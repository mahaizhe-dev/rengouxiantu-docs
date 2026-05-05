-- ============================================================================
-- rift.lua - 天裂峡谷（上古大能一剑劈断，横贯东西）
-- 峡谷: y=24~27 全宽，三座桥梁跨越
-- ============================================================================

local rift = {}

rift.regions = {
    -- 峡谷整体（不可通行底色，桥梁区域会被覆盖为可通行）
    mz_rift = { x1 = 0, y1 = 24, x2 = 79, y2 = 27, zone = "mz_rift" },
    -- 三座桥梁（可通行）
    mz_bridge_left   = { x1 = 11, y1 = 24, x2 = 14, y2 = 27, zone = "mz_rift" },
    mz_bridge_center = { x1 = 38, y1 = 24, x2 = 42, y2 = 27, zone = "mz_rift" },
    mz_bridge_right  = { x1 = 65, y1 = 24, x2 = 68, y2 = 27, zone = "mz_rift" },
}

rift.npcs = {}
rift.spawns = {}

-- 峡谷装饰物：三座桥头各放一块石碑
rift.decorations = {
    { type = "stone_tablet", x = 11, y = 24, label = "仙劫战场" },
    { type = "stone_tablet", x = 38, y = 24, label = "仙陨战场" },
    { type = "stone_tablet", x = 65, y = 24, label = "仙殒战场" },
}

rift.generation = {
    fill = { tile = "RIFT_VOID" },
    -- 桥梁子区域用 BRIDGE_FLOOR 覆盖
    subRegions = {
        { regionKey = "mz_bridge_left",   fill = { tile = "BRIDGE_FLOOR" } },
        { regionKey = "mz_bridge_center", fill = { tile = "BRIDGE_FLOOR" } },
        { regionKey = "mz_bridge_right",  fill = { tile = "BRIDGE_FLOOR" } },
    },
}

return rift
