---@diagnostic disable
-- entities/monsters.lua - 怪物渲染（列表、单体、边框、血条）
---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local shared = require("rendering.entities.shared")
local GameConfig = shared.GameConfig
local GameState = shared.GameState
local T = shared.T
local RenderUtils = shared.RenderUtils
local CombatSystem = shared.CombatSystem
local MonsterData = shared.MonsterData
local MONSTER_RADIUS_SCALE = shared.MONSTER_RADIUS_SCALE
local MONSTER_NAME_COLORS = shared.MONSTER_NAME_COLORS
local MONSTER_NAME_COLOR_DEFAULT = shared.MONSTER_NAME_COLOR_DEFAULT
local getLvBadgeColorGroup = shared.getLvBadgeColorGroup
local getRealmColorGroup = shared.getRealmColorGroup
local getHpColor = shared.getHpColor

local chests = require("rendering.entities.chests")

local M = {}

-- 从 chests 模块借用锁链封印渲染（怪物/宝箱共用）
M.RenderChainSeal = chests.RenderChainSeal

local function RenderArtifactCh6Aspect(nvg, cx, cy, radius, time, monster)
    if not monster.isArtifactCh6Boss then return end

    local aspect = monster.artifactCh6Aspect
    if aspect == "demon" then
        local pulse = 0.72 + 0.28 * math.sin(time * 4.2)
        local outerR = radius + 20 + 2 * math.sin(time * 2.6)
        local glow = nvgRadialGradient(
            nvg, cx, cy, radius * 0.65, outerR,
            nvgRGBA(220, 35, 90, math.floor(105 * pulse)),
            nvgRGBA(55, 5, 70, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, outerR)
        nvgFillPaint(nvg, glow)
        nvgFill(nvg)

        for i = 0, 5 do
            local startAngle = -time * 1.6 + i * math.pi / 3
            nvgBeginPath(nvg)
            nvgArc(
                nvg, cx, cy, radius + 13,
                startAngle, startAngle + math.pi * 0.20, NVG_CW)
            nvgStrokeColor(
                nvg, nvgRGBA(255, 55, 110, math.floor(230 * pulse)))
            nvgStrokeWidth(nvg, 3)
            nvgStroke(nvg)
        end

        for i = 0, 7 do
            local seed = i * 0.83
            local px = cx + math.sin(time * 1.7 + seed) * (radius + 7)
            local fall = (time * 28 + i * 11) % (radius * 1.7)
            local py = cy - radius * 0.55 + fall
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 2.2 + (i % 2))
            nvgFillColor(nvg, nvgRGBA(245, 50, 105, math.floor(205 * pulse)))
            nvgFill(nvg)
        end
    elseif aspect == "immortal" then
        local pulse = 0.78 + 0.22 * math.sin(time * 2.8)
        local outerR = radius + 21 + 2 * math.sin(time * 2.0)
        local glow = nvgRadialGradient(
            nvg, cx, cy, radius * 0.55, outerR,
            nvgRGBA(150, 255, 220, math.floor(95 * pulse)),
            nvgRGBA(245, 225, 145, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, outerR)
        nvgFillPaint(nvg, glow)
        nvgFill(nvg)

        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 13)
        nvgStrokeColor(
            nvg, nvgRGBA(245, 225, 145, math.floor(220 * pulse)))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)

        for i = 0, 7 do
            local angle = time * 0.85 + i * math.pi / 4
            local pr = radius + 15
            local px = cx + math.cos(angle) * pr
            local py = cy + math.sin(angle) * pr
            nvgSave(nvg)
            nvgTranslate(nvg, px, py)
            nvgRotate(nvg, angle)
            nvgBeginPath(nvg)
            nvgEllipse(nvg, 0, 0, 5.0, 2.4)
            nvgFillColor(
                nvg, nvgRGBA(190, 255, 225, math.floor(215 * pulse)))
            nvgFill(nvg)
            nvgRestore(nvg)
        end

        for i = 0, 5 do
            local angle = -time * 1.15 + i * math.pi / 3
            local pr = radius + 8
            local px = cx + math.cos(angle) * pr
            local py = cy + math.sin(angle) * pr
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 2.0)
            nvgFillColor(
                nvg, nvgRGBA(255, 245, 185, math.floor(235 * pulse)))
            nvgFill(nvg)
        end
    end

    if (monster.artifactCh6BlessingTimer or 0) > 0 then
        local alpha = math.min(1, monster.artifactCh6BlessingTimer) * 210
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 7)
        nvgStrokeColor(nvg, nvgRGBA(185, 255, 220, math.floor(alpha)))
        nvgStrokeWidth(nvg, 4)
        nvgStroke(nvg)
    end
end

function M.RenderMonsters(nvg, l, camera)
    local monsters = GameState.monsters
    for i = 1, #monsters do
        local m = monsters[i]
        if m.alive and camera:IsVisible(m.x, m.y, l.w, l.h, 2) then
            M.RenderMonster(nvg, l, camera, m)
        end
    end
end

