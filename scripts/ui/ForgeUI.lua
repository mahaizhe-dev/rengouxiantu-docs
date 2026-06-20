-- ============================================================================
-- ForgeUI.lua - 锻造师洗练面板
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: PanelShell骨架 | 顶部信息板操作 | 7列统一格子 | 身上/背包分区
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local EventBus = require("core.EventBus")
local SaveSession = require("systems.save.SaveSession")
local T = require("config.UITheme")
local PanelShell = require("ui.components.PanelShell")
local ImageItemSlot = require("ui.ImageItemSlot")

local ForgeUI = {}

-- ── 模块状态 ─────────────────────────────────────────────────────────────────
local shell_ = nil
local panel_ = nil
local visible_ = false
local selectedItem_ = nil     -- 当前选中的装备引用
local selectedSource_ = nil   -- "equipment" | "inventory"
local selectedSlot_ = nil     -- 装备槽位id 或 背包索引
local lastForgeTime_ = 0      -- 上次洗练时间戳（防连点）
local FORGE_THROTTLE = 0.5    -- 洗练最小间隔（秒）

-- 信息板控件引用
local infoPanel_ = nil        -- 顶部信息板容器
local infoNameLabel_ = nil    -- 选中装备名
local forgeStatLabel_ = nil   -- 洗练属性显示
local forgeBtn_ = nil         -- 洗练按钮
local resultLabel_ = nil      -- 操作结果反馈

-- 格子引用
local equipSlots_ = {}        -- 身上装备 slot widgets（key=slotId）
local invSlots_ = {}          -- 背包装备 slot widgets（key=index）

-- ── 常量 ─────────────────────────────────────────────────────────────────────
local SLOT_SIZE = T.size.slotSize
local SLOT_GAP = T.spacing.xs

-- 洗练费用（按阶级）
local FORGE_COST = {
    [1]  = 500,
    [2]  = 1000,
    [3]  = 2000,
    [4]  = 4000,
    [5]  = 8000,
    [6]  = 15000,
    [7]  = 25000,
    [8]  = 40000,
    [9]  = 60000,
    [10] = 100000,
    [11] = 160000,
}

-- 装备槽位顺序
local EQUIP_SLOT_ORDER = {
    "necklace", "helmet", "shoulder",
    "weapon", "armor", "cape",
    "ring1", "belt", "ring2",
    "exclusive", "boots", "treasure",
}

-- ============================================================================
-- 洗练逻辑（不动）
-- ============================================================================

--- 获取洗练费用
---@param item table
---@return number
local function GetForgeCost(item)
    return FORGE_COST[item.tier or 1] or 500
end

--- 计算某属性在指定 tier 下的洗练值范围文本
---@param statId string
---@param tier number
---@return string rangeText "（下限~上限）"
local function GetForgeRangeText(statId, tier)
    local baseDef = nil
    for _, sub in ipairs(EquipmentData.SUB_STATS) do
        if sub.stat == statId then baseDef = sub; break end
    end
    if not baseDef then return "" end

    local tierMult
    if EquipmentData.PCT_STATS[statId] then
        tierMult = EquipmentData.PCT_SUB_TIER_MULT[tier or 1] or 1.0
    else
        tierMult = EquipmentData.SUB_STAT_TIER_MULT[tier or 1] or 1.0
    end

    local rawMin = baseDef.baseValue * tierMult * 0.8
    local rawMax = baseDef.baseValue * tierMult * 1.2
    rawMin = math.floor(rawMin * 100 + 0.5) / 100
    rawMax = math.floor(rawMax * 100 + 0.5) / 100
    if rawMin <= 0 then rawMin = 0.01 end
    if rawMax <= 0 then rawMax = 0.01 end

    local function fmt(val)
        if EquipmentData.PCT_STATS[statId] or EquipmentData.PCT_MAIN_STATS[statId] then
            if statId == "critDmg" then return string.format("%.0f%%", val * 100)
            else return string.format("%.1f%%", val * 100) end
        elseif statId == "hpRegen" then return string.format("%.1f", val)
        else return tostring(math.floor(val))
        end
    end

    return "（" .. fmt(rawMin) .. "~" .. fmt(rawMax) .. "）"
end

