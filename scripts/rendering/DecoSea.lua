-- ============================================================================
-- DecoSea.lua  —— 海域装饰物渲染
-- 从 DecorationRenderers.lua 纯剥离，零逻辑修改
-- ============================================================================
local RenderUtils = require("rendering.RenderUtils")

local M = {}

-- ============================================================================
-- 模块级延迟加载图片句柄
-- ============================================================================
local seaReefImage_ = nil
local seaReefImageLoaded_ = false
local qingbaiLotusImage_ = nil
local qingbaiLotusImageLoaded_ = false

-- ============================================================================
-- 海域礁石（PNG 绘制，随波浪轻微浮动）
-- ============================================================================
function M.RenderSeaReef(nvg, sx, sy, ts, d, time)
    if not seaReefImageLoaded_ then
        seaReefImageLoaded_ = true
        seaReefImage_ = RenderUtils.GetCachedImage(nvg, "image/sea_reef_20260320154625.png")
    end

    if not seaReefImage_ then return end

    -- 每个礁石根据位置产生不同的浮动相位
    local phase = (d.x or 0) * 1.7 + (d.y or 0) * 2.3
    local bobY = math.sin(time * 1.2 + phase) * ts * 0.04  -- 轻微上下浮动
    local scale = d.scale or 0.8
    local imgW = ts * scale
    local imgH = ts * scale
    local imgX = sx + (ts - imgW) * 0.5
    local imgY = sy + (ts - imgH) * 0.5 + bobY

    -- 半透明水下阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.65 + bobY, imgW * 0.4, imgH * 0.15)
    nvgFillColor(nvg, nvgRGBA(0, 30, 50, 40))
    nvgFill(nvg)

    -- 绘制礁石 PNG
    local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgW, imgH, 0, seaReefImage_, 0.85)
    nvgBeginPath(nvg)
    nvgRect(nvg, imgX, imgY, imgW, imgH)
    nvgFillPaint(nvg, imgPaint)
    nvgFill(nvg)
end

function M.RenderQingbaiLotus(nvg, sx, sy, ts, d, time)
    if not qingbaiLotusImageLoaded_ then
        qingbaiLotusImageLoaded_ = true
        qingbaiLotusImage_ = RenderUtils.GetCachedImage(
            nvg,
            d.image or "image/qingbai_lotus_interactive_object_20260701004120.png")
    end

    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.56
    local phase = time * 1.8 + (d.x or 0) * 0.73 + (d.y or 0) * 0.41
    local pulse = 0.82 + 0.18 * math.sin(phase)
    local bobY = math.sin(phase * 0.7) * ts * 0.035
    local scale = d.imageScale or d.scale or 1.75

    local glow = nvgRadialGradient(
        nvg, cx, cy + bobY, ts * 0.08, ts * 1.05,
        nvgRGBA(210, 255, 255, math.floor(105 * pulse)),
        nvgRGBA(78, 204, 220, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy + bobY, ts * 1.0)
    nvgFillPaint(nvg, glow)
    nvgFill(nvg)

    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy + ts * 0.36, ts * 0.58, ts * 0.18)
    nvgFillColor(nvg, nvgRGBA(8, 42, 52, 95))
    nvgFill(nvg)

    if qingbaiLotusImage_ then
        local size = ts * scale
        local imgX = cx - size * 0.5
        local imgY = cy - size * 0.68 + bobY
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, size, size, 0, qingbaiLotusImage_, 0.96)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, size, size)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
    else
        for i = 0, 5 do
            local a = i * math.pi / 3
            local px = cx + math.cos(a) * ts * 0.18
            local py = cy + bobY + math.sin(a) * ts * 0.10
            nvgBeginPath(nvg)
            nvgEllipse(nvg, px, py, ts * 0.20, ts * 0.09)
            nvgFillColor(nvg, nvgRGBA(220, 252, 255, 235))
            nvgFill(nvg)
        end
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy + bobY, ts * 0.10)
        nvgFillColor(nvg, nvgRGBA(114, 232, 222, 245))
        nvgFill(nvg)
    end

    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy + bobY, ts * 0.42)
    nvgStrokeColor(nvg, nvgRGBA(176, 238, 255, math.floor(70 * pulse)))
    nvgStrokeWidth(nvg, math.max(1.2, ts * 0.035))
    nvgStroke(nvg)
end

function M.RenderCrystalReed(nvg, sx, sy, ts, d, time)
    local c = d.color or {115, 225, 195, 255}
    local cx = sx + ts * 0.5
    local baseY = sy + ts * 0.78
    local pulse = 0.78 + 0.22 * math.sin(time * 1.7 + (d.x or 0) * 0.9)

    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, baseY + ts * 0.04, ts * 0.34, ts * 0.12)
    nvgFillColor(nvg, nvgRGBA(10, 55, 62, 70))
    nvgFill(nvg)

    for i = -1, 1 do
        local offset = i * ts * 0.13
        local topX = cx + offset + math.sin(time * 1.2 + i) * ts * 0.025
        local topY = sy + ts * (0.26 + 0.05 * math.abs(i))
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + offset * 0.4, baseY)
        nvgLineTo(nvg, topX - ts * 0.05, topY + ts * 0.18)
        nvgLineTo(nvg, topX, topY)
        nvgLineTo(nvg, topX + ts * 0.06, topY + ts * 0.18)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(c[4] * pulse)))
        nvgFill(nvg)

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, topX, topY + ts * 0.04)
        nvgLineTo(nvg, topX + ts * 0.025, baseY - ts * 0.06)
        nvgStrokeColor(nvg, nvgRGBA(245, 255, 255, math.floor(90 * pulse)))
        nvgStrokeWidth(nvg, math.max(0.8, ts * 0.025))
        nvgStroke(nvg)
    end
end

function M.RenderCrystalBubble(nvg, sx, sy, ts, d, time)
    local c = d.color or {145, 235, 255, 220}
    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.55
    local phase = time * 0.9 + (d.x or 0) * 0.7

    for i = 1, 4 do
        local a = phase + i * 1.7
        local bx = cx + math.cos(a) * ts * (0.11 + i * 0.035)
        local by = cy + math.sin(a * 0.8) * ts * 0.16
        local r = ts * (0.045 + i * 0.012)
        local alpha = math.floor((90 + 30 * math.sin(phase + i)) * (c[4] or 220) / 255)

        nvgBeginPath(nvg)
        nvgCircle(nvg, bx, by, r)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], alpha))
        nvgStrokeWidth(nvg, math.max(0.8, ts * 0.018))
        nvgStroke(nvg)

        nvgBeginPath(nvg)
        nvgCircle(nvg, bx - r * 0.25, by - r * 0.25, math.max(1, r * 0.22))
        nvgFillColor(nvg, nvgRGBA(245, 255, 255, math.floor(alpha * 0.65)))
        nvgFill(nvg)
    end
end

return M
