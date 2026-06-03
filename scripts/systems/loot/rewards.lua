--- LootSystem / rewards sub-module
--- Event drops, Xianyuan chest rewards, Lingqi forging
--- (Stateless — no mutable module-level state)

local shared = require("systems.loot.shared")
local GameConfig = shared.GameConfig
local EquipmentData = shared.EquipmentData
local GameState = shared.GameState
local Utils = shared.Utils
local EquipmentUtils = shared.EquipmentUtils
local SUB_BASE_MAP = shared.SUB_BASE_MAP
local BASE_SELL_PRICE = shared.BASE_SELL_PRICE

local generation = require("systems.loot.generation")

local M = {}

--------------------------------------------------------------------------------
-- Event Drops
--------------------------------------------------------------------------------

--- BOSS 类别判定（boss / king_boss / emperor_boss / saint_boss）
local BOSS_CATEGORIES = {
    boss = true, king_boss = true, emperor_boss = true, saint_boss = true,
}

function M.GetEventDropRates(event, monster, chapterId)
    -- 返回章节 + 怪物阶级对应的普通掉落率（拨浪鼓等）
    local chapterRates = event.dropRates[chapterId]
    if not chapterRates then return nil end
    return chapterRates[monster.category]
end

--- 为已有的掉落结果追加活动道具掉落
--- 在 GenerateDrops 之后调用，独立于常规掉落
--- 两段独立判定：
---   第一段：普通开启物（章节 + category），所有怪都走
---   第二段：稀有开启物，仅 BOSS 生效（monsterOverrides 优先 > realmDropRates）
---@param dropResult table GenerateDrops 的返回值
---@param monster table 怪物数据
function M.RollEventDrops(dropResult, monster)
    local EventConfig = require("config.EventConfig")
    if not EventConfig.IsActive() then return end

    local event = EventConfig.ACTIVE_EVENT
    local chapterId = GameState.currentChapter or 1
    if not dropResult.consumables then dropResult.consumables = {} end

    -- ═══ 第一段：普通开启物（章节 + category）═══
    -- 所有怪物（包括四仙剑）都走这段，掉拨浪鼓
    local rates = M.GetEventDropRates(event, monster, chapterId)
    if rates then
        for itemId, chance in pairs(rates) do
            if Utils.Roll(chance) then
                dropResult.consumables[itemId] = (dropResult.consumables[itemId] or 0) + 1
            end
        end
    end

    -- ═══ 第二段：稀有开启物（仅 BOSS 生效）═══
    -- 优先级：monsterOverrides（按 typeId 精确匹配）> realmDropRates（按境界阶梯）
    if not BOSS_CATEGORIES[monster.category] then
        return  -- 非 BOSS 不参与稀有掉落
    end

    if event.monsterOverrides and event.monsterOverrides[monster.typeId] then
        -- 四仙剑等特殊 BOSS：使用专属稀有概率
        local overrideRates = event.monsterOverrides[monster.typeId]
        for itemId, chance in pairs(overrideRates) do
            if Utils.Roll(chance) then
                dropResult.consumables[itemId] = (dropResult.consumables[itemId] or 0) + 1
            end
        end
        return  -- override 和 realmDropRates 互斥，不双重判定
    end

    if event.realmDropRates and monster.realm then
        local realmRates = event.realmDropRates[monster.realm]
        if realmRates then
            for itemId, chance in pairs(realmRates) do
                if Utils.Roll(chance) then
                    dropResult.consumables[itemId] = (dropResult.consumables[itemId] or 0) + 1
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Xianyuan Chest Rewards
--------------------------------------------------------------------------------

