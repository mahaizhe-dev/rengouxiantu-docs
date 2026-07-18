-- ============================================================================
-- SaveSystem.lua - 云存档系统（瘦编排器）
-- S2 重构：所有实现拆分到 systems/save/ 子模块，此文件仅保留 Init/Update
-- 并将子模块函数 re-export 到 SaveSystem 表上，确保外部零修改
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CloudStorage = require("network.CloudStorage")
local NetworkStatus = require("network.NetworkStatus")

-- SaveState 返回的共享表 = SaveSystem 表本身
-- 所有子模块通过 SS 引用同一张表来读写运行时状态
local SaveSystem = require("systems.save.SaveState")

-- 加载所有子模块
local SaveKeys = require("systems.save.SaveKeys")
local SaveMigrations = require("systems.save.SaveMigrations")
local SaveSerializer = require("systems.save.SaveSerializer")
local SaveSlots = require("systems.save.SaveSlots")
local SavePersistence = require("systems.save.SavePersistence")
local SaveLoader = require("systems.save.SaveLoader")
local SaveRecovery = require("systems.save.SaveRecovery")

-- ============================================================================
-- Init（保留在编排器：涉及 EventBus 订阅 + 状态重置）
-- ============================================================================

function SaveSystem.Init()
    SaveSystem.saveTimer = 0
    SaveSystem.loaded = false
    SaveSystem.saving = false
    SaveSystem.activeSlot = nil
    SaveSystem._saveCount = 0
    SaveSystem._saveEpoch = (SaveSystem._saveEpoch or 0) + 1
    SaveSystem._savingStartTime = 0
    SaveSystem._lastKnownCloudLevel = 0
    SaveSystem._retryTimer = nil
    SaveSystem._consecutiveFailures = 0
    SaveSystem._saveTimeoutElapsed = 0
    SaveSystem._saveTimeoutActive = false
    SaveSystem._activeSaveCallback = nil
    SaveSystem._connCheckTimer = 0
    SaveSystem._lastConnState = true
    SaveSystem._disconnected = false
    NetworkStatus.Reset()
    SaveSystem._dirty = false
    SaveSystem._dirtySinceFlush = false  -- WP-02: 飞行期间是否有新脏标记
    SaveSystem._lastSaveTime = 0
    -- 注意：_cachedSlotsIndex 和 _cachedCharName 由 CharacterSelectScreen 设置，
    -- 跨越 Init 生命周期，此处不清除。

    -- 先移除旧监听（Init 可能被多次调用，避免累积注册）
    if SaveSystem._onSaveRequest then EventBus.Off("save_request", SaveSystem._onSaveRequest) end
    if SaveSystem._onConnLost then EventBus.Off("connection_lost", SaveSystem._onConnLost) end
    if SaveSystem._onConnRestored then EventBus.Off("connection_restored", SaveSystem._onConnRestored) end

    SaveSystem._onSaveRequest = function()
        if SaveSystem.loaded and SaveSystem.activeSlot then
            SaveSystem._dirty = true
            -- WP-02: 若存档正在飞行中，标记"飞行期间有新变更"，ok 回调时不清 dirty
            if SaveSystem.saving then
                SaveSystem._dirtySinceFlush = true
            end
        end
    end
    SaveSystem._onConnLost = function()
        SaveSystem._disconnected = true
        print("[SaveSystem] Connection lost — auto-save paused")
        -- 保存回调归 CloudStorage requestId 管理；断线时立即失败，释放玩法事务锁。
        pcall(function()
            CloudStorage.ExpirePendingCallbacks("save", "connection_lost")
        end)
        -- P0-fix: 断线时清除所有加载 pending，解除 single-flight 死锁
        pcall(function() require("network.SaveSystemNet").ClearAllPending() end)
    end
    SaveSystem._onConnRestored = function()
        SaveSystem._disconnected = false
        -- P0优化：不再立即 Save()，改为标记 dirty，由防抖流程统一调度
        -- 避免大量玩家同时重连时的 save 风暴
        print("[SaveSystem] Connection restored — marking dirty (deferred save)")
        if SaveSystem.loaded and SaveSystem.activeSlot then
            SaveSystem._dirty = true
        end
    end

    EventBus.On("save_request", SaveSystem._onSaveRequest)
    EventBus.On("connection_lost", SaveSystem._onConnLost)
    EventBus.On("connection_restored", SaveSystem._onConnRestored)

    print("[SaveSystem] Initialized (epoch=" .. SaveSystem._saveEpoch .. ")")
