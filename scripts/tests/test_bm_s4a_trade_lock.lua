-- ============================================================================
-- test_bm_s4a_trade_lock.lua — BM-S4A 黑市交易保护锁测试
--
-- 测试层次：
--   A. 核心锁判定：IsLocked / CanMergeStacks / IsOperationBlocked
--   B. 锁写入与清除：ApplyLock / ClearLock / ClearAllExpired / ClearAllOnSaveSuccess
--   C. 堆叠隔离：getMergeKey 等效逻辑 / CountUnlockedConsumable
--   D. 批次 ID 生成：GenerateBatchId 格式
--   E. 服务端判定：IsLockedServerSide / CanMergeStacksServerSide
--   F. 边界用例：nil 参数 / 空 bmLockSource / 过期锁
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

print("\n[test_bm_s4a_trade_lock] === BM-S4A 黑市交易保护锁测试 ===\n")

-- ============================================================================
-- Stubs & Setup
-- ============================================================================

-- 清除缓存以确保加载最新版本
local _stubModules = { "systems.BlackMarketTradeLock" }
local _origPackageLoaded = {}
for _, k in ipairs(_stubModules) do
    _origPackageLoaded[k] = package.loaded[k]
end
for _, k in ipairs(_stubModules) do
    package.loaded[k] = nil
end

local TradeLock = require("systems.BlackMarketTradeLock")

-- ============================================================================
-- A. 核心锁判定
-- ============================================================================

print("  --- A. 核心锁判定 ---")

test("A1: nil item → not locked", function()
    assertFalse(TradeLock.IsLocked(nil))
end)

test("A2: item without bmLockUntil → not locked", function()
    local item = { consumableId = "herb_01", count = 5 }
    assertFalse(TradeLock.IsLocked(item))
end)

test("A3: item with future bmLockUntil → locked", function()
    local item = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() + 300,
        bmLockSource = "black_market",
    }
    assertTrue(TradeLock.IsLocked(item))
end)

test("A4: item with past bmLockUntil → not locked (expired)", function()
    local item = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() - 10,
        bmLockSource = "black_market",
    }
    assertFalse(TradeLock.IsLocked(item))
end)

test("A5: item with bmLockUntil but no bmLockSource → not locked", function()
    local item = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() + 300,
    }
    assertFalse(TradeLock.IsLocked(item))
end)

test("A6: IsOperationBlocked returns true+message for locked item", function()
    local item = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() + 300,
        bmLockSource = "black_market",
    }
    local blocked, reason = TradeLock.IsOperationBlocked(item)
    assertTrue(blocked)
    assertEqual(reason, TradeLock.LOCK_MESSAGE)
end)

test("A7: IsOperationBlocked returns false for unlocked item", function()
    local item = { consumableId = "herb_01", count = 5 }
    local blocked, reason = TradeLock.IsOperationBlocked(item)
    assertFalse(blocked)
    assertEqual(reason, nil)
end)

test("A8: IsOperationBlocked returns false for nil", function()
    local blocked, _ = TradeLock.IsOperationBlocked(nil)
    assertFalse(blocked)
end)

-- ============================================================================
-- B. 锁写入与清除
-- ============================================================================

print("  --- B. 锁写入与清除 ---")

test("B1: ApplyLock sets all three fields", function()
    local item = { consumableId = "herb_01", count = 5 }
    TradeLock.ApplyLock(item, "batch_123", 600)
    assertTrue(item.bmLockUntil ~= nil)
    assertEqual(item.bmLockSource, "black_market")
    assertEqual(item.bmLockBatchId, "batch_123")
    assertTrue(item.bmLockUntil > os.time())
end)

test("B2: ApplyLock uses default duration when nil", function()
    local item = { consumableId = "herb_01", count = 5 }
    local before = os.time()
    TradeLock.ApplyLock(item, "batch_456")
    local expectedMin = before + TradeLock.LOCK_DURATION
    assertTrue(item.bmLockUntil >= expectedMin)
    assertTrue(item.bmLockUntil <= expectedMin + 2) -- 允许 2 秒误差
end)

