-- ============================================================================
-- AdaptiveIcon.lua - emoji / PNG 自适应图标
-- ============================================================================

local UI = require("urhox-libs/UI")
local IconUtils = require("utils.IconUtils")

local AdaptiveIcon = {}

---@class AdaptiveIconConfig
---@field size? number
---@field fontSize? number
---@field fallback? string
---@field backgroundFit? string

---@param icon string|nil
---@param cfg AdaptiveIconConfig|nil
---@return table
function AdaptiveIcon.Create(icon, cfg)
    cfg = cfg or {}
    local size = cfg.size or 20

    if IconUtils.IsImagePath(icon) then
        return UI.Panel {
            width = size,
            height = size,
            flexShrink = 0,
            backgroundImage = icon,
            backgroundFit = cfg.backgroundFit or "contain",
            pointerEvents = "none",
        }
    end

    return UI.Label {
        width = size,
        height = size,
        flexShrink = 0,
        text = IconUtils.GetTextIcon(icon, cfg.fallback or "?"),
        fontSize = cfg.fontSize or size,
        textAlign = "center",
        pointerEvents = "none",
    }
end

return AdaptiveIcon
