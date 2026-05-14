-- ============================================================================
-- test_bm_fix01_card_sell_split.lua
-- BM-FIX-01 + HOTFIX-SELL-01: 黑市商品级可售逻辑纠偏 — 4 条真实路径验证
--
-- 验证目标（直接对应 BM-FIX-01 §7 + HOTFIX-SELL-01 §6）：
--   路径1: A锁住，B未锁 → A显示🔒锁定，B显示出售
--   路径2: 顶部全局未同步时 → B仍显示出售
--          HOTFIX-SELL-01: onClick/confirm 也不再被 L2 拦截
--   路径3: 不再出现"整个黑市所有商品卡变成不可售/同步中"
--   路径4: 锁图标、强制新堆、按钮缺失修复不回退
--
-- 纯 Lua 测试，无引擎依赖。
-- ============================================================================

local TAG = "[test_bm_fix01]"

-- ============================================================================
-- 测试基础设施
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

print("\n" .. TAG .. " === BM-FIX-01 商品级可售逻辑纠偏测试 ===\n")

-- ============================================================================
-- Mock 基础设施
-- ============================================================================

local _origLoaded = {}
local _modulesToReset = {
    "core.EventBus",
    "systems.BlackMarketTradeLock",
    "systems.InventorySystem",
    "systems.BlackMarketSyncState",
    "systems.save.SaveSession",
    "config.GameConfig",
    "config.BlackMerchantConfig",
}
for _, k in ipairs(_modulesToReset) do
    _origLoaded[k] = package.loaded[k]
    package.loaded[k] = nil
end

-- EventBus mock
local _eventHandlers = {}
package.loaded["core.EventBus"] = {
    On = function(event, cb)
        if not _eventHandlers[event] then _eventHandlers[event] = {} end
        table.insert(_eventHandlers[event], cb)
    end,
    Emit = function(event, ...)
        local cbs = _eventHandlers[event]
        if cbs then for _, cb in ipairs(cbs) do cb(...) end end
    end,
    Off = function() end,
}

-- 背包 mock — 支持任意物品设定
local _backpack = {}
local _lockedItems = {}

package.loaded["systems.BlackMarketTradeLock"] = {
    HasAnyLockedConsumable = function(_, _, consumableId)
        return _lockedItems[consumableId] or false
    end,
    ClearAllOnSaveSuccess = function()
        _lockedItems = {}
    end,
    IsLocked = function(item)
        if not item then return false end
        if not item.bmLockUntil then return false end
        return os.time() < item.bmLockUntil
    end,
    LOCK_MESSAGE = "该商品处于黑市交易保护期，请稍后再试",
}

package.loaded["systems.InventorySystem"] = {
    GetManager = function() return nil end,
    HasAnyLockedConsumable = function(consumableId)
        return _lockedItems[consumableId] or false
    end,
}

package.loaded["config.GameConfig"] = {
    BACKPACK_SIZE = 40,
}

-- BMConfig mock — 提供商品表
package.loaded["config.BlackMerchantConfig"] = {
    ITEMS = {
        herb_001 = { name = "灵草", sell_price = 10, buy_price = 5, max_stock = 99, itemType = "consumable" },
        herb_002 = { name = "仙果", sell_price = 20, buy_price = 10, max_stock = 99, itemType = "consumable" },
        herb_003 = { name = "丹药", sell_price = 30, buy_price = 15, max_stock = 99, itemType = "consumable" },
    },
}

-- 加载被测模块
local SaveSession = require("systems.save.SaveSession")
local SyncState   = require("systems.BlackMarketSyncState")
local EventBus    = require("core.EventBus")

-- game_saved 时清锁（模拟真实 InventoryManager 行为）
EventBus.On("game_saved", function()
    _lockedItems = {}
end)

-- ============================================================================
-- 模拟卡片级决策函数（完全复刻 BlackMerchantUI.BuildItemCard 的逻辑）
-- ============================================================================

--- 模拟 BuildItemCard 中的商品卡决策，返回 {canSell, btnText, onClick 行为}
---@param itemId string
---@param held number
---@param stock number
---@param realmOk boolean
---@return table {canSell:boolean, btnText:string}
local function simulateCardDecision(itemId, held, stock, realmOk)
    local BMConfig = package.loaded["config.BlackMerchantConfig"]
    local cfg = BMConfig.ITEMS[itemId]
    local maxStock = cfg and cfg.max_stock or 99

    local sellBlockReason = SyncState.GetSellBlockReason(itemId)
    -- PRE-C5-A1 Principle B: 卡片级 canSell 只查 L1
    local canSell = realmOk and held > 0 and stock < maxStock and sellBlockReason ~= "locked_item"
    -- PRE-C5-A1 Principle B: 卡片只显示 L1 状态
    local btnText = sellBlockReason == "locked_item" and "🔒锁定" or "出售"

    return { canSell = canSell, btnText = btnText }
