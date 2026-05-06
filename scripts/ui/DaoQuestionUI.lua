-- ============================================================================
-- DaoQuestionUI.lua - 天道问心 全屏NanoVG模态覆盖
-- 极简写意的天人问答表现层，全程NanoVG渲染，无UI框架
-- ============================================================================

local DaoQuestionSystem = require("systems.DaoQuestionSystem")
local GameState = require("core.GameState")

local DaoQuestionUI = {}

-- ============================================================================
-- 状态常量
-- ============================================================================

local STATE_INACTIVE         = 0   -- 未激活
local STATE_ENTER_VOID       = 1   -- 坠入虚空（渐暗）
local STATE_VOID_IDLE        = 2   -- 虚空静默
local STATE_QUESTION_INTRO   = 3   -- 引语逐字浮现
local STATE_OPTIONS_APPEAR   = 4   -- 选项凝聚
local STATE_WAIT_SELECT      = 5   -- 等待点击
local STATE_SELECTED         = 6   -- 选中反馈
local STATE_FADE_OUT         = 7   -- 淡出回归虚空
local STATE_FINALE_CONVERGE  = 8   -- 残光汇聚
local STATE_FINALE_LIGHT     = 9   -- 光柱注入
local STATE_EXIT_VOID        = 10  -- 渐亮退出

-- ============================================================================
-- 色板
-- ============================================================================

local C_VOID           = {10, 8, 18, 255}
local C_STAR_DIM       = {120, 130, 160, 30}
local C_STAR_BRIGHT    = {180, 190, 220, 80}
local C_INTRO_TEXT     = {170, 165, 150}
local C_OPTION_NORMAL  = {220, 215, 200}
local C_OPTION_GLOW    = {255, 235, 180}
local C_SELECT_FLASH   = {255, 225, 140}
local C_SELECT_BLOOM   = {255, 200, 80}
local C_UNSELECT_FADE  = {100, 95, 85}
local C_PILLAR_CORE    = {255, 240, 200}
local C_PILLAR_BLOOM   = {255, 210, 120}

-- ============================================================================
-- 运行时状态（模块级私有）
-- ============================================================================

local nvgCtx_        = nil       -- NanoVG 上下文
local fontId_        = nil       -- 字体句柄
local inkImg_        = nil       -- 水墨云气纹理句柄
local bgImg_         = nil       -- 背景 PNG 句柄
local btnImg_        = nil       -- 按钮 PNG 句柄
local state_         = STATE_INACTIVE
local stateTime_     = 0         -- 当前状态已持续时间
local globalTime_    = 0         -- 全局累计时间（用于粒子/呼吸动画）
local lastTime_      = 0         -- 上一帧 elapsedTime
local questionIndex_ = 0         -- 当前题目索引 (1~5)
local isFirstQuestion_ = true   -- 是否第一道题（VOID_IDLE 仅首题播放）
local selectedChoice_  = nil     -- 当前题目选择: "A" | "B" | nil
local dpr_           = 1         -- 设备像素比
local logW_          = 0         -- 逻辑宽度
local logH_          = 0         -- 逻辑高度

-- 选中位置记忆（终幕汇聚用）
local selectedPositions_ = {}    -- { {x=, y=}, ... }

-- 回调
local onFinished_    = nil       -- 问心结束回调

-- ============================================================================
-- 星尘粒子
-- ============================================================================

local MAX_PARTICLES = 60
local particles_    = {}

local function initParticles(screenW, screenH)
    for i = 1, MAX_PARTICLES do
        particles_[i] = {
            x = math.random() * screenW,
            y = math.random() * screenH,
            vx = (math.random() - 0.5) * 8,
            vy = -math.random() * 6 - 2,
            alpha = math.random() * 0.3 + 0.05,
            radius = math.random() * 1.5 + 0.5,
            twinklePhase = math.random() * 6.28,
        }
    end
end

