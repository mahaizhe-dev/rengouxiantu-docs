-- ============================================================================
-- RankHandler.lua — 修仙榜/仙人榜/塔榜 + 竞速道印 服务端 Handler
--
-- 职责：榜单分类与分数计算 / 登录重建 / 查询代理 / 竞速占位
--       HandleTryUnlockRace / RACE_MEDAL_CONFIG
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B3）
-- ============================================================================

local Session      = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local GameConfig   = require("config.GameConfig")
local AscensionConfig = require("config.AscensionConfig")
local TrialTowerConfig = require("config.TrialTowerConfig")
local PrisonTowerConfig = require("config.PrisonTowerConfig")
local AdminPenaltyControl = require("network.AdminPenaltyControl")

AscensionConfig.EnsureRealmsRegistered()

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local ConnKey   = Session.ConnKey
local GetUserId = Session.GetUserId
local SafeSend  = Session.SafeSend

local M = {}

-- 修仙榜复合分数时间基数（与试炼榜/镇狱榜一致，10^10）
-- composite = rawScore * RANK2_TIME_BASE + (RANK2_TIME_BASE - 1 - os.time())
-- 同分时，先达成者的 (TIME_BASE - 1 - t) 更大 → 服务端降序排列即为先到先前
local RANK2_TIME_BASE = 10000000000
M.RANK2_TIME_BASE = RANK2_TIME_BASE
M.XIANREN_TIME_BASE = RANK2_TIME_BASE
M.XIANREN_FIRST_REALM_ORDER = 23

M.XIANREN_SCORE_PREFIX = "xianren_score_"
M.XIANREN_KILLS_PREFIX = "xianren_kills_"
M.XIANREN_TIME_PREFIX = "xianren_time_"
M.XIANREN_INFO_PREFIX = "xianren_info_"

local function ToInteger(value)
    local number = tonumber(value)
    if not number or number ~= number
        or number == math.huge or number == -math.huge then
        return nil
    end
    return math.floor(number)
end

local function IsImmortalRealm(realm, realmCfg)
    local order = realmCfg and tonumber(realmCfg.order) or 0
    return order >= M.XIANREN_FIRST_REALM_ORDER
end

M.IsImmortalRealm = IsImmortalRealm

local function GetRoleUid(userId, slot)
    return tostring(userId) .. ":" .. tostring(slot)
end

M.GetRoleUid = GetRoleUid

local function IsBodyUnlocked(accountBodies, bodyId)
    if bodyId == "mortal" then return true end
    local unlocked = type(accountBodies) == "table" and accountBodies.unlockedBodies or nil
    return type(unlocked) == "table" and type(unlocked[bodyId]) == "table"
end

local function GetImmortalBodyInfo(coreData, accountBodies)
    local bodyData = coreData and coreData.immortalBody
    local bodyId = type(bodyData) == "table" and bodyData.activeBodyId or nil
    bodyId = (type(bodyId) == "string" and bodyId ~= "") and bodyId or "mortal"

    local profile = AscensionConfig.GROWTH_PROFILES[bodyId]
    if not profile or not IsBodyUnlocked(accountBodies, bodyId) then
        bodyId = "mortal"
        profile = AscensionConfig.GROWTH_PROFILES[bodyId]
    end

    return {
        bodyId = bodyId,
        bodyName = profile and profile.name or "凡人之躯",
    }
end

M.GetImmortalBodyInfo = GetImmortalBodyInfo

function M.BuildImmortalInfo(rankInfo, coreData, userId, slot, taptapNick, accountBodies)
    local body = GetImmortalBodyInfo(coreData, accountBodies)
    return {
        name = rankInfo.charName,
        realm = rankInfo.realm,
        level = rankInfo.level,
        bossKills = rankInfo.bossKills,
        taptapNick = taptapNick,
        classId = rankInfo.classId,
        roleUid = GetRoleUid(userId, slot),
        currentBodyId = body.bodyId,
        currentBodyName = body.bodyName,
    }
end

function M.BuildCompositeScore(rankInfo, achieveTime)
    local timestamp = ToInteger(achieveTime) or os.time()
    return rankInfo.rankScore * RANK2_TIME_BASE
        + (RANK2_TIME_BASE - 1 - timestamp)
end

function M.DecodeCompositeScore(composite)
    local value = ToInteger(composite) or 0
    if value <= 0 then return 0, 0 end
    if value < RANK2_TIME_BASE then return value, 0 end

    local rawScore = math.floor(value / RANK2_TIME_BASE)
    local timePart = value - rawScore * RANK2_TIME_BASE
    local achieveTime = RANK2_TIME_BASE - 1 - timePart
    local now = os.time()
    if achieveTime < 1 or achieveTime > now + 300 then
        achieveTime = 0
    end
    return rawScore, achieveTime
end

local function CultivationKeys(slot, immortal)
    if immortal then
        return {
            score = M.XIANREN_SCORE_PREFIX .. slot,
            kills = M.XIANREN_KILLS_PREFIX .. slot,
            time = M.XIANREN_TIME_PREFIX .. slot,
            info = M.XIANREN_INFO_PREFIX .. slot,
        }
    end
    return {
        score = "rank2_score_" .. slot,
        kills = "rank2_kills_" .. slot,
        time = "rank2_time_" .. slot,
        info = "rank2_info_" .. slot,
    }
