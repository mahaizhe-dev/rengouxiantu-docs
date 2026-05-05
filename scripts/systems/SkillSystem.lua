-- ============================================================================
-- SkillSystem.lua - 技能系统（解锁、释放、冷却管理）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local SkillData = require("config.SkillData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local CombatSystem = require("systems.CombatSystem")

local SkillSystem = {}

-- ── 技能类型处理器注册表 ──
-- 结构: { [typeName] = { cast = function(skill, player) -> bool, passive = function(skill, player)? } }
SkillSystem.TypeHandlers = {}

--- 注册技能类型处理器
---@param typeName string 技能类型标识（对应 SkillData 中的 type 字段）
---@param handler table { cast?: fun(skill, player): boolean, passive?: fun(skill, player) }
function SkillSystem.RegisterType(typeName, handler)
    SkillSystem.TypeHandlers[typeName] = handler
end

-- ── 复用缓冲区：AutoCast 就绪技能列表 ──
local _readySkillsBuf = {}

-- 已解锁技能列表
SkillSystem.unlockedSkills = {}

-- 技能冷却计时器 { skillId = remainingCD }
SkillSystem.cooldowns = {}

-- 技能栏（最多4个已装备技能ID）
SkillSystem.equippedSkills = {}

-- 连击延迟队列 { { delay, elapsed, execute } }
SkillSystem.pendingCombos = {}

-- 连击延迟时间（秒）
local COMBO_DELAY = 0.5

-- 被动技能状态（per-skill，按 skill.id 索引）
-- 例: skillState["sword_formation"] = { counter = 0 }
--     skillState["dragon_elephant"] = { stacks = 0 }
SkillSystem.skillState = {}

--- 查找所有已解锁的指定类型技能
---@param typeName string 技能类型
---@return table[] 匹配的技能定义列表
function SkillSystem.FindUnlockedByType(typeName)
    local results = {}
    for skillId, unlocked in pairs(SkillSystem.unlockedSkills) do
        if unlocked then
            local skill = SkillData.Skills[skillId]
            if skill and skill.type == typeName then
                table.insert(results, skill)
            end
        end
    end
    return results
end

--- 获取或初始化指定技能的状态
---@param skillId string
---@param defaults table 默认值（首次访问时使用）
---@return table
function SkillSystem.GetSkillState(skillId, defaults)
    if not SkillSystem.skillState[skillId] then
        SkillSystem.skillState[skillId] = defaults or {}
    end
    return SkillSystem.skillState[skillId]
end

--- 连击统一入口：判定概率 → 调度延迟执行（含预告浮字 + 重播特效）
--- 所有主动技能只需在命中逻辑末尾调用此函数，不需要自行判定概率或调用 AddPendingCombo。
---@param player table 玩家实体
---@param skill table 技能定义（SkillData entry）
---@param targetAngle number 技能朝向角度
---@param comboHitFn function 连击第二轮的伤害逻辑闭包
function SkillSystem.TryCombo(player, skill, targetAngle, comboHitFn)
    local comboChance = player:GetSkillComboChance()
    if comboChance <= 0 then return end
    if math.random() >= comboChance then return end

    -- 预告浮字
    CombatSystem.AddFloatingText(player.x, player.y - 1.0, "连击!", {255, 100, 255, 255}, 0.8)

    -- 加入延迟队列
    table.insert(SkillSystem.pendingCombos, {
        delay = COMBO_DELAY,
        elapsed = 0,
        execute = function()
            comboHitFn()
            -- 重播技能特效
            CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, {
                shape = skill.shape,
                coneAngle = skill.coneAngle,
                rectLength = skill.rectLength,
                rectWidth = skill.rectWidth,
                targetAngle = targetAngle,
            })
            -- 连击也计入技能释放次数（触发 nth_cast_trigger 等被动）
            EventBus.Emit("skill_cast", skill.id, skill)
        end,
    })
end

--- 初始化技能系统
function SkillSystem.Init()
    SkillSystem.unlockedSkills = {}
    SkillSystem.cooldowns = {}
    SkillSystem.equippedSkills = {}
    SkillSystem.pendingCombos = {}
    SkillSystem.skillState = {}

    -- 监听升级/境界突破事件，检查新技能解锁
    EventBus.On("player_levelup", function(level)
        SkillSystem.CheckUnlocks()
    end)
    EventBus.On("realm_breakthrough", function(oldRealm, newRealm)
        SkillSystem.CheckUnlocks()
    end)

    -- 通用被动事件驱动（按 TypeHandler 分发，不依赖具体职业/技能ID）
    EventBus.On("player_normal_hit", function(player, monster)
        SkillSystem.HandleChargePassiveHit(1)
    end)
    EventBus.On("player_heavy_hit", function(player, monster)
        SkillSystem.HandleChargePassiveHit(2)
    end)
    EventBus.On("skill_cast", function(skillId, skill)
        SkillSystem.HandleSkillCastPassives(skillId, skill)
    end)

    -- 初始检查
    SkillSystem.CheckUnlocks()

    print("[SkillSystem] Initialized")
end

--- 通用：普攻/重击事件 → 分发给所有已解锁的 charge_passive 技能
---@param hitCount number 叠加层数（普攻1，重击2）
function SkillSystem.HandleChargePassiveHit(hitCount)
    local skills = SkillSystem.FindUnlockedByType("charge_passive")
    for _, skill in ipairs(skills) do
        SkillSystem.ChargePassiveAddStacks(skill, hitCount)
    end
end

--- 通用：skill_cast 事件 → 分发给需要响应的被动技能
---@param skillId string 触发源技能ID
---@param skill table 触发源技能定义
function SkillSystem.HandleSkillCastPassives(skillId, skill)
    -- 1. 御剑类被动：释放技能时恢复资源（sword_shield_passive）
    local shieldSkills = SkillSystem.FindUnlockedByType("sword_shield_passive")
    for _, shieldSkill in ipairs(shieldSkills) do
        SkillSystem.SwordShieldOnSkillCast(shieldSkill, skillId, skill)
    end

    -- 2. N次释放触发类被动（nth_cast_trigger）
    local nthSkills = SkillSystem.FindUnlockedByType("nth_cast_trigger")
    for _, nthSkill in ipairs(nthSkills) do
        SkillSystem.TryNthCastTrigger(nthSkill, skillId, skill)
    end
end

--- 检查并解锁可用技能（按当前职业的解锁列表）
function SkillSystem.CheckUnlocks()
    local player = GameState.player
    if not player then return end

    -- 获取当前职业的解锁列表
    local classId = player.classId or GameConfig.PLAYER_CLASS
    local unlockList = SkillData.UnlockOrder[classId]
    if not unlockList then return end

    for _, skillId in ipairs(unlockList) do
        local skill = SkillData.Skills[skillId]
        if skill and not SkillSystem.unlockedSkills[skillId] then
            -- 职业匹配检查（有 classId 的技能必须匹配当前职业）
            if skill.classId and skill.classId ~= classId then
                goto continue
            end

            -- 检查等级和境界
            local levelOk = player.level >= skill.unlockLevel
            local realmOk = true
            if skill.unlockRealm then
                local reqRealm = GameConfig.REALMS[skill.unlockRealm]
                local curRealm = GameConfig.REALMS[player.realm]
                local reqOrder = reqRealm and reqRealm.order or 0
                local curOrder = curRealm and curRealm.order or 0
                realmOk = curOrder >= reqOrder
            end

            if levelOk and realmOk then
                SkillSystem.unlockedSkills[skillId] = true
                -- 自动装备到技能栏空位（槽1-3，槽4保留给装备技能）
                local slotCount = 0
                for si = 1, 3 do
                    if SkillSystem.equippedSkills[si] then slotCount = slotCount + 1 end
                end
                if slotCount < 3 then
                    -- 找到第一个空的槽位(1-3)
                    for si = 1, 3 do
                        if not SkillSystem.equippedSkills[si] then
                            SkillSystem.equippedSkills[si] = skillId
                            break
                        end
                    end
                end
                EventBus.Emit("skill_unlocked", skillId, skill)
                print("[SkillSystem] Unlocked: " .. skill.name .. " (" .. skill.icon .. ")")
            end

            ::continue::
        end
    end
