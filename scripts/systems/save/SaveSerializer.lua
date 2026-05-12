-- ============================================================================
-- SaveSerializer.lua - 序列化/反序列化所有游戏数据模块
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local SS = require("systems.save.SaveState")
local SaveMigrations = require("systems.save.SaveMigrations")

local SaveSerializer = {}

-- ============================================================================
-- 玩家
-- ============================================================================

--- 序列化玩家数据为可存储的 table
---@return table
function SaveSerializer.SerializePlayer()
    local player = GameState.player
    if not player then return {} end

    -- 副本内保存时使用进入副本前的世界坐标，避免加载后出现在副本竞技场
    local saveX, saveY = player.x, player.y
    local ok, DC = pcall(require, "network.DungeonClient")
    if ok and DC and DC.IsDungeonMode and DC.IsDungeonMode() then
        local pos = DC.GetSavedPosition()
        if pos then
            saveX, saveY = pos.x, pos.y
            print("[SaveSerializer] In dungeon, using pre-dungeon position: (" .. saveX .. ", " .. saveY .. ")")
        else
            -- 🔴 防御：isDungeonMode=true 但 savedPosition 为 nil（不应发生）
            -- 使用当前坐标并记录警告，避免存档丢失位置
            print("[SaveSerializer] WARNING: In dungeon mode but savedPosition is nil! Using current pos: (" .. saveX .. ", " .. saveY .. ")")
        end
    end

    return {
        level = player.level,
        exp = player.exp,
        hp = player.hp,
        maxHp = player.maxHp,
        atk = player.atk,
        def = player.def,
        hpRegen = player.hpRegen,
        pillKillHeal = player.pillKillHeal or 0,
        pillConstitution = player.pillConstitution or 0,
        fruitFortune = player.fruitFortune or 0,
        seaPillarDef = player.seaPillarDef or 0,
        seaPillarAtk = player.seaPillarAtk or 0,
        seaPillarMaxHp = player.seaPillarMaxHp or 0,
        seaPillarHpRegen = player.seaPillarHpRegen or 0,
        prisonTowerAtk = player.prisonTowerAtk or 0,
        prisonTowerDef = player.prisonTowerDef or 0,
        prisonTowerMaxHp = player.prisonTowerMaxHp or 0,
        prisonTowerHpRegen = player.prisonTowerHpRegen or 0,
        daoTreeWisdom = player.daoTreeWisdom or 0,
        daoTreeWisdomPity = player.daoTreeWisdomPity or 0,
        -- v13: 丹药计数统一存入 player
        tigerPillCount = (function()
            local AlchemyUI = require("ui.AlchemyUI")
            return AlchemyUI.GetTigerPillCount()
        end)(),
        snakePillCount = (function()
            local AlchemyUI = require("ui.AlchemyUI")
            return AlchemyUI.GetSnakePillCount()
        end)(),
        diamondPillCount = (function()
            local AlchemyUI = require("ui.AlchemyUI")
            return AlchemyUI.GetDiamondPillCount()
        end)(),
        temperingPillEaten = (function()
            local AlchemyUI = require("ui.AlchemyUI")
            return AlchemyUI.GetTemperingPillEaten()
        end)(),
        dragonBloodPillCount = (function()
            local AlchemyUI = require("ui.AlchemyUI")
            return AlchemyUI.GetDragonBloodPillCount()
        end)(),
        xueshaDanCount = (function()
            local ChallengeSystem = require("systems.ChallengeSystem")
            return ChallengeSystem.xueshaDanCount or 0
        end)(),
        haoqiDanCount = (function()
            local ChallengeSystem = require("systems.ChallengeSystem")
            return ChallengeSystem.haoqiDanCount or 0
        end)(),
        gold = player.gold,
        lingYun = player.lingYun,
        realm = player.realm,
        x = math.floor(saveX * 10) / 10,
        y = math.floor(saveY * 10) / 10,
        chapter = GameState.currentChapter or 1,
        pillPhysique = player.pillPhysique or 0,
        -- 美酒系统
        wineConstitution = player.wineConstitution or 0,
        wineWisdom = player.wineWisdom or 0,
        wineFortune = player.wineFortune or 0,
        winePhysique = player.winePhysique or 0,
        wineObtained = player.wineObtained or {},
        wineSlots = player.wineSlots or {},
        gourdFirstKillFlags = player.gourdFirstKillFlags or {},
        -- 天道问心
        daoWisdom = player.daoWisdom or 0,
        daoFortune = player.daoFortune or 0,
        daoConstitution = player.daoConstitution or 0,
        daoPhysique = player.daoPhysique or 0,
        daoAtk = player.daoAtk or 0,
        daoMaxHp = player.daoMaxHp or 0,
        daoAnswers = player.daoAnswers or {},
        -- 丹药权威计数（运行时校正写入，持久化保存）
        pillCounts = player.pillCounts or nil,
        -- 镇岳：血气累计器（浮点→整数取整，旧存档默认 0）
        bloodAccumulator = math.floor(player._bloodAccumulator or 0),
        -- v16: 职业
        classId = player.classId,
    }
