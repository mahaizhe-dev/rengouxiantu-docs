-- ============================================================================
-- tiles/yaochi.lua - 瑶池与第五章特殊地形瓦片渲染
-- 包含: Water, YaochiCliff, SteleIntact, SteleBroken, BloodPool, Furnace, LavaWall
-- ============================================================================
local ActiveZoneData = require("config.ActiveZoneData")
local GameState      = require("core.GameState")
local UITheme        = require("config.UITheme")
local Shared = require("rendering.tiles.shared")

local tileHash    = Shared.tileHash
local tileRand    = Shared.tileRand
local tileRandInt = Shared.tileRandInt
local RenderFlat  = Shared.RenderFlat
local GetFlatColors = Shared.GetFlatColors

local M = {}

-- Image handles
local waterImage              = -1
local waterImageLoaded        = false
local yaochiCliffImage        = -1
local yaochiCliffImageLoaded  = false
local steleIntactImage        = -1
local steleIntactImageLoaded  = false
local steleBrokenImage        = -1
local steleBrokenImageLoaded  = false
local bloodPoolImage          = -1
local bloodPoolImageLoaded    = false
local furnaceImage            = -1
local furnaceImageLoaded      = false
local lavaImage               = -1
local lavaImageLoaded         = false

-- ============================================================================
-- 水面 (WATER) - PNG 水纹 + 波光高光
-- ============================================================================
local function EnsureWaterImage(nvg)
    if waterImageLoaded then return end
    waterImageLoaded = true
    waterImage = nvgCreateImage(nvg, "Textures/tile_water_yaochi.png", 0)
    if waterImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load water image, fallback to flat color")
    else
        print("[TileRenderer] Water image loaded: " .. waterImage)
    end
end

function M.RenderWater(nvg, sx, sy, ts, x, y)
    EnsureWaterImage(nvg)

    -- ① 底色：深蓝
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(40, 90, 150, 255))
    nvgFill(nvg)

    -- ② PNG 纹理叠加
    if waterImage > 0 then
        local hash = tileHash(x, y, 700) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.08)
        local offsetY = (hash >= 2) and 0 or (ts * 0.08)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, waterImage, 0.75)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end

    -- ③ 对角高光（水面波光）
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx + ts, sy + ts,
        nvgRGBA(120, 200, 255, 30), nvgRGBA(120, 200, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- 瑶池崖壁 (YAOCHI_CLIFF) - PNG 岩石 + 立体厚度
-- ============================================================================
local function EnsureYaochiCliffImage(nvg)
    if yaochiCliffImageLoaded then return end
    yaochiCliffImageLoaded = true
    yaochiCliffImage = nvgCreateImage(nvg, "Textures/tile_cliff_yaochi.png", 0)
    if yaochiCliffImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load yaochi cliff image, fallback to procedural")
    else
        print("[TileRenderer] Yaochi cliff image loaded: " .. yaochiCliffImage)
    end
end

function M.RenderYaochiCliff(nvg, sx, sy, ts, x, y)
    EnsureYaochiCliffImage(nvg)

    -- ① 底色：深灰褐岩石
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(70, 60, 50, 255))
    nvgFill(nvg)

    -- ② PNG 纹理叠加
    if yaochiCliffImage > 0 then
        local hash = tileHash(x, y, 800) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.1)
        local offsetY = (hash >= 2) and 0 or (ts * 0.1)
        local scale = ts / (128 - offsetX * 2)
        local imgSize = 128 * scale
        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, yaochiCliffImage, 0.9)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        -- 无贴图回退：程序化岩石纹理
        for i = 1, 5 do
            local rx = sx + tileRand(x, y, 800 + i) * ts * 0.8 + ts * 0.1
            local ry = sy + tileRand(x, y, 810 + i) * ts * 0.8 + ts * 0.1
            local rr = 1.5 + tileRand(x, y, 820 + i) * 2.5
            local bv = tileRandInt(x, y, 830 + i, -12, 12)
            nvgBeginPath(nvg)
            nvgCircle(nvg, rx, ry, rr)
            nvgFillColor(nvg, nvgRGBA(80 + bv, 70 + bv, 60 + bv, 60))
            nvgFill(nvg)
        end
    end

    -- ③ 顶部高光（崖顶受光）
    local hlH = math.max(2, ts * 0.1)
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx, sy + hlH,
        nvgRGBA(160, 150, 130, 80), nvgRGBA(160, 150, 130, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, hlH)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)

    -- ④ 底部阴影（崖底）
    local shH = math.max(3, ts * 0.15)
    local shPaint = nvgLinearGradient(nvg, sx, sy + ts - shH, sx, sy + ts,
        nvgRGBA(20, 15, 10, 0), nvgRGBA(20, 15, 10, 140))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts - shH, ts, shH)
    nvgFillPaint(nvg, shPaint)
    nvgFill(nvg)

    -- ⑤ 竖向裂缝纹理（~30%概率）
    if tileRand(x, y, 850) < 0.3 then
        local cx = sx + tileRand(x, y, 851) * ts * 0.6 + ts * 0.2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, sy + ts * 0.1)
        nvgLineTo(nvg, cx + ts * 0.05, sy + ts * 0.5)
        nvgLineTo(nvg, cx - ts * 0.03, sy + ts * 0.85)
        nvgStrokeColor(nvg, nvgRGBA(40, 35, 25, 60))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 完整石碑 (CH5_STELE_INTACT) - 使用 PNG 图片
