-- ============================================================================
-- DecoCh5.lua - 第五章装饰物渲染（太虚遗址主题）
-- 包含: ruined_pillar, anvil, ice_shard, toppled_stele, burning_shelf
-- ============================================================================

local M = {}

-- ============================================================================
-- 1. 残柱 ruined_pillar - 断裂的青石立柱，上截面斜切
-- 适用区域: sword_plaza, broken_gate, sword_palace
-- ============================================================================
function M.RenderRuinedPillar(nvg, sx, sy, ts, d, time)
    local w = (d.w or 1) * ts
    local h = (d.h or 1) * ts

    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + w * 0.5, sy + h * 0.9, w * 0.3, h * 0.06)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 35))
    nvgFill(nvg)

    -- 柱身（青灰色矩形，微圆角）
    local pillarW = w * 0.4
    local pillarH = h * 0.65
    local px = sx + (w - pillarW) / 2
    local py = sy + h * 0.2
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, px, py, pillarW, pillarH, 2)
    nvgFillColor(nvg, nvgRGBA(140, 145, 150, 255))
    nvgFill(nvg)

    -- 柱面竖向纹路
    for i = 1, 3 do
        local lx = px + pillarW * (i / 4)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx, py + 3)
        nvgLineTo(nvg, lx, py + pillarH - 3)
        nvgStrokeColor(nvg, nvgRGBA(120, 125, 130, 80))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end

    -- 断裂截面（斜切三角形，颜色更浅）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, px - 1, py)
    nvgLineTo(nvg, px + pillarW + 1, py)
    nvgLineTo(nvg, px + pillarW * 0.7, py - h * 0.08)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(160, 165, 170, 255))
    nvgFill(nvg)

    -- 底座（宽方块）
    nvgBeginPath(nvg)
    nvgRect(nvg, px - w * 0.06, py + pillarH, pillarW + w * 0.12, h * 0.1)
    nvgFillColor(nvg, nvgRGBA(120, 125, 130, 255))
    nvgFill(nvg)

    -- 柱身裂缝
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, px + pillarW * 0.3, py + pillarH * 0.35)
    nvgLineTo(nvg, px + pillarW * 0.5, py + pillarH * 0.5)
    nvgLineTo(nvg, px + pillarW * 0.35, py + pillarH * 0.7)
    nvgStrokeColor(nvg, nvgRGBA(80, 85, 90, 120))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)
end

-- ============================================================================
-- 2. 铁砧 anvil - 锻造用铁砧，深灰色块+锤击面
-- 适用区域: forge
-- ============================================================================
function M.RenderAnvil(nvg, sx, sy, ts, d, time)
    local w = (d.w or 1) * ts
    local h = (d.h or 1) * ts

    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + w * 0.5, sy + h * 0.88, w * 0.32, h * 0.06)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
    nvgFill(nvg)

    -- 底座梯形
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + w * 0.25, sy + h * 0.85)
    nvgLineTo(nvg, sx + w * 0.75, sy + h * 0.85)
    nvgLineTo(nvg, sx + w * 0.7, sy + h * 0.55)
    nvgLineTo(nvg, sx + w * 0.3, sy + h * 0.55)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(60, 60, 65, 255))
    nvgFill(nvg)

    -- 砧面（上部宽台）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + w * 0.15, sy + h * 0.4, w * 0.7, h * 0.18, 2)
    nvgFillColor(nvg, nvgRGBA(80, 80, 85, 255))
    nvgFill(nvg)

    -- 砧面高光
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + w * 0.2, sy + h * 0.42, w * 0.3, h * 0.04)
    nvgFillColor(nvg, nvgRGBA(110, 110, 115, 120))
    nvgFill(nvg)

    -- 锤击痕迹（小凹坑）
    for i = 1, 4 do
        local cx = sx + w * (0.25 + i * 0.1)
        local cy = sy + h * 0.48
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, 1.2)
        nvgFillColor(nvg, nvgRGBA(50, 50, 55, 100))
        nvgFill(nvg)
    end

    -- 尖角（左侧牛角形突出）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + w * 0.15, sy + h * 0.45)
    nvgLineTo(nvg, sx + w * 0.05, sy + h * 0.38)
    nvgLineTo(nvg, sx + w * 0.15, sy + h * 0.52)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(70, 70, 75, 255))
    nvgFill(nvg)

    -- 火星动画（偶尔闪现）
    local spark = math.sin(time * 4.0 + (d.x or 0) * 7.3)
    if spark > 0.7 then
        local sparkAlpha = math.floor((spark - 0.7) / 0.3 * 200)
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx + w * 0.45, sy + h * 0.38, 1.5)
        nvgFillColor(nvg, nvgRGBA(255, 180, 50, sparkAlpha))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 4. 冰棱 ice_shard - 竖立的半透明冰晶柱
