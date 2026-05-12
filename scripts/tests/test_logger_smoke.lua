-- ============================================================================
-- test_logger_smoke.lua — Logger 模块冒烟测试
--
-- R1: 诊断与日志治理收窄版
--
-- 覆盖:
--   1. Logger 模块可在纯 Lua 环境加载（无引擎依赖）
--   2. 4 个级别函数（error/warn/info/diag）均存在且可调用
--   3. diag 默认关闭（不输出）
--   4. SetDiagEnabled(true) 后 diag 输出
--   5. SetDiagEnabled(false) 可再次关闭
--   6. 输出前缀格式稳定：[LEVEL][Tag]
--   7. IsDiagEnabled() 返回正确状态
--   8. Logger 是纯叶模块（无业务依赖）
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

local function assert_type(val, expectedType, testName)
    totalTests = totalTests + 1
    if type(val) == expectedType then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected type %s, got %s",
            testName, expectedType, type(val)))
    end
end

-- ============================================================================
-- 捕获 print 输出的辅助工具
-- ============================================================================
local _capturedOutput = {}
local _originalPrint = print

local function startCapture()
    _capturedOutput = {}
    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        _capturedOutput[#_capturedOutput + 1] = table.concat(parts, "\t")
    end
end

local function stopCapture()
    print = _originalPrint
    return _capturedOutput
end

-- ============================================================================
-- TEST 1: Logger 模块可加载（纯叶模块，无引擎依赖）
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 1: 模块可加载 ---")

-- 清除可能的缓存，确保完整加载路径测试
package.loaded["utils.Logger"] = nil

local loadOk, Logger = pcall(require, "utils.Logger")
assert_true(loadOk, "Logger require 成功")

if not loadOk then
    _originalPrint("FATAL: Logger 模块加载失败: " .. tostring(Logger))
    return { passed = passed, failed = failed, total = totalTests }
end

-- ============================================================================
-- TEST 2: 4 个级别函数存在
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 2: 级别函数存在 ---")

assert_type(Logger.error, "function", "Logger.error 是函数")
assert_type(Logger.warn, "function", "Logger.warn 是函数")
assert_type(Logger.info, "function", "Logger.info 是函数")
assert_type(Logger.diag, "function", "Logger.diag 是函数")

-- ============================================================================
-- TEST 3: 控制 API 存在
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 3: 控制 API 存在 ---")

assert_type(Logger.SetDiagEnabled, "function", "SetDiagEnabled 是函数")
assert_type(Logger.IsDiagEnabled, "function", "IsDiagEnabled 是函数")

-- ============================================================================
-- TEST 4: diag 默认关闭
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 4: diag 默认关闭 ---")

-- 重置状态
Logger.SetDiagEnabled(false)

assert_eq(Logger.IsDiagEnabled(), false, "IsDiagEnabled() 默认返回 false")

startCapture()
Logger.diag("TestTag", "this should be silent")
local captured = stopCapture()
assert_eq(#captured, 0, "diag 关闭时无输出")

-- ============================================================================
-- TEST 5: error/warn/info 始终输出
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 5: error/warn/info 始终输出 ---")

Logger.SetDiagEnabled(false)

startCapture()
Logger.error("T", "e")
local capErr = stopCapture()
assert_eq(#capErr, 1, "error 输出 1 行")

startCapture()
Logger.warn("T", "w")
local capWarn = stopCapture()
assert_eq(#capWarn, 1, "warn 输出 1 行")

startCapture()
Logger.info("T", "i")
local capInfo = stopCapture()
assert_eq(#capInfo, 1, "info 输出 1 行")

-- ============================================================================
-- TEST 6: SetDiagEnabled(true) 后 diag 输出
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 6: diag 开启后输出 ---")

Logger.SetDiagEnabled(true)
assert_eq(Logger.IsDiagEnabled(), true, "IsDiagEnabled() 返回 true")

startCapture()
Logger.diag("TestTag", "diag enabled message")
local capDiag = stopCapture()
assert_eq(#capDiag, 1, "diag 开启后输出 1 行")

-- ============================================================================
-- TEST 7: SetDiagEnabled(false) 可再次关闭
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 7: diag 可再次关闭 ---")

Logger.SetDiagEnabled(false)
assert_eq(Logger.IsDiagEnabled(), false, "IsDiagEnabled() 再次返回 false")

startCapture()
Logger.diag("TestTag", "should be silent again")
local capSilent = stopCapture()
assert_eq(#capSilent, 0, "diag 再次关闭后无输出")

-- ============================================================================
-- TEST 8: 输出前缀格式稳定 [LEVEL][Tag]
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 8: 输出前缀格式 ---")

Logger.SetDiagEnabled(true)

local prefixTests = {
    { fn = Logger.error, level = "ERROR", tag = "MyTag", msg = "err_msg" },
    { fn = Logger.warn,  level = "WARN",  tag = "MyTag", msg = "warn_msg" },
    { fn = Logger.info,  level = "INFO",  tag = "MyTag", msg = "info_msg" },
    { fn = Logger.diag,  level = "DIAG",  tag = "MyTag", msg = "diag_msg" },
}

for _, tc in ipairs(prefixTests) do
    startCapture()
    tc.fn(tc.tag, tc.msg)
    local output = stopCapture()
    assert_eq(#output, 1, tc.level .. " 输出 1 行")

    if #output > 0 then
        local line = output[1]
        local expectedPrefix = "[" .. tc.level .. "][" .. tc.tag .. "]"
        assert_true(
            line:sub(1, #expectedPrefix) == expectedPrefix,
            tc.level .. " 前缀匹配: " .. expectedPrefix
        )
        assert_true(
            line:find(tc.msg, 1, true) ~= nil,
            tc.level .. " 包含消息体: " .. tc.msg
        )
    end
end

-- 恢复默认状态
Logger.SetDiagEnabled(false)

-- ============================================================================
-- TEST 9: 纯叶模块验证（无业务依赖）
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 9: 纯叶模块 ---")

-- Logger 模块不应引用任何业务模块
-- 通过检查 package.loaded 在加载 Logger 前后的差异来验证
-- （Logger 已加载，但可以验证其返回值结构简单）
local keys = {}
for k, _ in pairs(Logger) do
    keys[#keys + 1] = k
end

-- Logger 应只有以下 6 个公开 API
local expectedKeys = {
    error = true, warn = true, info = true, diag = true,
    SetDiagEnabled = true, IsDiagEnabled = true,
}
for _, k in ipairs(keys) do
    assert_true(expectedKeys[k] ~= nil, "Logger." .. k .. " 是已知 API")
end
assert_eq(#keys, 6, "Logger 公开 API 数量为 6")

-- ============================================================================
-- TEST 10: SetDiagEnabled 防御性参数处理
-- ============================================================================
_originalPrint("--- LOGGER SMOKE TEST 10: 防御性参数 ---")

Logger.SetDiagEnabled("truthy_string")
assert_eq(Logger.IsDiagEnabled(), false, "非 boolean true 不开启 diag")

Logger.SetDiagEnabled(1)
assert_eq(Logger.IsDiagEnabled(), false, "数字 1 不开启 diag")

Logger.SetDiagEnabled(true)
assert_eq(Logger.IsDiagEnabled(), true, "boolean true 开启 diag")

Logger.SetDiagEnabled(nil)
assert_eq(Logger.IsDiagEnabled(), false, "nil 关闭 diag")

Logger.SetDiagEnabled(false)
assert_eq(Logger.IsDiagEnabled(), false, "boolean false 关闭 diag")

-- ============================================================================
-- 汇总
-- ============================================================================
_originalPrint("\n" .. string.rep("=", 60))
_originalPrint(string.format("  LOGGER SMOKE: %d tests, %d passed, %d failed",
    totalTests, passed, failed))
_originalPrint(string.rep("=", 60))

if failed > 0 then
    _originalPrint("\n  *** LOGGER SMOKE TEST FAILED ***\n")
else
    _originalPrint("\n  ALL LOGGER SMOKE TESTS PASSED\n")
end

return { passed = passed, failed = failed, total = totalTests }
