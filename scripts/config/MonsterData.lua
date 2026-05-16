-- ============================================================================
-- MonsterData.lua - 怪物数据表
-- 属性公式化：最终属性 = 基础(level) × 阶级倍率 × 种族修正
-- ============================================================================

local MonsterData = {}

-- ===================== 基础属性公式 =====================

---@param level number
---@return number hp, number atk, number def, number speed, number exp, number gold
function MonsterData.CalcBaseStats(level)
    local hp    = 50 + level * 50
    -- Lv.55+ 二次HP成长（K=5），高等级怪物更耐打
    if level > 55 then
        hp = hp + (level - 55) * (level - 55) * 5
    end
    local atk   = 5  + level * 2.5
    local def   = 2  + level * 2
    local speed = 1.2 + level * 0.1
    local exp   = 10 + level * 5
    -- Lv.55+ 二次EXP成长（K=0.5），与HP同比例增幅，保持高等级刷怪效率
    if level > 55 then
        exp = exp + (level - 55) * (level - 55) * 0.5
    end
    local gold  = 1  + level * 1
    return hp, atk, def, speed, exp, gold
end

-- ===================== 种族修正 =====================

MonsterData.RaceModifiers = {
    spider       = { hp = 0.8, atk = 1.0, def = 0.7, speed = 1.3 },  -- 脆皮高速
    boar         = { hp = 1.3, atk = 0.9, def = 1.3, speed = 0.8 },  -- 肉盾低速
    bandit       = { hp = 1.0, atk = 1.1, def = 1.0, speed = 1.0 },  -- 均衡偏攻
    tiger        = { hp = 1.1, atk = 1.3, def = 0.9, speed = 1.2 },  -- 高攻高速
    frog         = { hp = 0.6, atk = 0.5, def = 0.5, speed = 0.9 },  -- 弱小被动
    snake        = { hp = 0.7, atk = 1.2, def = 0.6, speed = 1.4 },  -- 脆皮高攻高速
    undead       = { hp = 1.2, atk = 1.0, def = 1.1, speed = 0.9 },  -- 肉盾低速
    dark_warrior = { hp = 1.1, atk = 1.1, def = 1.0, speed = 1.0 },  -- 均衡偏攻
    -- 第三章：妖族
    sand_scorpion = { hp = 0.9, atk = 1.1, def = 1.2, speed = 0.9 },  -- 沙漠蝎：硬壳偏防
    sand_wolf    = { hp = 0.9, atk = 1.2, def = 0.8, speed = 1.3 },  -- 沙狼：高攻高速脆皮
    sand_demon   = { hp = 1.2, atk = 1.1, def = 1.0, speed = 1.0 },  -- 沙妖：均衡偏肉
    kumu         = { hp = 1.1, atk = 0.9, def = 1.3, speed = 0.7 },  -- 枯木精：高防低速，树木特性
    yanchan      = { hp = 1.3, atk = 0.8, def = 1.1, speed = 0.8 },  -- 岩蟾：高血高防低速，蟾蜍特性
    shegu        = { hp = 0.8, atk = 1.2, def = 0.9, speed = 1.2 },  -- 蛇骨妖：高攻高速偏脆，蛇类特性
    yao_king     = { hp = 1.3, atk = 1.2, def = 1.1, speed = 1.0 },  -- 妖王：全面强化
    -- 第四章：龙族
    ice_dragon   = { hp = 1.2, atk = 0.9, def = 1.3, speed = 0.8 },  -- 应龙：冰系坦克，高血高防低攻
    abyss_dragon = { hp = 1.1, atk = 1.1, def = 1.1, speed = 1.0 },  -- 蛟龙：深渊均衡，全面强化
    fire_dragon  = { hp = 0.9, atk = 1.3, def = 0.9, speed = 1.2 },  -- 蜃龙：火系玻璃，高攻低防
    sand_dragon  = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.3 },  -- 螭龙：沙系高速，持续侵蚀
    -- 神兽（神器BOSS专用）
    divine_beast = { hp = 1.4, atk = 1.2, def = 1.1, speed = 0.9 },  -- 神兽：高血高攻，威压沉稳
}

-- ===================== 阶级倍率表 =====================

