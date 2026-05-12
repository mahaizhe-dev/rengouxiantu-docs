-- ============================================================================
-- WorldRenderer.lua - 游戏世界 NanoVG 渲染（精简调度器）
-- 渲染职责已拆分到:
--   RenderUtils.lua          - 共享工具（图片缓存、坐标转换）
--   EntityRenderer.lua       - 实体渲染（玩家、宠物、怪物、NPC、掉落物）
--   DecorationRenderers.lua  - 装饰物渲染（27种装饰 + 城门 + 调度）
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ActiveZoneData = require("config.ActiveZoneData")
local QuestData = require("config.QuestData")
local QuestSystem = require("systems.QuestSystem")
local EffectRenderer = require("rendering.EffectRenderer")
local TileRenderer = require("rendering.TileRenderer")
local RenderUtils = require("rendering.RenderUtils")
local EntityRenderer = require("rendering.EntityRenderer")
local DecorationRenderers = require("rendering.DecorationRenderers")
local LingYunFx = require("rendering.LingYunFx")
local _drOk, DungeonRenderer = pcall(require, "rendering.DungeonRenderer")
if not _drOk then
    print("[WARN] DungeonRenderer load failed: " .. tostring(DungeonRenderer))
    DungeonRenderer = nil
end

-- 模块级常量：四方向邻居偏移（避免每帧每瓦片重建 ~1500 表/帧）
local neighbors = {
    {dx = 0, dy = -1, side = "top"},    -- 上
    {dx = 0, dy = 1,  side = "bottom"}, -- 下
    {dx = -1, dy = 0, side = "left"},    -- 左
    {dx = 1, dy = 0,  side = "right"},   -- 右
}

---@class WorldRenderer : Widget
local WorldRenderer = Widget:Extend("WorldRenderer")

function WorldRenderer:Init(props)
    props = props or {}
    props.width = props.width or "100%"
    props.height = props.height or "100%"
    props.backgroundColor = props.backgroundColor or {20, 25, 15, 255}

    -- 游戏引用（在 main.lua 中设置）
    self.gameMap = nil
    self.camera = nil

    Widget.Init(self, props)
end

--- 设置游戏引用
function WorldRenderer:SetGameRefs(gameMap, camera)
    self.gameMap = gameMap
    self.camera = camera
end

-- ============================================================================
-- 主渲染管线
-- ============================================================================
function WorldRenderer:Render(nvg)
    self:RenderFullBackground(nvg)

    local l = self:GetAbsoluteLayout()
    local gameMap = self.gameMap
    local camera = self.camera
    if not gameMap or not camera then return end

    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    -- 绘制地图瓦片
    self:RenderTiles(nvg, l)

    -- 绘制副本地板（在瓦片之上，覆盖空白区域）
    if DungeonRenderer then DungeonRenderer.RenderDungeonFloor(nvg, l, camera) end

    -- 绘制封印光幕特效（在瓦片之上、装饰物之下）
    self:RenderSealBarriers(nvg, l)

    -- 绘制主城围墙出入口标记
    DecorationRenderers.RenderTownGates(nvg, l, camera)

    -- 绘制装饰物
    DecorationRenderers.RenderDecorations(nvg, l, camera)

    -- 绘制福源果（地面交互物）
    EntityRenderer.RenderFortuneFruits(nvg, l, camera)

    -- 绘制仙缘宝箱（地面交互物）
    EntityRenderer.RenderXianyuanChests(nvg, l, camera)

    -- 绘制 NPC
    EntityRenderer.RenderNPCs(nvg, l, camera)

    -- 绘制掉落物
    EntityRenderer.RenderLootDrops(nvg, l, camera)

    -- 绘制怪物
    EntityRenderer.RenderMonsters(nvg, l, camera)

    -- 副本 BOSS 已是 GameState.monsters 中的本地 Monster 实体，由 RenderMonsters 统一绘制

    -- 绘制副本远程玩家（在 BOSS 之上、本地玩家之下）
    if DungeonRenderer then DungeonRenderer.RenderRemotePlayers(nvg, l, camera) end

    -- 绘制宠物
    EntityRenderer.RenderPet(nvg, l, camera)

    -- 绘制玩家
    EntityRenderer.RenderPlayer(nvg, l, camera)

    -- 绘制怪物血条（在实体上方）
    EntityRenderer.RenderMonsterHealthBars(nvg, l, camera)

    -- 绘制战斗特效（浮动伤害数字）
    EffectRenderer.Render(nvg, l, camera)

    -- 处理灵韵拾取粒子队列（世界坐标→屏幕坐标）
    LingYunFx.ProcessPending(camera, l)

    -- GM：鼠标悬停显示瓦片坐标
    if GameConfig.GM_SHOW_COORDS then
        self:RenderHoverCoord(nvg, l)
    end

    nvgRestore(nvg)
