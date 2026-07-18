-- ============================================================================
-- LifestealBurst.lua - 噬魂装备的击杀回血与满层爆发
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")

local M = {}

local COLOR_DAMAGE = {180, 80, 255, 255}
local COLOR_HEAL = {180, 120, 255, 255}

function M.CreateHandler(CombatSystem)
    return {
        onKill = function(eff, player, _monster)
            local effectId = eff.type or "lifesteal_burst"
            local effectName = eff.name or "噬魂"
            local maxHp = player:GetTotalMaxHp()
            local healAmount = math.floor(maxHp * (eff.healPercent or 0.03))
            if healAmount > 0 and player.hp < maxHp then
                local hpBefore = player.hp
                player.hp = math.min(maxHp, player.hp + healAmount)
                local actualHeal = player.hp - hpBefore
                CombatSystem.EmitCombatFeedback({
                    kind = "heal", value = actualHeal,
                    source = player, target = player, targetKey = "player:self",
                    sourceType = "equipment", sourceId = effectId .. ":kill_heal",
                    sourceName = effectName, color = COLOR_HEAL,
                }, {
                    x = player.x, y = player.y - 0.5,
                    text = effectName .. " +" .. actualHeal,
                    color = COLOR_HEAL, lifetime = 0.8,
                })
            end

            local maxStacks = eff.maxStacks or 10
            eff._soulStacks = (eff._soulStacks or 0) + 1
            if eff._soulStacks < maxStacks then
                CombatSystem.EmitCombatFeedback({
                    kind = "status",
                    text = effectName .. " " .. eff._soulStacks .. "/" .. maxStacks,
                    target = player, targetKey = "player:self",
                    sourceType = "equipment", sourceId = effectId .. ":stack",
                    labelPolicy = "never", color = COLOR_DAMAGE,
                }, {
                    x = player.x, y = player.y - 0.3,
                    text = effectName .. " " .. eff._soulStacks .. "/" .. maxStacks,
                    color = COLOR_DAMAGE, lifetime = 0.6,
                })
                return
            end

            eff._soulStacks = 0
            local baseDamage = math.max(
                1,
                math.floor(player:GetTotalAtk() * (eff.damagePercent or 1.0))
            )
            local nearest = GameState.GetNearestMonster(
                player.x, player.y, eff.range or 2.5)
            local sweepAngle
            if nearest then
                sweepAngle = math.atan(nearest.y - player.y, nearest.x - player.x)
            else
                sweepAngle = player.facingRight and 0 or math.pi
            end
            local cosAngle = math.cos(sweepAngle)
            local sinAngle = math.sin(sweepAngle)
            local rectLength = eff.rectLength or 2.0
            local rectWidth = eff.rectWidth or 1.0
            local halfWidth = rectWidth / 2
            local searchRange = math.sqrt(
                rectLength * rectLength + halfWidth * halfWidth) + 0.5
            local targets = GameState.GetMonstersInRange(
                player.x, player.y, searchRange)
            local maxTargets = eff.maxTargets or 3
            local hitCount = 0
            local totalDamage = 0
            local castId = CombatSystem.NextCombatCastId(effectId)

            for _, monster in ipairs(targets) do
                if monster.alive then
                    local offsetX = monster.x - player.x
                    local offsetY = monster.y - player.y
                    local forward = offsetX * cosAngle + offsetY * sinAngle
                    local lateral = -offsetX * sinAngle + offsetY * cosAngle
                    if forward >= 0 and forward <= rectLength
                        and math.abs(lateral) <= halfWidth then
                        local damage = GameConfig.CalcDamage(baseDamage, monster.def)
                        damage = monster:TakeDamage(damage, player)
                        hitCount = hitCount + 1
                        totalDamage = totalDamage + damage
                        CombatSystem.EmitDamageFeedback(
                            player, monster, damage, {
                                sourceType = "equipment",
                                sourceId = effectId,
                                effectId = effectId,
                                sourceName = effectName,
                                damageTag = "skill",
                                castId = castId,
                                hitIndex = hitCount,
                                color = COLOR_DAMAGE,
                                y = monster.y - 0.9,
                            }, {
                                x = monster.x, y = monster.y - 0.9,
                                text = effectName .. " " .. damage,
                                color = COLOR_DAMAGE, lifetime = 1.3,
                            })
                        if hitCount >= maxTargets then break end
                    end
                end
            end

            local burstHeal = 0
            if totalDamage > 0 and player.hp < maxHp then
                local hpBefore = player.hp
                player.hp = math.min(maxHp, player.hp + totalDamage)
                burstHeal = player.hp - hpBefore
                CombatSystem.EmitCombatFeedback({
                    kind = "heal", value = burstHeal,
                    source = player, target = player, targetKey = "player:self",
                    sourceType = "equipment", sourceId = effectId .. ":burst_heal",
                    sourceName = effectName .. "回复", color = COLOR_HEAL,
                }, {
                    x = player.x, y = player.y - 0.3,
                    text = effectName .. "回复 +" .. burstHeal,
                    color = COLOR_HEAL, lifetime = 1.0,
                })
            end

            local effectColor = eff.effectColor or {160, 80, 220, 255}
            CombatSystem.AddSkillEffect(
                player, "soul_burst", eff.range or 2.5, effectColor,
                "lifesteal", {
                    shape = "rect",
                    rectLength = rectLength,
                    rectWidth = rectWidth,
                    targetAngle = sweepAngle,
                    duration = 0.5,
                })

            print("[Combat] 噬魂满层爆发! hit=" .. hitCount
                .. " dmg=" .. totalDamage .. " heal=" .. burstHeal)
        end,
    }
end

return M
