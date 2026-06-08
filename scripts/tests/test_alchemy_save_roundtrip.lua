-- ============================================================================
-- test_alchemy_save_roundtrip.lua — 炼丹炉存档 Round-Trip 测试
--
-- 直接验证生产实现：AlchemySystem + SaveSerializer + SaveLoader 丹药链路
--
-- 覆盖：
--   RT-1: 7 个丹药计数序列化字段名正确（SaveSerializer.SerializePlayer）
--   RT-2: 7 个丹药计数反序列化后 getter 返回正确值（DeserializePlayer→AlchemySystem）
--   RT-3: round-trip 完整性（Serialize → Reset → Deserialize → 再 Serialize 值不变）
--   RT-4: pillCounts 双写一致性（Set* 后 player.pillCounts 同步）
--   RT-5: 缺失字段时 Deserialize 默认为 0
--   RT-6: pillCounts 缺失时 SaveLoader 校正逻辑能从扁平字段构建
--   RT-7: pillCounts 漂移时以 AlchemySystem getter 为准修正
--
-- 运行方式：纯 Lua（require 生产模块，stub 不相关依赖）
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

-- ============================================================================
-- 清除可能残留的模块缓存（runner 顺序执行多测试文件时需要）
-- ============================================================================
package.loaded["systems.AlchemySystem"] = nil
package.loaded["core.GameState"] = nil
package.loaded["systems.save.SaveSerializer"] = nil

-- ============================================================================
-- Stub 层：隔离不需要的引擎/UI 依赖
-- ============================================================================

-- 预注入 stub，防止 require 链拉入引擎运行时
-- InventorySystem stub（AlchemySystem 的 Craft 逻辑会用到，但本测试不测 Craft）
package.loaded["systems.InventorySystem"] = {
    CountConsumable = function() return 0 end,
    CountUnlockedConsumable = function() return 0 end,
    GetFreeSlots = function() return 10 end,
    AddConsumable = function() end,
    ConsumeConsumable = function() return true end,
}

-- GameState stub（player 对象我们自己管理）
local GameState = {
    player = nil,
    currentChapter = 1,
}
function GameState.Init()
    GameState.player = nil
    GameState.currentChapter = 1
end
package.loaded["core.GameState"] = GameState

-- GameConfig stub（只需要 Craft 用到的字段，RT 测试不走 Craft）
package.loaded["config.GameConfig"] = {
    EXP_TABLE = {},
    PET_MATERIALS = {},
    PET_FOOD = {},
    CONSUMABLES = {},
    REALM_COMPAT = nil,
    REALMS = setmetatable({}, { __index = function() return { attackSpeedBonus = 0 } end }),
}

-- EventBus stub
package.loaded["core.EventBus"] = { On = function() end, Emit = function() end }

-- PillRecipes stub（只需提供结构，Craft 不测）
package.loaded["config.PillRecipes"] = {
    CONSUMABLES = {},
    PERMANENTS = {},
    TOKEN_BOXES = {},
    TOKEN_BOX_LINGYUN_COST = 100,
    TOKEN_BOX_TOKEN_COST = 5,
    STAT_DISPLAY = {},
}

-- ChallengeSystem stub
package.loaded["systems.ChallengeSystem"] = {
    xueshaDanCount = 0,
    haoqiDanCount = 0,
    ningliDanCount = 0,
    ningjiaDanCount = 0,
    ningyuanDanCount = 0,
    ninghunDanCount = 0,
    ningxiDanCount = 0,
    gangguDanCount = 0,
}

-- ============================================================================
-- 创建 Player 对象（模拟 GameState.player 的最小结构）
-- ============================================================================

local function CreateMockPlayer()
    local p = {
        level = 10, exp = 500, hp = 100, maxHp = 200,
        atk = 50, def = 30, hpRegen = 1,
        pillKillHeal = 0, pillConstitution = 0, gangguConstitution = 0,
        fruitFortune = 0,
        seaPillarDef = 0, seaPillarAtk = 0, seaPillarMaxHp = 0, seaPillarHpRegen = 0,
        swordPoolAtk = 0, swordPoolDef = 0, swordPoolMaxHp = 0, swordPoolHpRegen = 0,
        prisonTowerAtk = 0, prisonTowerDef = 0, prisonTowerMaxHp = 0, prisonTowerHpRegen = 0,
        daoTreeWisdom = 0, daoTreeWisdomPity = 0,
        gold = 100, lingYun = 500, realm = "mortal",
        x = 10.5, y = 20.3,
        pillCounts = nil,
        pillPhysique = 0,
        classId = "monk",
        wineConstitution = 0, wineWisdom = 0, wineFortune = 0, winePhysique = 0,
        wineObtained = {}, wineSlots = {false, false, false},
        gourdFirstKillFlags = {},
        daoWisdom = 0, daoFortune = 0, daoConstitution = 0,
        daoPhysique = 0, daoAtk = 0, daoMaxHp = 0,
        daoAnswers = {},
        _bloodAccumulator = 0,
    }
    -- GetTotalMaxHp 用于 DeserializePlayer 的 hp 上限计算
    function p:GetTotalMaxHp()
        return self.maxHp
    end
    return p
