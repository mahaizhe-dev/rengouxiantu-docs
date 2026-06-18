-- ============================================================================
-- run_baseline.lua — headless 测试基线运行器（UrhoXRuntime tool_mode）
--
-- 用途：在沙箱无独立 lua 解释器时，借引擎 runtime 跑测试门禁，
--       为背包 UI 重构（附录 M.10.3）建立"重构前"基线。
--
-- 调用：
--   cd /workspace && ./.cli/UrhoXRuntime _proc/run_baseline.lua \
--       -tapcode_dir=/workspace -tool_mode
--
-- 复刻 scripts/tests/run_all.lua 的 blocking gate 逻辑，
-- 但用 engine:Exit() 替代 os.exit()（runtime 入口要求）。
-- ============================================================================

function Start()
    local ok, err = pcall(function()
        package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

        local TestRegistry = require("tests.TestRegistry")
        local TestRunner   = require("tests.TestRunner")

        print("================================================================")
        print("  背包 UI 重构 — BLOCKING 门禁基线 (附录 M.10.3)")
        print("================================================================")

        local tests = TestRegistry.GetBlocking()
        print(string.format("[BASELINE] blocking tests = %d", #tests))
        print("")

        local results = TestRunner.Run(tests)
        local executed = results.passed + results.failed

        print("")
        if results.failed > 0 then
            print("BASELINE_RESULT=FAILURE")
        elseif executed == 0 then
            print("BASELINE_RESULT=EMPTY")
        else
            print("BASELINE_RESULT=SUCCESS")
        end
        print(string.format("BASELINE_STATS total=%d executed=%d passed=%d failed=%d skipped=%d",
            results.total, results.executed, results.passed, results.failed, results.skipped))
    end)

    if not ok then
        print("BASELINE_RESULT=ERROR")
        print("[run-baseline] FATAL: " .. tostring(err))
        if log then log:Write(LOG_ERROR, "[run-baseline] " .. tostring(err)) end
    end

    engine:Exit()
end
