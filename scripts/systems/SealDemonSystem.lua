-- ============================================================================
-- SealDemonSystem.lua - 封魔任务核心逻辑
-- 管理封魔任务状态、魔化BOSS生成、击杀判定
-- 替代旧 ExorcismSystem
-- ============================================================================

local SealDemonConfig = require("config.SealDemonConfig")
local MonsterData = require("config.MonsterData")
local Monster = require("entities.Monster")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local InventorySystem = require("systems.InventorySystem")

local SaveProtocol = require("network.SaveProtocol")

local SealDemonSystem = {}

--- 获取今天的日期字符串（用于日常重置判断）
---@return string "YYYY-MM-DD"
local function GetTodayDate()
    return os.date("%Y-%m-%d")
end

-- ── 状态 ──
SealDemonSystem.questStates = {}       -- { [questId] = "locked"|"available"|"active"|"completed" }
SealDemonSystem.activeQuestId = nil    -- 当前进行中的一次性任务ID
SealDemonSystem.activeQuestMonster = nil -- 一次性任务怪物实例
SealDemonSystem.activeDailyChapter = nil -- 当前进行中的日常章节(1/2/3)
SealDemonSystem.activeDailyMonster = nil -- 日常任务怪物实例
SealDemonSystem.activeDemonMonster = nil -- 兼容：指向任意一个活跃怪物（优先日常）
SealDemonSystem.dailyCompletedDate = nil -- 日常封魔完成日期（"YYYY-MM-DD" 或 nil）
SealDemonSystem._acceptingAt = 0        -- C2S 防抖时间戳（0=空闲）
SealDemonSystem._reportingAt = 0        -- 击杀上报防抖时间戳

local C2S_TIMEOUT = 10  -- 秒：C2S 请求超时自动解锁

--- 判断防抖是否生效（未超时返回 true）
---@param startTime number os.clock() 时间戳
---@return boolean
local function _isThrottled(startTime)
    return startTime > 0 and (os.clock() - startTime) < C2S_TIMEOUT
end

--- 初始化（游戏启动时调用一次）
function SealDemonSystem.Init()
    SealDemonSystem.questStates = {}
    SealDemonSystem.activeQuestId = nil
    SealDemonSystem.activeQuestMonster = nil
    SealDemonSystem.activeDailyChapter = nil
    SealDemonSystem.activeDailyMonster = nil
    SealDemonSystem.activeDemonMonster = nil
    SealDemonSystem.dailyCompletedDate = nil

    -- 初始化所有一次性任务为 locked
    for _, q in ipairs(SealDemonConfig.QUESTS) do
        SealDemonSystem.questStates[q.id] = "locked"
    end

    -- 监听怪物死亡
    EventBus.On("monster_death", function(monster)
        SealDemonSystem.OnMonsterDeath(monster)
    end)

    -- 订阅 S2C 网络事件
    SealDemonSystem.InitNetwork()
end

-- ============================================================================
-- 魔化 BOSS 创建
-- ============================================================================

--- 从原BOSS数据创建魔化版本
---@param sourceBossId string 原BOSS的typeId
---@param config table { overrideLevel, overrideCategory, overrideRealm }
---@return table demonData 可传入 Monster.New 的数据
function SealDemonSystem.CreateDemonBoss(sourceBossId, config)
    local source = MonsterData.Types[sourceBossId]
    if not source then
        print("[SealDemonSystem] ERROR: source boss not found: " .. tostring(sourceBossId))
        return nil
    end

    local demon = Utils.DeepCopy(source)

    -- 封魔标记
    demon.isDemon = true
    demon.isSealDemon = true

    -- 等级覆盖
    if config.overrideLevel then
        demon.level = config.overrideLevel
        -- 清除 levelRange，使用固定等级
        demon.levelRange = nil
    end

    -- 类别升级
    if config.overrideCategory then
        demon.category = config.overrideCategory
    end

    -- 境界覆盖
    if config.overrideRealm then
        demon.realm = config.overrideRealm
    end

    -- 魔化增幅
    local buff = SealDemonConfig.DEMON_BUFF
    demon.berserkBuff = buff.berserkBuff
    demon.sealDemonHpMult = buff.hpMult

    -- 名称前缀
    demon.name = "魔·" .. (source.name or sourceBossId)

    return demon
