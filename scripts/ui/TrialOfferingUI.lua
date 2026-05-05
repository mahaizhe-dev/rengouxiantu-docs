-- ============================================================================
-- TrialOfferingUI.lua - 青云试炼·每日供奉领取面板
-- 由青云使·云裳 NPC 触发，领取基于试炼等级的每日供奉
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local TrialTowerSystem = require("systems.TrialTowerSystem")
local TrialTowerConfig = require("config.TrialTowerConfig")
local SaveProtocol = require("network.SaveProtocol")

local TrialOfferingUI = {}

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil
local rewardListPopup_ = nil
local rewardListVisible_ = false
local claimBtn_ = nil         -- 领取按钮引用，供 S2C 回调更新
local claimingAt_ = 0         -- C2S 防抖时间戳（0=空闲）
local C2S_TIMEOUT = 10        -- 秒：C2S 请求超时自动解锁

--- 判断防抖是否生效（未超时返回 true）
---@param startTime number os.clock() 时间戳
---@return boolean
local function _isThrottled(startTime)
    return startTime > 0 and (os.clock() - startTime) < C2S_TIMEOUT
end

-- ============================================================================
-- 供奉档位列表（用于"查看所有供奉"）
-- ============================================================================

--- 生成所有供奉档位数据
---@return table[] tiers { {tier, floorReq, lingYun, goldBar}, ... }
local function GetAllTiers()
    local tiers = {}
    for i = 1, TrialTowerConfig.MAX_DAILY_TIER do
        local floorReq = i * 10
        local lingYun, goldBar = TrialTowerConfig.CalcDailyRewardByTier(i)
        local realmInfo = TrialTowerConfig.REALMS[i]
        local realmName = realmInfo and realmInfo.name or ("第" .. floorReq .. "层")
        table.insert(tiers, {
            tier = i,
            floorReq = floorReq,
            lingYun = lingYun,
            goldBar = goldBar,
            realmName = realmName,
        })
    end
    return tiers
end

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 构建供奉面板内容
---@param npc table
---@return table[] children
local function BuildOfferingPanel(npc)
    local npcName = npc.name or "青云使"
    local dialog = npc.dialog or "每日可领取青云城供奉。"
    local highestFloor = TrialTowerSystem.highestFloor or 0
    local tier, lingYun, goldBar = TrialTowerConfig.CalcDailyReward(highestFloor)
    local collected = TrialTowerSystem.IsDailyCollected()
    local unlocked = highestFloor >= TrialTowerConfig.DAILY_UNLOCK_FLOOR

    -- 领取按钮
    local btnText, btnColor, btnDisabled
    local claimed = TrialTowerSystem.dailyClaimedTier
    if not unlocked then
        btnText = "通关第10层解锁供奉"
        btnColor = {80, 80, 90, 200}
        btnDisabled = true
    elseif collected then
        btnText = "今日已领取 ✅"
        btnColor = {80, 80, 90, 200}
        btnDisabled = true
    elseif claimed < tier then
        -- 里程碑：显示下一档
        local nextTier = claimed + 1
        local nLY, nGB = TrialTowerConfig.CalcDailyRewardByTier(nextTier)
        local remaining = tier - claimed
        btnText = "领取第" .. nextTier .. "档（灵韵×" .. nLY .. " 金条×" .. nGB .. "）"
        if remaining > 1 then
            btnText = btnText .. "  余" .. remaining .. "档"
        end
        btnColor = {180, 130, 40, 240}
        btnDisabled = false
    else
        -- 每日重复领取最高档
        btnText = "领取供奉（灵韵×" .. lingYun .. " 金条×" .. goldBar .. "）"
        btnColor = {180, 130, 40, 240}
        btnDisabled = false
    end

    -- 当前档位描述
    local statusText
    if not unlocked then
        statusText = "当前试炼进度：第 " .. highestFloor .. " 层\n通关第 10 层后解锁每日供奉"
    else
        local realmInfo = TrialTowerConfig.REALMS[tier]
        local realmName = realmInfo and realmInfo.name or ("第" .. tier .. "档")
        statusText = "当前试炼进度：第 " .. highestFloor .. " 层\n"
            .. "供奉档位：" .. realmName .. "（第" .. tier .. "档）\n"
            .. "每日可领：灵韵×" .. lingYun .. "  金条×" .. goldBar
    end

    local children = {
        -- 标题
        UI.Label {
            text = npcName,
            fontSize = T.fontSize.lg,
            fontWeight = "bold",
            fontColor = T.color.titleText,
            textAlign = "center",
            width = "100%",
        },
        UI.Panel { width = "100%", height = 1, backgroundColor = {80, 90, 110, 100} },
        -- NPC 对白
        UI.Label {
            text = dialog,
            fontSize = T.fontSize.sm,
            fontColor = {210, 210, 220, 240},
            lineHeight = 1.5,
        },
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60} },
        -- 当前状态
        UI.Label {
            text = statusText,
            fontSize = T.fontSize.sm,
            fontColor = unlocked and {255, 230, 160, 240} or {170, 170, 190, 220},
            lineHeight = 1.5,
        },
        -- 领取按钮（发送 C2S 请求，由服务端校验）
        UI.Button {
            id = "trial_claim_btn",
            text = btnText,
            width = "100%",
            height = T.size.dialogBtnH,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            borderRadius = T.radius.md,
            backgroundColor = btnColor,
            onClick = btnDisabled and nil or function(self)
                if _isThrottled(claimingAt_) then return end
                claimingAt_ = os.clock()
                claimBtn_ = self
                -- ③ 立即禁用按钮，阻止重复点击
                self:SetDisabled(true)
                self:SetText("领取中...")
                self:SetStyle({ backgroundColor = {100, 100, 110, 200} })

                -- 发送 C2S 请求到服务端
                local serverConn = network:GetServerConnection()
                if serverConn then
                    serverConn:SendRemoteEvent(SaveProtocol.C2S_TrialClaimDaily, true, VariantMap())
                else
                    claimingAt_ = 0
                    self:SetDisabled(false)
                    self:SetText("网络未连接")
                    self:SetStyle({ backgroundColor = {80, 80, 90, 200} })
                end
            end,
        },
        -- 查看所有供奉档位（小按钮，打开独立弹窗）
        UI.Button {
            text = "📋 规则",
            width = 70,
            height = 28,
            fontSize = T.fontSize.xs,
            borderRadius = T.radius.sm,
            backgroundColor = {50, 60, 80, 200},
            borderWidth = 1,
            borderColor = {120, 140, 180, 80},
            alignSelf = "flex-end",
            onClick = function(self)
                TrialOfferingUI.ShowRewardListPopup()
            end,
        },
    }

    return children
