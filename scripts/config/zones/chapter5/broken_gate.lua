-- ============================================================================
-- broken_gate.lua - 裂山门遗址（分流门区）
-- 坐标: x=28~52, y=14~22
-- 空间角色: 中轴封死，左右各留绕行口
-- 主材质: ruin_bluestone, ruin_cracked_stone
-- ============================================================================

local broken_gate = {}

broken_gate.regions = {
    ch5_broken_gate = { x1 = 30, y1 = 14, x2 = 50, y2 = 17, zone = "ch5_broken_gate" },
}

broken_gate.npcs = {
    -- 诛仙阵图（第五章神器交互入口）
    { name = "诛仙阵图", type = "object", interactType = "divine_zhentu", isObject = true, label = "诛仙阵图", x = 40, y = 15.5 },
}
broken_gate.spawns = {
    -- 裂山门守卫 king_boss ×2（左右对称镇守）
    { type = "ch5_stone_guardian", x = 32.5, y = 16.5 },
    { type = "ch5_stone_guardian", x = 48.5, y = 16.5 },
}
broken_gate.decorations = {
    -- 裂山门残柱（左右对称的门框遗迹）
    { type = "ruined_pillar", x = 33, y = 15 },
    { type = "ruined_pillar", x = 47, y = 15 },
    -- 诛仙阵图神器光效（2x2 区域左上角，视觉中心对齐 x=40）
    { type = "divine_zhentu", x = 39, y = 14, label = "诛仙阵图" },
}

broken_gate.generation = {
    fill = { tile = "CH5_RUIN_BLUESTONE" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "top", "left", "right" },  -- 上通前营，左右通两路
    },
}

return broken_gate
