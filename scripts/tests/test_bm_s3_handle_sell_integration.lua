-- ============================================================================
-- test_bm_s3_handle_sell_integration.lua
-- BM-S3R 真实 HandleSell() 拒绝路径集成测试
--
-- 验证 HandleSell() 被 SellGuard 拒绝时的服务端副作用：
--   I1. 高风险商品 → HandleSell 返回错误
--   I2. 拒绝时不调用 MoneyAdd(userId, "xianshi", ...)
--   I3. 拒绝时不调用 TradeLogger.LogPublic(..., "sell", ...)
--   I4. 拒绝时 sellActive_ 锁正确释放
--   I5. 拒绝时返回明确错误消息"该商品暂不支持出售"
--   I6. 所有分类的高风险商品均触发相同拒绝行为
--   I7. 自动回收路径 grep 验证 — SellGuard 未被 RecycleTick 引用
--
-- 测试方法：构造 stub serverCloud / connection / eventData / Session / TradeLogger，
-- 直接调用 HandleSell() 并断言副作用。
--
-- 纯 Lua 测试。
-- ============================================================================

local passed = 0
local failed = 0
local total  = 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        print("  ✗ " .. name .. ": " .. tostring(err))
    end
end

local function assertEqual(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a))
    end
end

local function assertTrue(v, msg)
    if not v then error(msg or "expected true") end
end

local function assertFalse(v, msg)
    if v then error(msg or "expected false") end
end

print("\n[test_bm_s3_handle_sell_integration] === BM-S3R HandleSell 拒绝路径集成测试 ===\n")

-- ============================================================================
-- 保存原始 package.loaded
-- ============================================================================
local _modulesToStub = {
    "config.BlackMerchantConfig",
    "config.GameConfig",
    "config.EquipmentData",
    "config.PetSkillData",
    "network.BlackMarketSellGuard",
    "network.BlackMerchantHandler",
    "network.BlackMerchantTradeLogger",
    "network.ServerSession",
    "network.SaveProtocol",
    "network.BackpackUtils",
    "systems.LootSystem",
}
local _origPackageLoaded = {}
for _, k in ipairs(_modulesToStub) do
    _origPackageLoaded[k] = package.loaded[k]
    package.loaded[k] = nil
end

-- ============================================================================
-- Spy infrastructure
-- ============================================================================

local spyLog = {}  -- 记录所有被调用的副作用

local function resetSpyLog()
    spyLog = {}
end

