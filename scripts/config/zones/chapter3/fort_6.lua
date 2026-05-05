-- ============================================================================
-- fort_6.lua - 第六寨·苍狼寨
-- 坐标: (56,8)→(71,23)  16×16
-- ============================================================================

local fort_6 = {}

fort_6.regions = {
    ch3_fort_6 = { x1 = 56, y1 = 8, x2 = 71, y2 = 23, zone = "ch3_fort_6" },
}

fort_6.npcs = {}

-- 苍狼 ×8 (normal Lv41~43) + 苍狼妖王 ×1 (boss Lv44)
fort_6.spawns = {
    { type = "sand_demon_6", x = 61, y = 12 },
    { type = "sand_demon_6", x = 66, y = 12 },
    { type = "sand_demon_6", x = 60, y = 15 },
    { type = "sand_demon_6", x = 65, y = 15 },
    { type = "sand_demon_6", x = 61, y = 18 },
    { type = "sand_demon_6", x = 66, y = 18 },
    { type = "sand_demon_6", x = 60, y = 20 },
    { type = "sand_demon_6", x = 67, y = 20 },
    { type = "yao_king_6",   x = 63, y = 16 },
}

fort_6.decorations = {
    -- 苍狼寨：军营风格，武器架+旗帜+帐篷
    { type = "campfire",     x = 63, y = 14 },
    { type = "weapon_rack",  x = 59, y = 11 },
    { type = "weapon_rack",  x = 67, y = 11 },
    { type = "weapon_rack",  x = 69, y = 21 },
    { type = "banner",       x = 59, y = 10, color = {100, 120, 160, 255} },
    { type = "banner",       x = 67, y = 10, color = {100, 120, 160, 255} },
    { type = "banner",       x = 59, y = 21, color = {100, 120, 160, 255} },
    { type = "banner",       x = 67, y = 21, color = {100, 120, 160, 255} },
    { type = "barrel",       x = 68, y = 12 },
    { type = "barrel",       x = 58, y = 20 },
    { type = "crack",        x = 62, y = 18 },
}

fort_6.generation = {
    special = "sand_fortress",
    fill = { tile = "SAND_FLOOR" },
    -- 城墙由 BuildCh3SandFortresses() 统一构建，不使用数据驱动边界
}

return fort_6
