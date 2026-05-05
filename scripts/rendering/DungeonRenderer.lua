-- ============================================================================
-- DungeonRenderer.lua - 副本远程玩家 + BOSS 渲染
--
-- 职责：
--   1. 维护远程玩家状态表（从 S2C_DungeonSnapshot 更新）
--   2. 在 WorldRenderer 中绘制远程玩家精灵、名牌
--   3. 副本 BOSS 渲染（S5 阶段实现）
--
-- 设计文档：docs/架构文档/multiplayer-dungeon-tech-plan.md §8 C1
-- ============================================================================

local GameConfig = require("config.GameConfig")
local DungeonConfig = require("config.DungeonConfig")
local GameState = require("core.GameState")
local RenderUtils = require("rendering.RenderUtils")

local M = {}

--- (BOSS 头像缓存已移除，BOSS 由 EntityRenderer 统一渲染)

--- 副本竞技场中心（含 PADDING=5 偏移：原 8.5→13.5，原 11.5→16.5）
local DUNGEON_CENTER_X = 13.5
local DUNGEON_CENTER_Y = 16.5
local DUNGEON_RADIUS   = 16  -- 副本可视区域半径（含填充墙，确保边框可见）

-- ============================================================================
-- 状态数据
-- ============================================================================

--- 远程玩家列表 connKey → { x, y, dir, anim, name, realm, classId }
---@type table<string, table>
local remotePlayers_ = {}

--- BOSS 渲染数据（从快照更新）
---@type table|nil
local bossRenderData_ = nil

--- 本机 connKey（进入副本时由 S2C_EnterDungeonResult 设置）
---@type string|nil
local localConnKey_ = nil

--- 是否处于副本模式
local isDungeonMode_ = false

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 设置本机 connKey
---@param connKey string
function M.SetLocalConnKey(connKey)
    localConnKey_ = connKey
    print("[DungeonRenderer] localConnKey set to: " .. tostring(connKey))
end

--- 进入副本模式
function M.EnterDungeon()
    isDungeonMode_ = true
    remotePlayers_ = {}
    bossRenderData_ = nil
    print("[DungeonRenderer] Entered dungeon mode")
end

--- 离开副本模式
function M.LeaveDungeon()
    isDungeonMode_ = false
    remotePlayers_ = {}
    bossRenderData_ = nil
    localConnKey_ = nil
    print("[DungeonRenderer] Left dungeon mode")
end

--- 重置所有状态（ReturnToLogin 时调用，防止跨会话残留）
function M.Reset()
    isDungeonMode_ = false
    remotePlayers_ = {}
    bossRenderData_ = nil
    localConnKey_ = nil
end

--- 是否处于副本模式
---@return boolean
function M.IsDungeonMode()
    return isDungeonMode_
end

--- 获取远程玩家表（供 HUD 等读取）
---@return table<string, table>
function M.GetRemotePlayers()
    return remotePlayers_
end

--- 获取 BOSS 渲染数据
---@return table|nil
function M.GetBossRenderData()
    return bossRenderData_
end

-- ============================================================================
-- 从 S2C_DungeonState 初始化状态（进入时的完整数据）
-- ============================================================================

---@param stateData table  解码后的 DungeonState 数据
function M.InitFromFullState(stateData)
    remotePlayers_ = {}

    -- 解析 players 列表
    local players = stateData.players
    if type(players) == "string" then
        local cjson = cjson  ---@diagnostic disable-line: undefined-global
        local ok, decoded = pcall(cjson.decode, players)
        if ok then players = decoded end
    end

    if type(players) == "table" then
        for _, p in ipairs(players) do
            if p.connKey and p.connKey ~= localConnKey_ then
                remotePlayers_[p.connKey] = {
                    x       = p.x or 0,
                    y       = p.y or 0,
                    dir     = p.dir or 1,
                    anim    = p.anim or "idle",
                    name    = p.name or "",
                    realm   = p.realm or "凡人",
                    classId = p.classId or "monk",
                }
            end
        end
    end

    -- BOSS 初始状态
    if stateData.bossAlive then
        bossRenderData_ = {
            x     = stateData.bossX or 0,
            y     = stateData.bossY or 0,
            hp    = stateData.bossHp or 0,
            maxHp = stateData.bossMaxHp or 0,
            anim  = stateData.bossAnim or "idle",
            alive = true,
        }
    else
        bossRenderData_ = {
            alive = false,
            hp = 0,
            maxHp = stateData.bossMaxHp or 0,
        }
    end

    print("[DungeonRenderer] InitFromFullState: " .. M.GetRemotePlayerCount() .. " remote players")
