-- ============================================================================
-- AscensionSystem.lua - 仙阶突破系统
-- ============================================================================
-- 职责：仙阶进度管理、吃丹、大/小阶判断、突破结算、序列化
-- 关联：AscensionConfig.lua, TribulationSystem.lua, ImmortalBodySystem.lua

local GameState       = require("core.GameState")
local EventBus        = require("core.EventBus")
local GameConfig      = require("config.GameConfig")
local AscensionConfig = require("config.AscensionConfig")
local InventorySystem = require("systems.InventorySystem")

local AscensionSystem = {}

-- ── 运行时状态（存档恢复后填充） ─────────────────────────────────────────────
local state = {
    stageIndex       = 0,   -- 当前大仙阶序 (0=未进入仙阶)
    minorIndex       = 0,   -- 当前小阶 (1-9)
    totalIndex       = 0,   -- 仙阶总序 (1-81, 0=未进入)
    progress         = 0,   -- 当前目标进度
    lastGain         = 0,   -- 最近一次吃丹进度
    lastCritType     = "normal",
    firstTribulationCompleted = false,
}

-- ============================================================================
-- 初始化
-- ============================================================================

function AscensionSystem.Init()
    state = {
        stageIndex = 0,
        minorIndex = 0,
        totalIndex = 0,
        progress = 0,
        lastGain = 0,
        lastCritType = "normal",
        firstTribulationCompleted = false,
    }
    -- 延迟注册仙阶假 realm（避免模块加载时循环依赖）
    AscensionConfig.EnsureRealmsRegistered()
end

function AscensionSystem.GetState()
    return state
end

-- ============================================================================
-- 查询
-- ============================================================================

--- 是否已启用仙阶系统（玩家达到大乘巅峰 Lv120）
function AscensionSystem.IsEnabled()
    if not AscensionConfig.FEATURE_ENABLED then return false end
    local player = GameState.player
    if not player then return false end
    -- 纯用玩家数据判断（不依赖模块 state，避免多角色切换时 state 残留）
    local realmData = GameConfig.REALMS[player.realm]
    local order = realmData and realmData.order or 0
    return order >= 22 and player.level >= 120  -- dacheng_4 order=22，及以上
end

--- 是否可见（大乘初期起显示 tab，但不一定可操作）
function AscensionSystem.IsVisible()
    if not AscensionConfig.FEATURE_ENABLED then return false end
    local player = GameState.player
    if not player then return false end
    -- 大乘初期 order=19
    local realmData = GameConfig.REALMS[player.realm]
    local order = realmData and realmData.order or 0
    return order >= 19 or state.totalIndex > 0
end

--- 获取当前目标仙阶信息
---@return table|nil 目标仙阶配置（AscensionConfig.ASCENSION_REWARDS[targetIndex]）
function AscensionSystem.GetTargetInfo()
    local targetIndex = state.totalIndex + 1
    return AscensionConfig.ASCENSION_REWARDS[targetIndex]
end

--- 获取当前目标所需进度
function AscensionSystem.GetRequiredProgress()
    local target = AscensionSystem.GetTargetInfo()
    if not target then return 0 end
    if target.isMajor then
        return AscensionConfig.MAJOR_PROGRESS_REQUIRED
    else
        return AscensionConfig.MINOR_PROGRESS_REQUIRED
    end
end

--- 获取当前使用的材料 ID
function AscensionSystem.GetCurrentMaterial()
    -- 谪仙（大仙阶1, totalIndex 1-9）：一转仙劫丹
    -- 人仙及以后（大仙阶2+, totalIndex 10+）：二转仙劫丹
    local stageIdx = math.ceil(math.max(state.totalIndex + 1, 1) / 9)  -- 目标大仙阶序号 1-9
    if stageIdx <= 1 then
        return AscensionConfig.ITEM_ONE_TURN_PILL
    else
        return AscensionConfig.ITEM_TWO_TURN_PILL
    end
end

--- 进度是否已满
function AscensionSystem.IsProgressFull()
    return state.progress >= AscensionSystem.GetRequiredProgress()
end

--- 获取当前显示名
function AscensionSystem.GetCurrentStageName()
    if state.totalIndex == 0 then return "大乘巅峰" end
    local info = AscensionConfig.ASCENSION_REWARDS[state.totalIndex]
    return info and info.displayName or "未知"
end

--- 获取目标显示名
function AscensionSystem.GetTargetStageName()
    local target = AscensionSystem.GetTargetInfo()
    return target and target.displayName or "未知"
end

-- ============================================================================
-- 吃丹（消耗仙劫丹增加进度）
-- ============================================================================

--- 随机进度
---@return number gain, string critType
function AscensionSystem._RollGain()
    local table = AscensionConfig.PILL_GAIN_TABLE
    local totalWeight = AscensionConfig.PILL_GAIN_TOTAL_WEIGHT
    local roll = math.random(1, totalWeight)
    local cumulative = 0
    for _, entry in ipairs(table) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.gain, entry.type
        end
    end
    return 1, "normal"
end

