-- ============================================================================
-- SwordPoolSystem.lua - 祀剑池核心系统
-- 管理解锁/升级/属性加成/存档
-- 解锁时移除BOSS房间封印，升级提供永久属性加成
-- ============================================================================

local SwordPoolConfig = require("config.SwordPoolConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")

local SwordPoolSystem = {}

-- ── 状态 ──
-- swords[swordId] = { unlocked = bool, level = 0~10 }
SwordPoolSystem.swords = {}
SwordPoolSystem._initialized = false

local function NormalizeLevel(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.max(0, math.min(SwordPoolConfig.MAX_LEVEL, math.floor(value)))
end

--- 初始化（幂等）
function SwordPoolSystem.Init()
    if SwordPoolSystem._initialized then return end
    SwordPoolSystem._initialized = true
    SwordPoolSystem.swords = {}
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        SwordPoolSystem.swords[id] = {
            unlocked = false,
            level = 0,
        }
    end
end

--- 确保已初始化
function SwordPoolSystem.EnsureInit()
    if not SwordPoolSystem._initialized then
        SwordPoolSystem.Init()
    end
end

-- ============================================================================
-- 查询
-- ============================================================================

--- 获取某剑状态
---@param swordId string
---@return table|nil { unlocked, level }
function SwordPoolSystem.GetSwordState(swordId)
    SwordPoolSystem.EnsureInit()
    return SwordPoolSystem.swords[swordId]
end

--- 是否已解锁
---@param swordId string
---@return boolean
function SwordPoolSystem.IsUnlocked(swordId)
    local state = SwordPoolSystem.swords[swordId]
    return state and state.unlocked or false
end

--- 获取等级
---@param swordId string
---@return number
function SwordPoolSystem.GetLevel(swordId)
    local state = SwordPoolSystem.swords[swordId]
    return state and state.level or 0
end

--- 是否满级
---@param swordId string
---@return boolean
function SwordPoolSystem.IsMaxLevel(swordId)
    return SwordPoolSystem.GetLevel(swordId) >= SwordPoolConfig.MAX_LEVEL
end

--- 能否解锁（未解锁且剑令够）
---@param swordId string
---@return boolean canUnlock
---@return string|nil reason
function SwordPoolSystem.CanUnlock(swordId)
    local state = SwordPoolSystem.swords[swordId]
    if not state then return false, "未知仙剑" end
    if state.unlocked then return false, "已解锁" end
    local count = InventorySystem.CountUnlockedConsumable(SwordPoolConfig.CURRENCY_ID)
    if count < SwordPoolConfig.UNLOCK_COST then
        return false, SwordPoolConfig.CURRENCY_NAME .. "不足（需要" .. SwordPoolConfig.UNLOCK_COST .. "，当前" .. count .. "）"
    end
    return true, nil
end

--- 能否升级（已解锁且未满级且剑令够）
---@param swordId string
---@return boolean canUpgrade
---@return string|nil reason
function SwordPoolSystem.CanUpgrade(swordId)
    local state = SwordPoolSystem.swords[swordId]
    if not state then return false, "未知仙剑" end
    if not state.unlocked then return false, "尚未解锁" end
    if state.level >= SwordPoolConfig.MAX_LEVEL then return false, "已满级" end
    local nextLevel = state.level + 1
    local cost = SwordPoolConfig.GetUpgradeCost(nextLevel)
    if not cost then return false, "配置错误" end
    local count = InventorySystem.CountUnlockedConsumable(SwordPoolConfig.CURRENCY_ID)
    if count < cost then
        return false, SwordPoolConfig.CURRENCY_NAME .. "不足（需要" .. cost .. "，当前" .. count .. "）"
    end
    return true, nil
end

-- ============================================================================
-- 操作
-- ============================================================================

--- 解锁仙剑（消耗剑令 + 移除封印）
---@param swordId string
---@return boolean success
---@return string|nil msg
function SwordPoolSystem.Unlock(swordId)
    local canUnlock, reason = SwordPoolSystem.CanUnlock(swordId)
    if not canUnlock then return false, reason end

    local ok = InventorySystem.ConsumeConsumable(SwordPoolConfig.CURRENCY_ID, SwordPoolConfig.UNLOCK_COST)
    if not ok then return false, "剑令扣除失败（可能被锁定）" end
    SwordPoolSystem.swords[swordId].unlocked = true
    SwordPoolSystem.swords[swordId].level = 0

    -- 移除BOSS房间封印（同时更新 sealStates_ 防止 ApplySeals 刷回）
    local cfg = SwordPoolConfig.SWORDS[swordId]
    if cfg and cfg.sealId then
        local QuestSystem = require("systems.QuestSystem")
        local gameMap = GameState.gameMap
        QuestSystem.ForceUnseal(gameMap, cfg.sealId)
    end

    print("[SwordPool] 解锁: " .. cfg.name)
    EventBus.Emit("sword_pool_unlocked", swordId)
    EventBus.Emit("save_request")
    return true, cfg.name .. "封印已解除！BOSS房间已开放！"
end

--- 升级仙剑
---@param swordId string
---@return boolean success
---@return string|nil msg
function SwordPoolSystem.Upgrade(swordId)
    local canUpgrade, reason = SwordPoolSystem.CanUpgrade(swordId)
    if not canUpgrade then return false, reason end

    local state = SwordPoolSystem.swords[swordId]
    local nextLevel = state.level + 1
    local cost = SwordPoolConfig.GetUpgradeCost(nextLevel)

    local ok = InventorySystem.ConsumeConsumable(SwordPoolConfig.CURRENCY_ID, cost)
    if not ok then return false, "剑令扣除失败（可能被锁定）" end
    state.level = nextLevel

    -- 应用属性加成
    SwordPoolSystem.ApplyAllBonuses()

    local cfg = SwordPoolConfig.SWORDS[swordId]
    local bonus = cfg.bonusPerLevel
    local msg = cfg.name .. " 升至" .. nextLevel .. "级！" .. cfg.bonusLabel .. "+" .. bonus
    print("[SwordPool] 升级: " .. msg)
    EventBus.Emit("sword_pool_upgraded", swordId, nextLevel)
    EventBus.Emit("save_request")
    return true, msg
end

-- ============================================================================
-- 属性加成
-- ============================================================================

--- 计算所有仙剑提供的属性加成总和
---@return table { atk=N, def=N, maxHp=N, hpRegen=N }
function SwordPoolSystem.GetAllBonuses()
    SwordPoolSystem.EnsureInit()
    local bonuses = { atk = 0, def = 0, maxHp = 0, hpRegen = 0 }
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        local state = SwordPoolSystem.swords[id]
        local cfg = SwordPoolConfig.SWORDS[id]
        if state and cfg and state.level > 0 then
            local stat = cfg.bonusStat
            bonuses[stat] = bonuses[stat] + (cfg.bonusPerLevel * state.level)
        end
    end
    return bonuses
end

--- 将祀剑池加成写入 GameState.player
function SwordPoolSystem.ApplyAllBonuses()
    local player = GameState.player
    if not player then return end
    local bonuses = SwordPoolSystem.GetAllBonuses()
    player.swordPoolAtk = bonuses.atk
    player.swordPoolDef = bonuses.def
    player.swordPoolMaxHp = bonuses.maxHp
    player.swordPoolHpRegen = bonuses.hpRegen

    player:InvalidateStatsCache()
end

-- ============================================================================
-- 存档
-- ============================================================================

--- 序列化
---@return table
function SwordPoolSystem.Serialize()
    SwordPoolSystem.EnsureInit()
    local data = {}
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        local state = SwordPoolSystem.swords[id]
        if state then
            data[id] = {
                unlocked = state.unlocked,
                level = state.level,
            }
        end
    end
    return data
end

--- 反序列化
---@param data table|nil
function SwordPoolSystem.Deserialize(data)
    SwordPoolSystem._initialized = false
    SwordPoolSystem.Init()

    if type(data) == "table" then
        for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
            local saved = data[id]
            if type(saved) == "table" then
                local unlocked = saved.unlocked == true
                SwordPoolSystem.swords[id].unlocked = unlocked
                SwordPoolSystem.swords[id].level = unlocked and NormalizeLevel(saved.level) or 0
            end
        end
    end

    -- 四剑等级档案是唯一真值；缺档时也要覆盖历史派生属性。
    SwordPoolSystem.ApplyAllBonuses()
end

--- 反序列化后恢复封印状态（地图加载后调用）
--- 已解锁的BOSS房间需要重新移除封印瓦片
function SwordPoolSystem.RestoreSeals()
    local QuestSystem = require("systems.QuestSystem")
    local gameMap = GameState.gameMap

    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        local state = SwordPoolSystem.swords[id]
        local cfg = SwordPoolConfig.SWORDS[id]
        if state and state.unlocked and cfg and cfg.sealId then
            QuestSystem.ForceUnseal(gameMap, cfg.sealId)
        end
    end
end

return SwordPoolSystem
