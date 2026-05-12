-- ============================================================================
-- SkinShopHandler.lua — 大黑无天皮肤商店 服务端 Handler
--
-- 职责：HandleQuery / HandleBuy 两个 C2S 处理
-- 设计：sell-only，不回收，不限量，简化版黑商模式
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local SkinShopConfig = require("config.SkinShopConfig")
local GameConfig = require("config.GameConfig")

local cjson = cjson ---@diagnostic disable-line: undefined-global

local M = {}

-- §8 服务端内存锁：防止同一玩家并发购买请求
local buyActive_ = {}  -- connKey -> true

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
local function SendError(connection, eventName, reason)
    local data = VariantMap()
    data["ok"] = Variant(false)
    data["reason"] = Variant(reason or "unknown")
    Session.SafeSend(connection, eventName, data)
end

--- 异步读取玩家境界 + 存档
---@param connKey string
---@param userId integer
---@param callback fun(realmOk: boolean, saveData: table|nil, slot: number|nil)
local function FetchRealmAndSave(connKey, userId, callback)
    local slot = Session.connSlots_[connKey]
    if not slot then
        callback(false, nil, nil)
        return
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData or not saveData.player then
            callback(false, saveData, slot)
            return
        end

        local realm = saveData.player.realm or "mortal"
        local realmData = GameConfig.REALMS[realm]
        local order = realmData and realmData.order or 0
        local ok = order >= SkinShopConfig.REQUIRED_REALM_ORDER

        callback(ok, saveData, slot)
    end)
end

--- 读取 account_cosmetics（已解锁皮肤信息）
---@param userId integer
---@param callback fun(cosmetics: table)
---@param errCallback fun(code: any, reason: any)
local function FetchAccountCosmetics(userId, callback, errCallback)
    serverCloud:BatchGet(userId)
        :Key("account_cosmetics")
        :Fetch({
            ok = function(scores)
                local cosmetics = scores["account_cosmetics"]
                if not cosmetics or type(cosmetics) ~= "table" then
                    cosmetics = {}
                end
                callback(cosmetics)
            end,
            error = function(code, reason)
                print("[SkinShop] FetchAccountCosmetics FAILED: " .. tostring(code) .. " " .. tostring(reason))
                if errCallback then errCallback(code, reason) end
            end,
        })
end

--- 检查皮肤是否已解锁
---@param cosmetics table
---@param skinId string
---@return boolean
local function IsSkinUnlocked(cosmetics, skinId)
    local pa = cosmetics.petAppearances
    if not pa then return false end
    local entry = pa[skinId]
    return entry and entry.unlocked == true
end

-- ============================================================================
-- HandleQuery — 查询皮肤商店数据（已解锁状态 + 仙石余额）
-- ============================================================================

