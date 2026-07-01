-- ============================================================================
-- effects/skills_b.lua - 技能特效渲染器 B（御剑护体/剑阵/浩然正气/青云镇压/山拳/地涌/血爆/龙息/魂爆）
-- ============================================================================

local shared = require("rendering.effects.shared")
local assets = require("rendering.effects.assets")

local GameState = shared.GameState
local CombatSystem = shared.CombatSystem
local SIGNS = shared.SIGNS

-- renderSoulBurst 所需的常量（与 skills_a 中的 renderBloodSlash 共用概念）
local BLOOD_SLASH_LOCAL_FACTORS = {
    {0,   -1},  -- 左近
    {1.0, -1},  -- 左远
    {1.0,  1},  -- 右远
    {0,    1},  -- 右近
}
local bloodSlashCorners = {{0,0},{0,0},{0,0},{0,0}}

local M = {}

local function renderSwordShield(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 御剑护体特效：瞬间剑环闪烁 + 格挡弧 ═══
    local shieldR = tileSize * 0.8 * expand
    -- 环形护盾闪烁
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, shieldR)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 内层光晕
    local innerPaint = nvgRadialGradient(nvg, sx, sy, shieldR * 0.3, shieldR,
        nvgRGBA(c[1], c[2], c[3], math.floor(60 * alpha)),
        nvgRGBA(c[1], c[2], c[3], 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, shieldR)
    nvgFillPaint(nvg, innerPaint)
    nvgFill(nvg)
    -- 三段防御弧（代表剑的格挡位置）
    for j = 0, 2 do
        local arcStart = j * math.pi * 2 / 3 + progress * math.pi * 2
        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, shieldR * 0.85, arcStart, arcStart + math.pi * 0.4, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(180, 220, 255, math.floor(180 * alpha)))
        nvgStrokeWidth(nvg, 3.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
    -- 剑影飞散粒子
    for j = 0, 5 do
        local pAngle = j * math.pi / 3 + progress * math.pi * 4
        local pDist = shieldR * (0.5 + 0.5 * progress)
        local px = sx + math.cos(pAngle) * pDist
        local py = sy + math.sin(pAngle) * pDist
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 2.0 * (1.0 - progress * 0.7))
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(160 * alpha)))
        nvgFill(nvg)
    end
    if se.effectVariant == "break_heal" then
        local healR = tileSize * (0.35 + 0.55 * progress) * expand
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, healR)
        nvgStrokeColor(nvg, nvgRGBA(90, 255, 130, math.floor(190 * alpha * (1.0 - progress * 0.35))))
        nvgStrokeWidth(nvg, 2.4)
        nvgStroke(nvg)
        local healPaint = nvgRadialGradient(nvg, sx, sy, 0, healR,
            nvgRGBA(80, 255, 120, math.floor(70 * alpha)),
            nvgRGBA(80, 255, 120, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, healR)
        nvgFillPaint(nvg, healPaint)
        nvgFill(nvg)
    end
end

local function renderSwordFormation(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    if se.effectVariant == "trigger_heal" then
        local ringR = tileSize * (0.45 + progress * 0.8) * expand
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, ringR)
        nvgStrokeColor(nvg, nvgRGBA(90, 255, 130, math.floor(220 * alpha * (1.0 - progress * 0.45))))
        nvgStrokeWidth(nvg, 3.0)
        nvgStroke(nvg)
        for j = 0, 2 do
            local arcAngle = progress * math.pi * 2 + j * math.pi * 2 / 3
            nvgBeginPath(nvg)
            nvgArc(nvg, sx, sy, ringR * 0.72, arcAngle, arcAngle + math.pi * 0.35, NVG_CW)
            nvgStrokeColor(nvg, nvgRGBA(160, 255, 180, math.floor(160 * alpha)))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end
        return
    end
    -- ═══ 一剑开天被动：巨剑PNG从上方劈落 + 冲击波（身前范围） ═══
    local radius = se.range * tileSize * expand
    local faceAngle = se.targetAngle or (se.facingRight and 0 or math.pi)
    -- 偏移中心到角色身前
    local offsetDist = se.range * tileSize * 1.0
    local cx = sx + math.cos(faceAngle) * offsetDist
    local cy = sy + math.sin(faceAngle) * offsetDist
    -- 巨剑下落动画（前25%砸下，节奏适中看得清）
    local dropProgress = math.min(1.0, progress / 0.25)
    local dropT = 1.0 - (1.0 - dropProgress) * (1.0 - dropProgress) * (1.0 - dropProgress)
    local giantImg = assets.GetGiantSwordImage(nvg)
    local swordW = tileSize * 1.5
    local swordH = tileSize * 2.6
    local swordAlpha = alpha * (progress < 0.25 and 1.0 or (1.0 - (progress - 0.25) / 0.75))
    -- 光柱（剑下落轨迹，下落期间显示）
    if dropProgress < 1.0 then
        local pillarH = tileSize * 6
        local pillarPaint = nvgLinearGradient(nvg,
            cx, cy - pillarH, cx, cy,
            nvgRGBA(c[1], c[2], c[3], 0),
            nvgRGBA(c[1], c[2], c[3], math.floor(160 * alpha)))
        nvgBeginPath(nvg)
        nvgRect(nvg, cx - 5, cy - pillarH, 10, pillarH)
        nvgFillPaint(nvg, pillarPaint)
        nvgFill(nvg)
    end
    -- 巨剑PNG下落（剑尖对齐落点cy）
    if giantImg then
        local dropOffsetY = swordH * 1.5 * (1.0 - dropT)
        local drawX = cx - swordW / 2
        local drawY = cy - swordH * 0.88 - dropOffsetY
        -- 外发光（additive blend）
        nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
        local glowW = swordW * 1.5
        local glowH = swordH * 1.5
        local glowX = cx - glowW / 2
        local glowY = drawY - (glowH - swordH) * 0.5
        local glowPaint = nvgImagePattern(nvg, glowX, glowY, glowW, glowH, 0, giantImg, 0.35 * swordAlpha)
        nvgBeginPath(nvg)
        nvgRect(nvg, glowX, glowY, glowW, glowH)
        nvgFillPaint(nvg, glowPaint)
        nvgFill(nvg)
        nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
        -- 剑身图片
        local imgPaint = nvgImagePattern(nvg, drawX, drawY, swordW, swordH, 0, giantImg, swordAlpha)
        nvgBeginPath(nvg)
        nvgRect(nvg, drawX, drawY, swordW, swordH)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
    end
    -- 落地冲击闪白
    if progress > 0.22 and progress < 0.38 then
        local flashT = (progress - 0.22) / 0.16
        local flashA = math.floor(100 * alpha * (1.0 - flashT))
        local flashR = radius * (0.3 + 0.7 * flashT)
        local flashPaint = nvgRadialGradient(nvg, cx, cy, 0, flashR,
            nvgRGBA(220, 240, 255, flashA),
            nvgRGBA(220, 240, 255, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, flashR)
        nvgFillPaint(nvg, flashPaint)
        nvgFill(nvg)
    end
    -- 冲击波（落地瞬间爆发）
    if progress > 0.23 then
        local waveProgress = math.min(1.0, (progress - 0.23) / 0.45)
        local waveT = 1.0 - (1.0 - waveProgress) * (1.0 - waveProgress) * (1.0 - waveProgress)
        local waveR1 = radius * (0.1 + 0.9 * waveT)
        local waveA1 = math.floor(240 * alpha * (1.0 - waveProgress * 0.85))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, waveR1)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveA1))
        nvgStrokeWidth(nvg, 5.0 * (1.0 - waveProgress * 0.4))
        nvgStroke(nvg)
        if waveProgress > 0.1 then
            local innerP = (waveProgress - 0.1) / 0.9
            local waveR2 = radius * (0.05 + 0.65 * innerP)
            local waveA2 = math.floor(180 * alpha * (1.0 - innerP))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, waveR2)
            nvgStrokeColor(nvg, nvgRGBA(200, 230, 255, waveA2))
            nvgStrokeWidth(nvg, 3.0 * (1.0 - innerP * 0.4))
            nvgStroke(nvg)
        end
        if waveProgress > 0.05 then
            local outerP = (waveProgress - 0.05) / 0.95
            local waveR3 = radius * (0.2 + 1.0 * outerP)
            local waveA3 = math.floor(100 * alpha * (1.0 - outerP))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, waveR3)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveA3))
            nvgStrokeWidth(nvg, 2.0 * (1.0 - outerP * 0.5))
            nvgStroke(nvg)
        end
        local fillA = math.floor(60 * alpha * (1.0 - waveProgress * 0.7))
        local fillPaint = nvgRadialGradient(nvg, cx, cy, radius * 0.05, radius * waveT,
            nvgRGBA(c[1], c[2], c[3], fillA),
            nvgRGBA(c[1], c[2], c[3], 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius * waveT)
        nvgFillPaint(nvg, fillPaint)
        nvgFill(nvg)
    end
end

local function renderHaoranZhengqi(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 浩然正气施法爆发特效：气旋冲击波 + 太极符 + 四维弧线 ═══
    local burstR = tileSize * 1.8 * expand

    -- ① 中心光晕（径向渐变，淡蓝色）
    local glowA = math.floor(120 * alpha * (1.0 - progress * 0.8))
    local glowPaint = nvgRadialGradient(nvg, sx, sy, burstR * 0.02, burstR * 0.5,
        nvgRGBA(c[1], c[2], c[3], glowA),
        nvgRGBA(c[1], c[2], c[3], 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, burstR * 0.5)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- ② 向外扩散的冲击波环（两道，错开时间）
    for j = 0, 1 do
        local waveP = math.min(1.0, (progress - j * 0.15) / 0.85)
        if waveP > 0 then
            local waveR = burstR * (0.1 + 0.9 * waveP)
            local waveA = math.floor(200 * alpha * (1.0 - waveP))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, waveR)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveA))
            nvgStrokeWidth(nvg, (3.0 - j) * (1.0 - waveP * 0.5))
            nvgStroke(nvg)
        end
    end

    -- ③ 中心旋转太极符（前70%时间显示，后30%淡出）
    local taijiAlpha = progress < 0.7 and alpha or (alpha * (1.0 - (progress - 0.7) / 0.3))
    local taijiR = burstR * 0.18 * expand
    local rotAngle = progress * math.pi * 4  -- 快速旋转
    nvgSave(nvg)
    nvgTranslate(nvg, sx, sy)
    nvgRotate(nvg, rotAngle)
    -- 阴鱼（深蓝半圆）
    nvgBeginPath(nvg)
    nvgArc(nvg, 0, 0, taijiR, math.pi * 0.5, math.pi * 1.5, NVG_CW)
    nvgArc(nvg, 0, -taijiR * 0.5, taijiR * 0.5, math.pi * 1.5, math.pi * 0.5, NVG_CCW)
    nvgArc(nvg, 0, taijiR * 0.5, taijiR * 0.5, math.pi * 1.5, math.pi * 0.5, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(30, 80, 160, math.floor(180 * taijiAlpha)))
    nvgFill(nvg)
    -- 阳鱼（亮青半圆）
    nvgBeginPath(nvg)
    nvgArc(nvg, 0, 0, taijiR, math.pi * 1.5, math.pi * 0.5, NVG_CW)
    nvgArc(nvg, 0, taijiR * 0.5, taijiR * 0.5, math.pi * 0.5, math.pi * 1.5, NVG_CCW)
    nvgArc(nvg, 0, -taijiR * 0.5, taijiR * 0.5, math.pi * 0.5, math.pi * 1.5, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(100, 220, 255, math.floor(180 * taijiAlpha)))
    nvgFill(nvg)
    -- 鱼眼
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, -taijiR * 0.5, taijiR * 0.12)
    nvgFillColor(nvg, nvgRGBA(100, 220, 255, math.floor(220 * taijiAlpha)))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, taijiR * 0.5, taijiR * 0.12)
    nvgFillColor(nvg, nvgRGBA(30, 80, 160, math.floor(220 * taijiAlpha)))
    nvgFill(nvg)
    nvgRestore(nvg)

    -- ④ 四条正气弧线（代表悟性/福缘/根骨/体魄四维属性）
    -- 从中心向外螺旋散出
    for j = 0, 3 do
        local arcP = math.min(1.0, progress / 0.8)  -- 在80%时间内完成扩散
        local burstAngle = j * math.pi * 0.5 + progress * math.pi * 3
        local arcR = burstR * (0.15 + 0.7 * arcP)
        local arcA = math.floor(180 * alpha * (1.0 - arcP * 0.6))
        -- 每条弧线微调色相（蓝→青→蓝白→淡紫）
        local cr = c[1] + j * 15
        local cg = c[2] + j * 10
        local cb = c[3] - j * 10
        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, arcR, burstAngle, burstAngle + math.pi * 0.35, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(cr, cg, cb, arcA))
        nvgStrokeWidth(nvg, 2.5 * (1.0 - arcP * 0.4))
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
end

