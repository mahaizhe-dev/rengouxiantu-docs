-- ============================================================================
-- TileTypes.lua - 共享瓦片资源库（跨章节通用）
-- 所有章节的 ZoneData 引用此模块获取瓦片枚举和通行性定义
-- 新增瓦片类型只需在此追加，所有章节自动可用
-- ============================================================================

local TileTypes = {}

-- ============================================================================
-- 瓦片枚举（全局唯一 ID，不可重复）
-- ============================================================================

TileTypes.TILE = {
    -- 基础瓦片（ch1 起始）
    GRASS        = 1,
    TOWN_FLOOR   = 2,
    TOWN_ROAD    = 3,
    CAVE_FLOOR   = 4,
    FOREST_FLOOR = 5,
    MOUNTAIN     = 6,
    WATER        = 7,
    WALL         = 8,
    CAMP_FLOOR   = 9,
    TIGER_GROUND = 10,

    -- ch2 新增瓦片
    FORTRESS_WALL  = 11,   -- 堡墙（不可通行）
    FORTRESS_FLOOR = 12,   -- 堡内地面
    SWAMP          = 13,   -- 沼泽/骷髅场地面
    SEALED_GATE    = 14,   -- 封印大门（不可通行）
    CRYSTAL_STONE  = 15,   -- 晶石屏障（不可通行）
    CAMP_DIRT      = 16,   -- 营地土地
    BATTLEFIELD    = 17,   -- 战场焦土（修罗场）

    -- ch3 新增瓦片
    SAND_WALL      = 18,   -- 沙岩城墙（不可通行）
    DESERT         = 19,   -- 沙漠地面
    SAND_FLOOR     = 20,   -- 城寨内地面
    SAND_ROAD      = 21,   -- 沙漠主路
    SAND_DARK      = 22,   -- 砾石硬沙（深色，道路/踩踏区）
    SAND_LIGHT     = 23,   -- 流沙细沙（浅色，开阔区/沙丘边缘）
    DRIED_GRASS    = 24,   -- 枯黄杂草（水源附近残存植被）
    CRACKED_EARTH  = 25,   -- 裂地（神器遗迹区域）

    -- ch4 新增瓦片（通用海域）
    DEEP_SEA       = 26,   -- 深海（不可通行，地图底色）
    SHALLOW_SEA    = 27,   -- 浅海（不可通行，航道/环形带）
    REEF_FLOOR     = 28,   -- 礁石地面（岛屿可通行地面）
    CORAL_WALL     = 29,   -- 珊瑚墙（岛屿边界，不可通行）
    ROCK_REEF      = 30,   -- 岩礁（爻纹障碍，不可通行）
    SEA_SAND       = 31,   -- 海沙地（中央岛地面）

    -- ch4 龙种岛专属瓦片
    ICE_FLOOR      = 32,   -- 冰原地面（可通行，玄冰岛·封霜应龙）
    ICE_WALL       = 33,   -- 冰岩壁（不可通行，玄冰岛）
    ABYSS_FLOOR    = 34,   -- 深渊地面（可通行，幽渊岛·堕渊蛟龙）
    ABYSS_WALL     = 35,   -- 深渊暗礁（不可通行，幽渊岛）
    VOLCANO_FLOOR  = 36,   -- 熔岩地面（可通行，烈焰岛·焚天蜃龙）
    VOLCANO_WALL   = 37,   -- 熔岩岩壁（不可通行，烈焰岛）
    DUNE_FLOOR     = 38,   -- 沙丘地面（可通行，流沙岛·蚀骨螭龙）
    DUNE_WALL      = 39,   -- 沙岩壁（不可通行，流沙岛）

    -- 中洲（特殊章节 ID 101）新增瓦片
    CELESTIAL_FLOOR  = 40,   -- 仙府地面（青石长街，可通行）
    CELESTIAL_WALL   = 41,   -- 仙府城墙（琉璃飞檐，不可通行）
    CELESTIAL_ROAD   = 42,   -- 仙府主道（灵气长街，可通行）
    RIFT_VOID        = 43,   -- 天裂峡谷（深不见底，不可通行）
    BRIDGE_FLOOR     = 44,   -- 桥梁地面（跨裂谷桥，可通行）
    BATTLEFIELD_VOID = 45,   -- 战场封印地面（封印中，不可通行）
    CORRUPTED_GROUND = 46,   -- 魔化焦土（可通行，战场内部地面）
    LIGHT_CURTAIN    = 47,   -- 光幕分隔（战场之间，不可通行）
    SEAL_RED         = 48,   -- 红色封印（战场入口，不可通行，可交互解封）
    YAOCHI_CLIFF     = 49,   -- 瑶池崖壁（高崖瀑布水源，不可通行）
    HERB_FIELD       = 50,   -- 药田（灵药种植区，可通行）
    MARKET_STREET    = 51,   -- 商业街（青云城主街，可通行）

    -- ch5 新增瓦片（太虚之殇）
    CH5_CAMP_DIRT         = 52,   -- 前营土地（可通行）
    CH5_CAMP_FLAGSTONE    = 53,   -- 前营修补石板（可通行）
    CH5_RUIN_BLUESTONE    = 54,   -- 废墟青石（可通行）
    CH5_RUIN_CRACKED      = 55,   -- 废墟裂石（可通行）
    CH5_FORGE_BLACKSTONE  = 56,   -- 铸剑焦黑石（可通行）
    CH5_FORGE_MOLTEN      = 57,   -- 熔裂纹地面（可通行）
    CH5_COURTYARD_MOSS    = 58,   -- 苔藓院石（可通行）
    CH5_COLD_JADE         = 59,   -- 寒池玉石地（可通行）
    CH5_COLD_ICE_EDGE     = 60,   -- 寒池冰边（不可通行）
    CH5_STELE_PALE        = 61,   -- 碑林苍白石（可通行）
    CH5_LIBRARY_BURNT     = 62,   -- 藏经焚毁地面（可通行）
    CH5_PALACE_WHITE      = 63,   -- 剑宫白石（可通行）
    CH5_PALACE_CORRUPTED  = 64,   -- 剑宫侵蚀脉络（可通行）
    CH5_BLOOD_RITUAL      = 65,   -- 血祭石（可通行）
    CH5_ABYSS_CHARRED     = 66,   -- 深渊焦岩（可通行）
    CH5_ABYSS_FLESH       = 67,   -- 深渊血肉岩（不可通行）
    CH5_CORRIDOR_DARK     = 68,   -- 回廊暗石（可通行）
    CH5_CORRIDOR_SWORD    = 69,   -- 回廊剑金属（不可通行）
    CH5_VOID              = 70,   -- 虚空/深渊（不可通行，地图底色）
    CH5_WALL              = 71,   -- 废墟墙体（不可通行）
    CH5_CLIFF             = 72,   -- 断崖边缘（不可通行）
    CH5_SEALED_GATE       = 73,   -- 封印门（不可通行）
    CH5_BRIDGE            = 74,   -- 桥面（可通行）
    CH5_CITY_WALL         = 75,   -- 剑气城墙（不可通行）
    CH5_WALL_BATTLEMENT   = 76,   -- 城垛（不可通行）
    CH5_WALL_COLLAPSED    = 77,   -- 坍塌城墙（可通行，废墟碎石）
    CH5_BLOOD_RIVER       = 78,   -- 血河（不可通行）
    CH5_STELE_INTACT      = 79,   -- 完整石碑（不可通行，碑林装饰）
    CH5_STELE_BROKEN      = 80,   -- 断壁残碑（可通行，碑林装饰）
    CH5_LAVA_WALL         = 81,   -- 岩浆墙（不可通行，深渊围墙）
    CH5_BLOOD_POOL        = 82,   -- 祀剑池（不可通行，可交互 3×2 PNG）
    CH5_FURNACE           = 83,   -- 铸剑地炉（不可通行，可交互 3×3 PNG）
}

