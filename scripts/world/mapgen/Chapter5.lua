-- ============================================================================
-- Chapter5.lua - 第五章地形生成（伍章·太虚之殇）
-- 80×80 废墟地图：浮空岛屿群，各区域以虚空隔开，桥梁连接
-- 前营 → 裂山门(双路分流) → 左路/右路 → 剑宫 → 深渊 → 城墙
-- 所有区域使用确定性哈希噪声生成有机边缘与材质变化
-- ============================================================================

---@param GameMap table
---@param zd table  ZoneData proxy
return function(GameMap, zd)

-- ============================================================================
-- 辅助：确定性哈希噪声
-- ============================================================================

--- 整数哈希 → 0.0~1.0
local function hash2(ix, iy, seed)
    local n = ix * 374761393 + iy * 668265263 + seed * 1274126177
    n = (n ~ (n >> 13)) * 1103515245
    n = n ~ (n >> 16)
    return (n % 10000) / 10000
end

-- ============================================================================
-- 辅助：安全瓦片设置
-- ============================================================================

local function safeTile(self, gx, gy, tile)
    if gx >= 1 and gx <= self.width and gy >= 1 and gy <= self.height then
        self:SetTile(gx, gy, tile)
    end
end

-- ============================================================================
-- 辅助：填充矩形区域（含有机边缘侵蚀）
-- ============================================================================

local function fillZoneOrganic(self, bounds, floorTile, baseTile, seed)
    local x1, y1, x2, y2 = bounds.x1, bounds.y1, bounds.x2, bounds.y2

    for gy = y1, y2 do
        for gx = x1, x2 do
            local distLeft   = gx - x1
            local distRight  = x2 - gx
            local distTop    = gy - y1
            local distBottom = y2 - gy
            local edgeDist = math.min(distLeft, distRight, distTop, distBottom)

            if edgeDist <= 1 then
                local n = hash2(gx, gy, seed + 50)
                if n < 0.10 then
                    safeTile(self, gx, gy, baseTile)
                else
                    safeTile(self, gx, gy, floorTile)
                end
            else
                safeTile(self, gx, gy, floorTile)
            end
        end
    end
end

-- ============================================================================
-- 辅助：绘制连接通道（两点间 N 格宽通道）
-- ============================================================================

local function drawPassage(self, x1, y1, x2, y2, tile, width)
    width = width or 3
    local halfW = math.floor(width / 2)

    if x1 == x2 then
        local minY = math.min(y1, y2)
        local maxY = math.max(y1, y2)
        for gy = minY, maxY do
            for dx = -halfW, halfW do
                safeTile(self, x1 + dx, gy, tile)
            end
        end
    elseif y1 == y2 then
        local minX = math.min(x1, x2)
        local maxX = math.max(x1, x2)
        for gx = minX, maxX do
            for dy = -halfW, halfW do
                safeTile(self, gx, y1 + dy, tile)
            end
        end
    else
        -- L 形通道：先水平后垂直
        local minX = math.min(x1, x2)
        local maxX = math.max(x1, x2)
        for gx = minX, maxX do
            for dy = -halfW, halfW do
                safeTile(self, gx, y1 + dy, tile)
            end
        end
        local minY = math.min(y1, y2)
        local maxY = math.max(y1, y2)
        for gy = minY, maxY do
            for dx = -halfW, halfW do
                safeTile(self, x2 + dx, gy, tile)
            end
        end
    end
end

-- ============================================================================
-- 辅助：绘制带墙垂直桥梁（3格宽通道 + 两侧各1格墙）
-- ============================================================================

local function drawVerticalBridge(self, cx, y1, y2, floorTile, wallTile)
    local minY = math.min(y1, y2)
    local maxY = math.max(y1, y2)
    for gy = minY, maxY do
        safeTile(self, cx - 2, gy, wallTile)
        for dx = -1, 1 do
            safeTile(self, cx + dx, gy, floorTile)
        end
        safeTile(self, cx + 2, gy, wallTile)
    end
end

-- ============================================================================
-- 辅助：绘制带墙水平桥梁（3格宽通道 + 上下各1格墙）
-- ============================================================================

local function drawHorizontalBridge(self, cy, x1, x2, floorTile, wallTile)
    local minX = math.min(x1, x2)
    local maxX = math.max(x1, x2)
    for gx = minX, maxX do
        safeTile(self, gx, cy - 2, wallTile)
        for dy = -1, 1 do
            safeTile(self, gx, cy + dy, floorTile)
        end
        safeTile(self, gx, cy + 2, wallTile)
    end
end

-- ============================================================================
-- 主入口：第五章地形生成
-- ============================================================================

