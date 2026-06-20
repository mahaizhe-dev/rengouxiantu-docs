---@diagnostic disable
-- ============================================================================
-- InventoryUI.lua - 背包与装备 UI 面板
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: PanelShell骨架 | 双Tab切页 | 动态职业精灵 | 内联品质选择 | 事件驱动刷新
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
local PanelShell = require("ui.components.PanelShell")
local InventoryOps = require("ui.InventoryOps")
local T = require("config.UITheme")

local InventoryUI = {}

-- UI 组件引用
local shell_ = nil
local panel_ = nil
local visible_ = false
local equipSlots_ = {}
local invSlots_ = {}
-- infoLabel_ 已移除，操作反馈使用 shell_.resultLabel
local sellMenu_ = nil
local sellQualities_ = { white = true, green = true, blue = true, purple = false, orange = false }

-- 批量出售品质勾选持久化（委托 InventoryOps）
local SELL_SETTINGS_FILE = "sell_equip_settings.json"
InventoryOps.LoadSellSettings(SELL_SETTINGS_FILE, sellQualities_)

-- Tab 切页状态
local currentTab_ = "equip"  -- "equip" | "mingge"
local tabBtnEquip_ = nil
local tabBtnMingge_ = nil
local equipContent_ = nil     -- 装备页内容容器
local minggeContent_ = nil    -- 命格页内容容器

-- 属性折叠状态
local statsExpanded_ = false
local statsDetail_ = nil

-- 配置
local INV_COLS = 7    -- 横屏列数（7列 × 60格 = 9行，首屏更紧凑）
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

-- 职业→精灵映射（与 CharacterUI/RealmPanel 一致）
local CLASS_PORTRAITS = {
    monk    = "Textures/player_right.png",
    taixu   = "Textures/class_swordsman_right.png",
    zhenyue = "image/zhenyue_sprite_v3_20260426072019.png",
}

local function GetClassSprite()
    local classId = (GameState.player and GameState.player.classId) or GameConfig.PLAYER_CLASS or "monk"
    return CLASS_PORTRAITS[classId] or CLASS_PORTRAITS.monk
end

--- 创建装备区（竖屏：精灵 + 格子 row + 属性摘要）
local spritePanel_ = nil  -- 保留引用以便刷新

