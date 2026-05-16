-- ============================================================================
-- QuestData_ch5.lua - 第五章·太虚之殇 封印数据
-- 与其他章节完全独立，由 QuestSystem.Init() 合并加载
-- 4 处封印：2 处白色（剑气城墙入口）+ 2 处红色（剑宫入口）
-- ============================================================================

local TileTypes = require("config.TileTypes")

local QuestData_ch5 = {}

--- 区域主线任务链（占位，暂不开发内容）
QuestData_ch5.ZONE_QUESTS = {
    -- ── 剑气城墙主线（白色封印关联） ──
    ch5_corridor_quest = {
        id = "ch5_corridor_quest",
        name = "剑气城墙封印",
        zone = "ch5_sword_corridor",
        chapter = 5,
        steps = {},  -- 暂不开发
    },
    -- ── 太虚剑宫主线（红色封印关联） ──
    ch5_palace_quest = {
        id = "ch5_palace_quest",
        name = "太虚剑宫封印",
        zone = "ch5_sword_palace",
        chapter = 5,
        steps = {},  -- 暂不开发
    },
}

--- 封印数据
--- sealColor: "white" | "red" 用于渲染区分同章节不同风格
QuestData_ch5.SEALS = {
    -- ═══ 白色封印：剑气城墙入口 ═══

    -- 左路入口（别院→城墙桥 末段，cx=12，y=66~67）
    seal_ch5_corridor_left = {
        questChain = "ch5_corridor_quest",
        sealColor = "white",
        sealTiles = {
            {x = 11, y = 66}, {x = 12, y = 66}, {x = 13, y = 66},
            {x = 11, y = 67}, {x = 12, y = 67}, {x = 13, y = 67},
        },
        originalTile = TileTypes.TILE.CH5_BRIDGE,
        promptText = "剑气封印阻隔去路",
        promptRange = 3.0,
    },

    -- 右路入口（藏经阁→城墙桥 末段，cx=67，y=66~67）
    seal_ch5_corridor_right = {
        questChain = "ch5_corridor_quest",
        sealColor = "white",
        sealTiles = {
            {x = 66, y = 66}, {x = 67, y = 66}, {x = 68, y = 66},
            {x = 66, y = 67}, {x = 67, y = 67}, {x = 68, y = 67},
        },
        originalTile = TileTypes.TILE.CH5_BRIDGE,
        promptText = "剑气封印阻隔去路",
        promptRange = 3.0,
    },

    -- ═══ 红色封印：太虚剑宫入口 ═══

    -- 左入口（别院→剑宫桥 进入剑宫处，x=26~27，y=31~33）
    seal_ch5_palace_left = {
        questChain = "ch5_palace_quest",
        sealColor = "red",
        sealTiles = {
            {x = 26, y = 31}, {x = 27, y = 31},
            {x = 26, y = 32}, {x = 27, y = 32},
            {x = 26, y = 33}, {x = 27, y = 33},
        },
        originalTile = TileTypes.TILE.CH5_PALACE_WHITE,
        promptText = "血色封印封锁剑宫",
        promptRange = 3.0,
    },

    -- 右入口（碑林→剑宫桥 进入剑宫处，x=53~54，y=31~33）
    seal_ch5_palace_right = {
        questChain = "ch5_palace_quest",
        sealColor = "red",
        sealTiles = {
            {x = 53, y = 31}, {x = 54, y = 31},
            {x = 53, y = 32}, {x = 54, y = 32},
            {x = 53, y = 33}, {x = 54, y = 33},
        },
        originalTile = TileTypes.TILE.CH5_PALACE_WHITE,
        promptText = "血色封印封锁剑宫",
        promptRange = 3.0,
    },
}

return QuestData_ch5
