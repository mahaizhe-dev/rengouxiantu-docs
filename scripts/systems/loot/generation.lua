---@diagnostic disable
-- ============================================================================
-- loot/generation.lua - 装备生成（Tier+品质 联合抽取、副属性随机、特殊/法宝/圣器）
-- ============================================================================

local shared = require("systems.loot.shared")

-- 解构常用引用
local GameConfig      = shared.GameConfig
local EquipmentData   = shared.EquipmentData
local Utils           = shared.Utils
local EquipmentUtils  = shared.EquipmentUtils
local IconUtils       = shared.IconUtils

local BASE_QUALITY_WEIGHTS = shared.BASE_QUALITY_WEIGHTS
local TIER_QUALITY_WEIGHTS = shared.TIER_QUALITY_WEIGHTS
local TIER_QUALITY_GATE    = shared.TIER_QUALITY_GATE
local TIER_POSITION_DECAY  = shared.TIER_POSITION_DECAY
local SPECIAL_FLUCTUATION  = shared.SPECIAL_FLUCTUATION
local SUB_BASE_MAP         = shared.SUB_BASE_MAP
local SLOT_ICONS_T1        = shared.SLOT_ICONS_T1
local GOURD_QUALITY_ICONS  = shared.GOURD_QUALITY_ICONS
local XIAN_SLOT_ICONS      = shared.XIAN_SLOT_ICONS
local GetAvailableTiers    = shared.GetAvailableTiers
local BASE_SELL_PRICE      = shared.BASE_SELL_PRICE

local M = {}

local function GetSubStatRandRange(quality)
    local qualityOrder = quality and GameConfig.QUALITY_ORDER[quality] or 1
    local shift = math.max(0, qualityOrder - 4) * 0.1
    if qualityOrder >= 7 then
        return 1.0, 0.5
    end
    return 0.8 + shift, 0.4
end

local function RoundScaledSpecialSubStat(stat, value)
    if EquipmentData.PCT_STATS[stat] then
        return math.floor(value * 10000 + 0.5) / 10000
    end
    return math.floor(value * 100 + 0.5) / 100
end

local function ShouldScaleFixedSpecialSubStats(equipId, item)
    if item.scaleFixedSubStats == true then
        return true
    end
    if item.scaleFixedSubStats == false then
        return false
    end
    return item.fixedSubStats == true
        and item.tier ~= nil
        and item.tier >= 11
        and type(equipId) == "string"
        and string.sub(equipId, 1, 4) == "ch6_"
end

local function ScaleFixedSpecialSubStats(item)
    local fluct = SPECIAL_FLUCTUATION[item.quality] or { 1.0, 0.2 }
    local specialBase = fluct[1]
    local numTierMult = EquipmentData.SUB_STAT_TIER_MULT[item.tier] or 1.0
    local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[item.tier] or 1.0

    for _, sub in ipairs(item.subStats or {}) do
        local baseInfo = SUB_BASE_MAP[sub.stat]
        if baseInfo and not baseInfo.linearGrowth then
            local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTierMult or numTierMult
            local rawValue = baseInfo.baseValue * tierMult
            sub.value = RoundScaledSpecialSubStat(sub.stat, rawValue * specialBase)
        end
    end
end

-- ============================================================================
-- Tier+品质 联合权重
-- ============================================================================