end

--- 在网络层没有可结算 pending 的极端情况下，确定性结束当前保存。
--- 递增 attemptId 可阻止晚到回包再次修改保存状态或重复调用业务回调。
---@param reason string
---@return boolean failed
function SaveSystem.FailActiveSave(reason)
    if not SaveSystem.saving and not SaveSystem._activeSaveCallback then
        return false
    end

    SaveSystem._saveAttemptId = (SaveSystem._saveAttemptId or 0) + 1
    SaveSystem.saving = false
    SaveSystem._saveTimeoutActive = false
    SaveSystem._consecutiveFailures = SaveSystem._consecutiveFailures + 1
    local retryDelay = math.min(10 * SaveSystem._consecutiveFailures, 60)
    SaveSystem._retryTimer = retryDelay

    local callback = SaveSystem._activeSaveCallback
    SaveSystem._activeSaveCallback = nil
    print("[SaveSystem] Save aborted: " .. tostring(reason)
        .. ", retry in " .. retryDelay .. "s")
    if SaveSystem._consecutiveFailures >= 2 then
        EventBus.Emit("save_warning", {
            failures = SaveSystem._consecutiveFailures,
            reason = reason,
        })
    end
    if callback then
        callback(false, reason)
    end
    return true
end

-- ============================================================================
-- UpdateCritical（WP-01: 始终调用，不受玩法模式跳过）
-- 职责：网络连接采样、存档超时检测、失败重试计时
-- 这些必须在任何模式下持续运行，否则断线感知和重试在副本中完全停摆
-- ============================================================================

function SaveSystem.UpdateCritical(dt)
    -- P0-fix: pending 超时清扫必须在 loaded 检查之前运行
    -- （FetchSlots/Load 的 pending 发生在 loaded=true 之前）
    if CloudStorage.IsNetworkMode() then
        pcall(function() require("network.SaveSystemNet").Tick() end)
    end

    if not SaveSystem.loaded then return end
    if not SaveSystem.activeSlot then return end

    -- 连接状态轮询（每 3s 采样，N1: 连续失败阈值+恢复滞回）
    if CloudStorage.IsNetworkMode() then
        SaveSystem._connCheckTimer = SaveSystem._connCheckTimer + dt
        if SaveSystem._connCheckTimer >= 3 then
            local elapsed = SaveSystem._connCheckTimer
            SaveSystem._connCheckTimer = 0
            local connected = network:GetServerConnection() ~= nil
            local event = NetworkStatus.RecordSample(connected, elapsed)
            if event then
                EventBus.Emit(event)
                if event == "connection_lost" then
                    SaveSystem._lastConnState = false
                elseif event == "connection_restored" then
                    SaveSystem._lastConnState = true
                end
            end
        end
    end

    -- 存档响应超时兜底。正常超时由 CloudStorage 先按 requestId 结算并调用业务回调；
    -- 此处晚一个 Tick 周期，只处理网络层 pending 异常丢失的极端情况。
    if SaveSystem._saveTimeoutActive and SaveSystem.saving then
        SaveSystem._saveTimeoutElapsed = SaveSystem._saveTimeoutElapsed + dt
        if SaveSystem._saveTimeoutElapsed >= SaveSystem.SAVE_RESPONSE_TIMEOUT then
            local expired = CloudStorage.ExpirePendingCallbacks(
                "save",
                "save_response_timeout")
            if expired == 0 and SaveSystem.saving then
                SaveSystem.FailActiveSave("save_response_timeout")
            end
            print("[SaveSystem] Save TIMEOUT fallback after "
                .. SaveSystem.SAVE_RESPONSE_TIMEOUT .. "s, expired callbacks=" .. expired)
            pcall(function() require("network.NetDiagClient").RecordSaveTimeout() end)
        end
    end

    -- 失败重试计时
    if SaveSystem._retryTimer then
        SaveSystem._retryTimer = SaveSystem._retryTimer - dt
        if SaveSystem._retryTimer <= 0 then
            SaveSystem._retryTimer = nil
            print("[SaveSystem] Retrying save after failure...")
            SaveSystem.Save()
        end
    end

    -- P1 阶段1：驱动心跳发送（被动观测，不改行为）
    if CloudStorage.IsNetworkMode() then
        NetworkStatus.HeartbeatTick(dt)
        -- C+: 驱动诊断上报
        pcall(function() require("network.NetDiagClient").Tick(dt) end)
    end
