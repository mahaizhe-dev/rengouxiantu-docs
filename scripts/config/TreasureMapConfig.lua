-- ============================================================================
-- TreasureMapConfig.lua - long-term treasure map gameplay contract
-- ============================================================================

local M = {}

M.VERSION = 1
M.STATE_KEY_PREFIX = "treasure_map_state_"
M.MAP_ITEM_ID = "treasure_map"
M.OPEN_DURATION_MS = 3000
M.COMPLETED_RUN_LIMIT = 32
M.TELEPORT_FX_DURATION = 0.9
M.DUPLICATE_SKIN_LINGYUN = 5000
M.DUPLICATE_BODY_LINGYUN = 5000
M.NEW_SKIN_VALUE = 5000
M.NEW_BODY_VALUE = 5000
M.WANBAO_BODY_ID = "immortal_body_wanbao_liuli"
M.NORMAL_CHEST_IMAGE = "image/treasure_sea_chest_20260713085518.png"
M.PREMIUM_CHEST_IMAGE = "image/treasure_account_chest_20260713085518.png"

M.ENTRY = {
    id = "ch4_treasure_map_entry",
    chapter = 4,
    zone = "ch4_haven",
}

M.RETURN_POINT = {
    id = "treasure_map_return_ch4",
    chapter = 4,
    x = 39.5,
    y = 41.5,
}

M.SKIN_IDS = {
    "pet_premium_chiyan",
    "pet_premium_xuanbing",
    "pet_premium_biling",
}

M.BOSS_DROP_RATES = {
    dragon_ice = 0.005,
    dragon_abyss = 0.005,
    dragon_fire = 0.005,
    dragon_sand = 0.005,
    ch5_sword_zhu = 0.0075,
    ch5_sword_xian = 0.0075,
    ch5_sword_lu = 0.0075,
    ch5_sword_jue = 0.0075,
    ch6_gua_master = 0.01,
    ch6_mojun_shixuan = 0.01,
}

M.REWARD_CATEGORIES = {
    { rewardType = "exp_pill", weight = 1300, kind = "consumable", itemId = "exp_pill",
      variants = { { amount = 6, weight = 1 } } },
    { rewardType = "gold_brick", weight = 1300, kind = "consumable", itemId = "gold_brick",
      variants = {
          { amount = 3, weight = 6 },
          { amount = 6, weight = 4 },
          { amount = 9, weight = 2 },
          { amount = 12, weight = 1 },
      } },
    { rewardType = "lingyun_fruit", weight = 1000, kind = "consumable", itemId = "lingyun_fruit",
      variants = { { amount = 4, weight = 1 } } },
    { rewardType = "lingyun_fruit_superior", weight = 4400, kind = "consumable",
      itemId = "lingyun_fruit_superior",
      variants = {
          { amount = 1, weight = 20 },
          { amount = 2, weight = 15 },
          { amount = 3, weight = 9 },
      } },
    { rewardType = "exp_pill_superior", weight = 1200, kind = "consumable",
      itemId = "exp_pill_superior",
      variants = {
          { amount = 1, weight = 3 },
          { amount = 2, weight = 2 },
          { amount = 3, weight = 1 },
      } },
    { rewardType = "exp_pill_supreme", weight = 500, kind = "consumable",
      itemId = "exp_pill_supreme", variants = { { amount = 1, weight = 1 } } },
    { rewardType = "lingyun_fruit_supreme", weight = 100, kind = "consumable",
      itemId = "lingyun_fruit_supreme", variants = { { amount = 1, weight = 1 } } },
    { rewardType = "gold_box_10m", weight = 150, kind = "consumable",
      itemId = "gold_box_10m", variants = { { amount = 1, weight = 1 } } },
    { rewardType = "account_treasure", weight = 50, kind = "account_treasure",
      variants = {
          { kind = "pet_skin", skinId = "pet_premium_chiyan", weight = 4 },
          { kind = "pet_skin", skinId = "pet_premium_xuanbing", weight = 4 },
          { kind = "pet_skin", skinId = "pet_premium_biling", weight = 4 },
          { kind = "immortal_body", bodyId = M.WANBAO_BODY_ID, weight = 3 },
      } },
}

