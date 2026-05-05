-- ============================================================================
-- SeaPillarConfig.lua - 海神柱配置
-- 四根海神柱对应四座兽岛，需要太虚令修复和升级
-- 阶段1：消耗1000太虚令修复传送阵（开启传送，无属性加成）
-- 阶段2：消耗太虚令升级（10级），每级提供永久属性加成
-- ============================================================================

local SeaPillarConfig = {}

-- 修复消耗
SeaPillarConfig.REPAIR_COST = 1000

-- 最大等级
SeaPillarConfig.MAX_LEVEL = 10

-- 每级升级消耗
SeaPillarConfig.UPGRADE_COSTS = {
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

-- 四根海神柱定义
-- pillarId 与八卦阵NPC的 pillarId 字段对应
SeaPillarConfig.PILLARS = {
    xuanbing = {
        id = "xuanbing",
        name = "玄冰海神柱",
        icon = "🧊",
        element = "冰",
        color = {100, 160, 220, 255},
        -- 修复后传送目标（玄冰岛）
        teleportTarget = { x = 7.5, y = 10.5, island = "beast_north" },
        -- 属性加成
        bonusStat = "def",
        bonusLabel = "防御",
        bonusPerLevel = 2,
    },
    youyuan = {
        id = "youyuan",
        name = "幽渊海神柱",
        icon = "🌀",
        element = "渊",
        color = {100, 50, 180, 255},
        teleportTarget = { x = 71.5, y = 11.5, island = "beast_east" },
        bonusStat = "atk",
        bonusLabel = "攻击",
        bonusPerLevel = 3,
    },
    lieyan = {
        id = "lieyan",
        name = "烈焰海神柱",
        icon = "🔥",
        element = "火",
        color = {240, 80, 20, 255},
        teleportTarget = { x = 70.5, y = 74.5, island = "beast_south" },
        bonusStat = "maxHp",
        bonusLabel = "生命上限",
        bonusPerLevel = 30,
    },
    liusha = {
        id = "liusha",
        name = "流沙海神柱",
        icon = "🏜️",
        element = "沙",
        color = {200, 170, 80, 255},
        teleportTarget = { x = 8.5, y = 73.5, island = "beast_west" },
        bonusStat = "hpRegen",
        bonusLabel = "生命回复",
        bonusPerLevel = 3,
    },
}

-- pillarId → 八卦阵zone映射（用于UI显示来源信息）
SeaPillarConfig.PILLAR_ZONE_MAP = {
    xuanbing = "ch4_qian",  -- 乾阵
    youyuan  = "ch4_gen",   -- 艮阵
    lieyan   = "ch4_xun",   -- 巽阵
    liusha   = "ch4_kun",   -- 坤阵
}

-- 有序列表（UI显示用）
SeaPillarConfig.PILLAR_ORDER = { "xuanbing", "youyuan", "lieyan", "liusha" }

--- 获取指定等级的升级消耗
---@param level number 目标等级（1~10）
---@return number|nil
function SeaPillarConfig.GetUpgradeCost(level)
    return SeaPillarConfig.UPGRADE_COSTS[level]
end

--- 获取某柱某级的属性加成总值
---@param pillarId string
---@param level number 当前等级（0=已修复未升级）
---@return number bonus
function SeaPillarConfig.GetTotalBonus(pillarId, level)
    local cfg = SeaPillarConfig.PILLARS[pillarId]
    if not cfg then return 0 end
    return cfg.bonusPerLevel * level
end

return SeaPillarConfig
