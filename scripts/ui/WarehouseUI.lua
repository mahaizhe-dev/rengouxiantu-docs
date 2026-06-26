---@diagnostic disable: param-type-mismatch, assign-type-mismatch
-- ============================================================================
-- WarehouseUI.lua - 仓库面板（宝箱 NPC 交互打开）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: 创建/销毁模式 | 108格子按需构建 | 脏标记即时存档 | S2.4骨架
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

-- ── 整理按钮防连点 CD ──
local SORT_CD = 1.5  -- 秒
local lastSortTime_ = -999

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

local localToast_ = nil
local toastDismissTime_ = 0       -- toast 自动消失的目标时刻
local TOAST_DURATION = 2.5        -- toast 显示秒数

local currentPage_ = 1  -- 1=第一页, 2=第二页

-- 槽位缓存（创建一次，后续只更新数据）
local whSlots_ = {}        -- [1..48] 仓库槽位 (ImageItemSlot)
local bagSlots_ = {}       -- [1..BACKPACK_SIZE] 背包槽位
local whGrid_ = nil        -- 仓库网格面板
local bagGrid_ = nil       -- 背包网格面板
local whTitleLabel_ = nil  -- "📦 仓库 x/y" 标签
local bagTitleLabel_ = nil -- "🎒 背包 x/y" 标签

local contentBuilt_ = false
local lastUnlockedRows_ = 0  -- 上次构建时的解锁行数

