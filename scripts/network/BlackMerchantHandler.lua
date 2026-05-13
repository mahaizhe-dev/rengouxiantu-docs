-- ============================================================================
-- BlackMerchantHandler.lua — 万界黑商服务端 Handler
--
-- 职责：Query / Buy / Sell / Exchange / History 五个 C2S 处理
-- 设计文档：docs/设计文档/万界黑商.md v0.8
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local BMConfig = require("config.BlackMerchantConfig")
local TradeLogger = require("network.BlackMerchantTradeLogger")

local BackpackUtils = require("network.BackpackUtils")
local LootSystem = require("systems.LootSystem")
local SellGuard = require("network.BlackMarketSellGuard")
local TradeLock = require("systems.BlackMarketTradeLock")

local cjson = cjson ---@diagnostic disable-line: undefined-global

local M = {}

-- 缓存玩家境界（connKey -> { ok = bool, realm = string }）
local playerRealms_ = {}

-- §8 服务端内存锁：防止同一玩家并发买/卖请求
local buyActive_  = {}  -- connKey -> true
local sellActive_ = {}  -- connKey -> true

-- P0: SYSTEM_UID 库存缓存（避免每次 Query 都读 serverCloud.money:Get(SYSTEM_UID)）
local systemStockCache_ = nil   -- { moneys = table, ts = number }
local SYSTEM_STOCK_TTL = 10     -- 缓存有效期（秒）

--- 获取系统库存（带缓存），callback(systemMoneys)
---@param callback fun(moneys: table)
---@param errCallback fun(code: any, reason: any)
local function GetSystemStockCached(callback, errCallback)
    local now = os.time()
    if systemStockCache_ and (now - systemStockCache_.ts) < SYSTEM_STOCK_TTL then
        callback(systemStockCache_.moneys)
        return
    end
    serverCloud.money:Get(BMConfig.SYSTEM_UID, {
        ok = function(moneys)
            systemStockCache_ = { moneys = moneys, ts = os.time() }
            callback(moneys)
        end,
        error = errCallback,
    })
end

--- Buy/Sell 成功后使缓存失效，确保下次 Query 读到最新值
local function InvalidateSystemStockCache()
    systemStockCache_ = nil
end

-- 背包操作委托给 BackpackUtils 共享模块（EventHandler 等也使用同一模块）
local CountBackpackItem  = BackpackUtils.CountBackpackItem
local AddToBackpack      = BackpackUtils.AddToBackpack
local RemoveFromBackpack = BackpackUtils.RemoveFromBackpack
local MAX_BACKPACK_SLOTS = BackpackUtils.MAX_BACKPACK_SLOTS
local MAX_STACK          = BackpackUtils.MAX_STACK
-- 装备操作（v0.10 新增）
local CountEquipmentItem          = BackpackUtils.CountEquipmentItem
local AddEquipmentToBackpack      = BackpackUtils.AddEquipmentToBackpack
local RemoveEquipmentFromBackpack = BackpackUtils.RemoveEquipmentFromBackpack

--- 判断商品是否为装备类
---@param itemId string
---@return boolean
local function IsEquipmentItem(itemId)
    local cfg = BMConfig.ITEMS[itemId]
    return cfg and cfg.itemType == "equipment"
end

--- 统计玩家背包中该商品的持有量（自动区分消耗品/装备）
---@param backpack table
---@param itemId string
---@return integer
local function CountItemHeld(backpack, itemId)
    if IsEquipmentItem(itemId) then
        local cfg = BMConfig.ITEMS[itemId]
        return CountEquipmentItem(backpack, cfg.equipId or itemId)
    else
        return CountBackpackItem(backpack, itemId)
    end
end

--- 将修改后的存档回写到 serverCloud（best-effort）
---@param userId integer
---@param slot number
---@param saveData table
---@param desc string
---@param onOk fun()|nil
---@param onError fun()|nil
local function WriteSaveBack(userId, slot, saveData, desc, onOk, onError)
    local saveKey = "save_" .. slot
    saveData.timestamp = os.time()
    serverCloud:BatchSet(userId)
        :Set(saveKey, saveData)
        :Save(desc, {
            ok = function()
                print("[BlackMerchant] SaveBack OK: " .. desc)
                if onOk then onOk() end
            end,
            error = function(code, reason)
                print("[BlackMerchant] SaveBack FAILED: " .. desc
                    .. " code=" .. tostring(code) .. " " .. tostring(reason))
                if onError then onError() end
            end,
        })
