-- ============================================================================
-- GameMap.lua - 瓦片地图管理
-- ============================================================================

local GameConfig = require("config.GameConfig")
local ActiveZoneData = require("config.ActiveZoneData")

-- 当前活跃的 ZoneData 引用（支持多章节切换）
-- 模块内所有方法通过此变量访问区域数据，由 GameMap.New() 设置
local activeZoneData = ActiveZoneData.Get()

-- 可变代理：子模块通过此代理访问 activeZoneData，章节切换时自动跟随更新
-- （Lua 闭包按引用捕获 upvalue，__index 始终读取最新的 activeZoneData）
local _zdProxy = setmetatable({}, {
    __index = function(_, k) return activeZoneData[k] end,
})

local GameMap = {}
GameMap.__index = GameMap

-- 加载子模块（将方法注入 GameMap 原型，传入代理而非直接引用）
require("world.mapgen.Primitives")(GameMap, _zdProxy)
require("world.mapgen.Effects")(GameMap, _zdProxy)
require("world.mapgen.Chapter1")(GameMap, _zdProxy)
require("world.mapgen.Chapter2")(GameMap, _zdProxy)
require("world.mapgen.Chapter3")(GameMap, _zdProxy)
require("world.mapgen.Chapter4")(GameMap, _zdProxy)

--- 创建地图
---@param zoneDataOverride table|nil 可选的 ZoneData 模块（用于多章节切换），不传则使用默认 ZoneData
---@param mapWidth number|nil 可选的地图宽度，不传则使用 GameConfig.MAP_WIDTH
---@param mapHeight number|nil 可选的地图高度，不传则使用 GameConfig.MAP_HEIGHT
---@return table
function GameMap.New(zoneDataOverride, mapWidth, mapHeight)
    local self = setmetatable({}, GameMap)

    self.width = mapWidth or GameConfig.MAP_WIDTH
    self.height = mapHeight or GameConfig.MAP_HEIGHT
    self.tiles = {}   -- 2D array [y][x]
    self.zoneData = zoneDataOverride or ActiveZoneData.Get()  -- 保存当前使用的 ZoneData 引用
    activeZoneData = self.zoneData  -- 更新模块级引用，供所有方法使用

    self:Generate()

    print("[GameMap] Generated " .. self.width .. "x" .. self.height .. " map")
    return self
end

