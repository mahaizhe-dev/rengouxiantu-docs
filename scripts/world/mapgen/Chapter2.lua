-- ============================================================================
-- mapgen/Chapter2.lua - 第二章地形生成（堡垒、美化）
-- ============================================================================

---@param GameMap table
---@param activeZoneData table
return function(GameMap, activeZoneData)

function GameMap:BuildFortressOutline()
    local fortressData = activeZoneData.fortressData
    local skullData    = activeZoneData.skullData
    if not fortressData then return end  -- 非第二章跳过

    local T = activeZoneData.TILE
    local FWALL = T.FORTRESS_WALL

    local R = fortressData.regions
    local E1 = R.fortress_e1
    local E2 = R.fortress_e2
    local E3 = R.fortress_e3
    local E4 = R.fortress_e4

    -- ================================================================
    -- 从区域数据推算堡垒外墙边界（数据驱动，不再硬编码）
    -- ================================================================
    local outerX1 = E1.x1
    local outerY1 = math.min(E1.y1, E4.y1)
    local outerX2 = E1.x2
    local outerY2 = math.max(E2.y2, E4.y2)
    local wallThick = 2

    -- 构建通道/缺口开口集合（通道区域和东墙缺口不画墙）
    local passages = fortressData.passages or {}
    local eastGaps = fortressData.eastGaps or {}
    local function isOpening(x, y)
        for _, p in ipairs(passages) do
            if x >= p.x1 and x <= p.x2 and y >= p.y1 and y <= p.y2 then
                return true, p.type
            end
        end
        for _, g in ipairs(eastGaps) do
            if x >= g.x1 and x <= g.x2 and y >= g.y1 and y <= g.y2 then
                return true, "gap"
            end
        end
        return false, nil
    end

    -- 北墙
    for y = outerY1, outerY1 + wallThick - 1 do
        for x = outerX1, outerX2 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end
    -- 南墙
    for y = outerY2 - wallThick + 1, outerY2 do
        for x = outerX1, outerX2 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end
    -- 西墙
    for x = outerX1, outerX1 + wallThick - 1 do
        for y = outerY1, outerY2 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end
    -- 东墙（缺口处跳过）
    for x = outerX2 - wallThick + 1, outerX2 do
        for y = outerY1, outerY2 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end

    -- ================================================================
    -- 2. 内部分隔墙（从区域边界推算）
    -- ================================================================

    -- E1 南墙 / E4 北墙分隔（E1.y2 ~ E1.y2+1）
    local e1SouthWallY = E1.y2
    for y = e1SouthWallY, e1SouthWallY + 1 do
        for x = outerX1, outerX2 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end

    -- E2 北墙 / E4 南墙分隔（E2.y1-2 ~ E2.y1-1）
    local e2NorthWallY = E2.y1 - 2
    for y = e2NorthWallY, e2NorthWallY + 1 do
        for x = outerX1, outerX2 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end

    -- E3 东墙 / E4 西墙分隔（E3.x2+1 ~ E4.x1-1）
    local e3e4WallX1 = E3.x2 + 1
    local e3e4WallX2 = E4.x1 - 1
    local e3e4WallY1 = e1SouthWallY + 2
    local e3e4WallY2 = e2NorthWallY
    for x = e3e4WallX1, e3e4WallX2 do
        for y = e3e4WallY1, e3e4WallY2 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end

    -- E3 北墙（E3.y1-2 ~ E3.y1-1, x=outerX1 ~ E4.x1-1）
    local e3NorthWallY = E3.y1 - 2
    for y = e3NorthWallY, e3NorthWallY + 1 do
        for x = outerX1, E4.x1 - 1 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end
    -- E3 南墙（E3.y2+1 ~ E3.y2+2, x=outerX1 ~ E4.x1-1）
    local e3SouthWallY = E3.y2 + 1
    for y = e3SouthWallY, e3SouthWallY + 1 do
        for x = outerX1, E4.x1 - 1 do
            if not isOpening(x, y) then
                self:SetTile(x, y, FWALL)
            end
        end
    end

    -- ================================================================
    -- 3. 通道处理
    --    open 类型：清为 FORTRESS_FLOOR
    --    crystal 类型：填充 CRYSTAL_STONE
    -- ================================================================
    for _, p in ipairs(passages) do
        for y = p.y1, p.y2 do
            for x = p.x1, p.x2 do
                if p.type == "crystal" then
                    self:SetTile(x, y, T.CRYSTAL_STONE)
                elseif p.type == "open" then
                    self:SetTile(x, y, T.FORTRESS_FLOOR)
                elseif p.type == "sealed" then
                    -- 先铺地板，后续步骤5由 sealedGate 覆盖封印瓦片
                    self:SetTile(x, y, T.FORTRESS_FLOOR)
                end
            end
        end
    end

    -- ================================================================
    -- 4. BOSS 房
    -- ================================================================
    for _, boss in ipairs(fortressData.bossRooms or {}) do
        local w = boss.wall
        for y = w.y1, w.y2 do
            for x = w.x1, w.x2 do
                self:SetTile(x, y, FWALL)
            end
        end
        local inner = boss.inner
        for y = inner.y1, inner.y2 do
            for x = inner.x1, inner.x2 do
                self:SetTile(x, y, T.FORTRESS_FLOOR)
            end
        end
        local ent = boss.entrance
        for y = ent.y1, ent.y2 do
            for x = ent.x1, ent.x2 do
                self:SetTile(x, y, T.FORTRESS_FLOOR)
            end
        end
        for _, b in ipairs(boss.barriers or {}) do
            self:SetTile(b[1], b[2], FWALL)
        end
    end

    -- ================================================================
    -- 4b. E3 大殿左墙加厚（x=36 整列变墙，仅留 3 格通道口对准封印门）
    -- ================================================================
    local sealedPassage = nil
    for _, p in ipairs(passages) do
        if p.desc == "D→E3" then sealedPassage = p; break end
    end
    local e3ThickX = outerX1 + wallThick  -- x=36（外墙 34~35 之后）
    local passCenter = sealedPassage
        and math.floor((sealedPassage.y1 + sealedPassage.y2) / 2) or 41
    local passHalf = 1  -- 3格通道: center-1 ~ center+1
    for y = E3.y1, E3.y2 do
        -- 留 3 格入口对准封印门
        if y >= passCenter - passHalf and y <= passCenter + passHalf then
            -- 通道口，不放墙
        else
            self:SetTile(e3ThickX, y, FWALL)
        end
    end
    -- 同样为 E4→E3 通道在东侧加厚墙处也留口（E3 内部东墙不加厚，无需处理）

    -- ================================================================
    -- 4c. 堡垒内部少量阻挡物（E1/E2/E4 走廊内散布碎石柱，E3 大殿保持空旷）
    -- ================================================================
    local function fortHash(x, y, seed)
        return ((x * 374761393 + y * 668265263 + seed) & 0x7FFFFFFF)
    end
    local function fortHashPct(x, y, seed)
        return fortHash(x, y, seed) % 100
    end

    -- E3 大殿内部范围（加厚后 x=37 开始，通道墙 x=57~59 之前）
    local e3Inner = { x1 = e3ThickX + 1, y1 = E3.y1 + 2, x2 = E3.x2, y2 = E3.y2 - 2 }

    -- 在 E1/E2/E4 散布少量 FORTRESS_WALL 碎石柱（约 2~3%）
    local subRegions = {
        { x1 = outerX1 + wallThick, y1 = outerY1 + wallThick,
          x2 = outerX2 - wallThick, y2 = E1.y2 - 1, seed = 88100 },    -- E1
        { x1 = outerX1 + wallThick, y1 = E2.y1 + 1,
          x2 = outerX2 - wallThick, y2 = outerY2 - wallThick, seed = 88200 }, -- E2
        { x1 = E4.x1 + 1, y1 = E1.y2 + 2,
          x2 = outerX2 - wallThick, y2 = E2.y1 - 3, seed = 88300 },    -- E4
    }
    for _, sr in ipairs(subRegions) do
        for y = sr.y1, sr.y2 do
            for x = sr.x1, sr.x2 do
                local tile = self:GetTile(x, y)
                if tile ~= T.FORTRESS_FLOOR then goto skipObst end
                -- 不挡通道口
                if isOpening(x, y) then goto skipObst end
                -- 远离通道区域 2 格
                local nearPass = false
                for _, p in ipairs(passages) do
                    if x >= p.x1 - 2 and x <= p.x2 + 2
                       and y >= p.y1 - 2 and y <= p.y2 + 2 then
                        nearPass = true; break
                    end
                end
                if nearPass then goto skipObst end
                -- 远离 BOSS 房入口
                for _, boss in ipairs(fortressData.bossRooms or {}) do
                    local ent = boss.entrance
                    if x >= ent.x1 - 2 and x <= ent.x2 + 2
                       and y >= ent.y1 - 2 and y <= ent.y2 + 2 then
                        nearPass = true; break
                    end
                end
                if nearPass then goto skipObst end
                -- 3% 概率放碎石柱
                if fortHashPct(x, y, sr.seed) < 3 then
                    self:SetTile(x, y, FWALL)
                end
                ::skipObst::
            end
        end
    end

    -- ================================================================
    -- 5. D 区凹陷甬道 + 封印大门
    -- ================================================================
    if skullData then
        local conc = skullData.concavity
        if conc then
            for y = conc.y1, conc.y2 do
                for x = conc.x1, conc.x2 do
                    self:SetTile(x, y, T.BATTLEFIELD)
                end
            end
            -- 凹陷两侧山墙
            for y = conc.y1 - 2, conc.y1 - 1 do
                for x = conc.x1, conc.x2 do
                    self:SetTile(x, y, T.MOUNTAIN)
                end
            end
            for y = conc.y2 + 1, conc.y2 + 2 do
                for x = conc.x1, conc.x2 do
                    self:SetTile(x, y, T.MOUNTAIN)
                end
            end
        end

        local gate = skullData.sealedGate
        if gate then
            for y = gate.y1, gate.y2 do
                for x = gate.x1, gate.x2 do
                    self:SetTile(x, y, T.SEALED_GATE)
                end
            end
        end
    end

    -- ================================================================
    -- 6. 堡垒西墙外侧封山（防止从 D 区绕行）
    --    skull_d.x2+1 ~ outerX1-1 的间隙填充 MOUNTAIN
    -- ================================================================
    local skullRegion = skullData and skullData.regions and skullData.regions.skull_d
    local gapX1 = skullRegion and (skullRegion.x2 + 1) or (outerX1 - 3)
    local gapX2 = outerX1 - 1
    if gapX1 <= gapX2 then
        for y = outerY1, outerY2 do
            for x = gapX1, gapX2 do
                -- 跳过通道区域（B→E1、C→E2、D→E3 等穿过间隙的通道）
                if not isOpening(x, y) then
                    local tile = self:GetTile(x, y)
                    if tile == T.GRASS or tile == T.FORTRESS_FLOOR then
                        self:SetTile(x, y, T.MOUNTAIN)
                    end
                end
            end
        end
    end