end

--- 反序列化玩家数据（版本迁移已在外部完成，这里只做赋值）
---@param data table
function SaveSerializer.DeserializePlayer(data)
    local player = GameState.player
    if not player or not data then return end

    player.level = data.level or 1
    player.exp = data.exp or 0
    player.maxHp = data.maxHp or 100
    player.atk = data.atk or 15
    player.def = data.def or 5
    player.hpRegen = data.hpRegen or 1.0
    player.pillKillHeal = data.pillKillHeal or 0
    player.pillConstitution = data.pillConstitution or 0
    player.fruitFortune = data.fruitFortune or 0
    player.seaPillarDef = data.seaPillarDef or 0
    player.seaPillarAtk = data.seaPillarAtk or 0
    player.seaPillarMaxHp = data.seaPillarMaxHp or 0
    player.seaPillarHpRegen = data.seaPillarHpRegen or 0
    player.prisonTowerAtk = data.prisonTowerAtk or 0
    player.prisonTowerDef = data.prisonTowerDef or 0
    player.prisonTowerMaxHp = data.prisonTowerMaxHp or 0
    player.prisonTowerHpRegen = data.prisonTowerHpRegen or 0
    player.daoTreeWisdom = data.daoTreeWisdom or 0
    player.daoTreeWisdomPity = data.daoTreeWisdomPity or 0
    player.pillPhysique = data.pillPhysique or 0
    -- 美酒系统
    player.wineConstitution = data.wineConstitution or 0
    player.wineWisdom = data.wineWisdom or 0
    player.wineFortune = data.wineFortune or 0
    player.winePhysique = data.winePhysique or 0
    player.wineObtained = data.wineObtained or {}
    -- wineSlots 修复：旧存档可能因稀疏数组被 cjson 编码为 object（string key），
    -- 需要重建为密集数组，空槽用 false 而非 nil
    do
        local raw = data.wineSlots or {}
        local slots = {false, false, false}
        for k, v in pairs(raw) do
            local idx = tonumber(k)
            if idx and idx >= 1 and idx <= 3 and type(v) == "string" then
                slots[idx] = v
            end
        end
        player.wineSlots = slots
    end
    player.gourdFirstKillFlags = data.gourdFirstKillFlags or {}
    -- 天道问心
    player.daoWisdom       = data.daoWisdom or 0
    player.daoFortune      = data.daoFortune or 0
    player.daoConstitution = data.daoConstitution or 0
    player.daoPhysique     = data.daoPhysique or 0
    player.daoAtk          = data.daoAtk or 0
    player.daoMaxHp        = data.daoMaxHp or 0
    -- daoAnswers 验证：必须是 5 个 "A"/"B" 的数组，否则清零所有 dao* 字段
    do
        local raw = data.daoAnswers
        local valid = true
        if type(raw) ~= "table" then
            valid = false
        else
            local count = 0
            for _ in pairs(raw) do count = count + 1 end
            if count ~= 5 then
                valid = false
            else
                for i = 1, 5 do
                    local v = raw[i]
                    if v ~= "A" and v ~= "B" then
                        valid = false
                        break
                    end
                end
            end
        end
        if valid then
            player.daoAnswers = raw
        else
            -- 答案无效 → 清零所有 dao* 字段（防止数据不一致）
            player.daoAnswers      = {}
            player.daoWisdom       = 0
            player.daoFortune      = 0
            player.daoConstitution = 0
            player.daoPhysique     = 0
            player.daoAtk          = 0
            player.daoMaxHp        = 0
            if data.daoAnswers and type(data.daoAnswers) == "table" then
                -- 有数据但格式错误，记录警告
                print("[SaveSystem] WARNING: daoAnswers invalid format, cleared all dao fields")
            end
        end
    end
    player.pillCounts = data.pillCounts or nil
    -- 镇岳：血气累计器恢复（旧存档无此字段默认 0）
    player._bloodAccumulator = data.bloodAccumulator or 0
    -- v16: 职业
    player.classId = data.classId or "monk"
    player.gold = data.gold or 0
    player.lingYun = data.lingYun or 0
    player.realm = data.realm or "mortal"

    -- 旧存档兼容：映射旧境界 ID 到新 ID（迁移管线未覆盖的残留场景）
    if GameConfig.REALM_COMPAT and GameConfig.REALM_COMPAT[player.realm] then
        local oldRealm = player.realm
        player.realm = GameConfig.REALM_COMPAT[player.realm]
        print("[SaveSystem] Realm compat: " .. oldRealm .. " -> " .. player.realm)
    end

    local totalMaxHp = player:GetTotalMaxHp()
    player.hp = math.min(data.hp or totalMaxHp, totalMaxHp)
    -- 🔴 Bug H fix: 防止死亡状态存档后加载出现 alive=true 但 hp=0 的无效状态
    if player.hp <= 0 then
        player.hp = totalMaxHp
        print("[SaveSystem] Player hp was 0 on load, restored to full: " .. totalMaxHp)
    end

    if data.x and data.y then
        player.x = data.x
        player.y = data.y
    end

    -- 恢复章节信息
    GameState.currentChapter = data.chapter or 1

    -- v13: 恢复丹药计数到各模块
    do
        local AlchemyUI = require("ui.AlchemyUI")
        AlchemyUI.SetTigerPillCount(data.tigerPillCount or 0)
        AlchemyUI.SetSnakePillCount(data.snakePillCount or 0)
        AlchemyUI.SetDiamondPillCount(data.diamondPillCount or 0)
        AlchemyUI.SetTemperingPillEaten(data.temperingPillEaten or 0)
        AlchemyUI.SetDragonBloodPillCount(data.dragonBloodPillCount or 0)

        local ChallengeSystem = require("systems.ChallengeSystem")
        ChallengeSystem.xueshaDanCount = data.xueshaDanCount or 0
        ChallengeSystem.haoqiDanCount  = data.haoqiDanCount or 0

        print("[SaveSystem] v13 pill counts restored: tiger=" .. (data.tigerPillCount or 0)
            .. " snake=" .. (data.snakePillCount or 0)
            .. " diamond=" .. (data.diamondPillCount or 0)
            .. " tempering=" .. (data.temperingPillEaten or 0)
            .. " dragonBlood=" .. (data.dragonBloodPillCount or 0)
            .. " xuesha=" .. (data.xueshaDanCount or 0)
            .. " haoqi=" .. (data.haoqiDanCount or 0))
    end

    local realmData = GameConfig.REALMS[player.realm]
    if realmData then
        player.realmAtkSpeedBonus = realmData.attackSpeedBonus or 0
    end

    print("[SaveSystem] Player data restored: Lv." .. player.level .. " " .. player.realm)
