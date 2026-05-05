-- ============================================================================
-- ZoneData_mz.lua - 特殊章节·中洲 区域数据聚合（ID: 101）
-- 结构与 ZoneData.lua / ZoneData_ch2~ch4.lua 完全一致
-- ============================================================================

local ZoneData_mz = {}

-- 加载各区域数据
local baseData       = require("config.zones.midland.base")
local qingyunData    = require("config.zones.midland.qingyun")
local fengmoData     = require("config.zones.midland.fengmo")
local xueshaData     = require("config.zones.midland.xuesha")
local haoqiData      = require("config.zones.midland.haoqi")
local tianjiData     = require("config.zones.midland.tianji")
local yaochiData     = require("config.zones.midland.yaochi")
local riftData       = require("config.zones.midland.rift")
local battleJieData  = require("config.zones.midland.battle_jie")
local battleLuoData  = require("config.zones.midland.battle_luo")
local battleYunData  = require("config.zones.midland.battle_yun")
local roadData       = require("config.zones.midland.road")

-- 所有区域模块列表（渲染顺序：底层先填充，上层覆盖）
local ALL_ZONES = {
    baseData,           -- ① 全图填充 CELESTIAL_WALL（未覆盖区域自动成墙）
    roadData,           -- ② 道路覆盖（可通行通道）
    qingyunData,        -- ③ 各势力区域覆盖（可通行 + 边界墙）
    fengmoData,
    xueshaData,
    haoqiData,
    tianjiData,
    yaochiData,
    riftData,           -- ④ 峡谷 + 桥梁
    battleJieData,      -- ⑤ 战场（全封闭边界）
    battleLuoData,
    battleYunData,
}

-- ============================================================================
-- 区域枚举
-- ============================================================================

ZoneData_mz.ZONES = {
    QINGYUN     = "mz_qingyun",
    FENGMO      = "mz_fengmo",
    XUESHA      = "mz_xuesha",
    HAOQI       = "mz_haoqi",
    TIANJI      = "mz_tianji",
    YAOCHI      = "mz_yaochi",
    RIFT        = "mz_rift",
    BATTLE_JIE  = "mz_battle_jie",
    BATTLE_LUO  = "mz_battle_luo",
    BATTLE_YUN  = "mz_battle_yun",
    ROAD        = "mz_road",
}

-- ============================================================================
-- 瓦片类型与通行性（引用共享资源库 TileTypes）
-- ============================================================================

local TileTypes = require("config.TileTypes")
ZoneData_mz.TILE = TileTypes.TILE
ZoneData_mz.WALKABLE = TileTypes.WALKABLE

-- ============================================================================
-- 从各区域文件汇总 Regions / SpawnPoints / Decorations / NPCs
-- ============================================================================

-- 区域范围
ZoneData_mz.Regions = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.regions then
        for name, region in pairs(zoneModule.regions) do
            ZoneData_mz.Regions[name] = region
        end
    end
end

-- 怪物刷新点（中洲南部无怪物）
ZoneData_mz.SpawnPoints = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.spawns then
        for _, sp in ipairs(zoneModule.spawns) do
            table.insert(ZoneData_mz.SpawnPoints, sp)
        end
    end
end

-- 装饰物
ZoneData_mz.TownDecorations = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.decorations then
        for _, deco in ipairs(zoneModule.decorations) do
            table.insert(ZoneData_mz.TownDecorations, deco)
        end
    end
end

-- NPC
ZoneData_mz.NPCs = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.npcs then
        for _, npc in ipairs(zoneModule.npcs) do
            table.insert(ZoneData_mz.NPCs, npc)
        end
    end
end

-- 中洲无传统主城围墙
ZoneData_mz.TOWN_GATES = {}

-- 玩家出生点（青云城中央）
ZoneData_mz.SPAWN_POINT = qingyunData.spawnPoint or { x = 40.5, y = 59.5 }

-- 暴露所有区域模块列表
ZoneData_mz.ALL_ZONES = ALL_ZONES

-- ============================================================================
-- 瓦片颜色定义（供 TileRenderer / WorldRenderer 数据驱动读取）
-- ============================================================================
local T = ZoneData_mz.TILE

