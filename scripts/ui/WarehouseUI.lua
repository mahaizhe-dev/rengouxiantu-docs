-- ============================================================================
-- WarehouseUI.lua - 仓库面板（宝箱 NPC 交互打开）
-- 创建一次 + 数据更新模式，避免每次操作重建 108 个组件导致卡死
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local WarehouseConfig = require("config.WarehouseConfig")
local WarehouseSystem = require("systems.WarehouseSystem")
local ImageItemSlot = require("ui.ImageItemSlot")
local EventBus = require("core.EventBus")

local WarehouseUI = {}

-- ── 常量 ──
local SLOT_SIZE = T.size.slotSize
local SLOT_GAP = T.spacing.xs
local COLS = WarehouseConfig.ITEMS_PER_ROW
local GRID_W = COLS * SLOT_SIZE + (COLS - 1) * SLOT_GAP  -- 8×56 + 7×4 = 476

-- ── 状态 ──
local parentOverlay_ = nil
---@type Panel|nil
local panel_ = nil
---@type Panel|nil
local outerPanel_ = nil
local visible_ = false
local goldLabel_ = nil
local localToast_ = nil

-- 槽位缓存（创建一次，后续只更新数据）
local whSlots_ = {}        -- [1..48] 仓库槽位 (ImageItemSlot)
local bagSlots_ = {}       -- [1..BACKPACK_SIZE] 背包槽位
local whGrid_ = nil        -- 仓库网格面板
local bagGrid_ = nil       -- 背包网格面板
local whTitleLabel_ = nil  -- "📦 仓库 x/y" 标签
local unlockBtn_ = nil     -- 解锁按钮
local contentBuilt_ = false
local lastUnlockedRows_ = 0  -- 上次构建时的解锁行数

-- ── 前向声明（解决循环依赖）──
local UpdateAllSlots
local BuildContent
local DestroyContent

-- ============================================================================
-- 仓库内部 toast
-- ============================================================================
local function DismissLocalToast()
    if localToast_ then
        localToast_:Destroy()
        localToast_ = nil
    end
end

local function ShowLocalToast(text)
    DismissLocalToast()
    localToast_ = UI.Panel {
        position = "absolute",
        top = "18%",
        left = 0, right = 0,
        zIndex = 10,
        pointerEvents = "none",
        alignItems = "center",
        children = {
            UI.Panel {
                backgroundColor = {20, 22, 30, 240},
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = {180, 220, 255, 255},
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.sm,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                children = {
                    UI.Label {
                        text = text,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {180, 220, 255, 255},
                        textAlign = "center",
                    },
                },
            },
        },
    }
    if panel_ then
        panel_:AddChild(localToast_)
    end
end

-- ============================================================================
-- 构建仓库网格（仅在 Show 时 / 解锁行时调用）
-- ============================================================================
local function BuildWarehouseGrid()
    if whGrid_ then
        whGrid_:Destroy()
        whGrid_ = nil
    end
    whSlots_ = {}

    local unlockedSlots = WarehouseSystem.GetUnlockedSlots()
    lastUnlockedRows_ = WarehouseSystem.GetUnlockedRows()

    whGrid_ = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }

    local totalSlots = WarehouseConfig.MAX_ROWS * COLS
    for idx = 1, totalSlots do
        local isLocked = idx > unlockedSlots
        if isLocked then
            local locked = UI.Panel {
                width = SLOT_SIZE,
                height = SLOT_SIZE,
                backgroundColor = {40, 40, 50, 150},
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = {60, 65, 80, 100},
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "🔒",
                        fontSize = T.fontSize.md,
                        textAlign = "center",
                    },
                },
            }
            whSlots_[idx] = nil
            whGrid_:AddChild(locked)
        else
            local capturedIdx = idx
            local slot = ImageItemSlot {
                slotId = idx,
                size = SLOT_SIZE,
                showTypeIcon = false,
                onSlotClick = function(slotWidget, clickedItem)
                    if clickedItem then
                        local ok, err = WarehouseSystem.RetrieveItem(capturedIdx)
                        if ok then
                            ShowLocalToast("已取出到背包")
                        else
                            ShowLocalToast(err or "取出失败")
                        end
                        UpdateAllSlots()
                    end
                end,
            }
            whSlots_[idx] = slot
            whGrid_:AddChild(slot)
        end
    end

    return whGrid_
