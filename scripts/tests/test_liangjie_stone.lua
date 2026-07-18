-- ============================================================================
-- test_liangjie_stone.lua - 两界阵石完整契约与事务回滚测试
-- 不调用 InventorySystem.Init/SetManager，不触碰真实背包单例。
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local passed, failed, total = 0, 0, 0
local errors = {}

local function assertTrue(value, message)
    if not value then error(message or "expected true", 2) end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
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

local function readFile(path)
    local file = assert(io.open(path, "rb"), "cannot open " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local GameConfig = require("config.GameConfig")
local Player = require("entities.Player")
local SaveState = require("systems.save.SaveState")
local Config = require("config.LiangjieStoneConfig")
local SaveMigrations = require("systems.save.SaveMigrations")
local SaveDTO = require("systems.save.SaveDTO")
local ZoneData = require("config.ZoneData_ch6")
local SaveWriteService = require("network.SaveWriteService")

local originalPlayer = GameState.player
local originalSaveState = {
    loaded = SaveState.loaded,
    activeSlot = SaveState.activeSlot,
    saving = SaveState.saving,
    retryTimer = SaveState._retryTimer,
    disconnected = SaveState._disconnected,
}
local originalInventorySystem = package.loaded["systems.InventorySystem"]
local originalSaveSerializer = package.loaded["systems.save.SaveSerializer"]
local originalSaveSystem = package.loaded["systems.SaveSystem"]
local originalStoneSystem = package.loaded["systems.LiangjieStoneSystem"]

local tokenCount = 0
local saveOk = true
local saveCalls = 0
local titleState = { unlocked = {} }

local InventoryMock = {}
function InventoryMock.CountUnlockedConsumable(consumableId)
    if consumableId ~= Config.CURRENCY_ID then return 0 end
    return tokenCount
end
function InventoryMock.ConsumeConsumable(consumableId, amount)
    if consumableId ~= Config.CURRENCY_ID or tokenCount < amount then return false end
    tokenCount = tokenCount - amount
    return true
end

local SaveSerializerMock = {}
function SaveSerializerMock.SerializeInventory()
    return { tokenCount = tokenCount }
end
function SaveSerializerMock.DeserializeInventory(data)
    tokenCount = data and data.tokenCount or 0
end
function SaveSerializerMock.SerializeTitles()
    local unlocked = {}
    for titleId, value in pairs(titleState.unlocked or {}) do
        unlocked[titleId] = value
    end
    return { unlocked = unlocked }
end
function SaveSerializerMock.DeserializeTitles(data)
    titleState = { unlocked = {} }
    for titleId, value in pairs(data and data.unlocked or {}) do
        titleState.unlocked[titleId] = value
    end
end

local SaveSystemMock = {}
function SaveSystemMock.Save(callback)
    saveCalls = saveCalls + 1
    if callback then
        callback(saveOk, saveOk and "ok" or "forced_fail")
    end
end

package.loaded["systems.InventorySystem"] = InventoryMock
package.loaded["systems.save.SaveSerializer"] = SaveSerializerMock
package.loaded["systems.SaveSystem"] = SaveSystemMock
package.loaded["systems.LiangjieStoneSystem"] = nil

local StoneSystem = require("systems.LiangjieStoneSystem")

local function NewPlayer()
    return {
        level = 121,
        exp = 0,
        maxHp = 1000,
        atk = 100,
        def = 50,
        hpRegen = 5,
        hp = 1000,
        realm = "zhexian",
        alive = true,
        liangjieStoneAtk = 0,
        liangjieStoneDef = 0,
        liangjieStoneMaxHp = 0,
        liangjieStoneHpRegen = 0,
        GainExp = function(self, amount)
            self.exp = self.exp + amount
        end,
        InvalidateStatsCache = function(self)
            self._statsCacheFrame = -1
        end,
    }
end

local function ResetEnv(tokens, shouldSave)
    tokenCount = tokens or 0
    saveOk = shouldSave ~= false
    saveCalls = 0
    titleState = { unlocked = {} }
    GameState.player = NewPlayer()
    SaveState.loaded = true
    SaveState.activeSlot = 1
    SaveState.saving = false
    SaveState._retryTimer = nil
    SaveState._disconnected = false
    StoneSystem.Reset()
end

local function FindStoneNpc(stoneId)
    for _, npc in ipairs(ZoneData.NPCs or {}) do
        if npc.interactType == StoneSystem.INTERACT_TYPE and npc.stoneId == stoneId then
            return npc
        end
    end
    return nil
end

print("--- Liangjie stone contract ---")

test("30级价格按每三等级一档且总消耗正确", function()
    assertEqual(Config.MAX_LEVEL, 30)
    assertEqual(Config.GetUpgradeCost(1), 500)
    assertEqual(Config.GetUpgradeCost(3), 500)
    assertEqual(Config.GetUpgradeCost(4), 750)
    assertEqual(Config.GetUpgradeCost(27), 2500)
    assertEqual(Config.GetUpgradeCost(28), 3000)
    assertEqual(Config.GetUpgradeCost(30), 3000)
    assertEqual(Config.GetMaxUpgradeCost(), 49500)
    assertEqual(Config.GetMaxUpgradeCost() + Config.ACTIVATION_COST, 50500)
end)

test("四属性每级与满级加成符合定稿", function()
    assertEqual(Config.STONES.tianfeng.bonusPerLevel, 5)
    assertEqual(Config.GetTotalBonus("tianfeng", 30), 150)
    assertEqual(Config.STONES.xuanbi.bonusPerLevel, 4)
    assertEqual(Config.GetTotalBonus("xuanbi", 30), 120)
    assertEqual(Config.STONES.houtu.bonusPerLevel, 50)
    assertEqual(Config.GetTotalBonus("houtu", 30), 1500)
    assertEqual(Config.STONES.huiyuan.bonusPerLevel, 5)
    assertEqual(Config.GetTotalBonus("huiyuan", 30), 150)
end)

test("四个阵石NPC部署在指定坐标并引用PNG", function()
    local expected = {
        xuanbi = { 32, 32 },
        tianfeng = { 49, 32 },
        houtu = { 32, 49 },
        huiyuan = { 49, 49 },
    }
    local count = 0
    for stoneId, pos in pairs(expected) do
        local npc = FindStoneNpc(stoneId)
        assertTrue(npc ~= nil, stoneId .. " NPC missing")
        assertEqual(npc.x, pos[1], stoneId .. " x")
        assertEqual(npc.y, pos[2], stoneId .. " y")
        assertEqual(npc.decorationType, "liangjie_stone")
        assertEqual(npc.image, Config.IMAGE)
        assertTrue(npc.isObject == true and npc.showNameplate == true)
        count = count + 1
    end
    assertEqual(count, 4)

    local asset = io.open("assets/" .. Config.IMAGE, "rb")
    assertTrue(asset ~= nil, "阵石PNG资源不存在")
    if asset then asset:close() end
end)

test("运行时NPC复制保留阵石交互与姓名板字段", function()
    local NPCWorldLoader = require("world.NPCWorldLoader")
    local runtimeNPCs = NPCWorldLoader.BuildList(ZoneData, true)
    local byId = NPCWorldLoader.IndexById(runtimeNPCs)
    local runtimeStone = byId.ch6_liangjie_stone_xuanbi
    assertTrue(runtimeStone ~= nil, "runtime stone NPC missing")
    assertEqual(runtimeStone.stoneId, "xuanbi")
    assertEqual(runtimeStone.imageAspect, 768 / 515)
    assertEqual(runtimeStone.nameplateOffset, 1.72)

    local dialog = readFile("scripts/ui/NPCDialog.lua")
    assertTrue(dialog:find("GetLiangjieStoneUI().Show(npc.stoneId)", 1, true) ~= nil,
        "liangjie_stone route must open its dedicated UI")
end)

test("NPC近身查找与交互路由把stoneId传给阵石面板", function()
    local originalNPCDialog = package.loaded["ui.NPCDialog"]
    local originalForgeUI = package.loaded["ui.ForgeUI"]
    local originalUILib = package.loaded["urhox-libs/UI"]
    local originalDungeonClient = package.loaded["network.DungeonClient"]
    local originalStoneUI = package.loaded["ui.LiangjieStoneUI"]
    local originalNPCs = GameState.npcs
    local openedStoneId = nil

    package.loaded["ui.NPCDialog"] = nil
    package.loaded["ui.ForgeUI"] = {
        IsVisible = function() return false end,
        Hide = function() end,
        Destroy = function() end,
    }
    package.loaded["urhox-libs/UI"] = {}
    package.loaded["network.DungeonClient"] = {
        IsDungeonMode = function() return false end,
    }
    package.loaded["ui.LiangjieStoneUI"] = {
        Show = function(stoneId) openedStoneId = stoneId end,
    }

    local ok, err = pcall(function()
        local NPCDialog = require("ui.NPCDialog")
        GameState.npcs = {
            {
                id = "ch6_liangjie_stone_xuanbi",
                x = 32,
                y = 32,
                interactType = "liangjie_stone",
                stoneId = "xuanbi",
            },
        }

        local nearby = NPCDialog.FindNearbyNPC(32.5, 32, 2)
        assertTrue(nearby ~= nil, "nearby stone NPC must be found")
        assertEqual(nearby.stoneId, "xuanbi")
        NPCDialog.Show(nearby)
        assertEqual(openedStoneId, "xuanbi")
    end)

    GameState.npcs = originalNPCs
    package.loaded["ui.NPCDialog"] = originalNPCDialog
    package.loaded["ui.ForgeUI"] = originalForgeUI
    package.loaded["urhox-libs/UI"] = originalUILib
    package.loaded["network.DungeonClient"] = originalDungeonClient
    package.loaded["ui.LiangjieStoneUI"] = originalStoneUI
    if not ok then error(err, 0) end
end)

test("阵石专用UI可以创建并显示激活面板", function()
    local originalUILib = package.loaded["urhox-libs/UI"]
    local originalStoneUI = package.loaded["ui.LiangjieStoneUI"]

    local function NewWidget(spec)
        local widget = spec or {}
        widget.children = widget.children or {}
        function widget:AddChild(child)
            self.children[#self.children + 1] = child
        end
        function widget:RemoveAllChildren()
            self.children = {}
        end
        function widget:Show()
            self.visible = true
        end
        function widget:Hide()
            self.visible = false
        end
        function widget:Destroy()
            self.destroyed = true
        end
        return widget
    end

    local function CollectTexts(widget, out)
        out = out or {}
        if widget.text then out[#out + 1] = widget.text end
        for _, child in ipairs(widget.children or {}) do
            CollectTexts(child, out)
        end
        return out
    end

    package.loaded["urhox-libs/UI"] = {
        Panel = NewWidget,
        Label = NewWidget,
        Button = NewWidget,
    }
    package.loaded["ui.LiangjieStoneUI"] = nil

    local ok, err = pcall(function()
        ResetEnv(0, true)
        local StoneUI = require("ui.LiangjieStoneUI")
        local overlay = NewWidget()

        StoneUI.Create(overlay)
        assertEqual(#overlay.children, 1, "stone panel must attach to overlay")
        StoneUI.Show("xuanbi")
        assertTrue(StoneUI.IsVisible(), "stone UI must become visible")
        assertTrue(overlay.children[1].visible == true, "root panel must be shown")
        assertEqual(#overlay.children[1].children, 1, "activation content must be built")
        assertEqual(GameState.uiOpen, "liangjie_stone")

        StoneUI.ShowActivationSuccessPopup("xuanbi", {
            configuredExp = Config.ACTIVATION_EXP_REWARD,
            actualExp = Config.ACTIVATION_EXP_REWARD,
            levelBefore = 121,
            levelAfter = 122,
        })
        assertTrue(StoneUI.IsResultPopupVisible(), "activation success popup must be visible")
        assertEqual(#overlay.children, 2, "result popup must attach above stone panel")
        local popupText = table.concat(CollectTexts(overlay.children[2]), "|")
        assertTrue(popupText:find("经验实际增加", 1, true) ~= nil,
            "success popup must confirm actual exp")
        assertTrue(popupText:find("Lv.121", 1, true) ~= nil
            and popupText:find("Lv.122", 1, true) ~= nil,
            "success popup must show level change")

        StoneUI.HideResultPopup()
        assertTrue(not StoneUI.IsResultPopupVisible(), "result popup must close cleanly")
        StoneUI.Hide()
        assertTrue(not StoneUI.IsVisible(), "stone UI must hide cleanly")
        StoneUI.Destroy()
    end)

    package.loaded["urhox-libs/UI"] = originalUILib
    package.loaded["ui.LiangjieStoneUI"] = originalStoneUI
    if not ok then error(err, 0) end
end)

test("读档规范化等级并由档案覆盖派生属性", function()
    ResetEnv(0, true)
    GameState.player.liangjieStoneAtk = 999
    GameState.player.liangjieStoneDef = 999
    GameState.player.liangjieStoneMaxHp = 999
    GameState.player.liangjieStoneHpRegen = 999

    StoneSystem.Deserialize({
        version = 1,
        stones = {
            xuanbi = { activated = true, level = 99, activationRewardClaimed = false },
            tianfeng = { activated = false, level = 30, activationRewardClaimed = true },
            houtu = { activated = true, level = 30 },
            huiyuan = { activated = true, level = 8 },
            injected = { activated = true, level = 30 },
        },
    })

    assertEqual(StoneSystem.GetLevel("xuanbi"), 30)
    assertEqual(StoneSystem.GetLevel("tianfeng"), 0)
    assertEqual(StoneSystem.GetStoneState("houtu").activationRewardClaimed, true)
    assertEqual(GameState.player.liangjieStoneAtk, 0)
    assertEqual(GameState.player.liangjieStoneDef, 120)
    assertEqual(GameState.player.liangjieStoneMaxHp, 1500)
    assertEqual(GameState.player.liangjieStoneHpRegen, 40)
    assertEqual(StoneSystem.GetNameplateText("xuanbi"), "MAX")
    assertEqual(StoneSystem.GetNameplateText("tianfeng"), "未激活")
    assertEqual(StoneSystem.GetNameplateText("huiyuan"), "Lv.8")
    assertTrue(StoneSystem.Serialize().stones.injected == nil)
end)

test("首次激活扣1000谪仙令并只发一次经验", function()
    ResetEnv(2000, true)
    local callbackOk = nil
    local started = StoneSystem.Activate("tianfeng", function(ok)
        callbackOk = ok
    end)

    assertTrue(started)
    assertEqual(callbackOk, true)
    assertEqual(saveCalls, 1)
    assertEqual(tokenCount, 1000)
    assertEqual(GameState.player.exp, Config.ACTIVATION_EXP_REWARD)
    assertEqual(StoneSystem.GetNameplateText("tianfeng"), "Lv.0")
    assertEqual(StoneSystem.GetStoneState("tianfeng").activationRewardClaimed, true)

    local startedAgain = StoneSystem.Activate("tianfeng")
    assertTrue(not startedAgain)
    assertEqual(tokenCount, 1000)
    assertEqual(GameState.player.exp, Config.ACTIVATION_EXP_REWARD)
    assertEqual(saveCalls, 1)
end)

test("真实Player GainExp路径实际增加1000万经验并回传到账明细", function()
    ResetEnv(1000, true)
    local player = Player.New(0, 0)
    player.level = 121
    player.realm = "dujie_1"
    player.exp = GameConfig.EXP_TABLE[121] + 12345
    GameState.player = player
    StoneSystem.ApplyAllBonuses()

    local expBefore = player.exp
    local levelBefore = player.level
    local expEventAmount = nil
    local unsubscribe = EventBus.On("player_exp_gain", function(amount)
        expEventAmount = amount
    end)
    local callbackOk = nil
    local details = nil

    local started = StoneSystem.Activate("houtu", function(ok, _, resultDetails)
        callbackOk = ok
        details = resultDetails
    end)
    unsubscribe()

    assertTrue(started)
    assertEqual(callbackOk, true)
    assertEqual(player.exp - expBefore, Config.ACTIVATION_EXP_REWARD)
    assertEqual(player.level, levelBefore)
    assertEqual(expEventAmount, Config.ACTIVATION_EXP_REWARD)
    assertTrue(details ~= nil)
    assertEqual(details.configuredExp, Config.ACTIVATION_EXP_REWARD)
    assertEqual(details.actualExp, Config.ACTIVATION_EXP_REWARD)
    assertEqual(details.expBefore, expBefore)
    assertEqual(details.expAfter, player.exp)
    assertEqual(details.levelBefore, levelBefore)
    assertEqual(details.levelAfter, player.level)
end)

test("激活保存失败时令牌经验与状态完整回滚", function()
    ResetEnv(1000, false)
    GameState.player.exp = 12345
    local callbackOk = true
    local started = StoneSystem.Activate("xuanbi", function(ok)
        callbackOk = ok
    end)

    assertTrue(started)
    assertEqual(callbackOk, false)
    assertEqual(saveCalls, 1)
    assertEqual(tokenCount, 1000)
    assertEqual(GameState.player.exp, 12345)
    assertEqual(StoneSystem.IsActivated("xuanbi"), false)
    assertEqual(GameState.player.liangjieStoneDef, 0)
end)

test("经验跨多级后保存失败会回滚基础属性称号与技能", function()
    local originalSkillSystem = package.loaded["systems.SkillSystem"]
    local SkillSystemMock = {
        unlockedSkills = { old_skill = true },
        equippedSkills = { "old_skill" },
    }
    package.loaded["systems.SkillSystem"] = SkillSystemMock

    local ok, err = pcall(function()
        ResetEnv(1000, false)
        local player = GameState.player
        player.level = 1
        player.realm = "mortal"
        player.exp = 100
        player.maxHp = 1000
        player.atk = 100
        player.def = 50
        player.hpRegen = 5
        player.hp = 900
        player.GainExp = function(self, amount)
            self.exp = self.exp + amount
            self.level = self.level + 3
            self.maxHp = self.maxHp + 45
            self.atk = self.atk + 9
            self.def = self.def + 6
            self.hpRegen = self.hpRegen + 0.9
            self.hp = self.maxHp
            titleState.unlocked.temp_level_title = true
            SkillSystemMock.unlockedSkills.temp_skill = true
            SkillSystemMock.equippedSkills[1] = "temp_skill"
        end

        local started = StoneSystem.Activate("tianfeng")
        assertTrue(started)
        assertEqual(player.level, 1)
        assertEqual(player.realm, "mortal")
        assertEqual(player.exp, 100)
        assertEqual(player.maxHp, 1000)
        assertEqual(player.atk, 100)
        assertEqual(player.def, 50)
        assertEqual(player.hpRegen, 5)
        assertEqual(player.hp, 900)
        assertTrue(titleState.unlocked.temp_level_title == nil)
        assertTrue(SkillSystemMock.unlockedSkills.temp_skill == nil)
        assertEqual(SkillSystemMock.equippedSkills[1], "old_skill")
        assertEqual(tokenCount, 1000)
        assertTrue(not StoneSystem.IsActivated("tianfeng"))
    end)

    package.loaded["systems.SkillSystem"] = originalSkillSystem
    if not ok then error(err, 0) end
end)

test("升级成功写入属性且保存失败可回滚", function()
    ResetEnv(2000, true)
    StoneSystem.Deserialize({
        stones = {
            xuanbi = { activated = true, level = 0 },
        },
    })

    local started = StoneSystem.Upgrade("xuanbi")
    assertTrue(started)
    assertEqual(tokenCount, 1500)
    assertEqual(StoneSystem.GetLevel("xuanbi"), 1)
    assertEqual(GameState.player.liangjieStoneDef, 4)

    saveOk = false
    local secondStarted = StoneSystem.Upgrade("xuanbi")
    assertTrue(secondStarted)
    assertEqual(tokenCount, 1500)
    assertEqual(StoneSystem.GetLevel("xuanbi"), 1)
    assertEqual(GameState.player.liangjieStoneDef, 4)
end)

test("服务端仅按规范阵石等级重算四项派生属性", function()
    local coreData = {
        player = {
            liangjieStoneAtk = 999,
            liangjieStoneDef = 999,
            liangjieStoneMaxHp = 999,
            liangjieStoneHpRegen = 999,
        },
        liangjieStones = {
            version = 99,
            stones = {
                xuanbi = { activated = true, level = 30.9, activationRewardClaimed = false },
                tianfeng = { activated = true, level = 30 },
                houtu = { activated = true, level = 30 },
                huiyuan = { activated = true, level = 30 },
                injected = { activated = true, level = 30 },
            },
        },
    }

    SaveWriteService._ValidateCoreData(coreData, 20001)

    assertEqual(coreData.liangjieStones.version, 1)
    assertEqual(coreData.liangjieStones.stones.xuanbi.level, 30)
    assertEqual(coreData.liangjieStones.stones.xuanbi.activationRewardClaimed, true)
    assertTrue(coreData.liangjieStones.stones.injected == nil)
    assertEqual(coreData.player.liangjieStoneAtk, 150)
    assertEqual(coreData.player.liangjieStoneDef, 120)
    assertEqual(coreData.player.liangjieStoneMaxHp, 1500)
    assertEqual(coreData.player.liangjieStoneHpRegen, 150)
end)

test("服务端缺档时清除伪造阵石派生属性", function()
    local coreData = {
        player = {
            liangjieStoneAtk = 150,
            liangjieStoneDef = 120,
            liangjieStoneMaxHp = 1500,
            liangjieStoneHpRegen = 150,
        },
    }
    SaveWriteService._ValidateCoreData(coreData, 20002)
    assertEqual(coreData.player.liangjieStoneAtk, 0)
    assertEqual(coreData.player.liangjieStoneDef, 0)
    assertEqual(coreData.player.liangjieStoneMaxHp, 0)
    assertEqual(coreData.player.liangjieStoneHpRegen, 0)
    assertTrue(type(coreData.liangjieStones.stones) == "table")
end)

test("v35旧档迁移为v36完整四石默认档案", function()
    local migrated, err = SaveMigrations.MigrateSaveData({
        version = 35,
        player = { level = 121, realm = "zhexian" },
    })
    assertTrue(migrated ~= nil, tostring(err))
    assertEqual(migrated.version, 36)
    assertEqual(migrated.liangjieStones.version, 1)
    for _, stoneId in ipairs(Config.STONE_ORDER) do
        local state = migrated.liangjieStones.stones[stoneId]
        assertTrue(state ~= nil)
        assertEqual(state.activated, false)
        assertEqual(state.level, 0)
        assertEqual(state.activationRewardClaimed, false)
    end
end)

test("SaveDTO与代码入口包含两界阵石字段", function()
    assertEqual(SaveDTO.GetDTOFieldCount(), 32)
    assertEqual(SaveDTO.GetSchemaFieldCount(), 40)
    assertTrue(SaveDTO.IsDTOField("liangjieStones"))

    local persistence = readFile("scripts/systems/save/SavePersistence.lua")
    local loader = readFile("scripts/systems/save/SaveLoader.lua")
    local player = readFile("scripts/entities/Player.lua")
    local npcRenderer = readFile("scripts/rendering/entities/npcs.lua")
    local ui = readFile("scripts/ui/LiangjieStoneUI.lua")

    assertTrue(persistence:find("liangjieStones", 1, true) ~= nil)
    assertTrue(loader:find("Deserialize(saveData.liangjieStones)", 1, true) ~= nil)
    assertTrue(player:find("(self.liangjieStoneAtk or 0)", 1, true) ~= nil)
    assertTrue(player:find("(self.liangjieStoneDef or 0)", 1, true) ~= nil)
    assertTrue(player:find("(self.liangjieStoneMaxHp or 0)", 1, true) ~= nil)
    assertTrue(player:find("(self.liangjieStoneHpRegen or 0)", 1, true) ~= nil)
    assertTrue(npcRenderer:find("GetNameplateText", 1, true) ~= nil)
    assertTrue(ui:find("激活阵石", 1, true) ~= nil)
    assertTrue(ui:find("经验实际增加 +", 1, true) ~= nil)
    assertTrue(ui:find("ShowActivationSuccessPopup", 1, true) ~= nil)
end)

package.loaded["systems.InventorySystem"] = originalInventorySystem
package.loaded["systems.save.SaveSerializer"] = originalSaveSerializer
package.loaded["systems.SaveSystem"] = originalSaveSystem
package.loaded["systems.LiangjieStoneSystem"] = originalStoneSystem
GameState.player = originalPlayer
SaveState.loaded = originalSaveState.loaded
SaveState.activeSlot = originalSaveState.activeSlot
SaveState.saving = originalSaveState.saving
SaveState._retryTimer = originalSaveState.retryTimer
SaveState._disconnected = originalSaveState.disconnected

print(string.format(
    "--- Liangjie stone contract: %d/%d passed, %d failed ---",
    passed, total, failed
))

return { passed = passed, failed = failed, total = total, errors = errors }
