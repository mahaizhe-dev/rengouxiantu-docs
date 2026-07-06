-- ============================================================================
-- ImageItemSlot.lua - ItemSlot with image icon support
-- Extends engine's ItemSlot to render PNG icons instead of emoji text
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Panel = require("urhox-libs/UI/Widgets/Panel")
local Label = require("urhox-libs/UI/Widgets/Label")
local ItemSlot = require("urhox-libs/UI/Components/ItemSlot")
local T = require("config.UITheme")
local IconUtils = require("utils.IconUtils")
local TradeLock = require("systems.BlackMarketTradeLock")

---@class ImageItemSlot : ItemSlot
local ImageItemSlot = ItemSlot:Extend("ImageItemSlot")

local isImagePath = IconUtils.IsImagePath

local function ConfigImagePath(cfg)
    if not cfg then return nil end
    if cfg.image and isImagePath(cfg.image) then
        return cfg.image
    end
    if cfg.icon and isImagePath(cfg.icon) then
        return cfg.icon
    end
    return nil
end

local function ResolveConsumableConfig(consumableId)
    if not consumableId then return nil end
    local GameConfig = require("config.GameConfig")
    return (GameConfig.PET_FOOD and GameConfig.PET_FOOD[consumableId])
        or (GameConfig.PET_MATERIALS and GameConfig.PET_MATERIALS[consumableId])
        or (GameConfig.EVENT_ITEMS and GameConfig.EVENT_ITEMS[consumableId])
        or (GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[consumableId])
end

local function ResolveEquipmentImage(item)
    if not item or not item.equipId then return nil end
    local ok, EquipmentData = pcall(require, "config.EquipmentData")
    if not ok or not EquipmentData then return nil end

    local tpl = nil
    if item.isFabao and EquipmentData.FabaoTemplates then
        tpl = EquipmentData.FabaoTemplates[item.equipId]
    end
    if not tpl and EquipmentData.SpecialEquipment then
        tpl = EquipmentData.SpecialEquipment[item.equipId]
    end
    if not tpl then return nil end

    if tpl.iconByTier and item.tier then
        local tierIcon = tpl.iconByTier[item.tier] or tpl.iconByTier[9]
        if isImagePath(tierIcon) then return tierIcon end
    end
    return ConfigImagePath(tpl)
end

local function ResolveImagePath(item)
    if not item then return nil end
    if item.image and isImagePath(item.image) then
        return item.image
    end
    if isImagePath(item.icon) then
        return item.icon
    end
    if item.category == "mingge" and item.bossId then
        local MinggeData = require("config.MinggeData")
        if MinggeData.PORTRAITS and MinggeData.PORTRAITS[item.bossId] then
            return MinggeData.PORTRAITS[item.bossId]
        end
    end
    if item.consumableId then
        return ConfigImagePath(ResolveConsumableConfig(item.consumableId))
    end
    return ResolveEquipmentImage(item)
end

ImageItemSlot.ResolveImagePath = ResolveImagePath

local function BuildParentDisplayItem(item, imgPath)
    if not item then return nil end
    local displayItem = {}
    for k, v in pairs(item) do
        displayItem[k] = v
    end
    if item.count then
        displayItem.quantity = item.count
    end
    if imgPath or isImagePath(displayItem.icon) then
        displayItem.icon = ""
    end
    return displayItem
end

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

    -- 五行元素标识：延迟创建（仅命格物品需要，避免非命格槽位浪费节点）
    self.elementBadge_ = nil

    -- BM-S4AR: 锁图标覆盖层（右上角小标签）
    local lockSize = math.max(14, math.floor(self.props.size * 0.3))
    self.lockOverlay_ = Label {
        text = "🔒",
        fontSize = math.max(9, lockSize - 4),
        fontColor = {255, 180, 80, 255},
        textAlign = "center",
        position = "absolute",
        top = 1,
        right = 1,
        width = lockSize,
        height = lockSize,
        pointerEvents = "none",
    }
    self.lockOverlay_:SetVisible(false)
    Widget.AddChild(self, self.lockOverlay_)

    -- Re-run display update now that image overlay exists
    self:UpdateDisplay()
