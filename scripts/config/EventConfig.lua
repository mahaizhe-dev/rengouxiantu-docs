-- ============================================================================
-- EventConfig.lua — 通用活动掉落框架配置
--
-- 职责：定义当前激活的活动（道具/掉率/奖池/排行榜）
-- 当前活动：情人节世界掉落活动
--
-- 换活动时：替换 ACTIVE_EVENT 配置块即可
-- ============================================================================

local EventConfig = {}

-- ═══════════════════════════════════════
-- 当前激活的活动（同一时间只有一个活动）
-- ═══════════════════════════════════════
EventConfig.ACTIVE_EVENT = {
    eventId = "valentine_2027",
    enabled = true,
    name = "情缘天降",
    npcName = "月老仙使",
    npcSubtitle = "情人节活动宝箱",
    npcPortrait = "Textures/npc_valentine_fairy.png",
    npcDialog = "情丝入世，月老赐缘。\n击败BOSS掉落同心红线开小宝箱，\n高境界BOSS还会掉落鸳鸯玉佩开大宝箱！",

    -- ═══ 活动道具 ID 列表（用于 LootSystem 掉落判定）═══
    items = {
        "valentine_red_thread", "valentine_pair_jade",
    },

    -- ═══ 双宝箱开启物定义 ═══
    openBoxes = {
        small = {
            itemId = "valentine_red_thread",
            score = 1,
            poolKey = "smallBoxPool",
        },
        big = {
            itemId = "valentine_pair_jade",
            score = 10,
            poolKey = "bigBoxPool",
        },
    },

    acquisitionTips = {
        small = "同心红线：击败各章节BOSS掉落（章节越高概率越大）",
        big = "鸳鸯玉佩：击败元婴及以上BOSS掉落（最高掉落四仙剑1%）",
    },

    -- ═══ 普通开启物（同心红线）掉率：[chapterId][category] ═══
    dropRates = {
        [1] = {
            boss      = { valentine_red_thread = 0.01 },
            king_boss = { valentine_red_thread = 0.015 },
        },
        [2] = {
            boss      = { valentine_red_thread = 0.015 },
            king_boss = { valentine_red_thread = 0.02 },
        },
        [3] = {
            boss         = { valentine_red_thread = 0.02 },
            king_boss    = { valentine_red_thread = 0.03 },
            emperor_boss = { valentine_red_thread = 0.04 },
        },
        [4] = {
            boss         = { valentine_red_thread = 0.03 },
            king_boss    = { valentine_red_thread = 0.04 },
            emperor_boss = { valentine_red_thread = 0.05 },
        },
        [5] = {
            king_boss    = { valentine_red_thread = 0.04 },
            emperor_boss = { valentine_red_thread = 0.05 },
            saint_boss   = { valentine_red_thread = 0.06 },
        },
        [101] = {
            king_boss    = { valentine_red_thread = 0.04 },
            emperor_boss = { valentine_red_thread = 0.05 },
        },
        [6] = {
            boss         = { valentine_red_thread = 0.02 },
            king_boss    = { valentine_red_thread = 0.03 },
            emperor_boss = { valentine_red_thread = 0.05 },
            saint_boss   = { valentine_red_thread = 0.06 },
        },
    },

    -- ═══ 稀有开启物（鸳鸯玉佩）掉率：按怪物境界 monster.realm ═══
    realmDropRates = {
        yuanying_1 = { valentine_pair_jade = 0.002 },
        yuanying_2 = { valentine_pair_jade = 0.002 },
        yuanying_3 = { valentine_pair_jade = 0.002 },
        huashen_1  = { valentine_pair_jade = 0.003 },
        huashen_2  = { valentine_pair_jade = 0.003 },
        huashen_3  = { valentine_pair_jade = 0.003 },
        heti_1     = { valentine_pair_jade = 0.004 },
        heti_2     = { valentine_pair_jade = 0.004 },
        heti_3     = { valentine_pair_jade = 0.004 },
        dacheng_1  = { valentine_pair_jade = 0.006 },
        dacheng_2  = { valentine_pair_jade = 0.006 },
        dacheng_3  = { valentine_pair_jade = 0.006 },
        dacheng_4  = { valentine_pair_jade = 0.006 },
        dujie_1    = { valentine_pair_jade = 0.008 },
        dujie_2    = { valentine_pair_jade = 0.008 },
        dujie_3    = { valentine_pair_jade = 0.008 },
        dujie_4    = { valentine_pair_jade = 0.008 },
    },

    -- ═══ 特殊覆盖（优先于 realmDropRates，按 typeId 精确控制）═══
    monsterOverrides = {
        -- 第五章·四仙剑
        ch5_sword_zhu  = { valentine_pair_jade = 0.01 },
        ch5_sword_xian = { valentine_pair_jade = 0.01 },
        ch5_sword_lu   = { valentine_pair_jade = 0.01 },
        ch5_sword_jue  = { valentine_pair_jade = 0.01 },
        -- 第六章·呱大王/魔君（圣级）: 1.2%
        ch6_gua_master     = { valentine_pair_jade = 0.012 },
        ch6_mojun_shixuan  = { valentine_pair_jade = 0.012 },
        -- 第六章·哼元帅/哈元帅: 1%
        ch6_heng_marshal   = { valentine_pair_jade = 0.01 },
        ch6_ha_marshal     = { valentine_pair_jade = 0.01 },
        -- 第六章·其他皇级BOSS: 0.8%（王级/普通BOSS不掉落，故不列入）
        ch6_lingfeng       = { valentine_pair_jade = 0.008 },
        ch6_zhuyou         = { valentine_pair_jade = 0.008 },
        ch6_duanyue        = { valentine_pair_jade = 0.008 },
        ch6_pojun          = { valentine_pair_jade = 0.008 },
        ch6_zhenyuan       = { valentine_pair_jade = 0.008 },
        ch6_qingfeng       = { valentine_pair_jade = 0.008 },
        ch6_leice          = { valentine_pair_jade = 0.008 },
    },

    -- ═══ 活动食品掉落已移除（红豆糕不再世界掉落，仅通过开箱获取）═══

    -- ═══ 兑换商品表（本活动不启用兑换）═══
    exchanges = {},

    -- ═══ BOSS 击杀里程碑任务（10 档，每档奖励鸳鸯玉佩 ×1）═══
    bossMilestones = {
        { id = "valentine_boss_300",  target = 300,  reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_600",  target = 600,  reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_900",  target = 900,  reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_1200", target = 1200, reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_1500", target = 1500, reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_1800", target = 1800, reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_2100", target = 2100, reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_2400", target = 2400, reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_2700", target = 2700, reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "valentine_boss_3000", target = 3000, reward = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
    },

    -- ═══ 小宝箱奖池（总权重 1000）═══
    smallBoxPool = {
        { id = "small_bone_15", name = "肉骨头×15",     weight = 150, rarity = "common",
          rewards = { { type = "consumable", id = "meat_bone", count = 15 } } },
        { id = "small_meat_5",  name = "灵肉×5",        weight = 150, rarity = "common",
          rewards = { { type = "consumable", id = "spirit_meat", count = 5 } } },
        { id = "small_ly_10",   name = "灵韵×10",       weight = 150, rarity = "common",
          rewards = { { type = "lingYun", count = 10 } } },
        { id = "small_ly_20",   name = "灵韵×20",       weight = 120, rarity = "common",
          rewards = { { type = "lingYun", count = 20 } } },
        { id = "small_bone_im", name = "仙骨×1",        weight = 120, rarity = "common",
          rewards = { { type = "consumable", id = "immortal_bone", count = 1 } } },
        { id = "small_bar_10",  name = "金条×10",       weight = 100, rarity = "common",
          rewards = { { type = "consumable", id = "gold_bar", count = 10 } } },
        { id = "small_ly_30",   name = "灵韵×30",       weight = 50,  rarity = "rare",
          rewards = { { type = "lingYun", count = 30 } } },
        { id = "small_pill_1",  name = "修炼果×1",      weight = 50,  rarity = "rare",
          rewards = { { type = "consumable", id = "exp_pill", count = 1 } } },
        { id = "small_bar_15",  name = "金条×15",       weight = 50,  rarity = "rare",
          rewards = { { type = "consumable", id = "gold_bar", count = 15 } } },
        { id = "small_ly_fruit",name = "灵韵果×1",      weight = 30,  rarity = "rare",
          rewards = { { type = "consumable", id = "lingyun_fruit", count = 1 } } },
        { id = "small_pair_jade", name = "鸳鸯玉佩×1",  weight = 20,  rarity = "legendary",
          rewards = { { type = "consumable", id = "valentine_pair_jade", count = 1 } } },
        { id = "small_redbean_cake", name = "相思红豆糕×1", weight = 10, rarity = "legendary",
          rewards = { { type = "consumable", id = "valentine_xiangsi_redbean_cake", count = 1 } } },
    },

    -- ═══ 大宝箱奖池（总权重 1000）═══
    bigBoxPool = {
        { id = "big_ly_100",    name = "灵韵×100",      weight = 200, rarity = "common",
          rewards = { { type = "lingYun", count = 100 } } },
        { id = "big_ly_150",    name = "灵韵×150",      weight = 150, rarity = "common",
          rewards = { { type = "lingYun", count = 150 } } },
        { id = "big_ly_200",    name = "灵韵×200",      weight = 150, rarity = "common",
          rewards = { { type = "lingYun", count = 200 } } },
        { id = "big_gold_30k",  name = "金币×30000",    weight = 100, rarity = "common",
          rewards = { { type = "gold", count = 30000 } } },
        { id = "big_ly_fruit",  name = "上品灵韵果×1",  weight = 30,  rarity = "rare",
          rewards = { { type = "consumable", id = "lingyun_fruit_superior", count = 1 } } },
        { id = "big_exp_pill",  name = "上品修炼果×1",  weight = 50,  rarity = "rare",
          rewards = { { type = "consumable", id = "exp_pill_superior", count = 1 } } },
        { id = "big_brick",     name = "金砖×1",        weight = 30,  rarity = "rare",
          rewards = { { type = "consumable", id = "gold_brick", count = 1 } } },
        { id = "big_marrow",    name = "龙髓×1",        weight = 60,  rarity = "common",
          rewards = { { type = "consumable", id = "dragon_marrow", count = 1 } } },
        { id = "big_essence_2", name = "妖兽精华×2",    weight = 100, rarity = "common",
          rewards = { { type = "consumable", id = "demon_essence", count = 2 } } },
        { id = "big_ly_300",    name = "灵韵×300",      weight = 60,  rarity = "rare",
          rewards = { { type = "lingYun", count = 300 } } },
        { id = "big_ly_400",    name = "灵韵×400",      weight = 40,  rarity = "rare",
          rewards = { { type = "lingYun", count = 400 } } },
        { id = "big_redbean_cake", name = "相思红豆糕×1", weight = 20, rarity = "legendary",
          rewards = { { type = "consumable", id = "valentine_xiangsi_redbean_cake", count = 1 } } },
        { id = "big_skin",      name = "根骨皮肤",      weight = 10,  rarity = "legendary",
          rewards = { { type = "petSkin", id = "pet_premium_gengu", dupLingYun = 5000 } } },
    },

    -- ═══ 保底机制（按箱型独立计数，命中后重置）═══
    pity = {
        small = { threshold = 120, targetId = "small_redbean_cake" },
        big   = { threshold = 120, targetId = "big_skin" },
    },

    -- ═══ 大奖弹窗触发条目（命中这些条目ID时弹"恭喜获得大奖"窗口）═══
    jackpotIds = {
        small_pair_jade = true,
        small_redbean_cake = true,
        big_redbean_cake = true,
        big_skin = true,
    },

    -- ═══ 黑市商品（仅供参考，实际价格以 BlackMerchantConfig.lua 为准）═══
    blackMarketItems = {
        valentine_red_thread = { name = "同心红线", buy_price = 1, sell_price = 2, category = "consumable", boss = "各章节BOSS" },
        valentine_pair_jade = { name = "鸳鸯玉佩", buy_price = 6, sell_price = 12, category = "consumable", boss = "高境界BOSS/里程碑" },
        valentine_xiangsi_redbean_cake = { name = "相思红豆糕", buy_price = 10, sell_price = 20, category = "consumable", boss = "高阶BOSS/宝箱大奖" },
        xianjie_premium_zong = { name = "仙界精品粽", buy_price = 10, sell_price = 20, category = "consumable", boss = "端午遗留黑市" },
    },

    -- ═══ 排行榜配置（积分榜）═══
    leaderboard = {
        rankKey = "evt_valentine_score",
        infoKey = "evt_valentine_info",
        recordsKey = "evt_valentine_records",
        displayCount = 10,
        rewardTopN = 3,
        rewardHint = "活动结束后，积分榜前3的玩家将在交流群(QQ群: 1054419838)获得小额现金红包奖励！",
        lockHint = "8月2日晚上10点榜单锁定，届时排名将不再变化",
    },
}

-- ============================================================================
-- 通用活动状态查询（供各系统调用）
-- ============================================================================

--- 判断活动是否激活
---@return boolean
function EventConfig.IsActive()
    local ev = EventConfig.ACTIVE_EVENT
    return ev and ev.enabled == true
end

--- 获取当前活动 ID
---@return string|nil
function EventConfig.GetEventId()
    local ev = EventConfig.ACTIVE_EVENT
    return ev and ev.eventId
end

--- 根据兑换 ID 查找兑换配置
---@param exchangeId string
---@return table|nil
function EventConfig.FindExchange(exchangeId)
    local ev = EventConfig.ACTIVE_EVENT
    if not ev or not ev.exchanges then return nil end
    for _, ex in ipairs(ev.exchanges) do
        if ex.id == exchangeId then return ex end
    end
    return nil
end

return EventConfig
