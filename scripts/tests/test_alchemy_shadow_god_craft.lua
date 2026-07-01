-- ============================================================================
-- test_alchemy_shadow_god_craft.lua
--
-- Focused regression for the chapter 6 permanent pill:
--   shadow_god: night_shadow_grass + 10000 lingYun + 1000000 gold
--   bonus: atk +5, shadowGodKillHeal +20, max 30 crafts
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

package.loaded["systems.AlchemySystem"] = nil
package.loaded["systems.InventorySystem"] = nil
package.loaded["core.GameState"] = nil
package.loaded["config.GameConfig"] = nil
package.loaded["config.PillRecipes"] = nil

local inventory = { night_shadow_grass = 1 }
local failConsume = false

package.loaded["systems.InventorySystem"] = {
    CountConsumable = function(id)
        return inventory[id] or 0
    end,
    CountUnlockedConsumable = function(id)
        return inventory[id] or 0
    end,
    ConsumeConsumable = function(id, count)
        if failConsume then return false end
        count = count or 1
        if (inventory[id] or 0) < count then return false end
        inventory[id] = (inventory[id] or 0) - count
        return true
    end,
    GetFreeSlots = function() return 10 end,
    AddConsumable = function(id, count)
        inventory[id] = (inventory[id] or 0) + (count or 1)
    end,
}

local GameState = { player = nil }
package.loaded["core.GameState"] = GameState

package.loaded["config.GameConfig"] = {
    PET_MATERIALS = {
        night_shadow_grass = { name = "shadow grass" },
    },
    PET_FOOD = {},
}

package.loaded["config.PillRecipes"] = {
    CONSUMABLES = {},
    TOKEN_BOXES = {},
    TOKEN_BOX_LINGYUN_COST = 100,
    TOKEN_BOX_TOKEN_COST = 5,
    STAT_DISPLAY = {
        atk = "ATK",
        shadowGodKillHeal = "KillHeal",
    },
    PERMANENTS = {
        shadow_god = {
            id = "shadow_god",
            name = "Shadow God Pill",
            cost = 10000,
            goldCost = 1000000,
            material = "night_shadow_grass",
            materialCount = 1,
            countKey = "shadowGod",
            maxCount = 30,
            bonuses = {
                { stat = "atk", value = 5 },
                { stat = "shadowGodKillHeal", value = 20 },
            },
        },
    },
}

local AlchemySystem = require("systems.AlchemySystem")

local passed = 0
local failed = 0
local total = 0

local function assert_eq(actual, expected, name)
    total = total + 1
    if actual == expected then
        passed = passed + 1
        print("  ok " .. name)
    else
        failed = failed + 1
        print("  fail " .. name .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

local function assert_true(value, name)
    assert_eq(value and true or false, true, name)
end

local function resetEnv()
    inventory = { night_shadow_grass = 1 }
    failConsume = false
    AlchemySystem.ResetRuntimeState()
    GameState.player = {
        lingYun = 10000,
        gold = 1000000,
        atk = 100,
        shadowGodKillHeal = 0,
        pillCounts = { shadow_god = 0 },
    }
    function GameState.player:InvalidateStatsCache()
        self.invalidated = true
    end
    function GameState.player:GetTotalMaxHp()
        return self.maxHp or 100
    end
    return GameState.player
end

print("\n[test_alchemy_shadow_god_craft] start")

do
    local player = resetEnv()
    local ok, err = AlchemySystem.CanCraftPermanent("shadow_god")
    assert_true(ok, "can craft with full resources")
    assert_eq(err, nil, "no can-craft error")

    local crafted, msg = AlchemySystem.CraftPermanent("shadow_god")
    assert_true(crafted, "craft succeeds")
    assert_true(type(msg) == "string", "craft returns message")
    assert_eq(player.lingYun, 0, "lingYun consumed")
    assert_eq(player.gold, 0, "gold consumed")
    assert_eq(inventory.night_shadow_grass, 0, "material consumed")
    assert_eq(player.atk, 105, "atk bonus applied")
    assert_eq(player.shadowGodKillHeal, 20, "kill-heal bonus applied")
    assert_eq(AlchemySystem.GetShadowGodPillCount(), 1, "count incremented")
    assert_eq(player.pillCounts.shadow_god, 1, "pillCounts synced")
    assert_true(player.invalidated, "stats cache invalidated")
end

do
    local player = resetEnv()
    player.gold = 999999
    local ok, err = AlchemySystem.CanCraftPermanent("shadow_god")
    assert_eq(ok, false, "gold shortage blocks can-craft")
    assert_true(type(err) == "string", "gold shortage has error")
end

do
    local player = resetEnv()
    failConsume = true
    local crafted = AlchemySystem.CraftPermanent("shadow_god")
    assert_eq(crafted, false, "consume failure blocks craft")
    assert_eq(player.lingYun, 10000, "consume failure rolls back lingYun")
    assert_eq(player.gold, 1000000, "consume failure rolls back gold")
    assert_eq(AlchemySystem.GetShadowGodPillCount(), 0, "consume failure keeps count")
end

do
    resetEnv()
    AlchemySystem.SetShadowGodPillCount(30)
    local ok = AlchemySystem.CanCraftPermanent("shadow_god")
    assert_eq(ok, false, "max count blocks can-craft")
end

print(string.format("[test_alchemy_shadow_god_craft] done: %d passed, %d failed, %d total", passed, failed, total))

return { passed = passed, failed = failed, total = total }
