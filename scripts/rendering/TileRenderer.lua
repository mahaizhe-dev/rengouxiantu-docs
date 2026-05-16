-- ============================================================================
-- TileRenderer.lua - 瓦片纹理绘制
-- ============================================================================
-- 安全区（城镇）瓦片使用 RPGMaker 风格程序化纹理
-- 其他区域瓦片使用纯色填充 + 棋盘格微调

local ActiveZoneData = require("config.ActiveZoneData")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")

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

local steleIntactImage = -1        -- NanoVG 图片句柄（完整石碑）
local steleIntactImageLoaded = false

local steleBrokenImage = -1        -- NanoVG 图片句柄（断壁残碑）
local steleBrokenImageLoaded = false

local bloodPoolImage = -1          -- NanoVG 图片句柄（祀剑池 3×2）
local bloodPoolImageLoaded = false

local furnaceImage = -1            -- NanoVG 图片句柄（铸剑地炉 3×3）
local furnaceImageLoaded = false

local lavaImage = -1               -- NanoVG 图片句柄（岩浆墙单格贴图）
local lavaImageLoaded = false

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
-- 完整石碑 (CH5_STELE_INTACT) - 使用 PNG 图片
-- ============================================================================
local function EnsureSteleIntactImage(nvg)
    if steleIntactImageLoaded then return end
    steleIntactImageLoaded = true
    steleIntactImage = nvgCreateImage(nvg, "image/tile_stele_intact_20260515023819.png", 0)
    if steleIntactImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load stele intact image, fallback to flat color")
    else
        print("[TileRenderer] Stele intact image loaded: " .. steleIntactImage)
    end
end

function TileRenderer.RenderSteleIntact(nvg, sx, sy, ts, x, y, gameMap)
    EnsureSteleIntactImage(nvg)

    if steleIntactImage > 0 then
        -- 3x3大碑：判断当前格在3x3中的位置
        local T = ActiveZoneData.Get().TILE
        local isLeftEdge = true
        local isTopEdge = true
        if gameMap and gameMap.GetTile then
            if x > 1 and gameMap:GetTile(x - 1, y) == T.CH5_STELE_INTACT then
                isLeftEdge = false
            end
            if y > 1 and gameMap:GetTile(x, y - 1) == T.CH5_STELE_INTACT then
                isTopEdge = false
            end
        end

        if isLeftEdge and isTopEdge then
            -- 左上角格：先画底色，再绘制3x3大碑图片
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, ts, ts)
            nvgFillColor(nvg, nvgRGBA(175, 170, 160, 255))
            nvgFill(nvg)

            local bigSize = ts * 3
            local paint = nvgImagePattern(nvg,
                sx, sy, bigSize, bigSize, 0, steleIntactImage, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, bigSize, bigSize)
            nvgFillPaint(nvg, paint)
            nvgFill(nvg)
        end
        -- 非左上角格：什么都不画（让左上角画的大图透出来）
    else
        -- fallback 纯色
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(175, 170, 160, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 断壁残碑 (CH5_STELE_BROKEN) - 使用 PNG 图片
-- ============================================================================
local function EnsureSteleBrokenImage(nvg)
    if steleBrokenImageLoaded then return end
    steleBrokenImageLoaded = true
    steleBrokenImage = nvgCreateImage(nvg, "image/tile_stele_broken_20260515023821.png", 0)
    if steleBrokenImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load stele broken image, fallback to flat color")
    else
        print("[TileRenderer] Stele broken image loaded: " .. steleBrokenImage)
    end
end

function TileRenderer.RenderSteleBroken(nvg, sx, sy, ts, x, y)
    EnsureSteleBrokenImage(nvg)

    if steleBrokenImage > 0 then
        -- 底色（碑林苍白石）
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(175, 170, 160, 255))
        nvgFill(nvg)

        -- 图片填充
        local hash = tileHash(x, y, 80) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.08)
        local offsetY = (hash >= 2) and 0 or (ts * 0.08)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, steleBrokenImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[80])
    end
end

-- ============================================================================
-- 祀剑池 (CH5_BLOOD_POOL) - 3×2 PNG 图片
-- ============================================================================
local function EnsureBloodPoolImage(nvg)
    if bloodPoolImageLoaded then return end
    bloodPoolImageLoaded = true
    bloodPoolImage = nvgCreateImage(nvg, "image/blood_pool_3x2_20260515065827.png", 0)
    if bloodPoolImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load blood pool image, fallback to flat color")
    else
        print("[TileRenderer] Blood pool image loaded: " .. bloodPoolImage)
    end
end

