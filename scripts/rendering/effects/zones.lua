-- ============================================================================
-- effects/zones.lua - 区域效果渲染（领域/怪物预警/正气结界）
-- ============================================================================

local shared = require("rendering.effects.shared")

local CombatSystem = shared.CombatSystem
local SIGNS = shared.SIGNS

local M = {}

local function DrawWanSymbol(nvg, sx, sy, size, alpha, elapsed)
    local s = size
    local strokeA = math.floor(255 * alpha)
    local glowA = math.floor(95 * alpha)

    nvgSave(nvg)
    nvgTranslate(nvg, sx, sy)
    nvgRotate(nvg, math.sin(elapsed * 1.2) * 0.04)

    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, 0, s * 0.72)
    local sealPaint = nvgRadialGradient(nvg, 0, 0, s * 0.10, s * 0.72,
        nvgRGBA(255, 246, 180, glowA),
        nvgRGBA(230, 170, 70, 0))
    nvgFillPaint(nvg, sealPaint)
    nvgFill(nvg)

    local function arm(x1, y1, x2, y2, x3, y3)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1 * s, y1 * s)
        nvgLineTo(nvg, x2 * s, y2 * s)
        nvgLineTo(nvg, x3 * s, y3 * s)
        nvgStrokeColor(nvg, nvgRGBA(90, 64, 26, math.floor(95 * alpha)))
        nvgStrokeWidth(nvg, math.max(3.0, s * 0.13))
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1 * s, y1 * s)
        nvgLineTo(nvg, x2 * s, y2 * s)
        nvgLineTo(nvg, x3 * s, y3 * s)
        nvgStrokeColor(nvg, nvgRGBA(255, 238, 135, strokeA))
        nvgStrokeWidth(nvg, math.max(2.0, s * 0.085))
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end

    -- 佛门万字符号（矢量绘制，避免字体缺字导致中心为空）
    arm(-0.10, 0.00, -0.58, 0.00, -0.58, -0.36)
    arm(0.10, 0.00, 0.58, 0.00, 0.58, 0.36)
    arm(0.00, -0.10, 0.00, -0.58, 0.36, -0.58)
    arm(0.00, 0.10, 0.00, 0.58, -0.36, 0.58)

    nvgRestore(nvg)
end

local function RenderMonkSealZone(nvg, zone, sx, sy, radius, c, alpha, elapsed)
    local pulse = 0.82 + 0.12 * math.sin(elapsed * math.pi * 4)
    local goldA = math.floor(125 * alpha * pulse)

    local fillPaint = nvgRadialGradient(nvg, sx, sy, radius * 0.05, radius,
        nvgRGBA(205, 174, 82, math.floor(42 * alpha)),
        nvgRGBA(150, 104, 42, math.floor(10 * alpha)))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgFillPaint(nvg, fillPaint)
    nvgFill(nvg)

    for j = 0, 1 do
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, radius * (0.72 + j * 0.22))
        nvgStrokeColor(nvg, nvgRGBA(214, 178, 82, math.floor(goldA * (j == 0 and 0.58 or 0.82))))
        nvgStrokeWidth(nvg, j == 0 and 1.5 or 2.2)
        nvgStroke(nvg)
    end

    for j = 0, 7 do
        local a = elapsed * 0.35 + j * math.pi * 2 / 8
        local r1 = radius * 0.24
        local r2 = radius * 0.86
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + math.cos(a) * r1, sy + math.sin(a) * r1)
        nvgLineTo(nvg, sx + math.cos(a) * r2, sy + math.sin(a) * r2)
        nvgStrokeColor(nvg, nvgRGBA(206, 176, 92, math.floor(30 * alpha)))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)
    end

    local palmR = radius * 0.20
    nvgBeginPath(nvg)
    nvgEllipse(nvg, sx, sy + palmR * 0.1, palmR * 0.75, palmR)
    nvgFillColor(nvg, nvgRGBA(190, 155, 82, math.floor(38 * alpha)))
    nvgFill(nvg)

    DrawWanSymbol(nvg, sx, sy, radius * 0.30, alpha, elapsed)

    for j = 0, 5 do
        local a = elapsed * 0.8 + j * math.pi * 2 / 6
        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, radius * 0.55, a, a + math.pi * 0.18, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(214, 186, 104, math.floor(64 * alpha)))
        nvgStrokeWidth(nvg, 1.2)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end

    local tickFrac = zone.tickInterval > 0 and (zone.tickTimer / zone.tickInterval) or 0
    if tickFrac > 0.85 then
        local tickPulse = (tickFrac - 0.85) / 0.15
        local flashColor = zone.tickFlashColor or c
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, radius * (0.85 + 0.2 * tickPulse))
        nvgStrokeColor(nvg, nvgRGBA(flashColor[1], flashColor[2], flashColor[3], math.floor((flashColor[4] or 180) * tickPulse * alpha)))
        nvgStrokeWidth(nvg, 3.0)
        nvgStroke(nvg)
    end
