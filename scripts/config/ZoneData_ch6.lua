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
    zone = "bandit_backhill",
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
ZoneData_ch6.REGION_PRIORITY = { "shadow_spawn_safe", "village_north_ruins", "bandit_backhill" }

-- 第六章运行期实体独立配置：只使用第六章怪物，不复用第一章刷怪点。
ZoneData_ch6.SpawnPoints = {
    -- 羊肠小径：普通BOSS按小怪式多点刷新，避开右侧影入口安全区。
    { type = "ch6_patrol_immortal_soldier", x = 55.5, y = 33.5 },
    { type = "ch6_patrol_immortal_soldier", x = 61.5, y = 35.5 },
    { type = "ch6_patrol_immortal_soldier", x = 66.5, y = 33.5 },
    { type = "ch6_patrol_immortal_soldier", x = 59.5, y = 45.5 },
    { type = "ch6_patrol_immortal_soldier", x = 68.5, y = 47.5 },
    {
        type = "ch6_lingfeng", x = 64.5, y = 38.5,
        patrolPreset = "large_waypoint_loop",
        patrol = {
            nodes = {
                { x = 56, y = 34 },
                { x = 64, y = 33 },
                { x = 70, y = 34 },
                { x = 70, y = 46 },
                { x = 62, y = 46 },
                { x = 56, y = 42 },
            },
        },
    },

    -- 影游荒原：上方领地 2 个小怪 + 夜游神；村庄外围 4 个小怪环绕。
    { type = "ch6_shadow_wanderer", x = 36.5, y = 25.5 },
    { type = "ch6_shadow_wanderer", x = 49.5, y = 26.5 },
    { type = "ch6_shadow_wanderer", x = 31.5, y = 37.5 },
    { type = "ch6_shadow_wanderer", x = 50.5, y = 38.5 },
    { type = "ch6_shadow_wanderer", x = 36.5, y = 50.5 },
    { type = "ch6_shadow_wanderer", x = 46.5, y = 50.5 },
    { type = "ch6_zhuyou", x = 42.5, y = 25.5 },

    -- 两界山
    { type = "ch6_mountain_colossus", x = 36.5, y = 8.5 },
    { type = "ch6_mountain_colossus", x = 43.5, y = 8.5 },
    { type = "ch6_mountain_colossus", x = 51.5, y = 8.5 },
    { type = "ch6_mountain_colossus", x = 38.5, y = 16.5 },
    { type = "ch6_mountain_colossus", x = 50.5, y = 17.5 },
    { type = "ch6_duanyue", x = 44.5, y = 13.5 },

    -- 界守·西大营
    { type = "ch6_west_celestial_soldier", x = 7.5,  y = 8.5 },
    { type = "ch6_west_celestial_soldier", x = 16.5, y = 8.5 },
    { type = "ch6_west_celestial_soldier", x = 25.5, y = 12.5 },
    { type = "ch6_west_celestial_soldier", x = 26.5, y = 28.5 },
    { type = "ch6_west_celestial_soldier", x = 22.5, y = 22.5 },
    { type = "ch6_west_celestial_soldier", x = 7.5,  y = 32.5 },
    { type = "ch6_west_celestial_soldier", x = 17.5, y = 34.5 },
    { type = "ch6_west_celestial_soldier", x = 26.5, y = 36.5 },
    { type = "ch6_west_celestial_soldier", x = 12.5, y = 44.5 },
    { type = "ch6_west_celestial_soldier", x = 24.5, y = 45.5 },
    {
        type = "ch6_pojun", x = 18.5, y = 10.5,
        patrolPreset = "large_waypoint_loop",
        patrol = {
            nodes = {
                { x = 8,  y = 8 },
                { x = 20, y = 8 },
                { x = 26, y = 14 },
                { x = 24, y = 22 },
                { x = 14, y = 22 },
                { x = 8,  y = 15 },
            },
        },
    },
    {
        type = "ch6_zhenyuan", x = 18.5, y = 38.5,
        patrolPreset = "large_waypoint_loop",
        patrol = {
            nodes = {
                { x = 7,  y = 32 },
                { x = 18, y = 32 },
                { x = 26, y = 36 },
                { x = 24, y = 44 },
                { x = 12, y = 44 },
                { x = 7,  y = 38 },
            },
        },
    },
    { type = "ch6_heng_marshal", x = 7.5, y = 24.5 },

    -- 界守·东大营：外层 6 个小怪，内层 4 个小怪。
    { type = "ch6_east_celestial_soldier", x = 46.5, y = 56.5 },
    { type = "ch6_east_celestial_soldier", x = 54.5, y = 57.5 },
    { type = "ch6_east_celestial_soldier", x = 59.5, y = 63.5 },
    { type = "ch6_east_celestial_soldier", x = 48.5, y = 68.5 },
    { type = "ch6_east_celestial_soldier", x = 56.5, y = 75.5 },
    { type = "ch6_east_celestial_soldier", x = 60.5, y = 72.5 },
    { type = "ch6_east_celestial_soldier", x = 66.5, y = 59.5 },
    { type = "ch6_east_celestial_soldier", x = 73.5, y = 61.5 },
    { type = "ch6_east_celestial_soldier", x = 66.5, y = 70.5 },
    { type = "ch6_east_celestial_soldier", x = 73.5, y = 73.5 },
    {
        type = "ch6_qingfeng", x = 52.5, y = 61.5,
        patrolPreset = "large_waypoint_loop",
        patrol = {
            nodes = {
                { x = 48, y = 58 },
                { x = 59, y = 58 },
                { x = 60, y = 68 },
                { x = 56, y = 76 },
                { x = 48, y = 74 },
                { x = 47, y = 64 },
            },
        },
    },
    {
        type = "ch6_leice", x = 70.5, y = 72.5,
        patrolPreset = "large_waypoint_loop",
        patrol = {
            nodes = {
                { x = 64, y = 58 },
                { x = 75, y = 58 },
                { x = 76, y = 68 },
                { x = 73, y = 75 },
                { x = 64, y = 74 },
                { x = 65, y = 64 },
            },
        },
    },
    { type = "ch6_ha_marshal", x = 70.5, y = 68.5 },

    -- 呱大人领地：区域跨度较大，蛤蟆仙人均匀分散在林地各侧。
    { type = "ch6_toad_immortal", x = 6.5,  y = 57.5 },
    { type = "ch6_toad_immortal", x = 16.5, y = 58.5 },
    { type = "ch6_toad_immortal", x = 28.5, y = 58.5 },
    { type = "ch6_toad_immortal", x = 35.5, y = 62.5 },
    { type = "ch6_toad_immortal", x = 31.5, y = 68.5 },
    { type = "ch6_toad_immortal", x = 18.5, y = 72.5 },
    { type = "ch6_toad_immortal", x = 28.5, y = 76.5 },
    { type = "ch6_toad_immortal", x = 35.5, y = 74.5 },
    { type = "ch6_gua_master", x = 11.5, y = 73.5 },

    -- 封印的两界村
    { type = "ch6_mojun_shixuan", x = 40.5, y = 41.5 },
}
ZoneData_ch6.TownDecorations = {
    -- 影入口：安全区保持克制，只提示“影化两界村”的入口感。
    { type = "stone_tablet", x = 73.5, y = 37.5, label = "影入口界碑" },
    { type = "lantern", x = 75.5, y = 36.5 },
    { type = "lantern", x = 78.5, y = 43.5 },
    { type = "cobweb", x = 72.5, y = 35.5 },
    { type = "crack", x = 77.5, y = 44.5 },

    -- 羊肠小径：天兵巡逻线，只加少量界碑和旗帜，不改变山路底色。
    { type = "banner", x = 65.5, y = 34.5 },
    { type = "stone_tablet", x = 69.5, y = 31.5, label = "巡界令碑" },
    { type = "crack", x = 58.5, y = 37.5 },

    -- 影游荒原：旧地被暗影渗出，装饰以枯影、裂纹、旧碑为主。
    { type = "dead_tree", x = 36.5, y = 24.5 },
    { type = "stone_tablet", x = 41.5, y = 25.5, label = "夜游旧碑" },
    { type = "crack", x = 45.5, y = 27.5 },
    { type = "cobweb", x = 52.5, y = 24.5 },
    { type = "crack", x = 49.5, y = 28.5 },

    -- 两界山：山神区域，强调石碑、裂山、山岳祭痕。
    { type = "stone_tablet", x = 44.5, y = 12.5, label = "镇山符碑" },
    { type = "ruined_pillar", x = 50.5, y = 8.5 },
    { type = "crack", x = 52.5, y = 15.5 },
    { type = "dead_tree", x = 35.5, y = 18.5 },

    -- 西大营：旧营寨被天军接管，只提高军阵装饰密度，不换底色；不用蛛网/石碑。
    { type = "banner", x = 8.5, y = 9.5 },
    { type = "banner", x = 18.5, y = 11.5 },
    { type = "flag", x = 24.5, y = 20.5, color = {190, 120, 60, 255} },
    { type = "weapon_rack", x = 6.5, y = 15.5 },
    { type = "weapon_rack", x = 14.5, y = 22.5 },
    { type = "weapon_rack", x = 22.5, y = 16.5 },
    { type = "weapon_rack", x = 24.5, y = 32.5 },
    { type = "campfire", x = 13.5, y = 18.5 },
    { type = "campfire", x = 19.5, y = 30.5 },
    { type = "campfire", x = 26.5, y = 18.5 },
    { type = "barrel", x = 7.5, y = 12.5 },
    { type = "barrel", x = 17.5, y = 9.5 },
    { type = "barrel", x = 24.5, y = 36.5 },
    { type = "fence", x = 10.5, y = 24.5 },
    { type = "fence", x = 11.5, y = 24.5 },
    { type = "fence", x = 12.5, y = 24.5 },

    -- 东大营：保留洞穴底色，提高天军驻扎密度；不用蛛网/石碑。
    { type = "banner", x = 58.5, y = 57.5 },
    { type = "flag", x = 66.5, y = 58.5, color = {80, 150, 210, 255} },
    { type = "flag", x = 74.5, y = 69.5, color = {95, 170, 230, 255} },
    { type = "weapon_rack", x = 51.5, y = 58.5 },
    { type = "weapon_rack", x = 57.5, y = 65.5 },
    { type = "weapon_rack", x = 66.5, y = 60.5 },
    { type = "weapon_rack", x = 72.5, y = 72.5 },
    { type = "stalactite", x = 47.5, y = 60.5 },
    { type = "stalactite", x = 56.5, y = 63.5 },
    { type = "stalactite", x = 70.5, y = 62.5 },
    { type = "stalactite", x = 73.5, y = 66.5 },
    { type = "stalactite", x = 49.5, y = 56.5 },
    { type = "stalactite", x = 55.5, y = 66.5 },
    { type = "stalactite", x = 75.5, y = 60.5 },

    -- 呱大人领地：荷塘湿地感，荒诞但不腐化。
    { type = "mushroom", x = 11.5, y = 68.5 },
    { type = "bush", x = 18.5, y = 72.5 },
    { type = "flower", x = 13.5, y = 76.5 },
    { type = "pond", x = 21.5, y = 66.5 },

    -- 全图三色灵晶：第六章暗夜氛围基础点缀，蓝/绿/暗红各 30 个。
    -- 蓝色灵晶
    { type = "crystal", x = 74.5, y = 36.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 78.5, y = 44.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 60.5, y = 35.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 67.5, y = 32.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 52.5, y = 36.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 36.5, y = 23.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 42.5, y = 28.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 53.5, y = 27.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 35.5, y = 8.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 41.5, y = 16.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 52.5, y = 6.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 7.5, y = 7.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 15.5, y = 15.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 25.5, y = 10.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 11.5, y = 33.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 24.5, y = 43.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 36.5, y = 16.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 44.5, y = 8.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 45.5, y = 55.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 52.5, y = 70.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 59.5, y = 76.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 65.5, y = 73.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 76.5, y = 76.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 57.5, y = 44.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 30.5, y = 58.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 55.5, y = 52.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 73.5, y = 52.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 4.5, y = 47.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 27.5, y = 47.5, color = {90, 165, 230, 255} },
    { type = "crystal", x = 68.5, y = 58.5, color = {90, 165, 230, 255} },
    -- 绿色灵晶
    { type = "crystal", x = 7.5, y = 67.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 15.5, y = 65.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 20.5, y = 76.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 24.5, y = 70.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 27.5, y = 72.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 10.5, y = 68.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 12.5, y = 74.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 18.5, y = 69.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 21.5, y = 66.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 23.5, y = 77.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 30.5, y = 62.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 34.5, y = 67.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 38.5, y = 72.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 42.5, y = 76.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 48.5, y = 74.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 72.5, y = 38.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 76.5, y = 35.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 79.5, y = 42.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 68.5, y = 44.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 61.5, y = 41.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 35.5, y = 24.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 39.5, y = 29.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 45.5, y = 23.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 50.5, y = 28.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 54.5, y = 24.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 34.5, y = 9.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 40.5, y = 18.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 48.5, y = 11.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 53.5, y = 18.5, color = {105, 200, 135, 255} },
    { type = "crystal", x = 31.5, y = 19.5, color = {105, 200, 135, 255} },
    -- 暗红灵晶
    { type = "crystal", x = 34.5, y = 36.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 46.5, y = 36.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 35.5, y = 46.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 47.5, y = 46.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 40.5, y = 34.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 41.5, y = 47.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 33.5, y = 40.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 48.5, y = 41.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 38.5, y = 38.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 43.5, y = 44.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 31.5, y = 11.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 48.5, y = 12.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 67.5, y = 25.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 72.5, y = 25.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 63.5, y = 12.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 75.5, y = 14.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 60.5, y = 22.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 58.5, y = 57.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 66.5, y = 60.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 74.5, y = 69.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 51.5, y = 58.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 57.5, y = 65.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 72.5, y = 72.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 8.5, y = 9.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 18.5, y = 11.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 24.5, y = 20.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 13.5, y = 18.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 19.5, y = 30.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 26.5, y = 18.5, color = {170, 70, 90, 255} },
    { type = "crystal", x = 7.5, y = 12.5, color = {170, 70, 90, 255} },

    -- 虎王试炼地：神圣试炼，不使用腐化元素。
    { type = "stone_tablet", x = 66.5, y = 29.5, label = "虎王试炼碑" },
    { type = "stone_tablet", x = 71.5, y = 29.5, label = "虎王试炼碑" },
    { type = "banner", x = 67.5, y = 31.5 },
    { type = "incense_burner", x = 70.5, y = 31.5 },

    -- 封印的两界村：噩梦关押核心，衰败与封印痕迹集中在村内。
    { type = "stone_tablet", x = 38.5, y = 39.5, label = "封梦碑" },
    { type = "stone_tablet", x = 43.5, y = 44.5, label = "封梦碑" },
    { type = "crack", x = 40.5, y = 41.5 },
    { type = "dead_tree", x = 35.5, y = 36.5 },
    { type = "cobweb", x = 46.5, y = 46.5 },
    { type = "ruined_pillar", x = 42.5, y = 39.5 },
}
ZoneData_ch6.NPCs = {
    -- ── 传送法阵（影入口安全区） ──
    {
        id = "ch6_teleport_array", name = "传送法阵", subtitle = "跨章传送",
        x = 76, y = 39, icon = "🌀",
        interactType = "teleport_array", zone = "shadow_spawn_safe",
        isObject = true, label = "传送法阵",
        decorationType = "teleport_array",
        color = {100, 150, 255, 200},
        dialog = "法阵幽光闪烁，可传送至其他界域。",
    },
    -- ── 炼丹炉 ──
    {
        id = "ch6_alchemy", name = "炼丹炉", subtitle = "炼丹",
        x = 78, y = 41, icon = "🔥",
        interactType = "alchemy", zone = "shadow_spawn_safe",
        portrait = "Textures/npc_alchemy_furnace.png",
        dialog = "炼丹炉被幽冥之火点燃，可在此炼制仙劫丹。",
    },
}

