-- ============================================================================
-- kan.lua - 坎·沉渊阵（北方，☵ 阴·阳·阴）
-- 坐标: (32,7)→(47,22)  16×16, C=3 切角
-- ============================================================================

local kan = {}

kan.regions = {
    ch4_kan = { x1 = 32, y1 = 7, x2 = 49, y2 = 22, zone = "ch4_kan" },
}

-- 爻纹定义：阴·阳·阴（上→下 = 三爻→二爻→初爻）
kan.yaoPattern = { "yin", "yang", "yin" }

kan.npcs = {
    -- 返回中央传送阵（NPC在岛底部）
    { id = "ch4_kan_tp_back", name = "回龟背岛", subtitle = "传送回中央",
      x = 48.5, y = 14.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_kan",
      isObject = true, label = "回龟背岛",
      -- 落在 haven 坎阵 NPC(39.5,34.5) 旁 +1y
      teleportTarget = { x = 39.5, y = 31.5, island = "haven" },
    },
}

kan.decorations = {
    { type = "teleport_array", x = 48.5, y = 14.5, color = {240, 240, 255, 255} },
}
kan.spawns = {
    -- 上层通道 (row 2-3, y=9~10)：3小怪
    { type = "kan_disciple", x = 35.5, y = 9.5 },
    { type = "kan_disciple", x = 39.5, y = 9.5 },
    { type = "kan_disciple", x = 43.5, y = 10.5 },
    -- 中上通道 (row 5-6, y=12~13)：3小怪
    { type = "kan_disciple", x = 35.5, y = 12.5 },
    { type = "kan_disciple", x = 39.5, y = 13.5 },
    { type = "kan_disciple", x = 43.5, y = 12.5 },
    -- 中下通道 (row 8-9, y=15~16)：3小怪
    { type = "kan_disciple", x = 35.5, y = 15.5 },
    { type = "kan_disciple", x = 39.5, y = 16.5 },
    { type = "kan_disciple", x = 43.5, y = 15.5 },
    -- 下层通道 (row 11-13, y=18~20)：1小怪 + BOSS
    { type = "kan_disciple", x = 42.5, y = 18.5 },
    { type = "kan_boss",     x = 39.5, y = 19.5 },
}

kan.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return kan
