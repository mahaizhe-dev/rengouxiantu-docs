-- ============================================================================
-- BattleContracts.lua — 战斗系统统一契约定义
-- ============================================================================
-- 定义命中上下文 (HitContext) 和命中结果 (HitResult) 的标准结构，
-- 作为未来 HitResolver / TargetSelector / ComboRunner 的公共数据契约。
--
-- 本模块不包含业务逻辑，仅提供：
--   1. 契约结构的构造函数（带默认值）
--   2. 合法 damageTag 枚举
--   3. 轻量验证工具（调试用）
-- ============================================================================

local BattleContracts = {}

-- ---------------------------------------------------------------------------
-- damageTag 枚举
-- ---------------------------------------------------------------------------

---@enum DamageTag
BattleContracts.DamageTag = {
    NORMAL   = "normal",     -- 普通攻击
    SKILL    = "skill",      -- 主动技能
    HEAVY    = "heavy",      -- 重击
    PET      = "pet",        -- 宠物攻击
    SET_AOE  = "set_aoe",    -- 套装 AoE
    DOT      = "dot",        -- 持续伤害
    BLOOD_RAGE = "blood_rage", -- 血怒引爆
    ARTIFACT = "artifact",   -- 神器追击
}

-- ---------------------------------------------------------------------------
-- HitContext — 命中上下文（攻击方构造，传入 HitResolver）
-- ---------------------------------------------------------------------------

--- 创建一个 HitContext
---@param overrides table|nil 可选的字段覆盖
---@return table HitContext
function BattleContracts.NewHitContext(overrides)
    local ctx = {
        source      = nil,       -- 攻击来源（Player / Pet）
        target      = nil,       -- 攻击目标（Monster / Player / Pet）
        skill       = nil,       -- 技能数据（SkillData 条目，普攻为 nil）
        rawDamage   = 0,         -- 原始伤害（CalcDamage 之前的 ATK 基数）
        canCrit     = true,      -- 是否允许暴击
        isDot       = false,     -- 是否持续伤害（影响血怒/套装 AoE 过滤）
        isHeavyHit  = false,     -- 是否重击
        isTrueDamage = false,    -- 是否真实伤害（跳过防御计算）
        damageTag   = "normal",  -- DamageTag 枚举值
        onApplied   = nil,       -- 命中后回调 function(result)
    }
    if overrides then
        for k, v in pairs(overrides) do
            ctx[k] = v
        end
    end
    return ctx
end

-- ---------------------------------------------------------------------------
-- HitResult — 命中结果（HitResolver 输出）
-- ---------------------------------------------------------------------------

--- 创建一个 HitResult
---@param overrides table|nil 可选的字段覆盖
---@return table HitResult
function BattleContracts.NewHitResult(overrides)
    local result = {
        requestedDamage = 0,     -- 请求伤害（CalcDamage 之后、TakeDamage 之前）
        finalDamage     = 0,     -- 实际伤害（TakeDamage 返回值）
        isCrit          = false, -- 是否暴击
        targetAlive     = true,  -- 目标是否存活
        wasEvaded       = false, -- 是否被闪避
        wasAbsorbed     = false, -- 是否被护盾完全吸收
        source          = nil,   -- 攻击来源
        target          = nil,   -- 攻击目标
    }
    if overrides then
        for k, v in pairs(overrides) do
            result[k] = v
        end
    end
    return result
end

-- ---------------------------------------------------------------------------
-- 调试工具
-- ---------------------------------------------------------------------------

--- 验证 HitContext 是否包含必要字段（调试用，生产环境可跳过）
---@param ctx table
---@return boolean ok
---@return string|nil errMsg
function BattleContracts.ValidateHitContext(ctx)
    if not ctx then return false, "HitContext is nil" end
    if not ctx.source then return false, "HitContext.source is nil" end
    if not ctx.target then return false, "HitContext.target is nil" end
    if type(ctx.rawDamage) ~= "number" then return false, "HitContext.rawDamage is not a number" end
    return true, nil
end

--- 验证 HitResult 是否包含必要字段（调试用）
---@param result table
---@return boolean ok
---@return string|nil errMsg
function BattleContracts.ValidateHitResult(result)
    if not result then return false, "HitResult is nil" end
    if type(result.finalDamage) ~= "number" then return false, "HitResult.finalDamage is not a number" end
    return true, nil
end

return BattleContracts
