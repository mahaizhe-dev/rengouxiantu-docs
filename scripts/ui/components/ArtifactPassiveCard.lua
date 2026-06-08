-- ============================================================================
-- ArtifactPassiveCard.lua - 神器被动卡片组件
-- 用于展示神器/特殊被动效果（带边框高亮）
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local ArtifactPassiveCard = {}

--- 创建一个神器被动卡片
---@param opts table
---  icon        string   emoji 图标
---  name        string   被动名称
---  nameColor   table    名称颜色
---  desc        string   被动描述
---  descColor?  table    描述颜色（默认 textSecondary）
---  bgColor     table    背景颜色
---  borderColor table    边框颜色
---@return table widget
function ArtifactPassiveCard.Create(opts)
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        padding = T.spacing.sm,
        backgroundColor = opts.bgColor,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = opts.borderColor,
        children = {
            UI.Label {
                text = opts.icon or "?",
                fontSize = T.fontSize.xl + 4,
                width = T.size.slotSize,
                height = T.size.slotSize,
                textAlign = "center",
            },
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                gap = 2,
                children = {
                    UI.Label {
                        text = opts.name,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = opts.nameColor,
                    },
                    UI.Label {
                        text = opts.desc,
                        fontSize = T.fontSize.xs,
                        fontColor = opts.descColor or T.color.textSecondary,
                    },
                },
            },
        },
    }
end

return ArtifactPassiveCard
