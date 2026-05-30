-- ============================================================================
-- EventHandler.lua — 六一活动服务端 Handler
--
-- 职责：处理 4 个 C2S 协议
--   1. HandleExchange   — 活动兑换（六一不启用）
--   2. HandleOpenFudai  — 开启宝箱（小宝箱/大宝箱, ×1 / ×5）
--   3. HandleGetRankList — 查询积分排行榜
--   4. HandleGetPullRecords — 查询全服稀有抽取记录
--
-- 模式：完全复刻 BlackMerchantHandler 的模块结构
-- 设计文档：docs/六一世界掉落活动（代码执行文档）.md v1.2
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local EventConfig = require("config.EventConfig")
local EventSystem = require("systems.EventSystem")
local BackpackUtils = require("network.BackpackUtils")

local cjson = cjson ---@diagnostic disable-line: undefined-global

local M = {}

-- ============================================================================
-- 常量
-- ============================================================================

local SYSTEM_UID = 0                          -- 全服公共记录所有者
local MAX_PULL_RECORDS = 50                   -- 最多保留最近 50 条

-- ============================================================================
-- 模块级内存锁（防同一用户并发请求）
-- ============================================================================

local fudaiLocks_ = {}      -- key = userId
local exchangeLocks_ = {}   -- key = userId

-- ============================================================================
-- 背包操作别名
-- ============================================================================

local CountBackpackItem  = BackpackUtils.CountBackpackItem
local AddToBackpack      = BackpackUtils.AddToBackpack
local RemoveFromBackpack = BackpackUtils.RemoveFromBackpack

-- ============================================================================
-- 内部工具（与 BlackMerchantHandler 对齐）
-- ============================================================================

