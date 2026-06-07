-- ============================================================================
-- skill/passives.lua - 被动技能实现（御剑护体、剑阵降临、龙象功、切换被动、累计触发）
-- ============================================================================

local shared = require("systems.skill.shared")

local GameConfig    = shared.GameConfig
local GameState     = shared.GameState
local CombatSystem  = shared.CombatSystem
local TargetSelector = shared.TargetSelector
local HitResolver   = shared.HitResolver
local EventBus      = shared.EventBus
local Utils         = shared.Utils

local math_floor  = shared.math_floor
local math_max    = shared.math_max
local math_min    = shared.math_min
local math_random = shared.math_random
local math_atan   = shared.math_atan
local math_cos    = shared.math_cos
local math_sin    = shared.math_sin
local math_pi     = shared.math_pi

local M = {}

-- ============================================================================
-- 御剑护体：灵剑环绕被动（sword_shield_passive）
-- ============================================================================

--- 御剑护体被动：每帧调用，管理灵剑恢复计时 + 安装受伤钩子
---@param skill table SkillData entry
---@param player table Player instance
---@param skillId string
---@param dt number 帧间隔
function M.SwordShieldPassive(skill, player, skillId, dt)
    -- 初始化御剑数据（首次调用）
    if not player._swordShield then
        player._swordShield = {
            swords = skill.maxSwords,
            maxSwords = skill.maxSwords,
            reducePercent = skill.damageReducePercent,
            recoverInterval = skill.recoverInterval,
            recoverTimer = 0,
        }
        -- 安装受伤前钩子（通过列表注册，支持多被动共存）
        player:AddPreDamageHook("sword_shield", function(self, damage, source)
            local ss = self._swordShield
            if not ss or ss.swords <= 0 then return damage end

            -- 消耗一柄剑，格挡部分伤害
            ss.swords = ss.swords - 1
            local blocked = math_floor(damage * ss.reducePercent)
            local finalDmg = math_max(1, damage - blocked)

            -- 重置恢复计时器（受击后重新开始计时）
            ss.recoverTimer = 0

            -- 浮字 + 特效
            CombatSystem.AddFloatingText(
                self.x, self.y - 1.0,
                "🔰剑挡 -" .. blocked .. " (余" .. ss.swords .. ")",
                skill.effectColor, 1.5
            )
            CombatSystem.AddSkillEffect(self, skill.id, 1.2,
                skill.effectColor, "sword_shield_passive", nil)

            print("[SwordShield] Blocked " .. blocked .. " dmg, swords left: " .. ss.swords)
            return finalDmg
        end)

        -- 首次激活浮字
        CombatSystem.AddFloatingText(
            player.x, player.y - 0.8,
            skill.icon .. skill.name .. " ×" .. skill.maxSwords,
            skill.effectColor, 2.0
        )
        print("[SkillSystem] SwordShield initialized: " .. skill.maxSwords .. " swords")
    end

    -- 灵剑恢复逻辑（只在有缺损时计时）
    local ss = player._swordShield
    if ss.swords < ss.maxSwords then
        ss.recoverTimer = ss.recoverTimer + dt
        if ss.recoverTimer >= ss.recoverInterval then
            ss.recoverTimer = ss.recoverTimer - ss.recoverInterval
            ss.swords = math_min(ss.maxSwords, ss.swords + 1)
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.8,
                "🔰剑恢复 (" .. ss.swords .. "/" .. ss.maxSwords .. ")",
                skill.effectColor, 1.2
            )
            print("[SwordShield] Sword recovered: " .. ss.swords .. "/" .. ss.maxSwords)
        end
    end
end

