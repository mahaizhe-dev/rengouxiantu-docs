package.path = package.path .. ";scripts/?.lua"

local Session = require("network.ServerSession")
local Bodies = require("network.AccountImmortalBodiesService")

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

local function assertTrue(value, message)
    if not value then error(message or "expected true") end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual))
    end
end

test("normalize creates version two account shape and deep clone", function()
    local source = { unlockedBodies = { mortal = { source = "default" } } }
    local normalized = Bodies.Normalize(source)
    normalized.unlockedBodies.mortal.source = "changed"
    assertEqual(source.unlockedBodies.mortal.source, "default")
    assertEqual(normalized.version, 2)
    assertTrue(type(normalized.bodyRewardSources) == "table")
end)

test("body grant records source and is idempotent", function()
    local first, firstResult = Bodies.PrepareBodyGrant(
        {}, "immortal_body_wanbao_liuli", "run-1", "treasure_map", 2, 100)
    assertTrue(firstResult.unlocked)
    assertTrue(not firstResult.duplicate)
    assertEqual(first.unlockedBodies.immortal_body_wanbao_liuli.firstUnlockSlot, 2)
    assertEqual(first.bodyRewardSources["run-1"].bodyId, "immortal_body_wanbao_liuli")

    local second, secondResult = Bodies.PrepareBodyGrant(
        first, "immortal_body_wanbao_liuli", "run-1", "treasure_map", 3, 200)
    assertTrue(secondResult.idempotent)
    assertTrue(secondResult.unlocked)
    assertEqual(second.version, first.version)
end)

test("different slot and run treats owned body as duplicate", function()
    local first = Bodies.PrepareBodyGrant(
        {}, "immortal_body_wanbao_liuli", "slot-1-run", "treasure_map", 1, 100)
    local second, result = Bodies.PrepareBodyGrant(
        first, "immortal_body_wanbao_liuli", "slot-2-run", "treasure_map", 2, 200)
    assertTrue(result.duplicate)
    assertTrue(not result.unlocked)
    assertEqual(second.bodyRewardSources["slot-2-run"].duplicate, true)
    assertEqual(second.unlockedBodies.immortal_body_wanbao_liuli.firstUnlockSlot, 1)
end)

test("body and cosmetic account locks are independent", function()
    Session.accountWriteLocks_ = {}
    assertTrue(Session.AcquireAccountLock(1001, Bodies.LOCK_RESOURCE))
    assertTrue(not Session.AcquireAccountLock(1001, Bodies.LOCK_RESOURCE))
    assertTrue(Session.AcquireAccountLock(1001, "account_cosmetics"))
    Session.ReleaseAllLocksForUser(1001)
    assertTrue(not Session.IsAccountLocked(1001, Bodies.LOCK_RESOURCE))
end)

print(string.format("[test_account_immortal_bodies_service] passed=%d failed=%d total=%d",
    passed, failed, total))

return { passed = passed, failed = failed, total = total }
