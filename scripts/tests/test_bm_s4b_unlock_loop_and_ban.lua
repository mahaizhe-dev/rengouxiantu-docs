-- ============================================================================
-- test_bm_s4b_unlock_loop_and_ban.lua — BM-S4B 解锁闭环与整类禁售测试
--
-- 测试层次：
--   A. 解锁闭环：SerializeItemFull 剥离锁字段 → 重登不复现
--   B. 整类禁售：HasAnyLockedConsumable → 只要有一个锁定，整个 itemId 禁售
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

print("\n[test_bm_s4b] === BM-S4B 解锁闭环与整类禁售测试 ===\n")

-- ============================================================================
-- Stubs & Setup
-- ============================================================================

local _origLoaded = {}
local _modulesToReset = {
    "systems.BlackMarketTradeLock",
    "systems.save.SaveSerializer",
    "systems.save.SaveState",
    "systems.save.SaveMigrations",
    "config.GameConfig",
    "core.GameState",
}
for _, k in ipairs(_modulesToReset) do
    _origLoaded[k] = package.loaded[k]
    package.loaded[k] = nil
end

local TradeLock = require("systems.BlackMarketTradeLock")

-- ============================================================================
-- A. 解锁闭环：SerializeItemFull 剥离锁字段
-- ============================================================================

print("  --- A. 解锁闭环 ---")

local serOk, SaveSerializer = pcall(require, "systems.save.SaveSerializer")

if serOk and SaveSerializer and SaveSerializer.SerializeItemFull then

    test("A1: 锁定物品序列化后 bmLockUntil/Source/BatchId 均为 nil", function()
        local item = {
            id = "locked_herb", name = "灵草", category = "consumable",
            consumableId = "herb_01", count = 10,
            bmLockUntil = os.time() + 300,
            bmLockSource = "black_market",
            bmLockBatchId = "bm_1700000000_1234",
        }
        -- 确认原始物品确实有锁
        assertTrue(TradeLock.IsLocked(item), "precondition: item should be locked")

        local serialized = SaveSerializer.SerializeItemFull(item)

        -- 序列化结果不应包含锁字段
        assertEqual(serialized.bmLockUntil, nil, "bmLockUntil must be nil in serialized")
        assertEqual(serialized.bmLockSource, nil, "bmLockSource must be nil in serialized")
        assertEqual(serialized.bmLockBatchId, nil, "bmLockBatchId must be nil in serialized")

        -- 但其他字段必须保留
        assertEqual(serialized.id, "locked_herb")
        assertEqual(serialized.consumableId, "herb_01")
        assertEqual(serialized.count, 10)
    end)

    test("A2: 模拟存档→加载往返，锁不复现", function()
        -- 1. 创建锁定物品
        local item = {
            id = "roundtrip_herb", name = "灵草", category = "consumable",
            consumableId = "herb_01", count = 5,
        }
        TradeLock.ApplyLock(item, "bm_test_batch", 300)
        assertTrue(TradeLock.IsLocked(item), "precondition: locked after ApplyLock")

        -- 2. 序列化（模拟存档写入）
        local serialized = SaveSerializer.SerializeItemFull(item)

        -- 3. 模拟从云端加载：反序列化数据就是 serialized 本身
        --    （SaveLoader.DeserializeInventory 直接使用 serialized 的 table）
        local loaded = serialized

        -- 4. 验证加载后的物品无锁
        assertFalse(TradeLock.IsLocked(loaded), "loaded item must NOT be locked")
        assertEqual(loaded.bmLockUntil, nil)
        assertEqual(loaded.bmLockSource, nil)
        assertEqual(loaded.bmLockBatchId, nil)
    end)

else
    print("  ⚠ A tests skipped: SaveSerializer not loadable in pure-lua env")
end

-- ============================================================================
-- B. 整类禁售：HasAnyLockedConsumable
-- ============================================================================

print("  --- B. 整类禁售 ---")

test("B1: HasAnyLockedConsumable — 有锁定堆叠返回 true", function()
    local backpack = {
        { category = "consumable", consumableId = "herb_01", count = 10 },  -- 无锁
        { category = "consumable", consumableId = "herb_01", count = 5,
          bmLockUntil = os.time() + 300, bmLockSource = "black_market", bmLockBatchId = "b1" },  -- 锁定
        { category = "consumable", consumableId = "herb_02", count = 20 },  -- 其他物品
    }
    local result = TradeLock.HasAnyLockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "herb_01"
    )
    assertTrue(result, "herb_01 has locked stack, should return true")
end)

test("B2: HasAnyLockedConsumable — 无锁定堆叠返回 false", function()
    local backpack = {
        { category = "consumable", consumableId = "herb_01", count = 10 },
        { category = "consumable", consumableId = "herb_01", count = 5 },
        { category = "consumable", consumableId = "herb_02", count = 20 },
    }
    local result = TradeLock.HasAnyLockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "herb_01"
    )
    assertFalse(result, "herb_01 has no locked stack, should return false")
end)

test("B3: HasAnyLockedConsumable — 过期锁不算锁定", function()
    local backpack = {
        { category = "consumable", consumableId = "herb_01", count = 5,
          bmLockUntil = os.time() - 10, bmLockSource = "black_market" },  -- 已过期
    }
    local result = TradeLock.HasAnyLockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "herb_01"
    )
    assertFalse(result, "expired lock should not count")
end)

test("B4: HasAnyLockedConsumable — 空背包返回 false", function()
    local result = TradeLock.HasAnyLockedConsumable(
        function(_) return nil end,
        60,
        "herb_01"
    )
    assertFalse(result, "empty backpack should return false")
end)

test("B5: HasAnyLockedConsumable — 装备类不受整类禁售影响", function()
    -- 装备不是 consumable，HasAnyLockedConsumable 只检查 category=="consumable"
    local backpack = {
        { category = "equipment", slot = "weapon", tier = 3,
          bmLockUntil = os.time() + 300, bmLockSource = "black_market" },
    }
    local result = TradeLock.HasAnyLockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "herb_01"
    )
    assertFalse(result, "equipment should not trigger consumable lock check")
end)

test("B6: HasAnyLockedConsumable — 不同 consumableId 的锁不相互影响", function()
    local backpack = {
        { category = "consumable", consumableId = "herb_02", count = 5,
          bmLockUntil = os.time() + 300, bmLockSource = "black_market" },  -- herb_02 锁定
        { category = "consumable", consumableId = "herb_01", count = 10 },  -- herb_01 无锁
    }
    -- herb_01 查询不应受 herb_02 的锁影响
    local result = TradeLock.HasAnyLockedConsumable(
        function(i) return backpack[i] end,
        #backpack,
        "herb_01"
    )
    assertFalse(result, "herb_02 lock should not affect herb_01")
end)

-- ============================================================================
-- Cleanup
-- ============================================================================

for _, k in ipairs(_modulesToReset) do
    package.loaded[k] = _origLoaded[k]
end

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format(
    "\n[test_bm_s4b] TOTAL: %d  PASSED: %d  FAILED: %d\n",
    total, passed, failed
))

return { passed = passed, failed = failed, total = total }
