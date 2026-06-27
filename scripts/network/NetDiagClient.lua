-- ============================================================================
-- NetDiagClient.lua — C+ 客户端诊断采集（纯观测，不改行为）
--
-- 职责：内存计数 + 低频上报服务端
-- 安全：不触发保存、不清 dirty、不写存档、不弹 UI
-- ============================================================================

local cjson = cjson or require("cjson") ---@diagnostic disable-line: undefined-global
local GameConfig = require("config.GameConfig")

local M = {}

-- ============================================================================
-- 配置
-- ============================================================================

M.REPORT_INTERVAL = 300   -- 上报间隔（秒）
M.REPORT_JITTER = 30      -- 随机抖动（秒）
M.COUNTER_CAP = 10000     -- 单窗口计数上限

-- ============================================================================
-- 窗口计数器
-- ============================================================================

local function NewWindow()
    return {
        hbSent = 0, hbAck = 0, hbMissed = 0,
        hbRttCount = 0, hbRttSum = 0, hbRttMax = 0,
        transportNil = 0, transportRestored = 0,
        shadowUnstable = 0, shadowReconnecting = 0, shadowDisconnected = 0,
        shadowMaxNoAckSec = 0,
        saveStart = 0, saveOk = 0, saveFail = 0,
        saveTimeout = 0, saveNoServerConn = 0, saveWarning = 0,
        cloudPendingTimeout = 0, cloudNoConnSave = 0, cloudNoConnRank = 0,
        bmSellBlockWarehouse = 0, bmSellBlockConsume = 0,
        bmSellBlockSaveSession = 0, bmSellBlockOther = 0,
        bmSellBlockMaxElapsed = 0,
        rateLimitedTotal = 0, rateLimitedBM = 0, rateLimitedSave = 0,
    }
end

local _w = NewWindow()
local _reportTimer = 0
local _nextInterval = 0  -- 下次上报间隔（含 jitter）
local _windowStart = 0

-- ============================================================================
-- 内部工具
-- ============================================================================

local function Inc(field, amount)
    _w[field] = math.min((_w[field] or 0) + (amount or 1), M.COUNTER_CAP)
end

local function Max(field, value)
    if value and value > (_w[field] or 0) then
        _w[field] = math.min(value, M.COUNTER_CAP)
    end
end

-- ============================================================================
-- 采集 API（各模块调用）
-- ============================================================================

function M.RecordHeartbeatSent()       Inc("hbSent") end
function M.RecordHeartbeatAck(rtt)
    Inc("hbAck")
    Inc("hbRttCount")
    _w.hbRttSum = math.min((_w.hbRttSum or 0) + rtt, 999999999)
    Max("hbRttMax", rtt)
end
function M.RecordHeartbeatMissed()     Inc("hbMissed") end
function M.RecordTransportNil()        Inc("transportNil") end
function M.RecordTransportRestored()   Inc("transportRestored") end

function M.RecordShadowState(state, noAckSec)
    if state == "unstable" then Inc("shadowUnstable")
    elseif state == "reconnecting" then Inc("shadowReconnecting")
    elseif state == "disconnected" then Inc("shadowDisconnected")
    end
    Max("shadowMaxNoAckSec", math.floor(noAckSec or 0))
end

function M.RecordSaveStart()           Inc("saveStart") end
function M.RecordSaveOk()              Inc("saveOk") end
function M.RecordSaveFail(reason)
    Inc("saveFail")
    if reason == "no_server_conn" then Inc("saveNoServerConn")
    elseif reason == "disconnected" then Inc("saveNoServerConn")  -- 归类相同
    end
end
function M.RecordSaveTimeout()         Inc("saveTimeout") end
function M.RecordSaveWarning()         Inc("saveWarning") end

function M.RecordCloudPendingTimeout() Inc("cloudPendingTimeout") end
function M.RecordCloudNoConn(type)
    if type == "save" then Inc("cloudNoConnSave")
    elseif type == "rank" then Inc("cloudNoConnRank")
    end
end

