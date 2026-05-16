-- ============================================================================
-- ZoneData_ch5.lua - 第五章区域数据聚合（伍章·太虚之殇）
-- 结构与 ZoneData.lua / ZoneData_ch2~ch4.lua 完全一致
-- ============================================================================

local ZoneData_ch5 = {}

-- 加载各区域数据
local frontCampData     = require("config.zones.chapter5.front_camp")
local brokenGateData    = require("config.zones.chapter5.broken_gate")
local swordPlazaData    = require("config.zones.chapter5.sword_plaza")
local forgeData         = require("config.zones.chapter5.forge")
local swordCourtData    = require("config.zones.chapter5.sword_court")
local coldPoolData      = require("config.zones.chapter5.cold_pool")
local steleForestData   = require("config.zones.chapter5.stele_forest")
local libraryData       = require("config.zones.chapter5.library")
local swordPalaceData   = require("config.zones.chapter5.sword_palace")
local demonAbyssData    = require("config.zones.chapter5.demon_abyss")
local swordCorridorData = require("config.zones.chapter5.sword_corridor")

-- 所有区域模块列表（按空间从前到后排列）
local ALL_ZONES = {
    frontCampData,
    brokenGateData,
    -- 左路
    swordPlazaData,
    forgeData,
    swordCourtData,
    -- 右路
    coldPoolData,
    steleForestData,
    libraryData,
    -- 中后场
    swordPalaceData,
    demonAbyssData,
    swordCorridorData,
}

-- ============================================================================
-- 区域枚举
-- ============================================================================

ZoneData_ch5.ZONES = {
    FRONT_CAMP     = "ch5_front_camp",
    BROKEN_GATE    = "ch5_broken_gate",
    SWORD_PLAZA    = "ch5_sword_plaza",
    FORGE          = "ch5_forge",
    SWORD_COURT    = "ch5_sword_court",
    COLD_POOL      = "ch5_cold_pool",
    STELE_FOREST   = "ch5_stele_forest",
    LIBRARY        = "ch5_library",
    SWORD_PALACE   = "ch5_sword_palace",
    DEMON_ABYSS    = "ch5_demon_abyss",
    SWORD_CORRIDOR = "ch5_sword_corridor",
}

-- ============================================================================
-- 瓦片类型与通行性（引用共享资源库 TileTypes）
-- ============================================================================

local TileTypes = require("config.TileTypes")
ZoneData_ch5.TILE = TileTypes.TILE
ZoneData_ch5.WALKABLE = TileTypes.WALKABLE

-- ============================================================================
-- 从各区域文件汇总 Regions / SpawnPoints / Decorations / NPCs
-- ============================================================================

-- 区域范围
ZoneData_ch5.Regions = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.regions then
        for name, region in pairs(zoneModule.regions) do
            ZoneData_ch5.Regions[name] = region
        end
    end
end

-- 怪物刷新点（第五章本次不添加怪物）
ZoneData_ch5.SpawnPoints = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.spawns then
        for _, sp in ipairs(zoneModule.spawns) do
            table.insert(ZoneData_ch5.SpawnPoints, sp)
        end
    end
end

-- 装饰物
ZoneData_ch5.TownDecorations = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.decorations then
        for _, deco in ipairs(zoneModule.decorations) do
            table.insert(ZoneData_ch5.TownDecorations, deco)
        end
    end
end

-- NPC
ZoneData_ch5.NPCs = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.npcs then
        for _, npc in ipairs(zoneModule.npcs) do
            table.insert(ZoneData_ch5.NPCs, npc)
        end
    end
end

-- 第五章无传统主城围墙
ZoneData_ch5.TOWN_GATES = {}

-- 玩家出生点（前营中央）
ZoneData_ch5.SPAWN_POINT = frontCampData.spawnPoint or { x = 40.5, y = 6.5 }

-- 暴露所有区域模块列表
ZoneData_ch5.ALL_ZONES = ALL_ZONES

-- ============================================================================
-- 空间布局配置（供 mapgen/Chapter5.lua 使用）
-- ============================================================================

