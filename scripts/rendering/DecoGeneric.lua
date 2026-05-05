-- ============================================================================
-- DecoGeneric.lua  —— 通用装饰物渲染（野营/军事/自然/魔法）
-- 从 DecorationRenderers.lua 纯剥离，零逻辑修改
-- ============================================================================
local T = require("config.UITheme")

local M = {}

-- ============================================================================
-- 模块级常量
-- ============================================================================
local WEAPON_RACK_DEFS = {
    { x = 0.35, len = 0.35, color = {160, 160, 170} },  -- 剑
    { x = 0.50, len = 0.40, color = {140, 140, 150} },  -- 刀
    { x = 0.65, len = 0.32, color = {170, 160, 150} },  -- 短剑
}

local FENCE_POSTS = {0.18, 0.45, 0.72}
local FENCE_BEAM_HEIGHTS = {0.35, 0.65}

local DEFAULT_COLOR_TENT      = {160, 120, 70, 255}
local DEFAULT_COLOR_BUSH      = {45, 110, 35, 255}
local DEFAULT_COLOR_FLAG      = {180, 40, 30, 255}
local DEFAULT_COLOR_TELEPORT  = {100, 150, 255, 255}

-- ============================================================================
-- 篝火 - 交叉木柴 + 多层火焰 + 火星 + 烟雾
-- ============================================================================
function M.RenderCampfire(nvg, sx, sy, ts, d, time)
    -- 地面光晕
    local flicker = math.sin(time * 4 + (d.x or 0) * 3) * 0.2 + 0.8
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.6, ts * 0.45)
    nvgFillColor(nvg, nvgRGBA(255, 150, 50, math.floor(20 * flicker)))
    nvgFill(nvg)

    -- 木柴（两根交叉）
    nvgSave(nvg)
    nvgTranslate(nvg, sx + ts * 0.5, sy + ts * 0.7)
    -- 左柴
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, -ts * 0.22, -ts * 0.02)
    nvgLineTo(nvg, ts * 0.08, ts * 0.06)
    nvgStrokeColor(nvg, nvgRGBA(100, 60, 25, 255))
    nvgStrokeWidth(nvg, 3.5)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
    -- 右柴
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, ts * 0.22, -ts * 0.02)
    nvgLineTo(nvg, -ts * 0.08, ts * 0.06)
    nvgStrokeColor(nvg, nvgRGBA(90, 55, 20, 255))
    nvgStrokeWidth(nvg, 3.5)
    nvgStroke(nvg)
    nvgRestore(nvg)

    -- 火焰（多层，从底到顶：红→橙→黄）
    local cx = sx + ts * 0.5
    local baseY = sy + ts * 0.62
    local sway = math.sin(time * 5 + (d.x or 0) * 7) * 2

    -- 外焰（红）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - ts * 0.14, baseY)
    nvgBezierTo(nvg, cx - ts * 0.12, baseY - ts * 0.2,
                cx + sway * 0.5, baseY - ts * 0.38,
                cx + sway, baseY - ts * 0.42)
    nvgBezierTo(nvg, cx + sway * 0.5, baseY - ts * 0.38,
                cx + ts * 0.12, baseY - ts * 0.2,
                cx + ts * 0.14, baseY)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(220, 60, 20, math.floor(200 * flicker)))
    nvgFill(nvg)

    -- 中焰（橙）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - ts * 0.08, baseY)
    nvgBezierTo(nvg, cx - ts * 0.06, baseY - ts * 0.15,
                cx + sway * 0.3, baseY - ts * 0.28,
                cx + sway * 0.7, baseY - ts * 0.32)
    nvgBezierTo(nvg, cx + sway * 0.3, baseY - ts * 0.28,
                cx + ts * 0.06, baseY - ts * 0.15,
                cx + ts * 0.08, baseY)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(255, 160, 30, math.floor(220 * flicker)))
    nvgFill(nvg)

    -- 内焰（黄白）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx + sway * 0.3, baseY - ts * 0.12, ts * 0.04, ts * 0.1)
    nvgFillColor(nvg, nvgRGBA(255, 240, 150, math.floor(250 * flicker)))
    nvgFill(nvg)

    -- 火星粒子
    for i = 1, 3 do
        local sparkT = (time * 2 + i * 1.3) % 2.0
        local sparkAlpha = math.max(0, 1 - sparkT)
        local sparkX = cx + math.sin(time * 3 + i * 2.1) * ts * 0.12
        local sparkY = baseY - ts * 0.3 - sparkT * ts * 0.2
        nvgBeginPath(nvg)
        nvgCircle(nvg, sparkX, sparkY, 1.2)
        nvgFillColor(nvg, nvgRGBA(255, 200, 80, math.floor(180 * sparkAlpha)))
        nvgFill(nvg)
    end

    -- 淡烟雾
    for i = 0, 1 do
        local smokeT = (time * 0.8 + i * 1.5) % 3.0
        local smokeAlpha = math.max(0, 40 - smokeT * 15)
        local smokeX = cx + math.sin(time * 0.6 + i * 2) * 3
        local smokeY = baseY - ts * 0.45 - smokeT * ts * 0.15
        nvgBeginPath(nvg)
        nvgCircle(nvg, smokeX, smokeY, 3 + smokeT * 1.5)
        nvgFillColor(nvg, nvgRGBA(160, 160, 160, math.floor(smokeAlpha)))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 帐篷 - 三角形布帐 + 木杆支撑 + 门帘
