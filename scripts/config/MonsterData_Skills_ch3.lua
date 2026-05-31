-- ============================================================================
-- MonsterData_Skills_ch3.lua - 第三章·沙漠九寨技能定义
-- 包含: 精英技能 + 六大妖王 + 烈焰狮王 + 蜃妖王 + 沙万里 + 猪二哥 + 流沙之母
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    -- ===================== 第三章·沙漠九寨 专属技能 =====================

    -- === 精英技能 ===
    M.Skills.sand_blade = {
        id = "sand_blade",
        name = "沙刃斩",
        cooldown = 6,
        damageMult = 2.0,
        effect = nil,
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.0,
        warningConeAngle = 80,
        warningColor = {210, 180, 80, 100},     -- 沙黄
    }
    M.Skills.sand_cross_strike = {
        id = "sand_cross_strike",
        name = "沙暴裂击",
        cooldown = 8,
        damageMult = 2.2,
        effect = nil,
        castTime = 1.0,
        warningShape = "cross",
        warningRange = 2.5,
        warningCrossWidth = 0.8,
        warningColor = {220, 170, 50, 120},     -- 深沙黄
    }
    M.Skills.sand_fire_circle = {
        id = "sand_fire_circle",
        name = "炎沙灼地",
        cooldown = 9,
        damageMult = 1.0,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.35,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {240, 130, 30, 120},     -- 炎橙
    }

    -- === 枯木妖王 ===
    M.Skills.kumu_entangle = {
        id = "kumu_entangle",
        name = "枯木缠绕",
        cooldown = 8,
        damageMult = 1.5,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.35,         -- 降低35%移速和攻速
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {100, 140, 50, 100},     -- 枯木绿
    }
    M.Skills.kumu_decay_dust = {
        id = "kumu_decay_dust",
        name = "腐朽尘暴",
        cooldown = 10,
        damageMult = 1.0,
        effect = "poison",
        effectDuration = 4,
        effectValue = 0.3,
        castTime = 1.0,
        warningShape = "cone",
        warningRange = 2.5,
        warningConeAngle = 70,
        warningColor = {120, 100, 40, 100},     -- 腐朽棕
    }
    M.Skills.kumu_root_cross = {
        id = "kumu_root_cross",
        name = "根系穿刺",
        cooldown = 9,
        damageMult = 2.0,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.5,          -- 降低50%移速
        castTime = 1.0,
        warningShape = "cross",
        warningRange = 3.5,
        warningCrossWidth = 0.8,
        warningColor = {80, 120, 40, 110},      -- 暗绿
    }
    M.Skills.kumu_withered_field = {
        id = "kumu_withered_field",
        name = "枯木领域",
        cooldown = 999,             -- 仅阶段触发
        damageMult = 2.5,
        effect = "poison",
        effectDuration = 5,
        effectValue = 0.4,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {90, 110, 30, 100},      -- 枯叶暗绿
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.7,
        damagePercent = 0.35,       -- 占最大HP的35%
    }
    M.Skills.kumu_death_bloom = {
        id = "kumu_death_bloom",
        name = "死木绽放",
        cooldown = 12,
        damageMult = 2.2,
        effect = "stun",
        effectDuration = 1.5,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {140, 80, 160, 120},     -- 腐紫
    }
    M.Skills.kumu_berserk_roots = {
        id = "kumu_berserk_roots",
        name = "狂暴根须",
        cooldown = 999,             -- 仅阶段触发
        damageMult = 3.0,
        effect = "knockback",
        effectDuration = 0.5,
        effectValue = 2.0,          -- 击退距离
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 6.0,
        warningColor = {180, 60, 30, 130},      -- 血红
    }

    -- === 岩蟾妖王 ===
    M.Skills.yanchan_quake = {
        id = "yanchan_quake",
        name = "岩蟾震波",
        cooldown = 8,
        damageMult = 2.0,
        effect = "stun",
        effectDuration = 1.0,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {160, 140, 80, 120},     -- 岩土色
    }
    M.Skills.yanchan_venom_spray = {
        id = "yanchan_venom_spray",
        name = "毒瘴喷吐",
        cooldown = 7,
        damageMult = 1.2,
        effect = "poison",
        effectDuration = 3,
        effectValue = 0.35,
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.5,
        warningConeAngle = 90,
        warningColor = {80, 160, 60, 100},      -- 蟾毒绿
    }

    -- === 苍狼妖王 ===
    M.Skills.canglang_howl = {
        id = "canglang_howl",
        name = "苍狼嚎月",
        cooldown = 10,
        damageMult = 1.5,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.30,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {150, 160, 200, 120},    -- 月光银蓝
    }
    M.Skills.canglang_charge = {
        id = "canglang_charge",
        name = "撕咬冲锋",
        cooldown = 6,
        damageMult = 2.5,
        effect = nil,
        castTime = 0.6,             -- 快速冲锋
        warningShape = "line",
        warningRange = 3.5,
        warningLineWidth = 0.8,
        warningColor = {140, 150, 180, 120},    -- 银灰
    }

    -- === 赤甲妖王 ===
    M.Skills.chijia_tail_sweep = {
        id = "chijia_tail_sweep",
        name = "毒尾横扫",
        cooldown = 7,
        damageMult = 1.8,
        effect = "poison",
        effectDuration = 3,
        effectValue = 0.4,
        castTime = 0.8,
        warningShape = "rect",
        warningRange = 2.5,
        warningRectLength = 2.5,
        warningRectWidth = 1.2,
        warningColor = {200, 60, 60, 120},      -- 赤红
    }
    M.Skills.chijia_pincer = {
        id = "chijia_pincer",
        name = "蝎钳夹击",
        cooldown = 8,
        damageMult = 2.5,
        effect = "knockback",
        effectValue = 1.5,
        castTime = 1.0,
        warningShape = "cone",
        warningRange = 2.0,
        warningConeAngle = 90,
        warningColor = {220, 80, 30, 120},      -- 赤橙
    }

    -- === 蛇骨妖王 ===
    M.Skills.shegu_bone_spike = {
        id = "shegu_bone_spike",
        name = "骨刺穿地",
        cooldown = 8,
        damageMult = 2.5,
        effect = nil,
        castTime = 1.2,
        warningShape = "cross",
        warningRange = 3.0,
        warningCrossWidth = 0.7,
        warningColor = {200, 190, 160, 120},    -- 骨白
    }
    M.Skills.shegu_miasma = {
        id = "shegu_miasma",
        name = "瘴气弥漫",
        cooldown = 10,
        damageMult = 0.8,
        effect = "poison",
        effectDuration = 4,
        effectValue = 0.45,          -- 高毒
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {100, 50, 130, 100},     -- 毒紫
    }

    -- === 烈焰狮王（王级BOSS） ===
    M.Skills.lieyan_roar = {
        id = "lieyan_roar",
        name = "狮焰咆哮",
        cooldown = 10,
        damageMult = 1.5,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.4,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {255, 100, 20, 120},     -- 烈焰橙
    }
    M.Skills.lieyan_pounce = {
        id = "lieyan_pounce",
        name = "烈焰扑击",
        cooldown = 7,
        damageMult = 2.5,
        effect = "knockback",
        effectValue = 2.0,
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.5,
        warningConeAngle = 80,
        warningColor = {255, 80, 10, 120},      -- 深焰红
    }
    M.Skills.lieyan_inferno = {
        id = "lieyan_inferno",
        name = "焚天火域",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.4,        -- 40%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {255, 60, 10, 160},      -- 焚天红
    }

    -- === 蜃妖王（王级BOSS） ===
    M.Skills.shen_vortex = {
        id = "shen_vortex",
        name = "幻影旋涡",
        cooldown = 9,
        damageMult = 1.5,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.35,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {130, 80, 200, 120},     -- 蜃影紫
    }
    M.Skills.shen_maze = {
        id = "shen_maze",
        name = "蜃气迷阵",
        cooldown = 8,
        damageMult = 2.0,
        effect = "stun",
        effectDuration = 1.2,
        castTime = 1.0,
        warningShape = "cross",
        warningRange = 3.0,
        warningCrossWidth = 0.8,
        warningColor = {150, 60, 220, 120},     -- 幻紫
    }
    M.Skills.shen_annihilation = {
        id = "shen_annihilation",
        name = "幻灭之域",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.45,       -- 45%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {160, 40, 240, 160},     -- 幻灭紫
    }
    M.Skills.shen_clone = {
        id = "shen_clone",
        name = "蜃影分身",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        effect = nil,
        isCloneSkill = true,
        cloneCount = 2,
        cloneHpPercent = 0.12,      -- 分身12%BOSS血量
        cloneAtkPercent = 0.35,     -- 分身35%BOSS攻击
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {140, 60, 200, 120},     -- 幻影紫
    }

    -- === 黄天大圣·沙万里（皇级BOSS） ===
    M.Skills.sha_cross_quake = {
        id = "sha_cross_quake",
        name = "黄沙裂地",
        cooldown = 7,
        damageMult = 2.8,
        effect = "stun",
        effectDuration = 1.2,
        castTime = 1.0,
        warningShape = "cross",
        warningRange = 3.5,
        warningCrossWidth = 1.0,
        warningColor = {210, 170, 40, 140},     -- 皇金
    }
    -- ===================== 猪二哥专属：全屏AOE（过阶段触发，不可闪避） =====================
    M.Skills.zhu_erge_divine_wrath = {
        id = "zhu_erge_divine_wrath",
        name = "天蓬怒",
        cooldown = 999,             -- 由阶段转换触发，不走常规CD
        damageMult = 1.0,           -- 技能系数1.0
        effect = nil,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 6.0,         -- 覆盖整个8×8竞技场
        warningColor = {255, 200, 50, 160},
    }
    M.Skills.sha_desert_storm = {
        id = "sha_desert_storm",
        name = "大漠风暴",
        cooldown = 10,
        damageMult = 1.5,
        effect = "slow",
        effectDuration = 3.5,
        effectValue = 0.40,         -- 降低40%移速和攻速
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.5,
        warningColor = {200, 160, 50, 140},     -- 沙暴黄
    }
    M.Skills.sha_sandstorm_field = {
        id = "sha_sandstorm_field",
        name = "灭世沙暴",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.5,        -- 50%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {220, 180, 30, 160},     -- 沙暴金
    }
    M.Skills.sha_sand_clone = {
        id = "sha_sand_clone",
        name = "沙傀分身",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        effect = nil,
        isCloneSkill = true,
        cloneCount = 3,             -- 3个分身（皇级更多）
        cloneHpPercent = 0.10,      -- 分身10%BOSS血量
        cloneAtkPercent = 0.30,     -- 分身30%BOSS攻击
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {200, 160, 40, 120},     -- 沙金
    }

    -- ===================== 流沙之子/流沙之母 专属技能 =====================
    -- 钻地突袭：沙虫钻入地底，从玩家脚下破土而出
    M.Skills.liusha_burrow = {
        id = "liusha_burrow",
        name = "钻地突袭",
        cooldown = 6,
        damageMult = 2.2,
        effect = nil,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 1.5,
        warningColor = {200, 170, 80, 120},     -- 沙土黄
    }
    -- 流沙波涛：扇形沙浪，击退玩家（P2 addSkill）
    M.Skills.liusha_sand_wave = {
        id = "liusha_sand_wave",
        name = "流沙波涛",
        cooldown = 8,
        damageMult = 1.8,
        effect = "knockback",
        effectDuration = 0.5,
        effectValue = 2.0,              -- 击退距离
        castTime = 1.0,
        warningShape = "fan",
        warningRange = 3.0,
        warningFanAngle = 90,
        warningColor = {210, 180, 60, 130},     -- 流沙金
    }
    -- 流沙陷阱：在玩家脚下生成流沙漩涡，持续减速+伤害（流沙之母专属）
    M.Skills.liusha_quicksand = {
        id = "liusha_quicksand",
        name = "流沙陷阱",
        cooldown = 10,
        damageMult = 0.5,
        effect = "slow",
        effectDuration = 4.0,
        effectValue = 0.50,             -- 降低50%移速
        isFieldSkill = true,
        fieldDuration = 5.0,
        fieldRadius = 1.8,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 1.8,
        warningColor = {180, 140, 50, 140},     -- 深沙色
    }
    -- 沙暴领域：全屏沙暴，大幅降低视野+持续伤害（流沙之母P3终极技）
    M.Skills.liusha_sandstorm = {
        id = "liusha_sandstorm",
        name = "沙暴领域",
        cooldown = 999,                 -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.4,            -- 40%最大血量
        effect = "blind",
        effectDuration = 5.0,
        effectValue = 0.60,             -- 降低60%视野范围
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.5,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 7.0,
        warningColor = {200, 160, 30, 160},     -- 沙暴黄金
    }

end
