-- ============================================================================
-- server_main.lua - 人狗仙途 服务端入口
--
-- 职责：
--   1. 接收客户端连接，获取 userId（ClientIdentity）
--   2. 代理存档 CRUD（FetchSlots / Load / Save / CreateChar / DeleteChar）
--   3. 代理排行榜查询（GetRankList）
--   4. 接收 clientScore 迁移数据并写入 serverCloud
--   5. 版本握手（检查客户端 CODE_VERSION）
-- ============================================================================

local FeatureFlags = require("config.FeatureFlags")
local SaveProtocol = require("network.SaveProtocol")
local GameConfig = require("config.GameConfig")
local DungeonConfig = require("config.DungeonConfig")
local SealDemonConfig = require("config.SealDemonConfig")

-- §4.5 B1: 模块化拆分 —— 共享状态层 + 业务 Handler
local Session = require("network.ServerSession")
local PillHandler = require("network.PillHandler")
local GMHandler = require("network.GMHandler")
local DaoTreeHandler = require("network.DaoTreeHandler")
local SealDemonHandler = require("network.SealDemonHandler")
local TrialHandler = require("network.TrialHandler")
local RankHandler = require("network.RankHandler")
local RedeemHandler = require("network.RedeemHandler")
local BlackMerchantHandler = require("network.BlackMerchantHandler")
local XianyuanChestHandler = require("network.XianyuanChestHandler")
local SkinShopHandler = require("network.SkinShopHandler")
local _dhOk, DungeonHandler = pcall(require, "network.DungeonHandler")
if not _dhOk then
    print("[Server][WARN] DungeonHandler load failed: " .. tostring(DungeonHandler))
    DungeonHandler = nil
end
local _ehOk, EventHandler = pcall(require, "network.EventHandler")
if not _ehOk then
    print("[Server][WARN] EventHandler load failed: " .. tostring(EventHandler))
    EventHandler = nil
end

require "LuaScripts/Utilities/Sample"

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

-- ============================================================================
-- Mock graphics for headless mode
-- ============================================================================

if GetGraphics() == nil then
    local mockGraphics = {
        SetWindowIcon = function() end,
        SetWindowTitleAndIcon = function() end,
        GetWidth = function() return 1920 end,
        GetHeight = function() return 1080 end,
    }
    function GetGraphics() return mockGraphics end
    graphics = mockGraphics
    console = { background = {} }
    function GetConsole() return console end
    debugHud = {}
    function GetDebugHud() return debugHud end
end

-- ============================================================================
-- §4.5 B1: 共享状态 & 工具函数 —— 由 ServerSession 持有，此处建立本地别名
-- 所有现有代码通过别名访问，语义不变、零改动。
-- ============================================================================
local GM_ADMIN_UIDS      = Session.GM_ADMIN_UIDS
local IsGMAdmin          = Session.IsGMAdmin
local connections_       = Session.connections_
local userIds_           = Session.userIds_
local connSlots_         = Session.connSlots_
local sealDemonActive_   = Session.sealDemonActive_
local daoTreeMeditating_ = Session.daoTreeMeditating_
local trialClaimingActive_ = Session.trialClaimingActive_
local creatingChar_      = Session.creatingChar_
local rateLimitCounters_ = Session.rateLimitCounters_
local CheckRateLimit     = Session.CheckRateLimit
local slotWriteLocks_    = Session.slotWriteLocks_
local AcquireSlotLock    = Session.AcquireSlotLock
local ReleaseSlotLock    = Session.ReleaseSlotLock
local IsSlotLocked       = Session.IsSlotLocked
local ConnKey            = Session.ConnKey
local GetUserId          = Session.GetUserId

-- ============================================================================
-- 工具函数（由 ServerSession 持有，此处建立本地别名）
-- ============================================================================
local SafeSend            = Session.SafeSend
local NormalizeSlotsIndex = Session.NormalizeSlotsIndex
local ServerGetSlotData   = Session.ServerGetSlotData

-- ============================================================================
-- 排行榜：服务端权威计算（P0 防作弊 + P1 存档校验）
-- ============================================================================

-- §4.5 B2: ServerGetSlotData 已提升至 ServerSession，此处使用别名（见行 71）

--- 从存档数据中提取并计算排行榜信息（服务端权威计算，不信任客户端）
--- P0: rankScore 由服务端从 coreData.player 计算，杜绝分数伪造
local function SendResult(connection, eventName, success, message)
    local data = VariantMap()
    data["ok"] = Variant(success)
    if message then
        data["message"] = Variant(message)
    end
    SafeSend(connection, eventName, data)
end

-- ============================================================================
-- 入口
-- ============================================================================

