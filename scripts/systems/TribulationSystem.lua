-- ============================================================================
-- TribulationSystem.lua - 渡劫台系统
-- ============================================================================
-- 职责：渡劫台状态管理、进入/退出、冷却、成功/失败结算
-- 首版只实现第1次渡劫（雷火劫），后8次保留框架

local GameState       = require("core.GameState")
local EventBus        = require("core.EventBus")
local AscensionConfig = require("config.AscensionConfig")

local TribulationSystem = {}

-- ── 运行时状态 ───────────────────────────────────────────────────────────────
local state = {
    tribState         = "none",  -- none/ready/inProgress/cooldown
    stageIndex        = 0,       -- 第几次大仙阶渡劫（1-9）
    startedAt         = 0,       -- 开始时间戳
    cooldownUntil     = 0,       -- 冷却结束时间戳
    lastResult        = "none",  -- success/fail/quit/disconnect
    runId             = "",      -- 单次实例 ID
}

-- ============================================================================
-- 初始化
-- ============================================================================

function TribulationSystem.Init()
    state = {
        tribState = "none",
        stageIndex = 0,
        startedAt = 0,
        cooldownUntil = 0,
        lastResult = "none",
        runId = "",
    }
end

function TribulationSystem.GetState()
    return state
end

-- ============================================================================
-- 查询
-- ============================================================================

--- 是否可以进入渡劫台
function TribulationSystem.CanEnter()
    local AscensionSystem = require("systems.AscensionSystem")
    if not AscensionSystem.IsEnabled() then return false, "未达仙阶条件" end
    if not AscensionSystem.IsProgressFull() then return false, "仙阶进度不足" end

    local target = AscensionSystem.GetTargetInfo()
    if not target or not target.isMajor then return false, "当前目标不需要渡劫" end

    local player = GameState.player
    local reqLevel = target.requiredLevel or 1
    if not player or player.level < reqLevel then
        return false, "等级不足 (需要 Lv." .. reqLevel .. ")"
    end

    if state.tribState == "inProgress" then return false, "渡劫中" end
    if state.tribState == "cooldown" then
        local remaining = state.cooldownUntil - os.time()
        if remaining > 0 then
            return false, "冷却中（剩余" .. math.ceil(remaining / 60) .. "分钟）"
        end
        -- 冷却已结束
        state.tribState = "ready"
    end

    return true, nil
end

--- 获取冷却剩余秒数
function TribulationSystem.GetCooldownRemaining()
    if state.tribState ~= "cooldown" then return 0 end
    return math.max(0, state.cooldownUntil - os.time())
end

--- 是否正在渡劫
function TribulationSystem.IsInProgress()
    return state.tribState == "inProgress"
end

-- ============================================================================
-- 进入渡劫台
-- ============================================================================

--- 请求进入渡劫台
---@return boolean success
---@return string|nil msg
function TribulationSystem.Enter()
    local canEnter, msg = TribulationSystem.CanEnter()
    if not canEnter then return false, msg end

    local AscensionSystem = require("systems.AscensionSystem")
    local ascState = AscensionSystem.GetState()

    -- 保存旧状态用于回滚（P1-7 修复）
    local prevTribState = state.tribState
    local prevStageIndex = state.stageIndex
    local prevStartedAt = state.startedAt
    local prevRunId = state.runId
    local prevLastResult = state.lastResult

    state.tribState = "inProgress"
    state.stageIndex = ascState.stageIndex + 1  -- 下一个大仙阶的渡劫
    state.startedAt = os.time()
    state.runId = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
    state.lastResult = "none"

    EventBus.Emit("tribulation_enter", state.stageIndex, state.runId)

    -- 等待场景实际创建成功后再保存；若事件监听端返回失败则回滚
    -- 注：tribulation_enter 监听端（main.lua）会调用 TribulationScene.Enter()
    -- 如果场景创建失败，通过 tribulation_scene_failed 事件回滚
    EventBus.Emit("save_request")

    print("[TribulationSystem] Entered tribulation stage=" .. state.stageIndex .. " runId=" .. state.runId)
    return true, nil
