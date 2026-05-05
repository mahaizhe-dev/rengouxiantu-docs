-- ============================================================================
-- fort_7.lua - 第七寨·岩蟾寨
-- 坐标: (8,32)→(23,47)  16×16
-- ============================================================================

local fort_7 = {}

fort_7.regions = {
    ch3_fort_7 = { x1 = 8, y1 = 32, x2 = 23, y2 = 47, zone = "ch3_fort_7" },
}

fort_7.npcs = {}

-- 岩蟾 ×8 (normal Lv37~39) + 岩蟾妖王 ×1 (boss Lv40)
fort_7.spawns = {
    { type = "sand_wolf_7", x = 13, y = 36 },
    { type = "sand_wolf_7", x = 19, y = 35 },
    { type = "sand_wolf_7", x = 12, y = 39 },
    { type = "sand_wolf_7", x = 18, y = 39 },
    { type = "sand_wolf_7", x = 13, y = 42 },
    { type = "sand_wolf_7", x = 19, y = 42 },
    { type = "sand_wolf_7", x = 16, y = 37 },
    { type = "sand_wolf_7", x = 16, y = 44 },
    { type = "yao_king_7",  x = 16, y = 40 },
}

fort_7.decorations = {
    -- 岩蟾寨：岩石密布，裂缝纵横，石碑古朴
    { type = "campfire",     x = 15, y = 38 },
    { type = "stone_tablet", x = 12, y = 35 },
    { type = "stone_tablet", x = 18, y = 44 },
    { type = "crack",        x = 14, y = 36 },
    { type = "crack",        x = 18, y = 43 },
    { type = "crack",        x = 11, y = 40 },
    { type = "crack",        x = 20, y = 38 },
    { type = "banner",       x = 11, y = 34, color = {100, 120, 80, 255} },
    { type = "banner",       x = 19, y = 34, color = {100, 120, 80, 255} },
    { type = "bone_pile",    x = 20, y = 44 },
}

fort_7.generation = {
    special = "sand_fortress",
    fill = { tile = "SAND_FLOOR" },
    -- 城墙由 BuildCh3SandFortresses() 统一构建，不使用数据驱动边界
}

return fort_7
