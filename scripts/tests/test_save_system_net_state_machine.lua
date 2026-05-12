-- ============================================================================
-- test_save_system_net_state_machine.lua — SaveSystemNet 状态机收口测试
--
-- R2: 验证 SaveSystemNet 的 pending 生命周期语义
--
-- 覆盖范围：
--   T1. FetchSlots single-flight reject：pending 时拒绝新请求
--   T2. FetchSlots 晚到响应：无 pending 时 S2C 被忽略
--   T3. Load single-flight reject：pending 时拒绝新请求
--   T4. Load 晚到响应：无 pending 时 S2C 被忽略
--   T5. Char single-flight reject：create 和 delete 共享 pending
--   T6. Char 晚到响应：无 pending 时 S2C 被忽略
--   T7. Migrate single-flight reject：pending 时拒绝新请求
--   T8. Migrate 晚到响应：无 pending 时 S2C 被忽略
--   T9. ClearQueue 通知排队的 FetchSlots 回调
--   T10. 网络未就绪时 FetchSlots 入队
--   T11. FetchSlots 正常流程：beginPending → resolvePending → callback
--   T12. Load 正常流程：beginPending → resolvePending → callback
--
-- 测试通过 stub 替代引擎全局（network/SubscribeToEvent/VariantMap/Variant 等），
-- 仅验证 SaveSystemNet 内部状态机逻辑。
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

local function assert_eq(actual, expected, testName)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print(string.format("  ✗ %s — expected %s, got %s",
            testName, tostring(expected), tostring(actual)))
    end
end

local function assert_true(cond, testName)
    totalTests = totalTests + 1
    if cond then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print(string.format("  ✗ %s — condition is false", testName))
    end
end

local function assert_nil(val, testName)
    totalTests = totalTests + 1
    if val == nil then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print(string.format("  ✗ %s — expected nil, got %s", testName, tostring(val)))
    end
end

local function assert_match(str, pattern, testName)
    totalTests = totalTests + 1
    if type(str) == "string" and str:find(pattern) then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print(string.format("  ✗ %s — string '%s' does not match pattern '%s'",
            testName, tostring(str), pattern))
    end
end

-- ============================================================================
-- Stubs: 模拟引擎全局环境
--
-- 注意：所有测试在同一个 LuaRuntime 中执行（共享全局环境），
-- 因此必须强制覆盖（不能用 if not ... then），且用完后恢复。
-- ============================================================================

-- 保存原始全局，测试结束后恢复
local _origGlobals = {
    network = network,
    cjson = cjson,
    Variant = Variant,
    VariantMap = VariantMap,
    SubscribeToEvent = SubscribeToEvent,
    GetPlatform = GetPlatform,
    fileSystem = fileSystem,
    clientCloud = clientCloud,
    SaveSystemNet_HandleSlotsData = SaveSystemNet_HandleSlotsData,
    SaveSystemNet_HandleLoadResult = SaveSystemNet_HandleLoadResult,
    SaveSystemNet_HandleCharResult = SaveSystemNet_HandleCharResult,
    SaveSystemNet_HandleMigrateResult = SaveSystemNet_HandleMigrateResult,
    SaveSystemNet_HandleDelayedUpdate = SaveSystemNet_HandleDelayedUpdate,
}

-- cjson stub
---@diagnostic disable-next-line: lowercase-global
cjson = {
    encode = function(t) return "{}" end,
    decode = function(s)
        -- 最小化 JSON 解码：支持测试中用到的简单 JSON
        if s == "{}" then return {} end
        -- 对于包含 slots 的 JSON，返回预期结构
        if s:find('"slots"') and s:find('"Hero"') then
            return { slots = { ["1"] = { charName = "Hero" } } }
        end
        if s:find('"slots"') then return { slots = {} } end
        if s:find('"player"') then return { player = { level = 5 }, equipment = {}, backpack = {} } end
        return {}
    end,
}

-- Variant stub
---@diagnostic disable-next-line: lowercase-global
Variant = function(v) return v end

-- VariantMap stub — 支持 key-value 读写和 GetBool/GetString/GetInt/GetFloat
---@diagnostic disable-next-line: lowercase-global
VariantMap = function()
    local data = {}
    local mt = {}
    mt.__newindex = function(t, k, v)
        data[k] = v
    end
    mt.__index = function(t, k)
        local val = data[k]
        return {
            GetBool = function() return val == true or val == "true" end,
            GetString = function() return tostring(val or "") end,
            GetInt = function() return tonumber(val) or 0 end,
            GetFloat = function() return tonumber(val) or 0.0 end,
        }
    end
    return setmetatable({}, mt)
end

-- 记录订阅的事件（用于验证 handler 注册）
local _subscribedEvents = {}

---@diagnostic disable-next-line: lowercase-global
function SubscribeToEvent(eventName, handlerName)
    _subscribedEvents[eventName] = handlerName
