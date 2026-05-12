-- ============================================================================
-- EntityRenderer.lua - 实体渲染（玩家、宠物、怪物、NPC、掉落物）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local T = require("config.UITheme")
local RenderUtils = require("rendering.RenderUtils")
local DecorationRenderers = require("rendering.DecorationRenderers")
local TitleSystem = require("systems.TitleSystem")
local CombatSystem = require("systems.CombatSystem")
local MonsterData = require("config.MonsterData")
local IconUtils = require("utils.IconUtils")
local PetAppearanceConfig = require("config.PetAppearanceConfig")

local M = {}

-- ── 复用缓冲区：气球渲染列表（RenderLootDrops 内每 drop 清空复用） ──
local _balloons = {}

-- 模块级常量：避免每帧每怪物重建
local MONSTER_RADIUS_SCALE = {
    normal       = 0.5,   -- 1格直径
    elite        = 0.75,  -- 1.5格直径
    boss         = 1.0,   -- 2格直径
    king_boss    = 1.25,  -- 2.5格直径
    emperor_boss = 1.25,  -- 2.5格直径（与王级一致）
    saint_boss   = 1.5,   -- 3格直径（圣级最大）
}

-- 模块级常量：宠物阶级贴图映射
local PET_TIER_TEXTURES = {
    [0] = "Textures/pet_dog_right.png",
    [1] = "Textures/pet_dog_tier1.png",
    [2] = "Textures/pet_dog_tier2.png",
    [3] = "Textures/pet_dog_tier3.png",
    [4] = "Textures/pet_dog_tier4.png",
}

-- 模块级常量：境界铭牌颜色查找表（按 realmOrder 区间索引）
-- 返回 {bg, fg, border}，避免每帧重建颜色表
local REALM_COLORS = {
    [0] = { -- 凡人：灰
        bg     = {50, 55, 65, 210},
        fg     = {230, 230, 210, 255},
        border = {180, 180, 170, 100},
    },
    [1] = { -- 练气：淡紫（order 1-3）
        bg     = {90, 60, 160, 220},
        fg     = {220, 200, 255, 255},
        border = {160, 130, 255, 130},
    },
    [2] = { -- 筑基：蓝（order 4-6）
        bg     = {40, 80, 170, 220},
        fg     = {180, 220, 255, 255},
        border = {100, 160, 255, 130},
    },
    [3] = { -- 金丹：金（order 7-9）
        bg     = {160, 120, 30, 220},
        fg     = {255, 235, 160, 255},
        border = {255, 200, 60, 130},
    },
    [4] = { -- 元婴：橙红（order 10-12）
        bg     = {170, 60, 30, 220},
        fg     = {255, 200, 160, 255},
        border = {255, 120, 60, 130},
    },
    [5] = { -- 化神以上：红金（order 13+）
        bg     = {150, 30, 30, 230},
        fg     = {255, 220, 140, 255},
        border = {255, 180, 80, 150},
    },
}

--- 根据 realmOrder 返回对应颜色组（不分配新表）
local function getRealmColorGroup(realmOrder)
    if realmOrder <= 0 then return REALM_COLORS[0] end
    if realmOrder <= 3 then return REALM_COLORS[1] end
    if realmOrder <= 6 then return REALM_COLORS[2] end
    if realmOrder <= 9 then return REALM_COLORS[3] end
    if realmOrder <= 12 then return REALM_COLORS[4] end
    return REALM_COLORS[5]
end

-- ── P2-5: 低频变化文本缓存（避免每帧字符串拼接） ──
local _cachedRealmText = ""
local _cachedRealmKey  = ""   -- realm .. "|" .. level
local _cachedTitleText = ""
local _cachedTitleName = ""

-- 模块级常量：怪物名字颜色（按 category 索引）
local MONSTER_NAME_COLORS = {
    saint_boss   = {180, 230, 255, 255},
    emperor_boss = {255, 215, 0, 255},
    king_boss    = {255, 215, 0, 255},
    boss         = {255, 150, 80, 255},
    elite        = {200, 160, 255, 255},
}
local MONSTER_NAME_COLOR_DEFAULT = {255, 255, 255, 220}

-- 模块级常量：怪物等级徽章颜色（按 realmOrder 区间）
local LV_BADGE_COLORS = {
    [0] = { -- 默认
        bg     = {30, 30, 30, 200},
        border = {180, 180, 180, 200},
        text   = {255, 255, 255, 240},
    },
    [1] = { -- order 1-3
        bg     = {60, 40, 110, 220},
        border = {160, 130, 255, 220},
        text   = {220, 200, 255, 255},
    },
    [2] = { -- order 4-6
        bg     = {30, 60, 130, 220},
        border = {100, 160, 255, 220},
        text   = {180, 220, 255, 255},
    },
    [3] = { -- order 7-9
        bg     = {120, 90, 20, 220},
        border = {255, 200, 60, 220},
        text   = {255, 235, 160, 255},
    },
    [4] = { -- order 10+
        bg     = {130, 40, 20, 220},
        border = {255, 140, 60, 220},
        text   = {255, 210, 160, 255},
    },
}

--- 根据 realmOrder 返回等级徽章颜色组
local function getLvBadgeColorGroup(realmOrder)
    if realmOrder >= 10 then return LV_BADGE_COLORS[4] end
    if realmOrder >= 7 then return LV_BADGE_COLORS[3] end
    if realmOrder >= 4 then return LV_BADGE_COLORS[2] end
    if realmOrder >= 1 then return LV_BADGE_COLORS[1] end
    return LV_BADGE_COLORS[0]
end

-- 模块级常量：HP 条三段变色
local HP_COLOR_HIGH = {80, 200, 80, 255}
local HP_COLOR_MED  = {220, 180, 50, 255}
local HP_COLOR_LOW  = {220, 50, 50, 255}

local function getHpColor(ratio)
    if ratio > 0.5 then return HP_COLOR_HIGH end
    if ratio > 0.25 then return HP_COLOR_MED end
    return HP_COLOR_LOW
end

function M.RenderPlayer(nvg, l, camera)
    local player = GameState.player
    if not player or not player.alive then return end

    local sx, sy = RenderUtils.WorldToLocal(player.x, player.y, camera, l)
    local ts = camera:GetTileSize()
    local uiTs = GameConfig.TILE_SIZE  -- UI 元素（血条/铭牌）保持固定大小

    -- 受伤闪烁
    local flash = player.hurtFlashTimer > 0 and math.floor(player.hurtFlashTimer * 20) % 2 == 0

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
    if rk ~= _cachedRealmKey then
        _cachedRealmKey = rk
        _cachedRealmText = realmName .. " Lv." .. player.level
    end
    local realmText = _cachedRealmText

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
        if tn ~= _cachedTitleName then
            _cachedTitleName = tn
            _cachedTitleText = "「" .. tn .. "」"
        end
        local titleText = _cachedTitleText
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

end

