-- ============================================================================
-- test_admin_penalty_control.lua — AdminPenaltyControl 纯逻辑单元测试
--
-- 覆盖：
--   1. IsDenyLogin 对配置中的 UID 返回正确值
--   2. IsSuppressRank 对配置中的 UID 返回正确值
--   3. IsPunishOnce 对配置中的 UID 返回正确值
--   4. 对不在配置中的 UID，所有 Is* 返回 false
--   5. GetSuppressedUids 返回正确集合
--   6. FilterRankList 正确过滤 suppressRank 用户
--   7. FilterRankList 处理空列表
--   8. FilterRankList 不误杀正常用户
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
-- Setup: require 模块
-- ============================================================================

local okConfig, Config = pcall(require, "config.AdminPenaltyConfig")
assert_true(okConfig, "AdminPenaltyConfig require 成功")

local okCtrl, Ctrl = pcall(require, "network.AdminPenaltyControl")
assert_true(okCtrl, "AdminPenaltyControl require 成功")

if not okConfig or not okCtrl then
    print("\n  *** 模块加载失败，无法继续测试 ***")
    return { passed = passed, failed = failed, total = totalTests }
end

-- 测试用的已知处罚 UID
local PENALIZED_UID = 1364895230
local CLEAN_UID     = 9999999999  -- 不存在于配置中

-- ============================================================================
-- TEST 1: IsDenyLogin
-- ============================================================================
print("--- TEST 1: IsDenyLogin ---")

-- Phase 1 配置中 denyLogin=false
assert_eq(Ctrl.IsDenyLogin(PENALIZED_UID), false, "处罚UID denyLogin=false (Phase1)")
assert_eq(Ctrl.IsDenyLogin(CLEAN_UID), false, "正常UID denyLogin=false")
assert_eq(Ctrl.IsDenyLogin(0), false, "UID=0 denyLogin=false")

-- ============================================================================
-- TEST 2: IsSuppressRank
-- ============================================================================
print("--- TEST 2: IsSuppressRank ---")

assert_eq(Ctrl.IsSuppressRank(PENALIZED_UID), true, "处罚UID suppressRank=true")
assert_eq(Ctrl.IsSuppressRank(CLEAN_UID), false, "正常UID suppressRank=false")
assert_eq(Ctrl.IsSuppressRank(0), false, "UID=0 suppressRank=false")

-- ============================================================================
-- TEST 3: IsPunishOnce
-- ============================================================================
print("--- TEST 3: IsPunishOnce ---")

assert_eq(Ctrl.IsPunishOnce(PENALIZED_UID), true, "处罚UID punishOnce=true")
assert_eq(Ctrl.IsPunishOnce(CLEAN_UID), false, "正常UID punishOnce=false")

-- ============================================================================
-- TEST 4: GetSuppressedUids
-- ============================================================================
print("--- TEST 4: GetSuppressedUids ---")

local suppressedSet = Ctrl.GetSuppressedUids()
assert_true(type(suppressedSet) == "table", "GetSuppressedUids 返回 table")
assert_eq(suppressedSet[tostring(PENALIZED_UID)], true, "处罚UID(string key) 在集合中")
assert_eq(suppressedSet[tostring(CLEAN_UID)], nil, "正常UID(string key) 不在集合中")

-- ============================================================================
-- TEST 5: FilterRankList — 过滤被处罚用户
-- ============================================================================
print("--- TEST 5: FilterRankList 过滤处罚用户 ---")

local mockRankList = {
    { userId = 111111, score = 100, rank = 1 },
    { userId = PENALIZED_UID, score = 99999, rank = 2 },
    { userId = 333333, score = 80, rank = 3 },
}

