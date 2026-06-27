-- ============================================================================
-- NetDiagHandler.lua — C+ 服务端诊断聚合
--
-- 职责：接收客户端诊断上报 → 内存聚合 → 定期 flush 到 serverCloud.list
-- 安全：不写玩家存档、不触发保存、不影响经济
-- ============================================================================

local cjson = cjson or require("cjson") ---@diagnostic disable-line: undefined-global

local M = {}

-- ============================================================================
-- 配置
-- ============================================================================

M.DIAG_UID = 0                    -- 系统 UID（不占用玩家空间）
M.DIAG_KEY = "net_diag_summary_v1"
M.BUCKET_SEC = 300                -- 聚合桶窗口（秒）
M.FLUSH_INTERVAL = 60             -- flush 间隔（秒）
M.MIN_REPORT_INTERVAL = 120       -- 单连接最小上报间隔（秒）
M.MAX_PAYLOAD_SIZE = 4096         -- payload 最大字节
M.MAX_RECORDS = 288               -- 保留最大记录数（24h / 5min）

-- ============================================================================
-- 内部状态
-- ============================================================================

local _bucket = nil               -- 当前聚合桶
local _bucketStart = 0            -- 桶开始时间
local _flushTimer = 0             -- flush 计时
local _lastReportTime = {}        -- connKey -> os.time()
local _reportCount = 0            -- 当前桶内收到的上报数
local _uniqueConns = {}           -- 当前桶内去重连接

local function NewBucket()
    return {
        hbSent = 0, hbAck = 0, hbMissed = 0,
        hbRttCount = 0, hbRttSum = 0, hbRttMax = 0,
        shadowUnstable = 0, shadowReconnecting = 0, shadowDisconnected = 0,
        saveStart = 0, saveOk = 0, saveFail = 0,
        saveTimeout = 0, saveNoServerConn = 0, saveWarning = 0,
        cloudPendingTimeout = 0, cloudNoConnSave = 0, cloudNoConnRank = 0,
        bmSellBlockWarehouse = 0, bmSellBlockConsume = 0,
        bmSellBlockSaveSession = 0, bmSellBlockMaxElapsed = 0,
        rateLimitedTotal = 0, rateLimitedBM = 0, rateLimitedSave = 0,
    }
end

local function Cap(v) return math.min(v or 0, 999999) end

local function MergeBucket(payload)
    if not _bucket then
        _bucket = NewBucket()
        _bucketStart = os.time()
    end
    local net = payload.net or {}
    local save = payload.save or {}
    local cloud = payload.cloud or {}
    local bm = payload.bm or {}
    local rate = payload.rate or {}

    _bucket.hbSent = Cap(_bucket.hbSent + (net.hbSent or 0))
    _bucket.hbAck = Cap(_bucket.hbAck + (net.hbAck or 0))
    _bucket.hbMissed = Cap(_bucket.hbMissed + (net.hbMissed or 0))
    _bucket.hbRttCount = Cap(_bucket.hbRttCount + (net.hbRttCount or 0))
    _bucket.hbRttSum = Cap(_bucket.hbRttSum + (net.hbRttSum or 0))
    _bucket.hbRttMax = math.max(_bucket.hbRttMax or 0, net.hbRttMax or 0)
    _bucket.shadowUnstable = Cap(_bucket.shadowUnstable + (net.shadowUnstable or 0))
    _bucket.shadowReconnecting = Cap(_bucket.shadowReconnecting + (net.shadowReconnecting or 0))
    _bucket.shadowDisconnected = Cap(_bucket.shadowDisconnected + (net.shadowDisconnected or 0))
    _bucket.saveStart = Cap(_bucket.saveStart + (save.start or 0))
    _bucket.saveOk = Cap(_bucket.saveOk + (save.ok or 0))
    _bucket.saveFail = Cap(_bucket.saveFail + (save.fail or 0))
    _bucket.saveTimeout = Cap(_bucket.saveTimeout + (save.timeout or 0))
    _bucket.saveNoServerConn = Cap(_bucket.saveNoServerConn + (save.noServerConn or 0))
    _bucket.saveWarning = Cap(_bucket.saveWarning + (save.warning or 0))
    _bucket.cloudPendingTimeout = Cap(_bucket.cloudPendingTimeout + (cloud.pendingTimeout or 0))
    _bucket.cloudNoConnSave = Cap(_bucket.cloudNoConnSave + (cloud.noConnSave or 0))
    _bucket.cloudNoConnRank = Cap(_bucket.cloudNoConnRank + (cloud.noConnRank or 0))
    _bucket.bmSellBlockWarehouse = Cap(_bucket.bmSellBlockWarehouse + (bm.warehouse or 0))
    _bucket.bmSellBlockConsume = Cap(_bucket.bmSellBlockConsume + (bm.consume or 0))
    _bucket.bmSellBlockSaveSession = Cap(_bucket.bmSellBlockSaveSession + (bm.saveSession or 0))
    _bucket.bmSellBlockMaxElapsed = math.max(_bucket.bmSellBlockMaxElapsed or 0, bm.maxElapsed or 0)
    _bucket.rateLimitedTotal = Cap(_bucket.rateLimitedTotal + (rate.total or 0))
    _bucket.rateLimitedBM = Cap(_bucket.rateLimitedBM + (rate.bm or 0))
    _bucket.rateLimitedSave = Cap(_bucket.rateLimitedSave + (rate.save or 0))