function Start()
    -- P0-2: 启动时输出功能开关快照
    do
        local snap = FeatureFlags.snapshot()
        local parts = {}
        for k, v in pairs(snap) do parts[#parts + 1] = k .. "=" .. tostring(v) end
        table.sort(parts)
        print("[FeatureFlags][Server] snapshot: " .. table.concat(parts, ", "))
    end

    print("[Server-BOOT] Start() called at " .. tostring(os.time and os.time() or "?"))
    SampleStart()

    -- 初始化随机种子（服务端独立 Lua VM，必须单独设置）
    math.randomseed(os.time and os.time() or os.clock())

    print("[Server-BOOT] Before SaveProtocol.RegisterAll()")
    -- 注册所有远程事件
    SaveProtocol.RegisterAll()
    print("[Server-BOOT] After SaveProtocol.RegisterAll()")

    -- 订阅引擎连接事件
    SubscribeToEvent("ClientIdentity", "HandleClientIdentity")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")

    -- 订阅游戏协议事件（P1-SRV-7: 通过 RateLimitedSubscribe 统一限流）
    --- 包装 handler：在原始 handler 前插入限流检查
    local function RateLimitedSubscribe(eventName, handlerName)
        local wrappedName = "_RL_" .. handlerName
        _G[wrappedName] = function(eventType, eventData)
            local ok2, connection = pcall(function() return eventData["Connection"]:GetPtr("Connection") end)
            if ok2 and connection then
                local ck = ConnKey(connection)
                if not CheckRateLimit(ck) then
                    print("[Server] RATE LIMITED: " .. handlerName .. " connKey=" .. ck)
                    -- 通知客户端被限流，避免静默丢弃导致客户端超时
                    local reply = VariantMap()
                    reply["EventName"] = Variant(eventName)
                    connection:SendRemoteEvent(SaveProtocol.S2C_RateLimited, true, reply)
                    return
                end
            end
            local hOk, hErr = pcall(_G[handlerName], eventType, eventData)
            if not hOk then
                print("[Server] HANDLER ERROR in " .. handlerName .. ": " .. tostring(hErr))
                -- P3: 尝试给客户端发错误响应，避免客户端永久等待
                if ok2 and connection then
                    pcall(function()
                        local errReply = VariantMap()
                        errReply["ok"] = Variant(false)
                        errReply["message"] = Variant("服务器内部错误")
                        connection:SendRemoteEvent(eventName .. "_Error", true, errReply)
                    end)
                end
            end
        end
        SubscribeToEvent(eventName, wrappedName)
    end

    RateLimitedSubscribe(SaveProtocol.C2S_FetchSlots, "HandleFetchSlots")
    RateLimitedSubscribe(SaveProtocol.C2S_CreateChar, "HandleCreateChar")
    RateLimitedSubscribe(SaveProtocol.C2S_DeleteChar, "HandleDeleteChar")
    RateLimitedSubscribe(SaveProtocol.C2S_LoadGame, "HandleLoadGame")
    RateLimitedSubscribe(SaveProtocol.C2S_SaveGame, "HandleSaveGame")
    RateLimitedSubscribe(SaveProtocol.C2S_MigrateData, "HandleMigrateData")
    RateLimitedSubscribe(SaveProtocol.C2S_GetRankList, "HandleGetRankList")
    SubscribeToEvent(SaveProtocol.C2S_VersionHandshake, "HandleVersionHandshake")  -- 握手不限流
    RateLimitedSubscribe(SaveProtocol.C2S_DaoTreeStart, "HandleDaoTreeStart")
    RateLimitedSubscribe(SaveProtocol.C2S_DaoTreeComplete, "HandleDaoTreeComplete")
    RateLimitedSubscribe(SaveProtocol.C2S_GMResetDaily, "HandleGMResetDaily")
    RateLimitedSubscribe(SaveProtocol.C2S_GMCommand, "HandleGMCommand")
    RateLimitedSubscribe(SaveProtocol.C2S_BuyPill, "HandleBuyPill")
    RateLimitedSubscribe(SaveProtocol.C2S_DaoTreeQuery, "HandleDaoTreeQuery")
    RateLimitedSubscribe(SaveProtocol.C2S_SealDemonAccept, "HandleSealDemonAccept")
    RateLimitedSubscribe(SaveProtocol.C2S_SealDemonBossKilled, "HandleSealDemonBossKilled")
    RateLimitedSubscribe(SaveProtocol.C2S_SealDemonAbandon, "HandleSealDemonAbandon")
    RateLimitedSubscribe(SaveProtocol.C2S_TrialClaimDaily, "HandleTrialClaimDaily")
    RateLimitedSubscribe(SaveProtocol.C2S_RedeemCode, "HandleRedeemCode")
    -- C2S_RedeemAck 已废弃（兑换码改为服务端直接写存档，不再需要客户端回执）
    RateLimitedSubscribe(SaveProtocol.C2S_GMCreateCode, "HandleGMCreateCode")
    RateLimitedSubscribe(SaveProtocol.C2S_TryUnlockRace, "HandleTryUnlockRace")
    RateLimitedSubscribe(SaveProtocol.C2S_CheckEventGrant, "HandleCheckEventGrant")
    RateLimitedSubscribe(SaveProtocol.C2S_CheckRaceSlots, "HandleCheckRaceSlots")
    RateLimitedSubscribe(SaveProtocol.C2S_ServerApiTest, "HandleServerApiTest")
    -- 万界黑商
    RateLimitedSubscribe(SaveProtocol.C2S_BlackMerchantQuery, "HandleBlackMerchantQuery")
    RateLimitedSubscribe(SaveProtocol.C2S_BlackMerchantBuy, "HandleBlackMerchantBuy")
    RateLimitedSubscribe(SaveProtocol.C2S_BlackMerchantSell, "HandleBlackMerchantSell")
    RateLimitedSubscribe(SaveProtocol.C2S_BlackMerchantExchange, "HandleBlackMerchantExchange")
    RateLimitedSubscribe(SaveProtocol.C2S_BlackMerchantHistory, "HandleBlackMerchantHistory")
    -- 皮肤商店（大黑无天）
    RateLimitedSubscribe(SaveProtocol.C2S_SkinShopQuery, "HandleSkinShopQuery")
    RateLimitedSubscribe(SaveProtocol.C2S_SkinShopBuy, "HandleSkinShopBuy")
    -- 仙缘宝箱
    RateLimitedSubscribe(SaveProtocol.C2S_XianyuanChest_StartOpen, "HandleXianyuanChestStartOpen")
    RateLimitedSubscribe(SaveProtocol.C2S_XianyuanChest_CancelOpen, "HandleXianyuanChestCancelOpen")
    RateLimitedSubscribe(SaveProtocol.C2S_XianyuanChest_CompleteOpen, "HandleXianyuanChestCompleteOpen")
    RateLimitedSubscribe(SaveProtocol.C2S_XianyuanChest_Pick, "HandleXianyuanChestPick")
    -- 五一活动（Kill Switch 守卫：EventConfig.IsActive() 在 Handler 内部检查）
    if EventHandler then
        RateLimitedSubscribe(SaveProtocol.C2S_EventExchange, "HandleEventExchange")
        RateLimitedSubscribe(SaveProtocol.C2S_EventOpenFudai, "HandleEventOpenFudai")
        RateLimitedSubscribe(SaveProtocol.C2S_EventGetRankList, "HandleEventGetRankList")
        RateLimitedSubscribe(SaveProtocol.C2S_EventGetPullRecords, "HandleEventGetPullRecords")
    end
    -- 多人副本（四兽岛）—— Kill Switch 守卫
    if GameConfig.DUNGEON_ENABLED and DungeonHandler then
        RateLimitedSubscribe(SaveProtocol.C2S_EnterDungeon, "HandleEnterDungeon")
        RateLimitedSubscribe(SaveProtocol.C2S_LeaveDungeon, "HandleLeaveDungeon")
        SubscribeToEvent(SaveProtocol.C2S_PlayerPosition, "HandleDungeonPlayerPosition")  -- 位置上报不限流
        SubscribeToEvent(SaveProtocol.C2S_DungeonAttack, "HandleDungeonAttack")  -- 伤害上报不走全局限流（DungeonHandler 自带 ATTACK_COOLDOWN）
        RateLimitedSubscribe(SaveProtocol.C2S_QueryDungeonReward, "HandleQueryDungeonReward")
        RateLimitedSubscribe(SaveProtocol.C2S_ClaimDungeonReward, "HandleClaimDungeonReward")

        -- 初始化副本 Handler（加载 BOSS 状态）
        -- pcall 防护：即使副本初始化失败，也不能阻断 Update 订阅和其他核心功能
        local dhOk, dhErr = pcall(function()
            DungeonHandler.Init()
        end)
        if not dhOk then
            print("[Server] WARNING: DungeonHandler.Init() failed: " .. tostring(dhErr))
        end
    else
        print("[Server] Dungeon system disabled (DUNGEON_ENABLED="
            .. tostring(GameConfig.DUNGEON_ENABLED)
            .. ", DungeonHandler=" .. tostring(DungeonHandler ~= nil) .. ")")
    end

    -- 订阅服务端 Update 事件（副本快照广播 + BOSS AI + 刷新计时）
    SubscribeToEvent("Update", "HandleServerUpdate")

    print("[Server] 人狗仙途 服务端已启动")
    print("[Server] serverCloud available: " .. tostring(serverCloud ~= nil))
    print("[Server] CODE_VERSION=" .. GameConfig.CODE_VERSION)

    -- 从配置文件注册兑换码
    RedeemHandler.RegisterRedeemCodesFromConfig()

end

function Stop()
    print("[Server] 服务端关闭")
end

-- ============================================================================
-- 连接事件
-- ============================================================================

--- ClientIdentity：userId 可用的时机
function HandleClientIdentity(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)

    local userId = connection.identity["user_id"]:GetInt64()

    -- 清理同一 userId 的旧连接记录（引擎会自动踢掉旧连接）
    -- 注意：不能给旧连接 SafeSend，引擎踢人与发消息存在竞态会导致崩溃
    for oldKey, oldUid in pairs(userIds_) do
        if oldUid == userId and oldKey ~= connKey then
            print("[Server] Duplicate login userId=" .. tostring(userId) .. " oldConn=" .. oldKey .. " (engine auto-kicks)")
            connections_[oldKey] = nil
            userIds_[oldKey] = nil
            break
        end
    end

    connections_[connKey] = connection
    userIds_[connKey] = userId

    print("[Server] ClientIdentity: connKey=" .. connKey .. " userId=" .. tostring(userId))
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData:GetPtr("Connection", "Connection")
    local connKey = ConnKey(connection)
    local userId = userIds_[connKey]
    local slot = connSlots_[connKey]

    -- ========= 核心清理（无条件执行，绝不 pcall）=========
    connections_[connKey] = nil
    userIds_[connKey] = nil
    connSlots_[connKey] = nil
    rateLimitCounters_[connKey] = nil
    sealDemonActive_[connKey] = nil
    daoTreeMeditating_[connKey] = nil
    trialClaimingActive_[connKey] = nil

    -- ========= 非核心清理（各自 pcall，互不影响）=========
    if userId and slot then
        pcall(ReleaseSlotLock, userId, slot)
    end

    if userId then
        pcall(function()
            for k in pairs(creatingChar_) do
                if k:find(tostring(userId) .. ":") == 1 then
                    creatingChar_[k] = nil
                end
            end
        end)
    end

    pcall(BlackMerchantHandler.OnDisconnect, connKey)
    pcall(XianyuanChestHandler.CleanupConnection, connKey)

    if EventHandler and userId then
        pcall(EventHandler.OnDisconnect, userId)
    end

    if DungeonHandler then
        pcall(DungeonHandler.OnPlayerDisconnected, connKey)
    end

    print("[Server] ClientDisconnected: userId=" .. tostring(userId))
end

-- ============================================================================
-- C2S_VersionHandshake — 版本握手
-- ============================================================================

function HandleVersionHandshake(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local clientVersion = eventData["CodeVersion"]:GetInt()
    print("[Server] VersionHandshake: userId=" .. tostring(userId)
        .. " clientVer=" .. clientVersion
        .. " serverVer=" .. GameConfig.CODE_VERSION)

    if clientVersion < GameConfig.CODE_VERSION then
        -- 客户端版本过旧 → 强制更新
        local data = VariantMap()
        data["requiredVersion"] = Variant(GameConfig.CODE_VERSION)
        SafeSend(connection, SaveProtocol.S2C_ForceUpdate, data)
        print("[Server] ForceUpdate sent to userId=" .. tostring(userId))
    end
    -- 如果客户端版本 >= 服务端，无需响应（正常继续）
end

-- ============================================================================
-- C2S_FetchSlots — 获取槽位列表
-- ============================================================================

function HandleFetchSlots(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    print("[Server] FetchSlots: userId=" .. tostring(userId))

    -- 读取 slots_index + save_X (v11) + save_data_X (v10 fallback) + account_bulletin + account_atlas + account_cosmetics + rank_score_1~4
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

                -- 归一化 slots key（serverCloud JSON 反序列化可能将数字 key 变成字符串）
                NormalizeSlotsIndex(slotsIndex)

                -- v11/v10 合并辅助：优先 save_X，fallback save_data_X
                local function getSlotData(s)
                    local v11 = scores["save_" .. s]
                    if v11 and type(v11) == "table" then return v11 end
                    local v10 = scores["save_data_" .. s]
                    if v10 and type(v10) == "table" then return v10 end
                    return nil
                end

                -- 正向验证：索引有条目但数据丢失（检查全部 4 槽）
                slotsIndex.slots = slotsIndex.slots or {}
                for slot = 1, 4 do
                    if slotsIndex.slots[slot] then
                        local hasData = getSlotData(slot) ~= nil
                        if not hasData then
                            slotsIndex.slots[slot].dataLost = true
                            print("[Server] WARNING: Slot " .. slot
                                .. " index exists but save data MISSING for userId=" .. tostring(userId))
                        end
                    end
                end

                -- 反向验证：孤儿存档自愈（检查全部 4 槽）
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
                            print("[Server] RECOVERED orphan slot " .. slot
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
                                print("[Server] Orphan repair written for userId=" .. tostring(userId))
                            end,
                            error = function(code, reason)
                                print("[Server] Orphan repair failed: " .. tostring(reason))
                            end,
                        })
                end

                -- P0: v2 排行榜 —— 登录时无条件从存档重建排行（全新 rank2_ key）
                -- 使用顶层 SetInt 确保更新全局排行索引

                -- P1-UI-1 修复：将排行榜重建移入 GetUserNickname 回调，避免异步竞态导致 taptapNick 为 nil
                local capturedSlotsIndex = slotsIndex  -- 闭包捕获
                local capturedUserId = userId
                local capturedGetSlotData = getSlotData
                GetUserNickname({
                    userIds = { userId },
                    onSuccess = function(nicknames)
                        local taptapNick = ""
                        if nicknames and #nicknames > 0 then
                            taptapNick = nicknames[1].nickname or ""
                            print("[Server] RankV2: got taptapNick for userId=" .. tostring(capturedUserId) .. " nick=" .. taptapNick)
                        end
                        -- 排行榜重建逻辑（原先在回调外，现移入回调内）
                        RankHandler.RebuildRankOnLogin(capturedUserId, capturedSlotsIndex, capturedGetSlotData, taptapNick)
                    end,
                    onError = function(errorCode, errorMsg)
                        print("[Server] RankV2: GetUserNickname FAILED userId=" .. tostring(capturedUserId)
                            .. " err=" .. tostring(errorCode) .. " " .. tostring(errorMsg))
                        -- 即使获取昵称失败，仍然用空字符串重建排行榜（排行数据比昵称更重要）
                        RankHandler.RebuildRankOnLogin(capturedUserId, capturedSlotsIndex, capturedGetSlotData, "")
                    end,
                })

                -- ====== [一次性管理员操作] UID 1074886667: 扣仙石≤2000 + 解锁樱华天犬 ======
                if userId == 1074886667 then
                    local ADMIN_OP_KEY = "admin_op_deduct_1074_xianshi2000"
                    serverCloud:Get(userId, ADMIN_OP_KEY, {
                        ok = function(opScores, opIscores)
                            -- 幂等检查：iscore 标记已执行则跳过
                            if opIscores and opIscores[ADMIN_OP_KEY] and opIscores[ADMIN_OP_KEY] > 0 then
                                print("[Server][AdminOp] SKIP: already executed for userId=1074886667")
                                return
                            end
                            -- 读取仙石余额
                            serverCloud.money:Get(userId, {
                                ok = function(moneys)
                                    local balance = (moneys and moneys.xianshi) or 0
                                    local deductAmount = math.min(balance, 2000)
                                    print("[Server][AdminOp] userId=1074886667 xianshi_balance=" .. balance .. " deduct=" .. deductAmount)

                                    -- 原子事务：扣仙石 + 标记已执行
                                    local commit = serverCloud:BatchCommit("管理员扣仙石1074886667")
                                    if deductAmount > 0 then
                                        commit:MoneyCost(userId, "xianshi", deductAmount)
                                    end
                                    commit:ScoreSetInt(userId, ADMIN_OP_KEY, 1)
                                    commit:Commit({
                                        ok = function()
                                            print("[Server][AdminOp] SUCCESS: deducted " .. deductAmount .. " xianshi, now unlocking skin...")
                                            -- 解锁樱华天犬皮肤（写 account_cosmetics）
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
                                                                    print("[Server][AdminOp] skin pet_premium_biling unlocked for userId=1074886667")
                                                                end,
                                                                error = function(code, reason)
                                                                    print("[Server][AdminOp] WARN: skin unlock write FAILED: " .. tostring(code) .. " " .. tostring(reason))
                                                                end,
                                                            })
                                                    end,
                                                    error = function(code, reason)
                                                        print("[Server][AdminOp] WARN: cosmetics read FAILED: " .. tostring(code) .. " " .. tostring(reason))
                                                    end,
                                                })
                                        end,
                                        error = function(code, reason)
                                            print("[Server][AdminOp] BatchCommit FAILED (will retry next login): " .. tostring(code) .. " " .. tostring(reason))
                                        end,
                                    })
                                end,
                                error = function(code, reason)
                                    print("[Server][AdminOp] money:Get FAILED: " .. tostring(code) .. " " .. tostring(reason))
                                end,
                            })
                        end,
                        error = function(code, reason)
                            print("[Server][AdminOp] flag read FAILED: " .. tostring(code) .. " " .. tostring(reason))
                        end,
                    })
                end
                -- ====== END [一次性管理员操作] ======

                -- ====== DIAGNOSTIC: 存档丢失排查 ======
                local diagKeys = {}
                for k, _ in pairs(scores) do diagKeys[#diagKeys + 1] = tostring(k) end
                table.sort(diagKeys)
                print("[Server] DIAG FetchSlots: userId=" .. tostring(userId)
                    .. " keys=[" .. table.concat(diagKeys, ", ") .. "]")
                print("[Server] DIAG slotsIndex: " .. cjson.encode(slotsIndex))
                -- ====== END DIAGNOSTIC ======

                -- 检查是否需要迁移（serverCloud 全部 4 槽无数据 → 可能 clientScore 有数据）
                local isEmpty = true
                for slot = 1, 4 do
                    if slotsIndex.slots[slot] then
                        isEmpty = false
                        break
                    end
                end

                -- 发送结果
                local resultData = VariantMap()
                resultData["ok"] = Variant(true)
                resultData["slotsIndex"] = Variant(cjson.encode(slotsIndex))
                resultData["needMigration"] = Variant(isEmpty)
                resultData["userId"] = Variant(tostring(userId))
                if bulletin then
                    resultData["bulletin"] = Variant(cjson.encode(bulletin))
                end
                -- 账号级仙图录
                local accountAtlas = scores["account_atlas"]
                if accountAtlas then
                    resultData["accountAtlas"] = Variant(cjson.encode(accountAtlas))
                end
                -- 账号级外观数据
                local accountCosmetics = scores["account_cosmetics"]
                if accountCosmetics then
                    resultData["accountCosmetics"] = Variant(cjson.encode(accountCosmetics))
                end
                SafeSend(connection, SaveProtocol.S2C_SlotsData, resultData)

                print("[Server] FetchSlots sent: userId=" .. tostring(userId)
                    .. " needMigration=" .. tostring(isEmpty))
            end,
            error = function(code, reason)
                print("[Server] FetchSlots ERROR: " .. tostring(code) .. " " .. tostring(reason))
                SendResult(connection, SaveProtocol.S2C_SlotsData, false, tostring(reason))
            end,
        })
