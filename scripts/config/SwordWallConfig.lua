-- ============================================================================
-- SwordWallConfig.lua - 剑气长城副本配置
-- 门票型多波挑战副本：3波怪 + 结算宝箱
-- ============================================================================

local SwordWallConfig = {}

-- ── 云存储 Key ──
SwordWallConfig.POINT_KEY       = "sword_wall_points"   -- serverCloud Money 域 key
SwordWallConfig.RUN_LOG_KEY     = "sw_run_log"          -- 已结算 runId 日志
SwordWallConfig.CLAIM_LOG_KEY   = "sw_claim_log"        -- 结算明细日志
SwordWallConfig.WAL_ITEM_KEY    = "sw_wal_item"         -- 装备补发 WAL

-- ── 门票 ──
SwordWallConfig.TICKET_ITEM_ID  = "immortal_essence_blood"
SwordWallConfig.TICKET_COST     = 1

-- ── 奖励 ──
SwordWallConfig.REWARD_POINT_MIN    = 10
SwordWallConfig.REWARD_POINT_MAX    = 30
SwordWallConfig.REWARD_EQUIP_TIER   = 10
SwordWallConfig.REWARD_EQUIP_QUALITY = "cyan"
SwordWallConfig.REWARD_SET_CHANCE   = 0.30
SwordWallConfig.REWARD_SET_IDS      = { "xuesha", "qingyun", "fengmo", "haoqi" }

-- ── 副本强化倍率（剑气长城·魔劫强化）──
SwordWallConfig.BUFF = {
    atkMult   = 1.30,
    defMult   = 1.30,
    hpMult    = 1.30,
    speedMult = 1.30,
    cdrMult   = 0.70,   -- cooldown *= 0.7 即缩减30%
}

-- ── 波次配置 ──
SwordWallConfig.WAVES = {
    [1] = {
        monsters = {
            { typeId = "ch5_blood_general", count = 6 },
        },
        delayAfterClear = 1.5,  -- 全灭后延迟秒数再出下一波
    },
    [2] = {
        monsters = {
            { typeId = "ch5_abyss_marshal",   count = 1 },
            { typeId = "ch5_marshal_shugu",   count = 1 },
            { typeId = "ch5_marshal_liesoul", count = 1 },
        },
        delayAfterClear = 2.0,
    },
    [3] = {
        monsters = {
            { typeId = "ch5_sword_wall_luohou", count = 1 },
        },
        delayAfterClear = 0,  -- BOSS死后直接出宝箱
    },
}

-- ── 战斗区域坐标（以副本中央 x=40, y=72 为基准，固定不动）──
SwordWallConfig.COMBAT_CENTER  = { x = 40, y = 72 }
SwordWallConfig.SPAWN_POINTS   = {
    -- 第1波6只分散站位（宽范围散布 x=24~56）
    wave1 = {
        { x = 24, y = 72 }, { x = 32, y = 73 }, { x = 38, y = 71 },
        { x = 44, y = 73 }, { x = 50, y = 71 }, { x = 56, y = 72 },
    },
    -- 第2波3只魔帅（间隔较大）
    wave2 = {
        { x = 30, y = 72 }, { x = 40, y = 73 }, { x = 50, y = 72 },
    },
    -- 第3波BOSS（正中央）
    wave3 = {
        { x = 40, y = 72 },
    },
}

-- ── 传送/退出坐标 ──
SwordWallConfig.PLAYER_ENTER_POS = { x = 67, y = 72 }  -- 玩家传入点（剑气长城中段）
SwordWallConfig.EXIT_PORTAL_POS  = { x = 67, y = 72 }  -- 退出传送阵（与入口同位置）
SwordWallConfig.CHEST_POS        = { x = 40, y = 72 }  -- 宝箱生成位置（副本中央）
SwordWallConfig.NPC_RETURN_POS   = { x = 67, y = 63 }  -- 返回入口NPC附近安全点(藏经阁底部)

-- ── 入口NPC ──
SwordWallConfig.NPC_ID   = "sword_wall_guardian"
SwordWallConfig.NPC_NAME = "剑气长城镇守使"
SwordWallConfig.NPC_POS  = { x = 12, y = 63 }  -- 栖剑别院底部靠近回廊入口

-- ── 积分商店 ──
SwordWallConfig.SHOP = {
    -- 仙劫丹（置顶，金色品质，限购 10）
    { id = "one_turn_tribulation_pill", name = "一转仙劫丹", itemType = "consumable", consumableId = "one_turn_tribulation_pill", price = 2000, limit = 10, quality = "orange", icon = "image/icon_one_turn_tribulation_pill.png" },
    -- 封印古剑（3000 积分）
    { id = "sword_zhu",  name = "封印古剑·诛仙", itemType = "equipment", equipId = "fengyin_zhuxian_ch5",  price = 3000, icon = "image/icon_fengyin_zhuxian_ch5_20260518083648.png" },
    { id = "sword_xian", name = "封印古剑·陷仙", itemType = "equipment", equipId = "fengyin_xianxian_ch5", price = 3000, icon = "image/icon_fengyin_xianxian_ch5_20260518085543.png" },
    { id = "sword_lu",   name = "封印古剑·戮仙", itemType = "equipment", equipId = "fengyin_luxian_ch5",   price = 3000, icon = "image/icon_fengyin_luxian_ch5_20260518083709.png" },
    { id = "sword_jue",  name = "封印古剑·绝仙", itemType = "equipment", equipId = "fengyin_juexian_ch5",  price = 3000, icon = "image/icon_fengyin_juexian_ch5_20260518083649.png" },
    -- 消耗品
    { id = "spirit_pill_5",          name = "灵兽丹·伍",   itemType = "consumable", consumableId = "spirit_pill_5",          price = 500 },
    { id = "lingyun_fruit_superior", name = "上品灵韵果",  itemType = "consumable", consumableId = "lingyun_fruit_superior", price = 200 },
    { id = "exp_pill_superior",      name = "上品修炼果",  itemType = "consumable", consumableId = "exp_pill_superior",      price = 150 },
    { id = "gold_brick",             name = "金砖",        itemType = "consumable", consumableId = "gold_brick",             price = 100 },
}

-- 限购追踪 key 前缀（serverCloud score 域: "{prefix}_{userId}_{itemId}"）
SwordWallConfig.SHOP_LIMIT_KEY_PREFIX = "sw_shop_bought"

return SwordWallConfig
