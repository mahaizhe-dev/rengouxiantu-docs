-- ============================================================================
-- ImageItemSlot.lua - ItemSlot with image icon support
-- Extends engine's ItemSlot to render PNG icons instead of emoji text
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Panel = require("urhox-libs/UI/Widgets/Panel")
local ItemSlot = require("urhox-libs/UI/Components/ItemSlot")
local T = require("config.UITheme")
local IconUtils = require("utils.IconUtils")

---@class ImageItemSlot : ItemSlot
local ImageItemSlot = ItemSlot:Extend("ImageItemSlot")

local isImagePath = IconUtils.IsImagePath

function ImageItemSlot:Init(props)
    ItemSlot.Init(self, props)

    -- Create image overlay panel (positioned inside the slot with padding)
    local pad = T.spacing.sm
    self.imageOverlay_ = Panel {
        position = "absolute",
        top = pad, left = pad,
        width = self.props.size - pad * 2,
        height = self.props.size - pad * 2,
        backgroundFit = "contain",
        pointerEvents = "none",
    }
    self.imageOverlay_:SetVisible(false)
    Widget.AddChild(self, self.imageOverlay_)

    -- Re-run display update now that image overlay exists
    self:UpdateDisplay()
end

--- 获取当前槽位应有的边框样式（品质色 / 空槽默认色）
function ImageItemSlot:GetSlotBorderStyle()
    local item = self.props.item
    if item then
        -- 有物品：查品质色（装备和消耗品通用）
        local GameConfig = require("config.GameConfig")
        -- 消耗品兼容：从配置补全 quality（统一用 CONSUMABLES 覆盖全品类）
        if item.category == "consumable" and not item.quality and item.consumableId then
            local cfgData = GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[item.consumableId]
            if cfgData then item.quality = cfgData.quality end
        end
        local qCfg = item.quality and GameConfig.QUALITY[item.quality]
        if qCfg then
            return qCfg.color, 2
        end
        return {120, 130, 150, 255}, 2
    elseif not item and self.props.showTypeIcon ~= false and isImagePath(self.props.slotTypeIcon) then
        return {45, 50, 65, 150}, 1
    end
    return {60, 65, 75, 255}, 2
end

function ImageItemSlot:UpdateDisplay()
    -- Call parent to handle standard logic (emoji text, background color, quantity badge)
    -- 兼容 count 字段：引擎 ItemSlot 只识别 quantity，游戏数据用 count
    local curItem = self.props.item
    if curItem and curItem.count then
        curItem.quantity = curItem.count
    end

    -- 🔴 FIX: 确定有效图标路径（优先 image 字段，其次 icon，最后从 GameConfig 查）
    local imgPath = nil
    if curItem then
        if curItem.image and isImagePath(curItem.image) then
            imgPath = curItem.image
        elseif isImagePath(curItem.icon) then
            imgPath = curItem.icon
        elseif curItem.category == "consumable" and curItem.consumableId then
            -- 旧存档可能没有 image 字段，从 GameConfig 实时查
            local GameConfig = require("config.GameConfig")
            local cfgData = GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[curItem.consumableId]
            if cfgData and cfgData.image and isImagePath(cfgData.image) then
                imgPath = cfgData.image
            end
        end
    end

    -- 阻止基类把 .png 路径写入 iconLabel（56px 容器放 ~395px 文本
    --    → CheckOverflow 每帧 100+ 次 print() → I/O 卡死）
    local savedIcon = nil
    if curItem and (isImagePath(curItem.icon) or imgPath) then
        savedIcon = curItem.icon
        curItem.icon = ""  -- 临时清空，基类只会 SetText("")
    end

    ItemSlot.UpdateDisplay(self)

    -- 还原 icon，不污染原始数据
    if savedIcon then
        curItem.icon = savedIcon
    end

    -- Guard: imageOverlay_ not yet created during parent Init
    if not self.imageOverlay_ then return end

    local item = self.props.item

    if item and imgPath then
        -- Item with image icon: show image, hide emoji text (iconLabel already "" from above)
        self.imageOverlay_.props.backgroundImage = imgPath
        self.imageOverlay_.props.opacity = 1.0
        self.imageOverlay_:SetVisible(true)

        -- 已装备：亮底 + 品质色边框
        local bc, bw = self:GetSlotBorderStyle()
        self.props.borderColor = bc
        self.props.borderWidth = bw
        self.props.backgroundColor = {55, 60, 80, 255}

    elseif not item and self.props.showTypeIcon ~= false and isImagePath(self.props.slotTypeIcon) then
        -- Empty equipment slot with image type icon (grayed out)
        self.iconLabel_:SetText("")
        self.imageOverlay_.props.backgroundImage = self.props.slotTypeIcon
        self.imageOverlay_.props.opacity = 0.15
        self.imageOverlay_:SetVisible(true)

        -- 空槽：暗底 + 虚线感边框
        self.props.backgroundColor = {20, 22, 30, 220}
        local bc, bw = self:GetSlotBorderStyle()
        self.props.borderColor = bc
        self.props.borderWidth = bw
    else
        -- Fallback to emoji (already handled by parent)
        self.imageOverlay_.props.backgroundImage = nil
        self.imageOverlay_:SetVisible(false)
        -- 有物品时显示品质色边框，无物品恢复默认
        if item and item.quality then
            local bc, bw = self:GetSlotBorderStyle()
            self.props.borderColor = bc
            self.props.borderWidth = bw
            self.props.backgroundColor = {40, 45, 60, 220}
        else
            self.props.borderColor = {60, 65, 75, 255}
            self.props.borderWidth = 1
            self.props.backgroundColor = {30, 35, 50, 220}
        end
    end
end

--- 重写 OnPointerEnter：仅保留拖拽悬停高亮，移除普通 hover 变色
function ImageItemSlot:OnPointerEnter(event)
    Widget.OnPointerEnter(self, event)
    self.isHovered_ = true

    local dragCtx = self.props.dragContext
    if dragCtx and dragCtx:IsDragging() then
        self.isDragOver_ = true
        if dragCtx:CanDrop(self) then
            self.props.borderColor = {100, 200, 100, 255}  -- 绿色：可放置
        else
            self.props.borderColor = {200, 100, 100, 255}  -- 红色：不可放置
        end
    end
    -- 非拖拽时不改变边框颜色
end

--- 重写 OnPointerLeave：恢复品质色边框而非默认灰色
function ImageItemSlot:OnPointerLeave(event)
    Widget.OnPointerLeave(self, event)
    self.isHovered_ = false
    self.isDragOver_ = false
    -- 恢复当前槽位应有的边框样式（品质色/空槽色）
    local bc, bw = self:GetSlotBorderStyle()
    self.props.borderColor = bc
    self.props.borderWidth = bw
end

return ImageItemSlot
