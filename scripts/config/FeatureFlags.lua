-- ============================================================================
-- FeatureFlags.lua — 统一功能开关 / Kill Switch 入口
--
-- P0-2: 线上开关与发布护栏
--
-- 设计原则：
--   1. 纯叶模块，零依赖（不 require 任何业务模块）
--   2. 所有开关默认 false，不改变当前行为
--   3. 统一读取 API，禁止外部直接访问内部表
--   4. 每个开关必须有 name / default / desc / task 四个元数据
--
-- 使用方式：
--   local FF = require("config.FeatureFlags")
--   if FF.isEnabled("SAVE_PIPELINE_V2") then
--       -- 新路径
--   else
--       -- 旧路径（当前默认）
--   end
-- ============================================================================

local FeatureFlags = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- 第一批 flag 元数据（P0-2 定义，全部默认 false）
-- ═══════════════════════════════════════════════════════════════════════════

---@class FlagMeta
---@field name    string  开关标识（与 key 相同）
---@field default boolean 默认值（当前全部 false）
---@field desc    string  开关说明
---@field task    string  对应后续任务 ID

---@type table<string, FlagMeta>
local FLAG_REGISTRY = {
    SAVE_PIPELINE_V2 = {
        name    = "SAVE_PIPELINE_V2",
        default = false,
        desc    = "启用 v2 存档管线（SavePersistence 统一读写）",
        task    = "P0-5",
    },
    SERVER_SAVE_VALIDATOR_V2 = {
        name    = "SERVER_SAVE_VALIDATOR_V2",
        default = false,
        desc    = "启用 v2 服务端存档校验器",
        task    = "P0-5",
    },
    SAVE_MIGRATION_SINGLE_ENTRY = {
        name    = "SAVE_MIGRATION_SINGLE_ENTRY",
        default = false,
        desc    = "启用迁移单入口模式（所有迁移逻辑收口到 SaveMigrations）",
        task    = "P0-3",
    },
    NEW_MAIN_LOOP_ORCHESTRATOR = {
        name    = "NEW_MAIN_LOOP_ORCHESTRATOR",
        default = false,
        desc    = "启用新版主循环编排器（替换 main.lua 中的手动调度）",
        task    = "P0-4",
    },
    NEW_SERVER_ROUTER = {
        name    = "NEW_SERVER_ROUTER",
        default = false,
        desc    = "启用新版服务端路由器（替换 server_main.lua 中的 handler 分发）",
        task    = "P0-6",
    },
    CLOUDSTORAGE_STRICT_BATCHSET = {
        name    = "CLOUDSTORAGE_STRICT_BATCHSET",
        default = false,
        desc    = "启用 CloudStorage 严格 BatchSet 模式（禁止散写）",
        task    = "P0-5",
    },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 运行时覆盖层（override）
-- 允许运行时动态切换开关，不修改注册表默认值
-- ═══════════════════════════════════════════════════════════════════════════

---@type table<string, boolean>
local overrides = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- 公共 API
-- ═══════════════════════════════════════════════════════════════════════════

--- 查询开关是否启用
--- 优先级：override > FLAG_REGISTRY.default
--- 未定义的开关返回 false（安全降级，不会崩溃）
---@param flagName string
---@return boolean
function FeatureFlags.isEnabled(flagName)
    -- 1. 检查运行时覆盖
    local ov = overrides[flagName]
    if ov ~= nil then
        return ov
    end
    -- 2. 检查注册表默认值
    local meta = FLAG_REGISTRY[flagName]
    if meta then
        return meta.default
    end
    -- 3. 未定义 → false（安全降级）
    return false
end

--- 运行时覆盖某个开关的值
--- 仅影响当前运行时，不持久化
---@param flagName string
---@param value boolean
---@return boolean ok 是否为已注册的开关
function FeatureFlags.setOverride(flagName, value)
    if type(value) ~= "boolean" then
        return false
    end
    overrides[flagName] = value
    -- 即使 flag 未注册也允许 override（前向兼容）
    return FLAG_REGISTRY[flagName] ~= nil
end

--- 清除某个开关的运行时覆盖，恢复默认值
---@param flagName string
function FeatureFlags.clearOverride(flagName)
    overrides[flagName] = nil
end

--- 清除所有运行时覆盖
function FeatureFlags.clearAllOverrides()
    overrides = {}
end

--- 获取某个开关的完整元数据（只读副本）
--- 未定义返回 nil
---@param flagName string
---@return FlagMeta|nil
function FeatureFlags.getMeta(flagName)
    local meta = FLAG_REGISTRY[flagName]
    if not meta then return nil end
    -- 返回浅拷贝，防止外部篡改
    return {
        name    = meta.name,
        default = meta.default,
        desc    = meta.desc,
        task    = meta.task,
    }
end

--- 获取所有已注册的 flag 名称列表
---@return string[]
function FeatureFlags.getAllNames()
    local names = {}
    for k, _ in pairs(FLAG_REGISTRY) do
        names[#names + 1] = k
    end
    table.sort(names)  -- 保证顺序稳定
    return names
end

--- 获取所有已注册 flag 的数量
---@return integer
function FeatureFlags.getCount()
    local n = 0
    for _ in pairs(FLAG_REGISTRY) do
        n = n + 1
    end
    return n
end

--- 获取所有 flag 的当前生效值快照（用于调试/日志）
---@return table<string, boolean>
function FeatureFlags.snapshot()
    local snap = {}
    for name, _ in pairs(FLAG_REGISTRY) do
        snap[name] = FeatureFlags.isEnabled(name)
    end
    return snap
end

--- （仅测试用）重置整个模块状态
--- 生产代码不应调用此函数
function FeatureFlags._resetForTest()
    overrides = {}
end

return FeatureFlags
