-- ============================================================================
-- Camera.lua - 2D 相机（跟随、边界限制）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local Utils = require("core.Utils")

local Camera = {}
Camera.__index = Camera

--- 创建相机
---@param mapWidth number 地图宽度（瓦片数）
---@param mapHeight number 地图高度（瓦片数）
---@return table
function Camera.New(mapWidth, mapHeight)
    local self = setmetatable({}, Camera)

    self.x = 0           -- 相机中心位置（瓦片坐标）
    self.y = 0
    self.mapWidth = mapWidth
    self.mapHeight = mapHeight
    self.smoothing = 5.0 -- 跟随平滑度
    self.zoom = GameConfig.CAMERA_ZOOM  -- 缩放因子（<1 拉远，>1 拉近）

    return self
end

--- 获取缩放后的瓦片像素大小（世界渲染用）
---@return number
function Camera:GetTileSize()
    return GameConfig.TILE_SIZE * self.zoom
end

--- 更新相机（跟随目标）
---@param dt number
---@param targetX number
---@param targetY number
---@param viewWidthTiles number 视野宽度（瓦片数）
---@param viewHeightTiles number 视野高度（瓦片数）
function Camera:Update(dt, targetX, targetY, viewWidthTiles, viewHeightTiles)
    -- 平滑跟随
    local t = math.min(1.0, self.smoothing * dt)
    self.x = Utils.Lerp(self.x, targetX, t)
    self.y = Utils.Lerp(self.y, targetY, t)

    -- 边界限制（确保不超出地图）
    local halfW = viewWidthTiles / 2
    local halfH = viewHeightTiles / 2

    local minX = halfW + 1
    local maxX = self.mapWidth - halfW
    local minY = halfH + 1
    local maxY = self.mapHeight - halfH

    -- 地图小于视野时，锁定到地图中心（避免 min > max 震荡）
    if minX > maxX then
        self.x = (self.mapWidth + 1) / 2
    else
        self.x = Utils.Clamp(self.x, minX, maxX)
    end
    if minY > maxY then
        self.y = (self.mapHeight + 1) / 2
    else
        self.y = Utils.Clamp(self.y, minY, maxY)
    end
end

--- 世界坐标转屏幕坐标
---@param worldX number 瓦片坐标
---@param worldY number
---@param screenW number 屏幕宽度（像素）
---@param screenH number 屏幕高度（像素）
---@return number, number 屏幕像素坐标
function Camera:WorldToScreen(worldX, worldY, screenW, screenH)
    local tileSize = self:GetTileSize()
    local sx = (worldX - self.x) * tileSize + screenW / 2
    local sy = (worldY - self.y) * tileSize + screenH / 2
    return sx, sy
end

--- 屏幕坐标转世界坐标
---@param screenX number
---@param screenY number
---@param screenW number
---@param screenH number
---@return number, number 瓦片坐标
function Camera:ScreenToWorld(screenX, screenY, screenW, screenH)
    local tileSize = self:GetTileSize()
    local wx = (screenX - screenW / 2) / tileSize + self.x
    local wy = (screenY - screenH / 2) / tileSize + self.y
    return wx, wy
end

--- 获取可见瓦片范围
---@param screenW number
---@param screenH number
---@return number startX
---@return number startY
---@return number endX
---@return number endY
function Camera:GetVisibleRange(screenW, screenH)
    local tileSize = self:GetTileSize()
    local tilesX = math.ceil(screenW / tileSize) + 2
    local tilesY = math.ceil(screenH / tileSize) + 2

    local startX = math.floor(self.x - tilesX / 2)
    local startY = math.floor(self.y - tilesY / 2)
    local endX = startX + tilesX
    local endY = startY + tilesY

    -- 限制在地图范围内
    startX = math.max(1, startX)
    startY = math.max(1, startY)
    endX = math.min(self.mapWidth, endX)
    endY = math.min(self.mapHeight, endY)

    return startX, startY, endX, endY
end

--- 判断世界坐标是否在可见范围内
---@param worldX number
---@param worldY number
---@param screenW number
---@param screenH number
---@param margin number 额外边距（瓦片数）
---@return boolean
function Camera:IsVisible(worldX, worldY, screenW, screenH, margin)
    margin = margin or 2
    local tileSize = self:GetTileSize()
    local halfW = screenW / (2 * tileSize) + margin
    local halfH = screenH / (2 * tileSize) + margin

    return math.abs(worldX - self.x) <= halfW and math.abs(worldY - self.y) <= halfH
end

return Camera
