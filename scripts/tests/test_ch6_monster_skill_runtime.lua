-- ============================================================================
-- test_ch6_monster_skill_runtime.lua
-- GM command: Chapter 6 monster skill runtime self-test
--
-- This test intentionally uses the real Monster + EventBus + GameEvents path.
-- It verifies that configured Ch6 skills can create warnings, hit a live target,
-- apply damage/effects, and that phase-triggered skills/addSkills take effect.
-- ============================================================================

local M = {}

local MonsterData = require("config.MonsterData")
local Monster = require("entities.Monster")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CombatSystem = require("systems.CombatSystem")

local CH6_TYPE_IDS = {
    "ch6_patrol_immortal_soldier",
    "ch6_lingfeng",
    "ch6_shadow_wanderer",
    "ch6_zhuyou",
    "ch6_mountain_colossus",
    "ch6_duanyue",
    "ch6_west_celestial_soldier",
    "ch6_pojun",
    "ch6_zhenyuan",
    "ch6_heng_marshal",
    "ch6_east_celestial_soldier",
    "ch6_qingfeng",
    "ch6_leice",
    "ch6_ha_marshal",
    "ch6_toad_immortal",
    "ch6_gua_master",
    "ch6_mojun_shixuan",
}

local VALID_SHAPES = {
    circle = true,
    cone = true,
    cross = true,
    line = true,
    rect = true,
}

local function Near(a, b, eps)
    return math.abs((a or 0) - (b or 0)) <= (eps or 0.001)
end

local function HasSkill(monster, skillId)
    for _, skill in ipairs(monster.skills or {}) do
        if skill and skill.id == skillId then
            return true
        end
    end
    return false
end

local function NewDummy(name)
    local dummy = {
        name = name or "TestDummy",
        x = 0,
        y = 0,
        hp = 1000000,
        maxHp = 1000000,
        def = 0,
        alive = true,
        facingRight = true,
        totalDamage = 0,
        lastDamage = 0,
        poisonCount = 0,
        knockbackCount = 0,
        stunCount = 0,
        slowCount = 0,
    }

    function dummy:Reset()
        self.hp = self.maxHp
        self.alive = true
        self.totalDamage = 0
        self.lastDamage = 0
        self.poisonCount = 0
        self.knockbackCount = 0
        self.stunCount = 0
        self.slowCount = 0
        self.lastPoisonDps = nil
        self.lastKnockbackDistance = nil
        self.lastStunDuration = nil
        self.lastSlowMovePercent = nil
    end

    function dummy:GetTotalMaxHp()
        return self.maxHp
    end

    function dummy:GetTotalDef()
        return self.def or 0
    end

    function dummy:TakeDamage(damage, source)
        damage = math.max(0, math.floor(damage or 0))
        self.lastDamage = damage
        self.totalDamage = self.totalDamage + damage
        self.hp = self.hp - damage
        if self.hp <= 0 then
            self.alive = false
        end
    end

    function dummy:ApplyPoison(duration, damagePerSec, source)
        self.poisonCount = self.poisonCount + 1
        self.lastPoisonDuration = duration
        self.lastPoisonDps = damagePerSec
    end

    function dummy:ApplyKnockback(fromX, fromY, distance, gameMap)
        self.knockbackCount = self.knockbackCount + 1
        self.lastKnockbackDistance = distance
    end

    function dummy:ApplyStun(duration)
        self.stunCount = self.stunCount + 1
        self.lastStunDuration = duration
    end

    function dummy:ApplySlow(duration, movePercent, atkPercent)
        self.slowCount = self.slowCount + 1
        self.lastSlowDuration = duration
        self.lastSlowMovePercent = movePercent
        self.lastSlowAtkPercent = atkPercent
    end

    return dummy
end

local function NewMonster(typeId)
    local data = MonsterData.Types[typeId]
    local monster = Monster.New(data, 10, 10)
    monster.typeId = typeId
    monster.x = 10
    monster.y = 10
    monster.spawnX = 10
    monster.spawnY = 10
    monster.atk = math.max(monster.atk or 0, 10000)
    monster.baseAtk = monster.atk
    monster.alive = true
    monster.state = "combat"
    monster.castTargetX = monster.x + 1
    monster.castTargetY = monster.y
    return monster
end

