-- ============================================================================
-- EffectRenderer.lua - 战斗特效渲染（浮动伤害数字、攻击特效）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local CombatSystem = require("systems.CombatSystem")
local SkillSystem = require("systems.SkillSystem")
local T = require("config.UITheme")
local DungeonHUD = require("rendering.DungeonHUD")

local EffectRenderer = {}

-- 模块级常量：符号方向（扇形边线等）
local SIGNS = {-1, 1}

-- 模块级常量：如来神掌五指几何参数 {offsetX, offsetY, halfWidth, height}
local ICE_SLASH_FINGERS = {
    {-0.35, -0.5, 0.10, 0.30},
    {-0.17, -0.6, 0.11, 0.35},
    { 0.0,  -0.65, 0.12, 0.38},
    { 0.17, -0.6, 0.11, 0.35},
    { 0.38, -0.3, 0.10, 0.28},
}

-- 模块级常量：伏魔刀矩形局部坐标因子 {xFactor, yFactor}
-- 实际坐标 = {xFactor * rectLen, yFactor * halfW}
local BLOOD_SLASH_LOCAL_FACTORS = {
    {0, -1}, {1, -1},
    {1,  1}, {0,  1},
}

-- 模块级复用表：伏魔刀四角屏幕坐标（避免每帧 table.insert）
local bloodSlashCorners = {{0,0}, {0,0}, {0,0}, {0,0}}

--- 在 WorldRenderer 的 Render 中调用
---@param nvg number NanoVG context
---@param l table {x, y, w, h} widget absolute layout
---@param camera table Camera instance
function EffectRenderer.Render(nvg, l, camera)
    EffectRenderer.RenderZones(nvg, l, camera)
    EffectRenderer.RenderBarrierZones(nvg, l, camera)
    EffectRenderer.RenderMonsterWarnings(nvg, l, camera)
    EffectRenderer.RenderSkillEffects(nvg, l, camera)
    EffectRenderer.RenderSwordFormations(nvg, l, camera)
    EffectRenderer.RenderSlashEffects(nvg, l, camera)
    EffectRenderer.RenderPetSlashEffects(nvg, l, camera)
    EffectRenderer.RenderClawEffects(nvg, l, camera)
    EffectRenderer.RenderRakeStrikeEffects(nvg, l, camera)
    EffectRenderer.RenderSetAoeEffects(nvg, l, camera)
    EffectRenderer.RenderBaguaAura(nvg, l, camera)
    EffectRenderer.RenderBuffAuras(nvg, l, camera)
    EffectRenderer.RenderFloatingTexts(nvg, l, camera)
    -- HUD 层：血煞印记叠层指示（屏幕空间，不跟随相机）
    EffectRenderer.RenderBloodMarkHUD(nvg, l.w, l.h)
    -- HUD 层：封魔印叠层指示
    EffectRenderer.RenderSealMarkHUD(nvg, l.w, l.h)
    -- HUD 层：副本战斗 HUD（BOSS 血条、伤害排行、飘字、退出按钮）
    DungeonHUD.Render(nvg, l.w, l.h)
end

--- 渲染浮动伤害数字
function EffectRenderer.RenderFloatingTexts(nvg, l, camera)
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

-- 刀光图片缓存
local slashImageHandle_ = nil
local swordImageHandle_ = nil

