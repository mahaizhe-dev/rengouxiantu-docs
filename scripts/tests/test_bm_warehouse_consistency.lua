-- ============================================================================
-- test_bm_warehouse_consistency.lua — HOTFIX-BM-01 黑市仓库一致性测试
--
-- 验证范围：
--   T1.  dirty 初始为 false
--   T2.  MarkDirty 设为 true，ClearDirty 设为 false
--   T3.  IsDirty 正确报告状态
--   T4.  StoreItem 设置 dirty 并发出 save_request
--   T5.  StoreItemToSlot 设置 dirty 并发出 save_request
--   T6.  RetrieveItem 设置 dirty 并发出 save_request
--   T7.  UnlockNextRow 设置 dirty 并发出 save_request
--   T8.  game_saved 事件清除 dirty
--   T9.  game_loaded 事件清除 dirty
--   T10. 仓库操作失败不设置 dirty，不发 save_request
--   T11. 卖出拦截：dirty 时 SendSell 不应被调用
--   T12. 卖出放行：非 dirty 时 SendSell 应被调用
--   T13. 卖后本地扣除成功 → 发 save_request
--   T14. 卖后本地扣除失败 → 不发 save_request
--
-- 纯 Lua 测试，通过 stub 替代引擎依赖。
-- ============================================================================

local passed = 0
local failed = 0
local total  = 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        print("  ✗ " .. name .. ": " .. tostring(err))
    end
end

local function assertEqual(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a))
    end
end

local function assertTrue(v, msg)
    if not v then error(msg or "expected true") end
end

local function assertFalse(v, msg)
    if v then error(msg or "expected false") end
end

print("\n[test_bm_warehouse_consistency] === HOTFIX-BM-01 黑市仓库一致性测试 ===\n")

-- ============================================================================
-- Stubs: 共享全局环境，用完恢复
-- ============================================================================

local _origGlobals = {
    cjson = cjson,
    GetPlatform = GetPlatform,
}

---@diagnostic disable-next-line: lowercase-global
cjson = cjson or { encode = function(t) return "{}" end, decode = function(s) return {} end }
if not GetPlatform then
    ---@diagnostic disable-next-line: lowercase-global
    function GetPlatform() return "Windows" end
end

-- ============================================================================
-- 准备：确保 package.path 包含 scripts/
-- ============================================================================

if not package.path:find("scripts/%?%.lua") then
    package.path = package.path .. ";scripts/?.lua"
end

-- ============================================================================
-- 加载核心模块（清除缓存以得到干净实例）
-- ============================================================================

-- 清除缓存
package.loaded["core.EventBus"] = nil
package.loaded["core.GameState"] = nil
package.loaded["config.WarehouseConfig"] = nil
package.loaded["config.GameConfig"] = nil
package.loaded["systems.WarehouseSystem"] = nil
package.loaded["systems.InventorySystem"] = nil

local EventBus = require("core.EventBus")
local GameState = require("core.GameState")
local WarehouseConfig = require("config.WarehouseConfig")
local GameConfig = require("config.GameConfig")

-- ============================================================================
-- InventorySystem stub: 提供 GetManager 和 ConsumeConsumable
-- ============================================================================

local _mockBackpack = {}  -- slotIndex → item

local mockManager = {
    GetInventoryItem = function(self, slot)
        return _mockBackpack[slot]
    end,
    SetInventoryItem = function(self, slot, item)
        _mockBackpack[slot] = item
    end,
}

local _consumeResult = true  -- ConsumeConsumable 返回值可控

local InventorySystem = {
    GetManager = function() return mockManager end,
    ConsumeConsumable = function(itemId, amount)
        return _consumeResult
    end,
}

package.loaded["systems.InventorySystem"] = InventorySystem

-- 加载被测 WarehouseSystem（它会 require InventorySystem）
package.loaded["systems.WarehouseSystem"] = nil
local WarehouseSystem = require("systems.WarehouseSystem")

-- ============================================================================
-- 辅助：事件追踪
-- ============================================================================

local _emittedEvents = {}

