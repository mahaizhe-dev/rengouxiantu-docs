-- ============================================================================
-- SkillSystem.lua - 技能系统 Facade（解锁、释放、冷却管理）
-- 子模块: skill/casting_a, skill/casting_b, skill/bar, skill/passives
-- ============================================================================

local GameConfig = require("config.GameConfig")
local SkillData = require("config.SkillData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CombatSystem = require("systems.CombatSystem")
local ComboRunner = require("systems.combat.ComboRunner")

-- 子模块
local casting_a = require("systems.skill.casting_a")
local casting_b = require("systems.skill.casting_b")
local bar       = require("systems.skill.bar")
local passives  = require("systems.skill.passives")

local SkillSystem = {}

-- P1-2: local化高频 math 函数
local math_floor = math.floor

-- ── 技能类型处理器注册表 ──
SkillSystem.TypeHandlers = {}

--- 注册技能类型处理器
---@param typeName string
---@param handler table { cast?: fun(skill, player): boolean, passive?: fun(skill, player) }
function SkillSystem.RegisterType(typeName, handler)
    SkillSystem.TypeHandlers[typeName] = handler
end

-- ── 复用缓冲区：AutoCast 就绪技能列表 ──
local _readySkillsBuf = {}

-- 已解锁技能列表
SkillSystem.unlockedSkills = {}

-- 技能冷却计时器 { skillId = remainingCD }
SkillSystem.cooldowns = {}

-- 技能栏（最多4个已装备技能ID）
SkillSystem.equippedSkills = {}

-- 被动技能状态（per-skill，按 skill.id 索引）
SkillSystem.skillState = {}

-- ============================================================================
-- 子模块函数挂载（直接透传，无需包装）
-- ============================================================================

-- casting_a: FilterByShape + 8 种 Cast
SkillSystem.FilterByShape          = casting_a.FilterByShape
SkillSystem.CastDamageSkill        = casting_a.CastDamageSkill
SkillSystem.CastLifestealSkill     = casting_a.CastLifestealSkill
SkillSystem.CastHealSkill          = casting_a.CastHealSkill
SkillSystem.CastBuffSkill          = casting_a.CastBuffSkill
SkillSystem.CastAoeDotSkill        = casting_a.CastAoeDotSkill
SkillSystem.CastGroundZoneSkill    = casting_a.CastGroundZoneSkill
SkillSystem.CastXianyuanConeAoeSkill = casting_a.CastXianyuanConeAoeSkill
SkillSystem.CastDamageAmpZoneSkill = casting_a.CastDamageAmpZoneSkill

-- casting_b: 4 种特殊 Cast
SkillSystem.CastMeleeAoeDotSkill   = casting_b.CastMeleeAoeDotSkill
SkillSystem.CastMultiZoneHeavySkill = casting_b.CastMultiZoneHeavySkill
SkillSystem.CastHpDamageSkill      = casting_b.CastHpDamageSkill
SkillSystem.CastHpHealDamageSkill  = casting_b.CastHpHealDamageSkill

-- passives: 不需要 SkillSystem 参数的函数直接透传
SkillSystem.SwordShieldPassive     = passives.SwordShieldPassive
SkillSystem.SwordShieldOnSkillCast = passives.SwordShieldOnSkillCast
SkillSystem.CreateSwordFormationFromSkill = passives.CreateSwordFormationFromSkill
SkillSystem.UpdateSwordFormations  = passives.UpdateSwordFormations
SkillSystem.TriggerChargePassiveRelease = passives.TriggerChargePassiveRelease
SkillSystem.AccumulateTriggerTick  = passives.AccumulateTriggerTick

-- passives: 需要 SkillSystem 参数的函数用包装器
function SkillSystem.TryNthCastTrigger(nthSkill, castSkillId, castSkill)
    return passives.TryNthCastTrigger(nthSkill, castSkillId, castSkill, SkillSystem)
end

function SkillSystem.TriggerNthCastEffect(skill, player)
    return passives.TriggerNthCastEffect(skill, player, SkillSystem)
end

function SkillSystem.ChargePassiveAddStacks(skill, count)
    return passives.ChargePassiveAddStacks(skill, count, SkillSystem)
end

function SkillSystem.TogglePassiveTick(skill, player, skillId, dt)
    return passives.TogglePassiveTick(skill, player, skillId, dt, SkillSystem)
end

function SkillSystem.TogglePassiveSkill(skillId)
    return passives.TogglePassiveSkill(skillId, SkillSystem)
end

-- bar: 所有函数需要 SkillSystem 参数
function SkillSystem.BindEquipSkill(skillId)
    return bar.BindEquipSkill(skillId, SkillSystem)
end

function SkillSystem.UnbindEquipSkill(skillId)
    return bar.UnbindEquipSkill(skillId, SkillSystem)
end

function SkillSystem.BindExclusiveSkill(skillId)
    return bar.BindExclusiveSkill(skillId, SkillSystem)
end

function SkillSystem.UnbindExclusiveSkill(skillId)
    return bar.UnbindExclusiveSkill(skillId, SkillSystem)
end

function SkillSystem.AutoCast()
    return bar.AutoCast(SkillSystem, _readySkillsBuf)
end

function SkillSystem.GetSkillBarInfo()
    return bar.GetSkillBarInfo(SkillSystem)
end

function SkillSystem.GetCooldownRatio(skillId)
    return bar.GetCooldownRatio(skillId, SkillSystem)
end

function SkillSystem.GetSkillBarSlots()
    return bar.GetSkillBarSlots(SkillSystem)
end

function SkillSystem.RestoreSkillBar(slots)
    return bar.RestoreSkillBar(slots, SkillSystem)
end

-- ============================================================================
-- Facade 核心逻辑（保留在主模块）
-- ============================================================================

--- 查找所有已解锁的指定类型技能
---@param typeName string
---@return table[]
function SkillSystem.FindUnlockedByType(typeName)
    local results = {}
    for skillId, unlocked in pairs(SkillSystem.unlockedSkills) do
        if unlocked then
            local skill = SkillData.Skills[skillId]
            if skill and skill.type == typeName then
                table.insert(results, skill)
            end
        end
    end
    return results
end

--- 获取或初始化指定技能的状态
---@param skillId string
---@param defaults table
---@return table
function SkillSystem.GetSkillState(skillId, defaults)
    if not SkillSystem.skillState[skillId] then
        SkillSystem.skillState[skillId] = defaults or {}
    end
    return SkillSystem.skillState[skillId]
end

--- 初始化技能系统
function SkillSystem.Init()
    SkillSystem.unlockedSkills = {}
    SkillSystem.cooldowns = {}
    SkillSystem.equippedSkills = {}
    SkillSystem.skillState = {}
    ComboRunner.Init()

    EventBus.On("player_levelup", function(level)
        SkillSystem.CheckUnlocks()
    end)
    EventBus.On("realm_breakthrough", function(oldRealm, newRealm)
        SkillSystem.CheckUnlocks()
    end)

    -- 通用被动事件驱动
    EventBus.On("player_normal_hit", function(player, monster)
        SkillSystem.HandleChargePassiveHit(1)
    end)
    EventBus.On("player_heavy_hit", function(player, monster)
        SkillSystem.HandleChargePassiveHit(2)
    end)
    EventBus.On("skill_cast", function(skillId, skill)
        SkillSystem.HandleSkillCastPassives(skillId, skill)
    end)

    SkillSystem.CheckUnlocks()
    print("[SkillSystem] Initialized")
end

--- 通用：普攻/重击事件 → charge_passive
---@param hitCount number
function SkillSystem.HandleChargePassiveHit(hitCount)
    local skills = SkillSystem.FindUnlockedByType("charge_passive")
    for _, skill in ipairs(skills) do
        SkillSystem.ChargePassiveAddStacks(skill, hitCount)
    end
end

--- 通用：skill_cast 事件 → 分发给需要响应的被动技能
---@param skillId string
---@param skill table
function SkillSystem.HandleSkillCastPassives(skillId, skill)
    -- 1. 御剑类被动
    local shieldSkills = SkillSystem.FindUnlockedByType("sword_shield_passive")
    for _, shieldSkill in ipairs(shieldSkills) do
        SkillSystem.SwordShieldOnSkillCast(shieldSkill, skillId, skill)
    end

    -- 2. N次释放触发类被动
    local nthSkills = SkillSystem.FindUnlockedByType("nth_cast_trigger")
    for _, nthSkill in ipairs(nthSkills) do
        SkillSystem.TryNthCastTrigger(nthSkill, skillId, skill)
    end

    -- 3. 诛仙阵图被动（第五章神器）
    local okCh5, ArtifactCh5 = pcall(require, "systems.ArtifactSystem_ch5")
    if okCh5 and ArtifactCh5 and ArtifactCh5.TryTriggerZhentu then
        ArtifactCh5.TryTriggerZhentu(skillId, skill)
    end
end

--- 检查并解锁可用技能
function SkillSystem.CheckUnlocks()
    local player = GameState.player
    if not player then return end

    local classId = player.classId or GameConfig.PLAYER_CLASS
    local unlockList = SkillData.UnlockOrder[classId]
    if not unlockList then return end

    for _, skillId in ipairs(unlockList) do
        local skill = SkillData.Skills[skillId]
        if skill and not SkillSystem.unlockedSkills[skillId] then
            if skill.classId and skill.classId ~= classId then
                goto continue
            end

            local levelOk = player.level >= skill.unlockLevel
            local realmOk = true
            if skill.unlockRealm then
                local reqRealm = GameConfig.REALMS[skill.unlockRealm]
                local curRealm = GameConfig.REALMS[player.realm]
                local reqOrder = reqRealm and reqRealm.order or 0
                local curOrder = curRealm and curRealm.order or 0
                realmOk = curOrder >= reqOrder
            end

            if levelOk and realmOk then
                SkillSystem.unlockedSkills[skillId] = true
                local slotCount = 0
                for si = 1, 3 do
                    if SkillSystem.equippedSkills[si] then slotCount = slotCount + 1 end
                end
                if slotCount < 3 then
                    for si = 1, 3 do
                        if not SkillSystem.equippedSkills[si] then
                            SkillSystem.equippedSkills[si] = skillId
                            break
                        end
                    end
                end
                EventBus.Emit("skill_unlocked", skillId, skill)
                print("[SkillSystem] Unlocked: " .. skill.name .. " (" .. skill.icon .. ")")
            end

            ::continue::
        end
    end
end

--- 更新技能冷却 + 被动技能检测
---@param dt number
function SkillSystem.Update(dt)
    -- 冷却倒计时
    for skillId, remaining in pairs(SkillSystem.cooldowns) do
        remaining = remaining - dt
        if remaining <= 0 then
            SkillSystem.cooldowns[skillId] = nil
            local skill = SkillData.Skills[skillId]
            if skill and skill.onCDReady then
                local ok, err = pcall(skill.onCDReady, skill, GameState.player)
                if not ok then
                    print("[SkillSystem] onCDReady error for " .. skillId .. ": " .. tostring(err))
                end
            end
        else
            SkillSystem.cooldowns[skillId] = remaining
        end
    end

    -- 护盾持续时间倒计时
    local player = GameState.player
    if player and player.shieldHp and player.shieldHp > 0 then
        player.shieldTimer = (player.shieldTimer or 0) - dt
        if player.shieldTimer <= 0 then
            player.shieldHp = 0
            player.shieldMaxHp = 0
            player.shieldTimer = 0
            EventBus.Emit("shield_expired")
        end
    end

    -- 被动技能触发检测
    if player and player.alive then
        SkillSystem.CheckPassiveTriggers(player, dt)
    end

    -- 更新剑阵降临
    SkillSystem.UpdateSwordFormations(dt)

    -- 更新连击延迟队列
    ComboRunner.Update(dt)
end

--- 检测被动技能触发
---@param player table
---@param dt number
function SkillSystem.CheckPassiveTriggers(player, dt)
    for skillId, _ in pairs(SkillSystem.unlockedSkills) do
        if not SkillSystem.cooldowns[skillId] then
            local skill = SkillData.Skills[skillId]
            if skill then
                local handler = SkillSystem.TypeHandlers[skill.type]
                if handler and handler.passive then
                    local ok, err = pcall(handler.passive, skill, player, skillId, dt)
                    if not ok then
                        print("[SkillSystem] passive pcall error skillId=" .. tostring(skillId) .. ": " .. tostring(err))
                    end
                end
            end
        end
    end
end

--- 金钟罩被动触发逻辑
---@param skill table
---@param player table
---@param skillId string
function SkillSystem.PassiveShieldTrigger(skill, player, skillId)
    if player.shieldHp and player.shieldHp > 0 then return end

    local maxHp = player:GetTotalMaxHp()
    local threshold = skill.triggerThreshold or 0.5
    if maxHp > 0 and (player.hp / maxHp) < threshold then
        local totalDef = player:GetTotalDef()
        local shieldValue = math_floor(totalDef * skill.shieldMultiplier)
        player.shieldHp = shieldValue
        player.shieldMaxHp = shieldValue
        player.shieldTimer = skill.shieldDuration

        SkillSystem.cooldowns[skillId] = skill.cooldown

        CombatSystem.EmitCombatFeedback({
            kind = "absorb", value = shieldValue,
            source = player, target = player, targetKey = "player:self",
            sourceType = "skill", sourceId = skillId,
            sourceName = skill.name, color = skill.effectColor,
        }, {
            x = player.x, y = player.y - 0.8,
            text = skill.icon .. skill.name .. " +" .. shieldValue,
            color = skill.effectColor, lifetime = 1.8,
        })
        CombatSystem.AddSkillEffect(player, skill.id, 1.5, skill.effectColor, "passive", nil)

        EventBus.Emit("skill_cast", skillId, skill)
        EventBus.Emit("shield_activated", shieldValue, skill.shieldDuration)
        print("[SkillSystem] Golden Bell triggered! Shield: " .. shieldValue)
    end
end

--- 释放技能（按技能栏索引）
---@param slotIndex number 1-4
---@return boolean
function SkillSystem.CastBySlot(slotIndex)
    local skillId = SkillSystem.equippedSkills[slotIndex]
    if not skillId then return false end
    return SkillSystem.Cast(skillId)
end

--- 释放技能
---@param skillId string
---@return boolean
function SkillSystem.Cast(skillId)
    local player = GameState.player
    if not player or not player.alive then return false end

    if not SkillSystem.unlockedSkills[skillId] then return false end
    if SkillSystem.cooldowns[skillId] then return false end

    local skill = SkillData.Skills[skillId]
    if not skill then return false end

    local handler = SkillSystem.TypeHandlers[skill.type]
    if not handler or not handler.cast then return false end

    local success = handler.cast(skill, player)

    if success then
        SkillSystem.cooldowns[skillId] = skill.cooldown
        EventBus.Emit("skill_cast", skillId, skill)
        print("[SkillSystem] Cast: " .. skill.name)
    end

    return success
end

-- ============================================================================
-- 注册内置技能类型处理器
-- ============================================================================

SkillSystem.RegisterType("melee_aoe",  { cast = SkillSystem.CastDamageSkill })
SkillSystem.RegisterType("ranged_aoe", { cast = SkillSystem.CastDamageSkill })
SkillSystem.RegisterType("lifesteal",  { cast = SkillSystem.CastLifestealSkill })
SkillSystem.RegisterType("heal",       { cast = SkillSystem.CastHealSkill })
SkillSystem.RegisterType("buff",       { cast = SkillSystem.CastBuffSkill })
SkillSystem.RegisterType("aoe_dot",    { cast = SkillSystem.CastAoeDotSkill })
SkillSystem.RegisterType("ground_zone",{ cast = SkillSystem.CastGroundZoneSkill })
SkillSystem.RegisterType("passive",    { passive = SkillSystem.PassiveShieldTrigger })
SkillSystem.RegisterType("charge_passive", {})
SkillSystem.RegisterType("sword_shield_passive", { passive = SkillSystem.SwordShieldPassive })
SkillSystem.RegisterType("nth_cast_trigger", {})
SkillSystem.RegisterType("melee_aoe_dot",  { cast = SkillSystem.CastMeleeAoeDotSkill })
SkillSystem.RegisterType("multi_zone_heavy", { cast = SkillSystem.CastMultiZoneHeavySkill })

-- 镇岳职业技能类型
SkillSystem.RegisterType("hp_damage",          { cast = SkillSystem.CastHpDamageSkill })
SkillSystem.RegisterType("hp_heal_damage",     { cast = SkillSystem.CastHpHealDamageSkill })
SkillSystem.RegisterType("toggle_passive",     { cast = function(skill, _player)
    SkillSystem.TogglePassiveSkill(skill.id)
    return true
end, passive = SkillSystem.TogglePassiveTick })
SkillSystem.RegisterType("accumulate_trigger", { passive = SkillSystem.AccumulateTriggerTick })

-- 封魔盘法宝技能类型
SkillSystem.RegisterType("damage_amp_zone",    { cast = SkillSystem.CastDamageAmpZoneSkill })

-- 龙极令法宝技能类型（仙缘扇形 AOE）
SkillSystem.RegisterType("xianyuan_cone_aoe",  { cast = SkillSystem.CastXianyuanConeAoeSkill })

return SkillSystem
