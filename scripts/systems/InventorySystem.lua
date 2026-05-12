-- ============================================================================
-- InventorySystem.lua - 背包与装备系统（数据层）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local InventorySystem = {}

---@type InventoryManager|nil
local manager_ = nil

--- 初始化背包系统
function InventorySystem.Init()
    -- 构建装备槽配置（10个槽位）
    local equipSlots = {}
    for _, slotId in ipairs(EquipmentData.SLOTS) do
        -- ring1/ring2 都接受 "ring" 类型的物品
        local slotType = slotId
        if slotId == "ring1" or slotId == "ring2" then
            slotType = "ring"
        end
        equipSlots[slotId] = { type = slotType, item = nil }
    end

    manager_ = UI.InventoryManager.new({
        inventorySize = GameConfig.BACKPACK_SIZE,
        equipmentSlots = equipSlots,
    })

    -- 装备变更时刷新属性加成
    manager_.onChange = function()
        InventorySystem.RecalcEquipStats()
    end

    print("[InventorySystem] Initialized with " .. GameConfig.BACKPACK_SIZE .. " slots")
end

--- 获取 InventoryManager 实例（供 UI 使用）
---@return InventoryManager
function InventorySystem.GetManager()
    return manager_
end

--- 添加物品到背包
---@param item table
---@return boolean success
---@return number|nil slotIndex
function InventorySystem.AddItem(item)
    if not manager_ then return false, nil end

    -- ring 类型装备统一 type 标记
    if item.slot == "ring1" or item.slot == "ring2" then
        item.type = "ring"
    else
        item.type = item.slot or item.type
    end

    local success, idx = manager_:AddToInventory(item)
    if success then
        EventBus.Emit("inventory_item_added", item, idx)
    else
        print("[InventorySystem] Backpack full! Cannot add: " .. (item.name or "?"))
        EventBus.Emit("inventory_full", item)
    end
    return success, idx
end

--- 自动拾取 pendingItems 到背包
function InventorySystem.PickupPendingItems()
    local pending = GameState.pendingItems
    for i = #pending, 1, -1 do
        local ok = InventorySystem.AddItem(pending[i])
        if ok then
            table.remove(pending, i)
        else
            break  -- 背包满了
        end
    end
end

--- 出售物品（从背包中移除并获得金币）
---@param slotIndex number 背包槽位
---@return boolean
function InventorySystem.SellItem(slotIndex)
    if not manager_ then return false end
    local item = manager_:GetInventoryItem(slotIndex)
    if not item then return false end

    local unitPrice = item.sellPrice or 1
    -- 消耗品优先从配置表读取售价（存档中可能缺失或为 0）
    if item.consumableId then
        local cfgData = GameConfig.CONSUMABLES[item.consumableId]
        if cfgData and cfgData.sellPrice and cfgData.sellPrice > 0 then
            unitPrice = cfgData.sellPrice
        end
    end
    local count = item.count or 1
    local price = unitPrice * count
    local player = GameState.player
    if player then
        if item.sellCurrency == "lingYun" then
            player:GainLingYun(price)
        else
            player:GainGold(price)
        end
    end

    local currencyName = item.sellCurrency == "lingYun" and "灵韵" or "金币"
    manager_:SetInventoryItem(slotIndex, nil)
    EventBus.Emit("item_sold", item, price, item.sellCurrency)
    print("[InventorySystem] Sold " .. item.name .. " x" .. count .. " for " .. price .. " " .. currencyName)
    return true
end

--- 批量出售指定品质及以下的装备（背包中非消耗品）
---@param qualitySetOrMax table|string 品质集合（如 {white=true, green=true}）或最高品质字符串（向后兼容）
---@return number soldCount, number totalGold
function InventorySystem.SellByQuality(qualitySetOrMax)
    if not manager_ then return 0, 0 end

    -- 兼容旧调用方式：传字符串时转换为集合
    local qualitySet
    if type(qualitySetOrMax) == "string" then
        local maxOrder = GameConfig.QUALITY_ORDER[qualitySetOrMax] or 0
        qualitySet = {}
        for q, order in pairs(GameConfig.QUALITY_ORDER) do
            if order <= maxOrder then qualitySet[q] = true end
        end
    else
        qualitySet = qualitySetOrMax or {}
    end

    local soldCount = 0
    local totalGold = 0
    local totalLingYun = 0

    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category ~= "consumable" and item.quality then
            if qualitySet[item.quality] then
                local price = (item.sellPrice or 1) * (item.count or 1)
                if item.sellCurrency == "lingYun" then
                    totalLingYun = totalLingYun + price
                else
                    totalGold = totalGold + price
                end
                manager_:SetInventoryItem(i, nil)
                soldCount = soldCount + 1
            end
        end
    end

    if soldCount > 0 then
        local player = GameState.player
        if player then
            if totalGold > 0 then player:GainGold(totalGold) end
            if totalLingYun > 0 then player:GainLingYun(totalLingYun) end
        end
        EventBus.Emit("batch_sold", soldCount, totalGold, totalLingYun)
        local msg = "[InventorySystem] Batch sold " .. soldCount .. " items for " .. totalGold .. " gold"
        if totalLingYun > 0 then msg = msg .. " + " .. totalLingYun .. " lingYun" end
        print(msg)
    end

    return soldCount, totalGold, totalLingYun
