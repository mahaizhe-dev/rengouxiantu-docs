-- ============================================================================
-- SaveSystemNet.lua - SaveSystem 网络模式实现
--
-- 职责：
--   当 CloudStorage.IsNetworkMode() == true 时，替代 SaveSystem 中
--   FetchSlots / Load / CreateCharacter / DeleteCharacter 的本地实现，
--   改为通过 C2S/S2C 远程事件与服务端通信。
--
-- 使用方式（由 SaveSystem 在方法顶部路由）：
--   if CloudStorage.IsNetworkMode() then
--       return SaveSystemNet.FetchSlots(callback)
--   end
--
-- 设计原则（迁移 ≠ 优化）：
--   - 回调签名与 SaveSystem 原方法完全一致，调用方无感知
--   - 不重复 ProcessLoadedData 等复杂逻辑，而是回调后交给 SaveSystem 处理
--   - Migration 在 FetchSlots 中自动触发，对调用方透明
--
-- R2 状态机收口：
--   - 统一 single-flight reject 语义：同类请求 pending 时拒绝新请求
--   - 统一晚到响应处理：无匹配 pending 时 warn+忽略
--   - 统一辅助函数：beginPending / resolvePending / rejectPending / hasPending
-- ============================================================================

local SaveProtocol = require("network.SaveProtocol")
local CloudStorage = require("network.CloudStorage")
local GameConfig = require("config.GameConfig")
local MigrationPolicy = require("network.MigrationPolicy")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson
local Logger = require("utils.Logger")

local SaveSystemNet = {}

-- ============================================================================
-- R2: 统一 pending 状态管理
--
-- 每类动作（fetchSlots / load / char / migrate）同一时刻最多一个 pending。
-- 语义：single-flight reject — pending 存在时新同类请求立即失败。
-- ============================================================================

--- 动作类型常量
local ACTION_FETCH_SLOTS = "fetchSlots"
local ACTION_LOAD        = "load"
local ACTION_CHAR        = "char"
local ACTION_MIGRATE     = "migrate"

--- 统一 pending 表：actionType → { callback, meta, createdAt }
--- meta 存放动作特有信息（如 slot、action 名）
local _pending = {}

--- 检查某类动作是否有 pending 请求
---@param actionType string
---@return boolean
local function hasPending(actionType)
    return _pending[actionType] ~= nil
end

--- 开始一个 pending 请求（single-flight reject：已有则返回 false）
---@param actionType string
---@param callback function
---@param meta table|nil 动作特有元数据
---@return boolean success 是否成功开始（false = 已有同类 pending，被拒绝）
local function beginPending(actionType, callback, meta)
    if _pending[actionType] then
        Logger.warn("SaveSystemNet", "REJECT: " .. actionType
            .. " already pending, refusing new request")
        return false
    end
    _pending[actionType] = {
        callback = callback,
        meta = meta or {},
        createdAt = os.clock(),
    }
    Logger.diag("SaveSystemNet", "beginPending: " .. actionType)
    return true
end

--- 解决一个 pending 请求（成功或失败），返回其 callback 和 meta
--- 如果无匹配 pending，返回 nil（晚到响应）
---@param actionType string
---@return function|nil callback
---@return table|nil meta
local function resolvePending(actionType)
    local entry = _pending[actionType]
    _pending[actionType] = nil
    if not entry then
        Logger.warn("SaveSystemNet", "LATE-RESPONSE: " .. actionType
            .. " response arrived but no matching pending (ignored)")
        return nil, nil
    end
    Logger.diag("SaveSystemNet", "resolvePending: " .. actionType
        .. " (elapsed=" .. string.format("%.1f", os.clock() - entry.createdAt) .. "s)")
    return entry.callback, entry.meta
end

--- 拒绝一个 pending 请求并通知旧回调（用于 ClearQueue 等场景）
---@param actionType string
---@param errorMsg string
local function rejectPending(actionType, errorMsg)
    local entry = _pending[actionType]
    _pending[actionType] = nil
    if entry and entry.callback then
        Logger.warn("SaveSystemNet", "rejectPending: " .. actionType .. " reason=" .. errorMsg)
        entry.callback(nil, errorMsg)
    end
end