end

--- 更新技能冷却 + 被动技能检测
---@param dt number
function SkillSystem.Update(dt)
    -- 冷却倒计时
    for skillId, remaining in pairs(SkillSystem.cooldowns) do
        remaining = remaining - dt
        if remaining <= 0 then
            SkillSystem.cooldowns[skillId] = nil
            -- 通用 CD 结束回调（数据驱动，替代 skill.id 硬编码）
            local skill = SkillData.Skills[skillId]
            if skill and skill.onCDReady then
                local ok, err = pcall(skill.onCDReady, skill, GameState.player)
                if not ok then
                    print("[SkillSystem] onCDReady error for " .. skillId .. ": " .. tostring(err))
                end
            end
        else
            SkillSystem.cooldowns[skillId] = remaining
        end
    end

    -- 护盾持续时间倒计时
    local player = GameState.player
    if player and player.shieldHp and player.shieldHp > 0 then
        player.shieldTimer = (player.shieldTimer or 0) - dt
        if player.shieldTimer <= 0 then
            player.shieldHp = 0
            player.shieldMaxHp = 0
            player.shieldTimer = 0
            EventBus.Emit("shield_expired")
        end
    end

    -- 被动技能触发检测（传入 dt 供御剑护体等被动使用）
    if player and player.alive then
        SkillSystem.CheckPassiveTriggers(player, dt)
    end

    -- 更新剑阵降临（电磁塔 tick）
    SkillSystem.UpdateSwordFormations(dt)

    -- 更新连击延迟队列
    local combos = SkillSystem.pendingCombos
    local cj = 1
    for ci = 1, #combos do
        local c = combos[ci]
        c.elapsed = c.elapsed + dt
        if c.elapsed >= c.delay then
            -- 玩家死亡时取消连击
            local p = GameState.player
            if p and p.alive then
                c.execute()
            end
        else
            combos[cj] = c
            cj = cj + 1
        end
    end
    for ci = cj, #combos do combos[ci] = nil end
end

--- 检测被动技能触发（遍历所有已解锁技能，调用注册的 passive 回调）
---@param player table
---@param dt number 帧间隔（供御剑护体等需要计时的被动使用）
function SkillSystem.CheckPassiveTriggers(player, dt)
    for skillId, _ in pairs(SkillSystem.unlockedSkills) do
        if not SkillSystem.cooldowns[skillId] then
            local skill = SkillData.Skills[skillId]
            if skill then
                local handler = SkillSystem.TypeHandlers[skill.type]
                if handler and handler.passive then
                    local ok, err = pcall(handler.passive, skill, player, skillId, dt)
                    if not ok then
                        print("[SkillSystem] passive pcall error skillId=" .. tostring(skillId) .. ": " .. tostring(err))
                    end
                end
            end
        end
    end
end

--- 金钟罩被动触发逻辑
---@param skill table
---@param player table
---@param skillId string
function SkillSystem.PassiveShieldTrigger(skill, player, skillId)
    -- 已有护盾时不重复触发
    if player.shieldHp and player.shieldHp > 0 then return end

    local maxHp = player:GetTotalMaxHp()
    local threshold = skill.triggerThreshold or 0.5
    if maxHp > 0 and (player.hp / maxHp) < threshold then
        -- 触发护盾
        local totalDef = player:GetTotalDef()
        local shieldValue = math.floor(totalDef * skill.shieldMultiplier)
        player.shieldHp = shieldValue
        player.shieldMaxHp = shieldValue
        player.shieldTimer = skill.shieldDuration

        -- 进入CD
        SkillSystem.cooldowns[skillId] = skill.cooldown

        -- 浮动文字
        CombatSystem.AddFloatingText(
            player.x, player.y - 0.8,
            skill.icon .. skill.name .. " +" .. shieldValue,
            skill.effectColor,
            1.8
        )

        -- 触发瞬间的钟形特效
        CombatSystem.AddSkillEffect(player, skill.id, 1.5, skill.effectColor, "passive", nil)

        EventBus.Emit("skill_cast", skillId, skill)
        EventBus.Emit("shield_activated", shieldValue, skill.shieldDuration)
        print("[SkillSystem] Golden Bell triggered! Shield: " .. shieldValue)
    end
end

--- 释放技能（按技能栏索引）
---@param slotIndex number 1-4
---@return boolean success
function SkillSystem.CastBySlot(slotIndex)
    local skillId = SkillSystem.equippedSkills[slotIndex]
    if not skillId then return false end
    return SkillSystem.Cast(skillId)
end

--- 释放技能
---@param skillId string
---@return boolean success
function SkillSystem.Cast(skillId)
    local player = GameState.player
    if not player or not player.alive then return false end

    -- 检查是否解锁
    if not SkillSystem.unlockedSkills[skillId] then return false end

    -- 检查冷却
    if SkillSystem.cooldowns[skillId] then return false end

    local skill = SkillData.Skills[skillId]
    if not skill then return false end

    -- 通过注册表查找处理器
    local handler = SkillSystem.TypeHandlers[skill.type]
    if not handler or not handler.cast then return false end

    -- 执行技能效果
    local success = handler.cast(skill, player)

    if success then
        -- 进入冷却
        SkillSystem.cooldowns[skillId] = skill.cooldown
        EventBus.Emit("skill_cast", skillId, skill)
        print("[SkillSystem] Cast: " .. skill.name)
    end

    return success
end

