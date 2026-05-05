-- ============================================================================
-- TileRenderer.lua - 瓦片纹理绘制
-- ============================================================================
-- 安全区（城镇）瓦片使用 RPGMaker 风格程序化纹理
-- 其他区域瓦片使用纯色填充 + 棋盘格微调

local ActiveZoneData = require("config.ActiveZoneData")
local GameConfig = require("config.GameConfig")

local TileRenderer = {}

-- ============================================================================
-- 图片资源（延迟加载，首次渲染时初始化）
-- ============================================================================
local rockImage = -1        -- NanoVG 图片句柄（山岩）
local rockImageLoaded = false

local fortressWallImage = -1   -- NanoVG 图片句柄（堡垒墙-暗红岩块）
local fortressWallImageLoaded = false

local swampImage = -1          -- NanoVG 图片句柄（沼泽泥地）
local swampImageLoaded = false

local battlefieldImage = -1    -- NanoVG 图片句柄（战场焦土）
local battlefieldImageLoaded = false

local sandWallImage = -1       -- NanoVG 图片句柄（沙岩城墙）
local sandWallImageLoaded = false

local desertImage = -1         -- NanoVG 图片句柄（沙漠地面）
local desertImageLoaded = false

local celestialWallImage = -1      -- NanoVG 图片句柄（仙府城墙）
local celestialWallImageLoaded = false

local riftVoidImage = -1           -- NanoVG 图片句柄（天裂峡谷）
local riftVoidImageLoaded = false

local battlefieldVoidImage = -1    -- NanoVG 图片句柄（战场封印）
local battlefieldVoidImageLoaded = false

local waterImage = -1              -- NanoVG 图片句柄（瑶池水面）
local waterImageLoaded = false

local yaochiCliffImage = -1        -- NanoVG 图片句柄（瑶池崖壁）
local yaochiCliffImageLoaded = false

-- ============================================================================
-- 确定性伪随机（基于坐标的 hash，保证同一位置每帧结果相同）
-- ============================================================================
local function tileHash(x, y, seed)
    local h = (x * 374761393 + y * 668265263 + (seed or 0) * 1274126177) & 0x7FFFFFFF
    return h
end

local function tileRand(x, y, seed)
    return (tileHash(x, y, seed) % 10000) / 10000.0
end

local function tileRandInt(x, y, seed, lo, hi)
    return lo + (tileHash(x, y, seed) % (hi - lo + 1))
end

-- ============================================================================
-- 通用纯色瓦片（非安全区共用）
-- ============================================================================
local function RenderFlat(nvg, sx, sy, ts, x, y, color)
    local brighten = ((x + y) % 2 == 0) and 8 or 0
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(
        math.min(255, color[1] + brighten),
        math.min(255, color[2] + brighten),
        math.min(255, color[3] + brighten),
        color[4] or 255
    ))
    nvgFill(nvg)
end

-- 颜色表（动态构建，随章节切换自动更新）
local cachedFlatColors = nil
local cachedZoneDataRef = nil

local function GetFlatColors()
    local zd = ActiveZoneData.Get()
    if zd == cachedZoneDataRef and cachedFlatColors then
        return cachedFlatColors
    end
    cachedZoneDataRef = zd
    -- 数据驱动：从 ZoneData 读取颜色定义（B1 优化）
    cachedFlatColors = zd.TILE_COLORS or {}
    return cachedFlatColors
end

-- ============================================================================
-- 城镇地板 (TOWN_FLOOR) - 石砖拼接
-- ============================================================================
function TileRenderer.RenderTownFloor(nvg, sx, sy, ts, x, y)
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
function TileRenderer.RenderTownRoad(nvg, sx, sy, ts, x, y)
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
function TileRenderer.RenderWall(nvg, sx, sy, ts, x, y)
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
local function EnsureRockImage(nvg)
    if rockImageLoaded then return end
    rockImageLoaded = true
    rockImage = nvgCreateImage(nvg, "Textures/rock_natural_tile_20260228022750.png", 0)
    if rockImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load rock image, fallback to flat color")
    else
        print("[TileRenderer] Rock image loaded: " .. rockImage)
    end
end

function TileRenderer.RenderMountain(nvg, sx, sy, ts, x, y)
    EnsureRockImage(nvg)

    if rockImage > 0 then
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
            0, rockImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 加载失败时回退到纯色
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.MOUNTAIN])
    end
end

