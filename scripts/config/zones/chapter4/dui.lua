-- ============================================================================
-- dui.lua - 兑·泽沼阵（西方，☱ 阴·阳·阳）
-- 坐标: (7,32)→(22,47)  16×16, C=3 切角
-- ============================================================================

local dui = {}

dui.regions = {
    ch4_dui = { x1 = 7, y1 = 30, x2 = 22, y2 = 47, zone = "ch4_dui" },
}

dui.yaoPattern = { "yin", "yang", "yang" }

dui.npcs = {
    { id = "ch4_dui_tp_back", name = "回龟背岛", subtitle = "传送回中央",
      x = 14.5, y = 30.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_dui",
      isObject = true, label = "回龟背岛",
      -- 落在 haven 兑阵 NPC(34.5,39.5) 旁 +1x
      teleportTarget = { x = 32.5, y = 39.5, island = "haven" },
    },
}

dui.decorations = {
    { type = "teleport_array", x = 14.5, y = 30.5, color = {240, 240, 255, 255} },
}
dui.spawns = {
    -- 上层通道 (row 2-3, y=34~35)：2小怪
    { type = "dui_disciple", x = 10.5, y = 34.5 },
    { type = "dui_disciple", x = 14.5, y = 34.5 },
    -- 中上通道 (row 5-6, y=37~38)：1小怪 + 1精英
    { type = "dui_disciple", x = 10.5, y = 37.5 },
    { type = "dui_elite",    x = 18.5, y = 38.5 },
    -- 中下通道 (row 8-9, y=40~41)：1小怪 + 2精英
    { type = "dui_disciple", x = 10.5, y = 40.5 },
    { type = "dui_elite",    x = 14.5, y = 41.5 },
    { type = "dui_elite",    x = 18.5, y = 41.5 },
    -- 下层通道 (row 11-13, y=43~45)：BOSS
    { type = "dui_boss",     x = 14.5, y = 44.5 },
}

dui.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return dui
