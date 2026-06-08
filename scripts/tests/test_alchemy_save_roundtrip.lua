-- ============================================================================
-- test_alchemy_save_roundtrip.lua — 炼丹炉存档 Round-Trip 测试
--
-- Phase 0: 在不改生产代码的前提下，钉住丹药计数的序列化/反序列化行为。
--
-- 覆盖：
--   RT-1: 7 个丹药计数序列化字段名正确
--   RT-2: 7 个丹药计数反序列化后 getter 返回正确值
--   RT-3: round-trip 完整性（Serialize → Deserialize → 再 Serialize 值不变）
--   RT-4: pillCounts 对象在序列化时存在且字段与扁平值一致
--   RT-5: 缺失字段时 Deserialize 默认为 0
--   RT-6: pillCounts 缺失时 SaveLoader 校正逻辑能从扁平字段构建
--   RT-7: pillCounts 漂移时以扁平字段为准修正
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

local function assert_nil(val, testName)
    totalTests = totalTests + 1
    if val == nil then
        passed = passed + 1
        print("  ✓ " .. testName)
    else
        failed = failed + 1
        print("  ✗ " .. testName)
        print("    expected: nil, got: " .. tostring(val))
    end
end

-- ============================================================================
-- Mock 框架
-- ============================================================================

--- 创建隔离的测试环境，模拟 AlchemyUI + GameState + SaveSerializer 交互
local function CreateTestEnv()
    local env = {}

    -- 模拟 AlchemyUI 的 module-level 计数状态
    env.pillState = {
        tiger = 0,
        snake = 0,
        diamond = 0,
        tempering = 0,
        dragonBlood = 0,
        swordIntent = 0,
        abyssSeal = 0,
    }

    -- 模拟 player 对象
    env.player = {
        level = 10,
        exp = 500,
        hp = 100,
        maxHp = 200,
        atk = 50,
        def = 30,
        hpRegen = 1,
        realm = "mortal",
        x = 10.5,
        y = 20.3,
        pillKillHeal = 0,
        pillConstitution = 0,
        gangguConstitution = 0,
        fruitFortune = 0,
        seaPillarDef = 0,
        seaPillarAtk = 0,
        seaPillarMaxHp = 0,
        seaPillarHpRegen = 0,
        swordPoolAtk = 0,
        swordPoolDef = 0,
        swordPoolMaxHp = 0,
        swordPoolHpRegen = 0,
        prisonTowerAtk = 0,
        prisonTowerDef = 0,
        prisonTowerMaxHp = 0,
        prisonTowerHpRegen = 0,
        daoTreeWisdom = 0,
        daoTreeWisdomPity = 0,
        gold = 100,
        lingYun = 500,
        pillCounts = nil,  -- 初始无 pillCounts
        pillPhysique = 0,
        classId = nil,
    }

    -- 模拟 AlchemyUI getter/setter
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

    --- 模拟 SerializePlayer 中丹药相关字段的序列化逻辑
    --- （精确复制 SaveSerializer.lua 第 64-95 行的行为）
    function env.SerializePillFields()
        return {
            tigerPillCount = env.AlchemyUI.GetTigerPillCount(),
            snakePillCount = env.AlchemyUI.GetSnakePillCount(),
            diamondPillCount = env.AlchemyUI.GetDiamondPillCount(),
            temperingPillEaten = env.AlchemyUI.GetTemperingPillEaten(),
            dragonBloodPillCount = env.AlchemyUI.GetDragonBloodPillCount(),
            swordIntentPillCount = env.AlchemyUI.GetSwordIntentPillCount(),
            abyssSealPillCount = env.AlchemyUI.GetAbyssSealPillCount(),
            pillCounts = env.player.pillCounts or nil,
        }
    end

    --- 模拟 DeserializePlayer 中丹药相关字段的反序列化逻辑
    --- （精确复制 SaveSerializer.lua 第 262-269 行的行为）
    function env.DeserializePillFields(data)
        env.AlchemyUI.SetTigerPillCount(data.tigerPillCount or 0)
        env.AlchemyUI.SetSnakePillCount(data.snakePillCount or 0)
        env.AlchemyUI.SetDiamondPillCount(data.diamondPillCount or 0)
        env.AlchemyUI.SetTemperingPillEaten(data.temperingPillEaten or 0)
        env.AlchemyUI.SetDragonBloodPillCount(data.dragonBloodPillCount or 0)
        env.AlchemyUI.SetSwordIntentPillCount(data.swordIntentPillCount or 0)
        env.AlchemyUI.SetAbyssSealPillCount(data.abyssSealPillCount or 0)
    end

    --- 模拟 SaveLoader 中 pillCounts 初始化逻辑
    --- （复制 SaveLoader.lua 第 253-268 行的行为）
    function env.InitPillCounts()
        local current = {
            tiger     = env.AlchemyUI.GetTigerPillCount(),
            snake     = env.AlchemyUI.GetSnakePillCount(),
            diamond   = env.AlchemyUI.GetDiamondPillCount(),
            tempering = env.AlchemyUI.GetTemperingPillEaten(),
            sword_intent = env.AlchemyUI.GetSwordIntentPillCount(),
            abyss_seal   = env.AlchemyUI.GetAbyssSealPillCount(),
        }
        if not env.player.pillCounts then
            env.player.pillCounts = current
        else
            -- 校正漂移：以扁平字段（getter）为准
            for key, val in pairs(current) do
                if env.player.pillCounts[key] ~= val then
                    env.player.pillCounts[key] = val
                end
            end
        end
    end

    return env
