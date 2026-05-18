-- ============================================================================
-- SwordPoolConfig.lua - 祀剑池配置
-- 消耗太虚剑令(taixu_jianling)解锁BOSS房间并升级
-- 解锁消耗1000，升级消耗与海神柱一致
-- 每把剑对应一个BOSS房间封印 + 一种属性加成
-- ============================================================================

local SwordPoolConfig = {}

-- 解锁消耗（太虚剑令）
SwordPoolConfig.UNLOCK_COST = 1000

-- 最大等级
SwordPoolConfig.MAX_LEVEL = 10

-- 每级升级消耗（与海神柱一致）
SwordPoolConfig.UPGRADE_COSTS = {
    [1]  = 500,
    [2]  = 750,
    [3]  = 1000,
    [4]  = 1250,
    [5]  = 1500,
    [6]  = 1750,
    [7]  = 2000,
    [8]  = 2250,
    [9]  = 2500,
    [10] = 3000,
}

-- 消耗的货币ID
SwordPoolConfig.CURRENCY_ID = "taixu_jianling"
SwordPoolConfig.CURRENCY_NAME = "太虚剑令"

-- 四把仙剑定义
SwordPoolConfig.SWORDS = {
    zhu = {
        id = "zhu",
        name = "诛仙剑封印",
        icon = "⚔️",
        image = "image/icon_fengyin_zhuxian_ch5_20260518083648.png",
        color = {200, 60, 40, 255},
        sealId = "seal_ch5_boss_zhu",
        bossId = "ch5_sword_zhu",
        bonusStat = "atk",
        bonusLabel = "攻击",
        bonusPerLevel = 5,
    },
    xian = {
        id = "xian",
        name = "陷仙剑封印",
        icon = "🗡️",
        image = "image/icon_fengyin_xianxian_ch5_20260518085543.png",
        color = {40, 80, 200, 255},
        sealId = "seal_ch5_boss_xian",
        bossId = "ch5_sword_xian",
        bonusStat = "def",
        bonusLabel = "防御",
        bonusPerLevel = 5,
    },
    lu = {
        id = "lu",
        name = "戮仙剑封印",
        icon = "🔪",
        image = "image/icon_fengyin_luxian_ch5_20260518083709.png",
        color = {60, 180, 60, 255},
        sealId = "seal_ch5_boss_lu",
        bossId = "ch5_sword_lu",
        bonusStat = "maxHp",
        bonusLabel = "生命上限",
        bonusPerLevel = 50,
    },
    jue = {
        id = "jue",
        name = "绝仙剑封印",
        icon = "💀",
        image = "image/icon_fengyin_juexian_ch5_20260518083649.png",
        color = {180, 60, 180, 255},
        sealId = "seal_ch5_boss_jue",
        bossId = "ch5_sword_jue",
        bonusStat = "hpRegen",
        bonusLabel = "生命回复",
        bonusPerLevel = 5,
    },
}

-- 有序列表（UI显示用）
SwordPoolConfig.SWORD_ORDER = { "zhu", "xian", "lu", "jue" }

--- 获取指定等级的升级消耗
---@param level number 目标等级（1~10）
---@return number|nil
function SwordPoolConfig.GetUpgradeCost(level)
    return SwordPoolConfig.UPGRADE_COSTS[level]
end

--- 获取某剑某级的属性加成总值
---@param swordId string
---@param level number 当前等级
---@return number bonus
function SwordPoolConfig.GetTotalBonus(swordId, level)
    local cfg = SwordPoolConfig.SWORDS[swordId]
    if not cfg then return 0 end
    return cfg.bonusPerLevel * level
end

return SwordPoolConfig
