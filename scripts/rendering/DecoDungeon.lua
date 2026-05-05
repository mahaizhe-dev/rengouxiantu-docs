-- ============================================================================
-- DecoDungeon.lua - 地牢/暗黑装饰物渲染（从 DecorationRenderers 拆分）
-- 包含: Cobweb, Mushroom, Crystal, Stalactite, BonePile, DeadTree, Crack,
--        StoneTablet, Banner
-- ============================================================================

local T = require("config.UITheme")

local M = {}

-- ============================================================================
-- 模块级常量
-- ============================================================================

-- RenderMushroom: 蘑菇参数
local MUSHROOM_DEFS = {
    {x = 0.3, y = 0.82, stemH = 0.2, capR = 0.12},
    {x = 0.55, y = 0.78, stemH = 0.28, capR = 0.15},
    {x = 0.72, y = 0.85, stemH = 0.15, capR = 0.09},
}

-- RenderBonePile: 骨骼参数 {x1, y1, x2, y2, width}
local BONE_PILE_DEFS = {
    {0.2, 0.7, 0.55, 0.6, 2.5},   -- 大腿骨
    {0.4, 0.75, 0.8, 0.65, 2.0},   -- 交叉骨
    {0.3, 0.55, 0.5, 0.5, 1.8},    -- 上方骨
    {0.55, 0.72, 0.75, 0.78, 1.5}, -- 小骨
    {0.15, 0.62, 0.35, 0.68, 1.5}, -- 碎骨
}

-- RenderDeadTree: 枯枝参数 {起点x, 起点y, 终点x, 终点y, 粗细}
local DEAD_TREE_BRANCHES = {
    {0.45, 0.3, 0.2, 0.12, 2.0},
    {0.5, 0.25, 0.8, 0.08, 1.8},
    {0.42, 0.4, 0.15, 0.28, 1.5},
    {0.55, 0.35, 0.82, 0.22, 1.5},
    {0.48, 0.22, 0.45, 0.06, 1.2},
}

-- RenderCrack: 碎石位置
local CRACK_DEBRIS = {{0.18, 0.18}, {0.55, 0.28}, {0.42, 0.5}, {0.65, 0.62}, {0.38, 0.85}}

-- 默认颜色常量
local DEFAULT_COLOR_MUSHROOM  = {180, 140, 200, 255}
local DEFAULT_COLOR_CRYSTAL   = {80, 160, 255, 255}
local DEFAULT_COLOR_BANNER    = {120, 40, 40, 255}

-- ============================================================================
-- 蛛网 - 半透明丝线从角落辐射
-- ============================================================================
function M.RenderCobweb(nvg, sx, sy, ts, d, time)
    local cx = sx + ts * 0.5
    local cy = sx and (sy + ts * 0.5) -- center

    -- 轻微飘动
    local sway = math.sin(time * 0.8 + (d.x or 0) * 2.3) * 1.5

    -- 丝线从左上角辐射
    local anchorX = sx + ts * 0.05
    local anchorY = sy + ts * 0.05
    local tips = {
        {sx + ts * 0.7, sy + ts * 0.15 + sway},
        {sx + ts * 0.9 + sway * 0.5, sy + ts * 0.45},
        {sx + ts * 0.6, sy + ts * 0.75 + sway * 0.3},
        {sx + ts * 0.15, sy + ts * 0.85 + sway * 0.5},
        {sx + ts * 0.85, sy + ts * 0.8 + sway * 0.2},
    }

    -- 辐射丝线
    for _, tip in ipairs(tips) do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, anchorX, anchorY)
        nvgBezierTo(nvg, (anchorX + tip[1]) * 0.5, anchorY + 3,
                    anchorX + 3, (anchorY + tip[2]) * 0.5,
                    tip[1], tip[2])
        nvgStrokeColor(nvg, nvgRGBA(200, 200, 210, 60))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end

    -- 同心弧线（蛛网环）
    for ring = 1, 3 do
        local r = ring * 0.22
        nvgBeginPath(nvg)
        for i, tip in ipairs(tips) do
            local px = anchorX + (tip[1] - anchorX) * r
            local py = anchorY + (tip[2] - anchorY) * r
            if i == 1 then
                nvgMoveTo(nvg, px, py)
            else
                nvgLineTo(nvg, px, py)
            end
        end
        nvgStrokeColor(nvg, nvgRGBA(200, 200, 210, 40))
        nvgStrokeWidth(nvg, 0.4)
        nvgStroke(nvg)
    end

    -- 中心小蜘蛛（可选点缀）
    nvgBeginPath(nvg)
    nvgCircle(nvg, anchorX + ts * 0.2, anchorY + ts * 0.2 + sway * 0.3, 2)
    nvgFillColor(nvg, nvgRGBA(60, 50, 40, 150))
    nvgFill(nvg)