end

--- 渲染持续性地板区域效果（浩气领域/血海领域等）
function M.RenderZones(nvg, l, camera)
    local zones = CombatSystem.GetActiveZones()
    if #zones == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #zones do
        local zone = zones[i]

        if camera:IsVisible(zone.x, zone.y, l.w, l.h, 5) then
            local sx = (zone.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (zone.y - camera.y) * tileSize + l.h / 2 + l.y
            local radius = zone.range * tileSize
            local c = zone.color

            -- 生命周期进度（用于淡入淡出）
            local lifeProgress = 1.0 - (zone.remaining / zone.duration)
            local alpha = 1.0
            if lifeProgress < 0.1 then
                alpha = lifeProgress / 0.1  -- 淡入
            elseif zone.remaining < 1.0 then
                alpha = zone.remaining  -- 最后 1 秒淡出
            end

            -- 呼吸脉冲（区域持续期间的视觉反馈）
            local elapsed = zone.duration - zone.remaining
            local pulse = 0.7 + 0.3 * math.sin(elapsed * 2.5)

            if zone.zoneVisualKey == "monk_seal_zone" then
                RenderMonkSealZone(nvg, zone, sx, sy, radius, c, alpha, elapsed)
            else
                -- 地面圆形填充（半透明）
                local fillPaint = nvgRadialGradient(nvg, sx, sy, radius * 0.1, radius,
                    nvgRGBA(c[1], c[2], c[3], math.floor(60 * alpha * pulse)),
                    nvgRGBA(c[1], c[2], c[3], math.floor(15 * alpha)))
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, radius)
                nvgFillPaint(nvg, fillPaint)
                nvgFill(nvg)

                -- 边缘圆环（脉冲发光）
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, radius)
                nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(180 * alpha * pulse)))
                nvgStrokeWidth(nvg, 2.0)
                nvgStroke(nvg)

                -- 内圈旋转弧线（持续旋转动画）
                -- 增伤区域：弧线和闪烁缩小到脚底（0.15倍半径），其他区域正常
                local isDmgBoost = (zone.damageBoostPercent or 0) > 0
                local innerScale = isDmgBoost and 0.15 or 1.0
                local rotSpeed = elapsed * 1.5
                for j = 0, 2 do
                    local arcAngle = rotSpeed + j * math.pi * 2 / 3
                    local arcR = radius * innerScale * (0.5 + 0.15 * math.sin(elapsed * 3 + j))
                    nvgBeginPath(nvg)
                    nvgArc(nvg, sx, sy, arcR, arcAngle, arcAngle + math.pi * 0.4, NVG_CW)
                    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(120 * alpha)))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end

                -- Tick 闪烁（每次 tick 伤害/回血时短暂闪光）
                local tickFrac = zone.tickTimer / zone.tickInterval
                if tickFrac > 0.85 then
                    -- 接近下一次 tick 时脉冲加强
                    local tickPulse = (tickFrac - 0.85) / 0.15
                    local flashAlpha = math.floor(100 * tickPulse * alpha)
                    local flashR = isDmgBoost and (radius * 0.15) or (radius * 0.9)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, sx, sy, flashR)
                    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], flashAlpha))
                    nvgFill(nvg)
                end
            end

            -- 区域名称标签
            if zone.showZoneLabel ~= false then
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 12)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * alpha)))
                nvgText(nvg, sx, sy - radius - 4, zone.name, nil)
            end
        end
    end
