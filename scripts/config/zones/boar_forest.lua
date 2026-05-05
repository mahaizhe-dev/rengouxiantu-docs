-- ============================================================================
-- boar_forest.lua - 野猪林区域数据
-- ============================================================================

local boar_forest = {}

-- 区域范围
boar_forest.regions = {
    boar_forest = { x1 = 2, y1 = 52, x2 = 38, y2 = 79, zone = "boar_forest" },
}

-- 怪物刷新点
-- 区域 (2,52)→(38,79)，DrawBorder 概率墙(无border配置但erosion侵蚀)
-- 实际边界: DrawBorder 未对 boar_forest 设置（原版无边界）
-- Barriers: 无独立山脊，但 ScatterWildernessRocks 在 (5,49)→(38,54) 15%密度
--   和 (38,52)→(44,60) 20%密度放碎石
-- 装饰阻挡: fallen_tree(10,58)(28,64)(18,72)(36,76), pond(26,67 2x2)(10,73 2x2)
-- 安全可用区域: x=4~36, y=55~77（避开北部碎石过渡带+装饰）
boar_forest.spawns = {
    -- 北部入口区域（避开碎石过渡带 y=49~54）
    { type = "boar_small", x = 20, y = 57 },   -- 下移避开碎石区
    { type = "boar_small", x = 30, y = 56 },   -- 下移避开碎石区
    { type = "boar_small", x = 35, y = 58 },   -- 下移避开碎石和 fallen_tree(10,58)
    -- 西部森林
    { type = "boar_small", x = 6,  y = 61 },   -- 安全
    { type = "boar_small", x = 12, y = 64 },   -- 安全
    { type = "boar_small", x = 8,  y = 69 },   -- 安全
    { type = "boar_small", x = 15, y = 76 },   -- 安全
    -- 中部森林
    { type = "boar_small", x = 25, y = 62 },   -- 安全
    { type = "boar_small", x = 30, y = 70 },   -- 避开 fallen_tree(28,64) 和 pond(26,67~68)
    { type = "boar_small", x = 22, y = 75 },   -- 安全
    { type = "boar_small", x = 34, y = 72 },   -- 安全
    -- 东部森林
    { type = "boar_small", x = 33, y = 65 },   -- 安全
    { type = "boar_small", x = 36, y = 70 },   -- 安全，避开边界 x=38
    { type = "boar_small", x = 31, y = 77 },   -- 安全
    -- 精英（Lv.9 野猪统领）
    { type = "boar_captain", x = 15, y = 65 },  -- 安全
    { type = "boar_captain", x = 28, y = 74 },  -- 安全
    -- BOSS（深处，Lv.10）
    { type = "boar_king",  x = 20, y = 70 },    -- 安全
}

-- 装饰物
boar_forest.decorations = {
    -- 倒木（横卧的树干）
    { type = "fallen_tree", x = 10, y = 58 },
    { type = "fallen_tree", x = 28, y = 64 },
    { type = "fallen_tree", x = 18, y = 72 },
    { type = "fallen_tree", x = 36, y = 76 },
    -- 灌木丛
    { type = "bush", x = 5,  y = 56, color = {40, 110, 35, 255} },
    { type = "bush", x = 16, y = 58, color = {50, 120, 40, 255} },
    { type = "bush", x = 35, y = 62, color = {45, 105, 30, 255} },
    { type = "bush", x = 8,  y = 66, color = {38, 100, 32, 255} },
    { type = "bush", x = 24, y = 76, color = {42, 108, 36, 255} },
    { type = "bush", x = 5,  y = 75, color = {48, 115, 38, 255} },
    -- 花丛（森林中的野花）
    { type = "flower", x = 14, y = 60 },
    { type = "flower", x = 32, y = 66 },
    { type = "flower", x = 10, y = 76 },
    -- 小池塘（占 2x2）
    { type = "pond", x = 26, y = 67, w = 2, h = 2 },
    { type = "pond", x = 10, y = 73, w = 2, h = 2 },
    -- 森林中的树木（更高大、颜色更深）
    { type = "tree", x = 4,  y = 54, color = {35, 95, 30, 255} },
    { type = "tree", x = 18, y = 56, color = {30, 90, 25, 255} },
    { type = "tree", x = 33, y = 58, color = {40, 100, 35, 255} },
    { type = "tree", x = 7,  y = 65, color = {32, 88, 28, 255} },
    { type = "tree", x = 36, y = 68, color = {35, 92, 30, 255} },
    { type = "tree", x = 22, y = 70, color = {38, 98, 33, 255} },
    { type = "tree", x = 5,  y = 76, color = {33, 90, 28, 255} },
    { type = "tree", x = 30, y = 77, color = {36, 95, 32, 255} },
}

-- 地图生成配置
boar_forest.generation = {
    fill = { tile = "FOREST_FLOOR" },
    border = {
        tile = "MOUNTAIN",
        minThick = 1,
        maxThick = 2,
        gaps = {
            { side = "north", from = 18, to = 23 },  -- 北侧入口（主城→野猪林）
            { side = "north", from = 5,  to = 10 },  -- 北侧通道（→山贼寨方向）
            { side = "east",  from = 55, to = 60 },  -- 东侧通道（→蜘蛛洞）
        },
        openSides = { "west", "south" },  -- 半开放：西/南靠地图边缘不建墙
    },
    erosion = { maxDepth = 3, protect = { south = true, west = true } },
}

return boar_forest