--- 随机洗练一条副属性
---@param item table
---@return table|nil newStat {stat, name, value}
local function RollForgeStat(item)
    local excluded = {}
    if item.mainStat then
        for stat, _ in pairs(item.mainStat) do
            excluded[stat] = true
        end
    end
    if item.subStats then
        for _, sub in ipairs(item.subStats) do
            excluded[sub.stat] = true
        end
    end
    if item.forgeStat then
        excluded[item.forgeStat.stat] = true
    end

    local pool = {}
    for _, sub in ipairs(EquipmentData.SUB_STATS) do
        if not excluded[sub.stat] then
            table.insert(pool, sub)
        end
    end

    if #pool == 0 then return nil end

    local pick = pool[math.random(1, #pool)]
    local tierMult
    if EquipmentData.PCT_STATS[pick.stat] then
        tierMult = EquipmentData.PCT_SUB_TIER_MULT[item.tier or 1] or 1.0
    else
        tierMult = EquipmentData.SUB_STAT_TIER_MULT[item.tier or 1] or 1.0
    end
    local value = pick.baseValue * tierMult * (0.8 + math.random() * 0.4)
    value = math.floor(value * 100 + 0.5) / 100
    if value <= 0 then value = 0.01 end

    if not EquipmentData.PCT_STATS[pick.stat] and pick.stat ~= "hpRegen" then
        value = math.max(1, math.floor(value + 0.5))
    end

    return { stat = pick.stat, name = pick.name, value = value }
end

--- 格式化属性值（公开方法，外部有引用）
---@param sub table {stat, value}
---@return string
function ForgeUI.FormatStatValue(sub)
    if EquipmentData.PCT_STATS[sub.stat] or EquipmentData.PCT_MAIN_STATS[sub.stat] then
        if sub.stat == "critDmg" then
            return string.format("%.0f%%", sub.value * 100)
        else
            return string.format("%.1f%%", sub.value * 100)
        end
    elseif sub.stat == "hpRegen" then
        return string.format("%.1f/s", sub.value)
    else
        return tostring(math.floor(sub.value))
    end
end

--- 执行洗练
---@return boolean success
---@return string message
local function DoForge()
    if not selectedItem_ then return false, "请选择装备" end

    local player = GameState.player
    if not player then return false, "错误" end

    local cost = GetForgeCost(selectedItem_)
    if player.gold < cost then
        return false, "金币不足（需要 " .. cost .. "）"
    end

    local newStat = RollForgeStat(selectedItem_)
    if not newStat then
        return false, "该装备无法再洗练新属性"
    end

    -- 扣金币
    player.gold = player.gold - cost

    -- 写入洗练属性
    selectedItem_.forgeStat = newStat

    -- 如果是身上装备，刷新属性
    if selectedSource_ == "equipment" then
        InventorySystem.RecalcEquipStats()
    end

    SaveSession.MarkDirty()

    local rangeText = GetForgeRangeText(newStat.stat, selectedItem_.tier)
    return true, "洗练成功！" .. newStat.name .. " +" .. ForgeUI.FormatStatValue(newStat) .. " " .. rangeText
end

-- ============================================================================
-- 信息板刷新
-- ============================================================================

--- 刷新顶部信息板（选中状态变化时调用）
local function RefreshInfoPanel()
    if not infoPanel_ then return end

    -- 同步预览格子
    if ForgeUI._previewSlot then
        ForgeUI._previewSlot:SetItem(selectedItem_)
    end

    if not selectedItem_ then
        -- 未选中
        if infoNameLabel_ then
            infoNameLabel_:SetText("选择装备")
            infoNameLabel_:SetStyle({ fontColor = T.color.textSecondary })
        end
        if forgeStatLabel_ then
            forgeStatLabel_:SetText("点击下方格子选择")
            forgeStatLabel_:SetStyle({ fontColor = T.color.textMuted })
        end
        if forgeBtn_ then
            forgeBtn_:SetText("🔨 洗练")
            forgeBtn_:SetDisabled(true)
        end
        if resultLabel_ then resultLabel_:SetText("") end
        return
    end

    local item = selectedItem_
    local qCfg = GameConfig.QUALITY[item.quality]
    local qColor = qCfg and qCfg.color or T.color.textPrimary

    -- 装备名
    if infoNameLabel_ then
        infoNameLabel_:SetText((item.name or "未知装备"))
        infoNameLabel_:SetStyle({ fontColor = qColor })
    end

    -- 洗练属性
    if item.forgeStat then
        local rangeText = GetForgeRangeText(item.forgeStat.stat, item.tier)
        if forgeStatLabel_ then
            forgeStatLabel_:SetText("洗练: " .. item.forgeStat.name .. " +" .. ForgeUI.FormatStatValue(item.forgeStat) .. " " .. rangeText)
            forgeStatLabel_:SetStyle({ fontColor = T.color.success })
        end
    else
        if forgeStatLabel_ then
            forgeStatLabel_:SetText("尚未洗练")
            forgeStatLabel_:SetStyle({ fontColor = T.color.textMuted })
        end
    end

    -- 按钮（S10: 花金币→btnSpend，不足→btnDisabled；S8: 超万缩写）
    local cost = GetForgeCost(item)
    local player = GameState.player
    local canAfford = player and player.gold >= cost
    local costText = cost >= 10000 and string.format("%.1fw", cost / 10000) or tostring(cost)
    if forgeBtn_ then
        forgeBtn_:SetText("🔨 洗练  💰" .. costText)
        forgeBtn_:SetDisabled(not canAfford)
        forgeBtn_:SetBackgroundColor(canAfford and T.color.btnSpend or T.color.btnDisabled)
    end
end

-- ============================================================================
-- 格子选中处理
-- ============================================================================

--- 选中装备（从身上）
local function SelectEquipSlot(slotId)
    local manager = InventorySystem.GetManager()
    if not manager then return end
    local item = manager:GetEquipmentItem(slotId)
    if not item or not item.quality then return end
    -- 已选同一个则取消
    if selectedItem_ == item then
        selectedItem_ = nil
        selectedSource_ = nil
        selectedSlot_ = nil
    else
        selectedItem_ = item
        selectedSource_ = "equipment"
        selectedSlot_ = slotId
    end
    if resultLabel_ then resultLabel_:SetText("") end
    RefreshInfoPanel()
end

--- 选中装备（从背包）
local function SelectInvSlot(index)
    local manager = InventorySystem.GetManager()
    if not manager then return end
    local item = manager:GetInventoryItem(index)
    if not item or not item.quality or item.category == "consumable" then return end
    if selectedItem_ == item then
        selectedItem_ = nil
        selectedSource_ = nil
        selectedSlot_ = nil
    else
        selectedItem_ = item
        selectedSource_ = "inventory"
        selectedSlot_ = index
    end
    if resultLabel_ then resultLabel_:SetText("") end
    RefreshInfoPanel()
end

-- ============================================================================
-- UI 构建
-- ============================================================================

local FORGE_SLOT_SIZE = 56

--- 创建顶部洗练操作板（左：装备格 | 右：属性+按钮）
local function CreateInfoPanel()
    -- 左侧：选中装备展示格
    local selectedSlotWidget_ = ImageItemSlot {
        slotId = "__forge_preview__",
        slotCategory = "forge_preview",
        size = FORGE_SLOT_SIZE,
        showTypeIcon = false,
    }

    infoNameLabel_ = UI.Label {
        text = "选择装备",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = T.color.textSecondary,
    }

    forgeStatLabel_ = UI.Label {
        text = "点击下方格子选择",
        fontSize = T.fontSize.xs,
        fontColor = T.color.textMuted,
    }

    resultLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = T.color.success,
    }

    forgeBtn_ = UI.Button {
        text = "🔨 洗练",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        paddingLeft = T.spacing.lg,
        paddingRight = T.spacing.lg,
        height = 32,
        borderRadius = T.radius.sm,
        backgroundColor = T.color.btnDisabled,
        fontColor = T.color.btnDisabledFg,
        disabled = true,
        onClick = function(self)
            local now = time and time.elapsedTime or 0
            if now - lastForgeTime_ < FORGE_THROTTLE then
                if resultLabel_ then resultLabel_:SetText("操作过快") end
                return
            end
            lastForgeTime_ = now
            local ok, msg = DoForge()
            if resultLabel_ then
                resultLabel_:SetText(msg)
                resultLabel_:SetStyle({ fontColor = ok and T.color.success or T.color.error })
            end
            RefreshInfoPanel()
            ForgeUI.RefreshSlots()
        end,
    }

    -- 保存 slotWidget 引用供刷新用
    ForgeUI._previewSlot = selectedSlotWidget_

    infoPanel_ = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.md,
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.border,
        padding = T.spacing.sm,
        children = {
            -- 左：装备格
            UI.Panel {
                width = FORGE_SLOT_SIZE + T.spacing.xs * 2,
                height = FORGE_SLOT_SIZE + T.spacing.xs * 2,
                backgroundColor = T.color.surface,
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = T.color.borderLight,
                justifyContent = "center",
                alignItems = "center",
                children = { selectedSlotWidget_ },
            },
            -- 右：信息区
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                gap = T.spacing.xs,
                children = {
                    infoNameLabel_,
                    forgeStatLabel_,
                    forgeBtn_,
                    resultLabel_,
                },
            },
        },
    }

    return infoPanel_
