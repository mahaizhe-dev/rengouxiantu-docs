---@diagnostic disable
-- ============================================================================
-- test_bm_noresell_consume.lua — BM-NORESELL(P2) 消耗优先级 + 混合消耗(Q4)
--
-- 覆盖（执行文档 P2 / Q4）：
--   P2-1.  消耗优先扣 bmNoResell（保留玩家可回售流动性，普通堆叠不动）
--   P2-2.  混合消耗(Q4)：需要 5 个，黑市3+普通2 → 全扣完
--   P2-2b. 混合消耗：黑市3全扣 + 普通仅扣 1
--   P2-3.  数量不足 → 拒绝消耗，任何堆叠不动
--   P2-4.  残留临时锁堆叠(旧存档)不参与消耗（兼容过渡）
--
-- 测试方法：构造 mock IS facade + mock manager（背靠本地 slots table），
-- 绝不调用 InventorySystem.Init/SetManager（遵守 rules.md 测试安全红线）。
-- 通过 package.loaded 隔离 EventBus / SyncState，避免触碰真实单例/事件总线。
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
    if a ~= b then error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a)) end
end
local function assertTrue(v, msg) if not v then error(msg or "expected true") end end
local function assertFalse(v, msg) if v then error(msg or "expected false") end end

print("\n[test_bm_noresell_consume] === 消耗优先扣 bmNoResell + 混合消耗 ===\n")

if not package.path:find("scripts/%?%.lua") then
    package.path = package.path .. ";scripts/?.lua"
end

-- 隔离重依赖：EventBus / SyncState 用无副作用桩，保存原值用于恢复
local _orig = {}
local function stub(name, mod) _orig[name] = package.loaded[name]; package.loaded[name] = mod end

stub("core.EventBus", { On = function() end, Emit = function() end, Off = function() end })
stub("systems.BlackMarketSyncState", {
    MarkConsumeUsed = function() end,
    MarkWarehouseOp = function() end,
})

-- 清缓存重载 consumables（捕获桩 EventBus）；TradeLock 用真实实现
local _origConsumables = package.loaded["systems.inventory.consumables"]
package.loaded["systems.inventory.consumables"] = nil

local TradeLock = require("systems.BlackMarketTradeLock")
local okC, consumables = pcall(require, "systems.inventory.consumables")

-- mock IS facade + manager（背靠本地 slots 数组，1-based）
local function makeIS(slots)
    local mgr = {
        GetInventoryItem = function(_, i) return slots[i] end,
        SetInventoryItem = function(_, i, v) slots[i] = v end,
    }
    return { GetManager = function() return mgr end }
end

-- 构造消耗品堆叠：noResell=黑市买入标记 / locked=旧存档残留临时锁
local function newStack(consumableId, count, noResell, locked)
    local it = { category = "consumable", consumableId = consumableId, count = count }
    if noResell then TradeLock.MarkNoResell(it, consumableId) end
    if locked then TradeLock.ApplyLock(it, "old_batch") end
    return it
end

if not okC or not consumables or not consumables.ConsumeConsumable then
    print("  (skip) consumables 在当前环境不可加载: " .. tostring(consumables))
else
    test("P2-1. 消耗优先扣 bmNoResell（普通堆叠保留）", function()
        local slots = {}
        slots[1] = newStack("gold_brick", 5, false)  -- 普通可卖
        slots[2] = newStack("gold_brick", 5, true)   -- 黑市买入
        local ok = consumables.ConsumeConsumable(makeIS(slots), "gold_brick", 3)
        assertTrue(ok, "消耗成功")
        assertEqual(slots[1].count, 5, "普通堆叠保留")
        assertEqual(slots[2].count, 2, "优先扣 bmNoResell 5→2")
    end)

    test("P2-2. 混合消耗(Q4)：需要5，黑市3+普通2 → 全扣完", function()
        local slots = {}
        slots[1] = newStack("spirit_pill", 3, true)   -- 黑市3（绑定）
        slots[2] = newStack("spirit_pill", 2, false)  -- 普通2（不绑定）
        local ok = consumables.ConsumeConsumable(makeIS(slots), "spirit_pill", 5)
        assertTrue(ok, "需要5，混合扣除成功")
        assertTrue(slots[1] == nil, "黑市3用尽移除")
        assertTrue(slots[2] == nil, "普通2用尽移除")
    end)

    test("P2-2b. 混合消耗：黑市3全扣 + 普通仅扣1", function()
        local slots = {}
        slots[1] = newStack("spirit_pill", 3, true)   -- 黑市3
        slots[2] = newStack("spirit_pill", 5, false)  -- 普通5
        local ok = consumables.ConsumeConsumable(makeIS(slots), "spirit_pill", 4)
        assertTrue(ok, "扣4成功")
        assertTrue(slots[1] == nil, "黑市3全扣")
        assertEqual(slots[2].count, 4, "普通仅扣1 → 5-1=4")
    end)

    test("P2-3. 数量不足 → 拒绝消耗，堆叠不动", function()
        local slots = {}
        slots[1] = newStack("gold_brick", 2, true)
        local ok = consumables.ConsumeConsumable(makeIS(slots), "gold_brick", 5)
        assertFalse(ok, "可消耗仅2，请求5应失败")
        assertEqual(slots[1].count, 2, "失败时不动堆叠")
    end)

    test("P2-4. 残留临时锁堆叠不参与消耗（旧存档兼容）", function()
        local slots = {}
        slots[1] = newStack("gold_brick", 10, false, true)  -- 旧存档临时锁
        slots[2] = newStack("gold_brick", 3, false)         -- 普通
        -- 可消耗仅普通3，请求5应失败
        local ok = consumables.ConsumeConsumable(makeIS(slots), "gold_brick", 5)
        assertFalse(ok, "锁堆不参与，可消耗仅3，请求5失败")
        assertEqual(slots[1].count, 10, "锁堆不动")
        -- 请求3成功，只扣普通
        local ok2 = consumables.ConsumeConsumable(makeIS(slots), "gold_brick", 3)
        assertTrue(ok2, "请求3成功")
        assertEqual(slots[1].count, 10, "锁堆仍不动")
        assertTrue(slots[2] == nil, "普通3用尽")
    end)
end

-- cleanup：恢复 consumables 与桩模块
package.loaded["systems.inventory.consumables"] = _origConsumables
for name, mod in pairs(_orig) do package.loaded[name] = mod end

print("\n[test_bm_noresell_consume] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
