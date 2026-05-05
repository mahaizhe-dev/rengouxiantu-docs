-- ============================================================================
-- DecoTown.lua - 城镇装饰物渲染（从 DecorationRenderers 拆分）
-- 包含: House, Tree, Well, Lantern, Sign, FlowerBed, Barrel, Stall
-- ============================================================================

local T = require("config.UITheme")

local M = {}

-- ============================================================================
-- 模块级常量
-- ============================================================================

-- RenderHouse: 窗户位置
local HOUSE_WINDOW_POSITIONS = {{0.12, 0.38}, {0.7, 0.38}}

-- RenderFlowerBed: 花朵定义
local FLOWERBED_DEFS = {
    {x = 0.14, color = {255, 100, 120}, petals = 5},
    {x = 0.30, color = {255, 210, 80},  petals = 6},
    {x = 0.50, color = {200, 100, 255}, petals = 5},
    {x = 0.68, color = {100, 200, 255}, petals = 4},
    {x = 0.84, color = {255, 180, 200}, petals = 5},
}

-- RenderStall: 商品颜色
local STALL_ITEM_COLORS = {
    {200, 80, 80},   -- 红色药水
    {80, 180, 80},   -- 绿色药水
    {80, 120, 220},  -- 蓝色药水
}

-- 默认颜色常量
local DEFAULT_COLOR_HOUSE     = {140, 100, 60, 255}
local DEFAULT_COLOR_TREE      = {50, 130, 50, 255}

