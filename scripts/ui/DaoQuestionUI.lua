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

local function getIntroPos(w, h)
    return w * 0.5, h * 0.35
end

local function getOptionAPos(w, h)
    return w * 0.28, h * 0.58
end

local function getOptionBPos(w, h)
    return w * 0.72, h * 0.58
end

-- ============================================================================
-- 绘制函数
-- ============================================================================

--- 绘制虚空底色
local function drawVoidBg(vg, w, h, alpha)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(C_VOID[1], C_VOID[2], C_VOID[3], math.floor(alpha * 255)))
    nvgFill(vg)
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

--- 绘制逐字浮现文本
local function drawIntroText(vg, elapsed, text, cx, cy)
    local chars = utf8Chars(text)
    local charInterval = 0.12
    local charFadeDur  = 0.25

    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 28)
    nvgTextLetterSpacing(vg, 6)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 测量总宽度以居中
    local totalW = 0
    local charWidths = {}
    for i, ch in ipairs(chars) do
        local adv = nvgTextBounds(vg, 0, 0, ch)
        charWidths[i] = adv
        totalW = totalW + adv
    end

    local startX = cx - totalW * 0.5
    local x = startX

    -- 找到破折号位置，让"——"同时出现
    local dashStart = nil
    for i, ch in ipairs(chars) do
        if ch == "—" and not dashStart then
            dashStart = i
        end
    end

    for i, ch in ipairs(chars) do
        -- 破折号整体同时出现（共享第一个破折号的 charStart）
        local effectiveI = i
        if dashStart and i > dashStart and ch == "—" then
            effectiveI = dashStart
        end

        local charStart = (effectiveI - 1) * charInterval
        local t = math.max(0, math.min(1, (elapsed - charStart) / charFadeDur))
        local alpha = easeOutCubic(t)

        if alpha > 0.001 then
            local offsetY = (1 - alpha) * 8
            nvgFillColor(vg, nvgRGBA(
                C_INTRO_TEXT[1], C_INTRO_TEXT[2], C_INTRO_TEXT[3],
                math.floor(alpha * 220)
            ))
            nvgText(vg, x + charWidths[i] * 0.5, cy + offsetY, ch, nil)
        end

        x = x + charWidths[i]
    end
end

--- 绘制引语文字（完全显示，带淡出）
local function drawIntroTextFull(vg, text, cx, cy, alpha)
    if alpha <= 0 then return end
    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 28)
    nvgTextLetterSpacing(vg, 6)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(C_INTRO_TEXT[1], C_INTRO_TEXT[2], C_INTRO_TEXT[3],
        math.floor(alpha * 220)))
    nvgText(vg, cx, cy, text, nil)
end

--- 引语总显示时长
local function getIntroDuration(text)
    local chars = utf8Chars(text)
    return (#chars - 1) * 0.12 + 0.25 + 0.6
end

--- 绘制选项出现动画
local function drawOptionsAppear(vg, elapsed, optA, optB, optAx, optBx, cy)
    local t = math.min(1, elapsed / 0.8)
    local eased = easeOutBack(t)

    local slideOffset = 120
    local axCurrent = optAx - slideOffset * (1 - eased)
    local bxCurrent = optBx + slideOffset * (1 - eased)
    local alpha = math.floor(eased * 240)

    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 40)
    nvgTextLetterSpacing(vg, 8)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFillColor(vg, nvgRGBA(C_OPTION_NORMAL[1], C_OPTION_NORMAL[2], C_OPTION_NORMAL[3], alpha))
    nvgText(vg, axCurrent, cy, optA, nil)

    nvgFillColor(vg, nvgRGBA(C_OPTION_NORMAL[1], C_OPTION_NORMAL[2], C_OPTION_NORMAL[3], alpha))
    nvgText(vg, bxCurrent, cy, optB, nil)
end

--- 绘制选项呼吸光晕
local function drawOptionGlow(vg, time, x, y, text)
    local breath = 0.5 + 0.5 * math.sin(time * math.pi * 2 / 2.5)

    local glowRadius = 60 + breath * 20
    local glowAlpha = 0.04 + breath * 0.06

    nvgBeginPath(vg)
    nvgCircle(vg, x, y, glowRadius)
    local grad = nvgRadialGradient(vg, x, y, 10, glowRadius,
        nvgRGBAf(C_OPTION_GLOW[1]/255, C_OPTION_GLOW[2]/255, C_OPTION_GLOW[3]/255, glowAlpha),
        nvgRGBAf(C_OPTION_GLOW[1]/255, C_OPTION_GLOW[2]/255, C_OPTION_GLOW[3]/255, 0))
    nvgFillPaint(vg, grad)
    nvgFill(vg)

    nvgFontFaceId(vg, fontId_)
    nvgFillColor(vg, nvgRGBA(C_OPTION_NORMAL[1], C_OPTION_NORMAL[2], C_OPTION_NORMAL[3], 240))
    nvgFontSize(vg, 40)
    nvgTextLetterSpacing(vg, 8)
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

