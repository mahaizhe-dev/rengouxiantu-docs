-- ============================================================================
-- TownReturnSystem.lua — 黑市快捷回城系统
--
-- 功能：点击入口后 2 秒读条，完成后传送到本章节安全点
-- 参考：FortuneFruitSystem 客户端读条框架
-- 设计文档：docs/仓库整理与黑市快捷回城执行文档.md §4
-- ============================================================================

local GameState      = require("core.GameState")
local EventBus       = require("core.EventBus")
local ActiveZoneData = require("config.ActiveZoneData")
local CombatSystem   = require("systems.CombatSystem")

local TownReturnSystem = {}

-- ============================================================================
-- 常量
-- ============================================================================

--- 读条时长（秒）
TownReturnSystem.CHANNEL_DURATION = 2.0

--- 传送成功后光效持续时间（秒）
TownReturnSystem.FX_DURATION = 0.7

-- ============================================================================
-- 运行时状态
-- ============================================================================

TownReturnSystem._channeling    = false
TownReturnSystem._channelTimer  = 0
TownReturnSystem._fxTimer       = 0       -- 传送完成后光效计时
TownReturnSystem._startX        = 0       -- 读条开始时玩家坐标（用于移动检测）
TownReturnSystem._startY        = 0

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 是否正在读条
---@return boolean
function TownReturnSystem.IsChanneling()
    return TownReturnSystem._channeling
end

--- 获取读条进度 0~1，未读条返回 nil
---@return number|nil progress
function TownReturnSystem.GetChannelProgress()
    if not TownReturnSystem._channeling then return nil end
    local progress = TownReturnSystem._channelTimer / TownReturnSystem.CHANNEL_DURATION
    return math.min(progress, 1.0)
end

--- 获取传送光效剩余时间（>0 则正在播放光效）
---@return number
function TownReturnSystem.GetFxTimer()
    return TownReturnSystem._fxTimer
end

-- ============================================================================
-- 使用条件检查
-- ============================================================================

--- 当前是否允许使用回城
---@return boolean canUse
---@return string|nil reason 不可用原因
function TownReturnSystem.CanUse()
    local player = GameState.player
    if not player or not player.alive then
        return false, "当前无法使用回城"
    end

    -- 挑战系统
    local okCh, ChallengeSystem = pcall(require, "systems.ChallengeSystem")
    if okCh and ChallengeSystem and ChallengeSystem.IsActive and ChallengeSystem.IsActive() then
        return false, "挑战中无法回城"
    end

    -- 试炼塔
    local okTT, TrialTowerSystem = pcall(require, "systems.TrialTowerSystem")
    if okTT and TrialTowerSystem and TrialTowerSystem.IsActive and TrialTowerSystem.IsActive() then
        return false, "试炼塔中无法回城"
    end

    -- 镇狱塔
    local okPT, PrisonTowerSystem = pcall(require, "systems.PrisonTowerSystem")
    if okPT and PrisonTowerSystem and PrisonTowerSystem.IsActive and PrisonTowerSystem.IsActive() then
        return false, "镇狱塔中无法回城"
    end

    -- 副本
    local okDC, DungeonClient = pcall(require, "network.DungeonClient")
    if okDC and DungeonClient and DungeonClient.IsDungeonMode and DungeonClient.IsDungeonMode() then
        return false, "副本中无法回城"
    end

    return true, nil
end

-- ============================================================================
-- 核心操作
-- ============================================================================

--- 尝试开始回城读条（入口按钮点击时调用）
--- 正在读条时再次调用会取消读条
---@return boolean started 是否成功启动或取消
---@return string|nil reason 失败原因
function TownReturnSystem.TryStart()
    -- 正在读条 → 取消
    if TownReturnSystem._channeling then
        TownReturnSystem.Cancel()
        return true, nil
    end

    -- 检查使用条件
    local canUse, reason = TownReturnSystem.CanUse()
    if not canUse then
        return false, reason
    end

    -- 开始读条
    local player = GameState.player
    TownReturnSystem._channeling   = true
    TownReturnSystem._channelTimer = 0
    TownReturnSystem._startX       = player.x
    TownReturnSystem._startY       = player.y

    print("[TownReturn] Channeling started")
    return true, nil
