-- ============================================================================
-- BossMechanics.lua - BOSS 机制子系统（从 CombatSystem 提取）
-- 献祭光环 / 血煞印记 / 正气结界 / 血怒 / 延迟命中 / 治愈之泉 / 玉甲回响
-- ============================================================================
-- Pattern A 注入：return function(CS) ... end

local GameConfig = require("config.GameConfig")
local GameState  = require("core.GameState")
local EventBus   = require("core.EventBus")
local Utils      = require("core.Utils")

-- ── 颜色常量 ──
local FT_HEAL_SPRING = {80, 220, 180, 255}
local FT_SACRIFICE   = {255, 140, 40, 220}
local FT_BLOOD_MARK  = {180, 30, 30, 255}
local FT_BARRIER     = {240, 200, 50, 255}
local FT_BLOOD_RAGE  = {200, 40, 40, 255}
local FT_RAGE_DET_CRIT   = {255, 60, 60, 255}
local FT_RAGE_DET_NORMAL = {220, 30, 30, 255}
local FT_HIT_DEFAULT = {160, 120, 50, 255}
local FT_JADE_SHIELD = {80, 220, 140, 255}
local FT_JADE_REFLECT = {60, 200, 120, 255}
local FT_SEAL_MARK   = {160, 80, 200, 255}
local FT_SEAL_BURST  = {200, 40, 220, 255}

return function(CS)

-- ============================================================================
-- 治愈之泉回血
-- ============================================================================

local healSpringTickTimer_ = 0

--- 治愈之泉回血逻辑（范围内每秒恢复5%最大生命值）
---@param dt number
---@param player table
---@param gameMap table
function CS.UpdateHealingSpring(dt, player, gameMap)
    if not player or not player.alive or not gameMap then return end

    if gameMap:IsNearHealingSpring(player.x, player.y, 1.5) then
        healSpringTickTimer_ = healSpringTickTimer_ + dt
        if healSpringTickTimer_ >= 1.0 then
            healSpringTickTimer_ = healSpringTickTimer_ - 1.0
            local healAmt = math.floor(player:GetTotalMaxHp() * 0.05)
            if healAmt > 0 and player.hp < player:GetTotalMaxHp() then
                player.hp = math.min(player:GetTotalMaxHp(), player.hp + healAmt)
                CS.AddFloatingText(
                    player.x, player.y, "+" .. healAmt .. " 泉",
                    FT_HEAL_SPRING, 0.8
                )
            end
        end
    else
        healSpringTickTimer_ = 0
    end
end

-- ============================================================================
-- 延迟命中系统（地刺等预警后延迟造成伤害）
-- ============================================================================

--- 添加延迟命中
---@param hit table { delay, x, y, range, damage, source, effectName, effectColor }
function CS.AddDelayedHit(hit)
    hit.elapsed = 0
    table.insert(CS.delayedHits, hit)
end

--- 更新延迟命中
---@param dt number
function CS.UpdateDelayedHits(dt)
    local player = GameState.player
    local pet = GameState.pet
    local arr = CS.delayedHits
    local j = 1
    for i = 1, #arr do
        local h = arr[i]
        h.elapsed = h.elapsed + dt
        if h.elapsed >= h.delay then
            -- 延迟到期，判定范围内玩家是否命中
            if player and player.alive then
                local dist = Utils.Distance(player.x, player.y, h.x, h.y)
                if dist <= (h.range or 0.8) then
                    player:TakeDamage(h.damage, h.source)
                    local color = h.effectColor or FT_HIT_DEFAULT
                    CS.AddFloatingText(
                        player.x, player.y - 0.3,
                        (h.effectName or "") .. " " .. h.damage,
                        color, 1.0
                    )
                end
            end
            -- 宠物也受延迟命中伤害（减半）
            if pet and pet.alive then
                local petDist = Utils.Distance(pet.x, pet.y, h.x, h.y)
                if petDist <= (h.range or 0.8) then
                    local petDmg = math.floor(h.damage * 0.5)
                    if petDmg > 0 then
                        pet:TakeDamage(petDmg, h.source)
                    end
                end
            end
            -- 已处理，不保留
        else
            arr[j] = h
            j = j + 1
        end
    end
    for i = j, #arr do arr[i] = nil end