end

--- 渲染怪物技能预警（圆形/扇形危险区域，脉冲闪烁）
function M.RenderMonsterWarnings(nvg, l, camera)
    local warnings = CombatSystem.monsterWarnings
    if #warnings == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #warnings do
        local w = warnings[i]

        if camera:IsVisible(w.x, w.y, l.w, l.h, 5) then
            -- 怪物屏幕坐标（预警中心）
            local sx = (w.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (w.y - camera.y) * tileSize + l.h / 2 + l.y

            local progress = w.elapsed / w.duration  -- 0→1 蓄力进度
            local c = w.color

            -- 脉冲闪烁：随蓄力进度加快（频率从2Hz到8Hz）
            local pulseFreq = 2.0 + progress * 6.0
            local pulse = 0.5 + 0.5 * math.sin(w.elapsed * pulseFreq * math.pi * 2)

            -- 基础透明度：随进度增强（蓄力越久越明显）
            local baseAlpha = 0.3 + progress * 0.5
            local alpha = baseAlpha * (0.6 + 0.4 * pulse)

            -- 范围扩展动画：前20%从0扩展到满
            local expand = 1.0
            if progress < 0.2 then
                local t = progress / 0.2
                expand = t * (2.0 - t)  -- easeOut
            end

            local radius = w.range * tileSize * expand

            if w.shape == "circle" then
                -- ═══ 场地技能：网格方块渲染 ═══
                if w.isFieldSkill and w.safeZones then
                    local safePulse = 0.5 + 0.5 * math.sin(w.elapsed * 4.0 * math.pi * 2 + math.pi)
                    local safeAlpha = 0.5 + 0.3 * safePulse

                    -- 构建安全格集合（复用模块级表+数值hash，避免每帧字符串分配）
                    if not M._safeSet then M._safeSet = {} end
                    local safeSet = M._safeSet
                    for k in pairs(safeSet) do safeSet[k] = nil end
                    for _, zone in ipairs(w.safeZones) do
                        safeSet[math.floor(zone.y) * 10000 + math.floor(zone.x)] = true
                    end

                    -- 遍历竞技场 6x6 格子
                    for gx = 2, 7 do
                        for gy = 2, 7 do
                            local cx = (gx + 0.5 - camera.x) * tileSize + l.w / 2 + l.x
                            local cy = (gy + 0.5 - camera.y) * tileSize + l.h / 2 + l.y
                            local halfTile = tileSize * 0.48 * expand

                            if safeSet[gy * 10000 + gx] then
                                -- 安全格：绿色方块
                                nvgBeginPath(nvg)
                                nvgRoundedRect(nvg, cx - halfTile, cy - halfTile, halfTile * 2, halfTile * 2, 3)
                                nvgFillColor(nvg, nvgRGBA(50, 220, 100, math.floor(120 * safeAlpha)))
                                nvgFill(nvg)

                                nvgBeginPath(nvg)
                                nvgRoundedRect(nvg, cx - halfTile, cy - halfTile, halfTile * 2, halfTile * 2, 3)
                                nvgStrokeColor(nvg, nvgRGBA(100, 255, 150, math.floor(220 * safeAlpha)))
                                nvgStrokeWidth(nvg, 2.0)
                                nvgStroke(nvg)
                            else
                                -- 危险格：技能色方块
                                nvgBeginPath(nvg)
                                nvgRoundedRect(nvg, cx - halfTile, cy - halfTile, halfTile * 2, halfTile * 2, 2)
                                nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(80 * alpha)))
                                nvgFill(nvg)
                            end
                        end
                    end

                    -- 收缩进度条（竞技场上方）
                    local barW = 6 * tileSize * expand
                    local barH = 4
                    local barX = (2.5 - camera.x) * tileSize + l.w / 2 + l.x - tileSize * 0.5
                    local barY = (1.5 - camera.y) * tileSize + l.h / 2 + l.y
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, barX, barY, barW * (1.0 - progress), barH, 2)
                    nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(180 * alpha)))
                    nvgFill(nvg)
                else
                    -- ═══ 普通圆形预警 ═══

                    -- 填充圆
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, sx, sy, radius)
                    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(c[4] * alpha)))
                    nvgFill(nvg)

                    -- 边缘圆环
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, sx, sy, radius)
                    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(220 * alpha)))
                    nvgStrokeWidth(nvg, 2.5)
                    nvgStroke(nvg)

                    -- 收缩圆环（进度指示）
                    local shrinkRadius = radius * (1.0 - progress)
                    if shrinkRadius > 2 then
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sx, sy, shrinkRadius)
                        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(150 * alpha)))
                        nvgStrokeWidth(nvg, 1.5)
                        nvgStroke(nvg)
                    end
                end

            elseif w.shape == "cone" then
                -- ═══ 扇形预警 ═══

                -- 计算朝向角度（怪物→目标）
                local dx = w.targetX - w.x
                local dy = w.targetY - w.y
                local angle = math.atan(dy, dx)
                local halfAngle = math.rad(w.coneAngle / 2)

                -- 扇形填充
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, sx, sy)
                nvgArc(nvg, sx, sy, radius, angle - halfAngle, angle + halfAngle, NVG_CW)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(c[4] * alpha)))
                nvgFill(nvg)

                -- 扇形边缘弧线
                nvgBeginPath(nvg)
                nvgArc(nvg, sx, sy, radius, angle - halfAngle, angle + halfAngle, NVG_CW)
                nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(220 * alpha)))
                nvgStrokeWidth(nvg, 2.5)
                nvgStroke(nvg)

                -- 两条边线
                for _, sign in ipairs(SIGNS) do
                    local edgeAngle = angle + sign * halfAngle
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, sx, sy)
                    nvgLineTo(nvg, sx + math.cos(edgeAngle) * radius, sy + math.sin(edgeAngle) * radius)
                    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(180 * alpha)))
                    nvgStrokeWidth(nvg, 2)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end

                -- 收缩弧线（进度指示）
                local shrinkR = radius * (1.0 - progress)
                if shrinkR > 2 then
                    nvgBeginPath(nvg)
                    nvgArc(nvg, sx, sy, shrinkR, angle - halfAngle, angle + halfAngle, NVG_CW)
                    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(120 * alpha)))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                end

            elseif w.shape == "cross" then
                -- ═══ 十字预警 ═══
                local armLen = w.range * tileSize * expand
                local halfW = (w.crossWidth or 0.8) * tileSize * expand / 2

                -- 水平臂
                nvgBeginPath(nvg)
                nvgRect(nvg, sx - armLen, sy - halfW, armLen * 2, halfW * 2)
                nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(c[4] * alpha)))
                nvgFill(nvg)
                -- 垂直臂
                nvgBeginPath(nvg)
                nvgRect(nvg, sx - halfW, sy - armLen, halfW * 2, armLen * 2)
                nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(c[4] * alpha)))
                nvgFill(nvg)

                -- 水平臂边框
                nvgBeginPath(nvg)
                nvgRect(nvg, sx - armLen, sy - halfW, armLen * 2, halfW * 2)
                nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(220 * alpha)))
                nvgStrokeWidth(nvg, 2)
                nvgStroke(nvg)
                -- 垂直臂边框
                nvgBeginPath(nvg)
                nvgRect(nvg, sx - halfW, sy - armLen, halfW * 2, armLen * 2)
                nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(220 * alpha)))
                nvgStrokeWidth(nvg, 2)
                nvgStroke(nvg)

                -- 收缩指示（中心十字缩小）
                local shrinkF = 1.0 - progress
                if shrinkF > 0.05 then
                    local sArmLen = armLen * shrinkF
                    local sHalfW = halfW * shrinkF
                    nvgBeginPath(nvg)
                    nvgRect(nvg, sx - sArmLen, sy - sHalfW, sArmLen * 2, sHalfW * 2)
                    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(120 * alpha)))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, sx - sHalfW, sy - sArmLen, sHalfW * 2, sArmLen * 2)
                    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(120 * alpha)))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                end

            elseif w.shape == "line" or w.shape == "rect" then
                -- ═══ 线性/矩形预警 ═══
                local dx = w.targetX - w.x
                local dy = w.targetY - w.y
                local angle = math.atan(dy, dx)

                local length, halfW
                if w.shape == "line" then
                    length = w.range * tileSize * expand
                    halfW = (w.lineWidth or 0.8) * tileSize * expand / 2
                else
                    length = (w.rectLength or 2.5) * tileSize * expand
                    halfW = (w.rectWidth or 1.2) * tileSize * expand / 2
                end

                -- 旋转绘制矩形
                nvgSave(nvg)
                nvgTranslate(nvg, sx, sy)
                nvgRotate(nvg, angle)

                -- 填充
                nvgBeginPath(nvg)
                nvgRect(nvg, 0, -halfW, length, halfW * 2)
                nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(c[4] * alpha)))
                nvgFill(nvg)

                -- 边框
                nvgBeginPath(nvg)
                nvgRect(nvg, 0, -halfW, length, halfW * 2)
                nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(220 * alpha)))
                nvgStrokeWidth(nvg, 2)
                nvgStroke(nvg)

                -- 收缩指示（从末端向起点收缩）
                local shrinkLen = length * (1.0 - progress)
                if shrinkLen > 2 then
                    nvgBeginPath(nvg)
                    nvgRect(nvg, length - shrinkLen, -halfW * 0.6, shrinkLen, halfW * 1.2)
                    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(120 * alpha)))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                end

                nvgRestore(nvg)
            end

            -- 技能名文字（预警区域上方）
            if w.skillName ~= "" then
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 14)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg, nvgRGBA(255, 200, 100, math.floor(220 * alpha)))
                nvgText(nvg, sx, sy - radius - 6, w.skillName, nil)
            end
        end
    end