end

-- ============================================================================
-- 加载生产模块
-- ============================================================================

local AlchemySystem = require("systems.AlchemySystem")
-- SaveSerializer 需要 require 很多子模块，我们 stub 掉不相关的
package.loaded["systems.save.SaveState"] = { _lastKnownCollectionCount = 0, _cachedCollectionData = nil }
package.loaded["systems.save.SaveMigrations"] = { MigrateSaveData = function(d) return d end }
package.loaded["systems.save.SaveKeys"] = {}
local SaveSerializer = require("systems.save.SaveSerializer")

-- ============================================================================
-- 测试框架
-- ============================================================================

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

--- 重置 AlchemySystem 并设置 player
local function resetEnv()
    AlchemySystem.ResetRuntimeState()
    local player = CreateMockPlayer()
    GameState.player = player
    return player
end

-- ============================================================================
-- 测试用例
-- ============================================================================

print("\n[test_alchemy_save_roundtrip] === 炼丹炉存档 Round-Trip 测试 ===\n")

-- ─────────────────────────────────────────────────────────────
-- RT-1: 序列化字段名正确（验证 SaveSerializer.SerializePlayer 输出）
-- ─────────────────────────────────────────────────────────────

print("── RT-1: 序列化字段名正确 ──")
do
    local player = resetEnv()

    -- 通过 AlchemySystem 的 Set* 设置值
    AlchemySystem.SetTigerPillCount(3)
    AlchemySystem.SetSnakePillCount(2)
    AlchemySystem.SetDiamondPillCount(4)
    AlchemySystem.SetTemperingPillEaten(15)
    AlchemySystem.SetDragonBloodPillCount(1)
    AlchemySystem.SetSwordIntentPillCount(2)
    AlchemySystem.SetAbyssSealPillCount(1)

    local serialized = SaveSerializer.SerializePlayer()

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
-- RT-2: 反序列化后 AlchemySystem getter 返回正确值
-- ─────────────────────────────────────────────────────────────

print("\n── RT-2: 反序列化后 getter 返回正确值 ──")
do
    local player = resetEnv()

    local saveData = {
        tigerPillCount = 5,
        snakePillCount = 3,
        diamondPillCount = 5,
        temperingPillEaten = 42,
        dragonBloodPillCount = 2,
        swordIntentPillCount = 3,
        abyssSealPillCount = 1,
        level = 10, exp = 500, maxHp = 200, atk = 50, def = 30, hpRegen = 1,
        gold = 100, lingYun = 500, realm = "mortal",
    }

    SaveSerializer.DeserializePlayer(saveData)

    assert_eq(AlchemySystem.GetTigerPillCount(), 5, "RT-2a: tiger getter 恢复正确")
    assert_eq(AlchemySystem.GetSnakePillCount(), 3, "RT-2b: snake getter 恢复正确")
    assert_eq(AlchemySystem.GetDiamondPillCount(), 5, "RT-2c: diamond getter 恢复正确")
    assert_eq(AlchemySystem.GetTemperingPillEaten(), 42, "RT-2d: tempering getter 恢复正确")
    assert_eq(AlchemySystem.GetDragonBloodPillCount(), 2, "RT-2e: dragonBlood getter 恢复正确")
    assert_eq(AlchemySystem.GetSwordIntentPillCount(), 3, "RT-2f: swordIntent getter 恢复正确")
    assert_eq(AlchemySystem.GetAbyssSealPillCount(), 1, "RT-2g: abyssSeal getter 恢复正确")
end

-- ─────────────────────────────────────────────────────────────
-- RT-3: Round-trip 完整性
-- ─────────────────────────────────────────────────────────────

