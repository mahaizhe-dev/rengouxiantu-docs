-- ============================================================================
-- LiangjieStoneSystem.lua - 两界阵石养成与规范存档
-- 阵石等级档案是唯一真值；激活/升级采用立即保存，失败时完整回滚。
-- ============================================================================

local LiangjieStoneConfig = require("config.LiangjieStoneConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")
local SaveState = require("systems.save.SaveState")
local SaveSerializer = require("systems.save.SaveSerializer")

local LiangjieStoneSystem = {}

LiangjieStoneSystem.INTERACT_TYPE = "liangjie_stone"
LiangjieStoneSystem.VERSION = 1
LiangjieStoneSystem.stones = {}
LiangjieStoneSystem._initialized = false

local busy_ = false

local PLAYER_SNAPSHOT_FIELDS = {
    "level", "exp", "maxHp", "atk", "def", "hpRegen", "hp", "realm", "alive",
    "liangjieStoneAtk", "liangjieStoneDef", "liangjieStoneMaxHp", "liangjieStoneHpRegen",
}

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return out
end

local function NormalizeLevel(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.max(0, math.min(LiangjieStoneConfig.MAX_LEVEL, math.floor(value)))
end

local function IsValidStoneId(stoneId)
    return type(stoneId) == "string" and LiangjieStoneConfig.STONES[stoneId] ~= nil
end

local function GetPlayerSnapshot(player)
    local snapshot = {}
    if not player then return snapshot end
    for _, field in ipairs(PLAYER_SNAPSHOT_FIELDS) do
        snapshot[field] = DeepCopy(player[field])
    end
    return snapshot
end

local function RestorePlayerSnapshot(player, snapshot)
    if not player or not snapshot then return end
    for _, field in ipairs(PLAYER_SNAPSHOT_FIELDS) do
        player[field] = DeepCopy(snapshot[field])
    end
    if player.InvalidateStatsCache then
        player:InvalidateStatsCache()
    else
        player._statsCacheFrame = -1
    end
    EventBus.Emit("player_exp_gain", 0)
end

local function GetTitleSnapshot()
    if not SaveSerializer.SerializeTitles then return nil end
    local ok, data = pcall(SaveSerializer.SerializeTitles)
    return ok and DeepCopy(data) or nil
end

local function RestoreTitleSnapshot(snapshot)
    if not snapshot or not SaveSerializer.DeserializeTitles then return end
    pcall(SaveSerializer.DeserializeTitles, DeepCopy(snapshot))
end

local function GetSkillSnapshot()
    local ok, SkillSystem = pcall(require, "systems.SkillSystem")
    if not ok or not SkillSystem then return nil end
    return {
        unlockedSkills = DeepCopy(SkillSystem.unlockedSkills),
        equippedSkills = DeepCopy(SkillSystem.equippedSkills),
    }
end

local function RestoreSkillSnapshot(snapshot)
    if not snapshot then return end
    local ok, SkillSystem = pcall(require, "systems.SkillSystem")
    if not ok or not SkillSystem then return end
    SkillSystem.unlockedSkills = DeepCopy(snapshot.unlockedSkills) or {}
    SkillSystem.equippedSkills = DeepCopy(snapshot.equippedSkills) or {}
end

local function MakeSnapshot()
    return {
        stones = DeepCopy(LiangjieStoneSystem.stones),
        inventory = DeepCopy(SaveSerializer.SerializeInventory()),
        player = GetPlayerSnapshot(GameState.player),
        titles = GetTitleSnapshot(),
        skills = GetSkillSnapshot(),
    }
end

local function RestoreSnapshot(snapshot)
    LiangjieStoneSystem.stones = DeepCopy(snapshot.stones) or {}
    SaveSerializer.DeserializeInventory(snapshot.inventory)
    RestorePlayerSnapshot(GameState.player, snapshot.player)
    RestoreTitleSnapshot(snapshot.titles)
    RestoreSkillSnapshot(snapshot.skills)
    LiangjieStoneSystem.ApplyAllBonuses()
end

local function GetSaveBlockReason()
    if not SaveState.loaded then return "存档尚未加载，暂时不能操作阵石" end
    if not SaveState.activeSlot then return "当前没有激活的角色存档" end
    if SaveState.saving then return "正在保存，请稍后再试" end
    if SaveState._retryTimer then return "存档正在等待重试，请稍后再试" end
    if SaveState._disconnected then return "网络断开，无法安全保存阵石进度" end
    return nil
end

local function FinishSavedOperation(
    snapshot,
    eventName,
    eventArgs,
    successMessage,
    callback,
    resultData)
    local SaveSystem = require("systems.SaveSystem")
    local callbackCalled = false

    local function finish(ok, reason)
        if callbackCalled then return end
        callbackCalled = true
        busy_ = false
        if ok then
            EventBus.Emit(eventName, table.unpack(eventArgs or {}))
            if callback then callback(true, successMessage, resultData) end
        else
            RestoreSnapshot(snapshot)
            local message = "保存失败，阵石操作已回滚：" .. tostring(reason or "unknown")
            if callback then callback(false, message, nil) end
        end
    end

    local ok, err = pcall(function()
        SaveSystem.Save(finish)
    end)
    if not ok then
        finish(false, err)
    end
end

function LiangjieStoneSystem.Init()
    if LiangjieStoneSystem._initialized then return end
    LiangjieStoneSystem._initialized = true
    LiangjieStoneSystem.stones = {}
    for _, stoneId in ipairs(LiangjieStoneConfig.STONE_ORDER) do
        LiangjieStoneSystem.stones[stoneId] = {
            activated = false,
            level = 0,
            activationRewardClaimed = false,
        }
    end
end

function LiangjieStoneSystem.EnsureInit()
    if not LiangjieStoneSystem._initialized then
        LiangjieStoneSystem.Init()
    end
end

function LiangjieStoneSystem.Reset()
    busy_ = false
    LiangjieStoneSystem._initialized = false
    LiangjieStoneSystem.Init()
    LiangjieStoneSystem.ApplyAllBonuses()
end

---@param stoneId string
---@return table|nil
function LiangjieStoneSystem.GetStoneState(stoneId)
    LiangjieStoneSystem.EnsureInit()
    return LiangjieStoneSystem.stones[stoneId]
end

---@param stoneId string
---@return boolean
function LiangjieStoneSystem.IsActivated(stoneId)
    local state = LiangjieStoneSystem.GetStoneState(stoneId)
    return state and state.activated == true or false
end

---@param stoneId string
---@return number
function LiangjieStoneSystem.GetLevel(stoneId)
    local state = LiangjieStoneSystem.GetStoneState(stoneId)
    return state and state.level or 0
end

---@param stoneId string
---@return boolean
function LiangjieStoneSystem.IsMaxLevel(stoneId)
    return LiangjieStoneSystem.GetLevel(stoneId) >= LiangjieStoneConfig.MAX_LEVEL
end

function LiangjieStoneSystem.IsBusy()
    return busy_
end

---@param stoneId string
---@return string
function LiangjieStoneSystem.GetNameplateText(stoneId)
    local state = LiangjieStoneSystem.GetStoneState(stoneId)
    if not state or not state.activated then return "未激活" end
    if state.level >= LiangjieStoneConfig.MAX_LEVEL then return "MAX" end
    return "Lv." .. tostring(state.level)
end

---@param stoneId string
---@return boolean
---@return string|nil
function LiangjieStoneSystem.CanActivate(stoneId)
    LiangjieStoneSystem.EnsureInit()
    if not IsValidStoneId(stoneId) then return false, "未知阵石" end
    if busy_ then return false, "阵石操作正在保存" end

    local state = LiangjieStoneSystem.stones[stoneId]
    if state.activated then return false, "阵石已经激活" end
    local saveBlock = GetSaveBlockReason()
    if saveBlock then return false, saveBlock end

    local count = InventorySystem.CountUnlockedConsumable(LiangjieStoneConfig.CURRENCY_ID)
    if count < LiangjieStoneConfig.ACTIVATION_COST then
        return false, LiangjieStoneConfig.CURRENCY_NAME .. "不足（需要"
            .. LiangjieStoneConfig.ACTIVATION_COST .. "，当前" .. count .. "）"
    end
    return true, nil
end

---@param stoneId string
---@return boolean
---@return string|nil
function LiangjieStoneSystem.CanUpgrade(stoneId)
    LiangjieStoneSystem.EnsureInit()
    if not IsValidStoneId(stoneId) then return false, "未知阵石" end
    if busy_ then return false, "阵石操作正在保存" end

    local state = LiangjieStoneSystem.stones[stoneId]
    if not state.activated then return false, "阵石尚未激活" end
    if state.level >= LiangjieStoneConfig.MAX_LEVEL then return false, "阵石已满级" end
    local saveBlock = GetSaveBlockReason()
    if saveBlock then return false, saveBlock end

    local cost = LiangjieStoneConfig.GetUpgradeCost(state.level + 1)
    local count = InventorySystem.CountUnlockedConsumable(LiangjieStoneConfig.CURRENCY_ID)
    if count < cost then
        return false, LiangjieStoneConfig.CURRENCY_NAME .. "不足（需要"
            .. cost .. "，当前" .. count .. "）"
    end
    return true, nil
end

---@param stoneId string
---@param callback fun(success: boolean, message: string, details: table|nil)|nil
---@return boolean started
---@return string message
function LiangjieStoneSystem.Activate(stoneId, callback)
    local canActivate, reason = LiangjieStoneSystem.CanActivate(stoneId)
    if not canActivate then return false, reason or "无法激活" end

    local player = GameState.player
    if not player or not player.GainExp then return false, "角色数据异常" end

    local snapshot = MakeSnapshot()
    busy_ = true
    local consumed = InventorySystem.ConsumeConsumable(
        LiangjieStoneConfig.CURRENCY_ID,
        LiangjieStoneConfig.ACTIVATION_COST)
    if not consumed then
        busy_ = false
        return false, LiangjieStoneConfig.CURRENCY_NAME .. "扣除失败（可能被锁定）"
    end

    local state = LiangjieStoneSystem.stones[stoneId]
    state.activated = true
    state.level = 0
    state.activationRewardClaimed = true
    local expBefore = player.exp or 0
    local levelBefore = player.level or 1
    player:GainExp(LiangjieStoneConfig.ACTIVATION_EXP_REWARD)
    local expAfter = player.exp or expBefore
    local levelAfter = player.level or levelBefore
    local activationResult = {
        configuredExp = LiangjieStoneConfig.ACTIVATION_EXP_REWARD,
        actualExp = math.max(0, expAfter - expBefore),
        expBefore = expBefore,
        expAfter = expAfter,
        levelBefore = levelBefore,
        levelAfter = levelAfter,
    }
    LiangjieStoneSystem.ApplyAllBonuses()

    local cfg = LiangjieStoneConfig.STONES[stoneId]
    local message = cfg.name .. "已激活，经验+"
        .. activationResult.actualExp
    FinishSavedOperation(
        snapshot,
        "liangjie_stone_activated",
        { stoneId },
        message,
        callback,
        activationResult)
    return true, "阵石激活保存中"
end

---@param stoneId string
---@param callback fun(success: boolean, message: string)|nil
---@return boolean started
---@return string message
function LiangjieStoneSystem.Upgrade(stoneId, callback)
    local canUpgrade, reason = LiangjieStoneSystem.CanUpgrade(stoneId)
    if not canUpgrade then return false, reason or "无法升级" end

    local state = LiangjieStoneSystem.stones[stoneId]
    local nextLevel = state.level + 1
    local cost = LiangjieStoneConfig.GetUpgradeCost(nextLevel)
    local snapshot = MakeSnapshot()
    busy_ = true

    local consumed = InventorySystem.ConsumeConsumable(LiangjieStoneConfig.CURRENCY_ID, cost)
    if not consumed then
        busy_ = false
        return false, LiangjieStoneConfig.CURRENCY_NAME .. "扣除失败（可能被锁定）"
    end

    state.level = nextLevel
    LiangjieStoneSystem.ApplyAllBonuses()

    local cfg = LiangjieStoneConfig.STONES[stoneId]
    local message = cfg.name .. "升至Lv." .. nextLevel
        .. "，" .. cfg.bonusLabel .. "+" .. cfg.bonusPerLevel
    FinishSavedOperation(
        snapshot,
        "liangjie_stone_upgraded",
        { stoneId, nextLevel },
        message,
        callback)
    return true, "阵石升级保存中"
end

---@return table
function LiangjieStoneSystem.GetAllBonuses()
    LiangjieStoneSystem.EnsureInit()
    local bonuses = { atk = 0, def = 0, maxHp = 0, hpRegen = 0 }
    for _, stoneId in ipairs(LiangjieStoneConfig.STONE_ORDER) do
        local state = LiangjieStoneSystem.stones[stoneId]
        local cfg = LiangjieStoneConfig.STONES[stoneId]
        if state and state.activated and state.level > 0 then
            bonuses[cfg.bonusStat] = bonuses[cfg.bonusStat]
                + cfg.bonusPerLevel * state.level
        end
    end
    return bonuses
end

function LiangjieStoneSystem.ApplyAllBonuses()
    local player = GameState.player
    if not player then return end
    local bonuses = LiangjieStoneSystem.GetAllBonuses()
    player.liangjieStoneAtk = bonuses.atk
    player.liangjieStoneDef = bonuses.def
    player.liangjieStoneMaxHp = bonuses.maxHp
    player.liangjieStoneHpRegen = bonuses.hpRegen
    if player.InvalidateStatsCache then
        player:InvalidateStatsCache()
    else
        player._statsCacheFrame = -1
    end
end

---@return table
function LiangjieStoneSystem.Serialize()
    LiangjieStoneSystem.EnsureInit()
    local stones = {}
    for _, stoneId in ipairs(LiangjieStoneConfig.STONE_ORDER) do
        local state = LiangjieStoneSystem.stones[stoneId]
        stones[stoneId] = {
            activated = state.activated == true,
            level = state.activated and NormalizeLevel(state.level) or 0,
            activationRewardClaimed = state.activated
                and state.activationRewardClaimed == true or false,
        }
    end
    return {
        version = LiangjieStoneSystem.VERSION,
        stones = stones,
    }
end

---@param data table|nil
function LiangjieStoneSystem.Deserialize(data)
    busy_ = false
    LiangjieStoneSystem._initialized = false
    LiangjieStoneSystem.Init()

    local savedStones = type(data) == "table" and data.stones or nil
    if type(savedStones) ~= "table" and type(data) == "table" then
        savedStones = data
    end

    if type(savedStones) == "table" then
        for _, stoneId in ipairs(LiangjieStoneConfig.STONE_ORDER) do
            local saved = savedStones[stoneId]
            if type(saved) == "table" then
                local activated = saved.activated == true
                local state = LiangjieStoneSystem.stones[stoneId]
                state.activated = activated
                state.level = activated and NormalizeLevel(saved.level) or 0
                -- 已激活旧档缺少标记时视为已领奖，避免补发一次性经验。
                state.activationRewardClaimed = activated
            end
        end
    end

    LiangjieStoneSystem.ApplyAllBonuses()
end

return LiangjieStoneSystem
