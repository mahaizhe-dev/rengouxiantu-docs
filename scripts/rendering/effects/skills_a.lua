-- ============================================================================
-- effects/skills_a.lua - 技能特效渲染器 A（金刚掌/伏魔刀/血海/浩气封印/金钟罩/龙象/三剑/巨剑）
-- ============================================================================

local shared = require("rendering.effects.shared")
local assets = require("rendering.effects.assets")

local GameState = shared.GameState
local SIGNS = shared.SIGNS

local M = {}

-- 模块级常量：如来神掌五指几何参数 {offsetX, offsetY, halfWidth, height}
local ICE_SLASH_FINGERS = {
    {-0.35, -0.5, 0.10, 0.30},
    {-0.17, -0.6, 0.11, 0.35},
    { 0.0,  -0.65, 0.12, 0.38},
    { 0.17, -0.6, 0.11, 0.35},
    { 0.38, -0.3, 0.10, 0.28},
}

-- 模块级常量：伏魔刀矩形局部坐标因子 {xFactor, yFactor}
-- 实际坐标 = {xFactor * rectLen, yFactor * halfW}
local BLOOD_SLASH_LOCAL_FACTORS = {
    {0, -1}, {1, -1},
    {1,  1}, {0,  1},
}

-- 模块级复用表：伏魔刀四角屏幕坐标（避免每帧 table.insert）
local bloodSlashCorners = {{0,0}, {0,0}, {0,0}, {0,0}}

