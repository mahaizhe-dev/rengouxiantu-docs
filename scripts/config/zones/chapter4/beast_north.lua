-- ============================================================================
-- beast_north.lua - 玄冰岛（西北角海兽岛，冰雪主题，BOSS：封霜应龙）
-- 坐标: (1,1)→(22,13)  22×13 横向蔓延
-- 来源传送：乾阵
-- ============================================================================

local beast_north = {}

beast_north.regions = {
    ch4_beast_north = { x1 = 1, y1 = 1, x2 = 22, y2 = 13, zone = "ch4_beast_north" },
}

beast_north.npcs = {
    -- 回龟背岛传送（NPC在岛中央偏下）
    { id = "ch4_bn_tp_back", name = "回龟背岛", subtitle = "传送回龟背岛",
      x = 7.5, y = 11.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_beast_north",
      isObject = true, label = "回龟背岛",
      teleportTarget = { x = 39.5, y = 39.5, island = "haven" },
    },
}

beast_north.decorations = {
    { type = "teleport_array", x = 7.5, y = 11.5, color = {255, 60, 60, 255} },
}
beast_north.spawns = {
    -- 封霜应龙：玄冰岛中央 (22×13 → 中心约 11.5, 6.5)
    { type = "dragon_ice", x = 11.5, y = 6.5, zone = "ch4_beast_north" },
}

beast_north.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return beast_north
