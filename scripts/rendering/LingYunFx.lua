-- ============================================================================
-- LingYunFx.lua - 灵韵拾取粒子特效
-- 三层视觉反馈：
--   1. 紫色宝石粒子从拾取点弹出散落（错开延迟）
--   2. 粒子逐颗沿弧线飞向屏幕顶部 💎 货币栏，带拖尾光效
--   3. 每颗到达时：放射碎光爆发 + BottomBar 弹跳闪光
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState  = require("core.GameState")

local LingYunFx = {}

-- ── math 局部化（避免每次全局查找） ──
local sin, cos, floor, min, max, random, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.random, math.abs, math.pi

-- ── NanoVG 专用上下文 ──
local nvgFx_ = nil
local lastTime_ = 0

-- ── 活跃粒子池 ──
local gems_ = {}        -- 弹出阶段的宝石粒子
local flyGems_ = {}     -- 飞行阶段的宝石粒子
local burstParticles_ = {} -- 到达爆发碎光粒子

-- ── 待处理的拾取队列（世界坐标，由 LootSystem 写入，WorldRenderer 消费） ──
local pendingPickups_ = {}

-- ── 目标位置（屏幕坐标，由 BottomBar 设置） ──
local targetX_ = 60
local targetY_ = 20

-- ── 到达回调 ──
local onArriveCallback_ = nil

-- ── 颜色配置 ──
local GEM_COLORS = {
    {180, 120, 255},   -- 紫
    {200, 150, 255},   -- 亮紫
    {160, 100, 240},   -- 深紫
    {220, 180, 255},   -- 浅紫
    {140, 80,  220},   -- 暗紫
}

-- ── 常量 ──
local SCATTER_DURATION  = 0.65   -- 弹出散落持续时间（加长，增强存在感）
local FLY_STAGGER_DELAY = 0.12   -- 每颗宝石飞行的间隔延迟（错开飞行核心）
local FLY_DURATION      = 0.50   -- 单颗飞行持续时间
local TRAIL_LENGTH      = 10     -- 拖尾节点数（增多，更华丽）
local GEM_SIZE_MIN      = 4.0    -- 加大宝石尺寸
local GEM_SIZE_MAX      = 6.5
local GRAVITY           = 140    -- 弹出阶段重力（减小，延长滞空）
local BURST_COUNT       = 8      -- 到达爆发碎光数量
local BURST_LIFE        = 0.35   -- 碎光存活时间

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 生成弹出宝石粒子（带错开飞行延迟）
---@param sx number 屏幕 X
---@param sy number 屏幕 Y
---@param count number 粒子数量
local function spawnScatterGems(sx, sy, count)
    for i = 1, count do
        local angle = -pi / 2 + (random() - 0.5) * pi * 1.4
        local speed = 100 + random() * 80
        local ci = random(1, #GEM_COLORS)
        local gem = {
            phase = "scatter",
            x = sx + (random() - 0.5) * 10,
            y = sy,
            vx = cos(angle) * speed,
            vy = sin(angle) * speed,
            elapsed = 0,
            size = GEM_SIZE_MIN + random() * (GEM_SIZE_MAX - GEM_SIZE_MIN),
            color = GEM_COLORS[ci],
            rotation = random() * pi * 2,
            rotSpeed = (random() - 0.5) * 10,
            -- 错开飞行：第 i 颗宝石在散落结束后再等 (i-1)*STAGGER 秒才起飞
            flyDelay = (i - 1) * FLY_STAGGER_DELAY,
            flyWaited = 0,
            -- 飞行阶段
            flyStartX = 0,
            flyStartY = 0,
            flyElapsed = 0,
            trail = {},
        }
        table.insert(gems_, gem)
    end
end

--- 生成到达爆发碎光
---@param x number 屏幕 X（目标位置）
---@param y number 屏幕 Y
---@param color table {r,g,b} 宝石颜色
local function spawnBurst(x, y, color)
    for i = 1, BURST_COUNT do
        local angle = (i - 1) / BURST_COUNT * pi * 2 + random() * 0.4
        local speed = 60 + random() * 50
        table.insert(burstParticles_, {
            x = x,
            y = y,
            vx = cos(angle) * speed,
            vy = sin(angle) * speed,
            life = BURST_LIFE,
            elapsed = 0,
            size = 1.5 + random() * 2.0,
            color = color,
        })
    end
end

--- 绘制单颗宝石（菱形+高光）
---@param nvg number
---@param x number
---@param y number
---@param size number
---@param color table {r,g,b}
---@param alpha number 0~255
---@param rot number 旋转弧度
local function drawGem(nvg, x, y, size, color, alpha, rot)
    local r, g, b = color[1], color[2], color[3]
    local a = floor(alpha)
    if a <= 0 then return end

    nvgSave(nvg)
    nvgTranslate(nvg, x, y)
    nvgRotate(nvg, rot)

    -- 宝石主体（菱形）
    local s = size
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, 0, -s * 1.2)
    nvgLineTo(nvg, s, 0)
    nvgLineTo(nvg, 0, s * 0.8)
    nvgLineTo(nvg, -s, 0)
    nvgClosePath(nvg)

    -- 渐变填充（从亮到暗）
    local grad = nvgLinearGradient(nvg, -s, -s, s, s,
        nvgRGBA(min(r + 80, 255), min(g + 80, 255), min(b + 80, 255), a),
        nvgRGBA(floor(r * 0.6), floor(g * 0.6), floor(b * 0.6), a))
    nvgFillPaint(nvg, grad)
    nvgFill(nvg)

    -- 高光（上半部分小三角）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, 0, -s * 1.2)
    nvgLineTo(nvg, s * 0.5, -s * 0.2)
    nvgLineTo(nvg, -s * 0.5, -s * 0.2)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, floor(a * 0.35)))
    nvgFill(nvg)

    -- 外发光
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, 0, size * 2.5)
    nvgFillColor(nvg, nvgRGBA(r, g, b, floor(a * 0.12)))
    nvgFill(nvg)

    nvgRestore(nvg)
