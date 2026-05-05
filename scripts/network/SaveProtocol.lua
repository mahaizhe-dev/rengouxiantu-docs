-- ============================================================================
-- SaveProtocol.lua - C/S 存档协议：事件定义 + 注册
--
-- 职责：
--   1. 定义所有客户端↔服务端的远程事件名称
--   2. 提供 RegisterAll() 统一注册（客户端和服务端都调用）
--
-- 使用方法：
--   local SaveProtocol = require("network.SaveProtocol")
--   SaveProtocol.RegisterAll()  -- 在 Start() 中调用
-- ============================================================================

local SaveProtocol = {}

-- ============================================================================
-- 事件名称常量
-- ============================================================================

--- 客户端 → 服务端（C2S）
SaveProtocol.C2S_FetchSlots   = "C2S_FetchSlots"     -- 请求槽位列表
SaveProtocol.C2S_CreateChar   = "C2S_CreateChar"      -- 创建新角色
SaveProtocol.C2S_DeleteChar   = "C2S_DeleteChar"      -- 删除角色
SaveProtocol.C2S_LoadGame     = "C2S_LoadGame"        -- 加载存档
SaveProtocol.C2S_SaveGame     = "C2S_SaveGame"        -- 保存存档
SaveProtocol.C2S_MigrateData  = "C2S_MigrateData"     -- clientScore → serverCloud 迁移
SaveProtocol.C2S_GetRankList  = "C2S_GetRankList"     -- 请求排行榜
SaveProtocol.C2S_VersionHandshake = "C2S_VersionHandshake"  -- 版本握手
SaveProtocol.C2S_DaoTreeStart    = "C2S_DaoTreeStart"     -- 请求开始参悟
SaveProtocol.C2S_DaoTreeComplete = "C2S_DaoTreeComplete"  -- 完成10秒读条
SaveProtocol.C2S_GMResetDaily    = "C2S_GMResetDaily"     -- GM: 重置所有日常
SaveProtocol.C2S_DaoTreeQuery    = "C2S_DaoTreeQuery"     -- 查询悟道树每日状态
SaveProtocol.C2S_SealDemonAccept = "C2S_SealDemonAccept"  -- 接取封魔任务
SaveProtocol.C2S_SealDemonBossKilled = "C2S_SealDemonBossKilled" -- 封魔BOSS击杀上报
SaveProtocol.C2S_SealDemonAbandon = "C2S_SealDemonAbandon" -- 放弃封魔任务
SaveProtocol.C2S_TrialClaimDaily  = "C2S_TrialClaimDaily"   -- 试炼塔领取每日供奉
SaveProtocol.C2S_GMCommand        = "C2S_GMCommand"          -- GM: 管理员命令（需权限校验）
SaveProtocol.C2S_BuyPill          = "C2S_BuyPill"            -- 购买丹药（服务端校验）
SaveProtocol.C2S_RedeemCode       = "C2S_RedeemCode"         -- 兑换码兑换
SaveProtocol.C2S_GMCreateCode     = "C2S_GMCreateCode"       -- GM: 创建兑换码
SaveProtocol.C2S_TryUnlockRace    = "C2S_TryUnlockRace"      -- 竞速道印占位请求
SaveProtocol.C2S_RedeemAck        = "C2S_RedeemAck"            -- 兑换码奖励确认回执
SaveProtocol.C2S_ServerApiTest    = "C2S_ServerApiTest"        -- 服务端 API 验证(C4/C5)
-- 万界黑商
SaveProtocol.C2S_BlackMerchantQuery    = "C2S_BMQuery"          -- 查询商品库存+仙石+持有量
SaveProtocol.C2S_BlackMerchantBuy      = "C2S_BMBuy"            -- 从黑商购买物品
SaveProtocol.C2S_BlackMerchantSell     = "C2S_BMSell"           -- 向黑商出售物品
SaveProtocol.C2S_BlackMerchantExchange = "C2S_BMExchange"       -- 灵韵↔仙石兑换
SaveProtocol.C2S_BlackMerchantHistory  = "C2S_BMHistory"        -- 查询交易记录
-- 五一世界掉落活动
SaveProtocol.C2S_EventExchange       = "C2S_EvtExchange"       -- 活动兑换请求
SaveProtocol.C2S_EventOpenFudai      = "C2S_EvtOpenFudai"      -- 开启福袋（count=1或10）
SaveProtocol.C2S_EventGetRankList    = "C2S_EvtGetRank"        -- 查询福袋排行榜
SaveProtocol.C2S_EventGetPullRecords = "C2S_EvtGetPull"        -- 查询全服抽取记录
-- 多人副本（四兽岛）
SaveProtocol.C2S_EnterDungeon    = "C2S_EnterDungeon"     -- 请求进入副本
SaveProtocol.C2S_LeaveDungeon    = "C2S_LeaveDungeon"     -- 请求离开副本
SaveProtocol.C2S_PlayerPosition  = "C2S_PlayerPosition"   -- 上报位置 (10fps)
SaveProtocol.C2S_DungeonAttack   = "C2S_DungeonAttack"    -- 请求攻击 BOSS
SaveProtocol.C2S_QueryDungeonReward = "C2S_QueryDungeonReward" -- 查询待领取副本奖励
SaveProtocol.C2S_ClaimDungeonReward = "C2S_ClaimDungeonReward" -- 领取副本奖励

