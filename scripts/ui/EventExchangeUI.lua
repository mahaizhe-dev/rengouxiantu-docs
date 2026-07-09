-- ============================================================================
-- EventExchangeUI.lua — 端午活动面板·主控（PanelShell + Tab 调度）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: PanelShell骨架 | Token化配色 | 三Tab调度(开启/任务/排行) | 弹窗队列
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local GameConfig = require("config.GameConfig")
local EventConfig = require("config.EventConfig")
local EventSystem = require("systems.EventSystem")
local InventorySystem = require("systems.InventorySystem")
local FormatUtils = require("utils.FormatUtils")
local SaveProtocol = require("network.SaveProtocol")
local IconUtils = require("utils.IconUtils")
local PanelShell = require("ui.components.PanelShell")
local cjson = cjson or require("cjson") ---@diagnostic disable-line: undefined-global

local EventExchangeUI = {}

-- ============================================================================
-- 常量
-- ============================================================================

local PORTRAIT_SIZE = 128
local TAB_NAMES = { "开启", "任务", "排行" }
local TAB_KEYS  = { "fudai", "milestone", "rank" }

-- ============================================================================
-- 状态（共享给 Tab 模块通过 getState()）
-- ============================================================================

local shell_ = nil
local visible_ = false
local parentOverlay_ = nil

-- 当前页签
local activeTab_ = "fudai"

-- UI 引用
local tabContent_ = nil   -- Tab 切页内容容器
local tabButtons_ = {}
local statusLabel_ = nil
local statusKeepUntil_ = 0

-- 服务端数据
local rankList_ = {}
local selfRank_ = nil
local selfScore_ = 0
local rankTotal_ = 0
local pullRecords_ = {}
local localPendingRecords_ = {}
local fudaiResults_ = {}

-- 里程碑数据
local milestoneBossKills_ = 0
local milestoneClaimed_ = {}
local milestoneEventId_ = ""

-- 防重复请求
local pendingRequest_ = false

-- 节流
local THROTTLE_INTERVAL = 0.5
local lastSendTime_ = -1

-- 奖池弹窗状态
local showPoolPopup_ = nil

-- 皮肤/大奖弹窗
local skinPopup_ = nil
local popupQueue_ = {}

-- ============================================================================
-- getState() — Tab 模块通过此函数访问共享可变状态
-- ============================================================================

local function GetState()
    return {
        pendingRequest = pendingRequest_,
        fudaiResults = fudaiResults_,
        pullRecords = pullRecords_,
        localPendingRecords = localPendingRecords_,
        showPoolPopup = showPoolPopup_,
        rankList = rankList_,
        selfRank = selfRank_,
        selfScore = selfScore_,
        rankTotal = rankTotal_,
        milestoneBossKills = milestoneBossKills_,
        milestoneClaimed = milestoneClaimed_,
        milestoneEventId = milestoneEventId_,
        -- Tab 模块可写回的字段（通过引用修改）
        setPending = function(v) pendingRequest_ = v end,
        setShowPoolPopup = function(v) showPoolPopup_ = v end,
        setFudaiResults = function(v) fudaiResults_ = v end,
    }
end

-- ============================================================================
-- 网络发送
-- ============================================================================

local function SendToServer(eventName, fields)
    local NetworkStatus = require("network.NetworkStatus")
    if NetworkStatus.IsDisconnected() then
        print("[EventExchangeUI] Blocked by sustained disconnect: " .. eventName)
        return false
    end

    local now = time.elapsedTime
    if now - lastSendTime_ < THROTTLE_INTERVAL then
        print("[EventExchangeUI] Throttled: " .. eventName)
        return false
    end
    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[EventExchangeUI] No server connection")
        return false
    end
    local data = VariantMap()
    if fields then
        for k, v in pairs(fields) do
            if type(v) == "string" then
                data[k] = Variant(v)
            elseif type(v) == "number" then
                if math.floor(v) == v then
                    data[k] = Variant(math.floor(v))
                else
                    data[k] = Variant(v)
                end
            elseif type(v) == "boolean" then
                data[k] = Variant(v)
            end
        end
    end
    serverConn:SendRemoteEvent(eventName, true, data)
    lastSendTime_ = time.elapsedTime
    print("[EventExchangeUI] SENT: " .. eventName)
    return true
