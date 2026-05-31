-- tiles/ch5_ground.lua - 第五章地面瓦片（程序化纹理）
local shared = require("rendering.tiles.shared")
local M = {}

local tileHash = shared.tileHash
local tileRand = shared.tileRand
local tileRandInt = shared.tileRandInt

-- ============================================================================
-- CH5 前营黄土地 (CH5_CAMP_DIRT) - 暗黄褐泥土 + 碎石
-- ============================================================================
function M.RenderCh5CampDirt(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗黄褐泥土
    local bv = ((x + y) % 2 == 0) and 6 or -4
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(130 + bv, 105 + bv, 70 + bv, 255))
    nvgFill(nvg)

    -- ② 泥土色斑（2~3 个不规则深色斑块）
    local numPatches = 2 + tileHash(x, y, 1000) % 2
    for i = 1, numPatches do
        local px = sx + tileRand(x, y, 1001 + i * 3) * ts * 0.6 + ts * 0.2
        local py = sy + tileRand(x, y, 1002 + i * 3) * ts * 0.6 + ts * 0.2
        local pr = ts * (0.1 + tileRand(x, y, 1003 + i * 3) * 0.12)
        nvgBeginPath(nvg)
        nvgEllipse(nvg, px, py, pr, pr * 0.8)
        nvgFillColor(nvg, nvgRGBA(110, 85, 55, 60))
        nvgFill(nvg)
    end

    -- ③ 碎石颗粒（~25% 概率，1~2 颗）
    if tileRand(x, y, 1010) < 0.25 then
        local cnt = 1 + tileHash(x, y, 1011) % 2
        for i = 1, cnt do
            local gx = sx + tileRand(x, y, 1012 + i) * ts * 0.7 + ts * 0.15
            local gy = sy + tileRand(x, y, 1013 + i) * ts * 0.7 + ts * 0.15
            local gr = 1.0 + tileRand(x, y, 1014 + i) * 1.5
            local gv = tileRandInt(x, y, 1015 + i, -10, 10)
            nvgBeginPath(nvg)
            nvgCircle(nvg, gx, gy, gr)
            nvgFillColor(nvg, nvgRGBA(100 + gv, 90 + gv, 65 + gv, 160))
            nvgFill(nvg)
        end
    end

    -- ④ 微弱脚印痕迹（~10% 概率）
    if tileRand(x, y, 1020) < 0.10 then
        local fx = sx + tileRand(x, y, 1021) * ts * 0.5 + ts * 0.25
        local fy = sy + tileRand(x, y, 1022) * ts * 0.5 + ts * 0.25
        nvgBeginPath(nvg)
        nvgEllipse(nvg, fx, fy, 2.0, 1.2)
        nvgFillColor(nvg, nvgRGBA(95, 75, 50, 50))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 前营修补石板 (CH5_CAMP_FLAGSTONE) - 石板拼接（参考 TownFloor）
-- ============================================================================
function M.RenderCh5CampFlagstone(nvg, sx, sy, ts, x, y)
    -- ① 底色：灰褐石板基底
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(140, 125, 105, 255))
    nvgFill(nvg)

    -- ② 2x2 石板拼接（交错排列）
    local halfW = ts / 2
    local halfH = ts / 2
    local offsetX = (y % 2 == 0) and (halfW * 0.5) or 0
    for bx = 0, 1 do
        for by = 0, 1 do
            local bsx = sx + bx * halfW + offsetX
            local bsy = sy + by * halfH
            local sv = tileRandInt(x, y, bx * 2 + by + 1050, -10, 10)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bsx + 1, bsy + 1, halfW - 2, halfH - 2, 1.0)
            nvgFillColor(nvg, nvgRGBA(135 + sv, 120 + sv, 100 + sv, 255))
            nvgFill(nvg)
            -- 接缝
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bsx + 1, bsy + 1, halfW - 2, halfH - 2, 1.0)
            nvgStrokeColor(nvg, nvgRGBA(90, 80, 65, 100))
            nvgStrokeWidth(nvg, 0.7)
            nvgStroke(nvg)
        end
    end

    -- ③ 修补痕迹裂缝（~20% 概率）
    if tileRand(x, y, 1060) < 0.20 then
        local cx = sx + tileRand(x, y, 1061) * ts * 0.6 + ts * 0.2
        local cy = sy + tileRand(x, y, 1062) * ts * 0.6 + ts * 0.2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy)
        nvgLineTo(nvg, cx + 5, cy + 4)
        nvgLineTo(nvg, cx + 3, cy + 8)
        nvgStrokeColor(nvg, nvgRGBA(80, 65, 50, 80))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- CH5 废墟青石 (CH5_RUIN_BLUESTONE) - 青色石板 + 苔痕
