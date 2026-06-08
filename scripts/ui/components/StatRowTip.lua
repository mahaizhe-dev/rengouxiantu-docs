-- ============================================================================
-- StatRowTip.lua - 带可展开说明的属性行组件
-- 用于 CharacterUI 中显示 属性值 + "!" 按钮 → 展开 tip 说明
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local StatRow = require("ui.components.StatRow")

local StatRowTip = {}

--- 创建一个带 tip 按钮的属性行（返回 widget 数组，1~2 个元素）
---@param opts table
---  label       string   属性名称（如"重击率"）
---  value       string   属性值文本（如"15%"）
---  labelColor  table    标签颜色
---  tipShowing  boolean  当前 tip 是否展开
---  tipText     string   说明文本
---  tipBgColor  table?   tip 背景色（默认 T.color.surface）
---  tipTextColor table?  tip 文字色（默认柔和暖色）
---  onToggle    function 点击 "!" 按钮的回调
---@return table[] widgets 插入到 children 的 widget 数组
function StatRowTip.Create(opts)
    local labelColor = opts.labelColor or T.color.textPrimary
    local tipBgColor = opts.tipBgColor or T.color.surface
    local tipTextColor = opts.tipTextColor or {200, 200, 200, 220}

    -- "!" 按钮颜色：与标签同色系但透明
    local btnFontColor = labelColor
    local btnBg = { math.floor(labelColor[1] * 0.3), math.floor(labelColor[2] * 0.3), math.floor(labelColor[3] * 0.3), 200 }

    local widgets = {}

    -- 参与 StatRow 行计数，保持交替底色一致
    local bgColor = StatRow.Advance()

    -- 主行：标签 + "!" + 值
    table.insert(widgets, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 26,
        borderRadius = 4,
        backgroundColor = bgColor,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label {
                        text = opts.label,
                        fontSize = T.fontSize.sm,
                        fontColor = labelColor,
                    },
                    UI.Button {
                        text = "!",
                        width = 24, height = 24,
                        fontSize = 13,
                        fontWeight = "bold",
                        fontColor = btnFontColor,
                        backgroundColor = btnBg,
                        borderRadius = 12,
                        onClick = function(self)
                            if opts.onToggle then opts.onToggle() end
                        end,
                    },
                },
            },
            UI.Label {
                text = opts.value,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.textPrimary,
            },
        },
    })

    -- tip 展开面板
    if opts.tipShowing then
        table.insert(widgets, UI.Panel {
            backgroundColor = tipBgColor,
            borderRadius = T.radius.sm,
            padding = T.spacing.sm,
            marginLeft = T.spacing.sm,
            marginRight = T.spacing.sm,
            children = {
                UI.Label {
                    text = opts.tipText,
                    fontSize = T.fontSize.xs,
                    fontColor = tipTextColor,
                    whiteSpace = "normal",
                },
            },
        })
    end

    return widgets
end

return StatRowTip
