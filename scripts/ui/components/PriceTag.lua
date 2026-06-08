-- ============================================================================
-- PriceTag.lua - 价格标签组件（金币/灵韵自适应，余额不足变红）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 用法: local tag = PriceTag.Create({ amount=1000, currency="gold" })
--       local tag = PriceTag.Create({ amount=50, currency="lingyin" })
--       local tag = PriceTag.Create({ amount=1000, currency="gold", balance=500 })
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local PriceTag = {}

--- 格式化价格数字（10000+ 缩写为 X.Xw）
---@param amount number
---@return string
local function FormatPrice(amount)
    if amount >= 10000 then
        return string.format("%.1fw", amount / 10000)
    end
    return tostring(amount)
end

--- @class PriceTagConfig
--- @field amount number 价格数额
--- @field currency? string "gold"|"lingyin"（默认 "gold"）
--- @field balance? number 当前余额（传入后自动判断是否不足变红）
--- @field fontSize? number 覆盖字号

--- 创建价格标签
---@param cfg PriceTagConfig
---@return table UI.Panel
function PriceTag.Create(cfg)
    local isLY = (cfg.currency == "lingyin")
    local amount = cfg.amount or 0
    local fontSize = cfg.fontSize or T.fontSize.sm

    -- 判断余额是否不足
    local insufficient = false
    if cfg.balance and cfg.balance < amount then
        insufficient = true
    end

    local emoji, textColor, bgColor, borderColor

    if isLY then
        emoji = "💎"
        textColor = insufficient and T.color.error or T.color.info
        bgColor = {120, 180, 255, 25}
        borderColor = {120, 180, 255, 80}
    else
        emoji = "💰"
        textColor = insufficient and T.color.error or T.color.warning
        bgColor = {255, 200, 80, 20}
        borderColor = {255, 200, 80, 60}
    end

    return UI.Panel {
        flexDirection = "row", alignItems = "center", gap = 3,
        paddingLeft = 8, paddingRight = 8, paddingTop = 3, paddingBottom = 3,
        borderRadius = T.radius.sm,
        backgroundColor = bgColor,
        borderWidth = 1,
        borderColor = borderColor,
        children = {
            UI.Label { text = emoji, fontSize = T.fontSize.xs },
            UI.Label {
                text = FormatPrice(amount),
                fontSize = fontSize,
                fontWeight = "bold",
                fontColor = textColor,
            },
        },
    }
end

--- 便捷方法：金币价格
---@param amount number
---@param balance? number
---@return table
function PriceTag.Gold(amount, balance)
    return PriceTag.Create({ amount = amount, currency = "gold", balance = balance })
end

--- 便捷方法：灵韵价格
---@param amount number
---@param balance? number
---@return table
function PriceTag.LingYin(amount, balance)
    return PriceTag.Create({ amount = amount, currency = "lingyin", balance = balance })
end

return PriceTag
