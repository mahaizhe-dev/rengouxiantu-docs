-- ============================================================================
-- wild_inner.lua - 内域荒漠（黄天寨入口走廊，③→①/②→① 通道）
-- ③→① 纵向 (x≈56~73, y=50~53)，②→① 横向 (x=50~53, y≈56~73)
-- 沙暴妖帅 ×5 (elite Lv63, 元婴中)
-- ============================================================================

local wild_inner = {}

wild_inner.npcs = {}

-- 沙暴妖帅：扼守通往黄天寨的最后通道，最强精英，均匀分布
wild_inner.spawns = {
    -- ③→① 横向通道 (x≈56~73, y=50~53)
    { type = "sand_elite_inner", x = 58, y = 51 },
    { type = "sand_elite_inner", x = 65, y = 52 },
    { type = "sand_elite_inner", x = 72, y = 51 },
    -- ②→① 纵向通道 (x=50~53, y≈56~73)
    { type = "sand_elite_inner", x = 51, y = 60 },
    { type = "sand_elite_inner", x = 52, y = 68 },
    -- 流沙之母(皇级)：矩形环路巡逻（18,75→53,75→53,78→18,78）
    { type = "liusha_mother", x = 18, y = 75,
      patrolPreset = "large_waypoint_loop",
      patrol = {
          nodes = {
              { x = 18, y = 75 },
              { x = 53, y = 75 },
              { x = 53, y = 78 },
              { x = 18, y = 78 },
          },
      },
    },
}

wild_inner.decorations = {}

return wild_inner
