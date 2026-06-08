-- ============================================================================
-- SectionCard.lua - 通用分组卡片容器
-- 用于将内容分组展示：暗底 + 淡边框 + 圆角 + 统一内边距
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local SectionCard = {}

--- 创建一个分组卡片容器
---@param opts { children: table[], title?: string, titleColor?: table, gap?: number }
---@return table UI.Panel
function SectionCard.Create(opts)
    local cardChildren = {}

    -- 可选标题行
    if opts.title then
        table.insert(cardChildren, UI.Label {
            text = opts.title,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = opts.titleColor or T.color.titleText,
            marginBottom = T.spacing.xs,
        })
    end

    -- 合入子元素
    if opts.children then
        for _, child in ipairs(opts.children) do
            table.insert(cardChildren, child)
        end
    end

    return UI.Panel {
        width = "100%",
        backgroundColor = T.color.surface,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.borderLight,
        padding = T.spacing.sm,
        gap = opts.gap or T.spacing.xs,
        children = cardChildren,
    }
end

return SectionCard
