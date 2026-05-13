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
local Logger = require("utils.Logger")

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
-- §R3: 主存档链路服务壳（等价拆分第一阶段）
local SlotReadService   = require("network.SlotReadService")
local SaveLoadService   = require("network.SaveLoadService")
local SaveWriteService  = require("network.SaveWriteService")
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

    -- §R3: 委托 SlotReadService
    SlotReadService.Execute(connection, connKey, userId)
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
    connSlots_[connKey] = slot

    -- §R3: 委托 SaveLoadService
    SaveLoadService.Execute(connection, connKey, userId, slot)
end

-- ============================================================================
-- C2S_SaveGame — 保存存档
-- ============================================================================

function HandleSaveGame(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)

    local userId = GetUserId(connKey)
    if not userId then
        print("[Server] SaveGame: no userId for connKey=" .. connKey)
        return
    end

    local slot = eventData["slot"]:GetInt()
    connSlots_[connKey] = slot

    -- §R3: 委托 SaveWriteService
    SaveWriteService.Execute(connection, connKey, userId, slot, eventData)
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

