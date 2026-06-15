-- ============================================================================
-- MinggeData.lua - 五行命格静态配置表
-- ============================================================================
-- 只放静态配置，不写逻辑。
-- 由 MinggeSystem.lua 在运行时消费。

local MinggeData = {}

-- ============================================================================
-- 1. 五行槽位定义（5行 × 3槽 = 15 装备位）
-- ============================================================================

MinggeData.ELEMENTS = { "metal", "wood", "water", "fire", "earth" }

MinggeData.ELEMENT_NAMES = {
    metal = "金",
    wood  = "木",
    water = "水",
    fire  = "火",
    earth = "土",
}

MinggeData.SLOTS = {
    metal = { "metal1", "metal2", "metal3" },
    wood  = { "wood1",  "wood2",  "wood3" },
    water = { "water1", "water2", "water3" },
    fire  = { "fire1",  "fire2",  "fire3" },
    earth = { "earth1", "earth2", "earth3" },
}

-- 所有槽位有序列表（用于 InventoryManager 初始化）
MinggeData.ALL_SLOTS = {
    "metal1", "metal2", "metal3",
    "wood1",  "wood2",  "wood3",
    "water1", "water2", "water3",
    "fire1",  "fire2",  "fire3",
    "earth1", "earth2", "earth3",
}

MinggeData.BACKPACK_SIZE = 60

-- ============================================================================
-- 2. 品质定义
-- ============================================================================

MinggeData.QUALITIES = { "purple", "orange", "cyan" }

MinggeData.QUALITY_NAMES = {
    purple = "紫",
    orange = "橙",
    cyan   = "青",
}

-- 品质颜色（用于 UI 显示）
MinggeData.QUALITY_COLORS = {
    purple = { 180, 80, 255, 255 },
    orange = { 255, 165, 0, 255 },
    cyan   = { 0, 220, 220, 255 },
}

-- 五行元素颜色（渲染用）
MinggeData.ELEMENT_COLORS = {
    metal = { 240, 220, 130, 255 },
    wood  = { 80, 200, 80, 255 },
    water = { 80, 160, 255, 255 },
    fire  = { 255, 80, 50, 255 },
    earth = { 180, 140, 80, 255 },
}

-- 五行元素图标（地面渲染用）
MinggeData.ELEMENT_ICONS = {
    metal = "金",
    wood  = "木",
    water = "水",
    fire  = "火",
    earth = "土",
}

-- 掉落品质权重（50/30/20）
MinggeData.QUALITY_WEIGHTS = {
    purple = 50,
    orange = 30,
    cyan   = 20,
}

-- roll 区间（总轴 1~6000）
MinggeData.QUALITY_ROLL = {
    purple = { 1, 2000 },
    orange = { 2001, 4000 },
    cyan   = { 4001, 6000 },
}

-- ============================================================================
-- 3. 四象套装定义
-- ============================================================================

MinggeData.SETS = {
    qinglong = { name = "青龙", stat = "attackSpeedBonus", value = 0.08, desc = "攻速+8%" },
    baihu    = { name = "白虎", stat = "critDmg",        value = 0.20, desc = "暴击伤害+20%" },
    zhuque   = { name = "朱雀", stat = "tianzhuDamage",  value = 0.20, desc = "天诛伤害+20%" },
    xuanwu   = { name = "玄武", stat = "petSyncRate",    value = 0.08, desc = "宠物同步率+8%" },
}

MinggeData.SET_IDS = { "qinglong", "baihu", "zhuque", "xuanwu" }

-- 套装颜色（左上角角标用）
MinggeData.SET_COLORS = {
    qinglong = { 60, 200, 120, 255 },  -- 青龙·翠绿
    baihu    = { 240, 220, 100, 255 },  -- 白虎·金黄
    zhuque   = { 255, 80, 60, 255 },    -- 朱雀·朱红
    xuanwu   = { 80, 140, 220, 255 },   -- 玄武·玄蓝
}

-- 套装简称（角标显示）
MinggeData.SET_SHORT = {
    qinglong = "龙",
    baihu    = "虎",
    zhuque   = "雀",
    xuanwu   = "武",
}

