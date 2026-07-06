---@diagnostic disable
-- ============================================================================
-- WarehouseSystem.lua - 仓库数据层
-- 管理仓库物品存取、排解锁逻辑
-- ============================================================================

local WarehouseConfig = require("config.WarehouseConfig")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")

local BlackMarketSyncState = require("systems.BlackMarketSyncState")
local TradeLock = require("systems.BlackMarketTradeLock")
local SortUtil = require("systems.InventorySortUtil")

local WarehouseSystem = {}

-- ── HOTFIX-BM-01: 仓库脏标记（未同步状态显式语义） ──
-- true = 仓库自上次成功存档后发生过变更，服务端 saveData 尚未反映本地仓库/背包真实状态
-- 黑市卖出前读此标记来决定是否拦截
WarehouseSystem._dirty = false

local function GetConsumableConfig(consumableId)
    if not consumableId then return nil, nil, nil end

    local skillBook = nil
    local ok, PetSkillData = pcall(require, "config.PetSkillData")
    if ok and PetSkillData and PetSkillData.SKILL_BOOKS then
        skillBook = PetSkillData.SKILL_BOOKS[consumableId]
    end

    local foodData = GameConfig.PET_FOOD and GameConfig.PET_FOOD[consumableId]
    local cfgData = skillBook
        or foodData
        or (GameConfig.PET_MATERIALS and GameConfig.PET_MATERIALS[consumableId])
        or (GameConfig.EVENT_ITEMS and GameConfig.EVENT_ITEMS[consumableId])
        or (GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[consumableId])

    return cfgData, foodData, skillBook
end

local function NormalizeWarehouseItemDisplayFields(itemData)
    if not itemData or not itemData.consumableId then return end

    local cfgData, foodData, skillBook = GetConsumableConfig(itemData.consumableId)
    if not cfgData then return end

    itemData.category = itemData.category or "consumable"
    itemData.icon = cfgData.icon or itemData.icon
    itemData.image = itemData.image or cfgData.image
    itemData.name = cfgData.name or itemData.name
    itemData.quality = itemData.quality or cfgData.quality
    itemData.sellPrice = itemData.sellPrice
        or cfgData.sellPrice
        or 1
    itemData.desc = itemData.desc or cfgData.desc

    if foodData and not itemData.petExp then
        itemData.petExp = foodData.exp
    end
    if skillBook then
        itemData.isSkillBook = true
        itemData.skillId = itemData.skillId or skillBook.skillId
        itemData.bookTier = itemData.bookTier or skillBook.tier
    end
end

-- ── 运行时数据（GameState 上挂载） ──
-- GameState.warehouse = {
--     unlockedRows = 1,             -- 已解锁排数
--     items = { [slotIndex] = item } -- 1~48，同背包格式
-- }

--- 初始化仓库数据（新角色或加载存档后调用）
function WarehouseSystem.Init()
    if not GameState.warehouse then
        GameState.warehouse = {
            unlockedRows = WarehouseConfig.INITIAL_UNLOCKED_ROWS,
            items = {},
            page2UnlockedRows = 0,
            page2Items = {},
        }
    end
    -- 兼容旧存档：补充第二页字段
    if GameState.warehouse.page2UnlockedRows == nil then
        GameState.warehouse.page2UnlockedRows = 0
    end
    if GameState.warehouse.page2Items == nil then
        GameState.warehouse.page2Items = {}
    end
end

--- HOTFIX-BM-01: 查询仓库是否处于未同步状态
---@return boolean
function WarehouseSystem.IsDirty()
    return WarehouseSystem._dirty == true
end

--- HOTFIX-BM-01: 手动标记脏（供测试或外部调用）
function WarehouseSystem.MarkDirty()
    WarehouseSystem._dirty = true
end

--- HOTFIX-BM-01: 清除脏标记（存档成功或加载时调用）
function WarehouseSystem.ClearDirty()
    WarehouseSystem._dirty = false