end

-- ============================================================================
-- 装备/背包
-- ============================================================================

--- 序列化已装备物品（全字段，存入 coreData）
---@return table equipment { [slotId] = itemData }
function SaveSerializer.SerializeEquipped()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return {} end

    local equipment = {}
    local EquipmentData = require("config.EquipmentData")
    for _, slotId in ipairs(EquipmentData.SLOTS) do
        local item = mgr:GetEquipmentItem(slotId)
        if item then
            equipment[slotId] = SaveSerializer.SerializeItemFull(item)
        end
    end
    return equipment
end

--- v11: 序列化完整背包为单个 table（不再拆分 bag1/bag2）
---@return table backpack 所有背包物品 { ["1"]=item, ["2"]=item, ... }
function SaveSerializer.SerializeBackpack()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return {} end

    local backpack = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item then
            backpack[tostring(i)] = SaveSerializer.SerializeItemFull(item)
        end
    end

    return backpack
end

--- 序列化完整 inventory（equipment + backpack）
---@return table { equipment, backpack }
function SaveSerializer.SerializeInventory()
    local equipment = SaveSerializer.SerializeEquipped()
    local backpack = SaveSerializer.SerializeBackpack()
    return { equipment = equipment, backpack = backpack }
end

--- 序列化单个物品（完整字段，不裁剪）
---@param item table
---@return table
function SaveSerializer.SerializeItemFull(item)
    return {
        id = item.id,
        name = item.name,
        type = item.type,
        slot = item.slot,
        quality = item.quality,
        tier = item.tier,
        level = item.level,
        mainStat = item.mainStat,
        mainStatValue = item.mainStatValue,
        subStats = item.subStats,
        setId = item.setId,
        enchantSetId = item.enchantSetId,
        icon = item.icon,
        sellPrice = item.sellPrice,
        forgeStat = item.forgeStat,
        spiritStat = item.spiritStat,
        isSpecial = item.isSpecial,
        isFabao = item.isFabao,
        skillId = item.skillId,
        equipId = item.equipId,
        category = item.category,
        consumableId = item.consumableId,
        count = item.count,
        petExp = item.petExp,
        isSkillBook = item.isSkillBook,
        bookTier = item.bookTier,
    }
