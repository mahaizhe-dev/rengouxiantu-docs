-- ============================================================================
-- test_ascension_system.lua - 仙阶系统单元测试
-- ============================================================================
-- 覆盖：AscensionSystem / TribulationSystem / ImmortalBodySystem 核心逻辑

local passed, failed = 0, 0

MOUSEB_LEFT = MOUSEB_LEFT or 0
MOUSEB_MIDDLE = MOUSEB_MIDDLE or 1
MOUSEB_RIGHT = MOUSEB_RIGHT or 2

local function assert_eq(actual, expected, msg)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print("[FAIL] " .. (msg or "") .. " | expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

local function assert_true(val, msg)
    if val then passed = passed + 1
    else failed = failed + 1; print("[FAIL] " .. (msg or "") .. " | expected true, got " .. tostring(val)) end
end

local function assert_false(val, msg)
    if not val then passed = passed + 1
    else failed = failed + 1; print("[FAIL] " .. (msg or "") .. " | expected false, got " .. tostring(val)) end
end

-- ── Mock GameState（保存原始值，测试结束后恢复） ──
local GameState = require("core.GameState")
local _origPlayer = GameState.player
local _origSlot = GameState.currentSlot
GameState.player = {
    level = 121,
    realm = "dacheng_4",
    lingYun = 50000,
    gold = 5000000,
    maxHp = 10000,
    atk = 3000,
    def = 2000,
    hpRegen = 100,
    hp = 10000,
    alive = true,
    GetTotalMaxHp = function(self) return self.maxHp end,
    GetTotalDef = function(self) return self.def end,
    TakeDamage = function(self, dmg) self.hp = self.hp - dmg end,
    SetMoveDirection = function() end,
    _statsCacheFrame = 0,
}
GameState.currentSlot = 1

-- ── Mock InventorySystem ──
local consumables_ = {}
local _origInventorySystem = package.loaded["systems.InventorySystem"]
local InventorySystem = {}
InventorySystem.CountConsumable = function(id) return consumables_[id] or 0 end
InventorySystem.AddConsumable = function(id, n) consumables_[id] = (consumables_[id] or 0) + (n or 1) end
InventorySystem.ConsumeConsumable = function(id, n)
    n = n or 1
    if (consumables_[id] or 0) < n then return false end
    consumables_[id] = consumables_[id] - n
    return true
end
InventorySystem.GetFreeSlots = function() return 10 end
package.loaded["systems.InventorySystem"] = InventorySystem

local _origSaveSession = package.loaded["systems.save.SaveSession"]
package.loaded["systems.save.SaveSession"] = {
    MarkDirty = function() end,
}

-- ── Load Systems ──
local AscensionConfig = require("config.AscensionConfig")
local GameConfig = require("config.GameConfig")
local AscensionSystem = require("systems.AscensionSystem")
local TribulationSystem = require("systems.TribulationSystem")
local ImmortalBodySystem = require("systems.ImmortalBodySystem")
AscensionConfig.EnsureRealmsRegistered()

-- ============================================================================
-- Test AscensionConfig level contract
-- ============================================================================

print("\n=== AscensionConfig Level Contract Tests ===")
assert_eq(AscensionConfig.ASCENSION_REWARDS[1].requiredLevel, 120, "谪仙1阶 requiredLevel")
assert_eq(AscensionConfig.ASCENSION_REWARDS[2].requiredLevel, 122, "谪仙2阶 requiredLevel")
assert_eq(AscensionConfig.ASCENSION_REWARDS[9].requiredLevel, 136, "谪仙9阶 requiredLevel")
assert_eq(AscensionConfig.ASCENSION_REWARDS[1].maxLevel, 140, "谪仙1阶 maxLevel")
assert_eq(AscensionConfig.ASCENSION_REWARDS[9].maxLevel, 140, "谪仙9阶 maxLevel follows major stage")
assert_eq(AscensionConfig.ASCENSION_REWARDS[10].requiredLevel, 140, "人仙1阶 requiredLevel")
assert_eq(AscensionConfig.ASCENSION_REWARDS[18].requiredLevel, 156, "人仙9阶 requiredLevel")
assert_eq(AscensionConfig.ASCENSION_REWARDS[18].maxLevel, 160, "人仙9阶 maxLevel follows major stage")
assert_eq(GameConfig.REALMS["asc_9"].requiredLevel, 136, "asc_9 registered requiredLevel")
assert_eq(GameConfig.REALMS["asc_9"].maxLevel, 140, "asc_9 registered maxLevel")

-- ============================================================================
-- Test AscensionSystem
-- ============================================================================

print("\n=== AscensionSystem Tests ===")

-- Init
AscensionSystem.Init()
assert_true(AscensionSystem.IsEnabled(), "IsEnabled at Lv121")

-- ConsumePill without material
consumables_["one_turn_tribulation_pill"] = 0
local ok, msg = AscensionSystem.ConsumePill()
assert_false(ok, "ConsumePill without material should fail")

-- ConsumePill with material
consumables_["one_turn_tribulation_pill"] = 50
local ok2, result = AscensionSystem.ConsumePill()
assert_true(ok2, "ConsumePill with material should succeed")
local state = AscensionSystem.GetState()
assert_true(state.progress > 0, "Progress should increase after consuming pill")
assert_eq(consumables_["one_turn_tribulation_pill"], 49, "Material count should decrease")

-- Fill progress
local required = AscensionSystem.GetRequiredProgress()
state.progress = required
assert_true(AscensionSystem.IsProgressFull(), "IsProgressFull when progress == required")

-- BreakthroughMinor (target should be minor)
-- First we need to set up for a minor target
GameState.player.realm = "asc_1"
GameState.player.level = 121
state.totalIndex = 1
state.stageIndex = 1
state.minorIndex = 1  -- 当前谪仙1阶，目标谪仙2阶 requiredLevel=122
state.progress = AscensionSystem.GetRequiredProgress()
local ok3, msg3 = AscensionSystem.BreakthroughMinor()
assert_false(ok3, "BreakthroughMinor below requiredLevel should fail")
assert_eq(msg3, "等级不足 (需要 Lv.122)", "BreakthroughMinor level gate message")
GameState.player.realm = "dacheng_4"
GameState.player.level = 121

-- ============================================================================
-- Test TribulationSystem
-- ============================================================================

print("\n=== TribulationSystem Tests ===")

TribulationSystem.Init()
local tState = TribulationSystem.GetState()
assert_eq(tState.tribState, "none", "Initial tribState")

-- CanEnter rejects major target below requiredLevel
AscensionSystem.Init()
state = AscensionSystem.GetState()
GameState.player.realm = "asc_9"
GameState.player.level = 139
state.totalIndex = 9
state.stageIndex = 1
state.minorIndex = 9
state.progress = AscensionConfig.PROGRESS_PER_MINOR[1]  -- 人仙1阶（渡劫）需求
local canEnterLow, enterLowMsg = TribulationSystem.CanEnter()
assert_false(canEnterLow, "CanEnter below major requiredLevel should fail")
assert_eq(enterLowMsg, "等级不足 (需要 Lv.140)", "CanEnter level gate message")
GameState.player.realm = "dacheng_4"
GameState.player.level = 121

-- CanEnter requires progress full + major target
-- Set up for major breakthrough
AscensionSystem.Init()
state = AscensionSystem.GetState()
state.progress = AscensionConfig.PROGRESS_PER_MINOR[1]  -- 首阶（渡劫）需求
state.stageIndex = 0
state.minorIndex = 0

local canEnter, enterMsg = TribulationSystem.CanEnter()
print("  CanEnter: " .. tostring(canEnter) .. " msg=" .. tostring(enterMsg))

-- Enter
if canEnter then
    local ok4, msg4 = TribulationSystem.Enter()
    assert_true(ok4, "Enter should succeed")
    assert_eq(TribulationSystem.GetState().tribState, "inProgress", "tribState after Enter")
    assert_true(TribulationSystem.IsInProgress(), "IsInProgress after Enter")

    -- OnSuccess
    TribulationSystem.OnSuccess()
    assert_eq(TribulationSystem.GetState().tribState, "none", "tribState after OnSuccess")
end

-- OnFail + cooldown
TribulationSystem.Init()
tState = TribulationSystem.GetState()
tState.tribState = "inProgress"
TribulationSystem.OnFail("fail")
assert_eq(tState.tribState, "cooldown", "tribState after OnFail")
assert_true(TribulationSystem.GetCooldownRemaining() > 0, "Cooldown should be positive")

-- PostLoadCheck: inProgress → disconnect fail
TribulationSystem.Init()
tState = TribulationSystem.GetState()
tState.tribState = "inProgress"
TribulationSystem.PostLoadCheck()
assert_eq(tState.tribState, "cooldown", "PostLoadCheck inProgress → cooldown")
assert_eq(tState.lastResult, "disconnect", "PostLoadCheck sets disconnect")

-- ============================================================================
-- Test ImmortalBodySystem
-- ============================================================================

print("\n=== ImmortalBodySystem Tests ===")

GameState.player.realm = "dacheng_4"
GameState.player.level = 121
GameState.player.maxHp = 10000
GameState.player.atk = 3000
GameState.player.def = 2000
GameState.player.hpRegen = 100
GameState.player.hp = 10000
GameState.player._statsCacheFrame = 0

ImmortalBodySystem.Init()
local ibAccountState = ImmortalBodySystem.GetAccountState()
ibAccountState.unlockedBodies = {
    mortal = { unlockedAt = 0, source = "default" },
}
ibAccountState.version = 1
assert_eq(ImmortalBodySystem.GetActiveBodyId(), "mortal", "Initial body is mortal")
assert_false(ImmortalBodySystem.IsUnlocked("immortal_body_1"), "Body 1 not unlocked initially")

-- Unlock
ImmortalBodySystem.UnlockBody("immortal_body_1", "test")
assert_true(ImmortalBodySystem.IsUnlocked("immortal_body_1"), "Body 1 unlocked after UnlockBody")

local list = ImmortalBodySystem.GetUnlockedList()
assert_eq(#list, 2, "2 bodies unlocked (mortal + immortal_body_1)")

-- PreviewSwitch
local preview = ImmortalBodySystem.PreviewSwitch("immortal_body_1")
assert_true(preview ~= nil, "PreviewSwitch should return data")
if preview then
    -- Level 121: mult = 120
    -- immortal_body_1: maxHp=25, mortal: maxHp=15 → delta = 10*120 = 1200
    assert_eq(preview.deltaHp, (25 - 15) * 120, "deltaHp = 1200")
    assert_eq(preview.deltaAtk, (5 - 3) * 120, "deltaAtk = 240")
    assert_eq(preview.deltaDef, (3 - 2) * 120, "deltaDef = 120")
end

-- RequestSwitch
GameState.player.lingYun = 50000
local ok5, msg5 = ImmortalBodySystem.RequestSwitch("immortal_body_1")
assert_true(ok5, "RequestSwitch should succeed")
assert_eq(GameState.player.lingYun, 50000 - AscensionConfig.IMMORTAL_BODY_SWITCH_COST_LINGYUN, "LingYun deducted")

local charState = ImmortalBodySystem.GetCharState()
assert_true(charState.pending ~= nil, "Pending should be set")
assert_eq(charState.pending.targetBodyId, "immortal_body_1", "Pending target")

-- ApplyPending
ImmortalBodySystem.ApplyPending()
assert_eq(ImmortalBodySystem.GetActiveBodyId(), "immortal_body_1", "Active body after apply")
assert_eq(charState.pending, nil, "Pending cleared after apply")
-- Check stats adjustment
assert_eq(GameState.player.maxHp, 10000 + 1200, "maxHp adjusted after switch")

-- ============================================================================
-- Test Serialization round-trip
-- ============================================================================

print("\n=== Serialization Tests ===")

-- AscensionSystem
local ascSer = AscensionSystem.Serialize()
AscensionSystem.Init()
AscensionSystem.Deserialize(ascSer)
assert_eq(AscensionSystem.GetState().progress, ascSer.progress, "AscensionSystem round-trip")

-- TribulationSystem
local tribSer = TribulationSystem.Serialize()
TribulationSystem.Init()
TribulationSystem.Deserialize(tribSer)
assert_eq(TribulationSystem.GetState().tribState, tribSer.tribState, "TribulationSystem round-trip")

-- ImmortalBodySystem
local ibCharSer = ImmortalBodySystem.SerializeCharacter()
ImmortalBodySystem.Init()
ImmortalBodySystem.DeserializeCharacter(ibCharSer)
assert_eq(ImmortalBodySystem.GetActiveBodyId(), "immortal_body_1", "ImmortalBody char round-trip")

-- ============================================================================
-- Summary
-- ============================================================================

-- Restore mocks
package.loaded["systems.InventorySystem"] = _origInventorySystem
package.loaded["systems.save.SaveSession"] = _origSaveSession
GameState.player = _origPlayer
GameState.currentSlot = _origSlot

local total = passed + failed
print(string.format("\n=== Ascension Tests: %d/%d passed, %d failed ===", passed, total, failed))

return { passed = passed, failed = failed, total = total }