function TileRenderer.RenderBloodPool(nvg, sx, sy, ts, x, y, gameMap)
    EnsureBloodPoolImage(nvg)

    if bloodPoolImage > 0 then
        local T = ActiveZoneData.Get().TILE
        local isLeftEdge = true
        local isTopEdge = true
        if gameMap and gameMap.GetTile then
            if x > 1 and gameMap:GetTile(x - 1, y) == T.CH5_BLOOD_POOL then
                isLeftEdge = false
            end
            if y > 1 and gameMap:GetTile(x, y - 1) == T.CH5_BLOOD_POOL then
                isTopEdge = false
            end
        end

        if isLeftEdge and isTopEdge then
            -- 左上角格：先画底色，再绘制 3×2 大图
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, ts, ts)
            nvgFillColor(nvg, nvgRGBA(120, 35, 30, 255))
            nvgFill(nvg)

            local bigW = ts * 3
            local bigH = ts * 2
            local paint = nvgImagePattern(nvg,
                sx, sy, bigW, bigH, 0, bloodPoolImage, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, bigW, bigH)
            nvgFillPaint(nvg, paint)
            nvgFill(nvg)

            -- ── 传送阵式能量波纹特效 ──
            local t = GameState.gameTime or 0
            local cx = sx + bigW * 0.5
            local cy = sy + bigH * 0.5
            local maxR = math.min(bigW, bigH) * 0.45

            nvgSave(nvg)
            nvgIntersectScissor(nvg, sx, sy, bigW, bigH)

            -- 3 层同心扩散环，不同相位
            for i = 0, 2 do
                local phase = (t * 0.6 + i * 0.333) % 1.0   -- 0→1 循环
                local r = maxR * (0.2 + phase * 0.8)
                local alpha = math.floor(55 * (1.0 - phase))  -- 由浓到淡
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, r)
                nvgStrokeColor(nvg, nvgRGBA(180, 50, 60, alpha))
                nvgStrokeWidth(nvg, ts * 0.04)
                nvgStroke(nvg)
            end

            -- 中心稳定光晕（呼吸感）
            local breathAlpha = math.floor(30 + 20 * math.sin(t * 2.5))
            local glowR = maxR * 0.35
            local glowPaint = nvgRadialGradient(nvg,
                cx, cy, glowR * 0.1, glowR,
                nvgRGBA(200, 60, 80, breathAlpha),
                nvgRGBA(200, 60, 80, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, glowR)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)

            nvgRestore(nvg)

            -- ── 标题："祀剑池" ──
            local titleFontSize = ts * 0.45
            local titleText = "祀剑池"
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, titleFontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            local titleX = sx + bigW * 0.5
            local titleY = sy - ts * 0.1
            -- 暗底
            local tw = nvgTextBounds(nvg, 0, 0, titleText, nil)
            local padH, padV = 6, 3
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, titleX - tw/2 - padH, titleY - titleFontSize - padV, tw + padH*2, titleFontSize + padV*2, 4)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
            nvgFill(nvg)
            -- 文字（血红色）
            nvgFillColor(nvg, nvgRGBA(220, 80, 80, 255))
            nvgText(nvg, titleX, titleY, titleText, nil)
        end
        -- 非左上角格：不画，让大图透出
    else
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(100, 25, 25, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 铸剑地炉 (CH5_FURNACE) - 3×3 PNG 图片
-- ============================================================================
local function EnsureFurnaceImage(nvg)
    if furnaceImageLoaded then return end
    furnaceImageLoaded = true
    furnaceImage = nvgCreateImage(nvg, "image/furnace_3x3_20260515085411.png", 0)
    if furnaceImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load furnace image, fallback to flat color")
    else
        print("[TileRenderer] Furnace image loaded: " .. furnaceImage)
    end
end

function TileRenderer.RenderFurnace(nvg, sx, sy, ts, x, y, gameMap)
    EnsureFurnaceImage(nvg)

    if furnaceImage > 0 then
        local T = ActiveZoneData.Get().TILE
        local isLeftEdge = true
        local isTopEdge = true
        if gameMap and gameMap.GetTile then
            if x > 1 and gameMap:GetTile(x - 1, y) == T.CH5_FURNACE then
                isLeftEdge = false
            end
            if y > 1 and gameMap:GetTile(x, y - 1) == T.CH5_FURNACE then
                isTopEdge = false
            end
        end

        if isLeftEdge and isTopEdge then
            -- 左上角格：先画底色，再绘制 3×3 大图
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, ts, ts)
            nvgFillColor(nvg, nvgRGBA(45, 40, 38, 255))
            nvgFill(nvg)

            local bigSize = ts * 3
            local paint = nvgImagePattern(nvg,
                sx, sy, bigSize, bigSize, 0, furnaceImage, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, bigSize, bigSize)
            nvgFillPaint(nvg, paint)
            nvgFill(nvg)

            -- ── 标题："铸剑地炉" ──
            local titleFontSize = ts * 0.45
            local titleText = "铸剑地炉"
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, titleFontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            local titleX = sx + bigSize * 0.5
            local titleY = sy - ts * 0.1
            -- 暗底
            local tw = nvgTextBounds(nvg, 0, 0, titleText, nil)
            local padH, padV = 6, 3
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, titleX - tw/2 - padH, titleY - titleFontSize - padV, tw + padH*2, titleFontSize + padV*2, 4)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
            nvgFill(nvg)
            -- 文字（橙金色）
            nvgFillColor(nvg, nvgRGBA(255, 180, 60, 255))
            nvgText(nvg, titleX, titleY, titleText, nil)
        end
        -- 非左上角格：不画，让大图透出
    else
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(60, 45, 30, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 岩浆墙 (CH5_LAVA_WALL) - 单格 PNG 贴图
-- ============================================================================
local function EnsureLavaImage(nvg)
    if lavaImageLoaded then return end
    lavaImageLoaded = true
    lavaImage = nvgCreateImage(nvg, "image/lava_tile_20260515054323.png", 0)
    if lavaImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load lava image, fallback to flat color")
    else
        print("[TileRenderer] Lava image loaded: " .. lavaImage)
    end
end

function TileRenderer.RenderLavaWall(nvg, sx, sy, ts, x, y)
    EnsureLavaImage(nvg)

    -- 底色（加载失败时也可用）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(180, 60, 15, 255))
    nvgFill(nvg)

    if lavaImage > 0 then
        -- 通过坐标 hash 做微小偏移，避免所有格完全一样
        local hash = tileHash(x, y, 77) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.08)
        local offsetY = (hash >= 2) and 0 or (ts * 0.08)
        local imgSrc = 64  -- PNG 原始尺寸
        local scale = ts / (imgSrc - offsetX * 2)
        local imgSize = imgSrc * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, lavaImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 前营土地 (CH5_CAMP_DIRT) - 不规则泥土 + 碎石颗粒
-- ============================================================================
function TileRenderer.RenderCh5CampDirt(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗黄褐泥土
    local bv = ((x + y) % 2 == 0) and 6 or -4
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(130 + bv, 105 + bv, 70 + bv, 255))
    nvgFill(nvg)

    -- ② 泥土色斑（2~3 个不规则深色斑块）
    local numPatches = 2 + tileHash(x, y, 1000) % 2
    for i = 1, numPatches do
        local px = sx + tileRand(x, y, 1001 + i * 3) * ts * 0.6 + ts * 0.2
        local py = sy + tileRand(x, y, 1002 + i * 3) * ts * 0.6 + ts * 0.2
        local pr = ts * (0.1 + tileRand(x, y, 1003 + i * 3) * 0.12)
        nvgBeginPath(nvg)
        nvgEllipse(nvg, px, py, pr, pr * 0.8)
        nvgFillColor(nvg, nvgRGBA(110, 85, 55, 60))
        nvgFill(nvg)
    end

    -- ③ 碎石颗粒（~25% 概率，1~2 颗）
    if tileRand(x, y, 1010) < 0.25 then
        local cnt = 1 + tileHash(x, y, 1011) % 2
        for i = 1, cnt do
            local gx = sx + tileRand(x, y, 1012 + i) * ts * 0.7 + ts * 0.15
            local gy = sy + tileRand(x, y, 1013 + i) * ts * 0.7 + ts * 0.15
            local gr = 1.0 + tileRand(x, y, 1014 + i) * 1.5
            local gv = tileRandInt(x, y, 1015 + i, -10, 10)
            nvgBeginPath(nvg)
            nvgCircle(nvg, gx, gy, gr)
            nvgFillColor(nvg, nvgRGBA(100 + gv, 90 + gv, 65 + gv, 160))
            nvgFill(nvg)
        end
    end

    -- ④ 微弱脚印痕迹（~10% 概率）
    if tileRand(x, y, 1020) < 0.10 then
        local fx = sx + tileRand(x, y, 1021) * ts * 0.5 + ts * 0.25
        local fy = sy + tileRand(x, y, 1022) * ts * 0.5 + ts * 0.25
        nvgBeginPath(nvg)
        nvgEllipse(nvg, fx, fy, 2.0, 1.2)
        nvgFillColor(nvg, nvgRGBA(95, 75, 50, 50))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 前营修补石板 (CH5_CAMP_FLAGSTONE) - 石板拼接（参考 TownFloor）
-- ============================================================================
function TileRenderer.RenderCh5CampFlagstone(nvg, sx, sy, ts, x, y)
    -- ① 底色：灰褐石板基底
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(140, 125, 105, 255))
    nvgFill(nvg)

    -- ② 2x2 石板拼接（交错排列）
    local halfW = ts / 2
    local halfH = ts / 2
    local offsetX = (y % 2 == 0) and (halfW * 0.5) or 0
    for bx = 0, 1 do
        for by = 0, 1 do
            local bsx = sx + bx * halfW + offsetX
            local bsy = sy + by * halfH
            local sv = tileRandInt(x, y, bx * 2 + by + 1050, -10, 10)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bsx + 1, bsy + 1, halfW - 2, halfH - 2, 1.0)
            nvgFillColor(nvg, nvgRGBA(135 + sv, 120 + sv, 100 + sv, 255))
            nvgFill(nvg)
            -- 接缝
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bsx + 1, bsy + 1, halfW - 2, halfH - 2, 1.0)
            nvgStrokeColor(nvg, nvgRGBA(90, 80, 65, 100))
            nvgStrokeWidth(nvg, 0.7)
            nvgStroke(nvg)
        end
    end

    -- ③ 修补痕迹裂缝（~20% 概率）
    if tileRand(x, y, 1060) < 0.20 then
        local cx = sx + tileRand(x, y, 1061) * ts * 0.6 + ts * 0.2
        local cy = sy + tileRand(x, y, 1062) * ts * 0.6 + ts * 0.2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy)
        nvgLineTo(nvg, cx + 5, cy + 4)
        nvgLineTo(nvg, cx + 3, cy + 8)
        nvgStrokeColor(nvg, nvgRGBA(80, 65, 50, 80))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- CH5 废墟青石 (CH5_RUIN_BLUESTONE) - 青色石板 + 苔痕
