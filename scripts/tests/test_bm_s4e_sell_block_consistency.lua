-- ============================================================================
-- test_bm_s4e_sell_block_consistency.lua
-- BM-S4E / Step A: GetSellBlockReason 一致性测试
--
-- 验证统一卖出判定入口 GetSellBlockReason 的所有分支：
--   T1. 无阻断 — 返回 "none"
--   T2. L1 同类锁 — 消耗品有锁返回 "locked_item"
--   T3. L1 装备豁免 — 装备类不检查 HasAnyLockedConsumable
--   T4. L2 consume 脏 — 返回 "global_unsync"
--   T5. L2 warehouse 脏 — 返回 "global_unsync"
--   T6. L2 SaveSession 活跃 — 返回 "global_unsync"
--   T7. L1+L2 同时存在 — L1 优先级高于 L2
--   T8. itemId=nil — 跳过 L1，仅检查 L2
--   T9. ClearAll 后 — L2 清除，恢复 "none"
--  T10. game_saved 事件 — 三条清除路径同步完成
-- ============================================================================

local TAG = "[test_bm_s4e_sell_block_consistency]"

-- ============================================================================
-- 测试辅助
-- ============================================================================

local passed, failed = 0, 0

local function assert_true(cond, msg)
    if cond then
        passed = passed + 1
        print("  OK " .. msg)
    else
        failed = failed + 1
        print("  FAIL: " .. msg)
    end
end

