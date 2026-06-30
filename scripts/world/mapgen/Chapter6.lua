-- ============================================================================
-- mapgen/Chapter6.lua - 第六章地形后处理（陆章·两界村之影）
-- 复刻第一章地图后，仅在第六章独立做区域重排与影化地形微调。
-- ============================================================================

---@param GameMap table
---@param zd table
return function(GameMap, zd)

local function safeTile(self, x, y, tile)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        self:SetTile(x, y, tile)
    end
end

local function fillRect(self, x1, y1, x2, y2, tile)
    for y = y1, y2 do
        for x = x1, x2 do
            safeTile(self, x, y, tile)
        end
    end
end

local function fillBorder(self, x1, y1, x2, y2, tile)
    for x = x1, x2 do
        safeTile(self, x, y1, tile)
        safeTile(self, x, y2, tile)
    end
    for y = y1, y2 do
        safeTile(self, x1, y, tile)
        safeTile(self, x2, y, tile)
    end
end

local function carveRoad(self, x1, y1, x2, y2, tile)
    fillRect(self, x1, y1, x2, y2, tile)
end

local function hash100(x, y, seed)
    return ((x * 374761393 + y * 668265263 + seed * 1442695041) & 0x7FFFFFFF) % 100
end

local function buildSpawnSafeArea(self, T)
    local safe = zd.Regions and zd.Regions.shadow_spawn_safe
    if not safe then return end

    for y = safe.y1, safe.y2 do
        for x = safe.x1, safe.x2 do
            local tile = self:GetTile(x, y)
            if tile == T.MOUNTAIN or tile == T.WALL or tile == T.WATER then
                safeTile(self, x, y, T.GRASS)
            end
        end
    end

    -- 出生入口做成一条清晰但克制的旧路，不再依赖第一章村落安全区。
    local roadY1 = math.floor((safe.y1 + safe.y2) / 2)
    local roadY2 = roadY1 + 1
    for x = safe.x1, safe.x2 do
        safeTile(self, x, roadY1, T.TOWN_ROAD)
        safeTile(self, x, roadY2, T.TOWN_ROAD)
    end
    for y = safe.y1 + 1, safe.y2 - 1 do
        safeTile(self, 76, y, T.TOWN_ROAD)
        safeTile(self, 77, y, T.TOWN_ROAD)
    end
end

local function buildBackhillExpansion(self, T)
    -- 后山寨右扩为独立区块：左接山贼寨，下接乱石旧地，不直接连虎王领地。
    fillRect(self, 48, 4, 55, 20, T.CAMP_FLOOR)
    fillBorder(self, 33, 4, 55, 20, T.MOUNTAIN)

    -- 左侧仍与山贼寨主寨相连。
    carveRoad(self, 29, 9, 33, 13, T.CAMP_FLOOR)

    -- 封掉第一章原后山北入口。
    fillRect(self, 38, 2, 41, 4, T.MOUNTAIN)

    -- 后山东侧恢复封闭，虎王领地不从后山进入。
    fillRect(self, 56, 4, 57, 25, T.MOUNTAIN)

    -- 与上移后的村北乱石旧地相连的自然通道。
    carveRoad(self, 42, 20, 46, 22, T.CAMP_FLOOR)
    safeTile(self, 41, 21, T.CAMP_FLOOR)
    safeTile(self, 47, 21, T.CAMP_FLOOR)
    safeTile(self, 42, 22, T.GRASS)
    safeTile(self, 46, 22, T.GRASS)

    -- 通道两侧保持断崖感，避免整条后山南侧都开放。
    for x = 33, 55 do
        if x < 41 or x > 47 then
            safeTile(self, x, 21, T.MOUNTAIN)
        end
    end

    -- 削掉右上、右下直角，让后山扩展区边缘更自然。
    local cornerCuts = {
        {55, 4}, {54, 4}, {55, 5}, {53, 4}, {55, 6},
        {54, 5}, {53, 5}, {54, 6},
        {55, 20}, {54, 20}, {55, 19}, {53, 20}, {55, 18},
        {54, 19}, {53, 19}, {54, 18},
    }
    for _, p in ipairs(cornerCuts) do
        safeTile(self, p[1], p[2], T.MOUNTAIN)
    end

    -- 扩展区少量固定岩簇，保持后山寨荒败感但不阻断主通路。
    local rocks = {
        {50, 6}, {51, 6}, {54, 8},
        {49, 16}, {52, 17}, {53, 17},
        {47, 18}, {54, 18},
    }
    for _, p in ipairs(rocks) do
        local tile = self:GetTile(p[1], p[2])
        if tile == T.CAMP_FLOOR then
            safeTile(self, p[1], p[2], T.MOUNTAIN)
        end
    end

    -- 指定清除：后山底部三格岩石改回营地地面。
    for x = 43, 45 do
        safeTile(self, x, 19, T.CAMP_FLOOR)
    end
