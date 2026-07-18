-- entities/chests.lua - 锁链封印与仙缘宝箱渲染
---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local shared = require("rendering.entities.shared")
local GameConfig = shared.GameConfig
local GameState = shared.GameState
local T = shared.T
local RenderUtils = shared.RenderUtils

local M = {}

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

-- ============================================================================
-- 乌家宝藏渲染 - 单格宝箱 + 紫金光效 + 交互提示
-- ============================================================================

local WubaoTreasureSystem_ = nil
local WubaoTreasureConfig_ = nil

function M.RenderWubaoTreasureChests(nvg, l, camera)
    if GameConfig.DUNGEON_ENABLED then
        local okDC, DungeonClient = pcall(require, "network.DungeonClient")
        if okDC and DungeonClient and DungeonClient.IsDungeonMode() then return end
    end

    if not WubaoTreasureSystem_ then
        WubaoTreasureSystem_ = require("systems.WubaoTreasureSystem")
    end
    if not WubaoTreasureConfig_ then
        WubaoTreasureConfig_ = require("config.WubaoTreasureConfig")
    end

    local chapter = GameState.currentChapter or 1
    local chests = WubaoTreasureSystem_.GetChestsForChapter(chapter)
    if #chests == 0 then return end

    local ts = camera:GetTileSize()
    local time = GameState.gameTime or 0
    local player = GameState.player
    local img = RenderUtils.GetCachedImage(nvg, WubaoTreasureConfig_.CHEST_TEXTURE)

    for _, entry in ipairs(chests) do
        local cfg = entry.cfg
        if camera:IsVisible(cfg.x, cfg.y, l.w, l.h, 2) then
            local sx, sy = RenderUtils.WorldToLocal(cfg.x, cfg.y, camera, l)
            local opened = entry.opened
            local dist = 999
            if player then
                local dx = player.x - cfg.x
                local dy = player.y - cfg.y
                dist = math.sqrt(dx * dx + dy * dy)
            end
            local nearby = (not opened) and dist <= (WubaoTreasureConfig_.INTERACT_RANGE or 1.5)
            local chestW = ts * 1.15
            local chestH = ts * 1.15
            local bob = opened and 0 or math.sin(time * 1.7 + cfg.x * 0.13) * 1.5

            if opened then
                nvgGlobalAlpha(nvg, 0.32)
                if img and img > 0 then
                    local pat = nvgImagePattern(nvg, sx - chestW / 2, sy - chestH / 2, chestW, chestH, 0, img, 1.0)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, sx - chestW / 2, sy - chestH / 2, chestW, chestH)
                    nvgFillPaint(nvg, pat)
                    nvgFill(nvg)
                end
                nvgGlobalAlpha(nvg, 1.0)
            else
                local pulse = 0.65 + 0.25 * math.sin(time * 2.2 + cfg.y * 0.17)
                local glowR = nearby and ts * 1.4 or ts * 1.0
                local glow = nvgRadialGradient(nvg,
                    sx, sy + bob, 0, glowR,
                    nvgRGBA(165, 95, 255, nearby and math.floor(70 * pulse) or math.floor(38 * pulse)),
                    nvgRGBA(255, 205, 80, 0)
                )
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy + bob, glowR)
                nvgFillPaint(nvg, glow)
                nvgFill(nvg)

                if img and img > 0 then
                    local pat = nvgImagePattern(nvg, sx - chestW / 2, sy + bob - chestH / 2, chestW, chestH, 0, img, 1.0)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, sx - chestW / 2, sy + bob - chestH / 2, chestW, chestH)
                    nvgFillPaint(nvg, pat)
                    nvgFill(nvg)
                end

                if nearby then
                    local progress, channelChestId = WubaoTreasureSystem_.GetChannelProgress()
                    local isChanneling = progress and channelChestId == entry.chestId
                    local promptY = sy + bob - chestH / 2 - 14

                    if isChanneling then
                        local barW = 78
                        local barH = 12
                        local barX = sx - barW / 2
                        local barY = promptY - barH / 2
                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
                        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
                        nvgFill(nvg)

                        local fillW = (barW - 4) * math.min(progress or 0, 1)
                        if fillW > 0 then
                            nvgBeginPath(nvg)
                            nvgRoundedRect(nvg, barX + 2, barY + 2, fillW, barH - 4, 2)
                            local barGrad = nvgLinearGradient(nvg,
                                barX + 2, barY, barX + 2 + fillW, barY,
                                nvgRGBA(165, 95, 255, 255),
                                nvgRGBA(255, 215, 90, 255)
                            )
                            nvgFillPaint(nvg, barGrad)
                            nvgFill(nvg)
                        end

                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
                        nvgStrokeColor(nvg, nvgRGBA(255, 215, 90, 190))
                        nvgStrokeWidth(nvg, 1)
                        nvgStroke(nvg)

                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, 10)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
                        nvgText(nvg, sx, promptY, math.floor((progress or 0) * 100) .. "%", nil)
                    else
                        nvgFontFace(nvg, "sans")
                        nvgFontSize(nvg, 13)
                        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgBeginPath(nvg)
                        nvgRoundedRect(nvg, sx - 38, promptY - 10, 76, 20, 6)
                        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 165))
                        nvgFill(nvg)
                        nvgFillColor(nvg, nvgRGBA(255, 220, 120, 255))
                        nvgText(nvg, sx, promptY, "按E查看", nil)
                    end
                end
            end
        end
    end
end

return M