--- 御剑护体：释放技能时额外恢复 1 柄剑
---@param shieldSkill table 被动技能定义（sword_shield_passive）
---@param castSkillId string 释放的技能ID
---@param castSkill table 释放的技能定义
function M.SwordShieldOnSkillCast(shieldSkill, castSkillId, castSkill)
    local player = GameState.player
    if not player or not player._swordShield then return end
    if castSkill.type == "sword_shield_passive" or castSkill.type == "nth_cast_trigger" then return end
    local classId = player.classId or GameConfig.PLAYER_CLASS
    if castSkill.classId and castSkill.classId ~= classId then return end

    local ss = player._swordShield
    if ss.swords < ss.maxSwords then
        ss.swords = ss.swords + 1
        CombatSystem.AddFloatingText(
            player.x, player.y - 0.6,
            "🔰+1剑 (" .. ss.swords .. "/" .. ss.maxSwords .. ")",
            {120, 200, 255, 200}, 1.0
        )
    end
end

-- ============================================================================
-- 剑阵降临：技能/连击触发 → 在目标附近插剑（电磁塔持续电击）
-- ============================================================================

local SWORD_FORMATION_MAX      = 3     -- 最多同时存在的剑阵数
local SWORD_FORMATION_MIN_DIST = 0.8   -- 两把剑阵间最小距离（瓦片）

--- N次释放触发：累计计数，满N次触发被动效果
---@param nthSkill table 被动技能定义
---@param castSkillId string 触发源技能ID
---@param castSkill table 触发源技能定义
---@param SkillSystem table 主模块引用
function M.TryNthCastTrigger(nthSkill, castSkillId, castSkill, SkillSystem)
    local player = GameState.player
    if not player or not player.alive then return end

    -- 排除被动/事件驱动类技能
    local handler = SkillSystem.TypeHandlers[castSkill.type]
    if not handler or not handler.cast then return end

    -- per-skill 计数器
    local state = SkillSystem.GetSkillState(nthSkill.id, { counter = 0 })
    state.counter = state.counter + 1

    local triggerN = nthSkill.triggerEveryN or 8
    print("[NthCast:" .. nthSkill.id .. "] counter=" .. state.counter .. "/" .. triggerN
        .. " source=" .. castSkillId .. "(" .. (castSkill.name or "?") .. ")"
        .. " type=" .. (castSkill.type or "?"))
    if state.counter >= triggerN then
        print("[NthCast:" .. nthSkill.id .. "] >>> TRIGGERED! resetting counter")
        state.counter = 0
        M.TriggerNthCastEffect(nthSkill, player, SkillSystem)
    end
end

--- nth_cast_trigger 被动触发效果（一剑开天等）
---@param skill table nth_cast_trigger 技能定义
---@param player table Player instance
---@param SkillSystem table
function M.TriggerNthCastEffect(skill, player, SkillSystem)
    local target = player.target
    if not target or not target.alive then return end

    -- 设置击杀回血乘数
    if skill.triggerKillHealMultiplier then
        player._killHealMultiplier = skill.triggerKillHealMultiplier
    end

    local targetAngle = math_atan(target.y - player.y, target.x - player.x)

    local targets, hitCount = TargetSelector.Select(player, {
        range        = skill.triggerRange or 1.5,
        maxTargets   = skill.triggerMaxTargets or 5,
        centerOffset = skill.triggerRange or 1.5,
        primaryFirst = true,
        facingAngle  = targetAngle,
    })
    if hitCount == 0 then return end

    local totalAtk = player:GetTotalAtk()
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit = HitResolver.Standard(player, m,
                math_floor(effectiveAtk * (skill.triggerDamageMultiplier or 3.0)))

            local dmgText = "⚡" .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = "⚡暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    CombatSystem.AddFloatingText(
        player.x, player.y - 0.8,
        skill.icon .. skill.name,
        skill.effectColor, 2.0
    )

    CombatSystem.AddSkillEffect(player, skill.id, skill.triggerRange or 1.5,
        skill.effectColor, "melee_aoe", {
            targetAngle = targetAngle,
            duration = skill.triggerEffectDuration or 1.0,
        })

    player._killHealMultiplier = nil

    print("[SkillSystem] 一剑开天触发! 命中" .. hitCount .. "个目标")
end