-- 套装触发条件：同一五行内 3 件同套
MinggeData.SET_REQUIRED_PIECES = 3

-- ============================================================================
-- 4. 掉落规则
-- ============================================================================

MinggeData.DROP_RULES = {
    baseDropChance     = 0.05,   -- 5% 基础掉率
    setEligibleQuality = "cyan", -- 只有青品质允许判定套装
    setAttachChance    = 0.20,   -- 20% 套装附带概率
}

-- ============================================================================
-- 5. 出售灵韵规则
-- ============================================================================

-- sellPrice[tier][quality] = 灵韵数量
MinggeData.SELL_PRICE = {
    [1] = { purple = 1, orange = 2, cyan = 3 },
    [2] = { purple = 2, orange = 4, cyan = 6 },
    [3] = { purple = 3, orange = 6, cyan = 9 },
}

-- ============================================================================
-- 6. 属性定义
-- ============================================================================

-- 属性字段到玩家字段的映射
MinggeData.STAT_FIELDS = {
    atk             = "minggeAtk",
    def             = "minggeDef",
    maxHp           = "minggeHp",
    hpRegen         = "minggeHpRegen",
    killHeal        = "minggeKillHeal",
    heavyHit        = "minggeHeavyHit",
    critRate        = "minggeCritRate",
    critDmg         = "minggeCritDmg",
    moveSpeed       = "minggeSpeed",
    tianzhuChance   = "minggeTianzhuChance",
    tianzhuDamage   = "minggeTianzhuDamage",
    fortune         = "minggeFortune",
    wisdom          = "minggeWisdom",
    constitution    = "minggeConstitution",
    physique        = "minggePhysique",
    petSyncRate     = "minggePetSyncRate",
    attackSpeedBonus = "minggeAtkSpeed",
}

-- 属性显示名
MinggeData.STAT_NAMES = {
    atk             = "攻击",
    def             = "防御",
    maxHp           = "生命上限",
    hpRegen         = "生命回复",
    killHeal        = "击杀回血",
    heavyHit        = "重击",
    critRate        = "暴击率",
    critDmg         = "暴击伤害",
    moveSpeed       = "移动速度",
    tianzhuChance   = "天诛",
    tianzhuDamage   = "天诛伤害",
    fortune         = "福缘",
    wisdom          = "悟性",
    constitution    = "根骨",
    physique        = "体魄",
    attackSpeedBonus = "攻速",
    petSyncRate     = "宠物同步率",
}

-- 百分比显示属性（显示时 ×100 并加 % 后缀）
MinggeData.PERCENT_STATS = {
    critRate         = true,
    critDmg          = true,
    moveSpeed        = true,
    tianzhuChance    = true,
    tianzhuDamage    = true,
    attackSpeedBonus = true,
}

-- 保留 1 位小数的属性
MinggeData.DECIMAL_STATS = {
    hpRegen       = true,
    critRate      = true,
    critDmg       = true,
    moveSpeed     = true,
    tianzhuChance = true,
    tianzhuDamage = true,
}

-- ============================================================================
-- 7. T1/T2/T3 属性范围表
-- ============================================================================
-- 格式: STAT_RANGES[tier][statId][quality] = { min, max }
-- 百分比属性存储为小数（如 1.0% 存为 0.01）