end

local function buildBanditBossRoom(self, T)
    -- 山贼寨主寨左侧中央 10x10 BOSS 房间。
    local x1, y1, x2, y2 = 3, 20, 12, 29
    fillRect(self, x1, y1, x2, y2, T.CAMP_FLOOR)
    fillBorder(self, x1, y1, x2, y2, T.WALL)

    -- 东侧双格门，先开放，后续可接封印/副本逻辑。
    safeTile(self, x2, 24, T.CAMP_FLOOR)
    safeTile(self, x2, 25, T.CAMP_FLOOR)
    safeTile(self, x2 + 1, 24, T.CAMP_FLOOR)
    safeTile(self, x2 + 1, 25, T.CAMP_FLOOR)
end

local function buildVillageNorthRuins(self, T)
    -- 两界村上方、后山寨下方的乱石旧地：保留原石地/旧场结构，只减少乱石堆。
    local r = zd.Regions and zd.Regions.village_north_ruins
    if not r then return end

    for y = r.y1, r.y2 do
        for x = r.x1, r.x2 do
            local tile = self:GetTile(x, y)
            local h = hash100(x, y, 606)
            local centerOpen = x >= 38 and x <= 49 and y >= 24 and y <= 28
            local passage = x >= 42 and x <= 46 and y <= 23

            -- 只打薄乱石：不整块重画，保留原石地板/道路/草地的既有结构。
            if tile == T.MOUNTAIN then
                if passage then
                    safeTile(self, x, y, T.CAMP_FLOOR)
                elseif centerOpen and h < 82 then
                    safeTile(self, x, y, T.TOWN_FLOOR)
                elseif h < 58 then
                    safeTile(self, x, y, T.GRASS)
                end
            elseif tile == T.GRASS and centerOpen and h < 30 then
                safeTile(self, x, y, T.TOWN_FLOOR)
            end
        end
    end

    -- 保留少量自然乱石，不做工整矩形边界。
    local rocks = {
        {35, 23}, {37, 22}, {52, 23}, {54, 25},
        {36, 28}, {50, 29}, {44, 26}, {39, 29},
    }
    for _, p in ipairs(rocks) do
        local tile = self:GetTile(p[1], p[2])
        if tile ~= T.TOWN_ROAD and tile ~= T.CAMP_FLOOR then
            safeTile(self, p[1], p[2], T.MOUNTAIN)
        end
    end

    -- 与后山相连的自然通道，需求要求两者连通。
    carveRoad(self, 42, 20, 46, 23, T.CAMP_FLOOR)
    safeTile(self, 41, 22, T.CAMP_FLOOR)
    safeTile(self, 47, 22, T.CAMP_FLOOR)
end

local function buildBoarWaterBossArea(self, T)
    -- 野猪林左下角扩大水域，形成天然不规则 BOSS 岛，东北方向自然敞开入口。
    local cx, cy = 12, 73
    local rx, ry = 10, 8

    for y = 63, 79 do
        for x = 3, 25 do
            local nx = (x - cx) / rx
            local ny = (y - cy) / ry
            local d = nx * nx + ny * ny
            local h = hash100(x, y, 666)
            local mouthSlope = y - (72 - math.floor((x - 15) * 0.55))
            local northEastMouth = x >= 15 and x <= 24 and y >= 64 and y <= 72
                and mouthSlope >= -2 and mouthSlope <= 2
                and h < 72
            if not northEastMouth then
                if d <= 1.12 and (d >= 0.24 or h < 30) then
                    safeTile(self, x, y, T.WATER)
                elseif d <= 1.24 and h < 18 then
                    safeTile(self, x, y, T.WATER)
                end
            end
        end
    end

    -- 左下 BOSS 岛，略微削角，避免方正。
    fillRect(self, 7, 70, 15, 77, T.FOREST_FLOOR)
    local cutCorners = {
        {7, 70}, {15, 70}, {7, 77}, {15, 77},
        {8, 70}, {14, 77}, {7, 71}, {15, 76},
    }
    for _, p in ipairs(cutCorners) do
        safeTile(self, p[1], p[2], T.WATER)
    end

    -- 东北方向敞开入口：用错落地块打散边缘，避免湖面被直线切开。
    local mouthTiles = {
        {15, 69}, {16, 68}, {16, 69}, {17, 67}, {17, 68}, {17, 70},
        {18, 66}, {18, 67}, {18, 69}, {19, 66}, {19, 68},
        {20, 65}, {20, 66}, {20, 67}, {21, 65}, {21, 66},
        {22, 64}, {22, 65}, {23, 64},
        {16, 71}, {17, 72}, {18, 71},
    }
    for _, p in ipairs(mouthTiles) do
        safeTile(self, p[1], p[2], T.FOREST_FLOOR)
    end
