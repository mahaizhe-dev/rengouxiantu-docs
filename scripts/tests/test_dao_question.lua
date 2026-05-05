-- ============================================================================
-- tests/test_dao_question.lua - 天道问心系统自测脚本
-- GM命令触发: "问心自测"
--
-- 测试目标:
-- 1. ApplyAnswers 全 32 路径属性校验
-- 2. ValidateAnswers 脏数据拦截
-- 3. HasCompleted 判定
-- 4. ClearDaoFields 清零
-- 5. Session 事务流程 (BeginSession → RecordAnswer → CommitSession)
-- 6. AbortSession 零副作用
-- 7. 重置流程（灵韵扣费）
-- ============================================================================

local DaoQuestionSystem = require("systems.DaoQuestionSystem")

local TestDaoQuestion = {}

-- ============================================================================
-- 测试基础设施
-- ============================================================================

local pass_ = 0
local fail_ = 0
local results_ = {}

local function assert_eq(name, actual, expected)
    if actual == expected then
        pass_ = pass_ + 1
    else
        fail_ = fail_ + 1
        table.insert(results_, "[FAIL] " .. name
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual))
    end
end

local function assert_true(name, cond)
    if cond then
        pass_ = pass_ + 1
    else
        fail_ = fail_ + 1
        table.insert(results_, "[FAIL] " .. name .. " (expected true)")
    end
end

local function assert_false(name, cond)
    if not cond then
        pass_ = pass_ + 1
    else
        fail_ = fail_ + 1
        table.insert(results_, "[FAIL] " .. name .. " (expected false)")
    end
end

--- 创建一个用于测试的 mock player
local function MockPlayer(overrides)
    local p = {
        level = 10,
        exp = 0,
        hp = 200,
        maxHp = 200,
        atk = 30,
        def = 15,
        hpRegen = 2.0,
        gold = 10000,
        lingYun = 2000,
        realm = "qiRefining",
        x = 5.0,
        y = 5.0,
        classId = "monk",
        -- dao 字段
        daoWisdom = 0,
        daoFortune = 0,
        daoConstitution = 0,
        daoPhysique = 0,
        daoAtk = 0,
        daoMaxHp = 0,
        daoAnswers = {},
        -- 缓存标记
        _statsCacheFrame = -1,
    }
    if overrides then
        for k, v in pairs(overrides) do
            p[k] = v
        end
    end
    return p
end

-- ============================================================================
-- 测试 1: ApplyAnswers 全 32 路径属性校验
-- ============================================================================
-- QUESTIONS 定义:
-- Q1: A→daoWisdom+5,       B→daoPhysique+5
-- Q2: A→daoFortune+5,      B→daoConstitution+5
-- Q3: A→daoFortune+5,      B→daoWisdom+5
-- Q4: A→daoPhysique+5,     B→daoConstitution+5
-- Q5: A→daoAtk+5,          B→daoMaxHp+30

