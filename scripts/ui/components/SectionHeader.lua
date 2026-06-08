-- ============================================================================
-- SectionHeader.lua - 区块标题（替代手动 Label + 分隔线组合）
-- 统一样式：居中标题文字 + 上方分隔线
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local SectionHeader = {}

--- 创建区块标题（用于 section 之间的视觉分隔）
---@param opts { text: string, color?: table, marginTop?: number, showDivider?: boolean }
---@return table UI.Panel
function SectionHeader.Create(opts)
    local showDivider = opts.showDivider ~= false  -- 默认 true
    local headerChildren = {}
    if showDivider then
        table.insert(headerChildren, UI.Panel {
            height = 1,
            width = "100%",
            backgroundColor = T.color.borderLight,
        })
    end
    table.insert(headerChildren, UI.Label {
        text = opts.text,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = opts.color or T.color.titleText,
        textAlign = "center",
    })
    return UI.Panel {
        width = "100%",
        marginTop = opts.marginTop or T.spacing.sm,
        gap = T.spacing.xs,
        children = headerChildren,
    }
end

return SectionHeader
