-- ============================================================================
-- ZoneData_ch4.lua - 第四章区域数据聚合（肆章·八卦海）
-- 结构与 ZoneData.lua / ZoneData_ch2.lua / ZoneData_ch3.lua 完全一致
-- ============================================================================

local ZoneData_ch4 = {}

-- 加载各区域数据
local havenData      = require("config.zones.chapter4.haven")
local kanData        = require("config.zones.chapter4.kan")
local genData        = require("config.zones.chapter4.gen")
local zhenData       = require("config.zones.chapter4.zhen")
local xunData        = require("config.zones.chapter4.xun")
local liData         = require("config.zones.chapter4.li")
local kunData        = require("config.zones.chapter4.kun")
local duiData        = require("config.zones.chapter4.dui")
local qianData       = require("config.zones.chapter4.qian")
local beastNorthData = require("config.zones.chapter4.beast_north")
local beastEastData  = require("config.zones.chapter4.beast_east")
local beastWestData  = require("config.zones.chapter4.beast_west")
local beastSouthData = require("config.zones.chapter4.beast_south")

-- 所有区域模块列表
local ALL_ZONES = {
    havenData,
    kanData, genData, zhenData, xunData,
    liData, kunData, duiData, qianData,
    beastNorthData, beastEastData, beastWestData, beastSouthData,
}

-- ============================================================================
-- 区域枚举
-- ============================================================================

ZoneData_ch4.ZONES = {
    HAVEN       = "ch4_haven",
    KAN         = "ch4_kan",
    GEN         = "ch4_gen",
    ZHEN        = "ch4_zhen",
    XUN         = "ch4_xun",
    LI          = "ch4_li",
    KUN         = "ch4_kun",
    DUI         = "ch4_dui",
    QIAN        = "ch4_qian",
    BEAST_NORTH = "ch4_beast_north",
    BEAST_EAST  = "ch4_beast_east",
    BEAST_WEST  = "ch4_beast_west",
    BEAST_SOUTH = "ch4_beast_south",
}

-- ============================================================================
-- 瓦片类型与通行性（引用共享资源库 TileTypes）
-- ============================================================================

local TileTypes = require("config.TileTypes")
ZoneData_ch4.TILE = TileTypes.TILE
ZoneData_ch4.WALKABLE = TileTypes.WALKABLE

-- ============================================================================
-- 从各区域文件汇总 Regions / SpawnPoints / Decorations / NPCs
-- ============================================================================

-- 区域范围
ZoneData_ch4.Regions = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.regions then
        for name, region in pairs(zoneModule.regions) do
            ZoneData_ch4.Regions[name] = region
        end
    end
end

-- 怪物刷新点（第四章初始无怪物）
ZoneData_ch4.SpawnPoints = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.spawns then
        for _, sp in ipairs(zoneModule.spawns) do
            table.insert(ZoneData_ch4.SpawnPoints, sp)
        end
    end
end

-- 装饰物
ZoneData_ch4.TownDecorations = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.decorations then
        for _, deco in ipairs(zoneModule.decorations) do
            table.insert(ZoneData_ch4.TownDecorations, deco)
        end
    end
end

-- NPC
ZoneData_ch4.NPCs = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.npcs then
        for _, npc in ipairs(zoneModule.npcs) do
            table.insert(ZoneData_ch4.NPCs, npc)
        end
    end
end

-- 第四章无传统主城围墙
ZoneData_ch4.TOWN_GATES = {}

-- 玩家出生点（龟背岛中央）
ZoneData_ch4.SPAWN_POINT = havenData.spawnPoint or { x = 39.5, y = 39.5 }

-- 暴露所有区域模块列表
ZoneData_ch4.ALL_ZONES = ALL_ZONES

