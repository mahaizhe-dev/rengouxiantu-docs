-- ============================================================================
-- MonsterData_Skills_ch5b.lua - 第五章技能定义（下）
-- 包含: 四仙剑BOSS(诛/陆/绝/戮) + 太虚宗主·司空玄胤
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    -- =====================================================================
    -- 第五章 · 四仙剑 BOSS 技能（28 skills = 7 × 4 swords）
    -- 每把剑：4常规 + 1转阶段 + 1 P2核心 + 1 P3场地
    -- 所有四仙剑为 stationary BOSS，地刺普攻由 groundSpike 配置实现
    -- =====================================================================

    -- ─────────────────────────────────────────────
    -- ① 诛仙剑（Zhu）—— 斩线处决、快节奏
    -- ─────────────────────────────────────────────

    --- P1常规：一字诛线（正前超长直线）
    M.Skills.ch5_zhu_line = {
        id = "ch5_zhu_line",
        name = "一字诛线",
        cooldown = 4,
        damageMult = 2.5,
        castTime = 0.8,
        warningShape = "line",
        warningRange = 6.0,
        warningLineWidth = 0.6,
        warningColor = {220, 60, 40, 120},
    }

    --- P1常规：横天断命（宽横斩矩形）
    M.Skills.ch5_zhu_cross_slash = {
        id = "ch5_zhu_cross_slash",
        name = "横天断命",
        cooldown = 5,
        damageMult = 2.8,
        castTime = 0.9,
        warningShape = "rect",
        warningRectLength = 5.0,
        warningRectWidth = 2.0,
        warningColor = {220, 60, 40, 120},
    }

    --- P1常规：十字绝路（十字两段，第二段旋转45°）
    M.Skills.ch5_zhu_cross = {
        id = "ch5_zhu_cross",
        name = "十字绝路",
        cooldown = 7,
        damageMult = 2.2,
        castTime = 1.0,
        burstCount = 2,
        burstInterval = 0.5,
        burstRotation = 45,
        warningShape = "cross",
        warningRange = 5.0,
        warningCrossWidth = 0.8,
        warningColor = {220, 60, 40, 120},
    }

    --- P1常规：追命剑标（追踪3连圆，每段瞄准玩家）
    M.Skills.ch5_zhu_tracking = {
        id = "ch5_zhu_tracking",
        name = "追命剑标",
        cooldown = 6,
        damageMult = 2.0,
        castTime = 0.6,
        burstCount = 3,
        burstInterval = 0.6,
        burstTrack = true,
        warningShape = "circle",
        warningRange = 1.5,
        warningColor = {240, 80, 60, 130},
    }

    --- P2触发：剑宫鸣杀（三连纵斩 + 眩晕）
    M.Skills.ch5_zhu_transition = {
        id = "ch5_zhu_transition",
        name = "剑宫鸣杀",
        cooldown = 999,
        damageMult = 3.5,
        castTime = 1.5,
        burstCount = 3,
        burstInterval = 0.4,
        effect = "stun",
        effectDuration = 1.0,
        warningShape = "line",
        warningRange = 7.0,
        warningLineWidth = 1.0,
        warningColor = {240, 40, 40, 140},
    }

    --- P2核心：诛心归一（超宽十字斩 × 2段旋转90°）
    M.Skills.ch5_zhu_core = {
        id = "ch5_zhu_core",
        name = "诛心归一",
        cooldown = 10,
        damageMult = 4.0,
        castTime = 1.2,
        burstCount = 2,
        burstInterval = 0.5,
        burstRotation = 90,
        warningShape = "cross",
        warningRange = 7.0,
        warningCrossWidth = 1.2,
        warningColor = {250, 40, 40, 150},
    }

    --- P3触发：万剑归宗（field，全场剑气 + 窄安全区）
    M.Skills.ch5_zhu_field = {
        id = "ch5_zhu_field",
        name = "万剑归宗",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.6,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {220, 40, 40, 160},
    }

    -- ─────────────────────────────────────────────
    -- ② 陷仙剑（Xian）—— 冰镜折返、减速迟滞
    -- ─────────────────────────────────────────────

    --- P1常规：霜环迟行（扩散寒环 + 减速）
    M.Skills.ch5_xian_frost_ring = {
        id = "ch5_xian_frost_ring",
        name = "霜环迟行",
        cooldown = 5,
        damageMult = 1.8,
        castTime = 0.7,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.5,
        warningShape = "circle",
        warningRange = 4.0,
        warningColor = {40, 60, 220, 120},
    }

    --- P1常规：镜面反斩（线 × 2段，第二段旋转120°模拟折返）
    M.Skills.ch5_xian_mirror_slash = {
        id = "ch5_xian_mirror_slash",
        name = "镜面反斩",
        cooldown = 5,
        damageMult = 2.5,
        castTime = 0.8,
        burstCount = 2,
        burstInterval = 0.7,
        burstRotation = 120,
        warningShape = "line",
        warningRange = 6.0,
        warningLineWidth = 0.6,
        warningColor = {60, 80, 240, 120},
    }

    --- P1常规：冰牢点名（prison，玩家须逃离）
    M.Skills.ch5_xian_ice_prison = {
        id = "ch5_xian_ice_prison",
        name = "冰牢点名",
        cooldown = 8,
        damageMult = 0,
        isPrisonSkill = true,
        prisonRadius = 1.0,
        prisonEscapeTime = 1.5,
        prisonDamagePercent = 0.35,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {100, 140, 255, 140},
    }

    --- P1常规：千镜回锋（4段依次旋转90°的直线）
    M.Skills.ch5_xian_mirror_barrage = {
        id = "ch5_xian_mirror_barrage",
        name = "千镜回锋",
        cooldown = 7,
        damageMult = 2.0,
        castTime = 0.6,
        burstCount = 4,
        burstInterval = 0.5,
        burstRotation = 90,
        warningShape = "line",
        warningRange = 5.0,
        warningLineWidth = 0.5,
        warningColor = {80, 100, 255, 120},
    }

    --- P2触发：寒台翻镜（大范围寒环 + 强减速）
    M.Skills.ch5_xian_transition = {
        id = "ch5_xian_transition",
        name = "寒台翻镜",
        cooldown = 999,
        damageMult = 2.5,
        castTime = 1.5,
        effect = "slow",
        effectDuration = 4.0,
        effectValue = 0.6,
        warningShape = "circle",
        warningRange = 6.0,
        warningColor = {60, 80, 240, 140},
    }

    --- P2核心：万镜同坠（十字 × 3段旋转30°+ 减速）
    M.Skills.ch5_xian_core = {
        id = "ch5_xian_core",
        name = "万镜同坠",
        cooldown = 10,
        damageMult = 3.0,
        castTime = 1.0,
        burstCount = 3,
        burstInterval = 0.6,
        burstRotation = 30,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.4,
        warningShape = "cross",
        warningRange = 6.0,
        warningCrossWidth = 0.8,
        warningColor = {40, 60, 220, 140},
    }

    --- P3触发：寒镜灭界（field，全场寒气 + 安全区）
    M.Skills.ch5_xian_field = {
        id = "ch5_xian_field",
        name = "寒镜灭界",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.5,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {40, 60, 220, 160},
    }

    -- ─────────────────────────────────────────────
    -- ③ 戮仙剑（Lu）—— 地火焚场、空间切割
    -- ─────────────────────────────────────────────

    --- P1常规：地火喷口（追踪3连圆 + 灼烧）
    M.Skills.ch5_lu_fire_vent = {
        id = "ch5_lu_fire_vent",
        name = "地火喷口",
        cooldown = 5,
        damageMult = 2.0,
        castTime = 0.7,
        burstCount = 3,
        burstInterval = 0.5,
        burstTrack = true,
        effect = "burn",
        effectDuration = 2.0,
        effectValue = 0.4,
        warningShape = "circle",
        warningRange = 2.0,
        warningColor = {40, 180, 40, 120},
    }

    --- P1常规：熔环外推（大圈火环 + 灼烧）
    M.Skills.ch5_lu_fire_ring = {
        id = "ch5_lu_fire_ring",
        name = "熔环外推",
        cooldown = 6,
        damageMult = 2.2,
        castTime = 0.8,
        effect = "burn",
        effectDuration = 2.5,
        effectValue = 0.3,
        warningShape = "circle",
        warningRange = 4.5,
        warningColor = {60, 200, 40, 120},
    }

    --- P1常规：落焰剑雨（追踪4连小圆 + 灼烧）
    M.Skills.ch5_lu_sword_rain = {
        id = "ch5_lu_sword_rain",
        name = "落焰剑雨",
        cooldown = 6,
        damageMult = 1.8,
        castTime = 0.5,
        burstCount = 4,
        burstInterval = 0.4,
        burstTrack = true,
        effect = "burn",
        effectDuration = 1.5,
        effectValue = 0.3,
        warningShape = "circle",
        warningRange = 1.8,
        warningColor = {80, 220, 40, 120},
    }

    --- P1常规：断桥熔线（十字熔线 + 强灼烧）
    M.Skills.ch5_lu_melt_line = {
        id = "ch5_lu_melt_line",
        name = "断桥熔线",
        cooldown = 7,
        damageMult = 2.5,
        castTime = 1.0,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.5,
        warningShape = "cross",
        warningRange = 6.0,
        warningCrossWidth = 0.7,
        warningColor = {40, 180, 40, 120},
    }

    --- P2触发：炉心崩裂（大范围火爆 + 强灼烧）
    M.Skills.ch5_lu_transition = {
        id = "ch5_lu_transition",
        name = "炉心崩裂",
        cooldown = 999,
        damageMult = 3.0,
        castTime = 1.5,
        effect = "burn",
        effectDuration = 4.0,
        effectValue = 0.6,
        warningShape = "circle",
        warningRange = 5.0,
        warningColor = {60, 200, 40, 140},
    }

    --- P2核心：八荒焚路（十字 × 2段旋转45°= 八向 + 灼烧）
    M.Skills.ch5_lu_core = {
        id = "ch5_lu_core",
        name = "八荒焚路",
        cooldown = 10,
        damageMult = 3.5,
        castTime = 1.2,
        burstCount = 2,
        burstInterval = 0.5,
        burstRotation = 45,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.5,
        warningShape = "cross",
        warningRange = 7.0,
        warningCrossWidth = 0.6,
        warningColor = {40, 180, 40, 140},
    }

    --- P3触发：焚天灭世（field，全场火海 + 安全区）
    M.Skills.ch5_lu_field = {
        id = "ch5_lu_field",
        name = "焚天灭世",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.5,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {40, 200, 40, 160},
    }

    -- ─────────────────────────────────────────────
    -- ④ 绝仙剑（Jue）—— 蚀血禁疗、血线压迫
    -- ─────────────────────────────────────────────

    --- P1常规：吸血锁链（锥形 + 灼烧DoT模拟吸血）
    M.Skills.ch5_jue_blood_chain = {
        id = "ch5_jue_blood_chain",
        name = "吸血锁链",
        cooldown = 5,
        damageMult = 2.0,
        castTime = 0.7,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.5,
        warningShape = "cone",
        warningRange = 4.0,
        warningConeAngle = 60,
        warningColor = {180, 40, 180, 120},
    }

    --- P1常规：蚀心剑印（脚下圆 + 中毒DoT）
    M.Skills.ch5_jue_blood_mark = {
        id = "ch5_jue_blood_mark",
        name = "蚀心剑印",
        cooldown = 6,
        damageMult = 2.2,
        castTime = 0.6,
        effect = "poison",
        effectDuration = 4.0,
        effectValue = 0.4,
        warningShape = "circle",
        warningRange = 2.0,
        warningColor = {200, 60, 200, 120},
    }

    --- P1常规：禁疗血雾（大圆减速区模拟禁疗）
    M.Skills.ch5_jue_blood_mist = {
        id = "ch5_jue_blood_mist",
        name = "禁疗血雾",
        cooldown = 7,
        damageMult = 1.5,
        castTime = 0.8,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.4,
        warningShape = "circle",
        warningRange = 3.5,
        warningColor = {160, 40, 160, 120},
    }

    --- P1常规：压血断生（高伤直线重斩）
    M.Skills.ch5_jue_blood_slash = {
        id = "ch5_jue_blood_slash",
        name = "压血断生",
        cooldown = 6,
        damageMult = 3.5,
        castTime = 0.9,
        warningShape = "line",
        warningRange = 5.0,
        warningLineWidth = 1.0,
        warningColor = {200, 60, 200, 120},
    }

    --- P2触发：血池倒灌（大范围血浪 + 中毒）
    M.Skills.ch5_jue_transition = {
        id = "ch5_jue_transition",
        name = "血池倒灌",
        cooldown = 999,
        damageMult = 2.5,
        castTime = 1.5,
        effect = "poison",
        effectDuration = 5.0,
        effectValue = 0.5,
        warningShape = "circle",
        warningRange = 6.0,
        warningColor = {180, 40, 180, 140},
    }

    --- P2核心：绝命蚀界（追踪3连圆 + 强中毒）
    M.Skills.ch5_jue_core = {
        id = "ch5_jue_core",
        name = "绝命蚀界",
        cooldown = 10,
        damageMult = 2.8,
        castTime = 0.8,
        burstCount = 3,
        burstInterval = 0.5,
        burstTrack = true,
        effect = "poison",
        effectDuration = 3.0,
        effectValue = 0.6,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {180, 40, 180, 140},
    }

    --- P3触发：蚀界天劫（field，全场血雾 + 安全区）
    M.Skills.ch5_jue_field = {
        id = "ch5_jue_field",
        name = "蚀界天劫",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.5,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {200, 40, 200, 160},
    }

    -- ===================== 太虚宗主·司空玄胤（诛仙阵图神器BOSS） =====================

    --- P1常规：诛仙剑雨（4方向追踪剑柱 + 弱减速）
    M.Skills.ch5_zhentu_sword_rain = {
        id = "ch5_zhentu_sword_rain",
        name = "诛仙剑雨",
        cooldown = 6,
        damageMult = 1.8,
        castTime = 0.5,
        burstCount = 4,
        burstInterval = 0.35,
        burstTrack = true,
        effect = "slow",
        effectDuration = 1.5,
        effectValue = 0.25,
        warningShape = "circle",
        warningRange = 1.8,
        warningColor = {100, 60, 200, 120},
    }

    --- P1常规：太虚裂斩（十字+斜十字双重十字，短硬直）
    M.Skills.ch5_zhentu_void_slash = {
        id = "ch5_zhentu_void_slash",
        name = "太虚裂斩",
        cooldown = 7,
        damageMult = 2.6,
        castTime = 0.8,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.35,
        warningShape = "cross",
        warningRange = 5.5,
        warningCrossWidth = 0.8,
        warningRotation = 45,
        warningColor = {120, 50, 220, 120},
    }

    --- P2触发：阵法封锁（大圆 + 禁闭效果，过场一次性）
    M.Skills.ch5_zhentu_formation_lock = {
        id = "ch5_zhentu_formation_lock",
        name = "阵法封锁",
        cooldown = 999,
        damageMult = 2.0,
        castTime = 1.2,
        effect = "slow",
        effectDuration = 4.0,
        effectValue = 0.55,
        warningShape = "circle",
        warningRange = 6.0,
        warningColor = {80, 40, 200, 140},
    }

    --- P2核心：虚空崩塌（3连追踪圆 + 减速叠加）
    M.Skills.ch5_zhentu_collapse = {
        id = "ch5_zhentu_collapse",
        name = "虚空崩塌",
        cooldown = 999,
        damageMult = 2.5,
        castTime = 1.5,
        burstCount = 3,
        burstInterval = 0.6,
        burstTrack = true,
        effect = "slow",
        effectDuration = 3.5,
        effectValue = 0.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {100, 50, 220, 150},
    }

    --- P3触发：四剑诛灭（field，全场剑阵 + 安全角落，一次性终极）
    M.Skills.ch5_zhentu_annihilation = {
        id = "ch5_zhentu_annihilation",
        name = "四剑诛灭",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.5,
        isFieldSkill = true,
        safeZoneCount = 4,
        safeZoneRadius = 0.6,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 9.0,
        warningColor = {80, 30, 200, 180},
    }

    --- P1：一字诛线（向正前方超长直线剑气，低延迟高伤害）
    M.Skills.ch5_zhentu_sword_line = {
        id = "ch5_zhentu_sword_line",
        name = "一字诛线",
        cooldown = 5,
        damageMult = 2.2,
        castTime = 0.4,
        warningShape = "line",
        warningRange = 9.0,
        warningWidth = 0.6,
        warningColor = {120, 60, 200, 140},
    }

    --- P1：寒镜回锋（剑光折返，折返段延迟明显）
    M.Skills.ch5_zhentu_mirror_blade = {
        id = "ch5_zhentu_mirror_blade",
        name = "寒镜回锋",
        cooldown = 7,
        damageMult = 1.6,
        castTime = 0.6,
        bounceCount = 1,
        bounceDelay = 0.8,
        warningShape = "line",
        warningRange = 6.0,
        warningWidth = 0.5,
        warningColor = {100, 140, 200, 120},
    }

    --- P1：熔环外推（以Boss为中心外扩火环，留灼地）
    M.Skills.ch5_zhentu_fire_ring = {
        id = "ch5_zhentu_fire_ring",
        name = "熔环外推",
        cooldown = 8,
        damageMult = 1.4,
        castTime = 0.7,
        effect = "burn",
        effectDuration = 2.0,
        effectValue = 0.15,
        isExpandRing = true,
        expandSpeed = 3.5,
        warningShape = "ring",
        warningRange = 5.0,
        warningRingWidth = 0.8,
        warningColor = {200, 80, 40, 130},
    }

    --- P1：禁疗血雾（指定区域血雾，降低治疗效果）
    M.Skills.ch5_zhentu_blood_mist = {
        id = "ch5_zhentu_blood_mist",
        name = "禁疗血雾",
        cooldown = 9,
        damageMult = 0.8,
        castTime = 0.8,
        effect = "healReduction",
        effectDuration = 5.0,
        effectValue = 0.7,
        isZoneSkill = true,
        zoneDuration = 5.0,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {160, 40, 60, 110},
    }

    --- P1：连式·诛线（连续3次窄版一字诛线，间隔0.35秒，角度微偏）
    M.Skills.ch5_zhentu_chain_slash = {
        id = "ch5_zhentu_chain_slash",
        name = "连式·诛线",
        cooldown = 12,
        damageMult = 1.5,
        castTime = 0.3,
        burstCount = 3,
        burstInterval = 0.35,
        burstAngleSpread = 12,
        warningShape = "line",
        warningRange = 7.0,
        warningWidth = 0.4,
        warningColor = {130, 60, 210, 120},
    }

    --- P2转阶段：血池灌体（宗主悬空，血池翻涌，获得满层养剑）
    M.Skills.ch5_zhentu_blood_surge = {
        id = "ch5_zhentu_blood_surge",
        name = "血池灌体",
        cooldown = 999,
        damageMult = 0,
        castTime = 1.5,
        isPhaseSkill = true,
        effect = "knockback",
        effectValue = 3.0,
        warningShape = "circle",
        warningRange = 4.0,
        warningColor = {160, 30, 50, 140},
    }

    --- P2：吸血锁链（血链吸血，离开范围可挣断）
    M.Skills.ch5_zhentu_drain_chain = {
        id = "ch5_zhentu_drain_chain",
        name = "吸血锁链",
        cooldown = 10,
        damageMult = 1.2,
        castTime = 0.5,
        effect = "drain",
        effectDuration = 3.5,
        effectValue = 0.08,
        isLeash = true,
        leashBreakRange = 4.0,
        warningShape = "line",
        warningRange = 4.5,
        warningWidth = 0.4,
        warningColor = {150, 20, 50, 130},
    }

    --- P2：十字绝路（先纵后横，两次交叉斩线）
    M.Skills.ch5_zhentu_cross_slash = {
        id = "ch5_zhentu_cross_slash",
        name = "十字绝路",
        cooldown = 8,
        damageMult = 2.0,
        castTime = 0.6,
        burstCount = 2,
        burstInterval = 0.4,
        warningShape = "cross",
        warningRange = 6.0,
        warningCrossWidth = 0.7,
        warningColor = {120, 50, 210, 130},
    }

    --- P2：四式归宗（连续4段缩短版技能，满养剑层则强化）
    M.Skills.ch5_zhentu_four_combo = {
        id = "ch5_zhentu_four_combo",
        name = "四式归宗",
        cooldown = 15,
        damageMult = 1.8,
        castTime = 0.5,
        burstCount = 4,
        burstInterval = 0.3,
        isComboSkill = true,
        comboSkills = { "ch5_zhentu_sword_line", "ch5_zhentu_mirror_blade", "ch5_zhentu_fire_ring", "ch5_zhentu_blood_mist" },
        warningShape = "circle",
        warningRange = 4.0,
        warningColor = {140, 50, 200, 140},
    }

    --- P3转阶段：入魔归宗（强制击退，血池扩大3秒，直接进归宗态）
    M.Skills.ch5_zhentu_demonic_surge = {
        id = "ch5_zhentu_demonic_surge",
        name = "入魔归宗",
        cooldown = 999,
        damageMult = 0,
        castTime = 2.0,
        isPhaseSkill = true,
        effect = "knockback",
        effectValue = 5.0,
        isFieldSkill = true,
        zoneDuration = 3.0,
        warningShape = "circle",
        warningRange = 7.0,
        warningColor = {100, 20, 180, 160},
    }

    --- P3：八荒焚路（多方向熔线，大面积灼烧带）
    M.Skills.ch5_zhentu_eight_burn = {
        id = "ch5_zhentu_eight_burn",
        name = "八荒焚路",
        cooldown = 11,
        damageMult = 1.6,
        castTime = 0.8,
        effect = "burn",
        effectDuration = 4.0,
        effectValue = 0.2,
        burstCount = 8,
        burstAngleSpread = 360,
        warningShape = "line",
        warningRange = 7.0,
        warningWidth = 0.5,
        warningColor = {200, 70, 30, 130},
    }

    --- P3：绝命蚀界（全场血界，仅保留少量安全点）
    M.Skills.ch5_zhentu_dread_zone = {
        id = "ch5_zhentu_dread_zone",
        name = "绝命蚀界",
        cooldown = 18,
        damageMult = 0,
        damagePercent = 0.2,
        castTime = 1.0,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.7,
        zoneDuration = 4.0,
        warningShape = "circle",
        warningRange = 9.0,
        warningColor = {90, 20, 160, 170},
    }

    --- P3终结：万剑归宗（依次四段强化技能连锁，最后补大范围竖斩）
    M.Skills.ch5_zhentu_ultimate = {
        id = "ch5_zhentu_ultimate",
        name = "万剑归宗",
        cooldown = 45,
        damageMult = 2.5,
        castTime = 1.2,
        burstCount = 5,
        burstInterval = 0.5,
        isUltimate = true,
        warningShape = "circle",
        warningRange = 9.0,
        warningColor = {80, 20, 200, 190},
    }
end