local function updateAndDrawParticles(vg, dt, time, screenW, screenH)
    for i = 1, MAX_PARTICLES do
        local p = particles_[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt

        if p.y < -10 then p.y = screenH + 10; p.x = math.random() * screenW end
        if p.x < -10 then p.x = screenW + 10 end
        if p.x > screenW + 10 then p.x = -10 end

        local twinkle = 0.5 + 0.5 * math.sin(time * 1.2 + p.twinklePhase)
        local finalAlpha = p.alpha * twinkle

        nvgBeginPath(vg)
        nvgCircle(vg, p.x, p.y, p.radius)
        nvgFillColor(vg, nvgRGBA(
            C_STAR_DIM[1] + math.floor((C_STAR_BRIGHT[1] - C_STAR_DIM[1]) * twinkle),
            C_STAR_DIM[2] + math.floor((C_STAR_BRIGHT[2] - C_STAR_DIM[2]) * twinkle),
            C_STAR_DIM[3] + math.floor((C_STAR_BRIGHT[3] - C_STAR_DIM[3]) * twinkle),
            math.floor(finalAlpha * 255)
        ))
        nvgFill(vg)
    end
end

-- ============================================================================
-- UTF-8 工具
-- ============================================================================

local function utf8Chars(str)
    local chars = {}
    local i = 1
    while i <= #str do
        local byte = string.byte(str, i)
        local charLen = 1
        if byte >= 0xF0 then charLen = 4
        elseif byte >= 0xE0 then charLen = 3
        elseif byte >= 0xC0 then charLen = 2
        end
        chars[#chars + 1] = string.sub(str, i, i + charLen - 1)
        i = i + charLen
    end
    return chars
end

-- ============================================================================
-- 缓动函数
-- ============================================================================

local function easeOutCubic(t)
    local u = 1 - t
    return 1 - u * u * u
end

local function easeInCubic(t)
    return t * t * t
end

local function easeInOutCubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        local u = -2 * t + 2
        return 1 - u * u * u / 2
    end
end

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local u = t - 1
    return 1 + c3 * u * u * u + c1 * u * u
end

local function easeOutExpo(t)
    if t >= 1 then return 1 end
    return 1 - math.pow(2, -10 * t)
end

-- ============================================================================
-- 布局计算
-- ============================================================================

local function getTitlePos(w, h)
    return w * 0.5, h * 0.28
end

local function getSubtitlePos(w, h)
    return w * 0.5, h * 0.36
end

local function getOptionAPos(w, h)
    return w * 0.28, h * 0.60
end

local function getOptionBPos(w, h)
    return w * 0.72, h * 0.60
end

-- ============================================================================
-- 绘制函数
-- ============================================================================

--- 绘制虚空底色（优先使用 PNG，回退到纯色）
local function drawVoidBg(vg, w, h, alpha)
    if bgImg_ then
        local paint = nvgImagePattern(vg, 0, 0, w, h, 0, bgImg_, alpha)
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
    else
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(C_VOID[1], C_VOID[2], C_VOID[3], math.floor(alpha * 255)))
        nvgFill(vg)
    end
end

--- 绘制水墨云气背景层
local function drawInkCloudBg(vg, time, cx, cy, screenW, screenH)
    if not inkImg_ then return end

    nvgSave(vg)

    nvgTranslate(vg, cx, cy)
    nvgRotate(vg, time * 0.015)
    nvgTranslate(vg, -cx, -cy)

    nvgGlobalAlpha(vg, 0.08)

    local margin = 256
    local paint = nvgImagePattern(vg,
        -margin, -margin,
        1024, 1024,
        0, inkImg_, 1.0)

    nvgBeginPath(vg)
    nvgRect(vg, -margin, -margin, screenW + margin * 2, screenH + margin * 2)
    nvgFillPaint(vg, paint)
    nvgFill(vg)

    nvgGlobalAlpha(vg, 1.0)
    nvgRestore(vg)
end

--- 绘制主标题逐字浮现（大号醒目）
local function drawTitleText(vg, elapsed, text, cx, cy)
    local chars = utf8Chars(text)
    local charInterval = 0.15
    local charFadeDur  = 0.3

    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 42)
    nvgTextLetterSpacing(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local totalW = 0
    local charWidths = {}
    for i, ch in ipairs(chars) do
        local adv = nvgTextBounds(vg, 0, 0, ch)
        charWidths[i] = adv
        totalW = totalW + adv
    end

    local startX = cx - totalW * 0.5
    local x = startX

    for i, ch in ipairs(chars) do
        local charStart = (i - 1) * charInterval
        local t = math.max(0, math.min(1, (elapsed - charStart) / charFadeDur))
        local alpha = easeOutCubic(t)

        if alpha > 0.001 then
            local offsetY = (1 - alpha) * 12
            -- 发光描边
            nvgFillColor(vg, nvgRGBA(255, 235, 180, math.floor(alpha * 60)))
            nvgFontBlur(vg, 6)
            nvgText(vg, x + charWidths[i] * 0.5, cy + offsetY, ch, nil)
            -- 主体文字
            nvgFontBlur(vg, 0)
            nvgFillColor(vg, nvgRGBA(255, 245, 220, math.floor(alpha * 255)))
            nvgText(vg, x + charWidths[i] * 0.5, cy + offsetY, ch, nil)
        end

        x = x + charWidths[i]
    end
end

--- 绘制副标题（主标题完成后淡入）
local function drawSubtitleText(vg, elapsed, titleText, subtitleText, cx, cy)
    local titleChars = utf8Chars(titleText)
    local titleDur = (#titleChars - 1) * 0.15 + 0.3
    local delay = titleDur + 0.2
    local fadeT = math.max(0, math.min(1, (elapsed - delay) / 0.5))
    if fadeT <= 0 then return end
    local alpha = easeOutCubic(fadeT)
    local offsetY = (1 - alpha) * 6

    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 22)
    nvgTextLetterSpacing(vg, 4)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(
        C_INTRO_TEXT[1], C_INTRO_TEXT[2], C_INTRO_TEXT[3],
        math.floor(alpha * 200)
    ))
    nvgText(vg, cx, cy + offsetY, subtitleText, nil)