--- 在指定位置创建剑阵DOT（电磁塔）
---@param skill table 带DOT字段的技能定义
---@param player table Player instance
---@param cx number 插剑X坐标
---@param cy number 插剑Y坐标
function M.CreateSwordFormationFromSkill(skill, player, cx, cy)
    if not player._swordFormations then
        player._swordFormations = {}
    end

    local spawnX = cx + (math_random() - 0.5) * 0.4
    local spawnY = cy + (math_random() - 0.5) * 0.4

    -- 检查是否与已有剑阵太近
    for _, sf in ipairs(player._swordFormations) do
        local dx = sf.x - spawnX
        local dy = sf.y - spawnY
        if dx * dx + dy * dy < SWORD_FORMATION_MIN_DIST * SWORD_FORMATION_MIN_DIST then
            local angle = math_random() * math_pi * 2
            spawnX = sf.x + math_cos(angle) * SWORD_FORMATION_MIN_DIST
            spawnY = sf.y + math_sin(angle) * SWORD_FORMATION_MIN_DIST
            break
        end
    end

    -- 超过上限则移除最旧的
    while #player._swordFormations >= SWORD_FORMATION_MAX do
        table.remove(player._swordFormations, 1)
    end

    local totalAtk = player:GetTotalAtk()
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)
    local rawDotDmg = math_floor(effectiveAtk * (skill.dotDamagePercent or 0.10))

    local dotDuration = skill.dotDuration or 5.0
    local dotRange = skill.dotRange or 2.0

    table.insert(player._swordFormations, {
        x = spawnX,
        y = spawnY,
        remaining = dotDuration,
        duration = dotDuration,
        tickTimer = 0,
        rawDmg = rawDotDmg,
        trueDamage = skill.dotTrueDamage or false,
        range = dotRange,
        currentTarget = nil,
        source = player,
        spawnTime = GameState.gameTime or 0,
    })

    CombatSystem.AddFloatingText(
        spawnX, spawnY - 0.8,
        "🗡️插剑",
        skill.effectColor or {80, 160, 255, 255}, 1.0
    )

    print("[SkillSystem] SwordFormation DOT placed at (" ..
        string.format("%.1f,%.1f", spawnX, spawnY) ..
        "), active=" .. #player._swordFormations)
end

--- 更新剑阵降临（电磁塔 tick），由 SkillSystem.Update 调用
---@param dt number
function M.UpdateSwordFormations(dt)
    local player = GameState.player
    if not player or not player.alive then return end
    if not player._swordFormations then return end

    local formations = player._swordFormations
    local i = 1
    while i <= #formations do
        local sf = formations[i]
        sf.remaining = sf.remaining - dt

        if sf.remaining <= 0 then
            table.remove(formations, i)
        else
            -- 寻找范围内最近的活着的敌人
            local nearest = nil
            local nearestDist = sf.range * sf.range + 1
            local monsters = GameState.GetMonstersInRange(sf.x, sf.y, sf.range)
            for j = 1, #monsters do
                local m = monsters[j]
                if m and m.alive then
                    local dx = m.x - sf.x
                    local dy = m.y - sf.y
                    local d2 = dx * dx + dy * dy
                    if d2 < nearestDist then
                        nearestDist = d2
                        nearest = m
                    end
                end
            end

            sf.currentTarget = nearest

            -- 每秒 tick 一次伤害
            if nearest then
                sf.tickTimer = sf.tickTimer + dt
                if sf.tickTimer >= 1.0 then
                    sf.tickTimer = sf.tickTimer - 1.0
                    local tickDmg
                    if sf.trueDamage then
                        tickDmg = sf.rawDmg
                    else
                        tickDmg = GameConfig.CalcDamage(sf.rawDmg, nearest.def)
                    end
                    tickDmg = math_max(1, tickDmg)
                    local isCrit = false
                    if sf.source and sf.source.ApplyCrit then
                        tickDmg, isCrit = sf.source:ApplyCrit(tickDmg)
                    end
                    tickDmg = nearest:TakeDamage(tickDmg, sf.source)
                    local dmgText = tickDmg .. " ⚡"
                    local dmgColor = {150, 200, 255, 255}
                    if isCrit then
                        dmgText = tickDmg .. " ⚡💥"
                        dmgColor = {255, 200, 50, 255}
                    end
                    CombatSystem.AddFloatingText(
                        nearest.x, nearest.y - 0.4,
                        dmgText,
                        dmgColor, 0.6
                    )
                end
            end

            i = i + 1
        end
    end
end

-- ============================================================================
-- charge_passive 通用：叠层 + 满层释放
-- ============================================================================

--- charge_passive 叠层
---@param skill table 被动技能定义
---@param count number 叠加层数（普攻1，重击2）
---@param SkillSystem table
function M.ChargePassiveAddStacks(skill, count, SkillSystem)
    local maxStacks = skill.maxStacks or 10
    local state = SkillSystem.GetSkillState(skill.id, { stacks = 0 })
    state.stacks = state.stacks + count

    if state.stacks >= maxStacks then
        state.stacks = 0
        M.TriggerChargePassiveRelease(skill)
    end
end

--- charge_passive 满层释放效果（龙象功震地等）
---@param skill table charge_passive 技能定义
function M.TriggerChargePassiveRelease(skill)
    local player = GameState.player
    if not player or not player.alive then return end

    local heavyDmg = math_floor(player:GetTotalDef() + player:GetTotalHeavyHit())
    local heavyDmgBonus = player:GetConstitutionHeavyDmgBonus()
    if heavyDmgBonus > 0 then
        heavyDmg = math_floor(heavyDmg * (1 + heavyDmgBonus))
    end

    local isCrit
    heavyDmg, isCrit = player:ApplyCrit(heavyDmg)

    local targets, hitCount = TargetSelector.SelectCircle(
        player.x, player.y, skill.aoeRange or 1.5, skill.maxTargets or 8
    )

    local actualHeavyDmg = heavyDmg
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            actualHeavyDmg = HitResolver.Hit(player, m, heavyDmg, { skipCalcDamage = true, skipCrit = true })
        end
    end

    local prefix = isCrit and "🐘震地暴击 " or "🐘震地 "
    local color = isCrit and {255, 220, 50, 255} or skill.effectColor
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, prefix .. actualHeavyDmg, color, 2.0)

    CombatSystem.AddSkillEffect(player, skill.id, skill.aoeRange or 1.5,
        skill.effectColor, "charge_passive", nil)

    EventBus.Emit("skill_cast", skill.id, skill)
    print("[SkillSystem] 龙象功震地! " .. heavyDmg .. (isCrit and " (CRIT)" or "") .. " 命中" .. hitCount .. "个目标")