end

--- 创建身上装备格子区
local function CreateEquipGrid()
    local gridPanel = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
    }

    -- 分区标签
    gridPanel:AddChild(UI.Label {
        text = "── 身上装备 ──",
        fontSize = T.fontSize.xs,
        fontColor = T.color.textMuted,
        textAlign = "center",
        width = "100%",
    })

    -- 7列格子（左对齐自然排列）
    local row = UI.Panel { width = "100%", flexDirection = "row", flexWrap = "wrap", gap = SLOT_GAP }
    for _, slotId in ipairs(EQUIP_SLOT_ORDER) do
        local capturedSlotId = slotId
        local slot = ImageItemSlot {
            slotId = slotId,
            slotCategory = "forge_equip",
            inventoryManager = InventorySystem.GetManager(),
            size = SLOT_SIZE,
            onSlotClick = function(slotWidget, clickedItem)
                SelectEquipSlot(capturedSlotId)
            end,
        }
        equipSlots_[slotId] = slot
        row:AddChild(slot)
    end
    gridPanel:AddChild(row)

    return gridPanel
end

--- 创建背包装备格子区（仅显示装备类物品）
local function CreateInvGrid()
    local gridPanel = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
    }

    -- 分区标签
    gridPanel:AddChild(UI.Label {
        text = "── 背包装备 ──",
        fontSize = T.fontSize.xs,
        fontColor = T.color.textMuted,
        textAlign = "center",
        width = "100%",
    })

    -- 7列格子（左对齐自然排列）
    local row = UI.Panel { width = "100%", flexDirection = "row", flexWrap = "wrap", gap = SLOT_GAP }
    local manager = InventorySystem.GetManager()
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager and manager:GetInventoryItem(i) or nil
        -- 只为装备类物品创建格子（跳过空位和消耗品）
        if item and item.quality and item.category ~= "consumable" then
            local capturedIdx = i
            local slot = ImageItemSlot {
                slotId = i,
                slotCategory = "forge_inv",
                size = SLOT_SIZE,
                showTypeIcon = false,
                onSlotClick = function(slotWidget, clickedItem)
                    SelectInvSlot(capturedIdx)
                end,
            }
            slot:SetItem(item)
            invSlots_[i] = slot
            row:AddChild(slot)
        end
    end
    gridPanel:AddChild(row)

    return gridPanel
