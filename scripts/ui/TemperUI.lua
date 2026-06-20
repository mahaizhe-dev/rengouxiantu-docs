---@diagnostic disable
-- ============================================================================
-- TemperUI.lua - 附灵师面板（萃取 + 附灵）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: 手动卡片height=76% | 预览格操作板 | Tab Show/Hide | S10语义按钮
--
-- Tab1 萃取：背包中3件同套装备 + 100灵韵 → 附灵玉
-- Tab2 附灵：已装备装备 + 附灵玉 + 100灵韵 → 写入 enchantSetId
-- ============================================================================

local UI           = require("urhox-libs/UI")
local GameConfig   = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState    = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local EventBus     = require("core.EventBus")
local SaveSession  = require("systems.save.SaveSession")
local T            = require("config.UITheme")
local IconUtils    = require("utils.IconUtils")
local ImageItemSlot = require("ui.ImageItemSlot")

local TemperUI = {}

-- ── 模块状态 ─────────────────────────────────────────────────────────────────
local panel_          = nil
local visible_        = false
local activeTab_      = "extract"
local parentOverlay_  = nil

-- Tab 按钮
local tabBtnExtract_  = nil
local tabBtnEnchant_  = nil

-- 内容区
local contentArea_    = nil
local resultLabel_    = nil

-- 预览格引用
local extractSlots_   = {}  -- [1],[2],[3] ImageItemSlot
local enchantEquipSlot_ = nil
local enchantLingyuSlot_ = nil

-- 弹窗
local obtainPopup_          = nil
local obtainIconPanel_      = nil
local obtainIconEmojiLabel_ = nil
local obtainNameLabel_      = nil
local enchantPopup_          = nil
local enchantIconPanel_      = nil
local enchantIconEmojiLabel_ = nil
local enchantEquipNameLabel_ = nil

-- 萃取状态
local selectedExtractSlots_ = {}

-- 附灵状态
local selectedEquipSlot_ = nil
local selectedLingyuId_  = nil

-- ── 常量 ─────────────────────────────────────────────────────────────────────
local COST_LINGYUN = 100
local SLOT_SIZE = T.size.slotSize  -- 56

local VALID_SET_IDS = { xuesha = true, qingyun = true, fengmo = true, haoqi = true }

local LINGYU_TO_SET = {
    lingyu_xuesha_lv1  = "xuesha",
    lingyu_qingyun_lv1 = "qingyun",
    lingyu_fengmo_lv1  = "fengmo",
    lingyu_haoqi_lv1   = "haoqi",
}

local SET_NAMES = {
    xuesha  = "血煞",
    qingyun = "青云",
    fengmo  = "封魔",
    haoqi   = "浩气",
}

local SET_TO_LINGYU = {
    xuesha  = "lingyu_xuesha_lv1",
    qingyun = "lingyu_qingyun_lv1",
    fengmo  = "lingyu_fengmo_lv1",
    haoqi   = "lingyu_haoqi_lv1",
}

local SET_COLORS = {
    xuesha  = T.color.setXuesha,
    qingyun = T.color.setQingyun,
    fengmo  = T.color.setFengmo,
    haoqi   = T.color.setHaoqi,
}

-- ── 辅助函数 ──────────────────────────────────────────────────────────────────

local function GetItemExtractSetId(item)
    if not item then return nil end
    if item.setId and VALID_SET_IDS[item.setId] then return item.setId end
    if item.enchantSetId and VALID_SET_IDS[item.enchantSetId] then return item.enchantSetId end
    return nil
end