-- ============================================================================
-- 通行性定义
-- ============================================================================

TileTypes.WALKABLE = {
    [1]  = true,   -- GRASS
    [2]  = true,   -- TOWN_FLOOR
    [3]  = true,   -- TOWN_ROAD
    [4]  = true,   -- CAVE_FLOOR
    [5]  = true,   -- FOREST_FLOOR
    [6]  = false,  -- MOUNTAIN
    [7]  = false,  -- WATER
    [8]  = false,  -- WALL
    [9]  = true,   -- CAMP_FLOOR
    [10] = true,   -- TIGER_GROUND
    [11] = false,  -- FORTRESS_WALL
    [12] = true,   -- FORTRESS_FLOOR
    [13] = true,   -- SWAMP
    [14] = false,  -- SEALED_GATE
    [15] = false,  -- CRYSTAL_STONE
    [16] = true,   -- CAMP_DIRT
    [17] = true,   -- BATTLEFIELD
    [18] = false,  -- SAND_WALL
    [19] = true,   -- DESERT
    [20] = true,   -- SAND_FLOOR
    [21] = true,   -- SAND_ROAD
    [22] = true,   -- SAND_DARK
    [23] = true,   -- SAND_LIGHT
    [24] = true,   -- DRIED_GRASS
    [25] = true,   -- CRACKED_EARTH
    [26] = false,  -- DEEP_SEA
    [27] = false,  -- SHALLOW_SEA
    [28] = true,   -- REEF_FLOOR
    [29] = false,  -- CORAL_WALL
    [30] = false,  -- ROCK_REEF
    [31] = true,   -- SEA_SAND
    [32] = true,   -- ICE_FLOOR
    [33] = false,  -- ICE_WALL
    [34] = true,   -- ABYSS_FLOOR
    [35] = false,  -- ABYSS_WALL
    [36] = true,   -- VOLCANO_FLOOR
    [37] = false,  -- VOLCANO_WALL
    [38] = true,   -- DUNE_FLOOR
    [39] = false,  -- DUNE_WALL
    -- 中洲
    [40] = true,   -- CELESTIAL_FLOOR
    [41] = false,  -- CELESTIAL_WALL
    [42] = true,   -- CELESTIAL_ROAD
    [43] = false,  -- RIFT_VOID
    [44] = true,   -- BRIDGE_FLOOR
    [45] = false,  -- BATTLEFIELD_VOID
    [46] = true,   -- CORRUPTED_GROUND
    [47] = false,  -- LIGHT_CURTAIN
    [48] = false,  -- SEAL_RED
    [49] = false,  -- YAOCHI_CLIFF
    [50] = true,   -- HERB_FIELD
    [51] = true,   -- MARKET_STREET
    -- ch5 太虚之殇
    [52] = true,   -- CH5_CAMP_DIRT
    [53] = true,   -- CH5_CAMP_FLAGSTONE
    [54] = true,   -- CH5_RUIN_BLUESTONE
    [55] = true,   -- CH5_RUIN_CRACKED
    [56] = true,   -- CH5_FORGE_BLACKSTONE
    [57] = true,   -- CH5_FORGE_MOLTEN
    [58] = true,   -- CH5_COURTYARD_MOSS
    [59] = true,   -- CH5_COLD_JADE
    [60] = false,  -- CH5_COLD_ICE_EDGE
    [61] = true,   -- CH5_STELE_PALE
    [62] = true,   -- CH5_LIBRARY_BURNT
    [63] = true,   -- CH5_PALACE_WHITE
    [64] = true,   -- CH5_PALACE_CORRUPTED
    [65] = true,   -- CH5_BLOOD_RITUAL
    [66] = true,   -- CH5_ABYSS_CHARRED
    [67] = false,  -- CH5_ABYSS_FLESH
    [68] = true,   -- CH5_CORRIDOR_DARK
    [69] = false,  -- CH5_CORRIDOR_SWORD
    [70] = false,  -- CH5_VOID
    [71] = false,  -- CH5_WALL
    [72] = false,  -- CH5_CLIFF
    [73] = false,  -- CH5_SEALED_GATE
    [74] = true,   -- CH5_BRIDGE
    [75] = true,   -- CH5_CITY_WALL（可行走城墙面）
    [76] = false,  -- CH5_WALL_BATTLEMENT（城垛，不可通行，隔断）
    [77] = true,   -- CH5_WALL_COLLAPSED
    [78] = false,  -- CH5_BLOOD_RIVER
    [79] = false,  -- CH5_STELE_INTACT（完整石碑，不可通行）
    [80] = true,   -- CH5_STELE_BROKEN（断壁残碑，可通行）
    [81] = false,  -- CH5_LAVA_WALL（岩浆墙，不可通行）
    [82] = false,  -- CH5_BLOOD_POOL（祀剑池，不可通行，可交互）
    [83] = false,  -- CH5_FURNACE（铸剑地炉，不可通行，可交互）
}

return TileTypes
