-- ============================================================================
-- HitResolver.lua - 统一命中结算器
-- Step 3 of 战斗系统架构优化方案
-- ============================================================================
--
-- 将分散在 SkillSystem / CombatSystem / ArtifactSystem 中的伤害管线
-- 统一为可组合的单目标命中函数：
--
--   CalcDamage（可选）→ ApplyCrit（可选）→ TakeDamage → EventBus.Emit（可选）
--
-- 支持 4 种管线模式：
--   标准:     CalcDamage → ApplyCrit → TakeDamage → Event
--   重击/真伤: 跳过 CalcDamage → ApplyCrit → TakeDamage → Event
--   无暴击:   CalcDamage → 跳过 ApplyCrit → TakeDamage（可选 Event）
--   纯旁路:   跳过 CalcDamage → 跳过 ApplyCrit → TakeDamage（可选 Event）
--
-- 设计原则：
--   1. 窄 helper：只管 per-target 的 damage→crit→hit→event 四步
--   2. 调用方仍负责：原始伤害计算、目标遍历、浮字、debuff、吸血等业务
--   3. 返回 (actualDamage, isCrit) 供调用方做后处理
--   4. 与 BattleContracts.HitContext 契约对齐
-- ============================================================================

local GameConfig = require("config.GameConfig")
local EventBus   = require("core.EventBus")

local HitResolver = {}

--- @type table
local EMPTY_OPTS = {}

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 单目标命中结算（通用入口）
---
--- 管线：rawDmg → [CalcDamage] → [ApplyCrit] → TakeDamage → [Event]
---
--- @param source table   攻击来源（Player / Pet，需要 .ApplyCrit 方法）
--- @param target table   攻击目标（Monster，需要 .def, .alive, :TakeDamage）
--- @param rawDmg number  原始伤害（CalcDamage 之前的攻击力基数）
--- @param opts table|nil 管线选项：
---   skipCalcDamage  boolean?  跳过 CalcDamage（真实伤害 / 重击，默认 false）
---   skipCrit        boolean?  跳过 ApplyCrit（装备特效旁路，默认 false）
---   conditionalCrit boolean?  条件暴击（仅当 canCrit=true 时才暴击，默认 false）
---   canCrit         boolean?  配合 conditionalCrit 使用
---   isDot           boolean?  标记为持续伤害（Event 第 4 参数，默认 false）
---   noEvent         boolean?  跳过 player_deal_damage 事件（默认 false）
---   pcallTakeDamage boolean?  用 pcall 包裹 TakeDamage（血神等容错场景）
---
--- @return number actualDamage  TakeDamage 返回的实际伤害
--- @return boolean isCrit       是否暴击
function HitResolver.Hit(source, target, rawDmg, opts)
    opts = opts or EMPTY_OPTS

    local damage = rawDmg
    local isCrit = false

    -- Step 1: 防御减算
    if not opts.skipCalcDamage then
        damage = GameConfig.CalcDamage(damage, target.def)
    end

    -- Step 2: 暴击判定
    if not opts.skipCrit then
        if opts.conditionalCrit then
            -- 条件暴击：仅当 canCrit 为 true 且 source 有 ApplyCrit 时
            if opts.canCrit and source and source.ApplyCrit then
                damage, isCrit = source:ApplyCrit(damage)
            end
        else
            -- 无条件暴击
            if source and source.ApplyCrit then
                damage, isCrit = source:ApplyCrit(damage)
            end
        end
    end

    -- Step 3: 扣血
    if opts.pcallTakeDamage then
        local ok, result = pcall(target.TakeDamage, target, damage, source)
        if ok then
            damage = result or damage
        else
            print("[HitResolver] TakeDamage pcall error: " .. tostring(result))
        end
    else
        damage = target:TakeDamage(damage, source)
    end

    -- Step 4: 事件
    if not opts.noEvent then
        if opts.isDot then
            EventBus.Emit("player_deal_damage", source, target, true)
        else
            EventBus.Emit("player_deal_damage", source, target)
        end
    end

    return damage, isCrit
end

-- ============================================================================
-- 便捷方法（覆盖 4 种常见管线模式）
-- ============================================================================

--- 标准管线：CalcDamage → ApplyCrit → TakeDamage → Event
--- 用于：CastDamageSkill, CastLifestealSkill, CastAoeDotSkill, AutoAttack 等
---@param source table
---@param target table
---@param rawDmg number
---@return number actualDamage
---@return boolean isCrit
function HitResolver.Standard(source, target, rawDmg)
    return HitResolver.Hit(source, target, rawDmg)
end

--- 真伤/重击管线：跳过 CalcDamage → ApplyCrit → TakeDamage → Event
--- 用于：TriggerChargePassive, CastMultiZoneHeavy, AccumulateTriggerTick 等
---@param source table
---@param target table
---@param rawDmg number
---@return number actualDamage
---@return boolean isCrit
function HitResolver.TrueDamage(source, target, rawDmg)
    return HitResolver.Hit(source, target, rawDmg, {
        skipCalcDamage = true,
    })
end

--- 无暴击管线：CalcDamage → 跳过 ApplyCrit → TakeDamage（无 Event）
--- 用于：装备特效 bleed_dot, wind_slash, lifesteal_burst
---@param source table
---@param target table
---@param rawDmg number
---@return number actualDamage
---@return boolean isCrit (always false)
function HitResolver.NoCrit(source, target, rawDmg)
    return HitResolver.Hit(source, target, rawDmg, {
        skipCrit = true,
        noEvent  = true,
    })
end

--- 纯旁路管线：跳过 CalcDamage → 跳过 ApplyCrit → TakeDamage（无 Event）
--- 用于：ArtifactSystem.TryPassiveStrike
---@param source table
---@param target table
---@param rawDmg number
---@return number actualDamage
---@return boolean isCrit (always false)
function HitResolver.Bypass(source, target, rawDmg)
    return HitResolver.Hit(source, target, rawDmg, {
        skipCalcDamage = true,
        skipCrit       = true,
        noEvent        = true,
    })
end

return HitResolver
