-- ============================================================================
-- TreasureMapSystem.lua - fourth-chapter island travel and authoritative patches
-- ============================================================================

local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local SaveProtocol = require("network.SaveProtocol")
local GameConfig = require("config.GameConfig")
local Config = require("config.TreasureMapConfig")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local M = {
    state = { version = 1, revision = 0 },
}

local initialized_ = false
local gameMap_ = nil
local camera_ = nil
local channel_ = nil
local pendingOpen_ = false
local pendingUse_ = false
local pendingUseRequestId_ = nil
local pendingUseMode_ = nil
local pendingUseStage_ = nil
local pendingUseWait_ = 0
local pendingOpenWait_ = 0
local pendingExit_ = false
local pendingExitKind_ = nil
local awaitingResult_ = false
local awaitingRunId_ = nil
local resultWait_ = 0
local exitWait_ = 0
local lastPresentedRunId_ = nil
local teleportFxTimer_ = 0
local teleportFxKind_ = nil
local checkpointPending_ = false
local checkpointRetry_ = 0
local mapSnapshotReady_ = false

local function Decode(text, fallback)
    if not cjson or not text or text == "" then return fallback end
    local ok, value = pcall(cjson.decode, text)
    if ok and type(value) == "table" then return value end
    return fallback
end

local function ReadString(eventData, key, fallback)
    local ok, value = pcall(function()
        local variant = eventData[key]
        return variant and variant:GetString() or nil
    end)
    return ok and value ~= nil and value or (fallback or "")
end

local function ReadBool(eventData, key, fallback)
    local ok, value = pcall(function()
        local variant = eventData[key]
        return variant and variant:GetBool() or nil
    end)
    return ok and value ~= nil and value or fallback == true
end

local function ReadInt(eventData, key, fallback)
    local ok, value = pcall(function()
        local variant = eventData[key]
        return variant and variant:GetInt() or nil
    end)
    return ok and value ~= nil and value or (fallback or 0)
end

local function Connection()
    return network and network:GetServerConnection()
end

local function ApplyBackpackPatch(text)
    local patch = Decode(text, {})
    local InventorySystem = require("systems.InventorySystem")
    local manager = InventorySystem.GetManager()
    if not manager then return false end
    for _, change in ipairs(patch) do
        local slot = tonumber(change.slot)
        if slot then
            manager:SetInventoryItem(slot, change.clear and nil or change.item)
        end
    end
    return true
end

function M.ApplyBackpackPatch(text)
    return ApplyBackpackPatch(text)
end

