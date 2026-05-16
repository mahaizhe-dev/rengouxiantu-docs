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
    -- 普通怪：同门残魂 ×5（散布试剑场）
    { type = "ch5_sword_ghost",   x = 8.5,  y = 6.5  },
    { type = "ch5_sword_ghost",   x = 15.5, y = 7.5  },
    { type = "ch5_sword_ghost",   x = 9.5,  y = 11.5 },
    { type = "ch5_sword_ghost",   x = 17.5, y = 10.5 },
    { type = "ch5_sword_ghost",   x = 6.5,  y = 9.5  },
    -- 精英怪：论剑残影 ×3（场地中部）
    { type = "ch5_sword_shadow",  x = 13.5, y = 9.5  },
    { type = "ch5_sword_shadow",  x = 11.5, y = 12.5 },
    { type = "ch5_sword_shadow",  x = 18.5, y = 13.5 },
    -- BOSS：裴千岳 ×1（深处）
    { type = "ch5_pei_qianyue",   x = 12.5, y = 14.5 },
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
