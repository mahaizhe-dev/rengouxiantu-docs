-- ============================================================================
-- TreasureMapHandler.lua - authoritative treasure map transactions
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local SaveBackupService = require("network.SaveBackupService")
local AccountCosmeticsService = require("network.AccountCosmeticsService")
local AccountImmortalBodiesService = require("network.AccountImmortalBodiesService")
local BackpackUtils = require("network.BackpackUtils")
local RewardUtil = require("systems.TriggeredBattleReward")
local TradeLock = require("systems.BlackMarketTradeLock")
local GameConfig = require("config.GameConfig")
local Config = require("config.TreasureMapConfig")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson
if not cjson then
    local ok, lib = pcall(require, "cjson") ---@diagnostic disable-line: unresolved-require
    if ok then cjson = lib end
end

local M = {}
local activeRequests_ = {}
local openSessions_ = {}

local function Clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[Clone(key, seen)] = Clone(child, seen)
    end
    return result
end

local function NowMs()
    local seconds = (time and time.elapsedTime) or os.clock() ---@diagnostic disable-line: undefined-global
    return math.floor(seconds * 1000)
end

local function NewId(prefix, userId, slot)
    return tostring(prefix) .. "-" .. tostring(userId) .. "-" .. tostring(slot)
        .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
end

