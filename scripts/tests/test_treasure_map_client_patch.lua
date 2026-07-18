-- ============================================================================
-- test_treasure_map_client_patch.lua - client-side authoritative reward patches
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local moduleNames = {
    "core.GameState",
    "core.EventBus",
    "network.SaveProtocol",
    "config.GameConfig",
    "config.TreasureMapConfig",
    "systems.InventorySystem",
    "systems.ImmortalBodySystem",
    "systems.SaveSystem",
    "systems.TreasureMapSystem",
    "world.ZoneManager",
}
local originals = {}
for _, name in ipairs(moduleNames) do
    originals[name] = package.loaded[name]
end
local originalCjson = cjson
local originalNetwork = network
local originalVariant = Variant
local originalVariantMap = VariantMap

local invalidationCount = 0
local saveCount = 0
local zoneResetCount = 0
local lastCheckpointMapCount = nil
local saveAutoComplete = true
local saveNextOk = true
local saveNextReason = nil
local deferredSaveCallback = nil
local actionTrace = {}
local sentEvents = {}
local inventorySlots = {}
local gameState = {
    player = {
        x = 1,
        y = 1,
        alive = true,
        lingYun = 0,
        gold = 0,
        exp = 0,
        SetMoveDirection = function() end,
        InvalidateStatsCache = function()
            invalidationCount = invalidationCount + 1
        end,
    },
    pet = {
        _statsDirty = false,
        FindSafeSpot = function(_, x, y) return x, y end,
    },
    accountCosmetics = {
        version = 2,
        petAppearances = {},
    },
    currentChapter = 4,
    currentZone = "ch4_haven",
    worldMode = nil,
}
local emitted = {}
local bodyPatch = nil
local inventoryWrites = {}

