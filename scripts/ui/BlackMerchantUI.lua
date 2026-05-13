-- ============================================================================
-- BlackMerchantUI.lua — 万界商行交易面板
--
-- 功能：NPC肖像+对话 / 商品橱窗（钯/八卦标签，竖卡双列） / 仙石兑换 / 交易记录
-- 设计文档：docs/设计文档/万界黑商.md v0.8 §8
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local GameConfig = require("config.GameConfig")
local SaveProtocol = require("network.SaveProtocol")
local BMConfig = require("config.BlackMerchantConfig")
local InventorySystem = require("systems.InventorySystem")
local FormatUtils = require("utils.FormatUtils")
local LootSystem = require("systems.LootSystem")
local IconUtils = require("utils.IconUtils")
local WarehouseSystem = require("systems.WarehouseSystem")  -- HOTFIX-BM-01
local cjson = cjson or require("cjson") ---@diagnostic disable-line: undefined-global

local BlackMerchantUI = {}

-- ============================================================================
-- 常量
-- ============================================================================

local PORTRAIT_SIZE = 64
local NPC_NAME = "胤"
local NPC_TITLE = "星界财团·新任掌柜"
local NPC_DIALOGUE = "欢迎来到万界商行。\n万物皆有价，买卖凭仙石。\n商店库存全部来自其他修士的寄售，无官方补货，售空即止。\n胤每天也会采购货物，满库存的商品可能被收走。\n灵韵可兑仙石，仙石亦可换灵韵（折损五成）。"

-- ============================================================================
-- 状态
-- ============================================================================

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil

-- 服务端数据缓存
local dataLoaded_ = false   -- 是否已收到过服务端响应
local realmOk_ = false
local xianshi_ = 0
local items_ = {}           -- { [itemId] = { stock, buy_price, sell_price, held } }
local tradeRecords_ = {}    -- 交易记录数组

-- UI 引用
local contentPanel_ = nil   -- 动态内容区（标签页切换时重建）
local currencyLabel_ = nil  -- 仙石余额文字
local statusLabel_ = nil    -- 状态提示文字
local tabBtnConsumableMat_ = nil
local tabBtnHerb_ = nil
-- local tabBtnEvent_ = nil  -- 活动已下架
local tabBtnRake_ = nil
local tabBtnBagua_ = nil
local tabBtnTiandi_ = nil
local tabBtnLingyu_ = nil
local tabBtnSpecialEquip_ = nil
local tabBtnSkillBook_ = nil
local tabBtnHistory_ = nil

local activeTab_ = "consumable_mat"   -- "consumable_mat" | "herb" | "rake" | "bagua" | "tiandi" | "lingyu" | "special_equip" | "skill_book" | "history"

-- 轮询
local POLL_INTERVAL = 30.0  -- P0: 降频，减少 SYSTEM_UID 热读压力
local pollTimer_ = 0

-- 防重复请求
local pendingRequest_ = false

-- 节流：所有 C2S 请求共享 0.5s 最小间隔（降低服务端限流压力）
local THROTTLE_INTERVAL = 0.5
local lastSendTime_ = -1  -- -1 保证首次不被节流

-- 状态提示保留时间（避免被查询响应立即覆盖）
local statusKeepUntil_ = 0

-- 二次确认弹窗
local confirmDialog_ = nil
local CONFIRM_TIMEOUT = 3.0
local confirmTimer_ = 0

-- 灵韵→仙石预扣记录（失败时回退）
local pendingExchangeLingYunCost_ = 0

-- 兑换弹窗状态
local exchangeDialog_ = nil
local exchangeVisible_ = false
local exchangeDirection_ = "buy"  -- "buy" = 灵韵→仙石, "sell" = 仙石→灵韵
local exchangeAmount_ = 1

-- ============================================================================
-- 颜色常量（暗紫/深金风格）
-- ============================================================================

local C = {
    panelBg      = {22, 18, 35, 248},
    headerBg     = {28, 22, 42, 255},
    cardBg       = {35, 30, 52, 230},
    cardBorder   = {120, 100, 60, 180},
    bossGlow     = {255, 200, 80, 255},
    titleGold    = {255, 220, 150, 255},
    xianshiColor = {180, 140, 255, 255},  -- 仙石紫色
    buyBtnColor  = {180, 150, 50, 240},   -- 购买金色
    sellBtnColor = {50, 150, 160, 240},   -- 出售青色
    disabledBtn  = {70, 70, 80, 200},
    stockGreen   = {80, 200, 100, 255},
    stockYellow  = {220, 200, 60, 255},
    stockRed     = {220, 80, 60, 255},
    tabActive    = {100, 60, 160, 255},
    tabInactive  = {50, 45, 65, 180},
    separator    = {120, 100, 60, 80},
    textMuted    = {160, 160, 170, 200},
    textSuccess  = {100, 255, 180, 255},
    textError    = {255, 120, 100, 255},
    dialogueBg   = {30, 25, 45, 200},
    npcNameColor = {220, 200, 160, 255},
    npcTitleColor = {150, 140, 120, 200},
}

-- ============================================================================
-- 网络通信
-- ============================================================================

--- 发送 C2S 事件
---@param eventName string
---@param fields table|nil
local function SendToServer(eventName, fields)
    -- 节流：0.5s 内不重复发送（使用引擎计时器，os.clock 在 WASM 下可能返回 0）
    local now = time.elapsedTime
    if now - lastSendTime_ < THROTTLE_INTERVAL then
        print("[BlackMerchantUI] Throttled: " .. eventName .. " now=" .. tostring(now) .. " last=" .. tostring(lastSendTime_))
        pendingRequest_ = false  -- 解锁，允许后续重试
        return false
    end

    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[BlackMerchantUI] No server connection")
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
    print("[BlackMerchantUI] SENT: " .. eventName .. " at=" .. tostring(lastSendTime_))
    return true
end

--- 查询商品数据
local function SendQuery()
    if pendingRequest_ then return end
    pendingRequest_ = true
    SendToServer(SaveProtocol.C2S_BlackMerchantQuery)
    print("[BlackMerchantUI] SendQuery")
end

--- 购买商品
local function SendBuy(consumableId, amount)
    if pendingRequest_ then return end
    pendingRequest_ = true
    SendToServer(SaveProtocol.C2S_BlackMerchantBuy, {
        consumableId = consumableId,
        amount = amount or 1,
    })
end

--- 出售商品
local function SendSell(consumableId, amount)
    if pendingRequest_ then return end
    pendingRequest_ = true
    SendToServer(SaveProtocol.C2S_BlackMerchantSell, {
        consumableId = consumableId,
        amount = amount or 1,
    })
end

--- 兑换灵韵/仙石
local function SendExchange(direction, amount)
    if pendingRequest_ then return end
    pendingRequest_ = true
    SendToServer(SaveProtocol.C2S_BlackMerchantExchange, {
        direction = direction,
        amount = amount,
    })
