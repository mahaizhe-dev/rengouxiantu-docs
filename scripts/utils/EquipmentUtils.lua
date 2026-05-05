-- ============================================================================
-- EquipmentUtils.lua - 装备数值公式工具（P1-12 提取）
-- ============================================================================

local EquipmentData = require("config.EquipmentData")

local EquipmentUtils = {}

--- 计算装备主属性值（标准公式）
--- mainValue = baseValue × tierMult × qualityMult，小数属性保留2位
---@param baseValue number 基础属性值
---@param mainStatType string 主属性类型（如 "atk", "critRate"）
---@param tier number 阶级
---@param qualityMult number 品质倍率
---@return number mainValue
function EquipmentUtils.CalcMainStatValue(baseValue, mainStatType, tier, qualityMult)
    local tierMult
    if EquipmentData.PCT_MAIN_STATS[mainStatType] then
        tierMult = EquipmentData.PCT_TIER_MULTIPLIER[tier] or 1.0
    else
        tierMult = EquipmentData.TIER_MULTIPLIER[tier] or 1.0
    end
    local rawMain = baseValue * tierMult * qualityMult
    if rawMain < 1 then
        return math.floor(rawMain * 100 + 0.5) / 100
    else
        return math.floor(rawMain)
    end
end

--- 根据槽位查表并计算主属性值（便捷封装）
---@param slot string 装备槽位
---@param tier number 阶级
---@param qualityMult number 品质倍率
---@return number|nil mainValue, string|nil mainStatType
function EquipmentUtils.CalcSlotMainStat(slot, tier, qualityMult)
    local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
    if not baseStat then return nil, nil end
    local mainStatType = EquipmentData.MAIN_STAT[slot]
    local baseValue = baseStat[mainStatType] or 0
    return EquipmentUtils.CalcMainStatValue(baseValue, mainStatType, tier, qualityMult), mainStatType
end

return EquipmentUtils
