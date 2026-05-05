--- 图标工具模块：统一处理图片路径 vs emoji/文字图标
local IconUtils = {}

--- 判断字符串是否为图片资源路径
---@param str any
---@return boolean
function IconUtils.IsImagePath(str)
    return type(str) == "string" and (str:match("%.png$") or str:match("%.jpg$")) ~= nil
end

--- 获取安全的文本图标（过滤掉图片路径，返回 fallback）
---@param icon string|nil 原始图标
---@param fallback string|nil 当图标为空或图片路径时的替代文本，默认 "📦"
---@return string
function IconUtils.GetTextIcon(icon, fallback)
    fallback = fallback or "📦"
    if not icon or icon == "" then return fallback end
    if IconUtils.IsImagePath(icon) then return fallback end
    return icon
end

return IconUtils
