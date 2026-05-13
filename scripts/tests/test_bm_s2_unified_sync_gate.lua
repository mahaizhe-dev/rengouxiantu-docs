-- ============================================================================
-- test_bm_s2_unified_sync_gate.lua — BM-S2 统一黑市未同步门禁测试
--
-- 测试层次：
--   A. 状态层：哪些操作置脏，哪些事件清脏
--   B. 行为层：黑市卖出是否在脏状态下被正确拦截
--
-- 验证范围（9.1 必测场景）：
--   T1.  初始状态：门禁不阻断
--   T2.  MarkConsumeUsed 置消耗脏 → IsBlocked = true
--   T3.  MarkWarehouseOp 置仓库脏 → IsBlocked = true
--   T4.  SaveSession 活跃 → IsBlocked = true
--   T5.  game_saved 清除所有脏标记
--   T6.  game_loaded 清除所有脏标记
--   T7.  仓库存入后 → IsBlocked = true（行为层）
--   T8.  仓库取出后 → IsBlocked = true（行为层）
--   T9.  ConsumeConsumable(令牌盒) → IsBlocked = true（行为层）
--   T10. ConsumeConsumable(gold_brick) → IsBlocked = true（行为层）
--   T11. ConsumeConsumable(附灵玉) → IsBlocked = true（行为层）
--   T12. 正常未脏状态 → IsBlocked = false, 卖出不被拦截
--   T13. ClearAll 后 → IsBlocked = false
--   T14. 消耗脏和仓库脏独立：清消耗不影响仓库
--   T15. 旧白名单兼容：_BM_SENSITIVE_CONSUMABLES 为空表
--
-- 纯 Lua 测试，通过 stub 替代引擎依赖。
-- ============================================================================

local passed = 0
local failed = 0
local total  = 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  \226\156\147 " .. name)
    else
        failed = failed + 1
        print("  \226\156\151 " .. name .. ": " .. tostring(err))
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

print("\n[test_bm_s2_unified_sync_gate] === BM-S2 统一黑市未同步门禁测试 ===\n")

-- ============================================================================
-- Stubs
-- ============================================================================

-- EventBus stub: 追踪事件发射和允许手动触发回调
local _eventHandlers = {}
local _eventLog = {}

