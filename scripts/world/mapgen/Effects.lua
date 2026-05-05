-- ============================================================================
-- mapgen/Effects.lua - 地形效果（边缘侵蚀）
-- ============================================================================

local function smoothNoise(t, wl, seed)
    local idx = math.floor(t / wl)
    local frac = (t % wl) / wl
    local function h(i)
        return ((i * 374761393 + seed * 668265263) & 0x7FFFFFFF) / 0x7FFFFFFF
    end
    local a, b = h(idx), h(idx + 1)
    local s = frac * frac * (3 - 2 * frac)
    return a + (b - a) * s
end

---@param GameMap table
---@param activeZoneData table
return function(GameMap, activeZoneData)

function GameMap:ErodeRegionEdge(region, side, maxDepth, seed)
    local T = activeZoneData.TILE
    local isHoriz = (side == "north" or side == "south")
    local start, finish
    if isHoriz then
        start, finish = region.x1 + 2, region.x2 - 2  -- 留出角落
    else
        start, finish = region.y1 + 2, region.y2 - 2
    end

    for coord = start, finish do
        -- 平滑噪声决定侵蚀深度 [0, maxDepth]
        local nv = smoothNoise(coord, 4, seed)
        local depth = math.floor(nv * (maxDepth + 0.99))
        if depth < 1 then goto nextErode end

        -- 角落侵蚀更深（距边缘 3~5 格内额外 +1）
        local distFromStart = coord - start
        local distFromEnd = finish - coord
        if distFromStart <= 4 or distFromEnd <= 4 then
            depth = math.min(depth + 1, maxDepth + 1)
        end

        for d = 0, depth - 1 do
            local tx, ty
            if side == "north" then
                tx, ty = coord, region.y1 + d
            elseif side == "south" then
                tx, ty = coord, region.y2 - d
            elseif side == "west" then
                tx, ty = region.x1 + d, coord
            else
                tx, ty = region.x2 - d, coord
            end
            -- 只侵蚀区域自身的地板瓦片（不动 GRASS/WALL/MOUNTAIN 等）
            local tile = self:GetTile(tx, ty)
            if tile ~= T.GRASS and tile ~= T.WALL and tile ~= T.MOUNTAIN
                and tile ~= T.WATER and tile ~= T.TOWN_FLOOR and tile ~= T.TOWN_ROAD then
                self:SetTile(tx, ty, T.GRASS)
            end
        end
        ::nextErode::
    end
end

--- 对所有需要侵蚀的区域执行边缘侵蚀（数据驱动）
function GameMap:ErodeZoneEdges()
    local sides = { "north", "south", "west", "east" }

    for _, zoneModule in ipairs(activeZoneData.ALL_ZONES) do
        local gen = zoneModule.generation
        if not gen then goto nextErosion end

        if gen.subRegions then
            -- 多子区域：逐个检查 erosion 配置
            for _, sub in ipairs(gen.subRegions) do
                if sub.erosion then
                    local region = zoneModule.regions[sub.regionKey]
                    if region then
                        for _, side in ipairs(sides) do
                            if not (sub.erosion.protect and sub.erosion.protect[side]) then
                                local seed = region.x1 * 13 + region.y1 * 37 + #side * 59
                                self:ErodeRegionEdge(region, side, sub.erosion.maxDepth, seed)
                            end
                        end
                    end
                end
            end
        elseif gen.erosion then
            -- 单区域
            for _, region in pairs(zoneModule.regions) do
                for _, side in ipairs(sides) do
                    if not (gen.erosion.protect and gen.erosion.protect[side]) then
                        local seed = region.x1 * 13 + region.y1 * 37 + #side * 59
                        self:ErodeRegionEdge(region, side, gen.erosion.maxDepth, seed)
                    end
                end
            end
        end
        ::nextErosion::
    end
end

end