end

local function DeleteCultivationKeys(commit, userId, keys)
    commit:ScoreDeleteInt(userId, keys.score)
    commit:ScoreDeleteInt(userId, keys.kills)
    commit:ScoreDeleteInt(userId, keys.time)
    commit:ScoreDelete(userId, keys.info)
end

local function CommitCallbacks(callbacks, label, okResult)
    callbacks = callbacks or {}
    return {
        ok = function()
            if callbacks.ok then callbacks.ok(okResult) end
        end,
        error = function(code, reason)
            print("[Server][" .. label .. "] FAILED: "
                .. tostring(code) .. " " .. tostring(reason))
            if callbacks.error then callbacks.error(code, reason) end
        end,
    }
end

function M.ClearCultivationRanks(userId, slot, callbacks)
    local commit = serverCloud:BatchCommit(
        "clear-cultivation-ranks-" .. tostring(userId) .. "-" .. tostring(slot))
    DeleteCultivationKeys(commit, userId, CultivationKeys(slot, false))
    DeleteCultivationKeys(commit, userId, CultivationKeys(slot, true))
    commit:Commit(CommitCallbacks(callbacks, "RankClear"))
end

function M.RemoveXiuxianRank(userId, slot, callbacks)
    local commit = serverCloud:BatchCommit(
        "clear-xiuxian-rank-" .. tostring(userId) .. "-" .. tostring(slot))
    DeleteCultivationKeys(commit, userId, CultivationKeys(slot, false))
    commit:Commit(CommitCallbacks(callbacks, "RankV2"))
end

function M.RemoveXianrenRank(userId, slot, callbacks)
    local commit = serverCloud:BatchCommit(
        "clear-xianren-rank-" .. tostring(userId) .. "-" .. tostring(slot))
    DeleteCultivationKeys(commit, userId, CultivationKeys(slot, true))
    commit:Commit(CommitCallbacks(callbacks, "XianrenRank"))
end

local function BuildXiuxianInfo(rankInfo, taptapNick)
    return {
        name = rankInfo.charName,
        realm = rankInfo.realm,
        level = rankInfo.level,
        bossKills = rankInfo.bossKills,
        taptapNick = taptapNick,
        classId = rankInfo.classId,
    }
end

function M.UpsertCultivationRank(userId, slot, rankInfo, coreData, taptapNick, callbacks)
    callbacks = callbacks or {}
    if not rankInfo then
        M.ClearCultivationRanks(userId, slot, callbacks)
        return
    end

    local targetKeys = CultivationKeys(slot, rankInfo.isImmortal)
    local otherKeys = CultivationKeys(slot, not rankInfo.isImmortal)
    local read = serverCloud:BatchGet(userId)
        :Key(targetKeys.score)
        :Key(targetKeys.time)
        :Key(targetKeys.info)
        :Key(otherKeys.score)
    if rankInfo.isImmortal then
        read:Key("account_immortal_bodies")
    end

    read:Fetch({
        ok = function(scores, iscores)
            scores = scores or {}
            iscores = iscores or {}
            local existingRaw, encodedTime = M.DecodeCompositeScore(
                iscores[targetKeys.score])
            local otherRaw = M.DecodeCompositeScore(iscores[otherKeys.score])
            local newRaw = ToInteger(rankInfo.rankScore) or 0
            if newRaw <= 0 then
                if callbacks.error then callbacks.error("INVALID_SCORE", "rank score <= 0") end
                return
            end
            local bestExistingRaw = math.max(existingRaw, otherRaw)
            if bestExistingRaw > newRaw then
                local staleKeys = existingRaw >= otherRaw and otherKeys or targetKeys
                print("[Server][Rank] ignored regression: userId=" .. tostring(userId)
                    .. " slot=" .. tostring(slot)
                    .. " existingRaw=" .. tostring(bestExistingRaw)
                    .. " incomingRaw=" .. tostring(newRaw))
                local repair = serverCloud:BatchCommit(
                    "repair-cultivation-regression-" .. tostring(userId)
                    .. "-" .. tostring(slot))
                DeleteCultivationKeys(repair, userId, staleKeys)
                repair:Commit(CommitCallbacks(
                    callbacks, "RankRegressionRepair", "regression_skipped"))
                return
            end

            local storedTime = ToInteger(iscores[targetKeys.time]) or encodedTime
            local achieveTime = existingRaw == newRaw and storedTime > 0
                and storedTime or os.time()
            local composite = M.BuildCompositeScore(rankInfo, achieveTime)
            local bossKills = math.max(0, ToInteger(rankInfo.bossKills) or 0)
            local accountBodies = scores.account_immortal_bodies
            local info = rankInfo.isImmortal
                and M.BuildImmortalInfo(
                    rankInfo, coreData, userId, slot, taptapNick, accountBodies)
                or BuildXiuxianInfo(rankInfo, taptapNick)

            local commit = serverCloud:BatchCommit(
                "upsert-cultivation-rank-" .. tostring(userId) .. "-" .. tostring(slot))
            DeleteCultivationKeys(commit, userId, otherKeys)
            commit:ScoreSetInt(userId, targetKeys.score, composite)
            commit:ScoreSetInt(userId, targetKeys.kills, bossKills)
            commit:ScoreSetInt(userId, targetKeys.time, achieveTime)
            commit:ScoreSet(userId, targetKeys.info, info)
            commit:Commit(CommitCallbacks(callbacks, "RankUpsert"))
        end,
        error = function(code, reason)
            print("[Server][RankUpsert] read FAILED: " .. tostring(code)
                .. " " .. tostring(reason))
            if callbacks.error then callbacks.error(code, reason) end
        end,
    })