end

local function sealSpiderTrailLinks(self, T)
    -- 封锁羊肠小径与蜘蛛洞的直接南北入口，蜘蛛洞必须从村子下方外围绕行。
    fillRect(self, 57, 50, 64, 54, T.MOUNTAIN)
    fillRect(self, 73, 50, 78, 54, T.MOUNTAIN)

    -- 保留蜘蛛洞西北侧从野猪林方向进入的绕行口。
    carveRoad(self, 43, 52, 48, 54, T.CAVE_FLOOR)
    carveRoad(self, 39, 55, 44, 59, T.FOREST_FLOOR)
end

local function buildTigerSealEntrance(self, T)
    local sealTile = T.SEALED_GATE or T.WALL

    -- 虎王领地恢复封闭：西侧不通后山，只保留南侧连接羊肠小径。
    fillRect(self, 56, 2, 57, 25, T.MOUNTAIN)
    fillRect(self, 56, 26, 79, 27, T.MOUNTAIN)

    -- 南侧唯一入口，保留门形并覆盖封印光幕瓦片。
    for x = 67, 70 do
        safeTile(self, x, 26, sealTile)
        safeTile(self, x, 27, sealTile)
    end
    carveRoad(self, 66, 28, 69, 30, T.GRASS)
end

local function narrowTrailTownEntrance(self, T)
    -- 收窄羊肠小径通往两界村方向的西侧入口；保留村外 x=49~51 环路畅通。
    fillRect(self, 52, 37, 54, 39, T.MOUNTAIN)
    fillRect(self, 52, 42, 54, 44, T.MOUNTAIN)
    carveRoad(self, 49, 40, 54, 41, T.GRASS)
end

local function sealTownGates(self, T)
    local sealTile = T.SEALED_GATE or T.WALL

    -- 两界村作为未来副本区域，四门保持入口形态，以封印光幕替代普通墙堵。
    fillRect(self, 40, 33, 41, 33, sealTile)
    fillRect(self, 40, 48, 41, 48, sealTile)
    fillRect(self, 33, 40, 33, 41, sealTile)
    fillRect(self, 48, 40, 48, 41, sealTile)

    -- 村墙外一圈不额外加阻挡，保持一章原有绕行结构。

    -- 村内中心保留轮廓，但清掉会造成“功能主城”错觉的中心道具占位。
    local clearTiles = {
        {39, 42}, -- 原水井
        {41, 43}, -- 原治愈之泉
        {42, 43}, -- 原摊位
        {41, 41}, -- 原传送法阵
    }
    for _, p in ipairs(clearTiles) do
        safeTile(self, p[1], p[2], T.TOWN_ROAD)
    end
end

local function canDecorateFloor(tile, T)
    return tile ~= T.MOUNTAIN and tile ~= T.WALL and tile ~= T.WATER and tile ~= T.SEALED_GATE
end

local function setFloorIfOpen(self, T, x, y, tile)
    local old = self:GetTile(x, y)
    if canDecorateFloor(old, T) then
        safeTile(self, x, y, tile)
    end
end

local function decorateShadowEntrance(self, T)
    -- 影入口只做低密度暗影斑块，保持出生安全区清晰。
    local points = {
        {73, 36}, {74, 35}, {78, 35}, {79, 38},
        {73, 44}, {75, 45}, {79, 44}, {72, 40},
    }
    for _, p in ipairs(points) do
        setFloorIfOpen(self, T, p[1], p[2], T.CH6_SHADOW_GROUND)
    end
end

local function decorateShadowRuins(self, T)
    local r = zd.Regions and zd.Regions.village_north_ruins
    if not r then return end

    for y = r.y1, r.y2 do
        for x = r.x1, r.x2 do
            local tile = self:GetTile(x, y)
            local h = hash100(x, y, 616)
            local nearCenter = x >= 38 and x <= 50 and y >= 24 and y <= 29
            if canDecorateFloor(tile, T) and ((nearCenter and h < 24) or h < 9) then
                safeTile(self, x, y, T.CH6_SHADOW_GROUND)
            end
        end
    end
end