end

--- 查询交易记录
local function SendHistory()
    if pendingRequest_ then return end
    pendingRequest_ = true
    SendToServer(SaveProtocol.C2S_BlackMerchantHistory)
end

-- ============================================================================
-- UI 辅助
-- ============================================================================

--- 库存颜色
local function StockColor(stock)
    if stock <= 1 then return C.stockRed end
    if stock <= 3 then return C.stockYellow end
    return C.stockGreen
end

--- 格式化时间戳（来自共享模块）
local FormatTime = FormatUtils.Time

--- 交易动作显示名
local function ActionName(action)
    if action == "buy" then return "购入" end
    if action == "sell" then return "售出" end
    if action == "exchange_buy" then return "兑入" end
    if action == "exchange_sell" then return "兑出" end
    return action or "?"
end

--- 交易动作颜色
local function ActionColor(action)
    if action == "buy" or action == "exchange_buy" then
        return C.buyBtnColor
    end
    return C.sellBtnColor
end

--- 设置状态提示
---@param text string
---@param color table|nil
---@param keepSec number|nil 保留秒数（期间不会被低优先级消息覆盖）
local function SetStatus(text, color, keepSec)
    if keepSec and keepSec > 0 then
        statusKeepUntil_ = time.elapsedTime + keepSec
    end
    if statusLabel_ then
        statusLabel_:SetText(text)
        statusLabel_:SetStyle({ fontColor = color or C.textMuted })
    end
end

--- 低优先级状态（可被 keepSec 保护的消息阻断）
local function SetStatusSoft(text, color)
    if time.elapsedTime < statusKeepUntil_ then return end
    SetStatus(text, color)
end

-- ============================================================================
-- 买卖二次确认弹窗
-- ============================================================================

local confirmBtnRef_ = nil   -- 确认按钮引用，用于更新倒计时文字
local confirmBtnText_ = ""   -- 按钮文字前缀（"确认购买" / "确认出售"）

local function HideConfirmDialog()
    if confirmDialog_ then
        confirmDialog_:SetVisible(false)
        if parentOverlay_ then
            parentOverlay_:RemoveChild(confirmDialog_)
        end
        confirmDialog_ = nil
        confirmBtnRef_ = nil
        confirmTimer_ = 0
    end
end

