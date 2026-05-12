--- SavePersistence.lua — 存档写入（Save / DoSave / ExportToLocalFile）
--- 从 SaveSystem.lua 拆分而来，所有状态通过 SaveState 共享表访问

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CloudStorage = require("network.CloudStorage")
local SS = require("systems.save.SaveState")
local SaveKeys = require("systems.save.SaveKeys")
local SaveSerializer = require("systems.save.SaveSerializer")
local SaveSlots = require("systems.save.SaveSlots")
---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local FeatureFlags = require("config.FeatureFlags")

local SavePersistence = {}

-- ============================================================================
-- Save（入口 + 前置校验）
-- ============================================================================

function SavePersistence.Save(callback)
    -- 超时自动解锁：如果 saving 卡死超过 30 秒，强制解锁并计入失败
    if SS.saving then
        local elapsed = os.time() - SS._savingStartTime
        if elapsed > 30 then
            print("[SaveSystem] saving flag stuck for " .. elapsed .. "s, force unlocking")
            SS.saving = false
            SS._saveTimeoutActive = false
            -- 方案4: 计入连续失败，触发退避重试
            SS._consecutiveFailures = SS._consecutiveFailures + 1
            local retryDelay = math.min(10 * SS._consecutiveFailures, 60)
            SS._retryTimer = retryDelay
            print("[SaveSystem] 30s stuck unlock: "
                .. SS._consecutiveFailures .. " consecutive failures, retry in " .. retryDelay .. "s")
            if SS._consecutiveFailures >= 2 then
                EventBus.Emit("save_warning", { failures = SS._consecutiveFailures })
            end
            return
        else
            print("[SaveSystem] Save already in progress, skipping")
            return
        end
    end
    if not SS.loaded then
        print("[SaveSystem] Not loaded, save skipped")
        return
    end
    if not SS.activeSlot then
        print("[SaveSystem] No active slot, save skipped")
        return
    end
    -- W2: 断线期间暂停存档（避免无意义的失败重试）
    if SS._disconnected then
        print("[SaveSystem] Save skipped: disconnected")
        return
    end

    local currentLevel = GameState.player and GameState.player.level or 1
    local slot = SS.activeSlot

    -- 本地安全阀：防止内存中等级被意外清零后覆盖云端有效存档
    if SS._lastKnownCloudLevel > 10 and currentLevel < SS._lastKnownCloudLevel * 0.5 then
        print("[SaveSystem] SAVE BLOCKED (local check): current Lv." .. currentLevel
            .. " << known cloud Lv." .. SS._lastKnownCloudLevel)
        EventBus.Emit("save_blocked", {
            cloudLevel = SS._lastKnownCloudLevel,
            currentLevel = currentLevel,
        })
        return
    end

    -- 方案6: serverConn 预检 —— 网络模式下若无连接，直接快速失败
    if CloudStorage.IsNetworkMode() and not network:GetServerConnection() then
        SS._consecutiveFailures = SS._consecutiveFailures + 1
        local retryDelay = math.min(10 * SS._consecutiveFailures, 60)
        SS._retryTimer = retryDelay
        print("[SaveSystem] Save SKIPPED: no serverConn, "
            .. SS._consecutiveFailures .. " consecutive failures, retry in " .. retryDelay .. "s")
        if SS._consecutiveFailures >= 2 then
            EventBus.Emit("save_warning", { failures = SS._consecutiveFailures })
        end
        return
    end

    SS.saving = true
    SS._savingStartTime = os.time()
    -- 方案1补充: 网络模式下激活 15s 响应超时检测
    SS._saveTimeoutElapsed = 0
    SS._saveTimeoutActive = CloudStorage.IsNetworkMode()

    local epoch = SS._saveEpoch  -- 捕获当前纪元
    SavePersistence.DoSave(slot, callback, epoch)
end

-- ============================================================================
-- DoSave（单次原子 BatchSet）
-- ============================================================================

