-- ============================================================================
-- CloudStorage.lua - 云存储抽象层（双模式）
--
-- 两种模式：
--   1. 单机模式（默认）：直接透传 clientScore API
--   2. 网络模式：通过 C2S/S2C 远程事件代理到服务端 serverCloud
--
-- 切换方式：
--   CloudStorage.SetNetworkMode(true)   -- 切换到网络模式
--   CloudStorage.SetNetworkMode(false)  -- 切换到单机模式
--
-- 设计原则（迁移 ≠ 优化）：
--   网络模式下的 API 签名与单机模式完全一致，
--   调用方（SaveSystem 等）无需修改任何代码。
-- ============================================================================

local SaveProtocol = require("network.SaveProtocol")
local FeatureFlags = require("config.FeatureFlags")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson
local Logger = require("utils.Logger")

local CloudStorage = {}

--- 错误码：网络模式下不支持的非存档 BatchSet
CloudStorage.ERR_UNSUPPORTED_BATCH = "UNSUPPORTED_BATCH"

-- ============================================================================
-- 模式管理
-- ============================================================================

local _isNetworkMode = false

--- 设置网络模式
---@param enabled boolean
function CloudStorage.SetNetworkMode(enabled)
    _isNetworkMode = enabled
    Logger.info("CloudStorage", "Mode: " .. (enabled and "NETWORK" or "STANDALONE"))
end

--- 获取当前模式
---@return boolean
function CloudStorage.IsNetworkMode()
    return _isNetworkMode
end

-- ============================================================================
-- 网络模式：回调注册表（requestId → events callback）
-- ============================================================================

local _requestId = 0
local _pendingCallbacks = {}  -- requestId -> events table

--- 生成唯一 requestId
---@return integer
local function NextRequestId()
    _requestId = _requestId + 1
    return _requestId
end

--- 注册回调并返回 requestId
---@param events table
---@return integer
local function RegisterCallback(events)
    local id = NextRequestId()
    -- P1-SAVE-2: 记录注册时间，用于超时清理
    _pendingCallbacks[id] = { events = events, registeredAt = os.clock() }
    return id
end

--- 取出并执行回调
---@param requestId integer
---@return table|nil
local function PopCallback(requestId)
    local entry = _pendingCallbacks[requestId]
    _pendingCallbacks[requestId] = nil
    if entry then return entry.events end
    return nil
end

-- P1-SAVE-2: 回调超时清理
local CALLBACK_TIMEOUT = 30  -- 秒

--- 定期调用，清理超时的 pending 回调（防止内存泄漏）
--- 由外部 Update 循环每隔一段时间调用
function CloudStorage.Tick()
    local now = os.clock()
    for id, entry in pairs(_pendingCallbacks) do
        if now - entry.registeredAt > CALLBACK_TIMEOUT then
            Logger.warn("CloudStorage", "TIMEOUT: callback id=" .. id .. " expired after " .. CALLBACK_TIMEOUT .. "s")
            _pendingCallbacks[id] = nil
            if entry.events and entry.events.error then
                local ok, err = pcall(entry.events.error, -2, "请求超时")
                if not ok then
                    Logger.error("CloudStorage", "TIMEOUT callback error: " .. tostring(err))
                end
            end
        end
    end
end

-- ============================================================================
-- 网络模式：事件订阅（在 SetNetworkMode(true) 时自动订阅）
-- ============================================================================

local _subscribed = false

local function EnsureSubscribed()
    if _subscribed then return end
    _subscribed = true

    -- FetchSlots 响应由 CharacterSelectScreen 直接处理（不经过 CloudStorage）
    -- Load 响应由 SaveSystem 直接处理（不经过 CloudStorage）

    -- 通用 Save 结果
    SubscribeToEvent(SaveProtocol.S2C_SaveResult, "CloudStorage_HandleSaveResult")
    -- 排行榜结果
    SubscribeToEvent(SaveProtocol.S2C_RankListData, "CloudStorage_HandleRankListData")

    Logger.info("CloudStorage", "Network event handlers subscribed")
end

-- ============================================================================
-- 用户 ID
-- ============================================================================

--- 网络模式下由服务端 FetchSlots 回传的 userId
local _networkUserId = nil

--- 设置网络模式下的 userId（由 SaveSystemNet 调用）
---@param uid string
function CloudStorage.SetNetworkUserId(uid)
    _networkUserId = uid
end

--- 获取当前用户 ID
---@return string|integer|nil
function CloudStorage.GetUserId()
    if _networkUserId then return _networkUserId end
    return clientScore and clientScore.userId
end

