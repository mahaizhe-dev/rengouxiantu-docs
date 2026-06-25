---@diagnostic disable
-- ============================================================================
-- test_save_request_immediate_status.lua — P0 保存收口 API 验烟
--
-- 验证：
--   T1. SaveSystem.GetSaveStatus 存在且返回 table
--   T2. SaveSystem.RequestImmediateSave 存在且返回 3 值
--   T3. 未加载时 RequestImmediateSave 返回 not_loaded
--   T4. saving 时返回 saving
--   T5. _retryTimer 时返回 retrying
--   T6. _disconnected 时返回 disconnected
--   T7. 源码断言：RequestImmediateSave 调用 SaveSystem.Save()
--   T8. 源码断言：RequestImmediateSave 不含 game_saved
--   T9. 源码断言：RequestImmediateSave 不含 ClearAll
--   T10. 源码断言：WarehouseUI.Hide 调用 RequestImmediateSave
--   T11. 源码断言：BlackMerchantUI 含 RequestSaveForSellBlock
--   T12. 源码断言：RequestSaveForSellBlock 调用 RequestImmediateSave
--
-- 纯结构+状态测试，无网络副作用。
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
local function assertFalse(v, msg) if v then error(msg or "expected false") end end

print("\n[test_save_request_immediate_status] === P0 保存收口 API 验烟 ===\n")

local SaveSystem = require("systems.SaveSystem")

-- T1: GetSaveStatus 存在
test("T1. GetSaveStatus 存在且返回 table", function()
    assertTrue(type(SaveSystem.GetSaveStatus) == "function", "GetSaveStatus 应为函数")
    local st = SaveSystem.GetSaveStatus()
    assertTrue(type(st) == "table", "应返回 table")
    -- 检查关键字段存在
    assertTrue(st.loaded ~= nil, "应有 loaded 字段")
    assertTrue(st.saving ~= nil, "应有 saving 字段")
    assertTrue(st.disconnected ~= nil, "应有 disconnected 字段")
    assertTrue(st.hasServerConn ~= nil, "应有 hasServerConn 字段")
end)

-- T2: RequestImmediateSave 存在
test("T2. RequestImmediateSave 存在且返回 3 值", function()
    assertTrue(type(SaveSystem.RequestImmediateSave) == "function", "应为函数")
    -- 在测试环境中可能 not_loaded，但至少返回 3 值
    local ok, reason, status = SaveSystem.RequestImmediateSave("test")
    assertTrue(ok ~= nil or ok == false, "第一返回值应为 boolean")
    assertTrue(type(reason) == "string", "第二返回值应为 string")
    assertTrue(type(status) == "table", "第三返回值应为 table")
end)

-- T3: 未加载时返回 not_loaded
test("T3. 未加载时返回 not_loaded", function()
    local origLoaded = SaveSystem.loaded
    SaveSystem.loaded = false
    local ok, reason = SaveSystem.RequestImmediateSave("test_not_loaded")
    SaveSystem.loaded = origLoaded
    assertTrue(ok == false, "应返回 false")
    assertTrue(reason == "not_loaded", "原因应为 not_loaded, got: " .. tostring(reason))
end)

-- T4: saving 时返回 saving
test("T4. saving 时返回 saving", function()
    local origLoaded = SaveSystem.loaded
    local origSlot = SaveSystem.activeSlot
    local origSaving = SaveSystem.saving
    SaveSystem.loaded = true
    SaveSystem.activeSlot = 1
    SaveSystem.saving = true
    local ok, reason = SaveSystem.RequestImmediateSave("test_saving")
    SaveSystem.loaded = origLoaded
    SaveSystem.activeSlot = origSlot
    SaveSystem.saving = origSaving
    assertTrue(ok == false, "应返回 false")
    assertTrue(reason == "saving", "原因应为 saving, got: " .. tostring(reason))
end)

-- T5: retryTimer 时返回 retrying
test("T5. retryTimer 时返回 retrying", function()
    local origLoaded = SaveSystem.loaded
    local origSlot = SaveSystem.activeSlot
    local origSaving = SaveSystem.saving
    local origRetry = SaveSystem._retryTimer
    SaveSystem.loaded = true
    SaveSystem.activeSlot = 1
    SaveSystem.saving = false
    SaveSystem._retryTimer = 3.0
    local ok, reason = SaveSystem.RequestImmediateSave("test_retry")
    SaveSystem.loaded = origLoaded
    SaveSystem.activeSlot = origSlot
    SaveSystem.saving = origSaving
    SaveSystem._retryTimer = origRetry
    assertTrue(ok == false, "应返回 false")
    assertTrue(reason == "retrying", "原因应为 retrying, got: " .. tostring(reason))
end)