end

-- ============================================================================
-- 测试用例
-- ============================================================================

print("\n[test_alchemy_save_roundtrip] === 炼丹炉存档 Round-Trip 测试 ===\n")

-- ─────────────────────────────────────────────────────────────
-- RT-1: 序列化字段名正确
-- ─────────────────────────────────────────────────────────────

print("── RT-1: 序列化字段名正确 ──")
do
    local env = CreateTestEnv()
    env.pillState.tiger = 3
    env.pillState.snake = 2
    env.pillState.diamond = 4
    env.pillState.tempering = 15
    env.pillState.dragonBlood = 1
    env.pillState.swordIntent = 2
    env.pillState.abyssSeal = 1

    local serialized = env.SerializePillFields()

    -- 验证字段名与 SaveWriteService 校验一致
    assert_eq(serialized.tigerPillCount, 3, "RT-1a: tigerPillCount 字段名+值")
    assert_eq(serialized.snakePillCount, 2, "RT-1b: snakePillCount 字段名+值")
    assert_eq(serialized.diamondPillCount, 4, "RT-1c: diamondPillCount 字段名+值")
    assert_eq(serialized.temperingPillEaten, 15, "RT-1d: temperingPillEaten 字段名+值")
    assert_eq(serialized.dragonBloodPillCount, 1, "RT-1e: dragonBloodPillCount 字段名+值")
    assert_eq(serialized.swordIntentPillCount, 2, "RT-1f: swordIntentPillCount 字段名+值")
    assert_eq(serialized.abyssSealPillCount, 1, "RT-1g: abyssSealPillCount 字段名+值")
end

-- ─────────────────────────────────────────────────────────────
-- RT-2: 反序列化后 getter 返回正确值
-- ─────────────────────────────────────────────────────────────

print("\n── RT-2: 反序列化后 getter 返回正确值 ──")
do
    local env = CreateTestEnv()

    local saveData = {
        tigerPillCount = 5,
        snakePillCount = 3,
        diamondPillCount = 5,
        temperingPillEaten = 42,
        dragonBloodPillCount = 2,
        swordIntentPillCount = 3,
        abyssSealPillCount = 1,
    }

    env.DeserializePillFields(saveData)

    assert_eq(env.AlchemyUI.GetTigerPillCount(), 5, "RT-2a: tiger getter 恢复正确")
    assert_eq(env.AlchemyUI.GetSnakePillCount(), 3, "RT-2b: snake getter 恢复正确")
    assert_eq(env.AlchemyUI.GetDiamondPillCount(), 5, "RT-2c: diamond getter 恢复正确")
    assert_eq(env.AlchemyUI.GetTemperingPillEaten(), 42, "RT-2d: tempering getter 恢复正确")
    assert_eq(env.AlchemyUI.GetDragonBloodPillCount(), 2, "RT-2e: dragonBlood getter 恢复正确")
    assert_eq(env.AlchemyUI.GetSwordIntentPillCount(), 3, "RT-2f: swordIntent getter 恢复正确")
    assert_eq(env.AlchemyUI.GetAbyssSealPillCount(), 1, "RT-2g: abyssSeal getter 恢复正确")
end

-- ─────────────────────────────────────────────────────────────
-- RT-3: Round-trip 完整性
-- ─────────────────────────────────────────────────────────────