end

function M.UpsertFloorRank(userId, options)
    local callbacks = options.callbacks or {}
    local floor = ToInteger(options.floor) or 0
    local maxFloor = ToInteger(options.maxFloor) or 0
    if floor < 0 or (maxFloor > 0 and floor > maxFloor) then
        print("[Server][" .. options.label .. "] rejected floor=" .. tostring(floor)
            .. " max=" .. tostring(maxFloor) .. " userId=" .. tostring(userId))
        if callbacks.error then callbacks.error("INVALID_FLOOR", tostring(floor)) end
        return
    end

    if floor == 0 then
        if not options.allowDecrease then
            if callbacks.ok then callbacks.ok("empty_skipped") end
            return
        end
        local clear = serverCloud:BatchCommit(
            "clear-" .. options.rankKey .. "-" .. tostring(userId))
        clear:ScoreDeleteInt(userId, options.rankKey)
        clear:ScoreDelete(userId, options.infoKey)
        clear:Commit(CommitCallbacks(callbacks, options.label))
        return
    end

    serverCloud:BatchGet(userId)
        :Key(options.rankKey)
        :Fetch({
            ok = function(_, iscores)
                local existingRaw, existingTime = M.DecodeCompositeScore(
                    iscores and iscores[options.rankKey])
                if existingRaw > floor and not options.allowDecrease then
                    if callbacks.ok then callbacks.ok("lower_floor_skipped") end
                    return
                end

                local achieveTime = existingRaw == floor and existingTime > 0
                    and existingTime or os.time()
                local composite = floor * RANK2_TIME_BASE
                    + (RANK2_TIME_BASE - 1 - achieveTime)
                local commit = serverCloud:BatchCommit(
                    "upsert-" .. options.rankKey .. "-" .. tostring(userId))
                commit:ScoreSetInt(userId, options.rankKey, composite)
                commit:ScoreSet(userId, options.infoKey, options.info)
                commit:Commit(CommitCallbacks(callbacks, options.label))
            end,
            error = function(code, reason)
                print("[Server][" .. options.label .. "] read FAILED: "
                    .. tostring(code) .. " " .. tostring(reason))
                if callbacks.error then callbacks.error(code, reason) end
            end,
        })
end

-- ============================================================================
-- ComputeRankFromSaveData — 存档→排行分数（服务端权威计算）
-- ============================================================================

--- P1: 校验 realm 合法性、level 范围，拒绝/修正异常数据
---@param coreData table 存档核心数据
---@return table|nil rankInfo 排行榜信息，nil 表示不满足排行条件或数据异常
---@return string|nil reason 拒绝原因（仅 nil 时有值）
local function ComputeRankFromSaveData(coreData)
    if not coreData or not coreData.player then
        return nil, "no_player_data"
    end
    local player = coreData.player
    local level = player.level
    if not level or type(level) ~= "number" then
        return nil, "invalid_level_type"
    end

    -- P1: 等级基本范围
    if level < 1 or level > 999 then
        return nil, "level_out_of_range"
    end

    -- 等级 <= 5 不上榜（正常业务规则）
    if level <= 5 then
        return nil, "level_too_low"
    end

    local realm = player.realm or "mortal"
    local realmCfg = GameConfig.REALMS[realm]

    -- P1: 境界必须在 GameConfig.REALMS 中存在
    if not realmCfg then
        print("[Server][AntiCheat] Invalid realm: " .. tostring(realm))
        return nil, "invalid_realm"
    end

    -- P1: 等级不得超过当前境界的 maxLevel
    local maxLevel = realmCfg.maxLevel or 999
    if level > maxLevel then
        print("[Server][AntiCheat] Level " .. level .. " exceeds maxLevel "
            .. maxLevel .. " for realm " .. realm .. ", capping")
        level = maxLevel
    end

    -- P1: 等级不得低于当前境界的 requiredLevel（如果有）
    local requiredLevel = realmCfg.requiredLevel or 0
    if level < requiredLevel then
        local isAscRealm = type(realm) == "string" and realm:sub(1, 4) == "asc_"
        if isAscRealm then
            print("[Server][Rank][LegacyAscension] Level " .. level .. " below requiredLevel "
                .. requiredLevel .. " for realm " .. realm .. ", allowing existing ascension rank")
        else
            print("[Server][AntiCheat] Level " .. level .. " below requiredLevel "
                .. requiredLevel .. " for realm " .. realm)
            return nil, "level_below_required"
        end
    end

    local realmOrder = realmCfg.order or 0
    local rankScore = realmOrder * 1000 + level
    local bossKills = coreData.bossKills
    if type(bossKills) ~= "number" then bossKills = 0 end

    return {
        rankScore = rankScore,
        level = level,
        realm = realm,
        realmOrder = realmOrder,
        bossKills = bossKills,
        charName = player.charName or "修仙者",
        classId = player.classId or "monk",
        isImmortal = IsImmortalRealm(realm, realmCfg),
    }