-- ============================================================================
function M.RenderTent(nvg, sx, sy, ts, d)
    local c = d.color or DEFAULT_COLOR_TENT

    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.88, ts * 0.42, ts * 0.1)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
    nvgFill(nvg)

    -- 帐篷主体（梯形/三角形）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.05, sy + ts * 0.85)  -- 左下
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.08)   -- 顶
    nvgLineTo(nvg, sx + ts * 0.95, sy + ts * 0.85)  -- 右下
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], c[4]))
    nvgFill(nvg)

    -- 帐篷纹理线（横条纹）
    for i = 1, 3 do
        local ly = sy + ts * (0.25 + i * 0.15)
        local halfW = ts * (0.1 + i * 0.12)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + ts * 0.5 - halfW, ly)
        nvgLineTo(nvg, sx + ts * 0.5 + halfW, ly)
        nvgStrokeColor(nvg, nvgRGBA(c[1] - 20, c[2] - 20, c[3] - 15, 60))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end

    -- 帐篷边框
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.05, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.08)
    nvgLineTo(nvg, sx + ts * 0.95, sy + ts * 0.85)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(c[1] - 30, c[2] - 30, c[3] - 25, 200))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- 门帘（中间的深色开口）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.38, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.5, sy + ts * 0.45)
    nvgLineTo(nvg, sx + ts * 0.62, sy + ts * 0.85)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(40, 30, 20, 180))
    nvgFill(nvg)

    -- 顶部支撑杆
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.5, sy + ts * 0.06, 2)
    nvgFillColor(nvg, nvgRGBA(90, 60, 30, 255))
    nvgFill(nvg)
end