-- ============================================================================
-- 批量读取（BatchGet）— 网络模式下不直接使用
-- 注意：网络模式下 BatchGet 由 SaveSystem.FetchSlots / Load 的专用 C2S 事件代替，
-- 而不是在 CloudStorage 层做通用 builder 模拟。
-- 这里保留 builder 接口是为了让 VersionGuard.Init 中的 CloudStorage.Get 正常工作。
-- ============================================================================

--- 创建批量读取构建器
---@return table builder 链式调用构建器
function CloudStorage.BatchGet()
    -- 单机模式：直接透传
    if not _isNetworkMode then
        local api = clientCloud or clientScore
        if not api then
            -- multiplayer 构建回退到 standalone 但 clientScore 不可用
            Logger.warn("CloudStorage", "BatchGet in standalone mode but clientScore is nil")
            local dummy = { _keys = {} }
            function dummy:Key(key) table.insert(self._keys, key); return self end
            function dummy:Fetch(events)
                if events and events.error then
                    events.error(-1, "云存储不可用（服务器连接失败）")
                end
            end
            return dummy
        end
        return api:BatchGet()
    end

    -- 网络模式：构建 key 列表，Fetch 时发送 C2S_LoadGame
    -- 注意：这个通用 builder 仅用于 FetchSlots/Load 以外的 BatchGet 场景
    -- （目前代码中没有这样的场景，但保留以防万一）
    local builder = {
        _keys = {},
    }

    function builder:Key(key)
        table.insert(self._keys, key)
        return self
    end

    function builder:Fetch(events)
        -- 网络模式下不支持通用 BatchGet（应使用专用 C2S 事件）
        Logger.warn("CloudStorage", "BatchGet:Fetch in network mode — not supported for generic use")
        if events and events.error then
            events.error(-1, "BatchGet not supported in network mode, use specific C2S events")
        end
    end

    return builder
end

-- ============================================================================
-- 批量写入（BatchSet）
-- ============================================================================

--- 判断 sets 表中是否包含存档键（save_{slot} 或 save_data_{slot}）
---@param sets table<string, any>
---@return boolean
local function IsSaveBatch(sets)
    for key, _ in pairs(sets) do
        if key:match("^save_%d+$") or key:match("^save_data_%d+$") then
            return true
        end
    end
    return false
end

