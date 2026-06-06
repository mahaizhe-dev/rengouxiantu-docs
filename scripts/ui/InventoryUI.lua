-- ============================================================================
-- InventoryUI.lua - 背包与装备 UI 面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")
local EquipTooltip = require("ui.EquipTooltip")
local ImageItemSlot = require("ui.ImageItemSlot")
local MinggePage = require("ui.MinggePage")
local T = require("config.UITheme")

local InventoryUI = {}

-- UI 组件引用
local panel_ = nil
local visible_ = false
local equipSlots_ = {}
local invSlots_ = {}
local infoLabel_ = nil
local sellMenu_ = nil
local sellToggleBtn_ = nil
local sellQualities_ = { white = true, green = true, blue = true, purple = false, orange = false }

-- 批量出售品质勾选本地持久化
local SELL_SETTINGS_FILE = "sell_equip_settings.json"
local cjson = require("cjson")

local function LoadSellSettings()
    pcall(function()
        if not fileSystem or not fileSystem:FileExists(SELL_SETTINGS_FILE) then return end
        local file = File(SELL_SETTINGS_FILE, FILE_READ)
        if not file or not file:IsOpen() then return end
        local raw = file:ReadString()
        file:Close()
        local ok, data = pcall(cjson.decode, raw)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if sellQualities_[k] ~= nil then
                    sellQualities_[k] = (v == true)
                end
            end
        end
    end)
end

local function SaveSellSettings()
    pcall(function()
        local file = File(SELL_SETTINGS_FILE, FILE_WRITE)
        if not file or not file:IsOpen() then return end
        file:WriteString(cjson.encode(sellQualities_))
        file:Close()
    end)
end

LoadSellSettings()

-- Tab 切页状态
local currentTab_ = "equip"  -- "equip" | "mingge"
local tabBtnEquip_ = nil
local tabBtnMingge_ = nil
local equipContent_ = nil     -- 装备页内容容器
local minggeContent_ = nil    -- 命格页内容容器

-- 配置
local INV_COLS = 6    -- 横屏最大列数（用于计算 maxWidth）
local SLOT_SIZE = T.size.slotSize
local SLOT_GAP = T.spacing.xs

