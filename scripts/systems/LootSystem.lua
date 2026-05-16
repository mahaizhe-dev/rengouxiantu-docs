-- ============================================================================
-- LootSystem.lua - 掉落系统（品质生成、副属性随机、消耗品掉落）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local MonsterData = require("config.MonsterData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local IconUtils = require("utils.IconUtils")
local EquipmentUtils = require("utils.EquipmentUtils")

local LootSystem = {}

-- 普通装备基础售价查表（按 tier 索引，白色品质基准值）
LootSystem.BASE_SELL_PRICE = {10, 20, 35, 55, 80, 110, 140, 180, 220, 270, 320}

-- ============================================================================
-- Tier+品质联合权重系统（等级驱动）
-- 规则：每升一级Tier，权重向下移一档
-- T1: 白50 绿30 蓝15 紫5
-- T2: 白30 绿15 蓝5  紫2   (=T1下移一档)
-- T3: 白15 绿5  蓝2  紫1   (=T2下移一档)
-- T4: 白5  绿2  蓝1  紫0.5 (=T3下移一档)
--
-- 等级→Tier解锁：Lv.1-5=T1, Lv.6-10=T1+T2, Lv.11-15=T1+T2+T3, Lv.16-20=T2+T3+T4
-- 小怪/精英：最多3个Tier
-- BOSS：取可用Tier中最高的2个
-- ============================================================================

-- 品质遍历列表（BuildTierQualityEntries 用此列表遍历每个品质）
local BASE_QUALITY_WEIGHTS = {
    { quality = "white",  weight = 250 },
    { quality = "green",  weight = 150 },
    { quality = "blue",   weight = 75 },
    { quality = "purple", weight = 25 },
    { quality = "orange", weight = 5 },  -- T5+ 引入（0.99%），受 TIER_QUALITY_GATE 等级门槛限制
    { quality = "cyan",   weight = 1 },  -- T9+ 引入（0.20%），受 TIER_QUALITY_GATE 等级门槛限制
}

-- 各 Tier 的品质权重（基础值，实际使用时乘以位置衰减系数）
-- T1-T4: 白绿蓝紫  T5-T8: 白绿蓝紫+低概率橙  T9-T11: 白绿蓝紫橙+极低概率青(灵器)
-- 权重比: 白250:绿150:蓝75:紫25:橙5:青1 (概率: 49.3%:29.6%:14.8%:4.93%:0.99%:0.20%)
local TIER_QUALITY_WEIGHTS = {
    [1]  = { white = 250, green = 150, blue = 75, purple = 25 },
    [2]  = { white = 250, green = 150, blue = 75, purple = 25 },
    [3]  = { white = 250, green = 150, blue = 75, purple = 25 },
    [4]  = { white = 250, green = 150, blue = 75, purple = 25 },
    [5]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5 },
    [6]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5 },
    [7]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5 },
    [8]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5 },
    [9]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5, cyan = 1 },
    [10] = { white = 250, green = 150, blue = 75, purple = 25, orange = 5, cyan = 1 },
    [11] = { white = 250, green = 150, blue = 75, purple = 25, orange = 5, cyan = 1 },
}

-- 高品质 per-tier 等级门槛（阶级解锁等级 + 延迟）
-- 橙色: 阶级解锁等级 + 5  (仅精英/BOSS可触发，普通怪 maxQuality 默认紫色，天然隔离)
-- 灵器: 阶级解锁等级 + 10 (仅精英/BOSS可触发)
-- 未列出的阶级/品质组合 = 该阶级不产出该品质
local TIER_QUALITY_GATE = {
    orange = {
        [5] = 31,  [6] = 46,  [7] = 61,  [8] = 76,
        [9] = 91,  [10] = 106, [11] = 126,
    },
    cyan = {
        [9] = 96,  [10] = 111, [11] = 131,
    },
}

-- 窗口内位置衰减系数：低阶Tier概率高，高阶Tier递推衰减
-- 位置1(窗口最低阶)=×1.0  位置2=×0.5  位置3(窗口最高阶)=×0.2
-- 3Tier窗口概率: 58.8% / 29.4% / 11.8%
-- 2Tier窗口概率: 66.7% / 33.3%
local TIER_POSITION_DECAY = { 1.0, 0.5, 0.2 }

-- 特殊装备副属性波动区间（P2-7：从函数内提升到模块级）
local SPECIAL_FLUCTUATION = {
    purple  = { 1.0, 0.2 },  -- 1.0 ~ 1.2
    orange  = { 1.1, 0.2 },  -- 1.1 ~ 1.3
    cyan    = { 1.1, 0.3 },  -- 1.1 ~ 1.4
    red     = { 1.2, 0.3 },  -- 1.2 ~ 1.5
    gold    = { 1.2, 0.4 },  -- 1.2 ~ 1.6
    rainbow = { 1.3, 0.4 },  -- 1.3 ~ 1.7
}

-- 副属性 baseValue 查找表（P2-9：从函数内提升到模块级，仅构建一次）
local SUB_BASE_MAP = {}
for _, sub in ipairs(EquipmentData.SUB_STATS) do
    SUB_BASE_MAP[sub.stat] = sub
end

-- T1 基础图标映射（P2-8：从函数内提升到模块级）
local SLOT_ICONS_T1 = {
    weapon    = "icon_weapon.png",
    helmet    = "icon_helmet.png",
    armor     = "icon_armor.png",
    shoulder  = "icon_shoulder.png",
    belt      = "icon_belt.png",
    boots     = "icon_boots.png",
    ring1     = "icon_ring.png",
    ring2     = "icon_ring.png",
    necklace  = "icon_necklace.png",
    cape      = "icon_cape.png",
    treasure  = "image/gourd_green.png",
    exclusive = "icon_exclusive.png",
}

-- 葫芦品质 → 图标映射（统一全局使用）
local GOURD_QUALITY_ICONS = {
    green  = "image/gourd_green.png",
    blue   = "image/gourd_blue.png",
    purple = "image/gourd_purple.png",
    orange = "image/gourd_orange.png",
    cyan   = "image/gourd_cyan.png",
}