end

--- 模拟 onClick 中的实时拦截（HOTFIX-SELL-01: 仅 L1 拦截，L2 不再阻止）
---@param itemId string
---@return string|nil blockReason nil=放行, "locked_item"=拦截
local function simulateOnClickBlock(itemId)
    local curReason = SyncState.GetSellBlockReason(itemId)
    if curReason == "locked_item" then
        return "locked_item"
    end
    -- HOTFIX-SELL-01: global_unsync 不再拦截 onClick
    return nil
end

--- 模拟确认弹窗最终防线（HOTFIX-SELL-01: 仅 L1 拦截，L2 不再阻止）
---@param itemId string
---@return string|nil blockReason nil=放行, "locked_item"=拦截
local function simulateConfirmBlock(itemId)
    local cfmReason = SyncState.GetSellBlockReason(itemId)
    if cfmReason == "locked_item" then
        return "locked_item"
    end
    -- HOTFIX-SELL-01: global_unsync 不再拦截确认弹窗
    return nil
end

-- ============================================================================
-- 路径 1: A锁住，B未锁 → A显示🔒锁定，B显示出售
-- ============================================================================

print("  --- 路径1: A锁住，B未锁 ---")

test("P1-1: A锁住 → 卡片显示🔒锁定，canSell=false", function()
    _lockedItems = { herb_001 = true }
    SyncState.ClearAll()

    local cardA = simulateCardDecision("herb_001", 10, 5, true)
    assertEqual(cardA.btnText, "🔒锁定", "A按钮文本")
    assertFalse(cardA.canSell, "A不可售")
end)

test("P1-2: B未锁 → 卡片显示出售，canSell=true", function()
    _lockedItems = { herb_001 = true }  -- 只有A锁
    SyncState.ClearAll()

    local cardB = simulateCardDecision("herb_002", 10, 5, true)
    assertEqual(cardB.btnText, "出售", "B按钮文本")
    assertTrue(cardB.canSell, "B可售")
end)

test("P1-3: C未锁 → 卡片显示出售，canSell=true", function()
    _lockedItems = { herb_001 = true }  -- 只有A锁
    SyncState.ClearAll()

    local cardC = simulateCardDecision("herb_003", 5, 0, true)
    assertEqual(cardC.btnText, "出售", "C按钮文本")
    assertTrue(cardC.canSell, "C可售")
end)

test("P1-4: A锁住不影响其他商品的 GetSellBlockReason", function()
    _lockedItems = { herb_001 = true }
    SyncState.ClearAll()

    local rA = SyncState.GetSellBlockReason("herb_001")
    local rB = SyncState.GetSellBlockReason("herb_002")
    local rC = SyncState.GetSellBlockReason("herb_003")
    assertEqual(rA, "locked_item", "A → locked_item")
    assertEqual(rB, "none", "B → none")
    assertEqual(rC, "none", "C → none")
end)

-- ============================================================================
-- 路径 2: 全局未同步时 → B仍显示出售，确认出售被挡
-- ============================================================================

print("  --- 路径2: 全局未同步 → 卡片不受影响，提交阶段拦截 ---")

test("P2-1: L2脏 → B卡片仍显示出售、canSell=true", function()
    _lockedItems = {}
    SyncState.ClearAll()
    SyncState.MarkConsumeUsed("some_consume")

    local cardB = simulateCardDecision("herb_002", 10, 5, true)
    assertEqual(cardB.btnText, "出售", "L2脏时B卡片仍显示出售")
    assertTrue(cardB.canSell, "L2脏时B卡片仍可售")
end)

test("P2-2: HOTFIX-SELL-01: L2脏 → onClick不再拦截，放行", function()
    _lockedItems = {}
    SyncState.ClearAll()
    SyncState.MarkConsumeUsed("some_consume")

    local block = simulateOnClickBlock("herb_002")
    assertEqual(block, nil, "HOTFIX-SELL-01: onClick不再被L2拦截")
end)

test("P2-3: HOTFIX-SELL-01: L2脏 → 确认弹窗不再拦截，放行", function()
    _lockedItems = {}
    SyncState.ClearAll()
    SyncState.MarkWarehouseOp("test_warehouse")

    local block = simulateConfirmBlock("herb_002")
    assertEqual(block, nil, "HOTFIX-SELL-01: 确认弹窗不再被L2拦截")
end)

