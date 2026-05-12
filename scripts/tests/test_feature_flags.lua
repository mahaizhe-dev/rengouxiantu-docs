-- ============================================================================
-- test_feature_flags.lua — FeatureFlags 模块纯 Lua 测试
--
-- P0-2: 线上开关与发布护栏
--
-- 覆盖：
--   1. 模块可加载
--   2. 6 个开关默认值全部为 false
--   3. 未定义开关返回 false（安全降级）
--   4. 统一读取 API（isEnabled）正常工作
--   5. 运行时覆盖（setOverride / clearOverride）正常
--   6. 元数据（getMeta）完整性
--   7. 快照（snapshot）正确
--   8. 关闭开关时不影响旧路径（默认行为不变）
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

-- ============================================================================
-- TEST 1: 模块可加载
-- ============================================================================
print("--- FF TEST 1: FeatureFlags 可加载 ---")

local ok, FF = pcall(require, "config.FeatureFlags")
assert_true(ok, "FeatureFlags require 成功")

if not ok then
    print("  FATAL: FeatureFlags 加载失败: " .. tostring(FF))
    return { passed = passed, failed = failed, total = totalTests }
end

assert_true(type(FF) == "table", "FeatureFlags 是 table")
assert_true(type(FF.isEnabled) == "function", "isEnabled 是函数")
assert_true(type(FF.setOverride) == "function", "setOverride 是函数")
assert_true(type(FF.clearOverride) == "function", "clearOverride 是函数")
assert_true(type(FF.clearAllOverrides) == "function", "clearAllOverrides 是函数")
assert_true(type(FF.getMeta) == "function", "getMeta 是函数")
assert_true(type(FF.getAllNames) == "function", "getAllNames 是函数")
assert_true(type(FF.getCount) == "function", "getCount 是函数")
assert_true(type(FF.snapshot) == "function", "snapshot 是函数")

-- ============================================================================
-- TEST 2: 6 个开关全部已注册
-- ============================================================================
print("--- FF TEST 2: 6 个开关已注册 ---")

local EXPECTED_FLAGS = {
    "CLOUDSTORAGE_STRICT_BATCHSET",
    "NEW_MAIN_LOOP_ORCHESTRATOR",
    "NEW_SERVER_ROUTER",
    "SAVE_MIGRATION_SINGLE_ENTRY",
    "SAVE_PIPELINE_V2",
    "SERVER_SAVE_VALIDATOR_V2",
}

assert_eq(FF.getCount(), 6, "已注册 flag 数量 = 6")