-- 适用区域: cold_pool
-- ============================================================================
function M.RenderIceShard(nvg, sx, sy, ts, d, time)
    local w = (d.w or 1) * ts
    local h = (d.h or 1) * ts

    -- 地面冰渍
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + w * 0.5, sy + h * 0.88, w * 0.25, h * 0.06)
    nvgFillColor(nvg, nvgRGBA(160, 200, 230, 50))
    nvgFill(nvg)

    -- 主冰晶（三角形尖柱）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + w * 0.5, sy + h * 0.08)
    nvgLineTo(nvg, sx + w * 0.65, sy + h * 0.85)
    nvgLineTo(nvg, sx + w * 0.35, sy + h * 0.85)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(170, 210, 240, 180))
    nvgFill(nvg)

    -- 冰面高光棱线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + w * 0.5, sy + h * 0.12)
    nvgLineTo(nvg, sx + w * 0.55, sy + h * 0.82)
    nvgStrokeColor(nvg, nvgRGBA(220, 240, 255, 150))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- 副冰晶（较小，左侧偏）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + w * 0.3, sy + h * 0.3)
    nvgLineTo(nvg, sx + w * 0.38, sy + h * 0.85)
    nvgLineTo(nvg, sx + w * 0.22, sy + h * 0.85)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(180, 215, 245, 140))
    nvgFill(nvg)

    -- 闪光动画
    local flash = math.sin(time * 2.0 + (d.x or 0) * 5.1) * 0.5 + 0.5
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + w * 0.48, sy + h * 0.25, 1.5 + flash * 1.0)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(60 + flash * 80)))
    nvgFill(nvg)
end

-- ============================================================================
-- 6. 倒碑 toppled_stele - 横倒的石碑（碑文碎块）
-- 适用区域: stele_forest
-- ============================================================================
function M.RenderToppledStele(nvg, sx, sy, ts, d, time)
    local w = (d.w or 2) * ts
    local h = (d.h or 1) * ts

    -- 倒地阴影
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + w * 0.05 + 2, sy + h * 0.42 + 2, w * 0.85, h * 0.38, 2)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
    nvgFill(nvg)

    -- 石碑主体（横长方形）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + w * 0.05, sy + h * 0.4, w * 0.85, h * 0.38, 2)
    nvgFillColor(nvg, nvgRGBA(150, 155, 145, 255))
    nvgFill(nvg)

    -- 碑面纹饰（模拟碑文横线）
    for i = 1, 5 do
        local ly = sy + h * 0.44 + i * (h * 0.3 / 6)
        local lx1 = sx + w * 0.12
        local lx2 = sx + w * (0.5 + i * 0.06)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx1, ly)
        nvgLineTo(nvg, lx2, ly)
        nvgStrokeColor(nvg, nvgRGBA(100, 105, 95, 100))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end

    -- 断裂碎块（右端脱落的小块）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + w * 0.88, sy + h * 0.4)
    nvgLineTo(nvg, sx + w * 0.95, sy + h * 0.45)
    nvgLineTo(nvg, sx + w * 0.92, sy + h * 0.55)
    nvgLineTo(nvg, sx + w * 0.85, sy + h * 0.5)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(140, 145, 135, 255))
    nvgFill(nvg)

    -- 苔藓点缀
    for i = 1, 3 do
        local mx = sx + w * (0.15 + i * 0.2)
        local my = sy + h * 0.72
        nvgBeginPath(nvg)
        nvgCircle(nvg, mx, my, 2.0)
        nvgFillColor(nvg, nvgRGBA(60, 100, 50, 80))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 7. 燃书架 burning_shelf - 半焚毁的木质书架，残火余烟