-- ============================================================================
function M.RenderCh5RuinBluestone(nvg, sx, sy, ts, x, y)
    -- ① 底色：青灰石
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(120 + bv, 135 + bv, 140 + bv, 255))
    nvgFill(nvg)

    -- ② 石板纹理线（横向 + 纵向淡线条）
    local lineY1 = sy + ts * (0.3 + tileRand(x, y, 1100) * 0.1)
    local lineY2 = sy + ts * (0.65 + tileRand(x, y, 1101) * 0.1)
    nvgStrokeColor(nvg, nvgRGBA(95, 110, 115, 60))
    nvgStrokeWidth(nvg, 0.6)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, lineY1)
    nvgLineTo(nvg, sx + ts, lineY1)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, lineY2)
    nvgLineTo(nvg, sx + ts, lineY2)
    nvgStroke(nvg)

    -- ③ 苔痕斑块（~20% 概率，1~2个绿色半透明斑）
    if tileRand(x, y, 1110) < 0.20 then
        local cnt = 1 + tileHash(x, y, 1111) % 2
        for i = 1, cnt do
            local mx = sx + tileRand(x, y, 1112 + i * 2) * ts * 0.6 + ts * 0.2
            local my = sy + tileRand(x, y, 1113 + i * 2) * ts * 0.6 + ts * 0.2
            local mr = 2.0 + tileRand(x, y, 1114 + i) * 2.5
            nvgBeginPath(nvg)
            nvgEllipse(nvg, mx, my, mr, mr * 0.7)
            nvgFillColor(nvg, nvgRGBA(60, 100, 55, 50))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- CH5 废墟裂石 (CH5_RUIN_CRACKED) - 裂纹石面 + 碎屑
-- ============================================================================
function M.RenderCh5RuinCracked(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗灰石
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(105 + bv, 100 + bv, 95 + bv, 255))
    nvgFill(nvg)

    -- ② 主裂纹（每格 1~2 条）
    local numCracks = 1 + tileHash(x, y, 1150) % 2
    for i = 1, numCracks do
        local cx1 = sx + tileRand(x, y, 1151 + i * 4) * ts * 0.3 + ts * 0.1
        local cy1 = sy + tileRand(x, y, 1152 + i * 4) * ts * 0.3 + ts * 0.1
        local cx2 = sx + tileRand(x, y, 1153 + i * 4) * ts * 0.3 + ts * 0.55
        local cy2 = sy + tileRand(x, y, 1154 + i * 4) * ts * 0.3 + ts * 0.55
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(55, 50, 45, 140))
        nvgStrokeWidth(nvg, 1.0 + tileRand(x, y, 1155 + i) * 0.8)
        nvgStroke(nvg)
    end

    -- ③ 碎石屑散落（~15% 概率）
    if tileRand(x, y, 1160) < 0.15 then
        for i = 1, 2 do
            local dx = sx + tileRand(x, y, 1161 + i) * ts * 0.8 + ts * 0.1
            local dy = sy + tileRand(x, y, 1162 + i) * ts * 0.8 + ts * 0.1
            local dr = 0.8 + tileRand(x, y, 1163 + i) * 1.0
            nvgBeginPath(nvg)
            nvgCircle(nvg, dx, dy, dr)
            nvgFillColor(nvg, nvgRGBA(85, 80, 75, 100))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- CH5 铸剑焦黑石 (CH5_FORGE_BLACKSTONE) - 暗黑石面 + 锈色斑
