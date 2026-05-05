-- ============================================================================
-- DecoDesert.lua  —— 沙漠装饰物渲染
-- 从 DecorationRenderers.lua 纯剥离，零逻辑修改
-- ============================================================================
local M = {}

-- ============================================================================
-- 模块级常量
-- ============================================================================
local CACTUS_SPINES = {
    {0.0, 0.35, -4, -2}, {0.0, 0.55, -5, 0}, {0.0, 0.7, -3, 1},
    {0.12, 0.4, 4, -1}, {0.12, 0.6, 5, 1}, {0.12, 0.75, 3, 0},
}

local DEAD_BUSH_BRANCHES = {
    {-0.22, -0.08}, {-0.18, 0.12}, {0.2, -0.1}, {0.15, 0.14},
    {-0.05, -0.2}, {0.08, -0.18}, {-0.12, 0.18}, {0.18, 0.05},
}

local PALM_LEAF_COLOR = {45, 120, 35, 220}
local PALM_LEAF_DARK_COLOR = {35, 95, 25, 200}
local PALM_LEAVES = {
    {-0.25, -0.05}, {-0.18, -0.15}, {-0.05, -0.2},
    {0.2, -0.08}, {0.15, -0.18}, {0.05, -0.22},
}

--- 仙人掌 - 绿色圆柱体 + 分叉臂 + 刺
function M.RenderCactus(nvg, sx, sy, ts, d, time)
    local sway = math.sin(time * 0.5 + (d.x or 0) * 3.7) * 0.3
    -- 阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.88, ts * 0.2, ts * 0.05)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 25))
    nvgFill(nvg)
    -- 主干
    local trunkX = sx + ts * 0.5 + sway
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, trunkX - ts * 0.06, sy + ts * 0.3, ts * 0.12, ts * 0.55, ts * 0.06)
    nvgFillColor(nvg, nvgRGBA(60, 130, 50, 255))
    nvgFill(nvg)
    -- 主干高光
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, trunkX - ts * 0.02, sy + ts * 0.32, ts * 0.04, ts * 0.5, ts * 0.02)
    nvgFillColor(nvg, nvgRGBA(90, 165, 70, 120))
    nvgFill(nvg)
    -- 左臂
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, trunkX - ts * 0.06, sy + ts * 0.5)
    nvgLineTo(nvg, trunkX - ts * 0.2, sy + ts * 0.5)
    nvgLineTo(nvg, trunkX - ts * 0.2, sy + ts * 0.35)
    nvgLineTo(nvg, trunkX - ts * 0.1, sy + ts * 0.35)
    nvgLineTo(nvg, trunkX - ts * 0.1, sy + ts * 0.45)
    nvgLineTo(nvg, trunkX - ts * 0.06, sy + ts * 0.45)
    nvgFillColor(nvg, nvgRGBA(55, 125, 45, 255))
    nvgFill(nvg)
    -- 右臂
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, trunkX + ts * 0.06, sy + ts * 0.55)
    nvgLineTo(nvg, trunkX + ts * 0.18, sy + ts * 0.55)
    nvgLineTo(nvg, trunkX + ts * 0.18, sy + ts * 0.42)
    nvgLineTo(nvg, trunkX + ts * 0.1, sy + ts * 0.42)
    nvgLineTo(nvg, trunkX + ts * 0.1, sy + ts * 0.5)
    nvgLineTo(nvg, trunkX + ts * 0.06, sy + ts * 0.5)
    nvgFillColor(nvg, nvgRGBA(55, 125, 45, 255))
    nvgFill(nvg)
    -- 刺（短线）
    local spines = CACTUS_SPINES
    nvgStrokeColor(nvg, nvgRGBA(80, 150, 60, 200))
    nvgStrokeWidth(nvg, 0.6)
    for _, s in ipairs(spines) do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, trunkX + ts * s[1] - ts * 0.03, sy + ts * s[2])
        nvgLineTo(nvg, trunkX + ts * s[1] + s[3], sy + ts * s[2] + s[4])
        nvgStroke(nvg)
    end
