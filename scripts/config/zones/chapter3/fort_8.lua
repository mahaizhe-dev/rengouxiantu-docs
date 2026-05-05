-- ============================================================================
-- fort_8.lua - 第八寨·枯木寨
-- 坐标: (32,8)→(47,23)  16×16
-- ============================================================================

local fort_8 = {}

fort_8.regions = {
    ch3_fort_8 = { x1 = 32, y1 = 8, x2 = 47, y2 = 23, zone = "ch3_fort_8" },
}

fort_8.npcs = {}

-- 枯木精 ×8 (normal Lv33~35) + 枯木妖王 ×1 (boss Lv36)
fort_8.spawns = {
    { type = "sand_scorpion_8", x = 36, y = 13 },
    { type = "sand_scorpion_8", x = 42, y = 13 },
    { type = "sand_scorpion_8", x = 44, y = 15 },
    { type = "sand_scorpion_8", x = 36, y = 16 },
    { type = "sand_scorpion_8", x = 43, y = 18 },
    { type = "sand_scorpion_8", x = 35, y = 19 },
    { type = "sand_scorpion_8", x = 41, y = 19 },
    { type = "sand_scorpion_8", x = 38, y = 21 },
    { type = "yao_king_8",      x = 40, y = 16 },
}

fort_8.decorations = {
    -- 枯木寨：干燥储物，桶架成堆
    { type = "campfire",     x = 39, y = 14 },
    { type = "barrel",       x = 35, y = 11 },
    { type = "barrel",       x = 36, y = 11 },
    { type = "barrel",       x = 44, y = 11 },
    { type = "barrel",       x = 45, y = 21 },
    { type = "weapon_rack",  x = 43, y = 12 },
    { type = "weapon_rack",  x = 34, y = 20 },
    { type = "stone_tablet", x = 39, y = 20 },
    { type = "banner",       x = 35, y = 10, color = {140, 110, 50, 255} },
    { type = "banner",       x = 43, y = 10, color = {140, 110, 50, 255} },
    { type = "crack",        x = 38, y = 17 },
}

fort_8.generation = {
    special = "sand_fortress",
    fill = { tile = "SAND_FLOOR" },
    -- 城墙由 BuildCh3SandFortresses() 统一构建，不使用数据驱动边界
}

return fort_8