end

-- ============================================================================
-- 任务状态管理
-- ============================================================================

--- 刷新任务状态（根据玩家等级解锁）
---@param playerLevel number
function SealDemonSystem.RefreshQuests(playerLevel)
    for _, q in ipairs(SealDemonConfig.QUESTS) do
        local state = SealDemonSystem.questStates[q.id]
        if state == "locked" then
            if playerLevel >= q.requiredLevel then
                SealDemonSystem.questStates[q.id] = "available"
            end
        end
    end
end

--- 获取指定章节的一次性任务及状态
---@param chapter number
---@return table[]
function SealDemonSystem.GetChapterQuests(chapter)
    local result = {}
    for _, q in ipairs(SealDemonConfig.QUESTS) do
        if q.chapter == chapter then
            table.insert(result, {
                quest = q,
                state = SealDemonSystem.questStates[q.id] or "locked",
            })
        end
    end
    return result
end

--- 检查指定章节的一次性任务是否全部完成（日常解锁条件）
---@param chapter number
---@return boolean
function SealDemonSystem.IsChapterCompleted(chapter)
    local daily = SealDemonConfig.DAILY[chapter]
    if not daily then return false end
    for _, questId in ipairs(daily.requiredQuests) do
        if SealDemonSystem.questStates[questId] ~= "completed" then
            return false
        end
    end
    return true
end

--- 获取玩家已解锁的最高日常章节
---@return number 0=无，1/2/3
function SealDemonSystem.GetHighestUnlockedDailyChapter()
    local highest = 0
    for ch = 1, 4 do
        if SealDemonSystem.IsChapterCompleted(ch) then
            highest = ch
        end
    end
    return highest
end

--- 是否有进行中的封魔任务（任意类型）
---@return boolean
function SealDemonSystem.HasActiveTask()
    return SealDemonSystem.activeQuestId ~= nil or SealDemonSystem.activeDailyChapter ~= nil
end

--- 是否有进行中的一次性任务
function SealDemonSystem.HasActiveQuest()
    return SealDemonSystem.activeQuestId ~= nil
end

--- 是否有进行中的日常任务
function SealDemonSystem.HasActiveDaily()
    return SealDemonSystem.activeDailyChapter ~= nil
end

--- 获取每日封魔进度（供 Minimap 日常仙缘面板使用）
---@return number done 已完成次数 (0 或 1)
---@return number limit 每日上限 (1)
function SealDemonSystem.GetDailyProgress()
    local done = (SealDemonSystem.dailyCompletedDate == GetTodayDate())
    return done and 1 or 0, 1
end

-- ============================================================================
-- 接取任务（客户端预处理，实际验证在服务端）
-- ============================================================================

--- 接取一次性封魔任务（C2S 模式：发请求到服务端）
---@param questId string
---@return boolean success 请求是否已发送
---@return string|nil errorMsg
function SealDemonSystem.AcceptQuest(questId)
    -- 客户端预检（减少无效请求）
    local state = SealDemonSystem.questStates[questId]
    if state ~= "available" then
        return false, "任务不可接受（当前状态: " .. tostring(state) .. "）"
    end

    if SealDemonSystem.HasActiveQuest() then
        return false, "已有进行中的一次性封魔任务"
    end

    if _isThrottled(SealDemonSystem._acceptingAt) then
        return false, "正在处理中，请稍候"
    end

    local serverConn = network:GetServerConnection()
    if not serverConn then
        return false, "网络未连接"
    end

    SealDemonSystem._acceptingAt = os.clock()

    local data = VariantMap()
    data["questId"] = Variant(questId)
    data["dailyChapter"] = Variant(0)  -- 0 = 非日常
    serverConn:SendRemoteEvent(SaveProtocol.C2S_SealDemonAccept, true, data)

    print("[SealDemonSystem] C2S AcceptQuest sent: " .. questId)
    return true
