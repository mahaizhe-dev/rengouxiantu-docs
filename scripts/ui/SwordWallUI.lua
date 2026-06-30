-- ============================================================================
-- SwordWallUI.lua - 剑气长城副本入口 + 积分商店 UI
-- 使用 PanelShell + ItemSlot 标准组件，符合项目 UI 规范
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local SwordWallUI = {}

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local PanelShell = require("ui.components.PanelShell")
local ItemSlot = require("ui.components.ItemSlot")
local SWC = require("config.SwordWallConfig")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local InventorySystem = require("systems.InventorySystem")
local SwordWallSystem = require("systems.SwordWallSystem")
local SaveProtocol = require("network.SaveProtocol")
local CombatSystem = require("systems.CombatSystem")
local Minimap = require("ui.Minimap")

local parentOverlay_ = nil
local entryShell_ = nil
local shopShell_ = nil
local shopBalance_ = 0
local shopBoughtCounts_ = {}  -- { [itemId] = bought_count } 限购商品已购次数
local gameMapRef_ = nil
local bannerLabel_ = nil
local bannerTimer_ = 0

--- 注入 gameMap 引用
function SwordWallUI.SetGameMap(gameMap)
    gameMapRef_ = gameMap
end

-- ============================================================================
-- 创建
-- ============================================================================

function SwordWallUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    SwordWallUI._createEntryPanel()
    SwordWallUI._createShopPanel()
    SwordWallUI._createBanner()
end

-- ============================================================================
-- 入口面板（道具图标 + 副本介绍）
-- ============================================================================

function SwordWallUI._createEntryPanel()
    entryShell_ = PanelShell.Create({
        title = "⚔️ 剑气长城",
        subtitle = "门票型多波挑战副本",
        onClose = function() SwordWallUI.HideEntry() end,
        parent = parentOverlay_,
    })
end