local function ExtractContext(eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Session.ConnKey(connection)
    local userId = Session.GetUserId(connKey)
    local slot = Session.connSlots_[connKey]
    if not userId or not slot then return nil, nil, nil, connection end
    return connKey, userId, slot, connection
end

local function ReadString(eventData, key, default)
    local ok, result = pcall(function()
        local value = eventData[key]
        return value and value:GetString() or nil
    end)
    if ok and result ~= nil then return result end
    return default or ""
end

local function Send(connection, eventName, fields)
    local data = VariantMap()
    for key, value in pairs(fields or {}) do data[key] = Variant(value) end
    Session.SafeSend(connection, eventName, data)
end

local function SendError(connection, eventName, message, requestId)
    Send(connection, eventName, {
        ok = false,
        reason = message or "操作失败",
        message = message or "操作失败",
        requestId = requestId or "",
    })
end

local function SendGMResult(connection, cmd, ok, message, extras)
    local fields = {
        ok = ok == true,
        cmd = cmd or "",
        msg = message or "",
    }
    for key, value in pairs(extras or {}) do fields[key] = value end
    Send(connection, SaveProtocol.S2C_GMCommandResult, fields)
end

local function EnsureState(raw)
    raw = type(raw) == "table" and Clone(raw) or {}
    raw.version = Config.VERSION
    raw.revision = math.max(0, math.floor(tonumber(raw.revision) or 0))
    raw.completedRuns = type(raw.completedRuns) == "table" and raw.completedRuns or {}
    raw.requestHistory = type(raw.requestHistory) == "table" and raw.requestHistory or {}
    if type(raw.session) ~= "table" then raw.session = nil end
    if type(raw.active) ~= "table" then raw.active = nil end
    return raw
end

local function StateForClient(state)
    local result = {
        version = state.version,
        revision = state.revision,
        session = Clone(state.session),
        active = nil,
    }
    if state.active then
        result.active = {
            runId = state.active.runId,
            requestId = state.active.requestId,
            islandId = state.active.islandId,
            chestId = state.active.chestId,
            rewardType = state.active.rewardType,
            status = state.active.status,
            createdAt = state.active.createdAt,
        }
    end
    return result
end

local function StateJson(state)
    return cjson.encode(StateForClient(state))
end

local function ActiveBindingIsValid(active)
    if type(active) ~= "table" or type(active.pendingReward) ~= "table" then
        return false
    end
    local rewardType = active.pendingReward.rewardType
    local island = rewardType and Config.ISLAND_BY_REWARD_TYPE[rewardType] or nil
    return island ~= nil
        and active.rewardType == rewardType
        and active.islandId == island.islandId
        and active.chestId == island.chest.chestId
end

local function ReadSaveAndState(userId, slot, callback, errorCallback)
    local saveKey = "save_" .. tostring(slot)
    local oldKey = "save_data_" .. tostring(slot)
    local bag1Key = "save_bag1_" .. tostring(slot)
    local bag2Key = "save_bag2_" .. tostring(slot)
    local stateKey = Config.STATE_KEY_PREFIX .. tostring(slot)

    serverCloud:BatchGet(userId)
        :Key(saveKey)
        :Key(oldKey)
        :Key(bag1Key)
        :Key(bag2Key)
        :Key(stateKey)
        :Fetch({
            ok = function(scores)
                local saveData = scores[saveKey]
                if type(saveData) ~= "table" then
                    saveData = scores[oldKey]
                    if type(saveData) == "table" then
                        saveData = Clone(saveData)
                        saveData.backpack = saveData.backpack or {}
                        for _, bagKey in ipairs({ bag1Key, bag2Key }) do
                            local bag = scores[bagKey]
                            if type(bag) == "table" then
                                for key, item in pairs(bag) do saveData.backpack[key] = item end
                            end
                        end
                    end
                end
                callback(saveData, EnsureState(scores[stateKey]))
            end,
            error = function(code, reason)
                if errorCallback then errorCallback(code, reason) end
            end,
        })
end

local function SaveMainAndState(userId, slot, saveData, state, desc, accountWrites, callbacks)
    saveData.timestamp = os.time()
    SaveBackupService.BeforeOverwrite(userId, slot, desc, function()
        local batch = serverCloud:BatchSet(userId)
            :Set("save_" .. tostring(slot), saveData)
            :Set(Config.STATE_KEY_PREFIX .. tostring(slot), state)
        for key, value in pairs(accountWrites or {}) do
            batch:Set(key, value)
        end
        batch:Save(desc, callbacks)
    end, callbacks.error)
end

local function SaveStateOnly(userId, slot, state, desc, callbacks)
    serverCloud:BatchSet(userId)
        :Set(Config.STATE_KEY_PREFIX .. tostring(slot), state)
        :Save(desc, callbacks)
end

local function ConsumeMap(backpack)
    local patch = {}
    local function Pass(wantNoResell)
        for slot = 1, GameConfig.BACKPACK_SIZE do
            local key = tostring(slot)
            local item = backpack[key] or backpack[slot]
            if item and item.category == "consumable"
                and item.consumableId == Config.MAP_ITEM_ID
                and not TradeLock.IsLockedServerSide(item)
                and TradeLock.IsNoResell(item) == wantNoResell then
                local count = item.count or 1
                if count <= 1 then
                    backpack[key] = nil
                    backpack[slot] = nil
                    patch[#patch + 1] = { slot = slot, clear = true }
                else
                    item.count = count - 1
                    patch[#patch + 1] = { slot = slot, item = item }
                end
                return true, patch
            end
        end
        return false, patch
    end
    local ok
    ok, patch = Pass(true)
    if ok then return true, patch end
    return Pass(false)
end

local function MapSnapshotJson(backpack)
    local snapshot = {}
    for slot = 1, GameConfig.BACKPACK_SIZE do
        local item = backpack and (backpack[tostring(slot)] or backpack[slot]) or nil
        if item and item.category == "consumable"
            and item.consumableId == Config.MAP_ITEM_ID then
            snapshot[#snapshot + 1] = {
                slot = slot,
                item = Clone(item),
            }
        end
    end
    return cjson.encode(snapshot)
end

local function TrimCompleted(state)
    local count = 0
    local oldestId, oldestAt
    for runId, record in pairs(state.completedRuns) do
        count = count + 1
        local completedAt = tonumber(record.completedAt) or 0
        if not oldestAt or completedAt < oldestAt then
            oldestAt, oldestId = completedAt, runId
        end
    end
    while count > Config.COMPLETED_RUN_LIMIT and oldestId do
        state.completedRuns[oldestId] = nil
        count = count - 1
        oldestId, oldestAt = nil, nil
        for runId, record in pairs(state.completedRuns) do
            local completedAt = tonumber(record.completedAt) or 0
            if not oldestAt or completedAt < oldestAt then
                oldestAt, oldestId = completedAt, runId
            end
        end
    end
end

local function ReplayCompleted(connection, state, record)
    local response = Clone(record.response or {})
    response.ok = true
    response.replayed = true
    response.stateJson = StateJson(state)
    Send(connection, SaveProtocol.S2C_TreasureMap_OpenResult, response)
end

local function LatestCompleted(state)
    local latest = nil
    for _, record in pairs(state.completedRuns or {}) do
        if not latest or (tonumber(record.completedAt) or 0) > (tonumber(latest.completedAt) or 0) then
            latest = record
        end
    end
    return latest
end

local function WithSlotLock(connKey, userId, slot, connection, eventName, work)
    if activeRequests_[connKey] then
        SendError(connection, eventName, "操作进行中，请稍候")
        return
    end
    if not Session.AcquireSlotLock(userId, slot) then
        SendError(connection, eventName, "存档正在写入，请稍后重试")
        return
    end
    activeRequests_[connKey] = true
    local released = false
    local function Release()
        if released then return end
        released = true
        activeRequests_[connKey] = nil
        Session.ReleaseSlotLock(userId, slot)
    end
    work(Release)
end

function M.HandleQueryState(eventType, eventData)
    local connKey, userId, slot, connection = ExtractContext(eventData)
    if not userId then return end
    WithSlotLock(connKey, userId, slot, connection,
        SaveProtocol.S2C_TreasureMap_State, function(Release)
        ReadSaveAndState(userId, slot, function(saveData, state)
            if not saveData then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_State, "角色存档读取失败")
                return
            end

            local function SendState()
                local recovery = nil
                if state.session and not state.active then
                    local latest = LatestCompleted(state)
                    recovery = latest and latest.response or nil
                end
                Release()
                Send(connection, SaveProtocol.S2C_TreasureMap_State, {
                    ok = true,
                    stateJson = StateJson(state),
                    recoveryJson = recovery and cjson.encode(recovery) or "",
                    mapSnapshotJson = MapSnapshotJson(saveData.backpack),
                    mapCount = BackpackUtils.CountUnlockedItem(
                        saveData.backpack or {}, Config.MAP_ITEM_ID),
                })
            end

            local sessionId = state.session and state.session.sessionId or nil
            local active = state.active
            local player = saveData.player
            local savedSessionId = player and player.treasureSessionId or nil
            local savedRevision = math.max(
                0, math.floor(tonumber(player and player.treasureRevision) or 0))
            if savedRevision > state.revision then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_State,
                    "藏宝状态版本异常，已停止恢复")
                return
            end
            local needsSessionMigration =
                tostring(savedSessionId or "") ~= tostring(sessionId or "")
            local needsRevisionMigration = savedRevision ~= state.revision
            if needsSessionMigration or needsRevisionMigration then
                local island = active and Config.ISLAND_BY_ID[active.islandId] or nil
                if not player or (active and (not island or not ActiveBindingIsValid(active))) then
                    Release()
                    SendError(connection, SaveProtocol.S2C_TreasureMap_State,
                        "藏宝恢复数据异常")
                    return
                end
                saveData = Clone(saveData)
                saveData.player.treasureSessionId = sessionId
                saveData.player.treasureRunId = active and active.runId or nil
                saveData.player.treasureRevision = state.revision
                if active then
                    saveData.player.chapter = Config.ENTRY.chapter
                    saveData.player.x = island.spawn.x
                    saveData.player.y = island.spawn.y
                end
                SaveMainAndState(userId, slot, saveData, state,
                    "treasure_map_resume_migration", nil, {
                    ok = SendState,
                    error = function()
                        Release()
                        SendError(connection, SaveProtocol.S2C_TreasureMap_State,
                            "藏宝恢复保存失败")
                    end,
                })
                return
            end
            SendState()
        end, function()
            Release()
            SendError(connection, SaveProtocol.S2C_TreasureMap_State, "藏宝进度读取失败")
        end)
    end)
end

local function RememberRequest(state, active, status, now)
    if not active or not active.requestId or active.requestId == "" then return end
    state.requestHistory = state.requestHistory or {}
    state.requestHistory[active.requestId] = {
        runId = active.runId,
        status = status,
        finishedAt = now or os.time(),
    }

    local count = 0
    local oldestId, oldestAt
    for requestId, record in pairs(state.requestHistory) do
        count = count + 1
        local finishedAt = tonumber(record.finishedAt) or 0
        if not oldestAt or finishedAt < oldestAt then
            oldestId, oldestAt = requestId, finishedAt
        end
    end
    while count > Config.COMPLETED_RUN_LIMIT and oldestId do
        state.requestHistory[oldestId] = nil
        count = count - 1
        oldestId, oldestAt = nil, nil
        for requestId, record in pairs(state.requestHistory) do
            local finishedAt = tonumber(record.finishedAt) or 0
            if not oldestAt or finishedAt < oldestAt then
                oldestId, oldestAt = requestId, finishedAt
            end
        end
    end
end

function M.HandleUse(eventType, eventData)
    local connKey, userId, slot, connection = ExtractContext(eventData)
    if not userId then return end
    local requestId = ReadString(eventData, "requestId")
    local entryId = ReadString(eventData, "entryId")
    local mode = ReadString(eventData, "mode", "entry")
    if requestId == "" then
        SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult, "请求标识无效")
        return
    end

    WithSlotLock(connKey, userId, slot, connection,
        SaveProtocol.S2C_TreasureMap_UseResult, function(Release)
        ReadSaveAndState(userId, slot, function(saveData, state)
            if not saveData or not saveData.player then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult, "存档读取失败", requestId)
                return
            end
            if state.active then
                if state.active.requestId == requestId then
                    local active = state.active
                    if not ActiveBindingIsValid(active) then
                        Release()
                        SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult,
                            "藏宝状态绑定异常", requestId)
                        return
                    end
                    Release()
                    Send(connection, SaveProtocol.S2C_TreasureMap_UseResult, {
                        ok = true,
                        replayed = true,
                        requestId = requestId,
                        runId = active.runId,
                        sessionId = state.session and state.session.sessionId or "",
                        islandId = active.islandId,
                        chestId = active.chestId,
                        rewardType = active.rewardType,
                        backpackPatch = "[]",
                        mapSnapshotJson = MapSnapshotJson(saveData.backpack),
                        stateJson = StateJson(state),
                    })
                else
                    Release()
                    SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult,
                        "请先完成当前藏宝图指向的宝藏", requestId)
                end
                return
            end
            if state.requestHistory and state.requestHistory[requestId] then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult,
                    "该藏宝请求已经结束，不能重复使用", requestId)
                return
            end
            if state.session then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult,
                    "请先确认奖励并归航，再开始下一次寻宝", requestId)
                return
            end
            if mode ~= "entry" or entryId ~= Config.ENTRY.id
                or tonumber(saveData.player.chapter) ~= Config.ENTRY.chapter then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult,
                    "藏宝图只能在第四章使用", requestId)
                return
            end
            if BackpackUtils.CountUnlockedItem(saveData.backpack or {}, Config.MAP_ITEM_ID) < 1 then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult, "藏宝图不足", requestId)
                return
            end

            local nextSave = Clone(saveData)
            nextSave.backpack = nextSave.backpack or {}
            local consumed, patch = ConsumeMap(nextSave.backpack)
            if not consumed then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult, "藏宝图扣除失败", requestId)
                return
            end

            local reward, island = Config.RollReward(nil)
            local now = os.time()
            local runId = NewId("tm-run", userId, slot)
            local sessionId = state.session and state.session.sessionId
                or NewId("tm-session", userId, slot)
            state.revision = state.revision + 1
            state.session = {
                sessionId = sessionId,
                returnPointId = Config.RETURN_POINT.id,
                currentIslandId = island.islandId,
                startedAt = state.session and state.session.startedAt or now,
                updatedAt = now,
            }
            state.active = {
                runId = runId,
                requestId = requestId,
                islandId = island.islandId,
                chestId = island.chest.chestId,
                rewardType = reward.rewardType,
                status = "entered",
                pendingReward = reward,
                createdAt = now,
                updatedAt = now,
            }
            nextSave.player.chapter = Config.ENTRY.chapter
            nextSave.player.x = island.spawn.x
            nextSave.player.y = island.spawn.y
            nextSave.player.treasureSessionId = sessionId
            nextSave.player.treasureRunId = runId
            nextSave.player.treasureRevision = state.revision

            SaveMainAndState(userId, slot, nextSave, state, "treasure_map_use:" .. runId, nil, {
                ok = function()
                    Release()
                    Send(connection, SaveProtocol.S2C_TreasureMap_UseResult, {
                        ok = true,
                        requestId = requestId,
                        runId = runId,
                        sessionId = sessionId,
                        islandId = island.islandId,
                        chestId = island.chest.chestId,
                        rewardType = reward.rewardType,
                        backpackPatch = cjson.encode(patch),
                        mapSnapshotJson = MapSnapshotJson(nextSave.backpack),
                        stateJson = StateJson(state),
                    })
                end,
                error = function()
                    Release()
                    SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult,
                        "藏宝图保存失败，请重试", requestId)
                end,
            })
        end, function()
            Release()
            SendError(connection, SaveProtocol.S2C_TreasureMap_UseResult, "存档读取失败", requestId)
        end)
    end)
