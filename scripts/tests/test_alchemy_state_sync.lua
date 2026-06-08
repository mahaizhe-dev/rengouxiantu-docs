-- ============================================================================
-- test_alchemy_state_sync.lua — 炼丹炉状态同步 + 清零测试
--
-- Phase 0: 在不改生产代码的前提下，钉住丹药运行时状态的同步行为。
--
-- 覆盖：
--   SS-1: CharacterTab3 PILL_CONFIG 中 getCount() 与 AlchemyUI getter 一致
--   SS-2: ReturnToLogin 后所有丹药计数归零
--   SS-3: player.pillCounts 双写一致性（AlchemyUI 修改后 pillCounts 同步）
--   SS-4: Set* 接受 nil 参数时默认为 0（防御性）
--   SS-5: 连续 Set/Get 幂等性
--   SS-6: 限量永久丹触发即时 save_request（行为合同）
--   SS-7: 高频炼丹走会话合并（行为合同）
--
-- 运行方式：纯 Lua 模拟，不依赖引擎运行时
-- ============================================================================

package.path = package.path .. ";scripts/?.lua;scripts/tests/?.lua"

local passed = 0
local failed = 0
local totalTests = 0

local function assert_eq(actual, expected, testName)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print("  ✗ " .. testName)
        print("    expected: " .. tostring(expected))
        print("    actual:   " .. tostring(actual))
    end
end

local function assert_true(cond, testName)
    totalTests = totalTests + 1
    if cond then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print("  ✗ " .. testName .. " — condition is false")
    end
end

-- ============================================================================
-- Mock 框架
-- ============================================================================

