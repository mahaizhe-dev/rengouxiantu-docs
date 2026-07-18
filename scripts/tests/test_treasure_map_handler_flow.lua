-- ============================================================================
-- test_treasure_map_handler_flow.lua - authoritative transaction regression
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local Session = require("network.ServerSession")
local SaveBackupService = require("network.SaveBackupService")
local AccountCosmeticsService = require("network.AccountCosmeticsService")
local AccountImmortalBodiesService = require("network.AccountImmortalBodiesService")
local Config = require("config.TreasureMapConfig")
local SaveProtocol = require("network.SaveProtocol")
local GameConfig = require("config.GameConfig")

local originals = {
    Variant = Variant,
    VariantMap = VariantMap,
    cjson = cjson,
    serverCloud = serverCloud,
    connKey = Session.ConnKey,
    getUserId = Session.GetUserId,
    connSlots = Session.connSlots_,
    acquireSlotLock = Session.AcquireSlotLock,
    releaseSlotLock = Session.ReleaseSlotLock,
    safeSend = Session.SafeSend,
    beforeOverwrite = SaveBackupService.BeforeOverwrite,
    rollReward = Config.RollReward,
    openDuration = Config.OPEN_DURATION_MS,
    cosmeticsBegin = AccountCosmeticsService.Begin,
    bodiesBegin = AccountImmortalBodiesService.Begin,
}

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

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual))
    end
end

local function Clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[Clone(key, seen)] = Clone(child, seen) end
    return result
end

local function VariantValue(value)
    if type(value) == "table" and value.__variantValue ~= nil then
        return value.__variantValue
    end
    return value
end

function Variant(value)
    return { __variantValue = value }
end

function VariantMap()
    return {}
end

cjson = {
    encode = function(value) return Clone(value) end,
    decode = function(value) return Clone(value) end,
}

local connKey = "treasure_map_flow_conn"
local userId = 10001
local slot = 1
local connection = { sent = {} }

function connection:SendRemoteEvent(eventName, reliable, data)
    local fields = {}
    for key, value in pairs(data or {}) do fields[key] = VariantValue(value) end
    self.sent[#self.sent + 1] = {
        eventName = eventName,
        reliable = reliable,
        data = fields,
    }
end

local storage = {}
local failNextSave = false
local saveCount = 0

