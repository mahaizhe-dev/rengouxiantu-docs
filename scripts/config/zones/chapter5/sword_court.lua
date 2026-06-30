-- ============================================================================
-- sword_court.lua - 栖剑别院（左三路）
-- 坐标: x=4~24, y=44~66
-- 空间角色: 回廊、院墙、灵泉遗迹，底部预留回廊深层出口
-- 主材质: courtyard_moss_stone
-- ============================================================================

local sword_court = {}

sword_court.regions = {
    ch5_sword_court = { x1 = 4, y1 = 39, x2 = 21, y2 = 63, zone = "ch5_sword_court" },
}

sword_court.npcs = {}
sword_court.spawns = {
    -- 普通怪：别院怨魂 ×6（均匀散布）
    { type = "ch5_court_wraith", x = 7.5,  y = 42.5 },
    { type = "ch5_court_wraith", x = 17.5, y = 43.5 },
    { type = "ch5_court_wraith", x = 9.5,  y = 48.5 },
    { type = "ch5_court_wraith", x = 18.5, y = 50.5 },
    { type = "ch5_court_wraith", x = 6.5,  y = 55.5 },
    { type = "ch5_court_wraith", x = 15.5, y = 58.5 },
    -- 精英怪：夜巡剑侍 ×4（均匀散布）
    { type = "ch5_night_guard",  x = 13.5, y = 44.5 },
    { type = "ch5_night_guard",  x = 8.5,  y = 52.5 },
    { type = "ch5_night_guard",  x = 17.5, y = 53.5 },
    { type = "ch5_night_guard",  x = 11.5, y = 60.5 },
    -- BOSS：宁栖梧 ×1（略微上移）
    { type = "ch5_ning_qiwu",    x = 12.5, y = 56.5 },
    -- 巡逻魔帅·蚀骨 ×1（皇级 Lv.120 谪仙1阶，别院外围四角巡逻）
    { type = "ch5_marshal_shugu", x = 5, y = 41,
      patrolPreset = "large_waypoint_loop",
      patrol = {
          nodes = {
              { x = 5,  y = 41 },
              { x = 5,  y = 62 },
              { x = 19, y = 62 },
              { x = 19, y = 41 },
          },
      },
    },
}
sword_court.decorations = {
    -- 栖剑别院：回廊残柱与苔痕剑迹
    { type = "ruined_pillar", x = 6,  y = 41 },
    { type = "ruined_pillar", x = 19, y = 41 },
    { type = "ruined_pillar", x = 6,  y = 52 },
    { type = "ruined_pillar", x = 19, y = 53 },
    { type = "ruined_pillar", x = 6,  y = 60 },
    { type = "ruined_pillar", x = 19, y = 62 },
    -- （灵泉已移至前营安全区）
    -- 苔痕花丛（院落氛围）
    { type = "bush",          x = 10, y = 40 },
}

sword_court.generation = {
    fill = { tile = "CH5_COURTYARD_MOSS" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "top", "right", "bottom" },  -- 上通铸剑地炉，右通剑宫，底通回廊
    },
    -- 生成后强制清除指定格为区域地面（移除多余墙壁）
    clearTiles = {
        { x = 12, y = 39 },
    },
}

return sword_court
