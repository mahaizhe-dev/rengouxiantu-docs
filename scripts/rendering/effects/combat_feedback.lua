---@diagnostic disable
-- ============================================================================
-- effects/combat_feedback.lua - 结构化战斗跳字 NanoVG 渲染器
-- ============================================================================

local CombatFeedback = require("systems.combat.CombatFeedback")
local Config = require("config.CombatFeedbackConfig")

local M = {}
local renderModel = {}
local OUTLINE_OFFSETS = {
    {-2, 0},
    {2, 0},
    {0, -2},
    {0, 2},
}

local function rgbaWithAlpha(nvg, color, alpha)
    return nvgRGBA(
        color[1],
        color[2],
        color[3],
        math.floor((color[4] or 255) * alpha)
    )
end

local function drawOutlinedText(nvg, x, y, text, fontSize, color, alpha)
    nvgFontSize(nvg, math.floor(fontSize))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local outline = Config.COLORS.outline
    nvgFillColor(nvg, rgbaWithAlpha(nvg, outline, alpha * 0.92))
    for i = 1, #OUTLINE_OFFSETS do
        local offset = OUTLINE_OFFSETS[i]
        nvgText(nvg, x + offset[1], y + offset[2], text, nil)
    end
    nvgFillColor(nvg, rgbaWithAlpha(nvg, color, alpha))
    nvgText(nvg, x, y, text, nil)
end

local function drawSoftText(nvg, x, y, text, fontSize, color, alpha)
    nvgFontSize(nvg, math.floor(fontSize))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, rgbaWithAlpha(nvg, Config.COLORS.shadow, alpha * 0.75))
    nvgText(nvg, x + 1, y + 1, text, nil)
    nvgFillColor(nvg, rgbaWithAlpha(nvg, color, alpha))
    nvgText(nvg, x, y, text, nil)
end

function M.Render(nvg, l, camera)
    local items = CombatFeedback.GetItems()
    if #items == 0 then return end

    local tileSize = camera:GetTileSize()
    nvgFontFace(nvg, "sans")

    for i = 1, #items do
        local item = items[i]
        if camera:IsVisible(item.x, item.y, l.w, l.h, 3) then
            CombatFeedback.Evaluate(item, renderModel)
            local sx = (item.x - camera.x) * tileSize + l.w / 2 + l.x + renderModel.offsetX
            local sy = (item.y - camera.y) * tileSize + l.h / 2 + l.y + renderModel.offsetY
            local alpha = renderModel.alpha

            drawOutlinedText(
                nvg, sx, sy, item.text, renderModel.fontSize,
                item.style.color, alpha)

            if item.label then
                drawSoftText(
                    nvg, sx, sy - renderModel.fontSize * 0.86,
                    item.label, renderModel.labelSize,
                    item.style.labelColor, alpha)
            end

            if item.tag then
                drawSoftText(
                    nvg, sx + renderModel.fontSize * 1.05,
                    sy - renderModel.fontSize * 0.48,
                    item.tag, renderModel.tagSize,
                    item.style.color, alpha)
            end

            if (item.hitCount or 1) > 1 then
                drawSoftText(
                    nvg, sx + renderModel.fontSize * 1.05,
                    sy + renderModel.fontSize * 0.42,
                    "x" .. tostring(item.hitCount), Config.FONTS.count,
                    item.style.color, alpha)
            end
        end
    end
end

return M
