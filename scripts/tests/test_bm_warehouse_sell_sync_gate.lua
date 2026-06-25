---@diagnostic disable
-- ============================================================================
-- test_bm_warehouse_sell_sync_gate.lua — P0 仓库出售门禁验烟
--
-- 验证：
--   T1. 仓库 dirty 下黑市出售被拦，且 code == "warehouse_unsync"
--   T2. game_saved 后门禁解除
--   T3. 消耗 dirty 返回 code == "consume_unsync"
--   T4. BlackMerchantUI 含精确仓库文案（P0-1 源码断言）
--   T5. BlackMerchantUI 不再只使用泛化文案（P0-1 源码断言）
--   T6. GetSellBlockReason 返回正确的 detail 格式
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
local function assertEqual(a, b, msg)
    if a ~= b then error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a)) end
end

print("\n[test_bm_warehouse_sell_sync_gate] === P0 仓库出售门禁验烟 ===\n")

-- T1: 仓库 dirty 下出售被拦
test("T1. 仓库 dirty 下 GetSellBlockReason 返回 global_unsync + warehouse_unsync", function()
    local BMS = require("systems.BlackMarketSyncState")
    -- 确保干净状态
    BMS.ClearAll()
    local r1, d1 = BMS.GetSellBlockReason("gold_brick")
    assertEqual(r1, "none", "清除后应返回 none")

    -- 标记仓库脏
    BMS.MarkWarehouseOp("store")
    local r2, d2 = BMS.GetSellBlockReason("gold_brick")
    assertEqual(r2, "global_unsync", "仓库脏应返回 global_unsync")
    assertTrue(d2 and d2:find("warehouse_unsync") ~= nil,
        "detail 应含 warehouse_unsync, got: " .. tostring(d2))

    -- 清理
    BMS.ClearAll()
end)

-- T2: game_saved 后门禁解除
test("T2. game_saved 后 GetSellBlockReason 返回 none", function()
    local BMS = require("systems.BlackMarketSyncState")
    BMS.MarkWarehouseOp("retrieve")
    local r1 = BMS.GetSellBlockReason("gold_brick")
    assertEqual(r1, "global_unsync", "仓库脏时应被拦")

    -- 模拟 game_saved
    BMS.ClearAll()
    local r2 = BMS.GetSellBlockReason("gold_brick")
    assertEqual(r2, "none", "ClearAll 后应解除门禁")
end)

-- T3: 消耗 dirty 返回 consume_unsync
test("T3. 消耗 dirty 返回 consume_unsync", function()
    local BMS = require("systems.BlackMarketSyncState")
    BMS.ClearAll()

    BMS.MarkConsumeUsed("bm_test_dummy_item")
    local r, d = BMS.GetSellBlockReason("gold_brick")
    assertEqual(r, "global_unsync", "消耗脏应返回 global_unsync")
    assertTrue(d and d:find("consume_unsync") ~= nil,
        "detail 应含 consume_unsync, got: " .. tostring(d))

    BMS.ClearAll()
end)

-- T4: BlackMerchantUI 含精确仓库文案（源码断言）
test("T4. BlackMerchantUI 含精确仓库文案（P0-1）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    assertTrue(src:find("仓库道具变更尚未完成存档，暂不能出售") ~= nil,
        "应含仓库精确文案")
    assertTrue(src:find("道具消耗尚未完成存档，暂不能出售") ~= nil,
        "应含消耗精确文案")
    assertTrue(src:find("近期操作正在保存，暂不能出售") ~= nil,
        "应含 save_session 精确文案")
end)

-- T5: 不再只使用泛化文案
test("T5. 泛化文案已移除（P0-1 替换）", function()
    if not (io and io.open) then print("    (skip) 无 io"); return end
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then print("    (skip) 源码不可读"); return end
    local src = f:read("*a"); f:close()
    -- "数据同步中，请稍后再出售" 应该不再作为 SetStatus 直接使用
    -- 搜索 SetStatus("数据同步中 模式
    local oldPattern = 'SetStatus%("数据同步中，请稍后再出售"'
    assertFalse(src:find(oldPattern),
        "不应再直接使用泛化文案 '数据同步中，请稍后再出售'")
end)

-- T6: detail 格式包含 L2: 前缀
test("T6. GetSellBlockReason detail 含 L2: 前缀", function()
    local BMS = require("systems.BlackMarketSyncState")
    BMS.ClearAll()
    BMS.MarkWarehouseOp("sort")
    local _, d = BMS.GetSellBlockReason("gold_brick")
    assertTrue(d and d:find("^L2:") ~= nil,
        "detail 应以 L2: 开头, got: " .. tostring(d))
    BMS.ClearAll()
end)

print("\n[test_bm_warehouse_sell_sync_gate] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
