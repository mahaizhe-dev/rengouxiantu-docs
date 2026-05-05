-- ============================================================================
-- qian.lua - 乾·天罡阵（西北，☰ 阳·阳·阳）
-- 坐标: (14,14)→(29,29)  16×16, C=3 切角
-- 额外传送：玄冰岛
-- ============================================================================

local qian = {}

qian.regions = {
    ch4_qian = { x1 = 12, y1 = 14, x2 = 31, y2 = 29, zone = "ch4_qian" },
}

qian.yaoPattern = { "yang", "yang", "yang" }

qian.npcs = {
    { id = "ch4_qian_tp_back", name = "回龟背岛", subtitle = "传送回中央",
      x = 30.5, y = 21.5, icon = "🌀",
      interactType = "bagua_teleport", zone = "ch4_qian",
      isObject = true, label = "回龟背岛",
      -- 落在 haven 乾阵 NPC(35.5,35.5) 旁 +1x
      teleportTarget = { x = 31.5, y = 34.5, island = "haven" },
    },
    -- 传送至玄冰岛（NPC在岛西侧沙滩，回龟背岛沙滩的反方向）
    -- 玄冰岛回乾阵NPC在(8.5,12.5)，落在其旁边 -1y
    { id = "ch4_qian_tp_beast", name = "玄冰海神柱", subtitle = "修复·升级·传送",
      x = 12.5, y = 21.5, icon = "🔱",
      interactType = "sea_pillar", zone = "ch4_qian",
      isObject = true, label = "海神柱",
      pillarId = "xuanbing",
    },
}

qian.decorations = {
    { type = "teleport_array", x = 30.5, y = 21.5, color = {240, 240, 255, 255} },
    { type = "teleport_array", x = 12.5, y = 21.5, color = {255, 60, 60, 255} },
}
qian.spawns = {
    -- 兑卦精英增援（散布上中层，阻挡推进）
    { type = "dui_elite",     x = 18.5, y = 16.5 },   -- 上层左
    { type = "dui_elite",     x = 24.5, y = 20.5 },   -- 中上右
    { type = "dui_elite",     x = 18.5, y = 23.5 },   -- 中下左
    -- 四石柱左右对称，护卫 BOSS（下层通道 y=25~27）
    -- 外侧一对（攻击范围不覆盖 BOSS）
    { type = "qian_pillar_w", x = 17.5, y = 25.5 },   -- 左外
    { type = "qian_pillar_e", x = 25.5, y = 25.5 },   -- 右外
    -- 内侧一对（拉开距离，左右两翼）
    { type = "qian_pillar_n", x = 16, y = 21 },   -- 左内
    { type = "qian_pillar_s", x = 27, y = 21 },   -- 右内
    -- 司空正阳（下层中央 row 13, y=27）
    { type = "qian_boss",     x = 21.5, y = 27.5 },
}

qian.generation = {}  -- 地形由 BuildCh4Terrain 统一生成

return qian
