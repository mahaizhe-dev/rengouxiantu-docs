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

    -- 用单格削边与外凸岩点打散矩形轮廓；右侧主封闭线仍保持不可穿透。
    local edgeCuts = {
        {34, 4, T.CAMP_FLOOR}, {35, 4, T.CAMP_FLOOR},
        {33, 6, T.CAMP_FLOOR}, {33, 14, T.CAMP_FLOOR},
        {54, 4, T.CAMP_FLOOR}, {55, 5, T.CAMP_FLOOR},
        {54, 20, T.GRASS}, {55, 18, T.GRASS},
        {50, 20, T.CAMP_FLOOR}, {36, 20, T.GRASS},
    }
    for _, p in ipairs(edgeCuts) do
        safeTile(self, p[1], p[2], p[3])
    end
    local edgeOutcrops = {
        {32, 7}, {32, 13}, {34, 3}, {39, 3}, {48, 3}, {52, 3},
        {56, 9}, {56, 17}, {52, 21}, {37, 21},
    }
    for _, p in ipairs(edgeOutcrops) do
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
    -- 呱大人领地左下角湖泊：水域包围湖心岛，东北侧保留 2 格宽自然入口。
    -- 碰撞/通行设计：WATER 不可行走；FOREST_FLOOR 入口链必须保持四向连通到 BOSS 岛。
    local cx, cy = 12, 73
    local rx, ry = 11.0, 8.2

    for y = 62, 79 do
        for x = 2, 27 do
            local nx = (x - cx) / rx
            local ny = (y - cy) / ry
            local d = nx * nx + ny * ny
            local h = hash100(x, y, 666)
            local wobble = (h - 50) / 100 * 0.18
            local mouth = x >= 15 and x <= 25 and y >= 64 and y <= 73
                and math.abs(y - (73 - math.floor((x - 15) * 0.55))) <= 3

            if not mouth then
                if d <= 1.02 + wobble then
                    safeTile(self, x, y, T.WATER)
                elseif d <= 1.18 + wobble and h < 48 then
                    safeTile(self, x, y, T.SWAMP)
                end
            elseif d <= 1.12 + wobble and h < 22 then
                safeTile(self, x, y, T.SWAMP)
            end
        end
    end

    -- 湖心岛做成椭圆削边，不再是硬矩形；中心保留给呱大人。
    local islandCx, islandCy = 11.5, 73.6
    for y = 69, 78 do
        for x = 6, 16 do
            local nx = (x - islandCx) / 5.0
            local ny = (y - islandCy) / 4.3
            local d = nx * nx + ny * ny
            local h = hash100(x, y, 667)
            if d <= 1.0 + (h - 50) / 100 * 0.12 then
                safeTile(self, x, y, T.FOREST_FLOOR)
            elseif d <= 1.12 and h < 35 then
                safeTile(self, x, y, T.SWAMP)
            end
        end
    end

    -- 四株白莲的落点与 BOSS 中心必须为陆地。
    local islandKeyTiles = {
        {8, 71}, {14, 71}, {8, 76}, {14, 76},
        {10, 72}, {11, 72}, {12, 72}, {11, 73}, {12, 73}, {11, 74}, {12, 74},
    }
    for _, p in ipairs(islandKeyTiles) do
        safeTile(self, p[1], p[2], T.FOREST_FLOOR)
    end

    -- 东北入口：错落的林地/浅沼形成自然堤岸，确保不被水面堵死。
    local entranceTiles = {
        {24, 64}, {23, 64}, {23, 65}, {22, 65}, {22, 66},
        {21, 66}, {21, 67}, {20, 67}, {20, 68}, {19, 68},
        {19, 69}, {18, 69}, {18, 70}, {17, 70}, {17, 71},
        {16, 71}, {16, 72}, {15, 72}, {15, 73}, {14, 73},
    }
    for _, p in ipairs(entranceTiles) do
        safeTile(self, p[1], p[2], T.FOREST_FLOOR)
    end
    local shoreTiles = {
        {25, 65}, {24, 66}, {23, 66}, {22, 67}, {21, 68},
        {20, 69}, {19, 70}, {18, 71}, {17, 72}, {16, 73},
    }
    for _, p in ipairs(shoreTiles) do
        local tile = self:GetTile(p[1], p[2])
        if tile == T.WATER then
            safeTile(self, p[1], p[2], T.SWAMP)
        end
    end