end

-- ============================================================================
-- 处理客户端上报
-- ============================================================================

function M.HandleReport(eventType, eventData)
    local ok, connection = pcall(function() return eventData["Connection"]:GetPtr("Connection") end)
    if not ok or not connection then return end
    local connKey = tostring(connection)

    -- 独立限频
    local now = os.time()
    if _lastReportTime[connKey] and (now - _lastReportTime[connKey]) < M.MIN_REPORT_INTERVAL then
        return  -- 过频丢弃
    end
    _lastReportTime[connKey] = now

    -- 解析 payload
    local payloadStr = ""
    pcall(function() payloadStr = eventData["payload"]:GetString() end)
    if #payloadStr == 0 or #payloadStr > M.MAX_PAYLOAD_SIZE then return end

    local decodeOk, payload = pcall(cjson.decode, payloadStr)
    if not decodeOk or type(payload) ~= "table" then return end

    -- 聚合
    _reportCount = _reportCount + 1
    _uniqueConns[connKey] = true
    MergeBucket(payload)
end

-- ============================================================================
-- Flush 到 serverCloud.list
-- ============================================================================

local function DoFlush()
    if not _bucket then return end
    if _reportCount == 0 then
        _bucket = nil
        return
    end

    local uniqueCount = 0
    for _ in pairs(_uniqueConns) do uniqueCount = uniqueCount + 1 end

    local record = {
        t = os.time(),
        windowStart = _bucketStart,
        windowSec = M.BUCKET_SEC,
        reports = _reportCount,
        uniqueConn = uniqueCount,
    }
    for k, v in pairs(_bucket) do record[k] = v end

    -- 写入 serverCloud.list（失败不重试）
    pcall(function()
        serverCloud.list:Add(M.DIAG_UID, M.DIAG_KEY, record, {
            ok = function()
                print("[NetDiag] Flush ok: reports=" .. _reportCount .. " conns=" .. uniqueCount)
            end,
            error = function(_, reason)
                print("[NetDiag] Flush error: " .. tostring(reason))
            end,
        })
    end)

    -- 重置桶
    _bucket = NewBucket()
    _bucketStart = os.time()
    _reportCount = 0
    _uniqueConns = {}
end

-- ============================================================================
-- Tick（由 server Update 驱动）
-- ============================================================================

function M.Tick(dt)
    _flushTimer = _flushTimer + dt
    if _flushTimer >= M.FLUSH_INTERVAL then
        _flushTimer = 0
        -- 检查桶是否过期
        if _bucketStart > 0 and (os.time() - _bucketStart) >= M.BUCKET_SEC then
            DoFlush()
        end
    end
end

-- ============================================================================
-- GM 查询
-- ============================================================================

function M.GetSummary(minutes)
    -- 返回最近 N 分钟内的聚合（从 serverCloud.list 读取）
    -- 异步操作，返回到回调
    return function(callback)
        pcall(function()
            serverCloud.list:Get(M.DIAG_UID, M.DIAG_KEY, {
                ok = function(records)
                    local cutoff = os.time() - (minutes * 60)
                    local sum = NewBucket()
                    sum.reports = 0
                    sum.uniqueConn = 0
                    local count = 0
                    for _, item in ipairs(records) do
                        local r = item.value
                        if r and r.t and r.t >= cutoff then
                            count = count + 1
                            sum.reports = sum.reports + (r.reports or 0)
                            sum.uniqueConn = sum.uniqueConn + (r.uniqueConn or 0)
                            for k, v in pairs(r) do
                                if type(v) == "number" and sum[k] then
                                    if k:find("Max") then
                                        sum[k] = math.max(sum[k], v)
                                    else
                                        sum[k] = sum[k] + v
                                    end
                                end
                            end
                        end
                    end
                    sum._buckets = count
                    sum._minutes = minutes
                    callback(sum)
                end,
                error = function(_, reason)
                    callback(nil, reason)
                end,
            })
        end)
    end
end

--- 清理旧记录（保留最近 MAX_RECORDS 条）
function M.TrimOldRecords()
    pcall(function()
        serverCloud.list:Get(M.DIAG_UID, M.DIAG_KEY, {
            ok = function(records)
                if #records <= M.MAX_RECORDS then return end
                -- 按时间排序，删除最旧的
                table.sort(records, function(a, b)
                    return (a.value and a.value.t or 0) < (b.value and b.value.t or 0)
                end)
                local toDelete = #records - M.MAX_RECORDS
                for i = 1, toDelete do
                    if records[i].list_id then
                        serverCloud.list:Delete(records[i].list_id)
                    end
                end
                print("[NetDiag] Trimmed " .. toDelete .. " old records")
            end,
            error = function() end,
        })
    end)
end

-- ============================================================================
-- 断线清理（清该 connKey 的限频记录）
-- ============================================================================

function M.OnDisconnect(connKey)
    _lastReportTime[connKey] = nil
end

return M
