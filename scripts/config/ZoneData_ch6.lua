-- ============================================================================
-- ZoneData_ch6.lua - 第六章区域数据聚合（陆章·两界村之影）
-- 目标：复刻第一章地图结构，但运行期实体完全独立，避免第六章调整影响第一章。
-- ============================================================================

local ZoneData_ch6 = {}

local baseZoneData = require("config.ZoneData")
local townData = require("config.zones.town")
local narrowTrailData = require("config.zones.narrow_trail")
local spiderCaveData = require("config.zones.spider_cave")
local boarForestData = require("config.zones.boar_forest")
local banditCampData = require("config.zones.bandit_camp")
local tigerDomainData = require("config.zones.tiger_domain")
local wildernessData = require("config.zones.wilderness")

local TileTypes = require("config.TileTypes")
ZoneData_ch6.TILE = TileTypes.TILE
ZoneData_ch6.WALKABLE = TileTypes.WALKABLE

ZoneData_ch6.CHAPTER_ID = 6
ZoneData_ch6.IS_SHADOW_LIANGJIE = true

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = copyTable(v)
    end
    return dst
end

local function terrainOnly(src)
    return {
        regions = copyTable(src.regions),
        generation = copyTable(src.generation),
        gates = copyTable(src.gates),
        roads = copyTable(src.roads),
    }
end

-- 只复用第一章地形生成所需字段；不复用 npcs / decorations / spawns。
local townShadow = terrainOnly(townData)
local narrowTrailShadow = terrainOnly(narrowTrailData)
local spiderCaveShadow = terrainOnly(spiderCaveData)
local boarForestShadow = terrainOnly(boarForestData)
local banditCampShadow = terrainOnly(banditCampData)
local tigerDomainShadow = terrainOnly(tigerDomainData)
local wildernessShadow = terrainOnly(wildernessData)

-- 第六章专用地形覆盖：只改 copy 后的数据，不影响第一章原始 zone 配置。
banditCampShadow.regions.bandit_backhill = {
    x1 = 33, y1 = 4, x2 = 55, y2 = 20,
    zone = "bandit_camp",
}

local ALL_ZONES = {
    townShadow,
    narrowTrailShadow,
    spiderCaveShadow,
    boarForestShadow,
    banditCampShadow,
    tigerDomainShadow,
    wildernessShadow,
}

ZoneData_ch6.ZONES = {
    SHADOW_SPAWN_SAFE = "shadow_spawn_safe",
    VILLAGE_NORTH_RUINS = "village_north_ruins",
    TOWN = "town",
    NARROW_TRAIL = "narrow_trail",
    SPIDER_CAVE = "spider_cave",
    BOAR_FOREST = "boar_forest",
    BANDIT_CAMP = "bandit_camp",
    TIGER_DOMAIN = "tiger_domain",
    WILDERNESS = "wilderness",
}

ZoneData_ch6.Regions = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.regions then
        for name, region in pairs(zoneModule.regions) do
            ZoneData_ch6.Regions[name] = region
        end
    end
end

-- 第六章出生安全区位于蛛网小径右侧入口；与 narrow_trail 重叠，使用 REGION_PRIORITY 保证识别稳定。
ZoneData_ch6.Regions.shadow_spawn_safe = {
    x1 = 72, y1 = 35, x2 = 79, y2 = 45,
    zone = "shadow_spawn_safe",
}

-- 两界村上方、后山寨下方的旧场区域；第六章中向上抬两格并与后山自然连通。
ZoneData_ch6.Regions.village_north_ruins = {
    x1 = 34, y1 = 22, x2 = 54, y2 = 29,
    zone = "village_north_ruins",
}
ZoneData_ch6.REGION_PRIORITY = { "shadow_spawn_safe", "village_north_ruins" }

-- 明确清空运行期实体，避免把第一章 NPC、装饰、刷怪点带入第六章。
ZoneData_ch6.SpawnPoints = {}
ZoneData_ch6.TownDecorations = {}
ZoneData_ch6.NPCs = {}

-- 第六章两界村保留入口形态，门洞由 Chapter6 后处理改为封印光幕。
ZoneData_ch6.TOWN_GATES = copyTable(townData.gates) or {}
ZoneData_ch6.SPAWN_POINT = { x = 76.5, y = 40.5 }
ZoneData_ch6.ALL_ZONES = ALL_ZONES

ZoneData_ch6.TILE_COLORS = copyTable(baseZoneData.TILE_COLORS)
ZoneData_ch6.WALKABLE_TILES = copyTable(baseZoneData.WALKABLE_TILES)
ZoneData_ch6.TILE_TRANSITION_COLORS = copyTable(baseZoneData.TILE_TRANSITION_COLORS)

ZoneData_ch6.AMBIENT = {
    enabled = true,
    mode = "night_shadow_village",
    tint = { 18, 28, 55, 88 },
    vignette = { 0, 0, 0, 135 },
    mist = { 72, 92, 135, 26 },
}

ZoneData_ch6.BESTIARY_ZONES = {
    order = {
        "shadow_spawn_safe", "village_north_ruins", "wilderness", "narrow_trail", "spider_cave",
        "boar_forest", "bandit_camp", "bandit_backhill", "tiger_domain",
    },
    names = {
        shadow_spawn_safe = "蛛网小径·影入口",
        village_north_ruins = "影游荒原",
        wilderness = "影游荒原",
        narrow_trail = "羊肠小径",
        spider_cave = "界守·东大营",
        boar_forest = "呱大人领地",
        bandit_camp = "界守·西大营",
        bandit_backhill = "两界山",
        tiger_domain = "虎王封印地",
    },
}

ZoneData_ch6.ZONE_INFO = {
    shadow_spawn_safe = { name = "蛛网小径·影入口", levelRange = nil },
    village_north_ruins = { name = "影游荒原", levelRange = {122, 124} },
    town = { name = "封印的两界村", levelRange = nil },
    trial_area = { name = "影·青云试炼旧址", levelRange = nil },
    narrow_trail = { name = "羊肠小径", levelRange = {121, 122} },
    spider_cave = { name = "界守·东大营", levelRange = {137, 140} },
    boar_forest = { name = "呱大人领地", levelRange = {139, 140} },
    bandit_camp = { name = "界守·西大营", levelRange = {136, 140} },
    bandit_backhill = { name = "两界山", levelRange = {124, 126} },
    tiger_domain = { name = "虎王封印地", levelRange = {136, 140} },
    wilderness = { name = "影游荒原", levelRange = {122, 124} },
}

return ZoneData_ch6