local function decorateMountainDomain(self, T)
    local r = zd.Regions and zd.Regions.bandit_backhill
    if not r then return end

    for y = r.y1, r.y2 do
        for x = r.x1, r.x2 do
            local tile = self:GetTile(x, y)
            if tile == T.CAMP_FLOOR or tile == T.TOWN_FLOOR then
                local h = hash100(x, y, 626)
                if h < 45 and T.CAMP_DIRT then
                    safeTile(self, x, y, T.CAMP_DIRT)
                else
                    safeTile(self, x, y, T.GRASS)
                end
            end
        end
    end

    -- 山神符纹只作为祭台点缀，不把整片两界山铺成石质地板。
    local altar = {
        {44, 12}, {45, 12}, {43, 13}, {44, 13}, {45, 13}, {46, 13},
        {44, 14}, {45, 14},
    }
    for _, p in ipairs(altar) do
        setFloorIfOpen(self, T, p[1], p[2], T.CH6_MOUNTAIN_RUNE)
    end
end

local function decorateCelestialCamps(self, T)
    -- 东西大营只做装饰性符点，不整体替换营地/洞穴底色。
    local westMarks = {
        {7, 24}, {8, 24}, {9, 24},
        {20, 12}, {21, 12}, {22, 12},
        {28, 15}, {28, 16},
    }
    for _, p in ipairs(westMarks) do
        setFloorIfOpen(self, T, p[1], p[2], T.CH6_SEAL_FLOOR)
    end

    local eastMarks = {
        {62, 61}, {63, 61}, {64, 61},
        {69, 66}, {70, 66}, {71, 66},
        {75, 72}, {75, 73},
    }
    for _, p in ipairs(eastMarks) do
        setFloorIfOpen(self, T, p[1], p[2], T.CH6_SEAL_FLOOR)
    end
end

local function decorateFrogMarsh(self, T)
    local points = {
        {10, 68}, {12, 68}, {18, 69}, {20, 70},
        {16, 73}, {18, 74}, {10, 77}, {13, 78},
        {22, 66}, {23, 67},
    }
    for _, p in ipairs(points) do
        local tile = self:GetTile(p[1], p[2])
        if tile == T.FOREST_FLOOR or tile == T.GRASS then
            safeTile(self, p[1], p[2], T.SWAMP)
        end
    end
end

local function decorateTigerTrial(self, T)
    -- 虎王领地是神圣试炼地：只用试炼石，不加腐化。
    local points = {
        {66, 28}, {67, 28}, {68, 28}, {69, 28}, {70, 28},
        {66, 29}, {67, 29}, {68, 29}, {69, 29}, {70, 29}, {71, 29},
        {67, 30}, {68, 30}, {69, 30}, {70, 30},
        {67, 31}, {70, 31},
    }
    for _, p in ipairs(points) do
        setFloorIfOpen(self, T, p[1], p[2], T.CH6_TRIAL_STONE)
    end
end

local function decorateTownSealCorruption(self, T)
    -- 腐化集中在封印两界村，不外溢到虎王试炼地。
    local sealCore = {
        {39, 40}, {40, 40}, {41, 40}, {42, 40},
        {39, 41}, {40, 41}, {41, 41}, {42, 41},
        {39, 42}, {40, 42}, {41, 42}, {42, 42},
        {40, 43}, {41, 43},
    }
    for _, p in ipairs(sealCore) do
        setFloorIfOpen(self, T, p[1], p[2], T.CH6_SEAL_FLOOR)
    end

    local corruption = {
        {40, 34}, {41, 34}, {40, 35}, {41, 35},
        {40, 46}, {41, 46}, {40, 47}, {41, 47},
        {34, 40}, {34, 41}, {35, 40}, {35, 41},
        {46, 40}, {46, 41}, {47, 40}, {47, 41},
        {37, 37}, {44, 37}, {37, 45}, {44, 45},
    }
    for _, p in ipairs(corruption) do
        setFloorIfOpen(self, T, p[1], p[2], T.CH6_CORRUPTED_TOWN)
    end
end

function GameMap:BuildCh6Terrain()
    if not zd.IS_SHADOW_LIANGJIE then return end

    local T = zd.TILE
    buildSpawnSafeArea(self, T)
    buildBackhillExpansion(self, T)
    buildBanditBossRoom(self, T)
    buildVillageNorthRuins(self, T)
    buildBoarWaterBossArea(self, T)
    sealSpiderTrailLinks(self, T)
    buildTigerSealEntrance(self, T)
    narrowTrailTownEntrance(self, T)
    sealTownGates(self, T)

    decorateShadowEntrance(self, T)
    decorateShadowRuins(self, T)
    decorateMountainDomain(self, T)
    decorateCelestialCamps(self, T)
    decorateFrogMarsh(self, T)
    decorateTigerTrial(self, T)
    decorateTownSealCorruption(self, T)

    print("[Chapter6] Shadow Liangjie terrain post-process complete")
end

end