-- ============================================================================
-- 瞭望塔 - 木构高台 + 观察哨 + 旗帜
-- ============================================================================
function M.RenderWatchtower(nvg, sx, sy, ts, d, time)
    local w = (d.w or 2) * ts
    local h = (d.h or 2) * ts

    -- 投影
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + 5, sy + 5, w - 4, h - 4, 3)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 35))
    nvgFill(nvg)

    -- 四根支撑柱
    local pillarW = w * 0.08
    local pillarH = h * 0.75
    local positions = {
        {sx + w * 0.1, sy + h * 0.2},
        {sx + w * 0.82, sy + h * 0.2},
        {sx + w * 0.1, sy + h * 0.65},
        {sx + w * 0.82, sy + h * 0.65},
    }
    for _, p in ipairs(positions) do
        nvgBeginPath(nvg)
        nvgRect(nvg, p[1], p[2], pillarW, pillarH)
        nvgFillColor(nvg, nvgRGBA(95, 65, 35, 255))
        nvgFill(nvg)
    end

    -- 交叉支撑（X 形）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + w * 0.14, sy + h * 0.3)
    nvgLineTo(nvg, sx + w * 0.86, sy + h * 0.7)
    nvgMoveTo(nvg, sx + w * 0.86, sy + h * 0.3)
    nvgLineTo(nvg, sx + w * 0.14, sy + h * 0.7)
    nvgStrokeColor(nvg, nvgRGBA(80, 55, 30, 180))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 平台（顶部）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx - 3, sy + h * 0.08, w + 6, h * 0.18, 3)
    nvgFillColor(nvg, nvgRGBA(120, 85, 45, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(80, 55, 30, 200))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- 栏杆（平台四周）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx - 3, sy + h * 0.08, w + 6, 2)
    nvgFillColor(nvg, nvgRGBA(100, 70, 35, 255))
    nvgFill(nvg)

    -- 小屋顶（三角）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx - 1, sy + h * 0.1)
    nvgLineTo(nvg, sx + w * 0.5, sy - h * 0.08)
    nvgLineTo(nvg, sx + w + 1, sy + h * 0.1)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(140, 60, 30, 240))
    nvgFill(nvg)

    -- 旗帜（顶端，飘动）
    local flagSway = math.sin(time * 2.5 + (d.x or 0) * 5) * 4
    local flagX = sx + w * 0.5
    local flagY = sy - h * 0.08
    -- 旗杆
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, flagX, flagY)
    nvgLineTo(nvg, flagX, flagY - h * 0.18)
    nvgStrokeColor(nvg, nvgRGBA(90, 60, 30, 255))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    -- 旗面（红色三角旗）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, flagX, flagY - h * 0.18)
    nvgLineTo(nvg, flagX + w * 0.15 + flagSway, flagY - h * 0.13)
    nvgLineTo(nvg, flagX, flagY - h * 0.08)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(200, 50, 30, 220))
    nvgFill(nvg)

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.label)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 130))
        nvgText(nvg, sx + w * 0.5 + 1, sy + h * 0.52 + 1, d.label, nil)
        nvgFillColor(nvg, nvgRGBA(255, 230, 180, 255))
        nvgText(nvg, sx + w * 0.5, sy + h * 0.52, d.label, nil)
    end
end

-- ============================================================================
-- 兵器架 - 木架 + 挂载的刀剑
-- ============================================================================
function M.RenderWeaponRack(nvg, sx, sy, ts, d)
    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.88, ts * 0.3, ts * 0.08)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 25))
    nvgFill(nvg)

    -- 支撑架（A 字形两根斜柱 + 横杆）
    -- 左斜柱
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.25, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.42, sy + ts * 0.15)
    nvgStrokeColor(nvg, nvgRGBA(100, 70, 35, 255))
    nvgStrokeWidth(nvg, 3)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
    -- 右斜柱
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.75, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.58, sy + ts * 0.15)
    nvgStrokeColor(nvg, nvgRGBA(100, 70, 35, 255))
    nvgStrokeWidth(nvg, 3)
    nvgStroke(nvg)
    -- 横杆
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.3, sy + ts * 0.3)
    nvgLineTo(nvg, sx + ts * 0.7, sy + ts * 0.3)
    nvgStrokeColor(nvg, nvgRGBA(110, 75, 40, 255))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)

    -- 挂载的武器（3把）
    for _, wp in ipairs(WEAPON_RACK_DEFS) do
        local wx = sx + ts * wp.x
        local wy = sy + ts * 0.32
        -- 剑柄
        nvgBeginPath(nvg)
        nvgRect(nvg, wx - 1.5, wy, 3, ts * 0.06)
        nvgFillColor(nvg, nvgRGBA(80, 50, 25, 255))
        nvgFill(nvg)
        -- 护手
        nvgBeginPath(nvg)
        nvgRect(nvg, wx - 4, wy + ts * 0.06, 8, 2)
        nvgFillColor(nvg, nvgRGBA(180, 150, 60, 255))
        nvgFill(nvg)
        -- 剑身
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, wx, wy + ts * 0.08)
        nvgLineTo(nvg, wx, wy + ts * wp.len)
        nvgStrokeColor(nvg, nvgRGBA(wp.color[1], wp.color[2], wp.color[3], 255))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)
        -- 剑尖
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, wx - 1.5, wy + ts * wp.len)
        nvgLineTo(nvg, wx, wy + ts * wp.len + 4)
        nvgLineTo(nvg, wx + 1.5, wy + ts * wp.len)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(wp.color[1], wp.color[2], wp.color[3], 255))
        nvgFill(nvg)
        -- 高光
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, wx + 0.5, wy + ts * 0.1)
        nvgLineTo(nvg, wx + 0.5, wy + ts * (wp.len - 0.05))
        nvgStrokeColor(nvg, nvgRGBA(220, 220, 230, 80))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 倒木 - 横卧的树干 + 断裂口 + 苔藓