--- 收集 batch 中所有操作的 key 列表（用于诊断日志）
---@param sets table
---@param setInts table
---@param deletes table
---@return string[]
local function CollectBatchKeys(sets, setInts, deletes)
    local keys = {}
    for k, _ in pairs(sets) do keys[#keys + 1] = k end
    for k, _ in pairs(setInts) do keys[#keys + 1] = k end
    for k, _ in pairs(deletes) do keys[#keys + 1] = "(del)" .. k end
    table.sort(keys)
    return keys
end

--- 创建批量写入构建器
---@return table builder 链式调用构建器
function CloudStorage.BatchSet()
    -- 单机模式：直接透传
    if not _isNetworkMode then
        local api = clientCloud or clientScore
        if not api then
            Logger.warn("CloudStorage", "BatchSet in standalone mode but clientScore is nil")
            local dummy = { _sets = {}, _setInts = {}, _deletes = {} }
            function dummy:Set(k, v) return self end
            function dummy:SetInt(k, v) return self end
            function dummy:Add(k, d) return self end
            function dummy:Delete(k) return self end
            function dummy:Save(desc, events)
                if events and events.error then
                    events.error(-1, "云存储不可用（服务器连接失败）")
                end
            end
            return dummy
        end
        return api:BatchSet()
    end

    -- 网络模式：收集所有 Set/SetInt/Delete 操作，Save 时通过 C2S_SaveGame 发送
    EnsureSubscribed()

    local builder = {
        _sets = {},      -- { key = value }（table 值）
        _setInts = {},   -- { key = number }（整数值）
        _deletes = {},   -- { key = true }
    }

    function builder:Set(key, value)
        self._sets[key] = value
        return self
    end

    function builder:SetInt(key, value)
        self._setInts[key] = value
        return self
    end

    function builder:Add(key, delta)
        -- Add 在网络模式下转换为 SetInt（需要先知道当前值，简化处理）
        self._setInts[key] = (self._setInts[key] or 0) + delta
        return self
    end

    function builder:Delete(key)
        self._deletes[key] = true
        return self
    end

    function builder:Save(desc, events)
        -- 将收集的数据通过 C2S_SaveGame 发送给服务端
        -- 这里需要判断是存档 Save 还是其他类型的 BatchSet
        -- SaveSystem.DoSave 会构建包含 save_X（v11）的 batch
        -- 其他地方（如 FetchSlots 自愈、checkpoint）也会用 BatchSet

        -- 提取关键数据
        local slot = nil
        local coreData = nil
        local slotsIndex = nil
        local bulletin = nil
        local playerLevel = nil
        local rankData = {}
        local codeVersion = nil

        for key, value in pairs(self._sets) do
            -- v11 新格式: save_X（X=slot），backpack 已嵌入 coreData
            if key:match("^save_%d+$") then
                slot = tonumber(key:match("^save_(%d+)$"))
                coreData = value
            -- v10 旧格式兼容（迁移期残留调用）
            elseif key:match("^save_data_%d+$") then
                slot = slot or tonumber(key:match("save_data_(%d+)"))
                coreData = coreData or value
            elseif key == "slots_index" then
                slotsIndex = value
            elseif key == "account_bulletin" then
                bulletin = value
            elseif key:match("^rank_info_%d+$") then
                rankData.info = value
            end
        end

        for key, value in pairs(self._setInts) do
            if key == "player_level" then
                playerLevel = value
            elseif key == "_code_ver" then
                codeVersion = value
            elseif key:match("^rank_score_%d+$") then
                rankData.rankScore = value
            elseif key:match("^boss_kills_%d+$") then
                rankData.bossKills = value
            elseif key:match("^rank_time_%d+$") then
                rankData.achieveTime = value
            end
        end

        -- 如果有 coreData，走 C2S_SaveGame
        if coreData and slot then
            rankData.level = coreData.player and coreData.player.level or 0

            local requestId = RegisterCallback(events)

            local eventData = VariantMap()
            eventData["slot"] = Variant(slot)
            eventData["coreData"] = Variant(cjson.encode(coreData))
            -- 🔴 Bug fix: slotsIndex 为 nil 时发送空字符串而非 "{}"，
            -- 防止服务端把空对象当作有效值写入，清空 slots_index
            eventData["slotsIndex"] = Variant(slotsIndex and cjson.encode(slotsIndex) or "")
            eventData["rankData"] = Variant(cjson.encode(rankData))
            eventData["bulletin"] = Variant(bulletin and cjson.encode(bulletin) or "")
            eventData["playerLevel"] = Variant(playerLevel or 0)
            eventData["codeVersion"] = Variant(codeVersion or 0)
            eventData["requestId"] = Variant(requestId)

            local serverConn = network:GetServerConnection()
            if serverConn then
                serverConn:SendRemoteEvent(SaveProtocol.C2S_SaveGame, true, eventData)
            else
                Logger.error("CloudStorage", "No server connection for Save")
                if events and events.error then
                    events.error(-1, "No server connection")
                end
            end
        else
            -- 非存档 BatchSet（如 checkpoint、自愈写回）
            -- 网络模式下不写入服务端
            if FeatureFlags.isEnabled("CLOUDSTORAGE_STRICT_BATCHSET") then
                -- P0-5 严格模式：显式告知调用方"未写入"
                local keyList = CollectBatchKeys(self._sets, self._setInts, self._deletes)
                local reason = string.format(
                    "Unsupported non-save BatchSet in network mode: desc=%s keys=[%s]",
                    tostring(desc), table.concat(keyList, ", "))
                Logger.warn("CloudStorage", "STRICT: " .. reason)
                if events and events.error then
                    events.error(CloudStorage.ERR_UNSUPPORTED_BATCH, reason)
                end
            else
                -- 旧路径（flag=false）：保持原有假成功行为
                Logger.warn("CloudStorage", "Network BatchSet (non-save): desc=" .. tostring(desc) .. " — skipped")
                if events and events.ok then
                    events.ok()
                end
            end
        end
    end

    return builder
end

-- ============================================================================
-- 单键读取（Get）
-- ============================================================================

--- 读取单个键值
---@param key string
---@param events table { ok = function(scores, iscores, sscores), error = function(code, reason) }
function CloudStorage.Get(key, events)
    if not _isNetworkMode then
        local api = clientCloud or clientScore
        if not api then
            Logger.warn("CloudStorage", "Get in standalone mode but clientScore is nil, key=" .. key)
            if events and events.error then
                events.error(-1, "云存储不可用（服务器连接失败）")
            end
            return
        end
        api:Get(key, events)
        return
    end

    -- 网络模式：VersionGuard 用 Get 读取 _code_ver
    -- 在网络模式下，VersionGuard 的版本检测由服务端握手替代
    -- 此处返回空数据（不报错），让 VersionGuard 的检查逻辑空转
    Logger.diag("CloudStorage", "Network Get: key=" .. key .. " — returning empty (server-side)")
    if events and events.ok then
        events.ok({}, {}, {})
    end
end

-- ============================================================================
-- 单键写入（SetInt）
-- ============================================================================

--- 写入单个整数值
---@param key string
---@param value integer
---@param events table { ok = function(), error = function(code, reason) }
function CloudStorage.SetInt(key, value, events)
    if not _isNetworkMode then
        local api = clientCloud or clientScore
        if not api then
            Logger.warn("CloudStorage", "SetInt in standalone mode but clientScore is nil, key=" .. key)
            if events and events.error then
                events.error(-1, "云存储不可用（服务器连接失败）")
            end
            return
        end
        api:SetInt(key, value, events)
        return
    end

    -- 网络模式：VersionGuard 用 SetInt 写 _code_ver
    -- 在网络模式下，_code_ver 由 Save 时搭车写入服务端
    -- 此处直接返回成功
    Logger.diag("CloudStorage", "Network SetInt: key=" .. key .. " value=" .. value .. " — deferred to Save")
    if events and events.ok then
        events.ok()
    end
end

-- ============================================================================
-- 排行榜查询（GetRankList）
-- ============================================================================

--- 查询排行榜
---@param key string 排行榜 key
---@param start integer 起始位置（0-based）
---@param count integer 返回数量
---@param events table { ok = function(rankList), error = function(code, reason) }
---@param ... string 附加字段 key
function CloudStorage.GetRankList(key, start, count, events, ...)
    if not _isNetworkMode then
        local api = clientCloud or clientScore
        if not api then
            Logger.warn("CloudStorage", "GetRankList in standalone mode but clientScore is nil")
            if events and events.error then
                events.error(-1, "云存储不可用（服务器连接失败）")
            end
            return
        end
        api:GetRankList(key, start, count, events, ...)
        return
    end

    -- 网络模式：通过 C2S_GetRankList 发送
    EnsureSubscribed()

    local extraKeys = { ... }
    local requestId = RegisterCallback(events)

    local eventData = VariantMap()
    eventData["rankKey"] = Variant(key)
    eventData["start"] = Variant(start)
    eventData["count"] = Variant(count)
    eventData["extraKeys"] = Variant(cjson.encode(extraKeys))
    eventData["requestId"] = Variant(requestId)

    local serverConn = network:GetServerConnection()
    if serverConn then
        serverConn:SendRemoteEvent(SaveProtocol.C2S_GetRankList, true, eventData)
    else
        Logger.error("CloudStorage", "No server connection for GetRankList")
        if events and events.error then
            events.error(-1, "No server connection")
        end
    end
end

-- ============================================================================
-- 网络模式：S2C 事件处理函数（全局函数，由 SubscribeToEvent 调用）
-- ============================================================================

--- 保存结果回调
function CloudStorage_HandleSaveResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local message = nil
    local hasMsg = pcall(function() message = eventData["message"]:GetString() end)

    -- 优先用 requestId 精确匹配回调
    local requestId = nil
    pcall(function() requestId = eventData["requestId"]:GetInt() end)

    local events = nil
    if requestId and requestId > 0 then
        events = PopCallback(requestId)
    end

    -- 兜底：如果服务端未回传 requestId（兼容旧版本），用 FIFO
    -- 由于存档是串行的（saving 锁），通常只有一个 pending
    if not events then
        for id, entry in pairs(_pendingCallbacks) do
            events = entry.events
            _pendingCallbacks[id] = nil
            break
        end
    end

    if events then
        if ok then
            if events.ok then events.ok() end
        else
            if events.error then events.error(-1, message or "Save failed") end
        end
    end
end

--- 排行榜数据回调
function CloudStorage_HandleRankListData(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local rankKey = eventData["rankKey"]:GetString()

    -- 优先用 requestId 精确匹配回调
    local requestId = nil
    pcall(function() requestId = eventData["requestId"]:GetInt() end)

    local events = nil
    if requestId and requestId > 0 then
        events = PopCallback(requestId)
    end

    -- 兜底：如果服务端未回传 requestId（兼容旧版本），用 FIFO
    if not events then
        for id, entry in pairs(_pendingCallbacks) do
            events = entry.events
            _pendingCallbacks[id] = nil
            break
        end
    end

    if events then
        if ok then
            local rankListJson = eventData["rankList"]:GetString()
            local decoded = cjson.decode(rankListJson)
            if events.ok then events.ok(decoded) end
        else
            local message = nil
            pcall(function() message = eventData["message"]:GetString() end)
            if events.error then events.error(-1, message or "GetRankList failed") end
        end
    else
        Logger.warn("CloudStorage", "RankList response for key=" .. rankKey .. " has no matching callback (reqId=" .. tostring(requestId) .. ")")
    end
end

return CloudStorage
