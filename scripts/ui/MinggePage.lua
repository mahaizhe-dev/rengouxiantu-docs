---@diagnostic disable
-- ============================================================================
-- MinggePage.lua - 五行命格页面（装备 + 背包 + 属性统计）
-- ============================================================================
-- 左侧：5行×3列 命格装备槽
-- 右侧：60格命格独立背包（30/30 分屏）
-- 底部属性汇总 + 套装激活

local UI = require("urhox-libs/UI")
local MinggeData = require("config.MinggeData")
local MinggeSystem = require("systems.MinggeSystem")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local ImageItemSlot = require("ui.ImageItemSlot")
local MinggeTooltip = require("ui.MinggeTooltip")
local T = require("config.UITheme")

local MinggePage = {}

-- UI 状态
local contentPanel_ = nil
local equipSlots_ = {}
local invSlots_ = {}
local infoLabel_ = nil
local sellMenu_ = nil
local sellQualities_ = { purple = true, orange = true, cyan = false }

-- 配置
local INV_COLS = 6
local SLOT_SIZE = T.size.slotSize
local SLOT_GAP = T.spacing.xs
local BAG_SPLIT = 30  -- 命格背包 30/30 分隔

-- 五行元素颜色
local ELEMENT_COLORS = {
    metal = {220, 200, 140, 255},
    wood  = {100, 200, 80, 255},
    water = {80, 160, 255, 255},
    fire  = {255, 100, 60, 255},
    earth = {200, 160, 80, 255},
}

-- ============================================================================
-- 刷新函数（前置声明）
-- ============================================================================

local function UpdateAllSlots() end
local function UpdateStats() end
local function UpdateFreeSlots() end

-- ============================================================================
-- 装备面板（左侧 5行×3列）
-- ============================================================================

local function CreateEquipPanel()
    local eqPanel = UI.Panel {
        width = 3 * (SLOT_SIZE + SLOT_GAP) + T.spacing.lg * 2,
        backgroundColor = {30, 35, 45, 240},
        borderRadius = T.radius.md,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "命格装备",
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                fontColor = T.color.titleText,
                textAlign = "center",
            },
        },
    }

    -- 5行：每行一个五行 + 3格
    for _, element in ipairs(MinggeData.ELEMENTS) do
        local elName = MinggeData.ELEMENT_NAMES[element]
        local elColor = ELEMENT_COLORS[element] or {180, 180, 180, 255}

        -- 行标签
        local row = UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = SLOT_GAP,
        }

        -- 五行标签
        row:AddChild(UI.Label {
            text = elName,
            fontSize = T.fontSize.xs,
            fontColor = elColor,
            width = 14,
            textAlign = "center",
        })

        -- 3 个装备格
        local slots = MinggeData.SLOTS[element]
        for _, slotId in ipairs(slots) do
            local capturedSlotId = slotId
            local slot = ImageItemSlot {
                slotId = slotId,
                slotCategory = "mingge_equip",
                inventoryManager = MinggeSystem.GetManager(),
                size = SLOT_SIZE,
                onSlotClick = function(slotWidget, clickedItem)
                    if clickedItem then
                        MinggeTooltip.Show(clickedItem, "equipment", capturedSlotId, function()
                            UpdateAllSlots()
                            UpdateStats()
                            UpdateFreeSlots()
                        end)
                    end
                end,
            }
            equipSlots_[slotId] = slot
            row:AddChild(slot)
        end

        eqPanel:AddChild(row)
    end

    -- ── 属性统计面板 ──
    local statsPanel = UI.Panel {
        marginTop = T.spacing.sm,
        padding = T.spacing.sm,
        gap = 2,
        backgroundColor = {20, 25, 35, 200},
        borderRadius = T.radius.sm,
    }

    -- 属性行
    local statDefs = {
        { key = "atk",          label = "攻击",     color = {255, 150, 100, 255} },
        { key = "def",          label = "防御",     color = {100, 200, 255, 255} },
        { key = "maxHp",        label = "生命",     color = {100, 255, 100, 255} },
        { key = "hpRegen",      label = "回复",     color = {150, 255, 200, 255} },
        { key = "critRate",     label = "暴击率",   color = {255, 220, 100, 255} },
        { key = "critDmg",      label = "暴击伤害", color = {255, 200, 80, 255} },
        { key = "heavyHit",     label = "重击",     color = {255, 140, 60, 255} },
        { key = "killHeal",     label = "击杀回血", color = {100, 255, 180, 255} },
        { key = "moveSpeed",    label = "移速",     color = {100, 220, 255, 255} },
        { key = "tianzhuChance",label = "天诛",     color = {0, 220, 220, 255} },
        { key = "tianzhuDamage",label = "天诛伤害", color = {0, 220, 220, 255} },
        { key = "fortune",      label = "福缘",     color = {255, 215, 0, 255} },
        { key = "wisdom",       label = "悟性",     color = {200, 150, 255, 255} },
        { key = "constitution", label = "根骨",     color = {255, 180, 100, 255} },
        { key = "physique",     label = "体魄",     color = {220, 50, 50, 255} },
    }

    for _, sd in ipairs(statDefs) do
        statsPanel:AddChild(UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = sd.label,
                    fontSize = T.fontSize.xs,
                    fontColor = sd.color,
                },
                UI.Label {
                    id = "mg_stat_" .. sd.key,
                    text = "+0",
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        })
    end

    -- 套装标签
    statsPanel:AddChild(UI.Label {
        id = "mg_set_bonus_label",
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = {100, 220, 255, 230},
        marginTop = T.spacing.xs,
    })

    eqPanel:AddChild(statsPanel)
    return eqPanel
