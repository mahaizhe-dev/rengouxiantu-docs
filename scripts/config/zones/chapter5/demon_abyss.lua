-- ============================================================================
-- demon_abyss.lua - 镇魔深渊（后场战区）
-- 坐标: x=28~52, y=44~68
-- 空间角色: 上扩占领剑宫腾出区域，中央下沉，断崖优先，妖魔之血来源
-- 主材质: abyss_charred_rock, abyss_flesh_rock, blood_ritual_stone
-- ============================================================================

local demon_abyss = {}

demon_abyss.regions = {
    ch5_demon_abyss = { x1 = 27, y1 = 50, x2 = 53, y2 = 67, zone = "ch5_demon_abyss" },
}

demon_abyss.npcs = {}
demon_abyss.spawns = {
    -- 镇魔深渊：纯BOSS区（无普通怪/精英怪）
    -- 裂渊屠血将 ×5（深渊五方）
    { type = "ch5_blood_general", x = 33.5, y = 54.5 },
    { type = "ch5_blood_general", x = 46.5, y = 55.5 },
    { type = "ch5_blood_general", x = 34.5, y = 61.5 },
    { type = "ch5_blood_general", x = 47.5, y = 60.5 },
    { type = "ch5_blood_general", x = 40.5, y = 58.5 },
}
demon_abyss.decorations = {
    -- 镇魔深渊：地裂与骨堆
    -- 地面裂缝（深渊裂痕）
    { type = "crack",         x = 35, y = 53 },
    { type = "crack",         x = 45, y = 63 },
    -- 骨堆残骸
    { type = "bone_pile",     x = 32, y = 59 },
    { type = "bone_pile",     x = 50, y = 64 },
}

demon_abyss.generation = {
    fill = { tile = "CH5_ABYSS_CHARRED" },
    border = {
        tile = "CH5_CLIFF",
        minThick = 1,
        maxThick = 3,

        openSides = { "top", "left", "right", "bottom" },  -- 上通剑宫，左通别院，右通藏经阁，下通回廊
    },
}

return demon_abyss
