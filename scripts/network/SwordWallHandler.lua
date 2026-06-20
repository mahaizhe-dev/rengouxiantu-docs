-- ============================================================================
-- SwordWallHandler.lua - 剑气长城副本服务端处理
-- 积分结算（宝箱） + 积分商店购买
-- 积分使用 serverCloud Money 域，同黑市仙石范式
-- ============================================================================

local SwordWallHandler = {}

local SaveProtocol = require("network.SaveProtocol")
local SWC = require("config.SwordWallConfig")
local Session = require("network.ServerSession")
local Logger = require("utils.Logger")
local LootSystem = require("systems.LootSystem")
local GameConfig = require("config.GameConfig")

-- 防并发锁
local claimActive_ = {}   -- connKey -> true
local shopActive_  = {}   -- connKey -> true

-- 已结算 runId 本地缓存（防重入，最近 50 个）
local claimedRuns_ = {}   -- { [runId] = true }
local claimedRunsList_ = {}  -- 有序列表，用于淘汰旧 ID

local MAX_CACHED_RUNS = 50

local function MarkRunClaimed(runId)
    if claimedRuns_[runId] then return end
    claimedRuns_[runId] = true
    table.insert(claimedRunsList_, runId)
    if #claimedRunsList_ > MAX_CACHED_RUNS then
        local old = table.remove(claimedRunsList_, 1)
        claimedRuns_[old] = nil
    end
end

local function IsRunClaimed(runId)
    return claimedRuns_[runId] == true
end

-- ============================================================================
-- 宝箱结算
-- ============================================================================

