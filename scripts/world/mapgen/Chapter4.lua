-- ============================================================================
-- Chapter4.lua - 第四章地形生成（肆章·八卦海）
-- 80×80 深海地图，中央龟背岛 + 8阵法岛 + 4海兽岛
-- 所有岛屿为切角矩形，阵法岛含爻纹障碍
-- 中央岛为巨大神龟形状（龟头朝南＝离卦方向，符合后天八卦）
-- ============================================================================

---@param GameMap table
---@param zd table  ZoneData proxy
return function(GameMap, zd)

-- ============================================================================
-- 辅助：切角矩形填充
-- ============================================================================
local function fillCutCornerIsland(self, x1, y1, x2, y2, C, floorTile, wallTile, seaTile)
    local W = x2 - x1 + 1
    local H = y2 - y1 + 1

    for ly = 0, H - 1 do
        for lx = 0, W - 1 do
            local gx = x1 + lx
            local gy = y1 + ly

            local inCorner = false
            if lx + ly < C then inCorner = true end
            if (W - 1 - lx) + ly < C then inCorner = true end
            if lx + (H - 1 - ly) < C then inCorner = true end
            if (W - 1 - lx) + (H - 1 - ly) < C then inCorner = true end

            if inCorner then
                self:SetTile(gx, gy, seaTile)
            elseif lx == 0 or lx == W - 1 or ly == 0 or ly == H - 1 then
                self:SetTile(gx, gy, wallTile)
            else
                self:SetTile(gx, gy, floorTile)
            end
        end
    end
end

