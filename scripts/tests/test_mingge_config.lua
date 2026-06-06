-- ============================================================================
-- test_mingge_config.lua — 验证 37 个 BOSS 命格掉落映射完整性
-- ============================================================================
-- 测试目标：确保所有 MonsterTypes 中的 BOSS typeId 都能通过
-- BOSS_TO_MINGGE 或直接匹配找到 SOURCES 条目

local MinggeData = require("config.MinggeData")

local T = {}
T.name = "mingge_config"
T.description = "验证37个BOSS命格来源映射完整性"

function T.run()
    local passed = 0
    local failed = 0
    local errors = {}

    -- 1. 所有 MonsterTypes 实际 typeId（运行时 monster.typeId 的值）
    --    与 SOURCES 或 BOSS_TO_MINGGE 的对应关系
    local ALL_BOSS_TYPEIDS = {
        -- Ch3 沙漠妖王（yao_king_N 命名）
        { typeId = "yao_king_1",  expectedSource = "sha_wanli" },
        { typeId = "yao_king_2",  expectedSource = "shen_king" },
        { typeId = "yao_king_3",  expectedSource = "lieyan_lion" },
        { typeId = "yao_king_4",  expectedSource = "shegu_king" },
        { typeId = "yao_king_5",  expectedSource = "chijia_king" },
        { typeId = "yao_king_6",  expectedSource = "canglang_king" },
        { typeId = "yao_king_7",  expectedSource = "yanchan_king" },
        { typeId = "yao_king_8",  expectedSource = "kumu_king" },
        -- Ch3 流沙系列
        { typeId = "liusha_son_outer", expectedSource = "liusha_son" },
        { typeId = "liusha_son_mid",   expectedSource = "liusha_son" },
        { typeId = "liusha_mother",    expectedSource = "liusha_mother" },
        -- Ch4 八卦 + 阵灵 + 四龙
        { typeId = "kan_boss",     expectedSource = "kan_boss" },
        { typeId = "gen_boss",     expectedSource = "gen_boss" },
        { typeId = "zhen_boss",    expectedSource = "zhen_boss" },
        { typeId = "xun_boss",     expectedSource = "xun_boss" },
        { typeId = "li_boss",      expectedSource = "li_boss" },
        { typeId = "kun_boss",     expectedSource = "kun_boss" },
        { typeId = "dui_boss",     expectedSource = "dui_boss" },
        { typeId = "qian_boss",    expectedSource = "qian_boss" },
        { typeId = "yin_spirit",   expectedSource = "yin_spirit" },
        { typeId = "yang_spirit",  expectedSource = "yang_spirit" },
        { typeId = "dragon_ice",   expectedSource = "dragon_ice" },
        { typeId = "dragon_abyss", expectedSource = "dragon_abyss" },
        { typeId = "dragon_fire",  expectedSource = "dragon_fire" },
        { typeId = "dragon_sand",  expectedSource = "dragon_sand" },
        -- Ch5 BOSS（ch5_ 前缀）
        { typeId = "ch5_pei_qianyue",     expectedSource = "pei_qianyue" },
        { typeId = "ch5_frost_luan",      expectedSource = "frost_luan" },
        { typeId = "ch5_han_bailian",     expectedSource = "han_bailian" },
        { typeId = "ch5_shi_guanlan",     expectedSource = "shi_guanlan" },
        { typeId = "ch5_ning_qiwu",       expectedSource = "ning_qiwu" },
        { typeId = "ch5_wen_suzhang",     expectedSource = "wen_suzhang" },
        { typeId = "ch5_sword_zhu",       expectedSource = "sword_zhu" },
        { typeId = "ch5_sword_xian",      expectedSource = "sword_xian" },
        { typeId = "ch5_sword_lu",        expectedSource = "sword_lu" },
        { typeId = "ch5_sword_jue",       expectedSource = "sword_jue" },
        { typeId = "ch5_blood_general",   expectedSource = "blood_general" },
        { typeId = "ch5_marshal_shugu",   expectedSource = "marshal_shugu" },
        { typeId = "ch5_marshal_liesoul", expectedSource = "marshal_liesoul" },
    }

    -- 2. 检查每个 typeId 能否解析到正确的 SOURCES
    for _, entry in ipairs(ALL_BOSS_TYPEIDS) do
        local bossId = MinggeData.BOSS_TO_MINGGE[entry.typeId] or entry.typeId
        local source = MinggeData.SOURCES[bossId]

        if not source then
            failed = failed + 1
            table.insert(errors, string.format(
                "FAIL: typeId=%s → bossId=%s → SOURCES[%s] = nil",
                entry.typeId, bossId, bossId))
        elseif bossId ~= entry.expectedSource then
            failed = failed + 1
            table.insert(errors, string.format(
                "FAIL: typeId=%s → bossId=%s, expected=%s",
                entry.typeId, bossId, entry.expectedSource))
        else
            passed = passed + 1
        end
    end

    -- 3. 反向检查：SOURCES 中所有条目是否都可达
    local reachable = {}
    for _, entry in ipairs(ALL_BOSS_TYPEIDS) do
        local bossId = MinggeData.BOSS_TO_MINGGE[entry.typeId] or entry.typeId
        reachable[bossId] = true
    end

    for bossId, src in pairs(MinggeData.SOURCES) do
        if not reachable[bossId] then
            failed = failed + 1
            table.insert(errors, string.format(
                "FAIL: SOURCES[%s] (%s) 无可达 typeId 路径",
                bossId, src.name))
        end
    end

    -- 4. 报告
    print(string.format("[MinggeConfig] 测试完成: %d passed, %d failed (共 %d typeIds + %d SOURCES 反向检查)",
        passed, failed, #ALL_BOSS_TYPEIDS, 37))

    for _, e in ipairs(errors) do
        print("  " .. e)
    end

    return failed == 0
end

return T