--- 获取能量剑图片句柄（懒加载）
local function GetSwordImage(nvg)
    if swordImageHandle_ then return swordImageHandle_ end
    swordImageHandle_ = nvgCreateImage(nvg, "Textures/energy_sword.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if swordImageHandle_ and swordImageHandle_ > 0 then
        return swordImageHandle_
    end
    swordImageHandle_ = nil
    return nil
end

local giantSwordImageHandle_ = nil
--- 获取巨剑图片句柄（懒加载）
local function GetGiantSwordImage(nvg)
    if giantSwordImageHandle_ then return giantSwordImageHandle_ end
    giantSwordImageHandle_ = nvgCreateImage(nvg, "Textures/giant_sword.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if giantSwordImageHandle_ and giantSwordImageHandle_ > 0 then
        return giantSwordImageHandle_
    end
    giantSwordImageHandle_ = nil
    return nil
end

--- 获取刀光图片句柄（懒加载，只加载一次）
local function GetSlashImage(nvg)
    if slashImageHandle_ then return slashImageHandle_ end
    slashImageHandle_ = nvgCreateImage(nvg, "Textures/slash_effect.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if slashImageHandle_ and slashImageHandle_ > 0 then
        return slashImageHandle_
    end
    slashImageHandle_ = nil
    return nil
end

local swordShieldImageHandle_ = nil
--- 获取能量小剑图片句柄（懒加载，御剑护体专用）
local function GetSwordShieldImage(nvg)
    if swordShieldImageHandle_ then return swordShieldImageHandle_ end
    swordShieldImageHandle_ = nvgCreateImage(nvg, "Textures/energy_sword.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if swordShieldImageHandle_ and swordShieldImageHandle_ > 0 then
        return swordShieldImageHandle_
    end
    swordShieldImageHandle_ = nil
    return nil
end

local lightningSwordImageHandle_ = nil
--- 获取电剑图片句柄（懒加载，剑阵降临插地剑专用）
local function GetLightningSwordImage(nvg)
    if lightningSwordImageHandle_ then return lightningSwordImageHandle_ end
    lightningSwordImageHandle_ = nvgCreateImage(nvg, "Textures/lightning_sword.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if lightningSwordImageHandle_ and lightningSwordImageHandle_ > 0 then
        return lightningSwordImageHandle_
    end
    lightningSwordImageHandle_ = nil
    return nil
end

local energyTowerImageHandle_ = nil
--- 获取能量青云塔图片句柄（懒加载，神塔镇压专用）
local function GetEnergyTowerImage(nvg)
    if energyTowerImageHandle_ then return energyTowerImageHandle_ end
    energyTowerImageHandle_ = nvgCreateImage(nvg, "Textures/energy_tower_qingyun.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if energyTowerImageHandle_ and energyTowerImageHandle_ > 0 then
        return energyTowerImageHandle_
    end
    energyTowerImageHandle_ = nil
    return nil
end

local bloodSkullImageHandle_ = nil
--- 获取血神头颅图片句柄（懒加载，镇岳血神专用）
local function GetBloodSkullImage(nvg)
    if bloodSkullImageHandle_ then return bloodSkullImageHandle_ end
    bloodSkullImageHandle_ = nvgCreateImage(nvg, "Textures/energy_blood_skull.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if bloodSkullImageHandle_ and bloodSkullImageHandle_ > 0 then
        return bloodSkullImageHandle_
    end
    bloodSkullImageHandle_ = nil
    return nil
end

--- 渲染刀光特效（图片素材版）
function EffectRenderer.RenderSlashEffects(nvg, l, camera)
    local effects = CombatSystem.slashEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()
    local imgHandle = GetSlashImage(nvg)
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
function EffectRenderer.RenderClawEffects(nvg, l, camera)
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

--- 渲染技能范围特效（金刚掌：圆形冲击波 / 伏魔刀：刀气横斩 / 金钟罩：钟形护盾）

-- ============================================================================
-- 技能特效渲染函数（从 RenderSkillEffects 提取的独立渲染器）
-- ============================================================================

local function renderIceSlash(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 金刚掌特效：身前圆形冲击波 + 掌印 + 金色气浪 ═══
    local radius = se.range * tileSize * expand
    -- 特效中心偏移到角色身前（沿面朝方向偏移 range 距离）
    local cx = sx + math.cos(baseAngle) * radius
    local cy = sy + math.sin(baseAngle) * radius
    -- 冲击波圆环（从内向外扩散）
    local waveRadius = radius * (0.3 + 0.7 * progress)
    local waveAlpha = math.floor(200 * alpha * (1.0 - progress * 0.5))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, waveRadius)
    nvgStrokeColor(nvg, nvgRGBA(255, 200, 80, waveAlpha))
    nvgStrokeWidth(nvg, 3.5 * (1.0 - progress * 0.5))
    nvgStroke(nvg)
    -- 内圈金色光晕填充
    local innerR = radius * 0.7 * expand
    local glowPaint = nvgRadialGradient(nvg, cx, cy, 0, innerR,
        nvgRGBA(255, 215, 80, math.floor(100 * alpha)),
        nvgRGBA(255, 180, 40, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, innerR)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)
    -- 掌印（五指 + 掌心），在圆心位置
    local palmScale = tileSize * 0.35 * expand
    nvgSave(nvg)
    nvgTranslate(nvg, cx, cy)
    nvgRotate(nvg, baseAngle + math.pi / 2)
    local palmAlpha = math.floor(220 * alpha)
    -- 掌心圆
    nvgBeginPath(nvg)
    nvgEllipse(nvg, 0, palmScale * 0.1, palmScale * 0.5, palmScale * 0.55)
    nvgFillColor(nvg, nvgRGBA(255, 220, 100, math.floor(palmAlpha * 0.7)))
    nvgFill(nvg)
    -- 五根手指（常量表已提升到模块级）
    for _, f in ipairs(ICE_SLASH_FINGERS) do
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg,
            (f[1] - f[3]) * palmScale,
            f[2] * palmScale,
            f[3] * 2 * palmScale,
            f[4] * palmScale,
            f[3] * palmScale * 0.8)
        nvgFillColor(nvg, nvgRGBA(255, 210, 80, palmAlpha))
        nvgFill(nvg)
    end
    nvgRestore(nvg)
    -- 外围金色气浪弧线（围绕身前圆心扩散）
    for j = 0, 3 do
        local arcAngle = baseAngle + (j - 1.5) * 0.5
        local arcR = radius * (0.5 + 0.5 * progress)
        local arcLen = math.pi * 0.25
        nvgBeginPath(nvg)
        nvgArc(nvg, cx, cy, arcR, arcAngle - arcLen / 2, arcAngle + arcLen / 2, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(255, 200, 60, math.floor(160 * alpha * (1.0 - progress * 0.6))))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
    -- 震地裂纹（从圆心向外辐射）
    for j = 0, 5 do
        local crackAngle = baseAngle + (j / 6) * math.pi * 2
        local crackStart = radius * 0.15
        local crackEnd = radius * (0.3 + 0.4 * progress)
        local x1 = cx + math.cos(crackAngle) * crackStart
        local y1 = cy + math.sin(crackAngle) * crackStart
        local x2 = cx + math.cos(crackAngle) * crackEnd
        local y2 = cy + math.sin(crackAngle) * crackEnd
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x2, y2)
        nvgStrokeColor(nvg, nvgRGBA(200, 170, 50, math.floor(120 * alpha)))
        nvgStrokeWidth(nvg, 1.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
end

local function renderBloodSlash(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 伏魔刀特效：前方矩形区域 + 横斩线 + 吸血回流 ═══
    local rectLen = (se.rectLength or 2.0) * tileSize * expand
    local rectW = (se.rectWidth or 1.0) * tileSize * expand
    local halfW = rectW / 2
    local cosA = math.cos(baseAngle)
    local sinA = math.sin(baseAngle)
    -- 矩形四角（玩家位置为起点，复用模块级表）
    for ci = 1, 4 do
        local fac = BLOOD_SLASH_LOCAL_FACTORS[ci]
        local lx = fac[1] * rectLen
        local ly = fac[2] * halfW
        bloodSlashCorners[ci][1] = sx + lx * cosA - ly * sinA
        bloodSlashCorners[ci][2] = sy + lx * sinA + ly * cosA
    end
    -- 矩形填充（深红半透明）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bloodSlashCorners[1][1], bloodSlashCorners[1][2])
    for j = 2, 4 do
        nvgLineTo(nvg, bloodSlashCorners[j][1], bloodSlashCorners[j][2])
    end
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(70 * alpha)))
    nvgFill(nvg)
    -- 矩形边框（血红）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bloodSlashCorners[1][1], bloodSlashCorners[1][2])
    for j = 2, 4 do
        nvgLineTo(nvg, bloodSlashCorners[j][1], bloodSlashCorners[j][2])
    end
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 横斩线（3条横切纹，沿矩形宽度方向）
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
        nvgStrokeColor(nvg, nvgRGBA(255, 80, 60, math.floor((140 - j * 20) * alpha)))
        nvgStrokeWidth(nvg, 2.5 - j * 0.3)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
    -- 吸血回流粒子（从矩形远端向玩家收缩）
    if progress > 0.2 then
        local returnProgress = (progress - 0.2) / 0.8
        for j = 0, 5 do
            local fwd = rectLen * (1.0 - returnProgress * 0.8) * ((j % 3 + 1) / 3.5)
            local lat = halfW * 0.7 * (j % 2 == 0 and -1 or 1) * (1.0 - returnProgress * 0.3)
            local px = sx + fwd * cosA - lat * sinA
            local py = sy + fwd * sinA + lat * cosA
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 2.0 * (1.0 - returnProgress * 0.5))
            nvgFillColor(nvg, nvgRGBA(255, 100, 100, math.floor(180 * alpha)))
            nvgFill(nvg)
        end
    end
end

local function renderBloodSeaAoe(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 血海翻涌特效：60度前方扇面 + 血气涟漪 + 血滴粒子 ═══
    local radius = se.range * tileSize * expand
    local halfAngle = math.rad((se.coneAngle or 60) / 2)
    local faceAngle = se.targetAngle or (se.facingRight and 0 or math.pi)
    -- 暗红扇面填充（血池效果）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy)
    nvgArc(nvg, sx, sy, radius, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
    nvgClosePath(nvg)
    local poolPaint = nvgRadialGradient(nvg, sx, sy, radius * 0.1, radius,
        nvgRGBA(c[1], c[2], c[3], math.floor(90 * alpha)),
        nvgRGBA(c[1], 0, 0, math.floor(30 * alpha)))
    nvgFillPaint(nvg, poolPaint)
    nvgFill(nvg)
    -- 扇面边缘描边
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, sy)
    nvgArc(nvg, sx, sy, radius, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 血气涟漪（3 圈扇形从中心向外扩散）
    for j = 0, 2 do
        local rippleP = math.fmod(progress + j * 0.33, 1.0)
        local rippleR = radius * (0.2 + 0.8 * rippleP)
        local rippleA = math.floor(160 * (1.0 - rippleP) * alpha)
        if rippleA > 0 then
            nvgBeginPath(nvg)
            nvgArc(nvg, sx, sy, rippleR, faceAngle - halfAngle, faceAngle + halfAngle, NVG_CW)
            nvgStrokeColor(nvg, nvgRGBA(200, 30, 30, rippleA))
            nvgStrokeWidth(nvg, 2.0 * (1.0 - rippleP * 0.6))
            nvgStroke(nvg)
        end
    end
    -- 血滴粒子（在扇面范围内飞散）
    for j = 0, 7 do
        local particleAngle = faceAngle - halfAngle + (j / 7) * halfAngle * 2
        particleAngle = particleAngle + math.sin(progress * 3.0 + j) * 0.15
        local dist = radius * (0.3 + 0.5 * math.fmod(progress * 2 + j * 0.12, 1.0))
        local px = sx + math.cos(particleAngle) * dist
        local py = sy + math.sin(particleAngle) * dist
        local pSize = 2.5 * (1.0 - progress * 0.5)
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, pSize)
        nvgFillColor(nvg, nvgRGBA(220, 40, 40, math.floor(180 * alpha)))
        nvgFill(nvg)
    end
    -- 中心血色旋涡（沿扇面中线喷射）
    local swirlR = radius * 0.35 * expand
    nvgBeginPath(nvg)
    nvgArc(nvg, sx, sy, swirlR,
        faceAngle - halfAngle * 0.6 + progress * math.pi * 2,
        faceAngle + halfAngle * 0.6 + progress * math.pi * 2, NVG_CW)
    nvgStrokeColor(nvg, nvgRGBA(255, 60, 60, math.floor(200 * alpha)))
    nvgStrokeWidth(nvg, 3.0)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
end

local function renderHaoqiSealZone(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 浩气领域特效：青蓝色圆形 + 太极纹 + 气旋 ═══
    local radius = se.range * tileSize * expand
    -- 青蓝色地面圆（领域场效果）
    local zonePaint = nvgRadialGradient(nvg, sx, sy, radius * 0.05, radius,
        nvgRGBA(c[1], c[2], c[3], math.floor(80 * alpha)),
        nvgRGBA(40, 120, 200, math.floor(20 * alpha)))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgFillPaint(nvg, zonePaint)
    nvgFill(nvg)
    -- 外圈边框
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(220 * alpha)))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    -- 太极图案（中心双鱼）
    local taijiR = radius * 0.25 * expand
    local rotAngle = progress * math.pi * 3  -- 旋转动画
    nvgSave(nvg)
    nvgTranslate(nvg, sx, sy)
    nvgRotate(nvg, rotAngle)
    -- 阴鱼（暗蓝半圆）
    nvgBeginPath(nvg)
    nvgArc(nvg, 0, 0, taijiR, math.pi * 0.5, math.pi * 1.5, NVG_CW)
    nvgArc(nvg, 0, -taijiR * 0.5, taijiR * 0.5, math.pi * 1.5, math.pi * 0.5, NVG_CCW)
    nvgArc(nvg, 0, taijiR * 0.5, taijiR * 0.5, math.pi * 1.5, math.pi * 0.5, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(40, 100, 180, math.floor(150 * alpha)))
    nvgFill(nvg)
    -- 阳鱼（亮青半圆）
    nvgBeginPath(nvg)
    nvgArc(nvg, 0, 0, taijiR, math.pi * 1.5, math.pi * 0.5, NVG_CW)
    nvgArc(nvg, 0, taijiR * 0.5, taijiR * 0.5, math.pi * 0.5, math.pi * 1.5, NVG_CCW)
    nvgArc(nvg, 0, -taijiR * 0.5, taijiR * 0.5, math.pi * 0.5, math.pi * 1.5, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(120, 230, 255, math.floor(150 * alpha)))
    nvgFill(nvg)
    -- 鱼眼
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, -taijiR * 0.5, taijiR * 0.12)
    nvgFillColor(nvg, nvgRGBA(120, 230, 255, math.floor(200 * alpha)))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, taijiR * 0.5, taijiR * 0.12)
    nvgFillColor(nvg, nvgRGBA(40, 100, 180, math.floor(200 * alpha)))
    nvgFill(nvg)
    nvgRestore(nvg)
    -- 外围气旋弧线（旋转）
    for j = 0, 3 do
        local arcBaseAngle = rotAngle + j * math.pi * 0.5
        local arcR = radius * (0.6 + 0.2 * math.sin(progress * math.pi * 4 + j))
        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, arcR, arcBaseAngle, arcBaseAngle + math.pi * 0.3, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(140 * alpha * (0.6 + 0.4 * math.sin(progress * 6 + j)))))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
