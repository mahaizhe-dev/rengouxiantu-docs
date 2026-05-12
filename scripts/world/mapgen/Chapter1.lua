-- ============================================================================
-- mapgen/Chapter1.lua - 第一章地形生成（主城、围墙、装饰、区域隔离）
-- ============================================================================

---@param GameMap table
---@param activeZoneData table
return function(GameMap, activeZoneData)

function GameMap:BuildTownWalls(town)
    local T = activeZoneData.TILE
    local gates = activeZoneData.TOWN_GATES

    -- 判断某个坐标是否是出入口
    local function isGate(x, y)
        for _, g in ipairs(gates) do
            if x >= g.x1 and x <= g.x2 and y >= g.y1 and y <= g.y2 then
                return true
            end
        end
        return false
    end

    -- 上下边
    for x = town.x1, town.x2 do
        if not isGate(x, town.y1) then self:SetTile(x, town.y1, T.WALL) end
        if not isGate(x, town.y2) then self:SetTile(x, town.y2, T.WALL) end
    end
    -- 左右边
    for y = town.y1, town.y2 do
        if not isGate(town.x1, y) then self:SetTile(town.x1, y, T.WALL) end
        if not isGate(town.x2, y) then self:SetTile(town.x2, y, T.WALL) end
    end
end

--- 放置装饰物（将占用格标记为不可通行）
function GameMap:PlaceDecorations()
    local T = activeZoneData.TILE
    local decorations = activeZoneData.TownDecorations
    if not decorations then return end

    -- 初始化装饰物记录
    self.decorations = decorations

    for _, d in ipairs(decorations) do
        if d.type == "house" then
            -- 房屋占多格
            local w = d.w or 2
            local h = d.h or 2
            for dy = 0, h - 1 do
                for dx = 0, w - 1 do
                    self:SetTile(d.x + dx, d.y + dy, T.WALL)
                end
            end
        elseif d.type == "watchtower" then
            -- 瞭望塔占多格（与 house 类似）
            local w = d.w or 2
            local h = d.h or 2
            for dy = 0, h - 1 do
                for dx = 0, w - 1 do
                    self:SetTile(d.x + dx, d.y + dy, T.WALL)
                end
            end
        elseif d.type == "pond" then
            -- 池塘占多格，设为水
            local w = d.w or 2
            local h = d.h or 2
            for dy = 0, h - 1 do
                for dx = 0, w - 1 do
                    self:SetTile(d.x + dx, d.y + dy, T.WATER)
                end
            end
        elseif d.type == "well" or d.type == "barrel" or d.type == "tent" then
            -- 占 1 格不可通行
            self:SetTile(d.x, d.y, T.WALL)
        elseif d.type == "fence" then
            -- 木栅栏占 1 格不可通行
            self:SetTile(d.x, d.y, T.WALL)
        elseif d.type == "fallen_tree" or d.type == "dead_tree" then
            -- 倒木/枯树占 1 格不可通行
            self:SetTile(d.x, d.y, T.WALL)
        elseif d.type == "crack" then
            -- 裂谷占 1 格不可通行（危险区域）
            self:SetTile(d.x, d.y, T.WALL)
        end
        -- tree/lantern/flower/sign/stall/campfire/weapon_rack/cobweb/mushroom/crystal/
        -- stalactite/bush/flag/bone_pile/stone_tablet/healing_spring 仅作为视觉装饰，不阻挡移动
    end

    -- 预提取治愈泉列表，避免运行时每帧遍历全部装饰物
    self.healingSprings = {}
    for _, d in ipairs(decorations) do
        if d.type == "healing_spring" then
            table.insert(self.healingSprings, d)
        end
    end
end