end

-- ============================================================================
-- 状态提示
-- ============================================================================

local function SetStatus(text, keepSeconds)
    if statusLabel_ then
        statusLabel_:SetText(text)
    end
    statusKeepUntil_ = time.elapsedTime + (keepSeconds or 2.0)
end

-- ============================================================================
-- 弹窗队列
-- ============================================================================

local ShowNextSpecialPopup  -- forward declaration

--- 显示皮肤获得弹窗
local function ShowSkinUnlockPopup(skinId, isDuplicate)
    if skinPopup_ and parentOverlay_ then
        parentOverlay_:RemoveChild(skinPopup_)
        skinPopup_ = nil
    end
    if not parentOverlay_ then return end

    local PetAppearanceConfig = require("config.PetAppearanceConfig")
    local skinCfg = PetAppearanceConfig.byId and PetAppearanceConfig.byId[skinId]
    if not skinCfg then
        print("[EventExchangeUI] ShowSkinUnlockPopup: unknown skinId=" .. tostring(skinId))
        return
    end

    local BONUS_NAMES = {
        atkPct = "攻击", defPct = "防御", hpPct = "生命",
        fortune = "福缘", wisdom = "悟性", constitution = "根骨",
        physique = "体魄", moveSpeedPct = "移速",
    }
    local bonusText = ""
    if skinCfg.bonus then
        for k, v in pairs(skinCfg.bonus) do
            local name = BONUS_NAMES[k] or k
            if type(v) == "number" and v < 1 then
                bonusText = bonusText .. name .. "+" .. math.floor(v * 100) .. "%  "
            else
                bonusText = bonusText .. name .. "+" .. tostring(v) .. "  "
            end
        end
    end

    local titleText = isDuplicate and "再次获得皮肤" or "恭喜获得稀有皮肤！"
    local titleColor = isDuplicate and T.color.evtPopupSubtext or T.color.evtRarityLegendary
    local subtitleText = isDuplicate
        and "已拥有该皮肤，本次获得转化为 5000 灵韵奖励"
        or "已永久解锁，可在宠物外观中切换"

    skinPopup_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        zIndex = 200,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function() end,
        children = {
            UI.Panel {
                width = 360,
                backgroundColor = T.color.evtPopupBg,
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = isDuplicate and T.color.evtPopupBorderDim or T.color.evtPopupBorderGold,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = titleText,
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = titleColor,
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "80%", height = 1,
                        backgroundColor = T.color.evtPopupDivider,
                    },
                    UI.Panel {
                        backgroundImage = skinCfg.texture,
                        backgroundFit = "contain",
                        width = 160, height = 160,
                        borderRadius = T.radius.md,
                        backgroundColor = T.color.evtPopupSkinBg,
                    },
                    UI.Label {
                        text = skinCfg.name,
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.evtPopupSkinName,
                        textAlign = "center",
                    },
                    bonusText ~= "" and UI.Label {
                        text = "加成: " .. bonusText,
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.evtPopupBonusGreen,
                        textAlign = "center",
                    } or nil,
                    UI.Label {
                        text = subtitleText,
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.evtPopupSubtext,
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "确定",
                        width = 140, height = 38,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        backgroundColor = isDuplicate and T.color.btnSecondary or T.color.btnSpend,
                        fontColor = isDuplicate and T.color.btnSecondaryFg or T.color.btnSpendFg,
                        borderRadius = T.radius.md,
                        marginTop = T.spacing.sm,
                        onClick = function()
                            if skinPopup_ and parentOverlay_ then
                                parentOverlay_:RemoveChild(skinPopup_)
                                skinPopup_ = nil
                            end
                            ShowNextSpecialPopup()
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(skinPopup_)
    print("[EventExchangeUI] ShowSkinUnlockPopup: " .. skinCfg.name .. (isDuplicate and " (duplicate)" or " (new)"))
end

--- 显示传说物品获得弹窗
local function ShowLegendaryItemPopup(itemName, rewardId)
    if skinPopup_ and parentOverlay_ then
        parentOverlay_:RemoveChild(skinPopup_)
        skinPopup_ = nil
    end
    if not parentOverlay_ then return end

    local descText = "活动传说奖励，可在背包中查看详情。"

    skinPopup_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        zIndex = 200,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function() end,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = T.color.evtPopupBg,
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = T.color.evtPopupBorderGold,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "🎉",
                        fontSize = 40,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "恭喜获得传说物品！",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.evtRarityLegendary,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = itemName,
                        fontSize = T.fontSize.md + 2,
                        fontWeight = "bold",
                        fontColor = T.color.evtPopupItemName,
                        textAlign = "center",
                        marginTop = T.spacing.xs,
                    },
                    UI.Label {
                        text = descText,
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.evtPopupItemDesc,
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "太棒了！",
                        width = 120, height = 36,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        backgroundColor = T.color.btnSpend,
                        fontColor = T.color.btnSpendFg,
                        borderRadius = T.radius.md,
                        marginTop = T.spacing.sm,
                        onClick = function()
                            if skinPopup_ and parentOverlay_ then
                                parentOverlay_:RemoveChild(skinPopup_)
                                skinPopup_ = nil
                            end
                            ShowNextSpecialPopup()
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(skinPopup_)
    print("[EventExchangeUI] ShowLegendaryItemPopup: " .. itemName .. " (" .. tostring(rewardId) .. ")")
end

--- 弹窗队列驱动
ShowNextSpecialPopup = function()
    if #popupQueue_ == 0 then return end
    local entry = table.remove(popupQueue_, 1)
    if entry.kind == "skin_new" then
        local PetSkinSystem = require("systems.PetSkinSystem")
        PetSkinSystem.UnlockPremiumSkin(entry.skinId)
        ShowSkinUnlockPopup(entry.skinId, false)
    elseif entry.kind == "skin_dup" then
        ShowSkinUnlockPopup(entry.skinId, true)
    elseif entry.kind == "legendary_item" then
        ShowLegendaryItemPopup(entry.name or entry.rewardId or "传说物品", entry.rewardId)
    end
end

-- ============================================================================
-- Tab 调度
-- ============================================================================

local function RebuildContent()
    if not tabContent_ then return end
    tabContent_:ClearChildren()

    local buildOpts = {
        sendToServer = SendToServer,
        setStatus = SetStatus,
        rebuildContent = RebuildContent,
        getState = GetState,
    }

    if activeTab_ == "fudai" then
        local FudaiTab = require("ui.EventFudaiTab")
        FudaiTab.Build(tabContent_, buildOpts)
    elseif activeTab_ == "milestone" then
        local MilestoneTab = require("ui.EventMilestoneTab")
        MilestoneTab.Build(tabContent_, buildOpts)
    elseif activeTab_ == "rank" then
        local RankTab = require("ui.EventRankTab")
        RankTab.Build(tabContent_, buildOpts)
    end
end

local function SwitchTab(tabKey)
    activeTab_ = tabKey
    for i, key in ipairs(TAB_KEYS) do
        if tabButtons_[i] then
            if key == tabKey then
                tabButtons_[i]:SetStyle({
                    backgroundColor = T.color.evtTabActiveBg,
                    fontColor = T.color.evtTabActiveFg,
                })
            else
                tabButtons_[i]:SetStyle({
                    backgroundColor = T.color.evtTabInactiveBg,
                    fontColor = T.color.evtTabInactiveFg,
                })
            end
        end
    end
    RebuildContent()
    if tabKey == "rank" then
        SendToServer(SaveProtocol.C2S_EventGetRankList)
    elseif tabKey == "fudai" then
        SendToServer(SaveProtocol.C2S_EventGetPullRecords)
    elseif tabKey == "milestone" then
        -- 查询完全基于服务端权威基线 + 客户端实时击杀，无需先存档（消除异步竞态）
        SendToServer(SaveProtocol.C2S_EventQueryBossMilestones, {
            [SaveProtocol.MS_F_ClientBossKills] = GameState.bossKills or 0,
        })
    end
end

-- ============================================================================
-- 公开接口
-- ============================================================================

function EventExchangeUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    SubscribeToEvent(SaveProtocol.S2C_EventExchangeResult, "EventExchangeUI_HandleExchangeResult")
    SubscribeToEvent(SaveProtocol.S2C_EventOpenFudaiResult, "EventExchangeUI_HandleFudaiResult")
    SubscribeToEvent(SaveProtocol.S2C_EventRankListData, "EventExchangeUI_HandleRankListData")
    SubscribeToEvent(SaveProtocol.S2C_EventPullRecordsData, "EventExchangeUI_HandlePullRecordsData")
    SubscribeToEvent(SaveProtocol.S2C_EventBossMilestonesData, "EventExchangeUI_HandleMilestonesData")
    SubscribeToEvent(SaveProtocol.S2C_EventBossMilestoneResult, "EventExchangeUI_HandleMilestoneResult")
end

function EventExchangeUI.Show(npc)
    if visible_ then return end
    if not parentOverlay_ then return end

    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return end

    -- 重置状态
    activeTab_ = "fudai"
    pendingRequest_ = false
    fudaiResults_ = {}
    tabButtons_ = {}
    showPoolPopup_ = nil

    -- NPC 信息
    local npcName = (npc and npc.name) or ev.npcName or "月老仙使"
    local npcSubtitle = (npc and npc.subtitle) or ev.npcSubtitle or "情人节活动宝箱"
    local npcDialog = (npc and npc.dialog) or ev.npcDialog
        or "情丝入世，月老赐缘。\n击败BOSS掉落同心红线开小宝箱，\n高境界BOSS还会掉落鸳鸯玉佩开大宝箱！"
    local npcPortrait = (npc and npc.portrait) or ev.npcPortrait or "Textures/npc_valentine_fairy.png"

    -- NPC 头像组件
    local portrait = UI.Panel {
        width = PORTRAIT_SIZE, height = PORTRAIT_SIZE,
        borderRadius = T.radius.lg,
        backgroundColor = T.color.evtNpcBg,
        backgroundImage = npcPortrait,
        backgroundFit = "contain",
    }

    -- 创建 PanelShell
    shell_ = PanelShell.Create({
        title = npcName,
        subtitle = npcSubtitle,
        portrait = portrait,
        onClose = function() EventExchangeUI.Hide() end,
        parent = parentOverlay_,
        maxHeight = "76%",
        zIndex = 115,
    })

    -- 页签按钮
    local tabBtnChildren = {}
    for i, name in ipairs(TAB_NAMES) do
        local tabKey = TAB_KEYS[i]
        local isActive = (tabKey == activeTab_)
        local btn = UI.Button {
            text = name,
            flexGrow = 1,
            height = 34,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            borderRadius = T.radius.sm,
            backgroundColor = isActive and T.color.evtTabActiveBg or T.color.evtTabInactiveBg,
            fontColor = isActive and T.color.evtTabActiveFg or T.color.evtTabInactiveFg,
            onClick = function()
                SwitchTab(tabKey)
            end,
        }
        tabButtons_[i] = btn
        table.insert(tabBtnChildren, btn)
    end

    -- 状态标签
    statusLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = T.color.evtStatusText,
        textAlign = "center",
        width = "100%",
        height = 16,
    }

    -- Tab 内容容器
    tabContent_ = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
    }

    -- S0.4 模式：固定区域（NPC对话 + TabBar + status）+ 切页内容
    shell_:AddContent(UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
        children = {
            -- NPC 对话区
            UI.Panel {
                width = "100%",
                gap = T.spacing.xxs,
                children = {
                    UI.Label {
                        text = npcDialog,
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.evtNpcDialog,
                        lineHeight = 1.3,
                    },
                },
            },
            -- 分隔线
            UI.Panel {
                width = "100%", height = 1,
                backgroundColor = T.color.evtDivider,
            },
            -- 页签栏
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = T.spacing.xs,
                children = tabBtnChildren,
            },
            -- 状态提示
            statusLabel_,
            -- 切页内容
            tabContent_,
        },
    })

    shell_:Show()
    visible_ = true

    RebuildContent()
    -- 初始加载：查询里程碑（服务端权威基线 + 客户端实时击杀，无需先存档）
    SendToServer(SaveProtocol.C2S_EventQueryBossMilestones, {
        [SaveProtocol.MS_F_ClientBossKills] = GameState.bossKills or 0,
    })

    print("[EventExchangeUI] Show")
