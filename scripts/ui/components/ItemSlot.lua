-- ============================================================================
-- ItemSlot.lua - 标准物品图标格子（56px、品质辉光边框、分层 icon）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 用法: local slot = ItemSlot.Create({ icon="icon_weapon.png", quality="blue" })
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local ItemSlot = {}

local SLOT_SIZE = T.size.slotSize    -- 56
local ICON_PAD  = T.spacing.xs       -- 4

--- @class ItemSlotConfig
--- @field icon? string 图标资源路径（贴图文件名）
--- @field emoji? string 无贴图时用 emoji 占位
--- @field quality? string 品质等级 "white"|"green"|"blue"|"purple"|"orange"|"red"
--- @field size? number 覆盖默认尺寸（默认 56）
--- @field onClick? function 点击回调

--- 创建标准物品格子
---@param cfg ItemSlotConfig
---@return table UI.Panel
function ItemSlot.Create(cfg)
    local quality = cfg.quality or "white"
    local size = cfg.size or SLOT_SIZE
    local iconSize = size - ICON_PAD * 2

    local borderColor = T.qualityBorder[quality] or T.qualityBorder.white
    local slotBg = T.decor.qualitySlotBg[quality] or T.decor.qualitySlotBg.white

    local content
    if cfg.icon then
        content = UI.Panel {
            width = iconSize, height = iconSize,
            borderRadius = T.radius.sm,
            backgroundImage = cfg.icon,
            backgroundFit = "contain",
        }
    else
        content = UI.Label {
            text = cfg.emoji or "?",
            fontSize = math.floor(size * 0.5),
        }
    end

    local slot = UI.Panel {
        width = size, height = size,
        borderRadius = T.radius.md,
        borderWidth = 2,
        borderColor = borderColor,
        backgroundColor = slotBg,
        justifyContent = "center",
        alignItems = "center",
        children = { content },
    }

    if cfg.onClick then
        -- 包裹一层 Button 以支持点击
        return UI.Button {
            width = size, height = size,
            borderRadius = T.radius.md,
            borderWidth = 2,
            borderColor = borderColor,
            backgroundColor = slotBg,
            justifyContent = "center",
            alignItems = "center",
            onClick = cfg.onClick,
            children = { content },
        }
    end

    return slot
end

return ItemSlot
