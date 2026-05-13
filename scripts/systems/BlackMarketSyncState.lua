-- ============================================================================
-- BlackMarketSyncState.lua - 统一黑市未同步门禁
--
-- BM-S2: 将黑市卖出前的客户端门禁从"仓库 dirty + 敏感道具白名单"
-- 升级为基于操作类型的统一未同步门。
--
-- 设计原则：
--   1. 不依赖物品名称白名单 — 以操作类型（消耗、仓库存取）为粒度
--   2. 新增黑市商品自动进入门禁 — 只要走 ConsumeConsumable 就被覆盖
--   3. 保留 BM-01/BM-01A 止血效果 — 仓库和消耗路径均不退化
--   4. 结合 SaveSession 活跃状态 — 覆盖延迟窗口内的未落盘操作
--
-- 脏标记语义：
--   _dirtyConsume   = true: 存在消耗操作尚未同步到服务端
--   _dirtyWarehouse = true: 存在仓库操作尚未同步到服务端
--   SaveSession.IsDirty(): 存在延迟合并窗口内的未落盘操作
--
-- 清除时机：
--   game_saved  → 清除 _dirtyConsume + _dirtyWarehouse
--   game_loaded → 清除 _dirtyConsume + _dirtyWarehouse
-- ============================================================================

local EventBus = require("core.EventBus")

local BlackMarketSyncState = {}

-- ============================================================================
-- 内部状态
-- ============================================================================

BlackMarketSyncState._dirtyConsume   = false  -- 消耗操作脏标记
BlackMarketSyncState._dirtyWarehouse = false  -- 仓库操作脏标记

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 标记消耗操作脏（ConsumeConsumable 成功后调用）
---@param consumableId string 消耗品 ID（仅用于日志）
function BlackMarketSyncState.MarkConsumeUsed(consumableId)
    BlackMarketSyncState._dirtyConsume = true
    print("[BlackMarketSyncState] consume dirty: " .. tostring(consumableId))
end

--- 标记仓库操作脏（仓库存/取/解锁后调用）
---@param reason string 操作原因（仅用于日志）
function BlackMarketSyncState.MarkWarehouseOp(reason)
    BlackMarketSyncState._dirtyWarehouse = true
    print("[BlackMarketSyncState] warehouse dirty: " .. tostring(reason))
end

--- 查询是否应阻断黑市卖出
--- 三合一条件：消耗脏 OR 仓库脏 OR SaveSession 活跃延迟窗口
---@return boolean blocked
---@return string|nil reason 阻断原因（用于日志/UI）
function BlackMarketSyncState.IsBlocked()
    -- 消耗操作未同步
    if BlackMarketSyncState._dirtyConsume then
        return true, "consume_unsync"
    end

    -- 仓库操作未同步
    if BlackMarketSyncState._dirtyWarehouse then
        return true, "warehouse_unsync"
    end

    -- SaveSession 活跃窗口（延迟合并中，尚未 flush）
    local okSS, SaveSession = pcall(require, "systems.save.SaveSession")
    if okSS and SaveSession and SaveSession.IsDirty() then
        return true, "save_session_active"
    end

    return false, nil
end

--- 清除所有脏标记（存档成功/加载时调用）
function BlackMarketSyncState.ClearAll()
    local wasDirty = BlackMarketSyncState._dirtyConsume or BlackMarketSyncState._dirtyWarehouse
    BlackMarketSyncState._dirtyConsume   = false
    BlackMarketSyncState._dirtyWarehouse = false
    if wasDirty then
        print("[BlackMarketSyncState] All dirty flags cleared")
    end
end

--- 查询消耗脏标记（供测试用）
---@return boolean
function BlackMarketSyncState.IsConsumeDirty()
    return BlackMarketSyncState._dirtyConsume == true
end

--- 查询仓库脏标记（供测试用）
---@return boolean
function BlackMarketSyncState.IsWarehouseDirty()
    return BlackMarketSyncState._dirtyWarehouse == true
end

-- ============================================================================
-- 事件订阅：存档事件清除脏标记
-- ============================================================================

EventBus.On("game_saved", function()
    BlackMarketSyncState.ClearAll()
end)

EventBus.On("game_loaded", function()
    BlackMarketSyncState.ClearAll()
end)

return BlackMarketSyncState