--- 显示买/卖确认弹窗
---@param action "buy"|"sell"
---@param itemId string
local function ShowConfirmDialog(action, itemId)
    if pendingRequest_ then return end  -- 上一个请求未完成，不弹新弹窗
    HideConfirmDialog()

    local cfg = BMConfig.ITEMS[itemId]
    if not cfg then return end

    local data = items_[itemId] or {}
    local isBuy = (action == "buy")
    local price = isBuy and cfg.sell_price or cfg.buy_price
    local stock = data.stock or 0
    local held = data.held or 0

    local titleText = isBuy and "确认购买" or "确认出售"
    local actionColor = isBuy and C.buyBtnColor or C.sellBtnColor
    local detailText = isBuy
        and (cfg.name .. " ×1\n花费 " .. price .. " 仙石")
        or  (cfg.name .. " ×1\n获得 " .. price .. " 仙石")
    local itemMaxStock = cfg.max_stock or BMConfig.MAX_STOCK
    local infoText = isBuy
        and ("商店库存 " .. stock .. "/" .. itemMaxStock .. "\n余额 " .. xianshi_ .. " 仙石")
        or  ("背包持有 " .. held .. "\n余额 " .. xianshi_ .. " 仙石")

    confirmDialog_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        onClick = function()
            HideConfirmDialog()
        end,
        children = {
            UI.Panel {
                width = "80%", maxWidth = 360,
                backgroundColor = C.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = C.cardBorder,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function() end,  -- 阻止穿透关闭
                children = {
                    -- 标题
                    UI.Label {
                        text = titleText,
                        fontSize = T.fontSize.lg, fontWeight = "bold",
                        fontColor = C.titleGold,
                        textAlign = "center", width = "100%",
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = C.separator },
                    -- 交易详情
                    UI.Label {
                        text = detailText,
                        fontSize = T.fontSize.md,
                        fontColor = {230, 230, 240, 255},
                        textAlign = "center", width = "100%",
                    },
                    -- 附加信息
                    UI.Label {
                        text = infoText,
                        fontSize = T.fontSize.sm,
                        fontColor = C.textMuted,
                        textAlign = "center", width = "100%",
                    },
                    -- 按钮行
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        justifyContent = "center", gap = T.spacing.md,
                        marginTop = T.spacing.sm,
                        children = {
                            UI.Button {
                                text = "取消",
                                width = 100, height = T.size.dialogBtnH,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = C.disabledBtn,
                                onClick = function()
                                    HideConfirmDialog()
                                end,
                            },
                            (function()
                                local btnText = isBuy and "确认购买" or "确认出售"
                                confirmBtnText_ = btnText
                                local btn = UI.Button {
                                    text = btnText .. " (3)",
                                    width = 120, height = T.size.dialogBtnH,
                                    fontSize = T.fontSize.md, fontWeight = "bold",
                                    borderRadius = T.radius.md,
                                    backgroundColor = actionColor,
                                    onClick = function()
                                        if pendingRequest_ then return end  -- 防重复
                                        HideConfirmDialog()
                                        if isBuy then
                                            SendBuy(itemId, 1)
                                            SetStatus("购买中...", C.xianshiColor)
                                        else
                                            -- HOTFIX-BM-01A: 背包未同步时拦截卖出（仓库存取 + 敏感道具消费）
                                            if WarehouseSystem.IsDirty() then
                                                SetStatus("背包数据未同步，请稍后再试", C.textError, 3)
                                                print("[BlackMerchantUI] SELL BLOCKED: backpack unsync (dirty)")
                                                return
                                            end
                                            SendSell(itemId, 1)
                                            SetStatus("出售中...", C.xianshiColor)
                                        end
                                    end,
                                }
                                confirmBtnRef_ = btn
                                return btn
                            end)(),
                        },
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(confirmDialog_)
    confirmTimer_ = CONFIRM_TIMEOUT
end

-- ============================================================================
-- 标签页切换
-- ============================================================================

local function SetActiveTab(tab)
    if activeTab_ == tab then return end
    activeTab_ = tab
    HideConfirmDialog()  -- 切标签关闭确认弹窗

    -- 更新所有标签按钮样式
    if tabBtnConsumableMat_ then tabBtnConsumableMat_:SetStyle({ backgroundColor = (tab == "consumable_mat") and C.tabActive or C.tabInactive }) end
    if tabBtnHerb_ then tabBtnHerb_:SetStyle({ backgroundColor = (tab == "herb") and C.tabActive or C.tabInactive }) end
    -- if tabBtnEvent_ then tabBtnEvent_:SetStyle({ backgroundColor = (tab == "event") and C.tabActive or C.tabInactive }) end  -- 活动已下架
    if tabBtnRake_ then tabBtnRake_:SetStyle({ backgroundColor = (tab == "rake") and C.tabActive or C.tabInactive }) end
    if tabBtnBagua_ then tabBtnBagua_:SetStyle({ backgroundColor = (tab == "bagua") and C.tabActive or C.tabInactive }) end
    if tabBtnTiandi_ then tabBtnTiandi_:SetStyle({ backgroundColor = (tab == "tiandi") and C.tabActive or C.tabInactive }) end
    if tabBtnLingyu_ then tabBtnLingyu_:SetStyle({ backgroundColor = (tab == "lingyu") and C.tabActive or C.tabInactive }) end
    if tabBtnSpecialEquip_ then tabBtnSpecialEquip_:SetStyle({ backgroundColor = (tab == "special_equip") and C.tabActive or C.tabInactive }) end
    if tabBtnSkillBook_ then tabBtnSkillBook_:SetStyle({ backgroundColor = (tab == "skill_book") and C.tabActive or C.tabInactive }) end
    if tabBtnHistory_ then tabBtnHistory_:SetStyle({ backgroundColor = (tab == "history") and C.tabActive or C.tabInactive }) end

    -- 切到记录页时请求数据
    if tab == "history" then
        SendHistory()
    end

    BlackMerchantUI.RefreshContent()
end

-- ============================================================================
-- 内容构建
-- ============================================================================

--- 构建单个商品竖卡
---@param itemId string
---@return table UI.Panel
local function BuildItemCard(itemId)
    local cfg = BMConfig.ITEMS[itemId]
    if not cfg then return UI.Panel {} end

    local data = items_[itemId] or {}
    local stock = data.stock or 0
    local held = data.held or 0
    local buyPrice = cfg.sell_price   -- 玩家购买价 = 黑商出售价
    local sellPrice = cfg.buy_price   -- 玩家出售价 = 黑商收购价

    local maxStock = cfg.max_stock or BMConfig.MAX_STOCK
    local canBuy = realmOk_ and stock > 0 and xianshi_ >= buyPrice
    local canSell = realmOk_ and held > 0 and stock < maxStock

    local nameText = cfg.name
    if cfg.isBoss then
        nameText = "★ " .. nameText
    end

    -- 库存条比例
    local stockRatio = stock / maxStock

    return UI.Panel {
        width = "48%",
        backgroundColor = C.cardBg,
        borderRadius = T.radius.md,
        borderWidth = cfg.isBoss and 2 or 1,
        borderColor = cfg.isBoss and C.bossGlow or C.cardBorder,
        padding = T.spacing.sm,
        gap = 4,
        alignItems = "center",
        children = {
            -- 道具图标：cfg.image 或 cfg.icon 为图片路径则贴图，否则 emoji 用文字渲染
            (function()
                local imgSrc = cfg.image or (IconUtils.IsImagePath(cfg.icon) and cfg.icon)
                if imgSrc then
                    return UI.Panel {
                        width = 48, height = 48,
                        backgroundImage = imgSrc,
                        backgroundFit = "contain",
                        alignSelf = "center",
                        pointerEvents = "none",
                    }
                else
                    return UI.Panel {
                        width = 48, height = 48,
                        alignSelf = "center",
                        justifyContent = "center", alignItems = "center",
                        pointerEvents = "none",
                        children = {
                            UI.Label { text = IconUtils.GetTextIcon(cfg.icon, "?"), fontSize = 28, textAlign = "center" },
                        },
                    }
                end
            end)(),
            -- 商品名
            UI.Label {
                text = nameText,
                fontSize = T.fontSize.sm, fontWeight = "bold",
                fontColor = cfg.isBoss and C.bossGlow or C.titleGold,
                textAlign = "center",
                pointerEvents = "none",
            },
            -- 库存条
            UI.Panel {
                width = "100%", height = 6,
                backgroundColor = {40, 35, 55, 200},
                borderRadius = 3,
                overflow = "hidden",
                children = {
                    UI.Panel {
                        width = tostring(math.max(stockRatio * 100, 2)) .. "%",
                        height = "100%",
                        backgroundColor = StockColor(stock),
                        borderRadius = 3,
                    },
                },
            },
            -- 库存/持有
            UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "space-between",
                children = {
                    UI.Label {
                        text = "商店 " .. stock .. "/" .. maxStock,
                        fontSize = 10,
                        fontColor = StockColor(stock),
                    },
                    UI.Label {
                        text = "背包 " .. held,
                        fontSize = 10,
                        fontColor = held > 0 and {200, 200, 255, 255} or C.textMuted,
                    },
                },
            },
            -- 价格行
            UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "center", gap = T.spacing.sm,
                children = {
                    UI.Label {
                        text = "买" .. buyPrice,
                        fontSize = 10,
                        fontColor = C.buyBtnColor,
                    },
                    UI.Label {
                        text = "卖" .. sellPrice,
                        fontSize = 10,
                        fontColor = C.sellBtnColor,
                    },
                },
            },
            -- 按钮行
            UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "space-between",
                children = {
                    UI.Button {
                        text = "购买",
                        width = 48, height = 26,
                        fontSize = 11, fontWeight = "bold",
                        borderRadius = T.radius.sm,
                        backgroundColor = canBuy and C.buyBtnColor or C.disabledBtn,
                        onClick = function()
                            -- 用实时数据判断（items_ 和 xianshi_ 可能在构建后更新）
                            local d = items_[itemId] or {}
                            local curStock = d.stock or 0
                            if not realmOk_ then
                                SetStatus("境界不足", C.textError); return
                            elseif curStock <= 0 then
                                SetStatus("库存为空", C.textError); return
                            elseif xianshi_ < buyPrice then
                                SetStatus("仙石不足 (需" .. buyPrice .. ")", C.textError); return
                            end
                            ShowConfirmDialog("buy", itemId)
                        end,
                    },
                    UI.Button {
                        text = "出售",
                        width = 48, height = 26,
                        fontSize = 11, fontWeight = "bold",
                        borderRadius = T.radius.sm,
                        backgroundColor = canSell and C.sellBtnColor or C.disabledBtn,
                        onClick = function()
                            local d = items_[itemId] or {}
                            local curHeld = d.held or 0
                            local curStock = d.stock or 0
                            if not realmOk_ then
                                SetStatus("境界不足", C.textError); return
                            elseif curHeld <= 0 then
                                SetStatus("未持有此物品", C.textError); return
                            elseif curStock >= maxStock then
                                SetStatus("黑商仓库已满", C.textError); return
                            end
                            ShowConfirmDialog("sell", itemId)
                        end,
                    },
                },
            },
        },
    }
end