local function CreateEquipPanel()
    local eqPanel = UI.Panel {
        width = "100%",
        alignItems = "center",
        gap = T.spacing.xs,
    }

    -- 装备区核心：角色精灵 + 4×3 格子 并排
    local equipGrid = UI.Panel { gap = SLOT_GAP }

    -- 构建装备格子（4行x3列 网格布局）
    for r = 1, 4 do
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
                row:AddChild(UI.Panel { width = SLOT_SIZE, height = SLOT_SIZE })
            end
        end
        equipGrid:AddChild(row)
    end

    -- 角色精灵（根据职业动态显示，非标准 slot 尺寸）
    spritePanel_ = UI.Panel {
        width = 140,  -- 角色精灵展示宽度（无对应令牌，与 4×3 装备格视觉平衡）
        height = 4 * (SLOT_SIZE + SLOT_GAP),
        backgroundImage = GetClassSprite(),
        backgroundFit = "contain",
        borderRadius = T.radius.sm,
    }

    -- 精灵 + 格子 并排（暗底容器包裹，增强结构感）
    eqPanel:AddChild(UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = T.spacing.md,
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.borderLight,
        padding = T.spacing.sm,
        children = {
            spritePanel_,
            equipGrid,
        },
    })

    -- ── 属性摘要行（始终可见：攻/防/血 + 展开按钮） ──
    local expandBtn = UI.Button {
        id = "stat_expand_btn",
        text = "🔻 详情",
        fontSize = T.fontSize.xs,
        paddingLeft = T.spacing.xs,
        paddingRight = T.spacing.xs,
        height = 20,
        borderRadius = T.radius.sm,
        backgroundColor = T.color.invStatPanelBg,
        fontColor = T.color.textSecondary,
        onClick = function(self)
            statsExpanded_ = not statsExpanded_
            if statsDetail_ then
                if statsExpanded_ then statsDetail_:Show() else statsDetail_:Hide() end
            end
            self:SetText(statsExpanded_ and "🔺 收起" or "🔻 详情")
        end,
    }

    local statsSummary = UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = T.spacing.xs,
        marginTop = T.spacing.xs,
        children = {
            UI.Label { id = "stat_summary_atk", text = "攻+0", fontSize = T.fontSize.xs, fontColor = T.statColor.atk },
            UI.Label { id = "stat_summary_def", text = "防+0", fontSize = T.fontSize.xs, fontColor = T.statColor.def },
            UI.Label { id = "stat_summary_maxHp", text = "血+0", fontSize = T.fontSize.xs, fontColor = T.statColor.maxHp },
            expandBtn,
        },
    }
    eqPanel:AddChild(statsSummary)

    -- ── 属性详情（默认隐藏，展开后随面板整体滚动，无独立滚动条） ──
    local STAT_ROW_H = 16

    -- 左列属性
    local leftDefs = {
        { key = "atk",          label = "攻击" },
        { key = "maxHp",        label = "生命" },
        { key = "critRate",     label = "暴击率" },
        { key = "heavyHit",     label = "重击" },
        { key = "killHeal",     label = "击杀回血" },
        { key = "speed",        label = "移速" },
        { key = "wisdom",       label = "悟性" },
        { key = "physique",     label = "体魄" },
        { key = "tianzhuChance",label = "天诛概率" },
    }
    -- 右列属性
    local rightDefs = {
        { key = "def",          label = "防御" },
        { key = "hpRegen",      label = "回复" },
        { key = "critDmg",      label = "暴击伤害" },
        { key = "skillDmg",     label = "技能伤害" },
        { key = "dmgReduce",    label = "减伤" },
        { key = "fortune",      label = "福缘" },
        { key = "constitution", label = "根骨" },
        { key = "tianzhuDamage",label = "天诛伤害" },
    }

    local function buildStatColumn(defs)
        local col = UI.Panel { flexGrow = 1, flexShrink = 1, gap = T.spacing.xxs }
        for _, sd in ipairs(defs) do
            col:AddChild(UI.Panel {
                height = STAT_ROW_H,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingRight = T.spacing.xs,
                children = {
                    UI.Label { text = sd.label, fontSize = T.fontSize.xs, fontColor = T.statColor[sd.key] or T.color.textSecondary },
                    UI.Label { id = "stat_" .. sd.key, text = "+0", fontSize = T.fontSize.xs, fontColor = T.color.invStatValue },
                },
            })
        end
        return col
    end

    -- 属性双列面板（无独立滚动，随面板整体滚动）
    statsDetail_ = UI.Panel {
        width = "100%",
        visible = false,
        marginTop = T.spacing.xs,
        backgroundColor = T.color.invStatPanelBg,
        borderRadius = T.radius.sm,
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        paddingTop = T.spacing.xs,
        paddingBottom = T.spacing.xs,
        gap = T.spacing.xs,
        children = {
            -- 双列属性
            UI.Panel {
                flexDirection = "row",
                gap = T.spacing.sm,
                children = {
                    buildStatColumn(leftDefs),
                    -- 中间竖分隔线
                    UI.Panel { width = 1, backgroundColor = T.color.borderLight },
                    buildStatColumn(rightDefs),
                },
            },
            -- 分隔线
            UI.Panel { width = "100%", height = 1, backgroundColor = T.color.borderLight, marginTop = T.spacing.xxs },
            -- 套装效果区
            UI.Panel {
                id = "set_bonus_panel",
                width = "100%",
                gap = T.spacing.xxs,
            },
        },
    }
    eqPanel:AddChild(statsDetail_)

    return eqPanel