end

--- 枯灌木/风滚草 - 棕色干枝球
function M.RenderDeadBush(nvg, sx, sy, ts, d, time)
    local sway = math.sin(time * 1.2 + (d.x or 0) * 5.1) * 1.0
    -- 阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.85, ts * 0.22, ts * 0.06)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 18))
    nvgFill(nvg)
    -- 主体（椭圆形干枝团）
    local cx = sx + ts * 0.5 + sway * 0.3
    local cy = sy + ts * 0.6
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy, ts * 0.2, ts * 0.18)
    nvgFillColor(nvg, nvgRGBA(140, 110, 60, 180))
    nvgFill(nvg)
    -- 枝条（放射状短线）
    nvgStrokeColor(nvg, nvgRGBA(120, 90, 45, 200))
    nvgStrokeWidth(nvg, 0.8)
    local branches = DEAD_BUSH_BRANCHES
    for _, b in ipairs(branches) do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy)
        nvgLineTo(nvg, cx + ts * b[1] + sway * 0.2, cy + ts * b[2])
        nvgStroke(nvg)
    end
end

--- 小沙丘 - 弧形隆起 + 阴影
function M.RenderSandDune(nvg, sx, sy, ts, d)
    -- 阴影面（暗色弧形）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.1, sy + ts * 0.75)
    nvgQuadTo(nvg, sx + ts * 0.5, sy + ts * 0.35, sx + ts * 0.9, sy + ts * 0.7)
    nvgLineTo(nvg, sx + ts * 0.9, sy + ts * 0.8)
    nvgQuadTo(nvg, sx + ts * 0.5, sy + ts * 0.55, sx + ts * 0.1, sy + ts * 0.8)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(180, 155, 95, 100))
    nvgFill(nvg)
    -- 受光面（亮色弧形）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.1, sy + ts * 0.75)
    nvgQuadTo(nvg, sx + ts * 0.45, sy + ts * 0.4, sx + ts * 0.85, sy + ts * 0.72)
    nvgStrokeColor(nvg, nvgRGBA(235, 220, 175, 90))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    -- 风纹线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.2, sy + ts * 0.68)
    nvgQuadTo(nvg, sx + ts * 0.5, sy + ts * 0.52, sx + ts * 0.8, sy + ts * 0.66)
    nvgStrokeColor(nvg, nvgRGBA(220, 200, 150, 60))
    nvgStrokeWidth(nvg, 0.6)
    nvgStroke(nvg)
end

--- 棕榈树 - 弯曲树干 + 扇形叶冠
function M.RenderPalmTree(nvg, sx, sy, ts, d, time)
    local sway = math.sin(time * 0.7 + (d.x or 0) * 2.9) * 1.5
    -- 阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.55, sy + ts * 0.88, ts * 0.28, ts * 0.07)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 22))
    nvgFill(nvg)
    -- 树干（弯曲路径）
    local baseX = sx + ts * 0.5
    local baseY = sy + ts * 0.85
    local topX = baseX + ts * 0.08 + sway * 0.3
    local topY = sy + ts * 0.2
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, baseX - ts * 0.03, baseY)
    nvgQuadTo(nvg, baseX + ts * 0.12, sy + ts * 0.55, topX, topY)
    nvgStrokeColor(nvg, nvgRGBA(130, 100, 50, 255))
    nvgStrokeWidth(nvg, ts * 0.06)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
    -- 叶冠（6片叶子向外伸展）
    local leafColor = PALM_LEAF_COLOR
    local leafDarkColor = PALM_LEAF_DARK_COLOR
    local leaves = PALM_LEAVES
    for i, lf in ipairs(leaves) do
        local lx = topX + ts * lf[1] + sway * 0.4
        local ly = topY + ts * lf[2]
        local c = (i % 2 == 0) and leafDarkColor or leafColor
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, topX + sway * 0.2, topY)
        nvgQuadTo(nvg, topX + ts * lf[1] * 0.5 + sway * 0.3, ly - ts * 0.05, lx, ly + ts * 0.08)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], c[4]))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