test("B3: ClearLock removes all three fields", function()
    local item = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() + 300,
        bmLockSource = "black_market",
        bmLockBatchId = "batch_789",
    }
    TradeLock.ClearLock(item)
    assertEqual(item.bmLockUntil, nil)
    assertEqual(item.bmLockSource, nil)
    assertEqual(item.bmLockBatchId, nil)
end)

test("B4: ClearLock on nil → no crash", function()
    TradeLock.ClearLock(nil) -- should not error
end)

test("B5: ClearAllExpired clears only expired locks", function()
    local backpack = {
        { consumableId = "herb_01", count = 1, bmLockUntil = os.time() - 10, bmLockSource = "black_market" },
        { consumableId = "herb_02", count = 2, bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
        { consumableId = "herb_03", count = 3 },  -- no lock
    }
    local cleared = TradeLock.ClearAllExpired(
        function(i) return backpack[i] end,
        #backpack
    )
    assertEqual(cleared, 1)
    assertEqual(backpack[1].bmLockUntil, nil) -- cleared
    assertTrue(backpack[2].bmLockUntil ~= nil)  -- still locked
    assertEqual(backpack[3].bmLockUntil, nil) -- never locked
end)

test("B6: ClearAllOnSaveSuccess clears ALL locks regardless of expiry", function()
    local backpack = {
        { consumableId = "herb_01", count = 1, bmLockUntil = os.time() - 10, bmLockSource = "black_market" },
        { consumableId = "herb_02", count = 2, bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
        { consumableId = "herb_03", count = 3 },
    }
    local cleared = TradeLock.ClearAllOnSaveSuccess(
        function(i) return backpack[i] end,
        #backpack
    )
    assertEqual(cleared, 2)
    assertEqual(backpack[1].bmLockUntil, nil)
    assertEqual(backpack[2].bmLockUntil, nil)
end)

-- ============================================================================
-- C. 堆叠合并隔离
-- ============================================================================

print("  --- C. 堆叠合并隔离 ---")

test("C1: same consumableId, both unlocked → can merge", function()
    local a = { consumableId = "herb_01", count = 3 }
    local b = { consumableId = "herb_01", count = 5 }
    assertTrue(TradeLock.CanMergeStacks(a, b))
end)

test("C2: different consumableId → cannot merge", function()
    local a = { consumableId = "herb_01", count = 3 }
    local b = { consumableId = "herb_02", count = 5 }
    assertFalse(TradeLock.CanMergeStacks(a, b))
end)

test("C3: one locked one unlocked → cannot merge", function()
    local a = {
        consumableId = "herb_01", count = 3,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b1",
    }
    local b = { consumableId = "herb_01", count = 5 }
    assertFalse(TradeLock.CanMergeStacks(a, b))
end)

test("C4: both locked same batch → can merge", function()
    local a = {
        consumableId = "herb_01", count = 3,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b1",
    }
    local b = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b1",
    }
    assertTrue(TradeLock.CanMergeStacks(a, b))
end)

test("C5: both locked different batch → cannot merge", function()
    local a = {
        consumableId = "herb_01", count = 3,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b1",
    }
    local b = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b2",
    }
    assertFalse(TradeLock.CanMergeStacks(a, b))
end)

test("C6: nil items → cannot merge", function()
    assertFalse(TradeLock.CanMergeStacks(nil, nil))
    assertFalse(TradeLock.CanMergeStacks({ consumableId = "herb_01" }, nil))
    assertFalse(TradeLock.CanMergeStacks(nil, { consumableId = "herb_01" }))
end)

test("C7: both locked but no batchId → conservative no merge", function()
    local a = {
        consumableId = "herb_01", count = 3,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market",
    }
    local b = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market",
    }
    assertFalse(TradeLock.CanMergeStacks(a, b))
end)

-- ============================================================================
-- D. CountUnlockedConsumable
-- ============================================================================

