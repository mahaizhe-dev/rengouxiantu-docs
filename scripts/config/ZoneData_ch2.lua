-- ============================================================================
-- ZoneData_ch2.lua - 第二章区域数据聚合（贰章·乌家堡）
-- 结构与 ZoneData.lua 完全一致，供 GameMap 数据驱动生成使用
-- ============================================================================

local ZoneData_ch2 = {}

-- 加载各区域数据
local campAData     = require("config.zones.chapter2.camp_a")
local wildBData     = require("config.zones.chapter2.wild_b")
local wildCData     = require("config.zones.chapter2.wild_c")
local skullDData    = require("config.zones.chapter2.skull_d")
local fortressEData = require("config.zones.chapter2.fortress_e")

-- 所有区域模块列表
local ALL_ZONES = {
    campAData,
    wildBData,
    wildCData,
    skullDData,
    fortressEData,
}

-- ============================================================================
-- 区域枚举
-- ============================================================================

ZoneData_ch2.ZONES = {
    CAMP_A       = "camp_a",
    WILD_B       = "wild_b",
    WILD_C       = "wild_c",
    SKULL_D      = "skull_d",
    FORTRESS_E1  = "fortress_e1",
    FORTRESS_E2  = "fortress_e2",
    FORTRESS_E3  = "fortress_e3",
    FORTRESS_E4  = "fortress_e4",
}

-- ============================================================================
-- 瓦片类型与通行性（引用共享资源库 TileTypes，与 ch1 完全解耦）
-- ============================================================================

local TileTypes = require("config.TileTypes")
ZoneData_ch2.TILE = TileTypes.TILE
ZoneData_ch2.WALKABLE = TileTypes.WALKABLE

-- ============================================================================
-- 从各区域文件汇总 Regions / SpawnPoints / Decorations / NPCs
-- ============================================================================

-- 区域范围
ZoneData_ch2.Regions = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.regions then
        for name, region in pairs(zoneModule.regions) do
            ZoneData_ch2.Regions[name] = region
        end
    end
end

-- 怪物刷新点
ZoneData_ch2.SpawnPoints = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.spawns then
        for _, sp in ipairs(zoneModule.spawns) do
            table.insert(ZoneData_ch2.SpawnPoints, sp)
        end
    end
end

-- 装饰物
ZoneData_ch2.TownDecorations = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.decorations then
        for _, deco in ipairs(zoneModule.decorations) do
            table.insert(ZoneData_ch2.TownDecorations, deco)
        end
    end
end

-- NPC
ZoneData_ch2.NPCs = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.npcs then
        for _, npc in ipairs(zoneModule.npcs) do
            table.insert(ZoneData_ch2.NPCs, npc)
        end
    end
end

-- 堡垒数据引用（供 GameMap 堡垒生成器使用）
ZoneData_ch2.fortressData = fortressEData
ZoneData_ch2.skullData = skullDData

-- 主城围墙出入口（第二章无传统主城围墙，置空）
ZoneData_ch2.TOWN_GATES = {}

-- 玩家出生点（A区营地）
ZoneData_ch2.SPAWN_POINT = campAData.spawnPoint or { x = 7.5, y = 40.5 }

-- 暴露所有区域模块列表
ZoneData_ch2.ALL_ZONES = ALL_ZONES

-- ============================================================================
-- 瓦片颜色定义（供 TileRenderer / WorldRenderer 数据驱动读取）
-- ============================================================================
local T = ZoneData_ch2.TILE