end

--- 残破石柱 - 断裂柱体
function M.RenderBrokenPillar(nvg, sx, sy, ts, d)
    -- 阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.52, sy + ts * 0.87, ts * 0.18, ts * 0.05)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 20))
    nvgFill(nvg)
    -- 柱体（梯形）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.35, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.65, sy + ts * 0.85)
    nvgLineTo(nvg, sx + ts * 0.6, sy + ts * 0.4)
    nvgLineTo(nvg, sx + ts * 0.4, sy + ts * 0.4)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(150, 135, 110, 255))
    nvgFill(nvg)
    -- 断裂面（锯齿顶部）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.38, sy + ts * 0.4)
    nvgLineTo(nvg, sx + ts * 0.42, sy + ts * 0.35)
    nvgLineTo(nvg, sx + ts * 0.48, sy + ts * 0.42)
    nvgLineTo(nvg, sx + ts * 0.53, sy + ts * 0.33)
    nvgLineTo(nvg, sx + ts * 0.58, sy + ts * 0.38)
    nvgLineTo(nvg, sx + ts * 0.62, sy + ts * 0.4)
    nvgLineTo(nvg, sx + ts * 0.38, sy + ts * 0.4)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(135, 120, 95, 255))
    nvgFill(nvg)
    -- 裂纹
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + ts * 0.48, sy + ts * 0.5)
    nvgLineTo(nvg, sx + ts * 0.52, sy + ts * 0.7)
    nvgStrokeColor(nvg, nvgRGBA(100, 85, 65, 150))
    nvgStrokeWidth(nvg, 0.8)
    nvgStroke(nvg)
    -- 底座碎石
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx + ts * 0.3, sy + ts * 0.82, ts * 0.04)
    nvgCircle(nvg, sx + ts * 0.7, sy + ts * 0.8, ts * 0.03)
    nvgFillColor(nvg, nvgRGBA(140, 125, 100, 180))
    nvgFill(nvg)
end

--- 骷髅标记桩 - 木桩 + 骷髅
function M.RenderSkullMarker(nvg, sx, sy, ts, d)
    -- 阴影
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx + ts * 0.5, sy + ts * 0.88, ts * 0.12, ts * 0.04)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 20))
    nvgFill(nvg)
    -- 木桩
    nvgBeginPath(nvg)
    nvgRect(nvg, sx + ts * 0.46, sy + ts * 0.35, ts * 0.08, ts * 0.52)
    nvgFillColor(nvg, nvgRGBA(110, 80, 45, 255))
    nvgFill(nvg)
    -- 骷髅头（圆形）
    local skX = sx + ts * 0.5
    local skY = sy + ts * 0.28
    nvgBeginPath(nvg)
    nvgEllipse(nvg, skX, skY, ts * 0.1, ts * 0.09)
    nvgFillColor(nvg, nvgRGBA(230, 220, 200, 255))
    nvgFill(nvg)
    -- 眼窝
    nvgBeginPath(nvg)
    nvgCircle(nvg, skX - ts * 0.04, skY - ts * 0.01, ts * 0.025)
    nvgCircle(nvg, skX + ts * 0.04, skY - ts * 0.01, ts * 0.025)
    nvgFillColor(nvg, nvgRGBA(40, 30, 20, 255))
    nvgFill(nvg)
    -- 鼻孔
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, skX, skY + ts * 0.02)
    nvgLineTo(nvg, skX - ts * 0.015, skY + ts * 0.04)
    nvgLineTo(nvg, skX + ts * 0.015, skY + ts * 0.04)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(40, 30, 20, 220))
    nvgFill(nvg)
end

return M
