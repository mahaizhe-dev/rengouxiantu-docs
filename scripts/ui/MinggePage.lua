---@diagnostic disable
-- ============================================================================
-- MinggePage.lua - 五行命格页面（装备 + 背包 + 属性统计）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: 五行方位布局 | 内联品质选择 | 2列属性详情 | 延迟渲染 | 独立背包
-- ============================================================================

local UI = require("urhox-libs/UI")
local MinggeData = require("config.MinggeData")
local MinggeSystem = require("systems.MinggeSystem")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local ImageItemSlot = require("ui.ImageItemSlot")
local MinggeTooltip = require("ui.MinggeTooltip")
local GameConfig = require("config.GameConfig")
local InventoryOps = require("ui.InventoryOps")
local T = require("config.UITheme")

local MinggePage = {}

-- UI 状态
local contentPanel_ = nil
local equipSlots_ = {}
local invSlots_ = {}
local sellMenu_ = nil
local lockMask_ = nil
local wrapperPanel_ = nil
local sellQualities_ = { purple = true, orange = false }
local contentCreated_ = false  -- 延迟渲染标志：首次 OnShow 时才创建格子
local minggeStatsExpanded_ = false
local minggeStatsDetail_ = nil

-- 批量出售品质勾选持久化（委托 InventoryOps）
local SELL_SETTINGS_FILE = "sell_mingge_settings.json"
InventoryOps.LoadSellSettings(SELL_SETTINGS_FILE, sellQualities_)

-- 配置
local INV_COLS = 7
local SLOT_SIZE = T.size.slotSize
local SLOT_GAP = T.spacing.xs

-- 五行元素颜色（统一引用 MinggeData 单一源，不再本地维护副本）
local ELEMENT_COLORS = MinggeData.ELEMENT_COLORS

-- 五行元素 Emoji（方位布局视觉标识）
local ELEMENT_EMOJI = {
    metal = "🪙",
    wood  = "🌳",
    water = "💧",
    fire  = "🔥",
    earth = "🪨",
}

-- ============================================================================
-- 刷新函数（前置声明）
-- ============================================================================

local function UpdateAllSlots() end
local function UpdateStats() end
local function UpdateFreeSlots() end

--- 检查是否达到解锁境界（金丹初期 order>=7）
local function CheckRealmUnlocked()
    local player = GameState.player
    if not player then return false end
    local realmData = GameConfig.REALMS[player.realm]
    if not realmData then return false end
    return realmData.order >= 7
end

-- ============================================================================
-- 装备面板（左侧 5行×3列）
-- ============================================================================

