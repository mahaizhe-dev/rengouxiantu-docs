-- ============================================================================
-- sword_corridor.lua - 万剑回廊（最深处特殊区）
-- 坐标: 凹字形 底部x=8~72,y=72~76 + 左臂x=4~14,y=68~72 + 右臂x=66~76,y=68~72
-- 空间角色: 凹字形回廊，无障碍物，横向悬空感
-- 主材质: corridor_dark_stone, corridor_sword_metal
-- ============================================================================

local sword_corridor = {}

sword_corridor.regions = {
    ch5_sword_corridor = { x1 = 4, y1 = 69, x2 = 76, y2 = 76, zone = "ch5_sword_corridor" },
}

sword_corridor.npcs = {}
sword_corridor.spawns = {}
sword_corridor.decorations = {
    -- 万剑回廊：残柱与地裂
    { type = "ruined_pillar", x = 12, y = 73 },
    { type = "crack",         x = 40, y = 73 },
    { type = "ruined_pillar", x = 68, y = 73 },
}

sword_corridor.generation = {
    fill = { tile = "CH5_CORRIDOR_DARK" },
    border = {
        tile = "CH5_CLIFF",
        minThick = 1,
        maxThick = 1,

        openSides = { "top" },  -- 上通镇魔深渊
    },
}

return sword_corridor