function M.RenderMonster(nvg, l, camera, m)
    local sx, sy = RenderUtils.WorldToLocal(m.x, m.y, camera, l)
    local ts = camera:GetTileSize()
    local size = m.bodySize
    local time = GameState.gameTime or 0

    local flash = (m.hurtFlashTimer or 0) > 0 and math.floor((m.hurtFlashTimer or 0) * 20) % 2 == 0

    local radius = ts * (MONSTER_RADIUS_SCALE[m.category] or 0.5)
    local cx = sx
    local cy = sy - radius * 0.15  -- 稍微上移使名字有空间

    -- 镇狱塔柱：只渲染头像和名字，跳过所有BOSS装饰
    if m.isPillar then
        -- 绘制圆形头像
        local imgHandle = RenderUtils.GetCachedImage(nvg, m.portrait)
        if imgHandle then
            local imgSize = radius * 2
            local imgX = cx - radius
            local imgY = cy - radius
            local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgSize, imgSize, 0, imgHandle, flash and 0.4 or 1.0)
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, radius - 1)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
            if flash then
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, radius - 1)
                nvgFillColor(nvg, nvgRGBA(255, 60, 60, 160))
                nvgFill(nvg)
            end
        else
            -- 回退：石柱色圆形
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, radius - 1)
            nvgFillColor(nvg, nvgRGBA(120, 110, 100, 255))
            nvgFill(nvg)
        end
        -- 简单石色边框
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius)
        nvgStrokeColor(nvg, nvgRGBA(160, 150, 130, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        -- 名字（白底黑字，简洁）
        local pillarNameSize = T.worldFont.name
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, pillarNameSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local pnW = nvgTextBounds(nvg, 0, 0, m.name, nil)
        local pnBgW = pnW + 12
        local pnBgH = pillarNameSize + 6
        local pnY = cy - radius - 6
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - pnBgW / 2, pnY - pnBgH / 2, pnBgW, pnBgH, 3)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 140))
        nvgFill(nvg)
        nvgFillColor(nvg, nvgRGBA(200, 195, 180, 255))
        nvgText(nvg, cx, pnY, m.name, nil)
        -- 锁链封印效果（与枯木守卫一致的铁链+铁锁样式）
        M.RenderChainSeal(nvg, cx, cy, radius, time)
        return  -- 柱子渲染完毕，跳过后续所有BOSS装饰
    end

    -- 1) 绘制分级光效底层（BOSS以上有外发光）
    if m.category == "saint_boss" then
        -- 圣级BOSS：三层圣白青金神圣光环
        local pulse = math.sin(time * 2.0) * 0.2 + 0.8
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 16)
        nvgFillColor(nvg, nvgRGBA(180, 230, 255, math.floor(25 * pulse)))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 12)
        nvgFillColor(nvg, nvgRGBA(200, 240, 255, math.floor(40 * pulse)))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 8)
        nvgFillColor(nvg, nvgRGBA(220, 245, 255, math.floor(60 * pulse)))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 5)
        nvgFillColor(nvg, nvgRGBA(255, 250, 230, math.floor(80 * pulse)))
        nvgFill(nvg)
    elseif m.category == "emperor_boss" then
        -- 皇级BOSS：双层金紫脉冲光环
        local pulse = math.sin(time * 2.5) * 0.2 + 0.8
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 12)
        nvgFillColor(nvg, nvgRGBA(255, 180, 0, math.floor(30 * pulse)))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 8)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, math.floor(50 * pulse)))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 5)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, math.floor(70 * pulse)))
        nvgFill(nvg)
    elseif m.category == "king_boss" then
        -- 王级BOSS：脉动金色光环
        local pulse = math.sin(time * 2.5) * 0.2 + 0.8
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 8)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, math.floor(40 * pulse)))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 5)
        nvgFillColor(nvg, nvgRGBA(255, 180, 30, math.floor(60 * pulse)))
        nvgFill(nvg)
    elseif m.category == "boss" then
        -- BOSS：红色外光晕
        local pulse = math.sin(time * 2.0) * 0.15 + 0.85
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 5)
        nvgFillColor(nvg, nvgRGBA(220, 60, 30, math.floor(35 * pulse)))
        nvgFill(nvg)
    end

    -- 魔化怪物特效：暗紫脉冲光环 + 旋转魔气粒子
    if m.isDemon or m.demonBuff then
        local demonPulse = math.sin(time * 3.0) * 0.3 + 0.7
        -- 外层暗紫大光环（明显可见）
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 12)
        nvgFillColor(nvg, nvgRGBA(120, 20, 80, math.floor(80 * demonPulse)))
        nvgFill(nvg)
        -- 内层暗红光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 7)
        nvgFillColor(nvg, nvgRGBA(200, 30, 30, math.floor(100 * demonPulse)))
        nvgFill(nvg)
        -- 旋转魔气粒子（6个，更大更亮）
        for i = 0, 5 do
            local angle = time * 2.0 + i * (math.pi / 3)
            local pr = radius + 10
            local px = cx + math.cos(angle) * pr
            local py = cy + math.sin(angle) * pr
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 3.5)
            nvgFillColor(nvg, nvgRGBA(255, 60, 60, math.floor(220 * demonPulse)))
            nvgFill(nvg)
        end
    end

    -- BOSS 阶段视觉状态（phaseState: berserk/demonize）
    if m.phaseState == "berserk" then
        -- 狂暴：红橙脉冲光环 + 旋转火粒子
        local bPulse = math.sin(time * 4.0) * 0.3 + 0.7
        -- 外层红色径向渐变
        local outerR = radius + 8 + math.sin(time * 3.0) * 2
        local outerGlow = nvgRadialGradient(nvg, cx, cy,
            radius * 0.5, outerR,
            nvgRGBA(255, 60, 30, math.floor(50 * bPulse)),
            nvgRGBA(255, 60, 30, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, outerR)
        nvgFillPaint(nvg, outerGlow)
        nvgFill(nvg)
        -- 红色描边光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 4)
        nvgStrokeColor(nvg, nvgRGBA(255, 80, 50, math.floor(120 * bPulse)))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)
        -- 旋转火粒子（4个）
        for i = 0, 3 do
            local angle = time * 3.0 + i * (math.pi / 2)
            local pr = radius + 6
            local px = cx + math.cos(angle) * pr
            local py = cy + math.sin(angle) * pr
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 2.5)
            nvgFillColor(nvg, nvgRGBA(255, 120, 50, math.floor(200 * bPulse)))
            nvgFill(nvg)
        end
    elseif m.phaseState == "demonize" then
        -- 魔化：暗紫脉冲光环 + 旋转魔气粒子（复用封魔风格）
        local dPulse = math.sin(time * 3.0) * 0.3 + 0.7
        -- 外层暗紫大光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 12)
        nvgFillColor(nvg, nvgRGBA(120, 20, 80, math.floor(80 * dPulse)))
        nvgFill(nvg)
        -- 内层暗红光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 7)
        nvgFillColor(nvg, nvgRGBA(200, 30, 30, math.floor(100 * dPulse)))
        nvgFill(nvg)
        -- 旋转魔气粒子（6个）
        for i = 0, 5 do
            local angle = time * 2.0 + i * (math.pi / 3)
            local pr = radius + 10
            local px = cx + math.cos(angle) * pr
            local py = cy + math.sin(angle) * pr
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 3.5)
            nvgFillColor(nvg, nvgRGBA(255, 60, 60, math.floor(220 * dPulse)))
            nvgFill(nvg)
        end
    end

    RenderArtifactCh6Aspect(nvg, cx, cy, radius, time, m)

    -- 2) 绘制圆形头像（用图片纹理+圆形路径裁剪）
    local imgHandle = RenderUtils.GetCachedImage(nvg, m.portrait)
    if imgHandle then
        local imgSize = radius * 2
        local imgX = cx - radius
        local imgY = cy - radius
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgSize, imgSize, 0, imgHandle, flash and 0.4 or 1.0)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 1)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)

        -- 受伤闪烁红色叠加
        if flash then
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, radius - 1)
            nvgFillColor(nvg, nvgRGBA(255, 60, 60, 160))
            nvgFill(nvg)
        end

        -- 魔化怪物：暗紫红叠色（明显可见）
        if (m.isDemon or m.demonBuff) and not flash then
            local dAlpha = math.floor(70 + 30 * math.sin(time * 2.5))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, radius - 1)
            nvgFillColor(nvg, nvgRGBA(120, 10, 40, dAlpha))
            nvgFill(nvg)
        end

        -- BOSS 阶段叠色
        if not flash then
            if m.phaseState == "berserk" then
                -- 狂暴：红橙叠色
                local bAlpha = math.floor(50 + 25 * math.sin(time * 3.0))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, radius - 1)
                nvgFillColor(nvg, nvgRGBA(200, 50, 20, bAlpha))
                nvgFill(nvg)
            elseif m.phaseState == "demonize" then
                -- 魔化：暗紫红叠色
                local dAlpha2 = math.floor(70 + 30 * math.sin(time * 2.5))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, radius - 1)
                nvgFillColor(nvg, nvgRGBA(120, 10, 40, dAlpha2))
                nvgFill(nvg)
            end

            if m.isArtifactCh6Boss and m.artifactCh6Aspect == "immortal" then
                local iAlpha = math.floor(42 + 18 * math.sin(time * 2.2))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, radius - 1)
                nvgFillColor(nvg, nvgRGBA(145, 245, 210, iAlpha))
                nvgFill(nvg)
            elseif m.isArtifactCh6Boss and m.artifactCh6Aspect == "demon" then
                local dAlpha3 = math.floor(45 + 20 * math.sin(time * 3.1))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, radius - 1)
                nvgFillColor(nvg, nvgRGBA(175, 15, 80, dAlpha3))
                nvgFill(nvg)
            end
        end
    else
        -- 无头像时的回退：纯色圆形 + emoji
        local c = m.bodyColor
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 1)
        if flash then
            nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
        else
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], c[4] or 255))
        end
        nvgFill(nvg)
    end

    -- 3) 绘制分级圆形边框
    local frameCategory = m.frameCategory or (m.data and m.data.frameCategory) or m.category
    M.RenderMonsterFrame(nvg, cx, cy, radius, frameCategory, time)

    -- 3.5) 试炼塔·锁链封印效果（stationary BOSS专属）
    if m.data and m.data.stationary and (m.category == "boss" or m.category == "king_boss" or m.category == "emperor_boss" or m.category == "saint_boss") then
        M.RenderChainSeal(nvg, cx, cy, radius, time)
    end

    -- 3.6) 封魔大阵·易伤标记（怪物在增伤区域内时显示）
    do
        local inDmgBoostZone = false
        local zones = CombatSystem.activeZones
        if zones then
            for zi = 1, #zones do
                local zone = zones[zi]
                if (zone.damageBoostPercent or 0) > 0 then
                    if CombatSystem.IsPointInZone and CombatSystem.IsPointInZone(m.x, m.y, zone) then
                        inDmgBoostZone = true
                        break
                    end
                end
            end
        end
        if inDmgBoostZone then
            -- 右上角紫色"易伤"铭牌
            local dbPulse = 0.7 + 0.3 * math.sin(time * 4.0)
            local dbX = cx + radius * 0.55
            local dbY = cy - radius * 0.55
            local dbLabel = "易伤"
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 10)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local dbTextW = nvgTextBounds(nvg, 0, 0, dbLabel, nil)
            local dbPillW = dbTextW + 8
            local dbPillH = 14
            -- 铭牌背景（暗紫色）
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, dbX - dbPillW / 2, dbY - dbPillH / 2, dbPillW, dbPillH, 3)
            nvgFillColor(nvg, nvgRGBA(120, 40, 180, math.floor(200 * dbPulse)))
            nvgFill(nvg)
            -- 铭牌边框
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, dbX - dbPillW / 2, dbY - dbPillH / 2, dbPillW, dbPillH, 3)
            nvgStrokeColor(nvg, nvgRGBA(200, 140, 255, math.floor(220 * dbPulse)))
            nvgStrokeWidth(nvg, 0.8)
            nvgStroke(nvg)
            -- 铭牌文字
            nvgFillColor(nvg, nvgRGBA(255, 220, 255, math.floor(255 * dbPulse)))
            nvgText(nvg, dbX, dbY, dbLabel, nil)
        end
    end

    -- 4) 境界铭牌（左上角独立组件，练气以上显示）
    if m.realm then
        local realmData = GameConfig.REALMS[m.realm]
        if realmData and (realmData.order or 0) > 0 then
            local realmName = realmData.name or ""
            -- 境界铭牌颜色：复用模块级常量表（避免每帧重建）
            local order = realmData.order
            local rc = getRealmColorGroup(order)
            local pillBg, pillFg, pillBorder = rc.bg, rc.fg, rc.border

            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, T.worldFont.realmBadgeMon)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local rTextW = nvgTextBounds(nvg, 0, 0, realmName, nil)
            local rPillW = rTextW + 10
            local rPillH = T.worldFont.realmBadgeMon + 5
            -- 放在头像左上方
            local rpX = cx - radius * 0.7
            local rpY = cy - radius * 0.7

            -- 铭牌背景
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, rpX - rPillW / 2, rpY - rPillH / 2, rPillW, rPillH, rPillH / 2)
            nvgFillColor(nvg, nvgRGBA(pillBg[1], pillBg[2], pillBg[3], pillBg[4]))
            nvgFill(nvg)
            -- 铭牌边框
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, rpX - rPillW / 2, rpY - rPillH / 2, rPillW, rPillH, rPillH / 2)
            nvgStrokeColor(nvg, nvgRGBA(pillBorder[1], pillBorder[2], pillBorder[3], pillBorder[4]))
            nvgStrokeWidth(nvg, 0.8)
            nvgStroke(nvg)
            -- 铭牌文字
            nvgFillColor(nvg, nvgRGBA(pillFg[1], pillFg[2], pillFg[3], pillFg[4]))
            nvgText(nvg, rpX, rpY, realmName, nil)
        end
    end

    -- 5) 怪物名字 + BOSS标签（带暗底背景板）
    local isBossLike = (m.category == "saint_boss" or m.category == "emperor_boss" or m.category == "king_boss" or m.category == "boss")
    local nameFontSize = isBossLike and T.worldFont.nameBoss or T.worldFont.name
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, nameFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local nameColor = MONSTER_NAME_COLORS[m.category] or MONSTER_NAME_COLOR_DEFAULT

    -- 测量名字宽度
    local nameTextW = nvgTextBounds(nvg, 0, 0, m.name, nil)
    local namePadH, namePadV = 8, 4
    local nameBgW = nameTextW + namePadH * 2
    local nameBgH = nameFontSize + namePadV * 2
    local nameBaseY = cy - radius - 6

    -- saint/emperor/king_boss 头顶 BOSS 标签（在名字上方）
    if m.category == "saint_boss" then
        local bossLabel = "⚡ 圣级 BOSS ⚡"
        if m.isArtifactCh6Boss and m.artifactCh6Aspect == "demon" then
            bossLabel = "魔化 · 双界王"
        elseif m.isArtifactCh6Boss and m.artifactCh6Aspect == "immortal" then
            bossLabel = "仙化 · 双界王"
        end
        local bossLabelSize = 13
        nvgFontSize(nvg, bossLabelSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local blW = nvgTextBounds(nvg, 0, 0, bossLabel, nil)
        local blPadH = 7
        local blBgW = blW + blPadH * 2
        local blBgH = bossLabelSize + 7
        local blCenterY = nameBaseY - nameBgH / 2 - blBgH / 2 - 2
        local pulse = math.sin(time * 3.0) * 0.15 + 0.85
        -- 圣白底条（深蓝底）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - blBgW / 2, blCenterY - blBgH / 2, blBgW, blBgH, 5)
        nvgFillColor(nvg, nvgRGBA(20, 50, 100, math.floor(210 * pulse)))
        nvgFill(nvg)
        -- 冰蓝外框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - blBgW / 2, blCenterY - blBgH / 2, blBgW, blBgH, 5)
        nvgStrokeColor(nvg, nvgRGBA(140, 220, 255, math.floor(220 * pulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        -- 内层金色细框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - blBgW / 2 + 2, blCenterY - blBgH / 2 + 2, blBgW - 4, blBgH - 4, 3)
        nvgStrokeColor(nvg, nvgRGBA(255, 230, 160, math.floor(120 * pulse)))
        nvgStrokeWidth(nvg, 0.6)
        nvgStroke(nvg)
        -- 圣白文字
        nvgFillColor(nvg, nvgRGBA(220, 245, 255, math.floor(255 * pulse)))
        nvgText(nvg, cx, blCenterY, bossLabel, nil)
    elseif m.category == "emperor_boss" then
        local bossLabel = "👑 皇级 BOSS 👑"
        local bossLabelSize = 12
        nvgFontSize(nvg, bossLabelSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local blW = nvgTextBounds(nvg, 0, 0, bossLabel, nil)
        local blPadH = 6
        local blBgW = blW + blPadH * 2
        local blBgH = bossLabelSize + 6
        local blCenterY = nameBaseY - nameBgH / 2 - blBgH / 2 - 2
        local pulse = math.sin(time * 3.0) * 0.15 + 0.85
        -- 深金底条
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - blBgW / 2, blCenterY - blBgH / 2, blBgW, blBgH, 4)
        nvgFillColor(nvg, nvgRGBA(140, 90, 0, math.floor(200 * pulse)))
        nvgFill(nvg)
        -- 金色边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - blBgW / 2, blCenterY - blBgH / 2, blBgW, blBgH, 4)
        nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, math.floor(200 * pulse)))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
        -- 金色文字
        nvgFillColor(nvg, nvgRGBA(255, 240, 120, math.floor(255 * pulse)))
        nvgText(nvg, cx, blCenterY, bossLabel, nil)
    elseif m.category == "king_boss" then
        local bossLabel = "★ BOSS ★"
        local bossLabelSize = 12
        nvgFontSize(nvg, bossLabelSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local blW = nvgTextBounds(nvg, 0, 0, bossLabel, nil)
        local blPadH = 6
        local blBgW = blW + blPadH * 2
        local blBgH = bossLabelSize + 6
        local blCenterY = nameBaseY - nameBgH / 2 - blBgH / 2 - 2
        -- 金色底条
        local pulse = math.sin(time * 3.0) * 0.15 + 0.85
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - blBgW / 2, blCenterY - blBgH / 2, blBgW, blBgH, 4)
        nvgFillColor(nvg, nvgRGBA(120, 80, 0, math.floor(180 * pulse)))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - blBgW / 2, blCenterY - blBgH / 2, blBgW, blBgH, 4)
        nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, math.floor(160 * pulse)))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 230, 100, math.floor(255 * pulse)))
        nvgText(nvg, cx, blCenterY, bossLabel, nil)
    end

    -- 名字暗底背景板
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx - nameBgW / 2, nameBaseY - nameBgH / 2, nameBgW, nameBgH, 4)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 140))
    nvgFill(nvg)

    -- 名字正文
    nvgFontSize(nvg, nameFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(nameColor[1], nameColor[2], nameColor[3], nameColor[4]))
    nvgText(nvg, cx, nameBaseY, m.name, nil)

    -- 6) 等级标签（右下角小圆，按境界阶级染色）
    local lvRadius = T.monsterLvRadius
    local lvX = cx + radius * 0.65
    local lvY = cy + radius * 0.65

    -- 等级徽章颜色：按怪物境界分级（颜色查找表已提升到模块级）
    local ro = 0
    if m.realm then
        local rd = GameConfig.REALMS[m.realm]
        ro = rd and rd.order or 0
    end
    local lvColors = getLvBadgeColorGroup(ro)
    local lvBgColor = lvColors.bg
    local lvBorderColor = lvColors.border
    local lvTextColor = lvColors.text

    nvgBeginPath(nvg)
    nvgCircle(nvg, lvX, lvY, lvRadius)
    nvgFillColor(nvg, nvgRGBA(lvBgColor[1], lvBgColor[2], lvBgColor[3], lvBgColor[4]))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, lvX, lvY, lvRadius)
    nvgStrokeColor(nvg, nvgRGBA(lvBorderColor[1], lvBorderColor[2], lvBorderColor[3], lvBorderColor[4]))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    nvgFontSize(nvg, T.worldFont.level)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(lvTextColor[1], lvTextColor[2], lvTextColor[3], lvTextColor[4]))
    nvgText(nvg, lvX, lvY, tostring(m.level), nil)

    -- 7) 冰缓特效（蓝色光环 + 雪花粒子）
    if m.isSlowed then
        local icePulse = math.sin(time * 4.0) * 0.2 + 0.8

        -- 冰蓝色半透明叠加
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 1)
        nvgFillColor(nvg, nvgRGBA(100, 180, 255, math.floor(40 * icePulse)))
        nvgFill(nvg)

        -- 外层冰霜光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 2)
        nvgStrokeColor(nvg, nvgRGBA(120, 200, 255, math.floor(160 * icePulse)))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 冰晶粒子（6个绕圆旋转的小点）
        for i = 0, 5 do
            local angle = i * math.pi / 3 + time * 2.0
            local px = cx + math.cos(angle) * (radius + 4)
            local py = cy + math.sin(angle) * (radius + 4)
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 1.5)
            nvgFillColor(nvg, nvgRGBA(180, 230, 255, math.floor(200 * icePulse)))
            nvgFill(nvg)
        end

        -- 底部"冰缓"文字标签
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.level)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(100, 200, 255, math.floor(220 * icePulse)))
        nvgText(nvg, cx, cy + radius + 10, "❄冰缓", nil)
    end

    -- 8) 易伤特效（紫红色光环 + 裂痕粒子）
    if m.isVulnerable then
        local vulnPulse = math.sin(time * 3.5) * 0.25 + 0.75

        -- 紫红色半透明叠加
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 1)
        nvgFillColor(nvg, nvgRGBA(200, 80, 255, math.floor(30 * vulnPulse)))
        nvgFill(nvg)

        -- 外层易伤光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 2)
        nvgStrokeColor(nvg, nvgRGBA(220, 100, 255, math.floor(140 * vulnPulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 裂痕粒子（4个闪烁小三角绕圆）
        for i = 0, 3 do
            local angle = i * math.pi / 2 + time * 1.5
            local px = cx + math.cos(angle) * (radius + 4)
            local py = cy + math.sin(angle) * (radius + 4)
            local sparkA = math.sin(time * 4.0 + i * 2.0) * 0.3 + 0.7
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, px, py - 2.5)
            nvgLineTo(nvg, px + 2, py + 1.5)
            nvgLineTo(nvg, px - 2, py + 1.5)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(255, 140, 80, math.floor(200 * sparkA)))
            nvgFill(nvg)
        end

        -- 底部"易伤"文字标签
        local vulnTextY = cy + radius + 10
        if m.isSlowed then vulnTextY = vulnTextY + T.worldFont.level + 2 end  -- 与冰缓错开
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.level)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(255, 160, 80, math.floor(220 * vulnPulse)))
        nvgText(nvg, cx, vulnTextY, "🐺易伤", nil)
    end

    -- 9) 减攻特效（暗红色向下箭头 + 碎剑粒子）
    if m.isAtkWeakened then
        local weakPulse = math.sin(time * 3.0) * 0.2 + 0.8

        -- 暗红色半透明叠加
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 1)
        nvgFillColor(nvg, nvgRGBA(255, 80, 80, math.floor(25 * weakPulse)))
        nvgFill(nvg)

        -- 外层虚弱光环
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 2)
        nvgStrokeColor(nvg, nvgRGBA(255, 100, 100, math.floor(120 * weakPulse)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 向下箭头粒子（3个缓慢下落的小箭头）
        for i = 0, 2 do
            local phase = (time * 1.2 + i * 1.3) % 2.0
            local ax = cx + (i - 1) * (radius * 0.6)
            local ay = cy - radius + phase * radius
            local arrowA = 1.0 - phase / 2.0
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, ax, ay + 3)
            nvgLineTo(nvg, ax + 2.5, ay - 1)
            nvgLineTo(nvg, ax - 2.5, ay - 1)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(255, 80, 80, math.floor(180 * arrowA * weakPulse)))
            nvgFill(nvg)
        end

        -- 底部"减攻"文字标签
        local weakTextY = cy + radius + 10
        if m.isSlowed then weakTextY = weakTextY + T.worldFont.level + 2 end
        if m.isVulnerable then weakTextY = weakTextY + T.worldFont.level + 2 end
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, T.worldFont.level)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(255, 100, 100, math.floor(220 * weakPulse)))
        nvgText(nvg, cx, weakTextY, "⚔减攻", nil)
    end
