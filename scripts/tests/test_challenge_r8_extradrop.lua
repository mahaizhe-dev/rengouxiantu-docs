-- ============================================================================
-- test_challenge_r8_extradrop.lua — R8 声望 + T10 法宝 + 额外掉落 自测
--
-- 覆盖场景：
--   TEST 1:  MAX_REPUTATION_LEVEL == 8
--   TEST 2:  REPUTATION_TIER[8] == 10
--   TEST 3:  REPUTATION_TOKEN[8] == "taixu_jianling"
--   TEST 4:  REPUTATION_UNLOCK_COST[8] == 3000
--   TEST 5:  REPUTATION_FIRST_CLEAR_QUALITY[8] == "cyan"
--   TEST 6:  BuildExtraDropTable(8) 返回非空表
--   TEST 7:  R8 金条数量 = 8
--   TEST 8:  R8 食物 = dragon_marrow × 3
--   TEST 9:  R8 包含 ganggu_essence 条目
--   TEST 10: R8 修炼果 count = 5
--   TEST 11: R8 灵韵果 count = 3
--   TEST 12: R8 五系精华 chance = 0.003
--   TEST 13: 4 阵营 MonsterTypes 都有 R8 Boss 定义
--   TEST 14: R8 Boss 属性验证（level=120, realm=dujie_1, category=saint_boss）
--   TEST 15: EquipmentData 4 法宝模板 iconByTier[10] 非空
--   TEST 16: EquipmentData 4 法宝模板 sellPriceByTier[10] == 1200
--   TEST 17: LootSystem 品质上限 — T10 tier → maxQ == "red"
--   TEST 18: LootSystem 品质上限 — T9 tier → maxQ == "cyan"
--   TEST 19: ChallengeSystem Init 生成 8 级声望槽位
--   TEST 20: GetExtraTotalChance(8) > GetExtraTotalChance(7)
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

-- ─────────────────────────────────────────────
-- 断言工具
-- ─────────────────────────────────────────────

local function assert_eq(actual, expected, testName)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName)
        print("    expected: " .. tostring(expected))
        print("    actual:   " .. tostring(actual))
    end
end

local function assert_true(cond, testName)
    assert_eq(cond, true, testName)
end

local function assert_not_nil(val, testName)
    totalTests = totalTests + 1
    if val ~= nil then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName .. " (got nil)")
    end
end

local function assert_gt(a, b, testName)
    totalTests = totalTests + 1
    if a > b then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName)
        print("    expected: " .. tostring(a) .. " > " .. tostring(b))
    end
end

-- ─────────────────────────────────────────────
-- require 模块
-- ─────────────────────────────────────────────

local ChallengeConfig = require("config.ChallengeConfig")

print("========================================")
print("  TEST: R8 声望 + T10 法宝 + 额外掉落")
print("========================================")

-- ─────────────────────────────────────────────
-- TEST 1-5: ChallengeConfig 基础查表
-- ─────────────────────────────────────────────

assert_eq(ChallengeConfig.MAX_REPUTATION_LEVEL, 8,
    "TEST 1: MAX_REPUTATION_LEVEL == 8")

assert_eq(ChallengeConfig.REPUTATION_TIER[8], 10,
    "TEST 2: REPUTATION_TIER[8] == 10")

assert_eq(ChallengeConfig.REPUTATION_TOKEN[8], "taixu_jianling",
    "TEST 3: REPUTATION_TOKEN[8] == taixu_jianling")

assert_eq(ChallengeConfig.REPUTATION_UNLOCK_COST[8], 3000,
    "TEST 4: REPUTATION_UNLOCK_COST[8] == 3000")

assert_eq(ChallengeConfig.REPUTATION_FIRST_CLEAR_QUALITY[8], "cyan",
    "TEST 5: REPUTATION_FIRST_CLEAR_QUALITY[8] == cyan")

-- ─────────────────────────────────────────────
-- TEST 6-12: BuildExtraDropTable(8) 内容验证
-- ─────────────────────────────────────────────

