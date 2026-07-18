-- ============================================================================
-- MonsterData_Skills_Common.lua - 通用/第一二章技能定义
-- 包含: 基础技能 + 乌万仇/沈墨/陆青云专属 + 通用扩展技能
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    M.Skills.poison_spit = {
        id = "poison_spit",
        name = "毒液喷射",
        cooldown = 6,
        damageMult = 1.2,
        effect = "poison",
        effectDuration = 3,
        effectValue = 0.3,
        -- 预警
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.0,
        warningColor = {50, 200, 50, 100},
    }
    M.Skills.shield_bash = {
        id = "shield_bash",
        name = "盾击",
        cooldown = 7,
        damageMult = 1.8,
        effect = "knockback",
        effectValue = 1.5,
        -- 预警
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.0,
        warningConeAngle = 90,
        warningColor = {200, 150, 50, 100},
    }
    M.Skills.whirlwind = {
        id = "whirlwind",
        name = "旋风斩",
        cooldown = 8,
        damageMult = 2.0,
        effect = nil,
        -- 预警
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {200, 200, 50, 100},
    }
    M.Skills.fan_strike = {
        id = "fan_strike",
        name = "羽扇毒计",
        cooldown = 7,
        damageMult = 1.0,
        effect = "poison",
        effectDuration = 4,
        effectValue = 0.4,
        -- 预警
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.5,
        warningConeAngle = 60,
        warningColor = {150, 50, 200, 100},
    }
    M.Skills.ground_pound = {
        id = "ground_pound",
        name = "震地锤",
        cooldown = 8,
        damageMult = 2.5,
        effect = "stun",
        effectDuration = 1.0,
        -- 预警
        castTime = 1.2,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {220, 60, 30, 100},
    }
    M.Skills.tiger_claw = {
        id = "tiger_claw",
        name = "虎爪",
        cooldown = 5,
        damageMult = 2.0,
        effect = nil,
        -- 预警
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.0,
        warningConeAngle = 80,
        warningColor = {220, 160, 30, 100},
    }
    -- ===================== 乌万仇专属技能 =====================
    M.Skills.wanchou_shadow_slash = {
        id = "wanchou_shadow_slash",
        name = "暗影重斩",
        cooldown = 6,
        damageMult = 2.5,
        effect = "knockback",
        effectValue = 2.0,
        -- 预警
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.5,
        warningConeAngle = 90,
        warningColor = {100, 30, 150, 120},
    }
    M.Skills.wanchou_fury = {
        id = "wanchou_fury",
        name = "万仇震怒",
        cooldown = 12,
        damageMult = 2.0,
        effect = "stun",
        effectDuration = 1.5,
        -- 预警
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {180, 50, 50, 120},
    }
    M.Skills.wanchou_blood_devour = {
        id = "wanchou_blood_devour",
        name = "血煞吞噬",
        cooldown = 10,
        damageMult = 1.5,
        effect = "poison",
        effectDuration = 5,
        effectValue = 0.5,
        -- 预警
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 3.5,
        warningColor = {150, 20, 60, 120},
    }
    M.Skills.wanchou_annihilation = {
        id = "wanchou_annihilation",
        name = "灭世血煞",
        cooldown = 999,             -- 不走CD，由阶段转换触发
        damageMult = 0,             -- 伤害为百分比制
        damagePercent = 0.5,        -- 50%当前血量上限
        effect = nil,
        -- 场地技能特殊参数
        isFieldSkill = true,
        safeZoneCount = 4,          -- 4个安全区
        safeZoneRadius = 0.7,       -- 安全区半径（瓦片）
        -- 预警
        castTime = 2.5,             -- 长蓄力给玩家跑位时间
        warningShape = "circle",
        warningRange = 8.0,         -- 超大范围
        warningColor = {200, 20, 20, 160},
    }

    -- ===================== 沈墨专属技能 =====================
    M.Skills.shenmo_blood_flood = {
        id = "shenmo_blood_flood",
        name = "血海漫灌",
        cooldown = 999,             -- 不走CD，由阶段转换触发
        damageMult = 0,
        damagePercent = 0.5,        -- 50%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,          -- 2个安全区
        safeZoneRadius = 0.5,       -- 安全区较小
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {180, 20, 20, 160},  -- 血红
    }
    -- T2/T3 低难度版本（更多安全格，更低伤害）
    M.Skills.shenmo_blood_flood_easy = {
        id = "shenmo_blood_flood",   -- 共用同一 id，渲染/颜色逻辑复用
        name = "血海漫灌",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.25,        -- 25%最大血量（T2/T3 降低）
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 8,           -- 8个安全格（36格中）
        safeZoneRadius = 0.5,
        castTime = 2.5,              -- 更长蓄力时间给玩家反应
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {180, 20, 20, 160},
    }
    M.Skills.shenmo_shadow_clone = {
        id = "shenmo_shadow_clone",
        name = "血煞分身",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        effect = nil,
        isCloneSkill = true,        -- 特殊标记：分身技能
        cloneCount = 2,             -- 召唤2个分身
        cloneHpPercent = 0.15,      -- 分身15%BOSS血量
        cloneAtkPercent = 0.4,      -- 分身40%BOSS攻击
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {150, 30, 30, 120},  -- 暗血红
    }

    -- ===================== 陆青云专属技能 =====================
    M.Skills.luqingyun_sword_array = {
        id = "luqingyun_sword_array",
        name = "天罡剑阵",
        cooldown = 999,             -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.6,        -- 60%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,          -- 2个安全区
        safeZoneRadius = 0.5,       -- 安全区较小
        castTime = 2.5,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {220, 180, 40, 160},  -- 金黄
    }
    -- T2/T3 低难度版本
    M.Skills.luqingyun_sword_array_easy = {
        id = "luqingyun_sword_array", -- 共用同一 id，渲染/颜色逻辑复用
        name = "天罡剑阵",
        cooldown = 999,
        damageMult = 0,
        damagePercent = 0.25,        -- 25%最大血量（T2/T3 降低）
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 8,           -- 8个安全格（36格中）
        safeZoneRadius = 0.5,
        castTime = 3.0,              -- 更长蓄力时间
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {220, 180, 40, 160},
    }
    M.Skills.luqingyun_prison = {
        id = "luqingyun_prison",
        name = "正气囚笼",
        cooldown = 15,
        damageMult = 0,
        effect = nil,
        isPrisonSkill = true,       -- 特殊标记：囚笼技能
        prisonRadius = 1.0,         -- 囚笼半径
        prisonEscapeTime = 1.5,     -- 逃脱时间窗口（秒）
        prisonDamagePercent = 0.4,  -- 未逃脱伤害（40%最大血量）
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 1.0,
        warningColor = {240, 200, 50, 140},  -- 亮金黄
    }

    M.Skills.tiger_roar = {
        id = "tiger_roar",
        name = "虎啸",
        cooldown = 10,
        damageMult = 1.5,
        effect = "slow",
        effectDuration = 3.0,
        effectValue = 0.30,         -- 降低30%移速和攻速
        -- 预警
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 3.5,
        warningColor = {220, 30, 30, 120},
    }

    -- ===================== 通用扩展技能 =====================
    M.Skills.cross_smash = {
        id = "cross_smash",
        name = "十字裂地",
        cooldown = 8,
        damageMult = 2.5,
        effect = nil,
        -- 预警
        castTime = 1.2,
        warningShape = "cross",
        warningRange = 3.0,         -- 十字臂长
        warningCrossWidth = 0.8,    -- 十字臂宽
        warningColor = {200, 100, 30, 120},
    }
    M.Skills.line_charge = {
        id = "line_charge",
        name = "冲锋突刺",
        cooldown = 7,
        damageMult = 2.2,
        effect = nil,
        -- 预警
        castTime = 0.8,
        warningShape = "line",
        warningRange = 3.5,         -- 线性长度
        warningLineWidth = 0.8,     -- 线性宽度
        warningColor = {220, 180, 50, 120},
    }
    M.Skills.rect_sweep = {
        id = "rect_sweep",
        name = "横扫千军",
        cooldown = 7,
        damageMult = 2.0,
        effect = nil,
        -- 预警
        castTime = 1.0,
        warningShape = "rect",
        warningRange = 2.5,         -- 用于预筛选
        warningRectLength = 2.5,    -- 矩形长
        warningRectWidth = 1.2,     -- 矩形宽
        warningColor = {180, 160, 60, 120},
    }
    M.Skills.fire_zone = {
        id = "fire_zone",
        name = "烈焰灼烧",
        cooldown = 10,
        damageMult = 0.8,
        effect = "burn",
        effectDuration = 3.0,
        effectValue = 0.4,          -- 每秒 40% ATK 持续灼烧
        -- 预警
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 2.0,
        warningColor = {255, 120, 30, 120},
    }
    M.Skills.shield_slam = {
        id = "shield_slam",
        name = "重盾猛击",
        cooldown = 7,
        damageMult = 2.5,
        effect = nil,               -- 纯高伤，无控制
        -- 预警
        castTime = 1.0,
        warningShape = "cone",
        warningRange = 2.0,
        warningConeAngle = 90,
        warningColor = {160, 160, 180, 120},
    }

end
