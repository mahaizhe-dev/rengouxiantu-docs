-- ============================================================================
-- test_bm_s4c_sell_block_model.lua — BM-S4C 卖出拦截模型收口测试
--
-- 测试层次：
--   A. L1 同类锁门 — BackpackUtils.HasAnyLockedItem (服务端)
--   B. L2 全局未同步门 — BlackMarketSyncState.IsBlocked
--   C. L1 + L2 优先级 — 锁门优先于未同步门
--   D. L3 服务端最终放行 — 无锁 + 无未同步 → 允许卖出
--   E. 服务端整类禁售一致性 — HandleSell 与产品规则对齐
--
-- 纯 Lua 测试，无引擎依赖。
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

print("\n[test_bm_s4c] === BM-S4C 卖出拦截模型收口测试 ===\n")

-- ============================================================================
-- Stubs & Setup
-- ============================================================================

local _origLoaded = {}
local _modulesToReset = {
    "systems.BlackMarketTradeLock",
    "systems.BlackMarketSyncState",
    "network.BackpackUtils",
    "systems.save.SaveState",
    "systems.save.SaveMigrations",
    "config.GameConfig",
    "core.GameState",
}
for _, k in ipairs(_modulesToReset) do
    _origLoaded[k] = package.loaded[k]
    package.loaded[k] = nil
end

-- Stub SaveSession for BlackMarketSyncState
package.loaded["network.SaveLoadService"] = { IsDirty = function() return false end }

local TradeLock = require("systems.BlackMarketTradeLock")
local BackpackUtils = require("network.BackpackUtils")

-- Manually load BlackMarketSyncState with SaveSession stub
local _syncOrig = package.loaded["systems.BlackMarketSyncState"]
package.loaded["systems.BlackMarketSyncState"] = nil

-- Stub the SaveSession dependency that BlackMarketSyncState.IsBlocked needs
-- (IsBlocked does: pcall(require, "systems.save.SaveSession"))
local _origSaveSession = package.loaded["systems.save.SaveSession"]

local mockSaveSession = { _dirty = false }
function mockSaveSession.IsDirty() return mockSaveSession._dirty end
package.loaded["systems.save.SaveSession"] = mockSaveSession

-- Stub EventBus and InventorySystem for BlackMarketSyncState
local _origEventBus = package.loaded["core.EventBus"]
package.loaded["core.EventBus"] = {
    On = function() end,
    Emit = function() end,
}

-- Now try to load BlackMarketSyncState
local syncOk, SyncState = pcall(require, "systems.BlackMarketSyncState")
if not syncOk then
    -- BlackMarketSyncState might need SubscribeToEvent stub
    -- Create a minimal stub
    SyncState = {
        _dirtyConsume = false,
        _dirtyWarehouse = false,
    }
    function SyncState.IsBlocked()
        if SyncState._dirtyConsume then return true, "consume_dirty" end
        if SyncState._dirtyWarehouse then return true, "warehouse_dirty" end
        if mockSaveSession.IsDirty() then return true, "save_dirty" end
        return false, nil
    end
    function SyncState.ClearAll()
        SyncState._dirtyConsume = false
        SyncState._dirtyWarehouse = false
    end
    function SyncState.SetDirtyConsume()
        SyncState._dirtyConsume = true
    end
    function SyncState.SetDirtyWarehouse()
        SyncState._dirtyWarehouse = true
    end
    print("  ⚠ Using stub BlackMarketSyncState")
end

-- ============================================================================
-- A. L1 同类锁门 — BackpackUtils.HasAnyLockedItem (服务端)
-- ============================================================================

print("  --- A. L1 同类锁门 (服务端 BackpackUtils.HasAnyLockedItem) ---")

test("A1: 有活动锁堆叠 → HasAnyLockedItem = true", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 10 },
        ["2"] = { category = "consumable", consumableId = "herb_01", count = 5,
                  bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b1" },
    }
    assertTrue(BackpackUtils.HasAnyLockedItem(backpack, "herb_01"),
        "should detect locked stack")
