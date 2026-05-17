-- ============================================================================
-- wild_outer.lua - 外围荒漠（寨间走廊，⑨⑧⑦→⑥⑤ 过渡带）
-- 北侧横向走廊 (⑨→⑧ x=24~31, ⑧→⑥ x=48~55) + 纵向走廊 (⑨→⑦, ⑧→⑤)
-- x>55 y=24~31 为湖泊阻断区（⑥→③不通）
-- 沙暴妖尉 ×7 (elite Lv41, 金丹初)
-- ============================================================================

local wild_outer = {}

wild_outer.npcs = {
    {
        id = "dao_tree_ch3", name = "万里黄沙·悟道树", subtitle = "每日参悟",
        x = 52, y = 26, icon = "🌳",
        interactType = "dao_tree", isObject = true, zone = "wild_outer",
        label = "悟道树",
        dialog = "荒漠孤树屹立千年不朽，灵根深扎大漠之下汲取天地灵气。静坐树下，可悟大道无形。",
    },
}

-- 沙暴妖尉：覆盖北侧横向走廊 + 纵向走廊，均匀分布
wild_outer.spawns = {
    -- ⑨→⑧ 横向走廊 (y≈14~18, x=24~55)
    { type = "sand_elite_outer", x = 27, y = 15 },
    { type = "sand_elite_outer", x = 38, y = 14 },
    { type = "sand_elite_outer", x = 50, y = 16 },
    -- ⑨→⑦ 纵向走廊 (x≈10~20, y=24~31)
    { type = "sand_elite_outer", x = 14, y = 26 },
    -- 走廊交叉口 (x=24~31, y=24~31)
    { type = "sand_elite_outer", x = 28, y = 28 },
    -- ⑧→⑤ 纵向走廊 (x≈35~45, y=24~31)
    { type = "sand_elite_outer", x = 39, y = 26 },
    { type = "sand_elite_outer", x = 44, y = 27 },
    -- 流沙之子：⑧寨上方边缘水平巡逻（入口路x=14~16以东，不阻隔入口）
    { type = "liusha_son_outer", x = 24, y = 4,
      patrolPreset = "large_waypoint_loop",
      patrol = {
          nodes = {
              { x = 24, y = 4 },    -- 入口路以东起点
              { x = 30, y = 4 },
              { x = 36, y = 4 },
              { x = 42, y = 4 },    -- ⑧上方中段
              { x = 48, y = 4 },
              { x = 54, y = 4 },    -- ⑧⑥间隙上方
              { x = 48, y = 4 },
              { x = 42, y = 4 },
              { x = 36, y = 4 },
              { x = 30, y = 4 },
              { x = 24, y = 4 },    -- 折返回起点
          },
      },
    },
}

wild_outer.decorations = {
    { type = "dao_tree", x = 52, y = 25, w = 2, h = 2, label = "悟道树" },
}

return wild_outer