end

--- 世界坐标转渲染坐标（保留供外部直接调用兼容）
function WorldRenderer:WorldToLocal(worldX, worldY, l)
    return RenderUtils.WorldToLocal(worldX, worldY, self.camera, l)
end

-- ============================================================================
-- 瓦片渲染（RPGMaker 风格程序化纹理）
-- ============================================================================
function WorldRenderer:RenderTiles(nvg, l)
    local gameMap = self.gameMap
    local camera = self.camera
    local tileSize = camera:GetTileSize()
    local startX, startY, endX, endY = camera:GetVisibleRange(l.w, l.h)

    for y = startY, endY do
        for x = startX, endX do
            local tileType = gameMap:GetTile(x, y)
            local sx, sy = RenderUtils.WorldToLocal(x - 0.5, y - 0.5, camera, l)

            -- 使用 TileRenderer 程序化绘制每种瓦片
            TileRenderer.RenderTile(nvg, sx, sy, tileSize, tileType, x, y)
        end
    end

    -- 区域边缘过渡效果（半透明渐变遮罩）
    self:RenderZoneTransitions(nvg, l, startX, startY, endX, endY)
end

-- ============================================================================
-- 区域边缘过渡（在不同地形交界处绘制渐变融合）
-- ============================================================================
function WorldRenderer:RenderZoneTransitions(nvg, l, startX, startY, endX, endY)
    local gameMap = self.gameMap
    local tileSize = self.camera:GetTileSize()

    -- 数据驱动：从 ZoneData 读取可通行瓦片和过渡色（B1 优化）
    local zd = ActiveZoneData.Get()
    local walkableTiles = zd.WALKABLE_TILES or {}
    local transitionColors = zd.TILE_TRANSITION_COLORS or {}

    for y = startY, endY do
        for x = startX, endX do
            local tileType = gameMap:GetTile(x, y)
            if not walkableTiles[tileType] then goto continue end

            local sx, sy = RenderUtils.WorldToLocal(x - 0.5, y - 0.5, self.camera, l)

            -- 检查四方向邻居（常量表已提升到模块级）

            for _, n in ipairs(neighbors) do
                local neighborType = gameMap:GetTile(x + n.dx, y + n.dy)
                if neighborType ~= tileType and walkableTiles[neighborType] then
                    local tc = transitionColors[neighborType]
                    if tc then
                        -- 在当前瓦片的对应边绘制一条渐变色带
                        local fadeW = tileSize * 0.25
                        nvgBeginPath(nvg)
                        if n.side == "top" then
                            nvgRect(nvg, sx, sy, tileSize, fadeW)
                        elseif n.side == "bottom" then
                            nvgRect(nvg, sx, sy + tileSize - fadeW, tileSize, fadeW)
                        elseif n.side == "left" then
                            nvgRect(nvg, sx, sy, fadeW, tileSize)
                        elseif n.side == "right" then
                            nvgRect(nvg, sx + tileSize - fadeW, sy, fadeW, tileSize)
                        end
                        nvgFillColor(nvg, nvgRGBA(tc[1], tc[2], tc[3], 40))
                        nvgFill(nvg)
                    end
                end
            end
            ::continue::
        end
    end
end

