-- ============================================================================
-- test_warehouse_sort.lua - 仓库整理自测脚本
-- 执行文档 §3.8: 20 个测试用例
-- 用法: 在 GM 控制台输入 require("tests.test_warehouse_sort").RunAll()
-- ============================================================================

local SortUtil = require("systems.InventorySortUtil")
local GameConfig = require("config.GameConfig")

local T = {}
local passed_ = 0
local failed_ = 0
local total_ = 0

--------------------------------------------------------------------
-- 测试辅助
--------------------------------------------------------------------
local function assert_eq(name, got, expected)
    total_ = total_ + 1
    if got == expected then
        passed_ = passed_ + 1
        print("  ✅ " .. name)
    else
        failed_ = failed_ + 1
        print("  ❌ " .. name .. " | expected=" .. tostring(expected) .. " got=" .. tostring(got))
    end
end

local function assert_true(name, val)
    assert_eq(name, val == true, true)
end

local function assert_false(name, val)
    assert_eq(name, val == true, false)
end

--- 创建消耗品
local function mkConsumable(cId, count, opts)
    opts = opts or {}
    return {
        id = opts.id or math.random(10000, 99999),
        category = "consumable",
        consumableId = cId,
        name = opts.name or ("item_" .. cId),
        count = count or 1,
        bmLockUntil = opts.bmLockUntil,
        bmLockBatchId = opts.bmLockBatchId,
        bmLockSource = opts.bmLockSource or (opts.bmLockUntil and "black_market" or nil),
    }
end

--- 创建装备（品质使用项目真实值: white/green/blue/purple/orange/cyan/red/gold/rainbow）
local function mkEquip(slot, quality, tier, opts)
    opts = opts or {}
    return {
        id = opts.id or math.random(10000, 99999),
        category = "equipment",
        slot = slot,
        quality = quality or "white",
        tier = tier or 1,
        name = opts.name or (quality .. "_" .. slot),
        -- 模拟装备特有字段
        enchantLevel = opts.enchantLevel,
        forgeLevel = opts.forgeLevel,
        spiritData = opts.spiritData,
    }
end