end

--- 绘制主标题（完全显示，带淡出）
local function drawTitleFull(vg, text, cx, cy, alpha)
    if alpha <= 0 then return end
    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 42)
    nvgTextLetterSpacing(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 发光描边
    nvgFillColor(vg, nvgRGBA(255, 235, 180, math.floor(alpha * 60)))
    nvgFontBlur(vg, 6)
    nvgText(vg, cx, cy, text, nil)
    -- 主体
    nvgFontBlur(vg, 0)
    nvgFillColor(vg, nvgRGBA(255, 245, 220, math.floor(alpha * 255)))
    nvgText(vg, cx, cy, text, nil)
end

--- 绘制副标题（完全显示，带淡出）
local function drawSubtitleFull(vg, text, cx, cy, alpha)
    if alpha <= 0 then return end
    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 22)
    nvgTextLetterSpacing(vg, 4)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(
        C_INTRO_TEXT[1], C_INTRO_TEXT[2], C_INTRO_TEXT[3],
        math.floor(alpha * 200)
    ))
    nvgText(vg, cx, cy, text, nil)
end

--- 引语总显示时长（基于主标题 + 副标题淡入延迟）
local function getIntroDuration(titleText)
    local chars = utf8Chars(titleText)
    local titleDur = (#chars - 1) * 0.15 + 0.3
    return titleDur + 0.2 + 0.5 + 0.4  -- 主标题 + 延迟 + 副标题淡入 + 停留
end

--- 绘制毛笔横扫按钮 PNG
local BTN_W = 200  -- 按钮宽度（逻辑像素）
local BTN_H = 56   -- 按钮高度（逻辑像素）
local function drawBtnImage(vg, x, y, alpha)
    if not btnImg_ then return end
    local hw = BTN_W * 0.5
    local hh = BTN_H * 0.5
    local paint = nvgImagePattern(vg, x - hw, y - hh, BTN_W, BTN_H, 0, btnImg_, alpha)
    nvgBeginPath(vg)
    nvgRect(vg, x - hw, y - hh, BTN_W, BTN_H)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end

--- 绘制选项出现动画（带按钮 PNG）
local function drawOptionsAppear(vg, elapsed, optA, optB, optAx, optBx, cy)
    local t = math.min(1, elapsed / 0.8)
    local eased = easeOutBack(t)

    local slideOffset = 120
    local axCurrent = optAx - slideOffset * (1 - eased)
    local bxCurrent = optBx + slideOffset * (1 - eased)
    local alpha = eased

    -- 按钮背景
    drawBtnImage(vg, axCurrent, cy, alpha * 0.85)
    drawBtnImage(vg, bxCurrent, cy, alpha * 0.85)

    -- 文字
    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 30)
    nvgTextLetterSpacing(vg, 1)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFillColor(vg, nvgRGBA(245, 240, 220, math.floor(alpha * 255)))
    nvgText(vg, axCurrent, cy, optA, nil)

    nvgFillColor(vg, nvgRGBA(245, 240, 220, math.floor(alpha * 255)))
    nvgText(vg, bxCurrent, cy, optB, nil)