end

--- 三次贝塞尔插值
local function bezier3(t, p0, p1, p2, p3)
    local u = 1 - t
    return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3
end

-- ============================================================================
-- NanoVG 渲染回调
-- ============================================================================

function HandleLingYunFxRender(eventType, eventData)
    if #gems_ == 0 and #flyGems_ == 0 and #burstParticles_ == 0 then return end
    if not nvgFx_ then return end

    local W = graphics.width
    local H = graphics.height
    local dpr = graphics:GetDPR() or 1
    local logW = W / dpr
    local logH = H / dpr
    local now = time.elapsedTime
    local dt = now - lastTime_
    lastTime_ = now
    if dt <= 0 or dt > 0.1 then dt = 0.016 end

    nvgBeginFrame(nvgFx_, logW, logH, dpr)

    -- ================================================================
    -- 阶段1: 弹出散落 + 悬浮等待
    -- ================================================================
    local i = 1
    while i <= #gems_ do
        local g = gems_[i]
        g.elapsed = g.elapsed + dt
        g.rotation = g.rotation + g.rotSpeed * dt

        if g.phase == "scatter" then
            local progress = g.elapsed / SCATTER_DURATION

            -- 物理更新（散落末段减速，营造悬浮感）
            local dampFactor = progress > 0.7 and (1.0 - (progress - 0.7) / 0.3 * 0.7) or 1.0
            g.x = g.x + g.vx * dt * dampFactor
            g.y = g.y + g.vy * dt * dampFactor
            g.vy = g.vy + GRAVITY * dt * dampFactor
            g.vx = g.vx * 0.98

            if progress >= 1.0 then
                -- 转入等待飞行阶段
                g.phase = "wait_fly"
                g.flyStartX = g.x
                g.flyStartY = g.y
                g.flyWaited = 0
            end
            -- 绘制散落中的宝石
            drawGem(nvgFx_, g.x, g.y, g.size, g.color, 255, g.rotation)
            i = i + 1

        elseif g.phase == "wait_fly" then
            -- 等待错开延迟，轻微浮动
            g.flyWaited = g.flyWaited + dt
            local floatY = sin(g.flyWaited * 6) * 2
            local floatAlpha = 200 + floor(sin(g.flyWaited * 10) * 55) -- 闪烁
            drawGem(nvgFx_, g.flyStartX, g.flyStartY + floatY, g.size, g.color, floatAlpha, g.rotation)

            if g.flyWaited >= g.flyDelay then
                -- 开始飞行
                g.phase = "fly"
                g.flyElapsed = 0
                g.trail = {}
                table.insert(flyGems_, g)
                table.remove(gems_, i)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end

    -- ================================================================
    -- 阶段2: 弧线飞行 + 拖尾（逐颗到达）
    -- ================================================================
    local j = 1
    while j <= #flyGems_ do
        local g = flyGems_[j]
        g.flyElapsed = g.flyElapsed + dt

        local progress = g.flyElapsed / FLY_DURATION
        -- ease-in-out 缓动
        local t = progress < 0.5
            and 2 * progress * progress
            or 1 - (-2 * progress + 2) * (-2 * progress + 2) / 2

        if progress >= 1.0 then
            -- 到达目标 → 生成爆发碎光
            spawnBurst(targetX_, targetY_, g.color)
            table.remove(flyGems_, j)
            -- 触发到达回调（每颗都触发，逐颗弹跳）
            if onArriveCallback_ then
                onArriveCallback_()
            end
        else
            -- 贝塞尔弧线
            local sx, sy = g.flyStartX, g.flyStartY
            local tx, ty = targetX_, targetY_
            local dx = tx - sx
            local dy = ty - sy
            local cp1x = sx + dx * 0.2
            local cp1y = sy - abs(dy) * 0.5 - 40
            local cp2x = sx + dx * 0.7
            local cp2y = ty - 30

            local cx = bezier3(t, sx, cp1x, cp2x, tx)
            local cy = bezier3(t, sy, cp1y, cp2y, ty)

            -- 记录拖尾
            table.insert(g.trail, 1, {x = cx, y = cy})
            if #g.trail > TRAIL_LENGTH then
                g.trail[TRAIL_LENGTH + 1] = nil
            end

            -- 绘制拖尾（渐变宽度 + 渐隐）
            local cr, cg, cb = g.color[1], g.color[2], g.color[3]
            for ti = #g.trail, 2, -1 do
                local tp = g.trail[ti]
                local tp2 = g.trail[ti - 1]
                local frac = (ti - 1) / TRAIL_LENGTH
                local trailAlpha = (1 - frac) * 0.7
                local trailWidth = g.size * (1 - frac) * 2.0 + 0.5

                nvgBeginPath(nvgFx_)
                nvgMoveTo(nvgFx_, tp.x, tp.y)
                nvgLineTo(nvgFx_, tp2.x, tp2.y)
                nvgStrokeColor(nvgFx_, nvgRGBA(cr, cg, cb, floor(trailAlpha * 255)))
                nvgStrokeWidth(nvgFx_, trailWidth)
                nvgLineCap(nvgFx_, NVG_ROUND)
                nvgStroke(nvgFx_)
            end

            -- 拖尾头部发光
            if #g.trail >= 1 then
                nvgBeginPath(nvgFx_)
                nvgCircle(nvgFx_, cx, cy, g.size * 3.5)
                nvgFillColor(nvgFx_, nvgRGBA(cr, cg, cb, 40))
                nvgFill(nvgFx_)
            end

            -- 飞行中宝石（逐渐缩小 + 闪烁）
            local flyScale = 1.0 - progress * 0.3
            local shimmer = 220 + floor(sin(g.flyElapsed * 18) * 35)
            g.rotation = g.rotation + g.rotSpeed * dt * 2.5
            drawGem(nvgFx_, cx, cy, g.size * flyScale, g.color, shimmer, g.rotation)

            j = j + 1
        end
    end

    -- ================================================================
    -- 阶段3: 到达爆发碎光
    -- ================================================================
    local k = 1
    while k <= #burstParticles_ do
        local p = burstParticles_[k]
        p.elapsed = p.elapsed + dt

        if p.elapsed >= p.life then
            table.remove(burstParticles_, k)
        else
            -- 物理更新（快速扩散 + 减速）
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vx = p.vx * 0.92
            p.vy = p.vy * 0.92

            local progress = p.elapsed / p.life
            local alpha = (1.0 - progress * progress) * 255 -- 缓出淡去
            local size = p.size * (1.0 - progress * 0.5)
            local cr, cg, cb = p.color[1], p.color[2], p.color[3]

            -- 碎光核心
            nvgBeginPath(nvgFx_)
            nvgCircle(nvgFx_, p.x, p.y, size)
            nvgFillColor(nvgFx_, nvgRGBA(
                min(cr + 60, 255),
                min(cg + 60, 255),
                min(cb + 60, 255),
                floor(alpha)))
            nvgFill(nvgFx_)

            -- 碎光光晕
            nvgBeginPath(nvgFx_)
            nvgCircle(nvgFx_, p.x, p.y, size * 3)
            nvgFillColor(nvgFx_, nvgRGBA(cr, cg, cb, floor(alpha * 0.15)))
            nvgFill(nvgFx_)

            k = k + 1
        end
    end

    nvgEndFrame(nvgFx_)
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 初始化（游戏启动时调用一次）
function LingYunFx.Init()
    if not nvgFx_ then
        nvgFx_ = nvgCreate(1)
        nvgSetRenderOrder(nvgFx_, 999993)  -- UI=999990 之上，Breakthrough=999995 之下
        SubscribeToEvent(nvgFx_, "NanoVGRender", "HandleLingYunFxRender")
        lastTime_ = time.elapsedTime
    end
