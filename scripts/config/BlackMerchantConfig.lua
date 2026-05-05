-- ============================================================================
-- BlackMerchantConfig.lua — 万界黑商配置表
--
-- 商品定价、汇率常量、库存上限、分类信息
-- 设计文档：docs/设计文档/万界黑商.md v0.8.1
-- ============================================================================

local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")

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

-- 筑基初期 order（黑商解锁门槛，v0.8 从金丹初期下调）
BMConfig.JINDAN_ORDER = 4

-- ============================================================================
-- 分类
-- ============================================================================

BMConfig.CATEGORY_RAKE    = "rake"      -- 上宝逊金钯碎片
BMConfig.CATEGORY_BAGUA   = "bagua"     -- 文王八卦盘碎片
BMConfig.CATEGORY_TIANDI  = "tiandi"    -- 天帝剑痕碎片
BMConfig.CATEGORY_LINGYU   = "lingyu"    -- 附灵玉
BMConfig.CATEGORY_MATERIAL     = "material"      -- 丹药材料
BMConfig.CATEGORY_EVENT        = "event"         -- 活动道具
BMConfig.CATEGORY_SPECIAL_EQUIP = "special_equip" -- 特殊装备

-- 分类显示名（标签页用）
BMConfig.CATEGORY_NAMES = {
    rake          = "逊金钯",
    bagua         = "八卦盘",
    tiandi        = "天帝剑痕",
    lingyu        = "附灵玉",
    material      = "材料",
    event         = "活动",
    special_equip = "特殊装备",
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

    -- === 丹药材料（v0.8 新增，max_stock 单独为 10，sort_order 控制显示顺序） ===
    tiger_bone         = ItemFromGame("tiger_bone",         { buy_price = 1,  sell_price = 2,  category = "material", max_stock = 10, sort_order = 1 }),
    snake_fruit        = ItemFromGame("snake_fruit",        { buy_price = 2,  sell_price = 4,  category = "material", max_stock = 10, sort_order = 2 }),
    diamond_wood       = ItemFromGame("diamond_wood",       { buy_price = 3,  sell_price = 6,  category = "material", max_stock = 10, sort_order = 3 }),
    wind_eroded_grass  = ItemFromGame("wind_eroded_grass",  { buy_price = 4,  sell_price = 8,  category = "material", max_stock = 10, sort_order = 4 }),
    lipo_essence       = ItemFromGame("lipo_essence",       { buy_price = 5,  sell_price = 10, category = "material", max_stock = 10, sort_order = 5 }),
    panshi_essence     = ItemFromGame("panshi_essence",     { buy_price = 5,  sell_price = 10, category = "material", max_stock = 10, sort_order = 6 }),
    yuanling_essence   = ItemFromGame("yuanling_essence",   { buy_price = 5,  sell_price = 10, category = "material", max_stock = 10, sort_order = 7 }),
    shihun_essence     = ItemFromGame("shihun_essence",     { buy_price = 5,  sell_price = 10, category = "material", max_stock = 10, sort_order = 8 }),
    lingxi_essence     = ItemFromGame("lingxi_essence",     { buy_price = 5,  sell_price = 10, category = "material", max_stock = 10, sort_order = 9 }),

    -- === 龙神打造材料（v0.8.1 新增，四龙掉落武器材料） ===
    dragon_scale_ice   = ItemFromGame("dragon_scale_ice",   { buy_price = 15, sell_price = 30, category = "material", max_stock = 5, sort_order = 10 }),
    dragon_scale_abyss = ItemFromGame("dragon_scale_abyss", { buy_price = 15, sell_price = 30, category = "material", max_stock = 5, sort_order = 11 }),
    dragon_scale_fire  = ItemFromGame("dragon_scale_fire",  { buy_price = 15, sell_price = 30, category = "material", max_stock = 5, sort_order = 12 }),
    dragon_scale_sand  = ItemFromGame("dragon_scale_sand",  { buy_price = 15, sell_price = 30, category = "material", max_stock = 5, sort_order = 13 }),
    gold_brick         = ItemFromGame("gold_brick",         { buy_price = 2,  sell_price = 5,  category = "material", max_stock = 10, sort_order = 14 }),

    -- === 五一活动信物（限时，福袋不可交易） ===
    mayday_wu   = ItemFromGame("mayday_wu",   { buy_price = 3, sell_price = 6, category = "event", max_stock = 5, sort_order = 1 }),
    mayday_yi   = ItemFromGame("mayday_yi",   { buy_price = 3, sell_price = 6, category = "event", max_stock = 5, sort_order = 2 }),
    mayday_kuai = ItemFromGame("mayday_kuai", { buy_price = 3, sell_price = 6, category = "event", max_stock = 5, sort_order = 3 }),
    mayday_le   = ItemFromGame("mayday_le",   { buy_price = 3, sell_price = 6, category = "event", max_stock = 5, sort_order = 4 }),

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

return BMConfig