--- 生成地图
function GameMap:Generate()
    local T = activeZoneData.TILE
    local R = activeZoneData.Regions

    -- 初始化全部为草地
    for y = 1, self.height do
        self.tiles[y] = {}
        for x = 1, self.width do
            self.tiles[y][x] = T.GRASS
        end
    end

    -- ================================================================
    -- 数据驱动：从 zone 配置填充区域地形
    -- ================================================================
    for _, zoneModule in ipairs(activeZoneData.ALL_ZONES) do
        local gen = zoneModule.generation
        if not gen then goto nextFill end

        if gen.subRegions then
            -- 多子区域（蜘蛛洞、山贼寨、裂谷+桥梁）
            -- 先用 gen.fill 填充所有区域（主区域底色），再用子区域 fill 覆盖
            if gen.fill then
                for _, region in pairs(zoneModule.regions) do
                    self:ApplyRegionFill(region, gen.fill, T)
                end
            end
            for _, sub in ipairs(gen.subRegions) do
                local region = zoneModule.regions[sub.regionKey]
                if region and sub.fill then
                    self:ApplyRegionFill(region, sub.fill, T)
                end
            end
        elseif gen.special == "town" then
            -- 主城特殊处理：填充所有区域，仅对主城区域绘制十字道路
            for regName, reg in pairs(zoneModule.regions) do
                self:FillRegion(reg, T[gen.fill.tile])
                if regName == "town" then
                    local townCx = math.floor((reg.x1 + reg.x2) / 2)
                    local townCy = math.floor((reg.y1 + reg.y2) / 2)
                    for x = reg.x1, reg.x2 do
                        self:SetTile(x, townCy, T.TOWN_ROAD)
                        self:SetTile(x, townCy + 1, T.TOWN_ROAD)
                    end
                    for y = reg.y1, reg.y2 do
                        self:SetTile(townCx, y, T.TOWN_ROAD)
                        self:SetTile(townCx + 1, y, T.TOWN_ROAD)
                    end
                end
            end
            -- 连接道路（主城→附属区域）
            if zoneModule.roads then
                for _, road in ipairs(zoneModule.roads) do
                    local tile = T[road.tile] or T.TOWN_ROAD
                    for ry = road.y1, road.y2 do
                        for rx = road.x1, road.x2 do
                            self:SetTile(rx, ry, tile)
                        end
                    end
                end
            end
        elseif gen.special == "fortress" then
            -- 堡垒特殊处理：填充所有子区域，具体墙壁由 BuildFortressOutline 处理
            for _, region in pairs(zoneModule.regions) do
                self:FillRegion(region, T[gen.fill.tile])
            end
        elseif gen.fill then
            -- 单区域：遍历所有 region 应用填充
            for _, region in pairs(zoneModule.regions) do
                self:ApplyRegionFill(region, gen.fill, T)
            end
        end
        ::nextFill::
    end

    -- ================================================================
    -- 边缘侵蚀（打破矩形轮廓，在厚边界之前执行）
    -- ================================================================
    self:ErodeZoneEdges()

    -- ================================================================
    -- 数据驱动：从 zone 配置构建厚实边界（hash 确定性）
    -- ================================================================
    for _, zoneModule in ipairs(activeZoneData.ALL_ZONES) do
        local gen = zoneModule.generation
        if not gen then goto nextBorder end

        if gen.subRegions then
            for _, sub in ipairs(gen.subRegions) do
                if sub.border then
                    local region = zoneModule.regions[sub.regionKey]
                    if region then
                        self:BuildThickBorder(
                            region,
                            T[sub.border.tile],
                            sub.border.minThick,
                            sub.border.maxThick,
                            sub.border.gaps,
                            sub.border.openSides
                        )
                    end
                end
            end
        elseif gen.border then
            for _, region in pairs(zoneModule.regions) do
                self:BuildThickBorder(
                    region,
                    T[gen.border.tile],
                    gen.border.minThick,
                    gen.border.maxThick,
                    gen.border.gaps,
                    gen.border.openSides
                )
            end
        end
        ::nextBorder::
    end

    -- 地图边界用水/山
    for x = 1, self.width do
        self:SetTile(x, 1, T.WATER)
        self:SetTile(x, self.height, T.WATER)
    end
    for y = 1, self.height do
        self:SetTile(1, y, T.WATER)
        self:SetTile(self.width, y, T.WATER)
    end

    -- 主城围墙（四周加墙，出入口留空）
    -- 动态查找 special=="town" 的区域（只取名为 "town" 的主城 region）
    local townRegionForWalls = nil
    for _, zm in ipairs(activeZoneData.ALL_ZONES) do
        if zm.generation and zm.generation.special == "town" then
            townRegionForWalls = zm.regions["town"] or zm.regions.town
            break
        end
    end
    if townRegionForWalls then
        self:BuildTownWalls(townRegionForWalls)
    end

    -- 放置装饰物（标记占用格为不可通行）
    self:PlaceDecorations()

    -- ================================================================
    -- 堡垒轮廓（第二章）
    -- ================================================================
    self:BuildFortressOutline()

    -- ================================================================
    -- 第二章地形美化（边界扭曲、野外隔离、道路、坍塌城墙、临时路障）
    -- ================================================================
    self:BeautifyCh2Terrain()

    -- ================================================================
    -- 第三章沙漠城寨地形（9寨 + 道路 + 荒漠美化）
    -- ================================================================
    self:BuildCh3SandFortresses()
    self:BuildCh3Roads()
    self:BeautifyCh3Terrain()

    -- ================================================================
    -- 第四章八卦海地形（深海 + 切角岛屿 + 爻纹障碍）
    -- ================================================================
    self:BuildCh4Terrain()

    -- ================================================================
    -- 区域间岩块分隔
    -- ================================================================
    self:BuildZoneBarriers()

    -- ================================================================
    -- 荒野过渡带碎石散布
    -- ================================================================
    self:ScatterWildernessRocks()

    -- ================================================================
    -- 第一章特有：道路连接 + 延伸大路 + 主城缓冲区
    -- （依赖 R.town / R.narrow_trail 等第一章区域，其他章节跳过）
    -- ================================================================
    if R.town and R.narrow_trail and R.boar_forest and R.bandit_camp and R.tiger_domain then
        local townCx = math.floor((R.town.x1 + R.town.x2) / 2)
        local townCy = math.floor((R.town.y1 + R.town.y2) / 2)

        -- 道路连接
        self:DrawRoad(R.town.x2, townCy, R.narrow_trail.x1, 40, T.GRASS)
        self:DrawRoad(townCx, R.town.y2, 40, R.boar_forest.y1, T.GRASS)
        self:DrawRoad(R.town.x1, townCy, R.bandit_camp.x2, 25, T.GRASS)
        self:DrawRoad(68, R.narrow_trail.y1, 68, R.tiger_domain.y2, T.GRASS)

        -- 从村子延伸到地图边界的两条大路
        local sx = townCx
        for y = R.town.y2 + 1, self.height - 1 do
            local hash = ((y * 374761393 + 12345) & 0x7FFFFFFF) % 7
            if hash == 0 and sx < townCx + 2 then
                sx = sx + 1
            elseif hash == 1 and sx > townCx - 2 then
                sx = sx - 1
            end
            self:SetTile(sx - 1, y, T.GRASS)
            self:SetTile(sx + 2, y, T.GRASS)
            self:SetTile(sx, y, T.TOWN_ROAD)
            self:SetTile(sx + 1, y, T.TOWN_ROAD)
        end
        local sy = townCy
        for x = R.town.x2 + 1, self.width - 1 do
            local hash = ((x * 668265263 + 67890) & 0x7FFFFFFF) % 7
            if hash == 0 and sy < townCy + 2 then
                sy = sy + 1
            elseif hash == 1 and sy > townCy - 2 then
                sy = sy - 1
            end
            self:SetTile(x, sy - 1, T.GRASS)
            self:SetTile(x, sy + 2, T.GRASS)
            self:SetTile(x, sy, T.TOWN_ROAD)
            self:SetTile(x, sy + 1, T.TOWN_ROAD)
        end
    end

    -- ================================================================
    -- 主城周围保持 3 格草地缓冲区
    -- ================================================================
    self:ClearTownBuffer(3)
