-- ============================================================================
-- gen.lua - 艮·止岩阵（东北，☶ 阳·阴·阴）
-- 坐标: (50,14)→(65,29)  16×16, C=3 切角
-- 额外传送：幽渊岛
-- ============================================================================

local gen = {}

gen.regions = {
    ch4_gen = { x1 = 50, y1 = 12, x2 = 65, y2 = 31, zone = "ch4_gen" },
}

gen.yaoPattern = { "yang", "yin", "yin" }

gen.npcs = {
    { id = "ch4_gen_tp_back", name = "回龟背岛", subtitle = "传送回中央",
      x = 57.5, y = 30.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_gen",
      isObject = true, label = "回龟背岛",
      -- 落在 haven 艮阵 NPC(44.5,34.5) 旁 +1y
      teleportTarget = { x = 47.5, y = 34.5, island = "haven" },
    },
    -- 传送至幽渊岛（NPC在岛北侧沙滩，回龟背岛沙滩的反方向）
    -- 幽渊岛回艮阵NPC在(71.5,12.5)，落在其旁边 -1y
    { id = "ch4_gen_tp_beast", name = "幽渊海神柱", subtitle = "修复·升级·传送",
      x = 57.5, y = 12.5, icon = "🔱",
      interactType = "sea_pillar", zone = "ch4_gen",
      isObject = true, label = "海神柱",
      pillarId = "youyuan",
    },
}

gen.decorations = {
    { type = "teleport_array", x = 57.5, y = 30.5, color = {240, 240, 255, 255} },
    { type = "teleport_array", x = 57.5, y = 12.5, color = {255, 60, 60, 255} },
}
gen.spawns = {
    -- 上层通道 (row 2-3, y=16~17)：2小怪
    { type = "gen_disciple", x = 53.5, y = 16.5 },
    { type = "gen_disciple", x = 57.5, y = 16.5 },
    -- 中上通道 (row 5-6, y=19~20)：1小怪 + 1精英
    { type = "gen_disciple", x = 53.5, y = 19.5 },
    { type = "gen_elite",    x = 61.5, y = 20.5 },
    -- 中下通道 (row 8-9, y=22~23)：1小怪 + 2精英
    { type = "gen_disciple", x = 53.5, y = 22.5 },
    { type = "gen_elite",    x = 57.5, y = 23.5 },
    { type = "gen_elite",    x = 61.5, y = 23.5 },
    -- 下层通道 (row 11-13, y=25~27)：BOSS
    { type = "gen_boss",     x = 57.5, y = 26.5 },
}

gen.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return gen