local EXPECTED_32 = {
    -- {answers, daoWisdom, daoFortune, daoConstitution, daoPhysique, daoAtk, daoMaxHp}
    -- Q1=A,Q2=A,Q3=A,Q4=A: W=5, F=10, C=0, P=5
    { {"A","A","A","A","A"},  5, 10,  0,  5,  5,  0 },
    { {"A","A","A","A","B"},  5, 10,  0,  5,  0, 30 },
    -- Q1=A,Q2=A,Q3=A,Q4=B: W=5, F=10, C=5, P=0
    { {"A","A","A","B","A"},  5, 10,  5,  0,  5,  0 },
    { {"A","A","A","B","B"},  5, 10,  5,  0,  0, 30 },
    -- Q1=A,Q2=A,Q3=B,Q4=A: W=10, F=5, C=0, P=5
    { {"A","A","B","A","A"}, 10,  5,  0,  5,  5,  0 },
    { {"A","A","B","A","B"}, 10,  5,  0,  5,  0, 30 },
    -- Q1=A,Q2=A,Q3=B,Q4=B: W=10, F=5, C=5, P=0
    { {"A","A","B","B","A"}, 10,  5,  5,  0,  5,  0 },
    { {"A","A","B","B","B"}, 10,  5,  5,  0,  0, 30 },
    -- Q1=A,Q2=B,Q3=A,Q4=A: W=5, F=5, C=5, P=5
    { {"A","B","A","A","A"},  5,  5,  5,  5,  5,  0 },
    { {"A","B","A","A","B"},  5,  5,  5,  5,  0, 30 },
    -- Q1=A,Q2=B,Q3=A,Q4=B: W=5, F=5, C=10, P=0
    { {"A","B","A","B","A"},  5,  5, 10,  0,  5,  0 },
    { {"A","B","A","B","B"},  5,  5, 10,  0,  0, 30 },
    -- Q1=A,Q2=B,Q3=B,Q4=A: W=10, F=0, C=5, P=5
    { {"A","B","B","A","A"}, 10,  0,  5,  5,  5,  0 },
    { {"A","B","B","A","B"}, 10,  0,  5,  5,  0, 30 },
    -- Q1=A,Q2=B,Q3=B,Q4=B: W=10, F=0, C=10, P=0
    { {"A","B","B","B","A"}, 10,  0, 10,  0,  5,  0 },
    { {"A","B","B","B","B"}, 10,  0, 10,  0,  0, 30 },
    -- Q1=B,Q2=A,Q3=A,Q4=A: W=0, F=10, C=0, P=10
    { {"B","A","A","A","A"},  0, 10,  0, 10,  5,  0 },
    { {"B","A","A","A","B"},  0, 10,  0, 10,  0, 30 },
    -- Q1=B,Q2=A,Q3=A,Q4=B: W=0, F=10, C=5, P=5
    { {"B","A","A","B","A"},  0, 10,  5,  5,  5,  0 },
    { {"B","A","A","B","B"},  0, 10,  5,  5,  0, 30 },
    -- Q1=B,Q2=A,Q3=B,Q4=A: W=5, F=5, C=0, P=10
    { {"B","A","B","A","A"},  5,  5,  0, 10,  5,  0 },
    { {"B","A","B","A","B"},  5,  5,  0, 10,  0, 30 },
    -- Q1=B,Q2=A,Q3=B,Q4=B: W=5, F=5, C=5, P=5
    { {"B","A","B","B","A"},  5,  5,  5,  5,  5,  0 },
    { {"B","A","B","B","B"},  5,  5,  5,  5,  0, 30 },
    -- Q1=B,Q2=B,Q3=A,Q4=A: W=0, F=5, C=5, P=10
    { {"B","B","A","A","A"},  0,  5,  5, 10,  5,  0 },
    { {"B","B","A","A","B"},  0,  5,  5, 10,  0, 30 },
    -- Q1=B,Q2=B,Q3=A,Q4=B: W=0, F=5, C=10, P=5
    { {"B","B","A","B","A"},  0,  5, 10,  5,  5,  0 },
    { {"B","B","A","B","B"},  0,  5, 10,  5,  0, 30 },
    -- Q1=B,Q2=B,Q3=B,Q4=A: W=5, F=0, C=5, P=10
    { {"B","B","B","A","A"},  5,  0,  5, 10,  5,  0 },
    { {"B","B","B","A","B"},  5,  0,  5, 10,  0, 30 },
    -- Q1=B,Q2=B,Q3=B,Q4=B: W=5, F=0, C=10, P=5
    { {"B","B","B","B","A"},  5,  0, 10,  5,  5,  0 },
    { {"B","B","B","B","B"},  5,  0, 10,  5,  0, 30 },
}

