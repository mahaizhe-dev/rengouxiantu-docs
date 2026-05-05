-- ============================================================================
-- kun.lua - 坤·厚土阵（西南，☷ 阴·阴·阴）
-- 坐标: (14,50)→(29,65)  16×16, C=3 切角
-- 额外传送：流沙岛
-- ============================================================================

local kun = {}

kun.regions = {
    ch4_kun = { x1 = 14, y1 = 48, x2 = 29, y2 = 67, zone = "ch4_kun" },
}

kun.yaoPattern = { "yin", "yin", "yin" }

kun.npcs = {
    { id = "ch4_kun_tp_back", name = "回龟背岛", subtitle = "传送回中央",
      x = 21.5, y = 48.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_kun",
      isObject = true, label = "回龟背岛",
      -- 落在 haven 坤阵 NPC(34.5,44.5) 旁 +1x
      teleportTarget = { x = 31.5, y = 44.5, island = "haven" },
    },
    -- 传送至流沙岛（NPC在岛南侧沙滩，回龟背岛沙滩的反方向）
    -- 流沙岛回坤阵NPC在(8.5,74.5)，落在其旁边 -1y
    { id = "ch4_kun_tp_beast", name = "流沙海神柱", subtitle = "修复·升级·传送",
      x = 21.5, y = 66.5, icon = "🔱",
      interactType = "sea_pillar", zone = "ch4_kun",
      isObject = true, label = "海神柱",
      pillarId = "liusha",
    },
}

kun.decorations = {
    { type = "teleport_array", x = 21.5, y = 48.5, color = {240, 240, 255, 255} },
    { type = "teleport_array", x = 21.5, y = 66.5, color = {255, 60, 60, 255} },
}
kun.spawns = {
    -- 上层通道 (row 2-3, y=52~53)：2小怪
    { type = "kun_disciple", x = 17.5, y = 52.5 },
    { type = "kun_disciple", x = 21.5, y = 52.5 },
    -- 中上通道 (row 5-6, y=55~56)：1小怪 + 1精英
    { type = "kun_disciple", x = 17.5, y = 55.5 },
    { type = "kun_elite",    x = 25.5, y = 56.5 },
    -- 中下通道 (row 8-9, y=58~59)：1小怪 + 2精英
    { type = "kun_disciple", x = 17.5, y = 58.5 },
    { type = "kun_elite",    x = 21.5, y = 59.5 },
    { type = "kun_elite",    x = 25.5, y = 59.5 },
    -- 下层通道 (row 11-13, y=61~63)：BOSS
    { type = "kun_boss",     x = 21.5, y = 62.5 },
}

kun.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return kun
