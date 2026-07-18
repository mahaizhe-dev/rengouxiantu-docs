-- ============================================================================
-- CombatFeedback.lua - 结构化主世界战斗反馈队列
-- 纯 Lua：不依赖 NanoVG、实体实现或伤害结算。
-- ============================================================================

local Config = require("config.CombatFeedbackConfig")

local M = {}

local items = {}
local now = 0
local nextItemId = 0
local nextCastId = 0
local nextTargetId = 0
local labelSeenAt = {}
local castLabelStates = {}
local targetIds = setmetatable({}, { __mode = "k" })
local cleanupTimer = 0

local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local function clamp(value, lo, hi)
    return math_max(lo, math_min(hi, value))
end

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function trimZeros(text)
    text = text:gsub("(%..-)0+$", "%1")
    return text:gsub("%.$", "")
end

local function formatScaled(value, divisor, suffix)
    local scaled = value / divisor
    local decimals = scaled < 10 and 2 or (scaled < 100 and 1 or 0)
    return trimZeros(string.format("%." .. decimals .. "f", scaled)) .. suffix
end

function M.FormatNumber(value)
    local number = math_abs(tonumber(value) or 0)
    if number < 10000 then
        return tostring(math_floor(number + 0.5))
    end
    if number >= 999950000000 then
        return formatScaled(number, 1000000000000, "万亿")
    end
    if number >= 99995000 then
        return formatScaled(number, 100000000, "亿")
    end
    if number >= 1000000000000 then
        return formatScaled(number, 1000000000000, "万亿")
    end
    if number >= 100000000 then
        return formatScaled(number, 100000000, "亿")
    end
    return formatScaled(number, 10000, "万")
end

function M.FormatHealText(text, value)
    local number = math_abs(tonumber(value) or 0)
    local formatted = tostring(math_floor(number + 0.5))
    if text == nil or text == "" then
        return "+" .. formatted
    end

    local result = tostring(text):gsub("(%+)(%d+%.%d+)", function(sign, _raw)
        return sign .. formatted
    end, 1)
    return result
end

function M.TruncateLabel(text, maxChars)
    text = tostring(text or "")
    maxChars = maxChars or 6
    if text == "" then return "" end
    if not utf8 or not utf8.len or not utf8.offset then
        return #text > maxChars and (text:sub(1, maxChars) .. "...") or text
    end
    local ok, length = pcall(function()
        return utf8.len(text)
    end)
    if not ok or not length or length <= maxChars then return text end
    local cut = utf8.offset(text, maxChars + 1)
    if not cut then return text end
    return text:sub(1, cut - 1) .. "…"
end

local function getTargetKey(event)
    if event.targetKey ~= nil then
        return tostring(event.targetKey)
    end
    local target = event.target
    if type(target) == "table" then
        local stableId = target.id or target.userId or target.uid or target.runtimeId
        if stableId ~= nil then
            return "entity:" .. tostring(stableId)
        end
        local runtimeId = targetIds[target]
        if not runtimeId then
            nextTargetId = nextTargetId + 1
            runtimeId = nextTargetId
            targetIds[target] = runtimeId
        end
        return "runtime:" .. tostring(runtimeId)
    end
    local x = tonumber(event.x) or 0
    local y = tonumber(event.y) or 0
    return string.format("pos:%d:%d", math_floor(x * 4), math_floor(y * 4))
end

local function resolveAnimationKey(event)
    if event.kind == "hurt" then return "hurt" end
    if event.kind == "heal" then return "heal" end
    if event.kind == "absorb" then return "absorb" end
    if event.kind == "evade" or event.kind == "immune" or event.kind == "status" then
        return "status"
    end
    if event.criticality == "tianzhu" then return "tianzhu" end
    if event.criticality == "crit" then return "crit" end
    if event.impact == "heavy" or event.damageTag == "heavy" then return "heavy" end
    if event.impact == "dot" or event.damageTag == "dot" then return "dot" end
    if event.sourceType == "skill" or event.sourceType == "pet_skill" then return "skill" end
    return "normal"
end

