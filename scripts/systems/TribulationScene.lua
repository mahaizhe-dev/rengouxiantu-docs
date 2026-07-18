-- ============================================================================
-- TribulationScene.lua - 雷火劫渡劫场景
-- ============================================================================
-- 职责：渡劫台的实际玩法——60 秒生存，躲避追身九雷 + 火场安全区
-- 复用 PrisonTowerSystem 的"覆盖层副本"模式
-- ============================================================================
--
-- 机制说明：
-- ┌────────────────────────────────────────────────────────────────────┐
-- │  [追身九雷]  每 2.5 秒一波，每波 3-5 道雷，追踪玩家位置            │
-- │              预警 0.8 秒，半径 0.8 tile，伤害 = 玩家 maxHp × 20%   │
-- │                                                                    │
-- │  [大范围火场] 每 8 秒一波，全场燃烧，仅 2-3 个安全区               │
-- │              预警 2.0 秒，伤害 = 玩家 maxHp × 40%                  │
-- │                                                                    │
-- │  [通过条件]  存活 60 秒                                            │
-- │  [失败条件]  玩家死亡                                              │
-- └────────────────────────────────────────────────────────────────────┘

local GameConfig      = require("config.GameConfig")
local GameState       = require("core.GameState")
local EventBus        = require("core.EventBus")
local AscensionConfig = require("config.AscensionConfig")
local TileTypes       = require("config.TileTypes")

local TribulationScene = {}

-- ============================================================================
-- 运行时状态
-- ============================================================================

local scene = {
    active         = false,
    elapsed        = 0,          -- 已过时间
    warmup         = 0,          -- 入场准备倒计时
    phase          = "none",     -- none / warmup / combat / ending

    -- 计时器
    lightningTimer = 0,
    fireTimer      = 0,

    -- 场景参数
    arenaSize      = 10,
    padding        = 3,
    totalSize      = 0,
    centerX        = 0,
    centerY        = 0,

    -- 备份
    _backup        = nil,
    _camera        = nil,
    _gameMap        = nil,

    -- 安全区 (火场机制)
    safeZones      = {},         -- { {x, y, radius}, ... }
    safeZoneActive = false,
    fireWarningElapsed = 0,
    fireWarningDuration = 2.0,

    -- 雷击预警列表（自管理）
    lightningWarnings = {},      -- { {x, y, elapsed, duration, triggered}, ... }

    -- 配置缓存
    duration       = 60,
    warmupDuration = 3,
}

-- ── 配置常量 ─────────────────────────────────────────────────────────────────
local LIGHTNING_INTERVAL   = 0.5    -- 每 0.5 秒释放一个雷（追踪玩家）
local LIGHTNING_WARNING    = 0.8    -- 雷击预警时间
local LIGHTNING_RADIUS     = 0.8    -- 雷击范围
local LIGHTNING_DMG_PCT    = 0.20   -- 雷击伤害 = maxHp × 20%

local FIRE_INTERVAL        = 8.0    -- 火场间隔
local FIRE_WARNING         = 2.0    -- 火场预警时间
local FIRE_SAFE_COUNT_MIN  = 2      -- 安全区最少数
local FIRE_SAFE_COUNT_MAX  = 3      -- 安全区最多数
local FIRE_SAFE_RADIUS     = 1.2    -- 安全区半径
local FIRE_DMG_PCT         = 0.40   -- 火场伤害 = maxHp × 40%

-- ============================================================================
-- 查询接口
-- ============================================================================

function TribulationScene.IsActive()
    return scene.active
end

function TribulationScene.GetPhase()
    return scene.phase
end

function TribulationScene.GetElapsed()
    return scene.elapsed
end

function TribulationScene.GetDuration()
    return scene.duration
end

function TribulationScene.GetTimeRemaining()
    if not scene.active then return 0 end
    return math.max(0, scene.duration - scene.elapsed)
end

function TribulationScene.GetWarmupRemaining()
    return math.max(0, scene.warmupDuration - scene.warmup)
end

function TribulationScene.GetSafeZones()
    return scene.safeZones
end

function TribulationScene.IsSafeZoneActive()
    return scene.safeZoneActive
end

function TribulationScene.GetLightningWarnings()
    return scene.lightningWarnings
