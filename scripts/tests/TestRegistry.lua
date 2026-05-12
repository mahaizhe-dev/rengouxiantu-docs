-- ============================================================================
-- TestRegistry.lua — 测试注册表
--
-- P0-1:  统一测试入口与最小 CI 门禁
-- P0-1A: 测试门禁收口与运行环境固化
--
-- 维护所有测试的元数据，供 TestRunner 消费
--
-- mode:
--   "run_file"       — dofile 执行，文件须 return { passed, failed, total }
--   "require_runall"  — require 后调 M.RunAll()，须返回 pass, fail
--   "skip"           — 跳过，仅记录
--
-- gate（门禁分类，P0-1A 新增）:
--   "blocking"       — 阻断门禁：默认门禁命令只跑这些，必须全绿
--   "non_blocking"   — 非阻断：可显式执行，不影响门禁结果
--   "known_red"      — 已知问题：已知失败，隔离出门禁，需跟踪修复
-- ============================================================================

local TestRegistry = {}

TestRegistry.tests = {

    ---------------------------------------------------------------------------
    -- smoke: Runner 自身冒烟测试（最先运行）
    ---------------------------------------------------------------------------

    {
        id            = "runner_smoke",
        group         = "smoke",
        path          = "scripts/tests/test_runner_smoke.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- pure_lua: 可在无引擎环境运行
    ---------------------------------------------------------------------------

    {
        id            = "save_optimization",
        group         = "save",
        path          = "scripts/tests/test_save_optimization.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "prison_tower",
        group         = "system",
        path          = "scripts/tests/test_prison_tower.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "recycle_system",
        group         = "system",
        path          = "scripts/tests/test_recycle_system.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "feature_flags",
        group         = "config",
        path          = "scripts/tests/test_feature_flags.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "cloudstorage_network_semantics",
        group         = "save",
        path          = "scripts/tests/test_cloudstorage_network_semantics.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "save_dto_contract",
        group         = "save",
        path          = "scripts/tests/test_save_dto_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "migration_state_policy",
        group         = "save",
        path          = "scripts/tests/test_migration_state_policy.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "logger_smoke",
        group         = "infra",
        path          = "scripts/tests/test_logger_smoke.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "save_system_net_state_machine",
        group         = "save",
        path          = "scripts/tests/test_save_system_net_state_machine.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- engine_required: 依赖引擎运行时，第一版标记 skip
    ---------------------------------------------------------------------------

    {
        id            = "event_system",
        group         = "system",
        path          = "scripts/tests/test_event_system.lua",
        mode          = "skip",
        entry         = "tests.test_event_system",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: config.EventConfig, systems.EventSystem, systems.LootSystem",
    },

    {
        id            = "target_selector",
        group         = "combat",
        path          = "scripts/tests/test_target_selector.lua",
        mode          = "skip",
        entry         = "tests.test_target_selector",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: core.GameState, systems.combat.TargetSelector",
    },

    {
        id            = "pre_damage_hooks",
        group         = "combat",
        path          = "scripts/tests/test_pre_damage_hooks.lua",
        mode          = "skip",
        entry         = "tests.test_pre_damage_hooks",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: core.GameState (player.AddPreDamageHook)",
    },

    {
        id            = "buff_skill_callbacks",
        group         = "combat",
        path          = "scripts/tests/test_buff_skill_callbacks.lua",
        mode          = "skip",
        entry         = "tests.test_buff_skill_callbacks",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: config.SkillData",
    },

    {
        id            = "p1p2p3_refactor",
        group         = "regression",
        path          = "scripts/tests/test_p1p2p3_refactor.lua",
        mode          = "skip",
        entry         = "tests.test_p1p2p3_refactor",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: systems.SkillSystem, config.SkillData, systems.CombatSystem",
    },

    {
        id            = "challenge_fabao",
        group         = "system",
        path          = "scripts/tests/test_challenge_fabao.lua",
        mode          = "skip",
        entry         = "tests.test_challenge_fabao",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: config.GameConfig, config.EquipmentData, systems.ChallengeSystem",
    },

    {
        id            = "batch_consumable",
        group         = "system",
        path          = "scripts/tests/test_batch_consumable.lua",
        mode          = "skip",
        entry         = "tests.test_batch_consumable",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: config.GameConfig, core.GameState, systems.InventorySystem",
    },

    {
        id            = "dao_question",
        group         = "system",
        path          = "scripts/tests/test_dao_question.lua",
        mode          = "skip",
        entry         = "tests.test_dao_question",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: systems.DaoQuestionSystem",
    },

    {
        id            = "p0_regression",
        group         = "regression",
        path          = "scripts/tests/test_p0_regression.lua",
        mode          = "skip",
        entry         = "tests.test_p0_regression",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: systems.ArtifactSystem_tiandi, core.EventBus, network.RedeemHandler",
    },

    {
        id            = "p1_regression",
        group         = "regression",
        path          = "scripts/tests/test_p1_regression.lua",
        mode          = "skip",
        entry         = "tests.test_p1_regression",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: systems.InventorySystem, core.GameState, cache:GetFile",
    },

    {
        id            = "hit_resolver",
        group         = "combat",
        path          = "scripts/tests/test_hit_resolver.lua",
        mode          = "skip",
        entry         = "tests.test_hit_resolver",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: config.GameConfig, systems.combat.HitResolver",
    },

    {
        id            = "combo_runner",
        group         = "combat",
        path          = "scripts/tests/test_combo_runner.lua",
        mode          = "skip",
        entry         = "tests.test_combo_runner",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: core.GameState, systems.combat.ComboRunner, systems.CombatSystem",
    },

    {
        id            = "battle_pipeline_regression",
        group         = "regression",
        path          = "scripts/tests/test_battle_pipeline_regression.lua",
        mode          = "skip",
        entry         = "tests.test_battle_pipeline_regression",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: config.GameConfig, core.EventBus, systems.combat.BattleContracts",
    },

    {
        id            = "c4c5_server",
        group         = "system",
        path          = "scripts/tests/c4c5_server_test.lua",
        mode          = "skip",
        entry         = "tests.c4c5_server_test",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "engine_required: server-only, needs sCloud/serverCloud async runtime",
    },
}

--- 返回所有测试条目
function TestRegistry.GetAll()
    return TestRegistry.tests
end

--- 按 group 过滤
function TestRegistry.GetByGroup(group)
    local result = {}
    for _, t in ipairs(TestRegistry.tests) do
        if t.group == group then
            result[#result + 1] = t
        end
    end
    return result
end

--- 返回启用的测试
function TestRegistry.GetEnabled()
    local result = {}
    for _, t in ipairs(TestRegistry.tests) do
        if t.enabled then
            result[#result + 1] = t
        end
    end
    return result
end

--- 返回阻断门禁测试（gate == "blocking"）
function TestRegistry.GetBlocking()
    local result = {}
    for _, t in ipairs(TestRegistry.tests) do
        if t.gate == "blocking" then
            result[#result + 1] = t
        end
    end
    return result
end

--- 返回已知问题测试（gate == "known_red"）
function TestRegistry.GetKnownRed()
    local result = {}
    for _, t in ipairs(TestRegistry.tests) do
        if t.gate == "known_red" then
            result[#result + 1] = t
        end
    end
    return result
end

--- 按 gate 值过滤
function TestRegistry.GetByGate(gate)
    local result = {}
    for _, t in ipairs(TestRegistry.tests) do
        if t.gate == gate then
            result[#result + 1] = t
        end
    end
    return result
end

--- 返回所有已知 group 名称
function TestRegistry.GetGroups()
    local seen = {}
    local groups = {}
    for _, t in ipairs(TestRegistry.tests) do
        if not seen[t.group] then
            seen[t.group] = true
            groups[#groups + 1] = t.group
        end
    end
    return groups
end

return TestRegistry