--- 根据怪物等级确定可用 Tier 列表
--- 每个等级段保留 2~3 个 Tier 窗口，低阶逐步淘汰
---@param monsterLevel number
---@return number[] availableTiers
local function GetAvailableTiers(monsterLevel)
    -- Tier 解锁等级: T1=1, T2=6, T3=11, T4=16, T5=26, T6=41, T7=56, T8=71, T9=86, T10=101, T11=121
    if monsterLevel >= 121 then return { 9, 10, 11 }
    elseif monsterLevel >= 101 then return { 8, 9, 10 }
    elseif monsterLevel >= 86  then return { 7, 8, 9 }
    elseif monsterLevel >= 71  then return { 6, 7, 8 }
    elseif monsterLevel >= 56  then return { 5, 6, 7 }
    elseif monsterLevel >= 41  then return { 4, 5, 6 }
    elseif monsterLevel >= 26  then return { 3, 4, 5 }
    elseif monsterLevel >= 16  then return { 2, 3, 4 }
    elseif monsterLevel >= 11  then return { 1, 2, 3 }
    elseif monsterLevel >= 6   then return { 1, 2 }
    else                            return { 1 }
    end
end

--- 构建等级对应的 Tier+品质联合权重表
---@param monsterLevel number
---@param isEliteOrBoss boolean|nil 是否为精英/BOSS（只取最高2个Tier）
---@param tierOnly number|nil 强制仅掉落指定Tier（如 tierOnly=5 则只掉T5）
---@return table[] entries { tier, quality, weight }
function LootSystem.BuildTierQualityEntries(monsterLevel, isEliteOrBoss, tierOnly)
    local tiers = GetAvailableTiers(monsterLevel)

    if tierOnly then
        -- 强制指定Tier，忽略窗口筛选
        tiers = { tierOnly }
    elseif isEliteOrBoss and #tiers > 2 then
        -- 精英/BOSS：只取最高的2个Tier
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
                    -- Per-tier quality gate: 该阶级的该品质是否已在此等级解锁
                    local gate = TIER_QUALITY_GATE[q.quality]
                    if gate and gate[tier] then
                        if monsterLevel < gate[tier] then
                            w = 0  -- 未达到解锁等级，拦截
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
---@param tierOnly number|nil 强制仅掉落指定Tier
---@return number tier, string quality
function LootSystem.RollTierAndQuality(monsterLevel, minQuality, maxQuality, isBoss, tierOnly)
    local entries = LootSystem.BuildTierQualityEntries(monsterLevel, isBoss, tierOnly)

    local minOrder = minQuality and GameConfig.QUALITY_ORDER[minQuality] or 1
    local maxOrder = maxQuality and GameConfig.QUALITY_ORDER[maxQuality] or 4

    -- 按品质范围筛选
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

    -- 加权随机
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

