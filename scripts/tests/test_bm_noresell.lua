---@diagnostic disable
-- ============================================================================
-- test_bm_noresell.lua — BM-NORESELL 黑市买入永久禁回售（阶段1 线A）
--
-- 覆盖范围（执行文档 §6 / §9.4）：
--   T1.  TradeLock.MarkNoResell 写入四字段成组；IsNoResell 判定
--   T2.  消耗品买入(AddLockedNewStack) → 每个堆叠带 bmNoResell=true
--   T3.  可回售统计排除黑市买入来源；不可回售统计计入
--   T4.  RemoveResellableFromBackpack 永不扣黑市买入来源
--   T5.  普通来源不受影响（计入可卖、可扣除）
--   T6.  混合背包：只扣普通来源，黑市来源数量不变
--   T7.  禁合并：普通入库不并入黑市买入堆叠（AddToBackpack）
--   T8.  整理合并键隔离：GetMergeKey 区分 noresell / 普通 / 锁定
--   T9.  装备：可回售统计/扣除排除黑市买入装备
--   T10. 全量遍历 BMConfig.ITEM_IDS（best-effort）：买入→不可回售→可卖=0
--   T11. 序列化保留 bmNoResell 组（best-effort，依赖 SaveSerializer 可加载）
--
-- 纯 Lua 测试：只操作本地构造的 backpack table，绝不触碰全局单例
-- （不调用 InventorySystem.Init/SetManager，遵守 rules.md 测试安全红线）
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

local function assertEqual(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a))
    end
end

local function assertTrue(v, msg) if not v then error(msg or "expected true") end end
local function assertFalse(v, msg) if v then error(msg or "expected false") end end

print("\n[test_bm_noresell] === 黑市买入永久禁回售（线A）===\n")

if not package.path:find("scripts/%?%.lua") then
    package.path = package.path .. ";scripts/?.lua"
end

-- 轻依赖模块（TradeLock 无依赖；BackpackUtils→TradeLock）
local TradeLock = require("systems.BlackMarketTradeLock")
local BackpackUtils = require("network.BackpackUtils")

-- ============================================================================
-- T1: MarkNoResell / IsNoResell
-- ============================================================================
test("T1. MarkNoResell 写入四字段成组 + IsNoResell 判定", function()
    local item = { category = "consumable", consumableId = "gold_brick", count = 1 }
    assertFalse(TradeLock.IsNoResell(item), "初始普通来源 IsNoResell=false")
    TradeLock.MarkNoResell(item, "gold_brick")
    assertEqual(item.bmNoResell, true, "bmNoResell")
    assertEqual(item.bmSource, TradeLock.NO_RESELL_SOURCE, "bmSource")
    assertEqual(item.bmBuyItemId, "gold_brick", "bmBuyItemId")
    assertTrue(type(item.bmBuyAt) == "number", "bmBuyAt 为时间戳")
    assertTrue(TradeLock.IsNoResell(item), "标记后 IsNoResell=true")
    assertFalse(TradeLock.IsNoResell(nil), "nil 安全")
end)

-- ============================================================================
-- T2: 消耗品买入 → 堆叠带 bmNoResell
-- ============================================================================
test("T2. AddLockedNewStack 写入 bmNoResell=true", function()
    local bp = {}
    local rem = BackpackUtils.AddLockedNewStack(bp, "wubao_token_box", 3, "乌堡令盒", "batch_t2")
    assertEqual(rem, 0, "全部放入")
    local found = 0
    for _, it in pairs(bp) do
        if it.consumableId == "wubao_token_box" then
            found = found + 1
            assertTrue(TradeLock.IsNoResell(it), "买入堆叠应带 bmNoResell")
            assertEqual(it.bmBuyItemId, "wubao_token_box", "bmBuyItemId")
        end
    end
    assertTrue(found >= 1, "至少一个堆叠")
end)

-- ============================================================================
-- T3: 可回售/不可回售统计
-- ============================================================================
test("T3. 可回售统计排除黑市买入；不可回售统计计入", function()
    local bp = {}
    BackpackUtils.AddLockedNewStack(bp, "gold_brick", 5, "金砖", "batch_t3")
    assertEqual(BackpackUtils.CountResellableBackpackItem(bp, "gold_brick"), 0,
        "黑市买入不计入可回售")
    assertEqual(BackpackUtils.CountNoResellBackpackItem(bp, "gold_brick"), 5,
        "黑市买入计入不可回售")
    -- 总持有量仍为 5
    assertEqual(BackpackUtils.CountBackpackItem(bp, "gold_brick"), 5, "总持有=5")
end)

