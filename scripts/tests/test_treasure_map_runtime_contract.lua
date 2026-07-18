package.path = package.path .. ";scripts/?.lua"

local SaveProtocol = require("network.SaveProtocol")
local Handler = require("network.TreasureMapHandler")

local passed, failed, total = 0, 0, 0
local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  [PASS] " .. name)
    else
        failed = failed + 1
        print("  [FAIL] " .. name .. ": " .. tostring(err))
    end
end
local function assertTrue(value, message)
    if not value then error(message or "expected true") end
end
local function Read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end

test("handler exports every transaction endpoint", function()
    for _, name in ipairs({
        "HandleQueryState", "HandleUse", "HandleContinue", "HandleStartOpen",
        "HandleCompleteOpen", "HandleCancelOpen", "HandleAbandon", "HandleExit",
        "GMGrantMaps10", "CleanupConnection",
    }) do
        assertTrue(type(Handler[name]) == "function", name)
    end
end)

test("all treasure map protocol events are registered", function()
    local registered = {}
    for _, eventName in ipairs(SaveProtocol.ALL_EVENTS) do registered[eventName] = true end
    for _, key in ipairs({
        "C2S_TreasureMap_QueryState", "C2S_TreasureMap_Use",
        "C2S_TreasureMap_Continue", "C2S_TreasureMap_StartOpen",
        "C2S_TreasureMap_CompleteOpen", "C2S_TreasureMap_CancelOpen",
        "C2S_TreasureMap_Abandon", "C2S_TreasureMap_Exit",
        "S2C_TreasureMap_State", "S2C_TreasureMap_UseResult",
        "S2C_TreasureMap_StartOpenResult", "S2C_TreasureMap_OpenResult",
        "S2C_TreasureMap_AbandonResult", "S2C_TreasureMap_ExitResult",
    }) do
        assertTrue(registered[SaveProtocol[key]], key)
    end
end)

test("complete-open path never rerolls and client never grants rewards locally", function()
    local handlerSource = Read("scripts/network/TreasureMapHandler.lua")
    local completeStart = assert(handlerSource:find("local function CompleteReward", 1, true))
    local completeEnd = assert(handlerSource:find("function M.HandleCompleteOpen", completeStart, true))
    local completeSource = handlerSource:sub(completeStart, completeEnd - 1)
    assertTrue(not completeSource:find("RollReward", 1, true))

    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    assertTrue(not clientSource:find("InventorySystem.AddConsumable", 1, true))
    assertTrue(clientSource:find("ApplyBackpackPatch", 1, true) ~= nil)
end)

test("normal save cannot overwrite account rewards and sidecar stays outside DTO", function()
    local saveSource = Read("scripts/network/SaveWriteService.lua")
    assertTrue(not saveSource:find(':Set("account_cosmetics"', 1, true))
    assertTrue(not saveSource:find(':Set("account_immortal_bodies"', 1, true))
    local dtoSource = Read("scripts/systems/save/SaveDTO.lua")
    assertTrue(not dtoSource:find("treasureMapState", 1, true))
    assertTrue(not dtoSource:find("treasure_map_state_", 1, true))
end)

test("stale main saves cannot cross treasure-session boundaries", function()
    local SaveWriteService = require("network.SaveWriteService")
    local same = SaveWriteService._ValidateTreasureSession(
        { player = { treasureSessionId = "session-a" } },
        { player = { treasureSessionId = "session-a" } })
    assertTrue(same)

    local staleBeforeEntry = SaveWriteService._ValidateTreasureSession(
        { player = { treasureSessionId = "session-a" } },
        { player = {} })
    assertTrue(not staleBeforeEntry)

    local staleAfterExit = SaveWriteService._ValidateTreasureSession(
        { player = {} },
        { player = { treasureSessionId = "session-a" } })
    assertTrue(not staleAfterExit)

    local normalWorld = SaveWriteService._ValidateTreasureSession(
        { player = {} },
        { player = {} })
    assertTrue(normalWorld)

    local staleAfterRoundTrip = SaveWriteService._ValidateTreasureSession(
        { player = { treasureRevision = 4 } },
        { player = { treasureRevision = 2 } })
    assertTrue(not staleAfterRoundTrip,
        "pre-entry empty-session save must not pass after departure returns to empty session")

    local currentAfterRoundTrip = SaveWriteService._ValidateTreasureSession(
        { player = { treasureRevision = 4 } },
        { player = { treasureRevision = 4 } })
    assertTrue(currentAfterRoundTrip)
end)

