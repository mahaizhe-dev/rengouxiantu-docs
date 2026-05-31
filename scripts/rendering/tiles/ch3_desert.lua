-- ============================================================================
-- tiles/ch3_desert.lua - 第三章沙漠瓦片渲染
-- 包含: SandWall, Desert, SandDark, SandLight, DriedGrass, CrackedEarth
-- ============================================================================
local ActiveZoneData = require("config.ActiveZoneData")
local Shared = require("rendering.tiles.shared")

local tileHash    = Shared.tileHash
local tileRand    = Shared.tileRand
local tileRandInt = Shared.tileRandInt
local RenderFlat  = Shared.RenderFlat
local GetFlatColors = Shared.GetFlatColors

local M = {}

-- Image handles
local sandWallImage        = -1
local sandWallImageLoaded  = false
local desertImage          = -1
local desertImageLoaded    = false
-- ============================================================================
-- 沙岩城墙 (SAND_WALL) - 沙岩块图片
-- ============================================================================
local function EnsureSandWallImage(nvg)
    if sandWallImageLoaded then return end
    sandWallImageLoaded = true
    sandWallImage = nvgCreateImage(nvg, "Textures/tile_sand_wall.png", 0)
    if sandWallImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load sand wall image, fallback to flat color")
    else
        print("[TileRenderer] Sand wall image loaded: " .. sandWallImage)
    end
end

function M.RenderSandWall(nvg, sx, sy, ts, x, y)
    EnsureSandWallImage(nvg)

    if sandWallImage > 0 then
        -- 底色：暗黄沙岩色
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(140, 115, 60, 255))
        nvgFill(nvg)

        -- 图片平铺填充，hash 偏移避免重复
        local hash = tileHash(x, y, 63) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, sandWallImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.SAND_WALL])
    end
end

-- ============================================================================
-- 沙漠地面 (DESERT) - 沙漠贴图 + 风纹点缀
-- ============================================================================
local function EnsureDesertImage(nvg)
    if desertImageLoaded then return end
    desertImageLoaded = true
    desertImage = nvgCreateImage(nvg, "Textures/tile_desert.png", 0)
    if desertImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load desert image, fallback to flat color")
    else
        print("[TileRenderer] Desert image loaded: " .. desertImage)
    end
end

function M.RenderDesert(nvg, sx, sy, ts, x, y)
    EnsureDesertImage(nvg)

    if desertImage > 0 then
        -- 图片平铺填充（纹理自身已含完整颜色，不需要底色）
        local hash = tileHash(x, y, 71) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, desertImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)

        -- 随机风纹（约15%概率）
        if tileRand(x, y, 150) < 0.15 then
            local wx = sx + tileRand(x, y, 151) * ts * 0.6 + ts * 0.2
            local wy = sy + tileRand(x, y, 152) * ts * 0.6 + ts * 0.2
            local wlen = 4 + tileRand(x, y, 153) * 8
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, wx - wlen, wy)
            nvgQuadTo(nvg, wx, wy - 2, wx + wlen, wy + 1)
            nvgStrokeColor(nvg, nvgRGBA(220, 200, 150, 50))
            nvgStrokeWidth(nvg, 0.8)
            nvgStroke(nvg)
        end
    else
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.DESERT])
    end
end

-- ============================================================================
-- 砾石硬沙 (SAND_DARK) - 深色沙地 + 碎石点缀
-- ============================================================================
function M.RenderSandDark(nvg, sx, sy, ts, x, y)
    EnsureDesertImage(nvg)
    if desertImage > 0 then
        -- 暗色底色 + 贴图全不透明覆盖（单层，与ch2一致）
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(155, 130, 80, 255))
        nvgFill(nvg)
        local hash = tileHash(x, y, 81) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, desertImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
        -- 碎石颗粒（~20%概率，与ch2装饰概率对齐）
        if tileRand(x, y, 160) < 0.20 then
            local gx = sx + tileRand(x, y, 161) * ts * 0.7 + ts * 0.15
            local gy = sy + tileRand(x, y, 162) * ts * 0.7 + ts * 0.15
            nvgBeginPath(nvg)
            nvgCircle(nvg, gx, gy, 1.2 + tileRand(x, y, 163) * 1.5)
            nvgFillColor(nvg, nvgRGBA(110, 95, 65, 120))
            nvgFill(nvg)
        end
    else
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.SAND_DARK])
    end