--- 根据 dropTable 生成掉落物
---@param dropTable table 怪物掉落表
---@param monster table 怪物实例
---@return table 掉落结果 {items, gold, exp, materials, lingYun}
function LootSystem.GenerateDrops(dropTable, monster)
    -- 魔化怪物：无任何掉落（奖励由除魔系统发放）— 封魔BOSS除外（保留原BOSS掉落）
    if monster.isDemon and not monster.isSealDemon then
        return { items = {}, gold = 0, exp = 0, materials = {}, lingYun = 0 }
    end

    -- 等级差衰减：超过15级不掉经验
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

    -- 金币（等级差>15不掉落）
    if monster.goldReward and levelDiff <= 15 then
        result.gold = Utils.RandomInt(monster.goldReward[1], monster.goldReward[2])
    end

    -- 处理掉落表
    for _, entry in ipairs(dropTable) do
        if Utils.Roll(entry.chance) then
            if entry.type == "equipment" then
                local item = nil
                if entry.equipId then
                    -- 特殊装备（固定掉落）
                    item = LootSystem.CreateSpecialEquipment(entry.equipId)
                else
                    -- 随机装备（按怪物等级决定 Tier，BOSS限制Tier范围）
                    local monsterLevel = monster.level or 1
                    local cat = monster.category or "normal"
                    local isEliteOrBoss = GameConfig.ELITE_OR_BOSS[cat] or false
                    item = LootSystem.GenerateRandomEquipment(monsterLevel, entry.minQuality, entry.maxQuality, isEliteOrBoss, monster.tierOnly)
                end
                if item then
                    table.insert(result.items, item)
                end
            elseif entry.type == "consumable" then
                -- 消耗品掉落（宠物食物、灵兽丹等）
                -- 支持 consumablePool：从池中随机选一种
                local cId = entry.consumableId
                if not cId and entry.consumablePool then
                    local pool = entry.consumablePool
                    cId = pool[math.random(1, #pool)]
                end
                -- 等级差>15: 宠物食物不掉落（与经验衰减一致）
                local isPetFood = GameConfig.PET_FOOD[cId]
                if not (isPetFood and levelDiff > 15) then
                    local cAmount = entry.amount and Utils.RandomInt(entry.amount[1], entry.amount[2]) or 1
                    if not result.consumables then result.consumables = {} end
                    result.consumables[cId] = (result.consumables[cId] or 0) + cAmount
                end
            elseif entry.type == "set_equipment" then
                -- 套装灵器独立掉落：从 setIds 中随机选一套
                local setIds = entry.setIds
                if setIds and #setIds > 0 then
                    local chosenSetId = setIds[math.random(1, #setIds)]
                    local mLevel = monster.level or 1
                    local item = LootSystem.GenerateSetEquipment(mLevel, chosenSetId)
                    if item then
                        table.insert(result.items, item)
                    end
                end
            elseif entry.type == "world_drop" then
                -- 世界掉落池：命中后从池中等权随机选一个
                local pool = MonsterData.WORLD_DROP_POOLS[entry.pool]
                if pool and pool.items and #pool.items > 0 then
                    -- 精英怪过滤 bossOnly 物品
                    local mCat = monster.category or "normal"
                    local isBoss = (mCat == "boss" or mCat == "king_boss" or mCat == "emperor_boss")
                    local candidates = {}
                    for _, pItem in ipairs(pool.items) do
                        if not pItem.bossOnly or isBoss then
                            table.insert(candidates, pItem)
                        end
                    end
                    local picked = #candidates > 0 and candidates[math.random(1, #candidates)] or nil
                    if picked and picked.type == "equipment" and picked.equipId then
                        local item = LootSystem.CreateSpecialEquipment(picked.equipId)
                        if item then
                            table.insert(result.items, item)
                        end
                    elseif picked and picked.type == "consumable" and picked.consumableId then
                        if not result.consumables then result.consumables = {} end
                        result.consumables[picked.consumableId] = (result.consumables[picked.consumableId] or 0) + 1
                    end
                end
            elseif entry.type == "equipment_pool" then
                -- 装备池：命中后从 pool 中随机选 count 个（不重复）
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
                    -- Fisher-Yates 取 count 个不重复
                    local indices = {}
                    for i = 1, #pool do indices[i] = i end
                    for i = 1, count do
                        local j = math.random(i, #pool)
                        indices[i], indices[j] = indices[j], indices[i]
                        local picked = pool[indices[i]]
                        if picked.equipId then
                            local item = LootSystem.CreateSpecialEquipment(picked.equipId)
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
---@param monsterLevel number 怪物等级
---@param minQuality string|nil 最低品质
---@param maxQuality string|nil 最高品质
---@param isBoss boolean|nil 是否为BOSS（BOSS只取最高2个Tier）
---@param tierOnly number|nil 强制仅掉落指定Tier
---@return table|nil
function LootSystem.GenerateRandomEquipment(monsterLevel, minQuality, maxQuality, isBoss, tierOnly)
    -- 随机选择装备槽
    local slot = Utils.RandomPick(EquipmentData.STANDARD_SLOTS)

    -- 联合抽取 Tier 和品质（等级驱动，BOSS限制Tier范围）
    local tier, quality = LootSystem.RollTierAndQuality(monsterLevel, minQuality, maxQuality, isBoss, tierOnly)
    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return nil end

    -- 主属性计算（提取到 EquipmentUtils）
    local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityConfig.multiplier)
    if not mainValue then return nil end

    -- 生成副属性（传入品质，橙色以上副属性波动上移）
    local subStats = LootSystem.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)

    -- 灵性属性（青·灵器及以上品质，额外1条半值副属性）
    local spiritStat = nil
    local qualityOrder = GameConfig.QUALITY_ORDER[quality] or 1
    if qualityOrder >= 6 then  -- cyan=6
        spiritStat = LootSystem.GenerateSpiritStat(tier, mainStatType, quality)
    end

    -- 装备名称（使用中式名称表）
    local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
    local baseName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

    local item = {
        id = Utils.NextId(),
        name = baseName,
        slot = slot,
        icon = LootSystem.GetSlotIcon(slot, tier),
        quality = quality,
        tier = tier,
        mainStat = { [mainStatType] = mainValue },
        subStats = subStats,
        spiritStat = spiritStat,
        sellPrice = math.floor((LootSystem.BASE_SELL_PRICE[tier] or (10 * tier)) * qualityConfig.multiplier),
    }

    -- 青色（灵器）及以上品质：出售货币改为灵韵，售价 = tier - 4（T5=1, T6=2, T7=3 ...）
    if qualityOrder >= 6 then  -- cyan=6
        item.sellCurrency = "lingYun"
        item.sellPrice = math.max(1, tier - 4)

    end

    return item
end

--- 生成套装灵器装备（BOSS 掉落专用，兼容旧掉落表调用）
--- 固定 T9 灵器(cyan)品质，附加 setId 标识
---@param monsterLevel number 怪物等级
---@param setId string 套装 ID（如 "xuesha"）
---@param slotOverride string|nil 强制指定槽位（nil=随机）
---@return table|nil
function LootSystem.GenerateSetEquipment(monsterLevel, setId, slotOverride)
    -- 固定参数：T9 灵器品质
    local tier = 9
    local quality = "cyan"
    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return nil end

    -- 槽位：优先使用 slotOverride，否则随机选取
    local slot = slotOverride or Utils.RandomPick(EquipmentData.STANDARD_SLOTS)

    -- 主属性计算（提取到 EquipmentUtils）
    local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityConfig.multiplier)
    if not mainValue then return nil end

    -- 副属性 + 灵性属性
    local subStats = LootSystem.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)
    local spiritStat = LootSystem.GenerateSpiritStat(tier, mainStatType, quality)

    -- 装备名称：套装名 + 槽位名
    local setData = EquipmentData.SetBonuses[setId]
    local setPrefix = setData and setData.name or setId
    local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
    local slotName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)
    local itemName = setPrefix .. "·" .. slotName

    local item = {
        id = Utils.NextId(),
        name = itemName,
        slot = slot,
        icon = LootSystem.GetSlotIcon(slot, tier),
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
function LootSystem.CreateSpecialEquipment(equipId)
    local template = EquipmentData.SpecialEquipment[equipId]
    if not template then return nil end

    local item = Utils.DeepCopy(template)
    item.id = Utils.NextId()
    item.equipId = equipId  -- 保存模板 ID，反序列化时精确还原
    item.sellPrice = template.sellPrice or 100  -- 特殊装备出售价（优先读模板配置）
    item.sellCurrency = template.sellCurrency    -- 出售货币类型（nil=金币, "lingYun"=灵韵）
    item.isSpecial = true

    -- 副属性波动：基于裸值(baseValue × tierMult)重算，特殊装备专用波动区间
    if item.subStats and item.tier then
        local fluct = SPECIAL_FLUCTUATION[item.quality] or { 1.0, 0.2 }
        local specialBase = fluct[1]
        local specialRange = fluct[2]

        local numTierMult = EquipmentData.SUB_STAT_TIER_MULT[item.tier] or 1.0
        local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[item.tier] or 1.0

        for _, sub in ipairs(item.subStats) do
            local baseInfo = SUB_BASE_MAP[sub.stat]
            if baseInfo and not baseInfo.linearGrowth then
                -- 裸值 = baseValue × 对应阶级倍率（不含品质偏移）
                local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTierMult or numTierMult
                local rawValue = baseInfo.baseValue * tierMult
                -- 应用特殊装备波动（品质前50%区间）
                local fluctuation = specialBase + math.random() * specialRange
                local newValue = rawValue * fluctuation
                -- 保留2位小数
                sub.value = math.floor(newValue * 100 + 0.5) / 100
            end
        end
    end

    return item
end

--- 创建法宝装备（阵营挑战动态掉落，Tier/品质为实例数据）
--- 与 CreateSpecialEquipment 不同，法宝只注册 1 个基础模板 ID，
--- Tier 和品质作为实例属性动态生成。
---@param templateId string 法宝模板 ID（如 "fabao_xuehaitu"）
---@param tier number 阶级（T3~T9）
---@param quality string 品质（如 "blue", "purple" 等）
---@return table|nil
function LootSystem.CreateFabaoEquipment(templateId, tier, quality)
    local template = EquipmentData.FabaoTemplates[templateId]
    if not template then
        print("[LootSystem] WARNING: FabaoTemplate not found: " .. tostring(templateId))
        return nil
    end

    -- quality 为 nil 时自动随机抽取（非首通场景）
    if not quality then
        -- 品质上限按 Tier：T3-T4→紫, T5-T8→橙, T9+→灵器(cyan)
        local maxQ = "purple"
        if tier >= 9 then
            maxQ = "cyan"
        elseif tier >= 5 then
            maxQ = "orange"
        end
        quality = LootSystem.RollQuality("white", maxQ)
        print("[LootSystem] Fabao quality rolled: " .. quality .. " (maxQ=" .. maxQ .. " tier=" .. tier .. ")")
    end

    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then
        print("[LootSystem] WARNING: Invalid quality for fabao: " .. tostring(quality))
        return nil
    end
    local qualityMult = qualityConfig.multiplier

    -- 主属性计算
    local mainStatValue
    if template.mainStatFormula == "xianyuan" then
        -- 仙缘公式: floor(tier × qualityMult) × mainStatBase
        mainStatValue = math.floor(tier * qualityMult) * template.mainStatBase
    else
        -- 标准公式（提取到 EquipmentUtils）
        mainStatValue = EquipmentUtils.CalcMainStatValue(
            template.mainStatBase, template.mainStatType, tier, qualityMult
        )
    end

    -- 声望等级 = tier - 2（T3→Lv.1, T4→Lv.2, ..., T9→Lv.7）
    local repLevel = math.max(1, tier - 2)
    local displayName = template.name .. "Lv." .. repLevel

    -- 图标（按 tier 映射，超范围回退到 T9）
    local icon = template.iconByTier[tier] or template.iconByTier[9] or "icon_fabao.png"

    -- 出售价格
    local sellPrice = template.sellPriceByTier[tier] or 100

    -- 副属性（复用现有装备系统：品质→条数，从 12 种池中随机排除主属性）
    local subStatCount = qualityConfig.subStatCount or 0
    local subStats = LootSystem.GenerateSubStats(subStatCount, tier, template.mainStatType, quality)

    -- 灵性属性（cyan 灵器及以上品质专属）
    local qualityOrder = GameConfig.QUALITY_ORDER[quality] or 1
    local spiritStat = nil
    if qualityOrder >= 6 then
        spiritStat = LootSystem.GenerateSpiritStat(tier, template.mainStatType, quality)
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
        isFabao   = true,       -- 标记为动态法宝（区分旧版 SpecialEquipment）
        isSpecial = true,       -- 兼容现有系统（装备栏判定等）
    }

    -- 灵器及以上出售灵韵
    if qualityOrder >= 6 then
        item.sellCurrency = "lingYun"
        item.sellPrice = math.max(1, tier - 4)
    end

    return item
