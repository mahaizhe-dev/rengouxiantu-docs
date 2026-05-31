-- ============================================================================
-- MonsterData_Skills_ch4.lua - 第四章技能定义
-- 包含: 封霜应龙 + 堕渊蛟龙 + 焚天蜃龙 + 蚀骨螭龙 + 八阵BOSS + 文王残影
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    -- ===================== 第四章·封霜应龙 专属技能 =====================
    M.Skills.frost_breath = {
        id = "frost_breath",
        name = "霜息吐纳",
        cooldown = 7,
        damageMult = 2.0,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.35,         -- 降低35%移速和攻速
        castTime = 1.0,
        warningShape = "cone",
        warningRange = 3.0,
        warningConeAngle = 80,
        warningColor = {140, 200, 240, 120},    -- 冰蓝
    }
    M.Skills.ice_prison = {
        id = "ice_prison",
        name = "玄冰囚笼",
        cooldown = 15,
        damageMult = 0,
        effect = nil,
        isPrisonSkill = true,
        prisonRadius = 1.0,
        prisonEscapeTime = 1.5,
        prisonDamagePercent = 0.35, -- 未逃脱伤害（35%最大血量）
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {100, 180, 240, 140},    -- 深冰蓝
    }
    M.Skills.permafrost_field = {
        id = "permafrost_field",
        name = "永霜封域",
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
        warningColor = {80, 160, 240, 160},     -- 极寒蓝
    }

    -- ===================== 第四章·堕渊蛟龙 专属技能 =====================
    M.Skills.abyss_roar = {
        id = "abyss_roar",
        name = "渊啸震魂",
        cooldown = 8,
        damageMult = 2.0,
        effect = "stun",
        effectDuration = 1.2,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {60, 30, 120, 120},      -- 深渊紫
    }
    M.Skills.abyss_venom = {
        id = "abyss_venom",
        name = "冥渊蚀毒",
        cooldown = 7,
        damageMult = 1.5,
        effect = "poison",
        effectDuration = 4,
        effectValue = 0.40,         -- 每秒40%ATK持续毒伤
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.5,
        warningConeAngle = 70,
        warningColor = {80, 50, 140, 100},      -- 渊毒紫
    }
    M.Skills.abyss_vortex_field = {
        id = "abyss_vortex_field",
        name = "冥渊吞噬",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.50,       -- 50%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {40, 20, 100, 160},      -- 冥渊深紫
    }

    -- ===================== 第四章·焚天蜃龙 专属技能 =====================
    M.Skills.dragon_flame = {
        id = "dragon_flame",
        name = "龙炎灭世",
        cooldown = 6,
        damageMult = 2.8,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.45,         -- 每秒45%ATK持续灼烧
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 3.0,
        warningConeAngle = 90,
        warningColor = {255, 80, 20, 120},      -- 龙炎红
    }
    M.Skills.inferno_ground = {
        id = "inferno_ground",
        name = "炼狱裂地",
        cooldown = 8,
        damageMult = 3.0,
        effect = nil,
        castTime = 1.0,
        warningShape = "cross",
        warningRange = 3.5,
        warningCrossWidth = 1.0,
        warningColor = {255, 120, 30, 140},     -- 熔岩橙
    }
    M.Skills.inferno_field = {
        id = "inferno_field",
        name = "焚天火海",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.55,       -- 55%最大血量（高攻BOSS补偿高伤场技）
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,          -- 仅2个安全区（高难度）
        safeZoneRadius = 0.6,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {255, 40, 10, 160},      -- 焚天红
    }

    -- ===================== 第四章·蚀骨螭龙 专属技能 =====================
    M.Skills.erosion_storm = {
        id = "erosion_storm",
        name = "蚀骨沙暴",
        cooldown = 7,
        damageMult = 1.8,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.30,         -- 降低30%移速和攻速
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {190, 170, 80, 120},     -- 蚀沙黄
    }
    M.Skills.sand_charge_dragon = {
        id = "sand_charge_dragon",
        name = "龙骨冲锋",
        cooldown = 6,
        damageMult = 2.5,
        effect = "knockback",
        effectValue = 2.0,
        castTime = 0.6,             -- 快速冲锋
        warningShape = "line",
        warningRange = 4.0,
        warningLineWidth = 1.0,
        warningColor = {200, 180, 60, 120},     -- 龙骨金
    }
    M.Skills.erosion_field = {
        id = "erosion_field",
        name = "蚀骨荒原",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.45,       -- 45%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        safeZoneMoving = true,      -- 安全区缓慢移动（增加难度）
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {180, 150, 40, 160},     -- 蚀骨黄
    }

    -- ===================== 第四章·八阵BOSS 专属技能 =====================

    -- === ①坎·沈渊衣（水系控制） ===
    M.Skills.kan_tidal_vortex = {
        id = "kan_tidal_vortex",
        name = "潮汐漩涡",
        cooldown = 8,
        damageMult = 1.5,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.35,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {60, 140, 220, 120},     -- 潮蓝
    }
    M.Skills.kan_water_blade = {
        id = "kan_water_blade",
        name = "水刃穿心",
        cooldown = 6,
        damageMult = 2.2,
        effect = nil,
        castTime = 0.8,
        warningShape = "line",
        warningRange = 3.5,
        warningLineWidth = 0.8,
        warningColor = {80, 160, 240, 120},     -- 水蓝
    }
    M.Skills.kan_whirlpool_prison = {
        id = "kan_whirlpool_prison",
        name = "漩涡牢笼",
        cooldown = 15,
        damageMult = 0,
        effect = nil,
        isPrisonSkill = true,
        prisonRadius = 1.0,
        prisonEscapeTime = 1.5,
        prisonDamagePercent = 0.30,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {40, 120, 200, 140},     -- 深水蓝
    }

    -- === ②艮·岩不动（土系坦克） ===
    M.Skills.gen_rock_slam = {
        id = "gen_rock_slam",
        name = "崩岩锤",
        cooldown = 8,
        damageMult = 2.5,
        effect = "stun",
        effectDuration = 1.0,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {160, 130, 60, 120},     -- 土黄
    }
    M.Skills.gen_stone_wall = {
        id = "gen_stone_wall",
        name = "石壁横推",
        cooldown = 7,
        damageMult = 2.0,
        effect = "knockback",
        effectValue = 2.0,
        castTime = 1.0,
        warningShape = "rect",
        warningRange = 2.5,
        warningRectLength = 2.5,
        warningRectWidth = 1.2,
        warningColor = {170, 140, 70, 120},     -- 岩土
    }
    M.Skills.gen_avalanche = {
        id = "gen_avalanche",
        name = "山崩地裂",
        cooldown = 10,
        damageMult = 2.8,
        effect = "stun",
        effectDuration = 1.2,
        castTime = 1.2,
        warningShape = "cross",
        warningRange = 3.0,
        warningCrossWidth = 1.0,
        warningColor = {180, 140, 50, 140},     -- 崩岩黄
    }

    -- === ③震·雷惊蛰（雷系爆发） ===
    M.Skills.zhen_thunder_pierce = {
        id = "zhen_thunder_pierce",
        name = "雷霆贯体",
        cooldown = 5,
        damageMult = 2.8,
        effect = nil,
        castTime = 0.6,
        warningShape = "line",
        warningRange = 4.0,
        warningLineWidth = 0.8,
        warningColor = {240, 220, 40, 120},     -- 雷金
    }
    M.Skills.zhen_thunder_roar = {
        id = "zhen_thunder_roar",
        name = "惊蛰雷鸣",
        cooldown = 9,
        damageMult = 2.0,
        effect = "stun",
        effectDuration = 1.0,
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {255, 240, 60, 120},     -- 亮雷黄
    }
    M.Skills.zhen_divine_thunder = {
        id = "zhen_divine_thunder",
        name = "九天雷罚",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.40,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {255, 230, 30, 160},     -- 雷罚金
    }

    -- === ④巽·风无痕（风系机动） ===
    M.Skills.xun_wind_slash = {
        id = "xun_wind_slash",
        name = "风刃乱舞",
        cooldown = 6,
        damageMult = 2.0,
        effect = nil,
        castTime = 0.6,
        warningShape = "cone",
        warningRange = 2.5,
        warningConeAngle = 80,
        warningColor = {100, 200, 160, 120},    -- 翠绿
    }
    M.Skills.xun_phantom_dash = {
        id = "xun_phantom_dash",
        name = "残影突袭",
        cooldown = 5,
        damageMult = 2.5,
        effect = nil,
        castTime = 0.5,
        warningShape = "line",
        warningRange = 4.0,
        warningLineWidth = 0.8,
        warningColor = {120, 210, 180, 120},    -- 风绿
    }
    M.Skills.xun_phantom_clone = {
        id = "xun_phantom_clone",
        name = "无痕分身",
        cooldown = 999,
        damageMult = 0,
        effect = nil,
        isCloneSkill = true,
        cloneCount = 2,
        cloneHpPercent = 0.12,
        cloneAtkPercent = 0.35,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {100, 190, 160, 120},    -- 幻风绿
    }

    -- === ⑤离·炎若晦（火系DOT） ===
    M.Skills.li_karma_fire = {
        id = "li_karma_fire",
        name = "业火焚身",
        cooldown = 6,
        damageMult = 1.5,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.45,
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 3.0,
        warningConeAngle = 90,
        warningColor = {255, 60, 20, 120},      -- 赤红
    }
    M.Skills.li_inferno_burst = {
        id = "li_inferno_burst",
        name = "炼狱爆裂",
        cooldown = 8,
        damageMult = 3.0,
        effect = nil,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.0,
        warningColor = {255, 100, 30, 120},     -- 橙红
    }
    M.Skills.li_heaven_fire = {
        id = "li_heaven_fire",
        name = "天火焚原",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {255, 80, 10, 160},      -- 天火红
    }

    -- === ⑥坤·厚德生（地系防御） ===
    M.Skills.kun_earth_surge = {
        id = "kun_earth_surge",
        name = "厚土翻涌",
        cooldown = 8,
        damageMult = 2.0,
        effect = "stun",
        effectDuration = 1.0,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {120, 90, 40, 120},      -- 深褐
    }
    M.Skills.kun_earth_sweep = {
        id = "kun_earth_sweep",
        name = "裂地横扫",
        cooldown = 7,
        damageMult = 2.2,
        effect = "knockback",
        effectValue = 1.5,
        castTime = 1.0,
        warningShape = "rect",
        warningRange = 3.0,
        warningRectLength = 3.0,
        warningRectWidth = 1.2,
        warningColor = {130, 100, 50, 120},     -- 泥褐
    }
    M.Skills.kun_earth_collapse = {
        id = "kun_earth_collapse",
        name = "坤土崩裂",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.40,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 4,
        safeZoneRadius = 0.6,
        castTime = 3.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {140, 110, 40, 160},     -- 崩土黄
    }

    -- === ⑦兑·泽归墟（毒系消耗） ===
    M.Skills.dui_gu_miasma = {
        id = "dui_gu_miasma",
        name = "蛊毒弥漫",
        cooldown = 7,
        damageMult = 1.0,
        effect = "poison",
        effectDuration = 4,
        effectValue = 0.45,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {60, 150, 40, 120},      -- 毒绿
    }
    M.Skills.dui_venom_line = {
        id = "dui_venom_line",
        name = "蚀骨毒线",
        cooldown = 6,
        damageMult = 2.0,
        effect = "poison",
        effectDuration = 3,
        effectValue = 0.30,
        castTime = 0.8,
        warningShape = "line",
        warningRange = 3.5,
        warningLineWidth = 0.8,
        warningColor = {80, 170, 50, 120},      -- 蛊绿
    }
    M.Skills.dui_gu_devour = {
        id = "dui_gu_devour",
        name = "万蛊噬心",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.45,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,
        safeZoneRadius = 0.6,
        safeZoneMoving = true,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {50, 130, 30, 160},      -- 噬心绿
    }

    -- === ⑧乾·司空正阳（全能终极人类BOSS） ===
    M.Skills.qian_gang_sword = {
        id = "qian_gang_sword",
        name = "天罡剑气",
        cooldown = 5,
        damageMult = 2.5,
        effect = nil,
        castTime = 0.7,
        warningShape = "line",
        warningRange = 4.0,
        warningLineWidth = 0.8,
        warningColor = {230, 220, 160, 120},    -- 金白
    }
    M.Skills.qian_taixu_palm = {
        id = "qian_taixu_palm",
        name = "太虚掌",
        cooldown = 8,
        damageMult = 2.0,
        effect = "stun",
        effectDuration = 1.0,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {240, 230, 170, 120},    -- 太虚金
    }
    M.Skills.qian_heaven_toss = {
        id = "qian_heaven_toss",
        name = "乾坤一掷",
        cooldown = 8,
        damageMult = 3.0,
        effect = "stun",
        effectDuration = 1.2,
        castTime = 1.0,
        warningShape = "cross",
        warningRange = 3.5,
        warningCrossWidth = 1.0,
        warningColor = {250, 240, 180, 140},    -- 乾坤金
    }
    M.Skills.qian_gang_annihilation = {
        id = "qian_gang_annihilation",
        name = "天罡灭阵",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.50,
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,
        safeZoneRadius = 0.5,
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {255, 240, 160, 160},    -- 天罡金
    }

    -- === 封霜应龙 新增P1技能 ===
    M.Skills.frost_crack = {
        id = "frost_crack",
        name = "寒冰裂地",
        cooldown = 8,
        damageMult = 2.5,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.30,
        castTime = 1.0,
        warningShape = "cross",
        warningRange = 3.0,
        warningCrossWidth = 0.8,
        warningColor = {120, 190, 240, 120},    -- 冰蓝十字
    }

    -- === 堕渊蛟龙 新增P2分身 ===
    M.Skills.abyss_clone = {
        id = "abyss_clone",
        name = "深渊分身",
        cooldown = 999,
        damageMult = 0,
        effect = nil,
        isCloneSkill = true,
        cloneCount = 3,
        cloneHpPercent = 0.10,
        cloneAtkPercent = 0.30,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {60, 30, 100, 120},      -- 深渊紫
    }

    -- === 焚天蜃龙 新增P2龙息 ===
    M.Skills.dragon_breath_sweep = {
        id = "dragon_breath_sweep",
        name = "龙息灭世",
        cooldown = 6,
        damageMult = 3.0,
        effect = "burn",
        effectDuration = 2.0,
        effectValue = 0.40,
        castTime = 0.8,
        warningShape = "rect",
        warningRange = 3.5,
        warningRectLength = 3.5,
        warningRectWidth = 1.5,
        warningColor = {255, 60, 10, 140},      -- 赤红宽矩
    }

    -- === 蚀骨螭龙 新增P2囚笼 ===
    M.Skills.sand_prison = {
        id = "sand_prison",
        name = "流沙囚笼",
        cooldown = 12,
        damageMult = 0,
        effect = nil,
        isPrisonSkill = true,
        prisonRadius = 1.0,
        prisonEscapeTime = 1.2,
        prisonDamagePercent = 0.40,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {200, 170, 60, 140},     -- 流沙金
    }

    -- === 文王残影（第四章神器BOSS）专属技能 ===

    -- 阴阳逆转：每10%血量触发的状态切换AOE
    M.Skills.wenwang_yinyang_reversal = {
        id = "wenwang_yinyang_reversal",
        name = "阴阳逆转",
        cooldown = 999,             -- 由阈值触发，不走常规CD
        damageMult = 0,
        damagePercent = 0.50,       -- 50%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,          -- 2个安全区
        safeZoneRadius = 0.6,
        castTime = 2.0,             -- 蓄力2秒给玩家跑位
        warningShape = "circle",
        warningRange = 8.0,         -- 覆盖整个竞技场
        warningColor = {180, 160, 80, 160},     -- 太极金
    }

    -- 阳仪态技能：乾天裂（快速高伤圆形砸击）
    M.Skills.wenwang_qian_split = {
        id = "wenwang_qian_split",
        name = "乾天裂",
        cooldown = 6,
        damageMult = 3.0,
        effect = nil,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {255, 200, 50, 120},     -- 阳金
    }

    -- 阳仪态技能：离火焚（前方矩形火焰 + 灼烧DOT）
    M.Skills.wenwang_li_blaze = {
        id = "wenwang_li_blaze",
        name = "离火焚",
        cooldown = 8,
        damageMult = 2.0,
        effect = "burn",
        effectDuration = 3.0,
        effectDamageMult = 1.0,     -- 灼烧3秒内额外1.0x系数
        castTime = 1.2,
        warningShape = "rect",
        warningRange = 3.0,
        warningRectLength = 3.0,
        warningRectWidth = 1.5,
        warningColor = {255, 120, 30, 120},     -- 离火橙
    }

    -- 阴仪态技能：坤地缚（大范围减速圆形）
    M.Skills.wenwang_kun_bind = {
        id = "wenwang_kun_bind",
        name = "坤地缚",
        cooldown = 7,
        damageMult = 1.5,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.50,         -- 减速50%
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {80, 120, 220, 120},     -- 阴蓝
    }

    -- 阴仪态技能：坎水寒（十字冰裂封锁走位）
    M.Skills.wenwang_kan_frost = {
        id = "wenwang_kan_frost",
        name = "坎水寒",
        cooldown = 9,
        damageMult = 2.0,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.40,         -- 减速40%
        castTime = 1.5,
        warningShape = "cross",
        warningRange = 3.5,
        warningCrossWidth = 1.0,
        warningColor = {60, 160, 255, 120},     -- 坎水蓝
    }

end
