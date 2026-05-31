-- ============================================================================
-- MonsterData_Skills_ch5a.lua - 第五章技能定义（上）
-- 包含: 精英怪 + 七大emperor_boss + 镇渊魔帅
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    -- =====================================================================
    --                     第五章 · 太虚宗废墟技能
    -- =====================================================================

    -- ===================== 精英怪技能（6个，各1个） =====================

    --- 残影剑灵 — 残影剑刺（line，快速直线突刺）
    M.Skills.ch5_shadow_thrust = {
        id = "ch5_shadow_thrust",
        name = "残影剑刺",
        cooldown = 5,
        damageMult = 2.0,
        effect = nil,
        castTime = 0.5,
        warningShape = "line",
        warningRange = 4.0,
        warningLineWidth = 0.5,
        warningColor = {180, 160, 220, 100},    -- 幽紫
    }

    --- 寒池冰龟 — 寒冰喷吐（cone + slow）
    M.Skills.ch5_frost_breath = {
        id = "ch5_frost_breath",
        name = "寒冰喷吐",
        cooldown = 6,
        damageMult = 1.8,
        effect = "slow",
        effectDuration = 2.5,
        effectValue = 0.35,                     -- 35% 减速
        castTime = 0.7,
        warningShape = "cone",
        warningRange = 3.0,
        warningConeAngle = 60,
        warningColor = {100, 200, 240, 100},    -- 冰蓝
    }

    --- 炉火锻兵 — 熔铁横扫（rect + knockback）
    M.Skills.ch5_molten_sweep = {
        id = "ch5_molten_sweep",
        name = "熔铁横扫",
        cooldown = 6,
        damageMult = 2.2,
        effect = "knockback",
        effectValue = 1.5,
        castTime = 0.8,
        warningShape = "rect",
        warningRange = 3.0,
        warningRectLength = 3.0,
        warningRectWidth = 1.8,
        warningColor = {240, 120, 40, 100},     -- 熔铁橙
    }

    --- 碑林剑魂 — 碑文剑气（cross，十字交叉封锁）
    M.Skills.ch5_stele_cross = {
        id = "ch5_stele_cross",
        name = "碑文剑气",
        cooldown = 7,
        damageMult = 2.0,
        effect = nil,
        castTime = 0.9,
        warningShape = "cross",
        warningRange = 3.5,
        warningCrossWidth = 0.7,
        warningColor = {160, 180, 200, 100},    -- 碑灰蓝
    }

    --- 月影夜卫 — 月影突刺（line，快速穿刺）
    M.Skills.ch5_moon_pierce = {
        id = "ch5_moon_pierce",
        name = "月影突刺",
        cooldown = 5,
        damageMult = 2.3,
        effect = nil,
        castTime = 0.5,
        warningShape = "line",
        warningRange = 4.5,
        warningLineWidth = 0.5,
        warningColor = {140, 160, 220, 100},    -- 月蓝
    }

    --- 墨毒书妖 — 墨毒弥散（circle + poison）
    M.Skills.ch5_ink_poison = {
        id = "ch5_ink_poison",
        name = "墨毒弥散",
        cooldown = 7,
        damageMult = 1.5,
        effect = "poison",
        effectDuration = 4.0,
        effectValue = 0.5,                      -- 每秒 0.5x 系数
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {60, 40, 80, 100},       -- 墨紫
    }

    -- ===================== 护山石傀（king_boss Lv.95）· 3技能 =====================
    -- 永久狂暴：3技能全部从开战可用，berserkBuff 常驻

    --- 山岩崩击（circle，大范围砸地）
    M.Skills.ch5_rock_smash = {
        id = "ch5_rock_smash",
        name = "山岩崩击",
        cooldown = 6,
        damageMult = 2.5,
        effect = "stun",
        effectDuration = 0.8,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {160, 140, 100, 120},    -- 岩土色
    }

    --- 碎石横飞（cone，前方扇形碎石弹射 + knockback）
    M.Skills.ch5_rock_scatter = {
        id = "ch5_rock_scatter",
        name = "碎石横飞",
        cooldown = 7,
        damageMult = 2.0,
        effect = "knockback",
        effectValue = 2.0,
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 3.0,
        warningConeAngle = 90,
        warningColor = {180, 160, 120, 120},    -- 砂石色
    }

    --- 山门镇压（rect，正面长条重压）
    M.Skills.ch5_gate_crush = {
        id = "ch5_gate_crush",
        name = "山门镇压",
        cooldown = 8,
        damageMult = 3.0,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.5,
        castTime = 1.2,
        warningShape = "rect",
        warningRange = 4.0,
        warningRectLength = 4.0,
        warningRectWidth = 1.5,
        warningColor = {140, 120, 80, 120},     -- 深岩色
    }

    -- ===================== 裂渊屠血将（king_boss Lv.120）· 3技能 =====================
    -- 2 基础 + 1 addSkill@50%

    --- 血刃横斩（rect，正面高伤矩形斩击）
    M.Skills.ch5_blood_cleave = {
        id = "ch5_blood_cleave",
        name = "血刃横斩",
        cooldown = 5,
        damageMult = 2.8,
        effect = nil,
        castTime = 0.7,
        warningShape = "rect",
        warningRange = 3.5,
        warningRectLength = 3.5,
        warningRectWidth = 1.5,
        warningColor = {220, 40, 40, 120},      -- 血红
    }

    --- 嗜血旋风（circle，中范围AOE + 吸血效果描述用burn代替）
    M.Skills.ch5_blood_whirl = {
        id = "ch5_blood_whirl",
        name = "嗜血旋风",
        cooldown = 7,
        damageMult = 2.2,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.4,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {200, 30, 30, 120},      -- 深血红
    }

    --- 血渊爆裂（P2 addSkill：cross，十字血线 + 高伤害）
    M.Skills.ch5_blood_eruption = {
        id = "ch5_blood_eruption",
        name = "血渊爆裂",
        cooldown = 9,
        damageMult = 3.5,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.4,
        castTime = 1.2,
        warningShape = "cross",
        warningRange = 4.0,
        warningCrossWidth = 0.8,
        warningColor = {240, 20, 20, 140},      -- 鲜红
    }

    -- ===================== 裴千岳（emperor_boss · 剑法广场）· 4技能 =====================
    -- 2 基础 + addSkill@70% + triggerSkill@30%

    --- 太虚剑诀（line，标志性直线剑气）
    M.Skills.ch5_pei_sword_qi = {
        id = "ch5_pei_sword_qi",
        name = "太虚剑诀",
        cooldown = 6,
        damageMult = 2.5,
        effect = nil,
        castTime = 0.6,
        warningShape = "line",
        warningRange = 5.0,
        warningLineWidth = 0.6,
        warningColor = {100, 180, 240, 120},    -- 剑意蓝
    }

    --- 裂空斩（rect，宽矩形横斩）
    M.Skills.ch5_pei_sky_slash = {
        id = "ch5_pei_sky_slash",
        name = "裂空斩",
        cooldown = 8,
        damageMult = 2.8,
        effect = "knockback",
        effectValue = 1.5,
        castTime = 0.9,
        warningShape = "rect",
        warningRange = 3.5,
        warningRectLength = 3.5,
        warningRectWidth = 2.0,
        warningColor = {80, 160, 220, 120},     -- 天蓝
    }

    --- P2追加：幻影剑阵（clone，召唤分身同时攻击）
    M.Skills.ch5_pei_phantom_sword = {
        id = "ch5_pei_phantom_sword",
        name = "幻影剑阵",
        cooldown = 12,
        damageMult = 2.0,
        effect = nil,
        isCloneSkill = true,
        cloneCount = 2,
        cloneHpPercent = 0.10,
        cloneAtkPercent = 0.30,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {120, 180, 240, 140},    -- 幻蓝
    }

    --- P3触发：千岳剑意·破灭（field，全场AOE + 安全区）
    M.Skills.ch5_pei_execution = {
        id = "ch5_pei_execution",
        name = "千岳剑意·破灭",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,                   -- 45% 最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.5,
        safeZoneMoving = false,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {60, 140, 220, 160},     -- 深剑蓝
    }

    -- ===================== 霜鸾（emperor_boss · 寒池）· 4技能 =====================

    --- 凝霜啄击（cone，前方冰锥 + slow）
    M.Skills.ch5_luan_frost_peck = {
        id = "ch5_luan_frost_peck",
        name = "凝霜啄击",
        cooldown = 6,
        damageMult = 2.5,
        effect = "slow",
        effectDuration = 2.5,
        effectValue = 0.35,
        castTime = 0.7,
        warningShape = "cone",
        warningRange = 3.0,
        warningConeAngle = 70,
        warningColor = {120, 200, 255, 120},    -- 霜蓝
    }

    --- 寒翼风暴（circle，大范围冰暴）
    M.Skills.ch5_luan_ice_storm = {
        id = "ch5_luan_ice_storm",
        name = "寒翼风暴",
        cooldown = 8,
        damageMult = 2.2,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.4,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {80, 180, 240, 120},     -- 冰风蓝
    }

    --- P2追加：冰棱监牢（prison，冰笼困锁玩家）
    M.Skills.ch5_luan_ice_prison = {
        id = "ch5_luan_ice_prison",
        name = "冰棱监牢",
        cooldown = 12,
        damageMult = 0,
        effect = nil,
        isPrisonSkill = true,
        prisonRadius = 1.0,
        prisonEscapeTime = 1.3,
        prisonDamagePercent = 0.40,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {140, 220, 255, 140},    -- 寒冰白蓝
    }

    --- P3触发：霜鸾绝唱（field，全场冰暴 + 安全区）
    M.Skills.ch5_luan_requiem = {
        id = "ch5_luan_requiem",
        name = "霜鸾绝唱",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.5,
        safeZoneMoving = true,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {60, 160, 240, 160},     -- 绝唱蓝
    }

    -- ===================== 韩百炼（emperor_boss · 锻造厅）· 4技能 =====================

    --- 炼狱锤击（circle，圆形重锤 + stun）
    M.Skills.ch5_han_forge_slam = {
        id = "ch5_han_forge_slam",
        name = "炼狱锤击",
        cooldown = 6,
        damageMult = 2.8,
        effect = "stun",
        effectDuration = 0.8,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {240, 80, 20, 120},      -- 铁火红
    }

    --- 火龙卷（rect，前方烈焰矩形 + burn）
    M.Skills.ch5_han_flame_roll = {
        id = "ch5_han_flame_roll",
        name = "火龙卷",
        cooldown = 7,
        damageMult = 2.2,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.5,
        castTime = 0.9,
        warningShape = "rect",
        warningRange = 3.5,
        warningRectLength = 3.5,
        warningRectWidth = 1.5,
        warningColor = {255, 100, 20, 120},     -- 烈焰橙
    }

    --- P2追加：百炼分身（clone，锻造分身锤击）
    M.Skills.ch5_han_forge_clone = {
        id = "ch5_han_forge_clone",
        name = "百炼分身",
        cooldown = 12,
        damageMult = 1.8,
        effect = nil,
        isCloneSkill = true,
        cloneCount = 2,
        cloneHpPercent = 0.10,
        cloneAtkPercent = 0.30,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {200, 60, 20, 140},      -- 暗火红
    }

    --- P3触发：天炉焚灭（field，全场火海 + 安全区）
    M.Skills.ch5_han_inferno = {
        id = "ch5_han_inferno",
        name = "天炉焚灭",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.6,
        safeZoneMoving = false,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {220, 40, 10, 160},      -- 炉火深红
    }

    -- ===================== 石观澜（emperor_boss · 碑林）· 4技能 =====================

    --- 万碑剑雨（cross，十字碑文剑气）
    M.Skills.ch5_shi_stele_rain = {
        id = "ch5_shi_stele_rain",
        name = "万碑剑雨",
        cooldown = 7,
        damageMult = 2.5,
        effect = nil,
        castTime = 0.8,
        warningShape = "cross",
        warningRange = 3.5,
        warningCrossWidth = 0.8,
        warningColor = {160, 170, 190, 120},    -- 碑灰
    }

    --- 碑铭震荡（circle，中范围圆形 + stun）
    M.Skills.ch5_shi_stele_shock = {
        id = "ch5_shi_stele_shock",
        name = "碑铭震荡",
        cooldown = 8,
        damageMult = 2.2,
        effect = "stun",
        effectDuration = 1.0,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.8,
        warningColor = {140, 150, 180, 120},    -- 石蓝灰
    }

    --- P2追加：碑林幻阵（clone，分裂碑影）
    M.Skills.ch5_shi_stele_clone = {
        id = "ch5_shi_stele_clone",
        name = "碑林幻阵",
        cooldown = 12,
        damageMult = 1.8,
        effect = nil,
        isCloneSkill = true,
        cloneCount = 3,
        cloneHpPercent = 0.08,
        cloneAtkPercent = 0.25,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {120, 140, 170, 140},    -- 幻碑灰蓝
    }

    --- P3触发：万碑归一（field，全场碑文共鸣 + 安全区）
    M.Skills.ch5_shi_convergence = {
        id = "ch5_shi_convergence",
        name = "万碑归一",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.5,
        safeZoneMoving = true,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {100, 120, 160, 160},    -- 碑文深蓝
    }

    -- ===================== 宁栖梧（emperor_boss · 别院）· 4技能 =====================

    --- 枯木逢春（line，直线剑气，枯与荣的转化）
    M.Skills.ch5_ning_dead_bloom = {
        id = "ch5_ning_dead_bloom",
        name = "枯木逢春",
        cooldown = 6,
        damageMult = 2.8,
        effect = nil,
        castTime = 0.6,
        warningShape = "line",
        warningRange = 5.0,
        warningLineWidth = 0.6,
        warningColor = {80, 180, 60, 120},      -- 枯绿
    }

    --- 落叶纷飞（cone，前方扇形叶刃 + slow）
    M.Skills.ch5_ning_leaf_blade = {
        id = "ch5_ning_leaf_blade",
        name = "落叶纷飞",
        cooldown = 7,
        damageMult = 2.2,
        effect = "slow",
        effectDuration = 2.5,
        effectValue = 0.35,
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 3.0,
        warningConeAngle = 80,
        warningColor = {120, 160, 40, 120},     -- 秋叶黄绿
    }

    --- P2追加：梧桐困锁（prison，枯木之笼困锁玩家）
    M.Skills.ch5_ning_wood_prison = {
        id = "ch5_ning_wood_prison",
        name = "梧桐困锁",
        cooldown = 12,
        damageMult = 0,
        effect = nil,
        isPrisonSkill = true,
        prisonRadius = 1.0,
        prisonEscapeTime = 1.3,
        prisonDamagePercent = 0.40,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {60, 140, 40, 140},      -- 枯木深绿
    }

    --- P3触发：千年枯荣（field，全场枯荣交替 + 安全区）
    M.Skills.ch5_ning_withering = {
        id = "ch5_ning_withering",
        name = "千年枯荣",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.50,                   -- 50% 最大血量（高难）
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.5,
        safeZoneMoving = true,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {40, 120, 30, 160},      -- 深枯绿
    }

    -- ===================== 温素章（emperor_boss · 藏经阁）· 4技能 =====================

    --- 万卷飞书（rect，矩形书页弹射 + poison）
    M.Skills.ch5_wen_book_barrage = {
        id = "ch5_wen_book_barrage",
        name = "万卷飞书",
        cooldown = 6,
        damageMult = 2.5,
        effect = "poison",
        effectDuration = 3.0,
        effectValue = 0.4,
        castTime = 0.7,
        warningShape = "rect",
        warningRange = 4.0,
        warningRectLength = 4.0,
        warningRectWidth = 1.5,
        warningColor = {80, 60, 120, 120},      -- 墨紫
    }

    --- 禁卷·灵文爆（circle，圆形灵文爆发 + stun）
    M.Skills.ch5_wen_rune_blast = {
        id = "ch5_wen_rune_blast",
        name = "禁卷·灵文爆",
        cooldown = 8,
        damageMult = 2.8,
        effect = "stun",
        effectDuration = 1.0,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {120, 80, 160, 120},     -- 灵文紫
    }

    --- P2追加：墨影分身（clone，书妖幻影分身）
    M.Skills.ch5_wen_ink_clone = {
        id = "ch5_wen_ink_clone",
        name = "墨影分身",
        cooldown = 12,
        damageMult = 1.5,
        effect = nil,
        isCloneSkill = true,
        cloneCount = 3,
        cloneHpPercent = 0.08,
        cloneAtkPercent = 0.25,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {60, 40, 100, 140},      -- 暗墨紫
    }

    --- P3触发：禁典·万灵归墟（field，全场灵文暴走 + 安全区）
    M.Skills.ch5_wen_forbidden = {
        id = "ch5_wen_forbidden",
        name = "禁典·万灵归墟",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.50,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.5,
        safeZoneMoving = false,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {80, 40, 140, 160},      -- 禁典深紫
    }

    -- ===================== 噬渊血犼（emperor_boss · 镇魔深渊）· 4技能 =====================

    --- 深渊噬咬（cone，前方大角度撕咬 + burn）
    -- =====================================================================
    -- 第五章 · 镇渊魔帅 技能
    -- 噬渊血犼（emperor_boss） / 蚀骨（emperor_boss） / 裂魂（emperor_boss）
    -- 共享：ch5_abyss_roar / ch5_abyss_prison / ch5_abyss_annihilation
    -- 差异：1技能各不同；P3各增加一个顺时针十字斩
    -- =====================================================================

    --- 噬渊血犼·1技能：深渊噬咬（宽扇形120° + 燃烧）
    M.Skills.ch5_abyss_devour = {
        id = "ch5_abyss_devour",
        name = "深渊噬咬",
        cooldown = 5,
        damageMult = 3.0,
        effect = "burn",
        effectDuration = 2.5,
        effectValue = 0.5,
        castTime = 0.7,
        warningShape = "cone",
        warningRange = 4.0,
        warningConeAngle = 120,
        warningColor = {160, 20, 60, 120},      -- 深渊红
    }

    --- 蚀骨·1技能：腐骨穿刺（直线穿刺 + 减速）
    M.Skills.ch5_shugu_pierce = {
        id = "ch5_shugu_pierce",
        name = "腐骨穿刺",
        cooldown = 5,
        damageMult = 3.0,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.5,                      -- 移速降低50%
        castTime = 0.6,
        warningShape = "line",
        warningRange = 5.0,
        warningLineWidth = 0.8,
        warningColor = {100, 20, 140, 130},     -- 蚀骨紫
    }

    --- 裂魂·1技能：裂魂弧斩（宽矩形×2段，第二段旋转45°）
    M.Skills.ch5_liesoul_arc = {
        id = "ch5_liesoul_arc",
        name = "裂魂弧斩",
        cooldown = 5,
        damageMult = 2.8,
        castTime = 0.8,
        burstCount = 2,
        burstInterval = 0.45,
        burstRotation = 45,
        warningShape = "rect",
        warningRectLength = 5.0,
        warningRectWidth = 2.5,
        warningColor = {60, 60, 180, 130},      -- 裂魂蓝
    }

    --- 共享：血犼震吼（全场圆形AOE + 击退，范围5格）
    M.Skills.ch5_abyss_roar = {
        id = "ch5_abyss_roar",
        name = "血犼震吼",
        cooldown = 7,
        damageMult = 2.5,
        effect = "knockback",
        effectValue = 2.0,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 5.0,
        warningColor = {180, 30, 40, 120},      -- 血犼红
    }

    --- P2追加：深渊囚笼（prison，魔气困锁）
    M.Skills.ch5_abyss_prison = {
        id = "ch5_abyss_prison",
        name = "深渊囚笼",
        cooldown = 12,
        damageMult = 0,
        effect = nil,
        isPrisonSkill = true,
        prisonRadius = 1.0,
        prisonEscapeTime = 1.2,
        prisonDamagePercent = 0.45,             -- 45%（高于ch4）
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {140, 10, 40, 140},      -- 深渊暗红
    }

    --- P3触发：噬天灭地（field，全场深渊吞噬 + 安全区）
    M.Skills.ch5_abyss_annihilation = {
        id = "ch5_abyss_annihilation",
        name = "噬天灭地",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.50,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.5,
        safeZoneMoving = true,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {120, 10, 30, 160},      -- 终焉暗红
    }

    --- P3追加：噬渊血犼·渊狱十字斩（十字形×3段顺时针旋转，每段30°）
    M.Skills.ch5_abyss_cross_slash = {
        id = "ch5_abyss_cross_slash",
        name = "渊狱十字斩",
        cooldown = 15,
        damageMult = 3.5,
        castTime = 1.0,
        burstCount = 3,
        burstInterval = 0.5,
        burstRotation = 30,                     -- 每段顺时针30°，三段共90°
        warningShape = "cross",
        warningRange = 5.0,
        warningCrossWidth = 1.0,
        warningColor = {160, 20, 60, 150},      -- 深渊红
    }

    --- P3追加：蚀骨·腐蚀十字斩（十字形×3段顺时针旋转，每段30°）
    M.Skills.ch5_shugu_cross_slash = {
        id = "ch5_shugu_cross_slash",
        name = "腐蚀十字斩",
        cooldown = 15,
        damageMult = 3.5,
        castTime = 1.0,
        burstCount = 3,
        burstInterval = 0.5,
        burstRotation = 30,                     -- 每段顺时针30°，三段共90°
        warningShape = "cross",
        warningRange = 5.0,
        warningCrossWidth = 1.0,
        warningColor = {100, 20, 140, 150},     -- 蚀骨紫
    }

    --- P3追加：裂魂·裂魂十字斩（十字形×3段顺时针旋转，每段30°）
    M.Skills.ch5_liesoul_cross_slash = {
        id = "ch5_liesoul_cross_slash",
        name = "裂魂十字斩",
        cooldown = 15,
        damageMult = 3.5,
        castTime = 1.0,
        burstCount = 3,
        burstInterval = 0.5,
        burstRotation = 30,                     -- 每段顺时针30°，三段共90°
        warningShape = "cross",
        warningRange = 5.0,
        warningCrossWidth = 1.0,
        warningColor = {60, 60, 180, 150},      -- 裂魂蓝
    }

end