end

function EventExchangeUI.Hide()
    -- 先关闭皮肤弹窗
    if skinPopup_ and parentOverlay_ then
        parentOverlay_:RemoveChild(skinPopup_)
        skinPopup_ = nil
    end
    if shell_ then
        shell_:Hide()
        -- PanelShell 挂在 parentOverlay_ 上，需要移除
        if parentOverlay_ and shell_.panel then
            parentOverlay_:RemoveChild(shell_.panel)
        end
        shell_ = nil
    end
    tabContent_ = nil
    statusLabel_ = nil
    tabButtons_ = {}
    visible_ = false
    pendingRequest_ = false
    print("[EventExchangeUI] Hide")
end

function EventExchangeUI.Destroy()
    EventExchangeUI.Hide()
    parentOverlay_ = nil
    rankList_ = {}
    selfRank_ = nil
    selfScore_ = 0
    rankTotal_ = 0
    pullRecords_ = {}
    fudaiResults_ = {}
end

function EventExchangeUI.IsVisible()
    return visible_
end

function EventExchangeUI.Update(dt)
    if statusLabel_ and time.elapsedTime > statusKeepUntil_ then
        statusLabel_:SetText("")
    end
end

-- 兼容旧调用
function EventExchangeUI._RebuildContent()
    RebuildContent()
