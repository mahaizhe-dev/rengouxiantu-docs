-- ============================================================================
-- effects/auras.lua - 光环与持续特效（钉耙横扫/八卦/套装AOE/Buff光环/阵图剑效果）
-- ============================================================================

local shared = require("rendering.effects.shared")
local assets = require("rendering.effects.assets")

local GameState = shared.GameState
local CombatSystem = shared.CombatSystem
local GameConfig = shared.GameConfig
local SkillSystem = shared.SkillSystem

local M = {}

--- 神器被动「天蓬遗威」钉耙横扫地面特效（矩形条带）
function M.RenderRakeStrikeEffects(nvg, l, camera)
    local effects = CombatSystem.rakeStrikeEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local e = effects[i]
        if not camera:IsVisible(e.x, e.y, l.w, l.h, e.range + 1) then goto continue end

        local t = e.elapsed / e.duration  -- 0→1
        local sx = (e.x - camera.x) * tileSize + l.w / 2 + l.x
        local sy = (e.y - camera.y) * tileSize + l.h / 2 + l.y
        local ang = e.angle
        local cosA = math.cos(ang)
        local sinA = math.sin(ang)
        local fullLen = (e.range or 2.5) * tileSize
        local halfW = (e.width or 1.2) * 0.5 * tileSize
        -- 前方(forward) 和 横向(right) 单位向量
        local fx, fy = cosA, sinA
        local rx, ry = -sinA, cosA

        -- 淡入后淡出
        local alpha
        if t < 0.15 then
            alpha = t / 0.15
        else
            alpha = 1.0 - (t - 0.15) / 0.85
        end
        alpha = math.max(0, math.min(1, alpha))
        local a = math.floor(255 * alpha)

        -- ① 矩形条带区域（金色半透明）——划过的地面
        local x1 = sx + rx * halfW
        local y1 = sy + ry * halfW
        local x2 = sx - rx * halfW
        local y2 = sy - ry * halfW
        local x3 = sx - rx * halfW + fx * fullLen
        local y3 = sy - ry * halfW + fy * fullLen
        local x4 = sx + rx * halfW + fx * fullLen
        local y4 = sy + ry * halfW + fy * fullLen
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x4, y4)
        nvgLineTo(nvg, x3, y3)
        nvgLineTo(nvg, x2, y2)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, math.floor(a * 0.10)))
        nvgFill(nvg)

        -- ② 横向划痕（三齿钉耙横着扫过，划痕方向=横向）
        -- 横扫进度：从一侧扫到另一侧
        local sweepProgress = math.min(t / 0.6, 1.0)  -- 前60%时间完成横扫
        local sweepFrom = -halfW
        local sweepTo = sweepFrom + (halfW * 2) * sweepProgress

        local prongCount = 3
        local prongGap = fullLen / (prongCount + 1)  -- 三齿沿前方均匀分布
        for p = 1, prongCount do
            local fDist = prongGap * p  -- 前方距离
            local cx = sx + fx * fDist
            local cy = sy + fy * fDist
            -- 划痕起点和终点（横向）
            local lx1 = cx + rx * sweepFrom
            local ly1 = cy + ry * sweepFrom
            local lx2 = cx + rx * sweepTo
            local ly2 = cy + ry * sweepTo
            -- 发光层
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, lx1, ly1)
            nvgLineTo(nvg, lx2, ly2)
            nvgStrokeColor(nvg, nvgRGBA(255, 240, 150, math.floor(a * 0.25)))
            nvgStrokeWidth(nvg, 6 * (1 - t * 0.4))
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
            -- 主线
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, lx1, ly1)
            nvgLineTo(nvg, lx2, ly2)
            nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, a))
            nvgStrokeWidth(nvg, 2.5 * (1 - t * 0.3))
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end

        -- ③ 钉耙影子（在划痕上方，跟随横扫位置移动）
        -- 影子位置 = 横扫前端
        local shadowLateral = sweepTo
        local shadowCenterF = fullLen * 0.5  -- 影子在前方中间位置
        local shX = sx + fx * shadowCenterF + rx * shadowLateral
        local shY = sy + fy * shadowCenterF + ry * shadowLateral
        -- 影子偏移到划痕上方（沿前方反方向偏移一点）
        shX = shX - fx * tileSize * 0.15
        shY = shY - fy * tileSize * 0.15
        local shadowAlpha = math.floor(a * 0.35 * (1 - t * 0.5))

        nvgSave(nvg)
        nvgTranslate(nvg, shX, shY)
        nvgRotate(nvg, ang)

        -- 钉耙柄（沿前方方向的一条线）
        local handleLen = fullLen * 0.35
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, -handleLen * 0.5, 0)
        nvgLineTo(nvg, handleLen * 0.5, 0)
        nvgStrokeColor(nvg, nvgRGBA(80, 60, 30, shadowAlpha))
        nvgStrokeWidth(nvg, 3)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)

        -- 钉耙头横档（垂直于柄）
        local headW = prongGap * (prongCount - 1) * 0.55
        local headX = handleLen * 0.5
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, headX, -headW)
        nvgLineTo(nvg, headX, headW)
        nvgStrokeColor(nvg, nvgRGBA(80, 60, 30, shadowAlpha))
        nvgStrokeWidth(nvg, 3.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)

        -- 三齿（从横档向下伸出，即沿前方方向）
        local toothLen = tileSize * 0.2
        for p = 1, prongCount do
            local ty = -headW + (p - 1) * headW
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, headX, ty)
            nvgLineTo(nvg, headX + toothLen, ty)
            nvgStrokeColor(nvg, nvgRGBA(80, 60, 30, shadowAlpha))
            nvgStrokeWidth(nvg, 2.5)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end

        nvgRestore(nvg)

        -- ④ 扬尘微粒（沿横扫前端散布）
        local sparkCount = 4
        for s = 1, sparkCount do
            local phase = (t * 5 + s * 1.3) % 1.0
            local spFwd = prongGap * (0.5 + (s - 1))  -- 沿前方分布
            if spFwd > fullLen then spFwd = fullLen * 0.9 end
            local spx = sx + fx * spFwd + rx * sweepTo + rx * phase * tileSize * 0.15
            local spy = sy + fy * spFwd + ry * sweepTo + ry * phase * tileSize * 0.15
            local spAlpha = math.floor(a * (1 - phase) * 0.5)
            local spR = 1.5 + phase * 2.5
            nvgBeginPath(nvg)
            nvgCircle(nvg, spx, spy, spR)
            nvgFillColor(nvg, nvgRGBA(255, 220, 100, spAlpha))
            nvgFill(nvg)
        end

        ::continue::
    end