function SwordWallUI.Show()
    if not entryShell_ then return end
    entryShell_:ClearContent()

    local ticketCount = InventorySystem.CountConsumable(SWC.TICKET_ITEM_ID)
    local canEnter = ticketCount >= SWC.TICKET_COST
    local ticketCfg = GameConfig.CONSUMABLES[SWC.TICKET_ITEM_ID]
    local ticketName = ticketCfg and ticketCfg.name or "仙人精血"
    local ticketIcon = ticketCfg and ticketCfg.icon or nil

    -- 判断 icon 是否为图片路径（含 . 或 /）还是 emoji
    local ticketIsImage = ticketIcon and (ticketIcon:find("%.") or ticketIcon:find("/"))
    local ticketSlotIcon = ticketIsImage and ticketIcon or nil
    local ticketSlotEmoji = (not ticketIsImage) and (ticketIcon or "🩸") or nil

    -- 门票区域（图标 + 文字）
    entryShell_:AddContent(UI.Panel {
        width = "100%", flexDirection = "row", alignItems = "center", gap = T.spacing.sm,
        marginBottom = T.spacing.sm,
        children = {
            ItemSlot.Create({ icon = ticketSlotIcon, emoji = ticketSlotEmoji, quality = "red", size = 44 }),
            UI.Panel { gap = 2, children = {
                UI.Label { text = "消耗：" .. ticketName .. " ×" .. SWC.TICKET_COST,
                    fontSize = T.fontSize.sm, fontColor = T.color.textPrimary },
                UI.Label { text = "持有 " .. ticketCount .. " 个",
                    fontSize = T.fontSize.xs,
                    fontColor = canEnter and T.color.success or T.color.error },
            }},
        },
    })

    -- 副本介绍
    entryShell_:AddContent(UI.Panel {
        width = "100%", padding = T.spacing.sm,
        backgroundColor = {30, 25, 45, 150}, borderRadius = T.radius.sm,
        gap = 4, marginBottom = T.spacing.md,
        children = {
            UI.Label { text = "副本说明", fontSize = T.fontSize.sm, fontColor = T.color.gold },
            UI.Label { text = "• 3波魔劫怪物 + 最终BOSS", fontSize = T.fontSize.xs, fontColor = T.color.textSecondary },
            UI.Label { text = "• 击败全部后出现结算宝箱", fontSize = T.fontSize.xs, fontColor = T.color.textSecondary },
            UI.Label { text = "• 死亡/退出视为失败，不返还门票", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
        },
    })

    -- 奖励预览（图标 + 文字）
    entryShell_:AddContent(UI.Panel {
        width = "100%", flexDirection = "row", alignItems = "center", gap = T.spacing.sm,
        marginBottom = T.spacing.md,
        children = {
            ItemSlot.Create({ icon = "image/warehouse_chest_20260331104459.png", quality = "cyan", size = 44 }),
            UI.Panel { gap = 2, children = {
                UI.Label { text = "通关奖励", fontSize = T.fontSize.sm, fontColor = T.color.gold },
                UI.Label { text = "10~30 剑气积分 + T10 青色灵器", fontSize = T.fontSize.xs, fontColor = T.color.textSecondary },
                UI.Label { text = "30%概率获得仙缘套装件", fontSize = T.fontSize.xs, fontColor = {180, 130, 255, 255} },
            }},
        },
    })

    -- 按钮
    entryShell_:AddContent(UI.Button {
        text = canEnter and "⚔️ 进入剑气长城" or "⚔️ 仙人精血不足",
        width = "100%", height = 42,
        fontSize = T.fontSize.md, fontWeight = "bold",
        variant = canEnter and "primary" or "disabled",
        borderRadius = T.radius.md,
        disabled = not canEnter,
        onClick = function()
            SwordWallUI.HideEntry()
            SwordWallUI._doEnter()
        end,
    })

    entryShell_:AddContent(UI.Panel { height = T.spacing.xs })

    entryShell_:AddContent(UI.Button {
        text = "📜 剑气积分商店",
        width = "100%", height = 36,
        fontSize = T.fontSize.sm,
        variant = "secondary",
        borderRadius = T.radius.md,
        onClick = function()
            SwordWallUI.HideEntry()
            SwordWallUI.ShowShop()
        end,
    })

    entryShell_:Show()
end

function SwordWallUI.HideEntry()
    if entryShell_ then entryShell_:Hide() end
end

function SwordWallUI._doEnter()
    local gameMap = gameMapRef_
    if not gameMap then
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "地图加载异常", {255, 100, 100, 255}, 2.0)
        end
        return
    end
    local ok, err = SwordWallSystem.Enter(gameMap)
    if not ok then
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, err or "进入失败", {255, 100, 100, 255}, 2.0)
        end
    end
end

-- ============================================================================
-- 积分商店面板（参考装备商店，带图标）
-- ============================================================================

function SwordWallUI._createShopPanel()
    shopShell_ = PanelShell.Create({
        title = "⚔️ 剑气积分商店",
        subtitle = "使用剑气积分兑换物品",
        onClose = function() SwordWallUI.HideShop() end,
        parent = parentOverlay_,
        maxHeight = "82%",
    })
end

function SwordWallUI.ShowShop()
    if not shopShell_ then return end
    shopShell_:ClearContent()
    shopShell_:AddContent(UI.Label {
        text = "查询积分中...", fontSize = T.fontSize.sm, fontColor = T.color.textMuted, textAlign = "center",
    })
    shopShell_:Show()

    if network and network.serverConnection then
        local msg = VariantMap()
        network.serverConnection:SendRemoteEvent(SaveProtocol.C2S_SwordWallShopQuery, true, msg)
    else
        SwordWallUI._refreshShopContent(0)
    end
end

function SwordWallUI.HideShop()
    if shopShell_ then shopShell_:Hide() end
end