local allNames = FF.getAllNames()
table.sort(allNames)
assert_eq(#allNames, #EXPECTED_FLAGS, "getAllNames 返回 6 个名称")

for i, name in ipairs(EXPECTED_FLAGS) do
    assert_eq(allNames[i], name, "flag 名称匹配: " .. name)
end

-- ============================================================================
-- TEST 3: 所有默认值为 false
-- ============================================================================
print("--- FF TEST 3: 所有默认值为 false ---")

FF._resetForTest()  -- 确保无残留覆盖

for _, name in ipairs(EXPECTED_FLAGS) do
    assert_false(FF.isEnabled(name), "默认值 false: " .. name)
end

-- ============================================================================
-- TEST 4: 未定义开关返回 false（安全降级）
-- ============================================================================
print("--- FF TEST 4: 未定义开关安全降级 ---")

assert_false(FF.isEnabled("NONEXISTENT_FLAG"), "未定义 flag 返回 false")
assert_false(FF.isEnabled(""), "空字符串 flag 返回 false")
assert_false(FF.isEnabled("random_name_12345"), "随机名称 flag 返回 false")

-- ============================================================================
-- TEST 5: 统一读取 API（isEnabled）
-- ============================================================================
print("--- FF TEST 5: isEnabled API ---")

FF._resetForTest()

-- 默认全 false
for _, name in ipairs(EXPECTED_FLAGS) do
    assert_eq(FF.isEnabled(name), false, "isEnabled 默认 false: " .. name)
end

-- ============================================================================
-- TEST 6: 运行时覆盖（setOverride）
-- ============================================================================
print("--- FF TEST 6: setOverride ---")

FF._resetForTest()

-- 覆盖一个已注册的 flag
local setOk = FF.setOverride("SAVE_PIPELINE_V2", true)
assert_true(setOk, "setOverride 已注册 flag 返回 true")
assert_true(FF.isEnabled("SAVE_PIPELINE_V2"), "覆盖后 isEnabled 返回 true")

-- 其他 flag 不受影响
assert_false(FF.isEnabled("NEW_SERVER_ROUTER"), "其他 flag 不受影响")

-- 覆盖回 false
FF.setOverride("SAVE_PIPELINE_V2", false)
assert_false(FF.isEnabled("SAVE_PIPELINE_V2"), "覆盖回 false 后 isEnabled 返回 false")

-- 覆盖未注册 flag：必须拒绝且不生效
local setUnknown = FF.setOverride("UNKNOWN_FLAG", true)
assert_false(setUnknown, "setOverride 未注册 flag 返回 false")
assert_false(FF.isEnabled("UNKNOWN_FLAG"), "未注册 flag 覆盖后 isEnabled 仍为 false")

-- 未注册 flag 不污染 snapshot
local snapAfterUnknown = FF.snapshot()
assert_true(snapAfterUnknown["UNKNOWN_FLAG"] == nil, "未注册 flag 不出现在 snapshot 中")

-- 非 boolean 值拒绝
local setBad = FF.setOverride("SAVE_PIPELINE_V2", "yes")
assert_false(setBad, "setOverride 非 boolean 返回 false")

-- 非 boolean 不写入 override（已注册 flag 仍走默认值）
assert_false(FF.isEnabled("SAVE_PIPELINE_V2"), "非 boolean setOverride 后仍为默认 false")

FF._resetForTest()

-- ============================================================================
-- TEST 7: clearOverride
-- ============================================================================
print("--- FF TEST 7: clearOverride ---")

FF._resetForTest()

FF.setOverride("NEW_SERVER_ROUTER", true)
assert_true(FF.isEnabled("NEW_SERVER_ROUTER"), "覆盖后为 true")

FF.clearOverride("NEW_SERVER_ROUTER")
assert_false(FF.isEnabled("NEW_SERVER_ROUTER"), "清除覆盖后恢复默认 false")

-- ============================================================================
-- TEST 8: clearAllOverrides
-- ============================================================================
print("--- FF TEST 8: clearAllOverrides ---")

FF.setOverride("SAVE_PIPELINE_V2", true)
FF.setOverride("NEW_SERVER_ROUTER", true)
FF.setOverride("NEW_MAIN_LOOP_ORCHESTRATOR", true)

assert_true(FF.isEnabled("SAVE_PIPELINE_V2"), "批量覆盖前检查 1")
assert_true(FF.isEnabled("NEW_SERVER_ROUTER"), "批量覆盖前检查 2")

FF.clearAllOverrides()

assert_false(FF.isEnabled("SAVE_PIPELINE_V2"), "clearAll 后恢复默认 1")
assert_false(FF.isEnabled("NEW_SERVER_ROUTER"), "clearAll 后恢复默认 2")
assert_false(FF.isEnabled("NEW_MAIN_LOOP_ORCHESTRATOR"), "clearAll 后恢复默认 3")

-- ============================================================================
-- TEST 9: getMeta 完整性
-- ============================================================================
print("--- FF TEST 9: getMeta 完整性 ---")

FF._resetForTest()

-- 已注册 flag 的元数据
local meta = FF.getMeta("SAVE_PIPELINE_V2")
assert_true(meta ~= nil, "getMeta 已注册 flag 返回非 nil")
assert_eq(meta.name, "SAVE_PIPELINE_V2", "meta.name 正确")
assert_eq(meta.default, false, "meta.default = false")
assert_eq(meta.task, "P0-3", "meta.task = P0-3")
assert_true(type(meta.desc) == "string" and #meta.desc > 0, "meta.desc 非空字符串")

-- 未注册 flag
local metaNil = FF.getMeta("NONEXISTENT")
assert_true(metaNil == nil, "getMeta 未注册 flag 返回 nil")

-- 元数据是只读副本（修改不影响原始注册表）
meta.default = true
local metaAgain = FF.getMeta("SAVE_PIPELINE_V2")
assert_eq(metaAgain.default, false, "getMeta 返回只读副本")

-- ============================================================================
-- TEST 10: 每个 flag 的 task 字段映射正确
-- ============================================================================
print("--- FF TEST 10: flag-task 映射 ---")

local EXPECTED_TASKS = {
    SAVE_PIPELINE_V2            = "P0-3",  -- 存档链路职责收敛
    SERVER_SAVE_VALIDATOR_V2    = "P0-6",  -- 服务端存档事务服务化
    SAVE_MIGRATION_SINGLE_ENTRY = "P0-4",  -- 迁移入口收敛
    NEW_MAIN_LOOP_ORCHESTRATOR  = "P1-1",  -- 客户端主入口编排器拆分
    NEW_SERVER_ROUTER           = "P0-6",  -- 服务端路由/服务化
    CLOUDSTORAGE_STRICT_BATCHSET = "P0-5", -- CloudStorage 语义修正
}

for flagName, expectedTask in pairs(EXPECTED_TASKS) do
    local m = FF.getMeta(flagName)
    assert_true(m ~= nil, "flag 存在: " .. flagName)
    if m then
        assert_eq(m.task, expectedTask, flagName .. " → " .. expectedTask)
    end
end

-- ============================================================================
-- TEST 11: snapshot 正确
-- ============================================================================
print("--- FF TEST 11: snapshot ---")

FF._resetForTest()

local snap = FF.snapshot()
assert_true(type(snap) == "table", "snapshot 返回 table")

-- 默认快照全 false
for _, name in ipairs(EXPECTED_FLAGS) do
    assert_eq(snap[name], false, "snapshot 默认 false: " .. name)
end

-- 覆盖后快照反映覆盖值
FF.setOverride("SAVE_PIPELINE_V2", true)
local snap2 = FF.snapshot()
assert_true(snap2["SAVE_PIPELINE_V2"], "snapshot 反映覆盖: SAVE_PIPELINE_V2=true")
assert_false(snap2["NEW_SERVER_ROUTER"], "snapshot 其他仍 false: NEW_SERVER_ROUTER")

FF._resetForTest()

-- ============================================================================
-- TEST 12: 关闭开关时旧路径逻辑不受影响
-- ============================================================================
print("--- FF TEST 12: 关闭开关 → 旧路径 ---")

FF._resetForTest()

-- 模拟业务代码中的开关分支
local usedOldPath = false
local usedNewPath = false

if FF.isEnabled("SAVE_PIPELINE_V2") then
    usedNewPath = true
else
    usedOldPath = true
end

assert_true(usedOldPath, "默认走旧路径")
assert_false(usedNewPath, "默认不走新路径")

-- 开启后走新路径
FF.setOverride("SAVE_PIPELINE_V2", true)
usedOldPath = false
usedNewPath = false

if FF.isEnabled("SAVE_PIPELINE_V2") then
    usedNewPath = true
else
    usedOldPath = true
end

assert_false(usedOldPath, "开启后不走旧路径")
assert_true(usedNewPath, "开启后走新路径")

FF._resetForTest()

-- ============================================================================
-- 汇总
-- ============================================================================
print("\n" .. string.rep("=", 60))
print(string.format("  FEATURE FLAGS: %d tests, %d passed, %d failed",
    totalTests, passed, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("\n  *** FEATURE FLAGS TEST FAILED ***\n")
else
    print("\n  ALL FEATURE FLAGS TESTS PASSED\n")
end

return { passed = passed, failed = failed, total = totalTests }