local function resolvePriority(event, animationKey)
    if event.priority then return event.priority end
    if animationKey == "tianzhu" then return Config.PRIORITY.tianzhu end
    if event.kind == "hurt" or event.kind == "evade" or event.kind == "immune" then
        return Config.PRIORITY.selfHigh
    end
    if animationKey == "crit" then return Config.PRIORITY.crit end
    if animationKey == "heavy" then
        return event.sourceType == "skill" and Config.PRIORITY.skillHeavy or Config.PRIORITY.heavy
    end
    if event.kind == "absorb" then return Config.PRIORITY.absorb end
    if event.kind == "heal" then return Config.PRIORITY.heal end
    if animationKey == "dot" then return Config.PRIORITY.dot end
    if event.sourceType == "skill" or event.sourceType == "pet_skill" then return Config.PRIORITY.skill end
    if event.sourceType == "passive" or event.sourceType == "equipment"
        or event.sourceType == "artifact" then
        return Config.PRIORITY.proc
    end
    if event.sourceType == "pet" then return Config.PRIORITY.pet end
    if event.kind == "status" then return Config.PRIORITY.status end
    return Config.PRIORITY.basic
end

function M.ResolveStyle(event)
    local animationKey = resolveAnimationKey(event)
    local color
    if event.kind == "hurt" then
        color = Config.COLORS.hurt
    elseif event.kind == "heal" then
        color = Config.COLORS.heal
    elseif event.kind == "absorb" then
        color = Config.COLORS.absorb
    elseif event.kind == "evade" or event.kind == "immune" or event.kind == "status" then
        color = event.color or Config.COLORS.statusNeutral
    elseif event.criticality == "tianzhu" then
        color = Config.COLORS.damageTianzhu
    elseif event.criticality == "crit" then
        color = Config.COLORS.damageCrit
    elseif animationKey == "heavy" then
        color = Config.COLORS.damageHeavy
    elseif animationKey == "dot" then
        color = Config.COLORS.damageDot
    elseif event.sourceType == "pet" then
        color = Config.COLORS.damagePet
    elseif event.sourceType == "skill" or event.sourceType == "pet_skill" then
        color = Config.COLORS.damageSkill
    else
        color = Config.COLORS.damageNormal
    end

    return {
        animationKey = animationKey,
        animation = Config.ANIMATIONS[animationKey],
        color = color,
        labelColor = event.color or color,
        fontSize = Config.FONTS[animationKey] or Config.FONTS.normal,
        labelSize = Config.FONTS.label,
        tagSize = Config.FONTS.tag,
        priority = resolvePriority(event, animationKey),
    }
end

local function resolveText(event)
    if event.text and event.text ~= "" then
        if event.kind == "heal" then
            return M.FormatHealText(event.text, event.value)
        end
        return tostring(event.text)
    end
    local formatted = M.FormatNumber(event.value)
    if event.kind == "heal" then return "+" .. formatted end
    if event.kind == "hurt" then return "-" .. formatted end
    if event.kind == "absorb" then return formatted end
    if event.kind == "evade" then return "闪避" end
    if event.kind == "immune" then return "免疫" end
    return formatted
end

local function defaultLabelPolicy(event)
    if not event.sourceName or event.sourceName == "" then return "never" end
    if event.sourceType == "basic" or event.sourceType == "pet" then return "never" end
    if event.impact == "dot" or event.damageTag == "dot" then
        return event.castId and "first_per_cast_target" or "cooldown"
    end
    if event.sourceType == "skill" or event.sourceType == "pet_skill" then
        return event.castId and "first_per_cast_target" or "cooldown"
    end
    if event.sourceType == "passive" or event.sourceType == "equipment"
        or event.sourceType == "artifact" then
        return event.castId and "first_per_cast_target" or "cooldown"
    end
    return "always"
end

local function labelKeyFor(item)
    local sourceKey = item.sourceId or item.effectId or item.sourceName or "unknown"
    if item.labelPolicy == "first_per_cast_target" and item.castId ~= nil then
        return table.concat({ "cast", tostring(item.castId), item.targetKey, tostring(sourceKey) }, "|")
    end
    return table.concat({ "cooldown", item.targetKey, tostring(sourceKey) }, "|")