-- ============================================================================
function TileRenderer.RenderCh5RuinBluestone(nvg, sx, sy, ts, x, y)
    -- ① 底色：青灰石
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(120 + bv, 135 + bv, 140 + bv, 255))
    nvgFill(nvg)

    -- ② 石板纹理线（横向 + 纵向淡线条）
    local lineY1 = sy + ts * (0.3 + tileRand(x, y, 1100) * 0.1)
    local lineY2 = sy + ts * (0.65 + tileRand(x, y, 1101) * 0.1)
    nvgStrokeColor(nvg, nvgRGBA(95, 110, 115, 60))
    nvgStrokeWidth(nvg, 0.6)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, lineY1)
    nvgLineTo(nvg, sx + ts, lineY1)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, lineY2)
    nvgLineTo(nvg, sx + ts, lineY2)
    nvgStroke(nvg)

    -- ③ 苔痕斑块（~20% 概率，1~2个绿色半透明斑）
    if tileRand(x, y, 1110) < 0.20 then
        local cnt = 1 + tileHash(x, y, 1111) % 2
        for i = 1, cnt do
            local mx = sx + tileRand(x, y, 1112 + i * 2) * ts * 0.6 + ts * 0.2
            local my = sy + tileRand(x, y, 1113 + i * 2) * ts * 0.6 + ts * 0.2
            local mr = 2.0 + tileRand(x, y, 1114 + i) * 2.5
            nvgBeginPath(nvg)
            nvgEllipse(nvg, mx, my, mr, mr * 0.7)
            nvgFillColor(nvg, nvgRGBA(60, 100, 55, 50))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- CH5 废墟裂石 (CH5_RUIN_CRACKED) - 裂纹石面 + 碎屑
-- ============================================================================
function TileRenderer.RenderCh5RuinCracked(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗灰石
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(105 + bv, 100 + bv, 95 + bv, 255))
    nvgFill(nvg)

    -- ② 主裂纹（每格 1~2 条）
    local numCracks = 1 + tileHash(x, y, 1150) % 2
    for i = 1, numCracks do
        local cx1 = sx + tileRand(x, y, 1151 + i * 4) * ts * 0.3 + ts * 0.1
        local cy1 = sy + tileRand(x, y, 1152 + i * 4) * ts * 0.3 + ts * 0.1
        local cx2 = sx + tileRand(x, y, 1153 + i * 4) * ts * 0.3 + ts * 0.55
        local cy2 = sy + tileRand(x, y, 1154 + i * 4) * ts * 0.3 + ts * 0.55
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(55, 50, 45, 140))
        nvgStrokeWidth(nvg, 1.0 + tileRand(x, y, 1155 + i) * 0.8)
        nvgStroke(nvg)
    end

    -- ③ 碎石屑散落（~15% 概率）
    if tileRand(x, y, 1160) < 0.15 then
        for i = 1, 2 do
            local dx = sx + tileRand(x, y, 1161 + i) * ts * 0.8 + ts * 0.1
            local dy = sy + tileRand(x, y, 1162 + i) * ts * 0.8 + ts * 0.1
            local dr = 0.8 + tileRand(x, y, 1163 + i) * 1.0
            nvgBeginPath(nvg)
            nvgCircle(nvg, dx, dy, dr)
            nvgFillColor(nvg, nvgRGBA(85, 80, 75, 100))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- CH5 铸剑焦黑石 (CH5_FORGE_BLACKSTONE) - 暗黑石面 + 锈色斑
-- ============================================================================
function TileRenderer.RenderCh5ForgeBlackstone(nvg, sx, sy, ts, x, y)
    -- ① 底色：极暗灰黑
    local bv = ((x + y) % 2 == 0) and 4 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(45 + bv, 40 + bv, 38 + bv, 255))
    nvgFill(nvg)

    -- ② 锈色斑点（2~3 个）
    local numSpots = 2 + tileHash(x, y, 1200) % 2
    for i = 1, numSpots do
        local rx = sx + tileRand(x, y, 1201 + i * 3) * ts * 0.7 + ts * 0.15
        local ry = sy + tileRand(x, y, 1202 + i * 3) * ts * 0.7 + ts * 0.15
        local rr = 1.5 + tileRand(x, y, 1203 + i * 3) * 2.0
        nvgBeginPath(nvg)
        nvgEllipse(nvg, rx, ry, rr, rr * 0.7)
        nvgFillColor(nvg, nvgRGBA(100, 55, 25, 45))
        nvgFill(nvg)
    end

    -- ③ 焦痕斑块（~15% 概率，填充椭圆替代线条）
    if tileRand(x, y, 1210) < 0.15 then
        local fx = sx + tileRand(x, y, 1211) * ts * 0.5 + ts * 0.25
        local fy = sy + tileRand(x, y, 1212) * ts * 0.5 + ts * 0.25
        local fr = 1.5 + tileRand(x, y, 1213) * 2.0
        nvgBeginPath(nvg)
        nvgEllipse(nvg, fx, fy, fr, fr * 0.6)
        nvgFillColor(nvg, nvgRGBA(30, 20, 15, 60))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 熔裂纹地面 (CH5_FORGE_MOLTEN) - 暗石 + 橙色熔纹线
-- ============================================================================
function TileRenderer.RenderCh5ForgeMolten(nvg, sx, sy, ts, x, y)
    -- ① 底色：深灰黑（类似锻造石）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(40, 35, 32, 255))
    nvgFill(nvg)

    -- ② 棋盘格微调
    if (x + y) % 2 == 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 6))
        nvgFill(nvg)
    end

    -- ③ 熔岩光斑（1~2 个发光椭圆，替代线条）
    local numSpots = 1 + tileHash(x, y, 1250) % 2
    for i = 1, numSpots do
        local cx = sx + tileRand(x, y, 1251 + i * 5) * ts * 0.6 + ts * 0.2
        local cy = sy + tileRand(x, y, 1252 + i * 5) * ts * 0.6 + ts * 0.2
        local cr = 2.0 + tileRand(x, y, 1253 + i * 5) * 2.5
        -- 发光外晕（宽、低透明）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, cr * 1.8, cr * 1.2)
        nvgFillColor(nvg, nvgRGBA(255, 120, 20, 25))
        nvgFill(nvg)
        -- 亮芯（窄、高亮）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, cr * 0.7, cr * 0.5)
        nvgFillColor(nvg, nvgRGBA(255, 180, 60, 80))
        nvgFill(nvg)
    end

    -- ④ 余温微光点（~10% 概率）
    if tileRand(x, y, 1260) < 0.10 then
        local ex = sx + tileRand(x, y, 1261) * ts * 0.7 + ts * 0.15
        local ey = sy + tileRand(x, y, 1262) * ts * 0.7 + ts * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, ex, ey, 1.5 + tileRand(x, y, 1263) * 1.5)
        nvgFillColor(nvg, nvgRGBA(255, 140, 30, 30))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 苔藓院石 (CH5_COURTYARD_MOSS) - 灰石板 + 绿苔斑
-- ============================================================================
function TileRenderer.RenderCh5CourtyardMoss(nvg, sx, sy, ts, x, y)
    -- ① 底色：灰石
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(130 + bv, 130 + bv, 120 + bv, 255))
    nvgFill(nvg)

    -- ② 石板接缝（十字形）
    local midX = sx + ts * (0.45 + tileRand(x, y, 1300) * 0.1)
    local midY = sy + ts * (0.45 + tileRand(x, y, 1301) * 0.1)
    nvgStrokeColor(nvg, nvgRGBA(100, 100, 90, 60))
    nvgStrokeWidth(nvg, 0.6)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, midX, sy)
    nvgLineTo(nvg, midX, sy + ts)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, midY)
    nvgLineTo(nvg, sx + ts, midY)
    nvgStroke(nvg)

    -- ③ 苔藓斑块（~30% 概率，2~3个绿斑）
    if tileRand(x, y, 1310) < 0.30 then
        local cnt = 2 + tileHash(x, y, 1311) % 2
        for i = 1, cnt do
            local mx = sx + tileRand(x, y, 1312 + i * 2) * ts * 0.7 + ts * 0.15
            local my = sy + tileRand(x, y, 1313 + i * 2) * ts * 0.7 + ts * 0.15
            local mr = 2.0 + tileRand(x, y, 1314 + i) * 3.0
            nvgBeginPath(nvg)
            nvgEllipse(nvg, mx, my, mr, mr * 0.6)
            nvgFillColor(nvg, nvgRGBA(50, 90, 40, 55))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- CH5 寒池玉石地 (CH5_COLD_JADE) - 冰蓝玉石 + 六角霜花
