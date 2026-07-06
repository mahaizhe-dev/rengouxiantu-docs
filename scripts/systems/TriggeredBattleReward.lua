-- ============================================================================
-- TriggeredBattleReward.lua - 触发战斗奖励背包写入工具
-- 服务端和本地测试共用，保持发奖容量判断与写入路径一致。
-- ============================================================================

local GameConfig = require("config.GameConfig")

local M = {}

local function getSkillBookData(consumableId)
    local ok, PetSkillData = pcall(require, "config.PetSkillData")
    if ok and PetSkillData and PetSkillData.SKILL_BOOKS then
        return PetSkillData.SKILL_BOOKS[consumableId]
    end
    return nil
end

function M.GetConsumableData(consumableId)
    local foodData = GameConfig.PET_FOOD and GameConfig.PET_FOOD[consumableId]
    local matData = GameConfig.PET_MATERIALS and GameConfig.PET_MATERIALS[consumableId]
    local bookData = getSkillBookData(consumableId)
    local eventData = GameConfig.EVENT_ITEMS and GameConfig.EVENT_ITEMS[consumableId]
    local consumableData = GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[consumableId]
    return foodData or matData or bookData or eventData or consumableData, foodData, bookData
end

local function readBackpackSlot(backpack, slot)
    return backpack[tostring(slot)] or backpack[slot]
end

local function writeBackpackSlot(backpack, slot, item)
    backpack[tostring(slot)] = item
    backpack[slot] = nil
end

function M.GetWritableCapacity(backpack, consumableId)
    backpack = backpack or {}
    local maxStack = GameConfig.MAX_STACK_COUNT or 9999
    local capacity = 0
    for slot = 1, GameConfig.BACKPACK_SIZE do
        local item = readBackpackSlot(backpack, slot)
        if not item then
            capacity = capacity + maxStack
        elseif item.category == "consumable"
            and item.consumableId == consumableId
            and not item.bmNoResell then
            capacity = capacity + math.max(0, maxStack - (item.count or 1))
        end
    end
    return capacity
end

function M.CanAddConsumable(backpack, consumableId, amount)
    amount = amount or 1
    local data = M.GetConsumableData(consumableId)
    if not data then return false, "invalid_item" end
    if M.GetWritableCapacity(backpack, consumableId) < amount then
        return false, "backpack_full"
    end
    return true
end

function M.CreateConsumableItem(consumableId, count, idPrefix)
    local data, foodData, bookData = M.GetConsumableData(consumableId)
    if not data then return nil end
    local id = tostring(idPrefix or "triggered_reward")
        .. "_"
        .. tostring(os.time and os.time() or 0)
        .. "_"
        .. tostring(math.random(100000, 999999))

    return {
        id = id,
        name = data.name,
        icon = data.icon,
        image = data.image or nil,
        category = "consumable",
        consumableId = consumableId,
        count = count or 1,
        sellPrice = data.sellPrice or 1,
        quality = data.quality or "white",
        desc = data.desc,
        petExp = foodData and foodData.exp or nil,
        isSkillBook = bookData and true or nil,
        skillId = bookData and bookData.skillId or nil,
        bookTier = bookData and bookData.tier or nil,
    }
end

function M.AddConsumableToBackpack(backpack, consumableId, amount, idPrefix)
    backpack = backpack or {}
    amount = amount or 1
    local originalAmount = amount
    local maxStack = GameConfig.MAX_STACK_COUNT or 9999
    local changes = {}

    local canAdd, reason = M.CanAddConsumable(backpack, consumableId, amount)
    if not canAdd then return false, 0, changes, reason end

    for slot = 1, GameConfig.BACKPACK_SIZE do
        if amount <= 0 then break end
        local item = readBackpackSlot(backpack, slot)
        if item and item.category == "consumable"
            and item.consumableId == consumableId
            and not item.bmNoResell then
            local cur = item.count or 1
            if cur < maxStack then
                local add = math.min(amount, maxStack - cur)
                item.count = cur + add
                amount = amount - add
                changes[#changes + 1] = { slot = slot, item = item }
            end
        end
    end

    for slot = 1, GameConfig.BACKPACK_SIZE do
        if amount <= 0 then break end
        local item = readBackpackSlot(backpack, slot)
        if not item then
            local stackAmount = math.min(amount, maxStack)
            local newItem = M.CreateConsumableItem(consumableId, stackAmount, idPrefix)
            if not newItem then
                return false, originalAmount - amount, changes, "invalid_item"
            end
            writeBackpackSlot(backpack, slot, newItem)
            amount = amount - stackAmount
            changes[#changes + 1] = { slot = slot, item = newItem }
        end
    end

    return amount <= 0, originalAmount - amount, changes, amount <= 0 and nil or "backpack_full"
end

return M
