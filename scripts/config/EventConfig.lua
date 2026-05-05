-- ============================================================================
-- EventConfig.lua — 通用活动掉落框架配置
--
-- 职责：定义当前激活的活动（道具/掉率/兑换/福袋/黑市/排行榜）
-- 设计文档：docs/设计文档/五一世界掉落活动.md v3.4
--
-- 换活动时：替换 ACTIVE_EVENT 配置块即可
-- ============================================================================

local EventConfig = {}

-- ═══════════════════════════════════════
-- 当前激活的活动（同一时间只有一个活动）
-- ═══════════════════════════════════════
EventConfig.ACTIVE_EVENT = {
    eventId = "mayday_2026",
    enabled = true,
    name = "五一快乐",
    npcName = "天官降福",
    npcSubtitle = "五一活动兑换",

    -- ═══ 活动道具 ID 列表（用于 LootSystem 掉落判定）═══
    items = {
        "mayday_wu", "mayday_yi", "mayday_kuai", "mayday_le", "mayday_fudai",
    },

    -- ═══ 掉率配置 [chapterId][category] = { itemId = chance } ═══
    dropRates = {
        [1] = { -- 初章·两界村
            boss      = { mayday_wu=0.005, mayday_yi=0.005, mayday_kuai=0.005, mayday_le=0.005, mayday_fudai=0.005 },
            king_boss = { mayday_wu=0.01,  mayday_yi=0.01,  mayday_kuai=0.01,  mayday_le=0.01,  mayday_fudai=0.01  },
        },
        [2] = { -- 贰章·乌家堡
            boss      = { mayday_wu=0.01, mayday_yi=0.01, mayday_kuai=0.01, mayday_le=0.01, mayday_fudai=0.01 },
            king_boss = { mayday_wu=0.02, mayday_yi=0.02, mayday_kuai=0.02, mayday_le=0.02, mayday_fudai=0.02 },
        },
        [3] = { -- 叁章·万里黄沙
            boss         = { mayday_wu=0.02, mayday_yi=0.02, mayday_kuai=0.02, mayday_le=0.02, mayday_fudai=0.02 },
            emperor_boss = { mayday_wu=0.03, mayday_yi=0.03, mayday_kuai=0.03, mayday_le=0.03, mayday_fudai=0.03 },
        },
        [4] = { -- 肆章·八卦海
            boss         = { mayday_wu=0.03, mayday_yi=0.03, mayday_kuai=0.03, mayday_le=0.03, mayday_fudai=0.03 },
            emperor_boss = { mayday_wu=0.03, mayday_yi=0.03, mayday_kuai=0.03, mayday_le=0.03, mayday_fudai=0.03 },
        },
        [101] = { -- 中洲
            king_boss = { mayday_wu=0.03, mayday_yi=0.03, mayday_kuai=0.03, mayday_le=0.03, mayday_fudai=0.03 },
        },
    },

    -- ═══ 四龙特殊掉率覆盖（通过怪物 typeId 匹配）═══
    monsterOverrides = {
        dragon_ice   = { mayday_wu=0.05, mayday_yi=0.05, mayday_kuai=0.05, mayday_le=0.05, mayday_fudai=0.05 },
        dragon_abyss = { mayday_wu=0.05, mayday_yi=0.05, mayday_kuai=0.05, mayday_le=0.05, mayday_fudai=0.05 },
        dragon_fire  = { mayday_wu=0.05, mayday_yi=0.05, mayday_kuai=0.05, mayday_le=0.05, mayday_fudai=0.05 },
        dragon_sand  = { mayday_wu=0.05, mayday_yi=0.05, mayday_kuai=0.05, mayday_le=0.05, mayday_fudai=0.05 },
    },

    -- ═══ 兑换商品表 ═══
    exchanges = {
        -- A 组：四字齐全（限购 1 次）
        {
            id = "mayday_ex_a1",
            name = "五一快乐大礼",
            desc = "集齐四字各五个，天官赐万灵",
            cost = { mayday_wu = 5, mayday_yi = 5, mayday_kuai = 5, mayday_le = 5 },
            reward = { type = "lingYun", count = 10000 },
            limit = 1,
        },
        -- B 组：1+1 组合兑换（各限购 10 次）
        {
            id = "mayday_ex_b1",
            name = "五一福报",
            desc = "五一二字各一个，得灵韵福报",
            cost = { mayday_wu = 1, mayday_yi = 1 },
            reward = { type = "lingYun", count = 500 },
            limit = 10,
        },
        {
            id = "mayday_ex_b2",
            name = "快乐福报",
            desc = "快乐二字各一个，得灵韵福报",
            cost = { mayday_kuai = 1, mayday_le = 1 },
            reward = { type = "lingYun", count = 500 },
            limit = 10,
        },
        -- C 组：单字换福袋（不限量）
        {
            id = "mayday_ex_c1", name = "「五」换福袋",
            cost = { mayday_wu = 1 },
            reward = { type = "consumable", id = "mayday_fudai", count = 1 },
            limit = -1,
        },
        {
            id = "mayday_ex_c2", name = "「一」换福袋",
            cost = { mayday_yi = 1 },
            reward = { type = "consumable", id = "mayday_fudai", count = 1 },
            limit = -1,
        },
        {
            id = "mayday_ex_c3", name = "「快」换福袋",
            cost = { mayday_kuai = 1 },
            reward = { type = "consumable", id = "mayday_fudai", count = 1 },
            limit = -1,
        },
        {
            id = "mayday_ex_c4", name = "「乐」换福袋",
            cost = { mayday_le = 1 },
            reward = { type = "consumable", id = "mayday_fudai", count = 1 },
            limit = -1,
        },
    },

    -- ═══ 福袋奖励池（总权重 1000）═══
    fudaiPool = {
        -- 一般奖励（common）· 85%
        { id = "fudai_exp_1",  name = "500经验",   weight = 130, rarity = "common",
          rewards = { { type = "exp", count = 500 } } },
        { id = "fudai_exp_2",  name = "1500经验",  weight = 80,  rarity = "common",
          rewards = { { type = "exp", count = 1500 } } },
        { id = "fudai_exp_3",  name = "2500经验",  weight = 35,  rarity = "common",
          rewards = { { type = "exp", count = 2500 } } },
        { id = "fudai_food_1", name = "肉骨头×3",  weight = 120, rarity = "common",
          rewards = { { type = "consumable", id = "meat_bone", count = 3 } } },
        { id = "fudai_food_2", name = "灵肉×2",    weight = 95,  rarity = "common",
          rewards = { { type = "consumable", id = "spirit_meat", count = 2 } } },
        { id = "fudai_food_3", name = "灵兽肉×2",  weight = 65,  rarity = "common",
          rewards = { { type = "consumable", id = "beast_meat", count = 2 } } },
        { id = "fudai_food_4", name = "仙骨×1",    weight = 40,  rarity = "common",
          rewards = { { type = "consumable", id = "immortal_bone", count = 1 } } },
        { id = "fudai_item_1", name = "金条×1",    weight = 25,  rarity = "common",
          rewards = { { type = "consumable", id = "gold_bar", count = 1 } } },
        { id = "fudai_gold_1", name = "金币×100",   weight = 130, rarity = "common",
          rewards = { { type = "gold", count = 100 } } },
        { id = "fudai_gold_2", name = "金币×300",   weight = 85,  rarity = "common",
          rewards = { { type = "gold", count = 300 } } },
        { id = "fudai_gold_3", name = "金币×500",   weight = 45,  rarity = "common",
          rewards = { { type = "gold", count = 500 } } },

        -- 稀有奖励（rare）· 14.5%
        { id = "fudai_rare_1", name = "妖兽精华×1", weight = 50, rarity = "rare",
          rewards = { { type = "consumable", id = "demon_essence", count = 1 } } },
        { id = "fudai_rare_2", name = "修炼果×1",   weight = 40, rarity = "rare",
          rewards = { { type = "consumable", id = "exp_pill", count = 1 } } },
        { id = "fudai_rare_3", name = "灵韵果×1",   weight = 30, rarity = "rare",
          rewards = { { type = "consumable", id = "lingyun_fruit", count = 1 } } },
        { id = "fudai_rare_4", name = "龙髓×1",     weight = 25, rarity = "rare",
          rewards = { { type = "consumable", id = "dragon_marrow", count = 1 } } },

        -- 最稀有（legendary）· 0.5%
        { id = "fudai_legend", name = "金砖×1", weight = 5, rarity = "legendary",
          rewards = { { type = "consumable", id = "gold_brick", count = 1 } } },
    },

    -- ═══ 黑市商品（仅四字可交易，福袋不可交易）═══
    blackMarketItems = {
        mayday_wu   = { name = "五", buy_price = 3, sell_price = 6, category = "event", boss = "各章节BOSS" },
        mayday_yi   = { name = "一", buy_price = 3, sell_price = 6, category = "event", boss = "各章节BOSS" },
        mayday_kuai = { name = "快", buy_price = 3, sell_price = 6, category = "event", boss = "各章节BOSS" },
        mayday_le   = { name = "乐", buy_price = 3, sell_price = 6, category = "event", boss = "各章节BOSS" },
    },

    -- ═══ 排行榜配置 ═══
    leaderboard = {
        rankKey = "evt_fudai_opened",
        displayCount = 10,
        rewardTopN = 3,
        rewardHint = "活动结束后，排名前3的玩家将在交流群(QQ群: 1054419838)获得小额现金红包奖励！",
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