local function ApplyMapSnapshot(text)
    local snapshot = Decode(text, nil)
    if type(snapshot) ~= "table" then return false end
    local InventorySystem = require("systems.InventorySystem")
    local manager = InventorySystem.GetManager()
    if not manager or not manager.GetInventoryItem or not manager.SetInventoryItem then
        return false
    end

    local validated = {}
    local occupied = {}
    for _, entry in ipairs(snapshot) do
        local slot = tonumber(entry and entry.slot)
        local item = entry and entry.item
        if not slot or slot < 1 or slot > GameConfig.BACKPACK_SIZE
            or occupied[slot]
            or type(item) ~= "table"
            or item.category ~= "consumable"
            or item.consumableId ~= Config.MAP_ITEM_ID then
            return false
        end
        occupied[slot] = true
        validated[#validated + 1] = { slot = slot, item = item }
    end

    for slot = 1, GameConfig.BACKPACK_SIZE do
        local item = manager:GetInventoryItem(slot)
        if item and item.category == "consumable"
            and item.consumableId == Config.MAP_ITEM_ID then
            manager:SetInventoryItem(slot, nil)
        end
    end
    for _, entry in ipairs(validated) do
        manager:SetInventoryItem(entry.slot, entry.item)
    end
    return true
end

local function ApplyPlayerPatch(text)
    local patch = Decode(text, {})
    local player = GameState.player
    if not player then return false end
    if patch.lingYun ~= nil then player.lingYun = patch.lingYun end
    if patch.gold ~= nil then player.gold = patch.gold end
    if patch.exp ~= nil then player.exp = patch.exp end
    return true
end

local function ApplyCosmeticsPatch(text)
    local patch = Decode(text, {})
    if not patch.skinId then return true end

    GameState.accountCosmetics = GameState.accountCosmetics or {}
    local cosmetics = GameState.accountCosmetics
    cosmetics.petAppearances = cosmetics.petAppearances or {}
    cosmetics.petAppearances[patch.skinId] = cosmetics.petAppearances[patch.skinId]
        or { unlocked = true }
    cosmetics.petAppearances[patch.skinId].unlocked = true
    cosmetics.version = math.max(tonumber(cosmetics.version) or 1, tonumber(patch.version) or 1)

    if GameState.player and GameState.player.InvalidateStatsCache then
        GameState.player:InvalidateStatsCache()
    end
    if GameState.pet then GameState.pet._statsDirty = true end
    return true
end

local function ApplyImmortalBodiesPatch(text)
    local patch = Decode(text, {})
    if not next(patch) then return true end
    local ImmortalBodySystem = require("systems.ImmortalBodySystem")
    ImmortalBodySystem.DeserializeAccount(patch)
    if GameState.player and GameState.player.InvalidateStatsCache then
        GameState.player:InvalidateStatsCache()
    end
    return true
end

local function ApplyAccountPatches(response)
    ApplyCosmeticsPatch(response.cosmeticsPatch or "{}")
    ApplyImmortalBodiesPatch(response.immortalBodiesPatch or "{}")
end

local function ResetActorAt(x, y)
    local player = GameState.player
    if player then
        player.x, player.y = x, y
        player.lastMoveX, player.lastMoveY = x, y
        player.stuckTimer = 0
        player.dx, player.dy = 0, 0
        player.moving = false
        player.target = nil
        player:SetMoveDirection(0, 0)
    end

    if GameState.pet and player and gameMap_ then
        local px, py = GameState.pet:FindSafeSpot(x + 0.5, y, gameMap_)
        GameState.pet.x, GameState.pet.y = px, py
        GameState.pet.target = nil
        GameState.pet.state = "follow"
    end

    if camera_ then
        camera_.x, camera_.y = x, y
    end
end

local function EnterWorld(active)
    if not active or not gameMap_ then return false end
    if not mapSnapshotReady_ then
        EventBus.Emit("TreasureMap_Error", { reason = "藏宝图背包状态尚未同步，请稍候重试" })
        return false
    end
    local island = Config.ISLAND_BY_ID[active.islandId]
    if not island then return false end
    if (GameState.currentChapter or 1) ~= Config.ENTRY.chapter then
        EventBus.Emit("TreasureMap_Error", { reason = "请先返回第四章龟背岛继续寻宝" })
        return false
    end

    GameState.currentChapter = Config.ENTRY.chapter
    GameState.currentZone = gameMap_:GetZoneAt(island.spawn.x, island.spawn.y)
    GameState.worldMode = "treasure_map"
    ResetActorAt(island.spawn.x, island.spawn.y)
    require("world.ZoneManager").Reset()

    teleportFxTimer_ = Config.TELEPORT_FX_DURATION
    teleportFxKind_ = "enter"
    checkpointPending_ = true
    checkpointRetry_ = 0
    EventBus.Emit("TreasureMap_WorldEntered", active)
    return true
end

local function RestoreWorld()
    if not gameMap_ then return false end
    channel_ = nil
    checkpointPending_ = false
    checkpointRetry_ = 0
    mapSnapshotReady_ = false
    GameState.currentChapter = Config.RETURN_POINT.chapter
    GameState.currentZone = Config.ENTRY.zone
    GameState.worldMode = nil
    ResetActorAt(Config.RETURN_POINT.x, Config.RETURN_POINT.y)
    require("world.ZoneManager").Reset()

    teleportFxTimer_ = Config.TELEPORT_FX_DURATION
    teleportFxKind_ = "return"
    EventBus.Emit("TreasureMap_WorldExited")
    return true
end

function M.SetGameRefs(gameMap, camera)
    gameMap_, camera_ = gameMap, camera
end

function M.IsActive()
    return GameState.worldMode == "treasure_map"
end

function M.IsUsePending()
    return pendingUse_
end

function M.CanSaveOnIsland()
    if not M.IsActive() then return true end
    return not pendingUse_
        and not pendingOpen_
        and not pendingExit_
        and channel_ == nil
        and not awaitingResult_
        and mapSnapshotReady_
        and not (M.state.session and not M.state.active)
end

function M.ContinueActive()
    return EnterWorld(M.state.active)
end

function M.IsChanneling()
    return channel_ ~= nil
end

---@return number|nil progress
---@return string|nil chestId
function M.GetChannelProgress()
    if not channel_ or not M.state.active then return nil, nil end
    return math.min(channel_.elapsed / channel_.minDurationMs, 1), M.state.active.chestId
end

---@return number timer
---@return string|nil kind
---@return number duration
function M.GetTeleportFx()
    return teleportFxTimer_, teleportFxKind_, Config.TELEPORT_FX_DURATION
end

function M.QueryState()
    local conn = Connection()
    if not conn then return false end
    conn:SendRemoteEvent(SaveProtocol.C2S_TreasureMap_QueryState, true, VariantMap())
    return true
end

local function SendUseRequest(conn, requestId, mode)
    local data = VariantMap()
    data["requestId"] = Variant(requestId)
    data["entryId"] = Variant(Config.ENTRY.id)
    data["mode"] = Variant(mode or "entry")
    conn:SendRemoteEvent(SaveProtocol.C2S_TreasureMap_Use, true, data)
end

local function ClearPendingUse()
    pendingUse_ = false
    pendingUseRequestId_ = nil
    pendingUseMode_ = nil
    pendingUseStage_ = nil
    pendingUseWait_ = 0
end

local function FailPendingUse(reason)
    ClearPendingUse()
    EventBus.Emit("TreasureMap_Error", { reason = reason })
end

local function IsInEntryChapter()
    return (GameState.currentChapter or 1) == Config.ENTRY.chapter
end

local function BeginUseRequest(requestId)
    if not pendingUse_ or pendingUseRequestId_ ~= requestId then return false end
    if not IsInEntryChapter() then
        FailPendingUse("藏宝图只能在第四章使用")
        return false
    end
    local conn = Connection()
    if not conn then
        FailPendingUse("连接已断开，无法前往寻宝")
        return false
    end
    pendingUseStage_ = "request"
    pendingUseWait_ = 10
    SendUseRequest(conn, pendingUseRequestId_, pendingUseMode_)
    return true
end

local function BeginChapterCheckpoint(requestId)
    if not pendingUse_ or pendingUseRequestId_ ~= requestId then return false end
    if not IsInEntryChapter() then
        FailPendingUse("藏宝图只能在第四章使用")
        return false
    end

    local SaveSystem = require("systems.SaveSystem")
    if SaveSystem.saving then
        pendingUseStage_ = "wait_save"
        pendingUseWait_ = (SaveSystem.SAVE_RESPONSE_TIMEOUT or 35) + 5
        return true
    end

    pendingUseStage_ = "checkpoint"
    pendingUseWait_ = (SaveSystem.SAVE_RESPONSE_TIMEOUT or 35) + 5
    SaveSystem.Save(function(ok, reason)
        if not pendingUse_ or pendingUseRequestId_ ~= requestId
            or pendingUseStage_ ~= "checkpoint" then
            return
        end
        if ok then
            BeginUseRequest(requestId)
        elseif reason == "already_saving" then
            pendingUseStage_ = "wait_save"
            pendingUseWait_ = (SaveSystem.SAVE_RESPONSE_TIMEOUT or 35) + 5
        else
            FailPendingUse("第四章状态保存失败，藏宝图未使用，请稍后重试")
        end
    end)
    return pendingUse_
end

function M.RequestUse(mode)
    if pendingUse_ then return false end
    if not IsInEntryChapter() then
        EventBus.Emit("TreasureMap_Error", { reason = "藏宝图只能在第四章使用" })
        return false
    end
    if not Connection() then return false end

    pendingUse_ = true
    pendingUseRequestId_ = "tm-client-" .. tostring(os.time()) .. "-"
        .. tostring(math.random(100000, 999999))
    pendingUseMode_ = mode or "entry"
    pendingUseStage_ = "checkpoint"
    pendingUseWait_ = 0
    return BeginChapterCheckpoint(pendingUseRequestId_)
end

function M.RequestStartOpen(chestId)
    if pendingOpen_ or channel_ or not M.state.active then return false end
    local SaveSystem = require("systems.SaveSystem")
    if checkpointPending_ or SaveSystem.saving then
        EventBus.Emit("TreasureMap_Error", { reason = "正在保存寻宝落点，请稍候开启宝箱" })
        return false
    end
    local active = M.state.active
    if active.chestId ~= chestId then
        EventBus.Emit("TreasureMap_Error", { reason = "这不是藏宝图指向的宝藏" })
        return false
    end
    local conn = Connection()
    if not conn then return false end
    local data = VariantMap()
    data["runId"] = Variant(active.runId)
    data["islandId"] = Variant(active.islandId)
    data["chestId"] = Variant(active.chestId)
    pendingOpen_ = true
    pendingOpenWait_ = 10
    conn:SendRemoteEvent(SaveProtocol.C2S_TreasureMap_StartOpen, true, data)
    return true
end

function M.CancelOpen(reason)
    if not channel_ then return end
    channel_ = nil
    local conn = Connection()
    if conn then
        conn:SendRemoteEvent(SaveProtocol.C2S_TreasureMap_CancelOpen, true, VariantMap())
    end
    if reason then EventBus.Emit("TreasureMap_Error", { reason = reason }) end
end

function M.RequestAbandon()
    if pendingExit_ then return false end
    if pendingOpen_ or channel_ or awaitingResult_ then
        EventBus.Emit("TreasureMap_Error", { reason = "宝箱交互处理中，暂时无法离开" })
        return false
    end
    if require("systems.SaveSystem").saving then
        EventBus.Emit("TreasureMap_Error", { reason = "正在保存寻宝进度，请稍候离开" })
        return false
    end
    local conn = Connection()
    if not conn then return false end
    pendingExit_ = true
    pendingExitKind_ = "abandon"
    exitWait_ = 10
    local data = VariantMap()
    data["runId"] = Variant(M.state.active and M.state.active.runId or "")
    data["sessionId"] = Variant(M.state.session and M.state.session.sessionId or "")
    conn:SendRemoteEvent(SaveProtocol.C2S_TreasureMap_Abandon, true, data)
    return true
end

function M.RequestExit()
    if pendingExit_ then return false end
    if pendingOpen_ or channel_ or awaitingResult_ then
        EventBus.Emit("TreasureMap_Error", { reason = "宝箱交互处理中，暂时无法离开" })
        return false
    end
    if require("systems.SaveSystem").saving then
        EventBus.Emit("TreasureMap_Error", { reason = "正在保存寻宝进度，请稍候离开" })
        return false
    end
    local conn = Connection()
    if not conn then return false end
    pendingExit_ = true
    pendingExitKind_ = "exit"
    exitWait_ = 10
    local data = VariantMap()
    data["runId"] = Variant(M.state.active and M.state.active.runId or "")
    data["sessionId"] = Variant(M.state.session and M.state.session.sessionId or "")
    conn:SendRemoteEvent(SaveProtocol.C2S_TreasureMap_Exit, true, data)
    return true
end

function M.Update(dt)
    if teleportFxTimer_ > 0 then
        teleportFxTimer_ = math.max(0, teleportFxTimer_ - dt)
        if teleportFxTimer_ == 0 then teleportFxKind_ = nil end
    end

    if pendingUse_ then
        if pendingUseStage_ == "wait_save" then
            local SaveSystem = require("systems.SaveSystem")
            pendingUseWait_ = pendingUseWait_ - dt
            if not SaveSystem.saving then
                BeginChapterCheckpoint(pendingUseRequestId_)
            elseif pendingUseWait_ <= 0 then
                FailPendingUse("等待角色存档超时，藏宝图未使用，请稍后重试")
            end
        elseif pendingUseStage_ == "checkpoint" then
            pendingUseWait_ = pendingUseWait_ - dt
            if pendingUseWait_ <= 0 then
                FailPendingUse("第四章状态保存超时，藏宝图未使用，请稍后重试")
            end
        elseif pendingUseStage_ == "request" and pendingUseWait_ > 0 then
            pendingUseWait_ = pendingUseWait_ - dt
            if pendingUseWait_ <= 0 then
                local conn = Connection()
                if conn and pendingUseRequestId_ then
                    -- Reuse the same request id. A delayed original request and
                    -- this retry can only resolve to one authoritative run.
                    SendUseRequest(conn, pendingUseRequestId_, pendingUseMode_)
                    M.QueryState()
                    pendingUseWait_ = 5
                else
                    pendingUseWait_ = 1
                end
            end
        end
    end

    if pendingOpen_ and pendingOpenWait_ > 0 then
        pendingOpenWait_ = pendingOpenWait_ - dt
        if pendingOpenWait_ <= 0 then
            pendingOpen_ = false
            pendingOpenWait_ = 0
            M.QueryState()
            EventBus.Emit("TreasureMap_Error", { reason = "宝箱授权超时，请重新开启" })
        end
    end

    if awaitingResult_ and resultWait_ > 0 then
        resultWait_ = resultWait_ - dt
        if resultWait_ <= 0 then
            if M.QueryState() then
                resultWait_ = 5
            else
                resultWait_ = 1
            end
        end
    end

    if pendingExit_ and exitWait_ > 0 then
        exitWait_ = exitWait_ - dt
        if exitWait_ <= 0 then
            if M.QueryState() then
                exitWait_ = 5
            else
                exitWait_ = 1
            end
        end
    end

    if checkpointPending_ and M.IsActive() then
        checkpointRetry_ = math.max(0, checkpointRetry_ - dt)
        local SaveSystem = require("systems.SaveSystem")
        if SaveSystem.saving then
            -- Any full save started on the island already captures this
            -- checkpoint; opening remains blocked until that save resolves.
            checkpointPending_ = false
        elseif checkpointRetry_ <= 0 and M.CanSaveOnIsland() then
            if SaveSystem.loaded and SaveSystem.activeSlot and not SaveSystem.saving then
                checkpointPending_ = false
                SaveSystem.Save(function(ok, reason)
                    if not ok and M.IsActive() then
                        checkpointPending_ = true
                        checkpointRetry_ = reason == "already_saving" and 1 or 3
                        print("[TreasureMap] Island checkpoint retry: " .. tostring(reason))
                    end
                end)
            end
        end
    end

    if not channel_ then return end

    local active = M.state.active
    local player = GameState.player
    if not active or not player or not player.alive then
        M.CancelOpen("开启已中断")
        return
    end
    local island = Config.ISLAND_BY_ID[active.islandId]
    local chest = island and island.chest
    if not chest then M.CancelOpen("宝箱配置异常"); return end
    local dx, dy = player.x - chest.x, player.y - chest.y
    if dx * dx + dy * dy > 2.25 then
        M.CancelOpen("离开宝箱范围，开启已中断")
        return
    end

    channel_.elapsed = channel_.elapsed + dt * 1000
    EventBus.Emit("TreasureMap_ChannelProgress",
        math.min(channel_.elapsed / channel_.minDurationMs, 1))
    if channel_.elapsed < channel_.minDurationMs then return end

    local conn = Connection()
    if not conn then M.CancelOpen("连接已断开，开启已中断"); return end
    local data = VariantMap()
    data["runId"] = Variant(active.runId)
    data["chestId"] = Variant(active.chestId)
    data["openToken"] = Variant(channel_.openToken)
    channel_ = nil
    awaitingResult_ = true
    awaitingRunId_ = active.runId
    resultWait_ = 10
    conn:SendRemoteEvent(SaveProtocol.C2S_TreasureMap_CompleteOpen, true, data)
end

function M._HandleState(eventData)
    if not ReadBool(eventData, "ok", false) then
        EventBus.Emit("TreasureMap_Error", { reason = ReadString(eventData, "reason", "读取失败") })
        return
    end
    M.state = Decode(ReadString(eventData, "stateJson"), M.state)
    mapSnapshotReady_ = ApplyMapSnapshot(
        ReadString(eventData, "mapSnapshotJson", ""))
    awaitingResult_ = false
    awaitingRunId_ = nil
    resultWait_ = 0
    pendingOpen_ = false
    pendingOpenWait_ = 0
    pendingExit_ = false
    pendingExitKind_ = nil
    exitWait_ = 0
    if M.state.active or M.state.session then
        ClearPendingUse()
    end
    EventBus.Emit("TreasureMap_StateChanged", M.state)
    if (M.state.active or M.state.session) and not mapSnapshotReady_ then
        checkpointPending_ = false
        EventBus.Emit("TreasureMap_Error", {
            reason = "藏宝图背包同步失败，已停止保存与开箱，请重新登录后重试",
        })
        return
    end
    if M.state.active and not M.IsActive() then
        if EnterWorld(M.state.active) then
            EventBus.Emit("TreasureMap_UseSuccess", M.state.active)
        else
            EventBus.Emit("TreasureMap_ResumeAvailable", M.state.active)
        end
    elseif not M.state.session and M.IsActive() then
        RestoreWorld()
    end
    local recovery = Decode(ReadString(eventData, "recoveryJson"), nil)
    if recovery and recovery.runId ~= lastPresentedRunId_ then
        ApplyBackpackPatch(recovery.backpackPatch or "[]")
        ApplyPlayerPatch(recovery.playerPatch or "{}")
        ApplyAccountPatches(recovery)
        lastPresentedRunId_ = recovery.runId
        EventBus.Emit("TreasureMap_OpenSuccess", {
            reward = Decode(recovery.rewardJson or "{}", {}),
            state = M.state,
            replayed = true,
        })
    end
end

function M._HandleUseResult(eventData)
    local requestId = ReadString(eventData, "requestId")
    if not pendingUse_ or requestId == "" or requestId ~= pendingUseRequestId_ then
        M.QueryState()
        return
    end
    ClearPendingUse()
    if not ReadBool(eventData, "ok", false) then
        EventBus.Emit("TreasureMap_Error", { reason = ReadString(eventData, "reason", "展开失败") })
        return
    end
    M.state = Decode(ReadString(eventData, "stateJson"), M.state)
    local patchOk = ApplyBackpackPatch(ReadString(eventData, "backpackPatch", "[]"))
    local snapshotOk = ApplyMapSnapshot(ReadString(eventData, "mapSnapshotJson", ""))
    mapSnapshotReady_ = patchOk and snapshotOk
    if not mapSnapshotReady_ then
        EventBus.Emit("TreasureMap_Error", {
            reason = "本地背包同步失败，已停止传送与保存，请重新登录",
        })
        M.QueryState()
        return
    end
    if EnterWorld(M.state.active) then
        EventBus.Emit("TreasureMap_UseSuccess", M.state.active)
    end
end

function M._HandleStartResult(eventData)
    if not pendingOpen_ then return end
    pendingOpen_ = false
    pendingOpenWait_ = 0
    if not ReadBool(eventData, "ok", false) then
        EventBus.Emit("TreasureMap_Error", { reason = ReadString(eventData, "reason", "无法开启") })
        return
    end
    channel_ = {
        openToken = ReadString(eventData, "openToken"),
        minDurationMs = ReadInt(eventData, "minDurationMs", Config.OPEN_DURATION_MS),
        elapsed = 0,
    }
end

function M._HandleOpenResult(eventData)
    local ok = ReadBool(eventData, "ok", false)
    local runId = ReadString(eventData, "runId")
    if not awaitingResult_
        or (ok and (runId == "" or runId ~= awaitingRunId_)) then
        M.QueryState()
        return
    end
    awaitingResult_ = false
    awaitingRunId_ = nil
    resultWait_ = 0
    if not ok then
        EventBus.Emit("TreasureMap_Error", { reason = ReadString(eventData, "reason", "开箱失败") })
        M.QueryState()
        return
    end
    ApplyBackpackPatch(ReadString(eventData, "backpackPatch", "[]"))
    ApplyPlayerPatch(ReadString(eventData, "playerPatch", "{}"))
    ApplyAccountPatches({
        cosmeticsPatch = ReadString(eventData, "cosmeticsPatch", "{}"),
        immortalBodiesPatch = ReadString(eventData, "immortalBodiesPatch", "{}"),
    })
    M.state = Decode(ReadString(eventData, "stateJson"), M.state)
    lastPresentedRunId_ = ReadString(eventData, "runId")
    EventBus.Emit("TreasureMap_OpenSuccess", {
        reward = Decode(ReadString(eventData, "rewardJson", "{}"), {}),
        state = M.state,
        replayed = ReadBool(eventData, "replayed", false),
    })
end

function M._HandleAbandonResult(eventData)
    if not pendingExit_ or pendingExitKind_ ~= "abandon" then
        M.QueryState()
        return
    end
    pendingExit_ = false
    pendingExitKind_ = nil
    exitWait_ = 0
    if not ReadBool(eventData, "ok", false) then
        EventBus.Emit("TreasureMap_Error", { reason = ReadString(eventData, "reason", "放弃失败") })
        return
    end
    M.state = Decode(ReadString(eventData, "stateJson"), M.state)
    RestoreWorld()
    EventBus.Emit("TreasureMap_Abandoned")
end

function M._HandleExitResult(eventData)
    if not pendingExit_ or pendingExitKind_ ~= "exit" then
        M.QueryState()
        return
    end
    pendingExit_ = false
    pendingExitKind_ = nil
    exitWait_ = 0
    if not ReadBool(eventData, "ok", false) then
        EventBus.Emit("TreasureMap_Error", { reason = ReadString(eventData, "reason", "归航失败") })
        return
    end
    M.state = Decode(ReadString(eventData, "stateJson"), M.state)
    RestoreWorld()
end

function M.Init()
    if initialized_ then return end
    initialized_ = true
    SubscribeToEvent(SaveProtocol.S2C_TreasureMap_State, "TreasureMap_HandleState")
    SubscribeToEvent(SaveProtocol.S2C_TreasureMap_UseResult, "TreasureMap_HandleUseResult")
    SubscribeToEvent(SaveProtocol.S2C_TreasureMap_StartOpenResult, "TreasureMap_HandleStartResult")
    SubscribeToEvent(SaveProtocol.S2C_TreasureMap_OpenResult, "TreasureMap_HandleOpenResult")
    SubscribeToEvent(SaveProtocol.S2C_TreasureMap_AbandonResult, "TreasureMap_HandleAbandonResult")
    SubscribeToEvent(SaveProtocol.S2C_TreasureMap_ExitResult, "TreasureMap_HandleExitResult")
end

function M.Reset()
    channel_ = nil
    pendingOpen_ = false
    pendingUse_ = false
    pendingUseRequestId_ = nil
    pendingUseMode_ = nil
    pendingUseStage_ = nil
    pendingUseWait_ = 0
    pendingOpenWait_ = 0
    pendingExit_ = false
    pendingExitKind_ = nil
    awaitingResult_ = false
    awaitingRunId_ = nil
    resultWait_ = 0
    exitWait_ = 0
    lastPresentedRunId_ = nil
    teleportFxTimer_ = 0
    teleportFxKind_ = nil
    checkpointPending_ = false
    checkpointRetry_ = 0
    mapSnapshotReady_ = false
    if M.IsActive() then RestoreWorld() end
    M.state = { version = 1, revision = 0 }
end

function TreasureMap_HandleState(_, eventData) M._HandleState(eventData) end
function TreasureMap_HandleUseResult(_, eventData) M._HandleUseResult(eventData) end
function TreasureMap_HandleStartResult(_, eventData) M._HandleStartResult(eventData) end
function TreasureMap_HandleOpenResult(_, eventData) M._HandleOpenResult(eventData) end
function TreasureMap_HandleAbandonResult(_, eventData) M._HandleAbandonResult(eventData) end
function TreasureMap_HandleExitResult(_, eventData) M._HandleExitResult(eventData) end

return M
