-- ============================================================================
-- SaveState.lua - 存档系统共享状态（常量 + 运行时变量）
-- 所有子模块通过 require 此模块获取同一张表，实现状态共享
-- ============================================================================

local SaveState = {}

-- ============================================================================
-- 常量
-- ============================================================================

SaveState.MAX_SLOTS = 4                -- 最大角色槽位数
SaveState.NEW_CHAR_MAX = 4             -- 允许创建新角色的最大槽位号（1-4 全部开放）
SaveState.AUTO_SAVE_INTERVAL = 60      -- 每 1 分钟自动存档
SaveState.CURRENT_SAVE_VERSION = 19    -- 当前存档数据版本（v19: 天道问心系统 dao* 属性字段）
SaveState.DEFAULT_CHARACTER_NAME = "修仙者"  -- 旧存档迁移时的默认角色名
SaveState.CHECKPOINT_INTERVAL = 5      -- 每 N 次存档写一次定期备份（~10 分钟）
SaveState.SAVE_DEBOUNCE_INTERVAL = 3   -- 防抖间隔（秒）：3秒内多次请求合并为一次

-- ============================================================================
-- 运行时状态
-- ============================================================================

SaveState.saveTimer = 0
SaveState.loaded = false       -- 是否已成功加载存档（控制自动存档）
SaveState.saving = false       -- 是否正在保存中（包括预检阶段）
SaveState.activeSlot = nil     -- 当前活跃的角色槽位 (1 或 2)
SaveState._saveCount = 0       -- 存档计数器（用于定期备份触发）
SaveState._saveEpoch = 0       -- 存档纪元（每次 Init 递增，用于作废过期回调）
SaveState._savingStartTime = 0 -- saving 设为 true 的时刻（用于超时自动解锁）
SaveState._lastKnownCloudLevel = 0  -- 上次成功加载时的云端等级（本地安全阀用）
SaveState._retryTimer = nil    -- 存档失败后的重试计时器
SaveState._consecutiveFailures = 0  -- 连续存档失败次数
SaveState._saveTimeoutElapsed = 0   -- 存档响应超时累计（dt 精度）
SaveState._saveTimeoutActive = false -- 是否启动存档响应超时检测
SaveState._cachedSlotsIndex = nil   -- 缓存的 slots_index（由 CharacterSelectScreen 设置）
SaveState._cachedCharName = nil     -- 缓存的角色名（由 CharacterSelectScreen/main 设置）
SaveState._lastKnownCollectionCount = 0  -- 上次已知的图鉴收录数量（退化检测用）
SaveState._connCheckTimer = 0       -- 连接状态轮询计时器（W1）
SaveState._lastConnState = true     -- 上次检测到的连接状态（W1）
SaveState._disconnected = false     -- 断线暂停存档标志（W2）
SaveState._dirty = false            -- 防抖脏标记：有待写入的存档变更
SaveState._lastSaveTime = 0         -- 上次成功存档的 os.clock() 时间戳

return SaveState