-- ============================================================================
-- 辅助：绘制神龟岛（龟背岛）
-- 龟头朝南（+y，离卦方向），龟尾朝北（-y，坎卦方向）
-- 符合后天八卦方位布局
-- 龟壳 16×16 (32,32)→(47,47) C=4，全部可行走（仅 SEA_SAND + REEF_FLOOR）
-- ============================================================================
local function drawTurtleIsland(self, layout, T)
    local hv = layout.haven
    local SAND = T.SEA_SAND
    local WALL = T.CORAL_WALL
    local REEF = T.REEF_FLOOR
    local SEA  = T.SHALLOW_SEA

    -- 龟壳中心 x（整数）：(32+47)/2 = 39.5 → floor = 39
    local cx = math.floor((hv.x1 + hv.x2) / 2)  -- 39

    -- ── A: 龟壳主体（切角矩形 16×16, C=4） ──
    -- wallTile = WALL（壳边缘为珊瑚墙，不可通行）
    fillCutCornerIsland(self, hv.x1, hv.y1, hv.x2, hv.y2,
        hv.cornerCut, SAND, WALL, SEA)

    -- ── B: 龟甲纹路（REEF_FLOOR 装饰，全部可行走） ──
    -- 三条水平分割线（将龟壳分为四段）
    for x = hv.x1 + 3, hv.x2 - 3 do
        self:SetTile(x, hv.y1 + 4,  REEF)   -- y=36
        self:SetTile(x, hv.y1 + 8,  REEF)   -- y=40
        self:SetTile(x, hv.y1 + 12, REEF)   -- y=44
    end
    -- 中央纵线（脊椎线，双宽）
    for y = hv.y1 + 3, hv.y2 - 3 do
        self:SetTile(cx, y, REEF)       -- x=39
        self:SetTile(cx + 1, y, REEF)   -- x=40
    end
    -- 侧面横线（肋骨纹，上下各一对，左右各一段，不穿过脊椎）
    for x = hv.x1 + 3, cx - 1 do
        self:SetTile(x, hv.y1 + 6,  REEF)   -- y=38 左半
        self:SetTile(x, hv.y1 + 10, REEF)   -- y=42 左半
    end
    for x = cx + 2, hv.x2 - 3 do
        self:SetTile(x, hv.y1 + 6,  REEF)   -- y=38 右半
        self:SetTile(x, hv.y1 + 10, REEF)   -- y=42 右半
    end

    -- ── C: 龟头（朝南 +y，离卦方向，保持原尺寸不变） ──
    local headY = hv.y2 + 1  -- y=48，壳底下方

    -- 颈部（4宽）
    for x = cx - 1, cx + 2 do
        self:SetTile(x, headY, SAND)        -- y=48
    end
    -- 头部主体（6宽）
    for x = cx - 2, cx + 3 do
        self:SetTile(x, headY + 1, SAND)    -- y=49
    end
    -- 头部收窄（4宽）
    for x = cx - 1, cx + 2 do
        self:SetTile(x, headY + 2, SAND)    -- y=50
    end
    -- 嘴部（2宽）
    self:SetTile(cx, headY + 3, SAND)       -- y=51
    self:SetTile(cx + 1, headY + 3, SAND)

    -- 眼睛（REEF_FLOOR 可行走，颜色区分即可）
    self:SetTile(cx - 1, headY + 1, REEF)   -- 左眼 (38,49)
    self:SetTile(cx + 2, headY + 1, REEF)   -- 右眼 (41,49)

    -- ── D: 龟尾（朝北 -y，坎卦方向，扩展为 3 行锥形） ──
    local tailY = hv.y1 - 1  -- y=31

    -- 尾根（4宽）
    for x = cx - 1, cx + 2 do
        self:SetTile(x, tailY, REEF)        -- y=31
    end
    -- 尾中（2宽）
    self:SetTile(cx, tailY - 1, REEF)       -- y=30
    self:SetTile(cx + 1, tailY - 1, REEF)
    -- 尾尖（2宽）
    self:SetTile(cx, tailY - 2, REEF)       -- y=29
    self:SetTile(cx + 1, tailY - 2, REEF)

    -- ── E: 四肢（REEF_FLOOR 桨形，~7 格/肢，含 2 桥接格） ──

    -- 左后肢（西北方，乾位附近）—— 桥接 + 肢体
    self:SetTile(hv.x1 - 1, hv.y1 + 2, REEF)   -- (31,34) 桥接1
    self:SetTile(hv.x1 - 1, hv.y1 + 3, REEF)   -- (31,35) 桥接2
    self:SetTile(hv.x1 - 2, hv.y1 + 1, REEF)   -- (30,33)
    self:SetTile(hv.x1 - 2, hv.y1 + 2, REEF)   -- (30,34)
    self:SetTile(hv.x1 - 2, hv.y1 + 3, REEF)   -- (30,35)
    self:SetTile(hv.x1 - 3, hv.y1 + 2, REEF)   -- (29,34)
    self:SetTile(hv.x1 - 3, hv.y1 + 3, REEF)   -- (29,35)

    -- 右后肢（东北方，艮位附近）
    self:SetTile(hv.x2 + 1, hv.y1 + 2, REEF)   -- (48,34) 桥接1
    self:SetTile(hv.x2 + 1, hv.y1 + 3, REEF)   -- (48,35) 桥接2
    self:SetTile(hv.x2 + 2, hv.y1 + 1, REEF)   -- (49,33)
    self:SetTile(hv.x2 + 2, hv.y1 + 2, REEF)   -- (49,34)
    self:SetTile(hv.x2 + 2, hv.y1 + 3, REEF)   -- (49,35)
    self:SetTile(hv.x2 + 3, hv.y1 + 2, REEF)   -- (50,34)
    self:SetTile(hv.x2 + 3, hv.y1 + 3, REEF)   -- (50,35)

    -- 左前肢（西南方，坤位附近）
    self:SetTile(hv.x1 - 1, hv.y2 - 3, REEF)   -- (31,44) 桥接1
    self:SetTile(hv.x1 - 1, hv.y2 - 2, REEF)   -- (31,45) 桥接2
    self:SetTile(hv.x1 - 2, hv.y2 - 3, REEF)   -- (30,44)
    self:SetTile(hv.x1 - 2, hv.y2 - 2, REEF)   -- (30,45)
    self:SetTile(hv.x1 - 2, hv.y2 - 1, REEF)   -- (30,46)
    self:SetTile(hv.x1 - 3, hv.y2 - 3, REEF)   -- (29,44)
    self:SetTile(hv.x1 - 3, hv.y2 - 2, REEF)   -- (29,45)

    -- 右前肢（东南方，巽位附近）
    self:SetTile(hv.x2 + 1, hv.y2 - 3, REEF)   -- (48,44) 桥接1
    self:SetTile(hv.x2 + 1, hv.y2 - 2, REEF)   -- (48,45) 桥接2
    self:SetTile(hv.x2 + 2, hv.y2 - 3, REEF)   -- (49,44)
    self:SetTile(hv.x2 + 2, hv.y2 - 2, REEF)   -- (49,45)
    self:SetTile(hv.x2 + 2, hv.y2 - 1, REEF)   -- (49,46)
    self:SetTile(hv.x2 + 3, hv.y2 - 3, REEF)   -- (50,44)
    self:SetTile(hv.x2 + 3, hv.y2 - 2, REEF)   -- (50,45)

    -- ── F: 腰弧（壳两侧各 +1 格突出，y=39,40） ──
    self:SetTile(hv.x1 - 1, hv.y1 + 7, REEF)   -- (31,39)
    self:SetTile(hv.x1 - 1, hv.y1 + 8, REEF)   -- (31,40)
    self:SetTile(hv.x2 + 1, hv.y1 + 7, REEF)   -- (48,39)
    self:SetTile(hv.x2 + 1, hv.y1 + 8, REEF)   -- (48,40)

    -- 腰部壳壁打通：移除 (32,39)(32,40)(47,39)(47,40) 的遮挡，连通壳内→腰弧
    self:SetTile(hv.x1, hv.y1 + 7, SAND)        -- (32,39) 壁→沙
    self:SetTile(hv.x1, hv.y1 + 8, SAND)        -- (32,40) 壁→沙
    self:SetTile(hv.x2, hv.y1 + 7, SAND)        -- (47,39) 壁→沙
    self:SetTile(hv.x2, hv.y1 + 8, SAND)        -- (47,40) 壁→沙

    -- ── G: 开通道（打通壳边缘/切角，连接头尾四肢） ──

    -- 龟头通道：覆盖南边缘 y=y2(47)，颈部宽度 4 格 → SAND（平滑过渡）
    for x = cx - 1, cx + 2 do
        self:SetTile(x, hv.y2, SAND)             -- (38~41, 47) 边缘→沙
    end

    -- 龟尾通道：覆盖北边缘 y=y1(32)，尾部宽度 4 格 → REEF
    for x = cx - 1, cx + 2 do
        self:SetTile(x, hv.y1, REEF)             -- (38~41, 32) 边缘→礁
    end

    -- 四肢通道：填补切角区，确保壳内与肢体连通
    -- 左后肢（NW）：(32,34)(32,35) 是切角区，需覆盖
    self:SetTile(hv.x1, hv.y1 + 2, REEF)         -- (32,34) 切角→礁
    self:SetTile(hv.x1, hv.y1 + 3, REEF)         -- (32,35) 切角→礁

    -- 右后肢（NE）：(47,34)(47,35) 是切角区
    self:SetTile(hv.x2, hv.y1 + 2, REEF)         -- (47,34) 切角→礁
    self:SetTile(hv.x2, hv.y1 + 3, REEF)         -- (47,35) 切角→礁

    -- 左前肢（SW）：(32,44)(32,45) 是切角区
    self:SetTile(hv.x1, hv.y2 - 3, REEF)         -- (32,44) 切角→礁
    self:SetTile(hv.x1, hv.y2 - 2, REEF)         -- (32,45) 切角→礁

    -- 右前肢（SE）：(47,44)(47,45) 是切角区
    self:SetTile(hv.x2, hv.y2 - 3, REEF)         -- (47,44) 切角→礁
    self:SetTile(hv.x2, hv.y2 - 2, REEF)         -- (47,45) 切角→礁