MonsterData.CategoryMultipliers = {
    normal = {
        hp = 1.0,  atk = 1.0,  def = 1.0,  speed = 1.0,
        exp = 1.0, gold = 1.0,
        bodySize = 0.65, respawnTime = 15, patrolRadius = 3,
    },
    elite = {
        hp = 2.0,  atk = 1.2,  def = 1.2,  speed = 1.2,
        exp = 2.0, gold = 2.0,
        bodySize = 0.9, respawnTime = 60, patrolRadius = 2,
    },
    boss = {
        hp = 5.0,  atk = 1.3,  def = 1.3,  speed = 1.3,
        exp = 5.0, gold = 5.0,
        bodySize = 1.3, respawnTime = 180, patrolRadius = 0,
    },
    king_boss = {
        hp = 10.0, atk = 1.5,  def = 1.5,  speed = 1.5,
        exp = 10.0, gold = 10.0,
        bodySize = 1.8, respawnTime = 180, patrolRadius = 0,
    },
    emperor_boss = {
        hp = 20.0, atk = 1.8,  def = 1.8,  speed = 1.6,
        exp = 20.0, gold = 20.0,
        bodySize = 2.2, respawnTime = 180, patrolRadius = 0,
    },
    saint_boss = {
        hp = 40.0, atk = 2.0,  def = 2.0,  speed = 1.8,
        exp = 40.0, gold = 40.0,
        bodySize = 2.8, respawnTime = 180, patrolRadius = 0,
    },
}

--- 计算境界系数（与玩家突破幅度一致）
--- 大境界突破(isMajor)额外+10%，从第二个大境界起累积
--- 化神+(order>=13)起步进加大：小境界+0.15, 大境界+0.30
---@param realmId string|nil
---@return number statMult, number rewardMult
function MonsterData.CalcRealmMult(realmId)
    if not realmId then return 1.0, 1.0 end
    local GameConfig = require("config.GameConfig")
    local realmData = GameConfig.REALMS[realmId]
    if not realmData then return 1.0, 1.0 end
    local order = realmData.order or 0
    if order <= 0 then return 1.0, 1.0 end
    -- 统计当前境界及之前的大境界突破次数
    local majorCount = 0
    for _, r in pairs(GameConfig.REALMS) do
        if r.isMajor and r.order and r.order <= order then
            majorCount = majorCount + 1
        end
    end
    -- 首个大境界(练气)为基线，之后每跨一个大境界额外+0.1
    local majorBonus = math.max(0, majorCount - 1) * 0.1
    local statMult = 1.1 + order * 0.1 + majorBonus

    -- 化神+(order>=13)起步进加大（统一影响HP/ATK/DEF）
    -- 小境界步进 0.10→0.15（+0.05），大境界步进 0.20→0.30（+0.10）
    if order >= 13 then
        local extraOrders = order - 12
        local extraMajors = 0
        for _, r in pairs(GameConfig.REALMS) do
            if r.isMajor and r.order and r.order > 12 and r.order <= order then
                extraMajors = extraMajors + 1
            end
        end
        statMult = statMult + extraOrders * 0.05 + extraMajors * 0.05
    end

    return statMult, 1.0 + order * 0.2
end

--- 根据等级、阶级、种族、境界计算最终属性
---@param level number
---@param category string
---@param race string|nil
---@param realmId string|nil
---@return table
function MonsterData.CalcFinalStats(level, category, race, realmId)
    local baseHp, baseAtk, baseDef, baseSpeed, baseExp, baseGold = MonsterData.CalcBaseStats(level)
    local mult = MonsterData.CategoryMultipliers[category] or MonsterData.CategoryMultipliers.normal
    local raceMod = race and MonsterData.RaceModifiers[race] or { hp = 1, atk = 1, def = 1, speed = 1 }
    local realmMult, rewardMult = MonsterData.CalcRealmMult(realmId)

    local finalHp    = math.floor(baseHp    * mult.hp    * raceMod.hp    * realmMult)
    local finalAtk   = math.floor(baseAtk   * mult.atk   * raceMod.atk   * realmMult)
    local finalDef   = math.floor(baseDef   * mult.def   * raceMod.def   * realmMult)
    local finalSpeed = baseSpeed * mult.speed * raceMod.speed
    local finalExp   = math.floor(baseExp   * mult.exp   * rewardMult)
    local finalGold  = math.floor(baseGold  * mult.gold  * rewardMult)

    local goldMin = math.floor(finalGold * 0.8)
    local goldMax = math.floor(finalGold * 1.2)

    return {
        hp = finalHp,
        atk = finalAtk,
        def = finalDef,
        speed = finalSpeed,
        expReward = finalExp,
        goldMin = goldMin,
        goldMax = goldMax,
        bodySize = mult.bodySize,
        respawnTime = mult.respawnTime,
        patrolRadius = mult.patrolRadius,
    }
end

