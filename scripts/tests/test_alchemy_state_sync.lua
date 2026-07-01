-- ============================================================================
-- test_alchemy_state_sync.lua — 炼丹炉状态同步 + 清零测试
--
-- 直接验证生产实现：AlchemySystem 运行时状态行为
--
-- 覆盖：
--   SS-1: GetSnapshot 与各 getter 一致
--   SS-2: ResetRuntimeState 后所有丹药计数归零
--   SS-3: player.pillCounts 双写一致性（Set* 后 pillCounts 同步更新）
--   SS-4: Set* 接受 nil 参数时默认为 0（防御性）
--   SS-5: 连续 Set/Get 幂等性
--   SS-6: pillCounts 不存在时 Set* 不报错（双写安全）
--   SS-7: DeserializePlayer 后 GetSnapshot 与存档数据一致
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
-- Stub 层：同 roundtrip 测试
-- ============================================================================

package.loaded["systems.InventorySystem"] = {
    CountConsumable = function() return 0 end,
    CountUnlockedConsumable = function() return 0 end,
    GetFreeSlots = function() return 10 end,
    AddConsumable = function() end,
    ConsumeConsumable = function() return true end,
}

local GameState = {
    player = nil,
    currentChapter = 1,
}
function GameState.Init()
    GameState.player = nil
    GameState.currentChapter = 1
end
package.loaded["core.GameState"] = GameState

package.loaded["config.GameConfig"] = {
    EXP_TABLE = {},
    PET_MATERIALS = {},
    PET_FOOD = {},
    CONSUMABLES = {},
    REALM_COMPAT = nil,
    REALMS = setmetatable({}, { __index = function() return { attackSpeedBonus = 0 } end }),
}

package.loaded["core.EventBus"] = { On = function() end, Emit = function() end }

package.loaded["config.PillRecipes"] = {
    CONSUMABLES = {},
    PERMANENTS = {},
    TOKEN_BOXES = {},
    TOKEN_BOX_LINGYUN_COST = 100,
    TOKEN_BOX_TOKEN_COST = 5,
    STAT_DISPLAY = {},
}

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

package.loaded["systems.save.SaveState"] = { _lastKnownCollectionCount = 0, _cachedCollectionData = nil }
package.loaded["systems.save.SaveMigrations"] = { MigrateSaveData = function(d) return d end }
package.loaded["systems.save.SaveKeys"] = {}

-- ============================================================================
-- Player 工厂
-- ============================================================================

