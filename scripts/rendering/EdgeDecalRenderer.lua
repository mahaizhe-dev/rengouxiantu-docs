-- ============================================================================
-- EdgeDecalRenderer.lua - 第五章边缘过渡 + 静态贴花渲染
-- 替代 WorldRenderer 中的 RenderZoneTransitions（仅 ch5+ 使用）
-- ============================================================================
-- 规格书 §6.3: 四类交界（地表-地表 / 地表-墙体 / 地表-断崖 / 地表-液面）
-- 规格书 §6.4: 8 种静态贴花（剑痕/裂纹/灰烬/血迹/烧痕/残剑/书页等）
-- 性能要求 §8.1: 变体在构建时确定（此处用确定性 hash 等效），无逐帧随机
-- ============================================================================

local ActiveZoneData = require("config.ActiveZoneData")
local RenderUtils = require("rendering.RenderUtils")

local EdgeDecalRenderer = {}

-- ============================================================================
-- 确定性伪随机（与 TileRenderer 完全相同的算法，保持一致性）
-- ============================================================================
local function tileHash(x, y, seed)
    local ix, iy = math.floor(x), math.floor(y)
    local h = (ix * 374761393 + iy * 668265263 + (seed or 0) * 1274126177) & 0x7FFFFFFF
    return h
end

local function tileRand(x, y, seed)
    return (tileHash(x, y, seed) % 10000) / 10000.0
end

local function tileRandInt(x, y, seed, lo, hi)
    return lo + (tileHash(x, y, seed) % (hi - lo + 1))
end

-- ============================================================================
-- 四方向 + 四对角邻居偏移（模块级常量）
-- ============================================================================
local CARDINAL = {
    { dx =  0, dy = -1, side = "top" },
    { dx =  0, dy =  1, side = "bottom" },
    { dx = -1, dy =  0, side = "left" },
    { dx =  1, dy =  0, side = "right" },
}

local DIAGONAL = {
    { dx = -1, dy = -1, corner = "tl" },
    { dx =  1, dy = -1, corner = "tr" },
    { dx = -1, dy =  1, corner = "bl" },
    { dx =  1, dy =  1, corner = "br" },
}

-- ============================================================================
-- 边缘分类：根据 EDGE_TYPES 判断邻居类型
-- ============================================================================
local function classifyTile(tileType, edgeTypes)
    if edgeTypes.wall[tileType]   then return "wall" end
    if edgeTypes.cliff[tileType]  then return "cliff" end
    if edgeTypes.void[tileType]   then return "void" end
    if edgeTypes.liquid[tileType] then return "liquid" end
    if edgeTypes.ground[tileType] then return "ground" end
    return "unknown"
end

