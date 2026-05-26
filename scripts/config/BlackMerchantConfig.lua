-- ============================================================================
-- BlackMerchantConfig.lua — 万界黑商配置表
--
-- 商品定价、汇率常量、库存上限、分类信息
-- 设计文档：docs/设计文档/万界黑商.md v0.8.1
-- ============================================================================

local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local PetSkillData = require("config.PetSkillData")

local BMConfig = {}

-- ============================================================================
-- 常量
-- ============================================================================

BMConfig.MAX_STOCK = 5                -- 所有商品统一库存上限
BMConfig.XIANSHI_BUY_RATE  = 100      -- 灵韵→仙石汇率（100 灵韵 = 1 仙石）
BMConfig.XIANSHI_SELL_RATE = 50       -- 仙石→灵韵汇率（1 仙石 = 50 灵韵）
BMConfig.SYSTEM_UID = 0               -- 系统用户 ID（黑商库存归属）
BMConfig.TRADE_LOG_KEY = "bm_trade_log"         -- 个人兑换记录 key（按 userId 存）
BMConfig.PUBLIC_TRADE_LOG_KEY = "bm_pub_trade"  -- 公共买卖记录 key（按 SYSTEM_UID 存）
BMConfig.MAX_TRADE_RECORDS = 50                 -- 公共买卖记录上限
BMConfig.MAX_PERSONAL_RECORDS = 50              -- 个人兑换记录上限

-- 黑商解锁门槛（筑基初期 order=4）
BMConfig.JINDAN_ORDER = 4

-- ============================================================================
-- 分类
-- ============================================================================

BMConfig.CATEGORY_RAKE    = "rake"      -- 上宝逊金钯碎片
BMConfig.CATEGORY_BAGUA   = "bagua"     -- 文王八卦盘碎片
BMConfig.CATEGORY_TIANDI  = "tiandi"    -- 天帝剑痕碎片
BMConfig.CATEGORY_ZHENTU  = "zhentu"    -- 诛仙阵图残符（第五章神器）
BMConfig.CATEGORY_LINGYU   = "lingyu"    -- 附灵玉
BMConfig.CATEGORY_MATERIAL     = "material"      -- 丹药材料（兼容旧引用）
BMConfig.CATEGORY_CONSUMABLE_MAT = "consumable_mat" -- 消耗品（龙鳞、金砖、令牌盒等）
BMConfig.CATEGORY_HERB         = "herb"           -- 草药（炼丹材料、精华等）
-- BMConfig.CATEGORY_EVENT     = "event"         -- 活动道具（已下架）
BMConfig.CATEGORY_SPECIAL_EQUIP = "special_equip" -- 特殊装备
BMConfig.CATEGORY_SKILL_BOOK   = "skill_book"    -- 技能书（旧兼容，勿直接使用）
BMConfig.CATEGORY_SKILL_BOOK_MID     = "skill_book_mid"      -- 中级书
BMConfig.CATEGORY_SKILL_BOOK_HIGH    = "skill_book_high"     -- 高级书
BMConfig.CATEGORY_SKILL_BOOK_SPECIAL = "skill_book_special"  -- 特级书

-- 分类显示名（标签页用）
BMConfig.CATEGORY_NAMES = {
    rake          = "逊金钯",
    bagua         = "八卦盘",
    tiandi        = "天帝剑痕",
    zhentu        = "诛仙阵图",
    lingyu        = "附灵玉",
    consumable_mat = "消耗品",
    herb          = "草药",
    -- event      = "活动",  -- 已下架
    special_equip = "特殊装备",
    skill_book    = "技能书",       -- 旧兼容
    skill_book_mid     = "中级书",
    skill_book_high    = "高级书",
    skill_book_special = "特级书",
}

-- ============================================================================
-- 商品表（36 种，固定价格）
-- buy_price  = 黑商收购价（玩家卖出获得仙石）
-- sell_price = 黑商出售价（玩家买入花费仙石）
-- sell_price = buy_price × 2
-- ============================================================================

