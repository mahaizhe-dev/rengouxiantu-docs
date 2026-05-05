-- ============================================================================
-- TrialHandler.lua — 试炼塔每日供奉服务端 Handler
--
-- 职责：HandleTrialClaimDaily
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B2）
-- ============================================================================

local Session      = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")

local ConnKey              = Session.ConnKey
local GetUserId            = Session.GetUserId
local SafeSend             = Session.SafeSend
local AcquireSlotLock      = Session.AcquireSlotLock
local ReleaseSlotLock      = Session.ReleaseSlotLock
local ServerGetSlotData    = Session.ServerGetSlotData
local connSlots_           = Session.connSlots_
local trialClaimingActive_ = Session.trialClaimingActive_

local M = {}

-- ============================================================================
-- C2S_TrialClaimDaily — 试炼塔领取每日供奉（服务端校验）
-- ============================================================================

function M.HandleTrialClaimDaily(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    -- ① 内存锁：防止同一用户并发请求
    if trialClaimingActive_[connKey] then
        print("[Server] TrialClaimDaily: already processing, skip")
        return
    end
    trialClaimingActive_[connKey] = true

    print("[Server] TrialClaimDaily: userId=" .. tostring(userId))

    local slot = connSlots_[connKey]
    if not slot then
        print("[Server] WARNING: connSlots_ not loaded for connKey=" .. connKey .. ", rejecting")
        return
    end
    local saveKey = "save_" .. slot

    -- P0-2 修复：加锁防止与 auto-save 并发覆盖
    if not AcquireSlotLock(userId, slot) then
        trialClaimingActive_[connKey] = nil
        print("[Server] TrialClaimDaily: slot locked, rejecting")
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["msg"] = Variant("slot_locked")
        SafeSend(connection, SaveProtocol.S2C_TrialClaimDailyResult, data)
        return
    end

    ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            ReleaseSlotLock(userId, slot)
            trialClaimingActive_[connKey] = nil
            print("[Server] TrialClaimDaily: save data not found")
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["msg"] = Variant("存档未找到")
            SafeSend(connection, SaveProtocol.S2C_TrialClaimDailyResult, data)
            return
        end

            local trialTower = saveData.trialTower or {}
            local highestFloor = trialTower.highestFloor or 0
            local dailyClaimedTier = trialTower.dailyClaimedTier or 0

            -- 内联 TrialTowerConfig 常量和计算
            local DAILY_UNLOCK_FLOOR = 10
            local MAX_DAILY_TIER = 18

            local currentTier = 0
            if highestFloor >= DAILY_UNLOCK_FLOOR then
                currentTier = math.min(math.floor(highestFloor / 10), MAX_DAILY_TIER)
            end

            if currentTier <= 0 then
                ReleaseSlotLock(userId, slot)
                trialClaimingActive_[connKey] = nil
                local data = VariantMap()
                data["ok"] = Variant(false)
                data["msg"] = Variant("通关第10层后解锁每日奖励")
                SafeSend(connection, SaveProtocol.S2C_TrialClaimDailyResult, data)
                return
            end

            --- 内联 CalcDailyRewardByTier
            local function calcReward(tier)
                if tier <= 0 or tier > MAX_DAILY_TIER then return 0, 0 end
                local lingYun = (tier * 2 + 4) * 2
                local goldBar = math.max(1, math.floor((tier * 500 + 1000) / 500 + 0.5)) * 2
                return lingYun, goldBar
            end

            local serverToday = os.date("%Y-%m-%d")
            local quotaKey = "trial_daily_offering_s" .. slot

            if dailyClaimedTier < currentTier then
                -- ══════ 里程碑领取（逐档）══════
                local nextTier = dailyClaimedTier + 1
                local lingYun, goldBar = calcReward(nextTier)

                trialTower.dailyClaimedTier = nextTier
                saveData.trialTower = trialTower
                saveData.timestamp = os.time()

                -- ② 里程碑只需保存存档，不需要 QuotaAdd
                local commit = serverCloud:BatchCommit("试炼供奉里程碑")
                commit:ScoreSet(userId, saveKey, saveData)
                commit:Commit({
                    ok = function()
                        ReleaseSlotLock(userId, slot)
                        trialClaimingActive_[connKey] = nil
                        local data = VariantMap()
                        data["ok"] = Variant(true)
                        data["type"] = Variant("milestone")
                        data["lingYun"] = Variant(lingYun)
                        data["goldBar"] = Variant(goldBar)
                        data["claimedTier"] = Variant(nextTier)
                        data["serverDate"] = Variant(serverToday)
                        SafeSend(connection, SaveProtocol.S2C_TrialClaimDailyResult, data)
                        print("[Server] TrialClaimDaily milestone OK: tier=" .. nextTier
                            .. " lingYun=" .. lingYun .. " goldBar=" .. goldBar)
                    end,
                    error = function(code, reason)
                        ReleaseSlotLock(userId, slot)
                        trialClaimingActive_[connKey] = nil
                        print("[Server] TrialClaimDaily milestone commit FAILED: " .. tostring(reason))
                        local data = VariantMap()
                        data["ok"] = Variant(false)
                        data["msg"] = Variant("保存失败，请重试")
                        SafeSend(connection, SaveProtocol.S2C_TrialClaimDailyResult, data)
                    end,
                })
            else
                -- ══════ 每日重复领取（quota 原子阻塞）══════
                local lingYun, goldBar = calcReward(currentTier)
                trialTower.dailyDate = serverToday
                saveData.trialTower = trialTower
                saveData.timestamp = os.time()

                -- ② 原子事务：quota + 存档在同一 BatchCommit
                local commit = serverCloud:BatchCommit("试炼每日供奉")
                commit:QuotaAdd(userId, quotaKey, 1, 1, "day", 1)
                commit:ScoreSet(userId, saveKey, saveData)
                commit:Commit({
                    ok = function()
                        ReleaseSlotLock(userId, slot)
                        trialClaimingActive_[connKey] = nil
                        local data = VariantMap()
                        data["ok"] = Variant(true)
                        data["type"] = Variant("daily")
                        data["lingYun"] = Variant(lingYun)
                        data["goldBar"] = Variant(goldBar)
                        data["claimedTier"] = Variant(currentTier)
                        data["serverDate"] = Variant(serverToday)
                        SafeSend(connection, SaveProtocol.S2C_TrialClaimDailyResult, data)
                        print("[Server] TrialClaimDaily daily OK: tier=" .. currentTier
                            .. " lingYun=" .. lingYun .. " goldBar=" .. goldBar)
                    end,
                    error = function(code, reason)
                        ReleaseSlotLock(userId, slot)
                        trialClaimingActive_[connKey] = nil
                        local errStr = tostring(reason)
                        if errStr:find("limit") then
                            local data = VariantMap()
                            data["ok"] = Variant(false)
                            data["msg"] = Variant("今日已领取")
                            SafeSend(connection, SaveProtocol.S2C_TrialClaimDailyResult, data)
                        else
                            print("[Server] TrialClaimDaily commit error: " .. tostring(reason))
                            local data = VariantMap()
                            data["ok"] = Variant(false)
                            data["msg"] = Variant("服务器错误，请重试")
                            SafeSend(connection, SaveProtocol.S2C_TrialClaimDailyResult, data)
                        end
                    end,
                })
            end
    end)
end

return M