end

--- 渲染正气结界区域
function M.RenderBarrierZones(nvg, l, camera)
    local zones = CombatSystem.GetBarrierZones()
    if #zones == 0 then return end

    local tileSize = camera:GetTileSize()
    -- 用于呼吸动画的时间累积（借用第一个 zone 的 tickTimer 近似）
    local time = zones[1].tickTimer or 0

    for i = 1, #zones do
        local zone = zones[i]

        if camera:IsVisible(zone.x, zone.y, l.w, l.h, 5) then
            local sx = (zone.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (zone.y - camera.y) * tileSize + l.h / 2 + l.y
            local radius = zone.radius * tileSize

            -- 呼吸脉冲
            local pulse = 0.7 + 0.3 * math.sin(time * 3.0 + i * 1.5)

            -- 地面圆形填充（金黄半透明）
            local fillPaint = nvgRadialGradient(nvg, sx, sy, radius * 0.1, radius,
                nvgRGBA(220, 180, 40, math.floor(70 * pulse)),
                nvgRGBA(180, 140, 20, 10))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, radius)
            nvgFillPaint(nvg, fillPaint)
            nvgFill(nvg)

            -- 外圈边框（金黄脉冲）
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, radius)
            nvgStrokeColor(nvg, nvgRGBA(240, 200, 50, math.floor(200 * pulse)))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)

            -- 内圈旋转弧线
            local rot = time * 2.0 + i * 2.0
            for j = 0, 2 do
                local arcAngle = rot + j * math.pi * 2 / 3
                nvgBeginPath(nvg)
                nvgArc(nvg, sx, sy, radius * 0.6, arcAngle, arcAngle + math.pi * 0.35, NVG_CW)
                nvgStrokeColor(nvg, nvgRGBA(255, 220, 80, math.floor(140 * pulse)))
                nvgStrokeWidth(nvg, 1.5)
                nvgLineCap(nvg, NVG_ROUND)
                nvgStroke(nvg)
            end

            -- 中心标记（结界符号）
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 11)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(nvg, nvgRGBA(255, 220, 80, math.floor(200 * pulse)))
            nvgText(nvg, sx, sy - radius - 3, "结界", nil)
        end
    end
