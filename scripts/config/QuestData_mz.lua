-- ============================================================================
-- QuestData_mz.lua - 中洲封印数据（战场入口封印）
-- 由 QuestSystem.Init() 合并到 QuestData.SEALS
-- ============================================================================

local TileTypes = require("config.TileTypes")

local QuestData_mz = {}

-- 中洲任务链（仅用于封印章节归属检测，修为等级解锁而非任务驱动）
QuestData_mz.ZONE_QUESTS = {
    mz_battle_jie_zone = {
        zone = "mz_battle_jie",
        chapter = 101,
        name = "仙劫战场",
        steps = {},
    },
    mz_battle_luo_zone = {
        zone = "mz_battle_luo",
        chapter = 101,
        name = "仙陨战场",
        steps = {},
    },
    mz_battle_yun_zone = {
        zone = "mz_battle_yun",
        chapter = 101,
        name = "仙殒战场",
        steps = {},
    },
}

-- 封印数据：三大战场入口（南侧桥头，2行深红色封印）
-- requiredRealmOrder: 境界 order 门槛（合体16/大乘19/渡劫23）
-- requiredRealmName: 显示用境界名
-- realmDriven: true 表示此封印由境界驱动（交互解封），而非任务链驱动
QuestData_mz.SEALS = {
    mz_battle_jie = {
        questChain = "mz_battle_jie_zone",
        sealTiles = {
            {x = 11, y = 23}, {x = 12, y = 23},
            {x = 13, y = 23}, {x = 14, y = 23},
            {x = 11, y = 24}, {x = 12, y = 24},
            {x = 13, y = 24}, {x = 14, y = 24},
        },
        originalTile = TileTypes.TILE.BRIDGE_FLOOR,
        sealTile = TileTypes.TILE.SEAL_RED,
        promptText = "仙劫封印：需达到合体期修为方可解封",
        promptRange = 3.0,
        realmDriven = true,
        requiredRealmOrder = 16,
        requiredRealmName = "合体期",
        requiredLevel = 100,
    },
    mz_battle_luo = {
        questChain = "mz_battle_luo_zone",
        sealTiles = {
            {x = 38, y = 23}, {x = 39, y = 23},
            {x = 40, y = 23}, {x = 41, y = 23},
            {x = 42, y = 23},
            {x = 38, y = 24}, {x = 39, y = 24},
            {x = 40, y = 24}, {x = 41, y = 24},
            {x = 42, y = 24},
        },
        originalTile = TileTypes.TILE.BRIDGE_FLOOR,
        sealTile = TileTypes.TILE.SEAL_RED,
        promptText = "仙陨封印：需渡劫期修为（Lv.140）方可解封",
        promptRange = 3.0,
        realmDriven = true,
        requiredRealmOrder = 23,
        requiredRealmName = "渡劫期",
        requiredLevel = 140,
    },
    mz_battle_yun = {
        questChain = "mz_battle_yun_zone",
        sealTiles = {
            {x = 65, y = 23}, {x = 66, y = 23},
            {x = 67, y = 23}, {x = 68, y = 23},
            {x = 65, y = 24}, {x = 66, y = 24},
            {x = 67, y = 24}, {x = 68, y = 24},
        },
        originalTile = TileTypes.TILE.BRIDGE_FLOOR,
        sealTile = TileTypes.TILE.SEAL_RED,
        promptText = "仙殒封印：需大乘期修为（Lv.120）方可解封",
        promptRange = 3.0,
        realmDriven = true,
        requiredRealmOrder = 19,
        requiredRealmName = "大乘期",
        requiredLevel = 120,
    },
}

return QuestData_mz
