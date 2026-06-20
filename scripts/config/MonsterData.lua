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


-- ===================== 技能定义（按章节拆分） =====================
require("config.MonsterData_Skills")(MonsterData)

-- ===================== 怪物类型定义 =====================
-- level: 固定等级（BOSS/部分精英）
-- levelRange: {min, max} 随机等级（小怪/部分精英）
-- race: 种族键，用于查找 RaceModifiers
-- skills: 技能ID列表
-- phaseConfig: BOSS阶段配置

MonsterData.Types = {}

-- ===================== 世界掉落池（按章节拆分） =====================
require("config.MonsterData_WorldDrop")(MonsterData)

-- 按章节加载怪物数据
require("config.MonsterTypes_ch1")(MonsterData)
require("config.MonsterTypes_ch2")(MonsterData)
require("config.MonsterTypes_ch3")(MonsterData)
require("config.MonsterTypes_ch4")(MonsterData)
require("config.MonsterTypes_ch5")(MonsterData)
require("config.MonsterTypes_xianjie")(MonsterData)
require("config.MonsterTypes_xianyun")(MonsterData)
require("config.MonsterTypes_training")(MonsterData)

return MonsterData