end

--- 创建背包区（竖屏：操作栏 + 品质选择 + 7 列连续格子）
local function CreateInvPanel()
    local invPanel = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
    }

    -- 品质选择内联面板（默认隐藏，点击▼展开）
    local QUALITY_KEYS = { "white", "green", "blue", "purple", "orange" }
    local QUALITY_LABELS = { "⚪普通", "🟢良品", "🔵精品", "🟣极品", "🟠稀世" }
    local qualityPanel = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = T.spacing.xs,
        paddingLeft = T.spacing.xs,
        paddingRight = T.spacing.xs,
        paddingTop = T.spacing.xs,
        paddingBottom = T.spacing.xs,
        backgroundColor = T.color.invStatPanelBg,
        borderRadius = T.radius.sm,
        visible = false,
    }
    -- 创建品质勾选按钮
    local qualityBtns = {}
    for idx, key in ipairs(QUALITY_KEYS) do
        local isChecked = sellQualities_[key]
        local btn = UI.Button {
            text = (isChecked and "✓ " or "   ") .. QUALITY_LABELS[idx],
            fontSize = T.fontSize.xs,
            paddingLeft = T.spacing.sm,
            paddingRight = T.spacing.sm,
            height = 24,
            borderRadius = T.radius.sm,
            backgroundColor = isChecked and T.color.surfaceLight or T.color.surfaceDeep,
            onClick = function(self)
                sellQualities_[key] = not sellQualities_[key]
                local checked = sellQualities_[key]
                self:SetText((checked and "✓ " or "   ") .. QUALITY_LABELS[idx])
                self:SetBackgroundColor(checked and T.color.surfaceLight or T.color.surfaceDeep)
                InventoryOps.SaveSellSettings(SELL_SETTINGS_FILE, sellQualities_)
            end,
        }
        qualityBtns[idx] = btn
        qualityPanel:AddChild(btn)
    end
    sellMenu_ = qualityPanel  -- 保留引用供 Hide 时关闭

    -- 操作栏（整理 + 批量出售 + 品质展开 + 空位显示）
    invPanel:AddChild(UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.xs,
                children = {
                    UI.Button {
                        text = "整理",
                        fontSize = T.fontSize.xs,
                        paddingLeft = T.spacing.sm,
                        paddingRight = T.spacing.sm,
                        height = 28,
                        borderRadius = T.radius.sm,
                        backgroundColor = T.color.btnSecondary,
                        fontColor = T.color.btnSecondaryFg,
                        onClick = function(self)
                            local msg = InventoryOps.DoSort(InventorySystem.SortBackpack)
                            UpdateAllSlots()
                            InventoryUI.UpdateFreeSlots()
                            if shell_ then shell_.resultLabel:SetText(msg) end
                        end,
                    },
                    UI.Button {
                        text = "批量出售",
                        fontSize = T.fontSize.xs,
                        paddingLeft = T.spacing.sm,
                        paddingRight = T.spacing.sm,
                        height = 28,
                        borderRadius = T.radius.sm,
                        borderTopRightRadius = 0,
                        borderBottomRightRadius = 0,
                        backgroundColor = T.color.btnSuccess,
                        fontColor = T.color.btnSuccessFg,
                        onClick = function(self)
                            local ok, msg = InventoryOps.DoBatchSell(sellQualities_, InventorySystem.SellByQuality)
                            if ok then
                                UpdateAllSlots()
                                InventoryUI.UpdateFreeSlots()
                            end
                            if shell_ then shell_.resultLabel:SetText(msg) end
                        end,
                    },
                    UI.Button {
                        text = "▼",
                        fontSize = T.fontSize.xxs,
                        width = 20,
                        height = 28,
                        paddingLeft = 0,
                        paddingRight = 0,
                        borderRadius = T.radius.sm,
                        borderTopLeftRadius = 0,
                        borderBottomLeftRadius = 0,
                        backgroundColor = T.color.btnSecondary,
                        fontColor = T.color.btnSecondaryFg,
                        onClick = function(self)
                            -- 内联展开/收起品质面板
                            if qualityPanel:IsVisible() then
                                qualityPanel:Hide()
                                self:SetText("▼")
                            else
                                qualityPanel:Show()
                                self:SetText("▲")
                            end
                        end,
                    },
                },
            },
            UI.Label {
                id = "inv_free_slots",
                text = "60/60",
                fontSize = T.fontSize.xs,
                fontColor = T.color.invEmptySlot,
            },
        },
    })

    -- 品质选择面板（内联，在操作栏下方展开）
    invPanel:AddChild(qualityPanel)

    -- 背包格子（连续 1~BACKPACK_SIZE，无分隔）
    local gridPanel = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }
    for i = 1, GameConfig.BACKPACK_SIZE do
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
        gridPanel:AddChild(slot)
    end
    invPanel:AddChild(gridPanel)

    return invPanel
