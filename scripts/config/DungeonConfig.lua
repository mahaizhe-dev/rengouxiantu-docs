-- ============================================================================
-- DungeonConfig.lua — 多人副本配置中心（单一事实源）
--
-- 所有副本相关的 ID、名称、数值、云端 key 前缀等全部集中于此。
-- 新增副本只需在 DUNGEONS 表中增加一条记录。
-- ============================================================================

local DungeonConfig = {}

-- ============================================================================
-- 当前默认副本 ID
-- ============================================================================
DungeonConfig.DEFAULT_DUNGEON_ID = "sishoudao"

-- ============================================================================
-- 副本定义表（按 dungeonId 索引）
-- ============================================================================
DungeonConfig.DUNGEONS = {
    sishoudao = {
        -- ——————— 标识 ———————
        id   = "sishoudao",
        name = "四兽岛",

        -- ——————— BOSS ———————
        boss = {
            name     = "枯木大圣",
            -- BOSS 属性通过公式推导（见 DungeonHandler.lua），此处仅存名称/种族/境界等配置
            level    = 70,
            category = "normal",    -- 圣级倍率在 DungeonHandler 中单独乘
            race     = "yao_king",
            realm    = "huashen_1",
            spawnX   = 13.5,        -- 8.5 + PADDING(5)，竞技场内部中心 X
            spawnY   = 14.5,        -- 9.5 + PADDING(5)，BOSS 位于竞技场上半区
            stateKey = "dungeon_boss_kumu",  -- serverCloud 持久化 key
        },

        -- ——————— 数值 ———————
        maxPlayers         = 8,
        bossRespawnInterval = 10800,  -- 3小时 = 10800秒
        snapshotInterval   = 0.1,    -- 快照广播间隔（10fps）
        respawnTimerInterval = 1.0,  -- 刷新倒计时广播间隔
        minDamageRatio     = 0.05,   -- 最低伤害比例门槛（5%）

        -- ——————— 灵韵奖励 ———————
        lingYunRewards     = { 500, 400, 300, 100, 100, 100, 100, 100 },  -- 前1~8名
        lingYunBaseReward  = 50,     -- 8名以后达标玩家的保底

        -- ——————— 圣级 BOSS 阶级倍率 ———————
        saintCategory = { hp = 50.0, atk = 2.0, def = 2.0, speed = 2.0, exp = 50.0, gold = 50.0 },
        -- 世界 BOSS 额外膨胀
        worldBossMult = { hp = 4.0 },

        -- ——————— 云端 Key ———————
        -- pending key 格式: "dungeon_pending_{dungeonId}_{slot}"
        cloudKeyPrefix = "dungeon_pending",

        -- ——————— UI 文案 ———————
        strings = {
            title         = "四兽岛副本",
            subtitle      = "世界BOSS（测试）",
            bossTitle     = "枯木大圣",
            welcome       = "欢迎来到四兽岛副本！",
            rewardTitle   = "击杀结算",
            hudBossLabel  = "枯木大圣",
            hudSettleTitle = "枯木大圣 - 击杀结算",
            arenaLabel    = "— 枯木大圣副本 —",
            npcDesc       = "一棵枯朽的巨树扎根于废寨边缘，腐朽的气息从树干裂缝中涌出。"
                         .. "据说集结数位修士可共同挑战枯木大圣，击败者可获丰厚灵韵奖励。",
            npcGuide      = "刷新: 0/3/6/9/12/15/18/21点整\n"
                         .. "BOSS: 枯木大圣（约350万血量）\n"
                         .. "人数: 最多8人，满员需等人离开\n"
                         .. "伤害: 退出或阵亡后保留，可重进\n"
                         .. "阵亡: 自动传送回入口，5秒后可重进\n"
                         .. "奖励: 按伤害排名分灵韵，≥5%可领取",
            highlightText = "⚔️ 击败枯木大圣可获灵韵奖励",
        },
    },
}

-- ============================================================================
-- 便捷方法
-- ============================================================================

--- 获取副本配置（找不到则返回 nil）
---@param dungeonId string|nil  副本ID，nil 时使用默认
---@return table|nil
function DungeonConfig.Get(dungeonId)
    return DungeonConfig.DUNGEONS[dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID]
end

--- 获取默认副本配置
---@return table
function DungeonConfig.GetDefault()
    return DungeonConfig.DUNGEONS[DungeonConfig.DEFAULT_DUNGEON_ID]
end

--- 构造 pending key
---@param dungeonId string|nil
---@param slot string|number
---@return string
function DungeonConfig.MakePendingKey(dungeonId, slot)
    local cfg = DungeonConfig.Get(dungeonId)
    local prefix = cfg and cfg.cloudKeyPrefix or "dungeon_pending"
    local id = dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID
    return prefix .. "_" .. id .. "_" .. tostring(slot)
end

--- 获取 BOSS 名称
---@param dungeonId string|nil
---@return string
function DungeonConfig.GetBossName(dungeonId)
    local cfg = DungeonConfig.Get(dungeonId)
    return cfg and cfg.boss and cfg.boss.name or "未知BOSS"
end

--- 获取副本显示名称
---@param dungeonId string|nil
---@return string
function DungeonConfig.GetDungeonName(dungeonId)
    local cfg = DungeonConfig.Get(dungeonId)
    return cfg and cfg.name or "未知副本"
end

return DungeonConfig