local function renderQingyunSuppress(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
        -- ═══ 神塔镇压：宝塔凝现 → 炸裂扩散，2×2 区域重击 ═══
        -- 时间线: 0~30% 宝塔凝现(淡入+微放大)  30~40% 蓄力发光  40~100% 炸裂(碎片+冲击波+闪光)
        local zones = se.zones
        local zSize = se.zoneSize or 1.0
        if zones and #zones > 0 then
            local halfPx = zSize * tileSize * 0.5
            -- 计算 4 区域整体中心
            local cx, cy = 0, 0
            for zi = 1, #zones do
                cx = cx + zones[zi].x
                cy = cy + zones[zi].y
            end
            cx = cx / #zones
            cy = cy / #zones
            local tcx = (cx - camera.x) * tileSize + l.w / 2 + l.x
            local tcy = (cy - camera.y) * tileSize + l.h / 2 + l.y

            -- ① 2×2 完整正方形区域底框（翡翠绿，用外包围盒画一个大方形）
            local boxA
            if progress < 0.30 then
                boxA = math.floor(200 * alpha * (progress / 0.30))
            elseif progress < 0.45 then
                boxA = math.floor(255 * alpha)  -- 炸裂瞬间满亮
            else
                boxA = math.floor(255 * alpha * math.max(0, 1.0 - (progress - 0.45) / 0.55))
            end
            -- 计算 4 个区域的外包围盒（世界坐标 → 屏幕坐标）
            local minWX, minWY = zones[1].x, zones[1].y
            local maxWX, maxWY = zones[1].x, zones[1].y
            for zi = 2, #zones do
                if zones[zi].x < minWX then minWX = zones[zi].x end
                if zones[zi].y < minWY then minWY = zones[zi].y end
                if zones[zi].x > maxWX then maxWX = zones[zi].x end
                if zones[zi].y > maxWY then maxWY = zones[zi].y end
            end
            -- 外包围盒 = 最外区域中心 ± halfZone
            local rectX1 = (minWX - zSize * 0.5 - camera.x) * tileSize + l.w / 2 + l.x
            local rectY1 = (minWY - zSize * 0.5 - camera.y) * tileSize + l.h / 2 + l.y
            local rectX2 = (maxWX + zSize * 0.5 - camera.x) * tileSize + l.w / 2 + l.x
            local rectY2 = (maxWY + zSize * 0.5 - camera.y) * tileSize + l.h / 2 + l.y
            local rectW = rectX2 - rectX1
            local rectH = rectY2 - rectY1
            -- 半透明填充（一个完整大方形）
            nvgBeginPath(nvg)
            nvgRect(nvg, rectX1, rectY1, rectW, rectH)
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(boxA * 0.35)))
            nvgFill(nvg)
            -- 粗边框
            nvgBeginPath(nvg)
            nvgRect(nvg, rectX1, rectY1, rectW, rectH)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], boxA))
            nvgStrokeWidth(nvg, 3.5)
            nvgStroke(nvg)

            -- ② 宝塔凝现 + 蓄力 + 炸裂
            local towerImg = assets.GetEnergyTowerImage(nvg)
            local baseImgW = tileSize * 1.6
            local baseImgH = tileSize * 3.2
            if progress < 0.40 and towerImg then
                -- 凝现阶段(0~30%): 淡入 + 从0.7倍放大到1.0倍
                -- 蓄力阶段(30~40%): 全亮 + 微微缩放脉冲
                local towerA, scale
                if progress < 0.30 then
                    local t = progress / 0.30
                    towerA = alpha * t
                    scale = 0.7 + 0.3 * t
                else
                    local t = (progress - 0.30) / 0.10
                    towerA = alpha
                    scale = 1.0 + 0.08 * math.sin(t * math.pi * 2)  -- 脉冲
                end
                local imgW = baseImgW * scale
                local imgH = baseImgH * scale
                local drawX = tcx - imgW * 0.5
                local drawY = tcy - imgH * 0.75  -- 塔底部偏区域中心下方
                -- 加法混合辉光
                nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
                local glowW = imgW * 1.5
                local glowH = imgH * 1.5
                local glowX = tcx - glowW * 0.5
                local glowY = drawY - (glowH - imgH) * 0.3
                local glowA = 0.35 * towerA
                if progress >= 0.30 then
                    glowA = (0.35 + 0.3 * ((progress - 0.30) / 0.10)) * towerA  -- 蓄力时辉光增强
                end
                local glowPaint = nvgImagePattern(nvg, glowX, glowY, glowW, glowH, 0, towerImg, glowA)
                nvgBeginPath(nvg)
                nvgRect(nvg, glowX, glowY, glowW, glowH)
                nvgFillPaint(nvg, glowPaint)
                nvgFill(nvg)
                nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
                -- 塔身图片
                local imgPaint = nvgImagePattern(nvg, drawX, drawY, imgW, imgH, 0, towerImg, towerA)
                nvgBeginPath(nvg)
                nvgRect(nvg, drawX, drawY, imgW, imgH)
                nvgFillPaint(nvg, imgPaint)
                nvgFill(nvg)
            end

            -- ③ 炸裂阶段(40%~100%): 碎片四散 + 冲击波 + 中心白闪
            if progress >= 0.40 then
                local explP = math.min(1.0, (progress - 0.40) / 0.60)
                -- 中心白绿闪光（炸裂瞬间最强，快速衰减）
                local flashA = math.floor(255 * alpha * math.max(0, 1.0 - explP * 1.8))
                if flashA > 0 then
                    local flashR = tileSize * (0.6 + 1.2 * explP)
                    local flashPaint = nvgRadialGradient(nvg, tcx, tcy, flashR * 0.05, flashR,
                        nvgRGBA(230, 255, 240, flashA),
                        nvgRGBA(c[1], c[2], c[3], 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, tcx, tcy, flashR)
                    nvgFillPaint(nvg, flashPaint)
                    nvgFill(nvg)
                end
                -- 双层冲击波
                local shockR = tileSize * (0.3 + 2.0 * explP)
                local shockA = math.floor(200 * alpha * (1.0 - explP))
                nvgBeginPath(nvg)
                nvgCircle(nvg, tcx, tcy, shockR)
                nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], shockA))
                nvgStrokeWidth(nvg, 3.0 * (1.0 - explP * 0.5))
                nvgStroke(nvg)
                local innerR = shockR * 0.55
                local innerA = math.floor(140 * alpha * (1.0 - explP))
                nvgBeginPath(nvg)
                nvgCircle(nvg, tcx, tcy, innerR)
                nvgStrokeColor(nvg, nvgRGBA(180, 255, 200, innerA))
                nvgStrokeWidth(nvg, 2.0 * (1.0 - explP * 0.3))
                nvgStroke(nvg)
                -- 碎片四散（8 片塔身残片向外飞散）
                if towerImg and explP < 0.8 then
                    local fragA = alpha * math.max(0, 1.0 - explP / 0.8)
                    local fragSize = tileSize * 0.5 * (1.0 - explP * 0.4)
                    nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
                    for fi = 1, 8 do
                        local angle = (fi - 1) * (math.pi * 2 / 8) + 0.3  -- 均匀 8 方向
                        local dist = tileSize * (0.3 + 1.8 * explP)
                        local fx = tcx + math.cos(angle) * dist
                        local fy = tcy + math.sin(angle) * dist - tileSize * 0.3 * (1.0 - explP)  -- 带微上抛
                        local fPaint = nvgImagePattern(nvg, fx - fragSize * 0.5, fy - fragSize * 0.5,
                            fragSize, fragSize, angle, towerImg, 0.6 * fragA)
                        nvgBeginPath(nvg)
                        nvgRect(nvg, fx - fragSize * 0.5, fy - fragSize * 0.5, fragSize, fragSize)
                        nvgFillPaint(nvg, fPaint)
                        nvgFill(nvg)
                    end
                    nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
                end
            end
        end

    -- ═══ 镇岳：裂山拳 — 身前圆形地裂冲击 + 拳印（参考金刚掌偏移方式） ═══
