-- ============================================================================
-- wild_b.lua - B区·野猪坡（北部过渡区）
-- 坐标: (2,2)→(30,26)  28×24
-- ============================================================================

local wild_b = {}

wild_b.regions = {
    wild_b = { x1 = 2, y1 = 2, x2 = 30, y2 = 26, zone = "wild_b" },
}

wild_b.npcs = {}

-- 怪物刷新点
-- 区域 (2,2)→(30,26)  28×24
-- scatterRocks: 底边(接camp/skull)和右边(接堡墙)交界处 20% 密度，边界宽 5 格
-- 安全刷怪区: x=4~24, y=4~20（避开底边5格碎石带 y>21，右边5格碎石带 x>25）
-- 道路横贯: roadY≈37~40（不在本区域范围内，无影响）
wild_b.spawns = {
    -- 沼泽毒蛇 Lv.16~20（普通怪，散布全区）
    { type = "swamp_snake", x = 6,  y = 5 },
    { type = "swamp_snake", x = 14, y = 6 },
    { type = "swamp_snake", x = 22, y = 5 },
    { type = "swamp_snake", x = 8,  y = 12 },
    { type = "swamp_snake", x = 18, y = 10 },
    { type = "swamp_snake", x = 24, y = 12 },
    { type = "swamp_snake", x = 5,  y = 18 },
    { type = "swamp_snake", x = 16, y = 16 },
    -- 黑野猪 Lv.16~19（普通怪，中部偏南）
    { type = "black_boar",  x = 10, y = 8 },
    { type = "black_boar",  x = 20, y = 14 },
    { type = "black_boar",  x = 7,  y = 15 },
    { type = "black_boar",  x = 15, y = 19 },
    -- 赤鬃野猪 Lv.19 精英（2只，分布两端）
    { type = "red_boar_elite", x = 8,  y = 10 },
    { type = "red_boar_elite", x = 21, y = 20 },
    -- 猪大哥 Lv.20 BOSS（区域深处）
    { type = "boar_boss_ch2",  x = 14, y = 14 },
}

wild_b.decorations = {}

-- 过渡区，保持草地基底，不特殊填充
wild_b.generation = {
    fill = { tile = "GRASS" },
}

return wild_b
