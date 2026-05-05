-- ============================================================================
-- RenderUtils.lua - 渲染共享工具（图片缓存、坐标转换）
-- ============================================================================

local GameConfig = require("config.GameConfig")

local RenderUtils = {}

-- 图片缓存 { [path] = nvgImageHandle }
local imageCache_ = {}

--- 加载或获取缓存的图片
---@param nvg any
---@param path string
---@return integer|nil
function RenderUtils.GetCachedImage(nvg, path)
    if not path then return nil end
    local cached = imageCache_[path]
    if cached ~= nil then
        -- false 表示之前加载失败，不再重试
        return cached ~= false and cached or nil
    end
    local img = nvgCreateImage(nvg, path, NVG_IMAGE_GENERATE_MIPMAPS)
    if img and img > 0 then
        imageCache_[path] = img
        return img
    end
    -- 缓存失败结果，防止每帧重试产生错误洪水
    imageCache_[path] = false
    return nil
end

--- 世界坐标转渲染坐标
---@param worldX number
---@param worldY number
---@param camera table {x, y}
---@param l table {x, y, w, h}
---@return number, number
function RenderUtils.WorldToLocal(worldX, worldY, camera, l)
    local tileSize = camera:GetTileSize()
    local sx = (worldX - camera.x) * tileSize + l.w / 2 + l.x
    local sy = (worldY - camera.y) * tileSize + l.h / 2 + l.y
    return sx, sy
end

return RenderUtils
