-- ============================================================================
-- tiles/ch3_void.lua - 第三章虚空与魔化地形瓦片渲染
-- 包含: RiftVoid, BattlefieldVoid, CorruptedGround
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local Shared = require("rendering.tiles.shared")

local tileHash    = Shared.tileHash
local tileRand    = Shared.tileRand

local M = {}

-- Image handles
local riftVoidImage        = -1
local riftVoidImageLoaded  = false
local battlefieldVoidImage        = -1
local battlefieldVoidImageLoaded  = false

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

function M.RenderRiftVoid(nvg, sx, sy, ts, x, y)
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

function M.RenderBattlefieldVoid(nvg, sx, sy, ts, x, y)
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
function M.RenderCorruptedGround(nvg, sx, sy, ts, x, y)
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

return M
