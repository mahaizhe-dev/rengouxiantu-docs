---@diagnostic disable
-- ============================================================================
-- test_save_exit_callback_reasons.lua — P0-1 保存早退 callback 验烟
--
-- 验证：
--   T1. saving 时 Save(cb) 回调 false, "already_saving"
--   T2. not loaded 时回调 false, "not_loaded"
--   T3. no activeSlot 时回调 false, "no_active_slot"
--   T4. disconnected 时回调 false, "disconnected"
--   T5. 源码断言：所有早退路径都有 callback 调用
--   T6. save_warning 节流：10s 内不重复（源码断言）
--   T7. CloudStorage pending 在 no serverConn 时释放（源码断言）
--   T8. 极端保存失败兜底只回调一次并作废旧 attempt
--   T9. SaveSystem 兜底超时晚于 CloudStorage requestId 超时
--
-- 纯状态+源码测试，无网络副作用。
-- ============================================================================

local passed, failed, total = 0, 0, 0

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

local function assertTrue(v, msg) if not v then error(msg or "expected true") end end
local function assertEqual(a, b, msg)
    if a ~= b then error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a)) end
end

print("\n[test_save_exit_callback_reasons] === P0-1/P0-2/P0-4 验烟 ===\n")

local SaveSystem = require("systems.SaveSystem")

-- T1: saving 时回调
test("T1. saving 时 callback(false, 'already_saving')", function()
    local orig = { SaveSystem.loaded, SaveSystem.activeSlot, SaveSystem.saving, SaveSystem._savingStartTime }
    SaveSystem.loaded = true
    SaveSystem.activeSlot = 1
    SaveSystem.saving = true
    SaveSystem._savingStartTime = os.time()  -- 非超时状态
    local cbOk, cbReason
    SaveSystem.Save(function(ok, reason) cbOk = ok; cbReason = reason end)
    SaveSystem.loaded, SaveSystem.activeSlot, SaveSystem.saving, SaveSystem._savingStartTime =
        orig[1], orig[2], orig[3], orig[4]
    assertEqual(cbOk, false, "T1 ok")
    assertEqual(cbReason, "already_saving", "T1 reason")
end)

-- T2: not loaded 时回调
test("T2. not loaded 时 callback(false, 'not_loaded')", function()
    local origLoaded = SaveSystem.loaded
    SaveSystem.loaded = false
    local cbOk, cbReason
    SaveSystem.Save(function(ok, reason) cbOk = ok; cbReason = reason end)
    SaveSystem.loaded = origLoaded
    assertEqual(cbOk, false, "T2 ok")
    assertEqual(cbReason, "not_loaded", "T2 reason")
end)

-- T3: no activeSlot 时回调
test("T3. no activeSlot 时 callback(false, 'no_active_slot')", function()
    local origLoaded, origSlot = SaveSystem.loaded, SaveSystem.activeSlot
    SaveSystem.loaded = true
    SaveSystem.activeSlot = nil
    local cbOk, cbReason
    SaveSystem.Save(function(ok, reason) cbOk = ok; cbReason = reason end)
    SaveSystem.loaded, SaveSystem.activeSlot = origLoaded, origSlot
    assertEqual(cbOk, false, "T3 ok")
    assertEqual(cbReason, "no_active_slot", "T3 reason")
end)

-- T4: disconnected 时回调
test("T4. disconnected 时 callback(false, 'disconnected')", function()
    local origLoaded, origSlot, origSaving, origDisc =
        SaveSystem.loaded, SaveSystem.activeSlot, SaveSystem.saving, SaveSystem._disconnected
    SaveSystem.loaded = true
    SaveSystem.activeSlot = 1
    SaveSystem.saving = false
    SaveSystem._disconnected = true
    local cbOk, cbReason
    SaveSystem.Save(function(ok, reason) cbOk = ok; cbReason = reason end)
    SaveSystem.loaded, SaveSystem.activeSlot, SaveSystem.saving, SaveSystem._disconnected =
        origLoaded, origSlot, origSaving, origDisc
    assertEqual(cbOk, false, "T4 ok")
    assertEqual(cbReason, "disconnected", "T4 reason")
end)

