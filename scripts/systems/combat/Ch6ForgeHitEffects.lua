-- ============================================================================
-- Ch6ForgeHitEffects.lua - 第六章铸造武器命中特效
-- ============================================================================

local GameState = require("core.GameState")
local HitResolver = require("systems.combat.HitResolver")

local M = {}

function M.CreateHenghaHandler(CombatSystem)
    return {
        onHit = function(eff, player, monster)
            if not monster.alive then return end
            if (eff._cooldown or 0) > 0 then return end
            if math.random() >= (eff.procChance or 0.15) then return end

            eff._cooldown = eff.cooldown or 1.0
            local actualDmg = HitResolver.FixedDamage(
                player, monster, eff.fixedDamage or 50000, true)
            monster.hurtFlashTimer = math.max(monster.hurtFlashTimer or 0, 0.35)
            CombatSystem.AddSkillEffect(
                monster, "hengha_burst", 1.7, {255, 105, 55, 255},
                "melee_aoe", { duration = 0.65 })
            CombatSystem.EmitDamageFeedback(player, monster, actualDmg, {
                sourceType = "equipment",
                sourceId = eff.type,
                sourceName = "哼哈震杀",
                damageTag = "skill",
                color = {255, 105, 55, 255},
                y = monster.y - 1.0,
            }, {
                x = monster.x, y = monster.y - 1.0,
                text = "哼哈震杀 " .. actualDmg,
                color = {255, 105, 55, 255}, lifetime = 1.5, baseScale = 1.6,
            })
        end,
        update = function(dt)
            local player = GameState.player
            if not player then return end
            for _, eff in ipairs(player.equipSpecialEffects or {}) do
                if eff.type == "hengha_fixed_burst" and (eff._cooldown or 0) > 0 then
                    eff._cooldown = math.max(0, eff._cooldown - dt)
                end
            end
        end,
    }
end

return M
