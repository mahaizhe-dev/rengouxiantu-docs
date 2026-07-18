-- ============================================================================
-- SaveWriteService.lua — SaveGame 服务壳
--
-- R3 等价拆分第一阶段：从 server_main.lua 原位平移 HandleSaveGame 逻辑。
-- 本模块仅负责 SaveGame 主链，不涉及黑市重写。
--
-- ※ 黑市相关（BM handler / WAL / 交易历史 / 兑换 / 自动收购）
--   不在本 service 范围内。SaveGame 主链与黑市完全独立——
--   BM-01A 的依赖链是 save_request → C2S_SaveGame → HandleSaveGame → batch:Save("存档")
--   → S2C_SaveResult ok=true，本次拆壳后该链路语义不变。
--
-- 变更历史：
--   2026-05-13  R3 创建 — 等价平移，不重写业务
-- ============================================================================

local SaveWriteService = {}

local GameConfig       = require("config.GameConfig")
local SealDemonConfig  = require("config.SealDemonConfig")
local SeaPillarConfig  = require("config.SeaPillarConfig")
local LiangjieStoneConfig = require("config.LiangjieStoneConfig")
local SwordPoolConfig  = require("config.SwordPoolConfig")
local PetSkillData     = require("config.PetSkillData")
local SaveProtocol     = require("network.SaveProtocol")
local SavePayloadCodec = require("network.SavePayloadCodec")
local SaveBackupService = require("network.SaveBackupService")
local Session          = require("network.ServerSession")
local AccountImmortalBodiesService = require("network.AccountImmortalBodiesService")
local RankHandler      = require("network.RankHandler")
local AdminPenaltyControl = require("network.AdminPenaltyControl")
local Logger           = require("utils.Logger")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

---@class SaveEventDataField
---@field GetString fun(): string
---@field GetInt fun(): integer

---@alias SaveEventDataLike userdata|table<string, SaveEventDataField>

-- ============================================================================
-- 本地工具
-- ============================================================================

local SafeSend            = Session.SafeSend
local NormalizeSlotsIndex = Session.NormalizeSlotsIndex
local IsSlotLocked        = Session.IsSlotLocked
local AcquireSlotLock     = Session.AcquireSlotLock
local ReleaseSlotLock     = Session.ReleaseSlotLock

local function SendResult(connection, eventName, success, message, requestId)
    local data = VariantMap()
    data["ok"] = Variant(success)
    if message then
        data["message"] = Variant(message)
    end
    if requestId then
        data["requestId"] = Variant(requestId)
    end
    SafeSend(connection, eventName, data)
end

local function TreasureSessionId(saveData)
    return saveData and saveData.player
        and tostring(saveData.player.treasureSessionId or "") or ""
end

local function TreasureRevision(saveData)
    return saveData and saveData.player
        and math.max(0, math.floor(tonumber(saveData.player.treasureRevision) or 0)) or 0
end

function SaveWriteService._ValidateTreasureSession(oldSave, incomingSave)
    local oldSession = TreasureSessionId(oldSave)
    local incomingSession = TreasureSessionId(incomingSave)
    local oldRevision = TreasureRevision(oldSave)
    local incomingRevision = TreasureRevision(incomingSave)
    return oldSession == incomingSession and oldRevision == incomingRevision,
        oldSession, incomingSession, oldRevision, incomingRevision
end

local function NormalizeJieshiProgress(raw, includeCooldown)
    raw = type(raw) == "table" and raw or {}
    local rawGrids = type(raw.activatedGrids) == "table"
        and raw.activatedGrids or {}
    local grids = {}
    local allActive = true
    for i = 1, 9 do
        grids[i] = rawGrids[i] == true
        if not grids[i] then allActive = false end
    end

    -- 第六章神器永久状态只接受“九格全满 → Boss首胜 → 被动解锁”的单向关系。
    local bossDefeated = allActive and raw.bossDefeated == true
    local normalized = {
        version = 1,
        activatedGrids = grids,
        bossDefeated = bossDefeated,
        passiveUnlocked = bossDefeated and raw.passiveUnlocked == true,
    }
    if includeCooldown then
        local readyAt = tonumber(raw.rescueReadyAt) or 0
        if readyAt ~= readyAt or readyAt == math.huge or readyAt == -math.huge then
            readyAt = 0
        end
        readyAt = math.max(0, math.floor(readyAt))
        local now = os.time()
        normalized.rescueReadyAt = math.min(readyAt, now + 185)
    end
    return normalized
end

-- ============================================================================
-- SaveGame 主入口
--
-- 分区说明（R3 §8.3）：
--   [主存档正文]     save_{slot} / slots_index 写入 + 旧格式清理
--   [账号级旁路]     account_bulletin / account_atlas / account_cosmetics
--   [修仙榜旁路]     rank2_score/kills/time (SetInt) + rank2_info (batch Set)
--   [仙人榜旁路]     xianren_score/kills/time (SetInt) + xianren_info (batch Set)
--   [试炼旁路]       trial_floor (SetInt) + trial_info (batch Set)
--   [镇狱塔旁路]     prison_floor (SetInt) + prison_info (batch Set)
--   [版本守卫]       player_level / _code_ver (SetInt)
--   [B4-S2 硬校验]   V1~V6 服务端权威修正
--
-- ※ 黑市相关（BM handler / WAL / 交易历史 / 兑换 / 自动收购）
--   不在本 service 范围内。SaveGame 写入的 save_{slot} key 与 BM 的
--   WriteSaveBack 共享同一个 key，但本次拆壳不改变写入语义。
-- ============================================================================

