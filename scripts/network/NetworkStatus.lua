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

-- [N1R] 已删除: SUSTAINED_DISCONNECT_DELAY / _sustainedTimer
-- 状态机为纯计数驱动，dt 参数不参与判定，无需时间计时器

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
        pcall(function() require("network.NetDiagClient").RecordTransportNil() end)

        if NetworkStatus._consecutiveFailCount == 1 and oldState == NetworkStatus.STATE_CONNECTED then
            -- 第一次失败：进入不稳定状态
            NetworkStatus._state = NetworkStatus.STATE_UNSTABLE
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
    -- P1: 重置心跳状态
    NetworkStatus._heartbeatSeq = 0
    NetworkStatus._heartbeatTimer = 0
    NetworkStatus._lastAckTime = 0
    NetworkStatus._lastRtt = 0
    NetworkStatus._missedCount = 0
end

-- ============================================================================
-- P1 阶段 1：被动心跳（只观测，不改行为）
-- ============================================================================

NetworkStatus.HEARTBEAT_INTERVAL = 5.0  -- 发送间隔（秒）

-- 心跳状态（阶段1仅记录，不影响业务判断）
NetworkStatus._heartbeatSeq = 0       -- 已发送的序号
NetworkStatus._heartbeatTimer = 0     -- 距上次发送的累计时间
NetworkStatus._lastAckTime = 0        -- 最后一次收到 ACK 的 time.elapsedTime
NetworkStatus._lastRtt = 0            -- 最后一次 RTT（ms）
NetworkStatus._missedCount = 0        -- 连续未收到 ACK 的心跳数
NetworkStatus._pendingSendTime = {}   -- requestId -> sendTime 映射

--- 心跳 Tick（由 SaveSystem.UpdateCritical 每帧调用）
---@param dt number
function NetworkStatus.HeartbeatTick(dt)
    NetworkStatus._heartbeatTimer = NetworkStatus._heartbeatTimer + dt

    if NetworkStatus._heartbeatTimer < NetworkStatus.HEARTBEAT_INTERVAL then
        return
    end
    NetworkStatus._heartbeatTimer = 0

    -- 发送心跳
    local serverConn = network:GetServerConnection()
    if not serverConn then return end

    NetworkStatus._heartbeatSeq = NetworkStatus._heartbeatSeq + 1
    local seq = NetworkStatus._heartbeatSeq
    local sendTime = time.elapsedTime

    NetworkStatus._pendingSendTime[seq] = sendTime

    local SaveProtocol = require("network.SaveProtocol")
    local data = VariantMap()
    data["requestId"] = Variant(seq)
    data["clientTime"] = Variant(math.floor(sendTime * 1000))  -- ms
    serverConn:SendRemoteEvent(SaveProtocol.C2S_Heartbeat, true, data)

    -- C+: 采集
    local okNDC, NDC = pcall(require, "network.NetDiagClient")
    if okNDC and NDC then NDC.RecordHeartbeatSent() end

    -- 检查 missed：如果上一个心跳还没收到 ACK
    if seq > 1 and NetworkStatus._pendingSendTime[seq - 1] then
        NetworkStatus._missedCount = NetworkStatus._missedCount + 1
        NetworkStatus._pendingSendTime[seq - 1] = nil  -- 放弃过期 pending
        if NetworkStatus._missedCount <= 3 then
            print("[Heartbeat] missed seq=" .. (seq - 1) .. " total_missed=" .. NetworkStatus._missedCount)
        end
        if okNDC and NDC then NDC.RecordHeartbeatMissed() end
    end

    -- C+: 更新 shadow 状态
    NetworkStatus.UpdateShadowState()
end

--- 心跳 ACK 处理（由 S2C_Heartbeat 事件回调调用）
---@param requestId number
function NetworkStatus.OnHeartbeatAck(requestId)
    local sendTime = NetworkStatus._pendingSendTime[requestId]
    if not sendTime then return end  -- 过期或重复的 ACK

    NetworkStatus._pendingSendTime[requestId] = nil
    local rtt = math.floor((time.elapsedTime - sendTime) * 1000)
    NetworkStatus._lastRtt = rtt
    NetworkStatus._lastAckTime = time.elapsedTime
    NetworkStatus._missedCount = 0

    -- C+: 采集
    local ok, NDC = pcall(require, "network.NetDiagClient")
    if ok and NDC then NDC.RecordHeartbeatAck(rtt) end

    print("[Heartbeat] ack seq=" .. requestId .. " rtt=" .. rtt .. "ms")
end

-- ============================================================================
-- C+ Shadow 状态机（只记录，不影响业务判断）
-- ============================================================================

NetworkStatus.SHADOW_NO_ACK_UNSTABLE     = 10   -- 秒
NetworkStatus.SHADOW_NO_ACK_RECONNECTING = 25
NetworkStatus.SHADOW_NO_ACK_DISCONNECTED = 60

NetworkStatus._shadowState = "connected"

--- 更新 shadow 状态（由 HeartbeatTick 每次发送后调用）
function NetworkStatus.UpdateShadowState()
    if NetworkStatus._lastAckTime <= 0 then return end
    local noAckSec = time.elapsedTime - NetworkStatus._lastAckTime
    local newState = "connected"

    if noAckSec > NetworkStatus.SHADOW_NO_ACK_DISCONNECTED then
        newState = "disconnected"
    elseif noAckSec > NetworkStatus.SHADOW_NO_ACK_RECONNECTING then
        newState = "reconnecting"
    elseif noAckSec > NetworkStatus.SHADOW_NO_ACK_UNSTABLE then
        newState = "unstable"
    end

    if newState ~= NetworkStatus._shadowState then
        print("[NetworkStatus] shadow state: " .. NetworkStatus._shadowState .. " → " .. newState
            .. " (noAck=" .. string.format("%.1f", noAckSec) .. "s)")
        NetworkStatus._shadowState = newState
        -- C+: 记录状态变化
        local ok, NDC = pcall(require, "network.NetDiagClient")
        if ok and NDC then NDC.RecordShadowState(newState, noAckSec) end
    end
end

--- 获取 shadow 状态（只读，供 GM 诊断）
function NetworkStatus.GetShadowState()
    return NetworkStatus._shadowState
end

return NetworkStatus
