-- ============================================================================
-- test_black_merchant_warehouse_consistency.lua — HOTFIX-BM-01A 黑市一致性测试
--
-- 在 BM-01 测试基础上扩展，覆盖 BM-01A 新增的本地消耗品漏洞场景：
--
--   T1. 仓库存放 → dirty + save_request
--   T2. 仓库取出 → dirty + save_request
--   T3. BM 敏感消耗品消费 → dirty + save_request              (BM-01A NEW)
--   T4. 非 BM 敏感消耗品消费 → 不置脏                          (BM-01A NEW)
--   T5. game_saved → 清除 dirty
--   T6. game_loaded → 清除 dirty
--   T7. dirty=true 时卖出守卫条件成立（IsDirty 返回 true）
--   T8. 本地扣除失败 → 不发 save_request
--   T9. 本地扣除成功 → 发 save_request
--   T10. _BM_SENSITIVE_CONSUMABLES 包含 3 个令牌盒              (BM-01A NEW)
--   T11. 消耗+存档+再消耗 → dirty 正确跟踪全链路                (BM-01A NEW)
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

print("\n[test_bm_warehouse_consistency_01A] === HOTFIX-BM-01A 黑市一致性测试 ===\n")

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

local function clearModuleCache()
    package.loaded["core.EventBus"] = nil
    package.loaded["core.GameState"] = nil
    package.loaded["core.Utils"] = nil
    package.loaded["config.WarehouseConfig"] = nil
    package.loaded["config.GameConfig"] = nil
    package.loaded["config.EquipmentData"] = nil
    package.loaded["systems.WarehouseSystem"] = nil
    package.loaded["systems.InventorySystem"] = nil
end

clearModuleCache()

local EventBus = require("core.EventBus")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")

-- ============================================================================
-- UI stub: InventoryManager mock（InventorySystem 真实加载需要此桩）
-- ============================================================================

-- InventorySystem 需要 require("urhox-libs/UI")，在纯 Lua 下不可用
-- 因此我们手动构建一个最小桩并注入 package.loaded

local _mockBackpack = {}  -- slotIndex → item

local function _makeMockManager()
    return {
        GetInventoryItem = function(self, slot) return _mockBackpack[slot] end,
        SetInventoryItem = function(self, slot, item) _mockBackpack[slot] = item end,
        AddToInventory = function(self, item)
            -- 找到第一个空位
            for i = 1, 100 do
                if not _mockBackpack[i] then
                    _mockBackpack[i] = item
                    return true, i
                end
            end
            return false, nil
        end,
        GetAllEquipment = function(self) return {} end,
        GetEquipmentItem = function(self, slot) return nil end,
    }
end

-- Stub UI module
package.loaded["urhox-libs/UI"] = {
    InventoryManager = {
        new = function(cfg) return _makeMockManager() end,
    },
}

-- Stub EquipmentData
package.loaded["config.EquipmentData"] = {
    SLOTS = {},
    SetBonuses = {},
    SpecialEquipment = {},
    GOURD_UPGRADE = {},
    GOURD_MAIN_STAT = {},
}

-- Stub SkillSystem (InventorySystem.RecalcEquipStats requires it)
package.loaded["systems.SkillSystem"] = {
    equippedSkills = {},
    BindEquipSkill = function() end,
    UnbindEquipSkill = function() end,
    BindExclusiveSkill = function() end,
    UnbindExclusiveSkill = function() end,
}

-- Stub Utils
if not package.loaded["core.Utils"] then
    local _nextId = 1000
    package.loaded["core.Utils"] = {
        NextId = function() _nextId = _nextId + 1; return _nextId end,
    }
end

-- 现在加载真实的 WarehouseSystem 和 InventorySystem
clearModuleCache()
-- 重新恢复上面已注入的 stubs（clearModuleCache 不影响非 listed 的模块）
---@diagnostic disable-next-line: redefined-local
local EventBus = require("core.EventBus")
---@diagnostic disable-next-line: redefined-local
local GameState = require("core.GameState")
---@diagnostic disable-next-line: redefined-local
local GameConfig = require("config.GameConfig")
local WarehouseSystem = require("systems.WarehouseSystem")
local InventorySystem = require("systems.InventorySystem")

-- InventorySystem.Init() 需要 UI.InventoryManager
InventorySystem.Init()

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
    GameState.player = { gold = 999999999, level = 1, realm = "mortal_1" }
end

local function countEvent(name)
    local n = 0
    for _, e in ipairs(_emittedEvents) do
        if e == name then n = n + 1 end
    end
    return n
end