local function renderIceSlash(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 金刚掌特效：身前圆形冲击波 + 掌印 + 金色气浪 ═══
    local cx, cy, hitRadius = shared.ResolveFrontCircleGeometry(se, sx, sy, baseAngle, tileSize)
    local radius = hitRadius * expand
    -- 冲击波圆环（从内向外扩散）
    local waveRadius = radius * (0.3 + 0.7 * progress)
    local waveAlpha = math.floor(200 * alpha * (1.0 - progress * 0.5))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, waveRadius)
    nvgStrokeColor(nvg, nvgRGBA(255, 200, 80, waveAlpha))
    nvgStrokeWidth(nvg, 3.5 * (1.0 - progress * 0.5))
    nvgStroke(nvg)
    -- 内圈金色光晕填充
    local innerR = radius * 0.7 * expand
    local glowPaint = nvgRadialGradient(nvg, cx, cy, 0, innerR,
        nvgRGBA(255, 215, 80, math.floor(100 * alpha)),
        nvgRGBA(255, 180, 40, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, innerR)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)
    -- 掌印（五指 + 掌心），在圆心位置
    local palmScale = tileSize * 0.35 * expand
    nvgSave(nvg)
    nvgTranslate(nvg, cx, cy)
    nvgRotate(nvg, baseAngle + math.pi / 2)
    local palmAlpha = math.floor(220 * alpha)
    -- 掌心圆
    nvgBeginPath(nvg)
    nvgEllipse(nvg, 0, palmScale * 0.1, palmScale * 0.5, palmScale * 0.55)
    nvgFillColor(nvg, nvgRGBA(255, 220, 100, math.floor(palmAlpha * 0.7)))
    nvgFill(nvg)
    -- 五根手指（常量表已提升到模块级）
    for _, f in ipairs(ICE_SLASH_FINGERS) do
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg,
            (f[1] - f[3]) * palmScale,
            f[2] * palmScale,
            f[3] * 2 * palmScale,
            f[4] * palmScale,
            f[3] * palmScale * 0.8)
        nvgFillColor(nvg, nvgRGBA(255, 210, 80, palmAlpha))
        nvgFill(nvg)
    end
    nvgRestore(nvg)
    -- 外围金色气浪弧线（围绕身前圆心扩散）
    for j = 0, 3 do
        local arcAngle = baseAngle + (j - 1.5) * 0.5
        local arcR = radius * (0.5 + 0.5 * progress)
        local arcLen = math.pi * 0.25
        nvgBeginPath(nvg)
        nvgArc(nvg, cx, cy, arcR, arcAngle - arcLen / 2, arcAngle + arcLen / 2, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(255, 200, 60, math.floor(160 * alpha * (1.0 - progress * 0.6))))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
    -- 震地裂纹（从圆心向外辐射）
    for j = 0, 5 do
        local crackAngle = baseAngle + (j / 6) * math.pi * 2
        local crackStart = radius * 0.15
        local crackEnd = radius * (0.3 + 0.4 * progress)
        local x1 = cx + math.cos(crackAngle) * crackStart
        local y1 = cy + math.sin(crackAngle) * crackStart
        local x2 = cx + math.cos(crackAngle) * crackEnd
        local y2 = cy + math.sin(crackAngle) * crackEnd
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x2, y2)
        nvgStrokeColor(nvg, nvgRGBA(200, 170, 50, math.floor(120 * alpha)))
        nvgStrokeWidth(nvg, 1.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
end

local function renderBloodSlash(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 伏魔刀特效：前方矩形区域 + 横斩线 + 吸血回流 ═══
    local rectLen = (se.rectLength or 2.0) * tileSize * expand
    local rectW = (se.rectWidth or 1.0) * tileSize * expand
    local halfW = rectW / 2
    local cosA = math.cos(baseAngle)
    local sinA = math.sin(baseAngle)
    -- 矩形四角（玩家位置为起点，复用模块级表）
    for ci = 1, 4 do
        local fac = BLOOD_SLASH_LOCAL_FACTORS[ci]
        local lx = fac[1] * rectLen
        local ly = fac[2] * halfW
        bloodSlashCorners[ci][1] = sx + lx * cosA - ly * sinA
        bloodSlashCorners[ci][2] = sy + lx * sinA + ly * cosA
    end
    -- 矩形填充（深红半透明）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bloodSlashCorners[1][1], bloodSlashCorners[1][2])
    for j = 2, 4 do
        nvgLineTo(nvg, bloodSlashCorners[j][1], bloodSlashCorners[j][2])
    end
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(70 * alpha)))
    nvgFill(nvg)
    -- 矩形边框（血红）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bloodSlashCorners[1][1], bloodSlashCorners[1][2])
    for j = 2, 4 do
        nvgLineTo(nvg, bloodSlashCorners[j][1], bloodSlashCorners[j][2])
    end
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 横斩线（3条横切纹，沿矩形宽度方向）
    for j = 1, 3 do
        local frac = j * 0.25
        local lx = sx + rectLen * frac * cosA
        local ly = sy + rectLen * frac * sinA
        local lx1 = lx - halfW * 0.85 * (-sinA)
        local ly1 = ly - halfW * 0.85 * cosA
        local lx2 = lx + halfW * 0.85 * (-sinA)
        local ly2 = ly + halfW * 0.85 * cosA
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx1, ly1)
        nvgLineTo(nvg, lx2, ly2)
        nvgStrokeColor(nvg, nvgRGBA(255, 80, 60, math.floor((140 - j * 20) * alpha)))
        nvgStrokeWidth(nvg, 2.5 - j * 0.3)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
    -- 吸血回流粒子（从矩形远端向玩家收缩）
    if progress > 0.2 then
        local returnProgress = (progress - 0.2) / 0.8
        for j = 0, 5 do
            local fwd = rectLen * (1.0 - returnProgress * 0.8) * ((j % 3 + 1) / 3.5)
            local lat = halfW * 0.7 * (j % 2 == 0 and -1 or 1) * (1.0 - returnProgress * 0.3)
            local px = sx + fwd * cosA - lat * sinA
            local py = sy + fwd * sinA + lat * cosA
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 2.0 * (1.0 - returnProgress * 0.5))
            nvgFillColor(nvg, nvgRGBA(255, 100, 100, math.floor(180 * alpha)))
            nvgFill(nvg)
        end
    end
end

