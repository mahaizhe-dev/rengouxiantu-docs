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

cold_pool.npcs = {
    -- 悟道树（2×2 占地：61~62, 4~5）
    {
        id = "dao_tree_ch5", name = "洗剑寒池·悟道树", subtitle = "每日参悟",
        x = 61.5, y = 4.5, icon = "🌳",
        interactType = "dao_tree", isObject = true, zone = "ch5_cold_pool",
        label = "悟道树",
        dialog = "寒池岸边古木参天，剑气与寒意在此相融。静坐树下，可悟剑道中藏匿的天地至理。",
    },
}
cold_pool.spawns = {
    -- 普通怪：寒池灵鹤 ×5（均匀散布）
    { type = "ch5_cold_crane",    x = 62.5, y = 7.5  },
    { type = "ch5_cold_crane",    x = 67.5, y = 11.5 },
    { type = "ch5_cold_crane",    x = 61.5, y = 13.5 },
    { type = "ch5_cold_crane",    x = 72.5, y = 12.5 },
    { type = "ch5_cold_crane",    x = 69.5, y = 8.5  },
    -- 精英怪：裂冰玄鼋 ×3（均匀散布）
    { type = "ch5_ice_turtle",    x = 64.5, y = 9.5  },
    { type = "ch5_ice_turtle",    x = 73.5, y = 14.5 },
    { type = "ch5_ice_turtle",    x = 66.5, y = 14.5 },
    -- BOSS：洗剑霜鸾 ×1（右上半区）
    { type = "ch5_frost_luan",    x = 73.5, y = 6.5  },
}
cold_pool.decorations = {
    -- 悟道树（2×2 占地：61~62, 4~5）
    { type = "dao_tree", x = 61, y = 4, w = 2, h = 2, label = "悟道树" },
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
