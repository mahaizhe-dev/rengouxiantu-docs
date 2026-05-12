-- ============================================================================
-- test_runner_smoke.lua — Runner 冒烟测试
--
-- P0-1: 验证测试基础设施自身工作正常
--
-- 覆盖:
--   1. TestRegistry 可加载
--   2. 一个 PASS 用例能记为 pass
--   3. 一个 FAIL 用例能记为 fail
--   4. 一个 SKIP 用例能记为 skip
--   5. TestRunner 统计正确
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

local function assert_eq(actual, expected, testName)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected %s, got %s",
            testName, tostring(expected), tostring(actual)))
    end
end

local function assert_true(cond, testName)
    totalTests = totalTests + 1
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — condition is false", testName))
    end
end

-- ============================================================================
-- TEST 1: TestRegistry 可加载
-- ============================================================================
print("--- SMOKE TEST 1: TestRegistry 可加载 ---")

local regOk, TestRegistry = pcall(require, "tests.TestRegistry")
assert_true(regOk, "TestRegistry require 成功")

if regOk then
    assert_true(type(TestRegistry.tests) == "table", "TestRegistry.tests 是 table")
    assert_true(#TestRegistry.tests > 0, "TestRegistry.tests 非空")
    assert_true(type(TestRegistry.GetAll) == "function", "GetAll 是函数")
    assert_true(type(TestRegistry.GetByGroup) == "function", "GetByGroup 是函数")
    assert_true(type(TestRegistry.GetEnabled) == "function", "GetEnabled 是函数")
    assert_true(type(TestRegistry.GetGroups) == "function", "GetGroups 是函数")
end

-- ============================================================================
-- TEST 2: TestRunner 可加载
-- ============================================================================
print("--- SMOKE TEST 2: TestRunner 可加载 ---")

local runOk, TestRunner = pcall(require, "tests.TestRunner")
assert_true(runOk, "TestRunner require 成功")

if runOk then
    assert_true(type(TestRunner.Run) == "function", "TestRunner.Run 是函数")
end

-- ============================================================================
-- TEST 3: PASS 用例正确记录
-- ============================================================================
print("--- SMOKE TEST 3: PASS 用例 ---")

if runOk then
    local mockTests = {
        {
            id          = "smoke_pass",
            group       = "smoke",
            mode        = "run_file",
            path        = nil, -- 我们不用 dofile，手动构造
            enabled     = true,
            skip_reason = nil,
        },
    }
    -- 用一个内联的假路径不行，改用 require_runall + 手动注入
    -- 更简单的方案: 直接测试 Runner 对 skip 的处理
    -- 不，任务卡要求验证 PASS，我们构造一个临时 lua 文件

    -- 构造方式: 写一个返回全部通过的模块到 package.loaded
    package.loaded["tests._smoke_pass_mock"] = {
        RunAll = function()
            return 1, 0  -- 1 pass, 0 fail
        end
    }
    mockTests[1].mode  = "require_runall"
    mockTests[1].entry = "tests._smoke_pass_mock"

    local results = TestRunner.Run(mockTests)
    assert_eq(results.passed, 1, "PASS 用例记为 passed")
    assert_eq(results.failed, 0, "PASS 用例 failed=0")
    assert_eq(results.skipped, 0, "PASS 用例 skipped=0")
end

-- ============================================================================
-- TEST 4: FAIL 用例正确记录
-- ============================================================================
print("--- SMOKE TEST 4: FAIL 用例 ---")

if runOk then
    package.loaded["tests._smoke_fail_mock"] = {
        RunAll = function()
            return 2, 1  -- 2 pass, 1 fail
        end
    }
    local mockTests = {
        {
            id          = "smoke_fail",
            group       = "smoke",
            mode        = "require_runall",
            entry       = "tests._smoke_fail_mock",
            enabled     = true,
            skip_reason = nil,
        },
    }

    local results = TestRunner.Run(mockTests)
    assert_eq(results.passed, 0, "FAIL 用例 passed=0（整体判定为 fail）")
    assert_eq(results.failed, 1, "FAIL 用例记为 failed")
    assert_eq(results.skipped, 0, "FAIL 用例 skipped=0")
    assert_eq(#results.failed_cases, 1, "FAIL 用例记入 failed_cases")
end

-- ============================================================================
-- TEST 5: SKIP 用例正确记录
-- ============================================================================
print("--- SMOKE TEST 5: SKIP 用例 ---")

if runOk then
    local mockTests = {
        {
            id          = "smoke_skip",
            group       = "smoke",
            mode        = "skip",
            enabled     = false,
            skip_reason = "engine_required: smoke test mock",
        },
    }

    local results = TestRunner.Run(mockTests)
    assert_eq(results.passed, 0, "SKIP 用例 passed=0")
    assert_eq(results.failed, 0, "SKIP 用例 failed=0")
    assert_eq(results.skipped, 1, "SKIP 用例记为 skipped")
end

-- ============================================================================
-- TEST 6: 异常捕获（pcall 防护）
-- ============================================================================
print("--- SMOKE TEST 6: 异常捕获 ---")

if runOk then
    package.loaded["tests._smoke_crash_mock"] = {
        RunAll = function()
            error("intentional crash for smoke test")
        end
    }
    local mockTests = {
        {
            id          = "smoke_crash",
            group       = "smoke",
            mode        = "require_runall",
            entry       = "tests._smoke_crash_mock",
            enabled     = true,
            skip_reason = nil,
        },
    }

    local results = TestRunner.Run(mockTests)
    assert_eq(results.failed, 1, "异常用例记为 failed")
    assert_true(#results.failed_cases > 0, "异常用例记入 failed_cases")
end

-- ============================================================================
-- TEST 7: group 过滤
-- ============================================================================
print("--- SMOKE TEST 7: group 过滤 ---")

if regOk then
    local saveTests = TestRegistry.GetByGroup("save")
    assert_true(#saveTests > 0, "save group 有测试")
    for _, t in ipairs(saveTests) do
        assert_eq(t.group, "save", "过滤结果 group 一致: " .. t.id)
    end

    local emptyGroup = TestRegistry.GetByGroup("nonexistent_group_xyz")
    assert_eq(#emptyGroup, 0, "不存在的 group 返回空")
end

-- ============================================================================
-- 汇总
-- ============================================================================
print("\n" .. string.rep("=", 60))
print(string.format("  SMOKE: %d tests, %d passed, %d failed",
    totalTests, passed, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("\n  *** SMOKE TEST FAILED ***\n")
else
    print("\n  ALL SMOKE TESTS PASSED\n")
end

-- 清理注入的 mock 模块
package.loaded["tests._smoke_pass_mock"]  = nil
package.loaded["tests._smoke_fail_mock"]  = nil
package.loaded["tests._smoke_crash_mock"] = nil

-- TestRunner 导出（P0-1: 统一测试入口）
return { passed = passed, failed = failed, total = totalTests }
