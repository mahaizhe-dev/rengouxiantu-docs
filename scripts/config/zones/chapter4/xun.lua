-- ============================================================================
-- xun.lua - 巽·风旋阵（东南，☴ 阳·阳·阴）
-- 坐标: (50,50)→(65,65)  16×16, C=3 切角
-- 额外传送：烈焰岛
-- ============================================================================

local xun = {}

xun.regions = {
    ch4_xun = { x1 = 48, y1 = 50, x2 = 67, y2 = 65, zone = "ch4_xun" },
}

xun.yaoPattern = { "yang", "yang", "yin" }

xun.npcs = {
    { id = "ch4_xun_tp_back", name = "回龟背岛", subtitle = "传送回中央",
      x = 48.5, y = 57.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_xun",
      isObject = true, label = "回龟背岛",
      -- 落在 haven 巽阵 NPC(44.5,44.5) 旁 -1x
      teleportTarget = { x = 47.5, y = 44.5, island = "haven" },
    },
    -- 传送至烈焰岛（NPC在岛东侧沙滩，回龟背岛沙滩的反方向）
    -- 烈焰岛回巽阵NPC在(71.5,74.5)，落在其旁边 -1x
    { id = "ch4_xun_tp_beast", name = "烈焰海神柱", subtitle = "修复·升级·传送",
      x = 66.5, y = 57.5, icon = "🔱",
      interactType = "sea_pillar", zone = "ch4_xun",
      isObject = true, label = "海神柱",
      pillarId = "lieyan",
    },
}

xun.decorations = {
    { type = "teleport_array", x = 48.5, y = 57.5, color = {240, 240, 255, 255} },
    { type = "teleport_array", x = 66.5, y = 57.5, color = {255, 60, 60, 255} },
}
xun.spawns = {
    -- 上层通道 (row 2-3, y=52~53)：2小怪
    { type = "xun_disciple", x = 53.5, y = 52.5 },
    { type = "xun_disciple", x = 57.5, y = 52.5 },
    -- 中上通道 (row 5-6, y=55~56)：1小怪 + 1精英
    { type = "xun_disciple", x = 53.5, y = 55.5 },
    { type = "xun_elite",    x = 61.5, y = 56.5 },
    -- 中下通道 (row 8-9, y=58~59)：1小怪 + 2精英
    { type = "xun_disciple", x = 53.5, y = 58.5 },
    { type = "xun_elite",    x = 57.5, y = 59.5 },
    { type = "xun_elite",    x = 61.5, y = 59.5 },
    -- 下层通道 (row 11-13, y=61~63)：BOSS
    { type = "xun_boss",     x = 57.5, y = 62.5 },
}

xun.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return xun