end

local function renderGoldenBell(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 金钟罩特效：钟形护盾 + 金色涟漪 ═══
    local bellH = tileSize * 1.3 * expand
    local bellW = tileSize * 0.9 * expand
    -- 金色光柱（从下向上）
    local pillarAlpha = math.floor(150 * alpha * (1.0 - progress * 0.7))
    local pillarPaint = nvgLinearGradient(nvg,
        sx, sy + bellH * 0.3,
        sx, sy - bellH * 0.5,
        nvgRGBA(255, 200, 50, pillarAlpha),
        nvgRGBA(255, 220, 100, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sx - bellW * 0.3, sy - bellH * 0.5, bellW * 0.6, bellH * 0.8)
    nvgFillPaint(nvg, pillarPaint)
    nvgFill(nvg)
    -- 钟形轮廓（椭圆顶 + 梯形体）
    local bellAlpha = math.floor(220 * alpha)
    nvgBeginPath(nvg)
    -- 钟顶弧线
    nvgArc(nvg, sx, sy - bellH * 0.25, bellW * 0.45,
        math.pi + 0.3, -0.3, NVG_CW)
    -- 右侧弧线向下展开
    nvgBezierTo(nvg,
        sx + bellW * 0.5, sy - bellH * 0.1,
        sx + bellW * 0.55, sy + bellH * 0.2,
        sx + bellW * 0.5, sy + bellH * 0.35)
    -- 底部弧线
    nvgBezierTo(nvg,
        sx + bellW * 0.45, sy + bellH * 0.4,
        sx - bellW * 0.45, sy + bellH * 0.4,
        sx - bellW * 0.5, sy + bellH * 0.35)
    -- 左侧弧线向上收
    nvgBezierTo(nvg,
        sx - bellW * 0.55, sy + bellH * 0.2,
        sx - bellW * 0.5, sy - bellH * 0.1,
        sx - bellW * 0.45, sy - bellH * 0.25 + 0.3)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, nvgRGBA(255, 215, 80, bellAlpha))
    nvgStrokeWidth(nvg, 3)
    nvgStroke(nvg)
    -- 半透明金色填充
    nvgFillColor(nvg, nvgRGBA(255, 215, 80, math.floor(50 * alpha)))
    nvgFill(nvg)
    -- 钟顶小圆钮
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy - bellH * 0.35, bellW * 0.08)
    nvgFillColor(nvg, nvgRGBA(255, 230, 120, bellAlpha))
    nvgFill(nvg)
    -- 向外扩散的金色涟漪环
    for j = 0, 2 do
        local ringProgress = math.fmod(progress + j * 0.33, 1.0)
        local ringR = (bellW * 0.5 + tileSize * 0.8 * ringProgress)
        local ringA = math.floor(160 * (1.0 - ringProgress) * alpha)
        if ringA > 0 then
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, ringR)
            nvgStrokeColor(nvg, nvgRGBA(255, 215, 80, ringA))
            nvgStrokeWidth(nvg, 1.5 * (1.0 - ringProgress * 0.5))
            nvgStroke(nvg)
        end
    end
end