end

-- ============================================================================
-- 蘑菇丛 - 几株大小不一的蘑菇
-- ============================================================================
function M.RenderMushroom(nvg, sx, sy, ts, d, time)
    local c = d.color or DEFAULT_COLOR_MUSHROOM
    local glow = math.sin(time * 1.5 + (d.x or 0) * 4) * 0.15 + 0.85

    -- 微弱发光（底部光晕）
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.7, ts * 0.35)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(15 * glow)))
    nvgFill(nvg)

    -- 3 株蘑菇
    local shrooms = MUSHROOM_DEFS

    for _, s in ipairs(shrooms) do
        local mx = sx + ts * s.x
        local my = sy + ts * s.y

        -- 菌柄（白色偏黄）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, mx - ts * 0.02, my - ts * s.stemH, ts * 0.04, ts * s.stemH, 1)
        nvgFillColor(nvg, nvgRGBA(220, 210, 190, 255))
        nvgFill(nvg)

        -- 菌盖（半圆，使用装饰物颜色）
        nvgBeginPath(nvg)
        nvgArc(nvg, mx, my - ts * s.stemH, ts * s.capR, math.pi, 0, NVG_CW)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(c[4] * glow)))
        nvgFill(nvg)

        -- 菌盖斑点
        nvgBeginPath(nvg)
        nvgCircle(nvg, mx - ts * s.capR * 0.3, my - ts * s.stemH - ts * s.capR * 0.3, 1.2)
        nvgFillColor(nvg, nvgRGBA(255, 255, 240, 120))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, mx + ts * s.capR * 0.4, my - ts * s.stemH - ts * s.capR * 0.15, 0.8)
        nvgFillColor(nvg, nvgRGBA(255, 255, 240, 100))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 发光水晶 - 多面体晶簇 + 脉动光芒
-- ============================================================================
function M.RenderCrystal(nvg, sx, sy, ts, d, time)
    local c = d.color or DEFAULT_COLOR_CRYSTAL
    local pulse = math.sin(time * 2.0 + (d.x or 0) * 3.7) * 0.25 + 0.75

    -- 外发光晕
    local glowPaint = nvgRadialGradient(nvg, sx + ts * 0.5, sy + ts * 0.55, ts * 0.05, ts * 0.5,
        nvgRGBA(c[1], c[2], c[3], math.floor(40 * pulse)),
        nvgRGBA(c[1], c[2], c[3], 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.55, ts * 0.5)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- 主晶体（最大，中间）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.42, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.35, sy + ts * 0.35)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.12)
    nvgLineTo(nvg, sx + ts * 0.58, sy + ts * 0.3)
    nvgLineTo(nvg, sx + ts * 0.58, sy + ts * 0.85)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * pulse)))
    nvgFill(nvg)

    -- 高光面
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.5, sy + ts * 0.12)
    nvgLineTo(nvg, sx + ts * 0.58, sy + ts * 0.3)
    nvgLineTo(nvg, sx + ts * 0.58, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.8)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(50 * pulse)))
    nvgFill(nvg)

    -- 左侧小晶体
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.22, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.2, sy + ts * 0.55)
    nvgLineTo(nvg, sx + ts * 0.3, sy + ts * 0.42)
    nvgLineTo(nvg, sx + ts * 0.35, sy + ts * 0.85)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(170 * pulse)))
    nvgFill(nvg)

    -- 右侧小晶体
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.65, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.68, sy + ts * 0.52)
    nvgLineTo(nvg, sx + ts * 0.75, sy + ts * 0.38)
    nvgLineTo(nvg, sx + ts * 0.78, sy + ts * 0.85)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(160 * pulse)))
    nvgFill(nvg)

    -- 边缘高光线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.35, sy + ts * 0.35)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.12)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(100 * pulse)))
    nvgStrokeWidth(nvg, 0.8)
    nvgStroke(nvg)
end