end

--- 反序列化背包数据
---@param data table
function SaveSerializer.DeserializeInventory(data)
    if not data then return end

    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return end

    local EquipmentData = require("config.EquipmentData")
    local LootSystem = require("systems.LootSystem")
    local NormalizePercentStats = SaveMigrations.NormalizePercentStats

    -- [Legacy] 补全旧 Trimmed 格式存档中省略的装备字段
    local function fillEquipFields(itemData)
        if not itemData.slot then return end
        local tier = itemData.tier or 1
        local specialTpl = nil
        local fabaoTpl = nil
        -- 法宝模板优先查找（动态法宝，与旧版 SpecialEquipment 独立）
        -- 兼容旧存档：即使 isFabao 缺失，也通过 equipId 反查 FabaoTemplates
        if itemData.equipId and EquipmentData.FabaoTemplates then
            fabaoTpl = EquipmentData.FabaoTemplates[itemData.equipId]
            if fabaoTpl and not itemData.isFabao then
                itemData.isFabao = true   -- 补全旧存档缺失的标记
            end
        end
        if itemData.isSpecial and not fabaoTpl then
            if itemData.equipId then
                specialTpl = EquipmentData.SpecialEquipment[itemData.equipId]
            end
            if not specialTpl and itemData.skillId then
                for _, tpl in pairs(EquipmentData.SpecialEquipment) do
                    if tpl.skillId == itemData.skillId and tpl.slot == itemData.slot
                        and tpl.tier == itemData.tier then
                        specialTpl = tpl
                        break
                    end
                end
            end
        end
        if fabaoTpl then
            -- 法宝名称 = "法宝名Lv.声望等级"（声望等级 = tier - 2）
            local repLevel = math.max(1, tier - 2)
            itemData.name = fabaoTpl.name .. "Lv." .. repLevel
        elseif specialTpl then
            itemData.name = specialTpl.name
        elseif not itemData.name then
            local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
            itemData.name = tierNames and tierNames[itemData.slot]
                or EquipmentData.SLOT_NAMES[itemData.slot] or itemData.slot
        end
        if not itemData.icon then
            if fabaoTpl then
                itemData.icon = fabaoTpl.iconByTier[tier] or fabaoTpl.iconByTier[9] or "icon_fabao.png"
            elseif specialTpl then
                itemData.icon = specialTpl.icon
            else
                itemData.icon = LootSystem.GetSlotIcon(itemData.slot, tier)
            end
        end
        -- 葫芦图标兼容：旧存档中可能是 icon_treasure/icon_jade_gourd，统一为品质图标
        if itemData.slot == "treasure" and itemData.icon
            and not itemData.icon:find("^image/gourd_") then
            itemData.icon = LootSystem.GetGourdIcon(itemData.quality or "green")
        end
        if fabaoTpl then
            -- 法宝出售：灵器及以上走灵韵，其余走金币（按 tier 定价）
            local qOrder = itemData.quality and GameConfig.QUALITY_ORDER[itemData.quality] or 0
            if qOrder >= 6 then
                itemData.sellCurrency = "lingYun"
                itemData.sellPrice = math.max(1, tier - 4)
            else
                itemData.sellPrice = fabaoTpl.sellPriceByTier[tier] or 100
            end
            -- 法宝 skillId 恢复（以防存档裁剪）
            if not itemData.skillId then
                itemData.skillId = fabaoTpl.skillId
            end
        elseif specialTpl then
            itemData.sellPrice = specialTpl.sellPrice or 100
            itemData.sellCurrency = specialTpl.sellCurrency
        elseif not itemData.sellPrice then
            local qualityConfig = itemData.quality and GameConfig.QUALITY[itemData.quality]
            local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
            itemData.sellPrice = math.floor(10 * tier * qualityMult)
        end
        if not specialTpl and not fabaoTpl and not itemData.sellCurrency then
            local qOrder = itemData.quality and GameConfig.QUALITY_ORDER[itemData.quality] or 0
            if qOrder >= 6 then
                itemData.sellCurrency = "lingYun"
                itemData.sellPrice = math.max(1, tier - 4)
            end
        end
        if not itemData.specialEffect and specialTpl and specialTpl.specialEffect then
            itemData.specialEffect = specialTpl.specialEffect
        end
        if itemData.subStats then
            for _, sub in ipairs(itemData.subStats) do
                if not sub.name and sub.stat then
                    for _, def in ipairs(EquipmentData.SUB_STATS) do
                        if def.stat == sub.stat then
                            sub.name = def.name
                            break
                        end
                    end
                end
            end
        end
    end

    -- 导出 fillEquipFields 供外部使用（保持 API 兼容）
    SaveSerializer.fillEquipFields = fillEquipFields

    if data.equipment then
        for slotId, itemData in pairs(data.equipment) do
            NormalizePercentStats(itemData)
            if itemData.slot and not itemData.tier then
                itemData.tier = 1
            end
            if not itemData.type then
                if slotId == "ring1" or slotId == "ring2" then
                    itemData.type = "ring"
                else
                    itemData.type = slotId
                end
            end
            fillEquipFields(itemData)
            local ok, err = mgr:SetEquipmentItem(slotId, itemData)
            if not ok then
                print("[SaveSystem] WARNING: equipment restore failed for " .. slotId .. ": " .. tostring(err))
            end
        end
    end

    if data.backpack then
        local PetSkillData = require("config.PetSkillData")
        for indexStr, itemData in pairs(data.backpack) do
            local index = tonumber(indexStr)
            if index then
                NormalizePercentStats(itemData)
                if itemData.consumableId and not itemData.isSkillBook then
                    local bookData = PetSkillData.SKILL_BOOKS[itemData.consumableId]
                    if bookData then
                        itemData.isSkillBook = true
                        itemData.skillId = itemData.skillId or bookData.skillId
                        itemData.bookTier = itemData.bookTier or bookData.tier
                    end
                end
                if itemData.consumableId then
                    if itemData.isSkillBook then
                        local bookData = PetSkillData.SKILL_BOOKS[itemData.consumableId]
                        if bookData then
                            itemData.icon = bookData.icon
                            itemData.name = bookData.name
                        end
                    else
                        local cfgData = GameConfig.PET_FOOD[itemData.consumableId]
                            or GameConfig.PET_MATERIALS[itemData.consumableId]
                        if cfgData then
                            itemData.icon = cfgData.icon
                            itemData.name = cfgData.name
                        end
                    end
                end
                if itemData.count and itemData.count > GameConfig.MAX_STACK_COUNT then
                    print("[SaveSystem] WARNING: consumable '" .. (itemData.consumableId or "?")
                        .. "' count=" .. itemData.count .. " exceeds MAX_STACK("
                        .. GameConfig.MAX_STACK_COUNT .. "), clamping")
                    itemData.count = GameConfig.MAX_STACK_COUNT
                end
                if itemData.slot and not itemData.tier then
                    itemData.tier = 1
                end
                fillEquipFields(itemData)
                mgr:SetInventoryItem(index, itemData)
            end
        end
    end

    InventorySystem.RecalcEquipStats()
    print("[SaveSystem] Inventory restored")