end

-- ============================================================================
-- 进入渡劫台
-- ============================================================================

--- 进入雷火劫场景
---@param gameMap table
---@param camera table|nil
---@return boolean success
---@return string|nil msg
function TribulationScene.Enter(gameMap, camera)
    if scene.active then return false, "已在渡劫中" end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    -- 互斥检测
    local okPT, PrisonTowerSystem = pcall(require, "systems.PrisonTowerSystem")
    if okPT and PrisonTowerSystem and PrisonTowerSystem.IsActive() then
        return false, "镇狱塔中无法渡劫"
    end
    local okTT, TrialTowerSystem = pcall(require, "systems.TrialTowerSystem")
    if okTT and TrialTowerSystem and TrialTowerSystem.IsActive() then
        return false, "试炼塔中无法渡劫"
    end
    local okSW, SwordWallSystem = pcall(require, "systems.SwordWallSystem")
    if okSW and SwordWallSystem and SwordWallSystem.IsActive() then
        return false, "剑气长城中无法渡劫"
    end

    -- 场景参数
    local T = TileTypes.TILE
    local innerSize = scene.arenaSize
    local padding = scene.padding
    local totalSize = innerSize + 2 + padding * 2

    scene.totalSize = totalSize
    scene.centerX = totalSize / 2 + 0.5
    scene.centerY = totalSize / 2 + 0.5
    scene.duration = AscensionConfig.TRIBULATION_DURATION_SEC
    scene.warmupDuration = AscensionConfig.TRIBULATION_WARMUP_SEC

    -- 1. 备份世界状态
    scene._backup = {
        tiles = gameMap.tiles,
        width = gameMap.width,
        height = gameMap.height,
        playerX = player.x,
        playerY = player.y,
        playerHp = player.hp,
        monsters = GameState.monsters,
        npcs = GameState.npcs,
        lootDrops = GameState.lootDrops,
        cameraX = camera and camera.x or nil,
        cameraY = camera and camera.y or nil,
        cameraMapW = camera and camera.mapWidth or nil,
        cameraMapH = camera and camera.mapHeight or nil,
    }

    -- 2. 创建渡劫场
    local wallMin = padding + 1
    local wallMax = padding + innerSize + 2
    local floorMin = wallMin + 1
    local floorMax = wallMax - 1
    gameMap.width = totalSize
    gameMap.height = totalSize
    gameMap.tiles = {}
    for y = 1, totalSize do
        gameMap.tiles[y] = {}
        for x = 1, totalSize do
            if x >= floorMin and x <= floorMax and y >= floorMin and y <= floorMax then
                gameMap.tiles[y][x] = T.CORRUPTED_GROUND   -- 劫台地面
            else
                gameMap.tiles[y][x] = T.CELESTIAL_WALL      -- 封印墙壁
            end
        end
    end

    -- 3. 清除当前世界实体
    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}

    -- 4. 传送玩家到中心
    player.x = scene.centerX
    player.y = scene.centerY
    player:SetMoveDirection(0, 0)
    player.hp = player:GetTotalMaxHp()

    -- 5. 相机
    scene._camera = camera
    scene._gameMap = gameMap
    if camera then
        camera.x = scene.centerX
        camera.y = scene.centerY
        camera.mapWidth = totalSize
        camera.mapHeight = totalSize
    end

    -- 6. 重置计时器
    scene.active = true
    scene.phase = "warmup"
    scene.elapsed = 0
    scene.warmup = 0
    scene.lightningTimer = 0
    scene.fireTimer = 0
    scene.safeZones = {}
    scene.safeZoneActive = false
    scene.fireWarningElapsed = 0
    scene.lightningWarnings = {}

    -- 7. 提示
    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.5,
        "— 雷火劫 · 渡劫开始 —",
        {255, 200, 80, 255}, 3.0
    )

    EventBus.Emit("tribulation_scene_enter")
    print("[TribulationScene] Entered. Duration=" .. scene.duration .. "s, warmup=" .. scene.warmupDuration .. "s")

    return true, nil
end

-- ============================================================================
-- 退出渡劫台
-- ============================================================================