-- ============================================================================
-- 房屋（精细版）- 砖墙、瓦顶、烟囱、窗户光效
-- ============================================================================
function M.RenderHouse(nvg, sx, sy, ts, d, time)
    local w = (d.w or 2) * ts
    local h = (d.h or 2) * ts
    local c = d.color or DEFAULT_COLOR_HOUSE

    -- 投影
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + 4, sy + 4, w - 4, h - 4, 4)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
    nvgFill(nvg)

    -- 房屋主体（墙壁）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + 2, sy + h * 0.22, w - 4, h * 0.75, 2)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], c[4]))
    nvgFill(nvg)

    -- 墙壁砖纹（水平线）
    for row = 1, 4 do
        local ly = sy + h * 0.22 + row * (h * 0.75 / 5)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + 4, ly)
        nvgLineTo(nvg, sx + w - 4, ly)
        nvgStrokeColor(nvg, nvgRGBA(c[1] - 15, c[2] - 15, c[3] - 10, 50))
        nvgStrokeWidth(nvg, 0.5)
        nvgStroke(nvg)
    end

    -- 屋顶（三角形瓦片效果）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx - 3, sy + h * 0.25)
    nvgLineTo(nvg, sx + w / 2, sy - 2)
    nvgLineTo(nvg, sx + w + 3, sy + h * 0.25)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(130, 50, 30, 255))
    nvgFill(nvg)

    -- 屋顶瓦片纹
    for row = 0, 2 do
        local ry = sy + 2 + row * (h * 0.08)
        local roofWidth = w * (0.3 + row * 0.25)
        local roofX = sx + (w - roofWidth) / 2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, roofX, ry + h * 0.06)
        nvgLineTo(nvg, roofX + roofWidth, ry + h * 0.06)
        nvgStrokeColor(nvg, nvgRGBA(100, 35, 20, 80))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end

    -- 屋顶脊线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + w * 0.35, sy + h * 0.05)
    nvgLineTo(nvg, sx + w * 0.65, sy + h * 0.05)
    nvgStrokeColor(nvg, nvgRGBA(160, 70, 40, 255))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 烟囱
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + w * 0.72, sy - 2, w * 0.1, h * 0.15)
    nvgFillColor(nvg, nvgRGBA(100, 80, 70, 255))
    nvgFill(nvg)
    -- 烟雾（动态）
    local smokeAlpha = math.sin(time * 2) * 20 + 40
    for si = 0, 2 do
        local smokeY = sy - 4 - si * 5 - math.sin(time * 1.5 + si) * 2
        local smokeX = sx + w * 0.77 + math.sin(time + si * 1.5) * 2
        nvgBeginPath(nvg)
        nvgCircle(nvg, smokeX, smokeY, 2 + si * 0.8)
        nvgFillColor(nvg, nvgRGBA(180, 180, 180, math.max(0, math.floor(smokeAlpha - si * 12))))
        nvgFill(nvg)
    end

    -- 门（精细版）
    local doorX = sx + w * 0.38
    local doorY = sy + h * 0.58
    local doorW = w * 0.24
    local doorH = h * 0.38
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, doorX, doorY, doorW, doorH, 2)
    nvgFillColor(nvg, nvgRGBA(85, 55, 30, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(60, 40, 20, 255))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    -- 门把手
    nvgBeginPath(nvg)
    nvgCircle(nvg, doorX + doorW * 0.75, doorY + doorH * 0.5, 1.5)
    nvgFillColor(nvg, nvgRGBA(200, 180, 100, 255))
    nvgFill(nvg)
    -- 门框装饰
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, doorX + doorW * 0.5, doorY)
    nvgLineTo(nvg, doorX + doorW * 0.5, doorY + doorH)
    nvgStrokeColor(nvg, nvgRGBA(60, 40, 20, 100))
    nvgStrokeWidth(nvg, 0.5)
    nvgStroke(nvg)

    -- 窗户（带十字框和灯光）
    local windowGlow = math.sin(time * 0.5) * 0.1 + 0.9
    for _, wpos in ipairs(HOUSE_WINDOW_POSITIONS) do
        local wx = sx + w * wpos[1]
        local wy = sy + h * wpos[2]
        local ww = w * 0.18
        local wh = h * 0.16

        -- 窗户光（暖色）
        nvgBeginPath(nvg)
        nvgRect(nvg, wx, wy, ww, wh)
        nvgFillColor(nvg, nvgRGBA(255, 230, 150, math.floor(180 * windowGlow)))
        nvgFill(nvg)
        -- 窗框
        nvgStrokeColor(nvg, nvgRGBA(70, 50, 30, 255))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
        -- 十字窗棂
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, wx + ww * 0.5, wy)
        nvgLineTo(nvg, wx + ww * 0.5, wy + wh)
        nvgMoveTo(nvg, wx, wy + wh * 0.5)
        nvgLineTo(nvg, wx + ww, wy + wh * 0.5)
        nvgStrokeColor(nvg, nvgRGBA(70, 50, 30, 200))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- 建筑标签（招牌）
    if d.label then
        -- 招牌底板
        local signW = (utf8.len(d.label) or #d.label) * 12 + 16
        local signX = sx + w / 2 - signW / 2
        local signY = sy + h * 0.22 - 2
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, signX, signY, signW, 14, 2)
        nvgFillColor(nvg, nvgRGBA(60, 35, 15, 220))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(180, 140, 80, 200))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.label)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 230, 180, 255))
        nvgText(nvg, sx + w / 2, signY + 7, d.label, nil)
    end
end