function SwordWallHandler.HandleClaim(connection, eventData)
    local connKey = tostring(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then return end

    -- 防并发
    if claimActive_[connKey] then
        Logger.warn("SwordWall", "Claim already active for " .. connKey)
        return
    end
    claimActive_[connKey] = true

    local function finish()
        claimActive_[connKey] = nil
    end

    local function SendResult(ok, points, equipJson, errMsg)
        local resp = VariantMap()
        resp["ok"] = Variant(ok)
        resp["points"] = Variant(points or 0)
        resp["equipment"] = Variant(equipJson or "")
        resp["error"] = Variant(errMsg or "")
        connection:SendRemoteEvent(SaveProtocol.S2C_SwordWallClaimResult, true, resp)
    end

    -- 解析 runId
    local runId = eventData["runId"] and eventData["runId"]:GetString() or ""
    if runId == "" then
        SendResult(false, 0, "", "runId为空")
        finish()
        return
    end

    -- 本地防重
    if IsRunClaimed(runId) then
        SendResult(false, 0, "", "该副本已结算")
        finish()
        return
    end

    -- 生成奖励
    local points = math.random(SWC.REWARD_POINT_MIN, SWC.REWARD_POINT_MAX)
    local equipment = LootSystem.GenerateSwordWallRewardEquipment()
    local cjson = require("cjson")
    local equipJson = equipment and cjson.encode(equipment) or ""

    -- 原子操作：加积分 + 写结算日志
    local commit = serverCloud:BatchCommit("剑气长城宝箱结算")
    commit:MoneyAdd(userId, SWC.POINT_KEY, points)
    -- WAL: 装备数据（如果背包写入失败可补发）
    commit:ListAdd(userId, SWC.WAL_ITEM_KEY, {
        runId = runId,
        equipment = equipJson,
        time = os.time(),
    })
    commit:Commit({
        ok = function()
            MarkRunClaimed(runId)
            Logger.info("SwordWall", "Claim OK: userId=" .. userId
                .. " runId=" .. runId .. " points=" .. points
                .. " equip=" .. (equipment and equipment.name or "nil"))

            -- 写入背包存档
            local slot = Session.connSlots_[connKey]
            if slot and equipment then
                local SaveLoadService = require("network.SaveLoadService")
                SaveLoadService.ReadSlot(userId, slot, function(saveData)
                    if saveData and saveData.inventory then
                        table.insert(saveData.inventory, equipment)
                        SaveLoadService.WriteSlot(userId, slot, saveData, function(writeOk)
                            if writeOk then
                                -- 清理 WAL
                                serverCloud:ListRemove(userId, SWC.WAL_ITEM_KEY, { runId = runId })
                            else
                                Logger.warn("SwordWall", "背包写入失败，WAL保留: runId=" .. runId)
                            end
                        end)
                    end
                end)
            end

            SendResult(true, points, equipJson, "")
            finish()
        end,
        error = function(code, reason)
            Logger.warn("SwordWall", "Claim BatchCommit FAILED: " .. tostring(code)
                .. " " .. tostring(reason) .. " runId=" .. runId)
            SendResult(false, 0, "", "服务端结算失败")
            finish()
        end,
    })
end

-- ============================================================================
-- 商店查询
-- ============================================================================

function SwordWallHandler.HandleShopQuery(connection, eventData)
    local connKey = tostring(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then return end

    serverCloud.money:Get(userId, {
        ok = function(moneys)
            local balance = (moneys and moneys[SWC.POINT_KEY]) or 0
            local cjson = require("cjson")
            local resp = VariantMap()
            resp["ok"] = Variant(true)
            resp["balance"] = Variant(balance)
            resp["shop"] = Variant(cjson.encode(SWC.SHOP))
            connection:SendRemoteEvent(SaveProtocol.S2C_SwordWallShopData, true, resp)
        end,
        error = function(code, reason)
            local resp = VariantMap()
            resp["ok"] = Variant(false)
            resp["error"] = Variant("查询积分失败: " .. tostring(reason))
            connection:SendRemoteEvent(SaveProtocol.S2C_SwordWallShopData, true, resp)
        end,
    })
end

-- ============================================================================
-- 商店购买
-- ============================================================================

function SwordWallHandler.HandleShopBuy(connection, eventData)
    local connKey = tostring(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then return end

    -- 防并发
    if shopActive_[connKey] then
        Logger.warn("SwordWall", "Shop buy already active for " .. connKey)
        return
    end
    shopActive_[connKey] = true

    local function finish()
        shopActive_[connKey] = nil
    end

    local function SendResult(ok, itemId, balanceAfter, errMsg)
        local resp = VariantMap()
        resp["ok"] = Variant(ok)
        resp["itemId"] = Variant(itemId or "")
        resp["balance"] = Variant(balanceAfter or 0)
        resp["error"] = Variant(errMsg or "")
        connection:SendRemoteEvent(SaveProtocol.S2C_SwordWallShopBuyResult, true, resp)
    end

    local shopItemId = eventData["itemId"] and eventData["itemId"]:GetString() or ""

    -- 查找商品
    local shopItem = nil
    for _, item in ipairs(SWC.SHOP) do
        if item.id == shopItemId then
            shopItem = item
            break
        end
    end

    if not shopItem then
        SendResult(false, "", 0, "商品不存在")
        finish()
        return
    end

    -- 查询余额
    serverCloud.money:Get(userId, {
        ok = function(moneys)
            local balance = (moneys and moneys[SWC.POINT_KEY]) or 0
            if balance < shopItem.price then
                SendResult(false, shopItemId, balance, "剑气积分不足")
                finish()
                return
            end

            -- 构造奖励物品
            local rewardItem = nil
            if shopItem.itemType == "equipment" and shopItem.equipId then
                rewardItem = LootSystem.CreateSpecialEquipment(shopItem.equipId)
            elseif shopItem.itemType == "consumable" and shopItem.consumableId then
                rewardItem = { type = "consumable", consumableId = shopItem.consumableId, count = 1 }
            end

            if not rewardItem then
                SendResult(false, shopItemId, balance, "物品生成失败")
                finish()
                return
            end

            -- 原子扣积分 + WAL
            local cjson = require("cjson")
            local commit = serverCloud:BatchCommit("剑气积分商店购买")
            commit:MoneyCost(userId, SWC.POINT_KEY, shopItem.price)
            commit:ListAdd(userId, SWC.WAL_ITEM_KEY, {
                shopItemId = shopItemId,
                reward = cjson.encode(rewardItem),
                time = os.time(),
            })
            commit:Commit({
                ok = function()
                    Logger.info("SwordWall", "Shop buy OK: userId=" .. userId
                        .. " item=" .. shopItemId .. " price=" .. shopItem.price)

                    -- 写入背包
                    local slot = Session.connSlots_[connKey]
                    if slot then
                        local SaveLoadService = require("network.SaveLoadService")
                        SaveLoadService.ReadSlot(userId, slot, function(saveData)
                            if saveData and saveData.inventory then
                                if shopItem.itemType == "equipment" then
                                    table.insert(saveData.inventory, rewardItem)
                                else
                                    -- consumable 加入 consumables
                                    if not saveData.consumables then saveData.consumables = {} end
                                    local cId = shopItem.consumableId
                                    saveData.consumables[cId] = (saveData.consumables[cId] or 0) + 1
                                end
                                SaveLoadService.WriteSlot(userId, slot, saveData, function(writeOk)
                                    if writeOk then
                                        serverCloud:ListRemove(userId, SWC.WAL_ITEM_KEY, { shopItemId = shopItemId })
                                    else
                                        Logger.warn("SwordWall", "Shop背包写入失败，WAL保留: " .. shopItemId)
                                    end
                                end)
                            end
                        end)
                    end

                    -- 读新余额返回
                    serverCloud.money:Get(userId, {
                        ok = function(newMoneys)
                            local newBal = (newMoneys and newMoneys[SWC.POINT_KEY]) or (balance - shopItem.price)
                            SendResult(true, shopItemId, newBal, "")
                            finish()
                        end,
                        error = function()
                            SendResult(true, shopItemId, balance - shopItem.price, "")
                            finish()
                        end,
                    })
                end,
                error = function(code, reason)
                    Logger.warn("SwordWall", "Shop BatchCommit FAILED: " .. tostring(code)
                        .. " " .. tostring(reason) .. " item=" .. shopItemId)
                    SendResult(false, shopItemId, balance, "扣积分失败")
                    finish()
                end,
            })
        end,
        error = function(code, reason)
            SendResult(false, shopItemId, 0, "查询余额失败")
            finish()
        end,
    })
end

-- ============================================================================
-- WAL 登录检查（补发未到账物品）
-- ============================================================================

function SwordWallHandler.CheckWAL(userId, connKey)
    serverCloud:ListGet(userId, SWC.WAL_ITEM_KEY, {
        ok = function(items)
            if not items or #items == 0 then return end
            Logger.info("SwordWall", "WAL found " .. #items .. " pending items for userId=" .. userId)

            local slot = Session.connSlots_[connKey]
            if not slot then return end

            local SaveLoadService = require("network.SaveLoadService")
            SaveLoadService.ReadSlot(userId, slot, function(saveData)
                if not saveData then return end

                local cjson = require("cjson")
                local delivered = 0
                for _, walItem in ipairs(items) do
                    local ok2, reward = pcall(cjson.decode, walItem.equipment or walItem.reward or "")
                    if ok2 and reward then
                        if reward.slot then
                            -- equipment
                            if not saveData.inventory then saveData.inventory = {} end
                            table.insert(saveData.inventory, reward)
                            delivered = delivered + 1
                        elseif reward.consumableId then
                            -- consumable
                            if not saveData.consumables then saveData.consumables = {} end
                            local cId = reward.consumableId
                            saveData.consumables[cId] = (saveData.consumables[cId] or 0) + (reward.count or 1)
                            delivered = delivered + 1
                        end
                    end
                end

                if delivered > 0 then
                    SaveLoadService.WriteSlot(userId, slot, saveData, function(writeOk)
                        if writeOk then
                            -- 清空 WAL
                            serverCloud:ListClear(userId, SWC.WAL_ITEM_KEY)
                            Logger.info("SwordWall", "WAL delivered " .. delivered .. " items for userId=" .. userId)
                        end
                    end)
                end
            end)
        end,
        error = function() end,
    })
end

-- ============================================================================
-- 注册
-- ============================================================================

function SwordWallHandler.Register()
    SubscribeToEvent(SaveProtocol.C2S_SwordWallClaim, function(eventType, eventData)
        local connection = eventData["Connection"]:GetPtr("Connection")
        if connection then SwordWallHandler.HandleClaim(connection, eventData) end
    end)

    SubscribeToEvent(SaveProtocol.C2S_SwordWallShopQuery, function(eventType, eventData)
        local connection = eventData["Connection"]:GetPtr("Connection")
        if connection then SwordWallHandler.HandleShopQuery(connection, eventData) end
    end)

    SubscribeToEvent(SaveProtocol.C2S_SwordWallShopBuy, function(eventType, eventData)
        local connection = eventData["Connection"]:GetPtr("Connection")
        if connection then SwordWallHandler.HandleShopBuy(connection, eventData) end
    end)

    print("[SwordWallHandler] Registered")
end

return SwordWallHandler
