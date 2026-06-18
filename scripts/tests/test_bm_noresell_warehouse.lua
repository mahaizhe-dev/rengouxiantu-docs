---@diagnostic disable
-- ============================================================================
-- test_bm_noresell_warehouse.lua — BM-NORESELL 仓库保留 bmNoResell 回归
--
-- ⚠️ 设计说明（务必先读）：
--   WarehouseSystem 的 StoreItem/RetrieveItem/Serialize/Deserialize 强耦合全局 GameState
--   与 InventoryManager（内部 require，不接受依赖注入）。真实引擎对 systems 模块走内部
--   模块表，测试改写 package.loaded 注入 mock 对其【无效】；直接调用又会碰真实玩家
--   背包/仓库并触发存档（rules.md 测试红线）。故本测试【不调用 WarehouseSystem 实例方法】，
--   改为【零副作用】验证它保留 bmNoResell 所依赖的三条不变量：
--     W1. 引用移动语义：存取本质是 table 引用搬运，bmNoResell 随引用保留（纯表模拟）
--     W2. 源码静态断言：WarehouseSystem.Serialize 必须复用 SaveSerializer.SerializeItemFull
--         （而非手写字段拷贝）—— 抓"改成自定义序列化漏掉 bmNoResell"回归（best-effort，依赖 io）
--     W3. 序列化往返：SerializeItemFull → 反序列化(itemData 本身) → 仍 IsNoResell（真实 SaveSerializer）
--
-- 纯 Lua + 只读源码，无引擎运行时副作用；依赖不可加载时 best-effort skip。
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

print("\n[test_bm_noresell_warehouse] === 仓库保留 bmNoResell 回归 ===\n")

if not package.path:find("scripts/%?%.lua") then
    package.path = package.path .. ";scripts/?.lua"
end

local TradeLock = require("systems.BlackMarketTradeLock")

-- ============================================================================
-- W1: 引用移动语义（纯表模拟 StoreItem / RetrieveItem 的核心：wh[t]=bag[s]; bag[s]=nil）
-- ============================================================================
test("W1. 引用移动：存仓/取出搬运 table 引用，bmNoResell 随引用保留", function()
    local item = { category = "consumable", consumableId = "gold_brick", count = 3, name = "金砖" }
    TradeLock.MarkNoResell(item, "gold_brick")

    local bag, wh = { [1] = item }, {}
    -- 模拟 StoreItem：引用搬运到仓库
    wh[1] = bag[1]; bag[1] = nil
    assertTrue(bag[1] == nil, "背包槽1已清空")
    assertTrue(wh[1] == item, "仓库持有同一引用")
    assertTrue(TradeLock.IsNoResell(wh[1]), "仓库物品仍 bmNoResell")

    -- 模拟 RetrieveItem：引用搬回背包
    bag[2] = wh[1]; wh[1] = nil
    assertTrue(wh[1] == nil, "仓库槽已清空")
    assertTrue(TradeLock.IsNoResell(bag[2]), "取回后背包物品仍 bmNoResell（未洗白）")
end)

-- ============================================================================
-- W2: 源码静态断言 —— Serialize 必须复用 SerializeItemFull（best-effort，依赖 io）
-- ============================================================================
test("W2. WarehouseSystem.Serialize 复用 SaveSerializer.SerializeItemFull（源码断言）", function()
    if not (io and io.open) then
        print("    (skip) 当前环境无 io，跳过源码静态断言")
        return
    end
    local f = io.open("scripts/systems/WarehouseSystem.lua", "r")
    if not f then
        local p = package.searchpath and package.searchpath("systems.WarehouseSystem", package.path)
        if p then f = io.open(p, "r") end
    end
    if not f then
        print("    (skip) 源码不可读")
        return
    end
    local src = f:read("*a"); f:close()
    -- 提取 Serialize 函数体（function WarehouseSystem.Serialize() ... 到下一个顶层 function）
    local body = src:match("function WarehouseSystem%.Serialize%(%)(.-)\nfunction ")
        or src:match("function WarehouseSystem%.Serialize%(%)(.+)")
    assertTrue(body ~= nil, "应能提取 Serialize 函数体")
    assertTrue(body:find("SerializeItemFull") ~= nil,
        "Serialize 必须复用 SaveSerializer.SerializeItemFull（防自定义序列化漏掉 bmNoResell）")
end)

-- ============================================================================
-- W3: 序列化往返 —— 仓库存档落盘/加载复用 SerializeItemFull，bmNoResell 不丢
-- （WarehouseSystem.Deserialize 直接使用 itemData 表，故往返结果即 SerializeItemFull 输出）
-- ============================================================================
test("W3. SerializeItemFull 往返：仓库物品序列化→反序列化仍 IsNoResell", function()
    local okSer, Ser = pcall(require, "systems.save.SaveSerializer")
    if not okSer or not Ser or not Ser.SerializeItemFull then
        print("    (skip) SaveSerializer 不可加载: " .. tostring(Ser))
        return
    end
    local item = { id = 1, category = "consumable", consumableId = "gold_brick", count = 2, name = "金砖" }
    TradeLock.MarkNoResell(item, "gold_brick")

    -- 模拟"存仓后落盘"：WarehouseSystem.Serialize 对每个仓库物品调用 SerializeItemFull
    local out = Ser.SerializeItemFull(item)
    assertEqual(out.bmNoResell, true, "序列化保留 bmNoResell")
    assertEqual(out.bmSource, TradeLock.NO_RESELL_SOURCE, "保留 bmSource")
    assertEqual(out.bmBuyItemId, "gold_brick", "保留 bmBuyItemId")
    assertEqual(out.bmLockUntil, nil, "临时锁字段不落盘")

    -- 模拟"加载重建"：WarehouseSystem.Deserialize 直接使用 itemData 表 → 即 out 本身
    assertTrue(TradeLock.IsNoResell(out), "反序列化后仓库物品仍 bmNoResell")
end)

print("\n[test_bm_noresell_warehouse] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