local function CreateEquipPanel()
    local eqPanel = UI.Panel {
        width = "100%",
        alignItems = "center",
        gap = T.spacing.xs,
    }

    -- 辅助：创建一个元素组（emoji label + 3 slots 垂直排列）
    local function buildElementGroup(element)
        local elName = MinggeData.ELEMENT_NAMES[element]
        local elColor = ELEMENT_COLORS[element] or T.color.textSecondary
        local group = UI.Panel {
            alignItems = "center",
            gap = T.spacing.xxs,
        }
        group:AddChild(UI.Label {
            text = ELEMENT_EMOJI[element] .. " " .. elName,
            fontSize = T.fontSize.xs,
            fontColor = elColor,
        })
        local slotRow = UI.Panel { flexDirection = "row", gap = SLOT_GAP }
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
            slotRow:AddChild(slot)
        end
        group:AddChild(slotRow)
        return group
    end

    -- 命格格子区：五行方位布局
    -- Row 1: 水(北/上，居中)
    -- Row 2: 木(东/左) + 金(西/右)
    -- Row 3: 火(南/左下) + 土(中/右下)
    local equipGrid = UI.Panel {
        alignItems = "center",
        gap = T.spacing.xs,
    }

    -- Row 1: 水（北/上，居中）
    equipGrid:AddChild(buildElementGroup("water"))

    -- Row 2: 木（左）+ 金（右）
    equipGrid:AddChild(UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        gap = T.spacing.lg,
        children = {
            buildElementGroup("wood"),
            buildElementGroup("metal"),
        },
    })

    -- Row 3: 火（左）+ 土（右）
    equipGrid:AddChild(UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        gap = T.spacing.lg,
        children = {
            buildElementGroup("fire"),
            buildElementGroup("earth"),
        },
    })

    -- surfaceDeep 容器包裹 equipGrid（与 InventoryUI 装备区对齐）
    eqPanel:AddChild(UI.Panel {
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.borderLight,
        padding = T.spacing.sm,
        children = { equipGrid },
    })

    -- ── 属性摘要行（始终可见：攻/防/血 + 展开按钮） ──
    local expandBtn = UI.Button {
        id = "mg_stat_expand_btn",
        text = "🔻 详情",
        fontSize = T.fontSize.xs,
        paddingLeft = T.spacing.xs,
        paddingRight = T.spacing.xs,
        height = 20,
        borderRadius = T.radius.sm,
        backgroundColor = T.color.invStatPanelBg,
        fontColor = T.color.textSecondary,
        onClick = function(self)
            minggeStatsExpanded_ = not minggeStatsExpanded_
            if minggeStatsDetail_ then
                if minggeStatsExpanded_ then minggeStatsDetail_:Show() else minggeStatsDetail_:Hide() end
            end
            self:SetText(minggeStatsExpanded_ and "🔺 收起" or "🔻 详情")
        end,
    }

    local statsSummary = UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = T.spacing.xs,
        marginTop = T.spacing.xs,
        children = {
            UI.Label { id = "mg_stat_summary_atk", text = "攻+0", fontSize = T.fontSize.xs, fontColor = T.statColor.atk },
            UI.Label { id = "mg_stat_summary_def", text = "防+0", fontSize = T.fontSize.xs, fontColor = T.statColor.def },
            UI.Label { id = "mg_stat_summary_maxHp", text = "血+0", fontSize = T.fontSize.xs, fontColor = T.statColor.maxHp },
            expandBtn,
        },
    }
    eqPanel:AddChild(statsSummary)

    -- ── 属性详情（默认隐藏，展开后随面板整体滚动，无独立滚动条） ──
    local MG_STAT_ROW_H = 16

    -- 左列属性
    local leftDefs = {
        { key = "atk",          label = "攻击" },
        { key = "maxHp",        label = "生命" },
        { key = "critRate",     label = "暴击率" },
        { key = "heavyHit",     label = "重击" },
        { key = "killHeal",     label = "击杀回血" },
        { key = "moveSpeed",    label = "移速" },
        { key = "wisdom",       label = "悟性" },
        { key = "tianzhuChance",label = "天诛" },
    }
    -- 右列属性
    local rightDefs = {
        { key = "def",          label = "防御" },
        { key = "hpRegen",      label = "回复" },
        { key = "critDmg",      label = "暴击伤害" },
        { key = "tianzhuDamage",label = "天诛伤害" },
        { key = "fortune",      label = "福缘" },
        { key = "constitution", label = "根骨" },
        { key = "physique",     label = "体魄" },
    }

    local function buildMgStatColumn(defs)
        local col = UI.Panel { flexGrow = 1, flexShrink = 1, gap = 1 }
        for _, sd in ipairs(defs) do
            col:AddChild(UI.Panel {
                height = MG_STAT_ROW_H,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingRight = T.spacing.xs,
                children = {
                    UI.Label { text = sd.label, fontSize = T.fontSize.xs, fontColor = T.statColor[sd.key] or T.color.textSecondary },
                    UI.Label { id = "mg_stat_" .. sd.key, text = "+0", fontSize = T.fontSize.xs, fontColor = T.color.invStatValue },
                },
            })
        end
        return col
    end

    -- 属性双列面板（无独立滚动，随面板整体滚动）
    minggeStatsDetail_ = UI.Panel {
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
                    buildMgStatColumn(leftDefs),
                    UI.Panel { width = 1, backgroundColor = T.color.borderLight },
                    buildMgStatColumn(rightDefs),
                },
            },
            -- 分隔线
            UI.Panel { width = "100%", height = 1, backgroundColor = T.color.borderLight, marginTop = T.spacing.xxs },
            -- 套装效果区
            UI.Panel {
                id = "mg_set_bonus_panel",
                width = "100%",
                gap = T.spacing.xxs,
            },
        },
    }
    eqPanel:AddChild(minggeStatsDetail_)

    return eqPanel
end

-- ============================================================================
-- 背包面板（右侧 60 格，30/30 分隔）
-- ============================================================================