end

local function sealEastCampTrailLinks(self, T)
    -- 封锁羊肠小径与东大营的直接南北入口，东大营必须从村子下方外围绕行。
    fillRect(self, 57, 50, 64, 54, T.MOUNTAIN)
    fillRect(self, 73, 50, 78, 54, T.MOUNTAIN)

    -- 山脊封口保留核心阻挡，只打散外沿，避免看成两块方形补丁。
    local edgeCuts = {
        {57, 50, T.GRASS}, {64, 50, T.GRASS},
        {57, 54, T.FOREST_FLOOR}, {64, 54, T.CAMP_FLOOR},
        {73, 50, T.GRASS}, {78, 50, T.GRASS},
        {73, 54, T.FOREST_FLOOR}, {78, 54, T.CAMP_FLOOR},
    }
    for _, p in ipairs(edgeCuts) do
        safeTile(self, p[1], p[2], p[3])
    end
    local outcrops = {
        {56, 51}, {59, 55}, {62, 49}, {65, 53},
        {72, 52}, {74, 55}, {76, 49}, {79, 51},
    }
    for _, p in ipairs(outcrops) do
        safeTile(self, p[1], p[2], T.MOUNTAIN)
    end

    -- 保留东大营西北侧从呱大人领地方向进入的绕行口。
    carveRoad(self, 43, 52, 48, 54, T.CAMP_FLOOR)
    carveRoad(self, 39, 55, 44, 59, T.FOREST_FLOOR)
end

local function tileByName(T, tileName, fallback)
    if tileName and T[tileName] then
        return T[tileName]
    end
    return fallback
end

local function applyFutureDungeonBarrier(self, T, barrierKey)
    local barriers = zd.FUTURE_DUNGEON_BARRIERS
    local cfg = barriers and barriers[barrierKey]
    if not cfg then return end

    local sealTile = tileByName(T, cfg.tile, T.SEALED_GATE or T.WALL)

    for _, rect in ipairs(cfg.mountainRects or {}) do
        fillRect(self, rect.x1, rect.y1, rect.x2, rect.y2, T.MOUNTAIN)
    end

    local b = cfg.bounds
    if b then
        for x = b.x1, b.x2 do
            safeTile(self, x, b.y1, sealTile)
            safeTile(self, x, b.y2, sealTile)
        end
        for y = b.y1 + 1, b.y2 - 1 do
            safeTile(self, b.x1, y, sealTile)
            safeTile(self, b.x2, y, sealTile)
        end
    end

    local scatter = cfg.scatter or {}
    local top = scatter.top
    if top then
        for x = top.x1, top.x2 do
            if hash100(x, top.y, top.seed) < top.threshold then
                safeTile(self, x, top.y, sealTile)
            end
        end
    end
    local bottom = scatter.bottom
    if bottom then
        for x = bottom.x1, bottom.x2 do
            if hash100(x, bottom.y, bottom.seed) < bottom.threshold then
                safeTile(self, x, bottom.y, sealTile)
            end
        end
    end
    local left = scatter.left
    if left then
        for y = left.y1, left.y2 do
            if hash100(left.x, y, left.seed) < left.threshold then
                safeTile(self, left.x, y, sealTile)
            end
        end
    end
    local right = scatter.right
    if right then
        for y = right.y1, right.y2 do
            if hash100(right.x, y, right.seed) < right.threshold then
                safeTile(self, right.x, y, sealTile)
            end
        end
    end

    if cfg.formerGate then
        fillRect(self, cfg.formerGate.x1, cfg.formerGate.y1, cfg.formerGate.x2, cfg.formerGate.y2, sealTile)
    end
    for _, rect in ipairs(cfg.sealRects or {}) do
        fillRect(self, rect.x1, rect.y1, rect.x2, rect.y2, sealTile)
    end
    if cfg.approachRoad then
        carveRoad(self, cfg.approachRoad.x1, cfg.approachRoad.y1, cfg.approachRoad.x2, cfg.approachRoad.y2,
            tileByName(T, cfg.approachRoad.tile, T.GRASS))
    end
    for _, p in ipairs(cfg.blockers or {}) do
        safeTile(self, p.x, p.y, tileByName(T, p.tile, T.MOUNTAIN))
    end
    for _, p in ipairs(cfg.edgeBreakup or {}) do
        safeTile(self, p.x, p.y, tileByName(T, p.tile, T.MOUNTAIN))
    end
