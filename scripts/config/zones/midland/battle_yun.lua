-- ============================================================================
-- battle_yun.lua - 仙殒战场（北部右侧，大乘期可入）
-- 坐标范围: (55,2)→(78,23)
-- 接壤势力: 浩气宗（右桥）
-- ============================================================================

local battle_yun = {}

battle_yun.regions = {
    mz_battle_yun   = { x1 = 55, y1 = 2, x2 = 78, y2 = 23, zone = "mz_battle_yun" },

    -- ── 裂地斑块（可通行，浩气宗战场氛围） ──
    decor_crack_tl  = { x1 = 55, y1 = 2,  x2 = 61, y2 = 8,  zone = "mz_battle_yun" },
    decor_crack_tr  = { x1 = 72, y1 = 2,  x2 = 78, y2 = 8,  zone = "mz_battle_yun" },
    decor_crack_ml  = { x1 = 55, y1 = 10, x2 = 60, y2 = 15, zone = "mz_battle_yun" },
    decor_crack_mr  = { x1 = 73, y1 = 10, x2 = 78, y2 = 15, zone = "mz_battle_yun" },
    decor_crack_ctr = { x1 = 63, y1 = 7,  x2 = 70, y2 = 16, zone = "mz_battle_yun" },
}

battle_yun.npcs = {}
battle_yun.decorations = {}
battle_yun.spawns = {}

battle_yun.generation = {
    fill = { tile = "CORRUPTED_GROUND" },
    subRegions = {
        -- 全区散布裂地（约 14%）
        { regionKey = "mz_battle_yun",   fill = { scatter = "CRACKED_EARTH", scatterPercent = 14 } },
        -- 裂地斑块
        { regionKey = "decor_crack_tl",  fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_tr",  fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_ml",  fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_mr",  fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_ctr", fill = { tile = "CRACKED_EARTH" } },
        -- 裂地区域内回散焦土，边缘自然融合
        { regionKey = "decor_crack_tl",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 32 } },
        { regionKey = "decor_crack_tr",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 32 } },
        { regionKey = "decor_crack_ml",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 32 } },
        { regionKey = "decor_crack_mr",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 32 } },
        { regionKey = "decor_crack_ctr", fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 25 } },
    },
}

return battle_yun
