-- ============================================================================
-- library.lua - 藏经书阁（右三路）
-- 坐标: x=56~76, y=46~66
-- 空间角色: 焚毁楼阁与书页散落，底部预留回廊深层出口
-- 主材质: library_burnt_floor
-- ============================================================================

local library = {}

library.regions = {
    ch5_library = { x1 = 59, y1 = 49, x2 = 76, y2 = 63, zone = "ch5_library" },
}

library.npcs = {}
library.spawns = {
    -- 藏经书阁：无普通怪，仅精英+BOSS
    -- 精英怪：禁页书妖 ×4（阁内巡逻）
    { type = "ch5_book_demon",    x = 64.5, y = 53.5 },
    { type = "ch5_book_demon",    x = 72.5, y = 55.5 },
    { type = "ch5_book_demon",    x = 62.5, y = 57.5 },
    { type = "ch5_book_demon",    x = 73.5, y = 59.5 },
    -- BOSS：温素章 ×1（阁楼深处）
    { type = "ch5_wen_suzhang",   x = 67.5, y = 60.5 },
}
library.decorations = {
    -- 藏经书阁：燃书架与散卷
    { type = "burning_shelf",     x = 61, y = 51, w = 1, h = 2 },
    { type = "burning_shelf",     x = 67, y = 50, w = 1, h = 2 },
    { type = "burning_shelf",     x = 74, y = 51, w = 1, h = 2 },
    { type = "burning_shelf",     x = 63, y = 56, w = 1, h = 2 },
    -- 地面裂缝
    { type = "crack",             x = 68, y = 58 },
}

library.generation = {
    fill = { tile = "CH5_LIBRARY_BURNT" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "top", "left", "bottom" },  -- 上通悟剑碑林，左通剑宫，底通回廊
    },
}

return library
