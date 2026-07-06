-- ============================================================================
-- WubaoTreasureHandler.lua - 乌家宝藏服务端事务
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local SaveBackupService = require("network.SaveBackupService")
local Config = require("config.WubaoTreasureConfig")
local BackpackUtils = require("network.BackpackUtils")
local RewardUtil = require("systems.TriggeredBattleReward")
local LootSystem = require("systems.LootSystem")
local GameConfig = require("config.GameConfig")
local TradeLock = require("systems.BlackMarketTradeLock")
local Logger = require("utils.Logger")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson
if not cjson then
    local ok, lib = pcall(require, "cjson") ---@diagnostic disable-line: unresolved-require
    if ok then cjson = lib end
end

local M = {}

local openingChest_ = {}
local chestActive_ = {}

local function cloneValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[cloneValue(k, seen)] = cloneValue(v, seen)
    end
    return copy
end

local function extractContext(eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Session.ConnKey(connection)
    local userId = Session.GetUserId(connKey)
    local slot = Session.connSlots_[connKey]
    if not userId or not slot then
        return nil, nil, nil, connection
    end
    return connKey, userId, slot, connection
end

local function readString(eventData, key, default)
    local ok, value = pcall(function()
        local v = eventData[key]
        return v and v:GetString() or nil
    end)
    if ok and value ~= nil then return value end
    return default or ""
end

local function send(connection, eventName, fields)
    local data = VariantMap()
    for k, v in pairs(fields or {}) do
        data[k] = Variant(v)
    end
    Session.SafeSend(connection, eventName, data)
end

local function sendError(connection, eventName, chestId, message)
    send(connection, eventName, {
        ok = false,
        chestId = chestId or "",
        reason = message or "操作失败",
        message = message or "操作失败",
    })
end

local function sendGMResult(connection, cmd, ok, message, extras)
    local data = VariantMap()
    data["ok"] = Variant(ok == true)
    data["cmd"] = Variant(cmd or "")
    data["msg"] = Variant(message or "")
    for k, v in pairs(extras or {}) do
        data[k] = Variant(v)
    end
    Session.SafeSend(connection, SaveProtocol.S2C_GMCommandResult, data)
end

local function writeSaveBack(userId, slot, saveData, desc, onOk, onError)
    saveData.timestamp = os.time()
    SaveBackupService.BeforeOverwrite(userId, slot, desc, function()
        serverCloud:BatchSet(userId)
            :Set("save_" .. tostring(slot), saveData)
            :Save(desc, {
                ok = function()
                    if onOk then onOk() end
                end,
                error = function(code, reason)
                    Logger.warn("WubaoTreasure", "save failed desc=" .. tostring(desc)
                        .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
                    if onError then onError(reason or code) end
                end,
            })
    end, function(code, reason)
        Logger.warn("WubaoTreasure", "backup failed desc=" .. tostring(desc)
            .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
        if onError then onError(reason or code) end
    end)
end

local function ensureState(saveData)
    local rawState = type(saveData.wubaoTreasureState) == "table"
        and saveData.wubaoTreasureState or {}
    local state = {
        rewardOrder = type(rawState.rewardOrder) == "table" and rawState.rewardOrder or {},
        opened = type(rawState.opened) == "table" and rawState.opened or {},
    }
    local opened = {}
    for chestId, value in pairs(state.opened) do
        if value then opened[chestId] = true end
    end
    state.opened = opened
    return state
end

local function cloneSaveWithState(saveData, state)
    local cloned = cloneValue(saveData or {})
    cloned.wubaoTreasureState = cloneValue(state)
    return cloned
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

local function ensureRewardOrder(state)
    local rewardSet = Config.GetRewardIdSet()
    local used = {}
    local missingChestIds = {}
    local repairedOrder = {}

    for _, chestId in ipairs(Config.CHEST_ORDER) do
        local rewardId = state.rewardOrder[chestId]
        if rewardSet[rewardId] and not used[rewardId] then
            repairedOrder[chestId] = rewardId
            used[rewardId] = true
        else
            missingChestIds[#missingChestIds + 1] = chestId
        end
    end

    if #missingChestIds == 0 then
        state.rewardOrder = repairedOrder
        return false
    end

    local unusedRewards = {}
    for _, rewardId in ipairs(Config.REWARD_IDS) do
        if not used[rewardId] then
            unusedRewards[#unusedRewards + 1] = rewardId
        end
    end
    shuffle(unusedRewards)
    for i, chestId in ipairs(missingChestIds) do
        repairedOrder[chestId] = unusedRewards[i]
    end

    state.rewardOrder = repairedOrder
    return true
end

local function appendChanges(dst, src)
    for _, change in ipairs(src or {}) do
        dst[#dst + 1] = change
    end
end

local function findEmptySlot(backpack)
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not backpack[tostring(i)] and not backpack[i] then
            return i
        end
    end
    return nil
end

local function addEquipmentWithPatch(backpack, equipId, patch)
    local slot = findEmptySlot(backpack)
    if not slot then return false, "背包已满，请清理后再开启" end
    local item = LootSystem.CreateSpecialEquipment(equipId)
    if not item then return false, "奖励装备配置异常" end
    backpack[tostring(slot)] = item
    patch[#patch + 1] = { slot = slot, item = item }
    return true, nil, item
end

local function applyReward(backpack, reward, rewardId, patch)
    if reward.type == "consumable" then
        local canAdd, reason = RewardUtil.CanAddConsumable(
            backpack,
            reward.consumableId,
            reward.count or 1
        )
        if not canAdd then
            local msg = reason == "backpack_full" and "背包已满，请清理后再开启" or "奖励道具配置异常"
            return false, msg
        end
        local ok, _, changes, addReason = RewardUtil.AddConsumableToBackpack(
            backpack,
            reward.consumableId,
            reward.count or 1,
            "wubao_treasure_" .. tostring(rewardId)
        )
        if not ok then
            local msg = addReason == "backpack_full" and "背包已满，请清理后再开启" or "奖励写入失败"
            return false, msg
        end
        appendChanges(patch, changes)
        return true
    elseif reward.type == "equipment" then
        return addEquipmentWithPatch(backpack, reward.equipId, patch)
    end
    return false, "奖励配置异常"
end

local function buildRewardDisplay(reward, grantedItem)
    if reward.type == "consumable" then
        return {
            itemId = reward.consumableId,
            count = reward.count or 1,
        }
    end
    return {
        name = grantedItem and grantedItem.name or reward.equipId,
        icon = grantedItem and grantedItem.icon or "📦",
        quality = grantedItem and grantedItem.quality or "white",
        desc = grantedItem and grantedItem.desc or "",
        count = 1,
    }
end

local function rewardName(reward, grantedItem)
    if reward.type == "consumable" then
        local data = RewardUtil.GetConsumableData(reward.consumableId)
        return data and data.name or reward.consumableId
    end
    return grantedItem and grantedItem.name or reward.equipId
end

local function consumeKeyWithPatch(backpack, patch)
    local remaining = 1

    local function deductSlot(slot, item)
        local has = item.count or 1
        if has <= remaining then
            backpack[tostring(slot)] = nil
            backpack[slot] = nil
            remaining = remaining - has
            patch[#patch + 1] = { slot = slot, clear = true }
        else
            item.count = has - remaining
            remaining = 0
            patch[#patch + 1] = { slot = slot, item = item }
        end
    end

    local function pass(wantNoResell)
        for i = 1, GameConfig.BACKPACK_SIZE do
            if remaining <= 0 then break end
            local item = backpack[tostring(i)] or backpack[i]
            if item and item.category == "consumable"
                and item.consumableId == Config.KEY_ID
                and not TradeLock.IsLockedServerSide(item)
                and TradeLock.IsNoResell(item) == wantNoResell then
                deductSlot(i, item)
            end
        end
    end

    pass(true)
    pass(false)
    return remaining <= 0
end

local function startOk(connection, chestId, state)
    send(connection, SaveProtocol.S2C_WubaoTreasure_StartResult, {
        ok = true,
        chestId = chestId,
        stateJson = cjson.encode(state),
    })
end

function M.HandleStartOpen(eventType, eventData)
    local connKey, userId, slot, connection = extractContext(eventData)
    if not userId then return end
    local chestId = readString(eventData, "chestId")
    if chestId == "" or not Config.CHESTS[chestId] then
        sendError(connection, SaveProtocol.S2C_WubaoTreasure_StartResult, chestId, "宝箱不存在")
        return
    end
    if chestActive_[connKey] then
        sendError(connection, SaveProtocol.S2C_WubaoTreasure_StartResult, chestId, "操作进行中")
        return
    end
    if not Session.AcquireSlotLock(userId, slot) then
        sendError(connection, SaveProtocol.S2C_WubaoTreasure_StartResult, chestId, "存档正在写入，请稍后重试")
        return
    end
    chestActive_[connKey] = true

    local released = false
    local function release()
        if not released then
            released = true
            chestActive_[connKey] = nil
            Session.ReleaseSlotLock(userId, slot)
        end
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_StartResult, chestId, "存档读取失败")
            return
        end
        local state = ensureState(saveData)
        local orderChanged = ensureRewardOrder(state)
        if state.opened[chestId] then
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_StartResult, chestId, "宝箱已开启")
            return
        end

        local function confirmStart()
            if BackpackUtils.CountUnlockedItem(saveData.backpack or {}, Config.KEY_ID) < 1 then
                release()
                sendError(connection, SaveProtocol.S2C_WubaoTreasure_StartResult, chestId, "需要堡主钥匙")
                return
            end
            openingChest_[connKey] = chestId
            release()
            startOk(connection, chestId, state)
        end

        if orderChanged then
            local orderSaveData = cloneSaveWithState(saveData, state)
            writeSaveBack(userId, slot, orderSaveData, "wubao_treasure_order:" .. chestId, confirmStart, function()
                release()
                sendError(connection, SaveProtocol.S2C_WubaoTreasure_StartResult, chestId, "奖励映射保存失败，请稍后重试")
            end)
        else
            confirmStart()
        end
    end)
end

function M.HandleCancelOpen(eventType, eventData)
    local connKey, userId = extractContext(eventData)
    if not userId then return end
    local chestId = readString(eventData, "chestId")
    if chestId == "" or openingChest_[connKey] == chestId then
        openingChest_[connKey] = nil
    end
end

function M.HandleCompleteOpen(eventType, eventData)
    local connKey, userId, slot, connection = extractContext(eventData)
    if not userId then return end
    local chestId = readString(eventData, "chestId")
    if chestId == "" or not Config.CHESTS[chestId] then
        sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "宝箱不存在")
        return
    end
    if openingChest_[connKey] ~= chestId then
        sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "开箱状态异常，请重新开启")
        return
    end
    if chestActive_[connKey] then
        sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "操作进行中")
        return
    end
    if not Session.AcquireSlotLock(userId, slot) then
        sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "存档正在写入，请稍后重试")
        return
    end
    chestActive_[connKey] = true

    local released = false
    local function release()
        if not released then
            released = true
            chestActive_[connKey] = nil
            Session.ReleaseSlotLock(userId, slot)
        end
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "存档读取失败，请重新开启")
            return
        end
        local state = ensureState(saveData)
        local orderChanged = ensureRewardOrder(state)
        if state.opened[chestId] then
            openingChest_[connKey] = nil
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "宝箱已开启")
            return
        end
        if orderChanged then
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "奖励映射刚修复，请重新开启")
            return
        end
        if BackpackUtils.CountUnlockedItem(saveData.backpack or {}, Config.KEY_ID) < 1 then
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "需要堡主钥匙")
            return
        end

        local rewardId = state.rewardOrder[chestId]
        local reward = Config.REWARDS[rewardId]
        if not reward then
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "奖励配置异常")
            return
        end

        local nextSaveData = cloneSaveWithState(saveData, state)
        nextSaveData.backpack = nextSaveData.backpack or {}
        local nextState = nextSaveData.wubaoTreasureState

        local patch = {}
        local rewardOk, rewardReason, grantedItem = applyReward(nextSaveData.backpack, reward, rewardId, patch)
        if not rewardOk then
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, rewardReason)
            return
        end
        if not consumeKeyWithPatch(nextSaveData.backpack, patch) then
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "钥匙扣除失败，请重新开启")
            return
        end

        nextState.opened[chestId] = true

        writeSaveBack(userId, slot, nextSaveData, "wubao_treasure_open:" .. chestId, function()
            openingChest_[connKey] = nil
            release()
            local display = buildRewardDisplay(reward, grantedItem)
            local name = rewardName(reward, grantedItem)
            send(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, {
                ok = true,
                chestId = chestId,
                rewardId = rewardId,
                stateJson = cjson.encode(nextState),
                backpackPatch = cjson.encode(patch),
                rewardJson = cjson.encode({ display }),
                message = "获得 " .. tostring(name) .. " ×" .. tostring(reward.count or 1),
            })
            Logger.info("WubaoTreasure", "open ok userId=" .. tostring(userId)
                .. " slot=" .. tostring(slot) .. " chest=" .. chestId
                .. " reward=" .. tostring(rewardId))
        end, function()
            release()
            sendError(connection, SaveProtocol.S2C_WubaoTreasure_OpenResult, chestId, "奖励保存失败，请重新开启")
        end)
    end)