end

-- network stub — 可控的 serverConnection
local _mockServerConn = nil

---@diagnostic disable-next-line: lowercase-global
network = {
    GetServerConnection = function(self)
        return _mockServerConn
    end,
}

-- mock serverConn: 记录发送的远程事件
local _sentEvents = {}

local function createMockServerConn()
    _sentEvents = {}
    return {
        SendRemoteEvent = function(self, eventName, reliable, data)
            table.insert(_sentEvents, { event = eventName, reliable = reliable })
        end,
    }
end

-- os.clock stub（如果不存在）
if not os then
    ---@diagnostic disable-next-line: lowercase-global
    os = { clock = function() return 0 end }
elseif not os.clock then
    os.clock = function() return 0 end
end

-- GetPlatform stub
---@diagnostic disable-next-line: lowercase-global
function GetPlatform() return "Windows" end

-- fileSystem stub
---@diagnostic disable-next-line: lowercase-global
fileSystem = {
    FileExists = function(self, f) return false end,
    Delete = function(self, f) end,
}

-- ============================================================================
-- 加载被测模块（强制重新加载以使用当前 stubs）
-- ============================================================================

package.path = package.path .. ";scripts/?.lua"

-- 清除模块缓存，确保使用我们的 stubs 重新加载
package.loaded["network.SaveSystemNet"] = nil
local SaveSystemNet = require("network.SaveSystemNet")

-- ============================================================================
-- 辅助：重置状态并设置模拟连接
-- ============================================================================

local function resetAll()
    SaveSystemNet._resetForTest()
    _sentEvents = {}
    _mockServerConn = createMockServerConn()
end

-- ============================================================================
-- 辅助：构造模拟 S2C 事件数据
-- ============================================================================

local function makeSlotsEventData(ok, slotsIndexJson, needMigration)
    local ed = VariantMap()
    ed["ok"] = ok
    ed["slotsIndex"] = slotsIndexJson or '{"slots":{}}'
    ed["needMigration"] = needMigration or false
    return ed
end

local function makeLoadEventData(ok, saveDataJson, message)
    local ed = VariantMap()
    ed["ok"] = ok
    ed["saveData"] = saveDataJson or '{}'
    ed["message"] = message or ""
    return ed
end

local function makeCharEventData(ok, message)
    local ed = VariantMap()
    ed["ok"] = ok
    ed["message"] = message or ""
    ed["slotsIndex"] = '{"slots":{}}'
    return ed
end

local function makeMigrateEventData(ok, message)
    local ed = VariantMap()
    ed["ok"] = ok
    ed["message"] = message or ""
    return ed
end

-- SaveSystem stub for Load handler
package.loaded["systems.SaveSystem"] = {
    loaded = false,
    ProcessLoadedData = function(slot, saveData, _, callback)
        if callback then callback(true, "ok") end
    end,
    _cachedSlotsIndex = nil,
}

-- ============================================================================
-- 测试开始
-- ============================================================================

print("\n[test_save_system_net_state_machine] === R2 状态机收口测试 ===\n")