-- ============================================================================
function M.RenderCh5ForgeBlackstone(nvg, sx, sy, ts, x, y)
    -- ① 底色：极暗灰黑
    local bv = ((x + y) % 2 == 0) and 4 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(45 + bv, 40 + bv, 38 + bv, 255))
    nvgFill(nvg)

    -- ② 锈色斑点（2~3 个）
    local numSpots = 2 + tileHash(x, y, 1200) % 2
    for i = 1, numSpots do
        local rx = sx + tileRand(x, y, 1201 + i * 3) * ts * 0.7 + ts * 0.15
        local ry = sy + tileRand(x, y, 1202 + i * 3) * ts * 0.7 + ts * 0.15
        local rr = 1.5 + tileRand(x, y, 1203 + i * 3) * 2.0
        nvgBeginPath(nvg)
        nvgEllipse(nvg, rx, ry, rr, rr * 0.7)
        nvgFillColor(nvg, nvgRGBA(100, 55, 25, 45))
        nvgFill(nvg)
    end

    -- ③ 焦痕斑块（~15% 概率，填充椭圆替代线条）
    if tileRand(x, y, 1210) < 0.15 then
        local fx = sx + tileRand(x, y, 1211) * ts * 0.5 + ts * 0.25
        local fy = sy + tileRand(x, y, 1212) * ts * 0.5 + ts * 0.25
        local fr = 1.5 + tileRand(x, y, 1213) * 2.0
        nvgBeginPath(nvg)
        nvgEllipse(nvg, fx, fy, fr, fr * 0.6)
        nvgFillColor(nvg, nvgRGBA(30, 20, 15, 60))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 熔裂纹地面 (CH5_FORGE_MOLTEN) - 暗石 + 橙色熔纹线
-- ============================================================================
function M.RenderCh5ForgeMolten(nvg, sx, sy, ts, x, y)
    -- ① 底色：深灰黑（类似锻造石）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(40, 35, 32, 255))
    nvgFill(nvg)

    -- ② 棋盘格微调
    if (x + y) % 2 == 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 6))
        nvgFill(nvg)
    end

    -- ③ 熔岩光斑（1~2 个发光椭圆，替代线条）
    local numSpots = 1 + tileHash(x, y, 1250) % 2
    for i = 1, numSpots do
        local cx = sx + tileRand(x, y, 1251 + i * 5) * ts * 0.6 + ts * 0.2
        local cy = sy + tileRand(x, y, 1252 + i * 5) * ts * 0.6 + ts * 0.2
        local cr = 2.0 + tileRand(x, y, 1253 + i * 5) * 2.5
        -- 发光外晕（宽、低透明）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, cr * 1.8, cr * 1.2)
        nvgFillColor(nvg, nvgRGBA(255, 120, 20, 25))
        nvgFill(nvg)
        -- 亮芯（窄、高亮）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, cr * 0.7, cr * 0.5)
        nvgFillColor(nvg, nvgRGBA(255, 180, 60, 80))
        nvgFill(nvg)
    end

    -- ④ 余温微光点（~10% 概率）
    if tileRand(x, y, 1260) < 0.10 then
        local ex = sx + tileRand(x, y, 1261) * ts * 0.7 + ts * 0.15
        local ey = sy + tileRand(x, y, 1262) * ts * 0.7 + ts * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, ex, ey, 1.5 + tileRand(x, y, 1263) * 1.5)
        nvgFillColor(nvg, nvgRGBA(255, 140, 30, 30))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 苔藓院石 (CH5_COURTYARD_MOSS) - 灰石板 + 绿苔斑
-- ============================================================================
function M.RenderCh5CourtyardMoss(nvg, sx, sy, ts, x, y)
    -- ① 底色：灰石
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(130 + bv, 130 + bv, 120 + bv, 255))
    nvgFill(nvg)

    -- ② 石板接缝（十字形）
    local midX = sx + ts * (0.45 + tileRand(x, y, 1300) * 0.1)
    local midY = sy + ts * (0.45 + tileRand(x, y, 1301) * 0.1)
    nvgStrokeColor(nvg, nvgRGBA(100, 100, 90, 60))
    nvgStrokeWidth(nvg, 0.6)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, midX, sy)
    nvgLineTo(nvg, midX, sy + ts)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, midY)
    nvgLineTo(nvg, sx + ts, midY)
    nvgStroke(nvg)

    -- ③ 苔藓斑块（~30% 概率，2~3个绿斑）
    if tileRand(x, y, 1310) < 0.30 then
        local cnt = 2 + tileHash(x, y, 1311) % 2
        for i = 1, cnt do
            local mx = sx + tileRand(x, y, 1312 + i * 2) * ts * 0.7 + ts * 0.15
            local my = sy + tileRand(x, y, 1313 + i * 2) * ts * 0.7 + ts * 0.15
            local mr = 2.0 + tileRand(x, y, 1314 + i) * 3.0
            nvgBeginPath(nvg)
            nvgEllipse(nvg, mx, my, mr, mr * 0.6)
            nvgFillColor(nvg, nvgRGBA(50, 90, 40, 55))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- CH5 寒池玉石地 (CH5_COLD_JADE) - 冰蓝玉石 + 六角霜花
