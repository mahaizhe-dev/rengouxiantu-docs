-- ============================================================================
-- DaoTreeHandler.lua — 悟道树系统服务端 Handler
--
-- 职责：HandleDaoTreeStart / HandleDaoTreeComplete / HandleDaoTreeQuery
--       HandleGMResetDaily（同时重置悟道树 + 试炼塔配额）
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B2）
-- ============================================================================

local Session      = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local ConnKey            = Session.ConnKey
local GetUserId          = Session.GetUserId
local SafeSend           = Session.SafeSend
local AcquireSlotLock    = Session.AcquireSlotLock
local ReleaseSlotLock    = Session.ReleaseSlotLock
local IsGMAdmin          = Session.IsGMAdmin
local ServerGetSlotData  = Session.ServerGetSlotData
local connSlots_         = Session.connSlots_
local daoTreeMeditating_ = Session.daoTreeMeditating_

local M = {}

-- ============================================================================
-- 常量
-- ============================================================================

--- 合法的悟道树 ID 列表
local VALID_TREE_IDS = {
    dao_tree_ch1 = true,
    dao_tree_ch2 = true,
    dao_tree_ch3 = true,
    dao_tree_ch4 = true,
    dao_tree_mz  = true,  -- 中洲·瑶池悟道古树
}
M.VALID_TREE_IDS = VALID_TREE_IDS

--- 悟道树经验公式: reward = level³
--- 锚点: Lv.10 = 1,000, Lv.100 = 1,000,000
---@param level number 玩家等级
---@return number 经验奖励（取整）
local function CalcDaoTreeExp(level)
    if level < 10 then level = 10 end
    return math.floor(level ^ 3)
end
M.CalcDaoTreeExp = CalcDaoTreeExp

--- 悟道树悟性上限
local DAO_TREE_WISDOM_CAP = 50
M.DAO_TREE_WISDOM_CAP = DAO_TREE_WISDOM_CAP

-- ============================================================================
-- C2S_DaoTreeStart — 请求开始参悟（先查后加方案）
-- ============================================================================

