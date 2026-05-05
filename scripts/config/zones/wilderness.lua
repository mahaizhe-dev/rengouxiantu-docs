-- ============================================================================
-- wilderness.lua - 荒野区域数据（无固定区域，散布在区域间的空白地带）
-- ============================================================================

local wilderness = {}

-- 荒野没有固定区域范围
wilderness.regions = {}

-- 怪物刷新点（青蛙散布在主城外围空地 Lv.1 被动怪）
-- 主城 (33,33)→(48,48)，ClearTownBuffer 清除周围3格(30~51, 30~51)为草地
-- Barriers: 竖向山脊 x=29 在主城西侧，ScatterWildernessRocks 在过渡带
-- 安全范围: 缓冲区内 (30~32, 30~51) 和 (49~51, 30~51)
-- 道路: 南路 ~x=40~41 向南延伸为 TOWN_ROAD(可通行)
-- 注意: ScatterWildernessRocks 过渡带密度较低(10~15%),但散布碎石可能命中
-- 将刷怪点放在确定为草地的缓冲区内
wilderness.spawns = {
    { type = "frog", x = 31, y = 36 },  -- 西侧（缓冲区内）
    { type = "frog", x = 31, y = 43 },  -- 西侧
    { type = "frog", x = 50, y = 37 },  -- 东侧（缓冲区内）
    { type = "frog", x = 50, y = 44 },  -- 东侧
    { type = "frog", x = 38, y = 31 },  -- 北侧（缓冲区内）
    { type = "frog", x = 44, y = 31 },  -- 北侧
    { type = "frog", x = 37, y = 50 },  -- 南侧（缓冲区内）
    { type = "frog", x = 44, y = 50 },  -- 南侧
}

-- 荒野无固定装饰物（由 ScatterWildernessRocks 程序生成）
wilderness.decorations = {}

return wilderness