-- ── P0-2: 本次打开期间是否有成功变更（用于 P0-3 关闭时触发保存） ──
local changedThisOpen_ = false
local lastCloseFlushTime_ = -999  -- 关闭保存防抖（初始 -999 确保第一次必触发）

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
    toastDismissTime_ = 0
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
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = T.color.info,
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.sm,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                children = {
                    UI.Label {
                        text = text,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = T.color.info,
                        textAlign = "center",
                    },
                },
            },
        },
    }
    if panel_ then
        panel_:AddChild(localToast_)
    end
    toastDismissTime_ = time.elapsedTime + TOAST_DURATION
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

    local unlockedSlots, totalSlots
    if currentPage_ == 1 then
        unlockedSlots = WarehouseSystem.GetUnlockedSlots()
        lastUnlockedRows_ = WarehouseSystem.GetUnlockedRows()
        totalSlots = WarehouseConfig.MAX_ROWS * COLS
    else
        unlockedSlots = WarehouseSystem.GetPage2UnlockedSlots()
        lastUnlockedRows_ = WarehouseSystem.GetPage2UnlockedRows and WarehouseSystem.GetPage2UnlockedRows() or 0
        totalSlots = WarehouseConfig.PAGE2_MAX_ROWS * COLS
    end

    whGrid_ = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = SLOT_GAP,
    }

    for idx = 1, totalSlots do
        local isLocked = idx > unlockedSlots
        if isLocked then
            local locked = UI.Panel {
                width = SLOT_SIZE,
                height = SLOT_SIZE,
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = T.color.border,
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
                        local ok, err
                        if currentPage_ == 1 then
                            ok, err = WarehouseSystem.RetrieveItem(capturedIdx)
                        else
                            ok, err = WarehouseSystem.RetrieveFromPage2(capturedIdx)
                        end
                        if ok then
                            changedThisOpen_ = true
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
                    local ok, err
                    if currentPage_ == 1 then
                        ok, err = WarehouseSystem.StoreItem(capturedIdx)
                    else
                        ok, err = WarehouseSystem.StoreItemToPage2(capturedIdx)
                    end
                    if ok then
                        changedThisOpen_ = true
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
    bagTitleLabel_ = nil
    contentBuilt_ = false
    lastUnlockedRows_ = 0
end

-- ============================================================================
-- 构建完整内容（仅 Show 时 / 解锁行时调用）
-- ============================================================================
BuildContent = function()
    -- ── 仓库标题行：[页签] [仓库 x/y] ... [整理] [解锁] 同一行 ──
    local rowChildren = {}

    -- 页面切换 Tab（第一页满解锁后显示）
    if WarehouseSystem.IsPage2Available() then
        rowChildren[#rowChildren + 1] = UI.Button {
            text = currentPage_ == 1 and "●一" or "○一",
            height = 24,
            paddingLeft = 4, paddingRight = 4,
            fontSize = T.fontSize.xxs,
            borderRadius = T.radius.sm,
            backgroundColor = currentPage_ == 1 and T.color.tabActiveBg or T.color.tabInactiveBg,
            fontColor = currentPage_ == 1 and T.color.tabActiveText or T.color.tabInactiveText,
            onClick = function(self)
                if currentPage_ ~= 1 then
                    currentPage_ = 1
                    DestroyContent()
                    BuildContent()
                    UpdateAllSlots()
                end
            end,
        }
        rowChildren[#rowChildren + 1] = UI.Button {
            text = currentPage_ == 2 and "●二" or "○二",
            height = 24,
            paddingLeft = 4, paddingRight = 4,
            fontSize = T.fontSize.xxs,
            borderRadius = T.radius.sm,
            backgroundColor = currentPage_ == 2 and T.color.tabActiveBg or T.color.tabInactiveBg,
            fontColor = currentPage_ == 2 and T.color.tabActiveText or T.color.tabInactiveText,
            onClick = function(self)
                if currentPage_ ~= 2 then
                    currentPage_ = 2
                    DestroyContent()
                    BuildContent()
                    UpdateAllSlots()
                end
            end,
        }
    end

    -- 仓库标题（缩小字号）
    whTitleLabel_ = UI.Label {
        text = "📦 0/0",
        fontSize = T.fontSize.sm,
        fontColor = T.color.titleText,
        flexGrow = 1, flexShrink = 1,
    }
    rowChildren[#rowChildren + 1] = whTitleLabel_

    -- 整理按钮
    rowChildren[#rowChildren + 1] = UI.Button {
        text = "整理",
        width = 48, height = 24,
        fontSize = T.fontSize.xxs, fontWeight = "bold",
        borderRadius = T.radius.sm,
        backgroundColor = T.color.btnSecondary,
        fontColor = T.color.btnSecondaryFg,
        onClick = function(self)
            local now = time.elapsedTime
            if now - lastSortTime_ < SORT_CD then
                ShowLocalToast("操作太快，请稍后再试")
                return
            end
            local ok, err
            if currentPage_ == 1 then
                ok, err = WarehouseSystem.SortWarehouse()
            else
                ok, err = WarehouseSystem.SortPage2()
            end
            if ok then
                changedThisOpen_ = true
                ShowLocalToast("仓库已整理")
                lastSortTime_ = now
            else
                ShowLocalToast(err or "整理失败")
            end
            UpdateAllSlots()
        end,
    }

    -- 解锁按钮
    rowChildren[#rowChildren + 1] = UI.Button {
        id = "wh_unlock_btn_content",
        text = "",
        height = 24,
        paddingLeft = T.spacing.xs, paddingRight = T.spacing.xs,
        fontSize = T.fontSize.xxs, fontWeight = "bold",
        borderRadius = T.radius.sm,
        backgroundColor = T.color.btnSpend,
        fontColor = T.color.btnSpendFg,
        onClick = function(self)
            local ok, err
            if currentPage_ == 1 then
                ok, err = WarehouseSystem.UnlockNextRow()
            else
                ok, err = WarehouseSystem.UnlockPage2NextRow()
            end
            if ok then
                changedThisOpen_ = true
                ShowLocalToast("解锁成功！")
            else
                ShowLocalToast(err or "解锁失败")
            end
            UpdateAllSlots()
        end,
    }

    outerPanel_:AddChild(UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center", gap = T.spacing.xs,
        children = rowChildren,
    })

    -- 仓库网格
    BuildWarehouseGrid()
    outerPanel_:AddChild(whGrid_)

    -- 分割线
    outerPanel_:AddChild(UI.Panel {
        width = "100%", height = 1,
        backgroundColor = T.color.borderLight,
        marginTop = T.spacing.xs, marginBottom = T.spacing.xs,
    })

    -- 背包标题（缩小字号）
    bagTitleLabel_ = UI.Label {
        text = "🎒 0/" .. GameConfig.BACKPACK_SIZE,
        fontSize = T.fontSize.sm,
        fontColor = T.color.titleText,
    }
    outerPanel_:AddChild(bagTitleLabel_)

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
    if currentPage_ == 1 then
        for idx = 1, WarehouseConfig.MAX_ROWS * COLS do
            local slot = whSlots_[idx]
            if slot then
                local item = WarehouseSystem.GetItem(idx)
                slot:SetItem(item)
            end
        end
    else
        for idx = 1, WarehouseConfig.PAGE2_MAX_ROWS * COLS do
            local slot = whSlots_[idx]
            if slot then
                local item = WarehouseSystem.GetPage2Item(idx)
                slot:SetItem(item)
            end
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

    -- 仓库标题（物品数/总空间）
    if whTitleLabel_ then
        local itemCount, totalSlots
        if currentPage_ == 1 then
            itemCount = WarehouseSystem.GetItemCount()
            totalSlots = WarehouseSystem.GetUnlockedSlots()
        else
            itemCount = WarehouseSystem.GetPage2ItemCount and WarehouseSystem.GetPage2ItemCount() or 0
            totalSlots = WarehouseSystem.GetPage2UnlockedSlots()
        end
        whTitleLabel_:SetText("📦 " .. itemCount .. "/" .. totalSlots)
    end

    -- 背包标题（物品数/总空间）
    if bagTitleLabel_ then
        local InventorySystem = require("systems.InventorySystem")
        local bagUsed = GameConfig.BACKPACK_SIZE - InventorySystem.GetFreeSlots()
        bagTitleLabel_:SetText("🎒 " .. bagUsed .. "/" .. GameConfig.BACKPACK_SIZE)
    end

    -- 解锁按钮
    local unlockedRows, maxRows, getCost, getRowFn
    if currentPage_ == 1 then
        unlockedRows = WarehouseSystem.GetUnlockedRows()
        maxRows = WarehouseConfig.MAX_ROWS
        getCost = function(r) return WarehouseConfig.GetRowCost(r) end
    else
        unlockedRows = WarehouseSystem.GetPage2UnlockedRows and WarehouseSystem.GetPage2UnlockedRows() or 0
        maxRows = WarehouseConfig.PAGE2_MAX_ROWS
        getCost = function(r) return WarehouseConfig.GetPage2RowCost and WarehouseConfig.GetPage2RowCost(r) or 0 end
    end

    local unlockBtnRef = panel_ and panel_:FindById("wh_unlock_btn_content")
    if unlockBtnRef then
        if unlockedRows < maxRows then
            local nextRow = unlockedRows + 1
            local cost = getCost(nextRow)
            unlockBtnRef:SetText("🔓 解锁第" .. nextRow .. "排（" .. WarehouseSystem.FormatGold(cost) .. "）")
            unlockBtnRef:SetVisible(true)
        else
            unlockBtnRef:SetVisible(false)
        end
    end

    -- 如果解锁行数变了，需要重建整个内容（解锁操作极少，可接受）
    local currentUnlockedRows
    if currentPage_ == 1 then
        currentUnlockedRows = WarehouseSystem.GetUnlockedRows()
    else
        currentUnlockedRows = WarehouseSystem.GetPage2UnlockedRows and WarehouseSystem.GetPage2UnlockedRows() or 0
    end
    if currentUnlockedRows ~= lastUnlockedRows_ and outerPanel_ then
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

    local portraitPanel = UI.Panel {
        width = 64, height = 64,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        backgroundImage = "image/warehouse_chest_20260331104459.png",
        backgroundFit = "cover",
        overflow = "hidden",
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
        padding = T.spacing.md,
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
        backgroundColor = T.color.overlay,
        zIndex = 900,
        visible = false,
        onClick = function(self)
            WarehouseUI.Hide()
        end,
        children = {
            UI.Panel {
                width = panelW,
                maxHeight = "80%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = T.color.goldDark,
                flexDirection = "column",
                onClick = function(self) end,
                children = {
                    -- ── Header ──
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        paddingLeft = T.spacing.md,
                        paddingRight = T.spacing.md,
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.sm,
                        borderBottomWidth = 1,
                        borderColor = T.color.goldDark,
                        children = {
                            portraitPanel,
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                marginLeft = T.spacing.sm,
                                gap = T.spacing.xxs,
                                children = {
                                    UI.Label { text = "仓库", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.gold },
                                    UI.Label { text = "点击仓库物品取出，点击背包物品存入", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
                                },
                            },
                            -- 关闭按钮
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.sm,
                                backgroundColor = {255, 100, 100, 30},
                                fontColor = T.color.error,
                                marginLeft = T.spacing.xs,
                                onClick = function(self)
                                    WarehouseUI.Hide()
                                end,
                            },
                        },
                    },
                    -- ── 可滚动内容区 ──
                    scrollView_,
                    -- ── Footer ──
                    UI.Panel {
                        width = "100%",
                        alignItems = "center",
                        paddingTop = T.spacing.xs,
                        paddingBottom = T.spacing.sm,
                        borderTopWidth = 1,
                        borderColor = T.color.borderLight,
                        children = {
                            UI.Label { text = "点击空白处关闭", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
                        },
                    },
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

    currentPage_ = 1
    changedThisOpen_ = false  -- P0-2: 重置本次变更标记

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

    -- P0-3: 关闭仓库时如有变更，立即尝试保存一次（加速 game_saved 解除黑市门禁）
    print("[WarehouseUI] Hide: changedThisOpen_=" .. tostring(changedThisOpen_))
    if changedThisOpen_ then
        local now = time.elapsedTime
        if not lastCloseFlushTime_ or now - lastCloseFlushTime_ >= 3 then
            lastCloseFlushTime_ = now
            EventBus.Emit("save_request")
            local ok1, err1 = pcall(function()
                require("systems.save.SaveSession").Flush()
            end)
            if not ok1 then print("[WarehouseUI] Flush ERROR: " .. tostring(err1)) end
            local ok2, err2 = pcall(function()
                local SaveSystem = require("systems.SaveSystem")
                local ok, reason, status = SaveSystem.RequestImmediateSave("warehouse_close")
                print("[WarehouseUI] Close save request: ok=" .. tostring(ok)
                    .. " reason=" .. tostring(reason)
                    .. " saving=" .. tostring(status and status.saving)
                    .. " retry=" .. tostring(status and status.retryTimer)
                    .. " disconnected=" .. tostring(status and status.disconnected)
                    .. " hasConn=" .. tostring(status and status.hasServerConn))
            end)
            if not ok2 then print("[WarehouseUI] RequestImmediateSave ERROR: " .. tostring(err2)) end
        end
        changedThisOpen_ = false
    end

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


--- 每帧更新：toast 定时消失
---@param dt number
function WarehouseUI.Update(dt)
    if localToast_ and toastDismissTime_ > 0 then
        if time.elapsedTime >= toastDismissTime_ then
            DismissLocalToast()
        end
    end
end

function WarehouseUI.Destroy()
    WarehouseUI.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    outerPanel_ = nil

    parentOverlay_ = nil
end

-- ── P0-2: 订阅仓库变更事件，标记本次打开期间有成功操作 ──
EventBus.On("warehouse_changed", function()
    print("[WarehouseUI] warehouse_changed received! visible_=" .. tostring(visible_)
        .. " changedThisOpen_=" .. tostring(changedThisOpen_))
    if visible_ then
        changedThisOpen_ = true
    end
end)

return WarehouseUI
