-- ============================================================================
-- skill/casting_a.lua - 技能释放函数（上半）: FilterByShape + 8 种 Cast 类型
-- ============================================================================

local shared = require("systems.skill.shared")

local GameState     = shared.GameState
local CombatSystem  = shared.CombatSystem
local SkillData     = shared.SkillData
local TargetSelector = shared.TargetSelector
local HitResolver   = shared.HitResolver
local ComboRunner   = shared.ComboRunner
local Utils         = shared.Utils

local math_floor  = shared.math_floor
local math_max    = shared.math_max
local math_min    = shared.math_min
local math_atan   = shared.math_atan
local math_cos    = shared.math_cos
local math_sin    = shared.math_sin
local math_abs    = shared.math_abs
local math_rad    = shared.math_rad
local math_pi     = shared.math_pi

local M = {}

--- 按形状过滤目标
---@param targets table[] 预筛目标列表
---@param skill table SkillData entry
---@param player table Player instance
---@param facingAngle number?
---@return table[] 过滤后的目标
function M.FilterByShape(targets, skill, player, facingAngle)
    if not skill.shape then return targets end

    -- 优先使用传入的朝向角，否则退回二值左右朝向
    facingAngle = facingAngle or (player.facingRight and 0 or math_pi)
    local filtered = {}

    if skill.shape == "cone" then
        -- 锥形过滤：检查玩家→目标角度是否在面朝方向 ±(coneAngle/2) 内
        local halfAngle = math_rad((skill.coneAngle or 90) / 2)
        for _, m in ipairs(targets) do
            local dx = m.x - player.x
            local dy = m.y - player.y
            local toTarget = math_atan(dy, dx)
            -- 角度差（归一化到 [-π, π]）
            local diff = toTarget - facingAngle
            diff = math_atan(math_sin(diff), math_cos(diff))
            if math_abs(diff) <= halfAngle then
                table.insert(filtered, m)
            end
        end

    elseif skill.shape == "rect" then
        -- 矩形过滤：以玩家为起点，面朝方向为长轴
        local length = skill.rectLength or 2.0
        local halfWidth = (skill.rectWidth or 1.0) / 2
        local cosA = math_cos(facingAngle)
        local sinA = math_sin(facingAngle)
        for _, m in ipairs(targets) do
            local dx = m.x - player.x
            local dy = m.y - player.y
            -- 投影到面朝方向的局部坐标
            local forward = dx * cosA + dy * sinA   -- 前方分量
            local lateral = -dx * sinA + dy * cosA  -- 侧向分量
            if forward >= 0 and forward <= length and math_abs(lateral) <= halfWidth then
                table.insert(filtered, m)
            end
        end
    else
        return targets
    end

    return filtered
end

