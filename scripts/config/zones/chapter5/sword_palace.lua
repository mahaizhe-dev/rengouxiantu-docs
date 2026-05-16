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
sword_palace.spawns = {}
sword_palace.decorations = {
    -- 太虚剑宫：中央区残柱与剑痕
    -- 四角残柱（宫殿支撑柱遗迹）
    { type = "ruined_pillar", x = 29, y = 26 },
    { type = "ruined_pillar", x = 51, y = 26 },
    { type = "ruined_pillar", x = 29, y = 39 },
    { type = "ruined_pillar", x = 51, y = 39 },
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
}

return sword_palace