end

--- 获取已解锁排数
---@return number
function WarehouseSystem.GetUnlockedRows()
    WarehouseSystem.Init()
    return GameState.warehouse.unlockedRows or WarehouseConfig.INITIAL_UNLOCKED_ROWS
end

--- 获取已解锁格子总数
---@return number
function WarehouseSystem.GetUnlockedSlots()
    return WarehouseSystem.GetUnlockedRows() * WarehouseConfig.ITEMS_PER_ROW
end

--- 获取指定格子物品
---@param slotIndex number 1-based
---@return table|nil
function WarehouseSystem.GetItem(slotIndex)
    WarehouseSystem.Init()
    return GameState.warehouse.items[slotIndex]
end

--- 设置指定格子物品
---@param slotIndex number 1-based
---@param item table|nil
function WarehouseSystem.SetItem(slotIndex, item)
    WarehouseSystem.Init()
    GameState.warehouse.items[slotIndex] = item
end

--- 存放物品：从背包移到仓库
---@param bagSlot number 背包槽位 (1-based)
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.StoreItem(bagSlot)
    WarehouseSystem.Init()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return false, "背包未初始化" end

    local item = mgr:GetInventoryItem(bagSlot)
    if not item then return false, "该格子没有物品" end

    -- TradeLock 校验：交易保护期内物品不可存入仓库
    local blocked, reason = TradeLock.IsOperationBlocked(item)
    if blocked then return false, reason or TradeLock.LOCK_MESSAGE end

    -- 找第一个空的已解锁仓库格子
    local maxSlot = WarehouseSystem.GetUnlockedSlots()
    local targetSlot = nil
    for i = 1, maxSlot do
        if not GameState.warehouse.items[i] then
            targetSlot = i
            break
        end
    end
    if not targetSlot then return false, "仓库已满" end

    -- 移动
    GameState.warehouse.items[targetSlot] = item
    mgr:SetInventoryItem(bagSlot, nil)

    WarehouseSystem._dirty = true  -- HOTFIX-BM-01: 标记未同步
    BlackMarketSyncState.MarkWarehouseOp("store")  -- BM-S2: 统一门禁
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("inventory_changed")
    EventBus.Emit("save_request")  -- HOTFIX-BM-01: 仓库操作后即时请求存档
    print("[Warehouse] Store item '" .. (item.name or "?") .. "' bag#" .. bagSlot .. " -> wh#" .. targetSlot)
    return true, nil
end

--- 存放到指定仓库格子
---@param bagSlot number 背包槽位
---@param whSlot number 仓库目标格子
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.StoreItemToSlot(bagSlot, whSlot)
    WarehouseSystem.Init()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return false, "背包未初始化" end

    local item = mgr:GetInventoryItem(bagSlot)
    if not item then return false, "该格子没有物品" end

    -- TradeLock 校验
    local blocked, reason = TradeLock.IsOperationBlocked(item)
    if blocked then return false, reason or TradeLock.LOCK_MESSAGE end

    if whSlot < 1 or whSlot > WarehouseSystem.GetUnlockedSlots() then
        return false, "目标格子未解锁"
    end

    if GameState.warehouse.items[whSlot] then
        return false, "目标格子已有物品"
    end

    GameState.warehouse.items[whSlot] = item
    mgr:SetInventoryItem(bagSlot, nil)

    WarehouseSystem._dirty = true  -- HOTFIX-BM-01: 标记未同步
    BlackMarketSyncState.MarkWarehouseOp("store_to_slot")  -- BM-S2: 统一门禁
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("inventory_changed")
    EventBus.Emit("save_request")  -- HOTFIX-BM-01: 仓库操作后即时请求存档
    return true, nil
end

