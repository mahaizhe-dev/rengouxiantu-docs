-- ============================================================================
-- EventConfig.lua — 通用活动掉落框架配置
--
-- 职责：定义当前激活的活动（道具/掉率/奖池/排行榜）
-- 设计文档：docs/端午世界掉落活动（代码执行文档）.md v1.0
--
-- 换活动时：替换 ACTIVE_EVENT 配置块即可
-- ============================================================================

local EventConfig = {}

-- ═══════════════════════════════════════
-- 当前激活的活动（同一时间只有一个活动）
-- ═══════════════════════════════════════
EventConfig.ACTIVE_EVENT = {
    eventId = "dragonboat_2026",
    enabled = true,
    name = "端午仙粽",
    npcName = "粽仙使者",
    npcSubtitle = "端午活动宝箱",

    -- ═══ 活动道具 ID 列表（用于 LootSystem 掉落判定）═══
    items = {
        "dragonboat_colored_rope", "dragonboat_sachet",
    },

    -- ═══ 双宝箱开启物定义 ═══
    openBoxes = {
        small = {
            itemId = "dragonboat_colored_rope",
            score = 1,
            poolKey = "smallBoxPool",
        },
        big = {
            itemId = "dragonboat_sachet",
            score = 10,
            poolKey = "bigBoxPool",
        },
    },

    -- ═══ 普通开启物（端午彩绳）掉率：[chapterId][category] ═══
    dropRates = {
        [1] = { -- 初章·两界村
            boss      = { dragonboat_colored_rope = 0.01 },
            king_boss = { dragonboat_colored_rope = 0.015 },
        },
        [2] = { -- 贰章·乌家堡
            boss      = { dragonboat_colored_rope = 0.015 },
            king_boss = { dragonboat_colored_rope = 0.02 },
        },
        [3] = { -- 叁章·万里黄沙
            boss         = { dragonboat_colored_rope = 0.02 },
            king_boss    = { dragonboat_colored_rope = 0.03 },
            emperor_boss = { dragonboat_colored_rope = 0.04 },
        },
        [4] = { -- 肆章·八卦海
            boss         = { dragonboat_colored_rope = 0.03 },
            king_boss    = { dragonboat_colored_rope = 0.04 },
            emperor_boss = { dragonboat_colored_rope = 0.05 },
        },
        [5] = { -- 伍章·中洲
            king_boss    = { dragonboat_colored_rope = 0.04 },
            emperor_boss = { dragonboat_colored_rope = 0.05 },
            saint_boss   = { dragonboat_colored_rope = 0.06 },
        },
        [101] = { -- 中洲战场（仙劫+仙殒）
            king_boss    = { dragonboat_colored_rope = 0.04 },
            emperor_boss = { dragonboat_colored_rope = 0.05 },
        },
    },

    -- ═══ 稀有开启物（辟邪香囊）掉率：按怪物境界 monster.realm ═══
    realmDropRates = {
        -- 元婴 0.2%
        yuanying_1 = { dragonboat_sachet = 0.002 },
        yuanying_2 = { dragonboat_sachet = 0.002 },
        yuanying_3 = { dragonboat_sachet = 0.002 },
        -- 化神 0.3%
        huashen_1  = { dragonboat_sachet = 0.003 },
        huashen_2  = { dragonboat_sachet = 0.003 },
        huashen_3  = { dragonboat_sachet = 0.003 },
        -- 合体 0.4%
        heti_1     = { dragonboat_sachet = 0.004 },
        heti_2     = { dragonboat_sachet = 0.004 },
        heti_3     = { dragonboat_sachet = 0.004 },
        -- 大乘 0.6%
        dacheng_1  = { dragonboat_sachet = 0.006 },
        dacheng_2  = { dragonboat_sachet = 0.006 },
        dacheng_3  = { dragonboat_sachet = 0.006 },
        dacheng_4  = { dragonboat_sachet = 0.006 },
        -- 谪仙 0.8%
        dujie_1    = { dragonboat_sachet = 0.008 },
        dujie_2    = { dragonboat_sachet = 0.008 },
        dujie_3    = { dragonboat_sachet = 0.008 },
        dujie_4    = { dragonboat_sachet = 0.008 },
    },

    -- ═══ 四仙剑特殊覆盖（优先于 realmDropRates）═══
    monsterOverrides = {
        ch5_sword_zhu  = { dragonboat_sachet = 0.01 },  -- 1%
        ch5_sword_xian = { dragonboat_sachet = 0.01 },  -- 1%
        ch5_sword_lu   = { dragonboat_sachet = 0.01 },  -- 1%
        ch5_sword_jue  = { dragonboat_sachet = 0.01 },  -- 1%
    },

    -- ═══ 仙界精品粽独立掉落配置（第三段，与彩绳/香囊互不排斥）═══
    -- 仅 BOSS + realm >= yuanying_1 参与；四仙剑走 typeId 覆盖
    -- rewards.lua RollEventDrops 第三段读取此表
    premiumZongDropRates = {
        yuanying_1 = 0.0005, yuanying_2 = 0.0005, yuanying_3 = 0.0005,
        huashen_1  = 0.0008, huashen_2  = 0.0008, huashen_3  = 0.0008,
        heti_1     = 0.0010, heti_2     = 0.0010, heti_3     = 0.0010,
        dacheng_1  = 0.0012, dacheng_2  = 0.0012, dacheng_3  = 0.0012, dacheng_4 = 0.0012,
        dujie_1    = 0.0015, dujie_2    = 0.0015, dujie_3    = 0.0015, dujie_4   = 0.0015,
        -- 四仙剑覆盖
        ch5_sword_zhu  = 0.0020,
        ch5_sword_xian = 0.0020,
        ch5_sword_lu   = 0.0020,
        ch5_sword_jue  = 0.0020,
    },

    -- ═══ 兑换商品表（端午不启用兑换）═══
    exchanges = {},

    -- ═══ BOSS 击杀里程碑任务（10 档，每档奖励辟邪香囊 ×1）═══
    bossMilestones = {
        { id = "dragonboat_boss_300",  target = 300,  reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_600",  target = 600,  reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_900",  target = 900,  reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_1200", target = 1200, reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_1500", target = 1500, reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_1800", target = 1800, reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_2100", target = 2100, reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_2400", target = 2400, reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_2700", target = 2700, reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "dragonboat_boss_3000", target = 3000, reward = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
    },

    -- ═══ 小宝箱奖池（总权重 1000，已确认按1000等比放大）═══
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
        { id = "small_sachet",  name = "辟邪香囊×1",    weight = 20,  rarity = "legendary",
          rewards = { { type = "consumable", id = "dragonboat_sachet", count = 1 } } },
        { id = "small_zong",    name = "仙界精品粽×1",  weight = 10,  rarity = "legendary",
          rewards = { { type = "consumable", id = "xianjie_premium_zong", count = 1 } } },
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
        { id = "big_zong",      name = "仙界精品粽×1",  weight = 20,  rarity = "legendary",
          rewards = { { type = "consumable", id = "xianjie_premium_zong", count = 1 } } },
        { id = "big_skin",      name = "悟性皮肤",      weight = 10,  rarity = "legendary",
          rewards = { { type = "petSkin", id = "pet_premium_wuxing", dupLingYun = 5000 } } },
    },

    -- ═══ 保底机制（按箱型独立计数，命中后重置）═══
    pity = {
        small = { threshold = 120, targetId = "small_zong" },   -- 小宝箱120次保底：仙界精品粽×1
        big   = { threshold = 120, targetId = "big_skin" },     -- 大宝箱120次保底：悟性皮肤
    },

    -- ═══ 大奖弹窗触发条目（命中这些条目ID时弹"恭喜获得大奖"窗口）═══
    jackpotIds = {
        small_sachet = true,    -- 辟邪香囊（小宝箱稀有大奖）
        small_zong   = true,    -- 仙界精品粽（小宝箱传说大奖）
        big_zong     = true,    -- 仙界精品粽（大宝箱传说大奖）
        big_skin     = true,    -- 悟性皮肤（大宝箱传说大奖）
    },

    -- ═══ 黑市商品（仅供参考，实际价格以 BlackMerchantConfig.lua 为准）═══
    blackMarketItems = {
        dragonboat_colored_rope = { name = "端午彩绳",   buy_price = 1,  sell_price = 2,  category = "consumable_mat", boss = "各章节BOSS" },
        dragonboat_sachet       = { name = "辟邪香囊",   buy_price = 6,  sell_price = 12, category = "consumable_mat", boss = "高境界BOSS/里程碑" },
        xianjie_premium_zong    = { name = "仙界精品粽", buy_price = 10, sell_price = 20, category = "consumable_mat", boss = "宝箱大奖" },
    },

    -- ═══ 排行榜配置（积分榜）═══
    leaderboard = {
        rankKey = "evt_dragonboat_score",
        infoKey = "evt_dragonboat_info",
        recordsKey = "evt_dragonboat_records",
        displayCount = 10,
        rewardTopN = 3,
        rewardHint = "活动结束后，积分榜前3的玩家将在交流群(QQ群: 1054419838)获得小额现金红包奖励！",
        lockHint = "6月28日晚上10点榜单锁定，活动将在锁榜后2小时内关闭",
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
