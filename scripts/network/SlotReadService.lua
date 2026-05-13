-- ============================================================================
-- SlotReadService.lua — FetchSlots 服务壳
--
-- R3 等价拆分第一阶段：从 server_main.lua 原位平移 HandleFetchSlots 逻辑。
-- 本模块仅负责 FetchSlots 主链，不涉及黑市/WAL/交易历史等旁路。
--
-- 变更历史：
--   2026-05-13  R3 创建 — 等价平移，不重写业务
-- ============================================================================

local SlotReadService = {}

local GameConfig   = require("config.GameConfig")
local SaveProtocol = require("network.SaveProtocol")
local Session      = require("network.ServerSession")
local RankHandler  = require("network.RankHandler")
local Logger       = require("utils.Logger")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

-- ============================================================================
-- 本地工具（等价平移自 server_main.lua）
-- ============================================================================

local SafeSend            = Session.SafeSend
local NormalizeSlotsIndex = Session.NormalizeSlotsIndex

local function SendResult(connection, eventName, success, message)
    local data = VariantMap()
    data["ok"] = Variant(success)
    if message then
        data["message"] = Variant(message)
    end
    SafeSend(connection, eventName, data)
end

-- ============================================================================
-- FetchSlots 主入口
--
-- 分区说明（R3 §8.3）：
--   [主存档正文]     save_{slot} / slots_index 读取与自愈
--   [账号级旁路]     account_bulletin / account_atlas / account_cosmetics
--   [排行旁路]       rank_score_{slot} — 登录重建（委托 RankHandler）
--   [管理员一次性]   UID 1074886667 仙石扣除 + 皮肤解锁
--
-- ※ 黑市相关（BM handler / WAL / 交易历史 / 兑换 / 自动收购）
--   不在本 service 范围内，亦不在此处调用。
-- ============================================================================

