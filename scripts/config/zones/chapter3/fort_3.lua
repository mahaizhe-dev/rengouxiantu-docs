-- ============================================================================
-- fort_3.lua - 第三寨·赤焰寨（王级BOSS）
-- 坐标: (54,30)→(73,49)  20×20
-- ============================================================================

local fort_3 = {}

fort_3.regions = {
    ch3_fort_3 = { x1 = 54, y1 = 30, x2 = 73, y2 = 49, zone = "ch3_fort_3" },
}

fort_3.npcs = {}

-- 赤焰妖 ×10 (normal Lv53~55) + 烈焰狮王 ×1 (king_boss Lv56)
fort_3.spawns = {
    { type = "sand_demon_3", x = 59, y = 35 },
    { type = "sand_demon_3", x = 67, y = 35 },
    { type = "sand_demon_3", x = 58, y = 38 },
    { type = "sand_demon_3", x = 68, y = 38 },
    { type = "sand_demon_3", x = 59, y = 41 },
    { type = "sand_demon_3", x = 67, y = 41 },
    { type = "sand_demon_3", x = 58, y = 44 },
    { type = "sand_demon_3", x = 68, y = 44 },
    { type = "sand_demon_3", x = 62, y = 37 },
    { type = "sand_demon_3", x = 64, y = 43 },
    { type = "yao_king_3",   x = 63, y = 40 },
}

fort_3.decorations = {
    -- 赤焰寨：火焰主题，多篝火，暖色旗帜
    { type = "campfire",     x = 60, y = 36 },
    { type = "campfire",     x = 66, y = 36 },
    { type = "campfire",     x = 60, y = 44 },
    { type = "campfire",     x = 66, y = 44 },
    { type = "banner",       x = 59, y = 34, color = {220, 80, 20, 255} },
    { type = "banner",       x = 67, y = 34, color = {220, 80, 20, 255} },
    { type = "banner",       x = 59, y = 46, color = {200, 60, 10, 255} },
    { type = "banner",       x = 67, y = 46, color = {200, 60, 10, 255} },
    { type = "crack",        x = 62, y = 38 },
    { type = "crack",        x = 66, y = 42 },
}

fort_3.generation = {
    special = "sand_fortress",
    fill = { tile = "SAND_FLOOR" },
    -- 城墙由 BuildCh3SandFortresses() 统一构建，不使用数据驱动边界
}

return fort_3