-- ============================================================================
-- 边缘渲染核心
-- ============================================================================
--- 渲染增强边缘过渡（替代原 RenderZoneTransitions）
---@param nvg userdata NanoVG 上下文
---@param l table 布局 {x,y,w,h}
---@param camera table 相机对象
---@param gameMap table 地图对象
---@param startX number 可视范围起始 X
---@param startY number 可视范围起始 Y
---@param endX number 可视范围结束 X
---@param endY number 可视范围结束 Y
function EdgeDecalRenderer.RenderEdges(nvg, l, camera, gameMap, startX, startY, endX, endY)
    local zd = ActiveZoneData.Get()
    local edgeTypes = zd.EDGE_TYPES
    if not edgeTypes then return end

    local tileSize = camera:GetTileSize()
    local walkableTiles = zd.WALKABLE_TILES or {}
    local tileColors = zd.TILE_COLORS or {}
    local transitionColors = zd.TILE_TRANSITION_COLORS or {}

    for y = startY, endY do
        for x = startX, endX do
            local tileType = gameMap:GetTile(x, y)
            -- 只处理可通行地表格
            if not walkableTiles[tileType] then goto continue end

            local sx, sy = RenderUtils.WorldToLocal(x - 0.5, y - 0.5, camera, l)
            local myClass = classifyTile(tileType, edgeTypes)

            -- === 四方向主邻居检查 ===
            for _, n in ipairs(CARDINAL) do
                local nx, ny = x + n.dx, y + n.dy
                local neighborType = gameMap:GetTile(nx, ny)
                if neighborType == tileType then goto next_cardinal end

                local nClass = classifyTile(neighborType, edgeTypes)
                local fadeW = tileSize * 0.10

                if nClass == "wall" then
                    -- 地表对墙体：深色阴影边（墙体投影感）
                    nvgBeginPath(nvg)
                    if n.side == "top" then
                        nvgRect(nvg, sx, sy, tileSize, fadeW)
                    elseif n.side == "bottom" then
                        nvgRect(nvg, sx, sy + tileSize - fadeW, tileSize, fadeW)
                    elseif n.side == "left" then
                        nvgRect(nvg, sx, sy, fadeW, tileSize)
                    elseif n.side == "right" then
                        nvgRect(nvg, sx + tileSize - fadeW, sy, fadeW, tileSize)
                    end
                    nvgFillColor(nvg, nvgRGBA(20, 18, 15, 70))
                    nvgFill(nvg)

                elseif nClass == "cliff" or nClass == "void" then
                    -- 地表对断崖/虚空：锐利暗边 + 窄高光线
                    -- §6.3: cliff_edge→abyss_void 必须单独处理
                    local edgeW = tileSize * 0.10
                    local lineW = math.max(1, tileSize * 0.02)

                    -- 暗边
                    nvgBeginPath(nvg)
                    if n.side == "top" then
                        nvgRect(nvg, sx, sy, tileSize, edgeW)
                    elseif n.side == "bottom" then
                        nvgRect(nvg, sx, sy + tileSize - edgeW, tileSize, edgeW)
                    elseif n.side == "left" then
                        nvgRect(nvg, sx, sy, edgeW, tileSize)
                    elseif n.side == "right" then
                        nvgRect(nvg, sx + tileSize - edgeW, sy, edgeW, tileSize)
                    end
                    -- 虚空比断崖更暗
                    local alpha = (nClass == "void") and 120 or 80
                    nvgFillColor(nvg, nvgRGBA(8, 5, 12, alpha))
                    nvgFill(nvg)

                    -- 高光线（边缘裂开的光线感）
                    nvgBeginPath(nvg)
                    if n.side == "top" then
                        nvgRect(nvg, sx, sy, tileSize, lineW)
                    elseif n.side == "bottom" then
                        nvgRect(nvg, sx, sy + tileSize - lineW, tileSize, lineW)
                    elseif n.side == "left" then
                        nvgRect(nvg, sx, sy, lineW, tileSize)
                    elseif n.side == "right" then
                        nvgRect(nvg, sx + tileSize - lineW, sy, lineW, tileSize)
                    end
                    nvgFillColor(nvg, nvgRGBA(180, 170, 160, 50))
                    nvgFill(nvg)

                elseif nClass == "liquid" then
                    -- 地表对液面：蓝/绿色岸线渐变
                    local fadeW2 = tileSize * 0.10
                    nvgBeginPath(nvg)
                    if n.side == "top" then
                        nvgRect(nvg, sx, sy, tileSize, fadeW2)
                    elseif n.side == "bottom" then
                        nvgRect(nvg, sx, sy + tileSize - fadeW2, tileSize, fadeW2)
                    elseif n.side == "left" then
                        nvgRect(nvg, sx, sy, fadeW2, tileSize)
                    elseif n.side == "right" then
                        nvgRect(nvg, sx + tileSize - fadeW2, sy, fadeW2, tileSize)
                    end
                    nvgFillColor(nvg, nvgRGBA(50, 110, 160, 55))
                    nvgFill(nvg)

                elseif nClass == "ground" and walkableTiles[neighborType] then
                    -- 地表对地表：色彩过渡（继承原有逻辑）
                    local tc = transitionColors[neighborType]
                    if tc then
                        nvgBeginPath(nvg)
                        if n.side == "top" then
                            nvgRect(nvg, sx, sy, tileSize, fadeW)
                        elseif n.side == "bottom" then
                            nvgRect(nvg, sx, sy + tileSize - fadeW, tileSize, fadeW)
                        elseif n.side == "left" then
                            nvgRect(nvg, sx, sy, fadeW, tileSize)
                        elseif n.side == "right" then
                            nvgRect(nvg, sx + tileSize - fadeW, sy, fadeW, tileSize)
                        end
                        nvgFillColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 40))
                        nvgFill(nvg)
                    end
                end

                ::next_cardinal::
            end

            -- === 对角邻居检查（内角修正） ===
            for _, d in ipairs(DIAGONAL) do
                local diagType = gameMap:GetTile(x + d.dx, y + d.dy)
                if diagType == tileType then goto next_diag end

                -- 对角格是障碍但两个正交邻居都是本类型 → 内角阴影
                local adjH = gameMap:GetTile(x + d.dx, y)
                local adjV = gameMap:GetTile(x, y + d.dy)
                if adjH == tileType and adjV == tileType then
                    local dClass = classifyTile(diagType, edgeTypes)
                    if dClass == "wall" or dClass == "cliff" or dClass == "void" then
                        local cornerSize = tileSize * 0.10
                        local cx, cy
                        if d.corner == "tl" then
                            cx, cy = sx, sy
                        elseif d.corner == "tr" then
                            cx, cy = sx + tileSize - cornerSize, sy
                        elseif d.corner == "bl" then
                            cx, cy = sx, sy + tileSize - cornerSize
                        else -- br
                            cx, cy = sx + tileSize - cornerSize, sy + tileSize - cornerSize
                        end
                        local cAlpha = (dClass == "void") and 90 or 55
                        nvgBeginPath(nvg)
                        nvgRect(nvg, cx, cy, cornerSize, cornerSize)
                        nvgFillColor(nvg, nvgRGBA(10, 8, 12, cAlpha))
                        nvgFill(nvg)
                    end
                end

                ::next_diag::
            end

            ::continue::
        end
    end
