-- ============================================================================
-- Blacklist.lua - 全服统一黑名单配置
-- 所有排行榜（修仙榜、试炼榜、镇狱榜、仙石榜）+ 登录拦截共用
-- ============================================================================
-- 维护说明：
--   1. 在 userIds 中添加被封禁玩家的 TapTap userId（最精确，改名无效）
--   2. 在 charNames 中添加角色名兜底（首次命中后自动扩展为 userId 级封禁）
--   3. kickOnLogin = true 的 userId 将在服务端登录时被踢出（完全禁入游戏）
-- ============================================================================

local Blacklist = {}

-- ── 按 userId 封禁（最精确，改名/换角色无法逃避）──
Blacklist.userIds = {
    1853807222,     -- TapTap昵称"123"，角色名：一剑纵横三界/爸爸快插我/修仙者（作弊，数据异常）
    23818077,       -- 角色名"三合"，排行榜第7，太虚第一，作弊数据异常
    797347017,      -- 作弊数据异常，仙石榜保留监控
}

-- ── 按角色名封禁（辅助兜底，命中后自动扩展为 userId 级）──
Blacklist.charNames = {
    "一剑纵横三界",
    "爸爸快插我",
    "三合",           -- 排行榜第7，太虚第一，作弊数据异常
}

-- ── 仙石榜保留（这些 userId 在仙石榜不过滤，仅监控）──
Blacklist.xianshiKeep = {
    [23818077] = true,   -- "三合"，保留仙石榜监控
    [797347017] = true,  -- 保留仙石榜监控
}

-- ── TapTap 昵称监控（匹配后记录 userId，不直接封禁，避免误封）──
Blacklist.nicknames = {}

-- ── 登录拦截名单（这些 userId 连游戏都进不去）──
-- 设为 true 表示禁止登录；设为 false 或不在表中则仅排行榜屏蔽
Blacklist.kickOnLogin = {
    -- [1853807222] = true,  -- 如需完全禁入游戏，取消此注释
    -- [待填入] "指上人间" userId
}

-- ── 工具方法 ──

--- 检查 userId 是否在排行榜黑名单中
---@param userId number|string
---@return boolean
function Blacklist.IsUserBanned(userId)
    local uid = tonumber(userId)
    if not uid then return false end
    for _, bannedId in ipairs(Blacklist.userIds) do
        if bannedId == uid then return true end
    end
    return false
end

--- 检查角色名是否在黑名单中
---@param charName string
---@return boolean
function Blacklist.IsCharNameBanned(charName)
    if not charName then return false end
    for _, name in ipairs(Blacklist.charNames) do
        if name == charName then return true end
    end
    return false
end

--- 检查 userId 是否被禁止登录
---@param userId number|string
---@return boolean
function Blacklist.IsKickedOnLogin(userId)
    local uid = tonumber(userId)
    if not uid then return false end
    return Blacklist.kickOnLogin[uid] == true
end

--- 从排行榜条目列表中过滤掉黑名单玩家
--- 支持两种数据格式：
---   格式A（修仙榜）: entry.userId + entry.charName
---   格式B（试炼/镇狱/仙石榜）: item.userId
---@param entries table 排行榜条目数组
---@param charNameField string|nil 角色名字段名（nil则不检查角色名）
---@param keepSet table|nil userId集合，在此集合中的不过滤（用于仙石榜监控保留）
---@return table 过滤后的条目数组
function Blacklist.FilterRankList(entries, charNameField, keepSet)
    if not entries or #entries == 0 then return entries end

    -- 构建封禁 userId 集合
    local bannedSet = {}
    for _, uid in ipairs(Blacklist.userIds) do
        bannedSet[uid] = true
    end

    -- 如果提供了角色名字段，先扫描角色名扩展封禁集合
    if charNameField then
        for _, e in ipairs(entries) do
            local name = e[charNameField]
            if name and Blacklist.IsCharNameBanned(name) then
                local uid = tonumber(e.userId)
                if uid then bannedSet[uid] = true end
            end
        end
    end

    -- 从封禁集合中排除 keepSet 中的 userId
    if keepSet then
        for uid, _ in pairs(keepSet) do
            bannedSet[uid] = nil
        end
    end

    -- 过滤
    local filtered = {}
    for _, e in ipairs(entries) do
        local uid = tonumber(e.userId)
        if not uid or not bannedSet[uid] then
            table.insert(filtered, e)
        end
    end
    return filtered
end

return Blacklist