end

function M.HandleContinue(eventType, eventData)
    M.HandleQueryState(eventType, eventData)
end

function M.HandleStartOpen(eventType, eventData)
    local connKey, userId, slot, connection = ExtractContext(eventData)
    if not userId then return end
    local runId = ReadString(eventData, "runId")
    local islandId = ReadString(eventData, "islandId")
    local chestId = ReadString(eventData, "chestId")
    ReadSaveAndState(userId, slot, function(_, state)
        local active = state.active
        if not ActiveBindingIsValid(active)
            or active.runId ~= runId or active.islandId ~= islandId
            or active.chestId ~= chestId then
            SendError(connection, SaveProtocol.S2C_TreasureMap_StartOpenResult, "这不是藏宝图指向的宝藏")
            return
        end
        local token = NewId("tm-open", userId, slot)
        openSessions_[connKey] = {
            token = token,
            runId = runId,
            chestId = chestId,
            startedAtMs = NowMs(),
        }
        Send(connection, SaveProtocol.S2C_TreasureMap_StartOpenResult, {
            ok = true,
            runId = runId,
            chestId = chestId,
            openToken = token,
            serverStartedAt = openSessions_[connKey].startedAtMs,
            minDurationMs = Config.OPEN_DURATION_MS,
        })
    end, function()
        SendError(connection, SaveProtocol.S2C_TreasureMap_StartOpenResult, "藏宝进度读取失败")
    end)