end

--- 接取日常封魔任务（C2S 模式：发请求到服务端）
---@param chapter number 1/2/3
---@return boolean success 请求是否已发送
---@return string|nil errorMsg
function SealDemonSystem.AcceptDaily(chapter)
    -- 客户端预检
    if SealDemonSystem.dailyCompletedDate == GetTodayDate() then
        return false, "今日日常封魔已完成"
    end

    if SealDemonSystem.HasActiveDaily() then
        return false, "已有进行中的日常封魔任务"
    end

    if not SealDemonSystem.IsChapterCompleted(chapter) then
        return false, "需先完成该章全部一次性封魔任务"
    end

    if _isThrottled(SealDemonSystem._acceptingAt) then
        return false, "正在处理中，请稍候"
    end

    local serverConn = network:GetServerConnection()
    if not serverConn then
        return false, "网络未连接"
    end

    SealDemonSystem._acceptingAt = os.clock()

    local data = VariantMap()
    data["questId"] = Variant("")  -- 空串 = 非一次性
    data["dailyChapter"] = Variant(chapter)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_SealDemonAccept, true, data)

    print("[SealDemonSystem] C2S AcceptDaily sent: chapter=" .. chapter)
    return true
end

-- ============================================================================
-- 击杀回调
-- ============================================================================

--- 怪物死亡回调（C2S 模式：上报击杀，等待服务端发奖）
---@param monster table
function SealDemonSystem.OnMonsterDeath(monster)
    if not monster then return end
    if not monster.isSealDemon then return end

    -- 判断是哪种任务的怪物
    local isQuestMonster = (monster == SealDemonSystem.activeQuestMonster)
    local isDailyMonster = (monster == SealDemonSystem.activeDailyMonster)
    if not isQuestMonster and not isDailyMonster then return end

    if _isThrottled(SealDemonSystem._reportingAt) then return end

    -- 清除本地怪物引用（怪物已死）
    if isQuestMonster then
        SealDemonSystem.activeQuestMonster = nil
    elseif isDailyMonster then
        SealDemonSystem.activeDailyMonster = nil
    end
    SealDemonSystem.activeDemonMonster = nil

    -- 发送击杀上报到服务端
    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[SealDemonSystem] WARNING: BossKilled but no server connection, applying locally")
        -- 降级：无网络时本地发奖（兜底）
        SealDemonSystem._applyRewardLocally(isQuestMonster, isDailyMonster)
        return
    end

    SealDemonSystem._reportingAt = os.clock()
    serverConn:SendRemoteEvent(SaveProtocol.C2S_SealDemonBossKilled, true, VariantMap())
    print("[SealDemonSystem] C2S BossKilled sent")
end

--- 本地发奖降级逻辑（仅在无网络时使用）
---@param isQuest boolean
---@param isDaily boolean
function SealDemonSystem._applyRewardLocally(isQuest, isDaily)
    if isQuest then
        local questId = SealDemonSystem.activeQuestId
        local questDef = SealDemonConfig.QUEST_BY_ID[questId]
        SealDemonSystem.questStates[questId] = "completed"
        SealDemonSystem.activeQuestId = nil

        local player = GameState.player
        if player and questDef and questDef.reward then
            if questDef.reward.lingYun then player:GainLingYun(questDef.reward.lingYun) end
            if questDef.reward.petFood then
                InventorySystem.AddConsumable(questDef.reward.petFood, questDef.reward.petFoodCount or 1)
            end
        end
        EventBus.Emit("seal_demon_victory", {
            type = "quest", questId = questId,
            questDef = questDef, reward = questDef and questDef.reward or {},
        })
        print("[SealDemonSystem] Local fallback reward: quest " .. tostring(questId))

    elseif isDaily then
        local chapter = SealDemonSystem.activeDailyChapter
        local daily = SealDemonConfig.DAILY[chapter]
        SealDemonSystem.activeDailyChapter = nil
        SealDemonSystem.dailyCompletedDate = GetTodayDate()

        local player = GameState.player
        if player and daily and daily.reward then
            if daily.reward.lingYun then player:GainLingYun(daily.reward.lingYun) end
            if daily.reward.petFood then
                InventorySystem.AddConsumable(daily.reward.petFood, daily.reward.petFoodCount or 1)
            end
            if daily.reward.physiquePill and daily.reward.physiquePill > 0 then
                local maxPill = SealDemonConfig.PHYSIQUE_PILL.maxCount
                local current = player.pillPhysique or 0
                if current < maxPill then
                    player.pillPhysique = math.min(current + daily.reward.physiquePill, maxPill)
                end
            end
        end
        EventBus.Emit("seal_demon_victory", {
            type = "daily", chapter = chapter,
            dailyDef = daily, reward = daily and daily.reward or {},
        })
        print("[SealDemonSystem] Local fallback reward: daily ch" .. tostring(chapter))
    end