function M.RecordRateLimited(originEvent)
    Inc("rateLimitedTotal")
    if originEvent and (originEvent:find("BlackMerchant") or originEvent:find("BM")) then
        Inc("rateLimitedBM")
    elseif originEvent and originEvent:find("Save") then
        Inc("rateLimitedSave")
    end
end

function M.RecordBMSellBlock(reason, elapsed)
    if reason and reason:find("warehouse") then Inc("bmSellBlockWarehouse")
    elseif reason and reason:find("consume") then Inc("bmSellBlockConsume")
    elseif reason and reason:find("save_session") then Inc("bmSellBlockSaveSession")
    else Inc("bmSellBlockOther")
    end
    Max("bmSellBlockMaxElapsed", math.floor(elapsed or 0))
end

-- ============================================================================
-- 上报逻辑
-- ============================================================================

local function IsAllZero()
    for k, v in pairs(_w) do
        if type(v) == "number" and v > 0 then return false end
    end
    return true
end

local function DoReport()
    local serverConn = network:GetServerConnection()
    if not serverConn then return end

    if IsAllZero() then
        _w = NewWindow()
        return
    end

    local payload = {
        v = 1,
        codeVersion = GameConfig.CODE_VERSION,
        windowSec = math.floor(time.elapsedTime - _windowStart),
        clientElapsed = math.floor(time.elapsedTime),
        net = {
            hbSent = _w.hbSent, hbAck = _w.hbAck, hbMissed = _w.hbMissed,
            hbRttCount = _w.hbRttCount, hbRttSum = _w.hbRttSum, hbRttMax = _w.hbRttMax,
            transportNil = _w.transportNil, transportRestored = _w.transportRestored,
            shadowUnstable = _w.shadowUnstable, shadowReconnecting = _w.shadowReconnecting,
            shadowDisconnected = _w.shadowDisconnected, shadowMaxNoAckSec = _w.shadowMaxNoAckSec,
        },
        save = {
            start = _w.saveStart, ok = _w.saveOk, fail = _w.saveFail,
            timeout = _w.saveTimeout, noServerConn = _w.saveNoServerConn,
            warning = _w.saveWarning,
        },
        cloud = {
            pendingTimeout = _w.cloudPendingTimeout,
            noConnSave = _w.cloudNoConnSave, noConnRank = _w.cloudNoConnRank,
        },
        bm = {
            warehouse = _w.bmSellBlockWarehouse, consume = _w.bmSellBlockConsume,
            saveSession = _w.bmSellBlockSaveSession, other = _w.bmSellBlockOther,
            maxElapsed = _w.bmSellBlockMaxElapsed,
        },
        rate = {
            total = _w.rateLimitedTotal, bm = _w.rateLimitedBM, save = _w.rateLimitedSave,
        },
    }

    local ok, json = pcall(cjson.encode, payload)
    if not ok or not json then return end
    if #json > 4096 then return end  -- payload 过大保护

    local SaveProtocol = require("network.SaveProtocol")
    local data = VariantMap()
    data["payload"] = Variant(json)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_NetDiagReport, true, data)

    -- 重置窗口
    _w = NewWindow()
    _windowStart = time.elapsedTime
end

-- ============================================================================
-- Tick（由 SaveSystem.UpdateCritical 驱动）
-- ============================================================================

function M.Tick(dt)
    _reportTimer = _reportTimer + dt
    if _nextInterval <= 0 then
        _nextInterval = M.REPORT_INTERVAL + math.random(0, M.REPORT_JITTER)
        _windowStart = time.elapsedTime
    end
    if _reportTimer >= _nextInterval then
        _reportTimer = 0
        _nextInterval = M.REPORT_INTERVAL + math.random(0, M.REPORT_JITTER)
        DoReport()
    end
end

-- ============================================================================
-- 调试：获取当前窗口快照（GM 用）
-- ============================================================================

function M.GetCurrentWindow()
    local copy = {}
    for k, v in pairs(_w) do copy[k] = v end
    copy._elapsed = time.elapsedTime - _windowStart
    return copy
end

return M
