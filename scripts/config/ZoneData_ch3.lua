-- ============================================================================
-- ZoneData_ch3.lua - 第三章区域数据聚合（叁章·万里黄沙）
-- 结构与 ZoneData.lua / ZoneData_ch2.lua 完全一致
-- ============================================================================

local ZoneData_ch3 = {}

-- 加载各区域数据
local fort9Data = require("config.zones.chapter3.fort_9")
local fort8Data = require("config.zones.chapter3.fort_8")
local fort7Data = require("config.zones.chapter3.fort_7")
local fort6Data = require("config.zones.chapter3.fort_6")
local fort5Data = require("config.zones.chapter3.fort_5")
local fort4Data = require("config.zones.chapter3.fort_4")
local fort3Data = require("config.zones.chapter3.fort_3")
local fort2Data = require("config.zones.chapter3.fort_2")
local fort1Data = require("config.zones.chapter3.fort_1")
local wildOuterData = require("config.zones.chapter3.wild_outer")
local wildMidData   = require("config.zones.chapter3.wild_mid")
local wildInnerData = require("config.zones.chapter3.wild_inner")
local xianyuanRoomsCh3 = require("config.zones.xianyuan_rooms_ch3")

-- 所有区域模块列表
local ALL_ZONES = {
    fort9Data,
    fort8Data,
    fort7Data,
    wildOuterData,
    fort6Data,
    fort5Data,
    fort4Data,
    wildMidData,
    fort3Data,
    fort2Data,
    wildInnerData,
    fort1Data,
    xianyuanRoomsCh3,  -- 仙缘宝箱藏宝室（必须在最后，覆盖原有地形）
}

-- ============================================================================
-- 区域枚举
-- ============================================================================

ZoneData_ch3.ZONES = {
    FORT_9 = "ch3_fort_9",
    FORT_8 = "ch3_fort_8",
    FORT_7 = "ch3_fort_7",
    FORT_6 = "ch3_fort_6",
    FORT_5 = "ch3_fort_5",
    FORT_4 = "ch3_fort_4",
    FORT_3 = "ch3_fort_3",
    FORT_2 = "ch3_fort_2",
    FORT_1 = "ch3_fort_1",
}

-- ============================================================================
-- 瓦片类型与通行性（引用共享资源库 TileTypes）
-- ============================================================================

local TileTypes = require("config.TileTypes")
ZoneData_ch3.TILE = TileTypes.TILE
ZoneData_ch3.WALKABLE = TileTypes.WALKABLE

-- ============================================================================
-- 从各区域文件汇总 Regions / SpawnPoints / Decorations / NPCs
-- ============================================================================

-- 区域范围
ZoneData_ch3.Regions = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.regions then
        for name, region in pairs(zoneModule.regions) do
            ZoneData_ch3.Regions[name] = region
        end
    end
end

-- 怪物刷新点（8座寨子 + 3片野外走廊）
ZoneData_ch3.SpawnPoints = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.spawns then
        for _, sp in ipairs(zoneModule.spawns) do
            table.insert(ZoneData_ch3.SpawnPoints, sp)
        end
    end
end

-- 装饰物
ZoneData_ch3.TownDecorations = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.decorations then
        for _, deco in ipairs(zoneModule.decorations) do
            table.insert(ZoneData_ch3.TownDecorations, deco)
        end
    end
end

-- NPC
ZoneData_ch3.NPCs = {}
for _, zoneModule in ipairs(ALL_ZONES) do
    if zoneModule.npcs then
        for _, npc in ipairs(zoneModule.npcs) do
            table.insert(ZoneData_ch3.NPCs, npc)
        end
    end
end

-- 第九寨废墟交互物件：上宝逊金钯（interactType = "divine_rake" → 直接打开ArtifactUI）
table.insert(ZoneData_ch3.NPCs, {
    name = "上宝逊金钯", subtitle = "天蓬元帅旧兵器",
    x = 15, y = 18, icon = "🔱",
    interactType = "divine_rake",
    isObject = true, label = "上宝逊金钯",
    -- dialog 不再使用静态文本，由 NPCDialog.Show 中 divine_rake 分支直接打开 ArtifactUI
})

-- 湖泊中的朱老二NPC（出售第9片碎片）
-- 位置：湖泊中央沙地岛（GameMap 会在此处生成3×3 SAND_FLOOR平台）
ZoneData_ch3.MYSTERIOUS_MERCHANT_POS = { x = 63, y = 27 }