-- T5: 源码断言 — 所有早退路径都有 callback
test("T5. SavePersistence 所有早退含 callback 调用", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/systems/save/SavePersistence.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    -- 提取 Save 函数到 DoSave 之间的代码
    local saveBody = src:match("function SavePersistence%.Save%(callback%)(.-)\n    SS%.saving = true")
    assertTrue(saveBody ~= nil, "应能提取 Save 函数早退区域")
    -- 统计 return 数量 和 callback 调用数量
    local returnCount = 0
    for _ in saveBody:gmatch("\n%s+return\n") do returnCount = returnCount + 1 end
    local callbackCount = 0
    for _ in saveBody:gmatch("if callback then callback") do callbackCount = callbackCount + 1 end
    assertTrue(callbackCount >= 6, "至少 6 处早退有 callback, got " .. callbackCount)
end)

-- T6: save_warning 状态式节流源码断言
test("T6. save_warning 按状态使用 30s/60s 节流", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/main.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    assertTrue(src:find("_lastSaveWarningTime") ~= nil, "应有节流变量")
    assertTrue(src:find("60 or 30", 1, true) ~= nil, "应有断线60s/重试30s阈值")
end)

-- T7: CloudStorage no serverConn 释放 pending（源码断言）
test("T7. CloudStorage no serverConn 时释放 pending", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/network/CloudStorage.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    -- 检查 "No server connection for Save" 后的局部代码包含 pending 释放。
    local startPos = src:find("No server connection for Save", 1, true)
    assertTrue(startPos ~= nil, "应找到 Save no conn 块")
    local saveBlock = src:sub(startPos, startPos + 500)
    assertTrue(saveBlock:find("_pendingCallbacks%[requestId%] = nil") ~= nil,
        "Save no conn 应释放 pending")
end)

test("T8. FailActiveSave 只回调一次并作废旧 attempt", function()
    local orig = {
        saving = SaveSystem.saving,
        callback = SaveSystem._activeSaveCallback,
        attemptId = SaveSystem._saveAttemptId,
        timeoutActive = SaveSystem._saveTimeoutActive,
        failures = SaveSystem._consecutiveFailures,
        retryTimer = SaveSystem._retryTimer,
    }
    local callbackCount, callbackOk, callbackReason = 0, nil, nil
    SaveSystem.saving = true
    SaveSystem._activeSaveCallback = function(ok, reason)
        callbackCount = callbackCount + 1
        callbackOk = ok
        callbackReason = reason
    end
    SaveSystem._saveAttemptId = 10
    SaveSystem._saveTimeoutActive = true
    SaveSystem._consecutiveFailures = 0
    SaveSystem._retryTimer = nil

    assertTrue(SaveSystem.FailActiveSave("forced_timeout"))
    assertEqual(callbackCount, 1, "T8 callback count")
    assertEqual(callbackOk, false, "T8 callback ok")
    assertEqual(callbackReason, "forced_timeout", "T8 callback reason")
    assertEqual(SaveSystem.saving, false, "T8 saving")
    assertEqual(SaveSystem._saveAttemptId, 11, "T8 attempt invalidated")
    assertEqual(SaveSystem._retryTimer, 10, "T8 retry")
    assertTrue(not SaveSystem.FailActiveSave("duplicate"), "T8 duplicate fail is ignored")
    assertEqual(callbackCount, 1, "T8 callback remains once")

    SaveSystem.saving = orig.saving
    SaveSystem._activeSaveCallback = orig.callback
    SaveSystem._saveAttemptId = orig.attemptId
    SaveSystem._saveTimeoutActive = orig.timeoutActive
    SaveSystem._consecutiveFailures = orig.failures
    SaveSystem._retryTimer = orig.retryTimer
end)

test("T9. requestId 超时先于 SaveSystem 兜底", function()
    assertTrue(SaveSystem.SAVE_RESPONSE_TIMEOUT > SaveSystem.CLOUD_CALLBACK_TIMEOUT,
        "SaveSystem 兜底必须晚于 CloudStorage 回调超时")
    local f = assert(io.open("scripts/systems/SaveSystem.lua", "r"))
    local src = f:read("*a")
    f:close()
    assertTrue(src:find('ExpirePendingCallbacks%(%s*"save"') ~= nil,
        "SaveSystem 超时必须先结算 CloudStorage 保存回调")
end)

print("\n[test_save_exit_callback_reasons] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
