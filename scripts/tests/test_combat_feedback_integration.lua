-- ============================================================================
-- test_combat_feedback_integration.lua - 新旧跳字桥接互斥测试
-- ============================================================================

package.path = package.path .. ";scripts/?.lua"

local FeatureFlags = require("config.FeatureFlags")
local Feedback = require("systems.combat.CombatFeedback")
local InstallBridge = require("systems.combat.CombatFeedbackBridge")
local InstallFeedbackEvents = require("systems.combat.CombatFeedbackEvents")
local InstallBossMechanics = require("systems.combat.BossMechanics")
local LifestealBurst = require("systems.combat.LifestealBurst")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Player = require("entities.Player")
local Pet = require("entities.Pet")
local ArtifactCh5 = require("systems.ArtifactSystem_ch5")
local CombatFeedbackDebug = require("ui.CombatFeedbackDebug")
local CastingA = require("systems.skill.casting_a")
local CastingB = require("systems.skill.casting_b")

local passed, failed, total = 0, 0, 0

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

local function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "eq") .. " expected=" .. tostring(expected) .. " got=" .. tostring(actual))
    end
end

local function makeCombatSystem()
    local system = { floatingTexts = {} }
    function system.AddFloatingText(x, y, text, color, lifetime, baseScale)
        system.floatingTexts[#system.floatingTexts + 1] = {
            x = x, y = y, text = text, color = color,
            lifetime = lifetime, baseScale = baseScale,
        }
    end
    InstallBridge(system)
    return system
end

local function reset()
    FeatureFlags._resetForTest()
    Feedback.ResetForTest()
end

print("\n[test_combat_feedback_integration] === 跳字桥接 ===\n")