local function NewBatchGet()
    local keys = {}
    local batch = {}
    function batch:Key(key)
        keys[#keys + 1] = key
        return self
    end
    function batch:Fetch(callbacks)
        local scores = {}
        for _, key in ipairs(keys) do scores[key] = Clone(storage[key]) end
        callbacks.ok(scores)
    end
    return batch
end

local function NewBatchSet()
    local writes = {}
    local batch = {}
    function batch:Set(key, value)
        writes[key] = Clone(value)
        return self
    end
    function batch:Save(_, callbacks)
        saveCount = saveCount + 1
        if failNextSave then
            failNextSave = false
            callbacks.error("TEST_SAVE_FAILURE", "forced")
            return
        end
        for key, value in pairs(writes) do storage[key] = Clone(value) end
        callbacks.ok()
    end
    return batch
end

serverCloud = {
    BatchGet = function() return NewBatchGet() end,
    BatchSet = function() return NewBatchSet() end,
}

Session.ConnKey = function() return connKey end
Session.GetUserId = function() return userId end
Session.connSlots_ = { [connKey] = slot }
Session.AcquireSlotLock = function() return true end
Session.ReleaseSlotLock = function() end
Session.SafeSend = function(conn, eventName, data)
    conn:SendRemoteEvent(eventName, true, data)
end
SaveBackupService.BeforeOverwrite = function(_, _, _, onReady)
    onReady(Clone(storage["save_1"]))
end
Config.OPEN_DURATION_MS = 0

local forcedReward = {
    kind = "consumable",
    rewardType = "lingyun_fruit",
    itemId = "lingyun_fruit",
    amount = 4,
}
Config.RollReward = function()
    return Clone(forcedReward), Config.ISLAND_BY_REWARD_TYPE[forcedReward.rewardType]
end

package.loaded["network.TreasureMapHandler"] = nil
local Handler = require("network.TreasureMapHandler")

local function Event(fields)
    local eventData = {
        Connection = { GetPtr = function() return connection end },
    }
    for key, value in pairs(fields or {}) do
        eventData[key] = {
            GetString = function() return tostring(value) end,
            GetBool = function() return value == true end,
        }
    end
    return eventData
end

local function Reset(mapCount, backpack)
    storage = {
        ["save_1"] = {
            player = { chapter = 4, lingYun = 0 },
            immortalBody = { activeBodyId = "mortal" },
            backpack = backpack or {
                ["1"] = {
                    category = "consumable",
                    consumableId = Config.MAP_ITEM_ID,
                    count = mapCount or 1,
                },
            },
        },
    }
    failNextSave = false
    saveCount = 0
    connection.sent = {}
    forcedReward = {
        kind = "consumable",
        rewardType = "lingyun_fruit",
        itemId = "lingyun_fruit",
        amount = 4,
    }
    AccountCosmeticsService.Begin = originals.cosmeticsBegin
    AccountImmortalBodiesService.Begin = originals.bodiesBegin
    Session.accountWriteLocks_ = {}
    Handler.CleanupConnection(connKey)
end

local function LastResponse()
    return connection.sent[#connection.sent]
end

local function Use(requestId)
    Handler.HandleUse(nil, Event({
        requestId = requestId,
        entryId = Config.ENTRY.id,
        mode = "entry",
    }))
    return LastResponse()
end

local function StartAndComplete(active)
    Handler.HandleStartOpen(nil, Event({
        runId = active.runId,
        islandId = active.islandId,
        chestId = active.chestId,
    }))
    local start = LastResponse()
    assertTrue(start and start.data.ok == true, "start open should succeed")
    Handler.HandleCompleteOpen(nil, Event({
        runId = active.runId,
        chestId = active.chestId,
        openToken = start.data.openToken,
    }))
    return LastResponse(), start.data.openToken
end

test("use save failure does not consume map or create sidecar", function()
    Reset(2)
    local source = Clone(storage["save_1"])
    failNextSave = true
    local response = Use("request-save-failure")
    assertEqual(response.data.ok, false)
    assertEqual(storage["save_1"].backpack["1"].count, source.backpack["1"].count)
    assertEqual(storage[Config.STATE_KEY_PREFIX .. "1"], nil)
end)

test("first use outside chapter four does not consume or roll", function()
    Reset(2)
    storage["save_1"].player.chapter = 5
    local countBefore = storage["save_1"].backpack["1"].count
    local response = Use("request-wrong-chapter")
    assertEqual(response.data.ok, false)
    assertEqual(storage["save_1"].backpack["1"].count, countBefore)
    assertEqual(storage[Config.STATE_KEY_PREFIX .. "1"], nil)
end)

test("duplicate requestId replays one run without consuming a second map", function()
    Reset(2)
    local first = Use("request-idempotent")
    assertEqual(first.data.ok, true)
    assertEqual(first.data.mapSnapshotJson[1].item.count, 1)
    local runId = first.data.runId
    local rewardType = first.data.rewardType
    local countAfterFirst = storage["save_1"].backpack["1"].count
    local savesAfterFirst = saveCount
    forcedReward = {
        kind = "consumable",
        rewardType = "gold_brick",
        itemId = "gold_brick",
        amount = 12,
    }
    local second = Use("request-idempotent")
    assertEqual(second.data.ok, true)
    assertEqual(second.data.replayed, true)
    assertEqual(second.data.runId, runId)
    assertEqual(second.data.rewardType, rewardType,
        "same request id must replay the persisted reward instead of rerolling")
    assertEqual(storage[Config.STATE_KEY_PREFIX .. "1"].active.pendingReward.rewardType,
        rewardType)
    assertEqual(second.data.mapSnapshotJson[1].item.count, 1)
    assertEqual(storage["save_1"].backpack["1"].count, countAfterFirst)
    assertEqual(saveCount, savesAfterFirst)
end)

test("query returns an authoritative treasure-map slot snapshot after response loss", function()
    Reset(2)
    local useResponse = Use("request-lost-use-response")
    assertEqual(useResponse.data.ok, true)
    assertEqual(useResponse.data.mapSnapshotJson[1].slot, 1)
    assertEqual(useResponse.data.mapSnapshotJson[1].item.count, 1)

    Handler.HandleQueryState(nil, Event())
    local queryResponse = LastResponse()
    assertEqual(queryResponse.data.ok, true)
    assertEqual(queryResponse.data.mapCount, 1)
    assertEqual(queryResponse.data.mapSnapshotJson[1].slot, 1)
    assertEqual(queryResponse.data.mapSnapshotJson[1].item.consumableId, Config.MAP_ITEM_ID)
    assertEqual(queryResponse.data.mapSnapshotJson[1].item.count, 1)
end)

test("active run blocks a second request without consuming a map", function()
    Reset(2)
    assertEqual(Use("request-first").data.ok, true)
    local countAfterFirst = storage["save_1"].backpack["1"].count
    local response = Use("request-second")
    assertEqual(response.data.ok, false)
    assertEqual(storage["save_1"].backpack["1"].count, countAfterFirst)
end)

test("return portal always abandons an unopened treasure and invalidates its token", function()
    Reset(2)
    assertEqual(Use("request-portal-abandon").data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local sessionId = storage[stateKey].session.sessionId
    assertEqual(storage["save_1"].player.treasureRunId, active.runId)
    assertEqual(storage["save_1"].player.treasureSessionId,
        storage[stateKey].session.sessionId)
    assertEqual(storage["save_1"].player.x,
        Config.ISLAND_BY_ID[active.islandId].spawn.x)
    assertEqual(storage["save_1"].player.y,
        Config.ISLAND_BY_ID[active.islandId].spawn.y)

    Handler.HandleStartOpen(nil, Event({
        runId = active.runId,
        islandId = active.islandId,
        chestId = active.chestId,
    }))
    local token = LastResponse().data.openToken

    -- Any portal departure abandons the active expedition, but must be bound
    -- to the exact run/session so a delayed request cannot hit the next map.
    Handler.HandleExit(nil, Event({
        runId = active.runId,
        sessionId = sessionId,
    }))
    assertEqual(LastResponse().data.ok, true)
    assertEqual(storage[stateKey].active, nil)
    assertEqual(storage[stateKey].session, nil)
    assertEqual(storage["save_1"].player.treasureRunId, nil)
    assertEqual(storage["save_1"].player.treasureSessionId, nil)
    assertEqual(storage["save_1"].player.treasureRevision, storage[stateKey].revision)
    assertTrue(storage["save_1"].player.treasureRevision > 1)
    assertEqual(storage["save_1"].player.x, Config.RETURN_POINT.x)
    assertEqual(storage["save_1"].player.y, Config.RETURN_POINT.y)

    local countAfterExit = storage["save_1"].backpack["1"].count
    local replayedOldUse = Use("request-portal-abandon")
    assertEqual(replayedOldUse.data.ok, false)
    assertEqual(storage["save_1"].backpack["1"].count, countAfterExit,
        "completed or abandoned request ids must remain consumed after departure")

    Handler.HandleCompleteOpen(nil, Event({
        runId = active.runId,
        chestId = active.chestId,
        openToken = token,
    }))
    assertEqual(LastResponse().data.ok, false)

    local nextRun = Use("request-after-portal-abandon")
    assertEqual(nextRun.data.ok, true)
    assertEqual(storage["save_1"].backpack["1"], nil)

    local nextActive = Clone(storage[stateKey].active)
    Handler.HandleExit(nil, Event({
        runId = active.runId,
        sessionId = sessionId,
    }))
    assertEqual(LastResponse().data.ok, false)
    assertEqual(storage[stateKey].active.runId, nextActive.runId,
        "a delayed departure from the old run must not abandon the next map")
end)

test("query migrates an old active run into a resumable island checkpoint", function()
    Reset(1)
    assertEqual(Use("request-resume-migration").data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local sessionId = storage[stateKey].session.sessionId
    storage["save_1"].player.treasureSessionId = nil
    storage["save_1"].player.treasureRunId = nil
    storage["save_1"].player.x = Config.RETURN_POINT.x
    storage["save_1"].player.y = Config.RETURN_POINT.y

    Handler.HandleQueryState(nil, Event())
    assertEqual(LastResponse().data.ok, true)
    assertEqual(storage["save_1"].player.treasureSessionId, sessionId)
    assertEqual(storage["save_1"].player.treasureRunId, active.runId)
    assertEqual(storage["save_1"].player.x,
        Config.ISLAND_BY_ID[active.islandId].spawn.x)
    assertEqual(storage["save_1"].player.y,
        Config.ISLAND_BY_ID[active.islandId].spawn.y)
end)

test("query never rolls the main-save treasure revision backward", function()
    Reset(1)
    assertEqual(Use("request-revision-rollback").data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local mainRevision = storage["save_1"].player.treasureRevision
    storage[stateKey].revision = mainRevision - 1

    Handler.HandleQueryState(nil, Event())
    assertEqual(LastResponse().data.ok, false)
    assertEqual(storage["save_1"].player.treasureRevision, mainRevision)
end)

test("full backpack preserves active pending reward", function()
    local backpack = {}
    for index = 1, GameConfig.BACKPACK_SIZE do
        backpack[tostring(index)] = {
            id = index,
            category = "equipment",
            equipId = "test_full_" .. tostring(index),
        }
    end
    backpack["1"] = {
        category = "consumable",
        consumableId = Config.MAP_ITEM_ID,
        count = 2,
    }
    Reset(1, backpack)
    local useResponse = Use("request-full-backpack")
    assertEqual(useResponse.data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local response = StartAndComplete(active)
    assertEqual(response.data.ok, false)
    assertEqual(storage[stateKey].active.runId, active.runId)
    assertEqual(storage[stateKey].completedRuns[active.runId], nil)
end)

test("completed run replays even after the in-memory open token is gone", function()
    Reset(1)
    local useResponse = Use("request-replay")
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local first, token = StartAndComplete(active)
    assertEqual(first.data.ok, true)
    local savesAfterFirst = saveCount
    Handler.HandleCompleteOpen(nil, Event({
        runId = active.runId,
        chestId = active.chestId,
        openToken = token,
    }))
    local replay = LastResponse()
    assertEqual(replay.data.ok, true)
    assertEqual(replay.data.replayed, true)
    assertEqual(saveCount, savesAfterFirst)
end)

test("completed reward must exit before another map can be used", function()
    Reset(2)
    local useResponse = Use("request-return-gate")
    assertEqual(useResponse.data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local complete = StartAndComplete(active)
    assertEqual(complete.data.ok, true)
    local sessionId = storage[stateKey].session.sessionId
    local countAfterComplete = storage["save_1"].backpack["1"].count

    local blocked = Use("request-before-return")
    assertEqual(blocked.data.ok, false)
    assertEqual(storage["save_1"].backpack["1"].count, countAfterComplete)

    Handler.HandleExit(nil, Event({
        runId = "",
        sessionId = sessionId,
    }))
    assertEqual(LastResponse().data.ok, true)
    local replayedCompletedUse = Use("request-return-gate")
    assertEqual(replayedCompletedUse.data.ok, false)
    local nextRun = Use("request-after-return")
    assertEqual(nextRun.data.ok, true)
    assertEqual(storage["save_1"].backpack["1"], nil)
end)

test("wrong chest cannot start opening", function()
    Reset(1)
    assertEqual(Use("request-wrong-chest").data.ok, true)
    local active = storage[Config.STATE_KEY_PREFIX .. "1"].active
    Handler.HandleStartOpen(nil, Event({
        runId = active.runId,
        islandId = active.islandId,
        chestId = "treasure_chest_other",
    }))
    assertEqual(LastResponse().data.ok, false)
    assertEqual(storage[Config.STATE_KEY_PREFIX .. "1"].active.runId, active.runId)

    local otherIsland = nil
    for _, island in ipairs(Config.ISLANDS) do
        if island.islandId ~= active.islandId then
            otherIsland = island
            break
        end
    end
    Handler.HandleStartOpen(nil, Event({
        runId = active.runId,
        islandId = otherIsland.islandId,
        chestId = otherIsland.chest.chestId,
    }))
    assertEqual(LastResponse().data.ok, false,
        "cheat movement to another island must not authorize its chest")
end)

test("opening before minimum duration preserves active reward", function()
    Reset(1)
    Config.OPEN_DURATION_MS = 1000
    assertEqual(Use("request-too-fast").data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    Handler.HandleStartOpen(nil, Event({
        runId = active.runId,
        islandId = active.islandId,
        chestId = active.chestId,
    }))
    local start = LastResponse()
    Handler.HandleCompleteOpen(nil, Event({
        runId = active.runId,
        chestId = active.chestId,
        openToken = start.data.openToken,
    }))
    assertEqual(LastResponse().data.ok, false)
    assertEqual(storage[stateKey].active.runId, active.runId)
    Config.OPEN_DURATION_MS = 0
end)

test("skin data read failure preserves active reward", function()
    Reset(1)
    forcedReward = {
        kind = "pet_skin",
        rewardType = "account_treasure",
        skinId = Config.SKIN_IDS[1],
        amount = 1,
    }
    AccountCosmeticsService.Begin = function(_, callbacks)
        callbacks.error("TEST_COSMETICS_READ_FAILURE", "forced")
    end
    local useResponse = Use("request-skin-read-failure")
    assertEqual(useResponse.data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local response = StartAndComplete(active)
    assertEqual(response.data.ok, false)
    assertEqual(storage[stateKey].active.runId, active.runId)
    assertEqual(storage[stateKey].completedRuns[active.runId], nil)
end)

test("pet skin first unlock persists account cosmetics without lingyun", function()
    Reset(1)
    local skinId = Config.SKIN_IDS[1]
    forcedReward = {
        kind = "pet_skin",
        rewardType = "account_treasure",
        skinId = skinId,
        amount = 1,
    }
    local useResponse = Use("request-skin-first")
    assertEqual(useResponse.data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local response = StartAndComplete(active)
    assertEqual(response.data.ok, true)
    local cosmetics = storage[AccountCosmeticsService.STORAGE_KEY]
    assertTrue(cosmetics.petAppearances[skinId].unlocked)
    assertEqual(cosmetics.petAppearances[skinId].sourceRunId, active.runId)
    assertEqual(response.data.rewardJson.skinResult.duplicate, false)
    assertEqual(response.data.cosmeticsPatch.skinId, skinId)
    assertEqual(storage["save_1"].player.lingYun, 0)
end)

test("pet skin duplicate grants exactly five thousand lingyun once", function()
    Reset(1)
    local skinId = Config.SKIN_IDS[1]
    storage[AccountCosmeticsService.STORAGE_KEY] = {
        version = 2,
        petAppearances = {
            [skinId] = {
                unlocked = true,
                unlockTime = 1,
                sourceType = "previous",
            },
        },
        skinRewardSources = {},
    }
    forcedReward = {
        kind = "pet_skin",
        rewardType = "account_treasure",
        skinId = skinId,
        amount = 1,
    }
    local useResponse = Use("request-skin-duplicate")
    assertEqual(useResponse.data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local response, token = StartAndComplete(active)
    assertEqual(response.data.ok, true)
    assertEqual(response.data.rewardJson.skinResult.duplicate, true)
    assertEqual(response.data.rewardJson.duplicateLingYun, 5000)
    assertEqual(storage["save_1"].player.lingYun, 5000)

    local savesAfterFirst = saveCount
    Handler.HandleCompleteOpen(nil, Event({
        runId = active.runId,
        chestId = active.chestId,
        openToken = token,
    }))
    local replay = LastResponse()
    assertEqual(replay.data.replayed, true)
    assertEqual(storage["save_1"].player.lingYun, 5000)
    assertEqual(saveCount, savesAfterFirst)
end)

test("pet skin batch save failure writes neither unlock nor completion", function()
    Reset(1)
    forcedReward = {
        kind = "pet_skin",
        rewardType = "account_treasure",
        skinId = Config.SKIN_IDS[1],
        amount = 1,
    }
    assertEqual(Use("request-skin-save-failure").data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    failNextSave = true
    local response = StartAndComplete(active)
    assertEqual(response.data.ok, false)
    assertEqual(storage[stateKey].active.runId, active.runId)
    assertEqual(storage[stateKey].completedRuns[active.runId], nil)
    assertEqual(storage[AccountCosmeticsService.STORAGE_KEY], nil)
end)

test("wanbao first unlock persists account body and client patch", function()
    Reset(1)
    forcedReward = {
        kind = "immortal_body",
        rewardType = "account_treasure",
        bodyId = Config.WANBAO_BODY_ID,
    }
    local useResponse = Use("request-body-first")
    assertEqual(useResponse.data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local response = StartAndComplete(active)
    assertEqual(response.data.ok, true)
    local bodies = storage[AccountImmortalBodiesService.STORAGE_KEY]
    assertTrue(bodies.unlockedBodies[Config.WANBAO_BODY_ID] ~= nil)
    assertEqual(bodies.unlockedBodies[Config.WANBAO_BODY_ID].firstUnlockSlot, 1)
    assertEqual(response.data.rewardJson.bodyResult.duplicate, false)
    assertTrue(response.data.immortalBodiesPatch.unlockedBodies[Config.WANBAO_BODY_ID] ~= nil)
    assertEqual(storage["save_1"].player.lingYun, 0)
    assertEqual(storage["save_1"].immortalBody.activeBodyId, "mortal")
end)

test("wanbao duplicate grants exactly five thousand lingyun", function()
    Reset(1)
    storage[AccountImmortalBodiesService.STORAGE_KEY] = {
        version = 2,
        unlockedBodies = {
            mortal = { unlockedAt = 0, source = "default" },
            [Config.WANBAO_BODY_ID] = { unlockedAt = 1, source = "previous" },
        },
        bodyRewardSources = {},
    }
    forcedReward = {
        kind = "immortal_body",
        rewardType = "account_treasure",
        bodyId = Config.WANBAO_BODY_ID,
    }
    local useResponse = Use("request-body-duplicate")
    assertEqual(useResponse.data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local response, token = StartAndComplete(active)
    assertEqual(response.data.ok, true)
    assertEqual(response.data.rewardJson.bodyResult.duplicate, true)
    assertEqual(response.data.rewardJson.duplicateLingYun, 5000)
    assertEqual(storage["save_1"].player.lingYun, 5000)

    local savesAfterFirst = saveCount
    Handler.HandleCompleteOpen(nil, Event({
        runId = active.runId,
        chestId = active.chestId,
        openToken = token,
    }))
    local replay = LastResponse()
    assertEqual(replay.data.replayed, true)
    assertEqual(storage["save_1"].player.lingYun, 5000)
    assertEqual(saveCount, savesAfterFirst)
end)

test("body data read failure preserves active reward", function()
    Reset(1)
    forcedReward = {
        kind = "immortal_body",
        rewardType = "account_treasure",
        bodyId = Config.WANBAO_BODY_ID,
    }
    AccountImmortalBodiesService.Begin = function(_, callbacks)
        callbacks.error("TEST_BODY_READ_FAILURE", "forced")
    end
    local useResponse = Use("request-body-read-failure")
    assertEqual(useResponse.data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    local response = StartAndComplete(active)
    assertEqual(response.data.ok, false)
    assertEqual(storage[stateKey].active.runId, active.runId)
    assertEqual(storage[stateKey].completedRuns[active.runId], nil)
end)

test("body batch save failure writes neither account unlock nor completion", function()
    Reset(1)
    forcedReward = {
        kind = "immortal_body",
        rewardType = "account_treasure",
        bodyId = Config.WANBAO_BODY_ID,
    }
    assertEqual(Use("request-body-save-failure").data.ok, true)
    local stateKey = Config.STATE_KEY_PREFIX .. "1"
    local active = Clone(storage[stateKey].active)
    failNextSave = true
    local response = StartAndComplete(active)
    assertEqual(response.data.ok, false)
    assertEqual(storage[stateKey].active.runId, active.runId)
    assertEqual(storage[stateKey].completedRuns[active.runId], nil)
    assertEqual(storage[AccountImmortalBodiesService.STORAGE_KEY], nil)
end)

test("GM grants ten treasure maps through authoritative save and patch", function()
    Reset(1)
    Handler.GMGrantMaps10(userId, slot, connection)
    local response = LastResponse()
    assertEqual(response.eventName, SaveProtocol.S2C_GMCommandResult)
    assertEqual(response.data.ok, true)
    assertEqual(response.data.cmd, "treasure_maps_10")
    assertEqual(response.data.mapCount, 11)
    assertTrue(type(response.data.backpackPatch) == "table")
    assertEqual(storage["save_1"].backpack["1"].count, 11)
end)

test("GM treasure map save failure grants nothing and releases the slot lock", function()
    Reset(1)
    failNextSave = true
    Handler.GMGrantMaps10(userId, slot, connection)
    local failedResponse = LastResponse()
    assertEqual(failedResponse.data.ok, false)
    assertEqual(failedResponse.data.cmd, "treasure_maps_10")
    assertEqual(storage["save_1"].backpack["1"].count, 1)

    Handler.GMGrantMaps10(userId, slot, connection)
    local retryResponse = LastResponse()
    assertEqual(retryResponse.data.ok, true)
    assertEqual(storage["save_1"].backpack["1"].count, 11)
end)

Variant = originals.Variant
VariantMap = originals.VariantMap
cjson = originals.cjson
serverCloud = originals.serverCloud
Session.ConnKey = originals.connKey
Session.GetUserId = originals.getUserId
Session.connSlots_ = originals.connSlots
Session.AcquireSlotLock = originals.acquireSlotLock
Session.ReleaseSlotLock = originals.releaseSlotLock
Session.SafeSend = originals.safeSend
SaveBackupService.BeforeOverwrite = originals.beforeOverwrite
Config.RollReward = originals.rollReward
Config.OPEN_DURATION_MS = originals.openDuration
AccountCosmeticsService.Begin = originals.cosmeticsBegin
AccountImmortalBodiesService.Begin = originals.bodiesBegin
package.loaded["network.TreasureMapHandler"] = nil

print(string.format("[test_treasure_map_handler_flow] passed=%d failed=%d total=%d",
    passed, failed, total))
return { passed = passed, failed = failed, total = total }
