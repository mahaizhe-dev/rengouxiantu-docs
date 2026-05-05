-- ============================================================================
-- DecoDivine.lua  —— 仙界装饰物渲染（神器 + 法器 + 试炼塔 + 悟道树）
-- 从 DecorationRenderers.lua 纯剥离，零逻辑修改
-- ============================================================================
local RenderUtils = require("rendering.RenderUtils")

local M = {}

-- ============================================================================
-- 模块级延迟加载图片句柄
-- ============================================================================
local divineRakeImage_ = nil
local divineRakeImageLoaded_ = false

local divineBaguaImage_ = nil
local divineBaguaImageLoaded_ = false

-- ============================================================================
-- 上宝逊金钯（虚幻态）- 图片 + 呼吸光效 + 光柱 + 旋转粒子
-- ============================================================================
function M.RenderDivineRake(nvg, sx, sy, ts, d, time)
    -- 延迟加载图片
    if not divineRakeImageLoaded_ then
        divineRakeImageLoaded_ = true
        divineRakeImage_ = RenderUtils.GetCachedImage(nvg, "divine_rake_20260312143058.png")
    end

    local cx = sx + ts * 0.5
    -- 呼吸脉动
    local breath = math.sin(time * 1.8) * 0.3 + 0.7  -- 0.4~1.0
    local baseAlpha = math.floor(140 + breath * 80)    -- 140~220

    -- ① 底部大光圈（地面承托光效）
    local glowR = ts * 0.7 + math.sin(time * 2.2) * ts * 0.08
    local glowPaint = nvgRadialGradient(nvg,
        cx, sy + ts * 0.9, ts * 0.08, glowR,
        nvgRGBA(255, 215, 0, math.floor(baseAlpha * 0.35)),
        nvgRGBA(255, 180, 0, 0))
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, sy + ts * 0.9, glowR, glowR * 0.35)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- ② 向上光柱（虚幻感）
    local pillarW = ts * 0.3 + math.sin(time * 1.5) * ts * 0.04
    local pillarH = ts * 2.2
    local pillarPaint = nvgLinearGradient(nvg,
        cx, sy - pillarH * 0.4, cx, sy + ts * 0.8,
        nvgRGBA(255, 230, 100, 0),
        nvgRGBA(255, 215, 50, math.floor(baseAlpha * 0.18)))
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - pillarW * 0.5, sy - pillarH * 0.4, pillarW, pillarH * 0.8)
    nvgFillPaint(nvg, pillarPaint)
    nvgFill(nvg)

    -- ③ 钉耙图片（比 NPC 更大：宽 1.8ts，高 2.7ts）
    if divineRakeImage_ then
        local imgW = ts * 1.8
        local imgH = ts * 2.7
        local imgX = cx - imgW * 0.5
        local imgY = sy - imgH * 0.6
        -- 虚幻半透明
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgW, imgH, 0, divineRakeImage_, baseAlpha / 255.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, imgW, imgH)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
        -- 叠加金色辉光层
        local glowAlpha = math.floor(30 + math.sin(time * 2.5) * 20)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, imgW, imgH)
        nvgFillColor(nvg, nvgRGBA(255, 220, 80, glowAlpha))
        nvgFill(nvg)
    end

    -- ④ 旋转光粒子环（围绕钉耙旋转）
    local sparkAlpha = math.floor(60 + math.sin(time * 3.5) * 40)
    for i = 1, 5 do
        local angle = time * 0.8 + i * 1.2566  -- 72度间隔
        local distX = ts * 0.55 + math.sin(time * 1.6 + i * 2.0) * ts * 0.1
        local distY = ts * 0.4 + math.cos(time * 1.3 + i * 1.7) * ts * 0.15
        local px = cx + math.cos(angle) * distX
        local py = sy + ts * 0.2 + math.sin(angle) * distY
        local pr = ts * 0.025 + math.sin(time * 4.0 + i * 1.5) * ts * 0.012
        -- 光晕
        local sparkGlow = nvgRadialGradient(nvg,
            px, py, 0, pr * 3,
            nvgRGBA(255, 240, 120, sparkAlpha),
            nvgRGBA(255, 200, 50, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pr * 3)
        nvgFillPaint(nvg, sparkGlow)
        nvgFill(nvg)
        -- 核心亮点
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pr)
        nvgFillColor(nvg, nvgRGBA(255, 255, 200, math.min(255, sparkAlpha + 80)))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 文王八卦盘（第四章神器 · 悬浮圆盘 + 蓝色光效 + 旋转卦象）