--- Execute: 等价于原 HandleSaveGame 函数体
---@param connection userdata    引擎 Connection 对象
---@param connKey   string       连接标识
---@param userId    integer      玩家 userId
---@param slot      integer      槽位号 (1-4)
---@param eventData userdata     原始 eventData（提取 coreData/slotsIndex/rankData/bulletin 等）
---@overload fun(connection: userdata, connKey: string, userId: integer, slot: integer, eventData: SaveEventDataLike)
function SaveWriteService.Execute(connection, connKey, userId, slot, eventData)
    local requestId = 0
    pcall(function() requestId = eventData["requestId"]:GetInt() end)

    -- ── [主存档正文] slot 写入锁保护 ──
    if IsSlotLocked(userId, slot) then
        Logger.warn("SaveGame", "DEFERRED: slot " .. slot .. " is locked (reward write in progress), userId=" .. tostring(userId))
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "slot_locked", requestId)
        return
    end

    local coreDataJson = eventData["coreData"]:GetString()
    local slotsIndexJson = eventData["slotsIndex"]:GetString()

    Logger.info("SaveGame", "userId=" .. tostring(userId) .. " slot=" .. slot)

    -- 解码 JSON
    local ok1, coreData = pcall(cjson.decode, coreDataJson)
    local ok4, slotsIndex = false, nil
    if slotsIndexJson and slotsIndexJson ~= "" then
        ok4, slotsIndex = pcall(cjson.decode, slotsIndexJson)
    end
    if not ok1 or not coreData then
        Logger.error("SaveGame", "coreData decode failed")
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "数据格式错误", requestId)
        return
    end

    -- ════════════════════════════════════════════════════════════════
    -- [B4-S2 硬校验] V1~V6：服务端权威修正关键数值
    -- 策略A：校验异常时跳过校验继续写入，宁存不完美数据也不丢玩家进度
    -- ════════════════════════════════════════════════════════════════
    local validateOk, validateErr = pcall(SaveWriteService._ValidateCoreData, coreData, userId)
    if not validateOk then
        Logger.error("SaveGame", "[CRITICAL] _ValidateCoreData THREW: " .. tostring(validateErr)
            .. " | userId=" .. tostring(userId) .. " — skipping validation, saving anyway")
    end

    -- ── [主存档正文] v11 单 key 写入 ──
    local saveKey = "save_" .. slot

    local batch = serverCloud:BatchSet(userId)
        :Set(saveKey, coreData)
    -- 清理旧格式 key（幂等 Delete）
    batch:Delete("save_data_" .. slot)
    batch:Delete("save_bag1_" .. slot)
    batch:Delete("save_bag2_" .. slot)

    -- slotsIndex 写入（防空覆盖）
    if ok4 and slotsIndex and slotsIndex.slots and next(slotsIndex.slots) then
        NormalizeSlotsIndex(slotsIndex)
        batch:Set("slots_index", slotsIndex)
    elseif ok4 and slotsIndex then
        Logger.warn("SaveGame", "SKIPPING empty slotsIndex write for userId=" .. tostring(userId))
    end

    -- ── [账号级旁路] bulletin ──
    local bulletinJson = eventData["bulletin"]:GetString()
    if bulletinJson and bulletinJson ~= "" then
        local ok6, bulletin = pcall(cjson.decode, bulletinJson)
        if ok6 and bulletin then
            batch:Set("account_bulletin", bulletin)
        end
    end

    -- ── [账号级旁路] account_atlas ──
    if coreData.atlas then
        batch:Set("account_atlas", coreData.atlas)
        Logger.info("SaveGame", "account_atlas written for userId=" .. tostring(userId))
    end

    -- account_cosmetics is server-owned. Never persist a client snapshot here:
    -- it may be stale and erase skins granted by server-side reward handlers.
    if coreData.accountCosmetics then
        Logger.info("SaveGame", "ignored client account_cosmetics for userId=" .. tostring(userId))
    end

    -- account_immortal_bodies is server-owned. Treasure rewards and other
    -- authoritative grant handlers write it through AccountImmortalBodiesService.
    if coreData.accountImmortalBodies then
        Logger.info("SaveGame", "ignored client account_immortal_bodies for userId=" .. tostring(userId))
    end

    -- ── [版本守卫] player_level ──
    local playerLevel = eventData["playerLevel"]:GetInt()
    if playerLevel and playerLevel > 0 then
        batch:SetInt("player_level", playerLevel)
    end

    -- ── [AdminPenalty] suppressRank 守卫 — 跳过所有排行写入 ──
    local _skipRank = AdminPenaltyControl.IsSuppressRank(userId)
    if _skipRank then
        Logger.info("SaveGame", "[AdminPenalty] suppressRank: skip ALL rank writes for userId=" .. tostring(userId))
    end

    -- ════════════════════════════════════════════════════════════════
    -- [排行旁路] rank2_ 排行榜（服务端权威计算）
    -- ════════════════════════════════════════════════════════════════
    local rankInfo, rankRejectReason
    if not _skipRank then
        rankInfo, rankRejectReason = RankHandler.ComputeRankFromSaveData(coreData) ---@diagnostic disable-line: param-type-mismatch
    end

    -- TapTap 昵称
    local taptapNick = ""
    GetUserNickname({
        userIds = { userId },
        onSuccess = function(nicknames)
            if nicknames and #nicknames > 0 then
                taptapNick = nicknames[1].nickname or ""
            end
        end,
    })

    if rankInfo then
        -- 角色名优先从 slotsIndex 取
        if ok4 and slotsIndex and slotsIndex.slots then
            local slotMeta = slotsIndex.slots[slot]
            if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                rankInfo.charName = slotMeta.name
            end
        end
    end

    if rankRejectReason and rankRejectReason ~= "level_too_low"
        and rankRejectReason ~= "no_player_data" then
        Logger.warn("SaveGame", "[AntiCheat] Rank write rejected for userId="
            .. tostring(userId) .. " slot=" .. slot
            .. " reason=" .. rankRejectReason)
    end

    -- ── [版本守卫] _code_ver ──
    local codeVersion = eventData["codeVersion"]:GetInt()
    if codeVersion and codeVersion > 0 then
        batch:SetInt("_code_ver", codeVersion)
    end

    -- ════════════════════════════════════════════════════════════════
    -- [主存档正文] 提交 batch
    -- ※ BM-01A 依赖链关键节点：batch:Save("存档") → ok 回调 → S2C_SaveResult ok=true
    --   拆壳后此语义不变。
    -- ════════════════════════════════════════════════════════════════
    local function RunPostSaveRankUpdates(done)
        if _skipRank then
            done()
            return
        end

        local pending = 2
        local function NewCompletion(label)
            local completed = false
            local function Complete(code, reason)
                if completed then return end
                completed = true
                if code ~= nil then
                    Logger.error("SaveGame", label .. " FAILED: userId="
                        .. tostring(userId) .. " slot=" .. tostring(slot)
                        .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end
                pending = pending - 1
                if pending == 0 then done() end
            end
            return {
                ok = function() Complete() end,
                error = Complete,
            }
        end

        RankHandler.UpsertCultivationRank(
            userId, slot, rankInfo, coreData, taptapNick,
            NewCompletion("cultivation rank update"))
        RankHandler.UpdateTowerRanksFromSave(
            userId, slot, slotsIndex, coreData, taptapNick,
            NewCompletion("tower rank update"))
    end

    local function CommitSave(releaseSlot)
        batch:Save("存档", {
        ok = function()
            local function FinishSuccess()
                if releaseSlot then releaseSlot() end  -- T1: 写档成功释放 slot 锁
                Logger.info("SaveGame", "OK: userId=" .. tostring(userId) .. " slot=" .. slot)

                local resultData = VariantMap()
                resultData["ok"] = Variant(true)
                resultData["requestId"] = Variant(requestId)
                SafeSend(connection, SaveProtocol.S2C_SaveResult, resultData)
            end

            local function FinishRanks()
                RunPostSaveRankUpdates(FinishSuccess)
            end

            -- The account snapshot is never trusted. The base immortal body is
            -- granted from the persisted ascension milestone through the same
            -- server-owned read/modify/write service used by treasure rewards.
            local ascension = type(coreData.ascension) == "table" and coreData.ascension or nil
            local shouldGrantBaseBody = ascension
                and ascension.firstTribulationCompleted == true
                and (tonumber(ascension.totalIndex) or 0) >= 1
            if not shouldGrantBaseBody then
                FinishRanks()
                return
            end

            AccountImmortalBodiesService.Begin(userId, {
                ok = function(transaction)
                    local updated, result = AccountImmortalBodiesService.PrepareBodyGrant(
                        transaction.immortalBodies,
                        "immortal_body_1",
                        "first_tribulation",
                        "first_tribulation",
                        slot)
                    if result.idempotent then
                        transaction:Release()
                        FinishRanks()
                        return
                    end
                    transaction:Save(updated, "first_tribulation_body_unlock", {
                        ok = FinishRanks,
                        error = function(code, reason)
                            Logger.error("SaveGame", "base body grant failed: "
                                .. tostring(code) .. " " .. tostring(reason))
                            FinishRanks()
                        end,
                    })
                end,
                busy = function()
                    Logger.warn("SaveGame", "base body grant deferred: account lock busy")
                    FinishRanks()
                end,
                error = function(code, reason)
                    Logger.error("SaveGame", "base body read failed: "
                        .. tostring(code) .. " " .. tostring(reason))
                    FinishRanks()
                end,
            })
        end,
        error = function(code, reason)
            if releaseSlot then releaseSlot() end  -- T1: 写档失败释放 slot 锁
            Logger.error("SaveGame", "FAILED: " .. tostring(code) .. " " .. tostring(reason))
            local resultData = VariantMap()
            resultData["ok"] = Variant(false)
            resultData["message"] = Variant(tostring(reason))
            resultData["requestId"] = Variant(requestId)
            SafeSend(connection, SaveProtocol.S2C_SaveResult, resultData)
        end,
        })
    end

    -- T1: 写档阶段取 slot 锁（与黑市 WriteSaveBack 双向互斥）
    -- 注：IsSlotLocked 快速拒绝在前面已做（:87），此处是真正 Acquire
    if not AcquireSlotLock(userId, slot) then
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "slot_locked", requestId)
        return
    end
    local slotReleased = false
    local function releaseSlot()
        if not slotReleased then slotReleased = true; ReleaseSlotLock(userId, slot) end
    end

    SaveBackupService.BeforeOverwrite(userId, slot, "SaveGame", function(oldSave)
        local treasureSessionOk, oldTreasureSession, newTreasureSession,
            oldTreasureRevision, newTreasureRevision =
            SaveWriteService._ValidateTreasureSession(oldSave, coreData)
        if not treasureSessionOk then
            releaseSlot()
            Logger.warn("SaveGame", "REJECTED stale treasure session: userId="
                .. tostring(userId) .. " slot=" .. tostring(slot)
                .. " old=" .. tostring(oldTreasureSession)
                .. " incoming=" .. tostring(newTreasureSession)
                .. " oldRevision=" .. tostring(oldTreasureRevision)
                .. " incomingRevision=" .. tostring(newTreasureRevision))
            SendResult(connection, SaveProtocol.S2C_SaveResult, false,
                "treasure_state_changed", requestId)
            return
        end

        -- [T5 ROLLBACK-WRITE] 对账日志（log-only，绝不阻断写入）
        if oldSave and type(oldSave) == "table"
            and type(oldSave.timestamp) == "number"
            and type(coreData.timestamp) == "number"
            and coreData.timestamp < oldSave.timestamp - 60 then
            print("[ROLLBACK-WRITE] userId=" .. tostring(userId)
                .. " slot=" .. slot
                .. " newTs=" .. coreData.timestamp
                .. " oldTs=" .. oldSave.timestamp
                .. " gap=" .. (oldSave.timestamp - coreData.timestamp) .. "s source=client_snapshot")
        end
        CommitSave(releaseSlot)
    end, function(code, reason)
        releaseSlot()
        Logger.error("SaveGame", "PREWRITE BACKUP FAILED: " .. tostring(code) .. " " .. tostring(reason))
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "backup_failed", requestId)
    end)