local function renderDragonElephant(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 龙象功特效：正面象头图腾（参考佛教象头线稿） ═══
    local S = tileSize * 2.4 * expand
    local headAlpha = math.floor(225 * alpha)
    local cy = sy - S * 0.05  -- 整体上移一点，给鼻子留空间
    local lw = 2.8  -- 主线宽
    local lwThin = 1.5  -- 细线宽
    local gold = function(a) return nvgRGBA(215, 190, 110, math.floor(a * alpha)) end
    local goldBright = function(a) return nvgRGBA(245, 225, 150, math.floor(a * alpha)) end

    -- ── 佛光（头顶圆形光晕） ──
    local haloA = math.floor(90 * alpha * (0.6 + 0.4 * math.sin(progress * math.pi * 2)))
    local haloPaint = nvgRadialGradient(nvg,
        sx, cy - S * 0.42, S * 0.08, S * 0.35,
        nvgRGBA(255, 225, 140, haloA),
        nvgRGBA(255, 200, 80, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, cy - S * 0.38, S * 0.34)
    nvgFillPaint(nvg, haloPaint)
    nvgFill(nvg)

    -- ── 盾形大耳（棱角分明的五边形，如参考图） ──
    for side = -1, 1, 2 do
        nvgBeginPath(nvg)
        -- 5个关键点构成盾形耳：
        -- P1: 耳根上（连接头顶侧）
        -- P2: 耳上外角（向外上翘）
        -- P3: 耳最外侧尖角
        -- P4: 耳下外角
        -- P5: 耳根下（连接头下侧）
        local p1x = sx + side * S * 0.16
        local p1y = cy - S * 0.28
        local p2x = sx + side * S * 0.48
        local p2y = cy - S * 0.32
        local p3x = sx + side * S * 0.58
        local p3y = cy - S * 0.10
        local p4x = sx + side * S * 0.45
        local p4y = cy + S * 0.16
        local p5x = sx + side * S * 0.15
        local p5y = cy + S * 0.08
        nvgMoveTo(nvg, p1x, p1y)
        -- P1→P2 上边：微弧向外上
        nvgBezierTo(nvg, sx + side * S * 0.28, p1y - S * 0.06, sx + side * S * 0.40, p2y - S * 0.02, p2x, p2y)
        -- P2→P3 外上→外侧尖：直线感
        nvgBezierTo(nvg, sx + side * S * 0.54, p2y + S * 0.04, p3x + side * S * 0.01, p3y - S * 0.06, p3x, p3y)
        -- P3→P4 外侧→外下角：直线感
        nvgBezierTo(nvg, p3x - side * S * 0.01, p3y + S * 0.08, p4x + side * S * 0.02, p4y - S * 0.04, p4x, p4y)
        -- P4→P5 下边：微弧收回
        nvgBezierTo(nvg, sx + side * S * 0.32, p4y + S * 0.04, sx + side * S * 0.22, p5y + S * 0.02, p5x, p5y)
        nvgClosePath(nvg)
        nvgStrokeColor(nvg, gold(headAlpha))
        nvgStrokeWidth(nvg, lw)
        nvgLineJoin(nvg, NVG_ROUND)
        nvgStroke(nvg)
        -- 耳面填充
        nvgFillColor(nvg, nvgRGBA(240, 230, 200, math.floor(25 * alpha)))
        nvgFill(nvg)
        -- 耳内装饰线（从内侧描一条平行轮廓）
        nvgBeginPath(nvg)
        local s2 = 0.72  -- 内轮廓缩放
        local ecx = (p1x + p3x) * 0.5
        local ecy = (p1y + p4y) * 0.5
        local function earInner(px, py) return ecx + (px - ecx) * s2, ecy + (py - ecy) * s2 end
        local i1x, i1y = earInner(p1x, p1y)
        local i2x, i2y = earInner(p2x, p2y)
        local i3x, i3y = earInner(p3x, p3y)
        local i4x, i4y = earInner(p4x, p4y)
        local i5x, i5y = earInner(p5x, p5y)
        nvgMoveTo(nvg, i1x, i1y)
        nvgLineTo(nvg, i2x, i2y)
        nvgLineTo(nvg, i3x, i3y)
        nvgLineTo(nvg, i4x, i4y)
        nvgLineTo(nvg, i5x, i5y)
        nvgStrokeColor(nvg, gold(70))
        nvgStrokeWidth(nvg, lwThin)
        nvgStroke(nvg)
    end

    -- ── 面部轮廓（倒三角/盾形，上宽下尖） ──
    nvgBeginPath(nvg)
    -- 用贝塞尔构建倒三角脸型：额宽→颧→下巴尖
    local faceTopW = S * 0.18  -- 额头半宽
    local faceMidW = S * 0.16  -- 颧骨半宽
    local faceTop = cy - S * 0.30  -- 额顶
    local faceMid = cy + S * 0.02  -- 颧骨
    local faceBot = cy + S * 0.22  -- 下巴尖
    nvgMoveTo(nvg, sx, faceTop - S * 0.08)  -- 额顶尖（冠顶）
    -- 额顶→右额角
    nvgBezierTo(nvg, sx + S * 0.04, faceTop - S * 0.06, sx + faceTopW - S * 0.04, faceTop + S * 0.02, sx + faceTopW, faceTop + S * 0.04)
    -- 右额→右颧
    nvgBezierTo(nvg, sx + faceTopW + S * 0.02, faceMid - S * 0.10, sx + faceMidW + S * 0.02, faceMid - S * 0.04, sx + faceMidW, faceMid)
    -- 右颧→下巴
    nvgBezierTo(nvg, sx + faceMidW - S * 0.01, faceMid + S * 0.08, sx + S * 0.04, faceBot - S * 0.04, sx, faceBot)
    -- 下巴→左颧
    nvgBezierTo(nvg, sx - S * 0.04, faceBot - S * 0.04, sx - faceMidW + S * 0.01, faceMid + S * 0.08, sx - faceMidW, faceMid)
    -- 左颧→左额
    nvgBezierTo(nvg, sx - faceMidW - S * 0.02, faceMid - S * 0.04, sx - faceTopW - S * 0.02, faceMid - S * 0.10, sx - faceTopW, faceTop + S * 0.04)
    -- 左额→额顶
    nvgBezierTo(nvg, sx - faceTopW + S * 0.04, faceTop + S * 0.02, sx - S * 0.04, faceTop - S * 0.06, sx, faceTop - S * 0.08)
    nvgClosePath(nvg)
    nvgStrokeColor(nvg, gold(headAlpha))
    nvgStrokeWidth(nvg, lw + 0.5)
    nvgStroke(nvg)
    -- 面部填充
    local headFill = nvgRadialGradient(nvg,
        sx, cy - S * 0.10, S * 0.04, S * 0.30,
        nvgRGBA(250, 242, 220, math.floor(70 * alpha)),
        nvgRGBA(225, 205, 155, math.floor(15 * alpha)))
    nvgFillPaint(nvg, headFill)
    nvgFill(nvg)

    -- ── 额顶冠饰（V形尖冠 + 中央竖线） ──
    -- 中央竖脊线（从冠顶到鼻梁）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, faceTop - S * 0.06)
    nvgLineTo(nvg, sx, cy + S * 0.06)
    nvgStrokeColor(nvg, gold(120))
    nvgStrokeWidth(nvg, lwThin)
    nvgStroke(nvg)
    -- 额头V纹（从中央向两侧展开的装饰线）
    for side = -1, 1, 2 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx, faceTop)
        nvgBezierTo(nvg,
            sx + side * S * 0.04, faceTop + S * 0.06,
            sx + side * S * 0.10, faceTop + S * 0.10,
            sx + side * S * 0.13, faceTop + S * 0.16)
        nvgStrokeColor(nvg, gold(100))
        nvgStrokeWidth(nvg, lwThin)
        nvgStroke(nvg)
    end

    -- ── 额间宝珠（圆形白毫） ──
    local jewY = cy - S * 0.18
    local jewelGlow = nvgRadialGradient(nvg,
        sx, jewY, S * 0.01, S * 0.055,
        nvgRGBA(255, 245, 200, math.floor(150 * alpha)),
        nvgRGBA(255, 230, 160, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, jewY, S * 0.055)
    nvgFillPaint(nvg, jewelGlow)
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, jewY, S * 0.022)
    nvgFillColor(nvg, nvgRGBA(255, 248, 220, math.floor(230 * alpha)))
    nvgFill(nvg)
    nvgStrokeColor(nvg, gold(180))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ── 眼睛（面部两侧，半闭垂目弧线） ──
    for side = -1, 1, 2 do
        local eyeX = sx + side * S * 0.085
        local eyeY = cy - S * 0.06
        -- 上眼线
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, eyeX - side * S * 0.01, eyeY - S * 0.008)
        nvgBezierTo(nvg,
            eyeX + side * S * 0.015, eyeY - S * 0.020,
            eyeX + side * S * 0.035, eyeY - S * 0.015,
            eyeX + side * S * 0.05, eyeY + S * 0.002)
        nvgStrokeColor(nvg, gold(headAlpha))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
        -- 下眼线
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, eyeX - side * S * 0.005, eyeY)
        nvgBezierTo(nvg,
            eyeX + side * S * 0.015, eyeY + S * 0.012,
            eyeX + side * S * 0.035, eyeY + S * 0.010,
            eyeX + side * S * 0.048, eyeY + S * 0.004)
        nvgStrokeColor(nvg, gold(140))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
        -- 眼周装饰弧（从眼尾向外延伸的流线）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, eyeX + side * S * 0.05, eyeY)
        nvgBezierTo(nvg,
            eyeX + side * S * 0.07, eyeY + S * 0.02,
            eyeX + side * S * 0.09, eyeY + S * 0.05,
            eyeX + side * S * 0.10, eyeY + S * 0.09)
        nvgStrokeColor(nvg, gold(70))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)
    end

    -- ── 象鼻（粗壮居中，长垂，末端卷曲如参考图） ──
    -- 左轮廓
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx - S * 0.045, cy + S * 0.10)
    nvgBezierTo(nvg,
        sx - S * 0.065, cy + S * 0.22,
        sx - S * 0.055, cy + S * 0.36,
        sx - S * 0.035, cy + S * 0.48)
    nvgBezierTo(nvg,
        sx - S * 0.02, cy + S * 0.54,
        sx + S * 0.01, cy + S * 0.58,
        sx + S * 0.05, cy + S * 0.56)
    nvgStrokeColor(nvg, gold(headAlpha))
    nvgStrokeWidth(nvg, lw)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)
    -- 右轮廓
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx + S * 0.045, cy + S * 0.10)
    nvgBezierTo(nvg,
        sx + S * 0.065, cy + S * 0.22,
        sx + S * 0.055, cy + S * 0.36,
        sx + S * 0.035, cy + S * 0.48)
    nvgBezierTo(nvg,
        sx + S * 0.025, cy + S * 0.52,
        sx + S * 0.03, cy + S * 0.55,
        sx + S * 0.05, cy + S * 0.56)
    nvgStrokeColor(nvg, gold(headAlpha))
    nvgStrokeWidth(nvg, lw)
    nvgStroke(nvg)
    -- 鼻纹横纹（5条）
    for k = 1, 5 do
        local ny = cy + S * (0.16 + k * 0.06)
        local hw = S * (0.042 - k * 0.004)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx - hw, ny)
        nvgLineTo(nvg, sx + hw, ny)
        nvgStrokeColor(nvg, gold(50))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
    end
    -- 鼻梁中线（装饰）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sx, cy + S * 0.12)
    nvgBezierTo(nvg,
        sx, cy + S * 0.28,
        sx - S * 0.005, cy + S * 0.40,
        sx, cy + S * 0.50)
    nvgStrokeColor(nvg, gold(60))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ── 象牙（从面颊两侧伸出，向外弯曲） ──
    for side = -1, 1, 2 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + side * S * 0.10, cy + S * 0.08)
        nvgBezierTo(nvg,
            sx + side * S * 0.18, cy + S * 0.12,
            sx + side * S * 0.24, cy + S * 0.22,
            sx + side * S * 0.22, cy + S * 0.38)
        nvgStrokeColor(nvg, nvgRGBA(245, 240, 218, headAlpha))
        nvgStrokeWidth(nvg, lw + 0.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end

    -- ── 面部装饰流线（颧骨→下颌的曲线纹饰，如参考图） ──
    for side = -1, 1, 2 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx + side * S * 0.14, cy - S * 0.12)
        nvgBezierTo(nvg,
            sx + side * S * 0.15, cy - S * 0.02,
            sx + side * S * 0.12, cy + S * 0.08,
            sx + side * S * 0.07, cy + S * 0.14)
        nvgStrokeColor(nvg, gold(65))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)
    end

    -- ── 金色 AOE 涟漪环 ──
    for j = 0, 2 do
        local ringProgress = math.fmod(progress + j * 0.33, 1.0)
        local ringR = (S * 0.3 + tileSize * 1.8 * ringProgress)
        local ringA = math.floor(150 * (1.0 - ringProgress) * alpha)
        if ringA > 0 then
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, ringR)
            nvgStrokeColor(nvg, nvgRGBA(220, 195, 100, ringA))
            nvgStrokeWidth(nvg, 2.0 * (1.0 - ringProgress * 0.5))
            nvgStroke(nvg)
        end
    end