-- ============================================================================
function M.RenderDivineBagua(nvg, sx, sy, ts, d, time)
    -- 延迟加载图片
    if not divineBaguaImageLoaded_ then
        divineBaguaImageLoaded_ = true
        divineBaguaImage_ = RenderUtils.GetCachedImage(nvg, "image/divine_bagua_20260403152445.png")
    end

    local cx = sx + ts * 0.5
    -- 呼吸脉动（蓝色调）
    local breath = math.sin(time * 1.5) * 0.3 + 0.7  -- 0.4~1.0
    local baseAlpha = math.floor(140 + breath * 80)    -- 140~220

    -- ① 底部大光圈（地面承托光效，蓝色调）
    local glowR = ts * 0.8 + math.sin(time * 2.0) * ts * 0.08
    local glowPaint = nvgRadialGradient(nvg,
        cx, sy + ts * 0.85, ts * 0.08, glowR,
        nvgRGBA(80, 160, 255, math.floor(baseAlpha * 0.35)),
        nvgRGBA(40, 100, 200, 0))
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, sy + ts * 0.85, glowR, glowR * 0.35)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- ② 向上光柱（蓝色虚幻感）
    local pillarW = ts * 0.35 + math.sin(time * 1.3) * ts * 0.04
    local pillarH = ts * 2.5
    local pillarPaint = nvgLinearGradient(nvg,
        cx, sy - pillarH * 0.4, cx, sy + ts * 0.8,
        nvgRGBA(100, 180, 255, 0),
        nvgRGBA(80, 150, 255, math.floor(baseAlpha * 0.15)))
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - pillarW * 0.5, sy - pillarH * 0.4, pillarW, pillarH * 0.8)
    nvgFillPaint(nvg, pillarPaint)
    nvgFill(nvg)

    -- ③ 八卦盘图片（圆形，比 NPC 更大：2.0ts × 2.0ts）
    if divineBaguaImage_ then
        local imgW = ts * 2.0
        local imgH = ts * 2.0
        local imgX = cx - imgW * 0.5
        local imgY = sy - imgH * 0.55
        -- 半透明悬浮
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgW, imgH, 0, divineBaguaImage_, baseAlpha / 255.0)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, imgY + imgH * 0.5, imgW * 0.5)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
        -- 叠加蓝色辉光层
        local glowAlpha = math.floor(20 + math.sin(time * 2.5) * 15)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, imgY + imgH * 0.5, imgW * 0.5)
        nvgFillColor(nvg, nvgRGBA(80, 160, 255, glowAlpha))
        nvgFill(nvg)
    end

    -- ④ 旋转八卦符号环（8个卦象围绕圆盘缓慢旋转）
    local symbolAlpha = math.floor(100 + math.sin(time * 2.0) * 50)
    local symbols = {"☰", "☱", "☲", "☳", "☴", "☵", "☶", "☷"}
    local ringR = ts * 0.65
    for i = 1, 8 do
        local angle = time * 0.3 + (i - 1) * (math.pi * 2 / 8)
        local px = cx + math.cos(angle) * ringR
        local py = sy + ts * 0.15 + math.sin(angle) * ringR * 0.4  -- 椭圆轨道
        -- 符号光晕
        local sparkGlow = nvgRadialGradient(nvg,
            px, py, 0, ts * 0.08,
            nvgRGBA(100, 200, 255, symbolAlpha),
            nvgRGBA(60, 140, 220, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, ts * 0.08)
        nvgFillPaint(nvg, sparkGlow)
        nvgFill(nvg)
    end

    -- ⑤ 外圈旋转光粒子（方向相反，增加层次感）
    local sparkAlpha2 = math.floor(50 + math.sin(time * 3.0) * 30)
    for i = 1, 6 do
        local angle = -time * 0.6 + i * (math.pi * 2 / 6)
        local distR = ts * 0.85 + math.sin(time * 1.8 + i * 1.5) * ts * 0.08
        local px = cx + math.cos(angle) * distR
        local py = sy + ts * 0.15 + math.sin(angle) * distR * 0.35
        local pr = ts * 0.02 + math.sin(time * 4.0 + i) * ts * 0.01
        -- 光晕
        local pGlow = nvgRadialGradient(nvg,
            px, py, 0, pr * 3,
            nvgRGBA(150, 220, 255, sparkAlpha2),
            nvgRGBA(80, 160, 255, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pr * 3)
        nvgFillPaint(nvg, pGlow)
        nvgFill(nvg)
        -- 核心亮点
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pr)
        nvgFillColor(nvg, nvgRGBA(200, 240, 255, math.min(255, sparkAlpha2 + 80)))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 天帝剑痕（中洲神器 · 古剑伤痕 + 金红光效 + 剑气粒子）
-- ============================================================================
local divineTiandiImage_ = nil
local divineTiandiImageLoaded_ = false

function M.RenderDivineTiandi(nvg, sx, sy, ts, d, time)
    -- 延迟加载图片
    if not divineTiandiImageLoaded_ then
        divineTiandiImageLoaded_ = true
        divineTiandiImage_ = RenderUtils.GetCachedImage(nvg, "image/divine_tiandi_scar_20260417171710.png")
    end

    local cx = sx + ts * 0.5
    -- 呼吸脉动（金红调）
    local breath = math.sin(time * 1.6) * 0.3 + 0.7  -- 0.4~1.0
    local baseAlpha = math.floor(140 + breath * 80)    -- 140~220

    -- ① 底部大光圈（金红地面承托光效）
    local glowR = ts * 0.75 + math.sin(time * 2.0) * ts * 0.07
    local glowPaint = nvgRadialGradient(nvg,
        cx, sy + ts * 0.9, ts * 0.08, glowR,
        nvgRGBA(255, 160, 40, math.floor(baseAlpha * 0.40)),
        nvgRGBA(180, 40, 20, 0))
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, sy + ts * 0.9, glowR, glowR * 0.32)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- ② 剑痕裂缝光线（3道斜向金色划痕）
    local scarAlpha = math.floor(60 + math.sin(time * 2.8) * 35)
    local scars = {
        { dx1 = -0.22, dy1 = 0.85, dx2 = 0.08, dy2 = 0.55 },
        { dx1 = -0.05, dy1 = 0.90, dx2 = 0.20, dy2 = 0.50 },
        { dx1 = 0.10,  dy1 = 0.88, dx2 = 0.35, dy2 = 0.52 },
    }
    for _, s in ipairs(scars) do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + s.dx1 * ts, sy + s.dy1 * ts)
        nvgLineTo(nvg, cx + s.dx2 * ts, sy + s.dy2 * ts)
        nvgStrokeColor(nvg, nvgRGBA(255, 200, 60, scarAlpha))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
    end

    -- ③ 向上光柱（金红虚幻感）
    local pillarW = ts * 0.28 + math.sin(time * 1.4) * ts * 0.04
    local pillarH = ts * 2.3
    local pillarPaint = nvgLinearGradient(nvg,
        cx, sy - pillarH * 0.4, cx, sy + ts * 0.85,
        nvgRGBA(255, 200, 60, 0),
        nvgRGBA(255, 120, 20, math.floor(baseAlpha * 0.20)))
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - pillarW * 0.5, sy - pillarH * 0.4, pillarW, pillarH * 0.85)
    nvgFillPaint(nvg, pillarPaint)
    nvgFill(nvg)

    -- ④ 神器图片（竖向，比 NPC 更大：1.8ts × 2.5ts）
    if divineTiandiImage_ then
        local imgW = ts * 1.8
        local imgH = ts * 2.5
        local imgX = cx - imgW * 0.5
        local imgY = sy - imgH * 0.55
        -- 半透明悬浮（稍带金色覆膜）
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgW, imgH, 0, divineTiandiImage_, baseAlpha / 255.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, imgW, imgH)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
        -- 金红辉光叠层
        local glowAlpha = math.floor(25 + math.sin(time * 2.2) * 18)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, imgW, imgH)
        nvgFillColor(nvg, nvgRGBA(255, 120, 20, glowAlpha))
        nvgFill(nvg)
    end

    -- ⑤ 旋转剑气粒子环（6 粒，金红色，椭圆轨道）
    local sparkAlpha = math.floor(55 + math.sin(time * 3.2) * 38)
    for i = 1, 6 do
        local angle = time * 0.7 + i * 1.0472  -- 60度间隔
        local distX = ts * 0.60 + math.sin(time * 1.4 + i * 1.8) * ts * 0.09
        local distY = ts * 0.38 + math.cos(time * 1.1 + i * 1.6) * ts * 0.12
        local px = cx + math.cos(angle) * distX
        local py = sy + ts * 0.25 + math.sin(angle) * distY
        local pr = ts * 0.022 + math.sin(time * 4.2 + i * 1.4) * ts * 0.010
        -- 金红光晕
        local sparkGlow = nvgRadialGradient(nvg,
            px, py, 0, pr * 3.2,
            nvgRGBA(255, 180, 50, sparkAlpha),
            nvgRGBA(220, 60, 20, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pr * 3.2)
        nvgFillPaint(nvg, sparkGlow)
        nvgFill(nvg)
        -- 核心亮点
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pr)
        nvgFillColor(nvg, nvgRGBA(255, 240, 180, math.min(255, sparkAlpha + 80)))
        nvgFill(nvg)
    end

    -- ⑥ 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(255, 215, 80, 220))
        nvgText(nvg, cx, sy + ts * 1.05, d.label)
    end