end

-- ============================================================================
-- [B4-S2 硬校验] V1~V6 内部验证函数
-- ============================================================================

-- ============================================================================
-- Chunked SaveGame session handlers
-- ============================================================================

local _saveChunkSessions = {}
local CHUNK_SESSION_TTL = 60

local function ChunkSessionKey(userId, slot, requestId)
    return tostring(userId) .. ":" .. tostring(slot) .. ":" .. tostring(requestId)
end

local function CleanupChunkSessions()
    local now = os.time()
    for key, session in pairs(_saveChunkSessions) do
        if now - (session.createdAt or now) > CHUNK_SESSION_TTL then
            _saveChunkSessions[key] = nil
        end
    end
end

local function ReadInt(eventData, name, defaultValue)
    local value = defaultValue or 0
    pcall(function() value = eventData[name]:GetInt() end)
    return value
end

local function ReadString(eventData, name, defaultValue)
    local value = defaultValue or ""
    pcall(function() value = eventData[name]:GetString() end)
    return value
end

---@param value string|nil
---@return SaveEventDataField
local function StringField(value)
    return {
        GetString = function() return value or "" end,
        GetInt = function() return tonumber(value) or 0 end,
    }
end

---@param value integer|number|string|nil
---@return SaveEventDataField
local function IntField(value)
    return {
        GetString = function() return tostring(value or "") end,
        GetInt = function() return tonumber(value) or 0 end,
    }