--- 构建等级对应的 Tier+品质联合权重表
---@param monsterLevel number
---@param isEliteOrBoss boolean|nil 是否为精英/BOSS（只取最高2个Tier）
---@param tierOnly number|nil 强制仅掉落指定Tier（如 tierOnly=5 则只掉T5）
---@param tierWindow number[]|nil 显式 Tier 窗口；用于第六章等需要覆盖默认裁剪的掉落
---@param qualityByTier table|nil 按 Tier 指定品质范围：{ [tier] = { minQuality = "...", maxQuality = "..." } }
---@return table[] entries { tier, quality, weight }
function M.BuildTierQualityEntries(monsterLevel, isEliteOrBoss, tierOnly, tierWindow, qualityByTier)
    local tiers = GetAvailableTiers(monsterLevel)

    if tierOnly then
        tiers = { tierOnly }
    elseif tierWindow and #tierWindow > 0 then
        tiers = tierWindow
    elseif isEliteOrBoss and #tiers > 2 then
        local topTiers = {}
        for i = #tiers - 1, #tiers do
            table.insert(topTiers, tiers[i])
        end
        tiers = topTiers
    end

    local entries = {}
    for idx, tier in ipairs(tiers) do
        local decay = TIER_POSITION_DECAY[idx] or TIER_POSITION_DECAY[#TIER_POSITION_DECAY]
        local weights = TIER_QUALITY_WEIGHTS[tier]
        if weights then
            for _, q in ipairs(BASE_QUALITY_WEIGHTS) do
                local w = (weights[q.quality] or 0) * decay
                if w > 0 then
                    local gate = TIER_QUALITY_GATE[q.quality]
                    if gate and gate[tier] then
                        if monsterLevel < gate[tier] then
                            w = 0
                        end
                    end
                    local tierQualityRule = qualityByTier and qualityByTier[tier] or nil
                    if tierQualityRule then
                        local minQ = tierQualityRule.minQuality or tierQualityRule.min
                        local maxQ = tierQualityRule.maxQuality or tierQualityRule.max
                        local qOrder = GameConfig.QUALITY_ORDER[q.quality]
                        local minOrder = minQ and GameConfig.QUALITY_ORDER[minQ] or 1
                        local maxOrder = maxQ and GameConfig.QUALITY_ORDER[maxQ] or 9
                        if not qOrder or qOrder < minOrder or qOrder > maxOrder then
                            w = 0
                        end
                    end
                    if w > 0 then
                        table.insert(entries, { tier = tier, quality = q.quality, weight = w })
                    end
                end
            end
        end
    end

    return entries
end

--- 根据怪物等级联合抽取 Tier 和品质
---@param monsterLevel number
---@param minQuality string|nil
---@param maxQuality string|nil
---@param isBoss boolean|nil
---@param tierOnly number|nil
---@param tierWindow number[]|nil
---@param qualityByTier table|nil
---@return number tier, string quality
function M.RollTierAndQuality(monsterLevel, minQuality, maxQuality, isBoss, tierOnly, tierWindow, qualityByTier)
    local entries = M.BuildTierQualityEntries(monsterLevel, isBoss, tierOnly, tierWindow, qualityByTier)

    local minOrder = minQuality and GameConfig.QUALITY_ORDER[minQuality] or 1
    local maxOrder = maxQuality and GameConfig.QUALITY_ORDER[maxQuality] or (qualityByTier and 9 or 4)

    local filtered = {}
    local totalWeight = 0
    for _, entry in ipairs(entries) do
        local order = GameConfig.QUALITY_ORDER[entry.quality]
        if order and order >= minOrder and order <= maxOrder then
            table.insert(filtered, entry)
            totalWeight = totalWeight + entry.weight
        end
    end

    if #filtered == 0 then return 1, "white" end

    local roll = math.random() * totalWeight
    local acc = 0
    for _, entry in ipairs(filtered) do
        acc = acc + entry.weight
        if roll <= acc then
            return entry.tier, entry.quality
        end
    end

    local last = filtered[#filtered]
    return last.tier, last.quality
end

-- ============================================================================
-- 副属性 / 灵性 / 圣性 生成
-- ============================================================================

--- 品质抽取
---@param minQuality string|nil
---@param maxQuality string|nil
---@return string
function M.RollQuality(minQuality, maxQuality)
    local minOrder = minQuality and GameConfig.QUALITY_ORDER[minQuality] or 1
    local maxOrder = maxQuality and GameConfig.QUALITY_ORDER[maxQuality] or 4

    local validQualities = {}
    local totalWeight = 0
    for _, entry in ipairs(BASE_QUALITY_WEIGHTS) do
        local order = GameConfig.QUALITY_ORDER[entry.quality]
        if order and order >= minOrder and order <= maxOrder then
            table.insert(validQualities, entry)
            totalWeight = totalWeight + entry.weight
        end
    end

    if #validQualities == 0 then return "white" end

    local roll = math.random() * totalWeight
    local acc = 0
    for _, entry in ipairs(validQualities) do
        acc = acc + entry.weight
        if roll <= acc then
            return entry.quality
        end
    end

    return validQualities[#validQualities].quality
end

--- 生成副属性
---@param count number 副属性数量
---@param tier number 阶级
---@param excludeStat string 排除的主属性
---@param quality string|nil 品质
---@return table
function M.GenerateSubStats(count, tier, excludeStat, quality)
    if count <= 0 then return {} end

    local pool = {}
    for _, sub in ipairs(EquipmentData.SUB_STATS) do
        if sub.stat ~= excludeStat then
            table.insert(pool, sub)
        end
    end

    local randBase, randRange = GetSubStatRandRange(quality)

    local selected = {}
    local used = {}
    local numTierMult = EquipmentData.SUB_STAT_TIER_MULT[tier] or 1.0
    local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[tier] or 1.0

    for i = 1, math.min(count, #pool) do
        local idx
        repeat
            idx = math.random(1, #pool)
        until not used[idx]
        used[idx] = true

        local sub = pool[idx]
        local value
        if sub.linearGrowth then
            local qualityConfig = quality and GameConfig.QUALITY[quality] or nil
            local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
            value = math.floor(tier * qualityMult)
            if value <= 0 then value = 1 end
        else
            local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTierMult or numTierMult
            value = sub.baseValue * tierMult
            value = value * (randBase + math.random() * randRange)
            value = math.floor(value * 100 + 0.5) / 100
            if value <= 0 then value = 0.01 end
        end

        table.insert(selected, {
            stat = sub.stat,
            name = sub.name,
            value = value,
        })
    end

    return selected
end

--- 生成灵性属性（青·灵器及以上品质专属，半值副属性）
---@param tier number
---@param mainStatType string
---@param quality string
---@return table|nil
function M.GenerateSpiritStat(tier, mainStatType, quality)
    local pool = {}
    for _, sub in ipairs(EquipmentData.SPIRIT_STATS) do
        if sub.stat ~= mainStatType then
            table.insert(pool, sub)
        end
    end
    if #pool == 0 then return nil end

    local sub = pool[math.random(1, #pool)]

    local randBase, randRange = GetSubStatRandRange(quality)

    local numTierMult = EquipmentData.SUB_STAT_TIER_MULT[tier] or 1.0
    local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[tier] or 1.0

    local value
    if sub.fixed then
        -- 天诛等固定属性：完全固定，无任何波动
        value = sub.baseValue
    elseif sub.linearGrowth then
        local qualityConfig = GameConfig.QUALITY[quality]
        local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
        value = math.floor(tier * qualityMult) * 0.5
        if value <= 0 then value = 0.5 end
    else
        local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTierMult or numTierMult
        value = sub.baseValue * tierMult
        value = value * (randBase + math.random() * randRange)
        value = value * 0.5  -- 半值
        value = math.floor(value * 100 + 0.5) / 100
        if value <= 0 then value = 0.01 end
    end

    return {
        stat = sub.stat,
        name = sub.name,
        value = value,
    }
end

--- 生成圣性属性（红·圣器专属，全值副属性）
---@param tier number
---@param mainStatType string
---@param quality string
---@return table|nil
function M.GenerateSaintStat(tier, mainStatType, quality)
    local pool = {}
    for _, sub in ipairs(EquipmentData.SAINT_STATS) do
        if sub.stat ~= mainStatType then
            table.insert(pool, sub)
        end
    end
    if #pool == 0 then return nil end

    local sub = pool[math.random(1, #pool)]

    local randBase, randRange = GetSubStatRandRange(quality)

    local numTierMult = EquipmentData.SUB_STAT_TIER_MULT[tier] or 1.0
    local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[tier] or 1.0

    local value
    if sub.fixed then
        -- 天诛等固定属性：完全固定，无任何波动
        value = sub.baseValue
    elseif sub.linearGrowth then
        local qualityConfig = GameConfig.QUALITY[quality]
        local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
        value = math.floor(tier * qualityMult)
        if value <= 0 then value = 1 end
    else
        local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTierMult or numTierMult
        value = sub.baseValue * tierMult
        value = value * (randBase + math.random() * randRange)
        value = math.floor(value * 100 + 0.5) / 100
        if value <= 0 then value = 0.01 end
    end

    return {
        stat = sub.stat,
        name = sub.name,
        value = value,
    }
end

-- ============================================================================
-- 装备创建
-- ============================================================================

--- 根据 dropTable 生成掉落物
---@param dropTable table
---@param monster table
---@return table
function M.GenerateDrops(dropTable, monster)
    local MonsterData = shared.MonsterData
    local GameState   = shared.GameState

    -- 魔化怪物：无掉落（封魔BOSS除外）
    if monster.isDemon and not monster.isSealDemon then
        return { items = {}, gold = 0, exp = 0, materials = {}, lingYun = 0 }
    end

    local player = GameState.player
    local levelDiff = (player and player.level or 0) - (monster.level or 0)
    local exp = monster.expReward or 0
    if levelDiff > 15 then
        exp = 0
    end

    local result = {
        items = {},
        gold = 0,
        exp = exp,
        materials = {},
        lingYun = 0,
    }

    if monster.goldReward and levelDiff <= 15 then
        result.gold = Utils.RandomInt(monster.goldReward[1], monster.goldReward[2])
    end

    for _, entry in ipairs(dropTable) do
        if Utils.Roll(entry.chance) then
            if entry.type == "equipment" then
                local item = nil
                if entry.equipId then
                    item = M.CreateSpecialEquipment(entry.equipId)
                else
                    local monsterLevel = monster.level or 1
                    local cat = monster.category or "normal"
                    local isEliteOrBoss = GameConfig.ELITE_OR_BOSS[cat] or false
                    local tierOnly = entry.tierOnly or monster.tierOnly
                    item = M.GenerateRandomEquipment(monsterLevel, entry.minQuality, entry.maxQuality,
                        isEliteOrBoss, tierOnly, entry.tierWindow, entry.qualityByTier)
                end
                if item then
                    table.insert(result.items, item)
                end
            elseif entry.type == "consumable" then
                local cId = entry.consumableId
                if not cId and entry.consumablePool then
                    local pool = entry.consumablePool
                    cId = pool[math.random(1, #pool)]
                end
                local isPetFood = GameConfig.PET_FOOD[cId]
                if not (isPetFood and levelDiff > 15) then
                    local cAmount = entry.amount and Utils.RandomInt(entry.amount[1], entry.amount[2]) or 1
                    if not result.consumables then result.consumables = {} end
                    result.consumables[cId] = (result.consumables[cId] or 0) + cAmount
                end
            elseif entry.type == "set_equipment" then
                local setIds = entry.setIds
                if setIds and #setIds > 0 then
                    local chosenSetId = setIds[math.random(1, #setIds)]
                    local mLevel = monster.level or 1
                    local item = M.GenerateSetEquipment(mLevel, chosenSetId, nil, entry.tier)
                    if item then
                        table.insert(result.items, item)
                    end
                end
            elseif entry.type == "world_drop" then
                local pool = MonsterData.WORLD_DROP_POOLS[entry.pool]
                if pool and pool.items and #pool.items > 0 then
                    local mCat = monster.category or "normal"
                    local isBoss = (mCat == "boss" or mCat == "king_boss" or mCat == "emperor_boss" or mCat == "saint_boss")
                    local candidates = {}
                    for _, pItem in ipairs(pool.items) do
                        if not pItem.bossOnly or isBoss then
                            table.insert(candidates, pItem)
                        end
                    end
                    local picked = #candidates > 0 and candidates[math.random(1, #candidates)] or nil
                    if picked and picked.type == "equipment" and picked.equipId then
                        local item = M.CreateSpecialEquipment(picked.equipId)
                        if item then
                            table.insert(result.items, item)
                        end
                    elseif picked and picked.type == "consumable" and picked.consumableId then
                        if not result.consumables then result.consumables = {} end
                        result.consumables[picked.consumableId] = (result.consumables[picked.consumableId] or 0) + 1
                    end
                end
            elseif entry.type == "equipment_pool" then
                local pool = entry.pool
                if pool and #pool > 0 then
                    local count = 1
                    if entry.count then
                        if type(entry.count) == "table" then
                            count = Utils.RandomInt(entry.count[1], entry.count[2])
                        else
                            count = entry.count
                        end
                    end
                    count = math.min(count, #pool)
                    local indices = {}
                    for i = 1, #pool do indices[i] = i end
                    for i = 1, count do
                        local j = math.random(i, #pool)
                        indices[i], indices[j] = indices[j], indices[i]
                        local picked = pool[indices[i]]
                        if picked.equipId then
                            local item = M.CreateSpecialEquipment(picked.equipId)
                            if item then
                                table.insert(result.items, item)
                            end
                        end
                    end
                end
            elseif entry.type == "material" then
                table.insert(result.materials, entry.materialId)
            elseif entry.type == "lingYun" then
                local amount = 1
                if entry.amount then
                    amount = Utils.RandomInt(entry.amount[1], entry.amount[2])
                end
                result.lingYun = result.lingYun + amount
            end
        end
    end

    return result
end

--- 生成随机装备（按怪物等级决定 Tier+品质）
---@param monsterLevel number
---@param minQuality string|nil
---@param maxQuality string|nil
---@param isBoss boolean|nil
---@param tierOnly number|nil
---@param tierWindow number[]|nil
---@param qualityByTier table|nil
---@return table|nil
function M.GenerateRandomEquipment(monsterLevel, minQuality, maxQuality, isBoss, tierOnly, tierWindow, qualityByTier)
    local slot = Utils.RandomPick(EquipmentData.STANDARD_SLOTS)
    local tier, quality = M.RollTierAndQuality(monsterLevel, minQuality, maxQuality, isBoss, tierOnly, tierWindow, qualityByTier)
    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return nil end

    local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityConfig.multiplier)
    if not mainValue then return nil end

    local subStats = M.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)

    local spiritStat = nil
    local qualityOrder = GameConfig.QUALITY_ORDER[quality] or 1
    if qualityOrder >= 6 then
        spiritStat = M.GenerateSpiritStat(tier, mainStatType, quality)
    end

    local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
    local baseName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

    local item = {
        id = Utils.NextId(),
        name = baseName,
        slot = slot,
        icon = M.GetSlotIcon(slot, tier),
        quality = quality,
        tier = tier,
        mainStat = { [mainStatType] = mainValue },
        subStats = subStats,
        spiritStat = spiritStat,
        sellPrice = math.floor((BASE_SELL_PRICE[tier] or (10 * tier)) * qualityConfig.multiplier),
    }

    if qualityOrder >= 6 then
        item.sellCurrency = "lingYun"
        item.sellPrice = math.max(1, tier - 4)
    end

    return item
end

--- 生成套装灵器装备（BOSS 掉落 / 龙锻铸造专用）
---@param monsterLevel number
---@param setId string
---@param slotOverride string|nil
---@param tierOverride number|nil
---@return table|nil
function M.GenerateSetEquipment(monsterLevel, setId, slotOverride, tierOverride)
    local tier = tierOverride or 9
    local quality = "cyan"
    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return nil end

    local slot = slotOverride or Utils.RandomPick(EquipmentData.STANDARD_SLOTS)

    local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityConfig.multiplier)
    if not mainValue then return nil end

    local subStats = M.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)
    local spiritStat = M.GenerateSpiritStat(tier, mainStatType, quality)

    local setData = EquipmentData.SetBonuses[setId]
    local setPrefix = setData and setData.name or setId
    local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
    local slotName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)
    local itemName = setPrefix .. "·" .. slotName

    local item = {
        id = Utils.NextId(),
        name = itemName,
        slot = slot,
        icon = M.GetSlotIcon(slot, tier),
        quality = quality,
        tier = tier,
        mainStat = { [mainStatType] = mainValue },
        subStats = subStats,
        spiritStat = spiritStat,
        setId = setId,
        sellCurrency = "lingYun",
        sellPrice = math.max(1, tier - 4),
    }

    return item
end

--- 创建特殊装备（BOSS 固定掉落）
---@param equipId string
---@return table|nil
function M.CreateSpecialEquipment(equipId)
    local template = EquipmentData.SpecialEquipment[equipId]
    if not template then return nil end

    local item = Utils.DeepCopy(template)
    item.id = Utils.NextId()
    item.equipId = equipId
    item.sellPrice = template.sellPrice or 100
    item.sellCurrency = template.sellCurrency
    item.isSpecial = true

    if item.subStats and item.tier and ShouldScaleFixedSpecialSubStats(equipId, item) then
        ScaleFixedSpecialSubStats(item)
    end

    -- 第六章过渡特殊装备要求副属性固定；旧章节未标记模板继续沿用波动逻辑。
    if item.subStats and item.tier and not item.fixedSubStats then
        local fluct = SPECIAL_FLUCTUATION[item.quality] or { 1.0, 0.2 }
        local specialBase = fluct[1]
        local specialRange = fluct[2]

        local numTierMult = EquipmentData.SUB_STAT_TIER_MULT[item.tier] or 1.0
        local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[item.tier] or 1.0

        for _, sub in ipairs(item.subStats) do
            local baseInfo = SUB_BASE_MAP[sub.stat]
            if baseInfo and not baseInfo.linearGrowth then
                local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTierMult or numTierMult
                local rawValue = baseInfo.baseValue * tierMult
                local fluctuation = specialBase + math.random() * specialRange
                local newValue = rawValue * fluctuation
                sub.value = math.floor(newValue * 100 + 0.5) / 100
            end
        end
    end

    if template.hasSpiritStat and not item.spiritStat then
        item.spiritStat = M.GenerateSpiritStat(item.tier, "atk", item.quality)
    end

    return item
end

--- 创建法宝装备（阵营挑战动态掉落）
---@param templateId string
---@param tier number
---@param quality string
---@return table|nil
function M.CreateFabaoEquipment(templateId, tier, quality)
    local template = EquipmentData.FabaoTemplates[templateId]
    if not template then
        print("[LootSystem] WARNING: FabaoTemplate not found: " .. tostring(templateId))
        return nil
    end

    if not quality then
        local maxQ = "purple"
        if tier >= 10 then
            maxQ = "red"
        elseif tier >= 9 then
            maxQ = "cyan"
        elseif tier >= 5 then
            maxQ = "orange"
        end
        quality = M.RollQuality("white", maxQ)
        print("[LootSystem] Fabao quality rolled: " .. quality .. " (maxQ=" .. maxQ .. " tier=" .. tier .. ")")
    end

    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then
        print("[LootSystem] WARNING: Invalid quality for fabao: " .. tostring(quality))
        return nil
    end
    local qualityMult = qualityConfig.multiplier

    local mainStatValue
    if template.mainStatFormula == "xianyuan" then
        mainStatValue = math.floor(tier * qualityMult) * template.mainStatBase
    else
        mainStatValue = EquipmentUtils.CalcMainStatValue(
            template.mainStatBase, template.mainStatType, tier, qualityMult
        )
    end

    local repLevel = math.max(1, tier - 2)
    local displayName = template.name .. "Lv." .. repLevel
    local icon = template.iconByTier[tier] or template.iconByTier[9] or "icon_fabao.png"
    local sellPrice = template.sellPriceByTier[tier] or 100

    local subStatCount = qualityConfig.subStatCount or 0
    local subStats = M.GenerateSubStats(subStatCount, tier, template.mainStatType, quality)

    local qualityOrder = GameConfig.QUALITY_ORDER[quality] or 1
    local spiritStat = nil
    if qualityOrder >= 6 then
        spiritStat = M.GenerateSpiritStat(tier, template.mainStatType, quality)
    end

    local item = {
        id        = Utils.NextId(),
        equipId   = templateId,
        name      = displayName,
        slot      = template.slot,
        tier      = tier,
        quality   = quality,
        icon      = icon,
        mainStat  = { [template.mainStatType] = mainStatValue },
        subStats  = subStats,
        spiritStat = spiritStat,
        skillId   = template.skillId,
        sellPrice = sellPrice,
        sellCurrency = nil,
        isFabao   = true,
        isSpecial = true,
    }

    if qualityOrder >= 6 then
        item.sellCurrency = "lingYun"
        item.sellPrice = math.max(1, tier - 4)
    end

    return item
end

--- 铸剑地炉：打造普通圣器装备
---@param equipId string
---@return table|nil
function M.CreateSaintEquipment(equipId)
    local template = EquipmentData.SpecialEquipment[equipId]
    if not template then
        print("[LootSystem] CreateSaintEquipment: template not found: " .. tostring(equipId))
        return nil
    end

    local item = M.CreateSpecialEquipment(equipId)
    if not item then return nil end

    if item.saintStat then
        -- 路线 A：固定圣性（帝尊圣戒等）
        item.spiritStat = nil
        print("[LootSystem] CreateSaintEquipment: " .. equipId ..
              " fixed saintStat=" .. item.saintStat.name .. "+" .. tostring(item.saintStat.value))
    else
        -- 路线 B：随机圣性（圣衣、圣氅、解封古剑等）
        item.spiritStat = nil
        local mainStatType = nil
        if template.mainStat then
            for k, _ in pairs(template.mainStat) do
                mainStatType = k
                break
            end
        end
        local quality = template.quality or "red"
        local tier = template.tier or 10
        item.saintStat = M.GenerateSaintStat(tier, mainStatType, quality)
        print("[LootSystem] CreateSaintEquipment: " .. equipId ..
              " random saintStat=" .. (item.saintStat and (item.saintStat.name .. "+" .. tostring(item.saintStat.value)) or "nil"))
    end

    return item
end

--- 铸剑地炉：解封古剑
---@param sourceFengyinItem table
---@param targetEquipId string
---@return table|nil
function M.CreateJiefengSword(sourceFengyinItem, targetEquipId)
    local template = EquipmentData.SpecialEquipment[targetEquipId]
    if not template then
        print("[LootSystem] CreateJiefengSword: template not found: " .. tostring(targetEquipId))
        return nil
    end
    if not sourceFengyinItem then
        print("[LootSystem] CreateJiefengSword: sourceFengyinItem is nil")
        return nil
    end

    local item = M.CreateSpecialEquipment(targetEquipId)
    if not item then return nil end

    item.spiritStat = nil

    local mainStatType = "atk"
    local quality = template.quality or "red"
    local tier = template.tier or 10
    item.saintStat = M.GenerateSaintStat(tier, mainStatType, quality)

    print("[LootSystem] CreateJiefengSword: " .. targetEquipId ..
          " from=" .. tostring(sourceFengyinItem.equipId) ..
          " spiritStat=" .. (item.spiritStat and (item.spiritStat.name .. "+" .. tostring(item.spiritStat.value)) or "nil") ..
          " saintStat=" .. (item.saintStat and (item.saintStat.name .. "+" .. tostring(item.saintStat.value)) or "nil"))
    return item
end

--- 铸剑地炉：升级龙极令为龙魂令
---@param sourceLongjiItem table
---@return table|nil
function M.CreateLonghunling(sourceLongjiItem)
    if not sourceLongjiItem then
        print("[LootSystem] CreateLonghunling: sourceLongjiItem is nil")
        return nil
    end

    local tier    = 10
    local quality = "red"
    local item = M.CreateFabaoEquipment("fabao_longhunling", tier, quality)
    if not item then
        print("[LootSystem] CreateLonghunling: CreateFabaoEquipment failed")
        return nil
    end

    print("[LootSystem] CreateLonghunling: success, mainStat=" .. tostring(item.mainStat and item.mainStat.atk))
    return item
end

-- ============================================================================
-- 命格掉落
-- ============================================================================

--- 命格掉落判定 + 生成（从 GameEvents 内联逻辑提取）
--- 返回 minggeItem 或 nil（不满足条件时）
---@param monster table 被击杀的怪物 { typeId, x, y, ... }
---@param player table 玩家 { realm, ... }
---@return table|nil minggeItem
function M.RollMingge(monster, player)
    local MinggeData   = require("config.MinggeData")
    local MinggeSystem = require("systems.MinggeSystem")

    -- 查找 monster.typeId 是否为命格来源 BOSS
    local bossId = MinggeData.BOSS_TO_MINGGE[monster.typeId] or monster.typeId
    local source = MinggeData.SOURCES[bossId]
    if not source then return nil end
    if not player then return nil end

    -- 概率判定
    if math.random() >= MinggeData.DROP_RULES.baseDropChance then return nil end

    -- 生成命格
    local minggeItem = MinggeSystem.GenerateItem(bossId)
    return minggeItem
end

-- ============================================================================
-- 图标辅助
-- ============================================================================

--- 获取槽位图标
---@param slot string
---@param tier number|nil
---@return string
function M.GetSlotIcon(slot, tier)
    tier = tier or 1
    if slot == "treasure" then
        local quality = "green"
        local upgradeData = EquipmentData.GOURD_UPGRADE[tier]
        if upgradeData then
            quality = upgradeData.quality or "green"
        end
        return GOURD_QUALITY_ICONS[quality] or GOURD_QUALITY_ICONS.green
    end
    local baseSlot = slot == "ring1" and "ring" or (slot == "ring2" and "ring" or slot)
    local xianIcons = XIAN_SLOT_ICONS[tier]
    if xianIcons then
        local xianIcon = xianIcons[slot] or xianIcons[baseSlot]
        if xianIcon then return xianIcon end
    end
    local iconTier = math.min(tier, 10)
    if iconTier >= 2 then
        return "icon_t" .. iconTier .. "_" .. baseSlot .. ".png"
    end
    return SLOT_ICONS_T1[slot] or "icon_weapon.png"
end

--- 根据葫芦品质获取图标路径
---@param quality string
---@return string
function M.GetGourdIcon(quality)
    return GOURD_QUALITY_ICONS[quality or "green"] or GOURD_QUALITY_ICONS.green
end

return M
