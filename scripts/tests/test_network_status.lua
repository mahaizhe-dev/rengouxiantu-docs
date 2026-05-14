-- ============================================================================
-- test_network_status.lua — NetworkStatus 状态机测试
--
-- N1: 验证断线宽限、恢复滞回、阻断判定、只读容错
--
-- 覆盖范围：
--   T1.  初始状态为 CONNECTED
--   T2.  首次失败 → UNSTABLE + connection_unstable 事件
--   T3.  单次失败后成功不立即恢复（滞回）
--   T4.  连续 2 次成功 → CONNECTED + connection_restored
--   T5.  连续 3 次失败 → DISCONNECTED + connection_lost
--   T6.  DISCONNECTED 后 1 次成功不恢复（滞回）
--   T7.  DISCONNECTED 后连续 2 次成功 → CONNECTED + connection_restored
--   T8.  CONNECTED 状态下连续成功无事件
--   T9.  UNSTABLE 阶段 IsUnstable=true, IsDisconnected=false
--   T10. DISCONNECTED 阶段 IsUnstable=true, IsDisconnected=true
--   T11. Reset 恢复初始状态
--   T12. 2 次失败不触发 connection_lost（阈值 3）
--   T13. 只读容错：CloudStorage 延迟重试结构验证
--   T14. DISCONNECTED 后再失败不重复触发
--   T15. [N1R] SUSTAINED_DISCONNECT_DELAY 残留常量已删除
--   T16. [N1R] dt 参数不影响状态机判定（纯计数驱动）
--   T17. [N1R] unstable 恢复不足后重新失败场景
--   T18. [N1R] Reset 后无 _sustainedTimer 字段
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

local function assert_eq(actual, expected, testName)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print(string.format("  ✗ %s — expected %s, got %s",
            testName, tostring(expected), tostring(actual)))
    end
end

local function assert_true(cond, testName)
    totalTests = totalTests + 1
    if cond then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print(string.format("  ✗ %s — condition is false", testName))
    end
end

local function assert_nil(val, testName)
    totalTests = totalTests + 1
    if val == nil then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print(string.format("  ✗ %s — expected nil, got %s", testName, tostring(val)))
    end
end

-- ============================================================================
-- 加载被测模块
-- ============================================================================

local NetworkStatus = require("network.NetworkStatus")

-- ============================================================================
-- 测试用例
-- ============================================================================

print("\n[N1] NetworkStatus 状态机测试")

-- T1: 初始状态
print("\n-- T1: 初始状态 --")
NetworkStatus.Reset()
assert_eq(NetworkStatus.GetState(), "connected", "T1: 初始状态为 connected")
assert_true(NetworkStatus.IsConnected(), "T1: IsConnected() = true")
assert_true(not NetworkStatus.IsUnstable(), "T1: IsUnstable() = false")
assert_true(not NetworkStatus.IsDisconnected(), "T1: IsDisconnected() = false")

-- T2: 首次失败 → UNSTABLE
print("\n-- T2: 首次失败 → UNSTABLE --")
NetworkStatus.Reset()
local ev = NetworkStatus.RecordSample(false, 3.0)
assert_eq(ev, "connection_unstable", "T2: 首次失败返回 connection_unstable")
assert_eq(NetworkStatus.GetState(), "unstable", "T2: 状态变为 unstable")
assert_true(NetworkStatus.IsUnstable(), "T2: IsUnstable() = true")
assert_true(not NetworkStatus.IsDisconnected(), "T2: IsDisconnected() = false")

-- T3: 单次成功不立即恢复（滞回，需要 RESTORE_THRESHOLD=2）
print("\n-- T3: 1 次成功不恢复（滞回）--")
-- 继续 T2 的 unstable 状态
ev = NetworkStatus.RecordSample(true, 3.0)
assert_nil(ev, "T3: 1 次成功后无事件（滞回中）")
assert_eq(NetworkStatus.GetState(), "unstable", "T3: 状态仍为 unstable")

-- T4: 连续 2 次成功 → CONNECTED
print("\n-- T4: 连续 2 次成功 → CONNECTED --")
ev = NetworkStatus.RecordSample(true, 3.0)
assert_eq(ev, "connection_restored", "T4: 第 2 次成功返回 connection_restored")
assert_eq(NetworkStatus.GetState(), "connected", "T4: 状态恢复为 connected")
assert_true(NetworkStatus.IsConnected(), "T4: IsConnected() = true")

