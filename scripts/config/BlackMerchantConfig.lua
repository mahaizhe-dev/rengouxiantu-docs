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
BMConfig.CATEGORY_LINGYU   = "lingyu"    -- 附灵玉
BMConfig.CATEGORY_MATERIAL     = "material"      -- 丹药材料（兼容旧引用）
BMConfig.CATEGORY_CONSUMABLE_MAT = "consumable_mat" -- 消耗品（龙鳞、金砖、令牌盒等）
BMConfig.CATEGORY_HERB         = "herb"           -- 草药（炼丹材料、精华等）
-- BMConfig.CATEGORY_EVENT     = "event"         -- 活动道具（已下架）
BMConfig.CATEGORY_SPECIAL_EQUIP = "special_equip" -- 特殊装备
BMConfig.CATEGORY_SKILL_BOOK   = "skill_book"    -- 技能书

-- 分类显示名（标签页用）
BMConfig.CATEGORY_NAMES = {
    rake          = "逊金钯",
    bagua         = "八卦盘",
    tiandi        = "天帝剑痕",
    lingyu        = "附灵玉",
    consumable_mat = "消耗品",
    herb          = "草药",
    -- event      = "活动",  -- 已下架
    special_equip = "特殊装备",
    skill_book    = "技能书",
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

    -- === 消耗品（龙神材料、金砖、令牌盒） ===
    dragon_scale_ice   = ItemFromGame("dragon_scale_ice",   { buy_price = 15, sell_price = 30, category = "consumable_mat", max_stock = 5, sort_order = 1 }),
    dragon_scale_abyss = ItemFromGame("dragon_scale_abyss", { buy_price = 15, sell_price = 30, category = "consumable_mat", max_stock = 5, sort_order = 2 }),
    dragon_scale_fire  = ItemFromGame("dragon_scale_fire",  { buy_price = 15, sell_price = 30, category = "consumable_mat", max_stock = 5, sort_order = 3 }),
    dragon_scale_sand  = ItemFromGame("dragon_scale_sand",  { buy_price = 15, sell_price = 30, category = "consumable_mat", max_stock = 5, sort_order = 4 }),
    gold_brick         = ItemFromGame("gold_brick",         { buy_price = 2,  sell_price = 5,  category = "consumable_mat", max_stock = 10, sort_order = 5 }),

    -- === 令牌盒（100令牌+100灵韵炼制，买2卖4仙石，限购10） ===
    wubao_token_box    = ItemFromGame("wubao_token_box",    { buy_price = 2,  sell_price = 4,  category = "consumable_mat", max_stock = 10, sort_order = 6 }),
    sha_hai_ling_box   = ItemFromGame("sha_hai_ling_box",   { buy_price = 2,  sell_price = 4,  category = "consumable_mat", max_stock = 10, sort_order = 7 }),
    taixu_token_box    = ItemFromGame("taixu_token_box",    { buy_price = 2,  sell_price = 4,  category = "consumable_mat", max_stock = 10, sort_order = 8 }),

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
        buy_price = 15, sell_price = 30, category = "special_equip", sort_order = 4,
        boss = "四龙",
    }),

    -- === 中级技能书（紫色品质，sellPrice=1000金，收3售6仙石，限购5） ===
    -- Ch1~Ch2 基础中级
    book_atk_2       = BookItemFromData("book_atk_2",       { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 1  }),
    book_hp_2        = BookItemFromData("book_hp_2",        { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 2  }),
    book_def_2       = BookItemFromData("book_def_2",       { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 3  }),
    book_evade_2     = BookItemFromData("book_evade_2",     { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 4  }),
    book_regen_2     = BookItemFromData("book_regen_2",     { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 5  }),
    book_crit_2      = BookItemFromData("book_crit_2",      { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 6  }),
    -- Ch3 中级
    book_atkSpd_2    = BookItemFromData("book_atkSpd_2",    { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 7  }),
    book_critDmg_2   = BookItemFromData("book_critDmg_2",   { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 8  }),
    book_doubleHit_2 = BookItemFromData("book_doubleHit_2", { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 9  }),
    book_lifeSteal_2 = BookItemFromData("book_lifeSteal_2", { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 10 }),
    book_hpPerLv_2   = BookItemFromData("book_hpPerLv_2",   { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 11 }),
    book_dmgReduce_2 = BookItemFromData("book_dmgReduce_2", { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 12 }),
    book_defPerLv_2  = BookItemFromData("book_defPerLv_2",  { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 13 }),
    -- 灵兽赐主中级
    book_wisdom_owner_2       = BookItemFromData("book_wisdom_owner_2",       { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 14 }),
    book_constitution_owner_2 = BookItemFromData("book_constitution_owner_2", { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 15 }),
    book_physique_owner_2     = BookItemFromData("book_physique_owner_2",     { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 16 }),
    book_fortune_owner_2      = BookItemFromData("book_fortune_owner_2",      { buy_price = 3,  sell_price = 6,  category = "skill_book", max_stock = 5, sort_order = 17 }),

    -- === 高级技能书（橙色品质，sellPrice=3000金，收8售16仙石，限购5） ===
    book_atk_3       = BookItemFromData("book_atk_3",       { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 20 }),
    book_hp_3        = BookItemFromData("book_hp_3",        { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 21 }),
    book_def_3       = BookItemFromData("book_def_3",       { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 22 }),
    book_evade_3     = BookItemFromData("book_evade_3",     { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 23 }),
    book_regen_3     = BookItemFromData("book_regen_3",     { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 24 }),
    book_crit_3      = BookItemFromData("book_crit_3",      { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 25 }),
    book_atkSpd_3    = BookItemFromData("book_atkSpd_3",    { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 26 }),
    book_critDmg_3   = BookItemFromData("book_critDmg_3",   { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 27 }),
    book_doubleHit_3 = BookItemFromData("book_doubleHit_3", { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 28 }),
    book_lifeSteal_3 = BookItemFromData("book_lifeSteal_3", { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 29 }),
    book_hpPerLv_3   = BookItemFromData("book_hpPerLv_3",   { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 30 }),
    book_dmgReduce_3 = BookItemFromData("book_dmgReduce_3", { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 31 }),
    book_defPerLv_3  = BookItemFromData("book_defPerLv_3",  { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 32 }),
    book_wisdom_owner_3       = BookItemFromData("book_wisdom_owner_3",       { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 33 }),
    book_constitution_owner_3 = BookItemFromData("book_constitution_owner_3", { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 34 }),
    book_physique_owner_3     = BookItemFromData("book_physique_owner_3",     { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 35 }),
    book_fortune_owner_3      = BookItemFromData("book_fortune_owner_3",      { buy_price = 8,  sell_price = 16, category = "skill_book", max_stock = 5, sort_order = 36 }),
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

return BMConfig