test("P2-4: L2脏 + A锁住 → A显示🔒锁定，B显示出售，两者独立", function()
    _lockedItems = { herb_001 = true }
    SyncState.ClearAll()
    SyncState.MarkConsumeUsed("unrelated")

    local cardA = simulateCardDecision("herb_001", 10, 5, true)
    local cardB = simulateCardDecision("herb_002", 10, 5, true)

    assertEqual(cardA.btnText, "🔒锁定", "A显示🔒锁定（L1）")
    assertFalse(cardA.canSell, "A不可售（L1）")

    assertEqual(cardB.btnText, "出售", "B显示出售（L2不影响卡片）")
    assertTrue(cardB.canSell, "B卡片可售（L2不影响卡片）")

    -- HOTFIX-SELL-01: B 的 onClick 也不再被 L2 拦截
    local blockB = simulateOnClickBlock("herb_002")
    assertEqual(blockB, nil, "HOTFIX-SELL-01: B的onClick不再被L2拦截")
end)

test("P2-5: HOTFIX-SELL-01: SaveSession脏 → 卡片仍显示出售，onClick也放行", function()
    _lockedItems = {}
    SyncState.ClearAll()
    SaveSession.MarkDirty()

    local cardB = simulateCardDecision("herb_002", 10, 5, true)
    assertEqual(cardB.btnText, "出售", "SaveSession脏 → 卡片仍出售")
    assertTrue(cardB.canSell, "SaveSession脏 → 卡片可售")

    local block = simulateOnClickBlock("herb_002")
    assertEqual(block, nil, "HOTFIX-SELL-01: SaveSession脏 → onClick也不拦截")

    -- 清理
    EventBus.Emit("game_saved")
end)

-- ============================================================================
-- 路径 3: 不再出现"整市场商品卡都变成不可售/同步中"
-- ============================================================================

print("  --- 路径3: 不再出现整市场不可售 ---")

test("P3-1: L2脏 → 3个商品卡都仍显示出售", function()
    _lockedItems = {}
    SyncState.ClearAll()
    SyncState.MarkConsumeUsed("consume_x")
    SyncState.MarkWarehouseOp("warehouse_y")

    local items = { "herb_001", "herb_002", "herb_003" }
    for _, id in ipairs(items) do
        local card = simulateCardDecision(id, 10, 5, true)
        assertEqual(card.btnText, "出售", "P3-1: " .. id .. " 按钮文本应为出售")
        assertTrue(card.canSell, "P3-1: " .. id .. " 应可售")
    end
end)

test("P3-2: 按钮文本永远不会出现'⏳同步中'", function()
    -- 场景1: L2 脏
    _lockedItems = {}
    SyncState.ClearAll()
    SyncState.MarkConsumeUsed("x")

    local reason = SyncState.GetSellBlockReason("herb_001")
    local text = reason == "locked_item" and "🔒锁定" or "出售"
    assertTrue(text ~= "⏳同步中", "L2脏 → 按钮不应出现⏳同步中")
    assertEqual(text, "出售", "L2脏 → 按钮文本应为出售")

    -- 场景2: SaveSession 脏
    SyncState.ClearAll()
    SaveSession.MarkDirty()

    local reason2 = SyncState.GetSellBlockReason("herb_001")
    local text2 = reason2 == "locked_item" and "🔒锁定" or "出售"
    assertTrue(text2 ~= "⏳同步中", "SaveSession脏 → 按钮不应出现⏳同步中")
    assertEqual(text2, "出售", "SaveSession脏 → 按钮文本应为出售")

    EventBus.Emit("game_saved")
end)

test("P3-3: 只有L1锁住的那1个商品显示🔒锁定，其余全部显示出售", function()
    _lockedItems = { herb_002 = true }  -- 只锁 herb_002
    SyncState.ClearAll()

    local card1 = simulateCardDecision("herb_001", 10, 5, true)
    local card2 = simulateCardDecision("herb_002", 10, 5, true)
    local card3 = simulateCardDecision("herb_003", 10, 5, true)

    assertEqual(card1.btnText, "出售", "herb_001 出售")
    assertEqual(card2.btnText, "🔒锁定", "herb_002 🔒锁定")
    assertEqual(card3.btnText, "出售", "herb_003 出售")

    assertTrue(card1.canSell, "herb_001 可售")
    assertFalse(card2.canSell, "herb_002 不可售")
    assertTrue(card3.canSell, "herb_003 可售")
end)

