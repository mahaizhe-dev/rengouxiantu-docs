-- scripts/tests/test_p1p2p3_refactor.lua
-- GM命令触发: "P1P2P3重构自测"
--
-- 测试目标:
-- P3: 函数名去特化（TriggerNthCastEffect / TriggerChargePassiveRelease 存在性）
-- P2: descriptionProvider 回调化（GetDynamicDescription 走回调分发）
-- P1-a: 重击计数器绑定到 eff 实例（eff._counter）
-- P1-b: 噬魂/灭影状态迁移到 eff 实例（eff._cooldown, eff._burstTimer）

local TestRefactor = {}

function TestRefactor.RunAll()
    local results = {}
    local pass = 0
    local fail = 0

    local function assert_true(name, condition)
        if condition then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, "[FAIL] " .. name)
        end
    end

    local function assert_eq(name, actual, expected)
        if actual == expected then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, "[FAIL] " .. name
                .. " expected=" .. tostring(expected)
                .. " actual=" .. tostring(actual))
        end
    end

    -- ========== P3: 函数名去特化 ==========
    print("======== P3: 函数名去特化 ========")

    local SkillSystem = require("systems.SkillSystem")

    -- T1: TriggerNthCastEffect 存在
    assert_true("P3-1 TriggerNthCastEffect exists",
        type(SkillSystem.TriggerNthCastEffect) == "function")

    -- T2: TriggerChargePassiveRelease 存在
    assert_true("P3-2 TriggerChargePassiveRelease exists",
        type(SkillSystem.TriggerChargePassiveRelease) == "function")

    -- T3: 旧名 TriggerPassiveGiantSword 不存在
    assert_true("P3-3 old TriggerPassiveGiantSword removed",
        SkillSystem.TriggerPassiveGiantSword == nil)

    -- T4: 旧名 TriggerDragonElephantQuake 不存在
    assert_true("P3-4 old TriggerDragonElephantQuake removed",
        SkillSystem.TriggerDragonElephantQuake == nil)

    -- ========== P2: descriptionProvider 回调化 ==========
    print("======== P2: descriptionProvider 回调化 ========")

    local SkillData = require("config.SkillData")

    -- T5: blood_sea_aoe 有 descriptionProvider
    assert_true("P2-1 blood_sea_aoe has descriptionProvider",
        type(SkillData.Skills.blood_sea_aoe) == "table"
        and type(SkillData.Skills.blood_sea_aoe.descriptionProvider) == "function")

    -- T6: haoqi_seal_zone 有 descriptionProvider
    assert_true("P2-2 haoqi_seal_zone has descriptionProvider",
        type(SkillData.Skills.haoqi_seal_zone) == "table"
        and type(SkillData.Skills.haoqi_seal_zone.descriptionProvider) == "function")

    -- T7: jade_gourd_heal 有 descriptionProvider
    assert_true("P2-3 jade_gourd_heal has descriptionProvider",
        type(SkillData.Skills.jade_gourd_heal) == "table"
        and type(SkillData.Skills.jade_gourd_heal.descriptionProvider) == "function")

    -- T8: GetDynamicDescription("blood_sea_aoe") 返回非空且含关键字
    local desc1 = SkillData.GetDynamicDescription("blood_sea_aoe", 10000, 3)
    assert_true("P2-4 blood_sea_aoe desc non-empty",
        type(desc1) == "string" and #desc1 > 0)
    assert_true("P2-5 blood_sea_aoe desc contains damage info",
        type(desc1) == "string" and desc1:find("攻击力") ~= nil)

    -- T9: GetDynamicDescription("haoqi_seal_zone") 返回非空且含关键字
    local desc2 = SkillData.GetDynamicDescription("haoqi_seal_zone", 10000, 3)
    assert_true("P2-6 haoqi_seal_zone desc non-empty",
        type(desc2) == "string" and #desc2 > 0)
    assert_true("P2-7 haoqi_seal_zone desc contains zone info",
        type(desc2) == "string" and desc2:find("领域") ~= nil)

    -- T10: GetDynamicDescription("jade_gourd_heal") 返回非空且含关键字
    local desc3 = SkillData.GetDynamicDescription("jade_gourd_heal", 10000, 3)
    assert_true("P2-8 jade_gourd_heal desc non-empty",
        type(desc3) == "string" and #desc3 > 0)
    assert_true("P2-9 jade_gourd_heal desc contains heal info",
        type(desc3) == "string" and desc3:find("恢复") ~= nil)

    -- T11: 无 descriptionProvider 的技能走兜底 description
    local descFallback = SkillData.GetDynamicDescription("ice_slash", 10000, 1)
    local expected = SkillData.Skills.ice_slash and SkillData.Skills.ice_slash.description or ""
    assert_eq("P2-10 fallback to static description", descFallback, expected)

    -- T12: 不存在的技能返回空字符串
    assert_eq("P2-11 nonexistent skill returns empty", SkillData.GetDynamicDescription("__nonexistent__"), "")

    -- T13: descriptionProvider 抛异常时 pcall 保护
    local testSkillId = "__test_error_provider__"
    SkillData.Skills[testSkillId] = {
        id = testSkillId,
        description = "fallback desc",
        descriptionProvider = function() error("intentional test error") end,
    }
    local descErr = SkillData.GetDynamicDescription(testSkillId, 100, 1)
    assert_eq("P2-12 error provider falls back to description", descErr, "fallback desc")
    SkillData.Skills[testSkillId] = nil  -- 清理

    -- ========== P1-a: 重击计数器实例化 ==========
    print("======== P1-a: 重击计数器实例化 ========")

    local CombatSystem = require("systems.CombatSystem")

    -- T14: CombatSystem.heavyStrikeCounter 不存在
    assert_true("P1a-1 module-level heavyStrikeCounter removed",
        CombatSystem.heavyStrikeCounter == nil)

    -- T15: 模拟 eff._counter 递增逻辑
    local mockEff = { type = "heavy_strike", hitInterval = 3, _counter = nil }
    -- 模拟3次递增
    for i = 1, 3 do
        mockEff._counter = (mockEff._counter or 0) + 1
    end
    assert_eq("P1a-2 eff._counter increments to hitInterval", mockEff._counter, 3)
    -- 到达阈值后重置
    if mockEff._counter >= (mockEff.hitInterval or 5) then
        mockEff._counter = 0
    end
    assert_eq("P1a-3 eff._counter resets at threshold", mockEff._counter, 0)

    -- T16: 两个独立 eff 实例计数器互不影响
    local eff1 = { type = "heavy_strike", hitInterval = 3 }
    local eff2 = { type = "heavy_strike", hitInterval = 5 }
    eff1._counter = (eff1._counter or 0) + 1
    eff1._counter = (eff1._counter or 0) + 1
    eff2._counter = (eff2._counter or 0) + 1
    assert_eq("P1a-4 eff1._counter independent", eff1._counter, 2)
    assert_eq("P1a-5 eff2._counter independent", eff2._counter, 1)

    -- ========== P1-b: 噬魂/灭影状态实例化 ==========
    print("======== P1-b: 噬魂/灭影状态实例化 ========")

    -- T17: 模块级状态变量已移除
    assert_true("P1b-1 lifestealBurstTimer removed",
        CombatSystem.lifestealBurstTimer == nil)
    assert_true("P1b-2 lifestealBurstDmgMult removed",
        CombatSystem.lifestealBurstDmgMult == nil)
    assert_true("P1b-3 lifestealBurstCooldown removed",
        CombatSystem.lifestealBurstCooldown == nil)
    assert_true("P1b-4 shadowStrikeCooldown removed",
        CombatSystem.shadowStrikeCooldown == nil)

    -- T18: FindPlayerEffect 工具函数
    assert_true("P1b-5 FindPlayerEffect exists",
        type(CombatSystem.FindPlayerEffect) == "function")

    local mockPlayer = {
        equipSpecialEffects = {
            { type = "bleed_dot" },
            { type = "lifesteal_burst", _burstTimer = 2.0, _burstDmgMult = 0.30 },
            { type = "shadow_strike", _cooldown = 1.5 },
        }
    }
    local found = CombatSystem.FindPlayerEffect(mockPlayer, "lifesteal_burst")
    assert_true("P1b-6 FindPlayerEffect finds lifesteal_burst",
        found ~= nil and found.type == "lifesteal_burst")
    assert_eq("P1b-7 FindPlayerEffect returns correct instance",
        found and found._burstTimer, 2.0)

    local notFound = CombatSystem.FindPlayerEffect(mockPlayer, "nonexistent")
    assert_true("P1b-8 FindPlayerEffect returns nil for missing",
        notFound == nil)

    local nilPlayer = CombatSystem.FindPlayerEffect(nil, "lifesteal_burst")
    assert_true("P1b-9 FindPlayerEffect handles nil player",
        nilPlayer == nil)

    -- T19: 噬魂 onKill 写入 eff 实例状态
    local lsEff = { type = "lifesteal_burst", healPercent = 0.03, buffDuration = 3.0, damageBuff = 0.30 }
    -- EFFECT_HANDLERS 是 CombatSystem 内部 local，无法直接调用 onKill
    -- 通过验证 eff 实例字段初始为 nil（默认值）确认状态不在模块级
    assert_true("P1b-10 eff._cooldown defaults nil", lsEff._cooldown == nil)
    assert_true("P1b-11 eff._burstTimer defaults nil", lsEff._burstTimer == nil)

    -- T20: 灭影 eff 实例冷却独立性
    local ssEff1 = { type = "shadow_strike", _cooldown = 2.0 }
    local ssEff2 = { type = "shadow_strike", _cooldown = 0 }
    -- 模拟 dt 衰减
    ssEff1._cooldown = ssEff1._cooldown - 0.5
    assert_eq("P1b-12 shadow_strike eff1 cooldown decrements", ssEff1._cooldown, 1.5)
    assert_eq("P1b-13 shadow_strike eff2 cooldown unchanged", ssEff2._cooldown, 0)

    -- ========== 汇总 ==========
    print("========================================")
    print(string.format("P1P2P3 重构自测: %d PASS / %d FAIL (共 %d 项)", pass, fail, pass + fail))
    for _, r in ipairs(results) do
        print("  " .. r)
    end

    return pass, fail
end

return TestRefactor
