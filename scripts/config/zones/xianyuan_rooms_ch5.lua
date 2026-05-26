-- ============================================================================
-- xianyuan_rooms_ch5.lua - 仙缘宝箱藏宝室区域数据（伍章）
-- 每个藏宝室为 5x5 独立区域，外圈 1 格阻隔墙，内部 3x3 环境瓦片，
-- 中心放置宝箱，对外开 1 格通路。
-- 此 zone 必须追加到 ALL_ZONES 末尾，覆盖原有地形。
--
-- 坐标选取（来自 XianyuanChestConfig.lua ch5 配置）：
--   福源 fortune      (21,29)  铸剑坊右侧间隙，东侧通路
--   悟性 wisdom       (40,22)  破关与剑宫之间间隙，南侧通路
--   根骨 constitution (58,64)  藏经阁下方间隙，西侧通路
--   体魄 physique     (22,64)  练剑庭院右侧间隙，东侧通路
--
-- 瓦片风格选取：
--   fortune      → 铸剑坊风（CH5_FORGE_BLACKSTONE / CH5_WALL）
--   wisdom       → 废墟青石风（CH5_RUIN_BLUESTONE / CH5_WALL）
--   constitution → 藏经焚毁风（CH5_LIBRARY_BURNT / CH5_WALL）
--   physique     → 苔藓院石风（CH5_COURTYARD_MOSS / CH5_WALL）
-- ============================================================================

local xianyuan_rooms_ch5 = {}

local TileTypes = require("config.TileTypes")
local T = TileTypes.TILE

-- ============================================================================
-- 区域范围：以宝箱坐标为中心，向外扩展 2 格形成 5x5
-- ============================================================================
xianyuan_rooms_ch5.regions = {
    -- 福源 (21,29) 铸剑坊右侧 -> 5x5: (19,27)->(23,31)，南侧入口
    xianyuan_room_fortune      = { x1 = 19, y1 = 27, x2 = 23, y2 = 31, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 21 },
                                   floorTile = T.CH5_FORGE_BLACKSTONE, wallTile = T.CH5_WALL },
    -- 悟性 (40,22) 破关与剑宫间隙 -> 5x5: (38,20)->(42,24)，南侧入口
    xianyuan_room_wisdom       = { x1 = 38, y1 = 20, x2 = 42, y2 = 24, zone = "xianyuan_room",
                                   entrance = { side = "south", coord = 40 },
                                   floorTile = T.CH5_RUIN_BLUESTONE, wallTile = T.CH5_WALL },
    -- 根骨 (58,64) 藏经阁下方 -> 5x5: (56,62)->(60,66)，东侧入口
    xianyuan_room_constitution = { x1 = 56, y1 = 62, x2 = 60, y2 = 66, zone = "xianyuan_room",
                                   entrance = { side = "east", coord = 64 },
                                   floorTile = T.CH5_LIBRARY_BURNT, wallTile = T.CH5_WALL },
    -- 体魄 (22,64) 练剑庭院右侧 -> 5x5: (20,62)->(24,66)，北侧入口
    xianyuan_room_physique     = { x1 = 20, y1 = 62, x2 = 24, y2 = 66, zone = "xianyuan_room",
                                   entrance = { side = "north", coord = 22 },
                                   floorTile = T.CH5_COURTYARD_MOSS, wallTile = T.CH5_WALL },
}

-- ch5 各藏宝室瓦片不同（per-region），模块级 floorTile/wallTile 不设置
-- BuildXianyuanRooms 会优先读取 region 级别的 floorTile/wallTile

-- 藏宝室不刷怪、不放障碍、不放采集物
xianyuan_rooms_ch5.spawns = {}
xianyuan_rooms_ch5.decorations = {}

-- ============================================================================
-- 地图生成配置
-- 不使用数据驱动的 fill/border，改由 BuildXianyuanRooms() 在
-- 生成管道最末尾手动放置，避免被前序步骤覆盖。
-- ============================================================================
xianyuan_rooms_ch5.generation = {}

return xianyuan_rooms_ch5
