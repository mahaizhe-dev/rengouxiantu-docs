-- ============================================================================
-- xianyuan_rooms.lua - 仙缘宝箱藏宝室区域数据（初章）
-- 每个藏宝室为 5×5 独立区域，外圈 1 格阻隔墙，内部 3×3 环境瓦片，
-- 中心放置宝箱，对外开 1 格通路。
-- 此 zone 必须追加到 ALL_ZONES 末尾，覆盖原有地形。
-- ============================================================================

local xianyuan_rooms = {}

-- ============================================================================
-- 区域范围：以宝箱坐标为中心，向外扩展 2 格形成 5×5
-- ============================================================================
xianyuan_rooms.regions = {
    -- 体魄 (31,22) → 5×5: (29,20)→(33,24)
    xianyuan_room_physique     = { x1 = 29, y1 = 20, x2 = 33, y2 = 24, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 31 } },
    -- 福源 (25,51) → 5×5: (23,49)→(27,53)
    xianyuan_room_fortune      = { x1 = 23, y1 = 49, x2 = 27, y2 = 53, zone = "xianyuan_room",
                                   entrance = { side = "east",  coord = 51 } },
    -- 根骨 (47,7)  → 5×5: (45,5)→(49,9)
    xianyuan_room_constitution = { x1 = 45, y1 = 5,  x2 = 49, y2 = 9,  zone = "xianyuan_room",
                                   entrance = { side = "west",  coord = 7  } },
    -- 悟性 (56,28) → 5×5: (54,26)→(58,30)
    xianyuan_room_wisdom       = { x1 = 54, y1 = 26, x2 = 58, y2 = 30, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 56 } },
}

-- 藏宝室瓦片类型（BuildXianyuanRooms 读取）
local TileTypes = require("config.TileTypes")
local T = TileTypes.TILE
xianyuan_rooms.floorTile = T.CAVE_FLOOR
xianyuan_rooms.wallTile  = T.MOUNTAIN

-- 藏宝室不刷怪、不放障碍、不放采集物
xianyuan_rooms.spawns = {}
xianyuan_rooms.decorations = {}

-- ============================================================================
-- 地图生成配置
-- ⚠️ 不使用数据驱动的 fill/border，改由 Chapter1:BuildXianyuanRooms() 在
--    生成管道最末尾手动放置，避免被 BuildZoneBarriers/ScatterWildernessRocks 覆盖。
-- ============================================================================
-- generation 留空，仅保留 regions 供碰撞/区域判定使用
xianyuan_rooms.generation = {}

return xianyuan_rooms