-- 纯色瓦片的填充色 {r, g, b, a}（ch1 基础色 + ch2 新增）
ZoneData_ch2.TILE_COLORS = {
    -- ch1 共享瓦片
    [T.GRASS]        = {80, 140, 60, 255},
    [T.CAVE_FLOOR]   = {100, 90, 80, 255},
    [T.FOREST_FLOOR] = {50, 100, 40, 255},
    [T.MOUNTAIN]     = {120, 110, 100, 255},
    [T.WATER]        = {60, 120, 180, 255},
    [T.CAMP_FLOOR]   = {100, 90, 80, 255},
    [T.TIGER_GROUND] = {35, 75, 30, 255},
    -- ch2 新增瓦片
    [T.FORTRESS_WALL]  = {60, 55, 50, 255},
    [T.FORTRESS_FLOOR] = {90, 70, 60, 255},
    [T.SWAMP]          = {50, 65, 40, 255},
    [T.SEALED_GATE]    = {80, 70, 30, 255},
    [T.CRYSTAL_STONE]  = {100, 60, 120, 255},
    [T.CAMP_DIRT]      = {120, 100, 70, 255},
    [T.BATTLEFIELD]    = {75, 55, 40, 255},
}

-- 可通行瓦片集合（区域过渡渐变用）
ZoneData_ch2.WALKABLE_TILES = {
    -- ch1 共享
    [T.GRASS] = true, [T.TOWN_FLOOR] = true, [T.TOWN_ROAD] = true,
    [T.CAVE_FLOOR] = true, [T.FOREST_FLOOR] = true,
    [T.CAMP_FLOOR] = true, [T.TIGER_GROUND] = true,
    -- ch2 新增
    [T.FORTRESS_FLOOR] = true,
    [T.SWAMP] = true,
    [T.CAMP_DIRT] = true,
    [T.BATTLEFIELD] = true,
}

-- 区域过渡渐变色 {r, g, b}
ZoneData_ch2.TILE_TRANSITION_COLORS = {
    -- ch1 共享
    [T.GRASS]        = {80, 140, 60},
    [T.TOWN_FLOOR]   = {160, 130, 100},
    [T.CAVE_FLOOR]   = {95, 85, 75},
    [T.FOREST_FLOOR] = {50, 100, 40},
    [T.CAMP_FLOOR]   = {105, 90, 70},
    [T.TIGER_GROUND] = {40, 70, 35},
    -- ch2 新增
    [T.FORTRESS_FLOOR] = {90, 70, 60},
    [T.SWAMP]          = {50, 65, 40},
    [T.CAMP_DIRT]      = {120, 100, 70},
    [T.BATTLEFIELD]    = {75, 55, 40},
}

-- ============================================================================
-- 区域信息（供 ZoneManager / SystemMenu 数据驱动读取）
-- ============================================================================

-- 图鉴区域分组（供 SystemMenu 怪物图鉴展示，key = MonsterData.zone）
ZoneData_ch2.BESTIARY_ZONES = {
    order = {
        "wilderness_ch2", "boar_slope", "snake_swamp", "shura_field",
        "wu_fortress", "wu_fortress_north", "wu_fortress_south",
        "wu_fortress_main", "wu_fortress_hall",
    },
    names = {
        wilderness_ch2      = "荒野·外域",
        boar_slope          = "野猪坡",
        snake_swamp         = "蛇沼",
        shura_field         = "修罗场",
        wu_fortress         = "乌家堡·外围",
        wu_fortress_north   = "乌家堡·北院",
        wu_fortress_south   = "乌家堡·南院",
        wu_fortress_main    = "乌家堡·主殿",
        wu_fortress_hall    = "乌家堡·大殿",
    },
}

ZoneData_ch2.ZONE_INFO = {
    camp_a        = { name = "临时营地",   levelRange = nil },
    wild_b        = { name = "野猪坡",     levelRange = {10, 15} },
    wild_c        = { name = "毒蛇沼",     levelRange = {10, 15} },
    skull_d       = { name = "修罗场",     levelRange = {12, 18} },
    fortress_e1   = { name = "乌家北堡",   levelRange = {14, 20} },
    fortress_e2   = { name = "乌家南堡",   levelRange = {14, 20} },
    fortress_e3   = { name = "乌堡大殿",   levelRange = {18, 25} },
    fortress_e4   = { name = "乌家主堡",   levelRange = {16, 22} },
}

return ZoneData_ch2
