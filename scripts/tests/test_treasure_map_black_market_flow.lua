---@diagnostic disable
-- ============================================================================
-- test_treasure_map_black_market_flow.lua - buy/sell/no-resell integration
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local BMConfig = require("config.BlackMerchantConfig")

local moduleNames = {
    "network.BlackMerchantHandler",
    "network.ServerSession",
    "network.SaveProtocol",
    "network.SaveBackupService",
    "network.BlackMerchantTradeLogger",
    "network.BackpackUtils",
    "network.BlackMarketSellGuard",
    "systems.BlackMarketTradeLock",
    "systems.LootSystem",
}
local originals = {}
for _, name in ipairs(moduleNames) do
    originals[name] = package.loaded[name]
end
local originalGlobals = {
    Variant = Variant,
    VariantMap = VariantMap,
    cjson = cjson,
    serverCloud = serverCloud,
}

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

Variant = function(value) return value end
VariantMap = function() return {} end
cjson = {
    encode = function(value) return Clone(value) end,
    decode = function(value) return Clone(value) end,
}

local USER_ID = 21001
local CONN_KEY = "treasure_map_bm_conn"
local SLOT = 1
local ITEM_ID = "treasure_map"
local STOCK_KEY = BMConfig.StockKey(ITEM_ID)

local connection = { sent = {} }
local saveStore = {}
local moneyStore = {}
local listStore = {}
local nextListId = 1

local Session = {
    connSlots_ = { [CONN_KEY] = SLOT },
}
function Session.ConnKey()
    return CONN_KEY
end
function Session.GetUserId(connKey)
    return connKey == CONN_KEY and USER_ID or nil
end
function Session.ServerGetSlotData(_, slot, callback)
    callback(Clone(saveStore["save_" .. tostring(slot)]))
end
function Session.AcquireSlotLock()
    return true
end
function Session.ReleaseSlotLock() end
function Session.SafeSend(_, eventName, data)
    connection.sent[#connection.sent + 1] = {
        eventName = eventName,
        data = Clone(data),
    }
end

local SaveProtocol = {
    S2C_BlackMerchantResult = "S2C_BlackMerchantResult",
    S2C_BlackMerchantData = "S2C_BlackMerchantData",
    S2C_BlackMerchantExchangeResult = "S2C_BlackMerchantExchangeResult",
    S2C_BlackMerchantHistory = "S2C_BlackMerchantHistory",
}
local SaveBackupService = {}
function SaveBackupService.BeforeOverwrite(_, slot, _, onReady)
    onReady(Clone(saveStore["save_" .. tostring(slot)]))
end

local TradeLogger = {
    LogPublic = function() end,
    LogPersonal = function() end,
}
local LootSystem = {
    CreateSpecialEquipment = function() return nil end,
}

package.loaded["network.ServerSession"] = Session
package.loaded["network.SaveProtocol"] = SaveProtocol
package.loaded["network.SaveBackupService"] = SaveBackupService
package.loaded["network.BlackMerchantTradeLogger"] = TradeLogger
package.loaded["systems.LootSystem"] = LootSystem
package.loaded["network.BackpackUtils"] = nil
package.loaded["network.BlackMarketSellGuard"] = nil
package.loaded["systems.BlackMarketTradeLock"] = nil

local BackpackUtils = require("network.BackpackUtils")
local TradeLock = require("systems.BlackMarketTradeLock")

local cloud = {}
cloud.money = {}
function cloud.money:Get(userId, callbacks)
    callbacks.ok(Clone(moneyStore[userId] or {}))
end
function cloud.money:Add(userId, key, amount, callbacks)
    moneyStore[userId] = moneyStore[userId] or {}
    moneyStore[userId][key] = (moneyStore[userId][key] or 0) + amount
    if callbacks and callbacks.ok then callbacks.ok() end
end

cloud.list = {}
function cloud.list:Get(userId, key, callbacks)
    local byUser = listStore[userId] or {}
    callbacks.ok(Clone(byUser[key] or {}))
end
function cloud.list:Add(userId, key, value, callbacks)
    listStore[userId] = listStore[userId] or {}
    listStore[userId][key] = listStore[userId][key] or {}
    listStore[userId][key][#listStore[userId][key] + 1] = {
        list_id = nextListId,
        value = Clone(value),
    }
    nextListId = nextListId + 1
    if callbacks and callbacks.ok then callbacks.ok() end
end
function cloud.list:Delete(listId)
    for _, byKey in pairs(listStore) do
        for _, entries in pairs(byKey) do
            for index = #entries, 1, -1 do
                if entries[index].list_id == listId then
                    table.remove(entries, index)
                end
            end
        end
    end
end

function cloud:BatchCommit()
    local operations = {}
    local batch = {}
    function batch:MoneyCost(userId, key, amount)
        operations[#operations + 1] = {
            kind = "cost", userId = userId, key = key, amount = amount,
        }
        return self
    end
    function batch:MoneyAdd(userId, key, amount)
        operations[#operations + 1] = {
            kind = "add", userId = userId, key = key, amount = amount,
        }
        return self
    end
    function batch:ListAdd(userId, key, value)
        operations[#operations + 1] = {
            kind = "list", userId = userId, key = key, value = Clone(value),
        }
        return self
    end
    function batch:Commit(callbacks)
        for _, operation in ipairs(operations) do
            if operation.kind == "cost" then
                local balance = moneyStore[operation.userId]
                    and moneyStore[operation.userId][operation.key] or 0
                if balance < operation.amount then
                    callbacks.error("INSUFFICIENT", "insufficient balance")
                    return
                end
            end
        end
        for _, operation in ipairs(operations) do
            if operation.kind == "cost" or operation.kind == "add" then
                moneyStore[operation.userId] = moneyStore[operation.userId] or {}
                local sign = operation.kind == "cost" and -1 or 1
                moneyStore[operation.userId][operation.key] =
                    (moneyStore[operation.userId][operation.key] or 0)
                    + sign * operation.amount
            elseif operation.kind == "list" then
                cloud.list:Add(
                    operation.userId, operation.key, operation.value, { ok = function() end })
            end
        end
        callbacks.ok()
    end
    return batch