end

-- ============================================================================
-- 贴花绘制函数（8 种）
-- 每个绘制函数接收 (nvg, cx, cy, size, seed) → 在 (cx,cy) 附近绘制一个贴花
-- ============================================================================

-- 1. 剑痕 - 斜线划痕
local function drawSwordMark(nvg, cx, cy, size, seed)
    local angle = tileRand(cx, cy, seed) * 3.14
    local halfLen = size * (0.2 + tileRand(cx, cy, seed + 1) * 0.15)
    local dx = math.cos(angle) * halfLen
    local dy = math.sin(angle) * halfLen
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - dx, cy - dy)
    nvgLineTo(nvg, cx + dx, cy + dy)
    nvgStrokeColor(nvg, nvgRGBA(60, 55, 50, 80))
    nvgStrokeWidth(nvg, math.max(1, size * 0.02))
    nvgStroke(nvg)
end

-- 2. 小裂纹 - 短折线
local function drawSmallCrack(nvg, cx, cy, size, seed)
    local r = tileRand(cx, cy, seed)
    local len = size * (0.08 + r * 0.1)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, cy)
    nvgLineTo(nvg, cx + len, cy - len * 0.6)
    nvgLineTo(nvg, cx + len * 1.5, cy + len * 0.3)
    nvgStrokeColor(nvg, nvgRGBA(40, 35, 30, 60))
    nvgStrokeWidth(nvg, math.max(1, size * 0.015))
    nvgStroke(nvg)
end

-- 3. 大裂纹 - 多段折线
local function drawLargeCrack(nvg, cx, cy, size, seed)
    local r = tileRand(cx, cy, seed)
    local seg = 3 + tileRandInt(cx, cy, seed + 2, 0, 2)
    nvgBeginPath(nvg)
    local px, py = cx, cy
    nvgMoveTo(nvg, px, py)
    for i = 1, seg do
        local dx = (tileRand(px, py, seed + i * 7) - 0.5) * size * 0.18
        local dy = (tileRand(py, px, seed + i * 13) - 0.5) * size * 0.18
        px = px + dx
        py = py + dy
        nvgLineTo(nvg, px, py)
    end
    nvgStrokeColor(nvg, nvgRGBA(35, 30, 28, 70))
    nvgStrokeWidth(nvg, math.max(1, size * 0.02))
    nvgStroke(nvg)
end

-- 4. 灰烬 - 半透明圆斑
local function drawAsh(nvg, cx, cy, size, seed)
    local radius = size * (0.04 + tileRand(cx, cy, seed) * 0.06)
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, radius)
    nvgFillColor(nvg, nvgRGBA(80, 75, 70, 40))
    nvgFill(nvg)
end

-- 5. 血迹 - 暗红色不规则斑
local function drawBlood(nvg, cx, cy, size, seed)
    local radius = size * (0.03 + tileRand(cx, cy, seed) * 0.05)
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy, radius * 1.3, radius * 0.8)
    nvgFillColor(nvg, nvgRGBA(100, 25, 20, 50))
    nvgFill(nvg)
end

-- 6. 烧痕 - 焦黑圆环
local function drawBurnMark(nvg, cx, cy, size, seed)
    local radius = size * (0.05 + tileRand(cx, cy, seed) * 0.05)
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, radius)
    nvgStrokeColor(nvg, nvgRGBA(30, 25, 20, 55))
    nvgStrokeWidth(nvg, math.max(1, size * 0.02))
    nvgStroke(nvg)
    -- 内部淡色
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, radius * 0.5)
    nvgFillColor(nvg, nvgRGBA(50, 40, 35, 30))
    nvgFill(nvg)
end