end

-- ============================================================================
-- 放弃 / 更新
-- ============================================================================

--- 放弃当前封魔任务（放弃所有进行中的）
function SealDemonSystem.AbandonActiveTask()
    local hadActive = SealDemonSystem.HasActiveTask()

    -- 放弃一次性任务
    if SealDemonSystem.activeQuestMonster then
        GameState.RemoveMonster(SealDemonSystem.activeQuestMonster)
        SealDemonSystem.activeQuestMonster = nil
    end
    if SealDemonSystem.activeQuestId then
        SealDemonSystem.questStates[SealDemonSystem.activeQuestId] = "available"
        SealDemonSystem.activeQuestId = nil
        print("[SealDemonSystem] 放弃一次性任务")
    end

    -- 放弃日常任务
    if SealDemonSystem.activeDailyMonster then
        GameState.RemoveMonster(SealDemonSystem.activeDailyMonster)
        SealDemonSystem.activeDailyMonster = nil
    end
    if SealDemonSystem.activeDailyChapter then
        SealDemonSystem.activeDailyChapter = nil
        print("[SealDemonSystem] 放弃日常任务")
    end

    SealDemonSystem.activeDemonMonster = nil

    -- 通知服务端清除 sealDemonActive_ 状态（fire-and-forget）
    if hadActive then
        local serverConn = network:GetServerConnection()
        if serverConn then
            serverConn:SendRemoteEvent(SaveProtocol.C2S_SealDemonAbandon, true, VariantMap())
            print("[SealDemonSystem] C2S Abandon sent")
        end
    end
end

--- 帧更新（检查怪物是否被系统清理）
function SealDemonSystem.Update(dt)
    -- 检查一次性任务怪物
    if SealDemonSystem.activeQuestMonster and not SealDemonSystem.activeQuestMonster.alive then
        SealDemonSystem.activeQuestMonster = nil
        if SealDemonSystem.activeQuestId then
            SealDemonSystem.questStates[SealDemonSystem.activeQuestId] = "available"
            SealDemonSystem.activeQuestId = nil
        end
    end

    -- 检查日常任务怪物
    if SealDemonSystem.activeDailyMonster and not SealDemonSystem.activeDailyMonster.alive then
        SealDemonSystem.activeDailyMonster = nil
        SealDemonSystem.activeDailyChapter = nil
    end

    -- 更新兼容字段
    SealDemonSystem.activeDemonMonster = SealDemonSystem.activeDailyMonster or SealDemonSystem.activeQuestMonster
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

--- 序列化（存档）
---@return table
function SealDemonSystem.Serialize()
    local data = {
        quests = {},
        dailyCompletedDate = SealDemonSystem.dailyCompletedDate,
    }
    for questId, state in pairs(SealDemonSystem.questStates) do
        -- 只保存 completed 和 available（active 重新加载后变回 available）
        if state == "completed" then
            data.quests[questId] = "completed"
        elseif state == "available" or state == "active" then
            data.quests[questId] = "available"
        end
        -- locked 不保存（由 RefreshQuests 重新计算）
    end
    return data
end