function GameMap:BuildCh5Terrain()
    local T = zd.TILE
    local layout = zd.LAYOUT
    if not layout or not layout.front_camp then
        print("[Chapter5] No LAYOUT.front_camp in ZoneData, skipping")
        return
    end

    local W = self.width
    local H = self.height

    -- 快捷引用
    local fc      = layout.front_camp
    local bg      = layout.broken_gate
    local sp      = layout.sword_plaza
    local fg      = layout.forge
    local sc      = layout.sword_court
    local cp      = layout.cold_pool
    local sf      = layout.stele_forest
    local lb      = layout.library
    local palace  = layout.sword_palace
    local abyss   = layout.demon_abyss
    local corridor = layout.sword_corridor

    -- ================================================================
    -- Step 1: 全图填充虚空底色
    -- ================================================================
    for y = 1, H do
        for x = 1, W do
            self:SetTile(x, y, T.CH5_VOID)
        end
    end

    -- ================================================================
    -- Step 2: 绘制各区域地表（浮空岛屿）
    -- ================================================================

    -- ── 2.1 太虚遗址前营 ──
    fillZoneOrganic(self, fc, T.CH5_CAMP_DIRT, T.CH5_VOID, 5001)
    -- 前营中央石板
    local fcCx = math.floor((fc.x1 + fc.x2) / 2)
    local fcCy = math.floor((fc.y1 + fc.y2) / 2)
    for gy = fcCy - 1, fcCy + 1 do
        for gx = fcCx - 4, fcCx + 4 do
            safeTile(self, gx, gy, T.CH5_CAMP_FLAGSTONE)
        end
    end
    -- （裂石噪点已移除，减少前营颜色种类）

    -- ── 2.2 裂山门遗址 ──
    fillZoneOrganic(self, bg, T.CH5_RUIN_BLUESTONE, T.CH5_VOID, 5020)
    -- 中轴封印门（宽6格）
    local bgCx = math.floor((bg.x1 + bg.x2) / 2)
    for gy = bg.y1, bg.y2 do
        for dx = -3, 2 do
            safeTile(self, bgCx + dx, gy, T.CH5_SEALED_GATE)
        end
    end
    -- 封印门外围墙壁
    for gy = bg.y1, bg.y2 do
        safeTile(self, bgCx - 4, gy, T.CH5_WALL)
        safeTile(self, bgCx + 3, gy, T.CH5_WALL)
    end
    -- 裂山门裂石
    for gy = bg.y1 + 1, bg.y2 - 1 do
        for gx = bg.x1 + 1, bg.x2 - 1 do
            if self:GetTile(gx, gy) == T.CH5_RUIN_BLUESTONE then
                local n = hash2(gx, gy, 5025)
                if n < 0.12 then
                    safeTile(self, gx, gy, T.CH5_RUIN_CRACKED)
                end
            end
        end
    end

    -- ── 2.3 问剑坪 ──
    fillZoneOrganic(self, sp, T.CH5_RUIN_BLUESTONE, T.CH5_VOID, 5030)
    -- 仅少量裂石点缀，保持整洁
    for gy = sp.y1 + 2, sp.y2 - 2 do
        for gx = sp.x1 + 2, sp.x2 - 2 do
            local n = hash2(gx, gy, 5035)
            if n < 0.05 then
                safeTile(self, gx, gy, T.CH5_RUIN_CRACKED)
            end
        end
    end

    -- ── 2.4 铸剑地炉 ──
    fillZoneOrganic(self, fg, T.CH5_FORGE_BLACKSTONE, T.CH5_VOID, 5040)
    local fgCx = math.floor((fg.x1 + fg.x2) / 2)
    local fgCy = math.floor((fg.y1 + fg.y2) / 2)
    for gy = fg.y1 + 1, fg.y2 - 1 do
        for gx = fg.x1 + 1, fg.x2 - 1 do
            local dx = gx - fgCx
            local dy = gy - fgCy
            local dist = math.sqrt(dx * dx + dy * dy)
            local n = hash2(gx, gy, 5045)
            local threshold = 0.06 + 0.12 * math.max(0, 1 - dist / 8)
            if n < threshold then
                safeTile(self, gx, gy, T.CH5_FORGE_MOLTEN)
            end
        end
    end

    -- ── 2.5 栖剑别院 ──
    fillZoneOrganic(self, sc, T.CH5_COURTYARD_MOSS, T.CH5_VOID, 5050)
    -- 院内回廊墙（少段数、每段保持长度）
    do
        local inX1 = sc.x1 + 5
        local inX2 = sc.x2 - 5
        local inY1 = sc.y1 + 5
        local inY2 = sc.y2 - 5
        local sLen = 3   -- 每段墙长度
        local sGap = 2   -- 段间缺口

        -- 水平墙（上下两边）
        local wx = inX1
        while wx <= inX2 do
            local n1 = hash2(wx, inY1, 5052)
            if n1 > 0.35 then
                for i = 0, sLen - 1 do
                    if wx + i <= inX2 then safeTile(self, wx + i, inY1, T.CH5_WALL) end
                end
            end
            local n2 = hash2(wx, inY2, 5053)
            if n2 > 0.35 then
                for i = 0, sLen - 1 do
                    if wx + i <= inX2 then safeTile(self, wx + i, inY2, T.CH5_WALL) end
                end
            end
            wx = wx + sLen + sGap
        end

        -- 垂直墙（左右两边）
        local wy = inY1
        while wy <= inY2 do
            local n1 = hash2(inX1, wy, 5054)
            if n1 > 0.35 then
                for i = 0, sLen - 1 do
                    if wy + i <= inY2 then safeTile(self, inX1, wy + i, T.CH5_WALL) end
                end
            end
            local n2 = hash2(inX2, wy, 5055)
            if n2 > 0.35 then
                for i = 0, sLen - 1 do
                    if wy + i <= inY2 then safeTile(self, inX2, wy + i, T.CH5_WALL) end
                end
            end
            wy = wy + sLen + sGap
        end

        -- 内院门口（上下各5格宽）
        local doorCx = math.floor((inX1 + inX2) / 2)
        for dx = -2, 2 do
            safeTile(self, doorCx + dx, inY1, T.CH5_COURTYARD_MOSS)
            safeTile(self, doorCx + dx, inY2, T.CH5_COURTYARD_MOSS)
        end
    end

    -- ── 2.6 洗剑寒池 ──
    fillZoneOrganic(self, cp, T.CH5_COLD_JADE, T.CH5_VOID, 5060)
    local cpCx = math.floor((cp.x1 + cp.x2) / 2)
    local cpCy = math.floor((cp.y1 + cp.y2) / 2)
    local poolRadius = 2
    for gy = cp.y1 + 2, cp.y2 - 2 do
        for gx = cp.x1 + 2, cp.x2 - 2 do
            local dx = gx - cpCx
            local dy = gy - cpCy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= poolRadius then
                safeTile(self, gx, gy, T.WATER)
            elseif dist <= poolRadius + 1.5 then
                local n = hash2(gx, gy, 5065)
                if n < 0.6 then
                    safeTile(self, gx, gy, T.CH5_COLD_ICE_EDGE)
                end
            end
        end
    end

    -- ── 2.7 悟剑碑林 ──
    fillZoneOrganic(self, sf, T.CH5_STELE_PALE, T.CH5_VOID, 5070)

    -- 完整石碑：3x3大碑，固定3座，手工选址确保不重叠且留出通行空间
    -- stele_forest = {x1=58, y1=20, x2=77, y2=45}
    local intactSteles = {
        { x = sf.x1 + 4,  y = sf.y1 + 4  },  -- 左上区域
        { x = sf.x1 + 12, y = sf.y1 + 12 },   -- 中部偏右
        { x = sf.x1 + 6,  y = sf.y1 + 20 },   -- 左下区域
    }
    for _, pos in ipairs(intactSteles) do
        -- 以pos为中心放置3x3完整石碑
        for dy = -1, 1 do
            for dx = -1, 1 do
                safeTile(self, pos.x + dx, pos.y + dy, T.CH5_STELE_INTACT)
            end
        end
    end

    -- 断壁残碑：稀疏散布（单格，可通行装饰）
    for gy = sf.y1 + 2, sf.y2 - 2, 5 do
        for gx = sf.x1 + 2, sf.x2 - 2, 6 do
            local offsetX = math.floor(hash2(gx, gy, 5076) * 2)
            local offsetY = math.floor(hash2(gx, gy, 5077) * 2)
            local px = gx + offsetX
            local py = gy + offsetY
            if px >= sf.x1 + 2 and px <= sf.x2 - 2
               and py >= sf.y1 + 2 and py <= sf.y2 - 2 then
                -- 避开完整碑3x3范围
                local tooClose = false
                for _, s in ipairs(intactSteles) do
                    if math.abs(px - s.x) <= 2 and math.abs(py - s.y) <= 2 then
                        tooClose = true
                        break
                    end
                end
                if not tooClose then
                    local n = hash2(px, py, 5075)
                    if n < 0.45 then
                        safeTile(self, px, py, T.CH5_STELE_BROKEN)
                    end
                end
            end
        end
    end

    -- ── 2.8 藏经书阁（有机填充 + 居中对称内环L型拐角）──
    fillZoneOrganic(self, lb, T.CH5_LIBRARY_BURNT, T.CH5_VOID, 5080)

    -- 内环L型拐角结构（居中对称）
    do
        local lbCx = math.floor((lb.x1 + lb.x2) / 2)  -- 67
        local lbCy = math.floor((lb.y1 + lb.y2) / 2)  -- 56
        local halfW, halfH = 6, 4  -- 内环半宽/半高
        local armLen = 3           -- L臂长度

        local ix1 = lbCx - halfW   -- 62 (左)
        local ix2 = lbCx + halfW   -- 73 (右)（关于67.5近似对称: 67-5=62, 67+6=73→实际用+5=72让它完全对称）
        -- 修正：确保对称 → 62..72 宽11格，中心67
        ix2 = lbCx + halfW - 1     -- 72
        local iy1 = lbCy - halfH   -- 52 (上)
        local iy2 = lbCy + halfH   -- 60 (下)

        -- 四个L型拐角，每臂 armLen 格
        local corners = {
            { cx = ix1, cy = iy1, dx =  1, dy =  1 },  -- 左上，臂向右+向下
            { cx = ix2, cy = iy1, dx = -1, dy =  1 },  -- 右上，臂向左+向下
            { cx = ix1, cy = iy2, dx =  1, dy = -1 },  -- 左下，臂向右+向上
            { cx = ix2, cy = iy2, dx = -1, dy = -1 },  -- 右下，臂向左+向上
        }
        for _, c in ipairs(corners) do
            -- 横臂
            for i = 0, armLen - 1 do
                safeTile(self, c.cx + c.dx * i, c.cy, T.CH5_CITY_WALL)
            end
            -- 竖臂（跳过拐角点避免重复）
            for i = 1, armLen - 1 do
                safeTile(self, c.cx, c.cy + c.dy * i, T.CH5_CITY_WALL)
            end
        end
    end

    -- ── 2.9 太虚剑宫（缺角四边形：四角各切 3×3）──
    local cornerCut = 3
    for gy = palace.y1, palace.y2 do
        for gx = palace.x1, palace.x2 do
            local dL = gx - palace.x1
            local dR = palace.x2 - gx
            local dT = gy - palace.y1
            local dB = palace.y2 - gy
            local inCorner = (dL < cornerCut and dT < cornerCut)
                          or (dR < cornerCut and dT < cornerCut)
                          or (dL < cornerCut and dB < cornerCut)
                          or (dR < cornerCut and dB < cornerCut)
            if not inCorner then
                safeTile(self, gx, gy, T.CH5_PALACE_WHITE)
            end
        end
    end
    local palCx = math.floor((palace.x1 + palace.x2) / 2)
    local palCy = math.floor((palace.y1 + palace.y2) / 2)

    -- 中央血池
    for dy = -1, 1 do
        for dx = -2, 2 do
            if math.abs(dx) + math.abs(dy) <= 3 then
                safeTile(self, palCx + dx, palCy + dy, T.CH5_BLOOD_RITUAL)
            end
        end
    end

    -- ── 2.10 镇魔深渊（椭圆形浮空岛，向外扩2圈，岩浆墙围边）──
    -- 注意：向下(南)不扩展，避免侵入剑气城墙
    local abCx = math.floor((abyss.x1 + abyss.x2) / 2)
    local abCy = math.floor((abyss.y1 + abyss.y2) / 2)
    local abExpand = 2  -- 向外扩展2格（减小以避免侵入城墙）
    local abRx = (abyss.x2 - abyss.x1) / 2 + abExpand  -- 扩展后水平半径
    local abRy = (abyss.y2 - abyss.y1) / 2 + abExpand   -- 扩展后垂直半径
    local cliffThick = 1.5  -- 岩浆墙厚度（1-2格渐变）

    -- 扩展后的绘制范围（南侧不扩展，保护城墙不被侵入）
    local abDrawX1 = abyss.x1 - abExpand
    local abDrawY1 = abyss.y1 - abExpand
    local abDrawX2 = abyss.x2 + abExpand
    local abDrawY2 = abyss.y2 - 1          -- 南侧收缩1格，不触碰城墙顶行(y=68)

    for gy = abDrawY1, abDrawY2 do
        for gx = abDrawX1, abDrawX2 do
            local dx = (gx - abCx) / abRx
            local dy = (gy - abCy) / abRy
            local dist = dx * dx + dy * dy  -- 椭圆归一化距离²

            if dist <= 1.0 then
                -- 仅覆盖虚空瓦片（确保不侵蚀已有区域）
                local curTile = self:GetTile(gx, gy)
                if curTile == T.CH5_VOID or (gx >= abyss.x1 and gx <= abyss.x2
                        and gy >= abyss.y1 and gy <= abyss.y2) then
                    local edgeFrac = (1.0 - math.sqrt(dist)) * math.min(abRx, abRy)
                    if edgeFrac < cliffThick then
                        -- 边缘 1-2 格：岩浆墙
                        safeTile(self, gx, gy, T.CH5_LAVA_WALL)
                    else
                        -- 内部地面
                        safeTile(self, gx, gy, T.CORRUPTED_GROUND)
                    end
                end
            end
            -- dist > 1.0 保持原瓦片
        end
    end

    -- 深渊入口1：北侧3格宽缺口（连接剑宫桥梁）
    for d = -1, 1 do
        for edy = 0, 2 do
            safeTile(self, abCx + d, abDrawY1 + edy, T.CORRUPTED_GROUND)
        end
    end
    -- 深渊南侧：岩浆墙封死底部，不再有城墙入口
    for gx = abyss.x1, abyss.x2 do
        safeTile(self, gx, abyss.y2 - 1, T.CH5_LAVA_WALL)
        safeTile(self, gx, abyss.y2,     T.CH5_LAVA_WALL)
    end

    -- ── 2.11 剑气城墙 ──
    -- corridor = {x1=3, y1=65, x2=77, y2=74} → 75宽 × 10高
    -- 布局(从上到下):
    --   y1     : 上城垛 (T.WALL，齿形)
    --   y1+1   : 上城垛第二行
    --   y1+2 ~ y1+7 : 可行走城墙面 (6行, T.CH5_CITY_WALL)
    --   y1+8   : 下城垛 (T.WALL，齿形)
    --   y1+9   : 下城垛第二行
    --   y2+1 ~ H : 虚空（城墙外侧）

    local wallTopY     = corridor.y1          -- 上城垛起始
    local walkStartY   = corridor.y1 + 2      -- 可行走区起始
    local walkEndY     = corridor.y1 + 7      -- 可行走区结束
    local wallBottomY  = corridor.y1 + 8      -- 下城垛起始
    local wallBottomEnd = corridor.y1 + 9     -- 下城垛结束

    -- 铺满可行走城墙面
    for gy = walkStartY, walkEndY do
        for gx = corridor.x1, corridor.x2 do
            safeTile(self, gx, gy, T.CH5_CITY_WALL)
        end
    end

    -- 上下城垛（使用 T.WALL —— 山贼寨墙壁瓦片，齿形交替）
    -- 齿形：3宽齿 + 2宽缺口，循环
    local toothWidth = 3
    local gapWidth   = 2
    local cycleWidth = toothWidth + gapWidth  -- 5
    for gx = corridor.x1, corridor.x2 do
        local posInCycle = (gx - corridor.x1) % cycleWidth
        local isTooth = (posInCycle < toothWidth)
        if isTooth then
            -- 城垛齿：使用 T.WALL（山贼寨深灰墙壁）
            safeTile(self, gx, wallTopY,      T.WALL)
            safeTile(self, gx, wallTopY + 1,  T.WALL)
            safeTile(self, gx, wallBottomY,     T.WALL)
            safeTile(self, gx, wallBottomEnd,   T.WALL)
        else
            -- 缺口：仍铺城墙面（矮墙连接部分）
            safeTile(self, gx, wallTopY,      T.CH5_CITY_WALL)
            safeTile(self, gx, wallTopY + 1,  T.CH5_CITY_WALL)
            safeTile(self, gx, wallBottomY,     T.CH5_CITY_WALL)
            safeTile(self, gx, wallBottomEnd,   T.CH5_CITY_WALL)
        end
    end

    -- 城墙走道上下边缘回廊暗石标记
    for gx = corridor.x1, corridor.x2 do
        safeTile(self, gx, walkStartY, T.CH5_CORRIDOR_DARK)
        safeTile(self, gx, walkEndY,   T.CH5_CORRIDOR_DARK)
    end

    -- （坍塌段已移除，城墙中段不再有碎石散落）

    -- ================================================================
    -- Step 3: 连接通道（跨虚空桥梁）
    -- 所有桥梁3格宽 + 两侧墙壁，跨越区域间虚空间隙
    -- ================================================================

    -- ── 3.1a 前营 → 裂山门左侧（垂直桥，跨2行虚空）──
    local bgLeftPassX  = bg.x1 + 3
    local bgRightPassX = bg.x2 - 3
    drawVerticalBridge(self, bgLeftPassX, fc.y2, bg.y1, T.CH5_BRIDGE, T.CH5_WALL)
    -- ── 3.1b 前营 → 裂山门右侧 ──
    drawVerticalBridge(self, bgRightPassX, fc.y2, bg.y1, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.2 裂山门 → 问剑坪（水平桥，跨3列虚空）──
    local bgMidY = math.floor((bg.y1 + bg.y2) / 2)
    local spMidY = math.floor((sp.y1 + sp.y2) / 2)
    -- 裂山门和问剑坪有高度差，用L形：水平到sp.x2+1，垂直到spMidY
    -- 简化：水平桥从bg.x1到sp.x2，y取bg中部
    drawHorizontalBridge(self, bgMidY, sp.x2, bg.x1, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.3 裂山门 → 洗剑寒池（水平桥）──
    drawHorizontalBridge(self, bgMidY, bg.x2, cp.x1, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.4 问剑坪 → 铸剑地炉（垂直桥，跨2行虚空）──
    local spFgCx = math.floor((sp.x1 + fg.x2) / 2)  -- 两区域x重叠区中轴
    -- 取较小区域的x范围中心
    local spCx = math.floor((sp.x1 + sp.x2) / 2)
    local fgTopCx = math.floor((fg.x1 + fg.x2) / 2)
    -- 取较左位置（两区域左对齐，用公共x中点）
    local bridgeSPFG_x = math.min(spCx, fgTopCx)
    drawVerticalBridge(self, bridgeSPFG_x, sp.y2, fg.y1, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.5 洗剑寒池 → 悟剑碑林（垂直桥）──
    local cpCxBridge = math.floor((cp.x1 + cp.x2) / 2)
    local sfCxBridge = math.floor((sf.x1 + sf.x2) / 2)
    local bridgeCPSF_x = math.floor((cpCxBridge + sfCxBridge) / 2)
    drawVerticalBridge(self, bridgeCPSF_x, cp.y2, sf.y1, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.6 铸剑地炉 → 栖剑别院（垂直桥）──
    local fgBotCx = math.floor((fg.x1 + fg.x2) / 2)
    local scTopCx = math.floor((sc.x1 + sc.x2) / 2)
    local bridgeFGSC_x = math.min(fgBotCx, scTopCx)
    drawVerticalBridge(self, bridgeFGSC_x, fg.y2, sc.y1, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.7 悟剑碑林 → 藏经书阁（垂直桥）──
    local sfBotCx = math.floor((sf.x1 + sf.x2) / 2)
    local lbTopCx = math.floor((lb.x1 + lb.x2) / 2)
    local bridgeSFLB_x = math.floor((sfBotCx + lbTopCx) / 2)
    drawVerticalBridge(self, bridgeSFLB_x, sf.y2, lb.y1, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.8（已移除：地炉不再直连剑宫）──

    -- ── 3.10 栖剑别院 → 剑宫（L形带墙桥：别院右上角内侧出发→右拐进入剑宫左侧）──
    -- 路线：从别院右上角(x≈21)出发，先垂直向上走到剑宫中部Y(≈32)，再水平向右进入剑宫
    local palaceSafeY = math.floor((palace.y1 + palace.y2) / 2) -- 剑宫中部（y≈32）
    local courtBridgeX = sc.x2 - 1  -- 别院右侧内1格 = 21（贴近别院右边缘）

    -- 段1：垂直段 从别院顶部(y=38)向上直走到剑宫中部Y(≈32)
    drawVerticalBridge(self, courtBridgeX, sc.y1, palaceSafeY, T.CH5_BRIDGE, T.CH5_WALL)
    -- 段2：水平段 右拐进入剑宫（从x=21到palace.x1+2=28）
    drawHorizontalBridge(self, palaceSafeY, courtBridgeX, palace.x1 + 2, T.CH5_BRIDGE, T.CH5_WALL)
    -- 清除别院出口（桥起点在别院内部，确保顶部3格通道畅通）
    for dy = -1, 1 do
        for dx = -1, 1 do
            safeTile(self, courtBridgeX + dx, sc.y1 + dy, T.CH5_BRIDGE)
        end
    end
    -- 清除剑宫入口（让桥连通到剑宫地面）
    for dy = -1, 1 do
        safeTile(self, palace.x1, palaceSafeY + dy, T.CH5_PALACE_WHITE)
        safeTile(self, palace.x1 + 1, palaceSafeY + dy, T.CH5_PALACE_WHITE)
    end

    -- ── 3.11 悟剑碑林 → 剑宫（水平带墙桥：碑林左侧→向左→进入剑宫右侧）──
    -- 碑林(x=58-77, y=20-43)与剑宫(x=26-54, y=23-42)在Y轴重叠
    -- 水平桥在剑宫安全区Y高度(palaceSafeY)连接两区域
    drawHorizontalBridge(self, palaceSafeY, palace.x2, sf.x1, T.CH5_BRIDGE, T.CH5_WALL)
    -- 清除进入点附近的墙
    for dy = -1, 1 do
        safeTile(self, palace.x2, palaceSafeY + dy, T.CH5_PALACE_WHITE)
        safeTile(self, palace.x2 - 1, palaceSafeY + dy, T.CH5_PALACE_WHITE)
        safeTile(self, sf.x1, palaceSafeY + dy, T.CH5_STELE_PALE)
        safeTile(self, sf.x1 + 1, palaceSafeY + dy, T.CH5_STELE_PALE)
    end

    -- ── 3.14 剑宫 → 镇魔深渊（垂直桥，跨6行虚空）──
    drawVerticalBridge(self, palCx, palace.y2, abyss.y1, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.15 栖剑别院 → 剑气城墙（垂直桥，跨别院底到城墙上缘）──
    local entryLeftCx = math.floor((sc.x1 + sc.x2) / 2)
    drawVerticalBridge(self, entryLeftCx, sc.y2, wallTopY, T.CH5_BRIDGE, T.CH5_WALL)

    -- ── 3.16 镇魔深渊 → 剑气城墙（已封死：岩浆墙封底，不再相通）──

    -- ── 3.17 藏经书阁 → 剑气城墙（垂直桥）──
    local entryRightCx = math.floor((lb.x1 + lb.x2) / 2)
    drawVerticalBridge(self, entryRightCx, lb.y2, wallTopY, T.CH5_BRIDGE, T.CH5_WALL)

    -- 城墙三个入口（在上城垛开3格宽缺口，让桥连通到走道）
    -- 左右两个入口有桥梁，需清除桥墙；深渊入口无桥，不清除
    local bridgeEntries = { entryLeftCx, entryRightCx }
    for _, ex in ipairs(bridgeEntries) do
        for d = -1, 1 do
            safeTile(self, ex + d, wallTopY,     T.CH5_CITY_WALL)
            safeTile(self, ex + d, wallTopY + 1, T.CH5_CITY_WALL)
        end
        -- 清除桥在城垛位置的墙壁，保证通行
        safeTile(self, ex - 2, wallTopY,     T.CH5_VOID)
        safeTile(self, ex + 2, wallTopY,     T.CH5_VOID)
        safeTile(self, ex - 2, wallTopY + 1, T.CH5_VOID)
        safeTile(self, ex + 2, wallTopY + 1, T.CH5_VOID)
    end
    -- （深渊入口已封死：岩浆墙封底，不再开城垛缺口，不再有血河连通城墙）

    -- ================================================================
    -- Step 3.9: BOSS 房（最后绘制，不被其他步骤覆盖）
    -- 四封剑台：12×12 = 2层厚墙 + 8×8 内部血祭台
    -- 从剑宫四角向外突出到虚空中
    -- ================================================================
    local bossSize = 12
    local bossWall = 2

    -- palace = {x1=26, y1=23, x2=54, y2=42}
    -- 上方BOSS房：突出到palace上方的虚空（y1-4到y1+7）
    -- 下方BOSS房：突出到palace下方的虚空（y2-7到y2+4）
    local bossRooms = {
        -- 左上：从palace左上角向上突出
        { x = palace.x1 - 2, y = palace.y1 - 4, doorSide = "rb" },
        -- 右上：从palace右上角向上突出
        { x = palace.x2 - 9, y = palace.y1 - 4, doorSide = "lb" },
        -- 左下：从palace左下角向下突出
        { x = palace.x1 - 2, y = palace.y2 - 7, doorSide = "rt" },
        -- 右下：从palace右下角向下突出
        { x = palace.x2 - 9, y = palace.y2 - 7, doorSide = "lt" },
    }
    for _, room in ipairs(bossRooms) do
        local rx, ry = room.x, room.y
        -- 12×12：先画墙再画内部
        for dy = 0, bossSize - 1 do
            for dx = 0, bossSize - 1 do
                local isW = (dx < bossWall or dx >= bossSize - bossWall
                          or dy < bossWall or dy >= bossSize - bossWall)
                if isW then
                    safeTile(self, rx + dx, ry + dy, T.CH5_WALL)
                else
                    safeTile(self, rx + dx, ry + dy, T.CH5_BLOOD_RITUAL)
                end
            end
        end
        -- 门洞：3格宽
        local doorCX = rx + math.floor(bossSize / 2)
        local doorCY = ry + math.floor(bossSize / 2)
        local ds = room.doorSide
        -- 右墙开门
        if ds == "rb" or ds == "rt" then
            for d = -1, 1 do
                for w = 0, bossWall - 1 do
                    safeTile(self, rx + bossSize - 1 - w, doorCY + d, T.CH5_BLOOD_RITUAL)
                end
            end
        end
        -- 左墙开门
        if ds == "lb" or ds == "lt" then
            for d = -1, 1 do
                for w = 0, bossWall - 1 do
                    safeTile(self, rx + w, doorCY + d, T.CH5_BLOOD_RITUAL)
                end
            end
        end
        -- 下墙开门
        if ds == "rb" or ds == "lb" then
            for d = -1, 1 do
                for w = 0, bossWall - 1 do
                    safeTile(self, doorCX + d, ry + bossSize - 1 - w, T.CH5_BLOOD_RITUAL)
                end
            end
        end
        -- 上墙开门
        if ds == "rt" or ds == "lt" then
            for d = -1, 1 do
                for w = 0, bossWall - 1 do
                    safeTile(self, doorCX + d, ry + w, T.CH5_BLOOD_RITUAL)
                end
            end
        end
    end

    -- ================================================================
    -- Step 3.9a: 手工坐标修正（移除指定阻隔 / 虚空 / 替换地板）
    -- ================================================================

    -- 任务2：移除 (21,34)(22,34) 阻隔，替换为桥面
    safeTile(self, 21, 34, T.CH5_BRIDGE)
    safeTile(self, 22, 34, T.CH5_BRIDGE)
    -- 任务2：(28,31)(28,32)(28,33) 替换为白色地板
    safeTile(self, 28, 31, T.CH5_PALACE_WHITE)
    safeTile(self, 28, 32, T.CH5_PALACE_WHITE)
    safeTile(self, 28, 33, T.CH5_PALACE_WHITE)

    -- 任务3：移除 (19,41)(17,41)(19,43) 别院阻隔
    safeTile(self, 19, 41, T.CH5_COURTYARD_MOSS)
    safeTile(self, 17, 41, T.CH5_COURTYARD_MOSS)
    safeTile(self, 19, 43, T.CH5_COURTYARD_MOSS)

    -- 任务4：祀剑池 3×2（剑宫正中央，palCx=40, palCy=32）
    -- 左上角 = (palCx-1, palCy) = (39, 32)，右下角 = (41, 33)
    for dy = 0, 1 do
        for dx = -1, 1 do
            safeTile(self, palCx + dx, palCy + dy, T.CH5_BLOOD_POOL)
        end
    end

    -- 任务6：铸剑地炉 3×3（地炉中央，fgCx=10, fgCy=27）
    -- 左上角 = (fgCx-1, fgCy-1) = (9, 26)，右下角 = (11, 28)
    for dy = -1, 1 do
        for dx = -1, 1 do
            safeTile(self, fgCx + dx, fgCy + dy, T.CH5_FURNACE)
        end
    end

    -- (12,59) 阻挡移除
    safeTile(self, 12, 59, T.CH5_COURTYARD_MOSS)

    -- 任务5：移除虚空
    safeTile(self, 11, 39, T.CH5_COURTYARD_MOSS)   -- 在别院范围内
    safeTile(self, 12, 49, T.CH5_COURTYARD_MOSS)   -- 在别院范围内
    safeTile(self, 4,  40, T.CH5_COURTYARD_MOSS)   -- 在别院范围内
    safeTile(self, 4,  41, T.CH5_COURTYARD_MOSS)   -- 在别院范围内

    -- ================================================================
    -- Step 3.95: 移除孤立单格虚空瓦片
    -- ================================================================
    for y = 2, H - 1 do
        for x = 2, W - 1 do
            if self:GetTile(x, y) == T.CH5_VOID then
                local tUp    = self:GetTile(x, y - 1)
                local tDown  = self:GetTile(x, y + 1)
                local tLeft  = self:GetTile(x - 1, y)
                local tRight = self:GetTile(x + 1, y)
                if tUp ~= T.CH5_VOID and tDown ~= T.CH5_VOID
                   and tLeft ~= T.CH5_VOID and tRight ~= T.CH5_VOID then
                    self:SetTile(x, y, tUp)
                end
            end
        end
    end

    -- ================================================================
    -- Step 4: 边界缓冲带（外围 2 格填虚空）
    -- ================================================================
    for y = 1, H do
        for x = 1, W do
            if x <= 2 or x >= W - 1 or y <= 2 or y >= H - 1 then
                self:SetTile(x, y, T.CH5_VOID)
            end
        end
    end

    print("[Chapter5] Terrain generation complete: " .. W .. "x" .. H)
end

end
