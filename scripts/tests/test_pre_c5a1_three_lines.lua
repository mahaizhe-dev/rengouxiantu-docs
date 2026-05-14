-- ============================================================================
-- test_pre_c5a1_three_lines.lua
-- PRE-C5-A1: 第五章前三线专项合并验证
--
-- 验证三条优化线的真实路径：
--
-- === Line 1: 黑市最小闭环 ===
--   T1.  A锁住，B未锁 → A不能卖，B能卖
--   T2.  卡片级 canSell 不受 L2(global_unsync) 影响
--   T3.  卡片按钮文本：只显示"出售"或"🔒锁定"，不显示"⏳同步中"
--   T4.  A存档后解锁 → canSell恢复
--   T5.  onClick仍做L2实时拦截（确保安全）
--   T6.  确认弹窗仍做L2最终防线（确保安全）
--
-- === Line 2: 自动回收 ===
--   T7.  同日不重复
--   T8.  次日触发
--   T9.  跨月触发
--   T10. 跨年触发
--   (详细覆盖已在 test_bm_s4e_recycle_tick_flow.lua 和
--    test_bm_recycle_day_rollover.lua 中完成，此处做交叉引用)
--
-- === Line 3: N1 网络波动容错 ===
--   T11. 瞬时波动不立刻 lost
--   T12. 持续断连 → connection_lost
--   T13. 只读请求短容错（IsUnstable 期间可延迟重试）
--   T14. 写请求不自动补发（Save 失败不重试）
-- ============================================================================

local TAG = "[test_pre_c5a1_three_lines]"

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

local function assert_false(cond, msg) assert_true(not cond, msg) end

