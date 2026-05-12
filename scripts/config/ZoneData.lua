-- ============================================================================
-- ZoneData.lua - 区域数据聚合（从按区域独立的数据文件汇总）
-- ============================================================================

local ZoneData = {}

-- 加载各区域数据
local townData         = require("config.zones.town")
local narrowTrailData  = require("config.zones.narrow_trail")
local spiderCaveData   = require("config.zones.spider_cave")
local boarForestData   = require("config.zones.boar_forest")
local banditCampData   = require("config.zones.bandit_camp")
local tigerDomainData  = require("config.zones.tiger_domain")
local wildernessData   = require("config.zones.wilderness")
local xianyuanRoomsData = require("config.zones.xianyuan_rooms")

-- 所有区域模块列表（方便遍历，未来新增区域只需在此追加）
-- ⚠️ xianyuanRoomsData 必须在末尾，覆盖原有地形生成 5×5 藏宝室
local ALL_ZONES = {
    townData,
    narrowTrailData,
    spiderCaveData,
    boarForestData,
    banditCampData,
    tigerDomainData,
    wildernessData,
    xianyuanRoomsData,
}

-- ============================================================================
-- 区域枚举（不变）
-- ============================================================================

ZoneData.ZONES = {
    TOWN = "town",
    NARROW_TRAIL = "narrow_trail",
    SPIDER_CAVE = "spider_cave",
    BOAR_FOREST = "boar_forest",
    BANDIT_CAMP = "bandit_camp",
    TIGER_DOMAIN = "tiger_domain",
}

-- ============================================================================
-- 瓦片类型与通行性（引用共享资源库 TileTypes）
-- ============================================================================

local TileTypes = require("config.TileTypes")
ZoneData.TILE = TileTypes.TILE
ZoneData.WALKABLE = TileTypes.WALKABLE

-- ============================================================================
-- 从各区域文件汇总 Regions / SpawnPoints / Decorations / NPCs
-- ============================================================================

-- 区域范围
ZoneData.Regions = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.regions then
        for name, region in pairs(zoneModule.regions) do
            ZoneData.Regions[name] = region
        end
    end
end

-- 怪物刷新点
ZoneData.SpawnPoints = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.spawns then
        for _, sp in ipairs(zoneModule.spawns) do
            table.insert(ZoneData.SpawnPoints, sp)
        end
    end
end

-- 装饰物（原 TownDecorations，实际包含所有区域）
ZoneData.TownDecorations = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.decorations then
        for _, deco in ipairs(zoneModule.decorations) do
            table.insert(ZoneData.TownDecorations, deco)
        end
    end
end

-- NPC（目前仅主城有）
ZoneData.NPCs = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.npcs then
        for _, npc in ipairs(zoneModule.npcs) do
            table.insert(ZoneData.NPCs, npc)
        end
    end
end

-- 主城围墙出入口
ZoneData.TOWN_GATES = townData.gates or {}

-- 玩家出生点
ZoneData.SPAWN_POINT = townData.spawnPoint or { x = 40.5, y = 40.5 }

-- 暴露所有区域模块列表（供 GameMap 数据驱动生成使用）
ZoneData.ALL_ZONES = ALL_ZONES

-- ============================================================================
-- 瓦片颜色定义（供 TileRenderer / WorldRenderer 数据驱动读取）
-- ============================================================================
local T = ZoneData.TILE

-- 纯色瓦片的填充色 {r, g, b, a}
ZoneData.TILE_COLORS = {
    [T.GRASS]        = {80, 140, 60, 255},
    [T.CAVE_FLOOR]   = {100, 90, 80, 255},
    [T.FOREST_FLOOR] = {50, 100, 40, 255},
    [T.MOUNTAIN]     = {120, 110, 100, 255},
    [T.WATER]        = {60, 120, 180, 255},
    [T.CAMP_FLOOR]   = {100, 90, 80, 255},
    [T.TIGER_GROUND] = {35, 75, 30, 255},
}

-- 可通行瓦片集合（区域过渡渐变用）
ZoneData.WALKABLE_TILES = {
    [T.GRASS] = true, [T.TOWN_FLOOR] = true, [T.TOWN_ROAD] = true,
    [T.CAVE_FLOOR] = true, [T.FOREST_FLOOR] = true,
    [T.CAMP_FLOOR] = true, [T.TIGER_GROUND] = true,
}

-- 区域过渡渐变色 {r, g, b}
ZoneData.TILE_TRANSITION_COLORS = {
    [T.GRASS]        = {80, 140, 60},
    [T.TOWN_FLOOR]   = {160, 130, 100},
    [T.CAVE_FLOOR]   = {95, 85, 75},
    [T.FOREST_FLOOR] = {50, 100, 40},
    [T.CAMP_FLOOR]   = {105, 90, 70},
    [T.TIGER_GROUND] = {40, 70, 35},
}

-- ============================================================================
-- 区域信息（供 ZoneManager / SystemMenu 数据驱动读取）
-- ============================================================================

-- 图鉴区域分组（供 SystemMenu 怪物图鉴展示，key = MonsterData.zone）
ZoneData.BESTIARY_ZONES = {
    order = {
        "wilderness", "narrow_trail", "spider_cave",
        "boar_forest", "bandit_camp", "bandit_backhill", "tiger_domain",
    },
    names = {
        wilderness      = "荒野",
        narrow_trail    = "羊肠小径",
        spider_cave     = "蜘蛛洞",
        boar_forest     = "野猪林",
        bandit_camp     = "山贼寨主寨",
        bandit_backhill = "山贼寨后山",
        tiger_domain    = "虎啸林",
    },
}

ZoneData.ZONE_INFO = {
    town          = { name = "两界村",   levelRange = nil },
    narrow_trail  = { name = "羊肠小径", levelRange = {1, 3} },
    spider_cave   = { name = "蜘蛛洞",   levelRange = {2, 5} },
    boar_forest   = { name = "野猪林",   levelRange = {3, 8} },
    bandit_camp   = { name = "山贼寨",   levelRange = {6, 10} },
    tiger_domain  = { name = "虎王领地", levelRange = {8, 10} },
    wilderness    = { name = "荒野",     levelRange = nil },
}

return ZoneData
