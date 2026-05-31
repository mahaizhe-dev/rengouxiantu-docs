-- ============================================================================
-- MonsterData_Skills_Artifact.lua - 跨章节/秘境技能定义
-- 包含: 仙劫战场·域外邪魔 + 云裳(青云门挑战) + 凌战专属技能
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    -- ===================== 仙劫战场·域外邪魔技能 =====================

    -- 虚空裂斩：十字形剑气，高伤害，可躲避
    M.Skills.void_cross_slash = {
        id = "void_cross_slash",
        name = "虚空裂斩",
        cooldown = 8,
        damageMult = 4.0,
        castTime = 1.5,
        warningShape = "cross",
        warningRange = 4.0,
        warningCrossWidth = 1.2,
        warningColor = {150, 30, 150, 120},     -- 邪紫
    }

    -- 邪能冲击：锥形冲击波，附带减速
    M.Skills.evil_impact = {
        id = "evil_impact",
        name = "邪能冲击",
        cooldown = 6,
        damageMult = 3.5,
        effect = "slow",
        effectDuration = 2.5,
        effectValue = 0.50,         -- 减速50%
        castTime = 1.2,
        warningShape = "cone",
        warningRange = 3.5,
        warningConeAngle = 60,
        warningColor = {100, 20, 100, 120},     -- 暗紫
    }

    -- 灭世波动：全范围圆形AOE，50%血量触发，高伤害
    M.Skills.doom_wave = {
        id = "doom_wave",
        name = "灭世波动",
        cooldown = 15,
        damageMult = 5.0,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 5.0,
        warningColor = {180, 20, 60, 120},      -- 血红
        isFieldSkill = true,                     -- 阶段触发技能
    }

    -- ===================== 云裳（青云门挑战）专属技能 =====================
    M.Skills.jade_palm = {
        id = "jade_palm",
        name = "翠玉掌",
        cooldown = 7,
        damageMult = 1.8,
        effect = "knockback",
        effectValue = 1.5,
        -- 预警
        castTime = 0.8,
        warningShape = "cone",
        warningRange = 2.0,
        warningConeAngle = 90,
        warningColor = {60, 180, 100, 120},     -- 翠绿
    }
    M.Skills.spirit_needle = {
        id = "spirit_needle",
        name = "灵针射",
        cooldown = 6,
        damageMult = 1.5,
        effect = "slow",
        effectDuration = 2.5,
        effectValue = 0.3,                       -- 30% 减速
        -- 预警
        castTime = 0.6,
        warningShape = "line",
        warningRange = 3.5,
        warningLineWidth = 0.6,
        warningColor = {80, 220, 140, 100},     -- 浅碧
    }
    M.Skills.cloud_drift = {
        id = "cloud_drift",
        name = "云遁步",
        cooldown = 9,
        damageMult = 2.0,
        effect = "stun",
        effectDuration = 0.8,
        -- 瞬移到玩家身后后释放圆形 AOE
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.0,
        warningColor = {100, 200, 160, 100},    -- 青碧
    }
    -- 阶段触发：碧玉风暴（全场 AOE + 安全区）
    M.Skills.yunshang_jade_storm = {
        id = "yunshang_jade_storm",
        name = "碧玉风暴",
        cooldown = 999,                          -- 由阶段转换触发
        damageMult = 0,
        damagePercent = 0.40,                    -- 40% 最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,                       -- 3 个安全区
        safeZoneRadius = 0.5,
        safeZoneMoving = true,                   -- 安全区缓慢移动
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {60, 180, 100, 160},     -- 翠绿
    }
    -- 阶段追加：盘根甲（P2 追加到技能列表的持续性矩形 AOE）
    M.Skills.yunshang_root_armor = {
        id = "yunshang_root_armor",
        name = "盘根甲",
        cooldown = 10,
        damageMult = 1.2,
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.4,                       -- 40% 减速
        -- 预警
        castTime = 1.2,
        warningShape = "cross",
        warningRange = 3.0,
        warningCrossWidth = 0.8,
        warningColor = {40, 140, 80, 120},      -- 深碧
    }

    -- ===================== 凌战专属技能 =====================

    --- 封印爆发（阶段转换触发：全屏AOE + 安全区，紫色主题）
    M.Skills.liwuji_seal_burst = {
        id = "liwuji_seal_burst",
        name = "封印爆发",
        cooldown = 999,             -- 不走CD，由阶段转换触发
        damageMult = 0,
        damagePercent = 0.4,        -- 40%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 3,          -- 3个安全区
        safeZoneRadius = 0.6,       -- 安全区半径（瓦片）
        castTime = 2.0,             -- 2秒蓄力给玩家跑位
        warningShape = "circle",
        warningRange = 8.0,         -- 超大范围
        warningColor = {160, 40, 220, 160},  -- 紫色
    }

    --- 虚空拉扯（阶段2新增常规技能：拉扯玩家到BOSS身边 + 伤害）
    M.Skills.liwuji_void_pull = {
        id = "liwuji_void_pull",
        name = "虚空拉扯",
        cooldown = 10,
        damageMult = 1.8,
        effect = "knockback",
        effectValue = -2.5,         -- 负值 = 拉扯（向怪物方向）
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 4.0,
        warningColor = {140, 60, 200, 140},  -- 深紫
    }

end