end

-- ============================================================================
-- 构建背包网格（仅在 Show 时调用一次）
-- ============================================================================
local function BuildBagGrid()
    if bagGrid_ then
        bagGrid_:Destroy()
        bagGrid_ = nil
    end
    bagSlots_ = {}

    bagGrid_ = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }

    local totalBag = GameConfig.BACKPACK_SIZE
    for i = 1, totalBag do
        local capturedIdx = i
        local slot = ImageItemSlot {
            slotId = i,
            size = SLOT_SIZE,
            showTypeIcon = false,
            onSlotClick = function(slotWidget, clickedItem)
                if clickedItem then
                    local ok, err = WarehouseSystem.StoreItem(capturedIdx)
                    if ok then
                        ShowLocalToast("已存入仓库")
                    else
                        ShowLocalToast(err or "存放失败")
                    end
                    UpdateAllSlots()
                end
            end,
        }
        bagSlots_[i] = slot
        bagGrid_:AddChild(slot)
    end

    return bagGrid_
end

-- ============================================================================
-- 清理内容（Hide 时 / 解锁重建前调用）
-- ============================================================================
DestroyContent = function()
    if not contentBuilt_ then return end

    -- Destroy() 逐个销毁，RemoveAllChildren 只移除不释放
    if outerPanel_ then
        local children = outerPanel_.children
        if children then
            for i = #children, 1, -1 do
                children[i]:Destroy()
            end
        end
    end

    whSlots_ = {}
    bagSlots_ = {}
    whGrid_ = nil
    bagGrid_ = nil
    whTitleLabel_ = nil
    unlockBtn_ = nil
    contentBuilt_ = false
    lastUnlockedRows_ = 0
end

-- ============================================================================
-- 构建完整内容（仅 Show 时 / 解锁行时调用）
-- ============================================================================
BuildContent = function()
    -- 仓库标题
    whTitleLabel_ = UI.Label {
        text = "📦 仓库  0/0",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = T.color.titleText,
    }
    outerPanel_:AddChild(whTitleLabel_)

    -- 仓库网格
    BuildWarehouseGrid()
    outerPanel_:AddChild(whGrid_)

    -- 解锁按钮
    unlockBtn_ = UI.Button {
        text = "",
        width = "100%",
        height = 36,
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        borderRadius = T.radius.sm,
        backgroundColor = {180, 140, 40, 255},
        onClick = function(self)
            local ok, err = WarehouseSystem.UnlockNextRow()
            if ok then
                ShowLocalToast("解锁成功！")
            else
                ShowLocalToast(err or "解锁失败")
            end
            UpdateAllSlots()
        end,
    }
    outerPanel_:AddChild(unlockBtn_)

    -- 分割线
    outerPanel_:AddChild(UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 100},
        marginTop = T.spacing.xs,
        marginBottom = T.spacing.xs,
    })

    -- 背包标题
    outerPanel_:AddChild(UI.Label {
        text = "🎒 背包（点击物品存入仓库）",
        fontSize = T.fontSize.sm,
        fontColor = {180, 180, 200, 200},
    })

    -- 背包网格
    BuildBagGrid()
    outerPanel_:AddChild(bagGrid_)

    contentBuilt_ = true
end