end

-- ============================================================================
-- 献祭光环系统（黄沙·焚天特效：持续灼烧周围怪物）
-- ============================================================================

CS.sacrificeAuraTimer = 0
CS.sacrificeAuraActive = false

--- 更新献祭光环
---@param dt number
function CS.UpdateSacrificeAura(dt)
    local player = GameState.player
    if not player or not player.alive then
        CS.sacrificeAuraActive = false
        return
    end

    local effects = player.equipSpecialEffects
    if not effects then
        CS.sacrificeAuraActive = false
        return
    end

    local eff = nil
    for _, e in ipairs(effects) do
        if e.type == "sacrifice_aura" then
            eff = e
            break
        end
    end
    if not eff then
        CS.sacrificeAuraActive = false
        return
    end

    CS.sacrificeAuraActive = true
    CS.sacrificeAuraRange = eff.range or 1.5

    local interval = eff.tickInterval or 0.5
    CS.sacrificeAuraTimer = CS.sacrificeAuraTimer + dt
    if CS.sacrificeAuraTimer < interval then return end
    CS.sacrificeAuraTimer = CS.sacrificeAuraTimer - interval

    local targets = GameState.GetMonstersInRange(player.x, player.y, eff.range or 3.0)
    if #targets == 0 then return end

    local dmg = math.max(1, math.floor(player:GetTotalAtk() * (eff.damagePercent or 0.05)))
    for _, m in ipairs(targets) do
        local actualDmg = m:TakeDamage(dmg, player) or dmg
        CS.AddFloatingText(
            m.x, m.y - 0.3,
            actualDmg .. " 灼",
            FT_SACRIFICE,
            0.6
        )
    end
end

-- ============================================================================
-- 血煞印记系统（沈墨BOSS机制）
-- ============================================================================

--- 更新血煞印记持续掉血
---@param dt number
function CS.UpdateBloodMark(dt)
    local player = GameState.player
    if not player or not player.alive then return end
    if player.bloodMarkStacks <= 0 then return end

    player.bloodMarkTickTimer = player.bloodMarkTickTimer + dt
    if player.bloodMarkTickTimer >= 1.0 then
        player.bloodMarkTickTimer = player.bloodMarkTickTimer - 1.0
        local maxHp = player:GetTotalMaxHp()
        local dmgPerStack = math.floor(maxHp * player.bloodMarkDmgPercent)
        local totalDmg = dmgPerStack * player.bloodMarkStacks
        if totalDmg > 0 then
            player:TakeDamage(totalDmg, nil)
            CS.AddFloatingText(
                player.x, player.y - 0.3,
                "-" .. totalDmg .. " 血煞",
                FT_BLOOD_MARK, 0.8
            )
        end
    end
end

--- 清除血煞印记（挑战结束时调用）
function CS.ClearBloodMark()
    local player = GameState.player
    if player then
        player.bloodMarkStacks = 0
        player.bloodMarkDmgPercent = 0
        player.bloodMarkTickTimer = 0
    end
end

-- ============================================================================
-- 正气结界系统（陆青云BOSS机制）
-- ============================================================================

