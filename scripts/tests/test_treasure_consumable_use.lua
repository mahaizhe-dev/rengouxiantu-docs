-- ============================================================================
-- test_treasure_consumable_use.lua - treasure reward consumable settlement
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local moduleNames = {
    "config.GameConfig",
    "core.GameState",
    "core.EventBus",
    "systems.BlackMarketTradeLock",
    "systems.inventory.batch_use",
}
local originals = {}
for _, name in ipairs(moduleNames) do
    originals[name] = package.loaded[name]
end

local gameState = { player = nil }
package.loaded["config.GameConfig"] = {
    CONSUMABLES = {},
    REALMS = {},
    EXP_TABLE = {},
}
package.loaded["core.GameState"] = gameState
package.loaded["core.EventBus"] = {
    Emit = function() end,
}
package.loaded["systems.BlackMarketTradeLock"] = {
    LOCK_MESSAGE = "物品处于交易保护期",
}
package.loaded["systems.inventory.batch_use"] = nil

local BatchUse = require("systems.inventory.batch_use")

local passed, failed, total = 0, 0, 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  [PASS] " .. name)
    else
        failed = failed + 1
        print("  [FAIL] " .. name .. ": " .. tostring(err))
    end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual))
    end
end

local function assertTrue(value, message)
    if not value then error(message or "expected true") end
end

local function NewInventory(initial)
    local state = {
        counts = {},
        consumed = {},
    }
    for itemId, count in pairs(initial or {}) do
        state.counts[itemId] = count
    end

    local IS = {}
    function IS.CountUnlockedConsumable(itemId)
        return state.counts[itemId] or 0
    end
    function IS.CountConsumable(itemId)
        return state.counts[itemId] or 0
    end
    function IS.ConsumeConsumable(itemId, amount)
        local have = state.counts[itemId] or 0
        if have < amount then return false end
        state.counts[itemId] = have - amount
        state.consumed[itemId] = (state.consumed[itemId] or 0) + amount
        return true
    end
    return IS, state
end

local function ResetPlayer()
    local player = {
        lingYun = 0,
        gold = 0,
    }
    function player:GainLingYun(amount)
        self.lingYun = self.lingYun + amount
    end
    function player:GainGold(amount)
        self.gold = self.gold + amount
    end
    gameState.player = player
    return player
end

test("lingyun fruit grants exactly 50 lingyun each", function()
    local player = ResetPlayer()
    local IS, inventory = NewInventory({ lingyun_fruit = 3 })
    local ok, _, actual = BatchUse.UseBatchConsumable(IS, "lingyun_fruit", 3)
    assertTrue(ok)
    assertEqual(actual, 3)
    assertEqual(player.lingYun, 150)
    assertEqual(inventory.counts.lingyun_fruit, 0)
    assertEqual(inventory.consumed.lingyun_fruit, 3)
end)

test("superior lingyun fruit grants 500 each and clamps to inventory", function()
    local player = ResetPlayer()
    local IS, inventory = NewInventory({ lingyun_fruit_superior = 2 })
    local ok, _, actual = BatchUse.UseBatchConsumable(
        IS, "lingyun_fruit_superior", 5)
    assertTrue(ok)
    assertEqual(actual, 2)
    assertEqual(player.lingYun, 1000)
    assertEqual(inventory.counts.lingyun_fruit_superior, 0)
end)

test("supreme lingyun fruit grants exactly 5000 lingyun each", function()
    local player = ResetPlayer()
    local IS, inventory = NewInventory({ lingyun_fruit_supreme = 2 })
    local ok, _, actual = BatchUse.UseBatchConsumable(
        IS, "lingyun_fruit_supreme", 2)
    assertTrue(ok)
    assertEqual(actual, 2)
    assertEqual(player.lingYun, 10000)
    assertEqual(inventory.counts.lingyun_fruit_supreme, 0)
end)

test("ten-million gold box grants exactly 10000000 gold each", function()
    local player = ResetPlayer()
    local IS, inventory = NewInventory({ gold_box_10m = 2 })
    local ok, _, actual = BatchUse.UseBatchConsumable(IS, "gold_box_10m", 2)
    assertTrue(ok)
    assertEqual(actual, 2)
    assertEqual(player.gold, 20000000)
    assertEqual(inventory.counts.gold_box_10m, 0)
end)

test("treasure map batch use redirects without consuming the map", function()
    ResetPlayer()
    local IS, inventory = NewInventory({ treasure_map = 2 })
    local ok, message, actual = BatchUse.UseBatchConsumable(IS, "treasure_map", 1)
    assertEqual(ok, false)
    assertEqual(message, "藏宝图只能在第四章的藏宝图界面使用")
    assertEqual(actual, nil)
    assertEqual(inventory.counts.treasure_map, 2)
    assertEqual(inventory.consumed.treasure_map, nil)
end)

for _, name in ipairs(moduleNames) do
    package.loaded[name] = originals[name]
end

print(string.format("[test_treasure_consumable_use] passed=%d failed=%d total=%d",
    passed, failed, total))
return { passed = passed, failed = failed, total = total }