end

-- ============================================================================
-- S2C 事件处理
-- ============================================================================

--- 兑换结果（保留接口兼容）
function EventExchangeUI.HandleExchangeResult(eventType, eventData)
    pendingRequest_ = false
    local success = eventData["ok"]:GetBool()
    if success then
        local exchangeId = eventData["ExchangeId"]:GetString()
        local usedCount = eventData["UsedCount"]:GetInt()
        EventSystem.SetExchangedCount(exchangeId, usedCount)
        SetStatus("兑换成功！", 3)

        local exchangeCfg = EventConfig.FindExchange(exchangeId)
        if exchangeCfg then
            for itemId, needCount in pairs(exchangeCfg.cost) do
                InventorySystem.ConsumeConsumable(itemId, needCount)
            end
        end

        local rewardJson = eventData["Reward"]:GetString()
        local reward = cjson.decode(rewardJson)
        if reward then
            if reward.type == "lingYun" then
                local player = GameState.player
                if player then
                    player.lingYun = (player.lingYun or 0) + reward.count
                end
            elseif reward.type == "consumable" then
                InventorySystem.AddConsumable(reward.id, reward.count or 1)
            end
        end

        local SavePersistence = require("systems.save.SavePersistence")
        SavePersistence.Save()
    else
        local errMsg = eventData["reason"]:GetString()
        SetStatus(errMsg or "兑换失败", 3)
    end
    if visible_ then
        RebuildContent()
    end