--- 按形状过滤目标
---@param targets table[] 预筛目标列表
---@param skill table SkillData entry
---@param player table Player instance
---@return table[] 过滤后的目标
function SkillSystem.FilterByShape(targets, skill, player, facingAngle)
    if not skill.shape then return targets end

    -- 优先使用传入的朝向角，否则退回二值左右朝向
    facingAngle = facingAngle or (player.facingRight and 0 or math.pi)
    local filtered = {}

    if skill.shape == "cone" then
        -- 锥形过滤：检查玩家→目标角度是否在面朝方向 ±(coneAngle/2) 内
        local halfAngle = math.rad((skill.coneAngle or 90) / 2)
        for _, m in ipairs(targets) do
            local dx = m.x - player.x
            local dy = m.y - player.y
            local toTarget = math.atan(dy, dx)
            -- 角度差（归一化到 [-π, π]）
            local diff = toTarget - facingAngle
            diff = math.atan(math.sin(diff), math.cos(diff))
            if math.abs(diff) <= halfAngle then
                table.insert(filtered, m)
            end
        end

    elseif skill.shape == "rect" then
        -- 矩形过滤：以玩家为起点，面朝方向为长轴
        local length = skill.rectLength or 2.0
        local halfWidth = (skill.rectWidth or 1.0) / 2
        local cosA = math.cos(facingAngle)
        local sinA = math.sin(facingAngle)
        for _, m in ipairs(targets) do
            local dx = m.x - player.x
            local dy = m.y - player.y
            -- 投影到面朝方向的局部坐标
            local forward = dx * cosA + dy * sinA   -- 前方分量
            local lateral = -dx * sinA + dy * cosA  -- 侧向分量
            if forward >= 0 and forward <= length and math.abs(lateral) <= halfWidth then
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
function SkillSystem.CastDamageSkill(skill, player)
    -- 必须有普攻目标才能释放
    if not player.target or not player.target.alive then return false end

    -- 设置击杀回血乘数（由 GameEvents.monster_death 读取）
    if skill.killHealMultiplier then
        player._killHealMultiplier = skill.killHealMultiplier
    end

    -- 以玩家到目标的实际角度作为技能释放方向（而非二值左右朝向）
    local targetAngle = math.atan(player.target.y - player.y, player.target.x - player.x)

    -- 判定中心：有 centerOffset 的技能沿朝向偏移，其他技能以玩家为中心
    local cx, cy = player.x, player.y
    if skill.centerOffset then
        local offsetDist = skill.centerOffset == true and skill.range or skill.centerOffset
        cx = player.x + math.cos(targetAngle) * offsetDist
        cy = player.y + math.sin(targetAngle) * offsetDist
    end

    local targets = GameState.GetMonstersInRange(cx, cy, skill.range)
    -- 按形状过滤
    targets = SkillSystem.FilterByShape(targets, skill, player, targetAngle)

    -- 确保普攻目标在命中列表中，否则技能无法释放
    local primaryInRange = false
    for _, m in ipairs(targets) do
        if m == player.target then primaryInRange = true; break end
    end
    if not primaryInRange then
        player._killHealMultiplier = nil
        return false
    end

    -- 限制最大目标数
    local hitCount = math.min(#targets, skill.maxTargets or 3)

    -- 普攻目标排首位，其余按距离排序
    table.sort(targets, function(a, b)
        if a == player.target then return true end
        if b == player.target then return false end
        local distA = Utils.Distance(player.x, player.y, a.x, a.y)
        local distB = Utils.Distance(player.x, player.y, b.x, b.y)
        return distA < distB
    end)

    local totalAtk = player:GetTotalAtk()
    -- 技能伤害百分比加成（装备 + 悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    -- 第一轮（立即执行）
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = GameConfig.CalcDamage(
                math.floor(effectiveAtk * skill.damageMultiplier),
                m.def
            )
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            damage = m:TakeDamage(damage, player) or damage

            EventBus.Emit("player_deal_damage", player, m)

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
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 连击（统一入口：概率判定 + 延迟调度 + 特效重播）
    SkillSystem.TryCombo(player, skill, targetAngle, function()
        for i = 1, hitCount do
            local m = targets[i]
            if m and m.alive then
                local damage = GameConfig.CalcDamage(
                    math.floor(effectiveAtk * skill.damageMultiplier),
                    m.def
                )
                local isCrit
                damage, isCrit = player:ApplyCrit(damage)
                damage = m:TakeDamage(damage, player) or damage
                EventBus.Emit("player_deal_damage", player, m)

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

                CombatSystem.AddFloatingText(
                    m.x, m.y - 0.3,
                    skill.icon .. "连击 " .. damage,
                    {255, 100, 255, 255},
                    1.2
                )
            end
        end
    end)

    -- 技能名浮动文字
    CombatSystem.AddFloatingText(
        player.x, player.y - 0.8,
        skill.name,
        skill.effectColor,
        1.5
    )

    -- 清除击杀回血乘数标记（第一轮伤害已同步处理完毕）
    player._killHealMultiplier = nil

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

--- 释放吸血类技能（造成伤害+回复等量生命）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function SkillSystem.CastLifestealSkill(skill, player)
    -- 必须有普攻目标才能释放
    if not player.target or not player.target.alive then return false end

    local targets = GameState.GetMonstersInRange(player.x, player.y, skill.range)
    -- 以玩家到目标的实际角度作为技能释放方向（而非二值左右朝向）
    local targetAngle = math.atan(player.target.y - player.y, player.target.x - player.x)
    -- 按形状过滤
    targets = SkillSystem.FilterByShape(targets, skill, player, targetAngle)

    -- 确保普攻目标在命中列表中
    local primaryInRange = false
    for _, m in ipairs(targets) do
        if m == player.target then primaryInRange = true; break end
    end
    if not primaryInRange then return false end

    local hitCount = math.min(#targets, skill.maxTargets or 3)

    -- 普攻目标排首位
    table.sort(targets, function(a, b)
        if a == player.target then return true end
        if b == player.target then return false end
        local distA = Utils.Distance(player.x, player.y, a.x, a.y)
        local distB = Utils.Distance(player.x, player.y, b.x, b.y)
        return distA < distB
    end)

    local totalAtk = player:GetTotalAtk()
    -- 技能伤害百分比加成（装备 + 悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    -- 第一轮（立即执行）
    local totalHeal = 0
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = GameConfig.CalcDamage(
                math.floor(effectiveAtk * skill.damageMultiplier),
                m.def
            )
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            damage = m:TakeDamage(damage, player) or damage
            totalHeal = totalHeal + damage

            EventBus.Emit("player_deal_damage", player, m)

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 第一轮吸血回复
    if totalHeal > 0 then
        local maxHp = player:GetTotalMaxHp()
        player.hp = math.min(maxHp, player.hp + totalHeal)
        CombatSystem.AddFloatingText(
            player.x, player.y - 0.3,
            "+" .. totalHeal,
            {100, 255, 100, 255},
            1.5
        )
    end

    -- 连击（统一入口：概率判定 + 延迟调度 + 特效重播）
    SkillSystem.TryCombo(player, skill, targetAngle, function()
        local comboHeal = 0
        for i = 1, hitCount do
            local m = targets[i]
            if m and m.alive then
                local damage = GameConfig.CalcDamage(
                    math.floor(effectiveAtk * skill.damageMultiplier),
                    m.def
                )
                local isCrit
                damage, isCrit = player:ApplyCrit(damage)
                damage = m:TakeDamage(damage, player) or damage
                comboHeal = comboHeal + damage

                EventBus.Emit("player_deal_damage", player, m)

                CombatSystem.AddFloatingText(
                    m.x, m.y - 0.3,
                    skill.icon .. "连击 " .. damage,
                    {255, 100, 255, 255},
                    1.2
                )
            end
        end
        if comboHeal > 0 then
            local maxHp = player:GetTotalMaxHp()
            player.hp = math.min(maxHp, player.hp + comboHeal)
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.3,
                "+" .. comboHeal,
                {100, 255, 100, 255},
                1.5
            )
        end
    end)

    -- 技能名浮动文字
    CombatSystem.AddFloatingText(
        player.x, player.y - 0.8,
        skill.name,
        skill.effectColor,
        1.5
    )

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
function SkillSystem.CastHealSkill(skill, player)
    -- 回复自身
    local healAmount = math.floor(player:GetTotalMaxHp() * skill.healPercent)
    player.hp = math.min(player:GetTotalMaxHp(), player.hp + healAmount)

    CombatSystem.AddFloatingText(
        player.x, player.y - 0.5,
        "+" .. healAmount,
        skill.effectColor,
        1.5
    )

    -- 回复宠物
    local pet = GameState.pet
    if pet and pet.alive and skill.petHealPercent then
        local petHeal = math.floor(pet.maxHp * skill.petHealPercent)
        pet.hp = math.min(pet.maxHp, pet.hp + petHeal)
        CombatSystem.AddFloatingText(
            pet.x, pet.y - 0.3,
            "+" .. petHeal,
            {100, 255, 150, 255},
            1.2
        )
    end

    -- 技能名
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.0,
        skill.name,
        skill.effectColor,
        1.5
    )

    return true
end

--- 释放buff类技能
---@param skill table
---@param player table
---@return boolean
function SkillSystem.CastBuffSkill(skill, player)
    local duration = skill.buffDuration or 30
    local healPercent = skill.buffHealPercent or 0

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

    -- 技能释放浮动文字
    CombatSystem.AddFloatingText(
        player.x, player.y - 0.8,
        skill.name,
        skill.effectColor,
        1.5
    )

    return true
end