--- 为仙缘宝箱生成 3 件候选装备（固定 tier + quality，保底 1 条仙缘副属性）
---@param tier number 固定 tier
---@param quality string 固定品质常量（"purple"/"orange"/"cyan"）
---@param guaranteedSubStat string 保底仙缘副属性（"constitution"/"fortune"/"wisdom"/"physique"）
---@return table[] items 3 件装备
function M.GenerateXianyuanReward(tier, quality, guaranteedSubStat)
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
        local subStats = generation.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)

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
            spiritStat = generation.GenerateSpiritStat(tier, mainStatType, quality)
        end

        -- 装备名称
        local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
        local baseName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

        local item = {
            id = Utils.NextId(),
            name = baseName,
            slot = slot,
            icon = generation.GetSlotIcon(slot, tier),
            quality = quality,
            tier = tier,
            mainStat = { [mainStatType] = mainValue },
            subStats = subStats,
            spiritStat = spiritStat,
            sellPrice = math.floor((BASE_SELL_PRICE[tier] or (10 * tier)) * qualityMult),
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

--- 为仙缘宝箱（第五章）生成 3 件候选套装灵器（固定 tier=10，随机套装 ID，保底 1 条仙缘副属性）
--- 与 GenerateXianyuanReward 的区别：每件装备携带 setId，名称含套装前缀
---@param tier number 固定 tier（第五章传 10）
---@param guaranteedSubStat string 保底仙缘副属性（"constitution"/"fortune"/"wisdom"/"physique"）
---@return table[] items 3 件套装灵器（可能不足 3 件，由调用方检查）
function M.GenerateXianyuanSetReward(tier, guaranteedSubStat)
    local XianyuanChestConfig = require("config.XianyuanChestConfig")
    local quality = "cyan"
    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return {} end
    local qualityMult = qualityConfig.multiplier
    local qualityOrder = GameConfig.QUALITY_ORDER[quality] or 1

    -- 仙劫四套装 ID
    local SET_IDS = { "xuesha", "qingyun", "fengmo", "haoqi" }

    -- 从 SLOT_POOL 中随机抽 3 个不重复槽位
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
    local guaranteedValue = math.floor(tier * qualityMult)
    if guaranteedValue <= 0 then guaranteedValue = 1 end

    local items = {}
    for i = 1, 3 do
        local slot = slots[i]
        -- 每件随机选一个套装（允许重复，玩家可选择凑套）
        local setId = SET_IDS[math.random(1, #SET_IDS)]

        -- 主属性计算
        local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityMult)
        if not mainValue then goto continue_set_slot end

        -- 生成副属性
        local subStats = generation.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)

        -- 强制注入保底仙缘副属性
        if guaranteedInfo then
            local found = false
            for _, sub in ipairs(subStats) do
                if sub.stat == guaranteedSubStat then
                    sub.value = math.max(sub.value, guaranteedValue)
                    found = true
                    break
                end
            end
            if not found then
                subStats[#subStats] = {
                    stat = guaranteedSubStat,
                    name = guaranteedInfo.name,
                    value = guaranteedValue,
                }
            end
        end

        -- 灵性属性（cyan 灵器）
        local spiritStat = nil
        if qualityOrder >= 6 then
            spiritStat = generation.GenerateSpiritStat(tier, mainStatType, quality)
        end

        -- 装备名称：套装前缀 + 槽位名
        local setData = EquipmentData.SetBonuses[setId]
        local setPrefix = setData and setData.name or setId
        local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
        local slotName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)
        local itemName = setPrefix .. "·" .. slotName

        local item = {
            id = Utils.NextId(),
            name = itemName,
            slot = slot,
            icon = generation.GetSlotIcon(slot, tier),
            quality = quality,
            tier = tier,
            mainStat = { [mainStatType] = mainValue },
            subStats = subStats,
            spiritStat = spiritStat,
            setId = setId,
            sellCurrency = "lingYun",
            sellPrice = math.max(1, tier - 4),
            isXianyuanReward = true,
        }

        items[#items + 1] = item
        ::continue_set_slot::
    end

    return items
end

--------------------------------------------------------------------------------
-- Lingqi Forging
--------------------------------------------------------------------------------

--- 灵器打造：生成固定 T9+cyan 的标准灵器装备（背包打造专用）
--- 与 GenerateRandomEquipment 不同，此函数直接指定 tier/quality/slot，不走等级驱动。
---@param slot string|nil 指定槽位（nil=从 LINGQI_FORGE_SLOTS 随机）
---@return table|nil
function M.ForgeRandomLingqi(slot)
    local tier = 9
    local quality = "cyan"
    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return nil end

    slot = slot or Utils.RandomPick(EquipmentData.LINGQI_FORGE_SLOTS)

    -- 主属性计算
    local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityConfig.multiplier)
    if not mainValue then return nil end

    -- 副属性 + 灵性属性
    local subStats = generation.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType, quality)
    local spiritStat = generation.GenerateSpiritStat(tier, mainStatType, quality)

    -- 装备名称
    local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
    local baseName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

    local item = {
        id = Utils.NextId(),
        name = baseName,
        slot = slot,
        icon = generation.GetSlotIcon(slot, tier),
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
--- 从制式套装白名单中随机选取，固定 T9+cyan，随机槽位
---@return table|nil
function M.ForgeRandomSetLingqi()
    -- 从白名单中随机选一个制式套装
    local pool = EquipmentData.FORGE_SET_POOLS and EquipmentData.FORGE_SET_POOLS.lingqi_t9_standard
    if not pool or #pool == 0 then
        print("[LootSystem] ForgeRandomSetLingqi: FORGE_SET_POOLS.lingqi_t9_standard is empty!")
        return nil
    end

    local setId = pool[math.random(1, #pool)]
    -- 复用 GenerateSetEquipment（已硬编码 T9+cyan）
    return generation.GenerateSetEquipment(100, setId, nil)
end

return M
