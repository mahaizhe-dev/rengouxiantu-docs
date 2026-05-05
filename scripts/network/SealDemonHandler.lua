-- ============================================================================
-- SealDemonHandler.lua — 封魔任务系统服务端 Handler
--
-- 职责：HandleSealDemonAccept / HandleSealDemonBossKilled / HandleSealDemonAbandon
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B2）
-- ============================================================================

local Session          = require("network.ServerSession")
local SaveProtocol     = require("network.SaveProtocol")
local SealDemonConfig  = require("config.SealDemonConfig")

local ConnKey           = Session.ConnKey
local GetUserId         = Session.GetUserId
local SafeSend          = Session.SafeSend
local AcquireSlotLock   = Session.AcquireSlotLock
local ReleaseSlotLock   = Session.ReleaseSlotLock
local ServerGetSlotData = Session.ServerGetSlotData
local connSlots_        = Session.connSlots_
local sealDemonActive_  = Session.sealDemonActive_

local M = {}

-- ============================================================================
-- 常量
-- ============================================================================

--- 体魄丹上限
local PHYSIQUE_PILL_CAP = SealDemonConfig.PHYSIQUE_PILL.maxCount
M.PHYSIQUE_PILL_CAP = PHYSIQUE_PILL_CAP

-- ============================================================================
-- C2S_SealDemonAccept — 接取封魔任务
-- ============================================================================

function M.HandleSealDemonAccept(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local questId = eventData["questId"]:GetString()
    local dailyChapter = eventData["dailyChapter"]:GetInt()

    local isDaily = (dailyChapter > 0)

    print("[Server] SealDemonAccept: userId=" .. tostring(userId)
        .. " questId=" .. questId .. " dailyChapter=" .. dailyChapter)

    -- 已有进行中的封魔任务
    if sealDemonActive_[connKey] then
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["reason"] = Variant("already_active")
        SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
        return
    end

    -- 读取存档验证
    local slot = connSlots_[connKey]
    if not slot then
        print("[Server] WARNING: connSlots_ not loaded for connKey=" .. connKey .. ", rejecting")
        return
    end
    ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            print("[Server] SealDemonAccept: save data not found")
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["reason"] = Variant("no_save")
            SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
            return
        end

            local playerLevel = (saveData.player and saveData.player.level) or 1
            local sealDemon = saveData.sealDemon or { quests = {} }

            if isDaily then
                -- 日常任务验证
                local daily = SealDemonConfig.DAILY[dailyChapter]
                if not daily then
                    local data = VariantMap()
                    data["ok"] = Variant(false)
                    data["reason"] = Variant("invalid_chapter")
                    SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
                    return
                end

                -- 检查前置：该章4个一次性任务全部完成
                for _, reqId in ipairs(daily.requiredQuests) do
                    if sealDemon.quests[reqId] ~= "completed" then
                        local data = VariantMap()
                        data["ok"] = Variant(false)
                        data["reason"] = Variant("prereq_incomplete")
                        SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
                        return
                    end
                end

                -- Quota 检查：每日1次（三章共享，按角色隔离）
                serverCloud.quota:Add(userId, "seal_demon_daily_s" .. slot, 1, 1, "day", {
                    ok = function()
                        -- 随机选择 BOSS
                        local pool = daily.bossPool
                        local chosen = pool[math.random(1, #pool)]

                        -- 检查低阶警告
                        local highestCh = 0
                        for ch = 1, 4 do
                            local dCfg = SealDemonConfig.DAILY[ch]
                            if dCfg then
                                local allDone = true
                                for _, rid in ipairs(dCfg.requiredQuests) do
                                    if sealDemon.quests[rid] ~= "completed" then
                                        allDone = false
                                        break
                                    end
                                end
                                if allDone then highestCh = ch end
                            end
                        end

                        sealDemonActive_[connKey] = {
                            dailyChapter = dailyChapter,
                            bossTypeId = chosen.sourceBoss,
                        }

                        local data = VariantMap()
                        data["ok"] = Variant(true)
                        data["bossId"] = Variant(chosen.sourceBoss)
                        data["bossLevel"] = Variant(chosen.level)
                        data["bossCategory"] = Variant(chosen.category)
                        data["bossRealm"] = Variant(chosen.realm)
                        data["spawnX"] = Variant(chosen.spawnX)
                        data["spawnY"] = Variant(chosen.spawnY)
                        if dailyChapter < highestCh then
                            data["warning"] = Variant("low_tier")
                        end
                        SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)

                        print("[Server] SealDemonAccept daily OK: ch=" .. dailyChapter
                            .. " boss=" .. chosen.sourceBoss)
                    end,
                    error = function(code, reason)
                        if tostring(reason):find("limit") then
                            local data = VariantMap()
                            data["ok"] = Variant(false)
                            data["reason"] = Variant("daily_limit")
                            SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
                        else
                            print("[Server] SealDemonAccept daily quota error: " .. tostring(reason))
                            local data = VariantMap()
                            data["ok"] = Variant(false)
                            data["reason"] = Variant("server_error")
                            SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
                        end
                    end,
                })
            else
                -- 一次性任务验证
                local questDef = SealDemonConfig.QUEST_BY_ID[questId]
                if not questDef then
                    local data = VariantMap()
                    data["ok"] = Variant(false)
                    data["reason"] = Variant("invalid_quest")
                    SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
                    return
                end

                -- 等级检查
                if playerLevel < questDef.requiredLevel then
                    local data = VariantMap()
                    data["ok"] = Variant(false)
                    data["reason"] = Variant("level_too_low")
                    SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
                    return
                end

                -- 已完成检查
                if sealDemon.quests[questId] == "completed" then
                    local data = VariantMap()
                    data["ok"] = Variant(false)
                    data["reason"] = Variant("already_completed")
                    SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)
                    return
                end

                sealDemonActive_[connKey] = {
                    questId = questId,
                    bossTypeId = questDef.sourceBoss,
                }

                local data = VariantMap()
                data["ok"] = Variant(true)
                data["questId"] = Variant(questId)
                data["bossId"] = Variant(questDef.sourceBoss)
                data["spawnX"] = Variant(questDef.spawnX)
                data["spawnY"] = Variant(questDef.spawnY)
                SafeSend(connection, SaveProtocol.S2C_SealDemonAcceptResult, data)

                print("[Server] SealDemonAccept quest OK: " .. questId)
            end
    end)