-- 从 GameConfig 自动获取标准名称和图标的辅助函数
local function ItemFromGame(consumableId, overrides)
    local gc = GameConfig.CONSUMABLES[consumableId]
    local item = {
        name  = gc and gc.name  or consumableId,
        icon  = gc and gc.icon  or nil,
        image = gc and gc.image or nil,  -- 保留 PNG 图片路径（如 Textures/lingyu_*.png）
    }
    for k, v in pairs(overrides) do
        item[k] = v
    end
    return item
end

--- 从 EquipmentData.SpecialEquipment 获取装备名称和图标的辅助函数
--- itemType = "equipment" 标记该商品为装备类（Handler 需区分处理）
local function EquipItemFromData(equipId, overrides)
    local eq = EquipmentData.SpecialEquipment[equipId]
    local item = {
        name     = eq and eq.name or equipId,
        icon     = eq and eq.icon or nil,
        itemType = "equipment",  -- 区分于消耗品（默认 nil = consumable）
        equipId  = equipId,      -- 装备模板 ID
    }
    for k, v in pairs(overrides) do
        item[k] = v
    end
    return item
end

--- 从 PetSkillData.SKILL_BOOKS 获取技能书名称和图标的辅助函数
local function BookItemFromData(bookId, overrides)
    local book = PetSkillData.SKILL_BOOKS[bookId]
    local item = {
        name = book and book.name or bookId,
        icon = book and book.icon or nil,
    }
    for k, v in pairs(overrides) do
        item[k] = v
    end
    return item
end