-- ============================================================================
function TileRenderer.RenderCh5ColdJade(nvg, sx, sy, ts, x, y)
    -- ① 底色：冰蓝玉石
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(160 + bv, 200 + bv, 215 + bv, 255))
    nvgFill(nvg)

    -- ② 玉石内纹理（淡色条纹）
    local lineAng = tileRand(x, y, 1350) * math.pi * 0.5
    local dx = math.cos(lineAng) * ts * 0.4
    local dy = math.sin(lineAng) * ts * 0.4
    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.5
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - dx, cy - dy)
    nvgLineTo(nvg, cx + dx, cy + dy)
    nvgStrokeColor(nvg, nvgRGBA(200, 230, 240, 50))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- ③ 六角霜花（~15% 概率，简化为 3 交叉线段）
    if tileRand(x, y, 1360) < 0.15 then
        local fx = sx + tileRand(x, y, 1361) * ts * 0.4 + ts * 0.3
        local fy = sy + tileRand(x, y, 1362) * ts * 0.4 + ts * 0.3
        local fr = 2.5 + tileRand(x, y, 1363) * 2.0
        nvgStrokeColor(nvg, nvgRGBA(220, 240, 255, 60))
        nvgStrokeWidth(nvg, 0.6)
        for a = 0, 2 do
            local ang = a * math.pi / 3
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, fx - math.cos(ang) * fr, fy - math.sin(ang) * fr)
            nvgLineTo(nvg, fx + math.cos(ang) * fr, fy + math.sin(ang) * fr)
            nvgStroke(nvg)
        end
    end

    -- ④ 微光泽（对角渐变高光）
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx + ts, sy + ts,
        nvgRGBA(220, 240, 255, 25), nvgRGBA(220, 240, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 寒池冰边 (CH5_COLD_ICE_EDGE) - 白蓝冰层 + 冰棱尖刺
-- ============================================================================
function TileRenderer.RenderCh5ColdIceEdge(nvg, sx, sy, ts, x, y)
    -- ① 底色：白蓝冰
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(200, 225, 240, 255))
    nvgFill(nvg)

    -- ② 冰层裂纹（2~3 条白色细线）
    local numLines = 2 + tileHash(x, y, 1400) % 2
    for i = 1, numLines do
        local lx1 = sx + tileRand(x, y, 1401 + i * 3) * ts * 0.4
        local ly1 = sy + tileRand(x, y, 1402 + i * 3) * ts
        local lx2 = sx + tileRand(x, y, 1403 + i * 3) * ts * 0.4 + ts * 0.6
        local ly2 = sy + tileRand(x, y, 1404 + i * 3) * ts
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx1, ly1)
        nvgLineTo(nvg, lx2, ly2)
        nvgStrokeColor(nvg, nvgRGBA(240, 248, 255, 80))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end

    -- ③ 冰棱三角尖刺（~20% 概率，1~2 个朝上的小三角）
    if tileRand(x, y, 1410) < 0.20 then
        local ix = sx + tileRand(x, y, 1411) * ts * 0.6 + ts * 0.2
        local iy = sy + ts * 0.8
        local iw = 2.0 + tileRand(x, y, 1412) * 2.0
        local ih = 3.0 + tileRand(x, y, 1413) * 3.0
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, ix - iw, iy)
        nvgLineTo(nvg, ix, iy - ih)
        nvgLineTo(nvg, ix + iw, iy)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(230, 245, 255, 140))
        nvgFill(nvg)
    end

    -- ④ 蓝白渐变覆盖（冰面光泽）
    local icePaint = nvgLinearGradient(nvg, sx, sy, sx, sy + ts,
        nvgRGBA(180, 210, 240, 40), nvgRGBA(220, 240, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, icePaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 碑林苍白石 (CH5_STELE_PALE) - 风化苍白石 + 纵向纹理
-- ============================================================================
function TileRenderer.RenderCh5StelePale(nvg, sx, sy, ts, x, y)
    -- ① 底色：苍白灰
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(170 + bv, 165 + bv, 158 + bv, 255))
    nvgFill(nvg)

    -- ② 纵向石纹（2~3 条竖直淡线）
    local numLines = 2 + tileHash(x, y, 1450) % 2
    for i = 1, numLines do
        local lx = sx + tileRand(x, y, 1451 + i) * ts * 0.8 + ts * 0.1
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx, sy + 1)
        nvgLineTo(nvg, lx + tileRand(x, y, 1452 + i) * 3 - 1.5, sy + ts - 1)
        nvgStrokeColor(nvg, nvgRGBA(145, 140, 132, 60))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end

    -- ③ 风化斑点（~15% 概率）
    if tileRand(x, y, 1460) < 0.15 then
        local wx = sx + tileRand(x, y, 1461) * ts * 0.6 + ts * 0.2
        local wy = sy + tileRand(x, y, 1462) * ts * 0.6 + ts * 0.2
        local wr = 1.5 + tileRand(x, y, 1463) * 2.0
        nvgBeginPath(nvg)
        nvgCircle(nvg, wx, wy, wr)
        nvgFillColor(nvg, nvgRGBA(155, 148, 140, 50))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 藏经焚毁地面 (CH5_LIBRARY_BURNT) - 焦木底 + 灰烬 + 余烬火星
-- ============================================================================
function TileRenderer.RenderCh5LibraryBurnt(nvg, sx, sy, ts, x, y)
    -- ① 底色：焦褐黑
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(55 + bv, 40 + bv, 30 + bv, 255))
    nvgFill(nvg)

    -- ② 焦木纹理（横向木纹线条）
    local numGrains = 2 + tileHash(x, y, 1500) % 2
    for i = 1, numGrains do
        local gy = sy + tileRand(x, y, 1501 + i) * ts * 0.8 + ts * 0.1
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + 2, gy)
        nvgLineTo(nvg, sx + ts - 2, gy + tileRand(x, y, 1502 + i) * 3 - 1.5)
        nvgStrokeColor(nvg, nvgRGBA(35, 25, 18, 80))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ③ 灰烬斑块（~20% 概率）
    if tileRand(x, y, 1510) < 0.20 then
        local ax = sx + tileRand(x, y, 1511) * ts * 0.5 + ts * 0.25
        local ay = sy + tileRand(x, y, 1512) * ts * 0.5 + ts * 0.25
        local ar = 2.0 + tileRand(x, y, 1513) * 2.5
        nvgBeginPath(nvg)
        nvgEllipse(nvg, ax, ay, ar, ar * 0.6)
        nvgFillColor(nvg, nvgRGBA(75, 70, 65, 50))
        nvgFill(nvg)
    end

    -- ④ 余烬火星（~8% 概率）
    if tileRand(x, y, 1520) < 0.08 then
        local ex = sx + tileRand(x, y, 1521) * ts * 0.7 + ts * 0.15
        local ey = sy + tileRand(x, y, 1522) * ts * 0.7 + ts * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, ex, ey, 1.0 + tileRand(x, y, 1523) * 0.8)
        nvgFillColor(nvg, nvgRGBA(200, 100, 30, 40))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 剑宫白石 (CH5_PALACE_WHITE) - 白石板 + 金边拼缝
