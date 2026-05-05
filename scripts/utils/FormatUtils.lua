--- FormatUtils: 统一数值/金币/时间格式化函数
--- 消除 FormatGold (4处), formatNumber (2处), FormatTimeAgo (2处) 等重复
---
--- 使用方式:
---   local Format = require("utils.FormatUtils")
---   Format.Gold(12345)          --> "1.2万"
---   Format.Number(1234567)      --> "1,234,567"
---   Format.TimeAgo(os.time()-120) --> "2分钟前"
---   Format.Time(os.time())      --> "05-04 14:30"

local FormatUtils = {}

------------------------------------------------------------------------
-- 金币格式化（中文简写：万/亿）
-- 来源: ShopUI, GourdUI, DragonForgeUI, ArtifactUI_tiandi
--
---@param gold number 金币数量
---@return string 格式化后的字符串
------------------------------------------------------------------------
function FormatUtils.Gold(gold)
    if gold >= 1e8 then
        return string.format("%.0f亿", gold / 1e8)
    elseif gold >= 1e7 then
        return string.format("%.0f万", gold / 1e4)
    elseif gold >= 1e4 then
        local s = string.format("%.1f万", gold / 1e4)
        return s:gsub("%.0万", "万")
    end
    return tostring(gold)
end

------------------------------------------------------------------------
-- 数字千分位格式化（1234567 → "1,234,567"）
-- 来源: DaoTreeUI FormatNumber, DPSTracker formatNumber
--
---@param n number
---@return string
------------------------------------------------------------------------
function FormatUtils.Number(n)
    n = math.floor(n)
    if n < 1000 then return tostring(n) end
    local s = tostring(n)
    local result = ""
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then
            result = result .. ","
        end
        result = result .. s:sub(i, i)
    end
    return result
end

------------------------------------------------------------------------
-- 相对时间格式化（"刚刚"、"3分钟前"、"2小时前"、"1天前"）
-- 来源: EventExchangeUI, CharacterSelectScreen
--
---@param timestamp number|nil Unix 时间戳
---@return string
------------------------------------------------------------------------
function FormatUtils.TimeAgo(timestamp)
    if not timestamp then return "" end
    local diff = os.time() - timestamp
    if diff < 60 then return "刚刚"
    elseif diff < 3600 then return math.floor(diff / 60) .. "分钟前"
    elseif diff < 86400 then return math.floor(diff / 3600) .. "小时前"
    else return math.floor(diff / 86400) .. "天前"
    end
end

------------------------------------------------------------------------
-- 时间格式化（"MM-DD HH:MM"）
-- 来源: BlackMerchantUI
--
---@param ts number|nil Unix 时间戳
---@return string
------------------------------------------------------------------------
function FormatUtils.Time(ts)
    if not ts or ts == 0 then return "???" end
    return os.date("%m-%d %H:%M", ts)
end

------------------------------------------------------------------------
-- 百分比格式化（0.15 → "15%"，保留指定小数位）
---@param value number 小数值 (0~1)
---@param decimals number|nil 小数位数，默认 1
---@return string
------------------------------------------------------------------------
function FormatUtils.Percent(value, decimals)
    decimals = decimals or 1
    return string.format("%." .. decimals .. "f%%", value * 100)
end

return FormatUtils
