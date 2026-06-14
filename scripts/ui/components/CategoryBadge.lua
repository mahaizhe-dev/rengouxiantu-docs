-- ============================================================================
-- CategoryBadge.lua - 分类标签组件（如"进阶丹药"、"属性丹药"、"物品打包"）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 用法: local badge = CategoryBadge.Create({ text="进阶丹药", bg=T.color.badgeAdvanceBg, fg=T.color.badgeAdvanceFg })
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local CategoryBadge = {}

--- @class CategoryBadgeConfig
--- @field text string 标签文字
--- @field bg table 背景色 RGBA
--- @field fg table 前景色 RGBA

--- 创建分类标签
---@param cfg CategoryBadgeConfig
---@return table UI.Panel
function CategoryBadge.Create(cfg)
    if not cfg or not cfg.text then
        return UI.Panel { width = 0, height = 0 }
    end
    return UI.Panel {
        paddingLeft = T.spacing.xs + T.spacing.xxs,
        paddingRight = T.spacing.xs + T.spacing.xxs,
        paddingTop = T.spacing.xxs,
        paddingBottom = T.spacing.xxs,
        borderRadius = T.radius.sm,
        backgroundColor = cfg.bg,
        children = {
            UI.Label {
                text = cfg.text,
                fontSize = T.fontSize.xxs,
                fontColor = cfg.fg,
            },
        },
    }
end

--- 预定义的分类标签快捷方式
CategoryBadge.PRESETS = {
    advance = { text = "进阶丹药", bg = T.color.badgeAdvanceBg, fg = T.color.badgeAdvanceFg },
    attr    = { text = "属性丹药", bg = T.color.badgeAttrBg, fg = T.color.badgeAttrFg },
    pack    = { text = "物品打包", bg = T.color.badgePackBg, fg = T.color.badgePackFg },
}

--- 通过预设 key 创建标签
---@param presetKey string "advance"|"attr"|"pack"
---@return table UI.Panel
function CategoryBadge.FromPreset(presetKey)
    local preset = CategoryBadge.PRESETS[presetKey]
    if not preset then
        return UI.Panel { width = 0, height = 0 }
    end
    return CategoryBadge.Create(preset)
end

return CategoryBadge
