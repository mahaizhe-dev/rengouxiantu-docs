---@diagnostic disable
-- ============================================================================
-- test_bm_warehouse_close_flush.lua — P0 仓库关闭保存验烟
--
-- 验证：
--   T1. WarehouseUI 存在 changedThisOpen_ 变量
--   T2. warehouse_changed 事件会置变更标记（EventBus.On 订阅）
--   T3. WarehouseUI.Hide() 中有 save_request + SaveSession.Flush + SaveSystem.Save
--   T4. WarehouseUI.Hide() 中不出现 BlackMarketSyncState.ClearAll
--   T5. WarehouseUI.Hide() 中不出现 game_saved
--   T6. WarehouseUI.Show() 重置 changedThisOpen_
--   T7. BlackMerchantUI.Show() 含仓库互斥关闭逻辑（P0-4）
--
-- 纯源码静态断言，无副作用。
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

print("\n[test_bm_warehouse_close_flush] === P0 仓库关闭保存验烟 ===\n")

-- 读取 WarehouseUI 源码
local whSrc = nil
if io and io.open then
    local f = io.open("scripts/ui/WarehouseUI.lua", "r")
    if f then whSrc = f:read("*a"); f:close() end
end

-- 读取 BlackMerchantUI 源码
local bmSrc = nil
if io and io.open then
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if f then bmSrc = f:read("*a"); f:close() end
end

-- T1: changedThisOpen_ 存在
test("T1. WarehouseUI 存在 changedThisOpen_ 变量", function()
    if not whSrc then print("    (skip) 源码不可读"); return end
    assertTrue(whSrc:find("changedThisOpen_") ~= nil,
        "应有 changedThisOpen_ 变量")
end)

-- T2: warehouse_changed 事件订阅置变更标记
test("T2. warehouse_changed 事件订阅置 changedThisOpen_ = true", function()
    if not whSrc then print("    (skip) 源码不可读"); return end
    assertTrue(whSrc:find('warehouse_changed') ~= nil,
        "应订阅 warehouse_changed 事件")
    -- 确认在回调中设置标记
    assertTrue(whSrc:find("changedThisOpen_%s*=%s*true") ~= nil,
        "事件回调应置 changedThisOpen_ = true")
end)

-- T3: Hide() 中有保存三件套
test("T3. Hide() 含 save_request + SaveSession.Flush + SaveSystem.Save", function()
    if not whSrc then print("    (skip) 源码不可读"); return end
    -- 提取 Hide 函数体（从 function WarehouseUI.Hide() 到下一个顶层 function）
    local hideBody = whSrc:match("function WarehouseUI%.Hide%(%)(.-)\nfunction")
        or whSrc:match("function WarehouseUI%.Hide%(%)(.-)\nreturn")
    assertTrue(hideBody ~= nil, "应能提取 Hide 函数体")
    assertTrue(hideBody:find('save_request') ~= nil,
        "Hide 应含 save_request")
    assertTrue(hideBody:find('SaveSession') ~= nil,
        "Hide 应含 SaveSession.Flush")
    assertTrue(hideBody:find('SaveSystem') ~= nil,
        "Hide 应含 SaveSystem.Save")
end)

-- T4: Hide() 中不清 dirty
test("T4. Hide() 不含 BlackMarketSyncState.ClearAll", function()
    if not whSrc then print("    (skip) 源码不可读"); return end
    local hideBody = whSrc:match("function WarehouseUI%.Hide%(%)(.-)\nfunction")
        or whSrc:match("function WarehouseUI%.Hide%(%)(.-)\nreturn")
    assertTrue(hideBody ~= nil, "应能提取 Hide 函数体")
    assertFalse(hideBody:find("ClearAll"),
        "Hide 不应调用 ClearAll（禁止清 dirty）")
    assertFalse(hideBody:find("_dirtyWarehouse%s*=%s*false"),
        "Hide 不应直接清 _dirtyWarehouse")
end)

-- T5: Hide() 中不发 game_saved
test("T5. Hide() 不含 game_saved 事件发射", function()
    if not whSrc then print("    (skip) 源码不可读"); return end
    local hideBody = whSrc:match("function WarehouseUI%.Hide%(%)(.-)\nfunction")
        or whSrc:match("function WarehouseUI%.Hide%(%)(.-)\nreturn")
    assertTrue(hideBody ~= nil, "应能提取 Hide 函数体")
    assertFalse(hideBody:find("game_saved"),
        "Hide 不应发射 game_saved（只有真实保存成功才能发）")
end)

-- T6: Show() 重置标记
test("T6. Show() 重置 changedThisOpen_ = false", function()
    if not whSrc then print("    (skip) 源码不可读"); return end
    local showBody = whSrc:match("function WarehouseUI%.Show%(.-%)(.-)\nend")
    assertTrue(showBody ~= nil, "应能提取 Show 函数体")
    assertTrue(showBody:find("changedThisOpen_%s*=%s*false") ~= nil,
        "Show 应重置 changedThisOpen_ = false")
end)

-- T7: BlackMerchantUI.Show() 互斥关闭仓库（P0-4）
test("T7. BlackMerchantUI.Show() 含仓库互斥关闭逻辑（P0-4）", function()
    if not bmSrc then print("    (skip) 源码不可读"); return end
    -- 找 BlackMerchantUI.Show 函数范围
    local showStart = bmSrc:find("function BlackMerchantUI%.Show%(%)") or 0
    local showSnippet = bmSrc:sub(showStart, showStart + 1000)
    assertTrue(showSnippet:find("WarehouseUI") ~= nil,
        "BlackMerchantUI.Show 应引用 WarehouseUI")
    assertTrue(showSnippet:find("IsVisible") ~= nil,
        "应检查 WarehouseUI.IsVisible")
    assertTrue(showSnippet:find("Hide") ~= nil,
        "应调用 WarehouseUI.Hide()")
end)

print("\n[test_bm_warehouse_close_flush] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
