---@diagnostic disable
-- ============================================================================
-- test_combat_yuanying_skills.lua
-- 元婴 T1 技能与太虚职业改动回归测试
--
-- 约束：
--   1. 不调用 CombatSystem.Init / SkillSystem.Init / InventorySystem.Init。
--   2. 不读写真实存档。
--   3. 只使用 mock player / monster 验证结算边界。
-- ============================================================================

package.path = package.path .. ";scripts/?.lua"

local SkillData = require("config.SkillData")
local GameState = require("core.GameState")
local CombatSystem = require("systems.CombatSystem")
local CastingA = require("systems.skill.casting_a")
local CastingB = require("systems.skill.casting_b")
local Passives = require("systems.skill.passives")

local passed = 0
local failed = 0
local total = 0

local savedRandom = math.random
local savedPlayer = GameState.player
local savedMonsters = GameState.monsters

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  [PASS] " .. name)
    else
        failed = failed + 1
        print("  [FAIL] " .. name .. ": " .. tostring(err))
    end
end

local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assertEqual") .. " expected=" .. tostring(expected) .. " got=" .. tostring(actual))
    end
end

local function assertNear(actual, expected, tol, msg)
    tol = tol or 0.001
    if math.abs(actual - expected) > tol then
        error((msg or "assertNear") .. " expected=" .. tostring(expected) .. " got=" .. tostring(actual))
    end
end

local function assertTrue(v, msg)
    if not v then error(msg or "expected true") end
end

local function resetCombat()
    CombatSystem.floatingTexts = {}
    CombatSystem.skillEffects = {}
    CombatSystem.activeZones = {}
    CombatSystem.bloodRageStacks = {}
    CombatSystem._bloodRageTriggeredThisCast = nil
    GameState.monsters = {}
    GameState.player = nil
    math.random = function() return 0.5 end
end

local function makePlayer(classId, realm)
    local p = {
        x = 0,
        y = 0,
        classId = classId,
        realm = realm or "yuanying_1",
        alive = true,
        hp = 500,
        facingRight = true,
        equipSkillDmg = 0,
        equipKillHeal = 0,
        titleKillHeal = 0,
        collectionKillHeal = 0,
        pillKillHeal = 0,
        artifactTiandiKillHeal = 0,
        minggeKillHeal = 0,
    }
    function p:GetTotalAtk() return 100 end
    function p:GetTotalDef() return 400 end
    function p:GetTotalMaxHp() return 1000 end
    function p:GetSkillDmgPercent() return 0 end
    function p:GetSkillComboChance() return 0 end
    function p:GetPhysiqueBloodRageValue() return 0 end
    function p:ApplyCrit(damage) return damage, false, false end
    function p:AddPreDamageHook(id, fn)
        self._preDamageHooks = self._preDamageHooks or {}
        self._preDamageHooks[id] = fn
    end
    return p
end

local function makeMonster(x, y, hp)
    local m = {
        id = "mock_" .. tostring(x) .. "_" .. tostring(y),
        name = "mock",
        x = x,
        y = y,
        def = 0,
        hp = hp or 100000,
        alive = true,
        totalDamage = 0,
    }
    function m:TakeDamage(damage, source)
        self.lastDamage = damage
        self.totalDamage = self.totalDamage + damage
        self.hp = self.hp - damage
        if self.hp <= 0 then self.alive = false end
        return damage
    end
    function m:ApplyDebuff(id, data)
        self.lastDebuff = id
    end
    return m
end

local function setWorld(player, monsters)
    GameState.player = player
    GameState.monsters = monsters or {}
    player.target = monsters and monsters[1] or nil
end

print("\n[test_combat_yuanying_skills] === 元婴职业技能回归 ===\n")

test("yuanying_1 三职业配置存在且指向 1 技能", function()
    assertEqual(SkillData.GetRealmEnhancement("yuanying_1", "monk").enhancedSkill, "ice_slash", "monk enhancedSkill")
    assertEqual(SkillData.GetRealmEnhancement("yuanying_1", "taixu").enhancedSkill, "three_swords", "taixu enhancedSkill")
    assertEqual(SkillData.GetRealmEnhancement("yuanying_1", "zhenyue").enhancedSkill, "mountain_fist", "zhenyue enhancedSkill")
end)

test("大破剑式使用施法快照且不污染基础 SkillData", function()
    resetCombat()
    local player = makePlayer("taixu", "yuanying_1")
    math.random = function() return 0.10 end
    local runtime = SkillData.CreateRuntimeSkill(SkillData.Skills.three_swords, player)
    assertEqual(runtime._upgradeVariantTriggered, true, "upgrade triggered")
    assertEqual(runtime.swordCount, 5, "sword count")
    assertEqual(runtime.coneAngle, 90, "cone angle")
    assertEqual(runtime.damageMultiplier, 2.5, "damage multiplier")
    assertEqual(runtime.maxTargets, 5, "max targets")
    assertEqual(SkillData.Skills.three_swords.swordCount, nil, "base swordCount remains nil")
    assertEqual(SkillData.Skills.three_swords.coneAngle, 60, "base coneAngle unchanged")

    math.random = function() return 0.90 end
    runtime = SkillData.CreateRuntimeSkill(SkillData.Skills.three_swords, player)
    assertEqual(runtime._upgradeVariantTriggered, false, "upgrade not triggered")
    assertEqual(runtime.damageMultiplier, 1.5, "base multiplier when not triggered")
    assertEqual(runtime.maxTargets, 3, "base targets when not triggered")

    local lowRealm = makePlayer("taixu", "jindan_3")
    runtime = SkillData.CreateRuntimeSkill(SkillData.Skills.three_swords, lowRealm)
    assertEqual(runtime.damageMultiplier, 1.5, "low realm keeps base multiplier")
end)

