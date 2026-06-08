-- ============================================================================
-- StatRow.lua - 通用属性行（标签 + 值，支持交替底色）
-- 使用 StatRow.Reset() 在每个 Section 开头重置计数器
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local StatRow = {}

--- 内部行计数器
local rowIdx_ = 0

--- 重置行计数器（每个 SectionCard 开始前调用）
function StatRow.Reset()
    rowIdx_ = 0
end

--- 获取当前行号（外部偶尔需要）
function StatRow.GetIndex()
    return rowIdx_
end

--- 递增行计数器并返回当前行的交替背景色（供 StatRowTip 等手动构建行使用）
---@return table|nil bgColor  偶数行返回 rowAlt 颜色，奇数行返回 nil
function StatRow.Advance()
    rowIdx_ = rowIdx_ + 1
    return (rowIdx_ % 2 == 0) and T.color.rowAlt or nil
end

--- 创建一行属性展示（label: value 格式，自动交替底色）
---@param label string 标签文字
---@param value string 值文字
---@param color? table 标签颜色（nil 则用 textSecondary）
---@param valueColor? table 值颜色（nil 则用 textPrimary）
---@return table UI.Panel
function StatRow.Create(label, value, color, valueColor)
    rowIdx_ = rowIdx_ + 1
    local bgColor = (rowIdx_ % 2 == 0) and T.color.rowAlt or nil
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 26,
        borderRadius = 4,
        backgroundColor = bgColor,
        children = {
            UI.Label {
                text = label,
                fontSize = T.fontSize.sm,
                fontColor = color or T.color.textSecondary,
                flexShrink = 1,
            },
            UI.Label {
                text = value,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = valueColor or T.color.textPrimary,
                minWidth = T.size.statValueMinW,
                textAlign = "right",
            },
        },
    }
end

return StatRow
