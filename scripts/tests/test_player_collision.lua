-- ============================================================================
-- test_player_collision.lua - 玩家椭圆脚部碰撞纯逻辑测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local Player = require("entities.Player")

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

local function assertFalse(value, message)
    if value then error(message or "expected false", 2) end
end

local function makeMap(blocked)
    return {
        IsWalkable = function(_, x, y)
            return not blocked[tostring(x) .. "," .. tostring(y)]
        end,
    }
end

local player = setmetatable({
    colHalfW = 0.30,
    colHalfH = 0.15,
    collisionOffsetY = 0,
}, Player)

print("\n[test_player_collision] === 玩家椭圆碰撞测试 ===\n")

test("空地图允许占位", function()
    assertTrue(player:CanOccupy(makeMap({}), 10, 10))
end)

test("与阻挡格侧边精确相切时保守阻挡", function()
    local map = makeMap({ ["2,1"] = true })
    assertFalse(player:CanOccupy(map, 1.2, 1.0))
    assertTrue(player:CanOccupy(map, 1.199, 1.0))
end)

test("四个方向精确相切时判定对称", function()
    assertFalse(player:CanOccupy(makeMap({ ["0,1"] = true }), 0.8, 1.0))
    assertFalse(player:CanOccupy(makeMap({ ["2,1"] = true }), 1.2, 1.0))
    assertFalse(player:CanOccupy(makeMap({ ["1,0"] = true }), 1.0, 0.65))
    assertFalse(player:CanOccupy(makeMap({ ["1,2"] = true }), 1.0, 1.35))
end)

test("椭圆圆角允许矩形外接角区域滑过", function()
    local map = makeMap({ ["2,2"] = true })
    assertTrue(player:CanOccupy(map, 1.25, 1.40))
end)

test("对角阻挡格接触点不能漏穿", function()
    local map = makeMap({
        ["1,1"] = true,
        ["2,2"] = true,
    })
    assertFalse(player:CanOccupy(map, 1.5, 1.5))
end)

test("碰撞检测最多查询相邻四格", function()
    local calls = 0
    local map = {
        IsWalkable = function()
            calls = calls + 1
            return true
        end,
    }
    assertTrue(player:CanOccupy(map, 5.4, 5.4))
    assertTrue(calls <= 4, "walkability calls=" .. tostring(calls))
end)

test("椭圆合法墙角位置不会被脱困逻辑误传送", function()
    local unstuckPlayer = setmetatable({
        x = 1.25,
        y = 1.40,
        dx = 0,
        dy = 0,
        facingRight = true,
        lastMoveX = 1.25,
        lastMoveY = 1.40,
        colHalfW = 0.30,
        colHalfH = 0.15,
        collisionOffsetY = 0,
    }, Player)
    local map = makeMap({ ["2,2"] = true })

    unstuckPlayer:Unstuck(map)

    assertTrue(unstuckPlayer.x == 1.25, "unstuck changed x")
    assertTrue(unstuckPlayer.y == 1.40, "unstuck changed y")
end)

print(string.format(
    "\n[test_player_collision] Result: %d passed, %d failed, %d total",
    passed, failed, total))
if failed > 0 then
    for _, err in ipairs(errors) do print("  - " .. err) end
end

return {
    passed = passed,
    failed = failed,
    total = total,
}
