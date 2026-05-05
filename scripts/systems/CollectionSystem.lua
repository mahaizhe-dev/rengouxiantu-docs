-- ============================================================================
-- CollectionSystem.lua - 神兵图录系统（数据层）
-- 独特装备图鉴：上交背包中的独特装备，获得永久属性加成
-- ============================================================================

local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local CollectionSystem = {}

-- 已收录的装备集合 { [equipId] = true }
CollectionSystem.collected = {}

--- 初始化
function CollectionSystem.Init()
    CollectionSystem.collected = {}
    print("[CollectionSystem] Initialized")
end

--- 获取图录条目总数
---@return number
function CollectionSystem.GetTotalCount()
    return #EquipmentData.Collection.order
end

--- 获取已收录数量
---@return number
function CollectionSystem.GetCollectedCount()
    local count = 0
    for _ in pairs(CollectionSystem.collected) do
        count = count + 1
    end
    return count
end

--- 某个装备是否已收录
---@param equipId string
---@return boolean
function CollectionSystem.IsCollected(equipId)
    return CollectionSystem.collected[equipId] == true
end

--- 在背包中查找指定独特装备
--- 返回背包槽位索引，未找到返回 nil
---@param equipId string
---@return number|nil slotIndex
function CollectionSystem.FindInBackpack(equipId)
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return nil end

    local GameConfig = require("config.GameConfig")
    local template = EquipmentData.SpecialEquipment[equipId]
    if not template then return nil end

    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item then
            if template.isFabaoCollection then
                -- 法宝图鉴：按 templateId + tier 匹配
                if item.isFabao and item.equipId == template.fabaoTemplateId
                    and item.tier == template.fabaoTier and item.quality == template.quality then
                    return i
                end
            else
                -- 常规独特装备：按名称匹配
                if item.isSpecial and item.name == template.name then
                    return i
                end
            end
        end
    end
    return nil
end

--- 上交装备进行收录
--- 消耗背包中对应的独特装备，记录为已收录
---@param equipId string
---@return boolean success
---@return string message
function CollectionSystem.Submit(equipId)
    -- 检查是否已收录
    if CollectionSystem.IsCollected(equipId) then
        return false, "已收录"
    end

    -- 检查图录中是否存在该条目
    local entry = EquipmentData.Collection.entries[equipId]
    if not entry then
        return false, "无效条目"
    end

    -- 查找背包中的装备
    local slotIndex = CollectionSystem.FindInBackpack(equipId)
    if not slotIndex then
        return false, "背包中没有该装备"
    end

    -- 消耗背包中的装备
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    mgr:SetInventoryItem(slotIndex, nil)

    -- 标记为已收录
    CollectionSystem.collected[equipId] = true

    -- 重算属性
    CollectionSystem.RecalcBonuses()

    EventBus.Emit("collection_submitted", equipId)

    local template = EquipmentData.SpecialEquipment[equipId]
    print("[CollectionSystem] Collected: " .. (template and template.name or equipId))
    return true, "收录成功"
end

--- 重新计算图录总加成并应用到玩家
function CollectionSystem.RecalcBonuses()
    local player = GameState.player
    if not player then return end

    local totalAtk = 0
    local totalDef = 0
    local totalHp = 0
    local totalHpRegen = 0
    local totalFortune = 0
    local totalKillHeal = 0
    local totalHeavyHit = 0
    local totalCritRate = 0
    local totalWisdom = 0
    local totalConstitution = 0
    local totalPhysique = 0

    for equipId, _ in pairs(CollectionSystem.collected) do
        local entry = EquipmentData.Collection.entries[equipId]
        if entry and entry.bonus then
            totalAtk = totalAtk + (entry.bonus.atk or 0)
            totalDef = totalDef + (entry.bonus.def or 0)
            totalHp = totalHp + (entry.bonus.maxHp or 0)
            totalHpRegen = totalHpRegen + (entry.bonus.hpRegen or 0)
            totalFortune = totalFortune + (entry.bonus.fortune or 0)
            totalKillHeal = totalKillHeal + (entry.bonus.killHeal or 0)
            totalHeavyHit = totalHeavyHit + (entry.bonus.heavyHit or 0)
            totalCritRate = totalCritRate + (entry.bonus.critRate or 0)
            totalWisdom = totalWisdom + (entry.bonus.wisdom or 0)
            totalConstitution = totalConstitution + (entry.bonus.constitution or 0)
            totalPhysique = totalPhysique + (entry.bonus.physique or 0)
        end
    end

    player.collectionAtk = totalAtk
    player.collectionDef = totalDef
    player.collectionHp = totalHp
    player.collectionHpRegen = totalHpRegen
    player.collectionFortune = totalFortune
    player.collectionKillHeal = totalKillHeal
    player.collectionHeavyHit = totalHeavyHit
    player.collectionCritRate = totalCritRate
    player.collectionWisdom = totalWisdom
    player.collectionConstitution = totalConstitution
    player.collectionPhysique = totalPhysique

    EventBus.Emit("collection_stats_changed")
end

--- 获取图录总加成属性
---@return table {atk, def, maxHp, hpRegen, fortune, killHeal, heavyHit, critRate, wisdom, constitution, physique}
function CollectionSystem.GetBonusSummary()
    local player = GameState.player
    if not player then
        return { atk = 0, def = 0, maxHp = 0, hpRegen = 0, fortune = 0, killHeal = 0, heavyHit = 0, critRate = 0, wisdom = 0, constitution = 0, physique = 0 }
    end
    return {
        atk = player.collectionAtk or 0,
        def = player.collectionDef or 0,
        maxHp = player.collectionHp or 0,
        hpRegen = player.collectionHpRegen or 0,
        fortune = player.collectionFortune or 0,
        killHeal = player.collectionKillHeal or 0,
        heavyHit = player.collectionHeavyHit or 0,
        critRate = player.collectionCritRate or 0,
        wisdom = player.collectionWisdom or 0,
        constitution = player.collectionConstitution or 0,
        physique = player.collectionPhysique or 0,
    }
end

--- 序列化（存档用）
---@return table
function CollectionSystem.Serialize()
    local list = {}
    for equipId, _ in pairs(CollectionSystem.collected) do
        table.insert(list, equipId)
    end
    return list
end

--- 反序列化（读档用）
---@param data table
function CollectionSystem.Deserialize(data)
    CollectionSystem.collected = {}
    local skipped = 0
    if data and type(data) == "table" then
        for _, equipId in ipairs(data) do
            -- 只保留当前 Collection.entries 中仍存在的条目，过滤已删除的旧图鉴
            if EquipmentData.Collection.entries[equipId] then
                CollectionSystem.collected[equipId] = true
            else
                skipped = skipped + 1
                print("[CollectionSystem] Skipped removed entry: " .. tostring(equipId))
            end
        end
    end
    CollectionSystem.RecalcBonuses()
    local count = CollectionSystem.GetCollectedCount()
    print("[CollectionSystem] Restored " .. count .. " entries" ..
        (skipped > 0 and (", skipped " .. skipped .. " removed") or ""))
end

return CollectionSystem
