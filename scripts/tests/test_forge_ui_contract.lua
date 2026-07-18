-- ============================================================================
-- test_forge_ui_contract.lua - 全铸造界面与实际生成规则合同
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local EquipmentData = require("config.EquipmentData")
local LootSystem = require("systems.LootSystem")
local ForgeStatRules = require("systems.forge.ForgeStatRules")

local passed, failed = 0, 0

local function ok(cond, desc)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. desc)
    end
end

local function eq(actual, expected, desc)
    ok(actual == expected,
        desc .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
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

local function assertGeneratedMatchesPreview(recipeId, recipe, template, item)
    ok(item ~= nil, recipeId .. " generated item exists")
    if not item then return end
    eq(#(item.subStats or {}), #(template.subStats or {}),
        recipeId .. " generated sub stat count")
    for index, templateSub in ipairs(template.subStats or {}) do
        local generatedSub = item.subStats and item.subStats[index]
        local preview = ForgeStatRules.GetForgeSubStatPreview(recipe, template, templateSub)
        eq(generatedSub and generatedSub.stat, templateSub.stat,
            recipeId .. " generated sub stat " .. index .. " type")
        if preview.mode == "range" then
            ok(generatedSub and generatedSub.value >= preview.minValue
                and generatedSub.value <= preview.maxValue,
                recipeId .. " generated sub stat " .. index .. " is inside UI range")
        else
            near(generatedSub and generatedSub.value, preview.value,
                recipeId .. " generated fixed sub stat " .. index)
        end
    end
end

local stationIds = {
    "tiger_trial_forge",
    "wubao_forge",
    "huangsha_forge",
    "dragon_forge",
    "sword_forge",
    "shadow_forge",
}

local recipeCount = 0
local equipRecipeCount = 0
local bagRecipeCount = 0
for _, stationId in ipairs(stationIds) do
    for _, recipeId in ipairs(EquipmentData.FORGE_RECIPE_ORDER[stationId] or {}) do
        recipeCount = recipeCount + 1
        local recipe = EquipmentData.FORGE_RECIPES[recipeId]
        ok(recipe ~= nil, recipeId .. " recipe exists")
        eq(recipe and recipe.stationId, stationId, recipeId .. " UI station")

        if recipe and recipe.inputMode == "equip_weapon" then
            equipRecipeCount = equipRecipeCount + 1
            eq(recipe.outputMode, "replace_weapon",
                recipeId .. " equipped input replaces the current weapon")
            ok(recipe.equipSource ~= nil or recipe.equipSourcePool ~= nil,
                recipeId .. " equipped input declares its required weapon")
        elseif recipe and recipe.inputMode == "bag_consume" then
            bagRecipeCount = bagRecipeCount + 1
            eq(recipe.outputMode, "add_to_bag",
                recipeId .. " bag input adds its output to the bag")
            ok(recipe.equipSource == nil and recipe.equipSourcePool == nil,
                recipeId .. " bag input never requires equipped gear")
        else
            ok(false, recipeId .. " input mode is recognized")
        end

        local outputId = recipe and (recipe.outputId
            or (recipe.generator and recipe.generator.outputId)
            or (recipe.generator and recipe.generator.targetId)
            or (recipe.generator and recipe.generator.templateId))
        local template = outputId and EquipmentData.SpecialEquipment[outputId]
        if template and template.subStats then
            local hasRange = false
            for _, sub in ipairs(template.subStats) do
                local preview = ForgeStatRules.GetForgeSubStatPreview(recipe, template, sub)
                ok(preview.mode == "fixed" or preview.mode == "range",
                    recipeId .. " preview mode is valid")
                if preview.mode == "range" then
                    hasRange = true
                    ok(preview.minValue < preview.maxValue,
                        recipeId .. " preview range increases")
                end
            end

            local generatorType = recipe.generator and recipe.generator.type
            if generatorType == "fixed_special_equipment" then
                ok(not hasRange, recipeId .. " fixed output does not show random ranges")
                assertGeneratedMatchesPreview(
                    recipeId, recipe, template, LootSystem.CreateSpecialEquipment(outputId)
                )
            elseif generatorType == "saint_equipment" then
                math.randomseed(7100 + recipeCount)
                assertGeneratedMatchesPreview(
                    recipeId, recipe, template, LootSystem.CreateSaintEquipment(outputId)
                )
            elseif generatorType == "jiefeng_sword" then
                math.randomseed(7200 + recipeCount)
                assertGeneratedMatchesPreview(
                    recipeId, recipe, template, LootSystem.CreateJiefengSword({}, outputId)
                )
            elseif generatorType == "true_sword" then
                math.randomseed(7300 + recipeCount)
                assertGeneratedMatchesPreview(
                    recipeId, recipe, template, LootSystem.CreateSaintEquipment(outputId)
                )
            end
        end
    end
end
eq(recipeCount, 29, "all forge recipes audited")
eq(equipRecipeCount, 14, "all equipped-weapon recipes audited")
eq(bagRecipeCount, 15, "all bag-consume recipes audited")

local dragonOrder = EquipmentData.FORGE_RECIPE_ORDER.dragon_forge
eq(dragonOrder[6], "zhenlong_helmet_ch4", "dragon forge second row starts with true dragon helmet")
eq(dragonOrder[7], "dragon_longji", "dragon forge second row places dragon extreme token second")
eq(dragonOrder[8], "dragon_lingqi", "dragon forge second row places lingqi crafting third")

local dragonForgeUi = readFile("scripts/ui/DragonForgeUI.lua")
local swordForgeUi = readFile("scripts/ui/SwordForgeUI.lua")
ok(dragonForgeUi:find('"装备升级"', 1, true) ~= nil
    and dragonForgeUi:find('"背包打造"', 1, true) ~= nil,
    "dragon forge distinguishes equipment upgrade and bag crafting")
ok(swordForgeUi:find('"装备升级"', 1, true) ~= nil
    and swordForgeUi:find('"背包打造"', 1, true) ~= nil,
    "shared forge UI distinguishes equipment upgrade and bag crafting")
ok(dragonForgeUi:find('"背包消耗"', 1, true) ~= nil,
    "dragon forge labels bag equipment as bag consumption")
ok(swordForgeUi:find('"背包消耗"', 1, true) ~= nil,
    "shared forge UI labels bag equipment as bag consumption")
ok(dragonForgeUi:find('"9阶  [圣器] 武器"', 1, true) == nil
    and dragonForgeUi:find('"9阶 [圣器] 武器"', 1, true) == nil,
    "dragon forge has no hard-coded output tier quality or slot")
ok(dragonForgeUi:find("EquipmentData.GetTierDisplayName", 1, true) ~= nil
    and dragonForgeUi:find("EquipmentData.SLOT_NAMES", 1, true) ~= nil
    and dragonForgeUi:find("GameConfig.QUALITY[qualityKey]", 1, true) ~= nil,
    "dragon forge derives output identity from the template")
ok(dragonForgeUi:find("local weaponTabs = {}", 1, true) ~= nil
    and dragonForgeUi:find("local extraTabs = {}", 1, true) ~= nil,
    "dragon forge uses explicit weapon and secondary tab rows")
local zhenlongTabPos = dragonForgeUi:find('[6] = { label = "真龙盔"', 1, true)
local longjiTabPos = dragonForgeUi:find('[7] = { label = "龙极令"', 1, true)
local lingqiTabPos = dragonForgeUi:find('[8] = { label = "灵器打造"', 1, true)
ok(zhenlongTabPos ~= nil
    and longjiTabPos ~= nil
    and lingqiTabPos ~= nil
    and zhenlongTabPos < longjiTabPos
    and longjiTabPos < lingqiTabPos,
    "dragon forge secondary row labels are true dragon helmet, dragon extreme token, lingqi crafting")
ok(dragonForgeUi:find('if currentTab_ == 6 then return BuildZhenlongContent() end', 1, true) ~= nil
    and dragonForgeUi:find('if currentTab_ == 7 then return BuildLongjiContent() end', 1, true) ~= nil
    and dragonForgeUi:find('if currentTab_ == 8 then return BuildLingqiContent() end', 1, true) ~= nil,
    "dragon forge secondary row opens the matching content")
ok(swordForgeUi:find("EquipmentUtils.CalcMainStatValue", 1, true) ~= nil,
    "fabao preview uses runtime main-stat formula")

local saintCape = EquipmentData.SpecialEquipment.saint_cape_ch5
local immortalCape = EquipmentData.SpecialEquipment.ch6_shijie_saint_cape
local saintCapeRecipe = EquipmentData.FORGE_RECIPES.saint_cape_ch5
local immortalCapeRecipe = EquipmentData.FORGE_RECIPES.ch6_shijie_saint_cape
local saintCrit = ForgeStatRules.GetForgeSubStatPreview(
    saintCapeRecipe, saintCape, saintCape.subStats[2]
)
local immortalCrit = ForgeStatRules.GetForgeSubStatPreview(
    immortalCapeRecipe, immortalCape, immortalCape.subStats[2]
)
near(saintCrit.minValue, 0.36, "saint cape UI crit damage minimum")
near(saintCrit.maxValue, 0.45, "saint cape UI crit damage maximum")
near(immortalCrit.minValue, 0.396, "immortal cape UI crit damage minimum")
near(immortalCrit.maxValue, 0.528, "immortal cape UI crit damage maximum")
ok(saintCrit.minValue ~= immortalCrit.minValue
    and saintCrit.maxValue ~= immortalCrit.maxValue,
    "saint and immortal cape UI ranges are not identical")

eq(ForgeStatRules.GetForgeExtraStatMode(
    EquipmentData.FORGE_RECIPES.daozang_saint_armor,
    EquipmentData.SpecialEquipment.daozang_saint_armor
), "saint_random", "chapter 5 saint armor preview shows saint stat")
eq(ForgeStatRules.GetForgeExtraStatMode(
    saintCapeRecipe, saintCape
), "saint_random", "chapter 5 saint cape preview shows saint stat")
eq(ForgeStatRules.GetForgeExtraStatMode(
    EquipmentData.FORGE_RECIPES.dizun_saint_ring,
    EquipmentData.SpecialEquipment.dizun_saint_ring
), "saint_fixed", "emperor saint ring preview shows fixed saint stat")
eq(ForgeStatRules.GetForgeExtraStatMode(
    EquipmentData.FORGE_RECIPES.dragon_shengqi_duanliu,
    EquipmentData.SpecialEquipment.shengqi_duanliu
), "spirit_random", "dragon forge preview shows spirit stat")
eq(ForgeStatRules.GetForgeExtraStatMode(
    EquipmentData.FORGE_RECIPES.zhenlong_helmet_ch4,
    EquipmentData.SpecialEquipment.zhenlong_helmet_ch4
), "spirit_fixed", "true dragon helmet preview shows fixed spirit stat")

local zhenlongRecipe = EquipmentData.FORGE_RECIPES.zhenlong_helmet_ch4
local zhenlongTemplate = EquipmentData.SpecialEquipment.zhenlong_helmet_ch4
eq(zhenlongTemplate.tier, 10, "true dragon helmet preview tier")
eq(zhenlongTemplate.quality, "cyan", "true dragon helmet preview quality")
eq(zhenlongTemplate.slot, "helmet", "true dragon helmet preview slot")
for index, sub in ipairs(zhenlongTemplate.subStats or {}) do
    local preview = ForgeStatRules.GetForgeSubStatPreview(zhenlongRecipe, zhenlongTemplate, sub)
    eq(preview.mode, "fixed", "true dragon helmet sub stat " .. index .. " is fixed")
    near(preview.value, sub.value, "true dragon helmet sub stat " .. index .. " exact value")
end
near(zhenlongTemplate.spiritStat and zhenlongTemplate.spiritStat.value,
    0.1875, "true dragon helmet fixed spirit value")

local rerollMin, rerollMax = ForgeStatRules.GetRerollRange("def", 11, "red")
eq(rerollMin, 14, "reroll defense UI minimum uses runtime rounding")
eq(rerollMax, 22, "reroll defense UI maximum uses runtime rounding")
for index = 0, 20 do
    local value = ForgeStatRules.RollRerollValue("def", 11, "red", index / 20)
    ok(value >= rerollMin and value <= rerollMax,
        "reroll defense sample remains inside displayed range " .. index)
end

local swordForgeSource = readFile("scripts/ui/SwordForgeUI.lua")
local dragonForgeSource = readFile("scripts/ui/DragonForgeUI.lua")
local forgeUiSource = readFile("scripts/ui/ForgeUI.lua")
ok(swordForgeSource:find("ForgeStatRules.GetForgeSubStatPreview", 1, true) ~= nil,
    "SwordForgeUI uses unified preview rules")
ok(swordForgeSource:find("ForgeStatRules.GetForgeExtraStatMode", 1, true) ~= nil,
    "SwordForgeUI uses unified spirit/saint rules")
ok(dragonForgeSource:find("ForgeStatRules.GetForgeSubStatPreview", 1, true) ~= nil
    and dragonForgeSource:find("ForgeStatRules.GetForgeExtraStatMode", 1, true) ~= nil,
    "DragonForgeUI uses unified preview rules")
ok(forgeUiSource:find("ForgeStatRules.GetRerollRange", 1, true) ~= nil
    and forgeUiSource:find("ForgeStatRules.RollRerollValue", 1, true) ~= nil,
    "ForgeUI display and roll use the same rounding rules")

print(string.format("[test_forge_ui_contract] %d/%d passed", passed, passed + failed))
return { passed = passed, failed = failed, total = passed + failed }