--- 释放伤害类技能
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function M.CastDamageSkill(skill, player)
    -- 必须有普攻目标才能释放
    if not player.target or not player.target.alive then return false end
    skill = SkillData.CreateRuntimeSkill(skill, player)
    local castId = CombatSystem.NextCombatCastId(skill.id)

    -- 设置击杀回血乘数（由 GameEvents.monster_death 读取）
    if skill.killHealMultiplier then
        player._killHealMultiplier = skill.killHealMultiplier
    end

    -- 以玩家到目标的实际角度作为技能释放方向（而非二值左右朝向）
    local targetAngle = math_atan(player.target.y - player.y, player.target.x - player.x)

    -- 目标选择（Pattern A: 主目标保底 + 主目标优先排序）
    local targets, hitCount = TargetSelector.SelectWithPrimary(player, skill, targetAngle)
    if not targets then
        player._killHealMultiplier = nil
        return false
    end

    local totalAtk = player:GetTotalAtk()
    -- 技能伤害百分比加成（装备 + 悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    -- 第一轮（立即执行）
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit, isTianzhu = HitResolver.Standard(player, m,
                math_floor(effectiveAtk * skill.damageMultiplier))

            if skill.slowPercent and skill.slowDuration and m.ApplyDebuff then
                m:ApplyDebuff("ice_slow", {
                    slowPercent = skill.slowPercent,
                    duration = skill.slowDuration,
                })
            end
            if skill.atkReducePercent and skill.atkReduceDuration and m.ApplyDebuff then
                m:ApplyDebuff("atk_weaken", {
                    atkReducePercent = skill.atkReducePercent,
                    duration = skill.atkReduceDuration,
                })
            end

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor or {255, 200, 80, 255}
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            shared.EmitSkillDamage(player, m, skill, damage, isCrit, isTianzhu, castId, {
                hitIndex = i,
                legacyText = dmgText,
                legacyColor = dmgColor,
            })
        end
    end

    local activeEnhancement = skill._activeRealmEnhancement
    local followupZone = activeEnhancement and activeEnhancement.followupGroundZone
    if followupZone and hitCount > 0 then
        local zoneX, zoneY = player.x, player.y
        if followupZone.shape == "same_as_hit_area" and skill.centerOffset then
            local offsetDist = skill.centerOffset == true and (skill.range or 1.5) or skill.centerOffset
            zoneX = player.x + math_cos(targetAngle) * offsetDist
            zoneY = player.y + math_sin(targetAngle) * offsetDist
        end
        CombatSystem.AddZone({
            x = zoneX,
            y = zoneY,
            range = skill.range or 1.5,
            duration = followupZone.duration or 3.0,
            tickInterval = followupZone.tickInterval or 0.5,
            damageSource = followupZone.damageSource,
            damageCoeff = followupZone.damageCoeff,
            usesCalcDamage = followupZone.usesCalcDamage ~= false,
            canCrit = followupZone.canCrit == true,
            isDot = true,
            source = player,
            maxTargets = skill.maxTargets or 0,
            color = skill.effectColor,
            name = activeEnhancement.name or skill.name,
            zoneVisualKey = followupZone.zoneVisualKey,
            showZoneLabel = followupZone.showZoneLabel,
            tickFlashColor = followupZone.tickFlashColor,
            effectIcon = skill.icon,
        })
    end

    -- 连击（ReplayHits + debuff 应用）
    ComboRunner.Schedule(player, skill, targetAngle, function()
        ComboRunner.ReplayHits(player, skill, targets, hitCount,
            math_floor(effectiveAtk * skill.damageMultiplier),
            function(m)
                if skill.slowPercent and skill.slowDuration and m.ApplyDebuff then
                    m:ApplyDebuff("ice_slow", {
                        slowPercent = skill.slowPercent,
                        duration = skill.slowDuration,
                    })
                end
                if skill.atkReducePercent and skill.atkReduceDuration and m.ApplyDebuff then
                    m:ApplyDebuff("atk_weaken", {
                        atkReducePercent = skill.atkReducePercent,
                        duration = skill.atkReduceDuration,
                    })
                end
            end,
            castId)
    end)

    CombatSystem.EmitLegacyOnlyFeedback({
        x = player.x, y = player.y - 0.8,
        text = skill.name, color = skill.effectColor, lifetime = 1.5,
    })

    -- 清除击杀回血乘数标记（第一轮伤害已同步处理完毕）
    player._killHealMultiplier = nil

    -- 技能范围特效（传递形状参数和实际朝向角度）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, {
        shape = skill.shape,
        coneAngle = skill.coneAngle,
        rectLength = skill.rectLength,
        rectWidth = skill.rectWidth,
        targetAngle = targetAngle,
        effectVariant = skill.effectVariant,
        swordCount = skill.swordCount,
        outerShockwaveScale = skill.outerShockwaveScale,
        outerShockwaveDelay = skill.outerShockwaveDelay,
    })

    return true
end

