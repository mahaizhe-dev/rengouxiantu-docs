-- ============================================================================
-- test_wubao_treasure_handler_flow.lua - 乌堡宝箱服务端事务测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local SaveProtocol = require("network.SaveProtocol")
local Config = require("config.WubaoTreasureConfig")
local Session = require("network.ServerSession")
local SaveBackupService = require("network.SaveBackupService")

local originals = {
    Variant = Variant,
    VariantMap = VariantMap,
    cjson = cjson,
    serverCloud = serverCloud,
    ConnKey = Session.ConnKey,
    GetUserId = Session.GetUserId,
    connSlots_ = Session.connSlots_,
    AcquireSlotLock = Session.AcquireSlotLock,
    ReleaseSlotLock = Session.ReleaseSlotLock,
    SafeSend = Session.SafeSend,
    ServerGetSlotData = Session.ServerGetSlotData,
    BeforeOverwrite = SaveBackupService.BeforeOverwrite,
}

local passed, failed, total = 0, 0, 0

local function fail(desc, detail)
    failed = failed + 1
    print("  FAIL: " .. desc .. (detail and (" - " .. detail) or ""))
end

local function assertTrue(cond, desc, detail)
    total = total + 1
    if cond then passed = passed + 1 else fail(desc, detail) end
end

local function assertEqual(actual, expected, desc)
    total = total + 1
    if actual == expected then
        passed = passed + 1
    else
        fail(desc, "expected=" .. tostring(expected) .. ", actual=" .. tostring(actual))
    end
end

local function variantValue(v)
    if type(v) == "table" and v.__variant_value ~= nil then return v.__variant_value end
    return v
end

function Variant(value)
    return { __variant_value = value }
end

function VariantMap()
    return {}
end

cjson = {
    encode = function(value) return value end,
    decode = function(value) return value end,
}

local connKey = "wubao_test_conn"
local connection = { sent = {} }

function connection:SendRemoteEvent(eventName, reliable, data)
    local fields = {}
    for k, v in pairs(data or {}) do
        fields[k] = variantValue(v)
    end
    self.sent[#self.sent + 1] = {
        eventName = eventName,
        reliable = reliable,
        data = fields,
    }
end

local function makeEvent(chestId)
    return {
        Connection = {
            GetPtr = function() return connection end,
        },
        chestId = {
            GetString = function() return chestId end,
        },
    }
end

local currentSaveData = nil
local savedData = nil
local saveShouldFail = false

Session.ConnKey = function() return connKey end
Session.GetUserId = function() return 10001 end
Session.connSlots_ = { [connKey] = 1 }
Session.AcquireSlotLock = function() return true end
Session.ReleaseSlotLock = function() end
Session.SafeSend = function(conn, eventName, data)
    conn:SendRemoteEvent(eventName, true, data)
end
Session.ServerGetSlotData = function(userId, slot, callback)
    callback(currentSaveData)
end

SaveBackupService.BeforeOverwrite = function(userId, slot, desc, onOk, onError)
    onOk()
end

serverCloud = {
    BatchSet = function(self, userId)
        return {
            Set = function(batch, key, data)
                savedData = data
                return batch
            end,
            Save = function(batch, desc, callbacks)
                if saveShouldFail then
                    callbacks.error("TEST_FAIL", "forced")
                else
                    callbacks.ok()
                end
            end,
        }
    end,
}

local Handler = require("network.WubaoTreasureHandler")

local function reset(saveData, failSave)
    currentSaveData = saveData
    savedData = nil
    saveShouldFail = failSave == true
    connection.sent = {}
    Handler.CleanupConnection(connKey)
end