--- 更新正气结界（周期生成+对玩家伤害）
---@param dt number
function CS.UpdateBarrierZones(dt)
    local player = GameState.player
    if not player or not player.alive then return end

    -- 查找当前存活的带 barrierZone 配置的挑战怪物
    ---@type table|nil
    local barrierMonster = nil
    for i = 1, #GameState.monsters do
        local m = GameState.monsters[i]
        if m.alive and m.isChallenge and m.barrierZone then
            barrierMonster = m
            break
        end
    end

    -- 有结界BOSS存活时，周期生成屏障
    if barrierMonster then
        local cfg = barrierMonster.barrierZone
        CS.barrierSpawnTimer = CS.barrierSpawnTimer + dt

        if CS.barrierSpawnTimer >= cfg.interval and #CS.barrierZones < cfg.maxCount then
            CS.barrierSpawnTimer = 0
            local arenaSize = 6
            local centerX = barrierMonster.spawnX or barrierMonster.x
            local centerY = barrierMonster.spawnY or barrierMonster.y
            local bx, by
            local attempts = 0
            repeat
                bx = centerX + (math.random() - 0.5) * arenaSize
                by = centerY + (math.random() - 0.5) * arenaSize
                bx = math.max(2.5, math.min(6.5, bx))
                by = math.max(2.5, math.min(6.5, by))
                attempts = attempts + 1
            until attempts > 10 or (
                Utils.Distance(bx, by, barrierMonster.x, barrierMonster.y) > 1.5 and
                Utils.Distance(bx, by, player.x, player.y) > 1.5
            )

            table.insert(CS.barrierZones, {
                x = bx,
                y = by,
                radius = cfg.radius,
                damagePercent = cfg.damagePercent,
                monsterAtk = barrierMonster.atk,
                tickTimer = 0,
            })
            CS.AddFloatingText(
                bx, by - 0.5,
                "正气结界",
                FT_BARRIER, 1.5
            )
            print("[CombatSystem] 正气结界生成! 位置=(" .. string.format("%.1f,%.1f", bx, by)
                .. ") 当前数量=" .. #CS.barrierZones .. "/" .. cfg.maxCount)
        end
    end

    -- 对范围内玩家和宠物造成每秒伤害
    local pet = GameState.pet
    for _, zone in ipairs(CS.barrierZones) do
        zone.tickTimer = zone.tickTimer + dt
        if zone.tickTimer >= 1.0 then
            zone.tickTimer = zone.tickTimer - 1.0
            local dist = Utils.Distance(player.x, player.y, zone.x, zone.y)
            if dist <= zone.radius then
                local dmg = math.floor(zone.monsterAtk * zone.damagePercent)
                if dmg > 0 then
                    local actualDmg = GameConfig.CalcDamage(dmg, player:GetTotalDef())
                    player:TakeDamage(actualDmg, nil)
                    CS.AddFloatingText(
                        player.x, player.y - 0.3,
                        "-" .. actualDmg .. " 结界",
                        FT_BARRIER, 0.8
                    )
                end
            end
            -- 宠物也受结界伤害（减半）
            if pet and pet.alive then
                local petDist = Utils.Distance(pet.x, pet.y, zone.x, zone.y)
                if petDist <= zone.radius then
                    local petDmg = math.floor(zone.monsterAtk * zone.damagePercent * 0.5)
                    if petDmg > 0 then
                        petDmg = GameConfig.CalcDamage(petDmg, pet:GetTotalDef())
                        pet:TakeDamage(petDmg, nil)
                    end
                end
            end
        end
    end
end

--- 获取正气结界列表（供渲染用）
---@return table[]
function CS.GetBarrierZones()
    return CS.barrierZones
end

--- 清除所有正气结界（挑战结束时调用）
function CS.ClearBarrierZones()
    CS.barrierZones = {}
    CS.barrierSpawnTimer = 0
end

-- ============================================================================
-- 血怒系统（体魄属性：叠层引爆）
-- ============================================================================

local BLOOD_RAGE_MAX_STACKS = 5
local BLOOD_RAGE_DETONATE_RATIO = 0.10

--- 血怒触发检查（命中后调用，概率触发，每次施法最多一层）
---@param player table
---@param monster table
function CS.TryBloodRage(player, monster)
    if not monster or not monster.alive then return end

    -- 多目标技能期间，概率血怒每次施法最多触发一次
    if CS._bloodRageTriggeredThisCast then return end

    local chance = player:GetPhysiqueBloodRageChance()
    if chance <= 0 then return end

    if math.random() > chance then return end

    -- 标记本次施法已触发（nil 时为普攻上下文，不设标记）
    if CS._bloodRageTriggeredThisCast == false then
        CS._bloodRageTriggeredThisCast = true
    end

    CS.AddBloodRageStack(player, monster)
end

--- 强制叠加一层血怒（跳过概率检查，供 guaranteedBloodRage 技能调用）
---@param player table
---@param monster table
function CS.AddBloodRageStack(player, monster)
    if not monster or not monster.alive then return end

    local mId = monster.id
    local stacks = (CS.bloodRageStacks[mId] or 0) + 1
    CS.bloodRageStacks[mId] = stacks

    if stacks < BLOOD_RAGE_MAX_STACKS then
        CS.AddFloatingText(
            monster.x, monster.y - 0.4,
            "血怒 x" .. stacks,
            FT_BLOOD_RAGE, 0.8
        )
        print("[Combat] 血怒叠层(保证)! " .. monster.name .. " x" .. stacks)
    else
        CS.bloodRageStacks[mId] = 0
        local detonateDmg = math.max(1, math.floor(player:GetTotalMaxHp() * BLOOD_RAGE_DETONATE_RATIO))
        local detCrit
        detonateDmg, detCrit = player:ApplyCrit(detonateDmg)
        detonateDmg = monster:TakeDamage(detonateDmg, player) or detonateDmg

        local prefix = detCrit and "血怒引爆暴击 " or "血怒引爆 "
        local color = detCrit and FT_RAGE_DET_CRIT or FT_RAGE_DET_NORMAL
        CS.AddFloatingText(
            monster.x, monster.y - 0.6,
            prefix .. detonateDmg,
            color,
            1.5
        )
        print("[Combat] 血怒引爆(保证)! " .. monster.name .. " " .. detonateDmg .. (detCrit and " (CRIT)" or ""))
    end
end

--- 获取指定怪物的血怒层数（供UI渲染用）
---@param monsterId number|string
---@return number
function CS.GetBloodRageStacks(monsterId)
    return CS.bloodRageStacks[monsterId] or 0
end

-- ============================================================================
-- 永驻八卦领域系统（文王残影BOSS机制）
-- 数据驱动：从 monster.baguaAura 读取配置
-- ============================================================================

local FT_BAGUA_AURA = {180, 160, 80, 255}

--- 八卦领域内部计时器（每个怪物独立）
---@type table<string|number, number>
CS.baguaAuraTimers = {}

--- 当前存活的八卦领域BOSS引用（供渲染用）
---@type table|nil
CS.activeBaguaBoss = nil

--- 更新永驻八卦领域（查找带 baguaAura 配置的存活怪物）
---@param dt number
function CS.UpdateBaguaAura(dt)
    local player = GameState.player
    if not player or not player.alive then
        CS.activeBaguaBoss = nil
        return
    end

    -- 查找存活的八卦领域BOSS
    local baguaBoss = nil
    for i = 1, #GameState.monsters do
        local m = GameState.monsters[i]
        if m.alive and m.baguaAura and m.baguaAura.enabled then
            baguaBoss = m
            break
        end
    end

    CS.activeBaguaBoss = baguaBoss
    if not baguaBoss then return end

    local cfg = baguaBoss.baguaAura
    local mId = baguaBoss.id
    local timer = (CS.baguaAuraTimers[mId] or 0) + dt
    local interval = cfg.tickInterval or 1.0

    if timer >= interval then
        timer = timer - interval

        -- 检查玩家是否在领域范围内
        local dist = Utils.Distance(player.x, player.y, baguaBoss.x, baguaBoss.y)
        if dist <= cfg.radius then
            local dmg = math.floor(player:GetTotalMaxHp() * (cfg.damagePercent or 0.02))
            if dmg > 0 then
                player:TakeDamage(dmg, baguaBoss)
                CS.AddFloatingText(
                    player.x, player.y - 0.3,
                    "-" .. dmg .. " 八卦",
                    FT_BAGUA_AURA, 0.8
                )
            end
        end

        -- 宠物也受领域伤害（减半）
        local pet = GameState.pet
        if pet and pet.alive then
            local petDist = Utils.Distance(pet.x, pet.y, baguaBoss.x, baguaBoss.y)
            if petDist <= cfg.radius then
                local petDmg = math.floor(player:GetTotalMaxHp() * (cfg.damagePercent or 0.02) * 0.5)
                if petDmg > 0 then
                    pet:TakeDamage(petDmg, baguaBoss)
                end
            end
        end
    end

    CS.baguaAuraTimers[mId] = timer
end

--- 获取当前八卦领域BOSS信息（供渲染用）
---@return table|nil boss, table|nil config, string|nil stateKey
function CS.GetBaguaAuraInfo()
    local boss = CS.activeBaguaBoss
    if not boss then return nil, nil, nil end
    return boss, boss.baguaAura, boss.dualStateCurrentKey
end

--- 清除八卦领域计时器（战斗结束时调用）
function CS.ClearBaguaAura()
    CS.baguaAuraTimers = {}
    CS.activeBaguaBoss = nil
end

-- ============================================================================
-- 玉甲回响系统（云裳BOSS机制）
-- 数据驱动：从 monster.jadeShield 读取配置
-- 周期性激活护盾，护盾期间减伤+反射伤害给玩家
-- ============================================================================

--- 玉甲回响内部计时器（每个怪物独立）
--- { [monsterId] = { cooldown = number, active = number, isActive = boolean } }
---@type table<string|number, table>
CS.jadeShieldTimers = {}

--- 当前存活的玉甲回响BOSS引用（供渲染用）
---@type table|nil
CS.activeJadeShieldBoss = nil

--- 更新玉甲回响（查找带 jadeShield 配置的存活怪物）
---@param dt number
function CS.UpdateJadeShield(dt)
    local player = GameState.player
    if not player or not player.alive then
        CS.activeJadeShieldBoss = nil
        return
    end

    -- 查找存活的玉甲回响BOSS
    local jadeBoss = nil
    for i = 1, #GameState.monsters do
        local m = GameState.monsters[i]
        if m.alive and m.isChallenge and m.jadeShield then
            jadeBoss = m
            break
        end
    end

    CS.activeJadeShieldBoss = jadeBoss
    if not jadeBoss then return end

    local cfg = jadeBoss.jadeShield
    local mId = jadeBoss.id
    local state = CS.jadeShieldTimers[mId]

    -- 初始化计时器状态
    if not state then
        state = { cooldown = 0, active = 0, isActive = false }
        CS.jadeShieldTimers[mId] = state
    end

    if state.isActive then
        -- 护盾激活中：累计激活时间
        state.active = state.active + dt
        if state.active >= cfg.duration then
            -- 护盾持续时间结束，关闭护盾
            state.isActive = false
            state.cooldown = 0
            state.active = 0
            -- 清除怪物身上的护盾标记
            jadeBoss.jadeShieldActive = false
            jadeBoss.jadeShieldDmgReduction = nil
            jadeBoss.jadeShieldReflectPercent = nil
            CS.AddFloatingText(
                jadeBoss.x, jadeBoss.y - 0.5,
                "玉甲消散",
                FT_JADE_SHIELD, 1.0
            )
        end
    else
        -- 护盾冷却中：累计冷却时间
        state.cooldown = state.cooldown + dt
        if state.cooldown >= cfg.interval then
            -- 冷却结束，激活护盾
            state.isActive = true
            state.active = 0
            state.cooldown = 0
            -- 在怪物身上设置护盾标记（Monster:TakeDamage 读取）
            jadeBoss.jadeShieldActive = true
            jadeBoss.jadeShieldDmgReduction = cfg.dmgReduction
            jadeBoss.jadeShieldReflectPercent = cfg.reflectPercent
            CS.AddFloatingText(
                jadeBoss.x, jadeBoss.y - 0.5,
                "🛡️ 玉甲回响",
                FT_JADE_SHIELD, 1.5
            )
            print("[BossMechanics] 玉甲回响激活! 减伤=" .. (cfg.dmgReduction * 100) .. "% 反射=" .. (cfg.reflectPercent * 100) .. "%")
        end
    end
end

--- 获取当前玉甲回响BOSS信息（供渲染用）
---@return table|nil boss, table|nil config, boolean isShieldActive, number remainingDuration
function CS.GetJadeShieldInfo()
    local boss = CS.activeJadeShieldBoss
    if not boss then return nil, nil, false, 0 end
    local state = CS.jadeShieldTimers[boss.id]
    local isActive = state and state.isActive or false
    local remaining = 0
    if isActive and state and boss.jadeShield then
        remaining = math.max(0, boss.jadeShield.duration - state.active)
    end
    return boss, boss.jadeShield, isActive, remaining
end

--- 清除玉甲回响计时器（挑战结束时调用）
function CS.ClearJadeShield()
    -- 清除所有怪物身上的护盾标记
    for mId, _ in pairs(CS.jadeShieldTimers) do
        for i = 1, #GameState.monsters do
            local m = GameState.monsters[i]
            if m.id == mId then
                m.jadeShieldActive = false
                m.jadeShieldDmgReduction = nil
                m.jadeShieldReflectPercent = nil
                break
            end
        end
    end
    CS.jadeShieldTimers = {}
    CS.activeJadeShieldBoss = nil
end

--- 订阅玉甲反伤事件（由 Monster:TakeDamage 触发）
EventBus.On("jade_shield_reflect", function(reflectDmg, monsterX, monsterY)
    local player = GameState.player
    if player and player.alive and reflectDmg > 0 then
        player:TakeDamage(reflectDmg, nil)
        CS.AddFloatingText(
            player.x, player.y - 0.3,
            "-" .. reflectDmg .. " 玉甲反伤",
            FT_JADE_REFLECT, 0.8
        )
    end
end)

-- ============================================================================
-- 封魔印系统（凌战BOSS机制）
-- 周期性自动叠层，满层爆发伤害；玩家攻击BOSS时削减层数
-- ============================================================================

--- 更新封魔印（周期叠层 + 满层爆发）
---@param dt number
function CS.UpdateSealMark(dt)
    local player = GameState.player
    if not player or not player.alive then return end

    -- 查找当前存活的带 sealMark 配置的挑战怪物
    ---@type table|nil
    local sealMonster = nil
    for i = 1, #GameState.monsters do
        local m = GameState.monsters[i]
        if m.alive and m.isChallenge and m.sealMark then
            sealMonster = m
            break
        end
    end

    if not sealMonster then
        -- 无封魔印BOSS，清空状态
        if player.sealMarkStacks > 0 then
            CS.ClearSealMark()
        end
        return
    end

    local cfg = sealMonster.sealMark
    -- 首次遇到封魔印BOSS时设置配置
    if not player.sealMarkConfig then
        player.sealMarkConfig = cfg
    end

    -- 周期叠层
    player.sealMarkTickTimer = player.sealMarkTickTimer + dt
    if player.sealMarkTickTimer >= cfg.stackInterval then
        player.sealMarkTickTimer = player.sealMarkTickTimer - cfg.stackInterval
        player.sealMarkStacks = player.sealMarkStacks + 1

        CS.AddFloatingText(
            player.x, player.y - 0.5,
            "封魔印 x" .. player.sealMarkStacks,
            FT_SEAL_MARK, 1.2
        )

        -- 满层爆发
        if player.sealMarkStacks >= cfg.maxStacks then
            local maxHp = player:GetTotalMaxHp()
            local burstDmg = math.floor(maxHp * cfg.burstDamagePercent)
            if burstDmg > 0 then
                player:TakeDamage(burstDmg, nil)
                CS.AddFloatingText(
                    player.x, player.y - 0.8,
                    "封印爆发! -" .. burstDmg,
                    FT_SEAL_BURST, 1.5
                )
            end
            -- 爆发后清零层数，重新开始叠加
            player.sealMarkStacks = 0
            player.sealMarkTickTimer = 0
        end
    end
end

--- 清除封魔印（挑战结束时调用）
function CS.ClearSealMark()
    local player = GameState.player
    if player then
        player.sealMarkStacks = 0
        player.sealMarkTickTimer = 0
        player.sealMarkConfig = nil
    end
end

--- 订阅怪物受伤事件：玩家攻击封魔印BOSS时削减印记层数
EventBus.On("monster_hurt", function(monster, _damage)
    if not monster or not monster.sealMark then return end
    local player = GameState.player
    if not player or player.sealMarkStacks <= 0 then return end
    local cfg = monster.sealMark
    local clearCount = cfg.clearPerHit or 1
    player.sealMarkStacks = math.max(0, player.sealMarkStacks - clearCount)
    if player.sealMarkStacks == 0 then
        player.sealMarkTickTimer = 0  -- 清空后重置计时
    end
end)

end -- return function(CS)