--- 释放吸血类技能（造成伤害+回复等量生命）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function M.CastLifestealSkill(skill, player)
    -- 必须有普攻目标才能释放
    if not player.target or not player.target.alive then return false end
    local castId = CombatSystem.NextCombatCastId(skill.id)

    -- 以玩家到目标的实际角度作为技能释放方向（而非二值左右朝向）
    local targetAngle = math_atan(player.target.y - player.y, player.target.x - player.x)

    -- 目标选择（Pattern A: 主目标保底 + 主目标优先排序）
    local targets, hitCount = TargetSelector.SelectWithPrimary(player, skill, targetAngle)
    if not targets then return false end

    local totalAtk = player:GetTotalAtk()
    -- 技能伤害百分比加成（装备 + 悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    -- 第一轮（立即执行）
    local totalHeal = 0
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit, isTianzhu = HitResolver.Standard(player, m,
                math_floor(effectiveAtk * skill.damageMultiplier))
            totalHeal = totalHeal + damage

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            shared.EmitSkillDamage(player, m, skill, damage, isCrit, isTianzhu, castId, {
                hitIndex = i,
                legacyText = dmgText,
                legacyColor = dmgColor,
            })
        end
    end

    -- 第一轮吸血回复
    if totalHeal > 0 then
        local maxHp = player:GetTotalMaxHp()
        local hpBefore = player.hp
        player.hp = math_min(maxHp, player.hp + totalHeal)
        local actualHeal = player.hp - hpBefore
        if actualHeal > 0 then
            shared.EmitHealFeedback(player, player, actualHeal, skill.name, {100, 255, 100, 255}, {
                x = player.x, y = player.y - 0.3,
                text = "+" .. actualHeal, color = {100, 255, 100, 255}, lifetime = 1.5,
            })
        end
    end

    -- 连击（ReplayHits 返回总伤害 → 吸血回复）
    ComboRunner.Schedule(player, skill, targetAngle, function()
        local comboHeal = ComboRunner.ReplayHits(player, skill, targets, hitCount,
            math_floor(effectiveAtk * skill.damageMultiplier), nil, castId)
        if comboHeal > 0 then
            local maxHp = player:GetTotalMaxHp()
            local hpBefore = player.hp
            player.hp = math_min(maxHp, player.hp + comboHeal)
            local actualHeal = player.hp - hpBefore
            if actualHeal > 0 then
                shared.EmitHealFeedback(player, player, actualHeal, skill.name, {100, 255, 100, 255}, {
                    x = player.x, y = player.y - 0.3,
                    text = "+" .. actualHeal, color = {100, 255, 100, 255}, lifetime = 1.5,
                })
            end
        end
    end)

    CombatSystem.EmitLegacyOnlyFeedback({
        x = player.x, y = player.y - 0.8,
        text = skill.name, color = skill.effectColor, lifetime = 1.5,
    })

    -- 技能范围特效（传递形状参数和实际朝向角度）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, {
        shape = skill.shape,
        coneAngle = skill.coneAngle,
        rectLength = skill.rectLength,
        rectWidth = skill.rectWidth,
        targetAngle = targetAngle,
    })

    return true
end

--- 释放治疗技能
---@param skill table
---@param player table
---@return boolean
function M.CastHealSkill(skill, player)
    -- 回复自身
    local healAmount = math_floor(player:GetTotalMaxHp() * skill.healPercent)
    local hpBefore = player.hp
    player.hp = math_min(player:GetTotalMaxHp(), player.hp + healAmount)
    local actualHeal = player.hp - hpBefore

    if actualHeal > 0 then
        shared.EmitHealFeedback(player, player, actualHeal, skill.name, skill.effectColor, {
            x = player.x, y = player.y - 0.5,
            text = "+" .. actualHeal, color = skill.effectColor, lifetime = 1.5,
        })
    end

    -- 回复宠物
    local pet = GameState.pet
    if pet and pet.alive and skill.petHealPercent then
        local petHeal = math_floor(pet.maxHp * skill.petHealPercent)
        local petHpBefore = pet.hp
        pet.hp = math_min(pet.maxHp, pet.hp + petHeal)
        local actualPetHeal = pet.hp - petHpBefore
        if actualPetHeal > 0 then
            shared.EmitHealFeedback(player, pet, actualPetHeal, skill.name, {100, 255, 150, 255}, {
                x = pet.x, y = pet.y - 0.3,
                text = "+" .. actualPetHeal, color = {100, 255, 150, 255}, lifetime = 1.2,
            })
        end
    end

    CombatSystem.EmitLegacyOnlyFeedback({
        x = player.x, y = player.y - 1.0,
        text = skill.name, color = skill.effectColor, lifetime = 1.5,
    })

    return true
end

