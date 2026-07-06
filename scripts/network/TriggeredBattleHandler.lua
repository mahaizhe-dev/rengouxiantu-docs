-- ============================================================================
-- TriggeredBattleHandler.lua - 触发式战斗服务端发奖
-- ============================================================================

local M = {}

---@type table<string, any>
local SaveProtocol = require("network.SaveProtocol")
local Session = require("network.ServerSession")
local SaveBackupService = require("network.SaveBackupService")
local TriggeredBattleConfig = require("config.TriggeredBattleConfig")
local RewardUtil = require("systems.TriggeredBattleReward")
local Logger = require("utils.Logger")

---@diagnostic disable-next-line: undefined-global
---@type any
local cjson = cjson
if not cjson then
    local ok, lib = pcall(require, "cjson") ---@diagnostic disable-line: unresolved-require
    if ok then cjson = lib end
end

---@type table<string, any>
local activeRuns_ = {}
---@type table<string, any>
local claimedRuns_ = {}
---@type string[]
local claimedRunOrder_ = {}
local MAX_CACHED_RUNS = 80

local function connKeyOf(connection)
    return Session.ConnKey and Session.ConnKey(connection) or tostring(connection)
end

local function send(connection, eventName, fields)
    local resp = VariantMap()
    for k, v in pairs(fields or {}) do
        resp[k] = Variant(v)
    end
    Session.SafeSend(connection, eventName, resp)
end

local function sendStart(connection, fields)
    send(connection, SaveProtocol.S2C_TriggeredBattleStartResult, fields)
end

local function sendFinish(connection, fields)
    send(connection, SaveProtocol.S2C_TriggeredBattleFinishResult, fields)
end

local function getString(eventData, key, default)
    local ok, value = pcall(function()
        local v = eventData[key]
        return v and v:GetString() or nil
    end)
    if ok and value ~= nil then return value end
    return default or ""
end

local function markClaimed(runId, result)
    if claimedRuns_[runId] then return end
    claimedRuns_[runId] = result
    claimedRunOrder_[#claimedRunOrder_ + 1] = runId
    if #claimedRunOrder_ > MAX_CACHED_RUNS then
        local old = table.remove(claimedRunOrder_, 1)
        claimedRuns_[old] = nil
    end
end

local function isCompleted(saveData, eventId)
    return TriggeredBattleConfig.IsCompleted(saveData and saveData.triggeredBattles, eventId)
end

function M.HandleStart(connection, eventData)
    local connKey = connKeyOf(connection)
    local userId = Session.GetUserId(connKey)
    local slot = Session.connSlots_[connKey]
    if not userId or not slot then
        sendStart(connection, { ok = false, message = "角色存档未加载" })
        return
    end

    local eventId = getString(eventData, "eventId")
    local cfg = TriggeredBattleConfig.Get(eventId)
    if not cfg then
        sendStart(connection, { ok = false, eventId = eventId, message = "事件配置不存在" })
        return
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            sendStart(connection, { ok = false, eventId = eventId, message = "存档读取失败" })
            return
        end
        if isCompleted(saveData, eventId) then
            sendStart(connection, {
                ok = true,
                eventId = eventId,
                alreadyCompleted = true,
                message = cfg.completedHint or "已完成",
            })
            return
        end

        local reward = cfg.reward or {}
        local canAdd, reason = RewardUtil.CanAddConsumable(
            saveData.backpack or {},
            reward.consumableId,
            reward.count or 1
        )
        if not canAdd then
            local msg = reason == "backpack_full" and "背包已满，请清理后再挑战" or "奖励配置异常"
            sendStart(connection, { ok = false, eventId = eventId, message = msg })
            return
        end

        local runId = eventId .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
        activeRuns_[connKey] = {
            eventId = eventId,
            runId = runId,
            startTime = os.time(),
        }

        Logger.info("TriggeredBattle", "start userId=" .. tostring(userId)
            .. " slot=" .. tostring(slot) .. " event=" .. eventId .. " runId=" .. runId)
        sendStart(connection, { ok = true, eventId = eventId, runId = runId, alreadyCompleted = false })
    end)
end