end

---@return SaveEventDataLike
local function BuildEventDataFromPayload(session, coreDataJson)
    return {
        coreData = StringField(coreDataJson),
        slotsIndex = StringField(session.slotsIndexJson),
        rankData = StringField(session.rankDataJson),
        bulletin = StringField(session.bulletinJson),
        playerLevel = IntField(session.playerLevel),
        codeVersion = IntField(session.codeVersion),
        requestId = IntField(session.requestId),
    }
end

function SaveWriteService.HandleChunkBegin(connection, connKey, userId, slot, eventData)
    CleanupChunkSessions()
    local requestId = ReadInt(eventData, "requestId", 0)
    local totalBytes = ReadInt(eventData, "totalBytes", -1)
    local totalChunks = ReadInt(eventData, "totalChunks", -1)
    local checksum = ReadString(eventData, "checksum", "")

    local ok, reason = SavePayloadCodec.ValidateMetadata(totalBytes, totalChunks)
    if not ok or checksum == "" or requestId <= 0 then
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, reason or "invalid_chunk_begin", requestId)
        return
    end

    local key = ChunkSessionKey(userId, slot, requestId)
    _saveChunkSessions[key] = {
        requestId = requestId,
        slot = slot,
        totalBytes = totalBytes,
        totalChunks = totalChunks,
        checksum = checksum,
        slotsIndexJson = ReadString(eventData, "slotsIndex", ""),
        rankDataJson = ReadString(eventData, "rankData", ""),
        bulletinJson = ReadString(eventData, "bulletin", ""),
        playerLevel = ReadInt(eventData, "playerLevel", 0),
        codeVersion = ReadInt(eventData, "codeVersion", 0),
        chunks = {},
        received = 0,
        createdAt = os.time(),
    }
    Logger.info("SaveGame", "chunk begin: userId=" .. tostring(userId)
        .. " slot=" .. tostring(slot) .. " requestId=" .. tostring(requestId)
        .. " chunks=" .. tostring(totalChunks) .. " bytes=" .. tostring(totalBytes))
end

function SaveWriteService.HandleChunk(connection, connKey, userId, slot, eventData)
    local requestId = ReadInt(eventData, "requestId", 0)
    local key = ChunkSessionKey(userId, slot, requestId)
    local session = _saveChunkSessions[key]
    if not session then
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "save_chunk_session_missing", requestId)
        return
    end

    local chunkIndex = ReadInt(eventData, "chunkIndex", 0)
    local chunkData = ReadString(eventData, "chunkData", "")
    if chunkIndex < 1 or chunkIndex > session.totalChunks or #chunkData > SavePayloadCodec.CHUNK_BYTES then
        _saveChunkSessions[key] = nil
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "invalid_save_chunk", requestId)
        return
    end

    local existing = session.chunks[chunkIndex]
    if existing == nil then
        session.chunks[chunkIndex] = chunkData
        session.received = session.received + 1
    elseif existing ~= chunkData then
        _saveChunkSessions[key] = nil
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "conflicting_save_chunk", requestId)
    end
end