--- 释放buff类技能
---@param skill table
---@param player table
---@return boolean
function M.CastBuffSkill(skill, player)
    local duration = skill.buffDuration or 30
    local healPercent = skill.buffHealPercent or 0

    -- 动态每秒恢复百分比（戮炎生息酿可增加）
    if healPercent > 0 then
        local ok2, WineSystem2 = pcall(require, "systems.WineSystem")
        if ok2 and WineSystem2 and WineSystem2.GetDrinkHealPerSecPercent then
            healPercent = WineSystem2.GetDrinkHealPerSecPercent()
        end
    end

    -- 通用 duration 回调（数据驱动，替代 skill.id 硬编码）
    if skill.getDuration then
        local ok, result = pcall(skill.getDuration, skill, player)
        if ok and result then
            duration = result
        elseif not ok then
            print("[SkillSystem] getDuration error for " .. skill.id .. ": " .. tostring(result))
        end
    end

    -- 添加持续回复buff到CombatSystem
    CombatSystem.AddBuff(skill.id, {
        name = skill.name,
        duration = duration,
        tickInterval = skill.buffTickInterval or 1.0,
        healPercent = healPercent,
        color = skill.effectColor or {150, 255, 200, 255},
    })

    -- 通用施放回调（数据驱动，替代 skill.id 硬编码）
    if skill.onCast then
        local ok, err = pcall(skill.onCast, skill, player, duration)
        if not ok then
            print("[SkillSystem] onCast error for " .. skill.id .. ": " .. tostring(err))
        end
    end

    -- 施法爆发特效（注册到 skillEffects，由 EffectRenderer 渲染）
    CombatSystem.AddSkillEffect(player, skill.id, 1.5, skill.effectColor, "buff", {
        duration = 1.5,
    })

    CombatSystem.EmitCombatFeedback({
        kind = "status", text = skill.name,
        target = player, targetKey = "player:self",
        sourceType = "skill", sourceId = skill.id, color = skill.effectColor,
    }, {
        x = player.x, y = player.y - 0.8,
        text = skill.name, color = skill.effectColor, lifetime = 1.5,
    })

    return true
end

--- 释放 AoE + DoT 技能（血海翻涌）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function M.CastAoeDotSkill(skill, player)
    -- 目标选择（Pattern B: 无主目标要求，按距离排序）
    local targets, hitCount = TargetSelector.SelectAoE(player, skill, 6)
    if hitCount == 0 then return false end
    local castId = CombatSystem.NextCombatCastId(skill.id)

    -- 计算朝向角度（面向当前目标，用于特效和连击）
    local targetAngle = player.facingRight and 0 or math_pi
    if player.target then
        targetAngle = math_atan(player.target.y - player.y, player.target.x - player.x)
    end

    -- 获取专属装备 tier 以查表覆盖参数
    local damageMultiplier = skill.damageMultiplier or 0.8
    local dotDamagePercent = skill.dotDamagePercent or 0.15
    local dotDuration = skill.dotDuration or 4.0

    if skill.tierScaling then
        local InventorySystem = require("systems.InventorySystem")
        local tier = InventorySystem.GetExclusiveSkillTier()
        local td = skill.tierScaling[tier]
        if td then
            damageMultiplier = td.damageMultiplier or damageMultiplier
            dotDamagePercent = td.dotDamagePercent or dotDamagePercent
            dotDuration = td.dotDuration or dotDuration
        end
    end

    local totalAtk = player:GetTotalAtk()
    -- 技能伤害百分比加成（悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    -- 第一轮（立即执行）
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit, isTianzhu = HitResolver.Standard(player, m,
                math_floor(effectiveAtk * damageMultiplier))

            local dotKey = "blood_sea_" .. (m.id or tostring(m))
            CombatSystem.activeDots[dotKey] = {
                monster = m,
                remaining = dotDuration,
                tickTimer = 0,
                dmgPerTick = math_floor(effectiveAtk * dotDamagePercent),
                effectName = "血蚀",
                source = player,
            }

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            shared.EmitSkillDamage(player, m, skill, damage, isCrit, isTianzhu, castId, {
                hitIndex = i,
                legacyText = dmgText,
                legacyColor = dmgColor,
            })
        end
    end

    -- 连击（ReplayHits + 连击刷新 DOT）
    ComboRunner.Schedule(player, skill, targetAngle, function()
        ComboRunner.ReplayHits(player, skill, targets, hitCount,
            math_floor(effectiveAtk * damageMultiplier),
            function(m)
                local dotKey = "blood_sea_" .. (m.id or tostring(m))
                CombatSystem.activeDots[dotKey] = {
                    monster = m,
                    remaining = dotDuration,
                    tickTimer = 0,
                    dmgPerTick = math_floor(effectiveAtk * dotDamagePercent),
                    effectName = "血蚀",
                    source = player,
                }
            end,
            castId)
    end)

    CombatSystem.EmitLegacyOnlyFeedback({
        x = player.x, y = player.y - 0.8,
        text = skill.name, color = skill.effectColor, lifetime = 1.5,
    })

    -- 技能特效（传递形状参数）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, {
        shape = skill.shape,
        coneAngle = skill.coneAngle,
        targetAngle = targetAngle,
    })

    return true
