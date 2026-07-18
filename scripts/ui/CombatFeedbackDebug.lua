-- ============================================================================
-- CombatFeedbackDebug.lua - GM 战斗跳字规范矩阵
-- ============================================================================

local FeatureFlags = require("config.FeatureFlags")

local M = {}

local function mockTarget(id, x, y)
    return { id = "feedback_debug_" .. id, x = x, y = y, alive = true }
end

local function spawnMatrix(CombatSystem, player)
    CombatSystem.ResetCombatFeedback()

    local px, py = player.x, player.y
    local cases = {
        { id = "normal", x = px - 2.4, y = py - 1.4, value = 9999,
          opts = { sourceType = "basic", sourceId = "debug_normal" } },
        { id = "skill", x = px - 0.8, y = py - 1.4, value = 12500,
          opts = { sourceType = "skill", sourceId = "debug_skill", sourceName = "诛仙剑气" } },
        { id = "crit", x = px + 0.8, y = py - 1.4, value = 128000,
          opts = { sourceType = "skill", sourceId = "debug_crit", sourceName = "神塔镇压", criticality = "crit" } },
        { id = "tianzhu", x = px + 2.4, y = py - 1.4, value = 268000,
          opts = { sourceType = "skill", sourceId = "debug_tianzhu", sourceName = "一剑开天", criticality = "tianzhu" } },
        { id = "heavy", x = px - 1.6, y = py + 0.2, value = 86400,
          opts = { sourceType = "passive", sourceId = "debug_heavy", sourceName = "龙象震地", damageTag = "heavy", impact = "heavy" } },
        { id = "dot", x = px, y = py + 0.2, value = 2380,
          opts = { sourceType = "passive", sourceId = "debug_dot", sourceName = "焚血", damageTag = "dot", impact = "dot" } },
        { id = "long", x = px + 1.6, y = py + 0.2, value = 99999999,
          opts = { sourceType = "skill", sourceId = "debug_long", sourceName = "九天十地万剑归宗诀", criticality = "crit" } },
    }

    for i = 1, #cases do
        local case = cases[i]
        local target = mockTarget(case.id, case.x, case.y)
        case.opts.castId = CombatSystem.NextCombatCastId(case.id)
        CombatSystem.EmitDamageFeedback(player, target, case.value, case.opts)
    end

    CombatSystem.EmitCombatFeedback({
        kind = "heal", value = 8888,
        source = player, target = player, targetKey = "debug:self:heal",
        sourceType = "skill", sourceId = "debug_heal", sourceName = "噬魂回复",
        x = px - 1.2, y = py + 1.7,
    })
    CombatSystem.EmitCombatFeedback({
        kind = "hurt", value = 6666,
        target = player, targetKey = "debug:self:hurt",
        sourceType = "boss", sourceId = "debug_hurt",
        x = px, y = py + 1.7,
    })
    CombatSystem.EmitCombatFeedback({
        kind = "absorb", value = 4321,
        target = player, targetKey = "debug:self:absorb",
        sourceType = "skill", sourceId = "debug_absorb", sourceName = "镇界天幕",
        x = px + 1.2, y = py + 1.7,
    })
    CombatSystem.EmitCombatFeedback({
        kind = "evade", text = "闪避",
        target = player, targetKey = "debug:self:evade",
        sourceType = "equipment", sourceId = "debug_evade",
        x = px + 2.4, y = py + 1.7,
    })

    return CombatSystem.GetCombatFeedbackStats()
end

function M.SpawnMatrix(CombatSystem, player)
    local previousOverride = FeatureFlags.getOverride("COMBAT_FEEDBACK_V2")
    FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", true)
    local ok, result = pcall(spawnMatrix, CombatSystem, player)
    if previousOverride == nil then
        FeatureFlags.clearOverride("COMBAT_FEEDBACK_V2")
    else
        FeatureFlags.setOverride("COMBAT_FEEDBACK_V2", previousOverride)
    end
    if not ok then error(result) end
    return result
end

return M