end

--- 品质抽取
---@param minQuality string|nil
---@param maxQuality string|nil
---@return string
function LootSystem.RollQuality(minQuality, maxQuality)
    local minOrder = minQuality and GameConfig.QUALITY_ORDER[minQuality] or 1
    local maxOrder = maxQuality and GameConfig.QUALITY_ORDER[maxQuality] or 4

    -- 筛选可用品质
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

    -- 加权随机
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
---@return table
function LootSystem.GenerateSubStats(count, tier, excludeStat, quality)
    if count <= 0 then return {} end

    -- 可用副属性池（排除主属性）
    local pool = {}
    for _, sub in ipairs(EquipmentData.SUB_STATS) do
        if sub.stat ~= excludeStat then
            table.insert(pool, sub)
        end
    end

    -- 品质波动偏移：橙色(5)以上每级上移0.1，区间宽度不变(0.4)
    -- 白/绿/蓝/紫=0.8~1.2  橙=0.9~1.3  红=1.0~1.4  金=1.1~1.5  彩虹=1.2~1.6
    local qualityOrder = quality and GameConfig.QUALITY_ORDER[quality] or 1
    local shift = math.max(0, qualityOrder - 4) * 0.1
    local randBase = 0.8 + shift

    -- 随机选择
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
            -- 线性成长属性（如 killGold）：value = tier × qualityMult，无随机波动
            local qualityConfig = quality and GameConfig.QUALITY[quality] or nil
            local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
            value = math.floor(tier * qualityMult)
            if value <= 0 then value = 1 end
        else
            -- 百分比属性（critRate/critDmg）走独立的平缓倍率表
            local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTierMult or numTierMult
            value = sub.baseValue * tierMult
            -- 品质偏移波动
            value = value * (randBase + math.random() * 0.4)
            -- 保留2位小数，确保正值
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

