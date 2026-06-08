-- ============================================================================
-- PillRecipes.lua - 炼丹炉配方静态数据（Phase 2）
-- 职责：集中定义所有丹药配方的数值、类型、限制等
-- 依赖：仅 GameConfig（常量引用），纯数据模块
-- ============================================================================

local GameConfig = require("config.GameConfig")

local PillRecipes = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- 配方分类常量
-- ══════════════════════════════════════════════════════════════════════════════

--- 配方种类
PillRecipes.KIND_CONSUMABLE = "consumable"   -- 产出型：扣灵韵，产出消耗品到背包
PillRecipes.KIND_PERMANENT  = "permanent"    -- 永久属性型：扣灵韵+材料，永久加属性
PillRecipes.KIND_TOKEN_BOX  = "token_box"    -- 令牌盒：扣灵韵+令牌，产出盒子

--- 授权模式
PillRecipes.AUTH_NONE = "none"   -- 客户端直接执行
PillRecipes.AUTH_C2S  = "c2s"    -- 需要服务端授权后执行

--- 保存策略
PillRecipes.SAVE_SESSION   = "session_merge"  -- 会话合并保存（高频炼制）
PillRecipes.SAVE_IMMEDIATE = "immediate"      -- 即时保存（限量永久丹）

-- ══════════════════════════════════════════════════════════════════════════════
-- 产出型配方（kind = "consumable"）
-- 特征：无上限、无材料、无属性加成、直接执行
-- ══════════════════════════════════════════════════════════════════════════════

PillRecipes.CONSUMABLES = {
    qi_pill = {
        id = "qi_pill",
        name = "练气丹",
        chapter = 1,
        cost = GameConfig.QI_PILL_COST or 10,
        outputId = "qi_pill",
    },
    zhuji_pill = {
        id = "zhuji_pill",
        name = "筑基丹",
        chapter = 2,
        cost = 100,
        outputId = "zhuji_pill",
    },
    jindan_sand = {
        id = "jindan_sand",
        name = "金丹沙",
        chapter = 3,
        cost = 100,
        outputId = "jindan_sand",
    },
    yuanying_fruit = {
        id = "yuanying_fruit",
        name = "元婴果",
        chapter = 3,
        cost = 200,
        outputId = "yuanying_fruit",
    },
    jiuzhuan_jindan = {
        id = "jiuzhuan_jindan",
        name = "九转金丹",
        chapter = 4,
        cost = 500,
        outputId = "jiuzhuan_jindan",
    },
    dujie_dan = {
        id = "dujie_dan",
        name = "渡劫丹",
        chapter = 5,
        cost = 1000,
        outputId = "dujie_dan",
    },
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 永久属性型配方（kind = "permanent"）
-- 特征：有上限、需材料、永久加属性、C2S 授权
-- ══════════════════════════════════════════════════════════════════════════════

PillRecipes.PERMANENTS = {
    tiger = {
        id = "tiger",
        name = "虎骨丹",
        chapter = 1,
        cost = 10,
        material = "tiger_bone",
        materialCount = 1,
        countKey = "tiger",       -- AlchemySystem getter/setter 的 key
        maxCount = 5,
        bonusStat = "maxHp",
        bonusValue = 30,
        alsoHeal = true,          -- 加 maxHp 时同时恢复等量 hp
    },
    snake = {
        id = "snake",
        name = "灵蛇丹",
        chapter = 2,
        cost = 100,
        material = "snake_fruit",
        materialCount = 1,
        countKey = "snake",
        maxCount = 5,
        bonusStat = "atk",
        bonusValue = 10,
    },
    diamond = {
        id = "diamond",
        name = "金刚丹",
        chapter = 2,
        cost = 100,
        material = "diamond_wood",
        materialCount = 1,
        countKey = "diamond",
        maxCount = 5,
        bonusStat = "def",
        bonusValue = 8,
    },
    tempering = {
        id = "tempering",
        name = "千锤百炼丹",
        chapter = 3,
        cost = 100,
        material = "wind_eroded_grass",
        materialCount = 1,
        countKey = "tempering",
        maxCount = 50,
        bonusStat = "pillConstitution",
        bonusValue = 1,
    },
    dragon_blood = {
        id = "dragon_blood",
        name = "龙血丹",
        chapter = 4,
        cost = 500,
        material = "dragon_blood_herb",
        materialCount = 1,
        countKey = "dragonBlood",
        maxCount = 10,
        bonusStat = "maxHp",
        bonusValue = 30,
        alsoHeal = true,
    },
    sword_intent = {
        id = "sword_intent",
        name = "太虚剑丹",
        chapter = 5,
        cost = 1000,
        material = "sword_intent_crystal",
        materialCount = 1,
        countKey = "swordIntent",
        maxCount = 10,
        bonusStat = "atk",
        bonusValue = 10,
    },
    abyss_seal = {
        id = "abyss_seal",
        name = "狱甲丹",
        chapter = 5,
        cost = 1000,
        material = "abyss_seal_shard",
        materialCount = 1,
        countKey = "abyssSeal",
        maxCount = 10,
        bonusStat = "def",
        bonusValue = 8,
    },
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 令牌盒配方（kind = "token_box"）
-- 特征：无上限、消耗令牌+灵韵、产出盒子、直接执行
-- ══════════════════════════════════════════════════════════════════════════════

PillRecipes.TOKEN_BOX_LINGYUN_COST = 100
PillRecipes.TOKEN_BOX_TOKEN_COST   = 100

PillRecipes.TOKEN_BOXES = {
    { tokenId = "wubao_token",     boxId = "wubao_token_box",     chapter = 2 },
    { tokenId = "sha_hai_ling",    boxId = "sha_hai_ling_box",    chapter = 3 },
    { tokenId = "taixu_token",     boxId = "taixu_token_box",     chapter = 4 },
    { tokenId = "taixu_jianling",  boxId = "taixu_jianling_box",  chapter = 5 },
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 属性显示名称映射（用于生成成功消息）
-- ══════════════════════════════════════════════════════════════════════════════

PillRecipes.STAT_DISPLAY = {
    maxHp            = "血量上限",
    atk              = "攻击力",
    def              = "防御力",
    pillConstitution = "根骨",
}

return PillRecipes
