-- ============================================================================
-- Ch6ForgeEffects.lua - 第六章影炉装备的玩家侧独立效果
-- ============================================================================

local Ch6ForgeEffects = {}

local function GetZhenjieEffect(player)
    for _, effect in ipairs(player.equipSpecialEffects or {}) do
        if effect.type == "zhenjie_shield" then
            return effect
        end
    end
    return nil
end

function Ch6ForgeEffects.Initialize(player)
    player._zhenjieShieldHp = 0
    player._zhenjieShieldMaxHp = 0
    player._zhenjieShieldDuration = 0
    player._zhenjieShieldCooldown = 0
end

function Ch6ForgeEffects.GetShieldStatus(player)
    return player._zhenjieShieldHp or 0,
           player._zhenjieShieldMaxHp or 0,
           player._zhenjieShieldDuration or 0,
           player._zhenjieShieldCooldown or 0
end

function Ch6ForgeEffects.Update(player, dt)
    if not GetZhenjieEffect(player) then
        Ch6ForgeEffects.Initialize(player)
        return
    end

    if player._zhenjieShieldCooldown > 0 then
        player._zhenjieShieldCooldown = math.max(0, player._zhenjieShieldCooldown - dt)
    end

    if player._zhenjieShieldHp > 0 then
        player._zhenjieShieldDuration = math.max(0, player._zhenjieShieldDuration - dt)
        if player._zhenjieShieldDuration <= 0 then
            player._zhenjieShieldHp = 0
            player._zhenjieShieldMaxHp = 0
        end
    end
end

---@return number remainingDamage
---@return number absorbedDamage
---@return boolean broken
function Ch6ForgeEffects.AbsorbDamage(player, damage)
    local shieldHp = player._zhenjieShieldHp or 0
    if shieldHp <= 0 or damage <= 0 then
        return damage, 0, false
    end

    local absorbed = math.min(damage, shieldHp)
    local remaining = damage - absorbed
    player._zhenjieShieldHp = shieldHp - absorbed

    local broken = player._zhenjieShieldHp <= 0
    if broken then
        player._zhenjieShieldHp = 0
        player._zhenjieShieldMaxHp = 0
        player._zhenjieShieldDuration = 0
    end

    return remaining, absorbed, broken
end

---@param randomFn function|nil 返回 [0,1) 的随机值
---@return boolean triggered
---@return number shieldValue
function Ch6ForgeEffects.TryTrigger(player, actualHpDamage, randomFn)
    if actualHpDamage <= 0 or not player.alive or player.hp <= 0 then
        return false, 0
    end
    if (player._zhenjieShieldHp or 0) > 0 or (player._zhenjieShieldCooldown or 0) > 0 then
        return false, 0
    end

    local effect = GetZhenjieEffect(player)
    if not effect then
        return false, 0
    end

    local roll = (randomFn or math.random)()
    if roll >= (effect.triggerChance or 0.20) then
        return false, 0
    end

    local totalDef = player.GetTotalDef and player:GetTotalDef() or 0
    local shieldValue = math.max(1, math.floor(totalDef * (effect.defMultiplier or 3)))
    player._zhenjieShieldHp = shieldValue
    player._zhenjieShieldMaxHp = shieldValue
    player._zhenjieShieldDuration = effect.duration or 6
    player._zhenjieShieldCooldown = effect.cooldown or 15
    return true, shieldValue
end

return Ch6ForgeEffects