end

-- ============================================================================
-- Update（自动保存调度，副本/挑战中可跳过）
-- 职责：dirty 防抖刷写 + 定时自动保存
-- ============================================================================

function SaveSystem.Update(dt)
    if not SaveSystem.loaded then return end
    if not SaveSystem.activeSlot then return end

    -- WP-01: 如果重试计时器正在等待，不在此处触发额外保存（让 UpdateCritical 的重试处理）
    if SaveSystem._retryTimer then return end

    -- WP-02 防抖刷写：脏标记存在且不在存档中时，检查距上次存档的间隔
    -- _dirty 不再在此处清除 —— 仅在 ok 回调中确认落盘后才清
    if SaveSystem._dirty and not SaveSystem.saving then
        local elapsed = time.elapsedTime - SaveSystem._lastSaveTime
        if elapsed >= SaveSystem.SAVE_DEBOUNCE_INTERVAL then
            SaveSystem._dirtySinceFlush = false  -- WP-02: 重置飞行期间脏标记
            SaveSystem.Save()
            return
        end
    end

    SaveSystem.saveTimer = SaveSystem.saveTimer + dt
    if SaveSystem.saveTimer >= SaveSystem.AUTO_SAVE_INTERVAL then
        SaveSystem.saveTimer = 0
        local ChallengeSystem = require("systems.ChallengeSystem")
        if ChallengeSystem.active then
            print("[SaveSystem] AutoSave skipped: challenge in progress")
        else
            SaveSystem.Save()
        end
    end
end

-- ============================================================================
-- Re-export：将子模块函数挂载到 SaveSystem 表上
-- 外部代码 require("systems.SaveSystem").Save() 继续可用
-- ============================================================================

-- SaveKeys
SaveSystem.GetKey          = SaveKeys.GetKey
SaveSystem.GetLegacyKeys   = SaveKeys.GetLegacyKeys
SaveSystem.GetSaveKey      = SaveKeys.GetSaveKey
SaveSystem.GetBackupKey    = SaveKeys.GetBackupKey
SaveSystem.GetPrevKey      = SaveKeys.GetPrevKey
SaveSystem.GetBag1Key      = SaveKeys.GetBag1Key
SaveSystem.GetBag2Key      = SaveKeys.GetBag2Key
SaveSystem.GetPrevBag1Key  = SaveKeys.GetPrevBag1Key
SaveSystem.GetPrevBag2Key  = SaveKeys.GetPrevBag2Key
SaveSystem.GetLoginBag1Key = SaveKeys.GetLoginBag1Key
SaveSystem.GetLoginBag2Key = SaveKeys.GetLoginBag2Key
SaveSystem.GetBakBag1Key   = SaveKeys.GetBakBag1Key
SaveSystem.GetBakBag2Key   = SaveKeys.GetBakBag2Key

-- SaveMigrations
SaveSystem.MigrateSaveData    = SaveMigrations.MigrateSaveData
SaveSystem.ValidateLoadedState = SaveMigrations.ValidateLoadedState

-- SaveSerializer
SaveSystem.SerializePlayer      = SaveSerializer.SerializePlayer
SaveSystem.DeserializePlayer    = SaveSerializer.DeserializePlayer
SaveSystem.SerializeEquipped    = SaveSerializer.SerializeEquipped
SaveSystem.SerializeBackpack    = SaveSerializer.SerializeBackpack
SaveSystem.SerializeInventory   = SaveSerializer.SerializeInventory
SaveSystem.SerializeItemFull    = SaveSerializer.SerializeItemFull
SaveSystem.DeserializeInventory = SaveSerializer.DeserializeInventory
SaveSystem.SerializePet         = SaveSerializer.SerializePet
SaveSystem.DeserializePet       = SaveSerializer.DeserializePet
SaveSystem.SerializeSkills      = SaveSerializer.SerializeSkills
SaveSystem.DeserializeSkills    = SaveSerializer.DeserializeSkills
SaveSystem.SerializeCollection  = SaveSerializer.SerializeCollection
SaveSystem.DeserializeCollection = SaveSerializer.DeserializeCollection
SaveSystem.SerializeTitles      = SaveSerializer.SerializeTitles
SaveSystem.DeserializeTitles    = SaveSerializer.DeserializeTitles
SaveSystem.SerializeShop        = SaveSerializer.SerializeShop
SaveSystem.DeserializeShop      = SaveSerializer.DeserializeShop