function SwordWallUI._refreshShopContent(balance)
    if not shopShell_ then return end
    shopShell_:ClearContent()

    -- 余额
    shopShell_:AddContent(UI.Panel {
        width = "100%", flexDirection = "row", alignItems = "center", gap = T.spacing.sm,
        marginBottom = T.spacing.sm,
        children = {
            UI.Label { text = "⚔️", fontSize = 20 },
            UI.Label { text = "剑气积分：" .. balance, fontSize = T.fontSize.md, fontColor = T.color.gold, fontWeight = "bold" },
        },
    })

    -- 背包空位校验
    local freeSlots = InventorySystem.GetFreeSlots()
    local bagFull = freeSlots < 1

    if bagFull then
        shopShell_:AddContent(UI.Label {
            text = "⚠️ 背包已满，无法兑换",
            fontSize = T.fontSize.xs, fontColor = T.color.error,
            marginBottom = T.spacing.xs,
        })
    end

    -- 商品列表
    for _, item in ipairs(SWC.SHOP) do
        local canBuy = balance >= item.price and not bagFull
        local rawIcon = item.icon or nil
        local iconPath = nil
        local emoji = nil

        if not rawIcon and item.consumableId then
            local cfg = GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[item.consumableId]
            if cfg then rawIcon = cfg.icon end
        end

        if rawIcon then
            -- 判断是图片路径（含.或/）还是emoji
            if rawIcon:find("%.") or rawIcon:find("/") then
                iconPath = rawIcon
            else
                emoji = rawIcon
            end
        else
            emoji = "📦"
        end

        local qualityStr = item.quality or "cyan"
        if not item.quality and item.itemType == "consumable" then qualityStr = "purple" end

        -- 限购显示
        local limitLabel = nil
        local limitExhausted = false
        if item.limit and item.limit > 0 then
            local bought = shopBoughtCounts_ and shopBoughtCounts_[item.id] or 0
            local remaining = item.limit - bought
            limitLabel = "限购 " .. remaining .. "/" .. item.limit
            if remaining <= 0 then
                canBuy = false
                limitExhausted = true
            end
        end

        shopShell_:AddContent(UI.Panel {
            width = "100%", height = 56, flexDirection = "row", alignItems = "center",
            paddingLeft = T.spacing.xs, paddingRight = T.spacing.xs,
            marginBottom = 3,
            backgroundColor = {30, 25, 40, 180}, borderRadius = T.radius.sm,
            children = {
                ItemSlot.Create({ icon = iconPath, emoji = emoji, quality = qualityStr, size = 44 }),
                UI.Panel { flex = 1, marginLeft = T.spacing.sm, gap = 2, children = {
                    UI.Label { text = item.name, fontSize = T.fontSize.sm, fontColor = T.color.textPrimary },
                    UI.Label { text = item.price .. " 积分" .. (limitLabel and ("  " .. limitLabel) or ""), fontSize = T.fontSize.xs,
                        fontColor = canBuy and T.color.gold or T.color.error },
                }},
                UI.Button {
                    text = limitExhausted and "已满" or "兑换",
                    width = 56, height = 28,
                    fontSize = T.fontSize.xs, borderRadius = T.radius.sm,
                    variant = canBuy and "primary" or "disabled",
                    disabled = not canBuy,
                    onClick = function() SwordWallUI._doBuy(item.id) end,
                },
            },
        })
    end
end

function SwordWallUI._doBuy(itemId)
    -- 实时校验背包空位（防止面板缓存过期）
    if InventorySystem.GetFreeSlots() < 1 then
        if shopShell_ then shopShell_:SetResult("背包已满，无法兑换", T.color.error) end
        return
    end
    if not network or not network.serverConnection then return end
    local msg = VariantMap()
    msg["itemId"] = Variant(itemId)
    network.serverConnection:SendRemoteEvent(SaveProtocol.C2S_SwordWallShopBuy, true, msg)
end

-- ============================================================================
-- 波次横幅警示
-- ============================================================================

function SwordWallUI._createBanner()
    bannerLabel_ = UI.Label {
        text = "",
        fontSize = 22,
        fontWeight = "bold",
        fontColor = {255, 220, 100, 255},
        textAlign = "center",
    }

    local bannerPanel = UI.Panel {
        id = "sw_wave_banner",
        position = "absolute",
        top = "18%", left = "10%", right = "10%",
        height = 48,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 180},
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = {200, 160, 60, 180},
        visible = false,
        zIndex = 90,
        children = { bannerLabel_ },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(bannerPanel)
    end

    SwordWallUI._bannerPanel = bannerPanel
