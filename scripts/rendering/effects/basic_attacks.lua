-- ============================================================================
-- effects/basic_attacks.lua - 基础攻击特效（浮动文字、刀光、爪击、宠物攻击）
-- ============================================================================

local shared = require("rendering.effects.shared")
local assets = require("rendering.effects.assets")

local CombatSystem = shared.CombatSystem
local GameConfig = shared.GameConfig
local T = shared.T

local M = {}

--- 渲染浮动伤害数字
function M.RenderFloatingTexts(nvg, l, camera)
    local texts = CombatSystem.floatingTexts
    if #texts == 0 then return end

    local tileSize = camera:GetTileSize()

    nvgFontFace(nvg, "sans")

    for i = 1, #texts do
        local ft = texts[i]

        -- 检查是否在可见范围
        if camera:IsVisible(ft.x, ft.y, l.w, l.h, 3) then
            -- 世界坐标转屏幕坐标
            local sx = (ft.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (ft.y - camera.y) * tileSize + l.h / 2 + l.y + ft.offsetY

            -- 计算透明度（最后 30% 时间淡出）
            local progress = ft.elapsed / ft.lifetime
            local alpha = 255
            if progress > 0.7 then
                alpha = math.floor(255 * (1.0 - (progress - 0.7) / 0.3))
            end
            alpha = math.max(0, math.min(255, alpha))

            local c = ft.color

            -- 缩放效果（刚出现时放大，然后恢复）
            local scale = 1.0
            if progress < 0.15 then
                scale = 1.0 + 0.5 * (1.0 - progress / 0.15)
            end

            -- 阴影
            local fontSize = math.floor(T.worldFont.damage * scale)
            nvgFontSize(nvg, fontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

            -- 描边（黑色阴影）
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.6)))
            nvgText(nvg, sx + 1, sy + 1, ft.text, nil)

            -- 主色
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], alpha))
            nvgText(nvg, sx, sy, ft.text, nil)
        end
    end
end

--- 渲染刀光特效（图片素材版）
function M.RenderSlashEffects(nvg, l, camera)
    local effects = CombatSystem.slashEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()
    local imgHandle = assets.GetSlashImage(nvg)
    if not imgHandle then return end

    -- 刀光素材原始宽高比（256x128 → 2:1）
    local imgAspect = 2.0

    for i = 1, #effects do
        local se = effects[i]

        if camera:IsVisible(se.x, se.y, l.w, l.h, 3) then
            -- 玩家屏幕坐标（刀光原点）
            local sx = (se.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (se.y - camera.y) * tileSize + l.h / 2 + l.y

            -- 动画进度 0~1
            local progress = se.elapsed / se.duration

            -- 透明度：前 15% 淡入，后 40% 淡出
            local alpha = 1.0
            if progress < 0.15 then
                alpha = progress / 0.15
            elseif progress > 0.6 then
                alpha = 1.0 - (progress - 0.6) / 0.4
            end
            alpha = math.max(0, math.min(1, alpha))

            -- 缩放动画：快速展开再略微收缩
            local scaleFactor = 1.0
            if progress < 0.3 then
                -- easeOutBack：快速展开略微过冲
                local t = progress / 0.3
                scaleFactor = 0.3 + 0.8 * (1.0 - (1.0 - t) * (1.0 - t))
            else
                -- 缓慢收缩
                local t = (progress - 0.3) / 0.7
                scaleFactor = 1.1 - 0.2 * t
            end

            -- 刀光图片尺寸：宽度 = 攻击范围像素，高度按宽高比
            local slashW = GameConfig.ATTACK_RANGE * tileSize * scaleFactor
            local slashH = slashW / imgAspect

            -- 旋转角度 = 指向怪物的角度
            local angle = se.angle

            -- 沿攻击方向前移到攻击范围中点，匹配实际攻击距离
            local offsetDist = GameConfig.ATTACK_RANGE * 0.5 * tileSize
            local ox = math.cos(angle) * offsetDist
            local oy = math.sin(angle) * offsetDist

            nvgSave(nvg)

            -- 移到角色胸前位置，旋转到攻击方向
            nvgTranslate(nvg, sx + ox, sy + oy)
            nvgRotate(nvg, angle)
            -- 水平翻转刀刃弧线方向
            nvgScale(nvg, -1, 1)

            -- 图片绘制区域：水平居中于攻击范围中点，垂直居中
            local drawX = -slashW * 0.5
            local drawY = -slashH / 2

            -- 用 nvgImagePattern 绘制带透明度的图片
            local imgPaint = nvgImagePattern(nvg, drawX, drawY, slashW, slashH, 0, imgHandle, alpha)
            nvgBeginPath(nvg)
            nvgRect(nvg, drawX, drawY, slashW, slashH)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)

            nvgRestore(nvg)
        end
    end
end

