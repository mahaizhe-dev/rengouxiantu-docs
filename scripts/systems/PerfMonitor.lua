-- ============================================================================
-- PerfMonitor.lua - Phase 0 性能基线采集
-- ============================================================================
-- 用途：在 HandleUpdate 中对关键段计时，每 N 秒输出 p50/p95/max 统计。
-- 计时：使用引擎 time:GetElapsedTime()（秒级浮点，微秒精度）。
--       os.clock() 在 WASM 上精度不足，已弃用。
-- 开关：GameConfig.PERF_FLAGS.enabled（默认 false），GM 命令 /perf 运行时切换。
-- 输出：[PERF] 前缀日志，可通过 grep '[PERF]' 过滤。
-- ============================================================================

local PerfMonitor = {}

-- ----------------------------------------------------------------------------
-- 高精度计时（引擎 time 子系统，微秒精度；WASM 下 os.clock() 精度不足）
-- ----------------------------------------------------------------------------
local function _now()
    return time.elapsedTime -- 属性访问，与项目其余代码一致
end

-- ----------------------------------------------------------------------------
-- 内部状态
-- ----------------------------------------------------------------------------
local _enabled = false
local _reportInterval = 10
local _timer = 0

-- 段计时：name -> { samples = {float[]}, _start = float }
local _segments = {}

-- 帧总计时
local _frameStart = 0
local _frameSamples = {}

-- 计数器：name -> int（每个报告周期重置）
local _counters = {}

-- 最近一次报告文本（供 GM 面板读取）
local _lastReport = ""

-- ----------------------------------------------------------------------------
-- 公共 API
-- ----------------------------------------------------------------------------

--- 初始化（在 GameStart 中调用一次）
---@param perfFlags table GameConfig.PERF_FLAGS
function PerfMonitor.Init(perfFlags)
    _enabled = perfFlags and perfFlags.enabled or false
    _reportInterval = (perfFlags and perfFlags.reportInterval) or 10
    print("[PerfMonitor] Init: enabled=" .. tostring(_enabled)
        .. " reportInterval=" .. tostring(_reportInterval) .. "s")
end

--- 运行时开关切换
function PerfMonitor.Toggle()
    _enabled = not _enabled
    -- 切换时清空历史，避免残留数据污染
    PerfMonitor._Reset()
    print("[PerfMonitor] " .. (_enabled and "ENABLED" or "DISABLED"))
    return _enabled
end

function PerfMonitor.IsEnabled()
    return _enabled
end

--- 帧开始（HandleUpdate 入口）
function PerfMonitor.BeginFrame()
    if not _enabled then return end
    _frameStart = _now()
end

--- 帧结束（HandleUpdate 出口），传入 dt 驱动报告计时
---@param dt number
function PerfMonitor.EndFrame(dt)
    if not _enabled then return end
    local elapsed = (_now() - _frameStart) * 1000 -- ms
    _frameSamples[#_frameSamples + 1] = elapsed

    _timer = _timer + dt
    if _timer >= _reportInterval then
        PerfMonitor._Report()
        _timer = 0
    end
end

--- 段计时开始
---@param name string
function PerfMonitor.StartSegment(name)
    if not _enabled then return end
    local seg = _segments[name]
    if not seg then
        seg = { samples = {}, _start = 0 }
        _segments[name] = seg
    end
    seg._start = _now()
end

--- 段计时结束
---@param name string
function PerfMonitor.EndSegment(name)
    if not _enabled then return end
    local seg = _segments[name]
    if not seg then return end
    local elapsed = (_now() - seg._start) * 1000 -- ms
    seg.samples[#seg.samples + 1] = elapsed
end

--- 累加计数器（每个报告周期自动重置）
---@param name string
---@param delta? number 默认 1
function PerfMonitor.Count(name, delta)
    if not _enabled then return end
    _counters[name] = (_counters[name] or 0) + (delta or 1)
end

--- 获取最近一次报告文本（供 GM Console 显示）
---@return string
function PerfMonitor.GetLastReport()
    return _lastReport
end

-- ----------------------------------------------------------------------------
-- 内部实现
-- ----------------------------------------------------------------------------

--- 计算排序数组的百分位值
---@param sorted number[]
---@param p number 0~1
---@return number
local function percentile(sorted, p)
    local idx = math.ceil(#sorted * p)
    return sorted[math.max(1, idx)]
end

--- 对样本数组计算统计量
---@param samples number[]
---@return table|nil
local function computeStats(samples)
    local n = #samples
    if n == 0 then return nil end
    table.sort(samples)
    local sum = 0
    for i = 1, n do sum = sum + samples[i] end
    return {
        p50 = percentile(samples, 0.5),
        p95 = percentile(samples, 0.95),
        max = samples[n],
        avg = sum / n,
        n   = n,
    }
end

--- 格式化统计量为一行文本
---@param label string
---@param stats table
---@return string
local function fmtStats(label, stats)
    return string.format("[PERF] %-12s p50=%.2f  p95=%.2f  max=%.2f  avg=%.2f ms  (n=%d)",
        label, stats.p50, stats.p95, stats.max, stats.avg, stats.n)
end

--- 输出报告并重置
function PerfMonitor._Report()
    local lines = {}

    -- 帧总计时
    local frameStats = computeStats(_frameSamples)
    if frameStats then
        local line = fmtStats("frame", frameStats)
        lines[#lines + 1] = line
        print(line)
    end

    -- 各段计时（按名称排序，输出稳定）
    local segNames = {}
    for name in pairs(_segments) do segNames[#segNames + 1] = name end
    table.sort(segNames)
    for _, name in ipairs(segNames) do
        local seg = _segments[name]
        local stats = computeStats(seg.samples)
        if stats then
            local line = fmtStats(name, stats)
            lines[#lines + 1] = line
            print(line)
        end
    end

    -- 计数器
    local frames = frameStats and frameStats.n or 1
    local counterNames = {}
    for name in pairs(_counters) do counterNames[#counterNames + 1] = name end
    table.sort(counterNames)
    for _, name in ipairs(counterNames) do
        local val = _counters[name]
        local line = string.format("[PERF] counter.%-20s total=%-8d avg/frame=%.1f",
            name, val, val / frames)
        lines[#lines + 1] = line
        print(line)
    end

    _lastReport = table.concat(lines, "\n")

    -- 重置
    PerfMonitor._Reset()
end

--- 重置所有采集数据
function PerfMonitor._Reset()
    _frameSamples = {}
    for _, seg in pairs(_segments) do
        seg.samples = {}
    end
    _counters = {}
    _timer = 0
end

return PerfMonitor