local function renderBloodSeaAoe(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 血海翻涌特效：60度前方扇面 + 血气涟漪 + 血滴粒子 ═══
    local radius = se.range * tileSize * expand
    local halfAngle = math.rad((se.coneAngle or 60) / 2)
    local faceAngle = se.targetAngle or (se.facingRight and 0 or math.pi)
    -- 暗红扇面填充（血池效果）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy)
    nvgArc(nvg, sx, sy, radius, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
    nvgClosePath(nvg)
    local poolPaint = nvgRadialGradient(nvg, sx, sy, radius * 0.1, radius,
        nvgRGBA(c[1], c[2], c[3], math.floor(90 * alpha)),
        nvgRGBA(c[1], 0, 0, math.floor(30 * alpha)))
    nvgFillPaint(nvg, poolPaint)
    nvgFill(nvg)
    -- 扇面边缘描边
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy)
    nvgArc(nvg, sx, sy, radius, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 血气涟漪（3 圈扇形从中心向外扩散）
    for j = 0, 2 do
        local rippleP = math.fmod(progress + j * 0.33, 1.0)
        local rippleR = radius * (0.2 + 0.8 * rippleP)
        local rippleA = math.floor(160 * (1.0 - rippleP) * alpha)
        if rippleA > 0 then
            nvgBeginPath(nvg)
            nvgArc(nvg, sx, sy, rippleR, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
            nvgStrokeColor(nvg, nvgRGBA(200, 30, 30, rippleA))
            nvgStrokeWidth(nvg, 2.0 * (1.0 - rippleP * 0.6))
            nvgStroke(nvg)
        end
    end
    -- 血滴粒子（在扇面范围内飞散）
    for j = 0, 7 do
        local particleAngle = faceAngle - halfAngle + (j / 7) * halfAngle * 2
        particleAngle = particleAngle + math.sin(progress * 3.0 + j) * 0.15
        local dist = radius * (0.3 + 0.5 * math.fmod(progress * 2 + j * 0.12, 1.0))
        local px = sx + math.cos(particleAngle) * dist
        local py = sy + math.sin(particleAngle) * dist
        local pSize = 2.5 * (1.0 - progress * 0.5)
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pSize)
        nvgFillColor(nvg, nvgRGBA(220, 40, 40, math.floor(180 * alpha)))
        nvgFill(nvg)
    end
    -- 中心血色旋涡（沿扇面中线喷射）
    local swirlR = radius * 0.35 * expand
    nvgBeginPath(nvg)
    nvgArc(nvg, sx, sy, swirlR,
        faceAngle - halfAngle * 0.6 + progress * math.pi * 2,
        faceAngle + halfAngle * 0.6 + progress * math.pi * 2, NVG_CW)
    nvgStrokeColor(nvg, nvgRGBA(255, 60, 60, math.floor(200 * alpha)))
    nvgStrokeWidth(nvg, 3.0)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
end

local function renderHaoqiSealZone(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 浩气领域特效：青蓝色圆形 + 太极纹 + 气旋 ═══
    local radius = se.range * tileSize * expand
    -- 青蓝色地面圆（领域场效果）
    local zonePaint = nvgRadialGradient(nvg, sx, sy, radius * 0.05, radius,
        nvgRGBA(c[1], c[2], c[3], math.floor(80 * alpha)),
        nvgRGBA(40, 120, 200, math.floor(20 * alpha)))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgFillPaint(nvg, zonePaint)
    nvgFill(nvg)
    -- 外圈边框
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(220 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 太极图案（中心双鱼）
    local taijiR = radius * 0.25 * expand
    local rotAngle = progress * math.pi * 3  -- 旋转动画
    nvgSave(nvg)
    nvgTranslate(nvg, sx, sy)
    nvgRotate(nvg, rotAngle)
    -- 阴鱼（暗蓝半圆）
    nvgBeginPath(nvg)
    nvgArc(nvg, 0, 0, taijiR, math.pi * 0.5, math.pi * 1.5, NVG_CW)
    nvgArc(nvg, 0, -taijiR * 0.5, taijiR * 0.5, math.pi * 1.5, math.pi * 0.5, NVG_CCW)
    nvgArc(nvg, 0, taijiR * 0.5, taijiR * 0.5, math.pi * 1.5, math.pi * 0.5, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(40, 100, 180, math.floor(150 * alpha)))
    nvgFill(nvg)
    -- 阳鱼（亮青半圆）
    nvgBeginPath(nvg)
    nvgArc(nvg, 0, 0, taijiR, math.pi * 1.5, math.pi * 0.5, NVG_CW)
    nvgArc(nvg, 0, taijiR * 0.5, taijiR * 0.5, math.pi * 0.5, math.pi * 1.5, NVG_CCW)
    nvgArc(nvg, 0, -taijiR * 0.5, taijiR * 0.5, math.pi * 0.5, math.pi * 1.5, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(120, 230, 255, math.floor(150 * alpha)))
    nvgFill(nvg)
    -- 鱼眼
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, -taijiR * 0.5, taijiR * 0.12)
    nvgFillColor(nvg, nvgRGBA(120, 230, 255, math.floor(200 * alpha)))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, taijiR * 0.5, taijiR * 0.12)
    nvgFillColor(nvg, nvgRGBA(40, 100, 180, math.floor(200 * alpha)))
    nvgFill(nvg)
    nvgRestore(nvg)
    -- 外围气旋弧线（旋转）
    for j = 0, 3 do
        local arcBaseAngle = rotAngle + j * math.pi * 0.5
        local arcR = radius * (0.6 + 0.2 * math.sin(progress * math.pi * 4 + j))
        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, arcR, arcBaseAngle, arcBaseAngle + math.pi * 0.3, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(140 * alpha * (0.6 + 0.4 * math.sin(progress * 6 + j)))))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
end