end)

test("A2: 无锁堆叠 → HasAnyLockedItem = false", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 10 },
        ["2"] = { category = "consumable", consumableId = "herb_01", count = 5 },
    }
    assertFalse(BackpackUtils.HasAnyLockedItem(backpack, "herb_01"),
        "no locked stacks")
end)

test("A3: 过期锁 → HasAnyLockedItem = false", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 5,
                  bmLockUntil = os.time() - 10, bmLockSource = "black_market" },
    }
    assertFalse(BackpackUtils.HasAnyLockedItem(backpack, "herb_01"),
        "expired lock should not block")
end)

test("A4: 空背包 → HasAnyLockedItem = false", function()
    assertFalse(BackpackUtils.HasAnyLockedItem({}, "herb_01"), "empty backpack")
    assertFalse(BackpackUtils.HasAnyLockedItem(nil, "herb_01"), "nil backpack")
end)

test("A5: 不同 consumableId 锁不交叉", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_02", count = 5,
                  bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
        ["2"] = { category = "consumable", consumableId = "herb_01", count = 10 },
    }
    assertFalse(BackpackUtils.HasAnyLockedItem(backpack, "herb_01"),
        "herb_02 lock should not affect herb_01")
    assertTrue(BackpackUtils.HasAnyLockedItem(backpack, "herb_02"),
        "herb_02 should be locked")
end)

test("A6: 装备类不受消耗品锁机制影响", function()
    local backpack = {
        ["1"] = { equipId = "sword_01", slot = "weapon", name = "剑",
                  bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
    }
    -- 装备的 category 不是 "consumable"，所以 HasAnyLockedItem 不匹配
    assertFalse(BackpackUtils.HasAnyLockedItem(backpack, "sword_01"),
        "equipment should not be matched by consumable lock check")
end)

test("A7: 整类禁售 — 有锁 + 有未锁 → 仍然整类禁售", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 50 }, -- 大量未锁
        ["2"] = { category = "consumable", consumableId = "herb_01", count = 1,
                  bmLockUntil = os.time() + 300, bmLockSource = "black_market" },  -- 1 个锁
    }
    assertTrue(BackpackUtils.HasAnyLockedItem(backpack, "herb_01"),
        "even 1 locked stack should block whole class")
    -- 同时验证 CountUnlockedItem 仍正确统计
    assertEqual(BackpackUtils.CountUnlockedItem(backpack, "herb_01"), 50,
        "unlocked count should be 50")
end)

-- ============================================================================
-- B. L2 全局未同步门 — BlackMarketSyncState.IsBlocked
-- ============================================================================

print("  --- B. L2 全局未同步门 (BlackMarketSyncState.IsBlocked) ---")

-- Reset sync state
if SyncState.ClearAll then SyncState.ClearAll() end
mockSaveSession._dirty = false

test("B1: 全部干净 → IsBlocked = false", function()
    if SyncState.ClearAll then SyncState.ClearAll() end
    mockSaveSession._dirty = false
    local blocked, reason = SyncState.IsBlocked()
    assertFalse(blocked, "clean state should not block")
end)

test("B2: dirtyConsume → IsBlocked = true", function()
    SyncState.ClearAll()
    mockSaveSession._dirty = false
    -- 真实 API: MarkConsumeUsed(consumableId)
    SyncState.MarkConsumeUsed("test_item")
    local blocked, reason = SyncState.IsBlocked()
    assertTrue(blocked, "dirtyConsume should block")
end)

test("B3: dirtyWarehouse → IsBlocked = true", function()
    SyncState.ClearAll()
    mockSaveSession._dirty = false
    -- 真实 API: MarkWarehouseOp(reason)
    SyncState.MarkWarehouseOp("test_op")
    local blocked, reason = SyncState.IsBlocked()
    assertTrue(blocked, "dirtyWarehouse should block")
end)