---@param slot number 槽位号
---@param callback function|nil
---@param epoch number 捕获的纪元
function SavePersistence.DoSave(slot, callback, epoch)
    -- 安全闸门：未正常加载存档时禁止写入
    if not SS.loaded then
        print("[SaveSystem] DoSave BLOCKED: data not loaded (forward version check or load failure)")
        if callback then callback(false, "存档未加载，禁止写入") end
        return
    end

    -- 纪元检查
    if epoch and epoch ~= SS._saveEpoch then
        print("[SaveSystem] DoSave: stale epoch, aborting")
        SS.saving = false
        if callback then callback(false, "存档纪元过期") end
        return
    end

    local playerData = SaveSerializer.SerializePlayer()
    -- v11 单键：equipment + backpack 全部嵌入 coreData
    local equippedData = SaveSerializer.SerializeEquipped()
    local backpackData = SaveSerializer.SerializeBackpack()
    local skillData = SaveSerializer.SerializeSkills()
    local collectionData = SaveSerializer.SerializeCollection()
    local petData = SaveSerializer.SerializePet()

    local QuestSystem = require("systems.QuestSystem")
    local questData = QuestSystem.Serialize()
    local shopData = SaveSerializer.SerializeShop()

    local titlesData = SaveSerializer.SerializeTitles()

    local ChallengeSystem = require("systems.ChallengeSystem")
    local challengeData = ChallengeSystem.Serialize()

    local SealDemonSystem = require("systems.SealDemonSystem")
    local sealDemonData = SealDemonSystem.Serialize()

    local BulletinUI = require("ui.BulletinUI")
    local bulletinData = BulletinUI.Serialize()
    local accountBulletinData = BulletinUI.SerializeAccount()

    -- 序列化BOSS击杀冷却（转换为相对剩余时间，与gameTime解耦）
    local bossKillData = {}
    for typeId, record in pairs(GameState.bossKillTimes) do
        local killTime = type(record) == "table" and record.killTime or record
        local respawnTime = type(record) == "table" and record.respawnTime or 180
        local remaining = killTime + respawnTime - GameState.gameTime
        if remaining > 0 then
            bossKillData[typeId] = { remaining = remaining, respawnTime = respawnTime }
        end
    end

    -- v11 单键架构：所有数据合并到一个 save_{slot} key
    local coreData = {
        version = SS.CURRENT_SAVE_VERSION,
        code_version = GameConfig.CODE_VERSION,
        timestamp = os.time(),
        player = playerData,
        equipment = equippedData,
        backpack = backpackData,
        skills = skillData,
        collection = collectionData,
        pet = petData,
        quests = questData,
        shop = shopData,
        titles = titlesData,
        bossKillTimes = bossKillData,
        bossKills = GameState.bossKills or 0,
        _bossKillsMigrated = true,
        bulletin = bulletinData,
        challenges = challengeData,
        sealDemon = sealDemonData,
        trialTower = (function()
            local TrialTowerSystem = require("systems.TrialTowerSystem")
            return TrialTowerSystem.Serialize()
        end)(),
        artifact = (function()
            local ArtifactSystem = require("systems.ArtifactSystem")
            return ArtifactSystem.Serialize()
        end)(),
        artifact_ch4 = (function()
            local ArtifactCh4 = require("systems.ArtifactSystem_ch4")
            return ArtifactCh4.Serialize()
        end)(),
        fortuneFruits = (function()
            local FortuneFruitSystem = require("systems.FortuneFruitSystem")
            return FortuneFruitSystem.Serialize()
        end)(),
        seaPillar = (function()
            local SeaPillarSystem = require("systems.SeaPillarSystem")
            return SeaPillarSystem.Serialize()
        end)(),
        prisonTower = (function()
            local PrisonTowerSystem = require("systems.PrisonTowerSystem")
            return PrisonTowerSystem.Serialize()
        end)(),
        warehouse = SaveSerializer.SerializeWarehouse(),
        atlas = SaveSerializer.SerializeAtlas(),
        accountCosmetics = GameState.accountCosmetics,  -- 账号级外观数据（透传给 server_main 写入独立 key）
        yaochi_wash = (function()
            local YaochiWashSystem = require("systems.YaochiWashSystem")
            return YaochiWashSystem.Serialize()
        end)(),
        event_data = (function()
            local EventSystem = require("systems.EventSystem")
            return EventSystem.Serialize()
        end)(),
        openedXianyuanChests = (function()
            local ok, XianyuanChestSystem = pcall(require, "systems.XianyuanChestSystem")
            if ok and XianyuanChestSystem then
                return XianyuanChestSystem.Serialize()
            end
            return {}
        end)(),
        -- 透传服务端写入的仙缘宝箱待选奖励（客户端不解析，原样写回防覆盖）
        pendingXianyuanRewards = SS._pendingXianyuanRewards,
    }

    -- P0-3: SAVE_PIPELINE_V2 影子校验 — 检查 coreData 字段边界
    if FeatureFlags.isEnabled("SAVE_PIPELINE_V2") then
        local SaveDTO = require("systems.save.SaveDTO")
        local boundaryOk, unknowns = SaveDTO.ValidateBoundary(coreData)
        if not boundaryOk then
            print("[SaveSystem][DTO] Boundary warning: unknown fields in coreData: "
                .. table.concat(unknowns, ", "))
        else
            print("[SaveSystem][DTO] Boundary check passed ("
                .. SaveDTO.GetSchemaFieldCount() .. " schema + "
                .. SaveDTO.GetPassthroughFieldCount() .. " passthrough)")
        end
    end

    -- v11 新 key + 旧 key（迁移用）
    local saveKey = SaveKeys.GetKey("save", slot)
    local legacy = SaveKeys.GetLegacyKeys(slot)

    -- 重组完整 saveData（供本地缓存和大小监控使用）
    local saveData = {}
    for k, v in pairs(coreData) do saveData[k] = v end
    saveData.inventory = { equipment = equippedData, backpack = backpackData }

    -- 数据大小监控（真实 JSON 序列化大小）
    local function measureSize(label, data)
        if cjson and cjson.encode then
            local ok, json = pcall(cjson.encode, data)
            if ok and json then
                local bytes = #json
                local kb = string.format("%.1f", bytes / 1024)
                print("[SaveSystem] " .. label .. ": " .. kb .. "KB (" .. bytes .. " bytes)")
                if bytes > 9 * 1024 then
                    print("[SaveSystem] WARNING: " .. label .. " approaching 10KB limit!")
                end
                return bytes
            end
        end
        return 0
    end
    local totalBytes = measureSize("saveData (" .. saveKey .. ")", coreData)

    -- S3 审计：字段级大小分解（每 10 次存档输出一次详细报告）
    SS._auditCounter = (SS._auditCounter or 0) + 1
    if SS._auditCounter % 10 == 1 and cjson and cjson.encode then
        local parts = {}
        for field, value in pairs(coreData) do
            if field ~= "version" and field ~= "timestamp" then
                local fOk, fJson = pcall(cjson.encode, value)
                if fOk and fJson then
                    parts[#parts + 1] = { field = field, bytes = #fJson }
                end
            end
        end
        table.sort(parts, function(a, b) return a.bytes > b.bytes end)
        local report = {}
        for _, p in ipairs(parts) do
            report[#report + 1] = string.format("  %s: %.1fKB", p.field, p.bytes / 1024)
        end
        print("[SaveSystem] === AUDIT: saveData field breakdown ===")
        print(table.concat(report, "\n"))
        print(string.format("[SaveSystem] === TOTAL: %.1fKB (single key) ===",
            totalBytes / 1024))
    end

    -- 图鉴退化检测：如果当前图鉴数量比上次已知数量大幅减少，用缓存替代
    local collectionCount = #collectionData
    local prevCount = SS._lastKnownCollectionCount or 0
    if prevCount > 2 and collectionCount < prevCount * 0.5 then
        print("[SaveSystem] COLLECTION DEGRADATION DETECTED! prev=" .. prevCount
            .. " -> current=" .. collectionCount .. " (>50% loss)")
        if SS._cachedCollectionData and #SS._cachedCollectionData >= prevCount then
            saveData.collection = SS._cachedCollectionData
            print("[SaveSystem] Collection replaced with cached data (" .. #SS._cachedCollectionData .. " entries)")
        else
            print("[SaveSystem] WARNING: no cached collection data, saving degraded data as-is")
        end
    else
        SS._lastKnownCollectionCount = collectionCount
        if collectionCount > 0 then
            local cached = {}
            for i, v in ipairs(collectionData) do cached[i] = v end
            SS._cachedCollectionData = cached
        end
    end

    -- 构建 slots_index 更新（使用缓存的角色名，无需网络读取）
    local charName = SS._cachedCharName or SS.DEFAULT_CHARACTER_NAME
    local updatedIndex = SS._cachedSlotsIndex

    -- 在发送 BatchSet 之前就缓存 saveData（不依赖异步回调）
    SS._lastSavedData = SS._lastSavedData or {}
    SS._lastSavedData[slot] = saveData

    -- v11 迁移前快照：首次 Save 时将旧格式原始数据写入 premigrate key
    local needPreMigrate = false
    SS._preMigrateWritten = SS._preMigrateWritten or {}
    if not SS._preMigrateWritten[slot]
        and SS._rawOldData
        and SS._rawOldData[slot] then
        needPreMigrate = true
    end

    --- 向 batch 中添加迁移清理条目
    local function addMigrationOps(batch)
        batch:Delete(legacy.save)
        batch:Delete(legacy.bag1)
        batch:Delete(legacy.bag2)
        if needPreMigrate then
            local raw = SS._rawOldData[slot]
            batch:Set(SaveKeys.GetKey("premigrate", slot), raw.coreData)
            batch:Set("premigrate_bag1_" .. slot, raw.bag1)
            batch:Set("premigrate_bag2_" .. slot, raw.bag2)
            print("[SaveSystem] Pre-migrate snapshot added to batch for slot " .. slot)
        end
        return batch
    end

    --- 首次迁移完成后的清理
    local function onMigrateComplete()
        if needPreMigrate then
            SS._preMigrateWritten[slot] = true
            SS._rawOldData[slot] = nil
            print("[SaveSystem] Pre-migrate snapshot committed for slot " .. slot)
        end
    end

    -- 纵深防御：缓存为 nil 时只写 save_{slot}，不触碰 slots_index 和排行
    if not updatedIndex then
        print("[SaveSystem] WARNING: _cachedSlotsIndex is nil! Saving data only (no index/rank update)")

        local batch = CloudStorage.BatchSet()
            :Set(saveKey, coreData)
        addMigrationOps(batch)

        SS._saveCount = SS._saveCount + 1
        local isCheckpoint = SS._saveCount == 1
            or SS._saveCount % SS.CHECKPOINT_INTERVAL == 0

        batch:Save("存档(仅数据)", {
            ok = function()
                if epoch and epoch ~= SS._saveEpoch then
                    print("[SaveSystem] Save ok (data only): stale epoch, discarding")
                    SS.saving = false

                    if callback then callback(false, "存档纪元过期") end
                    return
                end
                SS.saving = false
                SS._saveTimeoutActive = false
                SS._consecutiveFailures = 0
                SS._retryTimer = nil
                SS._lastKnownCloudLevel = playerData.level or 1
                SS._lastSaveTime = os.clock()
                SS.saveTimer = 0  -- P0优化：成功保存后重置自动存档计时器，以"距上次成功保存"为基准

                EventBus.Emit("save_warning_clear")
                onMigrateComplete()
                print("[SaveSystem] Slot " .. slot .. " saved (data only, no index) [v11]")
                EventBus.Emit("game_saved")
                if callback then callback(true) end

                if isCheckpoint then
                    SavePersistence.ExportToLocalFile(slot, coreData, nil)
                    local prevKey = SaveKeys.GetKey("prev", slot)
                    CloudStorage.BatchSet()
                        :Set(prevKey, coreData)
                        :Delete(legacy.prev)
                        :Delete(legacy.prevBag1)
                        :Delete(legacy.prevBag2)
                        :Save("checkpoint(仅数据)", {
                            ok = function()
                                print("[SaveSystem] Checkpoint written (data only): " .. prevKey .. " [v11]")
                            end,
                            error = function(code, reason)
                                print("[SaveSystem] Checkpoint write failed (data only): " .. tostring(reason))
                            end,
                        })
                end
            end,
            error = function(code, reason)
                if epoch and epoch ~= SS._saveEpoch then
                    print("[SaveSystem] Save error (data only): stale epoch, ignoring")
                    SS.saving = false

                    if callback then callback(false, "存档纪元过期") end
                    return
                end
                SS.saving = false
                SS._saveTimeoutActive = false
                SS._consecutiveFailures = SS._consecutiveFailures + 1
                local retryDelay = math.min(10 * SS._consecutiveFailures, 60)
                SS._retryTimer = retryDelay

                print("[SaveSystem] Save FAILED (data only): " .. tostring(reason))
                if SS._consecutiveFailures >= 2 then
                    EventBus.Emit("save_warning", { failures = SS._consecutiveFailures })
                end
                if callback then callback(false, reason) end
            end,
        })
        return
    end

    updatedIndex.slots = updatedIndex.slots or {}
    updatedIndex.slots[slot] = SaveSlots.BuildSlotSummary(slot, charName, playerData)

    -- 构建排行数据
    local realmCfg = GameConfig.REALMS[playerData.realm or "mortal"]
    local realmOrder = realmCfg and realmCfg.order or 0
    local rankScore = realmOrder * 1000 + (playerData.level or 1)
    local rankScoreKey = "rank_score_" .. slot
    local rankInfoKey = "rank_info_" .. slot

    local batch = CloudStorage.BatchSet()
        :Set(saveKey, coreData)
        :Set("slots_index", updatedIndex)
        :SetInt("player_level", playerData.level or 1)
        :Set("account_bulletin", accountBulletinData)
    addMigrationOps(batch)

    -- 排行榜（等级 > 5 时写入）
    local bossKillsCount = GameState.bossKills or 0
    local rankTimeKey = "rank_time_" .. slot
    if (playerData.level or 1) > 5 then
        batch:SetInt(rankScoreKey, rankScore)
        batch:SetInt("boss_kills_" .. slot, bossKillsCount)
        local lastScore = GameState.lastRankScore or 0
        if rankScore > lastScore then
            local achieveTime = os.time()
            batch:SetInt(rankTimeKey, achieveTime)
            GameState.lastRankScore = rankScore
            GameState.lastRankTime = achieveTime
        end
        batch:Set(rankInfoKey, {
            name = charName,
            realm = playerData.realm or "mortal",
            level = playerData.level or 1,
            bossKills = bossKillsCount,
            classId = playerData.classId,
        })
    end

    SS._saveCount = SS._saveCount + 1
    local isCheckpoint = SS._saveCount == 1
        or SS._saveCount % SS.CHECKPOINT_INTERVAL == 0

    batch:Save("存档", {
        ok = function()
            if epoch and epoch ~= SS._saveEpoch then
                print("[SaveSystem] Save ok: stale epoch, discarding")
                SS.saving = false

                if callback then callback(false, "存档纪元过期") end
                return
            end
            SS.saving = false
            SS._saveTimeoutActive = false
            SS._consecutiveFailures = 0
            SS._retryTimer = nil
            SS._lastSaveTime = os.clock()
            SS.saveTimer = 0  -- P0优化：成功保存后重置自动存档计时器，以"距上次成功保存"为基准

            EventBus.Emit("save_warning_clear")

            SS._cachedSlotsIndex = updatedIndex
            SS._lastKnownCloudLevel = playerData.level or 1
            onMigrateComplete()

            local checkpointMsg = isCheckpoint and " [+checkpoint]" or ""
            print("[SaveSystem] Slot " .. slot .. " saved! [v11]" .. checkpointMsg)
            EventBus.Emit("game_saved")
            if callback then callback(true) end

            if isCheckpoint then
                SavePersistence.ExportToLocalFile(slot, coreData, updatedIndex)
                local prevKey = SaveKeys.GetKey("prev", slot)
                CloudStorage.BatchSet()
                    :Set(prevKey, coreData)
                    :Delete(legacy.prev)
                    :Delete(legacy.prevBag1)
                    :Delete(legacy.prevBag2)
                    :Save("checkpoint", {
                        ok = function()
                            print("[SaveSystem] Checkpoint written: " .. prevKey .. " [v11]")
                        end,
                        error = function(code, reason)
                            print("[SaveSystem] Checkpoint write failed: " .. tostring(reason))
                        end,
                    })
            end
        end,
        error = function(code, reason)
            if epoch and epoch ~= SS._saveEpoch then
                print("[SaveSystem] Save error: stale epoch, ignoring")
                SS.saving = false

                if callback then callback(false, "存档纪元过期") end
                return
            end
            SS.saving = false
            SS._saveTimeoutActive = false
            SS._consecutiveFailures = SS._consecutiveFailures + 1

            local retryDelay = math.min(10 * SS._consecutiveFailures, 60)
            SS._retryTimer = retryDelay

            print("[SaveSystem] Save FAILED (" .. SS._consecutiveFailures
                .. " consecutive): " .. tostring(code) .. " - " .. tostring(reason)
                .. ", retry in " .. retryDelay .. "s")
            if SS._consecutiveFailures >= 2 then
                EventBus.Emit("save_warning", { failures = SS._consecutiveFailures })
            end

            if callback then callback(false, reason) end
        end,
    })
end

-- ============================================================================
-- ExportToLocalFile（本地存档导出）
-- ============================================================================

---@param slot number 槽位号
---@param coreData table 完整存档数据（含 equipment + backpack）
---@param slotsIndex table|nil 槽位索引（可能为 nil）
function SavePersistence.ExportToLocalFile(slot, coreData, slotsIndex)
    local exportData = {
        export_version = 2,
        export_time = os.time(),
        slot = slot,
        save_data = coreData,
        slots_index = slotsIndex,
    }
    local ok, json = pcall(cjson.encode, exportData)
    if not ok then
        print("[SaveSystem] Export encode FAILED: " .. tostring(json))
        return
    end
    local f = File("save_export_" .. slot .. ".json", FILE_WRITE)
    if f:IsOpen() then
        f:WriteString(json)
        f:Close()
        print("[SaveSystem] Export OK: slot " .. slot .. " (" .. #json .. " bytes)")

        local platform = GetPlatform()
        if platform ~= "Web" and platform ~= "Windows" then
            -- P2-Q-4: nil 检查，网络模式下 clientCloud 可能不可用
            if clientCloud and clientCloud.SetInt then
                clientCloud:SetInt("migration_backup_done", 1, {
                    ok = function()
                        print("[SaveSystem] migration_backup_done flag set in cloud")
                    end,
                    ng = function()
                        print("[SaveSystem] migration_backup_done flag set FAILED (non-critical)")
                    end,
                })
            end
        end
    else
        print("[SaveSystem] Export FAILED: cannot open file for slot " .. slot)
    end
end

return SavePersistence
