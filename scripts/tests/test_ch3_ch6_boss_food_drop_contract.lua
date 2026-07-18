-- ============================================================================
-- test_ch3_ch6_boss_food_drop_contract.lua
-- 第3-6章 BOSS 宠物食物掉落契约：单食物框、数量字段与期望经验
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local passed, failed, total = 0, 0, 0
local errors = {}

local function assertTrue(cond, msg)
    if not cond then error(msg or "assertTrue failed", 2) end
end

local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assertEqual failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

local function assertNear(actual, expected, msg)
    if math.abs((actual or 0) - expected) > 0.000001 then
        error((msg or "assertNear failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS " .. name)
    else
        failed = failed + 1
        errors[#errors + 1] = name .. ": " .. tostring(err)
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

local GameConfig = require("config.GameConfig")
local MonsterData = require("config.MonsterData")

local PET_FOOD = GameConfig.PET_FOOD or {}

local function amountExpected(amount)
    if type(amount) == "table" then
        return ((amount[1] or 1) + (amount[2] or amount[1] or 1)) * 0.5
    end
    return amount or 1
end

local function getMonster(monsterId)
    local monster = MonsterData.Types and MonsterData.Types[monsterId]
    assertTrue(monster ~= nil, "monster missing: " .. monsterId)
    return monster
end

local function getFoodDrops(monsterId)
    local drops = {}
    for _, drop in ipairs(getMonster(monsterId).dropTable or {}) do
        if drop.type == "consumable" and drop.consumableId and PET_FOOD[drop.consumableId] then
            drops[#drops + 1] = drop
        end
    end
    return drops
end

local function checkFood(spec)
    test(spec.id .. " food", function()
        local drops = getFoodDrops(spec.id)
        assertEqual(#drops, 1, spec.id .. " food drop count")
        local drop = drops[1]
        assertEqual(drop.consumableId, spec.food, spec.id .. " food id")
        assertNear(drop.chance, spec.chance, spec.id .. " food chance")
        assertTrue(drop.count == nil, spec.id .. " should not use ineffective count field")
        if spec.amount then
            assertTrue(type(drop.amount) == "table", spec.id .. " amount missing")
            assertEqual(drop.amount[1], spec.amount[1], spec.id .. " amount min")
            assertEqual(drop.amount[2], spec.amount[2], spec.id .. " amount max")
        else
            assertTrue(drop.amount == nil, spec.id .. " unexpected amount")
        end
        local exp = PET_FOOD[drop.consumableId].exp * drop.chance * amountExpected(drop.amount)
        assertNear(exp, spec.expected, spec.id .. " food expected exp")
    end)
end

print("--- Ch3-Ch6 boss food drop contract ---")

for _, spec in ipairs({
    -- 第3章
    { id = "yao_king_8", food = "immortal_bone", chance = 0.20, expected = 60 },
    { id = "yao_king_7", food = "immortal_bone", chance = 0.25, expected = 75 },
    { id = "liusha_son_outer", food = "immortal_bone", chance = 1.0, expected = 300 },
    { id = "yao_king_6", food = "immortal_bone", chance = 0.30, expected = 90 },
    { id = "yao_king_5", food = "immortal_bone", chance = 0.35, expected = 105 },
    { id = "yao_king_4", food = "immortal_bone", chance = 0.40, expected = 120 },
    { id = "liusha_son_mid", food = "immortal_bone", chance = 1.0, expected = 300 },
    { id = "yao_king_3", food = "immortal_bone", chance = 0.45, expected = 135 },
    { id = "yao_king_2", food = "immortal_bone", chance = 0.50, expected = 150 },
    { id = "kumu_guard", food = "immortal_bone", chance = 0.31333333333333335, expected = 94 },
    { id = "liusha_mother", food = "immortal_bone", chance = 1.0, expected = 300 },
    { id = "yao_king_1", food = "demon_essence", chance = 0.50, expected = 400 },

    -- 第4章
    { id = "kan_boss", food = "demon_essence", chance = 0.10, expected = 80 },
    { id = "gen_boss", food = "demon_essence", chance = 0.15, expected = 120 },
    { id = "zhen_boss", food = "demon_essence", chance = 0.20, expected = 160 },
    { id = "xun_boss", food = "demon_essence", chance = 0.25, expected = 200 },
    { id = "yin_spirit", food = "demon_essence", chance = 0.30, expected = 240 },
    { id = "li_boss", food = "demon_essence", chance = 0.30, expected = 240 },
    { id = "kun_boss", food = "demon_essence", chance = 0.35, expected = 280 },
    { id = "dui_boss", food = "demon_essence", chance = 0.40, expected = 320 },
    { id = "qian_pillar_e", food = "demon_essence", chance = 0.20, expected = 160 },
    { id = "qian_pillar_s", food = "demon_essence", chance = 0.20, expected = 160 },
    { id = "qian_pillar_n", food = "demon_essence", chance = 0.20, expected = 160 },
    { id = "qian_pillar_w", food = "demon_essence", chance = 0.20, expected = 160 },
    { id = "qian_boss", food = "demon_essence", chance = 1.0, expected = 800 },
    { id = "yang_spirit", food = "demon_essence", chance = 1.0, expected = 800 },
    { id = "dragon_abyss", food = "dragon_marrow", chance = 0.50, expected = 1500 },
    { id = "dragon_fire", food = "dragon_marrow", chance = 0.50, expected = 1500 },
    { id = "dragon_ice", food = "dragon_marrow", chance = 0.50, expected = 1500 },
    { id = "dragon_sand", food = "dragon_marrow", chance = 0.50, expected = 1500 },

    -- 第5章
    { id = "ch5_pei_qianyue", food = "dragon_marrow", chance = 0.15, expected = 450 },
    { id = "ch5_stone_guardian", food = "dragon_marrow", chance = 0.10, expected = 300 },
    { id = "ch5_frost_luan", food = "dragon_marrow", chance = 0.20, expected = 600 },
    { id = "ch5_han_bailian", food = "dragon_marrow", chance = 0.25, expected = 750 },
    { id = "ch5_shi_guanlan", food = "dragon_marrow", chance = 0.30, expected = 900 },
    { id = "ch5_ning_qiwu", food = "dragon_marrow", chance = 0.35, expected = 1050 },
    { id = "ch5_wen_suzhang", food = "dragon_marrow", chance = 0.40, expected = 1200 },
    { id = "ch5_blood_general", food = "dragon_marrow", chance = 0.50, expected = 1500 },
    { id = "ch5_abyss_marshal", food = "dragon_marrow", chance = 1.0, amount = {1, 1}, expected = 3000 },
    { id = "ch5_marshal_liesoul", food = "dragon_marrow", chance = 1.0, amount = {1, 1}, expected = 3000 },
    { id = "ch5_marshal_shugu", food = "dragon_marrow", chance = 1.0, amount = {1, 1}, expected = 3000 },
    { id = "ch5_sword_jue", food = "dragon_marrow", chance = 1.0, amount = {1, 2}, expected = 4500 },
    { id = "ch5_sword_lu", food = "dragon_marrow", chance = 1.0, amount = {1, 2}, expected = 4500 },
    { id = "ch5_sword_xian", food = "dragon_marrow", chance = 1.0, amount = {1, 2}, expected = 4500 },
    { id = "ch5_sword_zhu", food = "dragon_marrow", chance = 1.0, amount = {1, 2}, expected = 4500 },

    -- 第6章
    { id = "ch6_patrol_immortal_soldier", food = "demon_essence", chance = 0.25, expected = 200 },
    { id = "ch6_shadow_wanderer", food = "demon_essence", chance = 0.50, expected = 400 },
    { id = "ch6_mountain_colossus", food = "demon_essence", chance = 0.75, expected = 600 },
    { id = "ch6_east_celestial_soldier", food = "demon_essence", chance = 1.0, expected = 800 },
    { id = "ch6_west_celestial_soldier", food = "demon_essence", chance = 1.0, expected = 800 },
    { id = "ch6_lingfeng", food = "dragon_marrow", chance = 0.60, expected = 1800 },
    { id = "ch6_zhuyou", food = "dragon_marrow", chance = 0.80, expected = 2400 },
    { id = "ch6_duanyue", food = "dragon_marrow", chance = 1.0, expected = 3000 },
    { id = "ch6_toad_immortal", food = "dragon_marrow", chance = 0.40, expected = 1200 },
    { id = "ch6_pojun", food = "immortal_beast_soul", chance = 0.50, amount = {1, 1}, expected = 4000 },
    { id = "ch6_qingfeng", food = "immortal_beast_soul", chance = 0.50, amount = {1, 1}, expected = 4000 },
    { id = "ch6_leice", food = "immortal_beast_soul", chance = 0.50, amount = {1, 1}, expected = 4000 },
    { id = "ch6_zhenyuan", food = "immortal_beast_soul", chance = 0.50, amount = {1, 1}, expected = 4000 },
    { id = "ch6_gua_master", food = "immortal_beast_soul", chance = 1.0, amount = {1, 2}, expected = 12000 },
    { id = "ch6_ha_marshal", food = "immortal_beast_soul", chance = 1.0, amount = {1, 1}, expected = 8000 },
    { id = "ch6_heng_marshal", food = "immortal_beast_soul", chance = 0.50, amount = {1, 1}, expected = 4000 },
    { id = "ch6_mojun_shixuan", food = "immortal_beast_soul", chance = 1.0, amount = {2, 2}, expected = 16000 },
}) do
    checkFood(spec)
end

print(string.format("--- Ch3-Ch6 boss food drop contract: %d/%d passed, %d failed ---", passed, total, failed))

return { passed = passed, failed = failed, total = total, errors = errors }