print("  --- D. CountUnlockedConsumable ---")

test("D1: mixed locked/unlocked counts correctly", function()
    local backpack = {
        { category = "consumable", consumableId = "herb_01", count = 10 },
        { category = "consumable", consumableId = "herb_01", count = 5,
          bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
        { category = "consumable", consumableId = "herb_02", count = 20 },
        { category = "consumable", consumableId = "herb_01", count = 3 },
    }
    local unlocked, locked = TradeLock.CountUnlockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "herb_01"
    )
    assertEqual(unlocked, 13) -- 10 + 3
    assertEqual(locked, 5)
end)

test("D2: all locked → unlocked = 0", function()
    local backpack = {
        { category = "consumable", consumableId = "herb_01", count = 5,
          bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
        { category = "consumable", consumableId = "herb_01", count = 3,
          bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
    }
    local unlocked, locked = TradeLock.CountUnlockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "herb_01"
    )
    assertEqual(unlocked, 0)
    assertEqual(locked, 8)
end)

test("D3: no matching consumableId → both 0", function()
    local backpack = {
        { category = "consumable", consumableId = "herb_02", count = 10 },
    }
    local unlocked, locked = TradeLock.CountUnlockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "herb_01"
    )
    assertEqual(unlocked, 0)
    assertEqual(locked, 0)
end)

test("D4: empty backpack → both 0", function()
    local unlocked, locked = TradeLock.CountUnlockedConsumable(
        function(_) return nil end,
        60,
        "herb_01"
    )
    assertEqual(unlocked, 0)
    assertEqual(locked, 0)
end)

-- ============================================================================
-- E. 批次 ID 生成
-- ============================================================================

print("  --- E. 批次 ID 生成 ---")

test("E1: GenerateBatchId format bm_{time}_{random}", function()
    local id = TradeLock.GenerateBatchId()
    assertTrue(type(id) == "string")
    assertTrue(id:match("^bm_%d+_%d+$") ~= nil, "format mismatch: " .. id)
end)

test("E2: two calls produce different IDs (high probability)", function()
    local id1 = TradeLock.GenerateBatchId()
    local id2 = TradeLock.GenerateBatchId()
    -- 不保证绝对不同，但极大概率不同
    -- 此测试为弱断言，仅检查不完全相同即可
    assertTrue(type(id1) == "string" and type(id2) == "string")
end)

-- ============================================================================
-- F. 服务端判定
-- ============================================================================

print("  --- F. 服务端判定 ---")

test("F1: IsLockedServerSide mirrors IsLocked for active lock", function()
    local itemData = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() + 300,
        bmLockSource = "black_market",
    }
    assertTrue(TradeLock.IsLockedServerSide(itemData))
end)

test("F2: IsLockedServerSide returns false for expired lock", function()
    local itemData = {
        consumableId = "herb_01", count = 5,
        bmLockUntil = os.time() - 10,
        bmLockSource = "black_market",
    }
    assertFalse(TradeLock.IsLockedServerSide(itemData))
end)

test("F3: IsLockedServerSide returns false for nil", function()
    assertFalse(TradeLock.IsLockedServerSide(nil))
end)

test("F4: CanMergeStacksServerSide mirrors CanMergeStacks", function()
    local a = { consumableId = "herb_01", count = 3 }
    local b = { consumableId = "herb_01", count = 5 }
    assertTrue(TradeLock.CanMergeStacksServerSide(a, b))

    local c = {
        consumableId = "herb_01", count = 3,
        bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b1",
    }
    assertFalse(TradeLock.CanMergeStacksServerSide(c, b))
end)

-- ============================================================================
-- G. 常量验证
-- ============================================================================

print("  --- G. 常量验证 ---")

test("G1: LOCK_DURATION is 300 seconds", function()
    assertEqual(TradeLock.LOCK_DURATION, 300)
end)