-- ============================================================================
-- T1: 仓库存放 → dirty + save_request
-- ============================================================================

test("T1. 仓库存放(StoreItem) → dirty + save_request", function()
    resetState()
    _mockBackpack[1] = { name = "TestSword", id = "sword_01" }
    local ok, err = WarehouseSystem.StoreItem(1)
    assertTrue(ok, "StoreItem should succeed: " .. tostring(err))
    assertTrue(WarehouseSystem.IsDirty(), "should be dirty after StoreItem")
    assertTrue(countEvent("save_request") >= 1, "save_request should be emitted")
end)

-- ============================================================================
-- T2: 仓库取出 → dirty + save_request
-- ============================================================================

test("T2. 仓库取出(RetrieveItem) → dirty + save_request", function()
    resetState()
    GameState.warehouse.items[1] = { name = "TestRing", id = "ring_01" }
    local ok, err = WarehouseSystem.RetrieveItem(1)
    assertTrue(ok, "RetrieveItem should succeed: " .. tostring(err))
    assertTrue(WarehouseSystem.IsDirty(), "should be dirty after RetrieveItem")
    assertTrue(countEvent("save_request") >= 1, "save_request should be emitted")
end)

-- ============================================================================
-- T3: BM 敏感消耗品消费 → dirty + save_request  (BM-01A 核心)
-- ============================================================================

test("T3. BM 敏感消耗品消费 → dirty + save_request (wubao_token_box)", function()
    resetState()
    -- 在背包放入 1 个乌堡令盒
    _mockBackpack[1] = {
        name = "乌堡令盒", id = "box_001", category = "consumable",
        consumableId = "wubao_token_box", count = 1,
    }
    -- 清除事件记录
    _emittedEvents = {}
    local ok = InventorySystem.ConsumeConsumable("wubao_token_box", 1)
    assertTrue(ok, "ConsumeConsumable should succeed")
    assertTrue(WarehouseSystem.IsDirty(), "dirty must be true after BM-sensitive consume")
    assertTrue(countEvent("save_request") >= 1, "save_request must be emitted for BM-sensitive consume")
end)

test("T3b. BM 敏感消耗品消费 → dirty (sha_hai_ling_box)", function()
    resetState()
    _mockBackpack[1] = {
        name = "沙海令盒", id = "box_002", category = "consumable",
        consumableId = "sha_hai_ling_box", count = 1,
    }
    _emittedEvents = {}
    local ok = InventorySystem.ConsumeConsumable("sha_hai_ling_box", 1)
    assertTrue(ok, "ConsumeConsumable should succeed")
    assertTrue(WarehouseSystem.IsDirty(), "dirty must be true after sha_hai_ling_box consume")
end)

test("T3c. BM 敏感消耗品消费 → dirty (taixu_token_box)", function()
    resetState()
    _mockBackpack[1] = {
        name = "太虚令盒", id = "box_003", category = "consumable",
        consumableId = "taixu_token_box", count = 1,
    }
    _emittedEvents = {}
    local ok = InventorySystem.ConsumeConsumable("taixu_token_box", 1)
    assertTrue(ok, "ConsumeConsumable should succeed")
    assertTrue(WarehouseSystem.IsDirty(), "dirty must be true after taixu_token_box consume")
end)

-- ============================================================================
-- T4: 非 BM 敏感消耗品消费 → 不置脏
-- ============================================================================

test("T4. 非 BM 敏感消耗品消费 → 不置脏 (exp_pill)", function()
    resetState()
    _mockBackpack[1] = {
        name = "修炼果", id = "pill_001", category = "consumable",
        consumableId = "exp_pill", count = 5,
    }
    _emittedEvents = {}
    local ok = InventorySystem.ConsumeConsumable("exp_pill", 1)
    assertTrue(ok, "ConsumeConsumable should succeed")
    assertFalse(WarehouseSystem.IsDirty(), "dirty must remain false for non-BM-sensitive item")
    -- save_request 只来自 consumable_used 但不来自 BM-01A 分支
    -- 确认没有因为 BM-01A 发 save_request
    -- (consumable_used 本身不发 save_request，所以总计 0)
    assertEqual(countEvent("save_request"), 0, "no save_request for non-sensitive consumable")
end)

-- ============================================================================
-- T5: game_saved → 清除 dirty
-- ============================================================================

test("T5. game_saved 事件清除 dirty", function()
    resetState()
    WarehouseSystem._dirty = true
    assertTrue(WarehouseSystem.IsDirty())
    EventBus.Emit("game_saved")
    assertFalse(WarehouseSystem.IsDirty(), "dirty should be cleared by game_saved")
end)