-- ============================================================================
-- 宠物渲染
-- ============================================================================
function M.RenderPet(nvg, l, camera)
    local pet = GameState.pet
    if not pet or not pet.alive then return end

    local sx, sy = RenderUtils.WorldToLocal(pet.x, pet.y, camera, l)
    local ts = camera:GetTileSize()

    local flash = pet.hurtFlashTimer > 0 and math.floor(pet.hurtFlashTimer * 20) % 2 == 0

    -- 狗的视觉大小：高阶级更大；高级皮肤固定 1.3
    local appearanceId = pet.appearance and pet.appearance.selectedId or nil
    local baseSpriteScale
    local skinCfg = appearanceId and PetAppearanceConfig.byId[appearanceId]
    if skinCfg and skinCfg.category == "premium" then
        baseSpriteScale = 1.3    -- 所有高级皮肤
    elseif pet.tier >= 7 then
        baseSpriteScale = 1.3    -- T7: 天犬
    elseif pet.tier >= 6 then
        baseSpriteScale = 1.2    -- T6: 圣兽
    elseif pet.tier >= 5 then
        baseSpriteScale = 1.1    -- T5: 圣犬
    elseif pet.tier == 4 then
        baseSpriteScale = 1.0    -- T4: 灵兽
    else
        baseSpriteScale = 0.8    -- T0-T3: 幼犬/凶犬/斗犬/灵犬
    end
    local spriteSize = ts * baseSpriteScale
    local halfSize = spriteSize / 2

    local texPath = PetAppearanceConfig.GetTexture(appearanceId, pet.tier)
    local imgHandle = RenderUtils.GetCachedImage(nvg, texPath)

    if imgHandle then
        nvgSave(nvg)
        if not pet.facingRight then
            nvgTranslate(nvg, sx, 0)
            nvgScale(nvg, -1, 1)
            nvgTranslate(nvg, -sx, 0)
        end

        local imgX = sx - halfSize
        local imgY = sy - halfSize * 0.9

        -- 正常绘制宠物图片
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgHandle, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)

        if flash then
            -- 加法混合叠加：用图片 alpha 通道做蒙版，贴合轮廓发白光
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local tintPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgHandle, 0.7)
            nvgBeginPath(nvg)
            nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
            nvgFillPaint(nvg, tintPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
        end
        nvgRestore(nvg)
    else
        -- 回退：色块渲染
        local C = GameConfig.COLORS
        local bodyW = ts * 0.4
        local bodyH = ts * 0.3
        nvgBeginPath(nvg)
        nvgEllipse(nvg, sx, sy, bodyW / 2, bodyH / 2)
        if flash then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        else
            nvgFillColor(nvg, nvgRGBA(C.pet[1], C.pet[2], C.pet[3], 255))
        end
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 怪物渲染
-- ============================================================================
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

    local flash = m.hurtFlashTimer > 0 and math.floor(m.hurtFlashTimer * 20) % 2 == 0

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
    M.RenderMonsterFrame(nvg, cx, cy, radius, m.category, time)

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
                    local dx = m.x - zone.x
                    local dy = m.y - zone.y
                    if dx * dx + dy * dy <= zone.range * zone.range then
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
        if m.alive and m.hp < m.maxHp and not m.isPillar and camera:IsVisible(m.x, m.y, l.w, l.h, 2) then
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
        end
    end
end

-- ============================================================================
-- NPC 渲染
-- ============================================================================
function M.RenderNPCs(nvg, l, camera)
    local npcs = GameState.npcs
    for i = 1, #npcs do
        local npc = npcs[i]
        if camera:IsVisible(npc.x, npc.y, l.w, l.h, 2) then
            local sx, sy = RenderUtils.WorldToLocal(npc.x, npc.y, camera, l)
            local ts = camera:GetTileSize()

            -- 物件型NPC（公告栏等）：优先用图片，否则回退告示牌
            if npc.isObject then
                local objDrawn = false
                -- 优先使用 decorationType 渲染（如传送阵特效）
                if npc.decorationType then
                    local renderFn = DecorationRenderers["Render" .. npc.decorationType:gsub("^%l", string.upper):gsub("_%l", function(s) return s:sub(2):upper() end)]
                    if not renderFn then
                        -- 简单驼峰转换不够时，直接查方法表
                        local methodMap = { teleport_array = "RenderTeleportArray" }
                        local methodName = methodMap[npc.decorationType]
                        if methodName then renderFn = DecorationRenderers[methodName] end
                    end
                    if renderFn then
                        renderFn(nvg, sx - ts * 0.5, sy - ts * 0.5, ts, npc, GameState.gameTime or 0)
                        objDrawn = true
                    end
                end
                if not objDrawn and npc.image then
                    local imgH = RenderUtils.GetCachedImage(nvg, npc.image)
                    if imgH then
                        local spriteSize = npc.imageScale and (ts * npc.imageScale) or (ts * 1.6)
                        local imgX = sx - spriteSize / 2
                        local imgY = sy - spriteSize * 0.65
                        local imgPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgH, 1.0)
                        nvgBeginPath(nvg)
                        nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
                        nvgFillPaint(nvg, imgPaint)
                        nvgFill(nvg)
                        objDrawn = true
                    end
                end
                if not objDrawn then
                    DecorationRenderers.RenderSign(nvg, sx - ts * 0.5, sy - ts * 0.5, ts, npc)
                end

                -- 副本入口未领取奖励指示器（头顶黄色大感叹号，与公告栏同样式）
                if npc.interactType == "dungeon_entrance" and GameConfig.DUNGEON_ENABLED then
                    if M._dungeonClient == nil then
                        local _ok, _dc = pcall(require, "network.DungeonClient")
                        M._dungeonClient = _ok and _dc or false  -- false 表示加载失败，不再重试
                    end
                    if M._dungeonClient and M._dungeonClient ~= false and M._dungeonClient.HasPendingReward() then
                        local time = GameState.gameTime or 0
                        local spriteSize = ts * 1.6
                        local indicatorX = sx
                        local indicatorY = sy - spriteSize * 0.65 - 12
                        local bob = math.sin(time * 2.5) * 3
                        indicatorY = indicatorY + bob
                        local pulse = math.sin(time * 3.0) * 0.1 + 0.9
                        local indicatorR = 14 * pulse
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, indicatorX, indicatorY, indicatorR)
                        nvgFillColor(nvg, nvgRGBA(240, 190, 30, math.floor(240 * pulse)))
                        nvgFill(nvg)
                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, 20)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(nvg, nvgRGBA(60, 30, 0, 255))
                        nvgText(nvg, indicatorX, indicatorY, "!", nil)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, indicatorX, indicatorY, indicatorR + 4)
                        nvgStrokeColor(nvg, nvgRGBA(255, 220, 80, math.floor(120 * pulse)))
                        nvgStrokeWidth(nvg, 2)
                        nvgStroke(nvg)
                    end
                end

                -- 公告栏未领取奖励指示器（头顶黄色大感叹号）
                if npc.interactType == "bulletin" then
                    if not M._bulletinUI then
                        M._bulletinUI = require("ui.BulletinUI")
                    end
                    if M._bulletinUI.HasUnclaimedReward() then
                        local time = GameState.gameTime or 0
                        local spriteSize = ts * 1.6
                        -- 头顶正中位置
                        local indicatorX = sx
                        local indicatorY = sy - spriteSize * 0.65 - 12
                        -- 上下浮动动画
                        local bob = math.sin(time * 2.5) * 3
                        indicatorY = indicatorY + bob
                        -- 脉冲缩放
                        local pulse = math.sin(time * 3.0) * 0.1 + 0.9
                        local indicatorR = 14 * pulse
                        -- 黄色圆形背景
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, indicatorX, indicatorY, indicatorR)
                        nvgFillColor(nvg, nvgRGBA(240, 190, 30, math.floor(240 * pulse)))
                        nvgFill(nvg)
                        -- 深色感叹号
                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, 20)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(nvg, nvgRGBA(60, 30, 0, 255))
                        nvgText(nvg, indicatorX, indicatorY, "!", nil)
                        -- 外发光环
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, indicatorX, indicatorY, indicatorR + 4)
                        nvgStrokeColor(nvg, nvgRGBA(255, 220, 80, math.floor(120 * pulse)))
                        nvgStrokeWidth(nvg, 2)
                        nvgStroke(nvg)
                    end
                end
            else

            -- 有贴图的 NPC 用贴图渲染
            local drawn = false
            if npc.portrait then
                local imgHandle = RenderUtils.GetCachedImage(nvg, npc.portrait)
                if imgHandle then
                    local spriteSize = ts * 1.4 * (npc.iconScale or 1)
                    local halfSize = spriteSize / 2
                    local imgX = sx - halfSize
                    local imgY = sy - halfSize * 1.1
                    local imgPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgHandle, 1.0)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
                    nvgFillPaint(nvg, imgPaint)
                    nvgFill(nvg)
                    drawn = true
                end
            end

            if not drawn then
                -- 回退：色块渲染
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, sx - ts * 0.25, sy - ts * 0.2, ts * 0.5, ts * 0.5, 4)
                nvgFillColor(nvg, nvgRGBA(200, 180, 100, 255))
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, 200))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
            end

            -- ── NPC 名字（头顶 + 背景底 + 职能副标题） ──
            if not npc.hideName then
            nvgFontFace(nvg, "sans")

            -- 计算总高度：名字 + 可选副标题
            local hasSubtitle = npc.subtitle and #npc.subtitle > 0
            local nameFontSize = T.worldFont.name
            local subFontSize = T.worldFont.subtitle

            -- 测量名字宽度
            nvgFontSize(nvg, nameFontSize)
            local nameTextW = nvgTextBounds(nvg, 0, 0, npc.name, nil)

            -- 测量副标题宽度
            local subTextW = 0
            if hasSubtitle then
                nvgFontSize(nvg, subFontSize)
                subTextW = nvgTextBounds(nvg, 0, 0, npc.subtitle, nil)
            end

            -- 背景板尺寸
            local padH, padV = 8, 4
            local contentW = math.max(nameTextW, subTextW)
            local bgW = contentW + padH * 2
            local nameLineH = nameFontSize + padV
            local subLineH = hasSubtitle and (subFontSize + padV) or 0
            local bgH = nameLineH + subLineH + padV * 2
            local bgTopY = sy - ts * 0.85 - bgH / 2

            -- 暗底背景板
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx - bgW / 2, bgTopY, bgW, bgH, 5)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
            nvgFill(nvg)

            -- NPC 名字（金色）
            local nameCenterY = bgTopY + padV + nameLineH / 2
            nvgFontSize(nvg, nameFontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
            nvgText(nvg, sx, nameCenterY, npc.name, nil)

            -- 职能副标题（淡灰色，紧贴名字下方）
            if hasSubtitle then
                local subCenterY = nameCenterY + nameLineH / 2 + subLineH / 2
                nvgFontSize(nvg, subFontSize)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(200, 200, 180, 200))
                nvgText(nvg, sx, subCenterY, npc.subtitle, nil)
            end

            end -- hideName

            -- 云裳每日供奉未领取指示器（头顶黄色感叹号，同公告栏样式）
            if npc.interactType == "trial_offering" then
                if not M._trialTowerSystem then
                    M._trialTowerSystem = require("systems.TrialTowerSystem")
                end
                local tts = M._trialTowerSystem
                if tts.highestFloor >= 10 and not tts.IsDailyCollected() then
                    local time = GameState.gameTime or 0
                    local spriteSize = ts * 1.4
                    local indicatorX = sx
                    local indicatorY = sy - spriteSize * 0.65 - 12
                    local bob = math.sin(time * 2.5) * 3
                    indicatorY = indicatorY + bob
                    local pulse = math.sin(time * 3.0) * 0.1 + 0.9
                    local indicatorR = 14 * pulse
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, indicatorX, indicatorY, indicatorR)
                    nvgFillColor(nvg, nvgRGBA(240, 190, 30, math.floor(240 * pulse)))
                    nvgFill(nvg)
                    nvgFontFace(nvg, "sans")
                    nvgFontSize(nvg, 20)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(60, 30, 0, 255))
                    nvgText(nvg, indicatorX, indicatorY, "!", nil)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, indicatorX, indicatorY, indicatorR + 4)
                    nvgStrokeColor(nvg, nvgRGBA(255, 220, 80, math.floor(120 * pulse)))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                end
            end

            end -- isObject else
        end
    end