end

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 从 connection 提取 connKey + userId，校验基本前置条件
---@return string|nil connKey
---@return integer|nil userId
---@return any connection
local function ExtractContext(eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Session.ConnKey(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then
        return nil, nil, connection
    end
    -- 必须有活跃存档
    if not Session.connSlots_[connKey] then
        return nil, nil, connection
    end
    return connKey, userId, connection
end

--- 发送错误响应（通用）
local function SendError(connection, eventName, reason, extra)
    local data = VariantMap()
    data["ok"] = Variant(false)
    data["reason"] = Variant(reason or "unknown")
    if extra then
        for k, v in pairs(extra) do
            data[k] = v
        end
    end
    Session.SafeSend(connection, eventName, data)
end

--- 检查境界是否 >= 筑基初期
---@param connKey string
---@return boolean
local function IsRealmOk(connKey)
    local cached = playerRealms_[connKey]
    if cached then
        return cached.ok
    end
    return false
end

--- 异步读取玩家境界（每次从存档重新读取，确保突破后立即生效）
--- callback 同时透传 saveData 和 slot，供后续操作背包使用
---@param connKey string
---@param userId integer
---@param callback fun(realmOk: boolean, saveData: table|nil, slot: number|nil)
local function EnsureRealmCached(connKey, userId, callback)
    local slot = Session.connSlots_[connKey]
    if not slot then
        callback(false, nil, nil)
        return
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData or not saveData.player then
            playerRealms_[connKey] = { ok = false, realm = "unknown" }
            callback(false, saveData, slot)
            return
        end

        local realm = saveData.player.realm or "mortal"
        local GameConfig = require("config.GameConfig")
        local realmData = GameConfig.REALMS[realm]
        local order = realmData and realmData.order or 0
        local ok = order >= BMConfig.JINDAN_ORDER

        playerRealms_[connKey] = { ok = ok, realm = realm }
        callback(ok, saveData, slot)
    end)
end

-- ============================================================================
-- HandleQuery — 查询全部商品库存 + 玩家仙石 + 持有量
-- ============================================================================

function M.HandleQuery(eventType, eventData)
    print("[BlackMerchant][Query] === HandleQuery START ===")
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then
        print("[BlackMerchant][Query] ExtractContext failed: no userId or no slot")
        return
    end
    print("[BlackMerchant][Query] connKey=" .. tostring(connKey) .. " userId=" .. tostring(userId))

    -- 1. 异步获取境界 + 存档（saveData 包含 backpack）
    EnsureRealmCached(connKey, userId, function(realmOk, saveData, slot)
        print("[BlackMerchant][Query] EnsureRealmCached done: realmOk=" .. tostring(realmOk) .. " hasData=" .. tostring(saveData ~= nil) .. " slot=" .. tostring(slot))
        local backpack = saveData and saveData.backpack or {}

        -- 2. 读取玩家 Money 域（仙石）
        serverCloud.money:Get(userId, {
            ok = function(playerMoneys)
                print("[BlackMerchant][Query] playerMoney ok, xianshi=" .. tostring(playerMoneys.xianshi))
                -- 3. 读取系统 Money 域（16 种库存）— P0: 使用缓存
                GetSystemStockCached(function(systemMoneys)
                        print("[BlackMerchant][Query] systemStock ok")
                        -- 4. 检查 WAL 补偿
                        local walCompensation = nil
                        serverCloud.list:Get(userId, BMConfig.WAL_KEY, {
                            ok = function(walList)
                                if #walList > 0 then
                                    -- 有未完成的 WAL，计算补偿灵韵
                                    local totalLingYun = 0
                                    for _, item in ipairs(walList) do
                                        local val = item.value
                                        if val and val.lingYunGain then
                                            totalLingYun = totalLingYun + val.lingYunGain
                                        end
                                        -- 清除 WAL 条目
                                        if item.list_id then
                                            serverCloud.list:Delete(item.list_id)
                                        end
                                    end
                                    if totalLingYun > 0 then
                                        walCompensation = totalLingYun
                                    end
                                end

                                -- 5. 组装响应（从 backpack 读持有量）
                                M._SendQueryResponse(connection, realmOk,
                                    playerMoneys, systemMoneys, walCompensation, backpack)
                            end,
                            error = function(code, reason)
                                print("[BlackMerchant][Query] WAL check failed: "
                                    .. tostring(reason))
                                -- WAL 检查失败不阻塞查询
                                M._SendQueryResponse(connection, realmOk,
                                    playerMoneys, systemMoneys, nil, backpack)
                            end,
                        })
                end, function(code, reason)
                    print("[BlackMerchant][Query] System money get failed: "
                        .. tostring(reason))
                    SendError(connection, SaveProtocol.S2C_BlackMerchantData,
                        "服务器忙，请稍后重试")
                end)
            end,
            error = function(code, reason)
                print("[BlackMerchant][Query] Player money get failed: "
                    .. tostring(reason))
                SendError(connection, SaveProtocol.S2C_BlackMerchantData,
                    "服务器忙，请稍后重试")
            end,
        })
    end)
end

--- 组装并发送 Query 响应（held 从 backpack 统计）
function M._SendQueryResponse(connection, realmOk, playerMoneys, systemMoneys, walCompensation, backpack)
    print("[BlackMerchant][Query] _SendQueryResponse: realmOk=" .. tostring(realmOk) .. " itemCount=" .. #BMConfig.ITEM_IDS)
    local data = VariantMap()
    data["ok"] = Variant(true)
    data["realm_ok"] = Variant(realmOk)
    data["xianshi"] = Variant(playerMoneys.xianshi or 0)

    -- 构建 items JSON（held 从存档 backpack 统计，而非 money 域）
    local items = {}
    for _, id in ipairs(BMConfig.ITEM_IDS) do
        local cfg = BMConfig.ITEMS[id]
        items[id] = {
            stock = systemMoneys[BMConfig.StockKey(id)] or 0,
            buy_price = cfg.buy_price,
            sell_price = cfg.sell_price,
            held = CountItemHeld(backpack, id),
        }
    end
    local encOk, itemsJson = pcall(cjson.encode, items)
    if not encOk then
        print("[BlackMerchant] JSON encode failed (items): " .. tostring(itemsJson))
        SendError(connection, SaveProtocol.S2C_BlackMerchantData, "server error")
        return
    end
    data["items"] = Variant(itemsJson)
    print("[BlackMerchant][Query] JSON encode ok, len=" .. #itemsJson)

    if walCompensation then
        data["walCompensation"] = Variant(walCompensation)
    end

    Session.SafeSend(connection, SaveProtocol.S2C_BlackMerchantData, data)
    print("[BlackMerchant][Query] === HandleQuery SENT ===")
end

-- ============================================================================
-- HandleBuy — 从黑商购买物品（玩家花仙石）
-- ============================================================================

function M.HandleBuy(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    -- §8 内存锁
    if buyActive_[connKey] then
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "操作过于频繁")
        return
    end
    buyActive_[connKey] = true

    local ok1, consumableId = pcall(function() return eventData["consumableId"]:GetString() end)
    local ok2, amount = pcall(function() return eventData["amount"]:GetInt() end)
    if not ok1 or not ok2 then
        buyActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "invalid request")
        return
    end

    print("[BlackMerchant][Buy] userId=" .. tostring(userId)
        .. " id=" .. consumableId .. " amount=" .. tostring(amount))

    -- 1. 境界校验
    if not IsRealmOk(connKey) then
        buyActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
            "境界不足，需筑基初期以上")
        return
    end

    -- 2. 白名单校验
    local cfg = BMConfig.ITEMS[consumableId]
    if not cfg then
        buyActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "无效商品")
        return
    end

    -- 3. amount 校验
    if not amount or amount < 1 then
        buyActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "数量无效")
        return
    end

    local total = cfg.sell_price * amount
    local slot = Session.connSlots_[connKey]

    -- 4. 前置校验：读取玩家仙石 + 系统库存
    serverCloud.money:Get(userId, {
        ok = function(playerMoneys)
            local xianshi = playerMoneys.xianshi or 0
            if xianshi < total then
                buyActive_[connKey] = nil
                SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                    "仙石不足", { ["need"] = Variant(total), ["have"] = Variant(xianshi) })
                return
            end

            serverCloud.money:Get(BMConfig.SYSTEM_UID, {
                ok = function(systemMoneys)
                    local stock = systemMoneys[BMConfig.StockKey(consumableId)] or 0
                    if stock < amount then
                        buyActive_[connKey] = nil
                        SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                            "库存不足")
                        return
                    end

                    -- 5. BatchCommit: 扣仙石 + 出库 + 写背包 WAL
                    local isEquip = cfg.itemType == "equipment"
                    local commit = serverCloud:BatchCommit("黑商购买")
                    commit:MoneyCost(userId, "xianshi", total)
                    commit:MoneyCost(BMConfig.SYSTEM_UID, BMConfig.StockKey(consumableId), amount)
                    commit:ListAdd(userId, BMConfig.WAL_BP_KEY, {
                        consumableId = consumableId,
                        amount = amount,
                        name = cfg.name,
                        itemType = cfg.itemType,  -- "equipment" 或 nil
                        equipId = cfg.equipId,    -- 装备模板 ID（装备类才有）
                        t = os.time(),
                    })
                    commit:Commit({
                        ok = function()
                            local newXianshi = xianshi - total
                            local newStock = stock - amount

                            -- 6. 将碎片写入存档 backpack
                            Session.ServerGetSlotData(userId, slot, function(saveData)
                                if not saveData then
                                    buyActive_[connKey] = nil
                                    print("[BlackMerchant][Buy] WARN: saveData nil after commit, BP WAL will compensate on login")
                                    local resp = VariantMap()
                                    resp["ok"] = Variant(true)
                                    resp["action"] = Variant("buy")
                                    resp["id"] = Variant(consumableId)
                                    resp["amount"] = Variant(amount)
                                    resp["total"] = Variant(total)
                                    resp["newStock"] = Variant(newStock)
                                    resp["newXianshi"] = Variant(newXianshi)
                                    resp["newHeld"] = Variant(0)
                                    Session.SafeSend(connection,
                                        SaveProtocol.S2C_BlackMerchantResult, resp)
                                    return
                                end

                                local backpack = saveData.backpack or {}
                                local oldHeld = CountItemHeld(backpack, consumableId)
                                -- 装备类：逐件创建初始状态装备放入背包
                                -- 消耗品类：堆叠放入
                                -- BM-S4A: 为本次购入生成批次 ID
                                local batchId = TradeLock.GenerateBatchId()

                                if isEquip then
                                    for _ = 1, amount do
                                        local newEquip = LootSystem.CreateSpecialEquipment(cfg.equipId)
                                        if newEquip then
                                            AddEquipmentToBackpack(backpack, newEquip)
                                        end
                                    end
                                else
                                    -- BM-S4AR: 强制新建锁定堆叠，绝不合并到已有堆叠
                                    -- 替代旧的 AddToBackpack + 后置遍历锁定模式
                                    BackpackUtils.AddLockedNewStack(
                                        backpack, consumableId, amount, cfg.name, batchId
                                    )
                                end

                                saveData.backpack = backpack

                                local charName = (saveData.player and saveData.player.charName)
                                    or "修仙者"

                                --- 背包写入成功/失败的共用响应逻辑
                                local function SendBuyOk(desc)
                                    buyActive_[connKey] = nil
                                    local newHeld = oldHeld + amount
                                    TradeLogger.LogPublic(charName, "buy", consumableId,
                                        amount, cfg.sell_price, newXianshi)

                                    local resp = VariantMap()
                                    resp["ok"] = Variant(true)
                                    resp["action"] = Variant("buy")
                                    resp["id"] = Variant(consumableId)
                                    resp["amount"] = Variant(amount)
                                    resp["total"] = Variant(total)
                                    resp["newStock"] = Variant(newStock)
                                    resp["newXianshi"] = Variant(newXianshi)
                                    resp["newHeld"] = Variant(newHeld)
                                    Session.SafeSend(connection,
                                        SaveProtocol.S2C_BlackMerchantResult, resp)

                                    print("[BlackMerchant][Buy] " .. desc .. ": userId=" .. tostring(userId)
                                        .. " id=" .. consumableId .. " x" .. tostring(amount)
                                        .. " cost=" .. tostring(total))
                                end

                                WriteSaveBack(userId, slot, saveData,
                                    "黑商购买写入背包: " .. consumableId .. " x" .. amount,
                                    function() -- onOk: 背包已写入，清除 WAL
                                        -- 清除背包 WAL（best-effort）
                                        serverCloud.list:Get(userId, BMConfig.WAL_BP_KEY, {
                                            ok = function(walList)
                                                for _, item in ipairs(walList) do
                                                    if item.list_id then
                                                        serverCloud.list:Delete(item.list_id)
                                                    end
                                                end
                                            end,
                                            error = function() end,
                                        })
                                        InvalidateSystemStockCache()  -- P0
                                        SendBuyOk("OK")
                                    end,
                                    function() -- onError: 存档写入失败，WAL 保留，登录时补偿
                                        InvalidateSystemStockCache()  -- P0
                                        SendBuyOk("WARN save failed, BP WAL retained")
                                    end
                                )
                            end)
                        end,
                        error = function(code, reason)
                            buyActive_[connKey] = nil
                            local errStr = tostring(reason)
                            print("[BlackMerchant][Buy] BatchCommit FAILED: "
                                .. tostring(code) .. " " .. errStr)
                            local msg = "交易失败，请重试"
                            if errStr:find("balance") or errStr:find("insufficient") then
                                msg = "已被他人买走"
                            end
                            SendError(connection, SaveProtocol.S2C_BlackMerchantResult, msg)
                        end,
                    })
                end,
                error = function(code, reason)
                    buyActive_[connKey] = nil
                    SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                        "服务器忙，请稍后重试")
                end,
            })
        end,
        error = function(code, reason)
            buyActive_[connKey] = nil
            SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                "服务器忙，请稍后重试")
        end,
    })