end

-- ============================================================================
-- toggle_passive + accumulate_trigger
-- ============================================================================

--- toggle_passive: 每帧 tick
---@param skill table
---@param player table
---@param skillId string
---@param dt number
---@param SkillSystem table
function M.TogglePassiveTick(skill, player, skillId, dt, SkillSystem)
    local state = SkillSystem.GetSkillState(skillId, { active = skill.defaultActive or false })

    if not state.active then return end

    -- 首次 tick 时触发 onActivate
    if not state._activated then
        state._activated = true
        if skill.onActivate then skill.onActivate(skill, player) end
    end

    -- 血量不足自动关闭
    if skill.burnInterval then
        local maxHp = player:GetTotalMaxHp()
        if player.hp <= maxHp * 0.05 then
            state.active = false
            state._activated = false
            if skill.onDeactivate then skill.onDeactivate(skill, player) end
            CombatSystem.AddFloatingText(player.x, player.y - 0.8, skill.icon .. "气血不足 自动关闭", {255, 150, 50, 255}, 1.5)
            print("[SkillSystem] " .. skill.name .. " auto-off: HP too low")
            return
        end
    end

    -- 调用数据驱动的 onTick 回调
    if skill.onTick then
        local tickOk, tickDmg = pcall(skill.onTick, skill, player, skillId, dt, state)
        if not tickOk then
            print("[SkillSystem] onTick pcall error skill=" .. tostring(skillId) .. ": " .. tostring(tickDmg))
            return
        end

        -- NaN 防护
        if tickDmg and tickDmg ~= tickDmg then
            print("[SkillSystem] onTick returned NaN for skill=" .. tostring(skillId) .. ", skipping AoE")
            return
        end

        -- AoE 真实伤害
        if tickDmg and tickDmg > 0 and skill.aoeRange then
            local targets = GameState.GetMonstersInRange(player.x, player.y, skill.aoeRange)
            local aoeDmg = math_floor(tickDmg)
            if aoeDmg > 0 then
                for _, m in ipairs(targets) do
                    if m and m.alive then
                        local finalDmg, isCrit = HitResolver.Hit(player, m, aoeDmg, {
                            skipCalcDamage = true,
                            conditionalCrit = true, canCrit = skill.canCrit,
                            pcallTakeDamage = true, isDot = true,
                        })
                        local textScale = isCrit and 1.6 or 1.2
                        local critColor = isCrit and {255, 200, 0, 255} or skill.effectColor
                        CombatSystem.AddFloatingText(m.x, m.y - 0.3, tostring(finalDmg), critColor, textScale)
                    end
                end
            end
        end
    end