end

-- ============================================================================
-- 主城城门渲染
-- ============================================================================
function M.RenderLootDrops(nvg, l, camera)
    local drops = GameState.lootDrops
    local time = GameState.gameTime
    local ts = camera:GetTileSize()

    for i = 1, #drops do
        local drop = drops[i]
        if camera:IsVisible(drop.x, drop.y, l.w, l.h, 2) then
            local sx, sy = RenderUtils.WorldToLocal(drop.x, drop.y, camera, l)

            -- 判断是否有装备掉落（惰性缓存到 drop 对象，避免每帧重新扫描）
            if drop._bestItemCached == nil then
                local bi, bo = nil, 0
                if drop.items then
                    for j = 1, #drop.items do
                        local itm = drop.items[j]
                        local ord = GameConfig.QUALITY_ORDER[itm.quality] or 1
                        if ord > bo then
                            bo = ord
                            bi = itm
                        end
                    end
                end
                drop._bestItem = bi
                drop._bestOrder = bo
                drop._bestItemCached = true
            end
            local bestItem = drop._bestItem
            local bestOrder = drop._bestOrder

            if bestItem and bestItem.icon then
                -- ── 装备掉落：方框图标 + 品质光效 + 名称 ──
                local slotHalfBase = ts * 0.24   -- 方框半边长基准
                local cornerR = 4                -- 圆角
                local qCfg = GameConfig.QUALITY[bestItem.quality]
                local qc = qCfg and qCfg.color or {200, 200, 200, 255}
                local qName = qCfg and qCfg.name or "普通"
                local seed = drop.id or i
                local pulse = math.sin(time * 3 + seed) * 0.12 + 0.88

                -- 呼吸缩放（缓慢脉动）
                local breathe = 1.0 + math.sin(time * 1.8 + seed * 0.5) * 0.06
                local slotHalf = slotHalfBase * breathe

                -- 方框区域
                local bx = sx - slotHalf
                local by = sy - slotHalf
                local bw = slotHalf * 2
                local bh = bw

                -- ① 高品质外层光晕（order>=4 紫色以上）
                if bestOrder >= 4 then
                    local glowPulse = math.sin(time * 2.0 + seed) * 0.3 + 0.7
                    local glowR = slotHalf + 10 + math.sin(time * 1.5 + seed) * 3
                    local outerGlow = nvgRadialGradient(nvg, sx, sy, slotHalf, glowR,
                        nvgRGBA(qc[1], qc[2], qc[3], math.floor(60 * glowPulse)),
                        nvgRGBA(qc[1], qc[2], qc[3], 0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, sx, sy, glowR)
                    nvgFillPaint(nvg, outerGlow)
                    nvgFill(nvg)
                end

                -- ② 稀世以上（order>=5）：旋转光点粒子
                if bestOrder >= 5 then
                    local particleDist = slotHalf + 8
                    local sparkCount = math.min(bestOrder, 8)
                    for si = 1, sparkCount do
                        local angle = time * (1.0 + si * 0.25) + si * (6.28 / sparkCount)
                        local px = sx + math.cos(angle) * particleDist
                        local py = sy + math.sin(angle) * particleDist
                        local sparkAlpha = math.sin(time * 4 + si) * 0.4 + 0.6
                        local sparkR = 1.8 + math.sin(time * 5 + si * 2) * 0.8
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, px, py, sparkR)
                        nvgFillColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], math.floor(220 * sparkAlpha)))
                        nvgFill(nvg)
                    end
                end

                -- ③ 方框半透明背景
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, bx, by, bw, bh, cornerR)
                nvgFillColor(nvg, nvgRGBA(20, 22, 35, 160))
                nvgFill(nvg)

                -- ④ 品质色内发光
                local glowA = math.min(25 + bestOrder * 15, 110)
                local ga = math.floor(glowA * pulse)
                local innerGlow = nvgRadialGradient(nvg, sx, sy - slotHalf * 0.2,
                    slotHalf * 0.1, slotHalf * 1.0,
                    nvgRGBA(qc[1], qc[2], qc[3], ga),
                    nvgRGBA(qc[1], qc[2], qc[3], 0))
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, bx, by, bw, bh, cornerR)
                nvgFillPaint(nvg, innerGlow)
                nvgFill(nvg)

                -- ⑤ 装备图标
                local icon = bestItem.icon
                local isFilePath = icon and (icon:find("%.") or icon:find("/"))
                if isFilePath then
                    local imgHandle = RenderUtils.GetCachedImage(nvg, icon)
                    if imgHandle then
                        local imgSize = bw * 0.82
                        local imgX = sx - imgSize / 2
                        local imgY = sy - imgSize / 2
                        nvgSave(nvg)
                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, bx + 2, by + 2, bw - 4, bh - 4, cornerR - 1)
                        local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgSize, imgSize, 0, imgHandle, pulse)
                        nvgFillPaint(nvg, imgPaint)
                        nvgFill(nvg)
                        nvgRestore(nvg)
                    end
                elseif icon then
                    nvgFontFace(nvg, "sans")
                    nvgFontSize(nvg, slotHalf * 1.4)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(255 * pulse)))
                    nvgText(nvg, sx, sy, icon)
                end

                -- ⑥ 方框品质色边框
                local borderAlpha = math.floor((150 + bestOrder * 15) * pulse)
                local borderW = bestOrder >= 4 and 2.5 or 1.5
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, bx, by, bw, bh, cornerR)
                nvgStrokeColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], borderAlpha))
                nvgStrokeWidth(nvg, borderW)
                nvgStroke(nvg)

                -- ⑦ 品质名 + 装备名（图标下方）
                local textY = by + bh + 4
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 11)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                local tierStr = bestItem.tier and (bestItem.tier .. "阶 ") or ""
                nvgFillColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 240))
                nvgText(nvg, sx, textY, tierStr .. bestItem.name)
            else
                -- ── 非装备掉落：气球样式渲染 ──
                local seed = drop.id or i

                -- 收集气球项目（复用模块级缓冲区）
                local balloons = _balloons
                for _bi = 1, #balloons do balloons[_bi] = nil end
                -- 金币
                if drop.goldMin and drop.goldMin > 0 then
                    table.insert(balloons, {
                        label = tostring(drop.goldMin),
                        r = 255, g = 215, b = 50, icon = "💰",
                    })
                end
                -- 经验
                if drop.expReward and drop.expReward > 0 then
                    table.insert(balloons, {
                        label = tostring(drop.expReward),
                        r = 100, g = 220, b = 255, icon = "✨",
                    })
                end
                -- 灵韵
                if drop.lingYun and drop.lingYun > 0 then
                    table.insert(balloons, {
                        label = tostring(drop.lingYun),
                        r = 200, g = 130, b = 255, icon = "💎",
                    })
                end
                -- 消耗品
                if drop.consumables then
                    for cId, cAmt in pairs(drop.consumables) do
                        local cData = GameConfig.PET_FOOD[cId] or GameConfig.PET_MATERIALS[cId]
                        if cData then
                            local icon = IconUtils.GetTextIcon(cData.icon, "💊")
                            local label = cData.name or ""
                            if cAmt > 1 then label = label .. "×" .. cAmt end
                            table.insert(balloons, {
                                label = label,
                                r = 140, g = 230, b = 140, icon = icon,
                            })
                        end
                    end
                end
                -- 材料
                if drop.materials then
                    for _, mId in ipairs(drop.materials) do
                        local mData = MonsterData.Materials and MonsterData.Materials[mId]
                        if mData then
                            table.insert(balloons, {
                                label = "",
                                r = 180, g = 160, b = 255, icon = mData.icon or "🔮",
                            })
                        end
                    end
                end

                if #balloons == 0 then
                    table.insert(balloons, { label = "", r = 200, g = 200, b = 200, icon = "?" })
                end

                -- 气球排列参数
                local balloonR = 11
                local spacing = balloonR * 2.6
                local totalW = (#balloons - 1) * spacing
                local baseX = sx - totalW / 2

                for bi, b in ipairs(balloons) do
                    local bx = baseX + (bi - 1) * spacing
                    local bSeed = seed + bi * 3.7

                    -- 浮动动画：上下轻摇 + 左右微摆
                    local floatY = math.sin(time * 1.6 + bSeed) * 4
                    local floatX = math.sin(time * 1.1 + bSeed * 0.7) * 2
                    local by = sy - balloonR - 4 + floatY
                    bx = bx + floatX

                    -- 绳子（从气球底部到锚点）
                    local anchorY = sy + 2
                    local ropeCtrlX = bx + math.sin(time * 2.0 + bSeed) * 3
                    local ropeCtrlY = (by + balloonR + anchorY) * 0.5
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, bx, by + balloonR)
                    nvgQuadTo(nvg, ropeCtrlX, ropeCtrlY, sx, anchorY)
                    nvgStrokeColor(nvg, nvgRGBA(b.r, b.g, b.b, 120))
                    nvgStrokeWidth(nvg, 1.0)
                    nvgStroke(nvg)

                    -- 气球体（椭圆 + 高光）
                    local pulse = math.sin(time * 2.5 + bSeed) * 0.08 + 1.0
                    local rX = balloonR * pulse
                    local rY = balloonR * 1.15 * pulse

                    -- 气球主体渐变（从亮到暗）
                    nvgSave(nvg)
                    nvgBeginPath(nvg)
                    nvgEllipse(nvg, bx, by, rX, rY)
                    local bodyGrad = nvgLinearGradient(nvg,
                        bx - rX * 0.3, by - rY,
                        bx + rX * 0.3, by + rY,
                        nvgRGBA(math.min(b.r + 60, 255), math.min(b.g + 60, 255), math.min(b.b + 60, 255), 220),
                        nvgRGBA(math.floor(b.r * 0.7), math.floor(b.g * 0.7), math.floor(b.b * 0.7), 200))
                    nvgFillPaint(nvg, bodyGrad)
                    nvgFill(nvg)

                    -- 高光（左上角椭圆光斑）
                    nvgBeginPath(nvg)
                    nvgEllipse(nvg, bx - rX * 0.3, by - rY * 0.3, rX * 0.35, rY * 0.25)
                    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 80))
                    nvgFill(nvg)

                    -- 气球嘴（底部小三角）
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, bx - 2.5, by + rY)
                    nvgLineTo(nvg, bx, by + rY + 4)
                    nvgLineTo(nvg, bx + 2.5, by + rY)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(math.floor(b.r * 0.8), math.floor(b.g * 0.8), math.floor(b.b * 0.8), 220))
                    nvgFill(nvg)

                    nvgRestore(nvg)

                    -- 图标
                    nvgFontFace(nvg, "sans")
                    nvgFontSize(nvg, balloonR * 1.1)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
                    nvgText(nvg, bx, by - 1, b.icon)

                    -- 数值标签（气球下方）
                    if b.label and b.label ~= "" then
                        nvgFontSize(nvg, 10)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                        nvgFillColor(nvg, nvgRGBA(b.r, b.g, b.b, 220))
                        nvgText(nvg, bx, by + rY + 5, b.label)
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 篝火 - 火焰动画 + 木柴底座 + 烟雾
-- ============================================================================