--- 暴露给测试：获取当前 pending 状态快照
function SaveSystemNet._getPendingSnapshot()
    local snapshot = {}
    for k, v in pairs(_pending) do
        snapshot[k] = { meta = v.meta, createdAt = v.createdAt }
    end
    return snapshot
end

--- 暴露给测试：重置所有状态
function SaveSystemNet._resetForTest()
    _pending = {}
    _networkReady = false
    _queuedFetchSlots = nil
    _handlersSubscribed = false
    _delayedTasks = {}
end

local _handlersSubscribed = false
local _networkReady = false       -- ServerReady 是否已触发
local _queuedFetchSlots = nil     -- 网络未就绪时排队的 FetchSlots 回调

-- 重试配置
local MAX_RETRY = 3               -- 连接暂时不可用时最多重试次数
local RETRY_INTERVAL = 1.5        -- 重试间隔（秒）

-- 延迟执行队列（用 Update 事件驱动）
local _delayedTasks = {}           -- { { remaining, fn }, ... }
local _delayedUpdateSubscribed = false

local function ScheduleDelayed(delaySec, fn)
    table.insert(_delayedTasks, { remaining = delaySec, fn = fn })
    if not _delayedUpdateSubscribed then
        _delayedUpdateSubscribed = true
        SubscribeToEvent("PostUpdate", "SaveSystemNet_HandleDelayedUpdate")
    end
end

--- PostUpdate 驱动延迟任务
function SaveSystemNet_HandleDelayedUpdate(eventType, eventData)
    if #_delayedTasks == 0 then return end
    local dt = eventData["TimeStep"]:GetFloat()
    local i = 1
    while i <= #_delayedTasks do
        local task = _delayedTasks[i]
        task.remaining = task.remaining - dt
        if task.remaining <= 0 then
            table.remove(_delayedTasks, i)
            task.fn()
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- 初始化：订阅 S2C 事件（只订阅一次）
-- ============================================================================

function SaveSystemNet.InitHandlers()
    if _handlersSubscribed then return end
    _handlersSubscribed = true

    SubscribeToEvent(SaveProtocol.S2C_SlotsData, "SaveSystemNet_HandleSlotsData")
    SubscribeToEvent(SaveProtocol.S2C_LoadResult, "SaveSystemNet_HandleLoadResult")
    SubscribeToEvent(SaveProtocol.S2C_CharResult, "SaveSystemNet_HandleCharResult")
    SubscribeToEvent(SaveProtocol.S2C_MigrateResult, "SaveSystemNet_HandleMigrateResult")

    Logger.info("SaveSystemNet", "S2C handlers subscribed")
end

-- ============================================================================
-- 网络就绪通知（background_match 模式：ServerReady 后调用）
-- ============================================================================

--- 标记网络已就绪，自动执行排队的 FetchSlots 请求
function SaveSystemNet.OnNetworkReady()
    _networkReady = true
    Logger.info("SaveSystemNet", "Network ready, _networkReady=true")

    -- 执行排队的 FetchSlots
    if _queuedFetchSlots then
        local cb = _queuedFetchSlots
        _queuedFetchSlots = nil
        Logger.info("SaveSystemNet", "Executing queued FetchSlots...")
        SaveSystemNet.FetchSlots(cb)
    end
end

--- 清除排队的回调（连接超时回退时调用）
--- 带错误通知等待中的 FetchSlots 回调，避免 CharacterSelectScreen 挂起
function SaveSystemNet.ClearQueue()
    if _queuedFetchSlots then
        Logger.warn("SaveSystemNet", "Clearing queued FetchSlots callback (with error notification)")
        local cb = _queuedFetchSlots
        _queuedFetchSlots = nil
        -- 通知调用方连接失败，让 CharacterSelectScreen 立即显示重试 UI
        cb(nil, "服务器连接超时")
    end
    _networkReady = false
end

-- ============================================================================
-- FetchSlots（网络模式）
-- ============================================================================