end

--- toggle_passive 的切换函数
---@param skillId string
---@param SkillSystem table
function M.TogglePassiveSkill(skillId, SkillSystem)
    local SkillData = shared.SkillData
    local skill = SkillData.Skills[skillId]
    if not skill then return end

    local state = SkillSystem.GetSkillState(skillId, { active = skill.defaultActive or false })
    state.active = not state.active

    local player = GameState.player
    if player then
        if state.active then
            state._activated = true
            if skill.onActivate then skill.onActivate(skill, player) end
            CombatSystem.AddFloatingText(player.x, player.y - 0.8, skill.icon .. skill.name .. " 开启", skill.effectColor or {255, 100, 50, 255}, 1.5)
        else
            state._activated = false
            if skill.onDeactivate then skill.onDeactivate(skill, player) end
            CombatSystem.AddFloatingText(player.x, player.y - 0.8, skill.icon .. skill.name .. " 关闭", {150, 150, 150, 255}, 1.5)
        end
    end

    print("[SkillSystem] Toggle " .. skill.name .. ": " .. (state.active and "ON" or "OFF"))
end

--- accumulate_trigger: 累计触发被动
---@param skill table
---@param player table
---@param skillId string
---@param dt number
function M.AccumulateTriggerTick(skill, player, skillId, dt)
    local field = skill.accumulatorField
    if not field then return end

    local accumulated = player[field] or 0
    local maxHp = player:GetTotalMaxHp()
    local threshold = maxHp * (skill.threshold or 1.0)

    if accumulated < threshold then return end

    -- 达到阈值：先检查范围内是否有目标，没有则等待
    local targets = GameState.GetMonstersInRange(player.x, player.y, skill.aoeRange or 2)
    local hitCount = math_min(#targets, skill.maxTargets or 5)
    if hitCount == 0 then return end

    -- 有目标，引爆！重置累计器
    player[field] = 0

    local baseDmg = math_floor(maxHp * (skill.damagePercent or 0.10))

    -- 血怒值加成
    if skill.useBloodRageValue then
        local bloodRageValue = player:GetPhysiqueBloodRageValue() or 0
        baseDmg = math_floor(baseDmg * (1 + bloodRageValue))
    end

    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit = HitResolver.Hit(player, m, baseDmg, {
                skipCalcDamage = true, pcallTakeDamage = true,
            })

            local dmgText = isCrit and (skill.icon .. "血神暴击 " .. damage) or (skill.icon .. "血神 " .. damage)
            local dmgColor = isCrit and {255, 220, 50, 255} or (skill.effectColor or {180, 20, 20, 255})
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.8)
        end
    end

    local shapeData = skill.effectDuration and { duration = skill.effectDuration } or nil
    CombatSystem.AddSkillEffect(player, skill.id, skill.aoeRange or 2, skill.effectColor, "melee_aoe", shapeData)
    CombatSystem.AddFloatingText(player.x, player.y - 1.0, skill.icon .. skill.name .. "!", skill.effectColor or {180, 20, 20, 255}, 2.0)

    print("[SkillSystem] " .. skill.name .. " triggered! baseDmg=" .. baseDmg .. " hit " .. hitCount .. " targets")
end

return M
