-- ============================================================================
-- spider_cave.lua - 蜘蛛洞区域数据
-- ============================================================================

local spider_cave = {}

-- 区域范围（外层 + 巢穴）
spider_cave.regions = {
    spider_outer = { x1 = 43, y1 = 52, x2 = 79, y2 = 79, zone = "spider_cave" },
    spider_nest  = { x1 = 62, y1 = 55, x2 = 77, y2 = 77, zone = "spider_cave" },
}

-- 怪物刷新点
-- 外层 (43,52)→(79,79)，DrawBorder 概率墙(30%WALL)在边界1格
-- Barriers: ScatterWildernessRocks (38,52)→(44,60) 20%密度碎石
-- 装饰阻挡: cobweb/mushroom/crystal/stalactite 均不阻挡移动
-- 安全外层区域: x=45~60, y=54~77（避开边界概率墙+西侧碎石过渡）
--
-- 巢穴 (62,55)→(77,77)，DrawBorder 概率墙(30%WALL)在边界1格
-- 装饰阻挡: cobweb/crystal/mushroom/bone_pile 均不阻挡移动
-- 安全巢穴区域: x=64~75, y=57~75
spider_cave.spawns = {
    -- ===== 蜘蛛洞外层 (43,52)→(61,79) Lv.3~5 + 精英6 =====
    -- 入口区域（北部）
    { type = "spider_small", x = 47, y = 56 },   -- 避开碎石过渡区 x=43~44
    { type = "spider_small", x = 51, y = 58 },   -- 安全
    { type = "spider_small", x = 54, y = 56 },   -- 安全
    { type = "spider_small", x = 57, y = 55 },   -- 安全
    -- 西侧通道
    { type = "spider_small", x = 46, y = 63 },   -- 安全，避开碎石区上限
    { type = "spider_small", x = 48, y = 70 },   -- 安全
    { type = "spider_small", x = 47, y = 76 },   -- 安全，避开边界 x=43
    { type = "spider_small", x = 50, y = 73 },   -- 安全
    -- 中部区域
    { type = "spider_small", x = 54, y = 62 },   -- 安全
    { type = "spider_small", x = 57, y = 65 },   -- 安全
    { type = "spider_small", x = 55, y = 72 },   -- 安全
    { type = "spider_small", x = 58, y = 76 },   -- 安全
    -- 东部区域
    { type = "spider_small", x = 60, y = 68 },   -- 安全
    { type = "spider_small", x = 56, y = 60 },   -- 安全
    { type = "spider_small", x = 54, y = 75 },   -- 安全
    { type = "spider_small", x = 59, y = 70 },   -- 安全
    -- 精英蜘蛛（Lv.6）
    { type = "spider_elite", x = 49, y = 62 },   -- 安全
    { type = "spider_elite", x = 56, y = 72 },   -- 安全
    { type = "spider_elite", x = 52, y = 66 },   -- 安全

    -- ===== 蜘蛛巢穴 (62,55)→(77,77) 毒蛛精×5 + BOSS蛛母 =====
    { type = "spider_elite", x = 66, y = 59 },   -- 安全
    { type = "spider_elite", x = 73, y = 61 },   -- 安全，避开边界 y=55
    { type = "spider_elite", x = 67, y = 66 },   -- 安全
    { type = "spider_elite", x = 74, y = 68 },   -- 安全
    { type = "spider_elite", x = 68, y = 73 },   -- 安全
    { type = "spider_queen", x = 70, y = 68 },   -- BOSS 蛛母 Lv.8，中心位置
}