end

--- 绘制分级怪物圆形边框
---@param nvg any
---@param cx number 中心X
---@param cy number 中心Y
---@param radius number 圆形半径
---@param category string 怪物阶级
---@param time number 游戏时间（用于动画）
function M.RenderMonsterFrame(nvg, cx, cy, radius, category, time)
    if category == "normal" then
        -- 普通：简洁灰色单线框
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius)
        nvgStrokeColor(nvg, nvgRGBA(160, 160, 160, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

    elseif category == "elite" then
        -- 精英：紫金双线框
        -- 外圈
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 1)
        nvgStrokeColor(nvg, nvgRGBA(180, 120, 255, 220))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        -- 内圈
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 2)
        nvgStrokeColor(nvg, nvgRGBA(220, 180, 255, 150))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
        -- 四角小菱形装饰
        for i = 0, 3 do
            local angle = i * math.pi * 0.5 + math.pi * 0.25
            local dx = math.cos(angle) * (radius + 1)
            local dy = math.sin(angle) * (radius + 1)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx + dx, cy + dy - 3)
            nvgLineTo(nvg, cx + dx + 2.5, cy + dy)
            nvgLineTo(nvg, cx + dx, cy + dy + 3)
            nvgLineTo(nvg, cx + dx - 2.5, cy + dy)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(200, 150, 255, 200))
            nvgFill(nvg)
        end

    elseif category == "boss" then
        -- BOSS：华丽红金宽框 + 装饰齿
        -- 外框
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 2)
        nvgStrokeColor(nvg, nvgRGBA(220, 80, 30, 240))
        nvgStrokeWidth(nvg, 3)
        nvgStroke(nvg)
        -- 中间金线
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius)
        nvgStrokeColor(nvg, nvgRGBA(255, 200, 80, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        -- 8个装饰尖刺
        for i = 0, 7 do
            local angle = i * math.pi * 0.25 + time * 0.3
            local innerR = radius + 2
            local outerR = radius + 7
            local ax = cx + math.cos(angle) * innerR
            local ay = cy + math.sin(angle) * innerR
            local bx = cx + math.cos(angle) * outerR
            local by = cy + math.sin(angle) * outerR
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, ax, ay)
            nvgLineTo(nvg, bx, by)
            nvgStrokeColor(nvg, nvgRGBA(255, 180, 50, 180))
            nvgStrokeWidth(nvg, 2)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
            -- 尖端小点
            nvgBeginPath(nvg)
            nvgCircle(nvg, bx, by, 2)
            nvgFillColor(nvg, nvgRGBA(255, 200, 80, 220))
            nvgFill(nvg)
        end

    elseif category == "saint_boss" then
        -- 圣级BOSS：神圣四层冰蓝金华框 + 20旋转光芒 + 神圣光环 + 钻石皇冠
        local pulse = math.sin(time * 2.0) * 0.15 + 0.85

        -- 最外层冰蓝粗框
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 5)
        nvgStrokeColor(nvg, nvgRGBA(140, 220, 255, math.floor(240 * pulse)))
        nvgStrokeWidth(nvg, 4.5)
        nvgStroke(nvg)
        -- 第二层白金线
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 2)
        nvgStrokeColor(nvg, nvgRGBA(255, 250, 230, math.floor(230 * pulse)))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        -- 第三层深青线
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 0.5)
        nvgStrokeColor(nvg, nvgRGBA(80, 180, 220, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        -- 最内层金线
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 3)
        nvgStrokeColor(nvg, nvgRGBA(255, 235, 140, 160))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)

        -- 20个旋转光芒线（最密集）
        for i = 0, 19 do
            local angle = i * math.pi / 10 + time * 0.35
            local innerR = radius + 5
            local outerR = radius + 16
            local ax = cx + math.cos(angle) * innerR
            local ay = cy + math.sin(angle) * innerR
            local bx = cx + math.cos(angle) * outerR
            local by = cy + math.sin(angle) * outerR
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, ax, ay)
            nvgLineTo(nvg, bx, by)
            nvgStrokeColor(nvg, nvgRGBA(180, 230, 255, math.floor(130 * pulse)))
            nvgStrokeWidth(nvg, 1.5)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
            -- 尖端冰蓝珠
            nvgBeginPath(nvg)
            nvgCircle(nvg, bx, by, 2.5)
            nvgFillColor(nvg, nvgRGBA(200, 240, 255, math.floor(230 * pulse)))
            nvgFill(nvg)
        end

        -- 顶部神圣皇冠（七尖 — 超越皇级五尖）
        local crownY = cy - radius - 8
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 13, crownY + 6)
        nvgLineTo(nvg, cx - 10, crownY - 3)
        nvgLineTo(nvg, cx - 7, crownY + 2)
        nvgLineTo(nvg, cx - 3.5, crownY - 6)
        nvgLineTo(nvg, cx, crownY + 0)
        nvgLineTo(nvg, cx + 3.5, crownY - 6)
        nvgLineTo(nvg, cx + 7, crownY + 2)
        nvgLineTo(nvg, cx + 10, crownY - 3)
        nvgLineTo(nvg, cx + 13, crownY + 6)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(200, 240, 255, math.floor(250 * pulse)))
        nvgFill(nvg)
        -- 皇冠冰蓝描边
        nvgStrokeColor(nvg, nvgRGBA(100, 200, 255, 220))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)
        -- 皇冠顶部大钻石（中央）
        nvgBeginPath(nvg)
        local dSize = 3.5
        nvgMoveTo(nvg, cx, crownY - 6 - dSize)
        nvgLineTo(nvg, cx + dSize, crownY - 6)
        nvgLineTo(nvg, cx, crownY - 6 + dSize * 0.6)
        nvgLineTo(nvg, cx - dSize, crownY - 6)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgFill(nvg)
        -- 两侧蓝宝石
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx - 8, crownY, 2.0)
        nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx + 8, crownY, 2.0)
        nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
        nvgFill(nvg)
        -- 外侧金宝石
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx - 11, crownY + 2, 1.5)
        nvgFillColor(nvg, nvgRGBA(255, 230, 100, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx + 11, crownY + 2, 1.5)
        nvgFillColor(nvg, nvgRGBA(255, 230, 100, 255))
        nvgFill(nvg)

    elseif category == "emperor_boss" then
        -- 皇级BOSS：帝金三层华框 + 旋转光芒 + 皇冠 + 宝石
        local pulse = math.sin(time * 2.0) * 0.15 + 0.85

        -- 最外层粗金框
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 4)
        nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, math.floor(255 * pulse)))
        nvgStrokeWidth(nvg, 4.0)
        nvgStroke(nvg)
        -- 中间深红线
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 1)
        nvgStrokeColor(nvg, nvgRGBA(180, 30, 10, 220))
        nvgStrokeWidth(nvg, 2.0)
        nvgStroke(nvg)
        -- 内圈金线
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 2)
        nvgStrokeColor(nvg, nvgRGBA(255, 230, 120, 180))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)

        -- 16个旋转光芒线（比王级12个更多更密）
        for i = 0, 15 do
            local angle = i * math.pi / 8 + time * 0.4
            local innerR = radius + 4
            local outerR = radius + 13
            local ax = cx + math.cos(angle) * innerR
            local ay = cy + math.sin(angle) * innerR
            local bx = cx + math.cos(angle) * outerR
            local by = cy + math.sin(angle) * outerR
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, ax, ay)
            nvgLineTo(nvg, bx, by)
            nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, math.floor(140 * pulse)))
            nvgStrokeWidth(nvg, 1.8)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
            -- 尖端金珠
            nvgBeginPath(nvg)
            nvgCircle(nvg, bx, by, 2.2)
            nvgFillColor(nvg, nvgRGBA(255, 220, 80, math.floor(240 * pulse)))
            nvgFill(nvg)
        end

        -- 顶部皇冠装饰（五尖，比王级三尖更大）
        local crownY = cy - radius - 7
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 10, crownY + 5)
        nvgLineTo(nvg, cx - 7, crownY - 4)
        nvgLineTo(nvg, cx - 3, crownY + 1)
        nvgLineTo(nvg, cx, crownY - 7)
        nvgLineTo(nvg, cx + 3, crownY + 1)
        nvgLineTo(nvg, cx + 7, crownY - 4)
        nvgLineTo(nvg, cx + 10, crownY + 5)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, math.floor(250 * pulse)))
        nvgFill(nvg)
        -- 皇冠描边
        nvgStrokeColor(nvg, nvgRGBA(200, 150, 0, 200))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)
        -- 皇冠三颗宝石
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, crownY - 2, 2.5)
        nvgFillColor(nvg, nvgRGBA(255, 50, 50, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx - 6, crownY, 1.8)
        nvgFillColor(nvg, nvgRGBA(80, 200, 255, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx + 6, crownY, 1.8)
        nvgFillColor(nvg, nvgRGBA(80, 200, 255, 255))
        nvgFill(nvg)

    elseif category == "king_boss" then
        -- 王级BOSS：极致金色华框 + 旋转光芒 + 皇冠装饰
        local pulse = math.sin(time * 2.0) * 0.15 + 0.85

        -- 外层粗金框
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 3)
        nvgStrokeColor(nvg, nvgRGBA(255, 200, 40, math.floor(255 * pulse)))
        nvgStrokeWidth(nvg, 3.5)
        nvgStroke(nvg)
        -- 中间红线
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius + 0.5)
        nvgStrokeColor(nvg, nvgRGBA(200, 50, 30, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        -- 内圈金线
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, radius - 2)
        nvgStrokeColor(nvg, nvgRGBA(255, 220, 100, 160))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)

        -- 12个旋转光芒线
        for i = 0, 11 do
            local angle = i * math.pi / 6 + time * 0.5
            local innerR = radius + 3
            local outerR = radius + 10
            local ax = cx + math.cos(angle) * innerR
            local ay = cy + math.sin(angle) * innerR
            local bx = cx + math.cos(angle) * outerR
            local by = cy + math.sin(angle) * outerR
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, ax, ay)
            nvgLineTo(nvg, bx, by)
            nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, math.floor(120 * pulse)))
            nvgStrokeWidth(nvg, 1.5)
            nvgLineCap(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end

        -- 顶部皇冠装饰（三角形）
        local crownY = cy - radius - 6
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 8, crownY + 4)
        nvgLineTo(nvg, cx - 5, crownY - 5)
        nvgLineTo(nvg, cx, crownY + 1)
        nvgLineTo(nvg, cx + 5, crownY - 5)
        nvgLineTo(nvg, cx + 8, crownY + 4)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, math.floor(240 * pulse)))
        nvgFill(nvg)
        -- 皇冠宝石
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, crownY - 1, 2)
        nvgFillColor(nvg, nvgRGBA(255, 80, 80, 255))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 怪物血条
