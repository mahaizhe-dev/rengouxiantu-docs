-- ============================================================================
-- DaoQuestionSystem.lua - 天道问心系统核心逻辑
-- 角色创建后（或NPC重置时）五道天问，决定初始仙缘加成
-- ============================================================================

local GameState = require("core.GameState")

local DaoQuestionSystem = {}

-- ============================================================================
-- 常量
-- ============================================================================

--- 重置费用（灵韵）
DaoQuestionSystem.RESET_COST = 500

--- 五道天问数据
--- 每题: { intro = 引语, optA = 选项A文案, optB = 选项B文案, statA = {字段=值}, statB = {字段=值} }
DaoQuestionSystem.QUESTIONS = {
    {
        intro = "道法万千——",
        optA  = "剑破万法",
        optB  = "梦证长生",
        statA = { daoWisdom = 5 },
        statB = { daoPhysique = 5 },
    },
    {
        intro = "万物生灵——",
        optA  = "有情",
        optB  = "无情",
        statA = { daoFortune = 5 },
        statB = { daoConstitution = 5 },
    },
    {
        intro = "天道昭昭——",
        optA  = "应天命",
        optB  = "逆天行",
        statA = { daoFortune = 5 },
        statB = { daoWisdom = 5 },
    },
    {
        intro = "大道归途——",
        optA  = "是魔",
        optB  = "是仙",
        statA = { daoPhysique = 5 },
        statB = { daoConstitution = 5 },
    },
    {
        intro = "生死之间——",
        optA  = "向死而生",
        optB  = "住世为愿",
        statA = { daoAtk = 5 },
        statB = { daoMaxHp = 30 },
    },
}

--- daoAnswers 合法值
local VALID_VALUES = { A = true, B = true }

-- ============================================================================
-- 校验
-- ============================================================================

--- 校验 daoAnswers 是否合法
--- @param raw any  从存档或 GM 命令传入的原始值
--- @return table|nil  合法则返回规范化后的 table，否则返回 nil
function DaoQuestionSystem.ValidateAnswers(raw)
    if type(raw) ~= "table" then return nil end

    -- 必须恰好 5 个元素
    local count = 0
    for _ in pairs(raw) do count = count + 1 end
    if count ~= 5 then return nil end

    -- 每个元素必须是连续整数键 1~5，值为 "A" 或 "B"
    local result = {}
    for i = 1, 5 do
        local v = raw[i]
        if type(v) ~= "string" or not VALID_VALUES[v] then
            return nil
        end
        result[i] = v
    end
    return result
end

--- 判断玩家是否已完成问心
--- @param player table
--- @return boolean
function DaoQuestionSystem.HasCompleted(player)
    return DaoQuestionSystem.ValidateAnswers(player.daoAnswers) ~= nil
end

-- ============================================================================
-- 属性操作
-- ============================================================================

--- 清零全部 dao* 字段（重置前调用）
--- @param player table
function DaoQuestionSystem.ClearDaoFields(player)
    player.daoWisdom       = 0
    player.daoFortune      = 0
    player.daoConstitution = 0
    player.daoPhysique     = 0
    player.daoAtk          = 0
    player.daoMaxHp        = 0
    player.daoAnswers      = {}
    -- 清除属性缓存，强制下次 GetTotal* 重算
    player._statsCacheFrame = -1
end

--- 根据已校验的答案表写入 dao* 加成
--- @param player table
--- @param answers table  经过 ValidateAnswers 校验的合法答案 {1="A", 2="B", ...}
function DaoQuestionSystem.ApplyAnswers(player, answers)
    -- 防御性校验
    local valid = DaoQuestionSystem.ValidateAnswers(answers)
    if not valid then
        print("[DaoQuestion] ERROR: ApplyAnswers received invalid answers")
        return false
    end

    -- 先清零，防止重复叠加
    player.daoWisdom       = 0
    player.daoFortune      = 0
    player.daoConstitution = 0
    player.daoPhysique     = 0
    player.daoAtk          = 0
    player.daoMaxHp        = 0

    -- 逐题累加属性
    for i = 1, 5 do
        local q = DaoQuestionSystem.QUESTIONS[i]
        local choice = valid[i]
        local stats = (choice == "A") and q.statA or q.statB
        for field, value in pairs(stats) do
            player[field] = (player[field] or 0) + value
        end
    end

    -- 记录答案
    player.daoAnswers = valid

    -- 清除属性缓存，强制下次 GetTotal* 重算
    player._statsCacheFrame = -1

    print(string.format("[DaoQuestion] Applied answers: W=%d F=%d C=%d P=%d Atk=%d MaxHp=%d",
        player.daoWisdom, player.daoFortune, player.daoConstitution,
        player.daoPhysique, player.daoAtk, player.daoMaxHp))
    return true
