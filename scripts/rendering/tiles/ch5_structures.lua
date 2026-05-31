-- tiles/ch5_structures.lua - 第五章建筑/结构瓦片
local shared = require("rendering.tiles.shared")
local M = {}

local tileHash = shared.tileHash
local tileRand = shared.tileRand
local tileRandInt = shared.tileRandInt

-- ============================================================================
-- CH5 青石墙 (CH5_WALL) - 蓝灰石砖 + PNG纹理
-- ============================================================================
local ch5WallImage = -1
local ch5WallImageLoaded = false

local function EnsureCh5WallImage(nvg)
    if ch5WallImageLoaded then return end
    ch5WallImageLoaded = true
    ch5WallImage = nvgCreateImage(nvg, "Textures/tile_wall_bluestone.png", 0)
    if ch5WallImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load ch5 wall bluestone image, fallback to flat color")
    else
        print("[TileRenderer] Ch5 wall bluestone image loaded: " .. ch5WallImage)
    end
end

function M.RenderCh5Wall(nvg, sx, sy, ts, x, y)
    EnsureCh5WallImage(nvg)

    if ch5WallImage > 0 then
        -- 底色兜底
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(55, 52, 50, 255))
        nvgFill(nvg)

        -- 纹理平铺，hash 偏移避免重复感（与 FortressWall 同模式）
        local hash = tileHash(x, y, 1880) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.12)
        local offsetY = (hash >= 2) and 0 or (ts * 0.12)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, ch5WallImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 无图片时用纯色
        local sv = tileRandInt(x, y, 1880, -5, 5)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(55 + sv, 52 + sv, 50 + sv, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 封印墙 (CH5_SEAL_WALL) - 剑台Boss房墙体（PNG纹理）
-- ============================================================================
local sealWallImage = -1
local sealWallImageLoaded = false

local function EnsureSealWallImage(nvg)
    if sealWallImageLoaded then return end
    sealWallImageLoaded = true
    sealWallImage = nvgCreateImage(nvg, "Textures/tile_seal_wall.png", 0)
    if sealWallImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load seal wall image")
    end
end

function M.RenderCh5SealWall(nvg, sx, sy, ts, x, y)
    EnsureSealWallImage(nvg)
    if sealWallImage > 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(50, 30, 28, 255))
        nvgFill(nvg)
        local hash = tileHash(x, y, 2100) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.12)
        local offsetY = (hash >= 2) and 0 or (ts * 0.12)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, sealWallImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        local sv = tileRandInt(x, y, 2100, -5, 5)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(50 + sv, 30 + sv, 28 + sv, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 封印墙·颜色变体 — 复用同一张 PNG 纹理，底色不同
-- ============================================================================

-- 通用带色封印墙渲染（baseR/G/B 控制底色）
local function RenderCh5SealWallTinted(nvg, sx, sy, ts, x, y, baseR, baseG, baseB)
    EnsureSealWallImage(nvg)
    if sealWallImage > 0 then
        -- 底色
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(baseR, baseG, baseB, 255))
        nvgFill(nvg)
        -- PNG 纹理叠加（与红色版逻辑一致）
        local hash = tileHash(x, y, 2100) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.12)
        local offsetY = (hash >= 2) and 0 or (ts * 0.12)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, sealWallImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        local sv = tileRandInt(x, y, 2100, -5, 5)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(baseR + sv, baseG + sv, baseB + sv, 255))
        nvgFill(nvg)
    end
end

function M.RenderCh5SealWallBlue(nvg, sx, sy, ts, x, y)
    RenderCh5SealWallTinted(nvg, sx, sy, ts, x, y, 28, 35, 55)
end

function M.RenderCh5SealWallGreen(nvg, sx, sy, ts, x, y)
    RenderCh5SealWallTinted(nvg, sx, sy, ts, x, y, 28, 50, 35)
end

function M.RenderCh5SealWallPurple(nvg, sx, sy, ts, x, y)
    RenderCh5SealWallTinted(nvg, sx, sy, ts, x, y, 45, 28, 55)
end

-- ============================================================================
-- CH5 封印祭台 (CH5_SEAL_FLOOR) - 剑台Boss房地面（PNG纹理）
-- ============================================================================
local sealFloorImage = -1
local sealFloorImageLoaded = false

local function EnsureSealFloorImage(nvg)
    if sealFloorImageLoaded then return end
    sealFloorImageLoaded = true
    sealFloorImage = nvgCreateImage(nvg, "Textures/tile_seal_floor.png", 0)
    if sealFloorImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load seal floor image")
    end
end

function M.RenderCh5SealFloor(nvg, sx, sy, ts, x, y)
    EnsureSealFloorImage(nvg)
    if sealFloorImage > 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(55, 55, 58, 255))
        nvgFill(nvg)
        local hash = tileHash(x, y, 2110) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.12)
        local offsetY = (hash >= 2) and 0 or (ts * 0.12)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, sealFloorImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        local sv = tileRandInt(x, y, 2110, -5, 5)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(55 + sv, 55 + sv, 58 + sv, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 封印地毯 (CH5_SEAL_CARPET)
-- ============================================================================
local sealCarpetImage = -1
local sealCarpetImageLoaded = false

local function EnsureSealCarpetImage(nvg)
    if sealCarpetImageLoaded then return end
    sealCarpetImageLoaded = true
    sealCarpetImage = nvgCreateImage(nvg, "Textures/tile_seal_carpet.png", 0)
    if sealCarpetImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load seal carpet image")
    end
end

function M.RenderCh5SealCarpet(nvg, sx, sy, ts, x, y)
    EnsureSealCarpetImage(nvg)
    if sealCarpetImage > 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(180, 40, 40, 255))
        nvgFill(nvg)
        local hash = tileHash(x, y, 2120) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.12)
        local offsetY = (hash >= 2) and 0 or (ts * 0.12)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, sealCarpetImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        local sv = tileRandInt(x, y, 2120, -5, 5)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(180 + sv, 40 + sv, 40 + sv, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 断崖边缘 (CH5_CLIFF) - 岩石质感 + 裂边 + 阴影渐变
-- ============================================================================
function M.RenderCh5Cliff(nvg, sx, sy, ts, x, y)
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
function M.RenderCh5SealedGate(nvg, sx, sy, ts, x, y)
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
function M.RenderCh5Bridge(nvg, sx, sy, ts, x, y)
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
function M.RenderCh5CityWall(nvg, sx, sy, ts, x, y)
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
function M.RenderCh5WallBattlement(nvg, sx, sy, ts, x, y)
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
function M.RenderCh5WallCollapsed(nvg, sx, sy, ts, x, y)
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
function M.RenderCh5BloodRiver(nvg, sx, sy, ts, x, y)
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

return M