end

-- ============================================================================
-- 流沙细沙 (SAND_LIGHT) - 浅色沙地 + 风纹
-- ============================================================================
function M.RenderSandLight(nvg, sx, sy, ts, x, y)
    EnsureDesertImage(nvg)
    if desertImage > 0 then
        -- 亮色底色 + 贴图全不透明覆盖（单层，与ch2一致）
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(225, 210, 160, 255))
        nvgFill(nvg)
        local hash = tileHash(x, y, 91) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, desertImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
        -- 风纹（~15%概率，与ch2装饰概率对齐）
        if tileRand(x, y, 170) < 0.15 then
            local wx = sx + tileRand(x, y, 171) * ts * 0.5 + ts * 0.15
            local wy = sy + tileRand(x, y, 172) * ts * 0.6 + ts * 0.2
            local wlen = 5 + tileRand(x, y, 173) * 10
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, wx - wlen, wy)
            nvgQuadTo(nvg, wx, wy - 3, wx + wlen, wy + 0.5)
            nvgStrokeColor(nvg, nvgRGBA(240, 225, 180, 70))
            nvgStrokeWidth(nvg, 0.7)
            nvgStroke(nvg)
        end
    else
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.SAND_LIGHT])
    end
end

-- ============================================================================
-- 枯黄杂草 (DRIED_GRASS) - 沙地底 + 枯草丛
-- ============================================================================
function M.RenderDriedGrass(nvg, sx, sy, ts, x, y)
    EnsureDesertImage(nvg)
    if desertImage > 0 then
        -- 暗黄绿底色 + 贴图全不透明覆盖（单层，与ch2一致）
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(175, 165, 90, 255))
        nvgFill(nvg)
        local hash = tileHash(x, y, 101) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, desertImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
        -- 枯草丝（~20%概率画1根，与ch2装饰概率对齐）
        if tileRand(x, y, 180) < 0.20 then
            local bx = sx + tileRand(x, y, 181) * ts * 0.7 + ts * 0.15
            local by = sy + tileRand(x, y, 185) * ts * 0.5 + ts * 0.4
            local bh = 3 + tileRand(x, y, 189) * 5
            local lean = (tileRand(x, y, 193) - 0.5) * 4
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, bx, by)
            nvgLineTo(nvg, bx + lean, by - bh)
            nvgStrokeColor(nvg, nvgRGBA(140, 130, 50, 180))
            nvgStrokeWidth(nvg, 0.8)
            nvgStroke(nvg)
        end
    else
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.DRIED_GRASS])
    end
end

-- ============================================================================
-- 裂地 (CRACKED_EARTH) - 暗沙底 + 裂纹 + 微光
-- ============================================================================
function M.RenderCrackedEarth(nvg, sx, sy, ts, x, y)
    -- 暗褐底色
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(120, 95, 60, 255))
    nvgFill(nvg)
    -- 棋盘格微调
    if (x + y) % 2 == 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 8))
        nvgFill(nvg)
    end
    -- 裂纹（每格 1~2 条）
    local numCracks = 1 + tileHash(x, y, 250) % 2
    for i = 1, numCracks do
        local cx1 = sx + tileRand(x, y, 251 + i * 4) * ts * 0.3 + ts * 0.1
        local cy1 = sy + tileRand(x, y, 252 + i * 4) * ts * 0.3 + ts * 0.1
        local cx2 = sx + tileRand(x, y, 253 + i * 4) * ts * 0.3 + ts * 0.55
        local cy2 = sy + tileRand(x, y, 254 + i * 4) * ts * 0.3 + ts * 0.55
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(50, 35, 20, 160))
        nvgStrokeWidth(nvg, 1.2 + tileRand(x, y, 255 + i) * 0.8)
        nvgStroke(nvg)
    end
    -- 微弱金色光芒（暗示神力）
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.5, ts * 0.35)
    nvgFillColor(nvg, nvgRGBA(220, 180, 80, 15))
    nvgFill(nvg)
end

return M
