---@diagnostic disable: undefined-field, unnecessary-if, assign-type-mismatch
-- ============================================================================
-- test_challenge_r8_extradrop.lua — R8 声望 + T10 法宝 + 额外掉落 自测
--
-- 覆盖场景：
--   1. R8 基础配置与额外掉落表
--   2. R7/R8 非首通声望法宝：绿色起步，最高灵器
--   3. 非声望默认法宝生成仍保留 T10 可红
--   4. 显式红色法宝生成不受影响
--   5. 四种声望法宝模板与 R7/R8 配置完整
--   6. 章节入口 + 中洲入口 NPC 覆盖完整
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

local ChallengeConfig = require("config.ChallengeConfig")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local LootSystem = require("systems.LootSystem")
local generation = require("systems.loot.generation")

print("========================================")
print("  TEST: R8 声望 + T10 法宝 + 额外掉落")
print("========================================")

assert_eq(ChallengeConfig.MAX_REPUTATION_LEVEL, 9,
    "MAX_REPUTATION_LEVEL == 9")
assert_eq(ChallengeConfig.REPUTATION_TIER[8], 10,
    "REPUTATION_TIER[8] == 10")
assert_eq(ChallengeConfig.REPUTATION_TOKEN[8], "taixu_jianling",
    "REPUTATION_TOKEN[8] == taixu_jianling")
assert_eq(ChallengeConfig.REPUTATION_UNLOCK_COST[8], 3000,
    "REPUTATION_UNLOCK_COST[8] == 3000")
assert_eq(ChallengeConfig.GetFirstClearQuality(8), "orange",
    "R8 首通品质保持 orange")

