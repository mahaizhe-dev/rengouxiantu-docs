-- ============================================================================
-- PrisonTowerConfig.lua - 青云镇狱塔配置
-- 150层纯BOSS爬塔系统，每5层解锁1个新BOSS，永久数值成长
-- ============================================================================

local PrisonTowerConfig = {}

-- ============================================================================
-- 常量
-- ============================================================================

PrisonTowerConfig.ARENA_SIZE = 10           -- 内部可行走区域（与青云试炼一致）
PrisonTowerConfig.MAX_FLOOR = 150           -- 总层数
PrisonTowerConfig.MILESTONE_INTERVAL = 5    -- 每5层1次永久加成

-- ============================================================================
-- 开放条件
-- ============================================================================

PrisonTowerConfig.REQUIRED_REALM_ORDER = 7  -- 金丹初期 order=7
PrisonTowerConfig.REQUIRED_LEVEL = 40       -- 最低等级40

-- ============================================================================
-- 镇狱BUFF（塔内所有怪物统一挂载）
-- ============================================================================

PrisonTowerConfig.ZHENYU_BUFF = {
    hpMult = 2.0,           -- 生命翻倍
    atkMult = 2.0,          -- 攻击翻倍
    defMult = 2.0,          -- 防御翻倍
    speedMult = 2.0,        -- 移速翻倍
    atkSpeedMult = 2.0,     -- 攻速翻倍
    cdrMult = 0.5,          -- 实际CD减半（冷却效率翻倍）
}

-- ============================================================================
-- 镇狱塔柱技能参数
-- ============================================================================

PrisonTowerConfig.PILLAR_SKILLS = {
    groundSpike = {
        interval = 2.0,             -- 地刺触发间隔（秒）
        warningTime = 0.5,          -- 预警持续时间（秒）
        warningRange = 1.0,         -- 预警圆半径（格）
        warningColor = { 200, 50, 50, 160 },  -- 红色预警
        count = 3,                  -- 同时释放地刺数量（随机落点）
    },
    fullScreenAOE = {
        interval = 8.0,             -- AOE触发间隔（秒）
        warningTime = 1.5,          -- 预警持续时间（秒）
        warningColor = { 255, 200, 0, 120 },  -- 金色预警
        damagePct = 0.6,            -- 伤害为基准BOSS攻击力的60%
        canDodge = true,            -- 可通过无敌帧/盾值/闪避规避
    },
}

-- ============================================================================
-- BOSS固定出生点（基于10x10竞技场，中心点(6,6)留给塔柱）
-- ============================================================================

PrisonTowerConfig.BOSS_SPAWN_POSITIONS = {
    { x = 3.0, y = 3.0 },   -- 位置1：左上外圈
    { x = 9.0, y = 3.0 },   -- 位置2：右上外圈
    { x = 3.0, y = 9.0 },   -- 位置3：左下外圈
    { x = 9.0, y = 9.0 },   -- 位置4：右下外圈
}

-- 塔柱固定位置（房间正中央）
PrisonTowerConfig.PILLAR_POSITION = { x = 6.0, y = 6.0 }

-- ============================================================================
-- BOSS档位优先级（用于皇级保底判定）
-- ============================================================================

local CATEGORY_ORDER = {
    normal       = 1,
    elite        = 2,
    boss         = 3,
    king_boss    = 4,
    emperor_boss = 5,
    saint_boss   = 6,
}

-- ============================================================================
-- BOSS池（30个，按章节·等级升序排列）
-- ============================================================================

PrisonTowerConfig.BOSS_POOL = {
    -- 第一章
    "spider_queen",     -- 1:  蛛母
    "boar_king",        -- 2:  猪三哥
    "bandit_chief",     -- 3:  大大王
    "tiger_king",       -- 4:  虎王
    -- 第二章
    "boar_boss_ch2",    -- 5:  猪大哥
    "snake_king",       -- 6:  蛇妖·碧鳞
    "wu_dibei",         -- 7:  乌地北
    "wu_tiannan",       -- 8:  乌天南
    "wu_wanchou",       -- 9:  乌万仇
    "wu_wanhai",        -- 10: 乌万海
    -- 第三章
    "yao_king_8",       -- 11: 枯木妖王
    "yao_king_7",       -- 12: 岩蟾妖王
    "yao_king_6",       -- 13: 苍狼妖王
    "yao_king_5",       -- 14: 赤甲妖王
    "yao_king_4",       -- 15: 蛇骨妖王
    "yao_king_3",       -- 16: 烈焰狮王
    "yao_king_2",       -- 17: 蜃妖王
    "yao_king_1",       -- 18: 黄天大圣·沙万里
    -- 第四章
    "kan_boss",         -- 19: 沈渊衣
    "gen_boss",         -- 20: 岩不动
    "zhen_boss",        -- 21: 雷惊蛰
    "xun_boss",         -- 22: 风无痕
    "li_boss",          -- 23: 炎若晦
    "kun_boss",         -- 24: 厚德生
    "dui_boss",         -- 25: 泽归墟
    "qian_boss",        -- 26: 司空正阳
    "dragon_ice",       -- 27: 封霜应龙
    "dragon_abyss",     -- 28: 堕渊蛟龙
    "dragon_fire",      -- 29: 焚天蜃龙
    "dragon_sand",      -- 30: 蚀骨螭龙
}