local function ScanExtractableItems()
    local manager = InventorySystem.GetManager()
    if not manager then return {} end
    local list = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager:GetInventoryItem(i)
        local sid = GetItemExtractSetId(item)
        if sid then
            list[#list + 1] = { slotIndex = i, item = item, setId = sid, setName = SET_NAMES[sid] or sid, isEnchanted = (item.enchantSetId ~= nil) }
        end
    end
    return list
end

local function ScanEnchantable()
    local manager = InventorySystem.GetManager()
    if not manager then return {} end
    local list = {}
    local equipped = manager:GetAllEquipment()
    if not equipped then return list end
    local SLOT_ORDER = { "weapon","helmet","armor","shoulder","belt","boots","ring1","ring2","necklace","cape","treasure","exclusive" }
    local SLOT_NAMES = { weapon="武器", helmet="头盔", armor="铠甲", shoulder="肩甲", belt="腰带", boots="靴子", ring1="戒指1", ring2="戒指2", necklace="项链", cape="披风", treasure="法宝", exclusive="法宝" }
    for _, slotId in ipairs(SLOT_ORDER) do
        local item = equipped[slotId]
        if item then list[#list + 1] = { slotId = slotId, slotName = SLOT_NAMES[slotId] or slotId, item = item } end
    end
    return list
end

local function ScanLingyuInBag()
    local list = {}
    local ORDER = {"lingyu_xuesha_lv1","lingyu_qingyun_lv1","lingyu_fengmo_lv1","lingyu_haoqi_lv1"}
    for _, lingyuId in ipairs(ORDER) do
        local setId = LINGYU_TO_SET[lingyuId]
        local count = InventorySystem.CountConsumable(lingyuId)
        if count > 0 then
            local cfgData = GameConfig.PET_MATERIALS[lingyuId]
            list[#list + 1] = {
                consumableId = lingyuId, count = count, setId = setId,
                setName = SET_NAMES[setId] or setId,
                name = cfgData and cfgData.name or lingyuId,
                image = cfgData and cfgData.image or nil,
                color = SET_COLORS[setId] or T.color.textSecondary,
            }
        end
    end
    return list
end

local function StripSetPrefix(name)
    for _, sname in pairs(SET_NAMES) do
        local stripped = name:match("^" .. sname .. "%·(.+)$") or name:match("^" .. sname .. "(.+)$")
        if stripped and #stripped > 0 then return stripped end
    end
    return name
end

local function GetDisplayName(item)
    if not item then return "" end
    local sid = item.enchantSetId
    if sid and SET_NAMES[sid] then return SET_NAMES[sid] .. "·" .. StripSetPrefix(item.name or "") end
    if item.setId and SET_NAMES[item.setId] then return SET_NAMES[item.setId] .. "·" .. StripSetPrefix(item.name or "") end
    return item.name or ""
end

-- ── 萃取逻辑 ──────────────────────────────────────────────────────────────────

local function GetSelectedExtractInfo()
    local sid, count = nil, 0
    local manager = InventorySystem.GetManager()
    if not manager then return nil, 0 end
    for slotIndex in pairs(selectedExtractSlots_) do
        local item = manager:GetInventoryItem(slotIndex)
        local itemSid = GetItemExtractSetId(item)
        if not itemSid then return nil, 0 end
        if sid == nil then sid = itemSid
        elseif sid ~= itemSid then return nil, 0 end
        count = count + 1
    end
    return sid, count
end

local function DoExtract()
    local sid, count = GetSelectedExtractInfo()
    if not sid or count ~= 3 then return false, "请选择同一套装的3件装备" end
    local player = GameState.player
    if not player then return false, "内部错误" end
    if player.lingYun < COST_LINGYUN then return false, "灵韵不足（需要" .. COST_LINGYUN .. "）" end
    local manager = InventorySystem.GetManager()
    if not manager then return false, "内部错误" end
    local outputId = SET_TO_LINGYU[sid]
    -- 移除3件
    local removedItems = {}
    for slotIndex in pairs(selectedExtractSlots_) do
        removedItems[slotIndex] = manager:GetInventoryItem(slotIndex)
        manager:SetInventoryItem(slotIndex, nil)
    end
    -- 产出
    local addOk = InventorySystem.AddConsumable(outputId, 1)
    if not addOk then
        for slotIndex, item in pairs(removedItems) do manager:SetInventoryItem(slotIndex, item) end
        return false, "背包异常，请清理后重试"
    end
    player.lingYun = player.lingYun - COST_LINGYUN
    EventBus.Emit("player_lingyun_change", player.lingYun)
    EventBus.Emit("temper_extract", sid, outputId)
    SaveSession.MarkDirty()
    selectedExtractSlots_ = {}
    return true, "萃取成功！获得【附灵玉·" .. (SET_NAMES[sid] or sid) .. "】×1", outputId
end

-- ── 附灵逻辑 ──────────────────────────────────────────────────────────────────

local function DoEnchant()
    if not selectedEquipSlot_ then return false, "请选择装备" end
    if not selectedLingyuId_ then return false, "请选择附灵玉" end
    local player = GameState.player
    if not player then return false, "内部错误" end
    if player.lingYun < COST_LINGYUN then return false, "灵韵不足" end
    local manager = InventorySystem.GetManager()
    if not manager then return false, "内部错误" end
    local equipped = manager:GetAllEquipment()
    local item = equipped and equipped[selectedEquipSlot_]
    if not item then return false, "装备不存在" end
    if InventorySystem.CountConsumable(selectedLingyuId_) < 1 then return false, "附灵玉不足" end
    local setId = LINGYU_TO_SET[selectedLingyuId_]
    if not setId then return false, "无效附灵玉" end
    local consumeOk = InventorySystem.ConsumeConsumable(selectedLingyuId_, 1)
    if not consumeOk then return false, "附灵玉消耗失败" end
    player.lingYun = player.lingYun - COST_LINGYUN
    EventBus.Emit("player_lingyun_change", player.lingYun)
    if item.setId and VALID_SET_IDS[item.setId] then item.setId = nil end
    item.enchantSetId = setId
    item.name = SET_NAMES[setId] .. "·" .. StripSetPrefix(item.name or "")
    InventorySystem.RecalcEquipStats()
    EventBus.Emit("temper_enchant", selectedEquipSlot_, setId, item)
    SaveSession.MarkDirty()
    local enchantedItem = item
    selectedEquipSlot_ = nil
    selectedLingyuId_ = nil
    return true, "附灵成功！【" .. item.name .. "】获得" .. (SET_NAMES[setId] or "") .. "套装", enchantedItem
end

-- ── Tab 内容构建 ──────────────────────────────────────────────────────────────

local function BuildExtractTab()
    local itemList = ScanExtractableItems()
    local player = GameState.player
    local lingYun = player and player.lingYun or 0
    local enoughLY = lingYun >= COST_LINGYUN
    local selSid, selCount = GetSelectedExtractInfo()
    local canConfirm = selSid ~= nil and selCount == 3 and enoughLY

    -- 获取选中物品列表（按顺序）
    local selItems = {}
    local manager = InventorySystem.GetManager()
    if manager then
        for slotIndex in pairs(selectedExtractSlots_) do
            local item = manager:GetInventoryItem(slotIndex)
            if item then selItems[#selItems + 1] = item end
        end
    end

    -- 3个预览格子
    local previewSlots = UI.Panel {
        flexDirection = "row", justifyContent = "center", gap = T.spacing.sm,
    }
    for i = 1, 3 do
        local slot = ImageItemSlot {
            slotId = "extract_preview_" .. i,
            slotCategory = "temper_preview",
            size = SLOT_SIZE,
            showTypeIcon = false,
        }
        if selItems[i] then slot:SetItem(selItems[i]) end
        previewSlots:AddChild(slot)
    end

    -- 状态提示
    local hintText
    if selCount == 0 then hintText = "选择3件同套装装备"
    elseif selCount < 3 then hintText = "已选 " .. selCount .. "/3（" .. (SET_NAMES[selSid] or "") .. "）"
    else hintText = "✓ 已选3件 " .. (SET_NAMES[selSid] or "") .. " 套装"
    end

    -- 操作板
    local opPanel = UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1, borderColor = T.color.border,
        padding = T.spacing.sm,
        alignItems = "center",
        gap = T.spacing.xs,
        children = {
            previewSlots,
            UI.Label { text = hintText, fontSize = T.fontSize.xs, fontColor = selCount == 3 and T.color.success or T.color.textSecondary },
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = T.spacing.sm,
                children = {
                    UI.Label { text = "消耗🔮" .. COST_LINGYUN .. "灵韵", fontSize = T.fontSize.xs, fontColor = enoughLY and T.color.info or T.color.error },
                    UI.Button {
                        text = "萃取", fontSize = T.fontSize.sm, fontWeight = "bold",
                        paddingLeft = T.spacing.lg, paddingRight = T.spacing.lg,
                        height = 32, borderRadius = T.radius.sm,
                        backgroundColor = canConfirm and T.color.btnSpend or T.color.btnDisabled,
                        fontColor = canConfirm and T.color.btnSpendFg or T.color.btnDisabledFg,
                        disabled = not canConfirm,
                        onClick = canConfirm and function()
                            local ok, msg, outputId = DoExtract()
                            if resultLabel_ then resultLabel_:SetText(msg) end
                            if ok and outputId then TemperUI.ShowObtainPopup(outputId) end
                            TemperUI.RefreshContent()
                        end or nil,
                    },
                },
            },
        },
    }

    -- 物品列表
    local cards = {}
    if #itemList == 0 then
        cards[1] = UI.Label { text = "背包中没有可萃取的装备", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center", padding = T.spacing.lg }
    else
        for _, entry in ipairs(itemList) do
            local slot = entry.slotIndex
            local item = entry.item
            local col = SET_COLORS[entry.setId] or T.color.textSecondary
            local isSel = selectedExtractSlots_[slot] == true
            local canSelect = isSel or selCount < 3
            local qCfg = GameConfig.QUALITY[item.quality]
            local qColor = qCfg and qCfg.color or T.color.textPrimary

            cards[#cards + 1] = UI.Panel {
                flexDirection = "row", alignItems = "center",
                backgroundColor = isSel and T.color.surfaceLight or T.color.surface,
                borderRadius = T.radius.sm,
                borderWidth = isSel and 2 or 1,
                borderColor = isSel and col or T.color.borderLight,
                padding = T.spacing.sm, gap = T.spacing.sm,
                marginBottom = T.spacing.xs,
                onClick = canSelect and function()
                    if isSel then selectedExtractSlots_[slot] = nil
                    else
                        if selSid and selSid ~= entry.setId then selectedExtractSlots_ = {} end
                        selectedExtractSlots_[slot] = true
                    end
                    TemperUI.RefreshContent()
                end or nil,
                children = {
                    UI.Panel { width = 4, height = 32, borderRadius = 2, backgroundColor = col },
                    UI.Panel { flexGrow = 1, flexShrink = 1, gap = T.spacing.xxs, children = {
                        UI.Label { text = GetDisplayName(item), fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = qColor },
                        UI.Label { text = entry.setName .. "套装 T" .. (item.tier or "?"), fontSize = T.fontSize.xxs, fontColor = T.color.textMuted },
                    }},
                    isSel and UI.Label { text = "✓", fontSize = T.fontSize.sm, fontColor = col } or UI.Panel { width = 14 },
                },
            }
        end
    end

    return UI.Panel {
        width = "100%", flexGrow = 1, gap = T.spacing.sm,
        children = {
            opPanel,
            UI.ScrollView { flexGrow = 1, flexShrink = 1, flexBasis = 0, children = cards },
        },
    }
end

local function BuildEnchantTab()
    local enchantableList = ScanEnchantable()
    local lingyuList = ScanLingyuInBag()
    local player = GameState.player
    local lingYun = player and player.lingYun or 0
    local enoughLY = lingYun >= COST_LINGYUN
    local canConfirm = selectedEquipSlot_ ~= nil and selectedLingyuId_ ~= nil and enoughLY

    -- 获取选中物品
    local selEquipItem = nil
    if selectedEquipSlot_ then
        local manager = InventorySystem.GetManager()
        if manager then
            local equipped = manager:GetAllEquipment()
            selEquipItem = equipped and equipped[selectedEquipSlot_]
        end
    end
    local selLingyuData = nil
    if selectedLingyuId_ then
        for _, ly in ipairs(lingyuList) do
            if ly.consumableId == selectedLingyuId_ then selLingyuData = ly; break end
        end
    end

    -- 预览：装备格 → 灵玉格
    local equipPreview = ImageItemSlot { slotId = "enchant_equip_preview", slotCategory = "temper_preview", size = SLOT_SIZE, showTypeIcon = false }
    if selEquipItem then equipPreview:SetItem(selEquipItem) end

    local lingyuPreview = ImageItemSlot { slotId = "enchant_lingyu_preview", slotCategory = "temper_preview", size = SLOT_SIZE, showTypeIcon = false }
    if selLingyuData then
        lingyuPreview:SetItem({ name = selLingyuData.name, image = selLingyuData.image, quality = "purple" })
    end

    -- 操作板
    local equipName = selEquipItem and GetDisplayName(selEquipItem) or "未选择"
    local lingyuName = selLingyuData and (selLingyuData.setName .. "附灵玉") or "未选择"

    local opPanel = UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1, borderColor = T.color.border,
        padding = T.spacing.sm,
        alignItems = "center",
        gap = T.spacing.xs,
        children = {
            -- 预览格：装备 → 灵玉
            UI.Panel {
                flexDirection = "row", alignItems = "center", justifyContent = "center",
                gap = T.spacing.md,
                children = {
                    UI.Panel { alignItems = "center", gap = T.spacing.xxs, children = {
                        equipPreview,
                        UI.Label { text = equipName, fontSize = T.fontSize.xxs, fontColor = T.color.textSecondary, textAlign = "center" },
                    }},
                    UI.Label { text = "→", fontSize = T.fontSize.lg, fontColor = T.color.textMuted },
                    UI.Panel { alignItems = "center", gap = T.spacing.xxs, children = {
                        lingyuPreview,
                        UI.Label { text = lingyuName, fontSize = T.fontSize.xxs, fontColor = T.color.textSecondary, textAlign = "center" },
                    }},
                },
            },
            -- 费用 + 按钮
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = T.spacing.sm,
                children = {
                    UI.Label { text = "消耗🔮" .. COST_LINGYUN .. "灵韵", fontSize = T.fontSize.xs, fontColor = enoughLY and T.color.info or T.color.error },
                    UI.Button {
                        text = "附灵", fontSize = T.fontSize.sm, fontWeight = "bold",
                        paddingLeft = T.spacing.lg, paddingRight = T.spacing.lg,
                        height = 32, borderRadius = T.radius.sm,
                        backgroundColor = canConfirm and T.color.btnSpend or T.color.btnDisabled,
                        fontColor = canConfirm and T.color.btnSpendFg or T.color.btnDisabledFg,
                        disabled = not canConfirm,
                        onClick = canConfirm and function()
                            local ok, msg, enchantedItem = DoEnchant()
                            if resultLabel_ then resultLabel_:SetText(msg) end
                            if ok and enchantedItem then TemperUI.ShowEnchantPopup(enchantedItem) end
                            TemperUI.RefreshContent()
                        end or nil,
                    },
                },
            },
        },
    }

    -- 装备列表
    local equipCards = {}
    for _, entry in ipairs(enchantableList) do
        local isSelected = selectedEquipSlot_ == entry.slotId
        local item = entry.item
        local qCfg = GameConfig.QUALITY[item.quality]
        local qColor = qCfg and qCfg.color or T.color.textPrimary
        local badgeText, badgeColor = "", T.color.textMuted
        if item.enchantSetId and SET_NAMES[item.enchantSetId] then
            badgeText = SET_NAMES[item.enchantSetId] .. "·已附灵"
            badgeColor = SET_COLORS[item.enchantSetId] or T.color.textSecondary
        elseif item.setId and SET_NAMES[item.setId] then
            badgeText = SET_NAMES[item.setId] .. "·套装"
            badgeColor = SET_COLORS[item.setId] or T.color.textSecondary
        end

        equipCards[#equipCards + 1] = UI.Panel {
            flexDirection = "row", alignItems = "center",
            backgroundColor = isSelected and T.color.surfaceLight or T.color.surface,
            borderRadius = T.radius.sm,
            borderWidth = isSelected and 2 or 1,
            borderColor = isSelected and T.color.qualityPurple or T.color.borderLight,
            padding = T.spacing.sm, gap = T.spacing.sm, marginBottom = T.spacing.xs,
            onClick = function()
                selectedEquipSlot_ = (selectedEquipSlot_ == entry.slotId) and nil or entry.slotId
                TemperUI.RefreshContent()
            end,
            children = {
                UI.Panel { flexGrow = 1, flexShrink = 1, gap = T.spacing.xxs, children = {
                    UI.Label { text = GetDisplayName(item), fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = qColor },
                    UI.Panel { flexDirection = "row", gap = T.spacing.xs, children = {
                        UI.Label { text = entry.slotName, fontSize = T.fontSize.xxs, fontColor = T.color.textMuted },
                        UI.Label { text = badgeText, fontSize = T.fontSize.xxs, fontColor = badgeColor },
                    }},
                }},
                isSelected and UI.Label { text = "✓", fontSize = T.fontSize.sm, fontColor = T.color.qualityPurple } or UI.Panel { width = 14 },
            },
        }
    end

    -- 附灵玉列表
    local lingyuCards = {}
    for _, ly in ipairs(lingyuList) do
        local isSelected = selectedLingyuId_ == ly.consumableId
        local iconWidget = UI.Panel {
            width = 28, height = 28, borderRadius = T.radius.sm,
            backgroundColor = T.color.surface,
            backgroundImage = ly.image or nil,
            backgroundFit = "contain",
        }
        lingyuCards[#lingyuCards + 1] = UI.Panel {
            flexDirection = "row", alignItems = "center",
            backgroundColor = isSelected and T.color.surfaceLight or T.color.surface,
            borderRadius = T.radius.sm,
            borderWidth = isSelected and 2 or 1,
            borderColor = isSelected and ly.color or T.color.borderLight,
            padding = T.spacing.sm, gap = T.spacing.sm, marginBottom = T.spacing.xs,
            onClick = function()
                selectedLingyuId_ = (selectedLingyuId_ == ly.consumableId) and nil or ly.consumableId
                TemperUI.RefreshContent()
            end,
            children = {
                iconWidget,
                UI.Panel { flexGrow = 1, flexShrink = 1, gap = T.spacing.xxs, children = {
                    UI.Label { text = ly.setName .. " 附灵玉", fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = ly.color },
                    UI.Label { text = "×" .. ly.count, fontSize = T.fontSize.xxs, fontColor = T.color.textMuted },
                }},
                isSelected and UI.Label { text = "✓", fontSize = T.fontSize.sm, fontColor = ly.color } or UI.Panel { width = 14 },
            },
        }
    end

    return UI.Panel {
        width = "100%", flexGrow = 1, gap = T.spacing.sm,
        children = {
            opPanel,
            UI.Label { text = "── ① 装备栏 ──", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center", width = "100%" },
            UI.ScrollView { flexGrow = 1, flexShrink = 1, flexBasis = 0, children = equipCards },
            UI.Label { text = "── ② 附灵玉 ──", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center", width = "100%" },
            UI.Panel { gap = T.spacing.xs, children = lingyuCards },
        },
    }
end

-- ── Tab 切换 ──────────────────────────────────────────────────────────────────

local function SwitchTab(tab)
    if activeTab_ == tab then return end
    activeTab_ = tab
    if tabBtnExtract_ then tabBtnExtract_:SetBackgroundColor(tab == "extract" and T.color.tabActiveBg or T.color.tabInactiveBg) end
    if tabBtnEnchant_ then tabBtnEnchant_:SetBackgroundColor(tab == "enchant" and T.color.tabActiveBg or T.color.tabInactiveBg) end
    selectedExtractSlots_ = {}
    selectedEquipSlot_ = nil
    selectedLingyuId_ = nil
    if resultLabel_ then resultLabel_:SetText("") end
    TemperUI.RefreshContent()
end

-- ── 公共接口 ──────────────────────────────────────────────────────────────────

function TemperUI.RefreshContent()
    if not contentArea_ then return end
    contentArea_:ClearChildren()
    contentArea_:AddChild((activeTab_ == "extract") and BuildExtractTab() or BuildEnchantTab())
end

function TemperUI.ShowObtainPopup(outputId)
    if not obtainPopup_ then return end
    local mat = GameConfig.PET_MATERIALS[outputId]
    local name = (mat and mat.name) or outputId
    if mat and mat.image and obtainIconPanel_ then
        obtainIconPanel_:SetStyle({ backgroundImage = mat.image })
        if obtainIconEmojiLabel_ then obtainIconEmojiLabel_:Hide() end
    else
        if obtainIconPanel_ then obtainIconPanel_:SetStyle({ backgroundImage = "" }) end
        if obtainIconEmojiLabel_ then obtainIconEmojiLabel_:SetText((mat and mat.icon) or "💎"); obtainIconEmojiLabel_:Show() end
    end
    if obtainNameLabel_ then obtainNameLabel_:SetText(name) end
    obtainPopup_:Show()
end

function TemperUI.ShowEnchantPopup(item)
    if not enchantPopup_ then return end
    if item.icon and IconUtils.IsImagePath(item.icon) and enchantIconPanel_ then
        enchantIconPanel_:SetStyle({ backgroundImage = item.icon })
        if enchantIconEmojiLabel_ then enchantIconEmojiLabel_:Hide() end
    else
        if enchantIconPanel_ then enchantIconPanel_:SetStyle({ backgroundImage = "" }) end
        if enchantIconEmojiLabel_ then enchantIconEmojiLabel_:SetText(IconUtils.GetTextIcon(item.icon, "⚔️")); enchantIconEmojiLabel_:Show() end
    end
    if enchantEquipNameLabel_ then enchantEquipNameLabel_:SetText(item.name or "") end
    enchantPopup_:Show()
end

-- ── 面板创建（S2.4 手动模板，height="76%" 固定高度） ──────────────────────────

function TemperUI.Create(parentOverlay)
    if panel_ then return end
    parentOverlay_ = parentOverlay

    -- NPC 头像
    local portraitPanel = UI.Panel {
        width = 64, height = 64,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        overflow = "hidden",
        backgroundImage = "Textures/npc_temper_master.png",
        backgroundFit = "contain",
    }

    -- Tab 栏
    tabBtnExtract_ = UI.Button {
        text = "✨ 萃取", flexGrow = 1, height = 36,
        fontSize = T.fontSize.sm, fontWeight = "bold", borderRadius = T.radius.sm,
        backgroundColor = T.color.tabActiveBg, fontColor = T.color.tabActiveText,
        onClick = function() SwitchTab("extract") end,
    }
    tabBtnEnchant_ = UI.Button {
        text = "💎 附灵", flexGrow = 1, height = 36,
        fontSize = T.fontSize.sm, fontWeight = "bold", borderRadius = T.radius.sm,
        backgroundColor = T.color.tabInactiveBg, fontColor = T.color.tabInactiveText,
        onClick = function() SwitchTab("enchant") end,
    }

    -- 内容区
    contentArea_ = UI.Panel { width = "100%", flexGrow = 1, flexShrink = 1, flexBasis = 0 }

    -- 结果标签
    resultLabel_ = UI.Label { text = "", fontSize = T.fontSize.xs, fontColor = T.color.success, textAlign = "center" }

    -- 主面板（S2.4 手动模板，height="76%" 强制撑满）
    panel_ = UI.Panel {
        position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center", alignItems = "center",
        visible = false, zIndex = 900,
        onClick = function() TemperUI.Hide() end,
        children = {
            UI.Panel {
                width = "94%", maxWidth = T.size.npcPanelMaxW,
                height = "76%",  -- 固定高度，不自适应收缩
                flexDirection = "column",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = T.color.goldDark,
                onClick = function() end,  -- 阻止冒泡
                children = {
                    -- header（无背景色，S2.3）
                    UI.Panel {
                        width = "100%", flexDirection = "row", alignItems = "center",
                        paddingLeft = T.spacing.sm, paddingRight = T.spacing.md,
                        paddingTop = T.spacing.sm, paddingBottom = T.spacing.sm,
                        borderBottomWidth = 1, borderColor = T.color.border,
                        children = {
                            portraitPanel,
                            UI.Panel { flexGrow = 1, flexShrink = 1, marginLeft = T.spacing.sm, gap = T.spacing.xxs, children = {
                                UI.Label { text = "附灵师", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.gold },
                                UI.Label { text = "萃取·附灵", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
                            }},
                            UI.Button {
                                text = "✕", width = T.size.closeButton, height = T.size.closeButton,
                                fontSize = T.fontSize.md, fontWeight = "bold",
                                borderRadius = T.radius.sm,
                                backgroundColor = {255, 100, 100, 30}, fontColor = T.color.error,
                                onClick = function() TemperUI.Hide() end,
                            },
                        },
                    },
                    -- Tab 栏
                    UI.Panel {
                        width = "100%", flexDirection = "row", gap = T.spacing.xs,
                        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm, paddingTop = T.spacing.xs,
                        children = { tabBtnExtract_, tabBtnEnchant_ },
                    },
                    -- 内容区（填满剩余）
                    UI.ScrollView {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
                        paddingTop = T.spacing.sm, paddingBottom = T.spacing.sm,
                        children = { contentArea_ },
                    },
                    -- footer
                    UI.Panel {
                        width = "100%", alignItems = "center",
                        paddingTop = T.spacing.xs, paddingBottom = T.spacing.sm,
                        borderTopWidth = 1, borderColor = T.color.border,
                        gap = T.spacing.xs,
                        children = {
                            resultLabel_,
                            UI.Label { text = "点击空白处关闭", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
                        },
                    },
                },
            },
        },
    }

    -- ── 弹窗 ──
    obtainIconEmojiLabel_ = UI.Label { text = "💎", fontSize = 36, textAlign = "center" }
    obtainIconPanel_ = UI.Panel { width = 72, height = 72, alignSelf = "center", backgroundFit = "contain", justifyContent = "center", alignItems = "center", children = { obtainIconEmojiLabel_ } }
    obtainNameLabel_ = UI.Label { text = "", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = T.color.gold, textAlign = "center" }
    obtainPopup_ = UI.Panel {
        position = "absolute", width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = T.color.overlay, zIndex = 910, visible = false,
        children = { UI.Panel {
            width = "88%", maxWidth = 400,
            backgroundColor = T.color.panelBg, borderRadius = T.radius.lg,
            borderWidth = 1, borderColor = T.color.goldDark,
            padding = T.spacing.lg, gap = T.spacing.sm, alignItems = "center",
            onClick = function() end,
            children = {
                UI.Label { text = "✨ 萃取成功", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.gold },
                obtainIconPanel_, obtainNameLabel_,
                UI.Label { text = "×1", fontSize = T.fontSize.sm, fontColor = T.color.success },
                UI.Button { text = "确认", width = 120, height = 32, fontSize = T.fontSize.sm, borderRadius = T.radius.sm, backgroundColor = T.color.btnSecondary, fontColor = T.color.btnSecondaryFg, onClick = function() if obtainPopup_ then obtainPopup_:Hide() end end },
            },
        }},
    }
    parentOverlay:AddChild(obtainPopup_)

    enchantIconEmojiLabel_ = UI.Label { text = "⚔️", fontSize = 36, textAlign = "center" }
    enchantIconPanel_ = UI.Panel { width = 72, height = 72, alignSelf = "center", backgroundFit = "contain", justifyContent = "center", alignItems = "center", children = { enchantIconEmojiLabel_ } }
    enchantEquipNameLabel_ = UI.Label { text = "", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = T.color.gold, textAlign = "center" }
    enchantPopup_ = UI.Panel {
        position = "absolute", width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = T.color.overlay, zIndex = 910, visible = false,
        children = { UI.Panel {
            width = "88%", maxWidth = 400,
            backgroundColor = T.color.panelBg, borderRadius = T.radius.lg,
            borderWidth = 1, borderColor = T.color.goldDark,
            padding = T.spacing.lg, gap = T.spacing.sm, alignItems = "center",
            onClick = function() end,
            children = {
                UI.Label { text = "💎 附灵成功", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.info },
                enchantIconPanel_, enchantEquipNameLabel_,
                UI.Label { text = "已注入套装灵力", fontSize = T.fontSize.xs, fontColor = T.color.textSecondary },
                UI.Button { text = "确认", width = 120, height = 32, fontSize = T.fontSize.sm, borderRadius = T.radius.sm, backgroundColor = T.color.btnSecondary, fontColor = T.color.btnSecondaryFg, onClick = function() if enchantPopup_ then enchantPopup_:Hide() end end },
            },
        }},
    }
    parentOverlay:AddChild(enchantPopup_)

    parentOverlay:AddChild(panel_)
end

-- ── 显示/隐藏 ─────────────────────────────────────────────────────────────────

function TemperUI.Show()
    if not panel_ then return end
    if visible_ then return end
    selectedExtractSlots_ = {}
    selectedEquipSlot_ = nil
    selectedLingyuId_ = nil
    activeTab_ = "extract"
    if tabBtnExtract_ then tabBtnExtract_:SetBackgroundColor(T.color.tabActiveBg) end
    if tabBtnEnchant_ then tabBtnEnchant_:SetBackgroundColor(T.color.tabInactiveBg) end
    visible_ = true
    panel_:Show()
    if obtainPopup_ then obtainPopup_:Hide() end
    if enchantPopup_ then enchantPopup_:Hide() end
    GameState.uiOpen = "temper"
    if resultLabel_ then resultLabel_:SetText("") end
    TemperUI.RefreshContent()
end

function TemperUI.Hide()
    if not panel_ or not visible_ then return end
    SaveSession.Flush()
    visible_ = false
    panel_:Hide()
    if obtainPopup_ then obtainPopup_:Hide() end
    if enchantPopup_ then enchantPopup_:Hide() end
    if GameState.uiOpen == "temper" then GameState.uiOpen = nil end
end

function TemperUI.IsVisible()
    return visible_
end

function TemperUI.Destroy()
    if panel_ then panel_:Remove() end
    if obtainPopup_ then obtainPopup_:Remove() end
    if enchantPopup_ then enchantPopup_:Remove() end
    panel_ = nil; visible_ = false; contentArea_ = nil; resultLabel_ = nil
    tabBtnExtract_ = nil; tabBtnEnchant_ = nil
    obtainPopup_ = nil; obtainIconPanel_ = nil; obtainIconEmojiLabel_ = nil; obtainNameLabel_ = nil
    enchantPopup_ = nil; enchantIconPanel_ = nil; enchantIconEmojiLabel_ = nil; enchantEquipNameLabel_ = nil
    parentOverlay_ = nil
end

return TemperUI