end

--- Tab 切换函数
local function SwitchTab(tab)
    if currentTab_ == tab then return end
    currentTab_ = tab

    -- 更新按钮样式（标准 tab 色，仅背景切换）
    if tabBtnEquip_ then
        tabBtnEquip_:SetBackgroundColor(tab == "equip" and T.color.tabActiveBg or T.color.tabInactiveBg)
    end
    if tabBtnMingge_ then
        tabBtnMingge_:SetBackgroundColor(tab == "mingge" and T.color.tabActiveBg or T.color.tabInactiveBg)
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
        -- subtitle 已由 header Tab 替代，无需设置
        if shell_ then shell_.resultLabel:SetText("") end
        UpdateAllSlots()
        InventoryUI.UpdateStats()
        InventoryUI.UpdateFreeSlots()
        -- 隐藏命格 tooltip
        MinggePage.OnHide()
    else
        -- subtitle 已由 header Tab 替代，无需设置
        if shell_ then shell_.resultLabel:SetText("") end
        MinggePage.OnShow()
        -- 隐藏装备 tooltip
        EquipTooltip.Hide()
        if sellMenu_ and sellMenu_:IsVisible() then sellMenu_:Hide() end
    end
end

--- 创建整个背包 UI 面板
---@param parentOverlay table overlay Widget
function InventoryUI.Create(parentOverlay)
    -- PanelShell 外壳（标准竖屏参数：maxWidth=500, maxHeight=76%）
    local PORTRAIT_SIZE = 64
    local portraitPanel = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        overflow = "hidden",
        backgroundImage = "image/icon_backpack_20260618104916.png",
        backgroundFit = "contain",
    }

    -- Tab 按钮需要先创建，传入 titleContent
    -- （前置声明，实际按钮在下方创建后回填）
    local titleContent = UI.Panel {
        flexDirection = "row",
        gap = T.spacing.xs,
    }

    shell_ = PanelShell.Create({
        portrait = portraitPanel,
        titleContent = titleContent,
        onClose = function() InventoryUI.Hide() end,
        parent = parentOverlay,
        zIndex = 120,
        maxHeight = "80%",
        footerHint = "点击空白处关闭",
    })
    panel_ = shell_.panel  -- 保持 panel_ 引用用于 Show/Hide 兼容

    -- Tab 按钮（嵌入 header titleContent）
    tabBtnEquip_ = UI.Button {
        text = "⚔️ 装备",
        flexGrow = 1,
        height = 36,
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        borderRadius = T.radius.sm,
        backgroundColor = T.color.tabActiveBg,
        fontColor = T.color.tabActiveText,
        onClick = function(self) SwitchTab("equip") end,
    }
    tabBtnMingge_ = UI.Button {
        text = "☯️ 命格",
        flexGrow = 1,
        height = 36,
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        borderRadius = T.radius.sm,
        backgroundColor = T.color.tabInactiveBg,
        fontColor = T.color.tabInactiveText,
        onClick = function(self) SwitchTab("mingge") end,
    }

    -- 将 Tab 按钮挂入 header 的 titleContent
    titleContent:AddChild(tabBtnEquip_)
    titleContent:AddChild(tabBtnMingge_)

    -- 装备页内容容器（竖屏单列：装备区 → 操作栏 → 背包 grid）
    equipContent_ = UI.Panel {
        gap = T.spacing.sm,
        alignItems = "center",
        children = {
            CreateEquipPanel(),
            CreateInvPanel(),
        },
    }

    -- 命格页内容容器
    minggeContent_ = MinggePage.Create(parentOverlay)
    minggeContent_:Hide()  -- 默认隐藏

    -- 组装内容到 PanelShell（Tab 已在 header 中，无需单独添加）
    shell_:AddContent(equipContent_)
    shell_:AddContent(minggeContent_)

    -- 品质选择面板已改为内联模式（在 CreateInvPanel 中创建），无需挂载到 overlay

    -- 初始化装备详情浮层（挂载到 overlay 层，确保在背包面板之上）
    EquipTooltip.Init(parentOverlay)

    -- 监听装备变更（含存档恢复后首次触发）→ 同步刷新格子+属性+空位
    EventBus.On("equip_stats_changed", function()
        if visible_ and currentTab_ == "equip" then
            UpdateAllSlots()
            InventoryUI.UpdateFreeSlots()
        end
        InventoryUI.UpdateStats()
    end)

    -- 监听单件物品入包（掉落/购买/领取时触发）
    EventBus.On("inventory_item_added", function()
        if visible_ and currentTab_ == "equip" then
            UpdateAllSlots()
            InventoryUI.UpdateFreeSlots()
        end
    end)

    -- 监听命格页信息（由 MinggePage 通过事件传递到共享 infoLabel）
    EventBus.On("mingge_info", function(msg)
        if shell_ and currentTab_ == "mingge" then
            shell_.resultLabel:SetText(msg or "")
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
        if shell_ then shell_.resultLabel:SetText("") end
        if sellMenu_ and sellMenu_:IsVisible() then sellMenu_:Hide() end
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

    -- 套装效果（逐条渲染到独立容器）
    local setPanel = panel_:FindById("set_bonus_panel")
    if setPanel then
        setPanel:ClearChildren()
        local bonuses = InventorySystem.GetActiveSetBonuses()
        for _, b in ipairs(bonuses) do
            setPanel:AddChild(UI.Label {
                text = b.name .. ": " .. b.description,
                fontSize = T.fontSize.xs,
                fontColor = T.color.invSetBonus,
            })
        end
    end

    -- 摘要行更新（攻/防/血）
    local sumAtk = panel_:FindById("stat_summary_atk")
    local sumDef = panel_:FindById("stat_summary_def")
    local sumHp  = panel_:FindById("stat_summary_maxHp")
    if sumAtk then sumAtk:SetText("攻+" .. math.floor(summary.atk or 0)) end
    if sumDef then sumDef:SetText("防+" .. math.floor(summary.def or 0)) end
    if sumHp  then sumHp:SetText("血+" .. math.floor(summary.maxHp or 0)) end
end

--- 更新背包空位显示
function InventoryUI.UpdateFreeSlots()
    if not panel_ then return end
    local label = panel_:FindById("inv_free_slots")
    if label then
        local manager = InventorySystem.GetManager()
        local free = 0
        if manager then
            for i = 1, GameConfig.BACKPACK_SIZE do
                if not manager:GetInventoryItem(i) then free = free + 1 end
            end
        end
        label:SetText(free .. "/" .. GameConfig.BACKPACK_SIZE)
    end
end

return InventoryUI