-- ============================================================================
function M.RenderCh5ColdJade(nvg, sx, sy, ts, x, y)
    -- ① 底色：冰蓝玉石
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(160 + bv, 200 + bv, 215 + bv, 255))
    nvgFill(nvg)

    -- ② 玉石内纹理（淡色条纹）
    local lineAng = tileRand(x, y, 1350) * math.pi * 0.5
    local dx = math.cos(lineAng) * ts * 0.4
    local dy = math.sin(lineAng) * ts * 0.4
    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.5
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - dx, cy - dy)
    nvgLineTo(nvg, cx + dx, cy + dy)
    nvgStrokeColor(nvg, nvgRGBA(200, 230, 240, 50))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- ③ 六角霜花（~15% 概率，简化为 3 交叉线段）
    if tileRand(x, y, 1360) < 0.15 then
        local fx = sx + tileRand(x, y, 1361) * ts * 0.4 + ts * 0.3
        local fy = sy + tileRand(x, y, 1362) * ts * 0.4 + ts * 0.3
        local fr = 2.5 + tileRand(x, y, 1363) * 2.0
        nvgStrokeColor(nvg, nvgRGBA(220, 240, 255, 60))
        nvgStrokeWidth(nvg, 0.6)
        for a = 0, 2 do
            local ang = a * math.pi / 3
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, fx - math.cos(ang) * fr, fy - math.sin(ang) * fr)
            nvgLineTo(nvg, fx + math.cos(ang) * fr, fy + math.sin(ang) * fr)
            nvgStroke(nvg)
        end
    end

    -- ④ 微光泽（对角渐变高光）
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx + ts, sy + ts,
        nvgRGBA(220, 240, 255, 25), nvgRGBA(220, 240, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 寒池冰边 (CH5_COLD_ICE_EDGE) - 白蓝冰层 + 冰棱尖刺
-- ============================================================================
function M.RenderCh5ColdIceEdge(nvg, sx, sy, ts, x, y)
    -- ① 底色：白蓝冰
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(200, 225, 240, 255))
    nvgFill(nvg)

    -- ② 冰层裂纹（2~3 条白色细线）
    local numLines = 2 + tileHash(x, y, 1400) % 2
    for i = 1, numLines do
        local lx1 = sx + tileRand(x, y, 1401 + i * 3) * ts * 0.4
        local ly1 = sy + tileRand(x, y, 1402 + i * 3) * ts
        local lx2 = sx + tileRand(x, y, 1403 + i * 3) * ts * 0.4 + ts * 0.6
        local ly2 = sy + tileRand(x, y, 1404 + i * 3) * ts
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx1, ly1)
        nvgLineTo(nvg, lx2, ly2)
        nvgStrokeColor(nvg, nvgRGBA(240, 248, 255, 80))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end

    -- ③ 冰棱三角尖刺（~20% 概率，1~2 个朝上的小三角）
    if tileRand(x, y, 1410) < 0.20 then
        local ix = sx + tileRand(x, y, 1411) * ts * 0.6 + ts * 0.2
        local iy = sy + ts * 0.8
        local iw = 2.0 + tileRand(x, y, 1412) * 2.0
        local ih = 3.0 + tileRand(x, y, 1413) * 3.0
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, ix - iw, iy)
        nvgLineTo(nvg, ix, iy - ih)
        nvgLineTo(nvg, ix + iw, iy)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(230, 245, 255, 140))
        nvgFill(nvg)
    end

    -- ④ 蓝白渐变覆盖（冰面光泽）
    local icePaint = nvgLinearGradient(nvg, sx, sy, sx, sy + ts,
        nvgRGBA(180, 210, 240, 40), nvgRGBA(220, 240, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, icePaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 碑林苍白石 (CH5_STELE_PALE) - 风化苍白石 + 纵向纹理
-- ============================================================================
function M.RenderCh5StelePale(nvg, sx, sy, ts, x, y)
    -- ① 底色：苍白灰
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(170 + bv, 165 + bv, 158 + bv, 255))
    nvgFill(nvg)

    -- ② 纵向石纹（2~3 条竖直淡线）
    local numLines = 2 + tileHash(x, y, 1450) % 2
    for i = 1, numLines do
        local lx = sx + tileRand(x, y, 1451 + i) * ts * 0.8 + ts * 0.1
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx, sy + 1)
        nvgLineTo(nvg, lx + tileRand(x, y, 1452 + i) * 3 - 1.5, sy + ts - 1)
        nvgStrokeColor(nvg, nvgRGBA(145, 140, 132, 60))
        nvgStrokeWidth(nvg, 0.7)
        nvgStroke(nvg)
    end

    -- ③ 风化斑点（~15% 概率）
    if tileRand(x, y, 1460) < 0.15 then
        local wx = sx + tileRand(x, y, 1461) * ts * 0.6 + ts * 0.2
        local wy = sy + tileRand(x, y, 1462) * ts * 0.6 + ts * 0.2
        local wr = 1.5 + tileRand(x, y, 1463) * 2.0
        nvgBeginPath(nvg)
        nvgCircle(nvg, wx, wy, wr)
        nvgFillColor(nvg, nvgRGBA(155, 148, 140, 50))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 藏经焚毁地面 (CH5_LIBRARY_BURNT) - 焦木底 + 灰烬 + 余烬火星
