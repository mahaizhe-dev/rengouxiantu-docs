-- ============================================================================
-- PanelShell.lua - 标准面板骨架（遮罩 + 金边圆角卡片 + header + footer）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 用法: local shell = PanelShell.Create({ title="标题", onClose=fn, parent=overlay })
--       shell:AddContent(child)   -- 向 ScrollView 添加内容
--       shell:Show() / shell:Hide()
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local PanelShell = {}

--- @class PanelShellConfig
--- @field title string 面板标题（金色）
--- @field subtitle? string 副标题（灰色）
--- @field onClose function 关闭回调
--- @field parent table 父容器（用于 AddChild）
--- @field portrait? table 左侧头像/图标组件（可选）
--- @field maxHeight? string 最大高度（默认 "76%"）
--- @field maxWidth? number 最大宽度（默认 T.size.npcPanelMaxW）
--- @field footerHint? string 底部提示文字（默认 "点击空白处关闭"）
--- @field zIndex? number 层级（默认 100）

--- 创建标准面板
---@param cfg PanelShellConfig
---@return table shell { panel, contentPanel, resultLabel, Show, Hide, AddContent, SetTitle, SetResult }
function PanelShell.Create(cfg)
    local shell = {}

    -- 结果提示标签（购买成功等）
    shell.resultLabel = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = T.color.success,
        textAlign = "center",
        height = 22,
    }

    -- 内容容器（放在 ScrollView 内）
    shell.contentPanel = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
    }

    -- 标题 Label（可动态更新）
    local titleLabel = UI.Label {
        text = cfg.title or "",
        fontSize = T.fontSize.lg,
        fontWeight = "bold",
        fontColor = T.color.gold,
    }

    local subtitleLabel = UI.Label {
        text = cfg.subtitle or "",
        fontSize = T.fontSize.xs,
        fontColor = T.color.textMuted,
    }

    -- header 左侧内容
    local headerChildren = {}

    -- 头像/图标（可选）
    if cfg.portrait then
        table.insert(headerChildren, UI.Panel { children = { cfg.portrait } })
    end

    -- 标题区
    table.insert(headerChildren, UI.Panel {
        flexGrow = 1, flexShrink = 1,
        marginLeft = cfg.portrait and T.spacing.sm or 0,
        gap = 2,
        children = { titleLabel, subtitleLabel },
    })

    -- 关闭按钮（右侧）
    table.insert(headerChildren, UI.Button {
        text = "✕",
        width = T.size.closeButton, height = T.size.closeButton,
        fontSize = T.fontSize.md, fontWeight = "bold",
        borderRadius = T.radius.sm,
        backgroundColor = {255, 100, 100, 30},
        fontColor = T.color.error,
        onClick = function() if cfg.onClose then cfg.onClose() end end,
    })

    -- footer
    local footerHint = cfg.footerHint or "点击空白处关闭"
    local footer = UI.Panel {
        width = "100%",
        paddingTop = T.spacing.xs, paddingBottom = T.spacing.sm,
        borderTopWidth = 1, borderColor = T.decor.dividerColor,
        alignItems = "center",
        gap = T.spacing.xs,
        children = {
            shell.resultLabel,
            UI.Label { text = footerHint, fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
        },
    }

    -- 主面板（overlay → card → header → content → footer）
    shell.panel = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center", alignItems = "center",
        visible = false,
        zIndex = cfg.zIndex or 100,
        onClick = function() if cfg.onClose then cfg.onClose() end end,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = cfg.maxWidth or T.size.npcPanelMaxW,
                maxHeight = cfg.maxHeight or "76%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = T.color.goldDark,
                onClick = function() end,  -- 阻止冒泡
                children = {
                    -- header（无背景色，保护圆角）
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        paddingLeft = T.spacing.sm,
                        paddingRight = T.spacing.md,
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.sm,
                        borderBottomWidth = 1,
                        borderColor = T.decor.headerBorderBottom,
                        children = headerChildren,
                    },
                    -- 可滚动内容区（flexShrink=1 确保内容多时被 maxHeight 约束可滚动）
                    UI.ScrollView {
                        flexShrink = 1,
                        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
                        paddingTop = T.spacing.sm, paddingBottom = T.spacing.sm,
                        children = { shell.contentPanel },
                    },
                    -- footer
                    footer,
                },
            },
        },
    }

    -- 挂载到父容器
    if cfg.parent then
        cfg.parent:AddChild(shell.panel)
    end

    -- ── 公开方法 ──

    function shell:Show()
        self.panel:Show()
    end

    function shell:Hide()
        self.panel:Hide()
    end

    function shell:AddContent(child)
        self.contentPanel:AddChild(child)
    end

    function shell:ClearContent()
        self.contentPanel:ClearChildren()
    end

    function shell:SetTitle(text)
        titleLabel:SetText(text)
    end

    function shell:SetSubtitle(text)
        subtitleLabel:SetText(text)
    end

    function shell:SetResult(text, color)
        self.resultLabel:SetText(text)
        if color then
            self.resultLabel:SetStyle({ fontColor = color })
        end
    end

    function shell:IsVisible()
        return self.panel:IsVisible()
    end

    return shell
end

return PanelShell