table.insert(ZoneData_ch3.NPCs, {
    name = "朱老二", subtitle = "浪迹天涯的行商",
    x = ZoneData_ch3.MYSTERIOUS_MERCHANT_POS.x + 0.5,
    y = ZoneData_ch3.MYSTERIOUS_MERCHANT_POS.y + 0.5,
    icon = "🐷",
    interactType = "mysterious_merchant",
    portrait = "Textures/npc_zhu_laoer.png",
    label = "朱老二",
})

-- 第三章无传统主城围墙
ZoneData_ch3.TOWN_GATES = {}

-- 玩家出生点（第九寨安全区上半部分）
ZoneData_ch3.SPAWN_POINT = fort9Data.spawnPoint or { x = 15.5, y = 10.5 }

-- 暴露所有区域模块列表
ZoneData_ch3.ALL_ZONES = ALL_ZONES

-- 暴露第九寨数据（供 GameMap 废墟特殊处理）
ZoneData_ch3.fort9Data = fort9Data

-- ============================================================================
-- 城寨网格定义（供 GameMap 第三章地形生成器使用）
-- ============================================================================

-- 3×3 城寨布局: fortGrid[row][col] = zone module
-- row/col 从 1 开始
--   行1(y=8~23):  ⑨  ⑧  ⑥
--   行2(y=32~47): ⑦  ⑤  ③
--   行3(y=56~71): ④  ②  ①
ZoneData_ch3.fortGrid = {
    { fort9Data, fort8Data, fort6Data },
    { fort7Data, fort5Data, fort3Data },
    { fort4Data, fort2Data, fort1Data },
}

-- 网格坐标常量
ZoneData_ch3.GRID = {
    colX = { 8, 32, 56 },      -- 每列寨子 x1
    rowY = { 8, 32, 56 },      -- 每行寨子 y1
    fortSize = 16,              -- 每寨 16×16
    corridorX = { 24, 48 },    -- 列间走廊 x1 (宽8)
    corridorY = { 24, 48 },    -- 行间走廊 y1 (宽8)
    corridorW = 8,              -- 走廊宽度
}

-- 道路连接定义（寨间 + 入口/出口）
-- 每条: { from={row,col}, to={row,col}, axis="h"|"v" }
-- 特殊: entrance / exit
ZoneData_ch3.roads = {
    -- 横向（同行）
    { from = {1,1}, to = {1,2}, axis = "h" },  -- ⑨→⑧
    { from = {1,2}, to = {1,3}, axis = "h" },  -- ⑧→⑥
    { from = {2,1}, to = {2,2}, axis = "h" },  -- ⑦→⑤
    { from = {2,2}, to = {2,3}, axis = "h" },  -- ⑤→③
    { from = {3,1}, to = {3,2}, axis = "h" },  -- ④→②
    { from = {3,2}, to = {3,3}, axis = "h" },  -- ②→①
    -- 纵向（同列）
    { from = {1,1}, to = {2,1}, axis = "v" },  -- ⑨→⑦
    { from = {1,2}, to = {2,2}, axis = "v" },  -- ⑧→⑤
    -- { from = {1,3}, to = {2,3}, axis = "v" },  -- ⑥→③ 湖泊阻断
    { from = {2,1}, to = {3,1}, axis = "v" },  -- ⑦→④
    -- { from = {2,2}, to = {3,2}, axis = "v" },  -- ⑤→② 湖泊阻断
    { from = {2,3}, to = {3,3}, axis = "v" },  -- ③→①
    -- 入口（地图顶部→⑨北墙）
    { type = "entrance", fort = {1,1}, side = "north" },
    -- 出口（②南墙→地图底部）
    { type = "exit", fort = {3,2}, side = "south" },
}

-- ============================================================================
-- 瓦片颜色定义（供 TileRenderer / WorldRenderer 数据驱动读取）
-- ============================================================================
local T = ZoneData_ch3.TILE

ZoneData_ch3.TILE_COLORS = {
    -- ch1 共享瓦片
    [T.GRASS]        = {80, 140, 60, 255},
    [T.CAVE_FLOOR]   = {100, 90, 80, 255},
    [T.FOREST_FLOOR] = {50, 100, 40, 255},
    [T.MOUNTAIN]     = {120, 110, 100, 255},
    [T.WATER]        = {60, 120, 180, 255},
    [T.CAMP_FLOOR]   = {100, 90, 80, 255},
    [T.TIGER_GROUND] = {35, 75, 30, 255},
    -- ch2 共享瓦片
    [T.FORTRESS_WALL]  = {60, 55, 50, 255},
    [T.FORTRESS_FLOOR] = {90, 70, 60, 255},
    [T.SWAMP]          = {50, 65, 40, 255},
    [T.SEALED_GATE]    = {80, 70, 30, 255},
    [T.CRYSTAL_STONE]  = {100, 60, 120, 255},
    [T.CAMP_DIRT]      = {120, 100, 70, 255},
    [T.BATTLEFIELD]    = {75, 55, 40, 255},
    -- ch3 新增瓦片
    [T.SAND_WALL]  = {160, 130, 70, 255},
    [T.DESERT]     = {210, 190, 130, 255},
    [T.SAND_FLOOR] = {180, 155, 110, 255},
    [T.SAND_ROAD]  = {200, 175, 130, 255},
    [T.SAND_DARK]  = {175, 150, 95, 255},
    [T.SAND_LIGHT] = {230, 215, 165, 255},
    [T.DRIED_GRASS]   = {165, 155, 80, 255},
    [T.CRACKED_EARTH] = {120, 95, 60, 255},
}

