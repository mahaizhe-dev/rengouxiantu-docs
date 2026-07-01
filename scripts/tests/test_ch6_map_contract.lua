-- ============================================================================
-- test_ch6_map_contract.lua — 第六章地图契约验证
--
-- 覆盖：
--   M1: 虎王试炼未来副本边界复用已有封印，封印瓦片不可通行
--   M2: 呱大人湖区东北入口可连通 BOSS 岛，四株白莲落点可通行
--   M3: 第六章高风险瓦片都有颜色定义，避免调试紫色回退
--   M4: 第六章视觉语言为水晶，东大营不再使用洞窟/蛛网装饰
--   M5: 天青白莲当前只展示“暂未开放”，有头顶名字，不接青莲长生体养成逻辑
--   M6: 第六章传送阵使用通用传送阵特效
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local GameMap = require("world.GameMap")
local ZoneData_ch6 = require("config.ZoneData_ch6")

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

local function tileAt(map, x, y)
    return map:GetTile(x, y)
end

local function canReach(map, start, target)
    local sx, sy = start[1], start[2]
    local tx, ty = target[1], target[2]
    if not map:IsWalkable(sx, sy) or not map:IsWalkable(tx, ty) then
        return false
    end

    local queue = { { sx, sy } }
    local head = 1
    local seen = { [sx .. "," .. sy] = true }
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

    while queue[head] do
        local p = queue[head]
        head = head + 1
        if p[1] == tx and p[2] == ty then
            return true
        end
        for _, d in ipairs(dirs) do
            local nx, ny = p[1] + d[1], p[2] + d[2]
            local key = nx .. "," .. ny
            if not seen[key] and map:IsWalkable(nx, ny) then
                seen[key] = true
                queue[#queue + 1] = { nx, ny }
            end
        end
    end
    return false
end

print("--- CH6 MAP CONTRACT: build map ---")

local map = GameMap.New(ZoneData_ch6)
local T = ZoneData_ch6.TILE

-- ============================================================================
-- M1: 未来副本封印边界
-- ============================================================================
print("--- M1: tiger trial future barrier ---")

local barrier = ZoneData_ch6.FUTURE_DUNGEON_BARRIERS
    and ZoneData_ch6.FUTURE_DUNGEON_BARRIERS.tiger_trial
assert_true(barrier ~= nil, "虎王试炼未来副本边界配置存在")
assert_eq(barrier and barrier.tile, "SEALED_GATE", "虎王试炼边界复用已有 SEALED_GATE")
assert_true(T.CH6_TRIAL_SEAL == nil, "虎王试炼不再新增专属封印瓦片")
assert_true(barrier and barrier.bounds == nil, "虎王试炼不再整圈大面积封印")

local sealCount = 0
if barrier and barrier.sealRects then
    for _, rect in ipairs(barrier.sealRects) do
        for y = rect.y1, rect.y2 do
            for x = rect.x1, rect.x2 do
                if tileAt(map, x, y) == T.SEALED_GATE then
                    sealCount = sealCount + 1
                end
            end
        end
    end
end
assert_eq(sealCount, 8, "虎王试炼只封原 4x2 小门洞")

for x = 67, 70 do
    assert_eq(tileAt(map, x, 26), T.SEALED_GATE, "南侧原门洞 y=26 已封印 x=" .. x)
    assert_eq(tileAt(map, x, 27), T.SEALED_GATE, "南侧原门洞 y=27 已封印 x=" .. x)
end
assert_true(not map:IsWalkable(68, 26), "虎王试炼封印门不可通行")
assert_true(map:IsWalkable(68, 29), "虎王试炼门前可站立")

local hasTigerSealFx = false
for _, d in ipairs(ZoneData_ch6.TownDecorations or {}) do
    if d.type == "fengmo_seal" and d.x == 67 and d.y == 26 and d.w == 4 and d.h == 2 then
        hasTigerSealFx = true
        break
    end
end
assert_true(hasTigerSealFx, "虎王试炼入口复用已有动态封魔法阵")

-- ============================================================================
-- M2: 呱大人湖区连通性与白莲落点
-- ============================================================================
print("--- M2: gua lake connectivity ---")

assert_true(canReach(map, { 24, 64 }, { 12, 73 }), "呱大人湖区东北入口可连通 BOSS 岛")

local lotusTiles = {
    { 8, 71 }, { 14, 71 }, { 8, 76 }, { 14, 76 },
}
for _, p in ipairs(lotusTiles) do
    assert_true(map:IsWalkable(p[1], p[2]), "天青白莲落点可通行: " .. p[1] .. "," .. p[2])
end

-- ============================================================================
-- M3: 高风险瓦片颜色完整
-- ============================================================================
print("--- M3: ch6 tile colors ---")

local colorTiles = {
    "CAMP_DIRT", "SWAMP", "SEALED_GATE",
    "CH6_SHADOW_GROUND", "CH6_MOUNTAIN_STONE", "CH6_MOUNTAIN_RUNE",
    "CH6_CORRUPTED_TOWN", "CH6_SEAL_FLOOR", "CH6_TRIAL_STONE",
}
for _, key in ipairs(colorTiles) do
    local tile = T[key]
    assert_true(tile ~= nil, key .. " 瓦片存在")
    assert_true(tile and ZoneData_ch6.TILE_COLORS[tile] ~= nil, key .. " 有 TILE_COLORS")
    assert_true(tile and ZoneData_ch6.TILE_TRANSITION_COLORS[tile] ~= nil, key .. " 有 TILE_TRANSITION_COLORS")
end

-- ============================================================================
-- M4: 水晶视觉语言
-- ============================================================================
print("--- M4: crystal visual language ---")

assert_eq(ZoneData_ch6.MAP_THEME and ZoneData_ch6.MAP_THEME.visualLanguage, "crystal", "第六章视觉语言为 crystal")
local forbidden = ZoneData_ch6.MAP_THEME and ZoneData_ch6.MAP_THEME.forbiddenDecorationTypes or {}
local crystalCount = 0
for _, d in ipairs(ZoneData_ch6.TownDecorations or {}) do
    if d.type == "crystal" or d.type == "crystal_reed" or d.type == "crystal_bubble" then
        crystalCount = crystalCount + 1
    end
    assert_true(not forbidden[d.type], "第六章装饰不使用禁用类型: " .. tostring(d.type))
end
assert_true(crystalCount >= 90, "第六章水晶装饰密度足够", "crystalCount=" .. tostring(crystalCount))

-- ============================================================================
-- M5: 天青白莲暂未开放
-- ============================================================================
print("--- M5: qingbai lotus coming soon only ---")

local lotusCount = 0
for _, npc in ipairs(ZoneData_ch6.NPCs or {}) do
    if npc.decorationType == "qingbai_lotus" then
        lotusCount = lotusCount + 1
        assert_eq(npc.interactType, "coming_soon", npc.id .. " 交互类型暂未开放")
        assert_true(npc.showNameplate == true and npc.hideName ~= true, npc.id .. " 显示头顶名字")
        assert_true(npc.subtitle == nil or npc.subtitle == "", npc.id .. " 头顶只显示天青白莲名称")
        assert_true(type(npc.dialog) == "string" and npc.dialog:find("暂未开放", 1, true) ~= nil,
            npc.id .. " 文案包含暂未开放")
        assert_true(type(npc.dialog) == "string" and npc.dialog:find("青莲长生体", 1, true) == nil,
            npc.id .. " 暂不暴露青莲长生体养成逻辑")
    end
end
assert_eq(lotusCount, 4, "天青白莲数量为 4")

-- ============================================================================
-- M6: 第六章传送阵通用特效
-- ============================================================================
print("--- M6: ch6 teleport common effect ---")

local hasTeleportFx = false
for _, d in ipairs(ZoneData_ch6.TownDecorations or {}) do
    if d.type == "teleport_array" and d.x == 76 and d.y == 39 then
        hasTeleportFx = true
        break
    end
end
assert_true(hasTeleportFx, "第六章传送阵添加通用 teleport_array 特效")

print("")
print(string.format("CH6 MAP CONTRACT: %d tests, %d passed, %d failed", totalTests, passed, failed))

return { passed = passed, failed = failed, total = totalTests }
