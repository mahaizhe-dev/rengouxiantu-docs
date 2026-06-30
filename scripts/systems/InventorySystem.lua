---@diagnostic disable
-- ============================================================================
-- InventorySystem.lua - 背包与装备系统（Facade）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local TradeLock = require("systems.BlackMarketTradeLock")
local SortUtil = require("systems.InventorySortUtil")

-- Sub-modules
local equip_stats = require("systems.inventory.equip_stats")
local consumables = require("systems.inventory.consumables")
local batch_use   = require("systems.inventory.batch_use")

local InventorySystem = {}

-- BM-S2: 原 HOTFIX-BM-01A 白名单已废弃，改为 BlackMarketSyncState 统一门禁
-- 保留空表供向后兼容引用（外部若直接读此表不会报错）
InventorySystem._BM_SENSITIVE_CONSUMABLES = {}

---@type InventoryManager|nil
local manager_ = nil

--- 初始化背包系统
function InventorySystem.Init()
    -- 构建装备槽配置（10个槽位）
    local equipSlots = {}
    for _, slotId in ipairs(EquipmentData.SLOTS) do
        -- ring1/ring2 都接受 "ring" 类型的物品
        local slotType = slotId
        if slotId == "ring1" or slotId == "ring2" then
            slotType = "ring"
        end
        equipSlots[slotId] = { type = slotType, item = nil }
    end

    manager_ = UI.InventoryManager.new({
        inventorySize = GameConfig.BACKPACK_SIZE,
        equipmentSlots = equipSlots,
    })

    -- 装备变更时刷新属性加成
    manager_.onChange = function()
        InventorySystem.RecalcEquipStats()
    end

    print("[InventorySystem] Initialized with " .. GameConfig.BACKPACK_SIZE .. " slots")
end

--- 获取 InventoryManager 实例（供 UI 使用）
---@return InventoryManager
function InventorySystem.GetManager()
    return manager_
end

--- 🔴 仅供测试使用：安全注入一个隔离的 mock manager，不会影响 Init() 的副作用。
---@param mgr InventoryManager
function InventorySystem.SetManager(mgr)
    manager_ = mgr
end

--- 添加物品到背包
---@param item table
---@return boolean success
---@return number|nil slotIndex
function InventorySystem.AddItem(item)
    if not manager_ then return false, nil end

    -- ring 类型装备统一 type 标记
    if item.slot == "ring1" or item.slot == "ring2" then
        item.type = "ring"
    else
        item.type = item.slot or item.type
    end

    local success, idx = manager_:AddToInventory(item)
    if success then
        EventBus.Emit("inventory_item_added", item, idx)
    else
        print("[InventorySystem] Backpack full! Cannot add: " .. (item.name or "?"))
        EventBus.Emit("inventory_full", item)
    end
    return success, idx
end

--- 自动拾取 pendingItems 到背包
function InventorySystem.PickupPendingItems()
    local pending = GameState.pendingItems
    for i = #pending, 1, -1 do
        local ok = InventorySystem.AddItem(pending[i])
        if ok then
            table.remove(pending, i)
        else
            break  -- 背包满了
        end
    end
end

--- 出售物品（从背包中移除并获得金币）
---@param slotIndex number 背包槽位
---@return boolean
function InventorySystem.SellItem(slotIndex)
    if not manager_ then return false end
    local item = manager_:GetInventoryItem(slotIndex)
    if not item then return false end

    local unitPrice = item.sellPrice or 1
    -- 消耗品优先从配置表读取售价（存档中可能缺失或为 0）
    if item.consumableId then
        local cfgData = GameConfig.CONSUMABLES[item.consumableId]
        if cfgData then
            if cfgData.sellPrice and cfgData.sellPrice > 0 then
                unitPrice = cfgData.sellPrice
            elseif cfgData.sellPrice == 0 then
                -- sellPrice=0 表示不可出售（境界丹药等）
                return false
            end
        end
    end
    local count = item.count or 1
    local price = unitPrice * count
    local player = GameState.player
    if player then
        if item.sellCurrency == "lingYun" then
            player:GainLingYun(price)
        else
            player:GainGold(price)
        end
    end

    local currencyName = item.sellCurrency == "lingYun" and "灵韵" or "金币"
    manager_:SetInventoryItem(slotIndex, nil)
    EventBus.Emit("item_sold", item, price, item.sellCurrency)
    -- P0: 出售后标记脏，由 SaveSession 合并保存
    pcall(function() require("systems.save.SaveSession").MarkDirty() end)
    print("[InventorySystem] Sold " .. item.name .. " x" .. count .. " for " .. price .. " " .. currencyName)
    return true
