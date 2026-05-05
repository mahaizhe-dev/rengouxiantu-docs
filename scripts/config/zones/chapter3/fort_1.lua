-- ============================================================================
-- fort_1.lua - 第一寨·黄天寨（帝级BOSS 黄天大圣·沙万里）
-- 坐标: (54,54)→(76,76)  23×23
-- ============================================================================

local fort_1 = {}

fort_1.regions = {
    ch3_fort_1 = { x1 = 54, y1 = 54, x2 = 76, y2 = 76, zone = "ch3_fort_1" },
}

fort_1.npcs = {}

-- 黄天大圣·沙万里 ×1 (emperor_boss Lv65) — 帝级BOSS独占大殿
fort_1.spawns = {
    { type = "yao_king_1", x = 65, y = 65 },
    -- 枯木守卫 ×3（站桩型BOSS，守卫大殿入口）
    { type = "kumu_guard", x = 58, y = 60 },
    { type = "kumu_guard", x = 72, y = 60 },
    { type = "kumu_guard", x = 65, y = 73 },
}

fort_1.decorations = {
    -- 帝级BOSS殿堂：对称仪式感，旗帜环绕
    { type = "banner",       x = 59, y = 59, color = {180, 40, 20, 255} },
    { type = "banner",       x = 71, y = 59, color = {180, 40, 20, 255} },
    { type = "banner",       x = 59, y = 71, color = {180, 40, 20, 255} },
    { type = "banner",       x = 71, y = 71, color = {180, 40, 20, 255} },
    { type = "banner",       x = 65, y = 58, color = {200, 180, 50, 255} },
    { type = "banner",       x = 65, y = 72, color = {200, 180, 50, 255} },
    { type = "banner",       x = 58, y = 65, color = {200, 180, 50, 255} },
    { type = "banner",       x = 72, y = 65, color = {200, 180, 50, 255} },
    { type = "campfire",     x = 63, y = 65 },
    { type = "campfire",     x = 67, y = 65 },
    { type = "stone_tablet", x = 65, y = 59 },
    { type = "stone_tablet", x = 65, y = 71 },
}

fort_1.generation = {
    special = "sand_fortress_boss",
    fill = { tile = "SAND_FLOOR" },
    wallThick = 3,  -- 2-3格装饰城墙（外层实墙，内层随机残缺）
}

return fort_1
