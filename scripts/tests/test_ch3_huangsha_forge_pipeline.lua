-- ============================================================================
-- test_ch3_huangsha_forge_pipeline.lua
-- 第三章黄沙锻造台流水线测试：装备栏黄沙武器 -> 随机另一把黄沙武器
-- 说明：本测试替换 InventorySystem 单例，仅允许 lupa/offline 环境运行，禁止真实引擎 TestRegistry 自动执行。
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local passed, failed, total = 0, 0, 0
local errors = {}

local function assertTrue(cond, msg)
    if not cond then error(msg or "assertTrue failed", 2) end
end

local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assertEqual failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        errors[#errors + 1] = name .. ": " .. tostring(err)
        print("  ✗ " .. name .. ": " .. tostring(err))
    end
end

local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")

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

local InventorySystem = { _mgr = nil, recalcCount = 0, consumables = {} }

function InventorySystem.SetManager(mgr) InventorySystem._mgr = mgr end
function InventorySystem.GetManager() return InventorySystem._mgr end
function InventorySystem.RecalcEquipStats() InventorySystem.recalcCount = InventorySystem.recalcCount + 1; return true end
function InventorySystem.CountUnlockedConsumable(id) return InventorySystem.consumables[id] or 0 end
function InventorySystem.ConsumeConsumable(id, count)
    local have = InventorySystem.consumables[id] or 0
    if have < count then return false end
    InventorySystem.consumables[id] = have - count
    return true
end

function InventorySystem.GetFreeSlots()
    local mgr = InventorySystem.GetManager()
    if not mgr then return 0 end
    local free = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not mgr:GetInventoryItem(i) then free = free + 1 end
    end
    return free
end

function InventorySystem.AddItem(item)
    local mgr = InventorySystem.GetManager()
    if not mgr then return false, nil end
    return mgr:AddToInventory(item)
end

package.loaded["systems.InventorySystem"] = InventorySystem
package.loaded["systems.ForgeSystem"] = nil
local ForgeSystem = require("systems.ForgeSystem")

local HUANGSHA_POOL = {
    huangsha_duanliu = true,
    huangsha_fentian = true,
    huangsha_shihun = true,
    huangsha_liedi = true,
    huangsha_mieying = true,
}

local HUANGSHA_ORDER = {
    "huangsha_duanliu",
    "huangsha_fentian",
    "huangsha_shihun",
    "huangsha_liedi",
    "huangsha_mieying",
}

local function makePlayer(gold)
    return {
        gold = gold or 1000000,
        SpendGold = function(self, amount)
            if self.gold < amount then return false end
            self.gold = self.gold - amount
            return true
        end,
    }
end

local function makeEquip(equipId)
    local tpl = EquipmentData.SpecialEquipment[equipId]
    return {
        id = "test_" .. equipId,
        equipId = equipId,
        name = tpl and tpl.name or equipId,
        slot = tpl and tpl.slot or "material",
        tier = tpl and tpl.tier or 1,
        quality = tpl and tpl.quality or "white",
    }
end

local function newManager(slots, weapon)
    return {
        slots = slots or {},
        equipment = { weapon = weapon },
        GetInventoryItem = function(self, index) return self.slots[index] end,
        SetInventoryItem = function(self, index, item) self.slots[index] = item end,
        GetEquipmentItem = function(self, slotId) return self.equipment[slotId] end,
        SetEquipmentItem = function(self, slotId, item) self.equipment[slotId] = item end,
        AddToInventory = function(self, item)
            for i = 1, GameConfig.BACKPACK_SIZE do
                if not self.slots[i] then
                    self.slots[i] = item
                    return true, i
                end
            end
            return false, nil
        end,
    }
end

local function countEquip(mgr, equipId)
    local count = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item and item.equipId == equipId then count = count + 1 end
    end
    return count
end

local function resetEnv(slots, weapon, gold, consumables)
    emittedEvents = {}
    InventorySystem.recalcCount = 0
    InventorySystem.consumables = consumables or { sha_hai_ling = 1000 }
    GameState.player = makePlayer(gold)
    local mgr = newManager(slots, weapon)
    InventorySystem.SetManager(mgr)
    return mgr
end

print("\n[test_ch3_huangsha_forge_pipeline] === 黄沙锻造台流水线 ===")

test("站点配方隔离：第三章只有黄沙换兵，其他站点不串入", function()
    local recipes = ForgeSystem.GetRecipeList("huangsha_forge")
    assertEqual(#recipes, 1, "huangsha recipe count")
    assertEqual(recipes[1].recipeId, "huangsha_weapon_reroll", "huangsha recipe id")

    for _, stationId in ipairs({ "tiger_trial_forge", "wubao_forge", "dragon_forge", "sword_forge" }) do
        for _, recipe in ipairs(ForgeSystem.GetRecipeList(stationId)) do
            assertTrue(recipe.recipeId ~= "huangsha_weapon_reroll", stationId .. " should not include huangsha recipe")
        end
    end
end)

test("Check 未装备武器时拒绝打造", function()
    resetEnv({ [1] = makeEquip("dizun_ring_ch3") }, nil)
    local result = ForgeSystem.Check("huangsha_weapon_reroll")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("黄沙武器", 1, true) ~= nil, "error names huangsha weapon")
end)

test("Check 装备非黄沙武器时拒绝打造", function()
    resetEnv({ [1] = makeEquip("dizun_ring_ch3") }, makeEquip("tiger_set_weapon"))
    local result = ForgeSystem.Check("huangsha_weapon_reroll")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("黄沙武器", 1, true) ~= nil, "error names huangsha weapon")
end)