function M.HandleQuery(eventType, eventData)
    print("[SkinShop][Query] === HandleQuery START ===")
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then
        print("[SkinShop][Query] ExtractContext failed")
        return
    end

    -- 1. 检查境界
    FetchRealmAndSave(connKey, userId, function(realmOk, saveData, slot)
        -- 2. 读取仙石余额
        serverCloud.money:Get(userId, {
            ok = function(playerMoneys)
                local xianshi = playerMoneys.xianshi or 0
                -- 3. 读取已解锁皮肤
                FetchAccountCosmetics(userId, function(cosmetics)
                    -- 4. 构建回包
                    local unlocked = {}
                    for _, skinId in ipairs(SkinShopConfig.SKIN_IDS) do
                        if IsSkinUnlocked(cosmetics, skinId) then
                            unlocked[#unlocked + 1] = skinId
                        end
                    end

                    local reply = VariantMap()
                    reply["ok"] = Variant(true)
                    reply["realmOk"] = Variant(realmOk)
                    reply["xianshi"] = Variant(xianshi)
                    reply["unlocked"] = Variant(cjson.encode(unlocked))
                    reply["price"] = Variant(SkinShopConfig.SKIN_PRICE)
                    Session.SafeSend(connection, SaveProtocol.S2C_SkinShopData, reply)
                    print("[SkinShop][Query] sent data, xianshi=" .. xianshi
                        .. " unlocked=" .. #unlocked .. " realmOk=" .. tostring(realmOk))
                end, function(code, reason)
                    SendError(connection, SaveProtocol.S2C_SkinShopData, "读取皮肤数据失败")
                end)
            end,
            error = function(code, reason)
                print("[SkinShop][Query] money:Get FAILED: " .. tostring(code))
                SendError(connection, SaveProtocol.S2C_SkinShopData, "读取仙石失败")
            end,
        })
    end)
end

-- ============================================================================
-- HandleBuy — 购买皮肤
-- ============================================================================

function M.HandleBuy(eventType, eventData)
    print("[SkinShop][Buy] === HandleBuy START ===")
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then
        print("[SkinShop][Buy] ExtractContext failed")
        return
    end

    -- 解析请求参数
    local skinId = eventData["skinId"]:GetString()
    print("[SkinShop][Buy] connKey=" .. connKey .. " skinId=" .. tostring(skinId))

    -- 校验皮肤 ID 合法性
    local validSkin = false
    for _, sid in ipairs(SkinShopConfig.SKIN_IDS) do
        if sid == skinId then
            validSkin = true
            break
        end
    end
    if not validSkin then
        print("[SkinShop][Buy] invalid skinId: " .. tostring(skinId))
        SendError(connection, SaveProtocol.S2C_SkinShopResult, "无效的皮肤")
        return
    end

    -- §8 层①：服务端内存锁
    if buyActive_[connKey] then
        print("[SkinShop][Buy] LOCKED: " .. connKey)
        SendError(connection, SaveProtocol.S2C_SkinShopResult, "操作进行中，请稍候")
        return
    end
    buyActive_[connKey] = true

    -- 1. 检查境界
    FetchRealmAndSave(connKey, userId, function(realmOk, saveData, slot)
        if not realmOk then
            buyActive_[connKey] = nil
            SendError(connection, SaveProtocol.S2C_SkinShopResult, "境界不足")
            return
        end

        -- 2. 读取已解锁皮肤，检查是否重复购买
        FetchAccountCosmetics(userId, function(cosmetics)
            if IsSkinUnlocked(cosmetics, skinId) then
                buyActive_[connKey] = nil
                SendError(connection, SaveProtocol.S2C_SkinShopResult, "该皮肤已拥有")
                return
            end

            -- 3. §8 层②：原子事务扣仙石
            local price = SkinShopConfig.SKIN_PRICE
            local batch = serverCloud:BatchCommit("皮肤购买_" .. skinId)
            batch:MoneyCost(userId, "xianshi", price)
            batch:Commit({
                ok = function()
                    print("[SkinShop][Buy] BatchCommit OK, writing cosmetics...")
                    -- 4. 写入 account_cosmetics
                    if not cosmetics.petAppearances then
                        cosmetics.petAppearances = {}
                    end
                    cosmetics.petAppearances[skinId] = { unlocked = true }

                    serverCloud:BatchSet(userId)
                        :Set("account_cosmetics", cosmetics)
                        :Save("皮肤解锁_" .. skinId, {
                            ok = function()
                                buyActive_[connKey] = nil
                                print("[SkinShop][Buy] cosmetics saved, skinId=" .. skinId)
                                -- 5. 发送成功回包
                                local reply = VariantMap()
                                reply["ok"] = Variant(true)
                                reply["skinId"] = Variant(skinId)
                                -- 重新查余额返回最新值
                                serverCloud.money:Get(userId, {
                                    ok = function(moneys)
                                        reply["xianshi"] = Variant(moneys.xianshi or 0)
                                        Session.SafeSend(connection, SaveProtocol.S2C_SkinShopResult, reply)
                                    end,
                                    error = function()
                                        reply["xianshi"] = Variant(-1)  -- 读余额失败，前端会重新 Query
                                        Session.SafeSend(connection, SaveProtocol.S2C_SkinShopResult, reply)
                                    end,
                                })
                            end,
                            error = function(code, reason)
                                buyActive_[connKey] = nil
                                print("[SkinShop][Buy] cosmetics save FAILED: "
                                    .. tostring(code) .. " " .. tostring(reason))
                                -- 仙石已扣但皮肤未写入，需要补偿
                                -- 用 MoneyAdd 回退仙石
                                local rollback = serverCloud:BatchCommit("皮肤回退_" .. skinId)
                                rollback:MoneyAdd(userId, "xianshi", price)
                                rollback:Commit({
                                    ok = function()
                                        print("[SkinShop][Buy] xianshi rollback OK")
                                    end,
                                    error = function()
                                        print("[SkinShop][Buy] xianshi rollback FAILED! manual fix needed")
                                    end,
                                })
                                SendError(connection, SaveProtocol.S2C_SkinShopResult, "保存失败，仙石已退回")
                            end,
                        })
                end,
                error = function(code, reason)
                    buyActive_[connKey] = nil
                    print("[SkinShop][Buy] BatchCommit FAILED: "
                        .. tostring(code) .. " " .. tostring(reason))
                    local msg = "仙石不足"
                    if code ~= "INSUFFICIENT_FUNDS" then
                        msg = "交易失败: " .. tostring(reason)
                    end
                    SendError(connection, SaveProtocol.S2C_SkinShopResult, msg)
                end,
            })
        end, function(code, reason)
            buyActive_[connKey] = nil
            SendError(connection, SaveProtocol.S2C_SkinShopResult, "读取皮肤数据失败")
        end)
    end)
end

return M
