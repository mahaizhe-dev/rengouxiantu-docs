-- ============================================================================
-- SeaPillarSystem.lua - 海神柱核心系统
-- 管理修复/升级/传送/属性加成/存档
-- ============================================================================

local SeaPillarConfig = require("config.SeaPillarConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")

local SeaPillarSystem = {}

-- ── 状态 ──
-- pillars[pillarId] = { repaired = bool, level = 0~10 }
SeaPillarSystem.pillars = {}
SeaPillarSystem._initialized = false

--- 初始化（幂等，可重复调用）
function SeaPillarSystem.Init()
    if SeaPillarSystem._initialized then return end
    SeaPillarSystem._initialized = true
    SeaPillarSystem.pillars = {}
    for _, id in ipairs(SeaPillarConfig.PILLAR_ORDER) do
        SeaPillarSystem.pillars[id] = {
            repaired = false,
            level = 0,
        }
    end
end

--- 确保已初始化
function SeaPillarSystem.EnsureInit()
    if not SeaPillarSystem._initialized then
        SeaPillarSystem.Init()
    end
end

-- ============================================================================
-- 查询
-- ============================================================================

--- 获取某柱状态
---@param pillarId string
---@return table|nil { repaired, level }
function SeaPillarSystem.GetPillarState(pillarId)
    SeaPillarSystem.EnsureInit()
    return SeaPillarSystem.pillars[pillarId]
end

--- 是否已修复
---@param pillarId string
---@return boolean
function SeaPillarSystem.IsRepaired(pillarId)
    local state = SeaPillarSystem.pillars[pillarId]
    return state and state.repaired or false
end

--- 获取等级
---@param pillarId string
---@return number
function SeaPillarSystem.GetLevel(pillarId)
    local state = SeaPillarSystem.pillars[pillarId]
    return state and state.level or 0
end

--- 是否满级
---@param pillarId string
---@return boolean
function SeaPillarSystem.IsMaxLevel(pillarId)
    return SeaPillarSystem.GetLevel(pillarId) >= SeaPillarConfig.MAX_LEVEL
end

--- 能否修复（未修复且太虚令够）
---@param pillarId string
---@return boolean canRepair
---@return string|nil reason
function SeaPillarSystem.CanRepair(pillarId)
    local state = SeaPillarSystem.pillars[pillarId]
    if not state then return false, "未知海神柱" end
    if state.repaired then return false, "已修复" end
    local count = InventorySystem.CountConsumable("taixu_token")
    if count < SeaPillarConfig.REPAIR_COST then
        return false, "太虚令不足（需要" .. SeaPillarConfig.REPAIR_COST .. "，当前" .. count .. "）"
    end
    return true, nil
end

--- 能否升级（已修复且未满级且太虚令够）
---@param pillarId string
---@return boolean canUpgrade
---@return string|nil reason
function SeaPillarSystem.CanUpgrade(pillarId)
    local state = SeaPillarSystem.pillars[pillarId]
    if not state then return false, "未知海神柱" end
    if not state.repaired then return false, "尚未修复" end
    if state.level >= SeaPillarConfig.MAX_LEVEL then return false, "已满级" end
    local nextLevel = state.level + 1
    local cost = SeaPillarConfig.GetUpgradeCost(nextLevel)
    if not cost then return false, "配置错误" end
    local count = InventorySystem.CountConsumable("taixu_token")
    if count < cost then
        return false, "太虚令不足（需要" .. cost .. "，当前" .. count .. "）"
    end
    return true, nil
end

-- ============================================================================
-- 操作
-- ============================================================================

--- 修复海神柱
---@param pillarId string
---@return boolean success
---@return string|nil msg
function SeaPillarSystem.Repair(pillarId)
    local canRepair, reason = SeaPillarSystem.CanRepair(pillarId)
    if not canRepair then return false, reason end

    InventorySystem.ConsumeConsumable("taixu_token", SeaPillarConfig.REPAIR_COST)
    SeaPillarSystem.pillars[pillarId].repaired = true
    SeaPillarSystem.pillars[pillarId].level = 0

    local cfg = SeaPillarConfig.PILLARS[pillarId]
    print("[SeaPillar] 修复: " .. cfg.name)
    EventBus.Emit("sea_pillar_repaired", pillarId)
    EventBus.Emit("save_request")
    return true, cfg.name .. "已修复，传送功能已开启！"
