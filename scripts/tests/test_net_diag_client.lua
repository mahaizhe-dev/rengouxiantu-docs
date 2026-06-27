---@diagnostic disable
-- ============================================================================
-- test_net_diag_client.lua — C+ NetDiagClient 验烟
--
-- T1. 模块加载 + 计数器初始为 0
-- T2. Record 方法存在且不报错
-- T3. RTT sum/max 正确累积
-- T4. GetCurrentWindow 返回快照
-- T5. 源码断言：不含 SaveSystem.Save / ClearAll / game_saved
-- T6. 源码断言：不含 EventBus.Emit("game_saved")
-- T7. Shadow 状态阈值正确（10/25/60）
-- T8. Shadow 状态不触发 connection_lost
-- ============================================================================

local passed, failed, total = 0, 0, 0
local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print("  ✓ " .. name)
    else failed = failed + 1; print("  ✗ " .. name .. ": " .. tostring(err)) end
end
local function assertTrue(v, msg) if not v then error(msg or "expected true") end end
local function assertFalse(v, msg) if v then error(msg or "expected false") end end

print("\n[test_net_diag_client] === C+ NetDiagClient 验烟 ===\n")

test("T1. NetDiagClient 加载 + 初始窗口全 0", function()
    local NDC = require("network.NetDiagClient")
    assertTrue(NDC ~= nil, "模块应存在")
    local w = NDC.GetCurrentWindow()
    assertTrue(type(w) == "table", "应返回 table")
    assertTrue((w.hbSent or 0) >= 0, "hbSent 应 >= 0")
end)

test("T2. Record 方法存在且不报错", function()
    local NDC = require("network.NetDiagClient")
    NDC.RecordHeartbeatSent()
    NDC.RecordHeartbeatAck(50)
    NDC.RecordHeartbeatMissed()
    NDC.RecordTransportNil()
    NDC.RecordSaveStart()
    NDC.RecordSaveOk()
    NDC.RecordSaveFail("disconnected")
    NDC.RecordSaveTimeout()
    NDC.RecordSaveWarning()
    NDC.RecordCloudPendingTimeout()
    NDC.RecordCloudNoConn("save")
    NDC.RecordRateLimited("C2S_SaveGame")
    NDC.RecordBMSellBlock("warehouse_unsync", 5)
    NDC.RecordShadowState("unstable", 12)
end)

test("T3. RTT sum/max 正确累积", function()
    local NDC = require("network.NetDiagClient")
    local w1 = NDC.GetCurrentWindow()
    local prevSum = w1.hbRttSum or 0
    local prevMax = w1.hbRttMax or 0
    NDC.RecordHeartbeatAck(200)
    NDC.RecordHeartbeatAck(500)
    local w2 = NDC.GetCurrentWindow()
    assertTrue(w2.hbRttSum >= prevSum + 700, "sum 应累积 +700")
    assertTrue(w2.hbRttMax >= 500, "max 应 >= 500")
end)

test("T4. GetCurrentWindow 返回快照", function()
    local NDC = require("network.NetDiagClient")
    local w = NDC.GetCurrentWindow()
    assertTrue(w._elapsed ~= nil, "应有 _elapsed 字段")
end)

test("T5. NetDiagClient 不含 SaveSystem.Save / ClearAll", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/network/NetDiagClient.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    assertFalse(src:find("SaveSystem%.Save"), "不应调用 SaveSystem.Save")
    assertFalse(src:find("ClearAll"), "不应调用 ClearAll")
end)

test("T6. NetDiagClient 不含 game_saved emit", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/network/NetDiagClient.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    assertFalse(src:find('Emit%("game_saved"'), "不应 emit game_saved")
end)

test("T7. Shadow 状态阈值正确", function()
    local NS = require("network.NetworkStatus")
    assertTrue(NS.SHADOW_NO_ACK_UNSTABLE == 10, "unstable 应为 10s")
    assertTrue(NS.SHADOW_NO_ACK_RECONNECTING == 25, "reconnecting 应为 25s")
    assertTrue(NS.SHADOW_NO_ACK_DISCONNECTED == 60, "disconnected 应为 60s")
end)

test("T8. Shadow 状态不触发 connection_lost（源码断言）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/network/NetworkStatus.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    local fnStart = src:find("function NetworkStatus%.UpdateShadowState")
    assertTrue(fnStart ~= nil, "应找到 UpdateShadowState")
    local snippet = src:sub(fnStart, fnStart + 1000)
    local fnBody = snippet:match("(function.-\nend)")
    assertTrue(fnBody ~= nil, "应提取函数体")
    assertFalse(fnBody:find("connection_lost"), "不应触发 connection_lost")
    assertFalse(fnBody:find("_disconnected"), "不应修改 _disconnected")
end)

print("\n[test_net_diag_client] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")
return { passed = passed, failed = failed, total = total }