-- ============================================================================
-- T4: RemoveResellable 永不扣黑市买入来源
-- ============================================================================
test("T4. RemoveResellableFromBackpack 永不扣黑市买入来源", function()
    local bp = {}
    BackpackUtils.AddLockedNewStack(bp, "gold_brick", 5, "金砖", "batch_t4")
    local rem = BackpackUtils.RemoveResellableFromBackpack(bp, "gold_brick", 3)
    assertEqual(rem, 3, "可回售为0，无法扣除，剩余请求=3")
    assertEqual(BackpackUtils.CountBackpackItem(bp, "gold_brick"), 5, "黑市买入数量不变")
end)

-- ============================================================================
-- T5: 普通来源不受影响
-- ============================================================================
test("T5. 普通来源计入可卖、可扣除", function()
    local bp = {}
    BackpackUtils.AddToBackpack(bp, "gold_brick", 10, "金砖")
    assertEqual(BackpackUtils.CountResellableBackpackItem(bp, "gold_brick"), 10, "普通来源可卖=10")
    local rem = BackpackUtils.RemoveResellableFromBackpack(bp, "gold_brick", 4)
    assertEqual(rem, 0, "扣除成功")
    assertEqual(BackpackUtils.CountBackpackItem(bp, "gold_brick"), 6, "剩余6")
end)

-- ============================================================================
-- T6: 混合背包 → 只扣普通来源
-- ============================================================================
test("T6. 混合背包只扣普通来源，黑市来源不变", function()
    local bp = {}
    BackpackUtils.AddToBackpack(bp, "gold_brick", 4, "金砖")           -- 普通 4
    BackpackUtils.AddLockedNewStack(bp, "gold_brick", 6, "金砖", "b6") -- 黑市 6
    assertEqual(BackpackUtils.CountResellableBackpackItem(bp, "gold_brick"), 4, "可卖=普通4")
    assertEqual(BackpackUtils.CountNoResellBackpackItem(bp, "gold_brick"), 6, "不可卖=黑市6")
    -- 卖出 4（全部可卖）
    local rem = BackpackUtils.RemoveResellableFromBackpack(bp, "gold_brick", 4)
    assertEqual(rem, 0, "普通4全扣")
    assertEqual(BackpackUtils.CountResellableBackpackItem(bp, "gold_brick"), 0, "可卖归0")
    assertEqual(BackpackUtils.CountNoResellBackpackItem(bp, "gold_brick"), 6, "黑市6保持不变")
    -- 再尝试卖出 1 → 没有可卖
    local rem2 = BackpackUtils.RemoveResellableFromBackpack(bp, "gold_brick", 1)
    assertEqual(rem2, 1, "无可卖，扣除失败")
    assertEqual(BackpackUtils.CountNoResellBackpackItem(bp, "gold_brick"), 6, "黑市仍为6")
end)

-- ============================================================================
-- T7: 禁合并 — 普通入库不并入黑市买入堆叠
-- ============================================================================
test("T7. AddToBackpack 不把普通物品并入黑市买入堆叠", function()
    local bp = {}
    BackpackUtils.AddLockedNewStack(bp, "gold_brick", 2, "金砖", "b7")  -- 黑市堆叠
    BackpackUtils.AddToBackpack(bp, "gold_brick", 3, "金砖")            -- 普通入库
    -- 黑市堆叠仍为不可卖2，普通入库为可卖3，二者不混
    assertEqual(BackpackUtils.CountNoResellBackpackItem(bp, "gold_brick"), 2, "黑市仍2（未被污染）")
    assertEqual(BackpackUtils.CountResellableBackpackItem(bp, "gold_brick"), 3, "普通3独立存在")
end)