end

-- ============================================================================
-- C2S_SealDemonBossKilled — 封魔BOSS击杀上报
-- ============================================================================

function M.HandleSealDemonBossKilled(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    print("[Server] SealDemonBossKilled: userId=" .. tostring(userId))

    local activeState = sealDemonActive_[connKey]
    if not activeState then
        print("[Server] SealDemonBossKilled: no active seal demon task")
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["reason"] = Variant("no_active_task")
        SafeSend(connection, SaveProtocol.S2C_SealDemonReward, data)
        return
    end

    local slot = connSlots_[connKey]
    if not slot then
        print("[Server] WARNING: connSlots_ not loaded for connKey=" .. connKey .. ", rejecting")
        return
    end
    local saveKey = "save_" .. slot

    -- P0-2 修复：加锁防止与 auto-save 并发覆盖
    if not AcquireSlotLock(userId, slot) then
        print("[Server] SealDemonBossKilled: slot locked, rejecting")
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["reason"] = Variant("slot_locked")
        SafeSend(connection, SaveProtocol.S2C_SealDemonReward, data)
        return
    end

    ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            ReleaseSlotLock(userId, slot)
            print("[Server] SealDemonBossKilled: save data not found")
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["reason"] = Variant("no_save")
            SafeSend(connection, SaveProtocol.S2C_SealDemonReward, data)
            return
        end

            -- 确保 sealDemon 结构存在
            if not saveData.sealDemon then
                saveData.sealDemon = { quests = {} }
            end
            if not saveData.player then
                saveData.player = {}
            end

            local rewardData = VariantMap()
            rewardData["ok"] = Variant(true)

            if activeState.questId then
                -- 一次性任务完成
                local questDef = SealDemonConfig.QUEST_BY_ID[activeState.questId]
                saveData.sealDemon.quests[activeState.questId] = "completed"

                if questDef and questDef.reward then
                    rewardData["lingYun"] = Variant(questDef.reward.lingYun or 0)
                    rewardData["petFood"] = Variant(questDef.reward.petFood or "")
                    rewardData["petFoodCount"] = Variant(questDef.reward.petFoodCount or 1)
                end
                rewardData["questId"] = Variant(activeState.questId)
                rewardData["type"] = Variant("quest")

                print("[Server] SealDemonReward quest: " .. activeState.questId)

            elseif activeState.dailyChapter then
                -- 日常任务完成
                local daily = SealDemonConfig.DAILY[activeState.dailyChapter]

                if daily and daily.reward then
                    rewardData["lingYun"] = Variant(daily.reward.lingYun or 0)
                    rewardData["petFood"] = Variant(daily.reward.petFood or "")
                    rewardData["petFoodCount"] = Variant(daily.reward.petFoodCount or 1)

                    -- 体魄丹
                    if daily.reward.physiquePill and daily.reward.physiquePill > 0 then
                        local current = saveData.player.pillPhysique or 0
                        if current < PHYSIQUE_PILL_CAP then
                            saveData.player.pillPhysique = math.min(
                                current + daily.reward.physiquePill,
                                PHYSIQUE_PILL_CAP
                            )
                            rewardData["physiquePill"] = Variant(daily.reward.physiquePill)
                            rewardData["pillTotal"] = Variant(saveData.player.pillPhysique)
                        else
                            rewardData["physiquePill"] = Variant(0)
                            rewardData["pillTotal"] = Variant(PHYSIQUE_PILL_CAP)
                        end
                    end
                end
                rewardData["type"] = Variant("daily")
                rewardData["dailyChapter"] = Variant(activeState.dailyChapter)

                print("[Server] SealDemonReward daily: ch=" .. activeState.dailyChapter)
            end

            -- 保存存档
            local commit = serverCloud:BatchCommit("封魔奖励")
            commit:ScoreSet(userId, saveKey, saveData)
            commit:Commit({
                ok = function()
                    sealDemonActive_[connKey] = nil
                    ReleaseSlotLock(userId, slot)
                    SafeSend(connection, SaveProtocol.S2C_SealDemonReward, rewardData)
                    print("[Server] SealDemonReward saved OK")
                end,
                error = function(code, reason)
                    ReleaseSlotLock(userId, slot)
                    print("[Server] SealDemonReward save FAILED: " .. tostring(reason))
                    rewardData["ok"] = Variant(false)
                    rewardData["reason"] = Variant("save_failed")
                    SafeSend(connection, SaveProtocol.S2C_SealDemonReward, rewardData)
                end,
            })
    end)
end

-- ============================================================================
-- C2S_SealDemonAbandon — 放弃封魔任务
-- ============================================================================

function M.HandleSealDemonAbandon(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    print("[Server] SealDemonAbandon: userId=" .. tostring(userId))

    local activeState = sealDemonActive_[connKey]
    if not activeState then
        local data = VariantMap()
        data["ok"] = Variant(true)  -- 幂等：无活跃任务也算成功
        SafeSend(connection, SaveProtocol.S2C_SealDemonAbandonResult, data)
        return
    end

    sealDemonActive_[connKey] = nil

    local data = VariantMap()
    data["ok"] = Variant(true)
    SafeSend(connection, SaveProtocol.S2C_SealDemonAbandonResult, data)

    print("[Server] SealDemonAbandon OK")
end

return M