end

-- ============================================================================
-- 从 S2C_DungeonSnapshot 更新（10fps 快照）
-- ============================================================================

---@param snapshotData table  解码后的快照数据
function M.UpdateFromSnapshot(snapshotData)
    if not isDungeonMode_ then return end

    -- 解析 players（可能是 JSON 字符串）
    local players = snapshotData.players
    if type(players) == "string" then
        local cjson = cjson  ---@diagnostic disable-line: undefined-global
        local ok, decoded = pcall(cjson.decode, players)
        if ok then players = decoded end
    end

    if type(players) == "table" then
        -- 更新/新增远程玩家
        for connKey, data in pairs(players) do
            if connKey ~= localConnKey_ then
                remotePlayers_[connKey] = {
                    x       = data.x or 0,
                    y       = data.y or 0,
                    dir     = data.dir or 1,
                    anim    = data.anim or "idle",
                    name    = data.name or (remotePlayers_[connKey] and remotePlayers_[connKey].name or ""),
                    realm   = data.realm or (remotePlayers_[connKey] and remotePlayers_[connKey].realm or "凡人"),
                    classId = remotePlayers_[connKey] and remotePlayers_[connKey].classId or "monk",
                }
            end
        end
        -- 清理已离开的玩家（快照中不包含的 connKey）
        for connKey, _ in pairs(remotePlayers_) do
            if not players[connKey] then
                remotePlayers_[connKey] = nil
            end
        end
    end

    -- 更新 BOSS 数据
    local boss = snapshotData.boss
    if type(boss) == "string" then
        local cjson = cjson  ---@diagnostic disable-line: undefined-global
        local ok, decoded = pcall(cjson.decode, boss)
        if ok then boss = decoded end
    end

    if boss then
        bossRenderData_ = {
            x     = boss.x or 0,
            y     = boss.y or 0,
            hp    = boss.hp or 0,
            maxHp = boss.maxHp or 0,
            anim  = boss.anim or "idle",
            target = boss.target,
            alive = true,
        }
    elseif bossRenderData_ then
        bossRenderData_.alive = false
    end
end

-- ============================================================================
-- 玩家加入/离开处理
-- ============================================================================

--- 处理 S2C_PlayerJoined
---@param data table { connKey, name, realm, classId }
function M.OnPlayerJoined(data)
    if not isDungeonMode_ then return end
    if data.connKey == localConnKey_ then return end

    remotePlayers_[data.connKey] = {
        x       = 0,
        y       = 0,
        dir     = 1,
        anim    = "idle",
        name    = data.name or "",
        realm   = data.realm or "凡人",
        classId = data.classId or "monk",
    }
    print("[DungeonRenderer] PlayerJoined: " .. tostring(data.name) .. " (" .. tostring(data.connKey) .. ")")
end

--- 处理 S2C_PlayerLeft
---@param data table { connKey }
function M.OnPlayerLeft(data)
    if not isDungeonMode_ then return end
    local p = remotePlayers_[data.connKey]
    if p then
        print("[DungeonRenderer] PlayerLeft: " .. tostring(p.name) .. " (" .. tostring(data.connKey) .. ")")
        remotePlayers_[data.connKey] = nil
    end
