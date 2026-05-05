-- ============================================================================
-- mapgen/Primitives.lua - 地形生成基础图元（填充、边界、道路）
-- ============================================================================

---@param GameMap table
---@param activeZoneData table
return function(GameMap, activeZoneData)

function GameMap:ApplyRegionFill(region, fillConfig, T)
    if fillConfig.scatter then
        -- 散布填充（如羊肠小径：草地基底 + 随机散布洞穴地砖）
        local scatterTile = T[fillConfig.scatter]
        local percent = fillConfig.scatterPercent or 15
        for y = region.y1, region.y2 do
            for x = region.x1, region.x2 do
                local hash = ((x * 374761393 + y * 668265263) & 0x7FFFFFFF) % 100
                if hash < percent then
                    self:SetTile(x, y, scatterTile)
                end
            end
        end
    else
        -- 整体填充
        self:FillRegion(region, T[fillConfig.tile])
    end
end

--- 填充矩形区域
---@param region table {x1, y1, x2, y2}
---@param tileType number
function GameMap:FillRegion(region, tileType)
    for y = region.y1, region.y2 do
        for x = region.x1, region.x2 do
            self:SetTile(x, y, tileType)
        end
    end
end

--- 绘制区域边界（确定性哈希，保证每次生成结果一致）
---@param region table
---@param tileType number
---@param chance number 0-1
function GameMap:DrawBorder(region, tileType, chance)
    -- 确定性哈希函数，基于坐标生成 0~1 伪随机值
    local function hash01(x, y)
        local h = ((x * 374761393 + y * 668265263 + region.x1 * 31 + region.y1 * 17) & 0x7FFFFFFF)
        return h / 0x7FFFFFFF
    end
    for x = region.x1, region.x2 do
        if hash01(x, region.y1) < chance then self:SetTile(x, region.y1, tileType) end
        if hash01(x, region.y2 + 10000) < chance then self:SetTile(x, region.y2, tileType) end
    end
    for y = region.y1, region.y2 do
        if hash01(region.x1 + 20000, y) < chance then self:SetTile(region.x1, y, tileType) end
        if hash01(region.x2 + 30000, y) < chance then self:SetTile(region.x2, y, tileType) end
    end
end

--- 平滑噪声插值（波长 wl，整数坐标 t，种子 seed）
---@param t number 整数坐标
---@param wl number 波长
---@param seed number 种子
---@return number 0~1 连续值
local function smoothNoise(t, wl, seed)
    local idx = math.floor(t / wl)
    local frac = (t % wl) / wl
    local function h(i)
        return ((i * 374761393 + seed * 668265263) & 0x7FFFFFFF) / 0x7FFFFFFF
    end
    local a, b = h(idx), h(idx + 1)
    -- 三次 Hermite 插值
    local s = frac * frac * (3 - 2 * frac)
    return a + (b - a) * s
end

