---@diagnostic disable
-- ============================================================================
-- PlayerAnimator.lua - 玩家帧动画系统
-- ============================================================================
-- 职责：
--   1. 根据玩家状态（idle/move/attack）输出当前帧的精灵图路径
--   2. 监听攻击事件触发攻击动画序列
--   3. 渲染层读取输出的 spritePath 来绘制对应帧
-- ============================================================================

local EventBus = require("core.EventBus")
local GameState = require("core.GameState")

local PlayerAnimator = {}
local _lastGameTime = -1  -- -1 表示未初始化，首帧会被特殊处理

-- ═══════════════════════════════════════════
-- 帧动画配置（每个角色的帧序列）
-- ═══════════════════════════════════════════

local ANIM_DATA = {
    monk = {
        idle = {
            frames = { "Textures/anim/monk/idle_1.png" },
            fps = 1,
        },
        move = {
            frames = {
                "Textures/anim/monk/move_1.png",  -- 左脚迈出
                "Textures/anim/monk/move_2.png",  -- 过渡（幅度收小）
                "Textures/anim/monk/move_3.png",  -- 右脚迈出
                "Textures/anim/monk/move_4.png",  -- 回程过渡
            },
            fps = 6,  -- 4帧 / 6fps = 0.67秒一个完整步伐循环
        },
        attack = {
            frames = {
                "Textures/anim/monk/atk_1.png",  -- 举刀蓄力
                "Textures/anim/monk/atk_2.png",  -- 挥砍中段
                "Textures/anim/monk/atk_3.png",  -- 下劈到位
                "Textures/anim/monk/atk_4.png",  -- 收刀回位
            },
            fps = 10,  -- 4帧 / 10fps = 0.4秒完成攻击
            loop = false,
        },
    },
    taixu = {
        idle = {
            frames = { "Textures/anim/taixu/idle_1.png" },
            fps = 1,
        },
        move = {
            frames = {
                "Textures/anim/taixu/move_1.png",  -- 左脚迈出
                "Textures/anim/taixu/move_2.png",  -- 过渡并拢
                "Textures/anim/taixu/move_3.png",  -- 右脚迈出
                "Textures/anim/taixu/move_4.png",  -- 回程过渡
            },
            fps = 6,
        },
        attack = {
            frames = {
                "Textures/anim/taixu/atk_1.png",  -- 蓄力举剑
                "Textures/anim/taixu/atk_2.png",  -- 突刺中段
                "Textures/anim/taixu/atk_3.png",  -- 刺出到位
                "Textures/anim/taixu/atk_4.png",  -- 收剑回位
            },
            fps = 10,
            loop = false,
        },
    },
    zhenyue = {
        idle = {
            frames = { "Textures/anim/zhenyue/idle_1.png" },
            fps = 1,
        },
        move = {
            frames = {
                "Textures/anim/zhenyue/move_1.png",  -- 左脚迈出
                "Textures/anim/zhenyue/move_2.png",  -- 过渡并拢
                "Textures/anim/zhenyue/move_3.png",  -- 右脚迈出
                "Textures/anim/zhenyue/move_4.png",  -- 回程过渡
            },
            fps = 6,
        },
        attack = {
            frames = {
                "Textures/anim/zhenyue/atk_1.png",  -- 蓄力后拉
                "Textures/anim/zhenyue/atk_2.png",  -- 直拳出击
                "Textures/anim/zhenyue/atk_3.png",  -- 上勾追击
                "Textures/anim/zhenyue/atk_4.png",  -- 收拳回位
            },
            fps = 10,
            loop = false,
        },
    },
}

-- 默认 fallback 帧
local FALLBACK_SPRITES = {
    monk    = "Textures/player_right.png",
    taixu   = "Textures/class_swordsman_right.png",
    zhenyue = "Textures/class_body_cultivator_right.png",
}

-- ═══════════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════════

local _animState = {
    state = "idle",
    frameIndex = 1,
    frameTimer = 0,
    attackFinished = false,
}

-- 程序化动画效果参数（渲染层读取）
local _visualFX = {
    offsetY = 0,     -- Y轴偏移（像素）
    scaleX = 1.0,    -- X轴缩放
    scaleY = 1.0,    -- Y轴缩放
    rotation = 0,    -- 旋转角度（弧度）
}

