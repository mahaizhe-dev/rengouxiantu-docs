-- ============================================================================
-- test_all_forge_pipeline.lua
-- 全配方离线流水线：仅限 Lupa，禁止在真实引擎 TestRegistry 自动执行。
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local LootSystem = require("systems.LootSystem")

local passed, failed, total = 0, 0, 0
local errors = {}

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS " .. name)
    else
        failed = failed + 1
        errors[#errors + 1] = name .. ": " .. tostring(err)
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

local function assertTrue(value, message)
    if not value then error(message or "assertTrue failed", 2) end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertEqual failed")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local function normalizeItem(item)
    if not item then return nil end
    if item.slot == "ring1" or item.slot == "ring2" then
        item.type = "ring"
    else
        item.type = item.slot or item.type
    end
    return item
end

local function makeEquip(equipId)
    local item
    if EquipmentData.SpecialEquipment[equipId] then
        item = LootSystem.CreateSpecialEquipment(equipId)
    elseif EquipmentData.FabaoTemplates[equipId] then
        local template = EquipmentData.FabaoTemplates[equipId]
        item = LootSystem.CreateFabaoEquipment(
            equipId,
            template.tier or 9,
            template.quality or "cyan"
        )
    end
    assertTrue(item ~= nil, "cannot create input equipment: " .. tostring(equipId))
    return normalizeItem(item)
end

local function expectedType(slotId)
    if slotId == "ring1" or slotId == "ring2" then return "ring" end
    return slotId
end

local function newManager(slots, equipment)
    return {
        slots = slots or {},
        equipment = equipment or {},
        GetInventoryItem = function(self, index)
            return self.slots[index]
        end,
        SetInventoryItem = function(self, index, item)
            self.slots[index] = item
            return true
        end,
        GetEquipmentItem = function(self, slotId)
            return self.equipment[slotId]
        end,
        SetEquipmentItem = function(self, slotId, item)
            if item and item.type ~= expectedType(slotId) then
                return false, "type mismatch"
            end
            self.equipment[slotId] = item
            return true
        end,
        GetAllEquipment = function(self)
            return self.equipment
        end,
        AddToInventory = function(self, item)
            for index = 1, GameConfig.BACKPACK_SIZE do
                if not self.slots[index] then
                    self.slots[index] = item
                    return true, index
                end
            end
            return false, nil
        end,
    }
end

local originalPlayer = GameState.player
local originalInventorySystem = package.loaded["systems.InventorySystem"]
local originalEventBus = package.loaded["core.EventBus"]
local originalForgeSystem = package.loaded["systems.ForgeSystem"]

local emittedEvents = {}
package.loaded["core.EventBus"] = {
    Emit = function(eventName)
        emittedEvents[#emittedEvents + 1] = eventName
    end,
}

local InventorySystem = {
    _manager = nil,
    consumables = {},
    recalcCount = 0,
}

function InventorySystem.GetManager()
    return InventorySystem._manager
end

function InventorySystem.SetManager(manager)
    InventorySystem._manager = manager
end

function InventorySystem.CountUnlockedConsumable(consumableId)
    return InventorySystem.consumables[consumableId] or 0
end

function InventorySystem.ConsumeConsumable(consumableId, count)
    local current = InventorySystem.consumables[consumableId] or 0
    if current < count then return false end
    InventorySystem.consumables[consumableId] = current - count
    return true
end

function InventorySystem.GetFreeSlots()
    local manager = InventorySystem.GetManager()
    local free = 0
    for index = 1, GameConfig.BACKPACK_SIZE do
        if not manager:GetInventoryItem(index) then free = free + 1 end
    end
    return free
end

function InventorySystem.AddItem(item)
    normalizeItem(item)
    return InventorySystem.GetManager():AddToInventory(item)
end

function InventorySystem.RecalcEquipStats()
    InventorySystem.recalcCount = InventorySystem.recalcCount + 1
    return true
end

package.loaded["systems.InventorySystem"] = InventorySystem
package.loaded["systems.ForgeSystem"] = nil
local ForgeSystem = require("systems.ForgeSystem")

local function makePlayer(gold)
    return {
        gold = gold,
        SpendGold = function(self, amount)
            if self.gold < amount then return false end
            self.gold = self.gold - amount
            return true
        end,
    }
end

local function addBagInput(slots, nextSlot, equipId)
    slots[nextSlot] = makeEquip(equipId)
    return nextSlot + 1
end

local function setupRecipe(recipeId)
    local recipe = EquipmentData.FORGE_RECIPES[recipeId]
    assertTrue(recipe ~= nil, "missing recipe: " .. tostring(recipeId))

    local slots = {}
    local nextSlot = 1
    if recipe.fromBag then
        nextSlot = addBagInput(slots, nextSlot, recipe.fromBag.equipId)
    end
    if recipe.fromBag2 then
        nextSlot = addBagInput(slots, nextSlot, recipe.fromBag2.equipId)
    end
    for _, entry in ipairs(recipe.fromBagList or {}) do
        nextSlot = addBagInput(slots, nextSlot, entry.equipId)
    end

    local equipment = {}
    if recipe.inputMode == "equip_weapon" then
        local sourceId = recipe.equipSource
            or (recipe.equipSourcePool and recipe.equipSourcePool[1])
        local weapon = makeEquip(sourceId)
        weapon.forgeStat = { stat = "atk", name = "攻击力", value = 99 }
        weapon.spiritStat = { stat = "def", name = "防御力", value = 88 }
        weapon.saintStat = { stat = "maxHp", name = "生命值", value = 77 }
        equipment.weapon = weapon
    end

    local consumables = {}
    for _, material in ipairs(recipe.materials or {}) do
        consumables[material.id] = (consumables[material.id] or 0) + material.count
    end
    if (recipe.taixu_token or 0) > 0 then
        consumables.taixu_token = recipe.taixu_token
    end

    emittedEvents = {}
    InventorySystem.consumables = consumables
    InventorySystem.recalcCount = 0
    InventorySystem.SetManager(newManager(slots, equipment))
    GameState.player = makePlayer(recipe.gold or 0)

    return recipe, InventorySystem.GetManager()
end

local function countBagItems(manager)
    local count = 0
    for index = 1, GameConfig.BACKPACK_SIZE do
        if manager:GetInventoryItem(index) then count = count + 1 end
    end
    return count
end

local function hasEvent(eventName)
    for _, emitted in ipairs(emittedEvents) do
        if emitted == eventName then return true end
    end
    return false
end

local function assertConsumablesSpent(recipe)
    for _, material in ipairs(recipe.materials or {}) do
        assertEqual(InventorySystem.consumables[material.id], 0,
            "material not fully consumed: " .. material.id)
    end
    if (recipe.taixu_token or 0) > 0 then
        assertEqual(InventorySystem.consumables.taixu_token, 0,
            "taixu_token not fully consumed")
    end
end

local function countRecipeBagInputs(recipe)
    local count = 0
    if recipe.fromBag then count = count + 1 end
    if recipe.fromBag2 then count = count + 1 end
    count = count + #(recipe.fromBagList or {})
    return count
end

local function assertReplaceWeaponCanReequip(recipeId, recipe, manager, result)
    local weapon = manager:GetEquipmentItem("weapon")
    assertTrue(result.weapon == weapon, recipeId .. " result reference mismatch")
    assertEqual(weapon.slot, "weapon", recipeId .. " slot missing after replacement")
    assertEqual(weapon.type, "weapon", recipeId .. " runtime type missing after replacement")

    local oldId = weapon.id
    local removed = manager:SetEquipmentItem("weapon", nil)
    assertTrue(removed == true, recipeId .. " cannot unequip result")
    local added, bagSlot = manager:AddToInventory(weapon)
    assertTrue(added == true, recipeId .. " cannot return result to bag")
    local bagWeapon = manager:GetInventoryItem(bagSlot)
    assertEqual(bagWeapon.id, oldId, recipeId .. " id changed after unequip")
    manager:SetInventoryItem(bagSlot, nil)
    local equipped, equipError = manager:SetEquipmentItem("weapon", bagWeapon)
    assertTrue(equipped == true,
        recipeId .. " cannot re-equip after unequip: " .. tostring(equipError))
    assertTrue(manager:GetEquipmentItem("weapon") == bagWeapon,
        recipeId .. " re-equipped reference mismatch")

    if recipe.generator.type == "random_huangsha_weapon_except_equipped"
        or recipe.generator.type == "true_sword" then
        assertEqual(bagWeapon.forgeStat, nil, recipeId .. " should clear forgeStat")
    end
    if recipe.generator.type == "true_sword" then
        assertEqual(bagWeapon.spiritStat, nil, recipeId .. " should clear spiritStat")
        assertTrue(bagWeapon.saintStat ~= nil, recipeId .. " should regenerate saintStat")
    end
end

local orderedRecipes = {}
local stationIds = {
    "tiger_trial_forge",
    "wubao_forge",
    "huangsha_forge",
    "dragon_forge",
    "sword_forge",
    "shadow_forge",
}

for _, stationId in ipairs(stationIds) do
    local recipes = ForgeSystem.GetRecipeList(stationId)
    for _, recipe in ipairs(recipes) do
        assertEqual(recipe.stationId, stationId,
            recipe.recipeId .. " station mismatch")
        orderedRecipes[#orderedRecipes + 1] = recipe.recipeId
    end
end

test("all current forge recipes are covered", function()
    assertEqual(#orderedRecipes, 29, "forge recipe total")
end)

for _, recipeId in ipairs(orderedRecipes) do
    test(recipeId .. " Check is read-only", function()
        local recipe, manager = setupRecipe(recipeId)
        local beforeGold = GameState.player.gold
        local beforeBagCount = countBagItems(manager)
        local beforeWeapon = manager:GetEquipmentItem("weapon")
        local beforeWeaponId = beforeWeapon and beforeWeapon.id
        local beforeConsumables = {}
        for id, count in pairs(InventorySystem.consumables) do
            beforeConsumables[id] = count
        end

        local checked = ForgeSystem.Check(recipeId)
        assertTrue(checked.canForge == true, checked.error)
        assertEqual(GameState.player.gold, beforeGold, "Check changed gold")
        assertEqual(countBagItems(manager), beforeBagCount, "Check changed bag")
        assertEqual(manager:GetEquipmentItem("weapon"), beforeWeapon, "Check changed weapon reference")
        assertEqual(beforeWeapon and beforeWeapon.id, beforeWeaponId, "Check changed weapon id")
        for id, count in pairs(beforeConsumables) do
            assertEqual(InventorySystem.consumables[id], count, "Check changed material " .. id)
        end
        assertEqual(InventorySystem.recalcCount, 0, "Check recalculated equipment")
        assertEqual(#emittedEvents, 0, "Check emitted events")
        assertTrue(recipe ~= nil, "recipe missing after Check")
    end)

    test(recipeId .. " Execute success pipeline", function()
        local recipe, manager = setupRecipe(recipeId)
        local inputBagCount = countBagItems(manager)
        local inputWeapon = manager:GetEquipmentItem("weapon")
        local inputWeaponId = inputWeapon and inputWeapon.id

        math.randomseed(20260711 + #recipeId)
        local result = ForgeSystem.Execute(recipeId)
        assertTrue(result.success == true, result.error)
        assertEqual(GameState.player.gold, 0, "gold not fully consumed")
        assertConsumablesSpent(recipe)
        assertTrue(hasEvent("save_request"), "save_request not emitted")
        assertTrue(hasEvent("equipment_changed"), "equipment_changed not emitted")

        if recipe.outputMode == "replace_weapon" then
            assertEqual(result.item, nil, "replace mode returned bag item")
            assertEqual(result.weapon.id, inputWeaponId, "replace mode changed object id")
            assertTrue(InventorySystem.recalcCount > 0, "replace mode did not recalc stats")
            assertReplaceWeaponCanReequip(recipeId, recipe, manager, result)
        else
            assertTrue(result.item ~= nil, "bag mode returned nil item")
            assertEqual(result.item.type, expectedType(result.item.slot),
                "bag output runtime type mismatch")
            assertEqual(countBagItems(manager), inputBagCount - countRecipeBagInputs(recipe) + 1,
                "bag output count does not match consumed inputs plus output")
            if recipe.generator.type == "saint_equipment" then
                assertTrue(result.item.saintStat ~= nil,
                    recipeId .. " saint equipment missing saintStat")
                assertEqual(result.item.spiritStat, nil,
                    recipeId .. " saint equipment kept spiritStat")
            end
        end
    end)

    test(recipeId .. " failed precondition is atomic", function()
        local recipe, manager = setupRecipe(recipeId)
        local weapon = manager:GetEquipmentItem("weapon")

        if recipe.inputMode == "equip_weapon" then
            manager:SetEquipmentItem("weapon", nil)
        elseif recipe.fromBag then
            manager:SetInventoryItem(1, nil)
        elseif recipe.fromBag2 then
            manager:SetInventoryItem(1, nil)
        elseif #(recipe.fromBagList or {}) > 0 then
            manager:SetInventoryItem(1, nil)
        elseif #(recipe.materials or {}) > 0 then
            local material = recipe.materials[1]
            InventorySystem.consumables[material.id] = material.count - 1
        elseif (recipe.gold or 0) > 0 then
            GameState.player.gold = recipe.gold - 1
        end

        local beforeGold = GameState.player.gold
        local beforeBagCount = countBagItems(manager)
        local beforeConsumables = {}
        for id, count in pairs(InventorySystem.consumables) do
            beforeConsumables[id] = count
        end

        local result = ForgeSystem.Execute(recipeId)
        assertTrue(result.success == false, "invalid recipe execution unexpectedly succeeded")
        assertEqual(GameState.player.gold, beforeGold, "failed Execute changed gold")
        assertEqual(countBagItems(manager), beforeBagCount, "failed Execute changed bag")
        if recipe.inputMode == "equip_weapon" then
            assertEqual(manager:GetEquipmentItem("weapon"), nil,
                "failed Execute restored or changed missing weapon")
            assertTrue(weapon ~= nil, "test setup weapon missing")
        end
        for id, count in pairs(beforeConsumables) do
            assertEqual(InventorySystem.consumables[id], count,
                "failed Execute changed material " .. id)
        end
        assertEqual(InventorySystem.recalcCount, 0, "failed Execute recalculated equipment")
        assertEqual(#emittedEvents, 0, "failed Execute emitted events")
    end)
end

GameState.player = originalPlayer
InventorySystem.SetManager(nil)
package.loaded["systems.InventorySystem"] = originalInventorySystem
package.loaded["core.EventBus"] = originalEventBus
package.loaded["systems.ForgeSystem"] = originalForgeSystem

print("")
print(string.format("[test_all_forge_pipeline] %d/%d passed", passed, total))
if failed > 0 then
    for _, err in ipairs(errors) do print("  - " .. err) end
end

return { passed = passed, failed = failed, total = total }