end

--- 处理 S2C_BossRespawned（BOSS 重生）
---@param hp number
---@param maxHp number
---@param x number
---@param y number
function M.OnBossRespawned(hp, maxHp, x, y)
    bossRenderData_ = {
        x     = x or 0,
        y     = y or 0,
        hp    = hp,
        maxHp = maxHp,
        anim  = "idle",
        alive = true,
    }
    print("[DungeonRenderer] BOSS respawned at (" .. x .. ", " .. y .. ") hp=" .. hp)
end

--- 远程玩家计数
---@return integer
function M.GetRemotePlayerCount()
    local count = 0
    for _ in pairs(remotePlayers_) do count = count + 1 end
    return count
end

-- ============================================================================
-- 渲染：远程玩家
-- ============================================================================

--- 绘制所有远程玩家（在 WorldRenderer:Render 中调用）
---@param nvg userdata  NanoVG context
---@param l table       { x, y, w, h } absolute layout
---@param camera table  camera object with .x, .y
function M.RenderRemotePlayers(nvg, l, camera)
    if not isDungeonMode_ then return end

    local ts = camera:GetTileSize()

    for _, p in pairs(remotePlayers_) do
        local sx, sy = RenderUtils.WorldToLocal(p.x, p.y, camera, l)

        -- 视锥剔除
        local spriteSize = ts * 1.5
        local halfSize = spriteSize / 2
        if sx + halfSize < l.x or sx - halfSize > l.x + l.w or
           sy + halfSize < l.y or sy - halfSize > l.y + l.h then
            goto continue
        end

        -- 精灵绘制（复用 EntityRenderer.RenderPlayer 的逻辑）
        local DUNGEON_CLASS_SPRITES = {
            taixu   = "Textures/class_swordsman_right.png",
            zhenyue = "Textures/class_body_cultivator_right.png",
        }
        local spritePath = DUNGEON_CLASS_SPRITES[p.classId] or "Textures/player_right.png"
        local imgHandle = RenderUtils.GetCachedImage(nvg, spritePath)

        if imgHandle then
            nvgSave(nvg)
            -- dir: 1 = 右, -1 = 左
            local facingRight = (p.dir or 1) >= 0
            if not facingRight then
                nvgTranslate(nvg, sx, 0)
                nvgScale(nvg, -1, 1)
                nvgTranslate(nvg, -sx, 0)
            end

            local imgX = sx - halfSize
            local imgY = sy - halfSize * 1.1

            -- 半透明绘制（远程玩家微透明以区分本地玩家）
            local imgPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgHandle, 0.85)
            nvgBeginPath(nvg)
            nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
            nvgRestore(nvg)
        else
            -- 回退：半透明色块
            local bodyW = ts * 0.5
            local bodyH = ts * 0.6
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx - bodyW / 2, sy - bodyH * 0.3, bodyW, bodyH, 3)
            nvgFillColor(nvg, nvgRGBA(100, 180, 255, 180))
            nvgFill(nvg)
        end

        -- ── 名牌：名字 + 境界 ──
        local spriteTopY = sy - (ts * 1.5) / 2 * 1.1
        local nameY = spriteTopY - 6

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)

        -- 名字背景阴影
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
        nvgText(nvg, sx + 1, nameY + 1, p.name)

        -- 名字
        nvgFillColor(nvg, nvgRGBA(200, 230, 255, 255))
        nvgText(nvg, sx, nameY, p.name)

        -- 境界标签（名字上方）
        local realmY = nameY - 14
        nvgFontSize(nvg, 9)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)

        -- 境界药丸背景
        local realmText = p.realm or "凡人"
        local rtW = nvgTextBounds(nvg, 0, 0, realmText)
        local pillW = rtW + 8
        local pillH = 13
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, sx - pillW / 2, realmY - pillH + 2, pillW, pillH, pillH / 2)
        nvgFillColor(nvg, nvgRGBA(60, 40, 120, 200))
        nvgFill(nvg)

        nvgFillColor(nvg, nvgRGBA(220, 200, 255, 255))
        nvgText(nvg, sx, realmY, realmText)

        ::continue::
    end