--- 反序列化（读档）
---@param data table|nil sealDemon 存档数据
---@param pillPhysique number|nil 体魄丹累计
function SealDemonSystem.Deserialize(data, pillPhysique)
    -- 先初始化为全 locked
    for _, q in ipairs(SealDemonConfig.QUESTS) do
        SealDemonSystem.questStates[q.id] = "locked"
    end

    -- 恢复存档状态
    if data and data.quests then
        for questId, state in pairs(data.quests) do
            if SealDemonConfig.QUEST_BY_ID[questId] then
                SealDemonSystem.questStates[questId] = state
            end
        end
    end

    -- 恢复体魄丹（写入 player）
    if GameState.player and pillPhysique then
        GameState.player.pillPhysique = pillPhysique
    end

    -- 恢复日常完成状态（新版存日期字符串，旧版存 boolean 需兼容）
    if data and data.dailyCompletedDate then
        SealDemonSystem.dailyCompletedDate = data.dailyCompletedDate
    elseif data and data.dailyCompletedToday then
        -- 旧存档兼容：无日期信息，视为过期，允许今天重新接取（服务端 Quota 兜底）
        SealDemonSystem.dailyCompletedDate = nil
    else
        SealDemonSystem.dailyCompletedDate = nil
    end

    -- 清理活跃任务（加载时不恢复战斗）
    SealDemonSystem.activeQuestId = nil
    SealDemonSystem.activeQuestMonster = nil
    SealDemonSystem.activeDailyChapter = nil
    SealDemonSystem.activeDailyMonster = nil
    SealDemonSystem.activeDemonMonster = nil
end

-- ============================================================================
-- S2C 响应处理
-- ============================================================================

--- 服务端错误 reason → 玩家友好提示
local REASON_TEXT = {
    already_active    = "已有进行中的封魔任务",
    no_save           = "存档异常，请重启游戏",
    invalid_chapter   = "无效的章节",
    prereq_incomplete = "需先完成该章全部一次性封魔任务",
    daily_limit       = "今日日常封魔已完成",
    invalid_quest     = "无效的任务",
    level_too_low     = "等级不足",
    already_completed = "该任务已完成",
    server_error      = "服务器繁忙，请稍后重试",
    no_active_task    = "当前没有进行中的封魔任务",
    save_failed       = "存档保存失败，请稍后重试",
}