function GameMap:BuildZoneBarriers()
    local T = activeZoneData.TILE
    local R = activeZoneData.Regions

    -- 第一章特有逻辑，其他章节跳过
    if not R.town or not R.bandit_backhill then return end

    -- 辅助函数：将 GRASS 设为 MOUNTAIN（不覆盖已有区域地板）
    local function setMountain(x, y)
        if x >= 2 and x <= 79 and y >= 2 and y <= 79 then
            local tile = self:GetTile(x, y)
            if tile == T.GRASS then
                self:SetTile(x, y, T.MOUNTAIN)
            end
        end
    end

    -- ============================================================
    -- 1. 虎啸林 完全封锁 (58,2)→(78,25)
    --    四面山岩包围，仅南侧 x=67~68 留2格入口
    -- ============================================================

    -- 西墙 (x=56~57, y=2~28)
    for y = 2, 28 do
        setMountain(56, y)
        setMountain(57, y)
    end

    -- 南墙 (x=56~79, y=26~27)，留入口 x=67~68
    for x = 56, 79 do
        if not (x >= 67 and x <= 68) then
            setMountain(x, 26)
            setMountain(x, 27)
        end
    end

    -- 东侧补齐（靠近地图边缘）
    for y = 2, 27 do
        setMountain(79, y)
    end

    -- ============================================================
    -- 2. 山贼寨 ↔ 中央区域 分隔（中等）
    --    竖向山脊 x=29, y=2~49（单列，主城缓冲区 x=30~32 保持草地）
    --    留口: y=39~42 (4格，对应主城西门 y=40~41)
    --    后山通道已封闭（y=7~15 不再留口），后山改为从北面荒野进入
    -- ============================================================
    for y = 2, 49 do
        if not (y >= 39 and y <= 42) and not (y >= 9 and y <= 13) then
            setMountain(29, y)
        end
    end
    -- 后山侧面封堵：x=30~32, y=3~21（留 y=9~13 作为山贼寨↔后山通道）
    for y = 3, 21 do
        if not (y >= 9 and y <= 13) then
            for x = 30, 32 do
                local tile = self:GetTile(x, y)
                if tile == T.GRASS or tile == T.CAMP_FLOOR then
                    self:SetTile(x, y, T.MOUNTAIN)
                end
            end
        end
    end

    -- 3. 羊肠小径/蜘蛛区 ↔ 中央区域：不设独立山脊，主城缓冲区 x=49~51 保持草地
    --    羊肠小径从 x=52 开始，由 BuildThickBorder 提供边界感

    -- ============================================================
    -- 5. 中北部荒野山脉
    --    新手村北面 (32,2)→(55,29) 大片荒野填充山地
    --    排除：山贼寨后山区域 (33,4)→(47,20) 已开辟为营地
    --    y 上限 29（主城缓冲区 y=30~32 保持草地）
    -- ============================================================
    local bhR = R.bandit_backhill
    for y = 2, 29 do
        for x = 32, 55 do
            -- 跳过后山内部（已填充 CAMP_FLOOR）
            if x >= bhR.x1 and x <= bhR.x2 and y >= bhR.y1 and y <= bhR.y2 then
                goto skip_north
            end
            -- 跳过虎王领地西墙区域（已处理）
            if x >= 56 then goto skip_north end
            local tile = self:GetTile(x, y)
            if tile == T.GRASS then
                local hash = ((x * 374761393 + y * 668265263) & 0x7FFFFFFF) % 100
                if hash < 65 then
                    self:SetTile(x, y, T.MOUNTAIN)
                end
            end
            ::skip_north::
        end
    end

    -- 后山边界加固：确保四周有密实山墙（补充 hash 遗漏的缝隙）
    -- 北墙 y=3，留口 x=38~41（4格宽，北侧入口）
    for x = bhR.x1, bhR.x2 do
        if not (x >= 38 and x <= 41) then
            setMountain(x, bhR.y1 - 1)
        end
    end
    -- 南墙 y=21
    for x = bhR.x1, bhR.x2 do setMountain(x, bhR.y2 + 1) end
    -- 东墙 x=48
    for y = bhR.y1, bhR.y2 do setMountain(bhR.x2 + 1, y) end
    -- 西侧由山脊 x=29~32 封死

    -- 后山北侧入口通道：清理 x=38~41, y=2~4 的山体，确保从荒野可进入
    for y = 2, bhR.y1 do
        for x = 38, 41 do
            local tile = self:GetTile(x, y)
            if tile == T.MOUNTAIN or tile == T.WALL then
                self:SetTile(x, y, T.CAMP_FLOOR)
            end
        end
    end

    -- 后山内部散落岩群（手动布置，避开装饰物和刷怪点）
    local backhillRocks = {
        -- 北侧岩群
        {35, 5}, {36, 5}, {35, 6},
        -- 东侧岩群
        {46, 8}, {47, 8}, {46, 9},
        -- 中部岩群
        {41, 13}, {42, 13}, {42, 14},
        -- 西侧岩群
        {34, 17}, {35, 17},
        -- 南侧岩群
        {43, 19}, {44, 19},
        -- 散落碎石
        {39, 6}, {45, 12}, {34, 14}, {42, 18},
    }
    for _, pos in ipairs(backhillRocks) do
        local tile = self:GetTile(pos[1], pos[2])
        if tile == T.CAMP_FLOOR then
            self:SetTile(pos[1], pos[2], T.MOUNTAIN)
        end
    end

    -- 蜘蛛区与虎王之间补充山脉 (x=51~55, y=26~29)
    for y = 26, 29 do
        for x = 51, 55 do
            setMountain(x, y)
        end
    end

    -- ============================================================
    -- 通道清理：确保关键通路畅通
    -- ============================================================
    -- 山贼寨↔后山通道 (x=29~32, y=9~13)
    for y = 9, 13 do
        for x = 29, 32 do
            local tile = self:GetTile(x, y)
            if tile == T.MOUNTAIN or tile == T.WALL then
                self:SetTile(x, y, T.CAMP_FLOOR)
            end
        end
    end