end

function M.HandleCancelOpen(eventType, eventData)
    local connKey, userId = ExtractContext(eventData)
    if not userId then return end
    openSessions_[connKey] = nil
end

local function CompleteReward(userId, slot, connection, Release, saveData, state, transaction)
    local active = state.active
    local reward = active.pendingReward
    local nextSave = Clone(saveData)
    local nextState = Clone(state)
    nextSave.backpack = nextSave.backpack or {}
    nextSave.player = nextSave.player or {}
    local backpackPatch = {}
    local playerPatch = {}
    local cosmeticsPatch = {}
    local immortalBodiesPatch = {}
    local rewardSummary = {
        kind = reward.kind,
        rewardType = reward.rewardType,
        itemId = reward.itemId,
        amount = reward.amount,
        skinId = reward.skinId,
        bodyId = reward.bodyId,
    }
    local updatedCosmetics = nil
    local updatedImmortalBodies = nil

    if reward.kind == "consumable" then
        local ok, _, changes, reason = RewardUtil.AddConsumableToBackpack(
            nextSave.backpack, reward.itemId, reward.amount or 1, "treasure_map_" .. active.runId)
        if not ok then
            if transaction then transaction:Release() end
            Release()
            local message = reason == "backpack_full"
                and "背包空间不足，奖励已保留" or "奖励配置异常"
            SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult, message)
            return
        end
        backpackPatch = changes
    elseif reward.kind == "pet_skin" then
        updatedCosmetics, rewardSummary.skinResult = AccountCosmeticsService.PrepareSkinGrant(
            transaction.cosmetics, reward.skinId, active.runId, "treasure_map")
        if rewardSummary.skinResult.duplicate then
            nextSave.player.lingYun = (nextSave.player.lingYun or 0)
                + Config.DUPLICATE_SKIN_LINGYUN
            playerPatch.lingYun = nextSave.player.lingYun
            rewardSummary.duplicateLingYun = Config.DUPLICATE_SKIN_LINGYUN
        else
            cosmeticsPatch.skinId = reward.skinId
            cosmeticsPatch.version = updatedCosmetics.version
        end
    elseif reward.kind == "immortal_body" then
        updatedImmortalBodies, rewardSummary.bodyResult =
            AccountImmortalBodiesService.PrepareBodyGrant(
                transaction.immortalBodies, reward.bodyId, active.runId,
                "treasure_map", slot)
        immortalBodiesPatch = Clone(updatedImmortalBodies)
        if rewardSummary.bodyResult.duplicate then
            nextSave.player.lingYun = (nextSave.player.lingYun or 0)
                + Config.DUPLICATE_BODY_LINGYUN
            playerPatch.lingYun = nextSave.player.lingYun
            rewardSummary.duplicateLingYun = Config.DUPLICATE_BODY_LINGYUN
        end
    else
        if transaction then transaction:Release() end
        Release()
        SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult, "奖励配置异常")
        return
    end

    local now = os.time()
    nextState.revision = nextState.revision + 1
    nextSave.player.treasureRevision = nextState.revision
    RememberRequest(nextState, active, "completed", now)
    nextState.active = nil
    if nextState.session then nextState.session.updatedAt = now end
    local response = {
        runId = active.runId,
        islandId = active.islandId,
        chestId = active.chestId,
        rewardJson = cjson.encode(rewardSummary),
        backpackPatch = cjson.encode(backpackPatch),
        playerPatch = cjson.encode(playerPatch),
        cosmeticsPatch = cjson.encode(cosmeticsPatch),
        immortalBodiesPatch = cjson.encode(immortalBodiesPatch),
    }
    nextState.completedRuns[active.runId] = {
        completedAt = now,
        islandId = active.islandId,
        chestId = active.chestId,
        rewardSummary = Clone(rewardSummary),
        response = Clone(response),
    }
    TrimCompleted(nextState)

    local accountWrites = {}
    if updatedCosmetics then
        accountWrites[AccountCosmeticsService.STORAGE_KEY] = updatedCosmetics
    end
    if updatedImmortalBodies then
        accountWrites[AccountImmortalBodiesService.STORAGE_KEY] = updatedImmortalBodies
    end

    SaveMainAndState(userId, slot, nextSave, nextState,
        "treasure_map_open:" .. active.runId, accountWrites, {
        ok = function()
            if transaction then transaction:Release() end
            Release()
            response.ok = true
            response.stateJson = StateJson(nextState)
            Send(connection, SaveProtocol.S2C_TreasureMap_OpenResult, response)
        end,
        error = function()
            if transaction then transaction:Release() end
            Release()
            SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult,
                "奖励保存失败，宝藏已保留")
        end,
    })