end

-- ============================================================================
-- HandleSell — 向黑商出售物品（玩家得仙石）
-- ============================================================================

function M.HandleSell(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    -- §8 内存锁
    if sellActive_[connKey] then
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "操作过于频繁")
        return
    end
    sellActive_[connKey] = true

    local ok1, consumableId = pcall(function() return eventData["consumableId"]:GetString() end)
    local ok2, amount = pcall(function() return eventData["amount"]:GetInt() end)
    if not ok1 or not ok2 then
        sellActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "invalid request")
        return
    end

    print("[BlackMerchant][Sell] userId=" .. tostring(userId)
        .. " id=" .. consumableId .. " amount=" .. tostring(amount))

    -- 1. 境界校验
    if not IsRealmOk(connKey) then
        sellActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
            "境界不足，需筑基初期以上")
        return
    end

    -- 2. 白名单校验
    local cfg = BMConfig.ITEMS[consumableId]
    if not cfg then
        sellActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "无效商品")
        return
    end

    -- 2.5 BM-S4A: 卖出前置白名单校验（SellGuard 保留为后备，优先使用锁态检查）
    -- SellGuard 的全拦截已被 BM-S4A 锁机制替代，此处不再调用
    -- 实际的锁态校验在读取存档后进行（见下方 §4.5）

    -- 3. amount 校验
    if not amount or amount < 1 then
        sellActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "数量无效")
        return
    end

    local total = cfg.buy_price * amount
    local slot = Session.connSlots_[connKey]

    -- 4. 读取存档，从 backpack 验证持有量
    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            sellActive_[connKey] = nil
            SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                "存档读取失败，请重试")
            return
        end

        local backpack = saveData.backpack or {}
        local isEquip = cfg.itemType == "equipment"
        local held = CountItemHeld(backpack, consumableId)

        -- BM-S4C: 服务端整类禁售 — 消耗品存在任意锁堆则整类拒绝卖出
        if not isEquip and BackpackUtils.HasAnyLockedItem(backpack, consumableId) then
            sellActive_[connKey] = nil
            SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                "该商品处于黑市交易保护期，请稍后再试")
            return
        end

        -- 持有量校验（装备不参与锁机制，消耗品已过锁门，用总持有量判断即可）
        if held < amount then
            sellActive_[connKey] = nil
            SendError(connection, SaveProtocol.S2C_BlackMerchantResult, "持有量不足")
            return
        end

        -- 5. 检查黑商库存上限
        serverCloud.money:Get(BMConfig.SYSTEM_UID, {
            ok = function(systemMoneys)
                local stock = systemMoneys[BMConfig.StockKey(consumableId)] or 0
                local maxStock = cfg.max_stock or BMConfig.MAX_STOCK
                if stock + amount > maxStock then
                    sellActive_[connKey] = nil
                    SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                        "黑商仓库已满")
                    return
                end

                -- 6. 从 backpack 扣除物品并写回存档（装备按 equipId 移除，不论附魔/洗练）
                if isEquip then
                    RemoveEquipmentFromBackpack(backpack, cfg.equipId or consumableId, amount)
                else
                    RemoveFromBackpack(backpack, consumableId, amount)
                end
                saveData.backpack = backpack

                local charName = (saveData.player and saveData.player.charName)
                    or "修仙者"

                WriteSaveBack(userId, slot, saveData,
                    "黑商出售扣除背包: " .. consumableId .. " x" .. amount,
                    function() -- onOk: 存档已写，原子执行仙石+库存操作
                        -- 7. BatchCommit: 加仙石 + 入库（原子操作）
                        local commit = serverCloud:BatchCommit("黑商出售入账")
                        commit:MoneyAdd(userId, "xianshi", total)
                        commit:MoneyAdd(BMConfig.SYSTEM_UID, BMConfig.StockKey(consumableId), amount)
                        commit:Commit({
                            ok = function()
                                -- 读取新余额
                                serverCloud.money:Get(userId, {
                                    ok = function(playerMoneys)
                                        sellActive_[connKey] = nil
                                        local newXianshi = playerMoneys.xianshi or 0
                                        local newStock = stock + amount
                                        local newHeld = held - amount

                                        TradeLogger.LogPublic(charName, "sell", consumableId,
                                            amount, cfg.buy_price, newXianshi)

                                        local resp = VariantMap()
                                        resp["ok"] = Variant(true)
                                        resp["action"] = Variant("sell")
                                        resp["id"] = Variant(consumableId)
                                        resp["amount"] = Variant(amount)
                                        resp["total"] = Variant(total)
                                        resp["newStock"] = Variant(newStock)
                                        resp["newXianshi"] = Variant(newXianshi)
                                        resp["newHeld"] = Variant(newHeld)
                                        Session.SafeSend(connection,
                                            SaveProtocol.S2C_BlackMerchantResult, resp)

                                        InvalidateSystemStockCache()  -- P0
                                        print("[BlackMerchant][Sell] OK: userId=" .. tostring(userId)
                                            .. " id=" .. consumableId .. " x" .. tostring(amount)
                                            .. " earned=" .. tostring(total))
                                    end,
                                    error = function(code, reason)
                                        sellActive_[connKey] = nil
                                        -- 存档已扣、仙石已加，但读余额失败，用估算值
                                        local newHeld = held - amount

                                        TradeLogger.LogPublic(charName, "sell", consumableId,
                                            amount, cfg.buy_price, total)

                                        local resp = VariantMap()
                                        resp["ok"] = Variant(true)
                                        resp["action"] = Variant("sell")
                                        resp["id"] = Variant(consumableId)
                                        resp["amount"] = Variant(amount)
                                        resp["total"] = Variant(total)
                                        resp["newStock"] = Variant(stock + amount)
                                        resp["newXianshi"] = Variant(total)
                                        resp["newHeld"] = Variant(newHeld)
                                        Session.SafeSend(connection,
                                            SaveProtocol.S2C_BlackMerchantResult, resp)
                                    end,
                                })
                            end,
                            error = function(code, reason)
                                -- 背包已扣但仙石+库存提交失败（极罕见）
                                -- 写入 WAL_SELL_KEY，下次登录自动补发仙石
                                print("[BlackMerchant][Sell] CRITICAL: backpack deducted but BatchCommit failed: "
                                    .. tostring(code) .. " " .. tostring(reason)
                                    .. " | writing WAL_SELL for xianshi=" .. tostring(total))
                                serverCloud.list:Add(userId, BMConfig.WAL_SELL_KEY, { xianshi = total }, {
                                    ok = function()
                                        sellActive_[connKey] = nil
                                        print("[BlackMerchant][Sell] WAL_SELL written: userId="
                                            .. tostring(userId) .. " xianshi=" .. tostring(total))
                                        SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                                            "出售失败，仙石将在下次登录时自动补发")
                                    end,
                                    error = function(c2, r2)
                                        sellActive_[connKey] = nil
                                        print("[BlackMerchant][Sell] CRITICAL+WAL_SELL write failed: userId="
                                            .. tostring(userId) .. " xianshi=" .. tostring(total)
                                            .. " err=" .. tostring(r2))
                                        SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                                            "交易异常，请联系客服（代码：SELL_NO_WAL）")
                                    end,
                                })
                            end,
                        })
                    end,
                    function() -- onError: 存档写入失败，碎片未扣
                        sellActive_[connKey] = nil
                        SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                            "交易失败，请重试")
                    end
                )
            end,
            error = function(code, reason)
                sellActive_[connKey] = nil
                SendError(connection, SaveProtocol.S2C_BlackMerchantResult,
                    "服务器忙，请稍后重试")
            end,
        })
    end)