test("B4: SaveSession.IsDirty → IsBlocked = true", function()
    SyncState.ClearAll()
    mockSaveSession._dirty = true
    local blocked, reason = SyncState.IsBlocked()
    assertTrue(blocked, "save dirty should block")
    mockSaveSession._dirty = false
end)

-- ============================================================================
-- C. L1 + L2 优先级 — 锁门优先于未同步门
-- ============================================================================

print("  --- C. L1 + L2 优先级 ---")

test("C1: L1(锁) + L2(未同步) 同时命中 — 产品规则要求锁门优先展示", function()
    -- 这个测试验证的是模型设计：当两者同时存在时
    -- UI 应该优先展示 L1 锁门的提示（保护期禁售），而不是 L2 的提示（背包未同步）
    -- 因为 L1 是 itemId 级别的精确拦截，L2 是全局模糊拦截

    -- 模拟：herb_01 有锁堆 + 全局 dirty
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 5,
                  bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
    }

    -- L1 检查（应先执行）
    local l1Blocked = BackpackUtils.HasAnyLockedItem(backpack, "herb_01")
    assertTrue(l1Blocked, "L1 should fire for herb_01")

    -- L2 检查（也命中）
    SyncState.ClearAll()
    SyncState.MarkConsumeUsed("test_item")
    local l2Blocked = SyncState.IsBlocked()
    assertTrue(l2Blocked, "L2 should also fire")

    -- 正确行为：代码先检查 L1，命中就直接返回，不走到 L2
    -- 本测试确认两者都能独立检测到
end)

test("C2: L1 不命中 + L2 命中 — 应展示未同步提示", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 10 }, -- 无锁
    }
    local l1Blocked = BackpackUtils.HasAnyLockedItem(backpack, "herb_01")
    assertFalse(l1Blocked, "L1 should NOT fire")

    SyncState.ClearAll()
    SyncState.MarkConsumeUsed("test_item")
    local l2Blocked = SyncState.IsBlocked()
    assertTrue(l2Blocked, "L2 should fire")
end)

test("C3: L1 命中 + L2 不命中 — 应展示保护期禁售提示", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 5,
                  bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
    }
    local l1Blocked = BackpackUtils.HasAnyLockedItem(backpack, "herb_01")
    assertTrue(l1Blocked, "L1 should fire")

    SyncState.ClearAll()
    mockSaveSession._dirty = false
    local l2Blocked = SyncState.IsBlocked()
    assertFalse(l2Blocked, "L2 should NOT fire")
end)

-- ============================================================================
-- D. L3 正常放行 — 无锁 + 无未同步 → 允许卖出
-- ============================================================================

print("  --- D. L3 正常放行 ---")

test("D1: 无锁 + 无未同步 + 有持有 → 允许卖出", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 10 },
    }
    -- L1
    assertFalse(BackpackUtils.HasAnyLockedItem(backpack, "herb_01"), "L1 clear")
    -- L2
    if SyncState.ClearAll then SyncState.ClearAll() end
    mockSaveSession._dirty = false
    assertFalse(SyncState.IsBlocked(), "L2 clear")
    -- L3: 持有量足够
    local held = BackpackUtils.CountBackpackItem(backpack, "herb_01")
    assertTrue(held >= 1, "held should be >= 1, got " .. tostring(held))
end)

test("D2: 无锁 + 无未同步 + 持有为 0 → 不允许（持有量不足）", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_02", count = 10 },
    }
    assertFalse(BackpackUtils.HasAnyLockedItem(backpack, "herb_01"), "L1 clear")
    if SyncState.ClearAll then SyncState.ClearAll() end
    mockSaveSession._dirty = false
    assertFalse(SyncState.IsBlocked(), "L2 clear")
    local held = BackpackUtils.CountBackpackItem(backpack, "herb_01")
    assertEqual(held, 0, "herb_01 should not be held")