end

--- 整理背包：装备按品质降序→阶降序排前，消耗品平铺排后，空格沉底
function InventorySystem.SortBackpack()
    if not manager_ then return end

    -- 收集所有背包物品
    local items = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item then
            items[#items + 1] = item
        end
    end

    -- 合并同类消耗品堆叠（受 MAX_STACK_COUNT 限制）
    local MAX_STACK = GameConfig.MAX_STACK_COUNT
    local merged = {}       -- consumableId → { item1, item2, ... } 合并后的堆叠列表
    local result = {}       -- 最终物品列表
    for _, item in ipairs(items) do
        if item.category == "consumable" and item.consumableId then
            local cId = item.consumableId
            if not merged[cId] then
                merged[cId] = {}
            end
            -- 尝试塞入已有的未满堆叠
            local placed = false
            for _, stack in ipairs(merged[cId]) do
                if stack.count < MAX_STACK then
                    local space = MAX_STACK - stack.count
                    local move = math.min(item.count or 1, space)
                    stack.count = stack.count + move
                    local leftover = (item.count or 1) - move
                    if leftover > 0 then
                        item.count = leftover
                        -- 继续下一个堆叠
                    else
                        placed = true
                        break
                    end
                end
            end
            if not placed then
                -- 剩余数量作为新堆叠
                local remaining = item.count or 1
                while remaining > 0 do
                    local stackAmt = math.min(remaining, MAX_STACK)
                    local newItem = item
                    if remaining ~= (item.count or 1) or stackAmt ~= remaining then
                        -- 需要拆分，创建新的 item table
                        newItem = {}
                        for k, v in pairs(item) do newItem[k] = v end
                        newItem.id = require("core.Utils").NextId()
                    end
                    newItem.count = stackAmt
                    table.insert(merged[cId], newItem)
                    remaining = remaining - stackAmt
                end
            end
        else
            result[#result + 1] = item
        end
    end
    -- 将合并后的消耗品堆叠加入结果
    for _, stacks in pairs(merged) do
        for _, stack in ipairs(stacks) do
            result[#result + 1] = stack
        end
    end
    items = result

    -- 排序：装备在前(品质降序→阶降序)，消耗品在后(按 consumableId 升序)
    table.sort(items, function(a, b)
        local aIsEquip = (a.category ~= "consumable") and 1 or 0
        local bIsEquip = (b.category ~= "consumable") and 1 or 0
        -- 装备 > 消耗品
        if aIsEquip ~= bIsEquip then return aIsEquip > bIsEquip end
        if aIsEquip == 1 then
            -- 都是装备：品质降序
            local aQ = GameConfig.QUALITY_ORDER[a.quality] or 0
            local bQ = GameConfig.QUALITY_ORDER[b.quality] or 0
            if aQ ~= bQ then return aQ > bQ end
            -- 品质相同：阶降序
            local aT = a.tier or 0
            local bT = b.tier or 0
            if aT ~= bT then return aT > bT end
            -- 阶相同：按槽位名排序（稳定）
            return (a.slot or "") < (b.slot or "")
        else
            -- 都是消耗品：按 consumableId 排序
            local aId = a.consumableId or ""
            local bId = b.consumableId or ""
            return tostring(aId) < tostring(bId)
        end
    end)

    -- 清空全部格子，按排序结果重新放入
    for i = 1, GameConfig.BACKPACK_SIZE do
        manager_:SetInventoryItem(i, nil)
    end
    for i, item in ipairs(items) do
        manager_:SetInventoryItem(i, item)
    end

    print("[InventorySystem] Backpack sorted: " .. #items .. " items")
end

--- 重新计算装备加成并应用到玩家
function InventorySystem.RecalcEquipStats()
    if not manager_ then return end
    local player = GameState.player
    if not player then return end

    -- 属性累加表：stat名 → 累计值（替代 15 个独立变量）
    local totals = {
        atk = 0, def = 0, maxHp = 0, speed = 0, hpRegen = 0,
        critRate = 0, dmgReduce = 0, skillDmg = 0, killHeal = 0,
        critDmg = 0, heavyHit = 0, fortune = 0, wisdom = 0,
        constitution = 0, physique = 0,
    }

    -- 主属性字段名与 totals key 完全一致（mainStat 使用直接字段访问）
    -- 副属性/洗练/灵性的 stat 字段名也与 totals key 一致

    -- 统计套装件数（按原始 slot 去重：同 slot 的重复装备只计1件）
    local setCounts = {}
    local setSlotSeen = {}  -- setSlotSeen[setId][originalSlot] = true

    local equipped = manager_:GetAllEquipment()
    for slotId, item in pairs(equipped) do
        if item then
            -- 主属性（直接字段访问，保持不变）
            if item.mainStat then
                for stat in pairs(totals) do
                    totals[stat] = totals[stat] + (item.mainStat[stat] or 0)
                end
            end

            -- 副属性（查找表替代 if/elseif 链）
            if item.subStats then
                for _, sub in ipairs(item.subStats) do
                    if totals[sub.stat] then
                        totals[sub.stat] = totals[sub.stat] + sub.value
                    end
                end
            end

            -- 洗练属性（查找表替代 if/elseif 链）
            if item.forgeStat then
                local fs = item.forgeStat
                if totals[fs.stat] then
                    totals[fs.stat] = totals[fs.stat] + fs.value
                end
            end

            -- 灵性属性（查找表替代 if/elseif 链）
            if item.spiritStat then
                local ss = item.spiritStat
                if totals[ss.stat] then
                    totals[ss.stat] = totals[ss.stat] + ss.value
                end
            end

            -- 套装计数（按原始 slot 去重，两个相同戒指只算1件）
            if item.setId then
                local origSlot = item.slot or slotId
                if not setSlotSeen[item.setId] then
                    setSlotSeen[item.setId] = {}
                end
                if not setSlotSeen[item.setId][origSlot] then
                    setSlotSeen[item.setId][origSlot] = true
                    setCounts[item.setId] = (setCounts[item.setId] or 0) + 1
                end
            end
            -- 附灵套装计数（enchantSetId，每件已装备的装备贡献+1，无需去重）
            if item.enchantSetId then
                setCounts[item.enchantSetId] = (setCounts[item.enchantSetId] or 0) + 1
            end
        end
    end

    -- 套装效果加成
    local totalComboChance = 0
    local totalPetSyncRate = 0
    local totalBloodRageChance = 0
    local totalHeavyHitRate = 0
    local activeSetAoes = {}
    for setId, count in pairs(setCounts) do
        local setData = EquipmentData.SetBonuses[setId]
        if setData then
            for threshold, bonus in pairs(setData.pieces) do
                if count >= threshold then
                    if bonus.bonuses then
                        -- 15 项标准属性（复用 totals 查找表）
                        for stat in pairs(totals) do
                            totals[stat] = totals[stat] + (bonus.bonuses[stat] or 0)
                        end
                        -- 4 项特殊套装属性（仅套装使用，不在通用 totals 中）
                        totalComboChance = totalComboChance + (bonus.bonuses.comboChance or 0)
                        totalPetSyncRate = totalPetSyncRate + (bonus.bonuses.petSyncRate or 0)
                        totalBloodRageChance = totalBloodRageChance + (bonus.bonuses.bloodRageChance or 0)
                        totalHeavyHitRate = totalHeavyHitRate + (bonus.bonuses.heavyHitRate or 0)
                    end
                    -- 收集活跃的套装AOE效果（8件套触发技能）
                    if bonus.aoeEffect then
                        table.insert(activeSetAoes, {
                            setId = setId,
                            setName = setData.name,
                            aoe = bonus.aoeEffect,
                        })
                    end
                end
            end
        end
    end

    -- 应用到玩家（stat名 → player字段名映射）
    local STAT_TO_PLAYER = {
        atk = "equipAtk", def = "equipDef", maxHp = "equipHp",
        speed = "equipSpeed", hpRegen = "equipHpRegen",
        critRate = "equipCritRate", dmgReduce = "equipDmgReduce",
        skillDmg = "equipSkillDmg", killHeal = "equipKillHeal",
        critDmg = "equipCritDmg", heavyHit = "equipHeavyHit",
        fortune = "equipFortune", wisdom = "equipWisdom",
        constitution = "equipConstitution", physique = "equipPhysique",
    }
    for stat, field in pairs(STAT_TO_PLAYER) do
        player[field] = totals[stat]
    end
    -- 仙劫套装5件套直加属性
    player.equipComboChance = totalComboChance
    player.equipPetSyncRate = totalPetSyncRate
    player.equipBloodRageChance = totalBloodRageChance
    player.equipHeavyHitRate = totalHeavyHitRate
    -- 仙劫套装8件套AOE效果列表
    player.activeSetAoes = activeSetAoes

    -- 收集装备特效（bleed_dot 等）
    -- 旧存档兼容：specialEffect 未序列化，从模板按名字恢复
    local specialEffects = {}
    for slotId, item in pairs(equipped) do
        if item and item.isSpecial and not item.specialEffect then
            for _, tpl in pairs(EquipmentData.SpecialEquipment) do
                if tpl.name == item.name and tpl.specialEffect then
                    item.specialEffect = tpl.specialEffect
                    break
                end
            end
        end
        if item and item.specialEffect then
            table.insert(specialEffects, item.specialEffect)
        end
    end
    player.equipSpecialEffects = specialEffects

    -- 装备变动后，确保当前 hp 不超过新的最大生命值
    local newMaxHp = player:GetTotalMaxHp()
    if player.hp > newMaxHp then
        player.hp = newMaxHp
    end

    -- 法宝(treasure)槽位技能绑定 → 槽5
    local SkillSystem = require("systems.SkillSystem")
    local treasureItem = equipped["treasure"]

    -- 旧存档兼容：法宝缺少 skillId 时，从模板按名字补全
    if treasureItem and not treasureItem.skillId then
        for _, tpl in pairs(EquipmentData.SpecialEquipment) do
            if tpl.name == treasureItem.name and tpl.skillId then
                treasureItem.skillId = tpl.skillId
                treasureItem.isSpecial = true
                break
            end
        end
    end

    local currentTreasureSkill = SkillSystem.equippedSkills[5]

    if treasureItem and treasureItem.skillId then
        if currentTreasureSkill ~= treasureItem.skillId then
            if currentTreasureSkill then
                SkillSystem.UnbindEquipSkill(currentTreasureSkill)
            end
            SkillSystem.BindEquipSkill(treasureItem.skillId)
        end
    else
        if currentTreasureSkill then
            SkillSystem.UnbindEquipSkill(currentTreasureSkill)
        end
    end

    -- 专属(exclusive)槽位技能绑定 → 槽4
    local exclusiveItem = equipped["exclusive"]

    -- 旧存档兼容：专属装备缺少 skillId 时，从模板按名字补全
    if exclusiveItem and not exclusiveItem.skillId then
        for _, tpl in pairs(EquipmentData.SpecialEquipment) do
            if tpl.name == exclusiveItem.name and tpl.skillId then
                exclusiveItem.skillId = tpl.skillId
                exclusiveItem.isSpecial = true
                break
            end
        end
    end

    local currentExclusiveSkill = SkillSystem.equippedSkills[4]

    if exclusiveItem and exclusiveItem.skillId then
        if currentExclusiveSkill ~= exclusiveItem.skillId then
            if currentExclusiveSkill then
                SkillSystem.UnbindExclusiveSkill(currentExclusiveSkill)
            end
            SkillSystem.BindExclusiveSkill(exclusiveItem.skillId)
        end
    else
        if currentExclusiveSkill then
            SkillSystem.UnbindExclusiveSkill(currentExclusiveSkill)
        end
    end

    -- 重算美酒被动属性（装备变动可能影响葫芦是否装备）
    local wineOk, WineSystem = pcall(require, "systems.WineSystem")
    if wineOk and WineSystem then
        WineSystem.RecalcWineStats()
    end

    EventBus.Emit("equip_stats_changed")
end

--- 获取装备总属性汇总（用于 UI 显示）
---@return table {atk, def, maxHp, speed, hpRegen}
function InventorySystem.GetEquipStatSummary()
    local player = GameState.player
    if not player then return { atk = 0, def = 0, maxHp = 0, speed = 0, hpRegen = 0, critRate = 0, dmgReduce = 0, skillDmg = 0, killHeal = 0, critDmg = 0, heavyHit = 0, fortune = 0, wisdom = 0, constitution = 0, physique = 0 } end
    return {
        atk = player.equipAtk,
        def = player.equipDef,
        maxHp = player.equipHp,
        speed = player.equipSpeed,
        hpRegen = player.equipHpRegen,
        critRate = player.equipCritRate,
        dmgReduce = player.equipDmgReduce,
        skillDmg = player.equipSkillDmg,
        killHeal = player.equipKillHeal,
        critDmg = player.equipCritDmg,
        heavyHit = player.equipHeavyHit,
        fortune = player.equipFortune,
        wisdom = player.equipWisdom,
        constitution = player.equipConstitution,
        physique = player.equipPhysique,
    }
end

--- 获取当前生效的套装效果
---@return table[] { {name, description, count, threshold} }
function InventorySystem.GetActiveSetBonuses()
    if not manager_ then return {} end

    local setCounts = {}
    local setSlotSeen = {}
    local equipped = manager_:GetAllEquipment()
    for slotId, item in pairs(equipped) do
        if item and item.setId then
            local origSlot = item.slot or slotId
            if not setSlotSeen[item.setId] then
                setSlotSeen[item.setId] = {}
            end
            if not setSlotSeen[item.setId][origSlot] then
                setSlotSeen[item.setId][origSlot] = true
                setCounts[item.setId] = (setCounts[item.setId] or 0) + 1
            end
        end
        -- 附灵套装计数（enchantSetId，每件装备贡献+1）
        if item and item.enchantSetId then
            setCounts[item.enchantSetId] = (setCounts[item.enchantSetId] or 0) + 1
        end
    end

    local active = {}
    for setId, count in pairs(setCounts) do
        local setData = EquipmentData.SetBonuses[setId]
        if setData then
            for threshold, bonus in pairs(setData.pieces) do
                if count >= threshold then
                    table.insert(active, {
                        name = setData.name .. " (" .. threshold .. "件)",
                        description = bonus.description,
                        count = count,
                        threshold = threshold,
                    })
                end
            end
        end
    end

    return active
end

--- 获取背包空余格数
---@return number
function InventorySystem.GetFreeSlots()
    if not manager_ then return 0 end
    local count = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not manager_:GetInventoryItem(i) then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- 消耗品系统（宠物食物、灵兽丹等可堆叠物品）
-- ============================================================================

--- 添加消耗品到背包（支持堆叠上限溢出）
---@param consumableId string 消耗品 ID（如 "meat_bone", "spirit_pill"）
---@param amount number|nil 数量（默认1）
---@return boolean allSuccess 是否全部添加成功
---@return number addedCount 实际写入数量（部分成功时 > 0 但 allSuccess=false）
function InventorySystem.AddConsumable(consumableId, amount)
    if not manager_ then return false, 0 end
    amount = amount or 1
    local originalAmount = amount

    local MAX_STACK = GameConfig.MAX_STACK_COUNT  -- 9999

    -- 查找已有的未满堆叠
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            local cur = item.count or 1
            if cur < MAX_STACK then
                local space = MAX_STACK - cur
                if amount <= space then
                    -- 当前堆叠能装下全部
                    item.count = cur + amount
                    EventBus.Emit("inventory_item_added", item, i)
                    return true, originalAmount
                else
                    -- 填满当前堆叠，剩余溢出到新堆叠
                    item.count = MAX_STACK
                    amount = amount - space
                    EventBus.Emit("inventory_item_added", item, i)
                    -- 继续循环查找下一个未满堆叠
                end
            end
            -- 此堆叠已满，继续查找下一个
        end
    end

    -- 剩余 amount 需要创建新堆叠
    if amount <= 0 then return true, originalAmount end

    local foodData = GameConfig.PET_FOOD[consumableId]
    local matData = GameConfig.PET_MATERIALS[consumableId]
    local PetSkillData = require("config.PetSkillData")
    local bookData = PetSkillData.SKILL_BOOKS[consumableId]
    local eventData = GameConfig.EVENT_ITEMS and GameConfig.EVENT_ITEMS[consumableId]
    local consumableData = GameConfig.CONSUMABLES[consumableId]
    local data = foodData or matData or bookData or eventData or consumableData
    if not data then return false, originalAmount - amount end

    -- 循环创建新堆叠直到 amount 用尽或背包满
    while amount > 0 do
        local stackAmount = math.min(amount, MAX_STACK)
        local item = {
            id = require("core.Utils").NextId(),
            name = data.name,
            icon = data.icon,
            image = data.image or nil,
            category = "consumable",
            consumableId = consumableId,
            count = stackAmount,
            sellPrice = data.sellPrice or 1,
            quality = data.quality or "white",
            desc = data.desc,
            petExp = foodData and foodData.exp or nil,
            isSkillBook = bookData and true or nil,
            skillId = bookData and bookData.skillId or nil,
            bookTier = bookData and bookData.tier or nil,
        }
        local success, idx = manager_:AddToInventory(item)
        if success then
            EventBus.Emit("inventory_item_added", item, idx)
            amount = amount - stackAmount
        else
            -- 背包满，无法继续，返回已写入数量
            return false, originalAmount - amount
        end
    end
    return true, originalAmount
end

--- 统计某种消耗品的总数量
---@param consumableId string
---@return number
function InventorySystem.CountConsumable(consumableId)
    if not manager_ then return 0 end
    local total = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            total = total + (item.count or 1)
        end
    end
    return total
end

--- 消耗指定数量的消耗品
---@param consumableId string
---@param amount number
---@return boolean success
function InventorySystem.ConsumeConsumable(consumableId, amount)
    if not manager_ then return false end

    -- 先检查总量是否足够
    if InventorySystem.CountConsumable(consumableId) < amount then
        return false
    end

    local remaining = amount
    for i = 1, GameConfig.BACKPACK_SIZE do
        if remaining <= 0 then break end
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            local has = item.count or 1
            if has <= remaining then
                remaining = remaining - has
                manager_:SetInventoryItem(i, nil)  -- 全部用完，移除
            else
                item.count = has - remaining
                remaining = 0
            end
        end
    end

    EventBus.Emit("consumable_used", consumableId, amount)
    return true
end

--- 获取背包中所有宠物食物列表
---@return table[] { {slotIndex, consumableId, name, icon, count, petExp} }
function InventorySystem.GetPetFoodList()
    if not manager_ then return {} end
    local list = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.petExp then
            table.insert(list, {
                slotIndex = i,
                consumableId = item.consumableId,
                name = item.name,
                icon = item.icon,
                count = item.count or 1,
                petExp = item.petExp,
            })
        end
    end
    return list
end

--- 获取背包中所有技能书列表
---@return table[] { {slotIndex, consumableId, name, icon, count, skillId, bookTier, quality} }
function InventorySystem.GetSkillBookList()
    if not manager_ then return {} end
    local list = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.isSkillBook then
            table.insert(list, {
                slotIndex = i,
                consumableId = item.consumableId,
                name = item.name,
                icon = item.icon,
                count = item.count or 1,
                skillId = item.skillId,
                bookTier = item.bookTier,
                quality = item.quality,
            })
        end
    end
    return list
end

-- ============================================================================
-- 葫芦升级系统
-- ============================================================================

--- 升级装备中的葫芦（消耗金币，提升 tier，更新属性）
---@return boolean success, string|nil errorMsg
function InventorySystem.UpgradeGourd()
    if not manager_ then return false, "系统未初始化" end
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    -- 获取装备中的葫芦
    local gourd = manager_:GetEquipmentItem("treasure")
    if not gourd then return false, "未装备葫芦" end

    local currentTier = gourd.tier or 1
    local nextTier = currentTier + 1
    local upgradeData = EquipmentData.GOURD_UPGRADE[nextTier]
    if not upgradeData then return false, "已达最高阶级" end

    -- 检查境界要求
    if upgradeData.requiredRealm then
        local playerRealmData = GameConfig.REALMS[player.realm]
        local reqRealmData = GameConfig.REALMS[upgradeData.requiredRealm]
        if not playerRealmData or not reqRealmData then return false, "境界数据异常" end
        if playerRealmData.order < reqRealmData.order then
            local reqName = reqRealmData.name or upgradeData.requiredRealm
            return false, "境界不足，需要" .. reqName
        end
    end

    -- 检查金币
    if player.gold < upgradeData.cost then
        return false, "金币不足"
    end

    -- 扣除金币
    player:SpendGold(upgradeData.cost)

    -- 更新葫芦属性
    gourd.tier = nextTier
    gourd.quality = upgradeData.quality
    local LootSystem = require("systems.LootSystem")
    gourd.icon = LootSystem.GetGourdIcon(upgradeData.quality)
    gourd.name = "酒葫芦 lv." .. nextTier

    -- 更新主属性
    local newHpRegen = EquipmentData.GOURD_MAIN_STAT[nextTier] or gourd.mainStat.hpRegen
    gourd.mainStat = { hpRegen = newHpRegen }

    -- 更新副属性（覆盖，升级后洗练属性清除）
    gourd.subStats = {}
    for _, sub in ipairs(upgradeData.subStats) do
        table.insert(gourd.subStats, { stat = sub.stat, value = sub.value })
    end

    -- 更新灵性属性
    if upgradeData.spiritStat then
        gourd.spiritStat = { stat = upgradeData.spiritStat.stat, name = upgradeData.spiritStat.name, value = upgradeData.spiritStat.value }
    else
        gourd.spiritStat = nil
    end

    -- 清除洗练属性
    gourd.forgeStat = nil

    -- 重新计算装备加成
    InventorySystem.RecalcEquipStats()

    EventBus.Emit("gourd_upgraded", nextTier)
    print("[InventorySystem] Gourd upgraded to tier " .. nextTier)

    -- 即时存档：升级消耗大量金币，避免玩家退出后丢失进度
    EventBus.Emit("save_request")

    return true, nil
end

--- 获取当前装备的葫芦 tier（供技能系统查表用）
---@return number tier
function InventorySystem.GetGourdTier()
    if not manager_ then return 1 end
    local gourd = manager_:GetEquipmentItem("treasure")
    if not gourd then return 1 end
    return gourd.tier or 1
end

--- 获取专属装备阶级（用于技能 tierScaling 查表）
---@return number tier 默认4（Lv.1）
function InventorySystem.GetExclusiveTier()
    if not manager_ then return 3 end
    local excl = manager_:GetEquipmentItem("exclusive")
    if not excl then return 3 end
    return excl.tier or 3
end

--- 获取专属装备的**技能等级 Tier**
--- 新版法宝（id 以 "fabao_" 开头）技能暂不成长，固定返回 T3
--- 旧版专属装备（xuehaitu_chu/po/jue 等）保持原有 Tier 成长
function InventorySystem.GetExclusiveSkillTier()
    if not manager_ then return 3 end
    local excl = manager_:GetEquipmentItem("exclusive")
    if not excl then return 3 end
    -- 新版法宝：技能暂不成长（§8.4）
    if excl.id and type(excl.id) == "string" and excl.id:sub(1, 6) == "fabao_" then
        return 3
    end
    return excl.tier or 3
end

-- ============================================================================
-- 灵韵果使用
-- ============================================================================

--- 使用灵韵果（+50 灵韵，每次1颗）
---@return boolean success, string|nil errorMsg
function InventorySystem.UseLingyunFruit()
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local count = InventorySystem.CountConsumable("lingyun_fruit")
    if count < 1 then return false, "灵韵果不足" end

    local ok = InventorySystem.ConsumeConsumable("lingyun_fruit", 1)
    if not ok then return false, "消耗失败" end

    player:GainLingYun(50)
    return true, nil
end

-- ============================================================================
-- 修炼果使用
-- ============================================================================

--- 使用修炼果（+10000 EXP，每次1颗，境界等级上限时不可用）
---@return boolean success, string|nil errorMsg
function InventorySystem.UseExpPill()
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    -- 检查数量
    local count = InventorySystem.CountConsumable("exp_pill")
    if count < 1 then return false, "修炼果不足" end

    -- 检查是否卡在境界等级上限
    local realmData = GameConfig.REALMS[player.realm]
    if realmData then
        local maxLevel = realmData.maxLevel
        if player.level >= maxLevel then
            -- 经验已被 cap，不允许使用
            local curLevelExp = GameConfig.EXP_TABLE[player.level] or 0
            local nextLevelExp = GameConfig.EXP_TABLE[player.level + 1]
            if nextLevelExp then
                local cap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
                if player.exp >= cap then
                    return false, "经验已达境界上限，请先突破境界"
                end
            end
        end
    end

    -- 消耗1颗
    local ok = InventorySystem.ConsumeConsumable("exp_pill", 1)
    if not ok then return false, "消耗失败" end

    -- 给予经验
    player:GainExp(10000)
    EventBus.Emit("exp_pill_used", 10000)
    return true, nil
end

-- ============================================================================
-- 守护者证明使用（仙途守护者道印 +100 经验）
-- ============================================================================

--- 使用守护者证明（消耗1个，为仙途守护者道印注入100经验）
---@param slotIndex number|nil 背包槽位（可选，不传则自动查找）
---@return boolean success, string|nil errorMsg
function InventorySystem.UseGuardianToken(slotIndex)
    local count = InventorySystem.CountConsumable("item_guardian_token")
    if count < 1 then return false, "守护者证明不足" end

    local ok = InventorySystem.ConsumeConsumable("item_guardian_token", 1)
    if not ok then return false, "消耗失败" end

    local okAtlas, AtlasSystem = pcall(require, "systems.AtlasSystem")
    if okAtlas and AtlasSystem and AtlasSystem.ConsumeGuardianToken then
        AtlasSystem.ConsumeGuardianToken(1)
    else
        print("[InventorySystem] WARNING: AtlasSystem not available, guardian token consumed but exp not applied")
    end

    return true, nil
end

-- ============================================================================
-- 批量使用/出售消耗品
-- 支持：金条(gold_bar)、灵韵果(lingyun_fruit)、修炼果(exp_pill)
-- ============================================================================

--- 批量使用/出售消耗品统一入口
---@param consumableId string 消耗品 ID
---@param count number 使用/出售数量
---@return boolean success, string|nil message, number|nil actualCount
function InventorySystem.UseBatchConsumable(consumableId, count)
    if not consumableId or not count or count <= 0 then
        return false, "参数错误"
    end

    -- 检查库存
    local have = InventorySystem.CountConsumable(consumableId)
    if have <= 0 then
        return false, "物品不足"
    end
    -- 夹紧到实际拥有量
    count = math.min(count, have)

    -- 查配置（用于 category 判断）
    local cfgData = GameConfig.CONSUMABLES[consumableId]

    if consumableId == "exp_pill" then
        return InventorySystem._UseBatchExpPill(count)
    elseif consumableId == "lingyun_fruit" then
        return InventorySystem._UseBatchLingyunFruit(count)
    elseif consumableId == "gold_bar" or consumableId == "gold_brick"
        or (cfgData and cfgData.category == "event") then
        return InventorySystem._SellBatchConsumable(consumableId, count)
    elseif consumableId == "wubao_token_box" then
        return InventorySystem._UseTokenBox(consumableId, "wubao_token")
    elseif consumableId == "sha_hai_ling_box" then
        return InventorySystem._UseTokenBox(consumableId, "sha_hai_ling")
    elseif consumableId == "taixu_token_box" then
        return InventorySystem._UseTokenBox(consumableId, "taixu_token")
    else
        return false, "该物品不支持批量操作"
    end
end

--- 批量使用修炼果（预计算经验上限，一次性扣除+发放）
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function InventorySystem._UseBatchExpPill(count)
    local player = GameState.player
    if not player then print("[DEBUG _UseBatchExpPill] player is nil"); return false, "玩家不存在" end

    local EXP_PER_PILL = 10000

    -- 计算称号经验加成倍率（与 Player:GainExp 保持一致）
    local expBonus = player.titleExpBonus or 0
    local expMultiplier = 1 + expBonus
    local effectiveExpPerPill = math.floor(EXP_PER_PILL * expMultiplier)

    -- 计算经验上限（境界卡等级时的经验 cap）
    print("[DEBUG _UseBatchExpPill] player.realm=" .. tostring(player.realm) .. " level=" .. tostring(player.level) .. " exp=" .. tostring(player.exp))
    local realmData = GameConfig.REALMS[player.realm]
    if not realmData then print("[DEBUG _UseBatchExpPill] REALMS[" .. tostring(player.realm) .. "] is nil!"); return false, "境界数据异常" end

    local maxLevel = realmData.maxLevel
    local expCap = math.huge  -- 默认无上限

    if player.level >= maxLevel then
        local curLevelExp = GameConfig.EXP_TABLE[player.level] or 0
        local nextLevelExp = GameConfig.EXP_TABLE[player.level + 1]
        if nextLevelExp then
            expCap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
        end
        if player.exp >= expCap then
            return false, "经验已达境界上限，请先突破境界"
        end
    end

    -- 预计算：在 cap 限制下最多能吃多少颗
    -- GainExp 内部会再乘 expMultiplier，所以每颗实际提供 effectiveExpPerPill 点经验
    local maxUsable = count
    if player.level >= maxLevel and expCap ~= math.huge then
        local remainingExp = expCap - player.exp
        if remainingExp <= 0 then
            return false, "经验已达境界上限，请先突破境界"
        end
        local canUse = math.max(1, math.floor(remainingExp / effectiveExpPerPill))
        maxUsable = math.min(count, canUse)
    end

    if maxUsable <= 0 then
        return false, "经验已达境界上限，请先突破境界"
    end

    -- 检查库存并夹紧
    local have = InventorySystem.CountConsumable("exp_pill")
    maxUsable = math.min(maxUsable, have)
    if maxUsable <= 0 then return false, "修炼果不足" end

    -- 原子扣除
    local ok = InventorySystem.ConsumeConsumable("exp_pill", maxUsable)
    if not ok then return false, "消耗失败" end

    -- 一次性发放经验（GainExp 内部处理升级+cap+expBonus）
    local totalRawExp = EXP_PER_PILL * maxUsable
    player:GainExp(totalRawExp)

    local actualExp = math.floor(totalRawExp * expMultiplier)
    EventBus.Emit("exp_pill_used", actualExp)
    local msg = "使用 " .. maxUsable .. " 颗修炼果，获得 " .. actualExp .. " 经验！"
    print("[InventorySystem] " .. msg)
    return true, msg, maxUsable
end

--- 批量使用灵韵果（一次性扣除+发放）
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function InventorySystem._UseBatchLingyunFruit(count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local LINGYUN_PER_FRUIT = 50

    -- 夹紧到库存
    local have = InventorySystem.CountConsumable("lingyun_fruit")
    count = math.min(count, have)
    if count <= 0 then return false, "灵韵果不足" end

    -- 原子扣除
    local ok = InventorySystem.ConsumeConsumable("lingyun_fruit", count)
    if not ok then return false, "消耗失败" end

    -- 一次性发放灵韵（触发事件）
    local totalLingYun = LINGYUN_PER_FRUIT * count
    player:GainLingYun(totalLingYun)

    local msg = "使用 " .. count .. " 颗灵韵果，获得 " .. totalLingYun .. " 灵韵！"
    print("[InventorySystem] " .. msg)
    return true, msg, count
end

--- 批量出售消耗品（金条等纯卖钱物品）
--- 复用 item_sold 事件，保持与 SellItem 兼容
---@param consumableId string
---@param count number 期望出售数量
---@return boolean success, string|nil message, number|nil actualCount
function InventorySystem._SellBatchConsumable(consumableId, count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    -- 查找配置获取单价和货币类型
    local cfgData = GameConfig.CONSUMABLES[consumableId]
    if not cfgData then return false, "物品配置不存在" end

    local unitPrice = cfgData.sellPrice or 1
    local sellCurrency = cfgData.sellCurrency  -- nil = 金币

    -- 夹紧到库存
    local have = InventorySystem.CountConsumable(consumableId)
    count = math.min(count, have)
    if count <= 0 then return false, "物品不足" end

    -- 原子扣除
    local ok = InventorySystem.ConsumeConsumable(consumableId, count)
    if not ok then return false, "消耗失败" end

    -- 发放收益
    local totalPrice = unitPrice * count
    if sellCurrency == "lingYun" then
        player:GainLingYun(totalPrice)
    else
        player:GainGold(totalPrice)
    end

    -- 复用 item_sold 事件（与单件出售兼容）
    EventBus.Emit("item_sold", { name = cfgData.name, consumableId = consumableId, count = count, sellPrice = unitPrice, sellCurrency = sellCurrency }, totalPrice, sellCurrency)

    local currencyName = sellCurrency == "lingYun" and "灵韵" or "金币"
    local msg = "出售 " .. count .. " 个" .. cfgData.name .. "，获得 " .. totalPrice .. " " .. currencyName .. "！"
    print("[InventorySystem] " .. msg)
    return true, msg, count
end

--- 使用令牌盒：原子化消耗1个令牌盒 → 发放100个对应令牌（单次使用，不支持批量）
---@param boxId string   令牌盒消耗品ID（如 "wubao_token_box"）
---@param tokenId string 对应令牌ID（如 "wubao_token"）
---@return boolean success, string|nil message, number|nil actualCount
function InventorySystem._UseTokenBox(boxId, tokenId)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local TOKEN_PER_BOX = 100

    local boxData = GameConfig.CONSUMABLES[boxId]
    local tokenData = GameConfig.CONSUMABLES[tokenId]
    if not boxData or not tokenData then return false, "物品配置不存在" end

    -- 检查库存
    local have = InventorySystem.CountConsumable(boxId)
    if have <= 0 then return false, boxData.name .. "不足" end

    -- 检查背包空间（令牌已有堆叠或有空位）
    local canAdd = InventorySystem.CountConsumable(tokenId) > 0 or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        return false, "背包已满，无法使用！"
    end

    -- 原子扣除令牌盒
    local ok = InventorySystem.ConsumeConsumable(boxId, 1)
    if not ok then return false, "消耗失败" end

    -- 发放令牌
    InventorySystem.AddConsumable(tokenId, TOKEN_PER_BOX)

    local msg = "使用 " .. boxData.name .. "，获得 " .. TOKEN_PER_BOX .. " 个" .. tokenData.name .. "！"
    print("[InventorySystem] " .. msg)
    return true, msg, 1
end

return InventorySystem
