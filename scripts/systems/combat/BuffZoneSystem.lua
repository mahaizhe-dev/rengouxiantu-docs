-- ============================================================================
-- BuffZoneSystem.lua - Buff / Zone / DOT 子系统（从 CombatSystem 提取）
-- ============================================================================
-- Pattern A 注入：return function(CS) ... end
-- CS = CombatSystem 引用，可调用 CS.AddFloatingText() 等核心方法

local GameConfig = require("config.GameConfig")
local GameState  = require("core.GameState")
local Utils      = require("core.Utils")

-- ── 颜色常量（与 CombatSystem 同源，仅引用本模块需要的） ──
local FT_GRAY      = {200, 200, 200, 255}
local FT_DOT_TICK  = {200, 80, 80, 255}
local FT_HEAL_ZONE = {100, 255, 200, 255}
local FT_BUFF_DEFAULT = {150, 255, 200, 255}
local FT_ZONE_DEFAULT = {80, 200, 255, 255}

return function(CS)

-- ── 复用缓冲区（同帧 Buff/Zone/DOT 不重叠，可共享） ──
local _expiredBuf = {}

-- ============================================================================
-- Buff 子系统
-- ============================================================================

--- 添加buff
---@param buffId string buff唯一标识
---@param data table { duration, tickInterval, healPercent, atkPercent, defPercent, wisdomFlat, fortuneFlat, constitutionFlat, physiqueFlat, name, color }
function CS.AddBuff(buffId, data)
    CS.activeBuffs[buffId] = {
        id = buffId,
        name = data.name or buffId,
        duration = data.duration or 10,
        remaining = data.duration or 10,
        tickInterval = data.tickInterval or 1.0,
        healPercent = data.healPercent or 0,
        atkPercent = data.atkPercent or 0,
        defPercent = data.defPercent or 0,
        -- 四维属性固定值加成（悟性/福缘/根骨/体魄）
        wisdomFlat = data.wisdomFlat or 0,
        fortuneFlat = data.fortuneFlat or 0,
        constitutionFlat = data.constitutionFlat or 0,
        physiqueFlat = data.physiqueFlat or 0,
        tickTimer = 0,
        color = data.color or FT_BUFF_DEFAULT,
    }
    print("[CombatSystem] Buff added: " .. buffId .. " (" .. (data.duration or 10) .. "s)")
end

--- 移除buff
---@param buffId string
function CS.RemoveBuff(buffId)
    if CS.activeBuffs[buffId] then
        print("[CombatSystem] Buff removed: " .. buffId)
        CS.activeBuffs[buffId] = nil
    end
end

--- 是否有指定buff
---@param buffId string
---@return boolean
function CS.HasBuff(buffId)
    return CS.activeBuffs[buffId] ~= nil
end

--- 获取所有活跃buff
---@return table
function CS.GetActiveBuffs()
    return CS.activeBuffs
end

--- 获取所有活跃buff的攻击百分比加成之和
---@return number
function CS.GetBuffAtkPercent()
    local total = 0
    for _, buff in pairs(CS.activeBuffs) do
        total = total + (buff.atkPercent or 0)
    end
    return total
end

--- 获取所有活跃buff的防御百分比加成之和
---@return number
function CS.GetBuffDefPercent()
    local total = 0
    for _, buff in pairs(CS.activeBuffs) do
        total = total + (buff.defPercent or 0)
    end
    return total
end

--- 获取所有活跃buff的悟性固定值加成之和
---@return number
function CS.GetBuffWisdomFlat()
    local total = 0
    for _, buff in pairs(CS.activeBuffs) do
        total = total + (buff.wisdomFlat or 0)
    end
    return total
end

--- 获取所有活跃buff的福缘固定值加成之和
---@return number
function CS.GetBuffFortuneFlat()
    local total = 0
    for _, buff in pairs(CS.activeBuffs) do
        total = total + (buff.fortuneFlat or 0)
    end
    return total
end

--- 获取所有活跃buff的根骨固定值加成之和
---@return number
function CS.GetBuffConstitutionFlat()
    local total = 0
    for _, buff in pairs(CS.activeBuffs) do
        total = total + (buff.constitutionFlat or 0)
    end
    return total
end

--- 获取所有活跃buff的体魄固定值加成之和
---@return number
function CS.GetBuffPhysiqueFlat()
    local total = 0
    for _, buff in pairs(CS.activeBuffs) do
        total = total + (buff.physiqueFlat or 0)
    end
    return total
end

--- 更新所有buff（tick回血、持续时间递减、过期移除）
---@param dt number
function CS.UpdateBuffs(dt)
    local player = GameState.player
    if not player or not player.alive then return end

    local expired = _expiredBuf
    for i = 1, #expired do expired[i] = nil end
    for buffId, buff in pairs(CS.activeBuffs) do
        buff.remaining = buff.remaining - dt
        if buff.remaining <= 0 then
            table.insert(expired, buffId)
        else
            if buff.healPercent > 0 then
                buff.tickTimer = buff.tickTimer + dt
                if buff.tickTimer >= buff.tickInterval then
                    buff.tickTimer = buff.tickTimer - buff.tickInterval
                    local totalMaxHp = player:GetTotalMaxHp()
                    local healAmount = math.floor(totalMaxHp * buff.healPercent)
                    if healAmount > 0 and player.hp < totalMaxHp then
                        player.hp = math.min(totalMaxHp, player.hp + healAmount)
                        CS.AddFloatingText(player.x, player.y, "+" .. healAmount, buff.color, 0.8)
                    end
                end
            end
        end
    end

    for _, buffId in ipairs(expired) do
        local buff = CS.activeBuffs[buffId]
        if buff then
            CS.AddFloatingText(
                player.x, player.y,
                buff.name .. " 结束", FT_GRAY, 1.0
            )
        end
        CS.RemoveBuff(buffId)
    end
