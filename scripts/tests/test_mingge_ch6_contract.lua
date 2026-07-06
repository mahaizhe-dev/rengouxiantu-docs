-- ============================================================================
-- test_mingge_ch6_contract.lua — 第六章命格掉落与生成合同
-- ============================================================================

MOUSEB_LEFT = MOUSEB_LEFT or 0
MOUSEB_MIDDLE = MOUSEB_MIDDLE or 1
MOUSEB_RIGHT = MOUSEB_RIGHT or 2
package.loaded["urhox-libs/UI/Core/Transition"] = package.loaded["urhox-libs/UI/Core/Transition"] or {}

local MinggeData = require("config.MinggeData")
local LootGeneration = require("systems.loot.generation")
local MinggeSystem = require("systems.MinggeSystem")

local passed = 0
local failed = 0
local errors = {}

local function ASSERT(cond, desc)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        errors[#errors + 1] = desc
        print("  FAIL: " .. desc)
    end
end

local function ASSERT_EQ(actual, expected, desc)
    ASSERT(actual == expected, desc .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local function ASSERT_RANGE(value, range, desc)
    ASSERT(type(value) == "number", desc .. " value is number")
    if type(value) == "number" and range then
        ASSERT(value >= range[1] and value <= range[2],
            desc .. " value=" .. tostring(value) .. " in [" .. tostring(range[1]) .. "," .. tostring(range[2]) .. "]")
    end
end

local ch6Specs = {
    {
        bossId = "ch6_lingfeng", name = "巡游天神·凌风", element = "fire",
        stat = "wisdom", tier = 3, level = 124,
        portrait = "image/monster_ch6_narrow_lingfeng_q_20260627083109.png",
    },
    {
        bossId = "ch6_zhuyou", name = "夜游神·烛幽", element = "water",
        stat = "hpRegen", tier = 3, level = 128,
        portrait = "image/monster_ch6_zhuyou_q2_20260627084954.png",
    },
    {
        bossId = "ch6_duanyue", name = "两界山神·断岳", element = "wood",
        stat = "physique", tier = 3, level = 132,
        portrait = "image/monster_ch6_duanyue_majestic_20260627093145.png",
    },
    {
        bossId = "ch6_pojun", name = "西大营天将·破军", element = "metal",
        stat = "killHeal", tier = 3, level = 137,
        portrait = "image/monster_ch6_pojun_serious_20260627102842.png",
    },
    {
        bossId = "ch6_zhenyuan", name = "西大营天将·镇垣", element = "earth",
        stat = "constitution", tier = 3, level = 138,
        portrait = "image/monster_ch6_zhenyuan_serious_20260627102859.png",
    },
    {
        bossId = "ch6_qingfeng", name = "东大营天将·青锋", element = "wood",
        stat = "heavyHit", tier = 3, level = 137,
        portrait = "image/monster_ch6_qingfeng_serious_20260627102842.png",
    },
    {
        bossId = "ch6_leice", name = "东大营天将·雷策", element = "earth",
        stat = "fortune", tier = 3, level = 138,
        portrait = "image/monster_ch6_leice_serious_20260627103121.png",
    },
    {
        bossId = "ch6_heng_marshal", name = "哼元帅", element = "earth",
        stat = "fortune", tier = 4, level = 140,
        portrait = "image/monster_ch6_heng_marshal_comic_20260627102506.png",
    },
    {
        bossId = "ch6_ha_marshal", name = "哈元帅", element = "fire",
        stat = "moveSpeed", tier = 4, level = 140,
        portrait = "image/monster_ch6_ha_marshal_comic_20260627102518.png",
    },
    {
        bossId = "ch6_gua_master", name = "呱大人", element = "water",
        stat = "tianzhuChance", tier = 4, level = 140,
        portrait = "image/monster_ch6_gua_master_funny_ref_20260627104326.png",
    },
    {
        bossId = "ch6_mojun_shixuan", name = "魔君·蚀玄", element = "metal",
        stat = "tianzhuDamage", tier = 4, level = 140,
        portrait = "image/monster_ch6_mojun_shixuan_ref_darker_20260627105823.png",
    },
}

local expectedByBossId = {}
for _, spec in ipairs(ch6Specs) do
    expectedByBossId[spec.bossId] = spec
end

print("--- Mingge CH6 contract ---")

ASSERT_EQ(MinggeData.DROP_RULES.baseDropChance, 0.05, "命格基础掉率沿用 5%")
ASSERT_EQ(MinggeData.DROP_RULES.setEligibleQuality, "cyan", "仅青色命格可附带四象套装")
ASSERT_EQ(MinggeData.DROP_RULES.setAttachChance, 0.20, "青色命格四象套装概率为 20%")
ASSERT_EQ(MinggeData.SELL_PRICE[4].purple, 4, "T4 purple sell price")
ASSERT_EQ(MinggeData.SELL_PRICE[4].orange, 8, "T4 orange sell price")
ASSERT_EQ(MinggeData.SELL_PRICE[4].cyan, 12, "T4 cyan sell price")

local excludedCh6Sources = {
    "ch6_patrol_immortal_soldier",
    "ch6_shadow_wanderer",
    "ch6_mountain_colossus",
    "ch6_west_celestial_soldier",
    "ch6_east_celestial_soldier",
    "ch6_toad_immortal",
}
for _, bossId in ipairs(excludedCh6Sources) do
    ASSERT(MinggeData.SOURCES[bossId] == nil, bossId .. " 不进入第六章命格池")
end

local ch6SourceCount = 0
for bossId, source in pairs(MinggeData.SOURCES) do
    if bossId:find("^ch6_") then
        ch6SourceCount = ch6SourceCount + 1
        ASSERT(expectedByBossId[bossId] ~= nil, bossId .. " 是允许的第六章命格来源")
        ASSERT(MinggeData.PORTRAITS[bossId] ~= nil, bossId .. " 有头像映射")
        ASSERT(MinggeData.STAT_RANGES[source.tier] ~= nil, bossId .. " tier 有属性范围")
        ASSERT(MinggeData.STAT_RANGES[source.tier][source.stat] ~= nil, bossId .. " stat 有属性范围")
    end
end
ASSERT_EQ(ch6SourceCount, #ch6Specs, "第六章命格来源数量")

for _, spec in ipairs(ch6Specs) do
    local source = MinggeData.SOURCES[spec.bossId]
    ASSERT(source ~= nil, spec.bossId .. " source exists")
    if source then
        ASSERT_EQ(source.name, spec.name, spec.bossId .. " name")
        ASSERT_EQ(source.element, spec.element, spec.bossId .. " element")
        ASSERT_EQ(source.stat, spec.stat, spec.bossId .. " stat")
        ASSERT_EQ(source.tier, spec.tier, spec.bossId .. " tier")
        ASSERT_EQ(source.level, spec.level, spec.bossId .. " level")
        ASSERT_EQ(MinggeData.PORTRAITS[spec.bossId], spec.portrait, spec.bossId .. " portrait")
        ASSERT_EQ(MinggeData.GetMinggeId(spec.bossId), spec.element .. "_" .. spec.bossId,
            spec.bossId .. " minggeId")
        ASSERT_EQ(MinggeData.GetMinggeName(spec.bossId),
            MinggeData.ELEMENT_NAMES[spec.element] .. "命·" .. spec.name,
            spec.bossId .. " display name")
    end
end

local t4 = MinggeData.STAT_RANGES[4]
ASSERT_EQ(t4.fortune.purple[1], 10, "T4 fortune purple min")
ASSERT_EQ(t4.fortune.cyan[2], 15, "T4 fortune cyan max")
ASSERT_EQ(t4.moveSpeed.purple[1], 0.037, "T4 moveSpeed purple min")
ASSERT_EQ(t4.moveSpeed.cyan[2], 0.051, "T4 moveSpeed cyan max")
ASSERT_EQ(t4.tianzhuChance.purple[1], 0.037, "T4 tianzhuChance purple min")
ASSERT_EQ(t4.tianzhuChance.cyan[2], 0.051, "T4 tianzhuChance cyan max")
ASSERT_EQ(t4.tianzhuDamage.purple[1], 0.088, "T4 tianzhuDamage purple min")
ASSERT_EQ(t4.tianzhuDamage.cyan[2], 0.120, "T4 tianzhuDamage cyan max")

math.randomseed(6204)
for _, spec in ipairs(ch6Specs) do
    local item = MinggeSystem.GenerateItem(spec.bossId)
    ASSERT(item ~= nil, spec.bossId .. " GenerateItem returns item")
    if item then
        local source = MinggeData.SOURCES[spec.bossId]
        local range = MinggeData.STAT_RANGES[item.tier][item.stat][item.quality]
        ASSERT_EQ(item.category, "mingge", spec.bossId .. " item category")
        ASSERT_EQ(item.bossId, spec.bossId, spec.bossId .. " item bossId")
        ASSERT_EQ(item.bossName, spec.name, spec.bossId .. " item bossName")
        ASSERT_EQ(item.element, spec.element, spec.bossId .. " item element")
        ASSERT_EQ(item.type, spec.element, spec.bossId .. " item type")
        ASSERT_EQ(item.tier, spec.tier, spec.bossId .. " item tier")
        ASSERT_EQ(item.stat, spec.stat, spec.bossId .. " item stat")
        ASSERT_EQ(item.image, spec.portrait, spec.bossId .. " item image")
        ASSERT_EQ(item.sellCurrency, "lingYun", spec.bossId .. " item sell currency")
        ASSERT_EQ(item.sellPrice, MinggeData.SELL_PRICE[spec.tier][item.quality],
            spec.bossId .. " item sell price")
        ASSERT_RANGE(item.value, range, spec.bossId .. " item value")
        ASSERT(item.name:find(MinggeData.ELEMENT_NAMES[source.element] .. "命·" .. source.name, 1, true) == 1,
            spec.bossId .. " item name uses fixed mingge name")
        if item.quality ~= "cyan" then
            ASSERT(item.setId == nil, spec.bossId .. " non-cyan item has no set")
        end
    end
end

local oldChance = MinggeData.DROP_RULES.baseDropChance
MinggeData.DROP_RULES.baseDropChance = 1.0
math.randomseed(6205)
for _, spec in ipairs(ch6Specs) do
    local item = LootGeneration.RollMingge({ typeId = spec.bossId, x = 1, y = 1 }, {})
    ASSERT(item ~= nil, spec.bossId .. " RollMingge drops through loot chain")
    if item then
        ASSERT_EQ(item.bossId, spec.bossId, spec.bossId .. " RollMingge bossId")
        ASSERT_EQ(item.tier, spec.tier, spec.bossId .. " RollMingge tier")
        ASSERT_EQ(item.stat, spec.stat, spec.bossId .. " RollMingge stat")
        ASSERT_EQ(item.image, spec.portrait, spec.bossId .. " RollMingge image")
    end
end
MinggeData.DROP_RULES.baseDropChance = oldChance

print("")
if failed == 0 then
    print(string.format("Mingge CH6 contract: all %d passed", passed))
else
    print(string.format("Mingge CH6 contract: %d failed / %d total", failed, passed + failed))
    for _, e in ipairs(errors) do
        print("  " .. e)
    end
end

return { passed = passed, failed = failed, total = passed + failed }