--- 请求槽位列表（网络版）
--- 回调签名与 SaveSystem.FetchSlots 一致：callback(slotsIndex, errorReason)
--- 内部自动处理 needMigration → MigrateToServer → 重新 FetchSlots
---@param callback function(slotsIndex: table|nil, error: string|nil)
---@param _retryCount number|nil 内部重试计数（外部不传）
function SaveSystemNet.FetchSlots(callback, _retryCount)
    SaveSystemNet.InitHandlers()

    local serverConn = network:GetServerConnection()
    if not serverConn then
        if not _networkReady then
            -- background_match 模式：服务器连接尚未就绪，排队等待 ServerReady
            Logger.diag("SaveSystemNet", "No server connection yet (background_match), queuing FetchSlots...")
            _queuedFetchSlots = callback
            return
        end
        -- 网络已就绪但连接暂时不可用 → 自动重试
        local retries = _retryCount or 0
        if retries < MAX_RETRY then
            Logger.warn("SaveSystemNet", "FetchSlots: no connection, retry " .. (retries + 1) .. "/" .. MAX_RETRY
                .. " in " .. RETRY_INTERVAL .. "s")
            ScheduleDelayed(RETRY_INTERVAL, function()
                SaveSystemNet.FetchSlots(callback, retries + 1)
            end)
            return
        end
        -- 重试耗尽 → 报错
        Logger.error("SaveSystemNet", "FetchSlots: no connection after " .. MAX_RETRY .. " retries")
        if callback then callback(nil, "No server connection") end
        return
    end

    -- R2: single-flight reject
    if not beginPending(ACTION_FETCH_SLOTS, callback) then
        if callback then callback(nil, "FetchSlots already pending") end
        return
    end

    local data = VariantMap()
    serverConn:SendRemoteEvent(SaveProtocol.C2S_FetchSlots, true, data)
    Logger.info("SaveSystemNet", "C2S_FetchSlots sent")
end

--- S2C_SlotsData 处理
function SaveSystemNet_HandleSlotsData(eventType, eventData)
    -- R2: 统一 resolvePending
    local cb = resolvePending(ACTION_FETCH_SLOTS)
    if not cb then return end  -- 晚到响应，已在 resolvePending 中记录 warn

    local ok = eventData["ok"]:GetBool()

    if not ok then
        local message = nil
        pcall(function() message = eventData["message"]:GetString() end)
        Logger.error("SaveSystemNet", "FetchSlots failed: " .. tostring(message))
        cb(nil, message or "FetchSlots failed")
        return
    end

    local slotsIndexJson = eventData["slotsIndex"]:GetString()
    local slotsIndex = cjson.decode(slotsIndexJson)
    local needMigration = eventData["needMigration"]:GetBool()

    -- 从服务端回复中获取 userId 并存入 CloudStorage（供 SystemMenu 显示）
    local userIdStr = nil
    pcall(function() userIdStr = eventData["userId"]:GetString() end)
    if userIdStr and userIdStr ~= "" then
        CloudStorage.SetNetworkUserId(userIdStr)
    end

    -- 归一化 slots key（JSON 反序列化后数字 key 可能变成字符串）
    if slotsIndex and slotsIndex.slots then
        local normalized = {}
        for k, v in pairs(slotsIndex.slots) do
            local numKey = tonumber(k)
            if numKey and type(v) == "table" then
                normalized[numKey] = v
            end
        end
        slotsIndex.slots = normalized
    end

    -- 反序列化 account_bulletin（如果有）
    local bulletinJson = nil
    pcall(function() bulletinJson = eventData["bulletin"]:GetString() end)
    if bulletinJson and bulletinJson ~= "" then
        local ok2, bulletin = pcall(cjson.decode, bulletinJson)
        if ok2 and bulletin then
            local BulletinUI = require("ui.BulletinUI")
            BulletinUI.DeserializeAccount(bulletin)
        end
    end

    -- 反序列化 account_atlas（账号级仙图录，登录即可用）
    local atlasJson = nil
    pcall(function() atlasJson = eventData["accountAtlas"]:GetString() end)
    if atlasJson and atlasJson ~= "" then
        local ok3, atlasData = pcall(cjson.decode, atlasJson)
        if ok3 and atlasData then
            local AtlasSystem = require("systems.AtlasSystem")
            AtlasSystem.Init()
            local SaveSerializer = require("systems.save.SaveSerializer")
            SaveSerializer.DeserializeAtlas(atlasData)
            AtlasSystem.loaded = true
            Logger.info("SaveSystemNet", "account_atlas loaded at login")
        end
    end

    -- 反序列化 account_cosmetics（账号级外观数据，登录即可用）
    local cosmeticsJson = nil
    pcall(function() cosmeticsJson = eventData["accountCosmetics"]:GetString() end)
    if cosmeticsJson and cosmeticsJson ~= "" then
        local ok4, cosmeticsData = pcall(cjson.decode, cosmeticsJson)
        if ok4 and cosmeticsData then
            local GameState = require("core.GameState")
            GameState.accountCosmetics = cosmeticsData
            Logger.info("SaveSystemNet", "account_cosmetics loaded at login")
        end
    end

    -- 正常路径
    local slotCount = 0
    if slotsIndex.slots then for _ in pairs(slotsIndex.slots) do slotCount = slotCount + 1 end end
    Logger.info("SaveSystemNet", "FetchSlots ok: " .. slotCount .. " slots")

    -- P0-4: 迁移状态统一判断（由 MigrationPolicy 收口）
    local migrationState = MigrationPolicy.Evaluate(needMigration, slotCount)
    if migrationState then
        -- flag=true: 走统一入口
        Logger.info("SaveSystemNet", "MigrationPolicy: " .. MigrationPolicy.GetStateLabel(migrationState))
        if MigrationPolicy.ShouldAutoMigrate(migrationState) then
            -- 当前不会进入此分支（迁移已废弃），保留扩展点
            Logger.warn("SaveSystemNet", "MigrationPolicy: auto-migrate triggered (state=" .. migrationState .. ")")
        end
    else
        -- flag=false: 保持原有行为
        -- [已废弃] 迁移逻辑已正式关闭
        -- clientCloud → serverCloud 和 local_file → serverCloud 迁移不再触发
        -- 已迁移玩家不受影响：其 serverCloud 已有数据（needMigration=false）、本地导出文件已删除
        if needMigration then
            Logger.warn("SaveSystemNet", "needMigration=true but migration is DEPRECATED, treating as new player")
        end
    end

    -- ====== DIAGNOSTIC: 存档丢失排查 ======
    Logger.diag("SaveSystemNet", "DIAG userId=" .. tostring(userIdStr)
        .. " needMigration=" .. tostring(needMigration)
        .. " slotCount=" .. slotCount)
    Logger.diag("SaveSystemNet", "DIAG slotsIndex=" .. tostring(slotsIndexJson))
    -- ====== END DIAGNOSTIC ======
    cb(slotsIndex, nil)
