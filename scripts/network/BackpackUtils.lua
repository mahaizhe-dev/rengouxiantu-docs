-- ============================================================================
-- BackpackUtils.lua — 服务端背包操作共享模块
--
-- 职责：提供背包读写辅助函数（堆叠/添加/扣除/统计）
-- 使用方：BlackMerchantHandler、EventHandler 等需要操作存档背包的模块
-- ============================================================================

local BackpackUtils = {}

BackpackUtils.MAX_BACKPACK_SLOTS = 60  -- 与 GameConfig.BACKPACK_SIZE 一致（bag1: 1-30, bag2: 31-60）
BackpackUtils.MAX_STACK = 9999

-- ============================================================================
-- 背包操作辅助函数（服务端存档 backpack 格式）
-- backpack 格式: { "1" = {category, consumableId, count, name}, ... }
-- ============================================================================

--- 从存档 backpack 中统计指定消耗品的总数量
---@param backpack table|nil
---@param consumableId string
---@return integer
function BackpackUtils.CountBackpackItem(backpack, consumableId)
    if not backpack then return 0 end
    local total = 0
    for _, item in pairs(backpack) do
        if type(item) == "table"
            and item.category == "consumable"
            and item.consumableId == consumableId then
            total = total + (item.count or 1)
        end
    end
    return total
end

--- 向存档 backpack 中添加消耗品（堆叠 + 新槽位）
---@param backpack table
---@param consumableId string
---@param amount integer
---@param itemName string|nil
---@return integer remaining 未能放入的剩余数量（0 = 全部放入）
function BackpackUtils.AddToBackpack(backpack, consumableId, amount, itemName)
    local remaining = amount
    -- 先堆叠到已有槽位
    for i = 1, BackpackUtils.MAX_BACKPACK_SLOTS do
        if remaining <= 0 then break end
        local key = tostring(i)
        local item = backpack[key]
        if item and item.category == "consumable" and item.consumableId == consumableId then
            local cur = item.count or 1
            if cur < BackpackUtils.MAX_STACK then
                local space = BackpackUtils.MAX_STACK - cur
                if remaining <= space then
                    item.count = cur + remaining
                    remaining = 0
                else
                    item.count = BackpackUtils.MAX_STACK
                    remaining = remaining - space
                end
            end
        end
    end
    -- 剩余放到空槽位
    while remaining > 0 do
        local placed = false
        for i = 1, BackpackUtils.MAX_BACKPACK_SLOTS do
            local key = tostring(i)
            if not backpack[key] then
                local addCount = remaining > BackpackUtils.MAX_STACK and BackpackUtils.MAX_STACK or remaining
                backpack[key] = {
                    category = "consumable",
                    consumableId = consumableId,
                    count = addCount,
                    name = itemName,
                }
                remaining = remaining - addCount
                placed = true
                break
            end
        end
        if not placed then break end
    end
    return remaining
end

--- 从存档 backpack 中扣除消耗品
---@param backpack table
---@param consumableId string
---@param amount integer
---@return integer remaining 未能扣除的剩余数量（0 = 全部扣除）
function BackpackUtils.RemoveFromBackpack(backpack, consumableId, amount)
    local remaining = amount
    for i = 1, BackpackUtils.MAX_BACKPACK_SLOTS do
        if remaining <= 0 then break end
        local key = tostring(i)
        local item = backpack[key]
        if item and item.category == "consumable" and item.consumableId == consumableId then
            local cur = item.count or 1
            if cur <= remaining then
                backpack[key] = nil
                remaining = remaining - cur
            else
                item.count = cur - remaining
                remaining = 0
            end
        end
    end
    return remaining
end

-- ============================================================================
-- 装备操作辅助函数（服务端存档 backpack 格式）
-- 装备格式: { id=N, name="...", equipId="...", slot="ring1", quality="orange", ... }
-- 装备没有 category 字段（消耗品有 category="consumable"）
-- ============================================================================

--- 从存档 backpack 中统计指定装备的数量（按 equipId 匹配）
---@param backpack table|nil
---@param equipId string  装备模板 ID（如 "dizun_ring_ch1"）
---@return integer
function BackpackUtils.CountEquipmentItem(backpack, equipId)
    if not backpack then return 0 end
    local total = 0
    for _, item in pairs(backpack) do
        if type(item) == "table"
            and item.category ~= "consumable"
            and item.equipId == equipId then
            total = total + 1  -- 装备不堆叠，每件占一个槽位
        end
    end
    return total
end

--- 向存档 backpack 中添加一件装备（已构建好的装备对象）
--- 装备不堆叠，直接放入空槽位
---@param backpack table
---@param equipItem table  完整装备对象（由 LootSystem.CreateSpecialEquipment 生成）
---@return boolean success  是否成功放入（false = 背包已满）
function BackpackUtils.AddEquipmentToBackpack(backpack, equipItem)
    for i = 1, BackpackUtils.MAX_BACKPACK_SLOTS do
        local key = tostring(i)
        if not backpack[key] then
            backpack[key] = equipItem
            return true
        end
    end
    return false  -- 背包已满
end

--- 从存档 backpack 中移除指定装备（按 equipId 匹配，不论附魔/洗练状态）
--- 一次移除 amount 件，优先移除靠前槽位的
---@param backpack table
---@param equipId string  装备模板 ID
---@param amount integer  要移除的数量
---@return integer remaining  未能移除的剩余数量（0 = 全部移除）
function BackpackUtils.RemoveEquipmentFromBackpack(backpack, equipId, amount)
    local remaining = amount
    for i = 1, BackpackUtils.MAX_BACKPACK_SLOTS do
        if remaining <= 0 then break end
        local key = tostring(i)
        local item = backpack[key]
        if item and type(item) == "table"
            and item.category ~= "consumable"
            and item.equipId == equipId then
            backpack[key] = nil
            remaining = remaining - 1
        end
    end
    return remaining
end

return BackpackUtils