--- 退出并回滚世界
---@param reason string|nil "success"/"fail"/"quit"
function TribulationScene.Exit(reason)
    if not scene.active then return end

    reason = reason or "quit"

    local player = GameState.player
    local gameMap = scene._gameMap
    local camera = scene._camera

    -- 清除战斗特效
    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.ClearEffects()

    -- 回滚世界
    TribulationScene._rollback(gameMap, camera)

    -- 恢复玩家
    if player then
        player.hp = player:GetTotalMaxHp()
        player:SetMoveDirection(0, 0)
    end

    -- 结算
    local TribulationSystem = require("systems.TribulationSystem")
    if reason == "success" then
        TribulationSystem.OnSuccess()
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.5,
                "渡劫成功！仙阶突破！",
                {255, 215, 0, 255}, 3.0
            )
        end
        -- 大境界突破弹窗（使用注册到 GameConfig.REALMS 的仙阶 realm ID）
        local okBC, BreakthroughCelebration = pcall(require, "ui.BreakthroughCelebration")
        if okBC and BreakthroughCelebration then
            local AscensionSystem = require("systems.AscensionSystem")
            local ascState = AscensionSystem.GetState()
            local newRealmId = "asc_" .. ascState.totalIndex
            local oldRealmId = ascState.totalIndex <= 1 and "dacheng_4" or ("asc_" .. (ascState.totalIndex - 1))
            BreakthroughCelebration.Show(oldRealmId, newRealmId)
        end
    elseif reason == "fail" then
        TribulationSystem.OnFail("fail")
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.5,
                "渡劫失败，10分钟后再试",
                {200, 60, 60, 255}, 3.0
            )
        end
    else
        TribulationSystem.OnFail("quit")
    end

    -- 重置状态
    scene.active = false
    scene.phase = "none"
    scene._backup = nil
    scene._camera = nil
    scene._gameMap = nil
    scene.lightningWarnings = {}
    scene.safeZones = {}
    scene.safeZoneActive = false

    EventBus.Emit("tribulation_scene_exit", reason)
    print("[TribulationScene] Exited, reason=" .. reason)
end

--- 回滚世界状态
function TribulationScene._rollback(gameMap, camera)
    local backup = scene._backup
    if not backup then return end
    if not gameMap then return end

    gameMap.tiles = backup.tiles
    gameMap.width = backup.width
    gameMap.height = backup.height

    GameState.monsters = backup.monsters or {}
    GameState.npcs = backup.npcs or {}
    GameState.lootDrops = backup.lootDrops or {}

    local player = GameState.player
    if player then
        player.x = backup.playerX
        player.y = backup.playerY
    end

    if camera then
        camera.x = backup.cameraX or player.x
        camera.y = backup.cameraY or player.y
        camera.mapWidth = backup.cameraMapW or backup.width
        camera.mapHeight = backup.cameraMapH or backup.height
    end
end

-- ============================================================================
-- 帧更新
-- ============================================================================

--- 每帧调用
---@param dt number
function TribulationScene.Update(dt)
    if not scene.active then return end

    local player = GameState.player
    if not player then return end

    -- 玩家死亡检测
    if not player.alive or player.hp <= 0 then
        TribulationScene.Exit("fail")
        return
    end

    -- ── warmup 阶段 ──
    if scene.phase == "warmup" then
        scene.warmup = scene.warmup + dt
        if scene.warmup >= scene.warmupDuration then
            scene.phase = "combat"
            scene.elapsed = 0
            scene.lightningTimer = 0
            scene.fireTimer = 3.0  -- 首次火场 5 秒后触发（8 - 3 = 5s delay）

            local CombatSystem = require("systems.CombatSystem")
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.5,
                "天劫降临！坚持60秒！",
                {255, 100, 50, 255}, 2.0
            )
            print("[TribulationScene] Combat phase started")
        end
        return
    end

    -- ── ending 阶段（短暂延迟退出）──
    if scene.phase == "ending" then
        scene.elapsed = scene.elapsed + dt
        if scene.elapsed >= 1.5 then
            TribulationScene.Exit("success")
        end
        return
    end

    -- ── combat 阶段 ──
    scene.elapsed = scene.elapsed + dt

    -- 时间到 → 成功
    if scene.elapsed >= scene.duration then
        scene.phase = "ending"
        scene.elapsed = 0  -- 复用做 ending 计时

        local CombatSystem = require("systems.CombatSystem")
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.0,
            "天劫已过！",
            {100, 255, 100, 255}, 2.5
        )
        print("[TribulationScene] Player survived! Entering ending phase.")
        return
    end

    -- ─── 追身九雷 ───
    scene.lightningTimer = scene.lightningTimer + dt
    if scene.lightningTimer >= LIGHTNING_INTERVAL then
        scene.lightningTimer = 0
        TribulationScene._spawnLightning(player)
    end

    -- ─── 火场安全区 ───
    scene.fireTimer = scene.fireTimer + dt
    if scene.fireTimer >= FIRE_INTERVAL then
        scene.fireTimer = 0
        TribulationScene._startFireWave(player)
    end

    -- 更新火场预警
    if scene.safeZoneActive then
        scene.fireWarningElapsed = scene.fireWarningElapsed + dt
        if scene.fireWarningElapsed >= scene.fireWarningDuration then
            TribulationScene._resolveFireWave(player)
        end
    end

    -- 更新雷击预警
    TribulationScene._updateLightningWarnings(dt, player)
