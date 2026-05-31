-- entities/player.lua - 玩家渲染
local shared = require("rendering.entities.shared")
local GameConfig = shared.GameConfig
local GameState = shared.GameState
local T = shared.T
local RenderUtils = shared.RenderUtils
local DecorationRenderers = shared.DecorationRenderers
local TitleSystem = shared.TitleSystem
local CombatSystem = shared.CombatSystem
local PetAppearanceConfig = shared.PetAppearanceConfig
local getRealmColorGroup = shared.getRealmColorGroup

local M = {}
function M.RenderPlayer(nvg, l, camera)
    local player = GameState.player
    if not player or not player.alive then return end

    local sx, sy = RenderUtils.WorldToLocal(player.x, player.y, camera, l)
    local ts = camera:GetTileSize()
    local uiTs = GameConfig.TILE_SIZE  -- UI 元素（血条/铭牌）保持固定大小

    -- 受伤闪烁
    local flash = (player.hurtFlashTimer or 0) > 0 and math.floor((player.hurtFlashTimer or 0) * 20) % 2 == 0

    -- 视觉大小约 1.5 格
    local spriteSize = ts * 1.5
    local halfSize = spriteSize / 2

    -- 统一使用右朝向图片，左朝向通过水平翻转实现
    local CLASS_SPRITES = {
        taixu   = "Textures/class_swordsman_right.png",
        zhenyue = "Textures/class_body_cultivator_right.png",
    }
    local spritePath = CLASS_SPRITES[player.classId] or "Textures/player_right.png"
    local imgHandle = RenderUtils.GetCachedImage(nvg, spritePath)

    if imgHandle then
        nvgSave(nvg)
        -- 左朝向时水平翻转
        if not player.facingRight then
            nvgTranslate(nvg, sx, 0)
            nvgScale(nvg, -1, 1)
            nvgTranslate(nvg, -sx, 0)
        end

        local imgX = sx - halfSize
        local imgY = sy - halfSize * 1.1

        -- 受伤闪烁：交替显示原图和纯白剪影（贴合角色轮廓）
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgHandle, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)

        if flash then
            -- 叠加一层：用 SRC_ALPHA + ONE 加法混合，把图片当蒙版叠白红色
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local tintPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgHandle, 0.7)
            nvgBeginPath(nvg)
            nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
            nvgFillPaint(nvg, tintPaint)
            nvgFill(nvg)
            -- 恢复默认混合模式
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
        end
        nvgRestore(nvg)
    else
        -- 回退：原有色块渲染
        local C = GameConfig.COLORS
        local bodyW = ts * 0.5
        local bodyH = ts * 0.6
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, sx - bodyW / 2, sy - bodyH * 0.3, bodyW, bodyH, 3)
        if flash then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        else
            nvgFillColor(nvg, nvgRGBA(C.player[1], C.player[2], C.player[3], 255))
        end
        nvgFill(nvg)
    end

    -- ── 头顶 HP 条 + 境界铭牌 + 名字（在精灵翻转之外绘制） ──
    local barW = uiTs * 1.2  -- 玩家血条用 uiTs，缩放时宽度不变
    local barH = T.size.monsterBarH + 1
    local totalMaxHp = player:GetTotalMaxHp()
    local hpRatio = totalMaxHp > 0 and (player.hp / totalMaxHp) or 0
    local imgTopY = sy - halfSize * 1.1  -- 精灵顶边

    -- HP 条位置
    local hpBarY = imgTopY - barH - 3

    -- HP 条背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx - barW / 2, hpBarY, barW, barH, 2)
    nvgFillColor(nvg, nvgRGBA(40, 0, 0, 180))
    nvgFill(nvg)

    -- HP 填充（三段变色，颜色表已提升到模块级）
    if hpRatio > 0 then
        local hpColor = getHpColor(hpRatio)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, sx - barW / 2, hpBarY, barW * hpRatio, barH, 2)
        nvgFillColor(nvg, nvgRGBA(hpColor[1], hpColor[2], hpColor[3], hpColor[4]))
        nvgFill(nvg)
    end

    -- HP 条边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx - barW / 2, hpBarY, barW, barH, 2)
    nvgStrokeColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgStrokeWidth(nvg, 0.5)
    nvgStroke(nvg)

    -- ── 境界铭牌（多级配色 + 加大） ──
    local realmData = GameConfig.REALMS[player.realm]
    local realmName = realmData and realmData.name or "凡人"
    local realmOrder = realmData and realmData.order or 0
    -- P2-5: 缓存 realmText（realm/level 变化极低频）
    local rk = realmName .. "|" .. player.level
    if rk ~= shared._cachedRealmKey then
        shared._cachedRealmKey = rk
        shared._cachedRealmText = realmName .. " Lv." .. player.level
    end
    local realmText = shared._cachedRealmText

    -- 境界铭牌多级配色（颜色查找表已提升到模块级）
    local realmColorGroup = getRealmColorGroup(realmOrder)
    local realmBg = realmColorGroup.bg
    local realmFg = realmColorGroup.fg
    local realmBorder = realmColorGroup.border

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, T.worldFont.realmBadge)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 测量文字宽度
    local textW = nvgTextBounds(nvg, 0, 0, realmText, nil)
    local pillW = textW + 14
    local pillH = T.worldFont.realmBadge + 6
    local pillCenterY = hpBarY - pillH / 2 - 2

    -- 药丸背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx - pillW / 2, pillCenterY - pillH / 2, pillW, pillH, pillH / 2)
    nvgFillColor(nvg, nvgRGBA(realmBg[1], realmBg[2], realmBg[3], realmBg[4]))
    nvgFill(nvg)

    -- 铭牌边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx - pillW / 2, pillCenterY - pillH / 2, pillW, pillH, pillH / 2)
    nvgStrokeColor(nvg, nvgRGBA(realmBorder[1], realmBorder[2], realmBorder[3], realmBorder[4]))
    nvgStrokeWidth(nvg, 0.8)
    nvgStroke(nvg)

    -- 铭牌文字
    nvgFillColor(nvg, nvgRGBA(realmFg[1], realmFg[2], realmFg[3], realmFg[4]))
    nvgText(nvg, sx, pillCenterY, realmText, nil)

    -- ── 称号标签（铭牌上方，2倍铭牌尺寸，直角框） ──
    local equippedTitle = TitleSystem.GetEquipped()
    if equippedTitle then
        local titleFontSize = math.floor(T.worldFont.realmBadge * 1.5)
        nvgFontSize(nvg, titleFontSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- P2-5: 缓存 titleText（称号几乎不变）
        local tn = equippedTitle.name
        if tn ~= shared._cachedTitleName then
            shared._cachedTitleName = tn
            shared._cachedTitleText = "「" .. tn .. "」"
        end
        local titleText = shared._cachedTitleText
        local tTextW = nvgTextBounds(nvg, 0, 0, titleText, nil)
        local tBoxW = tTextW + 21
        local tBoxH = titleFontSize + 14
        local tBoxY = pillCenterY - pillH / 2 - tBoxH / 2 - 3

        local tc = equippedTitle.color or {100, 200, 100, 255}
        local tBg = equippedTitle.bgColor or {30, 60, 30, 220}
        local tBorder = equippedTitle.borderColor or {80, 160, 80, 200}

        -- 称号背景（边缘透明度渐变，无描边）
        local feather = 8
        local inset = 4
        local bgPaint = nvgBoxGradient(nvg,
            sx - tBoxW / 2 + inset, tBoxY - tBoxH / 2 + inset,
            tBoxW - inset * 2, tBoxH - inset * 2,
            2, feather,
            nvgRGBA(tBg[1], tBg[2], tBg[3], tBg[4]),
            nvgRGBA(tBg[1], tBg[2], tBg[3], 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, sx - tBoxW / 2 - feather, tBoxY - tBoxH / 2 - feather,
                     tBoxW + feather * 2, tBoxH + feather * 2)
        nvgFillPaint(nvg, bgPaint)
        nvgFill(nvg)

        -- 称号框体装饰（高级称号：四角装饰 + 发光）
        -- tier: 0=无装饰, 1=蓝色四角, 2=紫色豪华四角, 4=青蓝波纹, 5=刀剑交叉
        local titleTier = equippedTitle.tier or 0
        if titleTier == 0 then
            if equippedTitle.id == "pioneer" or equippedTitle.id == "jianghu_hero" then titleTier = 1 end
            if equippedTitle.id == "young_hero" then titleTier = 2 end
        end

        if titleTier == 2 then
            -- ═══ 紫色豪华装饰：四角+上下横线+外层光晕+菱形点缀 ═══
            local cornerLen = 12
            local pad = 4
            local cx1 = sx - tBoxW / 2 - pad
            local cy1 = tBoxY - tBoxH / 2 - pad
            local cx2 = sx + tBoxW / 2 + pad
            local cy2 = tBoxY + tBoxH / 2 + pad
            local time = GameState.gameTime or 0
            local pulse = math.sin(time * 3.0) * 0.25 + 0.75

            -- 外层光晕（紫色径向渐变）
            local glowR = math.max(tBoxW, tBoxH) * 0.7
            local glowPaint = nvgRadialGradient(nvg,
                sx, tBoxY, glowR * 0.3, glowR,
                nvgRGBA(tBorder[1], tBorder[2], tBorder[3], math.floor(35 * pulse)),
                nvgRGBA(tBorder[1], tBorder[2], tBorder[3], 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, tBoxY, glowR)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)

            -- 发光层（粗、半透明四角）
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], math.floor(70 * pulse)))
            nvgStrokeWidth(nvg, 5)
            nvgLineCap(nvg, NVG_ROUND)
            nvgLineJoin(nvg, NVG_ROUND)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1, cy1 + cornerLen)
            nvgLineTo(nvg, cx1, cy1)
            nvgLineTo(nvg, cx1 + cornerLen, cy1)
            nvgMoveTo(nvg, cx2 - cornerLen, cy1)
            nvgLineTo(nvg, cx2, cy1)
            nvgLineTo(nvg, cx2, cy1 + cornerLen)
            nvgMoveTo(nvg, cx1, cy2 - cornerLen)
            nvgLineTo(nvg, cx1, cy2)
            nvgLineTo(nvg, cx1 + cornerLen, cy2)
            nvgMoveTo(nvg, cx2 - cornerLen, cy2)
            nvgLineTo(nvg, cx2, cy2)
            nvgLineTo(nvg, cx2, cy2 - cornerLen)
            nvgStroke(nvg)

            -- 实线层（清晰四角）
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], tBorder[4]))
            nvgStrokeWidth(nvg, 2.5)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1, cy1 + cornerLen)
            nvgLineTo(nvg, cx1, cy1)
            nvgLineTo(nvg, cx1 + cornerLen, cy1)
            nvgMoveTo(nvg, cx2 - cornerLen, cy1)
            nvgLineTo(nvg, cx2, cy1)
            nvgLineTo(nvg, cx2, cy1 + cornerLen)
            nvgMoveTo(nvg, cx1, cy2 - cornerLen)
            nvgLineTo(nvg, cx1, cy2)
            nvgLineTo(nvg, cx1 + cornerLen, cy2)
            nvgMoveTo(nvg, cx2 - cornerLen, cy2)
            nvgLineTo(nvg, cx2, cy2)
            nvgLineTo(nvg, cx2, cy2 - cornerLen)
            nvgStroke(nvg)

            -- 上下横线装饰
            local lineInset = cornerLen + 2
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], math.floor(160 * pulse)))
            nvgStrokeWidth(nvg, 1.5)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1 + lineInset, cy1)
            nvgLineTo(nvg, cx2 - lineInset, cy1)
            nvgMoveTo(nvg, cx1 + lineInset, cy2)
            nvgLineTo(nvg, cx2 - lineInset, cy2)
            nvgStroke(nvg)

            -- 中央菱形点缀（上下各一个）
            local diamondSize = 3
            nvgFillColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], math.floor(200 * pulse)))
            for _di = 1, 2 do
                local dy = _di == 1 and cy1 or cy2
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, sx, dy - diamondSize)
                nvgLineTo(nvg, sx + diamondSize, dy)
                nvgLineTo(nvg, sx, dy + diamondSize)
                nvgLineTo(nvg, sx - diamondSize, dy)
                nvgClosePath(nvg)
                nvgFill(nvg)
            end

        elseif titleTier == 5 then
            -- ═══ 交叉标记装饰（千人斩/万人屠系列） ═══
            local pad = 4
            local cx1 = sx - tBoxW / 2 - pad
            local cy1 = tBoxY - tBoxH / 2 - pad
            local cx2 = sx + tBoxW / 2 + pad
            local cy2 = tBoxY + tBoxH / 2 + pad
            local time = GameState.gameTime or 0
            local pulse = math.sin(time * 2.5) * 0.2 + 0.8
            local ba = math.floor(200 * pulse)

            -- ── 左右 ✕ 交叉标记 ──
            local crossSize = 6
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], ba))
            nvgStrokeWidth(nvg, 2.0)
            nvgLineCap(nvg, NVG_ROUND)

            for _mi = 1, 2 do
                local markX = _mi == 1 and (cx1 - 6) or (cx2 + 6)
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, markX - crossSize, tBoxY - crossSize)
                nvgLineTo(nvg, markX + crossSize, tBoxY + crossSize)
                nvgMoveTo(nvg, markX + crossSize, tBoxY - crossSize)
                nvgLineTo(nvg, markX - crossSize, tBoxY + crossSize)
                nvgStroke(nvg)
            end

            -- ── 四角短角线 ──
            local cornerLen = 8
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], ba))
            nvgStrokeWidth(nvg, 1.8)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1, cy1 + cornerLen)
            nvgLineTo(nvg, cx1, cy1)
            nvgLineTo(nvg, cx1 + cornerLen, cy1)
            nvgMoveTo(nvg, cx2 - cornerLen, cy1)
            nvgLineTo(nvg, cx2, cy1)
            nvgLineTo(nvg, cx2, cy1 + cornerLen)
            nvgMoveTo(nvg, cx1, cy2 - cornerLen)
            nvgLineTo(nvg, cx1, cy2)
            nvgLineTo(nvg, cx1 + cornerLen, cy2)
            nvgMoveTo(nvg, cx2 - cornerLen, cy2)
            nvgLineTo(nvg, cx2, cy2)
            nvgLineTo(nvg, cx2, cy2 - cornerLen)
            nvgStroke(nvg)

        elseif titleTier == 6 then
            -- ═══ 火焰光效装饰（万人屠） ═══
            local pad = 5
            local cx1 = sx - tBoxW / 2 - pad
            local cy1 = tBoxY - tBoxH / 2 - pad
            local cx2 = sx + tBoxW / 2 + pad
            local cy2 = tBoxY + tBoxH / 2 + pad
            local time = GameState.gameTime or 0
            local pulse = math.sin(time * 3.0) * 0.25 + 0.75

            -- 外层火焰光晕（橙色径向渐变）
            local glowR = math.max(tBoxW, tBoxH) * 0.85
            local glowPaint = nvgRadialGradient(nvg,
                sx, tBoxY, glowR * 0.2, glowR,
                nvgRGBA(255, 140, 20, math.floor(50 * pulse)),
                nvgRGBA(255, 80, 0, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, tBoxY, glowR)
            nvgFillPaint(nvg, glowPaint)
            nvgFill(nvg)

            -- 内层暖光
            local innerR = math.max(tBoxW, tBoxH) * 0.45
            local innerPaint = nvgRadialGradient(nvg,
                sx, tBoxY, innerR * 0.1, innerR,
                nvgRGBA(255, 200, 80, math.floor(35 * pulse)),
                nvgRGBA(255, 160, 40, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, tBoxY, innerR)
            nvgFillPaint(nvg, innerPaint)
            nvgFill(nvg)

            -- 火焰粒子（上升的火星）
            for i = 1, 6 do
                local seed = i * 1.37
                local px = sx + math.sin(time * 1.8 + seed * 3.0) * (tBoxW * 0.5 + 4)
                local life = (time * 0.8 + seed) % 1.0  -- 0~1 生命周期
                local py = tBoxY + (1.0 - life) * 18 - 9  -- 从下往上
                local alpha = math.sin(life * math.pi) * 200  -- 中间最亮
                local sz = 1.5 + (1.0 - life) * 1.5
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, sz)
                nvgFillColor(nvg, nvgRGBA(255, math.floor(180 - life * 100), math.floor(40 - life * 40), math.floor(alpha)))
                nvgFill(nvg)
            end

            -- 发光四角（粗光晕层）
            local cornerLen = 10
            nvgStrokeColor(nvg, nvgRGBA(255, 160, 40, math.floor(80 * pulse)))
            nvgStrokeWidth(nvg, 5)
            nvgLineCap(nvg, NVG_ROUND)
            nvgLineJoin(nvg, NVG_ROUND)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1, cy1 + cornerLen)
            nvgLineTo(nvg, cx1, cy1)
            nvgLineTo(nvg, cx1 + cornerLen, cy1)
            nvgMoveTo(nvg, cx2 - cornerLen, cy1)
            nvgLineTo(nvg, cx2, cy1)
            nvgLineTo(nvg, cx2, cy1 + cornerLen)
            nvgMoveTo(nvg, cx1, cy2 - cornerLen)
            nvgLineTo(nvg, cx1, cy2)
            nvgLineTo(nvg, cx1 + cornerLen, cy2)
            nvgMoveTo(nvg, cx2 - cornerLen, cy2)
            nvgLineTo(nvg, cx2, cy2)
            nvgLineTo(nvg, cx2, cy2 - cornerLen)
            nvgStroke(nvg)

            -- 实线四角
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], tBorder[4]))
            nvgStrokeWidth(nvg, 2.5)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1, cy1 + cornerLen)
            nvgLineTo(nvg, cx1, cy1)
            nvgLineTo(nvg, cx1 + cornerLen, cy1)
            nvgMoveTo(nvg, cx2 - cornerLen, cy1)
            nvgLineTo(nvg, cx2, cy1)
            nvgLineTo(nvg, cx2, cy1 + cornerLen)
            nvgMoveTo(nvg, cx1, cy2 - cornerLen)
            nvgLineTo(nvg, cx1, cy2)
            nvgLineTo(nvg, cx1 + cornerLen, cy2)
            nvgMoveTo(nvg, cx2 - cornerLen, cy2)
            nvgLineTo(nvg, cx2, cy2)
            nvgLineTo(nvg, cx2, cy2 - cornerLen)
            nvgStroke(nvg)

            -- ✕ 交叉标记（带火焰色光晕）
            local crossSize = 6
            for _mi = 1, 2 do
                local markX = _mi == 1 and (cx1 - 6) or (cx2 + 6)
                -- 光晕层
                nvgStrokeColor(nvg, nvgRGBA(255, 140, 20, math.floor(90 * pulse)))
                nvgStrokeWidth(nvg, 4)
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, markX - crossSize, tBoxY - crossSize)
                nvgLineTo(nvg, markX + crossSize, tBoxY + crossSize)
                nvgMoveTo(nvg, markX + crossSize, tBoxY - crossSize)
                nvgLineTo(nvg, markX - crossSize, tBoxY + crossSize)
                nvgStroke(nvg)
                -- 实线层
                nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], 255))
                nvgStrokeWidth(nvg, 2.0)
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, markX - crossSize, tBoxY - crossSize)
                nvgLineTo(nvg, markX + crossSize, tBoxY + crossSize)
                nvgMoveTo(nvg, markX + crossSize, tBoxY - crossSize)
                nvgLineTo(nvg, markX - crossSize, tBoxY + crossSize)
                nvgStroke(nvg)
            end

        elseif titleTier == 4 then
            -- ═══ 青蓝波纹装饰（资深仙友） ═══
            local pad = 3
            local cx1 = sx - tBoxW / 2 - pad
            local cy1 = tBoxY - tBoxH / 2 - pad
            local cx2 = sx + tBoxW / 2 + pad
            local cy2 = tBoxY + tBoxH / 2 + pad
            local time = GameState.gameTime or 0

            -- 上下波纹线（正弦曲线）
            local segments = 12
            local waveAmp = 2.5
            local waveW = (cx2 - cx1)

            for _wi = 1, 2 do
                local wy = _wi == 1 and cy1 or cy2
                local phase = _wi == 1 and 0 or math.pi
                nvgBeginPath(nvg)
                for s = 0, segments do
                    local t = s / segments
                    local wx = cx1 + t * waveW
                    local oy = math.sin(t * math.pi * 3 + time * 2.0 + phase) * waveAmp
                    if s == 0 then
                        nvgMoveTo(nvg, wx, wy + oy)
                    else
                        nvgLineTo(nvg, wx, wy + oy)
                    end
                end
                nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], 180))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
            end

            -- 左右短竖线点缀
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], 150))
            nvgStrokeWidth(nvg, 1.5)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1, cy1 + 3)
            nvgLineTo(nvg, cx1, cy2 - 3)
            nvgMoveTo(nvg, cx2, cy1 + 3)
            nvgLineTo(nvg, cx2, cy2 - 3)
            nvgStroke(nvg)

        elseif titleTier >= 1 then
            -- ═══ 基础四角装饰（先驱者/江湖豪杰等） ═══
            local cornerLen = 10
            local pad = 3
            local cx1 = sx - tBoxW / 2 - pad
            local cy1 = tBoxY - tBoxH / 2 - pad
            local cx2 = sx + tBoxW / 2 + pad
            local cy2 = tBoxY + tBoxH / 2 + pad

            -- 发光层（更粗、半透明）
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], 80))
            nvgStrokeWidth(nvg, 4)
            nvgLineCap(nvg, NVG_ROUND)
            nvgLineJoin(nvg, NVG_ROUND)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1, cy1 + cornerLen)
            nvgLineTo(nvg, cx1, cy1)
            nvgLineTo(nvg, cx1 + cornerLen, cy1)
            nvgMoveTo(nvg, cx2 - cornerLen, cy1)
            nvgLineTo(nvg, cx2, cy1)
            nvgLineTo(nvg, cx2, cy1 + cornerLen)
            nvgMoveTo(nvg, cx1, cy2 - cornerLen)
            nvgLineTo(nvg, cx1, cy2)
            nvgLineTo(nvg, cx1 + cornerLen, cy2)
            nvgMoveTo(nvg, cx2 - cornerLen, cy2)
            nvgLineTo(nvg, cx2, cy2)
            nvgLineTo(nvg, cx2, cy2 - cornerLen)
            nvgStroke(nvg)

            -- 实线层（清晰锐利）
            nvgStrokeColor(nvg, nvgRGBA(tBorder[1], tBorder[2], tBorder[3], tBorder[4]))
            nvgStrokeWidth(nvg, 2)

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx1, cy1 + cornerLen)
            nvgLineTo(nvg, cx1, cy1)
            nvgLineTo(nvg, cx1 + cornerLen, cy1)
            nvgMoveTo(nvg, cx2 - cornerLen, cy1)
            nvgLineTo(nvg, cx2, cy1)
            nvgLineTo(nvg, cx2, cy1 + cornerLen)
            nvgMoveTo(nvg, cx1, cy2 - cornerLen)
            nvgLineTo(nvg, cx1, cy2)
            nvgLineTo(nvg, cx1 + cornerLen, cy2)
            nvgMoveTo(nvg, cx2 - cornerLen, cy2)
            nvgLineTo(nvg, cx2, cy2)
            nvgLineTo(nvg, cx2, cy2 - cornerLen)
            nvgStroke(nvg)
        end

        -- 称号文字
        nvgFillColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], tc[4]))
        nvgText(nvg, sx, tBoxY, titleText, nil)
    end

    -- ── 犬魂狂暴特效 ──
    if player:IsPetBerserkActive() then
        local time = GameState.gameTime or 0
        local pulse = math.sin(time * 4.0) * 0.3 + 0.7
        local auraR = halfSize * 1.1

        -- 红色脉冲光环（外层）
        local outerR = auraR + 4 + math.sin(time * 3.0) * 2
        local outerGlow = nvgRadialGradient(nvg, sx, sy - halfSize * 0.1,
            auraR * 0.5, outerR,
            nvgRGBA(255, 60, 30, math.floor(40 * pulse)),
            nvgRGBA(255, 60, 30, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy - halfSize * 0.1, outerR)
        nvgFillPaint(nvg, outerGlow)
        nvgFill(nvg)

        -- 红色描边光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy - halfSize * 0.1, auraR)
        nvgStrokeColor(nvg, nvgRGBA(255, 80, 50, math.floor(120 * pulse)))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 旋转火焰粒子（6个小点绕身体旋转）
        for pi = 0, 5 do
            local angle = pi * math.pi / 3 + time * 2.5
            local pr = auraR + 2
            local px = sx + math.cos(angle) * pr
            local py = (sy - halfSize * 0.1) + math.sin(angle) * pr
            local sparkAlpha = math.sin(time * 5 + pi * 1.5) * 0.3 + 0.7
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 2)
            nvgFillColor(nvg, nvgRGBA(255, 120, 30, math.floor(200 * sparkAlpha)))
            nvgFill(nvg)
        end

        -- 脚底"狂暴"文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.level)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        local textPulse = math.sin(time * 3.0) * 0.2 + 0.8
        nvgFillColor(nvg, nvgRGBA(255, 100, 60, math.floor(220 * textPulse)))
        local remaining = math.ceil(player.petBerserkTimer)
        nvgText(nvg, sx, sy + halfSize * 0.3, "🔥狂暴 " .. remaining .. "s", nil)
    end

    -- ── 金钟罩护盾特效 ──
    if player.shieldHp and player.shieldHp > 0 then
        local time = GameState.gameTime or 0
        local shieldRatio = (player.shieldMaxHp and player.shieldMaxHp > 0)
            and (player.shieldHp / player.shieldMaxHp) or 1.0
        local pulse = math.sin(time * 2.5) * 0.15 + 0.85
        local auraR = halfSize * 1.15

        -- 金色护盾光环（径向渐变）
        local shieldAlpha = math.floor(60 * shieldRatio * pulse)
        local outerGlow = nvgRadialGradient(nvg, sx, sy - halfSize * 0.1,
            auraR * 0.3, auraR,
            nvgRGBA(255, 215, 80, shieldAlpha),
            nvgRGBA(255, 215, 80, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy - halfSize * 0.1, auraR)
        nvgFillPaint(nvg, outerGlow)
        nvgFill(nvg)

        -- 护盾描边圆环
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy - halfSize * 0.1, auraR - 1)
        nvgStrokeColor(nvg, nvgRGBA(255, 220, 100, math.floor(140 * shieldRatio * pulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 护盾剩余值文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.level)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        local shieldTextAlpha = math.floor(200 * pulse)
        nvgFillColor(nvg, nvgRGBA(255, 225, 100, shieldTextAlpha))
        local shieldRemaining = math.ceil(player.shieldTimer or 0)
        -- 狂暴同时存在时错开 Y 位置
        local shieldTextY = sy + halfSize * 0.3
        if player:IsPetBerserkActive() then
            shieldTextY = shieldTextY + T.worldFont.level + 2
        end
        nvgText(nvg, sx, shieldTextY, "🛡️" .. player.shieldHp .. " " .. shieldRemaining .. "s", nil)
    end

    -- ── 文王护体护盾特效（常驻青色八卦光环） ──
    local okCh4_, ArtifactCh4_ = pcall(require, "systems.ArtifactSystem_ch4")
    if okCh4_ and ArtifactCh4_ and ArtifactCh4_.passiveUnlocked then
        local sHp, sMax = ArtifactCh4_.GetShieldStatus()
        if sMax > 0 then
            local time = GameState.gameTime or 0
            local ratio = sHp / sMax
            local pulse = math.sin(time * 2.0) * 0.15 + 0.85
            local auraR = halfSize * 1.25

            -- 护盾存在时：青色光环
            if sHp > 0 then
                local a = math.floor(50 * ratio * pulse)
                local glow = nvgRadialGradient(nvg, sx, sy - halfSize * 0.1,
                    auraR * 0.2, auraR,
                    nvgRGBA(80, 200, 255, a),
                    nvgRGBA(80, 200, 255, 0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy - halfSize * 0.1, auraR)
                nvgFillPaint(nvg, glow)
                nvgFill(nvg)

                -- 描边圆环
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy - halfSize * 0.1, auraR - 1)
                nvgStrokeColor(nvg, nvgRGBA(100, 210, 255, math.floor(120 * ratio * pulse)))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)

                -- 旋转八卦纹（小型，2条弧线）
                local rot = time * 1.2
                for j = 0, 1 do
                    local arcA = rot + j * math.pi
                    nvgBeginPath(nvg)
                    nvgArc(nvg, sx, sy - halfSize * 0.1, auraR * 0.7,
                        arcA, arcA + math.pi * 0.3, NVG_CW)
                    nvgStrokeColor(nvg, nvgRGBA(120, 220, 255, math.floor(80 * ratio * pulse)))
                    nvgStrokeWidth(nvg, 1.2)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end
            end

            -- 脚底文字（护盾值 + 刷新倒计时）
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, T.worldFont.level)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            local txtA = math.floor(200 * pulse)
            -- 护盾破碎时变红色警告
            local tr, tg, tb = 100, 220, 255
            if sHp <= 0 then tr, tg, tb = 255, 120, 80 end
            nvgFillColor(nvg, nvgRGBA(tr, tg, tb, txtA))
            local cdSec = math.ceil(ArtifactCh4_._shieldTimer or 0)
            local txtY = sy + halfSize * 0.3
            -- 避免和其他文字重叠
            if player.shieldHp and player.shieldHp > 0 then
                txtY = txtY + T.worldFont.level + 2
            end
            if player:IsPetBerserkActive() then
                txtY = txtY + T.worldFont.level + 2
            end
            if sHp > 0 then
                nvgText(nvg, sx, txtY, "☯" .. math.floor(sHp), nil)
            else
                nvgText(nvg, sx, txtY, "☯恢复 " .. cdSec .. "s", nil)
            end
        end
    end

    -- ── 献祭光环视觉效果（橙红脉冲光环） ──
    if CombatSystem.sacrificeAuraActive then
        local auraRange = (CombatSystem.sacrificeAuraRange or 1.5) * ts
        local time = GameState.gameTime or 0
        local pulse = math.sin(time * 2.5) * 0.3 + 0.7  -- 0.4~1.0 脉冲

        -- 外圈光环（橙红渐变）
        local outerR = auraRange + math.sin(time * 3.0) * 3
        local auraPaint = nvgRadialGradient(nvg,
            sx, sy,
            outerR * 0.6, outerR,
            nvgRGBA(255, 120, 30, math.floor(60 * pulse)),
            nvgRGBA(255, 60, 10, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, outerR)
        nvgFillPaint(nvg, auraPaint)
        nvgFill(nvg)

        -- 内圈描边
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, auraRange * 0.9)
        nvgStrokeColor(nvg, nvgRGBA(255, 140, 40, math.floor(100 * pulse)))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
    end

    -- ═══ 御剑护体：PNG灵剑环绕（垂直、剑尖朝上） ═══
    local ss = player._swordShield
    if ss and ss.swords > 0 then
        local time = GameState.gameTime or 0
        local orbitR = ts * 0.80             -- 环绕半径
        local swordW = ts * 0.494            -- 小剑宽度（0.38*1.3）
        local swordH = ts * 0.494            -- 小剑高度（0.38*1.3）
        local rotSpeed = 1.8                 -- 旋转速度（弧度/秒）
        local baseAngle = time * rotSpeed

        local swordImg = RenderUtils.GetCachedImage(nvg, "Textures/energy_sword.png")

        for j = 1, ss.swords do
            local angle = baseAngle + (j - 1) * (math.pi * 2 / ss.maxSwords)
            local floatY = math.sin(time * 2.5 + j * 1.2) * ts * 0.04
            local cx = sx + math.cos(angle) * orbitR
            local cy = sy + math.sin(angle) * orbitR * 0.5 + floatY

            local drawX = cx - swordW / 2
            local drawY = cy - swordH / 2

            if swordImg then
                -- 旋转 -90° 使剑尖朝上（原图剑尖朝右）
                nvgSave(nvg)
                nvgTranslate(nvg, cx, cy)
                nvgRotate(nvg, -math.pi / 2)
                nvgTranslate(nvg, -cx, -cy)

                -- 剑身 PNG（无发光层）
                local imgPaint = nvgImagePattern(nvg, drawX, drawY, swordW, swordH, 0, swordImg, 0.9)
                nvgBeginPath(nvg)
                nvgRect(nvg, drawX, drawY, swordW, swordH)
                nvgFillPaint(nvg, imgPaint)
                nvgFill(nvg)

                nvgRestore(nvg)
            else
                -- 回退：简单线段
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, cx, cy - swordH * 0.5)
                nvgLineTo(nvg, cx, cy + swordH * 0.5)
                nvgStrokeColor(nvg, nvgRGBA(120, 200, 255, 200))
                nvgStrokeWidth(nvg, 2.0)
                nvgStroke(nvg)
            end
        end

        -- 环绕轨迹光环（极淡）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, sx, sy, orbitR, orbitR * 0.5)
        nvgStrokeColor(nvg, nvgRGBA(120, 200, 255, 25))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)
    end

    -- ═══════════════════════════════════════════════════════
    -- 快捷回城：读条进度条 + 传送光效
    -- ═══════════════════════════════════════════════════════
    if not TownReturnSystem_ then
        TownReturnSystem_ = require("systems.TownReturnSystem")
    end

    local trProgress = TownReturnSystem_.GetChannelProgress()
    local trFxTimer  = TownReturnSystem_.GetFxTimer()

    -- 读条进度条（玩家头顶，HP 条上方）
    if trProgress then
        local trBarW = uiTs * 0.7
        local trBarH = 10
        local trBarX = sx - trBarW / 2
        local trBarY = imgTopY - trBarH - 24  -- HP 条上方足够空间

        -- 背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, trBarX, trBarY, trBarW, trBarH, 4)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
        nvgFill(nvg)

        -- 进度填充（蓝色渐变）
        local fillW = (trBarW - 4) * trProgress
        if fillW > 0 then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, trBarX + 2, trBarY + 2, fillW, trBarH - 4, 2)
            local trGrad = nvgLinearGradient(nvg,
                trBarX + 2, trBarY, trBarX + 2 + fillW, trBarY,
                nvgRGBA(60, 140, 220, 255),
                nvgRGBA(100, 200, 255, 255)
            )
            nvgFillPaint(nvg, trGrad)
            nvgFill(nvg)
        end

        -- 边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, trBarX, trBarY, trBarW, trBarH, 4)
        nvgStrokeColor(nvg, nvgRGBA(80, 180, 230, 180))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)

        -- 百分比文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
        nvgText(nvg, sx, trBarY + trBarH / 2, math.floor(trProgress * 100) .. "%", nil)

        -- 脚底传送法阵（读条期间显示）
        local feetY = sy + halfSize  -- 角色精灵脚底
        local circleR = ts * 0.7
        local circleAlpha = math.floor(120 + 80 * math.sin(trProgress * math.pi * 4))
        nvgBeginPath(nvg)
        nvgEllipse(nvg, sx, feetY, circleR, circleR * 0.4)
        nvgStrokeColor(nvg, nvgRGBA(60, 160, 255, circleAlpha))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 内圈旋转
        local innerR = circleR * 0.6
        nvgBeginPath(nvg)
        nvgEllipse(nvg, sx, feetY, innerR, innerR * 0.4)
        nvgStrokeColor(nvg, nvgRGBA(100, 200, 255, circleAlpha - 40))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end

    -- 传送成功光柱（FX 阶段）
    if trFxTimer and trFxTimer > 0 then
        local fxDuration = TownReturnSystem_.FX_DURATION
        local fxProgress = 1 - (trFxTimer / fxDuration)  -- 0→1
        local fxFeetY = sy + halfSize  -- 角色精灵脚底
        local pillarH = ts * 3
        local pillarW = ts * 0.5
        local pillarAlpha = math.floor(220 * (1 - fxProgress))  -- 渐隐

        -- 光柱主体（从脚底向上延伸）
        local pillarGrad = nvgLinearGradient(nvg,
            sx, fxFeetY - pillarH, sx, fxFeetY,
            nvgRGBA(100, 200, 255, 0),
            nvgRGBA(60, 160, 255, pillarAlpha)
        )
        nvgBeginPath(nvg)
        nvgRect(nvg, sx - pillarW / 2, fxFeetY - pillarH, pillarW, pillarH)
        nvgFillPaint(nvg, pillarGrad)
        nvgFill(nvg)

        -- 光柱底部光晕（脚底）
        local glowR = ts * 0.8 * (1 + fxProgress * 0.5)
        local glowAlpha = math.floor(150 * (1 - fxProgress))
        nvgBeginPath(nvg)
        nvgEllipse(nvg, sx, fxFeetY, glowR, glowR * 0.3)
        nvgFillColor(nvg, nvgRGBA(100, 200, 255, glowAlpha))
        nvgFill(nvg)
    end

end

-- ============================================================================
-- 宠物渲染
-- ============================================================================

return M