end

--- 在荒野过渡带散布碎石（MOUNTAIN），填充区域间空白草地
function GameMap:ScatterWildernessRocks()
    local T = activeZoneData.TILE
    local R = activeZoneData.Regions
    local town = R.town
    if not town then return end  -- 非第一章无过渡带数据，跳过

    -- 过渡带定义：{ x1, y1, x2, y2, density(%) }
    local zones = {
        -- 主城与野猪林之间（南部过渡）
        { x1 = 5,  y1 = 49, x2 = 38, y2 = 54, density = 15 },
        -- 主城与山贼寨之间（西部过渡）
        { x1 = 29, y1 = 25, x2 = 32, y2 = 48, density = 12 },
        -- 主城与羊肠小径之间（东部过渡）
        { x1 = 49, y1 = 30, x2 = 53, y2 = 50, density = 10 },
        -- 野猪林与蜘蛛洞之间（东南角）
        { x1 = 38, y1 = 52, x2 = 44, y2 = 60, density = 20 },
        -- 羊肠小径与虎王领地之间（东北过渡）
        { x1 = 52, y1 = 25, x2 = 60, y2 = 30, density = 18 },
    }

    -- 主城缓冲区范围（不在此放碎石）
    local bufX1, bufY1 = town.x1 - 3, town.y1 - 3
    local bufX2, bufY2 = town.x2 + 3, town.y2 + 3

    for _, z in ipairs(zones) do
        for y = z.y1, z.y2 do
            for x = z.x1, z.x2 do
                -- 跳过主城缓冲区
                if x >= bufX1 and x <= bufX2 and y >= bufY1 and y <= bufY2 then
                    goto nextRock
                end
                local tile = self:GetTile(x, y)
                if tile ~= T.GRASS then goto nextRock end
                -- 不在道路附近放（±1 格）
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local nb = self:GetTile(x + dx, y + dy)
                        if nb == T.TOWN_ROAD then goto nextRock end
                    end
                end
                -- hash 判定密度
                local hash = ((x * 374761393 + y * 668265263 + 54321) & 0x7FFFFFFF) % 100
                if hash < z.density then
                    -- 偶尔生成 2~3 格小簇
                    self:SetTile(x, y, T.MOUNTAIN)
                    if hash < z.density / 3 then
                        -- 簇：向右或向下延伸 1 格
                        local dir = hash % 2
                        local cx = x + (dir == 0 and 1 or 0)
                        local cy = y + (dir == 1 and 1 or 0)
                        local ct = self:GetTile(cx, cy)
                        if ct == T.GRASS then
                            self:SetTile(cx, cy, T.MOUNTAIN)
                        end
                    end
                end
                ::nextRock::
            end
        end
    end
end

-- ============================================================================
-- 堡垒轮廓生成（第二章专用）
-- 绘制堡垒外墙、内部分隔墙、通道口、BOSS房、凹陷甬道、封印门、晶石屏障
-- ============================================================================