-- ============================================================================
-- 树木（精细版）- 多层树冠、阴影、树干纹理
-- ============================================================================
function M.RenderTree(nvg, sx, sy, ts, d, time)
    local c = d.color or DEFAULT_COLOR_TREE

    -- 地面阴影（椭圆）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.88, ts * 0.35, ts * 0.1)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
    nvgFill(nvg)

    -- 树干（带纹理）
    local trunkX = sx + ts * 0.38
    local trunkY = sy + ts * 0.45
    local trunkW = ts * 0.24
    local trunkH = ts * 0.48
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, trunkX, trunkY, trunkW, trunkH, 3)
    nvgFillColor(nvg, nvgRGBA(90, 60, 30, 255))
    nvgFill(nvg)

    -- 树干纹理（年轮线）
    for i = 1, 3 do
        local ly = trunkY + i * (trunkH / 4)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, trunkX + 2, ly)
        nvgBezierTo(nvg, trunkX + trunkW * 0.3, ly - 1, trunkX + trunkW * 0.7, ly + 1, trunkX + trunkW - 2, ly)
        nvgStrokeColor(nvg, nvgRGBA(70, 45, 20, 80))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end

    -- 树干高光
    nvgBeginPath(nvg)
    nvgRect(nvg, trunkX + trunkW * 0.6, trunkY + 2, trunkW * 0.15, trunkH - 4)
    nvgFillColor(nvg, nvgRGBA(120, 85, 50, 50))
    nvgFill(nvg)

    -- 多层树冠
    local sway = math.sin(time * 1.2 + d.x * 3.7) * 1.0

    -- 底层树冠（最大，最暗）
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5 + sway * 0.3, sy + ts * 0.4, ts * 0.38)
    nvgFillColor(nvg, nvgRGBA(c[1] - 15, c[2] - 20, c[3] - 10, 255))
    nvgFill(nvg)

    -- 中层树冠
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.45 + sway * 0.5, sy + ts * 0.32, ts * 0.3)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 255))
    nvgFill(nvg)

    -- 顶层树冠（最小，最亮）
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.52 + sway * 0.7, sy + ts * 0.25, ts * 0.22)
    nvgFillColor(nvg, nvgRGBA(c[1] + 20, c[2] + 25, c[3] + 10, 255))
    nvgFill(nvg)

    -- 高光点
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.42 + sway * 0.5, sy + ts * 0.2, ts * 0.08)
    nvgFillColor(nvg, nvgRGBA(c[1] + 50, c[2] + 50, c[3] + 20, 80))
    nvgFill(nvg)
end

-- ============================================================================
-- 水井（精细版）- 石砌、绞盘、水面反光
-- ============================================================================
function M.RenderWell(nvg, sx, sy, ts, d, time)
    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.85, ts * 0.4, ts * 0.1)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
    nvgFill(nvg)

    -- 井台（石砌圆形）
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.5, ts * 0.38)
    nvgFillColor(nvg, nvgRGBA(130, 130, 135, 255))
    nvgFill(nvg)

    -- 石块纹理（外圈）
    for i = 0, 7 do
        local angle = i * math.pi * 0.25
        local bx = sx + ts * 0.5 + math.cos(angle) * ts * 0.3
        local by = sy + ts * 0.5 + math.sin(angle) * ts * 0.3
        nvgBeginPath(nvg)
        nvgCircle(nvg, bx, by, 4)
        nvgFillColor(nvg, nvgRGBA(110, 115, 120, 200))
        nvgFill(nvg)
    end

    -- 井台边缘
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.5, ts * 0.38)
    nvgStrokeColor(nvg, nvgRGBA(100, 100, 105, 255))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 内壁
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.5, ts * 0.25)
    nvgFillColor(nvg, nvgRGBA(60, 60, 65, 255))
    nvgFill(nvg)

    -- 水面（动态反光）
    local waterGlint = math.sin(time * 2.5) * 0.3 + 0.7
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.5, ts * 0.2)
    nvgFillColor(nvg, nvgRGBA(30, 60, 100, math.floor(200 * waterGlint)))
    nvgFill(nvg)

    -- 水面高光
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.45, sy + ts * 0.45, 3, 1.5)
    nvgFillColor(nvg, nvgRGBA(200, 220, 255, math.floor(120 * waterGlint)))
    nvgFill(nvg)

    -- 绞盘支架
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.35, sy + ts * 0.15, 2, ts * 0.3)
    nvgFillColor(nvg, nvgRGBA(80, 55, 30, 255))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.63, sy + ts * 0.15, 2, ts * 0.3)
    nvgFillColor(nvg, nvgRGBA(80, 55, 30, 255))
    nvgFill(nvg)
    -- 横梁
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.34, sy + ts * 0.15, ts * 0.32, 2)
    nvgFillColor(nvg, nvgRGBA(90, 60, 35, 255))
    nvgFill(nvg)
end