end

--- 场景创建失败时回滚渡劫状态（由 main.lua 调用）
function TribulationSystem.RollbackEnter()
    print("[TribulationSystem] Rolling back enter state")
    state.tribState = "none"
    state.lastResult = "none"
end

-- ============================================================================
-- 结算
-- ============================================================================

--- 渡劫成功
---@return boolean
function TribulationSystem.OnSuccess()
    if state.tribState ~= "inProgress" then return false end

    state.tribState = "none"
    state.lastResult = "success"

    -- 调用 AscensionSystem 完成大仙阶突破
    local AscensionSystem = require("systems.AscensionSystem")
    local ok = AscensionSystem.CompleteMajorBreakthrough()
    if not ok then
        print("[TribulationSystem] ERROR: CompleteMajorBreakthrough failed")
        return false
    end

    -- 首次渡劫成功→解锁仙体（stageIndex==1 或尚未解锁）
    local ImmortalBodySystem = require("systems.ImmortalBodySystem")
    if not ImmortalBodySystem.IsUnlocked("immortal_body_1") then
        ImmortalBodySystem.UnlockBody("immortal_body_1", "first_tribulation")
        print("[TribulationSystem] Unlocked immortal_body_1 on first tribulation success")
    end

    EventBus.Emit("tribulation_success", state.stageIndex, state.runId)
    EventBus.Emit("save_request")

    print("[TribulationSystem] Success! stage=" .. state.stageIndex)
    return true
end

--- 渡劫失败（死亡/退出/断线）
---@param reason string "fail"/"quit"/"disconnect"
function TribulationSystem.OnFail(reason)
    if state.tribState ~= "inProgress" then return end

    reason = reason or "fail"
    state.tribState = "cooldown"
    state.cooldownUntil = os.time() + AscensionConfig.TRIBULATION_COOLDOWN_SEC
    state.lastResult = reason

    -- 不扣进度，不扣道具
    EventBus.Emit("tribulation_fail", state.stageIndex, reason)
    EventBus.Emit("save_request")

    print("[TribulationSystem] Failed: " .. reason .. ", cooldown until " .. os.date("%H:%M:%S", state.cooldownUntil))
end

-- ============================================================================
-- 登录修复（检测 inProgress 状态）
-- ============================================================================

--- 加载后检测异常状态
function TribulationSystem.PostLoadCheck()
    if state.tribState == "inProgress" then
        -- 登录时发现 inProgress → 按失败处理
        print("[TribulationSystem] PostLoad: found inProgress state, treating as disconnect fail")
        state.tribState = "cooldown"
        state.cooldownUntil = os.time() + AscensionConfig.TRIBULATION_COOLDOWN_SEC
        state.lastResult = "disconnect"
    elseif state.tribState == "cooldown" then
        -- 检查冷却是否已过期
        if os.time() >= state.cooldownUntil then
            state.tribState = "none"
        end
    end
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

function TribulationSystem.Serialize()
    return {
        tribState     = state.tribState,
        stageIndex    = state.stageIndex,
        startedAt     = state.startedAt,
        cooldownUntil = state.cooldownUntil,
        lastResult    = state.lastResult,
        runId         = state.runId,
    }
end

function TribulationSystem.Deserialize(data)
    if not data then
        TribulationSystem.Init()
        return
    end
    state.tribState     = data.tribState or "none"
    state.stageIndex    = data.stageIndex or 0
    state.startedAt     = data.startedAt or 0
    state.cooldownUntil = data.cooldownUntil or 0
    state.lastResult    = data.lastResult or "none"
    state.runId         = data.runId or ""
    print("[TribulationSystem] Deserialized: state=" .. state.tribState)
end

return TribulationSystem