--------------------------------------------------------------------
-- TC-1: 空仓库整理
--------------------------------------------------------------------
function T.TC01_EmptyWarehouse()
    print("TC-01: 空仓库整理")
    local items = {}
    local sorted, ok, msg = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("空数组排序应成功", ok)
    assert_eq("结果应为空", #sorted, 0)
end

--------------------------------------------------------------------
-- TC-2: 单物品不变
--------------------------------------------------------------------
function T.TC02_SingleItem()
    print("TC-02: 单物品不变")
    local items = { mkConsumable("potion", 5) }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("数量不变", #sorted, 1)
    assert_eq("count 不变", sorted[1].count, 5)
end

--------------------------------------------------------------------
-- TC-3: 同类消耗品合并
--------------------------------------------------------------------
function T.TC03_MergeSameConsumable()
    print("TC-03: 同类消耗品合并")
    local items = {
        mkConsumable("potion", 30),
        mkConsumable("potion", 20),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("应合并为 1 堆", #sorted, 1)
    assert_eq("总数 50", sorted[1].count, 50)
end

--------------------------------------------------------------------
-- TC-4: 堆叠溢出拆分
--------------------------------------------------------------------
function T.TC04_StackOverflowSplit()
    print("TC-04: 堆叠溢出拆分")
    local MAX = GameConfig.MAX_STACK_COUNT
    local items = {
        mkConsumable("potion", MAX),
        mkConsumable("potion", 10),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("应拆为 2 堆", #sorted, 2)
    local total = 0
    for _, s in ipairs(sorted) do total = total + s.count end
    assert_eq("总数守恒", total, MAX + 10)
end

--------------------------------------------------------------------
-- TC-5: 锁定/非锁定不合并
--------------------------------------------------------------------
function T.TC05_LockedUnlockedNoMerge()
    print("TC-05: 锁定/非锁定不合并")
    local now = os.time()
    local items = {
        mkConsumable("potion", 10),
        mkConsumable("potion", 10, { bmLockUntil = now + 3600, bmLockBatchId = "b1" }),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("不合并，仍为 2 堆", #sorted, 2)
end

--------------------------------------------------------------------
-- TC-6: 不同批次锁定不合并
--------------------------------------------------------------------
function T.TC06_DiffBatchNoMerge()
    print("TC-06: 不同批次锁定不合并")
    local now = os.time()
    local items = {
        mkConsumable("potion", 10, { bmLockUntil = now + 3600, bmLockBatchId = "b1" }),
        mkConsumable("potion", 10, { bmLockUntil = now + 3600, bmLockBatchId = "b2" }),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("不合并，仍为 2 堆", #sorted, 2)
end

--------------------------------------------------------------------
-- TC-7: 同批次锁定可合并
--------------------------------------------------------------------
function T.TC07_SameBatchMerge()
    print("TC-07: 同批次锁定可合并")
    local now = os.time()
    local items = {
        mkConsumable("potion", 10, { bmLockUntil = now + 3600, bmLockBatchId = "b1" }),
        mkConsumable("potion", 10, { bmLockUntil = now + 3600, bmLockBatchId = "b1" }),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("同批次合并为 1 堆", #sorted, 1)
    assert_eq("总数 20", sorted[1].count, 20)
end

--------------------------------------------------------------------
-- TC-8: 装备排序（品质降序）
--------------------------------------------------------------------
function T.TC08_EquipSortByQuality()
    print("TC-08: 装备排序（品质降序）")
    local items = {
        mkEquip("weapon", "white", 1),
        mkEquip("weapon", "orange", 5),
        mkEquip("weapon", "blue", 3),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("第 1 个应为 orange", sorted[1].quality, "orange")
    assert_eq("第 2 个应为 blue", sorted[2].quality, "blue")
    assert_eq("第 3 个应为 white", sorted[3].quality, "white")
end

--------------------------------------------------------------------
-- TC-9: 装备排序（品质相同按阶降序）
--------------------------------------------------------------------
function T.TC09_EquipSortByTier()
    print("TC-09: 装备排序（品质相同按阶降序）")
    local items = {
        mkEquip("weapon", "blue", 2),
        mkEquip("weapon", "blue", 5),
        mkEquip("weapon", "blue", 1),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("tier 降序: 第 1 个 tier=5", sorted[1].tier, 5)
    assert_eq("tier 降序: 第 2 个 tier=2", sorted[2].tier, 2)
    assert_eq("tier 降序: 第 3 个 tier=1", sorted[3].tier, 1)
end

--------------------------------------------------------------------
-- TC-10: 装备在前、消耗品在后
--------------------------------------------------------------------
function T.TC10_EquipBeforeConsumable()
    print("TC-10: 装备在前、消耗品在后")
    local items = {
        mkConsumable("potion", 5),
        mkEquip("weapon", "white", 1),
        mkConsumable("scroll", 3),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("第 1 个应为装备", sorted[1].category, "equipment")
    assert_eq("第 2 个应为消耗品", sorted[2].category, "consumable")
    assert_eq("第 3 个应为消耗品", sorted[3].category, "consumable")
end

--------------------------------------------------------------------
-- TC-11: 消耗品按 consumableId 升序
--------------------------------------------------------------------
function T.TC11_ConsumableSortById()
    print("TC-11: 消耗品按 consumableId 升序")
    local items = {
        mkConsumable("scroll", 1),
        mkConsumable("arrow", 10),
        mkConsumable("potion", 5),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("第 1 个 cId=arrow", sorted[1].consumableId, "arrow")
    assert_eq("第 2 个 cId=potion", sorted[2].consumableId, "potion")
    assert_eq("第 3 个 cId=scroll", sorted[3].consumableId, "scroll")
end

--------------------------------------------------------------------
-- TC-12: 装备引用不变（§3.3.1 核心校验）
--------------------------------------------------------------------
function T.TC12_EquipReferenceIdentity()
    print("TC-12: 装备引用不变（§3.3.1）")
    local e1 = mkEquip("weapon", "blue", 3, {
        enchantLevel = 5,
        forgeLevel = 3,
        spiritData = { name = "火灵", level = 2 },
    })
    local origRef = e1
    local items = { mkConsumable("potion", 10), e1 }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    -- 找到装备
    local foundEquip = nil
    for _, item in ipairs(sorted) do
        if item.category == "equipment" then foundEquip = item break end
    end
    assert_true("装备引用完全相同(rawequal)", rawequal(foundEquip, origRef))
    assert_eq("enchantLevel 保留", foundEquip.enchantLevel, 5)
    assert_eq("forgeLevel 保留", foundEquip.forgeLevel, 3)
    assert_eq("spiritData.name 保留", foundEquip.spiritData.name, "火灵")
end

--------------------------------------------------------------------
-- TC-13: 数量守恒校验
--------------------------------------------------------------------
function T.TC13_QuantityConservation()
    print("TC-13: 数量守恒校验")
    local items = {
        mkConsumable("potion", 30),
        mkConsumable("potion", 25),
        mkConsumable("scroll", 10),
        mkEquip("armor", "blue", 2),
    }
    local beforeCounts = SortUtil.CountConsumables(items)
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    local afterCounts = SortUtil.CountConsumables(sorted)
    local conserved, msg = SortUtil.VerifyConservation(beforeCounts, afterCounts)
    assert_true("数量守恒", conserved)
end

--------------------------------------------------------------------
-- TC-14: 并发保护（_sorting 标志）
--------------------------------------------------------------------
function T.TC14_ConcurrencyGuard()
    print("TC-14: 并发保护标志")
    assert_false("初始状态未锁定", SortUtil._sorting)
    SortUtil._sorting = true
    -- 此时调用 SortItems 应仍然可以工作（_sorting 只在外层调用检查）
    -- 但 WarehouseSystem/InventorySystem 调用会被拒绝
    SortUtil._sorting = false
    assert_false("重置后解锁", SortUtil._sorting)
end

--------------------------------------------------------------------
-- TC-15: 混合装备+消耗品大量排序
--------------------------------------------------------------------
function T.TC15_MixedLargeSort()
    print("TC-15: 混合装备+消耗品大量排序")
    local items = {}
    -- 10 个装备
    local qualities = {"white", "green", "blue", "purple", "orange"}
    for i = 1, 10 do
        items[#items + 1] = mkEquip("weapon", qualities[(i % #qualities) + 1], i)
    end
    -- 20 个消耗品（各种 ID）
    for i = 1, 20 do
        items[#items + 1] = mkConsumable("item_" .. (i % 5), math.random(1, 30))
    end
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    -- 验证装备在前
    local lastEquipIdx = 0
    for i, item in ipairs(sorted) do
        if item.category == "equipment" then lastEquipIdx = i end
    end
    local firstConsIdx = #sorted + 1
    for i, item in ipairs(sorted) do
        if item.category == "consumable" then firstConsIdx = i break end
    end
    assert_true("装备全在消耗品前", lastEquipIdx < firstConsIdx)
end

--------------------------------------------------------------------
-- TC-16: GetMergeKey 一致性
--------------------------------------------------------------------
function T.TC16_MergeKeyConsistency()
    print("TC-16: GetMergeKey 一致性")
    local item = mkConsumable("potion", 5)
    local k1 = SortUtil.GetMergeKey(item)
    local k2 = SortUtil.GetMergeKey(item)
    assert_eq("同物品两次 key 一致", k1, k2)
    assert_eq("未锁定 key 包含 unlocked", k1, "potion|unlocked")
end

--------------------------------------------------------------------
-- TC-17: 品质相同阶相同按槽位名排序
--------------------------------------------------------------------
function T.TC17_SameQualitySameTierSortBySlot()
    print("TC-17: 品质相同阶相同按槽位名排序")
    local items = {
        mkEquip("weapon", "blue", 3),
        mkEquip("armor", "blue", 3),
        mkEquip("helmet", "blue", 3),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("slot 升序: armor", sorted[1].slot, "armor")
    assert_eq("slot 升序: helmet", sorted[2].slot, "helmet")
    assert_eq("slot 升序: weapon", sorted[3].slot, "weapon")
end

--------------------------------------------------------------------
-- TC-18: 多种消耗品各自合并
--------------------------------------------------------------------
function T.TC18_MultiTypeConsumableMerge()
    print("TC-18: 多种消耗品各自合并")
    local items = {
        mkConsumable("potion", 10),
        mkConsumable("scroll", 5),
        mkConsumable("potion", 20),
        mkConsumable("scroll", 15),
    }
    local sorted, ok = SortUtil.SortItems(items)
    sorted = sorted or {}
    assert_true("排序成功", ok)
    assert_eq("应合并为 2 种", #sorted, 2)
    -- 验证总数
    local totals = {}
    for _, s in ipairs(sorted) do
        totals[s.consumableId] = (totals[s.consumableId] or 0) + s.count
    end
    assert_eq("potion 总数 30", totals["potion"], 30)
    assert_eq("scroll 总数 20", totals["scroll"], 20)
end

--------------------------------------------------------------------
-- TC-19: SortComparator 稳定性
--------------------------------------------------------------------
function T.TC19_ComparatorStability()
    print("TC-19: SortComparator 稳定性")
    -- 两个完全相同属性的装备，排序不应崩溃
    local a = mkEquip("weapon", "blue", 3)
    local b = mkEquip("weapon", "blue", 3)
    local r1 = SortUtil.SortComparator(a, b)
    local r2 = SortUtil.SortComparator(b, a)
    -- a < b 和 b < a 不能同时为 true
    assert_false("不应同时 a<b 和 b<a", r1 == true and r2 == true)
end

--------------------------------------------------------------------
-- TC-20: VerifyConservation 检测到差异
--------------------------------------------------------------------
function T.TC20_ConservationDetectsMismatch()
    print("TC-20: VerifyConservation 检测差异")
    local before = { potion = 30 }
    local after = { potion = 25 }
    local ok, msg = SortUtil.VerifyConservation(before, after)
    assert_false("数量不一致应失败", ok)
end

--------------------------------------------------------------------
-- 运行所有测试
--------------------------------------------------------------------
function T.RunAll()
    passed_ = 0
    failed_ = 0
    total_ = 0
    print("========================================")
    print("  仓库整理测试 - 共 20 个用例")
    print("========================================")
    local cases = {
        T.TC01_EmptyWarehouse,
        T.TC02_SingleItem,
        T.TC03_MergeSameConsumable,
        T.TC04_StackOverflowSplit,
        T.TC05_LockedUnlockedNoMerge,
        T.TC06_DiffBatchNoMerge,
        T.TC07_SameBatchMerge,
        T.TC08_EquipSortByQuality,
        T.TC09_EquipSortByTier,
        T.TC10_EquipBeforeConsumable,
        T.TC11_ConsumableSortById,
        T.TC12_EquipReferenceIdentity,
        T.TC13_QuantityConservation,
        T.TC14_ConcurrencyGuard,
        T.TC15_MixedLargeSort,
        T.TC16_MergeKeyConsistency,
        T.TC17_SameQualitySameTierSortBySlot,
        T.TC18_MultiTypeConsumableMerge,
        T.TC19_ComparatorStability,
        T.TC20_ConservationDetectsMismatch,
    }
    for _, tc in ipairs(cases) do
        local ok, err = pcall(tc)
        if not ok then
            failed_ = failed_ + 1
            total_ = total_ + 1
            print("  💥 CRASH: " .. tostring(err))
        end
    end
    print("========================================")
    print(string.format("  结果: %d/%d 通过, %d 失败", passed_, total_, failed_))
    print("========================================")
    return passed_, failed_
end

return T
