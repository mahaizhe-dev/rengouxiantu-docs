-- ============================================================================
-- skill/bar.lua - 技能栏绑定、自动释放、查询
-- ============================================================================

local shared = require("systems.skill.shared")

local SkillData = shared.SkillData
local GameState = shared.GameState
local EventBus  = shared.EventBus

local M = {}

--- 绑定法宝技能到技能栏槽5
---@param skillId string
---@param SkillSystem table 主模块引用（需要访问共享状态）
function M.BindEquipSkill(skillId, SkillSystem)
    local skill = SkillData.Skills[skillId]
    if not skill then return end

    -- 标记解锁
    SkillSystem.unlockedSkills[skillId] = true

    -- 设置槽5（法宝技能）
    SkillSystem.equippedSkills[5] = skillId

    EventBus.Emit("skill_unlocked", skillId, skill)
    print("[SkillSystem] Equip skill bound to slot 5: " .. skill.name)
end

--- 解绑法宝技能（清除槽5）
---@param skillId string
---@param SkillSystem table
function M.UnbindEquipSkill(skillId, SkillSystem)
    if SkillSystem.equippedSkills[5] == skillId then
        SkillSystem.equippedSkills[5] = nil
        SkillSystem.unlockedSkills[skillId] = nil
        -- 不清除 cooldowns：穿脱同一法宝时保留CD，防止反复穿脱刷CD
        print("[SkillSystem] Equip skill unbound from slot 5: " .. skillId)
    end
end

--- 绑定专属装备技能到技能栏槽4
---@param skillId string
---@param SkillSystem table
function M.BindExclusiveSkill(skillId, SkillSystem)
    local skill = SkillData.Skills[skillId]
    if not skill then return end

    SkillSystem.unlockedSkills[skillId] = true
    SkillSystem.equippedSkills[4] = skillId

    EventBus.Emit("skill_unlocked", skillId, skill)
    print("[SkillSystem] Exclusive skill bound to slot 4: " .. skill.name)
end

--- 解绑专属装备技能（清除槽4）
---@param skillId string
---@param SkillSystem table
function M.UnbindExclusiveSkill(skillId, SkillSystem)
    if SkillSystem.equippedSkills[4] == skillId then
        SkillSystem.equippedSkills[4] = nil
        SkillSystem.unlockedSkills[skillId] = nil
        print("[SkillSystem] Exclusive skill unbound from slot 4: " .. skillId)
    end
end

--- 自动释放技能（优先CD较长的技能）
---@param SkillSystem table
---@param _readySkillsBuf table 复用缓冲区
---@return boolean 是否成功释放了任何技能
function M.AutoCast(SkillSystem, _readySkillsBuf)
    local player = GameState.player
    if not player or not player.alive then return false end

    -- 收集所有就绪的技能（已装备且无冷却，跳过被动技能）——复用模块级缓冲区
    local readySkills = _readySkillsBuf
    local rsCount = 0
    for i = 1, SkillData.MAX_SKILL_SLOTS do
        local skillId = SkillSystem.equippedSkills[i]
        if skillId and not SkillSystem.cooldowns[skillId] then
            local skill = SkillData.Skills[skillId]
            -- 只选有 cast 处理器的技能（自动排除所有被动/事件驱动类型）
            -- 跳过 toggle_passive：自动战斗不反复切换激活型技能
            local th = skill and SkillSystem.TypeHandlers[skill.type]
            if skill and th and th.cast and skill.type ~= "toggle_passive" then
                rsCount = rsCount + 1
                local entry = readySkills[rsCount]
                if not entry then
                    entry = {}
                    readySkills[rsCount] = entry
                end
                entry.index = i
                entry.skillId = skillId
                entry.skill = skill
            end
        end
    end
    -- 清除多余的旧条目
    for i = rsCount + 1, #readySkills do readySkills[i] = nil end

    if rsCount == 0 then return false end

    -- 按CD降序排列（优先使用CD较长的技能）
    table.sort(readySkills, function(a, b)
        return a.skill.cooldown > b.skill.cooldown
    end)

    -- 依次尝试释放
    for _, rs in ipairs(readySkills) do
        if SkillSystem.Cast(rs.skillId) then
            return true
        end
    end

    return false
end

--- 获取技能栏信息（供 UI 使用）
---@param SkillSystem table
---@return table[] { {skillId, skill, cdRemaining, cdTotal, unlocked} }
function M.GetSkillBarInfo(SkillSystem)
    local info = {}
    for i = 1, SkillData.MAX_SKILL_SLOTS do
        local skillId = SkillSystem.equippedSkills[i]
        if skillId then
            local skill = SkillData.Skills[skillId]
            local cd = SkillSystem.cooldowns[skillId] or 0
            info[i] = {
                skillId = skillId,
                skill = skill,
                cdRemaining = cd,
                cdTotal = skill and skill.cooldown or 0,
                unlocked = true,
            }
        else
            info[i] = {
                skillId = nil,
                skill = nil,
                cdRemaining = 0,
                cdTotal = 0,
                unlocked = false,
            }
        end
    end
    return info
end

--- 获取冷却比例 (0 = ready, 1 = full CD)
---@param skillId string
---@param SkillSystem table
---@return number
function M.GetCooldownRatio(skillId, SkillSystem)
    local skill = SkillData.Skills[skillId]
    if not skill then return 0 end
    local cd = SkillSystem.cooldowns[skillId]
    if not cd then return 0 end
    return cd / skill.cooldown
end

--- 获取技能栏槽位（供存档使用）
---@param SkillSystem table
---@return table {[1]=skillId, [2]=skillId, ...}
function M.GetSkillBarSlots(SkillSystem)
    local slots = {}
    for i = 1, SkillData.MAX_SKILL_SLOTS do
        if SkillSystem.equippedSkills[i] then
            slots[i] = SkillSystem.equippedSkills[i]
        end
    end
    return slots
end

--- 恢复技能栏（从存档恢复）
---@param slots table
---@param SkillSystem table
function M.RestoreSkillBar(slots, SkillSystem)
    if not slots then return end
    SkillSystem.equippedSkills = {}
    SkillSystem.unlockedSkills = {}

    -- 旧存档兼容：槽4的装备技能迁移到槽5
    if slots[4] and not slots[5] then
        local oldSkill = SkillData.Skills[slots[4]]
        if oldSkill and oldSkill.isEquipSkill then
            slots[5] = slots[4]
            slots[4] = nil
        end
    end

    for i = 1, SkillData.MAX_SKILL_SLOTS do
        local skillId = slots[i]
        if skillId and SkillData.Skills[skillId] then
            SkillSystem.equippedSkills[i] = skillId
            SkillSystem.unlockedSkills[skillId] = true
        end
    end
    -- 确保所有应该解锁的技能都解锁
    SkillSystem.CheckUnlocks()
    -- 重新绑定装备技能（RestoreSkillBar 会清空槽5，需从背包重新检测）
    local ok, InventorySystem = pcall(require, "systems.InventorySystem")
    if ok and InventorySystem and InventorySystem.RecalcEquipStats then
        InventorySystem.RecalcEquipStats()
    end
end

return M