ZoneData_mz.TILE_COLORS = {
    -- ch1 共享瓦片（保持基础兼容）
    [T.GRASS]        = {80, 140, 60, 255},
    [T.TOWN_FLOOR]   = {160, 130, 100, 255},
    [T.TOWN_ROAD]    = {180, 160, 130, 255},
    [T.CAVE_FLOOR]   = {100, 90, 80, 255},
    [T.FOREST_FLOOR] = {50, 100, 40, 255},
    [T.MOUNTAIN]     = {120, 110, 100, 255},
    [T.WATER]        = {60, 120, 180, 255},
    [T.WALL]         = {80, 80, 80, 255},
    [T.CAMP_FLOOR]   = {100, 90, 80, 255},
    [T.TIGER_GROUND] = {35, 75, 30, 255},
    [T.CAMP_DIRT]    = {120, 100, 70, 255},     -- 营地土地（副本地板用）
    -- 中洲新增瓦片
    [T.CELESTIAL_FLOOR]  = {170, 185, 200, 255},   -- 青石地面（冷灰蓝）
    [T.CELESTIAL_WALL]   = {90, 100, 120, 255},     -- 仙府城墙（深灰蓝）
    [T.CELESTIAL_ROAD]   = {195, 175, 130, 255},    -- 灵气长街（暖金石板）
    [T.RIFT_VOID]        = {15, 10, 30, 255},       -- 天裂峡谷（深渊黑紫）
    [T.BRIDGE_FLOOR]     = {160, 150, 130, 255},    -- 桥梁地面（温暖石色）
    [T.BATTLEFIELD_VOID] = {60, 50, 70, 255},       -- 战场封印（暗紫灰）
    [T.CORRUPTED_GROUND] = {55, 35, 40, 255},       -- 魔化焦土（暗红褐）
    [T.LIGHT_CURTAIN]    = {100, 160, 255, 255},     -- 光幕分隔（蓝白辉光）
    [T.SEAL_RED]         = {180, 40, 40, 255},       -- 红色封印（血红光幕）
    [T.YAOCHI_CLIFF]     = {75, 65, 55, 255},        -- 瑶池崖壁（灰褐岩石）
    [T.HERB_FIELD]       = {60, 130, 50, 255},        -- 药田（翠绿田地）
    [T.MARKET_STREET]    = {210, 185, 140, 255},       -- 商业街（暖黄石板，区别于普通道路）
}

-- 可通行瓦片集合（区域过渡渐变用）
ZoneData_mz.WALKABLE_TILES = {
    [T.CELESTIAL_FLOOR]  = true,
    [T.CELESTIAL_ROAD]   = true,
    [T.BRIDGE_FLOOR]     = true,
    [T.CORRUPTED_GROUND] = true,
    [T.HERB_FIELD]       = true,
    [T.MARKET_STREET]    = true,
}

-- 区域过渡渐变色 {r, g, b}
ZoneData_mz.TILE_TRANSITION_COLORS = {
    [T.CELESTIAL_FLOOR]  = {170, 185, 200},
    [T.CELESTIAL_ROAD]   = {195, 175, 130},
    [T.BRIDGE_FLOOR]     = {160, 150, 130},
    [T.CORRUPTED_GROUND] = {55, 35, 40},
    [T.HERB_FIELD]       = {60, 130, 50},
    [T.MARKET_STREET]    = {210, 185, 140},
}

-- ============================================================================
-- 图鉴区域分组（中洲无怪物，但保留结构以备扩展）
-- ============================================================================

ZoneData_mz.BESTIARY_ZONES = {
    order = { "xianjie_battlefield" },
    names = {
        xianjie_battlefield = "仙劫战场",
    },
}

ZoneData_mz.ZONE_INFO = {
    mz_qingyun    = { name = "青云城",     levelRange = nil },
    mz_fengmo     = { name = "封魔殿",     levelRange = nil },
    mz_xuesha     = { name = "血煞盟",     levelRange = nil },
    mz_haoqi      = { name = "浩气宗",     levelRange = nil },
    mz_tianji     = { name = "天机阁",     levelRange = nil },
    mz_yaochi     = { name = "瑶池",       levelRange = nil },
    mz_rift       = { name = "天裂峡谷",   levelRange = nil },
    mz_battle_jie = { name = "仙劫战场",   levelRange = nil },
    mz_battle_luo = { name = "仙陨战场",   levelRange = nil },
    mz_battle_yun = { name = "仙殒战场",   levelRange = nil },
    mz_road       = { name = "仙府长街",   levelRange = nil },
}

return ZoneData_mz