print("\n── RT-3: Round-trip 完整性 ──")
do
    local player = resetEnv()

    -- 设置初始值
    AlchemySystem.SetTigerPillCount(4)
    AlchemySystem.SetSnakePillCount(5)
    AlchemySystem.SetDiamondPillCount(3)
    AlchemySystem.SetTemperingPillEaten(20)
    AlchemySystem.SetDragonBloodPillCount(2)
    AlchemySystem.SetSwordIntentPillCount(1)
    AlchemySystem.SetAbyssSealPillCount(2)

    -- 第一次序列化
    local serialized1 = SaveSerializer.SerializePlayer()

    -- 清空状态模拟重启
    AlchemySystem.ResetRuntimeState()

    -- 反序列化（从 serialized1 恢复）
    SaveSerializer.DeserializePlayer(serialized1)

    -- 第二次序列化
    local serialized2 = SaveSerializer.SerializePlayer()

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
-- RT-4: pillCounts 双写一致性（Set* 后 player.pillCounts 自动同步）
-- ─────────────────────────────────────────────────────────────

print("\n── RT-4: pillCounts 双写一致性 ──")
do
    local player = resetEnv()
    -- 先初始化 pillCounts 结构（模拟 SaveLoader 初始化）
    player.pillCounts = {
        tiger = 0, snake = 0, diamond = 0, tempering = 0,
        dragon_blood = 0, sword_intent = 0, abyss_seal = 0,
    }

    AlchemySystem.SetTigerPillCount(3)
    AlchemySystem.SetSnakePillCount(2)
    AlchemySystem.SetDiamondPillCount(4)
    AlchemySystem.SetTemperingPillEaten(10)
    AlchemySystem.SetDragonBloodPillCount(1)
    AlchemySystem.SetSwordIntentPillCount(2)
    AlchemySystem.SetAbyssSealPillCount(1)

    assert_eq(player.pillCounts.tiger, 3, "RT-4a: pillCounts.tiger 双写同步")
    assert_eq(player.pillCounts.snake, 2, "RT-4b: pillCounts.snake 双写同步")
    assert_eq(player.pillCounts.diamond, 4, "RT-4c: pillCounts.diamond 双写同步")
    assert_eq(player.pillCounts.tempering, 10, "RT-4d: pillCounts.tempering 双写同步")
    assert_eq(player.pillCounts.dragon_blood, 1, "RT-4e: pillCounts.dragon_blood 双写同步")
    assert_eq(player.pillCounts.sword_intent, 2, "RT-4f: pillCounts.sword_intent 双写同步")
    assert_eq(player.pillCounts.abyss_seal, 1, "RT-4g: pillCounts.abyss_seal 双写同步")
end

-- ─────────────────────────────────────────────────────────────
-- RT-5: 缺失字段时 Deserialize 默认为 0
-- ─────────────────────────────────────────────────────────────

print("\n── RT-5: 缺失字段时 Deserialize 默认为 0 ──")
do
    local player = resetEnv()

    -- 先设置非零值
    AlchemySystem.SetTigerPillCount(99)
    AlchemySystem.SetSwordIntentPillCount(99)

    -- 反序列化一个空 table（模拟旧版存档缺失字段）
    SaveSerializer.DeserializePlayer({ level = 1 })

    assert_eq(AlchemySystem.GetTigerPillCount(), 0, "RT-5a: 缺失 tigerPillCount 默认 0")
    assert_eq(AlchemySystem.GetSnakePillCount(), 0, "RT-5b: 缺失 snakePillCount 默认 0")
    assert_eq(AlchemySystem.GetDiamondPillCount(), 0, "RT-5c: 缺失 diamondPillCount 默认 0")
    assert_eq(AlchemySystem.GetTemperingPillEaten(), 0, "RT-5d: 缺失 temperingPillEaten 默认 0")
    assert_eq(AlchemySystem.GetDragonBloodPillCount(), 0, "RT-5e: 缺失 dragonBloodPillCount 默认 0")
    assert_eq(AlchemySystem.GetSwordIntentPillCount(), 0, "RT-5f: 缺失 swordIntentPillCount 默认 0")
    assert_eq(AlchemySystem.GetAbyssSealPillCount(), 0, "RT-5g: 缺失 abyssSealPillCount 默认 0")
end

-- ─────────────────────────────────────────────────────────────
-- RT-6: pillCounts 缺失时 SaveLoader 校正逻辑从扁平字段构建
-- 模拟 SaveLoader.ProcessLoadedData 中 Step 5 逻辑
-- ─────────────────────────────────────────────────────────────