local function CreateMockPlayer()
    local p = {
        level = 10, exp = 500, hp = 100, maxHp = 200,
        atk = 50, def = 30, hpRegen = 1,
        pillKillHeal = 0, shadowGodKillHeal = 0, pillConstitution = 0, gangguConstitution = 0,
        fruitFortune = 0,
        seaPillarDef = 0, seaPillarAtk = 0, seaPillarMaxHp = 0, seaPillarHpRegen = 0,
        swordPoolAtk = 0, swordPoolDef = 0, swordPoolMaxHp = 0, swordPoolHpRegen = 0,
        prisonTowerAtk = 0, prisonTowerDef = 0, prisonTowerMaxHp = 0, prisonTowerHpRegen = 0,
        daoTreeWisdom = 0, daoTreeWisdomPity = 0,
        gold = 100, lingYun = 1000, realm = "mortal",
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
    function p:GetTotalMaxHp()
        return self.maxHp
    end
    return p
end

-- ============================================================================
-- 加载生产模块
-- ============================================================================

local AlchemySystem = require("systems.AlchemySystem")
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

local function resetEnv()
    AlchemySystem.ResetRuntimeState()
    local player = CreateMockPlayer()
    GameState.player = player
    return player
end

-- ============================================================================
-- 测试用例
-- ============================================================================

print("\n[test_alchemy_state_sync] === 炼丹炉状态同步测试 ===\n")

-- ─────────────────────────────────────────────────────────────
-- SS-1: GetSnapshot 与各 getter 一致
-- ─────────────────────────────────────────────────────────────

print("── SS-1: GetSnapshot 与各 getter 一致 ──")
do
    resetEnv()

    AlchemySystem.SetTigerPillCount(3)
    AlchemySystem.SetSnakePillCount(5)
    AlchemySystem.SetDiamondPillCount(2)
    AlchemySystem.SetTemperingPillEaten(30)
    AlchemySystem.SetDragonBloodPillCount(1)
    AlchemySystem.SetSwordIntentPillCount(2)
    AlchemySystem.SetAbyssSealPillCount(1)
    AlchemySystem.SetShadowGodPillCount(6)

    local snap = AlchemySystem.GetSnapshot()

    assert_eq(snap.tiger, AlchemySystem.GetTigerPillCount(), "SS-1a: snapshot.tiger == getter")
    assert_eq(snap.snake, AlchemySystem.GetSnakePillCount(), "SS-1b: snapshot.snake == getter")
    assert_eq(snap.diamond, AlchemySystem.GetDiamondPillCount(), "SS-1c: snapshot.diamond == getter")
    assert_eq(snap.tempering, AlchemySystem.GetTemperingPillEaten(), "SS-1d: snapshot.tempering == getter")
    assert_eq(snap.dragonBlood, AlchemySystem.GetDragonBloodPillCount(), "SS-1e: snapshot.dragonBlood == getter")
    assert_eq(snap.swordIntent, AlchemySystem.GetSwordIntentPillCount(), "SS-1f: snapshot.swordIntent == getter")
    assert_eq(snap.abyssSeal, AlchemySystem.GetAbyssSealPillCount(), "SS-1g: snapshot.abyssSeal == getter")
    assert_eq(snap.shadowGod, AlchemySystem.GetShadowGodPillCount(), "SS-1h: snapshot.shadowGod == getter")
end

-- ─────────────────────────────────────────────────────────────
-- SS-2: ResetRuntimeState 后所有丹药计数归零
-- ─────────────────────────────────────────────────────────────

print("\n── SS-2: ResetRuntimeState 后所有计数归零 ──")
do
    resetEnv()

    -- 设置运行时非零值
    AlchemySystem.SetTigerPillCount(4)
    AlchemySystem.SetSnakePillCount(3)
    AlchemySystem.SetDiamondPillCount(5)
    AlchemySystem.SetTemperingPillEaten(20)
    AlchemySystem.SetDragonBloodPillCount(2)
    AlchemySystem.SetSwordIntentPillCount(1)
    AlchemySystem.SetAbyssSealPillCount(2)
    AlchemySystem.SetShadowGodPillCount(7)

    -- 执行 ResetRuntimeState（生产中由 ReturnToLogin 调用）
    AlchemySystem.ResetRuntimeState()

    assert_eq(AlchemySystem.GetTigerPillCount(), 0, "SS-2a: tiger 归零")
    assert_eq(AlchemySystem.GetSnakePillCount(), 0, "SS-2b: snake 归零")
    assert_eq(AlchemySystem.GetDiamondPillCount(), 0, "SS-2c: diamond 归零")
    assert_eq(AlchemySystem.GetTemperingPillEaten(), 0, "SS-2d: tempering 归零")
    assert_eq(AlchemySystem.GetDragonBloodPillCount(), 0, "SS-2e: dragonBlood 归零")
    assert_eq(AlchemySystem.GetSwordIntentPillCount(), 0, "SS-2f: swordIntent 归零")
    assert_eq(AlchemySystem.GetAbyssSealPillCount(), 0, "SS-2g: abyssSeal 归零")
    assert_eq(AlchemySystem.GetShadowGodPillCount(), 0, "SS-2h: shadowGod 归零")
end

-- ─────────────────────────────────────────────────────────────
-- SS-3: player.pillCounts 双写一致性
-- ─────────────────────────────────────────────────────────────

print("\n── SS-3: player.pillCounts 双写一致性 ──")
do
    local player = resetEnv()

    -- 初始化 pillCounts 结构
    player.pillCounts = {
        tiger = 0, snake = 0, diamond = 0, tempering = 0,
        dragon_blood = 0, sword_intent = 0, abyss_seal = 0, shadow_god = 0,
    }

    -- Set* 应自动同步到 player.pillCounts
    AlchemySystem.SetTigerPillCount(1)
    assert_eq(player.pillCounts.tiger, 1, "SS-3a: Set tiger → pillCounts.tiger 同步")

    AlchemySystem.SetTigerPillCount(2)
    assert_eq(player.pillCounts.tiger, 2, "SS-3b: Set tiger 再次 → pillCounts.tiger 更新")

    AlchemySystem.SetSwordIntentPillCount(3)
    assert_eq(player.pillCounts.sword_intent, 3, "SS-3c: Set swordIntent → pillCounts.sword_intent 同步")

    AlchemySystem.SetDragonBloodPillCount(1)
    assert_eq(player.pillCounts.dragon_blood, 1, "SS-3d: Set dragonBlood → pillCounts.dragon_blood 同步")

    AlchemySystem.SetAbyssSealPillCount(2)
    assert_eq(player.pillCounts.abyss_seal, 2, "SS-3e: Set abyssSeal → pillCounts.abyss_seal 同步")

    AlchemySystem.SetShadowGodPillCount(6)
    assert_eq(player.pillCounts.shadow_god, 6, "SS-3f: Set shadowGod → pillCounts.shadow_god 同步")
end

-- ─────────────────────────────────────────────────────────────
-- SS-4: Set* 接受 nil 参数时默认为 0（防御性）
-- ─────────────────────────────────────────────────────────────

print("\n── SS-4: Set* 接受 nil 参数时默认为 0 ──")
do
    resetEnv()

    -- 设非零值
    AlchemySystem.SetTigerPillCount(5)
    AlchemySystem.SetSnakePillCount(3)
    AlchemySystem.SetDiamondPillCount(7)
    AlchemySystem.SetShadowGodPillCount(9)

    -- 传 nil
    AlchemySystem.SetTigerPillCount(nil)
    AlchemySystem.SetSnakePillCount(nil)
    AlchemySystem.SetDiamondPillCount(nil)
    AlchemySystem.SetShadowGodPillCount(nil)

    assert_eq(AlchemySystem.GetTigerPillCount(), 0, "SS-4a: SetTigerPillCount(nil) → 0")
    assert_eq(AlchemySystem.GetSnakePillCount(), 0, "SS-4b: SetSnakePillCount(nil) → 0")
    assert_eq(AlchemySystem.GetDiamondPillCount(), 0, "SS-4c: SetDiamondPillCount(nil) → 0")
    assert_eq(AlchemySystem.GetShadowGodPillCount(), 0, "SS-4d: SetShadowGodPillCount(nil) → 0")
end

-- ─────────────────────────────────────────────────────────────
-- SS-5: 连续 Set/Get 幂等性
-- ─────────────────────────────────────────────────────────────

print("\n── SS-5: 连续 Set/Get 幂等性 ──")
do
    resetEnv()

    -- 多次 Set 同一个值
    AlchemySystem.SetTigerPillCount(3)
    AlchemySystem.SetTigerPillCount(3)
    AlchemySystem.SetTigerPillCount(3)
    assert_eq(AlchemySystem.GetTigerPillCount(), 3, "SS-5a: 多次 Set 同值幂等")

    -- 交替 Set 不同值
    AlchemySystem.SetDiamondPillCount(1)
    AlchemySystem.SetDiamondPillCount(5)
    assert_eq(AlchemySystem.GetDiamondPillCount(), 5, "SS-5b: 后 Set 覆盖前值")

    -- Set 0 → Set 值 → Get 应为最新值
    AlchemySystem.SetSnakePillCount(0)
    AlchemySystem.SetSnakePillCount(7)
    assert_eq(AlchemySystem.GetSnakePillCount(), 7, "SS-5c: Set 0 后再 Set 正常覆盖")

    AlchemySystem.SetShadowGodPillCount(0)
    AlchemySystem.SetShadowGodPillCount(6)
    assert_eq(AlchemySystem.GetShadowGodPillCount(), 6, "SS-5d: shadowGod Set 0 后再 Set 正常覆盖")
end

-- ─────────────────────────────────────────────────────────────
-- SS-6: pillCounts 不存在时 Set* 不报错（双写安全）
-- ─────────────────────────────────────────────────────────────

print("\n── SS-6: pillCounts 不存在时 Set* 不报错 ──")
do
    local player = resetEnv()
    -- 确保 pillCounts 为 nil（模拟未初始化场景）
    player.pillCounts = nil

    -- 所有 Set* 不应报错
    local ok, err = pcall(function()
        AlchemySystem.SetTigerPillCount(5)
        AlchemySystem.SetSnakePillCount(3)
        AlchemySystem.SetDiamondPillCount(2)
        AlchemySystem.SetTemperingPillEaten(10)
        AlchemySystem.SetDragonBloodPillCount(1)
        AlchemySystem.SetSwordIntentPillCount(2)
        AlchemySystem.SetAbyssSealPillCount(1)
        AlchemySystem.SetShadowGodPillCount(6)
    end)

    assert_true(ok, "SS-6a: Set* 在 pillCounts=nil 时不报错")
    assert_eq(AlchemySystem.GetTigerPillCount(), 5, "SS-6b: getter 仍正确返回值")
    assert_true(player.pillCounts == nil, "SS-6c: pillCounts 未被 Set* 自行创建")
end

-- ─────────────────────────────────────────────────────────────
-- SS-7: DeserializePlayer 后 GetSnapshot 与存档数据一致
-- ─────────────────────────────────────────────────────────────

print("\n── SS-7: DeserializePlayer 后 GetSnapshot 与存档一致 ──")
do
    local player = resetEnv()

    local saveData = {
        tigerPillCount = 6, snakePillCount = 4, diamondPillCount = 3,
        temperingPillEaten = 25, dragonBloodPillCount = 2,
        swordIntentPillCount = 1, abyssSealPillCount = 2, shadowGodPillCount = 6,
        shadowGodKillHeal = 120,
        level = 15, exp = 1000, maxHp = 300, atk = 80, def = 40, hpRegen = 2,
        gold = 200, lingYun = 800, realm = "foundation",
    }

    SaveSerializer.DeserializePlayer(saveData)

    local snap = AlchemySystem.GetSnapshot()
    assert_eq(snap.tiger, 6, "SS-7a: snapshot.tiger == saveData.tigerPillCount")
    assert_eq(snap.snake, 4, "SS-7b: snapshot.snake == saveData.snakePillCount")
    assert_eq(snap.diamond, 3, "SS-7c: snapshot.diamond == saveData.diamondPillCount")
    assert_eq(snap.tempering, 25, "SS-7d: snapshot.tempering == saveData.temperingPillEaten")
    assert_eq(snap.dragonBlood, 2, "SS-7e: snapshot.dragonBlood == saveData.dragonBloodPillCount")
    assert_eq(snap.swordIntent, 1, "SS-7f: snapshot.swordIntent == saveData.swordIntentPillCount")
    assert_eq(snap.abyssSeal, 2, "SS-7g: snapshot.abyssSeal == saveData.abyssSealPillCount")
    assert_eq(snap.shadowGod, 6, "SS-7h: snapshot.shadowGod == saveData.shadowGodPillCount")
    assert_eq(GameState.player.shadowGodKillHeal, 120, "SS-7i: shadowGodKillHeal == saveData.shadowGodKillHeal")
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
else
    print("[test_alchemy_state_sync] ✅ 全部通过")
end

-- TestRunner 导出（P0-1: 统一测试入口）
return { passed = passed, failed = failed, total = totalTests }