end

-- ============================================================================
-- 永驻八卦领域渲染（文王残影脚底八卦，阴/阳双色切换）
-- ============================================================================

--- 八卦符号线段角度（8 条卦线均匀分布）
local BAGUA_LINE_COUNT = 8
local BAGUA_TWO_PI = math.pi * 2

--- 渲染永驻八卦领域
function M.RenderBaguaAura(nvg, l, camera)
    local boss, cfg, stateKey = CombatSystem.GetBaguaAuraInfo()
    if not boss or not cfg then return end

    if not camera:IsVisible(boss.x, boss.y, l.w, l.h, cfg.radius + 1) then return end

    local tileSize = camera:GetTileSize()
    local sx = (boss.x - camera.x) * tileSize + l.w / 2 + l.x
    local sy = (boss.y - camera.y) * tileSize + l.h / 2 + l.y
    local radius = cfg.radius * tileSize

    -- 颜色优先级：dualState.auraColor > baguaAura.auraColor > bodyColor > 默认金色
    local r, g, b = 180, 160, 80  -- 默认金色
    if boss.dualState and boss.dualState.states and stateKey then
        local stateInfo = boss.dualState.states[stateKey]
        if stateInfo and stateInfo.auraColor then
            r, g, b = stateInfo.auraColor[1], stateInfo.auraColor[2], stateInfo.auraColor[3]
        end
    elseif cfg.auraColor then
        r, g, b = cfg.auraColor[1], cfg.auraColor[2], cfg.auraColor[3]
    elseif boss.bodyColor then
        r, g, b = boss.bodyColor[1], boss.bodyColor[2], boss.bodyColor[3]
    end

    -- 时间动画（每帧递增，用 os.clock 近似）
    if not M._baguaTime then M._baguaTime = 0 end
    M._baguaTime = M._baguaTime + (1.0 / 60.0)
    local time = M._baguaTime

    local pulse = 0.6 + 0.4 * math.sin(time * 2.0)

    -- 1. 地面领域圆形填充（径向渐变，中心亮边缘暗）
    local fillPaint = nvgRadialGradient(nvg, sx, sy, radius * 0.05, radius,
        nvgRGBA(r, g, b, math.floor(50 * pulse)),
        nvgRGBA(r, g, b, 5))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgFillPaint(nvg, fillPaint)
    nvgFill(nvg)

    -- 2. 外圈边框（呼吸脉冲）
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(160 * pulse)))
    nvgStrokeWidth(nvg, 2.0)
    nvgStroke(nvg)

    -- 3. 八卦卦线（旋转的8条径向线，模拟八卦图案）
    local rot = time * 0.8  -- 慢速旋转
    for i = 0, BAGUA_LINE_COUNT - 1 do
        local angle = rot + i * BAGUA_TWO_PI / BAGUA_LINE_COUNT
        local innerR = radius * 0.2
        local outerR = radius * 0.85
        local x1 = sx + math.cos(angle) * innerR
        local y1 = sy + math.sin(angle) * innerR
        local x2 = sx + math.cos(angle) * outerR
        local y2 = sy + math.sin(angle) * outerR

        -- 阳爻（实线）和阴爻（断线）交替
        if i % 2 == 0 then
            -- 阳爻：完整线段
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, x1, y1)
            nvgLineTo(nvg, x2, y2)
            nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(120 * pulse)))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        else
            -- 阴爻：中间断开
            local midR = (innerR + outerR) / 2
            local gapR = (outerR - innerR) * 0.08
            local mx1 = sx + math.cos(angle) * (midR - gapR)
            local my1 = sy + math.sin(angle) * (midR - gapR)
            local mx2 = sx + math.cos(angle) * (midR + gapR)
            local my2 = sy + math.sin(angle) * (midR + gapR)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, x1, y1)
            nvgLineTo(nvg, mx1, my1)
            nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(100 * pulse)))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, mx2, my2)
            nvgLineTo(nvg, x2, y2)
            nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(100 * pulse)))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end
    end

    -- 4. 内圈旋转弧线（3条，反向旋转）
    local innerRot = -time * 1.5
    for j = 0, 2 do
        local arcAngle = innerRot + j * BAGUA_TWO_PI / 3
        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, radius * 0.45, arcAngle, arcAngle + math.pi * 0.4, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(100 * pulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end

    -- 5. 阴阳鱼（中心太极符号简化版）
    local yinYangR = radius * 0.12
    -- 外圆
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, yinYangR)
    nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(180 * pulse)))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    -- S形分割线（简化为两个半圆弧）
    local yinYangRot = time * 2.0
    nvgBeginPath(nvg)
    nvgArc(nvg, sx, sy, yinYangR, yinYangRot, yinYangRot + math.pi, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(r, g, b, math.floor(80 * pulse)))
    nvgFill(nvg)

    -- 6. 中心状态文字标签
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(nvg, nvgRGBA(r, g, b, math.floor(200 * pulse)))
    local label = boss.name or "八卦"
    if boss.dualState and boss.dualState.states and stateKey then
        local stateInfo = boss.dualState.states[stateKey]
        if stateInfo then label = stateInfo.name or label end
    end
    nvgText(nvg, sx, sy - radius - 4, label, nil)
