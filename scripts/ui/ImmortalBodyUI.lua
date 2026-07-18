-- ============================================================================
-- ImmortalBodyUI.lua - 仙体切换界面
-- ============================================================================
-- 职责：显示已解锁仙体列表、属性对比预览、切换确认二次弹窗
-- 入口：从仙阶面板或特定 NPC 交互打开
-- 使用 overlay:AddChild / panel:Destroy 模式（与 BreakthroughCelebration 一致）

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local ImmortalBodySystem = require("systems.ImmortalBodySystem")
local AscensionConfig = require("config.AscensionConfig")
local EventBus = require("core.EventBus")

local ImmortalBodyUI = {}

local visible_ = false
local overlay_ = nil     -- 父 overlay 引用（由 Create 传入）
local panel_ = nil       -- 当前主面板
local confirmPanel_ = nil -- 确认弹窗
local selectedBodyId_ = nil

-- ============================================================================
-- 创建（由 main.lua 初始化时调用，传入 parentOverlay）
-- ============================================================================

function ImmortalBodyUI.Create(parentOverlay)
    overlay_ = parentOverlay
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function ImmortalBodyUI.Show()
    if visible_ then return end
    if not overlay_ then
        print("[ImmortalBodyUI] ERROR: overlay_ is nil, Create() not called")
        return
    end
    visible_ = true
    selectedBodyId_ = nil
    GameState.uiOpen = "immortal_body"
    ImmortalBodyUI._build()
end

function ImmortalBodyUI.Hide()
    if not visible_ then return end
    visible_ = false
    ImmortalBodyUI._destroyConfirm()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    if GameState.uiOpen == "immortal_body" then
        GameState.uiOpen = nil
    end
end

function ImmortalBodyUI.IsVisible()
    return visible_
end

function ImmortalBodyUI.Toggle()
    if visible_ then ImmortalBodyUI.Hide() else ImmortalBodyUI.Show() end
end

-- ============================================================================
-- 构建 UI
-- ============================================================================

function ImmortalBodyUI._build()
    -- 先清理旧面板
    ImmortalBodyUI._destroyConfirm()
    if panel_ then panel_:Destroy(); panel_ = nil end

    local player = GameState.player
    if not player then return end

    local activeId = ImmortalBodySystem.GetActiveBodyId()
    local unlockedList = ImmortalBodySystem.GetUnlockedList()
    local cost = AscensionConfig.IMMORTAL_BODY_SWITCH_COST_LINGYUN

    -- 排序：当前激活的在最前
    table.sort(unlockedList, function(a, b)
        if a.id == activeId then return true end
        if b.id == activeId then return false end
        return a.unlockedAt < b.unlockedAt
    end)

    -- ── 仙体卡片列表 ──
    local bodyCards = {}
    for _, body in ipairs(unlockedList) do
        local isActive = (body.id == activeId)
        local isSelected = (body.id == selectedBodyId_)
        local profile = AscensionConfig.GROWTH_PROFILES[body.id]
        if profile then
            bodyCards[#bodyCards + 1] = ImmortalBodyUI._buildBodyCard(body, profile, isActive, isSelected)
        end
    end

    -- ── 预览区域 ──
    local previewSection = nil
    if selectedBodyId_ and selectedBodyId_ ~= activeId then
        previewSection = ImmortalBodyUI._buildPreviewSection(selectedBodyId_, cost, player)
    end

    -- ── pending 提示 ──
    local pendingSection = nil
    local charState = ImmortalBodySystem.GetCharState()
    if charState.pending then
        local targetProfile = AscensionConfig.GROWTH_PROFILES[charState.pending.targetBodyId]
        pendingSection = UI.Panel {
            width = "100%", padding = T.spacing.sm,
            backgroundColor = {60, 40, 20, 220}, borderRadius = T.radius.sm,
            alignItems = "center", gap = T.spacing.xs,
            children = {
                UI.Label { text = "待生效切换", fontSize = T.fontSize.xs, fontColor = T.color.warning },
                UI.Label {
                    text = "-> " .. (targetProfile and targetProfile.name or charState.pending.targetBodyId),
                    fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.gold,
                },
                UI.Label { text = "下次登录时自动生效", fontSize = T.fontSize.xs, fontColor = T.color.textSecondary },
            },
        }
    end

    -- ── 主面板 ──
    panel_ = UI.Panel {
        width = "100%", height = "100%",
        position = "absolute", top = 0, left = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        onClick = function() ImmortalBodyUI.Hide() end,
        children = {
            UI.Panel {
                width = 320, maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.md,
                gap = T.spacing.sm,
                onClick = function() end,  -- 阻止穿透
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        justifyContent = "space-between", alignItems = "center",
                        children = {
                            UI.Label {
                                text = "仙体管理",
                                fontSize = T.fontSize.lg, fontWeight = "bold",
                                fontColor = T.color.gold,
                            },
                            UI.Button {
                                text = "X", fontSize = T.fontSize.sm,
                                backgroundColor = T.color.error, borderRadius = T.radius.sm,
                                onClick = function() ImmortalBodyUI.Hide() end,
                            },
                        },
                    },
                    -- 当前仙体
                    UI.Panel {
                        width = "100%", alignItems = "center", paddingBottom = T.spacing.xs,
                        children = {
                            UI.Label {
                                text = "当前：" .. (AscensionConfig.GROWTH_PROFILES[activeId] and AscensionConfig.GROWTH_PROFILES[activeId].name or activeId),
                                fontSize = T.fontSize.sm, fontColor = T.color.text,
                            },
                        },
                    },
                    -- pending 提示
                    pendingSection,
                    -- 仙体列表
                    UI.Panel { width = "100%", gap = T.spacing.xs, children = bodyCards },
                    -- 预览区
                    previewSection,
                    -- 灵韵
                    UI.Panel {
                        width = "100%", alignItems = "center", paddingTop = T.spacing.xs,
                        children = {
                            UI.Label {
                                text = "灵韵：" .. (player.lingYun or 0) .. " (切换消耗 " .. cost .. ")",
                                fontSize = T.fontSize.xs, fontColor = T.color.textSecondary,
                            },
                        },
                    },
                },
            },
        },
    }
    overlay_:AddChild(panel_)