-- ============================================================================
-- 堡垒墙壁 (FORTRESS_WALL) - 暗红岩块图片
-- ============================================================================
local function EnsureFortressWallImage(nvg)
    if fortressWallImageLoaded then return end
    fortressWallImageLoaded = true
    fortressWallImage = nvgCreateImage(nvg, "Textures/fortress_wall_darkred.png", 0)
    if fortressWallImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load fortress wall image, fallback to flat color")
    else
        print("[TileRenderer] Fortress wall image loaded: " .. fortressWallImage)
    end
end

function TileRenderer.RenderFortressWall(nvg, sx, sy, ts, x, y)
    EnsureFortressWallImage(nvg)

    if fortressWallImage > 0 then
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
            0, fortressWallImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 加载失败时回退到纯色
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.FORTRESS_WALL])
    end
end

-- ============================================================================
-- 沼泽地面 (SWAMP) - 沼泽泥地图片 + 积水点缀
-- ============================================================================
local function EnsureSwampImage(nvg)
    if swampImageLoaded then return end
    swampImageLoaded = true
    swampImage = nvgCreateImage(nvg, "Textures/swamp_mud_tile.png", 0)
    if swampImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load swamp image, fallback to flat color")
    else
        print("[TileRenderer] Swamp image loaded: " .. swampImage)
    end
end

function TileRenderer.RenderSwamp(nvg, sx, sy, ts, x, y)
    EnsureSwampImage(nvg)

    if swampImage > 0 then
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
            0, swampImage, 1.0)
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
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.SWAMP])
    end
end

-- ============================================================================
-- 战场焦土 (BATTLEFIELD) - 战火遗迹图片 + 焦痕裂缝
-- ============================================================================
local function EnsureBattlefieldImage(nvg)
    if battlefieldImageLoaded then return end
    battlefieldImageLoaded = true
    battlefieldImage = nvgCreateImage(nvg, "Textures/battlefield_tile.png", 0)
    if battlefieldImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load battlefield image, fallback to flat color")
    else
        print("[TileRenderer] Battlefield image loaded: " .. battlefieldImage)
    end
end

function TileRenderer.RenderBattlefield(nvg, sx, sy, ts, x, y)
    EnsureBattlefieldImage(nvg)

    if battlefieldImage > 0 then
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
            0, battlefieldImage, 1.0)
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
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[ActiveZoneData.Get().TILE.BATTLEFIELD])
    end
end

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

function TileRenderer.RenderSandWall(nvg, sx, sy, ts, x, y)
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

function TileRenderer.RenderDesert(nvg, sx, sy, ts, x, y)
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
function TileRenderer.RenderSandDark(nvg, sx, sy, ts, x, y)
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
function TileRenderer.RenderSandLight(nvg, sx, sy, ts, x, y)
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
function TileRenderer.RenderDriedGrass(nvg, sx, sy, ts, x, y)
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
function TileRenderer.RenderCrackedEarth(nvg, sx, sy, ts, x, y)
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

-- ============================================================================
-- 仙府主道 (CELESTIAL_ROAD) - 金色石板路面 + 中央引导线 + 边沿
-- ============================================================================
function TileRenderer.RenderCelestialRoad(nvg, sx, sy, ts, x, y)
    -- ① 底色：暖金石板
    local bv = ((x + y) % 2 == 0) and 6 or -4
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(195 + bv, 175 + bv, 130 + bv, 255))
    nvgFill(nvg)

    -- ② 石板拼缝（2×2 网格）
    local halfW = ts / 2
    local halfH = ts / 2
    local offX = (y % 2 == 0) and (halfW * 0.5) or 0
    for bx = 0, 1 do
        for by = 0, 1 do
            local bsx = sx + bx * halfW + offX
            local bsy = sy + by * halfH
            local sv = tileRandInt(x, y, bx * 2 + by + 600, -6, 6)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bsx + 0.8, bsy + 0.8, halfW - 1.6, halfH - 1.6, 1.2)
            nvgFillColor(nvg, nvgRGBA(190 + sv, 170 + sv, 128 + sv, 255))
            nvgFill(nvg)
        end
    end

    -- ③ 中央引导线（金色条纹，沿 Y 方向贯穿）
    local lineW = math.max(1.5, ts * 0.06)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.5 - lineW * 0.5, sy, lineW, ts)
    nvgFillColor(nvg, nvgRGBA(220, 190, 110, 80))
    nvgFill(nvg)

    -- ④ 道路两侧边沿（微暗色带，区分道路与地面）
    local edgeW = math.max(1.5, ts * 0.07)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, edgeW, ts)
    nvgFillColor(nvg, nvgRGBA(160, 140, 100, 60))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts - edgeW, sy, edgeW, ts)
    nvgFillColor(nvg, nvgRGBA(160, 140, 100, 60))
    nvgFill(nvg)