-- ============================================================================
-- 福源果渲染 - 3×3 环境效果 + 果实本体 + 交互光效
-- ============================================================================

local FortuneFruitSystem_ = nil

function M.RenderFortuneFruits(nvg, l, camera)
    -- 副本模式下不渲染福源果
    if GameConfig.DUNGEON_ENABLED then
        local okDC, DungeonClient = pcall(require, "network.DungeonClient")
        if okDC and DungeonClient and DungeonClient.IsDungeonMode() then return end
    end

    if not FortuneFruitSystem_ then
        FortuneFruitSystem_ = require("systems.FortuneFruitSystem")
    end
    local allFruits = FortuneFruitSystem_.GetAllFruitsForRender()
    if #allFruits == 0 then return end

    local ts = camera:GetTileSize()
    local time = GameState.gameTime or 0
    local player = GameState.player

    for _, f in ipairs(allFruits) do
        if camera:IsVisible(f.x, f.y, l.w, l.h, 3) then
            local sx, sy = RenderUtils.WorldToLocal(f.x, f.y, camera, l)
            local collected = f.collected

            -- 玩家距离
            local dist = 999
            if player then
                local dx = player.x - f.x
                local dy = player.y - f.y
                dist = math.sqrt(dx * dx + dy * dy)
            end
            local nearby = (not collected) and dist <= FortuneFruitSystem_.INTERACT_RANGE

            if collected then
                -- ====== 已采集：置灰果实 ======
                local fruitR = ts * 0.22

                -- 灰色外发光（微弱）
                local glowGrad = nvgRadialGradient(nvg,
                    sx, sy, 0, fruitR * 2.0,
                    nvgRGBA(120, 120, 120, 25),
                    nvgRGBA(120, 120, 120, 0)
                )
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, fruitR * 2.0)
                nvgFillPaint(nvg, glowGrad)
                nvgFill(nvg)

                -- 灰色果实主体
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, fruitR)
                local grayGrad = nvgLinearGradient(nvg,
                    sx, sy - fruitR, sx, sy + fruitR,
                    nvgRGBA(140, 140, 130, 180),
                    nvgRGBA(100, 100, 90, 180)
                )
                nvgFillPaint(nvg, grayGrad)
                nvgFill(nvg)

                -- 灰色果蒂
                nvgSave(nvg)
                nvgTranslate(nvg, sx + fruitR * 0.15, sy - fruitR * 0.9)
                nvgRotate(nvg, 0.3)
                nvgBeginPath(nvg)
                nvgEllipse(nvg, 0, 0, fruitR * 0.5, fruitR * 0.2)
                nvgFillColor(nvg, nvgRGBA(100, 110, 90, 160))
                nvgFill(nvg)
                nvgRestore(nvg)

                -- "已拾取" 文字
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 12)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(150, 150, 140, 160))
                nvgText(nvg, sx, sy - fruitR * 2.2, "已拾取", nil)
            else
                -- ====== 未采集：完整特效 ======

                -- 3×3 环境效果：地面光晕
                local envPulse = 0.5 + 0.2 * math.sin(time * 1.5)
                local envRadius = ts * 1.8
                local envAlpha = nearby and math.floor(50 * envPulse) or math.floor(30 * envPulse)

                local grad = nvgRadialGradient(nvg,
                    sx, sy, ts * 0.3, envRadius,
                    nvgRGBA(140, 200, 60, envAlpha),
                    nvgRGBA(140, 200, 60, 0)
                )
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, envRadius)
                nvgFillPaint(nvg, grad)
                nvgFill(nvg)

                local coreAlpha = nearby and math.floor(60 * envPulse) or math.floor(35 * envPulse)
                local coreGrad = nvgRadialGradient(nvg,
                    sx, sy, 0, ts * 0.8,
                    nvgRGBA(200, 240, 100, coreAlpha),
                    nvgRGBA(200, 240, 100, 0)
                )
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, ts * 0.8)
                nvgFillPaint(nvg, coreGrad)
                nvgFill(nvg)

                -- 果实本体
                local fruitR = ts * 0.22
                local bob = math.sin(time * 2.0) * 2

                -- 外发光
                local glowPulse = 0.7 + 0.3 * math.sin(time * 3.0)
                local glowR = fruitR * (2.5 + (nearby and 1.0 or 0))
                local glowA = math.floor((nearby and 60 or 35) * glowPulse)
                local glowGrad = nvgRadialGradient(nvg,
                    sx, sy + bob, 0, glowR,
                    nvgRGBA(180, 230, 80, glowA),
                    nvgRGBA(180, 230, 80, 0)
                )
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy + bob, glowR)
                nvgFillPaint(nvg, glowGrad)
                nvgFill(nvg)

                -- 果实主体（金绿色圆形）
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy + bob, fruitR)
                local fruitGrad = nvgLinearGradient(nvg,
                    sx, sy + bob - fruitR, sx, sy + bob + fruitR,
                    nvgRGBA(200, 240, 80, 255),
                    nvgRGBA(120, 180, 40, 255)
                )
                nvgFillPaint(nvg, fruitGrad)
                nvgFill(nvg)

                -- 果实高光
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx - fruitR * 0.25, sy + bob - fruitR * 0.3, fruitR * 0.45)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 90))
                nvgFill(nvg)

                -- 果蒂
                nvgSave(nvg)
                nvgTranslate(nvg, sx + fruitR * 0.15, sy + bob - fruitR * 0.9)
                nvgRotate(nvg, 0.3)
                nvgBeginPath(nvg)
                nvgEllipse(nvg, 0, 0, fruitR * 0.5, fruitR * 0.2)
                nvgFillColor(nvg, nvgRGBA(80, 160, 40, 230))
                nvgFill(nvg)
                nvgRestore(nvg)

                -- 旋转光环
                local ringR = fruitR * 1.6
                local ringAngle = time * 1.5
                local ringAlpha = nearby and 140 or 70
                nvgSave(nvg)
                nvgTranslate(nvg, sx, sy + bob)
                nvgRotate(nvg, ringAngle)
                nvgBeginPath(nvg)
                nvgArc(nvg, 0, 0, ringR, 0, math.pi * 0.8, 1)
                nvgStrokeColor(nvg, nvgRGBA(200, 240, 100, ringAlpha))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
                nvgBeginPath(nvg)
                nvgArc(nvg, 0, 0, ringR, math.pi, math.pi * 1.8, 1)
                nvgStrokeColor(nvg, nvgRGBA(200, 240, 100, math.floor(ringAlpha * 0.6)))
                nvgStrokeWidth(nvg, 1.0)
                nvgStroke(nvg)
                nvgRestore(nvg)

                -- "福源果" 名称标签（大字醒目）
                local labelY = sy + bob - fruitR * 2.8
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 36)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                -- 描边（4-pass：上下左右，性能优于 8-pass 且视觉差异极小）
                nvgFillColor(nvg, nvgRGBA(20, 40, 10, 200))
                nvgText(nvg, sx - 1, labelY, "福源果", nil)
                nvgText(nvg, sx + 1, labelY, "福源果", nil)
                nvgText(nvg, sx, labelY - 1, "福源果", nil)
                nvgText(nvg, sx, labelY + 1, "福源果", nil)
                nvgFillColor(nvg, nvgRGBA(220, 255, 120, 255))
                nvgText(nvg, sx, labelY, "福源果", nil)

                -- 可交互时：上升光柱 + 提示/读条
                if nearby then
                    local pillarH = ts * 2.5
                    local pillarW = ts * 0.3
                    local pillarGrad = nvgLinearGradient(nvg,
                        sx, sy + bob, sx, sy + bob - pillarH,
                        nvgRGBA(180, 230, 80, 50),
                        nvgRGBA(180, 230, 80, 0)
                    )
                    nvgBeginPath(nvg)
                    nvgRect(nvg, sx - pillarW / 2, sy + bob - pillarH, pillarW, pillarH)
                    nvgFillPaint(nvg, pillarGrad)
                    nvgFill(nvg)

                    for p = 0, 3 do
                        local phase = time * 1.2 + p * 1.57
                        local py2 = (phase % 2.5) / 2.5
                        local px2 = math.sin(phase * 2.3) * ts * 0.15
                        local pAlpha = math.floor((1 - py2) * 150)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sx + px2, sy + bob - py2 * pillarH, 2)
                        nvgFillColor(nvg, nvgRGBA(220, 250, 140, pAlpha))
                        nvgFill(nvg)
                    end

                    -- 检查是否正在对此果实读条
                    local progress, chFruit = FortuneFruitSystem_.GetChannelProgress()
                    local isChanneling = progress and chFruit and chFruit.key == f.key

                    local promptY = labelY - 26
                    if isChanneling then
                        -- ====== 读条进度条 ======
                        local barW = 80
                        local barH = 12
                        local barX = sx - barW / 2
                        local barY = promptY - barH / 2

                        -- 背景
                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
                        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
                        nvgFill(nvg)

                        -- 进度填充
                        local fillW = (barW - 4) * progress
                        if fillW > 0 then
                            nvgBeginPath(nvg)
                            nvgRoundedRect(nvg, barX + 2, barY + 2, fillW, barH - 4, 2)
                            local barGrad = nvgLinearGradient(nvg,
                                barX + 2, barY, barX + 2 + fillW, barY,
                                nvgRGBA(140, 220, 60, 255),
                                nvgRGBA(220, 255, 100, 255)
                            )
                            nvgFillPaint(nvg, barGrad)
                            nvgFill(nvg)
                        end

                        -- 边框
                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
                        nvgStrokeColor(nvg, nvgRGBA(180, 230, 80, 180))
                        nvgStrokeWidth(nvg, 1)
                        nvgStroke(nvg)

                        -- 百分比文字
                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, 10)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
                        nvgText(nvg, sx, promptY, math.floor(progress * 100) .. "%", nil)
                    else
                        -- ====== "按E拾取" 提示 ======
                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, 13)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, sx - 36, promptY - 10, 72, 20, 6)
                        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
                        nvgFill(nvg)

                        nvgFillColor(nvg, nvgRGBA(220, 250, 140, 255))
                        nvgText(nvg, sx, promptY, "按E拾取", nil)
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- 试炼塔·锁链封印效果 (青云试炼特色)
-- 在驻守BOSS头像上绘制交叉铁链，表示BOSS被封印原地
-- 链环沿链条方向匀速滑动（履带效果），半透明不遮挡本体
-- ═══════════════════════════════════════════════════════