-- ============================================================================
-- T6: game_loaded → 清除 dirty
-- ============================================================================

test("T6. game_loaded 事件清除 dirty", function()
    resetState()
    WarehouseSystem._dirty = true
    assertTrue(WarehouseSystem.IsDirty())
    EventBus.Emit("game_loaded")
    assertFalse(WarehouseSystem.IsDirty(), "dirty should be cleared by game_loaded")
end)

-- ============================================================================
-- T7: dirty=true 时 IsDirty 返回 true（卖出守卫条件成立）
-- ============================================================================

test("T7. dirty=true → IsDirty 返回 true（卖出守卫拦截）", function()
    resetState()
    -- 消费敏感道具造成 dirty
    _mockBackpack[1] = {
        name = "乌堡令盒", id = "box_010", category = "consumable",
        consumableId = "wubao_token_box", count = 1,
    }
    InventorySystem.ConsumeConsumable("wubao_token_box", 1)
    assertTrue(WarehouseSystem.IsDirty(), "sell guard condition must hold")
end)

-- ============================================================================
-- T8: 本地扣除失败 → 不发 save_request
-- ============================================================================

test("T8. 本地扣除失败 → 不发 save_request", function()
    resetState()
    -- 背包里没有 potion_01，ConsumeConsumable 应返回 false
    _emittedEvents = {}
    local ok = InventorySystem.ConsumeConsumable("potion_01", 1)
    assertFalse(ok, "ConsumeConsumable should fail (item not in backpack)")
    assertEqual(countEvent("save_request"), 0, "no save_request on failure")
end)

-- ============================================================================
-- T9: 本地扣除成功 → 发 save_request（对 BM 敏感品）
-- ============================================================================

test("T9. 本地扣除成功(BM-sensitive) → 发 save_request", function()
    resetState()
    _mockBackpack[1] = {
        name = "乌堡令盒", id = "box_020", category = "consumable",
        consumableId = "wubao_token_box", count = 1,
    }
    _emittedEvents = {}
    local ok = InventorySystem.ConsumeConsumable("wubao_token_box", 1)
    assertTrue(ok, "ConsumeConsumable should succeed")
    assertTrue(countEvent("save_request") >= 1, "save_request should be emitted")
end)

-- ============================================================================
-- T10: _BM_SENSITIVE_CONSUMABLES 包含 3 个令牌盒
-- ============================================================================

test("T10. _BM_SENSITIVE_CONSUMABLES 包含 3 个令牌盒", function()
    local set = InventorySystem._BM_SENSITIVE_CONSUMABLES
    assertTrue(set ~= nil, "set must exist")
    assertTrue(set["wubao_token_box"] == true, "wubao_token_box must be in set")
    assertTrue(set["sha_hai_ling_box"] == true, "sha_hai_ling_box must be in set")
    assertTrue(set["taixu_token_box"] == true, "taixu_token_box must be in set")
    -- 确认没有多余条目
    local count = 0
    for _ in pairs(set) do count = count + 1 end
    assertEqual(count, 3, "set should have exactly 3 entries")
end)

-- ============================================================================
-- T11: 消耗+存档+再消耗 → dirty 正确跟踪全链路
-- ============================================================================

test("T11. 全链路：消费→存档→再消费→dirty 正确跟踪", function()
    resetState()
    -- 1. 消费敏感道具
    _mockBackpack[1] = {
        name = "乌堡令盒", id = "box_030", category = "consumable",
        consumableId = "wubao_token_box", count = 2,
    }
    InventorySystem.ConsumeConsumable("wubao_token_box", 1)
    assertTrue(WarehouseSystem.IsDirty(), "dirty after first consume")

    -- 2. 存档成功
    EventBus.Emit("game_saved")
    assertFalse(WarehouseSystem.IsDirty(), "clean after save")

    -- 3. 再消费一个
    _emittedEvents = {}
    InventorySystem.ConsumeConsumable("wubao_token_box", 1)
    assertTrue(WarehouseSystem.IsDirty(), "dirty after second consume")
    assertTrue(countEvent("save_request") >= 1, "save_request emitted again")

    -- 4. 再次存档
    EventBus.Emit("game_saved")
    assertFalse(WarehouseSystem.IsDirty(), "clean after second save")
end)

-- ============================================================================
-- 恢复全局
-- ============================================================================

EventBus.Emit = _origEmit

for k, v in pairs(_origGlobals) do
    _G[k] = v
end

-- ============================================================================
-- 结果汇总
-- ============================================================================

print("\n[test_bm_warehouse_consistency_01A] " .. passed .. "/" .. total .. " passed, "
    .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