local function assert_eq(a, b, msg)
    assert_true(a == b, msg .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end

-- ============================================================================
-- Mock 依赖
-- ============================================================================

-- EventBus mock
local _eventHandlers = {}
local MockEventBus = {
    On = function(event, cb)
        if not _eventHandlers[event] then _eventHandlers[event] = {} end
        table.insert(_eventHandlers[event], cb)
    end,
    Emit = function(event, ...)
        local cbs = _eventHandlers[event]
        if cbs then
            for _, cb in ipairs(cbs) do cb(...) end
        end
    end,
    Off = function() end,
}
package.loaded["core.EventBus"] = MockEventBus

-- SaveSession mock
local MockSaveSession = { _dirty = false }
function MockSaveSession.IsDirty() return MockSaveSession._dirty end
function MockSaveSession.ClearOnSave()
    MockSaveSession._dirty = false
end
MockSaveSession._clearOnSaveRegistered = false
package.loaded["systems.save.SaveSession"] = MockSaveSession

-- InventorySystem mock
local _lockedItems = {}
local MockInventorySystem = {}
function MockInventorySystem.HasAnyLockedConsumable(itemId)
    return _lockedItems[itemId] == true
end
function MockInventorySystem.GetManager()
    return { GetInventoryItem = function(_, i) return nil end }
end
package.loaded["systems.InventorySystem"] = MockInventorySystem

-- BlackMerchantConfig mock（最小化）
local MockBMConfig = {
    ITEMS = {
        herb_01     = { itemType = "consumable", name = "灵草" },
        sword_01    = { itemType = "equipment", name = "铁剑" },
        pill_01     = { itemType = "consumable", name = "丹药" },
    },
    MAX_STOCK = 99,
    BACKPACK_SIZE = 30,
}
package.loaded["config.BlackMerchantConfig"] = MockBMConfig

-- TradeLock mock
local MockTradeLock = {
    LOCK_MESSAGE = "交易保护锁：数据同步中",
    ClearAllOnSaveSuccess = function() end,
}
package.loaded["systems.BlackMarketTradeLock"] = MockTradeLock

-- GameConfig mock
local function _deepEmpty()
    return setmetatable({}, { __index = function(_, _) return _deepEmpty() end })
end
package.loaded["config.GameConfig"] = _deepEmpty()

-- MockSaveSession 的 game_saved handler（模拟真实 SaveSession 的自清除）
MockEventBus.On("game_saved", function() MockSaveSession.ClearOnSave() end)

-- 清除并加载被测模块
package.loaded["systems.BlackMarketSyncState"] = nil
local SyncState = require("systems.BlackMarketSyncState")

-- ============================================================================
-- 重置函数
-- ============================================================================

local function resetAll()
    SyncState._dirtyConsume = false
    SyncState._dirtyWarehouse = false
    MockSaveSession._dirty = false
    _lockedItems = {}
end

-- ============================================================================
-- 测试用例
-- ============================================================================

print(TAG .. " 开始测试")

-- T1: 无阻断
do
    resetAll()
    local reason, detail = SyncState.GetSellBlockReason("herb_01")
    assert_eq(reason, "none", "T1: 无阻断返回 none")
    assert_eq(detail, nil, "T1: detail = nil")
end

-- T2: L1 同类锁 — 消耗品有锁
do
    resetAll()
    _lockedItems["herb_01"] = true
    local reason, detail = SyncState.GetSellBlockReason("herb_01")
    assert_eq(reason, "locked_item", "T2: 消耗品有锁返回 locked_item")
    assert_true(detail ~= nil and detail:find("L1") ~= nil, "T2: detail 含 L1")
end

-- T3: L1 装备豁免 — 装备类不检查
do
    resetAll()
    _lockedItems["sword_01"] = true  -- 即使锁了也不应阻断装备
    local reason, detail = SyncState.GetSellBlockReason("sword_01")
    assert_eq(reason, "none", "T3: 装备类豁免 L1 检查")
end

-- T4: L2 consume 脏
do
    resetAll()
    SyncState.MarkConsumeUsed("herb_01")
    local reason, detail = SyncState.GetSellBlockReason("herb_01")
    assert_eq(reason, "global_unsync", "T4: consume 脏返回 global_unsync")
    assert_true(detail ~= nil and detail:find("L2") ~= nil, "T4: detail 含 L2")
end

-- T5: L2 warehouse 脏
do
    resetAll()
    SyncState.MarkWarehouseOp("test")
    local reason, detail = SyncState.GetSellBlockReason("herb_01")
    assert_eq(reason, "global_unsync", "T5: warehouse 脏返回 global_unsync")
end

-- T6: L2 SaveSession 活跃
do
    resetAll()
    MockSaveSession._dirty = true
    local reason, detail = SyncState.GetSellBlockReason("herb_01")
    assert_eq(reason, "global_unsync", "T6: SaveSession 活跃返回 global_unsync")
    assert_true(detail ~= nil and detail:find("save_session") ~= nil, "T6: detail 含 save_session")
end

-- T7: L1+L2 同时 — L1 优先
do
    resetAll()
    _lockedItems["herb_01"] = true
    SyncState.MarkConsumeUsed("something")
    local reason, detail = SyncState.GetSellBlockReason("herb_01")
    assert_eq(reason, "locked_item", "T7: L1 优先于 L2")
end

-- T8: itemId=nil — 跳过 L1，仅检查 L2
do
    resetAll()
    _lockedItems["herb_01"] = true  -- 有锁但 itemId=nil 应跳过
    local reason = SyncState.GetSellBlockReason(nil)
    assert_eq(reason, "none", "T8a: itemId=nil 跳过 L1，无 L2 返回 none")

    SyncState.MarkConsumeUsed("x")
    reason = SyncState.GetSellBlockReason(nil)
    assert_eq(reason, "global_unsync", "T8b: itemId=nil 但有 L2 返回 global_unsync")
end

-- T9: ClearAll 后恢复
do
    resetAll()
    SyncState.MarkConsumeUsed("x")
    SyncState.MarkWarehouseOp("y")
    assert_eq(SyncState.GetSellBlockReason("herb_01"), "global_unsync", "T9a: 清除前 global_unsync")
    SyncState.ClearAll()
    assert_eq(SyncState.GetSellBlockReason("herb_01"), "none", "T9b: ClearAll 后恢复 none")
end

-- T10: game_saved 事件 — 三条路径同步清除
do
    resetAll()
    SyncState.MarkConsumeUsed("a")
    SyncState.MarkWarehouseOp("b")
    MockSaveSession._dirty = true
    assert_eq(SyncState.GetSellBlockReason("herb_01"), "global_unsync", "T10a: 存档前 blocked")

    -- 模拟 game_saved 事件
    MockEventBus.Emit("game_saved")

    -- SaveSession 的 game_saved handler 已在模块加载时注册
    -- consume/warehouse 已被 ClearAll 清除
    -- SaveSession._dirty 也应被清除（由 SaveSession 的 game_saved handler）
    local reason = SyncState.GetSellBlockReason("herb_01")
    assert_eq(reason, "none", "T10b: game_saved 后所有标记清除")
end

-- T11: 未知 itemId（不在 BMConfig.ITEMS 中）— 仍执行 L1 检查
do
    resetAll()
    _lockedItems["unknown_item"] = true
    local reason = SyncState.GetSellBlockReason("unknown_item")
    -- cfgItem 为 nil → isEquip = false → 检查 HasAnyLockedConsumable
    assert_eq(reason, "locked_item", "T11: 未知 itemId 仍执行 L1 检查")
end

-- T12: L2 三条件逐一验证独立性
do
    -- 只有 consume 脏
    resetAll()
    SyncState._dirtyConsume = true
    local r1 = SyncState.GetSellBlockReason("herb_01")
    assert_eq(r1, "global_unsync", "T12a: 仅 consume 脏 → blocked")

    -- 只有 warehouse 脏
    resetAll()
    SyncState._dirtyWarehouse = true
    local r2 = SyncState.GetSellBlockReason("herb_01")
    assert_eq(r2, "global_unsync", "T12b: 仅 warehouse 脏 → blocked")

    -- 只有 SaveSession
    resetAll()
    MockSaveSession._dirty = true
    local r3 = SyncState.GetSellBlockReason("herb_01")
    assert_eq(r3, "global_unsync", "T12c: 仅 SaveSession 活跃 → blocked")
end

-- ============================================================================
-- 结果汇总
-- ============================================================================

print(string.format("\n%s 结果: %d passed, %d failed, %d total",
    TAG, passed, failed, passed + failed))

return { passed = passed, failed = failed, total = passed + failed }
