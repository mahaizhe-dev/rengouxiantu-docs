-- ============================================================================
-- skill/casting_b.lua - 技能释放函数（下半）: melee_aoe_dot, multi_zone_heavy,
--                       hp_damage, hp_heal_damage
-- ============================================================================

local shared = require("systems.skill.shared")

local GameConfig    = shared.GameConfig
local GameState     = shared.GameState
local CombatSystem  = shared.CombatSystem
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
local math_random = shared.math_random
local math_pi     = shared.math_pi

local M = {}

--- 释放近战AOE+DOT技能（奔雷式：砸击伤害+插剑电击）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function M.CastMeleeAoeDotSkill(skill, player)
    -- 必须有普攻目标
    if not player.target or not player.target.alive then return false end

    -- 以玩家到目标的角度作为释放方向
    local targetAngle = math_atan(player.target.y - player.y, player.target.x - player.x)

    -- 目标选择（Pattern A: 主目标保底 + 身前偏移，原代码硬编码 centerOffset=range）
    local targets, hitCount = TargetSelector.Select(player, {
        range          = skill.range,
        maxTargets     = skill.maxTargets or 5,
        shape          = skill.shape,
        coneAngle      = skill.coneAngle,
        centerOffset   = true,  -- 硬编码身前偏移 = range
        requirePrimary = true,
        primaryFirst   = true,
        facingAngle    = targetAngle,
    })
    if not targets then return false end

    -- 剑阵 DOT 放置点（身前偏移 = range）
    local cx = player.x + math_cos(targetAngle) * skill.range
    local cy = player.y + math_sin(targetAngle) * skill.range

    local totalAtk = player:GetTotalAtk()
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    -- 第一轮伤害（砸击）
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit = HitResolver.Standard(player, m,
                math_floor(effectiveAtk * skill.damageMultiplier))

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 在命中点创建剑阵DOT（电磁塔）— 需要通过 SkillSystem facade 调用
    local SkillSystem = require("systems.SkillSystem")
    SkillSystem.CreateSwordFormationFromSkill(skill, player, cx, cy)

    -- 连击（ReplayHits + 额外剑阵 DOT）
    ComboRunner.Schedule(player, skill, targetAngle, function()
        ComboRunner.ReplayHits(player, skill, targets, hitCount,
            math_floor(effectiveAtk * skill.damageMultiplier))
        SkillSystem.CreateSwordFormationFromSkill(skill, player, cx, cy)
    end)

    -- 技能名浮动文字
    CombatSystem.AddFloatingText(
        player.x, player.y - 0.8,
        skill.name,
        skill.effectColor,
        1.5
    )

    -- 技能特效（复用巨剑下落特效）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, {
        shape = skill.shape,
        targetAngle = targetAngle,
    })

    return true
end