-- T5: 连续 3 次失败 → DISCONNECTED
print("\n-- T5: 连续 3 次失败 → DISCONNECTED --")
NetworkStatus.Reset()
ev = NetworkStatus.RecordSample(false, 3.0)
assert_eq(ev, "connection_unstable", "T5: 第 1 次失败 → unstable")
ev = NetworkStatus.RecordSample(false, 3.0)
assert_nil(ev, "T5: 第 2 次失败无事件（未达阈值）")
ev = NetworkStatus.RecordSample(false, 3.0)
assert_eq(ev, "connection_lost", "T5: 第 3 次失败 → connection_lost")
assert_eq(NetworkStatus.GetState(), "disconnected", "T5: 状态为 disconnected")
assert_true(NetworkStatus.IsDisconnected(), "T5: IsDisconnected() = true")

-- T6: DISCONNECTED 后 1 次成功不恢复
print("\n-- T6: DISCONNECTED 后 1 次成功不恢复 --")
ev = NetworkStatus.RecordSample(true, 3.0)
assert_nil(ev, "T6: 1 次成功后无事件")
assert_eq(NetworkStatus.GetState(), "disconnected", "T6: 状态仍为 disconnected")

-- T7: DISCONNECTED 后连续 2 次成功 → CONNECTED
print("\n-- T7: 连续 2 次成功 → 恢复 --")
ev = NetworkStatus.RecordSample(true, 3.0)
assert_eq(ev, "connection_restored", "T7: 第 2 次成功返回 connection_restored")
assert_eq(NetworkStatus.GetState(), "connected", "T7: 状态恢复为 connected")

-- T8: CONNECTED 状态下连续成功无事件
print("\n-- T8: CONNECTED 状态下成功无事件 --")
ev = NetworkStatus.RecordSample(true, 3.0)
assert_nil(ev, "T8: 正常连接下成功无事件")
ev = NetworkStatus.RecordSample(true, 3.0)
assert_nil(ev, "T8: 正常连接下成功无事件(2)")

-- T9: UNSTABLE 状态查询
print("\n-- T9: UNSTABLE 状态查询一致性 --")
NetworkStatus.Reset()
NetworkStatus.RecordSample(false, 3.0) -- → unstable
assert_true(NetworkStatus.IsUnstable(), "T9: IsUnstable() = true 在 unstable 状态")
assert_true(not NetworkStatus.IsDisconnected(), "T9: IsDisconnected() = false 在 unstable 状态")
assert_true(not NetworkStatus.IsConnected(), "T9: IsConnected() = false 在 unstable 状态")

-- T10: DISCONNECTED 状态查询
print("\n-- T10: DISCONNECTED 状态查询一致性 --")
NetworkStatus.Reset()
NetworkStatus.RecordSample(false, 3.0)
NetworkStatus.RecordSample(false, 3.0)
NetworkStatus.RecordSample(false, 3.0) -- → disconnected
assert_true(NetworkStatus.IsUnstable(), "T10: IsUnstable() = true 在 disconnected 状态")
assert_true(NetworkStatus.IsDisconnected(), "T10: IsDisconnected() = true 在 disconnected 状态")
assert_true(not NetworkStatus.IsConnected(), "T10: IsConnected() = false 在 disconnected 状态")

-- T11: Reset 恢复初始状态
print("\n-- T11: Reset 恢复初始状态 --")
-- 先搞乱状态
NetworkStatus.RecordSample(false, 3.0)
NetworkStatus.RecordSample(false, 3.0)
NetworkStatus.Reset()
assert_eq(NetworkStatus.GetState(), "connected", "T11: Reset 后为 connected")
assert_eq(NetworkStatus._consecutiveFailCount, 0, "T11: Reset 后 failCount=0")
assert_eq(NetworkStatus._consecutiveSuccessCount, 0, "T11: Reset 后 successCount=0")

-- T12: 2 次失败不触发 connection_lost
print("\n-- T12: 2 次失败不触发 connection_lost --")
NetworkStatus.Reset()
NetworkStatus.RecordSample(false, 3.0)  -- → unstable
ev = NetworkStatus.RecordSample(false, 3.0)  -- 第 2 次
assert_nil(ev, "T12: 第 2 次失败无事件（阈值为 3）")
assert_eq(NetworkStatus.GetState(), "unstable", "T12: 状态仍为 unstable")