-- ============================================================================
-- T8: 整理合并键隔离
-- ============================================================================
test("T8. GetMergeKey 区分 noresell / 普通 / 锁定", function()
    local okSort, SortUtil = pcall(require, "systems.InventorySortUtil")
    if not okSort then error("InventorySortUtil 加载失败: " .. tostring(SortUtil)) end

    local normal = { consumableId = "gold_brick", count = 1 }
    local nores  = { consumableId = "gold_brick", count = 1 }
    TradeLock.MarkNoResell(nores, "gold_brick")
    -- 黑市买入但锁已过期（无 bmLock*）
    local kNormal = SortUtil.GetMergeKey(normal)
    local kNores  = SortUtil.GetMergeKey(nores)
    assertTrue(kNormal ~= kNores, "普通与黑市买入合并键必须不同（防洗白）")
    assertTrue(tostring(kNores):find("noresell") ~= nil, "黑市买入键含 noresell 维度")

    -- 黑市买入 + 临时锁
    local noresLocked = { consumableId = "gold_brick", count = 1 }
    TradeLock.MarkNoResell(noresLocked, "gold_brick")
    TradeLock.ApplyLock(noresLocked, "batchX")
    local kNoresLocked = SortUtil.GetMergeKey(noresLocked)
    assertTrue(kNoresLocked ~= kNormal, "锁定黑市买入仍与普通不同")
    assertTrue(tostring(kNoresLocked):find("noresell") ~= nil, "仍含 noresell 维度")
end)

-- ============================================================================
-- T9: 装备可回售统计/扣除
-- ============================================================================
test("T9. 装备可回售统计/扣除排除黑市买入装备", function()
    local bp = {}
    -- 普通装备 1 件
    bp["1"] = { id = 1001, category = "equip", equipId = "dizun_ring_ch1" }
    -- 黑市买入装备 1 件
    local bmEquip = { id = 1002, category = "equip", equipId = "dizun_ring_ch1" }
    TradeLock.MarkNoResell(bmEquip, "dizun_ring_ch1")
    bp["2"] = bmEquip

    assertEqual(BackpackUtils.CountEquipmentItem(bp, "dizun_ring_ch1"), 2, "总2件")
    assertEqual(BackpackUtils.CountResellableEquipmentItem(bp, "dizun_ring_ch1"), 1, "可卖仅普通1件")
    assertEqual(BackpackUtils.CountNoResellEquipmentItem(bp, "dizun_ring_ch1"), 1, "不可卖黑市1件")

    -- 卖出 1 件 → 应只移除普通件，黑市件保留
    local rem = BackpackUtils.RemoveResellableEquipmentFromBackpack(bp, "dizun_ring_ch1", 1)
    assertEqual(rem, 0, "移除成功")
    assertEqual(BackpackUtils.CountNoResellEquipmentItem(bp, "dizun_ring_ch1"), 1, "黑市装备仍在")
    assertEqual(BackpackUtils.CountResellableEquipmentItem(bp, "dizun_ring_ch1"), 0, "可卖归0")
    -- 再尝试卖 1 件 → 无可卖
    local rem2 = BackpackUtils.RemoveResellableEquipmentFromBackpack(bp, "dizun_ring_ch1", 1)
    assertEqual(rem2, 1, "无可卖装备，扣除失败")
    assertEqual(BackpackUtils.CountNoResellEquipmentItem(bp, "dizun_ring_ch1"), 1, "黑市装备保持")
end)

-- ============================================================================
-- T10: 全量遍历 BMConfig.ITEM_IDS（§9.4 新增商品自动覆盖）
-- ============================================================================
test("T10. 全量遍历 BMConfig.ITEM_IDS：买入→不可回售→可卖=0", function()
    local okCfg, BMConfig = pcall(require, "config.BlackMerchantConfig")
    if not okCfg or not BMConfig or not BMConfig.ITEM_IDS then
        print("    (skip) BMConfig 在纯Lua环境不可加载: " .. tostring(BMConfig))
        return
    end
    local n = 0
    for _, itemId in ipairs(BMConfig.ITEM_IDS) do
        local cfg = BMConfig.ITEMS[itemId]
        n = n + 1
        local bp = {}
        if cfg.itemType == "equipment" then
            -- 模拟黑市买入装备：构造对象 + 永久标记
            local e = { id = 9000 + n, category = "equip", equipId = cfg.equipId or itemId }
            TradeLock.MarkNoResell(e, cfg.equipId or itemId)
            bp["1"] = e
            local eqId = cfg.equipId or itemId
            assertTrue(TradeLock.IsNoResell(bp["1"]), itemId .. " 装备应带 bmNoResell")
            assertEqual(BackpackUtils.CountResellableEquipmentItem(bp, eqId), 0,
                itemId .. " 可卖装备应为0")
            local rem = BackpackUtils.RemoveResellableEquipmentFromBackpack(bp, eqId, 1)
            assertEqual(rem, 1, itemId .. " 装备应拒绝回售扣除")
        else
            -- 模拟黑市买入消耗品
            BackpackUtils.AddLockedNewStack(bp, itemId, 1, cfg.name, "sweep_" .. n)
            assertEqual(BackpackUtils.CountResellableBackpackItem(bp, itemId), 0,
                itemId .. " 可卖应为0")
            assertEqual(BackpackUtils.CountNoResellBackpackItem(bp, itemId), 1,
                itemId .. " 不可卖应为1")
            local rem = BackpackUtils.RemoveResellableFromBackpack(bp, itemId, 1)
            assertEqual(rem, 1, itemId .. " 应拒绝回售扣除")
        end
    end
    print("    遍历商品数: " .. n)
    assertTrue(n > 0, "至少覆盖一个商品")
end)