M.VALUE_BY_ITEM = {
    exp_pill = 25,
    exp_pill_superior = 250,
    exp_pill_supreme = 2500,
    lingyun_fruit = 50,
    lingyun_fruit_superior = 500,
    lingyun_fruit_supreme = 5000,
    gold_brick = 100,
    gold_box_10m = 10000,
}
M.REWARD_VISUALS = {
    exp_pill = { name = "修炼宝藏", icon = "💊", color = {100, 190, 255, 255} },
    gold_brick = { name = "金砖宝藏", icon = "🧱", color = {255, 205, 80, 255} },
    lingyun_fruit = { name = "灵韵宝藏", icon = "🍇", color = {210, 135, 255, 255} },
    lingyun_fruit_superior = { name = "上品灵韵宝藏", icon = "🍇", color = {255, 115, 190, 255} },
    exp_pill_superior = { name = "上品修炼宝藏", icon = "💊", color = {255, 160, 75, 255} },
    exp_pill_supreme = { name = "极品修炼宝藏", icon = "💊", color = {255, 90, 70, 255} },
    lingyun_fruit_supreme = { name = "极品灵韵宝藏", icon = "🍇", color = {255, 225, 90, 255} },
    gold_box_10m = { name = "金盒宝藏", icon = "📦", color = {255, 220, 100, 255} },
    account_treasure = { name = "仙缘秘藏", icon = "✨", color = {255, 235, 150, 255} },
}

