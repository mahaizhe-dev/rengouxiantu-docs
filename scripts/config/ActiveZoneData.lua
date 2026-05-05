-- ============================================================================
-- ActiveZoneData.lua - 全局活跃 ZoneData 代理
-- 所有需要引用当前章节区域数据的模块都应通过此模块获取
-- 章节切换时由 main.lua 调用 ActiveZoneData.Set() 更新
-- ============================================================================

local ActiveZoneData = {}

-- 默认指向第一章
local current = require("config.ZoneData")

--- 设置当前活跃的 ZoneData
---@param zoneData table 新的 ZoneData 模块
function ActiveZoneData.Set(zoneData)
    current = zoneData
end

--- 获取当前活跃的 ZoneData
---@return table
function ActiveZoneData.Get()
    return current
end

return ActiveZoneData
