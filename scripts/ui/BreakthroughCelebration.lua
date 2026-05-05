-- ============================================================================
-- BreakthroughCelebration.lua - 境界突破庆典弹框
-- 大境界突破：全屏金光仪式感弹框 + NanoVG 粒子特效
-- 小境界突破：简洁版弹框
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local T = require("config.UITheme")
local StatNames = require("utils.StatNames")

local BreakthroughCelebration = {}

local overlay_ = nil
local panel_ = nil
local visible_ = false

-- ── NanoVG 粒子专用上下文 ──
local nvgFx_ = nil
local lastTime_ = 0

-- ── 动画状态 ──
local animTime_ = 0
local particles_ = {}
local showAnim_ = false
local isMajor_ = false

-- ── 粒子颜色 ──
local MAJOR_COLORS = {
    {255, 215, 0},    -- 金色
    {255, 180, 50},   -- 暖金
    {255, 240, 150},  -- 亮金
    {255, 160, 30},   -- 橙金
    {255, 255, 200},  -- 白金
}
local MINOR_COLORS = {
    {160, 140, 255},  -- 紫蓝
    {180, 200, 255},  -- 浅蓝
    {200, 170, 255},  -- 淡紫
    {140, 180, 255},  -- 蓝
}

--- 生成粒子群
local function spawnParticles(count, isMajor)
    particles_ = {}
    local colors = isMajor and MAJOR_COLORS or MINOR_COLORS
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 40 + math.random() * 100
        local colorIdx = math.random(1, #colors)
        table.insert(particles_, {
            x = 0, y = 0,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 30,
            maxLife = 1.0 + math.random() * 1.8,
            size = isMajor and (2 + math.random() * 5) or (1.5 + math.random() * 3),
            color = colors[colorIdx],
            delay = math.random() * 0.5,
        })
    end
end

--- 属性名映射（来自共享模块）
local STAT_LABELS = StatNames.SHORT_NAMES

--- 构建属性提升行
local function buildRewardRow(label, value)
    local sign = value > 0 and "+" or ""
    local valStr = value
    if label == "回复" then
        valStr = string.format("%.1f", value)
    end
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        width = "100%",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        children = {
            UI.Label {
                text = label,
                fontSize = T.fontSize.sm,
                fontColor = {180, 180, 200, 220},
            },
            UI.Label {
                text = sign .. valStr,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {100, 255, 150, 255},
            },
        },
    }
end

-- ============================================================================
-- NanoVG 粒子渲染（独立上下文，渲染在 UI 之上）
-- ============================================================================

