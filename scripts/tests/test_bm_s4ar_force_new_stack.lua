-- ============================================================================
-- test_bm_s4ar_force_new_stack.lua — BM-S4AR 强制分堆与 UI 提示测试
--
-- 验收标准（§7.1）：
--   1. 背包已有未锁同类消耗品 → 黑市买入 → 新锁堆独立、旧堆不变
--   2. 服务端 backpack 已有未锁同类 → 买入写回 → 新锁堆独立
--   3. 锁堆判定只命中锁堆，不误伤旧堆
--   4. CountUnlockedConsumable 混合状态计数正确
--   5. 消费/卖钱只允许扣未锁堆
--   6. 黑市面板文案存在
--
-- 纯 Lua 测试，无引擎依赖。
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

local function assertNotNil(v, msg)
    if v == nil then error(msg or "expected non-nil") end
end

print("\n[test_bm_s4ar_force_new_stack] === BM-S4AR 强制分堆测试 ===\n")

-- ============================================================================
-- Setup
-- ============================================================================

-- 清除缓存
local _stubModules = {
    "systems.BlackMarketTradeLock",
    "network.BackpackUtils",
}
local _origLoaded = {}
for _, k in ipairs(_stubModules) do
    _origLoaded[k] = package.loaded[k]
    package.loaded[k] = nil
end

local TradeLock = require("systems.BlackMarketTradeLock")
local BackpackUtils = require("network.BackpackUtils")

-- ============================================================================
-- A. 服务端 AddLockedNewStack 强制分堆
-- ============================================================================

print("  --- A. 服务端 AddLockedNewStack 强制分堆 ---")

test("A1: 背包已有未锁同类消耗品，AddLockedNewStack 创建独立锁堆", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "gold_brick", count = 9, name = "金砖" },
    }
    local batchId = "bm_test_001"
    local remaining = BackpackUtils.AddLockedNewStack(backpack, "gold_brick", 1, "金砖", batchId)

    -- 返回 0，表示全部放入
    assertEqual(remaining, 0, "remaining")
    -- 旧堆不变
    assertEqual(backpack["1"].count, 9, "old stack count")
    assertEqual(backpack["1"].bmLockUntil, nil, "old stack NOT locked")
    -- 新堆独立存在
    assertNotNil(backpack["2"], "new stack should exist")
    assertEqual(backpack["2"].consumableId, "gold_brick", "new stack consumableId")
    assertEqual(backpack["2"].count, 1, "new stack count")
    assertEqual(backpack["2"].bmLockSource, "black_market", "new stack lock source")
    assertEqual(backpack["2"].bmLockBatchId, batchId, "new stack batchId")
    assertNotNil(backpack["2"].bmLockUntil, "new stack lockUntil")
    assertTrue(backpack["2"].bmLockUntil > os.time(), "new stack lock in future")
end)

test("A2: AddLockedNewStack 不合并进旧未锁堆（旧堆数量 < MAX_STACK）", function()
    local backpack = {
        ["1"] = { category = "consumable", consumableId = "herb_01", count = 100, name = "灵草" },
    }
    local remaining = BackpackUtils.AddLockedNewStack(backpack, "herb_01", 50, "灵草", "bm_test_002")

    assertEqual(remaining, 0, "remaining")
    -- 旧堆完全不动
    assertEqual(backpack["1"].count, 100, "old stack untouched")
    assertFalse(TradeLock.IsLocked(backpack["1"]), "old stack not locked")
    -- 新堆独立
    assertNotNil(backpack["2"], "new stack exists")
    assertEqual(backpack["2"].count, 50, "new stack count")
    assertTrue(TradeLock.IsLocked(backpack["2"]), "new stack is locked")
end)

test("A3: AddLockedNewStack 大数量跨多堆（超 MAX_STACK 拆多堆）", function()
    local backpack = {}
    local total_amount = BackpackUtils.MAX_STACK + 100  -- 10099
    local remaining = BackpackUtils.AddLockedNewStack(backpack, "herb_01", total_amount, "灵草", "bm_test_003")

    assertEqual(remaining, 0, "remaining")
    -- 第一堆满
    assertNotNil(backpack["1"], "first stack")
    assertEqual(backpack["1"].count, BackpackUtils.MAX_STACK, "first stack = MAX_STACK")
    assertTrue(TradeLock.IsLocked(backpack["1"]), "first stack locked")
    -- 第二堆放余量
    assertNotNil(backpack["2"], "second stack")
    assertEqual(backpack["2"].count, 100, "second stack = overflow")
    assertTrue(TradeLock.IsLocked(backpack["2"]), "second stack locked")
    -- 两堆同批次
    assertEqual(backpack["1"].bmLockBatchId, "bm_test_003")
    assertEqual(backpack["2"].bmLockBatchId, "bm_test_003")
end)