-- 适用区域: library
-- ============================================================================
function M.RenderBurningShelf(nvg, sx, sy, ts, d, time)
    local w = (d.w or 1) * ts
    local h = (d.h or 2) * ts

    -- 阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + w * 0.5, sy + h * 0.92, w * 0.35, h * 0.04)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 35))
    nvgFill(nvg)

    -- 书架框体（焦化深褐色）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + w * 0.12, sy + h * 0.1, w * 0.76, h * 0.78, 2)
    nvgFillColor(nvg, nvgRGBA(60, 40, 25, 255))
    nvgFill(nvg)

    -- 隔层横板（3 层）
    for i = 1, 3 do
        local ly = sy + h * (0.1 + i * 0.19)
        nvgBeginPath(nvg)
        nvgRect(nvg, sx + w * 0.12, ly, w * 0.76, h * 0.025)
        nvgFillColor(nvg, nvgRGBA(50, 32, 18, 255))
        nvgFill(nvg)
    end

    -- 残存书本（每层几本）
    local bookColors = {
        {120, 30, 30}, {30, 60, 100}, {80, 70, 30},
        {40, 80, 50}, {90, 40, 70}, {100, 80, 20},
    }
    for layer = 0, 2 do
        local layerY = sy + h * (0.13 + layer * 0.19)
        local booksInLayer = 2 + layer  -- 底层多一些
        for b = 1, booksInLayer do
            local ci = ((layer * 3 + b) % #bookColors) + 1
            local bc = bookColors[ci]
            local bx = sx + w * (0.15 + (b - 1) * 0.14)
            nvgBeginPath(nvg)
            nvgRect(nvg, bx, layerY, w * 0.08, h * 0.16)
            nvgFillColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], 200))
            nvgFill(nvg)
        end
    end

    -- 焦痕（上半部分变深）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + w * 0.12, sy + h * 0.1, w * 0.76, h * 0.3)
    nvgFillColor(nvg, nvgRGBA(20, 15, 10, 120))
    nvgFill(nvg)

    -- 残火（顶部微弱火苗动画）
    local firePhase = time * 3.0 + (d.x or 0) * 2.7
    for fi = 1, 2 do
        local fx = sx + w * (0.3 + fi * 0.15)
        local fy = sy + h * 0.08 - math.abs(math.sin(firePhase + fi * 1.2)) * h * 0.05
        local fAlpha = math.floor(120 + math.sin(firePhase + fi) * 60)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, fx, fy + h * 0.06)
        nvgQuadTo(nvg, fx - w * 0.03, fy, fx, fy - h * 0.04)
        nvgQuadTo(nvg, fx + w * 0.03, fy, fx, fy + h * 0.06)
        nvgFillColor(nvg, nvgRGBA(255, 120, 30, fAlpha))
        nvgFill(nvg)
    end

    -- 烟尘
    local smokeA = math.floor(30 + math.sin(time * 1.2) * 15)
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + w * 0.5 + math.sin(time * 0.7) * 3, sy + h * 0.02, 3)
    nvgFillColor(nvg, nvgRGBA(100, 100, 100, smokeA))
    nvgFill(nvg)
end

return M