--- 生成灵性属性（青·灵器及以上品质专属，半值副属性，仅排斥主属性）
---@param tier number 阶级
---@param mainStatType string 主属性类型（排斥）
---@param quality string 品质
---@return table|nil spiritStat { stat, name, value }
function LootSystem.GenerateSpiritStat(tier, mainStatType, quality)
    -- 仅排除主属性，可与副属性/洗练重复
    local pool = {}
    for _, sub in ipairs(EquipmentData.SUB_STATS) do
        if sub.stat ~= mainStatType then
            table.insert(pool, sub)
        end
    end
    if #pool == 0 then return nil end

    local sub = pool[math.random(1, #pool)]

    -- 品质波动偏移（与副属性相同）
    local qualityOrder = GameConfig.QUALITY_ORDER[quality] or 1
    local shift = math.max(0, qualityOrder - 4) * 0.1
    local randBase = 0.8 + shift

    local numTierMult = EquipmentData.SUB_STAT_TIER_MULT[tier] or 1.0
    local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[tier] or 1.0

    local value
    if sub.linearGrowth then
        local qualityConfig = GameConfig.QUALITY[quality]
        local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
        value = math.floor(tier * qualityMult) * 0.5
        if value <= 0 then value = 0.5 end
    else
        local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTierMult or numTierMult
        value = sub.baseValue * tierMult
        value = value * (randBase + math.random() * 0.4)
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

--- 获取槽位图标（根据阶级返回对应图标）
---@param slot string
---@param tier number|nil 阶级（1=T1, 2=T2, 3=T3, 4=T4），默认1
---@return string
function LootSystem.GetSlotIcon(slot, tier)
    tier = tier or 1
    -- 葫芦特殊处理：根据 tier 推导品质，返回品质图标
    if slot == "treasure" then
        local quality = "green"
        local upgradeData = EquipmentData.GOURD_UPGRADE[tier]
        if upgradeData then
            quality = upgradeData.quality or "green"
        end
        return GOURD_QUALITY_ICONS[quality] or GOURD_QUALITY_ICONS.green
    end
    local baseSlot = slot == "ring1" and "ring" or (slot == "ring2" and "ring" or slot)
    -- 图标素材 T1-T10，T11+ 回退到 T10 图标
    local iconTier = math.min(tier, 10)
    if iconTier >= 2 then
        return "icon_t" .. iconTier .. "_" .. baseSlot .. ".png"
    end
    return SLOT_ICONS_T1[slot] or "icon_weapon.png"
end

--- 根据葫芦品质获取图标路径（供外部模块使用）
---@param quality string 品质标识 (green/blue/purple/orange/cyan)
---@return string
function LootSystem.GetGourdIcon(quality)
    return GOURD_QUALITY_ICONS[quality or "green"] or GOURD_QUALITY_ICONS.green
end

-- ============================================================================
-- 自动拾取（从 main.lua 提取）
-- ============================================================================

--- 磁吸拾取范围（进入此范围触发飞向玩家）
local MAGNET_RANGE = 1.2
local MAGNET_RANGE_SQ = MAGNET_RANGE * MAGNET_RANGE
--- 磁吸飞行速度（瓦片/秒）
local MAGNET_SPEED = 8.0
--- 到达拾取的距离阈值
local PICKUP_ARRIVE_DIST = 0.3
local PICKUP_ARRIVE_DIST_SQ = PICKUP_ARRIVE_DIST * PICKUP_ARRIVE_DIST
local LOOT_PICKUP_RANGE_SQ = GameConfig.LOOT_PICKUP_RANGE * GameConfig.LOOT_PICKUP_RANGE

--- 自动拾取范围内的掉落物（带磁吸飞行效果）
---@param player table
---@param dt number
function LootSystem.AutoPickup(player, dt)
    dt = dt or 0.016
    local InventorySystem = require("systems.InventorySystem")

    -- P1-5: 循环外缓存 freeSlots，拾取成功后递减
    local freeSlots = InventorySystem.GetFreeSlots()

    for i = #GameState.lootDrops, 1, -1 do
        local drop = GameState.lootDrops[i]
        local distSq = Utils.DistanceSq(player.x, player.y, drop.x, drop.y)

        -- 已部分拾取的 drop（仅剩满堆叠消耗品）：不再重试，等自然过期
        if drop.partialLooted then goto continue_drop end

        -- 含装备的掉落物：背包满时不磁吸、不拾取
        if drop.items and #drop.items > 0 then
            if freeSlots < #drop.items then
                -- 冷却提示（避免每帧刷屏）
                if distSq <= MAGNET_RANGE_SQ then
                    if not drop.fullHintTime or (time.elapsedTime - drop.fullHintTime > 2.0) then
                        drop.fullHintTime = time.elapsedTime
                        local CombatSystem = require("systems.CombatSystem")
                        CombatSystem.AddFloatingText(
                            player.x, player.y - 0.5,
                            "背包已满", {255, 100, 100, 255}, 1.5
                        )
                    end
                end
                goto continue_drop
            end
        end

        -- 磁吸阶段：进入外圈后开始飞向玩家
        if distSq <= MAGNET_RANGE_SQ and not drop.magnetized then
            drop.magnetized = true
            -- 记录原始位置用于动画
            drop.originX = drop.x
            drop.originY = drop.y
        end

        if drop.magnetized then
            -- 飞向玩家
            local dx = player.x - drop.x
            local dy = player.y - drop.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > PICKUP_ARRIVE_DIST then
                -- 加速飞向玩家（越近越快）
                local speed = MAGNET_SPEED * (1.0 + (1.0 - d / MAGNET_RANGE) * 2.0)
                drop.x = drop.x + (dx / d) * speed * dt
                drop.y = drop.y + (dy / d) * speed * dt
            else
                distSq = 0 -- 强制进入拾取
            end
        end

        if distSq <= PICKUP_ARRIVE_DIST_SQ or (not drop.magnetized and distSq <= LOOT_PICKUP_RANGE_SQ) then
            -- 获得经验（含悟性加成：每点+1）
            if drop.expReward and drop.expReward > 0 then
                local expBonus = player:GetKillExpBonus()
                player:GainExp(drop.expReward + expBonus)
            end
            -- 获得金币（含福缘加成：每点+1）
            if drop.goldMin and drop.goldMax then
                local gold = Utils.RandomInt(drop.goldMin, drop.goldMax)
                local killGoldBonus = player:GetKillGoldBonus()
                if killGoldBonus > 0 then
                    gold = gold + killGoldBonus
                end
                player:GainGold(gold)
            end
            -- 获得灵韵（含福缘溢出加成）
            if drop.lingYun and drop.lingYun > 0 then
                local totalLingYun = drop.lingYun
                local guaranteed, chance = player:GetFortuneLingYunBonus()
                local extra = guaranteed + (chance > 0 and math.random() < chance and 1 or 0)
                totalLingYun = totalLingYun + extra
                player:GainLingYun(totalLingYun)
                -- 浮动文字提示
                local CombatSystem = require("systems.CombatSystem")
                local displayText = "+" .. totalLingYun .. " 💎"
                if extra > 0 then
                    displayText = displayText .. " (福缘+" .. extra .. ")"
                end
                CombatSystem.AddFloatingText(
                    drop.x, drop.y - 0.5,
                    displayText,
                    {200, 150, 255, 255}, 1.8
                )
                -- 触发灵韵拾取粒子特效
                local LingYunFx = require("rendering.LingYunFx")
                LingYunFx.QueuePickup(drop.x, drop.y, totalLingYun)
            end
            -- 获得消耗品（宠物食物、灵兽丹等）—— 检查返回值防丢失
            local hasConsumableFailure = false
            local hasFragmentPickup = false  -- 神器碎片拾取标记
            if drop.consumables then
                local CombatSystem = require("systems.CombatSystem")
                for cId, cAmount in pairs(drop.consumables) do
                    local ok, added = InventorySystem.AddConsumable(cId, cAmount)
                    local cData = GameConfig.PET_FOOD[cId] or GameConfig.PET_MATERIALS[cId]
                    local PetSkillData = require("config.PetSkillData")
                    local bookData = PetSkillData.SKILL_BOOKS[cId]
                    cData = cData or bookData

                    if added > 0 then
                        -- 成功拾取（全部或部分），显示绿色浮动文字
                        if cData then
                            local icon = IconUtils.GetTextIcon(cData.icon, "💊")
                            CombatSystem.AddFloatingText(
                                drop.x, drop.y - 0.5,
                                icon .. " " .. cData.name .. (added > 1 and ("×" .. added) or ""),
                                {180, 255, 180, 255}, 2.0
                            )
                        end
                        -- 神器碎片检测（rake_fragment_* / bagua_fragment_* / tiandi_fragment_*）
                        if string.find(cId, "_fragment_") then
                            hasFragmentPickup = true
                        end
                        -- 扣减 drop 中的数量
                        local remaining = cAmount - added
                        if remaining <= 0 then
                            drop.consumables[cId] = nil
                        else
                            drop.consumables[cId] = remaining
                        end
                    end

                    if not ok then
                        hasConsumableFailure = true
                        if cData then
                            CombatSystem.AddFloatingText(
                                drop.x, drop.y - 0.5,
                                cData.name .. " 堆叠已满",
                                {255, 100, 100, 255}, 2.0
                            )
                        end
                    end
                end
                -- 清理空 table
                if not next(drop.consumables) then
                    drop.consumables = nil
                end
            end
            -- 神器碎片拾取后立即存档，防止回档丢失（高价值低频掉落）
            if hasFragmentPickup then
                print("[Pickup] Artifact fragment acquired, requesting save")
                EventBus.Emit("save_request")
            end
            -- 获得装备（背包空间已在上方检查通过）
            if drop.items and #drop.items > 0 then
                local CombatSystem = require("systems.CombatSystem")
                for _, item in ipairs(drop.items) do
                    local ok = InventorySystem.AddItem(item)
                    if ok then
                        freeSlots = freeSlots - 1  -- P1-5: 同步递减
                        local qColor = GameConfig.QUALITY[item.quality]
                        local qName = qColor and qColor.name or "普通"
                        print("[Pickup] Got equipment: [" .. qName .. "] " .. item.name)
                        CombatSystem.AddFloatingText(
                            drop.x, drop.y - 0.3,
                            item.name,
                            qColor and qColor.color or {255, 255, 255, 255},
                            2.0
                        )
                        -- 特殊装备拾取后存档，防止回档丢失
                        if item.isSpecial then
                            print("[Pickup] Special equipment acquired, requesting save: " .. item.name)
                            EventBus.Emit("save_request")
                        end
                    end
                end
            end
            -- 移除掉落物（消耗品有失败的则保留 drop）
            if hasConsumableFailure then
                drop.partialLooted = true
                -- 清零已拾取的经验/金币/灵韵，防止重复领取
                drop.expReward = nil
                drop.goldMin = nil
                drop.goldMax = nil
                drop.lingYun = nil
            else
                table.remove(GameState.lootDrops, i)
            end
        end
        ::continue_drop::
    end
end

-- ============================================================================
-- 宠物拾取（拾荒伴侣）
-- ============================================================================

local PET_PICKUP_RANGE_SQ = GameConfig.PET_PICKUP_RANGE * GameConfig.PET_PICKUP_RANGE

--- 查找宠物可捡的最近掉落物
---@param petX number 宠物位置X
---@param petY number 宠物位置Y
---@param blacklist table|nil 拾取失败黑名单 { [dropId] = expireTime }
---@return table|nil 最近的可捡掉落物
function LootSystem.FindPetPickable(petX, petY, blacklist)
    local bestDrop = nil
    local bestDistSq = PET_PICKUP_RANGE_SQ

    for _, drop in ipairs(GameState.lootDrops) do
        -- 延迟检查：落地不满 PET_PICKUP_DELAY 秒不可捡
        local age = time.elapsedTime - (drop.spawnTime or 0)
        if age < GameConfig.PET_PICKUP_DELAY then goto next_drop end
        -- 已被玩家磁吸中的不可捡
        if drop.magnetized then goto next_drop end
        -- 含装备的掉落物：宠物不捡，留给玩家
        if drop.items and #drop.items > 0 then goto next_drop end
        -- 黑名单过滤（拾取失败的 drop 一段时间内不重试）
        if blacklist and blacklist[drop.id] then goto next_drop end

        local distSq = Utils.DistanceSq(petX, petY, drop.x, drop.y)
        if distSq < bestDistSq then
            bestDistSq = distSq
            bestDrop = drop
        end
        ::next_drop::
    end
    return bestDrop
end

--- 宠物执行拾取（部分拾取：经验/金币/灵韵始终拿，消耗品按堆叠情况拿）
--- 狗不拾取装备，含装备的 drop 直接跳过。
---@param player table 玩家实例
---@param drop table 掉落物
---@return boolean 是否完全拾取成功（false=有消耗品未能拾取）
function LootSystem.PetPickup(player, drop)
    local InventorySystem = require("systems.InventorySystem")
    local CombatSystem = require("systems.CombatSystem")

    -- Guard: 狗不拾取装备
    if drop.items and #drop.items > 0 then return false end

    -- 1) 始终拾取：经验（含悟性加成），拾取后清 nil 防重复
    if drop.expReward and drop.expReward > 0 then
        local expBonus = player:GetKillExpBonus()
        player:GainExp(drop.expReward + expBonus)
        drop.expReward = nil
    end

    -- 2) 始终拾取：金币（含福缘加成）
    if drop.goldMin and drop.goldMax then
        local gold = Utils.RandomInt(drop.goldMin, drop.goldMax)
        local killGoldBonus = player:GetKillGoldBonus()
        if killGoldBonus > 0 then
            gold = gold + killGoldBonus
        end
        player:GainGold(gold)
        drop.goldMin = nil
        drop.goldMax = nil
    end

    -- 3) 始终拾取：灵韵（含福缘溢出加成）
    if drop.lingYun and drop.lingYun > 0 then
        local totalLingYun = drop.lingYun
        local guaranteed, chance = player:GetFortuneLingYunBonus()
        local extra = guaranteed + (chance > 0 and math.random() < chance and 1 or 0)
        totalLingYun = totalLingYun + extra
        player:GainLingYun(totalLingYun)
        local displayText = "+" .. totalLingYun .. " 💎"
        if extra > 0 then
            displayText = displayText .. " (福缘+" .. extra .. ")"
        end
        CombatSystem.AddFloatingText(
            drop.x, drop.y - 0.5,
            displayText,
            {200, 150, 255, 255}, 1.8
        )
        local LingYunFx = require("rendering.LingYunFx")
        LingYunFx.QueuePickup(drop.x, drop.y, totalLingYun)
        drop.lingYun = nil
    end

    -- 4) 逐个尝试消耗品（按实际写入数量扣减 drop）
    local hasConsumableFailure = false
    local hasFragmentPickup = false  -- 神器碎片拾取标记
    if drop.consumables then
        for cId, cAmount in pairs(drop.consumables) do
            local ok, added = InventorySystem.AddConsumable(cId, cAmount)
            local cData = GameConfig.PET_FOOD[cId] or GameConfig.PET_MATERIALS[cId]
            local PetSkillData = require("config.PetSkillData")
            local bookData = PetSkillData.SKILL_BOOKS[cId]
            cData = cData or bookData

            if added > 0 then
                -- 成功拾取（全部或部分），显示绿色浮动文字
                if cData then
                    local icon = IconUtils.GetTextIcon(cData.icon, "💊")
                    CombatSystem.AddFloatingText(
                        drop.x, drop.y - 0.5,
                        icon .. " " .. cData.name .. (added > 1 and ("×" .. added) or ""),
                        {180, 255, 180, 255}, 2.0
                    )
                end
                -- 神器碎片检测（rake_fragment_* / bagua_fragment_* / tiandi_fragment_*）
                if string.find(cId, "_fragment_") then
                    hasFragmentPickup = true
                end
                -- 扣减 drop 中的数量
                local remaining = cAmount - added
                if remaining <= 0 then
                    drop.consumables[cId] = nil
                else
                    drop.consumables[cId] = remaining
                end
            end

            if not ok then
                -- 有未拾取的部分，显示红色浮动文字
                hasConsumableFailure = true
                if cData then
                    CombatSystem.AddFloatingText(
                        drop.x, drop.y - 0.5,
                        cData.name .. " 堆叠已满",
                        {255, 100, 100, 255}, 2.0
                    )
                end
            end
        end
        -- 清理空 table
        if not next(drop.consumables) then
            drop.consumables = nil
        end
    end
    -- 神器碎片拾取后立即存档，防止回档丢失（高价值低频掉落）
    if hasFragmentPickup then
        print("[PetPickup] Artifact fragment acquired, requesting save")
        EventBus.Emit("save_request")
    end

    -- 5) 判断是否完全拾取
    if not hasConsumableFailure then
        -- 全部成功，移除 drop
        for i = #GameState.lootDrops, 1, -1 do
            if GameState.lootDrops[i].id == drop.id then
                table.remove(GameState.lootDrops, i)
                break
            end
        end
        return true
    else
        -- 部分成功，drop 保留在地面（经验/金币/灵韵已清零）
        drop.partialLooted = true
        return false
    end
