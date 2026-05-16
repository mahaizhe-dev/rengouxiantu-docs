-- ============================================================================
-- forge.lua - 铸剑地炉（左二路）
-- 坐标: x=4~18, y=26~42
-- 空间角色: 焦黑炉区，热裂纹
-- 主材质: forge_blackstone, forge_molten_crack
-- ============================================================================

local forge = {}

forge.regions = {
    ch5_forge = { x1 = 4, y1 = 21, x2 = 17, y2 = 34, zone = "ch5_forge" },
}

forge.npcs = {}
forge.spawns = {
    -- 铸剑地炉：无普通怪，仅精英+BOSS
    -- 精英怪：炼炉兵傀 ×4（炉区四方位）
    { type = "ch5_forge_soldier", x = 7.5,  y = 23.5 },
    { type = "ch5_forge_soldier", x = 13.5, y = 24.5 },
    { type = "ch5_forge_soldier", x = 8.5,  y = 28.5 },
    { type = "ch5_forge_soldier", x = 14.5, y = 27.5 },
    -- BOSS：韩百炼 ×1（深处）
    { type = "ch5_han_bailian",   x = 10.5, y = 32.5 },
}
forge.decorations = {
    -- 铸剑地炉：铁砧与熔渠
    { type = "anvil",           x = 6,  y = 25 },
    { type = "anvil",           x = 15, y = 26 },
    { type = "anvil",           x = 10, y = 30 },
    -- 武器架（未完成的锻造品）
    { type = "weapon_rack",     x = 16, y = 33 },
}

forge.generation = {
    fill = { tile = "CH5_FORGE_BLACKSTONE" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "top", "bottom", "right" },  -- 上通问剑坪，下通栖剑别院，右通剑宫
    },
}

return forge