-- 暴露岛屿数据（供 mapgen 使用）
ZoneData_ch4.havenData = havenData
ZoneData_ch4.islandModules = {
    kan  = kanData,
    gen  = genData,
    zhen = zhenData,
    xun  = xunData,
    li   = liData,
    kun  = kunData,
    dui  = duiData,
    qian = qianData,
}
ZoneData_ch4.beastModules = {
    beast_north = beastNorthData,
    beast_east  = beastEastData,
    beast_west  = beastWestData,
    beast_south = beastSouthData,
}

-- ============================================================================
-- 岛屿布局配置（供 mapgen/Chapter4.lua 使用）
-- ============================================================================

ZoneData_ch4.LAYOUT = {
    center = { x = 40, y = 40 },       -- 地图中心
    seaRadius = 38,                      -- 圆形海域半径
    -- 中央岛（16×16, C=4）
    haven = { x1 = 32, y1 = 32, x2 = 47, y2 = 47, cornerCut = 4 },
    -- 八阵岛（16×16，C=3）按后天八卦方位排列
    islands = {
        kan  = { x1 = 32, y1 = 7,  x2 = 47, y2 = 22, cornerCut = 3 },  -- 北
        gen  = { x1 = 50, y1 = 14, x2 = 65, y2 = 29, cornerCut = 3 },  -- 东北
        zhen = { x1 = 57, y1 = 32, x2 = 72, y2 = 47, cornerCut = 3 },  -- 东
        xun  = { x1 = 50, y1 = 50, x2 = 65, y2 = 65, cornerCut = 3 },  -- 东南
        li   = { x1 = 32, y1 = 57, x2 = 47, y2 = 72, cornerCut = 3 },  -- 南
        kun  = { x1 = 14, y1 = 50, x2 = 29, y2 = 65, cornerCut = 3 },  -- 西南
        dui  = { x1 = 7,  y1 = 32, x2 = 22, y2 = 47, cornerCut = 3 },  -- 西
        qian = { x1 = 14, y1 = 14, x2 = 29, y2 = 29, cornerCut = 3 },  -- 西北
    },
    -- 龙种岛（22×13~14，横向蔓延）四角
    beastIslands = {
        beast_north = { x1 = 1,  y1 = 1,  x2 = 22, y2 = 13 },  -- 封霜应龙·玄冰岛 (NW)
        beast_east  = { x1 = 58, y1 = 1,  x2 = 79, y2 = 13 },  -- 堕渊蛟龙·幽渊岛 (NE)
        beast_south = { x1 = 58, y1 = 67, x2 = 79, y2 = 80 },  -- 焚天蜃龙·烈焰岛 (SE)
        beast_west  = { x1 = 1,  y1 = 67, x2 = 22, y2 = 80 },  -- 蚀骨螭龙·流沙岛 (SW)
    },
}

-- ============================================================================
-- 瓦片颜色定义（供 TileRenderer / WorldRenderer 数据驱动读取）
-- ============================================================================
local T = ZoneData_ch4.TILE

ZoneData_ch4.TILE_COLORS = {
    -- ch1 共享瓦片
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
    -- ch4 新增瓦片（通用海域）
    [T.DEEP_SEA]     = {15, 40, 80, 255},     -- 深蓝深海
    [T.SHALLOW_SEA]  = {30, 80, 140, 255},     -- 浅蓝浅海
    [T.REEF_FLOOR]   = {140, 160, 130, 255},   -- 灰绿礁石地面
    [T.CORAL_WALL]   = {100, 70, 90, 255},     -- 暗紫珊瑚墙
    [T.ROCK_REEF]    = {80, 75, 70, 255},      -- 深灰岩礁（爻纹）
    [T.SEA_SAND]     = {210, 200, 160, 255},   -- 浅黄海沙
    -- ch4 龙种岛专属瓦片
    [T.ICE_FLOOR]     = {180, 210, 230, 255},  -- 冰蓝地面（玄冰岛）
    [T.ICE_WALL]      = {120, 155, 180, 255},  -- 深冰蓝岩壁
    [T.ABYSS_FLOOR]   = {50, 40, 70, 255},     -- 暗紫深渊地面（幽渊岛）
    [T.ABYSS_WALL]    = {30, 20, 50, 255},     -- 深紫深渊暗礁
    [T.VOLCANO_FLOOR] = {140, 60, 30, 255},    -- 暗红熔岩地面（烈焰岛）
    [T.VOLCANO_WALL]  = {90, 30, 15, 255},     -- 深红熔岩岩壁
    [T.DUNE_FLOOR]    = {215, 190, 130, 255},  -- 沙黄地面（流沙岛）
    [T.DUNE_WALL]     = {170, 140, 85, 255},   -- 深沙岩壁
}