end

-- ============================================================================
-- 封印光幕瓦片 (SEALED_GATE) - 金色光幕屏障（静态，无动画）
-- ============================================================================
function TileRenderer.RenderSealedGate(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗金色基底
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(40, 35, 50, 255))
    nvgFill(nvg)

    -- ② 金色光幕渐变（从中心向外辐射）
    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.5
    local glowPaint = nvgRadialGradient(nvg, cx, cy, ts * 0.05, ts * 0.5,
        nvgRGBA(255, 215, 80, 140),
        nvgRGBA(200, 160, 40, 30))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- ③ 网格纹理（封印法阵线条，确定性 hash 决定方向）
    local hash = tileHash(x, y, 700) % 4
    nvgStrokeColor(nvg, nvgRGBA(255, 230, 130, 50))
    nvgStrokeWidth(nvg, 0.8)
    -- 横线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + ts * 0.33)
    nvgLineTo(nvg, sx + ts, sy + ts * 0.33)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + ts * 0.67)
    nvgLineTo(nvg, sx + ts, sy + ts * 0.67)
    nvgStroke(nvg)
    -- 竖线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.33, sy)
    nvgLineTo(nvg, sx + ts * 0.33, sy + ts)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.67, sy)
    nvgLineTo(nvg, sx + ts * 0.67, sy + ts)
    nvgStroke(nvg)

    -- ④ 边框辉光（标识封印边界）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + 0.5, sy + 0.5, ts - 1, ts - 1)
    nvgStrokeColor(nvg, nvgRGBA(255, 210, 70, 70))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- ⑤ 随机封印符文（~10%概率）
    if tileRand(x, y, 710) < 0.10 then
        local rx = sx + tileRand(x, y, 711) * ts * 0.4 + ts * 0.3
        local ry = sy + tileRand(x, y, 712) * ts * 0.4 + ts * 0.3
        local rr = 2.0 + tileRand(x, y, 713) * 2
        nvgBeginPath(nvg)
        nvgCircle(nvg, rx, ry, rr)
        nvgStrokeColor(nvg, nvgRGBA(255, 220, 100, 60))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, rx, ry, rr * 0.35)
        nvgFillColor(nvg, nvgRGBA(255, 240, 150, 40))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 光幕分隔 (LIGHT_CURTAIN) - 蓝白能量屏障（战场之间的1格分隔）
-- ============================================================================
function TileRenderer.RenderLightCurtain(nvg, sx, sy, ts, x, y)
    -- ① 底色：深蓝黑
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(10, 15, 35, 255))
    nvgFill(nvg)

    -- ② 竖直光柱（中央蓝白渐变条）
    local cx = sx + ts * 0.5
    local barW = ts * 0.4
    local barPaint = nvgLinearGradient(nvg,
        cx - barW * 0.5, sy, cx + barW * 0.5, sy,
        nvgRGBA(60, 140, 255, 20),
        nvgRGBA(120, 200, 255, 120))
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - barW * 0.5, sy, barW, ts)
    nvgFillPaint(nvg, barPaint)
    nvgFill(nvg)

    -- ③ 中心亮线
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - 1, sy, 2, ts)
    nvgFillColor(nvg, nvgRGBA(180, 220, 255, 100))
    nvgFill(nvg)

    -- ④ 散点光粒（~15%概率）
    if tileRand(x, y, 800) < 0.15 then
        local px = cx + (tileRand(x, y, 801) - 0.5) * barW * 0.8
        local py = sy + tileRand(x, y, 802) * ts
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 1.0 + tileRand(x, y, 803) * 1.0)
        nvgFillColor(nvg, nvgRGBA(180, 220, 255, 60))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 红色封印 (SEAL_RED) - 血红光幕屏障（可交互解封）
