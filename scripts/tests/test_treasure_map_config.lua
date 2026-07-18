package.path = package.path .. ";scripts/?.lua"

local Config = require("config.TreasureMapConfig")
local GameConfig = require("config.GameConfig")
local BlackMerchantConfig = require("config.BlackMerchantConfig")
local function LoadMonsterTypes(moduleName)
    local data = { Types = {}, RaceModifiers = {} }
    require(moduleName)(data)
    return data
end

local Ch4 = LoadMonsterTypes("config.MonsterTypes_ch4")
local Ch5 = LoadMonsterTypes("config.MonsterTypes_ch5")
local Ch6 = LoadMonsterTypes("config.MonsterTypes_ch6")

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

local function assertNear(actual, expected, epsilon, message)
    if math.abs(actual - expected) > epsilon then
        error((message or "values differ") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual))
    end
end

local function FindTreasureDrop(monster)
    local found = {}
    for _, drop in ipairs(monster.dropTable or {}) do
        if drop.type == "consumable" and drop.consumableId == "treasure_map" then
            found[#found + 1] = drop
        end
    end
    return found
end

local function RewardExpectedValue(skinValue, bodyValue, pureLingYun)
    local expected = 0
    for _, category in ipairs(Config.REWARD_CATEGORIES) do
        local variantWeight = 0
        for _, variant in ipairs(category.variants) do variantWeight = variantWeight + variant.weight end
        for _, variant in ipairs(category.variants) do
            local probability = (category.weight / 10000) * (variant.weight / variantWeight)
            local value = 0
            if variant.kind == "pet_skin" then
                value = skinValue
            elseif variant.kind == "immortal_body" then
                value = bodyValue
            elseif not pureLingYun
                or category.itemId == "lingyun_fruit"
                or category.itemId == "lingyun_fruit_superior"
                or category.itemId == "lingyun_fruit_supreme" then
                value = (Config.VALUE_BY_ITEM[category.itemId] or 0) * (variant.amount or 1)
            end
            expected = expected + probability * value
        end
    end
    return expected
end

test("reward category weights total 10000", function()
    local sum = 0
    for _, category in ipairs(Config.REWARD_CATEGORIES) do sum = sum + category.weight end
    assertEqual(sum, 10000)
end)

test("reward expected values match design", function()
    assertNear(RewardExpectedValue(5000, 5000, false), 896.5, 0.0001, "converted EV")
    assertNear(RewardExpectedValue(0, 0, true), 455, 0.0001, "pure LingYun EV")
    assertNear(RewardExpectedValue(5000, 5000, true), 480, 0.0001, "pure LingYun converted EV")
end)

test("reward conversion constants match design", function()
    assertEqual(Config.VALUE_BY_ITEM.exp_pill, 25)
    assertEqual(Config.VALUE_BY_ITEM.exp_pill_superior, 250)
    assertEqual(Config.VALUE_BY_ITEM.exp_pill_supreme, 2500)
    assertEqual(Config.VALUE_BY_ITEM.lingyun_fruit, 50)
    assertEqual(Config.VALUE_BY_ITEM.lingyun_fruit_superior, 500)
    assertEqual(Config.VALUE_BY_ITEM.lingyun_fruit_supreme, 5000)
    assertEqual(Config.VALUE_BY_ITEM.gold_brick, 100)
    assertEqual(Config.VALUE_BY_ITEM.gold_box_10m, 10000)
    assertEqual(Config.NEW_SKIN_VALUE, 5000)
    assertEqual(Config.NEW_BODY_VALUE, 5000)
    assertEqual(Config.DUPLICATE_SKIN_LINGYUN, 5000)
    assertEqual(Config.DUPLICATE_BODY_LINGYUN, 5000)
end)

test("account treasure split is skins 0.4 percent and body 0.1 percent", function()
    local category
    for _, entry in ipairs(Config.REWARD_CATEGORIES) do
        if entry.rewardType == "account_treasure" then category = entry end
    end
    assertTrue(category ~= nil, "account treasure category")
    assertEqual(category.weight, 50)
    local skinWeight, bodyWeight, totalWeight = 0, 0, 0
    for _, variant in ipairs(category.variants) do
        totalWeight = totalWeight + variant.weight
        if variant.kind == "pet_skin" then skinWeight = skinWeight + variant.weight end
        if variant.kind == "immortal_body" then
            bodyWeight = bodyWeight + variant.weight
            assertEqual(variant.bodyId, Config.WANBAO_BODY_ID)
        end
    end
    assertEqual(totalWeight, 15)
    assertEqual(skinWeight, 12)
    assertEqual(bodyWeight, 3)
    assertNear((category.weight / 10000) * (skinWeight / totalWeight), 0.004, 0.0000001)
    assertNear((category.weight / 10000) * (bodyWeight / totalWeight), 0.001, 0.0000001)
end)

test("nine reward types map one-to-one to islands and chests", function()
    assertEqual(#Config.ISLANDS, 9)
    local rewardTypes, islandIds, chestIds = {}, {}, {}
    for _, island in ipairs(Config.ISLANDS) do
        assertEqual(rewardTypes[island.rewardType], nil, "duplicate rewardType")
        assertEqual(islandIds[island.islandId], nil, "duplicate islandId")
        assertEqual(chestIds[island.chest.chestId], nil, "duplicate chestId")
        rewardTypes[island.rewardType] = true
        islandIds[island.islandId] = true
        chestIds[island.chest.chestId] = true
    end
end)

test("island bounds are in range and non-overlapping", function()
    for i, island in ipairs(Config.ISLANDS) do
        local b = island.bounds
        if b.x1 < 0 or b.y1 < 0 or b.x2 >= 80 or b.y2 >= 80 then
            error("island out of bounds: " .. island.islandId)
        end
        for j = i + 1, #Config.ISLANDS do
            local other = Config.ISLANDS[j].bounds
            local overlaps = not (b.x2 < other.x1 or other.x2 < b.x1
                or b.y2 < other.y1 or other.y2 < b.y1)
            if overlaps then error("islands overlap: " .. island.islandId) end
        end
    end
end)

test("boss whitelist has exactly one configured drop each", function()
    local modules = { Ch4, Ch5, Ch6 }
    local allTypes = {}
    for _, module in ipairs(modules) do
        for id, monster in pairs(module.Types) do allTypes[id] = monster end
    end
    for bossId, chance in pairs(Config.BOSS_DROP_RATES) do
        local drops = FindTreasureDrop(allTypes[bossId])
        assertEqual(#drops, 1, bossId .. " treasure drop count")
        assertNear(drops[1].chance, chance, 0.0000001, bossId .. " treasure drop chance")
    end
    for bossId, monster in pairs(allTypes) do
        if not Config.BOSS_DROP_RATES[bossId] then
            assertEqual(#FindTreasureDrop(monster), 0, bossId .. " must not inherit treasure map")
        end
    end
end)

test("items and black market prices match design", function()
    assertEqual(GameConfig.CONSUMABLES.treasure_map.name, "藏宝图")
    assertEqual(GameConfig.CONSUMABLES.lingyun_fruit_supreme.name, "极品灵韵果")
    assertEqual(GameConfig.CONSUMABLES.gold_box_10m.name, "金盒")
    local market = BlackMerchantConfig.ITEMS.treasure_map
    assertEqual(market.category, BlackMerchantConfig.CATEGORY_CONSUMABLE)
    assertEqual(market.buy_price, 6)
    assertEqual(market.sell_price, 12)
    assertEqual(market.max_stock, 10)
end)

test("dedicated item icons and metadata exist", function()
    for _, itemId in ipairs({
        "treasure_map",
        "lingyun_fruit",
        "lingyun_fruit_superior",
        "lingyun_fruit_supreme",
        "gold_box_10m",
    }) do
        local icon = GameConfig.CONSUMABLES[itemId].icon
        assertTrue(type(icon) == "string" and icon:match("%.png$"), itemId .. " icon path")
        local file = io.open("assets/" .. icon, "rb")
        assertTrue(file ~= nil, itemId .. " icon exists")
        if file then file:close() end
        local meta = io.open("assets/" .. icon .. ".meta", "r")
        assertTrue(meta ~= nil, itemId .. " icon meta exists")
        if meta then meta:close() end
    end
end)

test("wanbao immortal body card and metadata exist", function()
    local path = "assets/image/body_wanbao_liuli_20260713055235.png"
    local file = io.open(path, "rb")
    assertTrue(file ~= nil, "wanbao card exists")
    if file then file:close() end
    local meta = io.open(path .. ".meta", "r")
    assertTrue(meta ~= nil, "wanbao card meta exists")
    if meta then meta:close() end
end)

test("dedicated normal and premium maritime chest assets exist", function()
    for _, path in ipairs({
        Config.NORMAL_CHEST_IMAGE,
        Config.PREMIUM_CHEST_IMAGE,
    }) do
        local assetPath = "assets/" .. path
        local file = io.open(assetPath, "rb")
        assertTrue(file ~= nil, assetPath .. " exists")
        if file then file:close() end
        local meta = io.open(assetPath .. ".meta", "r")
        assertTrue(meta ~= nil, assetPath .. " meta exists")
        if meta then meta:close() end
    end
    assertTrue(Config.NORMAL_CHEST_IMAGE ~= Config.PREMIUM_CHEST_IMAGE)
end)

print(string.format("[test_treasure_map_config] passed=%d failed=%d total=%d",
    passed, failed, total))

return { passed = passed, failed = failed, total = total }
