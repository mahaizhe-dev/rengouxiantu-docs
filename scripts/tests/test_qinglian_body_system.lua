-- ============================================================================
-- test_qinglian_body_system.lua - 第六章青莲长生体事务测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

MOUSEB_LEFT = MOUSEB_LEFT or 0
MOUSEB_MIDDLE = MOUSEB_MIDDLE or 1
MOUSEB_RIGHT = MOUSEB_RIGHT or 2

local originalInventorySystem = package.loaded["systems.InventorySystem"]
local InventorySystem = { _mgr = nil }
function InventorySystem.SetManager(mgr) InventorySystem._mgr = mgr end
function InventorySystem.GetManager() return InventorySystem._mgr end
function InventorySystem.RecalcEquipStats() return true end
package.loaded["systems.InventorySystem"] = InventorySystem

local passed, failed = 0, 0

local function ok(cond, msg)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("[FAIL] " .. (msg or "assertion failed"))
    end
end

local function eq(actual, expected, msg)
    ok(actual == expected, (msg or "eq") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local AscensionConfig = require("config.AscensionConfig")
local MonsterData = require("config.MonsterData")
local ZoneDataCh6 = require("config.ZoneData_ch6")
local BlackMerchantConfig = require("config.BlackMerchantConfig")
local ImmortalBodySystem = require("systems.ImmortalBodySystem")
local SaveMigrations = require("systems.save.SaveMigrations")
local SaveState = require("systems.save.SaveState")
local QinglianBodySystem = require("systems.QinglianBodySystem")

local originalPlayer = GameState.player
local originalSlot = GameState.currentSlot
local originalSaveSystem = package.loaded["systems.SaveSystem"]
function InventorySystem.CountUnlockedConsumable(consumableId)
    local mgr = InventorySystem.GetManager()
    if not mgr then return 0 end
    local total = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            total = total + (item.count or 1)
        end
    end
    return total
end

function InventorySystem.ConsumeConsumable(consumableId, amount)
    local mgr = InventorySystem.GetManager()
    if not mgr then return false end
    amount = amount or 1
    if InventorySystem.CountUnlockedConsumable(consumableId) < amount then return false end

    local remaining = amount
    for i = 1, GameConfig.BACKPACK_SIZE do
        if remaining <= 0 then break end
        local item = mgr:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            local count = item.count or 1
            if count <= remaining then
                mgr:SetInventoryItem(i, nil)
                remaining = remaining - count
            else
                item.count = count - remaining
                remaining = 0
            end
        end
    end
    return remaining <= 0
end

local function newManager(slots)
    slots = slots or {}
    return {
        slots = slots,
        equipment = {},
        onChange = nil,
        GetInventoryItem = function(self, index) return self.slots[index] end,
        SetInventoryItem = function(self, index, item) self.slots[index] = item end,
        GetEquipmentItem = function(self, slotId) return self.equipment[slotId] end,
        SetEquipmentItem = function(self, slotId, item)
            self.equipment[slotId] = item
            return true
        end,
        AddToInventory = function(self, item)
            for i = 1, GameConfig.BACKPACK_SIZE do
                if not self.slots[i] then
                    self.slots[i] = item
                    return true, i
                end
            end
            return false, nil
        end,
    }
end

local function resetAccount()
    local account = ImmortalBodySystem.GetAccountState()
    account.unlockedBodies = { mortal = { unlockedAt = 0, source = "default" } }
    account.version = 1
end

local function resetEnv(saveOk)
    QinglianBodySystem.Reset()
    QinglianBodySystem.Init(nil)
    ImmortalBodySystem.Init()
    resetAccount()
    GameState.currentSlot = 1
    GameState.player = {
        level = 121,
        realm = "zhexian",
        exp = 0,
        maxHp = 1000,
        atk = 100,
        def = 50,
        hpRegen = 5,
        hp = 1000,
        lingYun = 50000,
        alive = true,
        x = 10,
        y = 10,
        GainExp = function(self, amount)
            self.exp = self.exp + amount
        end,
        InvalidateStatsCache = function(self)
            self._statsCacheFrame = -1
        end,
        GetTotalMaxHp = function(self)
            return self.maxHp
        end,
    }
    SaveState.loaded = true
    SaveState.activeSlot = 1
    SaveState.saving = false
    SaveState._retryTimer = nil
    SaveState._disconnected = false

    local saves = { count = 0 }
    package.loaded["systems.SaveSystem"] = {
        Save = function(callback)
            saves.count = saves.count + 1
            if callback then callback(saveOk ~= false, saveOk == false and "forced_fail" or "ok") end
        end,
    }
    return saves
end

local function makeDewStack(count)
    return {
        id = "dew_stack",
        name = "莲池仙露",
        icon = "image/icon_lotus_pool_dew_20260701120319.png",
        category = "consumable",
        consumableId = QinglianBodySystem.CONSUMABLE_ID,
        count = count,
        quality = "red",
        sellPrice = 30000,
    }
end

print("\n=== Qinglian Body System Tests ===")

do
    resetEnv(true)
    InventorySystem.SetManager(newManager({ [1] = makeDewStack(2) }))

    local started = QinglianBodySystem.Activate("ch6_qingbai_lotus_01")
    ok(started, "activation starts when resources and save state are valid")
    eq(QinglianBodySystem.IsActivated("ch6_qingbai_lotus_01"), true, "lotus marked active")
    eq(QinglianBodySystem.GetActivatedCount(), 1, "activated count")
    eq(InventorySystem.CountUnlockedConsumable(QinglianBodySystem.CONSUMABLE_ID), 1, "dew consumed once")
    eq(GameState.player.lingYun, 30000, "lingYun consumed")
    eq(GameState.player.exp, QinglianBodySystem.EXP_REWARD, "exp granted")
end

do
    resetEnv(false)
    InventorySystem.SetManager(newManager({ [1] = makeDewStack(1) }))
    GameState.player.exp = 12345
    GameState.player.lingYun = 50000

    local started = QinglianBodySystem.Activate("ch6_qingbai_lotus_01")
    ok(started, "activation still starts before forced save failure")
    eq(QinglianBodySystem.IsActivated("ch6_qingbai_lotus_01"), false, "activation rolled back")
    eq(QinglianBodySystem.GetActivatedCount(), 0, "count rolled back")
    eq(InventorySystem.CountUnlockedConsumable(QinglianBodySystem.CONSUMABLE_ID), 1, "dew restored")
    eq(GameState.player.lingYun, 50000, "lingYun restored")
    eq(GameState.player.exp, 12345, "exp restored")
    eq(ImmortalBodySystem.IsUnlocked(QinglianBodySystem.BODY_ID), false, "body unlock rolled back")
end

do
    local saves = resetEnv(true)
    InventorySystem.SetManager(newManager({ [1] = makeDewStack(1) }))

    local started = QinglianBodySystem.Activate("bad_lotus_id")
    ok(not started, "invalid lotus id cannot activate")
    eq(InventorySystem.CountUnlockedConsumable(QinglianBodySystem.CONSUMABLE_ID), 1, "invalid id does not consume dew")
    eq(GameState.player.lingYun, 50000, "invalid id does not consume lingYun")
    eq(saves.count, 0, "invalid id does not save")
    eq(QinglianBodySystem.GetActivatedCount(), 0, "invalid id does not affect progress")
end

do
    resetEnv(true)
    InventorySystem.SetManager(newManager({ [1] = makeDewStack(1) }))
    for i = 1, 8 do
        QinglianBodySystem.activatedLotuses[string.format("ch6_qingbai_lotus_%02d", i)] = true
    end

    local started = QinglianBodySystem.Activate("ch6_qingbai_lotus_09")
    ok(started, "ninth activation starts")
    eq(QinglianBodySystem.GetActivatedCount(), 9, "all lotuses activated")
    eq(QinglianBodySystem.finalRewardClaimed, true, "final reward claimed flag")
    eq(ImmortalBodySystem.IsUnlocked(QinglianBodySystem.BODY_ID), true, "qinglian body unlocked")
    eq(ImmortalBodySystem.GetActiveBodyId(), "mortal", "unlock does not auto switch active body")

    local accountData = ImmortalBodySystem.SerializeAccount()
    ImmortalBodySystem.Init()
    resetAccount()
    ImmortalBodySystem.DeserializeAccount(accountData)
    eq(ImmortalBodySystem.IsUnlocked(QinglianBodySystem.BODY_ID), true, "qinglian body persists as account unlock")
    eq(ImmortalBodySystem.GetActiveBodyId(), "mortal", "new character active body remains independent")
    GameState.player.lingYun = AscensionConfig.IMMORTAL_BODY_SWITCH_COST_LINGYUN
    local switchOk = ImmortalBodySystem.RequestSwitch(QinglianBodySystem.BODY_ID)
    ok(switchOk, "account unlocked qinglian body can be selected by another character")
end

do
    QinglianBodySystem.Deserialize(nil)
    eq(QinglianBodySystem.GetActivatedCount(), 0, "nil save data is safe")
    QinglianBodySystem.Deserialize({
        activatedLotuses = { ch6_qingbai_lotus_01 = true, bad = true },
        finalRewardClaimed = true,
    })
    eq(QinglianBodySystem.IsActivated("ch6_qingbai_lotus_01"), true, "deserialize active lotus")
    eq(QinglianBodySystem.IsActivated("bad"), false, "deserialize ignores invalid ids")
    eq(QinglianBodySystem.GetActivatedCount(), 1, "deserialize invalid ids do not affect progress")
    eq(QinglianBodySystem.Serialize().finalRewardClaimed, true, "serialize final flag")
end

do
    local migrated, err = SaveMigrations.MigrateSaveData({
        version = 33,
        player = { level = 121, realm = "zhexian", shadowGodPillCount = 0 },
    })
    ok(migrated ~= nil, "v33 save migrates to v34 without error: " .. tostring(err))
    if migrated then
        eq(migrated.version, 34, "migration bumps save version to v34")
        ok(type(migrated.qinglianBody) == "table", "migration initializes qinglianBody")
        ok(type(migrated.qinglianBody.activatedLotuses) == "table", "migration initializes lotus table")
        eq(migrated.qinglianBody.finalRewardClaimed, false, "migration defaults final reward to false")
    end
end

do
    local profile = AscensionConfig.GROWTH_PROFILES[QinglianBodySystem.BODY_ID]
    ok(profile ~= nil, "growth profile registered")
    eq(profile.maxHp, 30, "qinglian maxHp growth")
    eq(profile.atk, 3, "qinglian atk growth")
    eq(profile.def, 2, "qinglian def growth")
    eq(profile.hpRegen, 1.0, "qinglian regen growth")

    local dew = GameConfig.CONSUMABLES[QinglianBodySystem.CONSUMABLE_ID]
    ok(dew ~= nil, "lotus pool dew registered as consumable")
    eq(dew.icon, "image/icon_lotus_pool_dew_20260701120319.png", "dew icon path")

    local bm = BlackMerchantConfig.ITEMS[QinglianBodySystem.CONSUMABLE_ID]
    ok(bm ~= nil, "dew registered in black market")
    eq(bm.category, "consumable_mat", "black market category")
    eq(bm.sell_price, 60, "black market buy price for player")
    eq(bm.buy_price, 30, "black market sell price for player")
end

do
    local function hasDrop(monsterId, chance)
        local mt = MonsterData.Types[monsterId]
        for _, drop in ipairs(mt.dropTable or {}) do
            if drop.type == "consumable"
                and drop.consumableId == QinglianBodySystem.CONSUMABLE_ID
                and drop.chance == chance then
                return true
            end
        end
        return false
    end
    ok(hasDrop("ch6_toad_immortal", 0.002), "toad immortal dew drop 0.2%")
    ok(hasDrop("ch6_gua_master", 0.0005), "gua master dew drop 0.05%")

    local lotusCount = 0
    local ids = {}
    for _, npc in ipairs(ZoneDataCh6.NPCs or {}) do
        if npc.interactType == QinglianBodySystem.INTERACT_TYPE then
            lotusCount = lotusCount + 1
            ids[npc.id] = true
        end
    end
    eq(lotusCount, 9, "nine qinglian lotuses registered")
    for i = 1, 9 do
        ok(ids[string.format("ch6_qingbai_lotus_%02d", i)] == true, "stable lotus id " .. i)
    end
end

InventorySystem.SetManager(nil)
GameState.player = originalPlayer
GameState.currentSlot = originalSlot
package.loaded["systems.SaveSystem"] = originalSaveSystem
package.loaded["systems.InventorySystem"] = originalInventorySystem
QinglianBodySystem.Reset()

local total = passed + failed
print(string.format("\n=== Qinglian Body Tests: %d/%d passed, %d failed ===", passed, total, failed))

return { passed = passed, failed = failed, total = total }
