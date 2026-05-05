-- ============================================================================
-- RedeemUI.lua - 兑换码输入弹窗（设置界面入口）
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local SaveProtocol = require("network.SaveProtocol")
local SaveSystem = require("systems.SaveSystem")

local RedeemUI = {}

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil
local inputRef_ = nil       -- TextInput 引用
local statusLabel_ = nil    -- 状态提示标签
local submitBtn_ = nil      -- 提交按钮
local pending_ = false      -- 请求中锁

-- ============================================================================
-- 奖励发放（客户端执行，服务端已授权）
-- ============================================================================

--- 解析并发放服务端授权的奖励
---@param rewards table 奖励列表 [{type, id?, amount?}, ...]
---@return string 发放摘要文本
local function ApplyRewards(rewards)
    local player = GameState.player
    if not player then return "角色未加载" end

    local summary = {}

    for _, reward in ipairs(rewards) do
        local rType = reward.type
        local amount = reward.amount or 0

        if rType == "gold" then
            player.gold = player.gold + amount
            table.insert(summary, "金币 +" .. amount)

        elseif rType == "lingYun" then
            player.lingYun = player.lingYun + amount
            table.insert(summary, "灵韵 +" .. amount)

        elseif rType == "title" then
            local ok1, TitleSystem = pcall(require, "systems.TitleSystem")
            if ok1 and TitleSystem then
                local titleId = reward.id
                if titleId and not TitleSystem.unlocked[titleId] then
                    TitleSystem.unlocked[titleId] = true
                    TitleSystem.RecalcBonuses()
                    local ok2, TitleData = pcall(require, "config.TitleData")
                    local titleName = titleId
                    if ok2 and TitleData and TitleData.TITLES[titleId] then
                        titleName = TitleData.TITLES[titleId].name or titleId
                    end
                    table.insert(summary, "称号「" .. titleName .. "」")
                else
                    table.insert(summary, "称号（已拥有）")
                end
            end

        elseif rType == "item" then
            local ok1, InventorySystem = pcall(require, "systems.InventorySystem")
            if ok1 and InventorySystem then
                local itemId = reward.id
                local count = amount > 0 and amount or 1
                InventorySystem.AddConsumable(itemId, count)
                table.insert(summary, (reward.name or itemId) .. " x" .. count)
            end

        else
            table.insert(summary, (reward.name or rType) .. " x" .. (amount > 0 and amount or 1))
        end
    end

    return #summary > 0 and table.concat(summary, "、") or "无奖励"
end

-- ============================================================================
-- 网络通信
-- ============================================================================

local function SendRedeemRequest(code)
    local serverConn = network:GetServerConnection()
    if not serverConn then
        statusLabel_:SetText("无服务器连接")
        statusLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        pending_ = false
        return
    end

    local data = VariantMap()
    data["code"] = Variant(code)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_RedeemCode, true, data)
end

-- ============================================================================
-- 服务端响应处理
-- ============================================================================

function RedeemUI_HandleRedeemResult(eventType, eventData)
    pending_ = false
    if submitBtn_ then
        submitBtn_:SetText("兑换")
        submitBtn_:SetStyle({ backgroundColor = {80, 130, 220, 255} })
    end

    local ok = eventData["ok"]:GetBool()
    local msg = eventData["msg"]:GetString()

    if ok then
        -- 兑换成功，发放奖励
        local rewardsJson = eventData["rewards"]:GetString()
        ---@diagnostic disable-next-line: undefined-global
        local cjson = cjson
        local parseOk, rewards = pcall(cjson.decode, rewardsJson)
        if parseOk and type(rewards) == "table" and #rewards > 0 then
            local summary = ApplyRewards(rewards)
            if statusLabel_ then
                statusLabel_:SetText("兑换成功!\n获得: " .. summary)
                statusLabel_:SetStyle({ fontColor = {100, 255, 150, 255} })
            end
        else
            if statusLabel_ then
                statusLabel_:SetText("兑换成功!")
                statusLabel_:SetStyle({ fontColor = {100, 255, 150, 255} })
            end
        end
        -- 服务端已将奖励写入存档，客户端无需 Save 和 Ack
        -- ApplyRewards 仅更新内存状态用于即时显示，下次存档同步时自然一致
        -- 清空输入框
        if inputRef_ then
            inputRef_:Clear()
        end
    else
        if statusLabel_ then
            statusLabel_:SetText(msg or "兑换失败")
            statusLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        end
    end