end

--- 显示波次横幅
---@param text string
---@param duration number|nil 持续秒数（默认 2.5）
function SwordWallUI.ShowBanner(text, duration)
    if not SwordWallUI._bannerPanel then return end
    bannerLabel_:SetText(text)
    SwordWallUI._bannerPanel:Show()
    bannerTimer_ = duration or 2.5
end

--- 每帧更新横幅淡出
function SwordWallUI.UpdateBanner(dt)
    if bannerTimer_ <= 0 then return end
    bannerTimer_ = bannerTimer_ - dt
    if bannerTimer_ <= 0 then
        if SwordWallUI._bannerPanel then
            SwordWallUI._bannerPanel:Hide()
        end
    end
end

-- ============================================================================
-- 小地图宝箱标记
-- ============================================================================

function SwordWallUI.ShowChestOnMinimap()
    local pos = SWC.CHEST_POS
    Minimap.AddRipple(pos.x, pos.y, 255, 215, 0, "sw_chest")
end

function SwordWallUI.RemoveChestFromMinimap()
    Minimap.RemoveRipple("sw_chest")
end

-- ============================================================================
-- 奖励弹窗（通关结算展示）
-- ============================================================================

local rewardShell_ = nil

function SwordWallUI._createRewardPanel()
    if rewardShell_ then return end
    rewardShell_ = PanelShell.Create({
        title = "✨ 通关成功",
        subtitle = "剑气长城·魔劫已消",
        onClose = function() SwordWallUI.HideReward() end,
        parent = parentOverlay_,
        maxWidth = 300,
        footerHint = "点击确认返回",
    })
end