end

-- ============================================================================
-- C2S_CreateChar — 创建角色
-- ============================================================================

function HandleCreateChar(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local slot = eventData["slot"]:GetInt()
    local charName = eventData["charName"]:GetString()
    local classId = eventData["classId"]:GetString()
    -- 职业白名单校验（防止客户端篡改）
    if not classId or classId == "" or not GameConfig.CLASS_DATA[classId] then
        classId = GameConfig.PLAYER_CLASS
    end


    print("[Server] CreateChar: userId=" .. tostring(userId)
        .. " slot=" .. slot .. " name=" .. charName .. " class=" .. classId)

    -- 槽位范围限制：1-4 槽均可创角
    if slot < 1 or slot > 4 then
        print("[Server] CreateChar REJECTED: slot " .. slot .. " out of allowed range (1-4)")
        SendResult(connection, SaveProtocol.S2C_CharResult, false, "该槽位不允许创建角色")
        return
    end

    -- P1-SRV-4: 防重入守卫（TOCTOU 防护）
    local guardKey = tostring(userId) .. ":" .. slot
    if creatingChar_[guardKey] then
        print("[Server] CreateChar REJECTED: already in progress for " .. guardKey)
        SendResult(connection, SaveProtocol.S2C_CharResult, false, "正在创建中，请稍候")
        return
    end
    creatingChar_[guardKey] = true

    -- 先读取当前 slots_index
    serverCloud:Get(userId, "slots_index", {
        ok = function(scores)
            local slotsIndex = scores["slots_index"] or { version = 1, slots = {} }
            slotsIndex.slots = slotsIndex.slots or {}
            NormalizeSlotsIndex(slotsIndex)

            -- 检查槽位是否已被占用
            if slotsIndex.slots[slot] then
                creatingChar_[guardKey] = nil
                SendResult(connection, SaveProtocol.S2C_CharResult, false, "槽位已被占用")
                return
            end

            -- 构建初始存档（与 SaveSystem.CreateCharacter 保持一致，v11 单 key）
            local coreData = {
                version = 11,  -- CURRENT_SAVE_VERSION v11
                timestamp = os.time(),
                player = {
                    level = 1, exp = 0, hp = 100, maxHp = 100,
                    atk = 15, def = 5, hpRegen = 1.0,
                    gold = 0, lingYun = 0, realm = "mortal",
                    classId = classId,
                },
                equipment = {},
                backpack = {},
                skills = {},
                collection = {},
                pet = {},
                quests = {},
            }

            -- 更新 slots_index
            slotsIndex.slots[slot] = {
                name = charName,
                level = 1,
                realm = "mortal",
                realmName = "凡人",
                chapter = 1,
                classId = classId,
                lastSave = os.time(),
                saveVersion = coreData.version,
            }

            local saveKey = "save_" .. slot

            serverCloud:BatchSet(userId)
                :Set(saveKey, coreData)
                :Set("slots_index", slotsIndex)
                :Save("创建角色", {
                    ok = function()
                        creatingChar_[guardKey] = nil
                        print("[Server] Character created: userId=" .. tostring(userId)
                            .. " slot=" .. slot .. " name=" .. charName)
                        local data = VariantMap()
                        data["ok"] = Variant(true)
                        data["slot"] = Variant(slot)
                        data["slotsIndex"] = Variant(cjson.encode(slotsIndex))
                        SafeSend(connection, SaveProtocol.S2C_CharResult, data)
                    end,
                    error = function(code, reason)
                        creatingChar_[guardKey] = nil
                        print("[Server] CreateChar failed: " .. tostring(reason))
                        SendResult(connection, SaveProtocol.S2C_CharResult, false, tostring(reason))
                    end,
                })
        end,
        error = function(code, reason)
            creatingChar_[guardKey] = nil
            print("[Server] CreateChar read index failed: " .. tostring(reason))
            SendResult(connection, SaveProtocol.S2C_CharResult, false, tostring(reason))
        end,
    })
end

-- ============================================================================
-- C2S_DeleteChar — 删除角色
-- ============================================================================

function HandleDeleteChar(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local slot = eventData["slot"]:GetInt()

    print("[Server] DeleteChar: userId=" .. tostring(userId) .. " slot=" .. slot)

    -- 读取 v11 + v10 存档做备份 + 读取 slots_index
    local newSaveKey = "save_" .. slot
    local oldSaveKey = "save_data_" .. slot
    local oldBag1Key = "save_bag1_" .. slot
    local oldBag2Key = "save_bag2_" .. slot

    serverCloud:BatchGet(userId)
        :Key(newSaveKey)
        :Key(oldSaveKey)
        :Key(oldBag1Key)
        :Key(oldBag2Key)
        :Key("slots_index")
        :Fetch({
            ok = function(scores)
                local slotsIndex = scores["slots_index"] or { version = 1, slots = {} }
                slotsIndex.slots = slotsIndex.slots or {}
                NormalizeSlotsIndex(slotsIndex)

                local newData = scores[newSaveKey]
                local oldData = scores[oldSaveKey]
                local b1Data = scores[oldBag1Key]
                local b2Data = scores[oldBag2Key]

                -- 移除槽位
                slotsIndex.slots[slot] = nil

                local deletedKey = "deleted_" .. slot

                local batch = serverCloud:BatchSet(userId)
                    :Set("slots_index", slotsIndex)
                    :Delete(newSaveKey)
                    :Delete(oldSaveKey)
                    :Delete(oldBag1Key)
                    :Delete(oldBag2Key)
                    -- 删除旧版排行 key
                    :Delete("rank_score_" .. slot)
                    :Delete("rank_info_" .. slot)
                    -- 删除 v2 排行 key
                    :Delete("rank2_info_" .. slot)

                -- 合并备份数据（v11 单 key 格式）
                local backupData = nil
                if newData and type(newData) == "table" then
                    backupData = newData
                elseif oldData and type(oldData) == "table" then
                    backupData = oldData
                    local backpack = {}
                    if b1Data and type(b1Data) == "table" then
                        for k, v in pairs(b1Data) do backpack[k] = v end
                    end
                    if b2Data and type(b2Data) == "table" then
                        for k, v in pairs(b2Data) do backpack[k] = v end
                    end
                    backupData.backpack = backpack
                end

                if backupData then
                    batch:Set(deletedKey, {
                        data = backupData,
                        deletedAt = os.time(),
                    })
                end

                batch:Save("删除角色", {
                    ok = function()
                        print("[Server] Character deleted: userId=" .. tostring(userId) .. " slot=" .. slot)

                        -- 清除 v2 排行索引（顶层 SetInt 置 0，从排行榜移除）
                        serverCloud:SetInt(userId, "rank2_score_" .. slot, 0, {
                            error = function(code, reason)
                                print("[Server] DeleteChar SetInt rank2_score clear FAILED: userId=" .. tostring(userId)
                                    .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
                            end,
                        })
                        serverCloud:SetInt(userId, "rank2_kills_" .. slot, 0, {
                            error = function(code, reason)
                                print("[Server] DeleteChar SetInt rank2_kills clear FAILED: userId=" .. tostring(userId)
                                    .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
                            end,
                        })
                        serverCloud:SetInt(userId, "rank2_time_" .. slot, 0, {
                            error = function(code, reason)
                                print("[Server] DeleteChar SetInt rank2_time clear FAILED: userId=" .. tostring(userId)
                                    .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
                            end,
                        })

                        local data = VariantMap()
                        data["ok"] = Variant(true)
                        data["slot"] = Variant(slot)
                        data["slotsIndex"] = Variant(cjson.encode(slotsIndex))
                        SafeSend(connection, SaveProtocol.S2C_CharResult, data)
                    end,
                    error = function(code, reason)
                        print("[Server] DeleteChar failed: " .. tostring(reason))
                        SendResult(connection, SaveProtocol.S2C_CharResult, false, tostring(reason))
                    end,
                })
            end,
            error = function(code, reason)
                print("[Server] DeleteChar read failed: " .. tostring(reason))
                SendResult(connection, SaveProtocol.S2C_CharResult, false, tostring(reason))
            end,
        })
end

-- ============================================================================
-- 服务端奖励合并：将兑换码奖励直接写入存档数据（防断线丢奖励）
-- ============================================================================

-- ============================================================================
-- C2S_LoadGame — 加载存档
-- ============================================================================

function HandleLoadGame(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local slot = eventData["slot"]:GetInt()
    connSlots_[connKey] = slot  -- 记录当前连接的活跃角色槽位

    print("[Server] LoadGame: userId=" .. tostring(userId) .. " slot=" .. slot)

    -- v11 新 key + v10 旧 key（兼容窗口）
    local newSaveKey = "save_" .. slot
    local oldSaveKey = "save_data_" .. slot
    local oldBag1Key = "save_bag1_" .. slot
    local oldBag2Key = "save_bag2_" .. slot

    local pendingKey = "pending_redeem_s" .. slot
    local dungeonPendingKey = DungeonConfig.MakePendingKey(nil, slot)
    local oldDungeonPendingKey = "dungeon_pending_reward_" .. slot  -- 旧格式兼容

    serverCloud:BatchGet(userId)
        :Key(newSaveKey)
        :Key(oldSaveKey)
        :Key(oldBag1Key)
        :Key(oldBag2Key)
        :Key("account_atlas")
        :Key("account_cosmetics")
        :Key(pendingKey)
        :Key(dungeonPendingKey)
        :Key(oldDungeonPendingKey)
        :Fetch({
            ok = function(scores)
                -- v11 优先，v10 fallback
                local saveData = nil
                local newData = scores[newSaveKey]
                local oldData = scores[oldSaveKey]

                if newData and type(newData) == "table" then
                    saveData = newData
                elseif oldData and type(oldData) == "table" then
                    -- v10 格式：合并 bag 到 backpack
                    saveData = oldData
                    local backpack = {}
                    local b1 = scores[oldBag1Key]
                    local b2 = scores[oldBag2Key]
                    if b1 and type(b1) == "table" then
                        for k, v in pairs(b1) do backpack[k] = v end
                    end
                    if b2 and type(b2) == "table" then
                        for k, v in pairs(b2) do backpack[k] = v end
                    end
                    saveData.backpack = backpack
                end

                if not saveData then
                    print("[Server] LoadGame: save data missing for slot " .. slot
                        .. " userId=" .. tostring(userId))
                    SendResult(connection, SaveProtocol.S2C_LoadResult, false, "存档数据丢失")
                    return
                end

                -- 账号级仙图录：用 account_atlas 覆盖 per-slot 的 atlas
                local accountAtlas = scores["account_atlas"]
                if accountAtlas and type(accountAtlas) == "table" then
                    saveData.atlas = accountAtlas
                    print("[Server] LoadGame: account_atlas applied for userId=" .. tostring(userId))
                end

                -- 账号级外观数据：注入到 saveData 中供客户端使用
                local accountCosmetics = scores["account_cosmetics"]
                if accountCosmetics and type(accountCosmetics) == "table" then
                    saveData.accountCosmetics = accountCosmetics
                    print("[Server] LoadGame: account_cosmetics applied for userId=" .. tostring(userId))
                end

                -- ====== [过渡代码] 旧版 pending 兑换码奖励恢复（新版不再产生 pending，此段仅处理遗留数据） ======
                local pendingRedeem = scores[pendingKey]
                if pendingRedeem and type(pendingRedeem) == "table" and pendingRedeem.rewards then
                    local pendingCode = pendingRedeem.code
                    print("[Server] LoadGame: found pending redeem rewards for userId="
                        .. tostring(userId) .. " slot=" .. slot
                        .. " code=" .. tostring(pendingCode))
                    -- 服务端将奖励合并到存档（带幂等性检查，若已应用过则跳过）
                    local applied = RedeemHandler.ServerApplyRedeemRewards(saveData, pendingRedeem.rewards, pendingCode)
                    if applied then
                        saveData.timestamp = os.time()
                        print("[Server] LoadGame: rewards applied for code=" .. tostring(pendingCode))
                    else
                        print("[Server] LoadGame: rewards SKIPPED (already in save) for code=" .. tostring(pendingCode))
                    end
                    -- 无论是否实际应用，都要清除 pending 记录（避免每次登录都检查）
                    serverCloud:BatchSet(userId)
                        :Set(newSaveKey, saveData)
                        :Delete(pendingKey)
                        :Save("恢复兑换码奖励到存档", {
                            ok = function()
                                print("[Server] LoadGame: pending redeem cleared for userId="
                                    .. tostring(userId) .. " slot=" .. slot
                                    .. " applied=" .. tostring(applied))
                            end,
                            error = function(errCode, reason)
                                print("[Server] LoadGame: WARNING pending redeem merge FAILED: " .. tostring(reason))
                            end,
                        })
                end

                -- ====== [过渡代码] 旧格式副本 pending key 迁移 ======
                -- 旧格式 dungeon_pending_reward_{slot} → 新格式 dungeon_pending_sishoudao_{slot}
                -- 新格式下奖励由客户端通过 NPC 领取，LoadGame 不再自动发放到 saveData
                -- 注意：此段不受 DUNGEON_ENABLED 开关控制 — 即使副本关闭，遗留的旧格式数据仍需迁移
                local oldDungeonPending = scores[oldDungeonPendingKey]
                if oldDungeonPending and type(oldDungeonPending) == "table" and oldDungeonPending.lingYun then
                    -- 检查新 key 是否已有数据（避免覆盖）
                    local newDungeonPending = scores[dungeonPendingKey]
                    if not newDungeonPending or type(newDungeonPending) ~= "table" then
                        -- 迁移到新 key
                        serverCloud:BatchSet(userId)
                            :Set(dungeonPendingKey, oldDungeonPending)
                            :Delete(oldDungeonPendingKey)
                            :Save("迁移副本pending到新key格式", {
                                ok = function()
                                    print("[Server] LoadGame: migrated dungeon pending to new key for userId="
                                        .. tostring(userId) .. " slot=" .. slot)
                                end,
                                error = function(errCode, reason)
                                    print("[Server] LoadGame: WARNING dungeon pending migration FAILED: " .. tostring(reason))
                                end,
                            })
                    else
                        -- 新 key 已有数据，只删除旧 key
                        serverCloud:Delete(userId, oldDungeonPendingKey, {
                            ok = function()
                                print("[Server] LoadGame: old dungeon pending key deleted (new key already exists)")
                            end,
                            error = function() end,
                        })
                    end
                end

                -- 发送存档数据（v11 单 key 格式，JSON 编码）
                local resultData = VariantMap()
                resultData["ok"] = Variant(true)
                resultData["slot"] = Variant(slot)
                resultData["saveData"] = Variant(cjson.encode(saveData))
                SafeSend(connection, SaveProtocol.S2C_LoadResult, resultData)

                print("[Server] LoadGame sent: userId=" .. tostring(userId) .. " slot=" .. slot)

                -- 万界黑商 WAL 补偿检查（登录时异步执行，不阻塞 LoadGame 响应）
                BlackMerchantHandler.CheckWALOnLogin(userId, slot, saveData)
            end,
            error = function(code, reason)
                print("[Server] LoadGame ERROR: " .. tostring(code) .. " " .. tostring(reason))
                SendResult(connection, SaveProtocol.S2C_LoadResult, false, tostring(reason))
            end,
        })
end

-- ============================================================================
-- C2S_SaveGame — 保存存档
-- ============================================================================

function HandleSaveGame(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)

    local userId = GetUserId(connKey)
    if not userId then
        print("[Server] SaveGame REJECTED: no userId for connKey=" .. tostring(connKey))
        return
    end

    local requestId = 0
    pcall(function() requestId = eventData["requestId"]:GetInt() end)

    local slot = eventData["slot"]:GetInt()
    connSlots_[connKey] = slot  -- 同步更新活跃槽位（冗余保护）

    -- P0-2 修复：slot 写入锁保护，防止与 DaoTree/SealDemon/Trial read-modify-write 并发覆盖
    if IsSlotLocked(userId, slot) then
        print("[Server] SaveGame DEFERRED: slot " .. slot .. " is locked (reward write in progress), userId=" .. tostring(userId))
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "slot_locked")
        return
    end

    local coreDataJson = eventData["coreData"]:GetString()
    local slotsIndexJson = eventData["slotsIndex"]:GetString()
    local rankDataJson = eventData["rankData"]:GetString()

    print("[Server] SaveGame: userId=" .. tostring(userId) .. " slot=" .. slot)

    -- 解码 JSON（v11: coreData 已包含 equipment + backpack，无 bag1/bag2）
    local ok1, coreData = pcall(cjson.decode, coreDataJson)
    -- 🔴 Bug fix: 空字符串或 "{}" 不应视为有效 slotsIndex
    local ok4, slotsIndex = false, nil
    if slotsIndexJson and slotsIndexJson ~= "" then
        ok4, slotsIndex = pcall(cjson.decode, slotsIndexJson)
    end
    local ok5, rankData = pcall(cjson.decode, rankDataJson)

    if not ok1 or not coreData then
        print("[Server] SaveGame: coreData decode failed")
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "数据格式错误")
        return
    end

    -- ================================================================
    -- B4-S2 硬校验 V1~V4：服务端权威修正关键数值
    -- 不拒绝存档，而是 clamp 到合法范围后继续保存
    -- ================================================================
    if coreData.player then
        local cp = coreData.player

        -- V1: level 不得超过当前境界 maxLevel
        if cp.level and type(cp.level) == "number" then
            local realm = cp.realm or "mortal"
            local rCfg = GameConfig.REALMS[realm]
            if rCfg then
                local maxLv = rCfg.maxLevel or 999
                if cp.level > maxLv then
                    print("[Server][V1] Level clamped: " .. cp.level .. " -> " .. maxLv
                        .. " (realm=" .. realm .. ") userId=" .. tostring(userId))
                    cp.level = maxLv
                end
            end
            if cp.level < 1 then cp.level = 1 end
        end

        -- V2: exp 不得为负，不得超过当前等级经验表上限
        if cp.exp and type(cp.exp) == "number" then
            if cp.exp < 0 then
                print("[Server][V2] Exp clamped from " .. cp.exp .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.exp = 0
            end
            -- 经验上限：下一级所需经验（如已是最高级则用当前级）
            local nextLvExp = GameConfig.EXP_TABLE[cp.level + 1]
                or GameConfig.EXP_TABLE[cp.level]
                or cp.exp
            if nextLvExp and cp.exp > nextLvExp * 2 then
                -- 允许 2 倍余量（存档可能在升级瞬间），超过 2 倍视为异常
                print("[Server][V2] Exp suspicious: " .. cp.exp
                    .. " > 2x nextLvExp=" .. nextLvExp
                    .. " userId=" .. tostring(userId))
                cp.exp = nextLvExp
            end
        end

        -- V3: gold 不得为负
        if cp.gold and type(cp.gold) == "number" then
            if cp.gold < 0 then
                print("[Server][V3] Gold clamped from " .. cp.gold .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.gold = 0
            end
        end

        -- V4: lingYun 不得为负
        if cp.lingYun and type(cp.lingYun) == "number" then
            if cp.lingYun < 0 then
                print("[Server][V4] LingYun clamped from " .. cp.lingYun .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.lingYun = 0
            end
        end
    end

    -- V5: 丹药计数上限校验（v13 统一到 player）
    -- 仅记日志 + clamp，不拒绝存档
    -- 向后兼容：旧存档 shop/challenges 丹药字段也做 clamp（MIGRATIONS[13] 之前的存档可能从未跑过迁移）
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
                print("[Server][V5] " .. pill.name .. " clamped: "
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
                print("[Server][V5] " .. pill.name .. " clamped: "
                    .. v .. " -> " .. pill.max
                    .. " userId=" .. tostring(userId))
                coreData.challenges[pill.field] = pill.max
            end
        end
    end
    if coreData.player then
        local playerPillLimits = {
            -- v13 同桶字段
            { field = "tigerPillCount",    max = 5,  name = "虎骨丹" },
            { field = "snakePillCount",    max = 5,  name = "灵蛇丹" },
            { field = "diamondPillCount",  max = 5,  name = "金刚丹" },
            { field = "temperingPillEaten", max = 50, name = "千锤百炼丹" },
            { field = "xueshaDanCount",    max = 9,  name = "血煞丹" },
            { field = "haoqiDanCount",     max = 9,  name = "浩气丹" },
            -- 原有 player 直存字段
            { field = "pillConstitution", max = 50, name = "根骨(千锤)" },
            { field = "pillPhysique",     max = SealDemonConfig.PHYSIQUE_PILL.maxCount, name = "体魄丹" },
            { field = "pillKillHeal",     max = 45, name = "击杀回血(血煞)" }, -- 9×5=45
            { field = "daoTreeWisdom",    max = 50, name = "悟道" },
            { field = "fruitFortune",     max = 30, name = "福缘果" },
            { field = "seaPillarDef",     max = 20, name = "海神柱防御" },
            { field = "seaPillarAtk",     max = 30, name = "海神柱攻击" },
            { field = "seaPillarMaxHp",   max = 300, name = "海神柱生命" },
            { field = "seaPillarHpRegen", max = 30, name = "海神柱恢复" },
        }
        for _, pill in ipairs(playerPillLimits) do
            local v = coreData.player[pill.field]
            if v and type(v) == "number" and v > pill.max then
                print("[Server][V5] " .. pill.name .. " clamped: "
                    .. v .. " -> " .. pill.max
                    .. " userId=" .. tostring(userId))
                coreData.player[pill.field] = pill.max
            end
        end
    end

    -- V5b: 海神柱等级校验（每根柱子 level 0~10）
    if coreData.seaPillar then
        local pillarIds = { "xuanbing", "youyuan", "lieyan", "liusha" }
        for _, pid in ipairs(pillarIds) do
            local p = coreData.seaPillar[pid]
            if p and type(p) == "table" then
                if p.level and type(p.level) == "number" then
                    if p.level < 0 then p.level = 0 end
                    if p.level > 10 then
                        print("[Server][V5b] SeaPillar " .. pid .. " level clamped: "
                            .. p.level .. " -> 10 userId=" .. tostring(userId))
                        p.level = 10
                    end
                end
            end
        end
    end

    -- V6: 仓库数据校验（unlockedRows 1~6，items 不超过已解锁槽位）
    if coreData.warehouse then
        local wh = coreData.warehouse
        local MAX_ROWS = 6
        local ITEMS_PER_ROW = 8
        -- 校验 unlockedRows
        if wh.unlockedRows == nil or type(wh.unlockedRows) ~= "number" then
            wh.unlockedRows = 1
        end
        if wh.unlockedRows < 1 then wh.unlockedRows = 1 end
        if wh.unlockedRows > MAX_ROWS then
            print("[Server][V6] warehouse unlockedRows clamped: "
                .. wh.unlockedRows .. " -> " .. MAX_ROWS
                .. " userId=" .. tostring(userId))
            wh.unlockedRows = MAX_ROWS
        end
        -- 校验 items：移除超出已解锁槽位的物品
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
                print("[Server][V6] warehouse item removed at slot " .. tostring(k)
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

        -- 计算所有境界奖励累计
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

        -- 丹药加成上限（虎骨30×5 + 浩气30×9 + 海神柱30×10 = 720 maxHp）
        local pillMaxHp = 150 + 270 + 300  -- 虎骨丹 + 浩气丹 + 烈焰海神柱
        local pillAtk = 50 + 72 + 30       -- 灵蛇丹 + 血煞丹 + 幽渊海神柱
        local pillDef = 40 + 20            -- 金刚丹 + 玄冰海神柱

        -- 期望值 = 初始 + 等级成长 + 境界奖励 + 丹药上限
        local expectedMaxHp = 100 + 15 * lv + realmMaxHp + pillMaxHp
        local expectedAtk = 15 + 3 * lv + realmAtk + pillAtk
        local expectedDef = 5 + 2 * lv + realmDef + pillDef

        -- 容忍度 3 倍（装备等额外来源）
        local tolerance = 3
        if cp.maxHp and type(cp.maxHp) == "number" and cp.maxHp > expectedMaxHp * tolerance then
            print(string.format("[Server][V5c] maxHp SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.maxHp, expectedMaxHp * tolerance, expectedMaxHp, tolerance, tostring(userId), realm, lv))
        end
        if cp.atk and type(cp.atk) == "number" and cp.atk > expectedAtk * tolerance then
            print(string.format("[Server][V5c] atk SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.atk, expectedAtk * tolerance, expectedAtk, tolerance, tostring(userId), realm, lv))
        end
        if cp.def and type(cp.def) == "number" and cp.def > expectedDef * tolerance then
            print(string.format("[Server][V5c] def SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.def, expectedDef * tolerance, expectedDef, tolerance, tostring(userId), realm, lv))
        end
    end

    -- v11 单 key 写入
    local saveKey = "save_" .. slot

    local batch = serverCloud:BatchSet(userId)
        :Set(saveKey, coreData)
    -- 清理旧格式 key（幂等 Delete）
    batch:Delete("save_data_" .. slot)
    batch:Delete("save_bag1_" .. slot)
    batch:Delete("save_bag2_" .. slot)

    -- 🔴 Bug fix: 仅当 slotsIndex 包含有效 slots 数据时才写入，
    -- 防止空 {} 覆盖服务端已有的 slots_index
    if ok4 and slotsIndex and slotsIndex.slots and next(slotsIndex.slots) then
        NormalizeSlotsIndex(slotsIndex)
        batch:Set("slots_index", slotsIndex)
    elseif ok4 and slotsIndex then
        print("[Server] SaveGame: SKIPPING empty slotsIndex write for userId=" .. tostring(userId))
    end

    -- 账号级数据
    local bulletinJson = eventData["bulletin"]:GetString()
    if bulletinJson and bulletinJson ~= "" then
        local ok6, bulletin = pcall(cjson.decode, bulletinJson)
        if ok6 and bulletin then
            batch:Set("account_bulletin", bulletin)
        end
    end

    -- 账号级仙图录：从 coreData 中提取，写入独立的 account_atlas key
    -- 仙图录是账号级系统，所有角色共享同一份数据
    if coreData.atlas then
        batch:Set("account_atlas", coreData.atlas)
        print("[Server] SaveGame: account_atlas written for userId=" .. tostring(userId))
    end

    -- 账号级外观数据：从 coreData 中提取，写入独立的 account_cosmetics key
    if coreData.accountCosmetics then
        batch:Set("account_cosmetics", coreData.accountCosmetics)
        print("[Server] SaveGame: account_cosmetics written for userId=" .. tostring(userId))
    end

    -- player_level
    local playerLevel = eventData["playerLevel"]:GetInt()
    if playerLevel and playerLevel > 0 then
        batch:SetInt("player_level", playerLevel)
    end

    -- 排行榜数据（P0: 服务端权威计算，不信任客户端 rankData）
    -- 使用 rank2_ 前缀的全新排行 key（v2 排行榜）
    local rankInfo, rankRejectReason = RankHandler.ComputeRankFromSaveData(coreData)

    -- 查 TapTap 昵称（服务端同步读取，排行榜多处复用）
    local taptapNick = nil
    GetUserNickname({
        userIds = { userId },
        onSuccess = function(nicknames)
            if nicknames and #nicknames > 0 then
                taptapNick = nicknames[1].nickname or ""
            end
        end,
    })

    if rankInfo then
        -- 角色名优先从 slotsIndex 取（save_data.player.charName 大多数存档为 nil）
        if ok4 and slotsIndex and slotsIndex.slots then
            local slotMeta = slotsIndex.slots[slot]
            if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                rankInfo.charName = slotMeta.name
            end
        end

        -- 附加信息通过 batch 写入 scores（rank2_info 是 Set 类型，含 TapTap 昵称）
        batch:Set("rank2_info_" .. slot, {
            name = rankInfo.charName,
            realm = rankInfo.realm,
            level = rankInfo.level,
            bossKills = rankInfo.bossKills,
            taptapNick = taptapNick,
            classId = rankInfo.classId,
        })
    elseif rankRejectReason and rankRejectReason ~= "level_too_low"
        and rankRejectReason ~= "no_player_data" then
        print("[Server][AntiCheat] Rank write rejected for userId="
            .. tostring(userId) .. " slot=" .. slot
            .. " reason=" .. rankRejectReason)
    end

    -- _code_ver（版本守卫）
    local codeVersion = eventData["codeVersion"]:GetInt()
    if codeVersion and codeVersion > 0 then
        batch:SetInt("_code_ver", codeVersion)
    end

    -- P0 排行榜修复：排行分数提前写入，不依赖 batch:Save 成功
    -- 原因：batch:Save 失败时 ok 回调不执行，导致 rank2_score 永远不更新
    -- SetInt 是独立的轻量写操作，成功率远高于复杂 batch 写入
    if rankInfo then
        serverCloud:SetInt(userId, "rank2_score_" .. slot, rankInfo.rankScore, {
            error = function(code, reason)
                print("[Server] RankV2 SetInt rank2_score FAILED: userId=" .. tostring(userId)
                    .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
            end,
        })
        serverCloud:SetInt(userId, "rank2_kills_" .. slot, rankInfo.bossKills, {
            error = function(code, reason)
                print("[Server] RankV2 SetInt rank2_kills FAILED: userId=" .. tostring(userId)
                    .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
            end,
        })
        if ok5 and rankData and rankData.achieveTime then
            serverCloud:SetInt(userId, "rank2_time_" .. slot, rankData.achieveTime, {
                error = function(code, reason)
                    print("[Server] RankV2 SetInt rank2_time FAILED: userId=" .. tostring(userId)
                        .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
        end
    end

    -- ═══ 青云试炼排行榜（trial_floor，per-user，取当前存档最高层）═══
    local trialTower = coreData.trialTower
    if trialTower and type(trialTower) == "table" then
        local highestFloor = trialTower.highestFloor
        if highestFloor and type(highestFloor) == "number" and highestFloor > 0 then
            local TRIAL_TIME_BASE = 10000000000 -- 10^10
            local trialComposite = highestFloor * TRIAL_TIME_BASE
                + (TRIAL_TIME_BASE - 1 - os.time())
            serverCloud:SetInt(userId, "trial_floor", trialComposite, {
                error = function(code, reason)
                    print("[Server] Trial SetInt trial_floor FAILED: userId=" .. tostring(userId)
                        .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
            -- 角色名
            local trialCharName = "修仙者"
            if ok4 and slotsIndex and slotsIndex.slots then
                local slotMeta = slotsIndex.slots[slot]
                if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                    trialCharName = slotMeta.name
                end
            elseif coreData.player and coreData.player.charName then
                trialCharName = coreData.player.charName
            end
            batch:Set("trial_info", {
                floor = highestFloor,
                name = trialCharName,
                realm = coreData.player and coreData.player.realm or "mortal",
                level = coreData.player and coreData.player.level or 1,
                taptapNick = taptapNick,
                classId = coreData.player and coreData.player.classId or "monk",
            })
            print("[Server] Trial: enrolled userId=" .. tostring(userId)
                .. " floor=" .. highestFloor .. " composite=" .. trialComposite)
        end
    end

    -- ═══ 青云镇狱塔排行榜（prison_floor，per-user，取当前存档最高层）═══
    local prisonTower = coreData.prisonTower
    if prisonTower and type(prisonTower) == "table" then
        local prisonHighest = prisonTower.highestFloor
        if prisonHighest and type(prisonHighest) == "number" and prisonHighest > 0 then
            local PRISON_TIME_BASE = 10000000000 -- 10^10
            local prisonComposite = prisonHighest * PRISON_TIME_BASE
                + (PRISON_TIME_BASE - 1 - os.time())
            serverCloud:SetInt(userId, "prison_floor", prisonComposite, {
                error = function(code, reason)
                    print("[Server] Prison SetInt prison_floor FAILED: userId=" .. tostring(userId)
                        .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
            -- 角色名
            local prisonCharName = "修仙者"
            if ok4 and slotsIndex and slotsIndex.slots then
                local slotMeta = slotsIndex.slots[slot]
                if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                    prisonCharName = slotMeta.name
                end
            elseif coreData.player and coreData.player.charName then
                prisonCharName = coreData.player.charName
            end
            batch:Set("prison_info", {
                floor = prisonHighest,
                name = prisonCharName,
                realm = coreData.player and coreData.player.realm or "mortal",
                level = coreData.player and coreData.player.level or 1,
                taptapNick = taptapNick,
                classId = coreData.player and coreData.player.classId or "monk",
            })
            print("[Server] Prison: enrolled userId=" .. tostring(userId)
                .. " floor=" .. prisonHighest .. " composite=" .. prisonComposite)
        end
    end

    batch:Save("存档", {
        ok = function()
            print("[Server] SaveGame OK: userId=" .. tostring(userId) .. " slot=" .. slot)

            local resultData = VariantMap()
            resultData["ok"] = Variant(true)
            resultData["requestId"] = Variant(requestId)
            SafeSend(connection, SaveProtocol.S2C_SaveResult, resultData)
        end,
        error = function(code, reason)
            print("[Server] SaveGame FAILED: " .. tostring(code) .. " " .. tostring(reason))
            local resultData = VariantMap()
            resultData["ok"] = Variant(false)
            resultData["message"] = Variant(tostring(reason))
            resultData["requestId"] = Variant(requestId)
            SafeSend(connection, SaveProtocol.S2C_SaveResult, resultData)
        end,
    })

end

-- ============================================================================
-- C2S_MigrateData — clientScore → serverCloud 迁移
-- ============================================================================

function HandleMigrateData(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local payloadJson = eventData["payload"]:GetString()
    local ok, payload = pcall(cjson.decode, payloadJson)
    if not ok or not payload then
        print("[Server] MigrateData: payload decode failed")
        SendResult(connection, SaveProtocol.S2C_MigrateResult, false, "数据格式错误")
        return
    end

    local source = payload._migrationSource or "clientCloud"
    print("[Server] MigrateData: userId=" .. tostring(userId) .. " source=" .. source)

    -- _migrationSource 不写入存储
    payload._migrationSource = nil

    -- ========================================================================
    -- 槽位映射规则：
    --   clientCloud 直写（原样搬运 slot 1→1, 2→2）
    --   local_file  重映射（slot 1→3, 2→4，预留恢复槽位）
    -- ========================================================================

    local slotMap = {}
    if source == "local_file" then
        slotMap = { [1] = 3, [2] = 4 }
    else
        slotMap = { [1] = 1, [2] = 2 }
    end

    -- 先读取现有数据，检查目标槽位是否已有内容（幂等保护）
    serverCloud:BatchGet(userId)
        :Key("slots_index")
        :Key("save_data_" .. slotMap[1])
        :Key("save_data_" .. slotMap[2])
        :Fetch({
            ok = function(existingScores)
                local existingSlotsIndex = existingScores["slots_index"] or { version = 1, slots = {} }
                existingSlotsIndex.slots = existingSlotsIndex.slots or {}
                NormalizeSlotsIndex(existingSlotsIndex)

                -- 幂等检查：目标槽位已有数据 → 跳过
                local alreadyMigrated = true
                for origSlot = 1, 2 do
                    local targetSlot = slotMap[origSlot]
                    local targetKey = "save_data_" .. targetSlot
                    local srcKey = "save_data_" .. origSlot
                    if payload[srcKey] and type(payload[srcKey]) == "table" then
                        if not existingScores[targetKey] or type(existingScores[targetKey]) ~= "table" then
                            alreadyMigrated = false
                            break
                        end
                    end
                end

                if alreadyMigrated then
                    print("[Server] MigrateData: target slots already have data, skipping (idempotent)")
                    SendResult(connection, SaveProtocol.S2C_MigrateResult, true)
                    return
                end

                -- G4: 迁移前备份完整 payload（安全网）
                local batch = serverCloud:BatchSet(userId)
                batch:Set("save_migrate_backup_" .. source, {
                    payload = payload,
                    migratedAt = os.time(),
                    source = source,
                })

                -- 处理 slots_index 合并
                local payloadSlotsIndex = payload.slots_index
                if payloadSlotsIndex and type(payloadSlotsIndex) == "table" then
                    payloadSlotsIndex.slots = payloadSlotsIndex.slots or {}
                    NormalizeSlotsIndex(payloadSlotsIndex)
                    for origSlot = 1, 2 do
                        local targetSlot = slotMap[origSlot]
                        if payloadSlotsIndex.slots[origSlot] then
                            local slotInfo = payloadSlotsIndex.slots[origSlot]
                            if source == "local_file" then
                                slotInfo.migrated = true
                                slotInfo.migratedFrom = "local_file"
                                slotInfo.migratedAt = os.time()
                            end
                            existingSlotsIndex.slots[targetSlot] = slotInfo
                        end
                    end
                    batch:Set("slots_index", existingSlotsIndex)
                end

                -- 重映射每个槽位的数据 key
                local slotDataKeys = { "save_data_", "save_bag1_", "save_bag2_", "rank_info_" }
                local slotIntKeys = { "rank_score_", "rank_time_", "boss_kills_" }

                for origSlot = 1, 2 do
                    local targetSlot = slotMap[origSlot]
                    -- table 类型数据
                    for _, prefix in ipairs(slotDataKeys) do
                        local srcKey = prefix .. origSlot
                        local dstKey = prefix .. targetSlot
                        if payload[srcKey] and type(payload[srcKey]) == "table" then
                            batch:Set(dstKey, payload[srcKey])
                        end
                    end
                    -- integer 类型数据
                    for _, prefix in ipairs(slotIntKeys) do
                        local srcKey = prefix .. origSlot
                        local dstKey = prefix .. targetSlot
                        if payload[srcKey] and type(payload[srcKey]) == "number" then
                            batch:SetInt(dstKey, math.floor(payload[srcKey]))
                        end
                    end
                end

                -- 非槽位相关的全局 key（account_bulletin, player_level, _code_ver 等）
                local globalTableKeys = { "account_bulletin", "save_data" }
                for _, key in ipairs(globalTableKeys) do
                    if payload[key] and type(payload[key]) == "table" then
                        batch:Set(key, payload[key])
                    end
                end
                local globalIntKeys = { "player_level", "_code_ver" }
                for _, key in ipairs(globalIntKeys) do
                    if payload[key] and type(payload[key]) == "number" then
                        batch:SetInt(key, math.floor(payload[key]))
                    end
                end

                batch:Save(source .. "迁移", {
                    ok = function()
                        print("[Server] MigrateData OK: userId=" .. tostring(userId)
                            .. " source=" .. source
                            .. " slotMap=" .. slotMap[1] .. "," .. slotMap[2])
                        SendResult(connection, SaveProtocol.S2C_MigrateResult, true)
                    end,
                    error = function(code, reason)
                        print("[Server] MigrateData FAILED: " .. tostring(code) .. " " .. tostring(reason))
                        SendResult(connection, SaveProtocol.S2C_MigrateResult, false, tostring(reason))
                    end,
                })
            end,
            error = function(code, reason)
                print("[Server] MigrateData pre-check failed: " .. tostring(code) .. " " .. tostring(reason))
                SendResult(connection, SaveProtocol.S2C_MigrateResult, false, tostring(reason))
            end,
        })
end

-- ============================================================================
-- ============================================================================
-- §4.5 B2: DaoTree + GMResetDaily 已拆入 DaoTreeHandler
-- 此处保留全局函数名以兼容 RateLimitedSubscribe 路由
-- ============================================================================
function HandleDaoTreeStart(eventType, eventData)
    DaoTreeHandler.HandleDaoTreeStart(eventType, eventData)
end

function HandleDaoTreeComplete(eventType, eventData)
    DaoTreeHandler.HandleDaoTreeComplete(eventType, eventData)
end

function HandleGMResetDaily(eventType, eventData)
    DaoTreeHandler.HandleGMResetDaily(eventType, eventData)
end

-- ============================================================================
-- §4.5 B1: HandleBuyPill / HandleGMCommand 已拆入独立模块
-- 此处保留全局函数名以兼容 RateLimitedSubscribe 路由
-- ============================================================================
function HandleBuyPill(eventType, eventData)
    PillHandler.HandleBuyPill(eventType, eventData)
end

function HandleGMCommand(eventType, eventData)
    GMHandler.HandleGMCommand(eventType, eventData)
end

-- ============================================================================
-- §4.5 B2: DaoTreeQuery / SealDemon / Trial 已拆入独立模块
-- 此处保留全局函数名以兼容 RateLimitedSubscribe 路由
-- ============================================================================
function HandleDaoTreeQuery(eventType, eventData)
    DaoTreeHandler.HandleDaoTreeQuery(eventType, eventData)
end

function HandleSealDemonAccept(eventType, eventData)
    SealDemonHandler.HandleSealDemonAccept(eventType, eventData)
end

function HandleSealDemonBossKilled(eventType, eventData)
    SealDemonHandler.HandleSealDemonBossKilled(eventType, eventData)
end

function HandleSealDemonAbandon(eventType, eventData)
    SealDemonHandler.HandleSealDemonAbandon(eventType, eventData)
end

function HandleTrialClaimDaily(eventType, eventData)
    TrialHandler.HandleTrialClaimDaily(eventType, eventData)
end

-- ============================================================================

-- ============================================================================
-- §4.5 B3: Rank + Redeem 已拆入 RankHandler / RedeemHandler
-- 此处保留全局函数名以兼容 RateLimitedSubscribe 路由
-- ============================================================================
function HandleGetRankList(eventType, eventData)
    RankHandler.HandleGetRankList(eventType, eventData)
end

function HandleGMCreateCode(eventType, eventData)
    RedeemHandler.HandleGMCreateCode(eventType, eventData)
end

function HandleRedeemCode(eventType, eventData)
    RedeemHandler.HandleRedeemCode(eventType, eventData)
end

function HandleTryUnlockRace(eventType, eventData)
    RankHandler.HandleTryUnlockRace(eventType, eventData)
end

function HandleCheckEventGrant(eventType, eventData)
    RankHandler.HandleCheckEventGrant(eventType, eventData)
end

function HandleCheckRaceSlots(eventType, eventData)
    RankHandler.HandleCheckRaceSlots(eventType, eventData)
end

-- §4.2/4.3 C4/C5: serverCloud API 验证（临时测试入口，验证后移除）
function HandleServerApiTest(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Session.ConnKey(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then return end

    -- 仅管理员可执行
    if not Session.IsGMAdmin(userId) then
        print("[Server][ApiTest] REJECTED: userId=" .. tostring(userId) .. " not admin")
        return
    end

    print("[Server][ApiTest] 开始 C4/C5 验证, userId=" .. tostring(userId))
    local C4C5Test = require("tests.c4c5_server_test")
    C4C5Test.Run(serverCloud, userId, function(passed, failed, logStr)
        print("[Server][ApiTest] 完成: " .. passed .. " passed, " .. failed .. " failed")
        local data = VariantMap()
        data["passed"] = Variant(passed)
        data["failed"] = Variant(failed)
        data["log"] = Variant(logStr)
        Session.SafeSend(connection, SaveProtocol.S2C_ServerApiTestResult, data)
    end)
end

-- ============================================================================
-- 万界黑商 — 全局包装函数
-- ============================================================================

function HandleBlackMerchantQuery(eventType, eventData)
    BlackMerchantHandler.HandleQuery(eventType, eventData)
end

function HandleBlackMerchantBuy(eventType, eventData)
    BlackMerchantHandler.HandleBuy(eventType, eventData)
end

function HandleBlackMerchantSell(eventType, eventData)
    BlackMerchantHandler.HandleSell(eventType, eventData)
end

function HandleBlackMerchantExchange(eventType, eventData)
    BlackMerchantHandler.HandleExchange(eventType, eventData)
end

function HandleBlackMerchantHistory(eventType, eventData)
    BlackMerchantHandler.HandleHistory(eventType, eventData)
end

-- ============================================================================
-- 皮肤商店（大黑无天） — 全局包装函数
-- ============================================================================

function HandleSkinShopQuery(eventType, eventData)
    SkinShopHandler.HandleQuery(eventType, eventData)
end

function HandleSkinShopBuy(eventType, eventData)
    SkinShopHandler.HandleBuy(eventType, eventData)
end

-- ============================================================================
-- 仙缘宝箱 — 全局包装函数
-- ============================================================================

function HandleXianyuanChestStartOpen(eventType, eventData)
    XianyuanChestHandler.HandleStartOpen(eventType, eventData)
end

function HandleXianyuanChestCancelOpen(eventType, eventData)
    XianyuanChestHandler.HandleCancelOpen(eventType, eventData)
end

function HandleXianyuanChestCompleteOpen(eventType, eventData)
    XianyuanChestHandler.HandleCompleteOpen(eventType, eventData)
end

function HandleXianyuanChestPick(eventType, eventData)
    XianyuanChestHandler.HandlePick(eventType, eventData)
end

-- ============================================================================
-- 五一活动 — 全局包装函数
-- ============================================================================

function HandleEventExchange(eventType, eventData)
    if EventHandler then EventHandler.HandleExchange(eventType, eventData) end
end

function HandleEventOpenFudai(eventType, eventData)
    if EventHandler then EventHandler.HandleOpenFudai(eventType, eventData) end
end

function HandleEventGetRankList(eventType, eventData)
    if EventHandler then EventHandler.HandleGetRankList(eventType, eventData) end
end

function HandleEventGetPullRecords(eventType, eventData)
    if EventHandler then EventHandler.HandleGetPullRecords(eventType, eventData) end
end

-- ============================================================================
-- 多人副本（四兽岛）
-- ============================================================================

function HandleEnterDungeon(eventType, eventData)
    if not GameConfig.DUNGEON_ENABLED then return end
    if DungeonHandler then DungeonHandler.HandleEnterDungeon(eventType, eventData) end
end

function HandleLeaveDungeon(eventType, eventData)
    if not GameConfig.DUNGEON_ENABLED then return end
    if DungeonHandler then DungeonHandler.HandleLeaveDungeon(eventType, eventData) end
end

function HandleDungeonPlayerPosition(eventType, eventData)
    if not GameConfig.DUNGEON_ENABLED then return end
    if DungeonHandler then
        local ok, err = pcall(DungeonHandler.HandlePlayerPositionEvent, eventType, eventData)
        if not ok then print("[Server] HandleDungeonPlayerPosition pcall error: " .. tostring(err)) end
    end
end

function HandleDungeonAttack(eventType, eventData)
    if not GameConfig.DUNGEON_ENABLED then return end
    if DungeonHandler then
        local ok, err = pcall(DungeonHandler.HandleDungeonAttack, eventType, eventData)
        if not ok then print("[Server] HandleDungeonAttack pcall error: " .. tostring(err)) end
    end
end

function HandleQueryDungeonReward(eventType, eventData)
    if DungeonHandler then DungeonHandler.HandleQueryDungeonReward(eventType, eventData) end
end

function HandleClaimDungeonReward(eventType, eventData)
    if DungeonHandler then DungeonHandler.HandleClaimDungeonReward(eventType, eventData) end
end

-- ============================================================================
-- 服务端 Update（副本系统定时逻辑）
-- ============================================================================

function HandleServerUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if GameConfig.DUNGEON_ENABLED and DungeonHandler then
        local ok, err = pcall(DungeonHandler.Update, dt)
        if not ok then print("[Server] DungeonHandler.Update pcall error: " .. tostring(err)) end
    end
    -- §12 黑市自动收购（先占坑再干活，详见 BlackMerchantHandler.RecycleTick）
    if BlackMerchantHandler then
        local ok2, err2 = pcall(BlackMerchantHandler.RecycleTick, dt)
        if not ok2 then print("[Server] BlackMerchantHandler.RecycleTick pcall error: " .. tostring(err2)) end
    end
end