end

local function renderMountainFist(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
        local cx, cy, hitRadius = shared.ResolveFrontCircleGeometry(se, sx, sy, baseAngle, tileSize)
        local enhanced = se.effectVariant == "yuanying_mountain_fist" or se.outerShockwaveScale ~= nil
        local sourceRadius = enhanced and math.max(tileSize * 0.35, hitRadius - tileSize * 0.5) or hitRadius
        local coreRadius = enhanced and shared.ResolveShrunkCoreRadius(sourceRadius, tileSize, 0.5) or hitRadius
        local radius = coreRadius * expand
        local earthR, earthG, earthB = enhanced and 161 or 174, enhanced and 55 or 62, enhanced and 28 or 31
        -- 底层圆形冲击波（暗红）
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius)
        local wavePaint = nvgRadialGradient(nvg, cx, cy, radius * 0.1, radius,
            nvgRGBA(earthR, earthG, earthB, math.floor(100 * alpha)),
            nvgRGBA(98, 34, 24, math.floor(20 * alpha)))
        nvgFillPaint(nvg, wavePaint)
        nvgFill(nvg)
        -- 冲击波边缘
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius)
        nvgStrokeColor(nvg, nvgRGBA(196, 69, 35, math.floor((enhanced and 148 or 132) * alpha)))
        nvgStrokeWidth(nvg, enhanced and 2.4 or 1.9)
        nvgStroke(nvg)
        -- 地裂纹（从中心向外辐射 6 条）
        for j = 0, 5 do
            local crackAngle = baseAngle + (j / 6) * math.pi * 2
            local crackStart = radius * 0.1
            local crackEnd = radius * (0.4 + 0.5 * progress)
            local x1 = cx + math.cos(crackAngle) * crackStart
            local y1 = cy + math.sin(crackAngle) * crackStart
            local x2 = cx + math.cos(crackAngle) * crackEnd
            local y2 = cy + math.sin(crackAngle) * crackEnd
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, x1, y1)
            nvgLineTo(nvg, x2, y2)
            nvgStrokeColor(nvg, nvgRGBA(186, 78, 33, math.floor((enhanced and 96 or 82) * alpha)))
            nvgStrokeWidth(nvg, enhanced and 1.5 or 1.3)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end
        -- 中心拳印圆
        local fistR = tileSize * (enhanced and 0.28 or 0.23) * expand
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, fistR)
        nvgFillColor(nvg, nvgRGBA(196, 69, 35, math.floor((enhanced and 124 or 108) * alpha)))
        nvgFill(nvg)

        if enhanced then
            local delay = se.outerShockwaveDelay or 0
            if progress >= delay then
                local shockP = math.min(1.0, (progress - delay) / math.max(0.01, 1.0 - delay))
                local shockR = shared.ResolveOneTileSpreadRadius(radius, tileSize, shockP, hitRadius)
                local shockA = math.floor((60 + 140 * shockP) * alpha)

                local shockPaint = nvgRadialGradient(nvg, cx, cy, math.max(radius * 0.9, shockR - tileSize * 0.35), shockR,
                    nvgRGBA(186, 78, 33, math.floor((20 + 80 * shockP) * alpha)),
                    nvgRGBA(112, 38, 24, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, shockR)
                nvgFillPaint(nvg, shockPaint)
                nvgFill(nvg)

                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, shockR)
                nvgStrokeColor(nvg, nvgRGBA(202, 74, 36, shockA))
                nvgStrokeWidth(nvg, 2.2 + 2.0 * shockP)
                nvgStroke(nvg)

                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, hitRadius)
                nvgStrokeColor(nvg, nvgRGBA(220, 116, 59, math.floor((32 + 56 * shockP) * alpha)))
                nvgStrokeWidth(nvg, 0.9 + 0.8 * shockP)
                nvgStroke(nvg)

                for j = 0, 7 do
                    local crackAngle = baseAngle + (j / 8) * math.pi * 2 + shockP * 0.12
                    local r1 = radius * (0.78 + 0.08 * shockP)
                    local r2 = shockR * (0.90 + 0.06 * progress)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx + math.cos(crackAngle) * r1, cy + math.sin(crackAngle) * r1)
                    nvgLineTo(nvg, cx + math.cos(crackAngle) * r2, cy + math.sin(crackAngle) * r2)
                    nvgStrokeColor(nvg, nvgRGBA(202, 74, 36, math.floor((38 + 62 * shockP) * alpha)))
                    nvgStrokeWidth(nvg, 0.9 + 0.8 * shockP)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end
            end
            local bloodR = tileSize * (0.35 + 0.45 * progress) * expand
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, bloodR)
            nvgStrokeColor(nvg, nvgRGBA(128, 29, 23, math.floor(76 * alpha * (1.0 - progress * 0.35))))
            nvgStrokeWidth(nvg, 1.4)
            nvgStroke(nvg)
        end

    -- ═══ 镇岳：地涌推波 — 前方近身矩形推波 + 翠绿冲击 ═══