-- ============================================================================
function TileRenderer.RenderSealRed(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗红基底
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(50, 10, 15, 255))
    nvgFill(nvg)

    -- ② 红色光幕渐变（从中心向外辐射）
    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.5
    local glowPaint = nvgRadialGradient(nvg, cx, cy, ts * 0.05, ts * 0.5,
        nvgRGBA(255, 50, 30, 160),
        nvgRGBA(180, 20, 10, 40))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- ③ 封印网格纹路
    nvgStrokeColor(nvg, nvgRGBA(255, 100, 80, 50))
    nvgStrokeWidth(nvg, 0.8)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + ts * 0.33)
    nvgLineTo(nvg, sx + ts, sy + ts * 0.33)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + ts * 0.67)
    nvgLineTo(nvg, sx + ts, sy + ts * 0.67)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.33, sy)
    nvgLineTo(nvg, sx + ts * 0.33, sy + ts)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.67, sy)
    nvgLineTo(nvg, sx + ts * 0.67, sy + ts)
    nvgStroke(nvg)

    -- ④ 边框红光
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + 0.5, sy + 0.5, ts - 1, ts - 1)
    nvgStrokeColor(nvg, nvgRGBA(255, 60, 30, 80))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- ⑤ 随机封印符文（~10%概率）
    if tileRand(x, y, 810) < 0.10 then
        local rx = sx + tileRand(x, y, 811) * ts * 0.4 + ts * 0.3
        local ry = sy + tileRand(x, y, 812) * ts * 0.4 + ts * 0.3
        local rr = 2.0 + tileRand(x, y, 813) * 2
        nvgBeginPath(nvg)
        nvgCircle(nvg, rx, ry, rr)
        nvgStrokeColor(nvg, nvgRGBA(255, 80, 50, 60))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 仙府城墙 (CELESTIAL_WALL) - 琉璃砖石 + 金色镶边 + 立体厚度
-- ============================================================================
local function EnsureCelestialWallImage(nvg)
    if celestialWallImageLoaded then return end
    celestialWallImageLoaded = true
    celestialWallImage = nvgCreateImage(nvg, "Textures/tile_celestial_wall.png", 0)
    if celestialWallImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load celestial wall image, fallback to procedural")
    else
        print("[TileRenderer] Celestial wall image loaded: " .. celestialWallImage)
    end
end

function TileRenderer.RenderCelestialWall(nvg, sx, sy, ts, x, y)
    EnsureCelestialWallImage(nvg)

    -- ① 底色：深蓝灰色（仙府基石）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(55, 65, 80, 255))
    nvgFill(nvg)

    -- ② 贴图层（如果可用）
    if celestialWallImage > 0 then
        local hash = tileHash(x, y, 300) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, celestialWallImage, 0.85)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 贴图不可用时：程序化砖块纹理
        local brickH = ts / 3
        local brickW = ts / 2
        for row = 0, 2 do
            local offX = (row % 2 == 0) and 0 or (brickW * 0.5)
            local brickY = sy + row * brickH
            for col = -1, 2 do
                local brickX = sx + col * brickW + offX
                local bv = tileRandInt(x, y, row * 3 + col + 300, -8, 8)
                local drawX = math.max(sx, brickX + 1)
                local drawY = brickY + 1
                local drawW = math.min(sx + ts, brickX + brickW) - drawX - 1
                local drawH = brickH - 2
                if drawW > 0 and drawH > 0 then
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, drawX, drawY, drawW, drawH, 1.5)
                    nvgFillColor(nvg, nvgRGBA(65 + bv, 75 + bv, 95 + bv, 255))
                    nvgFill(nvg)
                end
            end
        end
    end

    -- ③ 立体厚度：顶部高光（城墙顶面受光）
    local hlH = math.max(2, ts * 0.12)
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx, sy + hlH,
        nvgRGBA(180, 200, 220, 100), nvgRGBA(180, 200, 220, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, hlH)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)

    -- ④ 立体厚度：底部阴影（城墙下方投影）
    local shH = math.max(3, ts * 0.18)
    local shPaint = nvgLinearGradient(nvg, sx, sy + ts - shH, sx, sy + ts,
        nvgRGBA(10, 15, 25, 0), nvgRGBA(10, 15, 25, 160))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts - shH, ts, shH)
    nvgFillPaint(nvg, shPaint)
    nvgFill(nvg)

    -- ⑤ 金色镶边线（琉璃飞檐 - 城墙顶部金饰）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, 1.5)
    nvgFillColor(nvg, nvgRGBA(210, 180, 100, 120))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + 1.5, ts, 0.8)
    nvgFillColor(nvg, nvgRGBA(255, 220, 130, 60))
    nvgFill(nvg)

    -- ⑥ 左右边缘微暗（模拟墙面侧面）
    local edgeW = math.max(1.5, ts * 0.08)
    -- 左边缘
    local lePaint = nvgLinearGradient(nvg, sx, sy, sx + edgeW, sy,
        nvgRGBA(20, 25, 35, 80), nvgRGBA(20, 25, 35, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, edgeW, ts)
    nvgFillPaint(nvg, lePaint)
    nvgFill(nvg)
    -- 右边缘
    local rePaint = nvgLinearGradient(nvg, sx + ts - edgeW, sy, sx + ts, sy,
        nvgRGBA(20, 25, 35, 0), nvgRGBA(20, 25, 35, 80))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts - edgeW, sy, edgeW, ts)
    nvgFillPaint(nvg, rePaint)
    nvgFill(nvg)

    -- ⑦ 随机灵纹符文（~8%概率，仙府特色装饰）
    if tileRand(x, y, 310) < 0.08 then
        local rx = sx + tileRand(x, y, 311) * ts * 0.4 + ts * 0.3
        local ry = sy + tileRand(x, y, 312) * ts * 0.4 + ts * 0.3
        local rr = 2.5 + tileRand(x, y, 313) * 2
        -- 灵纹外圈
        nvgBeginPath(nvg)
        nvgCircle(nvg, rx, ry, rr)
        nvgStrokeColor(nvg, nvgRGBA(130, 200, 230, 50))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
        -- 灵纹内芯微光
        nvgBeginPath(nvg)
        nvgCircle(nvg, rx, ry, rr * 0.4)
        nvgFillColor(nvg, nvgRGBA(150, 220, 240, 35))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 天裂峡谷 (RIFT_VOID) - 深不见底的裂谷 + 紫色能量 + 立体深度
