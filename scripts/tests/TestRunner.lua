-- ============================================================================
-- TestRunner.lua — 测试执行器
--
-- P0-1:  统一测试入口与最小 CI 门禁
-- P0-1A: 测试门禁收口与运行环境固化
--
-- 职责:
--   1. 根据 group 过滤测试
--   2. 加载注册表条目
--   3. 执行单测（pcall 捕获异常）
--   4. 统计 total / passed / failed / skipped
--   5. 输出统一格式结果
--   6. 返回结果供 run_all.lua 决定退出码
--
-- 支持的 mode:
--   "run_file"        — dofile(path)，文件须 return { passed, failed, total }
--   "require_runall"  — require(entry).RunAll()，须返回 pass, fail
--   "skip"            — 跳过，记录 skip_reason
-- ============================================================================

local TestRunner = {}

----------------------------------------------------------------------------
-- 内部: 执行单个 run_file 模式测试
----------------------------------------------------------------------------
local function execRunFile(test)
    local result = dofile(test.path)
    if type(result) ~= "table" then
        return false, "run_file did not return a result table"
    end
    local p = result.passed or 0
    local f = result.failed or 0
    local t = result.total  or (p + f)
    if f > 0 then
        return false, string.format("%d/%d sub-test(s) failed", f, t)
    end
    return true, string.format("%d/%d passed", p, t)
end

----------------------------------------------------------------------------
-- 内部: 执行单个 require_runall 模式测试
----------------------------------------------------------------------------
local function execRequireRunAll(test)
    local mod = require(test.entry)
    if not mod then
        return false, "require returned nil"
    end
    if type(mod.RunAll) ~= "function" then
        return false, "module has no RunAll() function"
    end
    local r1, r2, r3 = mod.RunAll()

    -- 适配多种返回模式:
    --   (pass, fail)           — 11 个测试
    --   (bool)                 — test_p0_regression
    --   (bool, pass, fail)     — test_batch_consumable
    if type(r1) == "boolean" then
        if type(r2) == "number" and type(r3) == "number" then
            -- (bool, pass, fail)
            if r3 > 0 then
                return false, string.format("%d sub-test(s) failed", r3)
            end
            return true, string.format("%d passed", r2)
        else
            -- (bool)
            if not r1 then
                return false, "RunAll() returned false"
            end
            return true, "ok"
        end
    elseif type(r1) == "number" then
        -- (pass, fail)
        local pass, fail = r1, r2 or 0
        if fail > 0 then
            return false, string.format("%d sub-test(s) failed", fail)
        end
        return true, string.format("%d passed", pass)
    end

    return false, "RunAll() returned unexpected type: " .. type(r1)
end

----------------------------------------------------------------------------
-- 公开: 执行一组测试
--
-- @param tests  table  TestRegistry 条目数组
-- @param opts   table  可选 { verbose = bool }
-- @return       table  { total, passed, failed, skipped, failed_cases }
----------------------------------------------------------------------------
function TestRunner.Run(tests, opts)
    opts = opts or {}

    local results = {
        total        = 0,
        passed       = 0,
        failed       = 0,
        skipped      = 0,
        executed     = 0,    -- P0-1A: 实际执行的测试数（passed + failed）
        failed_cases = {},
    }

    for _, test in ipairs(tests) do
        results.total = results.total + 1

        -- 打印测试开始
        print(string.format("[TEST] %s", test.id))

        -- skip 模式或 enabled == false
        if test.mode == "skip" or not test.enabled then
            results.skipped = results.skipped + 1
            local reason = test.skip_reason or "disabled"
            print(string.format("[SKIP] %s reason=%s", test.id, reason))
        else
            -- 通过 pcall 执行，捕获所有异常
            local pcallOk, execOk, detail = pcall(function()
                if test.mode == "run_file" then
                    return execRunFile(test)
                elseif test.mode == "require_runall" then
                    return execRequireRunAll(test)
                else
                    return false, "unknown mode: " .. tostring(test.mode)
                end
            end)

            if not pcallOk then
                -- pcall 本身捕获到异常（语法错误、require 失败等）
                results.failed = results.failed + 1
                results.executed = results.executed + 1
                local errMsg = tostring(execOk) -- pcall 第二返回值是错误信息
                results.failed_cases[#results.failed_cases + 1] = {
                    id    = test.id,
                    error = errMsg,
                }
                print(string.format("[FAIL] %s error=%s", test.id, errMsg))
            elseif not execOk then
                -- 测试执行成功但有子测试失败
                results.failed = results.failed + 1
                results.executed = results.executed + 1
                results.failed_cases[#results.failed_cases + 1] = {
                    id    = test.id,
                    error = detail or "unknown",
                }
                print(string.format("[FAIL] %s error=%s", test.id, detail or "unknown"))
            else
                -- 全部通过
                results.passed = results.passed + 1
                results.executed = results.executed + 1
                print(string.format("[PASS] %s (%s)", test.id, detail or "ok"))
            end
        end
    end

    -- 打印汇总
    print("")
    print(string.format("[SUMMARY] total=%d executed=%d passed=%d failed=%d skipped=%d",
        results.total, results.executed, results.passed, results.failed, results.skipped))

    if #results.failed_cases > 0 then
        print("")
        print("[FAILED CASES]")
        for _, fc in ipairs(results.failed_cases) do
            print(string.format("  - %s: %s", fc.id, fc.error))
        end
    end

    return results
end

return TestRunner
