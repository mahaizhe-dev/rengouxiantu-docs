-- ============================================================================
-- test_cloudstorage_network_semantics.lua
--
-- P0-5: CloudStorage 网络模式语义收口
--
-- 纯 Lua 测试，验证：
--   T1. flag=false + 非存档 batch → ok() 被调用（旧行为保持）
--   T2. flag=true  + 非存档 batch → error() 被调用，code=UNSUPPORTED_BATCH
--   T3. flag=true  + 存档 batch   → 尝试走 C2S（非假成功）
--   T4. flag=true  + unsupported  → reason 包含 desc 和 keys
--   T5. flag=false + 存档 batch   → 尝试走 C2S（旧行为不变）
--   T6. ERR_UNSUPPORTED_BATCH 常量稳定
--
-- 注意：测试通过 stub 替代引擎全局（network/SubscribeToEvent/Variant 等），
-- 仅验证 CloudStorage 内部分支逻辑。
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

local function assert_false(cond, testName)
    totalTests = totalTests + 1
    if not cond then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected false, got true", testName))
    end
end

local function assert_match(str, pattern, testName)
    totalTests = totalTests + 1
    if type(str) == "string" and str:find(pattern) then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — string '%s' does not match pattern '%s'",
            testName, tostring(str), pattern))
    end
end

-- ============================================================================
-- Stubs: 模拟引擎全局环境
-- ============================================================================

-- cjson stub
if not cjson then
    ---@diagnostic disable-next-line: lowercase-global
    cjson = {
        encode = function(t) return "{}" end,
        decode = function(s) return {} end,
    }
end

-- Variant stub
if not Variant then
    ---@diagnostic disable-next-line: lowercase-global
    Variant = function(v) return v end
end

-- VariantMap stub
if not VariantMap then
    ---@diagnostic disable-next-line: lowercase-global
    VariantMap = function()
        local m = {}
        local mt = { __newindex = function(t, k, v) rawset(t, k, v) end }
        setmetatable(m, mt)
        return m
    end
end

-- SubscribeToEvent stub
if not SubscribeToEvent then
    ---@diagnostic disable-next-line: lowercase-global
    SubscribeToEvent = function() end
end

-- network stub（默认无连接，存档路径走 error）
local _stubServerConn = nil
if not network then
    ---@diagnostic disable-next-line: lowercase-global
    network = {
        GetServerConnection = function(self)
            return _stubServerConn
        end,
    }
end

-- ============================================================================
-- 加载被测模块
-- ============================================================================

print("--- P0-5 TEST: CloudStorage 网络模式语义收口 ---\n")

-- 先加载 FeatureFlags（已被 CloudStorage require）
local okFF, FF = pcall(require, "config.FeatureFlags")
assert_true(okFF, "FeatureFlags 可加载")
if not okFF then
    print("  FATAL: FeatureFlags 加载失败: " .. tostring(FF))
    return { passed = passed, failed = failed, total = totalTests }
end

-- 加载 CloudStorage
local okCS, CloudStorage = pcall(require, "network.CloudStorage")
assert_true(okCS, "CloudStorage 可加载")
if not okCS then
    print("  FATAL: CloudStorage 加载失败: " .. tostring(CloudStorage))
    return { passed = passed, failed = failed, total = totalTests }
end

-- 切换到网络模式
CloudStorage.SetNetworkMode(true)

-- ============================================================================
-- T1: flag=false + 非存档 batch → ok() 被调用（旧行为保持）
-- ============================================================================
print("--- T1: flag=false + 非存档 batch → ok() ---")

FF._resetForTest()
-- 确保 flag=false（默认值）
assert_false(FF.isEnabled("CLOUDSTORAGE_STRICT_BATCHSET"), "T1: flag 默认 false")

local t1_ok_called = false
local t1_err_called = false

CloudStorage.BatchSet()
    :Set("prev_1", { test = "checkpoint" })
    :Save("checkpoint", {
        ok = function() t1_ok_called = true end,
        error = function(code, reason) t1_err_called = true end,
    })

assert_true(t1_ok_called, "T1: ok() 被调用（旧行为保持）")
assert_false(t1_err_called, "T1: error() 未被调用")

-- ============================================================================
-- T2: flag=true + 非存档 batch → error() 被调用，code=UNSUPPORTED_BATCH
-- ============================================================================
print("--- T2: flag=true + 非存档 batch → error(UNSUPPORTED_BATCH) ---")

FF._resetForTest()
FF.setOverride("CLOUDSTORAGE_STRICT_BATCHSET", true)

local t2_ok_called = false
local t2_err_called = false
local t2_err_code = nil
local t2_err_reason = nil

CloudStorage.BatchSet()
    :Set("prev_1", { test = "checkpoint" })
    :Save("checkpoint", {
        ok = function() t2_ok_called = true end,
        error = function(code, reason)
            t2_err_called = true
            t2_err_code = code
            t2_err_reason = reason
        end,
    })

assert_false(t2_ok_called, "T2: ok() 未被调用（严格模式）")
assert_true(t2_err_called, "T2: error() 被调用")
assert_eq(t2_err_code, CloudStorage.ERR_UNSUPPORTED_BATCH, "T2: error code = UNSUPPORTED_BATCH")

FF._resetForTest()

-- ============================================================================
-- T3: flag=true + 存档 batch → 尝试走 C2S（不走假成功）
-- ============================================================================
print("--- T3: flag=true + 存档 batch → C2S 路径 ---")

FF._resetForTest()
FF.setOverride("CLOUDSTORAGE_STRICT_BATCHSET", true)