-- 装备槽布局位置（左侧角色面板，4行x3列）
-- 布局：
--   项链(暴击)    头盔(生命)    肩膀(防御)
--   武器(攻击)    衣服(防御)    披风(减伤)*稀有
--   戒指(攻击)    腰带(生命)    戒指(防御)
--   专属(技能伤)* 鞋子(移速)    法宝(生命恢复)*稀有
local EQUIP_LAYOUT = {
    { id = "necklace",  icon = "icon_necklace.png",  row = 1, col = 1 },
    { id = "helmet",    icon = "icon_helmet.png",    row = 1, col = 2 },
    { id = "shoulder",  icon = "icon_shoulder.png",  row = 1, col = 3 },
    { id = "weapon",    icon = "icon_weapon.png",    row = 2, col = 1 },
    { id = "armor",     icon = "icon_armor.png",     row = 2, col = 2 },
    { id = "cape",      icon = "icon_cape.png",      row = 2, col = 3 },
    { id = "ring1",     icon = "icon_ring.png",      row = 3, col = 1 },
    { id = "belt",      icon = "icon_belt.png",      row = 3, col = 2 },
    { id = "ring2",     icon = "icon_ring.png",      row = 3, col = 3 },
    { id = "exclusive", icon = "icon_exclusive.png", row = 4, col = 1 },
    { id = "boots",     icon = "icon_boots.png",     row = 4, col = 2 },
    { id = "treasure",  icon = "image/gourd_green.png",  row = 4, col = 3 },
}

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 创建装备面板（左侧）
local function CreateEquipPanel()
    local eqPanel = UI.Panel {
        width = 3 * (SLOT_SIZE + SLOT_GAP) + T.spacing.lg * 2,
        backgroundColor = {30, 35, 45, 240},
        borderRadius = T.radius.md,
        padding = T.spacing.sm,
        gap = T.spacing.sm,
        children = {
            UI.Label {
                text = "装备",
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                fontColor = T.color.titleText,
                textAlign = "center",
            },
        },
    }

    -- 构建装备格子（4行x3列 网格布局）
    local maxRow = 4
    for r = 1, maxRow do
        local row = UI.Panel {
            flexDirection = "row",
            gap = SLOT_GAP,
            justifyContent = "center",
        }
        for c = 1, 3 do
            local slotDef = nil
            for _, def in ipairs(EQUIP_LAYOUT) do
                if def.row == r and def.col == c then
                    slotDef = def
                    break
                end
            end

            if slotDef then
                local manager = InventorySystem.GetManager()
                local capturedId = slotDef.id
                local slot = ImageItemSlot {
                    slotId = slotDef.id,
                    slotCategory = "equipment",
                    inventoryManager = manager,
                    slotTypeIcon = slotDef.icon,
                    size = SLOT_SIZE,
                    onSlotClick = function(slotWidget, clickedItem)
                        if clickedItem then
                            EquipTooltip.Show(clickedItem, "equipment", capturedId, function()
                                UpdateAllSlots()
                                InventoryUI.UpdateStats()
                                InventoryUI.UpdateFreeSlots()
                            end)
                        end
                    end,
                }
                equipSlots_[slotDef.id] = slot
                row:AddChild(slot)
            else
                -- 空位占位
                row:AddChild(UI.Panel {
                    width = SLOT_SIZE,
                    height = SLOT_SIZE,
                })
            end
        end
        eqPanel:AddChild(row)
    end

    -- 属性统计
    local statsPanel = UI.Panel {
        marginTop = T.spacing.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        backgroundColor = {20, 25, 35, 200},
        borderRadius = T.radius.sm,
    }

    local statDefs = {
        { key = "atk", label = "攻击", color = {255, 150, 100, 255} },
        { key = "def", label = "防御", color = {100, 200, 255, 255} },
        { key = "maxHp", label = "生命", color = {100, 255, 100, 255} },
        { key = "hpRegen", label = "回复", color = {150, 255, 200, 255} },
        { key = "critRate", label = "暴击率", color = {255, 220, 100, 255} },
        { key = "critDmg", label = "暴击伤害", color = {255, 200, 80, 255} },
        { key = "heavyHit", label = "重击", color = {255, 140, 60, 255} },
        { key = "skillDmg", label = "技能伤害", color = {200, 150, 255, 255} },
        { key = "killHeal", label = "击杀回血", color = {100, 255, 180, 255} },
        { key = "dmgReduce", label = "减伤", color = {180, 140, 255, 255} },
        { key = "speed", label = "移速", color = {100, 220, 255, 255} },
        { key = "fortune", label = "福缘", color = {255, 215, 0, 255} },
        { key = "wisdom", label = "悟性", color = {200, 150, 255, 255} },
        { key = "constitution", label = "根骨", color = {255, 180, 100, 255} },
        { key = "physique", label = "体魄", color = {220, 50, 50, 255} },
        { key = "tianzhuChance", label = "天诛概率", color = {0, 220, 220, 255} },
        { key = "tianzhuDamage", label = "天诛伤害", color = {0, 220, 220, 255} },
    }

    for _, sd in ipairs(statDefs) do
        local row = UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = sd.label,
                    fontSize = T.fontSize.xs,
                    fontColor = sd.color,
                },
                UI.Label {
                    id = "stat_" .. sd.key,
                    text = "+0",
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        }
        statsPanel:AddChild(row)
    end

    -- 套装效果
    statsPanel:AddChild(UI.Label {
        id = "set_bonus_label",
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = {255, 200, 100, 200},
        marginTop = T.spacing.xs,
    })

    eqPanel:AddChild(statsPanel)

    return eqPanel
end

