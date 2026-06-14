-- ============================================================================
-- PetAnimator.lua - 宠物程序化动画（呼吸待机 + 攻击前倾）
-- ============================================================================
-- 纯程序化变换，不需要额外帧图，适用于所有皮肤。
-- 渲染层（pet.lua）每帧调用 PetAnimator.GetVisualFX() 获取变换参数。
-- ============================================================================

local EventBus = require("core.EventBus")
local GameState = require("core.GameState")

local PetAnimator = {}

-- ═══════════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════════

local _phaseTimer = 0          -- 持续计时（驱动呼吸sin波）
local _attackTimer = -1        -- 攻击动画计时器（<0 表示未激活）
local ATTACK_DURATION = 0.3    -- 攻击动画总时长
local _lastGameTime = -1       -- 上一帧 gameTime（内部计算 dt）

-- 输出给渲染层的变换值
local _fx = {
    offsetX = 0,
    offsetY = 0,
    scaleX = 1.0,
    scaleY = 1.0,
    rotation = 0,
}

-- ═══════════════════════════════════════════
-- 初始化（订阅攻击事件）
-- ═══════════════════════════════════════════

function PetAnimator.Init()
    _phaseTimer = 0
    _attackTimer = -1
    _lastGameTime = -1

    EventBus.On("pet_attack", function()
        _attackTimer = 0
    end)

    EventBus.On("pet_skill_attack", function()
        _attackTimer = 0
    end)
end

-- ═══════════════════════════════════════════
-- 每帧更新（内部计算 dt，由 GetVisualFX 自动调用）
-- ═══════════════════════════════════════════

local function _Update()
    -- 内部计算 dt（与 PlayerAnimator 一致）
    local curTime = GameState.gameTime or 0
    local dt
    if _lastGameTime < 0 then
        dt = 0.016
    else
        dt = curTime - _lastGameTime
    end
    _lastGameTime = curTime

    if dt <= 0 then return end
    if dt > 0.1 then dt = 0.016 end

    _phaseTimer = _phaseTimer + dt

    -- 攻击动画活跃时
    if _attackTimer >= 0 then
        _attackTimer = _attackTimer + dt

        local t = _attackTimer / ATTACK_DURATION  -- 0~1 归一化进度

        if t < 0.27 then
            -- 阶段1: 蓄力后缩 (0~0.08s)
            local p = t / 0.27
            _fx.scaleX = 1.0 - 0.05 * p
            _fx.scaleY = 1.0 + 0.03 * p
            _fx.offsetX = -1.0 * p
            _fx.offsetY = 0
            _fx.rotation = 0.01 * p  -- 微微后仰

        elseif t < 0.67 then
            -- 阶段2: 前冲前倾 (0.08~0.2s)
            local p = (t - 0.27) / 0.4
            _fx.scaleX = 1.0 + 0.06 * p
            _fx.scaleY = 1.0 - 0.03 * p
            _fx.offsetX = 3.0 * p
            _fx.offsetY = -1.0 * p
            _fx.rotation = -0.07 * p  -- 前倾约4°

        else
            -- 阶段3: 回弹复位 (0.2~0.3s)
            local p = (t - 0.67) / 0.33
            -- ease-out: 快速恢复
            local ease = 1.0 - (1.0 - p) * (1.0 - p)
            _fx.scaleX = 1.06 + (1.0 - 1.06) * ease
            _fx.scaleY = 0.97 + (1.0 - 0.97) * ease
            _fx.offsetX = 3.0 * (1.0 - ease)
            _fx.offsetY = -1.0 * (1.0 - ease)
            _fx.rotation = -0.07 * (1.0 - ease)
        end

        -- 攻击结束
        if _attackTimer >= ATTACK_DURATION then
            _attackTimer = -1
            _fx.offsetX = 0
            _fx.offsetY = 0
            _fx.scaleX = 1.0
            _fx.scaleY = 1.0
            _fx.rotation = 0
        end
    else
        -- idle 呼吸动画（相位偏移，与角色异步）
        local breathVal = math.sin(_phaseTimer * 2.0 + 2.2)
        _fx.offsetX = 0
        _fx.offsetY = breathVal * 1.5
        _fx.scaleX = 1.0
        _fx.scaleY = 1.0 + breathVal * 0.012
        _fx.rotation = 0
    end
end

-- ═══════════════════════════════════════════
-- 获取当前变换值（渲染层调用，自动推进动画）
-- ═══════════════════════════════════════════

function PetAnimator.GetVisualFX()
    _Update()
    return _fx
end

return PetAnimator