-- ============================================================================
function M.RenderMonsterHealthBars(nvg, l, camera)
    local monsters = GameState.monsters
    for i = 1, #monsters do
        local m = monsters[i]
        if m.alive and (m.hp < m.maxHp or m.isTreasureRunner) and not m.isPillar and camera:IsVisible(m.x, m.y, l.w, l.h, 2) then
            local sx, sy = RenderUtils.WorldToLocal(m.x, m.y, camera, l)
            local ts = camera:GetTileSize()
            local radius = ts * m.bodySize * 0.32
            local cx = sx
            local cy = sy - radius * 0.15

            local barW = radius * 2 + 4
            local barH = 4
            local ratio = m.hp / m.maxHp
            local barY = cy + radius + 4

            -- 背景
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, cx - barW / 2, barY, barW, barH, 2)
            nvgFillColor(nvg, nvgRGBA(40, 0, 0, 180))
            nvgFill(nvg)

            -- HP 条（颜色表已提升到模块级）
            local hpColor = getHpColor(ratio)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, cx - barW / 2, barY, barW * ratio, barH, 2)
            nvgFillColor(nvg, nvgRGBA(hpColor[1], hpColor[2], hpColor[3], hpColor[4]))
            nvgFill(nvg)

            -- 边框
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, cx - barW / 2, barY, barW, barH, 2)
            nvgStrokeColor(nvg, nvgRGBA(0, 0, 0, 120))
            nvgStrokeWidth(nvg, 0.5)
            nvgStroke(nvg)

            if m.isTreasureRunner then
                local maxBars = m.treasureMaxHpBars or 50
                local curBars = math.max(0, math.min(maxBars, m.treasureHpBarsCurrent or m.hp or maxBars))
                local gap = 1.5
                local segW = (barW - gap * (maxBars - 1)) / maxBars
                for b = 1, maxBars do
                    local x = cx - barW / 2 + (b - 1) * (segW + gap)
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, x, barY, segW, barH + 1, 1.5)
                    nvgFillColor(nvg, nvgRGBA(35, 20, 10, 210))
                    nvgFill(nvg)
                    if b <= curBars then
                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, x, barY, segW, barH + 1, 1.5)
                        nvgFillColor(nvg, nvgRGBA(70, 245, 170, 245))
                        nvgFill(nvg)
                    end
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, x, barY, segW, barH + 1, 1.5)
                    nvgStrokeColor(nvg, nvgRGBA(255, 220, 80, 165))
                    nvgStrokeWidth(nvg, 0.5)
                    nvgStroke(nvg)
                end
            end
        end
    end
end

-- ============================================================================
-- NPC 渲染
-- ============================================================================

return M