package.loaded["core.GameState"] = gameState
package.loaded["core.EventBus"] = {
    Emit = function(eventName, payload)
        emitted[#emitted + 1] = { name = eventName, payload = payload }
    end,
}
package.loaded["network.SaveProtocol"] = {
    C2S_TreasureMap_QueryState = "C2S_TMQuery",
    C2S_TreasureMap_Use = "C2S_TMUse",
    C2S_TreasureMap_StartOpen = "C2S_TMStart",
    C2S_TreasureMap_CompleteOpen = "C2S_TMComplete",
    C2S_TreasureMap_CancelOpen = "C2S_TMCancel",
    C2S_TreasureMap_Abandon = "C2S_TMAbandon",
    C2S_TreasureMap_Exit = "C2S_TMExit",
}
package.loaded["config.GameConfig"] = {
    BACKPACK_SIZE = 64,
}
package.loaded["config.TreasureMapConfig"] = {
    MAP_ITEM_ID = "treasure_map",
    OPEN_DURATION_MS = 1200,
    TELEPORT_FX_DURATION = 0.5,
    ISLAND_BY_ID = {
        island_restore = {
            islandId = "island_restore",
            spawn = { x = 12, y = 18 },
            chest = { chestId = "chest_restore", x = 11, y = 17 },
        },
    },
    ENTRY = { id = "chapter4_bagua_sea", chapter = 4, zone = "bagua_sea" },
    RETURN_POINT = { chapter = 4, x = 0, y = 0 },
}
package.loaded["systems.InventorySystem"] = {
    GetManager = function()
        return {
            GetInventoryItem = function(_, slot)
                return inventorySlots[slot]
            end,
            SetInventoryItem = function(_, slot, item)
                inventorySlots[slot] = item
                inventoryWrites[slot] = item
            end,
        }
    end,
}
package.loaded["systems.ImmortalBodySystem"] = {
    DeserializeAccount = function(patch)
        bodyPatch = patch
    end,
}
local saveSystemMock = {
    loaded = true,
    activeSlot = 1,
    saving = false,
    SAVE_RESPONSE_TIMEOUT = 35,
}
saveSystemMock.Save = function(callback)
    saveCount = saveCount + 1
    actionTrace[#actionTrace + 1] = "save"
    lastCheckpointMapCount = 0
    for _, item in pairs(inventorySlots) do
        if item and item.category == "consumable"
            and item.consumableId == "treasure_map" then
            lastCheckpointMapCount = lastCheckpointMapCount + (item.count or 1)
        end
    end
    if saveAutoComplete then
        if callback then callback(saveNextOk, saveNextReason) end
    else
        saveSystemMock.saving = true
        deferredSaveCallback = callback
    end
end
package.loaded["systems.SaveSystem"] = saveSystemMock
package.loaded["world.ZoneManager"] = {
    Reset = function()
        zoneResetCount = zoneResetCount + 1
    end,
}
package.loaded["systems.TreasureMapSystem"] = nil

cjson = {
    decode = function(value)
        return value
    end,
}

network = {
    GetServerConnection = function()
        return {
            SendRemoteEvent = function(_, eventName, _, data)
                actionTrace[#actionTrace + 1] = eventName
                sentEvents[#sentEvents + 1] = { eventName = eventName, data = data }
            end,
        }
    end,
}
Variant = function(value) return value end
VariantMap = function() return {} end

local TreasureMapSystem = require("systems.TreasureMapSystem")

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

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual))
    end
end

local function assertTrue(value, message)
    if not value then error(message or "expected true") end
end

local function VariantValue(value)
    return {
        GetString = function() return value end,
        GetBool = function() return value == true end,
        GetInt = function() return tonumber(value) or 0 end,
    }
end

local function Event(fields)
    local result = {}
    for key, value in pairs(fields) do
        result[key] = VariantValue(value)
    end
    return result
end

local gameMap = {
    GetZoneAt = function(_, x, y)
        return "zone_" .. tostring(x) .. "_" .. tostring(y)
    end,
}
local camera = { x = 0, y = 0 }
TreasureMapSystem.SetGameRefs(gameMap, camera)

local function MapSnapshot(count, slot)
    if not count or count <= 0 then return {} end
    return {
        {
            slot = slot or 5,
            item = {
                category = "consumable",
                consumableId = "treasure_map",
                count = count,
            },
        },
    }
end

local function ActiveState(runId)
    return {
        version = 1,
        revision = 10,
        session = {
            sessionId = "session-" .. runId,
            currentIslandId = "island_restore",
        },
        active = {
            runId = runId,
            requestId = "request-" .. runId,
            islandId = "island_restore",
            chestId = "chest_restore",
            rewardType = "lingyun_fruit",
            status = "entered",
        },
    }
end

local function ResetClient()
    TreasureMapSystem.Reset()
    emitted = {}
    sentEvents = {}
    inventorySlots = {}
    inventoryWrites = {}
    saveCount = 0
    lastCheckpointMapCount = nil
    saveAutoComplete = true
    saveNextOk = true
    saveNextReason = nil
    deferredSaveCallback = nil
    actionTrace = {}
    saveSystemMock.saving = false
    zoneResetCount = 0
    bodyPatch = nil
    gameState.currentChapter = 4
    gameState.currentZone = "ch4_haven"
    gameState.worldMode = nil
    gameState.player.x = 1
    gameState.player.y = 1
    gameState.player.lingYun = 0
    gameState.player.gold = 0
    gameState.player.exp = 0
    gameState.pet._statsDirty = false
    TreasureMapSystem.SetGameRefs(gameMap, camera)
end

local function CompleteDeferredSave(ok, reason)
    local callback = deferredSaveCallback
    deferredSaveCallback = nil
    saveSystemMock.saving = false
    if callback then callback(ok, reason) end
end

local function RestoreActive(runId, mapCount)
    TreasureMapSystem._HandleState(Event({
        ok = true,
        stateJson = ActiveState(runId),
        mapSnapshotJson = MapSnapshot(mapCount or 1),
        recoveryJson = "",
    }))
end

local function BeginCompletion(runId)
    RestoreActive(runId, 1)
    TreasureMapSystem.Update(0.1)
    gameState.player.x = 11
    gameState.player.y = 17
    assertTrue(TreasureMapSystem.RequestStartOpen("chest_restore"))
    TreasureMapSystem._HandleStartResult(Event({
        ok = true,
        openToken = "open-token-" .. runId,
        minDurationMs = 1,
    }))
    TreasureMapSystem.Update(0.01)
end

test("open result immediately applies skin and immortal-body account patches", function()
    ResetClient()
    BeginCompletion("run-client-1")
    local skinId = "pet_premium_chiyan"
    local wanbaoId = "immortal_body_wanbao_liuli"
    TreasureMapSystem._HandleOpenResult(Event({
        ok = true,
        backpackPatch = {
            { slot = 3, item = { itemId = "lingyun_fruit_supreme", count = 1 } },
        },
        playerPatch = { lingYun = 5000, gold = 10000000, exp = 2500 },
        cosmeticsPatch = { skinId = skinId, version = 7 },
        immortalBodiesPatch = {
            version = 3,
            unlockedBodies = {
                [wanbaoId] = { source = "treasure_map", sourceRunId = "run-client-1" },
            },
        },
        stateJson = { version = 1, revision = 9, completed = { runId = "run-client-1" } },
        runId = "run-client-1",
        rewardJson = { kind = "account_treasure", rewardType = "immortal_body_wanbao" },
        replayed = false,
    }))

    assertEqual(gameState.player.lingYun, 5000)
    assertEqual(gameState.player.gold, 10000000)
    assertEqual(gameState.player.exp, 2500)
    assertEqual(inventoryWrites[3].itemId, "lingyun_fruit_supreme")
    assertTrue(gameState.accountCosmetics.petAppearances[skinId].unlocked)
    assertEqual(gameState.accountCosmetics.version, 7)
    assertEqual(bodyPatch.unlockedBodies[wanbaoId].sourceRunId, "run-client-1")
    assertEqual(invalidationCount, 2, "skin and body patches must both invalidate stats")
    assertTrue(gameState.pet._statsDirty, "skin patch must invalidate pet stats")
    assertEqual(emitted[#emitted].name, "TreasureMap_OpenSuccess")
    assertEqual(emitted[#emitted].payload.state.revision, 9)
end)

test("login state automatically restores the authoritative island and checkpoints it", function()
    ResetClient()
    gameState.currentChapter = 4
    gameState.currentZone = "ch4_haven"
    gameState.worldMode = nil
    gameState.player.x = 40
    gameState.player.y = 40
    saveCount = 0
    zoneResetCount = 0
    inventorySlots[2] = {
        category = "consumable",
        consumableId = "treasure_map",
        count = 2,
    }

    TreasureMapSystem._HandleState(Event({
        ok = true,
        stateJson = ActiveState("run-restore"),
        mapSnapshotJson = MapSnapshot(1, 5),
        recoveryJson = "",
    }))

    assertEqual(gameState.worldMode, "treasure_map")
    assertEqual(gameState.player.x, 12)
    assertEqual(gameState.player.y, 18)
    assertEqual(camera.x, 12)
    assertEqual(camera.y, 18)
    assertEqual(gameState.currentZone, "zone_12_18")
    assertEqual(zoneResetCount, 1)
    assertEqual(inventorySlots[2], nil, "stale local map stack must be removed")
    assertEqual(inventorySlots[5].count, 1, "server map snapshot must be authoritative")
    assertEqual(saveCount, 0, "checkpoint is queued for the next update")
    assertEqual(TreasureMapSystem.RequestStartOpen("chest_restore"), false,
        "opening must wait for the island checkpoint")

    TreasureMapSystem.Update(0.1)
    assertEqual(saveCount, 1)
    assertEqual(lastCheckpointMapCount, 1,
        "checkpoint must never restore the map consumed before a lost response")
    assertTrue(TreasureMapSystem.CanSaveOnIsland())

    assertTrue(TreasureMapSystem.RequestStartOpen("chest_restore"))
    assertEqual(TreasureMapSystem.CanSaveOnIsland(), false,
        "pending chest authorization must block full saves")
    TreasureMapSystem._HandleStartResult(Event({
        ok = true,
        openToken = "open-token",
        minDurationMs = 1,
    }))
    gameState.player.x = 11
    gameState.player.y = 17
    TreasureMapSystem.Update(0.01)
    assertEqual(TreasureMapSystem.CanSaveOnIsland(), false,
        "awaiting authoritative settlement must block full saves")

    TreasureMapSystem._HandleState(Event({
        ok = true,
        stateJson = ActiveState("run-restore"),
        mapSnapshotJson = MapSnapshot(1, 5),
        recoveryJson = "",
    }))
    assertTrue(TreasureMapSystem.CanSaveOnIsland())
    assertTrue(#sentEvents >= 2, "start and complete events must be sent")

    local sawResumePrompt = false
    for _, event in ipairs(emitted) do
        if event.name == "TreasureMap_ResumeAvailable" then sawResumePrompt = true end
    end
    assertEqual(sawResumePrompt, false, "login restore must not depend on a resume prompt")
end)

test("map use outside chapter four is inert", function()
    ResetClient()
    gameState.currentChapter = 3

    assertEqual(TreasureMapSystem.RequestUse("entry"), false)
    assertEqual(saveCount, 0, "outside chapter four must not save")
    assertEqual(#sentEvents, 0, "outside chapter four must not contact the server")
    assertEqual(emitted[#emitted].name, "TreasureMap_Error")
    assertEqual(emitted[#emitted].payload.reason, "藏宝图只能在第四章使用")
end)

test("chapter-four checkpoint must finish before map use is sent", function()
    ResetClient()
    saveAutoComplete = false

    assertTrue(TreasureMapSystem.RequestUse("entry"))
    assertEqual(saveCount, 1)
    assertEqual(#sentEvents, 0, "map use must wait for the chapter-four checkpoint")
    assertEqual(actionTrace[1], "save")

    CompleteDeferredSave(true)
    assertEqual(#sentEvents, 1)
    assertEqual(sentEvents[1].eventName, "C2S_TMUse")
    assertEqual(actionTrace[2], "C2S_TMUse")
end)

test("an existing chapter-switch save is followed by a fresh chapter-four checkpoint", function()
    ResetClient()
    saveSystemMock.saving = true

    assertTrue(TreasureMapSystem.RequestUse("entry"))
    assertEqual(saveCount, 0)
    assertEqual(#sentEvents, 0)
    TreasureMapSystem.Update(1)
    assertEqual(#sentEvents, 0)

    saveSystemMock.saving = false
    TreasureMapSystem.Update(0.1)
    assertEqual(saveCount, 1, "the old save cannot stand in for the chapter-four checkpoint")
    assertEqual(sentEvents[1].eventName, "C2S_TMUse")
end)

test("checkpoint failure sends no use request and unlocks retry", function()
    ResetClient()
    saveNextOk = false
    saveNextReason = "network_error"

    assertEqual(TreasureMapSystem.RequestUse("entry"), false)
    assertEqual(#sentEvents, 0)
    assertEqual(emitted[#emitted].name, "TreasureMap_Error")

    saveNextOk = true
    saveNextReason = nil
    assertTrue(TreasureMapSystem.RequestUse("entry"))
    assertEqual(sentEvents[1].eventName, "C2S_TMUse")
end)

test("timed-out map use retries only the same request id", function()
    ResetClient()
    assertTrue(TreasureMapSystem.RequestUse("entry"))
    local firstId = sentEvents[1].data.requestId
    assertTrue(type(firstId) == "string" and firstId ~= "")
    assertEqual(sentEvents[1].eventName, "C2S_TMUse")
    assertEqual(TreasureMapSystem.RequestUse("entry"), false,
        "ambiguous use must block a second request id")

    TreasureMapSystem.Update(10.1)
    local useIds = {}
    for _, sent in ipairs(sentEvents) do
        if sent.eventName == "C2S_TMUse" then
            useIds[#useIds + 1] = sent.data.requestId
        end
    end
    assertEqual(#useIds, 2)
    assertEqual(useIds[1], useIds[2], "timeout retry must reuse the original request id")

    TreasureMapSystem._HandleState(Event({
        ok = true,
        stateJson = { version = 1, revision = 0 },
        mapSnapshotJson = MapSnapshot(2),
        recoveryJson = "",
    }))
    TreasureMapSystem.Update(5.1)
    useIds = {}
    for _, sent in ipairs(sentEvents) do
        if sent.eventName == "C2S_TMUse" then
            useIds[#useIds + 1] = sent.data.requestId
        end
    end
    assertEqual(#useIds, 3)
    assertEqual(useIds[3], firstId,
        "empty authoritative state must continue the same ambiguous request")

    TreasureMapSystem._HandleUseResult(Event({
        ok = false,
        requestId = firstId,
        reason = "藏宝图不足",
    }))
    assertTrue(TreasureMapSystem.RequestUse("entry"),
        "an explicit matching failure may unlock a new request")
end)

test("stale map-use response cannot clear the current ambiguous request", function()
    ResetClient()
    assertTrue(TreasureMapSystem.RequestUse("entry"))
    local currentId = sentEvents[1].data.requestId
    TreasureMapSystem._HandleUseResult(Event({
        ok = false,
        requestId = "stale-request-id",
        reason = "stale",
    }))
    assertEqual(TreasureMapSystem.RequestUse("entry"), false)
    TreasureMapSystem.Update(10.1)
    local retriedId = nil
    for _, sent in ipairs(sentEvents) do
        if sent.eventName == "C2S_TMUse" then retriedId = sent.data.requestId end
    end
    assertEqual(retriedId, currentId)
end)

test("start-open timeout drops only local authorization and queries authority", function()
    ResetClient()
    RestoreActive("run-open-timeout", 1)
    TreasureMapSystem.Update(0.1)
    assertTrue(TreasureMapSystem.RequestStartOpen("chest_restore"))
    TreasureMapSystem.Update(10.1)
    assertTrue(TreasureMapSystem.CanSaveOnIsland(),
        "timeout must clear local pending authorization without clearing the run")

    local sawQuery = false
    for _, sent in ipairs(sentEvents) do
        if sent.eventName == "C2S_TMQuery" then sawQuery = true end
    end
    assertTrue(sawQuery, "authorization timeout must query authoritative state")

    TreasureMapSystem._HandleStartResult(Event({
        ok = true,
        openToken = "late-open-token",
        minDurationMs = 1,
    }))
    assertEqual(TreasureMapSystem.IsChanneling(), false,
        "late authorization must not restart a timed-out channel")
    assertTrue(TreasureMapSystem.RequestStartOpen("chest_restore"),
        "the same preserved run must be openable again")
end)

test("authoritative empty state returns home and permits the next map", function()
    ResetClient()
    RestoreActive("run-exit-lost", 1)
    TreasureMapSystem.Update(0.1)
    assertTrue(TreasureMapSystem.RequestExit())

    TreasureMapSystem._HandleState(Event({
        ok = true,
        stateJson = { version = 1, revision = 12 },
        mapSnapshotJson = MapSnapshot(1),
        recoveryJson = "",
    }))
    assertEqual(gameState.worldMode, nil)
    assertEqual(gameState.player.x, 0)
    assertEqual(gameState.player.y, 0)
    assertTrue(TreasureMapSystem.RequestUse("entry"),
        "after authoritative departure the next map flow must unlock")
end)

for _, name in ipairs(moduleNames) do
    package.loaded[name] = originals[name]
end
cjson = originalCjson
network = originalNetwork
Variant = originalVariant
VariantMap = originalVariantMap

print(string.format("[test_treasure_map_client_patch] passed=%d failed=%d total=%d",
    passed, failed, total))

return { passed = passed, failed = failed, total = total }