end

function M.HandleCompleteOpen(eventType, eventData)
    local connKey, userId, slot, connection = ExtractContext(eventData)
    if not userId then return end
    local runId = ReadString(eventData, "runId")
    local chestId = ReadString(eventData, "chestId")
    local openToken = ReadString(eventData, "openToken")

    WithSlotLock(connKey, userId, slot, connection,
        SaveProtocol.S2C_TreasureMap_OpenResult, function(Release)
        ReadSaveAndState(userId, slot, function(saveData, state)
            local completed = state.completedRuns[runId]
            if completed then
                openSessions_[connKey] = nil
                Release()
                ReplayCompleted(connection, state, completed)
                return
            end
            local opening = openSessions_[connKey]
            if not opening or opening.token ~= openToken or opening.runId ~= runId
                or opening.chestId ~= chestId then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult,
                    "开箱状态异常，请重新开启")
                return
            end
            if NowMs() - opening.startedAtMs < Config.OPEN_DURATION_MS then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult, "开启时间不足")
                return
            end
            local active = state.active
            if not saveData or not ActiveBindingIsValid(active)
                or active.runId ~= runId or active.chestId ~= chestId then
                Release()
                SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult, "藏宝授权已失效")
                return
            end
            openSessions_[connKey] = nil
            if active.pendingReward.kind == "pet_skin" then
                AccountCosmeticsService.Begin(userId, {
                    ok = function(transaction)
                        CompleteReward(
                            userId, slot, connection, Release, saveData, state, transaction)
                    end,
                    busy = function()
                        Release()
                        SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult,
                            "皮肤数据处理中，请稍后重试")
                    end,
                    error = function()
                        Release()
                        SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult,
                            "皮肤数据读取失败，奖励已保留")
                    end,
                })
            elseif active.pendingReward.kind == "immortal_body" then
                AccountImmortalBodiesService.Begin(userId, {
                    ok = function(transaction)
                        CompleteReward(
                            userId, slot, connection, Release, saveData, state, transaction)
                    end,
                    busy = function()
                        Release()
                        SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult,
                            "仙体数据处理中，请稍后重试")
                    end,
                    error = function()
                        Release()
                        SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult,
                            "仙体数据读取失败，奖励已保留")
                    end,
                })
            else
                CompleteReward(userId, slot, connection, Release, saveData, state, nil)
            end
        end, function()
            Release()
            SendError(connection, SaveProtocol.S2C_TreasureMap_OpenResult, "藏宝进度读取失败")
        end)
    end)