end

local function renderThreeSwords(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 三剑式特效：三柄能量小剑（PNG）扇形飞出（60°展角，匹配判定coneAngle） ═══
    local radius = se.range * tileSize * expand
    local halfAngle = math.rad(60 / 2)
    local faceAngle = se.targetAngle or (se.facingRight and 0 or math.pi)
    local swordImg = GetSwordImage(nvg)
    local swordSize = tileSize * 1.3
    for j = -1, 1 do
        local swordAngle = faceAngle + j * halfAngle * 0.8
        local swordDist = radius * (0.3 + 0.7 * progress)
        local cx = sx + math.cos(swordAngle) * swordDist
        local cy = sy + math.sin(swordAngle) * swordDist
        if swordImg then
            nvgSave(nvg)
            nvgTranslate(nvg, cx, cy)
            nvgRotate(nvg, swordAngle)
            local half = swordSize / 2
            -- 外发光（加法混合，半透明放大版）
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local glowS = swordSize * 1.4
            local glowH = glowS / 2
            local glowPaint = nvgImagePattern(nvg, -glowH, -glowH, glowS, glowS, 0, swordImg, 0.3 * alpha)
            nvgBeginPath(nvg)
            nvgRect(nvg, -glowH, -glowH, glowS, glowS)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
            -- 剑身图片
            local imgPaint = nvgImagePattern(nvg, -half, -half, swordSize, swordSize, 0, swordImg, alpha)
            nvgBeginPath(nvg)
            nvgRect(nvg, -half, -half, swordSize, swordSize)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
            -- 剑尖光点
            nvgBeginPath(nvg)
            nvgCircle(nvg, half * 0.7, 0, 4.0 * (1.0 - progress * 0.3))
            nvgFillColor(nvg, nvgRGBA(220, 240, 255, math.floor(255 * alpha)))
            nvgFill(nvg)
            nvgRestore(nvg)
        end
    end
end

local function renderGiantSword(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
    -- ═══ 奔雷式特效：落地AOE冲击波（电剑本体由剑阵出生动画渲染） ═══
    -- 技能整体效果：电剑从天而降→落地AOE伤害→停留为剑阵持续电击
    -- 此处只渲染落地时的AOE冲击波，电剑落下视觉由 RenderSwordFormations 的出生动画统一处理
    local radius = se.range * tileSize * expand
    local faceAngle = se.targetAngle or (se.facingRight and 0 or math.pi)
    -- 偏移中心到角色身前（偏移 range*1.0，让圆完全在身前）
    local offsetDist = se.range * tileSize * 1.0
    local cx = sx + math.cos(faceAngle) * offsetDist
    local cy = sy + math.sin(faceAngle) * offsetDist

    -- ═══ 落地冲击闪白（瞬间白光冲击） ═══
    if progress > 0.15 and progress < 0.35 then
        local flashT = (progress - 0.15) / 0.20
        local flashA = math.floor(120 * alpha * (1.0 - flashT))
        local flashR = radius * (0.3 + 0.7 * flashT)
        local flashPaint = nvgRadialGradient(nvg, cx, cy, 0, flashR,
            nvgRGBA(220, 240, 255, flashA),
            nvgRGBA(220, 240, 255, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, flashR)
        nvgFillPaint(nvg, flashPaint)
        nvgFill(nvg)
    end

    -- ═══ 冲击波（落地瞬间爆发） ═══
    if progress > 0.18 then
        local waveProgress = math.min(1.0, (progress - 0.18) / 0.50)
        -- 三次方 easeOut，快速爆开然后减速
        local waveT = 1.0 - (1.0 - waveProgress) * (1.0 - waveProgress) * (1.0 - waveProgress)
        -- 冲击波环1（主环，更粗）
        local waveR1 = radius * (0.1 + 0.9 * waveT)
        local waveA1 = math.floor(240 * alpha * (1.0 - waveProgress * 0.85))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, waveR1)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveA1))
        nvgStrokeWidth(nvg, 5.0 * (1.0 - waveProgress * 0.4))
        nvgStroke(nvg)
        -- 冲击波环2（内环，延迟展开）
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
        -- 冲击波环3（外环，更大更淡）
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
        -- 范围填充（冲击扩散底色）
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
end

local function renderSwordFormation(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
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
    local giantImg = GetGiantSwordImage(nvg)
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
            local towerImg = GetEnergyTowerImage(nvg)
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
        local radius = se.range * tileSize * expand
        -- 特效中心偏移到角色身前（沿面朝方向偏移 range 距离）
        local cx = sx + math.cos(baseAngle) * radius
        local cy = sy + math.sin(baseAngle) * radius
        -- 底层圆形冲击波（暗红）
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius)
        local wavePaint = nvgRadialGradient(nvg, cx, cy, radius * 0.1, radius,
            nvgRGBA(c[1], c[2], c[3], math.floor(100 * alpha)),
            nvgRGBA(c[1], c[2], c[3], math.floor(20 * alpha)))
        nvgFillPaint(nvg, wavePaint)
        nvgFill(nvg)
        -- 冲击波边缘
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * alpha)))
        nvgStrokeWidth(nvg, 2.5)
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
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(150 * alpha)))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end
        -- 中心拳印圆
        local fistR = tileSize * 0.25 * expand
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, fistR)
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(180 * alpha)))
        nvgFill(nvg)

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
    local skullImg = GetBloodSkullImage(nvg)
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
        nvgStrokeWidth(nvg, 2.5 - j * 0.3)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end
    -- 吸血回流粒子（紫色，从矩形远端向玩家收缩）
    if progress > 0.2 then
        local returnProgress = (progress - 0.2) / 0.8
        for j = 0, 5 do
            local fwd = rectLen * (1.0 - returnProgress * 0.8) * ((j % 3 + 1) / 3.5)
            local lat = halfW * 0.7 * (j % 2 == 0 and -1 or 1) * (1.0 - returnProgress * 0.3)
            local px = sx + fwd * cosA - lat * sinA
            local py = sy + fwd * sinA + lat * cosA
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 2.0 * (1.0 - returnProgress * 0.5))
            nvgFillColor(nvg, nvgRGBA(180, 120, 255, math.floor(180 * alpha)))
            nvgFill(nvg)
        end
    end
end

local SKILL_EFFECT_REGISTRY = {
    ["ice_slash"] = renderIceSlash,
    ["blood_slash"] = renderBloodSlash,
    ["blood_sea_aoe"] = renderBloodSeaAoe,
    ["haoqi_seal_zone"] = renderHaoqiSealZone,
    ["golden_bell"] = renderGoldenBell,
    ["dragon_elephant"] = renderDragonElephant,
    ["three_swords"] = renderThreeSwords,
    ["giant_sword"] = renderGiantSword,
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

function EffectRenderer.RenderSkillEffects(nvg, l, camera)
    local effects = CombatSystem.skillEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local se = effects[i]

        if camera:IsVisible(se.x, se.y, l.w, l.h, 4) then
            local sx = (se.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (se.y - camera.y) * tileSize + l.h / 2 + l.y

            local progress = se.elapsed / se.duration
            local c = se.color

            -- 透明度：快速出现，缓慢淡出
            local alpha = 1.0
            if progress < 0.1 then
                alpha = progress / 0.1
            elseif progress > 0.4 then
                alpha = 1.0 - (progress - 0.4) / 0.6
            end
            alpha = math.max(0, math.min(1, alpha))

            -- 扩展动画：快速展开
            local expand = 1.0
            if progress < 0.2 then
                local t = progress / 0.2
                expand = t * (2.0 - t)  -- easeOut
            end

            -- 朝向角度：优先使用实际目标角度，否则退回二值左右朝向
            local baseAngle = se.targetAngle or (se.facingRight and 0 or math.pi)

            nvgSave(nvg)

            local renderer = SKILL_EFFECT_REGISTRY[se.skillId]
            if renderer then
                renderer(nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
            end

            nvgRestore(nvg)
        end
    end
end

-- ============================================================================
-- 剑阵降临：持续性电磁塔渲染（地面插剑 + 电弧连接目标）
-- ============================================================================
function EffectRenderer.RenderSwordFormations(nvg, l, camera)
    local player = GameState.player
    if not player or not player._swordFormations then return end
    local formations = player._swordFormations
    if #formations == 0 then return end

    local tileSize = camera:GetTileSize()
    local time = GameState.gameTime or 0
    local swordImg = GetLightningSwordImage(nvg)
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

--- 渲染宠物攻击小刀光（绿色短弧线）
function EffectRenderer.RenderPetSlashEffects(nvg, l, camera)
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

--- 渲染持续性地板区域效果（浩气领域/血海领域等）
function EffectRenderer.RenderZones(nvg, l, camera)
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

            -- 区域名称标签
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 12)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(200 * alpha)))
            nvgText(nvg, sx, sy - radius - 4, zone.name, nil)
        end
    end