-- ============================================================================
function M.RenderCh5LibraryBurnt(nvg, sx, sy, ts, x, y)
    -- ① 底色：焦褐黑
    local bv = ((x + y) % 2 == 0) and 5 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(55 + bv, 40 + bv, 30 + bv, 255))
    nvgFill(nvg)

    -- ② 焦木纹理（横向木纹线条）
    local numGrains = 2 + tileHash(x, y, 1500) % 2
    for i = 1, numGrains do
        local gy = sy + tileRand(x, y, 1501 + i) * ts * 0.8 + ts * 0.1
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + 2, gy)
        nvgLineTo(nvg, sx + ts - 2, gy + tileRand(x, y, 1502 + i) * 3 - 1.5)
        nvgStrokeColor(nvg, nvgRGBA(35, 25, 18, 80))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ③ 灰烬斑块（~20% 概率）
    if tileRand(x, y, 1510) < 0.20 then
        local ax = sx + tileRand(x, y, 1511) * ts * 0.5 + ts * 0.25
        local ay = sy + tileRand(x, y, 1512) * ts * 0.5 + ts * 0.25
        local ar = 2.0 + tileRand(x, y, 1513) * 2.5
        nvgBeginPath(nvg)
        nvgEllipse(nvg, ax, ay, ar, ar * 0.6)
        nvgFillColor(nvg, nvgRGBA(75, 70, 65, 50))
        nvgFill(nvg)
    end

    -- ④ 余烬火星（~8% 概率）
    if tileRand(x, y, 1520) < 0.08 then
        local ex = sx + tileRand(x, y, 1521) * ts * 0.7 + ts * 0.15
        local ey = sy + tileRand(x, y, 1522) * ts * 0.7 + ts * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, ex, ey, 1.0 + tileRand(x, y, 1523) * 0.8)
        nvgFillColor(nvg, nvgRGBA(200, 100, 30, 40))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 剑宫白石 (CH5_PALACE_WHITE) - 白石板 + 金边拼缝