--- 创建背包面板（右侧，宽度自适应）
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
                        text = "背包",
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
                                    InventorySystem.SortBackpack()
                                    UpdateAllSlots()
                                    InventoryUI.UpdateFreeSlots()
                                    if infoLabel_ then
                                        infoLabel_:SetText("背包已整理")
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
                                    -- 直接执行出售
                                    local hasAny = false
                                    for _, v in pairs(sellQualities_) do
                                        if v then hasAny = true; break end
                                    end
                                    if not hasAny then
                                        if infoLabel_ then infoLabel_:SetText("请先在▼中勾选要出售的品质") end
                                        return
                                    end
                                    local count, gold, lingYun = InventorySystem.SellByQuality(sellQualities_)
                                    if count > 0 then
                                        UpdateAllSlots()
                                        InventoryUI.UpdateFreeSlots()
                                        if infoLabel_ then
                                            local msg = "出售了 " .. count .. " 件，获得 " .. gold .. " 金币"
                                            if lingYun and lingYun > 0 then
                                                msg = msg .. " + " .. lingYun .. " 灵韵"
                                            end
                                            infoLabel_:SetText(msg)
                                        end
                                    else
                                        if infoLabel_ then
                                            infoLabel_:SetText("没有可出售的对应品质装备")
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
                                    sellToggleBtn_ = self
                                    if sellMenu_ then
                                        if sellMenu_:IsOpen() then
                                            sellMenu_:Close()
                                        else
                                            -- 用 absoluteLayout 直接定位，确保渲染和点击区域一致
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
                                id = "inv_free_slots",
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



    -- 背包1 格子（1 ~ BAG_SPLIT）
    local split = GameConfig.BAG_SPLIT

    local gridPanel1 = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }
    for i = 1, split do
        local capturedIdx = i
        local slot = ImageItemSlot {
            slotId = i,
            slotCategory = "inventory",
            size = SLOT_SIZE,
            showTypeIcon = false,
            onSlotClick = function(slotWidget, clickedItem)
                if clickedItem then
                    EquipTooltip.Show(clickedItem, "inventory", capturedIdx, function()
                        UpdateAllSlots()
                        InventoryUI.UpdateStats()
                        InventoryUI.UpdateFreeSlots()
                    end)
                end
            end,
        }
        invSlots_[i] = slot
        gridPanel1:AddChild(slot)
    end
    invPanel:AddChild(gridPanel1)

    -- 分隔 tips
    invPanel:AddChild(UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.xs,
        marginTop = T.spacing.xs,
        marginBottom = T.spacing.xs,
        children = {
            UI.Panel { height = 1, flexGrow = 1, backgroundColor = {80, 90, 110, 150} },
            UI.Label {
                text = "背包 2",
                fontSize = T.fontSize.xs,
                fontColor = {140, 150, 170, 200},
            },
            UI.Panel { height = 1, flexGrow = 1, backgroundColor = {80, 90, 110, 150} },
        },
    })

    -- 背包2 格子（BAG_SPLIT+1 ~ BACKPACK_SIZE）
    local gridPanel2 = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }
    for i = split + 1, GameConfig.BACKPACK_SIZE do
        local capturedIdx = i
        local slot = ImageItemSlot {
            slotId = i,
            slotCategory = "inventory",
            size = SLOT_SIZE,
            showTypeIcon = false,
            onSlotClick = function(slotWidget, clickedItem)
                if clickedItem then
                    EquipTooltip.Show(clickedItem, "inventory", capturedIdx, function()
                        UpdateAllSlots()
                        InventoryUI.UpdateStats()
                        InventoryUI.UpdateFreeSlots()
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

--- Tab 切换函数
local function SwitchTab(tab)
    if currentTab_ == tab then return end
    currentTab_ = tab

    -- 更新按钮样式（醒目配色）
    local activeColor = {60, 140, 220, 255}
    local inactiveColor = {60, 60, 75, 200}
    if tabBtnEquip_ then
        tabBtnEquip_:SetBackgroundColor(tab == "equip" and activeColor or inactiveColor)
    end
    if tabBtnMingge_ then
        tabBtnMingge_:SetBackgroundColor(tab == "mingge" and activeColor or inactiveColor)
    end

    -- 切换内容可见性
    if equipContent_ then
        if tab == "equip" then equipContent_:Show() else equipContent_:Hide() end
    end
    if minggeContent_ then
        if tab == "mingge" then minggeContent_:Show() else minggeContent_:Hide() end
    end

    -- 切页时刷新对应页面数据 + 更新信息标签
    if tab == "equip" then
        if infoLabel_ then infoLabel_:SetText("点击装备查看详情") end
        UpdateAllSlots()
        InventoryUI.UpdateStats()
        InventoryUI.UpdateFreeSlots()
        -- 隐藏命格 tooltip
        MinggePage.OnHide()
    else
        if infoLabel_ then infoLabel_:SetText("点击命格查看详情") end
        MinggePage.OnShow()
        -- 隐藏装备 tooltip
        EquipTooltip.Hide()
        if sellMenu_ and sellMenu_:IsOpen() then sellMenu_:Close() end
    end
end

--- 创建整个背包 UI 面板
---@param parentOverlay table overlay Widget
function InventoryUI.Create(parentOverlay)
    -- 信息标签（操作反馈）
    infoLabel_ = UI.Label {
        id = "inv_info",
        text = "点击装备查看详情",
        fontSize = T.fontSize.sm,
        fontColor = {200, 200, 200, 200},
        textAlign = "center",
    }

    -- Tab 按钮（醒目大号）
    tabBtnEquip_ = UI.Button {
        text = "装备物品",
        fontSize = 16,
        fontColor = {255, 255, 255, 255},
        paddingLeft = 18,
        paddingRight = 18,
        height = 36,
        borderRadius = 18,
        backgroundColor = {60, 140, 220, 255},
        onClick = function(self) SwitchTab("equip") end,
    }
    tabBtnMingge_ = UI.Button {
        text = "五行命格",
        fontSize = 16,
        fontColor = {255, 255, 255, 255},
        paddingLeft = 18,
        paddingRight = 18,
        height = 36,
        borderRadius = 18,
        backgroundColor = {60, 60, 75, 200},
        onClick = function(self) SwitchTab("mingge") end,
    }

    -- 装备页内容容器
    equipContent_ = UI.Panel {
        gap = T.spacing.sm,
        children = {
            -- 装备 + 背包格子
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

    -- 命格页内容容器
    minggeContent_ = MinggePage.Create(parentOverlay)
    minggeContent_:Hide()  -- 默认隐藏

    -- 主面板（全屏半透明背景）
    panel_ = UI.Panel {
        id = "inventoryPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 120,
        children = {
            -- 可滚动内容区
            UI.ScrollView {
                maxHeight = "95%",
                width = "100%",
                flexGrow = 0,
                flexShrink = 1,
                contentProps = {
                    alignItems = "center",
                    gap = T.spacing.sm,
                    paddingTop = T.spacing.sm,
                    paddingBottom = T.spacing.lg,
                    paddingLeft = T.spacing.sm,
                    paddingRight = T.spacing.sm,
                },
                children = {
                    -- 统一卡片
                    UI.Panel {
                        maxWidth = 3 * (SLOT_SIZE + SLOT_GAP) + T.spacing.lg * 2
                              + T.spacing.md
                              + INV_COLS * (SLOT_SIZE + SLOT_GAP) + T.spacing.sm * 2
                              + T.spacing.md * 2,
                        alignSelf = "center",
                        backgroundColor = T.color.panelBg,
                        borderRadius = T.radius.lg,
                        padding = T.spacing.md,
                        gap = T.spacing.sm,
                        children = {
                            -- 标题栏（三列：左关闭、中tab居中、右信息）
                            UI.Panel {
                                flexDirection = "row",
                                justifyContent = "space-between",
                                alignItems = "center",
                                children = {
                                    -- 左：关闭按钮
                                    UI.Button {
                                        text = "✕",
                                        width = T.size.closeButton,
                                        height = T.size.closeButton,
                                        fontSize = T.fontSize.md,
                                        borderRadius = T.size.closeButton / 2,
                                        backgroundColor = {60, 60, 70, 200},
                                        onClick = function(self)
                                            InventoryUI.Hide()
                                        end,
                                    },
                                    -- 中：Tab 按钮居中
                                    UI.Panel {
                                        flexDirection = "row",
                                        gap = T.spacing.sm,
                                        children = {
                                            tabBtnEquip_,
                                            tabBtnMingge_,
                                        },
                                    },
                                    -- 右：信息标签（与左侧关闭按钮平衡宽度）
                                    infoLabel_,
                                },
                            },
                            -- 装备页内容
                            equipContent_,
                            -- 命格页内容
                            minggeContent_,
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)

    -- 批量出售品质选择菜单（挂载到 overlay 层，确保在背包面板之上）
    sellMenu_ = UI.Menu {
        size = "sm",
        position = "absolute",
        zIndex = 200,
        items = {
            { label = "⚪ 普通", checked = sellQualities_.white,  keepOpen = true },
            { label = "🟢 良品", checked = sellQualities_.green,  keepOpen = true },
            { label = "🔵 精品", checked = sellQualities_.blue,   keepOpen = true },
            { label = "🟣 极品", checked = sellQualities_.purple, keepOpen = true },
            { label = "🟠 稀世", checked = sellQualities_.orange, keepOpen = true },
        },
        onItemClick = function(self, item, index)
            -- 同步勾选状态到 sellQualities_
            local keys = { "white", "green", "blue", "purple", "orange" }
            if keys[index] then
                sellQualities_[keys[index]] = item.checked or false
                SaveSellSettings()
            end
        end,
    }
    sellMenu_:Close()  -- Menu:Init 中 `false or true` = true，手动关闭
    parentOverlay:AddChild(sellMenu_)

    -- 初始化装备详情浮层（挂载到 overlay 层，确保在背包面板之上）
    EquipTooltip.Init(parentOverlay)

    -- 监听装备变更
    EventBus.On("equip_stats_changed", function()
        InventoryUI.UpdateStats()
    end)

    -- 监听命格页信息（由 MinggePage 通过事件传递到共享 infoLabel）
    EventBus.On("mingge_info", function(msg)
        if infoLabel_ and currentTab_ == "mingge" then
            infoLabel_:SetText(msg or "")
        end
    end)
end

--- 显示背包面板
function InventoryUI.Show()
    if panel_ and not visible_ then
        visible_ = true
        panel_:Show()
        GameState.uiOpen = "inventory"

        -- 先拾取待领取物品
        InventorySystem.PickupPendingItems()

        -- 根据当前 tab 刷新对应页面
        if currentTab_ == "mingge" then
            MinggePage.OnShow()
        else
            UpdateAllSlots()
            InventoryUI.UpdateStats()
            InventoryUI.UpdateFreeSlots()
        end
    end
end

--- 隐藏背包面板
function InventoryUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        GameState.uiOpen = nil
        if infoLabel_ then infoLabel_:SetText("点击装备查看详情") end
        if sellMenu_ and sellMenu_:IsOpen() then sellMenu_:Close() end
        EquipTooltip.Hide()
        MinggePage.OnHide()
    end
end

--- 切换显示/隐藏
function InventoryUI.Toggle()
    if visible_ then
        InventoryUI.Hide()
    else
        InventoryUI.Show()
    end
end

--- 是否可见
---@return boolean
function InventoryUI.IsVisible()
    return visible_
end

--- 更新所有格子显示
function UpdateAllSlots()
    local manager = InventorySystem.GetManager()
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

--- 更新属性统计
function InventoryUI.UpdateStats()
    if not panel_ then return end

    local summary = InventorySystem.GetEquipStatSummary()

    local stats = {
        { key = "atk", value = summary.atk },
        { key = "def", value = summary.def },
        { key = "maxHp", value = summary.maxHp },
        { key = "hpRegen", value = summary.hpRegen },
        { key = "critRate", value = summary.critRate },
        { key = "critDmg", value = summary.critDmg },
        { key = "heavyHit", value = summary.heavyHit },
        { key = "skillDmg", value = summary.skillDmg },
        { key = "killHeal", value = summary.killHeal },
        { key = "dmgReduce", value = summary.dmgReduce },
        { key = "speed", value = summary.speed },
        { key = "fortune", value = summary.fortune },
        { key = "wisdom", value = summary.wisdom },
        { key = "constitution", value = summary.constitution },
        { key = "physique", value = summary.physique },
    }

    -- 天诛属性：仅显示装备提供的天诛值
    local player = GameState.player
    local tzChance = player and (player.equipTianzhuChance or 0) or 0
    local tzDmg = player and (player.equipTianzhuDamage or 0) or 0
    table.insert(stats, { key = "tianzhuChance", value = tzChance })
    table.insert(stats, { key = "tianzhuDamage", value = tzDmg })

    local pctKeys = { critRate = true, critDmg = true, dmgReduce = true, skillDmg = true, tianzhuChance = true, tianzhuDamage = true }

    for _, s in ipairs(stats) do
        local label = panel_:FindById("stat_" .. s.key)
        if label then
            local val = s.value or 0
            local txt
            if s.isTotal then
                -- 天诛显示总值百分比（不带+号）
                txt = string.format("%.1f%%", val * 100)
            elseif s.key == "hpRegen" then
                txt = "+" .. string.format("%.1f/s", val)
            elseif pctKeys[s.key] then
                txt = "+" .. string.format("%.1f%%", val * 100)
            elseif s.key == "speed" then
                txt = "+" .. string.format("%.1f", val)
            else
                txt = "+" .. tostring(math.floor(val))
            end
            label:SetText(txt)
        end
    end

    -- 套装效果
    local setLabel = panel_:FindById("set_bonus_label")
    if setLabel then
        local bonuses = InventorySystem.GetActiveSetBonuses()
        if #bonuses > 0 then
            local texts = {}
            for _, b in ipairs(bonuses) do
                table.insert(texts, b.name .. ": " .. b.description)
            end
            setLabel:SetText(table.concat(texts, "\n"))
        else
            setLabel:SetText("")
        end
    end
end

--- 更新背包空位显示
function InventoryUI.UpdateFreeSlots()
    if not panel_ then return end
    local label = panel_:FindById("inv_free_slots")
    if label then
        local manager = InventorySystem.GetManager()
        local split = GameConfig.BAG_SPLIT
        local free1, free2 = 0, 0
        if manager then
            for i = 1, split do
                if not manager:GetInventoryItem(i) then free1 = free1 + 1 end
            end
            for i = split + 1, GameConfig.BACKPACK_SIZE do
                if not manager:GetInventoryItem(i) then free2 = free2 + 1 end
            end
        end
        label:SetText(free1 .. "/" .. split .. " | " .. free2 .. "/" .. (GameConfig.BACKPACK_SIZE - split))
    end
end

return InventoryUI