end

-- ============================================================================
-- 掉落物计时器（从 main.lua 提取）
-- ============================================================================

--- 更新掉落物过期计时
---@param dt number
function LootSystem.UpdateTimers(dt)
    for i = #GameState.lootDrops, 1, -1 do
        local drop = GameState.lootDrops[i]
        drop.timer = drop.timer - dt
        if drop.timer <= 0 then
            table.remove(GameState.lootDrops, i)
        end
    end
end

-- ============================================================================
-- 活动掉落系统（设计文档 §3.4）
-- ============================================================================

--- 获取当前活动对某怪物的掉率表
--- 优先级：怪物 ID 覆盖 > 章节+阶级
---@param event table EventConfig.ACTIVE_EVENT
---@param monster table 怪物数据（需有 typeId, category）
---@param chapterId number 当前章节 ID
---@return table|nil { [itemId] = dropChance }
function LootSystem.GetEventDropRates(event, monster, chapterId)
    -- 优先级1：怪物 ID 覆盖（四龙等特殊 BOSS）
    if event.monsterOverrides and event.monsterOverrides[monster.typeId] then
        return event.monsterOverrides[monster.typeId]
    end
    -- 优先级2：章节 + 阶级
    local chapterRates = event.dropRates[chapterId]
    if not chapterRates then return nil end
    return chapterRates[monster.category]
