-- ============================================================================
-- fort_5.lua - 第五寨·赤甲寨（中心寨，四面通）
-- 坐标: (30,30)→(49,49)  20×20
-- ============================================================================

local fort_5 = {}

fort_5.regions = {
    ch3_fort_5 = { x1 = 30, y1 = 30, x2 = 49, y2 = 49, zone = "ch3_fort_5" },
}

fort_5.npcs = {}

-- 赤甲蝎 ×10 (normal Lv45~47) + 赤甲妖王 ×1 (boss Lv48)
fort_5.spawns = {
    { type = "sand_scorpion_5", x = 35, y = 35 },
    { type = "sand_scorpion_5", x = 43, y = 35 },
    { type = "sand_scorpion_5", x = 36, y = 38 },
    { type = "sand_scorpion_5", x = 43, y = 38 },
    { type = "sand_scorpion_5", x = 35, y = 42 },
    { type = "sand_scorpion_5", x = 43, y = 42 },
    { type = "sand_scorpion_5", x = 37, y = 45 },
    { type = "sand_scorpion_5", x = 41, y = 45 },
    { type = "sand_scorpion_5", x = 45, y = 36 },
    { type = "sand_scorpion_5", x = 34, y = 44 },
    { type = "yao_king_5",      x = 39, y = 40 },
}

fort_5.decorations = {
    -- 赤甲寨：中心竞技场，对称武备
    { type = "campfire",     x = 39, y = 38 },
    { type = "stone_tablet", x = 39, y = 39 },
    { type = "weapon_rack",  x = 34, y = 34 },
    { type = "weapon_rack",  x = 44, y = 34 },
    { type = "weapon_rack",  x = 34, y = 45 },
    { type = "weapon_rack",  x = 44, y = 45 },
    { type = "banner",       x = 34, y = 33, color = {200, 80, 40, 255} },
    { type = "banner",       x = 44, y = 33, color = {200, 80, 40, 255} },
    { type = "banner",       x = 34, y = 46, color = {200, 80, 40, 255} },
    { type = "banner",       x = 44, y = 46, color = {200, 80, 40, 255} },
    { type = "crack",        x = 37, y = 35 },
    { type = "crack",        x = 42, y = 43 },
}

fort_5.generation = {
    special = "sand_fortress",
    fill = { tile = "SAND_FLOOR" },
    -- 城墙由 BuildCh3SandFortresses() 统一构建，不使用数据驱动边界
}

return fort_5