-- ============================================================================
-- 灯笼（精细版）- 中式灯笼、光晕、飘带
-- ============================================================================
function M.RenderLantern(nvg, sx, sy, ts, d, time)
    local flicker = math.sin(time * 3 + d.x * 7) * 0.15 + 0.85
    local glow = math.floor(220 * flicker)
    local sway = math.sin(time * 1.8 + d.x * 5) * 1.0

    -- 灯柱（带底座）
    -- 底座
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.32, sy + ts * 0.82, ts * 0.36, ts * 0.1, 2)
    nvgFillColor(nvg, nvgRGBA(70, 50, 30, 255))
    nvgFill(nvg)
    -- 柱身
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.44, sy + ts * 0.25, ts * 0.12, ts * 0.58)
    nvgFillColor(nvg, nvgRGBA(85, 60, 35, 255))
    nvgFill(nvg)
    -- 柱身高光
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.52, sy + ts * 0.28, ts * 0.03, ts * 0.5)
    nvgFillColor(nvg, nvgRGBA(110, 80, 50, 60))
    nvgFill(nvg)

    -- 外层光晕（大范围）
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5 + sway, sy + ts * 0.2, ts * 0.45)
    nvgFillColor(nvg, nvgRGBA(255, 200, 80, math.floor(25 * flicker)))
    nvgFill(nvg)

    -- 灯笼体（红色，带纹理）
    local lanternX = sx + ts * 0.28 + sway
    local lanternY = sy + ts * 0.05
    local lanternW = ts * 0.44
    local lanternH = ts * 0.3
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, lanternX, lanternY, lanternW, lanternH, 6)
    nvgFillColor(nvg, nvgRGBA(220, 50, 30, glow))
    nvgFill(nvg)
    -- 灯笼边框
    nvgStrokeColor(nvg, nvgRGBA(180, 140, 60, 200))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- 灯笼横纹
    for ri = 1, 2 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lanternX + 2, lanternY + ri * lanternH / 3)
        nvgLineTo(nvg, lanternX + lanternW - 2, lanternY + ri * lanternH / 3)
        nvgStrokeColor(nvg, nvgRGBA(200, 160, 60, 100))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end

    -- 上下金属扣
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, lanternX + lanternW * 0.2, lanternY - 2, lanternW * 0.6, 3, 1)
    nvgFillColor(nvg, nvgRGBA(200, 170, 80, 255))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, lanternX + lanternW * 0.25, lanternY + lanternH, lanternW * 0.5, 3, 1)
    nvgFillColor(nvg, nvgRGBA(200, 170, 80, 255))
    nvgFill(nvg)

    -- 底部飘带
    local tassLen = 6
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, lanternX + lanternW * 0.4, lanternY + lanternH + 3)
    nvgLineTo(nvg, lanternX + lanternW * 0.4 + sway * 0.5, lanternY + lanternH + 3 + tassLen)
    nvgStrokeColor(nvg, nvgRGBA(220, 50, 30, 180))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, lanternX + lanternW * 0.6, lanternY + lanternH + 3)
    nvgLineTo(nvg, lanternX + lanternW * 0.6 + sway * 0.5, lanternY + lanternH + 3 + tassLen)
    nvgStrokeColor(nvg, nvgRGBA(220, 50, 30, 180))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 灯光内部发光
    nvgBeginPath(nvg)
    nvgCircle(nvg, lanternX + lanternW * 0.5, lanternY + lanternH * 0.5, lanternW * 0.2)
    nvgFillColor(nvg, nvgRGBA(255, 230, 150, math.floor(80 * flicker)))
    nvgFill(nvg)
end

