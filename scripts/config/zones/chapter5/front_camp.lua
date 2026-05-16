-- ============================================================================
-- front_camp.lua - 太虚遗址前营（第五章出生点/安全区）
-- 坐标: x=25~55, y=4~12
-- 空间角色: 安全区 / 回营区 / 功能NPC / 前线营棚
-- 主材质: camp_dirt, camp_flagstone
-- ============================================================================

local front_camp = {}

front_camp.regions = {
    ch5_front_camp = { x1 = 27, y1 = 4, x2 = 53, y2 = 9, zone = "ch5_front_camp" },
}

front_camp.spawnPoint = { x = 40.5, y = 6.5 }

-- NPC
front_camp.npcs = {
    {
        id = "ch5_teleport_array", name = "传送法阵", subtitle = "跨章传送",
        x = 40, y = 7, icon = "🌀",
        interactType = "teleport_array", zone = "ch5_front_camp",
        isObject = true, label = "传送法阵",
        dialog = "传送法阵在残垣间闪烁微光，可以将你传送至其他章节。",
    },
    {
        id = "ch5_alchemy", name = "炼丹炉", subtitle = "炼丹",
        x = 35, y = 6, icon = "🔥",
        portrait = "Textures/npc_alchemy_furnace.png",
        interactType = "alchemy", zone = "ch5_front_camp",
        dialog = "古炉内焰色幽蓝，可将灵韵淬炼为渡劫丹。",
    },
}
front_camp.spawns = {}
front_camp.decorations = {
    -- 营地旗帜和武器架（复用已有类型）
    { type = "banner",      x = 30, y = 5 },
    { type = "banner",      x = 50, y = 5 },
    { type = "weapon_rack", x = 38, y = 5 },
    { type = "barrel",      x = 43, y = 5 },
    { type = "campfire",    x = 46, y = 7 },
    -- 传送法阵
    { type = "teleport_array", x = 40, y = 7, color = {100, 150, 255, 255} },
    -- 治愈之泉
    { type = "healing_spring", x = 40, y = 5, color = {80, 200, 170, 255}, label = "治愈之泉" },
}

front_camp.generation = {
    fill = { tile = "CH5_CAMP_DIRT" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "bottom", "left", "right" },  -- 底部通向裂山门，左通问剑坪，右通寒池
    },
}

return front_camp