end

-- ============================================================================
-- 背包面板（右侧 60 格，30/30 分隔）
-- ============================================================================

local function CreateInvPanel()
    local invPanel = UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        minWidth = 3 * (SLOT_SIZE + SLOT_GAP) + T.spacing.sm * 2,
        maxWidth = INV_COLS * (SLOT_SIZE + SLOT_GAP) + T.spacing.sm * 2,
        backgroundColor = {30, 35, 45, 240},
        borderRadius = T.radius.md,
        padding = T.spacing.sm,
        gap = T.spacing.sm,
        children = {
            UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "命格背包",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                    },
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.sm,
                        children = {
                            UI.Button {
                                text = "整理",
                                fontSize = T.fontSize.xs,
                                paddingLeft = T.spacing.sm,
                                paddingRight = T.spacing.sm,
                                height = 22,
                                borderRadius = T.radius.sm,
                                backgroundColor = {50, 90, 130, 220},
                                onClick = function(self)
                                    MinggeSystem.SortBackpack()
                                    UpdateAllSlots()
                                    UpdateFreeSlots()
                                    if infoLabel_ then
                                        infoLabel_:SetText("命格已整理")
                                    end
                                end,
                            },
                            UI.Button {
                                text = "批量出售",
                                fontSize = T.fontSize.xs,
                                paddingLeft = T.spacing.sm,
                                paddingRight = T.spacing.sm,
                                height = 22,
                                borderRadius = T.radius.sm,
                                borderTopRightRadius = 0,
                                borderBottomRightRadius = 0,
                                backgroundColor = {120, 80, 30, 220},
                                onClick = function(self)
                                    local hasAny = false
                                    for _, v in pairs(sellQualities_) do
                                        if v then hasAny = true; break end
                                    end
                                    if not hasAny then
                                        if infoLabel_ then infoLabel_:SetText("请先在▼中勾选要出售的品质") end
                                        return
                                    end
                                    local count, lingYun = MinggeSystem.SellByQuality(sellQualities_)
                                    if count > 0 then
                                        UpdateAllSlots()
                                        UpdateFreeSlots()
                                        if infoLabel_ then
                                            infoLabel_:SetText("出售了 " .. count .. " 件，获得 " .. lingYun .. " 灵韵")
                                        end
                                    else
                                        if infoLabel_ then
                                            infoLabel_:SetText("没有可出售的对应品质命格")
                                        end
                                    end
                                end,
                            },
                            UI.Button {
                                text = "▼",
                                fontSize = 9,
                                width = 18,
                                height = 22,
                                paddingLeft = 0,
                                paddingRight = 0,
                                borderRadius = T.radius.sm,
                                borderTopLeftRadius = 0,
                                borderBottomLeftRadius = 0,
                                backgroundColor = {100, 65, 20, 220},
                                onClick = function(self)
                                    if sellMenu_ then
                                        if sellMenu_:IsOpen() then
                                            sellMenu_:Close()
                                        else
                                            local bl = self:GetAbsoluteLayout()
                                            local ml = sellMenu_:GetLayout()
                                            sellMenu_.absoluteLayout = {
                                                x = bl.x,
                                                y = bl.y + bl.h + 2,
                                                w = ml.w,
                                                h = ml.h,
                                            }
                                            sellMenu_:Open()
                                        end
                                    end
                                end,
                            },
                            UI.Label {
                                id = "mg_free_slots",
                                text = "60/60",
                                fontSize = T.fontSize.xs,
                                fontColor = {180, 180, 180, 200},
                            },
                        },
                    },
                },
            },
        },
    }

    -- 背包上半区（1~30）
    local gridPanel1 = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }
    for i = 1, BAG_SPLIT do
        local capturedIdx = i
        local slot = ImageItemSlot {
            slotId = i,
            slotCategory = "mingge_inv",
            size = SLOT_SIZE,
            showTypeIcon = false,
            onSlotClick = function(slotWidget, clickedItem)
                if clickedItem then
                    MinggeTooltip.Show(clickedItem, "backpack", capturedIdx, function()
                        UpdateAllSlots()
                        UpdateStats()
                        UpdateFreeSlots()
                    end)
                end
            end,
        }
        invSlots_[i] = slot
        gridPanel1:AddChild(slot)
    end
    invPanel:AddChild(gridPanel1)

    -- 分隔线
    invPanel:AddChild(UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.xs,
        marginTop = T.spacing.xs,
        marginBottom = T.spacing.xs,
        children = {
            UI.Panel { height = 1, flexGrow = 1, backgroundColor = {80, 90, 110, 150} },
            UI.Label {
                text = "命格背包 2",
                fontSize = T.fontSize.xs,
                fontColor = {140, 150, 170, 200},
            },
            UI.Panel { height = 1, flexGrow = 1, backgroundColor = {80, 90, 110, 150} },
        },
    })

    -- 背包下半区（31~60）
    local gridPanel2 = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }
    for i = BAG_SPLIT + 1, MinggeData.BACKPACK_SIZE do
        local capturedIdx = i
        local slot = ImageItemSlot {
            slotId = i,
            slotCategory = "mingge_inv",
            size = SLOT_SIZE,
            showTypeIcon = false,
            onSlotClick = function(slotWidget, clickedItem)
                if clickedItem then
                    MinggeTooltip.Show(clickedItem, "backpack", capturedIdx, function()
                        UpdateAllSlots()
                        UpdateStats()
                        UpdateFreeSlots()
                    end)
                end
            end,
        }
        invSlots_[i] = slot
        gridPanel2:AddChild(slot)
    end
    invPanel:AddChild(gridPanel2)

    return invPanel
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 构建命格页面内容（返回 panel，由 InventoryUI 挂载）
---@param parentOverlay Panel 遮罩层（用于挂载 tooltip 和 menu）
---@return Panel
function MinggePage.Create(parentOverlay)
    -- 信息标签
    infoLabel_ = UI.Label {
        id = "mg_info",
        text = "点击命格查看详情",
        fontSize = T.fontSize.sm,
        fontColor = {200, 200, 200, 200},
        textAlign = "center",
    }

    contentPanel_ = UI.Panel {
        gap = T.spacing.sm,
        children = {
            -- 标题 + 信息
            UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "五行命格",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                    },
                    infoLabel_,
                },
            },
            -- 装备 + 背包
            UI.Panel {
                flexDirection = "row",
                gap = T.spacing.md,
                flexWrap = "wrap",
                justifyContent = "center",
                alignItems = "flex-start",
                children = {
                    CreateEquipPanel(),
                    CreateInvPanel(),
                },
            },
        },
    }

    -- 初始化 MinggeTooltip
    MinggeTooltip.Init(parentOverlay)

    -- 批量出售品质选择菜单
    sellMenu_ = UI.Menu {
        size = "sm",
        position = "absolute",
        zIndex = 200,
        items = {
            { label = "🟣 紫品", checked = sellQualities_.purple, keepOpen = true },
            { label = "🟠 橙品", checked = sellQualities_.orange, keepOpen = true },
            { label = "🔵 青品", checked = sellQualities_.cyan,   keepOpen = true },
        },
        onItemClick = function(self, item, index)
            local keys = { "purple", "orange", "cyan" }
            if keys[index] then
                sellQualities_[keys[index]] = item.checked or false
            end
        end,
    }
    sellMenu_:Close()
    parentOverlay:AddChild(sellMenu_)

    -- 监听命格变更
    EventBus.On("mingge_stats_changed", function()
        UpdateStats()
    end)

    return contentPanel_
