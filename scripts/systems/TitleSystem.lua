-- ============================================================================
-- TitleSystem.lua - 称号系统（数据层）
-- 解锁称号、佩戴展示、属性累加（所有已解锁称号属性叠加生效）
-- ============================================================================

local TitleData = require("config.TitleData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CloudStorage = require("network.CloudStorage")

local TitleSystem = {}

-- 已解锁的称号集合 { [titleId] = true }
TitleSystem.unlocked = {}

-- 当前佩戴的称号 ID（nil = 未佩戴）
TitleSystem.equipped = nil

-- 击杀统计 { [monsterTypeId] = count }
TitleSystem.killStats = {}

-- BOSS 总击杀计数（boss + king_boss + emperor_boss 所有类型累计）
TitleSystem.bossKillTotal = 0

-- 先行者资格标记（排行榜异步查询结果）
TitleSystem.isPioneer = false

--- 初始化
function TitleSystem.Init()
    TitleSystem.unlocked = {}
    TitleSystem.equipped = nil
    TitleSystem.killStats = {}
    TitleSystem.bossKillTotal = 0
    TitleSystem.isPioneer = false

    -- 异步检查先行者资格（排行榜 + 白名单）
    TitleSystem.CheckPioneerEligibility()

    print("[TitleSystem] Initialized")
end

--- 检查先行者资格（纯白名单模式）
--- 只有 PIONEER_WHITELIST 中的 userId 才能获得先行者称号
function TitleSystem.CheckPioneerEligibility()
    local myUserId = CloudStorage.GetUserId()
    if not myUserId then return end

    local myId = tonumber(myUserId)
    for _, uid in ipairs(TitleData.PIONEER_WHITELIST) do
        if tonumber(uid) == myId then
            TitleSystem.isPioneer = true
            TitleSystem.CheckUnlocks()
            print("[TitleSystem] Pioneer confirmed (whitelist): " .. tostring(myUserId))
            return
        end
    end

    print("[TitleSystem] User " .. tostring(myUserId) .. " not in pioneer whitelist")
end

--- 工具方法：一次性从排行榜收集所有用户 ID 并输出到日志
--- 仅供开发时使用，用于收集需要加入白名单的 userId
function TitleSystem.DumpLeaderboardIds()
    if not CloudStorage.GetUserId() then
        print("[TitleSystem] CloudStorage not available")
        return
    end

    local completed = 0
    local totalQueries = 2
    local allUserIds = {}

    local function OnComplete()
        local idList = {}
        for uid, _ in pairs(allUserIds) do
            table.insert(idList, uid)
        end
        table.sort(idList)
        print("[TitleSystem] ====== 排行榜用户 ID 名单 ======")
        print("[TitleSystem] 共 " .. #idList .. " 个用户:")
        for i, uid in ipairs(idList) do
            print("[TitleSystem]   " .. i .. ". " .. tostring(uid) .. ",")
        end
        print("[TitleSystem] ====== 名单结束 ======")
        print("[TitleSystem] 将以上 ID 复制到 TitleData.PIONEER_WHITELIST 即可")
    end

    local function OnQueryDone(rankList)
        if rankList then
            for _, item in ipairs(rankList) do
                allUserIds[item.userId] = true
            end
        end
        completed = completed + 1
        if completed >= totalQueries then
            OnComplete()
        end
    end

    local function OnQueryError()
        completed = completed + 1
        if completed >= totalQueries then
            OnComplete()
        end
    end

    CloudStorage.GetRankList("rank2_score_1", 0, 50, {
        ok = function(rankList) OnQueryDone(rankList) end,
        error = function() OnQueryError() end,
    })
    CloudStorage.GetRankList("rank2_score_2", 0, 50, {
        ok = function(rankList) OnQueryDone(rankList) end,
        error = function() OnQueryError() end,
    })
end

-- ============================================================================
-- 击杀追踪与解锁检查
-- ============================================================================

--- 怪物被击杀时调用（由 GameEvents 的 monster_death 触发）
---@param monster table
function TitleSystem.OnMonsterKilled(monster)
    if not monster or not monster.typeId then return end
    if monster.isSealDemon then return end  -- 封魔BOSS击杀不计入成就

    -- 更新击杀统计（只记录精英和BOSS，普通怪不记录，节省存档空间）
    local typeId = monster.typeId
    local cat = monster.category
    if cat == "elite" or cat == "boss" or cat == "king_boss" or cat == "emperor_boss" then
        TitleSystem.killStats[typeId] = (TitleSystem.killStats[typeId] or 0) + 1
    end

    -- BOSS 总击杀计数：直接使用 GameState.bossKills（与排行榜对齐）

    -- 检查是否有新称号解锁
    TitleSystem.CheckUnlocks()
end

--- 遍历所有称号检查解锁条件
function TitleSystem.CheckUnlocks()
    for _, titleId in ipairs(TitleData.ORDER) do
        if not TitleSystem.unlocked[titleId] then
            local title = TitleData.TITLES[titleId]
            if title and TitleSystem.IsConditionMet(title.condition) then
                TitleSystem.UnlockTitle(titleId)
            end
        end
    end
end

--- 检查单个条件是否满足
---@param condition table
---@return boolean
function TitleSystem.IsConditionMet(condition)
    if not condition then return false end

    if condition.type == "kill" then
        local kills = TitleSystem.killStats[condition.targetType] or 0
        return kills >= (condition.count or 1)
    end

    if condition.type == "kill_all" then
        for _, target in ipairs(condition.targets) do
            local kills = TitleSystem.killStats[target.targetType] or 0
            if kills < (target.count or 1) then
                return false
            end
        end
        return true
    end

    if condition.type == "pioneer" then
        return TitleSystem.isPioneer
    end

    if condition.type == "boss_kill_total" then
        return (GameState.bossKills or 0) >= (condition.count or 1)
    end

    if condition.type == "level" then
        local player = GameState.player
        if not player then return false end
        return player.level >= (condition.level or 1)
    end

    return false
end

--- 获取条件进度文本
---@param condition table
---@return string
function TitleSystem.GetConditionProgress(condition)
    if not condition then return "" end

    if condition.type == "kill" then
        local kills = TitleSystem.killStats[condition.targetType] or 0
        local required = condition.count or 1
        return kills .. "/" .. required
    end

    if condition.type == "kill_all" then
        local done = 0
        local total = #condition.targets
        for _, target in ipairs(condition.targets) do
            local kills = TitleSystem.killStats[target.targetType] or 0
            if kills >= (target.count or 1) then
                done = done + 1
            end
        end
        return done .. "/" .. total
    end

    if condition.type == "pioneer" then
        return TitleSystem.isPioneer and "已认证" or "未认证"
    end

    if condition.type == "boss_kill_total" then
        local required = condition.count or 1
        return math.min(GameState.bossKills or 0, required) .. "/" .. required
    end

    if condition.type == "level" then
        local player = GameState.player
        local curLevel = player and player.level or 0
        local required = condition.level or 1
        return math.min(curLevel, required) .. "/" .. required
    end

    return "0/1"
end

--- 解锁称号
---@param titleId string
function TitleSystem.UnlockTitle(titleId)
    if TitleSystem.unlocked[titleId] then return end

    TitleSystem.unlocked[titleId] = true
    TitleSystem.RecalcBonuses()

    local title = TitleData.TITLES[titleId]
    local titleName = title and title.name or titleId

    EventBus.Emit("title_unlocked", titleId)

    -- 浮动文字提示
    local player = GameState.player
    if player then
        local CombatSystem = require("systems.CombatSystem")
        local color = title and title.color or {255, 255, 200, 255}
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "称号解锁: " .. titleName, color, 3.0
        )
    end

    print("[TitleSystem] Unlocked: " .. titleName)
end

-- ============================================================================
-- 佩戴管理
-- ============================================================================

--- 佩戴称号
---@param titleId string|nil nil 表示取消佩戴
---@return boolean success
---@return string message
function TitleSystem.Equip(titleId)
    if titleId and not TitleSystem.unlocked[titleId] then
        return false, "称号未解锁"
    end

    local oldId = TitleSystem.equipped
    TitleSystem.equipped = titleId

    EventBus.Emit("title_changed", oldId, titleId)

    if titleId then
        local title = TitleData.TITLES[titleId]
        print("[TitleSystem] Equipped: " .. (title and title.name or titleId))
        return true, "已佩戴"
    else
        print("[TitleSystem] Unequipped title")
        return true, "已取消佩戴"
    end
end

--- 获取当前佩戴的称号数据
---@return table|nil
function TitleSystem.GetEquipped()
    if not TitleSystem.equipped then return nil end
    return TitleData.TITLES[TitleSystem.equipped]
end

--- 获取当前佩戴的称号 ID
---@return string|nil
function TitleSystem.GetEquippedId()
    return TitleSystem.equipped
end

-- ============================================================================
-- 属性累加（所有已解锁称号属性叠加）
-- ============================================================================

--- 重新计算称号总加成并应用到玩家
function TitleSystem.RecalcBonuses()
    local player = GameState.player
    if not player then return end

    local totalAtk = 0
    local totalCritRate = 0
    local totalHeavyHit = 0
    local totalKillHeal = 0
    local totalExpBonus = 0
    local totalAtkBonus = 0

    for titleId, _ in pairs(TitleSystem.unlocked) do
        local title = TitleData.TITLES[titleId]
        if title and title.bonus then
            totalAtk = totalAtk + (title.bonus.atk or 0)
            totalCritRate = totalCritRate + (title.bonus.critRate or 0)
            totalHeavyHit = totalHeavyHit + (title.bonus.heavyHit or 0)
            totalKillHeal = totalKillHeal + (title.bonus.killHeal or 0)
            totalExpBonus = totalExpBonus + (title.bonus.expBonus or 0)
            totalAtkBonus = totalAtkBonus + (title.bonus.atkBonus or 0)
        end
    end

    player.titleAtk = totalAtk
    player.titleCritRate = totalCritRate
    player.titleHeavyHit = totalHeavyHit
    player.titleKillHeal = totalKillHeal
    player.titleExpBonus = totalExpBonus
    player.titleAtkBonus = totalAtkBonus

    EventBus.Emit("title_stats_changed")
end

--- 获取称号总加成属性（用于 UI 显示）
---@return table
function TitleSystem.GetBonusSummary()
    local player = GameState.player
    if not player then
        return { atk = 0, critRate = 0, heavyHit = 0, killHeal = 0, expBonus = 0, atkBonus = 0 }
    end
    return {
        atk = player.titleAtk or 0,
        critRate = player.titleCritRate or 0,
        heavyHit = player.titleHeavyHit or 0,
        killHeal = player.titleKillHeal or 0,
        expBonus = player.titleExpBonus or 0,
        atkBonus = player.titleAtkBonus or 0,
    }
end

--- 获取已解锁数量
---@return number
function TitleSystem.GetUnlockedCount()
    local count = 0
    for _ in pairs(TitleSystem.unlocked) do
        count = count + 1
    end
    return count
end

--- 获取总数量
---@return number
function TitleSystem.GetTotalCount()
    return #TitleData.ORDER
end

-- ============================================================================
-- 序列化（存档用）
-- ============================================================================

--- 序列化
---@return table
function TitleSystem.Serialize()
    local unlockedList = {}
    for titleId, _ in pairs(TitleSystem.unlocked) do
        table.insert(unlockedList, titleId)
    end
    return {
        unlocked = unlockedList,
        equipped = TitleSystem.equipped,
        killStats = TitleSystem.killStats,
        bossKillTotal = GameState.bossKills or 0,  -- 兼容旧存档读取
    }
end

--- 反序列化
---@param data table
function TitleSystem.Deserialize(data)
    TitleSystem.unlocked = {}
    TitleSystem.equipped = nil
    TitleSystem.killStats = {}
    TitleSystem.bossKillTotal = 0

    if not data or type(data) ~= "table" then
        return
    end

    -- 恢复已解锁称号
    if data.unlocked and type(data.unlocked) == "table" then
        for _, titleId in ipairs(data.unlocked) do
            TitleSystem.unlocked[titleId] = true
        end
    end

    -- 恢复佩戴状态（校验是否仍然解锁）
    if data.equipped and TitleSystem.unlocked[data.equipped] then
        TitleSystem.equipped = data.equipped
    end

    -- 恢复击杀统计（过滤掉旧存档中的普通怪条目，只保留精英和BOSS）
    if data.killStats and type(data.killStats) == "table" then
        local MonsterData = require("config.MonsterData")
        local kept, dropped = 0, 0
        for typeId, count in pairs(data.killStats) do
            local mdata = MonsterData.Types[typeId]
            local cat = mdata and mdata.category
            if cat == "elite" or cat == "boss" or cat == "king_boss" or cat == "emperor_boss" then
                TitleSystem.killStats[typeId] = count
                kept = kept + 1
            else
                dropped = dropped + 1
            end
        end
        if dropped > 0 then
            print("[TitleSystem] killStats cleanup: kept=" .. kept .. " dropped=" .. dropped .. " normal entries")
        end
    end

    -- 旧存档迁移：如果 GameState.bossKills 为 0 但旧存档有 bossKillTotal，则迁移
    if (GameState.bossKills or 0) == 0 and (data.bossKillTotal or 0) > 0 then
        GameState.bossKills = data.bossKillTotal
        print("[TitleSystem] Migrated bossKillTotal -> GameState.bossKills: " .. GameState.bossKills)
    end

    -- 🔴 修复：Deserialize 清空了 Init 阶段通过白名单解锁的称号
    -- 必须重新检查解锁条件，让 isPioneer=true 的用户重新获得先行者称号
    TitleSystem.CheckUnlocks()

    TitleSystem.RecalcBonuses()
    print("[TitleSystem] Restored " .. TitleSystem.GetUnlockedCount() .. " titles")
end

return TitleSystem
