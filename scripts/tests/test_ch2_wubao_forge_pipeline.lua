-- ============================================================================
-- test_ch2_wubao_forge_pipeline.lua
-- 第二章乌堡锻造台流水线测试：血海深仇戒 Check -> Execute
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
        gold = gold or 100000,
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

print("\n[test_ch2_wubao_forge_pipeline] === 乌堡锻造台流水线 ===")

test("站点配方隔离：第二章只有血海深仇戒，第一/五章不串入", function()
    local wubaoRecipes = ForgeSystem.GetRecipeList("wubao_forge")
    assertEqual(#wubaoRecipes, 1, "wubao recipe count")
    local firstRecipe = wubaoRecipes[1]
    assertTrue(firstRecipe ~= nil, "wubao first recipe exists")
    assertEqual(firstRecipe and firstRecipe.recipeId, "wubao_xuehai_shenchou_ring", "wubao recipe id")

    for _, recipe in ipairs(ForgeSystem.GetRecipeList("tiger_trial_forge")) do
        assertTrue(recipe.recipeId ~= "wubao_xuehai_shenchou_ring", "tiger forge should not include wubao recipe")
    end
    for _, recipe in ipairs(ForgeSystem.GetRecipeList("sword_forge")) do
        assertTrue(recipe.recipeId ~= "wubao_xuehai_shenchou_ring", "sword forge should not include wubao recipe")
    end
end)

test("Check 缺帝尊贰戒时拒绝打造", function()
    resetEnv({
        [1] = makeEquip("wu_ring_hai"),
        [2] = makeEquip("wu_ring_chou"),
    })
    local result = ForgeSystem.Check("wubao_xuehai_shenchou_ring")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("帝尊贰戒", 1, true) ~= nil, "error names missing item")
end)

test("Check 金币不足时拒绝打造", function()
    resetEnv({
        [1] = makeEquip("wu_ring_hai"),
        [2] = makeEquip("wu_ring_chou"),
        [3] = makeEquip("dizun_ring_ch2"),
    }, 99999)
    local result = ForgeSystem.Check("wubao_xuehai_shenchou_ring")
    assertEqual(result.canForge, false, "check should fail")
    assertTrue(tostring(result.error):find("金币不足", 1, true) ~= nil, "error names missing gold")
end)

test("Execute 成功扣三件材料，发放固定血海深仇戒", function()
    local mgr = resetEnv({
        [1] = makeEquip("wu_ring_hai"),
        [2] = makeEquip("wu_ring_chou"),
        [3] = makeEquip("dizun_ring_ch2"),
    })

    local result = ForgeSystem.Execute("wubao_xuehai_shenchou_ring")
    assertEqual(result.success, true, "execute success")
    assertEqual(result.item and result.item.equipId, "xuehai_shenchou_ring_ch2", "result item id")
    assertEqual(countEquip(mgr, "wu_ring_hai"), 0, "wu ring hai consumed")
    assertEqual(countEquip(mgr, "wu_ring_chou"), 0, "wu ring chou consumed")
    assertEqual(countEquip(mgr, "dizun_ring_ch2"), 0, "dizun ring consumed")
    assertEqual(countEquip(mgr, "xuehai_shenchou_ring_ch2"), 1, "ring awarded")
    local player = GameState.player
    assertTrue(player ~= nil, "player exists after execute")
    assertEqual(player and player.gold, 0, "gold consumed")

    local ring = findEquip(mgr, "xuehai_shenchou_ring_ch2")
    assertEqual(ring and ring.mainStat and ring.mainStat.atk, 36, "fixed main stat")
    assertEqual(ring and ring.subStats and ring.subStats[1].value, 0.033, "fixed critRate substat")
    assertEqual(ring and ring.subStats and ring.subStats[2].value, 48.4, "fixed heavyHit substat")
    assertEqual(ring and ring.subStats and ring.subStats[3].value, 9, "fixed constitution substat")
    assertEqual(ring and ring.fixedSubStats, true, "fixedSubStats kept")
    assertTrue(#emittedEvents >= 2, "save/equipment events emitted")
end)

test("满背包但消耗装备会腾格时仍可发奖", function()
    local slots = {
        [1] = makeEquip("wu_ring_hai"),
        [2] = makeEquip("wu_ring_chou"),
        [3] = makeEquip("dizun_ring_ch2"),
    }
    for i = 4, GameConfig.BACKPACK_SIZE do
        slots[i] = { id = "filler_" .. i, equipId = "filler_" .. i, slot = "misc" }
    end
    local mgr = resetEnv(slots)
    assertEqual(InventorySystem.GetFreeSlots(), 0, "backpack starts full")

    local check = ForgeSystem.Check("wubao_xuehai_shenchou_ring")
    assertEqual(check.canForge, true, "check allows freed material slots")
    local result = ForgeSystem.Execute("wubao_xuehai_shenchou_ring")
    assertEqual(result.success, true, "execute succeeds when full")
    assertEqual(countEquip(mgr, "xuehai_shenchou_ring_ch2"), 1, "ring awarded in freed slot")
    local player = GameState.player
    assertTrue(player ~= nil, "player exists after execute")
    assertEqual(player and player.gold, 0, "gold consumed")
end)

GameState.player = originalPlayer
InventorySystem.SetManager(nil)
package.loaded["systems.InventorySystem"] = originalInventorySystem
package.loaded["core.EventBus"] = originalEventBus
package.loaded["systems.ForgeSystem"] = originalForgeSystem

print("")
if failed == 0 then
    print(string.format("[test_ch2_wubao_forge_pipeline] %d/%d passed", passed, total))
else
    print(string.format("[test_ch2_wubao_forge_pipeline] %d failed / %d total", failed, total))
    for _, err in ipairs(errors) do print("  - " .. err) end
end

return { passed = passed, failed = failed, total = total }
