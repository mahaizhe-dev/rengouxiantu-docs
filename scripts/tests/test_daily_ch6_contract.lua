-- ============================================================================
-- test_daily_ch6_contract.lua — 第六章日常系统契约
--
-- 覆盖：
--   D1: 第六章悟道树注册、坐标、白名单
--   D2: 第六章福源果数量、坐标唯一、可采集
--   D3: 福源果采集后属性与存档状态同步
--   D4: 福源果保存上限随第六章总数提升到 50
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local GameState = require("core.GameState")
local GameMap = require("world.GameMap")
local ZoneData_ch6 = require("config.ZoneData_ch6")
local FortuneFruitSystem = require("systems.FortuneFruitSystem")

local passed = 0
local failed = 0
local totalTests = 0

local function fail(desc, detail)
    failed = failed + 1
    print("  FAIL: " .. desc .. (detail and (" — " .. detail) or ""))
end

local function assert_true(cond, desc, detail)
    totalTests = totalTests + 1
    if cond then
        passed = passed + 1
    else
        fail(desc, detail)
    end
end

local function assert_eq(actual, expected, desc)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
    else
        fail(desc, "expected=" .. tostring(expected) .. ", actual=" .. tostring(actual))
    end
end

local function findNpc(id)
    for _, npc in ipairs(ZoneData_ch6.NPCs or {}) do
        if npc.id == id then return npc end
    end
    return nil
end

local function hasDecoration(spec)
    for _, d in ipairs(ZoneData_ch6.TownDecorations or {}) do
        local ok = true
        for k, v in pairs(spec) do
            if d[k] ~= v then
                ok = false
                break
            end
        end
        if ok then return true end
    end
    return false
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

print("--- DAILY CH6 CONTRACT ---")

local map = GameMap.New(ZoneData_ch6)

-- D1: 悟道树入口
local daoNpc = findNpc("dao_tree_ch6")
assert_true(daoNpc ~= nil, "第六章悟道树 NPC 存在")
assert_eq(daoNpc and daoNpc.interactType, "dao_tree", "第六章悟道树复用 dao_tree 交互")
assert_eq(daoNpc and daoNpc.x, 54.5, "第六章悟道树 NPC x 坐标")
assert_eq(daoNpc and daoNpc.y, 30.5, "第六章悟道树 NPC y 坐标")
assert_eq(daoNpc and daoNpc.zone, "narrow_trail", "第六章悟道树归属羊肠小径区域")
assert_true(hasDecoration({ type = "dao_tree", x = 54, y = 30, w = 2, h = 2 }),
    "第六章悟道树 2x2 装饰占地存在")

local daoTiles = {
    { 54, 30 }, { 55, 30 },
    { 54, 31 }, { 55, 31 },
}
for _, p in ipairs(daoTiles) do
    assert_true(map:IsWalkable(p[1], p[2]), "第六章悟道树占地可达: " .. p[1] .. "," .. p[2])
end

local daoHandlerText = readFile("scripts/network/DaoTreeHandler.lua") or ""
assert_true(daoHandlerText:find("dao_tree_ch6 = true", 1, true) ~= nil,
    "服务端悟道树白名单包含 dao_tree_ch6")

-- D2: 福源果配置
local ch6Fruits = FortuneFruitSystem.FRUITS[6]
assert_true(type(ch6Fruits) == "table", "第六章福源果配置存在")
assert_eq(ch6Fruits and #ch6Fruits or 0, 10, "第六章福源果数量为 10")
assert_eq(FortuneFruitSystem.GetTotalCount(), 50, "福源果总上限为 50")

local seen = {}
for _, f in ipairs(ch6Fruits or {}) do
    local key = "6_" .. f.x .. "_" .. f.y
    assert_true(not seen[key], "第六章福源果坐标不重复: " .. key)
    seen[key] = true
    assert_true(map:IsWalkable(f.x, f.y), "第六章福源果落点可通行: " .. key)
end

-- D3: 采集后属性与状态同步
GameState.currentChapter = 6
FortuneFruitSystem.Deserialize({ collected = {} })
FortuneFruitSystem.ShowPopup = function() end

local player = {
    alive = true,
    x = ch6Fruits[1].x,
    y = ch6Fruits[1].y,
    fruitFortune = 0,
    invalidated = false,
    InvalidateStatsCache = function(self)
        self.invalidated = true
    end,
    GetTotalFortune = function(self)
        return self.fruitFortune or 0
    end,
}
GameState.player = player

local nearby = FortuneFruitSystem.FindNearby(player.x, player.y)
assert_true(nearby ~= nil, "玩家站在第六章福源果坐标可找到交互目标")
assert_true(FortuneFruitSystem.Collect(nearby), "第六章福源果可采集")
assert_eq(player.fruitFortune, 1, "采集后 player.fruitFortune +1")
assert_true(player.invalidated == true, "采集后属性缓存失效")
assert_true(FortuneFruitSystem.collected[nearby.key] == true, "采集后写入 collected 状态")
assert_eq(#FortuneFruitSystem.GetActiveFruits(), 9, "采集 1 个后第六章剩余 9 个")

FortuneFruitSystem.Deserialize({ collected = {} })
GameState.player = nil

-- D4: 保存上限
local saveWriteText = readFile("scripts/network/SaveWriteService.lua") or ""
assert_true(saveWriteText:find('{ field = "fruitFortune",     max = 50', 1, true) ~= nil,
    "SaveWriteService fruitFortune 上限为 50")

print("")
print(string.format("DAILY CH6 CONTRACT: %d tests, %d passed, %d failed", totalTests, passed, failed))

return { passed = passed, failed = failed, total = totalTests }