test("body reward uses account service and client applies body patch", function()
    local handlerSource = Read("scripts/network/TreasureMapHandler.lua")
    assertTrue(handlerSource:find('require("network.AccountImmortalBodiesService")', 1, true) ~= nil)
    assertTrue(handlerSource:find("PrepareBodyGrant", 1, true) ~= nil)
    assertTrue(handlerSource:find("immortalBodiesPatch", 1, true) ~= nil)
    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    assertTrue(clientSource:find("ApplyImmortalBodiesPatch", 1, true) ~= nil)
    assertTrue(clientSource:find("DeserializeAccount", 1, true) ~= nil)
end)

test("first tribulation base body also uses server-owned account service", function()
    local saveSource = Read("scripts/network/SaveWriteService.lua")
    assertTrue(saveSource:find('require("network.AccountImmortalBodiesService")', 1, true) ~= nil)
    assertTrue(saveSource:find('"immortal_body_1"', 1, true) ~= nil)
    assertTrue(saveSource:find('"first_tribulation"', 1, true) ~= nil)
    assertTrue(saveSource:find("PrepareBodyGrant", 1, true) ~= nil)
end)

test("island saves are allowed only outside treasure transactions", function()
    local saveSource = Read("scripts/systems/save/SavePersistence.lua")
    assertTrue(saveSource:find('GameState.worldMode == "treasure_map"', 1, true) ~= nil)
    assertTrue(saveSource:find("TreasureMapSystem.CanSaveOnIsland()", 1, true) ~= nil)
    assertTrue(saveSource:find("treasure_map_busy", 1, true) ~= nil)
    assertTrue(not saveSource:find("treasure_map_server_transaction", 1, true))

    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    assertTrue(clientSource:find("function M.CanSaveOnIsland()", 1, true) ~= nil)
    assertTrue(clientSource:find("awaitingResult_", 1, true) ~= nil)
    assertTrue(clientSource:find("SaveSystem.saving", 1, true) ~= nil)
    assertTrue(clientSource:find("checkpointPending_", 1, true) ~= nil)
    assertTrue(clientSource:find("mapSnapshotReady_", 1, true) ~= nil)
    assertTrue(clientSource:find("ApplyMapSnapshot", 1, true) ~= nil)

    local serializerSource = Read("scripts/systems/save/SaveSerializer.lua")
    assertTrue(serializerSource:find("treasureSessionId", 1, true) ~= nil)
    assertTrue(serializerSource:find("treasureRevision", 1, true) ~= nil)
    assertTrue(serializerSource:find("TreasureMapSystem.state", 1, true) ~= nil)

    local writeSource = Read("scripts/network/SaveWriteService.lua")
    assertTrue(writeSource:find("_ValidateTreasureSession", 1, true) ~= nil)
    assertTrue(writeSource:find("treasure_state_changed", 1, true) ~= nil)

    local mainSource = Read("scripts/main.lua")
    assertTrue(mainSource:find("not TreasureMapSystem.IsActive()", 1, true) ~= nil)
end)

test("lost use responses cannot restore a consumed treasure map", function()
    local handlerSource = Read("scripts/network/TreasureMapHandler.lua")
    assertTrue(handlerSource:find("MapSnapshotJson", 1, true) ~= nil)
    assertTrue(handlerSource:find("mapSnapshotJson = MapSnapshotJson(saveData.backpack)",
        1, true) ~= nil)
    assertTrue(handlerSource:find("mapSnapshotJson = MapSnapshotJson(nextSave.backpack)",
        1, true) ~= nil)

    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    assertTrue(clientSource:find("ApplyMapSnapshot(", 1, true) ~= nil)
    assertTrue(clientSource:find("and mapSnapshotReady_", 1, true) ~= nil)
    assertTrue(clientSource:find("patchOk and snapshotOk", 1, true) ~= nil)
end)

