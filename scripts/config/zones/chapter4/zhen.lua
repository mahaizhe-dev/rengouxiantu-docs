-- ============================================================================
-- zhen.lua - 震·惊雷阵（东方，☳ 阴·阴·阳）
-- 坐标: (57,32)→(72,47)  16×16, C=3 切角
-- ============================================================================

local zhen = {}

zhen.regions = {
    ch4_zhen = { x1 = 57, y1 = 32, x2 = 72, y2 = 49, zone = "ch4_zhen" },
}

zhen.yaoPattern = { "yin", "yin", "yang" }

zhen.npcs = {
    { id = "ch4_zhen_tp_back", name = "回龟背岛", subtitle = "传送回中央",
      x = 64.5, y = 48.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_zhen",
      isObject = true, label = "回龟背岛",
      -- 落在 haven 震阵 NPC(44.5,39.5) 旁 -1x
      teleportTarget = { x = 46.5, y = 39.5, island = "haven" },
    },
}

zhen.decorations = {
    { type = "teleport_array", x = 64.5, y = 48.5, color = {240, 240, 255, 255} },
}
zhen.spawns = {
    -- 上层通道 (row 2-3, y=34~35)：3小怪
    { type = "zhen_disciple", x = 60.5, y = 34.5 },
    { type = "zhen_disciple", x = 64.5, y = 34.5 },
    { type = "zhen_disciple", x = 68.5, y = 35.5 },
    -- 中上通道 (row 5-6, y=37~38)：3小怪
    { type = "zhen_disciple", x = 60.5, y = 37.5 },
    { type = "zhen_disciple", x = 64.5, y = 38.5 },
    { type = "zhen_disciple", x = 68.5, y = 37.5 },
    -- 中下通道 (row 8-9, y=40~41)：3小怪
    { type = "zhen_disciple", x = 60.5, y = 40.5 },
    { type = "zhen_disciple", x = 64.5, y = 41.5 },
    { type = "zhen_disciple", x = 68.5, y = 40.5 },
    -- 下层通道 (row 11-13, y=43~45)：1小怪 + BOSS
    { type = "zhen_disciple", x = 67.5, y = 43.5 },
    { type = "zhen_boss",     x = 64.5, y = 44.5 },
}

zhen.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return zhen
