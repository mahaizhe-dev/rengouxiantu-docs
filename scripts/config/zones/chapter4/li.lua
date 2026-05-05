-- ============================================================================
-- li.lua - 离·烈焰阵（南方，☲ 阳·阴·阳）
-- 坐标: (32,57)→(47,72)  16×16, C=3 切角
-- ============================================================================

local li = {}

li.regions = {
    ch4_li = { x1 = 30, y1 = 57, x2 = 47, y2 = 72, zone = "ch4_li" },
}

li.yaoPattern = { "yang", "yin", "yang" }

li.npcs = {
    { id = "ch4_li_tp_back", name = "回龟背岛", subtitle = "传送回中央",
      x = 30.5, y = 64.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_li",
      isObject = true, label = "回龟背岛",
      -- 落在 haven 离阵 NPC(39.5,44.5) 旁 -1y
      teleportTarget = { x = 39.5, y = 44.5, island = "haven" },
    },
}

li.decorations = {
    { type = "teleport_array", x = 30.5, y = 64.5, color = {240, 240, 255, 255} },
}
li.spawns = {
    -- 上层通道 (row 2-3, y=59~60)：3小怪
    { type = "li_disciple", x = 35.5, y = 59.5 },
    { type = "li_disciple", x = 39.5, y = 59.5 },
    { type = "li_disciple", x = 43.5, y = 60.5 },
    -- 中上通道 (row 5-6, y=62~63)：3小怪
    { type = "li_disciple", x = 35.5, y = 62.5 },
    { type = "li_disciple", x = 39.5, y = 63.5 },
    { type = "li_disciple", x = 43.5, y = 62.5 },
    -- 中下通道 (row 8-9, y=65~66)：3小怪
    { type = "li_disciple", x = 35.5, y = 65.5 },
    { type = "li_disciple", x = 39.5, y = 66.5 },
    { type = "li_disciple", x = 43.5, y = 65.5 },
    -- 下层通道 (row 11-13, y=68~70)：1小怪 + BOSS
    { type = "li_disciple", x = 42.5, y = 68.5 },
    { type = "li_boss",     x = 39.5, y = 69.5 },
}

li.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return li