-- 装饰物
spider_cave.decorations = {
    -- ============================================================
    -- 蜘蛛洞外层装饰物 (43,52)→(79,79)
    -- 主题：阴暗洞穴 — 蛛网、蘑菇丛、发光水晶、滴水石笋
    -- ============================================================
    -- 蛛网（入口、角落、通道口）
    { type = "cobweb", x = 46, y = 54 },
    { type = "cobweb", x = 48, y = 62 },
    { type = "cobweb", x = 45, y = 74 },
    { type = "cobweb", x = 55, y = 60 },
    { type = "cobweb", x = 75, y = 70 },
    { type = "cobweb", x = 58, y = 75 },
    -- 蘑菇丛（沿洞壁潮湿角落）
    { type = "mushroom", x = 46, y = 57, color = {170, 140, 200, 255} },
    { type = "mushroom", x = 56, y = 55, color = {170, 150, 190, 255} },
    { type = "mushroom", x = 53, y = 68, color = {180, 160, 200, 255} },
    { type = "mushroom", x = 49, y = 68, color = {160, 180, 150, 255} },
    { type = "mushroom", x = 46, y = 75, color = {180, 150, 190, 255} },
    { type = "mushroom", x = 56, y = 75, color = {160, 180, 140, 255} },
    -- 发光水晶（散发幽蓝/紫光）
    { type = "crystal", x = 47, y = 60, color = {80, 180, 220, 255} },
    { type = "crystal", x = 56, y = 63, color = {80, 200, 200, 255} },
    { type = "crystal", x = 54, y = 74, color = {100, 160, 255, 255} },
    -- 滴水石笋
    { type = "stalactite", x = 49, y = 56 },
    { type = "stalactite", x = 45, y = 70 },
    { type = "stalactite", x = 75, y = 60 },
    { type = "stalactite", x = 55, y = 66 },

    -- ============================================================
    -- 蜘蛛巢穴装饰物 (62,55)→(77,77) 墙厚2-3，安全区 x=65~74, y=58~74
    -- 入口在西侧 y=65~68
    -- 主题：密集蛛网、更多水晶、骨堆
    -- ============================================================
    { type = "cobweb", x = 67, y = 58 },
    { type = "cobweb", x = 73, y = 58 },
    { type = "cobweb", x = 65, y = 73 },
    { type = "cobweb", x = 73, y = 74 },
    { type = "cobweb", x = 69, y = 62 },
    { type = "cobweb", x = 73, y = 70 },
    { type = "crystal", x = 66, y = 60, color = {200, 60, 255, 255} },
    { type = "crystal", x = 73, y = 66, color = {255, 60, 160, 255} },
    { type = "crystal", x = 67, y = 73, color = {160, 60, 255, 255} },
    { type = "mushroom", x = 70, y = 63, color = {200, 120, 220, 255} },
    { type = "mushroom", x = 65, y = 72, color = {220, 140, 200, 255} },
    { type = "bone_pile", x = 71, y = 72 },
    { type = "bone_pile", x = 66, y = 66 },
}

-- 地图生成配置
spider_cave.generation = {
    -- 每个子区域的填充和边界
    subRegions = {
        {
            regionKey = "spider_outer",
            fill = { tile = "CAVE_FLOOR" },
            border = {
                tile = "MOUNTAIN",       -- 外围用岩块（非墙壁）
                minThick = 1,
                maxThick = 2,
                gaps = {
                    { side = "north", from = 43, to = 48 },  -- 北侧入口（野猪林方向）
                    { side = "north", from = 58, to = 63 },  -- 北侧入口（羊肠小径方向）
                    { side = "north", from = 74, to = 77 },  -- 北侧东端（对齐巢穴NE出口，通往羊肠小径）
                    { side = "west",  from = 55, to = 60 },  -- 西侧入口（野猪林方向）
                },
                openSides = { "east", "south" },  -- 半开放：东/南靠地图边缘不建墙
            },
            erosion = { maxDepth = 2, protect = { south = true, east = true } },
        },
        {
            regionKey = "spider_nest",
            fill = { tile = "CAVE_FLOOR" },
            border = {
                tile = "WALL",           -- 内层巢穴用墙壁
                minThick = 2,
                maxThick = 3,
                gaps = {
                    { side = "north", from = 75, to = 76 },  -- 东北小路（2格窄道，靠近羊肠小径）
                    { side = "west",  from = 72, to = 77 },  -- 西南大缺口（6格宽，通往外层）
                },
            },
        },
    },
}

return spider_cave