package.loaded["core.EventBus"] = {
    Emit = function(name, ...)
        _eventLog[#_eventLog + 1] = name
        if _eventHandlers[name] then
            for _, fn in ipairs(_eventHandlers[name]) do
                fn(...)
            end
        end
    end,
    On = function(name, fn)
        if not _eventHandlers[name] then
            _eventHandlers[name] = {}
        end
        table.insert(_eventHandlers[name], fn)
    end,
}

-- GameState stub
local _playerMeta = {
    __index = {
        GetTotalMaxHp = function(self) return self.maxHp or 99999 end,
    },
}
local _stubPlayer = setmetatable({ gold = 999999, hp = 100, maxHp = 99999 }, _playerMeta)

package.loaded["core.GameState"] = {
    player = _stubPlayer,
    warehouse = {
        unlockedRows = 2,
        items = {},
    },
}

-- GameConfig stub
package.loaded["config.GameConfig"] = {
    BACKPACK_SIZE = 30,
    CONSUMABLES = {
        wubao_token_box  = { name = "乌堡令盒", sellPrice = 100 },
        gold_brick       = { name = "金砖", sellPrice = 50000, sellCurrency = "gold" },
        lingyu_basic     = { name = "基础附灵玉", sellPrice = 10 },
        herb_pill        = { name = "草药丸", sellPrice = 5 },
    },
}

-- EquipmentData stub
package.loaded["config.EquipmentData"] = {
    SLOTS = { "weapon", "armor", "helmet", "boots", "ring1", "ring2", "necklace", "belt", "gloves", "pants" },
    SetBonuses = {},
    SpecialEquipment = {},
}

-- SkillSystem stub
package.loaded["systems.SkillSystem"] = {
    equippedSkills = {},
    BindEquipSkill = function() end,
    UnbindEquipSkill = function() end,
    BindExclusiveSkill = function() end,
    UnbindExclusiveSkill = function() end,
}

-- WineSystem stub (RecalcEquipStats 末尾 pcall 加载)
package.loaded["systems.WineSystem"] = {
    RecalcWineStats = function() end,
}

-- WarehouseConfig stub
package.loaded["config.WarehouseConfig"] = {
    INITIAL_UNLOCKED_ROWS = 2,
    ITEMS_PER_ROW = 8,
    MAX_ROWS = 6,
    MAX_SLOTS = 48,
    GetRowCost = function(row) return row * 10000 end,
}

-- UI stub
package.loaded["urhox-libs/UI"] = {
    InventoryManager = {
        new = function(cfg)
            local mgr = {
                _inv = {},
                _equip = cfg.equipmentSlots or {},
                onChange = nil,
            }
            function mgr:AddToInventory(item)
                for i = 1, (cfg.inventorySize or 30) do
                    if not self._inv[i] then
                        self._inv[i] = item
                        if self.onChange then self.onChange() end
                        return true, i
                    end
                end
                return false, nil
            end
            function mgr:GetInventoryItem(idx) return self._inv[idx] end
            function mgr:SetInventoryItem(idx, item)
                self._inv[idx] = item
                if self.onChange then self.onChange() end
            end
            function mgr:GetAllEquipment() return self._equip end
            return mgr
        end,
    },
}

-- 清除缓存确保新模块加载
package.loaded["systems.BlackMarketSyncState"] = nil
package.loaded["systems.save.SaveSession"] = nil
package.loaded["systems.WarehouseSystem"] = nil
package.loaded["systems.InventorySystem"] = nil

-- 加载模块
local BlackMarketSyncState = require("systems.BlackMarketSyncState")
local SaveSession = require("systems.save.SaveSession")

-- 重置函数
local function resetAll()
    BlackMarketSyncState._dirtyConsume = false
    BlackMarketSyncState._dirtyWarehouse = false
    _eventLog = {}
end

-- ============================================================================
-- A. 状态层测试
-- ============================================================================

print("  --- 状态层 ---")

test("T1: 初始状态 — 门禁不阻断", function()
    resetAll()
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertFalse(blocked, "should not be blocked initially")
    assertEqual(reason, nil, "reason should be nil")
end)

test("T2: MarkConsumeUsed → 消耗脏 → IsBlocked", function()
    resetAll()
    BlackMarketSyncState.MarkConsumeUsed("wubao_token_box")
    assertTrue(BlackMarketSyncState.IsConsumeDirty(), "consume should be dirty")
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertTrue(blocked, "should be blocked after consume")
    assertEqual(reason, "consume_unsync", "reason")
end)

test("T3: MarkWarehouseOp → 仓库脏 → IsBlocked", function()
    resetAll()
    BlackMarketSyncState.MarkWarehouseOp("store")
    assertTrue(BlackMarketSyncState.IsWarehouseDirty(), "warehouse should be dirty")
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertTrue(blocked, "should be blocked after warehouse op")
    assertEqual(reason, "warehouse_unsync", "reason")
end)

test("T4: SaveSession 活跃 → IsBlocked", function()
    resetAll()
    -- 手动激活 SaveSession
    SaveSession.MarkDirty()
    assertTrue(SaveSession.IsDirty(), "SaveSession should be dirty")
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertTrue(blocked, "should be blocked when SaveSession active")
    assertEqual(reason, "save_session_active", "reason")
    -- 清理: flush SaveSession
    SaveSession.Flush()
end)

test("T5: game_saved 清除所有脏标记", function()
    resetAll()
    BlackMarketSyncState.MarkConsumeUsed("test_item")
    BlackMarketSyncState.MarkWarehouseOp("test_op")
    assertTrue(BlackMarketSyncState.IsBlocked())
    -- 模拟 game_saved
    local EventBus = require("core.EventBus")
    EventBus.Emit("game_saved")
    assertFalse(BlackMarketSyncState.IsConsumeDirty(), "consume should be clean after game_saved")
    assertFalse(BlackMarketSyncState.IsWarehouseDirty(), "warehouse should be clean after game_saved")
end)

test("T6: game_loaded 清除所有脏标记", function()
    resetAll()
    BlackMarketSyncState.MarkConsumeUsed("test_item")
    BlackMarketSyncState.MarkWarehouseOp("test_op")
    assertTrue(BlackMarketSyncState.IsBlocked())
    local EventBus = require("core.EventBus")
    EventBus.Emit("game_loaded")
    assertFalse(BlackMarketSyncState.IsConsumeDirty(), "consume should be clean after game_loaded")
    assertFalse(BlackMarketSyncState.IsWarehouseDirty(), "warehouse should be clean after game_loaded")
end)

test("T13: ClearAll 后 → IsBlocked = false", function()
    resetAll()
    BlackMarketSyncState.MarkConsumeUsed("x")
    BlackMarketSyncState.MarkWarehouseOp("y")
    BlackMarketSyncState.ClearAll()
    local blocked = BlackMarketSyncState.IsBlocked()
    assertFalse(blocked, "should not be blocked after ClearAll")
end)

test("T14: 消耗脏和仓库脏独立", function()
    resetAll()
    BlackMarketSyncState.MarkConsumeUsed("a")
    BlackMarketSyncState.MarkWarehouseOp("b")
    -- 只清消耗
    BlackMarketSyncState._dirtyConsume = false
    assertFalse(BlackMarketSyncState.IsConsumeDirty())
    assertTrue(BlackMarketSyncState.IsWarehouseDirty(), "warehouse still dirty")
    assertTrue(BlackMarketSyncState.IsBlocked(), "still blocked by warehouse")
end)

-- ============================================================================
-- B. 行为层测试
-- ============================================================================

print("  --- 行为层 ---")

-- 初始化 InventorySystem 和 WarehouseSystem
local InventorySystem = require("systems.InventorySystem")
InventorySystem.Init()
local WarehouseSystem = require("systems.WarehouseSystem")
WarehouseSystem.Init()
local GameState = require("core.GameState")

--- 辅助：向背包添加消耗品
local function addConsumable(id, count)
    local mgr = InventorySystem.GetManager()
    for i = 1, (count or 1) do
        mgr:AddToInventory({
            category = "consumable",
            consumableId = id,
            name = id,
            count = 1,
        })
    end
end

--- 辅助：重置背包和仓库状态
local function resetGame()
    resetAll()
    -- 清空事件日志
    _eventLog = {}
    -- 重新初始化仓库
    GameState.warehouse = { unlockedRows = 2, items = {} }
    GameState.player = setmetatable({ gold = 999999, hp = 100, maxHp = 99999 }, _playerMeta)
    WarehouseSystem._dirty = false
    -- 清空背包
    local mgr = InventorySystem.GetManager()
    for i = 1, 30 do
        mgr:SetInventoryItem(i, nil)
    end
end

test("T7: 仓库存入后 → IsBlocked = true", function()
    resetGame()
    -- 放一个物品到背包
    addConsumable("herb_pill", 1)
    -- 存入仓库
    local ok = WarehouseSystem.StoreItem(1)
    assertTrue(ok, "store should succeed")
    -- 验证门禁
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertTrue(blocked, "should be blocked after store")
    assertEqual(reason, "warehouse_unsync", "reason should be warehouse_unsync (consume also set, but warehouse checked first after consume in order)")
end)

test("T8: 仓库取出后 → IsBlocked = true", function()
    resetGame()
    -- 先放物品到仓库
    GameState.warehouse.items[1] = { category = "consumable", consumableId = "herb_pill", name = "草药丸", count = 1 }
    -- 取出
    local ok = WarehouseSystem.RetrieveItem(1)
    assertTrue(ok, "retrieve should succeed")
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertTrue(blocked, "should be blocked after retrieve")
end)

test("T9: ConsumeConsumable(令牌盒) → IsBlocked = true", function()
    resetGame()
    addConsumable("wubao_token_box", 1)
    local ok = InventorySystem.ConsumeConsumable("wubao_token_box", 1)
    assertTrue(ok, "consume should succeed")
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertTrue(blocked, "should be blocked after token box consume")
    assertEqual(reason, "consume_unsync", "reason")
end)

test("T10: ConsumeConsumable(gold_brick) → IsBlocked = true", function()
    resetGame()
    addConsumable("gold_brick", 1)
    local ok = InventorySystem.ConsumeConsumable("gold_brick", 1)
    assertTrue(ok, "consume should succeed")
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertTrue(blocked, "should be blocked after gold_brick consume")
    assertEqual(reason, "consume_unsync", "reason")
end)

test("T11: ConsumeConsumable(附灵玉) → IsBlocked = true", function()
    resetGame()
    addConsumable("lingyu_basic", 1)
    local ok = InventorySystem.ConsumeConsumable("lingyu_basic", 1)
    assertTrue(ok, "consume should succeed")
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertTrue(blocked, "should be blocked after lingyu consume")
    assertEqual(reason, "consume_unsync", "reason")
end)

test("T12: 正常未脏状态 → IsBlocked = false", function()
    resetGame()
    local blocked, reason = BlackMarketSyncState.IsBlocked()
    assertFalse(blocked, "should not be blocked in clean state")
    assertEqual(reason, nil, "reason should be nil")
end)

test("T15: 旧白名单兼容 — _BM_SENSITIVE_CONSUMABLES 为空表", function()
    resetGame()
    -- 确认旧字段仍存在但为空
    assertTrue(type(InventorySystem._BM_SENSITIVE_CONSUMABLES) == "table", "should be table")
    assertEqual(next(InventorySystem._BM_SENSITIVE_CONSUMABLES), nil, "should be empty")
end)

-- ============================================================================
-- 汇总
-- ============================================================================

print("\n[test_bm_s2_unified_sync_gate] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