end

-- ============================================================================
-- 宠物
-- ============================================================================

--- 序列化宠物数据
---@return table
function SaveSerializer.SerializePet()
    local pet = GameState.pet
    if not pet then return {} end

    local skillsData = {}
    if pet.skills then
        for i, skill in pairs(pet.skills) do
            if skill then
                skillsData[tostring(i)] = { id = skill.id, tier = skill.tier }
            end
        end
    end

    -- 外观数据（v20）
    local appearanceData = nil
    if pet.appearance and pet.appearance.selectedId then
        appearanceData = { selectedId = pet.appearance.selectedId }
    end

    return {
        name = pet.name,
        level = pet.level,
        exp = pet.exp,
        tier = pet.tier,
        hp = pet.hp,
        alive = pet.alive,
        deathTimer = pet.alive and 0 or pet.deathTimer,
        skills = skillsData,
        appearance = appearanceData,
    }
end

--- 反序列化宠物数据
---@param data table
function SaveSerializer.DeserializePet(data)
    local pet = GameState.pet
    if not pet or not data then return end

    pet.name = data.name or "小黄"
    pet.level = data.level or 1
    pet.exp = data.exp or 0
    pet.tier = data.tier or 0

    pet.skills = {}
    if data.skills then
        local seenIds = {}
        for indexStr, skillData in pairs(data.skills) do
            local index = tonumber(indexStr)
            if index and skillData and skillData.id then
                if seenIds[skillData.id] then
                    print("[SaveSystem] WARNING: 宠物技能重复! slot=" .. index .. " id=" .. skillData.id .. " (已在slot " .. seenIds[skillData.id] .. ")")
                else
                    pet.skills[index] = { id = skillData.id, tier = skillData.tier or 1 }
                    seenIds[skillData.id] = index
                end
            end
        end
    end

    -- 外观数据恢复（v20+，nil 安全）
    if data.appearance and data.appearance.selectedId then
        pet.appearance = { selectedId = data.appearance.selectedId }
    end

    pet:RecalcStats()

    if data.alive == false then
        pet.alive = false
        pet.hp = 0
        pet.state = "dead"
        pet.deathTimer = data.deathTimer or 0
    else
        pet.alive = true
        pet.hp = math.min(data.hp or pet.maxHp, pet.maxHp)
        pet.state = "follow"
    end

    print("[SaveSystem] Pet data restored: " .. pet.name .. " Tier " .. pet.tier .. " Lv." .. pet.level)