--- 多区域重击技能释放（青云·镇压等）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function M.CastMultiZoneHeavySkill(skill, player)
    -- 必须有普攻目标才能释放
    if not player.target or not player.target.alive then return false end

    -- 朝向：玩家→目标
    local targetAngle = math_atan(player.target.y - player.y, player.target.x - player.x)

    -- tierScaling 获取当前法宝阶级的倍率
    local damageMultiplier = skill.damageMultiplier or 1.5
    if skill.tierScaling then
        local InventorySystem = require("systems.InventorySystem")
        local tier = InventorySystem.GetExclusiveSkillTier()
        local td = skill.tierScaling[tier]
        if not td then
            -- 向下搜索最近的已定义阶级
            for t = tier, 3, -1 do
                if skill.tierScaling[t] then td = skill.tierScaling[t]; break end
            end
            if not td then td = skill.tierScaling[3] end
        end
        if td then
            damageMultiplier = td.damageMultiplier or damageMultiplier
        end
    end

    -- 计算 2×2 网格的 4 个区域中心坐标
    local zoneSize   = skill.zoneSize or 1.0
    local zoneOffset = skill.zoneOffset or 1.0  -- 区域起始偏移（玩家前方多远）
    local cosA = math_cos(targetAngle)
    local sinA = math_sin(targetAngle)
    -- 法线方向（垂直于朝向）
    local perpCos = -sinA
    local perpSin =  cosA

    -- 4 个区域中心：从玩家位置沿朝向偏移，排列为 2×2 网格
    local halfZone = zoneSize * 0.5
    local zoneCenters = {}
    for row = 0, 1 do
        for col = -1, 0 do  -- col: -1=左侧, 0=右侧（相对朝向）
            local fwd  = zoneOffset + halfZone + row * zoneSize
            local side = (col + 0.5) * zoneSize
            local cx = player.x + cosA * fwd + perpCos * side
            local cy = player.y + sinA * fwd + perpSin * side
            table.insert(zoneCenters, { x = cx, y = cy })
        end
    end

    -- 收集所有区域内的去重目标
    local hitSet = {}  -- monster -> true
    local hitList = {} -- ordered list
    local maxTargets = skill.maxTargets or 8

    for _, zc in ipairs(zoneCenters) do
        local halfSize = zoneSize * 0.5
        local monstersNearby = GameState.GetMonstersInRange(zc.x, zc.y, zoneSize)
        for _, m in ipairs(monstersNearby) do
            if m.alive and not hitSet[m] then
                -- 方形区域检测
                local dx = math_abs(m.x - zc.x)
                local dy = math_abs(m.y - zc.y)
                if dx <= halfSize and dy <= halfSize then
                    hitSet[m] = true
                    table.insert(hitList, m)
                end
            end
        end
    end

    -- 若普攻目标不在区域内，将其强制加入命中列表（避免自动施法频繁失败）
    if not hitSet[player.target] then
        hitSet[player.target] = true
        table.insert(hitList, player.target)
    end

    -- 限制最大目标数，普攻目标优先
    table.sort(hitList, function(a, b)
        if a == player.target then return true end
        if b == player.target then return false end
        local distA = Utils.Distance(player.x, player.y, a.x, a.y)
        local distB = Utils.Distance(player.x, player.y, b.x, b.y)
        return distA < distB
    end)
    local hitCount = math_min(#hitList, maxTargets)

    -- 重击伤害公式：(DEF + HeavyHit) × damageMultiplier × (1 + 根骨重击加成)
    local baseDmg = math_floor(player:GetTotalDef() + player:GetTotalHeavyHit())
    local heavyDmgBonus = player:GetConstitutionHeavyDmgBonus()
    if heavyDmgBonus > 0 then
        baseDmg = math_floor(baseDmg * (1 + heavyDmgBonus))
    end
    local scaledDmg = math_floor(baseDmg * damageMultiplier)

    -- 暴击判定（全体共用同一次判定）
    local isCrit
    scaledDmg, isCrit = player:ApplyCrit(scaledDmg)

    -- 对命中目标施加伤害
    local actualDmg = scaledDmg
    for i = 1, hitCount do
        local m = hitList[i]
        if m and m.alive then
            actualDmg = HitResolver.Hit(player, m, scaledDmg, { skipCalcDamage = true, skipCrit = true })
        end
    end

    -- 浮字
    local icon = skill.icon or "🏯"
    local prefix = isCrit and (icon .. "暴击 ") or (icon .. "神塔镇压 ")
    local dmgColor = isCrit and {255, 220, 50, 255} or (skill.effectColor or {80, 200, 120, 255})
    CombatSystem.AddFloatingText(player.x, player.y - 0.6, prefix .. actualDmg, dmgColor, 1.8)

    -- 技能特效（显示 4 个区域的落点效果）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range or 2.0,
        skill.effectColor or {80, 200, 120, 255}, "multi_zone_heavy", {
            zones = zoneCenters,
            zoneSize = zoneSize,
            duration = 1.2,
        })

    -- 连击（自定义回调：重击伤害重算 + 共享暴击）
    ComboRunner.Schedule(player, skill, targetAngle, function()
        local comboDmg = math_floor(player:GetTotalDef() + player:GetTotalHeavyHit())
        local comboDmgBonus = player:GetConstitutionHeavyDmgBonus()
        if comboDmgBonus > 0 then
            comboDmg = math_floor(comboDmg * (1 + comboDmgBonus))
        end
        comboDmg = math_floor(comboDmg * damageMultiplier)
        local comboCrit
        comboDmg, comboCrit = player:ApplyCrit(comboDmg)

        for i = 1, hitCount do
            local m = hitList[i]
            if m and m.alive then
                HitResolver.Hit(player, m, comboDmg, { skipCalcDamage = true, skipCrit = true })
            end
        end
        local comboPrefix = comboCrit and (icon .. "连击暴击 ") or (icon .. "连击 ")
        local comboColor = comboCrit and {255, 220, 50, 255} or (skill.effectColor or {80, 200, 120, 255})
        CombatSystem.AddFloatingText(player.x, player.y - 0.8, comboPrefix .. comboDmg, comboColor, 1.5)
    end)

    local EventBus = shared.EventBus
    EventBus.Emit("skill_cast", skill.id, skill)
    print("[SkillSystem] 神塔镇压! " .. scaledDmg .. (isCrit and " (CRIT)" or "") .. " 命中" .. hitCount .. "个目标 (x" .. string.format("%.0f%%", damageMultiplier * 100) .. ")")
    return true
end