end

local function buildTigerSealEntrance(self, T)
    -- 虎王试炼地是未来副本入口：只封原小门洞，不扩大成独立大空间。
    applyFutureDungeonBarrier(self, T, "tiger_trial")
end

local function narrowTrailTownEntrance(self, T)
    -- 收窄羊肠小径通往两界村方向的西侧入口；保留村外 x=49~51 环路畅通。
    fillRect(self, 52, 37, 54, 39, T.MOUNTAIN)
    fillRect(self, 52, 42, 54, 44, T.MOUNTAIN)
    carveRoad(self, 49, 40, 54, 41, T.GRASS)

    local edgeCuts = {
        {52, 37, T.GRASS}, {54, 39, T.GRASS},
        {52, 44, T.GRASS}, {54, 42, T.GRASS},
    }
    for _, p in ipairs(edgeCuts) do
        safeTile(self, p[1], p[2], p[3])
    end
    local outcrops = {
        {51, 38}, {55, 38}, {51, 43}, {55, 43},
    }
    for _, p in ipairs(outcrops) do
        safeTile(self, p[1], p[2], T.MOUNTAIN)
    end
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
    return tile ~= T.MOUNTAIN and tile ~= T.WALL and tile ~= T.WATER
        and tile ~= T.SEALED_GATE
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
            if tile == T.CAMP_FLOOR or tile == T.TOWN_FLOOR or tile == T.GRASS then
                local h = hash100(x, y, 626)
                local northBias = (r.y2 - y) / math.max(1, r.y2 - r.y1)
                local centerBias = 1 - math.min(1, math.abs(x - 44) / 13)
                local ridge = northBias * 0.55 + centerBias * 0.28 + (hash100(x, y, 627) - 50) / 150
                if ridge > 0.62 and h < 58 then
                    safeTile(self, x, y, T.CH6_MOUNTAIN_STONE)
                elseif ridge > 0.38 and h < 34 then
                    safeTile(self, x, y, T.CH6_MOUNTAIN_RUNE)
                elseif h < 48 and T.CAMP_DIRT then
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

    local crystalVein = {
        {35, 7}, {36, 8}, {38, 9}, {41, 10}, {44, 11},
        {47, 11}, {50, 10}, {52, 9}, {53, 12}, {51, 15},
        {48, 16}, {45, 17}, {41, 17}, {38, 16}, {36, 14},
    }
    for _, p in ipairs(crystalVein) do
        setFloorIfOpen(self, T, p[1], p[2], T.CH6_MOUNTAIN_RUNE)
    end
end

local function decorateCelestialCamps(self, T)
    -- 东西大营只做装饰性晶痕符点，不整体替换营地底色。
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
        {66, 28}, {67, 28}, {68, 28}, {69, 28},
        {66, 29}, {67, 29}, {68, 29}, {69, 29}, {70, 29},
        {67, 30}, {68, 30}, {69, 30},
        {66, 31}, {69, 31},
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
    sealEastCampTrailLinks(self, T)
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