--- 释放 AoE + DoT 技能（血海翻涌）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function SkillSystem.CastAoeDotSkill(skill, player)
    -- 以玩家为中心的范围攻击
    local targets = GameState.GetMonstersInRange(player.x, player.y, skill.range)
    if #targets == 0 then return false end

    -- 计算朝向角度（面向当前目标）
    local targetAngle = player.facingRight and 0 or math.pi
    if player.target then
        targetAngle = math.atan(player.target.y - player.y, player.target.x - player.x)
    end

    -- 按形状过滤（扇形等）
    targets = SkillSystem.FilterByShape(targets, skill, player, targetAngle)
    if #targets == 0 then return false end

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

    local hitCount = math.min(#targets, skill.maxTargets or 6)
    local totalAtk = player:GetTotalAtk()
    -- 技能伤害百分比加成（悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    -- 按距离排序
    table.sort(targets, function(a, b)
        local distA = Utils.Distance(player.x, player.y, a.x, a.y)
        local distB = Utils.Distance(player.x, player.y, b.x, b.y)
        return distA < distB
    end)

    -- 第一轮（立即执行）
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = GameConfig.CalcDamage(
                math.floor(effectiveAtk * damageMultiplier),
                m.def
            )
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            damage = m:TakeDamage(damage, player) or damage

            EventBus.Emit("player_deal_damage", player, m)

            local dotKey = "blood_sea_" .. (m.id or tostring(m))
            CombatSystem.activeDots[dotKey] = {
                monster = m,
                remaining = dotDuration,
                tickTimer = 0,
                dmgPerTick = math.floor(effectiveAtk * dotDamagePercent),
                effectName = "血蚀",
                source = player,
            }

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 连击（统一入口：概率判定 + 延迟调度 + 特效重播）
    SkillSystem.TryCombo(player, skill, targetAngle, function()
        for i = 1, hitCount do
            local m = targets[i]
            if m and m.alive then
                local damage = GameConfig.CalcDamage(
                    math.floor(effectiveAtk * damageMultiplier),
                    m.def
                )
                local isCrit
                damage, isCrit = player:ApplyCrit(damage)
                damage = m:TakeDamage(damage, player) or damage

                EventBus.Emit("player_deal_damage", player, m)

                -- 连击刷新 DoT 持续时间
                local dotKey = "blood_sea_" .. (m.id or tostring(m))
                CombatSystem.activeDots[dotKey] = {
                    monster = m,
                    remaining = dotDuration,
                    tickTimer = 0,
                    dmgPerTick = math.floor(effectiveAtk * dotDamagePercent),
                    effectName = "血蚀",
                    source = player,
                }

                CombatSystem.AddFloatingText(
                    m.x, m.y - 0.3,
                    skill.icon .. "连击 " .. damage,
                    {255, 100, 255, 255},
                    1.2
                )
            end
        end
    end)

    -- 技能名浮动文字
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, skill.name, skill.effectColor, 1.5)

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
function SkillSystem.CastGroundZoneSkill(skill, player)
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

    -- 技能名浮动文字
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, skill.name, skill.effectColor, 1.5)

    -- 技能特效
    CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, nil)

    return true
end

