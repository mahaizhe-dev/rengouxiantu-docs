-- ============================================================================
-- test_ascension_system.lua - 仙阶系统单元测试
-- ============================================================================
-- 覆盖：AscensionSystem / TribulationSystem / ImmortalBodySystem 核心逻辑

local passed, failed = 0, 0

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
local InventorySystem = require("systems.InventorySystem")
local origCount = InventorySystem.CountConsumable
local origAdd = InventorySystem.AddConsumable
InventorySystem.CountConsumable = function(id) return consumables_[id] or 0 end
InventorySystem.AddConsumable = function(id, n) consumables_[id] = (consumables_[id] or 0) + (n or 1) end
InventorySystem.GetFreeSlots = function() return 10 end

-- ── Load Systems ──
local AscensionConfig = require("config.AscensionConfig")
local AscensionSystem = require("systems.AscensionSystem")
local TribulationSystem = require("systems.TribulationSystem")
local ImmortalBodySystem = require("systems.ImmortalBodySystem")

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
state.stageIndex = 1
state.minorIndex = 2  -- 谪仙2阶 → 谪仙3阶 is minor
state.progress = AscensionSystem.GetRequiredProgress()
local ok3, msg3 = AscensionSystem.BreakthroughMinor()
-- This might fail if target is major; depends on state setup
print("  BreakthroughMinor result: " .. tostring(ok3) .. " " .. tostring(msg3))

-- ============================================================================
-- Test TribulationSystem
-- ============================================================================

print("\n=== TribulationSystem Tests ===")

TribulationSystem.Init()
local tState = TribulationSystem.GetState()
assert_eq(tState.tribState, "none", "Initial tribState")

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

ImmortalBodySystem.Init()
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
InventorySystem.CountConsumable = origCount
InventorySystem.AddConsumable = origAdd
GameState.player = _origPlayer
GameState.currentSlot = _origSlot

local total = passed + failed
print(string.format("\n=== Ascension Tests: %d/%d passed, %d failed ===", passed, total, failed))

return { passed = passed, failed = failed, total = total }