-- 第六章两界村保留入口形态，门洞由 Chapter6 后处理改为封印光幕。
ZoneData_ch6.TOWN_GATES = copyTable(townData.gates) or {}
ZoneData_ch6.SPAWN_POINT = { x = 76.5, y = 40.5 }
ZoneData_ch6.ALL_ZONES = ALL_ZONES

ZoneData_ch6.TILE_COLORS = copyTable(baseZoneData.TILE_COLORS)
ZoneData_ch6.WALKABLE_TILES = copyTable(baseZoneData.WALKABLE_TILES)
ZoneData_ch6.TILE_TRANSITION_COLORS = copyTable(baseZoneData.TILE_TRANSITION_COLORS)

local T = ZoneData_ch6.TILE
ZoneData_ch6.TILE_COLORS[T.CH6_SHADOW_GROUND]  = {42, 48, 78, 255}
ZoneData_ch6.TILE_COLORS[T.CH6_MOUNTAIN_STONE] = {104, 99, 88, 255}
ZoneData_ch6.TILE_COLORS[T.CH6_MOUNTAIN_RUNE]  = {120, 108, 82, 255}
ZoneData_ch6.TILE_COLORS[T.CH6_CORRUPTED_TOWN] = {72, 55, 82, 255}
ZoneData_ch6.TILE_COLORS[T.CH6_SEAL_FLOOR]     = {98, 82, 112, 255}
ZoneData_ch6.TILE_COLORS[T.CH6_TRIAL_STONE]    = {126, 122, 102, 255}