test("开关关闭只写旧队列", function()
    reset()
    local system = makeCombatSystem()
    local monster = { id = "legacy", x = 2, y = 3 }
    system.EmitDamageFeedback({}, monster, 123, {
        sourceType = "basic",
    }, {
        x = 2, y = 3, text = "123", color = {255, 255, 100, 255},
    })
    eq(#system.floatingTexts, 1)
    eq(system.floatingTexts[1].text, "123")
    eq(#Feedback.GetItems(), 0)
end)

test("开关开启只写新队列", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local system = makeCombatSystem()
    local monster = { id = "new", x = 2, y = 3 }
    system.EmitDamageFeedback({}, monster, 456, {
        sourceType = "skill",
        sourceId = "zhuxian",
        sourceName = "诛仙剑气",
        criticality = "crit",
        castId = system.NextCombatCastId("skill"),
    }, {
        x = 2, y = 3, text = "旧暴击 456", color = {255, 220, 50, 255},
    })
    eq(#system.floatingTexts, 0)
    eq(#Feedback.GetItems(), 1)
    eq(Feedback.GetItems()[1].text, "456")
    eq(Feedback.GetItems()[1].label, "诛仙剑气")
    eq(Feedback.GetItems()[1].tag, "暴击")
end)

test("多人副本来源或目标始终保留旧表现且不进入 V2", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local system = makeCombatSystem()
    local DungeonRenderer = require("rendering.DungeonRenderer")
    local dungeonBoss = {
        id = "dungeon_boss", x = 2, y = 3, isDungeonBoss = true,
    }
    local ok, mode = system.EmitDamageFeedback({}, dungeonBoss, 321, {
        sourceType = "basic", sourceId = "player_attack",
    }, {
        x = 2, y = 3, text = "321", color = {255, 255, 100, 255},
    })
    eq(ok, true)
    eq(mode, "dungeon_legacy")
    eq(#system.floatingTexts, 1)
    eq(#Feedback.GetItems(), 0)

    system.EmitCombatFeedback({
        kind = "hurt", value = 50,
        source = dungeonBoss,
        target = { id = "player", x = 0, y = 0 },
    }, {
        x = 0, y = 0, text = "-50", color = {255, 80, 80, 255},
    })
    eq(#system.floatingTexts, 2)
    eq(#Feedback.GetItems(), 0)

    DungeonRenderer.EnterDungeon()
    system.EmitCombatFeedback({
        kind = "heal", value = 25,
        source = { id = "player" },
        target = { id = "player", x = 0, y = 0 },
        targetKey = "player:self",
    }, {
        x = 0, y = 0, text = "+25", color = {100, 255, 100, 255},
    })
    local _, labelMode = system.EmitLegacyOnlyFeedback({
        x = 0, y = -1, text = "副本技能名",
    })
    eq(labelMode, "dungeon_legacy")
    eq(#system.floatingTexts, 4)
    eq(#Feedback.GetItems(), 0)
    DungeonRenderer.LeaveDungeon()
end)

test("旧回退列表可以恢复多条旧表现", function()
    reset()
    local system = makeCombatSystem()
    system.EmitCombatFeedback({
        kind = "damage", value = 100,
        target = { id = "list", x = 0, y = 0 },
    }, {
        { x = 0, y = 0, text = "100" },
        { x = 0, y = -1, text = "旧技能名" },
    })
    eq(#system.floatingTexts, 2)
    eq(system.floatingTexts[2].text, "旧技能名")
    eq(#Feedback.GetItems(), 0)
end)

test("legacy-only 在 V2 下被抑制", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local system = makeCombatSystem()
    local ok, mode = system.EmitLegacyOnlyFeedback({
        x = 0, y = 0, text = "旧技能名",
    })
    eq(ok, true)
    eq(mode, "suppressed")
    eq(#system.floatingTexts, 0)
    eq(#Feedback.GetItems(), 0)
end)

test("桥接生命周期可清理新队列", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local system = makeCombatSystem()
    system.EmitCombatFeedback({
        kind = "status", text = "免疫",
        target = { id = "clear", x = 0, y = 0 },
    })
    eq(#system.GetCombatFeedbackItems(), 1)
    system.UpdateCombatFeedback(2)
    eq(#system.GetCombatFeedbackItems(), 0)
    system.ResetCombatFeedback()
end)

test("真实 AutoAttack 暴击在新旧模式都只产生一条数字", function()
    reset()
    local savedRandom = math.random
    math.random = function() return 0.5 end
    local CombatSystem = require("systems.CombatSystem")
    local savedPlayer = GameState.player
    local savedMonsters = GameState.monsters

    local monster = {
        id = "auto_attack_target",
        name = "测试目标",
        x = 1, y = 0, def = 0,
        hp = 10000, maxHp = 10000, alive = true,
    }
    function monster:TakeDamage(damage)
        self.hp = self.hp - damage
        return damage
    end

    local player = {
        x = 0, y = 0, alive = true, attackTimer = 1,
        facingRight = true, equipSpecialEffects = nil,
    }
    function player:GetAttackInterval() return 1 end
    function player:GetTotalAtk() return 100 end
    function player:GetTotalDef() return 0 end
    function player:GetTotalHeavyHit() return 0 end
    function player:GetClassHeavyHitChance() return 0 end
    function player:GetConstitutionHeavyHitChance() return 0 end
    function player:GetConstitutionHeavyDmgBonus() return 0 end
    function player:GetPhysiqueBloodRageChance() return 0 end
    function player:ApplyCrit(damage) return damage * 2, true, false end

    GameState.player = player
    GameState.monsters = { monster }
    CombatSystem.Init()
    CombatSystem.AutoAttack(0)
    eq(#CombatSystem.floatingTexts, 1, "legacy one floating text")
    local legacyDamage = tonumber(CombatSystem.floatingTexts[1].text:match("^暴击 (%d+)$"))
    if not legacyDamage or legacyDamage <= 0 then
        error("legacy crit text does not contain actual damage")
    end
    eq(#Feedback.GetItems(), 0, "legacy no v2 item")

    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    CombatSystem.floatingTexts = {}
    Feedback.ResetForTest()
    monster.hp = monster.maxHp
    monster.alive = true
    player.attackTimer = 1
    CombatSystem.AutoAttack(0)
    eq(#CombatSystem.floatingTexts, 0, "v2 no legacy text")
    eq(#Feedback.GetItems(), 1, "v2 one feedback item")
    eq(Feedback.GetItems()[1].criticality, "crit", "v2 crit semantic")
    eq(Feedback.GetItems()[1].value, legacyDamage, "v2 uses same actual damage")

    GameState.player = savedPlayer
    GameState.monsters = savedMonsters
    math.random = savedRandom
end)

test("噬魂爆发保留技能名并显示实际恢复值", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local system = makeCombatSystem()
    function system.AddSkillEffect() end

    local savedPlayer = GameState.player
    local savedMonsters = GameState.monsters
    local player = {
        x = 0, y = 0, hp = 900, alive = true, facingRight = true,
    }
    function player:GetTotalMaxHp() return 1000 end
    function player:GetTotalAtk() return 100 end

    local monster = {
        id = "lifesteal_target",
        name = "噬魂目标",
        x = 1, y = 0, def = 0, alive = true,
    }
    function monster:TakeDamage(_damage)
        return 75
    end

    GameState.player = player
    GameState.monsters = { monster }
    local handler = LifestealBurst.CreateHandler(system)
    handler.onKill({
        type = "lifesteal_burst",
        name = "噬魂",
        healPercent = 0.03,
        maxStacks = 1,
        damagePercent = 1.0,
        rectLength = 2.0,
        rectWidth = 1.0,
        range = 2.5,
        maxTargets = 1,
    }, player, monster)

    eq(#system.floatingTexts, 0, "v2 suppresses all legacy lifesteal texts")
    local items = Feedback.GetItems()
    eq(#items, 3, "kill heal, burst damage and burst heal")
    eq(items[1].kind, "heal")
    eq(items[1].value, 30, "kill heal actual value")
    eq(items[2].kind, "damage")
    eq(items[2].value, 75, "burst uses applied damage")
    eq(items[2].label, "噬魂", "burst keeps equipment skill name")
    eq(items[3].kind, "heal")
    eq(items[3].value, 70, "burst heal is capped actual recovery")
    eq(player.hp, 1000, "healing respects max hp")

    GameState.player = savedPlayer
    GameState.monsters = savedMonsters
end)

test("宠物伤害与吸血使用目标实际结算值", function()
    reset()
    local pet = {
        ignoreDefPct = 0,
        critRate = 0,
        critDmgPct = 0,
        bonusDmgPct = 0,
        lifeStealPct = 50,
        alive = true,
        hp = 40,
        maxHp = 100,
    }
    local monster = { def = 0 }
    function monster:TakeDamage(_damage)
        return 30
    end

    local result = Pet.CalcPetDamage(pet, 100, monster, "normal")
    eq(result.damage, 30, "pet feedback value uses actual damage")
    eq(pet.hp, 55, "pet lifesteal uses actual damage")
end)

test("宠物破防在 V2 中保留破防标签", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    EventBus.Clear()
    local system = makeCombatSystem()
    function system.AddPetSlashEffect() end
    InstallFeedbackEvents(system)
    system.InitCombatFeedbackEvents()

    EventBus.Emit("pet_attack",
        { id = "pet", x = 0, y = 0 },
        { id = "pet_target", x = 1, y = 0 },
        88, false, false, true)

    local items = Feedback.GetItems()
    eq(#items, 1)
    eq(items[1].value, 88)
    eq(items[1].label, "破防")
    EventBus.Clear()
end)

test("治疗技能只显示实际恢复值", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local savedPet = GameState.pet
    local savedMonsters = GameState.monsters
    local player = {
        id = "heal_player", x = 0, y = 0, hp = 95, alive = true,
        facingRight = true,
    }
    function player:GetTotalMaxHp() return 100 end
    function player:GetSkillDmgPercent() return 0 end
    local pet = {
        id = "heal_pet", x = 1, y = 0, hp = 99, maxHp = 100, alive = true,
    }
    GameState.pet = pet
    GameState.monsters = {}

    CastingA.CastHealSkill({
        id = "heal_skill", name = "回春术",
        healPercent = 0.5, petHealPercent = 0.5,
        effectColor = {80, 255, 120, 255},
    }, player)
    local items = Feedback.GetItems()
    eq(#items, 2)
    eq(items[1].value, 5, "player capped actual heal")
    eq(items[2].value, 1, "pet capped actual heal")

    Feedback.ResetForTest()
    player.hp = 90
    CastingB.CastHpHealDamageSkill({
        id = "hp_heal_damage", name = "生息震波", icon = "",
        healPercent = 0.5, hpCoefficient = 0.1,
        range = 1.5, maxTargets = 1,
        effectColor = {80, 255, 120, 255},
    }, player)
    items = Feedback.GetItems()
    eq(#items, 1)
    eq(items[1].value, 10, "heal-damage skill capped actual heal")

    GameState.pet = savedPet
    GameState.monsters = savedMonsters
end)

test("持续治疗与治愈泉只显示实际恢复值", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local CombatSystem = require("systems.CombatSystem")
    local savedPlayer = GameState.player
    local player = {
        id = "periodic_heal_player", x = 0, y = 0, hp = 98, alive = true,
    }
    function player:GetTotalMaxHp() return 100 end
    GameState.player = player

    CombatSystem.activeBuffs = {
        capped_regen = {
            remaining = 2, healPercent = 0.5,
            tickTimer = 0, tickInterval = 1,
            name = "持续回复", color = {80, 255, 120, 255},
        },
    }
    CombatSystem.UpdateBuffs(1)
    local items = Feedback.GetItems()
    eq(#items, 1)
    eq(items[1].value, 2, "buff capped actual heal")

    Feedback.ResetForTest()
    player.hp = 99
    CombatSystem.UpdateHealingSpring(0, player, {
        IsNearHealingSpring = function() return false end,
    })
    CombatSystem.UpdateHealingSpring(1, player, {
        IsNearHealingSpring = function() return true end,
    })
    items = Feedback.GetItems()
    eq(#items, 1)
    eq(items[1].value, 1, "spring capped actual heal")

    GameState.player = savedPlayer
end)

test("Boss 机制监听在 EventBus.Clear 后恢复且重复初始化不叠加", function()
    reset()
    EventBus.Clear()
    local system = {}
    InstallBossMechanics(system)
    local savedPlayer = GameState.player
    local player = {
        alive = true, hp = 100, x = 0, y = 0,
        sealMarkStacks = 2, sealMarkTickTimer = 1,
    }
    function player:TakeDamage(damage)
        self.hp = self.hp - damage
        return damage
    end
    GameState.player = player

    system.InitBossMechanicsListeners()
    EventBus.Emit("jade_shield_reflect", 10, 0, 0)
    eq(player.hp, 90, "jade reflect listener restored")

    local sealBoss = { sealMark = { clearPerHit = 1 } }
    EventBus.Emit("monster_hurt", sealBoss, 1)
    eq(player.sealMarkStacks, 1, "seal mark decremented once")

    system.InitBossMechanicsListeners()
    EventBus.Emit("monster_hurt", sealBoss, 1)
    eq(player.sealMarkStacks, 0, "re-init does not duplicate listener")

    GameState.player = savedPlayer
    EventBus.Clear()
end)

test("玩家特殊受伤只生成一条并保留来源语义", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    EventBus.Clear()

    local CombatSystem = require("systems.CombatSystem")
    local savedPlayer = GameState.player
    local player = Player.New(0, 0)
    player.hp = 1000
    player.maxHp = 1000
    GameState.player = player

    CombatSystem.Init()
    local actualDamage = player:TakeDamage(120, { name = "测试Boss" }, {
        sourceType = "boss",
        sourceId = "meteor",
        sourceName = "陨星",
        damageTag = "skill",
        impact = "heavy",
        legacyPrefix = "陨星 ",
    })

    eq(actualDamage, 120, "player damage result")
    eq(#Feedback.GetItems(), 1, "one structured hurt item")
    eq(Feedback.GetItems()[1].kind, "hurt", "hurt kind")
    eq(Feedback.GetItems()[1].value, 120, "hurt uses actual damage")
    eq(Feedback.GetItems()[1].label, "陨星", "hurt keeps boss skill name")
    eq(#CombatSystem.floatingTexts, 0, "v2 does not double write legacy text")

    GameState.player = savedPlayer
    EventBus.Clear()
end)

test("第五章神器逐目标上报实际伤害", function()
    reset()
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local system = makeCombatSystem()
    function system.AddZhentuSwordEffect() end

    local savedCombatSystem = package.loaded["systems.CombatSystem"]
    local savedMonsters = GameState.monsters
    package.loaded["systems.CombatSystem"] = system

    local monster = { id = "zhentu_target", x = 0, y = 0, alive = true }
    function monster:TakeDamage(damage)
        return damage - 7
    end
    local player = {}
    function player:GetTotalAtk() return 100 end
    function player:ApplyCrit(damage) return damage, false, false end

    GameState.monsters = { monster }
    ArtifactCh5._FireZhentuSwords(player, 0, 0)
    ArtifactCh5.UpdatePassiveCooldown(1.0)

    local items = Feedback.GetItems()
    eq(#items, 4, "four sword hits")
    eq(items[1].value, 93, "first sword actual damage")
    eq(items[2].value, 143, "second sword actual damage")
    eq(items[3].value, 193, "third sword actual damage")
    eq(items[4].value, 243, "fourth sword actual damage")
    for i = 1, #items do
        eq(items[i].sourceType, "artifact", "artifact source type")
    end

    package.loaded["systems.CombatSystem"] = savedCombatSystem
    GameState.monsters = savedMonsters
end)

test("GM 视觉矩阵结束后恢复原功能开关覆盖", function()
    reset()
    local system = makeCombatSystem()
    local player = { x = 0, y = 0 }

    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", false)
    CombatFeedbackDebug.SpawnMatrix(system, player)
    eq(FeatureFlags.getOverride("COMBAT_FEEDBACK_V2"), false, "explicit false restored")
    if #Feedback.GetItems() == 0 then
        error("debug matrix did not emit forced v2 items")
    end

    FeatureFlags.clearOverride("COMBAT_FEEDBACK_V2")
    Feedback.ResetForTest()
    CombatFeedbackDebug.SpawnMatrix(system, player)
    eq(FeatureFlags.getOverride("COMBAT_FEEDBACK_V2"), nil, "nil override restored")

    local brokenSystem = makeCombatSystem()
    function brokenSystem.ResetCombatFeedback()
        error("debug failure")
    end
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", false)
    local ok = pcall(CombatFeedbackDebug.SpawnMatrix, brokenSystem, player)
    eq(ok, false, "debug error is propagated")
    eq(FeatureFlags.getOverride("COMBAT_FEEDBACK_V2"), false, "override restored after error")
end)

test("main-world legacy heal text is rounded", function()
    reset()
    local system = makeCombatSystem()
    local player = { id = "heal_legacy", x = 2, y = 3 }
    system.EmitCombatFeedback({
        kind = "heal", value = 4.876543211,
        source = player, target = player, targetKey = "player:self",
        sourceType = "skill", sourceName = "Soul",
    }, {
        x = 2, y = 3, text = "Soul +4.876543211",
        color = {100, 255, 100, 255},
    })
    eq(#system.floatingTexts, 1)
    eq(system.floatingTexts[1].text, "Soul +5")
    eq(#Feedback.GetItems(), 0)
end)

test("dungeon legacy heal text remains unchanged", function()
    reset()
    local system = makeCombatSystem()
    local dungeonBoss = {
        id = "dungeon_heal", x = 2, y = 3, isDungeonBoss = true,
    }
    system.EmitCombatFeedback({
        kind = "heal", value = 4.876543211,
        source = dungeonBoss, target = dungeonBoss,
    }, {
        x = 2, y = 3, text = "+4.876543211",
        color = {100, 255, 100, 255},
    })
    eq(#system.floatingTexts, 1)
    eq(system.floatingTexts[1].text, "+4.876543211")
    eq(#Feedback.GetItems(), 0)
end)

reset()

return {
    passed = passed,
    failed = failed,
    total = total,
}
