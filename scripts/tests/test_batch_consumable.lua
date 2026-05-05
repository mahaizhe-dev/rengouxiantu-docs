-- ============================================================================
-- test_batch_consumable.lua - 批量消耗品使用/出售 模拟测试
-- 运行方式：在 GM 控制台中 require("tests.test_batch_consumable")
-- 测试覆盖：金条/金砖批量出售、灵韵果批量使用、修炼果批量使用（含经验上限）
-- 重点验证：无资源复制、无资源凭空产生、原子性、边界条件
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local EventBus = require("core.EventBus")

local TestBatch = {}

-- ============================================================================
-- 测试框架
-- ============================================================================

local passCount = 0
local failCount = 0
local skipCount = 0

local function log(msg)
    print("[TEST] " .. msg)
end

local function assert_eq(name, actual, expected)
    if actual == expected then
        passCount = passCount + 1
        log("  PASS: " .. name .. " = " .. tostring(actual))
    else
        failCount = failCount + 1
        log("  FAIL: " .. name .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

local function assert_true(name, value)
    if value then
        passCount = passCount + 1
        log("  PASS: " .. name)
    else
        failCount = failCount + 1
        log("  FAIL: " .. name .. " (expected true, got " .. tostring(value) .. ")")
    end
end

local function assert_false(name, value)
    if not value then
        passCount = passCount + 1
        log("  PASS: " .. name)
    else
        failCount = failCount + 1
        log("  FAIL: " .. name .. " (expected false, got " .. tostring(value) .. ")")
    end
end

local function assert_gte(name, actual, minimum)
    if actual >= minimum then
        passCount = passCount + 1
        log("  PASS: " .. name .. " = " .. tostring(actual) .. " >= " .. tostring(minimum))
    else
        failCount = failCount + 1
        log("  FAIL: " .. name .. " = " .. tostring(actual) .. " < " .. tostring(minimum))
    end
end

-- ============================================================================
-- 测试工具
-- ============================================================================

--- 本测试涉及的所有消耗品 ID
local ALL_TEST_IDS = { "gold_bar", "gold_brick", "lingyun_fruit", "exp_pill" }

--- 清空所有测试用消耗品（释放背包空间）
local function clearAllTestItems()
    for _, id in ipairs(ALL_TEST_IDS) do
        local c = InventorySystem.CountConsumable(id)
        if c > 0 then
            InventorySystem.ConsumeConsumable(id, c)
        end
    end
end

--- 添加消耗品，返回是否成功
local function give(id, amount)
    local ok = InventorySystem.AddConsumable(id, amount)
    if not ok then
        log("  ⚠ give('" .. id .. "', " .. amount .. ") FAILED — 背包已满")
    end
    return ok
end

--- 检查背包是否有空位可用；没有则打印警告并返回 false
local function hasFreeSlot()
    local free = InventorySystem.GetFreeSlots and InventorySystem.GetFreeSlots() or 999
    return free > 0
end

-- ============================================================================
-- T1: 金条批量出售
-- ============================================================================
function TestBatch.T1_GoldBarSell()
    log("=== T1: 金条批量出售 ===")
    local player = GameState.player
    if not player then log("  SKIP: 无玩家"); skipCount = skipCount + 1; return end

    clearAllTestItems()
    if not hasFreeSlot() then log("  SKIP: 背包已满"); skipCount = skipCount + 1; return end

    local initGold = player.gold

    -- 放入 25 个金条
    if not give("gold_bar", 25) then log("  SKIP: 无法添加金条"); skipCount = skipCount + 1; return end
    assert_eq("初始金条数", InventorySystem.CountConsumable("gold_bar"), 25)

    -- 1a: 出售 ×10
    local ok, msg, actual = InventorySystem.UseBatchConsumable("gold_bar", 10)
    assert_true("出售×10成功", ok)
    assert_eq("实际出售数", actual, 10)
    assert_eq("剩余金条", InventorySystem.CountConsumable("gold_bar"), 15)
    assert_eq("金币增加 10×1000", player.gold - initGold, 10000)

    -- 1b: 出售全部剩余（15）
    local gold2 = player.gold
    ok, msg, actual = InventorySystem.UseBatchConsumable("gold_bar", 15)
    assert_true("出售×15成功", ok)
    assert_eq("实际出售数", actual, 15)
    assert_eq("剩余金条", InventorySystem.CountConsumable("gold_bar"), 0)
    assert_eq("金币增加 15×1000", player.gold - gold2, 15000)

    -- 1c: 空库存出售
    ok = InventorySystem.UseBatchConsumable("gold_bar", 1)
    assert_false("空库存出售失败", ok)

    -- 守恒校验
    assert_eq("总金币收益=25000", player.gold - initGold, 25000)

    log("")
end

-- ============================================================================
-- T2: 灵韵果批量使用
-- ============================================================================
function TestBatch.T2_LingyunFruit()
    log("=== T2: 灵韵果批量使用 ===")
    local player = GameState.player
    if not player then log("  SKIP: 无玩家"); skipCount = skipCount + 1; return end

    clearAllTestItems()
    if not hasFreeSlot() then log("  SKIP: 背包已满"); skipCount = skipCount + 1; return end

    local initLY = player.lingYun or 0

    if not give("lingyun_fruit", 100) then log("  SKIP: 无法添加灵韵果"); skipCount = skipCount + 1; return end
    assert_eq("初始灵韵果数", InventorySystem.CountConsumable("lingyun_fruit"), 100)

    -- 2a: 使用 ×1
    local ok, msg, actual = InventorySystem.UseBatchConsumable("lingyun_fruit", 1)
    assert_true("使用×1成功", ok)
    assert_eq("实际使用数", actual, 1)
    assert_eq("灵韵+50", (player.lingYun or 0) - initLY, 50)

    -- 2b: 使用 ×50
    local ly2 = player.lingYun or 0
    ok, msg, actual = InventorySystem.UseBatchConsumable("lingyun_fruit", 50)
    assert_true("使用×50成功", ok)
    assert_eq("实际使用数", actual, 50)
    assert_eq("灵韵+2500", (player.lingYun or 0) - ly2, 2500)

    -- 2c: 请求 200，实际剩 49 → 夹紧
    local ly3 = player.lingYun or 0
    ok, msg, actual = InventorySystem.UseBatchConsumable("lingyun_fruit", 200)
    assert_true("超额请求夹紧成功", ok)
    assert_eq("实际使用数=49", actual, 49)
    assert_eq("灵韵+2450", (player.lingYun or 0) - ly3, 2450)
    assert_eq("剩余灵韵果=0", InventorySystem.CountConsumable("lingyun_fruit"), 0)

    -- 守恒校验
    assert_eq("总灵韵=100×50=5000", (player.lingYun or 0) - initLY, 5000)

    log("")
end

-- ============================================================================
-- T3: 修炼果批量使用
-- ============================================================================
function TestBatch.T3_ExpPill()
    log("=== T3: 修炼果批量使用 ===")
    local player = GameState.player
    if not player then log("  SKIP: 无玩家"); skipCount = skipCount + 1; return end

    clearAllTestItems()
    if not hasFreeSlot() then log("  SKIP: 背包已满"); skipCount = skipCount + 1; return end

    -- 前置：检查玩家是否已达经验上限（境界卡级时无法吃修炼果，属于正常功能）
    local realmData = GameConfig.REALMS[player.realm]
    local atExpCap = false
    if realmData and player.level >= realmData.maxLevel then
        local curLevelExp = GameConfig.EXP_TABLE[player.level] or 0
        local nextLevelExp = GameConfig.EXP_TABLE[player.level + 1]
        if nextLevelExp then
            local expCap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
            if player.exp >= expCap then
                atExpCap = true
            end
        end
    end

    if not give("exp_pill", 20) then log("  SKIP: 无法添加修炼果"); skipCount = skipCount + 1; return end
    assert_eq("初始修炼果数", InventorySystem.CountConsumable("exp_pill"), 20)

    if atExpCap then
        -- 玩家经验已达境界上限，验证：使用应被拒绝且不消耗物品
        log("  INFO: 玩家经验已达境界上限(realm=" .. player.realm .. " lv=" .. player.level .. "), 验证拒绝逻辑")
        local ok, msg = InventorySystem.UseBatchConsumable("exp_pill", 1)
        assert_false("经验上限-使用被拒绝", ok)
        assert_eq("经验上限-物品未消耗", InventorySystem.CountConsumable("exp_pill"), 20)
        log("  SKIP: 其余修炼果用例因经验上限跳过")
        skipCount = skipCount + 1
    else
        -- 3a: 使用 ×1 — 只验证成功和消耗品数量减少（经验受 titleExpBonus/升级 影响）
        local ok, msg, actual = InventorySystem.UseBatchConsumable("exp_pill", 1)
        assert_true("使用×1成功", ok)
        assert_eq("实际使用数=1", actual, 1)
        assert_eq("剩余修炼果=19", InventorySystem.CountConsumable("exp_pill"), 19)

        -- 3b: 使用 ×10
        ok, msg, actual = InventorySystem.UseBatchConsumable("exp_pill", 10)
        assert_true("使用×10成功", ok)
        assert_eq("实际使用数=10", actual, 10)
        assert_eq("剩余修炼果=9", InventorySystem.CountConsumable("exp_pill"), 9)
    end

    -- 3c: 清空后无库存（独立于经验上限）
    clearAllTestItems()
    local ok2 = InventorySystem.UseBatchConsumable("exp_pill", 1)
    assert_false("空库存使用失败", ok2)

    log("")
end

-- ============================================================================
-- T4: 安全性 — 资源复制检测
-- ============================================================================
function TestBatch.T4_Security()
    log("=== T4: 安全性 - 资源复制检测 ===")
    local player = GameState.player
    if not player then log("  SKIP: 无玩家"); skipCount = skipCount + 1; return end

    clearAllTestItems()
    if not hasFreeSlot() then log("  SKIP: 背包已满"); skipCount = skipCount + 1; return end

    -- 4a: ConsumeConsumable 拒绝超额消耗
    give("gold_bar", 5)
    local ok = InventorySystem.ConsumeConsumable("gold_bar", 10)
    assert_false("超额消耗被拒绝", ok)
    assert_eq("物品未变", InventorySystem.CountConsumable("gold_bar"), 5)
    clearAllTestItems()

    -- 4b: 连续出售守恒
    if not hasFreeSlot() then log("  SKIP: 背包已满(4b)"); skipCount = skipCount + 1; return end
    give("gold_bar", 3)
    local g0 = player.gold
    local ok1, _, a1 = InventorySystem.UseBatchConsumable("gold_bar", 1)
    local ok2, _, a2 = InventorySystem.UseBatchConsumable("gold_bar", 1)
    local ok3, _, a3 = InventorySystem.UseBatchConsumable("gold_bar", 1)
    local ok4 = InventorySystem.UseBatchConsumable("gold_bar", 1)
    assert_true("第1次成功", ok1)
    assert_true("第2次成功", ok2)
    assert_true("第3次成功", ok3)
    assert_false("第4次失败", ok4)
    assert_eq("剩余=0", InventorySystem.CountConsumable("gold_bar"), 0)
    assert_eq("总金币=3000", player.gold - g0, 3000)

    -- 4c: 零/负数量防护
    clearAllTestItems()
    if not hasFreeSlot() then log("  SKIP: 背包已满(4c)"); skipCount = skipCount + 1; return end
    give("gold_bar", 10)
    local ok0 = InventorySystem.UseBatchConsumable("gold_bar", 0)
    assert_false("零数量被拒绝", ok0)
    local okN = InventorySystem.UseBatchConsumable("gold_bar", -5)
    assert_false("负数量被拒绝", okN)
    assert_eq("物品未变=10", InventorySystem.CountConsumable("gold_bar"), 10)
    clearAllTestItems()

    log("")
end

-- ============================================================================
-- T5: 不支持的消耗品类型 + 非法参数
-- ============================================================================
function TestBatch.T5_Unsupported()
    log("=== T5: 不支持的消耗品类型 ===")

    local ok
    ok = InventorySystem.UseBatchConsumable("meat_bone", 1)
    assert_false("宠物食物不支持批量", ok)

    ok = InventorySystem.UseBatchConsumable("nonexistent_item", 1)
    assert_false("不存在的物品", ok)

    ok = InventorySystem.UseBatchConsumable(nil, 1)
    assert_false("nil consumableId", ok)

    ok = InventorySystem.UseBatchConsumable("gold_bar", nil)
    assert_false("nil count", ok)

    log("")
end

-- ============================================================================
-- T6: UseLingyunFruit 单次使用 + 事件触发
-- ============================================================================
function TestBatch.T6_LingyunFruitEvent()
    log("=== T6: UseLingyunFruit 事件触发 ===")
    local player = GameState.player
    if not player then log("  SKIP: 无玩家"); skipCount = skipCount + 1; return end

    clearAllTestItems()
    if not hasFreeSlot() then log("  SKIP: 背包已满"); skipCount = skipCount + 1; return end

    give("lingyun_fruit", 1)

    local eventFired = false
    local handler = function() eventFired = true end
    EventBus.On("player_lingyun_change", handler)

    local prevLY = player.lingYun or 0
    local ok = InventorySystem.UseLingyunFruit()
    assert_true("单次使用成功", ok)
    assert_true("事件已触发", eventFired)
    assert_eq("灵韵+50", (player.lingYun or 0) - prevLY, 50)

    EventBus.Off("player_lingyun_change", handler)
    clearAllTestItems()

    log("")
end

-- ============================================================================
-- 运行入口
-- ============================================================================
function TestBatch.RunAll()
    passCount = 0
    failCount = 0
    skipCount = 0

    log("========================================")
    log("批量消耗品系统 - 模拟测试")
    log("========================================")
    log("")

    -- 运行前统一清理，最大限度释放背包空间
    clearAllTestItems()

    TestBatch.T1_GoldBarSell()
    TestBatch.T2_LingyunFruit()
    TestBatch.T3_ExpPill()
    TestBatch.T4_Security()
    TestBatch.T5_Unsupported()
    TestBatch.T6_LingyunFruitEvent()

    -- 最终清理
    clearAllTestItems()

    log("========================================")
    log("结果: PASS=" .. passCount .. " FAIL=" .. failCount .. " SKIP=" .. skipCount)
    if failCount == 0 then
        log("ALL PASSED")
    else
        log("FAILED: " .. failCount .. " 个断言失败")
    end
    log("========================================")

    return failCount == 0, passCount, failCount
end

return TestBatch
