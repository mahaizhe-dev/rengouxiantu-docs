-- ============================================================================
-- fort_2.lua - 第二寨·蜃妖寨（王级BOSS，四面通，南出口通往外界）
-- 坐标: (30,54)→(49,73)  20×20
-- ============================================================================

local fort_2 = {}

fort_2.regions = {
    ch3_fort_2 = { x1 = 30, y1 = 54, x2 = 49, y2 = 73, zone = "ch3_fort_2" },
}

fort_2.npcs = {}

-- 蜃妖 ×10 (normal Lv57~59) + 蜃妖王 ×1 (king_boss Lv60)
fort_2.spawns = {
    { type = "sand_demon_2", x = 35, y = 59 },
    { type = "sand_demon_2", x = 43, y = 59 },
    { type = "sand_demon_2", x = 34, y = 62 },
    { type = "sand_demon_2", x = 44, y = 62 },
    { type = "sand_demon_2", x = 35, y = 65 },
    { type = "sand_demon_2", x = 43, y = 65 },
    { type = "sand_demon_2", x = 34, y = 68 },
    { type = "sand_demon_2", x = 44, y = 68 },
    { type = "sand_demon_2", x = 38, y = 60 },
    { type = "sand_demon_2", x = 40, y = 67 },
    { type = "yao_king_2",   x = 39, y = 64 },
}

fort_2.decorations = {
    -- 蜃妖寨：裂缝密布，地面碎裂，不稳定诡异氛围
    { type = "campfire",     x = 39, y = 62 },
    { type = "banner",       x = 35, y = 58, color = {120, 80, 180, 255} },
    { type = "banner",       x = 43, y = 58, color = {120, 80, 180, 255} },
    { type = "crack",        x = 34, y = 58 },
    { type = "crack",        x = 44, y = 58 },
    { type = "crack",        x = 38, y = 60 },
    { type = "crack",        x = 42, y = 66 },
    { type = "crack",        x = 36, y = 65 },
    { type = "crack",        x = 40, y = 70 },
    { type = "bone_pile",    x = 34, y = 68 },
    { type = "bone_pile",    x = 44, y = 68 },
    { type = "stone_tablet", x = 39, y = 69 },
    { type = "stone_tablet", x = 35, y = 63 },
}

fort_2.generation = {
    special = "sand_fortress",
    fill = { tile = "SAND_FLOOR" },
    -- 城墙由 BuildCh3SandFortresses() 统一构建，不使用数据驱动边界
}

return fort_2
