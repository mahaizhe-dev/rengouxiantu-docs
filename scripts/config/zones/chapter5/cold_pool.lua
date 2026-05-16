-- ============================================================================
-- cold_pool.lua - 洗剑寒池（右一路）
-- 坐标: x=58~76, y=4~24
-- 空间角色: 缩短下方让给碑林，岸线必须准确，寒池水面
-- 主材质: cold_pool_jade, cold_pool_ice_edge
-- ============================================================================

local cold_pool = {}

cold_pool.regions = {
    ch5_cold_pool = { x1 = 59, y1 = 4, x2 = 76, y2 = 16, zone = "ch5_cold_pool" },
}

cold_pool.npcs = {}
cold_pool.spawns = {
    -- 普通怪：寒池灵鹤 ×5（池岸散布）
    { type = "ch5_cold_crane",    x = 63.5, y = 6.5  },
    { type = "ch5_cold_crane",    x = 71.5, y = 7.5  },
    { type = "ch5_cold_crane",    x = 64.5, y = 11.5 },
    { type = "ch5_cold_crane",    x = 72.5, y = 10.5 },
    { type = "ch5_cold_crane",    x = 67.5, y = 13.5 },
    -- 精英怪：裂冰玄鼋 ×3（池心两侧）
    { type = "ch5_ice_turtle",    x = 65.5, y = 9.5  },
    { type = "ch5_ice_turtle",    x = 70.5, y = 12.5 },
    { type = "ch5_ice_turtle",    x = 62.5, y = 7.5  },
    -- BOSS：洗剑霜鸾 ×1（深处）
    { type = "ch5_frost_luan",    x = 68.5, y = 14.5 },
}
cold_pool.decorations = {
    -- 洗剑寒池：冰棱与寒气
    { type = "ice_shard",     x = 61, y = 6  },
    { type = "ice_shard",     x = 74, y = 7  },
    { type = "ice_shard",     x = 62, y = 13 },
    { type = "ice_shard",     x = 73, y = 12 },
    { type = "ice_shard",     x = 68, y = 5  },
    -- 池岸残柱
    { type = "ruined_pillar", x = 60, y = 5  },
    { type = "ruined_pillar", x = 75, y = 5  },
}

cold_pool.generation = {
    fill = { tile = "CH5_COLD_JADE" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "left", "bottom" },  -- 左通前营/裂山门，下通悟剑碑林
    },
}

return cold_pool
