-- ============================================================================
-- base.lua - 中洲地图底层（全图填充 CELESTIAL_WALL）
-- 必须在 ALL_ZONES 中排第一位，被后续区域覆盖
-- 未被任何区域覆盖的空白自动成为不可通行的仙府城墙
-- ============================================================================

local base = {}

base.regions = {
    mz_base = { x1 = 0, y1 = 0, x2 = 79, y2 = 79, zone = "mz_base" },
}

base.npcs = {}
base.decorations = {}
base.spawns = {}

base.generation = {
    fill = { tile = "CELESTIAL_WALL" },
}

return base