end

function GameMap:BeautifyCh2Terrain()
    local fortressData = activeZoneData.fortressData
    if not fortressData then return end
    local T = activeZoneData.TILE
    local R = activeZoneData.Regions
    local campA  = R.camp_a
    local wildB  = R.wild_b
    local wildC  = R.wild_c
    local skullD = R.skull_d
    if not (campA and wildB and wildC and skullD) then return end

    local skullData = activeZoneData.skullData
    local passages  = fortressData.passages or {}

    local function hash(x, y, seed)
        return ((x * 374761393 + y * 668265263 + seed) & 0x7FFFFFFF)
    end
    local function hashPct(x, y, seed)
        return hash(x, y, seed) % 100
    end

    local function isNearPassage(x, y, margin)
        for _, p in ipairs(passages) do
            if x >= p.x1 - margin and x <= p.x2 + margin
               and y >= p.y1 - margin and y <= p.y2 + margin then
                return true
            end
        end
        return false
    end

    -- 道路布局常量：东西大路正对乌堡大门(sealedGate y=39~43, 中心y=41)
    local skullGate = skullData and skullData.sealedGate
    local gateCenter = skullGate and math.floor((skullGate.y1 + skullGate.y2) / 2) or 41
    local roadY   = gateCenter - 1                           -- 道路 y=40,41 正对大门中心
    local nsRoadX = 32                                       -- 南北道路贴堡墙
    local gateX   = 33                                       -- 封印门 x

    local function isRoadArea(x, y)
        -- 东西道路：地图左侧 → 贯穿营地 → 乌堡门口
        if y >= roadY - 1 and y <= roadY + 2
           and x >= 2 and x <= gateX + 1 then
            return true
        end
        -- 南北道路：贴堡墙（x=31~34）
        if x >= nsRoadX - 1 and x <= nsRoadX + 2 then
            return true
        end
        return false
    end

    -- ================================================================
    -- 1. 区域边界不规则扭曲
    -- ================================================================
    self:ErodeRegionEdge(skullD, "north", 3, 80001)
    self:ErodeRegionEdge(skullD, "south", 3, 80002)
    self:ErodeRegionEdge(skullD, "west",  2, 80003)
    self:ErodeRegionEdge(campA,  "north", 2, 80004)
    self:ErodeRegionEdge(campA,  "south", 2, 80005)

    -- ================================================================
    -- 2. 野外区域交界岩石（仅在与其他区域相邻的边界放置，地图边线不放）
    --    借鉴第一章：只在区域交界处形成领地轮廓，地图边缘保持开阔
    -- ================================================================
    ---@param region table 区域矩形
    ---@param borderPct number 交界带密度(%)
    ---@param borderW number 交界带宽度(格)
    ---@param innerPct number 内部密度(%)
    ---@param seed number hash种子
    ---@param borderSides table 哪些方向是交界边 {top=bool,bottom=bool,left=bool,right=bool}
    ---@param exclude function|nil 排除函数
    local function scatterRocks(region, innerPct, borderPct, borderW, seed, borderSides, exclude)
        for y = region.y1, region.y2 do
            for x = region.x1, region.x2 do
                if exclude and exclude(x, y) then goto skip end
                if isNearPassage(x, y, 3) then goto skip end
                if isRoadArea(x, y) then goto skip end
                local tile = self:GetTile(x, y)
                if tile ~= T.GRASS and tile ~= T.SWAMP and tile ~= T.BATTLEFIELD then goto skip end

                -- 只计算交界方向的边距
                local dists = {}
                if borderSides.top    then dists[#dists+1] = y - region.y1 end
                if borderSides.bottom then dists[#dists+1] = region.y2 - y end
                if borderSides.left   then dists[#dists+1] = x - region.x1 end
                if borderSides.right  then dists[#dists+1] = region.x2 - x end

                local d = math.huge
                for _, v in ipairs(dists) do
                    if v < d then d = v end
                end
                -- 非交界边 → d 保持 huge → 使用 innerPct
                local pct = d < borderW and borderPct or innerPct
                if hashPct(x, y, seed) < pct then
                    self:SetTile(x, y, T.MOUNTAIN)
                    -- 交界带允许小簇延伸
                    if d < borderW and hashPct(x, y, seed + 1) < 35 then
                        local dir = hash(x, y, seed + 2) % 4
                        local offsets = { {1,0}, {-1,0}, {0,1}, {0,-1} }
                        local off = offsets[dir + 1]
                        local nx2, ny2 = x + off[1], y + off[2]
                        if nx2 >= region.x1 and nx2 <= region.x2
                           and ny2 >= region.y1 and ny2 <= region.y2
                           and not isNearPassage(nx2, ny2, 3)
                           and not isRoadArea(nx2, ny2)
                           and not (exclude and exclude(nx2, ny2)) then
                            local nt = self:GetTile(nx2, ny2)
                            if nt == T.GRASS or nt == T.SWAMP or nt == T.BATTLEFIELD then
                                self:SetTile(nx2, ny2, T.MOUNTAIN)
                            end
                        end
                    end
                end
                ::skip::
            end
        end
    end

    local function nearCamp(x, y)
        return x >= campA.x1 - 1 and x <= campA.x2 + 1
           and y >= campA.y1 - 1 and y <= campA.y2 + 1
    end
    local skullConc = skullData and skullData.concavity
    local function nearConcavity(x, y)
        if not skullConc then return false end
        return x >= skullConc.x1 - 1 and x <= skullConc.x2 + 1
           and y >= skullConc.y1 - 1 and y <= skullConc.y2 + 1
    end

    -- wild_b (2,2→30,26): 上/左是地图边线，下边接camp/skull，右边接堡墙
    scatterRocks(wildB,  1, 20, 5, 90001,
        { top = false, bottom = true, left = false, right = true },
        function(x, y) return nearCamp(x, y) end)
    -- wild_c (2,54→30,79): 下/左是地图边线，上边接camp/skull，右边接堡墙
    scatterRocks(wildC,  1, 18, 5, 90002,
        { top = true, bottom = false, left = false, right = true },
        function(x, y) return nearCamp(x, y) end)
    -- skull_d (13,23→30,59): 左接camp，上接wild_b，下接wild_c，右接堡墙
    scatterRocks(skullD, 2, 16, 4, 90003,
        { top = true, bottom = true, left = true, right = false },
        function(x, y) return nearCamp(x, y) or nearConcavity(x, y) end)

    -- ================================================================
    -- 2b. 修罗场与野猪坡/毒蛇沼过渡地带（交界处混合散落碎石+焦土残痕）
    -- ================================================================
    -- skull_d 上边界 (y≈23) 与 wild_b 下边界 (y≈26) 之间的过渡
    local transN_y1 = math.min(skullD.y1, wildB.y2) - 2
    local transN_y2 = math.max(skullD.y1, wildB.y2) + 2
    for y = transN_y1, transN_y2 do
        for x = skullD.x1, skullD.x2 do
            if isRoadArea(x, y) then goto skipTN end
            if isNearPassage(x, y, 3) then goto skipTN end
            local tile = self:GetTile(x, y)
            if tile == T.GRASS then
                -- 过渡带：零星焦土渗透
                if hashPct(x, y, 91100) < 15 then
                    self:SetTile(x, y, T.BATTLEFIELD)
                end
            end
            ::skipTN::
        end
    end
    -- skull_d 下边界 (y≈59) 与 wild_c 上边界 (y≈54) 之间的过渡
    local transS_y1 = math.min(wildC.y1, skullD.y2) - 2
    local transS_y2 = math.max(wildC.y1, skullD.y2) + 2
    for y = transS_y1, transS_y2 do
        for x = skullD.x1, skullD.x2 do
            if isRoadArea(x, y) then goto skipTS end
            if isNearPassage(x, y, 3) then goto skipTS end
            local tile = self:GetTile(x, y)
            if tile == T.GRASS then
                if hashPct(x, y, 91200) < 15 then
                    self:SetTile(x, y, T.BATTLEFIELD)
                end
            elseif tile == T.SWAMP then
                -- 沼泽与焦土交界：少量焦土侵入
                if hashPct(x, y, 91201) < 10 then
                    self:SetTile(x, y, T.BATTLEFIELD)
                end
            end
            ::skipTS::
        end
    end
    -- skull_d 左边界 (x≈13) 与 camp_a 右边界 (x≈13) 之间的过渡
    local transW_x1 = skullD.x1 - 2
    local transW_x2 = skullD.x1 + 3
    for y = skullD.y1, skullD.y2 do
        for x = transW_x1, transW_x2 do
            if nearCamp(x, y) then goto skipTW end
            if isRoadArea(x, y) then goto skipTW end
            local tile = self:GetTile(x, y)
            if tile == T.GRASS then
                if hashPct(x, y, 91300) < 12 then
                    self:SetTile(x, y, T.BATTLEFIELD)
                end
            end
            ::skipTW::
        end
    end

    -- ================================================================
    -- 3. 道路：营地→乌堡门口(东西) + 贴堡墙南北纵贯(不切割野外区域)
    -- ================================================================
    -- 东西道路: 地图左边缘 → 贯穿营地 → 封印门
    for x = 2, gateX do
        for w = 0, 1 do
            local y = roadY + w
            local tile = self:GetTile(x, y)
            if tile ~= T.WATER and tile ~= T.FORTRESS_WALL
               and tile ~= T.SEALED_GATE then
                self:SetTile(x, y, T.TOWN_ROAD)
            end
        end
        -- 清除道路两侧障碍
        for _, dy in ipairs({-1, 2}) do
            local y = roadY + dy
            local tile = self:GetTile(x, y)
            if tile == T.MOUNTAIN or tile == T.WALL then
                self:SetTile(x, y, T.GRASS)
            end
        end
    end

    -- 南北道路: 贴乌堡外墙 (x≈32)，从地图顶到底
    -- 只在间隙山体/修罗场区域铺路，不进入野猪林和毒蛇沼腹地
    local sx = nsRoadX
    for y = 2, self.height - 1 do
        -- 跳过营地内部（营地内无需铺路）
        if y >= campA.y1 and y <= campA.y2 and nsRoadX > campA.x2 then
            goto skipRoadY
        end
        -- hash 微小摆动
        local h = hash(y, 0, 95000) % 11
        if h == 0 and sx < nsRoadX + 1 then sx = sx + 1
        elseif h == 1 and sx > nsRoadX - 1 then sx = sx - 1 end
        for w = 0, 1 do
            local x = sx + w
            local tile = self:GetTile(x, y)
            if tile ~= T.WATER and tile ~= T.FORTRESS_WALL
               and tile ~= T.SEALED_GATE then
                self:SetTile(x, y, T.TOWN_ROAD)
            end
        end
        -- 清除道路两侧障碍
        for _, dx in ipairs({-1, 2}) do
            local x = sx + dx
            if x >= 2 and x <= self.width - 1 then
                local tile = self:GetTile(x, y)
                if tile == T.MOUNTAIN or tile == T.WALL then
                    self:SetTile(x, y, T.GRASS)
                end
            end
        end
        ::skipRoadY::
    end

    -- ================================================================
    -- 4. B→E1 和 C→E2 通道附近堡墙坍塌（支离破碎效果）
    -- ================================================================
    for _, p in ipairs(passages) do
        if p.desc ~= "B→E1" and p.desc ~= "C→E2" then goto nextBreach end
        local cy = math.floor((p.y1 + p.y2) / 2)
        local seed = 97000 + cy
        local pw = p.y2 - p.y1  -- 通道宽度

        -- a) 堡墙缺口大幅扩大：上下各6格范围，概率更高
        for dy = -6, 6 do
            local y = cy + dy
            if y >= p.y1 and y <= p.y2 then goto skipBr end
            local dist = y < p.y1 and (p.y1 - y) or (y - p.y2)
            local chance = math.max(0, 75 - dist * 10)
            for x = 34, 35 do
                if hashPct(x, y, seed) < chance then
                    self:SetTile(x, y, T.FORTRESS_FLOOR)
                end
            end
            ::skipBr::
        end

        -- b) 打通间隙山体，范围更大 (±4)，概率更高
        for dy = -4, pw + 4 do
            local y = p.y1 + dy
            for x = 30, 33 do
                local tile = self:GetTile(x, y)
                if tile == T.MOUNTAIN then
                    local dist = 0
                    if y < p.y1 then dist = p.y1 - y
                    elseif y > p.y2 then dist = y - p.y2 end
                    if hashPct(x, y, seed + 100) < math.max(0, 85 - dist * 15) then
                        self:SetTile(x, y, T.GRASS)
                    end
                end
            end
        end

        -- c) 堡墙碎片散落到野外 (MOUNTAIN 碎石 + 少量 FORTRESS_FLOOR 残留)
        for dy = -7, 7 do
            for dx = -10, 3 do
                local x = p.x1 + dx
                local y = cy + dy
                if x < 2 or x >= self.width then goto skipDebris end
                if isRoadArea(x, y) then goto skipDebris end
                local tile = self:GetTile(x, y)
                if tile == T.GRASS or tile == T.SWAMP then
                    local dist = math.abs(dy) + math.max(0, math.abs(dx + 3))
                    -- 近处碎石密度高
                    if hashPct(x, y, seed + 200) < math.max(0, 35 - dist * 2) then
                        self:SetTile(x, y, T.MOUNTAIN)
                    end
                    -- 极近处堡墙残块
                    if dist <= 3 and hashPct(x, y, seed + 300) < 15 then
                        self:SetTile(x, y, T.FORTRESS_FLOOR)
                    end
                end
                ::skipDebris::
            end
        end

        -- d) 堡墙内侧也有碎石散落
        for dy = -4, 4 do
            for dx = 0, 5 do
                local x = 36 + dx
                local y = cy + dy
                local tile = self:GetTile(x, y)
                if tile == T.FORTRESS_FLOOR then
                    local dist = math.abs(dy) + dx
                    if hashPct(x, y, seed + 400) < math.max(0, 25 - dist * 3) then
                        self:SetTile(x, y, T.MOUNTAIN)
                    end
                end
            end
        end
        ::nextBreach::
    end

    -- ================================================================
    -- 5. 安全区围栏（WALL 围墙 + 三个出口 + 不规则外形）
    -- ================================================================
    -- 出口定义：北(上)、东(中，对准道路)、南(下)，各 4 格宽
    local exitN_y = campA.y1                             -- 北出口
    local exitN_x1 = math.floor((campA.x1 + campA.x2) / 2) - 1
    local exitN_x2 = exitN_x1 + 3

    local exitS_y = campA.y2                             -- 南出口
    local exitS_x1 = exitN_x1
    local exitS_x2 = exitN_x2

    local exitE_x = campA.x2                             -- 东出口（对准道路）
    local exitE_y1 = roadY - 1
    local exitE_y2 = roadY + 2

    local exitW_x = campA.x1                             -- 西出口（对准道路，通往地图左侧）
    local exitW_y1 = roadY - 1
    local exitW_y2 = roadY + 2

    local function isExit(x, y)
        -- 北出口
        if y >= campA.y1 - 1 and y <= campA.y1
           and x >= exitN_x1 and x <= exitN_x2 then return true end
        -- 南出口
        if y >= campA.y2 and y <= campA.y2 + 1
           and x >= exitS_x1 and x <= exitS_x2 then return true end
        -- 东出口
        if x >= campA.x2 and x <= campA.x2 + 1
           and y >= exitE_y1 and y <= exitE_y2 then return true end
        -- 西出口
        if x >= campA.x1 - 1 and x <= campA.x1
           and y >= exitW_y1 and y <= exitW_y2 then return true end
        return false
    end

    -- 围栏：沿 camp_a 四边放置 WALL，带不规则外凸
    -- 北墙 (y = campA.y1 - 1)
    for x = campA.x1 - 1, campA.x2 + 1 do
        if not isExit(x, campA.y1 - 1) then
            self:SetTile(x, campA.y1 - 1, T.WALL)
            -- 不规则外凸
            local bump = hash(x, campA.y1, 99100) % 5
            if bump == 0 then
                self:SetTile(x, campA.y1 - 2, T.WALL)
            end
        end
    end
    -- 南墙 (y = campA.y2 + 1)
    for x = campA.x1 - 1, campA.x2 + 1 do
        if not isExit(x, campA.y2 + 1) then
            self:SetTile(x, campA.y2 + 1, T.WALL)
            local bump = hash(x, campA.y2, 99200) % 5
            if bump == 0 then
                self:SetTile(x, campA.y2 + 2, T.WALL)
            end
        end
    end
    -- 西墙 (x = campA.x1 - 1)，道路出口
    for y = campA.y1 - 1, campA.y2 + 1 do
        if not isExit(campA.x1 - 1, y) then
            self:SetTile(campA.x1 - 1, y, T.WALL)
            local bump = hash(campA.x1, y, 99300) % 6
            if bump == 0 then
                local bx = campA.x1 - 2
                if bx >= 2 then
                    self:SetTile(bx, y, T.WALL)
                end
            end
        end
    end
    -- 东墙 (x = campA.x2 + 1)
    for y = campA.y1 - 1, campA.y2 + 1 do
        if not isExit(campA.x2 + 1, y) then
            self:SetTile(campA.x2 + 1, y, T.WALL)
            local bump = hash(campA.x2, y, 99400) % 5
            if bump == 0 then
                self:SetTile(campA.x2 + 2, y, T.WALL)
            end
        end
    end

    -- 出口处铺设道路地块（连通）
    for x = exitN_x1, exitN_x2 do
        self:SetTile(x, campA.y1 - 1, T.CAMP_DIRT)
    end
    for x = exitS_x1, exitS_x2 do
        self:SetTile(x, campA.y2 + 1, T.CAMP_DIRT)
    end
    for y = exitE_y1, exitE_y2 do
        self:SetTile(campA.x2 + 1, y, T.CAMP_DIRT)
    end
    for y = exitW_y1, exitW_y2 do
        self:SetTile(campA.x1 - 1, y, T.CAMP_DIRT)
    end
end

end
