-- ============================================================================
-- wild_mid.lua - 中域荒漠（寨间走廊，⑦④→③② 过渡带）
-- 西段 ⑦→④ 走廊 (x=8~25, y=48~55) + 交叉口 (x=24~31)
-- x=30~49 为湖泊阻断区（⑤→②不通）
-- 沙暴妖将 ×6 (elite Lv56, 元婴初)
-- ============================================================================

local wild_mid = {}

wild_mid.npcs = {}

-- 沙暴妖将：散布在中域走廊，⑦南侧→⑤西侧→④北侧，均匀分布
wild_mid.spawns = {
    -- ⑦ 南侧走廊 (y=48~49, x=8~24)
    { type = "sand_elite_mid", x = 10, y = 48 },
    { type = "sand_elite_mid", x = 18, y = 49 },
    -- ⑦↔⑤ 走廊间纵向 (x=24~29, y=32~47)
    { type = "sand_elite_mid", x = 26, y = 36 },
    { type = "sand_elite_mid", x = 27, y = 44 },
    -- ⑤ 西侧→④ 北侧过渡 (x=24~29, y=50~57)
    { type = "sand_elite_mid", x = 26, y = 52 },
    { type = "sand_elite_mid", x = 27, y = 57 },
    -- 流沙之子：矩形环路巡逻（77,53→77,35→75,35→75,53）
    { type = "liusha_son_mid", x = 77, y = 53,
      patrolPreset = "large_waypoint_loop",
      patrol = {
          nodes = {
              { x = 77, y = 53 },
              { x = 77, y = 35 },
              { x = 75, y = 35 },
              { x = 75, y = 53 },
          },
      },
    },
}

wild_mid.decorations = {}

return wild_mid
