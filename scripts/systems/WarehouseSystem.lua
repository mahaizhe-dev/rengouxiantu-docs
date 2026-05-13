-- ============================================================================
-- WarehouseSystem.lua - 仓库数据层
-- 管理仓库物品存取、排解锁逻辑
-- ============================================================================

local WarehouseConfig = require("config.WarehouseConfig")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")

local WarehouseSystem = {}

-- ── HOTFIX-BM-01: 仓库脏标记（未同步状态显式语义） ──
-- true = 仓库自上次成功存档后发生过变更，服务端 saveData 尚未反映本地仓库/背包真实状态
-- 黑市卖出前读此标记来决定是否拦截
WarehouseSystem._dirty = false

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
        }
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

    if whSlot < 1 or whSlot > WarehouseSystem.GetUnlockedSlots() then
        return false, "目标格子未解锁"
    end

    if GameState.warehouse.items[whSlot] then
        return false, "目标格子已有物品"
    end

    GameState.warehouse.items[whSlot] = item
    mgr:SetInventoryItem(bagSlot, nil)

    WarehouseSystem._dirty = true  -- HOTFIX-BM-01: 标记未同步
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

--- 格式化金币显示
---@param gold number
---@return string
function WarehouseSystem.FormatGold(gold)
    if gold >= 100000000 then
        return string.format("%.1f亿", gold / 100000000)
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

    return {
        unlockedRows = wh.unlockedRows,
        items = itemsData,
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
        }
        return
    end

    GameState.warehouse = {
        unlockedRows = data.unlockedRows or WarehouseConfig.INITIAL_UNLOCKED_ROWS,
        items = {},
    }

    if data.items then
        for slotStr, itemData in pairs(data.items) do
            local slotIdx = tonumber(slotStr)
            if slotIdx and slotIdx >= 1 and slotIdx <= WarehouseConfig.MAX_SLOTS then
                GameState.warehouse.items[slotIdx] = itemData
            end
        end
    end

    print("[Warehouse] Deserialized: " .. (data.unlockedRows or 1) .. " rows unlocked")
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