local function renderGoldenBell(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 金钟罩特效：钟形护盾 + 金色涟漪 ═══
    local bellH = tileSize * 1.3 * expand
    local bellW = tileSize * 0.9 * expand
    -- 金色光柱（从下向上）
    local pillarAlpha = math.floor(150 * alpha * (1.0 - progress * 0.7))
    local pillarPaint = nvgLinearGradient(nvg,
        sx, sy + bellH * 0.3,
        sx, sy - bellH * 0.5,
        nvgRGBA(255, 200, 50, pillarAlpha),
        nvgRGBA(255, 220, 100, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx - bellW * 0.3, sy - bellH * 0.5, bellW * 0.6, bellH * 0.8)
    nvgFillPaint(nvg, pillarPaint)
    nvgFill(nvg)
    -- 钟形轮廓（椭圆顶 + 梯形体）
    local bellAlpha = math.floor(220 * alpha)
    nvgBeginPath(nvg)
    -- 钟顶弧线
    nvgArc(nvg, sx, sy - bellH * 0.25, bellW * 0.45,
        math.pi + 0.3, -0.3, NVG_CW)
    -- 右侧弧线向下展开
    nvgBezierTo(nvg,
        sx + bellW * 0.5, sy - bellH * 0.1,
        sx + bellW * 0.55, sy + bellH * 0.2,
        sx + bellW * 0.5, sy + bellH * 0.35)
    -- 底部弧线
    nvgBezierTo(nvg,
        sx + bellW * 0.45, sy + bellH * 0.4,
        sx - bellW * 0.45, sy + bellH * 0.4,
        sx - bellW * 0.5, sy + bellH * 0.35)
    -- 左侧弧线向上收
    nvgBezierTo(nvg,
        sx - bellW * 0.55, sy + bellH * 0.2,
        sx - bellW * 0.5, sy - bellH * 0.1,
        sx - bellW * 0.45, sy - bellH * 0.25 + 0.3)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(255, 215, 80, bellAlpha))
    nvgStrokeWidth(nvg, 3)
    nvgStroke(nvg)
    -- 半透明金色填充
    nvgFillColor(nvg, nvgRGBA(255, 215, 80, math.floor(50 * alpha)))
    nvgFill(nvg)
    -- 钟顶小圆钮
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy - bellH * 0.35, bellW * 0.08)
    nvgFillColor(nvg, nvgRGBA(255, 230, 120, bellAlpha))
    nvgFill(nvg)
    -- 向外扩散的金色涟漪环
    for j = 0, 2 do
        local ringProgress = math.fmod(progress + j * 0.33, 1.0)
        local ringR = (bellW * 0.5 + tileSize * 0.8 * ringProgress)
        local ringA = math.floor(160 * (1.0 - ringProgress) * alpha)
        if ringA > 0 then
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, ringR)
            nvgStrokeColor(nvg, nvgRGBA(255, 215, 80, ringA))
            nvgStrokeWidth(nvg, 1.5 * (1.0 - ringProgress * 0.5))
            nvgStroke(nvg)
        end
    end
end