BMConfig.ITEMS = {
    -- === 上宝逊金钯碎片（三章神器，8 种可交易） ===
    -- rake_fragment_9 不纳入（朱老二 100 万金购买，有稳定获取途径）
    rake_fragment_1 = ItemFromGame("rake_fragment_1", {
        buy_price = 10, sell_price = 20, category = "rake", boss = "枯木妖王",
    }),
    rake_fragment_2 = ItemFromGame("rake_fragment_2", {
        buy_price = 10, sell_price = 20, category = "rake", boss = "岩蟾妖王",
    }),
    rake_fragment_3 = ItemFromGame("rake_fragment_3", {
        buy_price = 10, sell_price = 20, category = "rake", boss = "苍狼妖王",
    }),
    rake_fragment_4 = ItemFromGame("rake_fragment_4", {
        buy_price = 10, sell_price = 20, category = "rake", boss = "赤甲妖王",
    }),
    rake_fragment_5 = ItemFromGame("rake_fragment_5", {
        buy_price = 10, sell_price = 20, category = "rake", boss = "蛇骨妖王",
    }),
    rake_fragment_6 = ItemFromGame("rake_fragment_6", {
        buy_price = 10, sell_price = 20, category = "rake", boss = "烈焰狮王",
    }),
    rake_fragment_7 = ItemFromGame("rake_fragment_7", {
        buy_price = 10, sell_price = 20, category = "rake", boss = "蜃妖王",
    }),
    rake_fragment_8 = ItemFromGame("rake_fragment_8", {
        buy_price = 15, sell_price = 30, category = "rake", boss = "黄天大圣", isBoss = true,
    }),

    -- === 文王八卦盘碎片（四章神器，8 种） ===
    bagua_fragment_kan = ItemFromGame("bagua_fragment_kan", {
        buy_price = 15, sell_price = 30, category = "bagua", boss = "沈渊衣",
    }),
    bagua_fragment_gen = ItemFromGame("bagua_fragment_gen", {
        buy_price = 15, sell_price = 30, category = "bagua", boss = "岩不动",
    }),
    bagua_fragment_zhen = ItemFromGame("bagua_fragment_zhen", {
        buy_price = 15, sell_price = 30, category = "bagua", boss = "雷惊蛰",
    }),
    bagua_fragment_xun = ItemFromGame("bagua_fragment_xun", {
        buy_price = 15, sell_price = 30, category = "bagua", boss = "风无痕",
    }),
    bagua_fragment_li = ItemFromGame("bagua_fragment_li", {
        buy_price = 15, sell_price = 30, category = "bagua", boss = "炎若晦",
    }),
    bagua_fragment_kun = ItemFromGame("bagua_fragment_kun", {
        buy_price = 15, sell_price = 30, category = "bagua", boss = "厚德生",
    }),
    bagua_fragment_dui = ItemFromGame("bagua_fragment_dui", {
        buy_price = 15, sell_price = 30, category = "bagua", boss = "泽归墟",
    }),
    bagua_fragment_qian = ItemFromGame("bagua_fragment_qian", {
        buy_price = 20, sell_price = 40, category = "bagua", boss = "司空正阳", isBoss = true,
    }),

    -- === 天帝剑痕碎片（中洲·仙劫战场，前三片） ===
    -- 卖25仙石（玩家出售），买50仙石（玩家购买）
    tiandi_fragment_1 = ItemFromGame("tiandi_fragment_1", {
        buy_price = 25, sell_price = 50, category = "tiandi", boss = "域外邪魔",
    }),
    tiandi_fragment_2 = ItemFromGame("tiandi_fragment_2", {
        buy_price = 25, sell_price = 50, category = "tiandi", boss = "域外邪魔",
    }),
    tiandi_fragment_3 = ItemFromGame("tiandi_fragment_3", {
        buy_price = 25, sell_price = 50, category = "tiandi", boss = "域外邪魔",
    }),

    -- === 诛仙阵图残符（太虚·第五章，对应9位BOSS） ===
    -- 魔帅掉落（1-3）：收购价30仙石，出售价60仙石
    -- 高层BOSS掉落（4-9）：收购价25仙石，出售价50仙石
    zhentu_fragment_1 = ItemFromGame("zhentu_fragment_1", {
        buy_price = 30, sell_price = 60, category = "zhentu", boss = "镇渊魔帅·蚀骨", isBoss = true,
    }),
    zhentu_fragment_2 = ItemFromGame("zhentu_fragment_2", {
        buy_price = 30, sell_price = 60, category = "zhentu", boss = "镇渊魔帅·裂魂", isBoss = true,
    }),
    zhentu_fragment_3 = ItemFromGame("zhentu_fragment_3", {
        buy_price = 30, sell_price = 60, category = "zhentu", boss = "噬渊血犼", isBoss = true,
    }),
    zhentu_fragment_4 = ItemFromGame("zhentu_fragment_4", {
        buy_price = 25, sell_price = 50, category = "zhentu", boss = "裴千岳",
    }),
    zhentu_fragment_5 = ItemFromGame("zhentu_fragment_5", {
        buy_price = 25, sell_price = 50, category = "zhentu", boss = "洗剑霜鸾",
    }),
    zhentu_fragment_6 = ItemFromGame("zhentu_fragment_6", {
        buy_price = 25, sell_price = 50, category = "zhentu", boss = "韩百炼",
    }),
    zhentu_fragment_7 = ItemFromGame("zhentu_fragment_7", {
        buy_price = 25, sell_price = 50, category = "zhentu", boss = "石观澜",
    }),
    zhentu_fragment_8 = ItemFromGame("zhentu_fragment_8", {
        buy_price = 25, sell_price = 50, category = "zhentu", boss = "宁栖梧",
    }),
    zhentu_fragment_9 = ItemFromGame("zhentu_fragment_9", {
        buy_price = 25, sell_price = 50, category = "zhentu", boss = "温素章",
    }),

    -- === 附灵玉（附灵师·萃取产出，对应四大T9套装） ===
    -- 收购价20仙石（玩家卖出），出售价40仙石（玩家买入）
    lingyu_xuesha_lv1  = ItemFromGame("lingyu_xuesha_lv1",  { buy_price = 20, sell_price = 40, category = "lingyu" }),
    lingyu_qingyun_lv1 = ItemFromGame("lingyu_qingyun_lv1", { buy_price = 20, sell_price = 40, category = "lingyu" }),
    lingyu_fengmo_lv1  = ItemFromGame("lingyu_fengmo_lv1",  { buy_price = 20, sell_price = 40, category = "lingyu" }),
    lingyu_haoqi_lv1   = ItemFromGame("lingyu_haoqi_lv1",   { buy_price = 20, sell_price = 40, category = "lingyu" }),

    -- === 草药（炼丹材料、精华） ===
    tiger_bone         = ItemFromGame("tiger_bone",         { buy_price = 1,  sell_price = 2,  category = "herb", max_stock = 10, sort_order = 1 }),
    snake_fruit        = ItemFromGame("snake_fruit",        { buy_price = 2,  sell_price = 4,  category = "herb", max_stock = 10, sort_order = 2 }),
    diamond_wood       = ItemFromGame("diamond_wood",       { buy_price = 3,  sell_price = 6,  category = "herb", max_stock = 10, sort_order = 3 }),
    wind_eroded_grass  = ItemFromGame("wind_eroded_grass",  { buy_price = 4,  sell_price = 8,  category = "herb", max_stock = 10, sort_order = 4 }),
    lipo_essence       = ItemFromGame("lipo_essence",       { buy_price = 5,  sell_price = 10, category = "herb", max_stock = 10, sort_order = 5 }),
    panshi_essence     = ItemFromGame("panshi_essence",     { buy_price = 5,  sell_price = 10, category = "herb", max_stock = 10, sort_order = 6 }),
    yuanling_essence   = ItemFromGame("yuanling_essence",   { buy_price = 5,  sell_price = 10, category = "herb", max_stock = 10, sort_order = 7 }),
    shihun_essence     = ItemFromGame("shihun_essence",     { buy_price = 5,  sell_price = 10, category = "herb", max_stock = 10, sort_order = 8 }),
    lingxi_essence     = ItemFromGame("lingxi_essence",     { buy_price = 5,  sell_price = 10, category = "herb", max_stock = 10, sort_order = 9 }),
    dragon_blood_herb  = ItemFromGame("dragon_blood_herb",  { buy_price = 5,  sell_price = 10, category = "herb", max_stock = 10, sort_order = 10 }),
    ganggu_essence     = ItemFromGame("ganggu_essence",     { buy_price = 8,  sell_price = 16, category = "herb", max_stock = 5,  sort_order = 11 }),
    -- Ch5 圣器材料（炼制太虚剑丹/狱甲丹/圣器的必需材料，高价值稀有草药）
    sword_intent_crystal   = ItemFromGame("sword_intent_crystal",   { buy_price = 8,  sell_price = 16, category = "herb", max_stock = 5, sort_order = 12 }),
    abyss_seal_shard       = ItemFromGame("abyss_seal_shard",       { buy_price = 8,  sell_price = 16, category = "herb", max_stock = 5, sort_order = 13 }),

    -- === 消耗品（龙神材料、仙人精血、金砖、令牌盒） ===
    dragon_scale_ice   = ItemFromGame("dragon_scale_ice",   { buy_price = 10, sell_price = 20, category = "consumable_mat", max_stock = 5, sort_order = 1 }),
    dragon_scale_abyss = ItemFromGame("dragon_scale_abyss", { buy_price = 10, sell_price = 20, category = "consumable_mat", max_stock = 5, sort_order = 2 }),
    dragon_scale_fire  = ItemFromGame("dragon_scale_fire",  { buy_price = 10, sell_price = 20, category = "consumable_mat", max_stock = 5, sort_order = 3 }),
    dragon_scale_sand  = ItemFromGame("dragon_scale_sand",  { buy_price = 10, sell_price = 20, category = "consumable_mat", max_stock = 5, sort_order = 4 }),
    -- 仙人精血（第五章消耗品，买15卖30仙石，限购5）
    immortal_essence_blood = ItemFromGame("immortal_essence_blood", { buy_price = 15, sell_price = 30, category = "consumable_mat", max_stock = 5, sort_order = 5 }),
    gold_brick         = ItemFromGame("gold_brick",         { buy_price = 1,  sell_price = 2,  category = "consumable_mat", max_stock = 10, sort_order = 6 }),

    -- === 令牌盒（100令牌+100灵韵炼制，买2卖4仙石，限购10） ===
    wubao_token_box    = ItemFromGame("wubao_token_box",    { buy_price = 2,  sell_price = 4,  category = "consumable_mat", max_stock = 10, sort_order = 7 }),
    sha_hai_ling_box   = ItemFromGame("sha_hai_ling_box",   { buy_price = 2,  sell_price = 4,  category = "consumable_mat", max_stock = 10, sort_order = 8 }),
    taixu_token_box    = ItemFromGame("taixu_token_box",    { buy_price = 2,  sell_price = 4,  category = "consumable_mat", max_stock = 10, sort_order = 9 }),
    -- 太虚剑令盒（100太虚剑令+100灵韵炼制，第五章令牌盒，买2卖4仙石，限购10）
    taixu_jianling_box = ItemFromGame("taixu_jianling_box", { buy_price = 2,  sell_price = 4,  category = "consumable_mat", max_stock = 10, sort_order = 10 }),

    -- === 五一活动信物（已下架） ===

    -- === 特殊装备：帝尊戒指系列（装备类商品，买回初始状态，卖出不论附魔/洗练） ===
    dizun_ring_ch1 = EquipItemFromData("dizun_ring_ch1", {
        buy_price = 2, sell_price = 4, category = "special_equip", sort_order = 1,
        boss = "虎王",
    }),
    dizun_ring_ch2 = EquipItemFromData("dizun_ring_ch2", {
        buy_price = 4, sell_price = 8, category = "special_equip", sort_order = 2,
        boss = "乌万仇/乌万海",
    }),
    dizun_ring_ch3 = EquipItemFromData("dizun_ring_ch3", {
        buy_price = 8, sell_price = 16, category = "special_equip", sort_order = 3,
        boss = "沙万里/狮王/蜃妖王",
    }),
    silong_ring_ch4 = EquipItemFromData("silong_ring_ch4", {
        buy_price = 12, sell_price = 24, category = "special_equip", sort_order = 4,
        boss = "四龙",
    }),

    -- === 帝尊五戒（Ch5 精英BOSS掉落，30仙石购买/15仙石收购）===
    dizun_ring_ch5 = EquipItemFromData("dizun_ring_ch5", {
        buy_price = 15, sell_price = 30, category = "special_equip", sort_order = 5,
        boss = "第五章精英BOSS",
    }),

    -- === 中级技能书（紫色品质，sellPrice=1000金，收2售4仙石，限购5） ===
    -- Ch1~Ch2 基础中级
    book_atk_2       = BookItemFromData("book_atk_2",       { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 1  }),
    book_hp_2        = BookItemFromData("book_hp_2",        { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 2  }),
    book_def_2       = BookItemFromData("book_def_2",       { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 3  }),
    book_evade_2     = BookItemFromData("book_evade_2",     { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 4  }),
    book_regen_2     = BookItemFromData("book_regen_2",     { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 5  }),
    book_crit_2      = BookItemFromData("book_crit_2",      { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 6  }),
    -- Ch3 中级
    book_atkSpd_2    = BookItemFromData("book_atkSpd_2",    { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 7  }),
    book_critDmg_2   = BookItemFromData("book_critDmg_2",   { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 8  }),
    book_doubleHit_2 = BookItemFromData("book_doubleHit_2", { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 9  }),
    book_lifeSteal_2 = BookItemFromData("book_lifeSteal_2", { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 10 }),
    book_hpPerLv_2   = BookItemFromData("book_hpPerLv_2",   { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 11 }),
    book_dmgReduce_2 = BookItemFromData("book_dmgReduce_2", { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 12 }),
    book_defPerLv_2  = BookItemFromData("book_defPerLv_2",  { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 13 }),
    -- 新3系列中级
    book_ignoreDef_2 = BookItemFromData("book_ignoreDef_2", { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 14 }),
    book_atkPerLv_2  = BookItemFromData("book_atkPerLv_2",  { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 15 }),
    book_bonusDmg_2  = BookItemFromData("book_bonusDmg_2",  { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 16 }),
    -- 灵兽赐主中级
    book_wisdom_owner_2       = BookItemFromData("book_wisdom_owner_2",       { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 17 }),
    book_constitution_owner_2 = BookItemFromData("book_constitution_owner_2", { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 18 }),
    book_physique_owner_2     = BookItemFromData("book_physique_owner_2",     { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 19 }),
    book_fortune_owner_2      = BookItemFromData("book_fortune_owner_2",      { buy_price = 2,  sell_price = 4,  category = "skill_book_mid", max_stock = 5, sort_order = 20 }),

    -- === 高级技能书（橙色品质，sellPrice=3000金，收5售10仙石，限购5） ===
    book_atk_3       = BookItemFromData("book_atk_3",       { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 1  }),
    book_hp_3        = BookItemFromData("book_hp_3",        { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 2  }),
    book_def_3       = BookItemFromData("book_def_3",       { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 3  }),
    book_evade_3     = BookItemFromData("book_evade_3",     { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 4  }),
    book_regen_3     = BookItemFromData("book_regen_3",     { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 5  }),
    book_crit_3      = BookItemFromData("book_crit_3",      { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 6  }),
    book_atkSpd_3    = BookItemFromData("book_atkSpd_3",    { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 7  }),
    book_critDmg_3   = BookItemFromData("book_critDmg_3",   { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 8  }),
    book_doubleHit_3 = BookItemFromData("book_doubleHit_3", { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 9  }),
    book_lifeSteal_3 = BookItemFromData("book_lifeSteal_3", { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 10 }),
    book_hpPerLv_3   = BookItemFromData("book_hpPerLv_3",   { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 11 }),
    book_dmgReduce_3 = BookItemFromData("book_dmgReduce_3", { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 12 }),
    book_defPerLv_3  = BookItemFromData("book_defPerLv_3",  { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 13 }),
    -- 新3系列高级
    book_ignoreDef_3 = BookItemFromData("book_ignoreDef_3", { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 14 }),
    book_atkPerLv_3  = BookItemFromData("book_atkPerLv_3",  { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 15 }),
    book_bonusDmg_3  = BookItemFromData("book_bonusDmg_3",  { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 16 }),
    -- 灵兽赐主高级
    book_wisdom_owner_3       = BookItemFromData("book_wisdom_owner_3",       { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 17 }),
    book_constitution_owner_3 = BookItemFromData("book_constitution_owner_3", { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 18 }),
    book_physique_owner_3     = BookItemFromData("book_physique_owner_3",     { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 19 }),
    book_fortune_owner_3      = BookItemFromData("book_fortune_owner_3",      { buy_price = 5,  sell_price = 10, category = "skill_book_high", max_stock = 5, sort_order = 20 }),

    -- === 特级技能书（红色品质，sellPrice=8000金，收10售20仙石，限购3） ===
    book_atk_4       = BookItemFromData("book_atk_4",       { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 1  }),
    book_hp_4        = BookItemFromData("book_hp_4",        { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 2  }),
    book_def_4       = BookItemFromData("book_def_4",       { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 3  }),
    book_evade_4     = BookItemFromData("book_evade_4",     { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 4  }),
    book_regen_4     = BookItemFromData("book_regen_4",     { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 5  }),
    book_crit_4      = BookItemFromData("book_crit_4",      { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 6  }),
    book_atkSpd_4    = BookItemFromData("book_atkSpd_4",    { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 7  }),
    book_critDmg_4   = BookItemFromData("book_critDmg_4",   { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 8  }),
    book_doubleHit_4 = BookItemFromData("book_doubleHit_4", { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 9  }),
    book_lifeSteal_4 = BookItemFromData("book_lifeSteal_4", { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 10 }),
    book_hpPerLv_4   = BookItemFromData("book_hpPerLv_4",   { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 11 }),
    book_dmgReduce_4 = BookItemFromData("book_dmgReduce_4", { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 12 }),
    book_defPerLv_4  = BookItemFromData("book_defPerLv_4",  { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 13 }),
    book_ignoreDef_4 = BookItemFromData("book_ignoreDef_4", { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 14 }),
    book_atkPerLv_4  = BookItemFromData("book_atkPerLv_4",  { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 15 }),
    book_bonusDmg_4  = BookItemFromData("book_bonusDmg_4",  { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 16 }),
    book_wisdom_owner_4       = BookItemFromData("book_wisdom_owner_4",       { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 17 }),
    book_constitution_owner_4 = BookItemFromData("book_constitution_owner_4", { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 18 }),
    book_physique_owner_4     = BookItemFromData("book_physique_owner_4",     { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 19 }),
    book_fortune_owner_4      = BookItemFromData("book_fortune_owner_4",      { buy_price = 10, sell_price = 20, category = "skill_book_special", max_stock = 3, sort_order = 20 }),
}