local function CollectSkillRefs(data)
    local refs = {}
    for _, skillId in ipairs(data.skills or {}) do
        table.insert(refs, { id = skillId, source = "base" })
    end
    for phaseIndex, phase in ipairs(data.phaseConfig or {}) do
        if phase.addSkill then
            table.insert(refs, { id = phase.addSkill, source = "phase" .. phaseIndex .. ".addSkill" })
        end
        if phase.addSkills then
            for _, skillId in ipairs(phase.addSkills) do
                table.insert(refs, { id = skillId, source = "phase" .. phaseIndex .. ".addSkills" })
            end
        end
        if phase.triggerSkill then
            table.insert(refs, { id = phase.triggerSkill, source = "phase" .. phaseIndex .. ".triggerSkill" })
        end
    end
    return refs
end

local function PlaceTargetForSkill(monster, target, skill)
    monster.x = 10
    monster.y = 10
    monster.castTargetX = monster.x + 1
    monster.castTargetY = monster.y

    local shape = skill.warningShape or "circle"
    if shape == "circle" then
        local range = math.max(0.2, (skill.warningRange or 2.0) * 0.45)
        target.x = monster.x + math.min(range, 1.0)
        target.y = monster.y
    elseif shape == "cone" then
        target.x = monster.x + math.min((skill.warningRange or 2.0) * 0.45, 1.2)
        target.y = monster.y
    elseif shape == "cross" then
        target.x = monster.x + math.min((skill.warningRange or 3.0) * 0.45, 1.5)
        target.y = monster.y
    elseif shape == "line" then
        target.x = monster.x + math.min((skill.warningRange or 3.5) * 0.45, 1.5)
        target.y = monster.y
    elseif shape == "rect" then
        target.x = monster.x + math.min((skill.warningRectLength or 2.5) * 0.45, 1.2)
        target.y = monster.y
    else
        target.x = monster.x + 0.5
        target.y = monster.y
    end
end

local function SetFieldHitPosition(monster, target)
    monster.x = 10
    monster.y = 10
    target.x = 10.5
    target.y = 10.5
end

local function SetFieldSafePosition(monster, target)
    local zone = monster.fieldSafeZones and monster.fieldSafeZones[1]
    if not zone then
        zone = { x = 2.5, y = 2.5 }
        monster.fieldSafeZones = { zone }
    end
    target.x = zone.x
    target.y = zone.y
end

