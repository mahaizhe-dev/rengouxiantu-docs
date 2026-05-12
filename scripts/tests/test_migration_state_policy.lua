-- ============================================================================
-- test_migration_state_policy.lua — MigrationPolicy 模块纯 Lua 测试
--
-- P0-4: 迁移入口收敛与废弃迁移分支冻结
--
-- 覆盖：
--   1. 模块可加载
--   2. 状态枚举完整性（5 种状态）
--   3. flag=false 时 Evaluate 返回 nil（不干预原有逻辑）
--   4. flag=true 时迁移状态矩阵（needMigration × slotCount）
--   5. ShouldBlockEntry 对所有状态返回 false（迁移已废弃）
--   6. ShouldAutoMigrate 对所有状态返回 false（迁移已废弃）
--   7. IsPCMigrationCheckNeeded: flag=false→true, flag=true→false
--   8. GetStateLabel 对所有状态返回非空字符串
--   9. flag 开关切换不影响另一条路径
--  10. _resetForTest 重置全局状态
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

local function assert_nil(val, testName)
    totalTests = totalTests + 1
    if val == nil then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected nil, got %s",
            testName, tostring(val)))
    end
end

local function assert_not_nil(val, testName)
    totalTests = totalTests + 1
    if val ~= nil then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected non-nil, got nil", testName))
    end
end

-- ============================================================================
-- 加载依赖
-- ============================================================================
print("--- MP TEST 1: MigrationPolicy 可加载 ---")

local ok_ff, FF = pcall(require, "config.FeatureFlags")
assert_true(ok_ff, "FeatureFlags require 成功")

local ok_mp, MP = pcall(require, "network.MigrationPolicy")
assert_true(ok_mp, "MigrationPolicy require 成功")

if not ok_mp then
    print("MigrationPolicy 加载失败，跳过所有后续测试")
    return { passed = passed, failed = failed, total = totalTests }
end

-- 每个测试前重置状态
local function resetAll()
    FF._resetForTest()
    MP._resetForTest()
end

-- ============================================================================
-- TEST 2: 状态枚举完整性
-- ============================================================================
print("--- MP TEST 2: 状态枚举完整性 ---")

resetAll()

local S = MP.State
assert_not_nil(S, "State 表存在")
assert_eq(S.MIGRATION_DISABLED, "migration_disabled", "MIGRATION_DISABLED 值正确")
assert_eq(S.NOT_NEEDED, "not_needed", "NOT_NEEDED 值正确")
assert_eq(S.ELIGIBLE_CLIENT_CLOUD, "eligible_client_cloud", "ELIGIBLE_CLIENT_CLOUD 值正确")
assert_eq(S.ELIGIBLE_LOCAL_FILE, "eligible_local_file", "ELIGIBLE_LOCAL_FILE 值正确")
assert_eq(S.ALREADY_MIGRATED, "already_migrated", "ALREADY_MIGRATED 值正确")