end

local function shouldShowLabel(item)
    if not item.sourceName or item.sourceName == "" then return false, nil end
    if item.labelPolicy == "never" then return false, nil end
    if item.labelPolicy == "always" then return true, nil end
    local key = labelKeyFor(item)
    if item.labelPolicy == "first_per_cast_target" then
        local sourceKey = item.sourceId or item.effectId or item.sourceName or "unknown"
        local castKey = table.concat({ tostring(item.castId), tostring(sourceKey) }, "|")
        local state = castLabelStates[castKey]
        if state and state.count >= Config.MAX_LABELS_PER_CAST then
            return false, nil, nil
        end
        return labelSeenAt[key] == nil, key, castKey
    end
    local cooldown = item.labelCooldown
        or ((item.impact == "dot" or item.damageTag == "dot") and Config.LABEL_COOLDOWNS.dot)
        or ((item.sourceType == "passive" or item.sourceType == "equipment"
            or item.sourceType == "artifact") and Config.LABEL_COOLDOWNS.proc)
        or Config.LABEL_COOLDOWNS.default
    local lastSeen = labelSeenAt[key]
    return lastSeen == nil or (now - lastSeen) >= cooldown, key
end

local function aggregateWindowFor(item)
    if item.aggregatePolicy == "never" then return 0 end
    if item.criticality ~= "normal" then return 0 end
    if item.kind == "heal" then return Config.AGGREGATE_WINDOWS.heal end
    if item.kind ~= "damage" then return 0 end
    if item.impact == "dot" or item.damageTag == "dot" then return Config.AGGREGATE_WINDOWS.dot end
    if item.sourceType == "skill" or item.sourceType == "pet_skill" then
        return Config.AGGREGATE_WINDOWS.skill
    end
    if item.sourceType == "pet" then return Config.AGGREGATE_WINDOWS.pet end
    return Config.AGGREGATE_WINDOWS.basic
end