ZoneData_ch6.WALKABLE_TILES[T.CH6_SHADOW_GROUND]  = true
ZoneData_ch6.WALKABLE_TILES[T.CH6_MOUNTAIN_STONE] = true
ZoneData_ch6.WALKABLE_TILES[T.CH6_MOUNTAIN_RUNE]  = true
ZoneData_ch6.WALKABLE_TILES[T.CH6_CORRUPTED_TOWN] = true
ZoneData_ch6.WALKABLE_TILES[T.CH6_SEAL_FLOOR]     = true
ZoneData_ch6.WALKABLE_TILES[T.CH6_TRIAL_STONE]    = true

ZoneData_ch6.TILE_TRANSITION_COLORS[T.CH6_SHADOW_GROUND]  = {42, 48, 78}
ZoneData_ch6.TILE_TRANSITION_COLORS[T.CH6_MOUNTAIN_STONE] = {104, 99, 88}
ZoneData_ch6.TILE_TRANSITION_COLORS[T.CH6_MOUNTAIN_RUNE]  = {120, 108, 82}
ZoneData_ch6.TILE_TRANSITION_COLORS[T.CH6_CORRUPTED_TOWN] = {72, 55, 82}
ZoneData_ch6.TILE_TRANSITION_COLORS[T.CH6_SEAL_FLOOR]     = {98, 82, 112}
ZoneData_ch6.TILE_TRANSITION_COLORS[T.CH6_TRIAL_STONE]    = {126, 122, 102}

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
        "boar_forest", "bandit_camp", "bandit_backhill", "tiger_domain", "town",
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
        town = "封印的两界村",
    },
}