-- ============================================================================
function M.RenderFallenTree(nvg, sx, sy, ts, d)
    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.7, ts * 0.42, ts * 0.08)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 25))
    nvgFill(nvg)

    -- 树干主体（横卧圆柱形）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.05, sy + ts * 0.52, ts * 0.9, ts * 0.2, 6)
    nvgFillColor(nvg, nvgRGBA(85, 60, 35, 255))
    nvgFill(nvg)

    -- 树皮纹理
    for i = 1, 5 do
        local lx = sx + ts * (0.1 + i * 0.13)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx, sy + ts * 0.54)
        nvgLineTo(nvg, lx, sy + ts * 0.7)
        nvgStrokeColor(nvg, nvgRGBA(65, 45, 25, 50))
        nvgStrokeWidth(nvg, 0.5)
        nvgStroke(nvg)
    end

    -- 断裂口（左端，黄色木质暴露）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.05, sy + ts * 0.62, ts * 0.04, ts * 0.1)
    nvgFillColor(nvg, nvgRGBA(180, 150, 90, 255))
    nvgFill(nvg)
    -- 年轮
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.05, sy + ts * 0.62, ts * 0.02, ts * 0.06)
    nvgStrokeColor(nvg, nvgRGBA(140, 110, 60, 150))
    nvgStrokeWidth(nvg, 0.5)
    nvgStroke(nvg)

    -- 残留枝杈（右端伸出）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.85, sy + ts * 0.55)
    nvgLineTo(nvg, sx + ts * 0.95, sy + ts * 0.4)
    nvgStrokeColor(nvg, nvgRGBA(75, 55, 30, 200))
    nvgStrokeWidth(nvg, 2)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.7, sy + ts * 0.53)
    nvgLineTo(nvg, sx + ts * 0.75, sy + ts * 0.38)
    nvgStrokeColor(nvg, nvgRGBA(75, 55, 30, 180))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 苔藓（绿色斑块覆盖树干上方）
    for i = 1, 3 do
        local mx = sx + ts * (0.2 + i * 0.2)
        nvgBeginPath(nvg)
        nvgEllipse(nvg, mx, sy + ts * 0.52, ts * 0.06, ts * 0.03)
        nvgFillColor(nvg, nvgRGBA(60, 120, 40, 140))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 灌木丛 - 多球形叠加的低矮灌木
-- ============================================================================
function M.RenderBush(nvg, sx, sy, ts, d, time)
    local c = d.color or DEFAULT_COLOR_BUSH
    local sway = math.sin(time * 1.0 + (d.x or 0) * 4.3) * 0.8

    -- 地面阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.85, ts * 0.35, ts * 0.08)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 20))
    nvgFill(nvg)

    -- 底层大球（最暗）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5 + sway * 0.2, sy + ts * 0.65, ts * 0.38, ts * 0.22)
    nvgFillColor(nvg, nvgRGBA(c[1] - 10, c[2] - 15, c[3] - 8, 255))
    nvgFill(nvg)

    -- 中层左球
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.32 + sway * 0.4, sy + ts * 0.55, ts * 0.22, ts * 0.18)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 255))
    nvgFill(nvg)

    -- 中层右球
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.68 + sway * 0.4, sy + ts * 0.55, ts * 0.2, ts * 0.16)
    nvgFillColor(nvg, nvgRGBA(c[1] + 5, c[2] + 5, c[3] + 3, 255))
    nvgFill(nvg)

    -- 顶层球（最亮）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5 + sway * 0.5, sy + ts * 0.48, ts * 0.15, ts * 0.12)
    nvgFillColor(nvg, nvgRGBA(c[1] + 15, c[2] + 20, c[3] + 10, 255))
    nvgFill(nvg)

    -- 叶片高光
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.4 + sway * 0.3, sy + ts * 0.5, ts * 0.04)
    nvgFillColor(nvg, nvgRGBA(c[1] + 40, c[2] + 45, c[3] + 20, 60))
    nvgFill(nvg)