-- ============================================================================
-- 滴水石笋 - 洞顶垂下的锥形石柱 + 水滴动画
-- ============================================================================
function M.RenderStalactite(nvg, sx, sy, ts, d, time)
    -- 顶部基座（嵌入洞壁）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.2, sy + ts * 0.02, ts * 0.6, ts * 0.1, 2)
    nvgFillColor(nvg, nvgRGBA(90, 85, 80, 255))
    nvgFill(nvg)

    -- 主石笋体（从上往下渐细的锥形）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.25, sy + ts * 0.08)
    nvgLineTo(nvg, sx + ts * 0.75, sy + ts * 0.08)
    nvgLineTo(nvg, sx + ts * 0.6, sy + ts * 0.45)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.7)
    nvgLineTo(nvg, sx + ts * 0.4, sy + ts * 0.45)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(110, 105, 95, 255))
    nvgFill(nvg)

    -- 石笋纹理（横向色带）
    for i = 1, 3 do
        local ly = sy + ts * (0.12 + i * 0.12)
        local hw = ts * (0.22 - i * 0.04)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + ts * 0.5 - hw, ly)
        nvgLineTo(nvg, sx + ts * 0.5 + hw, ly)
        nvgStrokeColor(nvg, nvgRGBA(80, 75, 70, 60))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end

    -- 高光
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.55, sy + ts * 0.12)
    nvgLineTo(nvg, sx + ts * 0.52, sy + ts * 0.5)
    nvgStrokeColor(nvg, nvgRGBA(140, 135, 125, 80))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 水滴动画（周期性滴落）
    local dropCycle = (time * 0.5 + (d.x or 0) * 0.7) % 2.0
    if dropCycle < 1.0 then
        local dropY = sy + ts * 0.7 + dropCycle * ts * 0.25
        local dropAlpha = math.max(0, 1.0 - dropCycle)
        nvgBeginPath(nvg)
        -- 水滴形状（小椭圆）
        nvgEllipse(nvg, sx + ts * 0.5, dropY, 1.5, 2.5)
        nvgFillColor(nvg, nvgRGBA(150, 180, 220, math.floor(180 * dropAlpha)))
        nvgFill(nvg)
    end

    -- 尖端积水反光
    local glint = math.sin(time * 1.2 + (d.x or 0) * 5) * 0.3 + 0.7
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.68, 1.5)
    nvgFillColor(nvg, nvgRGBA(180, 200, 240, math.floor(100 * glint)))
    nvgFill(nvg)
end

-- ============================================================================
-- 残破战旗 (banner) - 修罗场战场遗迹
-- ============================================================================
function M.RenderBanner(nvg, sx, sy, ts, d, time)
    local color = d.color or DEFAULT_COLOR_BANNER
    local cx = sx + ts * 0.5
    -- 旗杆
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, sy + ts * 0.15)
    nvgLineTo(nvg, cx, sy + ts * 0.85)
    nvgStrokeColor(nvg, nvgRGBA(90, 75, 60, 230))
    nvgStrokeWidth(nvg, 2.5)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
    -- 旗杆顶端
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, sy + ts * 0.15, 2.5)
    nvgFillColor(nvg, nvgRGBA(110, 90, 70, 240))
    nvgFill(nvg)
    -- 残破旗面（带微弱飘动）
    local wave = math.sin(time * 1.5 + (d.x or 0) * 3.7) * 2
    local flagTop = sy + ts * 0.18
    local flagBot = sy + ts * 0.50
    local flagRight = cx + ts * 0.30 + wave
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, flagTop)
    nvgLineTo(nvg, flagRight, flagTop + (flagBot - flagTop) * 0.3)
    nvgLineTo(nvg, flagRight - 3, flagBot - 2)  -- 破损下沿
    nvgLineTo(nvg, cx + ts * 0.10, flagBot)      -- 撕裂口
    nvgLineTo(nvg, cx, flagBot - 4)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], 200))
    nvgFill(nvg)
    -- 旗面暗色条纹
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx + 2, flagTop + 5)
    nvgLineTo(nvg, flagRight - 5, flagTop + 10 + wave * 0.3)
    nvgStrokeColor(nvg, nvgRGBA(color[1] - 30, color[2] - 10, color[3] - 10, 120))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
end