end

-- ============================================================================
-- HandleExchange — 灵韵 ↔ 仙石兑换
-- ============================================================================

function M.HandleExchange(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    local ok1, direction = pcall(function() return eventData["direction"]:GetString() end)
    local ok2, amount = pcall(function() return eventData["amount"]:GetInt() end)
    if not ok1 or not ok2 then
        SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult, "invalid request")
        return
    end

    print("[BlackMerchant][Exchange] userId=" .. tostring(userId)
        .. " direction=" .. direction .. " amount=" .. tostring(amount))

    -- 1. 境界校验
    if not IsRealmOk(connKey) then
        SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
            "境界不足，需筑基初期以上")
        return
    end

    -- 2. amount 校验
    if not amount or amount < 1 then
        SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult, "数量无效")
        return
    end

    if direction == "buy" then
        -- 灵韵 → 仙石：服务端从存档校验灵韵余额，原子扣除后加仙石
        local lingYunCost = amount * BMConfig.XIANSHI_BUY_RATE
        local slot = Session.connSlots_[connKey]

        -- 1. 读取存档验证灵韵
        Session.ServerGetSlotData(userId, slot, function(saveData)
            if not saveData or not saveData.player then
                SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
                    "存档读取失败，请重试")
                return
            end

            local lingYun = saveData.player.lingYun or 0
            if lingYun < lingYunCost then
                SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
                    "灵韵不足", { ["need"] = Variant(lingYunCost), ["have"] = Variant(lingYun) })
                return
            end

            -- 2. 扣除灵韵并写回存档
            saveData.player.lingYun = lingYun - lingYunCost

            WriteSaveBack(userId, slot, saveData,
                "黑商兑换扣灵韵: -" .. lingYunCost,
                function() -- onOk: 存档已扣灵韵，加仙石（P5: 改用 BatchCommit 原子操作）
                    local commit = serverCloud:BatchCommit("黑商灵韵→仙石")
                    commit:MoneyAdd(userId, "xianshi", amount)
                    commit:Commit({
                        ok = function()
                            -- 读取新仙石余额
                            serverCloud.money:Get(userId, {
                                ok = function(moneys)
                                    local newXianshi = moneys.xianshi or 0

                                    TradeLogger.LogPersonal(userId, "exchange_buy", "xianshi", amount,
                                        BMConfig.XIANSHI_BUY_RATE, newXianshi)

                                    local resp = VariantMap()
                                    resp["ok"] = Variant(true)
                                    resp["direction"] = Variant("buy")
                                    resp["amount"] = Variant(amount)
                                    resp["newXianshi"] = Variant(newXianshi)
                                    resp["lingYunDelta"] = Variant(-lingYunCost)
                                    Session.SafeSend(connection,
                                        SaveProtocol.S2C_BlackMerchantExchangeResult, resp)

                                    print("[BlackMerchant][Exchange] BUY OK: userId=" .. tostring(userId)
                                        .. " xianshi+" .. tostring(amount)
                                        .. " lingYun-" .. tostring(lingYunCost))
                                end,
                                error = function(code, reason)
                                    -- MoneyAdd 已成功，仅读余额失败，用估算值
                                    local estimatedXianshi = amount
                                    local resp = VariantMap()
                                    resp["ok"] = Variant(true)
                                    resp["direction"] = Variant("buy")
                                    resp["amount"] = Variant(amount)
                                    resp["newXianshi"] = Variant(estimatedXianshi)
                                    resp["lingYunDelta"] = Variant(-lingYunCost)
                                    Session.SafeSend(connection,
                                        SaveProtocol.S2C_BlackMerchantExchangeResult, resp)
                                end,
                            })
                        end,
                        error = function(code, reason)
                            -- 仙石加入失败，但灵韵已扣 → 写 WAL 补偿
                            print("[BlackMerchant][Exchange] BUY MoneyAdd FAILED: "
                                .. tostring(code) .. " " .. tostring(reason)
                                .. " | writing WAL_SELL for xianshi=" .. tostring(amount))
                            serverCloud.list:Add(userId, BMConfig.WAL_SELL_KEY, { xianshi = amount }, {
                                ok = function()
                                    print("[BlackMerchant][Exchange] WAL_SELL written for buy rollback: userId="
                                        .. tostring(userId) .. " xianshi=" .. tostring(amount))
                                    SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
                                        "兑换异常，仙石将在下次登录时补发")
                                end,
                                error = function(c2, r2)
                                    print("[BlackMerchant][Exchange] CRITICAL: WAL_SELL write also failed: "
                                        .. tostring(r2) .. " userId=" .. tostring(userId))
                                    SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
                                        "兑换异常，请联系客服（代码：EXBUY_NO_WAL）")
                                end,
                            })
                        end,
                    })
                end,
                function() -- onError: 存档写入失败，灵韵未扣
                    SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
                        "交易失败，请重试")
                end
            )
        end)

    elseif direction == "sell" then
        -- 仙石 → 灵韵：先 Cost 仙石（原子），再通知客户端加灵韵
        local lingYunGain = amount * BMConfig.XIANSHI_SELL_RATE

        -- WAL + Cost 原子操作
        local commit = serverCloud:BatchCommit("黑商仙石→灵韵")
        commit:MoneyCost(userId, "xianshi", amount)
        commit:ListAdd(userId, BMConfig.WAL_KEY, {
            lingYunGain = lingYunGain,
            amount = amount,
            t = os.time(),
        })
        commit:Commit({
            ok = function()
                -- Cost 成功，读取新余额
                serverCloud.money:Get(userId, {
                    ok = function(moneys)
                        local newXianshi = moneys.xianshi or 0

                        -- 交易记录（个人）
                        TradeLogger.LogPersonal(userId, "exchange_sell", "xianshi", amount,
                            BMConfig.XIANSHI_SELL_RATE, newXianshi)

                        -- 通知客户端加灵韵
                        local resp = VariantMap()
                        resp["ok"] = Variant(true)
                        resp["direction"] = Variant("sell")
                        resp["amount"] = Variant(amount)
                        resp["newXianshi"] = Variant(newXianshi)
                        resp["lingYunDelta"] = Variant(lingYunGain)
                        Session.SafeSend(connection,
                            SaveProtocol.S2C_BlackMerchantExchangeResult, resp)

                        -- 清除 WAL（客户端已收到通知）
                        serverCloud.list:Get(userId, BMConfig.WAL_KEY, {
                            ok = function(walList)
                                for _, item in ipairs(walList) do
                                    if item.list_id then
                                        serverCloud.list:Delete(item.list_id)
                                    end
                                end
                            end,
                            error = function() end,
                        })

                        print("[BlackMerchant][Exchange] SELL OK: userId=" .. tostring(userId)
                            .. " xianshi-" .. tostring(amount)
                            .. " lingYun+" .. tostring(lingYunGain))
                    end,
                    error = function(code, reason)
                        -- Cost 已成功但读余额失败，WAL 仍在，下次 Query 时补偿
                        SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
                            "服务器忙，请稍后重试")
                    end,
                })
            end,
            error = function(code, reason)
                local errStr = tostring(reason)
                print("[BlackMerchant][Exchange] SELL BatchCommit FAILED: "
                    .. tostring(code) .. " " .. errStr)
                if errStr:find("balance") or errStr:find("insufficient") then
                    SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
                        "仙石不足")
                else
                    SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
                        "兑换失败，请重试")
                end
            end,
        })
    else
        SendError(connection, SaveProtocol.S2C_BlackMerchantExchangeResult,
            "无效方向")
    end
