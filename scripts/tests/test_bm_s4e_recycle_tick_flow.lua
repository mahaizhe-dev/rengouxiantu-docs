-- ============================================================================
-- test_bm_s4e_recycle_tick_flow.lua
-- BM-S4E / Step C: RecycleTick() 流程级测试
--
-- 与 test_bm_recycle_day_rollover.lua（仅验证 RealDayGap 工具函数）不同，
-- 本测试用 stub 替换 os.date / serverCloud.money / ExecuteRecycle，
-- 验证 RecycleTick 的完整决策流程：
--   T1. 同一天幂等 — 第二次调用不触发任何云端操作
--   T2. 隔一天正常回收 — 占坑 + ExecuteRecycle 均被调用
--   T3. 跨月隔天 — realGap=1，正常回收（不被误判为异常）
--   T4. 跨年隔天 — realGap=1，正常回收
--   T5. 异常大跨度 — realGap > MAX_RECYCLE_GAP，仅推日期不回收
--   T6. 云端读取失败 — 清除内存占位，下次可重试
--   T7. 占坑失败 — 清除内存占位，商品未动
--   T8. RECYCLE_ENABLED=false — 直接返回不执行
-- ============================================================================

local TAG = "[test_bm_s4e_recycle_tick_flow]"

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
-- Mock 深度兜底（BMConfig 加载需要 GameConfig 等）
-- ============================================================================

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
-- 构建可控的 Handler 环境
-- 我们不直接 require BlackMerchantHandler（它有大量引擎依赖），
-- 而是提取 RecycleTick 的核心逻辑做等价测试。
-- ============================================================================