end

-- ============================================================================
-- 技能/图录/称号/商店
-- ============================================================================

function SaveSerializer.SerializeSkills()
    local SkillSystem = require("systems.SkillSystem")
    return { skillBar = SkillSystem.GetSkillBarSlots() }
end

function SaveSerializer.DeserializeSkills(data)
    if not data then return end
    local SkillSystem = require("systems.SkillSystem")
    if data.skillBar then
        SkillSystem.RestoreSkillBar(data.skillBar)
    end
    print("[SaveSystem] Skills restored")
end

function SaveSerializer.SerializeCollection()
    local CollectionSystem = require("systems.CollectionSystem")
    return CollectionSystem.Serialize()
end

function SaveSerializer.DeserializeCollection(data)
    local CollectionSystem = require("systems.CollectionSystem")
    CollectionSystem.Deserialize(data)
end

function SaveSerializer.SerializeTitles()
    local TitleSystem = require("systems.TitleSystem")
    return TitleSystem.Serialize()
end

function SaveSerializer.DeserializeTitles(data)
    local TitleSystem = require("systems.TitleSystem")
    TitleSystem.Deserialize(data)
end

function SaveSerializer.SerializeShop()
    -- v13: 丹药计数已迁移到 player 序列化，shop 保留空结构兼容旧代码引用
    return {}
end

function SaveSerializer.DeserializeShop(data)
    -- v13: 丹药计数已迁移到 DeserializePlayer，shop 无需反序列化丹药
    -- 保留兼容旧存档：如果 shop 中还有丹药字段（v12 及更早），迁移管线已在 MIGRATIONS[13] 处理
    if not data then return end
    print("[SaveSystem] Shop data restored (v13: pill counts moved to player)")
end

-- ============================================================================
-- 仓库序列化/反序列化
-- ============================================================================

--- 序列化仓库
---@return table
function SaveSerializer.SerializeWarehouse()
    local WarehouseSystem = require("systems.WarehouseSystem")
    return WarehouseSystem.Serialize()
end

--- 反序列化仓库
---@param data table
function SaveSerializer.DeserializeWarehouse(data)
    local WarehouseSystem = require("systems.WarehouseSystem")
    WarehouseSystem.Deserialize(data)
end

-- ============================================================================
-- 仙图录
-- ============================================================================

function SaveSerializer.SerializeAtlas()
    local AtlasSystem = require("systems.AtlasSystem")
    return AtlasSystem.Serialize()
end

function SaveSerializer.DeserializeAtlas(data)
    local AtlasSystem = require("systems.AtlasSystem")
    AtlasSystem.Deserialize(data)
end

return SaveSerializer