end

--- 设置飞行目标位置（屏幕坐标）
---@param x number
---@param y number
function LingYunFx.SetTarget(x, y)
    targetX_ = x
    targetY_ = y
end

--- 设置到达回调
---@param fn function
function LingYunFx.SetOnArrive(fn)
    onArriveCallback_ = fn
end

--- 在世界坐标位置生成灵韵拾取特效
---@param worldX number 世界坐标 X
---@param worldY number 世界坐标 Y
---@param amount number 灵韵数量（影响粒子数）
---@param camera table 相机对象
---@param layout table {x, y, w, h} 世界渲染区域
function LingYunFx.Spawn(worldX, worldY, amount, camera, layout)
    if not nvgFx_ then return end
    local tileSize = camera:GetTileSize()
    local sx = (worldX - camera.x) * tileSize + layout.w / 2 + layout.x
    local sy = (worldY - camera.y) * tileSize + layout.h / 2 + layout.y

    local count = min(6, max(2, floor(amount / 2) + 1))
    spawnScatterGems(sx, sy, count)
end

--- 将拾取请求加入待处理队列（由 LootSystem 调用，无需相机引用）
---@param worldX number 世界坐标 X
---@param worldY number 世界坐标 Y
---@param amount number 灵韵数量
function LingYunFx.QueuePickup(worldX, worldY, amount)
    table.insert(pendingPickups_, { x = worldX, y = worldY, amount = amount })
end

--- 消费待处理队列，将世界坐标转为屏幕坐标并生成粒子（由 WorldRenderer 每帧调用）
---@param camera table 相机对象
---@param layout table {x, y, w, h} 世界渲染区域
function LingYunFx.ProcessPending(camera, layout)
    if #pendingPickups_ == 0 then return end
    for _, p in ipairs(pendingPickups_) do
        LingYunFx.Spawn(p.x, p.y, p.amount, camera, layout)
    end
    for i = 1, #pendingPickups_ do pendingPickups_[i] = nil end
end

--- 是否有活跃粒子
---@return boolean
function LingYunFx.IsActive()
    return #gems_ > 0 or #flyGems_ > 0 or #burstParticles_ > 0
end

--- 销毁
function LingYunFx.Destroy()
    gems_ = {}
    flyGems_ = {}
    burstParticles_ = {}
end

return LingYunFx