MinggeData.STAT_RANGES = {
    -- T1 (Lv.36~85)
    [1] = {
        atk           = { purple = {3, 4},      orange = {5, 6},      cyan = {7, 8} },
        def           = { purple = {3, 4},      orange = {5, 6},      cyan = {7, 8} },
        maxHp         = { purple = {15, 20},    orange = {20, 30},    cyan = {30, 40} },
        hpRegen       = { purple = {1.5, 2.0},  orange = {2.0, 3.0},  cyan = {3.0, 4.0} },
        killHeal      = { purple = {7, 11},     orange = {12, 16},    cyan = {17, 21} },
        heavyHit      = { purple = {9, 14},     orange = {15, 20},    cyan = {21, 26} },
        critRate      = { purple = {0.010, 0.014}, orange = {0.015, 0.019}, cyan = {0.020, 0.024} },
        critDmg       = { purple = {0.025, 0.035}, orange = {0.036, 0.046}, cyan = {0.047, 0.057} },
        moveSpeed     = { purple = {0.010, 0.014}, orange = {0.015, 0.019}, cyan = {0.020, 0.024} },
        tianzhuChance = { purple = {0.010, 0.014}, orange = {0.015, 0.019}, cyan = {0.020, 0.024} },
        tianzhuDamage = { purple = {0.025, 0.035}, orange = {0.036, 0.046}, cyan = {0.047, 0.057} },
        fortune       = { purple = {1, 2},      orange = {3, 4},      cyan = {5, 6} },
        wisdom        = { purple = {1, 2},      orange = {3, 4},      cyan = {5, 6} },
        constitution  = { purple = {1, 2},      orange = {3, 4},      cyan = {5, 6} },
        physique      = { purple = {1, 2},      orange = {3, 4},      cyan = {5, 6} },
    },
    -- T2 (Lv.90~119)
    [2] = {
        atk           = { purple = {6, 7},      orange = {8, 9},      cyan = {10, 11} },
        def           = { purple = {6, 7},      orange = {8, 9},      cyan = {10, 11} },
        maxHp         = { purple = {30, 35},    orange = {35, 45},    cyan = {45, 55} },
        hpRegen       = { purple = {3.0, 3.5},  orange = {3.5, 4.5},  cyan = {4.5, 5.5} },
        killHeal      = { purple = {16, 20},    orange = {21, 25},    cyan = {26, 30} },
        heavyHit      = { purple = {20, 25},    orange = {26, 31},    cyan = {32, 37} },
        critRate      = { purple = {0.019, 0.023}, orange = {0.024, 0.028}, cyan = {0.029, 0.033} },
        critDmg       = { purple = {0.046, 0.056}, orange = {0.057, 0.067}, cyan = {0.068, 0.078} },
        moveSpeed     = { purple = {0.019, 0.023}, orange = {0.024, 0.028}, cyan = {0.029, 0.033} },
        tianzhuChance = { purple = {0.019, 0.023}, orange = {0.024, 0.028}, cyan = {0.029, 0.033} },
        tianzhuDamage = { purple = {0.046, 0.056}, orange = {0.057, 0.067}, cyan = {0.068, 0.078} },
        fortune       = { purple = {4, 5},      orange = {6, 7},      cyan = {8, 9} },
        wisdom        = { purple = {4, 5},      orange = {6, 7},      cyan = {8, 9} },
        constitution  = { purple = {4, 5},      orange = {6, 7},      cyan = {8, 9} },
        physique      = { purple = {4, 5},      orange = {6, 7},      cyan = {8, 9} },
    },
    -- T3 (Lv.120 终盘)
    [3] = {
        atk           = { purple = {9, 10},     orange = {11, 12},    cyan = {13, 14} },
        def           = { purple = {9, 10},     orange = {11, 12},    cyan = {13, 14} },
        maxHp         = { purple = {45, 50},    orange = {50, 60},    cyan = {60, 70} },
        hpRegen       = { purple = {4.5, 5.0},  orange = {5.0, 6.0},  cyan = {6.0, 7.0} },
        killHeal      = { purple = {25, 29},    orange = {30, 34},    cyan = {35, 39} },
        heavyHit      = { purple = {31, 36},    orange = {37, 42},    cyan = {43, 48} },
        critRate      = { purple = {0.028, 0.032}, orange = {0.033, 0.037}, cyan = {0.038, 0.042} },
        critDmg       = { purple = {0.067, 0.077}, orange = {0.078, 0.088}, cyan = {0.089, 0.099} },
        moveSpeed     = { purple = {0.028, 0.032}, orange = {0.033, 0.037}, cyan = {0.038, 0.042} },
        tianzhuChance = { purple = {0.028, 0.032}, orange = {0.033, 0.037}, cyan = {0.038, 0.042} },
        tianzhuDamage = { purple = {0.067, 0.077}, orange = {0.078, 0.088}, cyan = {0.089, 0.099} },
        fortune       = { purple = {7, 8},      orange = {9, 10},     cyan = {11, 12} },
        wisdom        = { purple = {7, 8},      orange = {9, 10},     cyan = {11, 12} },
        constitution  = { purple = {7, 8},      orange = {9, 10},     cyan = {11, 12} },
        physique      = { purple = {7, 8},      orange = {9, 10},     cyan = {11, 12} },
    },
}