-- ============================================================================
-- 封印光幕特效（简洁流光带）
-- ============================================================================
function WorldRenderer:RenderSealBarriers(nvg, l)
    local camera = self.camera
    if not camera then return end

    local tileSize = camera:GetTileSize()
    local t = GameState.gameTime

    for zoneId, sealData in pairs(QuestData.SEALS) do
        -- 跳过不属于当前章节的封印
        if not QuestSystem.IsSealInCurrentChapter(zoneId) then goto continue end
        if QuestSystem.IsSealRemoved(zoneId) then goto continue end

        local tiles = sealData.sealTiles
        if not tiles or #tiles == 0 then goto continue end

        -- 封印区域包围盒（静态数据，首次计算后缓存）
        if not sealData._bboxCached then
            local mnX, mnY = math.huge, math.huge
            local mxX, mxY = -math.huge, -math.huge
            for _, tile in ipairs(tiles) do
                if tile.x < mnX then mnX = tile.x end
                if tile.y < mnY then mnY = tile.y end
                if tile.x > mxX then mxX = tile.x end
                if tile.y > mxY then mxY = tile.y end
            end
            sealData._bboxMinX = mnX
            sealData._bboxMinY = mnY
            sealData._bboxMaxX = mxX
            sealData._bboxMaxY = mxY
            sealData._bboxCached = true
        end
        local minX, minY = sealData._bboxMinX, sealData._bboxMinY
        local maxX, maxY = sealData._bboxMaxX, sealData._bboxMaxY

        local sx, sy = RenderUtils.WorldToLocal(minX - 0.5, minY - 0.5, camera, l)
        local barrierW = (maxX - minX + 1) * tileSize
        local barrierH = (maxY - minY + 1) * tileSize

        -- 视锥剔除
        if sx + barrierW < l.x or sx > l.x + l.w or
           sy + barrierH < l.y or sy > l.y + l.h then
            goto continue
        end

        -- 判断封印所属章节（用于不同视觉风格）
        local chain = QuestData.ZONE_QUESTS[sealData.questChain]
        local chapter = chain and chain.chapter or 1

        -- 用原始地形色覆盖山岩纹理（从 ZoneData 数据驱动读取）
        -- 中洲封印（chapter=101）跳过：其 sealTile=SEAL_RED，瓦片层已自渲染底色
        if chapter ~= 101 then
            local zd = ActiveZoneData.Get()
            local TILE = zd.TILE
            local origTile = sealData.originalTile or TILE.GRASS
            local transColors = zd.TILE_TRANSITION_COLORS or {}
            local oc = transColors[origTile] or {80, 140, 60}
            for _, tile in ipairs(tiles) do
                local tx, ty = RenderUtils.WorldToLocal(tile.x - 0.5, tile.y - 0.5, camera, l)
                local shade = ((tile.x + tile.y) % 2 == 0) and 8 or -5
                nvgBeginPath(nvg)
                nvgRect(nvg, tx, ty, tileSize, tileSize)
                nvgFillColor(nvg, nvgRGBA(
                    math.min(255, oc[1] + shade),
                    math.min(255, oc[2] + shade),
                    math.min(255, oc[3] + shade), 255))
                nvgFill(nvg)
            end
        end

        if chapter == 2 then
            -- ═══ 第二章·血红色封印光效 ═══
            local pulse = 0.65 + 0.2 * math.sin(t * 2.2)
            local baseAlpha = math.floor(210 * pulse)

            -- 底层：暗红色光幕（自下而上渐隐）
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, barrierW, barrierH)
            local curtain = nvgLinearGradient(nvg,
                sx, sy + barrierH, sx, sy,
                nvgRGBA(180, 20, 20, baseAlpha),
                nvgRGBA(120, 10, 10, math.floor(baseAlpha * 0.1))
            )
            nvgFillPaint(nvg, curtain)
            nvgFill(nvg)

            -- 中层：脉动血纹横纹（3条水平光带上下浮动）
            for i = 0, 2 do
                local offset = math.sin(t * 1.5 + i * 2.1) * barrierH * 0.12
                local bandY = sy + barrierH * (0.25 + i * 0.25) + offset
                local bandH = tileSize * 0.25
                local bandAlpha = math.floor(120 * pulse * (0.6 + 0.4 * math.sin(t * 3.0 + i * 1.7)))
                nvgBeginPath(nvg)
                nvgRect(nvg, sx, bandY - bandH * 0.5, barrierW, bandH)
                nvgFillColor(nvg, nvgRGBA(255, 40, 30, bandAlpha))
                nvgFill(nvg)
            end

            -- 上层：边缘辉光（封印两侧竖向红光边框）
            local edgeW = tileSize * 0.2
            local edgeAlpha = math.floor(150 * pulse)
            -- 左边缘
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, edgeW, barrierH)
            local leftGlow = nvgLinearGradient(nvg,
                sx, sy, sx + edgeW, sy,
                nvgRGBA(255, 50, 30, edgeAlpha),
                nvgRGBA(200, 20, 10, 0)
            )
            nvgFillPaint(nvg, leftGlow)
            nvgFill(nvg)
            -- 右边缘
            nvgBeginPath(nvg)
            nvgRect(nvg, sx + barrierW - edgeW, sy, edgeW, barrierH)
            local rightGlow = nvgLinearGradient(nvg,
                sx + barrierW, sy, sx + barrierW - edgeW, sy,
                nvgRGBA(255, 50, 30, edgeAlpha),
                nvgRGBA(200, 20, 10, 0)
            )
            nvgFillPaint(nvg, rightGlow)
            nvgFill(nvg)
        elseif chapter == 3 then
            -- ═══ 第三章·沙金色封印光效（逐瓦片渲染，避免包围盒覆盖整寨） ═══
            local pulse = 0.6 + 0.25 * math.sin(t * 2.0)

            for ti, tile in ipairs(tiles) do
                local tx, ty = RenderUtils.WorldToLocal(tile.x - 0.5, tile.y - 0.5, camera, l)

                -- 视锥剔除单瓦片
                if tx + tileSize >= l.x and tx <= l.x + l.w and
                   ty + tileSize >= l.y and ty <= l.y + l.h then

                    -- 底层：沙金色光幕
                    local baseAlpha = math.floor(200 * pulse)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, tx, ty, tileSize, tileSize)
                    nvgFillColor(nvg, nvgRGBA(220, 180, 50, baseAlpha))
                    nvgFill(nvg)

                    -- 中层：脉动横纹
                    local bandOffset = math.sin(t * 1.5 + ti * 1.1) * tileSize * 0.15
                    local bandY = ty + tileSize * 0.5 + bandOffset
                    local bandH = tileSize * 0.15
                    local bandAlpha = math.floor(120 * pulse * (0.6 + 0.4 * math.sin(t * 2.5 + ti * 0.8)))
                    nvgBeginPath(nvg)
                    nvgRect(nvg, tx, bandY - bandH * 0.5, tileSize, bandH)
                    nvgFillColor(nvg, nvgRGBA(255, 230, 100, bandAlpha))
                    nvgFill(nvg)

                    -- 上层：闪烁星点（每瓦片1个）
                    local phase = t * 1.8 + ti * 2.17
                    local sparkAlpha = math.floor(200 * (0.3 + 0.7 * math.abs(math.sin(phase))))
                    local sparkX = tx + tileSize * (0.3 + 0.4 * ((math.sin(phase * 0.7) + 1) * 0.5))
                    local sparkY = ty + tileSize * (0.3 + 0.4 * ((math.cos(phase * 0.5) + 1) * 0.5))
                    local sparkR = tileSize * (0.05 + 0.03 * math.sin(phase * 2.0))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, sparkX, sparkY, sparkR)
                    nvgFillColor(nvg, nvgRGBA(255, 245, 170, sparkAlpha))
                    nvgFill(nvg)
                    -- 外围辉光
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, sparkX, sparkY, sparkR * 3)
                    nvgFillColor(nvg, nvgRGBA(255, 200, 60, math.floor(sparkAlpha * 0.2)))
                    nvgFill(nvg)

                    -- 边框辉光
                    nvgBeginPath(nvg)
                    nvgRect(nvg, tx, ty, tileSize, tileSize)
                    nvgStrokeColor(nvg, nvgRGBA(255, 215, 60, math.floor(150 * pulse)))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                end
            end
        elseif chapter == 4 then
            -- ═══ 第四章·海蓝色封印光效（逐瓦片渲染，醒目水纹效果） ═══
            local pulse = 0.55 + 0.3 * math.sin(t * 2.5)

            for ti, tile in ipairs(tiles) do
                local tx, ty = RenderUtils.WorldToLocal(tile.x - 0.5, tile.y - 0.5, camera, l)

                -- 视锥剔除单瓦片
                if tx + tileSize >= l.x and tx <= l.x + l.w and
                   ty + tileSize >= l.y and ty <= l.y + l.h then

                    -- 底层：深蓝色光幕
                    local baseAlpha = math.floor(210 * pulse)
                    nvgBeginPath(nvg)
                    nvgRect(nvg, tx, ty, tileSize, tileSize)
                    nvgFillColor(nvg, nvgRGBA(30, 100, 200, baseAlpha))
                    nvgFill(nvg)

                    -- 中层：水波纹效果（双横纹上下浮动）
                    for wi = 0, 1 do
                        local waveOffset = math.sin(t * 2.0 + ti * 1.3 + wi * 3.14) * tileSize * 0.12
                        local waveY = ty + tileSize * (0.35 + wi * 0.3) + waveOffset
                        local waveH = tileSize * 0.12
                        local waveAlpha = math.floor(140 * pulse * (0.5 + 0.5 * math.sin(t * 3.0 + ti * 0.9 + wi * 2.0)))
                        nvgBeginPath(nvg)
                        nvgRect(nvg, tx, waveY - waveH * 0.5, tileSize, waveH)
                        nvgFillColor(nvg, nvgRGBA(80, 180, 255, waveAlpha))
                        nvgFill(nvg)
                    end

                    -- 上层：闪烁水滴光点
                    local phase = t * 2.2 + ti * 2.71
                    local dropAlpha = math.floor(220 * (0.2 + 0.8 * math.abs(math.sin(phase))))
                    local dropX = tx + tileSize * (0.3 + 0.4 * ((math.sin(phase * 0.6) + 1) * 0.5))
                    local dropY = ty + tileSize * (0.3 + 0.4 * ((math.cos(phase * 0.4) + 1) * 0.5))
                    local dropR = tileSize * (0.04 + 0.03 * math.sin(phase * 1.8))
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, dropX, dropY, dropR)
                    nvgFillColor(nvg, nvgRGBA(150, 230, 255, dropAlpha))
                    nvgFill(nvg)
                    -- 外围辉光
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, dropX, dropY, dropR * 3.5)
                    nvgFillColor(nvg, nvgRGBA(60, 160, 240, math.floor(dropAlpha * 0.2)))
                    nvgFill(nvg)

                    -- 边框辉光
                    nvgBeginPath(nvg)
                    nvgRect(nvg, tx, ty, tileSize, tileSize)
                    nvgStrokeColor(nvg, nvgRGBA(60, 180, 255, math.floor(160 * pulse)))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                end
            end
        else
            -- ═══ 第一章·紫蓝色封印光效（保持原有风格） ═══
            local pulse = 0.7 + 0.15 * math.sin(t * 1.8)
            local baseAlpha = math.floor(200 * pulse)

            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, barrierW, barrierH)
            local curtain = nvgLinearGradient(nvg,
                sx, sy + barrierH, sx, sy,
                nvgRGBA(140, 100, 255, baseAlpha),
                nvgRGBA(120, 180, 255, math.floor(baseAlpha * 0.15))
            )
            nvgFillPaint(nvg, curtain)
            nvgFill(nvg)
        end

        ::continue::
    end