end

-- ============================================================================
-- 青云试炼塔（多层宝塔 + 灵光环绕）
-- ============================================================================
function M.RenderTrialTower(nvg, sx, sy, ts, d, time)
    local w = (d.w or 2) * ts
    local h = (d.h or 2) * ts
    local cx = sx + w * 0.5

    -- 原图 512x636，保持比例向上超出 2x2 区域
    local imgRatio = 636 / 512   -- ≈1.242
    local imgW = w
    local imgH = w * imgRatio
    local imgY = sy + h - imgH   -- 底部对齐，顶部向上延伸

    -- PNG 纹理绘制
    local img = RenderUtils.GetCachedImage(nvg, "Textures/trial_tower.png")
    if img then
        local imgPaint = nvgImagePattern(nvg, sx, imgY, imgW, imgH, 0, img, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, imgY, imgW, imgH)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
    end

    -- 顶端宝珠辉光（轻量特效）
    local pulse = 0.6 + 0.4 * math.sin(time * 2.0)
    local orbY = imgY + imgH * 0.04
    local glowPaint = nvgRadialGradient(nvg, cx, orbY, 2, 12,
        nvgRGBA(120, 180, 255, math.floor(100 * pulse)),
        nvgRGBA(120, 180, 255, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, orbY, 12)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- 灵光粒子（塔周围环绕）
    for i = 0, 4 do
        local angle = time * 1.2 + i * (math.pi * 2 / 5)
        local pr = w * 0.45
        local px = cx + math.cos(angle) * pr
        local py = imgY + imgH * 0.5 + math.sin(angle * 0.7) * imgH * 0.3
        local pAlpha = math.floor(140 * (0.5 + 0.5 * math.sin(time * 3.0 + i * 1.5)))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 2.5)
        nvgFillColor(nvg, nvgRGBA(150, 200, 255, pAlpha))
        nvgFill(nvg)
    end

    -- 标签
    if d.label then
        nvgFontSize(nvg, 11)
        nvgFontFace(nvg, "sans")
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(200, 220, 255, 220))
        nvgText(nvg, cx, sy + h + 4, d.label)
    end
end

-- ============================================================================
-- 悟道树：PNG 纹理 + 轻量 NanoVG 特效（灵藤摇摆、光粒子）
-- ============================================================================
function M.RenderDaoTree(nvg, sx, sy, ts, d, time)
    local w = (d.w or 2) * ts
    local h = (d.h or 2) * ts
    local pulse = math.sin(time * 1.2) * 0.15 + 0.85

    -- 放大 1.3 倍，整体下移 0.25 格，允许超出格子
    local scale = 1.3
    local imgW = w * scale
    local imgH = h * scale
    local imgX = sx + (w - imgW) * 0.5   -- 水平居中
    local imgY = sy + h - imgH + ts * 0.25  -- 底部对齐后下移 1/4 格
    local cx = sx + w * 0.5

    -- PNG 纹理绘制
    local img = RenderUtils.GetCachedImage(nvg, "Textures/dao_tree.png")
    if img then
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgW, imgH, 0, img, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, imgW, imgH)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
    end

    -- 树冠光晕（强烈的绿色辉光，双层叠加）
    local crownCy = imgY + imgH * 0.22
    -- 外层大光晕
    local glowPaint = nvgRadialGradient(nvg, cx, crownCy, imgW * 0.05, imgW * 0.55,
        nvgRGBA(130, 255, 100, math.floor(55 * pulse)),
        nvgRGBA(130, 255, 100, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, crownCy, imgW * 0.55)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)
    -- 内层亮核
    local innerGlow = nvgRadialGradient(nvg, cx, crownCy, 2, imgW * 0.2,
        nvgRGBA(200, 255, 180, math.floor(80 * pulse)),
        nvgRGBA(200, 255, 180, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, crownCy, imgW * 0.2)
    nvgFillPaint(nvg, innerGlow)
    nvgFill(nvg)

    -- 树干根部灵气光晕
    local rootCy = imgY + imgH * 0.85
    local rootGlow = nvgRadialGradient(nvg, cx, rootCy, 2, imgW * 0.3,
        nvgRGBA(100, 220, 80, math.floor(35 * pulse)),
        nvgRGBA(100, 220, 80, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, rootCy, imgW * 0.3)
    nvgFillPaint(nvg, rootGlow)
    nvgFill(nvg)

    -- 垂挂灵藤（基于放大后的图片区域）
    local vineAnchors = {
        { cx - imgW * 0.35, imgY + imgH * 0.20, imgH * 0.30 },
        { cx - imgW * 0.18, imgY + imgH * 0.18, imgH * 0.24 },
        { cx + imgW * 0.20, imgY + imgH * 0.16, imgH * 0.26 },
        { cx + imgW * 0.38, imgY + imgH * 0.20, imgH * 0.32 },
    }
    for i, va in ipairs(vineAnchors) do
        local vx, vy, vLen = va[1], va[2], va[3]
        local sway = math.sin(time * 0.6 + i * 1.3) * imgW * 0.03
        nvgStrokeWidth(nvg, 1.5)
        nvgStrokeColor(nvg, nvgRGBA(45, 95, 35, 160))
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, vx, vy)
        nvgBezierTo(nvg,
            vx + sway * 0.5, vy + vLen * 0.3,
            vx + sway, vy + vLen * 0.7,
            vx + sway * 0.7, vy + vLen)
        nvgStroke(nvg)
        -- 藤尖光点（更亮）
        nvgBeginPath(nvg)
        nvgCircle(nvg, vx + sway * 0.7, vy + vLen, 2.5)
        nvgFillColor(nvg, nvgRGBA(160, 255, 140, math.floor(180 * pulse)))
        nvgFill(nvg)
    end

    -- 灵光粒子（更多、更亮、更大）
    for i = 0, 7 do
        local seed = i * 1.2
        local px = cx + math.sin(time * 0.5 + seed) * imgW * 0.45
        local py = imgY + imgH * 0.1 + math.cos(time * 0.35 + seed * 2) * imgH * 0.35
        local pa = math.sin(time * 0.8 + seed) * 0.35 + 0.65
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 1.8 + math.sin(time * 1.2 + seed) * 0.8)
        nvgFillColor(nvg, nvgRGBA(180, 255, 160, math.floor(160 * pa)))
        nvgFill(nvg)
    end

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        local tw = nvgTextBounds(nvg, 0, 0, d.label)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - tw * 0.5 - 6, sy + h + 1, tw + 12, 16, 3)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 140))
        nvgFill(nvg)
        nvgFillColor(nvg, nvgRGBA(180, 240, 170, 230))
        nvgText(nvg, cx, sy + h + 3, d.label)
    end
