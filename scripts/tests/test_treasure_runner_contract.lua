-- ============================================================================
-- test_treasure_runner_contract.lua - Treasure runner static contract checks
-- ============================================================================

local passed, failed, total = 0, 0, 0

local function fail(desc, detail)
    failed = failed + 1
    print("  FAIL: " .. desc .. (detail and (" - " .. detail) or ""))
end

local function assertTrue(cond, desc, detail)
    total = total + 1
    if cond then passed = passed + 1 else fail(desc, detail) end
end

local function readAll(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

print("--- TREASURE RUNNER CONTRACT ---")

local src = readAll("scripts/systems/TreasureRunnerSystem.lua") or ""
assertTrue(src:find("local HP_BARS%s*=%s*100") ~= nil, "HP_BARS is fixed at 100")
assertTrue(src:find("math%.floor%(%s*minGold%s*/%s*10%s*%)") ~= nil, "hit gold uses 1/10 of boss minimum gold")
assertTrue(src:find("math%.floor%(%s*minGold%s*/%s*5%s*%)") == nil, "old 1/5 hit gold formula is removed")
assertTrue(src:find("slot%.status%s*=%s*\"available\"[%s\r\n]+slot%.activeInstanceId%s*=%s*nil[%s\r\n]+slot%.hpBarsCurrent%s*=%s*HP_BARS") ~= nil,
    "reward failure resets slot to available with full HP bars")
assertTrue(src:find("slot%.status%s*=%s*\"killed\"") ~= nil, "reward success marks slot killed")
assertTrue(src:find("RequestImmediateSave%(\"treasure_runner_kill\"%)") ~= nil, "reward success requests immediate save")
assertTrue(src:find("if slot.status ~= \"settling\" and slot.status ~= \"active\" then return true end", 1, true) ~= nil,
    "death settlement accepts only active or settling slots")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*66%.5,%s*y%s*=%s*21%.5%s*}") == nil,
    "chapter 1 runner no longer spawns in tiger domain")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*18%.5,%s*y%s*=%s*40%.5%s*}") ~= nil,
    "chapter 1 runner respawns in bandit camp")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*46%.5,%s*y%s*=%s*41%.5%s*}") == nil,
    "chapter 2 runner no longer spawns in Wubao final boss hall")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*56%.5,%s*y%s*=%s*62%.5%s*}") ~= nil,
    "chapter 2 runner respawns in a broad non-final fort area")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*65%.5,%s*y%s*=%s*65%.5%s*}") == nil,
    "chapter 3 runner no longer spawns in first fort")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*45%.5,%s*y%s*=%s*70%.5%s*}") ~= nil,
    "chapter 3 runner respawns in second fort")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*11%.5,%s*y%s*=%s*6%.5%s*}") == nil,
    "chapter 4 runner no longer spawns in Xuanbing island")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*35%.5,%s*y%s*=%s*68%.5%s*}") ~= nil,
    "chapter 4 runner respawns in Li island")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*40%.5,%s*y%s*=%s*58%.5%s*}") == nil,
    "chapter 5 runner no longer spawns in demon abyss")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*17%.5,%s*y%s*=%s*47%.5%s*}") ~= nil,
    "chapter 5 runner respawns in sword court")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*40%.5,%s*y%s*=%s*41%.5%s*}") == nil,
    "chapter 6 runner no longer spawns in Shixuan final boss room")
assertTrue(src:find("spawn%s*=%s*{%s*x%s*=%s*18%.5,%s*y%s*=%s*28%.5%s*}") ~= nil,
    "chapter 6 runner respawns in the western camp area")

print(string.format("TREASURE RUNNER CONTRACT: %d/%d passed, %d failed", passed, total, failed))
return { passed = passed, failed = failed, total = total }
