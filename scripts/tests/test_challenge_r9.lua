-- ============================================================================
-- test_challenge_r9.lua - R9 声望、仙1法宝、四 BOSS 技能与难度基线合同测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

-- 统一门禁在同一 LuaRuntime 内顺序执行，前序测试可能向 package.loaded 注入桩模块。
-- 本测试需要读取真实配置，因此先刷新本链路的模块，避免测试顺序影响结果。
local freshModules = {
    "core.EventBus",
    "core.GameState",
    "config.GameConfig",
    "config.ChallengeConfig",
    "config.EquipmentData",
    "config.MonsterData",
    "systems.loot.shared",
    "systems.loot.generation",
    "systems.loot.pickup",
    "systems.loot.rewards",
    "systems.LootSystem",
    "systems.challenge.shared",
    "systems.challenge.persistence",
    "systems.challenge.rewards",
    "systems.combat.BossMechanics",
    "systems.CombatSystem",
    "entities.Monster",
}
for _, moduleName in ipairs(freshModules) do
    package.loaded[moduleName] = nil
end

local ChallengeConfig = require("config.ChallengeConfig")
local EquipmentData = require("config.EquipmentData")
local MonsterData = require("config.MonsterData")
local LootSystem = require("systems.LootSystem")
local Consumables = require("systems.inventory.consumables")
local Monster = require("entities.Monster")
local persistence = require("systems.challenge.persistence")
local rewards = require("systems.challenge.rewards")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CombatSystem = require("systems.CombatSystem")

local passed, failed, total = 0, 0, 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

