-- ============================================================================
-- ForgeSystem.lua — 统一打造执行器
-- 所有打造逻辑的唯一入口：ForgeSystem.Execute(recipeId) → result
-- UI 层不再包含任何扣除/生成逻辑，仅做展示和调用本模块。
-- ============================================================================

local GameConfig     = require("config.GameConfig")
local EquipmentData  = require("config.EquipmentData")
local LootSystem     = require("systems.LootSystem")
local EventBus       = require("core.EventBus")
local GameState      = require("core.GameState")
local ForgeStatRules = require("systems.forge.ForgeStatRules")

local ForgeSystem = {}

-- ============================================================================
-- 内部工具函数
-- ============================================================================

--- 获取当前装备栏武器
---@return table|nil
local function GetEquippedWeapon()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return nil end
    return mgr:GetEquipmentItem("weapon")
end

--- 判断 equipId 是否在白名单中
---@param list string[]|nil
---@param equipId string|nil
---@return boolean
local function ContainsEquipId(list, equipId)
    if not list or not equipId then return false end
    for _, id in ipairs(list) do
        if id == equipId then return true end
    end
    return false
end

--- 归一化装备运行时字段（绕过 InventorySystem.AddItem 的原地替换也必须补齐）
---@param item table|nil
local function NormalizeEquipmentRuntimeFields(item)
    if not item then return end
    if item.slot == "ring1" or item.slot == "ring2" then
        item.type = "ring"
    else
        item.type = item.slot or item.type
    end
end

--- 将当前装备栏武器替换为指定特殊装备模板，不保留洗练属性
---@param weapon table 当前装备栏武器引用
---@param targetId string 目标 SpecialEquipment key
---@return boolean success
---@return string|nil error
local function ReplaceWeaponWithSpecialEquipmentNoForgeStat(weapon, targetId)
    local newItem = LootSystem.CreateSpecialEquipment(targetId)
    if not newItem then
        return false, "CreateSpecialEquipment 返回 nil: " .. tostring(targetId)
    end

    local oldId = weapon.id
    local keys = {}
    for k, _ in pairs(weapon) do
        table.insert(keys, k)
    end
    for _, k in ipairs(keys) do
        weapon[k] = nil
    end
    for k, v in pairs(newItem) do
        weapon[k] = v
    end
    if oldId then
        weapon.id = oldId
    end
    NormalizeEquipmentRuntimeFields(weapon)
    weapon.forgeStat = nil
    return true, nil
end

--- 将当前武器替换为二次解封仙剑：清除洗练/旧灵性/旧圣性并重生成圣性。
---@param weapon table 当前装备栏武器引用
---@param outputId string 目标 SpecialEquipment key
---@return boolean success
---@return string|nil error
local function GenerateTrueSword(weapon, outputId)
    local newItem = LootSystem.CreateSaintEquipment(outputId)
    if not newItem then
        return false, "CreateSaintEquipment 返回 nil: " .. tostring(outputId)
    end

    local oldId = weapon.id
    local keys = {}
    for k, _ in pairs(weapon) do
        table.insert(keys, k)
    end
    for _, k in ipairs(keys) do
        weapon[k] = nil
    end
    for k, v in pairs(newItem) do
        weapon[k] = v
    end
    if oldId then
        weapon.id = oldId
    end

    NormalizeEquipmentRuntimeFields(weapon)
    weapon.forgeStat = nil
    weapon.spiritStat = nil
    return true, nil
end

--- 从背包中查找指定 equipId 的物品（排除 usedSlots 中已占用的槽位）
---@param manager table
---@param equipId string
---@param usedSlots table<number, boolean>
---@return table|nil item
---@return number|nil slot
local function FindBagItemByEquipId(manager, equipId, usedSlots)
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not (usedSlots and usedSlots[i]) then
            local it = manager:GetInventoryItem(i)
            if it and it.equipId == equipId then
                return it, i
            end
        end
    end
    return nil, nil
end

-- ============================================================================
-- 生成器：special_equipment（龙神圣器，T9红，spiritStat，inline 副属性生成）
-- 复制自 DragonForgeUI.DoForge 的 inline 逻辑，确保数值一致。
-- ============================================================================

