-- entities/loot.lua - 掉落物与福缘果渲染
local shared = require("rendering.entities.shared")
local GameConfig = shared.GameConfig
local GameState = shared.GameState
local T = shared.T
local RenderUtils = shared.RenderUtils
local IconUtils = shared.IconUtils
local _balloons = shared._balloons

local M = {}

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
local TownReturnSystem_ = nil

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

return M
