-- ============================================================================
-- xianyuan_rooms_ch4.lua - 仙缘宝箱藏宝室区域数据（肆章）
-- 每个藏宝室为 5x5 独立区域，外圈 1 格阻隔墙，内部 3x3 环境瓦片，
-- 中心放置宝箱，对外开 1 格通路。
-- 四龙岛各一个，瓦片匹配所在龙岛风格，属性匹配龙酒掉落。
-- 此 zone 必须追加到 ALL_ZONES 末尾，覆盖原有地形。
--
-- 坐标选取原则：远离 boss 主战场，在岛屿角落深处
--   玄冰岛 (1,1)-(22,13)  boss(11.5,6.5)  → 宝箱(3,3)   左上角
--   幽渊岛 (58,1)-(79,13) boss(68.5,7.5)  → 宝箱(77,3)  右上角
--   烈焰岛 (58,67)-(79,80) boss(68.5,73.5) → 宝箱(77,78) 右下角
--   流沙岛 (1,67)-(22,80) boss(11.5,73.5) → 宝箱(3,78)  左下角
--
-- 属性匹配（WineData.lua 龙酒掉落）：
--   玄冰岛(封霜应龙) → constitution(根骨)
--   幽渊岛(堕渊蛟龙) → wisdom(悟性)
--   烈焰岛(焚天蜃龙) → physique(体魄)
--   流沙岛(蚀骨螭龙) → fortune(福缘)
-- ============================================================================

local xianyuan_rooms_ch4 = {}

local TileTypes = require("config.TileTypes")
local T = TileTypes.TILE

-- ============================================================================
-- 区域范围：以宝箱坐标为中心，向外扩展 2 格形成 5x5
-- 每个藏宝室使用所在龙岛的瓦片风格
-- ============================================================================
xianyuan_rooms_ch4.regions = {
    -- 根骨 (3,3) 玄冰岛左上角 -> 5x5: (1,1)->(5,5)
    xianyuan_room_constitution = { x1 = 1, y1 = 1, x2 = 5, y2 = 5, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 3 },
                                   floorTile = T.ICE_FLOOR, wallTile = T.ICE_WALL },
    -- 福源 (3,78) 流沙岛左下角 -> 5x5: (1,76)->(5,80)
    xianyuan_room_fortune      = { x1 = 1, y1 = 76, x2 = 5, y2 = 80, zone = "xianyuan_room",
                                   entrance = { side = "north", coord = 3 },
                                   floorTile = T.DUNE_FLOOR, wallTile = T.DUNE_WALL },
    -- 悟性 (77,3) 幽渊岛右上角 -> 5x5: (75,1)->(79,5)
    xianyuan_room_wisdom       = { x1 = 75, y1 = 1, x2 = 79, y2 = 5, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 77 },
                                   floorTile = T.ABYSS_FLOOR, wallTile = T.ABYSS_WALL },
    -- 体魄 (77,78) 烈焰岛右下角 -> 5x5: (75,76)->(79,80)
    xianyuan_room_physique     = { x1 = 75, y1 = 76, x2 = 79, y2 = 80, zone = "xianyuan_room",
                                   entrance = { side = "north", coord = 77 },
                                   floorTile = T.VOLCANO_FLOOR, wallTile = T.VOLCANO_WALL },
}

-- ch4 各藏宝室瓦片不同（per-region），模块级 floorTile/wallTile 不设置
-- BuildXianyuanRooms 会优先读取 region 级别的 floorTile/wallTile

-- 藏宝室不刷怪、不放障碍、不放采集物
xianyuan_rooms_ch4.spawns = {}
xianyuan_rooms_ch4.decorations = {}

-- ============================================================================
-- 地图生成配置
-- 不使用数据驱动的 fill/border，改由 BuildXianyuanRooms() 在
-- 生成管道最末尾手动放置，避免被前序步骤覆盖。
-- ============================================================================
xianyuan_rooms_ch4.generation = {}

return xianyuan_rooms_ch4
