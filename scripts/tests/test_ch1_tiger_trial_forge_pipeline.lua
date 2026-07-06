-- ============================================================================
-- test_ch1_tiger_trial_forge_pipeline.lua
-- 第一章虎王试炼炉流水线测试：参考第四/第五章锻造的 Check -> Execute 验收口径
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

local InventorySystem = { _mgr = nil }

function InventorySystem.SetManager(mgr) InventorySystem._mgr = mgr end
function InventorySystem.GetManager() return InventorySystem._mgr end
function InventorySystem.RecalcEquipStats() return true end
function InventorySystem.CountUnlockedConsumable() return 999999 end
function InventorySystem.ConsumeConsumable() return true end

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

local function makePlayer(gold)
    return {
        gold = gold or 10000,
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

local function newManager(slots)
    return {
        slots = slots or {},
        equipment = {},
        GetInventoryItem = function(self, index) return self.slots[index] end,
        SetInventoryItem = function(self, index, item) self.slots[index] = item end,
        GetEquipmentItem = function(self, slotId) return self.equipment[slotId] end,
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

local function findEquip(mgr, equipId)
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item and item.equipId == equipId then return item, i end
    end
    return nil, nil
end

local function resetEnv(slots, gold)
    emittedEvents = {}
    GameState.player = makePlayer(gold)
    local mgr = newManager(slots)
    InventorySystem.SetManager(mgr)
    return mgr
end

print("\n[test_ch1_tiger_trial_forge_pipeline] === 虎王试炼炉流水线 ===")

test("站点配方隔离：第一章只有极虎盔，第五章不串入", function()
    local tigerRecipes = ForgeSystem.GetRecipeList("tiger_trial_forge")
    assertEqual(#tigerRecipes, 1, "tiger recipe count")
    assertEqual(tigerRecipes[1].recipeId, "tiger_trial_jihu_helmet", "tiger recipe id")

    for _, recipe in ipairs(ForgeSystem.GetRecipeList("sword_forge")) do
        assertTrue(recipe.recipeId ~= "tiger_trial_jihu_helmet", "sword forge should not include tiger recipe")
    end
end)

test("Check 缺帝尊壹戒时拒绝打造", function()
    resetEnv({
        [1] = makeEquip("tiger_set_weapon"),
        [2] = makeEquip("tiger_set_armor"),
        [3] = makeEquip("tiger_set_necklace"),
    })
    local result = ForgeSystem.Check("tiger_trial_jihu_helmet")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("帝尊壹戒", 1, true) ~= nil, "error names missing item")
end)

test("Check 金币不足时拒绝打造", function()
    resetEnv({
        [1] = makeEquip("tiger_set_weapon"),
        [2] = makeEquip("tiger_set_armor"),
        [3] = makeEquip("tiger_set_necklace"),
        [4] = makeEquip("dizun_ring_ch1"),
    }, 9999)
    local result = ForgeSystem.Check("tiger_trial_jihu_helmet")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("金币不足", 1, true) ~= nil, "error names missing gold")
end)

test("Execute 成功扣四件材料，保留虎纹战袍，发放固定极虎盔", function()
    local mgr = resetEnv({
        [1] = makeEquip("tiger_set_weapon"),
        [2] = makeEquip("tiger_set_armor"),
        [3] = makeEquip("tiger_set_necklace"),
        [4] = makeEquip("tiger_set_cape"),
        [5] = makeEquip("dizun_ring_ch1"),
    })

    local result = ForgeSystem.Execute("tiger_trial_jihu_helmet")
    assertEqual(result.success, true, "execute success")
    assertEqual(result.item and result.item.equipId, "jihu_helmet_ch1", "result item id")
    assertEqual(countEquip(mgr, "tiger_set_weapon"), 0, "weapon consumed")
    assertEqual(countEquip(mgr, "tiger_set_armor"), 0, "armor consumed")
    assertEqual(countEquip(mgr, "tiger_set_necklace"), 0, "necklace consumed")
    assertEqual(countEquip(mgr, "dizun_ring_ch1"), 0, "ring consumed")
    assertEqual(countEquip(mgr, "tiger_set_cape"), 1, "cape kept")
    assertEqual(countEquip(mgr, "jihu_helmet_ch1"), 1, "helmet awarded")
    assertEqual(GameState.player.gold, 0, "gold consumed")

    local jihu = findEquip(mgr, "jihu_helmet_ch1")
    assertEqual(jihu and jihu.mainStat and jihu.mainStat.maxHp, 135, "fixed main stat")
    assertEqual(jihu and jihu.subStats and jihu.subStats[1].value, 5.4, "fixed atk substat")
    assertEqual(jihu and jihu.subStats and jihu.subStats[2].value, 0.024, "fixed critRate substat")
    assertEqual(jihu and jihu.subStats and jihu.subStats[3].value, 0.12, "fixed critDmg substat")
    assertEqual(jihu and jihu.fixedSubStats, true, "fixedSubStats kept")
    assertTrue(#emittedEvents >= 2, "save/equipment events emitted")
end)

test("满背包但消耗装备会腾格时仍可发奖", function()
    local slots = {
        [1] = makeEquip("tiger_set_weapon"),
        [2] = makeEquip("tiger_set_armor"),
        [3] = makeEquip("tiger_set_necklace"),
        [4] = makeEquip("dizun_ring_ch1"),
        [5] = makeEquip("tiger_set_cape"),
    }
    for i = 6, GameConfig.BACKPACK_SIZE do
        slots[i] = { id = "filler_" .. i, equipId = "filler_" .. i, slot = "misc" }
    end
    local mgr = resetEnv(slots)
    assertEqual(InventorySystem.GetFreeSlots(), 0, "backpack starts full")

    local check = ForgeSystem.Check("tiger_trial_jihu_helmet")
    assertEqual(check.canForge, true, "check allows freed material slots")
    local result = ForgeSystem.Execute("tiger_trial_jihu_helmet")
    assertEqual(result.success, true, "execute succeeds when full")
    assertEqual(countEquip(mgr, "jihu_helmet_ch1"), 1, "helmet awarded in freed slot")
    assertEqual(countEquip(mgr, "tiger_set_cape"), 1, "cape still kept")
    assertEqual(GameState.player.gold, 0, "gold consumed")
end)

GameState.player = originalPlayer
InventorySystem.SetManager(nil)
package.loaded["systems.InventorySystem"] = originalInventorySystem
package.loaded["core.EventBus"] = originalEventBus
package.loaded["systems.ForgeSystem"] = originalForgeSystem

print("")
if failed == 0 then
    print(string.format("[test_ch1_tiger_trial_forge_pipeline] %d/%d passed", passed, total))
else
    print(string.format("[test_ch1_tiger_trial_forge_pipeline] %d failed / %d total", failed, total))
    for _, err in ipairs(errors) do print("  - " .. err) end
end

return { passed = passed, failed = failed, total = total }
