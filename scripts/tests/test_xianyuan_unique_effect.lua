-- ============================================================================
-- test_xianyuan_unique_effect.lua - 均灵类唯一特效结算回归
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local Player = require("entities.Player")

local passed = 0
local failed = 0

local function eq(actual, expected, desc)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. desc .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

local ordinary = EquipmentData.SpecialEquipment.lingqi_ring_ch5.specialEffect
local guaKing = EquipmentData.SpecialEquipment.ch6_gua_king_ring.specialEffect
local guagua = EquipmentData.SpecialEquipment.ch6_guagua_junling_ring.specialEffect

eq(ordinary.bonus, 100, "ordinary junling ring bonus")
eq(guaKing.bonus, 100, "gua king ring bonus")
eq(guagua.bonus, 150, "guagua junling ring bonus")

local previousCosmetics = GameState.accountCosmetics
GameState.accountCosmetics = {}

local function NewPlayer(constitution, physique, fortune, wisdom, effects)
    local player = Player.New(0, 0, { classId = "xianyuan_test" })
    player.level = 0
    player.def = 100
    player.maxHp = 1000
    player.equipConstitution = constitution
    player.equipPhysique = physique
    player.equipFortune = fortune
    player.equipWisdom = wisdom
    player.equipSpecialEffects = effects
    player:InvalidateStatsCache()
    return player
end

local weakFirst = NewPlayer(10, 20, 30, 40, { ordinary, guagua })
eq(weakFirst:GetTotalConstitution(), 160, "100 then 150 uses the higher bonus")

local strongFirst = NewPlayer(10, 20, 30, 40, { guagua, ordinary })
eq(strongFirst:GetTotalConstitution(), 160, "150 then 100 is order independent")

local equalBonuses = NewPlayer(30, 10, 20, 40, { ordinary, guaKing })
eq(equalBonuses:GetTotalPhysique(), 110, "100 plus 100 applies only once")

local tiedLowest = NewPlayer(10, 10, 20, 30, { guaKing, guagua })
eq(tiedLowest:GetTotalConstitution(), 160, "tied lowest constitution gets highest bonus")
eq(tiedLowest:GetTotalPhysique(), 160, "tied lowest physique gets highest bonus")
eq(tiedLowest:GetTotalFortune(), 20, "non-lowest fortune is unchanged")
eq(tiedLowest:GetTotalWisdom(), 30, "non-lowest wisdom is unchanged")

local derivedConstitution = NewPlayer(10, 20, 30, 40, { ordinary, guagua })
eq(derivedConstitution:GetTotalDef(), 132, "boosted constitution affects derived defense")

local derivedPhysique = NewPlayer(20, 10, 30, 40, { guagua, ordinary })
eq(derivedPhysique:GetTotalMaxHp(), 1320, "boosted physique affects derived max hp")

local mixedEffects = NewPlayer(10, 20, 30, 40, {
    ordinary,
    { type = "def_boost", defPercent = 0.25 },
})
eq(mixedEffects:GetTotalDef(), 147, "different effect types remain simultaneously active")

GameState.accountCosmetics = previousCosmetics

return { passed = passed, failed = failed, total = passed + failed }