--- S2C_SealDemonAcceptResult 处理
---@param eventType string
---@param eventData table
function SealDemonSystem.HandleAcceptResult(eventType, eventData)
    SealDemonSystem._acceptingAt = 0

    local ok = eventData["ok"]:GetBool()
    if not ok then
        local reason = eventData["reason"]:GetString()
        local msg = REASON_TEXT[reason] or ("接取失败: " .. reason)
        EventBus.Emit("toast", msg)
        print("[SealDemonSystem] S2C AcceptResult FAIL: " .. reason)
        return
    end

    -- 成功：在客户端生成魔化 BOSS
    local bossId = eventData["bossId"]:GetString()
    local spawnX = eventData["spawnX"]:GetInt()
    local spawnY = eventData["spawnY"]:GetInt()

    -- 判断是一次性还是日常（一次性有 questId，日常有 bossLevel）
    local questId = ""
    local dailyChapter = 0
    -- 尝试读取 questId（一次性任务）
    if eventData["questId"] then
        local v = eventData["questId"]
        if v then questId = v:GetString() end
    end
    -- 尝试读取 bossLevel（日常任务标记）
    local bossLevel = 0
    if eventData["bossLevel"] then
        local v = eventData["bossLevel"]
        if v then bossLevel = v:GetInt() end
    end

    local isDaily = (questId == "" or questId == nil) and bossLevel > 0

    if isDaily then
        -- 日常任务：从 S2C 数据构建 overrides
        local bossCategory = eventData["bossCategory"]:GetString()
        local bossRealm = eventData["bossRealm"]:GetString()

        -- 检查低阶警告
        if eventData["warning"] then
            local warn = eventData["warning"]:GetString()
            if warn == "low_tier" then
                EventBus.Emit("toast", "提示：可选择更高章节获得更好奖励")
            end
        end

        -- 推断 dailyChapter：从 bossLevel 和配置反查
        for ch = 1, 4 do
            local daily = SealDemonConfig.DAILY[ch]
            if daily then
                for _, bp in ipairs(daily.bossPool) do
                    if bp.sourceBoss == bossId and bp.level == bossLevel then
                        dailyChapter = ch
                        break
                    end
                end
            end
            if dailyChapter > 0 then break end
        end
        -- 兜底：如果反查失败，根据 bossLevel 粗略判断
        if dailyChapter == 0 then
            if bossLevel <= 20 then dailyChapter = 1
            elseif bossLevel <= 40 then dailyChapter = 2
            else dailyChapter = 3 end
        end

        local demonData = SealDemonSystem.CreateDemonBoss(bossId, {
            overrideLevel = bossLevel,
            overrideCategory = bossCategory,
            overrideRealm = bossRealm,
        })
        if demonData then
            local monster = Monster.New(demonData, spawnX, spawnY)
            monster.typeId = bossId
            GameState.AddMonster(monster)

            monster.sealDemonChapter = dailyChapter
            monster.sealDemonDailyChapter = dailyChapter
            SealDemonSystem.activeDailyChapter = dailyChapter
            SealDemonSystem.activeDailyMonster = monster
            SealDemonSystem.activeDemonMonster = monster

            EventBus.Emit("toast", "日常封魔已接取，击败魔化BOSS！")
            print("[SealDemonSystem] S2C AcceptResult daily OK: ch=" .. dailyChapter
                .. " boss=" .. bossId .. " at " .. spawnX .. "," .. spawnY)
        else
            EventBus.Emit("toast", "BOSS 数据异常")
            print("[SealDemonSystem] ERROR: CreateDemonBoss failed for " .. bossId)
        end
    else
        -- 一次性任务
        local questDef = SealDemonConfig.QUEST_BY_ID[questId]
        if not questDef then
            EventBus.Emit("toast", "任务数据异常")
            print("[SealDemonSystem] ERROR: QUEST_BY_ID[" .. questId .. "] not found")
            return
        end

        local demonData = SealDemonSystem.CreateDemonBoss(bossId, {
            overrideLevel = questDef.level,
            overrideCategory = questDef.category,
            overrideRealm = questDef.realm,
        })
        if demonData then
            local monster = Monster.New(demonData, spawnX, spawnY)
            monster.typeId = bossId
            GameState.AddMonster(monster)

            monster.sealDemonChapter = questDef.chapter
            SealDemonSystem.questStates[questId] = "active"
            SealDemonSystem.activeQuestId = questId
            SealDemonSystem.activeQuestMonster = monster
            SealDemonSystem.activeDemonMonster = monster

            EventBus.Emit("toast", "封魔任务已接取，击败魔化BOSS！")
            print("[SealDemonSystem] S2C AcceptResult quest OK: " .. questId
                .. " boss=" .. bossId .. " at " .. spawnX .. "," .. spawnY)
        else
            EventBus.Emit("toast", "BOSS 数据异常")
            print("[SealDemonSystem] ERROR: CreateDemonBoss failed for " .. bossId)
        end
    end
end