end

local function MutateState(eventData, eventName, mutator, saveMain)
    local connKey, userId, slot, connection = ExtractContext(eventData)
    if not userId then return end
    WithSlotLock(connKey, userId, slot, connection, eventName, function(Release)
        ReadSaveAndState(userId, slot, function(saveData, state)
            local nextSave = saveData and Clone(saveData) or nil
            if saveMain and (not nextSave or not nextSave.player) then
                Release()
                SendError(connection, eventName, "角色存档读取失败")
                return
            end
            local ok, reason = mutator(state, connKey, nextSave)
            if ok == false then
                Release()
                SendError(connection, eventName, reason or "藏宝状态已变化，请重新查询")
                return
            end
            state.revision = state.revision + 1
            if saveMain then
                nextSave.player.treasureRevision = state.revision
            end
            local callbacks = {
                ok = function()
                    Release()
                    Send(connection, eventName, { ok = true, stateJson = StateJson(state) })
                end,
                error = function()
                    Release()
                    SendError(connection, eventName, "藏宝进度保存失败")
                end,
            }
            if saveMain then
                SaveMainAndState(userId, slot, nextSave, state,
                    "treasure_map_departure", nil, callbacks)
            else
                SaveStateOnly(userId, slot, state, "treasure_map_state_update", callbacks)
            end
        end, function()
            Release()
            SendError(connection, eventName, "藏宝进度读取失败")
        end)
    end)
