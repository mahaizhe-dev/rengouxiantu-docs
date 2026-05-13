-- ============================================================================
-- test_bm_recycle_day_rollover.lua
-- BM-S4D: 自动回收过天判断回归测试
--
-- 验证 BMConfig.RealDayGap() 和 BMConfig.DateToTime() 在以下场景正确：
--   1. 同月隔天（20260513→20260514 = 1 天）
--   2. 跨月隔天（20260531→20260601 = 1 天）
--   3. 跨年隔天（20261231→20270101 = 1 天）
--   4. 同月隔两天（20260513→20260515 = 2 天）
--   5. 跨月隔两天（20260530→20260601 = 2 天）
--   6. 异常大跨度（20260101→20260301 = 59 天）
--   7. 同一天（gap=0）
--   8. 未来日期（gap<0）
--   9. 无效日期降级回退
--  10. DateToTime 边界校验
-- ============================================================================

local TAG = "[test_bm_recycle_day_rollover]"

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
-- 加载被测模块
-- Mock 依赖：BMConfig 依赖 GameConfig, EquipmentData, PetSkillData
-- ============================================================================

-- 最小化 mock（BMConfig 加载时大量访问 GameConfig / EquipmentData / PetSkillData）
-- 策略：用深度兜底 metatable，任意字段访问返回空表→再索引也返回空表
-- 这样无论 BlackMerchantConfig 访问多少字段，都不会 nil index
local function _deepEmpty()
    return setmetatable({}, { __index = function(_, _) return _deepEmpty() end })
end

package.loaded["config.GameConfig"]    = _deepEmpty()
package.loaded["config.EquipmentData"] = _deepEmpty()
package.loaded["config.PetSkillData"]  = _deepEmpty()

-- 清除缓存确保干净加载
package.loaded["config.BlackMerchantConfig"] = nil

local BMConfig = require("config.BlackMerchantConfig")

-- ============================================================================
-- 测试用例
-- ============================================================================

print(TAG .. " 开始测试")

-- ---- DateToTime 基础测试 ----

-- T1: 合法日期返回非 nil
local t1 = BMConfig.DateToTime(20260514)
assert_true(t1 ~= nil, "T1: DateToTime(20260514) 返回非 nil")

-- T2: 无效日期返回 nil
assert_eq(BMConfig.DateToTime(0), nil, "T2a: DateToTime(0) = nil")
assert_eq(BMConfig.DateToTime(-1), nil, "T2b: DateToTime(-1) = nil")
assert_eq(BMConfig.DateToTime(123), nil, "T2c: DateToTime(123) = nil (非8位)")

-- T3: 月份/天数边界
assert_eq(BMConfig.DateToTime(20261301), nil, "T3a: 月份13 = nil")
assert_eq(BMConfig.DateToTime(20260032), nil, "T3b: 天数32 = nil")
assert_eq(BMConfig.DateToTime(20260000), nil, "T3c: 月份0 = nil")

-- ---- RealDayGap 核心测试 ----

-- T4: 同月隔天
assert_eq(BMConfig.RealDayGap(20260514, 20260513), 1, "T4: 同月隔天 0513→0514 = 1")

-- T5: 跨月隔天（核心修复验证）
assert_eq(BMConfig.RealDayGap(20260601, 20260531), 1, "T5: 跨月隔天 0531→0601 = 1 (旧逻辑=70)")

-- T6: 跨年隔天（核心修复验证）
assert_eq(BMConfig.RealDayGap(20270101, 20261231), 1, "T6: 跨年隔天 1231→0101 = 1 (旧逻辑=8870)")

-- T7: 同月隔两天
assert_eq(BMConfig.RealDayGap(20260515, 20260513), 2, "T7: 同月隔两天 0513→0515 = 2")

-- T8: 跨月隔两天
assert_eq(BMConfig.RealDayGap(20260601, 20260530), 2, "T8: 跨月隔两天 0530→0601 = 2")

-- T9: 同一天
assert_eq(BMConfig.RealDayGap(20260514, 20260514), 0, "T9: 同一天 = 0")

-- T10: 未来日期（负数）
local gap10 = BMConfig.RealDayGap(20260513, 20260514)
assert_true(gap10 < 0, "T10: 未来日期 gap < 0 (got " .. tostring(gap10) .. ")")

-- T11: 异常大跨度
assert_eq(BMConfig.RealDayGap(20260301, 20260101), 59, "T11: 0101→0301(非闰年) = 59")

-- T12: 闰年跨月
assert_eq(BMConfig.RealDayGap(20280301, 20280228), 2, "T12: 闰年 0228→0301 = 2")

-- T13: 非闰年跨月
assert_eq(BMConfig.RealDayGap(20270301, 20270228), 1, "T13: 非闰年 0228→0301 = 1")

-- ---- 与 MAX_RECYCLE_GAP 组合验证 ----

-- T14: 跨月隔天应 <= MAX_RECYCLE_GAP（不会被误判为异常）
local gap14 = BMConfig.RealDayGap(20260601, 20260531)
assert_true(gap14 <= BMConfig.MAX_RECYCLE_GAP,
    "T14: 跨月隔天 realGap=" .. gap14 .. " <= MAX_RECYCLE_GAP=" .. BMConfig.MAX_RECYCLE_GAP)

-- T15: 跨年隔天同理
local gap15 = BMConfig.RealDayGap(20270101, 20261231)
assert_true(gap15 <= BMConfig.MAX_RECYCLE_GAP,
    "T15: 跨年隔天 realGap=" .. gap15 .. " <= MAX_RECYCLE_GAP=" .. BMConfig.MAX_RECYCLE_GAP)

-- T16: 大跨度应 > MAX_RECYCLE_GAP（触发保护逻辑）
local gap16 = BMConfig.RealDayGap(20260301, 20260101)
assert_true(gap16 > BMConfig.MAX_RECYCLE_GAP,
    "T16: 大跨度 realGap=" .. gap16 .. " > MAX_RECYCLE_GAP=" .. BMConfig.MAX_RECYCLE_GAP)

-- ============================================================================
-- 结果汇总
-- ============================================================================

print(string.format("\n%s 结果: %d passed, %d failed, %d total",
    TAG, passed, failed, passed + failed))

return { passed = passed, failed = failed, total = passed + failed }