end

-- ============================================================================
-- 追身九雷
-- ============================================================================

--- 生成单个追踪雷击（每 0.5 秒调用一次）
function TribulationScene._spawnLightning(player)
    local padding = scene.padding
    local innerSize = scene.arenaSize

    -- 追身：以玩家位置为中心，加小幅随机偏移
    local offsetX = (math.random() - 0.5) * 1.5
    local offsetY = (math.random() - 0.5) * 1.5
    local targetX = player.x + offsetX
    local targetY = player.y + offsetY

    -- 限制在竞技场内
    local floorMin = padding + 2
    local floorMax = padding + innerSize + 1
    targetX = math.max(floorMin, math.min(floorMax, targetX))
    targetY = math.max(floorMin, math.min(floorMax, targetY))

    scene.lightningWarnings[#scene.lightningWarnings + 1] = {
        x = targetX,
        y = targetY,
        elapsed = 0,
        duration = LIGHTNING_WARNING,
        triggered = false,
    }
end

--- 更新雷击预警（到时触发伤害）
function TribulationScene._updateLightningWarnings(dt, player)
    local CombatSystem = require("systems.CombatSystem")
    local j = 1
    local n = #scene.lightningWarnings

    for i = 1, n do
        local w = scene.lightningWarnings[i]
        if not w then goto continue_warn end
        w.elapsed = w.elapsed + dt

        if w.elapsed >= w.duration and not w.triggered then
            -- 触发伤害
            w.triggered = true
            local dx = player.x - w.x
            local dy = player.y - w.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= LIGHTNING_RADIUS then
                local damage = math.floor(player:GetTotalMaxHp() * LIGHTNING_DMG_PCT)
                local source = { type = "tribulation_lightning", name = "天雷" }
                player:TakeDamage(damage, source, {
                    sourceType = "environment",
                    sourceId = source.type,
                    sourceName = source.name,
                    damageTag = "skill",
                    impact = "heavy",
                    color = {180, 220, 255, 255},
                    legacySuffix = " ⚡",
                    legacyColor = {180, 220, 255, 255},
                    legacyY = player.y - 0.5,
                    legacyLifetime = 1.0,
                })
            end
        end

        -- 保留未超时的（触发后保留 0.3 秒做消散动画）
        if w.elapsed < w.duration + 0.3 then
            scene.lightningWarnings[j] = w
            j = j + 1
        end
        ::continue_warn::
    end
    for i = j, n do
        scene.lightningWarnings[i] = nil
    end
end

-- ============================================================================
-- 大范围火场 + 安全区
-- ============================================================================