--- 生成龙神圣器属性（不创建新 item，而是直接替换 weapon 字段）
---@param weapon table 当前装备栏武器引用
---@param targetId string SpecialEquipment 中的 key
---@return boolean success
---@return string|nil error
local function GenerateSpecialEquipment(weapon, targetId)
    local targetDef = EquipmentData.SpecialEquipment[targetId]
    if not targetDef then
        return false, "配方目标数据不存在: " .. tostring(targetId)
    end

    -- 保留洗练
    local oldForgeStat = weapon.forgeStat

    -- 替换基础字段
    weapon.equipId       = targetId
    weapon.name          = targetDef.name
    weapon.icon          = targetDef.icon
    weapon.quality       = targetDef.quality
    weapon.tier          = targetDef.tier
    weapon.sellPrice     = targetDef.sellPrice
    weapon.sellCurrency  = targetDef.sellCurrency
    weapon.mainStat      = {}
    for k, v in pairs(targetDef.mainStat) do
        weapon.mainStat[k] = v
    end

    -- 副属性：条目类型固定（来自模板），数值随机浮动
    weapon.subStats = {}
    for _, templateSub in ipairs(targetDef.subStats) do
        local value = ForgeStatRules.RollSpecialSubStat(
            templateSub.stat,
            targetDef.tier or 9,
            targetDef.quality or "red",
            ForgeStatRules.DRAGON_FORGE_FLUCTUATION
        ) or templateSub.value

        table.insert(weapon.subStats, {
            stat  = templateSub.stat,
            name  = templateSub.name,
            value = value,
        })
    end

    weapon.specialEffect = targetDef.specialEffect
    -- 灵性属性
    weapon.spiritStat = LootSystem.GenerateSpiritStat(9, "atk", "red")

    -- 恢复洗练
    if oldForgeStat then
        weapon.forgeStat = oldForgeStat
    end

    return true, nil
end

-- ============================================================================
-- 生成器：jiefeng_sword（解封古剑，T10圣器，saintStat，原地替换）
-- ============================================================================

--- 生成解封古剑并替换装备栏武器
---@param weapon table 当前装备栏武器引用
---@param outputId string 目标 equipId
---@return boolean success
---@return string|nil error
local function GenerateJiefengSword(weapon, outputId)
    local newItem = LootSystem.CreateJiefengSword(weapon, outputId)
    if not newItem then
        return false, "CreateJiefengSword 返回 nil: " .. tostring(outputId)
    end

    -- 保留洗练
    local oldForgeStat = weapon.forgeStat

    -- 就地替换所有字段
    weapon.equipId       = newItem.equipId
    weapon.name          = newItem.name
    weapon.icon          = newItem.icon
    weapon.quality       = newItem.quality
    weapon.tier          = newItem.tier
    weapon.sellPrice     = newItem.sellPrice
    weapon.sellCurrency  = newItem.sellCurrency
    weapon.mainStat      = newItem.mainStat
    weapon.subStats      = newItem.subStats
    weapon.specialEffect = newItem.specialEffect
    weapon.spiritStat    = newItem.spiritStat
    weapon.saintStat     = newItem.saintStat

    -- 恢复洗练
    if oldForgeStat then
        weapon.forgeStat = oldForgeStat
    end

    return true, nil
end

-- ============================================================================
-- 生成器调度：根据 generator.type 生成产物
-- 返回 (item_or_nil, error_or_nil)
-- 对于 replace_weapon 模式，item 为 nil（直接修改 weapon 引用），error 为 nil 表示成功
-- 对于 add_to_bag 模式，返回生成的 item
-- ============================================================================