end

local function renderEarthSurge(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
        local rectLen = (se.rectLength or 2.0) * tileSize * expand
        local rectW = (se.rectWidth or 1.5) * tileSize * expand
        local halfW = rectW / 2
        local cosA = math.cos(baseAngle)
        local sinA = math.sin(baseAngle)
        -- 推波起点：紧贴玩家身前
        local ox, oy = sx, sy
        if se.centerOffset then
            local offVal = se.centerOffset
            if offVal == true then offVal = 0.5 end
            local offDist = offVal * tileSize * expand
            ox = sx + cosA * offDist
            oy = sy + sinA * offDist
        end

        -- ── 核心参数：波头/波尾推进（progress 0→1 对应 1 秒） ──
        -- 波头位置：匀速从起点推到远端
        local headFrac = math.min(progress * 1.15, 1.0)
        -- 波尾位置：延迟更久、追赶更慢 → 尾流更长
        local tailFrac = math.max(0, (progress - 0.35) * 1.1)
        tailFrac = math.min(tailFrac, 1.0)
        -- 当前波段长度（波头-波尾）
        local bandLen = headFrac - tailFrac
        if bandLen <= 0 then goto continue_es end
        -- 宽度渐展（前 15% 时间从窄到满宽）
        local widthFrac = math.min(progress * 6.5, 1.0)
        local curHalfW = halfW * widthFrac

        -- ── 波段矩形填充（从 tailFrac 到 headFrac） ──
        local tailX = ox + rectLen * tailFrac * cosA
        local tailY = oy + rectLen * tailFrac * sinA
        local headX = ox + rectLen * headFrac * cosA
        local headY = oy + rectLen * headFrac * sinA
        local perpX = -sinA * curHalfW
        local perpY = cosA * curHalfW
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, tailX - perpX, tailY - perpY)
        nvgLineTo(nvg, headX - perpX, headY - perpY)
        nvgLineTo(nvg, headX + perpX, headY + perpY)
        nvgLineTo(nvg, tailX + perpX, tailY + perpY)
        nvgClosePath(nvg)
        -- 渐变：从波尾到波头颜色加深
        local fillPaint = nvgLinearGradient(nvg,
            tailX, tailY, headX, headY,
            nvgRGBA(c[1], c[2], c[3], math.floor(30 * alpha)),
            nvgRGBA(c[1], c[2], c[3], math.floor(120 * alpha)))
        nvgFillPaint(nvg, fillPaint)
        nvgFill(nvg)

        -- ── 波头高亮线（最亮的前沿，加粗） ──
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, headX - perpX, headY - perpY)
        nvgLineTo(nvg, headX + perpX, headY + perpY)
        nvgStrokeColor(nvg, nvgRGBA(200, 255, 200, math.floor(255 * alpha)))
        nvgStrokeWidth(nvg, 4.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
        -- 波头外侧光晕（加大范围）
        local glowX = headX + cosA * 4
        local glowY = headY + sinA * 4
        local glowPaint = nvgRadialGradient(nvg, glowX, glowY, 0, curHalfW * 0.85,
            nvgRGBA(180, 255, 180, math.floor(80 * alpha)),
            nvgRGBA(180, 255, 180, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, glowX, glowY, curHalfW * 0.85)
        nvgFillPaint(nvg, glowPaint)
        nvgFill(nvg)

        -- ── 波段边框 ──
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, tailX - perpX, tailY - perpY)
        nvgLineTo(nvg, headX - perpX, headY - perpY)
        nvgLineTo(nvg, headX + perpX, headY + perpY)
        nvgLineTo(nvg, tailX + perpX, tailY + perpY)
        nvgClosePath(nvg)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(180 * alpha)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- ── 横向波纹（跟随波段向前推进，增加到8条） ──
        for j = 1, 8 do
            local wFrac = tailFrac + bandLen * (j / 9)
            local waveX = ox + rectLen * wFrac * cosA
            local waveY = oy + rectLen * wFrac * sinA
            local waveIntensity = 1.0 - math.abs(wFrac - headFrac) / math.max(bandLen, 0.01)
            local waveAlpha = math.floor(160 * waveIntensity * alpha)
            if waveAlpha > 5 then
                local wW = curHalfW * 0.9
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, waveX - wW * (-sinA), waveY - wW * cosA)
                nvgLineTo(nvg, waveX + wW * (-sinA), waveY + wW * cosA)
                nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveAlpha))
                nvgStrokeWidth(nvg, 2.0)
                nvgLineCap(nvg, NVG_ROUND)
                nvgStroke(nvg)
            end
        end

        -- ── 治愈粒子（集中在波头附近，跟着推进） ──
        for j = 0, 9 do
            local pBase = headFrac - bandLen * 0.8 * (j / 10)
            if pBase < tailFrac then goto nextParticle end
            local fwd = rectLen * pBase
            local lat = curHalfW * 0.6 * math.sin(j * 2.1 + progress * 6)
            local px = ox + fwd * cosA - lat * sinA
            local py = oy + fwd * sinA + lat * cosA
            local pDist = (pBase - tailFrac) / math.max(bandLen, 0.01)
            local pA = math.floor(200 * alpha * pDist)
            if pA > 5 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, 2.5 + 1.5 * pDist)
                nvgFillColor(nvg, nvgRGBA(180, 255, 180, pA))
                nvgFill(nvg)
            end
            ::nextParticle::
        end
        ::continue_es::

    -- ═══ 镇岳：血爆 — 累计触发大爆发 ═══