end

-- ============================================================================
-- 仙体卡片
-- ============================================================================

function ImmortalBodyUI._buildBodyCard(body, profile, isActive, isSelected)
    local borderColor = isActive and T.color.gold or (isSelected and T.color.primary or T.color.border)
    local bgColor = isActive and {40, 50, 30, 220} or (isSelected and {30, 40, 60, 220} or {25, 30, 40, 200})

    return UI.Panel {
        width = "100%", padding = T.spacing.sm,
        backgroundColor = bgColor, borderRadius = T.radius.sm,
        borderWidth = isActive and 2 or (isSelected and 1.5 or 0.5),
        borderColor = borderColor,
        flexDirection = "row", alignItems = "center", gap = T.spacing.sm,
        onClick = function()
            if not isActive then
                selectedBodyId_ = body.id
                ImmortalBodyUI._build()
            end
        end,
        children = {
            -- 名称 + 标签
            UI.Panel {
                flex = 1, gap = 2,
                children = {
                    UI.Label {
                        text = profile.name,
                        fontSize = T.fontSize.sm, fontWeight = "bold",
                        fontColor = isActive and T.color.gold or T.color.text,
                    },
                    UI.Label {
                        text = isActive and "(使用中)" or ("来源：" .. (body.source or "?")),
                        fontSize = T.fontSize.xs,
                        fontColor = isActive and T.color.success or T.color.textSecondary,
                    },
                },
            },
            -- 属性简览
            UI.Panel {
                alignItems = "flex-end", gap = 1,
                children = {
                    UI.Label { text = "HP+" .. profile.maxHp .. "/级", fontSize = 10, fontColor = T.color.textSecondary },
                    UI.Label { text = "ATK+" .. profile.atk .. "/级", fontSize = 10, fontColor = T.color.textSecondary },
                    profile.xianyuanGrowth and profile.xianyuanGrowth.fortune and UI.Label {
                        text = "福源+" .. tostring(profile.xianyuanGrowth.fortune.perLevel or 0) .. "/级",
                        fontSize = 10, fontColor = T.color.gold,
                    } or nil,
                },
            },
        },
    }
end

-- ============================================================================
-- 属性对比预览
-- ============================================================================