--- 渲染怪物普攻爪击特效（三道红色爪痕）
function M.RenderClawEffects(nvg, l, camera)
    local effects = CombatSystem.clawEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local ce = effects[i]

        if camera:IsVisible(ce.x, ce.y, l.w, l.h, 3) then
            local sx = (ce.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (ce.y - camera.y) * tileSize + l.h / 2 + l.y

            local progress = ce.elapsed / ce.duration

            -- 透明度：前10%淡入，后50%淡出
            local alpha = 1.0
            if progress < 0.1 then
                alpha = progress / 0.1
            elseif progress > 0.5 then
                alpha = 1.0 - (progress - 0.5) / 0.5
            end
            alpha = math.max(0, math.min(1, alpha))

            -- 爪痕伸展动画：快速划出
            local extend = 1.0
            if progress < 0.2 then
                local t = progress / 0.2
                extend = t * t  -- easeIn
            end

            -- 爪痕参数
            local clawLen = tileSize * 0.7 * extend  -- 爪痕长度
            local clawGap = tileSize * 0.12           -- 三道痕间距
            local lineWidth = 2.5

            nvgSave(nvg)
            nvgTranslate(nvg, sx, sy)
            nvgRotate(nvg, ce.angle)

            -- 爪痕颜色（支持自定义，默认红色）
            local cc = ce.color or {255, 50, 30}
            local glowR = math.min(255, cc[1] + 40)
            local glowG = math.min(255, cc[2] + 70)
            local glowB = math.min(255, cc[3] + 50)

            -- 三道平行爪痕
            for j = -1, 1 do
                local offsetY = j * clawGap
                local a = math.floor(255 * alpha)

                nvgBeginPath(nvg)
                nvgMoveTo(nvg, -clawLen * 0.3, offsetY - clawLen * 0.1)
                nvgLineTo(nvg, clawLen * 0.7, offsetY + clawLen * 0.1)
                nvgStrokeColor(nvg, nvgRGBA(cc[1], cc[2], cc[3], a))
                nvgStrokeWidth(nvg, lineWidth)
                nvgLineCap(nvg, NVG_ROUND)
                nvgStroke(nvg)

                -- 发光层
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, -clawLen * 0.3, offsetY - clawLen * 0.1)
                nvgLineTo(nvg, clawLen * 0.7, offsetY + clawLen * 0.1)
                nvgStrokeColor(nvg, nvgRGBA(glowR, glowG, glowB, math.floor(a * 0.4)))
                nvgStrokeWidth(nvg, lineWidth + 3)
                nvgLineCap(nvg, NVG_ROUND)
                nvgStroke(nvg)
            end

            nvgRestore(nvg)
        end
    end
end

--- 渲染宠物攻击小刀光（绿色短弧线）
function M.RenderPetSlashEffects(nvg, l, camera)
    local effects = CombatSystem.petSlashEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local pe = effects[i]

        if camera:IsVisible(pe.x, pe.y, l.w, l.h, 3) then
            local sx = (pe.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (pe.y - camera.y) * tileSize + l.h / 2 + l.y

            local progress = pe.elapsed / pe.duration

            -- 透明度
            local alpha = 1.0
            if progress < 0.15 then
                alpha = progress / 0.15
            elseif progress > 0.5 then
                alpha = 1.0 - (progress - 0.5) / 0.5
            end
            alpha = math.max(0, math.min(1, alpha))

            -- 伸展动画
            local extend = 1.0
            if progress < 0.25 then
                local t = progress / 0.25
                extend = t * t
            end

            local angle = pe.angle
            local slashLen = tileSize * 0.5 * extend

            nvgSave(nvg)

            -- 偏移到攻击方向前方
            local ox = math.cos(angle) * tileSize * 0.3
            local oy = math.sin(angle) * tileSize * 0.3
            nvgTranslate(nvg, sx + ox, sy + oy)
            nvgRotate(nvg, angle)

            -- 两道绿色短爪痕
            local a = math.floor(220 * alpha)
            for j = -1, 1, 2 do
                local offsetY = j * tileSize * 0.06
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, -slashLen * 0.3, offsetY)
                nvgLineTo(nvg, slashLen * 0.5, offsetY)
                nvgStrokeColor(nvg, nvgRGBA(100, 255, 150, a))
                nvgStrokeWidth(nvg, 2)
                nvgLineCap(nvg, NVG_ROUND)
                nvgStroke(nvg)
            end

            -- 发光层
            for j = -1, 1, 2 do
                local offsetY = j * tileSize * 0.06
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, -slashLen * 0.3, offsetY)
                nvgLineTo(nvg, slashLen * 0.5, offsetY)
                nvgStrokeColor(nvg, nvgRGBA(150, 255, 200, math.floor(a * 0.3)))
                nvgStrokeWidth(nvg, 5)
                nvgLineCap(nvg, NVG_ROUND)
                nvgStroke(nvg)
            end

            nvgRestore(nvg)
        end
    end
end

return M
