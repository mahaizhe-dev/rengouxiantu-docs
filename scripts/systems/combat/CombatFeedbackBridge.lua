-- ============================================================================
-- CombatFeedbackBridge.lua - CombatSystem 新旧跳字互斥桥接
-- ============================================================================

local FeatureFlags = require("config.FeatureFlags")
local CombatFeedback = require("systems.combat.CombatFeedback")

local function isDungeonMode()
    local DungeonRenderer = package.loaded["rendering.DungeonRenderer"]
    if not DungeonRenderer then
        local ok, loaded = pcall(require, "rendering.DungeonRenderer")
        if ok then DungeonRenderer = loaded end
    end
    return DungeonRenderer
        and DungeonRenderer.IsDungeonMode
        and DungeonRenderer.IsDungeonMode() == true
end

local function emitLegacy(CombatSystem, fallback, event)
    if not fallback then return false end
    local list = fallback[1] and fallback or { fallback }
    for i = 1, #list do
        local item = list[i]
        local text = item.text or ""
        if event and event.kind == "heal" then
            text = CombatFeedback.FormatHealText(text, event.value)
        end
        CombatSystem.AddFloatingText(
            item.x or 0,
            item.y or 0,
            text,
            item.color,
            item.lifetime,
            item.baseScale
        )
    end
    return true
end

local function isDungeonCombat(event)
    if isDungeonMode() then return true end
    if type(event) ~= "table" then return false end
    local source = event.source
    local target = event.target
    return (type(source) == "table" and source.isDungeonBoss == true)
        or (type(target) == "table" and target.isDungeonBoss == true)
end

return function(CombatSystem)
    function CombatSystem.EmitCombatFeedback(event, legacyFallback)
        -- 多人副本保留原有本地表现与权威 HUD 链路，不接入主世界 V2 队列。
        if isDungeonCombat(event) then
            return emitLegacy(CombatSystem, legacyFallback), "dungeon_legacy"
        end
        if FeatureFlags.isEnabled("COMBAT_FEEDBACK_V2") then
            return CombatFeedback.Emit(event)
        end
        return emitLegacy(CombatSystem, legacyFallback, event), "legacy"
    end

    function CombatSystem.EmitLegacyOnlyFeedback(legacyFallback)
        if isDungeonMode() then
            return emitLegacy(CombatSystem, legacyFallback), "dungeon_legacy"
        end
        if FeatureFlags.isEnabled("COMBAT_FEEDBACK_V2") then
            return true, "suppressed"
        end
        return emitLegacy(CombatSystem, legacyFallback), "legacy"
    end

    function CombatSystem.EmitDamageFeedback(source, target, value, opts, legacyFallback)
        opts = opts or {}
        local event = {
            kind = "damage",
            value = value,
            source = source,
            target = target,
            x = opts.x,
            y = opts.y,
            targetKey = opts.targetKey,
            sourceType = opts.sourceType,
            sourceId = opts.sourceId,
            sourceName = opts.sourceName,
            sourceShortName = opts.sourceShortName,
            effectId = opts.effectId,
            damageTag = opts.damageTag,
            criticality = opts.criticality,
            impact = opts.impact,
            castId = opts.castId,
            hitIndex = opts.hitIndex,
            labelPolicy = opts.labelPolicy,
            labelCooldown = opts.labelCooldown,
            aggregatePolicy = opts.aggregatePolicy,
            priority = opts.priority,
            color = opts.color,
            tag = opts.tag,
        }
        return CombatSystem.EmitCombatFeedback(event, legacyFallback)
    end

    function CombatSystem.NextCombatCastId(prefix)
        return CombatFeedback.NextCastId(prefix)
    end

    function CombatSystem.ResetCombatFeedback()
        CombatFeedback.Clear()
    end

    function CombatSystem.UpdateCombatFeedback(dt)
        CombatFeedback.Update(dt)
    end

    function CombatSystem.GetCombatFeedbackItems()
        return CombatFeedback.GetItems()
    end

    function CombatSystem.GetCombatFeedbackStats()
        return CombatFeedback.GetStats()
    end
end