function ImmortalBodyUI._buildPreviewSection(targetBodyId, cost, player)
    local preview = ImmortalBodySystem.PreviewSwitch(targetBodyId)
    if not preview then return nil end

    local canAfford = (player.lingYun or 0) >= cost
    local charState = ImmortalBodySystem.GetCharState()
    local hasPending = charState.pending ~= nil

    local function deltaColor(val)
        if val > 0 then return T.color.success end
        if val < 0 then return T.color.error end
        return T.color.textSecondary
    end
    local function deltaStr(val, fmt)
        fmt = fmt or "%d"
        if val >= 0 then return "+" .. string.format(fmt, val) end
        return string.format(fmt, val)
    end

    local btnText, btnColor, canClick
    if hasPending then
        btnText = "已有待生效切换"
        btnColor = T.color.disabled
        canClick = false
    elseif not canAfford then
        btnText = "灵韵不足"
        btnColor = T.color.disabled
        canClick = false
    else
        btnText = "确认切换"
        btnColor = T.color.primary
        canClick = true
    end

    return UI.Panel {
        width = "100%", padding = T.spacing.sm,
        backgroundColor = {30, 35, 50, 220}, borderRadius = T.radius.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label { text = "切换预览 (Lv" .. preview.level .. ")", fontSize = T.fontSize.xs, fontColor = T.color.textSecondary, textAlign = "center" },
            UI.Panel {
                width = "100%", gap = 2,
                children = {
                    UI.Label { text = "生命：" .. deltaStr(preview.deltaHp), fontSize = T.fontSize.xs, fontColor = deltaColor(preview.deltaHp) },
                    UI.Label { text = "攻击：" .. deltaStr(preview.deltaAtk), fontSize = T.fontSize.xs, fontColor = deltaColor(preview.deltaAtk) },
                    UI.Label { text = "防御：" .. deltaStr(preview.deltaDef), fontSize = T.fontSize.xs, fontColor = deltaColor(preview.deltaDef) },
                    UI.Label { text = "回复：" .. deltaStr(preview.deltaRegen, "%.1f"), fontSize = T.fontSize.xs, fontColor = deltaColor(preview.deltaRegen) },
                    UI.Label { text = "福源：" .. deltaStr(preview.deltaFortune), fontSize = T.fontSize.xs, fontColor = deltaColor(preview.deltaFortune) },
                },
            },
            UI.Panel {
                width = "100%", alignItems = "center", paddingTop = T.spacing.xs,
                children = {
                    UI.Button {
                        text = btnText, fontSize = T.fontSize.sm, fontWeight = "bold",
                        backgroundColor = btnColor, borderRadius = T.radius.md,
                        paddingLeft = T.spacing.lg, paddingRight = T.spacing.lg,
                        onClick = canClick and function()
                            ImmortalBodyUI._showConfirmDialog(targetBodyId, cost)
                        end or nil,
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 确认弹窗
-- ============================================================================

function ImmortalBodyUI._showConfirmDialog(targetBodyId, cost)
    local targetProfile = AscensionConfig.GROWTH_PROFILES[targetBodyId]
    if not targetProfile then return end

    ImmortalBodyUI._destroyConfirm()

    confirmPanel_ = UI.Panel {
        width = "100%", height = "100%",
        position = "absolute", top = 0, left = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 180},
        onClick = function() ImmortalBodyUI._destroyConfirm() end,
        children = {
            UI.Panel {
                width = 280, padding = T.spacing.md,
                backgroundColor = T.color.panelBg, borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = T.color.warning,
                gap = T.spacing.sm, alignItems = "center",
                onClick = function() end,
                children = {
                    UI.Label { text = "确认切换仙体？", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = T.color.warning },
                    UI.Label { text = "切换到：" .. targetProfile.name, fontSize = T.fontSize.sm, fontColor = T.color.text },
                    UI.Label { text = "消耗灵韵：" .. cost, fontSize = T.fontSize.xs, fontColor = T.color.gold },
                    UI.Label { text = "切换将在下次登录时生效", fontSize = T.fontSize.xs, fontColor = T.color.textSecondary },
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        justifyContent = "center", gap = T.spacing.md, paddingTop = T.spacing.sm,
                        children = {
                            UI.Button {
                                text = "取消", fontSize = T.fontSize.sm,
                                backgroundColor = T.color.border, borderRadius = T.radius.sm,
                                onClick = function() ImmortalBodyUI._destroyConfirm() end,
                            },
                            UI.Button {
                                text = "确认", fontSize = T.fontSize.sm, fontWeight = "bold",
                                backgroundColor = T.color.primary, borderRadius = T.radius.sm,
                                onClick = function()
                                    local ok, msg = ImmortalBodySystem.RequestSwitch(targetBodyId)
                                    ImmortalBodyUI._destroyConfirm()
                                    if ok then
                                        EventBus.Emit("save_request")
                                        ImmortalBodyUI._build()
                                        local CombatSystem = require("systems.CombatSystem")
                                        local p = GameState.player
                                        if p then
                                            CombatSystem.AddFloatingText(p.x, p.y - 1.0, "仙体切换已记录，下次登录生效", {255, 215, 0, 255}, 2.5)
                                        end
                                    else
                                        local CombatSystem = require("systems.CombatSystem")
                                        local p = GameState.player
                                        if p then
                                            CombatSystem.AddFloatingText(p.x, p.y - 0.5, msg or "切换失败", {255, 80, 80, 255}, 2.0)
                                        end
                                    end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    overlay_:AddChild(confirmPanel_)
end

function ImmortalBodyUI._destroyConfirm()
    if confirmPanel_ then
        confirmPanel_:Destroy()
        confirmPanel_ = nil
    end
end

return ImmortalBodyUI
