-- ============================================================================
-- AdminPenaltyConfig.lua — 配置驱动的账号处罚/封禁定义
--
-- 用法：在 PENALTIES 表中以 userId 为 key 添加处罚配置。
-- 每次发版生效（Lua require 在启动时加载一次）。
--
-- 字段说明：
--   denyLogin     bool   拒绝登录（HandleClientIdentity 阶段踢出）
--   punishOnce    bool   登录时执行一次性惩罚（扣仙石 + 清全部排行分数）
--   suppressRank  bool   永久压制排行写入 + 从排行查询结果中过滤
--   kickOnLogin   bool   （预留）允许登录但立即踢出
--   freezeSave    bool   （预留）禁止存档写入
--   note          string 处罚原因备注
--
-- 变更历史：
--   2026-06-01  创建 — Phase 1: 针对 UID 1364895230 (指上人间)
-- ============================================================================

local AdminPenaltyConfig = {}

--- 处罚定义表，key = userId (integer)
AdminPenaltyConfig.PENALTIES = {
    [1364895230] = {
        denyLogin    = false,   -- Phase 1: 允许登录
        punishOnce   = true,    -- 登录时扣全部仙石 + 清全部排行分数
        suppressRank = true,    -- 永久从排行榜过滤
        kickOnLogin  = false,
        freezeSave   = false,
        note         = "指上人间 — 六一活动代码审查确认作弊，Phase1 处罚",
    },
}

--- 处罚一次性操作完成后的标记 key 前缀
-- 完整 key = PREFIX .. tostring(userId)
AdminPenaltyConfig.DONE_KEY_PREFIX = "admin_penalty_done_"

--- 一次性处罚需要清零的全部排行 key 列表
AdminPenaltyConfig.RANK_KEYS_TO_CLEAR = {
    "xianshi_rank",
    "trial_floor",
    "prison_floor",
}

--- 带 slot 后缀的排行 key（会为 slot 1~5 生成 key_1 ~ key_5）
AdminPenaltyConfig.RANK_KEYS_PER_SLOT = {
    "rank2_score_",
    "rank2_kills_",
    "rank2_time_",
    "rank_score_",
    "rank_time_",
    "boss_kills_",
}

--- 带 slot 后缀的 info key（BatchSet 清空）
AdminPenaltyConfig.INFO_KEYS_PER_SLOT = {
    "rank2_info_",
    "rank_info_",
    "trial_info",
    "prison_info",
    "xianshi_info",
}

--- 最大 slot 数
AdminPenaltyConfig.MAX_SLOTS = 5

--- suppressRank 过滤时豁免的排行 key（仍显示在榜单，但分数已被清零）
AdminPenaltyConfig.RANK_KEYS_KEEP_VISIBLE = {
    ["xianshi_rank"] = true,
}

return AdminPenaltyConfig