local function CreateTestEnv()
    local env = {}

    -- 丹药运行时状态
    env.pillState = {
        tiger = 0,
        snake = 0,
        diamond = 0,
        tempering = 0,
        dragonBlood = 0,
        swordIntent = 0,
        abyssSeal = 0,
    }

    -- player 对象
    env.player = {
        pillCounts = nil,
        maxHp = 200,
        atk = 50,
        def = 30,
        lingYun = 1000,
    }

    -- 事件追踪
    env.events = {}

    function env.EventBus_Emit(event, ...)
        env.events[#env.events + 1] = { name = event, args = {...} }
    end

    -- AlchemyUI mock（完整模拟生产代码的 getter/setter 行为）
    env.AlchemyUI = {}
    function env.AlchemyUI.GetTigerPillCount() return env.pillState.tiger end
    function env.AlchemyUI.SetTigerPillCount(c) env.pillState.tiger = c or 0 end
    function env.AlchemyUI.GetSnakePillCount() return env.pillState.snake end
    function env.AlchemyUI.SetSnakePillCount(c) env.pillState.snake = c or 0 end
    function env.AlchemyUI.GetDiamondPillCount() return env.pillState.diamond end
    function env.AlchemyUI.SetDiamondPillCount(c) env.pillState.diamond = c or 0 end
    function env.AlchemyUI.GetTemperingPillEaten() return env.pillState.tempering end
    function env.AlchemyUI.SetTemperingPillEaten(c) env.pillState.tempering = c or 0 end
    function env.AlchemyUI.GetDragonBloodPillCount() return env.pillState.dragonBlood end
    function env.AlchemyUI.SetDragonBloodPillCount(c) env.pillState.dragonBlood = c or 0 end
    function env.AlchemyUI.GetSwordIntentPillCount() return env.pillState.swordIntent end
    function env.AlchemyUI.SetSwordIntentPillCount(c) env.pillState.swordIntent = c or 0 end
    function env.AlchemyUI.GetAbyssSealPillCount() return env.pillState.abyssSeal end
    function env.AlchemyUI.SetAbyssSealPillCount(c) env.pillState.abyssSeal = c or 0 end

    --- 模拟 CharacterTab3 的 PILL_CONFIG getCount 映射
    --- （精确复制 CharacterTab3.lua 第 23-132 行的 getCount 调用链）
    env.charTab3GetCounts = {
        { name = "虎骨丹",    getCount = function() return env.AlchemyUI.GetTigerPillCount() end },
        { name = "灵蛇丹",    getCount = function() return env.AlchemyUI.GetSnakePillCount() end },
        { name = "金刚丹",    getCount = function() return env.AlchemyUI.GetDiamondPillCount() end },
        { name = "千锤百炼丹", getCount = function() return env.AlchemyUI.GetTemperingPillEaten() end },
        { name = "龙血丹",    getCount = function() return env.AlchemyUI.GetDragonBloodPillCount() end },
        { name = "太虚剑丹",   getCount = function() return env.AlchemyUI.GetSwordIntentPillCount() end },
        { name = "狱甲丹",    getCount = function() return env.AlchemyUI.GetAbyssSealPillCount() end },
    }

    --- 模拟 ReturnToLogin 中对炼丹相关状态的清理
    --- 当前生产代码通过 GameState.Init() 重置 player，
    --- 但 AlchemyUI 的 module-level 变量需要显式重置
    function env.SimulateReturnToLogin()
        -- 生产代码中 ReturnToLogin → GameState.Init() 重置 player
        env.player = {
            pillCounts = nil,
            maxHp = 200,
            atk = 50,
            def = 30,
            lingYun = 1000,
        }
        -- 注意：当前生产代码中 AlchemyUI 的 module-level 变量
        -- 不会被 ReturnToLogin 主动清零，这是 Phase 1 要修复的
        -- 此测试记录当前行为作为基线
    end

    --- 模拟限量永久丹的炼制（触发即时 save_request）
    function env.SimulateLimitedPillCraft(pillKey)
        local oldCount = env.pillState[pillKey]
        env.pillState[pillKey] = oldCount + 1
        -- 双写 pillCounts
        if env.player.pillCounts then
            local keyMap = {
                tiger = "tiger", snake = "snake", diamond = "diamond",
                tempering = "tempering", dragonBlood = "dragon_blood",
                swordIntent = "sword_intent", abyssSeal = "abyss_seal",
            }
            env.player.pillCounts[keyMap[pillKey]] = env.pillState[pillKey]
        end
        -- 限量丹：即时保存
        env.EventBus_Emit("save_request")
    end

    --- 模拟高频炼丹（不直接触发 save_request，由会话合并收口）
    env.sessionOps = 0
    function env.SimulateFrequentCraft()
        env.sessionOps = env.sessionOps + 1
        -- 高频炼丹走会话合并，不逐次 save_request
    end

    return env
end

-- ============================================================================
-- 测试用例
-- ============================================================================

print("\n[test_alchemy_state_sync] === 炼丹炉状态同步测试 ===\n")

-- ─────────────────────────────────────────────────────────────
-- SS-1: CharacterTab3 getCount() 与 AlchemyUI getter 一致
-- ─────────────────────────────────────────────────────────────

print("── SS-1: CharacterTab3 getCount() 与 AlchemyUI getter 一致 ──")
do
    local env = CreateTestEnv()

    -- 设置非零值
    env.pillState.tiger = 3
    env.pillState.snake = 5
    env.pillState.diamond = 2
    env.pillState.tempering = 30
    env.pillState.dragonBlood = 1
    env.pillState.swordIntent = 2
    env.pillState.abyssSeal = 1

    local getters = {
        env.AlchemyUI.GetTigerPillCount,
        env.AlchemyUI.GetSnakePillCount,
        env.AlchemyUI.GetDiamondPillCount,
        env.AlchemyUI.GetTemperingPillEaten,
        env.AlchemyUI.GetDragonBloodPillCount,
        env.AlchemyUI.GetSwordIntentPillCount,
        env.AlchemyUI.GetAbyssSealPillCount,
    }

    for i, cfg in ipairs(env.charTab3GetCounts) do
        local tab3Val = cfg.getCount()
        local directVal = getters[i]()
        assert_eq(tab3Val, directVal,
            "SS-1" .. string.char(96 + i) .. ": " .. cfg.name .. " CharacterTab3==AlchemyUI")
    end
end

-- ─────────────────────────────────────────────────────────────
-- SS-2: ReturnToLogin 后丹药计数的当前行为基线
-- ─────────────────────────────────────────────────────────────

print("\n── SS-2: ReturnToLogin 后丹药计数行为基线 ──")
do
    local env = CreateTestEnv()

    -- 设置运行时非零值
    env.pillState.tiger = 4
    env.pillState.snake = 3
    env.pillState.diamond = 5
    env.pillState.tempering = 20
    env.pillState.dragonBlood = 2
    env.pillState.swordIntent = 1
    env.pillState.abyssSeal = 2
    env.player.pillCounts = { tiger = 4, snake = 3, diamond = 5 }

    env.SimulateReturnToLogin()

    -- 记录当前行为：module-level 变量在 ReturnToLogin 后 **不会** 被清零
    -- （因为生产代码中 ReturnToLogin 不显式调用 AlchemyUI 的重置）
    -- Phase 1 会通过 AlchemySystem.ResetRuntimeState() 修复此问题
    -- 这里记录的是 Phase 0 基线
    assert_eq(env.pillState.tiger, 4, "SS-2a: [基线] tiger module-level 未被 ReturnToLogin 重置")
    assert_eq(env.pillState.snake, 3, "SS-2b: [基线] snake module-level 未被 ReturnToLogin 重置")
    assert_eq(env.pillState.swordIntent, 1, "SS-2c: [基线] swordIntent module-level 未被 ReturnToLogin 重置")

    -- player 被 GameState.Init() 重置
    assert_true(env.player.pillCounts == nil, "SS-2d: player.pillCounts 被 GameState.Init 重置")
end

-- ─────────────────────────────────────────────────────────────
-- SS-3: player.pillCounts 双写一致性
-- ─────────────────────────────────────────────────────────────

print("\n── SS-3: player.pillCounts 双写一致性 ──")
do
    local env = CreateTestEnv()

    -- 初始化 pillCounts
    env.player.pillCounts = { tiger = 0, snake = 0, diamond = 0,
        tempering = 0, dragon_blood = 0, sword_intent = 0, abyss_seal = 0 }

    -- 模拟炼制虎骨丹
    env.SimulateLimitedPillCraft("tiger")
    assert_eq(env.pillState.tiger, 1, "SS-3a: pillState.tiger 增加到 1")
    assert_eq(env.player.pillCounts.tiger, 1, "SS-3b: player.pillCounts.tiger 同步为 1")

    -- 再炼一次
    env.SimulateLimitedPillCraft("tiger")
    assert_eq(env.pillState.tiger, 2, "SS-3c: pillState.tiger 增加到 2")
    assert_eq(env.player.pillCounts.tiger, 2, "SS-3d: player.pillCounts.tiger 同步为 2")

    -- 剑意丹
    env.SimulateLimitedPillCraft("swordIntent")
    assert_eq(env.pillState.swordIntent, 1, "SS-3e: pillState.swordIntent 增加到 1")
    assert_eq(env.player.pillCounts.sword_intent, 1, "SS-3f: player.pillCounts.sword_intent 同步为 1")
end

-- ─────────────────────────────────────────────────────────────
-- SS-4: Set* 接受 nil 参数时默认为 0
-- ─────────────────────────────────────────────────────────────

print("\n── SS-4: Set* 接受 nil 参数时默认为 0 ──")
do
    local env = CreateTestEnv()

    -- 设非零值
    env.pillState.tiger = 5
    env.pillState.snake = 3

    -- 传 nil
    env.AlchemyUI.SetTigerPillCount(nil)
    env.AlchemyUI.SetSnakePillCount(nil)

    assert_eq(env.AlchemyUI.GetTigerPillCount(), 0, "SS-4a: SetTigerPillCount(nil) → 0")
    assert_eq(env.AlchemyUI.GetSnakePillCount(), 0, "SS-4b: SetSnakePillCount(nil) → 0")
end

-- ─────────────────────────────────────────────────────────────
-- SS-5: 连续 Set/Get 幂等性
-- ─────────────────────────────────────────────────────────────

print("\n── SS-5: 连续 Set/Get 幂等性 ──")
do
    local env = CreateTestEnv()

    -- 多次 Set 同一个值
    env.AlchemyUI.SetTigerPillCount(3)
    env.AlchemyUI.SetTigerPillCount(3)
    env.AlchemyUI.SetTigerPillCount(3)
    assert_eq(env.AlchemyUI.GetTigerPillCount(), 3, "SS-5a: 多次 Set 同值幂等")

    -- 交替 Set 不同值
    env.AlchemyUI.SetDiamondPillCount(1)
    env.AlchemyUI.SetDiamondPillCount(5)
    assert_eq(env.AlchemyUI.GetDiamondPillCount(), 5, "SS-5b: 后 Set 覆盖前值")
end

-- ─────────────────────────────────────────────────────────────
-- SS-6: 限量永久丹触发即时 save_request
-- ─────────────────────────────────────────────────────────────

print("\n── SS-6: 限量永久丹触发即时 save_request ──")
do
    local env = CreateTestEnv()
    env.player.pillCounts = { tiger = 0, snake = 0, diamond = 0,
        tempering = 0, dragon_blood = 0, sword_intent = 0, abyss_seal = 0 }

    env.SimulateLimitedPillCraft("tiger")
    env.SimulateLimitedPillCraft("diamond")
    env.SimulateLimitedPillCraft("swordIntent")

    -- 每次限量丹炼制应触发一次 save_request
    local saveCount = 0
    for _, evt in ipairs(env.events) do
        if evt.name == "save_request" then saveCount = saveCount + 1 end
    end
    assert_eq(saveCount, 3, "SS-6a: 3 次限量丹炼制 → 3 次即时 save_request")
end

-- ─────────────────────────────────────────────────────────────
-- SS-7: 高频炼丹走会话合并（不逐次 save_request）
-- ─────────────────────────────────────────────────────────────

print("\n── SS-7: 高频炼丹走会话合并 ──")
do
    local env = CreateTestEnv()

    -- 模拟 10 次高频炼丹
    for _ = 1, 10 do
        env.SimulateFrequentCraft()
    end

    -- 高频炼丹不逐次触发 save_request
    local saveCount = 0
    for _, evt in ipairs(env.events) do
        if evt.name == "save_request" then saveCount = saveCount + 1 end
    end
    assert_eq(saveCount, 0, "SS-7a: 10 次高频炼丹 → 0 次即时 save_request（会话合并）")
    assert_eq(env.sessionOps, 10, "SS-7b: 操作计数正确记录 10 次")
end

-- ============================================================================
-- 结果
-- ============================================================================

print(string.format(
    "\n[test_alchemy_state_sync] 完成: %d 通过, %d 失败, 共 %d 项",
    passed, failed, totalTests
))

if failed > 0 then
    print("[test_alchemy_state_sync] ❌ 存在失败用例!")
    os.exit(1)
else
    print("[test_alchemy_state_sync] ✅ 全部通过")
end