end

-- ============================================================================
-- HandleHistory — 查询交易记录
-- ============================================================================

function M.HandleHistory(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    print("[BlackMerchant][History] userId=" .. tostring(userId))

    -- 境界校验（不限制查看记录，但保持一致性）
    if not IsRealmOk(connKey) then
        SendError(connection, SaveProtocol.S2C_BlackMerchantHistory,
            "境界不足，需筑基初期以上")
        return
    end

    -- 并行查两个 list：公共买卖 + 个人兑换
    local pending = 2
    local publicRecords = {}
    local personalRecords = {}
    local hasError = false

    local function TryMergeAndSend()
        pending = pending - 1
        if pending > 0 then return end
        if hasError then
            SendError(connection, SaveProtocol.S2C_BlackMerchantHistory,
                "查询失败，请稍后重试")
            return
        end

        -- 合并两个列表
        local merged = {}
        for _, rec in ipairs(publicRecords) do
            merged[#merged + 1] = rec
        end
        for _, rec in ipairs(personalRecords) do
            rec.own = true  -- 标记为自己的兑换记录
            merged[#merged + 1] = rec
        end

        -- 按时间倒序
        table.sort(merged, function(a, b)
            return (a.t or 0) > (b.t or 0)
        end)

        -- 总量上限 100
        if #merged > 100 then
            local trimmed = {}
            for i = 1, 100 do
                trimmed[i] = merged[i]
            end
            merged = trimmed
        end

        local resp = VariantMap()
        resp["ok"] = Variant(true)
        local encOk2, mergedJson = pcall(cjson.encode, merged)
        if not encOk2 then
            print("[BlackMerchant] JSON encode failed (history): " .. tostring(mergedJson))
            SendError(connection, SaveProtocol.S2C_BlackMerchantHistory, "server error")
            return
        end
        resp["records"] = Variant(mergedJson)
        Session.SafeSend(connection,
            SaveProtocol.S2C_BlackMerchantHistory, resp)
    end

    -- 1) 公共买卖记录
    serverCloud.list:Get(BMConfig.SYSTEM_UID, BMConfig.PUBLIC_TRADE_LOG_KEY, {
        ok = function(list)
            for _, item in ipairs(list) do
                if item.value then
                    publicRecords[#publicRecords + 1] = item.value
                end
            end
            TryMergeAndSend()
        end,
        error = function(code, reason)
            print("[BlackMerchant][History] Public list get failed: "
                .. tostring(code) .. " " .. tostring(reason))
            hasError = true
            TryMergeAndSend()
        end,
    })

    -- 2) 个人兑换记录
    serverCloud.list:Get(userId, BMConfig.TRADE_LOG_KEY, {
        ok = function(list)
            for _, item in ipairs(list) do
                if item.value then
                    personalRecords[#personalRecords + 1] = item.value
                end
            end
            TryMergeAndSend()
        end,
        error = function(code, reason)
            print("[BlackMerchant][History] Personal list get failed: "
                .. tostring(code) .. " " .. tostring(reason))
            hasError = true
            TryMergeAndSend()
        end,
    })
end

-- ============================================================================
-- CheckWALOnLogin — 登录时检查 WAL 补偿（由 HandleLoadGame 调用）
-- 如果有未完成的 WAL，将灵韵补偿写入存档
-- ============================================================================

--- 登录时检查并应用 WAL 补偿（灵韵 + 背包物品）
---@param userId integer
---@param slot number
---@param saveData table 已加载的存档（可原地修改）
---@param onDone fun(compensated: integer)|nil 补偿完成回调，compensated 为补偿的灵韵数（0=无补偿）
function M.CheckWALOnLogin(userId, slot, saveData, onDone)
    -- 并行检查三种 WAL
    local pending = 3
    local totalLingYun = 0
    local bpItems = {}  -- { {consumableId, amount, name}, ... }
    local needSave = false

    local function TryApplyAndSave()
        pending = pending - 1
        if pending > 0 then return end

        -- 应用灵韵补偿
        if totalLingYun > 0 and saveData.player then
            saveData.player.lingYun = (saveData.player.lingYun or 0) + totalLingYun
            needSave = true
            print("[BlackMerchant][WAL] Login lingYun compensation: +"
                .. tostring(totalLingYun) .. " userId=" .. tostring(userId))
        end

        -- 应用背包物品补偿
        if #bpItems > 0 and saveData then
            local backpack = saveData.backpack or {}
            for _, bp in ipairs(bpItems) do
                if bp.itemType == "equipment" and bp.equipId then
                    -- 装备类：逐件创建初始状态装备
                    for _ = 1, (bp.amount or 1) do
                        local newEquip = LootSystem.CreateSpecialEquipment(bp.equipId)
                        if newEquip then
                            AddEquipmentToBackpack(backpack, newEquip)
                        end
                    end
                else
                    AddToBackpack(backpack, bp.consumableId, bp.amount, bp.name)
                end
                print("[BlackMerchant][WAL] Login backpack compensation: "
                    .. (bp.consumableId or bp.equipId or "?") .. " x" .. tostring(bp.amount)
                    .. " type=" .. tostring(bp.itemType)
                    .. " userId=" .. tostring(userId))
            end
            saveData.backpack = backpack
            needSave = true
        end

        if needSave then
            WriteSaveBack(userId, slot, saveData,
                "WAL登录补偿",
                function()
                    print("[BlackMerchant][WAL] Login compensation save OK: userId="
                        .. tostring(userId))
                    if onDone then onDone(totalLingYun) end
                end,
                function()
                    print("[BlackMerchant][WAL] Login compensation save FAILED: userId="
                        .. tostring(userId))
                    -- 内存中已修改，客户端下次保存会同步
                    if onDone then onDone(totalLingYun) end
                end
            )
        else
            if onDone then onDone(0) end
        end
    end

    -- 1) 灵韵 WAL
    serverCloud.list:Get(userId, BMConfig.WAL_KEY, {
        ok = function(walList)
            for _, item in ipairs(walList) do
                local val = item.value
                if val and val.lingYunGain then
                    totalLingYun = totalLingYun + val.lingYunGain
                end
                if item.list_id then
                    serverCloud.list:Delete(item.list_id)
                end
            end
            TryApplyAndSave()
        end,
        error = function(code, reason)
            print("[BlackMerchant][WAL] Login lingYun WAL check failed: " .. tostring(reason))
            TryApplyAndSave()
        end,
    })

    -- 2) 背包 WAL
    serverCloud.list:Get(userId, BMConfig.WAL_BP_KEY, {
        ok = function(walList)
            for _, item in ipairs(walList) do
                local val = item.value
                if val and (val.consumableId or val.equipId) and val.amount then
                    bpItems[#bpItems + 1] = {
                        consumableId = val.consumableId,
                        amount = val.amount,
                        name = val.name,
                        itemType = val.itemType,  -- "equipment" 或 nil
                        equipId = val.equipId,    -- 装备模板 ID
                    }
                end
                if item.list_id then
                    serverCloud.list:Delete(item.list_id)
                end
            end
            TryApplyAndSave()
        end,
        error = function(code, reason)
            print("[BlackMerchant][WAL] Login backpack WAL check failed: " .. tostring(reason))
            TryApplyAndSave()
        end,
    })

    -- 3) 仙石补偿 WAL（出售时 BatchCommit 失败的补偿，直接 BatchCommit 补发，不经存档）
    serverCloud.list:Get(userId, BMConfig.WAL_SELL_KEY, {
        ok = function(walList)
            local totalXianshi = 0
            local listIds = {}
            for _, item in ipairs(walList) do
                local val = item.value
                if val and val.xianshi then
                    totalXianshi = totalXianshi + val.xianshi
                end
                if item.list_id then
                    listIds[#listIds + 1] = item.list_id
                end
            end
            if totalXianshi > 0 then
                local commit = serverCloud:BatchCommit("WAL出售仙石补偿")
                commit:MoneyAdd(userId, "xianshi", totalXianshi)
                commit:Commit({
                    ok = function()
                        -- 仙石已补发，安全删除 WAL 条目
                        for _, lid in ipairs(listIds) do
                            serverCloud.list:Delete(lid)
                        end
                        print("[BlackMerchant][WAL] xianshi compensation OK: +"
                            .. tostring(totalXianshi) .. " userId=" .. tostring(userId))
                    end,
                    error = function(c, r)
                        -- WAL 条目保留，下次登录继续尝试
                        print("[BlackMerchant][WAL] xianshi compensation FAILED: "
                            .. tostring(r) .. " userId=" .. tostring(userId))
                    end,
                })
            else
                -- 无需补偿，清理空条目
                for _, lid in ipairs(listIds) do
                    serverCloud.list:Delete(lid)
                end
            end
            TryApplyAndSave()
        end,
        error = function(code, reason)
            print("[BlackMerchant][WAL] Login xianshi WAL check failed: " .. tostring(reason))
            TryApplyAndSave()
        end,
    })
end

-- ============================================================================
-- §12 自动收购（胤）
-- ============================================================================

--- 内存日期缓存，避免每 tick 都读云端
local lastRecycleDate_ = nil  -- string: "YYYYMMDD" or nil
--- 执行锁，防止自动触发与 GM 手动触发并发
local recycleRunning_ = false

--- 加权随机收购数量（0/1/2），基于 BMConfig.RECYCLE_WEIGHTS 累积概率
---@return integer
local function WeightedRecycleAmount()
    local r = math.random()
    local weights = BMConfig.RECYCLE_WEIGHTS
    if r <= weights[1] then return 0 end
    if r <= weights[2] then return 1 end
    return 2
end

--- 执行一次完整的自动收购流程（逐件独立提交，fire-and-forget）
--- 调用方：RecycleTick（自动）或 GM 命令（手动）
--- 每件商品只处理一次，成功或失败后不再理会。
---@param callback fun(ok: boolean, summary: string)
function M.ExecuteRecycle(callback)
    if recycleRunning_ then
        callback(false, "收购正在执行中，请稍后再试")
        return
    end
    recycleRunning_ = true

    -- 1. 读取系统库存（强制实时，不走缓存——回收判断必须基于最新数据）
    InvalidateSystemStockCache()
    GetSystemStockCached(function(moneys)
        -- pcall 保护：防止回调内部异常导致 recycleRunning_ 永久泄漏
        local ok2, err2 = pcall(function()
            -- 2. 筛选满库存商品 + 随机收购数量
            local tasks = {}  -- { { itemId, amount, cfg } }
            for _, itemId in ipairs(BMConfig.ITEM_IDS) do
                local cfg = BMConfig.ITEMS[itemId]
                local maxStock = cfg.max_stock or BMConfig.MAX_STOCK
                local stockKey = BMConfig.StockKey(itemId)
                local currentStock = moneys[stockKey] or 0
                if currentStock >= maxStock then
                    local amount = WeightedRecycleAmount()
                    if amount > 0 then
                        amount = math.min(amount, currentStock)
                        tasks[#tasks + 1] = { itemId = itemId, amount = amount, cfg = cfg }
                    end
                end
            end

            -- 无符合商品
            if #tasks == 0 then
                recycleRunning_ = false
                callback(true, "无满库存商品，跳过收购")
                return
            end

            -- 3. 逐件顺序提交
            local totalKinds = 0
            local totalItems = 0
            local idx = 0

            local function processNext()
                idx = idx + 1
                if idx > #tasks then
                    -- 全部完成
                    InvalidateSystemStockCache()
                    recycleRunning_ = false
                    local summary = string.format("收购完成: %d种商品共%d件", totalKinds, totalItems)
                    print("[BlackMerchant][Recycle] " .. summary)
                    callback(true, summary)
                    return
                end

                local task = tasks[idx]
                local stockKey = BMConfig.StockKey(task.itemId)
                local commit = serverCloud:BatchCommit("胤收购_" .. task.itemId)
                commit:MoneyCost(BMConfig.SYSTEM_UID, stockKey, task.amount)
                commit:Commit({
                    ok = function()
                        totalKinds = totalKinds + 1
                        totalItems = totalItems + task.amount
                        -- 写公共交易记录
                        TradeLogger.LogPublic(
                            BMConfig.RECYCLE_NPC_NAME,
                            "buy",
                            task.itemId,
                            task.amount,
                            task.cfg.sell_price or 0,
                            0  -- NPC 无仙石余额
                        )
                        print("[BlackMerchant][Recycle] OK: " .. task.itemId
                            .. " x" .. tostring(task.amount))
                        processNext()
                    end,
                    error = function(code, reason)
                        -- 单件失败（可能库存已被玩家买走），跳过继续，不重试
                        print("[BlackMerchant][Recycle] SKIP: " .. task.itemId
                            .. " err=" .. tostring(reason))
                        processNext()
                    end,
                })
            end

            processNext()
        end)

        if not ok2 then
            recycleRunning_ = false
            local msg = "回调内部异常: " .. tostring(err2)
            print("[BlackMerchant][Recycle] " .. msg)
            callback(false, msg)
        end
    end,
    function(code, reason)
        -- 库存读取失败
        recycleRunning_ = false
        local msg = "读取库存失败: " .. tostring(reason)
        print("[BlackMerchant][Recycle] " .. msg)
        callback(false, msg)
    end)
end

--- 每帧 tick：检查是否需要执行每日自动收购
--- 执行顺序："先占坑再干活" — 先更新云端日期，成功后才处理商品。
--- 确保即使崩溃/重启，也不会重复回收。
--- 由 server_main.lua HandleServerUpdate 调用
---@param dt number
function M.RecycleTick(dt)
    if not BMConfig.RECYCLE_ENABLED then return end
    if recycleRunning_ then return end

    local today = os.date("%Y%m%d")
    if lastRecycleDate_ == today then return end

    -- 内存占位（快速路径，避免同一帧重复进入）
    lastRecycleDate_ = today

    -- 1. 读取云端日期
    serverCloud.money:Get(BMConfig.SYSTEM_UID, {
        ok = function(moneys)
            local cloudDate = moneys[BMConfig.RECYCLE_DATE_KEY] or 0
            local todayNum = tonumber(today) or 0
            -- BM-S4D: 用 YYYYMMDD 数值差推进云端日期值（Add 增量）
            local numericGap = todayNum - cloudDate
            -- BM-S4D: 用真实日差判断是否跨天 / 异常（跨月跨年不再失真）
            local realGap = BMConfig.RealDayGap(todayNum, cloudDate)

            if realGap <= 0 then
                print("[BlackMerchant][Recycle] 当日已执行 (cloud=" .. tostring(cloudDate) .. ")")
                return
            end

            -- 时间篡改防护：realGap > MAX_RECYCLE_GAP → 仅推进日期，不执行回收
            if realGap > (BMConfig.MAX_RECYCLE_GAP or 2) then
                print("[BlackMerchant][Recycle] realGap=" .. realGap .. "天 > 上限"
                    .. tostring(BMConfig.MAX_RECYCLE_GAP) .. ", 疑似时间异常或长期停机, 仅更新日期")
                serverCloud.money:Add(BMConfig.SYSTEM_UID, BMConfig.RECYCLE_DATE_KEY, numericGap, {
                    ok = function()
                        print("[BlackMerchant][Recycle] 日期已跳转至: " .. today .. " (无回收)")
                    end,
                    error = function(c, r)
                        -- 日期更新失败，清除内存占位让下一 tick 重试
                        lastRecycleDate_ = nil
                        print("[BlackMerchant][Recycle] 日期跳转失败: " .. tostring(r))
                    end,
                })
                return
            end

            -- 2. 先占坑：更新云端日期（在处理任何商品之前）
            serverCloud.money:Add(BMConfig.SYSTEM_UID, BMConfig.RECYCLE_DATE_KEY, numericGap, {
                ok = function()
                    print("[BlackMerchant][Recycle] 日期已占坑: " .. today .. " (realGap=" .. realGap .. ")")
                    -- 3. 占坑成功后才执行回收（fire-and-forget，失败可接受）
                    M.ExecuteRecycle(function(ok, summary)
                        if ok then
                            print("[BlackMerchant][Recycle] " .. summary)
                        else
                            -- 回收失败但日期已推进，不会重试，符合预期
                            print("[BlackMerchant][Recycle] 回收失败(日期已推进,不重试): " .. tostring(summary))
                        end
                    end)
                end,
                error = function(c, r)
                    -- 占坑失败 → 商品未动 → 清除内存占位让下一 tick 重试
                    -- 这是安全的：没有任何商品被处理
                    lastRecycleDate_ = nil
                    print("[BlackMerchant][Recycle] 占坑失败(商品未动,可重试): " .. tostring(r))
                end,
            })
        end,
        error = function(code, reason)
            -- 云端读取失败 → 清除内存占位让下一 tick 重试
            -- 安全：既没占坑也没处理商品
            lastRecycleDate_ = nil
            print("[BlackMerchant][Recycle] 云端读取失败(可重试): " .. tostring(reason))
        end,
    })
end

-- ============================================================================
-- OnDisconnect — 清理缓存
-- ============================================================================

function M.OnDisconnect(connKey)
    playerRealms_[connKey] = nil
end

return M
