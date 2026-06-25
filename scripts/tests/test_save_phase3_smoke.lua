---@diagnostic disable
-- ============================================================================
-- test_save_phase3_smoke.lua — Phase 3 黑市高峰承载 结构性验烟
--
-- 验证 WP-05 各子项的结构保证（源码断言 + 变量存在性），防 revert 回归。
--   T1. BlackMerchantUI 订阅了 S2C_RateLimited（WP-05a）
--   T2. HandleRateLimited 有 EventName 黑市事件过滤
--   T3. _lastFlushTime 冷却变量存在（WP-05b）
--   T4. itemSellLock_ per-item 锁变量存在（WP-05c）
--   T5. 出售成功路径不含 save_request（WP-05d 源码断言）
--   T6. 失败后 SendQuery 改为延迟轮询（WP-05f 源码断言）
--
-- 纯结构+源码读取测试，无副作用。
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

print("\n[test_save_phase3_smoke] === Phase 3 黑市高峰承载 验烟 ===\n")

-- T1: BlackMerchantUI 订阅了 S2C_RateLimited
test("T1. BlackMerchantUI 订阅 S2C_RateLimited（WP-05a）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    assertTrue(src:find("S2C_RateLimited") ~= nil,
        "BlackMerchantUI 应订阅 S2C_RateLimited")
    assertTrue(src:find("BlackMerchantUI_HandleRateLimited") ~= nil,
        "应有 HandleRateLimited 处理函数")
end)

-- T2: HandleRateLimited 有 EventName 过滤
test("T2. HandleRateLimited 有 EventName 黑市事件过滤（防误释放）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    local handler = src:match("function BlackMerchantUI_HandleRateLimited.-(end)")
    assertTrue(handler ~= nil, "应能提取 HandleRateLimited 函数体")
    assertTrue(handler:find("EventName") ~= nil,
        "HandleRateLimited 应检查 EventName")
    assertTrue(handler:find("BlackMerchant") ~= nil,
        "应过滤 BlackMerchant 前缀事件")
end)

-- T3: _lastFlushTime 冷却变量
test("T3. _lastFlushTime 冷却变量存在（WP-05b）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    assertTrue(src:find("_lastFlushTime") ~= nil,
        "应有 _lastFlushTime 冷却变量")
    -- 确认冷却逻辑存在
    assertTrue(src:find("os%.clock%(%)" .. ".-" .. "_lastFlushTime") ~= nil
        or src:find("_lastFlushTime.-os%.clock") ~= nil,
        "应有 os.clock 与 _lastFlushTime 的冷却比较逻辑")
end)

-- T4: itemSellLock_ per-item 锁
test("T4. itemSellLock_ per-item 短锁存在（WP-05c）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/network/BlackMerchantHandler.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    assertTrue(src:find("itemSellLock_") ~= nil,
        "应有 itemSellLock_ per-item 锁变量")
    assertTrue(src:find("ITEM_LOCK_TTL") ~= nil,
        "应有 TTL 超时常量防死锁")
end)

-- T5: 出售成功路径不含 save_request（WP-05d）
test("T5. 出售成功路径不含 save_request（WP-05d 源码断言）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    -- 查找 sell 成功后的 localDeductOk 块：应NOT含 save_request
    local sellOkBlock = src:match("if localDeductOk then(.-)\n        else")
    assertTrue(sellOkBlock ~= nil, "应能提取 sell 成功 localDeductOk 块")
    assertFalse(sellOkBlock:find("save_request"),
        "出售成功 localDeductOk 块不应含 save_request（WP-05d 已移除）")
end)

-- T6: 失败后 SendQuery 改为延迟轮询（非立即调用）
test("T6. 交易失败后无立即 SendQuery（WP-05f 延迟轮询）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    -- HandleBMResult failure 块不应有直接 SendQuery() 调用
    local failBlock = src:match("if not ok then(.-)\n    end\n\n    local action")
    assertTrue(failBlock ~= nil, "应能提取 HandleBMResult failure 块")
    assertFalse(failBlock:find("SendQuery"),
        "failure 块不应立即调 SendQuery（WP-05f: 改为延迟轮询 pollTimer_）")
    assertTrue(failBlock:find("POLL_INTERVAL") ~= nil,
        "failure 块应设 pollTimer_ 为延迟值")
end)

print("\n[test_save_phase3_smoke] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