--- 取出物品：从仓库移到背包
---@param whSlot number 仓库槽位 (1-based)
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.RetrieveItem(whSlot)
    WarehouseSystem.Init()
    local item = GameState.warehouse.items[whSlot]
    if not item then return false, "该格子没有物品" end

    -- TradeLock 校验
    local blocked, reason = TradeLock.IsOperationBlocked(item)
    if blocked then return false, reason or TradeLock.LOCK_MESSAGE end

    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return false, "背包未初始化" end

    -- 找背包空位
    local targetSlot = nil
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not mgr:GetInventoryItem(i) then
            targetSlot = i
            break
        end
    end
    if not targetSlot then return false, "背包已满" end

    mgr:SetInventoryItem(targetSlot, item)
    GameState.warehouse.items[whSlot] = nil

    WarehouseSystem._dirty = true  -- HOTFIX-BM-01: 标记未同步
    BlackMarketSyncState.MarkWarehouseOp("retrieve")  -- BM-S2: 统一门禁
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("inventory_changed")
    EventBus.Emit("save_request")  -- HOTFIX-BM-01: 仓库操作后即时请求存档
    print("[Warehouse] Retrieve item '" .. (item.name or "?") .. "' wh#" .. whSlot .. " -> bag#" .. targetSlot)
    return true, nil
end

--- 解锁下一排
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.UnlockNextRow()
    WarehouseSystem.Init()
    local wh = GameState.warehouse
    local nextRow = wh.unlockedRows + 1

    if nextRow > WarehouseConfig.MAX_ROWS then
        return false, "已达最大排数"
    end

    local cost = WarehouseConfig.GetRowCost(nextRow)
    local player = GameState.player
    if not player then return false, "玩家数据未加载" end

    if player.gold < cost then
        return false, "金币不足（需要 " .. WarehouseSystem.FormatGold(cost) .. "）"
    end

    player.gold = player.gold - cost
    wh.unlockedRows = nextRow

    WarehouseSystem._dirty = true  -- HOTFIX-BM-01: 标记未同步
    BlackMarketSyncState.MarkWarehouseOp("unlock_row")  -- BM-S2: 统一门禁
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("gold_changed")
    EventBus.Emit("save_request")  -- HOTFIX-BM-01: 仓库操作后即时请求存档
    print("[Warehouse] Unlocked row " .. nextRow .. ", cost " .. cost .. " gold")
    return true, nil
end

--- 获取仓库物品数量
---@return number
function WarehouseSystem.GetItemCount()
    WarehouseSystem.Init()
    local count = 0
    for i = 1, WarehouseSystem.GetUnlockedSlots() do
        if GameState.warehouse.items[i] then
            count = count + 1
        end
    end
    return count
end

--- 仓库是否已打开（UI 层设置，供 EquipTooltip 判断）
---@return boolean
function WarehouseSystem.IsOpen()
    return GameState._warehouseOpen == true
end

--- 设置仓库打开状态
---@param open boolean
function WarehouseSystem.SetOpen(open)
    GameState._warehouseOpen = open
end