-- ============================================================================
-- 告示牌（精细版）
-- ============================================================================
function M.RenderSign(nvg, sx, sy, ts, d)
    -- 支撑柱（两根）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.3, sy + ts * 0.45, 3, ts * 0.45)
    nvgFillColor(nvg, nvgRGBA(90, 60, 30, 255))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.67, sy + ts * 0.45, 3, ts * 0.45)
    nvgFillColor(nvg, nvgRGBA(90, 60, 30, 255))
    nvgFill(nvg)

    -- 牌面
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.12, sy + ts * 0.12, ts * 0.76, ts * 0.38, 3)
    nvgFillColor(nvg, nvgRGBA(190, 160, 110, 255))
    nvgFill(nvg)

    -- 边框装饰
    nvgStrokeColor(nvg, nvgRGBA(110, 80, 40, 255))
    nvgStrokeWidth(nvg, 1.8)
    nvgStroke(nvg)

    -- 木纹
    for i = 1, 3 do
        local ly = sy + ts * 0.15 + i * ts * 0.08
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + ts * 0.15, ly)
        nvgLineTo(nvg, sx + ts * 0.85, ly)
        nvgStrokeColor(nvg, nvgRGBA(150, 120, 80, 40))
        nvgStrokeWidth(nvg, 0.5)
        nvgStroke(nvg)
    end

    -- 文字
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.label)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(50, 30, 10, 255))
        nvgText(nvg, sx + ts * 0.5, sy + ts * 0.31, d.label, nil)
    end
end

