-- ============================================================================
-- xianyuan_rooms_ch2.lua - 仙缘宝箱藏宝室区域数据（贰章）
-- 每个藏宝室为 5×5 独立区域，外圈 1 格阻隔墙，内部 3×3 环境瓦片，
-- 中心放置宝箱，对外开 1 格通路。
-- 堡内房间默认使用 FORTRESS_FLOOR / FORTRESS_WALL（红石风格）
-- 堡外房间（根骨、体魄）使用 CAVE_FLOOR / MOUNTAIN（洞窟风格）
-- 此 zone 必须追加到 ALL_ZONES 末尾，覆盖原有地形。
-- ============================================================================

local xianyuan_rooms_ch2 = {}

-- 瓦片类型（需要在 regions 之前引入，供 per-region 覆盖使用）
local TileTypes = require("config.TileTypes")
local T = TileTypes.TILE

-- 模块级默认瓦片（堡内房间使用）—— 第二章风格
xianyuan_rooms_ch2.floorTile = T.FORTRESS_FLOOR
xianyuan_rooms_ch2.wallTile  = T.FORTRESS_WALL

-- ============================================================================
-- 区域范围：以宝箱坐标为中心，向外扩展 2 格形成 5×5
-- 堡外房间通过 per-region floorTile/wallTile 覆盖默认红石风格
-- ============================================================================
xianyuan_rooms_ch2.regions = {
    -- 根骨 (23,61) → 5×5: (21,59)→(25,63)  ※堡外，使用洞窟瓦片
    xianyuan_room_constitution = { x1 = 21, y1 = 59, x2 = 25, y2 = 63, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 23 },
                                   floorTile = T.CAVE_FLOOR, wallTile = T.MOUNTAIN },
    -- 福源 (46,52) → 5×5: (44,50)→(48,54)  ※堡内，沿用堡墙风格
    xianyuan_room_fortune      = { x1 = 44, y1 = 50, x2 = 48, y2 = 54, zone = "xianyuan_room",
                                   entrance = { side = "north", coord = 46 } },
    -- 悟性 (46,30) → 5×5: (44,28)→(48,32)  ※堡内，沿用堡墙风格
    xianyuan_room_wisdom       = { x1 = 44, y1 = 28, x2 = 48, y2 = 32, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 46 } },
    -- 体魄 (5,5) → 5×5: (3,3)→(7,7)        ※堡外，使用洞窟瓦片
    xianyuan_room_physique     = { x1 = 3, y1 = 3, x2 = 7, y2 = 7, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 5 },
                                   floorTile = T.CAVE_FLOOR, wallTile = T.MOUNTAIN },
}

-- 藏宝室不刷怪、不放障碍、不放采集物
xianyuan_rooms_ch2.spawns = {}
xianyuan_rooms_ch2.decorations = {}

-- ============================================================================
-- 地图生成配置
-- ⚠️ 不使用数据驱动的 fill/border，改由 BuildXianyuanRooms() 在
--    生成管道最末尾手动放置，避免被前序步骤覆盖。
-- ============================================================================
xianyuan_rooms_ch2.generation = {}

return xianyuan_rooms_ch2