print("\n── RT-3: Round-trip 完整性 ──")
do
    local env = CreateTestEnv()

    -- 设置初始值
    env.pillState.tiger = 4
    env.pillState.snake = 5
    env.pillState.diamond = 3
    env.pillState.tempering = 20
    env.pillState.dragonBlood = 2
    env.pillState.swordIntent = 1
    env.pillState.abyssSeal = 2

    -- 第一次序列化
    local serialized1 = env.SerializePillFields()

    -- 清空状态模拟重启
    env.pillState.tiger = 0
    env.pillState.snake = 0
    env.pillState.diamond = 0
    env.pillState.tempering = 0
    env.pillState.dragonBlood = 0
    env.pillState.swordIntent = 0
    env.pillState.abyssSeal = 0

    -- 反序列化
    env.DeserializePillFields(serialized1)

    -- 第二次序列化
    local serialized2 = env.SerializePillFields()

    -- 对比两次序列化结果
    assert_eq(serialized2.tigerPillCount, serialized1.tigerPillCount, "RT-3a: tiger round-trip 一致")
    assert_eq(serialized2.snakePillCount, serialized1.snakePillCount, "RT-3b: snake round-trip 一致")
    assert_eq(serialized2.diamondPillCount, serialized1.diamondPillCount, "RT-3c: diamond round-trip 一致")
    assert_eq(serialized2.temperingPillEaten, serialized1.temperingPillEaten, "RT-3d: tempering round-trip 一致")
    assert_eq(serialized2.dragonBloodPillCount, serialized1.dragonBloodPillCount, "RT-3e: dragonBlood round-trip 一致")
    assert_eq(serialized2.swordIntentPillCount, serialized1.swordIntentPillCount, "RT-3f: swordIntent round-trip 一致")
    assert_eq(serialized2.abyssSealPillCount, serialized1.abyssSealPillCount, "RT-3g: abyssSeal round-trip 一致")
end

-- ─────────────────────────────────────────────────────────────
-- RT-4: pillCounts 对象与扁平字段一致
-- ─────────────────────────────────────────────────────────────

print("\n── RT-4: pillCounts 对象与扁平字段一致 ──")
do
    local env = CreateTestEnv()
    env.pillState.tiger = 3
    env.pillState.snake = 2
    env.pillState.diamond = 4
    env.pillState.tempering = 10
    env.pillState.swordIntent = 1
    env.pillState.abyssSeal = 2

    -- 模拟 player.pillCounts 已被设置（正常运行时双写）
    env.player.pillCounts = {
        tiger = 3, snake = 2, diamond = 4, tempering = 10,
        sword_intent = 1, abyss_seal = 2,
    }

    local serialized = env.SerializePillFields()

    -- pillCounts 存在且字段一致
    assert_true(serialized.pillCounts ~= nil, "RT-4a: pillCounts 被序列化")
    assert_eq(serialized.pillCounts.tiger, serialized.tigerPillCount, "RT-4b: pillCounts.tiger == tigerPillCount")
    assert_eq(serialized.pillCounts.snake, serialized.snakePillCount, "RT-4c: pillCounts.snake == snakePillCount")
    assert_eq(serialized.pillCounts.diamond, serialized.diamondPillCount, "RT-4d: pillCounts.diamond == diamondPillCount")
    assert_eq(serialized.pillCounts.tempering, serialized.temperingPillEaten, "RT-4e: pillCounts.tempering == temperingPillEaten")
    assert_eq(serialized.pillCounts.sword_intent, serialized.swordIntentPillCount, "RT-4f: pillCounts.sword_intent == swordIntentPillCount")
    assert_eq(serialized.pillCounts.abyss_seal, serialized.abyssSealPillCount, "RT-4g: pillCounts.abyss_seal == abyssSealPillCount")
end

-- ─────────────────────────────────────────────────────────────
-- RT-5: 缺失字段时 Deserialize 默认为 0
-- ─────────────────────────────────────────────────────────────

print("\n── RT-5: 缺失字段时 Deserialize 默认为 0 ──")
do
    local env = CreateTestEnv()

    -- 先设置非零值
    env.pillState.tiger = 99
    env.pillState.swordIntent = 99

    -- 反序列化一个空 table（模拟旧版存档缺失字段）
    env.DeserializePillFields({})

    assert_eq(env.AlchemyUI.GetTigerPillCount(), 0, "RT-5a: 缺失 tigerPillCount 默认 0")
    assert_eq(env.AlchemyUI.GetSnakePillCount(), 0, "RT-5b: 缺失 snakePillCount 默认 0")
    assert_eq(env.AlchemyUI.GetDiamondPillCount(), 0, "RT-5c: 缺失 diamondPillCount 默认 0")
    assert_eq(env.AlchemyUI.GetTemperingPillEaten(), 0, "RT-5d: 缺失 temperingPillEaten 默认 0")
    assert_eq(env.AlchemyUI.GetDragonBloodPillCount(), 0, "RT-5e: 缺失 dragonBloodPillCount 默认 0")
    assert_eq(env.AlchemyUI.GetSwordIntentPillCount(), 0, "RT-5f: 缺失 swordIntentPillCount 默认 0")
    assert_eq(env.AlchemyUI.GetAbyssSealPillCount(), 0, "RT-5g: 缺失 abyssSealPillCount 默认 0")