function M.RunAll()
    local passed = 0
    local failed = 0
    local total = 0
    local log = {}
    local runtimeErrors = {}

    local originalPlayer = GameState.player
    local originalPet = GameState.pet
    local originalFloatingTexts = CombatSystem.floatingTexts
    local originalMonsterWarnings = CombatSystem.monsterWarnings
    local originalPrint = _G.print

    local player = NewDummy("CH6SkillTestPlayer")

    local function AddLog(line)
        table.insert(log, line)
    end

    local function Assert(name, condition, detail)
        total = total + 1
        if condition then
            passed = passed + 1
            AddLog("[PASS] " .. name)
        else
            failed = failed + 1
            AddLog("[FAIL] " .. name .. (detail and (" | " .. detail) or ""))
        end
    end

    local function EmitAndCheckNoEventError(eventName, ...)
        local before = #runtimeErrors
        EventBus.Emit(eventName, ...)
        return #runtimeErrors == before
    end

    local function CheckWarning(typeId, skill)
        local monster = NewMonster(typeId)
        monster.target = player
        if skill.isFieldSkill then
            monster.fieldSafeZones = {
                { x = 2.5, y = 2.5 },
                { x = 3.5, y = 3.5 },
            }
        end
        PlaceTargetForSkill(monster, player, skill)

        local before = #CombatSystem.monsterWarnings
        local ok = EmitAndCheckNoEventError("monster_skill_cast_start", monster, skill)
        local warning = CombatSystem.monsterWarnings[#CombatSystem.monsterWarnings]

        Assert(typeId .. "/" .. skill.id .. " warning no error", ok)
        Assert(typeId .. "/" .. skill.id .. " warning created",
            #CombatSystem.monsterWarnings > before,
            "before=" .. before .. " after=" .. #CombatSystem.monsterWarnings)

        if warning then
            local expectedShape = skill.warningShape or "circle"
            Assert(typeId .. "/" .. skill.id .. " warning shape",
                warning.shape == expectedShape,
                "expected=" .. expectedShape .. " actual=" .. tostring(warning.shape))
            Assert(typeId .. "/" .. skill.id .. " warning range",
                Near(warning.range, skill.warningRange or 2.0),
                "expected=" .. tostring(skill.warningRange or 2.0) .. " actual=" .. tostring(warning.range))
            if skill.isFieldSkill then
                Assert(typeId .. "/" .. skill.id .. " warning safe zones",
                    warning.isFieldSkill == true and warning.safeZones ~= nil,
                    "field warning missing safe zones")
            end
        end
    end

    local function CheckEffect(typeId, skill, before)
        local prefix = typeId .. "/" .. skill.id
        if skill.effect == "poison" or skill.effect == "burn" then
            Assert(prefix .. " dot effect applied",
                player.poisonCount > before.poisonCount,
                "poisonCount=" .. player.poisonCount .. " before=" .. before.poisonCount)
        elseif skill.effect == "knockback" then
            Assert(prefix .. " knockback applied",
                player.knockbackCount > before.knockbackCount,
                "knockbackCount=" .. player.knockbackCount .. " before=" .. before.knockbackCount)
        elseif skill.effect == "stun" then
            Assert(prefix .. " stun applied",
                player.stunCount > before.stunCount,
                "stunCount=" .. player.stunCount .. " before=" .. before.stunCount)
        elseif skill.effect == "slow" then
            Assert(prefix .. " slow applied",
                player.slowCount > before.slowCount,
                "slowCount=" .. player.slowCount .. " before=" .. before.slowCount)
        end
    end

    local function CheckSkillHit(typeId, skill)
        local monster = NewMonster(typeId)
        monster.target = player
        player:Reset()

        if skill.isFieldSkill then
            monster.fieldSafeZones = {
                { x = 2.5, y = 2.5 },
                { x = 3.5, y = 3.5 },
                { x = 4.5, y = 4.5 },
            }
            SetFieldHitPosition(monster, player)
        else
            PlaceTargetForSkill(monster, player, skill)
        end

        local before = {
            damage = player.totalDamage,
            poisonCount = player.poisonCount,
            knockbackCount = player.knockbackCount,
            stunCount = player.stunCount,
            slowCount = player.slowCount,
        }

        local ok = EmitAndCheckNoEventError("monster_skill", monster, skill)
        local prefix = typeId .. "/" .. skill.id
        Assert(prefix .. " skill no error", ok)
        Assert(prefix .. " damage/effect landed",
            player.totalDamage > before.damage,
            "damageBefore=" .. before.damage .. " damageAfter=" .. player.totalDamage)
        CheckEffect(typeId, skill, before)

        if skill.isFieldSkill then
            player:Reset()
            monster.fieldSafeZones = {
                { x = 2.5, y = 2.5 },
                { x = 3.5, y = 3.5 },
            }
            SetFieldSafePosition(monster, player)
            local safeBefore = player.totalDamage
            ok = EmitAndCheckNoEventError("monster_skill", monster, skill)
            Assert(prefix .. " safe-zone no error", ok)
            Assert(prefix .. " safe-zone avoids damage",
                player.totalDamage == safeBefore,
                "damageBefore=" .. safeBefore .. " damageAfter=" .. player.totalDamage)
        end
    end

    local function CheckPhase(typeId, data)
        if not data.phaseConfig or #data.phaseConfig == 0 then
            return
        end

        local monster = NewMonster(typeId)
        monster.target = player

        for phaseIndex, phase in ipairs(data.phaseConfig) do
            player:Reset()
            monster.hp = math.max(1, math.floor(monster.maxHp * ((phase.threshold or 0) - 0.01)))
            local beforeWarnings = #CombatSystem.monsterWarnings
            local ok = pcall(function()
                monster:CheckPhaseTransition()
            end)

            Assert(typeId .. " phase" .. phaseIndex .. " transition no Lua error", ok)
            Assert(typeId .. " phase" .. phaseIndex .. " currentPhase",
                monster.currentPhase >= phaseIndex + 1,
                "currentPhase=" .. tostring(monster.currentPhase))

            if phase.addSkill then
                Assert(typeId .. " phase" .. phaseIndex .. " addSkill " .. phase.addSkill,
                    HasSkill(monster, phase.addSkill))
            end
            if phase.addSkills then
                for _, skillId in ipairs(phase.addSkills) do
                    Assert(typeId .. " phase" .. phaseIndex .. " addSkills " .. skillId,
                        HasSkill(monster, skillId))
                end
            end
            if phase.state then
                Assert(typeId .. " phase" .. phaseIndex .. " state",
                    monster.phaseState == phase.state,
                    "expected=" .. phase.state .. " actual=" .. tostring(monster.phaseState))
            end
            if phase.berserkBuff then
                Assert(typeId .. " phase" .. phaseIndex .. " berserk flag",
                    monster.hasBerserkBuff == true)
                Assert(typeId .. " phase" .. phaseIndex .. " berserk CDR",
                    Near(monster.skillCooldownMult, phase.berserkBuff.cdrMult or 1.0),
                    "expected=" .. tostring(phase.berserkBuff.cdrMult) .. " actual=" .. tostring(monster.skillCooldownMult))
            end
            if phase.triggerSkill then
                Assert(typeId .. " phase" .. phaseIndex .. " trigger cast",
                    monster.casting == true and monster.castingSkill and monster.castingSkill.id == phase.triggerSkill,
                    "castingSkill=" .. (monster.castingSkill and monster.castingSkill.id or "nil"))
                Assert(typeId .. " phase" .. phaseIndex .. " trigger warning",
                    #CombatSystem.monsterWarnings > beforeWarnings,
                    "before=" .. beforeWarnings .. " after=" .. #CombatSystem.monsterWarnings)

                local triggerDef = MonsterData.Skills[phase.triggerSkill]
                if triggerDef and triggerDef.isFieldSkill then
                    Assert(typeId .. " phase" .. phaseIndex .. " field safe-zone count",
                        monster.fieldSafeZones ~= nil and #monster.fieldSafeZones == (triggerDef.safeZoneCount or 4),
                        "expected=" .. tostring(triggerDef.safeZoneCount or 4)
                            .. " actual=" .. tostring(monster.fieldSafeZones and #monster.fieldSafeZones or 0))
                    SetFieldHitPosition(monster, player)
                    local beforeDamage = player.totalDamage
                    local emitted = EmitAndCheckNoEventError("monster_skill", monster, triggerDef)
                    Assert(typeId .. " phase" .. phaseIndex .. " trigger field no error", emitted)
                    Assert(typeId .. " phase" .. phaseIndex .. " trigger field damage",
                        player.totalDamage > beforeDamage,
                        "damageBefore=" .. beforeDamage .. " damageAfter=" .. player.totalDamage)
                end
            end
        end
    end

    local function CheckMonster(typeId)
        local data = MonsterData.Types[typeId]
        Assert(typeId .. " type exists", data ~= nil)
        if not data then return end

        local created, monsterOrErr = pcall(NewMonster, typeId)
        Assert(typeId .. " Monster.New no error", created, tostring(monsterOrErr))
        if created then
            local monster = monsterOrErr
            Assert(typeId .. " runtime skill count",
                #(monster.skills or {}) == #(data.skills or {}),
                "expected=" .. #(data.skills or {}) .. " actual=" .. #(monster.skills or {}))
        end

        for _, ref in ipairs(CollectSkillRefs(data)) do
            local skill = MonsterData.Skills[ref.id]
            Assert(typeId .. "/" .. ref.id .. " exists (" .. ref.source .. ")", skill ~= nil)
            if skill then
                Assert(typeId .. "/" .. ref.id .. " supported warning shape",
                    VALID_SHAPES[skill.warningShape or "circle"] == true,
                    "shape=" .. tostring(skill.warningShape))
                CheckWarning(typeId, skill)
                CheckSkillHit(typeId, skill)
            end
        end

        CheckPhase(typeId, data)
    end

    GameState.player = player
    GameState.pet = nil
    CombatSystem.floatingTexts = {}
    CombatSystem.monsterWarnings = {}
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring(select(i, ...))
        end
        local line = table.concat(parts, " ")
        if line:find("[EventBus] ERROR", 1, true) then
            table.insert(runtimeErrors, line)
            AddLog("[EVENTBUS-ERROR] " .. line)
        end
        originalPrint(...)
    end

    local ok, err = pcall(function()
        for _, typeId in ipairs(CH6_TYPE_IDS) do
            CheckMonster(typeId)
        end
    end)

    if not ok then
        failed = failed + 1
        total = total + 1
        AddLog("[FATAL] " .. tostring(err))
    end

    for _, errLine in ipairs(runtimeErrors) do
        failed = failed + 1
        total = total + 1
        AddLog("[FAIL] EventBus runtime error captured | " .. errLine)
    end

    _G.print = originalPrint
    GameState.player = originalPlayer
    GameState.pet = originalPet
    CombatSystem.floatingTexts = originalFloatingTexts
    CombatSystem.monsterWarnings = originalMonsterWarnings

    local summary = {
        passed = passed,
        failed = failed,
        total = total,
        log = table.concat(log, "\n"),
    }
    print("[CH6SkillTest] passed=" .. passed .. " failed=" .. failed .. " total=" .. total)
    print(summary.log)
    return summary
end

return M
