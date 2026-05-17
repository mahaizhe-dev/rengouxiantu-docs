-- ============================================================================
-- sword_palace.lua - 太虚剑宫（中央终局区）
-- 坐标: x=27~53, y=25~42 (上移至距山门3格)
-- 空间角色: 缺角四边形人类建筑，四封剑台 + 中央血池，轴线清晰
-- 主材质: palace_white_stone, palace_corrupted_vein, blood_ritual_stone
-- ============================================================================

local sword_palace = {}

sword_palace.regions = {
    ch5_sword_palace = { x1 = 27, y1 = 24, x2 = 53, y2 = 41, zone = "ch5_sword_palace" },
}

sword_palace.npcs = {}
sword_palace.spawns = {
    -- 四封剑台BOSS：各自刷新在对应BOSS房间中央2×2区域
    -- BOSS房 12×12(墙厚1)，中央2×2白地板 = offset(5,5)~(6,6)
    -- 左上房 origin(24,19) → 中央(29,24)  右上房 origin(45,19) → 中央(50,24)
    -- 左下房 origin(24,35) → 中央(29,40)  右下房 origin(45,35) → 中央(50,40)
    { type = "ch5_sword_zhu",  x = 29, y = 24 },  -- 诛仙剑（左上房）
    { type = "ch5_sword_xian", x = 50, y = 24 },  -- 陷仙剑（右上房）
    { type = "ch5_sword_lu",   x = 29, y = 40 },  -- 戮仙剑（左下房）
    { type = "ch5_sword_jue",  x = 50, y = 40 },  -- 绝仙剑（右下房）
}
sword_palace.decorations = {
    -- 太虚剑宫：中央区残柱与剑痕
    -- 中轴线残柱
    { type = "ruined_pillar", x = 36, y = 28 },
    { type = "ruined_pillar", x = 44, y = 28 },
    { type = "ruined_pillar", x = 36, y = 37 },
    { type = "ruined_pillar", x = 44, y = 37 },
    -- 石碑（宫殿记事碑）
    { type = "stone_tablet",  x = 40, y = 25 },
}

sword_palace.generation = {
    fill = { tile = "CH5_PALACE_WHITE" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "left", "right", "bottom" },  -- 左通地炉，右通碑林，下通深渊
    },
    clearTiles = {
        { x = 26, y = 34 },
        { x = 27, y = 34 },
        { x = 28, y = 34 },
    },
}

return sword_palace