-- ============================================================================
-- 有序 ID 列表（供遍历和 BatchGet key 构建用）
-- ============================================================================

BMConfig.ITEM_IDS = {}
for id in pairs(BMConfig.ITEMS) do
    BMConfig.ITEM_IDS[#BMConfig.ITEM_IDS + 1] = id
end
table.sort(BMConfig.ITEM_IDS)

-- ============================================================================
-- 分类过滤辅助
-- ============================================================================

--- 返回指定分类的 ID 列表（有 sort_order 字段时按其排序，否则字母序）
---@param category string "rake" | "bagua" | "material" ...
---@return string[]
function BMConfig.GetItemsByCategory(category)
    local result = {}
    for _, id in ipairs(BMConfig.ITEM_IDS) do
        if BMConfig.ITEMS[id].category == category then
            result[#result + 1] = id
        end
    end
    -- 按 sort_order 排序（无 sort_order 的保持字母序不变）
    table.sort(result, function(a, b)
        local oa = BMConfig.ITEMS[a].sort_order
        local ob = BMConfig.ITEMS[b].sort_order
        if oa and ob then return oa < ob end
        if oa then return true end
        if ob then return false end
        return a < b
    end)
    return result
end

-- ============================================================================
-- serverCloud Money 域 key 辅助
-- ============================================================================

--- 黑商库存 key: bm_stock_{itemId}（consumableId 或 equipId）
---@param itemId string
---@return string
function BMConfig.StockKey(itemId)
    return "bm_stock_" .. itemId
end

--- WAL key: bm_wal（灵韵补偿）
BMConfig.WAL_KEY = "bm_wal"
--- WAL key: bm_wal_bp（背包物品补偿）
BMConfig.WAL_BP_KEY = "bm_wal_bp"
--- WAL key: bm_wal_sell（出售仙石补偿：背包已扣但 BatchCommit 失败时写入，下次登录补发仙石）
BMConfig.WAL_SELL_KEY = "bm_wal_sell"

-- ============================================================================
-- 自动收购（胤）—— 设计文档 §12
-- ============================================================================

--- 自动收购总开关（发版设 false 可关闭，无需服务端热更新）
BMConfig.RECYCLE_ENABLED = true
--- 收购 NPC 名称（显示在公共交易记录中）
BMConfig.RECYCLE_NPC_NAME = "胤"
--- 加权随机累积概率阈值：0件25%、1件50%、2件25%（期望值 1.0 件/天/满库存商品）
BMConfig.RECYCLE_WEIGHTS = { 0.25, 0.75, 1.0 }
--- serverCloud.money 日期键名（SYSTEM_UID=0 下存储，数值 YYYYMMDD）
BMConfig.RECYCLE_DATE_KEY = "bm_recycle_date"
--- 允许的最大日期跨度（天）。超过此值视为时间异常，仅更新日期不执行回收。
--- 防止篡改本地时钟跳天获利。正常值 1（过天），2 兼容时区偏移。
BMConfig.MAX_RECYCLE_GAP = 2

--- 将 YYYYMMDD 整数转为 os.time 时间戳（BM-S4D 收口）
--- 用于计算两个日期之间的真实天数差，避免跨月/跨年时数值减法失真。
---@param dateNum number YYYYMMDD 格式整数（如 20260531）
---@return number|nil 成功返回 os.time 时间戳，格式无效返回 nil
function BMConfig.DateToTime(dateNum)
    if type(dateNum) ~= "number" or dateNum < 19700101 then return nil end
    local s = tostring(math.floor(dateNum))
    if #s ~= 8 then return nil end
    local y = tonumber(s:sub(1, 4))
    local m = tonumber(s:sub(5, 6))
    local d = tonumber(s:sub(7, 8))
    if not y or not m or not d then return nil end
    if m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    return os.time({ year = y, month = m, day = d, hour = 12 })
end

--- 计算两个 YYYYMMDD 日期之间的真实天数差（BM-S4D 收口）
--- 跨月/跨年均能正确返回，例如 20260531→20260601 返回 1。
---@param todayNum number 今天的 YYYYMMDD 整数
---@param cloudDate number 云端存储的 YYYYMMDD 整数
---@return number 真实天数差（todayNum > cloudDate 时为正数），解析失败回退为数值差
function BMConfig.RealDayGap(todayNum, cloudDate)
    local t1 = BMConfig.DateToTime(todayNum)
    local t2 = BMConfig.DateToTime(cloudDate)
    if t1 and t2 then
        return math.floor((t1 - t2) / 86400)
    end
    -- 降级回退：解析失败仍用数值差（不应触发）
    return todayNum - cloudDate
end

return BMConfig
