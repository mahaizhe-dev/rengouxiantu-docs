-- ============================================================================
-- test_ch2_map_contract.lua - Chapter 2 map spawn and patrol contract checks
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local fortress = require("config.zones.chapter2.fortress_e")

local passed, failed, total = 0, 0, 0

local function fail(desc, detail)
    failed = failed + 1
    print("  FAIL: " .. desc .. (detail and (" - " .. detail) or ""))
end

local function assertTrue(cond, desc, detail)
    total = total + 1
    if cond then passed = passed + 1 else fail(desc, detail) end
end

local function assertEqual(actual, expected, desc)
    total = total + 1
    if actual == expected then
        passed = passed + 1
    else
        fail(desc, "expected=" .. tostring(expected) .. ", actual=" .. tostring(actual))
    end
end

local function findSpawn(monsterType)
    for _, spawn in ipairs(fortress.spawns or {}) do
        if spawn.type == monsterType then return spawn end
    end
    return nil
end

local function assertHorizontalPatrol(monsterType, y, desc)
    local spawn = findSpawn(monsterType)
    assertTrue(spawn ~= nil, desc .. " spawn exists")
    local nodes = spawn and spawn.patrol and spawn.patrol.nodes or {}
    assertTrue(#nodes >= 6, desc .. " uses wide back-and-forth route")
    local minX, maxX = 999, -999
    for _, node in ipairs(nodes) do
        assertEqual(node.y, y, desc .. " patrol stays on horizontal lane")
        minX = math.min(minX, node.x or 999)
        maxX = math.max(maxX, node.x or -999)
    end
    assertTrue(minX <= 38 and maxX >= 74, desc .. " patrol spans the fort width")
end

print("--- CH2 MAP CONTRACT ---")

assertHorizontalPatrol("wu_dasha", 12, "wu_dasha north fort")
assertHorizontalPatrol("wu_ersha", 64, "wu_ersha south fort")

local expectedPuppets = {
    ["64,32"] = true,
    ["76,32"] = true,
    ["64,41"] = true,
    ["76,41"] = true,
    ["64,50"] = true,
    ["76,50"] = true,
}
local foundPuppets = {}
local count = 0
for _, spawn in ipairs(fortress.spawns or {}) do
    if spawn.type == "wu_blood_puppet" and spawn.x >= 60 and spawn.y >= 30 and spawn.y <= 52 then
        local key = tostring(spawn.x) .. "," .. tostring(spawn.y)
        foundPuppets[key] = true
        count = count + 1
    end
end
assertEqual(count, 6, "wanchou main fort has six elite puppet spawns")
for key in pairs(expectedPuppets) do
    assertTrue(foundPuppets[key] == true, "wanchou puppet spawn exists: " .. key)
end

print(string.format("CH2 MAP CONTRACT: %d/%d passed, %d failed", passed, total, failed))
return { passed = passed, failed = failed, total = total }