-- ===================== 技能定义 =====================
-- cooldown: 冷却时间（秒）
-- damageMult: 伤害倍率（基于怪物ATK）
-- effect: 附加效果 "poison"|"knockback"|"stun"|"slow"|nil
-- effectDuration: 效果持续时间
-- effectValue: 效果参数（毒伤=ATK百分比/击退距离/ATK增幅百分比）

-- 预警参数说明:
-- castTime: 蓄力时间（秒），期间怪物停止移动，显示预警
-- warningShape: "circle"|"cone"|"cross"|"line"|"rect" 预警区域形状
-- warningRange: 预警区域半径（瓦片）
-- warningColor: 预警区域颜色 {r,g,b,a}
-- warningConeAngle: 锥形预警角度（度，仅 cone 形状）
-- warningCrossWidth: 十字臂宽度（瓦片，仅 cross 形状）
-- warningLineWidth: 线性宽度（瓦片，仅 line 形状）
-- warningRectLength/warningRectWidth: 矩形长宽（瓦片，仅 rect 形状）

MonsterData.Skills = {
    poison_spit = {
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
    },
    shield_bash = {
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
    },
    whirlwind = {
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
    },
    fan_strike = {
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
    },
    ground_pound = {
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
    },
    tiger_claw = {
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
    },
    -- ===================== 乌万仇专属技能 =====================
    wanchou_shadow_slash = {
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
    },
    wanchou_fury = {
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
    },
    wanchou_blood_devour = {
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
    },
    wanchou_annihilation = {
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
    },

    -- ===================== 沈墨专属技能 =====================
    shenmo_blood_flood = {
        id = "shenmo_blood_flood",
        name = "血海漫灌",
        cooldown = 999,             -- 不走CD，由阶段转换触发
        damageMult = 0,
        damagePercent = 0.5,        -- 50%最大血量
        effect = nil,
        isFieldSkill = true,
        safeZoneCount = 2,          -- 2个安全区
        safeZoneRadius = 0.5,       -- 安全区较小
        safeZoneMoving = true,      -- 安全区缓慢移动
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 8.0,
        warningColor = {180, 20, 20, 160},  -- 血红
    },
    -- T2/T3 低难度版本（更多安全格，更低伤害）
    shenmo_blood_flood_easy = {
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
    },
    shenmo_shadow_clone = {
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
    },

    -- ===================== 陆青云专属技能 =====================
    luqingyun_sword_array = {
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
    },
    -- T2/T3 低难度版本
    luqingyun_sword_array_easy = {
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
    },
    luqingyun_prison = {
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
    },

    tiger_roar = {
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
    },

    -- ===================== 通用扩展技能 =====================
    cross_smash = {
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
    },
    line_charge = {
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
    },
    rect_sweep = {
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
    },
    fire_zone = {
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
    },
    shield_slam = {
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
    },

    -- ===================== 第三章·沙漠九寨 专属技能 =====================

    -- === 精英技能 ===
    sand_blade = {
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
    },
    sand_cross_strike = {
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
    },
    sand_fire_circle = {
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
    },

    -- === 枯木妖王 ===
    kumu_entangle = {
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
    },
    kumu_decay_dust = {
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
    },
    kumu_root_cross = {
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
    },
    kumu_withered_field = {
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
    },
    kumu_death_bloom = {
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
    },
    kumu_berserk_roots = {
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
    },

    -- === 岩蟾妖王 ===
    yanchan_quake = {
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
    },
    yanchan_venom_spray = {
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
    },

    -- === 苍狼妖王 ===
    canglang_howl = {
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
    },
    canglang_charge = {
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
    },

    -- === 赤甲妖王 ===
    chijia_tail_sweep = {
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
    },
    chijia_pincer = {
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
    },

    -- === 蛇骨妖王 ===
    shegu_bone_spike = {
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
    },
    shegu_miasma = {
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
    },

    -- === 烈焰狮王（王级BOSS） ===
    lieyan_roar = {
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
    },
    lieyan_pounce = {
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
    },
    lieyan_inferno = {
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
    },

    -- === 蜃妖王（王级BOSS） ===
    shen_vortex = {
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
    },
    shen_maze = {
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
    },
    shen_annihilation = {
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
    },
    shen_clone = {
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
    },

    -- === 黄天大圣·沙万里（皇级BOSS） ===
    sha_cross_quake = {
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
    },
    -- ===================== 猪二哥专属：全屏AOE（过阶段触发，不可闪避） =====================
    zhu_erge_divine_wrath = {
        id = "zhu_erge_divine_wrath",
        name = "天蓬怒",
        cooldown = 999,             -- 由阶段转换触发，不走常规CD
        damageMult = 1.0,           -- 技能系数1.0
        effect = nil,
        castTime = 1.5,
        warningShape = "circle",
        warningRange = 6.0,         -- 覆盖整个8×8竞技场
        warningColor = {255, 200, 50, 160},
    },
    sha_desert_storm = {
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
    },
    sha_sandstorm_field = {
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
    },
    sha_sand_clone = {
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
    },

    -- ===================== 第四章·封霜应龙 专属技能 =====================
    frost_breath = {
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
    },
    ice_prison = {
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
    },
    permafrost_field = {
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
    },

    -- ===================== 第四章·堕渊蛟龙 专属技能 =====================
    abyss_roar = {
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
    },
    abyss_venom = {
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
    },
    abyss_vortex_field = {
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
    },

    -- ===================== 第四章·焚天蜃龙 专属技能 =====================
    dragon_flame = {
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
    },
    inferno_ground = {
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
    },
    inferno_field = {
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
    },

    -- ===================== 第四章·蚀骨螭龙 专属技能 =====================
    erosion_storm = {
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
    },
    sand_charge_dragon = {
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
    },
    erosion_field = {
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
    },

    -- ===================== 第四章·八阵BOSS 专属技能 =====================

    -- === ①坎·沈渊衣（水系控制） ===
    kan_tidal_vortex = {
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
    },
    kan_water_blade = {
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
    },
    kan_whirlpool_prison = {
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
    },

    -- === ②艮·岩不动（土系坦克） ===
    gen_rock_slam = {
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
    },
    gen_stone_wall = {
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
    },
    gen_avalanche = {
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
    },

    -- === ③震·雷惊蛰（雷系爆发） ===
    zhen_thunder_pierce = {
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
    },
    zhen_thunder_roar = {
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
    },
    zhen_divine_thunder = {
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
    },

    -- === ④巽·风无痕（风系机动） ===
    xun_wind_slash = {
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
    },
    xun_phantom_dash = {
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
    },
    xun_phantom_clone = {
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
    },

    -- === ⑤离·炎若晦（火系DOT） ===
    li_karma_fire = {
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
    },
    li_inferno_burst = {
        id = "li_inferno_burst",
        name = "炼狱爆裂",
        cooldown = 8,
        damageMult = 3.0,
        effect = nil,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.0,
        warningColor = {255, 100, 30, 120},     -- 橙红
    },
    li_heaven_fire = {
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
    },

    -- === ⑥坤·厚德生（地系防御） ===
    kun_earth_surge = {
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
    },
    kun_earth_sweep = {
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
    },
    kun_earth_collapse = {
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
    },

    -- === ⑦兑·泽归墟（毒系消耗） ===
    dui_gu_miasma = {
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
    },
    dui_venom_line = {
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
    },
    dui_gu_devour = {
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
    },

    -- === ⑧乾·司空正阳（全能终极人类BOSS） ===
    qian_gang_sword = {
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
    },
    qian_taixu_palm = {
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
    },
    qian_heaven_toss = {
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
    },
    qian_gang_annihilation = {
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
    },

    -- === 封霜应龙 新增P1技能 ===
    frost_crack = {
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
    },

    -- === 堕渊蛟龙 新增P2分身 ===
    abyss_clone = {
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
    },

    -- === 焚天蜃龙 新增P2龙息 ===
    dragon_breath_sweep = {
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
    },

    -- === 蚀骨螭龙 新增P2囚笼 ===
    sand_prison = {
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
    },

    -- === 文王残影（第四章神器BOSS）专属技能 ===

    -- 阴阳逆转：每10%血量触发的状态切换AOE
    wenwang_yinyang_reversal = {
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
    },

    -- 阳仪态技能：乾天裂（快速高伤圆形砸击）
    wenwang_qian_split = {
        id = "wenwang_qian_split",
        name = "乾天裂",
        cooldown = 6,
        damageMult = 3.0,
        effect = nil,
        castTime = 1.0,
        warningShape = "circle",
        warningRange = 2.5,
        warningColor = {255, 200, 50, 120},     -- 阳金
    },

    -- 阳仪态技能：离火焚（前方矩形火焰 + 灼烧DOT）
    wenwang_li_blaze = {
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
    },

    -- 阴仪态技能：坤地缚（大范围减速圆形）
    wenwang_kun_bind = {
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
    },

    -- 阴仪态技能：坎水寒（十字冰裂封锁走位）
    wenwang_kan_frost = {
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
    },

    -- ===================== 仙劫战场·域外邪魔技能 =====================

    -- 虚空裂斩：十字形剑气，高伤害，可躲避
    void_cross_slash = {
        id = "void_cross_slash",
        name = "虚空裂斩",
        cooldown = 8,
        damageMult = 4.0,
        castTime = 1.5,
        warningShape = "cross",
        warningRange = 4.0,
        warningCrossWidth = 1.2,
        warningColor = {150, 30, 150, 120},     -- 邪紫
    },

    -- 邪能冲击：锥形冲击波，附带减速
    evil_impact = {
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
    },

    -- 灭世波动：全范围圆形AOE，50%血量触发，高伤害
    doom_wave = {
        id = "doom_wave",
        name = "灭世波动",
        cooldown = 15,
        damageMult = 5.0,
        castTime = 2.0,
        warningShape = "circle",
        warningRange = 5.0,
        warningColor = {180, 20, 60, 120},      -- 血红
        isFieldSkill = true,                     -- 阶段触发技能
    },

    -- ===================== 云裳（青云门挑战）专属技能 =====================
    jade_palm = {
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
    },
    spirit_needle = {
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
    },
    cloud_drift = {
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
    },
    -- 阶段触发：碧玉风暴（全场 AOE + 安全区）
    yunshang_jade_storm = {
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
    },
    -- 阶段追加：盘根甲（P2 追加到技能列表的持续性矩形 AOE）
    yunshang_root_armor = {
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
    },

    -- ===================== 凌战专属技能 =====================

    --- 封印爆发（阶段转换触发：全屏AOE + 安全区，紫色主题）
    liwuji_seal_burst = {
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
    },

    --- 虚空拉扯（阶段2新增常规技能：拉扯玩家到BOSS身边 + 伤害）
    liwuji_void_pull = {
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
    },

    -- =====================================================================
    --                     第五章 · 太虚宗废墟技能
    -- =====================================================================

    -- ===================== 精英怪技能（6个，各1个） =====================

    --- 残影剑灵 — 残影剑刺（line，快速直线突刺）
    ch5_shadow_thrust = {
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
    },

    --- 寒池冰龟 — 寒冰喷吐（cone + slow）
    ch5_frost_breath = {
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
    },

    --- 炉火锻兵 — 熔铁横扫（rect + knockback）
    ch5_molten_sweep = {
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
    },

    --- 碑林剑魂 — 碑文剑气（cross，十字交叉封锁）
    ch5_stele_cross = {
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
    },

    --- 月影夜卫 — 月影突刺（line，快速穿刺）
    ch5_moon_pierce = {
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
    },

    --- 墨毒书妖 — 墨毒弥散（circle + poison）
    ch5_ink_poison = {
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
    },

    -- ===================== 护山石傀（king_boss Lv.95）· 3技能 =====================
    -- 永久狂暴：3技能全部从开战可用，berserkBuff 常驻

    --- 山岩崩击（circle，大范围砸地）
    ch5_rock_smash = {
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
    },

    --- 碎石横飞（cone，前方扇形碎石弹射 + knockback）
    ch5_rock_scatter = {
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
    },

    --- 山门镇压（rect，正面长条重压）
    ch5_gate_crush = {
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
    },

    -- ===================== 裂渊屠血将（king_boss Lv.120）· 3技能 =====================
    -- 2 基础 + 1 addSkill@50%

    --- 血刃横斩（rect，正面高伤矩形斩击）
    ch5_blood_cleave = {
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
    },

    --- 嗜血旋风（circle，中范围AOE + 吸血效果描述用burn代替）
    ch5_blood_whirl = {
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
    },

    --- 血渊爆裂（P2 addSkill：cross，十字血线 + 高伤害）
    ch5_blood_eruption = {
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
    },

    -- ===================== 裴千岳（emperor_boss · 剑法广场）· 4技能 =====================
    -- 2 基础 + addSkill@70% + triggerSkill@30%

    --- 太虚剑诀（line，标志性直线剑气）
    ch5_pei_sword_qi = {
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
    },

    --- 裂空斩（rect，宽矩形横斩）
    ch5_pei_sky_slash = {
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
    },

    --- P2追加：幻影剑阵（clone，召唤分身同时攻击）
    ch5_pei_phantom_sword = {
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
    },

    --- P3触发：千岳剑意·破灭（field，全场AOE + 安全区）
    ch5_pei_execution = {
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
    },

    -- ===================== 霜鸾（emperor_boss · 寒池）· 4技能 =====================

    --- 凝霜啄击（cone，前方冰锥 + slow）
    ch5_luan_frost_peck = {
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
    },

    --- 寒翼风暴（circle，大范围冰暴）
    ch5_luan_ice_storm = {
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
    },

    --- P2追加：冰棱监牢（prison，冰笼困锁玩家）
    ch5_luan_ice_prison = {
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
    },

    --- P3触发：霜鸾绝唱（field，全场冰暴 + 安全区）
    ch5_luan_requiem = {
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
    },

    -- ===================== 韩百炼（emperor_boss · 锻造厅）· 4技能 =====================

    --- 炼狱锤击（circle，圆形重锤 + stun）
    ch5_han_forge_slam = {
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
    },

    --- 火龙卷（rect，前方烈焰矩形 + burn）
    ch5_han_flame_roll = {
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
    },

    --- P2追加：百炼分身（clone，锻造分身锤击）
    ch5_han_forge_clone = {
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
    },

    --- P3触发：天炉焚灭（field，全场火海 + 安全区）
    ch5_han_inferno = {
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
    },

    -- ===================== 石观澜（emperor_boss · 碑林）· 4技能 =====================

    --- 万碑剑雨（cross，十字碑文剑气）
    ch5_shi_stele_rain = {
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
    },

    --- 碑铭震荡（circle，中范围圆形 + stun）
    ch5_shi_stele_shock = {
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
    },

    --- P2追加：碑林幻阵（clone，分裂碑影）
    ch5_shi_stele_clone = {
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
    },

    --- P3触发：万碑归一（field，全场碑文共鸣 + 安全区）
    ch5_shi_convergence = {
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
    },

    -- ===================== 宁栖梧（emperor_boss · 别院）· 4技能 =====================

    --- 枯木逢春（line，直线剑气，枯与荣的转化）
    ch5_ning_dead_bloom = {
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
    },

    --- 落叶纷飞（cone，前方扇形叶刃 + slow）
    ch5_ning_leaf_blade = {
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
    },

    --- P2追加：梧桐困锁（prison，枯木之笼困锁玩家）
    ch5_ning_wood_prison = {
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
    },

    --- P3触发：千年枯荣（field，全场枯荣交替 + 安全区）
    ch5_ning_withering = {
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
    },

    -- ===================== 温素章（emperor_boss · 藏经阁）· 4技能 =====================

    --- 万卷飞书（rect，矩形书页弹射 + poison）
    ch5_wen_book_barrage = {
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
    },

    --- 禁卷·灵文爆（circle，圆形灵文爆发 + stun）
    ch5_wen_rune_blast = {
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
    },

    --- P2追加：墨影分身（clone，书妖幻影分身）
    ch5_wen_ink_clone = {
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
    },

    --- P3触发：禁典·万灵归墟（field，全场灵文暴走 + 安全区）
    ch5_wen_forbidden = {
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
    },

    -- ===================== 噬渊血犼（emperor_boss · 镇魔深渊）· 4技能 =====================

    --- 深渊噬咬（cone，前方大角度撕咬 + burn）
    ch5_abyss_devour = {
        id = "ch5_abyss_devour",
        name = "深渊噬咬",
        cooldown = 5,
        damageMult = 3.0,
        effect = "burn",
        effectDuration = 2.5,
        effectValue = 0.5,
        castTime = 0.7,
        warningShape = "cone",
        warningRange = 3.0,
        warningConeAngle = 90,
        warningColor = {160, 20, 60, 120},      -- 深渊红
    },

    --- 血犼震吼（circle，中范围AOE + knockback）
    ch5_abyss_roar = {
        id = "ch5_abyss_roar",
        name = "血犼震吼",
        cooldown = 7,
        damageMult = 2.5,
        effect = "knockback",
        effectValue = 2.0,
        castTime = 0.8,
        warningShape = "circle",
        warningRange = 3.0,
        warningColor = {180, 30, 40, 120},      -- 血犼红
    },

    --- P2追加：深渊囚笼（prison，魔气困锁）
    ch5_abyss_prison = {
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
    },

    --- P3触发：噬天灭地（field，全场深渊吞噬 + 安全区）
    ch5_abyss_annihilation = {
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
    },
}

