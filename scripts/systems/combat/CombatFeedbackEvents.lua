-- ============================================================================
-- CombatFeedbackEvents.lua - 基础攻击、宠物与玩家受伤反馈事件
-- ============================================================================

local EventBus = require("core.EventBus")
local GameState = require("core.GameState")

local PET_COLOR = {100, 255, 150, 255}
local PET_SKILL_COLOR = {200, 130, 255, 255}
local PET_SKILL_LABEL = {180, 120, 255, 255}
local IGNORE_DEF_COLOR = {255, 200, 60, 255}
local DEBUFF_COLOR = {255, 160, 80, 255}
local HURT_COLOR = {255, 80, 80, 255}

return function(CombatSystem)
    function CombatSystem.InitCombatFeedbackEvents()
        EventBus.On("player_attack", function(player, monster)
            CombatSystem.AddSlashEffect(player, monster, player:GetAttackInterval())
        end)

        EventBus.On("pet_attack", function(pet, monster, damage, isCrit, _, isIgnoreDef)
            local text = isIgnoreDef and ("破防 " .. damage) or tostring(damage)
            local color = isIgnoreDef and IGNORE_DEF_COLOR or PET_COLOR
            CombatSystem.EmitDamageFeedback(pet, monster, damage, {
                sourceType = "pet",
                sourceName = isIgnoreDef and "破防" or nil,
                sourceId = isIgnoreDef and "pet_ignore_def" or "pet_attack",
                criticality = isCrit and "crit" or "normal",
                damageTag = "pet",
                labelPolicy = isIgnoreDef and "always" or nil,
            }, {
                x = monster.x, y = monster.y, text = text, color = color,
            })
            CombatSystem.AddPetSlashEffect(pet, monster)
        end)

        EventBus.On("pet_skill_attack", function(pet, monster, damage, isCrit, skill)
            local skillId = skill and skill.id or "pet_lingshi"
            CombatSystem.EmitDamageFeedback(pet, monster, damage, {
                sourceType = "pet_skill",
                sourceId = skillId,
                sourceName = skill and skill.name or "灵噬",
                criticality = isCrit and "crit" or "normal",
                damageTag = "pet",
                color = PET_SKILL_COLOR,
            }, {
                {
                    x = monster.x, y = monster.y - 0.3,
                    text = isCrit and ("暴击 " .. damage) or tostring(damage),
                    color = PET_SKILL_COLOR, lifetime = 1.3,
                },
                {
                    x = monster.x, y = monster.y - 0.6,
                    text = "🐺灵噬Lv." .. pet.tier, color = PET_SKILL_LABEL,
                },
            })
            CombatSystem.EmitCombatFeedback({
                kind = "status",
                text = "易伤 8%",
                target = monster,
                sourceType = "pet_skill",
                sourceId = skillId,
                color = DEBUFF_COLOR,
            }, {
                x = monster.x, y = monster.y + 0.1,
                text = "易伤 8%", color = DEBUFF_COLOR,
            })
            CombatSystem.AddPetSlashEffect(pet, monster)
        end)

        EventBus.On("player_hurt", function(damage, source, feedbackContext)
            local player = GameState.player
            if not player then return end
            feedbackContext = type(feedbackContext) == "table" and feedbackContext or {}
            local legacyText = feedbackContext.legacyText
            if not legacyText then
                legacyText = (feedbackContext.legacyPrefix or "-")
                    .. tostring(damage)
                    .. (feedbackContext.legacySuffix or "")
            end
            CombatSystem.EmitCombatFeedback({
                kind = "hurt",
                value = damage,
                source = source,
                target = player,
                x = feedbackContext.x,
                y = feedbackContext.y,
                sourceType = feedbackContext.sourceType or "boss",
                sourceId = feedbackContext.sourceId,
                sourceName = feedbackContext.sourceName,
                sourceShortName = feedbackContext.sourceShortName,
                effectId = feedbackContext.effectId,
                damageTag = feedbackContext.damageTag,
                impact = feedbackContext.impact,
                labelPolicy = feedbackContext.labelPolicy,
                labelCooldown = feedbackContext.labelCooldown,
                color = feedbackContext.color,
                tag = feedbackContext.tag,
                targetKey = "player:self",
            }, {
                x = feedbackContext.legacyX or player.x,
                y = feedbackContext.legacyY or player.y,
                text = legacyText,
                color = feedbackContext.legacyColor or HURT_COLOR,
                lifetime = feedbackContext.legacyLifetime,
                baseScale = feedbackContext.legacyScale,
            })
        end)

        EventBus.On("shield_hit", function(absorbed)
            local player = GameState.player
            if not player or not absorbed or absorbed <= 0 then return end
            CombatSystem.EmitCombatFeedback({
                kind = "absorb", value = absorbed,
                source = player, target = player, targetKey = "player:self",
                sourceType = "skill", sourceId = "player_shield",
                sourceName = "护盾",
            }, nil)
        end)

        EventBus.On("shield_broken", function()
            local player = GameState.player
            if not player then return end
            CombatSystem.EmitCombatFeedback({
                kind = "status", text = "护盾破碎",
                target = player, targetKey = "player:self",
                sourceType = "skill", sourceId = "player_shield",
                color = {121, 201, 255, 255},
            }, nil)
        end)
    end
end
