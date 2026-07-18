-- ============================================================================
-- test_ch1_ch2_drop_contract.lua
-- 第一章/第二章掉落契约：宠物食物单框、Boss 灵韵单框与期望值
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

local function assertNear(actual, expected, msg)
    if math.abs((actual or 0) - expected) > 0.000001 then
        error((msg or "assertNear failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual), 2)
    end
end

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

local GameConfig = require("config.GameConfig")
local MonsterData = require("config.MonsterData")

local PET_FOOD = GameConfig.PET_FOOD or {}

local function amountExpected(amount)
    if type(amount) == "table" then
        return ((amount[1] or 1) + (amount[2] or amount[1] or 1)) * 0.5
    end
    return amount or 1
end

local function getMonster(monsterId)
    local monster = MonsterData.Types and MonsterData.Types[monsterId]
    assertTrue(monster ~= nil, "monster missing: " .. monsterId)
    return monster
end

local function getFoodDrops(monsterId)
    local drops = {}
    for _, drop in ipairs(getMonster(monsterId).dropTable or {}) do
        if drop.type == "consumable" and drop.consumableId and PET_FOOD[drop.consumableId] then
            drops[#drops + 1] = drop
        end
    end
    return drops
end

local function getLingYunDrops(monsterId)
    local drops = {}
    for _, drop in ipairs(getMonster(monsterId).dropTable or {}) do
        if drop.type == "lingYun" then
            drops[#drops + 1] = drop
        end
    end
    return drops
end

local function getDrops(monsterId, predicate)
    local drops = {}
    for _, drop in ipairs(getMonster(monsterId).dropTable or {}) do
        if predicate(drop) then
            drops[#drops + 1] = drop
        end
    end
    return drops
end

local function checkFood(spec)
    test(spec.id .. " food", function()
        local drops = getFoodDrops(spec.id)
        assertEqual(#drops, 1, spec.id .. " food drop count")
        local drop = drops[1]
        assertEqual(drop.consumableId, spec.food, spec.id .. " food id")
        assertNear(drop.chance, spec.chance, spec.id .. " food chance")
        local exp = PET_FOOD[drop.consumableId].exp * drop.chance * amountExpected(drop.amount)
        assertNear(exp, spec.expected, spec.id .. " food expected exp")
    end)
end

local function checkLingYun(spec)
    test(spec.id .. " lingYun", function()
        local drops = getLingYunDrops(spec.id)
        assertEqual(#drops, 1, spec.id .. " lingYun drop count")
        local drop = drops[1]
        assertNear(drop.chance, spec.chance, spec.id .. " lingYun chance")
        assertEqual(drop.amount and drop.amount[1], spec.amount[1], spec.id .. " lingYun min")
        assertEqual(drop.amount and drop.amount[2], spec.amount[2], spec.id .. " lingYun max")
        assertNear(drop.chance * amountExpected(drop.amount), spec.expected, spec.id .. " lingYun expected")
    end)
end

local trackedMonsterIds = {
    "spider_trail",
    "boar_patrol",
    "spider_small",
    "spider_elite",
    "spider_queen",
    "boar_small",
    "boar_captain",
    "boar_king",
    "bandit_small",
    "bandit_guard",
    "bandit_second",
    "bandit_strategist",
    "bandit_guard_back",
    "bandit_chief",
    "tiger_elite",
    "tiger_king",
    "frog",
    "black_boar",
    "swamp_snake",
    "poison_snake",
    "red_boar_elite",
    "boar_boss_ch2",
    "snake_king",
    "xueshameng_corpse",
    "haoqizong_corpse",
    "wu_soldier",
    "wu_servant",
    "wu_blood_puppet",
    "wu_dibei",
    "wu_tiannan",
    "wu_dasha",
    "wu_ersha",
    "wu_wanchou",
    "wu_wanhai",
}

local trackedBossIds = {
    "boar_patrol",
    "spider_queen",
    "boar_king",
    "bandit_second",
    "bandit_chief",
    "tiger_king",
    "boar_boss_ch2",
    "snake_king",
    "wu_dibei",
    "wu_tiannan",
    "wu_dasha",
    "wu_ersha",
    "wu_wanchou",
    "wu_wanhai",
}

test("tracked ch1/ch2 monsters use at most one pet food roll", function()
    for _, monsterId in ipairs(trackedMonsterIds) do
        local drops = getFoodDrops(monsterId)
        assertTrue(#drops <= 1, monsterId .. " has duplicated pet food drops")
    end
end)

test("tracked ch1/ch2 bosses use at most one LingYun roll", function()
    for _, monsterId in ipairs(trackedBossIds) do
        local drops = getLingYunDrops(monsterId)
        assertTrue(#drops <= 1, monsterId .. " has duplicated LingYun drops")
    end
end)

test("boar_boss_ch2 does not drop ordinary spirit_pill", function()
    local drops = getDrops("boar_boss_ch2", function(drop)
        return drop.type == "consumable" and drop.consumableId == "spirit_pill"
    end)
    assertEqual(#drops, 0, "boar_boss_ch2 spirit_pill drop count")
end)

test("ch2 boss_pill_ch2 chance is 1.5 percent", function()
    for _, monsterId in ipairs({
        "wu_dibei",
        "wu_tiannan",
        "wu_dasha",
        "wu_ersha",
        "wu_wanchou",
        "wu_wanhai",
    }) do
        local drops = getDrops(monsterId, function(drop)
            return drop.type == "world_drop" and drop.pool == "boss_pill_ch2"
        end)
        assertEqual(#drops, 1, monsterId .. " boss_pill_ch2 drop count")
        assertNear(drops[1].chance, 0.015, monsterId .. " boss_pill_ch2 chance")
    end
end)

test("wu normal monsters random equipment chance is 10 percent", function()
    for _, monsterId in ipairs({ "wu_soldier", "wu_servant" }) do
        local drops = getDrops(monsterId, function(drop)
            return drop.type == "equipment" and drop.equipId == nil
        end)
        assertEqual(#drops, 1, monsterId .. " random equipment drop count")
        assertNear(drops[1].chance, 0.10, monsterId .. " random equipment chance")
    end
end)

print("--- Ch1/Ch2 drop contract: pet food exp ---")

for _, spec in ipairs({
    { id = "spider_trail", food = "meat_bone", chance = 0.20, expected = 4 },
    { id = "frog", food = "meat_bone", chance = 0.50, expected = 10 },
    { id = "spider_small", food = "meat_bone", chance = 0.30, expected = 6 },
    { id = "boar_small", food = "meat_bone", chance = 0.40, expected = 8 },
    { id = "bandit_small", food = "meat_bone", chance = 0.50, expected = 10 },
    { id = "bandit_guard", food = "meat_bone", chance = 0.60, expected = 12 },
    { id = "bandit_guard_back", food = "meat_bone", chance = 0.60, expected = 12 },
    { id = "spider_elite", food = "spirit_meat", chance = 0.15, expected = 12 },
    { id = "boar_captain", food = "spirit_meat", chance = 0.20, expected = 16 },
    { id = "bandit_strategist", food = "spirit_meat", chance = 0.25, expected = 20 },
    { id = "tiger_elite", food = "spirit_meat", chance = 0.25, expected = 20 },
    { id = "boar_patrol", food = "spirit_meat", chance = 0.20, expected = 16 },
    { id = "spider_queen", food = "spirit_meat", chance = 0.30, expected = 24 },
    { id = "boar_king", food = "spirit_meat", chance = 0.35, expected = 28 },
    { id = "bandit_second", food = "spirit_meat", chance = 0.40, expected = 32 },
    { id = "bandit_chief", food = "spirit_meat", chance = 0.45, expected = 36 },
    { id = "tiger_king", food = "immortal_bone", chance = 0.25, expected = 75 },
    { id = "black_boar", food = "meat_bone", chance = 0.70, expected = 14 },
    { id = "swamp_snake", food = "meat_bone", chance = 0.80, expected = 16 },
    { id = "poison_snake", food = "meat_bone", chance = 0.80, expected = 16 },
    { id = "wu_soldier", food = "meat_bone", chance = 0.90, expected = 18 },
    { id = "wu_servant", food = "meat_bone", chance = 1.0, expected = 20 },
    { id = "red_boar_elite", food = "spirit_meat", chance = 0.30, expected = 24 },
    { id = "xueshameng_corpse", food = "spirit_meat", chance = 0.40, expected = 32 },
    { id = "haoqizong_corpse", food = "spirit_meat", chance = 0.35, expected = 28 },
    { id = "wu_blood_puppet", food = "spirit_meat", chance = 0.45, expected = 36 },
    { id = "boar_boss_ch2", food = "beast_meat", chance = 0.20, expected = 32 },
    { id = "snake_king", food = "beast_meat", chance = 0.25, expected = 40 },
    { id = "wu_dibei", food = "beast_meat", chance = 0.30, expected = 48 },
    { id = "wu_tiannan", food = "beast_meat", chance = 0.35, expected = 56 },
    { id = "wu_dasha", food = "beast_meat", chance = 0.40, expected = 64 },
    { id = "wu_ersha", food = "beast_meat", chance = 0.40, expected = 64 },
    { id = "wu_wanchou", food = "beast_meat", chance = 0.50, expected = 80 },
    { id = "wu_wanhai", food = "immortal_bone", chance = 0.50, expected = 150 },
}) do
    checkFood(spec)
end

print("--- Ch1/Ch2 drop contract: boss LingYun ---")

for _, spec in ipairs({
    { id = "boar_patrol", chance = 0.20, amount = {1, 1}, expected = 0.2 },
    { id = "spider_queen", chance = 0.40, amount = {1, 1}, expected = 0.4 },
    { id = "boar_king", chance = 0.60, amount = {1, 1}, expected = 0.6 },
    { id = "bandit_second", chance = 0.80, amount = {1, 1}, expected = 0.8 },
    { id = "bandit_chief", chance = 1.0, amount = {1, 1}, expected = 1.0 },
    { id = "tiger_king", chance = 1.0, amount = {1, 2}, expected = 1.5 },
    { id = "boar_boss_ch2", chance = 1.0, amount = {1, 1}, expected = 1.0 },
    { id = "snake_king", chance = 1.0, amount = {1, 2}, expected = 1.5 },
    { id = "wu_dibei", chance = 1.0, amount = {1, 2}, expected = 1.5 },
    { id = "wu_tiannan", chance = 1.0, amount = {1, 2}, expected = 1.5 },
    { id = "wu_dasha", chance = 1.0, amount = {2, 2}, expected = 2.0 },
    { id = "wu_ersha", chance = 1.0, amount = {2, 2}, expected = 2.0 },
    { id = "wu_wanchou", chance = 1.0, amount = {2, 3}, expected = 2.5 },
    { id = "wu_wanhai", chance = 1.0, amount = {3, 3}, expected = 3.0 },
}) do
    checkLingYun(spec)
end

print(string.format("--- Ch1/Ch2 drop contract: %d/%d passed, %d failed ---", passed, total, failed))

return { passed = passed, failed = failed, total = total, errors = errors }
