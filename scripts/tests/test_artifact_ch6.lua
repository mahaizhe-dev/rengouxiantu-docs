-- ============================================================================
-- test_artifact_ch6.lua - 第六章神器「界匙」事务、账号、属性与战斗测试
-- 不初始化真实背包/网络；通过受控 mock 验证强保存和完整回滚。
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local passed, failed, total = 0, 0, 0
local errors = {}

local function assertTrue(value, message)
    if not value then error(message or "expected true", 2) end
end

local function assertFalse(value, message)
    if value then error(message or "expected false", 2) end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local function assertContains(text, needle, message)
    if not text or not text:find(needle, 1, true) then
        error((message or "text missing") .. ": " .. tostring(needle), 2)
    end
end

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS " .. name)
    else
        failed = failed + 1
        errors[#errors + 1] = name .. ": " .. tostring(err)
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[deepCopy(k, seen)] = deepCopy(v, seen)
    end
    return out
end

local function readFile(path)
    local file = assert(io.open(path, "rb"), "cannot open " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local function fileExists(path)
    local file = io.open(path, "rb")
    if not file then return false end
    file:close()
    return true
end

local GameState = require("core.GameState")
local SaveState = require("systems.save.SaveState")
local CombatFeedbackBridge = require("systems.combat.CombatFeedbackBridge")
local FeatureFlags = require("config.FeatureFlags")
local CombatFeedback = require("systems.combat.CombatFeedback")

local originalPlayer = GameState.player
local originalRandom = math.random
local originalSubscribeToEvent = _G.SubscribeToEvent
local originalModules = {
    inventory = package.loaded["systems.InventorySystem"],
    serializer = package.loaded["systems.save.SaveSerializer"],
    saveSystem = package.loaded["systems.SaveSystem"],
    atlas = package.loaded["systems.AtlasSystem"],
    combat = package.loaded["systems.CombatSystem"],
    challenge = package.loaded["systems.ChallengeSystem"],
    artifact = package.loaded["systems.ArtifactSystem"],
    artifactCh4 = package.loaded["systems.ArtifactSystem_ch4"],
    artifactCh5 = package.loaded["systems.ArtifactSystem_ch5"],
    artifactTiandi = package.loaded["systems.ArtifactSystem_tiandi"],
    artifactCh6 = package.loaded["systems.ArtifactSystem_ch6"],
}
local originalSaveState = {
    loaded = SaveState.loaded,
    activeSlot = SaveState.activeSlot,
    saving = SaveState.saving,
    retryTimer = SaveState._retryTimer,
    disconnected = SaveState._disconnected,
}

local fragmentCounts = {}
local consumeLocked = false
local saveBehavior = "success"
local saveCalls = 0
local pendingSaveCallback = nil
local callbackResults = {}
local now = 1000

local InventoryMock = {}
function InventoryMock.CountUnlockedConsumable(consumableId)
    return fragmentCounts[consumableId] or 0
end
function InventoryMock.ConsumeConsumable(consumableId, amount)
    if consumeLocked then return false end
    local count = fragmentCounts[consumableId] or 0
    if count < amount then return false end
    fragmentCounts[consumableId] = count - amount
    return true
end

local SaveSerializerMock = {}
function SaveSerializerMock.SerializeInventory()
    return { fragmentCounts = deepCopy(fragmentCounts) }
end
function SaveSerializerMock.DeserializeInventory(data)
    fragmentCounts = deepCopy(data and data.fragmentCounts or {})
end

local SaveSystemMock = {}
function SaveSystemMock.Save(callback)
    saveCalls = saveCalls + 1
    if saveBehavior == "throw" then error("forced_save_throw") end
    if saveBehavior == "pending" then
        pendingSaveCallback = callback
    elseif saveBehavior == "fail" then
        callback(false, "forced_save_fail")
    elseif saveBehavior == "duplicate_success" then
        callback(true, "ok")
        callback(false, "late_duplicate")
    else
        callback(true, "ok")
    end
end

local function emptyAccount()
    return {
        version = 1,
        activatedGrids = {
            false, false, false,
            false, false, false,
            false, false, false,
        },
        bossDefeated = false,
        passiveUnlocked = false,
        rescueReadyAt = 0,
    }
end

local function unlockedAccount(readyAt)
    return {
        version = 1,
        activatedGrids = {
            true, true, true,
            true, true, true,
            true, true, true,
        },
        bossDefeated = true,
        passiveUnlocked = true,
        rescueReadyAt = readyAt or 0,
    }
end

local AtlasMock = {
    loaded = true,
    data = {
        version = 3,
        artifact_jieshi = emptyAccount(),
    },
}
function AtlasMock.MarkArtifactJieshiAccountLoaded()
    AtlasMock.accountMarked = true
end

local CombatMock = {
    floatingTexts = {},
    rescueEffects = {},
}
function CombatMock.AddFloatingText(x, y, text, color, duration)
    CombatMock.floatingTexts[#CombatMock.floatingTexts + 1] = text
end
CombatFeedbackBridge(CombatMock)
function CombatMock.AddJieshiRescueEffect(player, duration)
    CombatMock.rescueEffects[#CombatMock.rescueEffects + 1] = {
        player = player,
        duration = duration,
    }
end
function CombatMock.GetBuffAtkPercent() return 0 end
function CombatMock.GetBuffDefPercent() return 0 end
function CombatMock.GetBuffCritDmgPercent() return 0 end
function CombatMock.GetBuffConstitutionFlat() return 0 end
function CombatMock.GetBuffPhysiqueFlat() return 0 end
function CombatMock.GetBuffFortuneFlat() return 0 end
function CombatMock.GetBuffWisdomFlat() return 0 end

local BaguaMock = {
    passiveUnlocked = false,
    remainingDamage = nil,
    shieldHp = 0,
    arenaActive = false,
}
function BaguaMock.AbsorbDamage(damage)
    if BaguaMock.remainingDamage ~= nil then
        return BaguaMock.remainingDamage
    end
    if not BaguaMock.passiveUnlocked or BaguaMock.shieldHp <= 0 then
        return damage
    end
    local absorbed = math.min(damage, BaguaMock.shieldHp)
    BaguaMock.shieldHp = BaguaMock.shieldHp - absorbed
    return damage - absorbed
end
function BaguaMock.GetShieldStatus()
    return BaguaMock.shieldHp, BaguaMock.shieldHp
end

local ChallengeMock = { active = false }
local ArtifactArenaMock = { arenaActive = false }

package.loaded["systems.InventorySystem"] = InventoryMock
package.loaded["systems.save.SaveSerializer"] = SaveSerializerMock
package.loaded["systems.SaveSystem"] = SaveSystemMock
package.loaded["systems.AtlasSystem"] = AtlasMock
package.loaded["systems.CombatSystem"] = CombatMock
package.loaded["systems.ChallengeSystem"] = ChallengeMock
package.loaded["systems.ArtifactSystem"] = ArtifactArenaMock
package.loaded["systems.ArtifactSystem_ch4"] = BaguaMock
package.loaded["systems.ArtifactSystem_ch5"] = ArtifactArenaMock
package.loaded["systems.ArtifactSystem_tiandi"] = ArtifactArenaMock
package.loaded["systems.ArtifactSystem_ch6"] = nil

local ArtifactCh6 = require("systems.ArtifactSystem_ch6")
local Player = require("entities.Player")
local GameConfig = require("config.GameConfig")

local function newTransactionPlayer()
    return {
        x = 0,
        y = 0,
        gold = 0,
        lingYun = 0,
        hp = 1000,
        alive = true,
        artifactCh6MaxHp = 0,
        artifactCh6HpRegen = 0,
        artifactCh6Fortune = 0,
        InvalidateStatsCache = function(self)
            self._statsCacheFrame = -1
        end,
        SetMoveDirection = function(self, dx, dy)
            self.moveDirX = dx
            self.moveDirY = dy
        end,
        GetTotalMaxHp = function(self)
            return 1000 + (self.artifactCh6MaxHp or 0)
        end,
    }
end

local function resetEnv()
    fragmentCounts = {}
    consumeLocked = false
    saveBehavior = "success"
    saveCalls = 0
    pendingSaveCallback = nil
    callbackResults = {}
    now = 1000

    SaveState.loaded = true
    SaveState.activeSlot = 1
    SaveState.saving = false
    SaveState._retryTimer = nil
    SaveState._disconnected = false

    AtlasMock.loaded = true
    AtlasMock.accountMarked = false
    AtlasMock.data = {
        version = 3,
        artifact_jieshi = emptyAccount(),
    }
    package.loaded["systems.AtlasSystem"] = AtlasMock
    package.loaded["systems.ChallengeSystem"] = ChallengeMock
    package.loaded["systems.ArtifactSystem"] = ArtifactArenaMock
    package.loaded["systems.ArtifactSystem_ch4"] = BaguaMock
    package.loaded["systems.ArtifactSystem_ch5"] = ArtifactArenaMock
    package.loaded["systems.ArtifactSystem_tiandi"] = ArtifactArenaMock

    CombatMock.floatingTexts = {}
    CombatMock.rescueEffects = {}
    BaguaMock.passiveUnlocked = false
    BaguaMock.remainingDamage = nil
    BaguaMock.shieldHp = 0
    BaguaMock.arenaActive = false
    ChallengeMock.active = false
    ArtifactArenaMock.arenaActive = false
    math.random = function() return 0.5 end

    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}
    GameState.bossKillTimes = {}
    GameState.player = newTransactionPlayer()
    ArtifactCh6.SetTimeProviderForTest(function() return now end)
    ArtifactCh6.gmBypass = false
    ArtifactCh6.Reset()
end

local function grantFragment(index, count)
    fragmentCounts[ArtifactCh6.FRAGMENT_IDS[index]] = count or 1
end

local function activateWithCallback(index)
    return ArtifactCh6.Activate(index, function(ok, message, details)
        callbackResults[#callbackResults + 1] = {
            ok = ok,
            message = message,
            details = details,
        }
    end)
end

local function unlockPassiveForCombat()
    for i = 1, ArtifactCh6.GRID_COUNT do
        ArtifactCh6.activatedGrids[i] = true
    end
    ArtifactCh6.bossDefeated = true
    ArtifactCh6.passiveUnlocked = true
    ArtifactCh6.rescueReadyAt = 0
end

local function newCombatPlayer()
    local player = Player.New(0, 0, { classId = "taixu" })
    player.maxHp = 1001
    player.hp = 1001
    player.def = 0
    player.equipDef = 0
    player.equipSpecialEffects = {}
    player.GetTotalMaxHp = function() return 1001 end
    player.InvalidateStatsCache = function(self)
        self._statsCacheFrame = -1
    end
    GameState.player = player
    return player
end

print("\n[test_artifact_ch6] === 界匙完整实现测试 ===\n")

test("配置、总消耗和最终属性符合定案", function()
    resetEnv()
    assertEqual(ArtifactCh6.GRID_COUNT, 9)
    assertEqual(ArtifactCh6.ACTIVATE_GOLD_COST, 30000000)
    assertEqual(ArtifactCh6.ACTIVATE_LINGYUN_COST, 30000)
    assertEqual(ArtifactCh6.ACTIVATE_GOLD_COST * 9, 270000000)
    assertEqual(ArtifactCh6.ACTIVATE_LINGYUN_COST * 9, 270000)
    assertEqual(ArtifactCh6.PASSIVE.invincibleDuration, 3.0)
    assertContains(ArtifactCh6.PASSIVE.desc, "无敌3秒")

    for count = 0, 9 do
        ArtifactCh6.Reset()
        for i = 1, count do ArtifactCh6.activatedGrids[i] = true end
        local hp, regen, fortune = ArtifactCh6.GetCurrentBonus()
        local full = count == 9 and 1 or 0
        assertEqual(hp, count * 150 + full * 150, "maxHp count=" .. count)
        assertEqual(regen, count * 10 + full * 10, "regen count=" .. count)
        assertEqual(fortune, count * 10 + full * 10, "fortune count=" .. count)
    end
end)

test("缺少碎片、金币、灵韵时分别阻断", function()
    resetEnv()
    GameState.player.gold = 30000000
    GameState.player.lingYun = 30000
    local ok, reason = ArtifactCh6.CanActivate(1)
    assertFalse(ok)
    assertContains(reason, "缺少")

    grantFragment(1)
    GameState.player.gold = 29999999
    ok, reason = ArtifactCh6.CanActivate(1)
    assertFalse(ok)
    assertContains(reason, "金币不足")

    GameState.player.gold = 30000000
    GameState.player.lingYun = 29999
    ok, reason = ArtifactCh6.CanActivate(1)
    assertFalse(ok)
    assertContains(reason, "灵韵不足")
end)

test("锁定碎片扣除失败时不扣资源、不改进度", function()
    resetEnv()
    grantFragment(1)
    consumeLocked = true
    GameState.player.gold = 30000000
    GameState.player.lingYun = 30000
    local started, reason = activateWithCallback(1)
    assertFalse(started)
    assertContains(reason, "碎片扣除失败")
    assertEqual(fragmentCounts[ArtifactCh6.FRAGMENT_IDS[1]], 1)
    assertEqual(GameState.player.gold, 30000000)
    assertEqual(GameState.player.lingYun, 30000)
    assertFalse(ArtifactCh6.IsGridActivated(1))
    assertEqual(saveCalls, 0)
end)

test("激活成功只在保存确认后回调，并同步账号档", function()
    resetEnv()
    grantFragment(2)
    GameState.player.gold = 50000000
    GameState.player.lingYun = 50000
    saveBehavior = "pending"

    local started = activateWithCallback(2)
    assertTrue(started)
    assertTrue(ArtifactCh6.IsBusy())
    assertEqual(#callbackResults, 0)
    assertTrue(ArtifactCh6.IsGridActivated(2))
    assertEqual(fragmentCounts[ArtifactCh6.FRAGMENT_IDS[2]], 0)
    assertEqual(GameState.player.gold, 20000000)
    assertEqual(GameState.player.lingYun, 20000)
    assertTrue(AtlasMock.data.artifact_jieshi.activatedGrids[2])
    assertTrue(AtlasMock.accountMarked)

    pendingSaveCallback(true, "ok")
    assertFalse(ArtifactCh6.IsBusy())
    assertEqual(#callbackResults, 1)
    assertTrue(callbackResults[1].ok)
    assertEqual(callbackResults[1].details.maxHp, 150)
    assertEqual(callbackResults[1].details.hpRegen, 10)
    assertEqual(callbackResults[1].details.fortune, 10)
end)

test("保存失败完整回滚背包、货币、位格、账号和派生属性", function()
    resetEnv()
    grantFragment(3)
    GameState.player.gold = 50000000
    GameState.player.lingYun = 50000
    AtlasMock.data.artifact_jieshi.customMarker = "before"
    saveBehavior = "pending"

    local started = activateWithCallback(3)
    assertTrue(started)
    assertEqual(GameState.player.artifactCh6MaxHp, 150)
    pendingSaveCallback(false, "forced")

    assertFalse(ArtifactCh6.IsGridActivated(3))
    assertEqual(fragmentCounts[ArtifactCh6.FRAGMENT_IDS[3]], 1)
    assertEqual(GameState.player.gold, 50000000)
    assertEqual(GameState.player.lingYun, 50000)
    assertEqual(GameState.player.artifactCh6MaxHp, 0)
    assertEqual(GameState.player.artifactCh6HpRegen, 0)
    assertEqual(GameState.player.artifactCh6Fortune, 0)
    assertEqual(AtlasMock.data.artifact_jieshi.customMarker, "before")
    assertEqual(#callbackResults, 1)
    assertFalse(callbackResults[1].ok)
    assertContains(callbackResults[1].message, "已回滚")
end)

test("重复保存回调只结算一次", function()
    resetEnv()
    grantFragment(4)
    GameState.player.gold = 50000000
    GameState.player.lingYun = 50000
    saveBehavior = "duplicate_success"
    local started = activateWithCallback(4)
    assertTrue(started)
    assertEqual(#callbackResults, 1)
    assertTrue(callbackResults[1].ok)
    assertTrue(ArtifactCh6.IsGridActivated(4))
    assertEqual(GameState.player.gold, 20000000)
end)

test("保存异常抛出时也会回滚事务", function()
    resetEnv()
    grantFragment(5)
    GameState.player.gold = 50000000
    GameState.player.lingYun = 50000
    saveBehavior = "throw"
    local started = activateWithCallback(5)
    assertTrue(started)
    assertFalse(ArtifactCh6.IsGridActivated(5))
    assertEqual(fragmentCounts[ArtifactCh6.FRAGMENT_IDS[5]], 1)
    assertEqual(GameState.player.gold, 50000000)
    assertEqual(#callbackResults, 1)
    assertFalse(callbackResults[1].ok)
end)

test("存档未加载、无槽位、保存中、重试中、断线和账号未加载均阻断", function()
    local cases = {
        {
            apply = function() SaveState.loaded = false end,
            expected = "存档尚未加载",
        },
        {
            apply = function() SaveState.activeSlot = nil end,
            expected = "没有激活的角色存档",
        },
        {
            apply = function() SaveState.saving = true end,
            expected = "正在保存",
        },
        {
            apply = function() SaveState._retryTimer = 1 end,
            expected = "等待重试",
        },
        {
            apply = function() SaveState._disconnected = true end,
            expected = "网络断开",
        },
        {
            apply = function() AtlasMock.loaded = false end,
            expected = "账号神器档案尚未加载",
        },
    }
    for _, case in ipairs(cases) do
        resetEnv()
        grantFragment(1)
        GameState.player.gold = 30000000
        GameState.player.lingYun = 30000
        case.apply()
        local ok, reason = ArtifactCh6.CanActivate(1)
        assertFalse(ok)
        assertContains(reason, case.expected)
    end
end)

test("角色镜像不含冷却，账号档包含冷却", function()
    resetEnv()
    ArtifactCh6.rescueReadyAt = 4567
    local character = ArtifactCh6.Serialize()
    local account = ArtifactCh6.SerializeAccount()
    assertEqual(character.rescueReadyAt, nil)
    assertEqual(account.rescueReadyAt, 4567)
end)

test("畸形九格被固定规范化，未满九格不可伪造Boss和被动", function()
    resetEnv()
    ArtifactCh6.Deserialize({
        activatedGrids = {
            [1] = true,
            [2] = 1,
            [10] = true,
        },
        bossDefeated = true,
        passiveUnlocked = true,
    })
    assertEqual(ArtifactCh6.GetActivatedCount(), 1)
    assertTrue(ArtifactCh6.IsGridActivated(1))
    assertFalse(ArtifactCh6.IsGridActivated(2))
    assertFalse(ArtifactCh6.bossDefeated)
    assertFalse(ArtifactCh6.passiveUnlocked)
    local canFight, reason = ArtifactCh6.CanFightBoss()
    assertFalse(canFight)
    assertContains(reason, "尚未全部激活")
end)

test("属性从九格真值重算，多次调用不会叠加", function()
    resetEnv()
    ArtifactCh6.activatedGrids[1] = true
    ArtifactCh6.activatedGrids[2] = true
    ArtifactCh6.RecalcAttributes()
    ArtifactCh6.RecalcAttributes()
    assertEqual(GameState.player.artifactCh6MaxHp, 300)
    assertEqual(GameState.player.artifactCh6HpRegen, 20)
    assertEqual(GameState.player.artifactCh6Fortune, 20)

    ArtifactCh6.activatedGrids[2] = false
    ArtifactCh6.RecalcAttributes()
    assertEqual(GameState.player.artifactCh6MaxHp, 150)
    assertEqual(GameState.player.artifactCh6HpRegen, 10)
    assertEqual(GameState.player.artifactCh6Fortune, 10)
end)

test("旧账号仅迁移一次角色镜像，账号字段出现后覆盖角色", function()
    resetEnv()
    package.loaded["systems.AtlasSystem"] = nil
    package.loaded["systems.ArtifactSystem_ch5"] = {
        GRID_COUNT = 9,
        activatedGrids = {},
        bossDefeated = false,
        passiveUnlocked = false,
        RecalcAttributes = function() end,
    }
    if not _G.SubscribeToEvent then
        _G.SubscribeToEvent = function() end
    end

    ArtifactCh6.Deserialize({
        activatedGrids = { true, false, false, false, false, false, false, false, false },
    })
    local RealAtlas = require("systems.AtlasSystem")
    RealAtlas.Deserialize({ version = 2, medals = {} })
    assertFalse(RealAtlas.HasArtifactJieshiAccountData())
    assertTrue(RealAtlas.MergeArtifactJieshiFromCharacter())
    assertTrue(RealAtlas.HasArtifactJieshiAccountData())
    assertTrue(RealAtlas.data.artifact_jieshi.activatedGrids[1])

    ArtifactCh6.activatedGrids[2] = true
    assertFalse(RealAtlas.MergeArtifactJieshiFromCharacter())
    assertFalse(RealAtlas.data.artifact_jieshi.activatedGrids[2])
    RealAtlas.SyncArtifactJieshiToCharacter()
    assertFalse(ArtifactCh6.activatedGrids[2])
    RealAtlas.Reset()
    assertFalse(RealAtlas.HasArtifactJieshiAccountData())

    package.loaded["systems.AtlasSystem"] = AtlasMock
    package.loaded["systems.ArtifactSystem_ch5"] = originalModules.artifactCh5
end)

test("切换角色后账号档恢复位格和替命冷却", function()
    resetEnv()
    package.loaded["systems.AtlasSystem"] = nil
    package.loaded["systems.ArtifactSystem_ch5"] = {
        GRID_COUNT = 9,
        activatedGrids = {},
        bossDefeated = false,
        passiveUnlocked = false,
        RecalcAttributes = function() end,
    }
    if not _G.SubscribeToEvent then
        _G.SubscribeToEvent = function() end
    end

    local RealAtlas = require("systems.AtlasSystem")
    RealAtlas.Deserialize({
        version = 3,
        medals = {},
        artifact_jieshi = {
            activatedGrids = {
                true, true, true,
                true, true, true,
                true, true, true,
            },
            bossDefeated = true,
            passiveUnlocked = true,
            rescueReadyAt = 1666,
        },
    })
    assertEqual(ArtifactCh6.GetActivatedCount(), 9)
    assertEqual(ArtifactCh6.rescueReadyAt, 1666)
    assertTrue(RealAtlas.data.artifact_jieshi.bossDefeated)
    assertTrue(RealAtlas.data.artifact_jieshi.passiveUnlocked)
    assertTrue(ArtifactCh6.passiveUnlocked)

    ArtifactCh6.Deserialize(nil)
    assertEqual(ArtifactCh6.GetActivatedCount(), 0)
    assertEqual(ArtifactCh6.rescueReadyAt, 0)
    RealAtlas.SyncArtifactJieshiToCharacter()
    assertEqual(ArtifactCh6.GetActivatedCount(), 9)
    assertEqual(ArtifactCh6.rescueReadyAt, 1666)

    package.loaded["systems.AtlasSystem"] = AtlasMock
    package.loaded["systems.ArtifactSystem_ch5"] = originalModules.artifactCh5
end)

local function prepareBossFight()
    resetEnv()
    for i = 1, ArtifactCh6.GRID_COUNT do
        ArtifactCh6.activatedGrids[i] = true
    end
    ArtifactCh6.RecalcAttributes()

    local worldMonster = { id = "world_monster", alive = true }
    local worldNpc = { id = "world_npc" }
    GameState.monsters = { worldMonster }
    GameState.npcs = { worldNpc }
    GameState.lootDrops = { { id = "world_loot" } }
    GameState.bossKillTimes = { world_boss = 123 }

    local map = {
        width = 4,
        height = 4,
        tiles = {
            {1, 1, 1, 1},
            {1, 2, 2, 1},
            {1, 2, 2, 1},
            {1, 1, 1, 1},
        },
    }
    local camera = {
        x = 2,
        y = 2,
        mapWidth = 4,
        mapHeight = 4,
    }
    return map, camera, worldMonster, worldNpc
end

test("神器双王配置为同源异化，魔化进攻、仙化防御治疗", function()
    resetEnv()
    local MonsterData = require("config.MonsterData")
    local demon = MonsterData.Types.artifact_ch6_gua_demon
    local immortal = MonsterData.Types.artifact_ch6_gua_immortal
    assertTrue(demon ~= nil)
    assertTrue(immortal ~= nil)
    assertEqual(demon.name, "魔化·呱大王")
    assertEqual(immortal.name, "仙化·呱大王")
    assertEqual(demon.portrait, immortal.portrait)
    assertTrue(demon.demonBuff)
    assertEqual(demon.artifactCh6Aspect, "demon")
    assertTrue((demon.artifactCh6AtkMult or 0) > 1)
    assertEqual(immortal.artifactCh6Aspect, "immortal")
    assertTrue((immortal.artifactCh6HpMult or 0) > 1)
    assertTrue((immortal.artifactCh6DefMult or 0) > 1)
    assertTrue((immortal.artifactCh6HealRatio or 0) > 0)
    assertEqual(#demon.dropTable, 0)
    assertEqual(#immortal.dropTable, 0)
end)

test("九格全满后进入竞技场生成两只不同强化的呱大王", function()
    local map, camera = prepareBossFight()
    local ok, reason = ArtifactCh6.EnterBossArena(map, camera)
    assertTrue(ok, reason)
    assertTrue(ArtifactCh6.arenaActive)
    assertEqual(#GameState.monsters, 2)

    local demon, immortal = nil, nil
    for _, monster in ipairs(GameState.monsters) do
        assertTrue(monster.isArtifactCh6Boss)
        if monster.artifactCh6Aspect == "demon" then demon = monster end
        if monster.artifactCh6Aspect == "immortal" then immortal = monster end
    end
    assertTrue(demon ~= nil)
    assertTrue(immortal ~= nil)
    assertTrue(demon.demonBuff)
    assertTrue(immortal.def > demon.def)
    assertTrue(immortal.maxHp > 0)
    assertEqual(ArtifactCh6.ARENA_SIZE, 12)
    assertEqual(map.width, ArtifactCh6.ARENA_SIZE + 2)
    assertEqual(map.height, 14)
    assertEqual(camera.mapWidth, 14)
    assertEqual(camera.mapHeight, 14)
    assertEqual(GameState.player.x, 7.5)
    assertEqual(GameState.player.y, 11.5)
    assertEqual(demon.x, 5.0)
    assertEqual(demon.y, 5.5)
    assertEqual(immortal.x, 10.0)
    assertEqual(immortal.y, 5.5)
    assertEqual(immortal.x - demon.x, 5.0)
end)

test("界匙双王战锁定回城且直接传送调用也不能越出竞技场", function()
    local originalTownReturn = package.loaded["systems.TownReturnSystem"]
    package.loaded["systems.TownReturnSystem"] = nil
    local TownReturnSystem = require("systems.TownReturnSystem")
    local map, camera = prepareBossFight()

    local started = TownReturnSystem.TryStart()
    assertTrue(started)
    assertTrue(TownReturnSystem.IsChanneling())

    local ok, reason = ArtifactCh6.EnterBossArena(map, camera)
    assertTrue(ok, reason)
    assertFalse(TownReturnSystem.IsChanneling())

    local canReturn, blockReason = TownReturnSystem.CanUse()
    assertFalse(canReturn)
    assertEqual(blockReason, "神器战斗中无法回城")

    local beforeX = GameState.player.x
    local beforeY = GameState.player.y
    local teleported, teleportReason = TownReturnSystem.PerformTeleport()
    assertFalse(teleported)
    assertEqual(teleportReason, "神器战斗中无法回城")
    assertEqual(GameState.player.x, beforeX)
    assertEqual(GameState.player.y, beforeY)

    ArtifactCh6.ExitBossArena(map, false, camera)
    local canReturnAfterExit = TownReturnSystem.CanUse()
    assertTrue(canReturnAfterExit)
    package.loaded["systems.TownReturnSystem"] = originalTownReturn
end)

test("仙化呱大王周期治疗仍存活双王并产生强化渲染状态", function()
    local map, camera = prepareBossFight()
    assertTrue(ArtifactCh6.EnterBossArena(map, camera))
    local demon, immortal = nil, nil
    for _, monster in ipairs(GameState.monsters) do
        if monster.artifactCh6Aspect == "demon" then demon = monster end
        if monster.artifactCh6Aspect == "immortal" then immortal = monster end
    end
    demon.hp = demon.maxHp - 1000
    immortal.hp = immortal.maxHp - 1000
    immortal.artifactCh6HealTimer = 0
    local demonBefore = demon.hp
    local immortalBefore = immortal.hp
    ArtifactCh6.UpdateBossArena(0.1, map, camera)
    assertTrue(demon.hp > demonBefore)
    assertTrue(immortal.hp > immortalBefore)
    assertTrue(demon.artifactCh6BlessingTimer > 0)
    assertTrue(immortal.artifactCh6BlessingTimer > 0)
    assertContains(table.concat(CombatMock.floatingTexts, "|"), "双界仙露")
end)

test("仅击败一王不结算，两王全灭后强保存并解锁被动", function()
    local map, camera, worldMonster, worldNpc = prepareBossFight()
    assertTrue(ArtifactCh6.EnterBossArena(map, camera))
    GameState.monsters[1].alive = false
    ArtifactCh6.UpdateBossArena(0.1, map, camera)
    assertTrue(ArtifactCh6.arenaActive)
    assertFalse(ArtifactCh6.bossDefeated)
    assertEqual(saveCalls, 0)

    GameState.monsters[2].alive = false
    ArtifactCh6.UpdateBossArena(0.1, map, camera)
    assertFalse(ArtifactCh6.arenaActive)
    assertTrue(ArtifactCh6.bossDefeated)
    assertTrue(ArtifactCh6.passiveUnlocked)
    assertEqual(saveCalls, 1)
    assertEqual(GameState.monsters[1], worldMonster)
    assertEqual(GameState.npcs[1], worldNpc)
    assertTrue(AtlasMock.data.artifact_jieshi.bossDefeated)
    assertTrue(AtlasMock.data.artifact_jieshi.passiveUnlocked)
end)

test("双王首胜保存失败回滚账号解锁且世界状态完整恢复", function()
    local map, camera, worldMonster = prepareBossFight()
    saveBehavior = "fail"
    assertTrue(ArtifactCh6.EnterBossArena(map, camera))
    for _, monster in ipairs(GameState.monsters) do monster.alive = false end
    ArtifactCh6.UpdateBossArena(0.1, map, camera)
    assertFalse(ArtifactCh6.arenaActive)
    assertFalse(ArtifactCh6.bossDefeated)
    assertFalse(ArtifactCh6.passiveUnlocked)
    assertFalse(AtlasMock.data.artifact_jieshi.bossDefeated)
    assertFalse(AtlasMock.data.artifact_jieshi.passiveUnlocked)
    assertEqual(GameState.monsters[1], worldMonster)
    assertContains(table.concat(CombatMock.floatingTexts, "|"), "觉醒保存失败")
end)

test("双王战中玩家死亡判负，恢复世界且不保存解锁", function()
    local map, camera, worldMonster = prepareBossFight()
    assertTrue(ArtifactCh6.EnterBossArena(map, camera))
    GameState.player.alive = false
    ArtifactCh6.UpdateBossArena(0.1, map, camera)
    assertFalse(ArtifactCh6.arenaActive)
    assertFalse(ArtifactCh6.bossDefeated)
    assertFalse(ArtifactCh6.passiveUnlocked)
    assertEqual(saveCalls, 0)
    assertEqual(GameState.monsters[1], worldMonster)
    assertTrue(GameState.player.alive)
end)

test("普通护盾优先吸收，不消耗两界替命", function()
    resetEnv()
    unlockPassiveForCombat()
    local player = newCombatPlayer()
    player.hp = 100
    player.shieldHp = 500
    player.shieldMaxHp = 500
    local damage = player:TakeDamage(200, {})
    assertEqual(damage, 0)
    assertEqual(player.hp, 100)
    assertEqual(player.shieldHp, 300)
    assertEqual(ArtifactCh6.rescueReadyAt, 0)
end)

test("文王护体优先吸收，不消耗两界替命", function()
    resetEnv()
    unlockPassiveForCombat()
    local player = newCombatPlayer()
    player.hp = 100
    BaguaMock.passiveUnlocked = true
    BaguaMock.remainingDamage = 0
    local damage = player:TakeDamage(200, {})
    assertEqual(damage, 0)
    assertEqual(player.hp, 100)
    assertEqual(ArtifactCh6.rescueReadyAt, 0)
end)

test("镇界、金钟罩、文王护体按顺序连续吸收", function()
    resetEnv()
    local player = newCombatPlayer()
    player.hp = 1000
    player._zhenjieShieldHp = 100
    player._zhenjieShieldMaxHp = 100
    player._zhenjieShieldDuration = 6
    player.shieldHp = 200
    player.shieldMaxHp = 200
    player.shieldTimer = 8
    BaguaMock.passiveUnlocked = true
    BaguaMock.shieldHp = 300

    local absorbedDamage = player:TakeDamage(450, {})
    assertEqual(absorbedDamage, 0)
    assertEqual(player.hp, 1000)
    assertEqual(player._zhenjieShieldHp, 0)
    assertEqual(player.shieldHp, 0)
    assertEqual(BaguaMock.shieldHp, 150)

    local hpDamage = player:TakeDamage(250, {})
    assertEqual(hpDamage, 100)
    assertEqual(BaguaMock.shieldHp, 0)
    assertEqual(player.hp, 900)
end)

test("装备免死成功时不消耗两界替命", function()
    resetEnv()
    unlockPassiveForCombat()
    local player = newCombatPlayer()
    player.hp = 1
    player.equipSpecialEffects = {
        { type = "death_immunity", immuneChance = 1, immuneDuration = 1.25 },
    }
    math.random = function() return 0 end
    player:TakeDamage(999999, {})
    assertTrue(player.alive)
    assertEqual(player.hp, 1)
    assertEqual(player.invincibleTimer, 1.25)
    assertEqual(ArtifactCh6.rescueReadyAt, 0)
end)

test("装备免死失败后触发两界替命，精确回复25%并无敌3秒", function()
    resetEnv()
    unlockPassiveForCombat()
    saveBehavior = "success"
    local player = newCombatPlayer()
    player.hp = 1
    player.equipSpecialEffects = {
        { type = "death_immunity", immuneChance = 0, immuneDuration = 1.25 },
    }
    math.random = function() return 0.9 end
    player:TakeDamage(999999, {})
    assertTrue(player.alive)
    assertEqual(player.hp, 250)
    assertEqual(player.invincibleTimer, 3.0)
    assertEqual(ArtifactCh6.rescueReadyAt, 1180)
    assertEqual(saveCalls, 1)
    assertEqual(#CombatMock.rescueEffects, 1)
    assertEqual(CombatMock.rescueEffects[1].player, player)
    assertEqual(CombatMock.rescueEffects[1].duration, 3.0)
    assertEqual(CombatMock.floatingTexts[1], "两界替命")
    assertEqual(CombatMock.floatingTexts[2], "+250")
end)

test("两界替命在V2中上报神器名与实际恢复值", function()
    resetEnv()
    unlockPassiveForCombat()
    saveBehavior = "success"
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    CombatFeedback.ResetForTest()
    local player = newCombatPlayer()
    player.hp = 1
    player.equipSpecialEffects = {
        { type = "death_immunity", immuneChance = 0, immuneDuration = 1.25 },
    }
    math.random = function() return 0.9 end

    player:TakeDamage(999999, {})

    local items = CombatFeedback.GetItems()
    local healItem = items[#items]
    assertEqual(healItem.kind, "heal")
    assertEqual(healItem.value, 250)
    assertEqual(healItem.label, "两界替命")
    assertEqual(#CombatMock.floatingTexts, 0)

    FeatureFlags.clearOverride("COMBAT_FEEDBACK_V2")
    CombatFeedback.ResetForTest()
end)

test("替命冷却阻止二次触发，180秒后恢复", function()
    resetEnv()
    unlockPassiveForCombat()
    saveBehavior = "success"
    local player = newCombatPlayer()
    player.hp = 1
    assertTrue(ArtifactCh6.TryRescuePlayer(player, {}))
    player.invincibleTimer = 0
    player.hp = 1
    assertFalse(ArtifactCh6.TryRescuePlayer(player, {}))
    now = 1179
    assertFalse(ArtifactCh6.TryRescuePlayer(player, {}))
    now = 1180
    assertTrue(ArtifactCh6.TryRescuePlayer(player, {}))
    assertEqual(ArtifactCh6.rescueReadyAt, 1360)
end)

test("bypassArtifactRescue可绕过神器并正常死亡", function()
    resetEnv()
    unlockPassiveForCombat()
    local player = newCombatPlayer()
    player.hp = 1
    player:TakeDamage(999999, { bypassArtifactRescue = true })
    assertFalse(player.alive)
    assertEqual(player.hp, 0)
    assertEqual(ArtifactCh6.rescueReadyAt, 0)
end)

test("角色镜像加载后再应用账号档可恢复跨角色冷却", function()
    resetEnv()
    ArtifactCh6.Deserialize({
        activatedGrids = { true, false, false, false, false, false, false, false, false },
    })
    assertEqual(ArtifactCh6.rescueReadyAt, 0)
    ArtifactCh6.ApplyAccountState({
        activatedGrids = { true, true, false, false, false, false, false, false, false },
        rescueReadyAt = 1300,
    })
    assertEqual(ArtifactCh6.GetActivatedCount(), 2)
    assertEqual(ArtifactCh6.rescueReadyAt, 1300)
end)

test("替命冷却保存失败保持待保存并按3秒重试至成功", function()
    resetEnv()
    unlockPassiveForCombat()
    saveBehavior = "fail"
    local player = newCombatPlayer()
    player.hp = 1
    assertTrue(ArtifactCh6.TryRescuePlayer(player, {}))
    assertTrue(ArtifactCh6.HasPendingCooldownSave())
    assertEqual(saveCalls, 1)

    ArtifactCh6.Update(2.9)
    assertEqual(saveCalls, 1)
    ArtifactCh6.Update(0.2)
    assertEqual(saveCalls, 2)
    assertTrue(ArtifactCh6.HasPendingCooldownSave())

    saveBehavior = "success"
    ArtifactCh6.Update(3.1)
    assertEqual(saveCalls, 3)
    assertFalse(ArtifactCh6.HasPendingCooldownSave())
end)

test("GM冷却清零强保存成功，保存失败时恢复账号旧冷却", function()
    resetEnv()
    local account = unlockedAccount(1800)
    AtlasMock.data.artifact_jieshi = deepCopy(account)
    ArtifactCh6.ApplyAccountState(account)

    local callbackOk, callbackMessage = nil, nil
    local started = ArtifactCh6.GMResetCooldown(function(ok, message)
        callbackOk = ok
        callbackMessage = message
    end)
    assertTrue(started)
    assertTrue(callbackOk)
    assertContains(callbackMessage, "冷却已清零")
    assertEqual(saveCalls, 1)
    assertEqual(ArtifactCh6.rescueReadyAt, 0)
    assertEqual(AtlasMock.data.artifact_jieshi.rescueReadyAt, 0)

    resetEnv()
    account = unlockedAccount(1900)
    AtlasMock.data.artifact_jieshi = deepCopy(account)
    ArtifactCh6.ApplyAccountState(account)
    saveBehavior = "fail"
    callbackOk = nil
    started = ArtifactCh6.GMResetCooldown(function(ok)
        callbackOk = ok
    end)
    assertTrue(started)
    assertFalse(callbackOk)
    assertEqual(ArtifactCh6.rescueReadyAt, 1900)
    assertEqual(AtlasMock.data.artifact_jieshi.rescueReadyAt, 1900)
end)

test("GM账号重置清除九格Boss被动冷却和派生属性，失败完整回滚", function()
    resetEnv()
    GameState.player = newTransactionPlayer()
    local account = unlockedAccount(1800)
    AtlasMock.data.artifact_jieshi = deepCopy(account)
    ArtifactCh6.ApplyAccountState(account)
    assertEqual(GameState.player.artifactCh6MaxHp, 1500)

    local callbackOk = nil
    local started = ArtifactCh6.GMResetAccount(function(ok)
        callbackOk = ok
    end)
    assertTrue(started)
    assertTrue(callbackOk)
    assertEqual(ArtifactCh6.GetActivatedCount(), 0)
    assertFalse(ArtifactCh6.bossDefeated)
    assertFalse(ArtifactCh6.passiveUnlocked)
    assertEqual(ArtifactCh6.rescueReadyAt, 0)
    assertEqual(GameState.player.artifactCh6MaxHp, 0)
    assertEqual(GameState.player.artifactCh6HpRegen, 0)
    assertEqual(GameState.player.artifactCh6Fortune, 0)
    assertFalse(AtlasMock.data.artifact_jieshi.activatedGrids[1])

    resetEnv()
    GameState.player = newTransactionPlayer()
    account = unlockedAccount(1900)
    AtlasMock.data.artifact_jieshi = deepCopy(account)
    ArtifactCh6.ApplyAccountState(account)
    saveBehavior = "fail"
    callbackOk = nil
    started = ArtifactCh6.GMResetAccount(function(ok)
        callbackOk = ok
    end)
    assertTrue(started)
    assertFalse(callbackOk)
    assertEqual(ArtifactCh6.GetActivatedCount(), 9)
    assertTrue(ArtifactCh6.bossDefeated)
    assertTrue(ArtifactCh6.passiveUnlocked)
    assertEqual(ArtifactCh6.rescueReadyAt, 1900)
    assertEqual(GameState.player.artifactCh6MaxHp, 1500)
    assertTrue(AtlasMock.data.artifact_jieshi.activatedGrids[1])
end)

test("服务端账号档权威规范化九格、镜像、冷却并拒绝未满九格觉醒", function()
    resetEnv()
    local SaveWriteService = require("network.SaveWriteService")
    local coreData = {
        player = {
            artifactCh6MaxHp = 999999,
            artifactCh6HpRegen = 999999,
            artifactCh6Fortune = 999999,
        },
        artifact_ch6 = {
            activatedGrids = { false, true, true, true, true, true, true, true, true },
            bossDefeated = true,
            passiveUnlocked = true,
        },
        atlas = {
            version = 1,
            artifact_jieshi = {
                activatedGrids = {
                    true, 1, false,
                    false, false, false,
                    false, false, false,
                    [10] = true,
                },
                bossDefeated = true,
                passiveUnlocked = true,
                rescueReadyAt = os.time() + 999999,
                injected = true,
            },
        },
    }
    SaveWriteService._ValidateCoreData(coreData, 60001)

    local account = coreData.atlas.artifact_jieshi
    assertEqual(coreData.atlas.version, 3)
    assertTrue(account.activatedGrids[1])
    assertFalse(account.activatedGrids[2])
    assertEqual(account.activatedGrids[10], nil)
    assertFalse(account.bossDefeated)
    assertFalse(account.passiveUnlocked)
    assertTrue(account.rescueReadyAt <= os.time() + 185)
    assertEqual(account.injected, nil)
    assertTrue(coreData.artifact_ch6.activatedGrids[1])
    assertFalse(coreData.artifact_ch6.activatedGrids[2])
    assertEqual(coreData.artifact_ch6.rescueReadyAt, nil)
end)

test("服务端仅在九格全满时接受双王首胜与被动关系", function()
    resetEnv()
    local SaveWriteService = require("network.SaveWriteService")
    local allActive = {
        true, true, true,
        true, true, true,
        true, true, true,
    }
    local coreData = {
        player = {},
        artifact_ch6 = {},
        atlas = {
            version = 3,
            artifact_jieshi = {
                activatedGrids = allActive,
                bossDefeated = true,
                passiveUnlocked = true,
                rescueReadyAt = 0,
            },
        },
    }
    SaveWriteService._ValidateCoreData(coreData, 60001)
    assertTrue(coreData.atlas.artifact_jieshi.bossDefeated)
    assertTrue(coreData.atlas.artifact_jieshi.passiveUnlocked)
    assertTrue(coreData.artifact_ch6.bossDefeated)
    assertTrue(coreData.artifact_ch6.passiveUnlocked)
end)

test("界匙专用UI可以创建、显示、刷新和关闭", function()
    resetEnv()
    local originalUiLib = package.loaded["urhox-libs/UI"]
    local originalArtifactUi = package.loaded["ui.ArtifactUI_ch6"]

    local function newWidget(spec)
        local widget = spec or {}
        widget.children = widget.children or {}
        function widget:AddChild(child)
            self.children[#self.children + 1] = child
        end
        function widget:ClearChildren()
            self.children = {}
        end
        function widget:Show()
            self.visible = true
        end
        function widget:Hide()
            self.visible = false
        end
        function widget:SetVisible(value)
            self.visible = value
        end
        function widget:SetDisabled(value)
            self.disabled = value
        end
        function widget:SetText(value)
            self.text = value
        end
        function widget:SetStyle(style)
            for key, value in pairs(style or {}) do self[key] = value end
        end
        function widget:FindById(id)
            if self.id == id then return self end
            for _, child in ipairs(self.children or {}) do
                if child.FindById then
                    local found = child:FindById(id)
                    if found then return found end
                end
            end
            return nil
        end
        return widget
    end

    package.loaded["urhox-libs/UI"] = {
        Panel = newWidget,
        Label = newWidget,
        Button = newWidget,
    }
    package.loaded["ui.ArtifactUI_ch6"] = nil

    local ok, err = pcall(function()
        local ArtifactUi = require("ui.ArtifactUI_ch6")
        local overlay = newWidget()
        ArtifactUi.Create(overlay)
        assertEqual(#overlay.children, 1)
        ArtifactUi.Show()
        assertTrue(ArtifactUi.IsVisible())
        assertTrue(overlay.children[1].visible == true)
        assertEqual(GameState.uiOpen, "artifact_ch6")
        ArtifactUi.Refresh()
        ArtifactUi.Hide()
        assertFalse(ArtifactUi.IsVisible())
        assertEqual(GameState.uiOpen, nil)
        ArtifactUi.Destroy()
    end)

    package.loaded["urhox-libs/UI"] = originalUiLib
    package.loaded["ui.ArtifactUI_ch6"] = originalArtifactUi
    if not ok then error(err, 0) end
end)

test("世界NPC、交互路由、主循环、面板和资源路径全部接通", function()
    resetEnv()
    local zone = require("config.ZoneData_ch6")
    local NPCWorldLoader = require("world.NPCWorldLoader")
    local runtimeNPCs = NPCWorldLoader.BuildList(zone, true)
    local found = nil
    for _, npc in ipairs(runtimeNPCs) do
        if npc.id == "ch6_divine_jieshi" then found = npc break end
    end
    assertTrue(found ~= nil)
    assertEqual(found.interactType, "divine_jieshi")
    assertEqual(found.decorationType, "divine_jieshi")
    assertEqual(found.x, 55.5)
    assertEqual(found.y, 40.5)
    assertEqual(found.zone, "narrow_trail")
    assertEqual(found.footprint.x, 55)
    assertEqual(found.footprint.y, 40)
    assertEqual(found.footprint.w, 2)
    assertEqual(found.footprint.h, 2)
    assertTrue(found.showNameplate)

    local npcDialog = readFile("scripts/ui/NPCDialog.lua")
    local main = readFile("scripts/main.lua")
    local atlasUi = readFile("scripts/ui/AtlasUI.lua")
    local characterTab = readFile("scripts/ui/CharacterTab2.lua")
    local effectRenderer = readFile("scripts/rendering/EffectRenderer.lua")
    local auraRenderer = readFile("scripts/rendering/effects/auras.lua")
    local gmConsole = readFile("scripts/ui/GMConsole.lua")
    local monsterRenderer = readFile("scripts/rendering/entities/monsters.lua")
    assertContains(npcDialog, "divine_jieshi")
    assertContains(npcDialog, "GetArtifactUI_ch6().Show()")
    assertContains(main, "NPCWorldLoader.Install")
    assertContains(readFile("scripts/ui/ArtifactUI_ch6.lua"),
        "第%s位已重铸\\n当前：生命+%d\\n生命回复+%d  福源+%d")
    assertContains(readFile("scripts/ui/ArtifactUI_ch6.lua"),
        'whiteSpace = "normal"')
    assertContains(main, "ArtifactSystem_ch6.Update(dt)")
    assertContains(main, "ArtifactSystem_ch6.UpdateBossArena")
    assertContains(main, "ArtifactUI_ch6.TryStartPendingBossFight")
    assertContains(main, "ArtifactUI_ch6.Update(dt)")
    assertContains(atlasUi, "BuildJieshiContent")
    assertContains(characterTab, "ArtifactCh6.GetPassiveDisplayDesc()")
    assertContains(effectRenderer, "RenderJieshiRescueEffects")
    assertContains(auraRenderer, "nvgRadialGradient")
    assertContains(auraRenderer, "impactGlow")
    assertContains(auraRenderer, "nvgIntersectScissor")
    assertContains(auraRenderer, "strokeRift")
    assertContains(auraRenderer, "coreAlpha")
    assertContains(auraRenderer, "particleAlpha")
    assertContains(gmConsole, "界匙神器材料包")
    assertContains(gmConsole, "give_jieshi_full")
    assertContains(gmConsole, "界匙替命表现自测")
    assertContains(gmConsole, "player.x = 54.5")
    assertContains(gmConsole, "player.y = 40.5")
    assertContains(gmConsole, "reset_jieshi_cooldown")
    assertContains(gmConsole, "神器6账号重置")
    assertContains(gmConsole, "传送到界匙")
    assertContains(monsterRenderer, "RenderArtifactCh6Aspect")
    assertContains(monsterRenderer, "魔化 · 双界王")
    assertContains(monsterRenderer, "仙化 · 双界王")

    assertTrue(fileExists("assets/" .. ArtifactCh6.FULL_IMAGE))
    assertTrue(fileExists("assets/" .. ArtifactCh6.WORLD_IMAGE))
    assertTrue(fileExists("assets/" .. ArtifactCh6.KEY_RUNE_IMAGE))
    assertTrue(fileExists("assets/" .. ArtifactCh6.RIFT_IMAGE))

    for i = 1, 9 do
        local cfg = GameConfig.CONSUMABLES[ArtifactCh6.FRAGMENT_IDS[i]]
        assertTrue(cfg ~= nil)
        assertContains(cfg.desc, "神器「界匙」处激活")
        assertFalse(cfg.desc:find("重铸功能后续开放", 1, true) ~= nil)
    end
end)

package.loaded["systems.InventorySystem"] = originalModules.inventory
package.loaded["systems.save.SaveSerializer"] = originalModules.serializer
package.loaded["systems.SaveSystem"] = originalModules.saveSystem
package.loaded["systems.AtlasSystem"] = originalModules.atlas
package.loaded["systems.CombatSystem"] = originalModules.combat
package.loaded["systems.ChallengeSystem"] = originalModules.challenge
package.loaded["systems.ArtifactSystem"] = originalModules.artifact
package.loaded["systems.ArtifactSystem_ch4"] = originalModules.artifactCh4
package.loaded["systems.ArtifactSystem_ch5"] = originalModules.artifactCh5
package.loaded["systems.ArtifactSystem_tiandi"] = originalModules.artifactTiandi
package.loaded["systems.ArtifactSystem_ch6"] = originalModules.artifactCh6
_G.SubscribeToEvent = originalSubscribeToEvent
GameState.player = originalPlayer
math.random = originalRandom
SaveState.loaded = originalSaveState.loaded
SaveState.activeSlot = originalSaveState.activeSlot
SaveState.saving = originalSaveState.saving
SaveState._retryTimer = originalSaveState.retryTimer
SaveState._disconnected = originalSaveState.disconnected

print(string.format(
    "\n[test_artifact_ch6] Result: %d passed, %d failed, %d total",
    passed, failed, total))
if failed > 0 then
    for _, err in ipairs(errors) do print("  - " .. err) end
end

return {
    passed = passed,
    failed = failed,
    total = total,
}
