-- ============================================================================
-- ImmortalBodyPanel.lua - 仙体 Tab（嵌入 RealmPanel PanelShell）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: 竖卡网格 | 对标宠物皮肤 | 切换→保存→退出 | 二次确认弹窗
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local ImmortalBodySystem = require("systems.ImmortalBodySystem")
local AscensionConfig = require("config.AscensionConfig")
local EventBus = require("core.EventBus")

local ImmortalBodyPanel = {}

-- ── overlay 引用（由 main.lua 初始化注入） ──
local overlay_ = nil
local confirmPanel_ = nil

function ImmortalBodyPanel.Init(parentOverlay)
    overlay_ = parentOverlay
end

-- ── 仙体贴图映射 ──
local BODY_TEXTURES = {
    mortal          = "image/body_mortal_20260627133129.png",
    immortal_body_1 = "image/body_immortal_1_20260627133119.png",
}

-- ── 卡片常量 ──
local COLS = 2
local CARD_GAP = T.spacing.sm

-- ============================================================================
-- BuildInto
-- ============================================================================

function ImmortalBodyPanel.BuildInto(shell)
    local player = GameState.player
    if not player then return end

    local activeId = ImmortalBodySystem.GetActiveBodyId()
    local unlockedList = ImmortalBodySystem.GetUnlockedList()
    local cost = AscensionConfig.IMMORTAL_BODY_SWITCH_COST_LINGYUN

    -- ── 未解锁任何非凡仙体 → 锁定提示 ──
    if #unlockedList <= 1 then
        shell:AddContent(UI.Panel {
            width = "100%", alignItems = "center", justifyContent = "center",
            paddingTop = T.spacing.xl, paddingBottom = T.spacing.xl, gap = T.spacing.md,
            children = {
                UI.Label { text = "仙体", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.gold },
                UI.Label { text = "首次渡劫成功后解锁「仙人之体」", fontSize = T.fontSize.sm, fontColor = T.color.warning, textAlign = "center" },
                UI.Panel { width = "60%", height = 1, backgroundColor = T.color.border },
                UI.Label {
                    text = "仙体是修仙世界追求的至宝\n激活后所有角色均可使用，重复获得无效",
                    fontSize = T.fontSize.sm, fontColor = T.color.info, textAlign = "center",
                },
                UI.Label {
                    text = "仙体大幅提升每级成长属性\n切换消耗 " .. cost .. " 灵韵，切换后立即保存并退出",
                    fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center",
                },
            },
        })
        return
    end

    -- 排序：当前在前
    table.sort(unlockedList, function(a, b)
        if a.id == activeId then return true end
        if b.id == activeId then return false end
        return a.unlockedAt < b.unlockedAt
    end)

    -- ── 标题行 ──
    shell:AddContent(UI.Panel {
        width = "100%", flexDirection = "row", justifyContent = "space-between", alignItems = "center",
        paddingBottom = T.spacing.xs,
        children = {
            UI.Label { text = "仙体图鉴", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = T.color.gold },
            UI.Label { text = "灵韵 " .. (player.lingYun or 0), fontSize = T.fontSize.xs, fontColor = T.color.info },
        },
    })

    -- ── 竖卡网格（对标宠物皮肤 4列，仙体数量少用 2列） ──
    local cards = {}
    for _, body in ipairs(unlockedList) do
        local profile = AscensionConfig.GROWTH_PROFILES[body.id]
        if profile then
            cards[#cards + 1] = ImmortalBodyPanel._MakeCard(body, profile, activeId, cost, player)
        end
    end

    -- 按 COLS 排行
    for i = 1, #cards, COLS do
        local rowChildren = {}
        for j = 0, COLS - 1 do
            local card = cards[i + j]
            if card then
                rowChildren[#rowChildren + 1] = card
            else
                rowChildren[#rowChildren + 1] = UI.Panel { flexGrow = 1, flexShrink = 1, flexBasis = 0 }
            end
        end
        shell:AddContent(UI.Panel {
            width = "100%", flexDirection = "row", gap = CARD_GAP,
            children = rowChildren,
        })
    end

    -- ── 底部说明 ──
    shell:AddContent(UI.Panel {
        width = "100%", alignItems = "center",
        paddingTop = T.spacing.sm, gap = T.spacing.xxs,
        borderTopWidth = 1, borderColor = T.color.border,
        children = {
            UI.Label { text = "切换消耗 " .. cost .. " 灵韵，立即保存并退出", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center" },
            UI.Label { text = "仙体为账号共享，激活后所有角色均可使用", fontSize = T.fontSize.xs, fontColor = T.color.info, textAlign = "center" },
            UI.Label { text = "重复获得无效", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center" },
        },
    })
end

-- ============================================================================
-- 单张仙体卡片
-- ============================================================================

function ImmortalBodyPanel._MakeCard(body, profile, activeId, cost, player)
    local isActive = (body.id == activeId)
    local texture = BODY_TEXTURES[body.id] or BODY_TEXTURES.mortal

    -- 卡片边框/底色
    local cardBg, borderColor, borderW
    if isActive then
        cardBg      = T.color.surfaceLight or {40, 50, 30, 220}
        borderColor = T.color.gold
        borderW     = 2
    else
        cardBg      = T.color.surfaceDeep
        borderColor = T.color.border
        borderW     = 1
    end

    -- 底部操作
    local bottomChildren = {
        UI.Label {
            text = profile.name,
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = isActive and T.color.gold or T.color.textPrimary,
            textAlign = "center",
        },
        UI.Label {
            text = "HP+" .. profile.maxHp .. " ATK+" .. profile.atk,
            fontSize = 9, fontColor = T.color.textSecondary, textAlign = "center",
        },
        UI.Label {
            text = "DEF+" .. profile.def .. " 回+" .. profile.hpRegen,
            fontSize = 9, fontColor = T.color.textSecondary, textAlign = "center",
        },
    }

    if isActive then
        table.insert(bottomChildren, UI.Label {
            text = "使用中",
            fontSize = T.fontSize.xs, fontWeight = "bold",
            fontColor = T.color.success, textAlign = "center",
        })
    else
        local canAfford = (player.lingYun or 0) >= cost
        local bodyId = body.id
        table.insert(bottomChildren, UI.Button {
            text = canAfford and "切换" or "灵韵不足",
            width = "100%", height = 24,
            fontSize = T.fontSize.xs, fontWeight = "bold",
            borderRadius = T.radius.sm,
            backgroundColor = canAfford and T.color.btnSpend or T.color.btnDisabled,
            fontColor = canAfford and T.color.btnSpendFg or T.color.btnDisabledFg,
            onClick = canAfford and function()
                ImmortalBodyPanel._ShowConfirm(bodyId, profile, cost)
            end or nil,
        })
    end

    return UI.Panel {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        backgroundColor = cardBg,
        borderRadius = T.radius.sm,
        borderWidth = borderW,
        borderColor = borderColor,
        overflow = "hidden",
        children = {
            -- 贴图预览（紧凑正方形）
            UI.Panel {
                width = "100%", aspectRatio = 1.0,
                backgroundColor = T.color.surfaceDeep,
                backgroundImage = texture,
                backgroundFit = "contain",
                children = isActive and {
                    UI.Label {
                        text = "装备",
                        fontSize = 9, fontWeight = "bold",
                        fontColor = T.color.gold,
                        backgroundColor = {0, 0, 0, 180},
                        borderRadius = 4,
                        paddingLeft = 4, paddingRight = 4, paddingTop = 2, paddingBottom = 2,
                        position = "absolute", top = 3, left = 3,
                    },
                } or {},
            },
            -- 底部信息
            UI.Panel {
                width = "100%", alignItems = "center",
                padding = T.spacing.xs, gap = T.spacing.xxs,
                children = bottomChildren,
            },
        },
    }
end

-- ============================================================================
-- 二次确认弹窗 → 立即切换 → 保存 → 退出
-- ============================================================================

function ImmortalBodyPanel._HideConfirm()
    if confirmPanel_ then
        confirmPanel_:Destroy()
        confirmPanel_ = nil
    end
end

function ImmortalBodyPanel._ShowConfirm(targetBodyId, targetProfile, cost)
    if not overlay_ then
        print("[ImmortalBodyPanel] ERROR: overlay_ not initialized")
        return
    end
    ImmortalBodyPanel._HideConfirm()

    local preview = ImmortalBodySystem.PreviewSwitch(targetBodyId)

    confirmPanel_ = UI.Panel {
        position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center", alignItems = "center",
        zIndex = 200,
        onClick = function() ImmortalBodyPanel._HideConfirm() end,
        children = {
            UI.Panel {
                width = "88%", maxWidth = 400,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = T.color.goldDark,
                padding = T.spacing.md, gap = T.spacing.sm,
                alignItems = "center",
                onClick = function() end,  -- 阻止冒泡
                children = {
                    UI.Label { text = "切换仙体", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.gold },
                    UI.Label { text = "切换到「" .. targetProfile.name .. "」", fontSize = T.fontSize.sm, fontColor = T.color.textPrimary },
                    UI.Label { text = "消耗灵韵 " .. cost, fontSize = T.fontSize.xs, fontColor = T.color.warning },
                    -- 属性变化预览
                    preview and UI.Panel {
                        width = "100%", padding = T.spacing.xs, gap = T.spacing.xxs,
                        backgroundColor = T.color.surfaceDeep, borderRadius = T.radius.sm,
                        children = {
                            UI.Label { text = "属性变化 (Lv" .. preview.level .. ")", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center" },
                            UI.Label { text = "生命 " .. (preview.deltaHp >= 0 and "+" or "") .. preview.deltaHp, fontSize = T.fontSize.xs, fontColor = preview.deltaHp >= 0 and T.color.success or T.color.error },
                            UI.Label { text = "攻击 " .. (preview.deltaAtk >= 0 and "+" or "") .. preview.deltaAtk, fontSize = T.fontSize.xs, fontColor = preview.deltaAtk >= 0 and T.color.success or T.color.error },
                            UI.Label { text = "防御 " .. (preview.deltaDef >= 0 and "+" or "") .. preview.deltaDef, fontSize = T.fontSize.xs, fontColor = preview.deltaDef >= 0 and T.color.success or T.color.error },
                            UI.Label { text = "回复 " .. (preview.deltaRegen >= 0 and "+" or "") .. string.format("%.1f", preview.deltaRegen), fontSize = T.fontSize.xs, fontColor = preview.deltaRegen >= 0 and T.color.success or T.color.error },
                        },
                    } or nil,
                    UI.Label { text = "确认后将立即保存并退出游戏", fontSize = T.fontSize.xs, fontColor = T.color.error, textAlign = "center" },
                    -- 按钮行
                    UI.Panel {
                        width = "100%", flexDirection = "row", justifyContent = "center",
                        gap = T.spacing.md, paddingTop = T.spacing.sm,
                        children = {
                            UI.Button {
                                text = "取消", fontSize = T.fontSize.sm,
                                backgroundColor = T.color.btnSecondary, fontColor = T.color.btnSecondaryFg,
                                borderRadius = T.radius.sm,
                                paddingLeft = T.spacing.lg, paddingRight = T.spacing.lg,
                                onClick = function() ImmortalBodyPanel._HideConfirm() end,
                            },
                            UI.Button {
                                text = "确认切换", fontSize = T.fontSize.sm, fontWeight = "bold",
                                backgroundColor = T.color.btnSpend, fontColor = T.color.btnSpendFg,
                                borderRadius = T.radius.sm,
                                paddingLeft = T.spacing.lg, paddingRight = T.spacing.lg,
                                onClick = function()
                                    -- 1. 写 pending + 扣灵韵
                                    local ok, msg = ImmortalBodySystem.RequestSwitch(targetBodyId)
                                    if not ok then
                                        ImmortalBodyPanel._HideConfirm()
                                        local CombatSystem = require("systems.CombatSystem")
                                        local p = GameState.player
                                        if p then CombatSystem.AddFloatingText(p.x, p.y - 0.5, msg or "切换失败", T.color.error, 1.5) end
                                        return
                                    end
                                    -- 2. 立即应用属性变化
                                    ImmortalBodySystem.ApplyPending()
                                    -- 3. 强制保存 → 退出到登录（P0-2 修复：检查保存结果）
                                    ImmortalBodyPanel._HideConfirm()
                                    local SaveSystem = require("systems.SaveSystem")
                                    SaveSystem.Save(function(ok, reason)
                                        if ok then
                                            if ReturnToLogin then ReturnToLogin() end
                                        else
                                            print("[ImmortalBodyPanel] Save failed: " .. tostring(reason))
                                            EventBus.Emit("show_toast", "保存失败，请稍后重试：" .. tostring(reason))
                                        end
                                    end)
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

return ImmortalBodyPanel
