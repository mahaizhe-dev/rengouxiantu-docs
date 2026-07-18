-- tiles/town.lua - 城镇/基础瓦片渲染
---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local shared = require("rendering.tiles.shared")
local M = {}

-- Copy needed shared references locally for performance
local tileHash = shared.tileHash
local tileRand = shared.tileRand
local tileRandInt = shared.tileRandInt
local RenderFlat = shared.RenderFlat

local function EnsureRockImage(nvg)
    if not shared.rockImageLoaded then
        shared.rockImage = nvgCreateImage(nvg, "Textures/rock_natural_tile_20260228022750.png", 0)
        shared.rockImageLoaded = true
    end
end

-- ============================================================================
-- 城镇地板 (TOWN_FLOOR) - 砖石地面
-- ============================================================================
function M.RenderTownFloor(nvg, sx, sy, ts, x, y)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(160, 130, 100, 255))
    nvgFill(nvg)

    local halfW = ts / 2
    local halfH = ts / 2
    local offsetX = (y % 2 == 0) and (halfW * 0.5) or 0

    for bx = 0, 1 do
        for by = 0, 1 do
            local bsx = sx + bx * halfW + offsetX
            local bsy = sy + by * halfH
            local bv = tileRandInt(x, y, bx * 2 + by, -8, 8)

            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bsx + 1, bsy + 1, halfW - 2, halfH - 2, 1.5)
            nvgFillColor(nvg, nvgRGBA(150 + bv, 125 + bv, 95 + bv, 255))
            nvgFill(nvg)

            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bsx + 1, bsy + 1, halfW - 2, halfH - 2, 1.5)
            nvgStrokeColor(nvg, nvgRGBA(120, 100, 75, 100))
            nvgStrokeWidth(nvg, 0.8)
            nvgStroke(nvg)
        end
    end

    if tileRand(x, y, 77) < 0.15 then
        local cx = sx + tileRand(x, y, 78) * ts * 0.6 + ts * 0.2
        local cy = sy + tileRand(x, y, 79) * ts * 0.6 + ts * 0.2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy)
        nvgLineTo(nvg, cx + 4, cy + 5)
        nvgLineTo(nvg, cx + 2, cy + 9)
        nvgStrokeColor(nvg, nvgRGBA(100, 80, 60, 80))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 城镇道路 (TOWN_ROAD) - 鹅卵石路面
-- ============================================================================
function M.RenderTownRoad(nvg, sx, sy, ts, x, y)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(185, 165, 135, 255))
    nvgFill(nvg)

    local stoneCount = tileRandInt(x, y, 0, 6, 8)
    for i = 1, stoneCount do
        local cx = sx + tileRand(x, y, 10 + i) * (ts - 10) + 5
        local cy = sy + tileRand(x, y, 20 + i) * (ts - 10) + 5
        local rx = 3 + tileRand(x, y, 30 + i) * 4
        local ry = 2.5 + tileRand(x, y, 40 + i) * 3
        local sv = tileRandInt(x, y, 50 + i, -15, 15)

        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, rx, ry)
        nvgFillColor(nvg, nvgRGBA(170 + sv, 155 + sv, 130 + sv, 255))
        nvgFill(nvg)

        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx - rx * 0.2, cy - ry * 0.2, rx * 0.4, ry * 0.3)
        nvgFillColor(nvg, nvgRGBA(200 + sv, 190 + sv, 165 + sv, 80))
        nvgFill(nvg)
    end

    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, 2, ts)
    nvgFillColor(nvg, nvgRGBA(160, 140, 110, 60))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts - 2, sy, 2, ts)
    nvgFillColor(nvg, nvgRGBA(160, 140, 110, 60))
    nvgFill(nvg)
end

-- ============================================================================
-- 墙壁 (WALL) - 砖墙纹理
-- ============================================================================
function M.RenderWall(nvg, sx, sy, ts, x, y)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(75, 75, 75, 255))
    nvgFill(nvg)

    local brickH = ts / 3
    local brickW = ts / 2
    for row = 0, 2 do
        local offsetX = (row % 2 == 0) and 0 or (brickW * 0.5)
        local brickY = sy + row * brickH
        for col = -1, 2 do
            local brickX = sx + col * brickW + offsetX
            local bv = tileRandInt(x, y, row * 3 + col + 10, -10, 10)

            local drawX = math.max(sx, brickX + 1)
            local drawY = brickY + 1
            local drawW = math.min(sx + ts, brickX + brickW) - drawX - 1
            local drawH = brickH - 2

            if drawW > 0 and drawH > 0 then
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, drawX, drawY, drawW, drawH, 1)
                nvgFillColor(nvg, nvgRGBA(90 + bv, 85 + bv, 80 + bv, 255))
                nvgFill(nvg)

                nvgStrokeColor(nvg, nvgRGBA(55, 50, 45, 150))
                nvgStrokeWidth(nvg, 0.6)
                nvgStroke(nvg)
            end
        end
    end

    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, 1.5)
    nvgFillColor(nvg, nvgRGBA(110, 105, 100, 80))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts - 1.5, ts, 1.5)
    nvgFillColor(nvg, nvgRGBA(40, 35, 30, 80))
    nvgFill(nvg)
end

-- ============================================================================
-- 山岩瓦片 (MOUNTAIN) - 使用岩块图片
-- ============================================================================
function M.RenderMountain(nvg, sx, sy, ts, x, y)
    EnsureRockImage(nvg)

    if shared.rockImage > 0 then
        -- 先画底色（避免透明处露白）
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(100, 95, 85, 255))
        nvgFill(nvg)

        -- 用图片填充，根据坐标 hash 做微小变化（旋转 / 翻转效果）
        local hash = tileHash(x, y, 42) % 4
        -- 通过偏移模拟变化，避免所有岩块完全一样
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (256 - offsetX * 2)  -- 256 是图片原始尺寸，缩放至 ts(128)
        local imgSize = 256 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, shared.rockImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 加载失败时回退到纯色
        local colors = shared.GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[shared.ActiveZoneData.Get().TILE.MOUNTAIN])
    end
end

return M