test("ambiguous use retries are correlated and fail closed", function()
    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    assertTrue(clientSource:find("pendingUseRequestId_", 1, true) ~= nil)
    assertTrue(clientSource:find(
        "SendUseRequest(conn, pendingUseRequestId_, pendingUseMode_)", 1, true) ~= nil)
    assertTrue(clientSource:find(
        "requestId ~= pendingUseRequestId_", 1, true) ~= nil)
    assertTrue(clientSource:find("pendingExitKind_", 1, true) ~= nil)
    assertTrue(clientSource:find("awaitingRunId_", 1, true) ~= nil)

    local handlerSource = Read("scripts/network/TreasureMapHandler.lua")
    assertTrue(handlerSource:find("ActiveBindingIsValid", 1, true) ~= nil)
    assertTrue(handlerSource:find("requestHistory", 1, true) ~= nil)
    assertTrue(handlerSource:find("RememberRequest", 1, true) ~= nil)
    local _, rollCalls = handlerSource:gsub("Config.RollReward", "")
    assertTrue(rollCalls == 1, "reward roll must exist only in the atomic map-use transaction")

    assertTrue(clientSource:find('data["runId"]', 1, true) ~= nil)
    assertTrue(clientSource:find('data["sessionId"]', 1, true) ~= nil)
end)

test("login query restores the active island after UI listeners are ready", function()
    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    local stateHandler = assert(clientSource:find("function M._HandleState", 1, true))
    local useHandler = assert(clientSource:find("function M._HandleUseResult", stateHandler, true))
    local stateSource = clientSource:sub(stateHandler, useHandler - 1)
    assertTrue(stateSource:find("EnterWorld(M.state.active)", 1, true) ~= nil)

    local mainSource = Read("scripts/main.lua")
    local uiCreate = assert(mainSource:find("TreasureMapUI.Create(overlay)", 1, true))
    local queryState = assert(mainSource:find("TreasureMapSystem.QueryState()", uiCreate, true))
    assertTrue(queryState > uiCreate)
end)

test("treasure travel stays on the real chapter-four map", function()
    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    assertTrue(not clientSource:find("TreasureSeaZoneData", 1, true))
    assertTrue(not clientSource:find("ActivateZoneData", 1, true))
    assertTrue(not clientSource:find("gameMap_.tiles =", 1, true))
    assertTrue(clientSource:find("GetZoneAt(island.spawn.x, island.spawn.y)", 1, true) ~= nil)

    local gameMapSource = Read("scripts/world/GameMap.lua")
    assertTrue(not gameMapSource:find("world.mapgen.TreasureSea", 1, true))
    assertTrue(not gameMapSource:find("BuildTreasureSea", 1, true))
end)

test("map use is chapter-gated, checkpointed and has no physical entry object", function()
    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    assertTrue(clientSource:find("local function IsInEntryChapter()", 1, true) ~= nil)
    assertTrue(clientSource:find("local function BeginChapterCheckpoint", 1, true) ~= nil)
    assertTrue(clientSource:find("SaveSystem.Save(function(ok, reason)", 1, true) ~= nil)
    assertTrue(clientSource:find('pendingUseStage_ = "wait_save"', 1, true) ~= nil)
    assertTrue(clientSource:find("藏宝图只能在第四章使用", 1, true) ~= nil)

    local havenSource = Read("scripts/config/zones/chapter4/haven.lua")
    assertTrue(not havenSource:find("ch4_treasure_map_entry", 1, true))
    assertTrue(not havenSource:find("treasure_map_entry", 1, true))

    local dialogSource = Read("scripts/ui/NPCDialog.lua")
    assertTrue(not dialogSource:find("treasure_map_entry = function", 1, true))

    local mainSource = Read("scripts/main.lua")
    assertTrue(mainSource:find("TreasureMapSystem.IsUsePending()", 1, true) ~= nil)
end)

