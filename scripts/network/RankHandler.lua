-- ============================================================================
-- RankHandler.lua — 排行榜 + 竞速道印 服务端 Handler
--
-- 职责：ComputeRankFromSaveData / RebuildRankOnLogin / HandleGetRankList
--       HandleTryUnlockRace / RACE_MEDAL_CONFIG
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B3）
-- ============================================================================

local Session      = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local GameConfig   = require("config.GameConfig")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local ConnKey   = Session.ConnKey
local GetUserId = Session.GetUserId
local SafeSend  = Session.SafeSend

local M = {}

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
        print("[Server][AntiCheat] Level " .. level .. " below requiredLevel "
            .. requiredLevel .. " for realm " .. realm)
        return nil, "level_below_required"
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
    local rankRepairBatch = nil
    for slot = 1, 4 do
        local saveData = getSlotData(slot)

        -- 有有效存档就无条件入榜（不检查是否已存在）
        if saveData and saveData.player then
            local rankInfo = ComputeRankFromSaveData(saveData)
            if rankInfo then
                -- 角色名优先从 slotsIndex 取（save_data.player.charName 大多数存档为 nil）
                local slotMeta = slotsIndex.slots and slotsIndex.slots[slot]
                if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                    rankInfo.charName = slotMeta.name
                end

                -- 顶层 SetInt 写排行分数（确保排行索引更新）
                serverCloud:SetInt(userId, "rank2_score_" .. slot, rankInfo.rankScore, {
                    error = function(code, reason)
                        print("[Server] RankV2 login SetInt rank2_score FAILED: userId=" .. tostring(userId)
                            .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
                    end,
                })
                serverCloud:SetInt(userId, "rank2_kills_" .. slot, rankInfo.bossKills, {
                    error = function(code, reason)
                        print("[Server] RankV2 login SetInt rank2_kills FAILED: userId=" .. tostring(userId)
                            .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
                    end,
                })
                serverCloud:SetInt(userId, "rank2_time_" .. slot, os.time(), {
                    error = function(code, reason)
                        print("[Server] RankV2 login SetInt rank2_time FAILED: userId=" .. tostring(userId)
                            .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
                    end,
                })

                -- batch 写附加 scores 信息（含 TapTap 昵称）
                if not rankRepairBatch then
                    rankRepairBatch = serverCloud:BatchSet(userId)
                end
                rankRepairBatch:Set("rank2_info_" .. slot, {
                    name = rankInfo.charName,
                    realm = rankInfo.realm,
                    level = rankInfo.level,
                    bossKills = rankInfo.bossKills,
                    taptapNick = taptapNick,
                    classId = rankInfo.classId,
                })
                print("[Server] RankV2: enrolled userId="
                    .. tostring(userId) .. " slot=" .. slot
                    .. " score=" .. rankInfo.rankScore
                    .. " name=" .. rankInfo.charName
                    .. " taptapNick=" .. tostring(taptapNick))
            end
        end
    end

    -- ═══ 青云试炼排行榜修复（per-user，取全部角色中最高层）═══
    local bestTrialFloor = 0
    local bestTrialSlotData = nil
    local bestTrialSlot = 0
    for rSlot = 1, 4 do
        local rSaveData = getSlotData(rSlot)
        if rSaveData
            and rSaveData.trialTower and type(rSaveData.trialTower) == "table" then
            local hf = rSaveData.trialTower.highestFloor
            if hf and type(hf) == "number" and hf > bestTrialFloor then
                bestTrialFloor = hf
                bestTrialSlot = rSlot
                bestTrialSlotData = rSaveData
            end
        end
    end
    if bestTrialFloor > 0 then
        local TRIAL_TIME_BASE = 10000000000
        local trialComposite = bestTrialFloor * TRIAL_TIME_BASE
            + (TRIAL_TIME_BASE - 1 - os.time())
        serverCloud:SetInt(userId, "trial_floor", trialComposite, {
            error = function(code, reason)
                print("[Server] Trial login SetInt FAILED: userId=" .. tostring(userId)
                    .. " err=" .. tostring(code) .. " " .. tostring(reason))
            end,
        })
        local trialCharName = "修仙者"
        local trialSlotMeta = slotsIndex.slots and slotsIndex.slots[bestTrialSlot]
        if trialSlotMeta and trialSlotMeta.name and trialSlotMeta.name ~= "" then
            trialCharName = trialSlotMeta.name
        elseif bestTrialSlotData.player and bestTrialSlotData.player.charName then
            trialCharName = bestTrialSlotData.player.charName
        end
        if not rankRepairBatch then
            rankRepairBatch = serverCloud:BatchSet(userId)
        end
        rankRepairBatch:Set("trial_info", {
            floor = bestTrialFloor,
            name = trialCharName,
            realm = bestTrialSlotData.player and bestTrialSlotData.player.realm or "mortal",
            level = bestTrialSlotData.player and bestTrialSlotData.player.level or 1,
            taptapNick = taptapNick,
            classId = bestTrialSlotData.player and bestTrialSlotData.player.classId or "monk",
        })
        print("[Server] Trial: login repair userId=" .. tostring(userId)
            .. " bestFloor=" .. bestTrialFloor .. " slot=" .. bestTrialSlot)
    end

    -- ═══ 青云镇狱塔排行榜修复（per-user，取全部角色中最高层）═══
    local bestPrisonFloor = 0
    local bestPrisonSlotData = nil
    local bestPrisonSlot = 0
    for rSlot = 1, 4 do
        local rSaveData = getSlotData(rSlot)
        if rSaveData
            and rSaveData.prisonTower and type(rSaveData.prisonTower) == "table" then
            local hf = rSaveData.prisonTower.highestFloor
            if hf and type(hf) == "number" and hf > bestPrisonFloor then
                bestPrisonFloor = hf
                bestPrisonSlot = rSlot
                bestPrisonSlotData = rSaveData
            end
        end
    end
    if bestPrisonFloor > 0 then
        -- 反作弊验证
        local prisonValid = true
        if bestPrisonFloor > 150 then
            print("[Server][AntiCheat] prison floor exceeds max: " .. bestPrisonFloor)
            prisonValid = false
        end
        if prisonValid and bestPrisonSlotData and bestPrisonSlotData.player then
            local pRealm = bestPrisonSlotData.player.realm or "mortal"
            local pRealmCfg = GameConfig.REALMS[pRealm]
            local pOrder = pRealmCfg and pRealmCfg.order or 0
            if pOrder < 7 then
                print("[Server][AntiCheat] prison requires jindan_1, got " .. pRealm)
                prisonValid = false
            end
            local pLevel = bestPrisonSlotData.player.level or 0
            if pLevel < 40 then
                print("[Server][AntiCheat] prison requires level 40, got " .. pLevel)
                prisonValid = false
            end
        end

        if prisonValid then
            local PRISON_TIME_BASE = 10000000000
            local prisonComposite = bestPrisonFloor * PRISON_TIME_BASE
                + (PRISON_TIME_BASE - 1 - os.time())
            serverCloud:SetInt(userId, "prison_floor", prisonComposite, {
                error = function(code, reason)
                    print("[Server] Prison login SetInt FAILED: userId=" .. tostring(userId)
                        .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
            local prisonCharName = "修仙者"
            local prisonSlotMeta = slotsIndex.slots and slotsIndex.slots[bestPrisonSlot]
            if prisonSlotMeta and prisonSlotMeta.name and prisonSlotMeta.name ~= "" then
                prisonCharName = prisonSlotMeta.name
            elseif bestPrisonSlotData.player and bestPrisonSlotData.player.charName then
                prisonCharName = bestPrisonSlotData.player.charName
            end
            if not rankRepairBatch then
                rankRepairBatch = serverCloud:BatchSet(userId)
            end
            rankRepairBatch:Set("prison_info", {
                floor = bestPrisonFloor,
                name = prisonCharName,
                realm = bestPrisonSlotData.player and bestPrisonSlotData.player.realm or "mortal",
                level = bestPrisonSlotData.player and bestPrisonSlotData.player.level or 1,
                taptapNick = taptapNick,
                classId = bestPrisonSlotData.player and bestPrisonSlotData.player.classId or "monk",
            })
            print("[Server] Prison: login repair userId=" .. tostring(userId)
                .. " bestFloor=" .. bestPrisonFloor .. " slot=" .. bestPrisonSlot)
        end
    end

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
                -- 附加信息（TapTap 昵称用于 UI 显示）
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

    -- 附加信息写回（fire-and-forget，不阻塞登录流程）
    if rankRepairBatch then
        rankRepairBatch:Save("v2排行榜入榜", {
            ok = function()
                print("[Server] RankV2 info saved for userId=" .. tostring(userId))
            end,
            error = function(code, reason)
                print("[Server] RankV2 info save FAILED: " .. tostring(code)
                    .. " " .. tostring(reason))
            end,
        })
    end
end
M.RebuildRankOnLogin = RebuildRankOnLogin

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
                    .. " entries=" .. #rankList .. " extraKeys=" .. #extraKeys)
            end

            for _, uid in ipairs(uniqueUserIds) do
                local bg = serverCloud:BatchGet(uid)
                for _, ek in ipairs(extraKeys) do
                    bg:Key(ek)
                end
                bg:Fetch({
                    ok = function(scores, iscores)
                        extraMap[tostring(uid)] = { score = scores, iscore = iscores }
                        print("[Server] BatchGet(single) uid=" .. tostring(uid)
                            .. " scores=" .. (scores and cjson.encode(scores) or "nil")
                            .. " iscores=" .. (iscores and cjson.encode(iscores) or "nil"))
                        fetchDone = fetchDone + 1
                        if fetchDone >= fetchTotal then onAllFetched() end
                    end,
                    error = function(code, reason)
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