end

-- ============================================================================
-- 城门（仙府风格 · 7格完整覆盖缺口）
-- 结构: [1格填充墙][1格石柱][ 5格通道 ][1格石柱][1格填充墙]
-- d.label: 门匾名称   d.dir: "ns"(南北向) 或 "ew"(东西向)
-- d.w/d.h: 必须为7(沿门洞方向)，另一维为1
-- ============================================================================
function M.RenderCityGate(nvg, sx, sy, ts, d, time)
    local w = (d.w or 7) * ts
    local h = (d.h or 1) * ts
    local dir = d.dir or "ns"
    local pulse = math.sin(time * 1.5) * 0.15 + 0.85

    -- 城墙色（匹配 RenderCelestialWall 底色）
    local wallR, wallG, wallB = 55, 65, 80

    if dir == "ns" then
        -- 南北向城门：门洞横跨 X 轴（w=7格, h=1格）
        -- 布局: [fill1][pillar1][ 5格通道 ][pillar2][fill2]

        -- ① 两端各1格填充墙
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, h)
        nvgFillColor(nvg, nvgRGBA(wallR, wallG, wallB, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx + w - ts, sy, ts, h)
        nvgFillColor(nvg, nvgRGBA(wallR, wallG, wallB, 255))
        nvgFill(nvg)

        -- ② 两根石柱（第2格和第6格, 各占1格宽, 向上下各延伸0.3格）
        local pillarW = ts
        local pillarH = h + ts * 0.6
        local pillarY = sy - ts * 0.3
        local p1x = sx + ts           -- 左柱 x
        local p2x = sx + w - ts * 2   -- 右柱 x

        for _, px in ipairs({p1x, p2x}) do
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, px + 1, pillarY, pillarW - 2, pillarH, 2)
            nvgFillColor(nvg, nvgRGBA(85, 75, 100, 255))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(210, 180, 100, math.floor(150 * pulse)))
            nvgStrokeWidth(nvg, 1.2)
            nvgStroke(nvg)
        end

        -- ③ 横额（连接两柱顶部）
        local beamH = math.max(ts * 0.25, 6)
        local beamX = p1x
        local beamW = p2x + pillarW - p1x
        local beamY = pillarY - beamH * 0.2
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, beamX - 1, beamY, beamW + 2, beamH, 1.5)
        nvgFillColor(nvg, nvgRGBA(70, 60, 85, 255))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(220, 190, 110, math.floor(130 * pulse)))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)

        -- ④ 柱顶金珠
        for _, px in ipairs({p1x + pillarW * 0.5, p2x + pillarW * 0.5}) do
            local orbGlow = nvgRadialGradient(nvg, px, pillarY - 1, 1, 5,
                nvgRGBA(255, 220, 100, math.floor(160 * pulse)),
                nvgRGBA(255, 200, 60, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, pillarY - 1, 5)
            nvgFillPaint(nvg, orbGlow)
            nvgFill(nvg)
        end

        -- ⑤ 名匾（横额中央）
        if d.label then
            local cx = sx + w * 0.5
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 10)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 230, 150, math.floor(220 * pulse)))
            nvgText(nvg, cx, beamY + beamH * 0.5, d.label)
        end
    else
        -- 东西向城门：门洞横跨 Y 轴（w=1格, h=7格）
        -- 布局: [fill1][pillar1][ 5格通道 ][pillar2][fill2]

        -- ① 两端各1格填充墙
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, w, ts)
        nvgFillColor(nvg, nvgRGBA(wallR, wallG, wallB, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy + h - ts, w, ts)
        nvgFillColor(nvg, nvgRGBA(wallR, wallG, wallB, 255))
        nvgFill(nvg)

        -- ② 两根石柱（第2格和第6格, 各占1格高, 向左右各延伸0.3格）
        local pillarH = ts
        local pillarW = w + ts * 0.6
        local pillarX = sx - ts * 0.3
        local p1y = sy + ts           -- 上柱 y
        local p2y = sy + h - ts * 2   -- 下柱 y

        for _, py in ipairs({p1y, p2y}) do
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, pillarX, py + 1, pillarW, pillarH - 2, 2)
            nvgFillColor(nvg, nvgRGBA(85, 75, 100, 255))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(210, 180, 100, math.floor(150 * pulse)))
            nvgStrokeWidth(nvg, 1.2)
            nvgStroke(nvg)
        end

        -- ③ 竖额（连接两柱侧面）
        local beamW = math.max(ts * 0.25, 6)
        local beamY = p1y
        local beamH = p2y + pillarH - p1y
        local beamX = pillarX - beamW * 0.2
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, beamX, beamY - 1, beamW, beamH + 2, 1.5)
        nvgFillColor(nvg, nvgRGBA(70, 60, 85, 255))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(220, 190, 110, math.floor(130 * pulse)))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)

        -- ④ 名匾（竖额中央）
        if d.label then
            local cy = sy + h * 0.5
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 10)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 230, 150, math.floor(220 * pulse)))
            nvgText(nvg, beamX + beamW * 0.5, cy, d.label)
        end
    end