-- ============================================================================
function TileRenderer.RenderCh5PalaceWhite(nvg, sx, sy, ts, x, y)
    -- ① 底色：温白石
    local bv = ((x + y) % 2 == 0) and 4 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(215 + bv, 210 + bv, 200 + bv, 255))
    nvgFill(nvg)

    -- ② 石板拼缝（2x2 方格 + 金色接缝线）
    local halfW = ts / 2
    local halfH = ts / 2
    for bx = 0, 1 do
        for by = 0, 1 do
            local bsx = sx + bx * halfW
            local bsy = sy + by * halfH
            local sv = tileRandInt(x, y, bx * 2 + by + 1550, -5, 5)
            nvgBeginPath(nvg)
            nvgRect(nvg, bsx + 0.8, bsy + 0.8, halfW - 1.6, halfH - 1.6)
            nvgFillColor(nvg, nvgRGBA(210 + sv, 205 + sv, 195 + sv, 255))
            nvgFill(nvg)
        end
    end
    -- 金色接缝
    nvgStrokeColor(nvg, nvgRGBA(200, 175, 110, 50))
    nvgStrokeWidth(nvg, 0.6)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + halfW, sy)
    nvgLineTo(nvg, sx + halfW, sy + ts)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + halfH)
    nvgLineTo(nvg, sx + ts, sy + halfH)
    nvgStroke(nvg)

    -- ③ 微光泽高光
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx + ts * 0.5, sy + ts * 0.5,
        nvgRGBA(255, 255, 240, 20), nvgRGBA(255, 255, 240, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 剑宫侵蚀脉络 (CH5_PALACE_CORRUPTED) - 暗紫基底 + 有机脉络纹
-- ============================================================================
function TileRenderer.RenderCh5PalaceCorrupted(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗紫灰
    local bv = ((x + y) % 2 == 0) and 4 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(65 + bv, 45 + bv, 75 + bv, 255))
    nvgFill(nvg)

    -- ② 有机脉络（2~3 条弯曲紫红线）
    local numVeins = 2 + tileHash(x, y, 1600) % 2
    for i = 1, numVeins do
        local vx1 = sx + tileRand(x, y, 1601 + i * 5) * ts * 0.3
        local vy1 = sy + tileRand(x, y, 1602 + i * 5) * ts
        local vx2 = sx + tileRand(x, y, 1603 + i * 5) * ts * 0.4 + ts * 0.3
        local vy2 = sy + tileRand(x, y, 1604 + i * 5) * ts
        local vcx = sx + tileRand(x, y, 1605 + i * 5) * ts * 0.4 + ts * 0.3
        local vcy = sy + tileRand(x, y, 1606 + i * 5) * ts
        -- 底层辉光（宽）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, vx1, vy1)
        nvgQuadTo(nvg, vcx, vcy, vx2, vy2)
        nvgStrokeColor(nvg, nvgRGBA(140, 50, 100, 25))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        -- 亮芯（窄）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, vx1, vy1)
        nvgQuadTo(nvg, vcx, vcy, vx2, vy2)
        nvgStrokeColor(nvg, nvgRGBA(180, 80, 140, 80))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ③ 侵蚀微光（~10% 概率）
    if tileRand(x, y, 1620) < 0.10 then
        local cx = sx + ts * 0.5
        local cy = sy + ts * 0.5
        local glowPaint = nvgRadialGradient(nvg, cx, cy, 0, ts * 0.3,
            nvgRGBA(150, 60, 120, 20), nvgRGBA(150, 60, 120, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, ts * 0.3)
        nvgFillPaint(nvg, glowPaint)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 血祭石 (CH5_BLOOD_RITUAL) - 暗红基底 + 符文刻痕
-- ============================================================================
function TileRenderer.RenderCh5BloodRitual(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗红褐
    local bv = ((x + y) % 2 == 0) and 4 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(95 + bv, 30 + bv, 25 + bv, 255))
    nvgFill(nvg)

    -- ② 祭祀纹路（十字 + 对角线）
    nvgStrokeColor(nvg, nvgRGBA(140, 50, 40, 50))
    nvgStrokeWidth(nvg, 0.7)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.5, sy + ts * 0.15)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.85)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.15, sy + ts * 0.5)
    nvgLineTo(nvg, sx + ts * 0.85, sy + ts * 0.5)
    nvgStroke(nvg)

    -- ③ 角落符文圆弧（~20% 概率）
    if tileRand(x, y, 1650) < 0.20 then
        local cx = sx + ts * 0.5
        local cy = sy + ts * 0.5
        local r = ts * 0.3
        nvgBeginPath(nvg)
        nvgArc(nvg, cx, cy, r, 0, math.pi * 1.2, 1)
        nvgStrokeColor(nvg, nvgRGBA(160, 60, 50, 45))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ④ 血迹渗出（~10% 概率）
    if tileRand(x, y, 1660) < 0.10 then
        local bx = sx + tileRand(x, y, 1661) * ts * 0.5 + ts * 0.25
        local by = sy + tileRand(x, y, 1662) * ts * 0.5 + ts * 0.25
        nvgBeginPath(nvg)
        nvgCircle(nvg, bx, by, 1.5 + tileRand(x, y, 1663) * 1.5)
        nvgFillColor(nvg, nvgRGBA(120, 20, 15, 50))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 深渊焦岩 (CH5_ABYSS_CHARRED) - 极暗底 + 橙色熔裂纹
-- ============================================================================
function TileRenderer.RenderCh5AbyssCharred(nvg, sx, sy, ts, x, y)
    -- ① 底色：极暗灰黑
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(25, 18, 15, 255))
    nvgFill(nvg)

    -- ② 棋盘微调
    if (x + y) % 2 == 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 5))
        nvgFill(nvg)
    end

    -- ③ 炽热裂纹（1~2 条橙色发光缝隙）
    local numCracks = 1 + tileHash(x, y, 1700) % 2
    for i = 1, numCracks do
        local cx1 = sx + tileRand(x, y, 1701 + i * 4) * ts * 0.3 + ts * 0.05
        local cy1 = sy + tileRand(x, y, 1702 + i * 4) * ts * 0.3 + ts * 0.05
        local cx2 = sx + tileRand(x, y, 1703 + i * 4) * ts * 0.3 + ts * 0.6
        local cy2 = sy + tileRand(x, y, 1704 + i * 4) * ts * 0.3 + ts * 0.6
        -- 底层辉光
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(200, 80, 10, 30))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        -- 亮芯
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(255, 160, 40, 100))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ④ 暗红微光（底部热辐射）
    local heatPaint = nvgLinearGradient(nvg, sx, sy + ts * 0.7, sx, sy + ts,
        nvgRGBA(180, 50, 10, 0), nvgRGBA(180, 50, 10, 20))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts * 0.7, ts, ts * 0.3)
    nvgFillPaint(nvg, heatPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 回廊暗石 (CH5_CORRIDOR_DARK) - 暗色方石 + 方形接缝
-- ============================================================================
function TileRenderer.RenderCh5CorridorDark(nvg, sx, sy, ts, x, y)
    -- ① 底色：深灰暗石
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(60, 55, 52, 255))
    nvgFill(nvg)

    -- ② 方形石板接缝（2x2 网格）
    local halfW = ts / 2
    local halfH = ts / 2
    for bx = 0, 1 do
        for by = 0, 1 do
            local bsx = sx + bx * halfW
            local bsy = sy + by * halfH
            local sv = tileRandInt(x, y, bx * 2 + by + 1750, -6, 6)
            nvgBeginPath(nvg)
            nvgRect(nvg, bsx + 0.8, bsy + 0.8, halfW - 1.6, halfH - 1.6)
            nvgFillColor(nvg, nvgRGBA(58 + sv, 53 + sv, 50 + sv, 255))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgRect(nvg, bsx + 0.8, bsy + 0.8, halfW - 1.6, halfH - 1.6)
            nvgStrokeColor(nvg, nvgRGBA(35, 30, 28, 80))
            nvgStrokeWidth(nvg, 0.6)
            nvgStroke(nvg)
        end
    end

    -- ③ 尘灰沉积（~10% 概率）
    if tileRand(x, y, 1760) < 0.10 then
        local dx = sx + tileRand(x, y, 1761) * ts * 0.5 + ts * 0.25
        local dy = sy + tileRand(x, y, 1762) * ts * 0.5 + ts * 0.25
        nvgBeginPath(nvg)
        nvgEllipse(nvg, dx, dy, 2.5, 1.5)
        nvgFillColor(nvg, nvgRGBA(80, 75, 70, 35))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 深渊血肉岩 (CH5_ABYSS_FLESH) - 暗红有机质感 + 脉动纹路