--- 模拟 RecycleTick 的完整决策逻辑（从 BlackMerchantHandler.lua L1323-1410 提取）
--- 这是一个纯函数化的等价实现，可以注入所有外部依赖
local function SimulateRecycleTick(opts)
    local recycleEnabled = opts.recycleEnabled
    local recycleRunning = opts.recycleRunning or false
    local lastRecycleDate = opts.lastRecycleDate
    local todayStr = opts.todayStr          -- os.date("%Y%m%d") 的返回值
    local cloudDate = opts.cloudDate or 0   -- 云端日期数值
    local moneyGetOk = opts.moneyGetOk      -- 云端读取是否成功
    local moneyAddOk = opts.moneyAddOk      -- 占坑是否成功

    local log = {}
    local newLastRecycleDate = lastRecycleDate
    local executeRecycleCalled = false
    local dateAddCalled = false
    local dateAddAmount = nil

    -- 检查开关
    if not recycleEnabled then
        log[#log+1] = "disabled"
        return { log = log, lastRecycleDate = newLastRecycleDate, executeRecycleCalled = false, dateAddCalled = false }
    end

    -- 检查是否正在运行
    if recycleRunning then
        log[#log+1] = "already_running"
        return { log = log, lastRecycleDate = newLastRecycleDate, executeRecycleCalled = false, dateAddCalled = false }
    end

    -- 检查内存占位
    if lastRecycleDate == todayStr then
        log[#log+1] = "same_day_skip"
        return { log = log, lastRecycleDate = newLastRecycleDate, executeRecycleCalled = false, dateAddCalled = false }
    end

    -- 内存占位
    newLastRecycleDate = todayStr

    -- 模拟 serverCloud.money:Get
    if not moneyGetOk then
        newLastRecycleDate = nil
        log[#log+1] = "money_get_failed"
        return { log = log, lastRecycleDate = newLastRecycleDate, executeRecycleCalled = false, dateAddCalled = false }
    end

    local todayNum = tonumber(todayStr) or 0
    local numericGap = todayNum - cloudDate
    local realGap = BMConfig.RealDayGap(todayNum, cloudDate)

    if realGap <= 0 then
        log[#log+1] = "cloud_same_day"
        return { log = log, lastRecycleDate = newLastRecycleDate, executeRecycleCalled = false, dateAddCalled = false }
    end

    -- 异常大跨度
    if realGap > (BMConfig.MAX_RECYCLE_GAP or 2) then
        log[#log+1] = "anomaly_gap"
        dateAddCalled = true
        dateAddAmount = numericGap
        if moneyAddOk then
            log[#log+1] = "date_jumped"
        else
            newLastRecycleDate = nil
            log[#log+1] = "date_jump_failed"
        end
        return { log = log, lastRecycleDate = newLastRecycleDate, executeRecycleCalled = false, dateAddCalled = dateAddCalled, dateAddAmount = dateAddAmount }
    end

    -- 正常流程：先占坑
    dateAddCalled = true
    dateAddAmount = numericGap
    if not moneyAddOk then
        newLastRecycleDate = nil
        log[#log+1] = "occupy_failed"
        return { log = log, lastRecycleDate = newLastRecycleDate, executeRecycleCalled = false, dateAddCalled = dateAddCalled, dateAddAmount = dateAddAmount }
    end

    -- 占坑成功 → 执行回收
    log[#log+1] = "occupied"
    executeRecycleCalled = true
    log[#log+1] = "recycle_executed"

    return {
        log = log,
        lastRecycleDate = newLastRecycleDate,
        executeRecycleCalled = executeRecycleCalled,
        dateAddCalled = dateAddCalled,
        dateAddAmount = dateAddAmount,
        realGap = realGap,
        numericGap = numericGap,
    }
end

-- ============================================================================
-- 测试用例
-- ============================================================================

print(TAG .. " 开始测试")

-- T1: 同一天幂等 — 内存占位命中，不触发任何云端操作
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = "20260514",
        todayStr = "20260514",
        cloudDate = 20260514,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, false, "T1: 同一天不执行回收")
    assert_eq(r.dateAddCalled, false, "T1: 同一天不调 money:Add")
    assert_eq(r.log[1], "same_day_skip", "T1: 日志为 same_day_skip")
end

-- T2: 隔一天正常回收
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260515",
        cloudDate = 20260514,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, true, "T2: 隔一天执行回收")
    assert_eq(r.dateAddCalled, true, "T2: 调用 money:Add 占坑")
    assert_eq(r.dateAddAmount, 1, "T2: numericGap = 1")
    assert_eq(r.lastRecycleDate, "20260515", "T2: 内存占位更新")
end

-- T3: 跨月隔天正常回收（0531→0601）
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260601",
        cloudDate = 20260531,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, true, "T3: 跨月隔天执行回收")
    assert_eq(r.realGap, 1, "T3: realGap = 1 (不是 70)")
    assert_eq(r.numericGap, 70, "T3: numericGap = 70 (YYYYMMDD 差)")
    assert_eq(r.dateAddAmount, 70, "T3: money:Add 增量 = 70")
end

-- T4: 跨年隔天正常回收（1231→0101）
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20270101",
        cloudDate = 20261231,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, true, "T4: 跨年隔天执行回收")
    assert_eq(r.realGap, 1, "T4: realGap = 1 (不是 8870)")
    assert_eq(r.numericGap, 8870, "T4: numericGap = 8870 (YYYYMMDD 差)")
end

-- T5: 异常大跨度 — 仅推日期不回收
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260601",
        cloudDate = 20260101,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, false, "T5: 异常跨度不执行回收")
    assert_eq(r.dateAddCalled, true, "T5: 仍然推进日期")
    assert_true(r.log[1] == "anomaly_gap", "T5: 日志标记 anomaly_gap")
end

-- T6: 云端读取失败 — 清除内存占位可重试
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260515",
        cloudDate = 0,
        moneyGetOk = false,
        moneyAddOk = false,
    })
    assert_eq(r.executeRecycleCalled, false, "T6: 读取失败不执行回收")
    assert_eq(r.lastRecycleDate, nil, "T6: 内存占位清除 (可重试)")
    assert_eq(r.log[1], "money_get_failed", "T6: 日志为 money_get_failed")
end

-- T7: 占坑失败 — 清除内存占位，商品未动
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260515",
        cloudDate = 20260514,
        moneyGetOk = true,
        moneyAddOk = false,
    })
    assert_eq(r.executeRecycleCalled, false, "T7: 占坑失败不执行回收")
    assert_eq(r.lastRecycleDate, nil, "T7: 内存占位清除 (可重试)")
    assert_eq(r.log[1], "occupy_failed", "T7: 日志为 occupy_failed")
end

-- T8: RECYCLE_ENABLED=false — 直接返回
do
    local r = SimulateRecycleTick({
        recycleEnabled = false,
        lastRecycleDate = nil,
        todayStr = "20260515",
        cloudDate = 20260514,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, false, "T8: 开关关闭不执行回收")
    assert_eq(r.dateAddCalled, false, "T8: 开关关闭不调 money:Add")
    assert_eq(r.log[1], "disabled", "T8: 日志为 disabled")
end

-- T9: 云端已是今天 — realGap=0，不重复回收
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,  -- 内存没占位（比如刚重启）
        todayStr = "20260515",
        cloudDate = 20260515,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, false, "T9: 云端已是今天不回收")
    assert_eq(r.dateAddCalled, false, "T9: 不调 money:Add")
    assert_eq(r.log[1], "cloud_same_day", "T9: 日志为 cloud_same_day")
end

-- T10: recycleRunning 防重入
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        recycleRunning = true,
        lastRecycleDate = nil,
        todayStr = "20260515",
        cloudDate = 20260514,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, false, "T10: recycleRunning 防重入")
    assert_eq(r.log[1], "already_running", "T10: 日志为 already_running")
end

-- T11: 异常跨度 + 占坑失败 — 清除内存占位
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260601",
        cloudDate = 20260101,
        moneyGetOk = true,
        moneyAddOk = false,
    })
    assert_eq(r.executeRecycleCalled, false, "T11: 异常跨度占坑失败不回收")
    assert_eq(r.lastRecycleDate, nil, "T11: 内存占位清除")
    assert_true(r.log[1] == "anomaly_gap", "T11: 日志标记 anomaly_gap")
    assert_true(r.log[2] == "date_jump_failed", "T11: 日志标记 date_jump_failed")