end

-- ============================================================================
-- Load（网络模式）
-- ============================================================================

--- 加载指定槽位存档（网络版）
--- 回调签名与 SaveSystem.Load 一致：callback(success, message)
---@param slot number 槽位号 (1 或 2)
---@param callback function(success: boolean, message: string)
---@param _retryCount number|nil 内部重试计数（外部不传）
function SaveSystemNet.Load(slot, callback, _retryCount)
    SaveSystemNet.InitHandlers()

    local serverConn = network:GetServerConnection()
    if not serverConn then
        -- 网络连接暂时不可用 → 自动重试
        local retries = _retryCount or 0
        if retries < MAX_RETRY then
            Logger.warn("SaveSystemNet", "Load: no connection, retry " .. (retries + 1) .. "/" .. MAX_RETRY
                .. " in " .. RETRY_INTERVAL .. "s")
            ScheduleDelayed(RETRY_INTERVAL, function()
                SaveSystemNet.Load(slot, callback, retries + 1)
            end)
            return
        end
        -- 重试耗尽 → 报错
        Logger.error("SaveSystemNet", "Load: no connection after " .. MAX_RETRY .. " retries")
        local SaveSystem = require("systems.SaveSystem")
        SaveSystem.loaded = false
        if callback then callback(false, "No server connection") end
        return
    end

    -- R2: single-flight reject
    if not beginPending(ACTION_LOAD, callback, { slot = slot }) then
        if callback then callback(false, "Load already pending") end
        return
    end

    local data = VariantMap()
    data["slot"] = Variant(slot)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_LoadGame, true, data)
    Logger.info("SaveSystemNet", "C2S_LoadGame sent: slot=" .. slot)
end