-- ============================================================================
local function EnsureRiftVoidImage(nvg)
    if riftVoidImageLoaded then return end
    riftVoidImageLoaded = true
    riftVoidImage = nvgCreateImage(nvg, "Textures/tile_rift_void.png", 0)
    if riftVoidImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load rift void image, fallback to procedural")
    else
        print("[TileRenderer] Rift void image loaded: " .. riftVoidImage)
    end
end

function TileRenderer.RenderRiftVoid(nvg, sx, sy, ts, x, y)
    EnsureRiftVoidImage(nvg)

    -- ① 底色：极深紫黑（无底深渊）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(8, 5, 18, 255))
    nvgFill(nvg)

    -- ② 贴图层（384x384 剑痕裂谷贴图，4×4 瓦片铺设）
    --    裂谷 y=24~27 共 4 格高，横向每 4 格重复
    --    每个瓦片显示图片的 1/16 区域
    if riftVoidImage > 0 then
        local RIFT_Y_START = 24
        local TILE_SPAN = 4
        local row = math.max(0, math.min(TILE_SPAN - 1, y - RIFT_Y_START))
        local col = x % TILE_SPAN

        local patternSize = ts * TILE_SPAN
        local paint = nvgImagePattern(nvg,
            sx - col * ts, sy - row * ts,
            patternSize, patternSize,
            0, riftVoidImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end

    -- ③ 深渊微粒闪烁（~10%概率，裂缝中央区域）
    if tileRand(x, y, 420) < 0.10 then
        local px = sx + tileRand(x, y, 421) * ts * 0.4 + ts * 0.3
        local py = sy + tileRand(x, y, 422) * ts * 0.2 + ts * 0.4
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 1.0 + tileRand(x, y, 423) * 1.0)
        nvgFillColor(nvg, nvgRGBA(120, 80, 200, 50))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 战场封印 (BATTLEFIELD_VOID) - 焦土 + 封印法阵 + 立体厚度
-- ============================================================================
local function EnsureBattlefieldVoidImage(nvg)
    if battlefieldVoidImageLoaded then return end
    battlefieldVoidImageLoaded = true
    battlefieldVoidImage = nvgCreateImage(nvg, "Textures/tile_battlefield_void.png", 0)
    if battlefieldVoidImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load battlefield void image, fallback to procedural")
    else
        print("[TileRenderer] Battlefield void image loaded: " .. battlefieldVoidImage)
    end
end