end

--- 渲染怪物技能预警（圆形/扇形危险区域，脉冲闪烁）
function EffectRenderer.RenderMonsterWarnings(nvg, l, camera)
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
                    if not EffectRenderer._safeSet then EffectRenderer._safeSet = {} end
                    local safeSet = EffectRenderer._safeSet
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

-- ============================================================================
-- 正气结界渲染（永久屏障区域，蓝色光柱 + 脉冲环）
-- ============================================================================

--- 渲染正气结界区域
function EffectRenderer.RenderBarrierZones(nvg, l, camera)
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

-- ============================================================================
-- 血煞印记 HUD 指示器（屏幕角落显示当前层数）
-- ============================================================================

--- 渲染血煞印记叠层指示（HUD，不跟随相机）
---@param nvg number NanoVG context
---@param screenW number 屏幕宽度
---@param screenH number 屏幕高度
function EffectRenderer.RenderBloodMarkHUD(nvg, screenW, screenH)
    local player = GameState.player
    if not player or player.bloodMarkStacks <= 0 then return end

    local stacks = player.bloodMarkStacks
    local dmgPercent = player.bloodMarkDmgPercent * 100

    -- 位置：屏幕右上角偏下
    local x = screenW - 10
    local y = 80

    -- 背景半透明黑色圆角矩形
    local bgW = 100
    local bgH = 38
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - bgW, y, bgW, bgH, 6)
    nvgFillColor(nvg, nvgRGBA(30, 10, 10, 180))
    nvgFill(nvg)
    -- 红色边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - bgW, y, bgW, bgH, 6)
    nvgStrokeColor(nvg, nvgRGBA(200, 40, 40, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 标题行："血煞印记"
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 80, 60, 255))
    nvgText(nvg, x - 6, y + 4, "血煞印记", nil)

    -- 数据行：层数 + 每秒伤害
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(255, 200, 180, 255))
    local totalPercent = stacks * dmgPercent
    local info = string.format("x%d  %.0f%%/s", stacks, totalPercent)
    nvgText(nvg, x - 6, y + 19, info, nil)
end

--- 封魔印 HUD（与血煞印记并列，紫色主题）
function EffectRenderer.RenderSealMarkHUD(nvg, screenW, screenH)
    local player = GameState.player
    if not player or (player.sealMarkStacks or 0) <= 0 then return end

    local stacks = player.sealMarkStacks
    local maxStacks = player.sealMarkConfig and player.sealMarkConfig.maxStacks or 5
    local burstPct = player.sealMarkConfig and player.sealMarkConfig.burstDamagePercent or 0.2

    -- 位置：血煞印记下方（y=80+38+6=124），如果血煞不显示则占用血煞位置
    local x = screenW - 10
    local y = 80
    if player.bloodMarkStacks and player.bloodMarkStacks > 0 then
        y = 124
    end

    -- 背景
    local bgW = 100
    local bgH = 38
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - bgW, y, bgW, bgH, 6)
    nvgFillColor(nvg, nvgRGBA(20, 10, 30, 180))
    nvgFill(nvg)
    -- 紫色边框（满层时高亮闪烁）
    local borderAlpha = 200
    if stacks >= maxStacks then
        borderAlpha = 160 + math.floor(math.abs(math.sin(os.clock() * 4)) * 95)
    end
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - bgW, y, bgW, bgH, 6)
    nvgStrokeColor(nvg, nvgRGBA(160, 60, 200, borderAlpha))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 标题行："封魔印"
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(200, 120, 255, 255))
    nvgText(nvg, x - 6, y + 4, "封魔印", nil)

    -- 数据行：层数/最大层 + 满层爆发伤害
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(220, 200, 255, 255))
    local info = string.format("%d/%d  爆发%.0f%%", stacks, maxStacks, burstPct * 100)
    nvgText(nvg, x - 6, y + 19, info, nil)
end

-- ============================================================================
-- 神器被动「天蓬遗威」钉耙横扫地面特效（矩形条带）
-- ============================================================================

function EffectRenderer.RenderRakeStrikeEffects(nvg, l, camera)
    local effects = CombatSystem.rakeStrikeEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local e = effects[i]
        if not camera:IsVisible(e.x, e.y, l.w, l.h, e.range + 1) then goto continue end

        local t = e.elapsed / e.duration  -- 0→1
        local sx = (e.x - camera.x) * tileSize + l.w / 2 + l.x
        local sy = (e.y - camera.y) * tileSize + l.h / 2 + l.y
        local ang = e.angle
        local cosA = math.cos(ang)
        local sinA = math.sin(ang)
        local fullLen = (e.range or 2.5) * tileSize
        local halfW = (e.width or 1.2) * 0.5 * tileSize
        -- 前方(forward) 和 横向(right) 单位向量
        local fx, fy = cosA, sinA
        local rx, ry = -sinA, cosA

        -- 淡入后淡出
        local alpha
        if t < 0.15 then
            alpha = t / 0.15
        else
            alpha = 1.0 - (t - 0.15) / 0.85
        end
        alpha = math.max(0, math.min(1, alpha))
        local a = math.floor(255 * alpha)

        -- ① 矩形条带区域（金色半透明）——划过的地面
        local x1 = sx + rx * halfW
        local y1 = sy + ry * halfW
        local x2 = sx - rx * halfW
        local y2 = sy - ry * halfW
        local x3 = sx - rx * halfW + fx * fullLen
        local y3 = sy - ry * halfW + fy * fullLen
        local x4 = sx + rx * halfW + fx * fullLen
        local y4 = sy + ry * halfW + fy * fullLen
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x4, y4)
        nvgLineTo(nvg, x3, y3)
        nvgLineTo(nvg, x2, y2)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, math.floor(a * 0.10)))
        nvgFill(nvg)

        -- ② 横向划痕（三齿钉耙横着扫过，划痕方向=横向）
        -- 横扫进度：从一侧扫到另一侧
        local sweepProgress = math.min(t / 0.6, 1.0)  -- 前60%时间完成横扫
        local sweepFrom = -halfW
        local sweepTo = sweepFrom + (halfW * 2) * sweepProgress

        local prongCount = 3
        local prongGap = fullLen / (prongCount + 1)  -- 三齿沿前方均匀分布
        for p = 1, prongCount do
            local fDist = prongGap * p  -- 前方距离
            local cx = sx + fx * fDist
            local cy = sy + fy * fDist
            -- 划痕起点和终点（横向）
            local lx1 = cx + rx * sweepFrom
            local ly1 = cy + ry * sweepFrom
            local lx2 = cx + rx * sweepTo
            local ly2 = cy + ry * sweepTo
            -- 发光层
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, lx1, ly1)
            nvgLineTo(nvg, lx2, ly2)
            nvgStrokeColor(nvg, nvgRGBA(255, 240, 150, math.floor(a * 0.25)))
            nvgStrokeWidth(nvg, 6 * (1 - t * 0.4))
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
            -- 主线
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, lx1, ly1)
            nvgLineTo(nvg, lx2, ly2)
            nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, a))
            nvgStrokeWidth(nvg, 2.5 * (1 - t * 0.3))
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end

        -- ③ 钉耙影子（在划痕上方，跟随横扫位置移动）
        -- 影子位置 = 横扫前端
        local shadowLateral = sweepTo
        local shadowCenterF = fullLen * 0.5  -- 影子在前方中间位置
        local shX = sx + fx * shadowCenterF + rx * shadowLateral
        local shY = sy + fy * shadowCenterF + ry * shadowLateral
        -- 影子偏移到划痕上方（沿前方反方向偏移一点）
        shX = shX - fx * tileSize * 0.15
        shY = shY - fy * tileSize * 0.15
        local shadowAlpha = math.floor(a * 0.35 * (1 - t * 0.5))

        nvgSave(nvg)
        nvgTranslate(nvg, shX, shY)
        nvgRotate(nvg, ang)

        -- 钉耙柄（沿前方方向的一条线）
        local handleLen = fullLen * 0.35
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, -handleLen * 0.5, 0)
        nvgLineTo(nvg, handleLen * 0.5, 0)
        nvgStrokeColor(nvg, nvgRGBA(80, 60, 30, shadowAlpha))
        nvgStrokeWidth(nvg, 3)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)

        -- 钉耙头横档（垂直于柄）
        local headW = prongGap * (prongCount - 1) * 0.55
        local headX = handleLen * 0.5
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, headX, -headW)
        nvgLineTo(nvg, headX, headW)
        nvgStrokeColor(nvg, nvgRGBA(80, 60, 30, shadowAlpha))
        nvgStrokeWidth(nvg, 3.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)

        -- 三齿（从横档向下伸出，即沿前方方向）
        local toothLen = tileSize * 0.2
        for p = 1, prongCount do
            local ty = -headW + (p - 1) * headW
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, headX, ty)
            nvgLineTo(nvg, headX + toothLen, ty)
            nvgStrokeColor(nvg, nvgRGBA(80, 60, 30, shadowAlpha))
            nvgStrokeWidth(nvg, 2.5)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end

        nvgRestore(nvg)

        -- ④ 扬尘微粒（沿横扫前端散布）
        local sparkCount = 4
        for s = 1, sparkCount do
            local phase = (t * 5 + s * 1.3) % 1.0
            local spFwd = prongGap * (0.5 + (s - 1))  -- 沿前方分布
            if spFwd > fullLen then spFwd = fullLen * 0.9 end
            local spx = sx + fx * spFwd + rx * sweepTo + rx * phase * tileSize * 0.15
            local spy = sy + fy * spFwd + ry * sweepTo + ry * phase * tileSize * 0.15
            local spAlpha = math.floor(a * (1 - phase) * 0.5)
            local spR = 1.5 + phase * 2.5
            nvgBeginPath(nvg)
            nvgCircle(nvg, spx, spy, spR)
            nvgFillColor(nvg, nvgRGBA(255, 220, 100, spAlpha))
            nvgFill(nvg)
        end

        ::continue::
    end