end

-- ─────────────────────────────────────────────────────────────
-- RT-6: pillCounts 缺失时从扁平字段构建
-- ─────────────────────────────────────────────────────────────

print("\n── RT-6: pillCounts 缺失时从扁平字段构建 ──")
do
    local env = CreateTestEnv()

    -- 模拟反序列化后 getter 已有值
    env.pillState.tiger = 3
    env.pillState.snake = 2
    env.pillState.diamond = 1
    env.pillState.tempering = 8
    env.pillState.swordIntent = 2
    env.pillState.abyssSeal = 1

    -- player.pillCounts 为 nil（旧版存档无此字段）
    env.player.pillCounts = nil

    -- 执行初始化
    env.InitPillCounts()

    -- 验证 pillCounts 被正确构建
    assert_true(env.player.pillCounts ~= nil, "RT-6a: pillCounts 被创建")
    assert_eq(env.player.pillCounts.tiger, 3, "RT-6b: pillCounts.tiger 从扁平字段构建")
    assert_eq(env.player.pillCounts.snake, 2, "RT-6c: pillCounts.snake 从扁平字段构建")
    assert_eq(env.player.pillCounts.diamond, 1, "RT-6d: pillCounts.diamond 从扁平字段构建")
    assert_eq(env.player.pillCounts.tempering, 8, "RT-6e: pillCounts.tempering 从扁平字段构建")
    assert_eq(env.player.pillCounts.sword_intent, 2, "RT-6f: pillCounts.sword_intent 从扁平字段构建")
    assert_eq(env.player.pillCounts.abyss_seal, 1, "RT-6g: pillCounts.abyss_seal 从扁平字段构建")
end

-- ─────────────────────────────────────────────────────────────
-- RT-7: pillCounts 漂移时以扁平字段为准修正
-- ─────────────────────────────────────────────────────────────

print("\n── RT-7: pillCounts 漂移时以扁平字段为准修正 ──")
do
    local env = CreateTestEnv()

    -- 扁平字段（getter）的值
    env.pillState.tiger = 4
    env.pillState.snake = 3
    env.pillState.diamond = 5
    env.pillState.tempering = 20
    env.pillState.swordIntent = 2
    env.pillState.abyssSeal = 1

    -- pillCounts 存在但与扁平字段不一致（模拟漂移）
    env.player.pillCounts = {
        tiger = 2,       -- 漂移：实际是 4
        snake = 3,       -- 一致
        diamond = 5,     -- 一致
        tempering = 15,  -- 漂移：实际是 20
        sword_intent = 2, -- 一致
        abyss_seal = 0,  -- 漂移：实际是 1
    }

    -- 执行校正
    env.InitPillCounts()

    -- 验证以扁平字段为准修正
    assert_eq(env.player.pillCounts.tiger, 4, "RT-7a: 漂移修正 tiger 4 (was 2)")
    assert_eq(env.player.pillCounts.snake, 3, "RT-7b: 未漂移 snake 保持 3")
    assert_eq(env.player.pillCounts.diamond, 5, "RT-7c: 未漂移 diamond 保持 5")
    assert_eq(env.player.pillCounts.tempering, 20, "RT-7d: 漂移修正 tempering 20 (was 15)")
    assert_eq(env.player.pillCounts.sword_intent, 2, "RT-7e: 未漂移 sword_intent 保持 2")
    assert_eq(env.player.pillCounts.abyss_seal, 1, "RT-7f: 漂移修正 abyss_seal 1 (was 0)")
end

-- ============================================================================
-- 结果
-- ============================================================================

print(string.format(
    "\n[test_alchemy_save_roundtrip] 完成: %d 通过, %d 失败, 共 %d 项",
    passed, failed, totalTests
))

if failed > 0 then
    print("[test_alchemy_save_roundtrip] ❌ 存在失败用例!")
    os.exit(1)
else
    print("[test_alchemy_save_roundtrip] ✅ 全部通过")
end
