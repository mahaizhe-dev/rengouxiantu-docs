package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local AscensionConfig = require("config.AscensionConfig")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ImmortalBodySystem = require("systems.ImmortalBodySystem")
local Player = require("entities.Player")

local passed, failed, total = 0, 0, 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  [PASS] " .. name)
    else
        failed = failed + 1
        print("  [FAIL] " .. name .. ": " .. tostring(err))
    end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual))
    end
end

local oldPlayer = GameState.player
local oldCosmetics = GameState.accountCosmetics
local oldSlot = GameState.currentSlot
local oldPlayerInitial = GameConfig.PLAYER_INITIAL
if not GameConfig.PLAYER_INITIAL then
    GameConfig.PLAYER_INITIAL = {
        level = 1,
        exp = 0,
        hp = 100,
        maxHp = 100,
        atk = 10,
        def = 5,
        speed = 3,
        hpRegen = 0,
        gold = 0,
        lingYun = 0,
        realm = "mortal",
        attackSpeed = 1,
    }
end
GameState.accountCosmetics = {}
GameState.currentSlot = 1

local bodyId = "immortal_body_wanbao_liuli"

test("growth profile matches final design", function()
    local profile = AscensionConfig.GROWTH_PROFILES[bodyId]
    assertEqual(profile.maxHp, 15)
    assertEqual(profile.atk, 3)
    assertEqual(profile.def, 2)
    assertEqual(profile.hpRegen, 0.3)
    assertEqual(profile.xianyuanGrowth.fortune.perLevel, 1)
    assertEqual(profile.xianyuanGrowth.fortune.startLevel, 1)
    assertEqual(profile.xianyuanGrowth.fortune.maxLevel, 300)
end)

test("fortune growth starts at one and caps at three hundred", function()
    assertEqual(ImmortalBodySystem.GetXianyuanBonuses(bodyId, 1).fortune, 1)
    assertEqual(ImmortalBodySystem.GetXianyuanBonuses(bodyId, 120).fortune, 120)
    assertEqual(ImmortalBodySystem.GetXianyuanBonuses(bodyId, 300).fortune, 300)
    assertEqual(ImmortalBodySystem.GetXianyuanBonuses(bodyId, 999).fortune, 300)
end)

test("switching body adds and removes derived fortune without storing it", function()
    ImmortalBodySystem.Init()
    local account = ImmortalBodySystem.GetAccountState()
    account.unlockedBodies = {
        mortal = { unlockedAt = 0, source = "default" },
        [bodyId] = { unlockedAt = 1, source = "test" },
    }
    account.bodyRewardSources = {}
    account.version = 2

    local player = Player.New(0, 0, { classId = "wanbao_test" })
    player.level = 120
    player.lingYun = 10000
    GameState.player = player

    assertEqual(player:GetTotalFortune(), 0, "mortal fortune")
    local preview = ImmortalBodySystem.PreviewSwitch(bodyId)
    assertEqual(preview.deltaFortune, 120, "preview fortune")

    local ok = ImmortalBodySystem.RequestSwitch(bodyId)
    assertEqual(ok, true)
    assertEqual(ImmortalBodySystem.ApplyPending(), true)
    player:InvalidateStatsCache()
    assertEqual(player:GetTotalFortune(), 120, "wanbao fortune")
    assertEqual(player.bodyFortune, nil, "fortune must not be stored on player")

    local okBack = ImmortalBodySystem.RequestSwitch("mortal")
    assertEqual(okBack, true)
    assertEqual(ImmortalBodySystem.ApplyPending(), true)
    player:InvalidateStatsCache()
    assertEqual(player:GetTotalFortune(), 0, "fortune removed after switch")
end)

test("account serialization preserves reward source idempotency", function()
    local account = ImmortalBodySystem.GetAccountState()
    account.bodyRewardSources = {
        ["treasure-run"] = {
            bodyId = bodyId,
            duplicate = false,
        },
    }
    account.version = 7
    local serialized = ImmortalBodySystem.SerializeAccount()
    account.bodyRewardSources = {}
    account.version = 2
    ImmortalBodySystem.DeserializeAccount(serialized)
    assertEqual(account.bodyRewardSources["treasure-run"].bodyId, bodyId)
    assertEqual(account.version, 7)
end)

GameState.player = oldPlayer
GameState.accountCosmetics = oldCosmetics
GameState.currentSlot = oldSlot
GameConfig.PLAYER_INITIAL = oldPlayerInitial

print(string.format("[test_immortal_body_wanbao] passed=%d failed=%d total=%d",
    passed, failed, total))
return { passed = passed, failed = failed, total = total }