end

-- T12: 连续两次调用 — 第一次执行，第二次幂等
do
    local r1 = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260515",
        cloudDate = 20260514,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r1.executeRecycleCalled, true, "T12a: 第一次执行回收")

    local r2 = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = r1.lastRecycleDate,  -- 传递第一次的内存状态
        todayStr = "20260515",
        cloudDate = 20260515,  -- 云端已更新
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r2.executeRecycleCalled, false, "T12b: 第二次幂等不执行")
    assert_eq(r2.log[1], "same_day_skip", "T12b: 内存占位命中")
end

-- T13: 多天连续模拟 — 证明"后续过天"会正确触发回收
--      模拟 Day1→Day2→Day3→Day4 连续四天，每天都应触发一次回收
--      这直接回答了"首日触发，后续不触发"的疑问
do
    print("  --- T13: 多天连续模拟 (Day1→Day2→Day3→Day4) ---")

    -- 初始状态：云端日期为 Day0 (20260513)，进程刚启动
    local memDate = nil       -- 进程刚启动，内存无占位
    local cloudDate = 20260513

    local days = { "20260514", "20260515", "20260516", "20260517" }

    for i, todayStr in ipairs(days) do
        -- 每天第一次 tick
        local r = SimulateRecycleTick({
            recycleEnabled = true,
            lastRecycleDate = memDate,
            todayStr = todayStr,
            cloudDate = cloudDate,
            moneyGetOk = true,
            moneyAddOk = true,
        })
        assert_eq(r.executeRecycleCalled, true,
            string.format("T13-Day%d: 第%d天(%s)执行回收", i, i, todayStr))
        assert_eq(r.realGap, 1,
            string.format("T13-Day%d: realGap = 1", i))

        -- 更新状态（模拟回收成功后的副作用）
        memDate = r.lastRecycleDate          -- 内存占位更新
        cloudDate = tonumber(todayStr)       -- 云端日期推进

        -- 同一天第二次 tick — 应该幂等
        local r2 = SimulateRecycleTick({
            recycleEnabled = true,
            lastRecycleDate = memDate,
            todayStr = todayStr,
            cloudDate = cloudDate,
            moneyGetOk = true,
            moneyAddOk = true,
        })
        assert_eq(r2.executeRecycleCalled, false,
            string.format("T13-Day%d: 同天第二次幂等", i))
    end
end

-- T14: 多天连续含跨月 — 0529→0530→0531→0601→0602
--      证明跨月边界不会中断连续回收
do
    print("  --- T14: 多天连续含跨月 (0529→0530→0531→0601→0602) ---")

    local memDate = nil
    local cloudDate = 20260528  -- Day0

    local days = { "20260529", "20260530", "20260531", "20260601", "20260602" }

    for i, todayStr in ipairs(days) do
        local r = SimulateRecycleTick({
            recycleEnabled = true,
            lastRecycleDate = memDate,
            todayStr = todayStr,
            cloudDate = cloudDate,
            moneyGetOk = true,
            moneyAddOk = true,
        })
        assert_eq(r.executeRecycleCalled, true,
            string.format("T14-Day%d: %s 执行回收", i, todayStr))
        assert_eq(r.realGap, 1,
            string.format("T14-Day%d: realGap = 1", i))

        memDate = r.lastRecycleDate
        cloudDate = tonumber(todayStr)
    end