-- ============================================================================
-- 8. 37 个命格来源表
-- ============================================================================
-- 格式: SOURCES[bossId] = { name, element, stat, tier, level }
-- bossId 与 MonsterTypes 的 typeId 对应

MinggeData.SOURCES = {
    -- ======================== T1 (15个, Lv.36~85) ========================
    kumu_king       = { name = "枯木妖王",               element = "water", stat = "hpRegen",       tier = 1, level = 36 },
    yanchan_king    = { name = "岩蟾妖王",               element = "wood",  stat = "physique",      tier = 1, level = 40 },
    canglang_king   = { name = "苍狼妖王",               element = "wood",  stat = "heavyHit",      tier = 1, level = 44 },
    liusha_son      = { name = "流沙之子",               element = "metal", stat = "killHeal",      tier = 1, level = 45 },
    chijia_king     = { name = "赤甲妖王",               element = "metal", stat = "critDmg",       tier = 1, level = 48 },
    shegu_king      = { name = "蛇骨妖王",               element = "earth", stat = "constitution",  tier = 1, level = 52 },
    lieyan_lion     = { name = "烈焰狮王",               element = "fire",  stat = "atk",           tier = 1, level = 56 },
    shen_king       = { name = "蜃妖王",                 element = "water", stat = "tianzhuChance", tier = 1, level = 60 },
    sha_wanli       = { name = "黄天大圣·沙万里",       element = "metal", stat = "tianzhuDamage", tier = 1, level = 65 },
    liusha_mother   = { name = "流沙之母",               element = "wood",  stat = "maxHp",         tier = 1, level = 65 },
    kan_boss        = { name = "沈渊衣",                 element = "fire",  stat = "wisdom",        tier = 1, level = 70 },
    gen_boss        = { name = "岩不动",                 element = "earth", stat = "def",           tier = 1, level = 75 },
    zhen_boss       = { name = "雷惊蛰",                 element = "water", stat = "critRate",      tier = 1, level = 80 },
    yin_spirit      = { name = "极阴阵灵",               element = "earth", stat = "fortune",       tier = 1, level = 85 },
    xun_boss        = { name = "风无痕",                 element = "fire",  stat = "moveSpeed",     tier = 1, level = 85 },

    -- ======================== T2 (15个, Lv.90~119) ========================
    li_boss         = { name = "炎若晦",                 element = "metal", stat = "killHeal",      tier = 2, level = 90 },
    kun_boss        = { name = "厚德生",                 element = "wood",  stat = "maxHp",         tier = 2, level = 93 },
    pei_qianyue     = { name = "问剑长老·裴千岳",       element = "wood",  stat = "heavyHit",      tier = 2, level = 95 },
    dui_boss        = { name = "泽归墟",                 element = "earth", stat = "fortune",       tier = 2, level = 96 },
    qian_boss       = { name = "司空正阳",               element = "metal", stat = "critDmg",       tier = 2, level = 99 },
    yang_spirit     = { name = "极阳阵灵",               element = "water", stat = "hpRegen",       tier = 2, level = 99 },
    dragon_ice      = { name = "封霜应龙",               element = "water", stat = "critRate",      tier = 2, level = 100 },
    dragon_abyss    = { name = "堕渊蛟龙",               element = "water", stat = "tianzhuChance", tier = 2, level = 100 },
    dragon_fire     = { name = "焚天蜃龙",               element = "metal", stat = "tianzhuDamage", tier = 2, level = 100 },
    dragon_sand     = { name = "蚀骨螭龙",               element = "earth", stat = "constitution",  tier = 2, level = 100 },
    frost_luan      = { name = "洗剑霜鸾",               element = "fire",  stat = "moveSpeed",     tier = 2, level = 100 },
    han_bailian     = { name = "铸剑长老·韩百炼",       element = "fire",  stat = "atk",           tier = 2, level = 105 },
    shi_guanlan     = { name = "守碑长老·石观澜",       element = "earth", stat = "def",           tier = 2, level = 110 },
    ning_qiwu       = { name = "别院院主·宁栖梧",       element = "wood",  stat = "physique",      tier = 2, level = 115 },
    wen_suzhang     = { name = "藏经阁主·温素章",       element = "fire",  stat = "wisdom",        tier = 2, level = 119 },

    -- ======================== T3 (7个, Lv.120) ========================
    sword_zhu       = { name = "诛仙剑",                 element = "metal", stat = "tianzhuDamage", tier = 3, level = 120 },
    sword_xian      = { name = "陷仙剑",                 element = "water", stat = "tianzhuChance", tier = 3, level = 120 },
    sword_lu        = { name = "戮仙剑",                 element = "metal", stat = "critDmg",       tier = 3, level = 120 },
    sword_jue       = { name = "绝仙剑",                 element = "water", stat = "critRate",      tier = 3, level = 120 },
    blood_general   = { name = "镇渊魔帅·噬渊血犼",     element = "wood",  stat = "maxHp",         tier = 3, level = 120 },
    marshal_shugu   = { name = "镇渊魔帅·蚀骨",         element = "earth", stat = "def",           tier = 3, level = 120 },
    marshal_liesoul = { name = "镇渊魔帅·裂魂",         element = "fire",  stat = "atk",           tier = 3, level = 120 },
}