end

-- ============================================================================
-- 辅助：绘制爻纹障碍（单层）
-- ============================================================================
local function drawYaoPattern(self, x1, y1, yaoPattern, reefTile)
    if not yaoPattern then return end

    -- 爻纹行偏移（相对岛屿 y1，16×16 岛内）
    -- 上爻 row 4, 中爻 row 7, 下爻 row 10（单层）
    local yaoRows = { {4}, {7}, {10} }

    for i, yaoType in ipairs(yaoPattern) do
        local rows = yaoRows[i]
        for _, rowOff in ipairs(rows) do
            local gy = y1 + rowOff
            if yaoType == "yang" then
                -- 阳爻：8格连续（lx 4~11），居中
                for lx = 4, 11 do
                    self:SetTile(x1 + lx, gy, reefTile)
                end
            else
                -- 阴爻：两段各3格（lx 4~6 + 9~11），中间2格间断
                for lx = 4, 6 do
                    self:SetTile(x1 + lx, gy, reefTile)
                end
                for lx = 9, 11 do
                    self:SetTile(x1 + lx, gy, reefTile)
                end
            end
        end
    end
end

-- ============================================================================
-- 主入口：第四章地形生成
-- ============================================================================
function GameMap:BuildCh4Terrain()
    local T = zd.TILE
    local layout = zd.LAYOUT
    if not layout then
        print("[Chapter4] No LAYOUT in ZoneData, skipping")
        return
    end

    local W = self.width
    local H = self.height
    local cx = layout.center.x
    local cy = layout.center.y
    local R = layout.seaRadius

    -- ================================================================
    -- Step 1: 全图填充深海
    -- ================================================================
    for y = 1, H do
        for x = 1, W do
            self:SetTile(x, y, T.DEEP_SEA)
        end
    end

    -- ================================================================
    -- Step 2: 圆形海域 R=38 → 浅海
    -- ================================================================
    for y = 1, H do
        for x = 1, W do
            local dx = x - cx
            local dy = y - cy
            if dx * dx + dy * dy <= R * R then
                self:SetTile(x, y, T.SHALLOW_SEA)
            end
        end
    end

    -- ================================================================
    -- Step 3: 中央龟背岛（神龟形状，龟头朝南）
    -- ================================================================
    drawTurtleIsland(self, layout, T)

    -- ================================================================
    -- Step 4: 八阵法岛 + 爻纹
    -- ================================================================
    for name, island in pairs(layout.islands) do
        fillCutCornerIsland(self, island.x1, island.y1, island.x2, island.y2,
            island.cornerCut, T.REEF_FLOOR, T.SEA_SAND, T.SHALLOW_SEA)

        -- 绘制爻纹障碍
        local mod = zd.islandModules and zd.islandModules[name]
        if mod and mod.yaoPattern then
            drawYaoPattern(self, island.x1, island.y1, mod.yaoPattern, T.ROCK_REEF)
        end
    end

    -- ================================================================
    -- Step 4.5: 阵法岛朝向龟背岛一侧的 2×2 沙滩（放置回程传送阵）
    -- 各岛面向中心(40,40)最近边外侧 2×2 SEA_SAND
    -- ================================================================
    -- 相生链: 坎→艮→震→巽→离→坤→兑→乾→坎（顺时针）
    -- 每岛沙滩朝向顺时针相邻岛，暗含八卦相生逻辑
    local beachData = {
        kan  = { {48,14},{49,14},{48,15},{49,15} },  -- 东侧→朝艮
        gen  = { {57,30},{58,30},{57,31},{58,31} },  -- 南侧→朝震
        zhen = { {64,48},{65,48},{64,49},{65,49} },  -- 南侧→朝巽
        xun  = { {48,57},{49,57},{48,58},{49,58} },  -- 西侧→朝离
        li   = { {30,64},{31,64},{30,65},{31,65} },  -- 西侧→朝坤
        kun  = { {21,48},{22,48},{21,49},{22,49} },  -- 北侧→朝兑
        dui  = { {14,30},{15,30},{14,31},{15,31} },  -- 北侧→朝乾
        qian = { {30,21},{31,21},{30,22},{31,22} },  -- 东侧→朝坎
    }
    for _, tiles in pairs(beachData) do
        for _, pos in ipairs(tiles) do
            self:SetTile(pos[1], pos[2], T.SEA_SAND)
        end
    end

    -- ================================================================
    -- Step 4.6: 四隅卦神兽岛传送沙滩（回龟背岛沙滩的反方向）
    -- 乾→北冥(西侧), 艮→东渊(北侧), 巽→南溟(东侧), 坤→西沧(南侧)
    -- ================================================================
    local beastBeachData = {
        qian = { {12,21},{13,21},{12,22},{13,22} },  -- 西侧（回龟背在东侧）
        gen  = { {57,12},{58,12},{57,13},{58,13} },  -- 北侧（回龟背在南侧）
        xun  = { {66,57},{67,57},{66,58},{67,58} },  -- 东侧（回龟背在西侧）
        kun  = { {21,66},{22,66},{21,67},{22,67} },  -- 南侧（回龟背在北侧）
    }
    for _, tiles in pairs(beastBeachData) do
        for _, pos in ipairs(tiles) do
            self:SetTile(pos[1], pos[2], T.SEA_SAND)
        end
    end

    -- ================================================================
    -- Step 5: 四龙种岛（自然不规则海岸 + 厚礁石过渡 + 专属瓦片）
    -- ================================================================
    local beastLayout = layout.beastIslands

    -- 辅助: 安全设置瓦片
    local function safeTile(gx, gy, tile)
        if gx >= 1 and gx <= W and gy >= 1 and gy <= H then
            self:SetTile(gx, gy, tile)
        end
    end

    -- 辅助: 整数哈希伪噪声（确定性，无需 math.random）
    -- 返回 0.0~1.0
    local function hash2(ix, iy, seed)
        local n = ix * 374761393 + iy * 668265263 + seed * 1274126177
        n = (n ~ (n >> 13)) * 1103515245
        n = n ~ (n >> 16)
        return (n % 10000) / 10000
    end

    -- 辅助: 平滑噪声（双线性插值 hash 值，频率由 freq 控制）
    local function smoothNoise(fx, fy, seed)
        local ix = math.floor(fx)
        local iy = math.floor(fy)
        local fracX = fx - ix
        local fracY = fy - iy
        -- 平滑步进
        fracX = fracX * fracX * (3 - 2 * fracX)
        fracY = fracY * fracY * (3 - 2 * fracY)
        local v00 = hash2(ix,     iy,     seed)
        local v10 = hash2(ix + 1, iy,     seed)
        local v01 = hash2(ix,     iy + 1, seed)
        local v11 = hash2(ix + 1, iy + 1, seed)
        local a = v00 + (v10 - v00) * fracX
        local b5 = v01 + (v11 - v01) * fracX
        return a + (b5 - a) * fracY
    end

    -- 辅助: 分形噪声（2 层叠加，返回 0~1）
    local function fractalNoise(gx, gy, seed, freq)
        local f = freq or 0.25
        local n1 = smoothNoise(gx * f,       gy * f,       seed)
        local n2 = smoothNoise(gx * f * 2.3, gy * f * 2.3, seed + 777)
        return n1 * 0.65 + n2 * 0.35
    end

    -- ────────────────────────────────────────────────────────────────
    -- 通用龙种岛生成函数（增强版：角度噪声 → 半岛/海湾 + 安全着陆区）
    -- b          : bounds {x1,y1,x2,y2}
    -- floorTile  : 专属可通行地面
    -- wallTile   : 专属不可通行障碍
    -- seed       : 噪声种子（每岛不同）
    -- safePoints : {{x,y}, ...}  传送落脚点/NPC 坐标（整数瓦片），
    --              生成后在这些位置周围清出安全通行区
    --
    -- 海岸线公式:
    --   coastLine = base + angularLobe + angularBay + posNoise
    --   angularLobe : 低频角度正弦 → 3~5 个大瓣（半岛突出）
    --   angularBay  : 高频角度正弦 → 小海湾凹陷
    --   posNoise    : 位置分形噪声 → 打破角度对称性
    -- ────────────────────────────────────────────────────────────────
    local function buildBeastIsland(b, floorTile, wallTile, seed, safePoints)
        local bcx = (b.x1 + b.x2) / 2
        local bcy = (b.y1 + b.y2) / 2
        local hrx = (b.x2 - b.x1) / 2
        local hry = (b.y2 - b.y1) / 2

        -- 每岛不同的瓣数与相位
        local lobeCount = 3 + (seed % 3)         -- 3, 4, 或 5 个大半岛
        local lobePhase = (seed % 100) * 0.0628   -- 随机相位偏移
        local bayCount  = lobeCount * 2 + 1       -- 高频海湾数
        local bayPhase  = lobePhase + 1.37        -- 海湾相位与半岛错开

        -- 扫描 bounds 扩展 3 格（半岛可能突出更远）
        for gy = b.y1 - 3, b.y2 + 3 do
            for gx = b.x1 - 3, b.x2 + 3 do
                local dx = (gx - bcx) / hrx
                local dy = (gy - bcy) / hry
                local baseDist = math.sqrt(dx * dx + dy * dy)

                -- 角度（弧度），用于方向性变形
                local angle = math.atan(dy, dx)

                -- 大瓣（半岛突出）: 振幅 0.14，向外凸
                local angularLobe = math.sin(angle * lobeCount + lobePhase) * 0.14
                -- 小湾（海湾凹陷）: 振幅 0.07，向内凹
                local angularBay  = math.sin(angle * bayCount + bayPhase) * 0.07
                -- 位置噪声打破对称性
                local posNoise = (fractalNoise(gx, gy, seed, 0.3) - 0.5) * 0.22
                -- 第二层位置噪声增加细节碎裂感
                local detailNoise = (fractalNoise(gx, gy, seed + 500, 0.55) - 0.5) * 0.10

                -- 合成海岸线阈值
                local coastLine = 0.86 + angularLobe + angularBay + posNoise + detailNoise
                -- 钳制到合理范围
                if coastLine < 0.68 then coastLine = 0.68 end
                if coastLine > 1.15 then coastLine = 1.15 end

                if baseDist < coastLine then
                    local ratio = baseDist / coastLine  -- 0~1 归一化

                    if ratio < 0.48 then
                        -- 核心区：纯 floorTile
                        safeTile(gx, gy, floorTile)
                    elseif ratio < 0.62 then
                        -- 内过渡：少量 wallTile 装饰（~8%）
                        local decor = hash2(gx, gy, seed + 100)
                        if decor < 0.08 then
                            safeTile(gx, gy, wallTile)
                        else
                            safeTile(gx, gy, floorTile)
                        end
                    elseif ratio < 0.78 then
                        -- 中过渡：ROCK_REEF + wallTile（~25%）
                        local reef = hash2(gx, gy, seed + 200)
                        if reef < 0.15 then
                            safeTile(gx, gy, T.ROCK_REEF)
                        elseif reef < 0.25 then
                            safeTile(gx, gy, wallTile)
                        else
                            safeTile(gx, gy, floorTile)
                        end
                    elseif ratio < 0.90 then
                        -- 外过渡：密集礁石（~55%）
                        local reef = hash2(gx, gy, seed + 300)
                        if reef < 0.35 then
                            safeTile(gx, gy, T.ROCK_REEF)
                        elseif reef < 0.55 then
                            safeTile(gx, gy, wallTile)
                        else
                            safeTile(gx, gy, floorTile)
                        end
                    else
                        -- 最外礁：极密（~75%）
                        local reef = hash2(gx, gy, seed + 400)
                        if reef < 0.45 then
                            safeTile(gx, gy, T.ROCK_REEF)
                        elseif reef < 0.75 then
                            safeTile(gx, gy, wallTile)
                        else
                            safeTile(gx, gy, floorTile)
                        end
                    end
                end
            end
        end

        -- ── 安全着陆区：清除传送点/NPC 周围的障碍，确保通行 ──
        if safePoints then
            for _, sp in ipairs(safePoints) do
                local sx = math.floor(sp.x)
                local sy = math.floor(sp.y)
                -- 清出 5×5 菱形区（曼哈顿距离 ≤ 2）
                for dy2 = -2, 2 do
                    for dx2 = -2, 2 do
                        if math.abs(dx2) + math.abs(dy2) <= 2 then
                            safeTile(sx + dx2, sy + dy2, floorTile)
                        end
                    end
                end
            end
        end
    end

    -- 5-1  封霜应龙·玄冰岛 (NW, 冰雪主题)
    buildBeastIsland(beastLayout.beast_north, T.ICE_FLOOR, T.ICE_WALL, 1001, {
        {x = 7.5, y = 10.5},   -- 传送落脚点
        {x = 7.5, y = 11.5},   -- 回乾阵 NPC
    })

    -- 5-2  堕渊蛟龙·幽渊岛 (NE, 深渊主题)
    buildBeastIsland(beastLayout.beast_east, T.ABYSS_FLOOR, T.ABYSS_WALL, 2002, {
        {x = 71.5, y = 11.5},  -- 传送落脚点
        {x = 71.5, y = 12.5},  -- 回艮阵 NPC
    })

    -- 5-3  焚天蜃龙·烈焰岛 (SE, 火山主题)
    buildBeastIsland(beastLayout.beast_south, T.VOLCANO_FLOOR, T.VOLCANO_WALL, 3003, {
        {x = 70.5, y = 74.5},  -- 传送落脚点
        {x = 71.5, y = 74.5},  -- 回巽阵 NPC
    })

    -- 5-4  蚀骨螭龙·流沙岛 (SW, 沙漠主题)
    buildBeastIsland(beastLayout.beast_west, T.DUNE_FLOOR, T.DUNE_WALL, 4004, {
        {x = 8.5, y = 73.5},   -- 传送落脚点
        {x = 8.5, y = 74.5},   -- 回坤阵 NPC
    })

    print("[Chapter4] Terrain generation complete: " .. W .. "x" .. H)
end

end