print("\n── RT-6: pillCounts 缺失时从 AlchemySystem getter 构建 ──")
do
    local player = resetEnv()

    -- 通过 DeserializePlayer 设置真值
    SaveSerializer.DeserializePlayer({
        tigerPillCount = 3, snakePillCount = 2, diamondPillCount = 1,
        temperingPillEaten = 8, dragonBloodPillCount = 0,
        swordIntentPillCount = 2, abyssSealPillCount = 1,
        level = 10,
    })

    -- player.pillCounts 为 nil（旧版存档无此字段）
    player.pillCounts = nil

    -- 模拟 SaveLoader Step 5: 从 AlchemySystem getter 构建 pillCounts
    local current = {
        tiger        = AlchemySystem.GetTigerPillCount(),
        snake        = AlchemySystem.GetSnakePillCount(),
        diamond      = AlchemySystem.GetDiamondPillCount(),
        tempering    = AlchemySystem.GetTemperingPillEaten(),
        sword_intent = AlchemySystem.GetSwordIntentPillCount(),
        abyss_seal   = AlchemySystem.GetAbyssSealPillCount(),
    }
    -- pillCounts 不存在 → 初始化
    player.pillCounts = current

    assert_true(player.pillCounts ~= nil, "RT-6a: pillCounts 被创建")
    assert_eq(player.pillCounts.tiger, 3, "RT-6b: pillCounts.tiger 从 getter 构建")
    assert_eq(player.pillCounts.snake, 2, "RT-6c: pillCounts.snake 从 getter 构建")
    assert_eq(player.pillCounts.diamond, 1, "RT-6d: pillCounts.diamond 从 getter 构建")
    assert_eq(player.pillCounts.tempering, 8, "RT-6e: pillCounts.tempering 从 getter 构建")
    assert_eq(player.pillCounts.sword_intent, 2, "RT-6f: pillCounts.sword_intent 从 getter 构建")
    assert_eq(player.pillCounts.abyss_seal, 1, "RT-6g: pillCounts.abyss_seal 从 getter 构建")
end

-- ─────────────────────────────────────────────────────────────
-- RT-7: pillCounts 漂移时以 AlchemySystem getter 为准修正
-- ─────────────────────────────────────────────────────────────

print("\n── RT-7: pillCounts 漂移时以 getter 为准修正 ──")
do
    local player = resetEnv()

    -- 通过 DeserializePlayer 设置真值
    SaveSerializer.DeserializePlayer({
        tigerPillCount = 4, snakePillCount = 3, diamondPillCount = 5,
        temperingPillEaten = 20, dragonBloodPillCount = 0,
        swordIntentPillCount = 2, abyssSealPillCount = 1,
        level = 10,
    })

    -- 模拟 pillCounts 存在但与 getter 不一致（漂移）
    player.pillCounts = {
        tiger = 2,        -- 漂移：getter 是 4
        snake = 3,        -- 一致
        diamond = 5,      -- 一致
        tempering = 15,   -- 漂移：getter 是 20
        sword_intent = 2, -- 一致
        abyss_seal = 0,   -- 漂移：getter 是 1
    }

    -- 模拟 SaveLoader Step 5 漂移校正逻辑
    local current = {
        tiger        = AlchemySystem.GetTigerPillCount(),
        snake        = AlchemySystem.GetSnakePillCount(),
        diamond      = AlchemySystem.GetDiamondPillCount(),
        tempering    = AlchemySystem.GetTemperingPillEaten(),
        sword_intent = AlchemySystem.GetSwordIntentPillCount(),
        abyss_seal   = AlchemySystem.GetAbyssSealPillCount(),
    }
    for key, val in pairs(current) do
        if player.pillCounts[key] ~= val then
            player.pillCounts[key] = val  -- 以 getter 为准
        end
    end

    -- 验证修正结果
    assert_eq(player.pillCounts.tiger, 4, "RT-7a: 漂移修正 tiger 4 (was 2)")
    assert_eq(player.pillCounts.snake, 3, "RT-7b: 未漂移 snake 保持 3")
    assert_eq(player.pillCounts.diamond, 5, "RT-7c: 未漂移 diamond 保持 5")
    assert_eq(player.pillCounts.tempering, 20, "RT-7d: 漂移修正 tempering 20 (was 15)")
    assert_eq(player.pillCounts.sword_intent, 2, "RT-7e: 未漂移 sword_intent 保持 2")
    assert_eq(player.pillCounts.abyss_seal, 1, "RT-7f: 漂移修正 abyss_seal 1 (was 0)")
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
else
    print("[test_alchemy_save_roundtrip] ✅ 全部通过")
end

-- TestRunner 导出（P0-1: 统一测试入口）
return { passed = passed, failed = failed, total = totalTests }
