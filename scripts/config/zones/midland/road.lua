-- ============================================================================
-- road.lua - 势力间通道（连接六大势力的仙府长街）
-- 散布于各势力区域之间的连接道路
-- ============================================================================

local road = {}

-- 道路区域定义：连接各势力间的通道
road.regions = {
    -- 左翼纵向连接：血煞盟(y28~52) ↔ 天机阁(y54~66)
    mz_road_left = { x1 = 3, y1 = 52, x2 = 16, y2 = 54, zone = "mz_road" },
    -- 右翼纵向连接：浩气宗(y28~52) ↔ 瑶池(y54~66)
    mz_road_right = { x1 = 64, y1 = 52, x2 = 77, y2 = 54, zone = "mz_road" },
    -- 左翼 → 青云城横向连接
    mz_road_left_to_center = { x1 = 16, y1 = 54, x2 = 22, y2 = 66, zone = "mz_road" },
    -- 右翼 → 青云城横向连接
    mz_road_right_to_center = { x1 = 58, y1 = 54, x2 = 64, y2 = 66, zone = "mz_road" },
    -- 封魔殿 → 青云城纵向连接
    mz_road_fengmo_to_center = { x1 = 30, y1 = 40, x2 = 50, y2 = 42, zone = "mz_road" },
    -- 血煞盟 → 封魔殿横向连接
    mz_road_xuesha_to_fengmo = { x1 = 19, y1 = 28, x2 = 30, y2 = 40, zone = "mz_road" },
    -- 浩气宗 → 封魔殿横向连接
    mz_road_haoqi_to_fengmo = { x1 = 50, y1 = 28, x2 = 61, y2 = 40, zone = "mz_road" },
    -- 地图边缘填充（南部底部，排除天机阁 x3~16,y54~70 和训练场 x3~16,y72~79）
    mz_road_south_left  = { x1 = 0,  y1 = 70, x2 = 3,  y2 = 79, zone = "mz_road" },
    mz_road_south_mid   = { x1 = 16, y1 = 70, x2 = 64, y2 = 79, zone = "mz_road" },  -- 天机阁右侧 → 瑶池左侧
    mz_road_south_gap   = { x1 = 3,  y1 = 70, x2 = 16, y2 = 72, zone = "mz_road" },  -- 天机阁与训练场之间的间隔路
    -- 地图边缘填充（左侧底部空白）
    mz_road_sw = { x1 = 0, y1 = 28, x2 = 3, y2 = 70, zone = "mz_road" },
    -- 地图边缘填充（右侧底部空白）
    mz_road_se = { x1 = 77, y1 = 28, x2 = 79, y2 = 79, zone = "mz_road" },
    -- 北部区域不覆盖道路：
    -- x=0~1, 78~79 (两侧) 及 x=26~27, 53~54 (战场间隙) 保留 base 层 CELESTIAL_WALL
    -- 由 rift.lua 在 y=24~27 提供裂谷，战场自带 border 封闭其余三面
}

road.npcs = {}
road.spawns = {}

-- 道路装饰物：沿主要通道两侧放置灯笼和行道树
road.decorations = {
    -- 封魔→青云纵向通道 (x30~50, y40~42) 两侧灯笼
    { type = "lantern", x = 35, y = 41 },
    { type = "lantern", x = 45, y = 41 },
    -- 血煞→封魔横向通道 (x19~30, y28~40) 行道树
    { type = "tree", x = 22, y = 32 },
    { type = "tree", x = 26, y = 36 },
    -- 浩气→封魔横向通道 (x50~61, y28~40) 行道树
    { type = "tree", x = 53, y = 32 },
    { type = "tree", x = 57, y = 36 },
    -- 左翼→青云横向通道 (x16~22, y54~66) 灯笼
    { type = "lantern", x = 19, y = 58 },
    { type = "lantern", x = 19, y = 63 },
    -- 右翼→青云横向通道 (x58~64, y54~66) 灯笼
    { type = "lantern", x = 61, y = 58 },
    { type = "lantern", x = 61, y = 63 },
    -- 左翼纵向连接 (x3~16, y52~54)（灯笼已移除）
    -- 右翼纵向连接 (x64~77, y52~54) 灯笼
    { type = "lantern", x = 70, y = 53 },
}

road.generation = {
    fill = { tile = "CELESTIAL_ROAD" },
}

return road