local t3_ok_called = false
local t3_err_called = false
local t3_err_code = nil

-- 存档 batch 包含 save_1 key
-- 因为无 server connection，会走 error("No server connection")
CloudStorage.BatchSet()
    :Set("save_1", { player = { level = 10 } })
    :Set("slots_index", { slots = { { id = 1 } } })
    :Save("data_and_index", {
        ok = function() t3_ok_called = true end,
        error = function(code, reason)
            t3_err_called = true
            t3_err_code = code
        end,
    })

-- 存档 batch 不应走假成功路径，而是尝试 C2S
-- 由于无 server connection，会走 error(-1, "No server connection")
assert_false(t3_ok_called, "T3: ok() 未被调用（无连接）")
assert_true(t3_err_called, "T3: error() 被调用（无连接）")
assert_eq(t3_err_code, -1, "T3: error code = -1（连接错误，非 UNSUPPORTED_BATCH）")

FF._resetForTest()

-- ============================================================================
-- T4: flag=true + unsupported → reason 包含 desc 和 keys
-- ============================================================================
print("--- T4: reason 包含 desc 和 keys ---")

FF._resetForTest()
FF.setOverride("CLOUDSTORAGE_STRICT_BATCHSET", true)

local t4_reason = nil

CloudStorage.BatchSet()
    :Set("account_atlas", { version = 1 })
    :SetInt("player_level", 50)
    :Save("atlas", {
        ok = function() end,
        error = function(code, reason) t4_reason = reason end,
    })

assert_true(t4_reason ~= nil, "T4: reason 非 nil")
assert_match(t4_reason, "atlas", "T4: reason 包含 desc")
assert_match(t4_reason, "account_atlas", "T4: reason 包含 key: account_atlas")
assert_match(t4_reason, "player_level", "T4: reason 包含 key: player_level")

FF._resetForTest()

-- ============================================================================
-- T5: flag=false + 存档 batch → C2S（旧行为不变）
-- ============================================================================
print("--- T5: flag=false + 存档 batch → C2S（旧行为） ---")

FF._resetForTest()
-- flag=false（默认）

local t5_ok_called = false
local t5_err_called = false
local t5_err_code = nil

CloudStorage.BatchSet()
    :Set("save_2", { player = { level = 5 } })
    :Save("data_only", {
        ok = function() t5_ok_called = true end,
        error = function(code, reason)
            t5_err_called = true
            t5_err_code = code
        end,
    })

-- 与 T3 相同：无 server connection → error(-1)
assert_false(t5_ok_called, "T5: ok() 未被调用（无连接）")
assert_true(t5_err_called, "T5: error() 被调用（无连接）")
assert_eq(t5_err_code, -1, "T5: error code = -1（旧行为不变）")

-- ============================================================================
-- T6: ERR_UNSUPPORTED_BATCH 常量稳定
-- ============================================================================
print("--- T6: ERR_UNSUPPORTED_BATCH 常量稳定 ---")

assert_eq(CloudStorage.ERR_UNSUPPORTED_BATCH, "UNSUPPORTED_BATCH",
    "T6: 常量值 = 'UNSUPPORTED_BATCH'")
assert_eq(type(CloudStorage.ERR_UNSUPPORTED_BATCH), "string",
    "T6: 常量类型 = string")

-- ============================================================================
-- T7: 无 error callback 时不崩溃
-- ============================================================================
print("--- T7: 无 error callback 时不崩溃 ---")

FF._resetForTest()
FF.setOverride("CLOUDSTORAGE_STRICT_BATCHSET", true)

local t7_ok = pcall(function()
    CloudStorage.BatchSet()
        :Set("prev_1", { test = "no_callback" })
        :Save("test_no_cb", {
            ok = function() end,
            -- 无 error callback
        })
end)
assert_true(t7_ok, "T7: 无 error callback 不崩溃")

-- 连 events 都没有
local t7b_ok = pcall(function()
    CloudStorage.BatchSet()
        :Set("prev_1", { test = "no_events" })
        :Save("test_no_events", nil)
end)
assert_true(t7b_ok, "T7b: events=nil 不崩溃")

FF._resetForTest()

-- ============================================================================
-- T8: Delete 操作也被正确收集到 keys
-- ============================================================================
print("--- T8: Delete 操作出现在 keys ---")

FF._resetForTest()
FF.setOverride("CLOUDSTORAGE_STRICT_BATCHSET", true)

local t8_reason = nil

CloudStorage.BatchSet()
    :Set("slots_index", { slots = {} })
    :Delete("deleted_save_1")
    :Save("delete_char", {
        ok = function() end,
        error = function(code, reason) t8_reason = reason end,
    })

assert_true(t8_reason ~= nil, "T8: reason 非 nil")
assert_match(t8_reason, "slots_index", "T8: reason 包含 Set key")
assert_match(t8_reason, "deleted_save_1", "T8: reason 包含 Delete key")

FF._resetForTest()

-- ============================================================================
-- 清理：恢复单机模式
-- ============================================================================
CloudStorage.SetNetworkMode(false)
FF._resetForTest()

-- ============================================================================
-- 汇总
-- ============================================================================
print("\n" .. string.rep("=", 60))
print(string.format("  CLOUDSTORAGE NETWORK SEMANTICS: %d tests, %d passed, %d failed",
    totalTests, passed, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("\n  *** CLOUDSTORAGE NETWORK SEMANTICS TEST FAILED ***\n")
else
    print("\n  ALL CLOUDSTORAGE NETWORK SEMANTICS TESTS PASSED\n")
end

return { passed = passed, failed = failed, total = totalTests }
