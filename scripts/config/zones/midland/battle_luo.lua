-- ============================================================================
-- battle_luo.lua - 仙陨战场（北部中央，渡劫期可入）
-- 坐标范围: (28,2)→(53,23)
-- 接壤势力: 封魔殿（中桥）
-- 含两侧光幕分隔柱: x=27 和 x=54
-- ============================================================================

local battle_luo = {}

battle_luo.regions = {
    mz_battle_luo    = { x1 = 28, y1 = 2, x2 = 53, y2 = 23, zone = "mz_battle_luo" },
    -- 光幕分隔柱（1格宽，战场之间的能量屏障）
    mz_divider_left  = { x1 = 27, y1 = 2, x2 = 27, y2 = 23, zone = "mz_battle_luo" },
    mz_divider_right = { x1 = 54, y1 = 2, x2 = 54, y2 = 23, zone = "mz_battle_luo" },

    -- ── 裂地斑块（可通行，封魔殿封印感） ──
    decor_crack_tl   = { x1 = 28, y1 = 2,  x2 = 34, y2 = 7,  zone = "mz_battle_luo" },
    decor_crack_tr   = { x1 = 47, y1 = 2,  x2 = 53, y2 = 7,  zone = "mz_battle_luo" },
    decor_crack_ctr  = { x1 = 37, y1 = 9,  x2 = 44, y2 = 16, zone = "mz_battle_luo" },
    decor_crack_bl   = { x1 = 28, y1 = 17, x2 = 34, y2 = 23, zone = "mz_battle_luo" },
    decor_crack_br   = { x1 = 47, y1 = 17, x2 = 53, y2 = 23, zone = "mz_battle_luo" },
}

battle_luo.npcs = {}
battle_luo.decorations = {}
battle_luo.spawns = {}

battle_luo.generation = {
    fill = { tile = "CORRUPTED_GROUND" },
    subRegions = {
        -- 全区散布裂地（约 13%）
        { regionKey = "mz_battle_luo",    fill = { scatter = "CRACKED_EARTH", scatterPercent = 13 } },
        -- 光幕分隔柱
        { regionKey = "mz_divider_left",  fill = { tile = "LIGHT_CURTAIN" } },
        { regionKey = "mz_divider_right", fill = { tile = "LIGHT_CURTAIN" } },
        -- 裂地斑块
        { regionKey = "decor_crack_tl",   fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_tr",   fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_ctr",  fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_bl",   fill = { tile = "CRACKED_EARTH" } },
        { regionKey = "decor_crack_br",   fill = { tile = "CRACKED_EARTH" } },
        -- 裂地区域内回散焦土，自然融合
        { regionKey = "decor_crack_tl",   fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 35 } },
        { regionKey = "decor_crack_tr",   fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 35 } },
        { regionKey = "decor_crack_ctr",  fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 28 } },
        { regionKey = "decor_crack_bl",   fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 35 } },
        { regionKey = "decor_crack_br",   fill = { scatter = "CORRUPTED_GROUND", scatterPercent = 35 } },
    },
}

return battle_luo
