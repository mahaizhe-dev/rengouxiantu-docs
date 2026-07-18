-- ============================================================================
-- MonsterData_Skills_ch6.lua - Chapter 6 monster skill definitions
-- ============================================================================
-- Only the two saint bosses add new skills here. All shapes are already handled
-- by GameEvents and CombatSystem warning rendering.
-- ============================================================================

---@param M table MonsterData main module
return function(M)
    -- =====================================================================
    -- Gua Master: poison bubbles, swamp crosses, and one phase field burst
    -- =====================================================================

    M.Skills.ch6_gua_toxic_orbs = {
        id = "ch6_gua_toxic_orbs",
        name = "呱鸣毒泡",
        cooldown = 6,
        damageMult = 1.4,
        effect = "poison",
        effectDuration = 3.0,
        effectValue = 0.25,
        castTime = 0.6,
        burstCount = 3,
        burstInterval = 0.45,
        burstTrack = true,
        warningShape = "circle",
        warningRange = 1.5,
        warningColor = {70, 180, 70, 120},
    }

    M.Skills.ch6_gua_swamp_cross = {
        id = "ch6_gua_swamp_cross",
        name = "沼纹连涌",
        cooldown = 9,
        damageMult = 1.7,
        effect = "slow",
        effectDuration = 2.5,
        effectValue = 0.35,
        castTime = 0.9,
        burstCount = 2,
        burstInterval = 0.45,
        burstRotation = 45,
        warningShape = "cross",
        warningRange = 4.0,
        warningCrossWidth = 0.8,
        warningColor = {70, 150, 90, 125},
    }

    M.Skills.ch6_gua_toxic_burst = {
        id = "ch6_gua_toxic_burst",
        name = "毒潭连爆",
        cooldown = 11,
        damageMult = 2.0,
        effect = "poison",
        effectDuration = 4.0,
        effectValue = 0.35,
        castTime = 0.8,
        burstCount = 4,
        burstInterval = 0.4,
        burstTrack = true,
        warningShape = "circle",
        warningRange = 1.8,
        warningColor = {80, 170, 60, 130},
    }

    M.Skills.ch6_gua_domain_cycle = {
        id = "ch6_gua_domain_cycle",
        name = "万沼归潭",
        cooldown = 13,
        damageMult = 2.2,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.45,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 3.5,
        warningColor = {60, 140, 55, 135},
    }

    M.Skills.ch6_gua_domain_burst = {
        id = "ch6_gua_domain_burst",
        name = "万沼归潭·大潮",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.42,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {50, 130, 45, 165},
    }

    -- =====================================================================
    -- Artifact Jieshi: immortalized Gua King control skills
    -- =====================================================================

    M.Skills.ch6_gua_immortal_lotus = {
        id = "ch6_gua_immortal_lotus",
        name = "玉莲镇界",
        cooldown = 7,
        damageMult = 1.55,
        effect = "slow",
        effectDuration = 2.2,
        effectValue = 0.30,
        castTime = 0.7,
        burstCount = 3,
        burstInterval = 0.5,
        burstTrack = true,
        warningShape = "circle",
        warningRange = 1.7,
        warningColor = {120, 225, 205, 135},
    }

    M.Skills.ch6_gua_immortal_cross = {
        id = "ch6_gua_immortal_cross",
        name = "仙阙分潮",
        cooldown = 9,
        damageMult = 1.8,
        effect = "stun",
        effectDuration = 0.65,
        castTime = 0.9,
        burstCount = 2,
        burstInterval = 0.55,
        burstRotation = 45,
        warningShape = "cross",
        warningRange = 4.2,
        warningCrossWidth = 0.75,
        warningColor = {155, 235, 215, 140},
    }

    M.Skills.ch6_gua_immortal_seal = {
        id = "ch6_gua_immortal_seal",
        name = "九霄莲印",
        cooldown = 12,
        damageMult = 2.15,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.42,
        castTime = 1.1,
        burstCount = 4,
        burstInterval = 0.45,
        burstTrack = true,
        warningShape = "circle",
        warningRange = 2.0,
        warningColor = {185, 245, 220, 150},
    }

    -- =====================================================================
    -- Demon Lord Shixuan: shadow lines, crossing rifts, and one field burst
    -- =====================================================================

    M.Skills.ch6_shixuan_shadow_cross = {
        id = "ch6_shixuan_shadow_cross",
        name = "玄影裂界",
        cooldown = 8,
        damageMult = 2.0,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.30,
        castTime = 0.8,
        burstCount = 3,
        burstInterval = 0.4,
        burstRotation = 30,
        warningShape = "cross",
        warningRange = 4.5,
        warningCrossWidth = 0.7,
        warningColor = {120, 55, 180, 135},
    }

    M.Skills.ch6_shixuan_seal_line = {
        id = "ch6_shixuan_seal_line",
        name = "封梦玄线",
        cooldown = 7,
        damageMult = 2.1,
        effect = "slow",
        effectDuration = 2.5,
        effectValue = 0.35,
        castTime = 0.7,
        burstCount = 3,
        burstInterval = 0.45,
        burstTrack = true,
        warningShape = "line",
        warningRange = 5.0,
        warningLineWidth = 0.7,
        warningColor = {150, 70, 210, 135},
    }

    M.Skills.ch6_shixuan_void_collapse = {
        id = "ch6_shixuan_void_collapse",
        name = "影界塌缩",
        cooldown = 12,
        damageMult = 2.5,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.45,
        castTime = 1.0,
        burstCount = 3,
        burstInterval = 0.5,
        burstTrack = true,
        warningShape = "circle",
        warningRange = 2.2,
        warningColor = {110, 45, 165, 145},
    }

    M.Skills.ch6_shixuan_dream_cycle = {
        id = "ch6_shixuan_dream_cycle",
        name = "两界封梦",
        cooldown = 14,
        damageMult = 2.4,
        effect = "stun",
        effectDuration = 0.8,
        castTime = 1.1,
        burstCount = 2,
        burstInterval = 0.45,
        burstRotation = 45,
        warningShape = "cross",
        warningRange = 5.5,
        warningCrossWidth = 0.8,
        warningColor = {130, 50, 190, 145},
    }

    M.Skills.ch6_shixuan_dream_burst = {
        id = "ch6_shixuan_dream_burst",
        name = "两界封梦·大破",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.46,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.6,
        castTime = 2.6,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {120, 35, 180, 170},
    }
end