--- S2C_LoadResult 处理
function SaveSystemNet_HandleLoadResult(eventType, eventData)
    -- R2: 统一 resolvePending
    local cb, meta = resolvePending(ACTION_LOAD)
    if not cb then return end  -- 晚到响应，已在 resolvePending 中记录 warn

    local SaveSystem = require("systems.SaveSystem")
    local ok = eventData["ok"]:GetBool()

    if not ok then
        local message = nil
        pcall(function() message = eventData["message"]:GetString() end)
        Logger.error("SaveSystemNet", "LoadGame failed: " .. tostring(message))
        SaveSystem.loaded = false
        cb(false, message or "Load failed")
        return
    end

    local slot = meta.slot

    -- 解码服务端发送的 JSON 数据
    local saveDataJson = eventData["saveData"]:GetString()
    local decodeOk, saveData = pcall(cjson.decode, saveDataJson)
    if not decodeOk or type(saveData) ~= "table" then
        Logger.error("SaveSystemNet", "LoadGame: saveData decode failed")
        SaveSystem.loaded = false
        cb(false, "存档数据解码失败")
        return
    end

    -- v11: equipment + backpack 已在顶层，重组 inventory 供 ProcessLoadedData 使用
    -- v10 fallback: 服务端已合并 bag → saveData.backpack
    saveData.inventory = {
        equipment = saveData.equipment or {},
        backpack = saveData.backpack or {},
    }
    saveData.equipment = nil   -- 清除顶层，统一到 inventory 下
    saveData.backpack = nil
    Logger.info("SaveSystemNet", "Inventory assembled from single-key network response")

    -- 交给 SaveSystem.ProcessLoadedData 处理（版本迁移 + 反序列化）
    SaveSystem.ProcessLoadedData(slot, saveData, nil, cb)
    Logger.info("SaveSystemNet", "LoadGame ok: slot=" .. slot)
end

-- ============================================================================
-- CreateCharacter（网络模式）
-- ============================================================================

--- 创建角色（网络版）
--- 回调签名与 SaveSystem.CreateCharacter 一致：callback(success, message)
---@param slot number 槽位号
---@param charName string 角色名
---@param slotsIndex table 当前的 slots_index（网络模式下由服务端管理，此处仅保持签名兼容）
---@param callback function(success: boolean, message: string|nil)
---@param classId string|nil 职业ID
function SaveSystemNet.CreateCharacter(slot, charName, slotsIndex, callback, classId)
    SaveSystemNet.InitHandlers()

    local serverConn = network:GetServerConnection()
    if not serverConn then
        if callback then callback(false, "No server connection") end
        return
    end

    -- R2: single-flight reject（create 和 delete 共享 char pending）
    if not beginPending(ACTION_CHAR, callback, { action = "create" }) then
        if callback then callback(false, "Character operation already pending") end
        return
    end

    local data = VariantMap()
    data["slot"] = Variant(slot)
    data["charName"] = Variant(charName)
    data["classId"] = Variant(classId or GameConfig.PLAYER_CLASS)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_CreateChar, true, data)
    Logger.info("SaveSystemNet", "C2S_CreateChar sent: slot=" .. slot .. " name=" .. charName .. " class=" .. (classId or "default"))
end

-- ============================================================================
-- DeleteCharacter（网络模式）
-- ============================================================================

--- 删除角色（网络版）
--- 回调签名与 SaveSystem.DeleteCharacter 一致：callback(success, message)
---@param slot number 槽位号
---@param slotsIndex table 当前的 slots_index（网络模式下由服务端管理）
---@param callback function(success: boolean, message: string|nil)
function SaveSystemNet.DeleteCharacter(slot, slotsIndex, callback)
    SaveSystemNet.InitHandlers()

    local serverConn = network:GetServerConnection()
    if not serverConn then
        if callback then callback(false, "No server connection") end
        return
    end

    -- R2: single-flight reject（create 和 delete 共享 char pending）
    if not beginPending(ACTION_CHAR, callback, { action = "delete" }) then
        if callback then callback(false, "Character operation already pending") end
        return
    end

    local data = VariantMap()
    data["slot"] = Variant(slot)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_DeleteChar, true, data)
    Logger.info("SaveSystemNet", "C2S_DeleteChar sent: slot=" .. slot)
end

