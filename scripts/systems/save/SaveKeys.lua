-- ============================================================================
-- SaveKeys.lua - 存档 Key 生成与 Legacy Key 兼容
-- ============================================================================

local SaveKeys = {}

-- ======== v11 统一 key 命名（S1 三键合并） ========

--- 通用 key 生成函数（v11+）
--- 所有存档 key 统一为 "{layer}_{slot}" 格式
---@param layer string "save"|"login"|"prev"|"deleted"|"premigrate"
---@param slot number 槽位号
---@return string
function SaveKeys.GetKey(layer, slot)
    return layer .. "_" .. slot
end

--- 获取指定 slot 的所有旧格式 key（v10 三键架构）
--- 用于迁移期 fallback 读取和旧 key 清理
---@param slot number
---@return table
function SaveKeys.GetLegacyKeys(slot)
    return {
        save     = "save_data_" .. slot,
        bag1     = "save_bag1_" .. slot,
        bag2     = "save_bag2_" .. slot,
        prev     = "save_prev_" .. slot,
        prevBag1 = "prev_bag1_" .. slot,
        prevBag2 = "prev_bag2_" .. slot,
        login    = "save_login_backup_" .. slot,
        loginBag1 = "login_bag1_" .. slot,
        loginBag2 = "login_bag2_" .. slot,
        backup   = "save_backup_" .. slot,
        bakBag1  = "bak_bag1_" .. slot,
        bakBag2  = "bak_bag2_" .. slot,
    }
end

-- ======== 以下为 v10 旧 key 函数（S1 迁移期保留，逐步替换后删除） ========

---@deprecated 使用 GetKey("save", slot) 或 GetLegacyKeys(slot).save
function SaveKeys.GetSaveKey(slot)
    return "save_data_" .. slot
end

---@deprecated 使用 GetKey("deleted", slot) 或 GetLegacyKeys(slot).backup
function SaveKeys.GetBackupKey(slot)
    return "save_backup_" .. slot
end

---@deprecated 使用 GetKey("prev", slot) 或 GetLegacyKeys(slot).prev
function SaveKeys.GetPrevKey(slot)
    return "save_prev_" .. slot
end

---@deprecated 使用 GetLegacyKeys(slot).bag1 — v11 后无 bag 分离
function SaveKeys.GetBag1Key(slot)
    return "save_bag1_" .. slot
end

---@deprecated
function SaveKeys.GetBag2Key(slot)
    return "save_bag2_" .. slot
end

---@deprecated
function SaveKeys.GetPrevBag1Key(slot)
    return "prev_bag1_" .. slot
end

---@deprecated
function SaveKeys.GetPrevBag2Key(slot)
    return "prev_bag2_" .. slot
end

---@deprecated
function SaveKeys.GetLoginBag1Key(slot)
    return "login_bag1_" .. slot
end

---@deprecated
function SaveKeys.GetLoginBag2Key(slot)
    return "login_bag2_" .. slot
end

---@deprecated
function SaveKeys.GetBakBag1Key(slot)
    return "bak_bag1_" .. slot
end

---@deprecated
function SaveKeys.GetBakBag2Key(slot)
    return "bak_bag2_" .. slot
end

return SaveKeys