---绘制一条履带式滑动锁链
---@param nvg any
---@param x1 number 起点X
---@param y1 number 起点Y
---@param x2 number 终点X
---@param y2 number 终点Y
---@param linkCount number 链环数量
---@param linkW number 链环宽度（沿链方向）
---@param linkH number 链环高度（垂直于链方向）
---@param time number 动画时间
---@param speed number 滑动速度（t/秒）
---@param alpha number 整体透明度(0~255)
local function drawChainLine(nvg, x1, y1, x2, y2, linkCount, linkW, linkH, time, speed, alpha)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end

    -- 链的方向角
    local angle = math.atan(dy, dx)
    -- 履带滑动偏移：链环沿链条方向匀速前进
    local slide = (time * speed) % 1.0  -- 0~1 循环

    local ironA = math.floor(alpha * 0.9)
    local hlA   = math.floor(alpha * 0.4)

    for i = 0, linkCount - 1 do
        local t = ((i + slide) / linkCount) % 1.0
        local lx = x1 + dx * t
        local ly = y1 + dy * t
        -- 交替横竖模拟真实锁链环扣
        local linkAngle = angle
        if i % 2 == 0 then
            linkAngle = linkAngle + math.pi * 0.5
        end

        nvgSave(nvg)
        nvgTranslate(nvg, lx, ly)
        nvgRotate(nvg, linkAngle)

        -- 铁环椭圆（半透明铁灰）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, 0, 0, linkW * 0.5, linkH * 0.5)
        nvgStrokeColor(nvg, nvgRGBA(100, 105, 115, ironA))
        nvgStrokeWidth(nvg, linkH * 0.25)
        nvgStroke(nvg)

        -- 金属高光弧
        nvgBeginPath(nvg)
        nvgArc(nvg, 0, 0, linkW * 0.32, -math.pi * 0.75, -math.pi * 0.25, NVG_CW)
        nvgStrokeColor(nvg, nvgRGBA(180, 190, 205, hlA))
        nvgStrokeWidth(nvg, linkH * 0.1)
        nvgStroke(nvg)

        nvgRestore(nvg)
    end