-- ============================================================================
-- 骨堆 - 散落的白色骨骼
-- ============================================================================
function M.RenderBonePile(nvg, sx, sy, ts, d)
    -- 底部阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.78, ts * 0.32, ts * 0.08)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 25))
    nvgFill(nvg)

    -- 散落骨骼（长骨、肋骨风格的线条）
    local bones = BONE_PILE_DEFS

    for _, b in ipairs(bones) do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + ts * b[1], sy + ts * b[2])
        nvgLineTo(nvg, sx + ts * b[3], sy + ts * b[4])
        nvgStrokeColor(nvg, nvgRGBA(220, 210, 190, 240))
        nvgStrokeWidth(nvg, b[5])
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)

        -- 骨端球节
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx + ts * b[1], sy + ts * b[2], b[5] * 0.8)
        nvgFillColor(nvg, nvgRGBA(230, 220, 200, 240))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx + ts * b[3], sy + ts * b[4], b[5] * 0.7)
        nvgFillColor(nvg, nvgRGBA(225, 215, 195, 240))
        nvgFill(nvg)
    end

    -- 头骨（中央偏上）
    local skullX = sx + ts * 0.45
    local skullY = sy + ts * 0.42
    -- 头骨轮廓
    nvgBeginPath(nvg)
    nvgEllipse(nvg, skullX, skullY, ts * 0.08, ts * 0.07)
    nvgFillColor(nvg, nvgRGBA(235, 225, 205, 255))
    nvgFill(nvg)
    -- 眼窝
    nvgBeginPath(nvg)
    nvgCircle(nvg, skullX - 3, skullY - 1, 1.5)
    nvgFillColor(nvg, nvgRGBA(50, 40, 30, 200))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, skullX + 3, skullY - 1, 1.5)
    nvgFillColor(nvg, nvgRGBA(50, 40, 30, 200))
    nvgFill(nvg)
    -- 鼻腔
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, skullX, skullY + 1)
    nvgLineTo(nvg, skullX - 1, skullY + 3)
    nvgLineTo(nvg, skullX + 1, skullY + 3)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(60, 50, 40, 180))
    nvgFill(nvg)
end

-- ============================================================================
-- 枯树 - 灰白色无叶枯树 + 扭曲枝干
-- ============================================================================
function M.RenderDeadTree(nvg, sx, sy, ts, d, time)
    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.88, ts * 0.3, ts * 0.08)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 25))
    nvgFill(nvg)

    -- 树干（灰白色，扭曲）
    local trunkColor = {120, 110, 95, 255}
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.42, sy + ts * 0.88)
    nvgBezierTo(nvg, sx + ts * 0.38, sy + ts * 0.6,
                sx + ts * 0.48, sy + ts * 0.4,
                sx + ts * 0.45, sy + ts * 0.22)
    nvgLineTo(nvg, sx + ts * 0.55, sy + ts * 0.22)
    nvgBezierTo(nvg, sx + ts * 0.52, sy + ts * 0.4,
                sx + ts * 0.62, sy + ts * 0.6,
                sx + ts * 0.58, sy + ts * 0.88)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(trunkColor[1], trunkColor[2], trunkColor[3], 255))
    nvgFill(nvg)

    -- 树干裂纹
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.48, sy + ts * 0.4)
    nvgBezierTo(nvg, sx + ts * 0.46, sy + ts * 0.5, sx + ts * 0.5, sy + ts * 0.6, sx + ts * 0.47, sy + ts * 0.75)
    nvgStrokeColor(nvg, nvgRGBA(80, 70, 55, 100))
    nvgStrokeWidth(nvg, 0.8)
    nvgStroke(nvg)

    -- 枯枝（无叶，扭曲伸展）
    local branches = DEAD_TREE_BRANCHES

    for _, b in ipairs(branches) do
        local startX = sx + ts * b[1]
        local startY = sy + ts * b[2]
        local endX = sx + ts * b[3]
        local endY = sy + ts * b[4]

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, startX, startY)
        nvgBezierTo(nvg,
            (startX + endX) * 0.5, startY - 5,
            endX - 3, (startY + endY) * 0.5,
            endX, endY)
        nvgStrokeColor(nvg, nvgRGBA(trunkColor[1], trunkColor[2], trunkColor[3], 220))
        nvgStrokeWidth(nvg, b[5])
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)

        -- 枝端分叉
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, endX, endY)
        nvgLineTo(nvg, endX + 4, endY - 5)
        nvgStrokeColor(nvg, nvgRGBA(trunkColor[1], trunkColor[2], trunkColor[3], 160))
        nvgStrokeWidth(nvg, b[5] * 0.5)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 地裂/裂谷 - 地面上的深色裂缝