end

--- 宝箱开启结果
function EventExchangeUI.HandleFudaiResult(eventType, eventData)
    pendingRequest_ = false
    local success = eventData["ok"]:GetBool()
    if success then
        local resultsJson = eventData["Results"]:GetString()
        local results = cjson.decode(resultsJson)
        fudaiResults_ = results or {}

        local totalGold = eventData["TotalGold"]:GetInt()
        local totalLingYun = eventData["TotalLingYun"]:GetInt()
        local player = GameState.player
        if player then
            if totalGold > 0 then
                player.gold = (player.gold or 0) + totalGold
            end
            if totalLingYun > 0 then
                player.lingYun = (player.lingYun or 0) + totalLingYun
            end
        end

        -- 扣除已开启的开启物
        local openedCount = eventData["Count"]:GetInt()
        local boxType = eventData["BoxType"]:GetString()
        local ev = EventConfig.ACTIVE_EVENT
        if ev and ev.openBoxes and ev.openBoxes[boxType] then
            local itemId = ev.openBoxes[boxType].itemId
            if openedCount > 0 then
                InventorySystem.ConsumeConsumable(itemId, openedCount)
            end
        end

        -- 消耗品奖励
        local consumablesJson = eventData["Consumables"]:GetString()
        local consumables = cjson.decode(consumablesJson)
        if consumables then
            for cId, cCount in pairs(consumables) do
                InventorySystem.AddConsumable(cId, cCount)
            end
        end

        -- SpecialRewards 弹窗队列
        local specialRewardsJson = eventData["SpecialRewards"] and eventData["SpecialRewards"]:GetString() or "[]"
        local specialRewards = cjson.decode(specialRewardsJson) or {}

        -- 兼容旧协议
        if #specialRewards == 0 then
            local skinField = eventData["UnlockedSkinId"]
            local unlockedSkinId = skinField and skinField:GetString() or ""
            if unlockedSkinId and #unlockedSkinId > 0 then
                local isDup = false
                local cosmetics = GameState.accountCosmetics or {}
                if cosmetics.petAppearances and cosmetics.petAppearances[unlockedSkinId] then
                    isDup = true
                end
                specialRewards[#specialRewards + 1] = {
                    kind = isDup and "skin_dup" or "skin_new",
                    skinId = unlockedSkinId,
                    skinName = unlockedSkinId,
                    lingYun = isDup and 5000 or nil,
                }
            else
                local jackpotIds = (EventConfig.ACTIVE_EVENT and EventConfig.ACTIVE_EVENT.jackpotIds) or {}
                for _, r in ipairs(fudaiResults_) do
                    if r.id and jackpotIds[r.id] then
                        specialRewards[#specialRewards + 1] = {
                            kind = "legendary_item",
                            name = r.name,
                            rewardId = r.id,
                        }
                    end
                end
            end
        end

        -- 填充弹窗队列
        popupQueue_ = {}
        for _, sr in ipairs(specialRewards) do
            popupQueue_[#popupQueue_ + 1] = sr
        end
        if #popupQueue_ > 0 then
            SetStatus("恭喜获得大奖！", 5)
            ShowNextSpecialPopup()
        else
            local count = #fudaiResults_
            SetStatus("开启 " .. count .. " 个宝箱！", 4)
        end

        -- NewPullRecords 即时合并
        local newRecordsJson = eventData["NewPullRecords"] and eventData["NewPullRecords"]:GetString() or "[]"
        local newRecords = cjson.decode(newRecordsJson) or {}
        if #newRecords > 0 then
            local SaveState = require("systems.save.SaveState")
            local myCharName = SaveState._cachedCharName or "修仙者"
            for _, rec in ipairs(newRecords) do
                rec.displayName = myCharName
                rec.charName = myCharName
                table.insert(pullRecords_, 1, rec)
                localPendingRecords_[#localPendingRecords_ + 1] = rec
            end
            while #pullRecords_ > 50 do
                table.remove(pullRecords_)
            end
        end

        -- 保底进度更新
        local pityCountField = eventData["PityCount"]
        local pityThresholdField = eventData["PityThreshold"]
        if pityCountField and pityThresholdField then
            local pityCount = pityCountField:GetInt()
            EventSystem.UpdatePityCount(boxType, pityCount)
        end

        local SavePersistence = require("systems.save.SavePersistence")
        SavePersistence.Save()
        print("[EventExchangeUI] Fudai opened, triggered immediate save")
    else
        local reasonField = eventData["reason"]
        local errMsg = reasonField and reasonField:GetString() or "开启失败"
        SetStatus(errMsg, 3)
        fudaiResults_ = {}
    end
    if visible_ and activeTab_ == "fudai" then
        RebuildContent()
    end
end

--- 排行榜数据
function EventExchangeUI.HandleRankListData(eventType, eventData)
    local rankJson = eventData["RankList"]:GetString()
    local list = cjson.decode(rankJson) or {}
    rankList_ = list

    selfRank_ = nil
    selfScore_ = 0
    rankTotal_ = 0
    local selfRankRaw = eventData["MyRank"]:GetInt()
    if selfRankRaw > 0 then
        selfRank_ = selfRankRaw
    end
    selfScore_ = eventData["MyScore"]:GetInt()
    rankTotal_ = eventData["Total"]:GetInt()

    if visible_ and activeTab_ == "rank" then
        RebuildContent()
    end
end

--- 全服抽取记录
function EventExchangeUI.HandlePullRecordsData(eventType, eventData)
    local recordsJson = eventData["Records"]:GetString()
    local records = cjson.decode(recordsJson) or {}

    local now = os.time()
    local serverRecords = {}
    for _, r in ipairs(records) do
        if now - (r.ts or 0) < 86400 then
            serverRecords[#serverRecords + 1] = r
        end
    end

    -- 防竞态合并
    local serverKeys = {}
    for _, r in ipairs(serverRecords) do
        local key = r.recordKey or (tostring(r.ts or 0) .. "|" .. (r.name or ""))
        serverKeys[key] = true
    end

    local stillPending = {}
    local missingFromServer = {}
    for _, pr in ipairs(localPendingRecords_) do
        local key = pr.recordKey or (tostring(pr.ts or 0) .. "|" .. (pr.name or ""))
        if not serverKeys[key] then
            stillPending[#stillPending + 1] = pr
            missingFromServer[#missingFromServer + 1] = pr
        end
    end
    localPendingRecords_ = stillPending

    pullRecords_ = {}
    for _, r in ipairs(missingFromServer) do
        pullRecords_[#pullRecords_ + 1] = r
    end
    for _, r in ipairs(serverRecords) do
        pullRecords_[#pullRecords_ + 1] = r
    end
    while #pullRecords_ > 50 do
        table.remove(pullRecords_)
    end

    if visible_ and activeTab_ == "fudai" then
        RebuildContent()
    end
end

--- 查询里程碑数据返回
function EventExchangeUI.HandleMilestonesData(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    if ok then
        milestoneBossKills_ = eventData[SaveProtocol.MS_F_BossKills]:GetInt()
        milestoneEventId_ = eventData[SaveProtocol.MS_F_EventId]:GetString()
        local claimedJson = eventData[SaveProtocol.MS_F_Claimed]:GetString()
        milestoneClaimed_ = cjson.decode(claimedJson) or {}
        print("[EventExchangeUI] MilestonesData: kills=" .. milestoneBossKills_ .. " claimed=" .. claimedJson)
    else
        local reason = eventData["reason"] and eventData["reason"]:GetString() or "查询失败"
        SetStatus(reason, 3)
        print("[EventExchangeUI] MilestonesData error: " .. reason)
    end
    if visible_ and activeTab_ == "milestone" then
        RebuildContent()
    end
end

--- 领取里程碑结果
function EventExchangeUI.HandleMilestoneResult(eventType, eventData)
    pendingRequest_ = false
    local ok = eventData["ok"]:GetBool()
    if ok then
        -- 统一字段名：服务端回包使用 Milestone（历史上误用 Target 导致 claimKey 永远为 "0"）
        local target = eventData[SaveProtocol.MS_F_Milestone]:GetInt()
        local claimKey = tostring(target)
        milestoneClaimed_[claimKey] = true

        local rewardsJson = eventData[SaveProtocol.MS_F_Rewards] and eventData[SaveProtocol.MS_F_Rewards]:GetString() or "[]"
        local rewards = cjson.decode(rewardsJson) or {}
        for _, rw in ipairs(rewards) do
            if rw.id and rw.count then
                InventorySystem.AddConsumable(rw.id, rw.count)
            end
        end

        SetStatus("领取成功！", 3)
        print("[EventExchangeUI] MilestoneClaimed: target=" .. target)
        -- 里程碑已领取状态由服务端独立 key 权威存储，客户端无需回写存档
    else
        local reason = eventData["reason"] and eventData["reason"]:GetString() or "领取失败"
        SetStatus(reason, 3)
        print("[EventExchangeUI] MilestoneClaim error: " .. reason)
    end
    if visible_ and activeTab_ == "milestone" then
        RebuildContent()
    end
end

-- ============================================================================
-- 全局转发函数（6个不可变接口）
-- ============================================================================
function EventExchangeUI_HandleExchangeResult(eventType, eventData)
    EventExchangeUI.HandleExchangeResult(eventType, eventData)
end
function EventExchangeUI_HandleFudaiResult(eventType, eventData)
    EventExchangeUI.HandleFudaiResult(eventType, eventData)
end
function EventExchangeUI_HandleRankListData(eventType, eventData)
    EventExchangeUI.HandleRankListData(eventType, eventData)
end
function EventExchangeUI_HandlePullRecordsData(eventType, eventData)
    EventExchangeUI.HandlePullRecordsData(eventType, eventData)
end
function EventExchangeUI_HandleMilestonesData(eventType, eventData)
    EventExchangeUI.HandleMilestonesData(eventType, eventData)
end
function EventExchangeUI_HandleMilestoneResult(eventType, eventData)
    EventExchangeUI.HandleMilestoneResult(eventType, eventData)
end

return EventExchangeUI
