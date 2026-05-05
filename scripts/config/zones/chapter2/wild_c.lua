-- ============================================================================
-- wild_c.lua - C区·毒蛇沼（南部过渡区）
-- 坐标: (2,54)→(30,79)  28×25  （比北部稍大，打破对称）
-- ============================================================================

local wild_c = {}

wild_c.regions = {
    wild_c = { x1 = 2, y1 = 54, x2 = 30, y2 = 79, zone = "wild_c" },
}

wild_c.npcs = {}

-- 怪物刷新点
-- 区域 (2,54)→(30,79)  28×25
-- scatterRocks: 顶边(接camp/skull)和右边(接堡墙)交界处 18% 密度，边界宽 5 格
-- 装饰阻挡: dead_tree(6,58)(22,62)(15,75), pond(10,65)(25,71), mushroom(4,70)(18,57)(28,76)
--           bone_pile(13,60)(20,68)
-- 安全刷怪区: x=4~24, y=60~77（避开顶边5格碎石带 y<59，右边5格碎石带 x>25）
wild_c.spawns = {
    -- 毒蛇 Lv.21~25（普通怪，密布沼泽各处）
    { type = "poison_snake", x = 5,  y = 61 },
    { type = "poison_snake", x = 14, y = 62 },
    { type = "poison_snake", x = 24, y = 60 },
    { type = "poison_snake", x = 8,  y = 66 },
    { type = "poison_snake", x = 17, y = 64 },
    { type = "poison_snake", x = 23, y = 66 },
    { type = "poison_snake", x = 6,  y = 71 },
    { type = "poison_snake", x = 16, y = 70 },
    { type = "poison_snake", x = 22, y = 73 },
    { type = "poison_snake", x = 9,  y = 76 },
    { type = "poison_snake", x = 19, y = 77 },
    { type = "poison_snake", x = 12, y = 68 },
    -- 蛇王 Lv.26 BOSS（沼泽深处）
    { type = "snake_king",   x = 14, y = 72 },
}

-- 沼泽氛围装饰
wild_c.decorations = {
    { type = "dead_tree",  x = 6,  y = 58 },
    { type = "dead_tree",  x = 22, y = 62 },
    { type = "dead_tree",  x = 15, y = 75 },
    { type = "pond",       x = 10, y = 65 },
    { type = "pond",       x = 25, y = 71 },
    { type = "mushroom",   x = 4,  y = 70, color = {120, 160, 80, 255} },
    { type = "mushroom",   x = 18, y = 57, color = {100, 140, 70, 255} },
    { type = "mushroom",   x = 28, y = 76, color = {110, 150, 75, 255} },
    { type = "bone_pile",  x = 13, y = 60 },
    { type = "bone_pile",  x = 20, y = 68 },
}

-- 沼泽基底
wild_c.generation = {
    fill = { tile = "SWAMP" },
}

return wild_c