local function Test_AllPaths()
    for i, case in ipairs(EXPECTED_32) do
        local answers = case[1]
        local player = MockPlayer()
        local ok = DaoQuestionSystem.ApplyAnswers(player, answers)
        assert_true("路径" .. i .. "_ApplyOK", ok)
        assert_eq("路径" .. i .. "_悟性",   player.daoWisdom,       case[2])
        assert_eq("路径" .. i .. "_福缘",   player.daoFortune,      case[3])
        assert_eq("路径" .. i .. "_根骨",   player.daoConstitution, case[4])
        assert_eq("路径" .. i .. "_体魄",   player.daoPhysique,     case[5])
        assert_eq("路径" .. i .. "_攻击",   player.daoAtk,          case[6])
        assert_eq("路径" .. i .. "_生命",   player.daoMaxHp,        case[7])
        -- 验证 daoAnswers 记录
        assert_eq("路径" .. i .. "_答案数", #player.daoAnswers, 5)
        for j = 1, 5 do
            assert_eq("路径" .. i .. "_答案" .. j, player.daoAnswers[j], answers[j])
        end
    end
end

-- ============================================================================
-- 测试 2: ValidateAnswers 脏数据拦截
-- ============================================================================

local function Test_ValidateAnswers()
    -- 合法输入
    local valid = DaoQuestionSystem.ValidateAnswers({"A","B","A","B","A"})
    assert_true("合法答案_非nil", valid ~= nil)
    assert_eq("合法答案_长度", valid and #valid or 0, 5)

    -- nil 输入
    assert_eq("nil输入", DaoQuestionSystem.ValidateAnswers(nil), nil)

    -- 非 table 输入
    assert_eq("数字输入", DaoQuestionSystem.ValidateAnswers(123), nil)
    assert_eq("字符串输入", DaoQuestionSystem.ValidateAnswers("AABBA"), nil)

    -- 长度不对
    assert_eq("4个答案", DaoQuestionSystem.ValidateAnswers({"A","B","A","B"}), nil)
    assert_eq("6个答案", DaoQuestionSystem.ValidateAnswers({"A","B","A","B","A","A"}), nil)
    assert_eq("空表", DaoQuestionSystem.ValidateAnswers({}), nil)

    -- 值非法
    assert_eq("含C值", DaoQuestionSystem.ValidateAnswers({"A","B","C","A","A"}), nil)
    assert_eq("含小写a", DaoQuestionSystem.ValidateAnswers({"a","B","A","A","A"}), nil)
    assert_eq("含数字1", DaoQuestionSystem.ValidateAnswers({1,"B","A","A","A"}), nil)
    assert_eq("含nil值", DaoQuestionSystem.ValidateAnswers({"A",nil,"A","A","A"}), nil)

    -- 非连续键
    local sparse = {}
    sparse[1] = "A"
    sparse[3] = "B"
    sparse[5] = "A"
    assert_eq("稀疏键", DaoQuestionSystem.ValidateAnswers(sparse), nil)

    -- 多余键（hash 部分）
    local extra = {"A","B","A","B","A"}
    extra["foo"] = "bar"
    assert_eq("多余hash键", DaoQuestionSystem.ValidateAnswers(extra), nil)
end

-- ============================================================================
-- 测试 3: HasCompleted 判定
-- ============================================================================

local function Test_HasCompleted()
    -- 未答题
    local p1 = MockPlayer()
    assert_false("未答题_未完成", DaoQuestionSystem.HasCompleted(p1))

    -- 已答题
    DaoQuestionSystem.ApplyAnswers(p1, {"A","A","A","A","A"})
    assert_true("已答题_已完成", DaoQuestionSystem.HasCompleted(p1))

    -- 清除后
    DaoQuestionSystem.ClearDaoFields(p1)
    assert_false("清除后_未完成", DaoQuestionSystem.HasCompleted(p1))

    -- daoAnswers 被篡改
    local p2 = MockPlayer({ daoAnswers = {"A","B","C","A","A"} })
    assert_false("脏答案_未完成", DaoQuestionSystem.HasCompleted(p2))
end

-- ============================================================================
-- 测试 4: ClearDaoFields 清零
-- ============================================================================

local function Test_ClearDaoFields()
    local p = MockPlayer()
    DaoQuestionSystem.ApplyAnswers(p, {"A","A","A","A","A"})
    -- 确认非零
    assert_true("清零前_悟性非0", p.daoWisdom > 0)

    DaoQuestionSystem.ClearDaoFields(p)
    assert_eq("清零_悟性", p.daoWisdom, 0)
    assert_eq("清零_福缘", p.daoFortune, 0)
    assert_eq("清零_根骨", p.daoConstitution, 0)
    assert_eq("清零_体魄", p.daoPhysique, 0)
    assert_eq("清零_攻击", p.daoAtk, 0)
    assert_eq("清零_生命", p.daoMaxHp, 0)
    assert_eq("清零_答案数", #p.daoAnswers, 0)
    assert_eq("清零_缓存", p._statsCacheFrame, -1)
end

-- ============================================================================
-- 测试 5: Session 事务流程
-- ============================================================================

local function Test_SessionCommit()
    local p = MockPlayer({ lingYun = 2000 })

    -- 首次问心 (非重置)
    local entered = DaoQuestionSystem.TryEnter(p, "create_char")
    assert_true("首次_TryEnter成功", entered)

    local session = DaoQuestionSystem.GetSession()
    assert_true("首次_会话存在", session ~= nil)
    assert_false("首次_非重置", session and session.isReset or false)

    -- 逐题记录
    DaoQuestionSystem.RecordAnswer(1, "B")
    DaoQuestionSystem.RecordAnswer(2, "A")
    DaoQuestionSystem.RecordAnswer(3, "B")
    DaoQuestionSystem.RecordAnswer(4, "A")
    DaoQuestionSystem.RecordAnswer(5, "A")

    -- 提交前灵韵不变（首次不扣费）
    local lingYunBefore = p.lingYun
    local ok = DaoQuestionSystem.CommitSession()
    assert_true("首次_CommitOK", ok)
    assert_eq("首次_灵韵不变", p.lingYun, lingYunBefore)

    -- 验证属性已写入
    -- B,A,B,A,A → W=5(Q3B), F=5(Q2A), C=0, P=10(Q1B+Q4A), Atk=5, MaxHp=0
    assert_eq("首次_悟性", p.daoWisdom, 5)
    assert_eq("首次_福缘", p.daoFortune, 5)
    assert_eq("首次_根骨", p.daoConstitution, 0)
    assert_eq("首次_体魄", p.daoPhysique, 10)
    assert_eq("首次_攻击", p.daoAtk, 5)
    assert_eq("首次_生命", p.daoMaxHp, 0)

    -- 会话已清除
    assert_eq("首次_会话已清除", DaoQuestionSystem.GetSession(), nil)
end

-- ============================================================================
-- 测试 6: AbortSession 零副作用
-- ============================================================================

local function Test_SessionAbort()
    local p = MockPlayer({ lingYun = 2000 })

    -- 先做一次问心，确认已有数据
    DaoQuestionSystem.ApplyAnswers(p, {"A","A","A","A","A"})
    local origW = p.daoWisdom
    local origF = p.daoFortune
    local origLY = p.lingYun

    -- 开始重置会话
    local entered = DaoQuestionSystem.TryEnter(p, "npc_reset")
    assert_true("中止_TryEnter成功", entered)

    -- 记录部分答案
    DaoQuestionSystem.RecordAnswer(1, "B")
    DaoQuestionSystem.RecordAnswer(2, "B")

    -- 中止
    DaoQuestionSystem.AbortSession()

    -- 验证：旧数据完全不变
    assert_eq("中止_悟性不变", p.daoWisdom, origW)
    assert_eq("中止_福缘不变", p.daoFortune, origF)
    assert_eq("中止_灵韵不变", p.lingYun, origLY)
    assert_eq("中止_会话已清除", DaoQuestionSystem.GetSession(), nil)
    assert_true("中止_仍已完成", DaoQuestionSystem.HasCompleted(p))
end

-- ============================================================================
-- 测试 7: 重置流程（灵韵扣费）
-- ============================================================================

local function Test_ResetFlow()
    local p = MockPlayer({ lingYun = 2000 })

    -- 先完成首次问心
    DaoQuestionSystem.ApplyAnswers(p, {"A","A","A","A","A"})
    assert_true("重置_已完成", DaoQuestionSystem.HasCompleted(p))

    -- 重置问心
    local entered = DaoQuestionSystem.TryEnter(p, "npc_reset")
    assert_true("重置_TryEnter成功", entered)

    DaoQuestionSystem.RecordAnswer(1, "B")
    DaoQuestionSystem.RecordAnswer(2, "B")
    DaoQuestionSystem.RecordAnswer(3, "B")
    DaoQuestionSystem.RecordAnswer(4, "B")
    DaoQuestionSystem.RecordAnswer(5, "B")

    local ok = DaoQuestionSystem.CommitSession()
    assert_true("重置_CommitOK", ok)

    -- 验证灵韵已扣
    assert_eq("重置_灵韵扣除", p.lingYun, 2000 - DaoQuestionSystem.RESET_COST)

    -- 验证属性更新: B,B,B,B,B → W=5(Q3B), F=0, C=10(Q2B+Q4B), P=5(Q1B), Atk=0, MaxHp=30
    assert_eq("重置_悟性", p.daoWisdom, 5)
    assert_eq("重置_福缘", p.daoFortune, 0)
    assert_eq("重置_根骨", p.daoConstitution, 10)
    assert_eq("重置_体魄", p.daoPhysique, 5)
    assert_eq("重置_攻击", p.daoAtk, 0)
    assert_eq("重置_生命", p.daoMaxHp, 30)
end

-- ============================================================================
-- 测试 8: 灵韵不足拒绝重置
-- ============================================================================

local function Test_InsufficientLingYun()
    local p = MockPlayer({ lingYun = 100 })  -- 不足 500

    -- 先完成首次
    DaoQuestionSystem.ApplyAnswers(p, {"A","A","A","A","A"})
    local origW = p.daoWisdom

    -- TryEnter 应拒绝
    local entered = DaoQuestionSystem.TryEnter(p, "npc_reset")
    assert_false("灵韵不足_TryEnter被拒", entered)
    assert_eq("灵韵不足_会话无", DaoQuestionSystem.GetSession(), nil)
    assert_eq("灵韵不足_悟性不变", p.daoWisdom, origW)
    assert_eq("灵韵不足_灵韵不变", p.lingYun, 100)
end

-- ============================================================================
-- 测试 9: TryEnter 边界检查
-- ============================================================================

local function Test_TryEnterEdgeCases()
    -- 未完成时不允许 npc_reset
    local p1 = MockPlayer()
    local entered1 = DaoQuestionSystem.TryEnter(p1, "npc_reset")
    assert_false("未完成_不可重置", entered1)
    DaoQuestionSystem.AbortSession()  -- 清理

    -- 已完成时不允许 create_char / npc_first
    local p2 = MockPlayer()
    DaoQuestionSystem.ApplyAnswers(p2, {"A","A","A","A","A"})
    local entered2 = DaoQuestionSystem.TryEnter(p2, "create_char")
    assert_false("已完成_不可首次", entered2)
    DaoQuestionSystem.AbortSession()  -- 清理

    local entered3 = DaoQuestionSystem.TryEnter(p2, "npc_first")
    assert_false("已完成_不可首次npc", entered3)
    DaoQuestionSystem.AbortSession()  -- 清理

    -- 未知 source
    local p3 = MockPlayer()
    local entered4 = DaoQuestionSystem.TryEnter(p3, "invalid_source")
    assert_false("未知source_拒绝", entered4)
    DaoQuestionSystem.AbortSession()  -- 清理
end

-- ============================================================================
-- 测试 10: CommitSession 不完整答案拒绝
-- ============================================================================

local function Test_IncompleteCommit()
    local p = MockPlayer()
    DaoQuestionSystem.TryEnter(p, "create_char")

    -- 只记录 3 题
    DaoQuestionSystem.RecordAnswer(1, "A")
    DaoQuestionSystem.RecordAnswer(2, "B")
    DaoQuestionSystem.RecordAnswer(3, "A")

    local ok = DaoQuestionSystem.CommitSession()
    assert_false("不完整_Commit拒绝", ok)
    -- 属性不应改变
    assert_eq("不完整_悟性0", p.daoWisdom, 0)
    assert_eq("不完整_会话已清除", DaoQuestionSystem.GetSession(), nil)
end

-- ============================================================================
-- 汇总
-- ============================================================================

function TestDaoQuestion.RunAll()
    pass_ = 0
    fail_ = 0
    results_ = {}

    -- 确保无残留会话
    DaoQuestionSystem.AbortSession()

    Test_AllPaths()
    Test_ValidateAnswers()
    Test_HasCompleted()
    Test_ClearDaoFields()
    Test_SessionCommit()
    Test_SessionAbort()
    Test_ResetFlow()
    Test_InsufficientLingYun()
    Test_TryEnterEdgeCases()
    Test_IncompleteCommit()

    -- 清理残留
    DaoQuestionSystem.AbortSession()

    -- 打印结果
    print("============================================")
    print("[DaoQuestion Test] PASS=" .. pass_ .. " FAIL=" .. fail_)
    print("============================================")
    for _, line in ipairs(results_) do
        print(line)
    end

    return pass_, fail_
end

return TestDaoQuestion