-- ─────────────────────────────────────────────────────────────
-- T1. FetchSlots single-flight reject
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    local cb1Result, cb1Error = nil, nil
    local cb2Result, cb2Error = nil, nil

    -- 第一次请求：应成功进入 pending
    SaveSystemNet.FetchSlots(function(slots, err)
        cb1Result = slots
        cb1Error = err
    end)
    assert_eq(#_sentEvents, 1, "T1a: first FetchSlots sends C2S event")

    -- 第二次请求（pending 未完成）：应被拒绝
    SaveSystemNet.FetchSlots(function(slots, err)
        cb2Result = slots
        cb2Error = err
    end)
    assert_eq(#_sentEvents, 1, "T1b: second FetchSlots does NOT send another C2S event")
    assert_nil(cb2Result, "T1c: rejected callback gets nil result")
    assert_match(cb2Error, "already pending", "T1d: rejected callback gets error message")

    -- 第一次请求的回调尚未被调用
    assert_nil(cb1Result, "T1e: first callback not yet called")
    assert_nil(cb1Error, "T1f: first callback not yet called")
end

-- ─────────────────────────────────────────────────────────────
-- T2. FetchSlots 晚到响应
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    -- 不发起任何请求，直接模拟 S2C 响应
    local ed = makeSlotsEventData(true, '{"slots":{}}', false)
    -- 调用 handler（全局函数）
    SaveSystemNet_HandleSlotsData("test", ed)
    -- 应该什么都不发生（晚到响应被忽略）
    local snapshot = SaveSystemNet._getPendingSnapshot()
    assert_nil(snapshot.fetchSlots, "T2: late SlotsData response ignored, no pending")
end

-- ─────────────────────────────────────────────────────────────
-- T3. Load single-flight reject
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    local cb1Ok, cb1Msg = nil, nil
    local cb2Ok, cb2Msg = nil, nil

    SaveSystemNet.Load(1, function(ok, msg)
        cb1Ok = ok
        cb1Msg = msg
    end)
    assert_eq(#_sentEvents, 1, "T3a: first Load sends C2S event")

    SaveSystemNet.Load(2, function(ok, msg)
        cb2Ok = ok
        cb2Msg = msg
    end)
    assert_eq(#_sentEvents, 1, "T3b: second Load does NOT send another C2S event")
    assert_eq(cb2Ok, false, "T3c: rejected Load callback gets false")
    assert_match(cb2Msg, "already pending", "T3d: rejected Load callback gets error message")
    assert_nil(cb1Ok, "T3e: first Load callback not yet called")
end

-- ─────────────────────────────────────────────────────────────
-- T4. Load 晚到响应
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    local ed = makeLoadEventData(true, '{"player":{"level":1}}')
    SaveSystemNet_HandleLoadResult("test", ed)
    local snapshot = SaveSystemNet._getPendingSnapshot()
    assert_nil(snapshot.load, "T4: late LoadResult response ignored, no pending")
end

-- ─────────────────────────────────────────────────────────────
-- T5. Char single-flight reject（create + delete 共享 pending）
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    local cb1Ok, cb1Msg = nil, nil
    local cb2Ok, cb2Msg = nil, nil

    -- 先发 Create
    SaveSystemNet.CreateCharacter(1, "TestChar", {}, function(ok, msg)
        cb1Ok = ok
        cb1Msg = msg
    end)
    assert_eq(#_sentEvents, 1, "T5a: CreateCharacter sends C2S event")

    -- 然后发 Delete（同类 pending，应被拒绝）
    SaveSystemNet.DeleteCharacter(2, {}, function(ok, msg)
        cb2Ok = ok
        cb2Msg = msg
    end)
    assert_eq(#_sentEvents, 1, "T5b: DeleteCharacter does NOT send another C2S event (shared pending)")
    assert_eq(cb2Ok, false, "T5c: rejected Delete callback gets false")
    assert_match(cb2Msg, "already pending", "T5d: rejected Delete gets error message")
    assert_nil(cb1Ok, "T5e: Create callback not yet called")
end

-- ─────────────────────────────────────────────────────────────
-- T6. Char 晚到响应
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    local ed = makeCharEventData(true)
    SaveSystemNet_HandleCharResult("test", ed)
    local snapshot = SaveSystemNet._getPendingSnapshot()
    assert_nil(snapshot.char, "T6: late CharResult response ignored, no pending")
end

-- ─────────────────────────────────────────────────────────────
-- T7. Migrate single-flight reject
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    -- MigrateToServer 在没有 clientCloud/clientScore 时会走 fast-path 返回
    -- 所以我们需要设置一个 mock clientCloud
    ---@diagnostic disable-next-line: lowercase-global
    clientCloud = {
        BatchGet = function(self)
            local builder = { _keys = {} }
            function builder:Key(k) table.insert(self._keys, k); return self end
            function builder:Fetch(events)
                -- 模拟：有数据，触发发送
                if events and events.ok then
                    events.ok(
                        { slots_index = { slots = { [1] = { charName = "Test" } } },
                          save_data_1 = { player = { level = 10 } } },
                        { player_level = 10 },
                        {}
                    )
                end
            end
            return builder
        end,
    }

    local cb1Ok, cb1Msg = nil, nil
    local cb2Ok, cb2Msg = nil, nil

    SaveSystemNet.MigrateToServer(function(ok, msg)
        cb1Ok = ok
        cb1Msg = msg
    end)

    -- 第一次迁移应该成功进入 pending（或者在 BatchGet 回调内完成）
    -- 由于 mock BatchGet 同步返回且有数据，会走到 SendRemoteEvent
    -- pending 仍然存在，等待 S2C 响应

    SaveSystemNet.MigrateToServer(function(ok, msg)
        cb2Ok = ok
        cb2Msg = msg
    end)
    assert_eq(cb2Ok, false, "T7a: second MigrateToServer rejected")
    assert_match(cb2Msg, "already pending", "T7b: rejected migration gets error message")

    -- 清理
    ---@diagnostic disable-next-line: lowercase-global
    clientCloud = nil
end

-- ─────────────────────────────────────────────────────────────
-- T8. Migrate 晚到响应
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    local ed = makeMigrateEventData(true)
    SaveSystemNet_HandleMigrateResult("test", ed)
    local snapshot = SaveSystemNet._getPendingSnapshot()
    assert_nil(snapshot.migrate, "T8: late MigrateResult response ignored, no pending")
end

-- ─────────────────────────────────────────────────────────────
-- T9. ClearQueue 通知排队的 FetchSlots 回调
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    _mockServerConn = nil  -- 无服务器连接

    local cbResult, cbError = nil, nil
    SaveSystemNet.FetchSlots(function(slots, err)
        cbResult = slots
        cbError = err
    end)
    -- 无连接 + 未 ready → 应入队
    assert_nil(cbResult, "T9a: queued FetchSlots callback not yet called")

    -- ClearQueue 应通知回调
    SaveSystemNet.ClearQueue()
    assert_nil(cbResult, "T9b: ClearQueue passes nil result")
    assert_match(cbError, "超时", "T9c: ClearQueue passes timeout error")
end

-- ─────────────────────────────────────────────────────────────
-- T10. 网络未就绪时 FetchSlots 入队，OnNetworkReady 后执行
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    _mockServerConn = nil  -- 无服务器连接

    local cbCalled = false
    SaveSystemNet.FetchSlots(function(slots, err)
        cbCalled = true
    end)
    assert_eq(cbCalled, false, "T10a: FetchSlots queued (not called)")

    -- 模拟连接建立
    _mockServerConn = createMockServerConn()

    -- OnNetworkReady 应执行排队的 FetchSlots
    SaveSystemNet.OnNetworkReady()
    -- 由于 FetchSlots 被重新调用且有连接，应发送 C2S 事件
    assert_eq(#_sentEvents, 1, "T10b: OnNetworkReady triggers queued FetchSlots → C2S sent")
end

-- ─────────────────────────────────────────────────────────────
-- T11. FetchSlots 正常流程：beginPending → S2C → resolvePending → callback
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    local cbSlots, cbErr = nil, nil

    SaveSystemNet.FetchSlots(function(slots, err)
        cbSlots = slots
        cbErr = err
    end)
    assert_eq(#_sentEvents, 1, "T11a: C2S_FetchSlots sent")

    -- 模拟服务端返回
    local ed = makeSlotsEventData(true, '{"slots":{"1":{"charName":"Hero"}}}', false)
    SaveSystemNet_HandleSlotsData("test", ed)

    assert_true(cbSlots ~= nil, "T11b: callback received slotsIndex")
    assert_nil(cbErr, "T11c: callback received no error")

    -- pending 应已清除
    local snapshot = SaveSystemNet._getPendingSnapshot()
    assert_nil(snapshot.fetchSlots, "T11d: pending cleared after resolve")
end

-- ─────────────────────────────────────────────────────────────
-- T12. Load 正常流程：beginPending → S2C → resolvePending → callback
-- ─────────────────────────────────────────────────────────────

do
    resetAll()
    local cbOk, cbMsg = nil, nil

    SaveSystemNet.Load(1, function(ok, msg)
        cbOk = ok
        cbMsg = msg
    end)
    assert_eq(#_sentEvents, 1, "T12a: C2S_LoadGame sent")

    -- 模拟服务端成功返回
    local saveData = '{"player":{"level":5},"equipment":{},"backpack":{}}'
    local ed = makeLoadEventData(true, saveData)
    SaveSystemNet_HandleLoadResult("test", ed)

    assert_eq(cbOk, true, "T12b: Load callback received success")

    local snapshot = SaveSystemNet._getPendingSnapshot()
    assert_nil(snapshot.load, "T12c: pending cleared after resolve")
end

-- ─────────────────────────────────────────────────────────────
-- 结果汇总
-- ─────────────────────────────────────────────────────────────

-- ============================================================================
-- 清理：恢复原始全局变量，避免影响后续测试
-- ============================================================================

-- 清除我们重新加载的 SaveSystemNet 模块缓存
package.loaded["network.SaveSystemNet"] = nil

-- 恢复全局变量
network = _origGlobals.network
cjson = _origGlobals.cjson
Variant = _origGlobals.Variant
VariantMap = _origGlobals.VariantMap
SubscribeToEvent = _origGlobals.SubscribeToEvent
GetPlatform = _origGlobals.GetPlatform
fileSystem = _origGlobals.fileSystem
clientCloud = _origGlobals.clientCloud
SaveSystemNet_HandleSlotsData = _origGlobals.SaveSystemNet_HandleSlotsData
SaveSystemNet_HandleLoadResult = _origGlobals.SaveSystemNet_HandleLoadResult
SaveSystemNet_HandleCharResult = _origGlobals.SaveSystemNet_HandleCharResult
SaveSystemNet_HandleMigrateResult = _origGlobals.SaveSystemNet_HandleMigrateResult
SaveSystemNet_HandleDelayedUpdate = _origGlobals.SaveSystemNet_HandleDelayedUpdate

print("\n[test_save_system_net_state_machine] " .. passed .. "/" .. totalTests .. " passed, "
    .. failed .. " failed\n")

return { passed = passed, failed = failed, total = totalTests }