end

--- 生成物品显示指纹（用于跳过无变化的 UpdateDisplay）
local function ItemFingerprint(item)
    if not item then return nil end
    local imagePath = ResolveImagePath(item) or item.image or item.icon or ""
    -- 包含影响显示的所有关键字段
    return string.format("%s|%s|%s|%s|%d|%s|%s|%s|%s|%s|%s",
        tostring(item.name),
        tostring(imagePath),
        tostring(item.quality or ""),
        tostring(item.element or ""),
        item.count or item.quantity or 1,
        tostring(item.locked or false),
        tostring(item.equipped or false),
        tostring(item.setId or ""),
        tostring(item.bmNoResell or false),
        tostring(item.consumableId or ""),
        tostring(item.equipId or "")
    )
end

--- 覆写 SetItem：快速对比指纹，无变化则跳过重绘
function ImageItemSlot:SetItem(item)
    local newFP = ItemFingerprint(item)
    if newFP == self.lastItemFP_ and item == self.props.item then
        return  -- 同一物品引用且显示字段无变化，跳过
    end
    self.lastItemFP_ = newFP
    self.props.item = item
    self:UpdateDisplay()
end

--- 获取当前槽位应有的边框样式（品质色 / 空槽默认色）
function ImageItemSlot:GetSlotBorderStyle()
    local item = self.props.item
    if item then
        -- 有物品：查品质色（装备和消耗品通用）
        local GameConfig = require("config.GameConfig")
        local quality = item.quality
        -- 消耗品兼容：从配置补全 quality（统一用 CONSUMABLES 覆盖全品类）
        if item.category == "consumable" and not quality and item.consumableId then
            local cfgData = ResolveConsumableConfig(item.consumableId)
            if cfgData then quality = cfgData.quality end
        end
        local qCfg = quality and GameConfig.QUALITY[quality]
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
    -- Keep the source item immutable; count is copied into a display-only item below.

    local imgPath = ResolveImagePath(curItem)

    -- 阻止基类把 .png 路径写入 iconLabel（56px 容器放 ~395px 文本
    --    → CheckOverflow 每帧 100+ 次 print() → I/O 卡死）
    local parentItem = BuildParentDisplayItem(curItem, imgPath)
    if parentItem then
        self.props.item = parentItem
    end

    ItemSlot.UpdateDisplay(self)

    -- Restore the original item reference after the parent renders the display copy.
    if parentItem then
        self.props.item = curItem
    end

    -- Guard: imageOverlay_ not yet created during parent Init
    if not self.imageOverlay_ then return end

    local item = self.props.item

    if item and imgPath then
        -- Item with image icon: show image, hide emoji text (iconLabel already "" from above)
        self.imageOverlay_:SetStyle({ backgroundImage = imgPath, opacity = 1.0 })
        self.imageOverlay_:SetVisible(true)

        -- 已装备：亮底 + 品质色边框
        local bc, bw = self:GetSlotBorderStyle()
        self.props.borderColor = bc
        self.props.borderWidth = bw
        self.props.backgroundColor = {55, 60, 80, 255}

    elseif not item and self.props.showTypeIcon ~= false and isImagePath(self.props.slotTypeIcon) then
        -- Empty equipment slot with image type icon (grayed out)
        self.iconLabel_:SetText("")
        self.imageOverlay_:SetStyle({ backgroundImage = self.props.slotTypeIcon, opacity = 0.15 })
        self.imageOverlay_:SetVisible(true)

        -- 空槽：暗底 + 虚线感边框
        self.props.backgroundColor = {20, 22, 30, 220}
        local bc, bw = self:GetSlotBorderStyle()
        self.props.borderColor = bc
        self.props.borderWidth = bw
    else
        -- Fallback to emoji (already handled by parent)
        self.imageOverlay_:SetStyle({ backgroundImage = "", opacity = 1.0 })
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

    -- 锁图标显示/隐藏（item.locked = 玩家手动锁 | TradeLock.IsLocked = 旧存档残留临时锁，5 分钟内自然过期）
    if self.lockOverlay_ then
        if item and (item.locked or TradeLock.IsLocked(item)) then
            self.lockOverlay_:SetVisible(true)
        else
            self.lockOverlay_:SetVisible(false)
        end
    end

    -- BM-NORESELL(P1): 黑市购入永久角标（左下角"黑"，与右上角临时锁图标区分）
    -- bmNoResell 永不清除 → 角标永久存在；仅标识"不可回售黑市"，不限制使用/食用/合成
    if item and TradeLock.IsNoResell(item) then
        if not self.noResellBadge_ then
            local nrSize = math.max(12, math.floor(self.props.size * 0.30))
            self.noResellBadge_ = Label {
                text = "黑",
                fontSize = math.max(8, nrSize - 4),
                fontColor = {255, 230, 200, 255},
                textAlign = "center",
                position = "absolute",
                bottom = 1,
                left = 1,
                width = nrSize,
                height = nrSize,
                backgroundColor = {150, 40, 40, 220},
                borderRadius = 3,
                pointerEvents = "none",
            }
            Widget.AddChild(self, self.noResellBadge_)
        end
        self.noResellBadge_:SetVisible(true)
    elseif self.noResellBadge_ then
        self.noResellBadge_:SetVisible(false)
    end

    -- 五行元素标识（仅命格物品显示，按需创建）
    if item and item.category == "mingge" and item.element then
        local MinggeData = require("config.MinggeData")
        local elemName = MinggeData.ELEMENT_NAMES[item.element]
        local elemColor = MinggeData.ELEMENT_COLORS[item.element]
        if elemName then
            -- 按需创建 badge（首次遇到命格物品时）
            if not self.elementBadge_ then
                local elemSize = math.max(12, math.floor(self.props.size * 0.28))
                self.elementBadge_ = Label {
                    text = "",
                    fontSize = math.max(8, elemSize - 3),
                    fontColor = {255, 255, 255, 255},
                    textAlign = "center",
                    position = "absolute",
                    bottom = 1,
                    right = 1,
                    width = elemSize,
                    height = elemSize,
                    backgroundColor = {0, 0, 0, 160},
                    borderRadius = 3,
                    pointerEvents = "none",
                }
                Widget.AddChild(self, self.elementBadge_)
            end
            self.elementBadge_:SetText(elemName)
            if elemColor then
                self.elementBadge_.props.fontColor = elemColor
            end
            self.elementBadge_:SetVisible(true)
        elseif self.elementBadge_ then
            self.elementBadge_:SetVisible(false)
        end
    elseif self.elementBadge_ then
        self.elementBadge_:SetVisible(false)
    end

    -- 四象套装角标（左上角，仅命格物品有 setId 时显示）
    if item and item.category == "mingge" and item.setId then
        local MinggeData = require("config.MinggeData")
        local setColor = MinggeData.SET_COLORS and MinggeData.SET_COLORS[item.setId]
        local setShort = MinggeData.SET_SHORT and MinggeData.SET_SHORT[item.setId]
        if setColor and setShort then
            if not self.setBadge_ then
                local badgeSize = math.max(12, math.floor(self.props.size * 0.28))
                self.setBadge_ = Label {
                    text = "",
                    fontSize = math.max(8, badgeSize - 3),
                    fontColor = {255, 255, 255, 255},
                    textAlign = "center",
                    position = "absolute",
                    top = 1,
                    left = 1,
                    width = badgeSize,
                    height = badgeSize,
                    borderRadius = 3,
                    pointerEvents = "none",
                }
                Widget.AddChild(self, self.setBadge_)
            end
            self.setBadge_:SetText(setShort)
            self.setBadge_.props.backgroundColor = setColor
            self.setBadge_:SetVisible(true)
        elseif self.setBadge_ then
            self.setBadge_:SetVisible(false)
        end
    elseif self.setBadge_ then
        self.setBadge_:SetVisible(false)
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