test("P3-4: L1+L2同时存在 → 只有被锁的商品显示🔒，其余仍出售", function()
    _lockedItems = { herb_001 = true }
    SyncState.ClearAll()
    SyncState.MarkWarehouseOp("test")

    local card1 = simulateCardDecision("herb_001", 10, 5, true)
    local card2 = simulateCardDecision("herb_002", 10, 5, true)
    local card3 = simulateCardDecision("herb_003", 10, 5, true)

    assertEqual(card1.btnText, "🔒锁定", "L1锁的商品显示🔒锁定")
    assertEqual(card2.btnText, "出售", "未锁商品显示出售")
    assertEqual(card3.btnText, "出售", "未锁商品显示出售")

    -- HOTFIX-SELL-01: 未锁商品的 onClick 不再被 L2 拦截
    assertEqual(simulateOnClickBlock("herb_002"), nil)
    assertEqual(simulateOnClickBlock("herb_003"), nil)

    SyncState.ClearAll()
end)

-- ============================================================================
-- 路径 4: 已有修复不回退
-- ============================================================================

print("  --- 路径4: 已有修复不回退 ---")

test("P4-1: 锁图标存在 — GetSellBlockReason 对锁定商品返回 locked_item", function()
    _lockedItems = { herb_001 = true }
    SyncState.ClearAll()

    local reason = SyncState.GetSellBlockReason("herb_001")
    assertEqual(reason, "locked_item", "锁定商品返回locked_item")
end)

test("P4-2: game_saved → 锁清除 → 商品恢复可售", function()
    _lockedItems = { herb_001 = true }
    SyncState.ClearAll()

    -- 存档前锁住
    local before = simulateCardDecision("herb_001", 10, 5, true)
    assertFalse(before.canSell, "存档前不可售")
    assertEqual(before.btnText, "🔒锁定", "存档前🔒锁定")

    -- game_saved
    EventBus.Emit("game_saved")

    -- 存档后解锁
    local after = simulateCardDecision("herb_001", 10, 5, true)
    assertTrue(after.canSell, "存档后可售")
    assertEqual(after.btnText, "出售", "存档后出售")
end)

test("P4-3: HOTFIX-SELL-01: onClick仅L1拦截 — L1拦截 → L2放行 → 全清放行", function()
    -- 场景1: L1 拦截
    _lockedItems = { herb_001 = true }
    SyncState.ClearAll()
    assertEqual(simulateOnClickBlock("herb_001"), "locked_item", "L1拦截")

    -- 场景2: HOTFIX-SELL-01: L2 不再拦截（无L1）
    _lockedItems = {}
    SyncState.MarkConsumeUsed("x")
    assertEqual(simulateOnClickBlock("herb_001"), nil, "HOTFIX-SELL-01: L2不再拦截onClick")

    -- 场景3: 全部清除 → 放行
    SyncState.ClearAll()
    assertEqual(simulateOnClickBlock("herb_001"), nil, "无阻断 → 放行")
end)

test("P4-4: HOTFIX-SELL-01: 确认弹窗仅L1拦截 — L1拦截 → L2放行 → 全清放行", function()
    -- 场景1: L1 拦截
    _lockedItems = { herb_001 = true }
    SyncState.ClearAll()
    assertEqual(simulateConfirmBlock("herb_001"), "locked_item", "确认L1拦截")

    -- 场景2: HOTFIX-SELL-01: L2 不再拦截
    _lockedItems = {}
    SyncState.MarkWarehouseOp("x")
    assertEqual(simulateConfirmBlock("herb_001"), nil, "HOTFIX-SELL-01: L2不再拦截确认弹窗")

    -- 场景3: 放行
    SyncState.ClearAll()
    assertEqual(simulateConfirmBlock("herb_001"), nil, "确认放行")
end)

test("P4-5: canSell 公式不查 global_unsync — 只排除 locked_item", function()
    -- 验证 canSell 决策逻辑只用 reason ~= "locked_item"
    SyncState.ClearAll()

    -- locked_item → canSell = false
    _lockedItems = { herb_001 = true }
    local r1 = SyncState.GetSellBlockReason("herb_001")
    local canSell1 = (r1 ~= "locked_item")
    assertFalse(canSell1, "locked_item → canSell公式=false")

    -- global_unsync → canSell = true（卡片不受L2影响）
    _lockedItems = {}
    SyncState.MarkConsumeUsed("x")
    local r2 = SyncState.GetSellBlockReason("herb_001")
    local canSell2 = (r2 ~= "locked_item")
    assertTrue(canSell2, "global_unsync → canSell公式=true（卡片不受L2影响）")

    -- none → canSell = true
    SyncState.ClearAll()
    local r3 = SyncState.GetSellBlockReason("herb_001")
    local canSell3 = (r3 ~= "locked_item")
    assertTrue(canSell3, "none → canSell公式=true")
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
    "\n%s TOTAL: %d  PASSED: %d  FAILED: %d\n",
    TAG, total, passed, failed
))

return { passed = passed, failed = failed, total = total }
