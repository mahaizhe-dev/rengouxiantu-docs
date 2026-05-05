-- ============================================================================
-- SaveSlots.lua - 槽位管理（FetchSlots / BuildSlotSummary / CreateCharacter / DeleteCharacter）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local CloudStorage = require("network.CloudStorage")
local SS = require("systems.save.SaveState")
local SaveKeys = require("systems.save.SaveKeys")

local SaveSlots = {}

--- 更新槽位索引摘要
---@param slot number
---@param charName string
---@param playerData table
---@return table
function SaveSlots.BuildSlotSummary(slot, charName, playerData)
    local realm = playerData.realm or "mortal"
    local realmCfg = GameConfig.REALMS[realm]
    local realmName = realmCfg and realmCfg.name or "凡人"

    return {
        name = charName or SS.DEFAULT_CHARACTER_NAME,
        level = playerData.level or 1,
        realm = realm,
        realmName = realmName,
        chapter = playerData.chapter or 1,
        classId = playerData.classId or "monk",
        lastSave = os.time(),
        saveVersion = SS.CURRENT_SAVE_VERSION,
    }
end

--- 获取所有槽位信息
---@param callback function(slotsIndex: table|nil, error: string|nil)
function SaveSlots.FetchSlots(callback)
    -- 网络模式委托
    if CloudStorage.IsNetworkMode() then
        local SaveSystemNet = require("network.SaveSystemNet")
        return SaveSystemNet.FetchSlots(callback)
    end

    print("[SaveSystem] Fetching slots index...")

    CloudStorage.BatchGet()
        :Key("slots_index")
        :Key("save_data")
        :Key("save_data_1")
        :Key("save_data_2")
        :Key("save_data_3")
        :Key("save_data_4")
        :Key("save_1")
        :Key("save_2")
        :Key("save_3")
        :Key("save_4")
        :Key("account_bulletin")
        :Fetch({
            ok = function(values, iscores)
                -- 加载账号级公告数据
                if values.account_bulletin then
                    local BulletinUI = require("ui.BulletinUI")
                    BulletinUI.DeserializeAccount(values.account_bulletin)
                end
                if values.slots_index then
                    local index = values.slots_index
                    -- P0-D: 正向验证
                    index.slots = index.slots or {}
                    for slot = 1, SS.MAX_SLOTS do
                        if index.slots[slot] then
                            local legacyKey = SaveKeys.GetSaveKey(slot)
                            local newKey = SaveKeys.GetKey("save", slot)
                            local hasData = (values[newKey] and type(values[newKey]) == "table")
                                or (values[legacyKey] and type(values[legacyKey]) == "table")
                            if not hasData then
                                local cached = SS._lastSavedData and SS._lastSavedData[slot]
                                if cached and type(cached) == "table" then
                                    print("[SaveSystem] Slot " .. slot
                                        .. " cloud data missing but LOCAL CACHE available (Lv."
                                        .. (cached.player and cached.player.level or "?")
                                        .. "), skipping dataLost")
                                else
                                    index.slots[slot].dataLost = true
                                    print("[SaveSystem] WARNING: Slot " .. slot
                                        .. " index exists but save data is MISSING!") -- fixed
                                end
                            end
                        end
                    end

                    -- P0-D: 反向验证（孤儿存档自愈）
                    local needRepair = false
                    for slot = 1, SS.MAX_SLOTS do
                        if not index.slots[slot] then
                            local newKey = SaveKeys.GetKey("save", slot)
                            local legacyKey = SaveKeys.GetSaveKey(slot)
                            local saveData = values[newKey] or values[legacyKey]
                            if saveData and type(saveData) == "table" and saveData.player then
                                local p = saveData.player
                                local realm = p.realm or "mortal"
                                local realmCfg = GameConfig.REALMS[realm]
                                local realmName = realmCfg and realmCfg.name or "凡人"
                                index.slots[slot] = {
                                    name = p.charName or SS.DEFAULT_CHARACTER_NAME,
                                    level = p.level or 1,
                                    realm = realm,
                                    realmName = realmName,
                                    chapter = p.chapter or 1,
                                    classId = p.classId or "monk",
                                    lastSave = saveData.timestamp or os.time(),
                                    saveVersion = saveData.version or 1,
                                    recovered = true,
                                }
                                needRepair = true
                                print("[SaveSystem] RECOVERED orphan slot " .. slot
                                    .. ": Lv." .. (p.level or 1) .. " " .. realmName)
                            end
                        end
                    end

                    if needRepair then
                        CloudStorage.BatchSet()
                            :Set("slots_index", index)
                            :Save("自愈修复slots_index", {
                                ok = function()
                                    print("[SaveSystem] Orphan slots repaired in cloud")
                                end,
                                error = function(code, reason)
                                    print("[SaveSystem] Orphan repair write failed: " .. tostring(reason))
                                end,
                            })
                    end

                    local lostSlots = {}
                    for slot = 1, SS.MAX_SLOTS do
                        if index.slots[slot] and index.slots[slot].dataLost then
                            table.insert(lostSlots, slot)
                        end
                    end

                    if #lostSlots > 0 then
                        print("[SaveSystem] dataLost remains for slot(s): " .. table.concat(lostSlots, ","))
                    else
                        print("[SaveSystem] Slots index found (all data intact)")
                    end

                    if callback then callback(index, nil) end
                    return
                end

                print("[SaveSystem] No save data found, new player")
                if callback then callback({ version = 1, slots = {} }, nil) end
            end,
            error = function(code, reason)
                print("[SaveSystem] Fetch slots failed: " .. tostring(reason))
                if callback then callback(nil, reason) end
            end,
        })