---@param recipe table FORGE_RECIPES 中的配方定义
---@param weapon table|nil 装备栏武器（replace_weapon 模式时非 nil）
---@param fromBagItem table|nil 从背包取出的源物品（longhunling 需要）
---@return table|nil item  生成的产物（add_to_bag 模式）或 nil（replace_weapon 模式）
---@return string|nil error 错误信息
local function DispatchGenerator(recipe, weapon, fromBagItem)
    local gen = recipe.generator
    local genType = gen.type

    if genType == "special_equipment" then
        -- 直接修改 weapon
        local ok, err = GenerateSpecialEquipment(weapon, gen.targetId)
        if not ok then return nil, err end
        return nil, nil  -- replace_weapon 模式，无独立 item

    elseif genType == "fixed_special_equipment" then
        local item = LootSystem.CreateSpecialEquipment(gen.outputId)
        if not item then return nil, "CreateSpecialEquipment 返回 nil: " .. tostring(gen.outputId) end
        return item, nil

    elseif genType == "jiefeng_sword" then
        -- 直接修改 weapon
        local ok, err = GenerateJiefengSword(weapon, gen.outputId)
        if not ok then return nil, err end
        return nil, nil

    elseif genType == "true_sword" then
        local ok, err = GenerateTrueSword(weapon, gen.outputId)
        if not ok then return nil, err end
        return nil, nil

    elseif genType == "fabao" then
        local item = LootSystem.CreateFabaoEquipment(gen.templateId, gen.tier, gen.quality)
        if not item then return nil, "CreateFabaoEquipment 返回 nil" end
        return item, nil

    elseif genType == "longhunling" then
        if not fromBagItem then return nil, "longhunling 需要 fromBagItem" end
        local item = LootSystem.CreateLonghunling(fromBagItem)
        if not item then return nil, "CreateLonghunling 返回 nil" end
        return item, nil

    elseif genType == "saint_equipment" then
        local item = LootSystem.CreateSaintEquipment(gen.outputId)
        if not item then return nil, "CreateSaintEquipment 返回 nil: " .. tostring(gen.outputId) end
        return item, nil

    elseif genType == "random_lingqi_mixed" then
        local item
        local roll = math.random()
        if roll < (gen.setChance or 0.30) then
            item = LootSystem.ForgeRandomSetLingqi(gen.setPoolId, gen.tier)
        else
            item = LootSystem.ForgeRandomLingqi(nil, gen.tier, gen.quality)
        end
        if not item then return nil, "随机灵器生成返回 nil" end
        return item, nil

    elseif genType == "random_huangsha_weapon_except_equipped" then
        if not weapon then return nil, "黄沙换兵需要当前装备武器" end
        local pool = gen.pool or recipe.equipSourcePool
        if not ContainsEquipId(pool, weapon.equipId) then
            return nil, "当前装备不是黄沙武器"
        end

        local candidates = {}
        for _, equipId in ipairs(pool or {}) do
            if equipId ~= weapon.equipId then
                table.insert(candidates, equipId)
            end
        end
        if #candidates == 0 then
            return nil, "黄沙武器候选池为空"
        end

        local targetId = candidates[math.random(1, #candidates)]
        local ok, err = ReplaceWeaponWithSpecialEquipmentNoForgeStat(weapon, targetId)
        if not ok then return nil, err end
        return nil, nil

    else
        return nil, "未知生成器类型: " .. tostring(genType)
    end
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 检查配方的所有前置条件（不扣除、不生成）
--- 返回 { canForge=bool, error=string|nil, details=table }
---@param recipeId string
---@return table result
function ForgeSystem.Check(recipeId)
    local InventorySystem = require("systems.InventorySystem")
    local recipe = EquipmentData.FORGE_RECIPES[recipeId]
    if not recipe then
        return { canForge = false, error = "未知配方: " .. tostring(recipeId) }
    end

    local player = GameState.player
    if not player then
        return { canForge = false, error = "玩家数据不存在" }
    end

    local manager = InventorySystem.GetManager()
    if not manager then
        return { canForge = false, error = "背包系统异常" }
    end

    -- 金币检查
    if (recipe.gold or 0) > 0 and player.gold < recipe.gold then
        return { canForge = false, error = "金币不足，需要" .. recipe.gold }
    end

    -- 太虚令检查
    if (recipe.taixu_token or 0) > 0 then
        if InventorySystem.CountUnlockedConsumable("taixu_token") < recipe.taixu_token then
            return { canForge = false, error = "太虚令不足，需要" .. recipe.taixu_token .. "枚" }
        end
    end

    -- 武器装备检查（equip_weapon 模式）
    if recipe.inputMode == "equip_weapon" then
        local weapon = GetEquippedWeapon()
        if recipe.equipSourcePool then
            if not weapon or not ContainsEquipId(recipe.equipSourcePool, weapon.equipId) then
                return { canForge = false, error = "请先装备黄沙武器" }
            end
        elseif not weapon or weapon.equipId ~= recipe.equipSource then
            local def = EquipmentData.SpecialEquipment[recipe.equipSource]
            return { canForge = false, error = "请先装备「" .. (def and def.name or recipe.equipSource) .. "」" }
        end
    end

    -- 背包物品检查
    local usedSlots = {}

    if recipe.fromBag then
        local _, slot = FindBagItemByEquipId(manager, recipe.fromBag.equipId, usedSlots)
        if not slot then
            local def = EquipmentData.SpecialEquipment[recipe.fromBag.equipId]
                     or EquipmentData.FabaoTemplates[recipe.fromBag.equipId]
            return { canForge = false, error = "背包中缺少：" .. (def and def.name or recipe.fromBag.equipId) }
        end
        usedSlots[slot] = true
    end

    if recipe.fromBag2 then
        local _, slot = FindBagItemByEquipId(manager, recipe.fromBag2.equipId, usedSlots)
        if not slot then
            local def = EquipmentData.SpecialEquipment[recipe.fromBag2.equipId]
            return { canForge = false, error = "背包中缺少：" .. (def and def.name or recipe.fromBag2.equipId) }
        end
        usedSlots[slot] = true
    end

    if recipe.fromBagList then
        for _, fb in ipairs(recipe.fromBagList) do
            local _, slot = FindBagItemByEquipId(manager, fb.equipId, usedSlots)
            if not slot then
                local def = EquipmentData.SpecialEquipment[fb.equipId]
                return { canForge = false, error = "背包中缺少：" .. (def and def.name or fb.equipId) }
            end
            usedSlots[slot] = true
        end
    end

    -- 背包空间检查：允许消耗背包装备后腾出的格子承接产物。
    if recipe.outputMode == "add_to_bag" then
        local consumedSlots = 0
        for _ in pairs(usedSlots) do consumedSlots = consumedSlots + 1 end
        if InventorySystem.GetFreeSlots() + consumedSlots <= 0 then
            return { canForge = false, error = "背包已满，无法打造" }
        end
    end

    -- 普通材料检查
    for _, mat in ipairs(recipe.materials or {}) do
        if InventorySystem.CountUnlockedConsumable(mat.id) < mat.count then
            local matDef = (GameConfig.PET_MATERIALS and GameConfig.PET_MATERIALS[mat.id])
                or (GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[mat.id])
            return { canForge = false, error = "材料不足：" .. (matDef and matDef.name or mat.id) }
        end
    end

    return { canForge = true, error = nil }
end

--- 执行打造（验证 → 生成 → 扣除 → 输出）
--- 原子安全：先生成产物，确认成功后再扣除消耗。
---@param recipeId string 配方 ID（FORGE_RECIPES 的 key）
---@return table result { success=bool, error=string|nil, item=table|nil, weapon=table|nil }
function ForgeSystem.Execute(recipeId)
    local InventorySystem = require("systems.InventorySystem")

    -- 1. 读取配方
    local recipe = EquipmentData.FORGE_RECIPES[recipeId]
    if not recipe then
        return { success = false, error = "未知配方: " .. tostring(recipeId) }
    end

    local player = GameState.player
    if not player then
        return { success = false, error = "玩家数据不存在" }
    end

    local manager = InventorySystem.GetManager()
    if not manager then
        return { success = false, error = "背包系统异常" }
    end

    -- 2. 验证所有前置条件
    local check = ForgeSystem.Check(recipeId)
    if not check.canForge then
        return { success = false, error = check.error }
    end

    -- 3. 定位输入物品（收集 slot 引用，用于后续扣除）
    local weapon = nil
    if recipe.inputMode == "equip_weapon" then
        weapon = GetEquippedWeapon()
    end

    local usedSlots = {}
    local fromBagItem, fromBagSlot = nil, nil
    local fromBag2Slot = nil
    local fromBagListItems = {}

    if recipe.fromBag then
        fromBagItem, fromBagSlot = FindBagItemByEquipId(manager, recipe.fromBag.equipId, usedSlots)
        if fromBagSlot then usedSlots[fromBagSlot] = true end
    end

    if recipe.fromBag2 then
        _, fromBag2Slot = FindBagItemByEquipId(manager, recipe.fromBag2.equipId, usedSlots)
        if fromBag2Slot then usedSlots[fromBag2Slot] = true end
    end

    if recipe.fromBagList then
        for _, fb in ipairs(recipe.fromBagList) do
            local _, slot = FindBagItemByEquipId(manager, fb.equipId, usedSlots)
            if slot then
                table.insert(fromBagListItems, { slot = slot })
                usedSlots[slot] = true
            end
        end
    end

    -- 4. 原子安全：先生成产物
    local generatedItem, genErr = DispatchGenerator(recipe, weapon, fromBagItem)
    if genErr then
        return { success = false, error = "打造失败：" .. genErr }
    end

    -- 对于 add_to_bag 模式，确认产物有效
    if recipe.outputMode == "add_to_bag" and not generatedItem then
        return { success = false, error = "打造失败：生成器未返回产物" }
    end

    -- 5. 产物生成成功，开始扣除消耗（不可回滚点）

    -- 5a. 扣除金币
    if (recipe.gold or 0) > 0 then
        player:SpendGold(recipe.gold)
    end

    -- 5b. 扣除太虚令
    if (recipe.taixu_token or 0) > 0 then
        InventorySystem.ConsumeConsumable("taixu_token", recipe.taixu_token)
    end

    -- 5c. 移除背包物品（降序排列避免 slot 偏移）
    if #fromBagListItems > 0 then
        table.sort(fromBagListItems, function(a, b) return a.slot > b.slot end)
        for _, fb in ipairs(fromBagListItems) do
            manager:SetInventoryItem(fb.slot, nil)
        end
    end
    if fromBag2Slot then manager:SetInventoryItem(fromBag2Slot, nil) end
    if fromBagSlot then manager:SetInventoryItem(fromBagSlot, nil) end

    -- 5d. 扣除普通材料
    for _, mat in ipairs(recipe.materials or {}) do
        InventorySystem.ConsumeConsumable(mat.id, mat.count)
    end

    -- 6. 输出产物
    if recipe.outputMode == "add_to_bag" then
        local ok = InventorySystem.AddItem(generatedItem)
        if not ok then
            -- 极端情况：背包满了（理论上 Check 已拦截，此处为安全兜底）
            print("[ForgeSystem] WARNING: AddItem failed after generation for recipe=" .. recipeId)
            return { success = false, error = "放入背包失败", item = generatedItem }
        end
    end

    -- 7. 重新计算装备属性（replace_weapon 模式修改了 weapon 引用）
    if recipe.outputMode == "replace_weapon" then
        InventorySystem.RecalcEquipStats()
    end

    -- 8. 触发存档和事件
    EventBus.Emit("save_request")
    EventBus.Emit("equipment_changed")

    -- 9. 返回结果
    return {
        success = true,
        error   = nil,
        item    = generatedItem,   -- add_to_bag 模式下的产物
        weapon  = weapon,          -- replace_weapon 模式下的武器引用
    }
end

--- 获取配方列表（供 UI 展示用）
---@param stationId string 站点 ID
---@return table[] recipes  配方定义数组（带 recipeId 字段）
function ForgeSystem.GetRecipeList(stationId)
    local order = EquipmentData.FORGE_RECIPE_ORDER[stationId]
    if not order then return {} end
    local result = {}
    for _, recipeId in ipairs(order) do
        local recipe = EquipmentData.FORGE_RECIPES[recipeId]
        if recipe then
            -- 附加 recipeId 方便 UI 回调
            local entry = { recipeId = recipeId }
            setmetatable(entry, { __index = recipe })
            table.insert(result, entry)
        end
    end
    return result
end

return ForgeSystem
