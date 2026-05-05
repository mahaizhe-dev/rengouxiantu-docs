-- ============================================================================
-- EventBus.lua - 简单发布/订阅事件系统
-- ============================================================================

local EventBus = {}
local listeners = {}

--- 订阅事件
---@param event string
---@param callback function
---@return function unsubscribe 取消订阅函数
function EventBus.On(event, callback)
    if not listeners[event] then
        listeners[event] = {}
    end
    table.insert(listeners[event], callback)

    -- 返回取消订阅函数
    return function()
        EventBus.Off(event, callback)
    end
end

--- 取消订阅
---@param event string
---@param callback function
function EventBus.Off(event, callback)
    if not listeners[event] then return end
    for i = #listeners[event], 1, -1 do
        if listeners[event][i] == callback then
            table.remove(listeners[event], i)
            break
        end
    end
end

--- 发布事件（pcall 保护，防止单个 listener 错误中断整个调用链）
---@param event string
---@param ... any
function EventBus.Emit(event, ...)
    local cbs = listeners[event]  -- P2-14: 局部化避免重复哈希查找
    if not cbs then return end
    -- 快照：防止 listener 内 Off 导致前向迭代跳过后续回调
    local snapshot = {table.unpack(cbs)}
    for i = 1, #snapshot do
        local ok, err = pcall(snapshot[i], ...)
        if not ok then
            print("[EventBus] ERROR in '" .. event .. "' listener #" .. i .. ": " .. tostring(err))
        end
    end
end

--- 清除所有监听器
function EventBus.Clear()
    listeners = {}
end

return EventBus