-- ============================================================================
function M.RenderCrack(nvg, sx, sy, ts, d)
    -- 主裂缝（Z字形深色线）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.1, sy + ts * 0.2)
    nvgLineTo(nvg, sx + ts * 0.35, sy + ts * 0.35)
    nvgLineTo(nvg, sx + ts * 0.25, sy + ts * 0.55)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.65)
    nvgLineTo(nvg, sx + ts * 0.45, sy + ts * 0.82)
    nvgLineTo(nvg, sx + ts * 0.7, sy + ts * 0.9)
    nvgStrokeColor(nvg, nvgRGBA(30, 25, 20, 200))
    nvgStrokeWidth(nvg, 3)
    nvgLineCap(nvg, NVG_ROUND)
    nvgLineJoin(nvg, NVG_ROUND)
    nvgStroke(nvg)

    -- 裂缝内部（更深的暗色线）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.12, sy + ts * 0.22)
    nvgLineTo(nvg, sx + ts * 0.35, sy + ts * 0.36)
    nvgLineTo(nvg, sx + ts * 0.26, sy + ts * 0.55)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.66)
    nvgLineTo(nvg, sx + ts * 0.46, sy + ts * 0.82)
    nvgLineTo(nvg, sx + ts * 0.68, sy + ts * 0.89)
    nvgStrokeColor(nvg, nvgRGBA(15, 10, 5, 255))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- 分支裂缝
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.35, sy + ts * 0.35)
    nvgLineTo(nvg, sx + ts * 0.55, sy + ts * 0.3)
    nvgStrokeColor(nvg, nvgRGBA(30, 25, 20, 150))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.5, sy + ts * 0.65)
    nvgLineTo(nvg, sx + ts * 0.72, sy + ts * 0.58)
    nvgStrokeColor(nvg, nvgRGBA(30, 25, 20, 130))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- 裂缝边缘碎石（使用确定性伪随机避免每帧闪烁）
    local debris = CRACK_DEBRIS
    for di, p in ipairs(debris) do
        -- 基于装饰坐标和碎石索引的确定性哈希，范围 0~1
        local hash = (((d.x or 0) * 73856093 + (d.y or 0) * 19349663 + di * 83492791) % 1000) / 1000
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx + ts * p[1], sy + ts * p[2], 1.5 + hash)
        nvgFillColor(nvg, nvgRGBA(80, 70, 55, 160))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 警示石碑 - 刻有文字的石头方碑
-- ============================================================================
function M.RenderStoneTablet(nvg, sx, sy, ts, d)
    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.88, ts * 0.3, ts * 0.07)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 25))
    nvgFill(nvg)

    -- 石碑基座
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.2, sy + ts * 0.78, ts * 0.6, ts * 0.12, 2)
    nvgFillColor(nvg, nvgRGBA(100, 95, 85, 255))
    nvgFill(nvg)

    -- 石碑主体（梯形，上窄下宽）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.25, sy + ts * 0.78)
    nvgLineTo(nvg, sx + ts * 0.3, sy + ts * 0.15)
    nvgLineTo(nvg, sx + ts * 0.7, sy + ts * 0.15)
    nvgLineTo(nvg, sx + ts * 0.75, sy + ts * 0.78)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(120, 115, 105, 255))
    nvgFill(nvg)

    -- 石碑顶部圆弧
    nvgBeginPath(nvg)
    nvgArc(nvg, sx + ts * 0.5, sy + ts * 0.15, ts * 0.2, math.pi, 0, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(125, 120, 110, 255))
    nvgFill(nvg)

    -- 石碑边框
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.25, sy + ts * 0.78)
    nvgLineTo(nvg, sx + ts * 0.3, sy + ts * 0.15)
    nvgArc(nvg, sx + ts * 0.5, sy + ts * 0.15, ts * 0.2, math.pi, 0, NVG_CW)
    nvgLineTo(nvg, sx + ts * 0.75, sy + ts * 0.78)
    nvgStrokeColor(nvg, nvgRGBA(80, 75, 65, 200))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- 风化纹理
    for i = 1, 3 do
        local ly = sy + ts * (0.25 + i * 0.12)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + ts * 0.32, ly)
        nvgLineTo(nvg, sx + ts * 0.68, ly)
        nvgStrokeColor(nvg, nvgRGBA(95, 90, 80, 40))
        nvgStrokeWidth(nvg, 0.5)
        nvgStroke(nvg)
    end

    -- 刻字
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.label)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        -- 刻字阴影（凹刻效果）
        nvgFillColor(nvg, nvgRGBA(60, 55, 45, 200))
        nvgText(nvg, sx + ts * 0.5 + 0.5, sy + ts * 0.48 + 0.5, d.label, nil)
        -- 刻字主体
        nvgFillColor(nvg, nvgRGBA(180, 170, 150, 255))
        nvgText(nvg, sx + ts * 0.5, sy + ts * 0.48, d.label, nil)
    end

    -- 苔藓斑点（石碑底部）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.35, sy + ts * 0.72, 4, 2.5)
    nvgFillColor(nvg, nvgRGBA(50, 90, 40, 80))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.65, sy + ts * 0.68, 3, 2)
    nvgFillColor(nvg, nvgRGBA(45, 85, 35, 60))
    nvgFill(nvg)
end

return M
