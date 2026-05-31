-- ============================================================================
-- effects/formations.lua - 剑阵降临特效（持续性电磁塔渲染）
-- ============================================================================

local shared = require("rendering.effects.shared")
local assets = require("rendering.effects.assets")

local GameState = shared.GameState

local M = {}

--- 剑阵降临：持续性电磁塔渲染（地面插剑 + 电弧连接目标）
function M.RenderSwordFormations(nvg, l, camera)
    local player = GameState.player
    if not player or not player._swordFormations then return end
    local formations = player._swordFormations
    if #formations == 0 then return end

    local tileSize = camera:GetTileSize()
    local time = GameState.gameTime or 0
    local swordImg = assets.GetLightningSwordImage(nvg)
    local swordW = tileSize * 0.62
    local swordH = tileSize * 1.24

    for i = 1, #formations do
        local sf = formations[i]
        if not camera:IsVisible(sf.x, sf.y, l.w, l.h, 3) then goto continue_sf end

        local sx = (sf.x - camera.x) * tileSize + l.w / 2 + l.x
        local sy = (sf.y - camera.y) * tileSize + l.h / 2 + l.y

        -- 生命周期
        local elapsed = sf.duration - sf.remaining  -- 已存活时间
        local spawnDur = 0.18                       -- 出现动画时长（快速砸地）
        local spawning = elapsed < spawnDur
        local spawnT = spawning and (elapsed / spawnDur) or 1.0  -- 0→1 出现进度

        local fadeAlpha = 1.0
        if spawning then
            fadeAlpha = spawnT
        elseif sf.remaining < 0.5 then
            fadeAlpha = sf.remaining / 0.5
        end

        nvgSave(nvg)

        -- ── 出现动画：落地冲击波（仅出现阶段） ──
        local rangeR = sf.range * tileSize
        if spawning then
            local ringProgress = spawnT

            -- ① 主冲击波（扩散到完整AOE范围）
            local impactR = rangeR * ringProgress
            local impactA = math.floor(255 * (1.0 - ringProgress) ^ 0.5)
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, impactR)
            nvgStrokeColor(nvg, nvgRGBA(180, 230, 255, impactA))
            nvgStrokeWidth(nvg, 5.0 * (1.0 - ringProgress * 0.3))
            nvgStroke(nvg)

            -- ② 第二层冲击波（稍慢、稍窄，延迟展开）
            local ring2T = math.max(0, (ringProgress - 0.15) / 0.85)
            if ring2T > 0 then
                local r2 = rangeR * 0.6 * ring2T
                local a2 = math.floor(180 * (1.0 - ring2T))
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, r2)
                nvgStrokeColor(nvg, nvgRGBA(140, 200, 255, a2))
                nvgStrokeWidth(nvg, 2.5 * (1.0 - ring2T * 0.5))
                nvgStroke(nvg)
            end

            -- ③ 落地中心闪光（additive blend，明亮白光）
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local flashIntensity = (1.0 - ringProgress) ^ 1.5
            local flashR = tileSize * 0.5 * (1.0 - ringProgress * 0.3)
            local flashPaint = nvgRadialGradient(nvg, sx, sy, 0, flashR,
                nvgRGBA(255, 255, 255, math.floor(255 * flashIntensity)),
                nvgRGBA(180, 220, 255, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, flashR)
            nvgFillPaint(nvg, flashPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)

        end

        -- ── 地面电场圆圈（淡蓝闪烁，出现后才显示） ──
        if not spawning then
            local flickerA = math.floor(30 * fadeAlpha * (0.5 + 0.5 * math.sin(time * 6 + i * 2)))
            local fieldPaint = nvgRadialGradient(nvg, sx, sy, rangeR * 0.15, rangeR,
                nvgRGBA(120, 180, 255, flickerA),
                nvgRGBA(120, 180, 255, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, rangeR)
            nvgFillPaint(nvg, fieldPaint)
            nvgFill(nvg)

            -- 范围描边
            local ringA = math.floor(60 * fadeAlpha * (0.4 + 0.6 * math.sin(time * 4 + i)))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, rangeR)
            nvgStrokeColor(nvg, nvgRGBA(100, 170, 255, ringA))
            nvgStrokeWidth(nvg, 1.0)
            nvgStroke(nvg)
        end

        -- ── 插地灵剑（PNG，剑尖朝下，插入地面姿态） ──
        -- 出现阶段：从高处加速坠落（三次方缓入，越来越快）；之后轻微悬浮
        local dropOffset = spawning and (tileSize * 2.5 * (1.0 - spawnT * spawnT * spawnT)) or 0
        local floatY = spawning and 0 or (math.sin(time * 3 + i * 1.5) * tileSize * 0.03)
        local swordCX = sx
        local swordTopY = sy - swordH + floatY - dropOffset  -- 出现时从高处落下
        local swordBotY = swordTopY + swordH

        if swordImg then
            -- 电剑贴图直接绘制（剑尖朝下，插地姿态，无需翻转）
            nvgSave(nvg)

            -- 外发光（同高度，横向扩散剑影）—— 刚落地时更亮
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local landingGlow = 1.0
            if elapsed < 0.6 then  -- 落地后0.25秒内额外发光渐弱
                landingGlow = 1.0 + 2.0 * math.max(0, 1.0 - (elapsed / 0.6))
            end
            local glowW = swordW * 2.0 * math.min(1.0 + (landingGlow - 1.0) * 0.3, 1.8)
            local glowH = swordH
            local glowP = nvgImagePattern(nvg,
                swordCX - glowW / 2, swordTopY,
                glowW, glowH, 0, swordImg, math.min(0.8, 0.3 * fadeAlpha * landingGlow))
            nvgBeginPath(nvg)
            nvgRect(nvg, swordCX - glowW / 2, swordTopY, glowW, glowH)
            nvgFillPaint(nvg, glowP)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)

            -- 剑身
            local imgP = nvgImagePattern(nvg,
                swordCX - swordW / 2, swordTopY,
                swordW, swordH, 0, swordImg, 0.9 * fadeAlpha)
            nvgBeginPath(nvg)
            nvgRect(nvg, swordCX - swordW / 2, swordTopY, swordW, swordH)
            nvgFillPaint(nvg, imgP)
            nvgFill(nvg)

            nvgRestore(nvg)  -- 恢复翻转变换
        else
            -- 回退：线段剑（剑尖朝下）
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, swordCX, swordTopY)
            nvgLineTo(nvg, swordCX, swordBotY)
            nvgStrokeColor(nvg, nvgRGBA(120, 200, 255, math.floor(200 * fadeAlpha)))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
        end

        -- ── 剑身周围小电弧环绕（不在出现阶段） ──
        if not spawning and fadeAlpha > 0.1 then
            local sparkCount = 3
            local swordMidX = swordCX
            local swordMidY = swordTopY + swordH * 0.5
            for s = 1, sparkCount do
                local phase = time * 5 + s * 2.1 + i * 1.7
                local sparkAngle = phase
                local sparkR = swordW * 0.5 + math.sin(phase * 1.3) * swordW * 0.15
                local sx1 = swordMidX + math.cos(sparkAngle) * sparkR
                local sy1 = swordMidY + math.sin(sparkAngle) * sparkR * 1.6
                local sx2 = swordMidX + math.cos(sparkAngle + 0.8) * sparkR * 0.7
                local sy2 = swordMidY + math.sin(sparkAngle + 0.8) * sparkR * 1.2
                local sparkA = math.floor(140 * fadeAlpha * (0.3 + 0.7 * math.abs(math.sin(phase * 2))))
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, sx1, sy1)
                nvgLineTo(nvg, sx2, sy2)
                nvgStrokeColor(nvg, nvgRGBA(160, 210, 255, sparkA))
                nvgStrokeWidth(nvg, 1.2)
                nvgLineCap(nvg, NVG_ROUND)
                nvgStroke(nvg)
            end
        end

        -- ── 电弧连接目标 ──
        local tgt = sf.currentTarget
        if tgt and tgt.alive then
            local tx = (tgt.x - camera.x) * tileSize + l.w / 2 + l.x
            local ty = (tgt.y - camera.y) * tileSize + l.h / 2 + l.y
            -- 剑身中心为电弧起点
            local arcStartX = swordCX
            local arcStartY = swordTopY + swordH * 0.35

            -- 电弧连线（粗主弧 + 外层光晕）
            local segments = 3
            local boltA = math.floor(210 * fadeAlpha * (0.5 + 0.5 * math.sin(time * 6 + i * 2)))

            -- 外层光晕（additive, 更宽更淡）
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, arcStartX, arcStartY)
            for s = 1, segments - 1 do
                local frac = s / segments
                local mx = arcStartX + (tx - arcStartX) * frac
                    + math.sin(time * 8 + s * 5 + i * 3) * tileSize * 0.10
                local my = arcStartY + (ty - arcStartY) * frac
                    + math.cos(time * 7 + s * 4 + i * 2) * tileSize * 0.10
                nvgLineTo(nvg, mx, my)
            end
            nvgLineTo(nvg, tx, ty)
            nvgStrokeColor(nvg, nvgRGBA(100, 170, 255, math.floor(boltA * 0.35)))
            nvgStrokeWidth(nvg, 5.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgLineJoin(nvg, NVG_ROUND)
            nvgStroke(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)

            -- 主弧（实心粗线）
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, arcStartX, arcStartY)
            for s = 1, segments - 1 do
                local frac = s / segments
                local mx = arcStartX + (tx - arcStartX) * frac
                    + math.sin(time * 8 + s * 5 + i * 3) * tileSize * 0.10
                local my = arcStartY + (ty - arcStartY) * frac
                    + math.cos(time * 7 + s * 4 + i * 2) * tileSize * 0.10
                nvgLineTo(nvg, mx, my)
            end
            nvgLineTo(nvg, tx, ty)
            nvgStrokeColor(nvg, nvgRGBA(180, 220, 255, boltA))
            nvgStrokeWidth(nvg, 2.5)
            nvgLineCap(nvg, NVG_ROUND)
            nvgLineJoin(nvg, NVG_ROUND)
            nvgStroke(nvg)

            -- 目标身上电击闪光
            local hitGlow = math.floor(120 * fadeAlpha * (0.3 + 0.7 * math.abs(math.sin(time * 12 + i))))
            nvgBeginPath(nvg)
            nvgCircle(nvg, tx, ty, tileSize * 0.15)
            nvgFillColor(nvg, nvgRGBA(180, 220, 255, hitGlow))
            nvgFill(nvg)
        end

        -- ── 剑根部地面微光（落地时有扩散冲击光） ──
        local impactFade = (elapsed < 0.8) and math.max(0, 1.0 - elapsed / 0.8) or 0
        -- 冲击光晕（仅落地后短暂出现）
        if impactFade > 0 then
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local impGlowR = tileSize * (0.4 + 0.3 * (1.0 - impactFade))
            local impGlowPaint = nvgRadialGradient(nvg, swordCX, swordBotY,
                0, impGlowR,
                nvgRGBA(180, 230, 255, math.floor(180 * impactFade)),
                nvgRGBA(100, 180, 255, 0))
            nvgBeginPath(nvg)
            nvgEllipse(nvg, swordCX, swordBotY, impGlowR, impGlowR * 0.4)
            nvgFillPaint(nvg, impGlowPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
        end
        -- 常驻呼吸微光
        local baseGlow = math.floor(80 * fadeAlpha * (0.5 + 0.5 * math.sin(time * 5 + i)))
        nvgBeginPath(nvg)
        nvgEllipse(nvg, swordCX, swordBotY, tileSize * 0.15, tileSize * 0.06)
        nvgFillColor(nvg, nvgRGBA(120, 200, 255, baseGlow))
        nvgFill(nvg)

        nvgRestore(nvg)
        ::continue_sf::
    end
end

return M