end

-- ============================================================================
-- 永驻八卦领域渲染（文王残影脚底八卦，阴/阳双色切换）
-- ============================================================================

--- 八卦符号线段角度（8 条卦线均匀分布）
local BAGUA_LINE_COUNT = 8
local BAGUA_TWO_PI = math.pi * 2

--- 渲染永驻八卦领域
function EffectRenderer.RenderBaguaAura(nvg, l, camera)
    local boss, cfg, stateKey = CombatSystem.GetBaguaAuraInfo()
    if not boss or not cfg then return end

    if not camera:IsVisible(boss.x, boss.y, l.w, l.h, cfg.radius + 1) then return end

    local tileSize = camera:GetTileSize()
    local sx = (boss.x - camera.x) * tileSize + l.w / 2 + l.x
    local sy = (boss.y - camera.y) * tileSize + l.h / 2 + l.y
    local radius = cfg.radius * tileSize

    -- 从 dualState 配置读取当前状态颜色（数据驱动，不硬编码）
    local r, g, b = 180, 160, 80  -- 默认金色
    if boss.dualState and boss.dualState.states and stateKey then
        local stateInfo = boss.dualState.states[stateKey]
        if stateInfo and stateInfo.auraColor then
            r, g, b = stateInfo.auraColor[1], stateInfo.auraColor[2], stateInfo.auraColor[3]
        end
    end

    -- 时间动画（每帧递增，用 os.clock 近似）
    if not EffectRenderer._baguaTime then EffectRenderer._baguaTime = 0 end
    EffectRenderer._baguaTime = EffectRenderer._baguaTime + (1.0 / 60.0)
    local time = EffectRenderer._baguaTime

    local pulse = 0.6 + 0.4 * math.sin(time * 2.0)

    -- 1. 地面领域圆形填充（径向渐变，中心亮边缘暗）
    local fillPaint = nvgRadialGradient(nvg, sx, sy, radius * 0.05, radius,
        nvgRGBA(r, g, b, math.floor(50 * pulse)),
        nvgRGBA(r, g, b, 5))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgFillPaint(nvg, fillPaint)
    nvgFill(nvg)

    -- 2. 外圈边框（呼吸脉冲）
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, radius)
    nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(160 * pulse)))
    nvgStrokeWidth(nvg, 2.0)
    nvgStroke(nvg)

    -- 3. 八卦卦线（旋转的8条径向线，模拟八卦图案）
    local rot = time * 0.8  -- 慢速旋转
    for i = 0, BAGUA_LINE_COUNT - 1 do
        local angle = rot + i * BAGUA_TWO_PI / BAGUA_LINE_COUNT
        local innerR = radius * 0.2
        local outerR = radius * 0.85
        local x1 = sx + math.cos(angle) * innerR
        local y1 = sy + math.sin(angle) * innerR
        local x2 = sx + math.cos(angle) * outerR
        local y2 = sy + math.sin(angle) * outerR

        -- 阳爻（实线）和阴爻（断线）交替
        if i % 2 == 0 then
            -- 阳爻：完整线段
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, x1, y1)
            nvgLineTo(nvg, x2, y2)
            nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(120 * pulse)))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        else
            -- 阴爻：中间断开
            local midR = (innerR + outerR) / 2
            local gapR = (outerR - innerR) * 0.08
            local mx1 = sx + math.cos(angle) * (midR - gapR)
            local my1 = sy + math.sin(angle) * (midR - gapR)
            local mx2 = sx + math.cos(angle) * (midR + gapR)
            local my2 = sy + math.sin(angle) * (midR + gapR)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, x1, y1)
            nvgLineTo(nvg, mx1, my1)
            nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(100 * pulse)))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, mx2, my2)
            nvgLineTo(nvg, x2, y2)
            nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(100 * pulse)))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end
    end

    -- 4. 内圈旋转弧线（3条，反向旋转）
    local innerRot = -time * 1.5
    for j = 0, 2 do
        local arcAngle = innerRot + j * BAGUA_TWO_PI / 3
        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, radius * 0.45, arcAngle, arcAngle + math.pi * 0.4, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(100 * pulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end

    -- 5. 阴阳鱼（中心太极符号简化版）
    local yinYangR = radius * 0.12
    -- 外圆
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy, yinYangR)
    nvgStrokeColor(nvg, nvgRGBA(r, g, b, math.floor(180 * pulse)))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    -- S形分割线（简化为两个半圆弧）
    local yinYangRot = time * 2.0
    nvgBeginPath(nvg)
    nvgArc(nvg, sx, sy, yinYangR, yinYangRot, yinYangRot + math.pi, NVG_CW)
    nvgFillColor(nvg, nvgRGBA(r, g, b, math.floor(80 * pulse)))
    nvgFill(nvg)

    -- 6. 中心状态文字标签
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(nvg, nvgRGBA(r, g, b, math.floor(200 * pulse)))
    local label = "八卦"
    if boss.dualState and boss.dualState.states and stateKey then
        local stateInfo = boss.dualState.states[stateKey]
        if stateInfo then label = stateInfo.name or label end
    end
    nvgText(nvg, sx, sy - radius - 4, label, nil)
end

-- ============================================================================
-- 套装AOE特效渲染（圆形冲击波 + 内圈光晕，颜色从数据读取）
-- ============================================================================
function EffectRenderer.RenderSetAoeEffects(nvg, l, camera)
    local effects = CombatSystem.setAoeEffects
    if not effects or #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local se = effects[i]

        if camera:IsVisible(se.x, se.y, l.w, l.h, 4) then
            local sx = (se.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (se.y - camera.y) * tileSize + l.h / 2 + l.y

            local progress = se.elapsed / se.duration
            local c = se.color
            local gc = se.glowColor

            -- 透明度：快速出现，缓慢淡出
            local alpha = 1.0
            if progress < 0.1 then
                alpha = progress / 0.1
            elseif progress > 0.3 then
                alpha = 1.0 - (progress - 0.3) / 0.7
            end
            alpha = math.max(0, math.min(1, alpha))

            -- 扩展动画：快速展开
            local expand = 1.0
            if progress < 0.2 then
                local t = progress / 0.2
                expand = t * (2.0 - t)  -- easeOut
            end

            local radius = se.range * tileSize * expand

            nvgSave(nvg)

            -- 外圈冲击波圆环（从内向外扩散）
            local waveRadius = radius * (0.3 + 0.7 * progress)
            local waveAlpha = math.floor(200 * alpha * (1.0 - progress * 0.5))

            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, waveRadius)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], waveAlpha))
            nvgStrokeWidth(nvg, 3.0 * (1.0 - progress * 0.5))
            nvgStroke(nvg)

            -- 内圈光晕填充
            local innerR = radius * 0.7 * expand
            local glowPaint = nvgRadialGradient(nvg, sx, sy, 0, innerR,
                nvgRGBA(gc[1], gc[2], gc[3], math.floor(gc[4] * alpha)),
                nvgRGBA(gc[1], gc[2], gc[3], 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, innerR)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)

            -- 第二层外圈波纹（稍慢扩散，增加层次感）
            local wave2Radius = radius * (0.1 + 0.9 * progress)
            local wave2Alpha = math.floor(120 * alpha * (1.0 - progress * 0.7))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, wave2Radius)
            nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], wave2Alpha))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)

            nvgRestore(nvg)
        end
    end