test("A4: AddLockedNewStack 背包满 → 放不下返回剩余", function()
    local backpack = {}
    -- 填满所有 60 个槽位
    for i = 1, BackpackUtils.MAX_BACKPACK_SLOTS do
        backpack[tostring(i)] = {
            category = "consumable", consumableId = "junk", count = 1, name = "垃圾",
        }
    end
    local remaining = BackpackUtils.AddLockedNewStack(backpack, "gold_brick", 5, "金砖", "bm_test_004")
    assertEqual(remaining, 5, "all 5 remain because backpack is full")
end)

test("A5: AddLockedNewStack 不合并进其他批次的锁堆", function()
    local backpack = {
        ["1"] = {
            category = "consumable", consumableId = "herb_01", count = 10, name = "灵草",
            bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "old_batch",
        },
    }
    local remaining = BackpackUtils.AddLockedNewStack(backpack, "herb_01", 5, "灵草", "new_batch")

    assertEqual(remaining, 0, "remaining")
    -- 旧锁堆不动
    assertEqual(backpack["1"].count, 10, "old locked stack untouched")
    assertEqual(backpack["1"].bmLockBatchId, "old_batch")
    -- 新锁堆独立
    assertNotNil(backpack["2"], "new stack exists")
    assertEqual(backpack["2"].count, 5)
    assertEqual(backpack["2"].bmLockBatchId, "new_batch")
end)

-- ============================================================================
-- B. 锁状态判定精确性（不误伤旧堆）
-- ============================================================================

print("  --- B. 锁状态判定精确性 ---")

test("B1: 旧未锁堆不受锁判定影响", function()
    local oldItem = { category = "consumable", consumableId = "gold_brick", count = 9 }
    local newItem = {
        category = "consumable", consumableId = "gold_brick", count = 1,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "bm_123",
    }

    assertFalse(TradeLock.IsLocked(oldItem), "old item NOT locked")
    assertTrue(TradeLock.IsLocked(newItem), "new item IS locked")

    local blocked1, _ = TradeLock.IsOperationBlocked(oldItem)
    assertFalse(blocked1, "old item NOT blocked")
    local blocked2, _ = TradeLock.IsOperationBlocked(newItem)
    assertTrue(blocked2, "new item IS blocked")
end)

test("B2: 同 consumableId 未锁/锁 并存 → CanMerge = false", function()
    local unlocked = { consumableId = "gold_brick", count = 9 }
    local locked = {
        consumableId = "gold_brick", count = 1,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "bm_x",
    }
    assertFalse(TradeLock.CanMergeStacks(unlocked, locked), "should not merge")
    assertFalse(TradeLock.CanMergeStacks(locked, unlocked), "reverse should not merge")
end)

-- ============================================================================
-- C. CountUnlockedConsumable 混合状态计数
-- ============================================================================

print("  --- C. CountUnlockedConsumable 混合计数 ---")

test("C1: 混合锁/未锁堆 → 计数正确", function()
    local backpack = {
        { category = "consumable", consumableId = "gold_brick", count = 9 },  -- 未锁
        {
            category = "consumable", consumableId = "gold_brick", count = 1,
            bmLockUntil = os.time() + 300, bmLockSource = "black_market",
        },  -- 锁
        { category = "consumable", consumableId = "gold_brick", count = 5 },  -- 未锁
        { category = "consumable", consumableId = "herb_01", count = 20 },   -- 不同种
    }
    local unlocked, locked = TradeLock.CountUnlockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "gold_brick"
    )
    assertEqual(unlocked, 14, "unlocked = 9 + 5")
    assertEqual(locked, 1, "locked = 1")
end)

test("C2: 全部是新锁堆 → unlocked = 0", function()
    local backpack = {
        {
            category = "consumable", consumableId = "gold_brick", count = 3,
            bmLockUntil = os.time() + 300, bmLockSource = "black_market",
        },
    }
    local unlocked, locked = TradeLock.CountUnlockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "gold_brick"
    )
    assertEqual(unlocked, 0)
    assertEqual(locked, 3)
end)

-- ============================================================================
-- D. 消费/卖钱只走未锁堆（操作闸验证）
-- ============================================================================

print("  --- D. 操作闸隔离验证 ---")

test("D1: IsOperationBlocked 对未锁堆返回 false", function()
    local unlocked = { category = "consumable", consumableId = "gold_brick", count = 9 }
    local blocked, _ = TradeLock.IsOperationBlocked(unlocked)
    assertFalse(blocked)
end)