-- ============================================================================
function TileRenderer.RenderCh5AbyssFlesh(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗红褐
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1800, -5, 5)
    nvgFillColor(nvg, nvgRGBA(55 + sv, 20 + sv, 18 + sv, 255))
    nvgFill(nvg)

    -- ② 有机纹理（不规则弧形脉络 2~3 条）
    local numVeins = 2 + tileHash(x, y, 1801) % 2
    for i = 1, numVeins do
        local vx1 = sx + tileRand(x, y, 1802 + i * 5) * ts
        local vy1 = sy + tileRand(x, y, 1803 + i * 5) * ts
        local vx2 = sx + tileRand(x, y, 1804 + i * 5) * ts
        local vy2 = sy + tileRand(x, y, 1805 + i * 5) * ts
        local vcx = sx + tileRand(x, y, 1806 + i * 5) * ts
        local vcy = sy + tileRand(x, y, 1807 + i * 5) * ts
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, vx1, vy1)
        nvgQuadTo(nvg, vcx, vcy, vx2, vy2)
        nvgStrokeColor(nvg, nvgRGBA(120, 30, 25, 80))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end

    -- ③ 肉质凸起斑块（~15%）
    if tileRand(x, y, 1820) < 0.15 then
        local bx = sx + tileRand(x, y, 1821) * ts * 0.6 + ts * 0.2
        local by = sy + tileRand(x, y, 1822) * ts * 0.6 + ts * 0.2
        nvgBeginPath(nvg)
        nvgEllipse(nvg, bx, by, 2.5, 2.0)
        nvgFillColor(nvg, nvgRGBA(90, 30, 25, 60))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 回廊剑金属 (CH5_CORRIDOR_SWORD) - 暗铁墙面 + 剑痕刻纹
-- ============================================================================
function TileRenderer.RenderCh5CorridorSword(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗铁灰
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1830, -4, 4)
    nvgFillColor(nvg, nvgRGBA(50 + sv, 50 + sv, 55 + sv, 255))
    nvgFill(nvg)

    -- ② 金属横纹（水平拉丝效果）
    for i = 1, 3 do
        local ly = sy + tileRand(x, y, 1831 + i) * ts
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx, ly)
        nvgLineTo(nvg, sx + ts, ly)
        nvgStrokeColor(nvg, nvgRGBA(70, 70, 75, 30))
        nvgStrokeWidth(nvg, 0.5)
        nvgStroke(nvg)
    end

    -- ③ 剑痕斜划（1~2 条锐利的浅色斜线）
    local numSlash = 1 + tileHash(x, y, 1835) % 2
    for i = 1, numSlash do
        local ax = sx + tileRand(x, y, 1836 + i * 3) * ts * 0.4
        local ay = sy + tileRand(x, y, 1837 + i * 3) * ts * 0.3
        local bxx = ax + ts * 0.5 + tileRand(x, y, 1838 + i * 3) * ts * 0.2
        local byy = ay + ts * 0.5 + tileRand(x, y, 1839 + i * 3) * ts * 0.2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, ax, ay)
        nvgLineTo(nvg, bxx, byy)
        nvgStrokeColor(nvg, nvgRGBA(130, 130, 140, 50))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- CH5 虚空 (CH5_VOID) - 极深暗色 + 微弱星点
-- ============================================================================
function TileRenderer.RenderCh5Void(nvg, sx, sy, ts, x, y)
    -- ① 底色：近黑
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1860, -3, 3)
    nvgFillColor(nvg, nvgRGBA(10 + sv, 8 + sv, 15 + sv, 255))
    nvgFill(nvg)

    -- ② 暗紫渐变覆盖（底部略亮）
    local voidPaint = nvgLinearGradient(nvg, sx, sy, sx, sy + ts,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(20, 10, 30, 40))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, voidPaint)
    nvgFill(nvg)

    -- ③ 微弱星点（~20% 每格 1 点）
    if tileRand(x, y, 1861) < 0.20 then
        local px = sx + tileRand(x, y, 1862) * ts
        local py = sy + tileRand(x, y, 1863) * ts
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 0.5)
        nvgFillColor(nvg, nvgRGBA(150, 130, 200, 30))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 废墟墙体 (CH5_WALL) - 深灰砖墙 + 裂纹 + 苔藓
-- ============================================================================
function TileRenderer.RenderCh5Wall(nvg, sx, sy, ts, x, y)
    -- ① 底色：深灰
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1880, -5, 5)
    nvgFillColor(nvg, nvgRGBA(55 + sv, 52 + sv, 50 + sv, 255))
    nvgFill(nvg)

    -- ② 砖缝（横 2 + 竖 1 错缝）
    local hLine1 = sy + ts * 0.33
    local hLine2 = sy + ts * 0.66
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, hLine1)
    nvgLineTo(nvg, sx + ts, hLine1)
    nvgMoveTo(nvg, sx, hLine2)
    nvgLineTo(nvg, sx + ts, hLine2)
    local vOff = tileRand(x, y, 1881) * ts * 0.3 + ts * 0.3
    nvgMoveTo(nvg, sx + vOff, sy)
    nvgLineTo(nvg, sx + vOff, hLine1)
    local vOff2 = tileRand(x, y, 1882) * ts * 0.3 + ts * 0.35
    nvgMoveTo(nvg, sx + vOff2, hLine1)
    nvgLineTo(nvg, sx + vOff2, hLine2)
    nvgStrokeColor(nvg, nvgRGBA(35, 32, 30, 90))
    nvgStrokeWidth(nvg, 0.6)
    nvgStroke(nvg)

    -- ③ 裂纹（~15%）
    if tileRand(x, y, 1883) < 0.15 then
        local cx1 = sx + tileRand(x, y, 1884) * ts * 0.5 + ts * 0.1
        local cy1 = sy + tileRand(x, y, 1885) * ts * 0.3
        local cx2 = cx1 + tileRand(x, y, 1886) * ts * 0.3
        local cy2 = cy1 + ts * 0.4
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(25, 22, 20, 80))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- CH5 断崖边缘 (CH5_CLIFF) - 岩石质感 + 裂边 + 阴影渐变
-- ============================================================================
function TileRenderer.RenderCh5Cliff(nvg, sx, sy, ts, x, y)
    -- ① 底色：中灰岩石
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1900, -6, 6)
    nvgFillColor(nvg, nvgRGBA(70 + sv, 65 + sv, 60 + sv, 255))
    nvgFill(nvg)

    -- ② 下方深渊阴影渐变
    local cliffShadow = nvgLinearGradient(nvg, sx, sy + ts * 0.5, sx, sy + ts,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 80))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts * 0.5, ts, ts * 0.5)
    nvgFillPaint(nvg, cliffShadow)
    nvgFill(nvg)

    -- ③ 断裂锯齿边缘（底部 2~3 段锯齿线）
    nvgBeginPath(nvg)
    local edgeY = sy + ts * 0.75
    nvgMoveTo(nvg, sx, edgeY)
    local numTeeth = 2 + tileHash(x, y, 1901) % 2
    local segW = ts / numTeeth
    for i = 1, numTeeth do
        local peakX = sx + (i - 0.5) * segW
        local peakY = edgeY + tileRand(x, y, 1902 + i) * ts * 0.15
        local endX = sx + i * segW
        nvgLineTo(nvg, peakX, peakY)
        nvgLineTo(nvg, endX, edgeY + tileRand(x, y, 1905 + i) * 2)
    end
    nvgStrokeColor(nvg, nvgRGBA(35, 30, 28, 100))
    nvgStrokeWidth(nvg, 0.8)
    nvgStroke(nvg)