-- ============================================================================
-- 数据更新（不重建组件，只更新 SetItem）
-- ============================================================================
UpdateAllSlots = function()
    -- 仓库槽位
    for idx = 1, WarehouseConfig.MAX_ROWS * COLS do
        local slot = whSlots_[idx]
        if slot then
            local item = WarehouseSystem.GetItem(idx)
            slot:SetItem(item)
        end
    end

    -- 背包槽位
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    for i = 1, GameConfig.BACKPACK_SIZE do
        local slot = bagSlots_[i]
        if slot then
            local item = mgr and mgr:GetInventoryItem(i) or nil
            slot:SetItem(item)
        end
    end

    -- 仓库标题
    if whTitleLabel_ then
        local itemCount = WarehouseSystem.GetItemCount()
        local totalSlots = WarehouseSystem.GetUnlockedSlots()
        whTitleLabel_:SetText("📦 仓库  " .. itemCount .. "/" .. totalSlots)
    end

    -- 解锁按钮
    local unlockedRows = WarehouseSystem.GetUnlockedRows()
    if unlockBtn_ then
        if unlockedRows < WarehouseConfig.MAX_ROWS then
            local nextRow = unlockedRows + 1
            local cost = WarehouseConfig.GetRowCost(nextRow)
            unlockBtn_:SetText("🔓 解锁第" .. nextRow .. "排（" .. WarehouseSystem.FormatGold(cost) .. " 金币）")
            unlockBtn_:SetVisible(true)
        else
            unlockBtn_:SetVisible(false)
        end
    end

    -- 金币
    if goldLabel_ then
        local player = GameState.player
        local goldText = player and ("💰 " .. WarehouseSystem.FormatGold(player.gold)) or ""
        goldLabel_:SetText(goldText)
    end

    -- 如果解锁行数变了，需要重建整个内容（解锁操作极少，可接受）
    if unlockedRows ~= lastUnlockedRows_ and outerPanel_ then
        DestroyContent()
        BuildContent()
        UpdateAllSlots()
    end
end

-- ============================================================================
-- 公共 API
-- ============================================================================

function WarehouseUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    local gridW = COLS * SLOT_SIZE + (COLS - 1) * SLOT_GAP
    local panelW = gridW + T.spacing.md * 2 + 8

    goldLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {255, 215, 0, 230},
    }

    outerPanel_ = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
    }

    local scrollView_ = UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        width = "100%",
        overflow = "scroll",
        gap = T.spacing.sm,
        children = {
            outerPanel_,
        },
    }

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 900,
        visible = false,
        onClick = function(self)
            WarehouseUI.Hide()
        end,
        children = {
            UI.Panel {
                width = panelW,
                maxHeight = "90%",
                backgroundColor = {25, 28, 38, 248},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {100, 120, 170, 150},
                padding = T.spacing.md,
                gap = T.spacing.sm,
                onClick = function(self) end,
                children = {
                    -- 标题栏（固定在滚动区外部）
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.sm,
                                backgroundColor = {80, 40, 40, 200},
                                onClick = function(self)
                                    WarehouseUI.Hide()
                                end,
                            },
                            UI.Label {
                                text = "📦 百宝箱",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = T.color.titleText,
                            },
                            goldLabel_,
                        },
                    },
                    -- 可滚动内容区
                    scrollView_,
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)
end

function WarehouseUI.Show(npc)
    if visible_ then return end
    if not panel_ then return end

    WarehouseSystem.Init()
    WarehouseSystem.SetOpen(true)

    visible_ = true
    GameState.uiOpen = "warehouse"
    panel_:SetVisible(true)

    -- 构建内容（创建槽位）
    BuildContent()
    -- 填充数据
    UpdateAllSlots()

    print("[WarehouseUI] Show")
end

function WarehouseUI.Hide()
    if not visible_ then return end

    DismissLocalToast()
    WarehouseSystem.SetOpen(false)

    -- 销毁内容，释放槽位
    DestroyContent()

    if panel_ then
        panel_:SetVisible(false)
    end
    visible_ = false
    GameState.uiOpen = nil

    print("[WarehouseUI] Hide")
end

function WarehouseUI.IsVisible()
    return visible_
end

function WarehouseUI.Destroy()
    WarehouseUI.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    outerPanel_ = nil
    goldLabel_ = nil
    parentOverlay_ = nil
end

return WarehouseUI