end

-- ============================================================================
-- GM：鼠标悬停瓦片坐标显示
-- ============================================================================
function WorldRenderer:RenderHoverCoord(nvg, l)
    local camera = self.camera
    local gameMap = self.gameMap
    if not camera or not gameMap then return end

    local mx = input:GetMousePosition().x
    local my = input:GetMousePosition().y

    -- 屏幕坐标→世界瓦片坐标
    local wx, wy = camera:ScreenToWorld(mx, my, l.w, l.h)
    local tileX = math.floor(wx + 0.5)
    local tileY = math.floor(wy + 0.5)

    -- 超出地图边界不显示
    if tileX < 1 or tileX > gameMap.width or tileY < 1 or tileY > gameMap.height then
        return
    end

    local tileSize = camera:GetTileSize()
    -- 瓦片左上角屏幕坐标
    local sx, sy = RenderUtils.WorldToLocal(tileX - 0.5, tileY - 0.5, camera, l)

    -- 高亮框
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, tileSize, tileSize)
    nvgFillColor(nvg, nvgRGBA(255, 255, 0, 35))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 0, 200))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 坐标文字
    local label = "(" .. tileX .. "," .. tileY .. ")"
    nvgFontSize(nvg, 14)
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 背景底衬
    local tw = nvgTextBounds(nvg, 0, 0, label)
    local pad = 4
    local labelX = sx + tileSize * 0.5
    local labelY = sy + tileSize * 0.5
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, labelX - tw * 0.5 - pad, labelY - 9, tw + pad * 2, 18, 3)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg)

    -- 文字
    nvgFillColor(nvg, nvgRGBA(255, 255, 0, 255))
    nvgText(nvg, labelX, labelY, label)
end

function WorldRenderer:IsStateful()
    return true
end

return WorldRenderer