-- ============================================================================
local function EnsureSteleIntactImage(nvg)
    if steleIntactImageLoaded then return end
    steleIntactImageLoaded = true
    steleIntactImage = nvgCreateImage(nvg, "image/tile_stele_intact_20260515023819.png", 0)
    if steleIntactImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load stele intact image, fallback to flat color")
    else
        print("[TileRenderer] Stele intact image loaded: " .. steleIntactImage)
    end
end

function M.RenderSteleIntact(nvg, sx, sy, ts, x, y, gameMap)
    EnsureSteleIntactImage(nvg)

    if steleIntactImage > 0 then
        -- 3x3大碑：判断当前格在3x3中的位置
        local T = ActiveZoneData.Get().TILE
        local isLeftEdge = true
        local isTopEdge = true
        if gameMap and gameMap.GetTile then
            if x > 1 and gameMap:GetTile(x - 1, y) == T.CH5_STELE_INTACT then
                isLeftEdge = false
            end
            if y > 1 and gameMap:GetTile(x, y - 1) == T.CH5_STELE_INTACT then
                isTopEdge = false
            end
        end

        if isLeftEdge and isTopEdge then
            -- 左上角格：先画底色，再绘制3x3大碑图片
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, ts, ts)
            nvgFillColor(nvg, nvgRGBA(175, 170, 160, 255))
            nvgFill(nvg)

            local bigSize = ts * 3
            local paint = nvgImagePattern(nvg,
                sx, sy, bigSize, bigSize, 0, steleIntactImage, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, bigSize, bigSize)
            nvgFillPaint(nvg, paint)
            nvgFill(nvg)
        end
        -- 非左上角格：什么都不画（让左上角画的大图透出来）
    else
        -- fallback 纯色
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(175, 170, 160, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 断壁残碑 (CH5_STELE_BROKEN) - 使用 PNG 图片
-- ============================================================================
local function EnsureSteleBrokenImage(nvg)
    if steleBrokenImageLoaded then return end
    steleBrokenImageLoaded = true
    steleBrokenImage = nvgCreateImage(nvg, "image/tile_stele_broken_20260515023821.png", 0)
    if steleBrokenImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load stele broken image, fallback to flat color")
    else
        print("[TileRenderer] Stele broken image loaded: " .. steleBrokenImage)
    end
end

function M.RenderSteleBroken(nvg, sx, sy, ts, x, y)
    EnsureSteleBrokenImage(nvg)

    if steleBrokenImage > 0 then
        -- 底色（碑林苍白石）
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(175, 170, 160, 255))
        nvgFill(nvg)

        -- 图片填充
        local hash = tileHash(x, y, 80) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.08)
        local offsetY = (hash >= 2) and 0 or (ts * 0.08)
        local scale = ts / (256 - offsetX * 2)
        local imgSize = 256 * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize, 0, steleBrokenImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        local colors = GetFlatColors()
        RenderFlat(nvg, sx, sy, ts, x, y, colors[80])
    end
end

-- ============================================================================
-- 祀剑池 (CH5_BLOOD_POOL) - 3×2 PNG 图片
-- ============================================================================
local function EnsureBloodPoolImage(nvg)
    if bloodPoolImageLoaded then return end
    bloodPoolImageLoaded = true
    bloodPoolImage = nvgCreateImage(nvg, "image/blood_pool_3x2_20260515065827.png", 0)
    if bloodPoolImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load blood pool image, fallback to flat color")
    else
        print("[TileRenderer] Blood pool image loaded: " .. bloodPoolImage)
    end
end