local function renderDragonElephant(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 龙象功特效：正面象头图腾（参考佛教象头线稿） ═══
    local S = tileSize * 2.4 * expand
    local headAlpha = math.floor(225 * alpha)
    local cy = sy - S * 0.05  -- 整体上移一点，给鼻子留空间
    local lw = 2.8  -- 主线宽
    local lwThin = 1.5  -- 细线宽
    local gold = function(a) return nvgRGBA(215, 190, 110, math.floor(a * alpha)) end
    local goldBright = function(a) return nvgRGBA(245, 225, 150, math.floor(a * alpha)) end

    -- ── 佛光（头顶圆形光晕） ──
    local haloA = math.floor(90 * alpha * (0.6 + 0.4 * math.sin(progress * math.pi * 2)))
    local haloPaint = nvgRadialGradient(nvg,
        sx, cy - S * 0.42, S * 0.08, S * 0.35,
        nvgRGBA(255, 225, 140, haloA),
        nvgRGBA(255, 200, 80, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, cy - S * 0.38, S * 0.34)
    nvgFillPaint(nvg, haloPaint)
    nvgFill(nvg)

    -- ── 盾形大耳（棱角分明的五边形，如参考图） ──
    for side = -1, 1, 2 do
        nvgBeginPath(nvg)
        -- 5个关键点构成盾形耳：
        -- P1: 耳根上（连接头顶侧）
        -- P2: 耳上外角（向外上翘）
        -- P3: 耳最外侧尖角
        -- P4: 耳下外角
        -- P5: 耳根下（连接头下侧）
        local p1x = sx + side * S * 0.16
        local p1y = cy - S * 0.28
        local p2x = sx + side * S * 0.48
        local p2y = cy - S * 0.32
        local p3x = sx + side * S * 0.58
        local p3y = cy - S * 0.10
        local p4x = sx + side * S * 0.45
        local p4y = cy + S * 0.16
        local p5x = sx + side * S * 0.15
        local p5y = cy + S * 0.08
        nvgMoveTo(nvg, p1x, p1y)
        -- P1→P2 上边：微弧向外上
        nvgBezierTo(nvg, sx + side * S * 0.28, p1y - S * 0.06, sx + side * S * 0.40, p2y - S * 0.02, p2x, p2y)
        -- P2→P3 外上→外侧尖：直线感
        nvgBezierTo(nvg, sx + side * S * 0.54, p2y + S * 0.04, p3x + side * S * 0.01, p3y - S * 0.06, p3x, p3y)
        -- P3→P4 外侧→外下角：直线感
        nvgBezierTo(nvg, p3x - side * S * 0.01, p3y + S * 0.08, p4x + side * S * 0.02, p4y - S * 0.04, p4x, p4y)
        -- P4→P5 下边：微弧收回
        nvgBezierTo(nvg, sx + side * S * 0.32, p4y + S * 0.04, sx + side * S * 0.22, p5y + S * 0.02, p5x, p5y)
        nvgClosePath(nvg)
        nvgStrokeColor(nvg, gold(headAlpha))
        nvgStrokeWidth(nvg, lw)
        nvgLineJoin(nvg, NVG_ROUND)
        nvgStroke(nvg)
        -- 耳面填充
        nvgFillColor(nvg, nvgRGBA(240, 230, 200, math.floor(25 * alpha)))
        nvgFill(nvg)
        -- 耳内装饰线（从内侧描一条平行轮廓）
        nvgBeginPath(nvg)
        local s2 = 0.72  -- 内轮廓缩放
        local ecx = (p1x + p3x) * 0.5
        local ecy = (p1y + p4y) * 0.5
        local function earInner(px, py) return ecx + (px - ecx) * s2, ecy + (py - ecy) * s2 end
        local i1x, i1y = earInner(p1x, p1y)
        local i2x, i2y = earInner(p2x, p2y)
        local i3x, i3y = earInner(p3x, p3y)
        local i4x, i4y = earInner(p4x, p4y)
        local i5x, i5y = earInner(p5x, p5y)
        nvgMoveTo(nvg, i1x, i1y)
        nvgLineTo(nvg, i2x, i2y)
        nvgLineTo(nvg, i3x, i3y)
        nvgLineTo(nvg, i4x, i4y)
        nvgLineTo(nvg, i5x, i5y)
        nvgStrokeColor(nvg, gold(70))
        nvgStrokeWidth(nvg, lwThin)
        nvgStroke(nvg)
    end

    -- ── 面部轮廓（倒三角/盾形，上宽下尖） ──
    nvgBeginPath(nvg)
    -- 用贝塞尔构建倒三角脸型：额宽→颧→下巴尖
    local faceTopW = S * 0.18  -- 额头半宽
    local faceMidW = S * 0.16  -- 颧骨半宽
    local faceTop = cy - S * 0.30  -- 额顶
    local faceMid = cy + S * 0.02  -- 颧骨
    local faceBot = cy + S * 0.22  -- 下巴尖
    nvgMoveTo(nvg, sx, faceTop - S * 0.08)  -- 额顶尖（冠顶）
    -- 额顶→右额角
    nvgBezierTo(nvg, sx + S * 0.04, faceTop - S * 0.06, sx + faceTopW - S * 0.04, faceTop + S * 0.02, sx + faceTopW, faceTop + S * 0.04)
    -- 右额→右颧
    nvgBezierTo(nvg, sx + faceTopW + S * 0.02, faceMid - S * 0.10, sx + faceMidW + S * 0.02, faceMid - S * 0.04, sx + faceMidW, faceMid)
    -- 右颧→下巴
    nvgBezierTo(nvg, sx + faceMidW - S * 0.01, faceMid + S * 0.08, sx + S * 0.04, faceBot - S * 0.04, sx, faceBot)
    -- 下巴→左颧
    nvgBezierTo(nvg, sx - S * 0.04, faceBot - S * 0.04, sx - faceMidW + S * 0.01, faceMid + S * 0.08, sx - faceMidW, faceMid)
    -- 左颧→左额
    nvgBezierTo(nvg, sx - faceMidW - S * 0.02, faceMid - S * 0.04, sx - faceTopW - S * 0.02, faceMid - S * 0.10, sx - faceTopW, faceTop + S * 0.04)
    -- 左额→额顶
    nvgBezierTo(nvg, sx - faceTopW + S * 0.04, faceTop + S * 0.02, sx - S * 0.04, faceTop - S * 0.06, sx, faceTop - S * 0.08)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, gold(headAlpha))
    nvgStrokeWidth(nvg, lw + 0.5)
    nvgStroke(nvg)
    -- 面部填充
    local headFill = nvgRadialGradient(nvg,
        sx, cy - S * 0.10, S * 0.04, S * 0.30,
        nvgRGBA(250, 242, 220, math.floor(70 * alpha)),
        nvgRGBA(225, 205, 155, math.floor(15 * alpha)))
    nvgFillPaint(nvg, headFill)
    nvgFill(nvg)

    -- ── 额顶冠饰（V形尖冠 + 中央竖线） ──
    -- 中央竖脊线（从冠顶到鼻梁）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, faceTop - S * 0.06)
    nvgLineTo(nvg, sx, cy + S * 0.06)
    nvgStrokeColor(nvg, gold(120))
    nvgStrokeWidth(nvg, lwThin)
    nvgStroke(nvg)
    -- 额头V纹（从中央向两侧展开的装饰线）
    for side = -1, 1, 2 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx, faceTop)
        nvgBezierTo(nvg,
            sx + side * S * 0.04, faceTop + S * 0.06,
            sx + side * S * 0.10, faceTop + S * 0.10,
            sx + side * S * 0.13, faceTop + S * 0.16)
        nvgStrokeColor(nvg, gold(100))
        nvgStrokeWidth(nvg, lwThin)
        nvgStroke(nvg)
    end

    -- ── 额间宝珠（圆形白毫） ──
    local jewY = cy - S * 0.18
    local jewelGlow = nvgRadialGradient(nvg,
        sx, jewY, S * 0.01, S * 0.055,
        nvgRGBA(255, 245, 200, math.floor(150 * alpha)),
        nvgRGBA(255, 230, 160, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, jewY, S * 0.055)
    nvgFillPaint(nvg, jewelGlow)
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, jewY, S * 0.022)
    nvgFillColor(nvg, nvgRGBA(255, 248, 220, math.floor(230 * alpha)))
    nvgFill(nvg)
    nvgStrokeColor(nvg, gold(180))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ── 眼睛（面部两侧，半闭垂目弧线） ──
    for side = -1, 1, 2 do
        local eyeX = sx + side * S * 0.085
        local eyeY = cy - S * 0.06
        -- 上眼线
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, eyeX - side * S * 0.01, eyeY - S * 0.008)
        nvgBezierTo(nvg,
            eyeX + side * S * 0.015, eyeY - S * 0.020,
            eyeX + side * S * 0.035, eyeY - S * 0.015,
            eyeX + side * S * 0.05, eyeY + S * 0.002)
        nvgStrokeColor(nvg, gold(headAlpha))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
        -- 下眼线
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, eyeX - side * S * 0.005, eyeY)
        nvgBezierTo(nvg,
            eyeX + side * S * 0.015, eyeY + S * 0.012,
            eyeX + side * S * 0.035, eyeY + S * 0.010,
            eyeX + side * S * 0.048, eyeY + S * 0.004)
        nvgStrokeColor(nvg, gold(140))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
        -- 眼周装饰弧（从眼尾向外延伸的流线）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, eyeX + side * S * 0.05, eyeY)
        nvgBezierTo(nvg,
            eyeX + side * S * 0.07, eyeY + S * 0.02,
            eyeX + side * S * 0.09, eyeY + S * 0.05,
            eyeX + side * S * 0.10, eyeY + S * 0.09)
        nvgStrokeColor(nvg, gold(70))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)
    end

    -- ── 象鼻（粗壮居中，长垂，末端卷曲如参考图） ──
    -- 左轮廓
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx - S * 0.045, cy + S * 0.10)
    nvgBezierTo(nvg,
        sx - S * 0.065, cy + S * 0.22,
        sx - S * 0.055, cy + S * 0.36,
        sx - S * 0.035, cy + S * 0.48)
    nvgBezierTo(nvg,
        sx - S * 0.02, cy + S * 0.54,
        sx + S * 0.01, cy + S * 0.58,
        sx + S * 0.05, cy + S * 0.56)
    nvgStrokeColor(nvg, gold(headAlpha))
    nvgStrokeWidth(nvg, lw)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
    -- 右轮廓
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + S * 0.045, cy + S * 0.10)
    nvgBezierTo(nvg,
        sx + S * 0.065, cy + S * 0.22,
        sx + S * 0.055, cy + S * 0.36,
        sx + S * 0.035, cy + S * 0.48)
    nvgBezierTo(nvg,
        sx + S * 0.025, cy + S * 0.52,
        sx + S * 0.03, cy + S * 0.55,
        sx + S * 0.05, cy + S * 0.56)
    nvgStrokeColor(nvg, gold(headAlpha))
    nvgStrokeWidth(nvg, lw)
    nvgStroke(nvg)
    -- 鼻纹横纹（5条）
    for k = 1, 5 do
        local ny = cy + S * (0.16 + k * 0.06)
        local hw = S * (0.042 - k * 0.004)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx - hw, ny)
        nvgLineTo(nvg, sx + hw, ny)
        nvgStrokeColor(nvg, gold(50))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end
    -- 鼻梁中线（装饰）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, cy + S * 0.12)
    nvgBezierTo(nvg,
        sx, cy + S * 0.28,
        sx - S * 0.005, cy + S * 0.40,
        sx, cy + S * 0.50)
    nvgStrokeColor(nvg, gold(60))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ── 象牙（从面颊两侧伸出，向外弯曲） ──
    for side = -1, 1, 2 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + side * S * 0.10, cy + S * 0.08)
        nvgBezierTo(nvg,
            sx + side * S * 0.18, cy + S * 0.12,
            sx + side * S * 0.24, cy + S * 0.22,
            sx + side * S * 0.22, cy + S * 0.38)
        nvgStrokeColor(nvg, nvgRGBA(245, 240, 218, headAlpha))
        nvgStrokeWidth(nvg, lw + 0.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end

    -- ── 面部装饰流线（颧骨→下颌的曲线纹饰，如参考图） ──
    for side = -1, 1, 2 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + side * S * 0.14, cy - S * 0.12)
        nvgBezierTo(nvg,
            sx + side * S * 0.15, cy - S * 0.02,
            sx + side * S * 0.12, cy + S * 0.08,
            sx + side * S * 0.07, cy + S * 0.14)
        nvgStrokeColor(nvg, gold(65))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)
    end

    -- ── 金色 AOE 涟漪环 ──
    for j = 0, 2 do
        local ringProgress = math.fmod(progress + j * 0.33, 1.0)
        local ringR = (S * 0.3 + tileSize * 1.8 * ringProgress)
        local ringA = math.floor(150 * (1.0 - ringProgress) * alpha)
        if ringA > 0 then
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, ringR)
            nvgStrokeColor(nvg, nvgRGBA(220, 195, 100, ringA))
            nvgStrokeWidth(nvg, 2.0 * (1.0 - ringProgress * 0.5))
            nvgStroke(nvg)
        end
    end