-- 可通行瓦片集合（区域过渡渐变用）
ZoneData_ch3.WALKABLE_TILES = {
    -- ch1 共享
    [T.GRASS] = true, [T.TOWN_FLOOR] = true, [T.TOWN_ROAD] = true,
    [T.CAVE_FLOOR] = true, [T.FOREST_FLOOR] = true,
    [T.CAMP_FLOOR] = true, [T.TIGER_GROUND] = true,
    -- ch2 共享
    [T.FORTRESS_FLOOR] = true, [T.SWAMP] = true,
    [T.CAMP_DIRT] = true, [T.BATTLEFIELD] = true,
    -- ch3 新增
    [T.DESERT] = true, [T.SAND_FLOOR] = true, [T.SAND_ROAD] = true,
    [T.SAND_DARK] = true, [T.SAND_LIGHT] = true, [T.DRIED_GRASS] = true,
    [T.CRACKED_EARTH] = true,
}

-- 区域过渡渐变色 {r, g, b}
ZoneData_ch3.TILE_TRANSITION_COLORS = {
    [T.GRASS]        = {80, 140, 60},
    [T.CAVE_FLOOR]   = {95, 85, 75},
    [T.CAMP_FLOOR]   = {105, 90, 70},
    [T.DESERT]       = {210, 190, 130},
    [T.SAND_FLOOR]   = {180, 155, 110},
    [T.SAND_ROAD]    = {200, 175, 130},
}

-- ============================================================================
-- 图鉴区域分组（供 SystemMenu 怪物图鉴展示，key = MonsterData.zone）
-- 从外到里：第八寨 → 第一寨，穿插野外精英区
-- ============================================================================

ZoneData_ch3.BESTIARY_ZONES = {
    order = {
        "ch3_fort_8", "ch3_fort_7", "ch3_wild_outer",
        "ch3_fort_6", "ch3_fort_5", "ch3_fort_4", "ch3_wild_mid",
        "ch3_fort_3", "ch3_fort_2", "ch3_wild_inner",
        "ch3_fort_1",
    },
    names = {
        ch3_fort_8     = "第八寨",
        ch3_fort_7     = "第七寨",
        ch3_wild_outer = "外围荒漠",
        ch3_fort_6     = "第六寨",
        ch3_fort_5     = "第五寨",
        ch3_fort_4     = "第四寨",
        ch3_wild_mid   = "中域荒漠",
        ch3_fort_3     = "第三寨",
        ch3_fort_2     = "第二寨",
        ch3_wild_inner = "内域荒漠",
        ch3_fort_1     = "第一寨",
    },
}

ZoneData_ch3.ZONE_INFO = {
    ch3_fort_9     = { name = "第九寨·废寨",   levelRange = nil },
    ch3_fort_8     = { name = "第八寨·枯木寨", levelRange = {33, 36} },
    ch3_fort_7     = { name = "第七寨·岩蟾寨", levelRange = {37, 40} },
    ch3_wild_outer = { name = "外围荒漠",       levelRange = {41, 41} },
    ch3_fort_6     = { name = "第六寨·苍狼寨", levelRange = {41, 44} },
    ch3_fort_5     = { name = "第五寨·赤甲寨", levelRange = {45, 48} },
    ch3_fort_4     = { name = "第四寨·蛇骨寨", levelRange = {49, 52} },
    ch3_wild_mid   = { name = "中域荒漠",       levelRange = {56, 56} },
    ch3_fort_3     = { name = "第三寨·赤焰寨", levelRange = {53, 56} },
    ch3_fort_2     = { name = "第二寨·蜃妖寨", levelRange = {57, 60} },
    ch3_wild_inner = { name = "内域荒漠",       levelRange = {63, 63} },
    ch3_fort_1     = { name = "第一寨·黄天寨", levelRange = {65, 65} },
}

return ZoneData_ch3