ZoneData_ch5.LAYOUT = {
    -- 地图外沿缓冲带
    buffer = { outer = 2 },

    -- ── 上半场（中路）──
    front_camp  = { x1 = 26, y1 = 3,  x2 = 54, y2 = 10 },  -- 前营 29×8
    broken_gate = { x1 = 29, y1 = 13, x2 = 51, y2 = 18 },  -- 裂山门 23×6  (与前营隔2行虚空)

    -- 左路（纵向浮空岛，各隔2行虚空）
    sword_plaza = { x1 = 3,  y1 = 3,  x2 = 22, y2 = 17 },  -- 问剑坪 20×15
    forge       = { x1 = 3,  y1 = 20, x2 = 18, y2 = 35 },  -- 铸剑地炉 16×16 (与坪隔2行)
    sword_court = { x1 = 3,  y1 = 38, x2 = 22, y2 = 64 },  -- 栖剑别院 20×27 (向下延伸6格)

    -- 右路（纵向浮空岛，各隔2行虚空）
    cold_pool    = { x1 = 58, y1 = 3,  x2 = 77, y2 = 17 },  -- 洗剑寒池 20×15
    stele_forest = { x1 = 58, y1 = 20, x2 = 77, y2 = 45 },  -- 悟剑碑林 20×26 (再向下延展2格)
    library      = { x1 = 58, y1 = 48, x2 = 77, y2 = 64 },  -- 藏经书阁 20×17 (顶部缩短2行)

    -- 中场（与裂山门隔4行虚空，为BOSS房突出预留空间）
    sword_palace = { x1 = 26, y1 = 23, x2 = 54, y2 = 42 },  -- 太虚剑宫 29×20

    -- 下半场（剑宫→深渊隔6行虚空，深渊→城墙隔2行虚空）
    demon_abyss    = { x1 = 26, y1 = 49, x2 = 54, y2 = 68 },  -- 镇魔深渊 29×20 (下延至城墙相通)
    -- 剑气城墙：全图横跨
    sword_corridor = { x1 = 3,  y1 = 68, x2 = 77, y2 = 77 },  -- 剑气城墙 75×10 (整体下移3格)
}

-- ============================================================================
-- 瓦片颜色定义（供 TileRenderer / WorldRenderer 数据驱动读取）
-- ============================================================================
local T = ZoneData_ch5.TILE