-- SaveSlots
SaveSystem.FetchSlots       = SaveSlots.FetchSlots
SaveSystem.BuildSlotSummary = SaveSlots.BuildSlotSummary
SaveSystem.CreateCharacter  = SaveSlots.CreateCharacter
SaveSystem.DeleteCharacter  = SaveSlots.DeleteCharacter

-- SavePersistence
---@diagnostic disable-next-line: assign-type-mismatch
SaveSystem.Save             = SavePersistence.Save
---@diagnostic disable-next-line: assign-type-mismatch
SaveSystem.DoSave           = SavePersistence.DoSave
SaveSystem.ExportToLocalFile = SavePersistence.ExportToLocalFile

-- SaveLoader
SaveSystem.Load             = SaveLoader.Load
SaveSystem.ProcessLoadedData = SaveLoader.ProcessLoadedData

-- SaveRecovery
SaveSystem.TryRecoverSave   = SaveRecovery.TryRecoverSave

-- ── 拆分后遗漏：CheckSaveExists（LoginScreen 依赖）──────────────────────────
--- 检查云端是否存在任何有效存档（回调方式）
---@param callback fun(hasSave: boolean|nil, errorReason: string|nil)
function SaveSystem.CheckSaveExists(callback)
    SaveSystem.FetchSlots(function(slotsIndex, err)
        if err then
            callback(nil, err)
            return
        end
        if not slotsIndex or not slotsIndex.slots then
            callback(false, nil)
            return
        end
        for slot = 1, SaveSystem.MAX_SLOTS do
            if slotsIndex.slots[slot] and not slotsIndex.slots[slot].dataLost then
                callback(true, nil)
                return
            end
        end
        callback(false, nil)
    end)
end

-- ============================================================================
-- P0-1: 保存状态只读查询（供黑市 UI / GM 诊断使用）
-- ============================================================================

---@return table status 保存系统当前状态快照
function SaveSystem.GetSaveStatus()
    return {
        loaded              = SaveSystem.loaded == true,
        activeSlot          = SaveSystem.activeSlot,
        dirty               = SaveSystem._dirty == true,
        dirtySinceFlush     = SaveSystem._dirtySinceFlush == true,
        saving              = SaveSystem.saving == true,
        retryTimer          = SaveSystem._retryTimer,
        disconnected        = SaveSystem._disconnected == true,
        consecutiveFailures = SaveSystem._consecutiveFailures or 0,
        lastSaveTime        = SaveSystem._lastSaveTime or 0,
        hasServerConn       = (not CloudStorage.IsNetworkMode()) or (network:GetServerConnection() ~= nil),
    }
end

-- ============================================================================
-- P0-2: 统一立即保存请求入口（不发 game_saved、不清 dirty）
-- ============================================================================

---@param reason string 调用原因（用于日志）
---@return boolean ok 是否成功启动保存
---@return string reason 原因码
---@return table status 当前状态快照
function SaveSystem.RequestImmediateSave(reason)
    -- 确保 dirty 标记存在（即使已有 save_request 置脏，这里兜底）
    if SaveSystem.loaded and SaveSystem.activeSlot then
        SaveSystem._dirty = true
    end

    local status = SaveSystem.GetSaveStatus()

    if not status.loaded then
        return false, "not_loaded", status
    end
    if not status.activeSlot then
        return false, "no_active_slot", status
    end
    if status.saving then
        return false, "saving", status
    end
    if status.retryTimer then
        return false, "retrying", status
    end
    if status.disconnected then
        return false, "disconnected", status
    end
    if not status.hasServerConn then
        return false, "no_server_conn", status
    end

    print("[SaveSystem] RequestImmediateSave: " .. tostring(reason))
    SaveSystem.Save()
    return true, "started", SaveSystem.GetSaveStatus()
end

return SaveSystem
