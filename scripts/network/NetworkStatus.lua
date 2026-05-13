-- ============================================================================
-- NetworkStatus.lua - 网络状态全局查询模块
-- N1 任务新增：提供统一的断线状态查询，供 UI 层阻断高风险操作
-- ============================================================================

local NetworkStatus = {}

-- 状态枚举
NetworkStatus.STATE_CONNECTED   = "connected"     -- 正常连接
NetworkStatus.STATE_UNSTABLE    = "unstable"       -- 短暂波动（宽限期内）
NetworkStatus.STATE_DISCONNECTED = "disconnected"  -- 持续断连

-- 当前状态（由 SaveSystem.Update 驱动更新）
NetworkStatus._state = NetworkStatus.STATE_CONNECTED

-- 连续采样失败计数（由 SaveSystem.Update 维护）
NetworkStatus._consecutiveFailCount = 0

-- 连续采样成功计数（用于恢复滞回）
NetworkStatus._consecutiveSuccessCount = 0

-- ============================================================================
-- 配置常量
-- ============================================================================

-- 连续失败多少次才判定为真断连（采样间隔 3s，3次 = 9s 宽限）
NetworkStatus.DISCONNECT_THRESHOLD = 3

-- 恢复时需要连续成功多少次才判定为已恢复（滞回防抖）
NetworkStatus.RESTORE_THRESHOLD = 2

-- 从 unstable 升级到 disconnected 的额外等待（秒）
-- 在 DISCONNECT_THRESHOLD 次失败后，再等此时长确认持续断连
NetworkStatus.SUSTAINED_DISCONNECT_DELAY = 5.0

-- 持续断连计时器
NetworkStatus._sustainedTimer = 0

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 是否处于持续断连状态（应阻断高风险操作）
---@return boolean
function NetworkStatus.IsDisconnected()
    return NetworkStatus._state == NetworkStatus.STATE_DISCONNECTED
end

--- 是否处于不稳定状态（包含断连，应显示轻提示）
---@return boolean
function NetworkStatus.IsUnstable()
    return NetworkStatus._state == NetworkStatus.STATE_UNSTABLE
        or NetworkStatus._state == NetworkStatus.STATE_DISCONNECTED
end

--- 是否正常连接
---@return boolean
function NetworkStatus.IsConnected()
    return NetworkStatus._state == NetworkStatus.STATE_CONNECTED
end

--- 获取当前状态字符串
---@return string
function NetworkStatus.GetState()
    return NetworkStatus._state
end

-- ============================================================================
-- 状态更新（仅由 SaveSystem.Update 调用）
-- ============================================================================

--- 记录一次连接采样结果
---@param connected boolean 本次采样是否连接正常
---@param dt number 距上次采样的时间间隔（秒）
---@return string|nil eventName 需要发射的事件名（nil=无状态变化）
function NetworkStatus.RecordSample(connected, dt)
    local oldState = NetworkStatus._state

    if connected then
        NetworkStatus._consecutiveFailCount = 0
        NetworkStatus._sustainedTimer = 0
        NetworkStatus._consecutiveSuccessCount = NetworkStatus._consecutiveSuccessCount + 1

        if oldState == NetworkStatus.STATE_CONNECTED then
            -- 已连接，无变化
            return nil
        end

        -- 需要连续成功 RESTORE_THRESHOLD 次才恢复
        if NetworkStatus._consecutiveSuccessCount >= NetworkStatus.RESTORE_THRESHOLD then
            NetworkStatus._state = NetworkStatus.STATE_CONNECTED
            return "connection_restored"
        end

        -- 还未达到恢复阈值，保持当前状态
        return nil
    else
        -- 采样失败
        NetworkStatus._consecutiveSuccessCount = 0
        NetworkStatus._consecutiveFailCount = NetworkStatus._consecutiveFailCount + 1

        if NetworkStatus._consecutiveFailCount == 1 and oldState == NetworkStatus.STATE_CONNECTED then
            -- 第一次失败：进入不稳定状态
            NetworkStatus._state = NetworkStatus.STATE_UNSTABLE
            NetworkStatus._sustainedTimer = 0
            return "connection_unstable"
        elseif NetworkStatus._consecutiveFailCount >= NetworkStatus.DISCONNECT_THRESHOLD
               and oldState ~= NetworkStatus.STATE_DISCONNECTED then
            -- 达到断连阈值：进入断连状态
            NetworkStatus._state = NetworkStatus.STATE_DISCONNECTED
            return "connection_lost"
        end

        return nil
    end
end

--- 重置状态（用于 Init）
function NetworkStatus.Reset()
    NetworkStatus._state = NetworkStatus.STATE_CONNECTED
    NetworkStatus._consecutiveFailCount = 0
    NetworkStatus._consecutiveSuccessCount = 0
    NetworkStatus._sustainedTimer = 0
end

return NetworkStatus
