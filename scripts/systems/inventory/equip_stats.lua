-- ============================================================================
-- inventory/equip_stats.lua — 装备属性计算子模块
-- ============================================================================
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local EquipmentData = require("config.EquipmentData")

local M = {}

--- 重新计算装备加成并应用到玩家
---@param IS table InventorySystem facade (access via IS.GetManager())
function M.RecalcEquipStats(IS)
    local manager_ = IS.GetManager()
    if not manager_ then return end
    local player = GameState.player
    if not player then return end

    -- 属性累加表：stat名 → 累计值（替代 15 个独立变量）
    local totals = {
        atk = 0, def = 0, maxHp = 0, speed = 0, hpRegen = 0,
        critRate = 0, dmgReduce = 0, skillDmg = 0, killHeal = 0,
        critDmg = 0, heavyHit = 0, fortune = 0, wisdom = 0,
        constitution = 0, physique = 0,
        tianzhuChance = 0, tianzhuDamage = 0,
    }

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

            -- 圣性属性（与灵性属性相同逻辑，圣器专属）
            if item.saintStat then
                local ss = item.saintStat
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
    local totalDefPercent = 0
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
                        totalDefPercent = totalDefPercent + (bonus.bonuses.defPercent or 0)
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
        tianzhuChance = "equipTianzhuChance", tianzhuDamage = "equipTianzhuDamage",
    }
    for stat, field in pairs(STAT_TO_PLAYER) do
        player[field] = totals[stat]
    end
    -- 仙劫套装5件套直加属性
    player.equipComboChance = totalComboChance
    player.equipPetSyncRate = totalPetSyncRate
    player.equipBloodRageChance = totalBloodRageChance
    player.equipHeavyHitRate = totalHeavyHitRate
    player.equipDefPercent = totalDefPercent
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
---@return table {atk, def, maxHp, speed, hpRegen, ...}
function M.GetEquipStatSummary()
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
---@param IS table InventorySystem facade
---@return table[] { {name, description, count, threshold} }
function M.GetActiveSetBonuses(IS)
    local manager_ = IS.GetManager()
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

return M