end

function cloud:BatchSet()
    local writes = {}
    local batch = {}
    function batch:Set(key, value)
        writes[key] = Clone(value)
        return self
    end
    function batch:Save(_, callbacks)
        for key, value in pairs(writes) do
            saveStore[key] = Clone(value)
        end
        callbacks.ok()
    end
    return batch
end

function cloud:BatchGet()
    local keys = {}
    local batch = {}
    function batch:Key(key)
        keys[#keys + 1] = key
        return self
    end
    function batch:Fetch(callbacks)
        local scores = {}
        for _, key in ipairs(keys) do
            scores[key] = Clone(saveStore[key])
        end
        callbacks.ok(scores)
    end
    return batch
end

serverCloud = cloud

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

local function Event(fields)
    local data = {
        Connection = {
            GetPtr = function() return connection end,
        },
    }
    for key, value in pairs(fields or {}) do
        data[key] = {
            GetString = function() return tostring(value) end,
            GetInt = function() return math.floor(tonumber(value) or 0) end,
        }
    end
    return data
end

local function Reset(backpack, stock)
    connection.sent = {}
    saveStore = {
        save_1 = {
            player = {
                realm = "zhuji_1",
                charName = "藏宝测试角色",
            },
            backpack = Clone(backpack or {}),
        },
    }
    moneyStore = {
        [USER_ID] = { xianshi = 100 },
        [BMConfig.SYSTEM_UID] = { [STOCK_KEY] = stock or 10 },
    }
    listStore = {}
    nextListId = 1
    package.loaded["network.BlackMerchantHandler"] = nil
    local handler = require("network.BlackMerchantHandler")
    handler.HandleQuery(nil, Event())
    connection.sent = {}
    return handler
end

local function LastResponse()
    return connection.sent[#connection.sent]
end

test("buying one treasure map costs 12 and creates a no-resell stack", function()
    local handler = Reset({}, 10)
    handler.HandleBuy(nil, Event({ consumableId = ITEM_ID, amount = 1 }))

    assertEqual(moneyStore[USER_ID].xianshi, 88)
    assertEqual(moneyStore[BMConfig.SYSTEM_UID][STOCK_KEY], 9)
    assertEqual(BackpackUtils.CountBackpackItem(saveStore.save_1.backpack, ITEM_ID), 1)
    assertEqual(BackpackUtils.CountResellableBackpackItem(
        saveStore.save_1.backpack, ITEM_ID), 0)
    assertEqual(BackpackUtils.CountNoResellBackpackItem(
        saveStore.save_1.backpack, ITEM_ID), 1)

    local stack = saveStore.save_1.backpack["1"]
    assertTrue(stack and stack.bmNoResell == true)
    assertEqual(stack.bmSource, TradeLock.NO_RESELL_SOURCE)
    local response = LastResponse()
    assertEqual(response.data.ok, true)
    assertEqual(response.data.action, "buy")
    assertEqual(response.data.total, 12)
end)

test("a black-market treasure map cannot be sold back", function()
    local handler = Reset({}, 10)
    handler.HandleBuy(nil, Event({ consumableId = ITEM_ID, amount = 1 }))
    handler.HandleSell(nil, Event({ consumableId = ITEM_ID, amount = 1 }))

    assertEqual(moneyStore[USER_ID].xianshi, 88)
    assertEqual(moneyStore[BMConfig.SYSTEM_UID][STOCK_KEY], 9)
    assertEqual(BackpackUtils.CountNoResellBackpackItem(
        saveStore.save_1.backpack, ITEM_ID), 1)
    local response = LastResponse()
    assertEqual(response.data.ok, false)
    assertEqual(response.data.reason, TradeLock.NO_RESELL_MESSAGE)
end)

test("a boss-drop treasure map sells for 6 without consuming no-resell maps", function()
    local backpack = {}
    BackpackUtils.AddLockedNewStack(backpack, ITEM_ID, 1, "藏宝图")
    BackpackUtils.AddToBackpack(backpack, ITEM_ID, 1, "藏宝图")
    local handler = Reset(backpack, 9)
    handler.HandleSell(nil, Event({ consumableId = ITEM_ID, amount = 1 }))

    assertEqual(moneyStore[USER_ID].xianshi, 106)
    assertEqual(moneyStore[BMConfig.SYSTEM_UID][STOCK_KEY], 10)
    assertEqual(BackpackUtils.CountResellableBackpackItem(
        saveStore.save_1.backpack, ITEM_ID), 0)
    assertEqual(BackpackUtils.CountNoResellBackpackItem(
        saveStore.save_1.backpack, ITEM_ID), 1)
    local response = LastResponse()
    assertEqual(response.data.ok, true)
    assertEqual(response.data.action, "sell")
    assertEqual(response.data.total, 6)
    assertEqual(response.data.newXianshi, 106)
end)

for _, name in ipairs(moduleNames) do
    package.loaded[name] = originals[name]
end
Variant = originalGlobals.Variant
VariantMap = originalGlobals.VariantMap
cjson = originalGlobals.cjson
serverCloud = originalGlobals.serverCloud

print(string.format("[test_treasure_map_black_market_flow] passed=%d failed=%d total=%d",
    passed, failed, total))
return { passed = passed, failed = failed, total = total }
