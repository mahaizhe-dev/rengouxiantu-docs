-- ============================================================================
-- test_monster_crowd.lua - 近身战斗怪物弱分离纯逻辑测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local MonsterCrowdSystem = require("systems.MonsterCrowdSystem")

local passed, failed, total = 0, 0, 0
local errors = {}

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

local function makeMonster(id, x, y, state, category, opts)
    opts = opts or {}
    return {
        id = id,
        x = x,
        y = y,
        alive = opts.alive ~= false,
        state = state or "attack",
        category = category or "normal",
        data = { stationary = opts.stationary or false },
        isTrainingDummy = opts.isTrainingDummy,
        isPillar = opts.isPillar,
        isDungeonBoss = opts.isDungeonBoss,
        casting = opts.casting,
        burstState = opts.burstState,
        disableSoftSeparation = opts.disableSoftSeparation,
    }
end

local openMap = {
    IsWalkable = function() return true end,
}
local player = { x = 0, y = 0 }

print("\n[test_monster_crowd] === 近身战斗怪弱分离测试 ===\n")

test("六只同点普通怪在一秒内多数产生轻微偏移", function()
    local monsters = {}
    for i = 1, 6 do
        monsters[i] = makeMonster(i, 1, 0, "attack", "normal")
    end

    MonsterCrowdSystem.Reset()
    for _ = 1, 10 do
        MonsterCrowdSystem.Update(0.1, monsters, player, openMap)
    end

    local moved = 0
    for _, monster in ipairs(monsters) do
        local dx = monster.x - 1
        local dy = monster.y
        if dx * dx + dy * dy > 0.03 * 0.03 then
            moved = moved + 1
        end
    end
    assertTrue(moved >= 4, "moved monsters=" .. tostring(moved))
end)

test("普通怪加快散开但单轮不瞬移到位", function()
    local monsters = {
        makeMonster(1, 1, 0, "attack", "normal"),
        makeMonster(2, 1, 0, "attack", "normal"),
    }

    MonsterCrowdSystem.Reset()
    MonsterCrowdSystem.Update(0.1, monsters, player, openMap)

    for _, monster in ipairs(monsters) do
        local dx = monster.x - 1
        local dy = monster.y
        local moved = math.sqrt(dx * dx + dy * dy)
        assertTrue(moved > 0, "normal monster did not move")
        assertTrue(moved <= 0.030001, "normal monster moved too far=" .. tostring(moved))
        assertTrue(moved < 0.15, "normal monster snapped to full separation")
    end
end)

test("远处与非战斗状态怪物保持原位", function()
    local monsters = {
        makeMonster(1, 20, 0, "attack", "normal"),
        makeMonster(2, 1, 0, "idle", "normal"),
        makeMonster(3, 1, 0, "patrol", "normal"),
        makeMonster(4, 1, 0, "return", "normal"),
    }

    MonsterCrowdSystem.Reset()
    MonsterCrowdSystem.Update(0.1, monsters, player, openMap)
    for i, monster in ipairs(monsters) do
        local expectedX = i == 1 and 20 or 1
        assertEqual(monster.x, expectedX, "monster " .. i .. " moved")
        assertEqual(monster.y, 0, "monster " .. i .. " moved")
    end
end)

test("BOSS及以上参与但单轮位移严格低于普通怪", function()
    local monsters = {
        makeMonster(1, 1, 0, "attack", "normal"),
        makeMonster(2, 1, 0, "attack", "boss"),
        makeMonster(3, 1, 0, "attack", "king_boss"),
        makeMonster(4, 1, 0, "attack", "emperor_boss"),
        makeMonster(5, 1, 0, "attack", "saint_boss"),
    }

    MonsterCrowdSystem.Reset()
    MonsterCrowdSystem.Update(0.1, monsters, player, openMap)
    local stats = MonsterCrowdSystem.GetLastStats()
    assertEqual(stats.candidates, 5)

    local normalDx = monsters[1].x - 1
    local normalDy = monsters[1].y
    local normalMove = math.sqrt(normalDx * normalDx + normalDy * normalDy)
    assertTrue(normalMove > 0.005, "normal monster should move more than bosses")

    for i = 2, #monsters do
        local dx = monsters[i].x - 1
        local dy = monsters[i].y
        local moved = math.sqrt(dx * dx + dy * dy)
        assertTrue(moved > 0, "boss " .. i .. " did not participate")
        assertTrue(moved <= 0.005001, "boss moved too far=" .. tostring(moved))
    end
end)

test("副本BOSS和特殊固定对象不参与", function()
    local monsters = {
        makeMonster(1, 1, 0, "attack", "boss", { isDungeonBoss = true }),
        makeMonster(2, 1, 0, "attack", "saint_boss", { stationary = true }),
        makeMonster(3, 1, 0, "attack", "normal", { isTrainingDummy = true }),
        makeMonster(4, 1, 0, "attack", "normal", { isPillar = true }),
        makeMonster(5, 1, 0, "attack", "boss", { casting = true }),
        makeMonster(6, 1, 0, "attack", "king_boss", { burstState = {} }),
        makeMonster(7, 1, 0, "attack", "emperor_boss", { disableSoftSeparation = true }),
    }

    MonsterCrowdSystem.Reset()
    MonsterCrowdSystem.Update(0.1, monsters, player, openMap)
    local stats = MonsterCrowdSystem.GetLastStats()
    assertEqual(stats.candidates, 0)
    for _, monster in ipairs(monsters) do
        assertEqual(monster.x, 1)
        assertEqual(monster.y, 0)
    end
end)

test("不可通行时允许继续完全重叠", function()
    local monsters = {
        makeMonster(1, 1, 0, "attack", "normal"),
        makeMonster(2, 1, 0, "attack", "normal"),
    }
    local blockedMap = {
        IsWalkable = function() return false end,
    }

    MonsterCrowdSystem.Reset()
    MonsterCrowdSystem.Update(0.1, monsters, player, blockedMap)
    local stats = MonsterCrowdSystem.GetLastStats()
    assertEqual(monsters[1].x, 1)
    assertEqual(monsters[2].x, 1)
    assertTrue(stats.movesBlocked > 0)
end)

test("候选数和配对数严格封顶", function()
    local monsters = {}
    for i = 1, 24 do
        monsters[i] = makeMonster(i, 1, 0, "attack", "normal")
    end

    MonsterCrowdSystem.Reset()
    MonsterCrowdSystem.Update(0.1, monsters, player, openMap)
    local stats = MonsterCrowdSystem.GetLastStats()
    assertEqual(stats.candidates, 16)
    assertTrue(stats.pairChecks <= 128)
    assertEqual(stats.pairChecks, 120)
end)

print(string.format(
    "\n[test_monster_crowd] Result: %d passed, %d failed, %d total",
    passed, failed, total))
if failed > 0 then
    for _, err in ipairs(errors) do print("  - " .. err) end
end

return {
    passed = passed,
    failed = failed,
    total = total,
}