-- 可通行瓦片集合（区域过渡渐变用）
ZoneData_ch4.WALKABLE_TILES = {
    [T.REEF_FLOOR]    = true,
    [T.SEA_SAND]      = true,
    [T.ICE_FLOOR]     = true,
    [T.ABYSS_FLOOR]   = true,
    [T.VOLCANO_FLOOR] = true,
    [T.DUNE_FLOOR]    = true,
}

-- 区域过渡渐变色 {r, g, b}
ZoneData_ch4.TILE_TRANSITION_COLORS = {
    [T.REEF_FLOOR]    = {140, 160, 130},
    [T.SEA_SAND]      = {210, 200, 160},
    [T.ICE_FLOOR]     = {180, 210, 230},
    [T.ABYSS_FLOOR]   = {50, 40, 70},
    [T.VOLCANO_FLOOR] = {140, 60, 30},
    [T.DUNE_FLOOR]    = {215, 190, 130},
}

-- ============================================================================
-- 图鉴区域分组（供 SystemMenu 怪物图鉴展示）
-- ============================================================================

ZoneData_ch4.BESTIARY_ZONES = {
    order = {
        "ch4_kan", "ch4_gen", "ch4_zhen", "ch4_xun",
        "ch4_li", "ch4_kun", "ch4_dui", "ch4_qian",
        "ch4_beast_north", "ch4_beast_east", "ch4_beast_west", "ch4_beast_south",
    },
    names = {
        ch4_kan         = "坎·沉渊阵",
        ch4_gen         = "艮·止岩阵",
        ch4_zhen        = "震·惊雷阵",
        ch4_xun         = "巽·风旋阵",
        ch4_li          = "离·烈焰阵",
        ch4_kun         = "坤·厚土阵",
        ch4_dui         = "兑·泽沼阵",
        ch4_qian        = "乾·天罡阵",
        ch4_beast_north = "玄冰岛",
        ch4_beast_east  = "幽渊岛",
        ch4_beast_west  = "流沙岛",
        ch4_beast_south = "烈焰岛",
    },
}

ZoneData_ch4.ZONE_INFO = {
    ch4_haven       = { name = "龟背岛",       levelRange = nil },
    ch4_kan         = { name = "坎·沉渊阵",   levelRange = {71, 74} },
    ch4_gen         = { name = "艮·止岩阵",   levelRange = {71, 74} },
    ch4_zhen        = { name = "震·惊雷阵",   levelRange = {73, 76} },
    ch4_xun         = { name = "巽·风旋阵",   levelRange = {73, 76} },
    ch4_li          = { name = "离·烈焰阵",   levelRange = {75, 78} },
    ch4_kun         = { name = "坤·厚土阵",   levelRange = {75, 78} },
    ch4_dui         = { name = "兑·泽沼阵",   levelRange = {77, 80} },
    ch4_qian        = { name = "乾·天罡阵",   levelRange = {79, 82} },
    ch4_beast_north = { name = "玄冰岛",       levelRange = {82, 85} },
    ch4_beast_east  = { name = "幽渊岛",       levelRange = {82, 85} },
    ch4_beast_west  = { name = "流沙岛",       levelRange = {82, 85} },
    ch4_beast_south = { name = "烈焰岛",       levelRange = {82, 85} },
}

return ZoneData_ch4
