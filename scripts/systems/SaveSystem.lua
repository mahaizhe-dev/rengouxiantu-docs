-- ============================================================================
-- SaveSystem.lua - 云存档系统（瘦编排器）
-- S2 重构：所有实现拆分到 systems/save/ 子模块，此文件仅保留 Init/Update
-- 并将子模块函数 re-export 到 SaveSystem 表上，确保外部零修改
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CloudStorage = require("network.CloudStorage")

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
    SaveSystem._connCheckTimer = 0
    SaveSystem._lastConnState = true
    SaveSystem._disconnected = false
    SaveSystem._dirty = false
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
        end
    end
    SaveSystem._onConnLost = function()
        SaveSystem._disconnected = true
        print("[SaveSystem] Connection lost — auto-save paused")
    end
    SaveSystem._onConnRestored = function()
        SaveSystem._disconnected = false
        print("[SaveSystem] Connection restored — triggering immediate save")
        if SaveSystem.loaded and SaveSystem.activeSlot then
            SaveSystem.Save()
        end
    end

    EventBus.On("save_request", SaveSystem._onSaveRequest)
    EventBus.On("connection_lost", SaveSystem._onConnLost)
    EventBus.On("connection_restored", SaveSystem._onConnRestored)

    print("[SaveSystem] Initialized (epoch=" .. SaveSystem._saveEpoch .. ")")
end

-- ============================================================================
-- Update（保留在编排器：涉及定时器 + EventBus + Save 调度）
-- ============================================================================

function SaveSystem.Update(dt)
    if not SaveSystem.loaded then return end
    if not SaveSystem.activeSlot then return end

    -- W1: 连接状态轮询（每 5s 检测一次，仅网络模式）
    if CloudStorage.IsNetworkMode() then
        SaveSystem._connCheckTimer = SaveSystem._connCheckTimer + dt
        if SaveSystem._connCheckTimer >= 5 then
            SaveSystem._connCheckTimer = 0
            local connected = network:GetServerConnection() ~= nil
            if connected ~= SaveSystem._lastConnState then
                SaveSystem._lastConnState = connected
                if not connected then
                    EventBus.Emit("connection_lost")
                else
                    EventBus.Emit("connection_restored")
                end
            end
        end
    end

    -- 存档响应超时检测（15s 无响应视为失败）
    if SaveSystem._saveTimeoutActive and SaveSystem.saving then
        SaveSystem._saveTimeoutElapsed = SaveSystem._saveTimeoutElapsed + dt
        if SaveSystem._saveTimeoutElapsed >= 15 then
            SaveSystem._saveTimeoutActive = false
            SaveSystem.saving = false
            SaveSystem._consecutiveFailures = SaveSystem._consecutiveFailures + 1
            local retryDelay = math.min(10 * SaveSystem._consecutiveFailures, 60)
            SaveSystem._retryTimer = retryDelay
            print("[SaveSystem] Save TIMEOUT (no response in 15s), "
                .. SaveSystem._consecutiveFailures .. " consecutive failures, retry in " .. retryDelay .. "s")
            if SaveSystem._consecutiveFailures >= 2 then
                EventBus.Emit("save_warning", { failures = SaveSystem._consecutiveFailures })
            end
            return
        end
    end

    -- 失败重试计时
    if SaveSystem._retryTimer then
        SaveSystem._retryTimer = SaveSystem._retryTimer - dt
        if SaveSystem._retryTimer <= 0 then
            SaveSystem._retryTimer = nil
            print("[SaveSystem] Retrying save after failure...")
            SaveSystem.Save()
            return
        end
    end

    -- 防抖刷写：脏标记存在且不在存档中时，检查距上次存档的间隔
    if SaveSystem._dirty and not SaveSystem.saving then
        local elapsed = os.clock() - SaveSystem._lastSaveTime
        if elapsed >= SaveSystem.SAVE_DEBOUNCE_INTERVAL then
            SaveSystem._dirty = false
            SaveSystem.Save()
        end
    end

    SaveSystem.saveTimer = SaveSystem.saveTimer + dt
    if SaveSystem.saveTimer >= SaveSystem.AUTO_SAVE_INTERVAL then
        SaveSystem.saveTimer = 0
        -- 挑战副本进行中时抑制自动存档，防止中间状态（completed=true 但未领奖）被持久化
        -- 这样强退/重启时 completed 不会被自动存档偷跑写入，玩家必须重新挑战
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
SaveSystem.Save             = SavePersistence.Save
SaveSystem.DoSave           = SavePersistence.DoSave
SaveSystem.ExportToLocalFile = SavePersistence.ExportToLocalFile

-- SaveLoader
SaveSystem.Load             = SaveLoader.Load
SaveSystem.ProcessLoadedData = SaveLoader.ProcessLoadedData

-- SaveRecovery
SaveSystem.TryRecoverSave   = SaveRecovery.TryRecoverSave

return SaveSystem