end

function M.CleanupConnection(connKey)
    openingChest_[connKey] = nil
    chestActive_[connKey] = nil
end

function M.GMGrantKeys16(userId, slot, connection)
    local cmd = "wubao_keys_16"
    if not userId or not slot then
        sendGMResult(connection, cmd, false, "未选择角色存档")
        return
    end
    if not Session.AcquireSlotLock(userId, slot) then
        sendGMResult(connection, cmd, false, "存档正在写入，请稍后重试")
        return
    end

    local released = false
    local function release()
        if not released then
            released = true
            Session.ReleaseSlotLock(userId, slot)
        end
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            release()
            sendGMResult(connection, cmd, false, "存档读取失败")
            return
        end

        local nextSaveData = cloneValue(saveData)
        nextSaveData.backpack = nextSaveData.backpack or {}
        local ok, _, changes, reason = RewardUtil.AddConsumableToBackpack(
            nextSaveData.backpack,
            Config.KEY_ID,
            16,
            "gm_wubao_treasure_key"
        )
        if not ok then
            release()
            local msg = reason == "backpack_full" and "背包已满，无法发放堡主钥匙" or "堡主钥匙配置异常"
            sendGMResult(connection, cmd, false, msg)
            return
        end

        writeSaveBack(userId, slot, nextSaveData, "gm_wubao_keys_16", function()
            release()
            sendGMResult(connection, cmd, true, "堡主钥匙 ×16 已发放", {
                backpackPatch = cjson.encode(changes),
            })
        end, function()
            release()
            sendGMResult(connection, cmd, false, "堡主钥匙保存失败")
        end)
    end)
end

function M.GMResetTreasure(userId, slot, connection, connKey)
    local cmd = "wubao_reset_treasure"
    if not userId or not slot then
        sendGMResult(connection, cmd, false, "未选择角色存档")
        return
    end
    if not Session.AcquireSlotLock(userId, slot) then
        sendGMResult(connection, cmd, false, "存档正在写入，请稍后重试")
        return
    end

    if connKey then
        openingChest_[connKey] = nil
        chestActive_[connKey] = nil
    end

    local released = false
    local function release()
        if not released then
            released = true
            Session.ReleaseSlotLock(userId, slot)
        end
    end

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            release()
            sendGMResult(connection, cmd, false, "存档读取失败")
            return
        end

        local nextSaveData = cloneValue(saveData)
        nextSaveData.wubaoTreasureState = { rewardOrder = {}, opened = {} }

        writeSaveBack(userId, slot, nextSaveData, "gm_wubao_reset_treasure", function()
            release()
            sendGMResult(connection, cmd, true, "乌家宝藏已重置", {
                stateJson = cjson.encode(nextSaveData.wubaoTreasureState),
            })
        end, function()
            release()
            sendGMResult(connection, cmd, false, "乌家宝藏重置保存失败")
        end)
    end)
end

return M