local function logSpy(action, ...)
    spyLog[#spyLog + 1] = { action = action, args = { ... } }
end

local function findSpyCall(action)
    for _, entry in ipairs(spyLog) do
        if entry.action == action then
            return entry
        end
    end
    return nil
end

-- ============================================================================
-- Stub: SaveProtocol
-- ============================================================================
local stubSaveProtocol = {
    S2C_BlackMerchantResult = "S2C_BlackMerchantResult",
    S2C_BlackMerchantData = "S2C_BlackMerchantData",
    S2C_BlackMerchantExchangeResult = "S2C_BlackMerchantExchangeResult",
    S2C_BlackMerchantHistory = "S2C_BlackMerchantHistory",
}
package.loaded["network.SaveProtocol"] = stubSaveProtocol

-- ============================================================================
-- Stub: ServerSession
-- ============================================================================
local TEST_CONN_KEY = "test_conn_1"
local TEST_USER_ID = 12345

local stubSession = {
    connSlots_ = { [TEST_CONN_KEY] = 1 },
}

function stubSession.ConnKey(connection)
    return TEST_CONN_KEY
end

function stubSession.GetUserId(connKey)
    if connKey == TEST_CONN_KEY then
        return TEST_USER_ID
    end
    return nil
end

function stubSession.SafeSend(connection, eventName, data)
    logSpy("SafeSend", eventName, data)
end

function stubSession.ServerGetSlotData(userId, slot, callback)
    -- 不应该走到这里（SellGuard 在步骤 2.5 拦截）
    logSpy("ServerGetSlotData", userId, slot)
    callback(nil)
end

package.loaded["network.ServerSession"] = stubSession

-- ============================================================================
-- Stub: BackpackUtils
-- ============================================================================
local stubBackpackUtils = {
    MAX_BACKPACK_SLOTS = 100,
    MAX_STACK = 999,
}
function stubBackpackUtils.CountBackpackItem(backpack, itemId) return 0 end
function stubBackpackUtils.AddToBackpack(backpack, itemId, amount, name) end
function stubBackpackUtils.RemoveFromBackpack(backpack, itemId, amount) end
function stubBackpackUtils.CountEquipmentItem(backpack, equipId) return 0 end
function stubBackpackUtils.AddEquipmentToBackpack(backpack, equip) end
function stubBackpackUtils.RemoveEquipmentFromBackpack(backpack, equipId, amount) end

package.loaded["network.BackpackUtils"] = stubBackpackUtils

-- ============================================================================
-- Stub: LootSystem
-- ============================================================================
local stubLootSystem = {}
function stubLootSystem.CreateSpecialEquipment(equipId) return nil end
package.loaded["systems.LootSystem"] = stubLootSystem

-- ============================================================================
-- Stub: TradeLogger (spy)
-- ============================================================================
local stubTradeLogger = {}
function stubTradeLogger.LogPublic(playerName, action, itemId, amount, price, newXianshi)
    logSpy("TradeLogger.LogPublic", playerName, action, itemId, amount, price, newXianshi)
end
function stubTradeLogger.LogPersonal(userId, action, itemId, amount, price, newXianshi)
    logSpy("TradeLogger.LogPersonal", userId, action, itemId, amount, price, newXianshi)
end
package.loaded["network.BlackMerchantTradeLogger"] = stubTradeLogger

-- ============================================================================
-- Stub: serverCloud (spy)
-- ============================================================================
local stubServerCloud = {}
local _batchCommitSpy = {}

function stubServerCloud:BatchCommit(desc)
    local commit = { desc = desc, ops = {} }
    function commit:MoneyAdd(uid, key, amount)
        logSpy("MoneyAdd", uid, key, amount)
        commit.ops[#commit.ops + 1] = { "MoneyAdd", uid, key, amount }
    end
    function commit:MoneyCost(uid, key, amount)
        logSpy("MoneyCost", uid, key, amount)
        commit.ops[#commit.ops + 1] = { "MoneyCost", uid, key, amount }
    end
    function commit:ListAdd(uid, key, value)
        logSpy("ListAdd", uid, key, value)
    end
    function commit:Commit(callbacks)
        logSpy("BatchCommit.Commit", desc)
        if callbacks and callbacks.ok then callbacks.ok() end
    end
    _batchCommitSpy = commit
    return commit
end

stubServerCloud.money = {}
function stubServerCloud.money:Get(uid, callbacks)
    logSpy("money.Get", uid)
    if callbacks and callbacks.ok then
        callbacks.ok({ xianshi = 1000 })
    end
end

stubServerCloud.list = {}
function stubServerCloud.list:Get(uid, key, callbacks)
    logSpy("list.Get", uid, key)
    if callbacks and callbacks.ok then
        callbacks.ok({})
    end
end
function stubServerCloud.list:Add(uid, key, value, callbacks)
    logSpy("list.Add", uid, key, value)
end
function stubServerCloud.list:Delete(listId) end

-- 将 serverCloud 挂到全局
_G.serverCloud = stubServerCloud

-- ============================================================================
-- Stub: Variant / VariantMap (最小化模拟)
-- ============================================================================
if not _G.Variant then
    _G.Variant = function(v) return v end
end
if not _G.VariantMap then
    _G.VariantMap = function()
        local m = {}
        local mt = {
            __newindex = function(t, k, v) rawset(t, k, v) end,
            __index = function(t, k) return rawget(t, k) end,
        }
        return setmetatable(m, mt)
    end
end

-- ============================================================================
-- Stub: connection + eventData
-- ============================================================================
local function makeConnection()
    return { __type = "Connection" }
end

local function makeEventData(fields)
    local data = {}
    -- 模拟 eventData["Connection"]:GetPtr("Connection") 调用链
    data["Connection"] = {
        GetPtr = function(self, typeName)
            return makeConnection()
        end
    }
    -- 模拟 eventData["consumableId"]:GetString() 等
    for k, v in pairs(fields or {}) do
        if type(v) == "string" then
            data[k] = { GetString = function() return v end }
        elseif type(v) == "number" then
            data[k] = { GetInt = function() return v end }
        end
    end
    return data
end

-- ============================================================================
-- 设置"境界已缓存"：注入 playerRealms_
-- HandleSell 先检查 IsRealmOk，需要预设缓存
-- ============================================================================

-- 加载真实模块（它们会 require 上面的 stub）
local BMConfig = require("config.BlackMerchantConfig")
local SellGuard = require("network.BlackMarketSellGuard")
local Handler = require("network.BlackMerchantHandler")

-- 由于 playerRealms_ 是 local，我们通过先调用 HandleQuery 的 EnsureRealmCached
-- 来间接设置。但更简单的做法是：HandleSell 在境界不满足时直接返回错误，
-- 我们测试的是 SellGuard 拦截（步骤 2.5），需要境界通过。
-- 
-- 方案：直接 stub EnsureRealmCached 的结果 —— 但 playerRealms_ 是 local。
-- 实际上 HandleSell 先检查 IsRealmOk(connKey)，返回 false 会在步骤 1 就退出。
-- 我们需要让步骤 1 通过才能到达步骤 2.5。
--
-- 解决：先通过 HandleQuery 触发 EnsureRealmCached 预热缓存。
-- 但 HandleQuery 依赖更多 stub...
--
-- 更直接的方法：stub ServerGetSlotData 返回有境界的 saveData，
-- 并先调用 HandleQuery（或其他触发 EnsureRealmCached 的路径）
-- 
-- 最简方案：让 HandleSell 走到境界检查失败的分支测试"境界不足"，
-- 然后另建测试让境界通过。

-- 因为 playerRealms_ 是 Handler 的 local 变量，无法直接设置。
-- 所以我们需要构造一个让 EnsureRealmCached 能成功写入缓存的环境。
-- EnsureRealmCached 调用 Session.ServerGetSlotData，我们 stub 它。

-- 修改 stub: ServerGetSlotData 返回有筑基境界的存档
local stubGameConfig = require("config.GameConfig")

stubSession.ServerGetSlotData = function(userId, slot, callback)
    logSpy("ServerGetSlotData", userId, slot)
    callback({
        player = {
            realm = "zhuji_1",  -- 筑基初期 order=4, >= JINDAN_ORDER(4)
            charName = "测试仙人",
            lingYun = 100,
        },
        backpack = {},
    })
end

-- 通过调用 HandleQuery 来预热境界缓存（EnsureRealmCached 会写入 playerRealms_）
local function warmUpRealmCache()
    resetSpyLog()
    local ed = makeEventData({})
    Handler.HandleQuery("C2S_BMQuery", ed)
end

-- 预热
warmUpRealmCache()
resetSpyLog()

-- ============================================================================
-- 集成测试
-- ============================================================================

print("  --- HandleSell 拒绝路径集成测试 ---")

test("I1: 高风险商品(rake_fragment_1) → HandleSell 返回错误", function()
    resetSpyLog()
    local rakeIds = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_RAKE)
    assertTrue(#rakeIds > 0, "should have rake items")
    local testId = rakeIds[1]

    local ed = makeEventData({
        consumableId = testId,
        amount = 1,
    })
    Handler.HandleSell("C2S_BMSell", ed)

    -- 应该有 SafeSend 调用
    local sendCall = findSpyCall("SafeSend")
    assertTrue(sendCall ~= nil, "should have called SafeSend")
    -- 验证返回了错误
    local eventName = sendCall.args[1]
    assertEqual(eventName, "S2C_BlackMerchantResult", "event name")
    local respData = sendCall.args[2]
    assertFalse(respData["ok"], "ok should be false")
end)

test("I2: 拒绝时不调用 MoneyAdd(userId, 'xianshi', ...)", function()
    resetSpyLog()
    local ed = makeEventData({
        consumableId = "dragon_scale_ice",
        amount = 1,
    })
    Handler.HandleSell("C2S_BMSell", ed)

    local moneyCall = findSpyCall("MoneyAdd")
    assertEqual(moneyCall, nil, "MoneyAdd should NOT be called on rejection")
end)

test("I3: 拒绝时不调用 TradeLogger.LogPublic(..., 'sell', ...)", function()
    resetSpyLog()
    local ed = makeEventData({
        consumableId = "wubao_token_box",
        amount = 1,
    })
    Handler.HandleSell("C2S_BMSell", ed)

    local logCall = findSpyCall("TradeLogger.LogPublic")
    assertEqual(logCall, nil, "TradeLogger.LogPublic should NOT be called on rejection")
end)

test("I4: 拒绝时 sellActive_ 锁正确释放（可再次调用）", function()
    resetSpyLog()
    -- 第一次调用
    local ed1 = makeEventData({
        consumableId = "gold_brick",
        amount = 1,
    })
    Handler.HandleSell("C2S_BMSell", ed1)

    -- 第二次调用应该也能通过（不被"操作过于频繁"拦截）
    resetSpyLog()
    local ed2 = makeEventData({
        consumableId = "gold_brick",
        amount = 1,
    })
    Handler.HandleSell("C2S_BMSell", ed2)

    local sendCall = findSpyCall("SafeSend")
    assertTrue(sendCall ~= nil, "second call should also produce a response")
    local respData = sendCall.args[2]
    -- 确认不是"操作过于频繁"
    local reason = respData["reason"]
    assertTrue(reason ~= "操作过于频繁", "should not be rate limited on second call")
end)

test("I5: 拒绝时返回明确错误消息'该商品暂不支持出售'", function()
    resetSpyLog()
    local ed = makeEventData({
        consumableId = "sha_hai_ling_box",
        amount = 1,
    })
    Handler.HandleSell("C2S_BMSell", ed)

    local sendCall = findSpyCall("SafeSend")
    assertTrue(sendCall ~= nil, "should have SafeSend call")
    local respData = sendCall.args[2]
    assertEqual(respData["reason"], "该商品暂不支持出售", "error message")
end)

test("I6: 多分类高风险商品均触发相同拒绝行为", function()
    -- 从每个分类取一个代表商品
    local representatives = {}
    for _, cat in ipairs({
        BMConfig.CATEGORY_RAKE,
        BMConfig.CATEGORY_BAGUA,
        BMConfig.CATEGORY_TIANDI,
        BMConfig.CATEGORY_LINGYU,
        BMConfig.CATEGORY_HERB,
        BMConfig.CATEGORY_SKILL_BOOK,
        BMConfig.CATEGORY_SPECIAL_EQUIP,
    }) do
        local ids = BMConfig.GetItemsByCategory(cat)
        if #ids > 0 then
            representatives[#representatives + 1] = { cat = cat, id = ids[1] }
        end
    end
    -- 加上 consumable_mat 的代表
    representatives[#representatives + 1] = { cat = "consumable_mat", id = "dragon_scale_fire" }
    representatives[#representatives + 1] = { cat = "consumable_mat", id = "taixu_token_box" }
    representatives[#representatives + 1] = { cat = "consumable_mat", id = "gold_brick" }

    for _, rep in ipairs(representatives) do
        resetSpyLog()
        local ed = makeEventData({
            consumableId = rep.id,
            amount = 1,
        })
        Handler.HandleSell("C2S_BMSell", ed)

        -- 验证拒绝
        local sendCall = findSpyCall("SafeSend")
        assertTrue(sendCall ~= nil, "should have SafeSend for " .. rep.id)
        local respData = sendCall.args[2]
        assertFalse(respData["ok"], "ok should be false for " .. rep.id)

        -- 验证无 MoneyAdd
        local moneyCall = findSpyCall("MoneyAdd")
        assertEqual(moneyCall, nil, "no MoneyAdd for " .. rep.id)

        -- 验证无 TradeLogger
        local tradeCall = findSpyCall("TradeLogger.LogPublic")
        assertEqual(tradeCall, nil, "no TradeLogger for " .. rep.id)
    end
end)

test("I7: 拒绝时不触发 ServerGetSlotData（不读取存档）", function()
    resetSpyLog()
    local ed = makeEventData({
        consumableId = "dragon_scale_abyss",
        amount = 1,
    })
    Handler.HandleSell("C2S_BMSell", ed)

    -- SellGuard 在步骤 2.5 拦截，不应走到步骤 4 的 ServerGetSlotData
    -- 注意：warmUpRealmCache 会调用 ServerGetSlotData，但我们在这里
    -- resetSpyLog 后再调 HandleSell，所以只有 HandleSell 的调用会被记录
    local slotCall = findSpyCall("ServerGetSlotData")
    assertEqual(slotCall, nil, "ServerGetSlotData should NOT be called after SellGuard rejection")
end)

test("I8: 拒绝时不触发 BatchCommit", function()
    resetSpyLog()
    local ed = makeEventData({
        consumableId = "dragon_scale_sand",
        amount = 1,
    })
    Handler.HandleSell("C2S_BMSell", ed)

    local commitCall = findSpyCall("BatchCommit.Commit")
    assertEqual(commitCall, nil, "BatchCommit should NOT be called on rejection")
end)

-- ============================================================================
-- D. 自动回收隔离 — 代码级验证
-- ============================================================================

print("  --- 自动回收隔离验证 ---")

test("I9: SellGuard 模块不导出任何回收相关接口", function()
    -- SellGuard 应该只有分类判定功能，不应有任何回收相关方法
    local publicApi = {}
    for k, v in pairs(SellGuard) do
        if type(v) == "function" then
            publicApi[#publicApi + 1] = k
        end
    end
    -- 期望的公共 API
    local expected = { "CheckSellAllowed", "GetSafeItemIds", "GetHighRiskItemIds" }
    assertEqual(#publicApi, #expected, "SellGuard should have exactly 3 public functions")
    for _, name in ipairs(expected) do
        assertTrue(SellGuard[name] ~= nil, "SellGuard." .. name .. " should exist")
    end
end)

test("I10: BlackMerchantHandler 的自动回收代码不引用 SellGuard", function()
    -- Handler 导出 RecycleTick / ExecuteRecycle（自动回收功能），
    -- 但这些方法不应引用 SellGuard（回收不走卖出校验）。
    -- 用源码 grep 验证：读取 Handler 源码中 RecycleTick/ExecuteRecycle 段落，
    -- 确认不包含 SellGuard 引用。
    local handlerPath = "scripts/network/BlackMerchantHandler.lua"
    local f = io.open(handlerPath, "r")
    if not f then
        -- io 不可用时（沙箱），尝试 package.searchpath
        local path = package.searchpath("network.BlackMerchantHandler", package.path)
        if path then f = io.open(path, "r") end
    end
    if f then
        local src = f:read("*a")
        f:close()
        -- 提取 RecycleTick + ExecuteRecycle 函数体（从 function 到下一个 ^function 或 ^return）
        local recycleBlock = src:match("function M%.ExecuteRecycle.-\nfunction M%.RecycleTick.-\nend")
            or src:match("function M%.ExecuteRecycle(.+)")
        if recycleBlock then
            assertFalse(recycleBlock:find("SellGuard"),
                "RecycleTick/ExecuteRecycle block should NOT reference SellGuard")
        end
    else
        -- 无法读源码，回退到接口层验证：
        -- 确认 Handler 的公开接口中 RecycleTick/ExecuteRecycle 存在但与 SellGuard 无关
        assertTrue(Handler.RecycleTick ~= nil, "Handler.RecycleTick exists (回收功能)")
        assertTrue(Handler.ExecuteRecycle ~= nil, "Handler.ExecuteRecycle exists (回收功能)")
    end
    -- 额外验证：SellGuard 模块不导出任何 recycle 相关接口
    assertEqual(SellGuard.RecycleTick, nil, "SellGuard has no RecycleTick")
    assertEqual(SellGuard.ExecuteRecycle, nil, "SellGuard has no ExecuteRecycle")
end)

-- ============================================================================
-- 汇总
-- ============================================================================

print("\n[test_bm_s3_handle_sell_integration] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

-- ============================================================================
-- Cleanup: 恢复 package.loaded + 全局
-- ============================================================================
_G.serverCloud = nil
for _, k in ipairs(_modulesToStub) do
    package.loaded[k] = _origPackageLoaded[k]
end

return { passed = passed, failed = failed, total = total }