--- 仓库整理：合并同类消耗品 + 按品质排序 + 空格沉底
--- §3.3: 使用 InventorySortUtil 共享排序逻辑
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.SortWarehouse()
    WarehouseSystem.Init()
    if SortUtil._sorting then
        print("[Warehouse] SortWarehouse: 排序进行中，忽略重复调用")
        return false, "排序进行中"
    end
    SortUtil._sorting = true

    local wh = GameState.warehouse
    local maxSlot = WarehouseSystem.GetUnlockedSlots()

    -- 收集所有仓库物品
    local items = {}
    for i = 1, maxSlot do
        local item = wh.items[i]
        if item then
            items[#items + 1] = item
        end
    end

    if #items == 0 then
        SortUtil._sorting = false
        print("[Warehouse] SortWarehouse: 仓库为空，无需整理")
        return true, nil
    end

    -- 使用共享工具排序（合并 + 排序 + 守恒校验）
    local sorted, ok, msg = SortUtil.SortItems(items)
    if not ok then
        print("[Warehouse] SortWarehouse 中止: " .. (msg or "unknown"))
        SortUtil._sorting = false
        return false, msg
    end

    -- 检查排序后物品数不超过已解锁格子数
    if #sorted > maxSlot then
        print("[Warehouse] SortWarehouse 中止: 排序后物品数(" .. #sorted .. ")超过已解锁格子数(" .. maxSlot .. ")")
        SortUtil._sorting = false
        return false, "物品数超过仓库容量"
    end

    -- 清空全部已解锁格子，按排序结果重新放入
    for i = 1, maxSlot do
        wh.items[i] = nil
    end
    for i, item in ipairs(sorted) do
        wh.items[i] = item
    end

    SortUtil._sorting = false
    WarehouseSystem._dirty = true
    BlackMarketSyncState.MarkWarehouseOp("sort")
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("save_request")
    print("[Warehouse] Warehouse sorted: " .. #sorted .. " items")
    return true, nil
end

-- ============================================================================
-- 第二页 API
-- ============================================================================

--- 第二页是否已开启（第一页满解锁后可开启）
---@return boolean
function WarehouseSystem.IsPage2Available()
    WarehouseSystem.Init()
    return GameState.warehouse.unlockedRows >= WarehouseConfig.MAX_ROWS
end

--- 获取第二页已解锁排数
---@return number
function WarehouseSystem.GetPage2UnlockedRows()
    WarehouseSystem.Init()
    return GameState.warehouse.page2UnlockedRows or 0
end

--- 获取第二页已解锁格子总数
---@return number
function WarehouseSystem.GetPage2UnlockedSlots()
    return WarehouseSystem.GetPage2UnlockedRows() * WarehouseConfig.ITEMS_PER_ROW
end

--- 获取第二页指定格子物品
---@param slotIndex number 1-based
---@return table|nil
function WarehouseSystem.GetPage2Item(slotIndex)
    WarehouseSystem.Init()
    return GameState.warehouse.page2Items[slotIndex]
end

--- 存放物品到第二页：从背包移到第二页仓库
---@param bagSlot number 背包槽位 (1-based)
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.StoreItemToPage2(bagSlot)
    WarehouseSystem.Init()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return false, "背包未初始化" end

    local item = mgr:GetInventoryItem(bagSlot)
    if not item then return false, "该格子没有物品" end

    local blocked, reason = TradeLock.IsOperationBlocked(item)
    if blocked then return false, reason or TradeLock.LOCK_MESSAGE end

    local maxSlot = WarehouseSystem.GetPage2UnlockedSlots()
    if maxSlot <= 0 then return false, "第二页未解锁" end

    local targetSlot = nil
    for i = 1, maxSlot do
        if not GameState.warehouse.page2Items[i] then
            targetSlot = i
            break
        end
    end
    if not targetSlot then return false, "仓库第二页已满" end

    GameState.warehouse.page2Items[targetSlot] = item
    mgr:SetInventoryItem(bagSlot, nil)

    WarehouseSystem._dirty = true
    BlackMarketSyncState.MarkWarehouseOp("store_p2")
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("inventory_changed")
    EventBus.Emit("save_request")
    print("[Warehouse] Store item '" .. (item.name or "?") .. "' bag#" .. bagSlot .. " -> p2#" .. targetSlot)
    return true, nil
end

--- 从第二页取出物品到背包
---@param whSlot number 第二页槽位 (1-based)
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.RetrieveFromPage2(whSlot)
    WarehouseSystem.Init()
    local item = GameState.warehouse.page2Items[whSlot]
    if not item then return false, "该格子没有物品" end

    local blocked, reason = TradeLock.IsOperationBlocked(item)
    if blocked then return false, reason or TradeLock.LOCK_MESSAGE end

    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return false, "背包未初始化" end

    local targetSlot = nil
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not mgr:GetInventoryItem(i) then
            targetSlot = i
            break
        end
    end
    if not targetSlot then return false, "背包已满" end

    mgr:SetInventoryItem(targetSlot, item)
    GameState.warehouse.page2Items[whSlot] = nil

    WarehouseSystem._dirty = true
    BlackMarketSyncState.MarkWarehouseOp("retrieve_p2")
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("inventory_changed")
    EventBus.Emit("save_request")
    print("[Warehouse] Retrieve item '" .. (item.name or "?") .. "' p2#" .. whSlot .. " -> bag#" .. targetSlot)
    return true, nil
end

--- 解锁第二页下一排
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.UnlockPage2NextRow()
    WarehouseSystem.Init()
    if not WarehouseSystem.IsPage2Available() then
        return false, "请先解锁第一页全部排"
    end

    local wh = GameState.warehouse
    local nextRow = wh.page2UnlockedRows + 1

    if nextRow > WarehouseConfig.PAGE2_MAX_ROWS then
        return false, "第二页已达最大排数"
    end

    local cost = WarehouseConfig.GetPage2RowCost(nextRow)
    local player = GameState.player
    if not player then return false, "玩家数据未加载" end

    if player.gold < cost then
        return false, "金币不足（需要 " .. WarehouseSystem.FormatGold(cost) .. "）"
    end

    player.gold = player.gold - cost
    wh.page2UnlockedRows = nextRow

    WarehouseSystem._dirty = true
    BlackMarketSyncState.MarkWarehouseOp("unlock_p2_row")
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("gold_changed")
    EventBus.Emit("save_request")
    print("[Warehouse] Page2 unlocked row " .. nextRow .. ", cost " .. cost .. " gold")
    return true, nil
end

--- 获取第二页物品数量
---@return number
function WarehouseSystem.GetPage2ItemCount()
    WarehouseSystem.Init()
    local count = 0
    for i = 1, WarehouseSystem.GetPage2UnlockedSlots() do
        if GameState.warehouse.page2Items[i] then
            count = count + 1
        end
    end
    return count
end

--- 第二页整理（独立于第一页）
---@return boolean success
---@return string|nil errMsg
function WarehouseSystem.SortPage2()
    WarehouseSystem.Init()
    if SortUtil._sorting then
        return false, "排序进行中"
    end
    SortUtil._sorting = true

    local wh = GameState.warehouse
    local maxSlot = WarehouseSystem.GetPage2UnlockedSlots()

    local items = {}
    for i = 1, maxSlot do
        if wh.page2Items[i] then
            items[#items + 1] = wh.page2Items[i]
        end
    end

    if #items == 0 then
        SortUtil._sorting = false
        return true, nil
    end

    local sorted, ok, msg = SortUtil.SortItems(items)
    if not ok then
        SortUtil._sorting = false
        return false, msg
    end

    if #sorted > maxSlot then
        SortUtil._sorting = false
        return false, "物品数超过第二页容量"
    end

    for i = 1, maxSlot do
        wh.page2Items[i] = nil
    end
    for i, item in ipairs(sorted) do
        wh.page2Items[i] = item
    end

    SortUtil._sorting = false
    WarehouseSystem._dirty = true
    BlackMarketSyncState.MarkWarehouseOp("sort_p2")
    EventBus.Emit("warehouse_changed")
    EventBus.Emit("save_request")
    print("[Warehouse] Page2 sorted: " .. #sorted .. " items")
    return true, nil
end

--- 格式化金币显示
---@param gold number
---@return string
function WarehouseSystem.FormatGold(gold)
    if gold >= 100000000 then
        return string.format("%.2f亿", gold / 100000000)
    elseif gold >= 10000 then
        return string.format("%.0fW", gold / 10000)
    else
        return tostring(gold)
    end
end

--- 序列化仓库数据（供 SaveSerializer 调用）
---@return table
function WarehouseSystem.Serialize()
    WarehouseSystem.Init()
    local SaveSerializer = require("systems.save.SaveSerializer")
    local wh = GameState.warehouse

    local itemsData = {}
    for i = 1, WarehouseConfig.MAX_SLOTS do
        if wh.items[i] then
            itemsData[tostring(i)] = SaveSerializer.SerializeItemFull(wh.items[i])
        end
    end

    -- 第二页序列化
    local page2ItemsData = {}
    for i = 1, WarehouseConfig.PAGE2_MAX_SLOTS do
        if wh.page2Items and wh.page2Items[i] then
            page2ItemsData[tostring(i)] = SaveSerializer.SerializeItemFull(wh.page2Items[i])
        end
    end

    return {
        unlockedRows = wh.unlockedRows,
        items = itemsData,
        page2UnlockedRows = wh.page2UnlockedRows or 0,
        page2Items = page2ItemsData,
    }
end

--- 反序列化仓库数据（供 SaveLoader 调用）
---@param data table
function WarehouseSystem.Deserialize(data)
    if not data then
        -- 🔴 Bug fix: 无存档数据时强制重置，不走 Init() 的 lazy guard
        GameState.warehouse = {
            unlockedRows = WarehouseConfig.INITIAL_UNLOCKED_ROWS,
            items = {},
            page2UnlockedRows = 0,
            page2Items = {},
        }
        return
    end

    GameState.warehouse = {
        unlockedRows = data.unlockedRows or WarehouseConfig.INITIAL_UNLOCKED_ROWS,
        items = {},
        page2UnlockedRows = data.page2UnlockedRows or 0,
        page2Items = {},
    }

    -- 第一页物品反序列化
    if data.items then
        local SaveSerializer = require("systems.save.SaveSerializer")
        local SaveMigrations = require("systems.save.SaveMigrations")
        local NormalizePercentStats = SaveMigrations.NormalizePercentStats
        for slotStr, itemData in pairs(data.items) do
            local slotIdx = tonumber(slotStr)
            if slotIdx and slotIdx >= 1 and slotIdx <= WarehouseConfig.MAX_SLOTS then
                NormalizePercentStats(itemData)
                NormalizeWarehouseItemDisplayFields(itemData)
                if itemData.slot and not itemData.tier then
                    itemData.tier = 1
                end
                if itemData.slot and SaveSerializer.fillEquipFields then
                    SaveSerializer.fillEquipFields(itemData)
                end
                GameState.warehouse.items[slotIdx] = itemData
            end
        end
    end

    -- 第二页物品反序列化
    if data.page2Items then
        local SaveSerializer = require("systems.save.SaveSerializer")
        local SaveMigrations = require("systems.save.SaveMigrations")
        local NormalizePercentStats = SaveMigrations.NormalizePercentStats
        for slotStr, itemData in pairs(data.page2Items) do
            local slotIdx = tonumber(slotStr)
            if slotIdx and slotIdx >= 1 and slotIdx <= WarehouseConfig.PAGE2_MAX_SLOTS then
                NormalizePercentStats(itemData)
                NormalizeWarehouseItemDisplayFields(itemData)
                if itemData.slot and not itemData.tier then
                    itemData.tier = 1
                end
                if itemData.slot and SaveSerializer.fillEquipFields then
                    SaveSerializer.fillEquipFields(itemData)
                end
                GameState.warehouse.page2Items[slotIdx] = itemData
            end
        end
    end

    local p2Rows = data.page2UnlockedRows or 0
    print("[Warehouse] Deserialized: " .. (data.unlockedRows or 1) .. " rows unlocked, page2: " .. p2Rows .. " rows")
end

-- ============================================================================
-- HOTFIX-BM-01: 存档事件订阅 — 清除脏标记
-- ============================================================================
EventBus.On("game_saved", function()
    if WarehouseSystem._dirty then
        WarehouseSystem._dirty = false
        print("[Warehouse] Dirty flag cleared (game_saved)")
    end
end)

EventBus.On("game_loaded", function()
    WarehouseSystem._dirty = false
    print("[Warehouse] Dirty flag cleared (game_loaded)")
end)

return WarehouseSystem