end

-- ============================================================================
-- Zone（地板区域效果）子系统
-- ============================================================================

--- 添加地板区域效果（浩气领域、封魔大阵等）
---@param data table { x, y, range, duration, tickInterval, damagePercent, healPercent, atk, damageBoostPercent, color, name }
function CS.AddZone(data)
    table.insert(CS.activeZones, {
        x = data.x,
        y = data.y,
        range = data.range or 2.0,
        remaining = data.duration or 6.0,
        duration = data.duration or 6.0,
        tickTimer = 0,
        tickInterval = data.tickInterval or 1.0,
        damagePercent = data.damagePercent or 0,
        healPercent = data.healPercent or 0,
        atk = data.atk or 0,
        maxTargets = data.maxTargets or 0,
        damageBoostPercent = data.damageBoostPercent or 0, -- 增伤区域：阵内怪物受到最终伤害+X%
        color = data.color or FT_ZONE_DEFAULT,
        name = data.name or "领域",
    })
    print("[CombatSystem] Zone added: " .. (data.name or "领域") .. " (" .. (data.duration or 6) .. "s)")
end

--- 更新地板区域效果（每 tick 对范围内敌人造成伤害、对自身回血）
---@param dt number
function CS.UpdateZones(dt)
    local player = GameState.player
    if not player or not player.alive then return end

    local expired = _expiredBuf
    for i = 1, #expired do expired[i] = nil end
    for i, zone in ipairs(CS.activeZones) do
        zone.remaining = zone.remaining - dt
        if zone.remaining <= 0 then
            table.insert(expired, i)
        else
            zone.tickTimer = zone.tickTimer + dt
            if zone.tickTimer >= zone.tickInterval then
                zone.tickTimer = zone.tickTimer - zone.tickInterval

                -- 对范围内怪物造成伤害（受 maxTargets 限制）
                if zone.damagePercent > 0 and zone.atk > 0 then
                    local monsters = GameState.GetMonstersInRange(zone.x, zone.y, zone.range)
                    local dmgPerTick = math.floor(zone.atk * zone.damagePercent)
                    local hitCount = 0
                    local hitLimit = zone.maxTargets > 0 and zone.maxTargets or #monsters
                    for _, m in ipairs(monsters) do
                        if m.alive then
                            local actualDmg = GameConfig.CalcDamage(dmgPerTick, m.def)
                            actualDmg = m:TakeDamage(actualDmg, player) or actualDmg
                            CS.AddFloatingText(
                                m.x, m.y - 0.2,
                                tostring(actualDmg),
                                zone.color,
                                0.8
                            )
                            hitCount = hitCount + 1
                            if hitCount >= hitLimit then break end
                        end
                    end
                end

                -- 对自身回血（玩家需在领域范围内）
                if zone.healPercent > 0 then
                    local distToZone = Utils.Distance(player.x, player.y, zone.x, zone.y)
                    if distToZone <= zone.range then
                        local maxHp = player:GetTotalMaxHp()
                        local healAmount = math.floor(maxHp * zone.healPercent)
                        if healAmount > 0 and player.hp < maxHp then
                            player.hp = math.min(maxHp, player.hp + healAmount)
                            CS.AddFloatingText(
                                player.x, player.y - 0.2,
                                "+" .. healAmount,
                                FT_HEAL_ZONE,
                                0.8
                            )
                        end
                    end
                end
            end
        end
    end

    -- 倒序移除已过期的区域
    for i = #expired, 1, -1 do
        local zone = CS.activeZones[expired[i]]
        if zone then
            CS.AddFloatingText(
                zone.x, zone.y,
                zone.name .. " 消散", FT_GRAY, 1.0
            )
        end
        table.remove(CS.activeZones, expired[i])
    end
end

--- 获取所有活跃地板区域（供渲染用）
---@return table[]
function CS.GetActiveZones()
    return CS.activeZones
end

-- ============================================================================
-- DOT 子系统（流血等持续伤害）
-- ============================================================================

--- 更新所有 DOT 效果（每帧调用）
---@param dt number
function CS.UpdateDots(dt)
    -- 更新内置 CD
    for key, cd in pairs(CS.dotCooldowns) do
        cd = cd - dt
        if cd <= 0 then
            CS.dotCooldowns[key] = nil
        else
            CS.dotCooldowns[key] = cd
        end
    end

    -- 更新 DOT tick
    local expired = _expiredBuf
    for i = 1, #expired do expired[i] = nil end
    for mId, dot in pairs(CS.activeDots) do
        local monster = dot.monster
        -- 怪物死亡或无效则移除
        if not monster or not monster.alive then
            table.insert(expired, mId)
        else
            dot.tickTimer = dot.tickTimer + dt
            -- 每秒 tick 一次
            if dot.tickTimer >= 1.0 then
                dot.tickTimer = dot.tickTimer - 1.0
                local tickDmg = math.max(1, math.floor(dot.dmgPerTick))
                tickDmg = monster:TakeDamage(tickDmg, dot.source) or tickDmg
                CS.AddFloatingText(
                    monster.x, monster.y - 0.4,
                    tickDmg .. " " .. dot.effectName,
                    FT_DOT_TICK, 0.6
                )
            end
            dot.remaining = dot.remaining - dt
            if dot.remaining <= 0 then
                table.insert(expired, mId)
            end
        end
    end
    for _, mId in ipairs(expired) do
        CS.activeDots[mId] = nil
    end
end

end -- return function(CS)