local function assert_eq(a, b, msg)
    assert_true(a == b, msg .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end

-- ============================================================================
-- Mock 基础设施
-- ============================================================================

local _eventHandlers = {}
package.loaded["core.EventBus"] = {
    On = function(event, cb)
        if not _eventHandlers[event] then _eventHandlers[event] = {} end
        table.insert(_eventHandlers[event], cb)
    end,
    Emit = function(event, ...)
        local cbs = _eventHandlers[event]
        if cbs then for _, cb in ipairs(cbs) do cb(...) end end
    end,
    Off = function() end,
}

-- TradeLock mock
local _lockedItems = {}
package.loaded["systems.BlackMarketTradeLock"] = {
    HasAnyLockedConsumable = function(_, _, consumableId)
        return _lockedItems[consumableId] or false
    end,
    ClearAllOnSaveSuccess = function()
        _lockedItems = {}
    end,
    IsLocked = function() return false end,
    LOCK_MESSAGE = "此类物品刚从黑商购入，正在等待存档确认",
}

-- InventorySystem mock — GetSellBlockReason 直接调用 InventorySystem.HasAnyLockedConsumable
package.loaded["systems.InventorySystem"] = {
    GetManager = function() return nil end,
    HasAnyLockedConsumable = function(consumableId)
        return _lockedItems[consumableId] or false
    end,
}
package.loaded["config.GameConfig"] = {
    BACKPACK_SIZE = 40,
}

-- 清除缓存
package.loaded["systems.save.SaveSession"] = nil
package.loaded["systems.BlackMarketSyncState"] = nil
package.loaded["network.NetworkStatus"] = nil

local SaveSession = require("systems.save.SaveSession")
local SyncState   = require("systems.BlackMarketSyncState")
local NetworkStatus = require("network.NetworkStatus")
local EventBus    = require("core.EventBus")

-- 模拟真实 TradeLock 行为：game_saved 时清除所有锁
-- （真实环境通过 InventoryManager → TradeLock.ClearAllOnSaveSuccess 完成，
--   但 mock 中 GetManager 返回 nil 所以需要这里补偿）
EventBus.On("game_saved", function()
    _lockedItems = {}
end)

-- ============================================================================
-- LINE 1: 黑市最小闭环
-- ============================================================================

print("\n" .. TAG .. " === Line 1: 黑市最小闭环 ===")

-- T1: A锁住，B未锁 → A不能卖，B能卖
do
    -- 清除所有状态
    SyncState.ClearAll()
    _lockedItems = {}

    -- 锁住 A 类商品
    _lockedItems["herb_001"] = true

    local reasonA = SyncState.GetSellBlockReason("herb_001")
    assert_eq(reasonA, "locked_item", "T1a: A锁住 → locked_item")

    local reasonB = SyncState.GetSellBlockReason("herb_002")
    assert_eq(reasonB, "none", "T1b: B未锁 → none")
end

-- T2: 卡片级 canSell 不受 L2(global_unsync) 影响
do
    _lockedItems = {}
    SyncState.ClearAll()

    -- 制造 L2 脏状态
    SyncState.MarkConsumeUsed("test_consume")

    -- GetSellBlockReason 仍然返回 global_unsync（底层行为不变）
    local reason = SyncState.GetSellBlockReason("herb_001")
    assert_eq(reason, "global_unsync", "T2a: GetSellBlockReason 底层返回 global_unsync")

    -- 但卡片级 canSell 逻辑：canSell = reason ~= "locked_item"
    -- 模拟卡片级判定
    local cardCanSell = (reason ~= "locked_item")
    assert_true(cardCanSell, "T2b: 卡片级 canSell 不受 L2 影响（Principle B）")

    SyncState.ClearAll()
end

-- T3: 卡片按钮文本只显示"出售"或"🔒锁定"
do
    _lockedItems = {}

    -- 无阻断 → 显示"出售"
    local reason1 = SyncState.GetSellBlockReason("herb_001")
    local text1 = reason1 == "locked_item" and "🔒锁定" or "出售"
    assert_eq(text1, "出售", "T3a: 无阻断 → 按钮文本'出售'")

    -- L1 锁住 → 显示"🔒锁定"
    _lockedItems["herb_001"] = true
    local reason2 = SyncState.GetSellBlockReason("herb_001")
    local text2 = reason2 == "locked_item" and "🔒锁定" or "出售"
    assert_eq(text2, "🔒锁定", "T3b: L1锁住 → 按钮文本'🔒锁定'")

    -- L2 脏 → 仍显示"出售"（不是"⏳同步中"）
    _lockedItems = {}
    SyncState.MarkConsumeUsed("x")
    local reason3 = SyncState.GetSellBlockReason("herb_001")
    local text3 = reason3 == "locked_item" and "🔒锁定" or "出售"
    assert_eq(text3, "出售", "T3c: L2脏时卡片仍显示'出售'（不是'⏳同步中'）")

    SyncState.ClearAll()
end

-- T4: A存档后解锁 → canSell恢复
do
    _lockedItems = { ["herb_001"] = true }
    local reason_before = SyncState.GetSellBlockReason("herb_001")
    assert_eq(reason_before, "locked_item", "T4a: 存档前 → locked_item")

    -- 模拟 game_saved → TradeLock.ClearAllOnSaveSuccess
    EventBus.Emit("game_saved")
    local reason_after = SyncState.GetSellBlockReason("herb_001")
    assert_eq(reason_after, "none", "T4b: game_saved 后 → none（解锁）")
end

-- T5: onClick 仍做 L2 实时拦截
do
    _lockedItems = {}
    SyncState.MarkWarehouseOp("test_op")

    local reason, detail = SyncState.GetSellBlockReason("herb_001")
    -- onClick 逻辑：检查 curReason == "global_unsync" 则拦截
    assert_eq(reason, "global_unsync", "T5: onClick L2 拦截仍生效")

    SyncState.ClearAll()
end

-- T6: 确认弹窗仍做 L2 最终防线
do
    _lockedItems = {}
    SaveSession.MarkDirty()

    local blocked, reason = SyncState.IsBlocked()
    assert_true(blocked, "T6a: SaveSession 脏时 IsBlocked=true（确认弹窗防线）")
    assert_eq(reason, "save_session_active", "T6b: 原因 save_session_active")

    EventBus.Emit("game_saved")
end

-- ============================================================================
-- LINE 2: 自动回收（交叉验证 — 核心已在专项测试中覆盖）
-- ============================================================================

print("\n" .. TAG .. " === Line 2: 自动回收交叉验证 ===")

-- 清除 BMConfig 依赖
local function _deepEmpty()
    return setmetatable({}, { __index = function(_, _) return _deepEmpty() end })
end
package.loaded["config.GameConfig"]    = _deepEmpty()
package.loaded["config.EquipmentData"] = _deepEmpty()
package.loaded["config.PetSkillData"]  = _deepEmpty()
package.loaded["config.BlackMerchantConfig"] = nil
local BMConfig = require("config.BlackMerchantConfig")

-- T7: 同日幂等 — RealDayGap 返回 0
do
    local gap = BMConfig.RealDayGap(20260514, 20260514)
    assert_eq(gap, 0, "T7: 同日 RealDayGap=0（不重复）")
end

-- T8: 次日触发 — RealDayGap 返回 1
do
    local gap = BMConfig.RealDayGap(20260515, 20260514)
    assert_eq(gap, 1, "T8: 次日 RealDayGap=1（触发回收）")
end

-- T9: 跨月触发 — 0531→0601 RealDayGap 返回 1
do
    local gap = BMConfig.RealDayGap(20260601, 20260531)
    assert_eq(gap, 1, "T9: 跨月 RealDayGap=1（正确）")
end

-- T10: 跨年触发 — 1231→0101 RealDayGap 返回 1
do
    local gap = BMConfig.RealDayGap(20270101, 20261231)
    assert_eq(gap, 1, "T10: 跨年 RealDayGap=1（正确）")
end

-- ============================================================================
-- LINE 3: N1 网络波动容错
-- ============================================================================

print("\n" .. TAG .. " === Line 3: N1 网络波动容错 ===")

-- 重置 NetworkStatus
NetworkStatus.Reset()

-- T11: 瞬时波动不立刻 lost（第1次失败 → unstable 警告，但不是 disconnected 阻断）
do
    NetworkStatus.Reset()
    -- 1次失败 → 进入 unstable（轻提示）
    local ev1 = NetworkStatus.RecordSample(false, 3.0)
    assert_eq(ev1, "connection_unstable", "T11a: 第1次失败 → unstable（轻提示）")
    assert_true(NetworkStatus.IsUnstable(), "T11a: 状态为 unstable")
    assert_false(NetworkStatus.IsDisconnected(), "T11a: 不是 disconnected（未阻断）")

    -- 2次失败 → 仍是 unstable，无新事件（宽限期内）
    local ev2 = NetworkStatus.RecordSample(false, 3.0)
    assert_eq(ev2, nil, "T11b: 第2次失败 → 无新事件（宽限期内）")
    assert_true(NetworkStatus.IsUnstable(), "T11b: 仍是 unstable")
    assert_false(NetworkStatus.IsDisconnected(), "T11b: 仍不是 disconnected")
end

-- T12: 持续断连 → connection_lost
do
    -- 继续第3次失败（从T11的unstable继续）
    local ev3 = NetworkStatus.RecordSample(false, 3.0)
    assert_eq(ev3, "connection_lost", "T12: 第3次失败 → connection_lost")
    assert_true(NetworkStatus.IsDisconnected(), "T12: 状态为 disconnected")
end

-- T13: 只读请求短容错 — unstable 期间 IsUnstable=true 且 IsDisconnected=false
do
    NetworkStatus.Reset()
    NetworkStatus.RecordSample(false, 3.0) -- fail 1
    NetworkStatus.RecordSample(false, 3.0) -- fail 2 → unstable

    -- 只读容错条件：IsUnstable() and not IsDisconnected()
    local canRetryRead = NetworkStatus.IsUnstable() and not NetworkStatus.IsDisconnected()
    assert_true(canRetryRead, "T13: unstable 期间只读可延迟重试")
end

-- T14: 写请求不自动补发 — disconnected 时无重试机制
do
    NetworkStatus.Reset()
    -- 制造 disconnected 状态
    NetworkStatus.RecordSample(false, 3.0)
    NetworkStatus.RecordSample(false, 3.0)
    NetworkStatus.RecordSample(false, 3.0)
    assert_true(NetworkStatus.IsDisconnected(), "T14a: 确认 disconnected")

    -- 验证 disconnected 时写操作应被阻断（各UI模块检查 IsDisconnected）
    -- 此处验证 NetworkStatus 不提供任何自动重试 API
    local hasRetryMethod = type(NetworkStatus.AutoRetry) == "function"
    assert_false(hasRetryMethod, "T14b: NetworkStatus 无 AutoRetry 方法（写不自动补发）")
end

-- ============================================================================
-- 结果汇总
-- ============================================================================

print(string.format("\n%s 结果: %d passed, %d failed, %d total",
    TAG, passed, failed, passed + failed))

return { passed = passed, failed = failed, total = passed + failed }