function M.RenderBloodPool(nvg, sx, sy, ts, x, y, gameMap)
    EnsureBloodPoolImage(nvg)

    if bloodPoolImage > 0 then
        local T = ActiveZoneData.Get().TILE
        local isLeftEdge = true
        local isTopEdge = true
        if gameMap and gameMap.GetTile then
            if x > 1 and gameMap:GetTile(x - 1, y) == T.CH5_BLOOD_POOL then
                isLeftEdge = false
            end
            if y > 1 and gameMap:GetTile(x, y - 1) == T.CH5_BLOOD_POOL then
                isTopEdge = false
            end
        end

        if isLeftEdge and isTopEdge then
            -- 左上角格：先画底色，再绘制 3×2 大图
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, ts, ts)
            nvgFillColor(nvg, nvgRGBA(120, 35, 30, 255))
            nvgFill(nvg)

            local bigW = ts * 3
            local bigH = ts * 2
            local paint = nvgImagePattern(nvg,
                sx, sy, bigW, bigH, 0, bloodPoolImage, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, bigW, bigH)
            nvgFillPaint(nvg, paint)
            nvgFill(nvg)

            -- ── 传送阵式能量波纹特效 ──
            local t = GameState.gameTime or 0
            local cx = sx + bigW * 0.5
            local cy = sy + bigH * 0.5
            local maxR = math.min(bigW, bigH) * 0.45

            nvgSave(nvg)
            nvgIntersectScissor(nvg, sx, sy, bigW, bigH)

            -- 3 层同心扩散环，不同相位
            for i = 0, 2 do
                local phase = (t * 0.6 + i * 0.333) % 1.0   -- 0→1 循环
                local r = maxR * (0.2 + phase * 0.8)
                local alpha = math.floor(55 * (1.0 - phase))  -- 由浓到淡
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, r)
                nvgStrokeColor(nvg, nvgRGBA(180, 50, 60, alpha))
                nvgStrokeWidth(nvg, ts * 0.04)
                nvgStroke(nvg)
            end

            -- 中心稳定光晕（呼吸感）
            local breathAlpha = math.floor(30 + 20 * math.sin(t * 2.5))
            local glowR = maxR * 0.35
            local glowPaint = nvgRadialGradient(nvg,
                cx, cy, glowR * 0.1, glowR,
                nvgRGBA(200, 60, 80, breathAlpha),
                nvgRGBA(200, 60, 80, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, glowR)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)

            nvgRestore(nvg)

            -- ── 名牌："祀剑池"（标题+副标题，与通用NPC一致） ──
            local titleText = "祀剑池"
            local subText   = "四仙剑共鸣"
            local nameFontSize = UITheme.worldFont.name
            local subFontSize  = UITheme.worldFont.subtitle
            local titleX = sx + bigW * 0.5
            local padH, padV = 8, 4

            nvgFontFace(nvg, "sans")

            -- 测量文字宽度
            nvgFontSize(nvg, nameFontSize)
            local nameTextW = nvgTextBounds(nvg, 0, 0, titleText, nil)
            nvgFontSize(nvg, subFontSize)
            local subTextW = nvgTextBounds(nvg, 0, 0, subText, nil)

            -- 背景板尺寸
            local contentW = math.max(nameTextW, subTextW)
            local bgW = contentW + padH * 2
            local nameLineH = nameFontSize + padV
            local subLineH  = subFontSize + padV
            local bgH = nameLineH + subLineH + padV * 2
            local bgTopY = sy - ts * 0.1 - bgH

            -- 暗底背景板
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, titleX - bgW / 2, bgTopY, bgW, bgH, 5)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
            nvgFill(nvg)

            -- 标题（金色，与通用NPC一致）
            local nameCenterY = bgTopY + padV + nameLineH / 2
            nvgFontSize(nvg, nameFontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
            nvgText(nvg, titleX, nameCenterY, titleText, nil)

            -- 副标题（淡灰色，与通用NPC一致）
            local subCenterY = nameCenterY + nameLineH / 2 + subLineH / 2
            nvgFontSize(nvg, subFontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(200, 200, 180, 200))
            nvgText(nvg, titleX, subCenterY, subText, nil)
        end
        -- 非左上角格：不画，让大图透出
    else
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(100, 25, 25, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 铸剑地炉 (CH5_FURNACE) - 3×3 PNG 图片
-- ============================================================================
local function EnsureFurnaceImage(nvg)
    if furnaceImageLoaded then return end
    furnaceImageLoaded = true
    furnaceImage = nvgCreateImage(nvg, "image/furnace_3x3_20260515085411.png", 0)
    if furnaceImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load furnace image, fallback to flat color")
    else
        print("[TileRenderer] Furnace image loaded: " .. furnaceImage)
    end
end

function M.RenderFurnace(nvg, sx, sy, ts, x, y, gameMap)
    EnsureFurnaceImage(nvg)

    if furnaceImage > 0 then
        local T = ActiveZoneData.Get().TILE
        local isLeftEdge = true
        local isTopEdge = true
        if gameMap and gameMap.GetTile then
            if x > 1 and gameMap:GetTile(x - 1, y) == T.CH5_FURNACE then
                isLeftEdge = false
            end
            if y > 1 and gameMap:GetTile(x, y - 1) == T.CH5_FURNACE then
                isTopEdge = false
            end
        end

        if isLeftEdge and isTopEdge then
            -- 左上角格：先画底色，再绘制 3×3 大图
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, ts, ts)
            nvgFillColor(nvg, nvgRGBA(45, 40, 38, 255))
            nvgFill(nvg)

            local bigSize = ts * 3
            local paint = nvgImagePattern(nvg,
                sx, sy, bigSize, bigSize, 0, furnaceImage, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, bigSize, bigSize)
            nvgFillPaint(nvg, paint)
            nvgFill(nvg)

            -- ── 名牌："铸剑地炉"（标题+副标题，与通用NPC一致） ──
            local titleText = "铸剑地炉"
            local subText   = "太虚锻造坊"
            local nameFontSize = UITheme.worldFont.name
            local subFontSize  = UITheme.worldFont.subtitle
            local titleX = sx + bigSize * 0.5
            local padH, padV = 8, 4

            nvgFontFace(nvg, "sans")

            -- 测量文字宽度
            nvgFontSize(nvg, nameFontSize)
            local nameTextW = nvgTextBounds(nvg, 0, 0, titleText, nil)
            nvgFontSize(nvg, subFontSize)
            local subTextW = nvgTextBounds(nvg, 0, 0, subText, nil)

            -- 背景板尺寸
            local contentW = math.max(nameTextW, subTextW)
            local bgW = contentW + padH * 2
            local nameLineH = nameFontSize + padV
            local subLineH  = subFontSize + padV
            local bgH = nameLineH + subLineH + padV * 2
            local bgTopY = sy - ts * 0.1 - bgH

            -- 暗底背景板
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, titleX - bgW / 2, bgTopY, bgW, bgH, 5)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
            nvgFill(nvg)

            -- 标题（金色，与通用NPC一致）
            local nameCenterY = bgTopY + padV + nameLineH / 2
            nvgFontSize(nvg, nameFontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
            nvgText(nvg, titleX, nameCenterY, titleText, nil)

            -- 副标题（淡灰色，与通用NPC一致）
            local subCenterY = nameCenterY + nameLineH / 2 + subLineH / 2
            nvgFontSize(nvg, subFontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(200, 200, 180, 200))
            nvgText(nvg, titleX, subCenterY, subText, nil)
        end
        -- 非左上角格：不画，让大图透出
    else
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(60, 45, 30, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 岩浆墙 (CH5_LAVA_WALL) - 单格 PNG 贴图
-- ============================================================================
local function EnsureLavaImage(nvg)
    if lavaImageLoaded then return end
    lavaImageLoaded = true
    lavaImage = nvgCreateImage(nvg, "image/lava_tile_20260515054323.png", 0)
    if lavaImage <= 0 then
        print("[TileRenderer] WARNING: Failed to load lava image, fallback to flat color")
    else
        print("[TileRenderer] Lava image loaded: " .. lavaImage)
    end
end

function M.RenderLavaWall(nvg, sx, sy, ts, x, y)
    EnsureLavaImage(nvg)

    -- 底色（加载失败时也可用）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(180, 60, 15, 255))
    nvgFill(nvg)

    if lavaImage > 0 then
        -- 通过坐标 hash 做微小偏移，避免所有格完全一样
        local hash = tileHash(x, y, 77) % 4
        local offsetX = ((hash % 2) == 0) and 0 or (ts * 0.08)
        local offsetY = (hash >= 2) and 0 or (ts * 0.08)
        local imgSrc = 64  -- PNG 原始尺寸
        local scale = ts / (imgSrc - offsetX * 2)
        local imgSize = imgSrc * scale

        local paint = nvgImagePattern(nvg,
            sx - offsetX * scale, sy - offsetY * scale,
            imgSize, imgSize,
            0, lavaImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end
end

return M