--- 选中项文字（闪白→金色）
local function drawSelectedText(vg, elapsed, x, y, text)
    local flashT = math.min(1, elapsed / 0.15)
    local r = math.floor(255 - flashT * (255 - C_SELECT_FLASH[1]))
    local g = math.floor(255 - flashT * (255 - C_SELECT_FLASH[2]))
    local b = math.floor(255 - flashT * (255 - C_SELECT_FLASH[3]))

    nvgFontFaceId(vg, fontId_)
    nvgFontSize(vg, 40)
    nvgTextLetterSpacing(vg, 8)
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
        nvgFontFaceId(vg, fontId_)
        nvgFontSize(vg, 40)
        nvgTextLetterSpacing(vg, 8)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(C_UNSELECT_FADE[1], C_UNSELECT_FADE[2], C_UNSELECT_FADE[3], alpha))
        nvgText(vg, x, y + driftY, text, nil)
    end
end

--- 引语淡出（选中后 0.4s~1.0s）
local function drawIntroFade(vg, elapsed, text, cx, cy)
    local fadeStart = 0.4
    local fadeDur = 0.6
    local t = math.max(0, math.min(1, (elapsed - fadeStart) / fadeDur))
    local eased = easeInCubic(t)
    local alpha = 1 - eased

    if alpha > 0 then
        local driftY = eased * -15
        drawIntroTextFull(vg, text, cx, cy + driftY, alpha)
    end
end

--- 点击检测
local function hitTestOptions(mx, my, optAx, optBx, cy)
    local hitW, hitH = 180, 70
    if mx >= optAx - hitW/2 and mx <= optAx + hitW/2
       and my >= cy - hitH/2 and my <= cy + hitH/2 then
        return "A"
    end
    if mx >= optBx - hitW/2 and mx <= optBx + hitW/2
       and my >= cy - hitH/2 and my <= cy + hitH/2 then
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
    local introCx, introCy = getIntroPos(logW_, logH_)
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
            drawIntroText(vg, stateTime_, q.intro, introCx, introCy)
            local dur = getIntroDuration(q.intro)
            if stateTime_ >= dur then
                setState(STATE_OPTIONS_APPEAR)
            end
        end

    elseif state_ == STATE_OPTIONS_APPEAR then
        drawVoidBg(vg, logW_, logH_, 1.0)
        drawInkCloudBg(vg, globalTime_, cx, cy, logW_, logH_)
        updateAndDrawParticles(vg, dt, globalTime_, logW_, logH_)

        if q then
            drawIntroTextFull(vg, q.intro, introCx, introCy, 1.0)
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
            drawIntroTextFull(vg, q.intro, introCx, introCy, 1.0)
            drawOptionGlow(vg, globalTime_, optAx, optAy, q.optA)
            drawOptionGlow(vg, globalTime_, optBx, optBy, q.optB)
        end

        -- 点击检测在 HandleUpdate 中处理

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
            -- 引语淡出
            drawIntroFade(vg, stateTime_, q.intro, introCx, introCy)
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
            if GameState.uiOpen == "dao_question" then
                GameState.uiOpen = nil
            end
            -- 必须在回调前销毁 NanoVG 上下文，否则透明覆盖层会拦截所有输入
            local cb = onFinished_
            onFinished_ = nil
            DaoQuestionUI.Destroy()
            if cb then
                cb()
            end
            return  -- nvgCtx_ 已销毁，不能再调用 nvgEndFrame
        end
    end

    nvgEndFrame(vg)
end

-- ============================================================================
-- Update（点击检测）
-- ============================================================================

function HandleDaoQuestionUpdate(eventType, eventData)
    if state_ ~= STATE_WAIT_SELECT then return end

    -- 检测点击（引擎自动将触摸映射为鼠标事件，无需单独处理触摸）
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return end

    local mx = input.mousePosition.x / dpr_
    local my = input.mousePosition.y / dpr_

    local optAx, optAy = getOptionAPos(logW_, logH_)
    local optBx, optBy = getOptionBPos(logW_, logH_)

    local hit = hitTestOptions(mx, my, optAx, optBx, optAy)
    if hit then
        selectedChoice_ = hit
        DaoQuestionSystem.RecordAnswer(questionIndex_, hit)

        -- 记录选中位置（终幕汇聚用）
        local selX = (hit == "A") and optAx or optBx
        selectedPositions_[questionIndex_] = { x = selX, y = optAy }

        print(string.format("[DaoQuestionUI] Q%d selected: %s", questionIndex_, hit))
        setState(STATE_SELECTED)
    end
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 初始化 NanoVG 上下文（幂等）
function DaoQuestionUI.Init()
    if nvgCtx_ then return end

    nvgCtx_ = nvgCreate(1)  -- antialias
    -- 渲染顺序：高于 BreakthroughCelebration (999995)，确保全屏覆盖一切
    nvgSetRenderOrder(nvgCtx_, 999998)

    SubscribeToEvent(nvgCtx_, "NanoVGRender", "HandleDaoQuestionRender")
    SubscribeToEvent("Update", "HandleDaoQuestionUpdate")

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

    lastTime_ = time.elapsedTime

    print("[DaoQuestionUI] Initialized")
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
        DaoQuestionUI.Destroy()  -- 销毁 NanoVG 上下文 + 取消事件订阅 + 清理 uiOpen
        print("[DaoQuestionUI] Aborted")
    end
end

--- 清理资源
function DaoQuestionUI.Destroy()
    if nvgCtx_ then
        UnsubscribeFromEvent(nvgCtx_, "NanoVGRender")
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end
    UnsubscribeFromEvent("Update")
    state_ = STATE_INACTIVE
    if GameState.uiOpen == "dao_question" then
        GameState.uiOpen = nil
    end
    print("[DaoQuestionUI] Destroyed")
end

return DaoQuestionUI