end

-- ============================================================================
-- 药园（天机阁标志 · 绿色草药田 + 围栏 + 灵气）
-- ============================================================================
function M.RenderHerbGarden(nvg, sx, sy, ts, d, time)
    local w = (d.w or 4) * ts
    local h = (d.h or 3) * ts
    local pulse = math.sin(time * 1.0) * 0.12 + 0.88

    -- ① 药田底色（深绿色土地）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + 2, sy + 2, w - 4, h - 4, 3)
    nvgFillColor(nvg, nvgRGBA(50, 80, 40, 200))
    nvgFill(nvg)

    -- ② 草药行列（3 排药草）
    local rows = 3
    local rowH = (h - 8) / rows
    for r = 0, rows - 1 do
        local ry = sy + 4 + r * rowH + rowH * 0.3
        local herbs = math.floor(w / (ts * 0.4))
        for hi = 1, herbs do
            local hx = sx + 4 + (hi - 0.5) * ((w - 8) / herbs)
            -- 用 sin 做确定性伪随机（替代 tileRand，该函数不在本模块作用域）
            local seed = hi * 17 + r * 53
            local hh = 3 + (math.sin(seed * 0.618) * 0.5 + 0.5) * 4
            local sway = math.sin(time * 0.8 + hi * 0.7 + r * 1.5) * 1.5
            local greenVar = math.floor(math.sin(seed * 1.337) * 20)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, hx, ry + 2)
            nvgLineTo(nvg, hx + sway, ry - hh)
            nvgStrokeColor(nvg, nvgRGBA(60 + greenVar, 140 + greenVar, 40, 200))
            nvgStrokeWidth(nvg, 1.2)
            nvgStroke(nvg)
            -- 叶片
            nvgBeginPath(nvg)
            nvgEllipse(nvg, hx + sway * 0.7, ry - hh + 1, 2.5, 1.5)
            nvgFillColor(nvg, nvgRGBA(70 + greenVar, 160 + greenVar, 50, 180))
            nvgFill(nvg)
        end
    end

    -- ③ 围栏（细线框）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + 1, sy + 1, w - 2, h - 2, 2)
    nvgStrokeColor(nvg, nvgRGBA(140, 120, 80, 120))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ④ 灵气光点（2~3 颗）
    for i = 1, 3 do
        local px = sx + w * (0.2 + (math.sin(i * 3.71) * 0.5 + 0.5) * 0.6)
        local py = sy + h * (0.3 + (math.sin(i * 5.13) * 0.5 + 0.5) * 0.4)
        local pa = math.sin(time * 1.5 + i * 2.0) * 0.4 + 0.6
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 2.0)
        nvgFillColor(nvg, nvgRGBA(140, 255, 120, math.floor(100 * pa * pulse)))
        nvgFill(nvg)
    end

    -- 标签
    if d.label then
        local cx = sx + w * 0.5
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(140, 220, 120, 200))
        nvgText(nvg, cx, sy + h + 3, d.label)
    end
end

-- ============================================================================
-- 瑶池仙池（大型水池 + 金色波纹 + 灵气蒸腾）
-- ============================================================================
function M.RenderCelestialPool(nvg, sx, sy, ts, d, time)
    local w = (d.w or 6) * ts
    local h = (d.h or 4) * ts
    local cx = sx + w * 0.5
    local cy = sy + h * 0.5
    local pulse = math.sin(time * 0.8) * 0.1 + 0.9

    -- ① 池体（蓝绿色椭圆）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy, w * 0.45, h * 0.42)
    nvgFillColor(nvg, nvgRGBA(40, 100, 140, 240))
    nvgFill(nvg)

    -- ② 内层渐变（中心更深邃）
    local innerPaint = nvgRadialGradient(nvg, cx, cy, w * 0.05, w * 0.4,
        nvgRGBA(30, 70, 120, 200),
        nvgRGBA(60, 140, 180, 100))
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy, w * 0.42, h * 0.39)
    nvgFillPaint(nvg, innerPaint)
    nvgFill(nvg)

    -- ③ 波纹（3 圈同心椭圆，缓慢扩散）
    for i = 1, 3 do
        local phase = time * 0.3 + i * 2.1
        local rippleR = (0.15 + (phase % 1.0) * 0.3) * w * 0.45
        local rippleA = math.floor(80 * (1.0 - (phase % 1.0)))
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, rippleR, rippleR * (h * 0.42 / (w * 0.45)))
        nvgStrokeColor(nvg, nvgRGBA(160, 220, 255, rippleA))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ④ 金色倒影光斑
    local spotX = cx + math.sin(time * 0.5) * w * 0.15
    local spotY = cy + math.cos(time * 0.4) * h * 0.1
    local spotGlow = nvgRadialGradient(nvg, spotX, spotY, 2, w * 0.12,
        nvgRGBA(255, 220, 120, math.floor(60 * pulse)),
        nvgRGBA(255, 200, 80, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, spotX, spotY, w * 0.12)
    nvgFillPaint(nvg, spotGlow)
    nvgFill(nvg)

    -- ⑤ 池岸边缘
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy, w * 0.46, h * 0.43)
    nvgStrokeColor(nvg, nvgRGBA(150, 180, 200, 100))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- ⑥ 灵气蒸腾光点（池面上方浮动）
    for i = 1, 4 do
        local px = cx + math.sin(time * 0.6 + i * 1.6) * w * 0.3
        local py = cy - h * 0.15 + math.cos(time * 0.5 + i * 2.0) * h * 0.2
        local pa = math.sin(time * 1.2 + i * 1.5) * 0.35 + 0.65
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 1.8)
        nvgFillColor(nvg, nvgRGBA(180, 230, 255, math.floor(120 * pa)))
        nvgFill(nvg)
    end

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(160, 220, 255, 220))
        nvgText(nvg, cx, sy + h + 4, d.label)
    end