local function lastResponse()
    return connection.sent[#connection.sent]
end

local function countOrder(order)
    local chestCount, rewardSeen = 0, {}
    for chestId, rewardId in pairs(order or {}) do
        if Config.CHESTS[chestId] then
            chestCount = chestCount + 1
            rewardSeen[rewardId] = (rewardSeen[rewardId] or 0) + 1
        end
    end
    local rewardCount = 0
    for _, n in pairs(rewardSeen) do
        if n == 1 then rewardCount = rewardCount + 1 end
    end
    return chestCount, rewardCount
end

local function makeRewardOrder(firstRewardId)
    local order = {}
    local firstChest = Config.CHEST_ORDER[1]
    order[firstChest] = firstRewardId
    local index = 1
    for _, chestId in ipairs(Config.CHEST_ORDER) do
        if chestId ~= firstChest then
            while Config.REWARD_IDS[index] == firstRewardId do
                index = index + 1
            end
            order[chestId] = Config.REWARD_IDS[index]
            index = index + 1
        end
    end
    return order
end

local function findConsumable(backpack, consumableId)
    for _, item in pairs(backpack or {}) do
        if type(item) == "table"
            and item.category == "consumable"
            and item.consumableId == consumableId then
            return item
        end
    end
    return nil
end

print("--- WubaoTreasure handler flow: reward order save before key prompt ---")

reset({ backpack = {}, wubaoTreasureState = nil }, false)
Handler.HandleStartOpen(nil, makeEvent(Config.CHEST_ORDER[1]))
local resp = lastResponse()
assertEqual(resp and resp.eventName, SaveProtocol.S2C_WubaoTreasure_StartResult, "无钥匙交互返回 StartResult")
assertEqual(resp and resp.data and resp.data.ok, false, "无钥匙交互不进入开箱结算")
assertEqual(resp and resp.data and resp.data.message, "需要堡主钥匙", "无钥匙提示正确")
assertTrue(savedData ~= nil, "无钥匙但首次交互仍保存奖励映射")
local chestCount, rewardCount = countOrder(savedData and savedData.wubaoTreasureState and savedData.wubaoTreasureState.rewardOrder)
assertEqual(chestCount, 16, "首次奖励映射覆盖 16 个宝箱")
assertEqual(rewardCount, 16, "首次奖励映射奖励编号不重复")

print("--- WubaoTreasure handler flow: reward order save failure blocks start ---")

reset({
    backpack = {
        ["1"] = { category = "consumable", consumableId = Config.KEY_ID, count = 1 },
    },
}, true)
Handler.HandleStartOpen(nil, makeEvent(Config.CHEST_ORDER[1]))
resp = lastResponse()
assertEqual(resp and resp.data and resp.data.ok, false, "奖励映射保存失败不进入开箱结算")
assertEqual(resp and resp.data and resp.data.message, "奖励映射保存失败，请稍后重试", "奖励映射保存失败文案")

print("--- WubaoTreasure handler flow: successful open grants reward and consumes key ---")

local chestId = Config.CHEST_ORDER[1]
local order = makeRewardOrder("reward_11")
reset({
    backpack = {
        ["1"] = { category = "consumable", consumableId = Config.KEY_ID, count = 2 },
    },
    wubaoTreasureState = { rewardOrder = order, opened = {} },
}, false)
Handler.HandleStartOpen(nil, makeEvent(chestId))
resp = lastResponse()
assertEqual(resp and resp.data and resp.data.ok, true, "持钥匙可进入开箱结算")
Handler.HandleCompleteOpen(nil, makeEvent(chestId))
resp = lastResponse()
assertEqual(resp and resp.eventName, SaveProtocol.S2C_WubaoTreasure_OpenResult, "开箱返回 OpenResult")
assertEqual(resp and resp.data and resp.data.ok, true, "开箱成功")
assertEqual(savedData and savedData.backpack and savedData.backpack["1"] and savedData.backpack["1"].count, 1, "成功开箱扣除 1 把钥匙")
local goldBar = findConsumable(savedData and savedData.backpack, "gold_bar")
assertEqual(goldBar and goldBar.count, 10, "成功开箱发放 reward_11 金条×10")
assertTrue(savedData and savedData.wubaoTreasureState and savedData.wubaoTreasureState.opened[chestId] == true, "成功开箱标记 opened")

print("--- WubaoTreasure handler flow: save failure does not mutate source save ---")

local sourceSave = {
    backpack = {
        ["1"] = { category = "consumable", consumableId = Config.KEY_ID, count = 1 },
    },
    wubaoTreasureState = { rewardOrder = makeRewardOrder("reward_11"), opened = {} },
}
reset(sourceSave, false)
Handler.HandleStartOpen(nil, makeEvent(chestId))
assertEqual(lastResponse() and lastResponse().data and lastResponse().data.ok, true, "保存失败用例先成功进入开箱结算")
saveShouldFail = true
Handler.HandleCompleteOpen(nil, makeEvent(chestId))
resp = lastResponse()
assertEqual(resp and resp.data and resp.data.ok, false, "保存失败返回失败")
assertEqual(resp and resp.data and resp.data.message, "奖励保存失败，请重新开启", "保存失败提示可重试")
assertEqual(sourceSave.backpack["1"].count, 1, "保存失败不扣原始钥匙")
assertTrue(findConsumable(sourceSave.backpack, "gold_bar") == nil, "保存失败不污染原始背包奖励")
assertTrue(sourceSave.wubaoTreasureState.opened[chestId] ~= true, "保存失败不标记原始宝箱 opened")

print("--- WubaoTreasure handler flow: GM grants 16 keys with save patch ---")

reset({ backpack = {}, wubaoTreasureState = nil }, false)
Handler.GMGrantKeys16(10001, 1, connection)
resp = lastResponse()
assertEqual(resp and resp.eventName, SaveProtocol.S2C_GMCommandResult, "GM给钥匙返回 GMCommandResult")
assertEqual(resp and resp.data and resp.data.ok, true, "GM给钥匙成功")
assertEqual(resp and resp.data and resp.data.cmd, "wubao_keys_16", "GM给钥匙命令号")
local gmKey = findConsumable(savedData and savedData.backpack, Config.KEY_ID)
assertEqual(gmKey and gmKey.count, 16, "GM给钥匙写入存档 16 把")
assertTrue(type(resp and resp.data and resp.data.backpackPatch) == "table", "GM给钥匙返回背包 patch")

print("--- WubaoTreasure handler flow: GM reset treasure state ---")

reset({
    backpack = {},
    wubaoTreasureState = {
        rewardOrder = makeRewardOrder("reward_11"),
        opened = { [chestId] = true },
    },
}, false)
Handler.GMResetTreasure(10001, 1, connection, connKey)
resp = lastResponse()
assertEqual(resp and resp.eventName, SaveProtocol.S2C_GMCommandResult, "GM重置宝藏返回 GMCommandResult")
assertEqual(resp and resp.data and resp.data.ok, true, "GM重置宝藏成功")
assertEqual(resp and resp.data and resp.data.cmd, "wubao_reset_treasure", "GM重置宝藏命令号")
local resetState = savedData and savedData.wubaoTreasureState
assertTrue(resetState and next(resetState.rewardOrder or {}) == nil, "GM重置清空 rewardOrder")
assertTrue(resetState and next(resetState.opened or {}) == nil, "GM重置清空 opened")
assertTrue(type(resp and resp.data and resp.data.stateJson) == "table", "GM重置返回宝藏状态")

print(string.format("--- WubaoTreasure handler flow: %d/%d passed, %d failed ---", passed, total, failed))

Variant = originals.Variant
VariantMap = originals.VariantMap
cjson = originals.cjson
serverCloud = originals.serverCloud
Session.ConnKey = originals.ConnKey
Session.GetUserId = originals.GetUserId
Session.connSlots_ = originals.connSlots_
Session.AcquireSlotLock = originals.AcquireSlotLock
Session.ReleaseSlotLock = originals.ReleaseSlotLock
Session.SafeSend = originals.SafeSend
Session.ServerGetSlotData = originals.ServerGetSlotData
SaveBackupService.BeforeOverwrite = originals.BeforeOverwrite

return { passed = passed, failed = failed, total = total }