end

--- 为已有的掉落结果追加活动道具掉落
--- 在 GenerateDrops 之后调用，独立于常规掉落
---@param dropResult table GenerateDrops 的返回值
---@param monster table 怪物数据
function LootSystem.RollEventDrops(dropResult, monster)
    local EventConfig = require("config.EventConfig")
    if not EventConfig.IsActive() then return end

    local event = EventConfig.ACTIVE_EVENT
    local chapterId = GameState.currentChapter or 1
    local rates = LootSystem.GetEventDropRates(event, monster, chapterId)
    if not rates then return end

    -- 对每个活动道具独立判定
    if not dropResult.consumables then dropResult.consumables = {} end
    for itemId, chance in pairs(rates) do
        if Utils.Roll(chance) then
            dropResult.consumables[itemId] = (dropResult.consumables[itemId] or 0) + 1
        end
    end
end

--- 为仙缘宝箱生成 3 件候选装备（固定 tier + quality，保底 1 条仙缘副属性）
---@param tier number 固定 tier
---@param quality string 固定品质常量（"purple"/"orange"/"cyan"）
---@param guaranteedSubStat string 保底仙缘副属性（"constitution"/"fortune"/"wisdom"/"physique"）
---@return table[] items 3 件装备
function LootSystem.GenerateXianyuanReward(tier, quality, guaranteedSubStat)
    local XianyuanChestConfig = require("config.XianyuanChestConfig")
    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return {} end
    local qualityMult = qualityConfig.multiplier
    local qualityOrder = GameConfig.QUALITY_ORDER[quality] or 1

    -- 1. 从 SLOT_POOL 中随机抽 3 个不重复槽位
    local pool = {}
    for _, s in ipairs(XianyuanChestConfig.SLOT_POOL) do
        pool[#pool + 1] = s
    end
    local slots = {}
    for i = 1, 3 do
        local idx = math.random(1, #pool)
        slots[i] = pool[idx]
        table.remove(pool, idx)
    end

    -- 保底副属性信息
    local guaranteedInfo = SUB_BASE_MAP[guaranteedSubStat]
    -- 保底副属性值：线性公式 floor(tier * qualityMult)
    local guaranteedValue = math.floor(tier * qualityMult)
    if guaranteedValue <= 0 then guaranteedValue = 1 end

    local items = {}
    for i = 1, 3 do
        local slot = slots[i]

        -- 主属性计算
        local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityMult)
        if not mainValue then goto continue_slot end

        -- 生成副属性（传入品质）
        local subStats = LootSystem.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)

        -- 强制注入保底仙缘副属性
        if guaranteedInfo then
            local found = false
            for _, sub in ipairs(subStats) do
                if sub.stat == guaranteedSubStat then
                    -- 已存在：保留较大值（保底值通常 >= 随机值，取 max 确保不亏）
                    sub.value = math.max(sub.value, guaranteedValue)
                    found = true
                    break
                end
            end
            if not found then
                -- 未存在：替换最后一条随机副属性（保持总数不超过 subStatCount）
                subStats[#subStats] = {
                    stat = guaranteedSubStat,
                    name = guaranteedInfo.name,
                    value = guaranteedValue,
                }
            end
        end

        -- 灵性属性（cyan 灵器及以上品质）
        local spiritStat = nil
        if qualityOrder >= 6 then
            spiritStat = LootSystem.GenerateSpiritStat(tier, mainStatType, quality)
        end

        -- 装备名称
        local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
        local baseName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

        local item = {
            id = Utils.NextId(),
            name = baseName,
            slot = slot,
            icon = LootSystem.GetSlotIcon(slot, tier),
            quality = quality,
            tier = tier,
            mainStat = { [mainStatType] = mainValue },
            subStats = subStats,
            spiritStat = spiritStat,
            sellPrice = math.floor((LootSystem.BASE_SELL_PRICE[tier] or (10 * tier)) * qualityMult),
            isXianyuanReward = true,
        }

        -- 灵器及以上出售灵韵
        if qualityOrder >= 6 then
            item.sellCurrency = "lingYun"
            item.sellPrice = math.max(1, tier - 4)
        end

        items[#items + 1] = item
        ::continue_slot::
    end

    return items
end

--- 灵器打造：生成固定 T9+cyan 的标准灵器装备（背包打造专用）
--- 与 GenerateRandomEquipment 不同，此函数直接指定 tier/quality/slot，不走等级驱动。
---@param slot string|nil 指定槽位（nil=从 LINGQI_FORGE_SLOTS 随机）
---@return table|nil
function LootSystem.ForgeRandomLingqi(slot)
    local tier = 9
    local quality = "cyan"
    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return nil end

    slot = slot or Utils.RandomPick(EquipmentData.LINGQI_FORGE_SLOTS)

    -- 主属性计算
    local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityConfig.multiplier)
    if not mainValue then return nil end

    -- 副属性 + 灵性属性
    local subStats = LootSystem.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)
    local spiritStat = LootSystem.GenerateSpiritStat(tier, mainStatType, quality)

    -- 装备名称
    local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
    local baseName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

    local item = {
        id = Utils.NextId(),
        name = baseName,
        slot = slot,
        icon = LootSystem.GetSlotIcon(slot, tier),
        quality = quality,
        tier = tier,
        mainStat = { [mainStatType] = mainValue },
        subStats = subStats,
        spiritStat = spiritStat,
        sellCurrency = "lingYun",
        sellPrice = math.max(1, tier - 4),
    }

    return item
end

--- 灵器打造：生成套装灵器（30%概率时调用）
--- 从所有套装中随机选取，固定 T9+cyan，随机槽位
---@return table|nil
function LootSystem.ForgeRandomSetLingqi()
    -- 从所有套装 ID 中随机选一个
    local setIds = {}
    for setId, _ in pairs(EquipmentData.SetBonuses) do
        table.insert(setIds, setId)
    end
    if #setIds == 0 then return nil end

    local setId = setIds[math.random(1, #setIds)]
    -- 复用 GenerateSetEquipment（已硬编码 T9+cyan）
    return LootSystem.GenerateSetEquipment(100, setId, nil)
end

return LootSystem