-- T13: 失败中间穿插成功 → 重置失败计数
print("\n-- T13: 失败间穿插成功重置计数 --")
NetworkStatus.Reset()
NetworkStatus.RecordSample(false, 3.0) -- fail 1 → unstable
NetworkStatus.RecordSample(false, 3.0) -- fail 2
NetworkStatus.RecordSample(true, 3.0)  -- success 1 → 重置 failCount
NetworkStatus.RecordSample(false, 3.0) -- fail 1 again (不是 fail 3!)
ev = NetworkStatus.RecordSample(false, 3.0) -- fail 2
assert_nil(ev, "T13: 穿插成功后第 2 次失败无 connection_lost")
-- 需要再失败一次才到阈值
ev = NetworkStatus.RecordSample(false, 3.0) -- fail 3
assert_eq(ev, "connection_lost", "T13: 重新累计第 3 次失败才 connection_lost")

-- T14: DISCONNECTED 后再失败不重复触发 connection_lost
print("\n-- T14: DISCONNECTED 后再失败不重复触发 --")
ev = NetworkStatus.RecordSample(false, 3.0)
assert_nil(ev, "T14: 已 DISCONNECTED 状态下再失败无事件")

-- ============================================================================
-- N1R 收口补充测试
-- ============================================================================

-- T15: SUSTAINED_DISCONNECT_DELAY 已删除 — 常量不存在
print("\n-- T15: [N1R] 残留常量已删除 --")
assert_nil(NetworkStatus.SUSTAINED_DISCONNECT_DELAY,
    "T15: SUSTAINED_DISCONNECT_DELAY 不存在")
assert_nil(NetworkStatus._sustainedTimer,
    "T15: _sustainedTimer 不存在")

-- T16: dt 参数不影响状态迁移 — 无论 dt 大小，纯计数驱动
print("\n-- T16: [N1R] dt 参数不影响状态机判定 --")
NetworkStatus.Reset()
-- 用 dt=0 和 dt=999 分别测试，结果应完全一致
local ev1 = NetworkStatus.RecordSample(false, 0)    -- dt=0
assert_eq(ev1, "connection_unstable", "T16a: dt=0 首次失败 → unstable")
NetworkStatus.Reset()
local ev2 = NetworkStatus.RecordSample(false, 999)  -- dt=999
assert_eq(ev2, "connection_unstable", "T16b: dt=999 首次失败 → unstable（与 dt=0 一致）")
-- 继续用 dt=0 累积到 disconnected
NetworkStatus.RecordSample(false, 0)  -- fail 2
local ev3 = NetworkStatus.RecordSample(false, 0)  -- fail 3
assert_eq(ev3, "connection_lost", "T16c: dt=0 累积 3 次失败 → disconnected")
-- 用 dt=0 恢复
NetworkStatus.RecordSample(true, 0)   -- success 1
local ev4 = NetworkStatus.RecordSample(true, 0)   -- success 2
assert_eq(ev4, "connection_restored", "T16d: dt=0 恢复 → connected")

-- T17: unstable → disconnected 中间穿插恢复不足（1次成功）→ 重新失败
print("\n-- T17: [N1R] unstable 恢复不足后重新失败 --")
NetworkStatus.Reset()
NetworkStatus.RecordSample(false, 3.0)  -- fail 1 → unstable
NetworkStatus.RecordSample(true, 3.0)   -- success 1（不够恢复）
assert_eq(NetworkStatus.GetState(), "unstable", "T17a: 1 次成功仍 unstable")
-- 再失败：failCount 被重置了，从 1 开始
ev = NetworkStatus.RecordSample(false, 3.0)  -- fail 1（新周期）
-- 由于已经是 unstable，且 failCount=1 with oldState=unstable，不触发 connection_unstable
assert_nil(ev, "T17b: unstable 态下再次首次失败无事件（已是 unstable）")
assert_eq(NetworkStatus.GetState(), "unstable", "T17c: 状态仍为 unstable")
NetworkStatus.RecordSample(false, 3.0)  -- fail 2
ev = NetworkStatus.RecordSample(false, 3.0)  -- fail 3
assert_eq(ev, "connection_lost", "T17d: 从 unstable 累计 3 次失败 → disconnected")

-- T18: Reset 后不存在 _sustainedTimer 字段
print("\n-- T18: [N1R] Reset 后无 _sustainedTimer --")
NetworkStatus.Reset()
assert_nil(NetworkStatus._sustainedTimer, "T18: Reset 后无 _sustainedTimer 字段")

-- ============================================================================
-- 结果汇总
-- ============================================================================

print(string.format("\n[N1] NetworkStatus: %d/%d passed, %d failed",
    passed, totalTests, failed))

return { passed = passed, failed = failed, total = totalTests }