end

--- 批量出售指定品质及以下的装备（背包中非消耗品）
---@param qualitySetOrMax table|string 品质集合或最高品质字符串
---@return number soldCount, number totalGold
function InventorySystem.SellByQuality(qualitySetOrMax)
    if not manager_ then return 0, 0 end

    -- 兼容旧调用方式：传字符串时转换为集合
    local qualitySet
    if type(qualitySetOrMax) == "string" then
        local maxOrder = GameConfig.QUALITY_ORDER[qualitySetOrMax] or 0
        qualitySet = {}
        for q, order in pairs(GameConfig.QUALITY_ORDER) do
            if order <= maxOrder then qualitySet[q] = true end
        end
    else
        qualitySet = qualitySetOrMax or {}
    end

    local soldCount = 0
    local totalGold = 0
    local totalLingYun = 0

    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category ~= "consumable" and item.quality then
            if qualitySet[item.quality] then
                local price = (item.sellPrice or 1) * (item.count or 1)
                if item.sellCurrency == "lingYun" then
                    totalLingYun = totalLingYun + price
                else
                    totalGold = totalGold + price
                end
                manager_:SetInventoryItem(i, nil)
                soldCount = soldCount + 1
            end
        end
    end

    if soldCount > 0 then
        local player = GameState.player
        if player then
            if totalGold > 0 then player:GainGold(totalGold) end
            if totalLingYun > 0 then player:GainLingYun(totalLingYun) end
        end
        EventBus.Emit("batch_sold", soldCount, totalGold, totalLingYun)
        -- P0: 批量出售结束后只 MarkDirty 一次（不逐件保存）
        pcall(function() require("systems.save.SaveSession").MarkDirty() end)
        local msg = "[InventorySystem] Batch sold " .. soldCount .. " items for " .. totalGold .. " gold"
        if totalLingYun > 0 then msg = msg .. " + " .. totalLingYun .. " lingYun" end
        print(msg)
    end

    return soldCount, totalGold, totalLingYun
end