--- 构建商品列表（钯 或 八卦）
local function BuildShowcase(category)
    local ids = BMConfig.GetItemsByCategory(category)
    local children = {}

    if not dataLoaded_ then
        -- 数据尚未加载，显示占位
        children[#children + 1] = UI.Panel {
            width = "100%", alignItems = "center", padding = T.spacing.lg,
            children = {
                UI.Label {
                    text = "正在获取商品数据...",
                    fontSize = T.fontSize.sm,
                    fontColor = C.textMuted,
                },
            },
        }
        return children
    end

    if not realmOk_ then
        -- 已加载，但境界不足
        children[#children + 1] = UI.Panel {
            width = "100%", alignItems = "center", padding = T.spacing.lg,
            children = {
                UI.Label {
                    text = "🔒",
                    fontSize = T.fontSize.xxl,
                },
                UI.Label {
                    text = "需达到「筑基初期」方可交易",
                    fontSize = T.fontSize.sm, fontWeight = "bold",
                    fontColor = C.textError,
                    marginTop = T.spacing.sm,
                },
                UI.Label {
                    text = "浏览商品不受限制",
                    fontSize = T.fontSize.xs,
                    fontColor = C.textMuted,
                },
            },
        }
    end

    for _, id in ipairs(ids) do
        children[#children + 1] = BuildItemCard(id)
    end

    if #ids == 0 then
        children[#children + 1] = UI.Label {
            text = "暂无商品",
            fontSize = T.fontSize.sm,
            fontColor = C.textMuted,
            textAlign = "center",
        }
    end

    return children
end

--- 构建交易记录列表
local function BuildHistoryList()
    local children = {}

    if #tradeRecords_ == 0 then
        children[#children + 1] = UI.Panel {
            width = "100%", alignItems = "center", padding = T.spacing.lg,
            children = {
                UI.Label {
                    text = "暂无交易记录",
                    fontSize = T.fontSize.sm,
                    fontColor = C.textMuted,
                },
            },
        }
        return children
    end

    -- 最多显示前 100 条
    local count = math.min(#tradeRecords_, 100)
    for i = 1, count do
        local rec = tradeRecords_[i]
        local action = rec.a or "?"
        local itemId = rec.id or ""
        local amount = rec.n or 0
        local ts = rec.t or 0

        -- 查找物品名称
        local itemName = itemId
        local cfg = BMConfig.ITEMS[itemId]
        if cfg then
            itemName = cfg.name
        elseif itemId == "xianshi" then
            itemName = "仙石"
        end

        -- 判断是否是胤（系统 NPC）的收购条目（兼容旧记录中的 "大黑五天"/"大黑无天"）
        local isNpcRecycle = (rec.pn == BMConfig.RECYCLE_NPC_NAME or rec.pn == "大黑五天" or rec.pn == "大黑无天")
        -- 玩家名标识：自己标"我"，NPC 统一显示当前名，其他显示原名
        local playerTag
        if rec.own then
            playerTag = "我"
        elseif isNpcRecycle then
            playerTag = BMConfig.RECYCLE_NPC_NAME  -- 旧记录也显示正确名称
        else
            playerTag = rec.pn or ""
        end

        -- 名字颜色：自己=蓝，胤=金，其他=灰
        local nameColor
        if rec.own then
            nameColor = {130, 200, 255, 255}
        elseif isNpcRecycle then
            nameColor = {255, 215, 80, 255}
        else
            nameColor = {200, 200, 210, 200}
        end

        children[#children + 1] = UI.Panel {
            width = "100%", flexDirection = "row",
            alignItems = "center",
            paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
            borderWidth = isNpcRecycle and 2 or nil,
            borderColor = isNpcRecycle and {210, 175, 55, 230} or C.separator,
            borderRadius = isNpcRecycle and 4 or nil,
            borderBottomWidth = not isNpcRecycle and 1 or nil,
            gap = T.spacing.xs,
            children = {
                -- 时间
                UI.Label {
                    text = FormatTime(ts),
                    fontSize = 11, width = 84,
                    fontColor = C.textMuted,
                },
                -- 玩家名
                UI.Label {
                    text = playerTag,
                    fontSize = 11, flexShrink = 0,
                    fontColor = nameColor,
                    fontWeight = isNpcRecycle and "bold" or nil,
                },
                -- 动作标签
                UI.Panel {
                    width = 36,
                    backgroundColor = ActionColor(action),
                    borderRadius = 3, alignItems = "center",
                    paddingTop = 1, paddingBottom = 1,
                    children = {
                        UI.Label {
                            text = ActionName(action),
                            fontSize = 10, fontWeight = "bold",
                            fontColor = {255, 255, 255, 255},
                        },
                    },
                },
                -- 物品 × 数量
                UI.Label {
                    text = itemName .. " ×" .. amount,
                    fontSize = T.fontSize.xs, flexGrow = 1, flexShrink = 1,
                    fontColor = isNpcRecycle and {240, 225, 160, 240} or {220, 220, 230, 240},
                },
            },
        }
    end

    return children
end

--- 刷新动态内容区
function BlackMerchantUI.RefreshContent()
    if not contentPanel_ then return end

    -- 清除旧内容
    contentPanel_:RemoveAllChildren()

    local children = {}
    if activeTab_ == "rake" then
        children = BuildShowcase(BMConfig.CATEGORY_RAKE)
    elseif activeTab_ == "bagua" then
        children = BuildShowcase(BMConfig.CATEGORY_BAGUA)
    elseif activeTab_ == "tiandi" then
        children = BuildShowcase(BMConfig.CATEGORY_TIANDI)
    elseif activeTab_ == "lingyu" then
        children = BuildShowcase(BMConfig.CATEGORY_LINGYU)
    elseif activeTab_ == "consumable_mat" then
        children = BuildShowcase(BMConfig.CATEGORY_CONSUMABLE_MAT)
    elseif activeTab_ == "herb" then
        children = BuildShowcase(BMConfig.CATEGORY_HERB)
    -- elseif activeTab_ == "event" then  -- 活动已下架
    --     children = BuildShowcase(BMConfig.CATEGORY_EVENT)
    elseif activeTab_ == "special_equip" then
        children = BuildShowcase(BMConfig.CATEGORY_SPECIAL_EQUIP)
    elseif activeTab_ == "skill_book" then
        children = BuildShowcase(BMConfig.CATEGORY_SKILL_BOOK)
    elseif activeTab_ == "history" then
        children = BuildHistoryList()
    end

    for _, child in ipairs(children) do
        contentPanel_:AddChild(child)
    end
end

--- 更新仙石余额显示
local function RefreshCurrency()
    if currencyLabel_ then
        currencyLabel_:SetText("仙石: " .. xianshi_)
    end
end

-- ============================================================================
-- 兑换弹窗
-- ============================================================================

local function ShowExchangeDialog(direction)
    if exchangeVisible_ then return end
    exchangeDirection_ = direction
    exchangeAmount_ = 1

    local player = GameState.player
    local lingYun = player and player.lingYun or 0

    local maxAmount
    local titleText, descText, costText
    if direction == "buy" then
        -- 灵韵 → 仙石
        maxAmount = math.floor(lingYun / BMConfig.XIANSHI_BUY_RATE)
        titleText = "灵韵 → 仙石"
        descText = BMConfig.XIANSHI_BUY_RATE .. " 灵韵 = 1 仙石"
        costText = "消耗 " .. BMConfig.XIANSHI_BUY_RATE .. " 灵韵，获得 1 仙石"
    else
        -- 仙石 → 灵韵
        maxAmount = xianshi_
        titleText = "仙石 → 灵韵"
        descText = "1 仙石 = " .. BMConfig.XIANSHI_SELL_RATE .. " 灵韵（50%折损）"
        costText = "消耗 1 仙石，获得 " .. BMConfig.XIANSHI_SELL_RATE .. " 灵韵"
    end

    if maxAmount < 1 then maxAmount = 0 end
    local canConfirm = maxAmount >= 1

    ---@type any
    local amountLabel = nil
    ---@type any
    local costLabel = nil

    local function UpdatePreview(amt)
        exchangeAmount_ = amt
        if amountLabel then
            amountLabel:SetText("数量: " .. amt)
        end
        if costLabel then
            if direction == "buy" then
                costLabel:SetText("消耗 " .. (amt * BMConfig.XIANSHI_BUY_RATE) .. " 灵韵，获得 " .. amt .. " 仙石")
            else
                costLabel:SetText("消耗 " .. amt .. " 仙石，获得 " .. (amt * BMConfig.XIANSHI_SELL_RATE) .. " 灵韵")
            end
        end
    end

    amountLabel = UI.Label {
        text = "数量: 1",
        fontSize = T.fontSize.md, fontWeight = "bold",
        fontColor = {255, 255, 255, 255},
        textAlign = "center",
    }

    costLabel = UI.Label {
        text = costText,
        fontSize = T.fontSize.xs,
        fontColor = C.xianshiColor,
        textAlign = "center",
    }

    exchangeDialog_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        onClick = function()
            BlackMerchantUI.HideExchangeDialog()
        end,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = C.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = C.cardBorder,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function() end,  -- 阻止穿透关闭
                children = {
                    -- 标题
                    UI.Label {
                        text = titleText,
                        fontSize = T.fontSize.lg, fontWeight = "bold",
                        fontColor = C.titleGold,
                        textAlign = "center", width = "100%",
                    },
                    -- 汇率说明
                    UI.Label {
                        text = descText,
                        fontSize = T.fontSize.xs,
                        fontColor = C.textMuted,
                        textAlign = "center", width = "100%",
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = C.separator },
                    -- 数量文字
                    amountLabel,
                    -- 滑块（用 +/- 按钮模拟）
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        justifyContent = "center", alignItems = "center",
                        gap = T.spacing.md,
                        children = {
                            UI.Button {
                                text = "-5", width = 44, height = 32,
                                fontSize = T.fontSize.sm, borderRadius = T.radius.sm,
                                backgroundColor = {80, 60, 120, 220},
                                onClick = function()
                                    UpdatePreview(math.max(1, exchangeAmount_ - 5))
                                end,
                            },
                            UI.Button {
                                text = "-1", width = 36, height = 32,
                                fontSize = T.fontSize.sm, borderRadius = T.radius.sm,
                                backgroundColor = {80, 60, 120, 220},
                                onClick = function()
                                    UpdatePreview(math.max(1, exchangeAmount_ - 1))
                                end,
                            },
                            UI.Button {
                                text = "+1", width = 36, height = 32,
                                fontSize = T.fontSize.sm, borderRadius = T.radius.sm,
                                backgroundColor = {80, 60, 120, 220},
                                onClick = function()
                                    UpdatePreview(math.min(maxAmount, exchangeAmount_ + 1))
                                end,
                            },
                            UI.Button {
                                text = "+5", width = 44, height = 32,
                                fontSize = T.fontSize.sm, borderRadius = T.radius.sm,
                                backgroundColor = {80, 60, 120, 220},
                                onClick = function()
                                    UpdatePreview(math.min(maxAmount, exchangeAmount_ + 5))
                                end,
                            },
                            UI.Button {
                                text = "MAX", width = 48, height = 32,
                                fontSize = T.fontSize.xs, fontWeight = "bold",
                                borderRadius = T.radius.sm,
                                backgroundColor = {100, 80, 140, 220},
                                onClick = function()
                                    if maxAmount >= 1 then
                                        UpdatePreview(maxAmount)
                                    end
                                end,
                            },
                        },
                    },
                    -- 消耗预览
                    costLabel,
                    -- 确认按钮
                    UI.Button {
                        text = canConfirm and "确认兑换" or "数量不足",
                        width = "100%", height = T.size.dialogBtnH,
                        fontSize = T.fontSize.md, fontWeight = "bold",
                        borderRadius = T.radius.md,
                        backgroundColor = canConfirm and C.buyBtnColor or C.disabledBtn,
                        onClick = function()
                            if not canConfirm then return end
                            if exchangeAmount_ < 1 then return end

                            -- 灵韵→仙石：客户端先扣灵韵
                            if direction == "buy" then
                                local cost = exchangeAmount_ * BMConfig.XIANSHI_BUY_RATE
                                local player2 = GameState.player
                                if player2 and player2.lingYun >= cost then
                                    player2.lingYun = player2.lingYun - cost
                                    pendingExchangeLingYunCost_ = cost  -- 记录预扣金额
                                else
                                    SetStatus("灵韵不足", C.textError)
                                    BlackMerchantUI.HideExchangeDialog()
                                    return
                                end
                            end

                            SendExchange(direction, exchangeAmount_)
                            SetStatus("兑换中...", C.xianshiColor)
                            BlackMerchantUI.HideExchangeDialog()
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(exchangeDialog_)
    exchangeVisible_ = true
end

function BlackMerchantUI.HideExchangeDialog()
    if exchangeDialog_ then
        exchangeDialog_:SetVisible(false)
        if parentOverlay_ then
            parentOverlay_:RemoveChild(exchangeDialog_)
        end
        exchangeDialog_ = nil
    end
    exchangeVisible_ = false
end

-- ============================================================================
-- Create / Show / Hide
-- ============================================================================

function BlackMerchantUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    -- 状态提示
    statusLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = C.textMuted,
        textAlign = "center",
    }

    -- 仙石余额
    currencyLabel_ = UI.Label {
        text = "仙石: 0",
        fontSize = T.fontSize.md, fontWeight = "bold",
        fontColor = C.xianshiColor,
    }

    -- 第一行页签按钮
    tabBtnConsumableMat_ = UI.Button {
        text = BMConfig.CATEGORY_NAMES.consumable_mat,
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabActive,
        onClick = function() SetActiveTab("consumable_mat") end,
    }
    tabBtnHerb_ = UI.Button {
        text = BMConfig.CATEGORY_NAMES.herb,
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabInactive,
        onClick = function() SetActiveTab("herb") end,
    }
    -- tabBtnEvent_ 活动已下架
    tabBtnLingyu_ = UI.Button {
        text = BMConfig.CATEGORY_NAMES.lingyu,
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabInactive,
        onClick = function() SetActiveTab("lingyu") end,
    }
    tabBtnSpecialEquip_ = UI.Button {
        text = BMConfig.CATEGORY_NAMES.special_equip,
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabInactive,
        onClick = function() SetActiveTab("special_equip") end,
    }
    tabBtnSkillBook_ = UI.Button {
        text = BMConfig.CATEGORY_NAMES.skill_book,
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabInactive,
        onClick = function() SetActiveTab("skill_book") end,
    }
    tabBtnHistory_ = UI.Button {
        text = "记录",
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabInactive,
        onClick = function() SetActiveTab("history") end,
    }
    -- 第二行页签按钮（神器碎片）
    tabBtnRake_ = UI.Button {
        text = BMConfig.CATEGORY_NAMES.rake,
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabInactive,
        onClick = function() SetActiveTab("rake") end,
    }
    tabBtnBagua_ = UI.Button {
        text = BMConfig.CATEGORY_NAMES.bagua,
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabInactive,
        onClick = function() SetActiveTab("bagua") end,
    }
    tabBtnTiandi_ = UI.Button {
        text = BMConfig.CATEGORY_NAMES.tiandi,
        flexGrow = 1, height = 28,
        fontSize = T.fontSize.xs, fontWeight = "bold",
        borderRadius = T.radius.xs,
        backgroundColor = C.tabInactive,
        onClick = function() SetActiveTab("tiandi") end,
    }

    -- 动态内容区（双列网格）
    contentPanel_ = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = T.spacing.sm,
        justifyContent = "space-between",
    }

    panel_ = UI.Panel {
        id = "blackMerchantPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 120},
        justifyContent = "center",
        alignItems = "center",
        paddingBottom = T.spacing.xl,
        visible = false,
        zIndex = 100,
        onClick = function() BlackMerchantUI.Hide() end,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = T.size.npcPanelMaxW,
                maxHeight = "85%",
                backgroundColor = C.panelBg,
                onClick = function() end,  -- 阻止穿透到遮罩关闭
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {140, 110, 60, 200},
                overflow = "scroll",
                children = {
                    -- ==========================================
                    -- 上半区：NPC 肖像 + 对话
                    -- ==========================================
                    UI.Panel {
                        width = "100%",
                        backgroundColor = C.headerBg,
                        borderTopLeftRadius = T.radius.lg,
                        borderTopRightRadius = T.radius.lg,
                        padding = T.spacing.md,
                        gap = T.spacing.sm,
                        children = {
                            -- 行1：关闭按钮 + 肖像 + 名称/头衔
                            UI.Panel {
                                width = "100%", flexDirection = "row",
                                alignItems = "center",
                                gap = T.spacing.md,
                                children = {
                                    -- 关闭按钮（左侧）
                                    UI.Button {
                                        text = "✕",
                                        width = T.size.closeButton,
                                        height = T.size.closeButton,
                                        fontSize = T.fontSize.md,
                                        borderRadius = T.size.closeButton / 2,
                                        backgroundColor = {60, 60, 70, 200},
                                        onClick = function() BlackMerchantUI.Hide() end,
                                    },
                                    -- NPC 肖像
                                    UI.Panel {
                                        width = PORTRAIT_SIZE,
                                        height = PORTRAIT_SIZE,
                                        borderRadius = T.radius.md,
                                        backgroundColor = {30, 25, 45, 200},
                                        overflow = "hidden",
                                        borderWidth = 2,
                                        borderColor = {180, 160, 100, 200},
                                        children = {
                                            UI.Panel {
                                                width = "100%",
                                                height = "100%",
                                                backgroundImage = "Textures/npc_yin.png",
                                                backgroundFit = "contain",
                                            },
                                        },
                                    },
                                    -- 名称 + 头衔
                                    UI.Panel {
                                        flexGrow = 1, flexShrink = 1,
                                        gap = 2,
                                        children = {
                                            UI.Label {
                                                text = NPC_NAME,
                                                fontSize = T.fontSize.lg, fontWeight = "bold",
                                                fontColor = C.npcNameColor,
                                            },
                                            UI.Label {
                                                text = NPC_TITLE,
                                                fontSize = T.fontSize.xs,
                                                fontColor = C.npcTitleColor,
                                            },
                                        },
                                    },
                                },
                            },
                            -- NPC 对话气泡
                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.dialogueBg,
                                borderRadius = T.radius.sm,
                                padding = T.spacing.sm,
                                children = {
                                    UI.Label {
                                        text = "欢迎来到万界商行。\n万物皆有价，买卖凭仙石。",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {200, 200, 180, 240},
                                        width = "100%",
                                    },
                                    UI.Label {
                                        text = "⚠ 商店库存全部来自其他修士的寄售，无官方补货，售空即止。",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {255, 210, 80, 255},
                                        width = "100%",
                                        marginTop = 4,
                                    },
                                    UI.Label {
                                        text = "胤每天也会采购货物，满库存的商品可能被收走。",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {180, 220, 255, 240},
                                        width = "100%",
                                        marginTop = 4,
                                    },
                                    UI.Label {
                                        text = "灵韵可兑仙石，仙石亦可换灵韵（折损五成）。",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {200, 200, 180, 240},
                                        width = "100%",
                                        marginTop = 4,
                                    },
                                },
                            },
                        },
                    },
                    -- ==========================================
                    -- 工具栏：仙石余额 + 兑换 + 标签页
                    -- ==========================================
                    UI.Panel {
                        width = "100%",
                        padding = T.spacing.md,
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.sm,
                        gap = T.spacing.sm,
                        children = {
                            -- 仙石行：余额 + 兑换按钮
                            UI.Panel {
                                width = "100%", flexDirection = "row",
                                alignItems = "center",
                                justifyContent = "space-between",
                                children = {
                                    currencyLabel_,
                                    UI.Panel {
                                        flexDirection = "row", gap = T.spacing.xs,
                                        children = {
                                            UI.Button {
                                                text = "皮肤",
                                                width = 52, height = 28,
                                                fontSize = 11, fontWeight = "bold",
                                                borderRadius = T.radius.sm,
                                                backgroundColor = {140, 60, 100, 220},
                                                onClick = function()
                                                    BlackMerchantUI.Hide()
                                                    local SkinShopUI = require("ui.SkinShopUI")
                                                    SkinShopUI.Show({ onClose = function()
                                                        BlackMerchantUI.Show()
                                                    end })
                                                end,
                                            },
                                            UI.Button {
                                                text = "灵韵→仙石",
                                                width = 86, height = 28,
                                                fontSize = 11, fontWeight = "bold",
                                                borderRadius = T.radius.sm,
                                                backgroundColor = {100, 70, 160, 220},
                                                onClick = function()
                                                    if not realmOk_ then
                                                        SetStatus("需筑基初期以上", C.textError)
                                                        return
                                                    end
                                                    ShowExchangeDialog("buy")
                                                end,
                                            },
                                            UI.Button {
                                                text = "仙石→灵韵",
                                                width = 86, height = 28,
                                                fontSize = 11, fontWeight = "bold",
                                                borderRadius = T.radius.sm,
                                                backgroundColor = {60, 120, 130, 220},
                                                onClick = function()
                                                    if not realmOk_ then
                                                        SetStatus("需筑基初期以上", C.textError)
                                                        return
                                                    end
                                                    ShowExchangeDialog("sell")
                                                end,
                                            },
                                        },
                                    },
                                },
                            },
                            -- 分隔线
                            UI.Panel { width = "100%", height = 1, backgroundColor = C.separator },
                            -- 标签页栏（双行）
                            -- 第一行：消耗品 · 草药 · 附灵玉 · 特殊装备 · 技能书 · 记录
                            UI.Panel {
                                width = "100%", flexDirection = "row",
                                gap = T.spacing.xs,
                                children = {
                                    tabBtnConsumableMat_,
                                    tabBtnHerb_,
                                    -- tabBtnEvent_,  -- 活动已下架
                                    tabBtnLingyu_,
                                    tabBtnSpecialEquip_,
                                    tabBtnSkillBook_,
                                    tabBtnHistory_,
                                },
                            },
                            -- 第二行：神器碎片
                            UI.Panel {
                                width = "100%", flexDirection = "row",
                                gap = T.spacing.xs,
                                children = {
                                    UI.Label {
                                        text = "神器",
                                        fontSize = 10,
                                        fontColor = C.textMuted,
                                        width = 24, textAlign = "center",
                                        alignSelf = "center",
                                    },
                                    tabBtnRake_,
                                    tabBtnBagua_,
                                    tabBtnTiandi_,
                                },
                            },
                            -- 状态提示
                            statusLabel_,
                        },
                    },
                    -- ==========================================
                    -- 下半区：商品货柜（双列竖卡网格）
                    -- ==========================================
                    UI.Panel {
                        width = "100%",
                        paddingLeft = T.spacing.md,
                        paddingRight = T.spacing.md,
                        paddingBottom = T.spacing.md,
                        children = {
                            contentPanel_,
                        },
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)
end

function BlackMerchantUI.Show()
    if not panel_ then return end

    -- 重置状态
    activeTab_ = "consumable_mat"
    dataLoaded_ = false
    pendingRequest_ = false
    pollTimer_ = 0

    -- 更新标签按钮
    if tabBtnConsumableMat_ then tabBtnConsumableMat_:SetStyle({ backgroundColor = C.tabActive }) end
    if tabBtnHerb_ then tabBtnHerb_:SetStyle({ backgroundColor = C.tabInactive }) end
    -- if tabBtnEvent_ then tabBtnEvent_:SetStyle({ backgroundColor = C.tabInactive }) end  -- 活动已下架
    if tabBtnRake_ then tabBtnRake_:SetStyle({ backgroundColor = C.tabInactive }) end
    if tabBtnBagua_ then tabBtnBagua_:SetStyle({ backgroundColor = C.tabInactive }) end
    if tabBtnTiandi_ then tabBtnTiandi_:SetStyle({ backgroundColor = C.tabInactive }) end
    if tabBtnLingyu_ then tabBtnLingyu_:SetStyle({ backgroundColor = C.tabInactive }) end
    if tabBtnSpecialEquip_ then tabBtnSpecialEquip_:SetStyle({ backgroundColor = C.tabInactive }) end
    if tabBtnSkillBook_ then tabBtnSkillBook_:SetStyle({ backgroundColor = C.tabInactive }) end
    if tabBtnHistory_ then tabBtnHistory_:SetStyle({ backgroundColor = C.tabInactive }) end

    panel_:SetVisible(true)
    visible_ = true
    SetStatus("加载中...", C.xianshiColor)

    -- 先用缓存数据刷一次内容（避免空白）
    BlackMerchantUI.RefreshContent()

    -- 再发起网络查询，响应后会再次刷新
    SendQuery()
end

function BlackMerchantUI.Hide()
    if not panel_ then return end
    panel_:SetVisible(false)
    visible_ = false
    pendingRequest_ = false
    HideConfirmDialog()
    BlackMerchantUI.HideExchangeDialog()
end

function BlackMerchantUI.IsVisible()
    return visible_
end

-- ============================================================================
-- 轮询 Update（由 main.lua HandleUpdate 调用，不要单独 SubscribeToEvent）
-- ============================================================================

function BlackMerchantUI.Update(dt)
    if not visible_ then return end
    pollTimer_ = pollTimer_ + dt
    if pollTimer_ >= POLL_INTERVAL then
        pollTimer_ = 0
        SendQuery()
    end

    -- 确认弹窗倒计时
    if confirmDialog_ and confirmTimer_ > 0 then
        confirmTimer_ = confirmTimer_ - dt
        if confirmTimer_ <= 0 then
            HideConfirmDialog()
        elseif confirmBtnRef_ then
            local sec = math.ceil(confirmTimer_)
            confirmBtnRef_:SetText(confirmBtnText_ .. " (" .. sec .. ")")
        end
    end
end

-- ============================================================================
-- S2C 事件处理
-- ============================================================================

--- S2C_BMData：商品查询响应
function BlackMerchantUI_HandleBMData(eventType, eventData)
    print("[BlackMerchantUI] === HandleBMData RECEIVED ===")
    pendingRequest_ = false

    local ok = eventData["ok"]:GetBool()
    if not ok then
        local reason = eventData["reason"]:GetString()
        print("[BlackMerchantUI] HandleBMData: ok=false reason=" .. tostring(reason))
        SetStatus(reason, C.textError)
        return
    end

    dataLoaded_ = true
    print("[BlackMerchantUI] HandleBMData: ok=true, setting dataLoaded_=true")
    realmOk_ = eventData["realm_ok"]:GetBool()
    xianshi_ = eventData["xianshi"]:GetInt()

    -- 解析 items JSON
    local itemsJson = eventData["items"]:GetString()
    local success, decoded = pcall(cjson.decode, itemsJson)
    if success and type(decoded) == "table" then
        items_ = decoded
    end

    -- WAL 补偿：加灵韵到客户端
    local walOk, walComp = pcall(function()
        return eventData["walCompensation"]:GetInt()
    end)
    if walOk and walComp and walComp > 0 then
        local player = GameState.player
        if player then
            player.lingYun = player.lingYun + walComp
            EventBus.Emit("save_request")
            print("[BlackMerchantUI] WAL compensation: +" .. walComp .. " lingYun")
            SetStatus("补偿到账: +" .. walComp .. " 灵韵", C.textSuccess)
        end
    else
        SetStatusSoft("", C.textMuted)
    end

    RefreshCurrency()
    BlackMerchantUI.RefreshContent()
end

--- S2C_BMResult：买/卖交易结果
function BlackMerchantUI_HandleBMResult(eventType, eventData)
    pendingRequest_ = false

    local ok = eventData["ok"]:GetBool()
    if not ok then
        local reason = eventData["reason"]:GetString()
        SetStatus(reason, C.textError, 3)
        -- 交易失败，自动刷新数据（库存/余额可能已变）
        pollTimer_ = 0
        SendQuery()
        return
    end

    local action = eventData["action"]:GetString()
    local itemId = eventData["id"]:GetString()
    local amount = eventData["amount"]:GetInt()
    local newXianshi = eventData["newXianshi"]:GetInt()
    local newStock = eventData["newStock"]:GetInt()
    local newHeld = eventData["newHeld"]:GetInt()

    -- 更新缓存
    xianshi_ = newXianshi
    if not items_[itemId] then items_[itemId] = {} end
    items_[itemId].stock = newStock
    items_[itemId].held = newHeld

    local cfg = BMConfig.ITEMS[itemId]
    local itemName = cfg and cfg.name or itemId

    -- 同步客户端背包：买入加物品，卖出扣物品（区分装备/消耗品）
    local isEquip = cfg and cfg.itemType == "equipment"
    if action == "buy" then
        if isEquip then
            for _ = 1, amount do
                local newEquip = LootSystem.CreateSpecialEquipment(cfg.equipId)
                if newEquip then
                    InventorySystem.AddItem(newEquip)
                end
            end
        else
            InventorySystem.AddConsumable(itemId, amount)
        end
        EventBus.Emit("save_request")
        SetStatus("购入 " .. itemName .. " ×" .. amount, C.textSuccess)
    else
        -- HOTFIX-BM-01: 跟踪本地扣除是否成功
        local localDeductOk = false
        if isEquip then
            -- 按 equipId 匹配移除装备（不论附魔/洗练状态）
            local manager = InventorySystem.GetManager()
            if manager then
                local remaining = amount
                for i = 1, GameConfig.BACKPACK_SIZE do
                    if remaining <= 0 then break end
                    local item = manager:GetInventoryItem(i)
                    if item and item.category ~= "consumable"
                        and item.equipId == cfg.equipId then
                        manager:SetInventoryItem(i, nil)
                        remaining = remaining - 1
                    end
                end
                localDeductOk = (remaining <= 0)
            end
        else
            localDeductOk = InventorySystem.ConsumeConsumable(itemId, amount)
        end
        -- HOTFIX-BM-01: 本地扣除失败 → 不请求保存（防止仓库副本覆盖服务端已扣数据）
        if localDeductOk then
            EventBus.Emit("save_request")
            SetStatus("售出 " .. itemName .. " ×" .. amount, C.textSuccess)
        else
            print("[BlackMerchantUI] WARNING: sell ok but local deduct FAILED for "
                .. tostring(itemId) .. " x" .. tostring(amount)
                .. " — save_request SUPPRESSED to prevent warehouse duplication")
            SetStatus("售出成功，但本地同步异常，请重新加载", C.textError, 5)
        end
    end

    RefreshCurrency()
    BlackMerchantUI.RefreshContent()
end

--- S2C_BMExchangeResult：兑换结果
function BlackMerchantUI_HandleBMExchangeResult(eventType, eventData)
    pendingRequest_ = false

    local ok = eventData["ok"]:GetBool()
    if not ok then
        local reason = eventData["reason"]:GetString()
        SetStatus(reason, C.textError, 3)
        -- 兑换失败，自动刷新数据
        pollTimer_ = 0
        SendQuery()
        -- 兑换失败且是灵韵→仙石方向：回退已扣的灵韵
        if pendingExchangeLingYunCost_ > 0 then
            local player = GameState.player
            if player then
                player.lingYun = player.lingYun + pendingExchangeLingYunCost_
                print("[BlackMerchantUI] Exchange buy failed, refunded "
                    .. pendingExchangeLingYunCost_ .. " lingYun")
            end
            pendingExchangeLingYunCost_ = 0
        end
        return
    end

    local direction = eventData["direction"]:GetString()
    local amount = eventData["amount"]:GetInt()
    local newXianshi = eventData["newXianshi"]:GetInt()
    local lingYunDelta = eventData["lingYunDelta"]:GetInt()

    -- 清零预扣记录
    pendingExchangeLingYunCost_ = 0

    -- 更新仙石
    xianshi_ = newXianshi

    -- 更新灵韵（仙石→灵韵：服务端通知客户端加灵韵）
    if lingYunDelta ~= 0 then
        local player = GameState.player
        if player then
            if direction == "sell" then
                -- 仙石→灵韵：服务端返回正数灵韵增量
                player.lingYun = player.lingYun + lingYunDelta
            end
            -- direction == "buy" 时灵韵已在客户端预扣，无需再处理
            EventBus.Emit("save_request")
        end
    end

    if direction == "buy" then
        SetStatus("兑入 " .. amount .. " 仙石", C.textSuccess)
    else
        SetStatus("兑出 " .. amount .. " 仙石 → " .. (amount * BMConfig.XIANSHI_SELL_RATE) .. " 灵韵", C.textSuccess)
    end

    RefreshCurrency()
    BlackMerchantUI.RefreshContent()
end

--- S2C_BMHistory：交易记录响应
function BlackMerchantUI_HandleBMHistory(eventType, eventData)
    pendingRequest_ = false

    local ok = eventData["ok"]:GetBool()
    if not ok then
        local reason = eventData["reason"]:GetString()
        SetStatus(reason, C.textError)
        return
    end

    local recordsJson = eventData["records"]:GetString()
    local success, decoded = pcall(cjson.decode, recordsJson)
    if success and type(decoded) == "table" then
        tradeRecords_ = decoded
    else
        tradeRecords_ = {}
    end

    SetStatus("", C.textMuted)
    BlackMerchantUI.RefreshContent()
end

-- ============================================================================
-- S2C 事件注册（模块加载时自动注册）
-- ============================================================================

do
    SubscribeToEvent(SaveProtocol.S2C_BlackMerchantData, "BlackMerchantUI_HandleBMData")
    SubscribeToEvent(SaveProtocol.S2C_BlackMerchantResult, "BlackMerchantUI_HandleBMResult")
    SubscribeToEvent(SaveProtocol.S2C_BlackMerchantExchangeResult, "BlackMerchantUI_HandleBMExchangeResult")
    SubscribeToEvent(SaveProtocol.S2C_BlackMerchantHistory, "BlackMerchantUI_HandleBMHistory")
end

return BlackMerchantUI
