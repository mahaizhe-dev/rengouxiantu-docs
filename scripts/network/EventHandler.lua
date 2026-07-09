-- ============================================================================
-- EventHandler.lua — 端午活动服务端 Handler
--
-- 职责：处理 4 个 C2S 协议
--   1. HandleExchange   — 活动兑换（端午不启用）
--   2. HandleOpenFudai  — 开启宝箱（小宝箱/大宝箱, ×1 / ×5）
--   3. HandleGetRankList — 查询积分排行榜
--   4. HandleGetPullRecords — 查询全服稀有抽取记录
--
-- 模式：完全复刻 BlackMerchantHandler 的模块结构
-- 设计文档：docs/端午世界掉落活动（代码执行文档）.md v1.2
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local EventConfig = require("config.EventConfig")
local GameConfig = require("config.GameConfig")
local EventSystem = require("systems.EventSystem")
local BackpackUtils = require("network.BackpackUtils")
local MilestoneLogic = require("systems.MilestoneLogic")

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

local function WritePullRecords(charName, rollResults, recordsKey, boxType, recordKeyPrefix)
    local masked = MaskPlayerName(charName)
    local seq = 0
    for _, r in ipairs(rollResults) do
        if r.rarity == "rare" or r.rarity == "legendary" then
            seq = seq + 1
            serverCloud.list:Add(SYSTEM_UID, recordsKey, {
                recordKey = recordKeyPrefix and (recordKeyPrefix .. seq) or nil,
                displayName = masked,
                name = r.name,
                rarity = r.rarity,
                boxType = boxType or r.boxType,
                ts = r.ts or os.time(),
            })
        end
    end
    TrimPullRecords(recordsKey)
end