end

--- 绘制选项呼吸光晕（带按钮 PNG）
local function drawOptionGlow(vg, time, x, y, text)
    local breath = 0.5 + 0.5 * math.sin(time * math.pi * 2 / 2.5)

    -- 按钮背景（呼吸透明度）
    drawBtnImage(vg, x, y, 0.75 + breath * 0.15)

    -- 光晕（椭圆形，匹配横向按钮）
    local glowW = BTN_W * 0.5 + 20 + breath * 10
    local glowH = BTN_H * 0.5 + 15 + breath * 8
    local glowAlpha = 0.04 + breath * 0.05

    nvgBeginPath(vg)
    nvgEllipse(vg, x, y, glowW, glowH)
    local grad = nvgRadialGradient(vg, x, y, 10, glowW,
        nvgRGBAf(C_OPTION_GLOW[1]/255, C_OPTION_GLOW[2]/255, C_OPTION_GLOW[3]/255, glowAlpha),
        nvgRGBAf(C_OPTION_GLOW[1]/255, C_OPTION_GLOW[2]/255, C_OPTION_GLOW[3]/255, 0))
    nvgFillPaint(vg, grad)
    nvgFill(vg)

    -- 文字（暖白色，在深色水墨按钮上醒目）
    nvgFontFaceId(vg, fontId_)
    nvgFillColor(vg, nvgRGBA(245, 240, 220, 245))
    nvgFontSize(vg, 30)
    nvgTextLetterSpacing(vg, 1)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, x, y, text, nil)
end

--- 选中项 Bloom 爆发
local function drawSelectBloom(vg, elapsed, x, y)
    local t = math.min(1, elapsed / 0.4)
    local eased = easeOutExpo(t)

    local radius = 30 + eased * 200
    local alpha = 0.5 * (1 - t)

    if alpha > 0 then
        nvgBeginPath(vg)
        nvgCircle(vg, x, y, radius)
        local grad = nvgRadialGradient(vg, x, y, radius * 0.1, radius,
            nvgRGBAf(C_SELECT_BLOOM[1]/255, C_SELECT_BLOOM[2]/255, C_SELECT_BLOOM[3]/255, alpha),
            nvgRGBAf(C_SELECT_BLOOM[1]/255, C_SELECT_BLOOM[2]/255, C_SELECT_BLOOM[3]/255, 0))
        nvgFillPaint(vg, grad)
        nvgFill(vg)
    end
end

--- 选中项文字（闪白→金色 + 按钮放大）
local function drawSelectedText(vg, elapsed, x, y, text)
    local flashT = math.min(1, elapsed / 0.15)
    local r = math.floor(255 - flashT * (255 - C_SELECT_FLASH[1]))
    local g = math.floor(255 - flashT * (255 - C_SELECT_FLASH[2]))
    local b = math.floor(255 - flashT * (255 - C_SELECT_FLASH[3]))

    -- 按钮背景
    drawBtnImage(vg, x, y, 0.9)

    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 30)
    nvgTextLetterSpacing(vg, 1)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(r, g, b, 255))
    nvgText(vg, x, y, text, nil)
end

--- 未选项淡出
local function drawUnselectedFade(vg, elapsed, x, y, text)
    local fadeStart = 0.2
    local fadeDur = 0.6
    local t = math.max(0, math.min(1, (elapsed - fadeStart) / fadeDur))
    local eased = easeInCubic(t)
    local alpha = math.floor((1 - eased) * 180)

    if alpha > 0 then
        local driftY = eased * -30
        -- 按钮淡出
        drawBtnImage(vg, x, y + driftY, alpha / 255 * 0.5)
        nvgFontFaceId(vg, fontId_)
        nvgFontSize(vg, 30)
        nvgTextLetterSpacing(vg, 1)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(C_UNSELECT_FADE[1], C_UNSELECT_FADE[2], C_UNSELECT_FADE[3], alpha))
        nvgText(vg, x, y + driftY, text, nil)
    end
end

