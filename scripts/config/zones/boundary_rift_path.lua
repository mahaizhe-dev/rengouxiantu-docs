-- ============================================================================
-- boundary_rift_path.lua - 第一章地图顶部的隐藏界隙残阵
-- ============================================================================

local boundary_rift_path = {}

boundary_rift_path.regions = {
    boundary_rift_path = { x1 = 49, y1 = 2, x2 = 55, y2 = 9, zone = "boundary_rift_path" },
}

boundary_rift_path.spawns = {}

boundary_rift_path.decorations = {
    { type = "stone_tablet", x = 50, y = 3, label = "界匙" },
    { type = "crystal", x = 49, y = 5, color = {160, 70, 230, 255} },
    { type = "crystal", x = 50, y = 8, color = {120, 120, 255, 255} },
    { type = "crystal", x = 51, y = 3, color = {110, 170, 255, 255} },
    { type = "crystal", x = 54, y = 3, color = {190, 90, 240, 255} },
    { type = "crystal", x = 55, y = 6, color = {180, 80, 230, 255} },
    { type = "crystal", x = 54, y = 8, color = {120, 120, 255, 255} },
    { type = "campfire", x = 53, y = 5, color = {120, 60, 180, 255} },
}

boundary_rift_path.npcs = {
    {
        id = "npc_ch1_shixuan_shadow",
        name = "蚀玄残影",
        subtitle = "界匙残阵",
        icon = "👹",
        image = "image/npc_cloaked_cold_youth_2p5_head_20260703044439.png",
        portrait = "image/npc_cloaked_cold_youth_2p5_head_20260703044439.png",
        x = 52.5,
        y = 5.5,
        zone = "boundary_rift_path",
        dialog = "残影立在界隙深处，像是在等一个能破阵的人。",
        interactType = "trigger_battle",
        triggerBattleId = "ch1_boundary_rift_shixuan",
    },
}

boundary_rift_path.generation = {
    fill = { tile = "CAMP_FLOOR" },
}

return boundary_rift_path