local function assertTrue(value, message)
    if not value then error(message or "expected true", 2) end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local function assertNear(actual, expected, epsilon, message)
    if math.abs(actual - expected) > (epsilon or 0.000001) then
        error((message or "values not near")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local function hasValue(list, expected)
    for _, value in ipairs(list or {}) do
        if value == expected then return true end
    end
    return false
end

local function hasSkillId(skills, expectedId)
    for _, skill in ipairs(skills or {}) do
        if skill.id == expectedId then return true end
    end
    return false
end

local function countSkillId(skills, expectedId)
    local count = 0
    for _, skill in ipairs(skills or {}) do
        if skill.id == expectedId then count = count + 1 end
    end
    return count
end

local function findEntry(entries, entryType, subId)
    for _, entry in ipairs(entries) do
        if entry.type == entryType and (subId == nil or entry.subId == subId) then
            return entry
        end
    end
    return nil
end

local R9_BOSSES = {
    xuesha = {
        id = "challenge_shenmo_r9",
        r8Id = "challenge_shenmo_r8",
        newSkill = "shenmo_blood_hunt",
        newSkillDamageMult = 3.0,
        warningShape = "line",
        effect = "slow",
        effectDuration = 2.0,
        effectValue = 0.35,
        fieldDamagePercent = 0.50,
    },
    haoqi = {
        id = "challenge_luqingyun_r9",
        r8Id = "challenge_luqingyun_r8",
        newSkill = "luqingyun_righteous_lock",
        newSkillDamageMult = 2.5,
        warningShape = "rect",
        effect = "stun",
        effectDuration = 1.0,
        fieldDamagePercent = 0.50,
    },
    qingyun = {
        id = "challenge_yunshang_r9",
        r8Id = "challenge_yunshang_r8",
        newSkill = "yunshang_jade_echo",
        newSkillDamageMult = 2.0,
        warningShape = "line",
        effect = "slow",
        effectDuration = 1.5,
        effectValue = 0.25,
        burstCount = 2,
        fieldDamagePercent = 0.50,
    },
    fengmo = {
        id = "challenge_liwuji_r9",
        r8Id = "challenge_liwuji_r8",
        newSkill = "liwuji_seal_repel",
        newSkillDamageMult = 3.0,
        warningShape = "cone",
        effect = "knockback",
        effectValue = 3.0,
        fieldDamagePercent = 0.50,
    },
}

print("\n[test_challenge_r9] === R9 声望挑战合同测试 ===\n")

test("R9 基础阶梯使用 T11、谪仙令与 1000 解锁费", function()
    assertEqual(ChallengeConfig.MAX_REPUTATION_LEVEL, 9)
    assertEqual(ChallengeConfig.REPUTATION_TIER[9], 11)
    assertEqual(ChallengeConfig.REPUTATION_TOKEN[9], "zhexian_ling")
    assertEqual(ChallengeConfig.REPUTATION_UNLOCK_COST[9], 1000)
    assertEqual(ChallengeConfig.ATTEMPT_COST, 10)
end)

test("R8 重复上限为青色，R9 重复范围为蓝到红", function()
    local r8MinQuality, r8MaxQuality = ChallengeConfig.GetRepeatQualityRange(8)
    assertEqual(r8MinQuality, "green")
    assertEqual(r8MaxQuality, "cyan")

    assertEqual(ChallengeConfig.GetFirstClearQuality(9), "orange")
    local minQuality, maxQuality = ChallengeConfig.GetRepeatQualityRange(9)
    assertEqual(minQuality, "blue")
    assertEqual(maxQuality, "red")
end)

test("R9 额外候选总概率精确为 9%", function()
    assertNear(ChallengeConfig.GetExtraDropChance(9), 0.09, 0.0000001)
end)

test("R9 额外候选概率与数量符合规格", function()
    local entries = ChallengeConfig.BuildExtraDropTable(9)
    local gold = findEntry(entries, "gold_bar")
    local food = findEntry(entries, "food")
    local steel = findEntry(entries, "essence", "ganggu_essence")
    local cultivation = findEntry(entries, "cultivation_fruit")
    local lingyun = findEntry(entries, "lingyun_fruit")

    assertTrue(gold and food and steel and cultivation and lingyun)
    assertNear(gold.chance, 0.01)
    assertEqual(gold.count, 18)
    assertNear(food.chance, 0.03)
    assertEqual(food.subId, "dragon_marrow")
    assertEqual(food.count, 4)
    assertNear(steel.chance, 0.015)
    assertEqual(steel.count, 1)
    assertEqual(cultivation.count, 6)
    assertEqual(lingyun.count, 4)

    local baseEssenceChance = 0
    local baseEssenceCount = 0
    for _, essenceId in ipairs(ChallengeConfig.BASE_ESSENCE_IDS) do
        local entry = findEntry(entries, "essence", essenceId)
        assertTrue(entry ~= nil, "missing base essence " .. essenceId)
        assertNear(entry.chance, 0.003)
        assertEqual(entry.count, 1)
        baseEssenceChance = baseEssenceChance + entry.chance
        baseEssenceCount = baseEssenceCount + 1
    end
    assertEqual(baseEssenceCount, 5)
    assertNear(baseEssenceChance, 0.015)
end)

test("R8 额外候选为 8.5%，R9 为 9%，金条固定 1%并按双数递增", function()
    local r8Entries = ChallengeConfig.BuildExtraDropTable(8)
    local r9Entries = ChallengeConfig.BuildExtraDropTable(9)

    assertNear(ChallengeConfig.GetExtraDropChance(8), 0.085, 0.0000001)
    assertNear(ChallengeConfig.GetExtraDropChance(9), 0.09, 0.0000001)

    local r8Gold = findEntry(r8Entries, "gold_bar")
    local r9Gold = findEntry(r9Entries, "gold_bar")
    assertNear(r8Gold.chance, 0.01)
    assertEqual(r8Gold.count, 16)
    assertNear(r9Gold.chance, 0.01)
    assertEqual(r9Gold.count, 18)

    for repLevel = 1, 9 do
        local gold = findEntry(ChallengeConfig.BuildExtraDropTable(repLevel), "gold_bar")
        assertNear(gold.chance, 0.01)
        assertEqual(gold.count, repLevel * 2)
        assertEqual(ChallengeConfig.GetExtraGoldBarCount(repLevel), repLevel * 2)
    end

    local r8Food = findEntry(r8Entries, "food")
    local r9Food = findEntry(r9Entries, "food")
    assertEqual(r8Food.subId, "dragon_marrow")
    assertEqual(r8Food.count, 3)
    assertEqual(r9Food.subId, "dragon_marrow")
    assertEqual(r9Food.count, 4)

    local r8Steel = findEntry(r8Entries, "essence", "ganggu_essence")
    local r9Steel = findEntry(r9Entries, "essence", "ganggu_essence")
    assertNear(r8Steel.chance, 0.01)
    assertNear(r9Steel.chance, 0.015)

    assertEqual(findEntry(r8Entries, "cultivation_fruit").count, 5)
    assertEqual(findEntry(r9Entries, "cultivation_fruit").count, 6)
    assertEqual(findEntry(r8Entries, "lingyun_fruit").count, 3)
    assertEqual(findEntry(r9Entries, "lingyun_fruit").count, 4)
end)

test("四阵营 R9 配置完整映射到对应 BOSS", function()
    for factionKey, expected in pairs(R9_BOSSES) do
        local faction = ChallengeConfig.FACTIONS[factionKey]
        local r9 = faction and faction.reputation and faction.reputation[9]
        assertTrue(r9 ~= nil, "missing faction R9 " .. factionKey)
        assertEqual(r9.tier, 11)
        assertEqual(r9.tokenId, "zhexian_ling")
        assertEqual(r9.unlockCost, 1000)
        assertEqual(r9.monsterId, expected.id)
    end
end)

test("四名 R9 BOSS 均为 Lv140 人仙1阶圣级三阶段", function()
    for _, expected in pairs(R9_BOSSES) do
        local boss = MonsterData.Types[expected.id]
        assertTrue(boss ~= nil, "missing boss " .. expected.id)
        assertEqual(boss.level, 140)
        assertEqual(boss.realm, "renxian_1")
        assertEqual(boss.category, "saint_boss")
        assertEqual(boss.phases, 3)
        assertEqual(#boss.phaseConfig, 2)
        assertEqual(#boss.skills, 3)
        assertNear(boss.phaseConfig[1].threshold, 0.6)
        assertNear(boss.phaseConfig[2].threshold, 0.3)
        assertNear(boss.fieldDamagePercent, expected.fieldDamagePercent)
        assertNear(boss.berserkBuff.atkSpeedMult, 1.4)
        assertNear(boss.berserkBuff.speedMult, 1.4)
        assertNear(boss.berserkBuff.cdrMult, 0.6)

        local r8 = MonsterData.Types[expected.r8Id]
        assertEqual(boss.phaseConfig[1].atkMult, r8.phaseConfig[1].atkMult)
        assertNear(boss.phaseConfig[1].speedMult, r8.phaseConfig[1].speedMult)
        assertNear(boss.phaseConfig[1].intervalMult, r8.phaseConfig[1].intervalMult)
        assertNear(boss.phaseConfig[2].atkMult, r8.phaseConfig[2].atkMult)
        assertNear(boss.phaseConfig[2].speedMult, r8.phaseConfig[2].speedMult)
        assertNear(boss.phaseConfig[2].intervalMult, r8.phaseConfig[2].intervalMult)
        assertNear(boss.berserkBuff.atkSpeedMult, r8.berserkBuff.atkSpeedMult)
        assertNear(boss.berserkBuff.speedMult, r8.berserkBuff.speedMult)
        assertNear(boss.berserkBuff.cdrMult, r8.berserkBuff.cdrMult)
    end
end)

test("R2-R9 phased reputation bosses use 60/30 thresholds", function()
    local prefixes = {
        "challenge_shenmo_r",
        "challenge_luqingyun_r",
        "challenge_yunshang_r",
        "challenge_liwuji_r",
    }
    for _, prefix in ipairs(prefixes) do
        assertEqual(MonsterData.Types[prefix .. "1"].phases, 1)
        for repLevel = 2, 9 do
            local boss = MonsterData.Types[prefix .. repLevel]
            assertEqual(boss.phases, 3)
            assertNear(boss.phaseConfig[1].threshold, 0.6)
            assertNear(boss.phaseConfig[2].threshold, 0.3)
        end
    end
end)

test("四名 R9 BOSS 的新增技能只在 P2/P3 加入，R8 不含该技能", function()
    for _, expected in pairs(R9_BOSSES) do
        local r9 = MonsterData.Types[expected.id]
        local r8 = MonsterData.Types[expected.r8Id]
        assertTrue(not hasValue(r9.skills, expected.newSkill), expected.id .. " new skill leaked into P1")
        assertTrue(not hasValue(r8.skills, expected.newSkill), expected.r8Id .. " unexpectedly has new skill")

        local phase2Adds = r9.phaseConfig[1].addSkills or { r9.phaseConfig[1].addSkill }
        assertTrue(hasValue(phase2Adds, expected.newSkill), expected.id .. " missing P2 new skill")

        local skill = MonsterData.Skills[expected.newSkill]
        assertTrue(skill ~= nil, "missing skill definition " .. expected.newSkill)
        assertTrue(not skill.isFieldSkill, expected.newSkill .. " must not add another field skill")
        assertTrue(skill.cooldown * r9.berserkBuff.cdrMult >= 8.39,
            expected.newSkill .. " effective cooldown too short")
        assertNear(skill.damageMult, expected.newSkillDamageMult)
        assertEqual(skill.warningShape, expected.warningShape)
        assertEqual(skill.effect, expected.effect)
        if expected.effectDuration then
            assertNear(skill.effectDuration, expected.effectDuration)
        end
        if expected.effectValue then
            assertNear(skill.effectValue, expected.effectValue)
        end
        if expected.burstCount then
            assertEqual(skill.burstCount, expected.burstCount)
            assertEqual(skill.burstTrack, true)
        end
    end
    assertNear(MonsterData.Skills.line_charge.damageMult, 2.2)
    assertNear(MonsterData.Skills.luqingyun_righteous_lock.effectDuration, 1.0)
    assertEqual(MonsterData.Skills.yunshang_jade_echo.burstCount, 2)
    assertNear(MonsterData.Skills.liwuji_seal_repel.effectValue, 3.0)
    assertNear(MonsterData.Skills.liwuji_void_pull_r9.damageMult, 2.0)
    assertNear(MonsterData.Skills.liwuji_void_pull.damageMult, 1.8)
end)

test("四名 R9 BOSS 在 60% 血量进入 P2，30% 血量进入 P3", function()
    for _, expected in pairs(R9_BOSSES) do
        local monster = Monster.New(MonsterData.Types[expected.id], 5, 5)
        assertTrue(not hasSkillId(monster.skills, expected.newSkill))
        if expected.id == "challenge_liwuji_r9" then
            assertTrue(not hasSkillId(monster.skills, "liwuji_void_pull_r9"))
        end

        monster.hp = math.floor(monster.maxHp * 0.6)
        monster:CheckPhaseTransition()

        assertEqual(monster.currentPhase, 2)
        assertEqual(countSkillId(monster.skills, expected.newSkill), 1,
            expected.id .. " did not gain exactly one P2 skill")
        if expected.id == "challenge_liwuji_r9" then
            assertEqual(countSkillId(monster.skills, "liwuji_void_pull_r9"), 1)
        end

        monster.hp = math.floor(monster.maxHp * 0.3)
        monster:CheckPhaseTransition()
        assertEqual(monster.currentPhase, 3)
        assertEqual(countSkillId(monster.skills, expected.newSkill), 1,
            expected.id .. " duplicated or lost its P2 skill in P3")
        if expected.id == "challenge_liwuji_r9" then
            assertEqual(countSkillId(monster.skills, "liwuji_void_pull_r9"), 1)
        end
    end
end)

test("R9 不再挂载未实现的分身与囚笼占位技能", function()
    local shenmo = MonsterData.Types.challenge_shenmo_r9
    local luqingyun = MonsterData.Types.challenge_luqingyun_r9
    for _, phase in ipairs(shenmo.phaseConfig) do
        assertTrue(phase.addSkill ~= "shenmo_shadow_clone")
    end
    for _, phase in ipairs(luqingyun.phaseConfig) do
        assertTrue(phase.addSkill ~= "luqingyun_prison")
    end
end)

test("四场 R9 战斗保留各自机制边界", function()
    local shenmo = MonsterData.Types.challenge_shenmo_r9
    local luqingyun = MonsterData.Types.challenge_luqingyun_r9
    local yunshang = MonsterData.Types.challenge_yunshang_r9
    local liwuji = MonsterData.Types.challenge_liwuji_r9

    assertEqual(shenmo.bloodMark.maxStacks, nil)
    assertNear(shenmo.bloodMark.damagePercent, 0.03)
    assertEqual(luqingyun.barrierZone.maxCount, 5)
    assertTrue(yunshang.jadeShield.dmgReduction <= 0.55)
    assertTrue(yunshang.jadeShield.reflectPercent <= 0.25)
    assertNear(liwuji.sealMark.clearCooldown, 0.25)
    assertEqual(liwuji.sealMark.clearDirectHitsOnly, true)
end)

test("R9 复杂度受控且末阶段压力不低于第五、六章稳定圣级 BOSS 基线", function()
    local stableBossIds = {
        "ch5_sword_zhu",
        "ch5_sword_xian",
        "ch5_sword_lu",
        "ch5_sword_jue",
        "ch6_gua_master",
        "ch6_mojun_shixuan",
    }

    for _, typeId in ipairs(stableBossIds) do
        local boss = MonsterData.Types[typeId]
        assertTrue(boss ~= nil, "missing stable boss " .. typeId)
        assertTrue(#boss.skills >= 4, typeId .. " stable baseline has fewer than four skills")
        assertTrue(boss.phases == 3, typeId .. " stable baseline is not three phases")
    end

    for _, expected in pairs(R9_BOSSES) do
        local boss = MonsterData.Types[expected.id]
        assertTrue(#boss.skills <= 3, expected.id .. " exceeds three P1 skills")
        assertTrue(#boss.phaseConfig <= 2, expected.id .. " exceeds two phase transitions")
        assertNear(boss.fieldDamagePercent, expected.fieldDamagePercent)

        local phase2 = boss.phaseConfig[1]
        local phase3 = boss.phaseConfig[2]
        assertEqual(phase2.atkMult, nil)
        assertNear(phase2.speedMult, 1.4)
        assertNear(phase2.intervalMult, 0.6)
        assertNear(phase3.atkMult, 2.5)
        assertNear(phase3.speedMult, 1.6)
        assertNear(phase3.intervalMult, 0.35)
        assertNear(boss.berserkBuff.atkSpeedMult, 1.4)
        assertNear(boss.berserkBuff.speedMult, 1.4)
        assertNear(boss.berserkBuff.cdrMult, 0.6)
    end

    local guaPhase3 = MonsterData.Types.ch6_gua_master.phaseConfig[2]
    local stablePressure = guaPhase3.atkMult / guaPhase3.intervalMult
    local r9Pressure = MonsterData.Types.challenge_shenmo_r9.phaseConfig[2].atkMult
        / MonsterData.Types.challenge_shenmo_r9.phaseConfig[2].intervalMult
    assertTrue(r9Pressure >= stablePressure,
        "R9 phase 3 raw attack pressure must not be lower than the same-level Ch6 baseline")
end)

test("R9 场地技能不再声明未实现的移动安全区", function()
    assertEqual(MonsterData.Skills.shenmo_blood_flood.safeZoneMoving, nil)
    assertEqual(MonsterData.Skills.yunshang_jade_storm.safeZoneMoving, nil)
end)

test("四件阵营法宝均支持 T11 图标与售价", function()
    for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
        local template = EquipmentData.FabaoTemplates[faction.fabaoTplId]
        assertTrue(template ~= nil, "missing template for " .. factionKey)
        assertTrue(template.iconByTier[11] ~= nil, "missing T11 icon for " .. factionKey)
        assertEqual(template.sellPriceByTier[11], 1500)
    end
end)

test("实际生成的 R9 法宝不会低于蓝或高于红", function()
    math.randomseed(20260714)
    local minQuality, maxQuality = ChallengeConfig.GetRepeatQualityRange(9)
    local minOrder = GameConfig.QUALITY_ORDER[minQuality]
    local maxOrder = GameConfig.QUALITY_ORDER[maxQuality]

    for _, faction in pairs(ChallengeConfig.FACTIONS) do
        for _ = 1, 40 do
            local quality = LootSystem.RollQuality(minQuality, maxQuality)
            local item = LootSystem.CreateFabaoEquipment(faction.fabaoTplId, 11, quality)
            assertTrue(item ~= nil)
            assertEqual(item.tier, 11)
            local order = GameConfig.QUALITY_ORDER[item.quality]
            assertTrue(order >= minOrder and order <= maxOrder,
                "quality out of range: " .. tostring(item.quality))
        end
    end
end)

test("旧 v4 存档保留 R1-R8 且新增 R9 默认为锁定未完成", function()
    local CS = {
        progress = {},
        treasure_challenge = {},
    }
    local data = {
        version = 4,
        treasure_challenge = {},
    }

    for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
        CS.treasure_challenge[factionKey] = { [faction.treasureKey] = {} }
        data.treasure_challenge[factionKey] = { [faction.treasureKey] = {} }
        for level = 1, 9 do
            CS.treasure_challenge[factionKey][faction.treasureKey][tostring(level)] = {
                unlocked = false,
                completed = false,
            }
        end
        for level = 1, 8 do
            data.treasure_challenge[factionKey][faction.treasureKey][tostring(level)] = {
                unlocked = true,
                completed = level <= 7,
            }
        end
    end

    persistence.Deserialize(CS, data)

    for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
        local levels = CS.treasure_challenge[factionKey][faction.treasureKey]
        for level = 1, 8 do
            assertTrue(levels[tostring(level)].unlocked)
            assertEqual(levels[tostring(level)].completed, level <= 7)
        end
        assertEqual(levels["9"].unlocked, false)
        assertEqual(levels["9"].completed, false)
    end
end)

test("Monster.New 已接通玉甲与 R9 场地伤害覆盖字段", function()
    local data = MonsterData.Types.challenge_yunshang_r9
    local monster = Monster.New(data, 5, 5)
    assertTrue(monster.jadeShield == data.jadeShield)
    assertNear(monster.fieldDamagePercent, 0.50)
end)

test("玉甲实际减伤且只反射玩家本体伤害", function()
    local savedPlayer = GameState.player
    local savedMonsters = GameState.monsters
    local reflectedDamage = 0
    local player = {
        alive = true,
        x = 0,
        y = 0,
        sealMarkStacks = 0,
        TakeDamage = function(_, damage)
            reflectedDamage = reflectedDamage + damage
            return damage
        end,
    }
    local pet = { alive = true }
    GameState.player = player
    GameState.monsters = {}
    CombatSystem.InitBossMechanicsListeners()

    local monster = Monster.New(MonsterData.Types.challenge_yunshang_r9, 5, 5)
    monster.jadeShieldActive = true
    monster.jadeShieldDmgReduction = 0.55
    monster.jadeShieldReflectPercent = 0.25

    assertEqual(monster:TakeDamage(100, pet), 45)
    assertEqual(reflectedDamage, 0)
    assertEqual(monster:TakeDamage(100, player), 45)
    assertEqual(reflectedDamage, 25)
    assertEqual(monster:TakeDamage(100, player, { damageTag = "dot" }), 45)
    assertEqual(reflectedDamage, 25)

    GameState.player = savedPlayer
    GameState.monsters = savedMonsters
end)

test("封魔印只被玩家本体非 DOT 命中按冷却削减", function()
    local savedPlayer = GameState.player
    local player = {
        alive = true,
        sealMarkStacks = 4,
        sealMarkTickTimer = 0,
        sealMarkClearCooldown = 0,
    }
    local pet = { alive = true }
    local monster = {
        sealMark = {
            clearPerHit = 1,
            clearCooldown = 0.25,
            clearDirectHitsOnly = true,
        },
    }
    GameState.player = player
    CombatSystem.InitBossMechanicsListeners()

    EventBus.Emit("monster_hurt", monster, 100, pet, nil)
    assertEqual(player.sealMarkStacks, 4)

    EventBus.Emit("monster_hurt", monster, 100, player, { damageTag = "dot" })
    assertEqual(player.sealMarkStacks, 4)

    EventBus.Emit("monster_hurt", monster, 100, player, nil)
    assertEqual(player.sealMarkStacks, 3)
    assertNear(player.sealMarkClearCooldown, 0.25)

    EventBus.Emit("monster_hurt", monster, 100, player, nil)
    assertEqual(player.sealMarkStacks, 3)

    player.sealMarkClearCooldown = 0
    EventBus.Emit("monster_hurt", monster, 100, player, nil)
    assertEqual(player.sealMarkStacks, 2)

    GameState.player = savedPlayer
end)

test("线上 R8 封魔印仍允许宠物与 DOT 命中按旧规则清层", function()
    local savedPlayer = GameState.player
    local player = {
        alive = true,
        sealMarkStacks = 4,
        sealMarkTickTimer = 0,
        sealMarkClearCooldown = 0,
    }
    local pet = { alive = true }
    local monster = {
        sealMark = MonsterData.Types.challenge_liwuji_r8.sealMark,
    }
    GameState.player = player
    CombatSystem.InitBossMechanicsListeners()

    assertEqual(monster.sealMark.clearDirectHitsOnly, nil)
    EventBus.Emit("monster_hurt", monster, 100, pet, nil)
    assertEqual(player.sealMarkStacks, 3)
    EventBus.Emit("monster_hurt", monster, 100, player, { damageTag = "dot" })
    assertEqual(player.sealMarkStacks, 2)

    GameState.player = savedPlayer
end)

test("胜利奖励选择期间会立即停止残留伤害与控制", function()
    local savedPlayer = GameState.player
    local savedMonsters = GameState.monsters
    local player = {
        alive = true,
        bloodMarkStacks = 3,
        bloodMarkDmgPercent = 0.03,
        bloodMarkTickTimer = 0.9,
        sealMarkStacks = 5,
        sealMarkTickTimer = 1.4,
        sealMarkConfig = {},
        sealMarkClearCooldown = 0.2,
        poisoned = true,
        poisonTimer = 3,
        poisonDamage = 100,
        poisonTickTimer = 0.9,
        poisonSource = {},
        stunTimer = 1,
        slowTimer = 2,
        slowMovePercent = 0.4,
        slowAtkPercent = 0.4,
        SetMoveDirection = function(self, dx, dy)
            self.dx = dx
            self.dy = dy
        end,
    }
    GameState.player = player
    GameState.monsters = {}
    CombatSystem.activeZones = { { x = 1, y = 1 } }
    CombatSystem.barrierZones = { { x = 1, y = 1 } }

    rewards.StopVictoryCombat()

    assertEqual(#CombatSystem.activeZones, 0)
    assertEqual(#CombatSystem.barrierZones, 0)
    assertEqual(player.bloodMarkStacks, 0)
    assertEqual(player.sealMarkStacks, 0)
    assertEqual(player.poisoned, false)
    assertEqual(player.stunTimer, 0)
    assertEqual(player.slowTimer, 0)
    assertEqual(player.dx, 0)
    assertEqual(player.dy, 0)

    GameState.player = savedPlayer
    GameState.monsters = savedMonsters
end)

test("新版法宝技能固定使用单一效果，不随 T10/T11 成长", function()
    local item = LootSystem.CreateFabaoEquipment("fabao_xuehaitu", 11, "red")
    local fakeIS = {
        GetManager = function()
            return {
                GetEquipmentItem = function(_, slot)
                    return slot == "exclusive" and item or nil
                end,
            }
        end,
    }

    assertTrue(item ~= nil)
    assertEqual(type(item.id), "number")
    assertEqual(item.equipId, "fabao_xuehaitu")
    assertEqual(Consumables.GetExclusiveSkillTier(fakeIS), 3)
end)

test("封魔大阵按 5x5 方形区域判定", function()
    assertTrue(CombatSystem.IsPointInZone ~= nil)

    local zone = {
        x = 0,
        y = 0,
        shape = "square",
        halfSize = 2.5,
        range = 2.5,
    }
    assertTrue(CombatSystem.IsPointInZone(2.4, 2.4, zone))
    assertTrue(not CombatSystem.IsPointInZone(2.6, 0, zone))
end)

print("\n========================================")
print(string.format("  RESULT: %d passed, %d failed, %d total", passed, failed, total))
print("========================================\n")

return { passed = passed, failed = failed, total = total }