end

-- ============================================================================
-- 封魔法阵（暗紫色法阵 + 封印符文旋转）
-- ============================================================================
function M.RenderFengmoSeal(nvg, sx, sy, ts, d, time)
    local w = (d.w or 3) * ts
    local h = (d.h or 3) * ts
    local cx = sx + w * 0.5
    local cy = sy + h * 0.5
    local r = math.min(w, h) * 0.4
    local pulse = math.sin(time * 2.0) * 0.2 + 0.8

    -- ① 底部暗光圈
    local glowPaint = nvgRadialGradient(nvg, cx, cy, r * 0.2, r * 1.2,
        nvgRGBA(120, 40, 160, math.floor(80 * pulse)),
        nvgRGBA(80, 20, 120, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r * 1.2)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- ② 双层法阵圆环
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r)
    nvgStrokeColor(nvg, nvgRGBA(180, 80, 220, math.floor(150 * pulse)))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r * 0.7)
    nvgStrokeColor(nvg, nvgRGBA(160, 60, 200, math.floor(120 * pulse)))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ③ 旋转符文点（6 个）
    for i = 1, 6 do
        local angle = time * 0.5 + (i - 1) * (math.pi * 2 / 6)
        local px = cx + math.cos(angle) * r * 0.85
        local py = cy + math.sin(angle) * r * 0.85
        local sa = math.sin(time * 2.5 + i * 1.1) * 0.3 + 0.7
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 2.5)
        nvgFillColor(nvg, nvgRGBA(200, 100, 255, math.floor(180 * sa)))
        nvgFill(nvg)
    end

    -- ④ 中心封印核心
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r * 0.15)
    nvgFillColor(nvg, nvgRGBA(160, 60, 220, math.floor(100 * pulse)))
    nvgFill(nvg)

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(200, 140, 255, 200))
        nvgText(nvg, cx, sy + h + 3, d.label)
    end
end

-- ============================================================================
-- 演武场（血煞盟标志 · 石制圆形擂台 + 红色旗帜）
-- ============================================================================
function M.RenderArenaRing(nvg, sx, sy, ts, d, time)
    local w = (d.w or 3) * ts
    local h = (d.h or 3) * ts
    local cx = sx + w * 0.5
    local cy = sy + h * 0.5
    local r = math.min(w, h) * 0.42

    -- ① 擂台底座（灰色圆形）
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r)
    nvgFillColor(nvg, nvgRGBA(100, 90, 80, 230))
    nvgFill(nvg)

    -- ② 擂台边缘石阶
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r)
    nvgStrokeColor(nvg, nvgRGBA(140, 125, 110, 200))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r * 0.85)
    nvgStrokeColor(nvg, nvgRGBA(120, 105, 90, 150))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ③ 中心血红标记
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r * 0.15)
    nvgFillColor(nvg, nvgRGBA(180, 40, 40, 160))
    nvgFill(nvg)

    -- ④ 四角旗帜标记点
    local flagPos = {{-1,-1}, {1,-1}, {-1,1}, {1,1}}
    for i, fp in ipairs(flagPos) do
        local fx = cx + fp[1] * r * 0.6
        local fy = cy + fp[2] * r * 0.6
        nvgBeginPath(nvg)
        nvgCircle(nvg, fx, fy, 2)
        nvgFillColor(nvg, nvgRGBA(200, 50, 50, 180))
        nvgFill(nvg)
    end

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(220, 150, 150, 200))
        nvgText(nvg, cx, sy + h + 3, d.label)
    end
end

-- ============================================================================
-- 剑碑（浩气宗标志 · 石碑 + 蓝色剑气 + 铭文）
-- ============================================================================
function M.RenderSwordStele(nvg, sx, sy, ts, d, time)
    local w = (d.w or 2) * ts
    local h = (d.h or 2) * ts
    local cx = sx + w * 0.5
    local pulse = math.sin(time * 1.8) * 0.15 + 0.85

    -- ① 石碑主体（灰白色窄长方形）
    local steleW = w * 0.35
    local steleH = h * 0.85
    local steleX = cx - steleW * 0.5
    local steleY = sy + h - steleH
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, steleX, steleY, steleW, steleH, 2)
    nvgFillColor(nvg, nvgRGBA(170, 175, 180, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(200, 205, 210, 150))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ② 剑气竖线（中央蓝色光线）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, steleY + steleH * 0.1)
    nvgLineTo(nvg, cx, steleY - steleH * 0.15)
    nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, math.floor(180 * pulse)))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- ③ 剑尖光晕
    local tipGlow = nvgRadialGradient(nvg, cx, steleY - steleH * 0.15, 1, 8,
        nvgRGBA(120, 200, 255, math.floor(140 * pulse)),
        nvgRGBA(100, 160, 255, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, steleY - steleH * 0.15, 8)
    nvgFillPaint(nvg, tipGlow)
    nvgFill(nvg)

    -- ④ 底座
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx - steleW * 0.7, sy + h - h * 0.08, steleW * 1.4, h * 0.08, 1)
    nvgFillColor(nvg, nvgRGBA(130, 135, 140, 220))
    nvgFill(nvg)

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(140, 200, 255, 200))
        nvgText(nvg, cx, sy + h + 3, d.label)
    end
end