--- 整理背包
function InventorySystem.SortBackpack()
    if not manager_ then return end
    if SortUtil._sorting then
        print("[InventorySystem] SortBackpack: 排序进行中，忽略重复调用")
        return
    end
    SortUtil._sorting = true

    -- 收集所有背包物品
    local items = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item then
            items[#items + 1] = item
        end
    end

    -- 使用共享工具排序（合并 + 排序 + 守恒校验）
    local sorted, ok, msg = SortUtil.SortItems(items)
    if not ok then
        print("[InventorySystem] SortBackpack 中止: " .. (msg or "unknown"))
        SortUtil._sorting = false
        return
    end

    -- 清空全部格子，按排序结果重新放入
    for i = 1, GameConfig.BACKPACK_SIZE do
        manager_:SetInventoryItem(i, nil)
    end
    for i, item in ipairs(sorted) do
        manager_:SetInventoryItem(i, item)
    end

    SortUtil._sorting = false
    print("[InventorySystem] Backpack sorted: " .. #sorted .. " items")
end

--- 获取背包空余格数
---@return number
function InventorySystem.GetFreeSlots()
    if not manager_ then return 0 end
    local count = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not manager_:GetInventoryItem(i) then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- Delegation: equip_stats sub-module
-- ============================================================================

function InventorySystem.RecalcEquipStats()
    return equip_stats.RecalcEquipStats(InventorySystem)
end

function InventorySystem.GetEquipStatSummary()
    return equip_stats.GetEquipStatSummary()
end

function InventorySystem.GetActiveSetBonuses()
    return equip_stats.GetActiveSetBonuses(InventorySystem)
end

-- ============================================================================
-- Delegation: consumables sub-module
-- ============================================================================

function InventorySystem.AddConsumable(consumableId, amount)
    return consumables.AddConsumable(InventorySystem, consumableId, amount)
end

function InventorySystem.AddConsumableLockedNewStack(consumableId, amount, batchId, duration)
    return consumables.AddConsumableLockedNewStack(InventorySystem, consumableId, amount, batchId, duration)
end

function InventorySystem.CountConsumable(consumableId)
    return consumables.CountConsumable(InventorySystem, consumableId)
end

function InventorySystem.CountUnlockedConsumable(consumableId)
    return consumables.CountUnlockedConsumable(InventorySystem, consumableId)
end

function InventorySystem.HasAnyLockedConsumable(consumableId)
    return consumables.HasAnyLockedConsumable(InventorySystem, consumableId)
end

function InventorySystem.ConsumeConsumable(consumableId, amount)
    return consumables.ConsumeConsumable(InventorySystem, consumableId, amount)
end

-- P0.2 BM-NORESELL: 黑市卖出成功后的镜像扣除（只扣可回售来源，绝不扣黑市买入物）
function InventorySystem.ConsumeResellableConsumable(consumableId, amount)
    return consumables.ConsumeResellableConsumable(InventorySystem, consumableId, amount)
end

function InventorySystem.GetPetFoodList()
    return consumables.GetPetFoodList(InventorySystem)
end

function InventorySystem.GetSkillBookList()
    return consumables.GetSkillBookList(InventorySystem)
end

function InventorySystem.UpgradeGourd()
    return consumables.UpgradeGourd(InventorySystem)
end

function InventorySystem.GetGourdTier()
    return consumables.GetGourdTier(InventorySystem)
end

function InventorySystem.GetExclusiveTier()
    return consumables.GetExclusiveTier(InventorySystem)
end

function InventorySystem.GetExclusiveSkillTier()
    return consumables.GetExclusiveSkillTier(InventorySystem)
end

function InventorySystem.UseExpPillSuperior()
    return consumables.UseExpPillSuperior(InventorySystem)
end

function InventorySystem.UseLingyunFruitSuperior()
    return consumables.UseLingyunFruitSuperior(InventorySystem)
end

function InventorySystem.UseLingyunFruit()
    return consumables.UseLingyunFruit(InventorySystem)
end

function InventorySystem.UseExpPill()
    return consumables.UseExpPill(InventorySystem)
end

function InventorySystem.UseGuardianToken(slotIndex)
    return consumables.UseGuardianToken(InventorySystem, slotIndex)
end

-- ============================================================================
-- Delegation: batch_use sub-module
-- ============================================================================

function InventorySystem.UseBatchConsumable(consumableId, count)
    return batch_use.UseBatchConsumable(InventorySystem, consumableId, count)
end

-- Internal batch helpers (exposed for backward compat / testing)
function InventorySystem._UseBatchExpPill(count)
    return batch_use._UseBatchExpPill(InventorySystem, count)
end

function InventorySystem._UseBatchLingyunFruit(count)
    return batch_use._UseBatchLingyunFruit(InventorySystem, count)
end

function InventorySystem._UseBatchExpPillSuperior(count)
    return batch_use._UseBatchExpPillSuperior(InventorySystem, count)
end

function InventorySystem._UseBatchLingyunFruitSuperior(count)
    return batch_use._UseBatchLingyunFruitSuperior(InventorySystem, count)
end

function InventorySystem._SellBatchConsumable(consumableId, count)
    return batch_use._SellBatchConsumable(InventorySystem, consumableId, count)
end

function InventorySystem._UseTokenBox(boxId, tokenId)
    return batch_use._UseTokenBox(InventorySystem, boxId, tokenId)
end

return InventorySystem
