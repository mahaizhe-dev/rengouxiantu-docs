-- ============================================================================
-- AccountImmortalBodiesService.lua - server-owned account immortal bodies
-- ============================================================================

local Session = require("network.ServerSession")

local M = {}

M.STORAGE_KEY = "account_immortal_bodies"
M.LOCK_RESOURCE = "account_immortal_bodies"

local function DeepClone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[DeepClone(key, seen)] = DeepClone(child, seen)
    end
    return copy
end

---@param bodies any
---@return table
function M.Normalize(bodies)
    local normalized = type(bodies) == "table" and DeepClone(bodies) or {}
    if type(normalized.unlockedBodies) ~= "table" then
        normalized.unlockedBodies = {}
    end
    if not normalized.unlockedBodies.mortal then
        normalized.unlockedBodies.mortal = {
            unlockedAt = 0,
            source = "default",
        }
    end
    if type(normalized.bodyRewardSources) ~= "table" then
        normalized.bodyRewardSources = {}
    end
    normalized.version = math.max(2, math.floor(tonumber(normalized.version) or 2))
    return normalized
end

---@param bodies table
---@param bodyId string
---@return boolean
function M.IsBodyUnlocked(bodies, bodyId)
    local unlocked = type(bodies) == "table" and bodies.unlockedBodies or nil
    return type(unlocked) == "table" and type(unlocked[bodyId]) == "table"
end

---@param bodies table
---@param bodyId string
---@param sourceRunId string|nil
---@param sourceType string|nil
---@param slot integer|nil
---@param now integer|nil
---@return table updated
---@return table result
function M.PrepareBodyGrant(bodies, bodyId, sourceRunId, sourceType, slot, now)
    local updated = M.Normalize(bodies)
    local rewardSources = updated.bodyRewardSources

    if sourceRunId and rewardSources[sourceRunId] then
        local previous = rewardSources[sourceRunId]
        return updated, {
            bodyId = previous.bodyId or bodyId,
            duplicate = previous.duplicate == true,
            idempotent = true,
            unlocked = previous.duplicate ~= true,
        }
    end

    local duplicate = M.IsBodyUnlocked(updated, bodyId)
    if not duplicate then
        updated.unlockedBodies[bodyId] = {
            unlockedAt = now or os.time(),
            source = sourceType or "server",
            sourceRunId = sourceRunId,
            firstUnlockSlot = slot,
        }
    end

    if sourceRunId then
        rewardSources[sourceRunId] = {
            bodyId = bodyId,
            duplicate = duplicate,
            settledAt = now or os.time(),
            sourceType = sourceType or "server",
            slot = slot,
        }
    end
    updated.version = updated.version + 1

    return updated, {
        bodyId = bodyId,
        duplicate = duplicate,
        idempotent = false,
        unlocked = not duplicate,
    }
end

---@param userId integer
---@param callbacks table
function M.Fetch(userId, callbacks)
    serverCloud:BatchGet(userId)
        :Key(M.STORAGE_KEY)
        :Fetch({
            ok = function(scores)
                callbacks.ok(M.Normalize(scores[M.STORAGE_KEY]))
            end,
            error = function(code, reason)
                if callbacks.error then callbacks.error(code, reason) end
            end,
        })
end

---@param userId integer
---@param callbacks table
function M.Begin(userId, callbacks)
    if not Session.AcquireAccountLock(userId, M.LOCK_RESOURCE) then
        if callbacks.busy then callbacks.busy() end
        return
    end

    local released = false
    local function Release()
        if released then return end
        released = true
        Session.ReleaseAccountLock(userId, M.LOCK_RESOURCE)
    end

    M.Fetch(userId, {
        ok = function(bodies)
            local transaction = {
                immortalBodies = bodies,
                Release = Release,
            }

            function transaction:Save(updated, reason, saveCallbacks)
                if released then
                    if saveCallbacks.error then
                        saveCallbacks.error("LOCK_RELEASED", "transaction released")
                    end
                    return
                end
                serverCloud:BatchSet(userId)
                    :Set(M.STORAGE_KEY, M.Normalize(updated))
                    :Save(reason or "account_immortal_bodies_update", {
                        ok = function()
                            Release()
                            if saveCallbacks.ok then saveCallbacks.ok() end
                        end,
                        error = function(code, saveReason)
                            Release()
                            if saveCallbacks.error then saveCallbacks.error(code, saveReason) end
                        end,
                    })
            end

            callbacks.ok(transaction)
        end,
        error = function(code, reason)
            Release()
            if callbacks.error then callbacks.error(code, reason) end
        end,
    })
end

return M
