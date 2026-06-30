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
local SkillData = require("config.SkillData")

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

-- ── 自动关闭定时 ──
local autoCloseTimer_ = 0
local AUTO_CLOSE_DELAY = 2.0  -- 粒子结束后 2 秒自动关闭

-- ── 粒子颜色（使用 UITheme 语义色为基础） ──
local MAJOR_COLORS = {
    {255, 220, 150},  -- T.color.gold 系
    {255, 180, 50},   -- 暖金
    {255, 240, 150},  -- 亮金
    {200, 160, 80},   -- T.color.goldDark 系
    {255, 255, 200},  -- 白金
}
local MINOR_COLORS = {
    {160, 140, 255},  -- 紫蓝
    {120, 180, 255},  -- T.color.info 系
    {200, 170, 255},  -- 淡紫
    {180, 130, 255},  -- T.color.qualityPurple 系
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

--- 属性行前缀 emoji
local STAT_EMOJI = {
    maxHp = "❤️",
    atk = "⚔️",
    def = "🛡️",
    hpRegen = "💚",
    attackSpeed = "⚡",
}

--- 构建属性提升行
local function buildRewardRow(label, value, statKey)
    local sign = value > 0 and "+" or ""
    local valStr = value
    if label == "回复" then
        valStr = string.format("%.1f", value)
    end
    local emoji = (statKey and STAT_EMOJI[statKey]) or ""
    local displayLabel = emoji ~= "" and (emoji .. " " .. label) or label
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        width = "100%",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        children = {
            UI.Label {
                text = displayLabel,
                fontSize = T.fontSize.sm,
                fontColor = T.color.textSecondary,
            },
            UI.Label {
                text = sign .. valStr,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.success,
            },
        },
    }
end

-- ============================================================================
-- NanoVG 粒子渲染（local 函数，通过 SubscribeToEvent 绑定）
-- ============================================================================

--- NanoVGRender 回调
local function handleBreakthroughFxRender(eventType, eventData)
    if not nvgFx_ then return end

    -- 自动关闭倒计时（粒子结束后）
    if not showAnim_ then
        if autoCloseTimer_ > 0 then
            local now = time.elapsedTime
            local dt2 = now - lastTime_
            lastTime_ = now
            if dt2 <= 0 or dt2 > 0.1 then dt2 = 0.016 end
            autoCloseTimer_ = autoCloseTimer_ - dt2
            if autoCloseTimer_ <= 0 then
                BreakthroughCelebration.Hide()
            end
        end
        return
    end

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
            nvgRGBA(255, 220, 150, math.floor(glowAlpha * 70)),
            nvgRGBA(255, 220, 150, 0))
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

                local pProgress = t / p.maxLife
                local alpha = 1.0 - pProgress * pProgress  -- 缓出淡去
                local size = p.size * (1.0 - pProgress * 0.4)

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

    -- 粒子全部结束 → 启动自动关闭计时
    if not alive and showAnim_ then
        showAnim_ = false
        autoCloseTimer_ = AUTO_CLOSE_DELAY
    end
end

