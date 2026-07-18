package.path = package.path .. ";scripts/?.lua"

local Session = require("network.ServerSession")
local Cosmetics = require("network.AccountCosmeticsService")

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

test("normalize deep-clones client data", function()
    local source = { petAppearances = { skin_a = { unlocked = true } } }
    local normalized = Cosmetics.Normalize(source)
    normalized.petAppearances.skin_a.unlocked = false
    assertTrue(source.petAppearances.skin_a.unlocked)
end)

test("skin grant records sourceRunId and is idempotent", function()
    local first, firstResult = Cosmetics.PrepareSkinGrant(
        {}, "pet_premium_chiyan", "run-1", "treasure_map", 100)
    assertTrue(firstResult.unlocked)
    assertTrue(not firstResult.duplicate)
    assertEqual(first.petAppearances.pet_premium_chiyan.sourceRunId, "run-1")

    local second, secondResult = Cosmetics.PrepareSkinGrant(
        first, "pet_premium_chiyan", "run-1", "treasure_map", 200)
    assertTrue(secondResult.idempotent)
    assertTrue(secondResult.unlocked)
    assertEqual(second.version, first.version)
end)

test("different run treats owned skin as duplicate", function()
    local first = Cosmetics.PrepareSkinGrant(
        {}, "pet_premium_biling", "run-1", "treasure_map", 100)
    local second, result = Cosmetics.PrepareSkinGrant(
        first, "pet_premium_biling", "run-2", "treasure_map", 200)
    assertTrue(result.duplicate)
    assertTrue(not result.unlocked)
    assertEqual(second.skinRewardSources["run-2"].duplicate, true)
end)

test("account locks are independent by resource and user", function()
    Session.accountWriteLocks_ = {}
    assertTrue(Session.AcquireAccountLock(1001, "account_cosmetics"))
    assertTrue(not Session.AcquireAccountLock(1001, "account_cosmetics"))
    assertTrue(Session.AcquireAccountLock(1001, "other"))
    assertTrue(Session.AcquireAccountLock(1002, "account_cosmetics"))
    Session.ReleaseAllLocksForUser(1001)
    assertTrue(not Session.IsAccountLocked(1001, "account_cosmetics"))
    assertTrue(Session.IsAccountLocked(1002, "account_cosmetics"))
    Session.ReleaseAllLocksForUser(1002)
end)

print(string.format("[test_account_cosmetics_service] passed=%d failed=%d total=%d",
    passed, failed, total))

return { passed = passed, failed = failed, total = total }