end

local function renderThreeSwords(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 三剑式特效：读取 swordCount/coneAngle，保证表现与判定一致 ═══
    local radius = se.range * tileSize * expand
    local swordCount = se.swordCount or 3
    local halfAngle = math.rad((se.coneAngle or 60) / 2)
    local faceAngle = se.targetAngle or (se.facingRight and 0 or math.pi)
    local swordImg = assets.GetSwordImage(nvg)
    local isGreat = se.effectVariant == "great_break_sword"
    local swordSize = tileSize * (isGreat and 1.55 or 1.3)
    for j = 1, swordCount do
        local t = swordCount == 1 and 0 or ((j - 1) / (swordCount - 1) * 2 - 1)
        local swordAngle = faceAngle + t * halfAngle * 0.85
        local swordDist = radius * (0.3 + 0.7 * progress)
        local cx = sx + math.cos(swordAngle) * swordDist
        local cy = sy + math.sin(swordAngle) * swordDist
        if swordImg then
            nvgSave(nvg)
            nvgTranslate(nvg, cx, cy)
            nvgRotate(nvg, swordAngle)
            local half = swordSize / 2
            -- 外发光（加法混合，半透明放大版）
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local glowS = swordSize * (isGreat and 1.75 or 1.4)
            local glowH = glowS / 2
            local glowPaint = nvgImagePattern(nvg, -glowH, -glowH, glowS, glowS, 0, swordImg, (isGreat and 0.45 or 0.3) * alpha)
            nvgBeginPath(nvg)
            nvgRect(nvg, -glowH, -glowH, glowS, glowS)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
            -- 剑身图片
            local imgPaint = nvgImagePattern(nvg, -half, -half, swordSize, swordSize, 0, swordImg, alpha)
            nvgBeginPath(nvg)
            nvgRect(nvg, -half, -half, swordSize, swordSize)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
            -- 剑尖光点
            nvgBeginPath(nvg)
            nvgCircle(nvg, half * 0.7, 0, 4.0 * (1.0 - progress * 0.3))
            nvgFillColor(nvg, nvgRGBA(220, 240, 255, math.floor(255 * alpha)))
            nvgFill(nvg)
            nvgRestore(nvg)
        end
    end
    if isGreat then
        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, radius * 0.92, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(210, 245, 255, math.floor(170 * alpha)))
        nvgStrokeWidth(nvg, 3.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
end

local function renderGiantSword(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 奔雷式特效：落地AOE冲击波（电剑本体由剑阵出生动画渲染） ═══
    -- 技能整体效果：电剑从天而降→落地AOE伤害→停留为剑阵持续电击
    -- 此处只渲染落地时的AOE冲击波，电剑落下视觉由 RenderSwordFormations 的出生动画统一处理
    local radius = se.range * tileSize * expand
    local faceAngle = se.targetAngle or (se.facingRight and 0 or math.pi)
    -- 偏移中心到角色身前（偏移 range*1.0，让圆完全在身前）
    local offsetDist = se.range * tileSize * 1.0
    local cx = sx + math.cos(faceAngle) * offsetDist
    local cy = sy + math.sin(faceAngle) * offsetDist

    -- ═══ 落地冲击闪白（瞬间白光冲击） ═══
    if progress > 0.15 and progress < 0.35 then
        local flashT = (progress - 0.15) / 0.20
        local flashA = math.floor(120 * alpha * (1.0 - flashT))
        local flashR = radius * (0.3 + 0.7 * flashT)
        local flashPaint = nvgRadialGradient(nvg, cx, cy, 0, flashR,
            nvgRGBA(220, 240, 255, flashA),
            nvgRGBA(220, 240, 255, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, flashR)
        nvgFillPaint(nvg, flashPaint)
        nvgFill(nvg)
    end

    -- ═══ 冲击波（落地瞬间爆发） ═══
    if progress > 0.18 then
        local waveProgress = math.min(1.0, (progress - 0.18) / 0.50)
        -- 三次方 easeOut，快速爆开然后减速
        local waveT = 1.0 - (1.0 - waveProgress) * (1.0 - waveProgress) * (1.0 - waveProgress)
        -- 冲击波环1（主环，更粗）
        local waveR1 = radius * (0.1 + 0.9 * waveT)
        local waveA1 = math.floor(240 * alpha * (1.0 - waveProgress * 0.85))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, waveR1)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveA1))
        nvgStrokeWidth(nvg, 5.0 * (1.0 - waveProgress * 0.4))
        nvgStroke(nvg)
        -- 冲击波环2（内环，延迟展开）
        if waveProgress > 0.1 then
            local innerP = (waveProgress - 0.1) / 0.9
            local waveR2 = radius * (0.05 + 0.65 * innerP)
            local waveA2 = math.floor(180 * alpha * (1.0 - innerP))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, waveR2)
            nvgStrokeColor(nvg, nvgRGBA(200, 230, 255, waveA2))
            nvgStrokeWidth(nvg, 3.0 * (1.0 - innerP * 0.4))
            nvgStroke(nvg)
        end
        -- 冲击波环3（外环，更大更淡）
        if waveProgress > 0.05 then
            local outerP = (waveProgress - 0.05) / 0.95
            local waveR3 = radius * (0.2 + 1.0 * outerP)
            local waveA3 = math.floor(100 * alpha * (1.0 - outerP))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, waveR3)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveA3))
            nvgStrokeWidth(nvg, 2.0 * (1.0 - outerP * 0.5))
            nvgStroke(nvg)
        end
        -- 范围填充（冲击扩散底色）
        local fillA = math.floor(60 * alpha * (1.0 - waveProgress * 0.7))
        local fillPaint = nvgRadialGradient(nvg, cx, cy, radius * 0.05, radius * waveT,
            nvgRGBA(c[1], c[2], c[3], fillA),
            nvgRGBA(c[1], c[2], c[3], 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius * waveT)
        nvgFillPaint(nvg, fillPaint)
        nvgFill(nvg)
    end
end

-- Export partial registry
M.registry = {
    ["ice_slash"]       = renderIceSlash,
    ["blood_slash"]     = renderBloodSlash,
    ["blood_sea_aoe"]   = renderBloodSeaAoe,
    ["haoqi_seal_zone"] = renderHaoqiSealZone,
    ["golden_bell"]     = renderGoldenBell,
    ["dragon_elephant"] = renderDragonElephant,
    ["three_swords"]    = renderThreeSwords,
    ["giant_sword"]     = renderGiantSword,
}

return M
