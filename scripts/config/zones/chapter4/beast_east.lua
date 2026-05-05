-- ============================================================================
-- beast_east.lua - 幽渊岛（东北角海兽岛，深渊主题，BOSS：堕渊蛟龙）
-- 坐标: (58,1)→(79,13)  22×13 横向蔓延
-- 来源传送：艮阵
-- ============================================================================

local beast_east = {}

beast_east.regions = {
    ch4_beast_east = { x1 = 58, y1 = 1, x2 = 79, y2 = 13, zone = "ch4_beast_east" },
}

beast_east.npcs = {
    -- 回龟背岛传送（NPC在岛中央偏下）
    { id = "ch4_be_tp_back", name = "回龟背岛", subtitle = "传送回龟背岛",
      x = 71.5, y = 12.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_beast_east",
      isObject = true, label = "回龟背岛",
      teleportTarget = { x = 39.5, y = 39.5, island = "haven" },
    },
}

beast_east.decorations = {
    { type = "teleport_array", x = 71.5, y = 12.5, color = {255, 60, 60, 255} },
}
beast_east.spawns = {
    -- 堕渊蛟龙：幽渊岛中央 (58,1)→(79,13) → 中心约 68.5, 7.5
    { type = "dragon_abyss", x = 68.5, y = 7.5, zone = "ch4_beast_east" },
}

beast_east.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return beast_east