-- ============================================================================
function M.RenderCh5PalaceWhite(nvg, sx, sy, ts, x, y)
    -- ① 底色：温白石
    local bv = ((x + y) % 2 == 0) and 4 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(215 + bv, 210 + bv, 200 + bv, 255))
    nvgFill(nvg)

    -- ② 石板拼缝（2x2 方格 + 金色接缝线）
    local halfW = ts / 2
    local halfH = ts / 2
    for bx = 0, 1 do
        for by = 0, 1 do
            local bsx = sx + bx * halfW
            local bsy = sy + by * halfH
            local sv = tileRandInt(x, y, bx * 2 + by + 1550, -5, 5)
            nvgBeginPath(nvg)
            nvgRect(nvg, bsx + 0.8, bsy + 0.8, halfW - 1.6, halfH - 1.6)
            nvgFillColor(nvg, nvgRGBA(210 + sv, 205 + sv, 195 + sv, 255))
            nvgFill(nvg)
        end
    end
    -- 金色接缝
    nvgStrokeColor(nvg, nvgRGBA(200, 175, 110, 50))
    nvgStrokeWidth(nvg, 0.6)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + halfW, sy)
    nvgLineTo(nvg, sx + halfW, sy + ts)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy + halfH)
    nvgLineTo(nvg, sx + ts, sy + halfH)
    nvgStroke(nvg)

    -- ③ 微光泽高光
    local hlPaint = nvgLinearGradient(nvg, sx, sy, sx + ts * 0.5, sy + ts * 0.5,
        nvgRGBA(255, 255, 240, 20), nvgRGBA(255, 255, 240, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, hlPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 剑宫侵蚀脉络 (CH5_PALACE_CORRUPTED) - 暗紫基底 + 有机脉络纹
-- ============================================================================
function M.RenderCh5PalaceCorrupted(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗紫灰
    local bv = ((x + y) % 2 == 0) and 4 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(65 + bv, 45 + bv, 75 + bv, 255))
    nvgFill(nvg)

    -- ② 有机脉络（2~3 条弯曲紫红线）
    local numVeins = 2 + tileHash(x, y, 1600) % 2
    for i = 1, numVeins do
        local vx1 = sx + tileRand(x, y, 1601 + i * 5) * ts * 0.3
        local vy1 = sy + tileRand(x, y, 1602 + i * 5) * ts
        local vx2 = sx + tileRand(x, y, 1603 + i * 5) * ts * 0.4 + ts * 0.3
        local vy2 = sy + tileRand(x, y, 1604 + i * 5) * ts
        local vcx = sx + tileRand(x, y, 1605 + i * 5) * ts * 0.4 + ts * 0.3
        local vcy = sy + tileRand(x, y, 1606 + i * 5) * ts
        -- 底层辉光（宽）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, vx1, vy1)
        nvgQuadTo(nvg, vcx, vcy, vx2, vy2)
        nvgStrokeColor(nvg, nvgRGBA(140, 50, 100, 25))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        -- 亮芯（窄）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, vx1, vy1)
        nvgQuadTo(nvg, vcx, vcy, vx2, vy2)
        nvgStrokeColor(nvg, nvgRGBA(180, 80, 140, 80))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ③ 侵蚀微光（~10% 概率）
    if tileRand(x, y, 1620) < 0.10 then
        local cx = sx + ts * 0.5
        local cy = sy + ts * 0.5
        local glowPaint = nvgRadialGradient(nvg, cx, cy, 0, ts * 0.3,
            nvgRGBA(150, 60, 120, 20), nvgRGBA(150, 60, 120, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, ts * 0.3)
        nvgFillPaint(nvg, glowPaint)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 血祭石 (CH5_BLOOD_RITUAL) - 暗红基底 + 符文刻痕
-- ============================================================================
function M.RenderCh5BloodRitual(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗红褐
    local bv = ((x + y) % 2 == 0) and 4 or -3
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(95 + bv, 30 + bv, 25 + bv, 255))
    nvgFill(nvg)

    -- ② 祭祀纹路（十字 + 对角线）
    nvgStrokeColor(nvg, nvgRGBA(140, 50, 40, 50))
    nvgStrokeWidth(nvg, 0.7)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.5, sy + ts * 0.15)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.85)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.15, sy + ts * 0.5)
    nvgLineTo(nvg, sx + ts * 0.85, sy + ts * 0.5)
    nvgStroke(nvg)

    -- ③ 角落符文圆弧（~20% 概率）
    if tileRand(x, y, 1650) < 0.20 then
        local cx = sx + ts * 0.5
        local cy = sy + ts * 0.5
        local r = ts * 0.3
        nvgBeginPath(nvg)
        nvgArc(nvg, cx, cy, r, 0, math.pi * 1.2, 1)
        nvgStrokeColor(nvg, nvgRGBA(160, 60, 50, 45))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ④ 血迹渗出（~10% 概率）
    if tileRand(x, y, 1660) < 0.10 then
        local bx = sx + tileRand(x, y, 1661) * ts * 0.5 + ts * 0.25
        local by = sy + tileRand(x, y, 1662) * ts * 0.5 + ts * 0.25
        nvgBeginPath(nvg)
        nvgCircle(nvg, bx, by, 1.5 + tileRand(x, y, 1663) * 1.5)
        nvgFillColor(nvg, nvgRGBA(120, 20, 15, 50))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 深渊焦岩 (CH5_ABYSS_CHARRED) - 极暗底 + 橙色熔裂纹