local function CreateInvPanel()
    local invPanel = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
    }

    -- 品质选择内联面板（默认隐藏，点击▼展开）
    local QUALITY_KEYS = { "purple", "orange" }
    local QUALITY_LABELS = { "🟣极品", "🟠稀世" }
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
        qualityPanel:AddChild(btn)
    end
    sellMenu_ = qualityPanel

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
                        height = 24,
                        borderRadius = T.radius.sm,
                        backgroundColor = T.color.invSortBtn,
                        onClick = function(self)
                            InventoryOps.DoSort(MinggeSystem.SortBackpack)
                            UpdateAllSlots()
                            UpdateFreeSlots()
                        end,
                    },
                    UI.Button {
                        text = "批量出售",
                        fontSize = T.fontSize.xs,
                        paddingLeft = T.spacing.sm,
                        paddingRight = T.spacing.sm,
                        height = 24,
                        borderRadius = T.radius.sm,
                        borderTopRightRadius = 0,
                        borderBottomRightRadius = 0,
                        backgroundColor = T.color.invSellBtn,
                        onClick = function(self)
                            -- wrapper: MinggeSystem.SellByQuality 返回 (count, lingYun)，映射到 (count, 0, lingYun)
                            local ok, msg = InventoryOps.DoBatchSell(sellQualities_, function(q)
                                local c, ly = MinggeSystem.SellByQuality(q)
                                return c, 0, ly
                            end)
                            if ok then
                                UpdateAllSlots()
                                UpdateFreeSlots()
                            end
                            EventBus.Emit("mingge_info", msg)
                        end,
                    },
                    UI.Button {
                        text = "▼",
                        fontSize = 9,
                        width = 20,
                        height = 24,
                        paddingLeft = 0,
                        paddingRight = 0,
                        borderRadius = T.radius.sm,
                        borderTopLeftRadius = 0,
                        borderBottomLeftRadius = 0,
                        backgroundColor = T.color.invSellDropBtn,
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
                id = "mg_free_slots",
                text = MinggeData.BACKPACK_SIZE .. "/" .. MinggeData.BACKPACK_SIZE,
                fontSize = T.fontSize.xs,
                fontColor = T.color.invEmptySlot,
            },
        },
    })

    -- 品质选择面板（内联，在操作栏下方展开）
    invPanel:AddChild(qualityPanel)

    -- 背包格子（连续 1~BACKPACK_SIZE）
    local gridPanel = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }
    for i = 1, MinggeData.BACKPACK_SIZE do
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
        gridPanel:AddChild(slot)
    end
    invPanel:AddChild(gridPanel)

    return invPanel
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 构建命格页面内容（返回 panel，由 InventoryUI 挂载）
---@param parentOverlay Panel 遮罩层（用于挂载 tooltip 和 menu）
---@return Panel
function MinggePage.Create(parentOverlay)
    -- 🔴 FIX: 重置所有模块级状态，防止"退出再进"时 contentCreated_ 残留导致
    -- 新 contentPanel_ 为空但 OnShow() 跳过内容创建，旧 slot widget 脱离渲染树
    -- 后 backgroundImage 在错误位置显示（P0 渲染异常）
    contentCreated_ = false
    equipSlots_ = {}
    invSlots_ = {}
    minggeStatsExpanded_ = false
    minggeStatsDetail_ = nil

    contentPanel_ = UI.Panel {
        gap = T.spacing.sm,
    }

    -- 初始化 MinggeTooltip
    MinggeTooltip.Init(parentOverlay)

    -- 品质选择面板已改为内联模式（在 CreateInvPanel 中创建），无需挂载到 overlay

    -- 监听命格变更
    EventBus.On("mingge_stats_changed", function()
        UpdateStats()
    end)

    -- 🔴 FIX: 监听命格拾取，实时刷新背包格子（否则页面已打开时拾取不会显示新物品）
    EventBus.On("mingge_item_added", function()
        if contentCreated_ then
            UpdateAllSlots()
            UpdateFreeSlots()
        end
    end)

    -- 解封遮罩（手动解封，需金丹初期 order>=7）
    lockMask_ = UI.Panel {
        id = "mg_lock_mask",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.minggeLockMask,
        justifyContent = "center",
        alignItems = "center",
        zIndex = 50,
        children = {
            UI.Panel {
                alignItems = "center",
                gap = T.spacing.md,
                children = {
                    UI.Label {
                        text = "🔒",
                        fontSize = 40,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "五行命格",
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = T.color.qualityPurple,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "修炼至「金丹初期」可解封",
                        fontSize = T.fontSize.md,
                        fontColor = T.color.invInfoLabel,
                        textAlign = "center",
                    },
                    UI.Label {
                        id = "mg_lock_realm_hint",
                        text = "",
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.textMuted,
                        textAlign = "center",
                    },
                    UI.Button {
                        id = "mg_unlock_btn",
                        text = "解 封",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        paddingLeft = T.spacing.xl,
                        paddingRight = T.spacing.xl,
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.sm,
                        marginTop = T.spacing.md,
                        borderRadius = T.radius.md,
                        backgroundColor = T.color.minggeUnlockBtn,
                        onClick = function(self)
                            if CheckRealmUnlocked() then
                                -- 解封成功
                                MinggeSystem.SetUnlocked(true)
                                -- 确保 manager 已初始化（新游戏路径可能为 nil）
                                if not MinggeSystem.GetManager() then
                                    MinggeSystem.Init()
                                end
                                lockMask_:Hide()
                                UpdateAllSlots()
                                UpdateStats()
                                UpdateFreeSlots()
                                EventBus.Emit("mingge_info", "五行命格已解封！")
                                EventBus.Emit("save_request")
                            else
                                -- 境界不足
                                local hintLabel = lockMask_:FindById("mg_lock_realm_hint")
                                if hintLabel then
                                    hintLabel:SetText("⚠ 境界不足，需要「金丹初期」")
                                end
                            end
                        end,
                    },
                },
            },
        },
    }

    -- 用 wrapper 包裹 contentPanel_ 和 lockMask_（相对定位容器）
    wrapperPanel_ = UI.Panel {
        children = {
            contentPanel_,
            lockMask_,
        },
    }

    return wrapperPanel_
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

    -- 套装加成（每条独占一行）
    local setPanel = contentPanel_:FindById("mg_set_bonus_panel")
    if setPanel then
        setPanel:RemoveAllChildren()
        local bonuses = MinggeSystem.GetActiveSetBonuses()
        for _, b in ipairs(bonuses) do
            local setDef = MinggeData.SETS[b.setId]
            if setDef then
                local elName = MinggeData.ELEMENT_NAMES[b.element] or "?"
                setPanel:AddChild(UI.Label {
                    text = elName .. "行·" .. setDef.name .. ": " .. setDef.desc,
                    fontSize = T.fontSize.xs,
                    fontColor = T.color.minggeSetBonus,
                    maxWidth = 9999,
                })
            end
        end
    end

    -- 摘要行更新（攻/防/血）
    local sumAtk = contentPanel_:FindById("mg_stat_summary_atk")
    local sumDef = contentPanel_:FindById("mg_stat_summary_def")
    local sumHp  = contentPanel_:FindById("mg_stat_summary_maxHp")
    if sumAtk then sumAtk:SetText("攻+" .. math.floor(summary.atk or 0)) end
    if sumDef then sumDef:SetText("防+" .. math.floor(summary.def or 0)) end
    if sumHp  then sumHp:SetText("血+" .. math.floor(summary.maxHp or 0)) end
