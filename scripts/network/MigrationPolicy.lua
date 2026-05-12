-- ============================================================================
-- MigrationPolicy.lua — 迁移状态统一判断模块
--
-- P0-4: 迁移入口收敛与废弃迁移分支冻结
--
-- 职责：
--   将散落在 SaveSystemNet.lua / main.lua 中的迁移状态判断逻辑收口
--   到单一模块，由 SAVE_MIGRATION_SINGLE_ENTRY feature flag 控制启用。
--
-- 设计原则：
--   1. 纯判断模块，零副作用（不发网络请求，不修改存档）
--   2. 零业务依赖（仅依赖 FeatureFlags）
--   3. flag=false 时所有 API 退化为 pass-through，不改变现有行为
--   4. 统一状态枚举，消除多处独立判断的不一致风险
--
-- 统一状态集合（5 种）：
--   - MIGRATION_DISABLED : 迁移功能已全局关闭（当前线上默认）
--   - NOT_NEEDED         : 服务端已有存档，无需迁移
--   - ELIGIBLE_CLIENT_CLOUD : 可从 clientCloud 迁移（保留定义，当前不触发）
--   - ELIGIBLE_LOCAL_FILE   : 可从本地导出文件迁移（保留定义，当前不触发）
--   - ALREADY_MIGRATED      : 已完成迁移
--
-- 使用方式：
--   local MP = require("network.MigrationPolicy")
--
--   -- 在 FetchSlots 回调中
--   local state = MP.Evaluate(needMigration, slotCount)
--   if MP.ShouldBlockEntry(state) then ... end
--
--   -- 在 main.lua PC 拦截中
--   if MP.IsPCMigrationCheckNeeded() then ... end
-- ============================================================================

local FeatureFlags = require("config.FeatureFlags")

local MigrationPolicy = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- 统一状态枚举
-- ═══════════════════════════════════════════════════════════════════════════

MigrationPolicy.State = {
    MIGRATION_DISABLED    = "migration_disabled",
    NOT_NEEDED            = "not_needed",
    ELIGIBLE_CLIENT_CLOUD = "eligible_client_cloud",
    ELIGIBLE_LOCAL_FILE   = "eligible_local_file",
    ALREADY_MIGRATED      = "already_migrated",
}

local S = MigrationPolicy.State

-- ═══════════════════════════════════════════════════════════════════════════
-- 内部：当前迁移总开关
-- 迁移在产品层面已废弃，此值硬编码为 false。
-- 未来若需重新启用，改此处 + 对应 flag 即可。
-- ═══════════════════════════════════════════════════════════════════════════

local MIGRATION_GLOBALLY_ENABLED = false

-- ═══════════════════════════════════════════════════════════════════════════
-- 核心 API
-- ═══════════════════════════════════════════════════════════════════════════

--- 判断 P0-4 统一入口是否启用
---@return boolean
function MigrationPolicy.IsEnabled()
    return FeatureFlags.isEnabled("SAVE_MIGRATION_SINGLE_ENTRY")
end

--- 评估迁移状态（统一入口）
---
--- 当 flag=false 时，返回 nil（调用方走原有逻辑）。
--- 当 flag=true 时，根据输入信号返回统一状态枚举。
---
---@param needMigration boolean 服务端返回的 needMigration 值
---@param slotCount number 服务端返回的有效槽位数
---@return string|nil state MigrationPolicy.State 枚举值，flag=false 时返回 nil
function MigrationPolicy.Evaluate(needMigration, slotCount)
    if not MigrationPolicy.IsEnabled() then
        return nil  -- flag 关闭，走原有逻辑
    end

    -- 迁移全局已废弃
    if not MIGRATION_GLOBALLY_ENABLED then
        return S.MIGRATION_DISABLED
    end

    -- 有存档 → 无需迁移
    if not needMigration or slotCount > 0 then
        return S.NOT_NEEDED
    end

    -- needMigration=true 且 slotCount=0
    -- 理论上可进入 ELIGIBLE 分支，但全局开关已关闭（上方已返回 DISABLED）
    -- 此处仅作防御性兜底
    return S.MIGRATION_DISABLED
end

--- 判断给定状态是否应阻止游戏入口
---
--- 当前所有状态均不阻止入口（迁移已废弃）。
--- 保留此 API 以便未来迁移重启时可扩展。
---
---@param state string|nil MigrationPolicy.State 枚举值
---@return boolean
function MigrationPolicy.ShouldBlockEntry(state)
    if state == nil then
        return false  -- flag 关闭，不阻止
    end
    -- 当前所有已知状态均不阻止
    return false
end

--- 判断 PC 端迁移备份检查是否仍需要
---
--- 当 flag=true 时，PC 端 migration_backup_done 拦截被统一收口到此处判断。
--- 由于迁移已废弃，统一返回 false（不再拦截 PC 用户）。
---
--- 当 flag=false 时，返回 true（保持原有 PC 拦截行为，不改变线上表现）。
---
---@return boolean needCheck true=仍需执行 PC 迁移检查, false=跳过
function MigrationPolicy.IsPCMigrationCheckNeeded()
    if not MigrationPolicy.IsEnabled() then
        return true  -- flag 关闭，保持原有行为（PC 仍拦截）
    end
    -- flag 启用 → 迁移已废弃，PC 端不再需要拦截
    return MIGRATION_GLOBALLY_ENABLED
end

--- 判断 FetchSlots 中是否应自动触发迁移流程
---
--- 当 flag=true 时，统一在此判断；当前迁移已废弃，始终返回 false。
--- 当 flag=false 时，返回 false（与当前已废弃的行为一致）。
---
---@param state string|nil MigrationPolicy.State 枚举值
---@return boolean shouldMigrate
function MigrationPolicy.ShouldAutoMigrate(state)
    -- 无论 flag 状态，迁移已废弃，始终不触发
    return false
end

--- 获取迁移状态的中文描述（调试/日志用）
---@param state string|nil MigrationPolicy.State 枚举值
---@return string
function MigrationPolicy.GetStateLabel(state)
    if state == nil then return "未启用(flag=false)" end
    local labels = {
        [S.MIGRATION_DISABLED]    = "迁移已废弃",
        [S.NOT_NEEDED]            = "无需迁移",
        [S.ELIGIBLE_CLIENT_CLOUD] = "可从clientCloud迁移",
        [S.ELIGIBLE_LOCAL_FILE]   = "可从本地文件迁移",
        [S.ALREADY_MIGRATED]      = "已完成迁移",
    }
    return labels[state] or ("未知状态: " .. tostring(state))
end

--- 获取所有合法状态值列表（测试用）
---@return string[]
function MigrationPolicy.GetAllStates()
    return {
        S.MIGRATION_DISABLED,
        S.NOT_NEEDED,
        S.ELIGIBLE_CLIENT_CLOUD,
        S.ELIGIBLE_LOCAL_FILE,
        S.ALREADY_MIGRATED,
    }
end

--- （仅测试用）临时覆盖全局迁移开关
---@param enabled boolean
function MigrationPolicy._setGlobalEnabled(enabled)
    MIGRATION_GLOBALLY_ENABLED = enabled
end

--- （仅测试用）重置全局迁移开关为默认值
function MigrationPolicy._resetForTest()
    MIGRATION_GLOBALLY_ENABLED = false
end

return MigrationPolicy