function TileRenderer.RenderBattlefieldVoid(nvg, sx, sy, ts, x, y)
    EnsureBattlefieldVoidImage(nvg)

    -- ① 底色：暗红灰焦土
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(50, 30, 35, 255))
    nvgFill(nvg)

    -- ② 贴图层
    if battlefieldVoidImage > 0 then
        local hash = tileHash(x, y, 500) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, battlefieldVoidImage, 0.8)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end

    -- ③ 立体厚度：顶部高光（焦土表面受光）
    local hlH = math.max(2, ts * 0.1)
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx, sy + hlH,
        nvgRGBA(120, 80, 70, 70), nvgRGBA(120, 80, 70, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, hlH)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)

    -- ④ 立体厚度：底部深色阴影
    local shH = math.max(2.5, ts * 0.15)
    local shPaint = nvgLinearGradient(nvg, sx, sy + ts - shH, sx, sy + ts,
        nvgRGBA(15, 5, 10, 0), nvgRGBA(15, 5, 10, 140))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts - shH, ts, shH)
    nvgFillPaint(nvg, shPaint)
    nvgFill(nvg)

    -- ⑤ 封印裂缝（每格 1~2 条）
    local numCracks = 1 + tileHash(x, y, 510) % 2
    for i = 1, numCracks do
        local cx1 = sx + tileRand(x, y, 511 + i * 4) * ts * 0.4 + ts * 0.1
        local cy1 = sy + tileRand(x, y, 512 + i * 4) * ts * 0.4 + ts * 0.1
        local cx2 = sx + tileRand(x, y, 513 + i * 4) * ts * 0.4 + ts * 0.5
        local cy2 = sy + tileRand(x, y, 514 + i * 4) * ts * 0.4 + ts * 0.5
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(30, 10, 15, 130))
        nvgStrokeWidth(nvg, 1.0 + tileRand(x, y, 515 + i) * 0.8)
        nvgStroke(nvg)
    end

    -- ⑥ 封印法阵微光（~7%概率，红紫色符文圆环）
    if tileRand(x, y, 520) < 0.07 then
        local fx = sx + tileRand(x, y, 521) * ts * 0.4 + ts * 0.3
        local fy = sy + tileRand(x, y, 522) * ts * 0.4 + ts * 0.3
        local fr = 2.5 + tileRand(x, y, 523) * 2.5
        -- 封印圆环
        nvgBeginPath(nvg)
        nvgCircle(nvg, fx, fy, fr)
        nvgStrokeColor(nvg, nvgRGBA(180, 50, 80, 50))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
        -- 内芯暗红光
        nvgBeginPath(nvg)
        nvgCircle(nvg, fx, fy, fr * 0.3)
        nvgFillColor(nvg, nvgRGBA(200, 60, 90, 30))
        nvgFill(nvg)
    end

    -- ⑦ 残余灵气火星（~8%概率）
    if tileRand(x, y, 530) < 0.08 then
        local ex = sx + tileRand(x, y, 531) * ts * 0.7 + ts * 0.15
        local ey = sy + tileRand(x, y, 532) * ts * 0.7 + ts * 0.15
        local er = 1.0 + tileRand(x, y, 533) * 1.2
        nvgBeginPath(nvg)
        nvgCircle(nvg, ex, ey, er)
        nvgFillColor(nvg, nvgRGBA(160, 50, 30, 40))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 魔化焦土 (CORRUPTED_GROUND) - 暗色焦土 + 裂纹 + 暗红余烬
-- ============================================================================
function TileRenderer.RenderCorruptedGround(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗褐红焦土
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local variation = tileHash(x, y, 600) % 20 - 10
    nvgFillColor(nvg, nvgRGBA(55 + variation, 35 + variation, 40 + variation, 255))
    nvgFill(nvg)

    -- ② 焦土纹理斑块（2~3个深色斑点）
    local numPatches = 2 + tileHash(x, y, 601) % 2
    for i = 1, numPatches do
        local px = sx + tileRand(x, y, 602 + i * 3) * ts * 0.6 + ts * 0.2
        local py = sy + tileRand(x, y, 603 + i * 3) * ts * 0.6 + ts * 0.2
        local pr = ts * (0.08 + tileRand(x, y, 604 + i * 3) * 0.12)
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pr)
        nvgFillColor(nvg, nvgRGBA(30, 15, 20, 80))
        nvgFill(nvg)
    end

    -- ③ 裂纹（1~2条）
    local numCracks = 1 + tileHash(x, y, 610) % 2
    for i = 1, numCracks do
        local cx1 = sx + tileRand(x, y, 611 + i * 4) * ts * 0.4 + ts * 0.1
        local cy1 = sy + tileRand(x, y, 612 + i * 4) * ts * 0.4 + ts * 0.1
        local cx2 = sx + tileRand(x, y, 613 + i * 4) * ts * 0.4 + ts * 0.5
        local cy2 = sy + tileRand(x, y, 614 + i * 4) * ts * 0.4 + ts * 0.5
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(25, 8, 12, 100))
        nvgStrokeWidth(nvg, 0.8 + tileRand(x, y, 615 + i) * 0.6)
        nvgStroke(nvg)
    end

    -- ④ 暗红余烬微光（~6%概率）
    if tileRand(x, y, 620) < 0.06 then
        local ex = sx + tileRand(x, y, 621) * ts * 0.6 + ts * 0.2
        local ey = sy + tileRand(x, y, 622) * ts * 0.6 + ts * 0.2
        local er = 1.2 + tileRand(x, y, 623) * 1.5
        nvgBeginPath(nvg)
        nvgCircle(nvg, ex, ey, er)
        nvgFillColor(nvg, nvgRGBA(140, 40, 25, 35))
        nvgFill(nvg)
    end
