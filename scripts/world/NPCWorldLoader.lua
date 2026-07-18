-- ============================================================================
-- NPCWorldLoader.lua - 世界NPC实例构建与开发期部署摘要
-- 正式世界和测试共用同一入口，避免只验证ZoneData而没有验证GameState实例。
-- ============================================================================

local M = {}

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(item, seen)
    end
    return copy
end

---@param npcData table
---@return table
function M.CopyNPC(npcData)
    return DeepCopy(npcData)
end

---@param zoneData table
---@param eventActive boolean
---@return table[]
function M.BuildList(zoneData, eventActive)
    local result = {}
    for _, npcData in ipairs(zoneData and zoneData.NPCs or {}) do
        if not npcData.eventBound or eventActive then
            result[#result + 1] = M.CopyNPC(npcData)
        end
    end
    return result
end

---@param npcs table[]
---@return table<string, table>
function M.IndexById(npcs)
    local byId = {}
    for _, npc in ipairs(npcs or {}) do
        if npc.id then byId[npc.id] = npc end
    end
    return byId
end

---@param npcs table[]
---@param zoneData table
---@param gameMap table|nil
---@return table
function M.Audit(npcs, zoneData, gameMap)
    local byId = M.IndexById(npcs)
    local required = zoneData and zoneData.REQUIRED_NPC_IDS or {}
    local missing = {}
    local zoneMismatch = {}
    local unwalkable = {}

    for _, npcId in ipairs(required) do
        local npc = byId[npcId]
        if not npc then
            missing[#missing + 1] = npcId
        elseif gameMap then
            local actualZone = gameMap:GetZoneAt(npc.x, npc.y)
            if npc.zone and actualZone ~= npc.zone then
                zoneMismatch[#zoneMismatch + 1] = npcId
                    .. ":" .. tostring(npc.zone) .. "!=" .. tostring(actualZone)
            end
            if not gameMap:IsWalkable(npc.x, npc.y) then
                unwalkable[#unwalkable + 1] = npcId
            end
        end
    end

    return {
        total = #(npcs or {}),
        required = #required,
        present = #required - #missing,
        missing = missing,
        zoneMismatch = zoneMismatch,
        unwalkable = unwalkable,
        byId = byId,
    }
end

---@param gameState table
---@param zoneData table
---@param eventActive boolean
---@param gameMap table|nil
---@param logEnabled boolean|nil
---@return table[]
---@return table
function M.Install(gameState, zoneData, eventActive, gameMap, logEnabled)
    local npcs = M.BuildList(zoneData, eventActive)
    gameState.npcs = npcs
    local audit = M.Audit(npcs, zoneData, gameMap)

    if logEnabled then
        local function Join(values)
            return #values > 0 and table.concat(values, ",") or "-"
        end
        print(string.format(
            "[NPCWorld] chapter=%s loaded=%d required=%d/%d missing=%s zoneMismatch=%s unwalkable=%s",
            tostring(zoneData and zoneData.CHAPTER_ID or "?"),
            audit.total,
            audit.present,
            audit.required,
            Join(audit.missing),
            Join(audit.zoneMismatch),
            Join(audit.unwalkable)))
    end

    return npcs, audit
end

return M
