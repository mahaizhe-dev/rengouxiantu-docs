package.path = package.path .. ";scripts/?.lua"

local Config = require("config.TreasureMapConfig")
local ZoneData = require("config.ZoneData_ch4")
local ActiveZoneData = require("config.ActiveZoneData")
local GameMap = require("world.GameMap")

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

local previousZoneData = ActiveZoneData.Get()
local map = GameMap.New(ZoneData, 80, 80)

local function Key(x, y)
    return tostring(x) .. "," .. tostring(y)
end

local function IslandTileSet(island)
    local set = {}
    for _, pos in ipairs(island.tiles or {}) do
        set[Key(pos[1], pos[2])] = true
    end
    return set
end

local function HasPath(island)
    local own = IslandTileSet(island)
    local queue = { { island.spawn.x, island.spawn.y } }
    local visited = { [Key(island.spawn.x, island.spawn.y)] = true }
    local head = 1
    local directions = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }
    while head <= #queue do
        local current = queue[head]
        head = head + 1
        if current[1] == island.chest.x and current[2] == island.chest.y then
            return true
        end
        for _, direction in ipairs(directions) do
            local x = current[1] + direction[1]
            local y = current[2] + direction[2]
            local key = Key(x, y)
            if own[key] and not visited[key] then
                visited[key] = true
                queue[#queue + 1] = { x, y }
            end
        end
    end
    return false
end

local function ShapeSignature(island)
    local parts = {}
    for _, pos in ipairs(island.tiles or {}) do
        parts[#parts + 1] = tostring(pos[1] - island.bounds.x1)
            .. "," .. tostring(pos[2] - island.bounds.y1)
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

test("treasure islands are part of the real chapter-four map", function()
    assertEqual(map.width, 80)
    assertEqual(map.height, 80)
    assertEqual(ZoneData.TREASURE_ISLANDS, Config.ISLANDS)
    local clientSource = assert(io.open("scripts/systems/TreasureMapSystem.lua", "r")):read("*a")
    assertTrue(not clientSource:find("TreasureSeaZoneData", 1, true))
    assertTrue(not clientSource:find("ActivateZoneData", 1, true))
    assertTrue(not clientSource:find("gameMap_.tiles =", 1, true))
end)

test("normal islands have 4-7 tiles and premium island has 9-10 tiles", function()
    for _, island in ipairs(Config.ISLANDS) do
        local count = #(island.tiles or {})
        if island.isPremium then
            assertTrue(count >= 9 and count <= 10, island.islandId .. " premium size")
        else
            assertTrue(count >= 4 and count <= 7, island.islandId .. " normal size")
        end
    end
end)

test("all island points are walkable, connected and belong to their island", function()
    for _, island in ipairs(Config.ISLANDS) do
        local own = IslandTileSet(island)
        assertTrue(own[Key(island.spawn.x, island.spawn.y)], island.islandId .. " spawn tile")
        assertTrue(own[Key(island.chest.x, island.chest.y)], island.islandId .. " chest tile")
        assertTrue(own[Key(island.exit.x, island.exit.y)], island.islandId .. " exit tile")
        for _, pos in ipairs(island.tiles) do
            assertTrue(map:IsWalkable(pos[1], pos[2]),
                island.islandId .. " walkable " .. Key(pos[1], pos[2]))
        end
        assertTrue(HasPath(island), island.islandId .. " spawn-to-chest path")
        assertEqual(island.chest.x, island.bounds.x1, island.islandId .. " chest x corner")
        assertEqual(island.chest.y, island.bounds.y1, island.islandId .. " chest y corner")
        assertEqual(island.exit.x, island.bounds.x2, island.islandId .. " exit x corner")
        assertEqual(island.exit.y, island.bounds.y2, island.islandId .. " exit y corner")
    end
end)

test("treasure islands use varied silhouettes across inner and outer sea", function()
    local innerCount, outerCount = 0, 0
    local signatures = {}
    for _, island in ipairs(Config.ISLANDS) do
        local centerX = (island.bounds.x1 + island.bounds.x2) / 2
        local centerY = (island.bounds.y1 + island.bounds.y2) / 2
        local dx, dy = centerX - 40, centerY - 40
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < 20 then innerCount = innerCount + 1 end
        if distance > 30 then outerCount = outerCount + 1 end
        signatures[ShapeSignature(island)] = true
    end
    local shapeCount = 0
    for _ in pairs(signatures) do shapeCount = shapeCount + 1 end
    assertTrue(innerCount >= 3, "expected at least three inner-sea treasure islands")
    assertTrue(outerCount >= 5, "expected at least five outer-sea treasure islands")
    assertTrue(shapeCount >= 6, "expected at least six distinct island silhouettes")
end)

test("superior lingyun treasure sits northeast of the zhen island", function()
    local treasure = Config.ISLAND_BY_REWARD_TYPE.lingyun_fruit_superior
    local zhen = ZoneData.LAYOUT.islands.zhen
    assertTrue(treasure.bounds.x1 > zhen.x2, "superior lingyun treasure must be east of zhen")
    assertTrue(treasure.bounds.y2 < zhen.y1, "superior lingyun treasure must be north of zhen")
end)

test("every treasure island is separated from all other land by sea", function()
    for _, island in ipairs(Config.ISLANDS) do
        local own = IslandTileSet(island)
        for _, pos in ipairs(island.tiles) do
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local x, y = pos[1] + dx, pos[2] + dy
                    if not own[Key(x, y)] then
                        assertTrue(not map:IsWalkable(x, y),
                            island.islandId .. " connected at " .. Key(x, y))
                    end
                end
            end
        end
    end
end)

test("chapter four contains nine visible chests and nine return portals", function()
    local chests, exits, premium = 0, 0, 0
    for _, npc in ipairs(ZoneData.NPCs) do
        if npc.interactType == "treasure_map_chest" then
            chests = chests + 1
            assertTrue(npc.showNameplate == true, npc.id .. " nameplate")
            assertTrue((npc.imageScale or 0) >= 1.5, npc.id .. " chest scale")
            if npc.rewardType == "account_treasure" then
                premium = premium + 1
                assertEqual(npc.image, Config.PREMIUM_CHEST_IMAGE)
                assertTrue((npc.imageScale or 0) > 1.5)
            else
                assertEqual(npc.image, Config.NORMAL_CHEST_IMAGE)
                assertEqual(npc.imageScale, 1.5)
            end
        elseif npc.interactType == "treasure_map_exit" then
            exits = exits + 1
        end
    end
    assertEqual(chests, 9)
    assertEqual(exits, 9)
    assertEqual(premium, 1)
end)

test("treasure islands do not add minimap markers", function()
    local file = assert(io.open("scripts/world/mapgen/Chapter4.lua", "r"))
    local source = file:read("*a")
    file:close()
    assertTrue(not source:find("Minimap", 1, true))
    assertTrue(not source:find("marker", 1, true))
end)

ActiveZoneData.Set(previousZoneData)

print(string.format("[test_treasure_sea_map] passed=%d failed=%d total=%d",
    passed, failed, total))
return { passed = passed, failed = failed, total = total }
