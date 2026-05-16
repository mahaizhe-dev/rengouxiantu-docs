-- ============================================================================
-- PatrolPresets.lua - 巡逻模板层
-- 提供可复用的巡逻模板，实例通过 patrolPreset + patrol 覆盖接入
-- ============================================================================

local PatrolPresets = {}

--- 巡逻模板定义
--- 每个模板提供默认参数，实例层可覆盖任意字段
PatrolPresets.presets = {
    -- 固定路点循环：适合狭长通路、寨内绕场
    waypoint_loop = {
        mode = "waypoint_loop",
        pauseMin = 0.8,
        pauseMax = 1.6,
        arrivalDist = 0.45,
        returnMode = "resume_patrol",  -- 脱战后回到最近路点继续巡逻
    },

    -- 大范围路点循环：适合较大区域
    large_waypoint_loop = {
        mode = "waypoint_loop",
        pauseMin = 1.0,
        pauseMax = 2.0,
        arrivalDist = 0.5,
        returnMode = "resume_patrol",
    },

    -- 堡垒巡逻：适合山寨、院落，围绕核心空地和入口
    fortress_loop = {
        mode = "waypoint_loop",
        pauseMin = 1.2,
        pauseMax = 2.5,
        arrivalDist = 0.5,
        returnMode = "resume_patrol",
    },
}

--- 合并预设与实例覆盖，返回最终巡逻配置
---@param presetName string|nil 预设名
---@param override table|nil 实例覆盖
---@return table|nil 最终巡逻配置，无配置时返回 nil
function PatrolPresets.Resolve(presetName, override)
    if not presetName and not override then
        return nil
    end

    local base = {}

    -- 从预设复制默认值
    if presetName and PatrolPresets.presets[presetName] then
        local preset = PatrolPresets.presets[presetName]
        for k, v in pairs(preset) do
            base[k] = v
        end
    end

    -- 实例覆盖
    if override then
        for k, v in pairs(override) do
            base[k] = v
        end
    end

    return base
end

return PatrolPresets
