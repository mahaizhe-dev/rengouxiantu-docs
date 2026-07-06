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
        id            = "save_payload_codec",
        group         = "save",
        path          = "scripts/tests/test_save_payload_codec.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "non_blocking",
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
        id            = "trial_tower",
        group         = "system",
        path          = "scripts/tests/test_trial_tower.lua",
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
        id            = "ch6_map_contract",
        group         = "map",
        path          = "scripts/tests/test_ch6_map_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "ch2_map_contract",
        group         = "map",
        path          = "scripts/tests/test_ch2_map_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "daily_ch6_contract",
        group         = "daily",
        path          = "scripts/tests/test_daily_ch6_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "triggered_battle",
        group         = "triggered_battle",
        path          = "scripts/tests/test_triggered_battle.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "wubao_treasure_contract",
        group         = "config",
        path          = "scripts/tests/test_wubao_treasure_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "wubao_treasure_handler_flow",
        group         = "config",
        path          = "scripts/tests/test_wubao_treasure_handler_flow.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "ch1_ch2_drop_contract",
        group         = "config",
        path          = "scripts/tests/test_ch1_ch2_drop_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "ch1_quest_contract",
        group         = "quest",
        path          = "scripts/tests/test_ch1_quest_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "treasure_runner_contract",
        group         = "daily",
        path          = "scripts/tests/test_treasure_runner_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "ch6_special_equipment",
        group         = "config",
        path          = "scripts/tests/test_ch6_special_equipment.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "qinglian_body_system",
        group         = "qinglian_body",
        path          = "scripts/tests/test_qinglian_body_system.lua",
        mode          = "skip",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "lupa_only: uses InventorySystem.SetManager; forbidden in real engine TestRegistry by rules.md",
    },

    {
        id            = "combat_yuanying_skills",
        group         = "combat",
        path          = "scripts/tests/test_combat_yuanying_skills.lua",
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

    {
        id            = "bm_warehouse_consistency",
        group         = "system",
        path          = "scripts/tests/test_bm_warehouse_consistency.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "image_item_slot_icon_contract",
        group         = "ui",
        path          = "scripts/tests/test_image_item_slot_icon_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "bm_s3_sell_guard",
        group         = "system",
        path          = "scripts/tests/test_bm_s3_sell_guard.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "bm_s3_handle_sell_integration",
        group         = "system",
        path          = "scripts/tests/test_bm_s3_handle_sell_integration.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- BM-S4A: 黑市交易保护锁
    ---------------------------------------------------------------------------

    {
        id            = "bm_s4a_trade_lock",
        group         = "system",
        path          = "scripts/tests/test_bm_s4a_trade_lock.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- BM-S4B: 解锁闭环与整类禁售
    ---------------------------------------------------------------------------

    {
        id            = "bm_s4b_unlock_loop_and_ban",
        group         = "system",
        path          = "scripts/tests/test_bm_s4b_unlock_loop_and_ban.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "non_blocking",
        skip_reason   = "BM-NORESELL(P1) 降级：'整类禁售'语义已退役。仍运行以守护两项过渡兼容保证 —— SerializeItemFull 剥离 bmLock* 不落盘、HasAnyLockedConsumable 对残留临时锁的纯逻辑；不再阻断门禁",
    },

    ---------------------------------------------------------------------------
    -- BM-S4C1: 卖出确认弹窗按钮缺失修复
    ---------------------------------------------------------------------------

    {
        id            = "bm_s4c1_confirm_dialog_buttons",
        group         = "system",
        path          = "scripts/tests/test_bm_s4c1_confirm_dialog_buttons.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- BM-S4D: 黑市状态边界与自动回收过天收口
    ---------------------------------------------------------------------------

    {
        id            = "bm_s4d_syncstate_after_save",
        group         = "system",
        path          = "scripts/tests/test_bm_s4d_syncstate_after_save.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "bm_s4d_recycle_day_rollover",
        group         = "system",
        path          = "scripts/tests/test_bm_recycle_day_rollover.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- BM-S4E: 黑市可售状态一致性与自动回收集成收口
    ---------------------------------------------------------------------------

    {
        id            = "bm_s4e_sell_block_consistency",
        group         = "system",
        path          = "scripts/tests/test_bm_s4e_sell_block_consistency.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "bm_s4e_recycle_tick_flow",
        group         = "system",
        path          = "scripts/tests/test_bm_s4e_recycle_tick_flow.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- R3: 服务壳契约测试
    ---------------------------------------------------------------------------

    {
        id            = "r3_service_shell_contract",
        group         = "save",
        path          = "scripts/tests/test_r3_service_shell_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- N1: 网络波动容错与强提示
    ---------------------------------------------------------------------------

    {
        id            = "network_status",
        group         = "network",
        path          = "scripts/tests/test_network_status.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- PRE-C5-A1: 第五章前三线专项合并验证
    ---------------------------------------------------------------------------

    {
        id            = "pre_c5a1_three_lines",
        group         = "system",
        path          = "scripts/tests/test_pre_c5a1_three_lines.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- C5: 解封仙剑配置正确性（圣性/灵性互斥、标签、fromBag）
    ---------------------------------------------------------------------------

    {
        id            = "jiefeng_sword_config",
        group         = "config",
        path          = "scripts/tests/test_jiefeng_sword_config.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- FORGE-CONTRACT: 打造系统静态合同（配方/模板/白名单/GM/Registry 安全）
    ---------------------------------------------------------------------------

    {
        id            = "forge_contract",
        group         = "config",
        path          = "scripts/tests/test_forge_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- CH1-FORGE-PIPELINE: 虎王试炼炉真实 Check/Execute 流水线
    ---------------------------------------------------------------------------

    {
        id            = "ch1_tiger_trial_forge_pipeline",
        group         = "config",
        path          = "scripts/tests/test_ch1_tiger_trial_forge_pipeline.lua",
        mode          = "skip",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "lupa_only: uses InventorySystem.SetManager; forbidden in real engine TestRegistry by rules.md",
    },

    ---------------------------------------------------------------------------
    -- CH2-WUBAO-FORGE-PIPELINE: 乌堡锻造台真实 Check/Execute 流水线
    ---------------------------------------------------------------------------

    {
        id            = "ch2_wubao_forge_pipeline",
        group         = "config",
        path          = "scripts/tests/test_ch2_wubao_forge_pipeline.lua",
        mode          = "skip",
        enabled       = false,
        gate          = "non_blocking",
        skip_reason   = "lupa_only: uses InventorySystem.SetManager; forbidden in real engine TestRegistry by rules.md",
    },

    ---------------------------------------------------------------------------
    -- BM-FIX-01: 黑市商品级可售逻辑纠偏
    ---------------------------------------------------------------------------

    {
        id            = "bm_fix01_card_sell_split",
        group         = "system",
        path          = "scripts/tests/test_bm_fix01_card_sell_split.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- BM-NORESELL: 黑市买入永久禁回售（阶段1 线A）
    -- 纯函数测试，本地构造 backpack，不碰全局单例；全量遍历 ITEM_IDS
    ---------------------------------------------------------------------------

    {
        id            = "bm_noresell",
        group         = "system",
        path          = "scripts/tests/test_bm_noresell.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- BM-NORESELL(P2): 消耗优先扣 bmNoResell + 混合消耗(Q4)
    -- mock IS facade + 本地 slots，不碰全局单例；隔离 EventBus/SyncState
    ---------------------------------------------------------------------------

    {
        id            = "bm_noresell_consume",
        group         = "system",
        path          = "scripts/tests/test_bm_noresell_consume.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- BM-NORESELL: 仓库存取保留 bmNoResell 端到端回归（买入→存仓→重登→取出）
    -- 隔离 mock GameState/InventorySystem，跑真实 WarehouseSystem+SaveSerializer
    ---------------------------------------------------------------------------

    {
        id            = "save_phase3_smoke",
        group         = "system",
        path          = "scripts/tests/test_save_phase3_smoke.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "save_phase1_smoke",
        group         = "save",
        path          = "scripts/tests/test_save_phase1_smoke.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "bm_noresell_warehouse",
        group         = "system",
        path          = "scripts/tests/test_bm_noresell_warehouse.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },
    {
        id            = "net_diag_client",
        group         = "system",
        path          = "scripts/tests/test_net_diag_client.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },
    {
        id            = "save_exit_callback_reasons",
        group         = "save",
        path          = "scripts/tests/test_save_exit_callback_reasons.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },
    {
        id            = "disconnect_lock_cleanup",
        group         = "system",
        path          = "scripts/tests/test_disconnect_lock_cleanup.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },
    {
        id            = "save_request_immediate_status",
        group         = "save",
        path          = "scripts/tests/test_save_request_immediate_status.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },
    {
        id            = "bm_warehouse_sell_sync_gate",
        group         = "system",
        path          = "scripts/tests/test_bm_warehouse_sell_sync_gate.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },
    {
        id            = "bm_warehouse_close_flush",
        group         = "system",
        path          = "scripts/tests/test_bm_warehouse_close_flush.lua",
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
        mode          = "non_blocking",
        entry         = "tests.test_event_system",
        enabled       = true,
        gate          = "non_blocking",
        note          = "GM命令'活动自测'触发; 依赖: config.EventConfig, systems.EventSystem, systems.LootSystem, systems.MilestoneLogic; 覆盖里程碑协议一致性/计数/基线迁移/领取(T17-T23)",
    },

    ---------------------------------------------------------------------------
    -- 第五章神器：诛仙阵图（ArtifactSystem_ch5）完整测试
    -- 覆盖：激活/消耗/账号属性/仙途录同步/挑战/BOSS战/神器技能/存档
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    -- T10 制式套装掉落链路（配置验证 + 可选引擎链路）
    -- TEST 1-5: 纯配置层（MonsterTypes_ch5/TemperUI/SaveSerializer），blocking
    -- TEST 6-7: GenerateSetEquipment 生成验证，pcall 保护，非引擎环境自动 SKIP
    ---------------------------------------------------------------------------

    {
        id            = "t10_set_drop",
        group         = "system",
        path          = "scripts/tests/test_t10_set_drop.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- R8 声望 + T10 法宝 + 额外掉落
    ---------------------------------------------------------------------------

    {
        id            = "challenge_r8_extradrop",
        group         = "system",
        path          = "scripts/tests/test_challenge_r8_extradrop.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- INFRA: 文件长度预算门禁（bigfile-refactor §3）
    ---------------------------------------------------------------------------

    {
        id            = "file_budget",
        group         = "infra",
        path          = "scripts/tests/test_file_budget.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- AdminPenalty: 账号处罚控制
    ---------------------------------------------------------------------------

    {
        id            = "admin_penalty_control",
        group         = "system",
        path          = "scripts/tests/test_admin_penalty_control.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "admin_penalty_wiring",
        group         = "system",
        path          = "scripts/tests/test_admin_penalty_wiring.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- BM-RECYCLE-WINDOW: 黑市自动回收窗口调度
    ---------------------------------------------------------------------------

    {
        id            = "recycle_window_schedule",
        group         = "system",
        path          = "scripts/tests/test_recycle_window_schedule.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- ALCHEMY: 炼丹系统存档往返（Save Roundtrip）
    ---------------------------------------------------------------------------

    {
        id            = "alchemy_save_roundtrip",
        group         = "save",
        path          = "scripts/tests/test_alchemy_save_roundtrip.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- ALCHEMY: 炼丹系统状态同步（State Sync）
    ---------------------------------------------------------------------------

    {
        id            = "alchemy_state_sync",
        group         = "save",
        path          = "scripts/tests/test_alchemy_state_sync.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- ALCHEMY: 影神丹炼制契约
    ---------------------------------------------------------------------------

    {
        id            = "alchemy_shadow_god_craft",
        group         = "save",
        path          = "scripts/tests/test_alchemy_shadow_god_craft.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- MINGGE: 五行命格配置完整性
    ---------------------------------------------------------------------------

    {
        id            = "mingge_config",
        group         = "config",
        path          = "scripts/tests/test_mingge_config.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- MINGGE: 五行命格属性范围与粒度
    ---------------------------------------------------------------------------

    {
        id            = "mingge_ranges",
        group         = "config",
        path          = "scripts/tests/test_mingge_ranges.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- MINGGE: 五行命格掉落合同与定价
    ---------------------------------------------------------------------------

    {
        id            = "mingge_drop_contract",
        group         = "config",
        path          = "scripts/tests/test_mingge_drop_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "mingge_ch6_contract",
        group         = "config",
        path          = "scripts/tests/test_mingge_ch6_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    {
        id            = "equip_shop_mingge_contract",
        group         = "config",
        path          = "scripts/tests/test_equip_shop_mingge_contract.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "blocking",
        skip_reason   = nil,
    },

    ---------------------------------------------------------------------------
    -- 仙阶/渡劫/仙体系统测试
    ---------------------------------------------------------------------------

    {
        id            = "ascension_system",
        group         = "system",
        path          = "scripts/tests/test_ascension_system.lua",
        mode          = "run_file",
        enabled       = true,
        gate          = "non_blocking",
        skip_reason   = nil,
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