function GameMap:ClearTownBuffer(radius)
    local T = activeZoneData.TILE
    local R = activeZoneData.Regions
    local town = R.town
    if not town then return end  -- 非第一章跳过

    local bx1 = town.x1 - radius  -- 30
    local by1 = town.y1 - radius  -- 30
    local bx2 = town.x2 + radius  -- 51
    local by2 = town.y2 + radius  -- 51

    -- 收集所有附属区域（如 trial_area），缓冲区不应覆盖这些区域的地板
    -- ⚠️ 新增 region 到 town.regions 时，此处会自动保护，无需额外修改
    local townZone = nil
    for _, zm in ipairs(activeZoneData.ALL_ZONES) do
        if zm.generation and zm.generation.special == "town" then
            townZone = zm
            break
        end
    end

    for y = by1, by2 do
        for x = bx1, bx2 do
            -- 跳过主城内部（保留城墙和地板）
            if x >= town.x1 and x <= town.x2 and y >= town.y1 and y <= town.y2 then
                goto continue
            end
            -- 跳过附属区域（如青云试炼区）
            if townZone then
                for regName, reg in pairs(townZone.regions) do
                    if regName ~= "town" and x >= reg.x1 and x <= reg.x2 and y >= reg.y1 and y <= reg.y2 then
                        goto continue
                    end
                end
            end
            local tile = self:GetTile(x, y)
            -- 保留道路，其他全部清为草地
            if tile ~= T.TOWN_ROAD then
                self:SetTile(x, y, T.GRASS)
            end
            ::continue::
        end
    end
end

--- 检测坐标是否在治愈之泉范围内
---@param x number
---@param y number
---@param range number 检测半径（瓦片）
---@return boolean
function GameMap:IsNearHealingSpring(x, y, range)
    local springs = self.healingSprings
    if not springs then return false end
    local rSq = range * range
    for _, s in ipairs(springs) do
        local dx = x - s.x
        local dy = y - s.y
        if dx * dx + dy * dy <= rSq then
            return true
        end
    end
    return false
end

--- 仙缘宝箱藏宝室：在生成管道最末尾手动放置 5×5 房间
--- 必须在 ClearTownBuffer 之后调用，保证不被任何前序步骤覆盖
--- 支持多章节：从 zone 配置读取 floorTile/wallTile，从 region 读取 entrance
function GameMap:BuildXianyuanRooms()
    -- 遍历 ALL_ZONES，找到所有含仙缘藏宝室 region 的 zone 模块
    for _, zm in ipairs(activeZoneData.ALL_ZONES) do
        if zm.regions and zm.regions.xianyuan_room_physique then
            local zmFloor = zm.floorTile or activeZoneData.TILE.CAVE_FLOOR
            local zmWall  = zm.wallTile  or activeZoneData.TILE.MOUNTAIN

            for regKey, region in pairs(zm.regions) do
                local entrance = region.entrance
                if not entrance then goto nextRoom end

                -- region 级瓦片优先（ch4 四龙岛各不相同），回退到 zone 模块级
                local floorTile = region.floorTile or zmFloor
                local wallTile  = region.wallTile  or zmWall

                -- 1. 整个 5×5 填充地板
                for y = region.y1, region.y2 do
                    for x = region.x1, region.x2 do
                        self:SetTile(x, y, floorTile)
                    end
                end

                -- 2. 外圈放墙（精确控制，不用 BuildThickBorder）
                for x = region.x1, region.x2 do
                    self:SetTile(x, region.y1, wallTile)
                    self:SetTile(x, region.y2, wallTile)
                end
                for y = region.y1, region.y2 do
                    self:SetTile(region.x1, y, wallTile)
                    self:SetTile(region.x2, y, wallTile)
                end

                -- 3. 入口处：1 格开口（精确 1 格，无 ±1 margin）
                local s = entrance.side
                local c = entrance.coord
                if s == "south" then
                    self:SetTile(c, region.y2, floorTile)
                elseif s == "north" then
                    self:SetTile(c, region.y1, floorTile)
                elseif s == "west" then
                    self:SetTile(region.x1, c, floorTile)
                elseif s == "east" then
                    self:SetTile(region.x2, c, floorTile)
                end

                ::nextRoom::
            end
        end
    end
end

end
