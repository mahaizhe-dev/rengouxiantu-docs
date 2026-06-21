-- ============================================================================
-- SwordWallHandler.lua - 剑气长城副本服务端处理
-- 积分结算（宝箱） + 积分商店购买
-- 积分使用 serverCloud Money 域，同黑市仙石范式
-- 装备由客户端收到成功回调后自行入库，auto-save 自然落盘
-- ============================================================================

local SwordWallHandler = {}

local SaveProtocol = require("network.SaveProtocol")
local SWC = require("config.SwordWallConfig")
local Session = require("network.ServerSession")
local Logger = require("utils.Logger")
local LootSystem = require("systems.LootSystem")

-- 防并发锁
local claimActive_ = {}   -- connKey -> true
local shopActive_  = {}   -- connKey -> true

-- 已结算 runId 本地缓存（防重入，最近 50 个）
-- 存储结算结果用于幂等重试: { [runId] = { points=N, equipJson="..." } }
local claimedRuns_ = {}
local claimedRunsList_ = {}   -- 有序列表，用于淘汰旧 ID

-- 副本开始注册（P0-1 防伪造）
local activeRuns_ = {}        -- { [connKey] = { runId=string, startTime=number } }

local MAX_CACHED_RUNS = 50
local MIN_CLEAR_TIME = 25     -- 至少 25 秒才可能通关（3波怪最低时间）

local function MarkRunClaimed(runId, result)
    if claimedRuns_[runId] then return end
    claimedRuns_[runId] = result or {}
    table.insert(claimedRunsList_, runId)
    if #claimedRunsList_ > MAX_CACHED_RUNS then
        local old = table.remove(claimedRunsList_, 1)
        claimedRuns_[old] = nil
    end
end

local function GetClaimedResult(runId)
    return claimedRuns_[runId]
end

-- ============================================================================
-- 副本开始注册（客户端进入副本时上报）
-- ============================================================================

function SwordWallHandler.HandleStart(connection, eventData)
    local connKey = tostring(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then return end

    local runId = eventData["runId"] and eventData["runId"]:GetString() or ""
    if runId == "" then return end

    -- 注册此连接的活跃副本
    activeRuns_[connKey] = {
        runId = runId,
        startTime = os.time(),
    }

    Logger.info("SwordWall", "Run started: userId=" .. userId .. " runId=" .. runId)
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

    -- 幂等重试：已结算的 runId 返回缓存的成功结果（防止响应丢失导致装备丢失）
    local cachedResult = GetClaimedResult(runId)
    if cachedResult then
        Logger.info("SwordWall", "Idempotent retry: runId=" .. runId .. " returning cached result")
        SendResult(true, cachedResult.points or 0, cachedResult.equipJson or "", "")
        finish()
        return
    end

    -- P0-1 防伪造校验：检查副本是否由此连接注册
    local runInfo = activeRuns_[connKey]
    if not runInfo or runInfo.runId ~= runId then
        Logger.warn("SwordWall", "Claim rejected: no registered run for " .. connKey
            .. " runId=" .. runId)
        SendResult(false, 0, "", "副本未注册")
        finish()
        return
    end

    -- 最短时间校验
    local elapsed = os.time() - runInfo.startTime
    if elapsed < MIN_CLEAR_TIME then
        Logger.warn("SwordWall", "Claim rejected: too fast (" .. elapsed .. "s) for " .. connKey)
        SendResult(false, 0, "", "通关时间异常")
        finish()
        return
    end

    -- 生成奖励（服务端权威生成）
    local points = math.random(SWC.REWARD_POINT_MIN, SWC.REWARD_POINT_MAX)
    local equipment = LootSystem.GenerateSwordWallRewardEquipment()
    local cjson = require("cjson")
    local equipJson = equipment and cjson.encode(equipment) or ""

    -- 原子操作：加积分
    local commit = serverCloud:BatchCommit("剑气长城宝箱结算")
    commit:MoneyAdd(userId, SWC.POINT_KEY, points)
    commit:Commit({
        ok = function()
            -- 缓存结算结果（用于幂等重试）
            MarkRunClaimed(runId, { points = points, equipJson = equipJson })
            -- 清理活跃副本记录
            activeRuns_[connKey] = nil

            Logger.info("SwordWall", "Claim OK: userId=" .. userId
                .. " runId=" .. runId .. " points=" .. points
                .. " equip=" .. (equipment and equipment.name or "nil"))

            -- 装备数据通过响应返回客户端，由客户端入库 + auto-save 落盘
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

            -- 构造奖励物品数据（序列化后发给客户端入库）
            local rewardItem = nil
            if shopItem.itemType == "equipment" and shopItem.equipId then
                rewardItem = LootSystem.CreateSpecialEquipment(shopItem.equipId)
            elseif shopItem.itemType == "consumable" and shopItem.consumableId then
                rewardItem = { type = "consumable", consumableId = shopItem.consumableId, count = shopItem.count or 1 }
            end

            if not rewardItem then
                SendResult(false, shopItemId, balance, "物品生成失败")
                finish()
                return
            end

            -- 原子扣积分
            local cjson = require("cjson")
            local commit = serverCloud:BatchCommit("剑气积分商店购买")
            commit:MoneyCost(userId, SWC.POINT_KEY, shopItem.price)
            commit:Commit({
                ok = function()
                    Logger.info("SwordWall", "Shop buy OK: userId=" .. userId
                        .. " item=" .. shopItemId .. " price=" .. shopItem.price)

                    -- 读新余额返回（物品数据一并返回，客户端自行入库）
                    serverCloud.money:Get(userId, {
                        ok = function(newMoneys)
                            local newBal = (newMoneys and newMoneys[SWC.POINT_KEY]) or (balance - shopItem.price)
                            -- 附带物品数据
                            local resp = VariantMap()
                            resp["ok"] = Variant(true)
                            resp["itemId"] = Variant(shopItemId)
                            resp["balance"] = Variant(newBal)
                            resp["error"] = Variant("")
                            resp["reward"] = Variant(cjson.encode(rewardItem))
                            connection:SendRemoteEvent(SaveProtocol.S2C_SwordWallShopBuyResult, true, resp)
                            finish()
                        end,
                        error = function()
                            local resp = VariantMap()
                            resp["ok"] = Variant(true)
                            resp["itemId"] = Variant(shopItemId)
                            resp["balance"] = Variant(balance - shopItem.price)
                            resp["error"] = Variant("")
                            resp["reward"] = Variant(cjson.encode(rewardItem))
                            connection:SendRemoteEvent(SaveProtocol.S2C_SwordWallShopBuyResult, true, resp)
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

-- 连接断开时清理活跃副本注册
function SwordWallHandler.OnDisconnect(connKey)
    activeRuns_[connKey] = nil
end

return SwordWallHandler
