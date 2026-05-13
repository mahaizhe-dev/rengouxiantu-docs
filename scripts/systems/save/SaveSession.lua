-- ============================================================================
-- SaveSession.lua - 会话式合并保存辅助模块
-- 将高频 UI 操作（洗练、拆解、附灵、炼丹等）的 save_request 合并，
-- 降低保存频率，减少 slot_locked / rate_limited / 超时掉线体感。
--
-- 参数（来自执行清单）：
--   • 连续 5 次操作后强制收口
--   • 连续 20 秒未落盘则强制收口
--   • 关闭 UI 时强制收口
--   • 空闲 15 秒收口（由外部 auto-save 兜底，此处不额外实现定时器）
--   • 收口失败不清脏（由 SaveSystem 的 _dirty 机制天然保证）
-- ============================================================================

local EventBus = require("core.EventBus")

local SaveSession = {}

-- ============================================================================
-- 常量
-- ============================================================================

local MAX_OPS_BEFORE_FLUSH = 5   -- 连续 N 次操作后强制收口
local MAX_DURATION_SECS    = 20  -- 会话持续 N 秒未落盘则强制收口

-- ============================================================================
-- 运行时状态
-- ============================================================================

local _opCount    = 0     -- 当前会话中的操作计数
local _startTime  = 0     -- 会话首次操作的 os.clock() 时间戳
local _active     = false -- 是否有活跃的脏会话

-- ============================================================================
-- 内部函数
-- ============================================================================

--- 执行收口：发出 save_request 并重置会话
local function _flush(reason)
    if not _active then return end
    print("[SaveSession] Flush: " .. (reason or "unknown")
        .. " (ops=" .. _opCount
        .. ", elapsed=" .. string.format("%.1f", os.clock() - _startTime) .. "s)")
    _active   = false
    _opCount  = 0
    _startTime = 0
    EventBus.Emit("save_request")
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 记录一次操作（替代直接 EventBus.Emit("save_request")）
--- 当操作次数或持续时间达到阈值时自动收口。
function SaveSession.MarkDirty()
    local now = os.clock()

    if not _active then
        -- 开启新会话
        _active    = true
        _opCount   = 1
        _startTime = now
    else
        _opCount = _opCount + 1
    end

    -- 判断是否需要立即收口
    if _opCount >= MAX_OPS_BEFORE_FLUSH then
        _flush("ops>=" .. MAX_OPS_BEFORE_FLUSH)
        return
    end

    if (now - _startTime) >= MAX_DURATION_SECS then
        _flush("duration>=" .. MAX_DURATION_SECS .. "s")
        return
    end

    -- 未达阈值，等待后续操作或 UI 关闭时收口
end

--- UI 关闭时调用，强制收口当前会话的脏数据。
function SaveSession.Flush()
    if _active then
        _flush("ui_close")
    end
end

--- 查询当前会话是否有未落盘的脏操作（调试 / 日志用）
---@return boolean
function SaveSession.IsDirty()
    return _active
end

--- 查询当前会话的操作计数（调试 / 日志用）
---@return number
function SaveSession.GetOpCount()
    return _opCount
end

--- 存档成功后清除会话活跃状态（BM-S4D 收口）
--- game_saved 表示数据已成功持久化，此前积累的脏会话已被覆盖，
--- 可以安全清除 _active，不会丢弃未保存数据。
function SaveSession.ClearOnSave()
    if _active then
        print("[SaveSession] ClearOnSave: cleared stale session"
            .. " (ops=" .. _opCount
            .. ", elapsed=" .. string.format("%.1f", os.clock() - _startTime) .. "s)")
    end
    _active    = false
    _opCount   = 0
    _startTime = 0
end

-- ============================================================================
-- 事件订阅：存档 / 加载成功时清除会话活跃状态
-- ============================================================================

EventBus.On("game_saved", function()
    SaveSession.ClearOnSave()
end)

EventBus.On("game_loaded", function()
    SaveSession.ClearOnSave()
end)

return SaveSession