-- ============================================================================
function M.RenderCh5AbyssCharred(nvg, sx, sy, ts, x, y)
    -- ① 底色：极暗灰黑
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(25, 18, 15, 255))
    nvgFill(nvg)

    -- ② 棋盘微调
    if (x + y) % 2 == 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, sx, sy, ts, ts)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 5))
        nvgFill(nvg)
    end

    -- ③ 炽热裂纹（1~2 条橙色发光缝隙）
    local numCracks = 1 + tileHash(x, y, 1700) % 2
    for i = 1, numCracks do
        local cx1 = sx + tileRand(x, y, 1701 + i * 4) * ts * 0.3 + ts * 0.05
        local cy1 = sy + tileRand(x, y, 1702 + i * 4) * ts * 0.3 + ts * 0.05
        local cx2 = sx + tileRand(x, y, 1703 + i * 4) * ts * 0.3 + ts * 0.6
        local cy2 = sy + tileRand(x, y, 1704 + i * 4) * ts * 0.3 + ts * 0.6
        -- 底层辉光
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(200, 80, 10, 30))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        -- 亮芯
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx1, cy1)
        nvgLineTo(nvg, cx2, cy2)
        nvgStrokeColor(nvg, nvgRGBA(255, 160, 40, 100))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end

    -- ④ 暗红微光（底部热辐射）
    local heatPaint = nvgLinearGradient(nvg, sx, sy + ts * 0.7, sx, sy + ts,
        nvgRGBA(180, 50, 10, 0), nvgRGBA(180, 50, 10, 20))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy + ts * 0.7, ts, ts * 0.3)
    nvgFillPaint(nvg, heatPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- CH5 回廊暗石 (CH5_CORRIDOR_DARK) - 暗色方石 + 方形接缝
-- ============================================================================
function M.RenderCh5CorridorDark(nvg, sx, sy, ts, x, y)
    -- ① 底色：深灰暗石
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(60, 55, 52, 255))
    nvgFill(nvg)

    -- ② 方形石板接缝（2x2 网格）
    local halfW = ts / 2
    local halfH = ts / 2
    for bx = 0, 1 do
        for by = 0, 1 do
            local bsx = sx + bx * halfW
            local bsy = sy + by * halfH
            local sv = tileRandInt(x, y, bx * 2 + by + 1750, -6, 6)
            nvgBeginPath(nvg)
            nvgRect(nvg, bsx + 0.8, bsy + 0.8, halfW - 1.6, halfH - 1.6)
            nvgFillColor(nvg, nvgRGBA(58 + sv, 53 + sv, 50 + sv, 255))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgRect(nvg, bsx + 0.8, bsy + 0.8, halfW - 1.6, halfH - 1.6)
            nvgStrokeColor(nvg, nvgRGBA(35, 30, 28, 80))
            nvgStrokeWidth(nvg, 0.6)
            nvgStroke(nvg)
        end
    end

    -- ③ 尘灰沉积（~10% 概率）
    if tileRand(x, y, 1760) < 0.10 then
        local dx = sx + tileRand(x, y, 1761) * ts * 0.5 + ts * 0.25
        local dy = sy + tileRand(x, y, 1762) * ts * 0.5 + ts * 0.25
        nvgBeginPath(nvg)
        nvgEllipse(nvg, dx, dy, 2.5, 1.5)
        nvgFillColor(nvg, nvgRGBA(80, 75, 70, 35))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 深渊血肉岩 (CH5_ABYSS_FLESH) - 暗红有机质感 + 脉动纹路