-- T6: disconnected 时返回 disconnected
test("T6. disconnected 时返回 disconnected", function()
    local origLoaded = SaveSystem.loaded
    local origSlot = SaveSystem.activeSlot
    local origSaving = SaveSystem.saving
    local origRetry = SaveSystem._retryTimer
    local origDisc = SaveSystem._disconnected
    SaveSystem.loaded = true
    SaveSystem.activeSlot = 1
    SaveSystem.saving = false
    SaveSystem._retryTimer = nil
    SaveSystem._disconnected = true
    local ok, reason = SaveSystem.RequestImmediateSave("test_disc")
    SaveSystem.loaded = origLoaded
    SaveSystem.activeSlot = origSlot
    SaveSystem.saving = origSaving
    SaveSystem._retryTimer = origRetry
    SaveSystem._disconnected = origDisc
    assertTrue(ok == false, "应返回 false")
    assertTrue(reason == "disconnected", "原因应为 disconnected, got: " .. tostring(reason))
end)

-- T7-T12: 源码断言
local function readSrc(path)
    if not (io and io.open) then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

test("T7. RequestImmediateSave 调用 SaveSystem.Save()", function()
    local src = readSrc("scripts/systems/SaveSystem.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local fnStart = src:find("function SaveSystem%.RequestImmediateSave")
    assertTrue(fnStart ~= nil, "应找到函数声明")
    local snippet = src:sub(fnStart, fnStart + 2000)
    assertTrue(snippet:find("SaveSystem%.Save%(%)") ~= nil, "应调用 SaveSystem.Save()")
end)

test("T8. RequestImmediateSave 不含 game_saved", function()
    local src = readSrc("scripts/systems/SaveSystem.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local fnStart = src:find("function SaveSystem%.RequestImmediateSave")
    assertTrue(fnStart ~= nil, "应找到函数声明")
    local snippet = src:sub(fnStart, fnStart + 2000)
    local fnBody = snippet:match("(function.-\nend)")
    assertTrue(fnBody ~= nil, "应提取函数体")
    assertFalse(fnBody:find("game_saved"), "不应含 game_saved")
end)

test("T9. RequestImmediateSave 不含 ClearAll", function()
    local src = readSrc("scripts/systems/SaveSystem.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local fnStart = src:find("function SaveSystem%.RequestImmediateSave")
    assertTrue(fnStart ~= nil, "应找到函数声明")
    local snippet = src:sub(fnStart, fnStart + 2000)
    local fnBody = snippet:match("(function.-\nend)")
    assertTrue(fnBody ~= nil, "应提取函数体")
    assertFalse(fnBody:find("ClearAll"), "不应含 ClearAll")
end)

test("T10. WarehouseUI.Hide 调用 RequestImmediateSave", function()
    local src = readSrc("scripts/ui/WarehouseUI.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local hideBody = src:match("function WarehouseUI%.Hide%(%)(.-)\nfunction")
        or src:match("function WarehouseUI%.Hide%(%)(.-)\nreturn")
    assertTrue(hideBody ~= nil, "应提取 Hide 函数体")
    assertTrue(hideBody:find("RequestImmediateSave") ~= nil,
        "Hide 应调用 RequestImmediateSave")
end)

test("T11. BlackMerchantUI 含 RequestSaveForSellBlock", function()
    local src = readSrc("scripts/ui/BlackMerchantUI.lua")
    if not src then print("    (skip) 源码不可读"); return end
    assertTrue(src:find("function RequestSaveForSellBlock") ~= nil
        or src:find("local function RequestSaveForSellBlock") ~= nil,
        "应有 RequestSaveForSellBlock 函数")
end)

test("T12. RequestSaveForSellBlock 调用 RequestImmediateSave", function()
    local src = readSrc("scripts/ui/BlackMerchantUI.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local fnStart = src:find("function RequestSaveForSellBlock")
    assertTrue(fnStart ~= nil, "应找到函数声明")
    local snippet = src:sub(fnStart, fnStart + 1500)
    assertTrue(snippet:find("RequestImmediateSave") ~= nil,
        "应调用 RequestImmediateSave")
end)

print("\n[test_save_request_immediate_status] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