-- ============================================================================
-- 境界映射表（15个挑战段，每段10层）
-- 玩家解锁境界 order = 6 + segmentIndex (7..21)
-- 怪物目标境界 order = requiredRealmOrder + 2 (9..23)
-- ============================================================================

PrisonTowerConfig.REALMS = {
    [1]  = { id = "jindan_1",   name = "金丹初期", monsterRealmId = "jindan_3",   reqLevel = 50,  maxLevel = 55 },
    [2]  = { id = "jindan_2",   name = "金丹中期", monsterRealmId = "yuanying_1", reqLevel = 55,  maxLevel = 70 },
    [3]  = { id = "jindan_3",   name = "金丹后期", monsterRealmId = "yuanying_2", reqLevel = 60,  maxLevel = 70 },
    [4]  = { id = "yuanying_1", name = "元婴初期", monsterRealmId = "yuanying_3", reqLevel = 65,  maxLevel = 70 },
    [5]  = { id = "yuanying_2", name = "元婴中期", monsterRealmId = "huashen_1",  reqLevel = 70,  maxLevel = 85 },
    [6]  = { id = "yuanying_3", name = "元婴后期", monsterRealmId = "huashen_2",  reqLevel = 75,  maxLevel = 85 },
    [7]  = { id = "huashen_1",  name = "化神初期", monsterRealmId = "huashen_3",  reqLevel = 80,  maxLevel = 85 },
    [8]  = { id = "huashen_2",  name = "化神中期", monsterRealmId = "heti_1",     reqLevel = 85,  maxLevel = 100 },
    [9]  = { id = "huashen_3",  name = "化神后期", monsterRealmId = "heti_2",     reqLevel = 90,  maxLevel = 100 },
    [10] = { id = "heti_1",     name = "合体初期", monsterRealmId = "heti_3",     reqLevel = 95,  maxLevel = 100 },
    [11] = { id = "heti_2",     name = "合体中期", monsterRealmId = "dacheng_1",  reqLevel = 100, maxLevel = 120 },
    [12] = { id = "heti_3",     name = "合体后期", monsterRealmId = "dacheng_2",  reqLevel = 105, maxLevel = 120 },
    [13] = { id = "dacheng_1",  name = "大乘初期", monsterRealmId = "dacheng_3",  reqLevel = 110, maxLevel = 120 },
    [14] = { id = "dacheng_2",  name = "大乘中期", monsterRealmId = "dacheng_4",  reqLevel = 115, maxLevel = 120 },
    [15] = { id = "dacheng_3",  name = "大乘后期", monsterRealmId = "dujie_1",    reqLevel = 120, maxLevel = 140 },
}

-- ============================================================================
-- 永久加成里程碑（每5层1次，共30个）
-- 前期(5-50): atk+2, def+2, maxHp+20, hpRegen+0.2
-- 中期(55-100): atk+4, def+3, maxHp+40, hpRegen+0.3
-- 后期(105-150): atk+6, def+4, maxHp+60, hpRegen+0.5
-- 总计: atk+120, def+90, maxHp+1200, hpRegen+10.0
-- ============================================================================

PrisonTowerConfig.MILESTONE_BONUS = {}
for i = 1, 30 do
    local floor = i * 5
    local bonus
    if floor <= 50 then
        bonus = { atk = 2, def = 2, maxHp = 20, hpRegen = 0.2 }
    elseif floor <= 100 then
        bonus = { atk = 4, def = 3, maxHp = 40, hpRegen = 0.3 }
    else
        bonus = { atk = 6, def = 4, maxHp = 60, hpRegen = 0.5 }
    end
    PrisonTowerConfig.MILESTONE_BONUS[floor] = bonus
end

-- ============================================================================
-- 公式函数
-- ============================================================================