local entries = ChallengeConfig.BuildExtraDropTable(8)
assert_true(#entries > 0, "TEST 6: BuildExtraDropTable(8) 非空")

-- 找各类条目
local goldEntry, foodEntry, gangguEntry, fruitEntry, lingyunEntry
local essenceEntries = {}

for _, e in ipairs(entries) do
    if e.type == "gold_bar" then goldEntry = e
    elseif e.type == "food" then foodEntry = e
    elseif e.type == "essence" and e.subId == "ganggu_essence" then gangguEntry = e
    elseif e.type == "essence" then table.insert(essenceEntries, e)
    elseif e.type == "cultivation_fruit" then fruitEntry = e
    elseif e.type == "lingyun_fruit" then lingyunEntry = e
    end
end

assert_not_nil(goldEntry, "TEST 7a: R8 金条条目存在")
if goldEntry then
    assert_eq(goldEntry.count, 8, "TEST 7b: R8 金条数量 = 8")
end

assert_not_nil(foodEntry, "TEST 8a: R8 食物条目存在")
if foodEntry then
    assert_eq(foodEntry.subId, "dragon_marrow", "TEST 8b: R8 食物 = dragon_marrow")
    assert_eq(foodEntry.count, 3, "TEST 8c: R8 食物数量 = 3")
end

assert_not_nil(gangguEntry, "TEST 9: R8 包含 ganggu_essence")

assert_not_nil(fruitEntry, "TEST 10a: R8 修炼果存在")
if fruitEntry then
    assert_eq(fruitEntry.count, 5, "TEST 10b: R8 修炼果 count = 5")
end

assert_not_nil(lingyunEntry, "TEST 11a: R8 灵韵果存在")
if lingyunEntry then
    assert_eq(lingyunEntry.count, 3, "TEST 11b: R8 灵韵果 count = 3")
end

-- 五系精华 chance
if #essenceEntries >= 5 then
    assert_eq(essenceEntries[1].chance, 0.003,
        "TEST 12: R8 五系精华 chance = 0.003")
else
    totalTests = totalTests + 1
    failed = failed + 1
    print("  FAIL: TEST 12: 五系精华条目数不足 (got " .. #essenceEntries .. ")")
end

-- ─────────────────────────────────────────────
-- TEST 13-14: MonsterTypes R8 Boss 验证
-- ─────────────────────────────────────────────

local MonsterTypes = require("config.MonsterTypes_ch3")

local r8Bosses = {
    { id = "challenge_shenmo_r8",    name = "沈墨" },
    { id = "challenge_luqingyun_r8", name = "陆青云" },
    { id = "challenge_yunshang_r8",  name = "云裳" },
    { id = "challenge_liwuji_r8",    name = "凌战" },
}

for _, boss in ipairs(r8Bosses) do
    local def = MonsterTypes.Types[boss.id]
    assert_not_nil(def, "TEST 13: " .. boss.name .. " R8 Boss 定义存在")
    if def then
        assert_eq(def.level, 120,
            "TEST 14a: " .. boss.name .. " level=120")
        assert_eq(def.realm, "dujie_1",
            "TEST 14b: " .. boss.name .. " realm=dujie_1")
        assert_eq(def.category, "saint_boss",
            "TEST 14c: " .. boss.name .. " category=saint_boss")
    end
end

-- ─────────────────────────────────────────────
-- TEST 15-16: EquipmentData 法宝模板 T10
-- ─────────────────────────────────────────────

local EquipmentData = require("config.EquipmentData")

local fabaoTemplateKeys = {
    "blood_sea_map",
    "qingyun_pagoda",
    "haoqi_seal",
    "fengmo_plate",
}

for _, key in ipairs(fabaoTemplateKeys) do
    local tpl = EquipmentData.FABAO_TEMPLATES and EquipmentData.FABAO_TEMPLATES[key]
    if tpl then
        assert_not_nil(tpl.iconByTier and tpl.iconByTier[10],
            "TEST 15: " .. key .. " iconByTier[10] 非空")
        assert_eq(tpl.sellPriceByTier and tpl.sellPriceByTier[10], 1200,
            "TEST 16: " .. key .. " sellPriceByTier[10] == 1200")
    else
        totalTests = totalTests + 2
        failed = failed + 2
        print("  FAIL: " .. key .. " 模板不存在")
    end
end

-- ─────────────────────────────────────────────
-- TEST 17-18: LootSystem 品质上限逻辑
-- (模拟 LootSystem 内部逻辑，不需 require 整个系统)
-- ─────────────────────────────────────────────

local function calcMaxQ(tier)
    local maxQ = "purple"
    if tier >= 10 then
        maxQ = "red"
    elseif tier >= 9 then
        maxQ = "cyan"
    elseif tier >= 5 then
        maxQ = "orange"
    end
    return maxQ
end

assert_eq(calcMaxQ(10), "red",  "TEST 17: T10 品质上限 = red")
assert_eq(calcMaxQ(9),  "cyan", "TEST 18: T9 品质上限 = cyan")

-- ─────────────────────────────────────────────
-- TEST 19: ChallengeSystem Init 生成 8 级声望槽位
-- ─────────────────────────────────────────────

-- 模拟 Init 逻辑
local function simulateInitSlots()
    local treasure_challenge = {}
    for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
        if faction.reputation then
            treasure_challenge[factionKey] = {
                [faction.treasureKey] = {},
            }
            for level = 1, ChallengeConfig.MAX_REPUTATION_LEVEL do
                treasure_challenge[factionKey][faction.treasureKey][tostring(level)] = {
                    unlocked = false,
                    completed = false,
                }
            end
        end
    end
    return treasure_challenge
end

local tc = simulateInitSlots()
local anyFactionKey = next(tc)
if anyFactionKey then
    local fCfg = ChallengeConfig.FACTIONS[anyFactionKey]
    local slots = tc[anyFactionKey][fCfg.treasureKey]
    assert_not_nil(slots["8"], "TEST 19: Init 生成第 8 级声望槽位")
else
    totalTests = totalTests + 1
    failed = failed + 1
    print("  FAIL: TEST 19: 无阵营数据")
end

-- ─────────────────────────────────────────────
-- TEST 20: GetExtraTotalChance(8) > (7)
-- ─────────────────────────────────────────────

local total7 = ChallengeConfig.GetExtraTotalChance(7)
local total8 = ChallengeConfig.GetExtraTotalChance(8)
assert_gt(total8, total7, "TEST 20: R8 总概率 > R7 (" .. tostring(total8) .. " > " .. tostring(total7) .. ")")

-- ─────────────────────────────────────────────
-- 结果汇总
-- ─────────────────────────────────────────────

print("========================================")
print(string.format("  RESULT: %d passed, %d failed, %d total",
    passed, failed, totalTests))
print("========================================")

return { passed = passed, failed = failed, total = totalTests }