--- 释放仙缘扇形 AOE 技能（龙息）
--- 以仙缘四属性之和为伤害基础，前方扇形范围瞬间伤害，走 CalcDamage，可暴击
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function SkillSystem.CastXianyuanConeAoeSkill(skill, player)
    -- 以玩家为中心的范围攻击
    local targets = GameState.GetMonstersInRange(player.x, player.y, skill.range)
    if #targets == 0 then return false end

    -- 计算朝向角度（面向当前目标）
    local targetAngle = player.facingRight and 0 or math.pi
    if player.target then
        targetAngle = math.atan(player.target.y - player.y, player.target.x - player.x)
    end

    -- 按形状过滤（扇形 cone）
    targets = SkillSystem.FilterByShape(targets, skill, player, targetAngle)
    if #targets == 0 then return false end

    -- 计算仙缘四属性之和
    local xianyuanSum = player:GetTotalWisdom()
                      + player:GetTotalFortune()
                      + player:GetTotalConstitution()
                      + player:GetTotalPhysique()

    local damageCoeff = skill.damageCoeff or 2.0
    local rawDmg = math.floor(xianyuanSum * damageCoeff)

    -- 技能伤害百分比加成（悟性派生：每5点+1%）
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    rawDmg = math.floor(rawDmg * (1 + skillDmgPercent))

    local hitCount = math.min(#targets, skill.maxTargets or 8)

    -- 按距离排序
    table.sort(targets, function(a, b)
        local distA = Utils.Distance(player.x, player.y, a.x, a.y)
        local distB = Utils.Distance(player.x, player.y, b.x, b.y)
        return distA < distB
    end)

    -- 对命中目标造成伤害
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = GameConfig.CalcDamage(rawDmg, m.def)
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            damage = m:TakeDamage(damage, player) or damage

            EventBus.Emit("player_deal_damage", player, m)

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 技能名浮动文字
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, skill.name, skill.effectColor, 1.5)

    -- 技能特效（扇形）
    CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, {
        shape = skill.shape,
        coneAngle = skill.coneAngle,
        targetAngle = targetAngle,
    })

    -- 连击（统一入口：概率判定 + 延迟调度 + 特效重播）
    SkillSystem.TryCombo(player, skill, targetAngle, function()
        local comboTargets = GameState.GetMonstersInRange(player.x, player.y, skill.range)
        comboTargets = SkillSystem.FilterByShape(comboTargets, skill, player, targetAngle)
        local comboXianyuanSum = player:GetTotalWisdom()
                              + player:GetTotalFortune()
                              + player:GetTotalConstitution()
                              + player:GetTotalPhysique()
        local comboRaw = math.floor(comboXianyuanSum * damageCoeff)
        local comboSkillDmg = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
        comboRaw = math.floor(comboRaw * (1 + comboSkillDmg))
        local comboHitCount = math.min(#comboTargets, skill.maxTargets or 8)
        for i = 1, comboHitCount do
            local m = comboTargets[i]
            if m and m.alive then
                local damage = GameConfig.CalcDamage(comboRaw, m.def)
                local isCrit
                damage, isCrit = player:ApplyCrit(damage)
                damage = m:TakeDamage(damage, player) or damage
                EventBus.Emit("player_deal_damage", player, m)
                local dmgText = skill.icon .. damage
                local dmgColor = skill.effectColor
                if isCrit then
                    dmgText = skill.icon .. "暴击 " .. damage
                    dmgColor = {255, 220, 50, 255}
                end
                CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
            end
        end
    end)

    return true
end

--- 释放增伤区域技能（封魔大阵）
--- 消耗当前HP的一定百分比，在脚下创建一个增伤区域，阵内怪物受到最终伤害加成
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function SkillSystem.CastDamageAmpZoneSkill(skill, player)
    local hpCostPercent = skill.hpCostPercent or 0.10
    local hpGuardPercent = skill.hpGuardPercent or 0.10
    local maxHp = player:GetTotalMaxHp()

    -- HP 保护：当前HP比例低于阈值时无法释放
    if player.hp / maxHp < hpGuardPercent then
        CombatSystem.AddFloatingText(player.x, player.y - 0.8, "生命不足", {255, 80, 80, 255}, 1.2)
        return false
    end

    -- 扣除当前HP的百分比
    local hpCost = math.floor(player.hp * hpCostPercent)
    if hpCost < 1 then hpCost = 1 end
    player.hp = math.max(1, player.hp - hpCost)

    local zoneDuration = skill.zoneDuration or 10.0
    local damageBoostPercent = skill.damageBoostPercent or 0.10
    local zoneSize = skill.zoneSize or 5.0

    -- 在玩家当前位置创建增伤区域
    CombatSystem.AddZone({
        x = player.x,
        y = player.y,
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

    -- HP消耗浮动文字
    CombatSystem.AddFloatingText(player.x, player.y - 0.5, "-" .. hpCost .. " HP", {200, 80, 80, 255}, 1.0)

    -- 技能名浮动文字
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, skill.name, skill.effectColor, 1.5)

    -- 技能特效
    CombatSystem.AddSkillEffect(player, skill.id, zoneSize / 2, skill.effectColor, skill.type, nil)

    return true
end

--- 绑定法宝技能到技能栏槽5
---@param skillId string
function SkillSystem.BindEquipSkill(skillId)
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
function SkillSystem.UnbindEquipSkill(skillId)
    if SkillSystem.equippedSkills[5] == skillId then
        SkillSystem.equippedSkills[5] = nil
        SkillSystem.unlockedSkills[skillId] = nil
        -- 不清除 cooldowns：穿脱同一法宝时保留CD，防止反复穿脱刷CD
        print("[SkillSystem] Equip skill unbound from slot 5: " .. skillId)
    end
end

--- 绑定专属装备技能到技能栏槽4
---@param skillId string
function SkillSystem.BindExclusiveSkill(skillId)
    local skill = SkillData.Skills[skillId]
    if not skill then return end

    SkillSystem.unlockedSkills[skillId] = true
    SkillSystem.equippedSkills[4] = skillId

    EventBus.Emit("skill_unlocked", skillId, skill)
    print("[SkillSystem] Exclusive skill bound to slot 4: " .. skill.name)
end

--- 解绑专属装备技能（清除槽4）
---@param skillId string
function SkillSystem.UnbindExclusiveSkill(skillId)
    if SkillSystem.equippedSkills[4] == skillId then
        SkillSystem.equippedSkills[4] = nil
        SkillSystem.unlockedSkills[skillId] = nil
        print("[SkillSystem] Exclusive skill unbound from slot 4: " .. skillId)
    end
end

--- 自动释放技能（优先CD较长的技能）
---@return boolean 是否成功释放了任何技能
function SkillSystem.AutoCast()
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
---@return table[] { {skillId, skill, cdRemaining, cdTotal, unlocked} }
function SkillSystem.GetSkillBarInfo()
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
---@return number
function SkillSystem.GetCooldownRatio(skillId)
    local skill = SkillData.Skills[skillId]
    if not skill then return 0 end
    local cd = SkillSystem.cooldowns[skillId]
    if not cd then return 0 end
    return cd / skill.cooldown
end

--- 获取技能栏槽位（供存档使用）
---@return table {[1]=skillId, [2]=skillId, ...}
function SkillSystem.GetSkillBarSlots()
    local slots = {}
    -- 遍历所有槽位（不能用 # 因为中间可能有 nil）
    for i = 1, SkillData.MAX_SKILL_SLOTS do
        if SkillSystem.equippedSkills[i] then
            slots[i] = SkillSystem.equippedSkills[i]
        end
    end
    return slots
end

--- 恢复技能栏（从存档恢复）
---@param slots table
function SkillSystem.RestoreSkillBar(slots)
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

-- ============================================================================
-- 御剑护体：灵剑环绕被动（sword_shield_passive）
-- ============================================================================

--- 御剑护体被动：每帧调用，管理灵剑恢复计时 + 安装受伤钩子
---@param skill table SkillData entry
---@param player table Player instance
---@param skillId string
---@param dt number 帧间隔
function SkillSystem.SwordShieldPassive(skill, player, skillId, dt)
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
            local blocked = math.floor(damage * ss.reducePercent)
            local finalDmg = math.max(1, damage - blocked)

            -- 重置恢复计时器（受击后重新开始计时）
            ss.recoverTimer = 0

            -- 浮字 + 特效
            CombatSystem.AddFloatingText(
                self.x, self.y - 1.0,
                "🔰剑挡 -" .. blocked .. " (余" .. ss.swords .. ")",
                skill.effectColor, 1.5
            )
            -- 瞬间剑盾特效（使用 skill.id 数据驱动，不硬编码）
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
            ss.swords = math.min(ss.maxSwords, ss.swords + 1)
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
function SkillSystem.SwordShieldOnSkillCast(shieldSkill, castSkillId, castSkill)
    local player = GameState.player
    if not player or not player._swordShield then return end
    -- 自身不触发（御剑护体本身没有主动释放，但以防万一）
    if castSkill.type == "sword_shield_passive" or castSkill.type == "nth_cast_trigger" then return end
    -- 只有同职业的技能触发
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

local SWORD_FORMATION_MAX   = 3     -- 最多同时存在的剑阵数
local SWORD_FORMATION_MIN_DIST = 0.8 -- 两把剑阵间最小距离（瓦片）

--- N次释放触发：累计计数，满N次触发被动效果（数据驱动，不绑定具体技能ID）
---@param nthSkill table 被动技能定义（type="nth_cast_trigger"，由 HandleSkillCastPassives 传入）
---@param castSkillId string 触发源技能ID
---@param castSkill table 触发源技能定义
function SkillSystem.TryNthCastTrigger(nthSkill, castSkillId, castSkill)
    local player = GameState.player
    if not player or not player.alive then return end

    -- 排除被动/事件驱动类技能（不应计入主动释放次数）
    local handler = SkillSystem.TypeHandlers[castSkill.type]
    if not handler or not handler.cast then return end  -- 无 cast 的类型 = 被动/事件驱动
    -- 所有主动技能均计数（含本职业技能 + 法宝/装备技能）

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
        SkillSystem.TriggerNthCastEffect(nthSkill, player)
    end
end

--- nth_cast_trigger 被动触发效果（一剑开天等）：在目标前方释放范围伤害
---@param skill table nth_cast_trigger 技能定义
---@param player table Player instance
function SkillSystem.TriggerNthCastEffect(skill, player)
    local target = player.target
    if not target or not target.alive then return end

    -- 设置击杀回血乘数
    if skill.triggerKillHealMultiplier then
        player._killHealMultiplier = skill.triggerKillHealMultiplier
    end

    -- 以玩家到目标的角度作为巨剑释放方向
    local targetAngle = math.atan(target.y - player.y, target.x - player.x)

    -- 判定中心：身前偏移（与原巨剑一致）
    local cx = player.x + math.cos(targetAngle) * (skill.triggerRange or 1.5)
    local cy = player.y + math.sin(targetAngle) * (skill.triggerRange or 1.5)

    local targets = GameState.GetMonstersInRange(cx, cy, skill.triggerRange or 1.5)

    -- 限制最大目标数
    local hitCount = math.min(#targets, skill.triggerMaxTargets or 5)

    -- 普攻目标排首位
    table.sort(targets, function(a, b)
        if a == player.target then return true end
        if b == player.target then return false end
        local distA = Utils.Distance(player.x, player.y, a.x, a.y)
        local distB = Utils.Distance(player.x, player.y, b.x, b.y)
        return distA < distB
    end)

    local totalAtk = player:GetTotalAtk()
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = GameConfig.CalcDamage(
                math.floor(effectiveAtk * (skill.triggerDamageMultiplier or 3.0)),
                m.def
            )
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            damage = m:TakeDamage(damage, player) or damage

            EventBus.Emit("player_deal_damage", player, m)

            local dmgText = "⚡" .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = "⚡暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 浮字
    CombatSystem.AddFloatingText(
        player.x, player.y - 0.8,
        skill.icon .. skill.name,
        skill.effectColor, 2.0
    )

    -- 被动触发特效（使用 skill.id 数据驱动，不硬编码）
    CombatSystem.AddSkillEffect(player, skill.id, skill.triggerRange or 1.5,
        skill.effectColor, "melee_aoe", {
            targetAngle = targetAngle,
            duration = skill.triggerEffectDuration or 1.0,
        })

    -- 清除击杀回血乘数
    player._killHealMultiplier = nil

    -- 被动巨剑不触发连击（DPS计算中不含此项）
    -- 被动巨剑不再递归触发自身计数（type 为 nth_cast_trigger 已被过滤）

    print("[SkillSystem] 一剑开天触发! 命中" .. hitCount .. "个目标")
end

--- 在指定位置创建剑阵DOT（电磁塔），由技能的DOT字段驱动
---@param skill table 带DOT字段的技能定义
---@param player table Player instance
---@param cx number 插剑X坐标
---@param cy number 插剑Y坐标
function SkillSystem.CreateSwordFormationFromSkill(skill, player, cx, cy)
    if not player._swordFormations then
        player._swordFormations = {}
    end

    -- 计算插剑位置：在命中点附近，带小随机偏移
    local spawnX = cx + (math.random() - 0.5) * 0.4
    local spawnY = cy + (math.random() - 0.5) * 0.4

    -- 检查是否与已有剑阵太近
    for _, sf in ipairs(player._swordFormations) do
        local dx = sf.x - spawnX
        local dy = sf.y - spawnY
        if dx * dx + dy * dy < SWORD_FORMATION_MIN_DIST * SWORD_FORMATION_MIN_DIST then
            local angle = math.random() * math.pi * 2
            spawnX = sf.x + math.cos(angle) * SWORD_FORMATION_MIN_DIST
            spawnY = sf.y + math.sin(angle) * SWORD_FORMATION_MIN_DIST
            break
        end
    end

    -- 超过上限则移除最旧的
    while #player._swordFormations >= SWORD_FORMATION_MAX do
        table.remove(player._swordFormations, 1)
    end

    -- 计算每跳伤害
    local totalAtk = player:GetTotalAtk()
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)
    local rawDotDmg = math.floor(effectiveAtk * (skill.dotDamagePercent or 0.10))

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

    -- 浮字
    CombatSystem.AddFloatingText(
        spawnX, spawnY - 0.8,
        "🗡️插剑",
        skill.effectColor or {80, 160, 255, 255}, 1.0
    )

    print("[SkillSystem] SwordFormation DOT placed at (" ..
        string.format("%.1f,%.1f", spawnX, spawnY) ..
        "), active=" .. #player._swordFormations)
end

--- 释放近战AOE+DOT技能（奔雷式：砸击伤害+插剑电击）
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function SkillSystem.CastMeleeAoeDotSkill(skill, player)
    -- 必须有普攻目标
    if not player.target or not player.target.alive then return false end

    -- 以玩家到目标的角度作为释放方向
    local targetAngle = math.atan(player.target.y - player.y, player.target.x - player.x)

    -- 判定中心：身前偏移（与原巨剑一致）
    local cx = player.x + math.cos(targetAngle) * skill.range
    local cy = player.y + math.sin(targetAngle) * skill.range

    local targets = GameState.GetMonstersInRange(cx, cy, skill.range)
    targets = SkillSystem.FilterByShape(targets, skill, player, targetAngle)

    -- 确保普攻目标在命中列表中
    local primaryInRange = false
    for _, m in ipairs(targets) do
        if m == player.target then primaryInRange = true; break end
    end
    if not primaryInRange then return false end

    local hitCount = math.min(#targets, skill.maxTargets or 5)

    -- 普攻目标排首位
    table.sort(targets, function(a, b)
        if a == player.target then return true end
        if b == player.target then return false end
        local distA = Utils.Distance(player.x, player.y, a.x, a.y)
        local distB = Utils.Distance(player.x, player.y, b.x, b.y)
        return distA < distB
    end)

    local totalAtk = player:GetTotalAtk()
    local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
    local effectiveAtk = totalAtk * (1 + skillDmgPercent)

    -- 第一轮伤害（砸击）
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = GameConfig.CalcDamage(
                math.floor(effectiveAtk * skill.damageMultiplier),
                m.def
            )
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            damage = m:TakeDamage(damage, player) or damage

            EventBus.Emit("player_deal_damage", player, m)

            local dmgText = skill.icon .. damage
            local dmgColor = skill.effectColor
            if isCrit then
                dmgText = skill.icon .. "暴击 " .. damage
                dmgColor = {255, 220, 50, 255}
            end
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.2)
        end
    end

    -- 在命中点创建剑阵DOT（电磁塔）
    SkillSystem.CreateSwordFormationFromSkill(skill, player, cx, cy)

    -- 连击（统一入口）
    SkillSystem.TryCombo(player, skill, targetAngle, function()
        for i = 1, hitCount do
            local m = targets[i]
            if m and m.alive then
                local damage = GameConfig.CalcDamage(
                    math.floor(effectiveAtk * skill.damageMultiplier),
                    m.def
                )
                local isCrit
                damage, isCrit = player:ApplyCrit(damage)
                damage = m:TakeDamage(damage, player) or damage
                EventBus.Emit("player_deal_damage", player, m)

                CombatSystem.AddFloatingText(
                    m.x, m.y - 0.3,
                    skill.icon .. "连击 " .. damage,
                    {255, 100, 255, 255},
                    1.2
                )
            end
        end
        -- 连击也插剑（额外DOT）
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

--- 更新剑阵降临（电磁塔 tick），由 SkillSystem.Update 调用
---@param dt number
function SkillSystem.UpdateSwordFormations(dt)
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
                        -- 真实伤害：无视防御，直接使用原始伤害值
                        tickDmg = sf.rawDmg
                    else
                        tickDmg = GameConfig.CalcDamage(sf.rawDmg, nearest.def)
                    end
                    tickDmg = math.max(1, tickDmg)
                    -- 独立判暴击
                    local isCrit = false
                    if sf.source and sf.source.ApplyCrit then
                        tickDmg, isCrit = sf.source:ApplyCrit(tickDmg)
                    end
                    tickDmg = nearest:TakeDamage(tickDmg, sf.source) or tickDmg
                    local dmgText = tickDmg .. " ⚡"
                    local dmgColor = {150, 200, 255, 255}
                    if isCrit then
                        dmgText = tickDmg .. " ⚡💥"
                        dmgColor = {255, 200, 50, 255}  -- 暴击金色
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
-- charge_passive 通用：叠层 + 满层释放（数据驱动，不绑定具体技能ID）
-- ============================================================================

--- charge_passive 叠层（由 HandleChargePassiveHit 分发调用）
---@param skill table 被动技能定义（type="charge_passive"）
---@param count number 叠加层数（普攻1，重击2）
function SkillSystem.ChargePassiveAddStacks(skill, count)
    local maxStacks = skill.maxStacks or 10
    local state = SkillSystem.GetSkillState(skill.id, { stacks = 0 })
    state.stacks = state.stacks + count

    if state.stacks >= maxStacks then
        state.stacks = 0
        SkillSystem.TriggerChargePassiveRelease(skill)
    end
end

--- charge_passive 满层释放效果（龙象功震地等）
---@param skill table charge_passive 技能定义
function SkillSystem.TriggerChargePassiveRelease(skill)
    local player = GameState.player
    if not player or not player.alive then return end

    -- 伤害 = 1倍重击公式：(ATK + HeavyHit) × (1 + 根骨重击加成)
    local heavyDmg = math.floor(player:GetTotalAtk() + player:GetTotalHeavyHit())
    local heavyDmgBonus = player:GetConstitutionHeavyDmgBonus()
    if heavyDmgBonus > 0 then
        heavyDmg = math.floor(heavyDmg * (1 + heavyDmgBonus))
    end

    -- 暴击判定
    local isCrit
    heavyDmg, isCrit = player:ApplyCrit(heavyDmg)

    -- AoE 真实伤害（不走 CalcDamage）
    local targets = GameState.GetMonstersInRange(player.x, player.y, skill.aoeRange or 1.5)
    local hitCount = math.min(#targets, skill.maxTargets or 8)

    local actualHeavyDmg = heavyDmg
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            actualHeavyDmg = m:TakeDamage(heavyDmg, player) or heavyDmg
            EventBus.Emit("player_deal_damage", player, m)
        end
    end

    -- 浮字
    local prefix = isCrit and "🐘震地暴击 " or "🐘震地 "
    local color = isCrit and {255, 220, 50, 255} or skill.effectColor
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, prefix .. actualHeavyDmg, color, 2.0)

    -- 技能特效（大象 + 地裂，由 EffectRenderer 渲染）
    CombatSystem.AddSkillEffect(player, skill.id, skill.aoeRange or 1.5,
        skill.effectColor, "charge_passive", nil)

    EventBus.Emit("skill_cast", skill.id, skill)
    print("[SkillSystem] 龙象功震地! " .. heavyDmg .. (isCrit and " (CRIT)" or "") .. " 命中" .. hitCount .. "个目标")
end

-- ============================================================================
-- multi_zone_heavy：多区域重击技能（青云·镇压等）
-- ============================================================================

--- 多区域重击技能释放
--- 在玩家面前生成 2×2 网格方形区域，每个区域独立检测目标，
--- 使用重击伤害公式（ATK + HeavyHit，无视防御），受根骨加成，可暴击
---@param skill table SkillData entry
---@param player table Player instance
---@return boolean
function SkillSystem.CastMultiZoneHeavySkill(skill, player)
    -- 必须有普攻目标才能释放
    if not player.target or not player.target.alive then return false end

    -- 朝向：玩家→目标
    local targetAngle = math.atan(player.target.y - player.y, player.target.x - player.x)

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
    local cosA = math.cos(targetAngle)
    local sinA = math.sin(targetAngle)
    -- 法线方向（垂直于朝向）
    local perpCos = -sinA
    local perpSin =  cosA

    -- 4 个区域中心：从玩家位置沿朝向偏移，排列为 2×2 网格
    -- 行方向 = 朝向（forward），列方向 = 垂直（perp）
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
                local dx = math.abs(m.x - zc.x)
                local dy = math.abs(m.y - zc.y)
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
    local hitCount = math.min(#hitList, maxTargets)

    -- 重击伤害公式：(ATK + HeavyHit) × damageMultiplier × (1 + 根骨重击加成)
    -- 无视防御，直接 TakeDamage
    local baseDmg = math.floor(player:GetTotalAtk() + player:GetTotalHeavyHit())
    local heavyDmgBonus = player:GetConstitutionHeavyDmgBonus()
    if heavyDmgBonus > 0 then
        baseDmg = math.floor(baseDmg * (1 + heavyDmgBonus))
    end
    local scaledDmg = math.floor(baseDmg * damageMultiplier)

    -- 暴击判定（全体共用同一次判定）
    local isCrit
    scaledDmg, isCrit = player:ApplyCrit(scaledDmg)

    -- 对命中目标施加伤害
    local actualDmg = scaledDmg
    for i = 1, hitCount do
        local m = hitList[i]
        if m and m.alive then
            actualDmg = m:TakeDamage(scaledDmg, player) or scaledDmg
            EventBus.Emit("player_deal_damage", player, m)
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
            duration = 1.2,  -- 神塔镇压：凝现→蓄力→炸裂，需要较长展示时间
        })

    -- 连击尝试
    SkillSystem.TryCombo(player, skill, targetAngle, function()
        -- 连击伤害重新计算
        local comboDmg = math.floor(player:GetTotalAtk() + player:GetTotalHeavyHit())
        local comboDmgBonus = player:GetConstitutionHeavyDmgBonus()
        if comboDmgBonus > 0 then
            comboDmg = math.floor(comboDmg * (1 + comboDmgBonus))
        end
        comboDmg = math.floor(comboDmg * damageMultiplier)
        local comboCrit
        comboDmg, comboCrit = player:ApplyCrit(comboDmg)

        for i = 1, hitCount do
            local m = hitList[i]
            if m and m.alive then
                m:TakeDamage(comboDmg, player)
                EventBus.Emit("player_deal_damage", player, m)
            end
        end
        local comboPrefix = comboCrit and (icon .. "连击暴击 ") or (icon .. "连击 ")
        local comboColor = comboCrit and {255, 220, 50, 255} or (skill.effectColor or {80, 200, 120, 255})
        CombatSystem.AddFloatingText(player.x, player.y - 0.8, comboPrefix .. comboDmg, comboColor, 1.5)
    end)

    EventBus.Emit("skill_cast", skill.id, skill)
    print("[SkillSystem] 神塔镇压! " .. scaledDmg .. (isCrit and " (CRIT)" or "") .. " 命中" .. hitCount .. "个目标 (x" .. string.format("%.0f%%", damageMultiplier * 100) .. ")")
    return true
end

-- ============================================================================
-- 镇岳职业技能类型处理器（hp_damage / hp_heal_damage / toggle_passive / accumulate_trigger）
-- ============================================================================

--- hp_damage: 消耗自身 HP，以最大生命为基础造成范围伤害
--- 公式: raw = maxHP × hpCoefficient × (1 + skillDmg%), 然后走 CalcDamage(raw, def) → ApplyCrit → TakeDamage
---@param skill table
---@param player table
---@return boolean
function SkillSystem.CastHpDamageSkill(skill, player)
    -- 必须有目标
    if not player.target or not player.target.alive then return false end

    local maxHp = player:GetTotalMaxHp()
    local hpCost = math.floor(maxHp * (skill.hpCost or 0))

    -- HP 不够（至少保留 1 点）
    if player.hp <= hpCost then return false end

    -- 扣血
    player.hp = math.max(1, player.hp - hpCost)

    -- 累计消耗（供血爆读取）
    if skill.feedsAccumulator then
        player._bloodAccumulator = (player._bloodAccumulator or 0) + hpCost
    end

    -- 判定中心：有 centerOffset 的技能沿朝向偏移（身前圆形区域），其他技能以玩家为中心
    local targetAngle = math.atan(player.target.y - player.y, player.target.x - player.x)
    local cx, cy = player.x, player.y
    if skill.centerOffset then
        local offsetDist = skill.centerOffset == true and (skill.range or 1.5) or skill.centerOffset
        cx = player.x + math.cos(targetAngle) * offsetDist
        cy = player.y + math.sin(targetAngle) * offsetDist
    end

    -- 获取范围内目标
    local targets = GameState.GetMonstersInRange(cx, cy, skill.range or 1.5)
    local hitCount = math.min(#targets, skill.maxTargets or 5)

    -- 基础伤害 = maxHP × hpCoefficient
    local rawDmg = maxHp * (skill.hpCoefficient or 0.10)

    -- 技能伤害%加成
    if skill.skillDmgApplies then
        local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
        rawDmg = rawDmg * (1 + skillDmgPercent)
    end

    rawDmg = math.floor(rawDmg)

    -- 多目标技能：每个血怒效果每次施法最多叠加一层
    CombatSystem._bloodRageTriggeredThisCast = false

    -- 对每个目标造成伤害
    local firstHitMonster = nil
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = GameConfig.CalcDamage(rawDmg, m.def)
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            damage = m:TakeDamage(damage, player) or damage
            EventBus.Emit("player_deal_damage", player, m)

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
function SkillSystem.CastHpHealDamageSkill(skill, player)
    -- 有形状过滤（如 rect 推波）时，需要目标来确定方向
    local targetAngle
    if skill.shape then
        if not player.target or not player.target.alive then return false end
        targetAngle = math.atan(player.target.y - player.y, player.target.x - player.x)
    end

    local maxHp = player:GetTotalMaxHp()

    -- 回血
    local healAmount = math.floor(maxHp * (skill.healPercent or 0.30))
    player.hp = math.min(maxHp, player.hp + healAmount)
    CombatSystem.AddFloatingText(player.x, player.y - 0.8, "+" .. healAmount, {80, 255, 120, 255}, 1.2)

    -- 判定中心：有 centerOffset 的技能沿朝向偏移（身前推波），否则以玩家为中心
    local cx, cy = player.x, player.y
    if skill.centerOffset and targetAngle then
        local offsetDist = skill.centerOffset == true and (skill.range or 1.5) or skill.centerOffset
        cx = player.x + math.cos(targetAngle) * offsetDist
        cy = player.y + math.sin(targetAngle) * offsetDist
    end

    -- 获取范围内目标
    local targets = GameState.GetMonstersInRange(cx, cy, skill.range or 1.5)

    -- 形状过滤（rect/cone）
    if skill.shape and targetAngle then
        targets = SkillSystem.FilterByShape(targets, skill, player, targetAngle)
    end

    local hitCount = math.min(#targets, skill.maxTargets or 5)

    -- 基础伤害 = maxHP × hpCoefficient
    local rawDmg = maxHp * (skill.hpCoefficient or 0.15)

    -- 技能伤害%加成
    if skill.skillDmgApplies then
        local skillDmgPercent = (player.equipSkillDmg or 0) + player:GetSkillDmgPercent()
        rawDmg = rawDmg * (1 + skillDmgPercent)
    end

    rawDmg = math.floor(rawDmg)

    -- 对每个目标造成伤害
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = GameConfig.CalcDamage(rawDmg, m.def)
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            damage = m:TakeDamage(damage, player) or damage
            EventBus.Emit("player_deal_damage", player, m)

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
        duration = skill.effectDuration,   -- earth_surge 使用更长的特效时间
    } or nil)

    print("[SkillSystem] " .. skill.name .. ": heal " .. healAmount .. ", hit " .. hitCount .. " targets")
    return true
end

--- toggle_passive: 可切换的被动技能，每帧 tick 消耗 HP 并对周围敌人造成真实伤害
--- passive 回调（CheckPassiveTriggers 每帧调用）
---@param skill table
---@param player table
---@param skillId string
---@param dt number
function SkillSystem.TogglePassiveTick(skill, player, skillId, dt)
    -- 获取或初始化状态（惰性初始化，默认 active = skill.defaultActive）
    local state = SkillSystem.GetSkillState(skillId, { active = skill.defaultActive or false })

    -- 未激活则跳过
    if not state.active then return end

    -- 首次 tick 时触发 onActivate（defaultActive=true 时不经过 Toggle 入口）
    if not state._activated then
        state._activated = true
        if skill.onActivate then skill.onActivate(skill, player) end
    end

    -- 血量不足自动关闭：当前 HP ≤ 最大HP的5% 时自动停止（防止烧死自己）
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

        -- NaN 防护：tickDmg 必须是有效数字
        if tickDmg and tickDmg ~= tickDmg then -- NaN check: NaN ~= NaN
            print("[SkillSystem] onTick returned NaN for skill=" .. tostring(skillId) .. ", skipping AoE")
            return
        end

        -- AoE 真实伤害（焚血灼伤周围敌人）
        if tickDmg and tickDmg > 0 and skill.aoeRange then
            local targets = GameState.GetMonstersInRange(player.x, player.y, skill.aoeRange)
            local aoeDmg = math.floor(tickDmg)
            if aoeDmg > 0 then
                for _, m in ipairs(targets) do
                    if m and m.alive then
                        -- 持续伤害：不走 CalcDamage，直接 TakeDamage
                        -- 焚血(canCrit=true)吃暴击；其他持续性真伤不吃暴击
                        local finalDmg = aoeDmg
                        local isCrit = false
                        if skill.canCrit and player.ApplyCrit then
                            finalDmg, isCrit = player:ApplyCrit(aoeDmg)
                        end
                        local dmgOk, dmgErr = pcall(m.TakeDamage, m, finalDmg, player)
                        if not dmgOk then
                            print("[SkillSystem] TakeDamage pcall error: " .. tostring(dmgErr))
                        end
                        -- 持续伤害标记 isDot=true，由系统级逻辑过滤血怒等后处理
                        EventBus.Emit("player_deal_damage", player, m, true)
                        -- 浮动伤害数字（暴击时放大显示）
                        local textScale = isCrit and 1.6 or 1.2
                        local critColor = isCrit and {255, 200, 0, 255} or skill.effectColor
                        CombatSystem.AddFloatingText(m.x, m.y - 0.3, tostring(finalDmg), critColor, textScale)
                    end
                end
            end
        end
    end
end

--- toggle_passive 的切换函数（被 BottomBar 调用）
---@param skillId string
function SkillSystem.TogglePassiveSkill(skillId)
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

--- accumulate_trigger: 累计触发被动（累积 HP 消耗达到阈值时自动引爆 AoE 真实伤害）
--- passive 回调（CheckPassiveTriggers 每帧调用）
---@param skill table
---@param player table
---@param skillId string
---@param dt number
function SkillSystem.AccumulateTriggerTick(skill, player, skillId, dt)
    local field = skill.accumulatorField
    if not field then return end

    local accumulated = player[field] or 0
    local maxHp = player:GetTotalMaxHp()
    local threshold = maxHp * (skill.threshold or 1.0)

    if accumulated < threshold then return end

    -- 达到阈值：引爆！
    player[field] = 0  -- 重置累计器

    -- 基础伤害 = maxHP × damagePercent
    local baseDmg = math.floor(maxHp * (skill.damagePercent or 0.10))

    -- 血怒值加成（防御性 or 0 兜底）
    if skill.useBloodRageValue then
        local bloodRageValue = player:GetPhysiqueBloodRageValue() or 0
        baseDmg = math.floor(baseDmg * (1 + bloodRageValue))
    end

    -- AoE 真实伤害
    local targets = GameState.GetMonstersInRange(player.x, player.y, skill.aoeRange or 2)
    local hitCount = math.min(#targets, skill.maxTargets or 5)

    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage = baseDmg  -- 真实伤害，不走 CalcDamage
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            local dmgOk, dmgResult = pcall(m.TakeDamage, m, damage, player)
            if dmgOk then
                damage = dmgResult or damage
            else
                print("[SkillSystem] AccumulateTrigger TakeDamage error: " .. tostring(dmgResult))
            end
            EventBus.Emit("player_deal_damage", player, m)

            local dmgText = isCrit and (skill.icon .. "血神暴击 " .. damage) or (skill.icon .. "血神 " .. damage)
            local dmgColor = isCrit and {255, 220, 50, 255} or (skill.effectColor or {180, 20, 20, 255})
            CombatSystem.AddFloatingText(m.x, m.y - 0.3, dmgText, dmgColor, 1.8)
        end
    end

    -- 引爆特效
    local shapeData = skill.effectDuration and { duration = skill.effectDuration } or nil
    CombatSystem.AddSkillEffect(player, skill.id, skill.aoeRange or 2, skill.effectColor, "melee_aoe", shapeData)
    CombatSystem.AddFloatingText(player.x, player.y - 1.0, skill.icon .. skill.name .. "!", skill.effectColor or {180, 20, 20, 255}, 2.0)

    print("[SkillSystem] " .. skill.name .. " triggered! baseDmg=" .. baseDmg .. " hit " .. hitCount .. " targets")
end

-- ============================================================================
-- 注册内置技能类型处理器
-- ============================================================================

SkillSystem.RegisterType("melee_aoe",  { cast = SkillSystem.CastDamageSkill })
SkillSystem.RegisterType("ranged_aoe", { cast = SkillSystem.CastDamageSkill })
SkillSystem.RegisterType("lifesteal",  { cast = SkillSystem.CastLifestealSkill })
SkillSystem.RegisterType("heal",       { cast = SkillSystem.CastHealSkill })
SkillSystem.RegisterType("buff",       { cast = SkillSystem.CastBuffSkill })
SkillSystem.RegisterType("aoe_dot",    { cast = SkillSystem.CastAoeDotSkill })
SkillSystem.RegisterType("ground_zone",{ cast = SkillSystem.CastGroundZoneSkill })
SkillSystem.RegisterType("passive",    { passive = SkillSystem.PassiveShieldTrigger })
SkillSystem.RegisterType("charge_passive", {})  -- 事件驱动（normal_hit / heavy_hit → ChargePassiveAddStacks）
SkillSystem.RegisterType("sword_shield_passive", { passive = SkillSystem.SwordShieldPassive })
SkillSystem.RegisterType("nth_cast_trigger", {})    -- 事件驱动（skill_cast → TryNthCastTrigger）
SkillSystem.RegisterType("melee_aoe_dot",  { cast = SkillSystem.CastMeleeAoeDotSkill })
SkillSystem.RegisterType("multi_zone_heavy", { cast = SkillSystem.CastMultiZoneHeavySkill })

-- 镇岳职业技能类型
SkillSystem.RegisterType("hp_damage",          { cast = SkillSystem.CastHpDamageSkill })
SkillSystem.RegisterType("hp_heal_damage",      { cast = SkillSystem.CastHpHealDamageSkill })
SkillSystem.RegisterType("toggle_passive",      { cast = function(skill, _player)
    SkillSystem.TogglePassiveSkill(skill.id)
    return true
end, passive = SkillSystem.TogglePassiveTick })
SkillSystem.RegisterType("accumulate_trigger",   { passive = SkillSystem.AccumulateTriggerTick })

-- 封魔盘法宝技能类型
SkillSystem.RegisterType("damage_amp_zone",      { cast = SkillSystem.CastDamageAmpZoneSkill })

-- 龙极令法宝技能类型（仙缘扇形 AOE）
SkillSystem.RegisterType("xianyuan_cone_aoe",    { cast = SkillSystem.CastXianyuanConeAoeSkill })

return SkillSystem