--- NanoVGRender 回调（全局函数，由引擎事件驱动）
function HandleBreakthroughFxRender(eventType, eventData)
    if not showAnim_ or not nvgFx_ then return end

    local W = graphics.width
    local H = graphics.height
    local now = time.elapsedTime
    local dt = now - lastTime_
    lastTime_ = now
    -- 首帧或异常帧，限制 dt
    if dt <= 0 or dt > 0.1 then dt = 0.016 end

    nvgBeginFrame(nvgFx_, W, H, 1.0)

    animTime_ = animTime_ + dt

    local cx = W * 0.5
    local cy = H * 0.5

    -- ── 大境界：中央光晕脉冲 ──
    if isMajor_ and animTime_ < 3.5 then
        local pulse = math.sin(animTime_ * 3.0) * 0.3 + 0.7
        local glowAlpha = math.max(0, 1.0 - animTime_ / 3.5) * pulse
        local glowR = 80 + animTime_ * 40

        local paint = nvgRadialGradient(nvgFx_, cx, cy, 0, glowR,
            nvgRGBA(255, 215, 0, math.floor(glowAlpha * 70)),
            nvgRGBA(255, 215, 0, 0))
        nvgBeginPath(nvgFx_)
        nvgCircle(nvgFx_, cx, cy, glowR)
        nvgFillPaint(nvgFx_, paint)
        nvgFill(nvgFx_)
    end

    -- ── 小境界：扩散光环 ──
    if not isMajor_ and animTime_ < 2.5 then
        local progress = animTime_ / 2.5
        local ringAlpha = math.max(0, 1.0 - progress) * 0.5
        local ringR = 30 + progress * 60

        nvgBeginPath(nvgFx_)
        nvgCircle(nvgFx_, cx, cy, ringR)
        nvgStrokeColor(nvgFx_, nvgRGBA(160, 140, 255, math.floor(ringAlpha * 255)))
        nvgStrokeWidth(nvgFx_, 2.5)
        nvgStroke(nvgFx_)
    end

    -- ── 粒子更新与渲染 ──
    local alive = false
    for _, p in ipairs(particles_) do
        if animTime_ >= p.delay then
            local t = animTime_ - p.delay
            if t < p.maxLife then
                alive = true
                -- 物理更新
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.vy = p.vy + 20 * dt   -- 轻微重力
                p.vx = p.vx * 0.985     -- 阻力

                local progress = t / p.maxLife
                local alpha = 1.0 - progress * progress  -- 缓出淡去
                local size = p.size * (1.0 - progress * 0.4)

                local c = p.color
                local a = math.floor(alpha * 255)

                -- 发光粒子核心
                nvgBeginPath(nvgFx_)
                nvgCircle(nvgFx_, cx + p.x, cy + p.y, size)
                nvgFillColor(nvgFx_, nvgRGBA(c[1], c[2], c[3], a))
                nvgFill(nvgFx_)

                -- 外发光光晕（大境界粒子更亮）
                if size > 2 then
                    local glowMul = isMajor_ and 0.2 or 0.12
                    nvgBeginPath(nvgFx_)
                    nvgCircle(nvgFx_, cx + p.x, cy + p.y, size * 3)
                    nvgFillColor(nvgFx_, nvgRGBA(c[1], c[2], c[3], math.floor(a * glowMul)))
                    nvgFill(nvgFx_)
                end
            end
        else
            alive = true
        end
    end

    nvgEndFrame(nvgFx_)

    -- 所有粒子结束后停止动画
    if not alive then
        showAnim_ = false
    end
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 显示突破庆典弹框
---@param oldRealm string 旧境界 ID
---@param newRealm string 新境界 ID
function BreakthroughCelebration.Show(oldRealm, newRealm)
    if visible_ then BreakthroughCelebration.Hide() end
    if not overlay_ then return end

    local oldData = GameConfig.REALMS[oldRealm] or {}
    local newData = GameConfig.REALMS[newRealm] or {}
    isMajor_ = newData.isMajor or false
    local realmName = newData.name or newRealm
    local oldRealmName = oldData.name or oldRealm

    -- 启动粒子动画
    animTime_ = 0
    lastTime_ = time.elapsedTime
    showAnim_ = true
    spawnParticles(isMajor_ and 80 or 40, isMajor_)

    -- 属性奖励列表
    local rewardChildren = {}
    local rewards = newData.rewards
    if rewards then
        for _, key in ipairs({"maxHp", "atk", "def", "hpRegen"}) do
            if rewards[key] and rewards[key] > 0 then
                table.insert(rewardChildren, buildRewardRow(STAT_LABELS[key] or key, rewards[key]))
            end
        end
    end

    -- 攻速加成文字
    local atkSpeedBonus = newData.attackSpeedBonus or 0
    local atkSpeedText = nil
    if atkSpeedBonus > 0 then
        atkSpeedText = string.format("攻速加成: +%d%%", math.floor(atkSpeedBonus * 100 + 0.5))
    end

    -- ── 颜色主题 ──
    local accentColor = isMajor_ and {255, 215, 0, 255} or {180, 160, 255, 255}
    local accentGlow  = isMajor_ and {255, 215, 0, 60}  or {160, 140, 255, 50}
    local accentBorder = isMajor_ and {255, 200, 50, 180} or {140, 120, 255, 120}
    local titleText = isMajor_ and "大境界突破" or "境界突破"
    local subtitleText = isMajor_ and "天地灵气涌动，修为大进！" or "修为精进，更上层楼"

    -- ── 构建弹框内容 ──
    local contentChildren = {}

    -- 图标
    table.insert(contentChildren, UI.Label {
        text = isMajor_ and "🌟" or "⚡",
        fontSize = isMajor_ and 48 or 36,
        textAlign = "center",
    })

    -- 标题
    table.insert(contentChildren, UI.Label {
        text = titleText,
        fontSize = isMajor_ and T.fontSize.hero or T.fontSize.xxl,
        fontWeight = "bold",
        fontColor = accentColor,
        textAlign = "center",
    })

    -- 副标题
    table.insert(contentChildren, UI.Label {
        text = subtitleText,
        fontSize = T.fontSize.sm,
        fontColor = {200, 200, 220, 180},
        textAlign = "center",
    })

    -- 分割线
    table.insert(contentChildren, UI.Panel {
        width = "80%", height = 1,
        backgroundColor = accentGlow,
        marginTop = T.spacing.xs,
        marginBottom = T.spacing.xs,
    })

    -- 境界变化：旧 → 新
    table.insert(contentChildren, UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.md,
        children = {
            UI.Label {
                text = oldRealmName,
                fontSize = T.fontSize.md,
                fontColor = {150, 150, 160, 200},
            },
            UI.Label {
                text = "→",
                fontSize = T.fontSize.lg,
                fontColor = accentColor,
            },
            UI.Label {
                text = realmName,
                fontSize = isMajor_ and T.fontSize.xl or T.fontSize.lg,
                fontWeight = "bold",
                fontColor = accentColor,
            },
        },
    })

    -- 属性提升区域
    if #rewardChildren > 0 then
        table.insert(contentChildren, UI.Panel {
            width = "100%",
            backgroundColor = {30, 35, 50, 200},
            borderRadius = T.radius.sm,
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            gap = T.spacing.xs,
            children = rewardChildren,
        })
    end

    -- 攻速加成
    if atkSpeedText then
        table.insert(contentChildren, UI.Label {
            text = atkSpeedText,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = {180, 220, 255, 255},
            textAlign = "center",
        })
    end

    -- 间距
    table.insert(contentChildren, UI.Panel { height = T.spacing.sm })

    -- 确认按钮
    local btnText = isMajor_ and "悟道成功" or "继续修炼"
    table.insert(contentChildren, UI.Button {
        text = btnText,
        width = 160,
        height = 40,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = {255, 255, 255, 255},
        variant = "primary",
        borderRadius = T.radius.md,
        onClick = function(self)
            BreakthroughCelebration.Hide()
        end,
    })

    -- ── 构建全屏弹框 ──
    panel_ = UI.Panel {
        id = "breakthrough_celebration",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = isMajor_ and {0, 0, 0, 190} or {0, 0, 0, 160},
        zIndex = 250,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.sm,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = isMajor_ and 2 or 1,
                borderColor = accentBorder,
                paddingTop = isMajor_ and T.spacing.xl or T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                minWidth = isMajor_ and 320 or 280,
                maxWidth = 360,
                children = contentChildren,
            },
        },
    }

    overlay_:AddChild(panel_)
    visible_ = true
    GameState.uiOpen = "breakthrough_celebration"
end

--- 隐藏弹框
function BreakthroughCelebration.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    visible_ = false
    showAnim_ = false
    particles_ = {}
    animTime_ = 0
    if GameState.uiOpen == "breakthrough_celebration" then
        GameState.uiOpen = nil
    end
end

--- 是否可见
function BreakthroughCelebration.IsVisible()
    return visible_
end

--- 初始化（游戏启动时调用一次）
---@param parentOverlay table
function BreakthroughCelebration.Create(parentOverlay)
    overlay_ = parentOverlay

    -- 创建粒子特效专用 NanoVG 上下文（渲染顺序高于 UI）
    if not nvgFx_ then
        nvgFx_ = nvgCreate(1)  -- antialias
        nvgSetRenderOrder(nvgFx_, 999995)  -- UI = 999990，粒子在 UI 之上
        SubscribeToEvent(nvgFx_, "NanoVGRender", "HandleBreakthroughFxRender")
        lastTime_ = time.elapsedTime
    end
end

--- 销毁
function BreakthroughCelebration.Destroy()
    BreakthroughCelebration.Hide()
    overlay_ = nil
    -- NanoVG 上下文跟随场景生命周期，无需手动销毁
end

return BreakthroughCelebration