end

--- 创建面板
---@param parentOverlay table
function ForgeUI.Create(parentOverlay)
    if panel_ then return end

    -- NPC 头像（锻造师，S2.5 规范：64px + headerBg + backgroundImage）
    local PORTRAIT_SIZE = 64
    local portraitPanel = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        overflow = "hidden",
        backgroundImage = "Textures/npc_blacksmith.png",
        backgroundFit = "contain",
    }

    shell_ = PanelShell.Create({
        title = "洗练",
        subtitle = "选择装备后点击洗练",
        portrait = portraitPanel,
        onClose = function() ForgeUI.Hide() end,
        parent = parentOverlay,
        zIndex = 100,
        footerHint = "每件装备可洗练1条额外属性，再次洗练会替换",
    })
    panel_ = shell_.panel

    -- 组装内容（居中对齐）
    local contentWrapper = UI.Panel {
        width = "100%",
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            CreateInfoPanel(),
            CreateEquipGrid(),
            CreateInvGrid(),
        },
    }
    shell_:AddContent(contentWrapper)

    -- 初始刷新格子
    ForgeUI.RefreshSlots()
end

-- ============================================================================
-- 刷新
-- ============================================================================

--- 刷新所有格子显示
function ForgeUI.RefreshSlots()
    local manager = InventorySystem.GetManager()
    if not manager then return end

    -- 身上装备
    for slotId, slotWidget in pairs(equipSlots_) do
        local item = manager:GetEquipmentItem(slotId)
        slotWidget:SetItem(item)
    end

    -- 背包格子（已创建的）
    for idx, slotWidget in pairs(invSlots_) do
        local item = manager:GetInventoryItem(idx)
        if item and item.quality and item.category ~= "consumable" then
            slotWidget:SetItem(item)
        else
            slotWidget:SetItem(nil)
        end
    end
end

--- 统一刷新
function ForgeUI.Refresh()
    ForgeUI.RefreshSlots()
    RefreshInfoPanel()
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function ForgeUI.Show()
    if panel_ and not visible_ then
        visible_ = true
        panel_:Show()
        GameState.uiOpen = "forge"
        selectedItem_ = nil
        selectedSource_ = nil
        selectedSlot_ = nil
        if resultLabel_ then resultLabel_:SetText("") end
        ForgeUI.Refresh()
    end
end

function ForgeUI.Hide()
    if panel_ and visible_ then
        SaveSession.Flush()
        visible_ = false
        panel_:Hide()
        if GameState.uiOpen == "forge" then
            GameState.uiOpen = nil
        end
    end
end

function ForgeUI.Toggle()
    if visible_ then ForgeUI.Hide() else ForgeUI.Show() end
end

function ForgeUI.IsVisible()
    return visible_
end

--- 销毁面板
function ForgeUI.Destroy()
    if panel_ then
        panel_:Remove()
    end
    panel_ = nil
    shell_ = nil
    visible_ = false
    selectedItem_ = nil
    selectedSource_ = nil
    selectedSlot_ = nil
    resultLabel_ = nil
    infoPanel_ = nil
    infoNameLabel_ = nil
    forgeStatLabel_ = nil
    forgeBtn_ = nil
    ForgeUI._previewSlot = nil
    equipSlots_ = {}
    invSlots_ = {}
end

return ForgeUI