--- 标题+副标题淡出（选中后 0.4s~1.0s）
local function drawTitleSubtitleFade(vg, elapsed, title, subtitle, titleCx, titleCy, subtCx, subtCy)
    local fadeStart = 0.4
    local fadeDur = 0.6
    local t = math.max(0, math.min(1, (elapsed - fadeStart) / fadeDur))
    local eased = easeInCubic(t)
    local alpha = 1 - eased

    if alpha > 0 then
        local driftY = eased * -15
        drawTitleFull(vg, title, titleCx, titleCy + driftY, alpha)
        drawSubtitleFull(vg, subtitle, subtCx, subtCy + driftY, alpha)
    end
end

--- 点击检测（横向按钮区域）
local function hitTestOptions(mx, my, optAx, optBx, cy)
    local hw = BTN_W * 0.5 + 10  -- 比按钮稍大的容错区
    local hh = BTN_H * 0.5 + 10
    -- A 按钮
    if mx >= optAx - hw and mx <= optAx + hw
       and my >= cy - hh and my <= cy + hh then
        return "A"
    end
    -- B 按钮
    if mx >= optBx - hw and mx <= optBx + hw
       and my >= cy - hh and my <= cy + hh then
        return "B"
    end
    return nil
end

--- 终幕：残光汇聚
local function drawConverge(vg, elapsed, cx, cy)
    local t = math.min(1, elapsed / 2.0)
    local eased = easeInOutCubic(t)

    for i = 1, #selectedPositions_ do
        local sp = selectedPositions_[i]
        if sp then
            local px = sp.x + (cx - sp.x) * eased
            local py = sp.y + (cy - sp.y) * eased

            local radius = 12 * (1 - eased * 0.7)
            local bloomR = 40 * (1 - eased * 0.5)

            nvgBeginPath(vg)
            nvgCircle(vg, px, py, bloomR)
            local grad = nvgRadialGradient(vg, px, py, radius, bloomR,
                nvgRGBAf(1.0, 0.88, 0.55, 0.3 + eased * 0.3),
                nvgRGBAf(1.0, 0.88, 0.55, 0))
            nvgFillPaint(vg, grad)
            nvgFill(vg)

            nvgBeginPath(vg)
            nvgCircle(vg, px, py, radius)
            nvgFillColor(vg, nvgRGBA(255, 235, 190, math.floor(180 + eased * 75)))
            nvgFill(vg)
        end
    end
end

--- 终幕：光柱注入
local function drawLightPillar(vg, elapsed, cx, cy, screenW, screenH)
    local t = math.min(1, elapsed / 1.5)
    local eased = easeOutExpo(t)

    local pillarW = 4 + eased * 12
    local pillarH = eased * screenH * 1.2

    -- 外层 bloom
    local bloomW = pillarW + 60
    local feather = 40

    nvgBeginPath(vg)
    nvgRect(vg, cx - bloomW/2, cy - pillarH/2, bloomW, pillarH)
    local grad = nvgBoxGradient(vg, cx - pillarW/2, cy - pillarH/2, pillarW, pillarH,
        0, feather,
        nvgRGBAf(C_PILLAR_BLOOM[1]/255, C_PILLAR_BLOOM[2]/255, C_PILLAR_BLOOM[3]/255, 0.35 * (1 - t * 0.5)),
        nvgRGBAf(C_PILLAR_BLOOM[1]/255, C_PILLAR_BLOOM[2]/255, C_PILLAR_BLOOM[3]/255, 0))
    nvgFillPaint(vg, grad)
    nvgFill(vg)

    -- 核心光柱
    nvgBeginPath(vg)
    nvgRect(vg, cx - pillarW/2, cy - pillarH/2, pillarW, pillarH)
    nvgFillColor(vg, nvgRGBA(
        C_PILLAR_CORE[1], C_PILLAR_CORE[2], C_PILLAR_CORE[3],
        math.floor(255 * (1 - t * 0.3))
    ))
    nvgFill(vg)

    -- t > 0.6 后光柱脉冲闪烁
    if t > 0.6 then
        local pulse = 0.5 + 0.5 * math.sin((t - 0.6) * 25)
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, screenW, screenH)
        nvgFillColor(vg, nvgRGBA(255, 240, 210, math.floor(pulse * 30)))
        nvgFill(vg)
    end
end

-- ============================================================================
-- 状态机
-- ============================================================================

local function setState(newState)
    state_ = newState
    stateTime_ = 0
end

local function getCurrentQuestion()
    if questionIndex_ >= 1 and questionIndex_ <= 5 then
        return DaoQuestionSystem.QUESTIONS[questionIndex_]
    end
    return nil