test("Check 缺帝尊叁戒时拒绝打造", function()
    resetEnv({}, makeEquip("huangsha_duanliu"))
    local result = ForgeSystem.Check("huangsha_weapon_reroll")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("帝尊叁戒", 1, true) ~= nil, "error names missing ring")
end)

test("Check 金币不足时拒绝打造", function()
    resetEnv({ [1] = makeEquip("dizun_ring_ch3") }, makeEquip("huangsha_duanliu"), 999999)
    local result = ForgeSystem.Check("huangsha_weapon_reroll")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("金币不足", 1, true) ~= nil, "error names missing gold")
end)

test("Check 缺沙海令时拒绝打造", function()
    resetEnv({ [1] = makeEquip("dizun_ring_ch3") }, makeEquip("huangsha_duanliu"), 1000000, { sha_hai_ling = 999 })
    local result = ForgeSystem.Check("huangsha_weapon_reroll")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("沙海令", 1, true) ~= nil, "error names missing sha hai ling")
end)

test("Execute 成功后保留可再次穿戴字段，消耗帝尊叁戒、沙海令和金币，当前武器转为另一把黄沙武器且不保留洗练", function()
    math.randomseed(20260710)
    local weapon = makeEquip("huangsha_duanliu")
    weapon.forgeStat = { stat = "atk", value = 99 }
    local oldId = weapon.id
    local mgr = resetEnv({ [1] = makeEquip("dizun_ring_ch3") }, weapon)

    local result = ForgeSystem.Execute("huangsha_weapon_reroll")
    assertEqual(result.success, true, "execute success")
    assertEqual(result.item, nil, "replace mode should not return bag item")
    assertTrue(result.weapon == mgr:GetEquipmentItem("weapon"), "result weapon is equipped weapon reference")
    assertTrue(HUANGSHA_POOL[result.weapon.equipId] == true, "result weapon is huangsha")
    assertEqual(result.weapon.slot, "weapon", "result weapon keeps equipment slot")
    assertEqual(result.weapon.type, "weapon", "result weapon can be equipped again after unequip")
    assertTrue(result.weapon.equipId ~= "huangsha_duanliu", "result excludes input weapon")
    assertEqual(result.weapon.id, oldId, "weapon object id kept for equipped reference")
    assertEqual(result.weapon.forgeStat, nil, "forgeStat is cleared")
    assertEqual(countEquip(mgr, "dizun_ring_ch3"), 0, "dizun ring consumed")
    assertEqual(InventorySystem.consumables.sha_hai_ling, 0, "sha hai ling consumed")
    assertEqual(GameState.player.gold, 0, "gold consumed")
    assertTrue(InventorySystem.recalcCount > 0, "equip stats recalculated")
    assertTrue(#emittedEvents >= 2, "save/equipment events emitted")
end)

test("Execute 对每一把黄沙输入都不会产出自身", function()
    for seedOffset, equipId in ipairs(HUANGSHA_ORDER) do
        math.randomseed(1000 + seedOffset)
        local weapon = makeEquip(equipId)
        local mgr = resetEnv({ [1] = makeEquip("dizun_ring_ch3") }, weapon)
        local result = ForgeSystem.Execute("huangsha_weapon_reroll")
        assertEqual(result.success, true, equipId .. " execute success")
        assertTrue(HUANGSHA_POOL[mgr:GetEquipmentItem("weapon").equipId] == true, equipId .. " output in pool")
        assertEqual(mgr:GetEquipmentItem("weapon").slot, "weapon", equipId .. " output slot is weapon")
        assertEqual(mgr:GetEquipmentItem("weapon").type, "weapon", equipId .. " output type is weapon")
        assertTrue(mgr:GetEquipmentItem("weapon").equipId ~= equipId, equipId .. " output excludes self")
    end
end)

GameState.player = originalPlayer
InventorySystem.SetManager(nil)
package.loaded["systems.InventorySystem"] = originalInventorySystem
package.loaded["core.EventBus"] = originalEventBus
package.loaded["systems.ForgeSystem"] = originalForgeSystem

print("")
if failed == 0 then
    print(string.format("[test_ch3_huangsha_forge_pipeline] %d/%d passed", passed, total))
else
    print(string.format("[test_ch3_huangsha_forge_pipeline] %d failed / %d total", failed, total))
    for _, err in ipairs(errors) do print("  - " .. err) end
end

return { passed = passed, failed = failed, total = total }
