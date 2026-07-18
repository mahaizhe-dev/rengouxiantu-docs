-- ============================================================================
-- ChapterAmbientRenderer.lua - 章节级世界氛围渲染
-- 仅绘制在 WorldRenderer 的世界裁剪区域内，不影响 UI 层。
-- ============================================================================

---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local ActiveZoneData = require("config.ActiveZoneData")

local ChapterAmbientRenderer = {}

local function rgba(c, fallbackAlpha)
    return nvgRGBA(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or fallbackAlpha or 255)
end

local function renderNightShadowVillage(nvg, l, ambient)
    local tint = ambient.tint or {18, 28, 55, 88}
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillColor(nvg, rgba(tint, 88))
    nvgFill(nvg)

    local mist = ambient.mist or {72, 92, 135, 26}
    local bandH = l.h * 0.22
    for i = 0, 2 do
        local y = l.y + l.h * (0.20 + i * 0.24)
        local alpha = math.max(8, (mist[4] or 26) - i * 5)
        local paint = nvgLinearGradient(nvg,
            l.x, y - bandH * 0.5,
            l.x, y + bandH * 0.5,
            nvgRGBA(mist[1], mist[2], mist[3], 0),
            nvgRGBA(mist[1], mist[2], mist[3], alpha)
        )
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, y - bandH * 0.5, l.w, bandH)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end

    local vignette = ambient.vignette or {0, 0, 0, 135}
    local cx = l.x + l.w * 0.5
    local cy = l.y + l.h * 0.5
    local inner = math.min(l.w, l.h) * 0.22
    local outer = math.max(l.w, l.h) * 0.68
    local vpaint = nvgRadialGradient(nvg, cx, cy, inner, outer,
        nvgRGBA(vignette[1], vignette[2], vignette[3], 0),
        nvgRGBA(vignette[1], vignette[2], vignette[3], vignette[4] or 135)
    )
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillPaint(nvg, vpaint)
    nvgFill(nvg)
end

function ChapterAmbientRenderer.Render(nvg, l, camera)
    local zd = ActiveZoneData.Get()
    local ambient = zd and zd.AMBIENT
    if not ambient or not ambient.enabled then return end

    if ambient.mode == "night_shadow_village" then
        renderNightShadowVillage(nvg, l, ambient)
    end
end

return ChapterAmbientRenderer