end

function M.HandleAbandon(eventType, eventData)
    local expectedRunId = ReadString(eventData, "runId")
    local expectedSessionId = ReadString(eventData, "sessionId")
    MutateState(eventData, SaveProtocol.S2C_TreasureMap_AbandonResult,
        function(state, connKey, saveData)
        local active = state.active
        local session = state.session
        if not session or expectedSessionId == ""
            or session.sessionId ~= expectedSessionId
            or not active or active.runId ~= expectedRunId then
            return false, "本次寻宝状态已变化，未执行放弃"
        end
        openSessions_[connKey] = nil
        RememberRequest(state, active, "abandoned")
        state.active = nil
        state.session = nil
        saveData.player.chapter = Config.RETURN_POINT.chapter
        saveData.player.x = Config.RETURN_POINT.x
        saveData.player.y = Config.RETURN_POINT.y
        saveData.player.treasureSessionId = nil
        saveData.player.treasureRunId = nil
    end, true)
end

function M.HandleExit(eventType, eventData)
    local expectedRunId = ReadString(eventData, "runId")
    local expectedSessionId = ReadString(eventData, "sessionId")
    MutateState(eventData, SaveProtocol.S2C_TreasureMap_ExitResult,
        function(state, connKey, saveData)
        local active = state.active
        local session = state.session
        if not session or expectedSessionId == ""
            or session.sessionId ~= expectedSessionId
            or (active and active.runId ~= expectedRunId)
            or (not active and expectedRunId ~= "") then
            return false, "本次寻宝状态已变化，未执行归航"
        end
        openSessions_[connKey] = nil
        RememberRequest(state, active, "abandoned")
        -- Portal departure always ends the expedition. Offline recovery only
        -- applies when the player quits while still on the island.
        state.active = nil
        state.session = nil
        saveData.player.chapter = Config.RETURN_POINT.chapter
        saveData.player.x = Config.RETURN_POINT.x
        saveData.player.y = Config.RETURN_POINT.y
        saveData.player.treasureSessionId = nil
        saveData.player.treasureRunId = nil
    end, true)
