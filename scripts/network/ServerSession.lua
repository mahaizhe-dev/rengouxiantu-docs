-- ============================================================================
-- ServerSession.lua — 服务端共享状态层
--
-- 职责：持有所有连接级共享状态表 + 纯工具函数。
-- 业务 Handler 通过 require("network.ServerSession") 访问。
-- 本模块不订阅任何事件，不包含业务逻辑。
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B1）
-- ============================================================================

local M = {}

-- ============================================================================
-- GM 管理员白名单（userId）
-- ============================================================================
M.GM_ADMIN_UIDS = {
    [1092360835] = true,
}

--- 检查 userId 是否为 GM 管理员
---@param userId integer
---@return boolean
function M.IsGMAdmin(userId)
    return M.GM_ADMIN_UIDS[userId] == true
end

-- ============================================================================
-- 连接管理
-- ============================================================================

--- connKey -> Connection
M.connections_ = {}
--- connKey -> userId (int64)
M.userIds_ = {}
--- connKey -> slot (当前加载的角色槽位，HandleLoadGame 时记录)
M.connSlots_ = {}
--- sealDemonActive_: connKey -> true
M.sealDemonActive_ = {}
--- daoTreeMeditating_: connKey -> true
M.daoTreeMeditating_ = {}
--- trialClaimingActive_: connKey -> true
M.trialClaimingActive_ = {}
--- P1-SRV-4: CreateChar 防重入守卫 { [userId..":"..slot] = true }
M.creatingChar_ = {}

-- ============================================================================
-- P1-SRV-7: C2S 请求限流（滑动窗口，每连接 50 次/10 秒）
-- ============================================================================
M.RATE_LIMIT_WINDOW = 10   -- 窗口大小（秒）
M.RATE_LIMIT_MAX    = 50   -- 窗口内最大请求数
M.rateLimitCounters_ = {}  -- connKey -> { count=number, windowStart=number }

--- 检查连接是否超限。返回 true 表示放行，false 表示应拒绝
---@param connKey string
---@return boolean
function M.CheckRateLimit(connKey)
    local now = os.clock()
    local entry = M.rateLimitCounters_[connKey]
    if not entry then
        M.rateLimitCounters_[connKey] = { count = 1, windowStart = now }
        return true
    end
    if now - entry.windowStart > M.RATE_LIMIT_WINDOW then
        entry.count = 1
        entry.windowStart = now
        return true
    end
    entry.count = entry.count + 1
    if entry.count > M.RATE_LIMIT_MAX then
        return false
    end
    return true
end

-- ============================================================================
-- Per-slot 写入锁
-- ============================================================================
M.slotWriteLocks_ = {}

--- 获取 slot 写入锁 key
---@param userId integer|string
---@param slot number
---@return string
function M.SlotLockKey(userId, slot)
    return tostring(userId) .. ":" .. tostring(slot)
end

--- 尝试获取 slot 写入锁（非阻塞）
---@param userId integer|string
---@param slot number
---@return boolean 是否成功获取锁
function M.AcquireSlotLock(userId, slot)
    local key = M.SlotLockKey(userId, slot)
    if M.slotWriteLocks_[key] then
        return false
    end
    M.slotWriteLocks_[key] = true
    return true
end

--- 释放 slot 写入锁
---@param userId integer|string
---@param slot number
function M.ReleaseSlotLock(userId, slot)
    local key = M.SlotLockKey(userId, slot)
    M.slotWriteLocks_[key] = nil
end

--- 检查 slot 是否被锁定
---@param userId integer|string
---@param slot number
---@return boolean
function M.IsSlotLocked(userId, slot)
    return M.slotWriteLocks_[M.SlotLockKey(userId, slot)] == true
end

-- ============================================================================
-- 连接工具函数
-- ============================================================================

--- 获取 connKey
---@param connection userdata
---@return string
function M.ConnKey(connection)
    return tostring(connection)
end

--- 根据 connKey 获取 userId
---@param connKey string
---@return integer|nil
function M.GetUserId(connKey)
    return M.userIds_[connKey]
end

-- ============================================================================
-- 通信工具
-- ============================================================================

--- 安全发送远程事件（连接可能已断开）
---@param connection userdata
---@param eventName string
---@param data userdata VariantMap
function M.SafeSend(connection, eventName, data)
    local ok, err = pcall(function()
        connection:SendRemoteEvent(eventName, true, data)
    end)
    if not ok then
        print("[Server] SafeSend failed for " .. eventName .. ": " .. tostring(err))
    end
end

--- 归一化 slots_index 的 slots key（JSON 反序列化后数字 key 可能变成字符串）
---@param slotsIndex table
---@return table
function M.NormalizeSlotsIndex(slotsIndex)
    if not slotsIndex or not slotsIndex.slots then return slotsIndex end
    local normalized = {}
    for k, v in pairs(slotsIndex.slots) do
        local numKey = tonumber(k)
        if numKey and type(v) == "table" then
            normalized[numKey] = v
        end
    end
    slotsIndex.slots = normalized
    return slotsIndex
end

-- ============================================================================
-- 存档读取（v11/v10 fallback）
-- B2 拆分时从 server_main.lua 提升至此，所有 Handler 共用
-- ============================================================================

--- 读取玩家存档数据（优先 v11，fallback v10 + bag 合并）
---@param userId integer
---@param slot number
---@param callback fun(saveData: table|nil)
function M.ServerGetSlotData(userId, slot, callback)
    local newKey = "save_" .. slot
    local oldKey = "save_data_" .. slot
    local oldBag1 = "save_bag1_" .. slot
    local oldBag2 = "save_bag2_" .. slot

    serverCloud:BatchGet(userId)
        :Key(newKey)
        :Key(oldKey)
        :Key(oldBag1)
        :Key(oldBag2)
        :Fetch({
            ok = function(scores)
                local v11 = scores[newKey]
                if v11 and type(v11) == "table" then
                    callback(v11)
                    return
                end
                local v10 = scores[oldKey]
                if v10 and type(v10) == "table" then
                    -- 合并 bag
                    local bp = {}
                    local b1 = scores[oldBag1]
                    local b2 = scores[oldBag2]
                    if b1 and type(b1) == "table" then
                        for k, v in pairs(b1) do bp[k] = v end
                    end
                    if b2 and type(b2) == "table" then
                        for k, v in pairs(b2) do bp[k] = v end
                    end
                    v10.backpack = bp
                    callback(v10)
                    return
                end
                callback(nil)
            end,
            error = function(code, reason)
                print("[Server] ServerGetSlotData ERROR: slot=" .. slot .. " " .. tostring(reason))
                callback(nil)
            end,
        })
end

return M