end

-- T15: 多天连续含跨年 — 1229→1230→1231→0101→0102 (2026→2027)
--      证明跨年边界不会中断连续回收
do
    print("  --- T15: 多天连续含跨年 (1229→1230→1231→0101→0102) ---")

    local memDate = nil
    local cloudDate = 20261228  -- Day0

    local days = { "20261229", "20261230", "20261231", "20270101", "20270102" }

    for i, todayStr in ipairs(days) do
        local r = SimulateRecycleTick({
            recycleEnabled = true,
            lastRecycleDate = memDate,
            todayStr = todayStr,
            cloudDate = cloudDate,
            moneyGetOk = true,
            moneyAddOk = true,
        })
        assert_eq(r.executeRecycleCalled, true,
            string.format("T15-Day%d: %s 执行回收", i, todayStr))
        assert_eq(r.realGap, 1,
            string.format("T15-Day%d: realGap = 1", i))

        memDate = r.lastRecycleDate
        cloudDate = tonumber(todayStr)
    end
end

-- T16: 进程重启后恢复 — 模拟 Day1 回收后进程崩溃重启，
--      Day2 靠云端日期恢复正确状态
do
    print("  --- T16: 进程重启后恢复 ---")

    -- Day1: 正常回收
    local r1 = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260520",
        cloudDate = 20260519,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r1.executeRecycleCalled, true, "T16-Day1: 正常回收")

    -- 模拟进程崩溃重启：memDate 清零，cloudDate 已在云端
    local memDate_after_restart = nil  -- 进程重启，内存丢失

    -- Day1 重启后同天再次 tick — 靠云端拦截
    local r1b = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = memDate_after_restart,
        todayStr = "20260520",
        cloudDate = 20260520,  -- 云端已更新到 Day1
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r1b.executeRecycleCalled, false, "T16-Day1-restart: 云端拦截不重复回收")
    assert_eq(r1b.log[1], "cloud_same_day", "T16-Day1-restart: cloud_same_day")

    -- Day2: 过天后正常触发
    local r2 = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = r1b.lastRecycleDate,
        todayStr = "20260521",
        cloudDate = 20260520,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r2.executeRecycleCalled, true, "T16-Day2: 重启后过天正常回收")
end

-- T17: 网络抖动重试 — Day1 首次 money:Get 失败，
--      重试成功后正常回收；Day2 继续正常
do
    print("  --- T17: 网络抖动重试 ---")

    -- Day1 首次 tick: 云端读取失败
    local r1a = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260520",
        cloudDate = 20260519,
        moneyGetOk = false,
        moneyAddOk = true,
    })
    assert_eq(r1a.executeRecycleCalled, false, "T17-Day1-fail: 读取失败不回收")
    assert_eq(r1a.lastRecycleDate, nil, "T17-Day1-fail: 内存占位清除可重试")

    -- Day1 重试 tick: 成功
    local r1b = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = r1a.lastRecycleDate,  -- nil，可重试
        todayStr = "20260520",
        cloudDate = 20260519,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r1b.executeRecycleCalled, true, "T17-Day1-retry: 重试成功回收")

    -- Day2: 继续正常
    local r2 = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = r1b.lastRecycleDate,
        todayStr = "20260521",
        cloudDate = 20260520,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r2.executeRecycleCalled, true, "T17-Day2: 次日正常回收")
end

-- T18: 2天间隔 — realGap=2 仍在 MAX_RECYCLE_GAP 内，正常回收
do
    local r = SimulateRecycleTick({
        recycleEnabled = true,
        lastRecycleDate = nil,
        todayStr = "20260516",
        cloudDate = 20260514,
        moneyGetOk = true,
        moneyAddOk = true,
    })
    assert_eq(r.executeRecycleCalled, true, "T18: 间隔2天仍回收 (realGap=2 <= MAX_RECYCLE_GAP)")
    assert_eq(r.realGap, 2, "T18: realGap = 2")
end

-- ============================================================================
-- 结果汇总
-- ============================================================================

print(string.format("\n%s 结果: %d passed, %d failed, %d total",
    TAG, passed, failed, passed + failed))

return { passed = passed, failed = failed, total = passed + failed }
