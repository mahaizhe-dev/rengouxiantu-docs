-- tiles/ch3_celestial.lua - 第三章仙府/封印瓦片
---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local shared = require("rendering.tiles.shared")
local M = {}

local tileHash = shared.tileHash
local tileRand = shared.tileRand
local tileRandInt = shared.tileRandInt

-- ============================================================================
-- 仙路 (CELESTIAL_ROAD) - 暖金石板路 + 拼缝 + 中央引导线
-- ============================================================================
function M.RenderCelestialRoad(nvg, sx, sy, ts, x, y)
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
function M.RenderSealedGate(nvg, sx, sy, ts, x, y)
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
function M.RenderLightCurtain(nvg, sx, sy, ts, x, y)
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
function M.RenderSealRed(nvg, sx, sy, ts, x, y)
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
    if shared.celestialWallImageLoaded then return end
    shared.celestialWallImageLoaded = true
    shared.celestialWallImage = nvgCreateImage(nvg, "Textures/tile_celestial_wall.png", 0)
    if shared.celestialWallImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load celestial wall image, fallback to procedural")
    else
        print("[TileRenderer] Celestial wall image loaded: " .. shared.celestialWallImage)
    end
end

function M.RenderCelestialWall(nvg, sx, sy, ts, x, y)
    EnsureCelestialWallImage(nvg)

    -- ① 底色：深蓝灰色（仙府基石）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(55, 65, 80, 255))
    nvgFill(nvg)

    -- ② 贴图层（如果可用）
    if shared.celestialWallImage > 0 then
        local hash = tileHash(x, y, 300) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, shared.celestialWallImage, 0.85)
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

return M
