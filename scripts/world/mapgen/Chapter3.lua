-- ============================================================================
-- mapgen/Chapter3.lua - 第三章地形生成（沙漠城寨、道路、美化）
-- ============================================================================

---@param GameMap table
---@param activeZoneData table
return function(GameMap, activeZoneData)

function GameMap:BuildCh3SandFortresses()
    local fortGrid = activeZoneData.fortGrid
    local GRID = activeZoneData.GRID
    if not fortGrid or not GRID then return end  -- 非第三章跳过

    local T = activeZoneData.TILE

    -- 第一步：全图填充沙漠底色（仅覆盖 GRASS，保留水域边界）
    for y = 2, self.height - 1 do
        for x = 2, self.width - 1 do
            if self.tiles[y][x] == T.GRASS then
                self.tiles[y][x] = T.DESERT
            end
        end
    end

    -- 第二步：逐寨填充内部地板 + 建造沙墙
    for row = 1, 3 do
        for col = 1, 3 do
            local fortModule = fortGrid[row][col]
            if not fortModule then goto nextFort end

            -- 从 zone 配置的 regions 获取实际范围
            local region = nil
            for _, reg in pairs(fortModule.regions) do
                region = reg
                break
            end
            if not region then goto nextFort end

            local x1, y1, x2, y2 = region.x1, region.y1, region.x2, region.y2
            local gen = fortModule.generation

            -- 填充城寨内部地板
            if gen and gen.special == "sand_fortress_ruins" then
                -- 废墟（第九寨）：上半区 SAND_FLOOR（安全区），下半区 DESERT（废墟残骸）
                local midY = y1 + math.floor((y2 - y1) / 2)
                for fy = y1, y2 do
                    for fx = x1, x2 do
                        if fy <= midY then
                            self:SetTile(fx, fy, T.SAND_FLOOR)
                        else
                            self:SetTile(fx, fy, T.DESERT)
                        end
                    end
                end
            else
                -- 普通城寨：全部 SAND_FLOOR
                for fy = y1, y2 do
                    for fx = x1, x2 do
                        self:SetTile(fx, fy, T.SAND_FLOOR)
                    end
                end
            end

            -- 建造沙墙
            local isRuins = gen and gen.special == "sand_fortress_ruins"
            local isBoss  = gen and gen.special == "sand_fortress_boss"
            local wallThick = (gen and gen.wallThick) or (isRuins and 2 or 1)
            local gapHalf = 1  -- 缺口半宽（中心 ±1 = 3 格宽）
            local cx = math.floor((x1 + x2) / 2)
            local cy = math.floor((y1 + y2) / 2)

            -- 判断是否跳过此墙格
            local function shouldSkip(wx, wy, depth)
                -- 废墟城寨：约 40% 概率留洞
                if isRuins then
                    local h = ((wx * 374761393 + wy * 668265263 + 77777) & 0x7FFFFFFF) % 100
                    return h < 40
                end
                -- Boss寨：外层(depth=0)实墙，内层(depth>=1)约50%随机残缺形成2-3格装饰
                if isBoss and depth >= 1 then
                    local h = ((wx * 271828183 + wy * 314159265 + depth * 99991) & 0x7FFFFFFF) % 100
                    return h < 50
                end
                return false
            end

            -- 北墙
            for d = 0, wallThick - 1 do
                local wy = y1 + d
                for wx = x1, x2 do
                    if math.abs(wx - cx) <= gapHalf then goto skipN end
                    if shouldSkip(wx, wy, d) then goto skipN end
                    self:SetTile(wx, wy, T.SAND_WALL)
                    ::skipN::
                end
            end
            -- 南墙
            for d = 0, wallThick - 1 do
                local wy = y2 - d
                for wx = x1, x2 do
                    if math.abs(wx - cx) <= gapHalf then goto skipS end
                    if shouldSkip(wx, wy, d) then goto skipS end
                    self:SetTile(wx, wy, T.SAND_WALL)
                    ::skipS::
                end
            end
            -- 西墙
            for d = 0, wallThick - 1 do
                local wx = x1 + d
                for wy = y1, y2 do
                    if math.abs(wy - cy) <= gapHalf then goto skipW end
                    if shouldSkip(wx, wy, d) then goto skipW end
                    self:SetTile(wx, wy, T.SAND_WALL)
                    ::skipW::
                end
            end
            -- 东墙
            for d = 0, wallThick - 1 do
                local wx = x2 - d
                for wy = y1, y2 do
                    if math.abs(wy - cy) <= gapHalf then goto skipE end
                    if shouldSkip(wx, wy, d) then goto skipE end
                    self:SetTile(wx, wy, T.SAND_WALL)
                    ::skipE::
                end
            end

            ::nextFort::
        end
    end

    print("[GameMap] Ch3: Built 9 sand fortresses")
end