-- 岛屿碰撞约束：
--   普通岛使用 4~7 个可行走格和不同轮廓，大奖岛 10 格；外围至少保留一圈不可行走海水。
--   玩家只能由藏宝图直接传送到 spawn，正常移动无法跨海登岛。
--   每座岛的 chest / exit 位于轮廓对角端点，spawn 位于岛屿内部。
M.ISLANDS = {
    {
        islandId = "treasure_island_training", rewardType = "exp_pill",
        bounds = { x1 = 32, y1 = 25, x2 = 34, y2 = 27 },
        tiles = { {32,25}, {33,25}, {32,26}, {33,26}, {34,26}, {33,27}, {34,27} },
        spawn = { x = 33, y = 26 },
        chest = { chestId = "treasure_chest_training", x = 32, y = 25 },
        exit = { x = 34, y = 27 },
    },
    {
        islandId = "treasure_island_gold", rewardType = "gold_brick",
        bounds = { x1 = 53, y1 = 36, x2 = 55, y2 = 37 },
        tiles = { {53,36}, {54,36}, {54,37}, {55,37} },
        spawn = { x = 54, y = 37 },
        chest = { chestId = "treasure_chest_gold", x = 53, y = 36 },
        exit = { x = 55, y = 37 },
    },
    {
        islandId = "treasure_island_lingyun", rewardType = "lingyun_fruit",
        bounds = { x1 = 29, y1 = 49, x2 = 31, y2 = 51 },
        tiles = { {29,49}, {30,49}, {31,49}, {30,50}, {31,50}, {31,51} },
        spawn = { x = 30, y = 50 },
        chest = { chestId = "treasure_chest_lingyun", x = 29, y = 49 },
        exit = { x = 31, y = 51 },
    },
    {
        islandId = "treasure_island_superior_lingyun", rewardType = "lingyun_fruit_superior",
        bounds = { x1 = 74, y1 = 28, x2 = 76, y2 = 30 },
        tiles = { {74,28}, {75,28}, {75,29}, {76,29}, {76,30} },
        spawn = { x = 75, y = 29 },
        chest = { chestId = "treasure_chest_superior_lingyun", x = 74, y = 28 },
        exit = { x = 76, y = 30 },
    },
    {
        islandId = "treasure_island_superior_training", rewardType = "exp_pill_superior",
        bounds = { x1 = 23, y1 = 8, x2 = 26, y2 = 10 },
        tiles = { {23,8}, {24,8}, {24,9}, {25,9}, {25,10}, {26,10} },
        spawn = { x = 25, y = 9 },
        chest = { chestId = "treasure_chest_superior_training", x = 23, y = 8 },
        exit = { x = 26, y = 10 },
    },
    {
        islandId = "treasure_island_supreme_training", rewardType = "exp_pill_supreme",
        bounds = { x1 = 54, y1 = 4, x2 = 56, y2 = 6 },
        tiles = { {54,4}, {54,5}, {55,5}, {56,5}, {56,6} },
        spawn = { x = 55, y = 5 },
        chest = { chestId = "treasure_chest_supreme_training", x = 54, y = 4 },
        exit = { x = 56, y = 6 },
    },
    {
        islandId = "treasure_island_supreme_lingyun", rewardType = "lingyun_fruit_supreme",
        bounds = { x1 = 3, y1 = 24, x2 = 6, y2 = 26 },
        tiles = { {3,24}, {3,25}, {4,25}, {4,26}, {5,25}, {5,26}, {6,26} },
        spawn = { x = 4, y = 25 },
        chest = { chestId = "treasure_chest_supreme_lingyun", x = 3, y = 24 },
        exit = { x = 6, y = 26 },
    },
    {
        islandId = "treasure_island_gold_box", rewardType = "gold_box_10m",
        bounds = { x1 = 72, y1 = 52, x2 = 75, y2 = 54 },
        tiles = { {72,52}, {73,52}, {74,52}, {74,53}, {75,53}, {74,54}, {75,54} },
        spawn = { x = 74, y = 53 },
        chest = { chestId = "treasure_chest_gold_box", x = 72, y = 52 },
        exit = { x = 75, y = 54 },
    },
    {
        islandId = "treasure_island_account_treasure", rewardType = "account_treasure",
        isPremium = true,
        bounds = { x1 = 50, y1 = 73, x2 = 53, y2 = 76 },
        tiles = {
            {50,73}, {51,73},
            {50,74}, {51,74}, {52,74},
            {51,75}, {52,75}, {53,75},
            {52,76}, {53,76},
        },
        spawn = { x = 51, y = 75 },
        chest = { chestId = "treasure_chest_account_treasure", x = 50, y = 73 },
        exit = { x = 53, y = 76 },
    },
}

M.ISLAND_BY_REWARD_TYPE = {}
M.ISLAND_BY_ID = {}
for _, island in ipairs(M.ISLANDS) do
    M.ISLAND_BY_REWARD_TYPE[island.rewardType] = island
    M.ISLAND_BY_ID[island.islandId] = island
end

local function RollWeighted(entries, randomInt)
    local total = 0
    for _, entry in ipairs(entries) do total = total + entry.weight end
    local roll = randomInt and randomInt(total) or math.random(total)
    local cursor = 0
    for _, entry in ipairs(entries) do
        cursor = cursor + entry.weight
        if roll <= cursor then return entry end
    end
    return entries[#entries]
end

---@param randomInt? fun(max: integer): integer
---@return table reward
---@return table island
function M.RollReward(randomInt)
    local category = RollWeighted(M.REWARD_CATEGORIES, randomInt)
    local variant = RollWeighted(category.variants, randomInt)
    local reward = {
        kind = variant.kind or category.kind,
        rewardType = category.rewardType,
        itemId = category.itemId,
        amount = variant.amount,
        skinId = variant.skinId,
        bodyId = variant.bodyId,
    }
    return reward, M.ISLAND_BY_REWARD_TYPE[category.rewardType]
end

return M