end

--- 构建奖励列表内容（供弹窗使用，更宽更完整）
---@return table[] rows
local function BuildRewardListRows()
    local allTiers = GetAllTiers()
    local highestFloor = TrialTowerSystem.highestFloor or 0
    local currentTier = math.floor(highestFloor / 10)

    local rows = {}
    -- 表头
    table.insert(rows, UI.Panel {
        flexDirection = "row",
        width = "100%",
        gap = T.spacing.sm,
        paddingBottom = T.spacing.xs,
        borderBottomWidth = 1,
        borderColor = {100, 120, 160, 100},
        children = {
            UI.Label { text = "档位", width = 80, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {160, 180, 220, 240} },
            UI.Label { text = "通关要求", width = 80, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {160, 180, 220, 240} },
            UI.Label { text = "灵韵/日", width = 65, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {160, 180, 220, 240} },
            UI.Label { text = "金条/日", width = 65, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {160, 180, 220, 240} },
        },
    })

    for _, t in ipairs(allTiers) do
        local isCurrent = t.tier == currentTier
        local isReached = t.tier <= currentTier
        local rowColor = isCurrent and {255, 220, 100, 255}
            or isReached and {180, 220, 180, 230}
            or {130, 130, 140, 180}
        local bgColor = isCurrent and {80, 70, 20, 140} or {0, 0, 0, 0}
        local prefix = isCurrent and "▶ " or "  "

        table.insert(rows, UI.Panel {
            flexDirection = "row",
            width = "100%",
            gap = T.spacing.sm,
            backgroundColor = bgColor,
            borderRadius = isCurrent and T.radius.sm or 0,
            paddingTop = 3, paddingBottom = 3,
            paddingLeft = 4, paddingRight = 4,
            children = {
                UI.Label { text = prefix .. t.realmName, width = 80, fontSize = T.fontSize.sm, fontColor = rowColor },
                UI.Label { text = t.floorReq .. "层", width = 80, fontSize = T.fontSize.sm, fontColor = rowColor },
                UI.Label { text = tostring(t.lingYun), width = 65, fontSize = T.fontSize.sm, fontColor = rowColor },
                UI.Label { text = tostring(t.goldBar), width = 65, fontSize = T.fontSize.sm, fontColor = rowColor },
            },
        })
    end

    return rows
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 初始化
---@param parentOverlay table
function TrialOfferingUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    -- 订阅 S2C 回调
    SubscribeToEvent(SaveProtocol.S2C_TrialClaimDailyResult, "TrialOfferingUI_HandleClaimResult")
end