end

--- 重置颜色缓存（章节切换时调用）
function TileRenderer.ResetCache()
    cachedFlatColors = nil
    cachedZoneDataRef = nil
    cachedTileRenderFns = nil
    cachedTileRenderZoneRef = nil
end

-- ============================================================================
-- 瓦片渲染分发（查找表 + 纯色回退）
-- ============================================================================
-- 水面 (WATER) - PNG 水纹 + 波光高光
-- ============================================================================
local function EnsureWaterImage(nvg)
    if waterImageLoaded then return end
    waterImageLoaded = true
    waterImage = nvgCreateImage(nvg, "Textures/tile_water_yaochi.png", 0)
    if waterImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load water image, fallback to flat color")
    else
        print("[TileRenderer] Water image loaded: " .. waterImage)
    end
end

function TileRenderer.RenderWater(nvg, sx, sy, ts, x, y)
    EnsureWaterImage(nvg)

    -- ① 底色：深蓝
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(40, 90, 150, 255))
    nvgFill(nvg)

    -- ② PNG 纹理叠加
    if waterImage > 0 then
        local hash = tileHash(x, y, 700) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.08)
        local offsetY = (hash >= 2) and 0 or (ts * 0.08)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, waterImage, 0.75)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end

    -- ③ 对角高光（水面波光）
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx + ts, sy + ts,
        nvgRGBA(120, 200, 255, 30), nvgRGBA(120, 200, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- 瑶池崖壁 (YAOCHI_CLIFF) - PNG 岩石 + 立体厚度
-- ============================================================================
local function EnsureYaochiCliffImage(nvg)
    if yaochiCliffImageLoaded then return end
    yaochiCliffImageLoaded = true
    yaochiCliffImage = nvgCreateImage(nvg, "Textures/tile_cliff_yaochi.png", 0)
    if yaochiCliffImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load yaochi cliff image, fallback to procedural")
    else
        print("[TileRenderer] Yaochi cliff image loaded: " .. yaochiCliffImage)
    end
end

function TileRenderer.RenderYaochiCliff(nvg, sx, sy, ts, x, y)
    EnsureYaochiCliffImage(nvg)

    -- ① 底色：深灰褐岩石
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(70, 60, 50, 255))
    nvgFill(nvg)

    -- ② PNG 纹理叠加
    if yaochiCliffImage > 0 then
        local hash = tileHash(x, y, 800) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, yaochiCliffImage, 0.9)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 无贴图回退：程序化岩石纹理
        for i = 1, 5 do
            local rx = sx + tileRand(x, y, 800 + i) * ts * 0.8 + ts * 0.1
            local ry = sy + tileRand(x, y, 810 + i) * ts * 0.8 + ts * 0.1
            local rr = 1.5 + tileRand(x, y, 820 + i) * 2.5
            local bv = tileRandInt(x, y, 830 + i, -12, 12)
            nvgBeginPath(nvg)
            nvgCircle(nvg, rx, ry, rr)
            nvgFillColor(nvg, nvgRGBA(80 + bv, 70 + bv, 60 + bv, 60))
            nvgFill(nvg)
        end
    end

    -- ③ 顶部高光（崖顶受光）
    local hlH = math.max(2, ts * 0.1)
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx, sy + hlH,
        nvgRGBA(160, 150, 130, 80), nvgRGBA(160, 150, 130, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, hlH)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)

    -- ④ 底部阴影（崖底）
    local shH = math.max(3, ts * 0.15)
    local shPaint = nvgLinearGradient(nvg, sx, sy + ts - shH, sx, sy + ts,
        nvgRGBA(20, 15, 10, 0), nvgRGBA(20, 15, 10, 140))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts - shH, ts, shH)
    nvgFillPaint(nvg, shPaint)
    nvgFill(nvg)

    -- ⑤ 竖向裂缝纹理（~30%概率）
    if tileRand(x, y, 850) < 0.3 then
        local cx = sx + tileRand(x, y, 851) * ts * 0.6 + ts * 0.2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, sy + ts * 0.1)
        nvgLineTo(nvg, cx + ts * 0.05, sy + ts * 0.5)
        nvgLineTo(nvg, cx - ts * 0.03, sy + ts * 0.85)
        nvgStrokeColor(nvg, nvgRGBA(40, 35, 25, 60))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end