end

-- ============================================================================
-- Buff 光环渲染：玩家身上 buff 期间的持续视觉表现
-- ============================================================================
function EffectRenderer.RenderBuffAuras(nvg, l, camera)
    local player = GameState.player
    if not player then return end

    -- 玩家是否在可见范围
    if not camera:IsVisible(player.x, player.y, l.w, l.h, 3) then return end

    -- ── 焚血之躯持续光环（半径3格，强烈燃烧 + 火焰边界） ──
    local burnState = SkillSystem.skillState and SkillSystem.skillState["blood_burn"]
    if burnState and burnState.active then
        local tileSize = camera:GetTileSize()
        local sx = (player.x - camera.x) * tileSize + l.w / 2 + l.x
        local sy = (player.y - camera.y) * tileSize + l.h / 2 + l.y
        local time = GameState.gameTime or 0
        local burnRadius = tileSize * 3.0  -- 半径3格
        local breathPhase = math.sin(time * 2.5) * 0.5 + 0.5  -- 0~1 呼吸

        -- ① 大范围地面燃烧区域（径向渐变填充）
        local groundAlpha = math.floor(35 + 20 * breathPhase)
        local groundPaint = nvgRadialGradient(nvg, sx, sy,
            burnRadius * 0.1, burnRadius * 0.95,
            nvgRGBA(200, 60, 20, groundAlpha),
            nvgRGBA(180, 40, 10, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, burnRadius)
        nvgFillPaint(nvg, groundPaint)
        nvgFill(nvg)

        -- ② 半透明边界线（明确范围，随呼吸微调透明度）
        local borderAlpha = math.floor((60 + 30 * breathPhase))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, burnRadius)
        nvgStrokeColor(nvg, nvgRGBA(255, 100, 30, borderAlpha))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- ④ 自身强烈灼烧特效（脚底大火焰光环）
        local selfGlow = math.floor(70 + 40 * breathPhase)
        local selfRadius = tileSize * 0.7
        local selfPaint = nvgRadialGradient(nvg, sx, sy + tileSize * 0.15,
            selfRadius * 0.05, selfRadius,
            nvgRGBA(255, 100, 20, selfGlow),
            nvgRGBA(200, 40, 10, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy + tileSize * 0.15, selfRadius)
        nvgFillPaint(nvg, selfPaint)
        nvgFill(nvg)

        -- ⑤ 自身火焰粒子上浮（8个，比之前多且大）
        for j = 0, 7 do
            local pAngle = (j / 8) * math.pi * 2 + time * 2.0
            local dist = tileSize * (0.15 + 0.2 * math.sin(time * 2.5 + j * 0.8))
            local px = sx + math.cos(pAngle) * dist
            local rise = math.fmod(time * 0.9 + j * 0.125, 1.0)
            local py = sy - tileSize * (0.1 + 0.6 * rise)
            local pA = math.floor(200 * (1.0 - rise))
            local pR = 2.5 + 1.5 * (1.0 - rise)
            if pA > 15 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, pR)
                nvgFillColor(nvg, nvgRGBA(255, 140, 30, pA))
                nvgFill(nvg)
            end
        end

        -- ⑥ 区域内散布的火星（6个随机飘浮）
        for j = 0, 5 do
            local sparkAngle = time * 0.4 + j * 1.05
            local sparkDist = burnRadius * (0.3 + 0.5 * math.fmod(math.sin(j * 2.3 + time * 0.3) * 0.5 + 0.5, 1.0))
            local sparkX = sx + math.cos(sparkAngle) * sparkDist
            local sparkY = sy + math.sin(sparkAngle) * sparkDist
            local sparkRise = math.fmod(time * 0.7 + j * 0.4, 1.0)
            sparkY = sparkY - tileSize * 0.4 * sparkRise
            local sparkA = math.floor(100 * (1.0 - sparkRise))
            if sparkA > 10 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, sparkX, sparkY, 1.8)
                nvgFillColor(nvg, nvgRGBA(255, 180, 60, sparkA))
                nvgFill(nvg)
            end
        end
    end

    -- ── 浩然正气 buff ──
    local buff = CombatSystem.activeBuffs and CombatSystem.activeBuffs["haoran_zhengqi"]
    if not buff then return end

    local tileSize = camera:GetTileSize()
    local sx = (player.x - camera.x) * tileSize + l.w / 2 + l.x
    local sy = (player.y - camera.y) * tileSize + l.h / 2 + l.y
    local time = GameState.gameTime or 0

    local c = buff.color or {60, 180, 255, 255}
    local remaining = buff.remaining or 0
    local duration = buff.duration or 12

    -- 即将过期闪烁（最后3秒）
    local expireFlicker = 1.0
    if remaining <= 3.0 and remaining > 0 then
        -- 快速闪烁：每0.25秒一次，透明度在0.3~1.0间跳动
        expireFlicker = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(remaining * math.pi * 4))
    end

    -- ═══ ① 脚底呼吸光环（正气蓝椭圆） ═══
    local breathPhase = math.sin(time * 2.5) * 0.5 + 0.5  -- 0~1 呼吸节奏
    local auraRx = tileSize * (0.55 + 0.08 * breathPhase)  -- 水平半径
    local auraRy = tileSize * (0.22 + 0.03 * breathPhase)  -- 竖直半径（扁椭圆）
    local auraAlpha = math.floor((60 + 40 * breathPhase) * expireFlicker)

    -- 径向渐变填充
    local auraPaint = nvgRadialGradient(nvg, sx, sy + tileSize * 0.3,
        auraRx * 0.1, auraRx * 0.9,
        nvgRGBA(c[1], c[2], c[3], auraAlpha),
        nvgRGBA(c[1], c[2], c[3], 0))
    nvgSave(nvg)
    nvgBeginPath(nvg)
    -- 用 save/translate/scale 模拟椭圆
    nvgTranslate(nvg, sx, sy + tileSize * 0.3)
    nvgScale(nvg, 1.0, auraRy / auraRx)
    nvgCircle(nvg, 0, 0, auraRx)
    nvgFillPaint(nvg, auraPaint)
    nvgFill(nvg)
    nvgRestore(nvg)

    -- 光环边缘描边
    local edgeAlpha = math.floor((100 + 50 * breathPhase) * expireFlicker)
    nvgSave(nvg)
    nvgBeginPath(nvg)
    nvgTranslate(nvg, sx, sy + tileSize * 0.3)
    nvgScale(nvg, 1.0, auraRy / auraRx)
    nvgCircle(nvg, 0, 0, auraRx)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], edgeAlpha))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    nvgRestore(nvg)

    -- ═══ ② 三条旋转正气弧线（环绕角色） ═══
    local orbR = tileSize * 0.45  -- 轨道半径
    for j = 0, 2 do
        local baseAngle = j * math.pi * 2 / 3 + time * 1.8  -- 匀速旋转
        local arcLen = math.pi * 0.4  -- 弧线长度（约 72°）
        local arcAlpha = math.floor(160 * expireFlicker)

        -- 每条弧线色相微偏移（蓝→青→蓝白）
        local cr = math.min(255, c[1] + j * 20)
        local cg = math.min(255, c[2] + j * 12)
        local cb = math.min(255, c[3] - j * 8)

        nvgBeginPath(nvg)
        nvgArc(nvg, sx, sy, orbR, baseAngle, baseAngle + arcLen, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(cr, cg, cb, arcAlpha))
        nvgStrokeWidth(nvg, 2.0)
        nvgLineCap(nvg, NVG_ROUND)
        nvgStroke(nvg)
    end

    -- ═══ ③ 竖向正气柱光线（角色身体周围淡淡的升腾感） ═══
    local pillarAlpha = math.floor(35 * expireFlicker)
    local pillarW = tileSize * 0.06
    local pillarH = tileSize * 0.9
    -- 两道对称淡光柱
    for j = -1, 1, 2 do
        local px = sx + j * tileSize * 0.18
        local pillarPaint = nvgLinearGradient(nvg,
            px, sy - pillarH * 0.5,
            px, sy + pillarH * 0.3,
            nvgRGBA(c[1], c[2], c[3], pillarAlpha),
            nvgRGBA(c[1], c[2], c[3], 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, px - pillarW * 0.5, sy - pillarH * 0.5, pillarW, pillarH)
        nvgFillPaint(nvg, pillarPaint)
        nvgFill(nvg)
    end
end

return EffectRenderer