--- 构建厚岩块边界（波浪版本：平滑噪声厚度 + 向外突起 + 角落横向延伸）
---@param region table {x1,y1,x2,y2}
---@param tileType number 边界瓦片类型
---@param minThick number 最小厚度
---@param maxThick number 最大厚度
---@param gaps table|nil 缺口列表
---@param openSides table|nil 开放边（不建墙的边，如 {"west","south"}）
function GameMap:BuildThickBorder(region, tileType, minThick, maxThick, gaps, openSides)
    gaps = gaps or {}

    -- 构建开放边查找表
    local openSet = {}
    if openSides then
        for _, s in ipairs(openSides) do openSet[s] = true end
    end

    -- 判断坐标是否在缺口内（含 ±1 安全边距）
    local function inGap(side, coord)
        for _, g in ipairs(gaps) do
            if g.side == side and coord >= g.from - 1 and coord <= g.to + 1 then
                return true
            end
        end
        return false
    end

    --- 处理一条边
    ---@param side string "north"|"south"|"west"|"east"
    local function processEdge(side)
        local isHoriz = (side == "north" or side == "south")
        local start, finish
        if isHoriz then
            start, finish = region.x1, region.x2
        else
            start, finish = region.y1, region.y2
        end

        local edgeLen = finish - start + 1
        local seed1 = region.x1 * 31 + region.y1 * 17  -- 厚度种子
        local seed2 = region.x2 * 53 + region.y2 * 79  -- 突起种子
        if side == "south" or side == "east" then
            seed1 = seed1 + 9999
            seed2 = seed2 + 7777
        end

        for coord = start, finish do
            if inGap(side, coord) then goto nextCoord end

            -- 平滑噪声决定厚度 [minThick, maxThick]
            local nv = smoothNoise(coord, 5, seed1)
            local thick = minThick + math.floor(nv * (maxThick - minThick + 0.99))

            -- 角落加厚：距边缘 ≤2 格取 maxThick
            local distFromStart = coord - start
            local distFromEnd = finish - coord
            if distFromStart <= 2 or distFromEnd <= 2 then
                thick = maxThick
            end

            -- 向外突起（0~1 格），平滑噪声控制
            local pv = smoothNoise(coord, 4, seed2)
            local protrude = 0
            if pv > 0.55 then protrude = 1 end
            if pv > 0.8 and maxThick >= 2 then protrude = 2 end

            -- 放置瓦片
            for d = -protrude, thick - 1 do
                local tx, ty
                if side == "north" then
                    tx, ty = coord, region.y1 + d   -- d<0 → 向外(上)
                elseif side == "south" then
                    tx, ty = coord, region.y2 - d   -- d<0 → 向外(下)
                elseif side == "west" then
                    tx, ty = region.x1 + d, coord   -- d<0 → 向外(左)
                else -- east
                    tx, ty = region.x2 - d, coord   -- d<0 → 向外(右)
                end
                self:SetTile(tx, ty, tileType)
            end

            ::nextCoord::
        end

        -- 角落横向延伸：在垂直邻边外侧补 1~2 格
        local cornerExtend = math.min(2, maxThick)
        for ext = 1, cornerExtend do
            if isHoriz then
                -- 左侧延伸
                local lx = region.x1 - ext
                local ly = (side == "north") and region.y1 or region.y2
                if not inGap(side, lx) then self:SetTile(lx, ly, tileType) end
                -- 右侧延伸
                local rx = region.x2 + ext
                if not inGap(side, rx) then self:SetTile(rx, ly, tileType) end
            else
                -- 上侧延伸
                local ty = region.y1 - ext
                local tx = (side == "west") and region.x1 or region.x2
                if not inGap(side, ty) then self:SetTile(tx, ty, tileType) end
                -- 下侧延伸
                local by = region.y2 + ext
                if not inGap(side, by) then self:SetTile(tx, by, tileType) end
            end
        end
    end

    if not openSet["north"] then processEdge("north") end
    if not openSet["south"] then processEdge("south") end
    if not openSet["west"]  then processEdge("west")  end
    if not openSet["east"]  then processEdge("east")  end
end

--- 绘制道路（确保连接区域间通路）
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param roadTile number
function GameMap:DrawRoad(x1, y1, x2, y2, roadTile)
    -- L 形道路：先水平再垂直
    local startX = math.min(x1, x2)
    local endX = math.max(x1, x2)
    local startY = math.min(y1, y2)
    local endY = math.max(y1, y2)

    -- 水平段
    for x = startX, endX do
        local tile = self:GetTile(x, y1)
        if tile == activeZoneData.TILE.WALL or tile == activeZoneData.TILE.MOUNTAIN then
            self:SetTile(x, y1, roadTile)
        end
    end
    -- 垂直段
    for y = startY, endY do
        local tile = self:GetTile(x2, y)
        if tile == activeZoneData.TILE.WALL or tile == activeZoneData.TILE.MOUNTAIN then
            self:SetTile(x2, y, roadTile)
        end
    end
end

end