end)

-- ============================================================================
-- E. 服务端整类禁售一致性
-- ============================================================================

print("  --- E. 服务端整类禁售一致性 ---")

test("E1: RemoveFromBackpack 跳过锁定堆叠（行为保持）", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 10 },
        ["2"] = { category = "consumable", consumableId = "herb_01", count = 5,
                  bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
    }
    -- 扣除 8 个，应只从未锁定的堆叠扣
    local remaining = BackpackUtils.RemoveFromBackpack(backpack, "herb_01", 8)
    assertEqual(remaining, 0, "should deduct 8 from unlocked stack")
    -- 未锁定堆叠应剩 2
    assertEqual(backpack["1"].count, 2, "unlocked stack should have 2 left")
    -- 锁定堆叠不动
    assertEqual(backpack["2"].count, 5, "locked stack should be untouched")
end)

test("E2: CountUnlockedItem 与 HasAnyLockedItem 逻辑一致", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 20 },
        ["2"] = { category = "consumable", consumableId = "herb_01", count = 3,
                  bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
    }
    -- HasAnyLockedItem 返回 true（存在锁堆）
    assertTrue(BackpackUtils.HasAnyLockedItem(backpack, "herb_01"))
    -- CountUnlockedItem 返回 20（只计未锁定）
    assertEqual(BackpackUtils.CountUnlockedItem(backpack, "herb_01"), 20)
    -- 产品规则：即使有 20 个未锁定，只要有 1 个锁定就整类禁售
    -- 这就是 S4C 的核心修改 — 服务端不再按 CountUnlockedItem 放行
end)

test("E3: 客户端 TradeLock.HasAnyLockedConsumable 与服务端 BackpackUtils.HasAnyLockedItem 判定一致", function()
    -- 构造相同的数据，用两种 API 判定结果应一致
    local items = {
        { category = "consumable", consumableId = "herb_01", count = 10 },
        { category = "consumable", consumableId = "herb_01", count = 5,
          bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b1" },
    }

    -- 客户端 API（用 getItemFn 接口）
    local clientResult = TradeLock.HasAnyLockedConsumable(
        function(i) return items[i] end,
        #items,
        "herb_01"
    )

    -- 服务端 API（用 backpack table 接口）
    local serverBackpack = {}
    for i, item in ipairs(items) do
        serverBackpack[tostring(i)] = item
    end
    local serverResult = BackpackUtils.HasAnyLockedItem(serverBackpack, "herb_01")

    -- 两者必须一致
    assertEqual(clientResult, serverResult, "client and server lock check must agree")
    assertTrue(clientResult, "both should detect locked")
end)

test("E4: 无锁时客户端与服务端判定一致", function()
    local items = {
        { category = "consumable", consumableId = "herb_01", count = 10 },
        { category = "consumable", consumableId = "herb_01", count = 5 },
    }

    local clientResult = TradeLock.HasAnyLockedConsumable(
        function(i) return items[i] end,
        #items,
        "herb_01"
    )

    local serverBackpack = {}
    for i, item in ipairs(items) do
        serverBackpack[tostring(i)] = item
    end
    local serverResult = BackpackUtils.HasAnyLockedItem(serverBackpack, "herb_01")

    assertEqual(clientResult, serverResult, "both should agree: no lock")
    assertFalse(clientResult, "both should return false")
end)

-- ============================================================================
-- Cleanup
-- ============================================================================

for _, k in ipairs(_modulesToReset) do
    package.loaded[k] = _origLoaded[k]
end
package.loaded["systems.save.SaveSession"] = _origSaveSession
package.loaded["core.EventBus"] = _origEventBus
package.loaded["network.SaveLoadService"] = nil

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format(
    "\n[test_bm_s4c] TOTAL: %d  PASSED: %d  FAILED: %d\n",
    total, passed, failed
))

return { passed = passed, failed = failed, total = total }