--- S2C_CharResult 处理（创建和删除共用）
function SaveSystemNet_HandleCharResult(eventType, eventData)
    -- R2: 统一 resolvePending
    local cb, meta = resolvePending(ACTION_CHAR)
    if not cb then return end  -- 晚到响应，已在 resolvePending 中记录 warn

    local actionName = (meta and meta.action) or "char"
    local ok = eventData["ok"]:GetBool()

    if not ok then
        local message = nil
        pcall(function() message = eventData["message"]:GetString() end)
        Logger.error("SaveSystemNet", actionName .. " failed: " .. tostring(message))
        cb(false, message or "Operation failed")
        return
    end

    -- 从服务端响应更新缓存的 slotsIndex
    pcall(function()
        local slotsIndexJson = eventData["slotsIndex"]:GetString()
        if slotsIndexJson and slotsIndexJson ~= "" then
            local SaveSystem = require("systems.SaveSystem")
            local decoded = cjson.decode(slotsIndexJson)
            -- 归一化 slots key（JSON 反序列化后数字 key 可能变成字符串）
            if decoded and decoded.slots then
                local normalized = {}
                for k, v in pairs(decoded.slots) do
                    local numKey = tonumber(k)
                    if numKey and type(v) == "table" then
                        normalized[numKey] = v
                    end
                end
                decoded.slots = normalized
            end
            SaveSystem._cachedSlotsIndex = decoded
            Logger.info("SaveSystemNet", "_cachedSlotsIndex updated from server response")
        end
    end)

    Logger.info("SaveSystemNet", actionName .. " ok")
    cb(true)
end

-- ============================================================================
-- MigrateToServer — clientScore → serverCloud 迁移
-- ============================================================================

