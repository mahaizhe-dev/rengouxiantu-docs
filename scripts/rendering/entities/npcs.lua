---@diagnostic disable
-- entities/npcs.lua - NPC 渲染
local shared = require("rendering.entities.shared")
local GameConfig = shared.GameConfig
local GameState = shared.GameState
local T = shared.T
local RenderUtils = shared.RenderUtils
local IconUtils = shared.IconUtils
local DecorationRenderers = shared.DecorationRenderers

local M = {}

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

return M
