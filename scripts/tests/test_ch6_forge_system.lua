-- ============================================================================
-- test_ch6_forge_system.lua - 第六章影炉配置与镇界护盾合同测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local EquipmentData = require("config.EquipmentData")
local LootSystem = require("systems.LootSystem")
local ZoneDataCh6 = require("config.ZoneData_ch6")
local Ch6ForgeEffects = require("systems.Ch6ForgeEffects")
local Ch6ForgeHitEffects = require("systems.combat.Ch6ForgeHitEffects")
local CombatFeedbackBridge = require("systems.combat.CombatFeedbackBridge")
local PlayerShieldStatus = require("systems.PlayerShieldStatus")
local GameState = require("core.GameState")
local CombatSystem = require("systems.CombatSystem")
local Monster = require("entities.Monster")
local MonsterData = require("config.MonsterData")
local ForgeStatRules = require("systems.forge.ForgeStatRules")

local passed = 0
local failed = 0

local function ok(cond, desc)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. desc)
    end
end

local function eq(actual, expected, desc)
    ok(actual == expected, desc .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local function near(actual, expected, desc)
    ok(math.abs((actual or 0) - expected) < 0.000001,
        desc .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local function readFile(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local recipeIds = {
    "ch6_true_zhuxian",
    "ch6_true_xianxian",
    "ch6_true_luxian",
    "ch6_true_juexian",
    "ch6_hengha_dual_blade",
    "ch6_zhenjie_saint_armor",
    "ch6_guagua_junling_ring",
    "ch6_shijie_saint_cape",
}

local order = EquipmentData.FORGE_RECIPE_ORDER.shadow_forge
ok(EquipmentData.FORGE_STATIONS.shadow_forge ~= nil, "shadow_forge station exists")
eq(#(order or {}), 9, "shadow_forge recipe count")

local trueSwordSources = {
    ch6_true_zhuxian = "jiefeng_zhuxian_ch5",
    ch6_true_xianxian = "jiefeng_xianxian_ch5",
    ch6_true_luxian = "jiefeng_luxian_ch5",
    ch6_true_juexian = "jiefeng_juexian_ch5",
}

for index, recipeId in ipairs(recipeIds) do
    eq(order and order[index], recipeId, "shadow_forge order " .. index)
    local recipe = EquipmentData.FORGE_RECIPES[recipeId]
    ok(recipe ~= nil, recipeId .. " recipe exists")
    ok(EquipmentData.SpecialEquipment[recipeId] ~= nil, recipeId .. " template exists")
    if recipe then
        eq(recipe.stationId, "shadow_forge", recipeId .. " station")
        eq(recipe.materials and recipe.materials[1] and recipe.materials[1].id,
            "shadow_crystal", recipeId .. " material")
        eq(recipe.materials and recipe.materials[1] and recipe.materials[1].count,
            6, recipeId .. " crystal count")
    end
end

eq(order and order[9], "fabao_longwangling", "shadow_forge order 9")
local longwangRecipe = EquipmentData.FORGE_RECIPES.fabao_longwangling
local longwangTemplate = EquipmentData.FabaoTemplates.fabao_longwangling
ok(longwangRecipe ~= nil, "dragon king token recipe exists")
ok(longwangTemplate ~= nil, "dragon king token template exists")
eq(longwangRecipe and longwangRecipe.stationId, "shadow_forge", "dragon king token station")
eq(longwangRecipe and longwangRecipe.inputMode, "bag_consume", "dragon king token bag input")
eq(longwangRecipe and longwangRecipe.outputMode, "add_to_bag", "dragon king token bag output")
eq(longwangRecipe and longwangRecipe.gold, 0, "dragon king token gold cost")
eq(longwangRecipe and longwangRecipe.fromBag and longwangRecipe.fromBag.equipId,
    "ch6_xianzun_1_ring", "dragon king token consumes immortal ring")
eq(longwangRecipe and longwangRecipe.materials and longwangRecipe.materials[1].id,
    "shadow_crystal", "dragon king token crystal material")
eq(longwangRecipe and longwangRecipe.materials and longwangRecipe.materials[1].count,
    6, "dragon king token crystal count")
eq(longwangRecipe and longwangRecipe.materials and longwangRecipe.materials[2].id,
    "zhexian_ling", "dragon king token chapter token")
eq(longwangRecipe and longwangRecipe.materials and longwangRecipe.materials[2].count,
    1000, "dragon king token chapter token count")
eq(longwangRecipe and longwangRecipe.generator and longwangRecipe.generator.type,
    "fabao", "dragon king token uses generic fabao generator")
eq(longwangTemplate and longwangTemplate.skillId, "dragon_breath",
    "dragon king token reuses dragon breath")

math.randomseed(6119)
local longhunItem = LootSystem.CreateFabaoEquipment("fabao_longhunling", 10, "red")
local longwangItem = LootSystem.CreateFabaoEquipment("fabao_longwangling", 11, "red")
ok(longwangItem ~= nil, "dragon king token generation succeeds")
eq(longwangItem and longwangItem.tier, 11, "dragon king token tier")
eq(longwangItem and longwangItem.quality, "red", "dragon king token quality")
eq(longwangItem and longwangItem.mainStat and longwangItem.mainStat.atk,
    105, "dragon king token attack")
eq(longwangItem and longwangItem.skillId,
    longhunItem and longhunItem.skillId, "dragon king and dragon soul use identical skill id")

for recipeId, sourceId in pairs(trueSwordSources) do
    local recipe = EquipmentData.FORGE_RECIPES[recipeId]
    eq(recipe.inputMode, "equip_weapon", recipeId .. " reads source sword from equipment slot")
    eq(recipe.equipSource, sourceId, recipeId .. " requires corresponding unsealed sword")
    eq(recipe.equipSourcePool, nil, recipeId .. " does not reuse huangsha weapon pool")
    eq(recipe.outputMode, "replace_weapon", recipeId .. " replaces equipped sword in place")
end

local expectedForgeStats = {
    ch6_true_zhuxian = {
        quality = "red", mainStat = "atk", mainValue = 262.5,
        subStats = {
            { "critDmg", 0.4455 },
            { "critDmg", 0.4455 },
            { "atk", 30.375 },
        },
    },
    ch6_true_xianxian = {
        quality = "red", mainStat = "atk", mainValue = 262.5,
        subStats = {
            { "physique", 23 },
            { "maxHp", 121.5 },
            { "critRate", 0.0891 },
        },
    },
    ch6_true_luxian = {
        quality = "red", mainStat = "atk", mainValue = 262.5,
        subStats = {
            { "constitution", 23 },
            { "heavyHit", 144 },
            { "atk", 30.375 },
        },
    },
    ch6_true_juexian = {
        quality = "red", mainStat = "atk", mainValue = 262.5,
        subStats = {
            { "killHeal", 60.75 },
            { "atk", 30.375 },
            { "atk", 30.375 },
        },
    },
    ch6_zhenjie_saint_armor = {
        quality = "red", mainStat = "def", mainValue = 210,
        subStats = {
            { "physique", 23 },
            { "maxHp", 121.5 },
            { "critDmg", 0.4455 },
        },
    },
    ch6_hengha_dual_blade = {
        quality = "red", mainStat = "atk", mainValue = 262.5,
        subStats = {
            { "critRate", 0.0891 },
            { "critDmg", 0.4455 },
            { "wisdom", 23 },
        },
    },
    ch6_guagua_junling_ring = {
        quality = "gold", mainStat = "atk", mainValue = 187.5,
        subStats = {
            { "def", 25.2 },
            { "maxHp", 126 },
            { "hpRegen", 10.5 },
        },
    },
    ch6_shijie_saint_cape = {
        quality = "gold", mainStat = "dmgReduce", mainValue = 0.45,
        subStats = {
            { "def", 25.2 },
            { "critDmg", 0.462 },
            { "wisdom", 27 },
        },
    },
}

for index, recipeId in ipairs(recipeIds) do
    local expected = expectedForgeStats[recipeId]
    local template = EquipmentData.SpecialEquipment[recipeId]
    ok(expected ~= nil, recipeId .. " has exact attribute audit data")
    eq(template and template.tier, 11, recipeId .. " tier")
    eq(template and template.quality, expected and expected.quality, recipeId .. " quality")
    ok(template and template.fixedSubStats ~= true, recipeId .. " forged sub stats remain random")
    near(template and template.mainStat and template.mainStat[expected.mainStat],
        expected.mainValue, recipeId .. " main stat")
    eq(template and #(template.subStats or {}), 3, recipeId .. " sub stat count")

    for subIndex, expectedSub in ipairs(expected.subStats) do
        local actualSub = template and template.subStats and template.subStats[subIndex]
        eq(actualSub and actualSub.stat, expectedSub[1],
            recipeId .. " sub stat " .. subIndex .. " type")
        near(actualSub and actualSub.value, expectedSub[2],
            recipeId .. " sub stat " .. subIndex .. " value")
    end

    math.randomseed(620 + index)
    local generated = LootSystem.CreateSaintEquipment(recipeId)
    ok(generated ~= nil, recipeId .. " generated item exists")
    eq(generated and generated.quality, expected.quality, recipeId .. " generated quality")
    near(generated and generated.mainStat and generated.mainStat[expected.mainStat],
        expected.mainValue, recipeId .. " generated main stat")
    ok(generated and generated.saintStat ~= nil, recipeId .. " generated saint stat")
    ok(generated and generated.spiritStat == nil, recipeId .. " excludes spirit stat")
    for subIndex, expectedSub in ipairs(expected.subStats) do
        local templateSub = template and template.subStats and template.subStats[subIndex]
        local generatedSub = generated and generated.subStats and generated.subStats[subIndex]
        eq(generatedSub and generatedSub.stat, expectedSub[1],
            recipeId .. " generated sub stat " .. subIndex .. " type")
        local preview = ForgeStatRules.GetForgeSubStatPreview(
            EquipmentData.FORGE_RECIPES[recipeId], template, templateSub
        )
        if preview.mode == "range" then
            ok(generatedSub and generatedSub.value >= preview.minValue
                and generatedSub.value <= preview.maxValue,
                recipeId .. " generated sub stat " .. subIndex .. " stays in preview range")
        else
            near(generatedSub and generatedSub.value, preview.value,
                recipeId .. " generated fixed sub stat " .. subIndex)
        end
    end
end

local saintCape = EquipmentData.SpecialEquipment.saint_cape_ch5
local immortalCape = EquipmentData.SpecialEquipment.ch6_shijie_saint_cape
near(immortalCape.mainStat.dmgReduce,
    saintCape.mainStat.dmgReduce * (9 / 8) * (2.5 / 2.1),
    "immortal cape main stat applies tier and quality upgrades")
near(immortalCape.subStats[1].value, 1.2 * 15 * 1.4,
    "immortal cape defense template uses gold range midpoint")
near(immortalCape.subStats[2].value, 0.05 * 6.6 * 1.4,
    "immortal cape critical damage template uses gold range midpoint")
eq(immortalCape.subStats[3].value, math.floor(11 * 2.5),
    "immortal cape wisdom uses T11 gold linear formula")
ok(immortalCape.mainStat.dmgReduce > saintCape.mainStat.dmgReduce,
    "immortal cape main stat exceeds chapter 5 saint cape")
eq(immortalCape.subStats[1].stat, saintCape.subStats[1].stat,
    "immortal cape preserves chapter 5 defense sub stat")
eq(immortalCape.subStats[2].stat, saintCape.subStats[2].stat,
    "immortal cape preserves chapter 5 critical damage sub stat")
eq(immortalCape.subStats[3].stat, saintCape.subStats[3].stat,
    "immortal cape preserves chapter 5 wisdom sub stat")
local saintCapeRecipe = EquipmentData.FORGE_RECIPES.saint_cape_ch5
local immortalCapeRecipe = EquipmentData.FORGE_RECIPES.ch6_shijie_saint_cape
local saintCritPreview = ForgeStatRules.GetForgeSubStatPreview(
    saintCapeRecipe, saintCape, saintCape.subStats[2]
)
local immortalCritPreview = ForgeStatRules.GetForgeSubStatPreview(
    immortalCapeRecipe, immortalCape, immortalCape.subStats[2]
)
near(saintCritPreview.minValue, 0.36, "saint cape critical damage preview minimum")
near(saintCritPreview.maxValue, 0.45, "saint cape critical damage preview maximum")
near(immortalCritPreview.minValue, 0.396, "immortal cape critical damage preview minimum")
near(immortalCritPreview.maxValue, 0.528, "immortal cape critical damage preview maximum")
ok(immortalCritPreview.minValue > saintCritPreview.minValue
    and immortalCritPreview.maxValue > saintCritPreview.maxValue,
    "immortal cape critical damage range exceeds saint cape range")
ok(immortalCape.subStats[3].value > saintCape.subStats[3].value,
    "immortal cape wisdom exceeds chapter 5 saint cape")

local collectionCh6 = EquipmentData.Collection.chapters[#EquipmentData.Collection.chapters]
local collectionIndex = {}
for index, equipId in ipairs(collectionCh6.order or {}) do
    collectionIndex[equipId] = index
end
eq(collectionIndex.ch6_hengha_dual_blade,
    (collectionIndex.ch6_true_juexian or 0) + 1,
    "collection keeps all five forged weapons together")
eq(collectionIndex.ch6_zhenjie_saint_armor,
    (collectionIndex.ch6_hengha_dual_blade or 0) + 1,
    "collection displays armor after dual blade")

eq(EquipmentData.FORGE_RECIPES.ch6_zhenjie_saint_armor.gold, 0, "armor has no gold cost")
for _, recipeId in ipairs(recipeIds) do
    if recipeId ~= "ch6_zhenjie_saint_armor" then
        eq(EquipmentData.FORGE_RECIPES[recipeId].gold, 20000000, recipeId .. " gold cost")
    end
end

local armor = EquipmentData.SpecialEquipment.ch6_zhenjie_saint_armor
eq(armor.specialEffect.type, "zhenjie_shield", "armor effect type")
near(armor.specialEffect.triggerChance, 0.20, "armor trigger chance")
eq(armor.specialEffect.defMultiplier, 3, "armor defense multiplier")
eq(armor.specialEffect.duration, 6, "armor duration")
eq(armor.specialEffect.cooldown, 15, "armor cooldown")

local dualBlade = EquipmentData.SpecialEquipment.ch6_hengha_dual_blade
eq(dualBlade.specialEffect.type, "hengha_fixed_burst", "dual blade effect type")
near(dualBlade.specialEffect.procChance, 0.15, "dual blade trigger chance")
eq(dualBlade.specialEffect.fixedDamage, 50000, "dual blade fixed damage")
eq(dualBlade.specialEffect.cooldown, 1, "dual blade cooldown")
eq(dualBlade.subStats[3].stat, "wisdom", "dual blade third sub stat uses wisdom")
eq(dualBlade.subStats[3].name, "悟性", "dual blade third sub stat display name")
eq(dualBlade.subStats[3].value, 23, "dual blade wisdom value")

local henghaCapture = {}
local fakeCombatSystem = {
    AddSkillEffect = function(_, skillId, range)
        henghaCapture.skillId = skillId
        henghaCapture.range = range
    end,
    AddFloatingText = function(_, _, text, _, lifetime, scale)
        henghaCapture.text = text
        henghaCapture.lifetime = lifetime
        henghaCapture.scale = scale
    end,
}
CombatFeedbackBridge(fakeCombatSystem)
local emitHenghaDamageFeedback = fakeCombatSystem.EmitDamageFeedback
fakeCombatSystem.EmitDamageFeedback = function(source, target, value, opts, legacyFallback)
    henghaCapture.feedbackValue = value
    henghaCapture.sourceType = opts and opts.sourceType
    henghaCapture.sourceName = opts and opts.sourceName
    henghaCapture.damageTag = opts and opts.damageTag
    return emitHenghaDamageFeedback(source, target, value, opts, legacyFallback)
end
local henghaHandler = Ch6ForgeHitEffects.CreateHenghaHandler(fakeCombatSystem)
local critCalls = 0
local henghaPlayer = {
    ApplyCrit = function()
        critCalls = critCalls + 1
        return 999999, true
    end,
}
local henghaMonster = {
    alive = true,
    x = 2,
    y = 3,
    def = 999999,
    hurtFlashTimer = 0,
    TakeDamage = function(self, damage)
        self.receivedDamage = damage
        return damage
    end,
}
local henghaEffect = {
    type = "hengha_fixed_burst",
    procChance = 0.15,
    fixedDamage = 50000,
    cooldown = 1,
}
local oldRandom = math.random
math.random = function() return 0 end
local henghaOk, henghaErr = pcall(henghaHandler.onHit, henghaEffect, henghaPlayer, henghaMonster)
math.random = oldRandom
ok(henghaOk, "dual blade handler executes: " .. tostring(henghaErr))
eq(henghaMonster.receivedDamage, 50000, "dual blade bypasses defense")
eq(critCalls, 0, "dual blade does not roll critical")
eq(henghaEffect._cooldown, 1, "dual blade starts cooldown")
eq(henghaCapture.skillId, "hengha_burst", "dual blade starts dedicated visual")
eq(henghaCapture.text, "哼哈震杀 50000",
    "dual blade hit text has no brackets")
eq(henghaCapture.lifetime, 1.5, "dual blade hit text matches tianzhu lifetime")
eq(henghaCapture.scale, 1.6, "dual blade hit text matches tianzhu scale")
eq(henghaCapture.feedbackValue, 50000, "dual blade feedback uses actual damage")
eq(henghaCapture.sourceType, "equipment", "dual blade feedback keeps equipment source")
eq(henghaCapture.sourceName, "哼哈震杀", "dual blade feedback keeps skill name")
eq(henghaCapture.damageTag, "skill", "dual blade feedback uses skill damage tag")

local realMonster = Monster.New(MonsterData.Types.frog, 2, 3)
realMonster.hp = 1000000
realMonster.maxHp = 1000000
realMonster.def = 999999
realMonster.debuffs.vulnerability = { timer = 10, percent = 1.0 }
realMonster.jadeShieldActive = true
realMonster.jadeShieldDmgReduction = 0.50
realMonster.jadeShieldReflectPercent = 0.50
local fixedDamagePlayer = {
    alive = true,
    petBerserkBonusDmg = 1.0,
    GetWashLevel = function() return 26 end,
    ApplyCrit = function()
        error("fixed damage must not roll critical")
    end,
}
local oldActiveZones = CombatSystem.activeZones
CombatSystem.activeZones = {
    { x = realMonster.x, y = realMonster.y, range = 10, damageBoostPercent = 1.0 },
}
local fixedEffect = {
    type = "hengha_fixed_burst",
    procChance = 1,
    fixedDamage = 50000,
    cooldown = 1,
}
local fixedHandler = Ch6ForgeHitEffects.CreateHenghaHandler(fakeCombatSystem)
local fixedHpBefore = realMonster.hp
local fixedOk, fixedErr = pcall(fixedHandler.onHit, fixedEffect, fixedDamagePlayer, realMonster)
CombatSystem.activeZones = oldActiveZones
ok(fixedOk, "dual blade fixed damage executes through real monster: " .. tostring(fixedErr))
eq(fixedHpBefore - realMonster.hp, 50000,
    "dual blade ignores outgoing and incoming final damage modifiers")

local oldGamePlayer = GameState.player
GameState.player = { equipSpecialEffects = { henghaEffect } }
henghaHandler.update(0.4)
GameState.player = oldGamePlayer
near(henghaEffect._cooldown, 0.6, "dual blade cooldown updates")

local ArtifactCh4 = require("systems.ArtifactSystem_ch4")
local oldBaguaUnlocked = ArtifactCh4.passiveUnlocked
local oldBaguaHp = ArtifactCh4._shieldHp
local oldBaguaMax = ArtifactCh4._shieldMaxHp
local oldBaguaTimer = ArtifactCh4._shieldTimer
ArtifactCh4.passiveUnlocked = true
ArtifactCh4._shieldHp = 1600
ArtifactCh4._shieldMaxHp = 3000
ArtifactCh4._shieldTimer = 18
local stackedShieldPlayer = {
    shieldHp = 800,
    shieldMaxHp = 1200,
    shieldTimer = 5,
    _zhenjieShieldHp = 600,
    _zhenjieShieldMaxHp = 1500,
    _zhenjieShieldDuration = 4,
    _swordShield = { swords = 2, maxSwords = 3 },
}
local stackedShields = PlayerShieldStatus.Collect(stackedShieldPlayer, 4000)
eq(#stackedShields, 3, "all three numeric shield sources are collected")
eq(stackedShields[1].id, "zhenjie", "zhenjie is first shield source")
eq(stackedShields[2].id, "golden_bell", "golden bell is second shield source")
eq(stackedShields[3].id, "bagua", "bagua is third shield source")
near(stackedShields[1].barRatio, 0.15, "zhenjie source uses max hp ratio")
near(stackedShields[2].barRatio, 0.20, "golden bell source uses max hp ratio")
near(stackedShields[3].barRatio, 0.40, "bagua source uses max hp ratio")
eq(PlayerShieldStatus.GetTotalAbsorbHp(stackedShields), 3000,
    "unified shield sums all numeric sources")
near(PlayerShieldStatus.GetUnifiedBarRatio(stackedShields, 4000), 0.75,
    "unified shield bar uses summed shield value")
ok(PlayerShieldStatus.Find(stackedShields, "sword_guard") == nil,
    "sword guard is not treated as a shield")
ArtifactCh4.passiveUnlocked = oldBaguaUnlocked
ArtifactCh4._shieldHp = oldBaguaHp
ArtifactCh4._shieldMaxHp = oldBaguaMax
ArtifactCh4._shieldTimer = oldBaguaTimer

local theoreticalShieldPerSecond = 1000 * armor.specialEffect.defMultiplier / armor.specialEffect.cooldown
local regenPerSecond = 10000 * 0.02
near(theoreticalShieldPerSecond, regenPerSecond, "shield and 2% regen balance at def=10% maxHp")

math.randomseed(611)
local guagua = LootSystem.CreateSaintEquipment("ch6_guagua_junling_ring")
ok(guagua ~= nil, "guagua generation succeeds")
ok(guagua and guagua.saintStat ~= nil, "guagua generates random saint stat")
ok(guagua and guagua.spiritStat == nil, "guagua saint stat excludes spirit stat")
eq(guagua and guagua.quality, "gold", "guagua remains gold immortal equipment")
eq(guagua and guagua.specialEffect and guagua.specialEffect.bonus, 150, "guagua lowest xianyuan bonus")

math.randomseed(612)
local cape = LootSystem.CreateSaintEquipment("ch6_shijie_saint_cape")
ok(cape ~= nil, "shijie cape generation succeeds")
eq(cape and cape.quality, "gold", "shijie cape is gold immortal equipment")
ok(cape and cape.saintStat ~= nil, "shijie cape generates random saint stat")

local player = {
    alive = true,
    hp = 5000,
    shieldHp = 777,
    equipSpecialEffects = { armor.specialEffect },
    GetTotalDef = function() return 1000 end,
}
Ch6ForgeEffects.Initialize(player)
local triggered, shieldValue = Ch6ForgeEffects.TryTrigger(player, 100, function() return 0 end)
ok(triggered, "zhenjie shield triggers on successful roll")
eq(shieldValue, 3000, "zhenjie shield equals 3x total defense")
local hudHp, hudMax, hudDuration, hudCooldown = Ch6ForgeEffects.GetShieldStatus(player)
eq(hudHp, 3000, "zhenjie HUD status current hp")
eq(hudMax, 3000, "zhenjie HUD status max hp")
eq(hudDuration, 6, "zhenjie HUD status duration")
eq(hudCooldown, 15, "zhenjie HUD status cooldown")

local remaining, absorbed = Ch6ForgeEffects.AbsorbDamage(player, 1200)
eq(remaining, 0, "zhenjie shield absorbs incoming damage first")
eq(absorbed, 1200, "zhenjie shield absorbed amount")
eq(player._zhenjieShieldHp, 1800, "zhenjie shield remaining hp")
eq(player.shieldHp, 777, "skill shield pool remains untouched")

Ch6ForgeEffects.Update(player, 6)
eq(player._zhenjieShieldHp, 0, "zhenjie shield expires after duration")
eq(player._zhenjieShieldCooldown, 9, "zhenjie cooldown continues after expiration")

local bottomBarSource = readFile("scripts/ui/BottomBar.lua")
local playerSource = readFile("scripts/entities/Player.lua")
local playerRendererSource = readFile("scripts/rendering/entities/player.lua")
local combatSource = readFile("scripts/systems/CombatSystem.lua")
local ch6HitEffectsSource = readFile("scripts/systems/combat/Ch6ForgeHitEffects.lua")
local shieldStatusSource = readFile("scripts/systems/PlayerShieldStatus.lua")
local skillEffectsSource = readFile("scripts/rendering/effects/skills_b.lua")
local swordForgeUiSource = readFile("scripts/ui/SwordForgeUI.lua")
ok(swordForgeUiSource:find('"▸ 副属性（随机锻造）"', 1, true) ~= nil,
    "forge preview preserves the original range heading")
ok(swordForgeUiSource:find(
    "FormatRange(sub.stat, preview.minValue, preview.maxValue)", 1, true
) ~= nil, "forge preview preserves the original range display")
ok(swordForgeUiSource:find(
    "ForgeStatRules.GetForgeSubStatPreview(recipe, targetDef, sub)", 1, true
) ~= nil, "forge preview reads the unified runtime range rules")
ok(bottomBarSource:find("PlayerShieldStatus.Collect(player, totalMaxHp)", 1, true) ~= nil,
    "bottom bar reads unified player shield status")
ok(bottomBarSource:find('id = "bb_shield_fill"', 1, true) ~= nil,
    "bottom bar has one unified shield fill")
ok(bottomBarSource:find("PlayerShieldStatus.GetUnifiedBarRatio", 1, true) ~= nil,
    "bottom bar renders the summed shield value")
ok(shieldStatusSource:find("御剑护体属于次数格挡", 1, true) ~= nil,
    "shield status explicitly excludes sword guard")
ok(shieldStatusSource:find('id = "sword_guard"', 1, true) == nil,
    "sword guard is absent from numeric shield sources")
ok(playerRendererSource:find("Ch6ForgeEffects.GetShieldStatus(player)", 1, true) ~= nil,
    "player renderer reads zhenjie shield status")
ok(playerRendererSource:find('"镇界 "', 1, true) ~= nil,
    "player renderer shows zhenjie shield value and duration")
ok(playerSource:find('"镇界吸收 "', 1, true) ~= nil,
    "zhenjie absorption has explicit combat feedback")
ok(playerSource:find('"镇界天幕破碎"', 1, true) ~= nil,
    "zhenjie break has explicit combat feedback")
local zhenjieAbsorbPos = playerSource:find("Ch6ForgeEffects.AbsorbDamage(self, damage)", 1, true)
local goldenBellPos = playerSource:find("if self.shieldHp and self.shieldHp > 0 then", 1, true)
local baguaAbsorbPos = playerSource:find("ArtifactCh4.AbsorbDamage(damage)", 1, true)
ok(zhenjieAbsorbPos and goldenBellPos and baguaAbsorbPos
    and zhenjieAbsorbPos < goldenBellPos
    and goldenBellPos < baguaAbsorbPos,
    "all numeric shield sources stack through a stable absorption order")
ok(combatSource:find("Ch6ForgeHitEffects.CreateHenghaHandler", 1, true) ~= nil,
    "combat system registers chapter 6 dual blade handler")
ok(ch6HitEffectsSource:find('"hengha_burst"', 1, true) ~= nil,
    "dual blade triggers dedicated burst visual")
ok(ch6HitEffectsSource:find('"哼哈震杀 "', 1, true) ~= nil,
    "dual blade uses bracket-free combat text")
ok(ch6HitEffectsSource:find('"【哼哈震杀】"', 1, true) == nil,
    "dual blade combat text does not use brackets")
ok(ch6HitEffectsSource:find("HitResolver.FixedDamage", 1, true) ~= nil,
    "dual blade uses the dedicated fixed damage pipeline")
ok(skillEffectsSource:find('["hengha_burst"] = renderHenghaBurst', 1, true) ~= nil,
    "dual blade burst renderer is registered")
ok(swordForgeUiSource:find('local displayText = requiredName .. "（需要装备）"', 1, true) ~= nil,
    "equipped weapon material row always labels the required weapon")
ok(swordForgeUiSource:find('"；当前装备：" .. item.name', 1, true) ~= nil,
    "wrong equipped weapon is shown only as diagnostic context")
ok(swordForgeUiSource:find("item and item.name or requiredText", 1, true) == nil,
    "current weapon can no longer overwrite recipe requirement")

local forgeNpc = nil
for _, npc in ipairs(ZoneDataCh6.NPCs or {}) do
    if npc.id == "ch6_shadow_forge" then
        forgeNpc = npc
        break
    end
end
ok(forgeNpc ~= nil, "chapter 6 shadow forge npc exists")
eq(forgeNpc and forgeNpc.interactType, "shadow_forge", "shadow forge npc interaction")
eq(forgeNpc and forgeNpc.zone, "shadow_spawn_safe", "shadow forge npc safe zone")

return { passed = passed, failed = failed, total = passed + failed }
