-- ============================================================================
-- battle_jie.lua - 仙劫战场（北部左侧，合体期解封）
-- 坐标范围: (2,2)→(26,23)  25×22
-- 接壤势力: 血煞盟（左桥）
-- ============================================================================

local battle_jie = {}

battle_jie.regions = {
    mz_battle_jie    = { x1 = 2, y1 = 2, x2 = 26, y2 = 23, zone = "mz_battle_jie" },

    -- ── 裂地斑块（可通行，打破焦土单调感） ──
    decor_crack_nw   = { x1 = 2,  y1 = 2,  x2 = 7,  y2 = 6,  zone = "mz_battle_jie" },
    decor_crack_ne   = { x1 = 19, y1 = 2,  x2 = 26, y2 = 6,  zone = "mz_battle_jie" },
    decor_crack_ctr  = { x1 = 10, y1 = 9,  x2 = 16, y2 = 15, zone = "mz_battle_jie" },
    decor_crack_sw   = { x1 = 2,  y1 = 18, x2 = 7,  y2 = 23, zone = "mz_battle_jie" },
    decor_crack_se   = { x1 = 19, y1 = 18, x2 = 26, y2 = 23, zone = "mz_battle_jie" },
}

battle_jie.npcs = {}
battle_jie.decorations = {}
battle_jie.spawns = {
    -- 域外邪魔 ×5（王级BOSS，均匀分布在战场区域）
    { type = "outer_demon_boss", x = 7,  y = 6  },
    { type = "outer_demon_boss", x = 20, y = 6  },
    { type = "outer_demon_boss", x = 14, y = 12 },
    { type = "outer_demon_boss", x = 7,  y = 18 },
    { type = "outer_demon_boss", x = 20, y = 18 },
}

battle_jie.generation = {
    fill = { tile = "CORRUPTED_GROUND" },
    subRegions = {
        -- 全区轻度散布裂地（约 12%，焦土中透出灰褐质感）
        { regionKey = "mz_battle_jie",   fill = { scatter = "CRACKED_EARTH", scatterPercent = 12 } },
        -- 四隅 + 中心裂地斑块（覆盖散布，形成密集纹理区）
        { regionKey = "decor_crack_nw",  fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_ne",  fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_ctr", fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_sw",  fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_se",  fill = { tile = "CRACKED_EARTH" } },
        -- 裂地区域内再散布焦土（让裂地斑块边缘自然融合）
        { regionKey = "decor_crack_nw",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 30 } },
        { regionKey = "decor_crack_ne",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 30 } },
        { regionKey = "decor_crack_ctr", fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 25 } },
        { regionKey = "decor_crack_sw",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 30 } },
        { regionKey = "decor_crack_se",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 30 } },
    },
}

return battle_jie
