-- ============================================================================
-- SaveBackupService.lua
--
-- Write-before-backup guard for save_{slot}. If the old save cannot be read or
-- copied to the latest backup key, the caller must not overwrite save_{slot}.
-- ============================================================================

local SaveBackupService = {}

---@param slot integer
---@return string
function SaveBackupService.BackupKey(slot)
    return "save_prewrite_backup_" .. tostring(slot)
end

---@param userId integer
---@param slot integer
---@param desc string
---@param onReady fun()
---@param onError fun(code:any, reason:any)|nil
function SaveBackupService.BeforeOverwrite(userId, slot, desc, onReady, onError)
    local saveKey = "save_" .. tostring(slot)
    local backupKey = SaveBackupService.BackupKey(slot)

    serverCloud:BatchGet(userId)
        :Key(saveKey)
        :Fetch({
            ok = function(scores)
                local current = scores and scores[saveKey]
                if type(current) ~= "table" then
                    onReady()
                    return
                end

                serverCloud:BatchSet(userId)
                    :Set(backupKey, {
                        data = current,
                        savedAt = os.time(),
                        desc = tostring(desc or ""),
                    })
                    :Save("prewrite backup " .. tostring(desc or saveKey), {
                        ok = function()
                            onReady()
                        end,
                        error = function(code, reason)
                            print("[SaveBackupService] backup write failed: userId="
                                .. tostring(userId) .. " slot=" .. tostring(slot)
                                .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
                            if onError then onError(code, reason) end
                        end,
                    })
            end,
            error = function(code, reason)
                print("[SaveBackupService] backup read failed: userId="
                    .. tostring(userId) .. " slot=" .. tostring(slot)
                    .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
                if onError then onError(code, reason) end
            end,
        })
end

return SaveBackupService