function M.HandleDaoTreeStart(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local treeId = eventData["treeId"]:GetString()

    print("[Server] DaoTreeStart: userId=" .. tostring(userId) .. " treeId=" .. treeId)

    -- 验证 treeId 合法性
    if not VALID_TREE_IDS[treeId] then
        print("[Server] DaoTreeStart: invalid treeId=" .. treeId)
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["reason"] = Variant("invalid_tree")
        SafeSend(connection, SaveProtocol.S2C_DaoTreeStartResult, data)
        return
    end

    -- 先查后加方案：查询两个 Quota（单树 + 每日总次数）
    local slot = connSlots_[connKey]
    if not slot then
        print("[Server] WARNING: connSlots_ not loaded for connKey=" .. connKey .. ", rejecting")
        return
    end
    local treeQuotaKey = "dao_tree_" .. treeId .. "_s" .. slot
    local dailyQuotaKey = "dao_tree_daily_s" .. slot

    -- 查询单树配额
    serverCloud.quota:Get(userId, treeQuotaKey, {
        ok = function(treeDatas)
            local treeUsed = 0
            if #treeDatas > 0 then
                treeUsed = treeDatas[1].value or 0
            end

            if treeUsed >= 1 then
                print("[Server] DaoTreeStart: tree already used today, treeId=" .. treeId)
                serverCloud.quota:Get(userId, dailyQuotaKey, {
                    ok = function(dailyDatas)
                        local dailyUsed = 0
                        if #dailyDatas > 0 then
                            dailyUsed = dailyDatas[1].value or 0
                        end
                        local data = VariantMap()
                        data["ok"] = Variant(false)
                        data["reason"] = Variant("tree_used")
                        data["dailyUsed"] = Variant(dailyUsed)
                        SafeSend(connection, SaveProtocol.S2C_DaoTreeStartResult, data)
                    end,
                    error = function()
                        local data = VariantMap()
                        data["ok"] = Variant(false)
                        data["reason"] = Variant("tree_used")
                        data["dailyUsed"] = Variant(0)
                        SafeSend(connection, SaveProtocol.S2C_DaoTreeStartResult, data)
                    end,
                })
                return
            end

            -- 查询每日总配额
            serverCloud.quota:Get(userId, dailyQuotaKey, {
                ok = function(dailyDatas)
                    local dailyUsed = 0
                    if #dailyDatas > 0 then
                        dailyUsed = dailyDatas[1].value or 0
                    end

                    if dailyUsed >= 3 then
                        print("[Server] DaoTreeStart: daily limit reached")
                        local data = VariantMap()
                        data["ok"] = Variant(false)
                        data["reason"] = Variant("daily_limit")
                        data["dailyUsed"] = Variant(dailyUsed)
                        SafeSend(connection, SaveProtocol.S2C_DaoTreeStartResult, data)
                        return
                    end

                    -- 两个都通过 → 记录参悟中状态，允许开始读条
                    daoTreeMeditating_[connKey] = {
                        treeId = treeId,
                        startTime = os.time(),
                    }

                    local data = VariantMap()
                    data["ok"] = Variant(true)
                    data["treeId"] = Variant(treeId)
                    data["dailyUsed"] = Variant(dailyUsed)
                    SafeSend(connection, SaveProtocol.S2C_DaoTreeStartResult, data)

                    print("[Server] DaoTreeStart: approved, dailyUsed=" .. dailyUsed)
                end,
                error = function(code, reason)
                    print("[Server] DaoTreeStart: daily quota get failed: " .. tostring(reason))
                    local data = VariantMap()
                    data["ok"] = Variant(false)
                    data["reason"] = Variant("server_error")
                    SafeSend(connection, SaveProtocol.S2C_DaoTreeStartResult, data)
                end,
            })
        end,
        error = function(code, reason)
            print("[Server] DaoTreeStart: tree quota get failed: " .. tostring(reason))
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["reason"] = Variant("server_error")
            SafeSend(connection, SaveProtocol.S2C_DaoTreeStartResult, data)
        end,
    })
end

-- ============================================================================
-- C2S_DaoTreeComplete — 完成10秒读条，发放奖励
-- ============================================================================

function M.HandleDaoTreeComplete(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local treeId = eventData["treeId"]:GetString()
    local slot = connSlots_[connKey]
    if not slot then
        print("[Server] WARNING: connSlots_ not loaded for connKey=" .. connKey .. ", rejecting")
        return
    end

    print("[Server] DaoTreeComplete: userId=" .. tostring(userId) .. " treeId=" .. treeId .. " slot=" .. slot)

    -- 验证参悟中状态
    local meditateState = daoTreeMeditating_[connKey]
    if not meditateState or meditateState.treeId ~= treeId then
        print("[Server] DaoTreeComplete: not meditating or treeId mismatch")
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["reason"] = Variant("not_meditating")
        SafeSend(connection, SaveProtocol.S2C_DaoTreeReward, data)
        return
    end

    -- 清除参悟状态
    daoTreeMeditating_[connKey] = nil

    -- P0-2 修复：加锁防止与 auto-save 并发覆盖
    if not AcquireSlotLock(userId, slot) then
        print("[Server] DaoTreeComplete: slot locked, rejecting")
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["reason"] = Variant("slot_locked")
        SafeSend(connection, SaveProtocol.S2C_DaoTreeReward, data)
        return
    end

    -- 读取存档获取玩家等级和当前悟道树悟性
    ServerGetSlotData(userId, slot, function(saveData)
        if not saveData or not saveData.player then
            ReleaseSlotLock(userId, slot)
            print("[Server] DaoTreeComplete: save data not found")
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["reason"] = Variant("save_not_found")
            SafeSend(connection, SaveProtocol.S2C_DaoTreeReward, data)
            return
        end

            local playerData = saveData.player
            local level = playerData.level or 1
            local currentWisdom = playerData.daoTreeWisdom or 0

            -- 计算经验奖励
            local expReward = CalcDaoTreeExp(level)

            -- 判定悟性（30% 概率，保底：连续3次未获得则第4次必出）
            local gotWisdom = false
            local currentPity = playerData.daoTreeWisdomPity or 0
            if currentWisdom < DAO_TREE_WISDOM_CAP then
                if currentPity >= 3 then
                    gotWisdom = true
                elseif math.random() < 0.30 then
                    gotWisdom = true
                end
            end

            -- 更新保底计数器
            if gotWisdom then
                playerData.daoTreeWisdomPity = 0
            else
                playerData.daoTreeWisdomPity = currentPity + 1
            end

            -- 使用 BatchCommit 原子提交：Quota扣次数 + 经验写入存档 + 悟性写入存档
            local treeQuotaKey = "dao_tree_" .. treeId .. "_s" .. slot
            local dailyQuotaKey = "dao_tree_daily_s" .. slot

            -- 更新存档数据
            playerData.exp = (playerData.exp or 0) + expReward
            if gotWisdom then
                playerData.daoTreeWisdom = currentWisdom + 1
            end
            saveData.timestamp = os.time()

            -- BatchCommit：原子提交配额 + 存档
            local commit = serverCloud:BatchCommit("悟道树参悟奖励")
            commit:QuotaAdd(userId, treeQuotaKey, 1, 1, "day", 1)
            commit:QuotaAdd(userId, dailyQuotaKey, 1, 3, "day", 1)
            commit:ScoreSet(userId, "save_" .. slot, saveData)
            commit:Commit({
                ok = function()
                    ReleaseSlotLock(userId, slot)
                    local newWisdom = playerData.daoTreeWisdom or currentWisdom

                    serverCloud.quota:Get(userId, dailyQuotaKey, {
                        ok = function(dailyDatas)
                            local dailyUsed = 3
                            if #dailyDatas > 0 then
                                dailyUsed = dailyDatas[1].value or 0
                            end

                            local newPity = playerData.daoTreeWisdomPity or 0

                            local data = VariantMap()
                            data["ok"] = Variant(true)
                            data["treeId"] = Variant(treeId)
                            data["exp"] = Variant(expReward)
                            data["gotWisdom"] = Variant(gotWisdom)
                            data["wisdomTotal"] = Variant(newWisdom)
                            data["dailyUsed"] = Variant(dailyUsed)
                            data["pity"] = Variant(newPity)
                            SafeSend(connection, SaveProtocol.S2C_DaoTreeReward, data)

                            print("[Server] DaoTreeReward: userId=" .. tostring(userId)
                                .. " exp=" .. expReward
                                .. " gotWisdom=" .. tostring(gotWisdom)
                                .. " wisdomTotal=" .. newWisdom
                                .. " dailyUsed=" .. dailyUsed
                                .. " pity=" .. newPity)
                        end,
                        error = function()
                            local newPity = playerData.daoTreeWisdomPity or 0
                            local data = VariantMap()
                            data["ok"] = Variant(true)
                            data["treeId"] = Variant(treeId)
                            data["exp"] = Variant(expReward)
                            data["gotWisdom"] = Variant(gotWisdom)
                            data["wisdomTotal"] = Variant(newWisdom)
                            data["dailyUsed"] = Variant(3)
                            data["pity"] = Variant(newPity)
                            SafeSend(connection, SaveProtocol.S2C_DaoTreeReward, data)
                        end,
                    })
                end,
                error = function(code, reason)
                    ReleaseSlotLock(userId, slot)
                    print("[Server] DaoTreeComplete BatchCommit FAILED: "
                        .. tostring(code) .. " " .. tostring(reason))
                    local data = VariantMap()
                    data["ok"] = Variant(false)
                    data["reason"] = Variant("commit_failed")
                    SafeSend(connection, SaveProtocol.S2C_DaoTreeReward, data)
                end,
            })
    end)
end

-- ============================================================================
-- C2S_GMResetDaily — GM: 重置所有日常配额（悟道树 + 试炼塔）
-- ============================================================================

function M.HandleGMResetDaily(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    -- 权限校验：仅管理员可执行
    if not IsGMAdmin(userId) then
        print("[Server][GM] ResetDaily REJECTED: userId=" .. tostring(userId) .. " not admin")
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["msg"] = Variant("权限不足：非管理员")
        SafeSend(connection, SaveProtocol.S2C_GMResetDailyResult, data)
        return
    end

    local slot = connSlots_[connKey]
    if not slot then
        print("[Server] WARNING: connSlots_ not loaded for connKey=" .. connKey .. ", rejecting")
        return
    end
    print("[Server][GM] ResetDaily: userId=" .. tostring(userId) .. " slot=" .. slot)

    -- 重置所有悟道树相关配额
    local keysToReset = { "dao_tree_daily_s" .. slot }
    for treeId, _ in pairs(VALID_TREE_IDS) do
        table.insert(keysToReset, "dao_tree_" .. treeId .. "_s" .. slot)
    end
    -- 同时重置试炼塔每日供奉配额
    table.insert(keysToReset, "trial_daily_offering_s" .. slot)

    local remaining = #keysToReset
    local failed = false

    for _, key in ipairs(keysToReset) do
        serverCloud.quota:Reset(userId, key, {
            ok = function()
                remaining = remaining - 1
                if remaining <= 0 and not failed then
                    print("[Server][GM] ResetDaily: all quotas reset for userId=" .. tostring(userId))
                    local data = VariantMap()
                    data["ok"] = Variant(true)
                    data["msg"] = Variant("日常已重置")
                    SafeSend(connection, SaveProtocol.S2C_GMResetDailyResult, data)
                end
            end,
            error = function(code, reason)
                if not failed then
                    failed = true
                    print("[Server][GM] ResetDaily: failed key=" .. key .. " reason=" .. tostring(reason))
                    local data = VariantMap()
                    data["ok"] = Variant(false)
                    data["msg"] = Variant("重置失败: " .. tostring(reason))
                    SafeSend(connection, SaveProtocol.S2C_GMResetDailyResult, data)
                end
            end,
        })
    end
end

-- ============================================================================
-- C2S_DaoTreeQuery — 查询悟道树每日状态（客户端重连后同步缓存）
-- ============================================================================

function M.HandleDaoTreeQuery(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local slot = connSlots_[connKey]
    if not slot then
        print("[Server] WARNING: connSlots_ not loaded for connKey=" .. connKey .. ", rejecting")
        return
    end
    print("[Server] DaoTreeQuery: userId=" .. tostring(userId) .. " slot=" .. slot)

    local dailyQuotaKey = "dao_tree_daily_s" .. slot

    serverCloud.quota:Get(userId, dailyQuotaKey, {
        ok = function(dailyDatas)
            local dailyUsed = 0
            if #dailyDatas > 0 then
                dailyUsed = dailyDatas[1].value or 0
            end

            local treeIds = {}
            for treeId, _ in pairs(VALID_TREE_IDS) do
                table.insert(treeIds, treeId)
            end

            local usedTreeList = {}
            local remaining = #treeIds

            for _, treeId in ipairs(treeIds) do
                local treeQuotaKey = "dao_tree_" .. treeId .. "_s" .. slot
                serverCloud.quota:Get(userId, treeQuotaKey, {
                    ok = function(treeDatas)
                        local treeUsed = 0
                        if #treeDatas > 0 then
                            treeUsed = treeDatas[1].value or 0
                        end
                        if treeUsed >= 1 then
                            table.insert(usedTreeList, treeId)
                        end
                        remaining = remaining - 1
                        if remaining <= 0 then
                            local data = VariantMap()
                            data["ok"] = Variant(true)
                            data["dailyUsed"] = Variant(dailyUsed)
                            data["usedTrees"] = Variant(cjson.encode(usedTreeList))
                            SafeSend(connection, SaveProtocol.S2C_DaoTreeQueryResult, data)
                            print("[Server] DaoTreeQuery result: dailyUsed=" .. dailyUsed
                                .. " usedTrees=" .. #usedTreeList)
                        end
                    end,
                    error = function()
                        remaining = remaining - 1
                        if remaining <= 0 then
                            local data = VariantMap()
                            data["ok"] = Variant(true)
                            data["dailyUsed"] = Variant(dailyUsed)
                            data["usedTrees"] = Variant(cjson.encode(usedTreeList))
                            SafeSend(connection, SaveProtocol.S2C_DaoTreeQueryResult, data)
                        end
                    end,
                })
            end
        end,
        error = function(code, reason)
            print("[Server] DaoTreeQuery failed: " .. tostring(reason))
            local data = VariantMap()
            data["ok"] = Variant(false)
            SafeSend(connection, SaveProtocol.S2C_DaoTreeQueryResult, data)
        end,
    })
end

return M