--- 消耗一颗仙劫丹
---@return boolean success
---@return string msg
function AscensionSystem.ConsumePill()
    if not AscensionSystem.IsEnabled() then
        return false, "未达到仙阶突破条件"
    end

    local req = AscensionSystem.GetRequiredProgress()
    if state.progress >= req then
        return false, "进度已满，请前往突破"
    end

    local materialId = AscensionSystem.GetCurrentMaterial()
    if InventorySystem.CountConsumable(materialId) <= 0 then
        local name = GameConfig.PET_MATERIALS[materialId] and GameConfig.PET_MATERIALS[materialId].name or materialId
        return false, name .. "不足"
    end

    -- 消耗
    local ok = InventorySystem.ConsumeConsumable(materialId, 1)
    if not ok then return false, "消耗失败" end

    -- 随机进度
    local gain, critType = AscensionSystem._RollGain()
    local maxProgress = req + AscensionConfig.PROGRESS_OVERFLOW_MAX
    state.progress = math.min(state.progress + gain, maxProgress)
    state.lastGain = gain
    state.lastCritType = critType

    EventBus.Emit("ascension_pill_consumed", gain, critType, state.progress, req)
    -- 不在此处 save_request（高频操作），由面板关闭时统一保存

    print(string.format("[AscensionSystem] Pill consumed: +%d (%s), progress=%d/%d",
        gain, critType, state.progress, req))
    return true, critType
end

-- ============================================================================
-- 突破结算
-- ============================================================================

--- 小境界突破（进度满后直接成功）
---@return boolean success
---@return string msg
function AscensionSystem.BreakthroughMinor()
    if not AscensionSystem.IsProgressFull() then
        return false, "进度不足"
    end

    local target = AscensionSystem.GetTargetInfo()
    if not target then return false, "已达最高仙阶" end
    if target.isMajor then return false, "大仙阶需要渡劫" end

    -- 推进仙阶
    AscensionSystem._AdvanceToIndex(target.totalIndex)

    -- 发放属性
    AscensionSystem._ApplyRewards(target.rewards)

    -- 进度处理：小阶保留溢出到下一级
    local req = AscensionSystem.GetRequiredProgress()
    local overflow = math.max(0, state.progress - req)
    state.progress = overflow  -- 保留溢出部分
    state.lastGain = 0
    state.lastCritType = "normal"

    -- 弹窗：传入 old/new 仙阶 realm ID（格式 "asc_N"）
    local oldRealmId = "asc_" .. (target.totalIndex - 1)
    local newRealmId = "asc_" .. target.totalIndex
    EventBus.Emit("ascension_minor_breakthrough", target, oldRealmId, newRealmId)
    EventBus.Emit("save_request")

    print("[AscensionSystem] Minor breakthrough: " .. target.displayName .. " overflow=" .. overflow)
    return true, oldRealmId, newRealmId
end

--- 大仙阶渡劫成功后的结算（由 TribulationSystem 调用）
---@return boolean
function AscensionSystem.CompleteMajorBreakthrough()
    local target = AscensionSystem.GetTargetInfo()
    if not target then return false end
    if not target.isMajor then return false end

    -- 推进仙阶
    AscensionSystem._AdvanceToIndex(target.totalIndex)

    -- 发放属性
    AscensionSystem._ApplyRewards(target.rewards)

    -- 设兼容 realm（首次渡劫设 dujie_1）
    if target.totalIndex == 1 then
        local player = GameState.player
        if player then
            player.realm = "dujie_1"
            player.realmAtkSpeedBonus = GameConfig.REALMS.dujie_1 and GameConfig.REALMS.dujie_1.attackSpeedBonus or 1.0
        end
        state.firstTribulationCompleted = true
    end

    -- 清进度
    state.progress = 0
    state.lastGain = 0
    state.lastCritType = "normal"

    local oldRealmId = "asc_" .. (target.totalIndex - 1)
    local newRealmId = "asc_" .. target.totalIndex
    EventBus.Emit("ascension_major_breakthrough", target, oldRealmId, newRealmId)
    print("[AscensionSystem] Major breakthrough: " .. target.displayName)
    return true, oldRealmId, newRealmId
end

-- ── 内部函数 ─────────────────────────────────────────────────────────────────

function AscensionSystem._AdvanceToIndex(totalIndex)
    state.totalIndex = totalIndex
    state.stageIndex = math.ceil(totalIndex / 9)
    state.minorIndex = ((totalIndex - 1) % 9) + 1
end

function AscensionSystem._ApplyRewards(rewards)
    local player = GameState.player
    if not player or not rewards then return end
    player.maxHp   = player.maxHp   + (rewards.maxHp or 0)
    player.atk     = player.atk     + (rewards.atk or 0)
    player.def     = player.def     + (rewards.def or 0)
    player.hpRegen = player.hpRegen + (rewards.hpRegen or 0)
    -- 回满血
    player.hp = player:GetTotalMaxHp()
    player._statsCacheFrame = -1
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

function AscensionSystem.Serialize()
    return {
        stageIndex   = state.stageIndex,
        minorIndex   = state.minorIndex,
        totalIndex   = state.totalIndex,
        progress     = state.progress,
        lastGain     = state.lastGain,
        lastCritType = state.lastCritType,
        firstTribulationCompleted = state.firstTribulationCompleted,
    }
end

function AscensionSystem.Deserialize(data)
    if not data then
        AscensionSystem.Init()
        return
    end
    AscensionConfig.EnsureRealmsRegistered()
    state.stageIndex   = data.stageIndex or 0
    state.minorIndex   = data.minorIndex or 0
    state.totalIndex   = data.totalIndex or 0
    state.progress     = data.progress or 0
    state.lastGain     = data.lastGain or 0
    state.lastCritType = data.lastCritType or "normal"
    state.firstTribulationCompleted = data.firstTribulationCompleted or false
    print("[AscensionSystem] Deserialized: totalIndex=" .. state.totalIndex .. " progress=" .. state.progress)
end

return AscensionSystem