-- ============================================================================
-- 瀑布（崖壁水流 + 水花 + 雾气）
-- ============================================================================
function M.RenderWaterfall(nvg, sx, sy, ts, d, time)
    local w = (d.w or 2) * ts
    local h = (d.h or 6) * ts
    local cx = sx + w * 0.5

    -- ① 崖壁暗岩底色
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + w * 0.05, sy, w * 0.9, h, 2)
    nvgFillColor(nvg, nvgRGBA(55, 50, 40, 180))
    nvgFill(nvg)

    -- ② 主水流（竖向渐变，白蓝半透明）
    local streamW = w * 0.45
    local streamX = cx - streamW * 0.5
    local waterPaint = nvgLinearGradient(nvg, cx, sy, cx, sy + h,
        nvgRGBA(190, 225, 255, 210),
        nvgRGBA(120, 180, 240, 160))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, streamX, sy, streamW, h, 3)
    nvgFillPaint(nvg, waterPaint)
    nvgFill(nvg)

    -- ③ 水流纹理线（动画下滑）
    for i = 1, 5 do
        local linePhase = (time * 1.2 + i * 0.8) % 1.0
        local lineY = sy + linePhase * h
        local lineAlpha = math.floor(100 * (1.0 - math.abs(linePhase - 0.5) * 2))
        local lineW = streamW * (0.3 + math.sin(i * 2.1) * 0.15)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - lineW * 0.5, lineY)
        nvgLineTo(nvg, cx + lineW * 0.5, lineY)
        nvgStrokeColor(nvg, nvgRGBA(230, 245, 255, lineAlpha))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
    end

    -- ④ 侧面飞溅水雾
    for side = -1, 1, 2 do
        local mistX = cx + side * streamW * 0.5
        local mistPaint = nvgLinearGradient(nvg,
            mistX, sy + h * 0.3, mistX + side * w * 0.2, sy + h * 0.7,
            nvgRGBA(180, 215, 240, 40), nvgRGBA(180, 215, 240, 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, mistX, sy + h * 0.3, side * w * 0.2, h * 0.4)
        nvgFillPaint(nvg, mistPaint)
        nvgFill(nvg)
    end

    -- ⑤ 底部水花（扩散弧 + 飞溅）
    local splashY = sy + h
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, splashY, w * 0.35, h * 0.05)
    nvgFillColor(nvg, nvgRGBA(170, 215, 245, 120))
    nvgFill(nvg)

    for i = 1, 3 do
        local dropPhase = (time * 0.8 + i * 1.3) % 1.0
        local dropX = cx + math.sin(i * 3.7 + time * 0.5) * w * 0.3
        local dropY = splashY - dropPhase * h * 0.1
        local dropA = math.floor(90 * (1.0 - dropPhase))
        nvgBeginPath(nvg)
        nvgCircle(nvg, dropX, dropY, 1.2)
        nvgFillColor(nvg, nvgRGBA(210, 235, 255, dropA))
        nvgFill(nvg)
    end

    -- ⑥ 底部雾气弥散
    local mistGlow = nvgRadialGradient(nvg, cx, splashY,
        w * 0.08, w * 0.4,
        nvgRGBA(180, 220, 250, math.floor(45 + math.sin(time * 0.6) * 15)),
        nvgRGBA(180, 220, 250, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, splashY, w * 0.4)
    nvgFillPaint(nvg, mistGlow)
    nvgFill(nvg)

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(180, 220, 255, 200))
        nvgText(nvg, cx, splashY + 4, d.label)
    end
end

-- ============================================================================
-- 黑商摊位（天机阁标志 · 暗色布帘 + 神秘货架 + 金色光芒）
-- ============================================================================
function M.RenderMerchantStall(nvg, sx, sy, ts, d, time)
    local w = (d.w or 3) * ts
    local h = (d.h or 3) * ts
    local cx = sx + w * 0.5
    local cy = sy + h * 0.5
    local pulse = math.sin(time * 1.2) * 0.1 + 0.9

    -- ① 摊位底座（深色木板）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + 2, sy + h * 0.3, w - 4, h * 0.65, 3)
    nvgFillColor(nvg, nvgRGBA(60, 45, 30, 220))
    nvgFill(nvg)

    -- ② 布帘顶篷（暗紫色，带波纹）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + h * 0.25)
    for i = 0, 4 do
        local px = sx + w * (i / 4)
        local py = sy + h * 0.25 + math.sin(i * 1.5 + time * 0.5) * 2
        if i == 0 then
            nvgMoveTo(nvg, px, py)
        else
            nvgLineTo(nvg, px, py)
        end
    end
    nvgLineTo(nvg, sx + w, sy + 2)
    nvgLineTo(nvg, sx, sy + 2)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(80, 40, 100, 200))
    nvgFill(nvg)

    -- ③ 货架上的发光物品（3个圆形光点）
    for i = 1, 3 do
        local ix = sx + w * (0.2 + (i - 1) * 0.3)
        local iy = cy + h * 0.05
        local glow = math.sin(time * 1.5 + i * 2.1) * 0.3 + 0.7
        -- 物品底色
        nvgBeginPath(nvg)
        nvgCircle(nvg, ix, iy, ts * 0.15)
        local colors = {
            {220, 180, 50},  -- 金色
            {100, 200, 255}, -- 冰蓝
            {255, 120, 80},  -- 赤橙
        }
        local c = colors[i]
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * glow * pulse)))
        nvgFill(nvg)
        -- 光晕
        local glowPaint = nvgRadialGradient(nvg, ix, iy, ts * 0.05, ts * 0.25,
            nvgRGBA(c[1], c[2], c[3], math.floor(60 * glow)), nvgRGBA(c[1], c[2], c[3], 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, ix, iy, ts * 0.25)
        nvgFillPaint(nvg, glowPaint)
        nvgFill(nvg)
    end

    -- ④ 摊位边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + 1, sy + 1, w - 2, h - 2, 3)
    nvgStrokeColor(nvg, nvgRGBA(100, 60, 130, 120))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(200, 170, 100, 200))
        nvgText(nvg, cx, sy + h + 3, d.label)
    end
end

