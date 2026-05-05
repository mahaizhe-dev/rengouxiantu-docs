-- ============================================================================
-- beast_west.lua - 流沙岛（西南角海兽岛，沙漠主题，BOSS：蚀骨螭龙）
-- 坐标: (1,67)→(22,80)  22×14 横向蔓延
-- 来源传送：坤阵
-- ============================================================================

local beast_west = {}

beast_west.regions = {
    ch4_beast_west = { x1 = 1, y1 = 67, x2 = 22, y2 = 80, zone = "ch4_beast_west" },
}

beast_west.npcs = {
    -- 回龟背岛传送（NPC在岛中央偏上）
    { id = "ch4_bw_tp_back", name = "回龟背岛", subtitle = "传送回龟背岛",
      x = 8.5, y = 74.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_beast_west",
      isObject = true, label = "回龟背岛",
      teleportTarget = { x = 39.5, y = 39.5, island = "haven" },
    },
}

beast_west.decorations = {
    { type = "teleport_array", x = 8.5, y = 74.5, color = {255, 60, 60, 255} },
}
beast_west.spawns = {
    -- 蚀骨螭龙：流沙岛中央 (1,67)→(22,80) → 中心约 11.5, 73.5
    { type = "dragon_sand", x = 11.5, y = 73.5, zone = "ch4_beast_west" },
}

beast_west.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return beast_west
