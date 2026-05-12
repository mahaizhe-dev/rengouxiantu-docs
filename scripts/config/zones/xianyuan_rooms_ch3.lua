-- ============================================================================
-- xianyuan_rooms_ch3.lua - 仙缘宝箱藏宝室区域数据（叁章）
-- 每个藏宝室为 5x5 独立区域，外圈 1 格阻隔墙，内部 3x3 环境瓦片，
-- 中心放置宝箱，对外开 1 格通路。
-- 瓦片使用第三章风格：SAND_FLOOR / SAND_WALL
-- 此 zone 必须追加到 ALL_ZONES 末尾，覆盖原有地形。
-- ============================================================================

local xianyuan_rooms_ch3 = {}

-- ============================================================================
-- 区域范围：以宝箱坐标为中心，向外扩展 2 格形成 5x5
-- ============================================================================
xianyuan_rooms_ch3.regions = {
    -- 根骨 (26,51) -> 5x5: (24,49)->(28,53)
    xianyuan_room_constitution = { x1 = 24, y1 = 49, x2 = 28, y2 = 53, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 26 } },
    -- 福源 (73,73) -> 5x5: (71,71)->(75,75)  入口：西墙 (71,73)
    xianyuan_room_fortune      = { x1 = 71, y1 = 71, x2 = 75, y2 = 75, zone = "xianyuan_room",
                                   entrance = { side = "west", coord = 73 } },
    -- 悟性 (27,31) -> 5x5: (25,29)->(29,33)  入口：西墙 (25,31)
    xianyuan_room_wisdom       = { x1 = 25, y1 = 29, x2 = 29, y2 = 33, zone = "xianyuan_room",
                                   entrance = { side = "west", coord = 31 } },
    -- 体魄 (4,50) -> 5x5: (2,48)->(6,52)   入口：北墙 (4,48)
    xianyuan_room_physique     = { x1 = 2, y1 = 48, x2 = 6, y2 = 52, zone = "xianyuan_room",
                                   entrance = { side = "north", coord = 4 } },
}

-- 藏宝室瓦片类型（BuildXianyuanRooms 读取）—— 第三章风格
local TileTypes = require("config.TileTypes")
local T = TileTypes.TILE
xianyuan_rooms_ch3.floorTile = T.SAND_FLOOR
xianyuan_rooms_ch3.wallTile  = T.SAND_WALL

-- 藏宝室不刷怪、不放障碍、不放采集物
xianyuan_rooms_ch3.spawns = {}
xianyuan_rooms_ch3.decorations = {}

-- ============================================================================
-- 地图生成配置
-- 不使用数据驱动的 fill/border，改由 BuildXianyuanRooms() 在
-- 生成管道最末尾手动放置，避免被前序步骤覆盖。
-- ============================================================================
xianyuan_rooms_ch3.generation = {}

return xianyuan_rooms_ch3