--- S2C 回调：服务端返回领取结果
function TrialOfferingUI_HandleClaimResult(eventType, eventData)
    claimingAt_ = 0

    local ok = eventData["ok"]:GetBool()

    if ok then
        local lingYun = eventData["lingYun"]:GetInt()
        local goldBar = eventData["goldBar"]:GetInt()
        local claimedTier = eventData["claimedTier"]:GetInt()
        local serverDate = eventData["serverDate"]:GetString()

        -- 更新客户端状态（使用服务端返回的权威数据）
        TrialTowerSystem.dailyClaimedTier = claimedTier
        if serverDate ~= "" then
            TrialTowerSystem.dailyDate = serverDate
        end

        -- 发放奖励到客户端
        TrialTowerSystem._grantReward(lingYun, goldBar)

        -- 刷新小地图每日面板
        local Minimap = require("ui.Minimap")
        if Minimap.UpdateDaily then Minimap.UpdateDaily() end

        -- 更新按钮状态
        if claimBtn_ then
            local curTier = TrialTowerConfig.GetDailyTier(TrialTowerSystem.highestFloor)
            local newClaimed = TrialTowerSystem.dailyClaimedTier
            if TrialTowerSystem.IsDailyCollected() then
                -- 今日已领完：保持禁用
                claimBtn_:SetText("今日已领取 ✅")
                claimBtn_:SetStyle({ backgroundColor = {80, 80, 90, 200} })
                -- SetDisabled(true) 已在点击时设置，此处保持
            elseif newClaimed < curTier then
                -- 还有里程碑档位：恢复可点击
                local nxt = newClaimed + 1
                local nLY, nGB = TrialTowerConfig.CalcDailyRewardByTier(nxt)
                local rem = curTier - newClaimed
                local t = "领取第" .. nxt .. "档（灵韵×" .. nLY .. " 金条×" .. nGB .. "）"
                if rem > 1 then t = t .. "  余" .. rem .. "档" end
                claimBtn_:SetText(t)
                claimBtn_:SetStyle({ backgroundColor = {180, 130, 40, 240} })
                claimBtn_:SetDisabled(false)
            end
        end

        print("[TrialOfferingUI] Claim OK: tier=" .. claimedTier
            .. " lingYun=" .. lingYun .. " goldBar=" .. goldBar)
    else
        local msg = eventData["msg"]:GetString()
        if msg == "" then msg = "领取失败" end

        if claimBtn_ then
            if msg == "今日已领取" then
                -- 服务端确认今日已领：保持禁用
                claimBtn_:SetText("今日已领取 ✅")
                claimBtn_:SetStyle({ backgroundColor = {80, 80, 90, 200} })
            else
                -- 其他失败（网络错误等）：恢复可点击
                claimBtn_:SetText(msg)
                claimBtn_:SetStyle({ backgroundColor = {80, 80, 90, 200} })
                claimBtn_:SetDisabled(false)
            end
        end

        print("[TrialOfferingUI] Claim FAILED: " .. msg)
    end
end

--- 显示供奉面板
---@param npc table
function TrialOfferingUI.Show(npc)
    if visible_ then TrialOfferingUI.Hide() end
    if not parentOverlay_ then return end

    rewardListVisible_ = false
    rewardListPanel_ = nil

    local contentChildren = BuildOfferingPanel(npc)

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 900,
        onClick = function(self) TrialOfferingUI.Hide() end,
        children = {
            UI.Panel {
                id = "trial_offering_content",
                width = 340,
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {180, 150, 80, 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function(self) end,  -- 阻止冒泡
                children = contentChildren,
            },
        },
    }

    parentOverlay_:AddChild(panel_)
    visible_ = true
end

--- 显示供奉档位弹窗（独立的全屏遮罩弹窗，更宽）
function TrialOfferingUI.ShowRewardListPopup()
    if rewardListVisible_ then
        TrialOfferingUI.HideRewardListPopup()
        return
    end
    if not parentOverlay_ then return end

    local rows = BuildRewardListRows()

    rewardListPopup_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 950,
        onClick = function(self) TrialOfferingUI.HideRewardListPopup() end,
        children = {
            UI.Panel {
                width = 380,
                maxHeight = "80%",
                backgroundColor = {25, 28, 40, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {140, 160, 200, 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.sm,
                onClick = function(self) end,  -- 阻止冒泡
                children = {
                    -- 标题
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        width = "100%",
                        children = {
                            UI.Label {
                                text = "📋 供奉档位一览",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = {255, 220, 130, 255},
                            },
                            UI.Button {
                                text = "✕",
                                width = 28, height = 28,
                                fontSize = T.fontSize.sm,
                                borderRadius = T.radius.sm,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function() TrialOfferingUI.HideRewardListPopup() end,
                            },
                        },
                    },
                    -- 说明
                    UI.Label {
                        text = "通关试炼对应层数后解锁更高档位，每日可领一次",
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 160, 180, 180},
                        lineHeight = 1.3,
                    },
                    UI.Panel { width = "100%", height = 1, backgroundColor = {100, 120, 160, 60} },
                    -- 列表（可滚动）
                    UI.Panel {
                        width = "100%",
                        maxHeight = 340,
                        overflow = "scroll",
                        gap = 2,
                        children = rows,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(rewardListPopup_)
    rewardListVisible_ = true
end

--- 隐藏供奉档位弹窗
function TrialOfferingUI.HideRewardListPopup()
    if rewardListPopup_ then
        rewardListPopup_:Destroy()
        rewardListPopup_ = nil
    end
    rewardListVisible_ = false
end

--- 隐藏面板
function TrialOfferingUI.Hide()
    TrialOfferingUI.HideRewardListPopup()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    visible_ = false
end

--- 是否可见
---@return boolean
function TrialOfferingUI.IsVisible()
    return visible_
end

--- 销毁
function TrialOfferingUI.Destroy()
    TrialOfferingUI.Hide()
    parentOverlay_ = nil
end

return TrialOfferingUI
