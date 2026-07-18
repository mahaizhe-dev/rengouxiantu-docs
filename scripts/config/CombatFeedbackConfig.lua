-- ============================================================================
-- CombatFeedbackConfig.lua - 主世界战斗跳字视觉与队列配置
-- ============================================================================

local Config = {}

Config.MAX_GLOBAL = 36
Config.MAX_PER_TARGET = 5
Config.MAX_SELF = 4
Config.MAX_DOT_PER_TARGET = 2
Config.MAX_LABELS_PER_CAST = 3

Config.LANES = { 0, -16, 16, -30, 30 }

Config.COLORS = {
    damageNormal  = {255, 242, 194, 255},
    damageSkill   = {255, 231, 163, 255},
    damageCrit    = {255, 216, 74, 255},
    damageTianzhu = {113, 243, 255, 255},
    damageHeavy   = {255, 154, 61, 255},
    damageDot     = {229, 138, 138, 255},
    damagePet     = {143, 230, 181, 255},
    heal          = {111, 229, 138, 255},
    hurt          = {255, 102, 117, 255},
    absorb        = {121, 201, 255, 255},
    statusNeutral = {240, 240, 240, 255},
    outline       = {36, 27, 27, 255},
    shadow        = {0, 0, 0, 150},
}

Config.FONTS = {
    normal  = 18,
    skill   = 19,
    crit    = 22,
    tianzhu = 25,
    heavy   = 21,
    dot     = 15,
    heal    = 18,
    hurt    = 20,
    absorb  = 16,
    status  = 17,
    label   = 12,
    tag     = 11,
    count   = 10,
}

Config.PRIORITY = {
    tianzhu  = 100,
    selfHigh = 90,
    crit     = 80,
    skillHeavy = 75,
    heavy    = 70,
    absorb   = 65,
    heal     = 60,
    skill    = 55,
    proc     = 50,
    basic    = 40,
    pet      = 35,
    dot      = 20,
    status   = 45,
}

Config.AGGREGATE_WINDOWS = {
    basic = 0.08,
    skill = 0.10,
    dot   = 0.16,
    pet   = 0.08,
    heal  = 0.10,
}

Config.LABEL_COOLDOWNS = {
    default = 0.80,
    dot = 1.00,
    proc = 0.60,
}

Config.ANIMATIONS = {
    normal = {
        duration = 0.82, travelY = 42, driftX = 6,
        startScale = 0.88, peakScale = 1.06, peakAt = 0.085, settleAt = 0.18,
    },
    skill = {
        duration = 0.92, travelY = 48, driftX = 8,
        startScale = 0.86, peakScale = 1.10, peakAt = 0.085, settleAt = 0.19,
    },
    crit = {
        duration = 1.02, travelY = 54, driftX = 10,
        startScale = 0.82, peakScale = 1.24, peakAt = 0.08, settleAt = 0.20,
    },
    tianzhu = {
        duration = 1.15, travelY = 60, driftX = 10,
        startScale = 0.78, peakScale = 1.36, peakAt = 0.08, settleAt = 0.21,
    },
    heavy = {
        duration = 1.00, travelY = 50, driftX = 6,
        startScale = 0.84, peakScale = 1.18, peakAt = 0.09, settleAt = 0.23,
    },
    dot = {
        duration = 0.62, travelY = 24, driftX = 4,
        startScale = 0.96, peakScale = 1.02, peakAt = 0.08, settleAt = 0.16,
    },
    heal = {
        duration = 0.90, travelY = 38, driftX = 4,
        startScale = 0.90, peakScale = 1.08, peakAt = 0.09, settleAt = 0.19,
    },
    hurt = {
        duration = 0.85, travelY = 34, driftX = 6,
        startScale = 0.86, peakScale = 1.14, peakAt = 0.08, settleAt = 0.18,
    },
    absorb = {
        duration = 0.80, travelY = 30, driftX = 4,
        startScale = 0.92, peakScale = 1.06, peakAt = 0.09, settleAt = 0.18,
    },
    status = {
        duration = 0.95, travelY = 28, driftX = 2,
        startScale = 0.94, peakScale = 1.04, peakAt = 0.10, settleAt = 0.20,
    },
}

return Config
