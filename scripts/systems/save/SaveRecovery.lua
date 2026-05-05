-- ============================================================================
-- SaveRecovery.lua - 存档恢复（TryRecoverSave）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local CloudStorage = require("network.CloudStorage")
local SS = require("systems.save.SaveState")
local SaveKeys = require("systems.save.SaveKeys")

-- 延迟引用：SaveLoader 和 SaveRecovery 互相依赖
local SaveLoader
local function ensureLoader()
    if not SaveLoader then
        SaveLoader = require("systems.save.SaveLoader")
    end
end

local SaveRecovery = {}

--- 尝试从备份源恢复丢失的存档
---@param slot number
---@param callback function(success: boolean, message: string)
function SaveRecovery.TryRecoverSave(slot, callback)
    print("[SaveSystem] Attempting recovery for slot " .. slot .. "...")

    local newLoginKey = SaveKeys.GetKey("login", slot)
    local newPrevKey = SaveKeys.GetKey("prev", slot)
    local newDeletedKey = SaveKeys.GetKey("deleted", slot)
    local legacy = SaveKeys.GetLegacyKeys(slot)

    CloudStorage.BatchGet()
        :Key(newLoginKey)
        :Key(newPrevKey)
        :Key(newDeletedKey)
        :Key(legacy.login)
        :Key(legacy.loginBag1)
        :Key(legacy.loginBag2)
        :Key(legacy.prev)
        :Key(legacy.prevBag1)
        :Key(legacy.prevBag2)
        :Key(legacy.backup)
        :Key(legacy.bakBag1)
        :Key(legacy.bakBag2)
        :Key("slots_index")
        :Fetch({
            ok = function(values)
                local function rebuildInventory(data, bag1KeyName, bag2KeyName)
                    if not data then return data end
                    if data.backpack and type(data.backpack) == "table" then
                        data.inventory = {
                            equipment = data.equipment or {},
                            backpack = data.backpack,
                        }
                        data.equipment = nil
                        data.backpack = nil
                        return data
                    end
                    local b1 = values[bag1KeyName]
                    local b2 = values[bag2KeyName]
                    local backpack = {}
                    if b1 and type(b1) == "table" then
                        local realB1 = (b1.data and type(b1.data) == "table" and b1.deletedAt) and b1.data or b1
                        for k, v in pairs(realB1) do backpack[k] = v end
                    end
                    if b2 and type(b2) == "table" then
                        local realB2 = (b2.data and type(b2.data) == "table" and b2.deletedAt) and b2.data or b2
                        for k, v in pairs(realB2) do backpack[k] = v end
                    end
                    data.inventory = {
                        equipment = data.equipment or {},
                        backpack = backpack,
                    }
                    data.equipment = nil
                    return data
                end

                local candidates = {}

                -- v11 login
                if values[newLoginKey] and type(values[newLoginKey]) == "table" then
                    local lb = rebuildInventory(values[newLoginKey], nil, nil)
                    if lb and lb.player then
                        local lv = lb.player.level or 1
                        table.insert(candidates, { data = lb, source = "v11登录备份", level = lv, key = newLoginKey })
                        print("[SaveSystem] Recovery candidate: " .. newLoginKey .. " Lv." .. lv)
                    end
                end

                -- v10 login
                if values[legacy.login] and type(values[legacy.login]) == "table" then
                    local lb = rebuildInventory(values[legacy.login], legacy.loginBag1, legacy.loginBag2)
                    if lb and lb.player then
                        local lv = lb.player.level or 1
                        table.insert(candidates, { data = lb, source = "v10登录备份", level = lv, key = legacy.login })
                        print("[SaveSystem] Recovery candidate: " .. legacy.login .. " Lv." .. lv)
                    end
                end

                -- v11 prev
                if values[newPrevKey] and type(values[newPrevKey]) == "table" then
                    local prev = rebuildInventory(values[newPrevKey], nil, nil)
                    if prev and prev.player then
                        local lv = prev.player.level or 1
                        table.insert(candidates, { data = prev, source = "v11定期备份", level = lv, key = newPrevKey })
                        print("[SaveSystem] Recovery candidate: " .. newPrevKey .. " Lv." .. lv)
                    end
                end

                -- v10 prev
                if values[legacy.prev] and type(values[legacy.prev]) == "table" then
                    local prev = rebuildInventory(values[legacy.prev], legacy.prevBag1, legacy.prevBag2)
                    if prev and prev.player then
                        local lv = prev.player.level or 1
                        table.insert(candidates, { data = prev, source = "v10定期备份", level = lv, key = legacy.prev })
                        print("[SaveSystem] Recovery candidate: " .. legacy.prev .. " Lv." .. lv)
                    end
                end

                -- v11 deleted
                if values[newDeletedKey] and type(values[newDeletedKey]) == "table" then
                    local backup = values[newDeletedKey]
                    local bkData = (backup.data and type(backup.data) == "table") and backup.data or backup
                    if bkData.player then
                        rebuildInventory(bkData, nil, nil)
                        local lv = bkData.player.level or 1
                        table.insert(candidates, { data = bkData, source = "v11删除备份", level = lv, key = newDeletedKey })
                        print("[SaveSystem] Recovery candidate: " .. newDeletedKey .. " Lv." .. lv)
                    end
                end

                -- v10 deleted
                if values[legacy.backup] and type(values[legacy.backup]) == "table" then
                    local backup = values[legacy.backup]
                    if backup.data and type(backup.data) == "table" and backup.data.player then
                        rebuildInventory(backup.data, legacy.bakBag1, legacy.bakBag2)
                        local lv = backup.data.player.level or 1
                        table.insert(candidates, { data = backup.data, source = "v10删除备份", level = lv, key = legacy.backup })
                        print("[SaveSystem] Recovery candidate: " .. legacy.backup .. " Lv." .. lv)
                    end
                end

                -- 选出等级最高的
                local recoveredData = nil
                local recoverySource = nil
                local bestLevel = 0
                for _, c in ipairs(candidates) do
                    if c.level > bestLevel then
                        bestLevel = c.level
                        recoveredData = c.data
                        recoverySource = c.source
                    end
                end
                if recoveredData then
                    print("[SaveSystem] Best recovery source: " .. recoverySource .. " (Lv." .. bestLevel .. ")")
                end

                -- 最后手段：从 slots_index 元数据重建最小存档
                if not recoveredData then
                    local rebuildData = nil
                    local rebuildLevel = 0
                    local slotsIndex = values["slots_index"]
                    if slotsIndex and slotsIndex.slots and slotsIndex.slots[slot] then
                        local meta = slotsIndex.slots[slot]
                        rebuildLevel = meta.level or 1
                        local rebuildRealm = meta.realm or "mortal"
                        local rebuildChapter = meta.chapter or 1

                        local baseHp = 100 + (rebuildLevel - 1) * 15
                        local baseAtk = 15 + (rebuildLevel - 1) * 3
                        local baseDef = 5 + (rebuildLevel - 1) * 2
                        local baseHpRegen = 1.0 + (rebuildLevel - 1) * 0.2

                        local realmBonusHp, realmBonusAtk, realmBonusDef, realmBonusRegen = 0, 0, 0, 0
                        for _, rid in ipairs(GameConfig.REALM_LIST) do
                            local rd = GameConfig.REALMS[rid]
                            if rd and rd.rewards then
                                realmBonusHp = realmBonusHp + (rd.rewards.maxHp or 0)
                                realmBonusAtk = realmBonusAtk + (rd.rewards.atk or 0)
                                realmBonusDef = realmBonusDef + (rd.rewards.def or 0)
                                realmBonusRegen = realmBonusRegen + (rd.rewards.hpRegen or 0)
                            end
                            if rid == rebuildRealm then break end
                        end

                        local rebuildExp = GameConfig.EXP_TABLE[rebuildLevel] or 0

                        rebuildData = {
                            version = SS.CURRENT_SAVE_VERSION,
                            timestamp = os.time(),
                            player = {
                                level = rebuildLevel,
                                exp = rebuildExp,
                                hp = baseHp + realmBonusHp,
                                maxHp = baseHp + realmBonusHp,
                                atk = baseAtk + realmBonusAtk,
                                def = baseDef + realmBonusDef,
                                hpRegen = baseHpRegen + realmBonusRegen,
                                gold = 1000,
                                lingYun = 0,
                                realm = rebuildRealm,
                                chapter = rebuildChapter,
                                pillKillHeal = 0,
                                pillConstitution = 0,
                                fruitFortune = 0,
                                daoTreeWisdom = 0,
                                daoTreeWisdomPity = 0,
                                pillPhysique = 0,
                                x = 0,
                                y = 0,
                                seaPillarDef = 0,
                                seaPillarAtk = 0,
                                seaPillarMaxHp = 0,
                                seaPillarHpRegen = 0,
                            },
                            inventory = {},
                            skills = {},
                            collection = {},
                            pet = {},
                            quests = {},
                            shop = {},
                            titles = {},
                            challenges = {},
                            sealDemon = { quests = {} },
                            bulletin = {},
                            artifact = {},
                            fortuneFruits = { collected = {} },
                            trialTower = {},
                            bossKillTimes = {},
                            code_version = GameConfig.CODE_VERSION,
                            bossKills = 0,
                            _bossKillsMigrated = true,
                            seaPillar = {},
                        }
                    end

                    if rebuildData then
                        recoveredData = rebuildData
                        recoveredData._recoveredFromMeta = true
                        recoverySource = "元数据重建(仅保留等级境界)"
                        print("[SaveSystem] Last resort: rebuilding from slots_index meta — Lv."
                            .. rebuildLevel)
                    end
                end

                if not recoveredData then
                    print("[SaveSystem] No recovery source found for slot " .. slot)
                    SS.loaded = false
                    if callback then callback(false, "存档数据丢失，未找到可恢复的备份") end
                    return
                end

                -- 将恢复的数据写回
                local recSaveKey = SaveKeys.GetKey("save", slot)
                local recoveredPlayer = recoveredData.player or {}
                local recoveredLevel = recoveredPlayer.level or 1
                local recoveredRealm = recoveredPlayer.realm or "mortal"
                local realmCfg = GameConfig.REALMS[recoveredRealm]
                local realmName = realmCfg and realmCfg.name or "凡人"

                local recInv = recoveredData.inventory or {}
                local recCoreData = {}
                for k, v in pairs(recoveredData) do
                    if k ~= "inventory" then recCoreData[k] = v end
                end
                recCoreData.equipment = recInv.equipment or {}
                recCoreData.backpack = recInv.backpack or {}

                CloudStorage.BatchGet()
                    :Key("slots_index")
                    :Fetch({
                        ok = function(idxValues)
                            local updatedIndex = idxValues.slots_index or { version = 1, slots = {} }
                            updatedIndex.slots = updatedIndex.slots or {}
                            local oldName = SS.DEFAULT_CHARACTER_NAME
                            if updatedIndex.slots[slot] then
                                oldName = updatedIndex.slots[slot].name or oldName
                            end
                            updatedIndex.slots[slot] = {
                                name = oldName,
                                level = recoveredLevel,
                                realm = recoveredRealm,
                                realmName = realmName,
                                chapter = recoveredPlayer.chapter or 1,
                                lastSave = os.time(),
                                saveVersion = recoveredData.version or 1,
                            }
                            local batch = CloudStorage.BatchSet()
                                :Set(recSaveKey, recCoreData)
                                :Set("slots_index", updatedIndex)
                            batch:Delete(legacy.save)
                            batch:Delete(legacy.bag1)
                            batch:Delete(legacy.bag2)
                            batch:Save("恢复存档+同步索引", {
                                    ok = function()
                                        print("[SaveSystem] Recovery: data + slots_index synced for slot " .. slot .. " [single-key]")
                                    end,
                                    error = function(code, reason)
                                        print("[SaveSystem] Recovery write-back failed: " .. tostring(reason))
                                    end,
                                })
                        end,
                        error = function(code, reason)
                            print("[SaveSystem] Recovery: slots_index read failed, writing data only: " .. tostring(reason))
                            local batch = CloudStorage.BatchSet()
                                :Set(recSaveKey, recCoreData)
                            batch:Delete(legacy.save)
                            batch:Delete(legacy.bag1)
                            batch:Delete(legacy.bag2)
                            batch:Save("恢复存档", {
                                    ok = function()
                                        print("[SaveSystem] Recovery data written back to " .. recSaveKey .. " [single-key]")
                                    end,
                                    error = function(code2, reason2)
                                        print("[SaveSystem] Recovery write-back failed: " .. tostring(reason2))
                                    end,
                                })
                        end,
                    })

                -- 立即用恢复的数据进行反序列化
                ensureLoader()
                SaveLoader.ProcessLoadedData(slot, recoveredData, recoverySource, callback)
            end,
            error = function(code, reason)
                print("[SaveSystem] Recovery query failed: " .. tostring(reason))
                SS.loaded = false
                if callback then callback(false, "存档数据为空，备份查询失败: " .. tostring(reason)) end
            end,
        })
end

return SaveRecovery