end

--- 释放地板区域技能（浩气领域）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function M.CastGroundZoneSkill(skill, player)
    -- 获取专属装备 tier 以查表覆盖参数
    local zoneDuration = skill.zoneDuration or 6.0
    local zoneDamagePercent = skill.zoneDamagePercent or 0.12
    local zoneHealPercent = skill.zoneHealPercent or 0.04

    if skill.tierScaling then
        local InventorySystem = require("systems.InventorySystem")
        local tier = InventorySystem.GetExclusiveSkillTier()
        local td = skill.tierScaling[tier]
        if td then
            zoneDuration = td.zoneDuration or zoneDuration
            zoneDamagePercent = td.zoneDamagePercent or zoneDamagePercent
            zoneHealPercent = td.zoneHealPercent or zoneHealPercent
        end
    end

    local totalAtk = player:GetTotalAtk()
    -- 技能伤害百分比加成（悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()

    -- 在玩家当前位置创建地板区域
    CombatSystem.AddZone({
        x = player.x,
        y = player.y,
        range = skill.range or 2.0,
        duration = zoneDuration,
        tickInterval = skill.zoneTickInterval or 1.0,
        damagePercent = zoneDamagePercent,
        healPercent = zoneHealPercent,
        atk = totalAtk * (1 + skillDmgPercent),
        maxTargets = skill.maxTargets or 0,
        color = skill.effectColor,
        name = skill.name,
    })

    CombatSystem.EmitCombatFeedback({
        kind = "status", text = skill.name,
        target = player, targetKey = "player:self",
        sourceType = "skill", sourceId = skill.id, color = skill.effectColor,
    }, {
        x = player.x, y = player.y - 0.8,
        text = skill.name, color = skill.effectColor, lifetime = 1.5,
    })

    -- 技能特效
    CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, nil)

    return true
end

--- 释放仙缘扇形 AOE 技能（龙息）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function M.CastXianyuanConeAoeSkill(skill, player)
    -- 目标选择（Pattern B: 无主目标要求，按距离排序）
    local targets, hitCount = TargetSelector.SelectAoE(player, skill, 8)
    if hitCount == 0 then return false end
    local castId = CombatSystem.NextCombatCastId(skill.id)

    -- 计算朝向角度（用于特效和连击）
    local targetAngle = player.facingRight and 0 or math_pi
    if player.target then
        targetAngle = math_atan(player.target.y - player.y, player.target.x - player.x)
    end

    -- 计算仙缘四属性之和
    local xianyuanSum = player:GetTotalWisdom()
                      + player:GetTotalFortune()
                      + player:GetTotalConstitution()
                      + player:GetTotalPhysique()

    local damageCoeff = skill.damageCoeff or 2.0
    local rawDmg = math_floor(xianyuanSum * damageCoeff)

    -- 技能伤害百分比加成（悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    rawDmg = math_floor(rawDmg * (1 + skillDmgPercent))

    -- 对命中目标造成伤害
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit, isTianzhu = HitResolver.Standard(player, m, rawDmg)

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            shared.EmitSkillDamage(player, m, skill, damage, isCrit, isTianzhu, castId, {
                hitIndex = i,
                legacyText = dmgText,
                legacyColor = dmgColor,
            })
        end
    end

    CombatSystem.EmitLegacyOnlyFeedback({
        x = player.x, y = player.y - 0.8,
        text = skill.name, color = skill.effectColor, lifetime = 1.5,
    })

    -- 技能特效（扇形）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, {
        shape = skill.shape,
        coneAngle = skill.coneAngle,
        targetAngle = targetAngle,
    })

    -- 连击（自定义回调：reselect 模式 + 仙缘公式重算）
    ComboRunner.Schedule(player, skill, targetAngle, function()
        local comboTargets, comboHitCount = TargetSelector.SelectAoE(player, skill, 8)
        if comboHitCount == 0 then return end
        local comboXianyuanSum = player:GetTotalWisdom()
                              + player:GetTotalFortune()
                              + player:GetTotalConstitution()
                              + player:GetTotalPhysique()
        local comboRaw = math_floor(comboXianyuanSum * damageCoeff)
        local comboSkillDmg = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
        comboRaw = math_floor(comboRaw * (1 + comboSkillDmg))
        for i = 1, comboHitCount do
            local m = comboTargets[i]
            if m and m.alive then
                local damage, isCrit, isTianzhu = HitResolver.Standard(player, m, comboRaw)
                local dmgText = skill.icon .. damage
                local dmgColor = skill.effectColor
                if isCrit then
                    dmgText = skill.icon .. "暴击 " .. damage
                    dmgColor = {255, 220, 50, 255}
                end
                shared.EmitSkillDamage(player, m, skill, damage, isCrit, isTianzhu, castId, {
                    hitIndex = i,
                    legacyText = dmgText,
                    legacyColor = dmgColor,
                })
            end
        end
    end)

    return true