--- hp_damage: 消耗自身 HP，以最大生命为基础造成范围伤害
---@param skill table
---@param player table
---@return boolean
function M.CastHpDamageSkill(skill, player)
    -- 必须有目标
    if not player.target or not player.target.alive then return false end

    local maxHp = player:GetTotalMaxHp()
    local hpCost = math_floor(maxHp * (skill.hpCost or 0))

    -- HP 不够（至少保留 1 点）
    if player.hp <= hpCost then return false end

    -- 扣血
    player.hp = math_max(1, player.hp - hpCost)

    -- 累计消耗（供血爆读取）
    if skill.feedsAccumulator then
        player._bloodAccumulator = (player._bloodAccumulator or 0) + hpCost
    end

    -- 目标选择（Pattern C: 圆形范围，有 centerOffset，无排序无形状过滤）
    local targetAngle = math_atan(player.target.y - player.y, player.target.x - player.x)
    local targets, hitCount = TargetSelector.Select(player, {
        range        = skill.range or 1.5,
        maxTargets   = skill.maxTargets or 5,
        centerOffset = skill.centerOffset,
        noSort       = true,
        facingAngle  = targetAngle,
    })

    -- 基础伤害 = maxHP × hpCoefficient
    local rawDmg = maxHp * (skill.hpCoefficient or 0.10)

    -- 技能伤害%加成
    if skill.skillDmgApplies then
        local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
        rawDmg = rawDmg * (1 + skillDmgPercent)
    end

    rawDmg = math_floor(rawDmg)

    -- 多目标技能：每个血怒效果每次施法最多叠加一层
    CombatSystem._bloodRageTriggeredThisCast = false

    -- 对每个目标造成伤害
    local firstHitMonster = nil
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit = HitResolver.Standard(player, m, rawDmg)

            if not firstHitMonster and m.alive then
                firstHitMonster = m
            end

            local dmgText = isCrit and (skill.icon .. "暴击 " .. damage) or (skill.icon .. damage)
            local dmgColor = isCrit and {255, 220, 50, 255} or (skill.effectColor or {255, 100, 50, 255})
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 清除多目标去重标记，恢复普攻上下文
    CombatSystem._bloodRageTriggeredThisCast = nil

    -- 裂山拳：保证叠加一层血怒（独立于概率触发，每次施法一层）
    if skill.guaranteedBloodRage and firstHitMonster then
        CombatSystem.AddBloodRageStack(player, firstHitMonster)
    end

    -- HP 消耗浮字
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, "-" .. hpCost .. " HP", {200, 80, 80, 200}, 1.0)

    -- 技能特效（传递偏移中心和朝向信息）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range or 1.5, skill.effectColor, "melee_aoe", {
        targetAngle = targetAngle,
        centerOffset = skill.centerOffset,
    })

    print("[SkillSystem] " .. skill.name .. ": cost " .. hpCost .. " HP, hit " .. hitCount .. " targets")
    return true
end

--- hp_heal_damage: 回复自身 HP + 以最大生命为基础造成范围伤害
---@param skill table
---@param player table
---@return boolean
function M.CastHpHealDamageSkill(skill, player)
    -- 有形状过滤（如 rect 推波）时，需要目标来确定方向
    local targetAngle
    if skill.shape then
        if not player.target or not player.target.alive then return false end
        targetAngle = math_atan(player.target.y - player.y, player.target.x - player.x)
    end

    local maxHp = player:GetTotalMaxHp()

    -- 回血
    local healAmount = math_floor(maxHp * (skill.healPercent or 0.30))
    player.hp = math_min(maxHp, player.hp + healAmount)
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, "+" .. healAmount, {80, 255, 120, 255}, 1.2)

    -- 目标选择（Pattern C: 条件形状过滤 + centerOffset，无排序）
    local targets, hitCount = TargetSelector.Select(player, {
        range        = skill.range or 1.5,
        maxTargets   = skill.maxTargets or 5,
        shape        = skill.shape,
        coneAngle    = skill.coneAngle,
        rectLength   = skill.rectLength,
        rectWidth    = skill.rectWidth,
        centerOffset = skill.centerOffset,
        noSort       = true,
        facingAngle  = targetAngle,
    })

    -- 基础伤害 = maxHP × hpCoefficient
    local rawDmg = maxHp * (skill.hpCoefficient or 0.15)

    -- 技能伤害%加成
    if skill.skillDmgApplies then
        local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
        rawDmg = rawDmg * (1 + skillDmgPercent)
    end

    rawDmg = math_floor(rawDmg)

    -- 对每个目标造成伤害
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit = HitResolver.Standard(player, m, rawDmg)

            local dmgText = isCrit and (skill.icon .. "暴击 " .. damage) or (skill.icon .. damage)
            local dmgColor = isCrit and {255, 220, 50, 255} or (skill.effectColor or {80, 220, 120, 255})
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 技能特效（传递形状参数和朝向角度）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range or 1.5, skill.effectColor, skill.shape and skill.type or "melee_aoe", skill.shape and {
        shape = skill.shape,
        coneAngle = skill.coneAngle,
        rectLength = skill.rectLength,
        rectWidth = skill.rectWidth,
        targetAngle = targetAngle,
        centerOffset = skill.centerOffset,
        duration = skill.effectDuration,
    } or nil)

    print("[SkillSystem] " .. skill.name .. ": heal " .. healAmount .. ", hit " .. hitCount .. " targets")
    return true
end

return M