local entries = ChallengeConfig.BuildExtraDropTable(8)
assert_true(#entries > 0, "BuildExtraDropTable(8) 非空")

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

assert_not_nil(goldEntry, "R8 金条条目存在")
if goldEntry then assert_eq(goldEntry.count, 16, "R8 金条数量 = 16") end

assert_not_nil(foodEntry, "R8 食物条目存在")
if foodEntry then
    assert_eq(foodEntry.subId, "dragon_marrow", "R8 食物 = dragon_marrow")
    assert_eq(foodEntry.count, 3, "R8 食物数量 = 3")
end

assert_not_nil(gangguEntry, "R8 包含 ganggu_essence")
assert_not_nil(fruitEntry, "R8 修炼果存在")
if fruitEntry then assert_eq(fruitEntry.count, 5, "R8 修炼果 count = 5") end
assert_not_nil(lingyunEntry, "R8 灵韵果存在")
if lingyunEntry then assert_eq(lingyunEntry.count, 3, "R8 灵韵果 count = 3") end

if #essenceEntries >= 5 then
    assert_eq(essenceEntries[1].chance, 0.003,
        "R8 五系精华 chance = 0.003")
else
    totalTests = totalTests + 1
    failed = failed + 1
    print("  FAIL: 五系精华条目数不足 (got " .. #essenceEntries .. ")")
end

local MonsterTypes = require("config.MonsterData")
local r8Bosses = {
    { id = "challenge_shenmo_r8",    name = "沈墨" },
    { id = "challenge_luqingyun_r8", name = "陆青云" },
    { id = "challenge_yunshang_r8",  name = "云裳" },
    { id = "challenge_liwuji_r8",    name = "凌战" },
}

for _, boss in ipairs(r8Bosses) do
    local def = MonsterTypes.Types[boss.id]
    assert_not_nil(def, boss.name .. " R8 Boss 定义存在")
    if def then
        assert_eq(def.level, 120, boss.name .. " level=120")
        assert_eq(def.realm, "zhexian_1", boss.name .. " realm=zhexian_1")
        assert_eq(def.category, "saint_boss", boss.name .. " category=saint_boss")
    end
end

local factionContracts = {
    xuesha = { tpl = "fabao_xuehaitu", oldNpc = "xuesha_spy", midNpc = "xuesha_master" },
    haoqi = { tpl = "fabao_haoqiyin", oldNpc = "haoqi_envoy", midNpc = "haoqi_master" },
    qingyun = { tpl = "fabao_qingyunta", chapterNpc = "qingyun_envoy_ch3", midNpc = "qingyun_master" },
    fengmo = { tpl = "fabao_fengmopan", chapterNpc = "fengmodian_envoy_ch3", midNpc = "fengmo_master" },
}

for factionKey, contract in pairs(factionContracts) do
    local faction = ChallengeConfig.FACTIONS[factionKey]
    assert_not_nil(faction, factionKey .. " faction 存在")
    if faction then
        assert_eq(faction.fabaoTplId, contract.tpl, factionKey .. " fabaoTplId")
        assert_not_nil(faction.reputation[7], factionKey .. " R7 配置存在")
        assert_not_nil(faction.reputation[8], factionKey .. " R8 配置存在")
        assert_eq(faction.reputation[7].tier, 9, factionKey .. " R7 tier=9")
        assert_eq(faction.reputation[8].tier, 10, factionKey .. " R8 tier=10")
    end

    local tpl = EquipmentData.FabaoTemplates and EquipmentData.FabaoTemplates[contract.tpl]
    assert_not_nil(tpl, contract.tpl .. " 法宝模板存在")
    if tpl then
        assert_not_nil(tpl.iconByTier and tpl.iconByTier[9], contract.tpl .. " iconByTier[9] 非空")
        assert_not_nil(tpl.iconByTier and tpl.iconByTier[10], contract.tpl .. " iconByTier[10] 非空")
        assert_eq(tpl.sellPriceByTier and tpl.sellPriceByTier[9], 900,
            contract.tpl .. " sellPriceByTier[9] == 900")
        assert_eq(tpl.sellPriceByTier and tpl.sellPriceByTier[10], 1200,
            contract.tpl .. " sellPriceByTier[10] == 1200")
    end

    assert_eq(ChallengeConfig.GetFactionByNpcId(contract.midNpc), factionKey,
        contract.midNpc .. " fallback 映射")
    if contract.oldNpc then
        assert_eq(ChallengeConfig.GetFactionByNpcId(contract.oldNpc), factionKey,
            contract.oldNpc .. " legacy fallback 映射")
    end
end

local chapter2 = require("config.zones.chapter2.camp_a")
local chapter3 = require("config.zones.chapter3.fort_9")
local midXuesha = require("config.zones.midland.xuesha")
local midHaoqi = require("config.zones.midland.haoqi")
local midQingyun = require("config.zones.midland.qingyun")
local midFengmo = require("config.zones.midland.fengmo")

local function findNpc(zone, npcId)
    for _, npc in ipairs(zone.npcs or {}) do
        if npc.id == npcId then return npc end
    end
    return nil
end

local npcContracts = {
    { zone = chapter2, id = "xuesha_spy", faction = "xuesha" },
    { zone = chapter2, id = "haoqi_envoy", faction = "haoqi" },
    { zone = chapter3, id = "qingyun_envoy_ch3", faction = "qingyun" },
    { zone = chapter3, id = "fengmodian_envoy_ch3", faction = "fengmo" },
    { zone = midXuesha, id = "xuesha_master", faction = "xuesha" },
    { zone = midHaoqi, id = "haoqi_master", faction = "haoqi" },
    { zone = midQingyun, id = "qingyun_master", faction = "qingyun" },
    { zone = midFengmo, id = "fengmo_master", faction = "fengmo" },
}

for _, contract in ipairs(npcContracts) do
    local npc = findNpc(contract.zone, contract.id)
    assert_not_nil(npc, contract.id .. " NPC 存在")
    if npc then
        assert_eq(npc.interactType, "challenge_envoy", contract.id .. " interactType")
        assert_eq(npc.challengeFaction, contract.faction, contract.id .. " challengeFaction")
    end
end

assert_eq(ChallengeConfig.GetRandomMinQuality(7), "green", "R7 随机法宝绿色起步")
assert_eq(ChallengeConfig.GetRandomMaxQuality(7), "cyan", "R7 随机法宝最高灵器")
assert_eq(ChallengeConfig.GetRandomMinQuality(8), "green", "R8 随机法宝绿色起步")
assert_eq(ChallengeConfig.GetRandomMaxQuality(8), "cyan", "R8 随机法宝最高灵器")

local originalRollQuality = generation.RollQuality
local captured = {}
local function stubRollQuality(minQ, maxQ)
    captured[#captured + 1] = { minQ = minQ, maxQ = maxQ }
    return maxQ
end

generation.RollQuality = stubRollQuality
LootSystem.RollQuality = stubRollQuality

for factionKey, contract in pairs(factionContracts) do
    for _, repLevel in ipairs({7, 8}) do
        local tier = ChallengeConfig.REPUTATION_TIER[repLevel]
        captured = {}
        local item = LootSystem.CreateFabaoEquipment(contract.tpl, tier, nil, {
            minQuality = ChallengeConfig.GetRandomMinQuality(repLevel),
            maxQuality = ChallengeConfig.GetRandomMaxQuality(repLevel),
        })
        assert_not_nil(item, factionKey .. " R" .. repLevel .. " 法宝生成")
        assert_not_nil(captured[1], factionKey .. " R" .. repLevel .. " 捕获到 RollQuality")
        if captured[1] then
            assert_eq(captured[1].minQ, "green", factionKey .. " R" .. repLevel .. " minQ=green")
            assert_eq(captured[1].maxQ, "cyan", factionKey .. " R" .. repLevel .. " maxQ=cyan")
        end
        if item then
            assert_eq(item.quality, "cyan", factionKey .. " R" .. repLevel .. " 生成 cyan")
        end
    end
end

captured = {}
local defaultItem = LootSystem.CreateFabaoEquipment("fabao_xuehaitu", 10, nil)
assert_not_nil(defaultItem, "默认 T10 法宝生成成功")
assert_not_nil(captured[1], "默认 T10 法宝捕获到 RollQuality")
if captured[1] then
    assert_eq(captured[1].minQ, "white", "默认 T10 法宝 minQ=white")
    assert_eq(captured[1].maxQ, "red", "默认 T10 法宝 maxQ=red")
end
if defaultItem then
    assert_eq(defaultItem.quality, "red", "默认 T10 法宝可出 red")
end

local explicitRed = LootSystem.CreateFabaoEquipment("fabao_xuehaitu", 10, "red")
assert_not_nil(explicitRed, "显式 red 法宝生成成功")
if explicitRed then
    assert_eq(explicitRed.quality, "red", "显式 red 法宝品质不被覆盖")
end

generation.RollQuality = originalRollQuality
LootSystem.RollQuality = originalRollQuality

local total7 = ChallengeConfig.GetExtraDropChance(7)
local total8 = ChallengeConfig.GetExtraDropChance(8)
assert_true(math.abs(total8 - total7) < 0.0000001,
    "R8 与 R7 额外掉落总概率均为 8.5%")
assert_true(math.abs(total8 - 0.085) < 0.0000001,
    "R8 额外掉落总概率 = 8.5%")
assert_eq(ChallengeConfig.GetExtraTotalChance(8), total8,
    "旧接口 GetExtraTotalChance 兼容")

print("========================================")
print(string.format("  RESULT: %d passed, %d failed, %d total",
    passed, failed, totalTests))
print("========================================")

return { passed = passed, failed = failed, total = totalTests }