--- 根据楼层计算挑战段索引（1..15）
---@param floor number
---@return number segmentIndex
function PrisonTowerConfig.GetSegmentIndex(floor)
    return math.ceil(floor / 10)
end

--- 根据楼层获取层内位置（1..10）
---@param floor number
---@return number localFloor
function PrisonTowerConfig.GetLocalFloor(floor)
    return ((floor - 1) % 10) + 1
end

--- 根据楼层获取境界信息
---@param floor number
---@return table|nil realm, number segmentIndex
function PrisonTowerConfig.GetRealmByFloor(floor)
    local seg = PrisonTowerConfig.GetSegmentIndex(floor)
    return PrisonTowerConfig.REALMS[seg], seg
end

--- 计算怪物等级（怪物目标境界的reqLevel~maxLevel按10层线性插值）
---@param floor number
---@return number level
function PrisonTowerConfig.CalcMonsterLevel(floor)
    local realm = PrisonTowerConfig.GetRealmByFloor(floor)
    if not realm then return 50 end
    local localFloor = PrisonTowerConfig.GetLocalFloor(floor)
    return realm.reqLevel + math.floor((realm.maxLevel - realm.reqLevel) * (localFloor - 1) / 9)
end

--- 计算当前楼层BOSS上阵数量（每5层段内: 1/2/3/4/4）
---@param floor number
---@return number bossCount
function PrisonTowerConfig.CalcBossCount(floor)
    return math.min(((floor - 1) % 5) + 1, 4)
end

--- 计算已解锁BOSS数量（每5层解锁1个）
---@param floor number
---@return number unlockCount
function PrisonTowerConfig.CalcUnlockCount(floor)
    return math.min(30, math.ceil(floor / 5))
end

--- 获取当前楼层实际上阵的BOSS ID列表
--- 规则：
---   第1段(1-5层): 无前置BOSS，数量按 1/2/3/4/4 递增，全为该段主BOSS
---   第2段起(6+层): 始终4个BOSS。新BOSS占 bossCount 个，剩余用前一段BOSS补满
--- 示例：第7层 bossCount=2 → 2个野猪王 + 2个蛛母 = 4个
---@param floor number
---@return table activeBossIds
function PrisonTowerConfig.GetActiveBossIds(floor)
    local bossCount = PrisonTowerConfig.CalcBossCount(floor)

    -- 当前5层段对应的BOSS序号（1-30）
    local segBossIndex = math.min(30, math.ceil(floor / 5))
    local mainBossId = PrisonTowerConfig.BOSS_POOL[segBossIndex]

    local active = {}

    if segBossIndex <= 1 then
        -- 第1段（1-5层）：没有前置BOSS，数量从1递增到4
        for i = 1, bossCount do
            active[i] = mainBossId
        end
    else
        -- 第2段起：始终4个BOSS
        -- 新BOSS占 bossCount 个位置
        for i = 1, bossCount do
            active[i] = mainBossId
        end
        -- 前一段BOSS补满剩余位置（4 - bossCount 个）
        local prevBossId = PrisonTowerConfig.BOSS_POOL[segBossIndex - 1]
        for i = bossCount + 1, 4 do
            active[i] = prevBossId
        end
    end

    return active
end

--- 获取BOSS的有效数值档位（不低于emperor_boss）
---@param originalCategory string 原始怪物类别
---@return string effectiveCategory
function PrisonTowerConfig.GetEffectiveCategory(originalCategory)
    local origOrder = CATEGORY_ORDER[originalCategory] or 0
    local emperorOrder = CATEGORY_ORDER.emperor_boss
    if origOrder < emperorOrder then
        return "emperor_boss"
    end
    return originalCategory
end

--- 计算指定highestFloor下的永久加成总和
---@param highestFloor number
---@return table bonuses { atk, def, maxHp, hpRegen }
function PrisonTowerConfig.GetAllBonuses(highestFloor)
    local bonuses = { atk = 0, def = 0, maxHp = 0, hpRegen = 0 }
    if not highestFloor or highestFloor <= 0 then
        return bonuses
    end

    for floor, bonus in pairs(PrisonTowerConfig.MILESTONE_BONUS) do
        if highestFloor >= floor then
            bonuses.atk = bonuses.atk + (bonus.atk or 0)
            bonuses.def = bonuses.def + (bonus.def or 0)
            bonuses.maxHp = bonuses.maxHp + (bonus.maxHp or 0)
            bonuses.hpRegen = bonuses.hpRegen + (bonus.hpRegen or 0)
        end
    end

    return bonuses
end

return PrisonTowerConfig