end

--- 取消读条
function TownReturnSystem.Cancel()
    if not TownReturnSystem._channeling then return end
    TownReturnSystem._channeling   = false
    TownReturnSystem._channelTimer = 0
    print("[TownReturn] Channeling cancelled")
end

--- 执行传送（读条完成后调用）
function TownReturnSystem.PerformTeleport()
    local player = GameState.player
    if not player then return end

    local spawn = ActiveZoneData.Get().SPAWN_POINT
    if not spawn then
        print("[TownReturn] ERROR: SPAWN_POINT not found")
        return
    end

    -- 1. 传送玩家
    player.x = spawn.x
    player.y = spawn.y

    -- 2. 同步卡住检测
    player.lastMoveX = spawn.x
    player.lastMoveY = spawn.y
    player.stuckTimer = 0

    -- 3. 重置速度和移动状态
    player.dx = 0
    player.dy = 0
    player.moving = false
    player:SetMoveDirection(0, 0)

    -- 4. 清除战斗目标
    player.target = nil

    -- 5. 宠物同步
    local pet = GameState.pet
    if pet then
        pet.x = spawn.x + 1
        pet.y = spawn.y
        pet.target = nil
        pet.state = "follow"
    end

    -- 6. 清除怪物仇恨
    if GameState.monsters then
        for i = 1, #GameState.monsters do
            local m = GameState.monsters[i]
            if m.alive then
                m.target = nil
                m.state = "idle"
            end
        end
    end

    -- 7. 清除残留技能特效（防止 stale effect 导致渲染错误）
    if CombatSystem.skillEffects then
        for i = #CombatSystem.skillEffects, 1, -1 do
            CombatSystem.skillEffects[i] = nil
        end
    end

    -- 8. 启动传送光效
    TownReturnSystem._fxTimer = TownReturnSystem.FX_DURATION

    -- 9. 触发存档
    EventBus.Emit("save_request")

    print("[TownReturn] Teleported to SPAWN_POINT (" .. spawn.x .. ", " .. spawn.y .. ")")
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

---@param dt number
function TownReturnSystem.Update(dt)
    -- 光效衰减
    if TownReturnSystem._fxTimer > 0 then
        TownReturnSystem._fxTimer = TownReturnSystem._fxTimer - dt
        if TownReturnSystem._fxTimer < 0 then
            TownReturnSystem._fxTimer = 0
        end
    end

    -- 非读条状态，无事可做
    if not TownReturnSystem._channeling then return end

    local player = GameState.player

    -- 检查玩家存在且存活
    if not player or not player.alive then
        TownReturnSystem.Cancel()
        return
    end

    -- 检查玩家是否移动（与读条开始时的位置比较）
    local dx = player.x - TownReturnSystem._startX
    local dy = player.y - TownReturnSystem._startY
    local distSq = dx * dx + dy * dy
    if distSq > 0.01 then  -- 容差 0.1 瓦片
        TownReturnSystem.Cancel()
        return
    end

    -- 检查使用条件是否仍然满足（场景切换等）
    local canUse = TownReturnSystem.CanUse()
    if not canUse then
        TownReturnSystem.Cancel()
        return
    end

    -- 推进读条计时
    TownReturnSystem._channelTimer = TownReturnSystem._channelTimer + dt
    if TownReturnSystem._channelTimer >= TownReturnSystem.CHANNEL_DURATION then
        -- 读条完成
        TownReturnSystem._channeling   = false
        TownReturnSystem._channelTimer = 0
        TownReturnSystem.PerformTeleport()
    end
end

return TownReturnSystem