ZoneData_ch5.TILE_COLORS = {
    -- ch1 共享瓦片（保留基础色以防回退）
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

    -- ch5 太虚之殇 专属瓦片颜色
    [T.CH5_CAMP_DIRT]        = {140, 115, 80, 255},    -- 暖土色（前营泥土）
    [T.CH5_CAMP_FLAGSTONE]   = {155, 145, 130, 255},   -- 灰石板色（修补石板）
    [T.CH5_RUIN_BLUESTONE]   = {95, 110, 125, 255},    -- 青灰石（废墟基调）
    [T.CH5_RUIN_CRACKED]     = {110, 100, 90, 255},    -- 暗裂石
    [T.CH5_FORGE_BLACKSTONE] = {45, 40, 38, 255},      -- 焦黑石
    [T.CH5_FORGE_MOLTEN]     = {130, 55, 25, 255},     -- 暗红熔裂
    [T.CH5_COURTYARD_MOSS]   = {85, 105, 80, 255},     -- 苔绿院石
    [T.CH5_COLD_JADE]        = {140, 175, 180, 255},   -- 冰玉青
    [T.CH5_COLD_ICE_EDGE]    = {180, 210, 220, 255},   -- 冰边白蓝
    [T.CH5_STELE_PALE]       = {175, 170, 160, 255},   -- 苍白碑石
    [T.CH5_LIBRARY_BURNT]    = {70, 55, 45, 255},      -- 焚烧深褐
    [T.CH5_PALACE_WHITE]     = {200, 200, 195, 255},   -- 白玉石
    [T.CH5_PALACE_CORRUPTED] = {160, 140, 155, 255},   -- 侵蚀紫脉
    [T.CH5_BLOOD_RITUAL]     = {120, 35, 30, 255},     -- 暗红血祭
    [T.CH5_ABYSS_CHARRED]    = {50, 42, 40, 255},      -- 深渊焦岩
    [T.CH5_ABYSS_FLESH]      = {90, 40, 45, 255},      -- 血肉暗红
    [T.CH5_CORRIDOR_DARK]    = {55, 55, 65, 255},      -- 冷暗石
    [T.CH5_CORRIDOR_SWORD]   = {130, 135, 145, 255},   -- 剑金属灰
    [T.CH5_VOID]             = {15, 12, 18, 255},      -- 虚空深黑
    [T.CH5_WALL]             = {75, 75, 80, 255},      -- 废墟墙灰
    [T.CH5_CLIFF]            = {60, 55, 50, 255},      -- 断崖深褐
    [T.CH5_SEALED_GATE]      = {100, 70, 110, 255},    -- 封印紫
    [T.CH5_BRIDGE]           = {130, 125, 115, 255},   -- 桥面石
    [T.CH5_CITY_WALL]        = {70, 75, 90, 255},      -- 剑气城墙（暗蓝灰）
    [T.CH5_WALL_BATTLEMENT]  = {60, 65, 80, 255},      -- 城垛（更深蓝灰）
    [T.CH5_WALL_COLLAPSED]   = {95, 85, 75, 255},      -- 坍塌废墟（暖灰碎石）
    [T.CH5_BLOOD_RIVER]      = {110, 25, 20, 255},     -- 血河（暗红）
    [T.CH5_STELE_INTACT]     = {155, 150, 140, 255},   -- 完整石碑（灰白碑石）
    [T.CH5_STELE_BROKEN]     = {135, 125, 115, 255},   -- 断壁残碑（暗灰碎碑）
    [T.CH5_LAVA_WALL]        = {180, 60, 15, 255},     -- 岩浆墙（橙红熔岩）
    [T.CH5_BLOOD_POOL]       = {100, 25, 25, 255},     -- 祀剑池（暗红血池）
    [T.CH5_FURNACE]          = {60, 45, 30, 255},      -- 铸剑地炉（焦铜色）
}

-- 可通行瓦片集合（区域过渡渐变用）
ZoneData_ch5.WALKABLE_TILES = {
    [T.CH5_CAMP_DIRT]        = true,
    [T.CH5_CAMP_FLAGSTONE]   = true,
    [T.CH5_RUIN_BLUESTONE]   = true,
    [T.CH5_RUIN_CRACKED]     = true,
    [T.CH5_FORGE_BLACKSTONE] = true,
    [T.CH5_FORGE_MOLTEN]     = true,
    [T.CH5_COURTYARD_MOSS]   = true,
    [T.CH5_COLD_JADE]        = true,
    [T.CH5_STELE_PALE]       = true,
    [T.CH5_LIBRARY_BURNT]    = true,
    [T.CH5_PALACE_WHITE]     = true,
    [T.CH5_PALACE_CORRUPTED] = true,
    [T.CH5_BLOOD_RITUAL]     = true,
    [T.CH5_ABYSS_CHARRED]    = true,
    [T.CORRUPTED_GROUND]     = true,
    [T.CH5_CORRIDOR_DARK]    = true,
    [T.CH5_BRIDGE]           = true,
    [T.CH5_WALL_COLLAPSED]   = true,
    [T.CH5_CITY_WALL]        = true,
    [T.CH5_STELE_BROKEN]     = true,
}

-- ============================================================================
-- 边缘分类集合（供 EdgeDecalRenderer 判断交界类型）
-- ============================================================================
ZoneData_ch5.EDGE_TYPES = {
    -- 墙体集合（地表对墙体 → 阴影投影边）
    wall = {
        [T.CH5_WALL]            = true,
        [T.CH5_SEALED_GATE]     = true,
        [T.WALL]                = true,
        [T.CH5_WALL_BATTLEMENT] = true,
        [T.CH5_CITY_WALL]       = true,
    },
    -- 断崖集合（地表对断崖 → 锐利暗边）
    cliff = {
        [T.CH5_CLIFF]        = true,
        [T.CH5_LAVA_WALL]    = true,
    },
    -- 虚空集合（地表对虚空 → 最深暗边 + 高光线）
    void = {
        [T.CH5_VOID]         = true,
    },
    -- 液面集合（地表对液面 → 岸线渐变）
    liquid = {
        [T.WATER]            = true,
        [T.CH5_COLD_ICE_EDGE] = true,
        [T.CH5_ABYSS_FLESH]  = true,
        [T.CH5_BLOOD_RIVER]  = true,
    },
    -- 地表集合（地表对地表 → 色彩过渡）
    ground = ZoneData_ch5.WALKABLE_TILES,
}

