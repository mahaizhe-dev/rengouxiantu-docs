-- ============================================================================
-- beast_south.lua - 烈焰岛（东南角海兽岛，火山主题，BOSS：焚天蜃龙）
-- 坐标: (58,67)→(79,80)  22×14 横向蔓延
-- 来源传送：巽阵
-- ============================================================================

local beast_south = {}

beast_south.regions = {
    ch4_beast_south = { x1 = 58, y1 = 67, x2 = 79, y2 = 80, zone = "ch4_beast_south" },
}

beast_south.npcs = {
    -- 回龟背岛传送（NPC在岛中央偏上）
    { id = "ch4_bs_tp_back", name = "回龟背岛", subtitle = "传送回龟背岛",
      x = 71.5, y = 74.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_beast_south",
      isObject = true, label = "回龟背岛",
      teleportTarget = { x = 39.5, y = 39.5, island = "haven" },
    },
}

beast_south.decorations = {
    { type = "teleport_array", x = 71.5, y = 74.5, color = {255, 60, 60, 255} },
}
beast_south.spawns = {
    -- 焚天蜃龙：烈焰岛中央 (58,67)→(79,80) → 中心约 68.5, 73.5
    { type = "dragon_fire", x = 68.5, y = 73.5, zone = "ch4_beast_south" },
}

beast_south.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return beast_south
