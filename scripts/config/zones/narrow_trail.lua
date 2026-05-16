-- ============================================================================
-- narrow_trail.lua - 羊肠小径区域数据
-- ============================================================================

local narrow_trail = {}

-- 区域范围
narrow_trail.regions = {
    narrow_trail = { x1 = 52, y1 = 28, x2 = 79, y2 = 50, zone = "narrow_trail" },
}

-- 怪物刷新点
-- 区域 (52,28)→(79,50)，DrawBorder 概率墙(25%MOUNTAIN)在边界1格
-- Barriers: ScatterWildernessRocks (49,30)→(53,50) 10%密度碎石，(52,25)→(60,30) 18%密度碎石
-- 补充山脉 (51,26)→(55,29)
-- 装饰阻挡: cobweb/bush/tree/sign 均不阻挡移动
-- 安全可用区域: x=55~77, y=31~48（避开西侧碎石+北侧碎石+边界概率墙）
narrow_trail.spawns = {
    { type = "spider_trail", x = 57, y = 34 },   -- 避开碎石过渡 x=52~54
    { type = "spider_trail", x = 63, y = 35 },   -- 安全
    { type = "spider_trail", x = 69, y = 33 },   -- 安全
    { type = "spider_trail", x = 74, y = 35 },   -- 安全
    { type = "spider_trail", x = 57, y = 43 },   -- 安全
    { type = "spider_trail", x = 64, y = 41 },   -- 安全
    { type = "spider_trail", x = 70, y = 45 },   -- 安全
    { type = "spider_trail", x = 75, y = 41 },   -- 安全
    { type = "spider_trail", x = 61, y = 38 },   -- 中部补点
    -- 巡逻Boss：拦路猪妖（waypoint_loop，覆盖主通路）
    {
        type = "boar_patrol", x = 66, y = 39,
        patrolPreset = "waypoint_loop",
        patrol = {
            nodes = {
                { x = 58, y = 34 },
                { x = 64, y = 35 },
                { x = 71, y = 34 },
                { x = 75, y = 39 },
                { x = 69, y = 45 },
                { x = 60, y = 43 },
            },
        },
    },
}

-- 装饰物
narrow_trail.decorations = {
    -- 蛛网（稀疏，暗示蜘蛛出没）
    { type = "cobweb", x = 54, y = 32 },
    { type = "cobweb", x = 71, y = 44 },
    { type = "cobweb", x = 65, y = 38 },
    -- 灌木丛
    { type = "bush", x = 56, y = 34, color = {50, 110, 40, 255} },
    { type = "bush", x = 68, y = 42, color = {45, 105, 35, 255} },
    { type = "bush", x = 75, y = 36, color = {55, 115, 45, 255} },
    { type = "bush", x = 60, y = 47, color = {48, 108, 38, 255} },
    -- 树木（小径两旁）
    { type = "tree", x = 58, y = 30, color = {40, 100, 35, 255} },
    { type = "tree", x = 72, y = 40, color = {45, 105, 40, 255} },
    { type = "tree", x = 66, y = 46, color = {38, 95, 32, 255} },
    { type = "tree", x = 76, y = 32, color = {42, 98, 36, 255} },
    -- 路标
    { type = "sign", x = 54, y = 40, label = "羊肠小径" },
}

-- 地图生成配置
narrow_trail.generation = {
    fill = {
        tile = "GRASS",          -- 基底保持草地
        scatter = "CAVE_FLOOR",  -- 散布洞穴地砖
        scatterPercent = 15,     -- 15% 概率
    },
    border = {
        tile = "MOUNTAIN",
        minThick = 1,
        maxThick = 2,
        gaps = {
            { side = "west",  from = 38, to = 42 },  -- 西侧入口（主城→小径）
            { side = "north", from = 66, to = 69 },  -- 北侧通道（→虎王领地）
            { side = "south", from = 58, to = 63 },  -- 南侧通道（→蜘蛛洞）
            { side = "south", from = 74, to = 77 },  -- 南侧东端（对齐巢穴NE出口）
        },
    },
    erosion = nil,  -- 不侵蚀（草地为主）
}

return narrow_trail