--- Update 回调（驱动自动关闭计时器）
-- 自动关闭逻辑在 handleBreakthroughFxRender 中处理（不另开 Update 订阅以避免覆盖主循环）

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
    autoCloseTimer_ = 0
    lastTime_ = time.elapsedTime
    showAnim_ = true
    spawnParticles(isMajor_ and 80 or 40, isMajor_)

    -- 属性奖励列表
    local rewardChildren = {}
    local rewards = newData.rewards
    if rewards then
        for _, key in ipairs({"maxHp", "atk", "def", "hpRegen"}) do
            if rewards[key] and rewards[key] > 0 then
                table.insert(rewardChildren, buildRewardRow(STAT_LABELS[key] or key, rewards[key], key))
            end
        end
    end

    -- 攻速加成（只在比上一阶有增加时才显示）
    local oldAtkSpeed = oldData.attackSpeedBonus or 0
    local newAtkSpeed = newData.attackSpeedBonus or 0
    local atkSpeedBonus = (newAtkSpeed > oldAtkSpeed) and (newAtkSpeed - oldAtkSpeed) or 0

    -- ── 颜色主题（使用 UITheme token） ──
    local accentColor = isMajor_ and T.color.gold or T.color.qualityPurple
    local accentGlow  = isMajor_ and {255, 220, 150, 60} or {160, 140, 255, 50}
    local accentBorder = isMajor_ and {255, 200, 50, 180} or {140, 120, 255, 120}
    local titleText = "突破成功！"
    local subtitleText = isMajor_ and "天地灵气涌动，修为大进！" or "修为精进，更上层楼"

    -- ── 构建弹框内容 ──
    local contentChildren = {}

    -- 图标 + 光晕背景圆
    local iconGlowColor = isMajor_ and {255, 220, 120, 40} or {140, 120, 255, 35}
    table.insert(contentChildren, UI.Panel {
        width = isMajor_ and 72 or 56,
        height = isMajor_ and 72 or 56,
        borderRadius = isMajor_ and 36 or 28,
        backgroundColor = iconGlowColor,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label {
                text = isMajor_ and "🌟" or "⚡",
                fontSize = isMajor_ and 40 or 28,
                textAlign = "center",
            },
        },
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
        fontColor = T.color.textSecondary,
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
                fontColor = T.color.textMuted,
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

    -- 攻速加成（与属性行统一样式，插入 rewardChildren）
    if atkSpeedBonus > 0 then
        local atkSpeedLabel = string.format("+%d%%", math.floor(atkSpeedBonus * 100 + 0.5))
        table.insert(rewardChildren, UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            width = "100%",
            paddingLeft = T.spacing.sm,
            paddingRight = T.spacing.sm,
            children = {
                UI.Label {
                    text = "⚡ 攻速",
                    fontSize = T.fontSize.sm,
                    fontColor = T.color.textSecondary,
                },
                UI.Label {
                    text = atkSpeedLabel,
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = T.color.success,
                },
            },
        })
    end

    -- 属性提升区域
    if #rewardChildren > 0 then
        table.insert(contentChildren, UI.Panel {
            width = "100%",
            backgroundColor = T.color.surfaceDeep,
            borderRadius = T.radius.sm,
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            gap = T.spacing.xs,
            children = rewardChildren,
        })
    end

    -- ── 技能解锁展示 ──
    local classId = (GameState.player and GameState.player.classId) or GameConfig.PLAYER_CLASS
    local unlockedSkills = {}
    for skillId, skillDef in pairs(SkillData.Skills) do
        if skillDef.unlockRealm == newRealm and skillDef.classId == classId then
            table.insert(unlockedSkills, skillDef)
        end
    end

    local enhancement = SkillData.GetRealmEnhancement(newRealm, classId)
    local enhancementDesc = ""
    local enhancedSkill = nil
    if enhancement then
        enhancementDesc = SkillData.GetRealmEnhancementDynamicDescription(newRealm, classId, GameState.player)
        if enhancement.enhancedSkill then
            enhancedSkill = SkillData.Skills[enhancement.enhancedSkill]
        end
    end

    if #unlockedSkills > 0 or enhancement then
        -- 分割线
        table.insert(contentChildren, UI.Panel {
            width = "80%", height = 1,
            backgroundColor = accentGlow,
            marginTop = T.spacing.xs,
            marginBottom = T.spacing.xs,
        })

        table.insert(contentChildren, UI.Label {
            text = "🔓 解锁技能",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = accentColor,
            textAlign = "center",
        })

        for _, skill in ipairs(unlockedSkills) do
            local typeLabel = ""
            if skill.type == "passive" or skill.type == "sword_shield_passive"
                or skill.type == "toggle_passive" or skill.type == "charge_passive"
                or skill.type == "nth_cast_trigger" or skill.type == "accumulate_trigger" then
                typeLabel = "[被动]"
            else
                typeLabel = "[主动]"
            end

            table.insert(contentChildren, UI.Panel {
                width = "100%",
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = accentGlow,
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.sm,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                gap = T.spacing.xxs,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.sm,
                        children = {
                            UI.Label {
                                text = skill.icon or "⚡",
                                fontSize = T.fontSize.xl,
                            },
                            UI.Panel {
                                flexDirection = "column",
                                flexShrink = 1,
                                gap = 2,
                                children = {
                                    UI.Label {
                                        text = (skill.name or skill.id) .. " " .. typeLabel,
                                        fontSize = T.fontSize.sm,
                                        fontWeight = "bold",
                                        fontColor = T.color.textPrimary,
                                    },
                                    UI.Label {
                                        text = skill.description or "",
                                        fontSize = T.fontSize.xxs,
                                        fontColor = T.color.textSecondary,
                                        flexShrink = 1,
                                    },
                                },
                            },
                        },
                    },
                },
            })
        end

        if enhancement then
            local enhancedName = (enhancedSkill and enhancedSkill.name)
                or enhancement.enhancedSkill
                or "既有技能"
            local displayName = enhancedName .. "强化"
            if enhancement.name and enhancement.name ~= "" then
                displayName = displayName .. " · " .. enhancement.name
            end

            table.insert(contentChildren, UI.Panel {
                width = "100%",
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = accentGlow,
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.sm,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                gap = T.spacing.xxs,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.sm,
                        children = {
                            UI.Label {
                                text = enhancement.icon or (enhancedSkill and enhancedSkill.icon) or "⬆️",
                                fontSize = T.fontSize.xl,
                            },
                            UI.Panel {
                                flexDirection = "column",
                                flexShrink = 1,
                                gap = 2,
                                children = {
                                    UI.Label {
                                        text = displayName .. " [强化]",
                                        fontSize = T.fontSize.sm,
                                        fontWeight = "bold",
                                        fontColor = T.color.textPrimary,
                                    },
                                    UI.Label {
                                        text = enhancementDesc,
                                        fontSize = T.fontSize.xxs,
                                        fontColor = T.color.textSecondary,
                                        flexShrink = 1,
                                    },
                                },
                            },
                        },
                    },
                },
            })
        end
    end

    -- ── 仙体解锁展示（首次渡劫成功解锁仙人之体）──
    if newRealm == "asc_1" then
        local AscensionConfig = require("config.AscensionConfig")
        local bodyProfile = AscensionConfig.GROWTH_PROFILES and AscensionConfig.GROWTH_PROFILES["immortal_body_1"]
        if bodyProfile then
            table.insert(contentChildren, UI.Panel {
                width = "80%", height = 1,
                backgroundColor = accentGlow,
                marginTop = T.spacing.xs,
                marginBottom = T.spacing.xs,
            })

            table.insert(contentChildren, UI.Label {
                text = "🔓 解锁仙体",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = accentColor,
                textAlign = "center",
            })

            table.insert(contentChildren, UI.Panel {
                width = "100%",
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = accentGlow,
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.sm,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                gap = T.spacing.xxs,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.sm,
                        children = {
                            UI.Label {
                                text = "✨",
                                fontSize = T.fontSize.xl,
                            },
                            UI.Panel {
                                flexDirection = "column",
                                flexShrink = 1,
                                gap = 2,
                                children = {
                                    UI.Label {
                                        text = bodyProfile.name or "仙人之体",
                                        fontSize = T.fontSize.sm,
                                        fontWeight = "bold",
                                        fontColor = T.color.nameHighlight,
                                    },
                                    UI.Label {
                                        text = string.format("每级成长：HP+%d / ATK+%d / DEF+%d / 回复+%.1f",
                                            bodyProfile.maxHp or 25, bodyProfile.atk or 5,
                                            bodyProfile.def or 3, bodyProfile.hpRegen or 0.5),
                                        fontSize = T.fontSize.xxs,
                                        fontColor = T.color.textSecondary,
                                        flexShrink = 1,
                                    },
                                    UI.Label {
                                        text = "可在境界面板「仙体」标签中切换",
                                        fontSize = T.fontSize.xxs,
                                        fontColor = T.color.warning,
                                    },
                                },
                            },
                        },
                    },
                },
            })
        end
    end

    -- 间距
    table.insert(contentChildren, UI.Panel { height = T.spacing.sm })

    -- 确认按钮（大境界 gold 底色，小境界 primary）
    local btnText = isMajor_ and "悟道成功" or "继续修炼"
    local btnProps = {
        text = btnText,
        width = 160,
        height = 40,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        borderRadius = T.radius.md,
        onClick = function(self)
            BreakthroughCelebration.Hide()
        end,
    }
    if isMajor_ then
        btnProps.backgroundColor = T.color.btnSpend
        btnProps.fontColor = T.color.btnSpendFg
    else
        btnProps.variant = "primary"
        btnProps.fontColor = T.color.textPrimary
    end
    table.insert(contentChildren, UI.Button(btnProps))

    -- 自动关闭提示
    table.insert(contentChildren, UI.Label {
        text = "点击空白处关闭",
        fontSize = T.fontSize.xxs,
        fontColor = T.color.textMuted,
        textAlign = "center",
        marginTop = T.spacing.xs,
    })

    -- ── 构建全屏弹框（点击遮罩可关闭） ──
    panel_ = UI.Panel {
        id = "breakthrough_celebration",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = T.color.popupOverlay,
        zIndex = 250,
        onClick = function(self)
            -- 点击遮罩区域关闭
            BreakthroughCelebration.Hide()
        end,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.sm,
                backgroundColor = isMajor_ and {30, 28, 20, 250} or T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = isMajor_ and 2 or 1,
                borderColor = accentBorder,
                paddingTop = isMajor_ and T.spacing.xl or T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                minWidth = isMajor_ and 320 or 280,
                maxWidth = 360,
                -- 阻止点击卡片内部时冒泡到遮罩
                onClick = function(self) end,
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
    autoCloseTimer_ = 0
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
        SubscribeToEvent(nvgFx_, "NanoVGRender", handleBreakthroughFxRender)
        lastTime_ = time.elapsedTime
    end

end

--- 销毁
function BreakthroughCelebration.Destroy()
    BreakthroughCelebration.Hide()
    -- 释放 NanoVG 上下文
    if nvgFx_ then
        nvgDelete(nvgFx_)
        nvgFx_ = nil
    end
    overlay_ = nil
end

return BreakthroughCelebration