end

-- ============================================================================
-- 主渲染
-- ============================================================================

function HandleDaoQuestionRender(eventType, eventData)
    if state_ == STATE_INACTIVE then return end
    if not nvgCtx_ then return end

    -- 时间管理
    local now = time.elapsedTime
    local dt = now - lastTime_
    lastTime_ = now
    if dt <= 0 or dt > 0.1 then dt = 0.016 end

    stateTime_ = stateTime_ + dt
    globalTime_ = globalTime_ + dt

    -- 屏幕尺寸
    local W = graphics.width
    local H = graphics.height
    dpr_ = graphics:GetDPR() or 1
    logW_ = W / dpr_
    logH_ = H / dpr_

    local vg = nvgCtx_
    nvgBeginFrame(vg, logW_, logH_, dpr_)

    local cx = logW_ * 0.5
    local cy = logH_ * 0.5
    local titleCx, titleCy = getTitlePos(logW_, logH_)
    local subtCx, subtCy = getSubtitlePos(logW_, logH_)
    local optAx, optAy = getOptionAPos(logW_, logH_)
    local optBx, optBy = getOptionBPos(logW_, logH_)
    local q = getCurrentQuestion()

    -- ================================================================
    -- 各状态渲染
    -- ================================================================

    if state_ == STATE_ENTER_VOID then
        -- 画面渐暗覆盖
        local t = math.min(1, stateTime_ / 1.5)
        local alpha = easeInCubic(t)
        drawVoidBg(vg, logW_, logH_, alpha)

        -- 星尘渐入
        if alpha > 0.3 then
            nvgGlobalAlpha(vg, (alpha - 0.3) / 0.7)
            updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)
            nvgGlobalAlpha(vg, 1.0)
        end

        if t >= 1 then
            if isFirstQuestion_ then
                setState(STATE_VOID_IDLE)
            else
                -- 非首题跳过 VOID_IDLE
                questionIndex_ = 1
                setState(STATE_QUESTION_INTRO)
            end
        end

    elseif state_ == STATE_VOID_IDLE then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)

        if stateTime_ >= 1.0 then
            questionIndex_ = 1
            setState(STATE_QUESTION_INTRO)
        end

    elseif state_ == STATE_QUESTION_INTRO then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)

        if q then
            drawTitleText(vg, stateTime_, q.title, titleCx, titleCy)
            drawSubtitleText(vg, stateTime_, q.title, q.subtitle, subtCx, subtCy)
            local dur = getIntroDuration(q.title)
            if stateTime_ >= dur then
                setState(STATE_OPTIONS_APPEAR)
            end
        end

    elseif state_ == STATE_OPTIONS_APPEAR then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)

        if q then
            drawTitleFull(vg, q.title, titleCx, titleCy, 1.0)
            drawSubtitleFull(vg, q.subtitle, subtCx, subtCy, 1.0)
            drawOptionsAppear(vg, stateTime_, q.optA, q.optB, optAx, optBx, optAy)
        end

        if stateTime_ >= 0.8 then
            setState(STATE_WAIT_SELECT)
        end

    elseif state_ == STATE_WAIT_SELECT then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)

        if q then
            drawTitleFull(vg, q.title, titleCx, titleCy, 1.0)
            drawSubtitleFull(vg, q.subtitle, subtCx, subtCy, 1.0)
            drawOptionGlow(vg, globalTime_, optAx, optAy, q.optA)
            drawOptionGlow(vg, globalTime_, optBx, optBy, q.optB)
        end

        -- 点击检测（内联，避免全局 SubscribeToEvent("Update") 覆盖主游戏循环的 HandleUpdate）
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            local mx = input.mousePosition.x / dpr_
            local my = input.mousePosition.y / dpr_
            local hit = hitTestOptions(mx, my, optAx, optBx, optAy)
            if hit then
                selectedChoice_ = hit
                DaoQuestionSystem.RecordAnswer(questionIndex_, hit)
                local selX = (hit == "A") and optAx or optBx
                selectedPositions_[questionIndex_] = { x = selX, y = optAy }
                print(string.format("[DaoQuestionUI] Q%d selected: %s", questionIndex_, hit))
                setState(STATE_SELECTED)
            end
        end

    elseif state_ == STATE_SELECTED then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)

        if q and selectedChoice_ then
            local selX = (selectedChoice_ == "A") and optAx or optBx
            local selY = optAy
            local selText = (selectedChoice_ == "A") and q.optA or q.optB
            local unselX = (selectedChoice_ == "A") and optBx or optAx
            local unselText = (selectedChoice_ == "A") and q.optB or q.optA

            -- Bloom 爆发
            drawSelectBloom(vg, stateTime_, selX, selY)
            -- 选中项文字
            drawSelectedText(vg, stateTime_, selX, selY, selText)
            -- 未选项淡出
            drawUnselectedFade(vg, stateTime_, unselX, selY, unselText)
            -- 标题+副标题淡出
            drawTitleSubtitleFade(vg, stateTime_, q.title, q.subtitle, titleCx, titleCy, subtCx, subtCy)
        end

        if stateTime_ >= 1.2 then
            setState(STATE_FADE_OUT)
        end

    elseif state_ == STATE_FADE_OUT then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)

        -- 选中项残光收缩消散
        if selectedChoice_ and q then
            local selX = (selectedChoice_ == "A") and optAx or optBx
            local selY = optAy
            local t = math.min(1, stateTime_ / 0.8)
            local alpha = (1 - easeInCubic(t)) * 180
            if alpha > 0 then
                local shrink = (1 - t) * 8
                nvgBeginPath(vg)
                nvgCircle(vg, selX, selY, shrink + 2)
                nvgFillColor(vg, nvgRGBA(C_SELECT_FLASH[1], C_SELECT_FLASH[2], C_SELECT_FLASH[3],
                    math.floor(alpha)))
                nvgFill(vg)
            end
        end

        if stateTime_ >= 0.8 then
            if questionIndex_ < 5 then
                questionIndex_ = questionIndex_ + 1
                selectedChoice_ = nil
                setState(STATE_QUESTION_INTRO)
            else
                setState(STATE_FINALE_CONVERGE)
            end
        end

    elseif state_ == STATE_FINALE_CONVERGE then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)
        drawConverge(vg, stateTime_, cx, cy)

        if stateTime_ >= 2.0 then
            setState(STATE_FINALE_LIGHT)
        end

    elseif state_ == STATE_FINALE_LIGHT then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)
        drawLightPillar(vg, stateTime_, cx, cy, logW_, logH_)

        if stateTime_ >= 1.5 then
            -- 提交会话
            local ok = DaoQuestionSystem.CommitSession()
            if not ok then
                print("[DaoQuestionUI] WARNING: CommitSession failed")
            end
            setState(STATE_EXIT_VOID)
        end

    elseif state_ == STATE_EXIT_VOID then
        -- 黑幕渐淡
        local t = math.min(1, stateTime_ / 1.2)
        local eased = easeOutCubic(t)
        local alpha = 1 - eased

        drawVoidBg(vg, logW_, logH_, alpha)

        -- 星尘也渐隐
        if alpha > 0.1 then
            nvgGlobalAlpha(vg, alpha)
            updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)
            nvgGlobalAlpha(vg, 1.0)
        end

        if t >= 1 then
            setState(STATE_INACTIVE)
            -- 先结束当前帧，再触发回调（上下文保留复用，不销毁）
            nvgEndFrame(vg)
            local cb = onFinished_
            onFinished_ = nil
            DaoQuestionUI.Destroy()  -- 隐藏（重置 state + 清理 uiOpen）
            if cb then
                cb()
            end
            return  -- 已 EndFrame，不要再执行下方的 nvgEndFrame
        end
    end

    nvgEndFrame(vg)
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 初始化 NanoVG 上下文（幂等，只创建一次，后续 Show/hide 复用）
function DaoQuestionUI.Init()
    if nvgCtx_ then return end

    nvgCtx_ = nvgCreate(1)  -- antialias
    -- 渲染顺序：高于 BreakthroughCelebration (999995)，确保全屏覆盖一切
    nvgSetRenderOrder(nvgCtx_, 999998)

    SubscribeToEvent(nvgCtx_, "NanoVGRender", "HandleDaoQuestionRender")
    -- 🔴 不要用全局 SubscribeToEvent("Update", ...) ！
    -- 它会覆盖 main.lua 的 HandleUpdate 订阅，导致主游戏循环停止、画面定格。
    -- 点击检测已内联到 HandleDaoQuestionRender 的 STATE_WAIT_SELECT 分支中。

    fontId_ = nvgCreateFont(nvgCtx_, "dao", "Fonts/MiSans-Regular.ttf")

    -- 尝试加载水墨云气纹理（可选资源，不存在则跳过）
    local ok, img = pcall(nvgCreateImage, nvgCtx_, "Textures/void_ink_cloud.png",
        NVG_IMAGE_REPEATX + NVG_IMAGE_REPEATY)
    if ok and img and img > 0 then
        inkImg_ = img
    else
        inkImg_ = nil
        print("[DaoQuestionUI] void_ink_cloud.png not found, skipping ink cloud layer")
    end

    -- 加载背景 PNG
    local ok2, img2 = pcall(nvgCreateImage, nvgCtx_, "Textures/dao_void_bg.png", 0)
    if ok2 and img2 and img2 > 0 then
        bgImg_ = img2
        print("[DaoQuestionUI] Background PNG loaded")
    else
        bgImg_ = nil
        print("[DaoQuestionUI] dao_void_bg.png not found, using fallback color")
    end

    -- 加载毛笔横扫按钮 PNG
    local ok3, img3 = pcall(nvgCreateImage, nvgCtx_, "Textures/dao_btn_brush.png", 0)
    if ok3 and img3 and img3 > 0 then
        btnImg_ = img3
        print("[DaoQuestionUI] Brush button PNG loaded")
    else
        btnImg_ = nil
        print("[DaoQuestionUI] dao_btn_brush.png not found, buttons will be text-only")
    end

    lastTime_ = time.elapsedTime

    print("[DaoQuestionUI] Initialized (context created)")