--- 显示加载态弹窗（点击宝箱后立即弹出，等待服务端响应）
function SwordWallUI.ShowRewardLoading()
    if not parentOverlay_ then return end
    if not rewardShell_ then SwordWallUI._createRewardPanel() end
    rewardShell_:ClearContent()

    rewardShell_:AddContent(UI.Panel {
        width = "100%", height = 80, justifyContent = "center", alignItems = "center",
        children = {
            UI.Label { text = "⏳ 结算中...", fontSize = T.fontSize.md, fontColor = T.color.gold, textAlign = "center" },
            UI.Label { text = "正在与服务器通信", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center", marginTop = T.spacing.xs },
        },
    })

    rewardShell_:Show()
end

--- 服务端超时通知（弹窗已显示，更新为超时状态 + 重试按钮）
function SwordWallUI.OnClaimTimeout()
    if not rewardShell_ then return end
    rewardShell_:ClearContent()

    rewardShell_:AddContent(UI.Panel {
        width = "100%", height = 60, justifyContent = "center", alignItems = "center",
        children = {
            UI.Label { text = "⚠️ 服务器响应超时", fontSize = T.fontSize.sm, fontColor = T.color.warning, textAlign = "center" },
            UI.Label { text = "可重试或通过传送阵退出", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center", marginTop = T.spacing.xs },
        },
    })

    rewardShell_:AddContent(UI.Panel { height = T.spacing.sm })

    rewardShell_:AddContent(UI.Button {
        text = "重试结算",
        width = "100%", height = 36,
        fontSize = T.fontSize.sm,
        variant = "primary",
        borderRadius = T.radius.md,
        onClick = function()
            local SWS = require("systems.SwordWallSystem")
            -- 重置为可重试状态
            SWS.chestOpened = false
            SWS.state = "chest_ready"
            if SWS.chestEntity then
                SWS.chestEntity.interactable = true
                SWS.chestEntity.icon = "📦"
                SWS.chestEntity.name = "结算宝箱"
                SWS.chestEntity.opened = false
            end
            SwordWallUI.HideReward()
        end,
    })

    rewardShell_:AddContent(UI.Panel { height = T.spacing.xs })

    rewardShell_:AddContent(UI.Button {
        text = "通过传送阵退出",
        width = "100%", height = 32,
        fontSize = T.fontSize.xs,
        variant = "secondary",
        borderRadius = T.radius.md,
        onClick = function()
            SwordWallUI.HideReward()
        end,
    })
end

--- 显示奖励弹窗（积分高亮 + 装备 tips 样式内嵌）
--- 由服务端成功响应后调用，覆盖加载态内容
---@param points number 剑气积分
---@param equipment table|nil 获得的装备
function SwordWallUI.ShowReward(points, equipment)
    if not parentOverlay_ then return end
    if not rewardShell_ then SwordWallUI._createRewardPanel() end
    rewardShell_:ClearContent()

    local StatNames = require("utils.StatNames")
    local EquipmentData = require("config.EquipmentData")
    local IconUtils = require("utils.IconUtils")

    -- ── 积分奖励（高亮金色）──
    rewardShell_:AddContent(UI.Panel {
        width = "100%", flexDirection = "row", alignItems = "center",
        padding = T.spacing.sm,
        backgroundColor = {60, 50, 20, 200},
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = {255, 200, 50, 180},
        marginBottom = T.spacing.sm,
        children = {
            UI.Label { text = "⚔️", fontSize = 24 },
            UI.Panel { marginLeft = T.spacing.sm, gap = 2, children = {
                UI.Label { text = "剑气积分", fontSize = T.fontSize.sm, fontColor = {255, 220, 100, 255} },
                UI.Label { text = "+" .. points, fontSize = 20, fontWeight = "bold", fontColor = {255, 215, 0, 255} },
            }},
        },
    })

    -- ── 装备 Tips 样式（内嵌）──
    if equipment then
        local qualityColor = {100, 220, 255, 255}
        local qCfg = GameConfig.QUALITY and GameConfig.QUALITY[equipment.quality]
        if qCfg and qCfg.color then qualityColor = qCfg.color end
        local qName = qCfg and qCfg.name or "灵器"
        local slotName = EquipmentData.SLOT_NAMES and EquipmentData.SLOT_NAMES[equipment.slot] or equipment.slot or ""
        local equipIcon = equipment.icon or nil
        local equipIsImage = equipIcon and (equipIcon:find("%.") or equipIcon:find("/"))

        local tipsChildren = {}

        -- 头部：图标 + 名称
        table.insert(tipsChildren, UI.Panel {
            width = "100%", flexDirection = "row", alignItems = "center", gap = T.spacing.sm,
            paddingBottom = T.spacing.xs,
            borderBottomWidth = 1, borderColor = {200, 200, 200, 30},
            children = {
                equipIsImage and UI.Panel {
                    width = 40, height = 40, borderRadius = T.radius.sm,
                    backgroundImage = equipIcon, backgroundFit = "contain",
                } or UI.Label { text = "🗡️", fontSize = 28 },
                UI.Panel { gap = 2, children = {
                    UI.Label { text = equipment.name or "灵器", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = qualityColor },
                    UI.Label { text = EquipmentData.GetTierDisplayName(equipment.tier or 10) .. "  [" .. qName .. "] " .. slotName,
                        fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
                }},
            },
        })

        -- 主属性区
        if equipment.mainStat then
            local mainRows = { UI.Label { text = "□ 主属性", fontSize = T.fontSize.xs, fontColor = T.color.textMuted } }
            for stat, val in pairs(equipment.mainStat) do
                local icon = StatNames.ICONS and StatNames.ICONS[stat] or "◆"
                table.insert(mainRows, UI.Panel {
                    width = "100%", flexDirection = "row", alignItems = "center",
                    children = {
                        UI.Label { text = icon .. " " .. (StatNames.NAMES[stat] or stat),
                            fontSize = T.fontSize.sm, fontColor = {255, 255, 255, 255}, flex = 1 },
                        UI.Label { text = "+" .. StatNames.FormatValue(stat, val),
                            fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = qualityColor },
                    },
                })
            end
            table.insert(tipsChildren, UI.Panel {
                width = "100%", padding = T.spacing.xs,
                backgroundColor = {qualityColor[1], qualityColor[2], qualityColor[3], 15},
                borderRadius = T.radius.sm, gap = 2, marginTop = T.spacing.xs,
                children = mainRows,
            })
        end

        -- 副属性区
        if equipment.subStats and #equipment.subStats > 0 then
            local subRows = { UI.Label { text = "□ 副属性", fontSize = T.fontSize.xs, fontColor = T.color.textMuted } }
            for _, sub in ipairs(equipment.subStats) do
                local icon = StatNames.ICONS and StatNames.ICONS[sub.stat] or "◇"
                table.insert(subRows, UI.Panel {
                    width = "100%", flexDirection = "row", alignItems = "center",
                    children = {
                        UI.Label { text = icon .. " " .. (sub.name or StatNames.NAMES[sub.stat] or sub.stat),
                            fontSize = T.fontSize.xs, fontColor = T.color.textSecondary, flex = 1 },
                        UI.Label { text = "+" .. StatNames.FormatValue(sub.stat, sub.value),
                            fontSize = T.fontSize.xs, fontColor = T.color.textPrimary },
                    },
                })
            end
            table.insert(tipsChildren, UI.Panel {
                width = "100%", gap = 2, marginTop = T.spacing.xs,
                children = subRows,
            })
        end

        -- 灵性属性区
        if equipment.spiritStat then
            local sp = equipment.spiritStat
            local icon = StatNames.ICONS and StatNames.ICONS[sp.stat] or "✦"
            table.insert(tipsChildren, UI.Panel {
                width = "100%", padding = T.spacing.xs,
                backgroundColor = {160, 120, 255, 15},
                borderRadius = T.radius.sm, gap = 2, marginTop = T.spacing.xs,
                children = {
                    UI.Label { text = "□ 灵性属性", fontSize = T.fontSize.xs, fontColor = {200, 160, 255, 255} },
                    UI.Panel {
                        width = "100%", flexDirection = "row", alignItems = "center",
                        children = {
                            UI.Label { text = icon .. " " .. (sp.name or StatNames.NAMES[sp.stat] or sp.stat),
                                fontSize = T.fontSize.sm, fontColor = {200, 160, 255, 255}, flex = 1 },
                            UI.Label { text = "+" .. StatNames.FormatValue(sp.stat, sp.value),
                                fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {200, 160, 255, 255} },
                        },
                    },
                },
            })
        end

        -- 套装信息
        if equipment.setId then
            local EquipmentData = require("config.EquipmentData")
            local setData = EquipmentData.SetBonuses and EquipmentData.SetBonuses[equipment.setId]
            local setDisplayName = setData and setData.name or equipment.setId
            table.insert(tipsChildren, UI.Label {
                text = "🔗 套装：" .. setDisplayName,
                fontSize = T.fontSize.xs, fontColor = T.color.equipTipSetName or {180, 130, 255, 255}, marginTop = T.spacing.xs,
            })
        end

        -- 组装 tips 面板
        rewardShell_:AddContent(UI.Panel {
            width = "100%",
            padding = T.spacing.sm,
            backgroundColor = {20, 25, 40, 220},
            borderRadius = T.radius.md,
            borderWidth = 1,
            borderColor = {qualityColor[1], qualityColor[2], qualityColor[3], 60},
            children = tipsChildren,
        })
    end

    rewardShell_:AddContent(UI.Panel { height = T.spacing.sm })
    rewardShell_:AddContent(UI.Button {
        text = "确认返回",
        width = "100%", height = 40,
        fontSize = T.fontSize.md, fontWeight = "bold",
        variant = "primary",
        borderRadius = T.radius.md,
        onClick = function()
            SwordWallUI.HideReward()
            local SWS = require("systems.SwordWallSystem")
            if SWS.IsActive() or SWS.state == "completed" then
                local gm = SWS._getGameMap() or gameMapRef_
                SWS._cleanup(gm)
                SWS._returnToEntry()
            end
        end,
    })

    rewardShell_:Show()
end

function SwordWallUI.HideReward()
    if rewardShell_ then rewardShell_:Hide() end
end

-- ============================================================================
-- 兼容
-- ============================================================================

function SwordWallUI.Hide()
    SwordWallUI.HideEntry()
    SwordWallUI.HideShop()
    SwordWallUI.HideReward()
end

-- ============================================================================
-- 服务端回调
-- ============================================================================

function SwordWallUI.OnShopDataReceived(balance)
    shopBalance_ = balance or 0
    SwordWallUI._refreshShopContent(shopBalance_)
end

function SwordWallUI.OnShopBuyResult(ok, itemId, balance, errMsg)
    if ok then
        shopBalance_ = balance
        -- 限购计数递增（客户端侧追踪，下次打开商店服务端会校正）
        shopBoughtCounts_[itemId] = (shopBoughtCounts_[itemId] or 0) + 1
        SwordWallUI._refreshShopContent(shopBalance_)
        if shopShell_ then shopShell_:SetResult("兑换成功！", T.color.success) end
    else
        if shopShell_ then shopShell_:SetResult(errMsg or "兑换失败", T.color.error) end
    end
end

function SwordWallUI.OnClaimResult(ok, points, equipJson, errMsg)
    if ok then
        local cjson = require("cjson")
        local equip = nil
        if equipJson and equipJson ~= "" then
            local decOk, decoded = pcall(cjson.decode, equipJson)
            if decOk then equip = decoded end
        end
        SwordWallSystem.OnClaimSuccess(points, equip)
        SwordWallUI.RemoveChestFromMinimap()
    else
        SwordWallSystem.OnClaimFailed(errMsg)
    end
end

-- ============================================================================
-- S2C 事件注册
-- ============================================================================

function SwordWallUI_HandleClaimResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local points = eventData["points"]:GetInt()
    local equipJson = eventData["equipment"]:GetString()
    local errMsg = eventData["error"]:GetString()
    SwordWallUI.OnClaimResult(ok, points, equipJson, errMsg)
end

function SwordWallUI_HandleShopData(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    if ok then
        local balance = eventData["balance"]:GetInt()
        -- 解析限购已购次数
        local boughtJson = nil
        pcall(function() boughtJson = eventData["boughtCounts"]:GetString() end)
        if boughtJson and boughtJson ~= "" then
            local cjson = require("cjson")
            local decOk, counts = pcall(cjson.decode, boughtJson)
            if decOk and counts then
                shopBoughtCounts_ = counts
            end
        end
        SwordWallUI.OnShopDataReceived(balance)
    end
end

function SwordWallUI_HandleShopBuyResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local itemId = eventData["itemId"]:GetString()
    local balance = eventData["balance"]:GetInt()
    local errMsg = eventData["error"]:GetString()

    -- 服务端返回的物品数据，客户端入库
    if ok then
        local rewardJson = eventData["reward"] and eventData["reward"]:GetString() or ""
        if rewardJson ~= "" then
            local cjson = require("cjson")
            local decOk, rewardItem = pcall(cjson.decode, rewardJson)
            if decOk and rewardItem then
                local InventorySystem = require("systems.InventorySystem")
                if rewardItem.type == "consumable" then
                    InventorySystem.AddConsumable(rewardItem.consumableId, rewardItem.count or 1)
                else
                    InventorySystem.AddItem(rewardItem)
                end
            end
        end
        -- R5 修复：购买成功入库后即时保存，防止断线/崩溃丢失物品
        local EventBus = require("core.EventBus")
        EventBus.Emit("save_request")
    end

    SwordWallUI.OnShopBuyResult(ok, itemId, balance, errMsg)
end

function SwordWallUI.RegisterEvents()
    SubscribeToEvent(SaveProtocol.S2C_SwordWallClaimResult, "SwordWallUI_HandleClaimResult")
    SubscribeToEvent(SaveProtocol.S2C_SwordWallShopData, "SwordWallUI_HandleShopData")
    SubscribeToEvent(SaveProtocol.S2C_SwordWallShopBuyResult, "SwordWallUI_HandleShopBuyResult")
    print("[SwordWallUI] S2C events registered")
end

return SwordWallUI