--- S2C_SealDemonReward 处理
---@param eventType string
---@param eventData table
function SealDemonSystem.HandleReward(eventType, eventData)
    SealDemonSystem._reportingAt = 0

    local ok = eventData["ok"]:GetBool()
    if not ok then
        local reason = eventData["reason"]:GetString()

        -- 服务端保存类错误（save_failed/slot_locked/no_save），降级为本地发奖
        -- BOSS 已死，奖励不应丢失；本地状态将由下次 auto-save 同步到服务端
        if reason == "save_failed" or reason == "slot_locked" or reason == "no_save" then
            print("[SealDemonSystem] S2C Reward server-save error (" .. reason .. "), applying locally as fallback")
            local isQuest = (SealDemonSystem.activeQuestId ~= nil)
            local isDaily = (SealDemonSystem.activeDailyChapter ~= nil)
            SealDemonSystem._applyRewardLocally(isQuest, isDaily)
            EventBus.Emit("save_request")  -- 请求即时存档，持久化本地状态
            return
        end

        local msg = REASON_TEXT[reason] or ("奖励领取失败: " .. reason)
        EventBus.Emit("toast", msg)
        print("[SealDemonSystem] S2C Reward FAIL: " .. reason)
        return
    end

    local rtype = eventData["type"]:GetString()
    local lingYun = eventData["lingYun"]:GetInt()
    local petFood = eventData["petFood"]:GetString()
    local petFoodCount = eventData["petFoodCount"]:GetInt()
    if petFoodCount < 1 then petFoodCount = 1 end
    local player = GameState.player

    if rtype == "quest" then
        local questId = eventData["questId"]:GetString()
        SealDemonSystem.questStates[questId] = "completed"
        SealDemonSystem.activeQuestId = nil

        if player and lingYun > 0 then player:GainLingYun(lingYun) end
        if petFood ~= "" then
            InventorySystem.AddConsumable(petFood, petFoodCount)
        end

        local questDef = SealDemonConfig.QUEST_BY_ID[questId]
        EventBus.Emit("seal_demon_victory", {
            type = "quest", questId = questId,
            questDef = questDef, reward = questDef and questDef.reward or {},
        })
        print("[SealDemonSystem] S2C Reward quest: " .. questId
            .. " lingYun=" .. lingYun)

    elseif rtype == "daily" then
        local dailyChapter = eventData["dailyChapter"]:GetInt()
        SealDemonSystem.activeDailyChapter = nil
        SealDemonSystem.dailyCompletedDate = GetTodayDate()

        if player and lingYun > 0 then player:GainLingYun(lingYun) end
        if petFood ~= "" then
            InventorySystem.AddConsumable(petFood, petFoodCount)
        end

        -- 体魄丹：使用服务端权威值
        if eventData["physiquePill"] then
            local pillGain = eventData["physiquePill"]:GetInt()
            if pillGain > 0 and player then
                local pillTotal = eventData["pillTotal"]:GetInt()
                player.pillPhysique = pillTotal
                print("[SealDemonSystem] physiquePill +" .. pillGain
                    .. " total=" .. pillTotal)
            end
        end

        local daily = SealDemonConfig.DAILY[dailyChapter]
        EventBus.Emit("seal_demon_victory", {
            type = "daily", chapter = dailyChapter,
            dailyDef = daily, reward = daily and daily.reward or {},
        })
        print("[SealDemonSystem] S2C Reward daily: ch=" .. dailyChapter
            .. " lingYun=" .. lingYun)
    end
end

--- S2C_SealDemonAbandonResult 处理
---@param eventType string
---@param eventData table
function SealDemonSystem.HandleAbandonResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    if ok then
        print("[SealDemonSystem] S2C AbandonResult OK")
    else
        print("[SealDemonSystem] S2C AbandonResult FAIL (local already cleaned)")
    end
    -- 本地状态已在 AbandonActiveTask 中提前清理，无需额外操作
end

-- ============================================================================
-- 网络初始化（订阅 S2C 事件）
-- ============================================================================

--- 初始化网络事件订阅（幂等，多次调用安全）
function SealDemonSystem.InitNetwork()
    if SealDemonSystem._networkInited then return end
    SealDemonSystem._networkInited = true

    SubscribeToEvent(SaveProtocol.S2C_SealDemonAcceptResult, function(eventType, eventData)
        SealDemonSystem.HandleAcceptResult(eventType, eventData)
    end)
    SubscribeToEvent(SaveProtocol.S2C_SealDemonReward, function(eventType, eventData)
        SealDemonSystem.HandleReward(eventType, eventData)
    end)
    SubscribeToEvent(SaveProtocol.S2C_SealDemonAbandonResult, function(eventType, eventData)
        SealDemonSystem.HandleAbandonResult(eventType, eventData)
    end)
    print("[SealDemonSystem] Network events subscribed")
end

return SealDemonSystem