test("罗汉金刚掌命中后只生成一枚可暴击防御系数金刚印", function()
    resetCombat()
    local player = makePlayer("monk", "yuanying_1")
    local monster = makeMonster(1.5, 0)
    setWorld(player, { monster })

    local ok = CastingA.CastDamageSkill(SkillData.Skills.ice_slash, player)
    assertEqual(ok, true, "cast ok")
    assertEqual(#CombatSystem.activeZones, 1, "one zone")
    local zone = CombatSystem.activeZones[1]
    assertNear(zone.x, 1.5, 0.001, "zone x")
    assertNear(zone.y, 0, 0.001, "zone y")
    assertEqual(zone.damageSource, "def", "damage source")
    assertEqual(zone.damageCoeff, 0.25, "damage coeff")
    assertEqual(zone.canCrit, true, "can crit")
    assertEqual(zone.isDot, true, "is dot")
    assertEqual(zone.zoneVisualKey, "monk_seal_zone", "visual key")

    player.ApplyCrit = function(self, damage) return damage * 2, true, false end
    monster.lastDamage = 0
    CombatSystem.UpdateZones(0.5)
    assertEqual(monster.lastDamage, 200, "zone tick crit damage")
end)

test("御剑诀消耗一柄灵剑时回复 8% 当前最大生命", function()
    resetCombat()
    local player = makePlayer("taixu", "yuanying_1")
    player.hp = 500
    Passives.SwordShieldPassive(SkillData.Skills.sword_shield, player, "sword_shield", 0.1)
    assertTrue(player._preDamageHooks and player._preDamageHooks.sword_shield, "hook installed")

    local finalDamage = player._preDamageHooks.sword_shield(player, 100, nil)
    assertEqual(player._swordShield.swords, 2, "sword consumed")
    assertEqual(finalDamage, 70, "30 percent blocked")
    assertEqual(player.hp, 580, "healed before remaining damage is applied")
end)

test("一剑开天触发回血只按总击杀回血结算一次", function()
    resetCombat()
    local player = makePlayer("taixu", "yuanying_1")
    player.hp = 500
    player.equipKillHeal = 3
    player.titleKillHeal = 2
    player.collectionKillHeal = 1
    player.pillKillHeal = 4
    player.artifactTiandiKillHeal = 5
    player.minggeKillHeal = 6
    local m1 = makeMonster(1.5, 0)
    local m2 = makeMonster(1.2, 0.2)
    setWorld(player, { m1, m2 })

    Passives.TriggerNthCastEffect(SkillData.Skills.sword_formation, player, {})
    assertEqual(player.hp, 668, "heal once: (3+2+1+4+5+6)*8")
    assertEqual(player._killHealMultiplier, nil, "old multiplier not used")
    assertTrue(m1.totalDamage > 0 and m2.totalDamage > 0, "both targets damaged")
end)

test("太虚触发回血在缺血为小数时浮字仍为整数", function()
    resetCombat()
    local player = makePlayer("taixu", "yuanying_1")
    player.hp = 990.25
    player.equipKillHeal = 3
    local monster = makeMonster(1.5, 0)
    setWorld(player, { monster })

    Passives.TriggerNthCastEffect(SkillData.Skills.sword_formation, player, {})
    assertNear(player.hp, 999.25, 0.001, "integer clamped heal")

    local foundHealText = false
    for _, ft in ipairs(CombatSystem.floatingTexts) do
        if ft.text == "+9" then
            foundHealText = true
        end
        if type(ft.text) == "string" and ft.text:match("^%+%d+%.") then
            error("heal floating text contains decimal: " .. ft.text)
        end
    end
    assertTrue(foundHealText, "integer heal floating text")
end)

test("镇岳裂山元婴强化仅在元婴后覆盖本次施法参数", function()
    resetCombat()
    local player = makePlayer("zhenyue", "yuanying_1")
    player.hp = 1000
    local monster = makeMonster(2.0, 0)
    setWorld(player, { monster })
    local ok = CastingB.CastHpDamageSkill(SkillData.Skills.mountain_fist, player)
    assertEqual(ok, true, "yuan cast ok")
    assertEqual(player.hp, 940, "yuan cost 6% maxHp")
    assertEqual(player._bloodAccumulator, 60, "yuan accumulator")
    assertEqual(monster.lastDamage, 120, "yuan damage 12% maxHp")
    assertEqual(CombatSystem.skillEffects[#CombatSystem.skillEffects].range, 2.0, "yuan effect range")
    assertEqual(CombatSystem.skillEffects[#CombatSystem.skillEffects].duration, 0.9, "yuan effect duration")
    assertEqual(SkillData.Skills.mountain_fist.range, 1.5, "base range unchanged")

    resetCombat()
    local lowRealm = makePlayer("zhenyue", "jindan_3")
    lowRealm.hp = 1000
    local lowMonster = makeMonster(1.5, 0)
    setWorld(lowRealm, { lowMonster })
    ok = CastingB.CastHpDamageSkill(SkillData.Skills.mountain_fist, lowRealm)
    assertEqual(ok, true, "low realm cast ok")
    assertEqual(lowRealm.hp, 950, "low realm cost 5% maxHp")
    assertEqual(lowRealm._bloodAccumulator, 50, "low realm accumulator")
    assertEqual(lowMonster.lastDamage, 100, "low realm damage 10% maxHp")
end)

math.random = savedRandom
GameState.player = savedPlayer
GameState.monsters = savedMonsters

return {
    passed = passed,
    failed = failed,
    total = total,
}