end

--- 刷新所有格子显示
function UpdateAllSlots()
    local manager = MinggeSystem.GetManager()
    if not manager then return end

    -- 装备格
    for slotId, slotWidget in pairs(equipSlots_) do
        local item = manager:GetEquipmentItem(slotId)
        slotWidget:SetItem(item)
    end

    -- 背包格
    for i, slotWidget in ipairs(invSlots_) do
        local item = manager:GetInventoryItem(i)
        slotWidget:SetItem(item)
    end
end

--- 刷新属性统计
function UpdateStats()
    if not contentPanel_ then return end

    local summary = MinggeSystem.GetStatSummary()

    local statKeys = {
        "atk", "def", "maxHp", "hpRegen",
        "critRate", "critDmg", "heavyHit", "killHeal",
        "moveSpeed", "tianzhuChance", "tianzhuDamage",
        "fortune", "wisdom", "constitution", "physique",
    }

    for _, key in ipairs(statKeys) do
        local label = contentPanel_:FindById("mg_stat_" .. key)
        if label then
            local val = summary[key] or 0
            local txt
            if MinggeData.PERCENT_STATS[key] then
                txt = "+" .. string.format("%.1f%%", val * 100)
            elseif MinggeData.DECIMAL_STATS[key] then
                txt = "+" .. string.format("%.1f", val)
            else
                txt = "+" .. tostring(math.floor(val))
            end
            label:SetText(txt)
        end
    end

    -- 套装加成
    local setLabel = contentPanel_:FindById("mg_set_bonus_label")
    if setLabel then
        local bonuses = MinggeSystem.GetActiveSetBonuses()
        if #bonuses > 0 then
            local texts = {}
            for _, b in ipairs(bonuses) do
                local setDef = MinggeData.SETS[b.setId]
                if setDef then
                    local elName = MinggeData.ELEMENT_NAMES[b.element] or "?"
                    table.insert(texts, elName .. "行·" .. setDef.name .. ": " .. setDef.desc)
                end
            end
            setLabel:SetText(table.concat(texts, "\n"))
        else
            setLabel:SetText("")
        end
    end
end

--- 刷新背包空位显示
function UpdateFreeSlots()
    if not contentPanel_ then return end
    local label = contentPanel_:FindById("mg_free_slots")
    if label then
        local manager = MinggeSystem.GetManager()
        local free1, free2 = 0, 0
        if manager then
            for i = 1, BAG_SPLIT do
                if not manager:GetInventoryItem(i) then free1 = free1 + 1 end
            end
            for i = BAG_SPLIT + 1, MinggeData.BACKPACK_SIZE do
                if not manager:GetInventoryItem(i) then free2 = free2 + 1 end
            end
        end
        label:SetText(free1 .. "/" .. BAG_SPLIT .. " | " .. free2 .. "/" .. (MinggeData.BACKPACK_SIZE - BAG_SPLIT))
    end
end

--- 页面被显示时调用（刷新数据）
function MinggePage.OnShow()
    UpdateAllSlots()
    UpdateStats()
    UpdateFreeSlots()
end

--- 页面被隐藏时调用
function MinggePage.OnHide()
    MinggeTooltip.Hide()
    if sellMenu_ and sellMenu_:IsOpen() then sellMenu_:Close() end
end

return MinggePage