function M.HandleFinish(connection, eventData)
    local connKey = connKeyOf(connection)
    local userId = Session.GetUserId(connKey)
    local slot = Session.connSlots_[connKey]
    if not userId or not slot then
        sendFinish(connection, { ok = false, message = "角色存档未加载" })
        return
    end

    local eventId = getString(eventData, "eventId")
    local runId = getString(eventData, "runId")
    local result = getString(eventData, "result", "victory")
    local cfg = TriggeredBattleConfig.Get(eventId)
    if not cfg then
        sendFinish(connection, { ok = false, eventId = eventId, runId = runId, message = "事件配置不存在" })
        return
    end
    if result ~= "victory" then
        activeRuns_[connKey] = nil
        sendFinish(connection, { ok = true, eventId = eventId, runId = runId, noReward = true })
        return
    end

    local cached = claimedRuns_[runId]
    if cached then
        sendFinish(connection, cached)
        return
    end

    local runInfo = activeRuns_[connKey]
    if not runInfo or runInfo.eventId ~= eventId or runInfo.runId ~= runId then
        sendFinish(connection, { ok = false, eventId = eventId, runId = runId, message = "挑战记录无效，请重新挑战" })
        return
    end

    if not Session.AcquireSlotLock(userId, slot) then
        sendFinish(connection, { ok = false, eventId = eventId, runId = runId, message = "存档正在写入，请稍后重试" })
        return
    end

    local released = false
    local function release()
        if not released then
            released = true
            Session.ReleaseSlotLock(userId, slot)
        end
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            release()
            sendFinish(connection, { ok = false, eventId = eventId, runId = runId, message = "存档读取失败，请重新挑战" })
            return
        end

        saveData.triggeredBattles = saveData.triggeredBattles or {}
        if isCompleted(saveData, eventId) then
            activeRuns_[connKey] = nil
            local response = {
                ok = true,
                eventId = eventId,
                runId = runId,
                alreadyCompleted = true,
                stateJson = cjson.encode(saveData.triggeredBattles[eventId]),
                rewardPatch = "[]",
                message = cfg.completedHint or "已完成",
            }
            markClaimed(runId, response)
            release()
            sendFinish(connection, response)
            return
        end

        local reward = cfg.reward or {}
        saveData.backpack = saveData.backpack or {}
        local addedOk, _, changes, reason = RewardUtil.AddConsumableToBackpack(
            saveData.backpack,
            reward.consumableId,
            reward.count or 1,
            eventId
        )
        if not addedOk then
            release()
            local msg = reason == "backpack_full" and "背包已满，请清理后重新挑战" or "奖励写入失败，请重新挑战"
            sendFinish(connection, { ok = false, eventId = eventId, runId = runId, message = msg })
            return
        end

        saveData.triggeredBattles[eventId] = TriggeredBattleConfig.CloneCompletion(eventId, runId)
        saveData.timestamp = os.time()

        SaveBackupService.BeforeOverwrite(userId, slot, "triggered battle reward " .. eventId, function()
            serverCloud:BatchSet(userId)
                :Set("save_" .. tostring(slot), saveData)
                :Save("触发战斗奖励", {
                    ok = function()
                        activeRuns_[connKey] = nil
                        local response = {
                            ok = true,
                            eventId = eventId,
                            runId = runId,
                            stateJson = cjson.encode(saveData.triggeredBattles[eventId]),
                            rewardPatch = cjson.encode(changes),
                            rewardId = reward.consumableId or "",
                            rewardCount = reward.count or 1,
                            message = "获得 " .. tostring((RewardUtil.GetConsumableData(reward.consumableId) or {}).name or reward.consumableId),
                        }
                        markClaimed(runId, response)
                        Logger.info("TriggeredBattle", "reward ok userId=" .. tostring(userId)
                            .. " slot=" .. tostring(slot) .. " event=" .. eventId .. " runId=" .. runId)
                        release()
                        sendFinish(connection, response)
                    end,
                    error = function(code, reason2)
                        Logger.warn("TriggeredBattle", "reward save failed code=" .. tostring(code)
                            .. " reason=" .. tostring(reason2) .. " event=" .. eventId)
                        release()
                        sendFinish(connection, { ok = false, eventId = eventId, runId = runId, message = "奖励保存失败，请重新挑战" })
                    end,
                })
        end, function(code, reason2)
            Logger.warn("TriggeredBattle", "backup failed code=" .. tostring(code)
                .. " reason=" .. tostring(reason2) .. " event=" .. eventId)
            release()
            sendFinish(connection, { ok = false, eventId = eventId, runId = runId, message = "奖励备份失败，请重新挑战" })
        end)
    end)
end

function M.CleanupConnection(connKey)
    activeRuns_[connKey] = nil
end

return M
