-- ============================================================================
-- SkinShopUI.lua — 大黑无天皮肤商店面板
--
-- 展示：NPC肖像+懊恼对话 / 3款皮肤卡片 / 购买按钮
-- 网络：C2S_SkinShopQuery → S2C_SkinShopData
--       C2S_SkinShopBuy   → S2C_SkinShopResult
-- ============================================================================

local UI = require("urhox-libs/UI")
local T  = require("config.UITheme")
local GameState = require("core.GameState")
local EventBus  = require("core.EventBus")
local SaveProtocol = require("network.SaveProtocol")
local SkinShopConfig = require("config.SkinShopConfig")
local PetSkinSystem  = require("systems.PetSkinSystem")
local cjson = cjson or require("cjson") ---@diagnostic disable-line: undefined-global

local SkinShopUI = {}

-- ============================================================================
-- 颜色常量
-- ============================================================================

local C = {
    bg           = {25, 20, 35, 245},
    headerBg     = {45, 30, 60, 255},
    cardBg       = {40, 35, 55, 230},
    cardOwned    = {30, 50, 40, 230},
    textTitle    = {255, 220, 140, 255},
    textNormal   = {210, 210, 220, 240},
    textMuted    = {140, 140, 160, 180},
    textSuccess  = {80, 220, 120, 255},
    textError    = {255, 90, 90, 255},
    xianshiColor = {255, 200, 60, 255},
    btnBuy       = {120, 60, 180, 255},
    btnBuyHover  = {140, 80, 200, 255},
    btnDisabled  = {80, 80, 90, 180},
    btnClose     = {180, 50, 50, 220},
    bonusColor   = {140, 220, 255, 255},
    separator    = {80, 70, 100, 120},
}

-- ============================================================================
-- 状态
-- ============================================================================

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil

local dataLoaded_ = false
local pendingRequest_ = false
local realmOk_ = false
local xianshi_ = 0
local unlockedSet_ = {}   -- { [skinId] = true }
local price_ = SkinShopConfig.SKIN_PRICE

-- UI 引用
local contentPanel_ = nil
local currencyLabel_ = nil
local statusLabel_ = nil
local onClose_ = nil  -- 关闭时的回调（从黑市打开时用于返回黑市）

-- 前向声明（SendBuy 需要在定义之前引用）
local SetStatus
local RefreshContent

-- ============================================================================
-- 网络通信
-- ============================================================================

local lastSendTime_ = 0
local SEND_COOLDOWN = 0.5

--- 发送事件到服务器
---@param eventName string
---@param fields table|nil
---@return boolean
local function SendToServer(eventName, fields)
    -- N1: 持续断连时阻断高风险操作
    local NetworkStatus = require("network.NetworkStatus")
    if NetworkStatus.IsDisconnected() then
        print("[SkinShopUI] Blocked by sustained disconnect: " .. eventName)
        return false
    end
    local serverConn = network.serverConnection
    if not serverConn then
        print("[SkinShopUI] no server connection")
        return false
    end
    local now = time.elapsedTime
    if now - lastSendTime_ < SEND_COOLDOWN then
        print("[SkinShopUI] Throttled: " .. eventName)
        return false
    end

    local data = VariantMap()
    if fields then
        for k, v in pairs(fields) do
            if type(v) == "string" then
                data[k] = Variant(v)
            elseif type(v) == "number" then
                data[k] = Variant(v)
            elseif type(v) == "boolean" then
                data[k] = Variant(v)
            end
        end
    end
    serverConn:SendRemoteEvent(eventName, true, data)
    lastSendTime_ = time.elapsedTime
    print("[SkinShopUI] SENT: " .. eventName)
    return true
end

local function SendQuery()
    if pendingRequest_ then return end
    pendingRequest_ = true
    if not SendToServer(SaveProtocol.C2S_SkinShopQuery) then
        pendingRequest_ = false  -- 发送失败时释放锁
    end
end