-- ============================================================================
-- 9. 命格图标头像映射（bossId → 怪物头像资源路径）
-- ============================================================================

MinggeData.PORTRAITS = {
    -- T1
    kumu_king       = "Textures/monster_kumu_king.png",
    yanchan_king    = "Textures/monster_yanchan_king.png",
    canglang_king   = "Textures/monster_canglang_king.png",
    liusha_son      = "Textures/monster_liusha_mother.png",
    chijia_king     = "Textures/monster_chijia_king.png",
    shegu_king      = "Textures/monster_shegu_king.png",
    lieyan_lion     = "Textures/monster_lieyan_lion.png",
    shen_king       = "Textures/monster_shen_king.png",
    sha_wanli       = "Textures/monster_sha_wanli.png",
    liusha_mother   = "Textures/monster_liusha_mother_emperor.png",
    kan_boss        = "Textures/monster_kan_boss.png",
    gen_boss        = "Textures/monster_gen_boss.png",
    zhen_boss       = "Textures/monster_zhen_boss.png",
    yin_spirit      = "Textures/monster_yin_spirit.png",
    xun_boss        = "Textures/monster_xun_boss.png",
    -- T2
    li_boss         = "Textures/monster_li_boss.png",
    kun_boss        = "Textures/monster_kun_boss.png",
    pei_qianyue     = "Textures/monster_pei_qianyue.png",
    dui_boss        = "Textures/monster_dui_boss.png",
    qian_boss       = "Textures/monster_qian_boss.png",
    yang_spirit     = "Textures/monster_yang_spirit.png",
    dragon_ice      = "Textures/monster_dragon_ice.png",
    dragon_abyss    = "Textures/monster_dragon_abyss.png",
    dragon_fire     = "Textures/monster_dragon_fire.png",
    dragon_sand     = "Textures/monster_dragon_sand.png",
    frost_luan      = "Textures/monster_frost_luan.png",
    han_bailian     = "Textures/monster_han_bailian.png",
    shi_guanlan     = "Textures/monster_shi_guanlan.png",
    ning_qiwu       = "Textures/monster_ning_qiwu.png",
    wen_suzhang     = "Textures/monster_wen_suzhang.png",
    -- T3
    sword_zhu       = "image/monster_sword_zhu_20260517104708.png",
    sword_xian      = "image/monster_sword_xian_20260517104710.png",
    sword_lu        = "image/edited_monster_sword_lu_20260517105112.png",
    sword_jue       = "image/monster_sword_jue_20260517104750.png",
    blood_general   = "Textures/monster_abyss_marshal.png",
    marshal_shugu   = "Textures/monster_marshal_shugu.png",
    marshal_liesoul = "Textures/monster_marshal_liesoul.png",
}

