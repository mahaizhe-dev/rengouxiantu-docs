-- ============================================================================
-- AccountCosmeticsService.lua - server-owned account cosmetic persistence
-- ============================================================================

local Session = require("network.ServerSession")

local M = {}

M.STORAGE_KEY = "account_cosmetics"
M.LOCK_RESOURCE = "account_cosmetics"

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

---@param cosmetics any
---@return table
function M.Normalize(cosmetics)
    local normalized = type(cosmetics) == "table" and DeepClone(cosmetics) or {}
    if type(normalized.petAppearances) ~= "table" then
        normalized.petAppearances = {}
    end
    if type(normalized.skinRewardSources) ~= "table" then
        normalized.skinRewardSources = {}
    end
    normalized.version = math.max(1, math.floor(tonumber(normalized.version) or 1))
    return normalized
end

---@param cosmetics table
---@param skinId string
---@return boolean
function M.IsSkinUnlocked(cosmetics, skinId)
    local appearances = type(cosmetics) == "table" and cosmetics.petAppearances or nil
    local entry = type(appearances) == "table" and appearances[skinId] or nil
    return type(entry) == "table" and entry.unlocked == true
end

---@param cosmetics table
---@param skinId string
---@param sourceRunId string|nil
---@param sourceType string|nil
---@param now integer|nil
---@return table updated
---@return table result
function M.PrepareSkinGrant(cosmetics, skinId, sourceRunId, sourceType, now)
    local updated = M.Normalize(cosmetics)
    local rewardSources = updated.skinRewardSources

    if sourceRunId and rewardSources[sourceRunId] then
        local previous = rewardSources[sourceRunId]
        return updated, {
            skinId = previous.skinId or skinId,
            duplicate = previous.duplicate == true,
            idempotent = true,
            unlocked = previous.duplicate ~= true,
        }
    end

    local duplicate = M.IsSkinUnlocked(updated, skinId)
    if not duplicate then
        updated.petAppearances[skinId] = {
            unlocked = true,
            unlockTime = now or os.time(),
            sourceType = sourceType or "server",
            sourceRunId = sourceRunId,
        }
    end

    if sourceRunId then
        rewardSources[sourceRunId] = {
            skinId = skinId,
            duplicate = duplicate,
            settledAt = now or os.time(),
            sourceType = sourceType or "server",
        }
    end
    updated.version = updated.version + 1

    return updated, {
        skinId = skinId,
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
        ok = function(cosmetics)
            local transaction = {
                cosmetics = cosmetics,
                Release = Release,
            }

            function transaction:Save(updated, reason, saveCallbacks)
                if released then
                    if saveCallbacks.error then saveCallbacks.error("LOCK_RELEASED", "transaction released") end
                    return
                end
                serverCloud:BatchSet(userId)
                    :Set(M.STORAGE_KEY, M.Normalize(updated))
                    :Save(reason or "account_cosmetics_update", {
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
