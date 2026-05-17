-- ============================================================================
-- sword_plaza.lua - 问剑坪（左一路）
-- 坐标: x=4~22, y=4~24
-- 空间角色: 开阔试剑场，裂纹密集
-- 主材质: ruin_bluestone, ruin_cracked_stone
-- ============================================================================

local sword_plaza = {}

sword_plaza.regions = {
    ch5_sword_plaza = { x1 = 4, y1 = 4, x2 = 21, y2 = 16, zone = "ch5_sword_plaza" },
}

sword_plaza.npcs = {}
sword_plaza.spawns = {
    -- 普通怪：同门残魂 ×5（均匀散布）
    { type = "ch5_sword_ghost",   x = 16.5, y = 6.5  },
    { type = "ch5_sword_ghost",   x = 7.5,  y = 11.5 },
    { type = "ch5_sword_ghost",   x = 18.5, y = 11.5 },
    { type = "ch5_sword_ghost",   x = 13.5, y = 13.5 },
    { type = "ch5_sword_ghost",   x = 10.5, y = 8.5  },
    -- 精英怪：论剑残影 ×3（均匀散布）
    { type = "ch5_sword_shadow",  x = 15.5, y = 9.5  },
    { type = "ch5_sword_shadow",  x = 8.5,  y = 14.5 },
    { type = "ch5_sword_shadow",  x = 18.5, y = 14.5 },
    -- BOSS：裴千岳 ×1（左上半区）
    { type = "ch5_pei_qianyue",   x = 7.5,  y = 6.5  },
}
sword_plaza.decorations = {
    -- 问剑坪：断裂石柱与碑残
    { type = "ruined_pillar", x = 5,  y = 5  },
    { type = "ruined_pillar", x = 20, y = 5  },
    { type = "ruined_pillar", x = 20, y = 14 },
    -- 碎裂石碑（场中央记功碑残骸）
    { type = "stone_tablet",  x = 12, y = 8  },
}

sword_plaza.generation = {
    fill = { tile = "CH5_RUIN_BLUESTONE" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "right", "bottom" },  -- 右通前营/裂山门，下通铸剑地炉
    },
}

return sword_plaza