--- 服务端 → 客户端（S2C）
SaveProtocol.S2C_SlotsData    = "S2C_SlotsData"       -- 返回槽位列表
SaveProtocol.S2C_CharResult   = "S2C_CharResult"      -- 创建/删除角色结果
SaveProtocol.S2C_LoadResult   = "S2C_LoadResult"      -- 返回存档数据
SaveProtocol.S2C_SaveResult   = "S2C_SaveResult"      -- 保存结果
SaveProtocol.S2C_MigrateResult = "S2C_MigrateResult"  -- 迁移结果
SaveProtocol.S2C_RankListData = "S2C_RankListData"    -- 排行榜数据
SaveProtocol.S2C_ForceUpdate  = "S2C_ForceUpdate"     -- 强制更新（版本过旧）
SaveProtocol.S2C_Maintenance  = "S2C_Maintenance"     -- 维护通知
SaveProtocol.S2C_DaoTreeStartResult = "S2C_DaoTreeStartResult"  -- 参悟验证结果
SaveProtocol.S2C_DaoTreeReward      = "S2C_DaoTreeReward"       -- 参悟奖励结果
SaveProtocol.S2C_GMResetDailyResult = "S2C_GMResetDailyResult"  -- GM: 重置日常结果
SaveProtocol.S2C_DaoTreeQueryResult = "S2C_DaoTreeQueryResult"  -- 悟道树每日状态结果
SaveProtocol.S2C_SealDemonAcceptResult = "S2C_SealDemonAcceptResult" -- 接取封魔任务结果
SaveProtocol.S2C_SealDemonReward = "S2C_SealDemonReward"   -- 封魔奖励发放
SaveProtocol.S2C_SealDemonAbandonResult = "S2C_SealDemonAbandonResult" -- 放弃封魔结果
SaveProtocol.S2C_TrialClaimDailyResult  = "S2C_TrialClaimDailyResult"   -- 试炼塔每日供奉结果
SaveProtocol.S2C_GMCommandResult  = "S2C_GMCommandResult"    -- GM: 管理员命令结果
SaveProtocol.S2C_BuyPillResult    = "S2C_BuyPillResult"      -- 购买丹药结果
SaveProtocol.S2C_RedeemResult     = "S2C_RedeemResult"       -- 兑换码兑换结果
SaveProtocol.S2C_GMCreateCodeResult = "S2C_GMCreateCodeResult" -- GM: 创建兑换码结果
SaveProtocol.S2C_TryUnlockRaceResult = "S2C_TryUnlockRaceResult" -- 竞速道印占位结果
SaveProtocol.S2C_ServerApiTestResult = "S2C_ServerApiTestResult" -- 服务端 API 验证结果
-- 万界黑商
SaveProtocol.S2C_BlackMerchantData           = "S2C_BMData"           -- 商品列表+仙石+境界
SaveProtocol.S2C_BlackMerchantResult         = "S2C_BMResult"         -- 买/卖交易结果
SaveProtocol.S2C_BlackMerchantExchangeResult = "S2C_BMExchangeResult" -- 兑换结果
SaveProtocol.S2C_BlackMerchantHistory        = "S2C_BMHistory"        -- 交易记录列表
-- 五一世界掉落活动
SaveProtocol.S2C_EventExchangeResult  = "S2C_EvtExResult"      -- 兑换结果
SaveProtocol.S2C_EventOpenFudaiResult = "S2C_EvtFudaiResult"   -- 福袋奖励结果
SaveProtocol.S2C_EventRankListData    = "S2C_EvtRankData"      -- 排行榜数据
SaveProtocol.S2C_EventPullRecordsData = "S2C_EvtPullData"      -- 全服抽取记录列表
-- 多人副本（四兽岛）
SaveProtocol.S2C_EnterDungeonResult = "S2C_EnterDungeonResult" -- 进入副本结果
SaveProtocol.S2C_DungeonState       = "S2C_DungeonState"       -- 副本完整状态（进入时）
SaveProtocol.S2C_DungeonSnapshot    = "S2C_DungeonSnapshot"    -- 位置快照 (10fps)
SaveProtocol.S2C_PlayerJoined       = "S2C_PlayerJoined"       -- 新玩家进入
SaveProtocol.S2C_PlayerLeft         = "S2C_PlayerLeft"         -- 玩家离开
SaveProtocol.S2C_AttackResult       = "S2C_AttackResult"       -- 攻击结果
SaveProtocol.S2C_BossAttackPlayer   = "S2C_BossAttackPlayer"   -- BOSS攻击玩家（仅被攻击者）
SaveProtocol.S2C_BossAttackAnim     = "S2C_BossAttackAnim"     -- BOSS攻击动画（旁观者）
SaveProtocol.S2C_BossSkill          = "S2C_BossSkill"          -- BOSS放技能
SaveProtocol.S2C_BossDefeated       = "S2C_BossDefeated"       -- 击杀结算
SaveProtocol.S2C_BossRespawned      = "S2C_BossRespawned"      -- BOSS刷新
SaveProtocol.S2C_BossRespawnTimer   = "S2C_BossRespawnTimer"   -- 刷新倒计时 (1fps)
SaveProtocol.S2C_DungeonRewardInfo  = "S2C_DungeonRewardInfo"  -- 待领取副本奖励信息
SaveProtocol.S2C_ClaimDungeonRewardResult = "S2C_ClaimDungeonResult" -- 领取副本奖励结果
-- 通用
SaveProtocol.S2C_RateLimited  = "S2C_RateLimited"     -- 服务端速率限制反馈