end

-- ============================================================================
-- 渲染：BOSS（S5 阶段完善）
-- ============================================================================

-- BOSS 动画/攻击/技能特效已由客户端本地Monster实体+GameEvents处理
-- DungeonRenderer 只负责远程玩家渲染和副本地板

--- 绘制副本地板背景（在瓦片层之上调用）
---@param nvg userdata
---@param l table
---@param camera table
function M.RenderDungeonFloor(nvg, l, camera)
    if not isDungeonMode_ then return end

    local ts = camera:GetTileSize()

    -- 副本区域范围
    local x1 = DUNGEON_CENTER_X - DUNGEON_RADIUS
    local y1 = DUNGEON_CENTER_Y - DUNGEON_RADIUS
    local x2 = DUNGEON_CENTER_X + DUNGEON_RADIUS
    local y2 = DUNGEON_CENTER_Y + DUNGEON_RADIUS

    -- 转换到屏幕坐标
    local sx1, sy1 = RenderUtils.WorldToLocal(x1, y1, camera, l)
    local sx2, sy2 = RenderUtils.WorldToLocal(x2, y2, camera, l)
    local floorW = sx2 - sx1
    local floorH = sy2 - sy1

    -- 深色副本地板
    nvgBeginPath(nvg)
    nvgRect(nvg, sx1, sy1, floorW, floorH)
    nvgFillColor(nvg, nvgRGBA(35, 30, 25, 255))
    nvgFill(nvg)

    -- 网格线（淡色，营造副本氛围）
    nvgStrokeColor(nvg, nvgRGBA(60, 55, 45, 80))
    nvgStrokeWidth(nvg, 1)
    for gx = x1, x2 do
        local lx, _ = RenderUtils.WorldToLocal(gx, y1, camera, l)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx, sy1)
        nvgLineTo(nvg, lx, sy2)
        nvgStroke(nvg)
    end
    for gy = y1, y2 do
        local _, ly = RenderUtils.WorldToLocal(x1, gy, camera, l)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx1, ly)
        nvgLineTo(nvg, sx2, ly)
        nvgStroke(nvg)
    end

    -- 外层发光晕染（营造副本结界感）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx1 - 6, sy1 - 6, floorW + 12, floorH + 12)
    nvgStrokeColor(nvg, nvgRGBA(100, 80, 40, 60))
    nvgStrokeWidth(nvg, 8)
    nvgStroke(nvg)

    -- 加厚边界主边框
    nvgBeginPath(nvg)
    nvgRect(nvg, sx1, sy1, floorW, floorH)
    nvgStrokeColor(nvg, nvgRGBA(140, 115, 65, 200))
    nvgStrokeWidth(nvg, 4)
    nvgStroke(nvg)

    -- 内侧高光线（增强立体感）
    nvgBeginPath(nvg)
    nvgRect(nvg, sx1 + 2, sy1 + 2, floorW - 4, floorH - 4)
    nvgStrokeColor(nvg, nvgRGBA(180, 150, 80, 80))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 副本标题
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(120, 110, 80, 120))
    local cx = (sx1 + sx2) / 2
    nvgText(nvg, cx, sy1 + 6, DungeonConfig.GetDefault().strings.arenaLabel)
end

--- 绘制 BOSS（使用枯木妖王头像）
---@param nvg userdata
---@param l table
---@param camera table
--- BOSS 世界空间渲染已由 EntityRenderer.RenderMonsters 统一处理（v1.7 重构）
--- 保留空函数以兼容可能的外部调用
function M.RenderBoss(nvg, l, camera)
    -- no-op: BOSS 现在是 GameState.monsters 中的本地 Monster 实体
end

return M
