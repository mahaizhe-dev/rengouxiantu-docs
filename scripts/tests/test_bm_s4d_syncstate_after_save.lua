-- ============================================================================
-- test_bm_s4d_syncstate_after_save.lua
-- BM-S4D: SaveSession 边界 + BlackMarketSyncState L2 门收口回归测试
--
-- 验证：
--   1. SaveSession.MarkDirty() 后 IsDirty() 返回 true
--   2. 模拟 game_saved → SaveSession.ClearOnSave() 被调用
--   3. ClearOnSave 后 IsDirty() 返回 false
--   4. BlackMarketSyncState.IsBlocked() 在 game_saved 后不再因旧会话误拦
--   5. game_loaded 同样清除 SaveSession 活跃态
--   6. ClearOnSave 对未激活会话是幂等无害的
-- ============================================================================

local TAG = "[test_bm_s4d_syncstate]"

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

local function assert_false(cond, msg)
    assert_true(not cond, msg)
end

-- ============================================================================
-- Mock EventBus（捕获订阅但允许手动触发）
-- ============================================================================

local eventHandlers = {}

package.loaded["core.EventBus"] = {
    On = function(event, handler)
        if not eventHandlers[event] then
            eventHandlers[event] = {}
        end
        table.insert(eventHandlers[event], handler)
    end,
    Emit = function(event, ...)
        local handlers = eventHandlers[event]
        if handlers then
            for _, h in ipairs(handlers) do h(...) end
        end
    end,
}

-- Mock BlackMarketTradeLock（ClearAllOnSaveSuccess 需要 InventorySystem）
package.loaded["systems.BlackMarketTradeLock"] = {
    ClearAllOnSaveSuccess = function() end,
}
package.loaded["systems.InventorySystem"] = {
    GetManager = function() return nil end,
}
package.loaded["config.GameConfig"] = {
    BACKPACK_SIZE = 40,
}

-- ============================================================================
-- 加载被测模块（顺序重要：先 SaveSession 再 SyncState）
-- ============================================================================

-- 清除缓存确保干净加载
package.loaded["systems.save.SaveSession"] = nil
package.loaded["systems.BlackMarketSyncState"] = nil

local SaveSession = require("systems.save.SaveSession")
local SyncState   = require("systems.BlackMarketSyncState")
local EventBus    = require("core.EventBus")

-- ============================================================================
-- 测试用例
-- ============================================================================

print(TAG .. " 开始测试")

-- T1: 初始状态 — SaveSession 不脏
assert_false(SaveSession.IsDirty(), "T1: 初始 SaveSession 不脏")

-- T2: MarkDirty 后变脏
SaveSession.MarkDirty()
assert_true(SaveSession.IsDirty(), "T2: MarkDirty 后 IsDirty=true")

-- T3: IsBlocked 因 SaveSession 脏而命中
SyncState.ClearAll()  -- 确保 consume/warehouse 都干净
local blocked, reason = SyncState.IsBlocked()
assert_true(blocked, "T3: SaveSession 脏时 IsBlocked=true")
assert_true(reason == "save_session_active", "T3: 原因是 save_session_active (got " .. tostring(reason) .. ")")

-- T4: 模拟 game_saved → SaveSession 清除
EventBus.Emit("game_saved")
assert_false(SaveSession.IsDirty(), "T4: game_saved 后 SaveSession 不脏")

-- T5: game_saved 后 IsBlocked 不再命中
local blocked2, reason2 = SyncState.IsBlocked()
assert_false(blocked2, "T5: game_saved 后 IsBlocked=false (reason=" .. tostring(reason2) .. ")")

-- T6: ClearOnSave 幂等 — 对未激活会话无害
SaveSession.ClearOnSave()
assert_false(SaveSession.IsDirty(), "T6: ClearOnSave 幂等，未激活会话不报错")

-- T7: 再次 MarkDirty → game_loaded 也能清除
SaveSession.MarkDirty()
SaveSession.MarkDirty()  -- 连续两次
assert_true(SaveSession.IsDirty(), "T7a: 连续 MarkDirty 后 IsDirty=true")
assert_true(SaveSession.GetOpCount() == 2, "T7b: OpCount=2 (got " .. tostring(SaveSession.GetOpCount()) .. ")")

EventBus.Emit("game_loaded")
assert_false(SaveSession.IsDirty(), "T7c: game_loaded 后 SaveSession 不脏")
assert_true(SaveSession.GetOpCount() == 0, "T7d: game_loaded 后 OpCount=0")

-- T8: consume 脏 + SaveSession 干净 → 仍阻断
SyncState.MarkConsumeUsed("test_item")
local blocked3, reason3 = SyncState.IsBlocked()
assert_true(blocked3, "T8: consume 脏时 IsBlocked=true")
assert_true(reason3 == "consume_unsync", "T8: 原因是 consume_unsync")

-- T9: game_saved 清除 consume 脏
EventBus.Emit("game_saved")
local blocked4, reason4 = SyncState.IsBlocked()
assert_false(blocked4, "T9: game_saved 清除 consume 后 IsBlocked=false")

-- T10: warehouse 脏 + SaveSession 干净 → 仍阻断
SyncState.MarkWarehouseOp("test_op")
local blocked5, reason5 = SyncState.IsBlocked()
assert_true(blocked5, "T10: warehouse 脏时 IsBlocked=true")
assert_true(reason5 == "warehouse_unsync", "T10: 原因是 warehouse_unsync")

-- T11: 全部脏 → game_saved 全部清除
SaveSession.MarkDirty()
SyncState.MarkConsumeUsed("x")
SyncState.MarkWarehouseOp("y")
assert_true(SyncState.IsBlocked(), "T11a: 三重脏时 IsBlocked=true")
EventBus.Emit("game_saved")
local blocked6, reason6 = SyncState.IsBlocked()
assert_false(blocked6, "T11b: game_saved 后全部清除, IsBlocked=false")

-- ============================================================================
-- 结果汇总
-- ============================================================================

print(string.format("\n%s 结果: %d passed, %d failed, %d total",
    TAG, passed, failed, passed + failed))

return { passed = passed, failed = failed, total = passed + failed }