end

-- ============================================================================
-- 小池塘 - 2x2 椭圆形水面 + 涟漪 + 荷叶
-- ============================================================================
function M.RenderPond(nvg, sx, sy, ts, d, time)
    local w = (d.w or 2) * ts
    local h = (d.h or 2) * ts
    local cx = sx + w * 0.5
    local cy = sy + h * 0.5

    -- 池塘边缘（深色泥土环）
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy, w * 0.48, h * 0.42)
    nvgFillColor(nvg, nvgRGBA(70, 55, 35, 255))
    nvgFill(nvg)

    -- 水面主体
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy, w * 0.42, h * 0.36)
    nvgFillColor(nvg, nvgRGBA(40, 80, 120, 220))
    nvgFill(nvg)

    -- 水面反光
    local glint = math.sin(time * 1.5) * 0.2 + 0.8
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx - w * 0.1, cy - h * 0.08, w * 0.15, h * 0.08)
    nvgFillColor(nvg, nvgRGBA(120, 180, 220, math.floor(80 * glint)))
    nvgFill(nvg)

    -- 涟漪（同心圆动画）
    local ripplePhase = (time * 0.6) % 2.0
    local rippleAlpha = math.max(0, 1 - ripplePhase * 0.5)
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx + w * 0.05, cy + h * 0.05, w * 0.1 + ripplePhase * w * 0.08, h * 0.06 + ripplePhase * h * 0.05)
    nvgStrokeColor(nvg, nvgRGBA(150, 200, 230, math.floor(60 * rippleAlpha)))
    nvgStrokeWidth(nvg, 0.6)
    nvgStroke(nvg)

    -- 荷叶（2片）
    -- 荷叶1
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx - w * 0.12, cy + h * 0.08, w * 0.06, h * 0.04)
    nvgFillColor(nvg, nvgRGBA(40, 110, 50, 180))
    nvgFill(nvg)
    -- 荷叶缺口
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - w * 0.12, cy + h * 0.08)
    nvgLineTo(nvg, cx - w * 0.12 - w * 0.02, cy + h * 0.04)
    nvgStrokeColor(nvg, nvgRGBA(40, 80, 120, 220))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 荷叶2
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx + w * 0.15, cy - h * 0.05, w * 0.05, h * 0.035)
    nvgFillColor(nvg, nvgRGBA(50, 120, 55, 170))
    nvgFill(nvg)

    -- 池塘边缘草丛点缀
    for i = 0, 3 do
        local angle = i * math.pi * 0.5 + 0.3
        local gx = cx + math.cos(angle) * w * 0.44
        local gy = cy + math.sin(angle) * h * 0.38
        nvgBeginPath(nvg)
        nvgEllipse(nvg, gx, gy, 4, 3)
        nvgFillColor(nvg, nvgRGBA(50, 100, 40, 140))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 旗帜 - 木杆 + 飘动的三角旗