end

-- ============================================================================
-- UI 构建
-- ============================================================================

function RedeemUI.Destroy()
    if panel_ then
        panel_:Remove()
        panel_ = nil
    end
    inputRef_ = nil
    statusLabel_ = nil
    submitBtn_ = nil
    visible_ = false
    pending_ = false
    parentOverlay_ = nil
end

function RedeemUI.Create(parentOverlay)
    -- 切换账号时先清理旧实例
    if panel_ then
        RedeemUI.Destroy()
    end
    parentOverlay_ = parentOverlay

    inputRef_ = UI.TextField {
        placeholder = "请输入兑换码",
        width = "100%",
        height = 44,
        fontSize = T.fontSize.md,
        borderRadius = T.radius.md,
        backgroundColor = {30, 32, 42, 255},
        borderWidth = 1,
        borderColor = {80, 85, 100, 200},
        paddingLeft = 12,
        paddingRight = 12,
    }

    statusLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {160, 160, 180, 255},
        textAlign = "center",
        width = "100%",
        wordWrap = true,
    }

    submitBtn_ = UI.Button {
        text = "兑换",
        width = "100%",
        height = 44,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = {80, 130, 220, 255},
        pressedBackgroundColor = {60, 110, 200, 255},
        transition = "backgroundColor 0.15s easeOut",
        onClick = function(self)
            if pending_ then return end
            local code = inputRef_ and inputRef_:GetValue() or ""
            -- 去除首尾空格
            code = code:match("^%s*(.-)%s*$") or ""
            if code == "" then
                statusLabel_:SetText("请输入兑换码")
                statusLabel_:SetStyle({ fontColor = {255, 200, 100, 255} })
                return
            end
            pending_ = true
            submitBtn_:SetText("兑换中...")
            submitBtn_:SetStyle({ backgroundColor = {60, 80, 120, 255} })
            statusLabel_:SetText("正在验证...")
            statusLabel_:SetStyle({ fontColor = {200, 200, 220, 255} })
            SendRedeemRequest(code)
        end,
    }

    panel_ = UI.Panel {
        id = "redeemUI",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 250,
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self)
            -- 点击背景关闭
            RedeemUI.Hide()
        end,
        children = {
            UI.Panel {
                width = 380,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function(self) end,  -- 防止穿透到背景
                children = {
                    -- 标题栏
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = T.spacing.sm,
                                children = {
                                    UI.Label {
                                        text = "🎁",
                                        fontSize = T.fontSize.xl,
                                    },
                                    UI.Label {
                                        text = "兑换码",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self)
                                    RedeemUI.Hide()
                                end,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Divider { color = {60, 60, 75, 200} },
                    -- 说明文字
                    UI.Label {
                        text = "输入兑换码获取奖励",
                        fontSize = T.fontSize.sm,
                        fontColor = {140, 140, 160, 200},
                        textAlign = "center",
                    },
                    -- 输入框
                    inputRef_,
                    -- 状态标签
                    statusLabel_,
                    -- 兑换按钮
                    submitBtn_,
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)

    -- 订阅服务端响应
    SubscribeToEvent(SaveProtocol.S2C_RedeemResult, "RedeemUI_HandleRedeemResult")
end

function RedeemUI.Show()
    if not panel_ then return end
    if visible_ then return end
    visible_ = true
    pending_ = false
    if statusLabel_ then
        statusLabel_:SetText("")
    end
    if inputRef_ then
        inputRef_:Clear()
    end
    if submitBtn_ then
        submitBtn_:SetText("兑换")
        submitBtn_:SetStyle({ backgroundColor = {80, 130, 220, 255} })
    end
    panel_:Show()
end

function RedeemUI.Hide()
    if not panel_ then return end
    if not visible_ then return end
    visible_ = false
    panel_:Hide()
end

function RedeemUI.IsVisible()
    return visible_
end

return RedeemUI
