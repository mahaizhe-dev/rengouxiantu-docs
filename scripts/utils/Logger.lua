------------------------------------------------------------
-- Logger.lua  —  最小统一日志入口（R1）
--
-- 纯叶模块：不依赖业务代码、不依赖引擎对象
-- 纯 Lua 环境可加载
--
-- 等级：error > warn > info > diag
-- 默认：error/warn/info 开启，diag 关闭
--
-- 用法：
--   local Logger = require("utils.Logger")
--   Logger.info("SaveGame", "保存完成, slot=" .. slot)
--   Logger.diag("FetchSlots", "slotsIndex=" .. json)
--   Logger.SetDiagEnabled(true)   -- 运行时开启诊断
------------------------------------------------------------

local Logger = {}

------------------------------------------------------------
-- 内部状态
------------------------------------------------------------
local _diagEnabled = false

------------------------------------------------------------
-- 公共 API
------------------------------------------------------------

--- 开启 / 关闭 diag 级别输出
---@param enabled boolean
function Logger.SetDiagEnabled(enabled)
    _diagEnabled = (enabled == true)
end

--- 当前 diag 是否开启
---@return boolean
function Logger.IsDiagEnabled()
    return _diagEnabled
end

------------------------------------------------------------
-- 四个等级函数
------------------------------------------------------------

--- 错误：保存失败、回调异常、无法继续
---@param tag string
---@param msg string
function Logger.error(tag, msg)
    print("[ERROR][" .. tag .. "] " .. msg)
end

--- 警告：可恢复异常、降级、废弃路径
---@param tag string
---@param msg string
function Logger.warn(tag, msg)
    print("[WARN][" .. tag .. "] " .. msg)
end

--- 信息：关键链路起止、成功、模式切换
---@param tag string
---@param msg string
function Logger.info(tag, msg)
    print("[INFO][" .. tag .. "] " .. msg)
end

--- 诊断：数据 dump、高频状态、仅排障时需要
--- 默认关闭，需 Logger.SetDiagEnabled(true) 后才输出
---@param tag string
---@param msg string
function Logger.diag(tag, msg)
    if _diagEnabled then
        print("[DIAG][" .. tag .. "] " .. msg)
    end
end

return Logger
