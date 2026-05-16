-- ============================================================================
-- stele_forest.lua - 悟剑碑林（右二路）
-- 坐标: x=58~76, y=26~44
-- 空间角色: 上扩接收寒池空间，碑与地裂节奏，倾倒碑石
-- 主材质: stele_pale_stone, ruin_cracked_stone
-- ============================================================================

local stele_forest = {}

stele_forest.regions = {
    ch5_stele_forest = { x1 = 59, y1 = 21, x2 = 76, y2 = 44, zone = "ch5_stele_forest" },
}

stele_forest.npcs = {}
stele_forest.spawns = {
    -- 普通怪：剑痕石俑 ×8（碑林散布，区域较大）
    { type = "ch5_stele_golem",   x = 63.5, y = 24.5 },
    { type = "ch5_stele_golem",   x = 72.5, y = 25.5 },
    { type = "ch5_stele_golem",   x = 64.5, y = 30.5 },
    { type = "ch5_stele_golem",   x = 71.5, y = 32.5 },
    { type = "ch5_stele_golem",   x = 67.5, y = 36.5 },
    { type = "ch5_stele_golem",   x = 62.5, y = 28.5 },
    { type = "ch5_stele_golem",   x = 73.5, y = 35.5 },
    { type = "ch5_stele_golem",   x = 69.5, y = 27.5 },
    -- 精英怪：守碑幻影 ×4（碑林中后部）
    { type = "ch5_stele_phantom", x = 66.5, y = 33.5 },
    { type = "ch5_stele_phantom", x = 70.5, y = 38.5 },
    { type = "ch5_stele_phantom", x = 64.5, y = 39.5 },
    { type = "ch5_stele_phantom", x = 74.5, y = 41.5 },
    -- BOSS：石观澜 ×1（最深处）
    { type = "ch5_shi_guanlan",   x = 67.5, y = 42.5 },
}
stele_forest.decorations = {
    -- 悟剑碑林：倒碑散落与卷轴残页
    { type = "toppled_stele",     x = 61, y = 23, w = 2, h = 1 },
    { type = "toppled_stele",     x = 70, y = 26, w = 2, h = 1 },
    { type = "toppled_stele",     x = 63, y = 31, w = 2, h = 1 },
    { type = "toppled_stele",     x = 73, y = 37, w = 2, h = 1 },
    { type = "toppled_stele",     x = 65, y = 40, w = 2, h = 1 },
    -- 残柱（碑林入口标记）
    { type = "ruined_pillar",     x = 60, y = 22 },
    -- 地面裂缝（复用已有 crack）
    { type = "crack",             x = 66, y = 29 },
    { type = "crack",             x = 71, y = 43 },
}

stele_forest.generation = {
    fill = { tile = "CH5_STELE_PALE" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "top", "bottom", "left" },  -- 上通洗剑寒池，下通藏经书阁，左通剑宫
    },
}

return stele_forest