end

--- 释放增伤区域技能（封魔大阵）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function M.CastDamageAmpZoneSkill(skill, player)
    local hpCostPercent = skill.hpCostPercent or 0.10
    local hpGuardPercent = skill.hpGuardPercent or 0.10
    local maxHp = player:GetTotalMaxHp()

    -- HP 保护：当前HP比例低于阈值时无法释放
    if player.hp / maxHp < hpGuardPercent then
        CombatSystem.EmitCombatFeedback({
            kind = "status", text = "生命不足",
            target = player, targetKey = "player:self",
            sourceType = "skill", sourceId = skill.id,
            color = {255, 80, 80, 255},
        }, {
            x = player.x, y = player.y - 0.8,
            text = "生命不足", color = {255, 80, 80, 255}, lifetime = 1.2,
        })
        return false
    end

    -- 扣除当前HP的百分比
    local hpCost = math_floor(player.hp * hpCostPercent)
    if hpCost < 1 then hpCost = 1 end
    player.hp = math_max(1, player.hp - hpCost)

    local zoneDuration = skill.zoneDuration or 10.0
    local damageBoostPercent = skill.damageBoostPercent or 0.10
    local zoneSize = skill.zoneSize or 5.0
    local zoneHalfSize = zoneSize / 2

    -- 在玩家当前位置创建增伤区域
    CombatSystem.AddZone({
        x = player.x,
        y = player.y,
        shape = "square",
        halfSize = zoneHalfSize,
        range = zoneSize / 2,  -- 5×5方阵 → 半径=2.5（用于距离判定）
        duration = zoneDuration,
        tickInterval = 1.0,
        damagePercent = 0,     -- 不造成直接伤害
        healPercent = 0,       -- 不回血
        atk = 0,
        damageBoostPercent = damageBoostPercent,  -- 增伤标记
        color = skill.effectColor,
        name = skill.name,
    })

    CombatSystem.EmitCombatFeedback({
        kind = "status", text = "-" .. hpCost .. " HP",
        target = player, targetKey = "player:self",
        sourceType = "skill", sourceId = skill.id,
        color = {200, 80, 80, 255},
    }, {
        x = player.x, y = player.y - 0.5,
        text = "-" .. hpCost .. " HP", color = {200, 80, 80, 255}, lifetime = 1.0,
    })
    CombatSystem.EmitCombatFeedback({
        kind = "status", text = skill.name,
        target = player, targetKey = "player:self",
        sourceType = "skill", sourceId = skill.id, color = skill.effectColor,
    }, {
        x = player.x, y = player.y - 0.8,
        text = skill.name, color = skill.effectColor, lifetime = 1.5,
    })

    -- 技能特效
    CombatSystem.AddSkillEffect(player, skill.id, zoneSize / 2, skill.effectColor, skill.type, nil)

    return true
end

return M