--- 从 clientScore 读取所有存档数据并发送给服务端写入 serverCloud
--- 在 FetchSlots 收到 needMigration=true 时自动触发，对调用方透明
---@param callback function(success: boolean, message: string|nil)
function SaveSystemNet.MigrateToServer(callback)
    SaveSystemNet.InitHandlers()

    -- clientCloud 是推荐 API，clientScore 是废弃别名（兼容旧引擎）
    local cloudApi = clientCloud or clientScore
    if not cloudApi then
        -- Phase 2（multiplayer.enabled=true）：clientCloud 不注入，这是正常路径
        -- 返回成功（无数据可迁移），由调用方继续尝试 MigrateFromLocalFile
        Logger.info("SaveSystemNet", "clientCloud/clientScore unavailable (Phase 2 normal), skipping clientCloud migration")
        if callback then callback(true, "no_client_cloud") end
        return
    end

    -- R2: single-flight reject
    if not beginPending(ACTION_MIGRATE, callback) then
        if callback then callback(false, "Migration already pending") end
        return
    end

    -- 直接使用 clientCloud（绕过 CloudStorage 网络模式），读取本地数据
    -- 读取顺序：全局键 → 每槽位核心键 → 排行榜键
    local builder = cloudApi:BatchGet()

    -- 全局键
    builder:Key("slots_index")
    builder:Key("account_bulletin")
    builder:Key("save_data")        -- 旧版单 key 兼容

    -- 每个槽位的核心数据（clientCloud 只有 1-2 槽，不要改成 1-4）
    for slot = 1, 2 do
        builder:Key("save_data_" .. slot)
        builder:Key("save_bag1_" .. slot)
        builder:Key("save_bag2_" .. slot)
        builder:Key("rank_info_" .. slot)
    end

    -- 整数值键（player_level, _code_ver, rank scores 等）
    builder:Key("player_level")
    builder:Key("_code_ver")
    -- clientCloud 只有 1-2 槽，不要改成 1-4
    for slot = 1, 2 do
        builder:Key("rank_score_" .. slot)
        builder:Key("rank_time_" .. slot)
        builder:Key("boss_kills_" .. slot)
    end

    builder:Fetch({
        ok = function(scores, iscores, sscores)
            -- 构建迁移 payload：合并 table 值和 integer 值
            local payload = {}

            -- Table 值（scores）
            if scores then
                for key, value in pairs(scores) do
                    if value and type(value) == "table" then
                        payload[key] = value
                    end
                end
            end

            -- Integer 值（iscores）
            if iscores then
                for key, value in pairs(iscores) do
                    if value and type(value) == "number" and value ~= 0 then
                        payload[key] = value
                    end
                end
            end

            -- 检查是否有实际数据需要迁移
            local hasData = false
            if payload.slots_index and type(payload.slots_index) == "table"
                and payload.slots_index.slots then
                for slot = 1, 2 do
                    if payload.slots_index.slots[slot] then
                        hasData = true
                        break
                    end
                end
            end
            -- 也检查旧版 save_data（可能还没有 slots_index 的老玩家）
            if not hasData and payload.save_data
                and type(payload.save_data) == "table"
                and payload.save_data.player then
                hasData = true
            end

            if not hasData then
                Logger.info("SaveSystemNet", "No clientScore data to migrate (truly new player)")
                -- R2: 通过 resolvePending 统一清理
                local migCb = resolvePending(ACTION_MIGRATE)
                if migCb then migCb(true, "no_data") end
                return
            end

            -- 发送迁移数据到服务端
            local serverConn = network:GetServerConnection()
            if not serverConn then
                local migCb = resolvePending(ACTION_MIGRATE)
                if migCb then migCb(false, "No server connection") end
                return
            end

            -- 标记迁移来源，服务端据此决定是否重映射槽位
            payload._migrationSource = "clientCloud"

            local payloadJson = cjson.encode(payload)
            local evtData = VariantMap()
            evtData["payload"] = Variant(payloadJson)
            serverConn:SendRemoteEvent(SaveProtocol.C2S_MigrateData, true, evtData)

            Logger.info("SaveSystemNet", "C2S_MigrateData sent: "
                .. string.format("%.1fKB", #payloadJson / 1024))
        end,
        error = function(code, reason)
            Logger.error("SaveSystemNet", "clientScore read failed: " .. tostring(reason))
            -- R2: 通过 resolvePending 统一清理
            local migCb = resolvePending(ACTION_MIGRATE)
            if migCb then migCb(false, "Failed to read clientScore: " .. tostring(reason)) end
        end,
    })
end

-- ============================================================================
-- MigrateFromLocalFile — Phase 1 本地导出文件 → serverCloud 迁移
-- ============================================================================

--- 读取 Phase 1 导出的 save_export_{slot}.json 文件，构建 payload 发送给服务端
--- 本地文件仅在移动端（iOS/Android）持久化，PC/Web 不存在
--- 发送成功后删除本地文件，防止重复迁移
---@param callback function(success: boolean, message: string|nil)
function SaveSystemNet.MigrateFromLocalFile(callback)
    SaveSystemNet.InitHandlers()

    -- 检查平台（PC/Web 无持久化本地文件，直接跳过）
    local platform = GetPlatform()
    if platform == "Web" or platform == "Windows" then
        Logger.info("SaveSystemNet", "MigrateFromLocalFile: skipping on " .. platform)
        if callback then callback(true, "no_local_files") end
        return
    end

    -- 收集所有存在的导出文件
    local exportSlots = {}   -- { {slot=N, data=table}, ... }
    for slot = 1, 2 do
        local filename = "save_export_" .. slot .. ".json"
        if fileSystem:FileExists(filename) then
            local f = File(filename, FILE_READ)
            if f:IsOpen() then
                local content = f:ReadString()
                f:Close()
                if content and #content > 0 then
                    local ok, parsed = pcall(cjson.decode, content)
                    if ok and type(parsed) == "table" then
                        table.insert(exportSlots, { slot = slot, data = parsed })
                        Logger.info("SaveSystemNet", "MigrateFromLocalFile: read slot " .. slot
                            .. " (" .. #content .. " bytes)")
                    else
                        Logger.error("SaveSystemNet", "MigrateFromLocalFile: decode failed for slot " .. slot)
                    end
                end
            end
        end
    end

    if #exportSlots == 0 then
        Logger.info("SaveSystemNet", "MigrateFromLocalFile: no export files found")
        if callback then callback(true, "no_local_files") end
        return
    end

    -- 构建 payload（与 MigrateToServer 格式兼容，但来源标记为 local_file）
    local payload = {
        _migrationSource = "local_file",
    }

    -- 从第一个导出文件获取 slots_index（如果有）
    -- 🔴 FIX: 只保留有对应 save_export 文件的槽位条目，避免幽灵索引
    --   例：只有 save_export_1.json 时，不要把 slot 2 的索引也带过去
    --   否则服务端会创建有索引无数据的 slot → "存档数据异常"
    if exportSlots[1].data.slots_index then
        local srcIndex = exportSlots[1].data.slots_index
        local filteredIndex = { version = srcIndex.version or 1, slots = {} }
        -- 构建实际有导出文件的槽位集合
        local hasExport = {}
        for _, entry in ipairs(exportSlots) do
            hasExport[entry.slot] = true
        end
        -- 只保留有导出文件的槽位条目
        if srcIndex.slots then
            for k, v in pairs(srcIndex.slots) do
                local numKey = tonumber(k)
                if numKey and hasExport[numKey] then
                    filteredIndex.slots[numKey] = v
                end
            end
        end
        payload.slots_index = filteredIndex
    end

    -- 汇总每个槽位的数据
    for _, entry in ipairs(exportSlots) do
        local slot = entry.slot
        local d = entry.data
        if d.save_data then
            payload["save_data_" .. slot] = d.save_data
        end
        if d.save_bag1 then
            payload["save_bag1_" .. slot] = d.save_bag1
        end
        if d.save_bag2 then
            payload["save_bag2_" .. slot] = d.save_bag2
        end
        -- 提取排行榜相关字段（从存档数据重建）
        if d.save_data and d.save_data.player then
            local p = d.save_data.player
            local level = p.level or 1
            if level > 5 then
                -- rank_score = realmOrder * 1000 + level
                local realmCfg = GameConfig.REALMS[p.realm or "mortal"]
                local realmOrder = realmCfg and realmCfg.order or 0
                local rankScore = realmOrder * 1000 + level
                payload["rank_score_" .. slot] = rankScore

                -- rank_info（角色名从 slots_index 或 player.charName 取）
                local charName = p.charName or "修仙者"
                payload["rank_info_" .. slot] = {
                    name = charName,
                    realm = p.realm or "mortal",
                    level = level,
                    bossKills = d.save_data.bossKills or 0,
                    classId = p.classId,
                }

                -- boss_kills
                payload["boss_kills_" .. slot] = d.save_data.bossKills or 0
            end
        end
    end

    -- 发送到服务端
    local serverConn = network:GetServerConnection()
    if not serverConn then
        if callback then callback(false, "No server connection") end
        return
    end

    -- R2: single-flight reject
    -- 包装回调：成功时删除本地文件
    local wrappedCallback = function(ok, msg)
        if ok then
            for _, entry in ipairs(exportSlots) do
                local filename = "save_export_" .. entry.slot .. ".json"
                if fileSystem:FileExists(filename) then
                    fileSystem:Delete(filename)
                    Logger.info("SaveSystemNet", "MigrateFromLocalFile: deleted " .. filename)
                end
            end
        end
        if callback then callback(ok, msg) end
    end

    if not beginPending(ACTION_MIGRATE, wrappedCallback) then
        if callback then callback(false, "Migration already pending") end
        return
    end

    local payloadJson = cjson.encode(payload)
    local evtData = VariantMap()
    evtData["payload"] = Variant(payloadJson)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_MigrateData, true, evtData)

    Logger.info("SaveSystemNet", "MigrateFromLocalFile: C2S_MigrateData sent ("
        .. #exportSlots .. " slots, "
        .. string.format("%.1fKB", #payloadJson / 1024) .. ")")
end

--- S2C_MigrateResult 处理
function SaveSystemNet_HandleMigrateResult(eventType, eventData)
    -- R2: 统一 resolvePending
    local cb = resolvePending(ACTION_MIGRATE)
    if not cb then return end  -- 晚到响应，已在 resolvePending 中记录 warn

    local ok = eventData["ok"]:GetBool()

    if ok then
        Logger.info("SaveSystemNet", "Migration successful!")
        cb(true)
    else
        local message = nil
        pcall(function() message = eventData["message"]:GetString() end)
        Logger.error("SaveSystemNet", "Migration failed: " .. tostring(message))
        cb(false, message or "Migration failed")
    end
end

return SaveSystemNet
