-- ============================================================================
-- MilestoneLogic.lua — BOSS 里程碑纯逻辑（客户端/服务端/测试共用）
--
-- 设计目标：将"活动击杀计数 / 领取校验 / 基线初始化与迁移"从网络 handler 中
-- 抽离为无副作用的纯函数，便于在无引擎环境下做单元测试，并消除前后端口径不一致。
--
-- 数据模型（独立权威 key: evt_ms_<eventId>_<slot>）：
--   {
--     baseline = <int>,                 -- 角色登录进入活动版本时的 bossKills 快照
--     claimed  = { ["300"]=true, ... }, -- 已领取档位 map
--   }
--
-- 活动击杀数 eventKills = max(0, currentBossKills - baseline)
--   currentBossKills = max(savedBossKills, clientBossKills)
-- ============================================================================

local M = {}

--- 解析当前全局击杀数：取存档值与客户端实时值的较大值（消除存档写入竞态）
---@param savedBossKills integer|nil   存档中的全局击杀数
---@param clientBossKills integer|nil  客户端请求附带的实时击杀数
---@return integer
function M.ResolveCurrentKills(savedBossKills, clientBossKills)
    return math.max(savedBossKills or 0, clientBossKills or 0)
end

--- 计算活动击杀数
---@param currentBossKills integer|nil
---@param baseline integer|nil
---@return integer eventKills 非负
function M.ComputeEventKills(currentBossKills, baseline)
    return math.max(0, (currentBossKills or 0) - (baseline or 0))
end

--- 构建里程碑初始/迁移状态
--- 优先迁移旧 save_{slot}.event_data[eventId].bossMilestones（保留 baselineKills/claimed），
--- 否则以登录时存档的全局击杀数为基线（新角色 / 从未打开过面板）。
---@param legacy table|nil          旧 bossMilestones（可能含 baselineKills / claimed）
---@param savedBossKills integer|nil 登录时存档中的全局击杀数
---@return table state { baseline:integer, claimed:table, migrated:boolean }
function M.BuildInitialState(legacy, savedBossKills)
    if legacy and legacy.baselineKills ~= nil then
        return {
            baseline = legacy.baselineKills,
            claimed = legacy.claimed or {},
            migrated = true,
        }
    end
    return {
        baseline = savedBossKills or 0,
        claimed = {},
        migrated = false,
    }
end

--- 领取校验
---@param eventKills integer  当前活动击杀数
---@param target integer      档位阈值
---@param claimed table       已领取 map
---@return boolean ok
---@return string|nil reason  失败原因（ok=false 时有效）
function M.CheckClaim(eventKills, target, claimed)
    if eventKills < target then
        return false, "击杀数不足（需要 " .. target .. "，当前 " .. eventKills .. "）"
    end
    if claimed[tostring(target)] then
        return false, "已领取过该档位"
    end
    return true, nil
end

--- 统计已领取档位数量
---@param claimed table|nil
---@return integer
function M.CountClaimed(claimed)
    local n = 0
    if claimed then
        for _ in pairs(claimed) do n = n + 1 end
    end
    return n
end

return M