end

function M.GMGrantMaps10(userId, slot, connection)
    local cmd = "treasure_maps_10"
    if not userId or not slot then
        SendGMResult(connection, cmd, false, "未选择角色存档")
        return
    end
    if not Session.AcquireSlotLock(userId, slot) then
        SendGMResult(connection, cmd, false, "存档正在写入，请稍后重试")
        return
    end

    local released = false
    local function Release()
        if released then return end
        released = true
        Session.ReleaseSlotLock(userId, slot)
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            Release()
            SendGMResult(connection, cmd, false, "存档读取失败")
            return
        end

        local nextSave = Clone(saveData)
        nextSave.backpack = nextSave.backpack or {}
        local ok, _, changes, reason = RewardUtil.AddConsumableToBackpack(
            nextSave.backpack, Config.MAP_ITEM_ID, 10, "gm_treasure_maps_10")
        if not ok then
            Release()
            local message = reason == "backpack_full"
                and "背包已满，无法发放藏宝图" or "藏宝图配置异常"
            SendGMResult(connection, cmd, false, message)
            return
        end

        nextSave.timestamp = os.time()
        SaveBackupService.BeforeOverwrite(userId, slot, "gm_treasure_maps_10", function()
            serverCloud:BatchSet(userId)
                :Set("save_" .. tostring(slot), nextSave)
                :Save("gm_treasure_maps_10", {
                    ok = function()
                        Release()
                        SendGMResult(connection, cmd, true, "藏宝图 ×10 已发放", {
                            backpackPatch = cjson.encode(changes),
                            mapCount = BackpackUtils.CountBackpackItem(
                                nextSave.backpack, Config.MAP_ITEM_ID),
                        })
                    end,
                    error = function()
                        Release()
                        SendGMResult(connection, cmd, false, "藏宝图保存失败")
                    end,
                })
        end, function()
            Release()
            SendGMResult(connection, cmd, false, "藏宝图保存前备份失败")
        end)
    end)
end

function M.CleanupConnection(connKey)
    activeRequests_[connKey] = nil
    openSessions_[connKey] = nil
end

return M
