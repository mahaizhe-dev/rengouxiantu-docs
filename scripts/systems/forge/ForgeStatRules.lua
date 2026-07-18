-- ============================================================================
-- ForgeStatRules.lua - 打造属性生成与预览的统一规则
-- ============================================================================

local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")

local ForgeStatRules = {}

ForgeStatRules.SPECIAL_FLUCTUATION = {
    purple  = { 1.0, 0.2 },
    orange  = { 1.1, 0.2 },
    cyan    = { 1.1, 0.3 },
    red     = { 1.2, 0.3 },
    gold    = { 1.2, 0.4 },
    rainbow = { 1.3, 0.4 },
}

ForgeStatRules.DRAGON_FORGE_FLUCTUATION = { 1.1, 0.4 }

local SUB_STAT_BY_ID = {}
for _, sub in ipairs(EquipmentData.SUB_STATS or {}) do
    SUB_STAT_BY_ID[sub.stat] = sub
end

---@param stat string
---@param value number
---@return number
function ForgeStatRules.RoundSpecialSubStat(stat, value)
    if EquipmentData.PCT_STATS[stat] then
        return math.floor(value * 10000 + 0.5) / 10000
    end
    return math.floor(value * 100 + 0.5) / 100
end

---@param stat string
---@param tier number
---@param quality string
---@return number
local function GetLinearValue(stat, tier, quality)
    local qualityConfig = GameConfig.QUALITY[quality]
    local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
    return math.max(1, math.floor(tier * qualityMult))
end

---@param stat string
---@param tier number
---@return number|nil
local function GetRawSubStatValue(stat, tier)
    local subDef = SUB_STAT_BY_ID[stat]
    if not subDef then return nil end
    local tierMult
    if EquipmentData.PCT_STATS[stat] then
        tierMult = EquipmentData.PCT_SUB_TIER_MULT[tier] or 1.0
    else
        tierMult = EquipmentData.SUB_STAT_TIER_MULT[tier] or 1.0
    end
    return subDef.baseValue * tierMult
end

---@param stat string
---@param tier number
---@param quality string
---@param fluctuation number[]|nil
---@return number|nil minValue
---@return number|nil maxValue
---@return boolean isFixed
function ForgeStatRules.GetSpecialSubStatRange(stat, tier, quality, fluctuation)
    local subDef = SUB_STAT_BY_ID[stat]
    if not subDef then return nil, nil, true end
    if subDef.linearGrowth or EquipmentData.LINEAR_GROWTH_STATS[stat] then
        local value = GetLinearValue(stat, tier, quality)
        return value, value, true
    end

    local range = fluctuation or ForgeStatRules.SPECIAL_FLUCTUATION[quality] or { 1.0, 0.2 }
    local rawValue = GetRawSubStatValue(stat, tier)
    if not rawValue then return nil, nil, true end

    local minValue = ForgeStatRules.RoundSpecialSubStat(stat, rawValue * range[1])
    local maxValue = ForgeStatRules.RoundSpecialSubStat(stat, rawValue * (range[1] + range[2]))
    return minValue, maxValue, false
end

---@param stat string
---@param tier number
---@param quality string
---@param fluctuation number[]|nil
---@param randomValue number|nil
---@return number|nil
function ForgeStatRules.RollSpecialSubStat(stat, tier, quality, fluctuation, randomValue)
    local minValue, maxValue, isFixed = ForgeStatRules.GetSpecialSubStatRange(
        stat, tier, quality, fluctuation
    )
    if minValue == nil then return nil end
    if isFixed then return minValue end

    local roll = randomValue
    if roll == nil then roll = math.random() end
    local rawValue = GetRawSubStatValue(stat, tier)
    local range = fluctuation or ForgeStatRules.SPECIAL_FLUCTUATION[quality] or { 1.0, 0.2 }
    local value = rawValue * (range[1] + roll * range[2])
    value = ForgeStatRules.RoundSpecialSubStat(stat, value)
    return math.max(minValue, math.min(maxValue, value))