-- ============================================================================
-- 香炉（青铜三足鼎 + 袅袅烟雾 + 暖光）
-- ============================================================================
function M.RenderIncenseBurner(nvg, sx, sy, ts, d, time)
    local w = (d.w or 1) * ts
    local h = (d.h or 1) * ts
    local cx = sx + w * 0.5
    local cy = sy + h * 0.5

    -- ① 三足底座（两条短线）
    nvgStrokeColor(nvg, nvgRGBA(120, 100, 60, 200))
    nvgStrokeWidth(nvg, 1.5)
    for _, off in ipairs({-0.2, 0.2}) do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + w * off, cy + h * 0.35)
        nvgLineTo(nvg, cx + w * off, cy + h * 0.45)
        nvgStroke(nvg)
    end

    -- ② 炉身（扁圆形，青铜色）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy + h * 0.15, w * 0.3, h * 0.2)
    nvgFillColor(nvg, nvgRGBA(140, 120, 60, 230))
    nvgFill(nvg)
    -- 炉口
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy + h * 0.05, w * 0.22, h * 0.08)
    nvgFillColor(nvg, nvgRGBA(80, 60, 30, 200))
    nvgFill(nvg)

    -- ③ 烟雾（3条上升的半透明曲线）
    for i = 1, 3 do
        local smokeX = cx + math.sin(i * 2.3 + time * 0.3) * w * 0.15
        local smokePhase = (time * 0.4 + i * 0.5) % 2.0
        local smokeY0 = cy
        local smokeY1 = cy - h * (0.2 + smokePhase * 0.3)
        local smokeAlpha = math.max(0, math.floor(80 * (1.0 - smokePhase / 2.0)))
        local sway = math.sin(time * 0.8 + i * 1.7) * w * 0.1
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, smokeX, smokeY0)
        nvgBezierTo(nvg,
            smokeX + sway * 0.5, (smokeY0 + smokeY1) * 0.5,
            smokeX + sway, smokeY1 + (smokeY0 - smokeY1) * 0.3,
            smokeX + sway * 0.7, smokeY1)
        nvgStrokeColor(nvg, nvgRGBA(180, 170, 150, smokeAlpha))
        nvgStrokeWidth(nvg, 1.0 + smokePhase * 0.5)
        nvgStroke(nvg)
    end

    -- ④ 炉口暖光
    local glowR = w * 0.15
    local glowPaint = nvgRadialGradient(nvg, cx, cy + h * 0.05, glowR * 0.2, glowR,
        nvgRGBA(255, 180, 80, math.floor(60 * (math.sin(time * 1.0) * 0.3 + 0.7))),
        nvgRGBA(255, 180, 80, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy + h * 0.05, glowR)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- 宝箱（古朴木箱 + 金属包角 + 微光暗示）
-- ============================================================================
function M.RenderTreasureCrate(nvg, sx, sy, ts, d, time)
    local w = (d.w or 1) * ts
    local h = (d.h or 1) * ts
    local cx = sx + w * 0.5
    local pulse = math.sin(time * 1.5) * 0.15 + 0.85

    -- ① 箱体主体（深棕色矩形）
    local boxW = w * 0.7
    local boxH = h * 0.5
    local boxX = cx - boxW * 0.5
    local boxY = sy + h * 0.3
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, boxX, boxY, boxW, boxH, 2)
    nvgFillColor(nvg, nvgRGBA(100, 70, 40, 230))
    nvgFill(nvg)

    -- ② 箱盖（略宽，梯形效果用矩形近似）
    local lidH = boxH * 0.35
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, boxX - 1, boxY - lidH, boxW + 2, lidH, 2)
    nvgFillColor(nvg, nvgRGBA(120, 85, 50, 230))
    nvgFill(nvg)

    -- ③ 金属锁扣（中心小圆）
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, boxY, 2)
    nvgFillColor(nvg, nvgRGBA(200, 170, 60, math.floor(220 * pulse)))
    nvgFill(nvg)

    -- ④ 金属包角（四角小方块）
    local cornerSize = 2
    for _, pos in ipairs({{boxX, boxY}, {boxX + boxW - cornerSize, boxY},
                          {boxX, boxY + boxH - cornerSize}, {boxX + boxW - cornerSize, boxY + boxH - cornerSize}}) do
        nvgBeginPath(nvg)
        nvgRect(nvg, pos[1], pos[2], cornerSize, cornerSize)
        nvgFillColor(nvg, nvgRGBA(180, 155, 60, 180))
        nvgFill(nvg)
    end

    -- ⑤ 微光暗示（缝隙金光）
    local glowAlpha = math.floor(40 * pulse + math.sin(time * 2.0) * 15)
    nvgBeginPath(nvg)
    nvgRect(nvg, boxX + 2, boxY - 1, boxW - 4, 2)
    nvgFillColor(nvg, nvgRGBA(255, 220, 100, math.max(0, glowAlpha)))
    nvgFill(nvg)
end

-- ============================================================================
-- 天机阁藏宝阁：PNG 纹理 + 紫金辉光特效
-- ============================================================================
function M.RenderTianjiPavilion(nvg, sx, sy, ts, d, time)
    local w = (d.w or 4) * ts
    local h = (d.h or 4) * ts
    local cx = sx + w * 0.5

    -- 原图 512x636，保持比例向上超出
    local imgRatio = 636 / 512
    local imgW = w
    local imgH = w * imgRatio
    local imgY = sy + h - imgH   -- 底部对齐，顶部向上延伸

    -- PNG 纹理绘制
    local img = RenderUtils.GetCachedImage(nvg, "Textures/tianji_pavilion.png")
    if img then
        local imgPaint = nvgImagePattern(nvg, sx, imgY, imgW, imgH, 0, img, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, imgY, imgW, imgH)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
    end

    -- 顶端紫金宝珠辉光
    local pulse = 0.6 + 0.4 * math.sin(time * 1.8)
    local orbY = imgY + imgH * 0.04
    local glowPaint = nvgRadialGradient(nvg, cx, orbY, 3, 14,
        nvgRGBA(180, 140, 255, math.floor(120 * pulse)),
        nvgRGBA(180, 140, 255, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, orbY, 14)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- 灵光粒子（藏宝阁周围环绕，紫金色调）
    for i = 0, 5 do
        local angle = time * 0.9 + i * (math.pi * 2 / 6)
        local pr = w * 0.5
        local px = cx + math.cos(angle) * pr
        local py = imgY + imgH * 0.5 + math.sin(angle * 0.6) * imgH * 0.3
        local pAlpha = math.floor(120 * (0.5 + 0.5 * math.sin(time * 2.5 + i * 1.2)))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 2.5)
        nvgFillColor(nvg, nvgRGBA(200, 170, 255, pAlpha))
        nvgFill(nvg)
    end

    -- 标签
    if d.label then
        nvgFontSize(nvg, 12)
        nvgFontFace(nvg, "sans")
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(220, 200, 255, 220))
        nvgText(nvg, cx, sy + h + 4, d.label)
    end
end

return M