test("chest interaction starts channel directly with no second modal", function()
    local dialogSource = Read("scripts/ui/NPCDialog.lua")
    assertTrue(dialogSource:find("TreasureMapSystem.RequestStartOpen(npc.id)", 1, true) ~= nil)
    assertTrue(not dialogSource:find("TreasureMapUI\").ShowChest", 1, true))

    local uiSource = Read("scripts/ui/TreasureMapUI.lua")
    assertTrue(not uiSource:find("function M.ShowChest", 1, true))
    assertTrue(not uiSource:find("使用下一张", 1, true))
    assertTrue(uiSource:find("ShowProbabilityPreview", 1, true) ~= nil)
    assertTrue(uiSource:find("赤焰天犬、玄冰天犬、樱华天犬", 1, true) ~= nil)
    assertTrue(uiSource:find('"0.4%"', 1, true) ~= nil)
    assertTrue(uiSource:find("PANEL_Z = 1200", 1, true) ~= nil)
    assertTrue(uiSource:find('justifyContent = "center"', 1, true) ~= nil)
    assertTrue(uiSource:find('whiteSpace = "normal"', 1, true) ~= nil)
    assertTrue(uiSource:find("CloseInventoryIfOpen", 1, true) ~= nil)
    assertTrue(uiSource:find("InventoryUI.Hide()", 1, true) ~= nil)
    assertTrue(uiSource:find("前往寻宝", 1, true) ~= nil)
    assertTrue(not uiSource:find("展开藏宝图", 1, true))
    assertTrue(uiSource:find("QuestRewardUI.ShowGrantedBundle", 1, true) ~= nil)
    assertTrue(uiSource:find("TreasureMapSystem.RequestExit()", 1, true) ~= nil)
    assertTrue(not uiSource:find("TreasureMapSystem.RequestExit(false)", 1, true))
    assertTrue(not uiSource:find("TreasureMapSystem.RequestExit(true)", 1, true))
    assertTrue(not uiSource:find("保留藏宝进度并归航", 1, true))

    local rewardSource = Read("scripts/ui/QuestRewardUI.lua")
    assertTrue(rewardSource:find('id = "quest_granted_bundle_panel"', 1, true) ~= nil)
    assertTrue(rewardSource:find('whiteSpace = "normal"', 1, true) ~= nil)
end)

test("server forbids chain use and requires return before the next map", function()
    local handlerSource = Read("scripts/network/TreasureMapHandler.lua")
    assertTrue(not handlerSource:find('mode ~= "chain"', 1, true))
    assertTrue(handlerSource:find("请先确认奖励并归航，再开始下一次寻宝", 1, true) ~= nil)
    assertTrue(handlerSource:find("Config.ENTRY.chapter", 1, true) ~= nil)
    assertTrue(handlerSource:find("Portal departure always ends the expedition", 1, true) ~= nil)
    assertTrue(not handlerSource:find('ReadBool(eventData, "abandon"', 1, true))
end)

test("entry and return teleport effects are wired to player rendering", function()
    local clientSource = Read("scripts/systems/TreasureMapSystem.lua")
    assertTrue(clientSource:find('teleportFxKind_ = "enter"', 1, true) ~= nil)
    assertTrue(clientSource:find('teleportFxKind_ = "return"', 1, true) ~= nil)
    assertTrue(clientSource:find("function M.GetTeleportFx()", 1, true) ~= nil)
    local playerSource = Read("scripts/rendering/entities/player.lua")
    assertTrue(playerSource:find("TreasureMapSystem_.GetTeleportFx()", 1, true) ~= nil)
end)

test("server entry subscribes and cleans up treasure map handler", function()
    local source = Read("scripts/server_main.lua")
    assertTrue(source:find("C2S_TreasureMap_QueryState", 1, true) ~= nil)
    assertTrue(source:find("C2S_TreasureMap_CompleteOpen", 1, true) ~= nil)
    assertTrue(source:find("TreasureMapHandler.CleanupConnection", 1, true) ~= nil)
    assertTrue(source:find("Do not force-release a slot lock on disconnect", 1, true) ~= nil)

    local disconnectStart = assert(source:find("function HandleClientDisconnected", 1, true))
    local disconnectEnd = assert(source:find("function HandleVersionHandshake", disconnectStart, true))
    local disconnectSource = source:sub(disconnectStart, disconnectEnd - 1)
    assertTrue(not disconnectSource:find("ReleaseSlotLock", 1, true),
        "disconnect must not release a lock owned by an in-flight cloud write")
end)

test("GM console routes authoritative treasure map grant and applies patch", function()
    local gmHandler = Read("scripts/network/GMHandler.lua")
    assertTrue(gmHandler:find('"treasure_maps_10"', 1, true) ~= nil)
    assertTrue(gmHandler:find("GMGrantMaps10", 1, true) ~= nil)

    local gmConsole = Read("scripts/ui/GMConsole.lua")
    assertTrue(gmConsole:find("藏宝图 ×10", 1, true) ~= nil)
    assertTrue(gmConsole:find('"treasure_maps_10"', 1, true) ~= nil)
    assertTrue(gmConsole:find("TreasureMapSystem.ApplyBackpackPatch", 1, true) ~= nil)
end)

print(string.format("[test_treasure_map_runtime_contract] passed=%d failed=%d total=%d",
    passed, failed, total))
return { passed = passed, failed = failed, total = total }