--- 构建第三章道路（城寨间 + 入口/出口）
function GameMap:BuildCh3Roads()
    local roads = activeZoneData.roads
    local GRID = activeZoneData.GRID
    local fortGrid = activeZoneData.fortGrid
    if not roads or not GRID or not fortGrid then return end

    local T = activeZoneData.TILE
    local roadW = 3  -- 道路宽度 3 格

    for _, road in ipairs(roads) do
        if road.type == "entrance" then
            -- 入口：地图顶部 → 城寨北墙
            local row, col = road.fort[1], road.fort[2]
            local fortModule = fortGrid[row][col]
            local region = nil
            for _, reg in pairs(fortModule.regions) do region = reg; break end
            if not region then goto nextRoad end
            local cx = math.floor((region.x1 + region.x2) / 2)
            -- 从 y=2 到城寨北墙
            for y = 2, region.y1 do
                for w = 0, roadW - 1 do
                    local x = cx - 1 + w
                    local tile = self:GetTile(x, y)
                    if tile ~= T.WATER and tile ~= T.SAND_WALL then
                        self:SetTile(x, y, T.SAND_ROAD)
                    end
                end
            end

        elseif road.type == "exit" then
            -- 出口：城寨南墙 → 地图底部
            local row, col = road.fort[1], road.fort[2]
            local fortModule = fortGrid[row][col]
            local region = nil
            for _, reg in pairs(fortModule.regions) do region = reg; break end
            if not region then goto nextRoad end
            local cx = math.floor((region.x1 + region.x2) / 2)
            for y = region.y2, self.height - 1 do
                for w = 0, roadW - 1 do
                    local x = cx - 1 + w
                    local tile = self:GetTile(x, y)
                    if tile ~= T.WATER and tile ~= T.SAND_WALL then
                        self:SetTile(x, y, T.SAND_ROAD)
                    end
                end
            end

        else
            -- 寨间道路
            local fromRow, fromCol = road.from[1], road.from[2]
            local toRow, toCol = road.to[1], road.to[2]
            local fromModule = fortGrid[fromRow][fromCol]
            local toModule = fortGrid[toRow][toCol]
            local fromRegion, toRegion = nil, nil
            for _, reg in pairs(fromModule.regions) do fromRegion = reg; break end
            for _, reg in pairs(toModule.regions) do toRegion = reg; break end
            if not fromRegion or not toRegion then goto nextRoad end

            if road.axis == "h" then
                -- 横向：从 fromRegion.x2 → toRegion.x1
                local cy = math.floor((fromRegion.y1 + fromRegion.y2) / 2)
                local sx = fromRegion.x2 + 1
                local ex = toRegion.x1 - 1
                for x = sx, ex do
                    for w = 0, roadW - 1 do
                        local y = cy - 1 + w
                        local tile = self:GetTile(x, y)
                        if tile ~= T.WATER and tile ~= T.SAND_WALL then
                            self:SetTile(x, y, T.SAND_ROAD)
                        end
                    end
                end
            elseif road.axis == "v" then
                -- 纵向：从 fromRegion.y2 → toRegion.y1
                local cx = math.floor((fromRegion.x1 + fromRegion.x2) / 2)
                local sy = fromRegion.y2 + 1
                local ey = toRegion.y1 - 1
                for y = sy, ey do
                    for w = 0, roadW - 1 do
                        local x = cx - 1 + w
                        local tile = self:GetTile(x, y)
                        if tile ~= T.WATER and tile ~= T.SAND_WALL then
                            self:SetTile(x, y, T.SAND_ROAD)
                        end
                    end
                end
            end
        end
        ::nextRoad::
    end

    print("[GameMap] Ch3: Built " .. #roads .. " roads")
end

--- 第三章地形美化（沙丘散布 + 废墟碎石 + 道路两侧风沙）
function GameMap:BeautifyCh3Terrain()
    local fortGrid = activeZoneData.fortGrid
    local GRID = activeZoneData.GRID
    if not fortGrid or not GRID then return end

    local T = activeZoneData.TILE
    local W = activeZoneData.WALKABLE
    local fort9Data = activeZoneData.fort9Data
    local decos = activeZoneData.TownDecorations  -- 动态追加装饰物

    local function hash(x, y, seed)
        return ((x * 374761393 + y * 668265263 + seed) & 0x7FFFFFFF)
    end
    local function hashPct(x, y, seed)
        return hash(x, y, seed) % 100
    end

    -- 判断是否在城寨/道路/水体附近（排除这些区域不做地形替换）
    local function nearStructure(x, y, radius)
        for dy = -radius, radius do
            for dx = -radius, radius do
                local nx, ny = x + dx, y + dy
                if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                    local nt = self.tiles[ny][nx]
                    if nt == T.SAND_ROAD or nt == T.SAND_FLOOR or nt == T.SAND_WALL then
                        return true
                    end
                end
            end
        end
        return false
    end

    -- ================================================================
    -- 三环分层系统：
    --   外环(1): 第9/8/7寨 → row+col ≤ 3
    --   中环(2): 第6/5/4寨 → row+col = 4
    --   内环(3): 第3/2/1寨 → row+col ≥ 5
    -- ================================================================
    local function getRingLevel(x, y)
        local gridRow, gridCol
        if y <= 27 then gridRow = 1
        elseif y <= 51 then gridRow = 2
        else gridRow = 3 end
        if x <= 27 then gridCol = 1
        elseif x <= 51 then gridCol = 2
        else gridCol = 3 end
        local sum = gridRow + gridCol
        if sum <= 3 then return 1 end
        if sum <= 4 then return 2 end
        return 3
    end

    -- ================================================================
    -- 0. 沙色变体分布（SAND_DARK / SAND_LIGHT / DRIED_GRASS）
    --    在放置岩块之前先给沙漠地形染色
    -- ================================================================
    -- SAND_DARK:  道路两侧 1 格路肩 + 内环踩踏区
    -- SAND_LIGHT: 外环开阔地带（远离道路/城寨）
    -- DRIED_GRASS: 水体附近 2~3 格范围
    if T.SAND_DARK then
        for y = 3, self.height - 2 do
            for x = 3, self.width - 2 do
                local tile = self.tiles[y][x]
                if tile ~= T.DESERT then goto skipSandVar end

                -- 检查水体附近 → DRIED_GRASS
                local nearWater = false
                for dy = -3, 3 do
                    for dx = -3, 3 do
                        local nx, ny = x + dx, y + dy
                        if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                            if self.tiles[ny][nx] == T.WATER then
                                nearWater = true; break
                            end
                        end
                    end
                    if nearWater then break end
                end
                if nearWater then
                    -- 距水越近概率越高
                    local waterDist = 3
                    for dy = -2, 2 do
                        for dx = -2, 2 do
                            local nx, ny = x + dx, y + dy
                            if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                                if self.tiles[ny][nx] == T.WATER then
                                    local d = math.abs(dx) + math.abs(dy)
                                    if d < waterDist then waterDist = d end
                                end
                            end
                        end
                    end
                    local grassPct = waterDist <= 1 and 80 or (waterDist <= 2 and 50 or 25)
                    if hashPct(x, y, 69000) < grassPct then
                        self:SetTile(x, y, T.DRIED_GRASS)
                        goto skipSandVar
                    end
                end

                -- 检查道路附近 1 格 → SAND_DARK（路肩）
                local adjRoad = false
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if dx == 0 and dy == 0 then goto nextRAdj end
                        local nx, ny = x + dx, y + dy
                        if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                            if self.tiles[ny][nx] == T.SAND_ROAD then
                                adjRoad = true; break
                            end
                        end
                        ::nextRAdj::
                    end
                    if adjRoad then break end
                end
                if adjRoad then
                    if hashPct(x, y, 69010) < 70 then
                        self:SetTile(x, y, T.SAND_DARK)
                        goto skipSandVar
                    end
                end

                -- 远离结构物的外环开阔地 → SAND_LIGHT
                local ring = getRingLevel(x, y)
                if ring == 1 and not nearStructure(x, y, 3) then
                    if hashPct(x, y, 69020) < 35 then
                        self:SetTile(x, y, T.SAND_LIGHT)
                    end
                elseif ring == 2 and not nearStructure(x, y, 3) then
                    if hashPct(x, y, 69020) < 20 then
                        self:SetTile(x, y, T.SAND_LIGHT)
                    elseif hashPct(x, y, 69025) < 10 then
                        self:SetTile(x, y, T.SAND_DARK)
                    end
                elseif ring == 3 and not nearStructure(x, y, 2) then
                    -- 内环更多踩踏痕迹
                    if hashPct(x, y, 69025) < 15 then
                        self:SetTile(x, y, T.SAND_DARK)
                    end
                end

                ::skipSandVar::
            end
        end
    end

    -- ================================================================
    -- 1. 三环密度岩块散布 + 簇群自然化（L/T 形）
    -- ================================================================
    local ringParams = {
        [1] = { rockPct = 3,  clusterPct = 25, maxExtra = 2, debrisPct = 0 },
        [2] = { rockPct = 8,  clusterPct = 35, maxExtra = 2, debrisPct = 0 },
        [3] = { rockPct = 12, clusterPct = 45, maxExtra = 3, debrisPct = 5 },
    }
    -- L/T 形簇群模板（相对偏移）
    local clusterShapes = {
        { {1,0}, {0,1} },              -- L 形
        { {-1,0}, {0,1} },             -- 反 L
        { {1,0}, {0,-1} },             -- 反 L2
        { {1,0}, {-1,0} },             -- 横线
        { {0,1}, {0,-1} },             -- 竖线
        { {1,0}, {0,1}, {1,1} },       -- 方块
        { {1,0}, {-1,0}, {0,1} },      -- T 形
        { {1,0}, {-1,0}, {0,-1} },     -- 倒 T
    }

    for y = 3, self.height - 2 do
        for x = 3, self.width - 2 do
            local tile = self.tiles[y][x]
            -- 允许在 DESERT / SAND_LIGHT / SAND_DARK 上放岩块
            if tile ~= T.DESERT and tile ~= T.SAND_LIGHT
               and (not T.SAND_DARK or tile ~= T.SAND_DARK) then
                goto skipScatter
            end

            if nearStructure(x, y, 2) then goto skipScatter end

            local ring = getRingLevel(x, y)
            local params = ringParams[ring]

            if hashPct(x, y, 70001) < params.rockPct then
                self:SetTile(x, y, T.MOUNTAIN)
                -- 簇群延伸：使用 L/T 形模板
                if hashPct(x, y, 70002) < params.clusterPct then
                    local shapeIdx = (hash(x, y, 70009) % #clusterShapes) + 1
                    local shape = clusterShapes[shapeIdx]
                    local numPlace = math.min(#shape, params.maxExtra)
                    for i = 1, numPlace do
                        local off = shape[i]
                        local nx2, ny2 = x + off[1], y + off[2]
                        if nx2 >= 3 and nx2 <= self.width - 2
                           and ny2 >= 3 and ny2 <= self.height - 2 then
                            local nt = self.tiles[ny2][nx2]
                            if nt == T.DESERT or nt == T.SAND_LIGHT
                               or (T.SAND_DARK and nt == T.SAND_DARK) then
                                self:SetTile(nx2, ny2, T.MOUNTAIN)
                            end
                        end
                    end
                end
                -- 岩块阴影：簇群旁放 SAND_DARK
                if T.SAND_DARK then
                    local shadowDir = hash(x, y, 70015) % 4
                    local sdOff = { {1,1}, {-1,1}, {1,-1}, {-1,-1} }
                    local so = sdOff[shadowDir + 1]
                    local sx, sy = x + so[1], y + so[2]
                    if sx >= 3 and sx <= self.width - 2 and sy >= 3 and sy <= self.height - 2 then
                        local st = self.tiles[sy][sx]
                        if st == T.DESERT or st == T.SAND_LIGHT then
                            self:SetTile(sx, sy, T.SAND_DARK)
                        end
                    end
                end
            end

            -- 内环：废墟碎片
            if ring == 3 and self.tiles[y][x] == T.DESERT
               and hashPct(x, y, 70050) < params.debrisPct then
                self:SetTile(x, y, T.SAND_WALL)
            end

            ::skipScatter::
        end
    end

    -- ================================================================
    -- 2. 道路磨损 + 路旁碎石（中环/内环递增）
    -- ================================================================
    local roadRubblePct = { [1] = 0, [2] = 12, [3] = 20 }
    for y = 3, self.height - 2 do
        for x = 3, self.width - 2 do
            local tile = self.tiles[y][x]

            -- 道路磨损：5~8% 的道路格替换为 SAND_DARK（脚印/车辙）
            if tile == T.SAND_ROAD and T.SAND_DARK then
                local ring = getRingLevel(x, y)
                local wearPct = ring == 1 and 5 or (ring == 2 and 7 or 8)
                if hashPct(x, y, 70310) < wearPct then
                    self:SetTile(x, y, T.SAND_DARK)
                end
                goto skipRoadTrans
            end

            -- 路旁碎石
            if tile ~= T.DESERT and (not T.SAND_DARK or tile ~= T.SAND_DARK)
               and (not T.SAND_LIGHT or tile ~= T.SAND_LIGHT) then
                goto skipRoadTrans
            end
            do
                local nearRoad = false
                for dy = -2, 2 do
                    for dx = -2, 2 do
                        if dx == 0 and dy == 0 then goto nextAdj end
                        local nx, ny = x + dx, y + dy
                        if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                            if self.tiles[ny][nx] == T.SAND_ROAD then
                                nearRoad = true; break
                            end
                        end
                        ::nextAdj::
                    end
                    if nearRoad then break end
                end
                if nearRoad then
                    local ring = getRingLevel(x, y)
                    local pct = roadRubblePct[ring] or 0
                    if pct > 0 and hashPct(x, y, 70300) < pct then
                        self:SetTile(x, y, T.MOUNTAIN)
                    end
                end
            end
            ::skipRoadTrans::
        end
    end

    -- ================================================================
    -- 3. 自然地标
    -- ================================================================
    -- 3a. 绿洲（外环 ~26,26）：5×5 不规则水体 + DRIED_GRASS 过渡环 + 棕榈树
    local oasisCx, oasisCy = 26, 26
    for dy = -3, 3 do
        for dx = -3, 3 do
            local lx, ly = oasisCx + dx, oasisCy + dy
            if lx < 2 or ly < 2 or lx > self.width - 1 or ly > self.height - 1 then goto skipOasis end
            local adx, ady = math.abs(dx), math.abs(dy)
            if adx <= 2 and ady <= 2 then
                -- 5×5 核心区：角落概率性削去形成不规则形状
                if adx == 2 and ady == 2 then
                    if hashPct(lx, ly, 69100) < 50 then
                        self:SetTile(lx, ly, T.WATER)
                    elseif T.DRIED_GRASS then
                        self:SetTile(lx, ly, T.DRIED_GRASS)
                    end
                else
                    self:SetTile(lx, ly, T.WATER)
                end
            elseif adx + ady <= 4 then
                -- 外环：DRIED_GRASS 过渡
                if T.DRIED_GRASS then
                    if hashPct(lx, ly, 69110) < 60 then
                        self:SetTile(lx, ly, T.DRIED_GRASS)
                    end
                else
                    self:SetTile(lx, ly, T.SAND_FLOOR)
                end
            end
            ::skipOasis::
        end
    end
    -- 绿洲周围棕榈树（4 棵，对称分布）
    if decos then
        table.insert(decos, { type = "palm_tree", x = oasisCx - 3, y = oasisCy - 1 })
        table.insert(decos, { type = "palm_tree", x = oasisCx + 3, y = oasisCy + 1 })
        table.insert(decos, { type = "palm_tree", x = oasisCx - 1, y = oasisCy + 3 })
        table.insert(decos, { type = "palm_tree", x = oasisCx + 1, y = oasisCy - 3 })
    end

    -- 3b. 枯井（中环 ~26,52）：1 格水 + 四周岩石
    self:SetTile(26, 52, T.WATER)
    for _, off in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        self:SetTile(26 + off[1], 52 + off[2], T.MOUNTAIN)
    end
    -- 枯井旁枯草
    if T.DRIED_GRASS then
        for _, off in ipairs({{2,0},{-2,0},{0,2},{0,-2},{1,1},{-1,1},{1,-1},{-1,-1}}) do
            local wx, wy = 26 + off[1], 52 + off[2]
            if wx >= 2 and wy >= 2 and wx <= self.width - 1 and wy <= self.height - 1 then
                local t = self.tiles[wy][wx]
                if t == T.DESERT or (T.SAND_LIGHT and t == T.SAND_LIGHT) then
                    self:SetTile(wx, wy, T.DRIED_GRASS)
                end
            end
        end
    end

    -- 3c. 废弃营地（中环 ~52,26）：小片 SAND_FLOOR + 死灌木
    for dy = -1, 1 do
        for dx = -1, 1 do
            self:SetTile(52 + dx, 26 + dy, T.SAND_FLOOR)
        end
    end
    if decos then
        table.insert(decos, { type = "dead_bush", x = 54, y = 25 })
        table.insert(decos, { type = "dead_bush", x = 50, y = 27 })
    end

    -- 3d. 干涸河床（从绿洲向东南延伸，2~3 格宽 SAND_DARK 带 DRIED_GRASS 岸）
    if T.SAND_DARK then
        local rbX, rbY = oasisCx + 3, oasisCy + 2
        for step = 0, 12 do
            local cx = rbX + step
            local cy = rbY + math.floor(step * 0.5)
            if cx > self.width - 2 or cy > self.height - 2 then break end
            -- 河床中心 2 格
            for w = 0, 1 do
                local rx, ry = cx, cy + w
                if ry <= self.height - 2 then
                    local t = self.tiles[ry][rx]
                    if t == T.DESERT or t == T.SAND_LIGHT then
                        self:SetTile(rx, ry, T.SAND_DARK)
                    end
                end
            end
            -- 河岸 DRIED_GRASS
            if T.DRIED_GRASS then
                for _, bankOff in ipairs({{0,-1},{0,2},{1,-1},{1,2}}) do
                    local bx, by = cx + bankOff[1], cy + bankOff[2]
                    if bx >= 2 and by >= 2 and bx <= self.width - 1 and by <= self.height - 1 then
                        local bt = self.tiles[by][bx]
                        if bt == T.DESERT or bt == T.SAND_LIGHT then
                            if hashPct(bx, by, 69200) < 60 then
                                self:SetTile(bx, by, T.DRIED_GRASS)
                            end
                        end
                    end
                end
            end
        end
    end

    -- 3e. 沙丘带（走廊区域：外环南北、中环东西的开阔地带）
    --     SAND_LIGHT + SAND_DARK 交替条纹，不阻挡通行
    if T.SAND_LIGHT and T.SAND_DARK then
        -- 走廊1: y=24~29 左半区（湖泊左侧空地）
        for y = 24, 29 do
            for x = 3, 25 do
                local t = self.tiles[y][x]
                if t == T.DESERT then
                    -- 对角线条纹
                    local stripe = (x + y) % 5
                    if stripe == 0 then
                        self:SetTile(x, y, T.SAND_LIGHT)
                    elseif stripe == 2 then
                        if hashPct(x, y, 69300) < 40 then
                            self:SetTile(x, y, T.SAND_DARK)
                        end
                    end
                end
            end
        end
        -- 走廊2: x=52~76, y=50~55（东侧宽阔地带）
        for y = 50, 55 do
            for x = 52, 76 do
                local t = self.tiles[y][x]
                if t == T.DESERT then
                    local stripe = (x + y * 2) % 6
                    if stripe <= 1 then
                        self:SetTile(x, y, T.SAND_LIGHT)
                    elseif stripe == 3 then
                        if hashPct(x, y, 69310) < 35 then
                            self:SetTile(x, y, T.SAND_DARK)
                        end
                    end
                end
            end
        end
    end

    -- ================================================================
    -- 4. 天然地形隔断带（多类型：湖泊 / 散布岩石 / 混合地形）
    -- ================================================================

    -- 辅助A：有机湖泊填充（带边缘散播）
    local function fillNaturalLake(lx1, ly1, lx2, ly2, coreInset)
        coreInset = coreInset or 1
        lx1 = math.max(2, lx1)
        ly1 = math.max(2, ly1)
        lx2 = math.min(self.width - 1, lx2)
        ly2 = math.min(self.height - 1, ly2)

        for y = ly1, ly2 do
            for x = lx1, lx2 do
                local tile = self.tiles[y][x]
                if tile == T.SAND_WALL or tile == T.SAND_FLOOR then goto skipLake end
                local distToEdge = math.min(x - lx1, lx2 - x, y - ly1, ly2 - y)
                if distToEdge >= coreInset then
                    self:SetTile(x, y, T.WATER)
                else
                    local h = hashPct(x, y, 70400)
                    if h < 55 then self:SetTile(x, y, T.WATER)
                    elseif h < 75 then self:SetTile(x, y, T.SAND_FLOOR) end
                end
                ::skipLake::
            end
        end
        -- 边缘散播
        for y = ly1 - 2, ly2 + 2 do
            for x = lx1 - 2, lx2 + 2 do
                if x >= lx1 and x <= lx2 and y >= ly1 and y <= ly2 then goto skipSpray end
                if x < 2 or y < 2 or x > self.width - 1 or y > self.height - 1 then goto skipSpray end
                local tile = self.tiles[y][x]
                if tile == T.SAND_WALL or tile == T.SAND_FLOOR or tile == T.WATER then goto skipSpray end
                local dist = 0
                if x < lx1 then dist = dist + (lx1 - x) end
                if x > lx2 then dist = dist + (x - lx2) end
                if y < ly1 then dist = dist + (ly1 - y) end
                if y > ly2 then dist = dist + (y - ly2) end
                local h = hashPct(x, y, 70410)
                if dist <= 1 then
                    if h < 25 then self:SetTile(x, y, T.WATER)
                    elseif h < 50 then self:SetTile(x, y, T.SAND_FLOOR) end
                elseif h < 10 then self:SetTile(x, y, T.WATER)
                elseif h < 25 then self:SetTile(x, y, T.SAND_FLOOR) end
                ::skipSpray::
            end
        end
    end

    -- 辅助B：散布式隔断
    local function fillScatteredBarrier(lx1, ly1, lx2, ly2, seed)
        lx1 = math.max(2, lx1)
        ly1 = math.max(2, ly1)
        lx2 = math.min(self.width - 1, lx2)
        ly2 = math.min(self.height - 1, ly2)
        seed = seed or 70500
        local blockTypes = { T.MOUNTAIN, T.WATER, T.MOUNTAIN, T.MOUNTAIN }

        for y = ly1, ly2 do
            for x = lx1, lx2 do
                local tile = self.tiles[y][x]
                if tile == T.SAND_WALL or tile == T.SAND_FLOOR then goto skipSB end
                local h = hashPct(x, y, seed)
                if h < 78 then
                    local idx = (hashPct(x, y, seed + 7) % #blockTypes) + 1
                    self:SetTile(x, y, blockTypes[idx])
                else
                    self:SetTile(x, y, T.DESERT)
                end
                ::skipSB::
            end
        end

        -- 安全校验：逐列确保不可穿越
        for x = lx1, lx2 do
            local allWalkable = true
            for y = ly1, ly2 do
                local tile = self.tiles[y][x]
                if not W[tile] then
                    allWalkable = false
                    break
                end
            end
            if allWalkable then
                local midY = math.floor((ly1 + ly2) / 2)
                local idx = (hashPct(x, midY, seed + 20) % #blockTypes) + 1
                self:SetTile(x, midY, blockTypes[idx])
            end
        end

        -- 边缘散播
        for y = ly1 - 2, ly2 + 2 do
            for x = lx1 - 2, lx2 + 2 do
                if x >= lx1 and x <= lx2 and y >= ly1 and y <= ly2 then goto skipSE end
                if x < 2 or y < 2 or x > self.width - 1 or y > self.height - 1 then goto skipSE end
                local tile = self.tiles[y][x]
                if tile == T.SAND_WALL or tile == T.SAND_FLOOR or tile == T.WATER or tile == T.MOUNTAIN then goto skipSE end
                local dist = 0
                if x < lx1 then dist = dist + (lx1 - x) end
                if x > lx2 then dist = dist + (x - lx2) end
                if y < ly1 then dist = dist + (ly1 - y) end
                if y > ly2 then dist = dist + (y - ly2) end
                local h = hashPct(x, y, seed + 30)
                if dist <= 1 then
                    if h < 20 then
                        local idx = (hashPct(x, y, seed + 40) % #blockTypes) + 1
                        self:SetTile(x, y, blockTypes[idx])
                    elseif h < 35 then
                        self:SetTile(x, y, T.DESERT)
                    end
                elseif h < 8 then
                    local idx = (hashPct(x, y, seed + 40) % #blockTypes) + 1
                    self:SetTile(x, y, blockTypes[idx])
                end
                ::skipSE::
            end
        end
    end

    -- 4a. 第六寨↔第三寨：【湖泊】散播覆盖走廊 + 延伸至地图右侧
    --     左端延伸到 x=48，与第八寨右墙(x=47)衔接，封堵⑤⑥间缺口
    fillNaturalLake(48, 24, self.width - 1, 29, 1)
    -- 强制封死湖泊左下角接缝（⑤寨右墙上方，覆盖 coreInset 边缘概率缺口）
    for y = 24, 29 do
        for x = 48, 50 do
            local t = self.tiles[y][x]
            if t ~= T.SAND_WALL and t ~= T.SAND_FLOOR and t ~= T.WATER then
                self:SetTile(x, y, T.WATER)
            end
        end
    end

    -- 4b. 湖泊中央沙地岛（3×3 SAND_FLOOR，供朱老二NPC站立）
    local merchantPos = self.zoneData.MYSTERIOUS_MERCHANT_POS
    if merchantPos then
        for dy = -1, 1 do
            for dx = -1, 1 do
                self:SetTile(merchantPos.x + dx, merchantPos.y + dy, T.SAND_FLOOR)
            end
        end
    end

    -- 4c. 横贯隔断带：x=2~49, y=50~53（第五寨底y=49 ↔ 第四寨顶y=54）
    --      在 x=13~17 留 5 格缺口作为 ⑦→④ 通路
    fillScatteredBarrier(2, 50, 12, 53, 70500)    -- 左段
    fillScatteredBarrier(18, 50, 49, 53, 70510)   -- 右段
    -- 注意：角落封堵已移除 —— 第四寨扩大至 20×20 后
    --       北墙 y=54 覆盖 x=6~25，完全封堵了原先需要角落封堵的区域

    -- ================================================================
    -- 4.5 隔断过渡羽化（barrier 外围 3~4 格渐变带）
    -- ================================================================
    -- 在隔断带外围放置 SAND_DARK + 零星岩石，形成自然过渡
    if T.SAND_DARK then
        -- 横贯隔断（y=50~53）的上下过渡
        for _, band in ipairs({
            {2, 47, 49, 49},   -- 上方过渡：y=47~49
            {2, 54, 49, 56},   -- 下方过渡：y=54~56（注意避开城寨区域）
        }) do
            local bx1, by1, bx2, by2 = band[1], band[2], band[3], band[4]
            for y = by1, by2 do
                for x = bx1, bx2 do
                    if x < 2 or y < 2 or x > self.width - 1 or y > self.height - 1 then goto skipFeath end
                    local tile = self.tiles[y][x]
                    -- 只处理沙漠/沙变体，不覆盖城寨/道路/障碍
                    if tile ~= T.DESERT and tile ~= T.SAND_LIGHT
                       and tile ~= T.SAND_DARK and tile ~= T.DRIED_GRASS then
                        goto skipFeath
                    end
                    -- 距隔断越远概率越低
                    local distToBarrier = math.min(math.abs(y - 50), math.abs(y - 53))
                    local featherPct = distToBarrier <= 1 and 50 or (distToBarrier <= 2 and 30 or 15)
                    local h = hashPct(x, y, 69400)
                    if h < featherPct then
                        self:SetTile(x, y, T.SAND_DARK)
                    elseif h < featherPct + 8 then
                        self:SetTile(x, y, T.MOUNTAIN)  -- 零星碎石
                    end
                    ::skipFeath::
                end
            end
        end

        -- 湖泊隔断（y=24~29）的上下过渡
        for _, band in ipairs({
            {50, 21, self.width - 1, 23},  -- 上方
            {50, 30, self.width - 1, 32},  -- 下方
        }) do
            local bx1, by1, bx2, by2 = band[1], band[2], band[3], band[4]
            for y = by1, by2 do
                for x = bx1, bx2 do
                    if x < 2 or y < 2 or x > self.width - 1 or y > self.height - 1 then goto skipFeath2 end
                    local tile = self.tiles[y][x]
                    if tile ~= T.DESERT and tile ~= T.SAND_LIGHT
                       and tile ~= T.SAND_DARK then
                        goto skipFeath2
                    end
                    local distToLake = math.min(math.abs(y - 24), math.abs(y - 29))
                    local fp = distToLake <= 1 and 45 or 20
                    if hashPct(x, y, 69410) < fp then
                        if T.DRIED_GRASS then
                            self:SetTile(x, y, T.DRIED_GRASS)
                        else
                            self:SetTile(x, y, T.SAND_DARK)
                        end
                    end
                    ::skipFeath2::
                end
            end
        end
    end

    -- ================================================================
    -- 5. 废墟（第九寨）下半区散布碎石（约 8%）
    -- ================================================================
    if fort9Data then
        local region9 = nil
        for _, reg in pairs(fort9Data.regions) do region9 = reg; break end
        if region9 then
            local midY = region9.y1 + math.floor((region9.y2 - region9.y1) / 2)
            for y = midY + 1, region9.y2 do
                for x = region9.x1 + 2, region9.x2 - 2 do
                    local tile = self.tiles[y][x]
                    if tile == T.DESERT then
                        if hashPct(x, y, 70100) < 8 then
                            self:SetTile(x, y, T.MOUNTAIN)
                        end
                    end
                end
            end
        end
    end

    -- 5b. 第九寨废墟中央裂地遗迹（3×3 CRACKED_EARTH）+ 上宝逊金钯
    if fort9Data and T.CRACKED_EARTH then
        local region9 = nil
        for _, reg in pairs(fort9Data.regions) do region9 = reg; break end
        if region9 then
            local rakeCx = math.floor((region9.x1 + region9.x2) / 2)  -- 15
            local midY = region9.y1 + math.floor((region9.y2 - region9.y1) / 2)
            local rakeCy = midY + 2  -- 废墟区内，营火正下方
            for dy = -1, 1 do
                for dx = -1, 1 do
                    self:SetTile(rakeCx + dx, rakeCy + dy, T.CRACKED_EARTH)
                end
            end
            if decos then
                table.insert(decos, { type = "divine_rake", x = rakeCx, y = rakeCy })
            end
        end
    end

    -- ================================================================
    -- 6. 城寨内部少量装饰石柱（约 2%，远离门口）
    -- ================================================================
    for row = 1, 3 do
        for col = 1, 3 do
            local fortModule = fortGrid[row][col]
            if not fortModule then goto skipFortDeco end
            local gen = fortModule.generation
            if gen and gen.special == "sand_fortress_ruins" then goto skipFortDeco end

            local region = nil
            for _, reg in pairs(fortModule.regions) do region = reg; break end
            if not region then goto skipFortDeco end

            local cx = math.floor((region.x1 + region.x2) / 2)
            local cy = math.floor((region.y1 + region.y2) / 2)

            for y = region.y1 + 3, region.y2 - 3 do
                for x = region.x1 + 3, region.x2 - 3 do
                    if math.abs(x - cx) <= 3 and (y <= region.y1 + 4 or y >= region.y2 - 4) then
                        goto skipPillar
                    end
                    if math.abs(y - cy) <= 3 and (x <= region.x1 + 4 or x >= region.x2 - 4) then
                        goto skipPillar
                    end
                    local tile = self.tiles[y][x]
                    if tile == T.SAND_FLOOR and hashPct(x, y, 70200 + row * 10 + col) < 2 then
                        self:SetTile(x, y, T.SAND_WALL)
                    end
                    ::skipPillar::
                end
            end
            ::skipFortDeco::
        end
    end

    -- ================================================================
    -- 7. 程序化沙漠装饰物散布
    -- ================================================================
    if decos then
        -- 各环级装饰物参数
        local decoParams = {
            [1] = { cactus = 4, dead_bush = 3, sand_dune = 2, skull_marker = 0, broken_pillar = 0 },
            [2] = { cactus = 3, dead_bush = 3, sand_dune = 1, skull_marker = 1, broken_pillar = 1 },
            [3] = { cactus = 2, dead_bush = 2, sand_dune = 1, skull_marker = 2, broken_pillar = 2 },
        }

        for y = 3, self.height - 2 do
            for x = 3, self.width - 2 do
                local tile = self.tiles[y][x]
                -- 只在可通行沙漠地形上放装饰物
                if tile ~= T.DESERT and tile ~= T.SAND_LIGHT
                   and (not T.SAND_DARK or tile ~= T.SAND_DARK)
                   and (not T.DRIED_GRASS or tile ~= T.DRIED_GRASS) then
                    goto skipDeco
                end
                if nearStructure(x, y, 1) then goto skipDeco end

                local ring = getRingLevel(x, y)
                local dp = decoParams[ring]
                local h = hashPct(x, y, 69500)

                local threshold = 0
                -- 仙人掌
                threshold = threshold + dp.cactus
                if h < threshold then
                    table.insert(decos, { type = "cactus", x = x, y = y })
                    goto skipDeco
                end
                -- 枯灌木
                threshold = threshold + dp.dead_bush
                if h < threshold then
                    table.insert(decos, { type = "dead_bush", x = x, y = y })
                    goto skipDeco
                end
                -- 沙丘
                threshold = threshold + dp.sand_dune
                if h < threshold then
                    table.insert(decos, { type = "sand_dune", x = x, y = y })
                    goto skipDeco
                end
                -- 骷髅标记
                threshold = threshold + dp.skull_marker
                if h < threshold then
                    table.insert(decos, { type = "skull_marker", x = x, y = y })
                    goto skipDeco
                end
                -- 断柱
                threshold = threshold + dp.broken_pillar
                if h < threshold then
                    table.insert(decos, { type = "broken_pillar", x = x, y = y })
                    goto skipDeco
                end

                ::skipDeco::
            end
        end
    end

    print("[GameMap] Ch3: Terrain beautified (6-proposal naturalization)")

end

end