-- ============================================================================
function M.RenderFlag(nvg, sx, sy, ts, d, time)
    local c = d.color or DEFAULT_COLOR_FLAG
    local sway = math.sin(time * 2.5 + (d.x or 0) * 5) * 5

    -- 旗杆底座
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + ts * 0.38, sy + ts * 0.82, ts * 0.24, ts * 0.1, 2)
    nvgFillColor(nvg, nvgRGBA(70, 50, 30, 255))
    nvgFill(nvg)

    -- 旗杆
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.47, sy + ts * 0.08, 3, ts * 0.76)
    nvgFillColor(nvg, nvgRGBA(90, 65, 35, 255))
    nvgFill(nvg)

    -- 杆顶装饰球
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.485, sy + ts * 0.06, 3)
    nvgFillColor(nvg, nvgRGBA(200, 170, 80, 255))
    nvgFill(nvg)

    -- 旗面（矩形，带波浪下边）
    local flagX = sx + ts * 0.5
    local flagY = sy + ts * 0.1
    local flagW = ts * 0.38
    local flagH = ts * 0.25

    nvgBeginPath(nvg)
    nvgMoveTo(nvg, flagX, flagY)
    nvgLineTo(nvg, flagX + flagW + sway, flagY + flagH * 0.1)
    nvgBezierTo(nvg, flagX + flagW + sway * 0.8, flagY + flagH * 0.5,
                flagX + flagW * 0.8 + sway * 0.6, flagY + flagH * 0.8,
                flagX + flagW * 0.7 + sway * 0.3, flagY + flagH)
    nvgLineTo(nvg, flagX, flagY + flagH)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], c[4]))
    nvgFill(nvg)

    -- 旗面装饰（交叉骨图案 — 山贼标志）
    local iconCx = flagX + flagW * 0.35 + sway * 0.4
    local iconCy = flagY + flagH * 0.5
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, iconCx - 4, iconCy - 4)
    nvgLineTo(nvg, iconCx + 4, iconCy + 4)
    nvgMoveTo(nvg, iconCx + 4, iconCy - 4)
    nvgLineTo(nvg, iconCx - 4, iconCy + 4)
    nvgStrokeColor(nvg, nvgRGBA(255, 230, 180, 180))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    -- 骷髅小圆
    nvgBeginPath(nvg)
    nvgCircle(nvg, iconCx, iconCy - 5, 3)
    nvgFillColor(nvg, nvgRGBA(255, 230, 180, 180))
    nvgFill(nvg)
end

-- ============================================================================
-- 木栅栏 - 单格竖木栅
-- ============================================================================
function M.RenderFence(nvg, sx, sy, ts, d)
    -- 3 根竖木桩
    for _, px in ipairs(FENCE_POSTS) do
        local postX = sx + ts * px
        -- 木桩
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, postX - 3, sy + ts * 0.15, 6, ts * 0.7, 1.5)
        nvgFillColor(nvg, nvgRGBA(110, 75, 40, 255))
        nvgFill(nvg)
        -- 尖顶
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, postX - 3, sy + ts * 0.15)
        nvgLineTo(nvg, postX, sy + ts * 0.05)
        nvgLineTo(nvg, postX + 3, sy + ts * 0.15)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(120, 85, 45, 255))
        nvgFill(nvg)
    end

    -- 横梁（2条，连接木桩）
    for _, hy in ipairs(FENCE_BEAM_HEIGHTS) do
        nvgBeginPath(nvg)
        nvgRect(nvg, sx + ts * 0.12, sy + ts * hy, ts * 0.66, 3)
        nvgFillColor(nvg, nvgRGBA(100, 70, 35, 220))
        nvgFill(nvg)
    end

    -- 木纹
    for _, px in ipairs(FENCE_POSTS) do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + ts * px + 1, sy + ts * 0.2)
        nvgLineTo(nvg, sx + ts * px + 1, sy + ts * 0.8)
        nvgStrokeColor(nvg, nvgRGBA(85, 55, 25, 40))
        nvgStrokeWidth(nvg, 0.5)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 治愈之泉 - 发光水池 + 涟漪 + 粒子