ZoneData_ch6.MINIMAP_LABELS = {
    { key = "shadow_spawn_safe", name = "影入口", color = {150, 175, 255, 255} },
    { key = "village_north_ruins", name = "影游荒原", color = {170, 150, 230, 255} },
    { key = "town", name = "封印的两界村", color = {210, 170, 220, 255} },
    { key = "narrow_trail", name = "羊肠小径", color = {180, 200, 160, 255} },
    { key = "spider_outer", name = "界守·东大营", color = {130, 190, 230, 255} },
    { key = "boar_forest", name = "呱大人领地", color = {150, 220, 130, 255} },
    { key = "bandit_camp", name = "界守·西大营", color = {220, 180, 140, 255} },
    { key = "bandit_backhill", name = "两界山", color = {205, 190, 145, 255} },
    { key = "tiger_domain", name = "虎王试炼地", color = {235, 215, 160, 255} },
}

ZoneData_ch6.ZONE_INFO = {
    shadow_spawn_safe = { name = "蛛网小径·影入口", levelRange = nil },
    village_north_ruins = { name = "影游荒原", levelRange = {123, 128} },
    town = { name = "封印的两界村", levelRange = {140, 140} },
    trial_area = { name = "影·青云试炼旧址", levelRange = nil },
    narrow_trail = { name = "羊肠小径", levelRange = {121, 124} },
    spider_cave = { name = "界守·东大营", levelRange = {131, 140} },
    boar_forest = { name = "呱大人领地", levelRange = {138, 140} },
    bandit_camp = { name = "界守·西大营", levelRange = {131, 140} },
    bandit_backhill = { name = "两界山", levelRange = {127, 132} },
    tiger_domain = { name = "虎王封印地", levelRange = {136, 140} },
    wilderness = { name = "影游荒原", levelRange = {123, 128} },
}

return ZoneData_ch6