-- ============================================================================
-- T11: 序列化保留 bmNoResell 组（best-effort）
-- ============================================================================
test("T11. SerializeItemFull 保留 bmNoResell 四字段组（best-effort）", function()
    local okSer, Ser = pcall(require, "systems.save.SaveSerializer")
    if not okSer or not Ser or not Ser.SerializeItemFull then
        print("    (skip) SaveSerializer 在纯Lua环境不可加载: " .. tostring(Ser))
        return
    end
    local item = {
        id = 7777, name = "金砖", category = "consumable",
        consumableId = "gold_brick", count = 2,
    }
    TradeLock.MarkNoResell(item, "gold_brick")
    local out = Ser.SerializeItemFull(item)
    assertEqual(out.bmNoResell, true, "序列化保留 bmNoResell")
    assertEqual(out.bmSource, TradeLock.NO_RESELL_SOURCE, "序列化保留 bmSource")
    assertEqual(out.bmBuyItemId, "gold_brick", "序列化保留 bmBuyItemId")
    assertTrue(type(out.bmBuyAt) == "number", "序列化保留 bmBuyAt")
    -- 临时锁字段不应落盘
    assertEqual(out.bmLockUntil, nil, "临时锁不落盘")
end)

-- ============================================================================
-- T12: P1 同源合并 — 连续买入同 ID 合并到同一 bmNoResell 堆叠（不再强制分堆）
-- ============================================================================
test("T12. 同源合并：连续买入同 ID 合并为单一 bmNoResell 堆叠", function()
    local bp = {}
    BackpackUtils.AddLockedNewStack(bp, "gold_brick", 3, "金砖", "b12a")
    BackpackUtils.AddLockedNewStack(bp, "gold_brick", 4, "金砖", "b12b")
    local stackCount = 0
    for _, it in pairs(bp) do
        if it.consumableId == "gold_brick" then stackCount = stackCount + 1 end
    end
    assertEqual(stackCount, 1, "同源黑市买入应合并为单堆（不再强制分堆）")
    assertEqual(BackpackUtils.CountNoResellBackpackItem(bp, "gold_brick"), 7, "合并后不可卖=7")
    assertEqual(BackpackUtils.CountResellableBackpackItem(bp, "gold_brick"), 0, "可卖=0")
end)

-- ============================================================================
-- T13: P1 买入物立即可用 — 无临时锁字段（IsLocked=false），但仍是 bmNoResell
-- ============================================================================
test("T13. 黑市买入物无临时锁，立即可用（IsLocked=false / 无 bmLock*）", function()
    local bp = {}
    BackpackUtils.AddLockedNewStack(bp, "spirit_pill", 2, "灵丹", "b13")
    local checked = 0
    for _, it in pairs(bp) do
        if it.consumableId == "spirit_pill" then
            checked = checked + 1
            assertFalse(TradeLock.IsLocked(it), "买入物不应处于临时锁")
            assertEqual(it.bmLockUntil, nil, "无 bmLockUntil")
            assertEqual(it.bmLockSource, nil, "无 bmLockSource")
            assertEqual(it.bmLockBatchId, nil, "无 bmLockBatchId")
            assertTrue(TradeLock.IsNoResell(it), "仍是 bmNoResell")
        end
    end
    assertTrue(checked >= 1, "至少检查一个堆叠")
end)

print("\n[test_bm_noresell] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