end

---绘制锁链封印效果（两条交叉链 + 中心铁锁）
---@param nvg any
---@param cx number 头像中心X
---@param cy number 头像中心Y
---@param radius number 头像半径
---@param time number 游戏时间
function M.RenderChainSeal(nvg, cx, cy, radius, time)
    local r = radius + 2

    -- 链环尺寸——稀疏一些，不遮挡本体
    local linkW = radius * 0.26
    local linkH = radius * 0.16
    local linkCount = math.max(3, math.floor(radius / 8))  -- 更稀疏
    local chainAlpha = 140  -- 半透明

    -- ── 锁链1：左上→右下 ──
    local a1 = -math.pi * 0.75
    local x1s = cx + math.cos(a1) * r
    local y1s = cy + math.sin(a1) * r
    local x1e = cx + math.cos(a1 + math.pi) * r
    local y1e = cy + math.sin(a1 + math.pi) * r
    drawChainLine(nvg, x1s, y1s, x1e, y1e, linkCount, linkW, linkH, time, 0.15, chainAlpha)

    -- ── 锁链2：右上→左下 ──
    local a2 = -math.pi * 0.25
    local x2s = cx + math.cos(a2) * r
    local y2s = cy + math.sin(a2) * r
    local x2e = cx + math.cos(a2 + math.pi) * r
    local y2e = cy + math.sin(a2 + math.pi) * r
    drawChainLine(nvg, x2s, y2s, x2e, y2e, linkCount, linkW, linkH, time, -0.12, chainAlpha)

    -- ── 中心铁锁 ──
    local ls = radius * 0.26
    local lockA = 160  -- 锁也半透明

    -- 锁体
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx - ls * 0.5, cy - ls * 0.3, ls, ls * 0.7, ls * 0.12)
    nvgFillColor(nvg, nvgRGBA(70, 75, 85, lockA))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(120, 125, 135, lockA))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- 锁扣弧
    nvgBeginPath(nvg)
    nvgArc(nvg, cx, cy - ls * 0.3, ls * 0.22, math.pi, 0, NVG_CW)
    nvgStrokeColor(nvg, nvgRGBA(100, 105, 115, lockA))
    nvgStrokeWidth(nvg, ls * 0.13)
    nvgLineCap(nvg, NVG_ROUND)
    nvgStroke(nvg)

    -- 锁眼
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy + ls * 0.02, ls * 0.06)
    nvgFillColor(nvg, nvgRGBA(30, 30, 35, lockA))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, cy + ls * 0.07)
    nvgLineTo(nvg, cx, cy + ls * 0.18)
    nvgStrokeColor(nvg, nvgRGBA(30, 30, 35, lockA))
    nvgStrokeWidth(nvg, ls * 0.05)
    nvgStroke(nvg)