-- 7. 残剑 - 倾斜短粗线段 + 剑柄
local function drawBrokenSword(nvg, cx, cy, size, seed)
    local angle = tileRand(cx, cy, seed) * 3.14 * 2
    local bladeLen = size * (0.1 + tileRand(cx, cy, seed + 1) * 0.08)
    local dx = math.cos(angle) * bladeLen
    local dy = math.sin(angle) * bladeLen
    -- 剑身
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - dx * 0.3, cy - dy * 0.3)
    nvgLineTo(nvg, cx + dx, cy + dy)
    nvgStrokeColor(nvg, nvgRGBA(130, 130, 140, 70))
    nvgStrokeWidth(nvg, math.max(1, size * 0.025))
    nvgStroke(nvg)
    -- 剑柄（短粗横线）
    local hx = -dy * 0.15
    local hy = dx * 0.15
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - dx * 0.3 + hx, cy - dy * 0.3 + hy)
    nvgLineTo(nvg, cx - dx * 0.3 - hx, cy - dy * 0.3 - hy)
    nvgStrokeColor(nvg, nvgRGBA(90, 80, 70, 65))
    nvgStrokeWidth(nvg, math.max(1, size * 0.03))
    nvgStroke(nvg)
end

-- 8. 书页/玉简残片 - 小矩形
local function drawBookFragment(nvg, cx, cy, size, seed)
    local w = size * (0.06 + tileRand(cx, cy, seed) * 0.04)
    local h = w * (0.6 + tileRand(cx, cy, seed + 1) * 0.4)
    nvgSave(nvg)
    nvgTranslate(nvg, cx, cy)
    nvgRotate(nvg, tileRand(cx, cy, seed + 2) * 6.28)
    nvgBeginPath(nvg)
    nvgRect(nvg, -w * 0.5, -h * 0.5, w, h)
    local r = tileRandInt(cx, cy, seed + 3, 0, 1)
    if r == 0 then
        -- 书页：泛黄
        nvgFillColor(nvg, nvgRGBA(180, 165, 120, 50))
    else
        -- 玉简：淡绿
        nvgFillColor(nvg, nvgRGBA(140, 175, 150, 45))
    end
    nvgFill(nvg)
    nvgRestore(nvg)
end

-- 贴花绘制函数查找表
local DECAL_DRAWERS = {
    sword_mark     = drawSwordMark,
    small_crack    = drawSmallCrack,
    large_crack    = drawLargeCrack,
    ash            = drawAsh,
    blood          = drawBlood,
    burn_mark      = drawBurnMark,
    broken_sword   = drawBrokenSword,
    book_fragment  = drawBookFragment,
}

-- ============================================================================
-- 贴花渲染核心
-- ============================================================================
--- 渲染静态贴花层
---@param nvg userdata NanoVG 上下文
---@param l table 布局 {x,y,w,h}
---@param camera table 相机对象
---@param gameMap table 地图对象
---@param startX number 可视范围起始 X
---@param startY number 可视范围起始 Y
---@param endX number 可视范围结束 X
---@param endY number 可视范围结束 Y
function EdgeDecalRenderer.RenderDecals(nvg, l, camera, gameMap, startX, startY, endX, endY)
    local zd = ActiveZoneData.Get()
    local decalConfig = zd.DECAL_CONFIG
    if not decalConfig then return end

    local tileSize = camera:GetTileSize()

    for y = startY, endY do
        for x = startX, endX do
            local tileType = gameMap:GetTile(x, y)
            local cfg = decalConfig[tileType]
            if not cfg then goto continue end

            -- 确定性密度检查：此格是否放贴花
            local density = cfg.density or 0.15
            if tileRand(x, y, 9001) >= density then goto continue end

            local sx, sy = RenderUtils.WorldToLocal(x - 0.5, y - 0.5, camera, l)

            -- 选择贴花类型
            local types = cfg.types
            if not types or #types == 0 then goto continue end
            local typeIdx = tileRandInt(x, y, 9002, 1, #types)
            local decalType = types[typeIdx]

            local drawer = DECAL_DRAWERS[decalType]
            if not drawer then goto continue end

            -- 贴花位置偏移（瓦片内随机位置）
            local ox = tileRand(x, y, 9003) * 0.6 + 0.2  -- 0.2~0.8 范围
            local oy = tileRand(x, y, 9004) * 0.6 + 0.2
            local cx = sx + tileSize * ox
            local cy = sy + tileSize * oy

            drawer(nvg, cx, cy, tileSize, tileHash(x, y, 9005))

            -- 部分瓦片放第二个贴花（密度 > 0.5 时）
            if density > 0.5 and tileRand(x, y, 9006) < 0.4 then
                local typeIdx2 = tileRandInt(x, y, 9007, 1, #types)
                local decalType2 = types[typeIdx2]
                local drawer2 = DECAL_DRAWERS[decalType2]
                if drawer2 then
                    local ox2 = tileRand(x, y, 9008) * 0.5 + 0.25
                    local oy2 = tileRand(x, y, 9009) * 0.5 + 0.25
                    drawer2(nvg, sx + tileSize * ox2, sy + tileSize * oy2, tileSize, tileHash(x, y, 9010))
                end
            end

            ::continue::
        end
    end
end

return EdgeDecalRenderer