local function SendBuy(skinId)
    if pendingRequest_ then return end
    pendingRequest_ = true
    if not SendToServer(SaveProtocol.C2S_SkinShopBuy, { skinId = skinId }) then
        pendingRequest_ = false  -- 发送失败时释放锁
        SetStatus("请稍候再试", C.textError)
        RefreshContent()  -- 恢复按钮状态
    end
end

-- ============================================================================
-- UI 辅助
-- ============================================================================

SetStatus = function(text, color)
    if statusLabel_ then
        statusLabel_:SetStyle({ text = text, fontColor = color or C.textMuted })
    end
end

local function RefreshCurrency()
    if currencyLabel_ then
        currencyLabel_:SetStyle({ text = "仙石: " .. tostring(xianshi_) })
    end
end

--- 获取 bonus 描述文字
---@param bonus table
---@return string
local function FormatBonus(bonus)
    if not bonus then return "" end
    local parts = {}
    if bonus.atkPct then parts[#parts + 1] = "攻击+" .. (bonus.atkPct * 100) .. "%" end
    if bonus.defPct then parts[#parts + 1] = "防御+" .. (bonus.defPct * 100) .. "%" end
    if bonus.hpPct  then parts[#parts + 1] = "生命+" .. (bonus.hpPct * 100) .. "%" end
    if bonus.fortune then parts[#parts + 1] = "福缘+" .. bonus.fortune end
    if bonus.wisdom  then parts[#parts + 1] = "悟性+" .. bonus.wisdom end
    if #parts == 0 then return "无" end
    return table.concat(parts, "  ")
end

--- 构建皮肤卡片列表
local function BuildSkinCards()
    local items = SkinShopConfig.GetShopItems()
    local cards = {}

    for _, item in ipairs(items) do
        local owned = unlockedSet_[item.id] == true
        local canBuy = realmOk_ and not owned and xianshi_ >= price_ and not pendingRequest_

        -- 购买按钮
        local buyBtn
        if owned then
            buyBtn = UI.Label {
                text = "✓ 已拥有",
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                fontColor = C.textSuccess,
                textAlign = "center",
                width = "100%",
                paddingTop = 4,
                paddingBottom = 4,
            }
        else
            local skinIdCapture = item.id
            buyBtn = UI.Button {
                text = price_ .. " 仙石",
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                width = "100%",
                height = 36,
                borderRadius = T.radius.sm,
                backgroundColor = canBuy and C.btnBuy or C.btnDisabled,
                fontColor = {255, 255, 255, canBuy and 255 or 120},
                disabled = not canBuy,
                onClick = function(self)
                    if pendingRequest_ then return end
                    -- §8 层③：客户端按钮禁用
                    self:SetDisabled(true)
                    self:SetStyle({ backgroundColor = C.btnDisabled })
                    SetStatus("购买中...", C.xianshiColor)
                    SendBuy(skinIdCapture)
                end,
            }
        end

        cards[#cards + 1] = UI.Panel {
            width = "100%",
            backgroundColor = owned and C.cardOwned or C.cardBg,
            borderRadius = T.radius.md,
            padding = T.spacing.sm,
            gap = T.spacing.xs,
            flexDirection = "row",
            alignItems = "center",
            children = {
                -- 皮肤预览图
                UI.Panel {
                    width = 72,
                    height = 72,
                    borderRadius = T.radius.sm,
                    backgroundColor = {20, 18, 30, 200},
                    backgroundImage = item.texture,
                    backgroundFit = "contain",
                    flexShrink = 0,
                },
                -- 信息区
                UI.Panel {
                    flex = 1,
                    flexShrink = 1,
                    gap = 2,
                    children = {
                        UI.Label {
                            text = item.name,
                            fontSize = T.fontSize.md,
                            fontWeight = "bold",
                            fontColor = C.textTitle,
                        },
                        UI.Label {
                            text = "加成: " .. FormatBonus(item.bonus),
                            fontSize = T.fontSize.sm,
                            fontColor = C.bonusColor,
                        },
                        buyBtn,
                    },
                },
            },
        }
    end

    return cards
end

--- 重建内容区域
RefreshContent = function()
    if not contentPanel_ then return end
    contentPanel_:RemoveAllChildren()

    local cards = BuildSkinCards()
    for _, card in ipairs(cards) do
        contentPanel_:AddChild(card)
    end

    -- 境界不足提示
    if dataLoaded_ and not realmOk_ then
        contentPanel_:AddChild(UI.Label {
            text = "需达到「筑基初期」境界方可购买",
            fontSize = T.fontSize.md,
            fontColor = C.textError,
            textAlign = "center",
            width = "100%",
            paddingTop = T.spacing.sm,
        })
    end
end

-- ============================================================================
-- 公共接口
-- ============================================================================

function SkinShopUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    panel_ = nil  -- 重入安全

    panel_ = UI.Panel {
        id = "skinShopPanel",
        position = "absolute",
        width = "100%",
        height = "100%",
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 20,
        children = {
            -- 主面板
            UI.Panel {
                width = "92%",
                maxWidth = 420,
                maxHeight = "85%",
                backgroundColor = C.bg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {120, 80, 180, 100},
                overflow = "scroll",
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%",
                        backgroundColor = C.headerBg,
                        borderTopLeftRadius = T.radius.lg,
                        borderTopRightRadius = T.radius.lg,
                        padding = T.spacing.sm,
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.sm,
                        children = {
                            -- NPC 肖像
                            UI.Panel {
                                width = 56,
                                height = 56,
                                borderRadius = 28,
                                backgroundColor = {30, 25, 45, 255},
                                backgroundImage = SkinShopConfig.NPC_PORTRAIT,
                                backgroundFit = "contain",
                                flexShrink = 0,
                            },
                            -- NPC 名称 + 头衔
                            UI.Panel {
                                flex = 1,
                                flexShrink = 1,
                                gap = 2,
                                children = {
                                    UI.Label {
                                        text = SkinShopConfig.NPC_NAME,
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = C.textTitle,
                                    },
                                    UI.Label {
                                        text = SkinShopConfig.NPC_TITLE,
                                        fontSize = T.fontSize.sm,
                                        fontColor = C.textMuted,
                                    },
                                },
                            },
                            -- 关闭按钮
                            UI.Button {
                                text = "✕",
                                fontSize = T.fontSize.lg,
                                width = 36,
                                height = 36,
                                borderRadius = 18,
                                backgroundColor = C.btnClose,
                                fontColor = {255, 255, 255, 255},
                                onClick = function()
                                    SkinShopUI.Hide()
                                end,
                            },
                        },
                    },
                    -- NPC 对话气泡（和黑市一样的多行结构）
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {50, 40, 65, 160},
                        borderRadius = T.radius.sm,
                        padding = T.spacing.sm,
                        children = (function()
                            local labels = {}
                            for i, line in ipairs(SkinShopConfig.NPC_DIALOGUE) do
                                labels[#labels + 1] = UI.Label {
                                    text = "「" .. line .. "」",
                                    fontSize = T.fontSize.xs,
                                    fontColor = {200, 200, 180, 240},
                                    width = "100%",
                                    marginTop = i > 1 and 4 or 0,
                                }
                            end
                            return labels
                        end)(),
                    },
                    -- 分隔线
                    UI.Panel {
                        width = "90%",
                        height = 1,
                        backgroundColor = C.separator,
                        alignSelf = "center",
                    },
                    -- 仙石余额 + 状态
                    UI.Panel {
                        width = "100%",
                        paddingLeft = T.spacing.md,
                        paddingRight = T.spacing.md,
                        paddingTop = T.spacing.xs,
                        paddingBottom = T.spacing.xs,
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                id = "skinShopCurrency",
                                text = "仙石: --",
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                fontColor = C.xianshiColor,
                            },
                            UI.Label {
                                id = "skinShopStatus",
                                text = "",
                                fontSize = T.fontSize.sm,
                                fontColor = C.textMuted,
                            },
                        },
                    },
                    -- 商品列表
                    UI.Panel {
                        id = "skinShopContent",
                        width = "100%",
                        padding = T.spacing.sm,
                        gap = T.spacing.sm,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)

    -- 绑定 UI 引用
    currencyLabel_ = panel_:FindById("skinShopCurrency")
    statusLabel_   = panel_:FindById("skinShopStatus")
    contentPanel_  = panel_:FindById("skinShopContent")
end

function SkinShopUI.Show(options)
    if not panel_ then return end

    -- 保存关闭回调
    onClose_ = options and options.onClose or nil

    -- 重置状态
    dataLoaded_ = false
    pendingRequest_ = false

    panel_:SetVisible(true)
    visible_ = true
    SetStatus("加载中...", C.xianshiColor)
    RefreshContent()
    SendQuery()
end

function SkinShopUI.Hide()
    if not panel_ then return end
    panel_:SetVisible(false)
    visible_ = false
    pendingRequest_ = false
    -- 触发关闭回调（返回黑市）
    local cb = onClose_
    onClose_ = nil
    if cb then cb() end
end

function SkinShopUI.IsVisible()
    return visible_
end

function SkinShopUI.Destroy()
    if panel_ then
        panel_:Remove()
        panel_ = nil
    end
    visible_ = false
    parentOverlay_ = nil
    contentPanel_ = nil
    currencyLabel_ = nil
    statusLabel_ = nil
end

-- ============================================================================
-- S2C 事件处理（全局函数，模块加载时注册）
-- ============================================================================

--- S2C_SkinShopData：查询响应
function SkinShopUI_HandleData(eventType, eventData)
    pendingRequest_ = false
    local ok = eventData["ok"]:GetBool()
    if not ok then
        local reason = eventData["reason"]:GetString()
        SetStatus(reason, C.textError)
        return
    end

    dataLoaded_ = true
    realmOk_ = eventData["realmOk"]:GetBool()
    xianshi_ = eventData["xianshi"]:GetInt()
    price_   = eventData["price"]:GetInt()

    -- 解析已解锁列表
    unlockedSet_ = {}
    local unlockedJson = eventData["unlocked"]:GetString()
    local success, decoded = pcall(cjson.decode, unlockedJson)
    if success and type(decoded) == "table" then
        for _, skinId in ipairs(decoded) do
            unlockedSet_[skinId] = true
        end
    end

    RefreshCurrency()
    SetStatus("", C.textMuted)
    RefreshContent()
end

--- S2C_SkinShopResult：购买响应
function SkinShopUI_HandleResult(eventType, eventData)
    pendingRequest_ = false
    local ok = eventData["ok"]:GetBool()

    if not ok then
        local reason = eventData["reason"]:GetString()
        SetStatus(reason, C.textError)
        -- 购买失败，重新查询以刷新按钮状态
        SendQuery()
        return
    end

    -- 购买成功
    local skinId = eventData["skinId"]:GetString()
    local newXianshi = eventData["xianshi"]:GetInt()
    if newXianshi >= 0 then
        xianshi_ = newXianshi
    end
    unlockedSet_[skinId] = true

    -- 客户端解锁皮肤（更新 GameState）
    PetSkinSystem.UnlockPremiumSkin(skinId)

    -- 请求保存存档
    EventBus.Emit("save_request")

    RefreshCurrency()
    SetStatus("购买成功！", C.textSuccess)
    RefreshContent()
end

-- ============================================================================
-- S2C 事件注册（模块加载时自动注册）
-- ============================================================================

do
    SubscribeToEvent(SaveProtocol.S2C_SkinShopData, "SkinShopUI_HandleData")
    SubscribeToEvent(SaveProtocol.S2C_SkinShopResult, "SkinShopUI_HandleResult")
end

return SkinShopUI