end

-- ============================================================================
-- 仙缘宝箱渲染 - 贴图宝箱 + 属性光效 + 读条进度
-- ============================================================================

local XianyuanChestSystem_ = nil
local XianyuanChestConfig_ = nil

-- 属性光效颜色 {r, g, b}
local XIANYUAN_ATTR_COLORS = {
    constitution = {220, 180, 60},   -- 根骨：金色
    fortune      = {80, 200, 120},   -- 福源：翠绿
    wisdom       = {120, 140, 240},  -- 悟性：靛蓝
    physique     = {230, 90, 80},    -- 体魄：赤红
}

function M.RenderXianyuanChests(nvg, l, camera)
    -- 副本模式下不渲染
    if GameConfig.DUNGEON_ENABLED then
        local okDC, DungeonClient = pcall(require, "network.DungeonClient")
        if okDC and DungeonClient and DungeonClient.IsDungeonMode() then return end
    end

    if not XianyuanChestSystem_ then
        XianyuanChestSystem_ = require("systems.XianyuanChestSystem")
    end
    if not XianyuanChestConfig_ then
        XianyuanChestConfig_ = require("config.XianyuanChestConfig")
    end

    local chapter = GameState.currentChapter or 1
    local chests = XianyuanChestSystem_.GetChestsForChapter(chapter)
    if #chests == 0 then return end

    local ts = camera:GetTileSize()
    local time = GameState.gameTime or 0
    local player = GameState.player

    for _, entry in ipairs(chests) do
        local cfg = entry.cfg
        -- 跳过无坐标的宝箱（用户稍后补充）
        if not cfg.x or not cfg.y then goto nextChest end

        if camera:IsVisible(cfg.x, cfg.y, l.w, l.h, 3) then
            local sx, sy = RenderUtils.WorldToLocal(cfg.x, cfg.y, camera, l)
            local opened = entry.opened
            local attr = cfg.attr or "constitution"
            local ac = XIANYUAN_ATTR_COLORS[attr] or XIANYUAN_ATTR_COLORS.constitution

            -- 玩家距离
            local dist = 999
            if player then
                local dx = player.x - cfg.x
                local dy = player.y - cfg.y
                dist = math.sqrt(dx * dx + dy * dy)
            end
            local nearby = (not opened) and dist <= (XianyuanChestConfig_.INTERACT_RANGE or 1.5)

            -- 宝箱贴图尺寸（2×2 瓦片视觉面积，文档 §10）
            local chestW = ts * 2.0
            local chestH = ts * 2.0

            if opened then
                -- ====== 已开启：置灰 + 半透明 ======

                -- 微弱灰色光晕
                local glowGrad = nvgRadialGradient(nvg,
                    sx, sy, 0, chestW * 1.2,
                    nvgRGBA(120, 120, 120, 20),
                    nvgRGBA(120, 120, 120, 0)
                )
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, chestW * 1.2)
                nvgFillPaint(nvg, glowGrad)
                nvgFill(nvg)

                -- 宝箱贴图（降低透明度模拟置灰）
                local texPath = XianyuanChestConfig_.CHEST_TEXTURES[attr]
                if texPath then
                    local img = RenderUtils.GetCachedImage(nvg, texPath)
                    if img and img > 0 then
                        nvgGlobalAlpha(nvg, 0.35)
                        local pat = nvgImagePattern(nvg,
                            sx - chestW / 2, sy - chestH / 2,
                            chestW, chestH, 0, img, 1.0)
                        nvgBeginPath(nvg)
                        nvgRect(nvg, sx - chestW / 2, sy - chestH / 2, chestW, chestH)
                        nvgFillPaint(nvg, pat)
                        nvgFill(nvg)
                        nvgGlobalAlpha(nvg, 1.0)
                    end
                end

                -- "已开启" 文字
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 12)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(150, 150, 140, 140))
                nvgText(nvg, sx, sy - chestH / 2 - 12, "此箱机缘已尽", nil)
            else
                -- ====== 未开启：完整特效 ======

                -- 地面光晕（属性色）
                local envPulse = 0.5 + 0.2 * math.sin(time * 1.5)
                local envRadius = ts * 2.5
                local envAlpha = nearby and math.floor(55 * envPulse) or math.floor(30 * envPulse)

                local grad = nvgRadialGradient(nvg,
                    sx, sy, ts * 0.2, envRadius,
                    nvgRGBA(ac[1], ac[2], ac[3], envAlpha),
                    nvgRGBA(ac[1], ac[2], ac[3], 0)
                )
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, envRadius)
                nvgFillPaint(nvg, grad)
                nvgFill(nvg)

                -- 宝箱浮动
                local bob = math.sin(time * 1.8) * 2

                -- 外发光（属性色脉冲）
                local glowPulse = 0.7 + 0.3 * math.sin(time * 2.5)
                local glowR = chestW * (1.0 + (nearby and 0.5 or 0))
                local glowA = math.floor((nearby and 55 or 30) * glowPulse)
                local glowGrad = nvgRadialGradient(nvg,
                    sx, sy + bob, 0, glowR,
                    nvgRGBA(ac[1], ac[2], ac[3], glowA),
                    nvgRGBA(ac[1], ac[2], ac[3], 0)
                )
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy + bob, glowR)
                nvgFillPaint(nvg, glowGrad)
                nvgFill(nvg)

                -- 宝箱贴图
                local texPath = XianyuanChestConfig_.CHEST_TEXTURES[attr]
                if texPath then
                    local img = RenderUtils.GetCachedImage(nvg, texPath)
                    if img and img > 0 then
                        local pat = nvgImagePattern(nvg,
                            sx - chestW / 2, sy + bob - chestH / 2,
                            chestW, chestH, 0, img, 1.0)
                        nvgBeginPath(nvg)
                        nvgRect(nvg, sx - chestW / 2, sy + bob - chestH / 2, chestW, chestH)
                        nvgFillPaint(nvg, pat)
                        nvgFill(nvg)
                    end
                end

                -- 旋转光环（属性色）
                local ringR = chestW * 0.55
                local ringAngle = time * 1.2
                local ringAlpha = nearby and 130 or 60
                nvgSave(nvg)
                nvgTranslate(nvg, sx, sy + bob)
                nvgRotate(nvg, ringAngle)
                nvgBeginPath(nvg)
                nvgArc(nvg, 0, 0, ringR, 0, math.pi * 0.8, 1)
                nvgStrokeColor(nvg, nvgRGBA(ac[1], ac[2], ac[3], ringAlpha))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
                nvgBeginPath(nvg)
                nvgArc(nvg, 0, 0, ringR, math.pi, math.pi * 1.8, 1)
                nvgStrokeColor(nvg, nvgRGBA(ac[1], ac[2], ac[3], math.floor(ringAlpha * 0.5)))
                nvgStrokeWidth(nvg, 1.0)
                nvgStroke(nvg)
                nvgRestore(nvg)

                -- 属性名标签
                local attrName = XianyuanChestConfig_.ATTR_NAMES[attr] or attr
                local labelText = "仙缘·" .. attrName
                local labelY = sy + bob - chestH / 2 - 10
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 30)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                -- 4-pass 描边
                nvgFillColor(nvg, nvgRGBA(20, 20, 30, 200))
                nvgText(nvg, sx - 1, labelY, labelText, nil)
                nvgText(nvg, sx + 1, labelY, labelText, nil)
                nvgText(nvg, sx, labelY - 1, labelText, nil)
                nvgText(nvg, sx, labelY + 1, labelText, nil)
                -- 属性色文字
                nvgFillColor(nvg, nvgRGBA(ac[1], ac[2], ac[3], 255))
                nvgText(nvg, sx, labelY, labelText, nil)

                -- 可交互时：光柱 + 提示/读条
                if nearby then
                    -- 上升光柱
                    local pillarH = ts * 2.5
                    local pillarW = ts * 0.3
                    local pillarGrad = nvgLinearGradient(nvg,
                        sx, sy + bob, sx, sy + bob - pillarH,
                        nvgRGBA(ac[1], ac[2], ac[3], 45),
                        nvgRGBA(ac[1], ac[2], ac[3], 0)
                    )
                    nvgBeginPath(nvg)
                    nvgRect(nvg, sx - pillarW / 2, sy + bob - pillarH, pillarW, pillarH)
                    nvgFillPaint(nvg, pillarGrad)
                    nvgFill(nvg)

                    -- 上升粒子
                    for p = 0, 3 do
                        local phase = time * 1.2 + p * 1.57
                        local py2 = (phase % 2.5) / 2.5
                        local px2 = math.sin(phase * 2.3) * ts * 0.15
                        local pAlpha = math.floor((1 - py2) * 140)
                        nvgBeginPath(nvg)
                        nvgCircle(nvg, sx + px2, sy + bob - py2 * pillarH, 2)
                        nvgFillColor(nvg, nvgRGBA(ac[1], ac[2], ac[3], pAlpha))
                        nvgFill(nvg)
                    end

                    -- 检查是否正在对此宝箱读条
                    local progress, chChestId = XianyuanChestSystem_.GetChannelProgress()
                    local isChanneling = progress and chChestId and chChestId == entry.chestId

                    local promptY = labelY - 26
                    if isChanneling then
                        -- ====== 读条进度条 ======
                        local barW = 80
                        local barH = 12
                        local barX = sx - barW / 2
                        local barY = promptY - barH / 2

                        -- 背景
                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
                        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
                        nvgFill(nvg)

                        -- 进度填充
                        local fillW = (barW - 4) * progress
                        if fillW > 0 then
                            nvgBeginPath(nvg)
                            nvgRoundedRect(nvg, barX + 2, barY + 2, fillW, barH - 4, 2)
                            local barGrad = nvgLinearGradient(nvg,
                                barX + 2, barY, barX + 2 + fillW, barY,
                                nvgRGBA(ac[1], ac[2], ac[3], 255),
                                nvgRGBA(math.min(ac[1] + 40, 255), math.min(ac[2] + 40, 255), math.min(ac[3] + 40, 255), 255)
                            )
                            nvgFillPaint(nvg, barGrad)
                            nvgFill(nvg)
                        end

                        -- 边框
                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
                        nvgStrokeColor(nvg, nvgRGBA(ac[1], ac[2], ac[3], 180))
                        nvgStrokeWidth(nvg, 1)
                        nvgStroke(nvg)

                        -- 百分比文字
                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, 10)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
                        nvgText(nvg, sx, promptY, math.floor(progress * 100) .. "%", nil)
                    else
                        -- ====== "按E查看" 提示 ======
                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, 13)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, sx - 36, promptY - 10, 72, 20, 6)
                        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
                        nvgFill(nvg)

                        nvgFillColor(nvg, nvgRGBA(ac[1], ac[2], ac[3], 255))
                        nvgText(nvg, sx, promptY, "按E查看", nil)
                    end
                end
            end
        end
        ::nextChest::
    end
end

return M