end

local function renderBloodExplosion(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 镇岳血神：能量血神头颅凝现 → 爆裂（图片素材版） ═══
    -- 时间线: 0~25% 头颅凝现  25~45% 蓄力脉动  45~65% 爆发  65~100% 余波
    local radius = se.range * tileSize * expand
    local skullImg = assets.GetBloodSkullImage(nvg)
    local baseSize = tileSize * 1.8  -- 头颅基准尺寸（正方形）
    if progress < 0.25 then

        -- ── 阶段1: 血神头颅凝现（从下方淡入上浮） ──
        local riseP = progress / 0.25
        local riseEase = riseP * riseP * (3 - 2 * riseP)
        local skullA = alpha * riseEase
        local scale = 0.5 + 0.5 * riseEase
        local offsetY = tileSize * 1.2 * (1.0 - riseEase) -- 从下方升起
        -- 脚底血池
        local poolR = tileSize * 0.5 * (0.4 + 0.6 * riseEase)
        nvgBeginPath(nvg)
        nvgEllipse(nvg, sx, sy + tileSize * 0.2, poolR, poolR * 0.3)
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(100 * skullA)))
        nvgFill(nvg)
        -- 头颅图片
        if skullImg then
            local imgS = baseSize * scale
            local drawX = sx - imgS * 0.5
            local drawY = sy - tileSize * 1.5 - imgS * 0.5 + offsetY
            -- 加法混合辉光
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local glowS = imgS * 1.4
            local glowPaint = nvgImagePattern(nvg, sx - glowS * 0.5, drawY - (glowS - imgS) * 0.3, glowS, glowS, 0, skullImg, 0.25 * skullA)
            nvgBeginPath(nvg)
            nvgRect(nvg, sx - glowS * 0.5, drawY - (glowS - imgS) * 0.3, glowS, glowS)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
            local imgPaint = nvgImagePattern(nvg, drawX, drawY, imgS, imgS, 0, skullImg, skullA)
            nvgBeginPath(nvg)
            nvgRect(nvg, drawX, drawY, imgS, imgS)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
        end
        -- 上升血气粒子
        for j = 0, 4 do
            local pRise = math.fmod(riseP * 2 + j * 0.2, 1.0)
            local px = sx + (j - 2) * tileSize * 0.15
            local py = sy - tileSize * 0.5 * pRise + offsetY * 0.5
            local pA = math.floor(140 * alpha * (1.0 - pRise))
            if pA > 10 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, 2.0)
                nvgFillColor(nvg, nvgRGBA(255, 60, 30, pA))
                nvgFill(nvg)
            end
        end
    elseif progress < 0.45 then

        -- ── 阶段2: 蓄力脉动（头颅悬浮，辉光增强，能量环收缩） ──
        local chargeP = (progress - 0.25) / 0.20
        local pulseA = math.sin(chargeP * math.pi * 5) * 0.25 + 0.75
        local skullA = alpha * pulseA
        if skullImg then
            local scale = 1.0 + 0.06 * math.sin(chargeP * math.pi * 3)
            local imgS = baseSize * scale
            local drawX = sx - imgS * 0.5
            local drawY = sy - tileSize * 1.5 - imgS * 0.5
            -- 辉光增强
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local glowS = imgS * (1.4 + 0.3 * chargeP)
            local glowA = (0.3 + 0.35 * chargeP) * skullA
            local glowPaint = nvgImagePattern(nvg, sx - glowS * 0.5, drawY - (glowS - imgS) * 0.3, glowS, glowS, 0, skullImg, glowA)
            nvgBeginPath(nvg)
            nvgRect(nvg, sx - glowS * 0.5, drawY - (glowS - imgS) * 0.3, glowS, glowS)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
            local imgPaint = nvgImagePattern(nvg, drawX, drawY, imgS, imgS, 0, skullImg, skullA)
            nvgBeginPath(nvg)
            nvgRect(nvg, drawX, drawY, imgS, imgS)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
        end
        -- 能量收缩环
        for j = 0, 2 do
            local ringP = math.fmod(chargeP * 3 + j * 0.33, 1.0)
            local ringR = radius * (1.0 - ringP * 0.7)
            local ringA = math.floor(160 * alpha * ringP)
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, ringR)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], ringA))
            nvgStrokeWidth(nvg, 2.0 * ringP)
            nvgStroke(nvg)
        end
    elseif progress < 0.65 then

        -- ── 阶段3: 爆发（头颅放大炸裂 + 冲击波） ──
        local burstP = (progress - 0.45) / 0.20
        local burstEase = 1.0 - (1.0 - burstP) * (1.0 - burstP)
        -- 中心闪光
        local flashA = math.floor(255 * alpha * math.max(0, 1.0 - burstP * 2.5))
        if flashA > 0 then
            local flashPaint = nvgRadialGradient(nvg, sx, sy - tileSize * 0.8, 0, tileSize,
                nvgRGBA(255, 200, 180, flashA),
                nvgRGBA(255, 80, 40, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy - tileSize * 0.8, tileSize)
            nvgFillPaint(nvg, flashPaint)
            nvgFill(nvg)
        end
        -- 头颅快速放大并消散
        if skullImg and burstP < 0.5 then
            local scale = 1.0 + 2.0 * burstP
            local skullFade = 1.0 - burstP * 2.0
            local imgS = baseSize * scale
            local drawX = sx - imgS * 0.5
            local drawY = sy - tileSize * 1.5 - imgS * 0.5
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local imgPaint = nvgImagePattern(nvg, drawX, drawY, imgS, imgS, 0, skullImg, alpha * skullFade * 0.6)
            nvgBeginPath(nvg)
            nvgRect(nvg, drawX, drawY, imgS, imgS)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
        end
        -- 冲击波环
        for j = 0, 1 do
            local waveP = math.min(1.0, (burstP - j * 0.1) / 0.9)
            if waveP > 0 then
                local waveR = radius * (0.1 + 0.9 * waveP)
                local waveA = math.floor(240 * alpha * (1.0 - waveP))
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, waveR)
                nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveA))
                nvgStrokeWidth(nvg, (4.0 - j * 1.5) * (1.0 - waveP * 0.5))
                nvgStroke(nvg)
            end
        end
        -- 爆发填充
        local fillR = radius * burstEase
        local fillA = math.floor(100 * alpha * (1.0 - burstP * 0.7))
        local fillPaint = nvgRadialGradient(nvg, sx, sy, fillR * 0.05, fillR,
            nvgRGBA(c[1], c[2], c[3], fillA),
            nvgRGBA(c[1], c[2], c[3], 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, fillR)
        nvgFillPaint(nvg, fillPaint)
        nvgFill(nvg)
    else

        -- ── 阶段4: 余波（血雾消散） ──
        local fadeP = (progress - 0.65) / 0.35
        -- 扩散血雾
        local mistR = radius * (0.8 + 0.3 * fadeP)
        local mistA = math.floor(50 * alpha * (1.0 - fadeP))
        local mistPaint = nvgRadialGradient(nvg, sx, sy, mistR * 0.1, mistR,
            nvgRGBA(c[1], c[2], c[3], mistA),
            nvgRGBA(c[1], c[2], c[3], 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, mistR)
        nvgFillPaint(nvg, mistPaint)
        nvgFill(nvg)
        -- 血雾粒子飘散
        for j = 0, 7 do
            local pAngle = (j / 8) * math.pi * 2 + fadeP * 0.5
            local pDist = radius * (0.3 + 0.6 * fadeP) + tileSize * 0.15 * math.sin(j * 1.5)
            local px = sx + math.cos(pAngle) * pDist
            local py = sy + math.sin(pAngle) * pDist - tileSize * 0.25 * fadeP
            local pA = math.floor(120 * alpha * (1.0 - fadeP))
            if pA > 10 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, 2.0 * (1.0 - fadeP * 0.4))
                nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], pA))
                nvgFill(nvg)
            end
        end
        -- 淡出涟漪环
        local rippleR = radius * (0.5 + 0.5 * fadeP)
        local rippleA = math.floor(70 * alpha * (1.0 - fadeP))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, rippleR)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], rippleA))
        nvgStrokeWidth(nvg, 1.5 * (1.0 - fadeP))
        nvgStroke(nvg)
    end