end
M.ComputeRankFromSaveData = ComputeRankFromSaveData

-- ============================================================================
-- RebuildRankOnLogin — 登录时排行榜重建
-- ============================================================================

--- P1-UI-1: 排行榜重建（从 GetUserNickname 回调中调用，确保 taptapNick 已就绪）
---@param userId number
---@param slotsIndex table
---@param getSlotData function
---@param taptapNick string
local function RebuildRankOnLogin(userId, slotsIndex, getSlotData, taptapNick)
    for slot = 1, 4 do
        local saveData = getSlotData(slot)
        if saveData and saveData.player then
            local rankInfo = ComputeRankFromSaveData(saveData)
            if rankInfo then
                local slotMeta = slotsIndex.slots and slotsIndex.slots[slot]
                if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                    rankInfo.charName = slotMeta.name
                end
            end
            M.UpsertCultivationRank(userId, slot, rankInfo, saveData, taptapNick, {
                error = function(code, reason)
                    print("[Server] Rank login repair FAILED: userId=" .. tostring(userId)
                        .. " slot=" .. tostring(slot)
                        .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
        else
            M.ClearCultivationRanks(userId, slot, {
                error = function(code, reason)
                    print("[Server] Rank empty-slot clear FAILED: userId=" .. tostring(userId)
                        .. " slot=" .. tostring(slot)
                        .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
        end
    end

    M.RebuildAccountTowerRanks(userId, slotsIndex, getSlotData, taptapNick, {
        error = function(code, reason)
            print("[Server] Tower login repair FAILED: userId=" .. tostring(userId)
                .. " err=" .. tostring(code) .. " " .. tostring(reason))
        end,
    })

    -- ═══ 仙石榜（xianshi_rank）: 仙石>0 的账号永久入榜 ═══
    -- 单向操作：一旦入榜不删除，即使仙石后续变为 0
    serverCloud.money:Get(userId, {
        ok = function(playerMoneys)
            local xianshi = playerMoneys and playerMoneys.xianshi or 0
            if xianshi > 0 then
                serverCloud:SetInt(userId, "xianshi_rank", xianshi, {
                    error = function(code, reason)
                        print("[Server] xianshi_rank SetInt FAILED: userId=" .. tostring(userId)
                            .. " err=" .. tostring(code) .. " " .. tostring(reason))
                    end,
                })
                local xsBatch = serverCloud:BatchSet(userId)
                xsBatch:Set("xianshi_info", {
                    xianshi = xianshi,
                    taptapNick = taptapNick,
                })
                xsBatch:Save("仙石榜入榜", {
                    ok = function()
                        print("[Server] xianshi_rank: enrolled userId=" .. tostring(userId)
                            .. " xianshi=" .. xianshi .. " nick=" .. tostring(taptapNick))
                    end,
                    error = function(code, reason)
                        print("[Server] xianshi_rank info save FAILED: " .. tostring(code)
                            .. " " .. tostring(reason))
                    end,
                })
            end
        end,
        error = function(code, reason)
            print("[Server] xianshi_rank money:Get FAILED: userId=" .. tostring(userId)
                .. " err=" .. tostring(code) .. " " .. tostring(reason))
        end,
    })
end
M.RebuildRankOnLogin = RebuildRankOnLogin

local function SlotCharacterName(slotsIndex, slot, saveData)
    local slotMeta = slotsIndex and slotsIndex.slots and slotsIndex.slots[slot]
    if slotMeta and slotMeta.name and slotMeta.name ~= "" then
        return slotMeta.name
    end
    local player = saveData and saveData.player
    return player and player.charName or "修仙者"
end

local function BuildTowerInfo(slotsIndex, slot, saveData, floor, taptapNick)
    local player = saveData and saveData.player or {}
    return {
        floor = floor,
        name = SlotCharacterName(slotsIndex, slot, saveData),
        realm = player.realm or "mortal",
        level = player.level or 1,
        taptapNick = taptapNick,
        classId = player.classId or "monk",
    }
end

local function IsTrialFloorValid(saveData, floor)
    if floor < 1 or floor > TrialTowerConfig.MAX_FLOOR then return false end
    local player = saveData and saveData.player
    if not player then return false end
    local realmCfg = GameConfig.REALMS[player.realm or "mortal"]
    local order = realmCfg and realmCfg.order or 0
    local required = TrialTowerConfig.GetRealmByFloor(floor)
    local requiredOrder = TrialTowerConfig.GetRequiredOrderByFloor(floor)
    if order >= M.XIANREN_FIRST_REALM_ORDER then
        return required ~= nil and order >= requiredOrder
    end
    return required ~= nil
        and order >= requiredOrder
        and (tonumber(player.level) or 0) >= (required.reqLevel or 1)
end

local function IsPrisonFloorValid(saveData, floor)
    if floor < 1 or floor > PrisonTowerConfig.MAX_FLOOR then return false end
    local player = saveData and saveData.player
    if not player then return false end
    local realmCfg = GameConfig.REALMS[player.realm or "mortal"]
    local order = realmCfg and realmCfg.order or 0
    local required = PrisonTowerConfig.GetRealmByFloor(floor)
    local requiredCfg = required and GameConfig.REALMS[required.id]
    local requiredOrder = requiredCfg and requiredCfg.order
        or PrisonTowerConfig.REQUIRED_REALM_ORDER
    return required ~= nil
        and order >= requiredOrder
        and (tonumber(player.level) or 0) >= (required.reqLevel or PrisonTowerConfig.REQUIRED_LEVEL)
end

function M.RebuildAccountTowerRanks(userId, slotsIndex, getSlotData, taptapNick, callbacks)
    callbacks = callbacks or {}
    local bestTrialFloor = 0
    local bestTrialSlotData = nil
    local bestTrialSlot = 0
    local invalidTrialCandidate = false
    local bestPrisonFloor = 0
    local bestPrisonSlotData = nil
    local bestPrisonSlot = 0
    local invalidPrisonCandidate = false

    for rSlot = 1, 4 do
        local rSaveData = getSlotData(rSlot)
        if rSaveData
            and rSaveData.trialTower and type(rSaveData.trialTower) == "table" then
            local hf = ToInteger(rSaveData.trialTower.highestFloor) or 0
            if hf > bestTrialFloor and IsTrialFloorValid(rSaveData, hf) then
                bestTrialFloor = hf
                bestTrialSlot = rSlot
                bestTrialSlotData = rSaveData
            elseif hf > 0 and not IsTrialFloorValid(rSaveData, hf) then
                invalidTrialCandidate = true
                print("[Server][AntiCheat] invalid trial floor=" .. tostring(hf)
                    .. " userId=" .. tostring(userId) .. " slot=" .. tostring(rSlot))
            end
        end
        if rSaveData
            and rSaveData.prisonTower and type(rSaveData.prisonTower) == "table" then
            local hf = ToInteger(rSaveData.prisonTower.highestFloor) or 0
            if hf > bestPrisonFloor and IsPrisonFloorValid(rSaveData, hf) then
                bestPrisonFloor = hf
                bestPrisonSlot = rSlot
                bestPrisonSlotData = rSaveData
            elseif hf > 0 and not IsPrisonFloorValid(rSaveData, hf) then
                invalidPrisonCandidate = true
                print("[Server][AntiCheat] invalid prison floor=" .. tostring(hf)
                    .. " userId=" .. tostring(userId) .. " slot=" .. tostring(rSlot))
            end
        end
    end

    local pending = 2
    local failed = false
    local firstCode = nil
    local firstReason = nil
    local function Done(code, reason)
        if code ~= nil then
            failed = true
            firstCode = firstCode or code
            firstReason = firstReason or reason
        end
        pending = pending - 1
        if pending == 0 then
            if failed then
                if callbacks.error then callbacks.error(firstCode, firstReason) end
            elseif callbacks.ok then
                callbacks.ok()
            end
        end
    end

    M.UpsertFloorRank(userId, {
        label = "TrialRank",
        rankKey = "trial_floor",
        infoKey = "trial_info",
        floor = bestTrialFloor,
        maxFloor = TrialTowerConfig.MAX_FLOOR,
        allowDecrease = not (bestTrialFloor == 0 and invalidTrialCandidate),
        info = BuildTowerInfo(
            slotsIndex, bestTrialSlot, bestTrialSlotData, bestTrialFloor, taptapNick),
        callbacks = {
            ok = function() Done() end,
            error = Done,
        },
    })
    M.UpsertFloorRank(userId, {
        label = "PrisonRank",
        rankKey = "prison_floor",
        infoKey = "prison_info",
        floor = bestPrisonFloor,
        maxFloor = PrisonTowerConfig.MAX_FLOOR,
        allowDecrease = not (bestPrisonFloor == 0 and invalidPrisonCandidate),
        info = BuildTowerInfo(
            slotsIndex, bestPrisonSlot, bestPrisonSlotData, bestPrisonFloor, taptapNick),
        callbacks = {
            ok = function() Done() end,
            error = Done,
        },
    })
end

function M.UpdateTowerRanksFromSave(userId, slot, slotsIndex, coreData, taptapNick, callbacks)
    callbacks = callbacks or {}
    local pending = 2
    local failed = false
    local firstCode = nil
    local firstReason = nil
    local function Done(code, reason)
        if code ~= nil then
            failed = true
            firstCode = firstCode or code
            firstReason = firstReason or reason
        end
        pending = pending - 1
        if pending == 0 then
            if failed then
                if callbacks.error then callbacks.error(firstCode, firstReason) end
            elseif callbacks.ok then
                callbacks.ok()
            end
        end
    end

    local trialFloor = coreData.trialTower
        and ToInteger(coreData.trialTower.highestFloor) or 0
    if trialFloor > 0 and not IsTrialFloorValid(coreData, trialFloor) then
        trialFloor = TrialTowerConfig.MAX_FLOOR + 1
    end
    M.UpsertFloorRank(userId, {
        label = "TrialRank",
        rankKey = "trial_floor",
        infoKey = "trial_info",
        floor = trialFloor,
        maxFloor = TrialTowerConfig.MAX_FLOOR,
        allowDecrease = false,
        info = BuildTowerInfo(slotsIndex, slot, coreData, trialFloor, taptapNick),
        callbacks = {
            ok = function() Done() end,
            error = Done,
        },
    })

    local prisonFloor = coreData.prisonTower
        and ToInteger(coreData.prisonTower.highestFloor) or 0
    if prisonFloor > 0 and not IsPrisonFloorValid(coreData, prisonFloor) then
        prisonFloor = PrisonTowerConfig.MAX_FLOOR + 1
    end
    M.UpsertFloorRank(userId, {
        label = "PrisonRank",
        rankKey = "prison_floor",
        infoKey = "prison_info",
        floor = prisonFloor,
        maxFloor = PrisonTowerConfig.MAX_FLOOR,
        allowDecrease = false,
        info = BuildTowerInfo(slotsIndex, slot, coreData, prisonFloor, taptapNick),
        callbacks = {
            ok = function() Done() end,
            error = Done,
        },
    })
end

-- ============================================================================
-- HandleGetRankList — 排行榜查询
-- ============================================================================

function M.HandleGetRankList(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local rankKey = eventData["rankKey"]:GetString()
    local start = eventData["start"]:GetInt()
    local count = eventData["count"]:GetInt()
    local extraKeysJson = eventData["extraKeys"]:GetString()
    -- 读取客户端传来的 requestId（用于回调精确匹配）
    local requestId = 0
    pcall(function() requestId = eventData["requestId"]:GetInt() end)

    print("[Server] GetRankList: userId=" .. tostring(userId)
        .. " key=" .. rankKey .. " start=" .. start .. " count=" .. count
        .. " reqId=" .. requestId)

    -- 解析附加字段
    local extraKeys = {}
    if extraKeysJson and extraKeysJson ~= "" then
        local ok, decoded = pcall(cjson.decode, extraKeysJson)
        if ok and type(decoded) == "table" then
            extraKeys = decoded
        end
    end

    -- serverCloud:GetRankList 的 start 是 1-based，客户端传来的是 0-based，需要 +1
    local adjustedStart = start + 1

    -- serverCloud:GetRankList 不支持附加 key 参数（与 clientCloud 不同）
    -- 需要先拿排名，再用 BatchGet 补查附加字段
    serverCloud:GetRankList(rankKey, adjustedStart, count, {
        ok = function(rankList)
            -- ── [AdminPenalty] suppressRank: 过滤被屏蔽的 UID（xianshi_rank 豁免）──
            rankList = AdminPenaltyControl.FilterRankList(rankList, rankKey)

            -- 无附加字段或无结果 → 直接返回
            if #extraKeys == 0 or #rankList == 0 then
                local resultData = VariantMap()
                resultData["ok"] = Variant(true)
                resultData["rankKey"] = Variant(rankKey)
                resultData["rankList"] = Variant(cjson.encode(rankList))
                resultData["requestId"] = Variant(requestId)
                SafeSend(connection, SaveProtocol.S2C_RankListData, resultData)
                print("[Server] RankList sent (no extras): key=" .. rankKey .. " entries=" .. #rankList)
                return
            end

            -- 用单人 BatchGet 逐个补查附加字段
            -- （多人 BatchGet():Player() 模式返回空结果，改用单人模式）
            local uniqueUserIds = {}
            local uidSet = {}
            for _, item in ipairs(rankList) do
                local uidStr = tostring(item.userId)
                if not uidSet[uidStr] then
                    uidSet[uidStr] = true
                    table.insert(uniqueUserIds, item.userId)
                end
            end

            local extraMap = {}
            local fetchDone = 0
            local fetchTotal = #uniqueUserIds
            local fetchFailures = 0

            local function onAllFetched()
                -- 合并附加字段到 rankList
                for _, item in ipairs(rankList) do
                    local extra = extraMap[tostring(item.userId)]
                    if extra then
                        if extra.iscore then
                            if not item.iscore then item.iscore = {} end
                            for k, v in pairs(extra.iscore) do
                                if item.iscore[k] == nil then
                                    item.iscore[k] = v
                                end
                            end
                        end
                        if extra.score then
                            if not item.score then item.score = {} end
                            for k, v in pairs(extra.score) do
                                if item.score[k] == nil then
                                    item.score[k] = v
                                end
                            end
                        end
                    end
                end

                local resultData = VariantMap()
                resultData["ok"] = Variant(true)
                resultData["rankKey"] = Variant(rankKey)
                resultData["rankList"] = Variant(cjson.encode(rankList))
                resultData["requestId"] = Variant(requestId)
                SafeSend(connection, SaveProtocol.S2C_RankListData, resultData)
                print("[Server] RankList sent (with extras): key=" .. rankKey
                    .. " entries=" .. #rankList .. " extraKeys=" .. #extraKeys
                    .. " fetchFailures=" .. fetchFailures)
            end

            for _, uid in ipairs(uniqueUserIds) do
                local bg = serverCloud:BatchGet(uid)
                for _, ek in ipairs(extraKeys) do
                    bg:Key(ek)
                end
                bg:Fetch({
                    ok = function(scores, iscores)
                        extraMap[tostring(uid)] = { score = scores, iscore = iscores }
                        fetchDone = fetchDone + 1
                        if fetchDone >= fetchTotal then onAllFetched() end
                    end,
                    error = function(code, reason)
                        fetchFailures = fetchFailures + 1
                        print("[Server] BatchGet(single) FAILED uid=" .. tostring(uid)
                            .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
                        fetchDone = fetchDone + 1
                        if fetchDone >= fetchTotal then onAllFetched() end
                    end,
                })
            end
        end,
        error = function(code, reason)
            print("[Server] GetRankList ERROR: " .. tostring(code) .. " " .. tostring(reason))
            local resultData = VariantMap()
            resultData["ok"] = Variant(false)
            resultData["rankKey"] = Variant(rankKey)
            resultData["message"] = Variant(tostring(reason))
            resultData["requestId"] = Variant(requestId)
            SafeSend(connection, SaveProtocol.S2C_RankListData, resultData)
        end,
    })
end

-- ============================================================================
-- HandleTryUnlockRace — 竞速道印占位（先人一步·化神/合体）
-- ============================================================================

--- 合法的竞速道印 ID 及其对应排行榜 key 和名额上限
local RACE_MEDAL_CONFIG = {
    pioneer_huashen = { rankKey = "pioneer_huashen", maxSlots = 10 },
    pioneer_heti    = { rankKey = "pioneer_heti",    maxSlots = 10 },
}
M.RACE_MEDAL_CONFIG = RACE_MEDAL_CONFIG

function M.HandleTryUnlockRace(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local medalId = eventData["medalId"]:GetString()
    print("[Server] TryUnlockRace: userId=" .. tostring(userId) .. " medalId=" .. tostring(medalId))

    -- 校验 medalId 合法性
    local config = RACE_MEDAL_CONFIG[medalId]
    if not config then
        print("[Server] TryUnlockRace: invalid medalId=" .. tostring(medalId))
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["medalId"] = Variant(medalId)
        data["msg"] = Variant("invalid_medal")
        SafeSend(connection, SaveProtocol.S2C_TryUnlockRaceResult, data)
        return
    end

    local rankKey = config.rankKey
    local maxSlots = config.maxSlots

    -- 乐观锁：先 SetInt 占位，再 GetRankList 验证排名，超额则 Delete 回滚
    -- 消除 TOCTOU 竞争窗口（旧方案 GetRankList→check→SetInt 在高并发下可超发名额）
    local submitTime = os.time()
    serverCloud:SetInt(userId, rankKey, submitTime, {
        ok = function()
            -- 占位成功，验证实际排名
            serverCloud:GetUserRank(userId, rankKey, {
                ok = function(rankInfo)
                    local myRank = rankInfo and rankInfo.rank or 0
                    if myRank >= 1 and myRank <= maxSlots then
                        -- 在名额内，成功
                        print("[Server] TryUnlockRace OK: userId=" .. tostring(userId)
                            .. " medal=" .. medalId .. " rank=" .. myRank .. "/" .. maxSlots)
                        local data = VariantMap()
                        data["ok"] = Variant(true)
                        data["medalId"] = Variant(medalId)
                        data["alreadyHad"] = Variant(false)
                        data["count"] = Variant(myRank)
                        data["maxSlots"] = Variant(maxSlots)
                        SafeSend(connection, SaveProtocol.S2C_TryUnlockRaceResult, data)
                    else
                        -- 超出名额，回滚删除
                        print("[Server] TryUnlockRace ROLLBACK: userId=" .. tostring(userId)
                            .. " rank=" .. myRank .. " exceeds maxSlots=" .. maxSlots)
                        serverCloud:Delete(userId, rankKey, {
                            ok = function()
                                print("[Server] TryUnlockRace rollback Delete OK")
                            end,
                            error = function(c2, r2)
                                print("[Server] TryUnlockRace rollback Delete FAILED: " .. tostring(r2))
                            end,
                        })
                        local data = VariantMap()
                        data["ok"] = Variant(false)
                        data["medalId"] = Variant(medalId)
                        data["msg"] = Variant("full")
                        data["count"] = Variant(myRank)
                        data["maxSlots"] = Variant(maxSlots)
                        SafeSend(connection, SaveProtocol.S2C_TryUnlockRaceResult, data)
                    end
                end,
                error = function(code, reason)
                    -- 验证失败，保守回滚
                    print("[Server] TryUnlockRace GetUserRank FAILED: " .. tostring(reason) .. ", rolling back")
                    serverCloud:Delete(userId, rankKey, {
                        ok = function() end,
                        error = function() end,
                    })
                    local data = VariantMap()
                    data["ok"] = Variant(false)
                    data["medalId"] = Variant(medalId)
                    data["msg"] = Variant("服务器错误，请重试")
                    SafeSend(connection, SaveProtocol.S2C_TryUnlockRaceResult, data)
                end,
            })
        end,
        error = function(code, reason)
            print("[Server] TryUnlockRace SetInt FAILED: " .. tostring(reason))
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["medalId"] = Variant(medalId)
            data["msg"] = Variant("服务器错误，请重试")
            SafeSend(connection, SaveProtocol.S2C_TryUnlockRaceResult, data)
        end,
    })
end

-- ============================================================================
-- HandleCheckEventGrant — event_grant 道印：服务端代查排行榜
-- 客户端无 clientCloud，改由服务端查 serverCloud 排行
-- ============================================================================

function M.HandleCheckEventGrant(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local leaderboard = eventData["leaderboard"]:GetString()
    local medalId = eventData["medalId"]:GetString()
    print("[Server] CheckEventGrant: userId=" .. tostring(userId)
        .. " medalId=" .. medalId .. " leaderboard=" .. leaderboard)

    -- 用 serverCloud:Get 查询该玩家是否有 iscore 记录（等价于原 clientCloud:GetMyScore）
    -- xianshi_rank 通过 SetInt 写入 iscores，所以从 iscores 读取
    serverCloud:Get(userId, leaderboard, {
        ok = function(scores, iscores)
            local onBoard = false
            local score = 0
            -- SetInt 写入的值在 iscores 中
            local ival = iscores and iscores[leaderboard]
            if ival and ival > 0 then
                onBoard = true
                score = ival
            end
            -- 也检查 scores 以防数据通过 Set 写入
            if not onBoard then
                local sval = scores and scores[leaderboard]
                if sval and type(sval) == "number" and sval > 0 then
                    onBoard = true
                    score = sval
                end
            end
            print("[Server] CheckEventGrant result: userId=" .. tostring(userId)
                .. " leaderboard=" .. leaderboard
                .. " onBoard=" .. tostring(onBoard) .. " score=" .. tostring(score)
                .. " iscores=" .. tostring(iscores and iscores[leaderboard])
                .. " scores=" .. tostring(scores and scores[leaderboard]))
            local data = VariantMap()
            data["ok"] = Variant(true)
            data["medalId"] = Variant(medalId)
            data["leaderboard"] = Variant(leaderboard)
            data["onBoard"] = Variant(onBoard)
            data["score"] = Variant(score)
            SafeSend(connection, SaveProtocol.S2C_CheckEventGrantResult, data)
        end,
        error = function(code, reason)
            print("[Server] CheckEventGrant ERROR: userId=" .. tostring(userId)
                .. " leaderboard=" .. leaderboard
                .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["medalId"] = Variant(medalId)
            data["leaderboard"] = Variant(leaderboard)
            data["msg"] = Variant(tostring(reason))
            SafeSend(connection, SaveProtocol.S2C_CheckEventGrantResult, data)
        end,
    })
end

-- ============================================================================
-- HandleCheckRaceSlots — 竞速道印名额查询（服务端代查）
-- ============================================================================

function M.HandleCheckRaceSlots(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local medalId = eventData["medalId"]:GetString()
    local leaderboard = eventData["leaderboard"]:GetString()
    local maxSlots = eventData["maxSlots"]:GetInt()
    print("[Server] CheckRaceSlots: userId=" .. tostring(userId)
        .. " medalId=" .. medalId .. " leaderboard=" .. leaderboard
        .. " maxSlots=" .. maxSlots)

    serverCloud:GetRankList(leaderboard, 1, maxSlots, {
        ok = function(rankList)
            local count = rankList and #rankList or 0
            local isFull = count >= maxSlots
            print("[Server] CheckRaceSlots result: leaderboard=" .. leaderboard
                .. " count=" .. count .. " isFull=" .. tostring(isFull))
            local data = VariantMap()
            data["ok"] = Variant(true)
            data["medalId"] = Variant(medalId)
            data["leaderboard"] = Variant(leaderboard)
            data["count"] = Variant(count)
            data["maxSlots"] = Variant(maxSlots)
            data["isFull"] = Variant(isFull)
            SafeSend(connection, SaveProtocol.S2C_CheckRaceSlotsResult, data)
        end,
        error = function(code, reason)
            print("[Server] CheckRaceSlots ERROR: leaderboard=" .. leaderboard
                .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["medalId"] = Variant(medalId)
            data["leaderboard"] = Variant(leaderboard)
            data["msg"] = Variant(tostring(reason))
            SafeSend(connection, SaveProtocol.S2C_CheckRaceSlotsResult, data)
        end,
    })
end

return M