end

-- ============================================================================
-- 会话事务管理
-- ============================================================================

-- 当前会话状态（非持久化，仅运行时）
DaoQuestionSystem._session = nil

--- 开始问心会话（仅标记，不动持久数据）
--- @param player table
--- @param isReset boolean  是否为重置模式
function DaoQuestionSystem.BeginSession(player, isReset)
    DaoQuestionSystem._session = {
        player  = player,
        isReset = isReset,
        answers = {},  -- 本次会话临时答案
    }
    print("[DaoQuestion] Session begun, isReset=" .. tostring(isReset))
end

--- 记录当前题目的选择（临时，不写入 player）
--- @param questionIndex number  题号 1~5
--- @param choice string  "A" 或 "B"
function DaoQuestionSystem.RecordAnswer(questionIndex, choice)
    local s = DaoQuestionSystem._session
    if not s then
        print("[DaoQuestion] ERROR: RecordAnswer called without active session")
        return
    end
    if questionIndex < 1 or questionIndex > 5 then return end
    if choice ~= "A" and choice ~= "B" then return end
    s.answers[questionIndex] = choice
end

--- 提交会话：原子执行 扣费→清旧→写新→存档
--- @return boolean success
function DaoQuestionSystem.CommitSession()
    local s = DaoQuestionSystem._session
    if not s then
        print("[DaoQuestion] ERROR: CommitSession called without active session")
        return false
    end

    -- 校验答案完整性
    local valid = DaoQuestionSystem.ValidateAnswers(s.answers)
    if not valid then
        print("[DaoQuestion] ERROR: CommitSession failed, invalid answers: "
            .. tostring(s.answers and #s.answers or "nil"))
        DaoQuestionSystem._session = nil
        return false
    end

    local player = s.player

    -- ★ 原子操作开始 ——————————————————
    -- 1. 扣灵韵（仅重置时）
    if s.isReset then
        if player.lingYun < DaoQuestionSystem.RESET_COST then
            print("[DaoQuestion] ERROR: CommitSession failed, insufficient lingYun: " .. (player.lingYun or 0))
            DaoQuestionSystem._session = nil
            return false
        end
        player.lingYun = player.lingYun - DaoQuestionSystem.RESET_COST
        print("[DaoQuestion] Deducted " .. DaoQuestionSystem.RESET_COST .. " lingYun, remaining: " .. player.lingYun)
    end

    -- 2. 清旧加成
    DaoQuestionSystem.ClearDaoFields(player)

    -- 3. 写新加成
    DaoQuestionSystem.ApplyAnswers(player, valid)

    -- 4. 标记存档脏位
    local SavePersistence = require("systems.save.SavePersistence")
    if SavePersistence and SavePersistence.MarkDirty then
        SavePersistence.MarkDirty()
    end
    -- ★ 原子操作结束 ——————————————————

    DaoQuestionSystem._session = nil
    print("[DaoQuestion] Session committed successfully")
    return true
end

--- 中止会话：丢弃临时数据，不改任何持久状态
function DaoQuestionSystem.AbortSession()
    if DaoQuestionSystem._session then
        print("[DaoQuestion] Session aborted, no changes made")
    end
    DaoQuestionSystem._session = nil
end

--- 获取当前会话（供 UI 读取）
--- @return table|nil
function DaoQuestionSystem.GetSession()
    return DaoQuestionSystem._session
end

-- ============================================================================
-- 统一入口
-- ============================================================================

--- 统一入口判定（所有触发场景都调用此函数）
--- @param player table
--- @param source string  "create_char" | "npc_first" | "npc_reset"
--- @return boolean entered  是否成功进入问心
function DaoQuestionSystem.TryEnter(player, source)
    if source == "create_char" or source == "npc_first" then
        -- 首次问心：daoAnswers 必须为空或非法
        if DaoQuestionSystem.HasCompleted(player) then
            print("[DaoQuestion] TryEnter rejected: already completed (source=" .. source .. ")")
            return false
        end
        DaoQuestionSystem.BeginSession(player, false)
        return true

    elseif source == "npc_reset" then
        -- 重置问心：必须已答过 + 灵韵足够
        if not DaoQuestionSystem.HasCompleted(player) then
            print("[DaoQuestion] TryEnter rejected: never completed, should use npc_first")
            return false
        end
        if player.lingYun < DaoQuestionSystem.RESET_COST then
            print("[DaoQuestion] TryEnter rejected: insufficient lingYun ("
                .. (player.lingYun or 0) .. " < " .. DaoQuestionSystem.RESET_COST .. ")")
            return false
        end
        DaoQuestionSystem.BeginSession(player, true)
        return true
    end

    print("[DaoQuestion] TryEnter rejected: unknown source=" .. tostring(source))
    return false
end

return DaoQuestionSystem