end

--- 启动问心流程（由外部调用 TryEnter 成功后调用）
--- @param onFinished function|nil  问心完成后的回调
function DaoQuestionUI.Show(onFinished)
    DaoQuestionUI.Init()

    -- 重置所有状态
    state_           = STATE_ENTER_VOID
    stateTime_       = 0
    globalTime_      = 0
    questionIndex_   = 0
    isFirstQuestion_ = true
    selectedChoice_  = nil
    selectedPositions_ = {}
    onFinished_      = onFinished
    lastTime_        = time.elapsedTime

    -- 初始化屏幕尺寸和粒子
    local W = graphics.width
    local H = graphics.height
    dpr_ = graphics:GetDPR() or 1
    logW_ = W / dpr_
    logH_ = H / dpr_
    initParticles(logW_, logH_)

    GameState.uiOpen = "dao_question"
    print("[DaoQuestionUI] Show - entering void")
end

--- 是否正在进行问心
--- @return boolean
function DaoQuestionUI.IsActive()
    return state_ ~= STATE_INACTIVE
end

--- 强制中止（中途退出，如崩溃恢复）
function DaoQuestionUI.Abort()
    if state_ ~= STATE_INACTIVE then
        DaoQuestionSystem.AbortSession()
        DaoQuestionUI.Destroy()  -- 隐藏 + 清理 uiOpen（保留上下文复用）
        print("[DaoQuestionUI] Aborted")
    end