-- 连续计时器（用于sin波动）
local _phaseTimer = 0

-- ── 位移驱动步态 ──
local _lastPlayerX = nil
local _lastPlayerY = nil
local _movePhase = 0           -- 0~1 循环相位
local STRIDE_LENGTH = 1.8      -- 一个完整步伐循环对应的世界单位距离(格)
local TELEPORT_THRESHOLD = 3.0 -- 超过此距离视为传送，不累计

-- ═══════════════════════════════════════════
-- 初始化 & 事件订阅
-- ═══════════════════════════════════════════

function PlayerAnimator.Init()
    -- 重置动画状态（支持 InitGame 多次调用，因为 EventBus.Clear 会清除旧订阅）
    _animState.state = "idle"
    _animState.frameIndex = 1
    _animState.frameTimer = 0
    _animState.attackFinished = false
    _lastGameTime = -1
    _lastPlayerX = nil
    _lastPlayerY = nil
    _movePhase = 0

    -- 重新注册事件监听（EventBus.Clear 后必须重新订阅）
    EventBus.On("player_attack", function(player, monster, damage)
        if not player then return end
        -- 防止攻击动画正在播放时被重复重置（让动画播完）
        if _animState.state == "attack" and not _animState.attackFinished then
            return
        end
        _animState.state = "attack"
        _animState.frameIndex = 1
        _animState.frameTimer = 0
        _animState.attackFinished = false
    end)

    print("[PlayerAnimator] Frame animation system initialized")
end

-- ═══════════════════════════════════════════
-- 每帧更新 → 返回当前应显示的精灵图路径
-- ═══════════════════════════════════════════

