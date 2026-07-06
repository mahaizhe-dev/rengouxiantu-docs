-- ============================================================================
-- WubaoTreasureConfig.lua - 乌家宝藏配置
-- 16 个一次性宝箱按角色随机映射固定奖励池。
-- ============================================================================

local M = {}

M.KEY_ID = "wubao_treasure_key"
M.STATE_FIELD = "wubaoTreasureState"
M.CHEST_TEXTURE = "image/wubao_treasure_chest_20260704023406.png"
M.TREASURE_NAME = "乌家宝藏"
M.KEY_NAME = "堡主钥匙"

M.INTERACT_RANGE = 1.5
M.CHANNEL_DURATION = 3.0

M.CHEST_ORDER = {
    "wubao_treasure_chest_01",
    "wubao_treasure_chest_02",
    "wubao_treasure_chest_03",
    "wubao_treasure_chest_04",
    "wubao_treasure_chest_05",
    "wubao_treasure_chest_06",
    "wubao_treasure_chest_07",
    "wubao_treasure_chest_08",
    "wubao_treasure_chest_09",
    "wubao_treasure_chest_10",
    "wubao_treasure_chest_11",
    "wubao_treasure_chest_12",
    "wubao_treasure_chest_13",
    "wubao_treasure_chest_14",
    "wubao_treasure_chest_15",
    "wubao_treasure_chest_16",
}

M.CHESTS = {
    wubao_treasure_chest_01 = { chapter = 2, zone = "fortress_e3", group = "nw", x = 39, y = 35 },
    wubao_treasure_chest_02 = { chapter = 2, zone = "fortress_e3", group = "nw", x = 40, y = 35 },
    wubao_treasure_chest_03 = { chapter = 2, zone = "fortress_e3", group = "nw", x = 39, y = 36 },
    wubao_treasure_chest_04 = { chapter = 2, zone = "fortress_e3", group = "nw", x = 40, y = 36 },
    wubao_treasure_chest_05 = { chapter = 2, zone = "fortress_e3", group = "ne", x = 52, y = 35 },
    wubao_treasure_chest_06 = { chapter = 2, zone = "fortress_e3", group = "ne", x = 53, y = 35 },
    wubao_treasure_chest_07 = { chapter = 2, zone = "fortress_e3", group = "ne", x = 52, y = 36 },
    wubao_treasure_chest_08 = { chapter = 2, zone = "fortress_e3", group = "ne", x = 53, y = 36 },
    wubao_treasure_chest_09 = { chapter = 2, zone = "fortress_e3", group = "sw", x = 39, y = 46 },
    wubao_treasure_chest_10 = { chapter = 2, zone = "fortress_e3", group = "sw", x = 40, y = 46 },
    wubao_treasure_chest_11 = { chapter = 2, zone = "fortress_e3", group = "sw", x = 39, y = 47 },
    wubao_treasure_chest_12 = { chapter = 2, zone = "fortress_e3", group = "sw", x = 40, y = 47 },
    wubao_treasure_chest_13 = { chapter = 2, zone = "fortress_e3", group = "se", x = 52, y = 46 },
    wubao_treasure_chest_14 = { chapter = 2, zone = "fortress_e3", group = "se", x = 53, y = 46 },
    wubao_treasure_chest_15 = { chapter = 2, zone = "fortress_e3", group = "se", x = 52, y = 47 },
    wubao_treasure_chest_16 = { chapter = 2, zone = "fortress_e3", group = "se", x = 53, y = 47 },
}

for chestId, cfg in pairs(M.CHESTS) do
    cfg.id = chestId
end

M.REWARD_IDS = {
    "reward_01", "reward_02", "reward_03", "reward_04",
    "reward_05", "reward_06", "reward_07", "reward_08",
    "reward_09", "reward_10", "reward_11", "reward_12",
    "reward_13", "reward_14", "reward_15", "reward_16",
}

M.REWARDS = {
    reward_01 = { type = "consumable", consumableId = "wubao_token_box", count = 1 },
    reward_02 = { type = "consumable", consumableId = "wubao_token_box", count = 1 },
    reward_03 = { type = "consumable", consumableId = "wubao_token_box", count = 1 },
    reward_04 = { type = "consumable", consumableId = "wubao_token_box", count = 2 },
    reward_05 = { type = "consumable", consumableId = "lingyun_fruit", count = 2 },
    reward_06 = { type = "consumable", consumableId = "lingyun_fruit", count = 2 },
    reward_07 = { type = "consumable", consumableId = "lingyun_fruit", count = 3 },
    reward_08 = { type = "consumable", consumableId = "lingyun_fruit", count = 3 },
    reward_09 = { type = "consumable", consumableId = "zhuji_pill", count = 1 },
    reward_10 = { type = "consumable", consumableId = "zhuji_pill", count = 1 },
    reward_11 = { type = "consumable", consumableId = "gold_bar", count = 10 },
    reward_12 = { type = "consumable", consumableId = "gold_bar", count = 20 },
    reward_13 = { type = "consumable", consumableId = "exp_pill", count = 3 },
    reward_14 = { type = "consumable", consumableId = "demon_essence", count = 5 },
    reward_15 = { type = "equipment", equipId = "jianxin_belt_ch2", count = 1 },
    reward_16 = { type = "equipment", equipId = "dizun_ring_ch2", count = 1 },
}

---@param chapter number
---@return string[]
function M.GetChestIdsByChapter(chapter)
    local ids = {}
    for _, chestId in ipairs(M.CHEST_ORDER) do
        local cfg = M.CHESTS[chestId]
        if cfg and cfg.chapter == chapter then
            ids[#ids + 1] = chestId
        end
    end
    return ids
end

---@param chestId string
---@return table|nil
function M.GetChest(chestId)
    return M.CHESTS[chestId]
end

---@param rewardId string
---@return table|nil
function M.GetReward(rewardId)
    return M.REWARDS[rewardId]
end

---@return table<string, true>
function M.GetRewardIdSet()
    local set = {}
    for _, rewardId in ipairs(M.REWARD_IDS) do
        set[rewardId] = true
    end
    return set
end

return M
