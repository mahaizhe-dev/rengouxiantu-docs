-- ============================================================================
-- test_ch6_special_equipment.lua — 第六章掉落特殊装备合同测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local EquipmentData = require("config.EquipmentData")
local MonsterData = require("config.MonsterData")
local LootSystem = require("systems.LootSystem")
local CollectionSystem = require("systems.CollectionSystem")
local equipStats = require("systems.inventory.equip_stats")
local GameState = require("core.GameState")

local passed = 0
local failed = 0

local function fail(desc)
    failed = failed + 1
    print("  FAIL: " .. desc)
end

local function ok(cond, desc)
    if cond then
        passed = passed + 1
    else
        fail(desc)
    end
end

local function eq(actual, expected, desc)
    if actual == expected then
        passed = passed + 1
    else
        fail(desc .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

local function near(actual, expected, desc)
    if math.abs((actual or 0) - expected) < 0.000001 then
        passed = passed + 1
    else
        fail(desc .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

local function hasDrop(monsterId, equipId, chance)
    local monster = MonsterData.Types[monsterId]
    if not monster or not monster.dropTable then return false end
    for _, entry in ipairs(monster.dropTable) do
        if entry.type == "equipment" and entry.equipId == equipId then
            return math.abs((entry.chance or 0) - chance) < 0.000001
        end
    end
    return false
end

local function findSub(item, stat)
    for _, sub in ipairs(item.subStats or {}) do
        if sub.stat == stat then return sub.value end
    end
    return nil
end

local function assertStatTable(actual, expected, descPrefix)
    for stat, value in pairs(expected or {}) do
        near(actual and actual[stat], value, descPrefix .. " " .. stat)
    end
end

local function assertSubStats(item, expected, descPrefix)
    for stat, value in pairs(expected or {}) do
        near(findSub(item, stat), value, descPrefix .. " " .. stat)
    end
end

local function assertSubStatTypes(item, expected, descPrefix)
    for stat, _ in pairs(expected or {}) do
        ok(findSub(item, stat) ~= nil, descPrefix .. " has " .. stat)
    end
end

local function assertExtraStat(actual, expected, descPrefix)
    if expected then
        ok(actual ~= nil, descPrefix .. " exists")
        if actual then
            eq(actual.stat, expected.stat, descPrefix .. " stat")
            eq(actual.name, expected.name, descPrefix .. " name")
            near(actual.value, expected.value, descPrefix .. " value")
            if expected.confirmed ~= nil then
                eq(actual.confirmed, expected.confirmed, descPrefix .. " confirmed")
            end
        end
    else
        ok(actual == nil, descPrefix .. " absent")
    end
end

local expected = {
    {
        id = "ch6_xuntian_helmet", quality = "orange", slot = "helmet", setId = "ch6_xuntian_guard",
        sources = { { monster = "ch6_patrol_immortal_soldier", chance = 0.005 } },
        main = { maxHp = 750 }, sub = { def = 19.8, hpRegen = 8.25, killHeal = 49.5 },
        collection = { def = 8, maxHp = 30 }, sellPrice = 2500,
    },
    {
        id = "ch6_xuntian_boots", quality = "orange", slot = "boots", setId = "ch6_xuntian_guard",
        sources = { { monster = "ch6_lingfeng", chance = 0.01 } },
        main = { speed = 0.40 }, sub = { def = 19.8, maxHp = 99, hpRegen = 8.25 },
        collection = { def = 8, maxHp = 30 }, sellPrice = 2500,
    },
    {
        id = "ch6_yingyou_ring", quality = "orange", slot = "ring1", setId = "ch6_yingyou_assault",
        sources = { { monster = "ch6_shadow_wanderer", chance = 0.005 } },
        main = { atk = 112 }, sub = { critRate = 0.0726, critDmg = 0.363, killHeal = 49.5 },
        collection = { atk = 8, killHeal = 12 }, sellPrice = 2500,
    },
    {
        id = "ch6_yingyou_necklace", quality = "orange", slot = "necklace", setId = "ch6_yingyou_assault",
        sources = { { monster = "ch6_zhuyou", chance = 0.01 } },
        main = { critRate = 0.40 }, sub = { atk = 24.75, critDmg = 0.363, killHeal = 49.5 },
        collection = { atk = 8, killHeal = 12 }, sellPrice = 2500,
    },
    {
        id = "ch6_lieshan_shoulder", quality = "orange", slot = "shoulder", setId = "ch6_lieshan_vitality",
        sources = { { monster = "ch6_mountain_colossus", chance = 0.005 } },
        main = { def = 112 }, sub = { maxHp = 99, hpRegen = 8.25, killHeal = 49.5 },
        collection = { def = 8, maxHp = 30 }, sellPrice = 2500,
    },
    {
        id = "ch6_lieshan_armor", quality = "orange", slot = "armor", setId = "ch6_lieshan_vitality",
        sources = { { monster = "ch6_duanyue", chance = 0.01 } },
        main = { def = 150 }, sub = { maxHp = 99, hpRegen = 8.25, killHeal = 49.5 },
        collection = { def = 8, maxHp = 30 }, sellPrice = 2500,
    },
    {
        id = "ch6_tianbing_belt", quality = "orange", slot = "belt", setId = "ch6_tianbing_battle",
        sources = { { monster = "ch6_west_celestial_soldier", chance = 0.005 } },
        main = { maxHp = 562 }, sub = { killHeal = 49.5, critDmg = 0.363, def = 19.8 },
        collection = { atk = 8, maxHp = 30 }, sellPrice = 2500,
    },
    {
        id = "ch6_tianbing_weapon", quality = "orange", slot = "weapon", setId = "ch6_tianbing_battle",
        sources = { { monster = "ch6_east_celestial_soldier", chance = 0.005 } },
        main = { atk = 187 }, sub = { killHeal = 49.5, critRate = 0.0726, critDmg = 0.363 },
        collection = { atk = 8, maxHp = 30 }, sellPrice = 2500,
    },
    {
        id = "ch6_zhenjie_helmet", quality = "cyan", slot = "helmet",
        sources = {
            { monster = "ch6_west_celestial_soldier", chance = 0.001 },
            { monster = "ch6_east_celestial_soldier", chance = 0.001 },
        },
        main = { maxHp = 900 }, sub = { wisdom = 24, atk = 24.75, killHeal = 49.5 },
        spirit = { stat = "wisdom", name = "悟性", value = 9 },
        collection = { def = 8, maxHp = 30 },
    },
    {
        id = "ch6_zhenjie_armor", quality = "cyan", slot = "armor",
        sources = { { monster = "ch6_pojun", chance = 0.002 } },
        main = { def = 180 }, sub = { constitution = 18, maxHp = 99, hpRegen = 8.25 },
        spirit = { stat = "constitution", name = "根骨", value = 9 },
        collection = { def = 8, maxHp = 30 },
    },
    {
        id = "ch6_zhenjie_shoulder", quality = "cyan", slot = "shoulder",
        sources = { { monster = "ch6_zhenyuan", chance = 0.002 } },
        main = { def = 135 }, sub = { physique = 18, hpRegen = 8.25, killHeal = 49.5 },
        spirit = { stat = "physique", name = "体魄", value = 9 },
        collection = { def = 8, maxHp = 30 },
    },
    {
        id = "ch6_zhenjie_belt", quality = "cyan", slot = "belt",
        sources = { { monster = "ch6_qingfeng", chance = 0.002 } },
        main = { maxHp = 675 }, sub = { fortune = 18, killHeal = 49.5, atk = 24.75 },
        spirit = { stat = "fortune", name = "福缘", value = 9 },
        collection = { atk = 8, def = 8 },
    },
    {
        id = "ch6_zhenjie_boots", quality = "cyan", slot = "boots",
        sources = { { monster = "ch6_leice", chance = 0.002 } },
        main = { speed = 0.45 }, sub = { wisdom = 18, def = 19.8, maxHp = 99 },
        spirit = { stat = "wisdom", name = "悟性", value = 9 },
        collection = { def = 8, maxHp = 30 },
    },
    {
        id = "ch6_toad_immortal_boots", quality = "red", slot = "boots",
        sources = { { monster = "ch6_toad_immortal", chance = 0.001 } },
        main = { speed = 0.50 }, sub = { critDmg = 0.396, atk = 27, maxHp = 108 },
        spirit = { stat = "fortune", name = "福缘", value = 11.5 },
        specialEffect = "evade_damage",
        collection = { maxHp = 30, hpRegen = 2 },
    },
    {
        id = "ch6_heng_weapon", quality = "red", slot = "weapon",
        sources = { { monster = "ch6_heng_marshal", chance = 0.001 } },
        main = { atk = 262.5 }, sub = { critDmg = 0.396, hpRegen = 9, fortune = 23 },
        spirit = { stat = "tianzhuChance", name = "天诛概率", value = 0.01 },
        collection = { atk = 8, killHeal = 12 },
    },
    {
        id = "ch6_heng_cyan_helmet", quality = "cyan", slot = "helmet", setId = "ch6_hengha_regen",
        sources = { { monster = "ch6_heng_marshal", chance = 0.005 } },
        main = { maxHp = 900 }, sub = { physique = 30, hpRegen = 8.25, critDmg = 0.363 },
        spirit = { stat = "tianzhuChance", name = "天诛概率", value = 0.01 },
        collection = { def = 8, hpRegen = 1 },
    },
    {
        id = "ch6_ha_weapon", quality = "red", slot = "weapon",
        sources = { { monster = "ch6_ha_marshal", chance = 0.001 } },
        main = { atk = 262.5 }, sub = { critRate = 0.0792, killHeal = 54, fortune = 23 },
        spirit = { stat = "tianzhuDamage", name = "天诛伤害", value = 0.05 },
        collection = { atk = 8, killHeal = 12 },
    },
    {
        id = "ch6_ha_cyan_armor", quality = "cyan", slot = "armor", setId = "ch6_hengha_regen",
        sources = { { monster = "ch6_ha_marshal", chance = 0.005 } },
        main = { def = 180 }, sub = { constitution = 30, heavyHit = 132, critRate = 0.0726 },
        spirit = { stat = "tianzhuDamage", name = "天诛伤害", value = 0.05 },
        collection = { maxHp = 30, hpRegen = 1 },
    },
    {
        id = "ch6_gua_king_ring", quality = "red", slot = "ring2",
        sources = { { monster = "ch6_gua_master", chance = 0.002 } },
        main = { atk = 157.5 }, sub = { def = 21.6, maxHp = 108, hpRegen = 9 },
        specialEffect = "xianyuan_lowest_boost",
        collection = { atk = 8, maxHp = 30 },
    },
    {
        id = "ch6_xianzun_1_ring", name = "仙尊壹戒", quality = "red", slot = "ring1",
        sources = {
            { monster = "ch6_gua_master", chance = 0.002 },
            { monster = "ch6_mojun_shixuan", chance = 0.002 },
        },
        main = { atk = 157.5 }, sub = { wisdom = 23, constitution = 23, physique = 23 },
        saint = { stat = "fortune", name = "福缘", value = 23, confirmed = true },
        collection = { fortune = 7 },
    },
    {
        id = "ch6_shixuan_demon_cape", quality = "red", slot = "cape",
        sources = { { monster = "ch6_mojun_shixuan", chance = 0.002 } },
        main = { dmgReduce = 0.378 }, sub = { critDmg = 0.396, maxHp = 108, def = 21.6 },
        saint = { stat = "tianzhuChance", name = "天诛概率", value = 0.02, confirmed = true },
        collection = { def = 8, maxHp = 30, hpRegen = 2 },
    },
}

for _, exp in ipairs(expected) do
    local tpl = EquipmentData.SpecialEquipment[exp.id]
    ok(tpl ~= nil, exp.id .. " template exists")
    if tpl then
        eq(tpl.slot, exp.slot, exp.id .. " slot")
        if exp.name then
            eq(tpl.name, exp.name, exp.id .. " name")
        end
        eq(tpl.quality, exp.quality, exp.id .. " quality")
        eq(tpl.tier, 11, exp.id .. " tier")
        eq(tpl.setId, exp.setId, exp.id .. " setId")
        ok(tpl.fixedSubStats == true, exp.id .. " fixedSubStats")
        if exp.setId then
            ok(EquipmentData.SetBonuses[exp.setId] ~= nil, exp.id .. " set bonus exists")
        end
        eq(tpl.sellPrice, exp.sellPrice or 7, exp.id .. " sellPrice")
        local expectedSellCurrency = "lingYun"
        if exp.quality == "orange" then
            expectedSellCurrency = nil
        end
        eq(tpl.sellCurrency, expectedSellCurrency, exp.id .. " sellCurrency")
        assertStatTable(tpl.mainStat, exp.main, exp.id .. " template main")
        assertSubStatTypes(tpl, exp.sub, exp.id .. " template sub type")
        assertExtraStat(tpl.spiritStat, exp.spirit, exp.id .. " template spiritStat")
        assertExtraStat(tpl.saintStat, exp.saint, exp.id .. " template saintStat")
        if exp.specialEffect then
            ok(tpl.specialEffect ~= nil, exp.id .. " specialEffect exists")
            if tpl.specialEffect then
                eq(tpl.specialEffect.type, exp.specialEffect, exp.id .. " specialEffect type")
            end
        else
            ok(tpl.specialEffect == nil, exp.id .. " specialEffect absent")
        end

        local iconFile = io.open("assets/" .. tpl.icon, "rb")
        ok(iconFile ~= nil, exp.id .. " icon file exists")
        if iconFile then iconFile:close() end

        local generated = LootSystem.CreateSpecialEquipment(exp.id)
        ok(generated ~= nil, exp.id .. " can be generated")
        if generated then
            eq(generated.equipId, exp.id, exp.id .. " generated equipId")
            eq(generated.isSpecial, true, exp.id .. " generated isSpecial")
            eq(generated.setId, exp.setId, exp.id .. " generated setId")
            assertStatTable(generated.mainStat, exp.main, exp.id .. " generated main")
            assertSubStats(generated, exp.sub, exp.id .. " generated sub")
            assertExtraStat(generated.spiritStat, exp.spirit, exp.id .. " generated spiritStat")
            assertExtraStat(generated.saintStat, exp.saint, exp.id .. " generated saintStat")
        end

        local forced = LootSystem.GenerateDrops({
            { chance = 1.0, type = "equipment", equipId = exp.id },
        }, { level = 140, category = "boss" })
        ok(forced and forced.items and #forced.items == 1, exp.id .. " forced drop chain produced item")
        if forced and forced.items and forced.items[1] then
            eq(forced.items[1].equipId, exp.id, exp.id .. " forced drop equipId")
        end
    end

    for _, source in ipairs(exp.sources) do
        ok(hasDrop(source.monster, exp.id, source.chance), exp.id .. " drop source/chance " .. source.monster)
    end

    local coll = EquipmentData.Collection.entries[exp.id]
    ok(coll ~= nil, exp.id .. " collection entry exists")
    if coll then
        for stat, value in pairs(exp.collection) do
            eq(coll.bonus[stat], value, exp.id .. " collection " .. stat)
        end
    end
end

local setData = EquipmentData.SetBonuses.ch6_hengha_regen
ok(setData ~= nil, "ch6_hengha_regen set exists")
if setData and setData.pieces and setData.pieces[2] then
    eq(setData.pieces[2].bonuses.hpRegen, 60, "ch6_hengha_regen 2pc hpRegen")
end

local forgePools = EquipmentData.FORGE_SET_POOLS or {}
for poolId, ids in pairs(forgePools) do
    for _, setId in ipairs(ids) do
        ok(setId ~= "ch6_hengha_regen", "ch6_hengha_regen not in forge set pool " .. tostring(poolId))
    end
end

do
    local hengHelm = LootSystem.CreateSpecialEquipment("ch6_heng_cyan_helmet")
    local haArmor = LootSystem.CreateSpecialEquipment("ch6_ha_cyan_armor")
    local equipped = { helmet = hengHelm, armor = haArmor }
    local fakeManager = {
        GetAllEquipment = function()
            return equipped
        end,
    }
    local fakeIS = {
        GetManager = function()
            return fakeManager
        end,
    }
    local oldPlayerForSet = GameState.player
    local setPlayer = {
        hp = 100,
        wineSlots = {},
        invalidated = 0,
        InvalidateStatsCache = function(self)
            self.invalidated = self.invalidated + 1
        end,
        GetTotalMaxHp = function()
            return 999999
        end,
    }
    GameState.player = setPlayer
    equipStats.RecalcEquipStats(fakeIS)

    near(setPlayer.equipHpRegen, 68.25, "ch6_hengha_regen applied hpRegen through equip stats")
    near(setPlayer.equipHp, 900, "hengha equipped maxHp")
    near(setPlayer.equipDef, 180, "hengha equipped def")
    near(setPlayer.equipTianzhuChance, 0.01, "hengha equipped tianzhuChance")
    near(setPlayer.equipTianzhuDamage, 0.05, "hengha equipped tianzhuDamage")
    ok(setPlayer.invalidated > 0, "hengha equip stats invalidated player stats")

    local active = equipStats.GetActiveSetBonuses(fakeIS)
    ok(#active == 1, "hengha active set count")
    if active[1] then
        eq(active[1].description, "生命回复 +60", "hengha active set description")
        eq(active[1].threshold, 2, "hengha active set threshold")
    end

    GameState.player = oldPlayerForSet
end

for _, monsterId in ipairs({
    "ch6_patrol_immortal_soldier", "ch6_lingfeng", "ch6_shadow_wanderer", "ch6_zhuyou",
    "ch6_mountain_colossus", "ch6_duanyue", "ch6_west_celestial_soldier", "ch6_pojun",
    "ch6_zhenyuan", "ch6_heng_marshal", "ch6_east_celestial_soldier", "ch6_qingfeng",
    "ch6_leice", "ch6_ha_marshal", "ch6_toad_immortal", "ch6_gua_master", "ch6_mojun_shixuan",
}) do
    local monster = MonsterData.Types[monsterId]
    for _, entry in ipairs(monster.dropTable or {}) do
        ok(entry.type ~= "set_equipment", monsterId .. " does not use set_equipment")
    end
end

local oldPlayer = GameState.player
local oldCollected = CollectionSystem.collected
local mockPlayer = {
    invalidated = false,
    InvalidateStatsCache = function(self)
        self.invalidated = true
    end,
}

GameState.player = mockPlayer
CollectionSystem.collected = {}
for _, exp in ipairs(expected) do
    CollectionSystem.collected[exp.id] = true
end
CollectionSystem.RecalcBonuses()

eq(mockPlayer.collectionAtk, 64, "collection applied total atk")
eq(mockPlayer.collectionDef, 88, "collection applied total def")
eq(mockPlayer.collectionHp, 420, "collection applied total maxHp")
eq(mockPlayer.collectionKillHeal, 48, "collection applied total killHeal")
eq(mockPlayer.collectionHpRegen, 6, "collection applied total hpRegen")
eq(mockPlayer.collectionFortune, 7, "collection applied total fortune")
ok(mockPlayer.invalidated, "collection invalidated player stats")

GameState.player = oldPlayer
CollectionSystem.collected = oldCollected

return { passed = passed, failed = failed, total = passed + failed }