end

--- 升级海神柱
---@param pillarId string
---@return boolean success
---@return string|nil msg
function SeaPillarSystem.Upgrade(pillarId)
    local canUpgrade, reason = SeaPillarSystem.CanUpgrade(pillarId)
    if not canUpgrade then return false, reason end

    local state = SeaPillarSystem.pillars[pillarId]
    local nextLevel = state.level + 1
    local cost = SeaPillarConfig.GetUpgradeCost(nextLevel)

    InventorySystem.ConsumeConsumable("taixu_token", cost)
    state.level = nextLevel

    -- 应用属性加成
    SeaPillarSystem.ApplyAllBonuses()

    local cfg = SeaPillarConfig.PILLARS[pillarId]
    local bonus = cfg.bonusPerLevel
    local msg = cfg.name .. " 升至" .. nextLevel .. "级！" .. cfg.bonusLabel .. "+" .. bonus
    print("[SeaPillar] 升级: " .. msg)
    EventBus.Emit("sea_pillar_upgraded", pillarId, nextLevel)
    EventBus.Emit("save_request")
    return true, msg
end

--- 传送到兽岛（检查是否已修复）
---@param pillarId string
---@return boolean canTeleport
---@return table|nil target { x, y, island }
function SeaPillarSystem.GetTeleportTarget(pillarId)
    if not SeaPillarSystem.IsRepaired(pillarId) then
        return false, nil
    end
    local cfg = SeaPillarConfig.PILLARS[pillarId]
    if not cfg then return false, nil end
    return true, cfg.teleportTarget
end

-- ============================================================================
-- 属性加成
-- ============================================================================

--- 计算所有海神柱提供的属性加成总和
---@return table { def=N, atk=N, maxHp=N, hpRegen=N }
function SeaPillarSystem.GetAllBonuses()
    local bonuses = { def = 0, atk = 0, maxHp = 0, hpRegen = 0 }
    for _, id in ipairs(SeaPillarConfig.PILLAR_ORDER) do
        local state = SeaPillarSystem.pillars[id]
        local cfg = SeaPillarConfig.PILLARS[id]
        if state and cfg and state.level > 0 then
            local stat = cfg.bonusStat
            bonuses[stat] = bonuses[stat] + (cfg.bonusPerLevel * state.level)
        end
    end
    return bonuses
end

--- 将海神柱加成写入 GameState.player
function SeaPillarSystem.ApplyAllBonuses()
    local player = GameState.player
    if not player then return end
    local bonuses = SeaPillarSystem.GetAllBonuses()
    player.seaPillarDef = bonuses.def
    player.seaPillarAtk = bonuses.atk
    player.seaPillarMaxHp = bonuses.maxHp
    player.seaPillarHpRegen = bonuses.hpRegen
end

-- ============================================================================
-- 存档
-- ============================================================================

--- 序列化
---@return table
function SeaPillarSystem.Serialize()
    local data = {}
    for _, id in ipairs(SeaPillarConfig.PILLAR_ORDER) do
        local state = SeaPillarSystem.pillars[id]
        if state then
            data[id] = {
                repaired = state.repaired,
                level = state.level,
            }
        end
    end
    return data
end

--- 反序列化
---@param data table|nil
function SeaPillarSystem.Deserialize(data)
    -- 先重置再初始化默认状态
    SeaPillarSystem._initialized = false
    SeaPillarSystem.Init()
    if not data then return end

    for _, id in ipairs(SeaPillarConfig.PILLAR_ORDER) do
        if data[id] then
            SeaPillarSystem.pillars[id].repaired = data[id].repaired or false
            SeaPillarSystem.pillars[id].level = data[id].level or 0
        end
    end

    -- 加载后立即应用属性
    SeaPillarSystem.ApplyAllBonuses()
end

return SeaPillarSystem