-- ============================================================================
-- HandleExchange — 活动兑换（端午不启用，保留接口兼容）
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
            -- DL-4 fix: 空档防御，防止骨架数据覆盖真实存档
            if not saveData.player then
                Session.ReleaseSlotLock(userId, currentSlot)
                exchangeLocks_[userId] = nil
                SendError(connection, SaveProtocol.S2C_EventExchangeResult, "存档未就绪")
                return
            end
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
-- 设计文档：docs/端午世界掉落活动（代码执行文档）.md §4.4
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
            -- DL-4 fix: 空档防御
            if not saveData.player then
                releaseLocks()
                SendError(connection, SaveProtocol.S2C_EventOpenFudaiResult, "存档未就绪")
                return
            end
            local backpack = saveData.backpack or {}

            -- 服务端校验背包物品数量（BM-S4A: 只统计未锁定堆叠，防止锁定物品通过校验后扣除失败）
            local targetItemId = boxCfg.itemId
            local heldCount = BackpackUtils.CountUnlockedItem(backpack, targetItemId)

            if heldCount <= 0 then
                releaseLocks()
                local itemDefs = GameConfig.EVENT_ITEMS or {}
                local itemDef = itemDefs[targetItemId]
                local itemName = itemDef and itemDef.name or targetItemId
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

            -- ════ 保底计数器读取 ════
            local eventId = event.eventId
            local evtAllData = saveData.event_data or {}
            local evtData = evtAllData[eventId] or {}
            local pityCounters = evtData.pity or {}
            local pityCount = pityCounters[boxType] or 0

            -- 保底配置
            local pityCfg = event.pity and event.pity[boxType]
            local pityThreshold = pityCfg and pityCfg.threshold or 0
            local pityTargetId = pityCfg and pityCfg.targetId

            -- 从奖池查找保底目标条目（用于强制替换）
            local pityEntry = nil
            if pityTargetId then
                for _, item in ipairs(pool) do
                    if item.id == pityTargetId then
                        pityEntry = item
                        break
                    end
                end
            end

            -- 服务端执行 N 次独立抽取
            local rollResults = {}
            local totalRewards = { exp = 0, gold = 0, lingYun = 0, consumables = {} }
            local skinRewards = {}  -- 记录抽到的皮肤奖励

            for i = 1, actualCount do
                local entry = EventSystem.RollFudaiReward(pool)

                -- 保底逻辑
                if pityEntry and pityThreshold > 0 then
                    pityCount = pityCount + 1
                    if entry.id == pityTargetId then
                        -- 自然命中保底目标，重置计数器
                        pityCount = 0
                    elseif pityCount >= pityThreshold then
                        -- 达到保底阈值，强制替换为保底物品
                        entry = pityEntry
                        pityCount = 0
                        print("[EventHandler] PITY triggered: box=" .. boxType
                            .. " threshold=" .. pityThreshold .. " user=" .. tostring(userId))
                    end
                end

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
                            name = entry.name,
                            rollEntryId = entry.id,  -- 外层条目ID，用于去重
                            dupLingYun = r.dupLingYun or 5000,
                        }
                    end
                end
            end

            -- ════ 保底计数器写回 event_data ════
            pityCounters[boxType] = pityCount
            evtData.pity = pityCounters
            evtAllData[eventId] = evtData
            saveData.event_data = evtAllData

            -- ════ 组装 NewPullRecords（rare/legendary 立即回传客户端）════
            -- 生成稳定 recordKey 前缀，避免同秒多抽记录重复
            local recordTs = os.time()
            local recordKeyPrefix = userId .. "_" .. recordTs .. "_"
            local recordSeq = 0
            local newPullRecords = {}
            for _, r in ipairs(rollResults) do
                if r.rarity == "rare" or r.rarity == "legendary" then
                    recordSeq = recordSeq + 1
                    newPullRecords[#newPullRecords + 1] = {
                        recordKey = recordKeyPrefix .. recordSeq,
                        name = r.name,
                        rarity = r.rarity,
                        boxType = boxType,
                        ts = recordTs,
                    }
                end
            end

            -- ════ 组装 SpecialRewards（大奖弹窗：jackpotIds 配置 或 传说物品）════
            local jackpotIds = event.jackpotIds or {}
            local baseSpecialRewards = {}
            for _, r in ipairs(rollResults) do
                local isJackpot = (r.id ~= nil) and (jackpotIds[r.id] or r.rarity == "legendary")
                if isJackpot then
                    -- 检查是否属于皮肤奖励（用 rollEntryId 匹配外层条目ID）
                    local isSkinReward = false
                    for _, skin in ipairs(skinRewards) do
                        if skin.rollEntryId == r.id then isSkinReward = true; break end
                    end
                    if not isSkinReward then
                        baseSpecialRewards[#baseSpecialRewards + 1] = {
                            kind = "legendary_item",
                            rewardId = r.id,
                            name = r.name,
                        }
                    end
                end
            end

            -- ================================================================
            -- 皮肤奖励处理：需要先读 account_cosmetics 判断是否已拥有
            -- ================================================================
            local function ProcessAfterSkinCheck(unlockedSkinId, dupLingYunTotal, specialRewards)
                -- 扣宝箱道具（BM-S4A: 必须检查返回值，防止锁定物品导致扣除不足仍发奖）
                local removeRemaining = RemoveFromBackpack(backpack, targetItemId, actualCount)
                if removeRemaining > 0 then
                    -- 扣除失败（锁定物品导致实际可扣数量不足）→ 拒绝本次开启
                    releaseLocks()
                    SendError(connection, SaveProtocol.S2C_EventOpenFudaiResult,
                        "道具被锁定中，无法开启")
                    print("[EventHandler] OpenBox BLOCKED: item locked, remaining=" .. removeRemaining
                        .. " user=" .. tostring(userId))
                    return
                end

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
                                    WritePullRecords(charName, rollResults, recordsKey, boxType, recordKeyPrefix)
                                end,
                                error = function()
                                    WriteRankInfo(userId, infoKey, fallbackName, classId)
                                    WritePullRecords(fallbackName, rollResults, recordsKey, boxType, recordKeyPrefix)
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
                        -- 保底进度（当前计数/阈值）
                        reply["PityCount"] = Variant(pityCount)
                        reply["PityThreshold"] = Variant(pityThreshold)
                        -- 大奖弹窗列表 + 全服记录即时回传
                        reply["SpecialRewards"] = Variant(cjson.encode(specialRewards))
                        -- NewPullRecords: 补充 displayName
                        local masked = MaskPlayerName(fallbackName)
                        for _, rec in ipairs(newPullRecords) do
                            rec.displayName = masked
                        end
                        reply["NewPullRecords"] = Variant(cjson.encode(newPullRecords))
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
                            local skinSpecials = {}

                            for _, skin in ipairs(skinRewards) do
                                if petApps[skin.id] and petApps[skin.id].unlocked then
                                    -- 已拥有 → 补偿灵韵
                                    dupLingYunTotal = dupLingYunTotal + skin.dupLingYun
                                    skinSpecials[#skinSpecials + 1] = {
                                        kind = "skin_dup",
                                        skinId = skin.id,
                                        skinName = skin.name or skin.id,
                                        lingYun = skin.dupLingYun,
                                    }
                                else
                                    -- 未拥有 → 解锁（多次抽到同一皮肤，第一次解锁，后续补偿）
                                    if not unlockedSkinId then
                                        unlockedSkinId = skin.id
                                        skinSpecials[#skinSpecials + 1] = {
                                            kind = "skin_new",
                                            skinId = skin.id,
                                            skinName = skin.name or skin.id,
                                        }
                                    else
                                        -- 同一轮抽到多次相同皮肤，第二次起按重复补偿
                                        dupLingYunTotal = dupLingYunTotal + skin.dupLingYun
                                        skinSpecials[#skinSpecials + 1] = {
                                            kind = "skin_dup",
                                            skinId = skin.id,
                                            skinName = skin.name or skin.id,
                                            lingYun = skin.dupLingYun,
                                        }
                                    end
                                end
                            end

                            -- 合并: 皮肤弹窗优先 + 非皮肤传说物品
                            local combined = {}
                            for _, s in ipairs(skinSpecials) do combined[#combined + 1] = s end
                            for _, b in ipairs(baseSpecialRewards) do combined[#combined + 1] = b end
                            ProcessAfterSkinCheck(unlockedSkinId, dupLingYunTotal, combined)
                        end,
                        error = function()
                            -- 读取失败 → 重试（最多2次），仍失败则兜底：
                            -- 按新皮肤解锁处理（幂等写入无害），不发 dupLingYun（防止多发）
                            print("[EventHandler] WARN: account_cosmetics read failed, retrying...")
                            serverCloud:BatchGet(userId)
                                :Key("account_cosmetics")
                                :Fetch({
                                    ok = function(cosResult)
                                        -- 重试成功，正常判断逻辑
                                        local cosmetics = cosResult["account_cosmetics"] or {}
                                        local petApps = cosmetics.petAppearances or {}
                                        local unlockedSkinId = nil
                                        local dupLingYunTotal = 0
                                        local skinSpecials = {}
                                        for _, skin in ipairs(skinRewards) do
                                            if petApps[skin.id] and petApps[skin.id].unlocked then
                                                dupLingYunTotal = dupLingYunTotal + skin.dupLingYun
                                                skinSpecials[#skinSpecials + 1] = {
                                                    kind = "skin_dup",
                                                    skinId = skin.id,
                                                    skinName = skin.name or skin.id,
                                                    lingYun = skin.dupLingYun,
                                                }
                                            else
                                                if not unlockedSkinId then
                                                    unlockedSkinId = skin.id
                                                    skinSpecials[#skinSpecials + 1] = {
                                                        kind = "skin_new",
                                                        skinId = skin.id,
                                                        skinName = skin.name or skin.id,
                                                    }
                                                else
                                                    dupLingYunTotal = dupLingYunTotal + skin.dupLingYun
                                                    skinSpecials[#skinSpecials + 1] = {
                                                        kind = "skin_dup",
                                                        skinId = skin.id,
                                                        skinName = skin.name or skin.id,
                                                        lingYun = skin.dupLingYun,
                                                    }
                                                end
                                            end
                                        end
                                        local combined = {}
                                        for _, s in ipairs(skinSpecials) do combined[#combined + 1] = s end
                                        for _, b in ipairs(baseSpecialRewards) do combined[#combined + 1] = b end
                                        ProcessAfterSkinCheck(unlockedSkinId, dupLingYunTotal, combined)
                                    end,
                                    error = function()
                                        -- 两次都失败 → 兜底：按新皮肤解锁（幂等），不发 dupLingYun（不多发）
                                        print("[EventHandler] ERR: account_cosmetics retry failed, fallback to unlock-only")
                                        local unlockedSkinId = skinRewards[1].id
                                        local skinSpecials = {
                                            {
                                                kind = "skin_new",
                                                skinId = skinRewards[1].id,
                                                skinName = skinRewards[1].name or skinRewards[1].id,
                                            }
                                        }
                                        -- 同轮多次皮肤：第一个解锁，后续不发补偿也不解锁（防多发）
                                        local combined = {}
                                        for _, s in ipairs(skinSpecials) do combined[#combined + 1] = s end
                                        for _, b in ipairs(baseSpecialRewards) do combined[#combined + 1] = b end
                                        ProcessAfterSkinCheck(unlockedSkinId, 0, combined)
                                    end,
                                })
                        end,
                    })
            else
                -- 无皮肤奖励，直接走正常流程（仅传非皮肤传说物品）
                ProcessAfterSkinCheck(nil, 0, baseSpecialRewards)
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
-- 里程碑独立权威存储（独立 key，不再嵌套在 save_{slot}.event_data 下，
-- 因此普通存档整包写入无法覆盖/重置里程碑状态）
-- key 结构：evt_ms_<eventId>_<slot>，值 = { baseline, claimed }
-- ============================================================================

local function MilestoneKey(eventId, slot)
    return "evt_ms_" .. eventId .. "_" .. slot
end

-- ============================================================================
-- EnsureMilestoneStateOnLoad — 角色登录加载时一次性初始化里程碑基线
-- 由 SaveLoadService.Execute 在读到 saveData 后调用。
-- 禁止在查询/领取时初始化基线（避免"先打怪后开面板"被清零）。
-- 幂等：独立 key 已存在则不覆盖；不存在则迁移旧 event_data 或以登录 bossKills 建基线。
-- ============================================================================
---@param userId integer
---@param slot integer|string
---@param saveData table  已加载存档（读取 bossKills 与迁移旧 bossMilestones）
function M.EnsureMilestoneStateOnLoad(userId, slot, saveData)
    if not EventConfig.IsActive() then return end
    if not userId or not slot then return end
    local eventId = EventConfig.GetEventId()
    if not eventId then return end
    local msKey = MilestoneKey(eventId, slot)

    serverCloud:Get(userId, msKey, {
        ok = function(scores)
            local existing = scores[msKey]
            if existing and type(existing) == "table" and existing.baseline ~= nil then
                return  -- 已初始化/已迁移，幂等返回
            end

            -- 迁移旧 save_{slot}.event_data[eventId].bossMilestones，或以登录时 bossKills 建基线
            local legacy = saveData and saveData.event_data
                and saveData.event_data[eventId]
                and saveData.event_data[eventId].bossMilestones
            local state = MilestoneLogic.BuildInitialState(legacy, saveData and saveData.bossKills)

            local commit = serverCloud:BatchCommit("event_milestone_init")
            commit:ScoreSet(userId, msKey, { baseline = state.baseline, claimed = state.claimed })
            commit:Commit({})

            print("[EventHandler] Milestone " .. (state.migrated and "MIGRATED" or "INIT")
                .. " baseline=" .. state.baseline
                .. " claimedN=" .. MilestoneLogic.CountClaimed(state.claimed)
                .. " user=" .. tostring(userId) .. " slot=" .. tostring(slot))
        end,
        error = function(code, reason)
            print("[EventHandler] Milestone init GET ERROR: code=" .. tostring(code)
                .. " reason=" .. tostring(reason) .. " user=" .. tostring(userId))
        end,
    })
end

-- ============================================================================
-- HandleQueryBossMilestones — 查询 BOSS 里程碑状态
-- 设计文档：docs/端午世界掉落活动（代码执行文档）.md §7
-- ============================================================================

function M.HandleQueryBossMilestones(eventType, eventData)
    if not EventConfig.IsActive() then return end

    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    local currentSlot = Session.connSlots_[connKey]
    if not currentSlot then return end

    -- 客户端附带的实时 bossKills（活动击杀以客户端实时值为准，消除存档写入竞态）
    local clientBossKills = 0
    pcall(function() clientBossKills = eventData[SaveProtocol.MS_F_ClientBossKills]:GetInt() end)

    local eventId = EventConfig.GetEventId()
    local saveKey = "save_" .. currentSlot
    local msKey = MilestoneKey(eventId, currentSlot)

    -- 同时读取主存档（取 savedBossKills）与独立里程碑 key（取 baseline/claimed）
    serverCloud:BatchGet(userId)
        :Key(saveKey)
        :Key(msKey)
        :Fetch({
            ok = function(scores)
                local saveData = scores[saveKey] or {}
                local msData = scores[msKey]
                local currentKills = MilestoneLogic.ResolveCurrentKills(saveData.bossKills, clientBossKills)

                local baseline, claimed
                if msData and type(msData) == "table" and msData.baseline ~= nil then
                    baseline = msData.baseline
                    claimed = msData.claimed or {}
                else
                    -- 防御：登录初始化尚未就绪（正常流程不应发生）。临时以当前值为基准，不持久化基线。
                    baseline = currentKills
                    claimed = {}
                    print("[EventHandler] WARNING: milestone state missing at query, user=" .. tostring(userId)
                        .. " slot=" .. tostring(currentSlot))
                end

                local eventKills = MilestoneLogic.ComputeEventKills(currentKills, baseline)

                local reply = VariantMap()
                reply["ok"] = Variant(true)
                reply[SaveProtocol.MS_F_EventId] = Variant(eventId)
                reply[SaveProtocol.MS_F_BossKills] = Variant(eventKills)
                reply[SaveProtocol.MS_F_Claimed] = Variant(cjson.encode(claimed))
                Session.SafeSend(connection, SaveProtocol.S2C_EventBossMilestonesData, reply)
            end,
            error = function()
                SendError(connection, SaveProtocol.S2C_EventBossMilestonesData, "查询失败")
            end,
        })
end

-- ============================================================================
-- HandleClaimBossMilestone — 领取 BOSS 里程碑奖励
-- 设计文档：docs/端午世界掉落活动（代码执行文档）.md §7.3
-- ============================================================================

local milestoneLocks_ = {}  -- key = userId

function M.HandleClaimBossMilestone(eventType, eventData)
    -- 1. 校验活动开启
    if not EventConfig.IsActive() then return end

    -- 2. 校验连接、用户
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    -- 客户端附带的实时 bossKills（活动击杀以客户端实时值为准，消除存档写入竞态）
    local clientBossKills = 0
    pcall(function() clientBossKills = eventData[SaveProtocol.MS_F_ClientBossKills]:GetInt() end)

    -- 内存锁
    if milestoneLocks_[userId] then return end
    milestoneLocks_[userId] = true

    local milestoneTarget = eventData[SaveProtocol.MS_F_Milestone]:GetInt()

    -- 校验目标档位是否存在于配置
    local event = EventConfig.ACTIVE_EVENT
    local milestones = event.bossMilestones
    local targetCfg = nil
    for _, m in ipairs(milestones) do
        if m.target == milestoneTarget then
            targetCfg = m
            break
        end
    end

    if not targetCfg then
        milestoneLocks_[userId] = nil
        SendError(connection, SaveProtocol.S2C_EventBossMilestoneResult, "无效的里程碑档位")
        return
    end

    -- 3. 槽位锁
    local currentSlot = Session.connSlots_[connKey]
    if not Session.AcquireSlotLock(userId, currentSlot) then
        milestoneLocks_[userId] = nil
        SendError(connection, SaveProtocol.S2C_EventBossMilestoneResult, "操作中，请稍后")
        return
    end

    local function releaseLocks()
        milestoneLocks_[userId] = nil
        Session.ReleaseSlotLock(userId, currentSlot)
    end

    -- 4. 读取存档（主存档取 backpack/bossKills）+ 独立里程碑 key（取 baseline/claimed）
    local eventId = EventConfig.GetEventId()
    local saveKey = "save_" .. currentSlot
    local msKey = MilestoneKey(eventId, currentSlot)

    serverCloud:BatchGet(userId)
        :Key(saveKey)
        :Key(msKey)
        :Fetch({
        ok = function(scores)
            local saveData = scores[saveKey] or {}
            -- DL-4 fix: 空档防御
            if not saveData.player then
                milestoneLocks_[userId] = nil
                Session.ReleaseSlotLock(userId, currentSlot)
                SendError(connection, SaveProtocol.S2C_EventBossMilestoneResult, "存档未就绪")
                return
            end
            local backpack = saveData.backpack or {}
            local msData = scores[msKey]

            -- 5. 计算活动击杀数（当前击杀取存档值与客户端实时值的较大值）
            local currentKills = MilestoneLogic.ResolveCurrentKills(saveData.bossKills, clientBossKills)

            -- 6. 读取里程碑权威状态（独立 key）
            local baseline, claimed
            if msData and type(msData) == "table" and msData.baseline ~= nil then
                baseline = msData.baseline
                claimed = msData.claimed or {}
            else
                -- 防御：登录初始化尚未就绪（正常流程不应发生）。不在此处建基线，直接拒绝领取。
                releaseLocks()
                SendError(connection, SaveProtocol.S2C_EventBossMilestoneResult, "里程碑数据未就绪，请重新进入活动面板")
                print("[EventHandler] WARNING: milestone state missing at claim, user=" .. tostring(userId)
                    .. " slot=" .. tostring(currentSlot))
                return
            end
            local eventKills = MilestoneLogic.ComputeEventKills(currentKills, baseline)

            -- 7. 达标 + 未领取校验（纯逻辑）
            local claimKey = tostring(milestoneTarget)
            local canClaim, reason = MilestoneLogic.CheckClaim(eventKills, milestoneTarget, claimed)
            if not canClaim then
                releaseLocks()
                SendError(connection, SaveProtocol.S2C_EventBossMilestoneResult, reason)
                return
            end

            -- 8. 发放奖励（先检查背包空间，避免标记已领但奖品丢失）
            local allPlaced = true
            for _, r in ipairs(targetCfg.reward) do
                if r.type == "consumable" then
                    local remaining = AddToBackpack(backpack, r.id, r.count)
                    if remaining > 0 then
                        allPlaced = false
                    end
                elseif r.type == "lingYun" then
                    saveData.player = saveData.player or {}
                    saveData.player.lingYun = (saveData.player.lingYun or 0) + r.count
                end
            end

            if not allPlaced then
                releaseLocks()
                SendError(connection, SaveProtocol.S2C_EventBossMilestoneResult, "背包已满，请清理后再领取")
                return
            end

            -- 9. 标记已领取（写入独立 key）
            claimed[claimKey] = true

            -- 10. 原子持久化：主存档（背包/灵韵奖励）+ 独立里程碑 key（已领取状态）
            saveData.timestamp = os.time()
            local commit = serverCloud:BatchCommit("event_boss_milestone")
            commit:ScoreSet(userId, saveKey, saveData)
            commit:ScoreSet(userId, msKey, { baseline = baseline, claimed = claimed })
            commit:Commit({
                ok = function()
                    local reply = VariantMap()
                    reply["ok"] = Variant(true)
                    reply[SaveProtocol.MS_F_EventId] = Variant(eventId)
                    reply[SaveProtocol.MS_F_Milestone] = Variant(milestoneTarget)
                    reply[SaveProtocol.MS_F_BossKills] = Variant(eventKills)
                    reply[SaveProtocol.MS_F_Claimed] = Variant(true)
                    reply[SaveProtocol.MS_F_Rewards] = Variant(cjson.encode(targetCfg.reward))
                    Session.SafeSend(connection, SaveProtocol.S2C_EventBossMilestoneResult, reply)
                    releaseLocks()
                    print("[EventHandler] BossMilestone claimed: target=" .. milestoneTarget
                        .. " eventKills=" .. eventKills .. " user=" .. tostring(userId))
                end,
                error = function(code, reason)
                    releaseLocks()
                    SendError(connection, SaveProtocol.S2C_EventBossMilestoneResult, "领取失败，请重试")
                    print("[EventHandler] BossMilestone FAILED: " .. tostring(code)
                        .. " " .. tostring(reason))
                end,
            })
        end,
        error = function()
            releaseLocks()
            SendError(connection, SaveProtocol.S2C_EventBossMilestoneResult, "服务器忙，请稍后")
        end,
    })
end

-- ============================================================================
-- 断连清理
-- ============================================================================

function M.OnDisconnect(userId)
    exchangeLocks_[userId] = nil
    fudaiLocks_[userId] = nil
    milestoneLocks_[userId] = nil
end

return M