test("D2: IsOperationBlocked 对锁堆返回 true + 提示", function()
    local locked = {
        category = "consumable", consumableId = "gold_brick", count = 1,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market",
    }
    local blocked, reason = TradeLock.IsOperationBlocked(locked)
    assertTrue(blocked)
    assertTrue(type(reason) == "string" and #reason > 0, "reason non-empty")
end)

test("D3: IsOperationBlocked 锁过期后返回 false", function()
    local expired = {
        category = "consumable", consumableId = "gold_brick", count = 1,
        bmLockUntil = os.time() - 10, bmLockSource = "black_market",
    }
    local blocked, _ = TradeLock.IsOperationBlocked(expired)
    assertFalse(blocked)
end)

-- ============================================================================
-- E. 服务端锁堆独立写回
-- ============================================================================

print("  --- E. 服务端写回验证 ---")

test("E1: 服务端 saveData 已有未锁同类，买入后新锁堆独立", function()
    -- 模拟 HandleBuy 的核心写入逻辑
    local backpack = {
        ["3"] = { category = "consumable", consumableId = "herb_01", count = 50, name = "灵草" },
        ["5"] = { category = "consumable", consumableId = "gold_brick", count = 9, name = "金砖" },
    }
    local batchId = TradeLock.GenerateBatchId()
    local remaining = BackpackUtils.AddLockedNewStack(backpack, "gold_brick", 2, "金砖", batchId)

    assertEqual(remaining, 0)
    -- 旧 gold_brick 不变
    assertEqual(backpack["5"].count, 9)
    assertFalse(TradeLock.IsLockedServerSide(backpack["5"]))
    -- 新堆在空位创建
    local found = false
    for k, v in pairs(backpack) do
        if k ~= "3" and k ~= "5" and v.consumableId == "gold_brick" then
            assertEqual(v.count, 2)
            assertTrue(TradeLock.IsLockedServerSide(v), "new stack locked server side")
            assertEqual(v.bmLockBatchId, batchId)
            found = true
        end
    end
    assertTrue(found, "new locked stack should be found in backpack")
end)

test("E2: 服务端 IsLockedServerSide 只命中锁堆", function()
    local unlocked = { consumableId = "gold_brick", count = 9 }
    local locked = {
        consumableId = "gold_brick", count = 1,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market",
    }
    assertFalse(TradeLock.IsLockedServerSide(unlocked))
    assertTrue(TradeLock.IsLockedServerSide(locked))
end)

-- ============================================================================
-- F. UI 提示文案存在性
-- ============================================================================

print("  --- F. UI 提示文案验证 ---")

test("F1: BlackMerchantUI.lua 包含 NPC 面板常驻保护提示", function()
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then
        -- 纯 lua 环境可能无法直接打开，尝试 package 方式
        f = io.open("./scripts/ui/BlackMerchantUI.lua", "r")
    end
    assertNotNil(f, "BlackMerchantUI.lua should be readable")
    local content = f:read("*a")
    f:close()
    -- 验证常驻提示关键词
    assertTrue(content:find("保护期") ~= nil, "should contain '保护期'")
    assertTrue(content:find("不可使用") ~= nil or content:find("不可使用/出售") ~= nil
        or content:find("锁定保护") ~= nil, "should contain usage restriction")
end)

test("F2: BlackMerchantUI.lua 包含买入确认弹窗保护提醒", function()
    local f = io.open("scripts/ui/BlackMerchantUI.lua", "r")
    if not f then
        f = io.open("./scripts/ui/BlackMerchantUI.lua", "r")
    end
    assertNotNil(f, "BlackMerchantUI.lua should be readable")
    local content = f:read("*a")
    f:close()
    -- 验证二次提示关键词
    assertTrue(content:find("独立存放") ~= nil, "should contain '独立存放'")
    assertTrue(content:find("存档成功") ~= nil, "should contain '存档成功'")
end)

test("F3: ImageItemSlot.lua 包含锁图标渲染逻辑", function()
    local f = io.open("scripts/ui/ImageItemSlot.lua", "r")
    if not f then
        f = io.open("./scripts/ui/ImageItemSlot.lua", "r")
    end
    assertNotNil(f, "ImageItemSlot.lua should be readable")
    local content = f:read("*a")
    f:close()
    -- 验证锁图标逻辑
    assertTrue(content:find("lockOverlay_") ~= nil, "should contain lockOverlay_")
    assertTrue(content:find("TradeLock%.IsLocked") ~= nil or content:find("TradeLock.IsLocked") ~= nil,
        "should reference TradeLock.IsLocked")
end)

test("F4: BackpackUtils.AddLockedNewStack 函数存在", function()
    assertTrue(type(BackpackUtils.AddLockedNewStack) == "function",
        "BackpackUtils.AddLockedNewStack should be a function")
end)

-- ============================================================================
-- Cleanup
-- ============================================================================

for _, k in ipairs(_stubModules) do
    package.loaded[k] = _origLoaded[k]
end

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format(
    "\n[test_bm_s4ar_force_new_stack] TOTAL: %d  PASSED: %d  FAILED: %d\n",
    total, passed, failed
))

return { passed = passed, failed = failed, total = total }
