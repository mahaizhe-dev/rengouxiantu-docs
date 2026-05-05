-- ============================================================================
-- fort_4.lua - 第四寨·蛇骨寨
-- 坐标: (6,54)→(25,73)  20×20
-- ============================================================================

local fort_4 = {}

fort_4.regions = {
    ch3_fort_4 = { x1 = 6, y1 = 54, x2 = 25, y2 = 73, zone = "ch3_fort_4" },
}

fort_4.npcs = {}

-- 蛇骨妖 ×10 (normal Lv49~51) + 蛇骨妖王 ×1 (boss Lv52)
fort_4.spawns = {
    { type = "sand_wolf_4", x = 11, y = 58 },
    { type = "sand_wolf_4", x = 19, y = 58 },
    { type = "sand_wolf_4", x = 10, y = 61 },
    { type = "sand_wolf_4", x = 20, y = 61 },
    { type = "sand_wolf_4", x = 11, y = 64 },
    { type = "sand_wolf_4", x = 19, y = 64 },
    { type = "sand_wolf_4", x = 10, y = 67 },
    { type = "sand_wolf_4", x = 20, y = 67 },
    { type = "sand_wolf_4", x = 14, y = 59 },
    { type = "sand_wolf_4", x = 17, y = 69 },
    { type = "yao_king_4",  x = 15, y = 63 },
}

fort_4.decorations = {
    -- 蛇骨寨：骸骨遍地，阴森恐怖（20×20 布局）
    { type = "campfire",     x = 15, y = 62 },
    { type = "bone_pile",    x = 9,  y = 57 },
    { type = "bone_pile",    x = 22, y = 57 },
    { type = "bone_pile",    x = 11, y = 63 },
    { type = "bone_pile",    x = 20, y = 63 },
    { type = "bone_pile",    x = 9,  y = 69 },
    { type = "bone_pile",    x = 22, y = 69 },
    { type = "crack",        x = 13, y = 59 },
    { type = "crack",        x = 19, y = 67 },
    { type = "crack",        x = 8,  y = 65 },
    { type = "crack",        x = 23, y = 60 },
    { type = "stone_tablet", x = 15, y = 68 },
    { type = "weapon_rack",  x = 10, y = 60 },
    { type = "weapon_rack",  x = 21, y = 66 },
}

fort_4.generation = {
    special = "sand_fortress",
    fill = { tile = "SAND_FLOOR" },
    -- 城墙由 BuildCh3SandFortresses() 统一构建，不使用数据驱动边界
}

return fort_4