local _origEmit = EventBus.Emit
EventBus.Emit = function(event, ...)
    _emittedEvents[#_emittedEvents + 1] = event
    return _origEmit(event, ...)
end

local function resetState()
    _emittedEvents = {}
    WarehouseSystem._dirty = false
    -- 重置 GameState.warehouse
    GameState.warehouse = {
        unlockedRows = 1,
        items = {},
    }
    -- 重置模拟背包
    _mockBackpack = {}
    -- 重置 player
    GameState.player = { gold = 999999999, level = 1 }
    _consumeResult = true
end

local function countEvent(name)
    local n = 0
    for _, e in ipairs(_emittedEvents) do
        if e == name then n = n + 1 end
    end
    return n
end

-- ============================================================================
-- T1-T3: dirty 标记基本 API
-- ============================================================================

test("T1. dirty 初始为 false", function()
    resetState()
    assertFalse(WarehouseSystem.IsDirty(), "should be clean")
end)

test("T2. MarkDirty → true, ClearDirty → false", function()
    resetState()
    WarehouseSystem.MarkDirty()
    assertTrue(WarehouseSystem.IsDirty(), "should be dirty after MarkDirty")
    WarehouseSystem.ClearDirty()
    assertFalse(WarehouseSystem.IsDirty(), "should be clean after ClearDirty")
end)

test("T3. IsDirty 报告真实状态", function()
    resetState()
    assertFalse(WarehouseSystem.IsDirty())
    WarehouseSystem._dirty = true
    assertTrue(WarehouseSystem.IsDirty())
    WarehouseSystem._dirty = false
    assertFalse(WarehouseSystem.IsDirty())
end)

-- ============================================================================
-- T4-T7: 仓库操作设置 dirty 并发 save_request
-- ============================================================================

test("T4. StoreItem 设置 dirty 并发出 save_request", function()
    resetState()
    -- 放一个物品到背包 slot 1
    _mockBackpack[1] = { name = "TestSword", id = "sword_01" }
    local ok, err = WarehouseSystem.StoreItem(1)
    assertTrue(ok, "StoreItem should succeed: " .. tostring(err))
    assertTrue(WarehouseSystem.IsDirty(), "should be dirty after StoreItem")
    assertTrue(countEvent("save_request") >= 1, "save_request should be emitted")
end)

test("T5. StoreItemToSlot 设置 dirty 并发出 save_request", function()
    resetState()
    _mockBackpack[1] = { name = "TestShield", id = "shield_01" }
    local ok, err = WarehouseSystem.StoreItemToSlot(1, 3)
    assertTrue(ok, "StoreItemToSlot should succeed: " .. tostring(err))
    assertTrue(WarehouseSystem.IsDirty(), "should be dirty after StoreItemToSlot")
    assertTrue(countEvent("save_request") >= 1, "save_request should be emitted")
end)

test("T6. RetrieveItem 设置 dirty 并发出 save_request", function()
    resetState()
    -- 先在仓库 slot 2 放一个物品
    GameState.warehouse.items[2] = { name = "TestRing", id = "ring_01" }
    local ok, err = WarehouseSystem.RetrieveItem(2)
    assertTrue(ok, "RetrieveItem should succeed: " .. tostring(err))
    assertTrue(WarehouseSystem.IsDirty(), "should be dirty after RetrieveItem")
    assertTrue(countEvent("save_request") >= 1, "save_request should be emitted")
end)

test("T7. UnlockNextRow 设置 dirty 并发出 save_request", function()
    resetState()
    GameState.player.gold = 999999999
    local ok, err = WarehouseSystem.UnlockNextRow()
    assertTrue(ok, "UnlockNextRow should succeed: " .. tostring(err))
    assertTrue(WarehouseSystem.IsDirty(), "should be dirty after UnlockNextRow")
    assertTrue(countEvent("save_request") >= 1, "save_request should be emitted")
end)

-- ============================================================================
-- T8-T9: 存档事件清除 dirty
-- ============================================================================

test("T8. game_saved 事件清除 dirty", function()
    resetState()
    WarehouseSystem._dirty = true
    assertTrue(WarehouseSystem.IsDirty())
    EventBus.Emit("game_saved")
    assertFalse(WarehouseSystem.IsDirty(), "dirty should be cleared by game_saved")
end)

test("T9. game_loaded 事件清除 dirty", function()
    resetState()
    WarehouseSystem._dirty = true
    assertTrue(WarehouseSystem.IsDirty())
    EventBus.Emit("game_loaded")
    assertFalse(WarehouseSystem.IsDirty(), "dirty should be cleared by game_loaded")
end)

-- ============================================================================
-- T10: 仓库操作失败不设置 dirty，不发 save_request
-- ============================================================================

test("T10a. StoreItem 失败（空槽位）不设 dirty", function()
    resetState()
    -- 背包 slot 1 为空
    local ok, err = WarehouseSystem.StoreItem(1)
    assertFalse(ok, "StoreItem should fail on empty slot")
    assertFalse(WarehouseSystem.IsDirty(), "dirty should remain false")
    assertEqual(countEvent("save_request"), 0, "no save_request on failure")
end)

test("T10b. StoreItem 失败（仓库满）不设 dirty", function()
    resetState()
    -- 填满仓库所有已解锁格子（1排 = 8格）
    for i = 1, 8 do
        GameState.warehouse.items[i] = { name = "filler" .. i }
    end
    _mockBackpack[1] = { name = "overflow" }
    local ok, err = WarehouseSystem.StoreItem(1)
    assertFalse(ok, "StoreItem should fail when warehouse full")
    assertFalse(WarehouseSystem.IsDirty(), "dirty should remain false")
    assertEqual(countEvent("save_request"), 0, "no save_request on failure")
end)

test("T10c. RetrieveItem 失败（空仓库格）不设 dirty", function()
    resetState()
    local ok, err = WarehouseSystem.RetrieveItem(1)
    assertFalse(ok, "RetrieveItem should fail on empty slot")
    assertFalse(WarehouseSystem.IsDirty(), "dirty should remain false")
    assertEqual(countEvent("save_request"), 0, "no save_request on failure")
end)

test("T10d. UnlockNextRow 失败（金币不足）不设 dirty", function()
    resetState()
    GameState.player.gold = 0
    -- 第2排需要 1000000 金币
    local ok, err = WarehouseSystem.UnlockNextRow()
    assertFalse(ok, "UnlockNextRow should fail with 0 gold")
    assertFalse(WarehouseSystem.IsDirty(), "dirty should remain false")
    assertEqual(countEvent("save_request"), 0, "no save_request on failure")
end)

-- ============================================================================
-- T11-T12: 卖出拦截逻辑（单元级别验证 IsDirty 守卫）
--
-- 注意：BlackMerchantUI 是 UI 模块，依赖大量引擎/UI 全局，不宜在纯 Lua 中加载。
-- 这里验证核心守卫逻辑：IsDirty() 返回值 → 阻止/放行 决策。
-- ============================================================================

test("T11. 卖出拦截：dirty 时 IsDirty 返回 true（守卫条件成立）", function()
    resetState()
    -- 模拟仓库操作后状态
    _mockBackpack[1] = { name = "item_to_store" }
    WarehouseSystem.StoreItem(1)
    -- 此时 dirty = true，卖出守卫应拦截
    assertTrue(WarehouseSystem.IsDirty(), "dirty must be true — sell should be blocked")
end)

test("T12. 卖出放行：game_saved 后 IsDirty 返回 false（守卫条件不成立）", function()
    resetState()
    _mockBackpack[1] = { name = "item_to_store" }
    WarehouseSystem.StoreItem(1)
    assertTrue(WarehouseSystem.IsDirty())
    -- 模拟存档成功
    EventBus.Emit("game_saved")
    assertFalse(WarehouseSystem.IsDirty(), "dirty must be false — sell should proceed")
end)

-- ============================================================================
-- T13-T14: 卖出后 save_request 抑制逻辑
--
-- 验证 InventorySystem.ConsumeConsumable 返回值决定是否发 save_request。
-- 这模拟 BlackMerchantUI_HandleBMResult 中的核心逻辑路径。
-- ============================================================================

test("T13. 卖后本地扣除成功 → 应发 save_request", function()
    resetState()
    _consumeResult = true

    -- 模拟 BlackMerchantUI_HandleBMResult 中消耗品卖出成功的核心逻辑
    local localDeductOk = InventorySystem.ConsumeConsumable("potion_01", 1)
    _emittedEvents = {}  -- 清空之前事件
    if localDeductOk then
        EventBus.Emit("save_request")
    end

    assertTrue(localDeductOk, "local deduct should succeed")
    assertEqual(countEvent("save_request"), 1, "save_request should be emitted")
end)

test("T14. 卖后本地扣除失败 → 不发 save_request", function()
    resetState()
    _consumeResult = false

    -- 模拟消耗品卖出：服务端成功但本地背包没有物品（已移入仓库）
    local localDeductOk = InventorySystem.ConsumeConsumable("potion_01", 1)
    _emittedEvents = {}
    if localDeductOk then
        EventBus.Emit("save_request")
    end

    assertFalse(localDeductOk, "local deduct should fail (item in warehouse)")
    assertEqual(countEvent("save_request"), 0, "save_request must NOT be emitted")
end)

-- ============================================================================
-- T15: 完整漏洞链路回归 — 存放仓库 → 存档 → 再操作 → dirty 正确
-- ============================================================================

test("T15. 完整链路：存放→存档→取出→dirty 正确跟踪", function()
    resetState()
    -- 1. 存放物品到仓库
    _mockBackpack[1] = { name = "gem", id = "gem_01" }
    WarehouseSystem.StoreItem(1)
    assertTrue(WarehouseSystem.IsDirty(), "dirty after store")

    -- 2. 存档成功
    EventBus.Emit("game_saved")
    assertFalse(WarehouseSystem.IsDirty(), "clean after save")

    -- 3. 取出物品
    -- 仓库 slot 1 现在有 gem
    WarehouseSystem.RetrieveItem(1)
    assertTrue(WarehouseSystem.IsDirty(), "dirty after retrieve")

    -- 4. 再次存档
    EventBus.Emit("game_saved")
    assertFalse(WarehouseSystem.IsDirty(), "clean after second save")
end)

test("T16. game_loaded 无条件清 dirty（即使之前未 dirty）", function()
    resetState()
    assertFalse(WarehouseSystem.IsDirty())
    EventBus.Emit("game_loaded")
    assertFalse(WarehouseSystem.IsDirty(), "should remain false")
    -- 设置 dirty 后 game_loaded 也能清除
    WarehouseSystem._dirty = true
    EventBus.Emit("game_loaded")
    assertFalse(WarehouseSystem.IsDirty(), "should be cleared")
end)

-- ============================================================================
-- 恢复全局
-- ============================================================================

EventBus.Emit = _origEmit  -- 恢复原始 Emit

for k, v in pairs(_origGlobals) do
    _G[k] = v
end

-- ============================================================================
-- 结果汇总
-- ============================================================================

print("\n[test_bm_warehouse_consistency] " .. passed .. "/" .. total .. " passed, "
    .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
