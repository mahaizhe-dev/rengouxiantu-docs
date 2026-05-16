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
    -- 普通怪：别院怨魂 ×6（回廊散布，区域较大）
    { type = "ch5_court_wraith", x = 8.5,  y = 42.5 },
    { type = "ch5_court_wraith", x = 17.5, y = 43.5 },
    { type = "ch5_court_wraith", x = 9.5,  y = 48.5 },
    { type = "ch5_court_wraith", x = 16.5, y = 50.5 },
    { type = "ch5_court_wraith", x = 12.5, y = 54.5 },
    { type = "ch5_court_wraith", x = 6.5,  y = 46.5 },
    -- 精英怪：夜巡剑侍 ×4（院中后部）
    { type = "ch5_night_guard",  x = 14.5, y = 47.5 },
    { type = "ch5_night_guard",  x = 10.5, y = 55.5 },
    { type = "ch5_night_guard",  x = 15.5, y = 57.5 },
    { type = "ch5_night_guard",  x = 18.5, y = 52.5 },
    -- BOSS：宁栖梧 ×1（最深处）
    { type = "ch5_ning_qiwu",    x = 12.5, y = 61.5 },
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
}

return sword_court