end

--- 在指定槽位创建新角色存档
---@param slot number
---@param charName string
---@param slotsIndex table
---@param callback function(success: boolean, message: string|nil)
function SaveSlots.CreateCharacter(slot, charName, slotsIndex, callback, classId)
    if CloudStorage.IsNetworkMode() then
        local SaveSystemNet = require("network.SaveSystemNet")
        return SaveSystemNet.CreateCharacter(slot, charName, slotsIndex, callback, classId)
    end

    print("[SaveSystem] Creating character '" .. charName .. "' in slot " .. slot
        .. " class=" .. (classId or "default"))

    local initialPlayer = {
        level = GameConfig.PLAYER_INITIAL.level,
        exp = GameConfig.PLAYER_INITIAL.exp,
        hp = GameConfig.PLAYER_INITIAL.hp,
        maxHp = GameConfig.PLAYER_INITIAL.maxHp,
        atk = GameConfig.PLAYER_INITIAL.atk,
        def = GameConfig.PLAYER_INITIAL.def,
        hpRegen = GameConfig.PLAYER_INITIAL.hpRegen,
        gold = GameConfig.PLAYER_INITIAL.gold,
        lingYun = GameConfig.PLAYER_INITIAL.lingYun,
        realm = GameConfig.PLAYER_INITIAL.realm,
        classId = classId or GameConfig.PLAYER_CLASS,
    }

    local coreData = {
        version = SS.CURRENT_SAVE_VERSION,
        timestamp = os.time(),
        player = initialPlayer,
        equipment = {},
        backpack = {},
        skills = {},
        collection = {},
        pet = {},
        quests = {},
    }

    local updatedIndex = slotsIndex or { version = 1, slots = {} }
    updatedIndex.slots = updatedIndex.slots or {}
    updatedIndex.slots[slot] = SaveSlots.BuildSlotSummary(slot, charName, initialPlayer)

    local saveKey = SaveKeys.GetKey("save", slot)

    CloudStorage.BatchSet()
        :Set(saveKey, coreData)
        :Set("slots_index", updatedIndex)
        :Save("创建角色", {
            ok = function()
                print("[SaveSystem] Character '" .. charName .. "' created in slot " .. slot .. " [single-key]")
                if callback then callback(true) end
            end,
            error = function(code, reason)
                print("[SaveSystem] Create character failed: " .. tostring(reason))
                if callback then callback(false, reason) end
            end,
        })
end

--- 删除指定槽位的角色
---@param slot number
---@param slotsIndex table
---@param callback function(success: boolean, message: string|nil)
function SaveSlots.DeleteCharacter(slot, slotsIndex, callback)
    if CloudStorage.IsNetworkMode() then
        local SaveSystemNet = require("network.SaveSystemNet")
        return SaveSystemNet.DeleteCharacter(slot, slotsIndex, callback)
    end

    print("[SaveSystem] Deleting character in slot " .. slot)

    local newSaveKey = SaveKeys.GetKey("save", slot)
    local newDeletedKey = SaveKeys.GetKey("deleted", slot)
    local legacy = SaveKeys.GetLegacyKeys(slot)

    CloudStorage.BatchGet()
        :Key(newSaveKey)
        :Key(legacy.save)
        :Key(legacy.bag1)
        :Key(legacy.bag2)
        :Fetch({
            ok = function(values)
                local newData = values[newSaveKey]
                local oldData = values[legacy.save]
                local b1Data = values[legacy.bag1]
                local b2Data = values[legacy.bag2]

                local updatedIndex = slotsIndex or { version = 1, slots = {} }
                updatedIndex.slots = updatedIndex.slots or {}
                updatedIndex.slots[slot] = nil

                local rankScoreKey = "rank_score_" .. slot
                local rankInfoKey = "rank_info_" .. slot

                local batch = CloudStorage.BatchSet()
                    :Set("slots_index", updatedIndex)
                    :Delete(newSaveKey)
                    :Delete(rankScoreKey)
                    :Delete(rankInfoKey)
                batch:Delete(legacy.save)
                batch:Delete(legacy.bag1)
                batch:Delete(legacy.bag2)

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
                    batch:Set(newDeletedKey, {
                        data = backupData,
                        deletedAt = os.time(),
                    })
                end

                batch:Save("删除角色", {
                    ok = function()
                        print("[SaveSystem] Character in slot " .. slot .. " deleted (backup saved) [single-key]")
                        if callback then callback(true) end
                    end,
                    error = function(code, reason)
                        print("[SaveSystem] Delete character failed: " .. tostring(reason))
                        if callback then callback(false, reason) end
                    end,
                })
            end,
            error = function(code, reason)
                print("[SaveSystem] Cannot read save for backup: " .. tostring(reason))
                if callback then callback(false, reason) end
            end,
        })
end

return SaveSlots