end

-- ============================================================================
-- CH5 封印门 (CH5_SEALED_GATE) - 暗石底 + 发光封印符文
-- ============================================================================
function TileRenderer.RenderCh5SealedGate(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗紫灰
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(45, 35, 55, 255))
    nvgFill(nvg)

    -- ② 门框矩形轮廓
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.15, sy + ts * 0.05, ts * 0.7, ts * 0.9)
    nvgStrokeColor(nvg, nvgRGBA(100, 70, 140, 120))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- ③ 中心封印圆（发光）
    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.45
    local r = ts * 0.15
    -- 外光晕
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r + 2)
    nvgFillColor(nvg, nvgRGBA(150, 100, 220, 25))
    nvgFill(nvg)
    -- 内圈
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r)
    nvgStrokeColor(nvg, nvgRGBA(180, 130, 255, 90))
    nvgStrokeWidth(nvg, 0.8)
    nvgStroke(nvg)

    -- ④ 十字封印线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - r * 0.7, cy)
    nvgLineTo(nvg, cx + r * 0.7, cy)
    nvgMoveTo(nvg, cx, cy - r * 0.7)
    nvgLineTo(nvg, cx, cy + r * 0.7)
    nvgStrokeColor(nvg, nvgRGBA(200, 160, 255, 70))
    nvgStrokeWidth(nvg, 0.6)
    nvgStroke(nvg)
end

-- ============================================================================
-- CH5 桥面 (CH5_BRIDGE) - 木板横纹 + 护栏暗示
-- ============================================================================
function TileRenderer.RenderCh5Bridge(nvg, sx, sy, ts, x, y)
    -- ① 底色：深褐木色
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1950, -5, 5)
    nvgFillColor(nvg, nvgRGBA(75 + sv, 55 + sv, 35 + sv, 255))
    nvgFill(nvg)

    -- ② 木板横纹（3 条深色线）
    for i = 1, 3 do
        local plankY = sy + (i * 0.25) * ts
        local wobble = tileRand(x, y, 1951 + i) * 1.5 - 0.75
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx, plankY + wobble)
        nvgLineTo(nvg, sx + ts, plankY + wobble)
        nvgStrokeColor(nvg, nvgRGBA(50, 35, 20, 70))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end

    -- ③ 两侧护栏暗示（左右各一条竖线）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + 1.5, sy)
    nvgLineTo(nvg, sx + 1.5, sy + ts)
    nvgMoveTo(nvg, sx + ts - 1.5, sy)
    nvgLineTo(nvg, sx + ts - 1.5, sy + ts)
    nvgStrokeColor(nvg, nvgRGBA(45, 30, 18, 90))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)
end

-- ============================================================================
-- CH5 剑气城墙 (CH5_CITY_WALL) - 厚重石墙 + 剑气蓝色辉光
-- ============================================================================
function TileRenderer.RenderCh5CityWall(nvg, sx, sy, ts, x, y)
    -- ① 底色：深灰蓝石
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1970, -4, 4)
    nvgFillColor(nvg, nvgRGBA(48 + sv, 48 + sv, 58 + sv, 255))
    nvgFill(nvg)

    -- ② 城砖缝隙（横 2 竖 2 交错）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + ts * 0.5)
    nvgLineTo(nvg, sx + ts, sy + ts * 0.5)
    local vx1 = sx + tileRand(x, y, 1971) * ts * 0.3 + ts * 0.2
    nvgMoveTo(nvg, vx1, sy)
    nvgLineTo(nvg, vx1, sy + ts * 0.5)
    local vx2 = sx + tileRand(x, y, 1972) * ts * 0.3 + ts * 0.4
    nvgMoveTo(nvg, vx2, sy + ts * 0.5)
    nvgLineTo(nvg, vx2, sy + ts)
    nvgStrokeColor(nvg, nvgRGBA(30, 30, 38, 80))
    nvgStrokeWidth(nvg, 0.6)
    nvgStroke(nvg)

    -- ③ 剑气蓝色微光条纹（1条）
    if tileRand(x, y, 1973) < 0.30 then
        local glY = sy + tileRand(x, y, 1974) * ts * 0.6 + ts * 0.2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + 2, glY)
        nvgLineTo(nvg, sx + ts - 2, glY)
        nvgStrokeColor(nvg, nvgRGBA(100, 160, 255, 35))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- CH5 城垛 (CH5_WALL_BATTLEMENT) - 矮墙垛口 + 凹槽
-- ============================================================================
function TileRenderer.RenderCh5WallBattlement(nvg, sx, sy, ts, x, y)
    -- ① 底色：中灰
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 2000, -4, 4)
    nvgFillColor(nvg, nvgRGBA(62 + sv, 58 + sv, 56 + sv, 255))
    nvgFill(nvg)

    -- ② 城垛凹口（上方中间挖去一块深色）
    local notchW = ts * 0.35
    local notchH = ts * 0.3
    local notchX = sx + (ts - notchW) * 0.5
    nvgBeginPath(nvg)
    nvgRect(nvg, notchX, sy, notchW, notchH)
    nvgFillColor(nvg, nvgRGBA(30, 28, 25, 180))
    nvgFill(nvg)

    -- ③ 垛口轮廓线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + notchH)
    nvgLineTo(nvg, notchX, sy + notchH)
    nvgLineTo(nvg, notchX, sy)
    nvgLineTo(nvg, notchX + notchW, sy)
    nvgLineTo(nvg, notchX + notchW, sy + notchH)
    nvgLineTo(nvg, sx + ts, sy + notchH)
    nvgStrokeColor(nvg, nvgRGBA(40, 36, 33, 100))
    nvgStrokeWidth(nvg, 0.7)
    nvgStroke(nvg)
end

