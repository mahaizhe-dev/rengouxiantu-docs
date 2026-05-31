-- ============================================================================
-- EventConfig.lua — 通用活动掉落框架配置
--
-- 职责：定义当前激活的活动（道具/掉率/奖池/排行榜）
-- 设计文档：docs/六一世界掉落活动（代码执行文档）.md v1.2
--
-- 换活动时：替换 ACTIVE_EVENT 配置块即可
-- ============================================================================

local EventConfig = {}

-- ═══════════════════════════════════════
-- 当前激活的活动（同一时间只有一个活动）
-- ═══════════════════════════════════════
EventConfig.ACTIVE_EVENT = {
    eventId = "childrensday_2026",
    enabled = true,
    name = "六一童趣",
    npcName = "天官赐福",
    npcSubtitle = "六一活动宝箱",

    -- ═══ 活动道具 ID 列表（用于 LootSystem 掉落判定）═══
    items = {
        "childday_rattle", "childday_pinwheel",
    },

    -- ═══ 双宝箱开启物定义 ═══
    openBoxes = {
        small = {
            itemId = "childday_rattle",
            score = 1,
            poolKey = "smallBoxPool",
        },
        big = {
            itemId = "childday_pinwheel",
            score = 10,
            poolKey = "bigBoxPool",
        },
    },

    -- ═══ 普通开启物（拨浪鼓）掉率：[chapterId][category] ═══
    dropRates = {
        [1] = { -- 初章·两界村
            boss      = { childday_rattle = 0.01 },
            king_boss = { childday_rattle = 0.015 },
        },
        [2] = { -- 贰章·乌家堡
            boss      = { childday_rattle = 0.015 },
            king_boss = { childday_rattle = 0.02 },
        },
        [3] = { -- 叁章·万里黄沙
            boss         = { childday_rattle = 0.02 },
            king_boss    = { childday_rattle = 0.03 },
            emperor_boss = { childday_rattle = 0.04 },
        },
        [4] = { -- 肆章·八卦海
            boss         = { childday_rattle = 0.03 },
            king_boss    = { childday_rattle = 0.04 },
            emperor_boss = { childday_rattle = 0.05 },
        },
        [5] = { -- 伍章·中洲
            king_boss    = { childday_rattle = 0.04 },
            emperor_boss = { childday_rattle = 0.05 },
            saint_boss   = { childday_rattle = 0.06 },
        },
    },

    -- ═══ 稀有开启物（风车）掉率：按怪物境界 monster.realm ═══
    realmDropRates = {
        -- 元婴 0.2%
        yuanying_1 = { childday_pinwheel = 0.002 },
        yuanying_2 = { childday_pinwheel = 0.002 },
        yuanying_3 = { childday_pinwheel = 0.002 },
        -- 化神 0.3%
        huashen_1  = { childday_pinwheel = 0.003 },
        huashen_2  = { childday_pinwheel = 0.003 },
        huashen_3  = { childday_pinwheel = 0.003 },
        -- 合体 0.4%
        heti_1     = { childday_pinwheel = 0.004 },
        heti_2     = { childday_pinwheel = 0.004 },
        heti_3     = { childday_pinwheel = 0.004 },
        -- 大乘 0.6%
        dacheng_1  = { childday_pinwheel = 0.006 },
        dacheng_2  = { childday_pinwheel = 0.006 },
        dacheng_3  = { childday_pinwheel = 0.006 },
        dacheng_4  = { childday_pinwheel = 0.006 },
        -- 谪仙 0.8%
        dujie_1    = { childday_pinwheel = 0.008 },
        dujie_2    = { childday_pinwheel = 0.008 },
        dujie_3    = { childday_pinwheel = 0.008 },
        dujie_4    = { childday_pinwheel = 0.008 },
    },

    -- ═══ 四仙剑特殊覆盖（优先于 realmDropRates）═══
    monsterOverrides = {
        ch5_sword_zhu  = { childday_pinwheel = 0.01 },  -- 1%
        ch5_sword_xian = { childday_pinwheel = 0.01 },  -- 1%
        ch5_sword_lu   = { childday_pinwheel = 0.01 },  -- 1%
        ch5_sword_jue  = { childday_pinwheel = 0.01 },  -- 1%
    },

    -- ═══ 兑换商品表（六一不启用兑换）═══
    exchanges = {},

    -- ═══ 小宝箱奖池（总权重 1000，E=20.4灵韵）═══
    smallBoxPool = {
        { id = "small_bone_15", name = "肉骨头×15",     weight = 150, rarity = "common",
          rewards = { { type = "consumable", id = "meat_bone", count = 15 } } },
        { id = "small_meat_5",  name = "灵肉×5",        weight = 150, rarity = "common",
          rewards = { { type = "consumable", id = "spirit_meat", count = 5 } } },
        { id = "small_bone_im", name = "仙骨×1",        weight = 150, rarity = "common",
          rewards = { { type = "consumable", id = "immortal_bone", count = 1 } } },
        { id = "small_ly_20",   name = "灵韵×20",       weight = 120, rarity = "common",
          rewards = { { type = "lingYun", count = 20 } } },
        { id = "small_bar_10",  name = "金条×10",       weight = 100, rarity = "common",
          rewards = { { type = "consumable", id = "gold_bar", count = 10 } } },
        { id = "small_pill_1",  name = "修炼果×1",      weight = 50,  rarity = "common",
          rewards = { { type = "consumable", id = "exp_pill", count = 1 } } },
        { id = "small_ly_25",   name = "灵韵×25",       weight = 110, rarity = "common",
          rewards = { { type = "lingYun", count = 25 } } },
        { id = "small_ly_30",   name = "灵韵×30",       weight = 60,  rarity = "rare",
          rewards = { { type = "lingYun", count = 30 } } },
        { id = "small_bar_15",  name = "金条×15",       weight = 50,  rarity = "rare",
          rewards = { { type = "consumable", id = "gold_bar", count = 15 } } },
        { id = "small_ly_fruit",name = "灵韵果×1",      weight = 40,  rarity = "rare",
          rewards = { { type = "consumable", id = "lingyun_fruit", count = 1 } } },
        { id = "small_upgrade", name = "流光风车×1",    weight = 20,  rarity = "legendary",
          rewards = { { type = "consumable", id = "childday_pinwheel", count = 1 } } },
    },

    -- ═══ 大宝箱奖池（总权重 1000，E=206.1灵韵）═══
    bigBoxPool = {
        { id = "big_ly_100",    name = "灵韵×100",      weight = 150, rarity = "common",
          rewards = { { type = "lingYun", count = 100 } } },
        { id = "big_gold_50k",  name = "金币×50000",    weight = 130, rarity = "common",
          rewards = { { type = "gold", count = 50000 } } },
        { id = "big_marrow",    name = "龙髓×1",        weight = 120, rarity = "common",
          rewards = { { type = "consumable", id = "dragon_marrow", count = 1 } } },
        { id = "big_ly_200",    name = "灵韵×200",      weight = 110, rarity = "common",
          rewards = { { type = "lingYun", count = 200 } } },
        { id = "big_brick",     name = "金砖×1",        weight = 100, rarity = "rare",
          rewards = { { type = "consumable", id = "gold_brick", count = 1 } } },
        { id = "big_exp_pill",  name = "上品修炼果×1",  weight = 50,  rarity = "rare",
          rewards = { { type = "consumable", id = "exp_pill_superior", count = 1 } } },
        { id = "big_essence_5", name = "妖兽精华×5",    weight = 100, rarity = "common",
          rewards = { { type = "consumable", id = "demon_essence", count = 5 } } },
        { id = "big_ly_300",    name = "灵韵×300",      weight = 100, rarity = "rare",
          rewards = { { type = "lingYun", count = 300 } } },
        { id = "big_ly_400",    name = "灵韵×400",      weight = 80,  rarity = "rare",
          rewards = { { type = "lingYun", count = 400 } } },
        { id = "big_ly_fruit",  name = "上品灵韵果×1",  weight = 50,  rarity = "rare",
          rewards = { { type = "consumable", id = "lingyun_fruit_superior", count = 1 } } },
        { id = "big_skin",      name = "福缘皮肤",      weight = 10,  rarity = "legendary",
          rewards = { { type = "petSkin", id = "pet_premium_fuyuan", dupLingYun = 5000 } } },
    },

    -- ═══ 保底机制（按箱型独立计数，命中后重置）═══
    pity = {
        small = { threshold = 60,  targetId = "small_upgrade" },  -- 小宝箱60次保底：流光风车×1
        big   = { threshold = 120, targetId = "big_skin" },       -- 大宝箱120次保底：福缘皮肤
    },

    -- ═══ 黑市商品（仅供参考，实际价格以 BlackMerchantConfig.lua 为准）═══
    -- ⚠️ 当前无代码读取此表，如需修改黑市价格请改 BlackMerchantConfig.lua
    blackMarketItems = {
        childday_rattle   = { name = "童趣拨浪鼓", buy_price = 1, sell_price = 2,  category = "event", boss = "各章节BOSS" },
        childday_pinwheel = { name = "流光风车",   buy_price = 6, sell_price = 12, category = "event", boss = "高境界BOSS/小宝箱" },
    },

    -- ═══ 排行榜配置（积分榜）═══
    leaderboard = {
        rankKey = "evt_childday_score",
        infoKey = "evt_childday_info",
        recordsKey = "evt_childday_records",
        displayCount = 10,
        rewardTopN = 3,
        rewardHint = "活动结束后，积分榜前3的玩家将在交流群(QQ群: 1054419838)获得小额现金红包奖励！",
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