-- ============================================================================
-- 花坛（精细版）- 多种花型、蝴蝶
-- ============================================================================
function M.RenderFlowerBed(nvg, sx, sy, ts, d, time)
    -- 花坛底座（泥土）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.08, sy + ts * 0.48, ts * 0.84, ts * 0.4, 4)
    nvgFillColor(nvg, nvgRGBA(110, 80, 45, 255))
    nvgFill(nvg)
    -- 泥土边框
    nvgStrokeColor(nvg, nvgRGBA(80, 55, 30, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 花朵（5 株，多种样式）
    for fi, fd in ipairs(FLOWERBED_DEFS) do
        local fx = sx + ts * fd.x
        local stemSway = math.sin(time * 1.5 + fi * 1.3) * 1.0

        -- 茎
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, fx, sy + ts * 0.48)
        nvgBezierTo(nvg, fx + stemSway, sy + ts * 0.4, fx + stemSway * 0.5, sy + ts * 0.35, fx + stemSway, sy + ts * 0.3)
        nvgStrokeColor(nvg, nvgRGBA(50, 120, 35, 255))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 叶子（左侧一片小叶）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, fx - 3 + stemSway * 0.3, sy + ts * 0.4, 3, 1.5)
        nvgFillColor(nvg, nvgRGBA(60, 130, 40, 200))
        nvgFill(nvg)

        -- 花瓣
        local fc = fd.color
        local flowerCx = fx + stemSway
        local flowerCy = sy + ts * 0.28
        local petalR = ts * 0.05

        for p = 1, fd.petals do
            local angle = (p / fd.petals) * math.pi * 2
            local px = flowerCx + math.cos(angle) * petalR * 1.2
            local py = flowerCy + math.sin(angle) * petalR * 1.2
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, petalR)
            nvgFillColor(nvg, nvgRGBA(fc[1], fc[2], fc[3], 230))
            nvgFill(nvg)
        end

        -- 花蕊
        nvgBeginPath(nvg)
        nvgCircle(nvg, flowerCx, flowerCy, petalR * 0.6)
        nvgFillColor(nvg, nvgRGBA(255, 230, 100, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 木桶（精细版）- 木板纹理、铁箍、盖子
-- ============================================================================
function M.RenderBarrel(nvg, sx, sy, ts, d)
    -- 投影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.52, sy + ts * 0.88, ts * 0.3, ts * 0.08)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
    nvgFill(nvg)

    -- 桶身
    local bx = sx + ts * 0.2
    local by = sy + ts * 0.18
    local bw = ts * 0.6
    local bh = ts * 0.68
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, bw, bh, 5)
    nvgFillColor(nvg, nvgRGBA(140, 95, 50, 255))
    nvgFill(nvg)

    -- 木板纹理（竖线）
    for i = 1, 4 do
        local lx = bx + i * (bw / 5)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx, by + 3)
        nvgLineTo(nvg, lx, by + bh - 3)
        nvgStrokeColor(nvg, nvgRGBA(110, 70, 35, 60))
        nvgStrokeWidth(nvg, 0.5)
        nvgStroke(nvg)
    end

    -- 铁箍（3 条）
    for i = 1, 3 do
        local hy = by + i * (bh / 4)
        nvgBeginPath(nvg)
        nvgRect(nvg, bx - 1, hy - 2, bw + 2, 3)
        nvgFillColor(nvg, nvgRGBA(75, 75, 80, 220))
        nvgFill(nvg)
        -- 铆钉
        nvgBeginPath(nvg)
        nvgCircle(nvg, bx + 2, hy - 0.5, 1.2)
        nvgFillColor(nvg, nvgRGBA(120, 120, 130, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, bx + bw - 2, hy - 0.5, 1.2)
        nvgFillColor(nvg, nvgRGBA(120, 120, 130, 255))
        nvgFill(nvg)
    end

    -- 桶盖（椭圆顶）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, bx + bw * 0.5, by, bw * 0.5, 4)
    nvgFillColor(nvg, nvgRGBA(155, 110, 60, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(100, 70, 35, 150))
    nvgStrokeWidth(nvg, 0.8)
    nvgStroke(nvg)

    -- 高光
    nvgBeginPath(nvg)
    nvgRect(nvg, bx + bw * 0.65, by + 5, bw * 0.1, bh * 0.6)
    nvgFillColor(nvg, nvgRGBA(170, 125, 70, 50))
    nvgFill(nvg)
end

-- ============================================================================
-- 摊位（精细版）- 条纹棚顶、商品、价签
-- ============================================================================
function M.RenderStall(nvg, sx, sy, ts, d)
    -- 支撑柱（两根）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.08, sy + ts * 0.28, 3, ts * 0.6)
    nvgFillColor(nvg, nvgRGBA(100, 70, 40, 255))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.88, sy + ts * 0.28, 3, ts * 0.6)
    nvgFillColor(nvg, nvgRGBA(100, 70, 40, 255))
    nvgFill(nvg)

    -- 台面
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.06, sy + ts * 0.45, ts * 0.88, ts * 0.45, 3)
    nvgFillColor(nvg, nvgRGBA(165, 135, 95, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(120, 90, 55, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 商品（小方块）
    for i = 1, 3 do
        local ic = STALL_ITEM_COLORS[i]
        local ix = sx + ts * (0.18 + (i - 1) * 0.25)
        local iy = sy + ts * 0.52
        -- 瓶子
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, ix, iy, ts * 0.12, ts * 0.16, 2)
        nvgFillColor(nvg, nvgRGBA(ic[1], ic[2], ic[3], 200))
        nvgFill(nvg)
        -- 瓶口
        nvgBeginPath(nvg)
        nvgRect(nvg, ix + ts * 0.03, iy - 2, ts * 0.06, 3)
        nvgFillColor(nvg, nvgRGBA(ic[1] + 30, ic[2] + 30, ic[3] + 30, 200))
        nvgFill(nvg)
    end

    -- 棚顶（条纹布）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.02, sy + ts * 0.03, ts * 0.96, ts * 0.28, 3)
    nvgFillColor(nvg, nvgRGBA(180, 55, 35, 240))
    nvgFill(nvg)

    -- 条纹
    local stripeW = ts * 0.96 / 6
    for i = 0, 5 do
        if i % 2 == 0 then
            nvgBeginPath(nvg)
            nvgRect(nvg, sx + ts * 0.02 + i * stripeW, sy + ts * 0.03, stripeW, ts * 0.28)
            nvgFillColor(nvg, nvgRGBA(220, 200, 170, 80))
            nvgFill(nvg)
        end
    end

    -- 棚顶边缘波浪
    nvgBeginPath(nvg)
    for i = 0, 6 do
        local wx = sx + ts * 0.02 + i * stripeW
        local wy = sy + ts * 0.31
        if i == 0 then
            nvgMoveTo(nvg, wx, wy)
        else
            nvgLineTo(nvg, wx - stripeW * 0.5, wy + 3)
            nvgLineTo(nvg, wx, wy)
        end
    end
    nvgStrokeColor(nvg, nvgRGBA(180, 55, 35, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.label)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 240, 200, 255))
        nvgText(nvg, sx + ts * 0.5, sy + ts * 0.17, d.label, nil)
    end
end

return M
