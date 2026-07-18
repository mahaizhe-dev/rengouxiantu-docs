-- ============================================================================
-- tiles/ch2_terrain.lua - 第二章特殊地形瓦片
-- 包含：堡垒城墙 (FORTRESS_WALL)、沼泽地面 (SWAMP)、战场焦土 (BATTLEFIELD)
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local shared = require("rendering.tiles.shared")
local ActiveZoneData = require("config.ActiveZoneData")

local M = {}

local tileHash    = shared.tileHash
local tileRand    = shared.tileRand
local tileRandInt = shared.tileRandInt

-- ============================================================================
-- 堡垒城墙 (FORTRESS_WALL) - 暗红岩块图片
-- ============================================================================
local function EnsureFortressWallImage(nvg)
    if shared.fortressWallImageLoaded then return end
    shared.fortressWallImageLoaded = true
    shared.fortressWallImage = nvgCreateImage(nvg, "Textures/fortress_wall_darkred.png", 0)
    if shared.fortressWallImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load fortress wall image, fallback to flat color")
    else
        print("[TileRenderer] Fortress wall image loaded: " .. shared.fortressWallImage)
    end
end

function M.RenderFortressWall(nvg, sx, sy, ts, x, y)
    EnsureFortressWallImage(nvg)

    if shared.fortressWallImage > 0 then
        -- 底色：暗红褐色（透明区域透出此底色，与场景融合）
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(75, 35, 30, 255))
        nvgFill(nvg)

        -- 用暗红岩块图片填充，坐标 hash 做微小偏移避免重复感
        local hash = tileHash(x, y, 99) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.12)
        local offsetY = (hash >= 2) and 0 or (ts * 0.12)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, shared.fortressWallImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 加载失败时回退到纯色
        local colors = shared.GetFlatColors()
        shared.RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.FORTRESS_WALL])
    end
end

-- ============================================================================
-- 沼泽地面 (SWAMP) - 沼泽泥地图片 + 积水点缀
-- ============================================================================
local function EnsureSwampImage(nvg)
    if shared.swampImageLoaded then return end
    shared.swampImageLoaded = true
    shared.swampImage = nvgCreateImage(nvg, "Textures/swamp_mud_tile.png", 0)
    if shared.swampImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load swamp image, fallback to flat color")
    else
        print("[TileRenderer] Swamp image loaded: " .. shared.swampImage)
    end
end

function M.RenderSwamp(nvg, sx, sy, ts, x, y)
    EnsureSwampImage(nvg)

    if shared.swampImage > 0 then
        -- 底色：深绿褐
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(40, 55, 35, 255))
        nvgFill(nvg)

        -- 贴图填充，hash偏移避免重复
        local hash = tileHash(x, y, 55) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, shared.swampImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)

        -- 随机积水光斑（约20%概率）
        if tileRand(x, y, 88) < 0.2 then
            local px = sx + tileRand(x, y, 89) * ts * 0.6 + ts * 0.2
            local py = sy + tileRand(x, y, 90) * ts * 0.6 + ts * 0.2
            local pr = 2 + tileRand(x, y, 91) * 3
            nvgBeginPath(nvg)
            nvgEllipse(nvg, px, py, pr, pr * 0.7)
            nvgFillColor(nvg, nvgRGBA(60, 90, 70, 60))
            nvgFill(nvg)
        end
    else
        local colors = shared.GetFlatColors()
        shared.RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.SWAMP])
    end
end

-- ============================================================================
-- 战场焦土 (BATTLEFIELD) - 战火遗迹图片 + 焦痕裂缝
-- ============================================================================
local function EnsureBattlefieldImage(nvg)
    if shared.battlefieldImageLoaded then return end
    shared.battlefieldImageLoaded = true
    shared.battlefieldImage = nvgCreateImage(nvg, "Textures/battlefield_tile.png", 0)
    if shared.battlefieldImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load battlefield image, fallback to flat color")
    else
        print("[TileRenderer] Battlefield image loaded: " .. shared.battlefieldImage)
    end
end

function M.RenderBattlefield(nvg, sx, sy, ts, x, y)
    EnsureBattlefieldImage(nvg)

    if shared.battlefieldImage > 0 then
        -- 底色：深褐焦土
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(65, 45, 30, 255))
        nvgFill(nvg)

        -- 贴图填充，hash偏移避免重复
        local hash = tileHash(x, y, 77) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, shared.battlefieldImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)

        -- 随机焦痕/裂缝（约25%概率）
        if tileRand(x, y, 120) < 0.25 then
            local cx = sx + tileRand(x, y, 121) * ts * 0.6 + ts * 0.2
            local cy = sy + tileRand(x, y, 122) * ts * 0.6 + ts * 0.2
            local len = 3 + tileRand(x, y, 123) * 6
            local ang = tileRand(x, y, 124) * math.pi
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx - math.cos(ang) * len, cy - math.sin(ang) * len)
            nvgLineTo(nvg, cx + math.cos(ang) * len, cy + math.sin(ang) * len)
            nvgStrokeColor(nvg, nvgRGBA(30, 20, 10, 90))
            nvgStrokeWidth(nvg, 1.0 + tileRand(x, y, 125) * 0.8)
            nvgStroke(nvg)
        end

        -- 随机火星余烬（约10%概率）
        if tileRand(x, y, 130) < 0.10 then
            local ex = sx + tileRand(x, y, 131) * ts * 0.8 + ts * 0.1
            local ey = sy + tileRand(x, y, 132) * ts * 0.8 + ts * 0.1
            local er = 1.5 + tileRand(x, y, 133) * 1.5
            nvgBeginPath(nvg)
            nvgCircle(nvg, ex, ey, er)
            nvgFillColor(nvg, nvgRGBA(120, 60, 20, 50))
            nvgFill(nvg)
        end
    else
        local colors = shared.GetFlatColors()
        shared.RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.BATTLEFIELD])
    end
end

return M