end

--- 设置瓦片
---@param x number
---@param y number
---@param tileType number
function GameMap:SetTile(x, y, tileType)
    x = math.floor(x)
    y = math.floor(y)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        self.tiles[y][x] = tileType
    end
end

--- 获取瓦片
--- 注意：渲染系统中瓦片 (N,N) 的视觉中心在世界坐标 (N,N)，范围 [N-0.5, N+0.5)
--- 因此查询时需 +0.5 再 floor，使碰撞格与视觉格对齐
---@param x number 世界坐标（浮点）
---@param y number
---@return number
function GameMap:GetTile(x, y)
    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        return self.tiles[y][x]
    end
    return activeZoneData.TILE.WATER  -- 边界外视为水
end

--- 判断坐标是否可通行
---@param x number 瓦片坐标（浮点）
---@param y number
---@return boolean
function GameMap:IsWalkable(x, y)
    local tileType = self:GetTile(x, y)
    return activeZoneData.WALKABLE[tileType] == true
end

--- 获取坐标所在区域
---@param x number
---@param y number
---@return string
function GameMap:GetZoneAt(x, y)
    for name, region in pairs(activeZoneData.Regions) do
        if x >= region.x1 and x <= region.x2 and y >= region.y1 and y <= region.y2 then
            return region.zone
        end
    end
    return "wilderness"
end

local _tileColorCache = nil
local _tileColorCacheZd = nil
--- 获取瓦片颜色（缓存查找表，按 zoneData 引用失效）
---@param tileType number
---@return table {r,g,b,a}
function GameMap:GetTileColor(tileType)
    -- 缓存命中：zoneData 引用未变
    if _tileColorCache and _tileColorCacheZd == activeZoneData then
        return _tileColorCache[tileType] or _tileColorCache._default
    end
    -- 重建缓存
    local C = GameConfig.COLORS
    local T = activeZoneData.TILE
    local colors = {
        [T.GRASS]        = C.grass,
        [T.TOWN_FLOOR]   = C.town,
        [T.TOWN_ROAD]    = C.town_road,
        [T.CAVE_FLOOR]   = C.cave,
        [T.FOREST_FLOOR] = C.forest,
        [T.MOUNTAIN]     = C.mountain,
        [T.WATER]        = C.water,
        [T.WALL]         = C.wall,
        [T.CAMP_FLOOR]   = C.cave,
        [T.TIGER_GROUND] = C.forest_dark,
    }
    -- 第二章瓦片颜色（仅当 TILE 表中定义了这些类型时生效）
    if T.FORTRESS_WALL then
        colors[T.FORTRESS_WALL]  = C.fortress_wall
        colors[T.FORTRESS_FLOOR] = C.fortress_floor
        colors[T.SWAMP]          = C.swamp
        colors[T.SEALED_GATE]    = C.sealed_gate
        colors[T.CRYSTAL_STONE]  = C.crystal_stone
        colors[T.CAMP_DIRT]      = C.camp_dirt
        colors[T.BATTLEFIELD]    = C.battlefield
    end
    -- 第三章瓦片颜色
    if T.SAND_WALL then
        colors[T.SAND_WALL]  = C.sand_wall
        colors[T.DESERT]     = C.desert
        colors[T.SAND_FLOOR] = C.sand_floor
        colors[T.SAND_ROAD]  = C.sand_road
    end
    -- 第四章瓦片颜色
    if T.DEEP_SEA then
        colors[T.DEEP_SEA]    = C.deep_sea    or {15, 40, 80, 255}
        colors[T.SHALLOW_SEA] = C.shallow_sea or {30, 80, 140, 255}
        colors[T.REEF_FLOOR]  = C.reef_floor  or {140, 160, 130, 255}
        colors[T.CORAL_WALL]  = C.coral_wall  or {100, 70, 90, 255}
        colors[T.ROCK_REEF]   = C.rock_reef   or {80, 75, 70, 255}
        colors[T.SEA_SAND]    = C.sea_sand    or {210, 200, 160, 255}
    end
    colors._default = C.grass
    _tileColorCache = colors
    _tileColorCacheZd = activeZoneData
    return colors[tileType] or C.grass
end

return GameMap