--- 开始一波火场（显示安全区预警）
function TribulationScene._startFireWave(player)
    -- 生成随机安全区
    local safeCount = math.random(FIRE_SAFE_COUNT_MIN, FIRE_SAFE_COUNT_MAX)
    scene.safeZones = {}

    local padding = scene.padding
    local innerSize = scene.arenaSize
    local floorMin = padding + 2
    local floorMax = padding + innerSize + 1

    for i = 1, safeCount do
        local zx = floorMin + math.random() * (floorMax - floorMin)
        local zy = floorMin + math.random() * (floorMax - floorMin)
        table.insert(scene.safeZones, {
            x = zx,
            y = zy,
            radius = FIRE_SAFE_RADIUS,
        })
    end

    scene.safeZoneActive = true
    scene.fireWarningElapsed = 0
    scene.fireWarningDuration = FIRE_WARNING

    -- 提示
    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.2,
        "火场将至！进入安全区！",
        {255, 150, 50, 255}, 1.5
    )

    print("[TribulationScene] Fire wave started, safeZones=" .. safeCount)
end

--- 火场预警结束，结算伤害
function TribulationScene._resolveFireWave(player)
    scene.safeZoneActive = false

    -- 判断玩家是否在安全区内
    local inSafe = false
    for _, zone in ipairs(scene.safeZones) do
        local dx = player.x - zone.x
        local dy = player.y - zone.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= zone.radius then
            inSafe = true
            break
        end
    end

    local CombatSystem = require("systems.CombatSystem")

    if not inSafe then
        -- 不在安全区，受到火场伤害
        local damage = math.floor(player:GetTotalMaxHp() * FIRE_DMG_PCT)
        local source = { type = "tribulation_fire", name = "劫火" }
        player:TakeDamage(damage, source, {
            sourceType = "environment",
            sourceId = source.type,
            sourceName = source.name,
            damageTag = "dot",
            impact = "dot",
            color = {255, 100, 30, 255},
            legacySuffix = " 🔥",
            legacyColor = {255, 100, 30, 255},
            legacyY = player.y - 0.5,
            legacyLifetime = 1.2,
        })
    else
        CombatSystem.AddFloatingText(
            player.x, player.y - 0.5,
            "安全！",
            {100, 255, 150, 255}, 0.8
        )
    end

    -- 清除安全区显示
    scene.safeZones = {}
    print("[TribulationScene] Fire resolved, inSafe=" .. tostring(inSafe))
end

-- ============================================================================
-- 外部请求退出（按钮/传送）
-- ============================================================================

--- 玩家主动退出渡劫
function TribulationScene.RequestQuit()
    if not scene.active then return end
    TribulationScene.Exit("quit")
end

-- ============================================================================
-- 渲染数据接口（供 WorldRenderer 绘制预警圈）
-- ============================================================================

--- 获取当前所有预警圈数据（供渲染层使用）
---@return table[] warnings { {x, y, radius, color, progress}, ... }
function TribulationScene.GetWarningCircles()
    local circles = {}

    -- 雷击预警
    for _, w in ipairs(scene.lightningWarnings) do
        if not w.triggered then
            local progress = w.elapsed / w.duration
            table.insert(circles, {
                x = w.x,
                y = w.y,
                radius = LIGHTNING_RADIUS,
                color = {100, 150, 255, math.floor(180 * (1 - progress))},
                progress = progress,
                type = "lightning",
            })
        end
    end

    -- 火场安全区（反色显示：安全区外全是危险区）
    if scene.safeZoneActive then
        local progress = scene.fireWarningElapsed / scene.fireWarningDuration
        -- 标记整场火（渲染层会画红色底，安全区内画绿色圈）
        table.insert(circles, {
            x = scene.centerX,
            y = scene.centerY,
            radius = scene.arenaSize / 2 + 1,
            color = {255, 80, 30, math.floor(120 * (1 - progress * 0.3))},
            progress = progress,
            type = "fire_field",
        })
        -- 安全区绿圈
        for _, zone in ipairs(scene.safeZones) do
            table.insert(circles, {
                x = zone.x,
                y = zone.y,
                radius = zone.radius,
                color = {50, 255, 100, math.floor(200 * (1 - progress * 0.3))},
                progress = progress,
                type = "safe_zone",
            })
        end
    end

    return circles
end

--- 获取竞技场边界（供渲染层绘制边界高亮）
function TribulationScene.GetArenaBounds()
    if not scene.active then return nil end
    local p = scene.padding
    local s = scene.arenaSize
    return {
        floorMin = p + 2,
        floorMax = p + s + 1,
        centerX = scene.centerX,
        centerY = scene.centerY,
    }
end

return TribulationScene