-- ============================================================================
function M.RenderHealingSpring(nvg, sx, sy, ts, d, time)
    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.5
    local r = ts * 0.45

    -- 外圈光晕（脉动）
    local glowAlpha = math.sin(time * 1.5) * 30 + 50
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r + 6)
    nvgFillColor(nvg, nvgRGBA(80, 220, 180, math.floor(glowAlpha)))
    nvgFill(nvg)

    -- 水池底部
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r)
    nvgFillColor(nvg, nvgRGBA(40, 140, 130, 200))
    nvgFill(nvg)

    -- 水面高光
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r * 0.85)
    local waterGrad = nvgRadialGradient(nvg, cx - r * 0.2, cy - r * 0.2, r * 0.1, r * 0.8,
        nvgRGBA(120, 255, 220, 180), nvgRGBA(50, 180, 160, 120))
    nvgFillPaint(nvg, waterGrad)
    nvgFill(nvg)

    -- 涟漪（两圈，相位不同）
    for i = 0, 1 do
        local phase = (time * 0.8 + i * 1.5) % 3.0
        local rippleR = r * 0.3 + (phase / 3.0) * r * 0.6
        local rippleA = math.max(0, 1.0 - phase / 3.0) * 120
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, rippleR)
        nvgStrokeColor(nvg, nvgRGBA(150, 255, 220, math.floor(rippleA)))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
    end

    -- 浮动光粒（3颗）
    for i = 0, 2 do
        local angle = time * 0.6 + i * 2.094  -- 120度间隔
        local pr = r * 0.5 + math.sin(time * 1.2 + i) * r * 0.15
        local px = cx + math.cos(angle) * pr
        local py = cy + math.sin(angle) * pr - math.sin(time * 2 + i) * 3
        local pa = math.sin(time * 2 + i * 1.3) * 60 + 140
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 2)
        nvgFillColor(nvg, nvgRGBA(180, 255, 230, math.floor(pa)))
        nvgFill(nvg)
    end

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(80, 220, 180, 220))
        nvgText(nvg, cx, sy + ts + 2, d.label)
    end
end

-- ============================================================================
-- 传送法阵 - 旋转发光同心圆 + 符文光效
-- ============================================================================
function M.RenderTeleportArray(nvg, sx, sy, ts, d, time)
    local cx = sx + ts * 0.5
    local cy = sy + ts * 0.5
    local baseR = ts * 0.45
    local c = d.color or DEFAULT_COLOR_TELEPORT
    local pulse = 0.85 + 0.15 * math.sin(time * 2.0)
    local alpha = math.floor(c[4] * pulse)

    -- 底部光晕（大范围柔和光）
    local glowR = baseR * 1.3
    local glowPaint = nvgRadialGradient(nvg, cx, cy, baseR * 0.3, glowR,
        nvgRGBA(c[1], c[2], c[3], math.floor(alpha * 0.4)),
        nvgRGBA(c[1], c[2], c[3], 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, glowR)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- 外圈
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, baseR)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], alpha))
    nvgStrokeWidth(nvg, 2.0)
    nvgStroke(nvg)

    -- 内圈
    local innerR = baseR * 0.6
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, innerR)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(alpha * 0.8)))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 旋转符文标记（6个点绕外圈旋转）
    local runeCount = 6
    local rotSpeed = time * 0.8
    for i = 1, runeCount do
        local angle = rotSpeed + (i - 1) * (2 * math.pi / runeCount)
        local rx = cx + math.cos(angle) * baseR * 0.8
        local ry = cy + math.sin(angle) * baseR * 0.8
        local runeAlpha = math.floor(alpha * (0.6 + 0.4 * math.sin(time * 3.0 + i)))

        nvgBeginPath(nvg)
        nvgCircle(nvg, rx, ry, ts * 0.04)
        nvgFillColor(nvg, nvgRGBA(200, 220, 255, runeAlpha))
        nvgFill(nvg)
    end

    -- 中心核心光点
    local coreR = ts * 0.08
    local corePaint = nvgRadialGradient(nvg, cx, cy, 0, coreR,
        nvgRGBA(220, 240, 255, math.floor(alpha * 0.9)),
        nvgRGBA(c[1], c[2], c[3], 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, coreR)
    nvgFillPaint(nvg, corePaint)
    nvgFill(nvg)

    -- 标签
    if d.label then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(180, 210, 255, math.floor(alpha * 0.9)))
        nvgText(nvg, cx, sy + ts + 2, d.label)
    end
end

return M
