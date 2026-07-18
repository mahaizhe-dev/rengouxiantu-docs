-- ============================================================================
-- skill/shared.lua - SkillSystem 子模块公共依赖
-- ============================================================================

local shared = {}

-- ── 公共依赖 ──
shared.GameConfig    = require("config.GameConfig")
shared.SkillData     = require("config.SkillData")
shared.GameState     = require("core.GameState")
shared.EventBus      = require("core.EventBus")
shared.Utils         = require("core.Utils")
shared.CombatSystem  = require("systems.CombatSystem")
shared.TargetSelector = require("systems.combat.TargetSelector")
shared.HitResolver   = require("systems.combat.HitResolver")
shared.ComboRunner   = require("systems.combat.ComboRunner")

-- ── local 化高频 math 函数 ──
shared.math_floor  = math.floor
shared.math_max    = math.max
shared.math_min    = math.min
shared.math_random = math.random
shared.math_atan   = math.atan
shared.math_cos    = math.cos
shared.math_sin    = math.sin
shared.math_abs    = math.abs
shared.math_rad    = math.rad
shared.math_pi     = math.pi

function shared.Criticality(isCrit, isTianzhu)
    return isTianzhu and "tianzhu" or (isCrit and "crit" or "normal")
end

function shared.EmitSkillDamage(player, target, skill, damage, isCrit, isTianzhu, castId, opts)
    opts = opts or {}
    local legacy
    if not opts.noLegacy then
        legacy = {
            x = opts.legacyX or (target and target.x) or 0,
            y = opts.legacyY or (target and target.y and target.y - 0.3) or 0,
            text = opts.legacyText or tostring(damage),
            color = opts.legacyColor or skill.effectColor,
            lifetime = opts.legacyLifetime or 1.2,
            baseScale = opts.legacyScale,
        }
    end
    return shared.CombatSystem.EmitDamageFeedback(player, target, damage, {
        sourceType = opts.sourceType or "skill",
        sourceId = opts.sourceId or skill.id,
        sourceName = opts.sourceName or skill.name,
        sourceShortName = opts.sourceShortName,
        damageTag = opts.damageTag or "skill",
        criticality = shared.Criticality(isCrit, isTianzhu),
        impact = opts.impact,
        castId = castId,
        hitIndex = opts.hitIndex,
        labelPolicy = opts.labelPolicy,
        aggregatePolicy = opts.aggregatePolicy,
        color = opts.color or skill.effectColor,
        x = opts.x,
        y = opts.y or (target and target.y and target.y - 0.3),
    }, legacy)
end

function shared.EmitHealFeedback(source, target, value, sourceName, color, legacy)
    return shared.CombatSystem.EmitCombatFeedback({
        kind = "heal",
        value = value,
        source = source,
        target = target,
        sourceType = "skill",
        sourceName = sourceName,
        color = color,
        targetKey = target == source and "player:self" or nil,
    }, legacy)
end

return shared