function PlayerAnimator.Update(player)
    if not player then
        return FALLBACK_SPRITES.monk
    end

    local classId = player.classId or "monk"
    local animData = ANIM_DATA[classId]

    if not animData then
        return FALLBACK_SPRITES[classId] or FALLBACK_SPRITES.monk
    end

    -- 计算 dt：使用 GameState.gameTime 差值
    local curTime = GameState.gameTime or 0
    local dt
    if _lastGameTime < 0 then
        -- 首帧：用默认帧间隔
        dt = 0.016
    else
        dt = curTime - _lastGameTime
    end
    _lastGameTime = curTime

    -- 钳制 dt：防止异常跳帧
    if dt <= 0 then
        dt = 0  -- 同一帧内多次调用，不推进
    elseif dt > 0.1 then
        dt = 0.016  -- 异常大间隔，用默认值
    end

    -- ── 状态转换逻辑 ──

    if _animState.state == "attack" then
        if _animState.attackFinished then
            -- 攻击播完，回到 idle 或 move
            _animState.state = player.moving and "move" or "idle"
            _animState.frameIndex = 1
            _animState.frameTimer = 0
        end
        -- 攻击未完成时锁定状态，不受 player.moving 干扰
    else
        -- 非攻击状态：根据 player.moving 切换
        local targetState = player.moving and "move" or "idle"
        if _animState.state ~= targetState then
            _animState.state = targetState
            _animState.frameIndex = 1
            _animState.frameTimer = 0
        end
    end

    -- ── 位移驱动步态相位（move 专用） ──
    local px, py = player.x or 0, player.y or 0
    if _lastPlayerX == nil then
        _lastPlayerX = px
        _lastPlayerY = py
    end
    local dx = px - _lastPlayerX
    local dy = py - _lastPlayerY
    local moveDist = math.sqrt(dx * dx + dy * dy)
    _lastPlayerX = px
    _lastPlayerY = py

    -- 仅在合理范围内累加（排除传送/击退）
    if moveDist > 0 and moveDist < TELEPORT_THRESHOLD then
        _movePhase = (_movePhase + moveDist / STRIDE_LENGTH) % 1.0
    end

    -- ── 帧推进 ──
    local clip = animData[_animState.state]
    if not clip or not clip.frames or #clip.frames == 0 then
        return FALLBACK_SPRITES[classId] or FALLBACK_SPRITES.monk
    end

    local frameCount = #clip.frames
    local frameDuration = 1.0 / (clip.fps or 6)

    if _animState.state == "move" then
        -- ★ 位移驱动：phase → 帧索引
        _animState.frameIndex = math.floor(_movePhase * frameCount) + 1
        if _animState.frameIndex > frameCount then _animState.frameIndex = frameCount end
    elseif dt > 0 then
        -- idle/attack 仍用时间驱动
        _animState.frameTimer = _animState.frameTimer + dt

        while _animState.frameTimer >= frameDuration do
            _animState.frameTimer = _animState.frameTimer - frameDuration

            if _animState.frameIndex < frameCount then
                _animState.frameIndex = _animState.frameIndex + 1
            else
                if clip.loop == false then
                    -- 攻击播完：标记完成，停在最后帧
                    _animState.attackFinished = true
                    break
                else
                    -- 循环动画：回到第1帧
                    _animState.frameIndex = 1
                end
            end
        end
    end

    -- ── 程序化视觉效果 ──
    _phaseTimer = _phaseTimer + dt

    if _animState.state == "idle" then
        -- 呼吸起伏：Y轴微小sin波动
        _visualFX.offsetY = math.sin(_phaseTimer * 2.0) * 1.5
        _visualFX.scaleX = 1.0
        _visualFX.scaleY = 1.0 + math.sin(_phaseTimer * 2.0) * 0.01  -- 轻微纵向呼吸
        _visualFX.rotation = 0

    elseif _animState.state == "move" then
        -- ★ 位移驱动：用 movePhase 驱动弹跳和身体摆动
        -- 每步两次触地（phase 0→0.5 左脚，0.5→1 右脚），用 2π 映射一个完整步伐
        local phaseRad = _movePhase * math.pi * 2
        -- 重心弹跳：每半步一次触地（abs sin → 双峰），最高点在 0.25 和 0.75 相位
        local bounce = math.abs(math.sin(phaseRad))
        _visualFX.offsetY = -bounce * 1.2  -- 向上弹跳 1.2px
        -- 身体左右摆动：单周期 sin，左脚右倾/右脚左倾
        _visualFX.rotation = math.sin(phaseRad) * 0.012  -- ±0.7°
        -- 纵向压缩（触地帧轻微 squash）
        _visualFX.scaleX = 1.0 + bounce * 0.01
        _visualFX.scaleY = 1.0 - bounce * 0.008

    elseif _animState.state == "attack" then
        local fi = _animState.frameIndex
        if fi == 1 then
            -- 蓄力：轻微压缩（squash）
            _visualFX.scaleX = 0.92
            _visualFX.scaleY = 1.06
            _visualFX.offsetY = 1.0  -- 微微下沉
            _visualFX.rotation = 0
        elseif fi == 2 then
            -- 挥砍：拉伸（stretch）+ 前倾
            _visualFX.scaleX = 1.08
            _visualFX.scaleY = 0.95
            _visualFX.offsetY = -1.5  -- 向前冲
            _visualFX.rotation = -0.04  -- 前倾约2°
        elseif fi == 3 then
            -- 到位：轻微拉伸保持 + 顿帧感（渲染层不处理，用scale传达冲击）
            _visualFX.scaleX = 1.05
            _visualFX.scaleY = 0.97
            _visualFX.offsetY = -1.0
            _visualFX.rotation = -0.02
        else
            -- 收刀回弹
            local t = _animState.frameTimer / frameDuration  -- 0~1 在当前帧的进度
            local rebound = math.sin(t * math.pi) * 0.03  -- 过冲回弹
            _visualFX.scaleX = 1.0 + rebound
            _visualFX.scaleY = 1.0 - rebound
            _visualFX.offsetY = 0
            _visualFX.rotation = 0
        end
    else
        _visualFX.offsetY = 0
        _visualFX.scaleX = 1.0
        _visualFX.scaleY = 1.0
        _visualFX.rotation = 0
    end

    return clip.frames[_animState.frameIndex]
end

-- ═══════════════════════════════════════════
-- 获取当前帧的视觉修饰参数
-- ═══════════════════════════════════════════

function PlayerAnimator.GetVisualFX()
    return _visualFX
end

function PlayerAnimator.GetState()
    return _animState.state
end

return PlayerAnimator