end

-- ============================================================================
-- 套装AOE特效渲染（圆形冲击波 + 内圈光晕，颜色从数据读取）
-- ============================================================================
--- 渲染套装 AOE 特效（十字/环形/旋风等）
function M.RenderSetAoeEffects(nvg, l, camera)
    local effects = CombatSystem.setAoeEffects
    if not effects or #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local se = effects[i]

        if camera:IsVisible(se.x, se.y, l.w, l.h, 4) then
            local sx = (se.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (se.y - camera.y) * tileSize + l.h / 2 + l.y

            local progress = se.elapsed / se.duration
            local c = se.color
            local gc = se.glowColor

            -- 透明度：快速出现，缓慢淡出
            local alpha = 1.0
            if progress < 0.1 then
                alpha = progress / 0.1
            elseif progress > 0.3 then
                alpha = 1.0 - (progress - 0.3) / 0.7
            end
            alpha = math.max(0, math.min(1, alpha))

            -- 扩展动画：快速展开
            local expand = 1.0
            if progress < 0.2 then
                local t = progress / 0.2
                expand = t * (2.0 - t)  -- easeOut
            end

            local radius = se.range * tileSize * expand

            nvgSave(nvg)

            -- 外圈冲击波圆环（从内向外扩散）
            local waveRadius = radius * (0.3 + 0.7 * progress)
            local waveAlpha = math.floor(200 * alpha * (1.0 - progress * 0.5))

            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, waveRadius)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveAlpha))
            nvgStrokeWidth(nvg, 3.0 * (1.0 - progress * 0.5))
            nvgStroke(nvg)

            -- 内圈光晕填充
            local innerR = radius * 0.7 * expand
            local glowPaint = nvgRadialGradient(nvg, sx, sy, 0, innerR,
                nvgRGBA(gc[1], gc[2], gc[3], math.floor(gc[4] * alpha)),
                nvgRGBA(gc[1], gc[2], gc[3], 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, innerR)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)

            -- 第二层外圈波纹（稍慢扩散，增加层次感）
            local wave2Radius = radius * (0.1 + 0.9 * progress)
            local wave2Alpha = math.floor(120 * alpha * (1.0 - progress * 0.7))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, wave2Radius)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], wave2Alpha))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)

            nvgRestore(nvg)
        end
    end