end

local function renderDragonBreath(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 龙息特效：90度前方扇面 + 金色龙火 + 火焰粒子 ═══
    local radius = se.range * tileSize * expand
    local halfAngle = math.rad((se.coneAngle or 90) / 2)
    local faceAngle = se.targetAngle or (se.facingRight and 0 or math.pi)
    -- 金色龙火扇面填充
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy)
    nvgArc(nvg, sx, sy, radius, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
    nvgClosePath(nvg)
    local firePaint = nvgRadialGradient(nvg, sx, sy, radius * 0.05, radius,
        nvgRGBA(255, 220, 80, math.floor(120 * alpha)),
        nvgRGBA(200, 120, 20, math.floor(25 * alpha)))
    nvgFillPaint(nvg, firePaint)
    nvgFill(nvg)
    -- 扇面内层高亮（接近中心更亮）
    local innerR = radius * 0.55
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy)
    nvgArc(nvg, sx, sy, innerR, faceAngle - halfAngle * 0.8, faceAngle + halfAngle * 0.8, NVG_CW)
    nvgClosePath(nvg)
    local innerPaint = nvgRadialGradient(nvg, sx, sy, radius * 0.02, innerR,
        nvgRGBA(255, 255, 200, math.floor(100 * alpha)),
        nvgRGBA(255, 200, 50, math.floor(10 * alpha)))
    nvgFillPaint(nvg, innerPaint)
    nvgFill(nvg)
    -- 扇面边缘描边（金色）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy)
    nvgArc(nvg, sx, sy, radius, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(255, 200, 50, math.floor(220 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 龙火涟漪（3 圈扇形弧从中心向外扩散）
    for j = 0, 2 do
        local rippleP = math.fmod(progress + j * 0.33, 1.0)
        local rippleR = radius * (0.15 + 0.85 * rippleP)
        local rippleA = math.floor(180 * (1.0 - rippleP) * alpha)
        if rippleA > 0 then
            nvgBeginPath(nvg)
            nvgArc(nvg, sx, sy, rippleR, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
            nvgStrokeColor(nvg, nvgRGBA(255, 180, 30, rippleA))
            nvgStrokeWidth(nvg, 2.5 * (1.0 - rippleP * 0.5))
            nvgStroke(nvg)
        end
    end
    -- 火焰粒子（在扇面范围内飞散，金橙色）
    for j = 0, 9 do
        local particleAngle = faceAngle - halfAngle + (j / 9) * halfAngle * 2
        particleAngle = particleAngle + math.sin(progress * 4.0 + j * 1.2) * 0.12
        local dist = radius * (0.2 + 0.6 * math.fmod(progress * 2.5 + j * 0.1, 1.0))
        local px = sx + math.cos(particleAngle) * dist
        local py = sy + math.sin(particleAngle) * dist
        local pSize = 3.0 * (1.0 - progress * 0.4) * (0.7 + 0.3 * math.sin(j * 2.1))
        local flicker = math.floor(200 * alpha * (0.6 + 0.4 * math.sin(progress * 8 + j * 3)))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pSize)
        nvgFillColor(nvg, nvgRGBA(255, 180 + j * 5, 30, flicker))
        nvgFill(nvg)
    end
    -- 中心龙息喷射光束（沿扇面中线向外延伸）
    local beamLen = radius * 0.7 * expand
    local beamEndX = sx + math.cos(faceAngle) * beamLen
    local beamEndY = sy + math.sin(faceAngle) * beamLen
    local beamW = tileSize * 0.08
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy)
    nvgLineTo(nvg, beamEndX, beamEndY)
    nvgStrokeColor(nvg, nvgRGBA(255, 240, 150, math.floor(180 * alpha)))
    nvgStrokeWidth(nvg, beamW * (1.0 + 0.3 * math.sin(progress * 12)))
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
    -- 龙息外焰旋涡（两侧扇边弧线旋转）
    local swirlR = radius * 0.4 * expand
    nvgBeginPath(nvg)
    nvgArc(nvg, sx, sy, swirlR,
        faceAngle - halfAngle * 0.5 + progress * math.pi * 2.5,
        faceAngle + halfAngle * 0.5 + progress * math.pi * 2.5, NVG_CW)
    nvgStrokeColor(nvg, nvgRGBA(255, 160, 20, math.floor(160 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
end

local function renderSoulBurst(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 噬魂AOE特效：紫色矩形区域 + 魂气横斩线 + 吸血回流 ═══
    local rectLen = (se.rectLength or 2.0) * tileSize * expand
    local rectW = (se.rectWidth or 1.0) * tileSize * expand
    local halfW = rectW / 2
    local cosA = math.cos(baseAngle)
    local sinA = math.sin(baseAngle)
    -- 矩形四角（复用伏魔刀的 BLOOD_SLASH_LOCAL_FACTORS）
    for ci = 1, 4 do
        local fac = BLOOD_SLASH_LOCAL_FACTORS[ci]
        local lx = fac[1] * rectLen
        local ly = fac[2] * halfW
        bloodSlashCorners[ci][1] = sx + lx * cosA - ly * sinA
        bloodSlashCorners[ci][2] = sy + lx * sinA + ly * cosA
    end
    -- 矩形填充（暗紫半透明）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bloodSlashCorners[1][1], bloodSlashCorners[1][2])
    for j = 2, 4 do
        nvgLineTo(nvg, bloodSlashCorners[j][1], bloodSlashCorners[j][2])
    end
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(80 * alpha)))
    nvgFill(nvg)
    -- 矩形边框（紫色）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bloodSlashCorners[1][1], bloodSlashCorners[1][2])
    for j = 2, 4 do
        nvgLineTo(nvg, bloodSlashCorners[j][1], bloodSlashCorners[j][2])
    end
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(220 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 魂气横斩线（3条，紫色调）
    for j = 1, 3 do
        local frac = j * 0.25
        local lx = sx + rectLen * frac * cosA
        local ly = sy + rectLen * frac * sinA
        local lx1 = lx - halfW * 0.85 * (-sinA)
        local ly1 = ly - halfW * 0.85 * cosA
        local lx2 = lx + halfW * 0.85 * (-sinA)
        local ly2 = ly + halfW * 0.85 * cosA
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx1, ly1)
        nvgLineTo(nvg, lx2, ly2)
        nvgStrokeColor(nvg, nvgRGBA(180, 100, 255, math.floor((150 - j * 20) * alpha)))
        nvgStrokeWidth(nvg, 2.0)
        nvgStroke(nvg)
    end
end

-- 导出部分注册表
M.registry = {
    ["sword_shield"] = renderSwordShield,
    ["sword_formation"] = renderSwordFormation,
    ["haoran_zhengqi"] = renderHaoranZhengqi,
    ["qingyun_suppress"] = renderQingyunSuppress,
    ["mountain_fist"] = renderMountainFist,
    ["earth_surge"] = renderEarthSurge,
    ["blood_explosion"] = renderBloodExplosion,
    ["dragon_breath"] = renderDragonBreath,
    ["soul_burst"] = renderSoulBurst,
}

return M