--- 从 eventData 提取 connKey + userId + connection，校验前置条件
---@return string|nil connKey
---@return integer|nil userId
---@return any connection
local function ExtractContext(eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Session.ConnKey(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then
        return nil, nil, connection
    end
    if not Session.connSlots_[connKey] then
        return nil, nil, connection
    end
    return connKey, userId, connection
end

--- 发送错误响应
---@param connection any
---@param eventName string S2C 事件名
---@param reason string
---@param extra table|nil 额外字段 { [k]=Variant }
local function SendError(connection, eventName, reason, extra)
    local data = VariantMap()
    data["ok"] = Variant(false)
    data["reason"] = Variant(reason or "unknown")
    if extra then
        for k, v in pairs(extra) do
            data[k] = v
        end
    end
    Session.SafeSend(connection, eventName, data)
end

-- ============================================================================
-- FIFO 截断：超出 MAX_PULL_RECORDS 时删除最旧记录
-- ============================================================================

local function TrimPullRecords(recordsKey)
    serverCloud.list:Get(SYSTEM_UID, recordsKey, {
        ok = function(list)
            if #list <= MAX_PULL_RECORDS then return end
            table.sort(list, function(a, b)
                local tA = (a.value and a.value.ts) or 0
                local tB = (b.value and b.value.ts) or 0
                return tA < tB  -- 最旧的在前面
            end)
            local toDelete = #list - MAX_PULL_RECORDS
            for i = 1, toDelete do
                if list[i] and list[i].list_id then
                    serverCloud.list:Delete(list[i].list_id)
                end
            end
        end,
    })
end

--- 玩家名展示
---@param playerName string
---@return string
local function MaskPlayerName(playerName)
    if not playerName or playerName == "" then return "???" end
    return playerName
end

-- ============================================================================
-- 辅助：写入排行附加信息 + TapTap 昵称
-- ============================================================================

local function WriteRankInfo(userId, infoKey, charName, classId)
    GetUserNickname({
        userIds = { userId },
        onSuccess = function(nicknames)
            local taptapNick = ""
            if nicknames and #nicknames > 0 then
                taptapNick = nicknames[1].nickname or ""
            end
            serverCloud:BatchSet(userId)
                :Set(infoKey, {
                    name = charName,
                    classId = classId,
                    taptapNick = taptapNick,
                })
                :Save(infoKey, {
                    ok = function()
                        print("[EventHandler] RankInfo saved: user=" .. tostring(userId)
                            .. " name=" .. charName .. " nick=" .. tostring(taptapNick))
                    end,
                    error = function(code, reason)
                        print("[EventHandler] RankInfo save FAILED: " .. tostring(code)
                            .. " " .. tostring(reason))
                    end,
                })
        end,
    })
end

-- ============================================================================
-- 辅助：全服抽取记录（稀有/传说写入 serverCloud.list）
-- ============================================================================

local function WritePullRecords(charName, rollResults, recordsKey, boxType)
    local masked = MaskPlayerName(charName)
    for _, r in ipairs(rollResults) do
        if r.rarity == "rare" or r.rarity == "legendary" then
            serverCloud.list:Add(SYSTEM_UID, recordsKey, {
                displayName = masked,
                name = r.name,
                rarity = r.rarity,
                boxType = boxType or r.boxType,
                ts = os.time(),
            })
        end
    end
    TrimPullRecords(recordsKey)
end

-- ============================================================================
-- HandleExchange — 活动兑换（六一不启用，保留接口兼容）
-- ============================================================================

function M.HandleExchange(eventType, eventData)
    -- 活动未激活 → 静默忽略
    if not EventConfig.IsActive() then return end

    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    -- 内存锁（防并发）
    if exchangeLocks_[userId] then return end
    exchangeLocks_[userId] = true

    local exchangeId = eventData["ExchangeId"]:GetString()

    -- 查找兑换配置
    local exchangeCfg = EventConfig.FindExchange(exchangeId)
    if not exchangeCfg then
        exchangeLocks_[userId] = nil
        SendError(connection, SaveProtocol.S2C_EventExchangeResult, "无效的兑换项")
        return
    end

    -- 槽位锁
    local currentSlot = Session.connSlots_[connKey]
    if not Session.AcquireSlotLock(userId, currentSlot) then
        exchangeLocks_[userId] = nil
        SendError(connection, SaveProtocol.S2C_EventExchangeResult, "操作中，请稍后")
        return
    end

    local function releaseLocks()
        exchangeLocks_[userId] = nil
        Session.ReleaseSlotLock(userId, currentSlot)
    end

    -- 读取存档
    local saveKey = "save_" .. currentSlot
    serverCloud:Get(userId, saveKey, {
        ok = function(scores)
            local saveData = scores[saveKey] or {}
            local backpack = saveData.backpack or {}
            local evtAllData = saveData.event_data or {}
            local evtState = evtAllData[EventConfig.GetEventId()] or {}
            local exchanged = evtState.exchanged or {}

            -- 校验限购（limit=-1 表示不限）
            local usedCount = exchanged[exchangeId] or 0
            if exchangeCfg.limit > 0 and usedCount >= exchangeCfg.limit then
                releaseLocks()
                SendError(connection, SaveProtocol.S2C_EventExchangeResult, "已达兑换上限")
                return
            end

            -- 校验背包材料数量
            for itemId, needCount in pairs(exchangeCfg.cost) do
                local held = CountBackpackItem(backpack, itemId)
                if held < needCount then
                    releaseLocks()
                    SendError(connection, SaveProtocol.S2C_EventExchangeResult, "材料不足")
                    return
                end
            end

            -- 扣材料
            for itemId, needCount in pairs(exchangeCfg.cost) do
                RemoveFromBackpack(backpack, itemId, needCount)
            end

            -- 发奖励
            local reward = exchangeCfg.reward
            if reward.type == "lingYun" then
                saveData.player = saveData.player or {}
                saveData.player.lingYun = (saveData.player.lingYun or 0) + reward.count
            elseif reward.type == "consumable" then
                AddToBackpack(backpack, reward.id, reward.count)
            end

            -- 记录兑换次数
            exchanged[exchangeId] = usedCount + 1
            evtState.exchanged = exchanged
            evtAllData[EventConfig.GetEventId()] = evtState
            saveData.event_data = evtAllData

            -- 原子提交
            saveData.timestamp = os.time()
            local commit = serverCloud:BatchCommit("event_exchange")
            commit:ScoreSet(userId, saveKey, saveData)
            commit:Commit({
                ok = function()
                    local reply = VariantMap()
                    reply["ok"] = Variant(true)
                    reply["ExchangeId"] = Variant(exchangeId)
                    reply["UsedCount"] = Variant(usedCount + 1)
                    reply["Reward"] = Variant(cjson.encode(reward))
                    Session.SafeSend(connection, SaveProtocol.S2C_EventExchangeResult, reply)
                    releaseLocks()
                    print("[EventHandler] Exchange OK: " .. exchangeId .. " user=" .. tostring(userId))
                end,
                error = function(code, reason)
                    releaseLocks()
                    SendError(connection, SaveProtocol.S2C_EventExchangeResult, "兑换失败，请重试")
                    print("[EventHandler] Exchange FAILED: " .. tostring(code) .. " " .. tostring(reason))
                end,
            })
        end,
        error = function()
            releaseLocks()
            SendError(connection, SaveProtocol.S2C_EventExchangeResult, "服务器忙，请稍后")
        end,
    })
end

-- ============================================================================
-- HandleOpenFudai — 开启宝箱（双宝箱：小宝箱/大宝箱, ×1 / ×5）
-- 设计文档：docs/六一世界掉落活动（代码执行文档）.md §4.4
-- ============================================================================

function M.HandleOpenFudai(eventType, eventData)
    if not EventConfig.IsActive() then return end

    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    -- 内存锁
    if fudaiLocks_[userId] then return end
    fudaiLocks_[userId] = true

    local requestCount = eventData["Count"]:GetInt()
    local boxType = eventData["BoxType"]:GetString()

    -- 请求数量白名单（仅允许 1 或 5）
    if requestCount ~= 1 and requestCount ~= 5 then
        fudaiLocks_[userId] = nil
        return  -- 非法数量，静默拒绝
    end

    -- 校验 BoxType
    local event = EventConfig.ACTIVE_EVENT
    local boxCfg = event.openBoxes and event.openBoxes[boxType]
    if not boxCfg then
        fudaiLocks_[userId] = nil
        return  -- 非法 BoxType，静默拒绝
    end

    -- 从配置读取排行/记录 key
    local leaderboard = event.leaderboard
    local rankKey = leaderboard.rankKey
    local infoKey = leaderboard.infoKey
    local recordsKey = leaderboard.recordsKey

    -- 槽位锁
    local currentSlot = Session.connSlots_[connKey]
    if not Session.AcquireSlotLock(userId, currentSlot) then
        fudaiLocks_[userId] = nil
        SendError(connection, SaveProtocol.S2C_EventOpenFudaiResult, "操作中，请稍后")
        return
    end

    local function releaseLocks()
        fudaiLocks_[userId] = nil
        Session.ReleaseSlotLock(userId, currentSlot)
    end

    -- 读取存档
    local saveKey = "save_" .. currentSlot
    serverCloud:Get(userId, saveKey, {
        ok = function(scores)
            local saveData = scores[saveKey] or {}
            local backpack = saveData.backpack or {}

            -- 服务端校验背包物品数量
            local targetItemId = boxCfg.itemId
            local heldCount = CountBackpackItem(backpack, targetItemId)

            if heldCount <= 0 then
                releaseLocks()
                local itemName = (boxType == "big") and "流光风车" or "童趣拨浪鼓"
                SendError(connection, SaveProtocol.S2C_EventOpenFudaiResult, "没有" .. itemName)
                return
            end

            -- 背包空位检查
            local usedSlots = 0
            for i = 1, BackpackUtils.MAX_BACKPACK_SLOTS do
                if backpack[tostring(i)] then usedSlots = usedSlots + 1 end
            end
            if usedSlots >= BackpackUtils.MAX_BACKPACK_SLOTS then
                releaseLocks()
                SendError(connection, SaveProtocol.S2C_EventOpenFudaiResult, "背包已满，请先清理背包")
                return
            end

            -- 实际开启数量 = min(请求数, 持有数)
            local actualCount = math.min(requestCount, heldCount)

            -- 选择对应奖池
            local pool = event[boxCfg.poolKey]
            if not pool then
                releaseLocks()
                SendError(connection, SaveProtocol.S2C_EventOpenFudaiResult, "奖池配置异常")
                return
            end

            -- 服务端执行 N 次独立抽取
            local rollResults = {}
            local totalRewards = { exp = 0, gold = 0, lingYun = 0, consumables = {} }
            local skinRewards = {}  -- 记录抽到的皮肤奖励

            for i = 1, actualCount do
                local entry = EventSystem.RollFudaiReward(pool)
                rollResults[#rollResults + 1] = {
                    id = entry.id, name = entry.name, rarity = entry.rarity,
                }

                for _, r in ipairs(entry.rewards) do
                    if r.type == "exp" then
                        totalRewards.exp = totalRewards.exp + r.count
                    elseif r.type == "gold" then
                        totalRewards.gold = totalRewards.gold + r.count
                    elseif r.type == "lingYun" then
                        totalRewards.lingYun = totalRewards.lingYun + r.count
                    elseif r.type == "consumable" then
                        totalRewards.consumables[r.id] =
                            (totalRewards.consumables[r.id] or 0) + r.count
                    elseif r.type == "petSkin" then
                        skinRewards[#skinRewards + 1] = {
                            id = r.id,
                            dupLingYun = r.dupLingYun or 10000,
                        }
                    end
                end
            end

            -- ================================================================
            -- 皮肤奖励处理：需要先读 account_cosmetics 判断是否已拥有
            -- ================================================================
            local function ProcessAfterSkinCheck(unlockedSkinId, dupLingYunTotal)
                -- 扣宝箱道具 + 发奖励
                RemoveFromBackpack(backpack, targetItemId, actualCount)

                saveData.player = saveData.player or {}
                saveData.player.exp = (saveData.player.exp or 0) + totalRewards.exp
                saveData.player.gold = (saveData.player.gold or 0) + totalRewards.gold
                saveData.player.lingYun = (saveData.player.lingYun or 0)
                    + totalRewards.lingYun + dupLingYunTotal

                for consumableId, count in pairs(totalRewards.consumables) do
                    local lost = AddToBackpack(backpack, consumableId, count)
                    if lost > 0 then
                        print("[EventHandler] WARNING: backpack full, lost " .. lost .. "x " .. consumableId)
                    end
                end

                -- 计算本次积分增量
                local scoreAdd = boxCfg.score * actualCount

                saveData.timestamp = os.time()
                local commit = serverCloud:BatchCommit("event_open_fudai")
                commit:ScoreSet(userId, saveKey, saveData)
                -- 排行榜积分递增（服务端权威）
                commit:ScoreAddInt(userId, rankKey, scoreAdd)

                -- 如果有皮肤解锁，写入 account_cosmetics
                if unlockedSkinId then
                    -- account_cosmetics 写入在下方 Commit ok 回调中执行
                end

                commit:Commit({
                    ok = function()
                        -- 写入排行附加信息（角色名/职业/TapTap昵称）
                        local classId = (saveData.player or {}).classId or "monk"
                        local fallbackName = (saveData.player or {}).charName or "修仙者"

                        serverCloud:BatchGet(userId)
                            :Key("slots_index")
                            :Fetch({
                                ok = function(result)
                                    local slotsIndex = result["slots_index"] or {}
                                    slotsIndex = Session.NormalizeSlotsIndex(slotsIndex)
                                    local slotMeta = slotsIndex.slots and slotsIndex.slots[currentSlot]
                                    local charName = (slotMeta and slotMeta.name and slotMeta.name ~= "")
                                        and slotMeta.name or fallbackName

                                    WriteRankInfo(userId, infoKey, charName, classId)
                                    WritePullRecords(charName, rollResults, recordsKey, boxType)
                                end,
                                error = function()
                                    WriteRankInfo(userId, infoKey, fallbackName, classId)
                                    WritePullRecords(fallbackName, rollResults, recordsKey, boxType)
                                end,
                            })

                        -- 皮肤解锁持久化到 account_cosmetics
                        if unlockedSkinId then
                            serverCloud:BatchGet(userId)
                                :Key("account_cosmetics")
                                :Fetch({
                                    ok = function(cosResult)
                                        local cosmetics = cosResult["account_cosmetics"] or {}
                                        cosmetics.petAppearances = cosmetics.petAppearances or {}
                                        cosmetics.petAppearances[unlockedSkinId] = { unlocked = true }
                                        serverCloud:BatchSet(userId)
                                            :Set("account_cosmetics", cosmetics)
                                            :Save("account_cosmetics_skin_unlock", {
                                                ok = function()
                                                    print("[EventHandler] Skin unlocked: " .. unlockedSkinId
                                                        .. " user=" .. tostring(userId))
                                                end,
                                                error = function(code, reason)
                                                    print("[EventHandler] Skin unlock FAILED: "
                                                        .. tostring(code) .. " " .. tostring(reason))
                                                end,
                                            })
                                    end,
                                    error = function(code, reason)
                                        print("[EventHandler] account_cosmetics fetch FAILED: "
                                            .. tostring(code) .. " " .. tostring(reason))
                                    end,
                                })
                        end

                        -- 发送结果给客户端
                        local reply = VariantMap()
                        reply["ok"] = Variant(true)
                        reply["BoxType"] = Variant(boxType)
                        reply["Count"] = Variant(actualCount)
                        reply["Results"] = Variant(cjson.encode(rollResults))
                        reply["TotalExp"] = Variant(totalRewards.exp)
                        reply["TotalGold"] = Variant(totalRewards.gold)
                        reply["TotalLingYun"] = Variant(totalRewards.lingYun + dupLingYunTotal)
                        reply["Consumables"] = Variant(cjson.encode(totalRewards.consumables))
                        if unlockedSkinId then
                            reply["UnlockedSkinId"] = Variant(unlockedSkinId)
                        end
                        Session.SafeSend(connection, SaveProtocol.S2C_EventOpenFudaiResult, reply)

                        releaseLocks()
                        print("[EventHandler] OpenBox OK: type=" .. boxType .. " count=" .. actualCount
                            .. " score=+" .. scoreAdd .. " user=" .. tostring(userId))
                    end,
                    error = function(code, reason)
                        releaseLocks()
                        SendError(connection, SaveProtocol.S2C_EventOpenFudaiResult, "开启失败，请重试")
                        print("[EventHandler] OpenBox FAILED: " .. tostring(code) .. " " .. tostring(reason))
                    end,
                })
            end

            -- ================================================================
            -- 皮肤奖励预处理：检查是否已拥有，决定解锁 or 补偿灵韵
            -- ================================================================
            if #skinRewards > 0 then
                -- 读取 account_cosmetics 判断皮肤是否已拥有
                serverCloud:BatchGet(userId)
                    :Key("account_cosmetics")
                    :Fetch({
                        ok = function(cosResult)
                            local cosmetics = cosResult["account_cosmetics"] or {}
                            local petApps = cosmetics.petAppearances or {}
                            local unlockedSkinId = nil
                            local dupLingYunTotal = 0

                            for _, skin in ipairs(skinRewards) do
                                if petApps[skin.id] and petApps[skin.id].unlocked then
                                    -- 已拥有 → 补偿灵韵
                                    dupLingYunTotal = dupLingYunTotal + skin.dupLingYun
                                else
                                    -- 未拥有 → 解锁（多次抽到同一皮肤，第一次解锁，后续补偿）
                                    if not unlockedSkinId then
                                        unlockedSkinId = skin.id
                                    else
                                        -- 同一轮抽到多次相同皮肤，第二次起按重复补偿
                                        dupLingYunTotal = dupLingYunTotal + skin.dupLingYun
                                    end
                                end
                            end

                            ProcessAfterSkinCheck(unlockedSkinId, dupLingYunTotal)
                        end,
                        error = function()
                            -- 读取失败 → 保守处理：仍然尝试解锁第一个皮肤
                            local unlockedSkinId = skinRewards[1].id
                            local dupLingYunTotal = 0
                            for i = 2, #skinRewards do
                                dupLingYunTotal = dupLingYunTotal + skinRewards[i].dupLingYun
                            end
                            ProcessAfterSkinCheck(unlockedSkinId, dupLingYunTotal)
                        end,
                    })
            else
                -- 无皮肤奖励，直接走正常流程
                ProcessAfterSkinCheck(nil, 0)
            end
        end,
        error = function()
            releaseLocks()
            SendError(connection, SaveProtocol.S2C_EventOpenFudaiResult, "服务器忙，请稍后")
        end,
    })
end

-- ============================================================================
-- HandleGetRankList — 查询积分排行榜
-- ============================================================================

function M.HandleGetRankList(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    local event = EventConfig.ACTIVE_EVENT
    local leaderboard = event.leaderboard
    local rankKey = leaderboard.rankKey
    local infoKey = leaderboard.infoKey
    local displayCount = leaderboard.displayCount or 10

    --- 发送排行榜回复的公共函数
    local function sendReply(processed, myRank, myScore, total)
        local reply = VariantMap()
        reply["ok"] = Variant(true)
        reply["RankList"] = Variant(cjson.encode(processed))
        reply["MyRank"] = Variant(myRank or 0)
        reply["MyScore"] = Variant(myScore or 0)
        reply["Total"] = Variant(total or 0)
        reply["RewardHint"] = Variant(leaderboard.rewardHint or "")
        Session.SafeSend(connection, SaveProtocol.S2C_EventRankListData, reply)
    end

    -- 查询排行榜 Top N
    serverCloud:GetRankList(rankKey, 0, displayCount, {
        ok = function(rankList)
            if #rankList == 0 then
                serverCloud:GetUserRank(userId, rankKey, {
                    ok = function(myRank, myScore)
                        serverCloud:GetRankTotal(rankKey, {
                            ok = function(total) sendReply({}, myRank, myScore, total) end,
                            error = function() sendReply({}, myRank, myScore, 0) end,
                        })
                    end,
                    error = function() sendReply({}, 0, 0, 0) end,
                })
                return
            end

            -- 1. 提取 userId 列表 + 基础结果
            local userIds = {}
            local results = {}
            for _, item in ipairs(rankList) do
                userIds[#userIds + 1] = item.userId
                results[#results + 1] = {
                    charName = "",
                    taptapNick = "",
                    classId = "monk",
                    score = item.iscore and item.iscore[rankKey] or 0,
                }
            end

            -- 2. 批量获取排行附加信息
            local infoMap = {}
            local fetchDone = 0
            local fetchTotal = #userIds

            local function onAllInfoFetched()
                for idx, entry in ipairs(results) do
                    local info = infoMap[tostring(userIds[idx])]
                    if info then
                        entry.charName = info.name or "修仙者"
                        entry.classId = info.classId or "monk"
                        entry.taptapNick = info.taptapNick or ""
                    end
                end

                -- 3. 补充 TapTap 平台昵称
                GetUserNickname({
                    userIds = userIds,
                    onSuccess = function(nicknames)
                        local nickMap = {}
                        for _, ni in ipairs(nicknames) do
                            nickMap[ni.userId] = ni.nickname or ""
                        end
                        for idx, entry in ipairs(results) do
                            local nick = nickMap[userIds[idx]]
                            if nick and nick ~= "" then
                                entry.taptapNick = nick
                            end
                            if entry.charName == "" then
                                entry.charName = "修仙者"
                            end
                        end
                    end,
                })

                -- 4. 查询自己排名 + 总人数
                serverCloud:GetUserRank(userId, rankKey, {
                    ok = function(myRank, myScore)
                        serverCloud:GetRankTotal(rankKey, {
                            ok = function(total)
                                sendReply(results, myRank, myScore, total)
                            end,
                            error = function()
                                sendReply(results, myRank, myScore, 0)
                            end,
                        })
                    end,
                    error = function()
                        sendReply(results, 0, 0, 0)
                    end,
                })
            end

            -- 逐个 BatchGet 获取排行信息
            for _, uid in ipairs(userIds) do
                serverCloud:BatchGet(uid)
                    :Key(infoKey)
                    :Fetch({
                        ok = function(fetchScores)
                            infoMap[tostring(uid)] = fetchScores[infoKey]
                            fetchDone = fetchDone + 1
                            if fetchDone >= fetchTotal then onAllInfoFetched() end
                        end,
                        error = function()
                            fetchDone = fetchDone + 1
                            if fetchDone >= fetchTotal then onAllInfoFetched() end
                        end,
                    })
            end
        end,
        error = function()
            SendError(connection, SaveProtocol.S2C_EventRankListData, "排行查询失败")
        end,
    })
end

-- ============================================================================
-- HandleGetPullRecords — 查询全服抽取记录
-- ============================================================================

function M.HandleGetPullRecords(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    local recordsKey = EventConfig.ACTIVE_EVENT.leaderboard.recordsKey

    serverCloud.list:Get(SYSTEM_UID, recordsKey, {
        ok = function(list)
            local records = {}
            for _, item in ipairs(list) do
                records[#records + 1] = item.value
            end
            table.sort(records, function(a, b)
                return (a.ts or 0) > (b.ts or 0)
            end)

            local reply = VariantMap()
            reply["ok"] = Variant(true)
            reply["Records"] = Variant(cjson.encode(records))
            Session.SafeSend(connection, SaveProtocol.S2C_EventPullRecordsData, reply)
        end,
        error = function()
            local reply = VariantMap()
            reply["ok"] = Variant(true)
            reply["Records"] = Variant("[]")
            Session.SafeSend(connection, SaveProtocol.S2C_EventPullRecordsData, reply)
        end,
    })
end

-- ============================================================================
-- 断连清理
-- ============================================================================

function M.OnDisconnect(userId)
    exchangeLocks_[userId] = nil
    fudaiLocks_[userId] = nil
end

return M