-- ===================== 怪物类型定义 =====================
-- level: 固定等级（BOSS/部分精英）
-- levelRange: {min, max} 随机等级（小怪/部分精英）
-- race: 种族键，用于查找 RaceModifiers
-- skills: 技能ID列表
-- phaseConfig: BOSS阶段配置

MonsterData.Types = {}

-- ===================== 世界掉落池（共享 roll） =====================
-- 同一池内物品共享一次掉率判定，命中后等权随机选一个
-- eliteLabel/bossLabel: 图鉴显示用
MonsterData.WORLD_DROP_POOLS = {
    ch1 = {
        eliteLabel = "0.5%", bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "gold_bar" },   -- 金条
        },
    },
    ch2 = {
        eliteLabel = "1%", bossLabel = "2%",
        items = {
            { type = "equipment", equipId = "gold_helmet_ch2" },  -- 招财金盔
            { type = "consumable", consumableId = "gold_bar" },
        },
    },
    ch3 = {
        eliteLabel = "1%", bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "exp_pill" },          -- 修炼果
            { type = "consumable", consumableId = "gold_bar" },          -- 金条
            { type = "consumable", consumableId = "demon_essence" },     -- 妖兽精华
            { type = "consumable", consumableId = "wind_eroded_grass", bossOnly = true }, -- 风蚀草（BOSS专属）
        },
    },
    ch4 = {
        eliteLabel = "3%", bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "exp_pill" },          -- 修炼果
            { type = "consumable", consumableId = "gold_bar" },          -- 金条
            { type = "consumable", consumableId = "demon_essence" },     -- 妖兽精华
            { type = "consumable", consumableId = "lingyun_fruit", bossOnly = true }, -- 灵韵果（BOSS专属）
        },
    },
    ch5 = {
        eliteLabel = "3%", bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "exp_pill" },          -- 修炼果
            { type = "consumable", consumableId = "gold_bar" },          -- 金条
            { type = "consumable", consumableId = "demon_essence" },     -- 妖兽精华
            { type = "consumable", consumableId = "lingyun_fruit", bossOnly = true }, -- 灵韵果（BOSS专属）
        },
    },
    -- 万仇/万海专用：筑基丹与修炼果共享掉落池
    boss_pill_ch2 = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "zhuji_pill" },       -- 筑基丹
            { type = "consumable", consumableId = "exp_pill" },         -- 修炼果
            { type = "consumable", consumableId = "wubao_token_box" },  -- 乌堡令盒
        },
    },
    -- 虎王专属：中级技能书共享5%，随机掉1本
    tiger_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_atk_2" },   -- 中级攻击书
            { type = "consumable", consumableId = "book_hp_2" },    -- 中级生命书
            { type = "consumable", consumableId = "book_def_2" },   -- 中级防御书
        },
    },
    -- 蛇王专属：中级技能书共享5%，随机掉1本
    snake_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_evade_2" }, -- 中级闪避书
            { type = "consumable", consumableId = "book_regen_2" }, -- 中级恢复书
            { type = "consumable", consumableId = "book_crit_2" },  -- 中级暴击书
        },
    },
    -- 蝎尾妖王专属：攻速技能书共享5%，随机掉1本
    xiewei_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_atkSpd_1" },    -- 初级攻速书
            { type = "consumable", consumableId = "book_atkSpd_2" },    -- 中级攻速书
        },
    },
    -- 苍狼妖王专属：暴伤技能书共享5%，随机掉1本
    canglang_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_critDmg_1" },   -- 初级暴伤书
            { type = "consumable", consumableId = "book_critDmg_2" },   -- 中级暴伤书
        },
    },
    -- 岩蟾妖王专属：蕴灵·生命技能书共享5%，随机掉1本
    yanchan_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_hpPerLv_1" },   -- 初级蕴灵·生命书
            { type = "consumable", consumableId = "book_hpPerLv_2" },   -- 中级蕴灵·生命书
        },
    },
    -- 赤甲妖王专属：减伤技能书共享5%，随机掉1本
    chijia_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_dmgReduce_1" }, -- 初级减伤书
            { type = "consumable", consumableId = "book_dmgReduce_2" }, -- 中级减伤书
        },
    },
    -- 铁脊狼王专属：蕴灵·防御技能书共享5%，随机掉1本
    tieji_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_defPerLv_1" },  -- 初级蕴灵·防御书
            { type = "consumable", consumableId = "book_defPerLv_2" },  -- 中级蕴灵·防御书
        },
    },
    -- 玄蟒妖王专属：连击技能书共享5%，随机掉1本
    xuanmang_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_doubleHit_1" }, -- 初级连击书
            { type = "consumable", consumableId = "book_doubleHit_2" }, -- 中级连击书
        },
    },
    -- 烈焰妖王专属：吸血技能书共享5%，随机掉1本
    lieyan_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_lifeSteal_1" }, -- 初级吸血书
            { type = "consumable", consumableId = "book_lifeSteal_2" }, -- 中级吸血书
        },
    },

    -- 沙万里专属：灵兽赐主T2技能书共享5%，随机掉1本
    shawanli_owner_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_wisdom_owner_2" },       -- 灵兽通慧书·贰
            { type = "consumable", consumableId = "book_constitution_owner_2" }, -- 灵兽铸骨书·贰
            { type = "consumable", consumableId = "book_physique_owner_2" },     -- 灵兽淬体书·贰
            { type = "consumable", consumableId = "book_fortune_owner_2" },      -- 灵兽赐福书·贰
        },
    },

    -- 黄天大圣灵器武器共享掉落池（1%命中后等权随机1把）
    huangsha_weapons = {
        bossLabel = "1%",
        items = {
            { type = "equipment", equipId = "huangsha_duanliu" },   -- 黄沙·断流
            { type = "equipment", equipId = "huangsha_fentian" },   -- 黄沙·焚天
            { type = "equipment", equipId = "huangsha_shihun" },    -- 黄沙·噬魂
            { type = "equipment", equipId = "huangsha_liedi" },     -- 黄沙·裂地
            { type = "equipment", equipId = "huangsha_mieying" },   -- 黄沙·灭影
        },
    },

    -- 司空正阳专属：高级蕴灵书共享3%，随机掉1本
    sikong_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_hpPerLv_3" },   -- 高级蕴灵·生命书
            { type = "consumable", consumableId = "book_defPerLv_3" },  -- 高级蕴灵·防御书
        },
    },
    -- 封霜应龙专属：高级技能书共享3%，随机掉1本（含赐主）
    dragon_ice_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_evade_3" },          -- 高级闪避书
            { type = "consumable", consumableId = "book_dmgReduce_3" },      -- 高级减伤书
            { type = "consumable", consumableId = "book_wisdom_owner_3" },   -- 灵兽通慧书·叁
        },
    },
    -- 堕渊蛟龙专属：高级技能书共享3%，随机掉1本（含赐主）
    dragon_abyss_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_regen_3" },              -- 高级恢复书
            { type = "consumable", consumableId = "book_crit_3" },               -- 高级暴击书
            { type = "consumable", consumableId = "book_constitution_owner_3" }, -- 灵兽铸骨书·叁
        },
    },
    -- 焚天蜃龙专属：高级技能书共享3%，随机掉1本（含赐主）
    dragon_fire_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_critDmg_3" },        -- 高级暴伤书
            { type = "consumable", consumableId = "book_doubleHit_3" },      -- 高级连击书
            { type = "consumable", consumableId = "book_physique_owner_3" }, -- 灵兽淬体书·叁
        },
    },
    -- 蚀骨螭龙专属：高级技能书共享3%，随机掉1本（含赐主）
    dragon_sand_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_atkSpd_3" },         -- 高级攻速书
            { type = "consumable", consumableId = "book_lifeSteal_3" },      -- 高级吸血书
            { type = "consumable", consumableId = "book_fortune_owner_3" },  -- 灵兽赐福书·叁
        },
    },

    -- ===================== 仙劫战场·域外邪魔掉落池 =====================

    -- 100% 掉落池：龙髓/妖兽精华/金条 三选一
    xianjie_material = {
        bossLabel = "100%",
        items = {
            { type = "consumable", consumableId = "dragon_marrow" },     -- 龙髓
            { type = "consumable", consumableId = "demon_essence" },     -- 妖兽精华
            { type = "consumable", consumableId = "gold_bar" },          -- 金条
        },
    },
    -- 5% 掉落池：九转金丹/修炼果/灵韵果 三选一
    xianjie_rare = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "jiuzhuan_jindan" },   -- 九转金丹
            { type = "consumable", consumableId = "exp_pill" },          -- 修炼果
            { type = "consumable", consumableId = "lingyun_fruit" },     -- 灵韵果
        },
    },
    -- 0.1% 掉落池：天帝剑痕碎片(1/2/3) 三选一
    xianjie_fragments = {
        bossLabel = "0.1%",
        items = {
            { type = "consumable", consumableId = "tiandi_fragment_1" }, -- 天帝剑痕碎片·壹
            { type = "consumable", consumableId = "tiandi_fragment_2" }, -- 天帝剑痕碎片·贰
            { type = "consumable", consumableId = "tiandi_fragment_3" }, -- 天帝剑痕碎片·叁
        },
    },
}

-- 按章节加载怪物数据
require("config.MonsterTypes_ch1")(MonsterData)
require("config.MonsterTypes_ch2")(MonsterData)
require("config.MonsterTypes_ch3")(MonsterData)
require("config.MonsterTypes_ch4")(MonsterData)
require("config.MonsterTypes_ch5")(MonsterData)
require("config.MonsterTypes_xianjie")(MonsterData)
require("config.MonsterTypes_training")(MonsterData)

return MonsterData
