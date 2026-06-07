-- ============================================================================
-- PetSkillRepairService.lua — 宠物技能丢失一次性修复
--
-- 事故背景: 2026-06 V7d 校验逻辑因 string/number key 不匹配，
--           将全服玩家宠物技能整表清空并写入云端。
--
-- 修复策略: 服务端读档时惰性检测，满足全部条件才补写固定技能组合。
-- 执行规则: 只补不删、一次性幂等、保守判定。
--
-- 变更历史:
--   2026-06-07  创建 — 一次性补偿，修复后由幂等标记永久跳过
-- ============================================================================

local PetSkillRepairService = {}

-- ============================================================================
-- 总开关（事故修复完毕后置 false，永久关闭登录时执行）
-- ============================================================================
PetSkillRepairService.ENABLED = false

-- ============================================================================
-- 常量
-- ============================================================================

--- 事故时间窗起点: 2026-06-06 00:00:00 +08:00
PetSkillRepairService.INCIDENT_START_TS = 1780675200

--- 幂等 key 前缀
PetSkillRepairService.FLAG_PREFIX = "pet_skill_restore_v3_s"

--- 幂等标记值
PetSkillRepairService.FLAG_CHECKED = 1   -- 已检查，无需修复
PetSkillRepairService.FLAG_REPAIRED = 2  -- 已修复

--- 固定补偿技能列表（槽位 1~10）
PetSkillRepairService.FIXED_SKILL_IDS = {
    "wisdom_owner",        -- 1: 灵兽通慧
    "constitution_owner",  -- 2: 灵兽铸骨
    "physique_owner",      -- 3: 灵兽淬体
    "fortune_owner",       -- 4: 灵兽赐福
    "hp_basic",            -- 5: 生命强化
    "hpPerLv_basic",       -- 6: 生命·蕴灵
    "def_basic",           -- 7: 防御强化
    "dmgReduce_basic",     -- 8: 减伤强化
    "regen_basic",         -- 9: 恢复强化
    "evade_basic",         -- 10: 闪避强化
}

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 境界 order 查表（硬编码，避免依赖 GameConfig）
local REALM_ORDER = {
    mortal = 0,
    lianqi_1 = 1, lianqi_2 = 2, lianqi_3 = 3,
    zhuji_1 = 4, zhuji_2 = 5, zhuji_3 = 6,
    jindan_1 = 7, jindan_2 = 8, jindan_3 = 9,
    yuanying_1 = 10, yuanying_2 = 11, yuanying_3 = 12,
    huashen_1 = 13, huashen_2 = 14, huashen_3 = 15,
    heti_1 = 16, heti_2 = 17, heti_3 = 18,
    dacheng_1 = 19, dacheng_2 = 20, dacheng_3 = 21, dacheng_4 = 22,
    dujie_1 = 23, dujie_2 = 24, dujie_3 = 25, dujie_4 = 26,
}

--- 章节解锁境界门槛（与 ChapterConfig.requirements.minRealm 对齐）
local CHAPTER_REALM_THRESHOLDS = {
    -- { 最低 order, 对应 tier }
    { order = 17, tier = 4 },  -- heti_2 → 可达第5章 → 特级
    { order = 11, tier = 3 },  -- yuanying_2 → 可达第4章 → 高级
    { order = 6,  tier = 2 },  -- zhuji_3 → 可达第3章 → 中级
}

--- 根据玩家境界返回补偿 tier（按最高可达章节判定）
---@param realm string  玩家当前境界 ID
---@return number|nil  nil 表示不符合补偿资格
local function GetTargetTier(realm)
    local realmOrder = REALM_ORDER[realm]
    if not realmOrder then return nil end
    for _, threshold in ipairs(CHAPTER_REALM_THRESHOLDS) do
        if realmOrder >= threshold.order then
            return threshold.tier
        end
    end
    return nil
end

--- 判断 pet.skills 是否为"整表清空"状态
---@param petData table  saveData.pet
---@return boolean  true = 技能全空（需要修复）
local function IsSkillsEmpty(petData)
    if not petData then return false end
    local skills = petData.skills
    if skills == nil then return true end
    if type(skills) ~= "table" then return true end
    -- 遍历（兼容 string/number key），只要有一个有效技能就不算丢失
    for _, skillData in pairs(skills) do
        if type(skillData) == "table" and skillData.id and skillData.id ~= "" then
            return false
        end
    end
    return true
end

--- 构建修复后的 skills table（string key 格式，与 SerializePet 一致）
---@param tier number
---@return table
local function BuildRepairedSkills(tier)
    local skills = {}
    for i, skillId in ipairs(PetSkillRepairService.FIXED_SKILL_IDS) do
        skills[tostring(i)] = { id = skillId, tier = tier }
    end
    return skills
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 获取幂等 key 名
---@param slot number
---@return string
function PetSkillRepairService.GetFlagKey(slot)
    return PetSkillRepairService.FLAG_PREFIX .. slot
end

--- 判定是否需要修复，返回修复计划
---@param saveData table       完整存档数据
---@param flagValue any         幂等 key 当前值（nil/number）
---@param slot number           槽位号
---@return table plan  { shouldRepair: boolean, shouldMark: boolean, tier: number|nil, reason: string }
function PetSkillRepairService.Evaluate(saveData, flagValue, slot)
    local plan = { shouldRepair = false, shouldMark = false, tier = nil, reason = "" }

    -- 1) 幂等检查：已处理过则永久跳过
    if flagValue and (flagValue == PetSkillRepairService.FLAG_CHECKED
                   or flagValue == PetSkillRepairService.FLAG_REPAIRED) then
        plan.reason = "already_flagged(" .. tostring(flagValue) .. ")"
        return plan
    end

    -- 2) 章节检查
    local player = saveData.player
    if not player then
        plan.shouldMark = true
        plan.reason = "no_player_data"
        return plan
    end

    local realm = player.realm or "mortal"
    local tier = GetTargetTier(realm)
    if not tier then
        plan.shouldMark = true
        plan.reason = "realm_too_low(" .. realm .. ")"
        return plan
    end

    -- 3) 时间窗检查
    local ts = saveData.timestamp or 0
    if ts < PetSkillRepairService.INCIDENT_START_TS then
        plan.shouldMark = true
        plan.reason = "before_incident_window(ts=" .. ts .. ")"
        return plan
    end

    -- 4) 技能丢失检查
    if not IsSkillsEmpty(saveData.pet) then
        plan.shouldMark = true
        plan.reason = "skills_not_empty"
        return plan
    end

    -- 全部条件满足 → 需要修复
    plan.shouldRepair = true
    plan.shouldMark = true
    plan.tier = tier
    plan.reason = "repair_needed(realm=" .. realm .. ",tier=" .. tier .. ")"
    return plan
end

--- 执行修复：原地修改 saveData.pet.skills
---@param saveData table
---@param tier number
function PetSkillRepairService.ApplyRepair(saveData, tier)
    if not saveData.pet then
        saveData.pet = {}
    end
    local before = saveData.pet.skills
    saveData.pet.skills = BuildRepairedSkills(tier)
    print("[PetSkillRepair V3] REPAIRED: before=" .. tostring(before)
        .. " -> 10 skills at tier=" .. tier)
end

return PetSkillRepairService
