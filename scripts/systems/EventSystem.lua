-- ============================================================================
-- EventSystem.lua — 活动系统核心逻辑（客户端+服务端共用）
--
-- 职责：
--   1. RollFudaiReward(pool) — 加权随机抽取福袋奖励（服务端调用）
--   2. Serialize() / Deserialize(data) — 活动存档序列化钩子
--   3. exchangedData_ 管理 — 客户端记录本角色已兑换次数
--
-- 设计文档：docs/设计文档/五一世界掉落活动.md v3.4 §4.3 / §11.2
-- ============================================================================

local EventConfig = require("config.EventConfig")

local M = {}

-- ============================================================================
-- 模块级状态（客户端用于本地 UI 展示，服务端以 saveData 为准）
-- ============================================================================

--- 当前角色的兑换次数 { [exchangeId] = count }
local exchangedData_ = {}

--- 上次从云端加载的完整 event_data（防止客户端存档用 nil 覆盖服务器数据）
local _lastLoadedEventData = nil

-- ============================================================================
-- 客户端状态管理
-- ============================================================================

--- 获取某兑换项已使用次数（客户端 UI 展示用）
---@param exchangeId string
---@return integer
function M.GetExchangedCount(exchangeId)
    return exchangedData_[exchangeId] or 0
end

--- 设置某兑换项已使用次数（收到服务端 S2C 结果后更新）
---@param exchangeId string
---@param count integer
function M.SetExchangedCount(exchangeId, count)
    exchangedData_[exchangeId] = count
end

--- 重置状态（切换角色 / 退出登录时调用）
function M.Reset()
    exchangedData_ = {}
    _lastLoadedEventData = nil
end

-- ============================================================================
-- 加权随机抽取（服务端执行，设计文档 §4.3）
-- ============================================================================

--- 从奖励池中按权重随机抽取一个条目
---@param pool table[] 奖励池数组，每项需有 weight 字段
---@return table 抽中的奖励条目
function M.RollFudaiReward(pool)
    local totalWeight = 0
    for _, entry in ipairs(pool) do
        totalWeight = totalWeight + entry.weight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(pool) do
        cumulative = cumulative + entry.weight
        if roll < cumulative then
            return entry
        end
    end
    -- 兜底：浮点精度问题时返回最后一个
    return pool[#pool]
end

-- ============================================================================
-- 存档序列化 / 反序列化（设计文档 §11.2）
-- ============================================================================

--- 序列化活动数据（存入 saveData.event_data）
--- 在 SavePersistence.DoSave() 中调用
---
--- 🔴 关键修复：不能在客户端无兑换记录时返回 nil！
--- 原因：服务器 HandleExchange 通过 serverCloud:BatchCommit 将兑换次数
--- 写入 saveData.event_data[eventId].exchanged。如果客户端自动存档时
--- Serialize() 返回 nil，就会用 event_data=nil 覆盖服务器写入的兑换计数，
--- 导致玩家可以无限兑换。
---@return table|nil
function M.Serialize()
    local eventId = EventConfig.GetEventId()

    -- 1. 先基于上次从云端加载的数据构建基础表（保留服务端写入的字段）
    local result = nil
    if _lastLoadedEventData then
        result = {}
        for k, v in pairs(_lastLoadedEventData) do
            result[k] = v
        end
    end

    -- 2. 如果当前有客户端兑换记录，合并覆盖到结果中
    if eventId then
        local hasData = false
        for _ in pairs(exchangedData_) do hasData = true; break end
        if hasData then
            result = result or {}
            result[eventId] = result[eventId] or {}
            result[eventId].exchanged = exchangedData_
        end
    end

    return result
end

--- 反序列化活动数据（从 saveData.event_data 恢复）
--- 在 SaveLoader.ProcessLoadedData() 中调用
---@param data table|nil saveData.event_data
function M.Deserialize(data)
    exchangedData_ = {}
    -- 缓存从云端加载的完整 event_data，防止客户端存档覆盖服务端数据
    _lastLoadedEventData = data
    if not data then return end
    local eventId = EventConfig.GetEventId()
    if not eventId then return end
    local evData = data[eventId] or {}
    exchangedData_ = evData.exchanged or {}
    print("[EventSystem] Deserialized: eventId=" .. eventId
        .. " exchanged items=" .. (function()
            local n = 0; for _ in pairs(exchangedData_) do n = n + 1 end; return n
        end)())
end

return M