-- ============================================================================
-- CH5 坍塌城墙 (CH5_WALL_COLLAPSED) - 碎石废墟地面 + 碎片散布
-- ============================================================================
function TileRenderer.RenderCh5WallCollapsed(nvg, sx, sy, ts, x, y)
    -- ① 底色：灰褐碎石
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 2020, -5, 5)
    nvgFillColor(nvg, nvgRGBA(72 + sv, 65 + sv, 58 + sv, 255))
    nvgFill(nvg)

    -- ② 散布碎石块（3~5 个小矩形）
    local numDebris = 3 + tileHash(x, y, 2021) % 3
    for i = 1, numDebris do
        local dx = sx + tileRand(x, y, 2022 + i * 3) * ts * 0.8 + ts * 0.1
        local dy = sy + tileRand(x, y, 2023 + i * 3) * ts * 0.8 + ts * 0.1
        local dw = 1.5 + tileRand(x, y, 2024 + i * 3) * 2.5
        local dh = 1.0 + tileRand(x, y, 2025 + i * 3) * 2.0
        local dv = tileRandInt(x, y, 2026 + i * 3, -8, 8)
        nvgBeginPath(nvg)
        nvgRect(nvg, dx, dy, dw, dh)
        nvgFillColor(nvg, nvgRGBA(55 + dv, 50 + dv, 45 + dv, 200))
        nvgFill(nvg)
    end

    -- ③ 尘土覆盖渐变（底部）
    local dustPaint = nvgLinearGradient(nvg, sx, sy + ts * 0.6, sx, sy + ts,
        nvgRGBA(100, 90, 80, 0), nvgRGBA(100, 90, 80, 25))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts * 0.6, ts, ts * 0.4)
    nvgFillPaint(nvg, dustPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 血河 (CH5_BLOOD_RIVER) - 暗红液体 + 波纹 + 泛光
-- ============================================================================
function TileRenderer.RenderCh5BloodRiver(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗血红
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 2050, -4, 4)
    nvgFillColor(nvg, nvgRGBA(80 + sv, 15 + sv, 12 + sv, 255))
    nvgFill(nvg)

    -- ② 棋盘微调（水面波光模拟）
    if (x + y) % 2 == 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(255, 200, 180, 8))
        nvgFill(nvg)
    end

    -- ③ 水平波纹线（2~3 条）
    local numWaves = 2 + tileHash(x, y, 2051) % 2
    for i = 1, numWaves do
        local waveY = sy + tileRand(x, y, 2052 + i) * ts * 0.7 + ts * 0.15
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx, waveY)
        local mid1 = sx + ts * 0.33
        local mid2 = sx + ts * 0.66
        local wobble1 = tileRand(x, y, 2054 + i) * 2 - 1
        local wobble2 = tileRand(x, y, 2056 + i) * 2 - 1
        nvgQuadTo(nvg, mid1, waveY + wobble1, mid2, waveY + wobble2)
        nvgLineTo(nvg, sx + ts, waveY + wobble2 * 0.5)
        nvgStrokeColor(nvg, nvgRGBA(120, 30, 20, 45))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end

    -- ④ 暗红泛光（中心高亮）
    local glowPaint = nvgRadialGradient(nvg, sx + ts * 0.5, sy + ts * 0.5,
        0, ts * 0.5,
        nvgRGBA(150, 40, 30, 18), nvgRGBA(150, 40, 30, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)
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
    -- ch5 石碑瓦片
    if T.CH5_STELE_INTACT then
        cachedTileRenderFns[T.CH5_STELE_INTACT] = TileRenderer.RenderSteleIntact
    end
    if T.CH5_STELE_BROKEN then
        cachedTileRenderFns[T.CH5_STELE_BROKEN] = TileRenderer.RenderSteleBroken
    end
    -- ch5 交互瓦片
    if T.CH5_BLOOD_POOL then
        cachedTileRenderFns[T.CH5_BLOOD_POOL] = TileRenderer.RenderBloodPool
    end
    if T.CH5_FURNACE then
        cachedTileRenderFns[T.CH5_FURNACE] = TileRenderer.RenderFurnace
    end
    if T.CH5_LAVA_WALL then
        cachedTileRenderFns[T.CH5_LAVA_WALL] = TileRenderer.RenderLavaWall
    end
    -- ch5 地面瓦片（程序化纹理）
    if T.CH5_CAMP_DIRT then
        cachedTileRenderFns[T.CH5_CAMP_DIRT] = TileRenderer.RenderCh5CampDirt
    end
    if T.CH5_CAMP_FLAGSTONE then
        cachedTileRenderFns[T.CH5_CAMP_FLAGSTONE] = TileRenderer.RenderCh5CampFlagstone
    end
    if T.CH5_RUIN_BLUESTONE then
        cachedTileRenderFns[T.CH5_RUIN_BLUESTONE] = TileRenderer.RenderCh5RuinBluestone
    end
    if T.CH5_RUIN_CRACKED then
        cachedTileRenderFns[T.CH5_RUIN_CRACKED] = TileRenderer.RenderCh5RuinCracked
    end
    if T.CH5_FORGE_BLACKSTONE then
        cachedTileRenderFns[T.CH5_FORGE_BLACKSTONE] = TileRenderer.RenderCh5ForgeBlackstone
    end
    if T.CH5_FORGE_MOLTEN then
        cachedTileRenderFns[T.CH5_FORGE_MOLTEN] = TileRenderer.RenderCh5ForgeMolten
    end
    if T.CH5_COURTYARD_MOSS then
        cachedTileRenderFns[T.CH5_COURTYARD_MOSS] = TileRenderer.RenderCh5CourtyardMoss
    end
    if T.CH5_COLD_JADE then
        cachedTileRenderFns[T.CH5_COLD_JADE] = TileRenderer.RenderCh5ColdJade
    end
    if T.CH5_COLD_ICE_EDGE then
        cachedTileRenderFns[T.CH5_COLD_ICE_EDGE] = TileRenderer.RenderCh5ColdIceEdge
    end
    if T.CH5_STELE_PALE then
        cachedTileRenderFns[T.CH5_STELE_PALE] = TileRenderer.RenderCh5StelePale
    end
    if T.CH5_LIBRARY_BURNT then
        cachedTileRenderFns[T.CH5_LIBRARY_BURNT] = TileRenderer.RenderCh5LibraryBurnt
    end
    if T.CH5_PALACE_WHITE then
        cachedTileRenderFns[T.CH5_PALACE_WHITE] = TileRenderer.RenderCh5PalaceWhite
    end
    if T.CH5_PALACE_CORRUPTED then
        cachedTileRenderFns[T.CH5_PALACE_CORRUPTED] = TileRenderer.RenderCh5PalaceCorrupted
    end
    if T.CH5_BLOOD_RITUAL then
        cachedTileRenderFns[T.CH5_BLOOD_RITUAL] = TileRenderer.RenderCh5BloodRitual
    end
    if T.CH5_ABYSS_CHARRED then
        cachedTileRenderFns[T.CH5_ABYSS_CHARRED] = TileRenderer.RenderCh5AbyssCharred
    end
    if T.CH5_CORRIDOR_DARK then
        cachedTileRenderFns[T.CH5_CORRIDOR_DARK] = TileRenderer.RenderCh5CorridorDark
    end
    -- ch5 结构/特殊瓦片
    if T.CH5_ABYSS_FLESH then
        cachedTileRenderFns[T.CH5_ABYSS_FLESH] = TileRenderer.RenderCh5AbyssFlesh
    end
    if T.CH5_CORRIDOR_SWORD then
        cachedTileRenderFns[T.CH5_CORRIDOR_SWORD] = TileRenderer.RenderCh5CorridorSword
    end
    if T.CH5_VOID then
        cachedTileRenderFns[T.CH5_VOID] = TileRenderer.RenderCh5Void
    end
    if T.CH5_WALL then
        cachedTileRenderFns[T.CH5_WALL] = TileRenderer.RenderCh5Wall
    end
    if T.CH5_CLIFF then
        cachedTileRenderFns[T.CH5_CLIFF] = TileRenderer.RenderCh5Cliff
    end
    if T.CH5_SEALED_GATE then
        cachedTileRenderFns[T.CH5_SEALED_GATE] = TileRenderer.RenderCh5SealedGate
    end
    if T.CH5_BRIDGE then
        cachedTileRenderFns[T.CH5_BRIDGE] = TileRenderer.RenderCh5Bridge
    end
    if T.CH5_CITY_WALL then
        cachedTileRenderFns[T.CH5_CITY_WALL] = TileRenderer.RenderCh5CityWall
    end
    if T.CH5_WALL_BATTLEMENT then
        cachedTileRenderFns[T.CH5_WALL_BATTLEMENT] = TileRenderer.RenderCh5WallBattlement
    end
    if T.CH5_WALL_COLLAPSED then
        cachedTileRenderFns[T.CH5_WALL_COLLAPSED] = TileRenderer.RenderCh5WallCollapsed
    end
    if T.CH5_BLOOD_RIVER then
        cachedTileRenderFns[T.CH5_BLOOD_RIVER] = TileRenderer.RenderCh5BloodRiver
    end
    return cachedTileRenderFns
end

function TileRenderer.RenderTile(nvg, sx, sy, ts, tileType, x, y, gameMap)
    local renderFns = GetTileRenderFns()
    local fn = renderFns[tileType]
    if fn then
        fn(nvg, sx, sy, ts, x, y, gameMap)
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