end

--- 渲染渡劫场景预警（雷击圈 + 火场 + 安全区 + HUD 倒计时）
function M.RenderTribulationWarnings(nvg, l, camera)
    local okTS, TribulationScene = pcall(require, "systems.TribulationScene")
    if not okTS or not TribulationScene or not TribulationScene.IsActive() then return end

    local tileSize = camera:GetTileSize()
    local circles = TribulationScene.GetWarningCircles()

    for _, c in ipairs(circles) do
        local sx = (c.x - camera.x) * tileSize + l.w / 2 + l.x
        local sy = (c.y - camera.y) * tileSize + l.h / 2 + l.y
        local radius = c.radius * tileSize
        local col = c.color
        local progress = c.progress or 0

        if c.type == "lightning" then
            -- 雷击预警：蓝白色圆圈 + 脉冲
            local pulseFreq = 3.0 + progress * 8.0
            local pulse = 0.5 + 0.5 * math.sin(progress * pulseFreq * math.pi * 2)
            local alpha = (0.4 + progress * 0.6) * (0.6 + 0.4 * pulse)

            -- 填充
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, radius)
            nvgFillColor(nvg, nvgRGBA(col[1], col[2], col[3], math.floor((col[4] or 180) * alpha)))
            nvgFill(nvg)

            -- 边框
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, radius)
            nvgStrokeColor(nvg, nvgRGBA(200, 220, 255, math.floor(255 * alpha)))
            nvgStrokeWidth(nvg, 2.0)
            nvgStroke(nvg)

            -- 雷击符号
            if progress > 0.5 then
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 14)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(255 * alpha)))
                nvgText(nvg, sx, sy, "⚡", nil)
            end

        elseif c.type == "fire_field" then
            -- 全场火海：大红圈
            local pulse = 0.6 + 0.4 * math.sin(progress * 6.0 * math.pi)
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, radius)
            nvgFillColor(nvg, nvgRGBA(col[1], col[2], col[3], math.floor((col[4] or 120) * pulse)))
            nvgFill(nvg)

        elseif c.type == "safe_zone" then
            -- 安全区：绿色闪烁圈
            local pulse = 0.6 + 0.4 * math.sin(progress * 8.0 * math.pi)
            -- 填充
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, radius)
            nvgFillColor(nvg, nvgRGBA(col[1], col[2], col[3], math.floor((col[4] or 200) * 0.4 * pulse)))
            nvgFill(nvg)
            -- 边框
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, radius)
            nvgStrokeColor(nvg, nvgRGBA(col[1], col[2], col[3], math.floor((col[4] or 200) * pulse)))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
            -- 标记
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 12)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(50, 255, 100, math.floor(255 * pulse)))
            nvgText(nvg, sx, sy, "安全", nil)
        end
    end

    -- ── HUD 倒计时 ──
    local phase = TribulationScene.GetPhase()
    local hudText, hudColor
    if phase == "warmup" then
        local remaining = TribulationScene.GetWarmupRemaining()
        hudText = "准备... " .. math.ceil(remaining)
        hudColor = {255, 255, 200, 255}
    elseif phase == "combat" then
        local remaining = TribulationScene.GetTimeRemaining()
        hudText = "剩余 " .. math.ceil(remaining) .. " 秒"
        hudColor = remaining <= 10 and {255, 80, 80, 255} or {255, 220, 100, 255}
    elseif phase == "ending" then
        hudText = "渡劫成功！"
        hudColor = {100, 255, 150, 255}
    end

    if hudText then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 22)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(hudColor[1], hudColor[2], hudColor[3], hudColor[4]))
        nvgText(nvg, l.w / 2 + l.x, l.y + 20, hudText, nil)

        -- 副标题
        nvgFontSize(nvg, 13)
        nvgFillColor(nvg, nvgRGBA(200, 200, 200, 200))
        nvgText(nvg, l.w / 2 + l.x, l.y + 46, "— 雷火劫 —", nil)
    end
end

return M