-- ============================================================================
function M.RenderCh5AbyssFlesh(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗红褐
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1800, -5, 5)
    nvgFillColor(nvg, nvgRGBA(55 + sv, 20 + sv, 18 + sv, 255))
    nvgFill(nvg)

    -- ② 有机纹理（不规则弧形脉络 2~3 条）
    local numVeins = 2 + tileHash(x, y, 1801) % 2
    for i = 1, numVeins do
        local vx1 = sx + tileRand(x, y, 1802 + i * 5) * ts
        local vy1 = sy + tileRand(x, y, 1803 + i * 5) * ts
        local vx2 = sx + tileRand(x, y, 1804 + i * 5) * ts
        local vy2 = sy + tileRand(x, y, 1805 + i * 5) * ts
        local vcx = sx + tileRand(x, y, 1806 + i * 5) * ts
        local vcy = sy + tileRand(x, y, 1807 + i * 5) * ts
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, vx1, vy1)
        nvgQuadTo(nvg, vcx, vcy, vx2, vy2)
        nvgStrokeColor(nvg, nvgRGBA(120, 30, 25, 80))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end

    -- ③ 肉质凸起斑块（~15%）
    if tileRand(x, y, 1820) < 0.15 then
        local bx = sx + tileRand(x, y, 1821) * ts * 0.6 + ts * 0.2
        local by = sy + tileRand(x, y, 1822) * ts * 0.6 + ts * 0.2
        nvgBeginPath(nvg)
        nvgEllipse(nvg, bx, by, 2.5, 2.0)
        nvgFillColor(nvg, nvgRGBA(90, 30, 25, 60))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- CH5 回廊剑金属 (CH5_CORRIDOR_SWORD) - 暗铁墙面 + 剑痕刻纹
-- ============================================================================
function M.RenderCh5CorridorSword(nvg, sx, sy, ts, x, y)
    -- ① 底色：暗铁灰
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1830, -4, 4)
    nvgFillColor(nvg, nvgRGBA(50 + sv, 50 + sv, 55 + sv, 255))
    nvgFill(nvg)

    -- ② 金属横纹（水平拉丝效果）
    for i = 1, 3 do
        local ly = sy + tileRand(x, y, 1831 + i) * ts
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx, ly)
        nvgLineTo(nvg, sx + ts, ly)
        nvgStrokeColor(nvg, nvgRGBA(70, 70, 75, 30))
        nvgStrokeWidth(nvg, 0.5)
        nvgStroke(nvg)
    end

    -- ③ 剑痕斜划（1~2 条锐利的浅色斜线）
    local numSlash = 1 + tileHash(x, y, 1835) % 2
    for i = 1, numSlash do
        local ax = sx + tileRand(x, y, 1836 + i * 3) * ts * 0.4
        local ay = sy + tileRand(x, y, 1837 + i * 3) * ts * 0.3
        local bxx = ax + ts * 0.5 + tileRand(x, y, 1838 + i * 3) * ts * 0.2
        local byy = ay + ts * 0.5 + tileRand(x, y, 1839 + i * 3) * ts * 0.2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, ax, ay)
        nvgLineTo(nvg, bxx, byy)
        nvgStrokeColor(nvg, nvgRGBA(130, 130, 140, 50))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- CH5 虚空 (CH5_VOID) - 极深暗色 + 微弱星点
-- ============================================================================
function M.RenderCh5Void(nvg, sx, sy, ts, x, y)
    -- ① 底色：近黑
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    local sv = tileRandInt(x, y, 1860, -3, 3)
    nvgFillColor(nvg, nvgRGBA(10 + sv, 8 + sv, 15 + sv, 255))
    nvgFill(nvg)

    -- ② 暗紫渐变覆盖（底部略亮）
    local voidPaint = nvgLinearGradient(nvg, sx, sy, sx, sy + ts,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(20, 10, 30, 40))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillPaint(nvg, voidPaint)
    nvgFill(nvg)

    -- ③ 微弱星点（~20% 每格 1 点）
    if tileRand(x, y, 1861) < 0.20 then
        local px = sx + tileRand(x, y, 1862) * ts
        local py = sy + tileRand(x, y, 1863) * ts
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 0.5)
        nvgFillColor(nvg, nvgRGBA(150, 130, 200, 30))
        nvgFill(nvg)
    end
end

return M