end

--- 刷新背包空位显示
function UpdateFreeSlots()
    if not contentPanel_ then return end
    local label = contentPanel_:FindById("mg_free_slots")
    if label then
        local manager = MinggeSystem.GetManager()
        local free = 0
        if manager then
            for i = 1, MinggeData.BACKPACK_SIZE do
                if not manager:GetInventoryItem(i) then free = free + 1 end
            end
        end
        label:SetText(free .. "/" .. MinggeData.BACKPACK_SIZE)
    end
end

--- 页面被显示时调用（刷新数据）
function MinggePage.OnShow()
    -- 延迟渲染：首次 OnShow 时才创建装备面板和背包面板
    if not contentCreated_ then
        contentCreated_ = true
        -- 竖屏单列：装备区在上，背包在下
        contentPanel_:AddChild(CreateEquipPanel())
        contentPanel_:AddChild(CreateInvPanel())
    end

    -- 检查持久化解封标记（境界达标时自动解封）
    if lockMask_ then
        local isUnlocked = MinggeSystem.IsUnlocked()
        if not isUnlocked and CheckRealmUnlocked() then
            -- 境界已达标但未解封（老存档），自动解封
            MinggeSystem.SetUnlocked(true)
            if not MinggeSystem.GetManager() then
                MinggeSystem.Init()
            end
            isUnlocked = true
            EventBus.Emit("save_request")
        end
        if isUnlocked then
            lockMask_:Hide()
        else
            lockMask_:Show()
            -- 更新当前境界提示
            local hintLabel = lockMask_:FindById("mg_lock_realm_hint")
            if hintLabel then
                local player = GameState.player
                local realmName = "凡人"
                if player and player.realm then
                    local rd = GameConfig.REALMS[player.realm]
                    if rd then realmName = rd.name end
                end
                hintLabel:SetText("当前境界：" .. realmName)
            end
            return  -- 遮罩状态下不刷新内容
        end
    end

    UpdateAllSlots()
    UpdateStats()
    UpdateFreeSlots()
end

--- 页面被隐藏时调用
function MinggePage.OnHide()
    MinggeTooltip.Hide()
    if sellMenu_ and sellMenu_:IsVisible() then sellMenu_:Hide() end
end

return MinggePage