end

-- ============================================================================
-- Buff 光环渲染：玩家身上 buff 期间的持续视觉表现
-- ============================================================================
--- 渲染 Buff 状态光环（火焰护盾/寒冰盾等）
function M.RenderBuffAuras(nvg, l, camera)
    local player = GameState.player
    if not player then return end

    -- 玩家是否在可见范围
    if not camera:IsVisible(player.x, player.y, l.w, l.h, 3) then return end

    -- ── 焚血之躯持续光环（半径3格，强烈燃烧 + 火焰边界） ──
    local burnState = SkillSystem.skillState and SkillSystem.skillState["blood_burn"]
    if burnState and burnState.active then
        local tileSize = camera:GetTileSize()
        local sx = (player.x - camera.x) * tileSize + l.w / 2 + l.x
        local sy = (player.y - camera.y) * tileSize + l.h / 2 + l.y
        local time = GameState.gameTime or 0
        local burnRadius = tileSize * 3.0  -- 半径3格
        local breathPhase = math.sin(time * 2.5) * 0.5 + 0.5  -- 0~1 呼吸

        -- ① 大范围地面燃烧区域（径向渐变填充）
        local groundAlpha = math.floor(35 + 20 * breathPhase)
        local groundPaint = nvgRadialGradient(nvg, sx, sy,
            burnRadius * 0.1, burnRadius * 0.95,
            nvgRGBA(200, 60, 20, groundAlpha),
            nvgRGBA(180, 40, 10, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, burnRadius)
        nvgFillPaint(nvg, groundPaint)
        nvgFill(nvg)

        -- ② 半透明边界线（明确范围，随呼吸微调透明度）
        local borderAlpha = math.floor((60 + 30 * breathPhase))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, burnRadius)
        nvgStrokeColor(nvg, nvgRGBA(255, 100, 30, borderAlpha))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- ④ 自身强烈灼烧特效（脚底大火焰光环）
        local selfGlow = math.floor(70 + 40 * breathPhase)
        local selfRadius = tileSize * 0.7
        local selfPaint = nvgRadialGradient(nvg, sx, sy + tileSize * 0.15,
            selfRadius * 0.05, selfRadius,
            nvgRGBA(255, 100, 20, selfGlow),
            nvgRGBA(200, 40, 10, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy + tileSize * 0.15, selfRadius)
        nvgFillPaint(nvg, selfPaint)
        nvgFill(nvg)

        -- ⑤ 自身火焰粒子上浮（8个，比之前多且大）
        for j = 0, 7 do
            local pAngle = (j / 8) * math.pi * 2 + time * 2.0
            local dist = tileSize * (0.15 + 0.2 * math.sin(time * 2.5 + j * 0.8))
            local px = sx + math.cos(pAngle) * dist
            local rise = math.fmod(time * 0.9 + j * 0.125, 1.0)
            local py = sy - tileSize * (0.1 + 0.6 * rise)
            local pA = math.floor(200 * (1.0 - rise))
            local pR = 2.5 + 1.5 * (1.0 - rise)
            if pA > 15 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, pR)
                nvgFillColor(nvg, nvgRGBA(255, 140, 30, pA))
                nvgFill(nvg)
            end
        end

        -- ⑥ 区域内散布的火星（6个随机飘浮）
        for j = 0, 5 do
            local sparkAngle = time * 0.4 + j * 1.05
            local sparkDist = burnRadius * (0.3 + 0.5 * math.fmod(math.sin(j * 2.3 + time * 0.3) * 0.5 + 0.5, 1.0))
            local sparkX = sx + math.cos(sparkAngle) * sparkDist
            local sparkY = sy + math.sin(sparkAngle) * sparkDist
            local sparkRise = math.fmod(time * 0.7 + j * 0.4, 1.0)
            sparkY = sparkY - tileSize * 0.4 * sparkRise
            local sparkA = math.floor(100 * (1.0 - sparkRise))
            if sparkA > 10 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, sparkX, sparkY, 1.8)
                nvgFillColor(nvg, nvgRGBA(255, 180, 60, sparkA))
                nvgFill(nvg)
            end
        end
    end

    -- ── 浩然正气 buff ──
    local buff = CombatSystem.activeBuffs and CombatSystem.activeBuffs["haoran_zhengqi"]
    if not buff then return end

    local tileSize = camera:GetTileSize()
    local sx = (player.x - camera.x) * tileSize + l.w / 2 + l.x
    local sy = (player.y - camera.y) * tileSize + l.h / 2 + l.y
    local time = GameState.gameTime or 0

    local c = buff.color or {60, 180, 255, 255}
    local remaining = buff.remaining or 0
    local duration = buff.duration or 12

    -- 即将过期闪烁（最后3秒）
    local expireFlicker = 1.0
    if remaining <= 3.0 and remaining > 0 then
        -- 快速闪烁：每0.25秒一次，透明度在0.3~1.0间跳动
        expireFlicker = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(remaining * math.pi * 4))
    end

    -- ═══ ① 脚底呼吸光环（正气蓝椭圆） ═══
    local breathPhase = math.sin(time * 2.5) * 0.5 + 0.5  -- 0~1 呼吸节奏
    local auraRx = tileSize * (0.55 + 0.08 * breathPhase)  -- 水平半径
    local auraRy = tileSize * (0.22 + 0.03 * breathPhase)  -- 竖直半径（扁椭圆）
    local auraAlpha = math.floor((60 + 40 * breathPhase) * expireFlicker)

    -- 径向渐变填充
    local auraPaint = nvgRadialGradient(nvg, sx, sy + tileSize * 0.3,
        auraRx * 0.1, auraRx * 0.9,
        nvgRGBA(c[1], c[2], c[3], auraAlpha),
        nvgRGBA(c[1], c[2], c[3], 0))
    nvgSave(nvg)
    nvgBeginPath(nvg)
    -- 用 save/translate/scale 模拟椭圆
    nvgTranslate(nvg, sx, sy + tileSize * 0.3)
    nvgScale(nvg, 1.0, auraRy / auraRx)
    nvgCircle(nvg, 0, 0, auraRx)
    nvgFillPaint(nvg, auraPaint)
    nvgFill(nvg)
    nvgRestore(nvg)

    -- 光环边缘描边
    local edgeAlpha = math.floor((100 + 50 * breathPhase) * expireFlicker)
    nvgSave(nvg)
    nvgBeginPath(nvg)
    nvgTranslate(nvg, sx, sy + tileSize * 0.3)
    nvgScale(nvg, 1.0, auraRy / auraRx)
    nvgCircle(nvg, 0, 0, auraRx)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], edgeAlpha))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    nvgRestore(nvg)

    -- ═══ ② 三条旋转正气弧线（环绕角色） ═══
    local orbR = tileSize * 0.45  -- 轨道半径
    for j = 0, 2 do
        local baseAngle = j * math.pi * 2 / 3 + time * 1.8  -- 匀速旋转
        local arcLen = math.pi * 0.4  -- 弧线长度（约 72°）
        local arcAlpha = math.floor(160 * expireFlicker)

        -- 每条弧线色相微偏移（蓝→青→蓝白）
        local cr = math.min(255, c[1] + j * 20)
        local cg = math.min(255, c[2] + j * 12)
        local cb = math.min(255, c[3] - j * 8)

        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, orbR, baseAngle, baseAngle + arcLen, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(cr, cg, cb, arcAlpha))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end

    -- ═══ ③ 竖向正气柱光线（角色身体周围淡淡的升腾感） ═══
    local pillarAlpha = math.floor(35 * expireFlicker)
    local pillarW = tileSize * 0.06
    local pillarH = tileSize * 0.9
    -- 两道对称淡光柱
    for j = -1, 1, 2 do
        local px = sx + j * tileSize * 0.18
        local pillarPaint = nvgLinearGradient(nvg,
            px, sy - pillarH * 0.5,
            px, sy + pillarH * 0.3,
            nvgRGBA(c[1], c[2], c[3], pillarAlpha),
            nvgRGBA(c[1], c[2], c[3], 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, px - pillarW * 0.5, sy - pillarH * 0.5, pillarW, pillarH)
        nvgFillPaint(nvg, pillarPaint)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 神器被动「四剑诛灭」剑影特效
-- 四把剑从四个斜角飞向玩家，到达目标时爆出冲击光圈
-- ============================================================================

--- 渲染阵图剑气特效
function M.RenderZhentuSwordEffects(nvg, l, camera)
    local effects = CombatSystem.zhentuSwordEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local e = effects[i]
        local t = e.elapsed / e.duration   -- 0 → 1

        -- 插值：剑从起点飞向目标
        -- 前70%时间飞行，后30%时间冲击光圈消散
        local flyT = math.min(t / 0.70, 1.0)
        -- 使用 ease-out（减速到达）
        local eased = 1.0 - (1.0 - flyT) * (1.0 - flyT)

        local wx = e.startX + (e.targetX - e.startX) * eased
        local wy = e.startY + (e.targetY - e.startY) * eased

        if not camera:IsVisible(wx, wy, l.w, l.h, 2) then goto continue end

        local sx = (wx - camera.x) * tileSize + l.w / 2 + l.x
        local sy = (wy - camera.y) * tileSize + l.h / 2 + l.y

        local c = e.color
        -- 飞行阶段 alpha（全程可见，到达后淡出）
        local alpha
        if t < 0.70 then
            alpha = 0.7 + flyT * 0.3   -- 飞行中逐渐增亮
        else
            alpha = 1.0 - (t - 0.70) / 0.30
        end
        alpha = math.max(0, math.min(1, alpha))
        local a = math.floor(alpha * 255)

        local ang = e.angle
        local cosA = math.cos(ang)
        local sinA = math.sin(ang)

        -- ① 剑身（矩形条）
        local swordLen = tileSize * (0.55 + flyT * 0.1)   -- 飞行时略微拉长
        local swordW   = tileSize * 0.06
        local halfW    = swordW * 0.5
        -- 前向(剑尖方向) & 侧向
        local fx, fy = cosA, sinA
        local rx, ry = -sinA, cosA

        -- 剑尖在当前位置，剑柄在后方
        local tipX = sx + fx * swordLen * 0.35
        local tipY = sy + fy * swordLen * 0.35
        local hiltX = sx - fx * swordLen * 0.65
        local hiltY = sy - fy * swordLen * 0.65

        -- 发光外层
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, tipX, tipY)
        nvgLineTo(nvg, hiltX + rx * halfW * 2.5, hiltY + ry * halfW * 2.5)
        nvgLineTo(nvg, hiltX - rx * halfW * 2.5, hiltY - ry * halfW * 2.5)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(a * 0.30)))
        nvgFill(nvg)

        -- 主剑身
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, tipX, tipY)
        nvgLineTo(nvg, hiltX + rx * halfW, hiltY + ry * halfW)
        nvgLineTo(nvg, hiltX - rx * halfW, hiltY - ry * halfW)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], a))
        nvgFill(nvg)

        -- 剑身高光（沿中线）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, tipX, tipY)
        nvgLineTo(nvg, hiltX, hiltY)
        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(a * 0.6)))
        nvgStrokeWidth(nvg, 1.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)

        -- ② 拖尾（飞行方向反向的渐隐线）
        if flyT < 0.98 then
            local trailLen = tileSize * 0.5 * flyT
            local trailX = sx - fx * trailLen
            local trailY = sy - fy * trailLen
            local trailPaint = nvgLinearGradient(nvg,
                sx, sy, trailX, trailY,
                nvgRGBA(c[1], c[2], c[3], math.floor(a * 0.55)),
                nvgRGBA(c[1], c[2], c[3], 0))
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, sx + rx * halfW * 1.5, sy + ry * halfW * 1.5)
            nvgLineTo(nvg, sx - rx * halfW * 1.5, sy - ry * halfW * 1.5)
            nvgLineTo(nvg, trailX, trailY)
            nvgClosePath(nvg)
            nvgFillPaint(nvg, trailPaint)
            nvgFill(nvg)
        end

        -- ③ 到达冲击光圈（到达目标后展开）
        if flyT >= 0.95 then
            local impactT = (t - 0.70) / 0.30
            impactT = math.max(0, math.min(1, impactT))
            local ringR = tileSize * 0.6 * impactT
            local ringA = math.floor(255 * (1.0 - impactT) * alpha)

            -- 目标中心屏幕坐标
            local tsx = (e.targetX - camera.x) * tileSize + l.w / 2 + l.x
            local tsy = (e.targetY - camera.y) * tileSize + l.h / 2 + l.y

            nvgBeginPath(nvg)
            nvgCircle(nvg, tsx, tsy, ringR)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], ringA))
            nvgStrokeWidth(nvg, 3.0 * (1.0 - impactT * 0.7))
            nvgStroke(nvg)

            -- 内圈填充（更淡）
            nvgBeginPath(nvg)
            nvgCircle(nvg, tsx, tsy, ringR * 0.5)
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(ringA * 0.15)))
            nvgFill(nvg)
        end

        ::continue::
    end
end

return M