end

--- 隐藏并重置状态（不销毁 NanoVG 上下文，下次 Show 复用）
function DaoQuestionUI.Destroy()
    -- 🔴 不要销毁 nvgCtx_！字体和图片句柄绑定在上下文上，
    -- 反复 nvgDelete + nvgCreate + nvgCreateFont/Image 会导致 GPU 显存泄漏，
    -- 表现为每次答题动画越来越卡。
    -- 只需将 state_ 设为 INACTIVE，HandleDaoQuestionRender 首行会 early return。
    state_ = STATE_INACTIVE
    if GameState.uiOpen == "dao_question" then
        GameState.uiOpen = nil
    end
    print("[DaoQuestionUI] Hidden (context preserved for reuse)")
end

--- 彻底销毁 NanoVG 上下文（仅在不再需要问心系统时调用）
function DaoQuestionUI.Shutdown()
    if nvgCtx_ then
        UnsubscribeFromEvent(nvgCtx_, "NanoVGRender")
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end
    state_ = STATE_INACTIVE
    fontId_ = nil
    bgImg_ = nil
    btnImg_ = nil
    inkImg_ = nil
    if GameState.uiOpen == "dao_question" then
        GameState.uiOpen = nil
    end
    print("[DaoQuestionUI] Shutdown (context destroyed)")
end

return DaoQuestionUI