-- ============================================================================
-- 静态贴花配置（供 EdgeDecalRenderer 决定每格贴花类型与密度）
-- 规格书 §6.4: 剑痕/裂纹/灰烬/血迹/烧痕/残剑/书页
-- 规格书 §7.1: 分区贴花重点
-- ============================================================================
-- 贴花已禁用（效果不佳）
ZoneData_ch5.DECAL_CONFIG = {}

-- 区域过渡渐变色 {r, g, b}
ZoneData_ch5.TILE_TRANSITION_COLORS = {
    [T.CH5_CAMP_DIRT]        = {140, 115, 80},
    [T.CH5_RUIN_BLUESTONE]   = {95, 110, 125},
    [T.CH5_FORGE_BLACKSTONE] = {45, 40, 38},
    [T.CH5_COURTYARD_MOSS]   = {85, 105, 80},
    [T.CH5_COLD_JADE]        = {140, 175, 180},
    [T.CH5_STELE_PALE]       = {175, 170, 160},
    [T.CH5_LIBRARY_BURNT]    = {70, 55, 45},
    [T.CH5_PALACE_WHITE]     = {200, 200, 195},
    [T.CH5_ABYSS_CHARRED]    = {50, 42, 40},
    [T.CH5_CORRIDOR_DARK]    = {55, 55, 65},
}

-- ============================================================================
-- 图鉴区域分组（供 SystemMenu 怪物图鉴展示）
-- ============================================================================

ZoneData_ch5.BESTIARY_ZONES = {
    order = {
        "ch5_front_camp",
        "ch5_broken_gate",
        "ch5_sword_plaza", "ch5_forge", "ch5_sword_court",
        "ch5_cold_pool", "ch5_stele_forest", "ch5_library",
        "ch5_sword_palace",
        "ch5_demon_abyss",
        "ch5_sword_corridor",
    },
    names = {
        ch5_front_camp     = "太虚遗址前营",
        ch5_broken_gate    = "裂山门遗址",
        ch5_sword_plaza    = "问剑坪",
        ch5_forge          = "铸剑地炉",
        ch5_sword_court    = "栖剑别院",
        ch5_cold_pool      = "洗剑寒池",
        ch5_stele_forest   = "悟剑碑林",
        ch5_library        = "藏经书阁",
        ch5_sword_palace   = "太虚剑宫",
        ch5_demon_abyss    = "镇魔深渊",
        ch5_sword_corridor = "剑气长城",
    },
}

ZoneData_ch5.ZONE_INFO = {
    ch5_front_camp     = { name = "太虚遗址前营",   levelRange = nil },
    ch5_broken_gate    = { name = "裂山门遗址",     levelRange = {100, 104} },
    ch5_sword_plaza    = { name = "问剑坪",         levelRange = {100, 106} },
    ch5_forge          = { name = "铸剑地炉",       levelRange = {103, 108} },
    ch5_sword_court    = { name = "栖剑别院",       levelRange = {106, 112} },
    ch5_cold_pool      = { name = "洗剑寒池",       levelRange = {100, 106} },
    ch5_stele_forest   = { name = "悟剑碑林",       levelRange = {103, 108} },
    ch5_library        = { name = "藏经书阁",       levelRange = {106, 112} },
    ch5_sword_palace   = { name = "太虚剑宫",       levelRange = {110, 116} },
    ch5_demon_abyss    = { name = "镇魔深渊",       levelRange = {114, 118} },
    ch5_sword_corridor = { name = "剑气长城",       levelRange = {116, 120} },
}

return ZoneData_ch5