local filtered = Ctrl.FilterRankList(mockRankList)
assert_eq(#filtered, 2, "过滤后剩余 2 条")
assert_eq(filtered[1].userId, 111111, "第1名未变")
assert_eq(filtered[2].userId, 333333, "第2名正确（原第3名升上来）")

-- ============================================================================
-- TEST 5.5: FilterRankList — rankKey 为 xianshi_rank 时不过滤（KEEP_VISIBLE）
-- ============================================================================
print("--- TEST 5.5: FilterRankList xianshi_rank 豁免 ---")

local xianshiList = {
    { userId = 111111, score = 5000, rank = 1 },
    { userId = PENALIZED_UID, score = 0, rank = 2 },
    { userId = 333333, score = 3000, rank = 3 },
}

local xianshiFiltered = Ctrl.FilterRankList(xianshiList, "xianshi_rank")
assert_eq(#xianshiFiltered, 3, "xianshi_rank: 处罚UID仍保留")
assert_eq(xianshiFiltered[2].userId, PENALIZED_UID, "xianshi_rank: 处罚UID在第2位")

-- 同样的列表，用 trial_floor 查询则被过滤
local trialFiltered = Ctrl.FilterRankList(xianshiList, "trial_floor")
assert_eq(#trialFiltered, 2, "trial_floor: 处罚UID被过滤")

-- rankKey 为 nil 时走默认过滤逻辑（向后兼容）
local nilKeyFiltered = Ctrl.FilterRankList(xianshiList, nil)
assert_eq(#nilKeyFiltered, 2, "rankKey=nil: 处罚UID被过滤")

-- rankKey 为非豁免的其他 key 也过滤
local otherKeyFiltered = Ctrl.FilterRankList(xianshiList, "rank2_score_1")
assert_eq(#otherKeyFiltered, 2, "rank2_score_1: 处罚UID被过滤")

-- ============================================================================
-- TEST 6: FilterRankList — 空列表处理
-- ============================================================================
print("--- TEST 6: FilterRankList 空列表 ---")

local emptyResult = Ctrl.FilterRankList({})
assert_eq(#emptyResult, 0, "空列表返回空")

local nilResult = Ctrl.FilterRankList(nil)
assert_eq(nilResult, nil, "nil 输入返回 nil")

-- ============================================================================
-- TEST 7: FilterRankList — 不误杀正常用户
-- ============================================================================
print("--- TEST 7: FilterRankList 不误杀 ---")

local cleanList = {
    { userId = 111111, score = 100 },
    { userId = 222222, score = 90 },
    { userId = 333333, score = 80 },
}

local cleanFiltered = Ctrl.FilterRankList(cleanList)
assert_eq(#cleanFiltered, 3, "全正常列表不被过滤")

-- ============================================================================
-- TEST 8: Config 结构验证
-- ============================================================================
print("--- TEST 8: Config 结构验证 ---")

assert_true(type(Config.PENALTIES) == "table", "PENALTIES 是 table")
assert_true(type(Config.DONE_KEY_PREFIX) == "string", "DONE_KEY_PREFIX 是 string")
assert_true(type(Config.RANK_KEYS_TO_CLEAR) == "table", "RANK_KEYS_TO_CLEAR 是 table")
assert_true(#Config.RANK_KEYS_TO_CLEAR > 0, "RANK_KEYS_TO_CLEAR 非空")
assert_true(type(Config.RANK_KEYS_PER_SLOT) == "table", "RANK_KEYS_PER_SLOT 是 table")
assert_true(#Config.RANK_KEYS_PER_SLOT > 0, "RANK_KEYS_PER_SLOT 非空")
assert_true(type(Config.MAX_SLOTS) == "number", "MAX_SLOTS 是 number")
assert_true(Config.MAX_SLOTS >= 1, "MAX_SLOTS >= 1")
assert_true(type(Config.RANK_KEYS_KEEP_VISIBLE) == "table", "RANK_KEYS_KEEP_VISIBLE 是 table")
assert_eq(Config.RANK_KEYS_KEEP_VISIBLE["xianshi_rank"], true, "xianshi_rank 在 KEEP_VISIBLE 中")

-- 验证处罚条目结构
local entry = Config.PENALTIES[PENALIZED_UID]
assert_true(entry ~= nil, "处罚UID存在于 PENALTIES 中")
if entry then
    assert_true(type(entry.denyLogin) == "boolean", "denyLogin 是 boolean")
    assert_true(type(entry.punishOnce) == "boolean", "punishOnce 是 boolean")
    assert_true(type(entry.suppressRank) == "boolean", "suppressRank 是 boolean")
    assert_true(type(entry.note) == "string", "note 是 string")
end

-- ============================================================================
-- 汇总
-- ============================================================================
print("\n" .. string.rep("=", 60))
print(string.format("  AdminPenaltyControl: %d tests, %d passed, %d failed",
    totalTests, passed, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("\n  *** TEST FAILED ***\n")
else
    print("\n  ALL TESTS PASSED\n")
end

return { passed = passed, failed = failed, total = totalTests }