end

-- ============================================================================
local cachedTileRenderFns = nil
local cachedTileRenderZoneRef = nil

local function GetTileRenderFns()
    local zd = ActiveZoneData.Get()
    if zd == cachedTileRenderZoneRef and cachedTileRenderFns then
        return cachedTileRenderFns
    end
    cachedTileRenderZoneRef = zd
    local T = zd.TILE
    cachedTileRenderFns = {
        [T.TOWN_FLOOR]    = TileRenderer.RenderTownFloor,
        [T.TOWN_ROAD]     = TileRenderer.RenderTownRoad,
        [T.WALL]          = TileRenderer.RenderWall,
        [T.MOUNTAIN]      = TileRenderer.RenderMountain,
    }
    -- ch2 精细纹理瓦片（仅当枚举存在时注册）
    if T.FORTRESS_WALL then
        cachedTileRenderFns[T.FORTRESS_WALL] = TileRenderer.RenderFortressWall
    end
    if T.SWAMP then
        cachedTileRenderFns[T.SWAMP] = TileRenderer.RenderSwamp
    end
    if T.BATTLEFIELD then
        cachedTileRenderFns[T.BATTLEFIELD] = TileRenderer.RenderBattlefield
    end
    -- ch3 精细纹理瓦片
    if T.SAND_WALL then
        cachedTileRenderFns[T.SAND_WALL] = TileRenderer.RenderSandWall
    end
    if T.DESERT then
        cachedTileRenderFns[T.DESERT] = TileRenderer.RenderDesert
    end
    if T.SAND_DARK then
        cachedTileRenderFns[T.SAND_DARK] = TileRenderer.RenderSandDark
    end
    if T.SAND_LIGHT then
        cachedTileRenderFns[T.SAND_LIGHT] = TileRenderer.RenderSandLight
    end
    if T.DRIED_GRASS then
        cachedTileRenderFns[T.DRIED_GRASS] = TileRenderer.RenderDriedGrass
    end
    if T.CRACKED_EARTH then
        cachedTileRenderFns[T.CRACKED_EARTH] = TileRenderer.RenderCrackedEarth
    end
    -- 中洲精细纹理瓦片
    if T.CELESTIAL_WALL then
        cachedTileRenderFns[T.CELESTIAL_WALL] = TileRenderer.RenderCelestialWall
    end
    if T.CELESTIAL_ROAD then
        cachedTileRenderFns[T.CELESTIAL_ROAD] = TileRenderer.RenderCelestialRoad
    end
    if T.RIFT_VOID then
        cachedTileRenderFns[T.RIFT_VOID] = TileRenderer.RenderRiftVoid
    end
    if T.BATTLEFIELD_VOID then
        cachedTileRenderFns[T.BATTLEFIELD_VOID] = TileRenderer.RenderBattlefieldVoid
    end
    if T.CORRUPTED_GROUND then
        cachedTileRenderFns[T.CORRUPTED_GROUND] = TileRenderer.RenderCorruptedGround
    end
    -- 封印光幕（ch2 + 中洲战场共用）
    if T.SEALED_GATE then
        cachedTileRenderFns[T.SEALED_GATE] = TileRenderer.RenderSealedGate
    end
    -- 中洲：光幕分隔 + 红色封印
    if T.LIGHT_CURTAIN then
        cachedTileRenderFns[T.LIGHT_CURTAIN] = TileRenderer.RenderLightCurtain
    end
    if T.SEAL_RED then
        cachedTileRenderFns[T.SEAL_RED] = TileRenderer.RenderSealRed
    end
    -- 瑶池专属瓦片
    if T.WATER then
        cachedTileRenderFns[T.WATER] = TileRenderer.RenderWater
    end
    if T.YAOCHI_CLIFF then
        cachedTileRenderFns[T.YAOCHI_CLIFF] = TileRenderer.RenderYaochiCliff
    end
    return cachedTileRenderFns
end

function TileRenderer.RenderTile(nvg, sx, sy, ts, tileType, x, y)
    local renderFns = GetTileRenderFns()
    local fn = renderFns[tileType]
    if fn then
        fn(nvg, sx, sy, ts, x, y)
    else
        -- 非精细纹理瓦片：纯色 + 棋盘格微调
        local colors = GetFlatColors()
        local color = colors[tileType]
        if color then
            RenderFlat(nvg, sx, sy, ts, x, y, color)
        else
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, ts, ts)
            nvgFillColor(nvg, nvgRGBA(255, 0, 200, 200))
            nvgFill(nvg)
        end
    end
end

return TileRenderer