local function aggregateKeyFor(item)
    local parts = {
        item.targetKey,
        item.kind,
        item.sourceType or "",
        tostring(item.sourceId or ""),
        tostring(item.effectId or ""),
        item.sourceName or "",
        item.damageTag or "",
        item.criticality or "",
        item.impact or "",
    }
    if item.castId ~= nil then
        parts[#parts + 1] = tostring(item.castId or "")
    end
    return table.concat(parts, "|")
end

local function tryAggregate(item)
    local window = aggregateWindowFor(item)
    if window <= 0 then return false end
    local key = aggregateKeyFor(item)
    for i = #items, 1, -1 do
        local existing = items[i]
        if existing.aggregateKey == key and existing.elapsed <= window then
            existing.value = (existing.value or 0) + (item.value or 0)
            existing.hitCount = (existing.hitCount or 1) + 1
            existing.text = resolveText({
                kind = existing.kind,
                value = existing.value,
            })
            existing.elapsed = math_min(existing.elapsed, 0.08)
            existing.aggregatePulse = math_min(3, (existing.aggregatePulse or 0) + 1)
            return true
        end
    end
    item.aggregateKey = key
    return false
end

local function removeAt(index)
    table.remove(items, index)
end

local function findLowestPriority(predicate)
    local lowestIndex, lowestPriority, lowestElapsed
    local count = 0
    for i = 1, #items do
        local item = items[i]
        if predicate(item) then
            count = count + 1
            if not lowestIndex or item.priority < lowestPriority
                or (item.priority == lowestPriority and item.elapsed > lowestElapsed) then
                lowestIndex, lowestPriority, lowestElapsed = i, item.priority, item.elapsed
            end
        end
    end
    return count, lowestIndex, lowestPriority
end

local function enforceCapacity(limit, predicate, item)
    local count, lowestIndex, lowestPriority = findLowestPriority(predicate)
    if count < limit then return true end
    if not lowestIndex or item.priority < lowestPriority then
        return false
    end
    removeAt(lowestIndex)
    return true
end

local function isDot(item)
    return item.impact == "dot" or item.damageTag == "dot"
end

local function ensureCapacity(item)
    if isDot(item) then
        local dotOk = enforceCapacity(Config.MAX_DOT_PER_TARGET, function(existing)
            return existing.targetKey == item.targetKey and isDot(existing)
        end, item)
        if not dotOk then return false end
    end

    local isSelfFeedback = item.targetKey == "player:self"
    local targetLimit = isSelfFeedback and Config.MAX_SELF or Config.MAX_PER_TARGET
    local targetOk = enforceCapacity(targetLimit, function(existing)
        return existing.targetKey == item.targetKey
    end, item)
    if not targetOk then return false end

    return enforceCapacity(Config.MAX_GLOBAL, function()
        return true
    end, item)
end

local function chooseLane(targetKey)
    local counts = {}
    for i = 1, #Config.LANES do counts[i] = 0 end
    local stackCount = 0
    for i = 1, #items do
        local item = items[i]
        if item.targetKey == targetKey then
            stackCount = stackCount + 1
            counts[item.laneIndex or 1] = counts[item.laneIndex or 1] + 1
        end
    end
    local best = 1
    for i = 2, #counts do
        if counts[i] < counts[best] then best = i end
    end
    return best, stackCount
end

local function normalize(event)
    if type(event) ~= "table" then return nil end
    local kind = event.kind or "damage"
    local value = tonumber(event.value)
    if (kind == "damage" or kind == "hurt" or kind == "heal" or kind == "absorb")
        and (not value or value <= 0) then
        return nil
    end

    local target = event.target
    local x = tonumber(event.x) or (type(target) == "table" and tonumber(target.x)) or 0
    local y = tonumber(event.y) or (type(target) == "table" and tonumber(target.y)) or 0
    local criticality = event.criticality
        or (event.isTianzhu and "tianzhu")
        or (event.isCrit and "crit")
        or "normal"
    local impact = event.impact
        or ((event.damageTag == "dot" or event.isDot) and "dot")
        or ((event.damageTag == "heavy" or event.isHeavy) and "heavy")
        or "normal"
    local sourceName = event.sourceShortName or event.sourceName

    local normalized = {
        kind = kind,
        value = value,
        text = event.text,
        source = event.source,
        target = target,
        x = x,
        y = y,
        targetKey = getTargetKey(event),
        sourceType = event.sourceType or "basic",
        sourceId = event.sourceId,
        sourceName = sourceName and M.TruncateLabel(sourceName, event.maxLabelChars or 6) or nil,
        effectId = event.effectId,
        damageTag = event.damageTag or (kind == "damage" and "normal" or kind),
        criticality = criticality,
        impact = impact,
        castId = event.castId,
        hitIndex = event.hitIndex,
        labelPolicy = event.labelPolicy,
        labelCooldown = event.labelCooldown,
        aggregatePolicy = event.aggregatePolicy,
        color = event.color,
        tag = event.tag,
    }
    normalized.labelPolicy = normalized.labelPolicy or defaultLabelPolicy(normalized)
    normalized.style = M.ResolveStyle(normalized)
    normalized.priority = event.priority or normalized.style.priority
    normalized.text = resolveText(normalized)
    normalized.tag = normalized.tag
        or (criticality == "tianzhu" and "天诛")
        or (criticality == "crit" and "暴击")
        or (kind == "absorb" and "吸收")
        or nil
    return normalized
end

function M.Emit(event)
    local item = normalize(event)
    if not item then return false, nil end
    if tryAggregate(item) then return true, "aggregated" end
    if not ensureCapacity(item) then return false, "capacity" end

    local showLabel, labelKey, castLabelKey = shouldShowLabel(item)
    item.label = showLabel and item.sourceName or nil
    if labelKey and showLabel then labelSeenAt[labelKey] = now end
    if castLabelKey and showLabel then
        local state = castLabelStates[castLabelKey]
        if state then
            state.count = state.count + 1
            state.seenAt = now
        else
            castLabelStates[castLabelKey] = { count = 1, seenAt = now }
        end
    end

    local laneIndex, stackCount = chooseLane(item.targetKey)
    item.laneIndex = laneIndex
    item.laneX = Config.LANES[laneIndex]
    item.stackY = math_min(12, stackCount * 3)
    item.elapsed = 0
    item.duration = item.style.animation.duration
    item.hitCount = 1
    item.aggregatePulse = 0
    nextItemId = nextItemId + 1
    item.id = nextItemId
    items[#items + 1] = item
    return true, item
end

function M.EmitDamage(event)
    event.kind = "damage"
    return M.Emit(event)
end

function M.EmitHeal(event)
    event.kind = "heal"
    return M.Emit(event)
end

function M.EmitHurt(event)
    event.kind = "hurt"
    return M.Emit(event)
end

function M.EmitStatus(event)
    event.kind = event.kind or "status"
    return M.Emit(event)
end

function M.NextCastId(prefix)
    nextCastId = nextCastId + 1
    return tostring(prefix or "cast") .. ":" .. tostring(nextCastId)
end

function M.Update(dt)
    dt = math_max(0, tonumber(dt) or 0)
    now = now + dt
    cleanupTimer = cleanupTimer + dt
    local write = 1
    for read = 1, #items do
        local item = items[read]
        item.elapsed = item.elapsed + dt
        if item.elapsed < item.duration then
            items[write] = item
            write = write + 1
        end
    end
    for i = write, #items do items[i] = nil end

    if cleanupTimer >= 5 then
        cleanupTimer = 0
        for key, seenAt in pairs(labelSeenAt) do
            if now - seenAt > 5 then labelSeenAt[key] = nil end
        end
        for key, state in pairs(castLabelStates) do
            if now - state.seenAt > 5 then castLabelStates[key] = nil end
        end
    end
end

function M.Evaluate(item, out)
    out = out or {}
    local progress = clamp(item.elapsed / item.duration, 0, 1)
    local animation = item.style.animation
    local alpha = 1
    if progress < 0.06 then
        alpha = progress / 0.06
    elseif progress > 0.70 then
        alpha = 1 - (progress - 0.70) / 0.30
    end
    alpha = clamp(alpha, 0, 1)

    local scale
    if progress <= animation.peakAt then
        local t = progress / animation.peakAt
        scale = animation.startScale
            + (animation.peakScale - animation.startScale) * easeOutQuad(t)
    elseif progress <= animation.settleAt then
        local t = (progress - animation.peakAt) / (animation.settleAt - animation.peakAt)
        scale = animation.peakScale + (1 - animation.peakScale) * easeOutQuad(t)
    else
        scale = 1
    end
    if (item.aggregatePulse or 0) > 0 and progress < 0.20 then
        scale = scale + math_min(0.12, item.aggregatePulse * 0.03)
    end

    local eased = easeOutCubic(progress)
    local laneSign = item.laneX < 0 and -1 or (item.laneX > 0 and 1 or 0)
    out.progress = progress
    out.alpha = alpha
    out.scale = scale
    out.offsetX = item.laneX + laneSign * animation.driftX * eased
    out.offsetY = -item.stackY - animation.travelY * eased
    out.fontSize = item.style.fontSize * scale
    out.labelSize = item.style.labelSize
    out.tagSize = item.style.tagSize
    return out
end

function M.GetItems()
    return items
end

function M.GetStats()
    local targets = {}
    local maxPerTarget = 0
    for i = 1, #items do
        local key = items[i].targetKey
        targets[key] = (targets[key] or 0) + 1
        maxPerTarget = math_max(maxPerTarget, targets[key])
    end
    local labelCount = 0
    for _ in pairs(labelSeenAt) do labelCount = labelCount + 1 end
    return {
        active = #items,
        targetCount = maxPerTarget,
        labelCache = labelCount,
    }
end

function M.Clear()
    items = {}
    labelSeenAt = {}
    castLabelStates = {}
    targetIds = setmetatable({}, { __mode = "k" })
    now = 0
    nextItemId = 0
    nextCastId = 0
    nextTargetId = 0
    cleanupTimer = 0
end

M.ResetForTest = M.Clear
M.Config = Config

return M