function SaveWriteService.HandleChunkCommit(connection, connKey, userId, slot, eventData)
    local requestId = ReadInt(eventData, "requestId", 0)
    local key = ChunkSessionKey(userId, slot, requestId)
    local session = _saveChunkSessions[key]
    if not session then
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "save_chunk_session_missing", requestId)
        return
    end

    if session.received ~= session.totalChunks then
        _saveChunkSessions[key] = nil
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "save_chunk_incomplete", requestId)
        return
    end

    local ok, payloadOrReason = SavePayloadCodec.Join(session.chunks, session.totalChunks)
    if not ok then
        _saveChunkSessions[key] = nil
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, payloadOrReason, requestId)
        return
    end

    local payload = payloadOrReason
    if #payload ~= session.totalBytes or SavePayloadCodec.Checksum(payload) ~= session.checksum then
        _saveChunkSessions[key] = nil
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "save_chunk_checksum_failed", requestId)
        return
    end

    _saveChunkSessions[key] = nil
    Logger.info("SaveGame", "chunk commit: userId=" .. tostring(userId)
        .. " slot=" .. tostring(slot) .. " requestId=" .. tostring(requestId)
        .. " bytes=" .. tostring(#payload))
    SaveWriteService.Execute(connection, connKey, userId, slot, BuildEventDataFromPayload(session, payload))
end
function SaveWriteService._ValidateCoreData(coreData, userId)
    -- V1~V4: player 基础数值
    if coreData.player then
        local cp = coreData.player

        -- V1: level 不得超过当前境界 maxLevel
        if cp.level and type(cp.level) == "number" then
            local realm = cp.realm or "mortal"
            local rCfg = GameConfig.REALMS[realm]
            if rCfg then
                local maxLv = rCfg.maxLevel or 999
                if cp.level > maxLv then
                    Logger.warn("SaveGame", "[V1] Level clamped: " .. cp.level .. " -> " .. maxLv
                        .. " (realm=" .. realm .. ") userId=" .. tostring(userId))
                    cp.level = maxLv
                end
            end
            if cp.level < 1 then cp.level = 1 end
        end

        -- V2: exp 不得为负
        if cp.exp and type(cp.exp) == "number" then
            if cp.exp < 0 then
                Logger.warn("SaveGame", "[V2] Exp clamped from " .. cp.exp .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.exp = 0
            end
            local nextLvExp = GameConfig.EXP_TABLE[cp.level + 1]
                or GameConfig.EXP_TABLE[cp.level]
                or cp.exp
            if nextLvExp and cp.exp > nextLvExp * 2 then
                Logger.warn("SaveGame", "[V2] Exp suspicious: " .. cp.exp
                    .. " > 2x nextLvExp=" .. nextLvExp
                    .. " userId=" .. tostring(userId))
                cp.exp = nextLvExp
            end
        end

        -- V3: gold 不得为负
        if cp.gold and type(cp.gold) == "number" then
            if cp.gold < 0 then
                Logger.warn("SaveGame", "[V3] Gold clamped from " .. cp.gold .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.gold = 0
            end
        end

        -- V4: lingYun 不得为负
        if cp.lingYun and type(cp.lingYun) == "number" then
            if cp.lingYun < 0 then
                Logger.warn("SaveGame", "[V4] LingYun clamped from " .. cp.lingYun .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.lingYun = 0
            end
        end
    end

    -- V5: 丹药计数上限校验
    if coreData.shop then
        local shopPillLimits = {
            { field = "tigerPillCount",    max = 5,  name = "虎骨丹(shop-legacy)" },
            { field = "snakePillCount",    max = 5,  name = "灵蛇丹(shop-legacy)" },
            { field = "diamondPillCount",  max = 5,  name = "金刚丹(shop-legacy)" },
            { field = "temperingPillEaten", max = 50, name = "千锤百炼丹(shop-legacy)" },
        }
        for _, pill in ipairs(shopPillLimits) do
            local v = coreData.shop[pill.field]
            if v and type(v) == "number" and v > pill.max then
                Logger.warn("SaveGame", "[V5] " .. pill.name .. " clamped: "
                    .. v .. " -> " .. pill.max
                    .. " userId=" .. tostring(userId))
                coreData.shop[pill.field] = pill.max
            end
        end
    end
    if coreData.challenges then
        local chPillLimits = {
            { field = "xueshaDanCount", max = 9, name = "血煞丹(ch-legacy)" },
            { field = "haoqiDanCount",  max = 9, name = "浩气丹(ch-legacy)" },
        }
        for _, pill in ipairs(chPillLimits) do
            local v = coreData.challenges[pill.field]
            if v and type(v) == "number" and v > pill.max then
                Logger.warn("SaveGame", "[V5] " .. pill.name .. " clamped: "
                    .. v .. " -> " .. pill.max
                    .. " userId=" .. tostring(userId))
                coreData.challenges[pill.field] = pill.max
            end
        end
    end
    if coreData.player then
        local playerPillLimits = {
            { field = "tigerPillCount",    max = 5,  name = "虎骨丹" },
            { field = "snakePillCount",    max = 5,  name = "灵蛇丹" },
            { field = "diamondPillCount",  max = 5,  name = "金刚丹" },
            { field = "temperingPillEaten", max = 50, name = "千锤百炼丹" },
            { field = "xueshaDanCount",    max = 9,  name = "血煞丹" },
            { field = "haoqiDanCount",     max = 9,  name = "浩气丹" },
            { field = "shadowGodPillCount", max = 30, name = "影神丹" },
            { field = "pillConstitution", max = 50, name = "根骨(千锤百炼)" },
            { field = "gangguConstitution", max = 50, name = "根骨(钢筋铁骨)" },
            { field = "pillPhysique",     max = SealDemonConfig.PHYSIQUE_PILL.maxCount, name = "体魄丹" },
            { field = "pillKillHeal",     max = 45, name = "击杀回血(血煞)" },
            { field = "shadowGodKillHeal", max = 600, name = "击杀回血(影神丹)" },
            { field = "daoTreeWisdom",    max = 100, name = "悟道" },
            { field = "fruitFortune",     max = 50, name = "福缘果" },
            { field = "seaPillarDef",     max = 20, name = "海神柱防御" },
            { field = "seaPillarAtk",     max = 30, name = "海神柱攻击" },
            { field = "seaPillarMaxHp",   max = 300, name = "海神柱生命" },
            { field = "seaPillarHpRegen", max = 30, name = "海神柱恢复" },
            { field = "liangjieStoneAtk", max = 150, name = "两界阵石攻击" },
            { field = "liangjieStoneDef", max = 120, name = "两界阵石防御" },
            { field = "liangjieStoneMaxHp", max = 1500, name = "两界阵石生命" },
            { field = "liangjieStoneHpRegen", max = 150, name = "两界阵石恢复" },
            { field = "premiumZongEaten", max = 10, name = "仙界精品粽" },
            { field = "pillFortune",      max = 10, name = "福缘(精品粽)" },
            { field = "premiumRedbeanCakeEaten", max = 10, name = "相思红豆糕" },
            { field = "pillWisdom",       max = 10, name = "悟性(相思红豆糕)" },
        }
        for _, pill in ipairs(playerPillLimits) do
            local v = coreData.player[pill.field]
            if v and type(v) == "number" and v > pill.max then
                Logger.warn("SaveGame", "[V5] " .. pill.name .. " clamped: "
                    .. v .. " -> " .. pill.max
                    .. " userId=" .. tostring(userId))
                coreData.player[pill.field] = pill.max
            end
        end

        -- V5d: 仙界精品粽三字段对齐（§10.15）
        local cp = coreData.player
        if type(cp.pillCounts) ~= "table" then cp.pillCounts = {} end
        local eaten = cp.premiumZongEaten or 0
        if (cp.pillFortune or 0) ~= eaten then
            Logger.warn("SaveGame", "[V5d] pillFortune realigned: " .. (cp.pillFortune or 0) .. " -> " .. eaten
                .. " userId=" .. tostring(userId))
            cp.pillFortune = eaten
        end
        if (cp.pillCounts.zong or 0) ~= eaten then
            Logger.warn("SaveGame", "[V5d] pillCounts.zong realigned: " .. (cp.pillCounts.zong or 0) .. " -> " .. eaten
                .. " userId=" .. tostring(userId))
            cp.pillCounts.zong = eaten
        end

        -- V5e: 相思红豆糕三字段对齐
        local redbeanEaten = cp.premiumRedbeanCakeEaten or 0
        if (cp.pillWisdom or 0) ~= redbeanEaten then
            Logger.warn("SaveGame", "[V5e] pillWisdom realigned: " .. (cp.pillWisdom or 0) .. " -> " .. redbeanEaten
                .. " userId=" .. tostring(userId))
            cp.pillWisdom = redbeanEaten
        end
        if (cp.pillCounts.redbean_cake or 0) ~= redbeanEaten then
            Logger.warn("SaveGame", "[V5e] pillCounts.redbean_cake realigned: "
                .. (cp.pillCounts.redbean_cake or 0) .. " -> " .. redbeanEaten
                .. " userId=" .. tostring(userId))
            cp.pillCounts.redbean_cake = redbeanEaten
        end
    end

    -- V5b: 海神柱等级是规范档案；角色聚合字段只能由服务端重算。
    do
        local rawPillars = type(coreData.seaPillar) == "table" and coreData.seaPillar or {}
        local normalized = {}
        local bonuses = { def = 0, atk = 0, maxHp = 0, hpRegen = 0 }

        for _, pid in ipairs(SeaPillarConfig.PILLAR_ORDER) do
            local raw = type(rawPillars[pid]) == "table" and rawPillars[pid] or {}
            local repaired = raw.repaired == true
            local level = 0
            if repaired and type(raw.level) == "number" and raw.level == raw.level then
                level = math.floor(raw.level)
                if level < 0 then level = 0 end
                if level > SeaPillarConfig.MAX_LEVEL then
                    Logger.warn("SaveGame", "[V5b] SeaPillar " .. pid .. " level clamped: "
                        .. level .. " -> " .. SeaPillarConfig.MAX_LEVEL
                        .. " userId=" .. tostring(userId))
                    level = SeaPillarConfig.MAX_LEVEL
                end
            end

            normalized[pid] = {
                repaired = repaired,
                level = level,
            }

            local cfg = SeaPillarConfig.PILLARS[pid]
            if cfg and level > 0 then
                bonuses[cfg.bonusStat] = bonuses[cfg.bonusStat] + cfg.bonusPerLevel * level
            end
        end

        coreData.seaPillar = normalized
        if coreData.player then
            local cp = coreData.player
            cp.seaPillarDef = bonuses.def
            cp.seaPillarAtk = bonuses.atk
            cp.seaPillarMaxHp = bonuses.maxHp
            cp.seaPillarHpRegen = bonuses.hpRegen
        end
    end

    -- V5f: 两界阵石等级档案是唯一真值；服务端规范化后覆盖角色派生字段。
    do
        local rawSystem = type(coreData.liangjieStones) == "table"
            and coreData.liangjieStones or {}
        local rawStones = type(rawSystem.stones) == "table"
            and rawSystem.stones or rawSystem
        local normalizedStones = {}
        local bonuses = { atk = 0, def = 0, maxHp = 0, hpRegen = 0 }

        for _, stoneId in ipairs(LiangjieStoneConfig.STONE_ORDER) do
            local raw = type(rawStones[stoneId]) == "table"
                and rawStones[stoneId] or {}
            local activated = raw.activated == true
            local level = 0
            if activated and type(raw.level) == "number" and raw.level == raw.level then
                level = math.floor(raw.level)
                if level < 0 then level = 0 end
                if level > LiangjieStoneConfig.MAX_LEVEL then
                    Logger.warn("SaveGame", "[V5f] LiangjieStone " .. stoneId
                        .. " level clamped: " .. level .. " -> "
                        .. LiangjieStoneConfig.MAX_LEVEL
                        .. " userId=" .. tostring(userId))
                    level = LiangjieStoneConfig.MAX_LEVEL
                end
            end

            normalizedStones[stoneId] = {
                activated = activated,
                level = level,
                -- 激活状态本身证明奖励事务已提交，禁止伪造未领奖状态补发经验。
                activationRewardClaimed = activated,
            }

            local cfg = LiangjieStoneConfig.STONES[stoneId]
            if cfg and activated and level > 0 then
                bonuses[cfg.bonusStat] = bonuses[cfg.bonusStat]
                    + cfg.bonusPerLevel * level
            end
        end

        coreData.liangjieStones = {
            version = 1,
            stones = normalizedStones,
        }
        if coreData.player then
            local cp = coreData.player
            cp.liangjieStoneAtk = bonuses.atk
            cp.liangjieStoneDef = bonuses.def
            cp.liangjieStoneMaxHp = bonuses.maxHp
            cp.liangjieStoneHpRegen = bonuses.hpRegen
        end
    end

    -- V5c: 祀剑池等级是规范档案；角色聚合字段只能由服务端重算。
    do
        local rawSwords = type(coreData.swordPool) == "table" and coreData.swordPool or {}
        local normalized = {}
        local bonuses = { atk = 0, def = 0, maxHp = 0, hpRegen = 0 }

        for _, swordId in ipairs(SwordPoolConfig.SWORD_ORDER) do
            local raw = type(rawSwords[swordId]) == "table" and rawSwords[swordId] or {}
            local unlocked = raw.unlocked == true
            local level = 0
            if unlocked and type(raw.level) == "number" and raw.level == raw.level then
                level = math.floor(raw.level)
                if level < 0 then level = 0 end
                if level > SwordPoolConfig.MAX_LEVEL then
                    Logger.warn("SaveGame", "[V5c] SwordPool " .. swordId .. " level clamped: "
                        .. level .. " -> " .. SwordPoolConfig.MAX_LEVEL
                        .. " userId=" .. tostring(userId))
                    level = SwordPoolConfig.MAX_LEVEL
                end
            end

            normalized[swordId] = {
                unlocked = unlocked,
                level = level,
            }

            local cfg = SwordPoolConfig.SWORDS[swordId]
            if cfg and level > 0 then
                bonuses[cfg.bonusStat] = bonuses[cfg.bonusStat] + cfg.bonusPerLevel * level
            end
        end

        coreData.swordPool = normalized
        if coreData.player then
            local cp = coreData.player
            cp.swordPoolAtk = bonuses.atk
            cp.swordPoolDef = bonuses.def
            cp.swordPoolMaxHp = bonuses.maxHp
            cp.swordPoolHpRegen = bonuses.hpRegen
        end
    end

    -- V5g: 第六章界匙以账号档为权威；固定九格并校验解锁关系和替命冷却。
    do
        local rawAccount = type(coreData.atlas) == "table"
            and coreData.atlas.artifact_jieshi or nil
        local rawMirror = type(coreData.artifact_ch6) == "table"
            and coreData.artifact_ch6 or nil
        local source = type(rawAccount) == "table" and rawAccount or rawMirror
        local normalizedAccount = NormalizeJieshiProgress(source, true)

        coreData.artifact_ch6 = {
            version = 1,
            activatedGrids = normalizedAccount.activatedGrids,
            bossDefeated = normalizedAccount.bossDefeated,
            passiveUnlocked = normalizedAccount.passiveUnlocked,
        }
        if type(coreData.atlas) == "table" then
            coreData.atlas.version = math.max(
                3, tonumber(coreData.atlas.version) or 1)
            coreData.atlas.artifact_jieshi = normalizedAccount
        end
    end

    -- V6: 仓库数据校验
    if coreData.warehouse then
        local wh = coreData.warehouse
        local MAX_ROWS = 6
        local ITEMS_PER_ROW = 8
        if wh.unlockedRows == nil or type(wh.unlockedRows) ~= "number" then
            wh.unlockedRows = 1
        end
        if wh.unlockedRows < 1 then wh.unlockedRows = 1 end
        if wh.unlockedRows > MAX_ROWS then
            Logger.warn("SaveGame", "[V6] warehouse unlockedRows clamped: "
                .. wh.unlockedRows .. " -> " .. MAX_ROWS
                .. " userId=" .. tostring(userId))
            wh.unlockedRows = MAX_ROWS
        end
        if wh.items and type(wh.items) == "table" then
            local maxSlot = wh.unlockedRows * ITEMS_PER_ROW
            local keysToRemove = {}
            for k, _ in pairs(wh.items) do
                local idx = tonumber(k)
                if idx == nil or idx < 1 or idx > maxSlot then
                    table.insert(keysToRemove, k)
                end
            end
            for _, k in ipairs(keysToRemove) do
                Logger.warn("SaveGame", "[V6] warehouse item removed at slot " .. tostring(k)
                    .. " (max=" .. maxSlot .. ") userId=" .. tostring(userId))
                wh.items[k] = nil
            end
        end
    end



    -- V5c: maxHp/atk/def 属性上界软校验（仅记日志，不 clamp）
    if coreData.player then
        local cp = coreData.player
        local lv = cp.level or 1
        local realm = cp.realm or "mortal"

        local realmMaxHp, realmAtk, realmDef = 0, 0, 0
        local realmOrder = GameConfig.REALMS[realm] and GameConfig.REALMS[realm].order or 0
        for _, rId in ipairs(GameConfig.REALM_LIST) do
            local rCfg = GameConfig.REALMS[rId]
            if rCfg and rCfg.order and rCfg.order <= realmOrder and rCfg.rewards then
                realmMaxHp = realmMaxHp + (rCfg.rewards.maxHp or 0)
                realmAtk = realmAtk + (rCfg.rewards.atk or 0)
                realmDef = realmDef + (rCfg.rewards.def or 0)
            end
        end

        local pillMaxHp = 150 + 270 + 300
        local pillAtk = 50 + 72 + 30 + 100 + 150  -- +100: 太虚剑丹(10×10), +150: 影神丹(30×5)
        local pillDef = 40 + 20 + 80        -- +80: 狱甲丹(8×10)

        local expectedMaxHp = 100 + 15 * lv + realmMaxHp + pillMaxHp
        local expectedAtk = 15 + 3 * lv + realmAtk + pillAtk
        local expectedDef = 5 + 2 * lv + realmDef + pillDef

        local tolerance = 3
        if cp.maxHp and type(cp.maxHp) == "number" and cp.maxHp > expectedMaxHp * tolerance then
            Logger.diag("SaveGame", string.format("[V5c] maxHp SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.maxHp, expectedMaxHp * tolerance, expectedMaxHp, tolerance, tostring(userId), realm, lv))
        end
        if cp.atk and type(cp.atk) == "number" and cp.atk > expectedAtk * tolerance then
            Logger.diag("SaveGame", string.format("[V5c] atk SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.atk, expectedAtk * tolerance, expectedAtk, tolerance, tostring(userId), realm, lv))
        end
        if cp.def and type(cp.def) == "number" and cp.def > expectedDef * tolerance then
            Logger.diag("SaveGame", string.format("[V5c] def SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.def, expectedDef * tolerance, expectedDef, tolerance, tostring(userId), realm, lv))
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- V7: 宠物数据校验（tier/level/exp/skills/appearance 白名单边界）
    -- 策略：仅 clamp 越界数值 + 剔除非法技能条目，不删整个 pet 块
    -- 隔离 pcall：宠物段抛异常不影响 V1~V6 已完成的校验
    -- ════════════════════════════════════════════════════════════════
    if coreData.pet and type(coreData.pet) == "table" then
      local petValOk, petValErr = pcall(function()
        local pet = coreData.pet

        -- V7a: tier 范围 [0, 7]
        if pet.tier ~= nil then
            if type(pet.tier) ~= "number" then
                Logger.warn("SaveGame", "[V7a] pet.tier not number, resetting to 0 userId=" .. tostring(userId))
                pet.tier = 0
            else
                if pet.tier < 0 then pet.tier = 0 end
                if pet.tier > 7 then
                    Logger.warn("SaveGame", "[V7a] pet.tier clamped: " .. pet.tier .. " -> 7 userId=" .. tostring(userId))
                    pet.tier = 7
                end
            end
        end

        -- V7b: level 范围 [1, tier.maxLevel]
        if pet.level ~= nil then
            if type(pet.level) ~= "number" then
                Logger.warn("SaveGame", "[V7b] pet.level not number, resetting to 1 userId=" .. tostring(userId))
                pet.level = 1
            else
                if pet.level < 1 then pet.level = 1 end
                local tierData = GameConfig.PET_TIERS[pet.tier or 0]
                local maxLv = tierData and tierData.maxLevel or 160
                if pet.level > maxLv then
                    Logger.warn("SaveGame", "[V7b] pet.level clamped: " .. pet.level .. " -> " .. maxLv
                        .. " (tier=" .. tostring(pet.tier) .. ") userId=" .. tostring(userId))
                    pet.level = maxLv
                end
            end
        end

        -- V7c: exp 不得为负（仅记录告警，不修改值，避免丢失合法经验）
        if pet.exp ~= nil and type(pet.exp) == "number" then
            if pet.exp < 0 then
                Logger.warn("SaveGame", "[V7c] pet.exp negative: " .. pet.exp .. " userId=" .. tostring(userId))
            end
        end

        -- V7d: skills 白名单校验（slot 1~10, id 必须在 PetSkillData.SKILLS 中, tier 1~MAX_TIER）
        if pet.skills and type(pet.skills) == "table" then
            local MAX_SLOT = 10
            local MAX_SKILL_TIER = PetSkillData.MAX_TIER or 4
            local keysToRemove = {}
            for k, v in pairs(pet.skills) do
                local slotNum = tonumber(k)
                local invalid = false
                if slotNum == nil or slotNum < 1 or slotNum > MAX_SLOT then
                    invalid = true
                    Logger.warn("SaveGame", "[V7d] pet skill invalid slot=" .. tostring(k)
                        .. " userId=" .. tostring(userId))
                elseif type(v) ~= "table" then
                    invalid = true
                    Logger.warn("SaveGame", "[V7d] pet skill slot " .. tostring(k)
                        .. " value not table userId=" .. tostring(userId))
                elseif not v.id or not PetSkillData.SKILLS[v.id] then
                    invalid = true
                    Logger.warn("SaveGame", "[V7d] pet skill unknown id=" .. tostring(v.id)
                        .. " slot=" .. tostring(k) .. " userId=" .. tostring(userId))
                else
                    -- id 合法，clamp tier
                    if v.tier and type(v.tier) == "number" then
                        if v.tier < 1 then v.tier = 1 end
                        if v.tier > MAX_SKILL_TIER then
                            Logger.warn("SaveGame", "[V7d] pet skill tier clamped: " .. v.tier
                                .. " -> " .. MAX_SKILL_TIER .. " id=" .. v.id
                                .. " userId=" .. tostring(userId))
                            v.tier = MAX_SKILL_TIER
                        end
                    else
                        v.tier = 1
                    end
                end
                if invalid then
                    table.insert(keysToRemove, k)
                end
            end
            for _, k in ipairs(keysToRemove) do
                pet.skills[k] = nil
            end
        end

        -- V7e: appearance 白名单 + 解锁校验
        if pet.appearance ~= nil then
            if type(pet.appearance) ~= "table" then
                Logger.warn("SaveGame", "[V7e] pet.appearance not table, removing userId=" .. tostring(userId))
                pet.appearance = nil
            elseif pet.appearance.selectedId and type(pet.appearance.selectedId) ~= "string" then
                Logger.warn("SaveGame", "[V7e] pet.appearance.selectedId not string, removing userId=" .. tostring(userId))
                pet.appearance = nil
            elseif pet.appearance.selectedId then
                local PetAppearanceConfig = require("config.PetAppearanceConfig")
                local skin = PetAppearanceConfig.byId and PetAppearanceConfig.byId[pet.appearance.selectedId]
                if not skin then
                    Logger.warn("SaveGame", "[V7e] pet.appearance.selectedId unknown: "
                        .. pet.appearance.selectedId .. ", removing userId=" .. tostring(userId))
                    pet.appearance = nil
                elseif skin.category == "base" and (pet.tier or 1) < (skin.requiredTier or 0) then
                    Logger.warn("SaveGame", "[V7e] pet.appearance tier locked: "
                        .. pet.appearance.selectedId .. " requires tier " .. (skin.requiredTier or 0)
                        .. " but pet tier=" .. tostring(pet.tier) .. ", removing userId=" .. tostring(userId))
                    pet.appearance = nil
                end
            end
        end

        -- V7f: formId 白名单 + 解锁 + 启用校验
        local PetFormConfig = require("config.PetFormConfig")
        local petTier = pet.tier or 1
        if pet.formId ~= nil then
            if type(pet.formId) ~= "string" then
                Logger.warn("SaveGame", "[V7f] pet.formId not string, removing userId=" .. tostring(userId))
                pet.formId = nil
            elseif not PetFormConfig.IsValid(pet.formId) then
                Logger.warn("SaveGame", "[V7f] pet.formId invalid: " .. tostring(pet.formId)
                    .. ", removing userId=" .. tostring(userId))
                pet.formId = nil
            elseif not PetFormConfig.IsFormEnabled(pet.formId) then
                Logger.warn("SaveGame", "[V7f] pet.formId disabled: " .. pet.formId
                    .. ", removing userId=" .. tostring(userId))
                pet.formId = nil
            else
                local cfg = PetFormConfig.Get(pet.formId)
                if cfg and cfg.unlockTier > petTier then
                    Logger.warn("SaveGame", "[V7f] pet.formId locked: " .. pet.formId
                        .. " requires tier " .. cfg.unlockTier .. " but pet tier=" .. petTier
                        .. ", removing userId=" .. tostring(userId))
                    pet.formId = nil
                end
            end
        end
        -- V7f-2: pendingFormId 校验（仅死亡态合法，活着时无条件清除）
        if pet.pendingFormId ~= nil then
            if pet.alive ~= false then
                -- 宠物活着不应有 pendingFormId（只有死亡期间才暂存待切形态）
                Logger.warn("SaveGame", "[V7f] pet.pendingFormId present while alive, clearing: "
                    .. tostring(pet.pendingFormId) .. " userId=" .. tostring(userId))
                pet.pendingFormId = nil
            elseif type(pet.pendingFormId) ~= "string"
                or not PetFormConfig.IsValid(pet.pendingFormId)
                or not PetFormConfig.IsFormEnabled(pet.pendingFormId) then
                Logger.warn("SaveGame", "[V7f] pet.pendingFormId invalid/disabled: "
                    .. tostring(pet.pendingFormId) .. ", removing userId=" .. tostring(userId))
                pet.pendingFormId = nil
            else
                local cfg = PetFormConfig.Get(pet.pendingFormId)
                if cfg and cfg.unlockTier > petTier then
                    Logger.warn("SaveGame", "[V7f] pet.pendingFormId locked: " .. pet.pendingFormId
                        .. " requires tier " .. cfg.unlockTier .. " but pet tier=" .. petTier
                        .. ", removing userId=" .. tostring(userId))
                    pet.pendingFormId = nil
                end
            end
        end
      end) -- pcall end
      if not petValOk then
          Logger.error("SaveGame", "[V7] pet validation THREW: " .. tostring(petValErr)
              .. " | userId=" .. tostring(userId) .. " — pet data saved as-is")
      end
    end
end

return SaveWriteService
