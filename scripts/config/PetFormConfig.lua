-- ============================================================================
-- PetFormConfig.lua - 宠物形态系统配置
-- 独立于技能书体系，形态不占技能格、不消耗技能书
-- ============================================================================

local PetFormConfig = {}

-- ===================== 形态定义 =====================
-- 解锁条件绑定 pet.tier
-- statMods: 作用于 GetSkillBonuses 最终乘区 (百分比，正值加成/负值削弱)
-- berserk: 犬魂狂暴参数覆写 (nil 则沿用默认)
-- reviveTime: 固定复活秒数 (nil 则使用 GameConfig.PET_REVIVE_TIME 默认值)

PetFormConfig.FORMS = {
    normal = {
        id = "normal",
        name = "普通形态",
        icon = "🐕",
        desc = "默认形态，无额外增减益",
        unlockTier = 0,   -- 初始可用
        statMods = {},     -- 无修正
        berserk = nil,     -- 使用默认犬魂狂暴
    },
    battle = {
        id = "battle",
        name = "战斗形态",
        icon = "⚔️",
        desc = "稳定输出形态，偏 Boss 战和长线输出",
        unlockTier = 2,
        statMods = {
            atk = 20,       -- 最大攻击力 +20%
        },
        -- 灵噬易伤持续时间倍率 (4s → 8s)
        spiritDevourDurationMul = 2.0,
        berserk = nil,     -- 战斗形态使用默认犬魂狂暴
    },
    guard = {
        id = "guard",
        name = "守护形态",
        icon = "🛡️",
        desc = "生存形态，偏高压图、持续战、宠物站场",
        unlockTier = 3,
        statMods = {
            maxHp = 15,     -- 最大生命值 +15%
        },
        berserk = nil,     -- 守护形态使用默认犬魂狂暴（不额外加减伤）
        reviveTime = 20,   -- 固定复活时间 20 秒（默认 30 秒）
    },
    rage = {
        id = "rage",
        name = "狂暴形态",
        icon = "🔥",
        desc = "高风险爆发形态，偏短时收益和死亡补偿",
        unlockTier = 5,
        statMods = {
            atk = 30,       -- 最大攻击力 +30%
            maxHp = -15,    -- 最大生命值 -15%
        },
        berserk = {
            duration = 10,
            atkSpeedBonus = 0.3,
            moveSpeedBonus = 0.3,
            bonusDmg = 0.15,   -- 额外全伤害 +15%
            dmgReduce = 0,
        },
    },
}

-- 有序列表（用于 UI 遍历）
PetFormConfig.FORM_ORDER = { "normal", "battle", "guard", "rage" }

-- 切换冷却（秒）
PetFormConfig.SWITCH_COOLDOWN = 30

-- Feature flag: 形态系统总开关
-- 设为 false 时，所有形态 API 退化为 normal
PetFormConfig.ENABLED = true

-- PD-2: 狂暴形态独立开关（高风险形态可单独禁用，不影响其他形态）
-- 设为 false 时：rage 不可切换、当前处于 rage 的宠物在下帧自动回退 normal
PetFormConfig.RAGE_ENABLED = true

-- ===================== 辅助 API =====================

--- 获取形态配置
---@param formId string
---@return table|nil
function PetFormConfig.Get(formId)
    return PetFormConfig.FORMS[formId]
end

--- 判断形态是否存在
---@param formId string
---@return boolean
function PetFormConfig.IsValid(formId)
    return PetFormConfig.FORMS[formId] ~= nil
end

--- 获取所有合法 formId 列表
---@return string[]
function PetFormConfig.GetAllIds()
    local ids = {}
    for _, id in ipairs(PetFormConfig.FORM_ORDER) do
        ids[#ids + 1] = id
    end
    return ids
end

--- PD-2: 判断某形态当前是否启用（含独立开关检查）
---@param formId string
---@return boolean
function PetFormConfig.IsFormEnabled(formId)
    if not PetFormConfig.ENABLED then return false end
    if formId == "rage" and not PetFormConfig.RAGE_ENABLED then return false end
    return PetFormConfig.FORMS[formId] ~= nil
end

return PetFormConfig
