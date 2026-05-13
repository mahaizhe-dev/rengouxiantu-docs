-- ============================================================================
-- RedeemCodes.lua - 兑换码配置文档
-- ============================================================================
-- 使用说明：
--   1. 在下方 CODES 表中添加兑换码配置
--   2. 告诉 AI "生成兑换码" 即可自动注册到服务器
--   3. 本文件即是项目文档，可随时查阅所有已配置的兑换码
--
-- 奖励字段说明：
--   gold      = 金币数量
--   lingYun   = 灵韵数量
--   titleId   = 称号ID（见下方称号列表）
--   itemId    = 道具/装备ID
--   itemCount = 道具数量（默认1）
--
-- 限制类型（perType）：
--   "account"   - 每个账号限兑N次（默认，不填即为 account）
--   "character" - 每个角色限兑N次（同一账号不同角色可分别兑换）
--
-- 可用称号ID（来自 TitleData.lua）：
--   "pioneer"         - 先行者
--   "novice_star"     - 新星
--   "jianghu_hero"    - 江湖豪侠
--   "young_hero"      - 少年英雄
--   "veteran_xianyu"  - 老咸鱼
--   "boss_slayer_1k"  - 千斩（击杀1000 BOSS）
--   "boss_slayer_10k" - 万斩（击杀10000 BOSS）
--
-- 装备槽位（来自 EquipmentData.lua）：
--   weapon, helmet, armor, shoulder, belt, boots,
--   ring1, ring2, necklace, cape, exclusive, treasure
-- ============================================================================

local RedeemCodes = {}

--- 兑换码配置表
--- 每条记录格式：
---   code       = 兑换码（大写字母+数字，建议8位）
---   rewards    = 奖励内容（表）
---   maxUses    = 最大使用次数（0=无限）
---   perUser    = 每人限用次数（默认1）
---   perType    = 限制类型："account"=每账号(默认) / "character"=每角色
---   targetUID  = 指定玩家UID（0=全体玩家）
---   note       = 备注说明（仅文档用途，不参与逻辑）
RedeemCodes.CODES = {
    -- ========================================
    -- 示例（取消注释即可启用）：
    -- ========================================
    -- {
    --     code      = "WELCOME1",
    --     rewards   = { gold = 500, lingYun = 10 },
    --     maxUses   = 0,
    --     perUser   = 1,
    --     targetUID = 0,
    --     note      = "新手欢迎礼包",
    -- },
    -- {
    --     code      = "VIP2026",
    --     rewards   = { gold = 2000, titleId = "pioneer" },
    --     maxUses   = 100,
    --     perUser   = 1,
    --     targetUID = 0,
    --     note      = "2026限定先行者称号礼包",
    -- },
    -- {
    --     code      = "TESTGIFT",
    --     rewards   = { gold = 9999, lingYun = 999 },
    --     maxUses   = 1,
    --     perUser   = 1,
    --     targetUID = 1092360835,
    --     note      = "仅限测试账号使用",
    -- },

    -- ========================================
    -- 正式兑换码
    -- ========================================
    {
        code      = "RGXT",
        rewards   = { gold = 1000, lingYun = 10 },
        maxUses   = 0,
        perUser   = 1,
        perType   = "character",
        targetUID = 0,
        note      = "新手欢迎礼包",
    },
    {
        code      = "RGXT099",
        rewards   = { lingYun = 100 },
        maxUses   = 100,
        perUser   = 1,
        targetUID = 0,
        note      = "新手欢迎礼包",
    },
    {
        code      = "TAIXU666",
        rewards   = { itemId = "gold_bar", itemCount = 10, lingYun = 100 },
        maxUses   = 100,
        perUser   = 1,
        targetUID = 0,
        note      = "通用礼包：10金条+100灵韵",
    },
    -- 以下已废除（2026-04-06）
    { code = "SHOUHU873V2", enabled = false, rewards = {}, note = "已废除" },
    { code = "SUIPIAN2019", enabled = false, rewards = {}, note = "已废除" },
    { code = "SHOUHU849V2", enabled = false, rewards = {}, note = "已废除" },
    { code = "BUFA873",     enabled = false, rewards = {}, note = "已废除" },

    -- 以下专属码已废除（2026-04-24）
    { code = "VIP873A",  enabled = false, rewards = {}, note = "已废除" },
    { code = "VIP116A",  enabled = false, rewards = {}, note = "已废除" },
    { code = "VIP2019A", enabled = false, rewards = {}, note = "已废除" },
    { code = "VIP579A",  enabled = false, rewards = {}, note = "已废除" },
    { code = "VIP1074A", enabled = false, rewards = {}, note = "已废除" },
    { code = "VIP376A",  enabled = false, rewards = {}, note = "已废除" },
    { code = "VIP230A",  enabled = false, rewards = {}, note = "已废除" },
    { code = "VIP873B",  enabled = false, rewards = {}, note = "已废除" },
    { code = "VIP376B",  enabled = false, rewards = {}, note = "已废除" },

    -- ====== 2026-04-24 新增 ======
    {
        code      = "VIP1144A",
        rewards   = {
            { type = "lingYun", amount = 200 },
            { type = "item", id = "item_guardian_token", amount = 2 },
        },
        maxUses   = 1,
        perUser   = 1,
        targetUID = 1144778218,
        note      = "1144778218专属：灵韵200+守护者证明x2",
    },
    {
        code      = "VIP849A",
        rewards   = {
            { type = "item", id = "taixu_token", amount = 500 },
            { type = "item", id = "item_guardian_token", amount = 1 },
        },
        maxUses   = 1,
        perUser   = 1,
        targetUID = 849655543,
        note      = "849655543专属：太虚令x500+守护者证明x1",
    },
    {
        code      = "VIP230B",
        rewards   = {
            { type = "lingYun", amount = 1000 },
            { type = "item", id = "item_guardian_token", amount = 3 },
        },
        maxUses   = 1,
        perUser   = 1,
        targetUID = 230729385,
        note      = "230729385专属：灵韵1000+守护者证明x3",
        disabled  = true,
    },
    {
        code      = "VIP230C",
        rewards   = {
            { type = "item", id = "dragon_scale_sand", amount = 1 },
            { type = "item", id = "item_guardian_token", amount = 3 },
        },
        maxUses   = 1,
        perUser   = 1,
        targetUID = 230729385,
        note      = "230729385专属：蚀骨龙牙x1+守护者证明x3",
    },
}

return RedeemCodes
