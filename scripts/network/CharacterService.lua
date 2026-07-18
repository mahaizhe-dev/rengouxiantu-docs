-- ============================================================================
-- CharacterService.lua - character slot create/delete service
-- ============================================================================

local GameConfig = require("config.GameConfig")
local SaveProtocol = require("network.SaveProtocol")
local Session = require("network.ServerSession")
local RankHandler = require("network.RankHandler")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local M = {}

local SafeSend = Session.SafeSend
local NormalizeSlotsIndex = Session.NormalizeSlotsIndex
local creatingChar_ = Session.creatingChar_

local function SendResult(connection, success, message)
    local data = VariantMap()
    data["ok"] = Variant(success)
    if message then data["message"] = Variant(message) end
    SafeSend(connection, SaveProtocol.S2C_CharResult, data)
end

local function ResolveIdentity(eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = Session.GetUserId(Session.ConnKey(connection))
    if userId then return connection, userId end
    SendResult(connection, false, "identity_not_ready")
    return connection, nil
end

function M.HandleCreate(eventType, eventData)
    local connection, userId = ResolveIdentity(eventData)
    if not userId then return end

    local slot = eventData["slot"]:GetInt()
    local charName = eventData["charName"]:GetString()
    local classId = eventData["classId"]:GetString()
    if not classId or classId == "" or not GameConfig.CLASS_DATA[classId] then
        classId = GameConfig.PLAYER_CLASS
    end

    print("[Server] CreateChar: userId=" .. tostring(userId)
        .. " slot=" .. slot .. " name=" .. charName .. " class=" .. classId)

    if slot < 1 or slot > 4 then
        print("[Server] CreateChar REJECTED: slot " .. slot
            .. " out of allowed range (1-4)")
        SendResult(connection, false, "该槽位不允许创建角色")
        return
    end

    local guardKey = tostring(userId) .. ":" .. slot
    if creatingChar_[guardKey] then
        print("[Server] CreateChar REJECTED: already in progress for " .. guardKey)
        SendResult(connection, false, "正在创建中，请稍候")
        return
    end
    creatingChar_[guardKey] = true

    local saveKey = "save_" .. slot
    serverCloud:BatchGet(userId)
        :Key("slots_index")
        :Key(saveKey)
        :Fetch({
            ok = function(scores)
                local slotsIndex = scores["slots_index"]
                    or { version = 1, slots = {} }
                slotsIndex.slots = slotsIndex.slots or {}
                NormalizeSlotsIndex(slotsIndex)

                if slotsIndex.slots[slot] then
                    creatingChar_[guardKey] = nil
                    SendResult(connection, false, "槽位已被占用")
                    return
                end

                local existingSave = scores[saveKey]
                if existingSave and type(existingSave) == "table"
                    and existingSave.player then
                    creatingChar_[guardKey] = nil
                    print("[Server] CreateChar BLOCKED: save_" .. slot
                        .. " data exists but index missing! userId="
                        .. tostring(userId) .. " - refusing overwrite")
                    SendResult(connection, false, "该槽位存在数据，请联系客服")
                    return
                end

                local coreData = {
                    version = 11,
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
                    triggeredBattles = {},
                }

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

                serverCloud:BatchSet(userId)
                    :Set(saveKey, coreData)
                    :Set("slots_index", slotsIndex)
                    :Save("创建角色", {
                        ok = function()
                            local function FinishCreate()
                                creatingChar_[guardKey] = nil
                                print("[Server] Character created: userId="
                                    .. tostring(userId) .. " slot=" .. slot
                                    .. " name=" .. charName)
                                local data = VariantMap()
                                data["ok"] = Variant(true)
                                data["slot"] = Variant(slot)
                                data["slotsIndex"] = Variant(cjson.encode(slotsIndex))
                                SafeSend(connection, SaveProtocol.S2C_CharResult, data)
                            end
                            RankHandler.ClearCultivationRanks(userId, slot, {
                                ok = FinishCreate,
                                error = function(code, reason)
                                    print("[Server] CreateChar stale rank clear FAILED: "
                                        .. tostring(code) .. " " .. tostring(reason))
                                    FinishCreate()
                                end,
                            })
                        end,
                        error = function(code, reason)
                            creatingChar_[guardKey] = nil
                            print("[Server] CreateChar failed: " .. tostring(reason))
                            SendResult(connection, false, tostring(reason))
                        end,
                    })
            end,
            error = function(code, reason)
                creatingChar_[guardKey] = nil
                print("[Server] CreateChar read index failed: " .. tostring(reason))
                SendResult(connection, false, tostring(reason))
            end,
        })
end

function M.HandleDelete(eventType, eventData)
    local connection, userId = ResolveIdentity(eventData)
    if not userId then return end

    local slot = eventData["slot"]:GetInt()
    print("[Server] DeleteChar: userId=" .. tostring(userId) .. " slot=" .. slot)

    local newSaveKey = "save_" .. slot
    local oldSaveKey = "save_data_" .. slot
    local oldBag1Key = "save_bag1_" .. slot
    local oldBag2Key = "save_bag2_" .. slot
    local deleteRead = serverCloud:BatchGet(userId)
        :Key(newSaveKey)
        :Key(oldSaveKey)
        :Key(oldBag1Key)
        :Key(oldBag2Key)
        :Key("slots_index")
    for readSlot = 1, 4 do
        local readKey = "save_" .. readSlot
        if readKey ~= newSaveKey then deleteRead:Key(readKey) end
    end

    deleteRead:Fetch({
        ok = function(scores)
            local slotsIndex = scores["slots_index"]
                or { version = 1, slots = {} }
            slotsIndex.slots = slotsIndex.slots or {}
            NormalizeSlotsIndex(slotsIndex)

            local newData = scores[newSaveKey]
            local oldData = scores[oldSaveKey]
            local b1Data = scores[oldBag1Key]
            local b2Data = scores[oldBag2Key]
            slotsIndex.slots[slot] = nil

            local batch = serverCloud:BatchSet(userId)
                :Set("slots_index", slotsIndex)
                :Delete(newSaveKey)
                :Delete(oldSaveKey)
                :Delete(oldBag1Key)
                :Delete(oldBag2Key)
                :Delete("rank_score_" .. slot)
                :Delete("rank_info_" .. slot)

            local backupData = nil
            if newData and type(newData) == "table" then
                backupData = newData
            elseif oldData and type(oldData) == "table" then
                backupData = oldData
                local backpack = {}
                if b1Data and type(b1Data) == "table" then
                    for key, value in pairs(b1Data) do backpack[key] = value end
                end
                if b2Data and type(b2Data) == "table" then
                    for key, value in pairs(b2Data) do backpack[key] = value end
                end
                backupData.backpack = backpack
            end
            if backupData then
                batch:Set("deleted_" .. slot, {
                    data = backupData,
                    deletedAt = os.time(),
                })
            end

            batch:Save("删除角色", {
                ok = function()
                    print("[Server] Character deleted: userId="
                        .. tostring(userId) .. " slot=" .. slot)
                    local taptapNick = ""
                    GetUserNickname({
                        userIds = { userId },
                        onSuccess = function(nicknames)
                            if nicknames and #nicknames > 0 then
                                taptapNick = nicknames[1].nickname or ""
                            end
                        end,
                    })

                    local pending = 2
                    local function Done()
                        pending = pending - 1
                        if pending > 0 then return end
                        local data = VariantMap()
                        data["ok"] = Variant(true)
                        data["slot"] = Variant(slot)
                        data["slotsIndex"] = Variant(cjson.encode(slotsIndex))
                        SafeSend(connection, SaveProtocol.S2C_CharResult, data)
                    end
                    local function Failed(label, code, reason)
                        print("[Server] DeleteChar " .. label .. " FAILED: "
                            .. tostring(code) .. " " .. tostring(reason))
                        Done()
                    end

                    RankHandler.ClearCultivationRanks(userId, slot, {
                        ok = Done,
                        error = function(code, reason)
                            Failed("rank clear", code, reason)
                        end,
                    })
                    RankHandler.RebuildAccountTowerRanks(
                        userId,
                        slotsIndex,
                        function(readSlot)
                            if readSlot == slot then return nil end
                            return scores["save_" .. readSlot]
                        end,
                        taptapNick,
                        {
                            ok = Done,
                            error = function(code, reason)
                                Failed("tower rebuild", code, reason)
                            end,
                        })
                end,
                error = function(code, reason)
                    print("[Server] DeleteChar failed: " .. tostring(reason))
                    SendResult(connection, false, tostring(reason))
                end,
            })
        end,
        error = function(code, reason)
            print("[Server] DeleteChar read failed: " .. tostring(reason))
            SendResult(connection, false, tostring(reason))
        end,
    })
end

return M