end

---@param recipe table|nil
---@param targetDef table
---@param sub table
---@return table
function ForgeStatRules.GetForgeSubStatPreview(recipe, targetDef, sub)
    if targetDef.fixedSubStats == true then
        return { mode = "fixed", value = sub.value }
    end

    local generatorType = recipe and recipe.generator and recipe.generator.type
    local fluctuation = nil
    if generatorType == "special_equipment" then
        fluctuation = ForgeStatRules.DRAGON_FORGE_FLUCTUATION
    end

    local minValue, maxValue, isFixed = ForgeStatRules.GetSpecialSubStatRange(
        sub.stat,
        targetDef.tier or 1,
        targetDef.quality or "white",
        fluctuation
    )
    if minValue == nil or isFixed then
        return { mode = "fixed", value = minValue or sub.value }
    end
    return { mode = "range", minValue = minValue, maxValue = maxValue }
end

---@param recipe table|nil
---@param targetDef table
---@return string|nil
function ForgeStatRules.GetForgeExtraStatMode(recipe, targetDef)
    local generatorType = recipe and recipe.generator and recipe.generator.type
    if generatorType == "special_equipment" then
        return "spirit_random"
    end
    if generatorType == "saint_equipment"
        or generatorType == "jiefeng_sword"
        or generatorType == "true_sword" then
        if targetDef.saintStat and targetDef.saintStat.confirmed then
            return "saint_fixed"
        end
        return "saint_random"
    end
    if targetDef.saintStat and targetDef.saintStat.confirmed then
        return "saint_fixed"
    end
    if targetDef.hasSaintStat then
        return "saint_random"
    end
    if targetDef.spiritStat then
        return "spirit_fixed"
    end
    if targetDef.hasSpiritStat then
        return "spirit_random"
    end
    return nil
end

local function RoundForgeValue(stat, value)
    value = math.floor(value * 100 + 0.5) / 100
    if value <= 0 then value = 0.01 end
    if not EquipmentData.PCT_STATS[stat] and stat ~= "hpRegen" then
        value = math.max(1, math.floor(value + 0.5))
    end
    return value
end

---@param stat string
---@param tier number
---@param quality string
---@return number|nil minValue
---@return number|nil maxValue
function ForgeStatRules.GetRerollRange(stat, tier, quality)
    local subDef = SUB_STAT_BY_ID[stat]
    if not subDef then return nil, nil end
    if subDef.linearGrowth or EquipmentData.LINEAR_GROWTH_STATS[stat] then
        local baseValue = GetLinearValue(stat, tier, quality)
        local minValue = math.max(1, math.floor(baseValue * 0.8 + 0.5))
        local maxValue = math.max(1, math.floor(baseValue * 1.2 + 0.5))
        return minValue, maxValue
    end

    local rawValue = GetRawSubStatValue(stat, tier)
    return RoundForgeValue(stat, rawValue * 0.8),
        RoundForgeValue(stat, rawValue * 1.2)
end

---@param stat string
---@param tier number
---@param quality string
---@param randomValue number|nil
---@return number|nil
function ForgeStatRules.RollRerollValue(stat, tier, quality, randomValue)
    local subDef = SUB_STAT_BY_ID[stat]
    if not subDef then return nil end
    local roll = randomValue
    if roll == nil then roll = math.random() end
    if subDef.linearGrowth or EquipmentData.LINEAR_GROWTH_STATS[stat] then
        local baseValue = GetLinearValue(stat, tier, quality)
        return math.max(1, math.floor(baseValue * (0.8 + roll * 0.4) + 0.5))
    end

    local rawValue = GetRawSubStatValue(stat, tier)
    return RoundForgeValue(stat, rawValue * (0.8 + roll * 0.4))
end

return ForgeStatRules