-- ============================================================================
-- 事件列表（用于批量注册）
-- ============================================================================

SaveProtocol.ALL_EVENTS = {
    -- C2S
    SaveProtocol.C2S_FetchSlots,
    SaveProtocol.C2S_CreateChar,
    SaveProtocol.C2S_DeleteChar,
    SaveProtocol.C2S_LoadGame,
    SaveProtocol.C2S_SaveGame,
    SaveProtocol.C2S_MigrateData,
    SaveProtocol.C2S_GetRankList,
    SaveProtocol.C2S_VersionHandshake,
    SaveProtocol.C2S_DaoTreeStart,
    SaveProtocol.C2S_DaoTreeComplete,
    SaveProtocol.C2S_GMResetDaily,
    SaveProtocol.C2S_DaoTreeQuery,
    SaveProtocol.C2S_SealDemonAccept,
    SaveProtocol.C2S_SealDemonBossKilled,
    SaveProtocol.C2S_SealDemonAbandon,
    SaveProtocol.C2S_TrialClaimDaily,
    SaveProtocol.C2S_GMCommand,
    SaveProtocol.C2S_BuyPill,
    SaveProtocol.C2S_RedeemCode,
    SaveProtocol.C2S_GMCreateCode,
    SaveProtocol.C2S_TryUnlockRace,
    SaveProtocol.C2S_RedeemAck,
    SaveProtocol.C2S_ServerApiTest,
    -- S2C
    SaveProtocol.S2C_SlotsData,
    SaveProtocol.S2C_CharResult,
    SaveProtocol.S2C_LoadResult,
    SaveProtocol.S2C_SaveResult,
    SaveProtocol.S2C_MigrateResult,
    SaveProtocol.S2C_RankListData,
    SaveProtocol.S2C_ForceUpdate,
    SaveProtocol.S2C_Maintenance,
    SaveProtocol.S2C_DaoTreeStartResult,
    SaveProtocol.S2C_DaoTreeReward,
    SaveProtocol.S2C_GMResetDailyResult,
    SaveProtocol.S2C_DaoTreeQueryResult,
    SaveProtocol.S2C_SealDemonAcceptResult,
    SaveProtocol.S2C_SealDemonReward,
    SaveProtocol.S2C_SealDemonAbandonResult,
    SaveProtocol.S2C_TrialClaimDailyResult,
    SaveProtocol.S2C_GMCommandResult,
    SaveProtocol.S2C_BuyPillResult,
    SaveProtocol.S2C_RedeemResult,
    SaveProtocol.S2C_GMCreateCodeResult,
    SaveProtocol.S2C_TryUnlockRaceResult,
    SaveProtocol.S2C_ServerApiTestResult,
    -- 万界黑商
    SaveProtocol.C2S_BlackMerchantQuery,
    SaveProtocol.C2S_BlackMerchantBuy,
    SaveProtocol.C2S_BlackMerchantSell,
    SaveProtocol.C2S_BlackMerchantExchange,
    SaveProtocol.C2S_BlackMerchantHistory,
    SaveProtocol.S2C_BlackMerchantData,
    SaveProtocol.S2C_BlackMerchantResult,
    SaveProtocol.S2C_BlackMerchantExchangeResult,
    SaveProtocol.S2C_BlackMerchantHistory,
    -- 五一世界掉落活动
    SaveProtocol.C2S_EventExchange,
    SaveProtocol.C2S_EventOpenFudai,
    SaveProtocol.C2S_EventGetRankList,
    SaveProtocol.C2S_EventGetPullRecords,
    SaveProtocol.S2C_EventExchangeResult,
    SaveProtocol.S2C_EventOpenFudaiResult,
    SaveProtocol.S2C_EventRankListData,
    SaveProtocol.S2C_EventPullRecordsData,
    -- 多人副本（四兽岛）
    SaveProtocol.C2S_EnterDungeon,
    SaveProtocol.C2S_LeaveDungeon,
    SaveProtocol.C2S_PlayerPosition,
    SaveProtocol.C2S_DungeonAttack,
    SaveProtocol.C2S_QueryDungeonReward,
    SaveProtocol.C2S_ClaimDungeonReward,
    SaveProtocol.S2C_EnterDungeonResult,
    SaveProtocol.S2C_DungeonState,
    SaveProtocol.S2C_DungeonSnapshot,
    SaveProtocol.S2C_PlayerJoined,
    SaveProtocol.S2C_PlayerLeft,
    SaveProtocol.S2C_AttackResult,
    SaveProtocol.S2C_BossAttackPlayer,
    SaveProtocol.S2C_BossAttackAnim,
    SaveProtocol.S2C_BossSkill,
    SaveProtocol.S2C_BossDefeated,
    SaveProtocol.S2C_BossRespawned,
    SaveProtocol.S2C_BossRespawnTimer,
    SaveProtocol.S2C_DungeonRewardInfo,
    SaveProtocol.S2C_ClaimDungeonRewardResult,
    -- 通用
    SaveProtocol.S2C_RateLimited,
}

-- ============================================================================
-- 注册
-- ============================================================================

--- 注册所有远程事件（客户端和服务端均需调用）
function SaveProtocol.RegisterAll()
    for _, eventName in ipairs(SaveProtocol.ALL_EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
    print("[SaveProtocol] Registered " .. #SaveProtocol.ALL_EVENTS .. " remote events")
end

return SaveProtocol
