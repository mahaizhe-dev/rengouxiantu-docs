-- ============================================================================
-- AdminPenaltyControl.lua — 配置驱动的账号处罚控制模块
--
-- 对外接口：
--   .IsDenyLogin(userId)        → bool
--   .IsSuppressRank(userId)     → bool
--   .IsPunishOnce(userId)       → bool
--   .ExecutePunishOnce(userId, callbacks)  → 执行一次性惩罚
--   .FilterRankList(rankList)   → 过滤后的 rankList
--   .GetSuppressedUids()        → table (uid set)
--
-- 变更历史：
--   2026-06-01  创建 — Phase 1
-- ============================================================================

local AdminPenaltyControl = {}

local Config = require("config.AdminPenaltyConfig")
local Logger = require("utils.Logger")

local TAG = "AdminPenalty"

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 内部：统一将 userId 转为 Lua number 再查表
--- serverCloud 返回的 userId 可能是 int64 userdata，直接做 table key 匹配会失败
---@param userId any
---@return table|nil entry
local function LookupPenalty(userId)
    local key = tonumber(tostring(userId))
    if not key then return nil end
    return Config.PENALTIES[key]
end

--- 是否拒绝登录
---@param userId any
---@return boolean
function AdminPenaltyControl.IsDenyLogin(userId)
    local entry = LookupPenalty(userId)
    return entry ~= nil and entry.denyLogin == true
end

--- 是否压制排行（写入 + 查询过滤）
---@param userId any
---@return boolean
function AdminPenaltyControl.IsSuppressRank(userId)
    local entry = LookupPenalty(userId)
    return entry ~= nil and entry.suppressRank == true
end

--- 是否需要执行一次性处罚
---@param userId any
---@return boolean
function AdminPenaltyControl.IsPunishOnce(userId)
    local entry = LookupPenalty(userId)
    return entry ~= nil and entry.punishOnce == true
end

--- 获取所有被 suppressRank 的 userId 集合 (key 为 string，便于与 tostring(item.userId) 比较)
---@return table<string, boolean>
function AdminPenaltyControl.GetSuppressedUids()
    local set = {}
    for uid, entry in pairs(Config.PENALTIES) do
        if entry.suppressRank then
            set[tostring(uid)] = true
        end
    end
    return set
end

-- ============================================================================
-- 执行一次性处罚
-- ============================================================================

--- 执行一次性处罚：扣全部仙石 + 清全部排行分数
--- 幂等：通过 doneKey 标记防止重复执行
---@param userId integer
---@param callbacks? {ok?: fun(), skip?: fun(), error?: fun(reason: string)}
function AdminPenaltyControl.ExecutePunishOnce(userId, callbacks)
    callbacks = callbacks or {}
    local doneKey = Config.DONE_KEY_PREFIX .. tostring(userId)

    -- 1. 检查是否已执行过
    serverCloud:Get(userId, doneKey, {
        ok = function(scores, iscores)
            if iscores and iscores[doneKey] and iscores[doneKey] > 0 then
                Logger.info(TAG, "SKIP punishOnce: already done for userId=" .. tostring(userId))
                if callbacks.skip then callbacks.skip() end
                return
            end
            -- 2. 查仙石余额
            AdminPenaltyControl._DoDeductAndClear(userId, doneKey, callbacks)
        end,
        error = function(code, reason)
            local msg = "doneKey read FAILED: " .. tostring(code) .. " " .. tostring(reason)
            Logger.error(TAG, msg)
            if callbacks.error then callbacks.error(msg) end
        end,
    })
end

--- 内部：执行扣款 + 清排行
---@private
function AdminPenaltyControl._DoDeductAndClear(userId, doneKey, callbacks)
    serverCloud.money:Get(userId, {
        ok = function(moneys)
            local balance = (moneys and moneys.xianshi) or 0
            Logger.info(TAG, "[PUNISH] userId=" .. tostring(userId) .. " xianshi_balance=" .. balance)

            local commit = serverCloud:BatchCommit("AdminPenalty-punishOnce-" .. tostring(userId))

            -- 扣全部仙石
            if balance > 0 then
                commit:MoneyCost(userId, "xianshi", balance)
            end

            -- 清全部排行分数 (无 slot 后缀)
            for _, key in ipairs(Config.RANK_KEYS_TO_CLEAR) do
                commit:ScoreSetInt(userId, key, 0)
            end

            -- 清带 slot 后缀的排行分数
            for _, prefix in ipairs(Config.RANK_KEYS_PER_SLOT) do
                for slot = 1, Config.MAX_SLOTS do
                    commit:ScoreSetInt(userId, prefix .. slot, 0)
                end
            end

            for _, key in ipairs(Config.INFO_KEYS_TO_CLEAR or {}) do
                commit:ScoreDelete(userId, key)
            end
            for _, prefix in ipairs(Config.INFO_KEYS_PER_SLOT or {}) do
                for slot = 1, Config.MAX_SLOTS do
                    commit:ScoreDelete(userId, prefix .. slot)
                end
            end

            -- 标记已执行
            commit:ScoreSetInt(userId, doneKey, 1)

            commit:Commit({
                ok = function()
                    Logger.info(TAG, "[PUNISH] SUCCESS: userId=" .. tostring(userId)
                        .. " deducted " .. balance .. " xianshi + cleared all ranks")
                    if callbacks.ok then callbacks.ok() end
                end,
                error = function(code, reason)
                    local msg = "BatchCommit FAILED (will retry next login): "
                        .. tostring(code) .. " " .. tostring(reason)
                    Logger.error(TAG, msg)
                    if callbacks.error then callbacks.error(msg) end
                end,
            })
        end,
        error = function(code, reason)
            local msg = "money:Get FAILED: " .. tostring(code) .. " " .. tostring(reason)
            Logger.error(TAG, msg)
            if callbacks.error then callbacks.error(msg) end
        end,
    })
end

-- ============================================================================
-- 排行榜过滤
-- ============================================================================

--- 从排行榜结果中过滤掉被 suppressRank 的用户
--- 对于 RANK_KEYS_KEEP_VISIBLE 中的 rankKey（如 xianshi_rank），不过滤（保留显示，分数已清零）
---@param rankList table[] 原始排行榜数组 (每项有 .userId 字段)
---@param rankKey? string 当前查询的排行榜 key
---@return table[] 过滤后的数组
function AdminPenaltyControl.FilterRankList(rankList, rankKey)
    if not rankList or #rankList == 0 then
        return rankList
    end

    -- 若该 rankKey 在豁免列表中，不做过滤
    if rankKey and Config.RANK_KEYS_KEEP_VISIBLE[rankKey] then
        return rankList
    end

    local suppressedUids = AdminPenaltyControl.GetSuppressedUids()
    if not next(suppressedUids) then
        return rankList
    end

    local filtered = {}
    for _, item in ipairs(rankList) do
        if not suppressedUids[tostring(item.userId)] then
            table.insert(filtered, item)
        end
    end
    return filtered
end

return AdminPenaltyControl
