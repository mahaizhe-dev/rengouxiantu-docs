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

return M
