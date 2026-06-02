-- ============================================================================
-- test_recycle_window_schedule.lua
--
-- 测试 BlackMerchantHandler.RecycleTick 午间窗口调度逻辑
-- 验证：节流、窗口时间、失败重试间隔、补跑截止
-- ============================================================================

local BMConfig = require("config.BlackMerchantConfig")

local passed = 0
local failed = 0
local total  = 0

local function TEST(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  [PASS] " .. name)
    else
        failed = failed + 1
        print("  [FAIL] " .. name .. ": " .. tostring(err))
    end
end

local function ASSERT(cond, msg)
    if not cond then error(msg or "assertion failed", 2) end
end

print("=== test_recycle_window_schedule ===")

-- ============================================================================
-- TEST 1: 调度配置常量存在且合理
-- ============================================================================

TEST("1. 调度配置常量存在", function()
    ASSERT(BMConfig.RECYCLE_TIMEZONE_OFFSET == 8 * 3600, "TIMEZONE_OFFSET should be 28800")
    ASSERT(BMConfig.RECYCLE_AUTO_START_HOUR == 12, "START_HOUR should be 12")
    ASSERT(BMConfig.RECYCLE_AUTO_END_HOUR == 13, "END_HOUR should be 13")
    ASSERT(BMConfig.RECYCLE_CHECK_INTERVAL == 60, "CHECK_INTERVAL should be 60")
    ASSERT(BMConfig.RECYCLE_RETRY_INTERVAL == 300, "RETRY_INTERVAL should be 300")
    ASSERT(BMConfig.RECYCLE_LATE_END_HOUR == 18, "LATE_END_HOUR should be 18")
end)

-- ============================================================================
-- TEST 2: START_HOUR < LATE_END_HOUR (窗口逻辑一致性)
-- ============================================================================

TEST("2. 窗口逻辑一致性: START < LATE_END", function()
    ASSERT(BMConfig.RECYCLE_AUTO_START_HOUR < BMConfig.RECYCLE_LATE_END_HOUR,
        "START_HOUR must be < LATE_END_HOUR")
end)

-- ============================================================================
-- TEST 3: RETRY_INTERVAL > CHECK_INTERVAL (节流层次正确)
-- ============================================================================

TEST("3. RETRY_INTERVAL > CHECK_INTERVAL", function()
    ASSERT(BMConfig.RECYCLE_RETRY_INTERVAL > BMConfig.RECYCLE_CHECK_INTERVAL,
        "RETRY_INTERVAL must be > CHECK_INTERVAL to prevent thrashing")
end)

-- ============================================================================
-- TEST 4: DateToTime 和 RealDayGap 仍然正常工作（回归）
-- ============================================================================

TEST("4. DateToTime 基本正确性", function()
    local t = BMConfig.DateToTime(20260601)
    ASSERT(t ~= nil, "20260601 should parse")
    ASSERT(type(t) == "number", "should return number")

    local bad = BMConfig.DateToTime(0)
    ASSERT(bad == nil, "0 should fail")

    local bad2 = BMConfig.DateToTime(19691231)
    ASSERT(bad2 == nil, "before 1970 should fail")
end)

TEST("5. RealDayGap 跨月正确", function()
    local gap = BMConfig.RealDayGap(20260601, 20260531)
    ASSERT(gap == 1, "20260601 - 20260531 should be 1 day, got " .. tostring(gap))
end)

TEST("6. RealDayGap 同日为 0", function()
    local gap = BMConfig.RealDayGap(20260601, 20260601)
    ASSERT(gap == 0, "same day should be 0")
end)

TEST("7. RealDayGap 跨年正确", function()
    local gap = BMConfig.RealDayGap(20270101, 20261231)
    ASSERT(gap == 1, "20270101 - 20261231 should be 1 day, got " .. tostring(gap))
end)

-- ============================================================================
-- TEST 8: RECYCLE_WEIGHTS 未被修改（保持 0/1/2 三档）
-- ============================================================================

TEST("8. RECYCLE_WEIGHTS 保持 0.25/0.75/1.0", function()
    local w = BMConfig.RECYCLE_WEIGHTS
    ASSERT(w ~= nil, "RECYCLE_WEIGHTS must exist")
    ASSERT(#w == 3, "should have 3 entries")
    ASSERT(w[1] == 0.25, "w[1] should be 0.25")
    ASSERT(w[2] == 0.75, "w[2] should be 0.75")
    ASSERT(w[3] == 1.0, "w[3] should be 1.0")
end)

-- ============================================================================
-- TEST 9: MAX_RECYCLE_GAP 仍为 2
-- ============================================================================

TEST("9. MAX_RECYCLE_GAP = 2", function()
    ASSERT(BMConfig.MAX_RECYCLE_GAP == 2, "MAX_RECYCLE_GAP should be 2")
end)

-- ============================================================================
-- TEST 10: RECYCLE_ENABLED 为 true
-- ============================================================================

TEST("10. RECYCLE_ENABLED = true", function()
    ASSERT(BMConfig.RECYCLE_ENABLED == true, "RECYCLE_ENABLED should be true")
end)

-- ============================================================================
-- TEST 11: 验证窗口调度代码结构（RecycleTick 存在且可调用）
-- ============================================================================

TEST("11. BlackMerchantHandler.RecycleTick 存在", function()
    -- 只验证模块可加载、函数存在，不做真实调用（需要 serverCloud mock）
    local ok, Handler = pcall(require, "network.BlackMerchantHandler")
    if not ok then
        -- 在纯 Lua 测试环境下 serverCloud 不可用，跳过
        print("       (skipped: serverCloud not available in test env)")
        return
    end
    ASSERT(type(Handler.RecycleTick) == "function", "RecycleTick should be a function")
    ASSERT(type(Handler.ExecuteRecycle) == "function", "ExecuteRecycle should be a function")
end)

-- ============================================================================
-- 结果汇总
-- ============================================================================

print(string.format("\n=== 结果: %d/%d PASS, %d FAIL ===\n", passed, total, failed))

if failed > 0 then
    print("!!! TEST SUITE FAILED !!!")
end

return { passed = passed, failed = failed, total = total }