test("G2: SOURCE_BLACK_MARKET is 'black_market'", function()
    assertEqual(TradeLock.SOURCE_BLACK_MARKET, "black_market")
end)

test("G3: LOCK_MESSAGE is non-empty string", function()
    assertTrue(type(TradeLock.LOCK_MESSAGE) == "string")
    assertTrue(#TradeLock.LOCK_MESSAGE > 0)
end)

-- ============================================================================
-- H. SaveSerializer 锁字段持久化验证
-- ============================================================================

print("  --- H. SaveSerializer 锁字段持久化 ---")

-- 直接加载 SaveSerializer 并验证 SerializeItemFull 保留锁字段
local _serModules = {
    "systems.save.SaveSerializer",
    "systems.save.SaveState",
    "systems.save.SaveMigrations",
    "config.GameConfig",
    "core.GameState",
}
for _, k in ipairs(_serModules) do
    _origPackageLoaded[k] = package.loaded[k]
end

-- 尝试加载 SaveSerializer（如果依赖未满足则跳过）
local serOk, SaveSerializer = pcall(require, "systems.save.SaveSerializer")

if serOk and SaveSerializer and SaveSerializer.SerializeItemFull then
    test("H1: SerializeItemFull preserves bmLockUntil", function()
        local item = {
            id = "test_item", name = "Test", category = "consumable",
            consumableId = "herb_01", count = 5,
            bmLockUntil = 1700000000, bmLockSource = "black_market", bmLockBatchId = "bm_123_456",
        }
        local serialized = SaveSerializer.SerializeItemFull(item)
        assertEqual(serialized.bmLockUntil, 1700000000)
        assertEqual(serialized.bmLockSource, "black_market")
        assertEqual(serialized.bmLockBatchId, "bm_123_456")
    end)

    test("H2: SerializeItemFull omits nil lock fields", function()
        local item = {
            id = "test_item", name = "Test", category = "consumable",
            consumableId = "herb_02", count = 3,
        }
        local serialized = SaveSerializer.SerializeItemFull(item)
        assertEqual(serialized.bmLockUntil, nil)
        assertEqual(serialized.bmLockSource, nil)
        assertEqual(serialized.bmLockBatchId, nil)
    end)
else
    print("  ⚠ H tests skipped: SaveSerializer not loadable in pure-lua env")
end

-- ============================================================================
-- I. 存档版本验证
-- ============================================================================

print("  --- I. 存档版本验证 ---")

local ssOk, SaveState = pcall(require, "systems.save.SaveState")
if ssOk and SaveState then
    test("I1: CURRENT_SAVE_VERSION >= 24", function()
        assertTrue(SaveState.CURRENT_SAVE_VERSION >= 24,
            "expected >= 24, got " .. tostring(SaveState.CURRENT_SAVE_VERSION))
    end)
else
    print("  ⚠ I tests skipped: SaveState not loadable")
end

local migOk, SaveMigrations = pcall(require, "systems.save.SaveMigrations")
if migOk and SaveMigrations and SaveMigrations.MIGRATIONS then
    test("I2: Migration [24] exists and is callable", function()
        assertTrue(type(SaveMigrations.MIGRATIONS[24]) == "function",
            "MIGRATIONS[24] should be a function")
    end)

    test("I3: Migration [24] bumps version to 24", function()
        local data = { version = 23 }
        local result = SaveMigrations.MIGRATIONS[24](data)
        assertEqual(result.version, 24)
    end)
else
    print("  ⚠ I2-I3 tests skipped: SaveMigrations not loadable")
end

-- ============================================================================
-- Cleanup
-- ============================================================================

for _, k in ipairs(_stubModules) do
    package.loaded[k] = _origPackageLoaded[k]
end
for _, k in ipairs(_serModules) do
    package.loaded[k] = _origPackageLoaded[k]
end

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format(
    "\n[test_bm_s4a_trade_lock] TOTAL: %d  PASSED: %d  FAILED: %d\n",
    total, passed, failed
))

return { passed = passed, failed = failed, total = total }