--- Execute: 等价于原 HandleFetchSlots 函数体
---@param connection userdata    引擎 Connection 对象
---@param connKey   string       连接标识
---@param userId    integer      玩家 userId
function SlotReadService.Execute(connection, connKey, userId)
    Logger.info("FetchSlots", "userId=" .. tostring(userId))

    -- ── [主存档正文 + 账号级旁路 + 排行旁路] 批量读取 ──
    serverCloud:BatchGet(userId)
        :Key("slots_index")
        :Key("save_1"):Key("save_2"):Key("save_3"):Key("save_4")
        :Key("save_data_1"):Key("save_data_2"):Key("save_data_3"):Key("save_data_4")
        :Key("account_bulletin")
        :Key("account_atlas")
        :Key("account_cosmetics")
        :Key("rank_score_1")
        :Key("rank_score_2")
        :Key("rank_score_3")
        :Key("rank_score_4")
        :Fetch({
            ok = function(scores, iscores, sscores)
                local slotsIndex = scores["slots_index"]
                local bulletin = scores["account_bulletin"]

                -- 如果没有 slots_index，返回空（新玩家）
                if not slotsIndex then
                    slotsIndex = { version = 1, slots = {} }
                end

                -- 归一化 slots key
                NormalizeSlotsIndex(slotsIndex)

                -- ── [主存档正文] v11/v10 合并辅助 ──
                local function getSlotData(s)
                    local v11 = scores["save_" .. s]
                    if v11 and type(v11) == "table" then return v11 end
                    local v10 = scores["save_data_" .. s]
                    if v10 and type(v10) == "table" then return v10 end
                    return nil
                end

                -- ── [主存档正文] 正向验证：索引有条目但数据丢失 ──
                slotsIndex.slots = slotsIndex.slots or {}
                for slot = 1, 4 do
                    if slotsIndex.slots[slot] then
                        local hasData = getSlotData(slot) ~= nil
                        if not hasData then
                            slotsIndex.slots[slot].dataLost = true
                            Logger.warn("FetchSlots", "Slot " .. slot
                                .. " index exists but save data MISSING for userId=" .. tostring(userId))
                        end
                    end
                end

                -- ── [主存档正文] 反向验证：孤儿存档自愈 ──
                local needRepair = false
                for slot = 1, 4 do
                    if not slotsIndex.slots[slot] then
                        local saveData = getSlotData(slot)
                        if saveData and saveData.player then
                            local p = saveData.player
                            local realm = p.realm or "mortal"
                            local realmCfg = GameConfig.REALMS[realm]
                            local realmName = realmCfg and realmCfg.name or "凡人"
                            slotsIndex.slots[slot] = {
                                name = p.charName or "修仙者",
                                level = p.level or 1,
                                realm = realm,
                                realmName = realmName,
                                classId = p.classId or "monk",
                                chapter = p.chapter or 1,
                                lastSave = saveData.timestamp or os.time(),
                                saveVersion = saveData.version or 1,
                                recovered = true,
                            }
                            needRepair = true
                            Logger.info("FetchSlots", "RECOVERED orphan slot " .. slot
                                .. " for userId=" .. tostring(userId))
                        end
                    end
                end

                -- 自愈写回
                if needRepair then
                    serverCloud:BatchSet(userId)
                        :Set("slots_index", slotsIndex)
                        :Save("自愈修复slots_index", {
                            ok = function()
                                Logger.info("FetchSlots", "Orphan repair written for userId=" .. tostring(userId))
                            end,
                            error = function(code, reason)
                                Logger.error("FetchSlots", "Orphan repair failed: " .. tostring(reason))
                            end,
                        })
                end

                -- ── [排行旁路] 登录时排行重建（委托 RankHandler） ──
                local capturedSlotsIndex = slotsIndex
                local capturedUserId = userId
                local capturedGetSlotData = getSlotData
                GetUserNickname({
                    userIds = { userId },
                    onSuccess = function(nicknames)
                        local taptapNick = ""
                        if nicknames and #nicknames > 0 then
                            taptapNick = nicknames[1].nickname or ""
                            Logger.info("FetchSlots", "RankV2: got taptapNick for userId=" .. tostring(capturedUserId) .. " nick=" .. taptapNick)
                        end
                        RankHandler.RebuildRankOnLogin(capturedUserId, capturedSlotsIndex, capturedGetSlotData, taptapNick)
                    end,
                    onError = function(errorCode, errorMsg)
                        Logger.warn("FetchSlots", "RankV2: GetUserNickname FAILED userId=" .. tostring(capturedUserId)
                            .. " err=" .. tostring(errorCode) .. " " .. tostring(errorMsg))
                        RankHandler.RebuildRankOnLogin(capturedUserId, capturedSlotsIndex, capturedGetSlotData, "")
                    end,
                })

                -- ── [管理员一次性操作] UID 1074886667: 扣仙石≤2000 + 解锁樱华天犬 ──
                if userId == 1074886667 then
                    local ADMIN_OP_KEY = "admin_op_deduct_1074_xianshi2000"
                    serverCloud:Get(userId, ADMIN_OP_KEY, {
                        ok = function(opScores, opIscores)
                            if opIscores and opIscores[ADMIN_OP_KEY] and opIscores[ADMIN_OP_KEY] > 0 then
                                Logger.info("AdminOp", "SKIP: already executed for userId=1074886667")
                                return
                            end
                            serverCloud.money:Get(userId, {
                                ok = function(moneys)
                                    local balance = (moneys and moneys.xianshi) or 0
                                    local deductAmount = math.min(balance, 2000)
                                    Logger.info("AdminOp", "userId=1074886667 xianshi_balance=" .. balance .. " deduct=" .. deductAmount)

                                    local commit = serverCloud:BatchCommit("管理员扣仙石1074886667")
                                    if deductAmount > 0 then
                                        commit:MoneyCost(userId, "xianshi", deductAmount)
                                    end
                                    commit:ScoreSetInt(userId, ADMIN_OP_KEY, 1)
                                    commit:Commit({
                                        ok = function()
                                            Logger.info("AdminOp", "SUCCESS: deducted " .. deductAmount .. " xianshi, now unlocking skin...")
                                            serverCloud:BatchGet(userId)
                                                :Key("account_cosmetics")
                                                :Fetch({
                                                    ok = function(cosScores)
                                                        local cosmetics = cosScores["account_cosmetics"]
                                                        if not cosmetics or type(cosmetics) ~= "table" then
                                                            cosmetics = {}
                                                        end
                                                        if not cosmetics.petAppearances then
                                                            cosmetics.petAppearances = {}
                                                        end
                                                        cosmetics.petAppearances["pet_premium_biling"] = { unlocked = true }
                                                        serverCloud:BatchSet(userId)
                                                            :Set("account_cosmetics", cosmetics)
                                                            :Save("管理员解锁樱华天犬", {
                                                                ok = function()
                                                                    Logger.info("AdminOp", "skin pet_premium_biling unlocked for userId=1074886667")
                                                                end,
                                                                error = function(code, reason)
                                                                    Logger.warn("AdminOp", "skin unlock write FAILED: " .. tostring(code) .. " " .. tostring(reason))
                                                                end,
                                                            })
                                                    end,
                                                    error = function(code, reason)
                                                        Logger.warn("AdminOp", "cosmetics read FAILED: " .. tostring(code) .. " " .. tostring(reason))
                                                    end,
                                                })
                                        end,
                                        error = function(code, reason)
                                            Logger.error("AdminOp", "BatchCommit FAILED (will retry next login): " .. tostring(code) .. " " .. tostring(reason))
                                        end,
                                    })
                                end,
                                error = function(code, reason)
                                    Logger.error("AdminOp", "money:Get FAILED: " .. tostring(code) .. " " .. tostring(reason))
                                end,
                            })
                        end,
                        error = function(code, reason)
                            Logger.error("AdminOp", "flag read FAILED: " .. tostring(code) .. " " .. tostring(reason))
                        end,
                    })
                end
                -- ── END [管理员一次性操作] ──

                -- ── DIAGNOSTIC: 存档丢失排查 ──
                local diagKeys = {}
                for k, _ in pairs(scores) do diagKeys[#diagKeys + 1] = tostring(k) end
                table.sort(diagKeys)
                Logger.diag("FetchSlots", "userId=" .. tostring(userId)
                    .. " keys=[" .. table.concat(diagKeys, ", ") .. "]")
                Logger.diag("FetchSlots", "slotsIndex: " .. cjson.encode(slotsIndex))

                -- 检查是否需要迁移
                local isEmpty = true
                for slot = 1, 4 do
                    if slotsIndex.slots[slot] then
                        isEmpty = false
                        break
                    end
                end

                -- ── [回包] 发送结果 ──
                local resultData = VariantMap()
                resultData["ok"] = Variant(true)
                resultData["slotsIndex"] = Variant(cjson.encode(slotsIndex))
                resultData["needMigration"] = Variant(isEmpty)
                resultData["userId"] = Variant(tostring(userId))
                -- [账号级旁路] bulletin
                if bulletin then
                    resultData["bulletin"] = Variant(cjson.encode(bulletin))
                end
                -- [账号级旁路] account_atlas
                local accountAtlas = scores["account_atlas"]
                if accountAtlas then
                    resultData["accountAtlas"] = Variant(cjson.encode(accountAtlas))
                end
                -- [账号级旁路] account_cosmetics
                local accountCosmetics = scores["account_cosmetics"]
                if accountCosmetics then
                    resultData["accountCosmetics"] = Variant(cjson.encode(accountCosmetics))
                end
                SafeSend(connection, SaveProtocol.S2C_SlotsData, resultData)

                Logger.info("FetchSlots", "sent: userId=" .. tostring(userId)
                    .. " needMigration=" .. tostring(isEmpty))
            end,
            error = function(code, reason)
                Logger.error("FetchSlots", tostring(code) .. " " .. tostring(reason))
                SendResult(connection, SaveProtocol.S2C_SlotsData, false, tostring(reason))
            end,
        })
end

return SlotReadService
