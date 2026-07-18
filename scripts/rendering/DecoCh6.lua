-- ============================================================================
-- DecoCh6.lua - 第六章专用装饰物渲染
-- ============================================================================

---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local RenderUtils = require("rendering.RenderUtils")

local M = {}

local stoneImage_ = nil
local stoneImageLoaded_ = false
local jieshiImage_ = nil
local jieshiImageLoaded_ = false
local LiangjieStoneSystem_ = nil
local systemLoadAttempted_ = false
local ArtifactCh6_ = nil
local artifactLoadAttempted_ = false

local function GetLiangjieStoneSystem()
    if not systemLoadAttempted_ then
        systemLoadAttempted_ = true
        local ok, mod = pcall(require, "systems.LiangjieStoneSystem")
        if ok then LiangjieStoneSystem_ = mod end
    end
    return LiangjieStoneSystem_
end

local function IsActivated(stoneId)
    local system = GetLiangjieStoneSystem()
    return system and system.IsActivated and system.IsActivated(stoneId) == true
end

local function GetArtifactCh6()
    if not artifactLoadAttempted_ then
        artifactLoadAttempted_ = true
        local ok, mod = pcall(require, "systems.ArtifactSystem_ch6")
        if ok then ArtifactCh6_ = mod end
    end
    return ArtifactCh6_
end

function M.RenderLiangjieStone(nvg, sx, sy, ts, d, _time)
    if not stoneImageLoaded_ then
        stoneImageLoaded_ = true
        stoneImage_ = RenderUtils.GetCachedImage(
            nvg,
            d.image or "image/ch6_liangjie_array_stone_20260710105731.png")
    end

    local active = IsActivated(d.stoneId)
    local color = d.color or {125, 190, 230, 255}
    local cx = sx + ts * 0.5
    local baseY = sy + ts * 0.82
    local glowY = sy + ts * 0.38

    -- 激活后光效为固定强度，不随等级变化。
    local innerAlpha = active and 110 or 38
    local outerAlpha = active and 48 or 12
    local glow = nvgRadialGradient(
        nvg,
        cx,
        glowY,
        ts * 0.12,
        ts * 0.92,
        nvgRGBA(color[1], color[2], color[3], innerAlpha),
        nvgRGBA(color[1], color[2], color[3], outerAlpha))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, glowY, ts * 0.92)
    nvgFillPaint(nvg, glow)
    nvgFill(nvg)

    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, baseY, ts * 0.48, ts * 0.14)
    nvgFillColor(nvg, nvgRGBA(4, 12, 22, active and 125 or 90))
    nvgFill(nvg)

    if active then
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, baseY - ts * 0.03, ts * 0.55, ts * 0.20)
        nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], 155))
        nvgStrokeWidth(nvg, math.max(1.5, ts * 0.035))
        nvgStroke(nvg)
    end

    if stoneImage_ then
        local imageScale = d.imageScale or 1.34
        local imageW = ts * imageScale
        local imageH = imageW * (d.imageAspect or (768 / 515))
        local imageX = cx - imageW * 0.5
        local imageY = baseY - imageH
        local paint = nvgImagePattern(
            nvg,
            imageX,
            imageY,
            imageW,
            imageH,
            0,
            stoneImage_,
            active and 1.0 or 0.78)
        nvgBeginPath(nvg)
        nvgRect(nvg, imageX, imageY, imageW, imageH)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end
end

function M.RenderDivineJieshi(nvg, sx, sy, ts, d, time)
    if not jieshiImageLoaded_ then
        jieshiImageLoaded_ = true
        jieshiImage_ = RenderUtils.GetCachedImage(
            nvg,
            d.image or "image/ch6_jieshi_world_artifact_20260711011456.png")
    end

    local system = GetArtifactCh6()
    local activeCount = system and system.GetActivatedCount
        and system.GetActivatedCount() or 0
    local progress = math.max(0, math.min(1, activeCount / 9))
    local cx = sx + ts * 0.5
    local baseY = sy + ts * 0.82
    local breath = 0.72 + math.sin(time * 1.7) * 0.18

    -- 双界地面环：左侧人界青白，右侧影界紫色。
    local ringR = ts * (0.68 + progress * 0.10)
    local leftGlow = nvgRadialGradient(nvg,
        cx - ts * 0.18, baseY, ts * 0.05, ringR,
        nvgRGBA(135, 235, 255, math.floor(90 * breath + progress * 35)),
        nvgRGBA(70, 160, 220, 0))
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx - ts * 0.12, baseY, ringR, ringR * 0.26)
    nvgFillPaint(nvg, leftGlow)
    nvgFill(nvg)

    local rightGlow = nvgRadialGradient(nvg,
        cx + ts * 0.18, baseY, ts * 0.05, ringR,
        nvgRGBA(185, 90, 255, math.floor(85 * breath + progress * 35)),
        nvgRGBA(90, 30, 160, 0))
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx + ts * 0.12, baseY, ringR, ringR * 0.26)
    nvgFillPaint(nvg, rightGlow)
    nvgFill(nvg)

    -- 中央竖向界缝，让未激活状态也具有清晰神器轮廓。
    local crackH = ts * 2.35
    local crackAlpha = math.floor(65 + breath * 80 + progress * 45)
    local crackPaint = nvgLinearGradient(nvg,
        cx, baseY - crackH, cx, baseY,
        nvgRGBA(150, 240, 255, 0),
        nvgRGBA(185, 105, 255, crackAlpha))
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - ts * 0.025, baseY - crackH, ts * 0.05, crackH)
    nvgFillPaint(nvg, crackPaint)
    nvgFill(nvg)

    if jieshiImage_ then
        local imageW = ts * (1.62 + progress * 0.08)
        local imageH = imageW * (768 / 515)
        local bob = math.sin(time * 1.35) * ts * 0.035
        local imageX = cx - imageW * 0.5
        local imageY = baseY - imageH + bob
        local imageAlpha = 0.82 + progress * 0.18
        local paint = nvgImagePattern(
            nvg, imageX, imageY, imageW, imageH,
            0, jieshiImage_, imageAlpha)
        nvgBeginPath(nvg)
        nvgRect(nvg, imageX, imageY, imageW, imageH)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end

    -- 九枚轨道光点对应九格进度；已激活格亮起，未激活格保持暗点。
    for i = 1, 9 do
        local angle = -math.pi * 0.5 + (i - 1) * math.pi * 2 / 9
            + time * 0.22
        local px = cx + math.cos(angle) * ts * 0.62
        local py = baseY - ts * 0.75 + math.sin(angle) * ts * 0.28
        local lit = i <= activeCount
        local color = i % 2 == 0
            and {185, 105, 255} or {145, 240, 255}
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, lit and ts * 0.035 or ts * 0.018)
        nvgFillColor(nvg, nvgRGBA(
            color[1], color[2], color[3], lit and 220 or 70))
        nvgFill(nvg)
    end
end

return M
