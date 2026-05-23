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
    -- 普通怪：剑痕石俑 ×8（左侧及中部散布，为右侧BOSS留出空间）
    { type = "ch5_stele_golem",   x = 62.5, y = 23.5 },
    { type = "ch5_stele_golem",   x = 67.5, y = 24.5 },
    { type = "ch5_stele_golem",   x = 61.5, y = 28.5 },
    { type = "ch5_stele_golem",   x = 66.5, y = 30.5 },
    { type = "ch5_stele_golem",   x = 63.5, y = 34.5 },
    { type = "ch5_stele_golem",   x = 68.5, y = 37.5 },
    { type = "ch5_stele_golem",   x = 62.5, y = 41.5 },
    { type = "ch5_stele_golem",   x = 67.5, y = 42.5 },
    -- 精英怪：守碑幻影 ×4（中部过渡带，通往BOSS的路径上）
    { type = "ch5_stele_phantom", x = 70.5, y = 26.5 },
    { type = "ch5_stele_phantom", x = 71.5, y = 33.5 },
    { type = "ch5_stele_phantom", x = 69.5, y = 38.5 },
    { type = "ch5_stele_phantom", x = 72.5, y = 42.5 },
    -- BOSS：石观澜 ×1（右侧中部）
    { type = "ch5_shi_guanlan",   x = 74.5, y = 33.5 },
    -- 巡逻魔帅·裂魂 ×1（皇级 Lv.120 极谪仙境，碑林外围四角巡逻）
    { type = "ch5_marshal_liesoul", x = 60, y = 22,
      patrolPreset = "large_waypoint_loop",
      patrol = {
          nodes = {
              { x = 60, y = 22 },
              { x = 60, y = 43 },
              { x = 75, y = 43 },
              { x = 75, y = 22 },
          },
      },
    },
}
stele_forest.decorations = {
    -- 悟剑碑林：倒碑散落与卷轴残页
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