local allStates = MP.GetAllStates()
assert_eq(#allStates, 5, "共 5 种状态")

-- ============================================================================
-- TEST 3: flag=false 时 Evaluate 返回 nil
-- ============================================================================
print("--- MP TEST 3: flag=false → Evaluate 返回 nil ---")

resetAll()
-- 确认 flag 默认为 false
assert_false(FF.isEnabled("SAVE_MIGRATION_SINGLE_ENTRY"), "flag 默认 false")
assert_false(MP.IsEnabled(), "MP.IsEnabled() 默认 false")

-- 各种输入组合都应返回 nil
assert_nil(MP.Evaluate(true, 0), "flag=false, needMigration=true, slots=0 → nil")
assert_nil(MP.Evaluate(false, 0), "flag=false, needMigration=false, slots=0 → nil")
assert_nil(MP.Evaluate(true, 2), "flag=false, needMigration=true, slots=2 → nil")
assert_nil(MP.Evaluate(false, 3), "flag=false, needMigration=false, slots=3 → nil")

-- ============================================================================
-- TEST 4: flag=true 时迁移状态矩阵
-- ============================================================================
print("--- MP TEST 4: flag=true 迁移状态矩阵 ---")

resetAll()
FF.setOverride("SAVE_MIGRATION_SINGLE_ENTRY", true)
assert_true(MP.IsEnabled(), "flag 启用后 MP.IsEnabled()=true")

-- 迁移全局已废弃(MIGRATION_GLOBALLY_ENABLED=false)，所有输入组合应返回 MIGRATION_DISABLED
assert_eq(MP.Evaluate(true, 0), S.MIGRATION_DISABLED,
    "needMigration=true, slots=0, global=false → DISABLED")
assert_eq(MP.Evaluate(false, 0), S.MIGRATION_DISABLED,
    "needMigration=false, slots=0, global=false → DISABLED")
assert_eq(MP.Evaluate(true, 2), S.MIGRATION_DISABLED,
    "needMigration=true, slots=2, global=false → DISABLED")
assert_eq(MP.Evaluate(false, 3), S.MIGRATION_DISABLED,
    "needMigration=false, slots=3, global=false → DISABLED")

-- ============================================================================
-- TEST 5: flag=true + 假设迁移重新启用时的状态判断
-- ============================================================================
print("--- MP TEST 5: flag=true + 迁移启用假设 ---")

resetAll()
FF.setOverride("SAVE_MIGRATION_SINGLE_ENTRY", true)
MP._setGlobalEnabled(true)  -- 测试用：模拟迁移重新启用

-- 有存档 → NOT_NEEDED
assert_eq(MP.Evaluate(false, 2), S.NOT_NEEDED,
    "needMigration=false, slots=2, global=true → NOT_NEEDED")
assert_eq(MP.Evaluate(false, 1), S.NOT_NEEDED,
    "needMigration=false, slots=1, global=true → NOT_NEEDED")

-- needMigration=true 但有存档 → NOT_NEEDED（防御性：服务端异常时以槽位数为准）
assert_eq(MP.Evaluate(true, 1), S.NOT_NEEDED,
    "needMigration=true, slots=1, global=true → NOT_NEEDED")
assert_eq(MP.Evaluate(true, 4), S.NOT_NEEDED,
    "needMigration=true, slots=4, global=true → NOT_NEEDED")

-- needMigration=false, slots=0 → NOT_NEEDED（无迁移标记）
assert_eq(MP.Evaluate(false, 0), S.NOT_NEEDED,
    "needMigration=false, slots=0, global=true → NOT_NEEDED")

resetAll()

-- ============================================================================
-- TEST 6: ShouldBlockEntry 对所有状态返回 false
-- ============================================================================
print("--- MP TEST 6: ShouldBlockEntry 全部 false ---")

resetAll()

-- nil（flag=false 时）
assert_false(MP.ShouldBlockEntry(nil), "ShouldBlockEntry(nil) → false")

-- 所有枚举状态
for _, state in ipairs(MP.GetAllStates()) do
    assert_false(MP.ShouldBlockEntry(state),
        "ShouldBlockEntry(" .. state .. ") → false")
end

-- ============================================================================
-- TEST 7: ShouldAutoMigrate 对所有状态返回 false
-- ============================================================================
print("--- MP TEST 7: ShouldAutoMigrate 全部 false ---")

resetAll()

for _, state in ipairs(MP.GetAllStates()) do
    assert_false(MP.ShouldAutoMigrate(state),
        "ShouldAutoMigrate(" .. state .. ") → false")
end

-- ============================================================================
-- TEST 8: IsPCMigrationCheckNeeded
-- ============================================================================
print("--- MP TEST 8: IsPCMigrationCheckNeeded ---")

resetAll()

-- flag=false → 保持原有行为 → true（PC 仍拦截）
assert_true(MP.IsPCMigrationCheckNeeded(),
    "flag=false → IsPCMigrationCheckNeeded=true")

-- flag=true → 迁移已废弃 → false（不再拦截 PC）
FF.setOverride("SAVE_MIGRATION_SINGLE_ENTRY", true)
assert_false(MP.IsPCMigrationCheckNeeded(),
    "flag=true → IsPCMigrationCheckNeeded=false")

-- flag=true + 迁移重新启用 → true（需要拦截）
MP._setGlobalEnabled(true)
assert_true(MP.IsPCMigrationCheckNeeded(),
    "flag=true + global=true → IsPCMigrationCheckNeeded=true")

resetAll()

-- ============================================================================
-- TEST 9: GetStateLabel 对所有状态返回非空字符串
-- ============================================================================
print("--- MP TEST 9: GetStateLabel ---")

resetAll()

-- nil → 特殊标签
local nilLabel = MP.GetStateLabel(nil)
assert_true(type(nilLabel) == "string" and #nilLabel > 0,
    "GetStateLabel(nil) 返回非空字符串")

-- 所有枚举状态
for _, state in ipairs(MP.GetAllStates()) do
    local label = MP.GetStateLabel(state)
    assert_true(type(label) == "string" and #label > 0,
        "GetStateLabel(" .. state .. ") 返回非空字符串")
end

-- 未知状态
local unknownLabel = MP.GetStateLabel("some_unknown_state")
assert_true(type(unknownLabel) == "string" and #unknownLabel > 0,
    "GetStateLabel(unknown) 返回非空字符串")

-- ============================================================================
-- TEST 10: flag 切换不交叉影响
-- ============================================================================
print("--- MP TEST 10: flag 切换隔离 ---")

resetAll()

-- 启用 flag → Evaluate 返回非 nil
FF.setOverride("SAVE_MIGRATION_SINGLE_ENTRY", true)
local s1 = MP.Evaluate(true, 0)
assert_not_nil(s1, "flag=true → Evaluate 返回非 nil")

-- 关闭 flag → Evaluate 回到 nil
FF.clearOverride("SAVE_MIGRATION_SINGLE_ENTRY")
local s2 = MP.Evaluate(true, 0)
assert_nil(s2, "flag 关闭后 → Evaluate 回到 nil")

-- 再次启用 → 又恢复
FF.setOverride("SAVE_MIGRATION_SINGLE_ENTRY", true)
local s3 = MP.Evaluate(true, 0)
assert_not_nil(s3, "flag 再次启用 → Evaluate 又返回非 nil")

resetAll()

-- ============================================================================
-- TEST 11: _resetForTest 重置全局状态
-- ============================================================================
print("--- MP TEST 11: _resetForTest ---")

MP._setGlobalEnabled(true)
FF.setOverride("SAVE_MIGRATION_SINGLE_ENTRY", true)

-- 验证启用状态
assert_true(MP.IsPCMigrationCheckNeeded(), "reset前: global=true → PC check needed")

-- 重置
MP._resetForTest()
FF._resetForTest()

-- 验证回到默认
assert_true(MP.IsPCMigrationCheckNeeded(), "reset后: 回到默认 → PC check needed (flag=false保持原行为)")
assert_false(MP.IsEnabled(), "reset后: IsEnabled=false")

-- ============================================================================
-- 汇总
-- ============================================================================
print("\n" .. string.rep("=", 60))
print(string.format("  MIGRATION POLICY: %d tests, %d passed, %d failed",
    totalTests, passed, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("\n  *** MIGRATION POLICY TEST FAILED ***\n")
else
    print("\n  ALL MIGRATION POLICY TESTS PASSED\n")
end

return { passed = passed, failed = failed, total = totalTests }