-- ============================================================================
-- 10. 流沙之子双来源映射
-- ============================================================================
-- bossTypeId → 命格来源 bossId
-- 两个不同 monster typeId 映射到同一个命格 bossId

MinggeData.BOSS_TO_MINGGE = {
    -- 流沙之子·外域 和 流沙之子·中域 都映射到 liusha_son
    liusha_son_outer = "liusha_son",
    liusha_son_mid   = "liusha_son",

    -- Ch3 沙漠妖王（MonsterTypes 用 yao_king_N 序号命名）
    yao_king_1 = "sha_wanli",
    yao_king_2 = "shen_king",
    yao_king_3 = "lieyan_lion",
    yao_king_4 = "shegu_king",
    yao_king_5 = "chijia_king",
    yao_king_6 = "canglang_king",
    yao_king_7 = "yanchan_king",
    yao_king_8 = "kumu_king",

    -- Ch5 BOSS（MonsterTypes 用 ch5_ 前缀）
    ch5_pei_qianyue     = "pei_qianyue",
    ch5_frost_luan      = "frost_luan",
    ch5_han_bailian     = "han_bailian",
    ch5_shi_guanlan     = "shi_guanlan",
    ch5_ning_qiwu       = "ning_qiwu",
    ch5_wen_suzhang     = "wen_suzhang",
    ch5_sword_zhu       = "sword_zhu",
    ch5_sword_xian      = "sword_xian",
    ch5_sword_lu        = "sword_lu",
    ch5_sword_jue       = "sword_jue",
    ch5_abyss_marshal   = "blood_general",
    ch5_marshal_shugu   = "marshal_shugu",
    ch5_marshal_liesoul = "marshal_liesoul",
}

-- ============================================================================
-- 11. 五行属性归属（用于验证装备位匹配）
-- ============================================================================

MinggeData.ELEMENT_STATS = {
    metal = { "critDmg", "tianzhuDamage", "killHeal" },
    wood  = { "maxHp", "physique", "heavyHit" },
    water = { "critRate", "tianzhuChance", "hpRegen" },
    fire  = { "atk", "wisdom", "moveSpeed" },
    earth = { "def", "constitution", "fortune" },
}

-- ============================================================================
-- 12. 命格 ID 生成规则
-- ============================================================================
-- minggeId = element .. "_" .. bossId
-- 例如: "metal_sha_wanli", "water_kumu_king"

--- 根据 bossId 生成命格 ID
---@param bossId string
---@return string
function MinggeData.GetMinggeId(bossId)
    local source = MinggeData.SOURCES[bossId]
    if not source then return "unknown_" .. bossId end
    return source.element .. "_" .. bossId
end

--- 根据 bossId 生成命格名称（不含套装）
---@param bossId string
---@return string
function MinggeData.GetMinggeName(bossId)
    local source = MinggeData.SOURCES[bossId]
    if not source then return "未知命格" end
    local elemName = MinggeData.ELEMENT_NAMES[source.element] or "?"
    return elemName .. "命·" .. source.name
end

--- 根据 bossId 生成完整命格名称（含套装）
---@param bossId string
---@param setId string|nil
---@return string
function MinggeData.GetMinggeFullName(bossId, setId)
    local baseName = MinggeData.GetMinggeName(bossId)
    if setId and MinggeData.SETS[setId] then
        return baseName .. "·" .. MinggeData.SETS[setId].name
    end
    return baseName
end

--- 获取属性显示文本
---@param statId string
---@param value number
---@return string
function MinggeData.FormatStatValue(statId, value)
    if MinggeData.PERCENT_STATS[statId] then
        -- 百分比属性: 0.025 → "2.5%"
        return string.format("%.1f%%", value * 100)
    elseif MinggeData.DECIMAL_STATS[statId] then
        return string.format("%.1f", value)
    else
        return tostring(math.floor(value))
    end
end

return MinggeData
