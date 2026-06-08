-- ============================================================================
-- IconStatRow.lua - 通用图标属性行（icon + name | status + bonus）
-- 用于丹药、地区加成等带图标的统一行组件，参与 StatRow 行计数
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local StatRow = require("ui.components.StatRow")

local IconStatRow = {}

--- 创建一行图标属性展示（自动参与 StatRow 行计数交替底色）
---@param opts table
---  icon        string   emoji 图标
---  name        string   名称
---  nameColor?  table    名称颜色（默认 textPrimary）
---  statusText  string   状态文本（如"3/5"、"Lv.3"）
---  statusColor table    状态颜色
---  bonusText   string   加成文本（如"+30攻击"、"-"）
---  bonusColor  table    加成颜色
---@return table widget
function IconStatRow.Create(opts)
    local bgColor = StatRow.Advance()
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 28,
        borderRadius = 4,
        backgroundColor = bgColor,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label { text = opts.icon, fontSize = T.fontSize.sm + 2 },
                    UI.Label {
                        text = opts.name,
                        fontSize = T.fontSize.sm,
                        fontColor = opts.nameColor or T.color.textPrimary,
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    UI.Label {
                        text = opts.statusText,
                        fontSize = T.fontSize.sm,
                        fontColor = opts.statusColor,
                    },
                    UI.Label {
                        text = opts.bonusText,
                        fontSize = T.fontSize.xs,
                        fontColor = opts.bonusColor,
                    },
                },
            },
        },
    }
end

return IconStatRow
