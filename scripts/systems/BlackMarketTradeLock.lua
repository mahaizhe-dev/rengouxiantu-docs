-- ============================================================================
-- BlackMarketTradeLock.lua — 黑市交易保护锁（BM-S4A）
--
-- 职责：
--   1. 定义锁元数据结构与常量
--   2. 提供锁状态判定 API（IsLocked / CanMerge / IsConsumeBlocked）
--   3. 提供锁写入 API（ApplyLock / ClearLock / ClearAllExpired）
--   4. 存档成功后批量清锁
--
-- 设计文档：
--   docs/2026-05-13-BM-S4A-黑市交易保护锁与统一操作闸任务卡.md
--
-- 原则：
--   - 锁只标记在消耗品堆叠上（equipment 不参与）
--   - 锁定堆叠与未锁定同类不合并
--   - 保护期内阻断一切本地状态变更
-- ============================================================================

local M = {}

-- ============================================================================
-- 常量
-- ============================================================================

--- 保护锁默认时长（秒）
M.LOCK_DURATION = 300  -- 5 分钟

--- 锁来源标识
M.SOURCE_BLACK_MARKET = "black_market"

--- 保护期内统一提示文案
M.LOCK_MESSAGE = "该商品处于黑市交易保护期，请稍后再试"

-- ============================================================================
-- 锁状态判定
-- ============================================================================

--- 判断单个堆叠是否处于保护锁定状态
---@param item table|nil 背包物品
---@return boolean
function M.IsLocked(item)
    if not item then return false end
    if not item.bmLockUntil then return false end
    if not item.bmLockSource then return false end
    -- 检查是否仍在保护期内
    return os.time() < item.bmLockUntil
end

--- 判断两个消耗品堆叠是否可以合并
--- 规则：
---   1. consumableId 必须相同
---   2. 两者锁状态必须一致（都无锁 / 都有锁且同批次）
---@param a table|nil
---@param b table|nil
---@return boolean
function M.CanMergeStacks(a, b)
    if not a or not b then return false end
    if a.consumableId ~= b.consumableId then return false end

    local aLocked = M.IsLocked(a)
    local bLocked = M.IsLocked(b)

    -- 一个锁一个不锁 → 不合并
    if aLocked ~= bLocked then return false end

    -- 都没锁 → 可合并
    if not aLocked then return true end

    -- 都有锁 → 同批次才合并
    if a.bmLockBatchId and b.bmLockBatchId then
        return a.bmLockBatchId == b.bmLockBatchId
    end

    -- 有锁但无批次 ID → 不合并（保守策略）
    return false
end

--- 判断消耗品是否被锁阻断（统一操作闸）
--- 用于：使用、消耗、卖钱、存仓、取仓、合成、激活、打造、黑市回卖
---@param item table|nil
---@return boolean blocked
---@return string|nil reason
function M.IsOperationBlocked(item)
    if not item then return false, nil end
    if M.IsLocked(item) then
        return true, M.LOCK_MESSAGE
    end
    return false, nil
end

-- ============================================================================
-- 锁写入
-- ============================================================================

--- 为物品堆叠写入保护锁元数据
---@param item table 背包物品（会被原地修改）
---@param batchId string|nil 批次 ID（可选，用于同批次合并判断）
---@param duration number|nil 锁时长秒数（可选，默认 LOCK_DURATION）
function M.ApplyLock(item, batchId, duration)
    if not item then return end
    local dur = duration or M.LOCK_DURATION
    item.bmLockUntil  = os.time() + dur
    item.bmLockSource = M.SOURCE_BLACK_MARKET
    item.bmLockBatchId = batchId or nil
end

--- 清除单个物品的保护锁
---@param item table 背包物品（会被原地修改）
function M.ClearLock(item)
    if not item then return end
    item.bmLockUntil   = nil
    item.bmLockSource  = nil
    item.bmLockBatchId = nil
end

--- 清除背包中所有已过期的锁（定时清理）
---@param getItemFn fun(i: number): table|nil 获取第 i 槽位物品的函数
---@param maxSlots number 最大槽位数
---@return number cleared 清除数量
function M.ClearAllExpired(getItemFn, maxSlots)
    local cleared = 0
    local now = os.time()
    for i = 1, maxSlots do
        local item = getItemFn(i)
        if item and item.bmLockUntil and now >= item.bmLockUntil then
            M.ClearLock(item)
            cleared = cleared + 1
        end
    end
    return cleared
end

--- 存档成功后批量清除所有保护锁（不论是否过期）
---@param getItemFn fun(i: number): table|nil 获取第 i 槽位物品的函数
---@param maxSlots number 最大槽位数
---@return number cleared 清除数量
function M.ClearAllOnSaveSuccess(getItemFn, maxSlots)
    local cleared = 0
    for i = 1, maxSlots do
        local item = getItemFn(i)
        if item and item.bmLockUntil then
            M.ClearLock(item)
            cleared = cleared + 1
        end
    end
    if cleared > 0 then
        print("[BlackMarketTradeLock] Save success → cleared " .. cleared .. " lock(s)")
    end
    return cleared
end

-- ============================================================================
-- 服务端背包锁判定（供 BackpackUtils / HandleSell 使用）
-- ============================================================================

--- 服务端判断背包中的堆叠是否处于保护期（基于存档数据）
--- 与 IsLocked 逻辑相同，但独立导出以明确调用场景
---@param itemData table|nil 存档中的 backpack[key]
---@return boolean
function M.IsLockedServerSide(itemData)
    if not itemData then return false end
    if not itemData.bmLockUntil then return false end
    if not itemData.bmLockSource then return false end
    return os.time() < itemData.bmLockUntil
end

--- 服务端判断两个堆叠是否可合并（同 CanMergeStacks，语义导出）
---@param a table|nil
---@param b table|nil
---@return boolean
function M.CanMergeStacksServerSide(a, b)
    return M.CanMergeStacks(a, b)
end

-- ============================================================================
-- 工具
-- ============================================================================

--- 生成批次 ID
---@return string
function M.GenerateBatchId()
    return string.format("bm_%d_%d", os.time(), math.random(1000, 9999))
end

--- 计算指定消耗品的未锁定数量（客户端用）
---@param getItemFn fun(i: number): table|nil
---@param maxSlots number
---@param consumableId string
---@return number unlocked 未锁定的总数量
---@return number locked 锁定中的总数量
function M.CountUnlockedConsumable(getItemFn, maxSlots, consumableId)
    local unlocked = 0
    local locked = 0
    for i = 1, maxSlots do
        local item = getItemFn(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            local count = item.count or 1
            if M.IsLocked(item) then
                locked = locked + count
            else
                unlocked = unlocked + count
            end
        end
    end
    return unlocked, locked
end

return M
