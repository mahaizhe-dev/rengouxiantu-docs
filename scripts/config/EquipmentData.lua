-- ============================================================================
-- EquipmentData.lua - 装备数据表
-- ============================================================================

local EquipmentData = {}

-- 装备槽位类型（全部12个槽位，按UI布局排列）
-- 布局 4x3:
--   项链(暴击)    头盔(生命)    肩膀(防御)
--   武器(攻击)    衣服(防御)    披风(减伤)*稀有
--   戒指(攻击)    腰带(生命)    戒指(攻击)
--   专属(技能伤)* 鞋子(移速)    法宝(生命恢复)*稀有
EquipmentData.SLOTS = {
    "necklace",   -- 项链
    "helmet",     -- 头盔
    "shoulder",   -- 肩膀
    "weapon",     -- 武器
    "armor",      -- 衣服
    "cape",       -- 披风（稀有，仅BOSS掉落）
    "ring1",      -- 戒指1
    "belt",       -- 腰带
    "ring2",      -- 戒指2
    "exclusive",  -- 专属（稀有，未来版本解锁）
    "boots",      -- 鞋子
    "treasure",   -- 法宝（稀有，仅BOSS掉落）
}

-- 标准装备槽（小怪可掉落的制式装备）
EquipmentData.STANDARD_SLOTS = {
    "weapon", "helmet", "armor", "shoulder", "belt", "boots", "ring1", "ring2", "necklace"
}

-- 稀有装备槽（非常规掉落：披风、法宝、专属）
EquipmentData.SPECIAL_SLOTS = { "cape", "treasure", "exclusive" }

-- 装备槽显示名
EquipmentData.SLOT_NAMES = {
    weapon = "武器", helmet = "头盔", armor = "衣服", shoulder = "肩膀",
    belt = "腰带", boots = "鞋子", ring1 = "戒指", ring2 = "戒指",
    necklace = "项链", cape = "披风", treasure = "葫芦", exclusive = "法宝",
}

-- 每个槽位的主属性类型（按图片定义）
EquipmentData.MAIN_STAT = {
    necklace  = "critRate",    -- 项链 → 暴击
    helmet    = "maxHp",       -- 头盔 → 生命
    shoulder  = "def",         -- 肩膀 → 防御
    weapon    = "atk",         -- 武器 → 攻击
    armor     = "def",         -- 衣服 → 防御
    cape      = "dmgReduce",   -- 披风 → 减伤（稀有）
    ring1     = "atk",         -- 戒指 → 攻击
    belt      = "maxHp",       -- 腰带 → 生命
    ring2     = "atk",         -- 戒指 → 攻击
    exclusive = "wisdom",      -- 专属 → 悟性（仙元属性）
    boots     = "speed",       -- 鞋子 → 移动速度
    treasure  = "hpRegen",     -- 法宝 → 生命恢复（稀有）
}

-- 主属性基础值（T1 白装基准）
EquipmentData.BASE_MAIN_STAT = {
    necklace  = { critRate = 0.03 },
    helmet    = { maxHp = 20 },
    shoulder  = { def = 3 },
    weapon    = { atk = 5 },
    armor     = { def = 4 },
    cape      = { dmgReduce = 0.02 },
    ring1     = { atk = 3 },
    belt      = { maxHp = 15 },
    ring2     = { atk = 3 },
    exclusive = { wisdom = 5 },  -- 基础悟性值（整数属性，使用 TIER_MULTIPLIER）
    boots     = { speed = 0.03 },
    treasure  = { hpRegen = 1.0 },
}

-- 阶级×槽位的中式名称
EquipmentData.TIER_SLOT_NAMES = {
    [1] = {
        weapon = "铁剑", helmet = "布帽", armor = "布衣", shoulder = "布肩",
        belt = "粗布带", boots = "布靴", ring1 = "铜戒", ring2 = "铜戒",
        necklace = "铜链", cape = "粗布披风", treasure = "酒葫芦", exclusive = "无",
    },
    [2] = {
        weapon = "玄铁剑", helmet = "皮盔", armor = "皮甲", shoulder = "皮肩",
        belt = "兽皮带", boots = "皮靴", ring1 = "银戒", ring2 = "银戒",
        necklace = "银链", cape = "锦缎披风", treasure = "灵符", exclusive = "无",
    },
    [3] = {
        weapon = "精钢剑", helmet = "锻铁盔", armor = "链甲", shoulder = "锻铁肩",
        belt = "锻铁带", boots = "锻铁靴", ring1 = "金戒", ring2 = "金戒",
        necklace = "金链", cape = "锦绣披风", treasure = "玉符", exclusive = "无",
    },
    [4] = {
        weapon = "灵纹剑", helmet = "玄铁盔", armor = "锁子甲", shoulder = "玄铁肩",
        belt = "灵纹带", boots = "玄铁靴", ring1 = "玉戒", ring2 = "玉戒",
        necklace = "玉佩", cape = "灵纹披风", treasure = "灵玉", exclusive = "无",
    },
    -- T5 筑基（Lv.25+）
    [5] = {
        weapon = "青锋剑", helmet = "寒铁盔", armor = "玄甲", shoulder = "寒铁肩",
        belt = "寒玉带", boots = "寒铁靴", ring1 = "灵石戒", ring2 = "灵石戒",
        necklace = "灵石坠", cape = "青云披风", treasure = "灵晶", exclusive = "无",
    },
    -- T6 金丹（Lv.40+）
    [6] = {
        weapon = "赤霄剑", helmet = "紫金盔", armor = "紫金甲", shoulder = "紫金肩",
        belt = "紫金腰环", boots = "紫金靴", ring1 = "丹晶戒", ring2 = "丹晶戒",
        necklace = "丹晶链", cape = "紫霞披风", treasure = "丹晶", exclusive = "无",
    },
    -- T7 元婴（Lv.55+）
    [7] = {
        weapon = "碧落剑", helmet = "天蚕盔", armor = "天蚕甲", shoulder = "天蚕肩",
        belt = "天蚕丝带", boots = "天蚕靴", ring1 = "元灵戒", ring2 = "元灵戒",
        necklace = "元灵坠", cape = "天蚕披风", treasure = "元灵珠", exclusive = "无",
    },
    -- T8 化神（Lv.70+）
    [8] = {
        weapon = "星陨剑", helmet = "星辰盔", armor = "星辰甲", shoulder = "星辰肩",
        belt = "星辰带", boots = "星辰靴", ring1 = "星辰戒", ring2 = "星辰戒",
        necklace = "星辰链", cape = "星辰披风", treasure = "星辰石", exclusive = "无",
    },
    -- T9 合体（Lv.85+）
    [9] = {
        weapon = "龙渊剑", helmet = "龙鳞盔", armor = "龙鳞甲", shoulder = "龙鳞肩",
        belt = "龙骨带", boots = "龙鳞靴", ring1 = "龙骨戒", ring2 = "龙骨戒",
        necklace = "龙骨坠", cape = "龙鳞披风", treasure = "龙珠", exclusive = "无",
    },
    -- T10 大乘（Lv.100+）
    [10] = {
        weapon = "九霄剑", helmet = "九霄盔", armor = "九霄甲", shoulder = "九霄肩",
        belt = "九霄带", boots = "九霄靴", ring1 = "九霄戒", ring2 = "九霄戒",
        necklace = "九霄链", cape = "九霄披风", treasure = "九霄珠", exclusive = "无",
    },
    -- T11 谪仙（Lv.120+）
    [11] = {
        weapon = "破天剑", helmet = "天劫盔", armor = "天劫甲", shoulder = "天劫肩",
        belt = "天劫带", boots = "天劫靴", ring1 = "天劫戒", ring2 = "天劫戒",
        necklace = "天劫链", cape = "天劫披风", treasure = "天劫珠", exclusive = "无",
    },
}

-- 阶级倍率（T1~T11）
-- T1凡人 T2凡人 T3练气 T4练气 T5筑基 T6金丹 T7元婴 T8化神 T9合体 T10大乘 T11谪仙
EquipmentData.TIER_MULTIPLIER = {
    [1]  = 1.0,
    [2]  = 2.0,
    [3]  = 3.0,
    [4]  = 4.5,
    [5]  = 6.0,
    [6]  = 8.0,
    [7]  = 10.5,
    [8]  = 13.5,
    [9]  = 17.0,
    [10] = 21.0,
    [11] = 25.0,
}

-- 百分比主属性阶级倍率（critRate 等百分比属性用此表，增长平缓，避免溢出）
EquipmentData.PCT_TIER_MULTIPLIER = {
    [1]  = 1.0,
    [2]  = 1.5,
    [3]  = 2.0,
    [4]  = 2.5,
    [5]  = 3.0,
    [6]  = 4.0,
    [7]  = 5.0,
    [8]  = 6.0,
    [9]  = 7.0,
    [10] = 8.0,
    [11] = 9.0,
}

-- 百分比副属性阶级倍率（critRate / critDmg 用此表）
EquipmentData.PCT_SUB_TIER_MULT = {
    [1]  = 1.0,
    [2]  = 1.3,
    [3]  = 1.6,
    [4]  = 2.0,
    [5]  = 2.5,
    [6]  = 3.0,
    [7]  = 3.8,
    [8]  = 4.8,
    [9]  = 6.0,
    [10] = 7.5,
    [11] = 9.0,
}

-- 百分比类副属性集合（用于判断走哪个倍率表）
EquipmentData.PCT_STATS = {
    critRate = true,
    critDmg = true,
}

-- 百分比类主属性集合
EquipmentData.PCT_MAIN_STATS = {
    critRate = true,
    speed = true,
    dmgReduce = true,
}

-- 整数型主属性集合（使用 TIER_MULTIPLIER 而非 PCT_TIER_MULTIPLIER）
-- 与默认数值型主属性相同倍率，但需要标记以区分百分比
EquipmentData.INT_MAIN_STATS = {
    wisdom = true,
}

-- 线性增长副属性集合（value = floor(tier × qualityMult)，无随机）
EquipmentData.LINEAR_GROWTH_STATS = {
    killGold = true,  -- 保留旧标记兼容
    fortune = true,
    wisdom = true,
    constitution = true,
    physique = true,
}

-- 可用副属性池（baseValue 约为对应主属性基础值的 30%）
EquipmentData.SUB_STATS = {
    { stat = "atk",       name = "攻击力",   baseValue = 1.5 },
    { stat = "def",       name = "防御力",   baseValue = 1.2 },
    { stat = "maxHp",     name = "生命值",   baseValue = 6 },
    { stat = "hpRegen",   name = "生命回复", baseValue = 0.5 },
    { stat = "killHeal",  name = "击杀回血", baseValue = 3 },
    { stat = "critRate",  name = "暴击率",   baseValue = 0.01 },
    { stat = "critDmg",   name = "暴击伤害", baseValue = 0.05 },
    { stat = "heavyHit",  name = "重击值",   baseValue = 8 },
    { stat = "fortune",   name = "福缘",     baseValue = 1, linearGrowth = true },
    { stat = "wisdom",    name = "悟性",     baseValue = 1, linearGrowth = true },
    { stat = "constitution", name = "根骨",  baseValue = 1, linearGrowth = true },
    { stat = "physique",     name = "体魄",  baseValue = 1, linearGrowth = true },
}

-- 副属性强度（按阶级递增）
EquipmentData.SUB_STAT_TIER_MULT = {
    [1]  = 1.0,
    [2]  = 1.5,
    [3]  = 2.2,
    [4]  = 3.0,
    [5]  = 4.0,
    [6]  = 5.5,
    [7]  = 7.0,
    [8]  = 9.0,
    [9]  = 11.0,
    [10] = 13.0,
    [11] = 15.0,
}

-- ===================== 特殊装备（BOSS 专属掉落） =====================

EquipmentData.SpecialEquipment = {
    -- 初始法宝：酒葫芦（T1绿·初始法宝，附带治愈技能）
    -- 主属性: 1.0 × 1.0 × 1.1(绿) = 1.1
    -- 副属性: 绿色1条, 中值×1.0
    jade_gourd = {
        name = "酒葫芦",
        slot = "treasure",
        icon = "icon_jade_gourd.png",
        quality = "green",
        tier = 1,
        sellPrice = 100,
        mainStat = { hpRegen = 1.1 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 6 },
        },
        skillId = "jade_gourd_heal",  -- 治愈技能，CD30秒，回血10秒
    },

    -- 拦路猪妖掉落：T1紫色头盔
    -- 主属性(maxHp): 20 × 1.0(T1) × 1.3(紫) = 26
    -- 副属性: 紫色3条, subBase × SUB_T1(1.0) × 1.3(紫)
    boar_patrol_helmet = {
        name = "猪妖铁盔",
        slot = "helmet",
        icon = "icon_boar_patrol_helmet.png",
        quality = "purple",
        tier = 1,
        sellPrice = 100,
        mainStat = { maxHp = 26 },
        subStats = {
            { stat = "def", name = "防御力", value = 1.56 },      -- 1.2 × 1.0(SUB_T1) × 1.3(紫) = 1.56
            { stat = "atk", name = "攻击力", value = 1.95 },      -- 1.5 × 1.0(SUB_T1) × 1.3(紫) = 1.95
            { stat = "hpRegen", name = "生命回复", value = 0.65 }, -- 0.5 × 1.0(SUB_T1) × 1.3(紫) = 0.65
        },
        desc = "拦路猪妖用粗铁敲出的简陋头盔，虽然做工粗糙，但意外地结实。",
    },

    -- 猪三哥掉落：T2紫色武器
    -- 主属性: 5 × 2.0(T2) × 1.3(紫) = 13
    -- 副属性: 紫色3条, 中值×1.0
    boar_king_weapon = {
        name = "猪三哥战斧",
        slot = "weapon",
        icon = "icon_boar_king_weapon.png",
        quality = "purple",
        tier = 2,
        sellPrice = 200,
        mainStat = { atk = 13 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 2.25 },     -- 1.5 × 1.5(T2) = 2.25
            { stat = "maxHp", name = "生命值", value = 9 },     -- 6 × 1.5(T2) = 9
            { stat = "constitution", name = "根骨", value = 2 },  -- linearGrowth: floor(2 × 1.3) = 2
        },
    },

    -- 大大王掉落：T3紫色披风
    -- 主属性: 2 × 3.0(T3) × 1.3(紫) = 7.8
    -- 副属性: 紫色3条, 中值×1.0
    boss_cape = {
        name = "大大王战袍",
        slot = "cape",
        icon = "icon_bandit_boss_cape.png",
        quality = "purple",
        tier = 3,
        sellPrice = 300,
        mainStat = { dmgReduce = 0.05 },
        subStats = {
            { stat = "def", name = "防御力", value = 2.64 },       -- 1.2 × 2.2(T3) = 2.64
            { stat = "maxHp", name = "生命值", value = 13.2 },   -- 6 × 2.2(T3) = 13.2
            { stat = "atk", name = "攻击力", value = 3.3 },      -- 1.5 × 2.2(T3) = 3.3
        },
    },

    -- 二大王掉落：T3紫色腰带
    -- 主属性(maxHp): 15 × 3.0(T3) × 1.3(紫) = 58.5
    -- 副属性: 紫色3条, subBase × SUB_T3(2.2) × 1.3(紫)
    bandit_second_belt = {
        name = "霸刀腰带",
        slot = "belt",
        icon = "icon_bandit_second_belt.png",
        quality = "purple",
        tier = 3,
        sellPrice = 300,
        mainStat = { maxHp = 58.5 },
        subStats = {
            { stat = "def", name = "防御力", value = 3.43 },       -- 1.2 × 2.2(SUB_T3) × 1.3(紫) = 3.432
            { stat = "atk", name = "攻击力", value = 4.29 },       -- 1.5 × 2.2(SUB_T3) × 1.3(紫) = 4.29
            { stat = "killHeal", name = "击杀回血", value = 8.58 }, -- 3 × 2.2(SUB_T3) × 1.3(紫) = 8.58
        },
        desc = "这条腰带宽如手掌，据说二大王靠它挡住过大大王的全力一刀。",
    },

    -- 蛛母掉落：T2紫色戒指
    -- 主属性: 3 × 2.0(T2) × 1.3(紫) = 7.8
    -- 副属性: 紫色3条, 中值×1.0
    spider_queen_ring = {
        name = "蛛母毒丝戒",
        slot = "ring1",
        icon = "icon_spider_queen_ring.png",
        quality = "purple",
        tier = 2,
        sellPrice = 200,
        mainStat = { atk = 7.8 },
        subStats = {
            { stat = "critRate", name = "暴击率", value = 0.013 },   -- 0.01 × 1.3(PCT_SUB T2) = 0.013
            { stat = "heavyHit", name = "重击值", value = 12 },       -- 8 × 1.5(T2) = 12
            { stat = "killHeal", name = "击杀回血", value = 4.5 },  -- 3 × 1.5(T2) = 4.5
        },
    },

    -- 虎王掉落：3件套（武器/铠甲 T3紫，项链 T4橙）
    -- tiger_set_weapon: 主属性 5 × 3.0(T3) × 1.3(紫) = 19.5
    -- 副属性: 紫色3条, 中值×1.0
    tiger_set_weapon = {
        name = "虎牙刃",
        slot = "weapon",
        icon = "icon_tiger_set_weapon.png",
        quality = "purple",
        tier = 3,
        sellPrice = 300,
        setId = "tiger_king",
        mainStat = { atk = 19.5 },
        subStats = {
            { stat = "def", name = "防御力", value = 2.64 },       -- 1.2 × 2.2(T3) = 2.64
            { stat = "maxHp", name = "生命值", value = 13.2 },   -- 6 × 2.2(T3) = 13.2
            { stat = "wisdom", name = "悟性", value = 3 },       -- linearGrowth: floor(3 × 1.3) = 3
        },
    },
    -- tiger_set_armor: 主属性 4 × 3.0(T3) × 1.3(紫) = 15.6
    -- 副属性: 紫色3条, 中值×1.0
    tiger_set_armor = {
        name = "虎王铠",
        slot = "armor",
        icon = "icon_tiger_set_armor.png",
        quality = "purple",
        tier = 3,
        sellPrice = 300,
        setId = "tiger_king",
        mainStat = { def = 15.6 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 13.2 },   -- 6 × 2.2(T3) = 13.2
            { stat = "atk", name = "攻击力", value = 3.3 },        -- 1.5 × 2.2(T3) = 3.3
            { stat = "physique", name = "体魄", value = 3 },     -- linearGrowth: floor(3 × 1.3) = 3
        },
    },
    -- tiger_set_necklace: 主属性 0.03 × 2.5(PCT_T4) × 1.5(橙) ≈ 0.1125 → 0.11
    -- 副属性: 橙色3条, 中值×1.0 (橙色shift +0.1 仅影响随机装备)
    tiger_set_necklace = {
        name = "虎王血珀",
        slot = "necklace",
        icon = "icon_tiger_set_necklace.png",
        quality = "orange",
        tier = 4,
        sellPrice = 400,
        setId = "tiger_king",
        mainStat = { critRate = 0.11 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 4.95 },       -- 1.5 × 3.0(SUB T4) × 1.1(橙mid) = 4.95
            { stat = "def", name = "防御力", value = 3.96 },       -- 1.2 × 3.0(SUB T4) × 1.1(橙mid) = 3.96
            { stat = "fortune", name = "福缘", value = 6 },      -- linearGrowth: floor(4 × 1.5) = 6
        },
        specialEffect = {
            type = "bleed_dot",
            name = "流血",
            damagePercent = 0.08,  -- 每秒8%攻击力（无视防御）
            duration = 3,          -- 持续3秒
            triggerChance = 0.35,  -- 35%触发概率
            cooldown = 3,          -- 内置CD 3秒
            -- 刷新逻辑：CD期间不可触发，持续期间再次触发重置duration
        },
    },
    -- 虎王掉落：T4紫色披风（与虎王血珀共享10%池）
    -- 主属性(dmgReduce): 0.02 × 2.5(PCT_T4) × 1.3(紫) = 0.065
    -- 副属性: 紫色3条, subBase × SUB_T4(3.0) × 1.3(紫)
    tiger_set_cape = {
        name = "虎纹战袍",
        slot = "cape",
        icon = "icon_tiger_set_cape.png",
        quality = "purple",
        tier = 4,
        sellPrice = 400,
        setId = "tiger_king",
        mainStat = { dmgReduce = 0.065 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 5.85 },     -- 1.5 × 3.0(SUB_T4) × 1.3(紫) = 5.85
            { stat = "maxHp", name = "生命值", value = 23.4 },   -- 6 × 3.0(SUB_T4) × 1.3(紫) = 23.4
            { stat = "physique", name = "体魄", value = 5 },     -- linearGrowth: floor(4 × 1.3) = 5
        },
        desc = "虎王亲自以虎皮缝制的战袍，纹路似活物般蜿蜒，穿上便如虎添翼。",
    },

    -- #帝尊壹戒（虎王5%独立掉落）：T3 橙/稀世 戒指
    -- 主属性: 3 × 3.0(T3) × 1.5(橙) = 13.5
    -- 副属性: 橙色3条, linearGrowth: floor(3 × 1.5) = 4
    dizun_ring_ch1 = {
        name = "帝尊壹戒",
        desc = "帝尊初出茅庐时所铸之戒，承载少年意气与破境之志。",
        slot = "ring1",
        icon = "icon_dizun_ring_ch1.png",
        quality = "orange",
        tier = 3,
        sellPrice = 300,
        mainStat = { atk = 13.5 },
        subStats = {
            { stat = "wisdom", name = "悟性", value = 4 },           -- floor(3 × 1.5) = 4
            { stat = "constitution", name = "根骨", value = 4 },     -- floor(3 × 1.5) = 4
            { stat = "physique", name = "体魄", value = 4 },         -- floor(3 × 1.5) = 4
        },
    },

    -- ===================== 第二章特殊装备 =====================

    -- 世界掉落：T4橙色头盔（区域2精英/BOSS均可掉落）
    -- 主属性: 20 × 4.5(T4) × 1.5(橙) = 135
    -- 副属性: 3条fortune（linearGrowth: floor(4 × 1.5) = 6）
    gold_helmet_ch2 = {
        name = "招财金盔",
        slot = "helmet",
        icon = "icon_gold_helmet_ch2.png",
        quality = "orange",
        tier = 4,
        sellPrice = 400,
        mainStat = { maxHp = 135 },
        subStats = {
            { stat = "fortune", name = "福缘", value = 6 },
            { stat = "fortune", name = "福缘", value = 6 },
            { stat = "fortune", name = "福缘", value = 6 },
        },
    },

    -- 猪大哥掉落：T4紫色腰带
    -- 主属性: 15 × 4.5(T4) × 1.3(紫) = 87.75
    -- 副属性: 紫色3条, 中值×1.0
    boar_belt_ch2 = {
        name = "蛮力腰带",
        slot = "belt",
        icon = "icon_boar_belt_ch2.png",
        quality = "purple",
        tier = 4,
        sellPrice = 400,
        mainStat = { maxHp = 87.75 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 4.5 },      -- 1.5 × 3.0(SUB_T4) = 4.5
            { stat = "constitution", name = "根骨", value = 5 },  -- linearGrowth: floor(4 × 1.3) = 5
            { stat = "heavyHit", name = "重击值", value = 24 },   -- 8 × 3.0(SUB_T4) = 24
        },
    },

    -- 蛇王掉落：T5紫色披风（稀有部位）
    -- 主属性: 0.02 × 3.0(PCT_T5) × 1.3(紫) = 0.078
    -- 副属性: 紫色3条, 中值×1.0
    snake_cape_ch2 = {
        name = "蛇鳞披风",
        slot = "cape",
        icon = "icon_snake_cape_ch2.png",
        quality = "purple",
        tier = 5,
        sellPrice = 500,
        mainStat = { dmgReduce = 0.078 },
        subStats = {
            { stat = "def", name = "防御力", value = 4.8 },      -- 1.2 × 4.0(SUB_T5) = 4.8
            { stat = "fortune", name = "福缘", value = 9 },      -- linearGrowth: floor(5 × 1.8) = 9
            { stat = "killHeal", name = "击杀回血", value = 12 }, -- 3 × 4.0(SUB_T5) = 12
        },
    },

    -- 乌地北掉落：T4橙色肩膀
    -- 主属性: 3 × 4.5(T4) × 1.5(橙) = 20.25
    -- 副属性: 橙色3条, 中值×1.1
    wu_shoulder_ch2 = {
        name = "玄铁肩甲",
        slot = "shoulder",
        icon = "icon_wu_shoulder_ch2.png",
        quality = "orange",
        tier = 4,
        sellPrice = 400,
        mainStat = { def = 20.25 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 19.8 },    -- 6 × 3.0(SUB_T4) × 1.1(橙) = 19.8
            { stat = "physique", name = "体魄", value = 6 },      -- linearGrowth: floor(4 × 1.5) = 6
            { stat = "hpRegen", name = "生命回复", value = 1.65 }, -- 0.5 × 3.0(SUB_T4) × 1.1(橙) = 1.65
        },
    },

    -- 乌天南掉落：T5紫色武器
    -- 主属性: 5 × 6.0(T5) × 1.3(紫) = 39
    -- 副属性: 紫色3条, 中值×1.0
    wu_weapon_ch2 = {
        name = "南刀·裂风",
        slot = "weapon",
        icon = "icon_wu_weapon_ch2.png",
        quality = "purple",
        tier = 5,
        sellPrice = 500,
        mainStat = { atk = 39 },
        subStats = {
            { stat = "def", name = "防御力", value = 4.8 },      -- 1.2 × 4.0(SUB_T5) = 4.8
            { stat = "atk", name = "攻击力", value = 6.0 },      -- 1.5 × 4.0(SUB_T5) = 6.0
            { stat = "critRate", name = "暴击率", value = 0.025 }, -- 0.01 × 2.5(PCT_SUB_T5) = 0.025
        },
    },

    -- 乌万仇掉落：T5橙色戒指（乌堡双煞套装 2件套之一）
    -- 主属性: 3 × 6.0(T5) × 1.5(橙) = 27
    -- 副属性: 橙色3条, 中值×1.1
    wu_ring_chou = {
        name = "乌堡戒·仇",
        slot = "ring1",
        icon = "icon_wu_ring_chou.png",
        quality = "orange",
        tier = 5,
        sellPrice = 500,
        setId = "wu_rings",
        mainStat = { atk = 27 },
        subStats = {
            { stat = "def", name = "防御力", value = 5.28 },      -- 1.2 × 4.0(SUB_T5) × 1.1(橙) = 5.28
            { stat = "wisdom", name = "悟性", value = 7 },        -- linearGrowth: floor(5 × 1.5) = 7
            { stat = "critDmg", name = "暴击伤害", value = 0.138 }, -- 0.05 × 2.5(PCT_SUB_T5) × 1.1(橙) = 0.1375 → 0.138
        },
    },

    -- 乌万海掉落：T5橙色戒指（乌堡双煞套装 2件套之二）
    -- 主属性: 3 × 6.0(T5) × 1.5(橙) = 27
    -- 副属性: 橙色3条, 中值×1.1
    wu_ring_hai = {
        name = "乌堡戒·海",
        slot = "ring2",
        icon = "icon_wu_ring_hai.png",
        quality = "orange",
        tier = 5,
        sellPrice = 500,
        setId = "wu_rings",
        mainStat = { atk = 27 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 6.6 },       -- 1.5 × 4.0(SUB_T5) × 1.1(橙) = 6.6
            { stat = "maxHp", name = "生命值", value = 26.4 },    -- 6 × 4.0(SUB_T5) × 1.1(橙) = 26.4
            { stat = "heavyHit", name = "重击值", value = 35.2 },  -- 8 × 4.0(SUB_T5) × 1.1(橙) = 35.2
        },
    },

    -- ===================== 第三章·万里黄沙（妖王专属掉落） =====================

    -- 枯木妖王掉落：T5紫色头盔
    -- 主属性: 20 × 6.0(T5) × 1.3(紫) = 156
    -- 副属性: 紫色3条, 中值×1.0
    kumu_helmet_ch3 = {
        name = "枯木灵冠",
        slot = "helmet",
        icon = "icon_kumu_helmet_ch3.png",
        quality = "purple",
        tier = 5,
        sellPrice = 500,
        mainStat = { maxHp = 156 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 24.0 },      -- 6 × 4.0(SUB_T5) = 24.0
            { stat = "hpRegen", name = "生命回复", value = 2.0 },   -- 0.5 × 4.0(SUB_T5) = 2.0
            { stat = "physique", name = "体魄", value = 6 },       -- linearGrowth: floor(5 × 1.3) = 6
        },
    },

    -- 岩蟾妖王掉落：T5橙色铠甲
    -- 主属性: 4 × 6.0(T5) × 1.5(橙) = 36.0
    -- 副属性: 橙色3条, 中值×1.1
    yanchan_armor_ch3 = {
        name = "岩蟾石铠",
        slot = "armor",
        icon = "icon_yanchan_armor_ch3.png",
        quality = "orange",
        tier = 5,
        sellPrice = 600,
        mainStat = { def = 36.0 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 26.4 },      -- 6 × 4.0(SUB_T5) × 1.1(橙) = 26.4
            { stat = "heavyHit", name = "重击值", value = 35.2 },   -- 8 × 4.0(SUB_T5) × 1.1(橙) = 35.2
            { stat = "def", name = "防御力", value = 5.28 },        -- 1.2 × 4.0(SUB_T5) × 1.1(橙) = 5.28
        },
    },

    -- 苍狼妖王掉落：T6紫色项链
    -- 主属性: 0.03 × 4.0(PCT_T6) × 1.3(紫) = 0.156
    -- 副属性: 紫色3条, 中值×1.0
    canglang_necklace_ch3 = {
        name = "苍狼牙坠",
        slot = "necklace",
        icon = "icon_canglang_necklace_ch3.png",
        quality = "purple",
        tier = 6,
        sellPrice = 600,
        mainStat = { critRate = 0.156 },
        subStats = {
            { stat = "critRate", name = "暴击率", value = 0.03 },    -- 0.01 × 3.0(PCT_SUB_T6) = 0.03
            { stat = "def", name = "防御力", value = 6.6 },          -- 1.2 × 5.5(SUB_T6) = 6.6
            { stat = "wisdom", name = "悟性", value = 7 },           -- linearGrowth: floor(6 × 1.3) = 7
        },
    },

    -- 赤甲妖王掉落：T6紫色戒指
    -- 主属性: 3 × 8.0(T6) × 1.3(紫) = 31.2
    -- 副属性: 紫色3条, 中值×1.0
    chijia_ring_ch3 = {
        name = "赤甲毒尾戒",
        slot = "ring1",
        icon = "icon_chijia_ring_ch3.png",
        quality = "purple",
        tier = 6,
        sellPrice = 600,
        mainStat = { atk = 31.2 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 8.25 },        -- 1.5 × 5.5(SUB_T6) = 8.25
            { stat = "critDmg", name = "暴击伤害", value = 0.15 },  -- 0.05 × 3.0(PCT_SUB_T6) = 0.15
            { stat = "heavyHit", name = "重击值", value = 44 },     -- 8 × 5.5(SUB_T6) = 44
        },
    },

    -- 蛇骨妖王掉落：T6橙色腰带
    -- 主属性: 15 × 8.0(T6) × 1.5(橙) = 180
    -- 副属性: 橙色3条, 中值×1.1
    shegu_belt_ch3 = {
        name = "蛇骨腰环",
        slot = "belt",
        icon = "icon_shegu_belt_ch3.png",
        quality = "orange",
        tier = 6,
        sellPrice = 600,
        mainStat = { maxHp = 180 },
        subStats = {
            { stat = "critDmg", name = "暴击伤害", value = 0.165 }, -- 0.05 × 3.0(PCT_SUB_T6) × 1.1(橙) = 0.165
            { stat = "fortune", name = "福缘", value = 9 },          -- linearGrowth: floor(6 × 1.5) = 9
            { stat = "maxHp", name = "生命值", value = 36.3 },      -- 6 × 5.5(SUB_T6) × 1.1(橙) = 36.3
        },
    },

    -- 烈焰狮王掉落：T7橙色披风（王级BOSS，含特效）
    -- 主属性: 0.02 × 5.0(PCT_T7) × 1.5(橙) = 0.15
    -- 副属性: 橙色3条, 中值×1.1
    lieyan_cape_ch3 = {
        name = "烈焰鬃披",
        slot = "cape",
        icon = "icon_lieyan_cape_ch3.png",
        quality = "orange",
        tier = 7,
        sellPrice = 700,
        mainStat = { dmgReduce = 0.15 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 11.55 },       -- 1.5 × 7.0(SUB_T7) × 1.1(橙) = 11.55
            { stat = "critRate", name = "暴击率", value = 0.0418 },  -- 0.01 × 3.8(PCT_SUB_T7) × 1.1(橙) = 0.0418
            { stat = "heavyHit", name = "重击值", value = 61.6 },   -- 8 × 7.0(SUB_T7) × 1.1(橙) = 61.6
        },
    },

    -- 蜃妖王掉落：T7灵器肩甲（王级BOSS，含特效）
    -- 主属性: 3 × 10.5(T7) × 1.8(灵器) = 56.7
    -- 副属性: 灵器3条, 中值×1.0
    shen_shoulder_ch3 = {
        name = "蜃影肩甲",
        slot = "shoulder",
        icon = "icon_shen_shoulder_ch3.png",
        quality = "cyan",
        tier = 7,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { def = 56.7 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 42.0 },      -- 6 × 7.0(SUB_T7) = 42.0
            { stat = "constitution", name = "根骨", value = 12 },   -- linearGrowth: floor(7 × 1.8) = 12
            { stat = "critDmg", name = "暴击伤害", value = 0.19 },  -- 0.05 × 3.8(PCT_SUB_T7) = 0.19
        },
        specialEffect = {
            type = "death_immunity",
            name = "蜃影",
            immuneChance = 0.15,    -- 15%概率免疫致命伤害
            immuneDuration = 1.0,   -- 隐身1秒
        },
    },

    -- ===================== 黄天大圣·沙万里 灵器武器（共享掉落池） =====================

    -- T7灵器武器通用参数:
    -- 主属性: 5 × 10.5(T7) × 1.8(灵器) = 94.5
    -- 副属性: 灵器3条, 中值×1.0; SUB_T7=7.0, PCT_SUB_T7=3.8

    huangsha_duanliu = {
        name = "黄沙·断流",
        slot = "weapon",
        icon = "icon_huangsha_duanliu.png",
        quality = "cyan",
        tier = 7,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { atk = 94.5 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 10.5 },       -- 1.5 × 7.0 = 10.5
            { stat = "critRate", name = "暴击率", value = 0.038 },  -- 0.01 × 3.8 = 0.038
            { stat = "def", name = "防御力", value = 8.4 },         -- 1.2 × 7.0 = 8.4
        },
        specialEffect = {
            type = "wind_slash",
            name = "裂风斩",
            triggerChance = 0.20,    -- 20%概率释放风刃
            damagePercent = 1.20,    -- 造成120%攻击力额外伤害
            cooldown = 2.0,          -- 内置CD 2秒
        },
    },

    huangsha_fentian = {
        name = "黄沙·焚天",
        slot = "weapon",
        icon = "icon_huangsha_fentian.png",
        quality = "cyan",
        tier = 7,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { atk = 94.5 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 10.5 },       -- 1.5 × 7.0 = 10.5
            { stat = "maxHp", name = "生命值", value = 42 },        -- 6 × 7.0 = 42
            { stat = "physique", name = "体魄", value = 12 },       -- linearGrowth: floor(7 × 1.8) = 12
        },
        specialEffect = {
            type = "sacrifice_aura",
            name = "献祭光环",
            range = 3.0,             -- 光环范围（格）
            tickInterval = 0.5,      -- 每0.5秒跳一次伤害
            damagePercent = 0.10,    -- 每跳造成10%ATK真实伤害
            description = "持续灼烧周围敌人，每秒造成10%攻击力真实伤害",
        },
    },

    huangsha_shihun = {
        name = "黄沙·噬魂",
        slot = "weapon",
        icon = "icon_huangsha_shihun.png",
        quality = "cyan",
        tier = 7,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { atk = 94.5 },
        subStats = {
            { stat = "killHeal", name = "击杀回血", value = 21 },   -- 3 × 7.0 = 21
            { stat = "critRate", name = "暴击率", value = 0.038 },  -- 0.01 × 3.8 = 0.038
            { stat = "wisdom", name = "悟性", value = 12 },         -- linearGrowth: floor(7 × 1.8) = 12
        },
        specialEffect = {
            type = "lifesteal_burst",
            name = "噬魂",
            healPercent = 0.03,      -- 击杀时回复3%最大生命
            maxStacks = 10,          -- 击杀堆叠满10层释放AOE
            damagePercent = 1.0,     -- AOE伤害系数100%攻击力
            rectLength = 2.0,        -- 矩形长度（与伏魔刀一致）
            rectWidth = 1.0,         -- 矩形宽度（与伏魔刀一致）
            range = 2.5,             -- 搜索范围
            maxTargets = 3,          -- 最多命中3个目标
            effectColor = {160, 80, 220, 255},  -- 紫色（区分伏魔刀红色）
        },
    },

    huangsha_liedi = {
        name = "黄沙·裂地",
        slot = "weapon",
        icon = "icon_huangsha_liedi.png",
        quality = "cyan",
        tier = 7,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { atk = 94.5 },
        subStats = {
            { stat = "heavyHit", name = "重击值", value = 56 },     -- 8 × 7.0 = 56
            { stat = "constitution", name = "根骨", value = 12 },   -- linearGrowth: floor(7 × 1.8) = 12
            { stat = "def", name = "防御力", value = 8.4 },         -- 1.2 × 7.0 = 8.4
        },
        specialEffect = {
            type = "heavy_strike",
            name = "裂地",
            hitInterval = 20,        -- 每第20次攻击必定重击
            description = "每第20次攻击必定触发重击",
        },
    },

    huangsha_mieying = {
        name = "黄沙·灭影",
        slot = "weapon",
        icon = "icon_huangsha_mieying.png",
        quality = "cyan",
        tier = 7,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { atk = 94.5 },
        subStats = {
            { stat = "critDmg", name = "暴击伤害", value = 0.19 },  -- 0.05 × 3.8 = 0.19
            { stat = "critDmg", name = "暴击伤害", value = 0.19 },  -- 0.05 × 3.8 = 0.19
            { stat = "atk", name = "攻击力", value = 10.5 },        -- 1.5 × 7.0 = 10.5
        },
        specialEffect = {
            type = "shadow_strike",
            name = "灭影",
            triggerOnCrit = true,     -- 暴击时触发
            triggerChance = 0.50,     -- 50%概率追加影击
            damagePercent = 0.60,     -- 造成60%攻击力的影击
        },
    },

    -- #帝尊叁戒（沙万里/狮王/蜃妖王0.5%独立掉落）：T7 青/灵器 戒指
    -- 主属性: 3 × 10.5(T7) × 1.8(灵器) = 56.7
    -- 副属性: 灵器3条, linearGrowth: floor(7 × 1.8) = 12; 灵性属性: floor(7×1.8×0.5) = 6
    dizun_ring_ch3 = {
        name = "帝尊叁戒",
        desc = "帝尊纵横沙海时所铸之戒，黄沙万里淬炼，已具宗师之姿。",
        slot = "ring1",
        icon = "icon_dizun_ring_ch3.png",
        quality = "cyan",
        tier = 7,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { atk = 56.7 },
        subStats = {
            { stat = "wisdom", name = "悟性", value = 12 },          -- floor(7 × 1.8) = 12
            { stat = "constitution", name = "根骨", value = 12 },    -- floor(7 × 1.8) = 12
            { stat = "physique", name = "体魄", value = 12 },        -- floor(7 × 1.8) = 12
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 6 }, -- floor(7×1.8×0.5) = 6
    },

    -- ===================== 龙神圣器武器（神真子打造，T7灵器→T9圣器） =====================

    -- T9圣器武器通用参数:
    -- 主属性: 5 × 17.0(T9) × 2.1(圣器) = 178.5
    -- 副属性: 圣器4条(原3条+1灵性), 中值×1.0; SUB_T9=11.0, PCT_SUB_T9=6.0
    -- 灵性属性: linearGrowth, floor(9×2.1×0.5) = 9
    -- 特效: 继承T7灵器特效不变

    shengqi_duanliu = {
        name = "龙极·断流",
        slot = "weapon",
        icon = "icon_huangsha_duanliu.png",
        quality = "red",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 178.5 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 16.5 },        -- 1.5 × 11.0 = 16.5
            { stat = "critRate", name = "暴击率", value = 0.06 },   -- 0.01 × 6.0 = 0.06
            { stat = "def", name = "防御力", value = 13.2 },        -- 1.2 × 11.0 = 13.2
        },
        spiritStat = { stat = "constitution", name = "根骨", value = 9 },  -- floor(9×2.1×0.5) = 9
        specialEffect = {
            type = "wind_slash",
            name = "裂风斩",
            triggerChance = 0.20,
            damagePercent = 1.20,
            cooldown = 2.0,
        },
    },

    shengqi_fentian = {
        name = "龙极·焚天",
        slot = "weapon",
        icon = "icon_huangsha_fentian.png",
        quality = "red",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 178.5 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 16.5 },        -- 1.5 × 11.0 = 16.5
            { stat = "maxHp", name = "生命值", value = 66 },        -- 6 × 11.0 = 66
            { stat = "physique", name = "体魄", value = 18 },       -- linearGrowth: floor(9 × 2.1) = 18
        },
        spiritStat = { stat = "wisdom", name = "悟性", value = 9 },  -- floor(9×2.1×0.5) = 9
        specialEffect = {
            type = "sacrifice_aura",
            name = "献祭光环",
            range = 3.0,
            tickInterval = 0.5,
            damagePercent = 0.10,
            description = "持续灼烧周围敌人，每秒造成10%攻击力真实伤害",
        },
    },

    shengqi_shihun = {
        name = "龙极·噬魂",
        slot = "weapon",
        icon = "icon_huangsha_shihun.png",
        quality = "red",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 178.5 },
        subStats = {
            { stat = "killHeal", name = "击杀回血", value = 33 },   -- 3 × 11.0 = 33
            { stat = "critRate", name = "暴击率", value = 0.06 },   -- 0.01 × 6.0 = 0.06
            { stat = "wisdom", name = "悟性", value = 18 },         -- linearGrowth: floor(9 × 2.1) = 18
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 9 },  -- floor(9×2.1×0.5) = 9
        specialEffect = {
            type = "lifesteal_burst",
            name = "噬魂",
            healPercent = 0.03,
            maxStacks = 10,
            damagePercent = 1.0,
            rectLength = 2.0,
            rectWidth = 1.0,
            range = 2.5,
            maxTargets = 3,
            effectColor = {160, 80, 220, 255},
        },
    },

    shengqi_liedi = {
        name = "龙极·裂地",
        slot = "weapon",
        icon = "icon_huangsha_liedi.png",
        quality = "red",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 178.5 },
        subStats = {
            { stat = "heavyHit", name = "重击值", value = 88 },     -- 8 × 11.0 = 88
            { stat = "constitution", name = "根骨", value = 18 },   -- linearGrowth: floor(9 × 2.1) = 18
            { stat = "def", name = "防御力", value = 13.2 },        -- 1.2 × 11.0 = 13.2
        },
        spiritStat = { stat = "physique", name = "体魄", value = 9 },  -- floor(9×2.1×0.5) = 9
        specialEffect = {
            type = "heavy_strike",
            name = "裂地",
            hitInterval = 20,
            description = "每第20次攻击必定触发重击",
        },
    },

    shengqi_mieying = {
        name = "龙极·灭影",
        slot = "weapon",
        icon = "icon_huangsha_mieying.png",
        quality = "red",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 178.5 },
        subStats = {
            { stat = "critDmg", name = "暴击伤害", value = 0.30 },  -- 0.05 × 6.0 = 0.30
            { stat = "critDmg", name = "暴击伤害", value = 0.30 },  -- 0.05 × 6.0 = 0.30
            { stat = "atk", name = "攻击力", value = 16.5 },        -- 1.5 × 11.0 = 16.5
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 9 },  -- floor(9×2.1×0.5) = 9
        specialEffect = {
            type = "shadow_strike",
            name = "灭影",
            triggerOnCrit = true,
            triggerChance = 0.50,
            damagePercent = 0.60,
        },
    },

    -- ===================== 第四章·八卦海 特殊装备 =====================

    -- #1 沉渊冥冠（沈渊衣·坎阵BOSS）：T7 橙/稀世 头盔
    -- 主属性: 20 × 10.5(T7) × 1.5(橙) = 315
    -- 副属性: 橙色3条, 中值×1.1; 仙元属性: floor(7×1.5)=10
    chengyuan_helmet_ch4 = {
        name = "沉渊冥冠",
        slot = "helmet",
        icon = "icon_chengyuan_helmet.png",
        quality = "orange",
        tier = 7,
        sellPrice = 700,
        mainStat = { maxHp = 315 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 46.2 },       -- 6 × 7.0 × 1.1 = 46.2
            { stat = "hpRegen", name = "生命回复", value = 3.85 },   -- 0.5 × 7.0 × 1.1 = 3.85
            { stat = "physique", name = "体魄", value = 10 },        -- floor(7 × 1.5) = 10
        },
    },

    -- #2 止岩重靴（岩不动·艮阵BOSS）：T8 紫/极品 靴子
    -- 主属性: 0.03 × 6.0(T8pct) × 1.3(紫) = 0.234
    -- 副属性: 紫色3条, 中值×1.0; 仙元属性: floor(8×1.3)=10
    zhiyan_boots_ch4 = {
        name = "止岩重靴",
        slot = "boots",
        icon = "icon_zhiyan_boots.png",
        quality = "purple",
        tier = 8,
        sellPrice = 800,
        mainStat = { speed = 0.234 },
        subStats = {
            { stat = "def", name = "防御力", value = 10.8 },         -- 1.2 × 9.0 = 10.8
            { stat = "maxHp", name = "生命值", value = 54.0 },       -- 6 × 9.0 = 54.0
            { stat = "constitution", name = "根骨", value = 10 },    -- floor(8 × 1.3) = 10
        },
    },

    -- #3 雷鸣玉坠（雷惊蛰·震阵BOSS）：T8 橙/稀世 项链
    -- 主属性: 0.03 × 6.0(T8pct) × 1.5(橙) = 0.27
    -- 副属性: 橙色3条, 中值×1.1; 仙元属性: floor(8×1.5)=12
    leiming_necklace_ch4 = {
        name = "雷鸣玉坠",
        slot = "necklace",
        icon = "icon_leiming_necklace.png",
        quality = "orange",
        tier = 8,
        sellPrice = 800,
        mainStat = { critRate = 0.27 },
        subStats = {
            { stat = "critRate", name = "暴击率", value = 0.0528 },  -- 0.01 × 4.8 × 1.1 = 0.0528
            { stat = "atk", name = "攻击力", value = 14.85 },       -- 1.5 × 9.0 × 1.1 = 14.85
            { stat = "wisdom", name = "悟性", value = 12 },         -- floor(8 × 1.5) = 12
        },
    },

    -- #4 风痕指环（风无痕·巽阵BOSS）：T8 橙/稀世 戒指
    -- 主属性: 3 × 13.5(T8) × 1.5(橙) = 60.75
    -- 副属性: 橙色3条, 中值×1.1
    fenghen_ring_ch4 = {
        name = "风痕指环",
        slot = "ring1",
        icon = "icon_fenghen_ring.png",
        quality = "orange",
        tier = 8,
        sellPrice = 800,
        mainStat = { atk = 60.75 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 14.85 },       -- 1.5 × 9.0 × 1.1 = 14.85
            { stat = "critDmg", name = "暴击伤害", value = 0.264 }, -- 0.05 × 4.8 × 1.1 = 0.264
            { stat = "heavyHit", name = "重击值", value = 79.2 },     -- 8 × 9.0 × 1.1 = 79.2
        },
    },

    -- #5 焰心腰环（炎若晦·离阵BOSS）：T9 橙/稀世 腰带
    -- 主属性: 15 × 17.0(T9) × 1.5(橙) = 382.5 → 382
    -- 副属性: 橙色3条, 中值×1.1; 仙元属性: floor(9×1.5)=13
    yanxin_belt_ch4 = {
        name = "焰心腰环",
        slot = "belt",
        icon = "icon_yanxin_belt.png",
        quality = "orange",
        tier = 9,
        sellPrice = 900,
        mainStat = { maxHp = 382 },
        subStats = {
            { stat = "critDmg", name = "暴击伤害", value = 0.33 },  -- 0.05 × 6.0 × 1.1 = 0.33
            { stat = "fortune", name = "福缘", value = 13 },        -- floor(9 × 1.5) = 13
            { stat = "killHeal", name = "击杀回血", value = 38.0 }, -- 3 × 11.5 × 1.1 ≈ 37.95 → 38.0
        },
    },

    -- #6 厚土肩铠（厚德生·坤阵BOSS）：T9 橙/稀世 肩甲
    -- 主属性: 3 × 17.0(T9) × 1.5(橙) = 76.5
    -- 副属性: 橙色3条, 中值×1.1
    houtu_shoulder_ch4 = {
        name = "厚土肩铠",
        slot = "shoulder",
        icon = "icon_houtu_shoulder.png",
        quality = "orange",
        tier = 9,
        sellPrice = 900,
        mainStat = { def = 76.5 },
        subStats = {
            { stat = "hpRegen", name = "生命回复", value = 6.325 }, -- 0.5 × 11.5 × 1.1 = 6.325
            { stat = "critRate", name = "暴击率", value = 0.066 },  -- 0.01 × 6.0 × 1.1 = 0.066
            { stat = "heavyHit", name = "重击值", value = 101.2 },    -- 8 × 11.5 × 1.1 ≈ 101.2
        },
    },

    -- #7 泽渊仙铠（泽归墟·兑阵BOSS）：T9 青/灵器 衣服
    -- 主属性: 4 × 17.0(T9) × 1.8(灵器) = 122.4
    -- 副属性: 灵器3条, 中值×1.0; 仙元属性: floor(9×1.8)=16
    -- 特效: 泽渊生息 — 每秒恢复2%最大生命值（血满不再恢复）
    zeyuan_armor_ch4 = {
        name = "泽渊仙铠",
        slot = "armor",
        icon = "icon_zeyuan_armor.png",
        quality = "cyan",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { def = 122.4 },
        subStats = {
            { stat = "physique", name = "体魄", value = 16 },       -- floor(9 × 1.8) = 16
            { stat = "constitution", name = "根骨", value = 16 },   -- floor(9 × 1.8) = 16
            { stat = "critDmg", name = "暴击伤害", value = 0.30 },  -- 0.05 × 6.0 = 0.30
        },
        specialEffect = {
            type = "hp_regen_percent",
            name = "泽渊生息",
            regenPercent = 0.02,      -- 每秒恢复2%最大生命值
            stopWhenFull = true,      -- 血满不再恢复
        },
    },

    -- #8 天罡圣披（司空正阳·乾阵BOSS）：T9 青/灵器 披风
    -- 主属性: 0.02 × 7.0(T9pct) × 1.8(灵器) = 0.252
    -- 副属性: 灵器3条, 中值×1.0
    -- 灵性属性: 福缘+8（floor(9×1.8×0.5)=8）
    tiangang_cape_ch4 = {
        name = "天罡圣披",
        slot = "cape",
        icon = "icon_tiangang_cape.png",
        quality = "cyan",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { dmgReduce = 0.252 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 17.25 },       -- 1.5 × 11.5 = 17.25
            { stat = "critRate", name = "暴击率", value = 0.06 },   -- 0.01 × 6.0 = 0.06
            { stat = "def", name = "防御力", value = 13.8 },        -- 1.2 × 11.5 = 13.8
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 8 }, -- floor(9×1.8×0.5) = 8
    },

    -- #帝尊肆戒（四龙BOSS 0.25%独立掉落）：T9 青/灵器 戒指
    -- 主属性: 3 × 17.0(T9) × 1.8(灵器) = 91.8
    -- 副属性: 灵器3条, linearGrowth: floor(9×1.8)=16; 灵性属性: floor(9×1.8×0.5)=8
    silong_ring_ch4 = {
        name = "帝尊肆戒",
        desc = "帝尊威震四海时所铸之戒，龙威淬骨，气运加身。",
        slot = "ring1",
        icon = "icon_dizun_ring_ch4.png",
        quality = "cyan",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 91.8 },
        subStats = {
            { stat = "constitution", name = "根骨", value = 16 },   -- floor(9 × 1.8) = 16
            { stat = "wisdom", name = "悟性", value = 16 },         -- floor(9 × 1.8) = 16
            { stat = "physique", name = "体魄", value = 16 },       -- floor(9 × 1.8) = 16
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 8 }, -- floor(9×1.8×0.5) = 8
    },

    -- ===================== 挑战专属装备（使者挑战奖励） =====================

    -- 血海图 Lv.1（血煞盟 T1 首通奖励）：T3 紫色专属
    -- 主属性: 5 × 3.0(T3) × 1.3(紫) = 19.5 → 19
    -- 副属性: 紫色3条, 中值×1.0
    blood_sea_lv1 = {
        name = "血海图·初",
        slot = "exclusive",
        icon = "icon_blood_sea_lv1.png",
        quality = "purple",
        tier = 3,
        sellPrice = 300,
        mainStat = { wisdom = 19 },   -- 5 × 3.0(T3) × 1.3(紫) = 19.5 → 19
        subStats = {
            { stat = "def", name = "防御力", value = 2.4 },          -- 1.2 × 2.0(SUB_T3) = 2.4
            { stat = "killHeal", name = "击杀回血", value = 6 },     -- 3 × 2.0(SUB_T3) = 6
            { stat = "critDmg", name = "暴击伤害", value = 0.08 },   -- 0.05 × 1.6(PCT_SUB_T3) = 0.08
        },
        skillId = "blood_sea_aoe",
    },

    -- 血海图 Lv.2（血煞盟 T3 首通奖励）：T5 紫色专属
    -- 主属性: 5 × 6.0(T5) × 1.3(紫) = 39
    -- 副属性: 紫色3条, 中值×1.0
    blood_sea_lv2 = {
        name = "血海图·破",
        slot = "exclusive",
        icon = "icon_blood_sea_lv2.png",
        quality = "purple",
        tier = 5,
        sellPrice = 500,
        mainStat = { wisdom = 39 },   -- 5 × 6.0(T5) × 1.3(紫) = 39
        subStats = {
            { stat = "def", name = "防御力", value = 4.8 },          -- 1.2 × 4.0(SUB_T5) = 4.8
            { stat = "killHeal", name = "击杀回血", value = 12 },    -- 3 × 4.0(SUB_T5) = 12
            { stat = "critDmg", name = "暴击伤害", value = 0.125 },  -- 0.05 × 2.5(PCT_SUB_T5) = 0.125
        },
        skillId = "blood_sea_aoe",
    },

    -- 浩气印 Lv.1（浩气宗 T1 首通奖励）：T3 紫色专属
    -- 主属性: 5 × 3.0(T3) × 1.3(紫) = 19.5 → 19
    -- 副属性: 紫色3条, 中值×1.0
    haoqi_seal_lv1 = {
        name = "浩气印·初",
        slot = "exclusive",
        icon = "icon_haoqi_seal_lv1.png",
        quality = "purple",
        tier = 3,
        sellPrice = 300,
        mainStat = { wisdom = 19 },   -- 5 × 3.0(T3) × 1.3(紫) = 19.5 → 19
        subStats = {
            { stat = "def", name = "防御力", value = 2.4 },          -- 1.2 × 2.0(SUB_T3) = 2.4
            { stat = "hpRegen", name = "生命回复", value = 1.0 },    -- 0.5 × 2.0(SUB_T3) = 1.0
            { stat = "critRate", name = "暴击率", value = 0.016 },   -- 0.01 × 1.6(PCT_SUB_T3) = 0.016
        },
        skillId = "haoqi_seal_zone",
    },

    -- 浩气印 Lv.2（浩气宗 T3 首通奖励）：T5 紫色专属
    -- 主属性: 5 × 6.0(T5) × 1.3(紫) = 39
    -- 副属性: 紫色3条, 中值×1.0
    haoqi_seal_lv2 = {
        name = "浩气印·破",
        slot = "exclusive",
        icon = "icon_haoqi_seal_lv2.png",
        quality = "purple",
        tier = 5,
        sellPrice = 500,
        mainStat = { wisdom = 39 },   -- 5 × 6.0(T5) × 1.3(紫) = 39
        subStats = {
            { stat = "def", name = "防御力", value = 4.8 },          -- 1.2 × 4.0(SUB_T5) = 4.8
            { stat = "hpRegen", name = "生命回复", value = 2.0 },    -- 0.5 × 4.0(SUB_T5) = 2.0
            { stat = "critRate", name = "暴击率", value = 0.025 },   -- 0.01 × 2.5(PCT_SUB_T5) = 0.025
        },
        skillId = "haoqi_seal_zone",
    },

    -- 血海图 Lv.3（血煞盟 第三章首通奖励）：T7 橙色专属
    -- 主属性: 5 × 10.5(T7) × 1.5(橙) = 78.75 → 78
    -- 副属性: 橙色3条, 中值×1.1
    blood_sea_lv3 = {
        name = "血海图·绝",
        slot = "exclusive",
        icon = "icon_blood_sea_lv3.png",
        quality = "orange",
        tier = 7,
        sellPrice = 1000,
        mainStat = { wisdom = 78 },   -- 5 × 10.5(T7) × 1.5(橙) = 78.75 → 78
        subStats = {
            { stat = "def", name = "防御力", value = 9.24 },          -- 1.2 × 7.0(SUB_T7) × 1.1(橙) = 9.24
            { stat = "killHeal", name = "击杀回血", value = 23.1 },   -- 3 × 7.0(SUB_T7) × 1.1(橙) = 23.1
            { stat = "critDmg", name = "暴击伤害", value = 0.209 },   -- 0.05 × 3.8(PCT_SUB_T7) × 1.1(橙) = 0.209
        },
        skillId = "blood_sea_aoe",
    },

    -- 浩气印 Lv.3（浩气宗 第三章首通奖励）：T7 橙色专属
    -- 主属性: 5 × 10.5(T7) × 1.5(橙) = 78.75 → 78
    -- 副属性: 橙色3条, 中值×1.1
    haoqi_seal_lv3 = {
        name = "浩气印·绝",
        slot = "exclusive",
        icon = "icon_haoqi_seal_lv3.png",
        quality = "orange",
        tier = 7,
        sellPrice = 1000,
        mainStat = { wisdom = 78 },   -- 5 × 10.5(T7) × 1.5(橙) = 78.75 → 78
        subStats = {
            { stat = "def", name = "防御力", value = 9.24 },          -- 1.2 × 7.0(SUB_T7) × 1.1(橙) = 9.24
            { stat = "hpRegen", name = "生命回复", value = 3.85 },    -- 0.5 × 7.0(SUB_T7) × 1.1(橙) = 3.85
            { stat = "critRate", name = "暴击率", value = 0.0418 },   -- 0.01 × 3.8(PCT_SUB_T7) × 1.1(橙) = 0.0418
        },
        skillId = "haoqi_seal_zone",
    },

    -- 乌万海掉落：T5灵器鞋子（踏云靴·闪避10%伤害）
    -- 主属性: 0.03 × 3.0(PCT_T5) × 1.8(灵器) = 0.162
    -- 副属性: 灵器3条, 中值×1.0
    wu_boots_ch2 = {
        name = "踏云靴",
        slot = "boots",
        icon = "icon_wu_boots_ch2.png",
        quality = "cyan",
        tier = 5,
        sellPrice = 1,
        sellCurrency = "lingYun",
        mainStat = { speed = 0.162 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 6.0 },      -- 1.5 × 4.0(SUB_T5) = 6.0
            { stat = "critRate", name = "暴击率", value = 0.025 }, -- 0.01 × 2.5(PCT_SUB_T5) = 0.025
            { stat = "maxHp", name = "生命值", value = 24.0 },   -- 6 × 4.0(SUB_T5) = 24.0
        },
        specialEffect = {
            type = "evade_damage",
            name = "踏云",
            evadeChance = 0.10,  -- 10%概率完全闪避伤害
        },
    },

    -- 乌大傻掉落：T5紫色铠甲
    -- 主属性: 4 × 6.0(T5) × 1.3(紫) = 31.2
    -- 副属性: 紫色3条, 中值×1.0
    wu_armor_ch2 = {
        name = "乌煞重铠",
        slot = "armor",
        icon = "icon_wu_armor_ch2.png",
        quality = "purple",
        tier = 5,
        sellPrice = 500,
        mainStat = { def = 31.2 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 24.0 },      -- 6 × 4.0(SUB_T5) = 24.0
            { stat = "hpRegen", name = "生命回复", value = 2.0 },   -- 0.5 × 4.0(SUB_T5) = 2.0
            { stat = "def", name = "防御力", value = 4.8 },          -- 1.2 × 4.0(SUB_T5) = 4.8
        },
    },

    -- 乌二傻掉落：T5紫色项链
    -- 主属性: 0.03 × 3.0(PCT_T5) × 1.3(紫) = 0.117
    -- 副属性: 紫色3条, 中值×1.0
    wu_necklace_ch2 = {
        name = "乌骨牙链",
        slot = "necklace",
        icon = "icon_wu_necklace_ch2.png",
        quality = "purple",
        tier = 5,
        sellPrice = 500,
        mainStat = { critRate = 0.117 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 6.0 },          -- 1.5 × 4.0(SUB_T5) = 6.0
            { stat = "critRate", name = "暴击率", value = 0.025 },   -- 0.01 × 2.5(PCT_SUB_T5) = 0.025
            { stat = "def", name = "防御力", value = 4.8 },          -- 1.2 × 4.0(SUB_T5) = 4.8
        },
    },

    -- 乌大傻/乌二傻3%掉落：T5橙色武器
    -- 主属性: 5 × 6.0(T5) × 1.5(橙) = 45
    -- 副属性: 橙色3条, 中值×1.1
    wu_hammer_ch2 = {
        name = "傻大锤",
        slot = "weapon",
        icon = "icon_wu_hammer_ch2.png",
        quality = "orange",
        tier = 5,
        sellPrice = 500,
        mainStat = { atk = 45 },
        subStats = {
            { stat = "hpRegen", name = "生命回复", value = 2.2 },   -- 0.5 × 4.0(SUB_T5) × 1.1(橙) = 2.2
            { stat = "killHeal", name = "击杀回血", value = 13.2 }, -- 3 × 4.0(SUB_T5) × 1.1(橙) = 13.2
            { stat = "fortune", name = "福缘", value = 7 },         -- linearGrowth: floor(5 × 1.5) = 7
        },
    },

    -- #帝尊贰戒（万仇/万海3%独立掉落）：T5 橙/稀世 戒指
    -- 主属性: 3 × 6.0(T5) × 1.5(橙) = 27
    -- 副属性: 橙色3条, linearGrowth: floor(5 × 1.5) = 7
    dizun_ring_ch2 = {
        name = "帝尊贰戒",
        desc = "帝尊崭露锋芒时所铸之戒，历经乌堡血战，心志愈坚。",
        slot = "ring1",
        icon = "icon_dizun_ring_ch2.png",
        quality = "orange",
        tier = 5,
        sellPrice = 500,
        mainStat = { atk = 27 },
        subStats = {
            { stat = "wisdom", name = "悟性", value = 7 },           -- floor(5 × 1.5) = 7
            { stat = "constitution", name = "根骨", value = 7 },     -- floor(5 × 1.5) = 7
            { stat = "physique", name = "体魄", value = 7 },         -- floor(5 × 1.5) = 7
        },
    },

    -- ===================== 法宝图鉴虚拟条目（仅供图鉴系统显示和匹配） =====================
    -- 血海图 Lv.3/5/7（T5/T7/T9）
    fabao_xuehaitu_t5 = {
        name = "血海图Lv.3", slot = "exclusive", quality = "purple", tier = 5,
        isFabaoCollection = true, fabaoTemplateId = "fabao_xuehaitu", fabaoTier = 5,
    },
    fabao_xuehaitu_t7 = {
        name = "血海图Lv.5", slot = "exclusive", quality = "orange", tier = 7,
        isFabaoCollection = true, fabaoTemplateId = "fabao_xuehaitu", fabaoTier = 7,
    },
    fabao_xuehaitu_t9 = {
        name = "血海图Lv.7", slot = "exclusive", quality = "cyan", tier = 9,
        isFabaoCollection = true, fabaoTemplateId = "fabao_xuehaitu", fabaoTier = 9,
    },
    -- 浩气印 Lv.3/5/7（T5/T7/T9）
    fabao_haoqiyin_t5 = {
        name = "浩气印Lv.3", slot = "exclusive", quality = "purple", tier = 5,
        isFabaoCollection = true, fabaoTemplateId = "fabao_haoqiyin", fabaoTier = 5,
    },
    fabao_haoqiyin_t7 = {
        name = "浩气印Lv.5", slot = "exclusive", quality = "orange", tier = 7,
        isFabaoCollection = true, fabaoTemplateId = "fabao_haoqiyin", fabaoTier = 7,
    },
    fabao_haoqiyin_t9 = {
        name = "浩气印Lv.7", slot = "exclusive", quality = "cyan", tier = 9,
        isFabaoCollection = true, fabaoTemplateId = "fabao_haoqiyin", fabaoTier = 9,
    },
    -- 青云塔 Lv.3/5/7（T5/T7/T9）
    fabao_qingyunta_t5 = {
        name = "青云塔Lv.3", slot = "exclusive", quality = "purple", tier = 5,
        isFabaoCollection = true, fabaoTemplateId = "fabao_qingyunta", fabaoTier = 5,
    },
    fabao_qingyunta_t7 = {
        name = "青云塔Lv.5", slot = "exclusive", quality = "orange", tier = 7,
        isFabaoCollection = true, fabaoTemplateId = "fabao_qingyunta", fabaoTier = 7,
    },
    fabao_qingyunta_t9 = {
        name = "青云塔Lv.7", slot = "exclusive", quality = "cyan", tier = 9,
        isFabaoCollection = true, fabaoTemplateId = "fabao_qingyunta", fabaoTier = 9,
    },
    -- 封魔盘 Lv.3/5/7（T5/T7/T9）
    fabao_fengmopan_t5 = {
        name = "封魔盘Lv.3", slot = "exclusive", quality = "purple", tier = 5,
        isFabaoCollection = true, fabaoTemplateId = "fabao_fengmopan", fabaoTier = 5,
    },
    fabao_fengmopan_t7 = {
        name = "封魔盘Lv.5", slot = "exclusive", quality = "orange", tier = 7,
        isFabaoCollection = true, fabaoTemplateId = "fabao_fengmopan", fabaoTier = 7,
    },
    fabao_fengmopan_t9 = {
        name = "封魔盘Lv.7", slot = "exclusive", quality = "cyan", tier = 9,
        isFabaoCollection = true, fabaoTemplateId = "fabao_fengmopan", fabaoTier = 9,
    },
    -- 龙极令（攻击型法宝，第四章铸造）
    fabao_longjiling_t9 = {
        name = "龙极令", slot = "exclusive", quality = "cyan", tier = 9,
        isFabaoCollection = true, fabaoTemplateId = "fabao_longjiling", fabaoTier = 9,
    },

    -- ===================== 第五章·太虚遗藏（章节专属装备） =====================

    -- #1 镇派石履（护山石傀·入口Boss）：T9 橙色 鞋子
    -- 主属性: 0.03 × 7.0(T9pct) × 1.5(橙) = 0.315
    -- 副属性: 橙色3条, 中值×1.1
    zhenpai_boots_ch5 = {
        name = "镇派石履",
        slot = "boots",
        icon = "icon_zhenpai_boots_ch5.png",
        quality = "orange",
        tier = 9,
        sellPrice = 1500,
        mainStat = { speed = 0.315 },
        subStats = {
            { stat = "def", name = "防御力", value = 14.52 },        -- 1.2 × 11.0 × 1.1 = 14.52
            { stat = "maxHp", name = "生命值", value = 72.6 },       -- 6 × 11.0 × 1.1 = 72.6
            { stat = "constitution", name = "根骨", value = 13 },    -- floor(9 × 1.5) = 13
        },
    },

    -- #2 问锋雷纹坠（问剑长老·裴千岳）：T9 青/灵器 项链
    -- 主属性: 0.03 × 7.0(T9pct) × 1.8(灵器) = 0.378
    -- 副属性: 灵器3条, 中值×1.0
    wenfeng_necklace_ch5 = {
        name = "问锋雷纹坠",
        slot = "necklace",
        icon = "icon_wenfeng_necklace_ch5.png",
        quality = "cyan",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { critRate = 0.378 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 16.5 },        -- 1.5 × 11.0 = 16.5
            { stat = "wisdom", name = "悟性", value = 16 },          -- floor(9 × 1.8) = 16
            { stat = "killHeal", name = "击杀回血", value = 33 },    -- 3 × 11.0 = 33
        },
        spiritStat = { stat = "wisdom", name = "悟性", value = 8 }, -- floor(9×1.8×0.5) = 8
    },

    -- #3 寒池霜华戒（洗剑霜鸾）：T9 青/灵器 戒指
    -- 主属性: 3 × 17.0(T9) × 1.8(灵器) = 91.8
    -- 副属性: 灵器3条, 中值×1.0
    hanchi_ring_ch5 = {
        name = "寒池霜华戒",
        slot = "ring1",
        icon = "icon_hanchi_ring_ch5.png",
        quality = "cyan",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 91.8 },
        subStats = {
            { stat = "critRate", name = "暴击率", value = 0.06 },    -- 0.01 × 6.0 = 0.06
            { stat = "physique", name = "体魄", value = 16 },        -- floor(9 × 1.8) = 16
            { stat = "hpRegen", name = "生命回复", value = 5.5 },    -- 0.5 × 11.0 = 5.5
        },
        spiritStat = { stat = "physique", name = "体魄", value = 8 }, -- floor(9×1.8×0.5) = 8
    },

    -- #4 百炼火绶（铸剑长老·韩百炼）：T10 橙色 腰带
    -- 主属性: 6 × 21.0(T10) × 1.5(橙) × 2.5(腰带主属性倍率) = 472.5
    -- 副属性: 橙色3条, 中值×1.1
    bailian_belt_ch5 = {
        name = "百炼火绶",
        slot = "belt",
        icon = "icon_bailian_belt_ch5.png",
        quality = "orange",
        tier = 10,
        sellPrice = 2000,
        mainStat = { maxHp = 472.5 },
        subStats = {
            { stat = "hpRegen", name = "生命回复", value = 7.15 },   -- 0.5 × 13.0 × 1.1 = 7.15
            { stat = "maxHp", name = "生命值", value = 85.8 },       -- 6 × 13.0 × 1.1 = 85.8
            { stat = "physique", name = "体魄", value = 15 },        -- floor(10 × 1.5) = 15
        },
    },

    -- #5 观澜碑佩（守碑长老·石观澜）：T10 橙色 项链
    -- 主属性: 0.03 × 8.0(T10pct) × 1.5(橙) = 0.36
    -- 副属性: 橙色3条, 中值×1.1
    guanlan_necklace_ch5 = {
        name = "观澜碑佩",
        slot = "necklace",
        icon = "icon_guanlan_necklace_ch5.png",
        quality = "orange",
        tier = 10,
        sellPrice = 2000,
        mainStat = { critRate = 0.36 },
        subStats = {
            { stat = "critDmg", name = "暴击伤害", value = 0.4125 }, -- 0.05 × 7.5(PCT_SUB_T10) × 1.1 = 0.4125
            { stat = "atk", name = "攻击力", value = 21.45 },        -- 1.5 × 13.0 × 1.1 = 21.45
            { stat = "wisdom", name = "悟性", value = 15 },          -- floor(10 × 1.5) = 15
        },
    },

    -- #6 宿心残戒（别院院主·宁栖梧，共享1%二选一）：T10 橙色 戒指
    -- 主属性: 3 × 21.0(T10) × 1.5(橙) = 94.5
    -- 副属性: 橙色3条, 中值×1.1
    suxin_ring_ch5 = {
        name = "宿心残戒",
        slot = "ring1",
        icon = "icon_suxin_ring_ch5.png",
        quality = "orange",
        tier = 10,
        sellPrice = 2000,
        mainStat = { atk = 94.5 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 21.45 },        -- 1.5 × 13.0 × 1.1 = 21.45
            { stat = "critDmg", name = "暴击伤害", value = 0.4125 }, -- 0.05 × 7.5 × 1.1 = 0.4125
            { stat = "heavyHit", name = "重击伤害", value = 114.4 }, -- 8 × 13.0 × 1.1 = 114.4
        },
    },

    -- #7 藏真玄衣（藏经阁主·温素章，共享1%二选一）：T10 青/灵器 衣服
    -- 主属性: 1.2 × 21.0(T10) × 1.8(灵器) × 4(衣服主属性倍率) = 181.44 → 设计值151.2（按标准公式）
    -- 副属性: 灵器3条, 中值×1.0
    cangzhen_armor_ch5 = {
        name = "藏真玄衣",
        slot = "armor",
        icon = "icon_cangzhen_armor_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { def = 151.2 },
        subStats = {
            { stat = "physique", name = "体魄", value = 18 },        -- floor(10 × 1.8) = 18
            { stat = "constitution", name = "根骨", value = 18 },    -- floor(10 × 1.8) = 18
            { stat = "critDmg", name = "暴击伤害", value = 0.375 },  -- 0.05 × 7.5 = 0.375
        },
        specialEffect = {
            type = "hp_regen_percent",
            name = "泽渊生息",
            regenPercent = 0.02,      -- 每秒恢复2%最大生命值
            stopWhenFull = true,      -- 血满不再恢复
        },
    },

    -- #8 噬渊魔氅（镇渊魔帅·噬渊血犼）：T10 青/灵器 披风
    -- 主属性: 0.02 × 8.0(T10pct) × 1.8(灵器) = 0.288
    -- 副属性: 灵器3条, 中值×1.0
    shiyuan_cape_ch5 = {
        name = "噬渊魔氅",
        slot = "cape",
        icon = "icon_shiyuan_cape_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { dmgReduce = 0.288 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 19.5 },         -- 1.5 × 13.0 = 19.5
            { stat = "critRate", name = "暴击率", value = 0.075 },   -- 0.01 × 7.5 = 0.075
            { stat = "def", name = "防御力", value = 15.6 },         -- 1.2 × 13.0 = 15.6
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 9 }, -- floor(10×1.8×0.5) = 9
    },

    -- #9 藏真玄冠（藏经阁主·温素章，共享1%二选一）：T10 青/灵器 头盔 [套装：护脉遗装]
    -- 主属性: 6 × 21.0(T10) × 1.8(灵器) × 不适用头盔特殊倍率 → 设计值756
    -- 副属性: 灵器3条, 中值×1.0
    cangzhen_helmet_ch5 = {
        name = "藏真玄冠",
        slot = "helmet",
        icon = "icon_cangzhen_helmet_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        setId = "humai_yizhuang",
        mainStat = { maxHp = 756 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 19.5 },        -- 1.5 × 13.0 = 19.5
            { stat = "wisdom", name = "悟性", value = 18 },          -- floor(10 × 1.8) = 18
            { stat = "killHeal", name = "击杀回血", value = 39 },    -- 3 × 13.0 = 39
        },
        spiritStat = { stat = "atk", name = "攻击力", value = 9.75 }, -- 1.5×13.0×0.5 = 9.75
    },

    -- #10 屠血命绶（裂渊屠血将，共享0.5%二选一）：T10 青/灵器 腰带 [套装：护脉遗装]
    -- 主属性: 6 × 21.0(T10) × 1.8(灵器) × 2.5(腰带倍率) → 设计值567
    -- 副属性: 灵器3条, 中值×1.0
    tuxue_belt_ch5 = {
        name = "屠血命绶",
        slot = "belt",
        icon = "icon_tuxue_belt_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        setId = "humai_yizhuang",
        mainStat = { maxHp = 567 },
        subStats = {
            { stat = "def", name = "防御力", value = 15.6 },         -- 1.2 × 13.0 = 15.6
            { stat = "killHeal", name = "击杀回血", value = 39 },    -- 3 × 13.0 = 39
            { stat = "constitution", name = "根骨", value = 18 },    -- floor(10 × 1.8) = 18
        },
        spiritStat = { stat = "critRate", name = "暴击率", value = 0.0375 }, -- 0.01×7.5×0.5 = 0.0375
    },

    -- #11 栖剑行靴（别院院主·宁栖梧，共享1%二选一）：T10 青/灵器 鞋子 [套装：镇宗玄卫]
    -- 主属性: 0.03 × 8.0(T10pct) × 1.8(灵器) = 0.432
    -- 副属性: 灵器3条, 中值×1.0
    qijian_boots_ch5 = {
        name = "栖剑行靴",
        slot = "boots",
        icon = "icon_qijian_boots_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        setId = "zhenzong_xuanwei",
        mainStat = { speed = 0.432 },
        subStats = {
            { stat = "def", name = "防御力", value = 15.6 },         -- 1.2 × 13.0 = 15.6
            { stat = "maxHp", name = "生命值", value = 78 },         -- 6 × 13.0 = 78
            { stat = "fortune", name = "福缘", value = 18 },         -- floor(10 × 1.8) = 18
        },
        spiritStat = { stat = "critDmg", name = "暴击伤害", value = 0.1875 }, -- 0.05×7.5×0.5 = 0.1875
    },

    -- #12 屠血魔肩（裂渊屠血将，共享0.5%二选一）：T10 青/灵器 肩膀 [套装：镇宗玄卫]
    -- 主属性: 1.2 × 21.0(T10) × 1.8(灵器) × 2.5(肩膀倍率) → 设计值113.4
    -- 副属性: 灵器3条, 中值×1.0
    tuxue_shoulder_ch5 = {
        name = "屠血魔肩",
        slot = "shoulder",
        icon = "icon_tuxue_shoulder_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        setId = "zhenzong_xuanwei",
        mainStat = { def = 113.4 },
        subStats = {
            { stat = "maxHp", name = "生命值", value = 78 },         -- 6 × 13.0 = 78
            { stat = "hpRegen", name = "生命回复", value = 6.5 },    -- 0.5 × 13.0 = 6.5
            { stat = "physique", name = "体魄", value = 18 },        -- floor(10 × 1.8) = 18
        },
        spiritStat = { stat = "critRate", name = "暴击率", value = 0.0375 }, -- 0.01×7.5×0.5 = 0.0375
    },

    -- #帝尊伍戒（噬渊血犼+四仙剑 各0.5%独立掉落）：T10 青/灵器 戒指
    -- 主属性: 3 × 21.0(T10) × 1.8(灵器) = 113.4
    -- 副属性: 灵器3条, linearGrowth: floor(10×1.8)=18; 灵性属性: floor(10×1.8×0.5)=9
    dizun_ring_ch5 = {
        name = "帝尊伍戒",
        desc = "帝尊终成大道时所铸之戒，五行归元，万法归宗。",
        slot = "ring1",
        icon = "icon_dizun_ring_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 113.4 },
        subStats = {
            { stat = "constitution", name = "根骨", value = 18 },    -- floor(10 × 1.8) = 18
            { stat = "wisdom", name = "悟性", value = 18 },          -- floor(10 × 1.8) = 18
            { stat = "physique", name = "体魄", value = 18 },        -- floor(10 × 1.8) = 18
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 9 }, -- floor(10×1.8×0.5) = 9
    },

    -- ===================== 第五章·封印古剑（四仙剑各0.5%独立掉落） =====================

    -- 封印古剑·诛仙（诛仙剑Boss掉落）：T10 青/灵器 武器
    fengyin_zhuxian_ch5 = {
        name = "封印古剑·诛仙",
        desc = "诛仙剑灵封印后残余的剑身，虽失锋芒，仍余诛杀之意。",
        slot = "weapon",
        icon = "icon_fengyin_zhuxian_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 189 },  -- 5 × 21.0 × 1.8 = 189（weapon BASE=5）
        subStats = {
            { stat = "critRate", name = "暴击率", value = 0.075 },   -- 0.01 × 7.5 = 0.075
            { stat = "critDmg", name = "暴击伤害", value = 0.375 },  -- 0.05 × 7.5 = 0.375
            { stat = "wisdom", name = "悟性", value = 18 },          -- floor(10 × 1.8) = 18
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 9 }, -- floor(10×1.8×0.5) = 9
    },

    -- 封印古剑·陷仙（陷仙剑Boss掉落）：T10 青/灵器 武器
    fengyin_xianxian_ch5 = {
        name = "封印古剑·陷仙",
        desc = "陷仙剑灵封印后残余的剑身，困敌之力犹存，触之即陷。",
        slot = "weapon",
        icon = "icon_fengyin_xianxian_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 189 },  -- 5 × 21.0 × 1.8 = 189（weapon BASE=5）
        subStats = {
            { stat = "def", name = "防御力", value = 15.6 },         -- 1.2 × 13.0 = 15.6
            { stat = "maxHp", name = "生命值", value = 78 },         -- 6 × 13.0 = 78
            { stat = "constitution", name = "根骨", value = 18 },    -- floor(10 × 1.8) = 18
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 9 }, -- floor(10×1.8×0.5) = 9
    },

    -- 封印古剑·戮仙（戮仙剑Boss掉落）：T10 青/灵器 武器
    fengyin_luxian_ch5 = {
        name = "封印古剑·戮仙",
        desc = "戮仙剑灵封印后残余的剑身，嗜杀本能未泯，血气缠绕。",
        slot = "weapon",
        icon = "icon_fengyin_luxian_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 189 },  -- 5 × 21.0 × 1.8 = 189（weapon BASE=5）
        subStats = {
            { stat = "atk", name = "攻击力", value = 19.5 },        -- 1.5 × 13.0 = 19.5
            { stat = "heavyHit", name = "重击伤害", value = 104 },   -- 8 × 13.0 = 104
            { stat = "physique", name = "体魄", value = 18 },        -- floor(10 × 1.8) = 18
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 9 }, -- floor(10×1.8×0.5) = 9
    },

    -- 封印古剑·绝仙（绝仙剑Boss掉落）：T10 青/灵器 武器
    fengyin_juexian_ch5 = {
        name = "封印古剑·绝仙",
        desc = "绝仙剑灵封印后残余的剑身，绝灭之力沉睡其中，不可轻触。",
        slot = "weapon",
        icon = "icon_fengyin_juexian_ch5.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 189 },  -- 5 × 21.0 × 1.8 = 189（weapon BASE=5）
        subStats = {
            { stat = "killHeal", name = "击杀回血", value = 39 },    -- 3 × 13.0 = 39
            { stat = "hpRegen", name = "生命回复", value = 6.5 },    -- 0.5 × 13.0 = 6.5
            { stat = "fortune", name = "福缘", value = 18 },         -- floor(10 × 1.8) = 18
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 9 }, -- floor(10×1.8×0.5) = 9
    },
}

-- ===================== 神兵图录（独特装备图鉴系统） =====================

-- 图录条目：收录所有独特装备，上交可获得属性加成
-- key = SpecialEquipment 的 key, bonus = 收录后获得的永久属性加成
EquipmentData.Collection = {
    -- 按章节分组的展示顺序
    chapters = {
        {
            name = "第一章",
            order = {
                "jade_gourd",
                "boar_patrol_helmet",
                "boar_king_weapon",
                "boss_cape",
                "bandit_second_belt",
                "spider_queen_ring",
                "tiger_set_weapon",
                "tiger_set_armor",
                "tiger_set_necklace",
                "tiger_set_cape",
                "dizun_ring_ch1",
            },
        },
        {
            name = "第二章",
            order = {
                "gold_helmet_ch2",
                "boar_belt_ch2",
                "snake_cape_ch2",
                "wu_shoulder_ch2",
                "wu_weapon_ch2",
                "wu_ring_chou",
                "wu_ring_hai",
                "wu_boots_ch2",
                "wu_armor_ch2",
                "wu_necklace_ch2",
                "wu_hammer_ch2",
                "dizun_ring_ch2",
                "fabao_xuehaitu_t5",
                "fabao_haoqiyin_t5",
                "fabao_qingyunta_t5",
                "fabao_fengmopan_t5",
            },
        },
        {
            name = "第三章",
            order = {
                "kumu_helmet_ch3",
                "yanchan_armor_ch3",
                "canglang_necklace_ch3",
                "chijia_ring_ch3",
                "shegu_belt_ch3",
                "lieyan_cape_ch3",
                "shen_shoulder_ch3",
                "huangsha_duanliu",
                "huangsha_fentian",
                "huangsha_shihun",
                "huangsha_liedi",
                "huangsha_mieying",
                "dizun_ring_ch3",
                "fabao_xuehaitu_t7",
                "fabao_haoqiyin_t7",
                "fabao_qingyunta_t7",
                "fabao_fengmopan_t7",
            },
        },
        {
            name = "第四章",
            order = {
                "chengyuan_helmet_ch4",
                "zhiyan_boots_ch4",
                "leiming_necklace_ch4",
                "fenghen_ring_ch4",
                "yanxin_belt_ch4",
                "houtu_shoulder_ch4",
                "zeyuan_armor_ch4",
                "tiangang_cape_ch4",
                "shengqi_duanliu",
                "shengqi_fentian",
                "shengqi_shihun",
                "shengqi_liedi",
                "shengqi_mieying",
                "silong_ring_ch4",
                "fabao_xuehaitu_t9",
                "fabao_haoqiyin_t9",
                "fabao_qingyunta_t9",
                "fabao_fengmopan_t9",
                "fabao_longjiling_t9",
            },
        },
        {
            name = "第五章",
            order = {
                "zhenpai_boots_ch5",
                "wenfeng_necklace_ch5",
                "hanchi_ring_ch5",
                "bailian_belt_ch5",
                "guanlan_necklace_ch5",
                "suxin_ring_ch5",
                "cangzhen_armor_ch5",
                "shiyuan_cape_ch5",
                "cangzhen_helmet_ch5",
                "tuxue_belt_ch5",
                "qijian_boots_ch5",
                "tuxue_shoulder_ch5",
                "dizun_ring_ch5",
                "fengyin_zhuxian_ch5",
                "fengyin_xianxian_ch5",
                "fengyin_luxian_ch5",
                "fengyin_juexian_ch5",
            },
        },
    },
    -- 完整顺序（兼容旧接口）
    order = {
        "jade_gourd",
        "boar_king_weapon",
        "boss_cape",
        "spider_queen_ring",
        "boar_patrol_helmet",
        "tiger_set_weapon",
        "tiger_set_armor",
        "tiger_set_necklace",
        "tiger_set_cape",
        "bandit_second_belt",
        "dizun_ring_ch1",
        "gold_helmet_ch2",
        "boar_belt_ch2",
        "snake_cape_ch2",
        "wu_shoulder_ch2",
        "wu_weapon_ch2",
        "wu_ring_chou",
        "wu_ring_hai",
        "wu_boots_ch2",
        "wu_armor_ch2",
        "wu_necklace_ch2",
        "wu_hammer_ch2",
        "dizun_ring_ch2",
        "fabao_xuehaitu_t5",
        "fabao_haoqiyin_t5",
        "fabao_qingyunta_t5",
        "fabao_fengmopan_t5",
        "kumu_helmet_ch3",
        "yanchan_armor_ch3",
        "canglang_necklace_ch3",
        "chijia_ring_ch3",
        "shegu_belt_ch3",
        "lieyan_cape_ch3",
        "shen_shoulder_ch3",
        "huangsha_duanliu",
        "huangsha_fentian",
        "huangsha_shihun",
        "huangsha_liedi",
        "huangsha_mieying",
        "dizun_ring_ch3",
        "fabao_xuehaitu_t7",
        "fabao_haoqiyin_t7",
        "fabao_qingyunta_t7",
        "fabao_fengmopan_t7",
        "chengyuan_helmet_ch4",
        "zhiyan_boots_ch4",
        "leiming_necklace_ch4",
        "fenghen_ring_ch4",
        "yanxin_belt_ch4",
        "houtu_shoulder_ch4",
        "zeyuan_armor_ch4",
        "tiangang_cape_ch4",
        "shengqi_duanliu",
        "shengqi_fentian",
        "shengqi_shihun",
        "shengqi_liedi",
        "shengqi_mieying",
        "silong_ring_ch4",
        "fabao_xuehaitu_t9",
        "fabao_haoqiyin_t9",
        "fabao_qingyunta_t9",
        "fabao_fengmopan_t9",
        "fabao_longjiling_t9",
        -- 第五章·太虚遗藏
        "zhenpai_boots_ch5",
        "wenfeng_necklace_ch5",
        "hanchi_ring_ch5",
        "bailian_belt_ch5",
        "guanlan_necklace_ch5",
        "suxin_ring_ch5",
        "cangzhen_armor_ch5",
        "shiyuan_cape_ch5",
        "cangzhen_helmet_ch5",
        "tuxue_belt_ch5",
        "qijian_boots_ch5",
        "tuxue_shoulder_ch5",
        "dizun_ring_ch5",
        "fengyin_zhuxian_ch5",
        "fengyin_xianxian_ch5",
        "fengyin_luxian_ch5",
        "fengyin_juexian_ch5",
    },

    -- 每个条目的收录奖励（总计≈T3绿全套的20%）
    entries = {
        jade_gourd = {
            bonus = { atk = 1, maxHp = 5 },
            desc = "浊酒一壶，清灵润体，行走江湖必备之物。",
        },
        spider_queen_ring = {
            bonus = { atk = 1, def = 1 },
            desc = "蛛母丝腺凝结的指环，剧毒缠绕，触之即噬。",
        },
        boar_king_weapon = {
            bonus = { atk = 2, def = 1, maxHp = 5 },
            desc = "猪三哥的战斧，力量惊人。",
        },
        boss_cape = {
            bonus = { def = 2, maxHp = 10 },
            desc = "大大王的战袍，穿上后气势非凡。",
        },
        tiger_set_weapon = {
            bonus = { atk = 2, def = 1, maxHp = 5 },
            desc = "虎牙磨制的利刃，锋利无比。",
        },
        tiger_set_armor = {
            bonus = { def = 3, maxHp = 10 },
            desc = "虎王皮革锻造的铠甲，防御卓越。",
        },
        tiger_set_necklace = {
            bonus = { atk = 3, def = 2, maxHp = 5 },
            desc = "虎王血珀凝结的项坠，蕴含虎王之力。",
        },
        tiger_set_cape = {
            bonus = { atk = 2, def = 2, maxHp = 10 },
            desc = "虎皮缝制的战袍，披上便有虎威加身。",
        },
        boar_patrol_helmet = {
            bonus = { maxHp = 5 },
            desc = "猪妖粗制的铁盔，虽然简陋但异常坚固。",
        },
        bandit_second_belt = {
            bonus = { atk = 1, maxHp = 5 },
            desc = "二大王的腰带，宽如手掌，刀劈不断。",
        },
        dizun_ring_ch1 = {
            bonus = { fortune = 2 },
            desc = "帝尊初铸之戒，虎啸山林，福缘深厚。",
        },
        -- 第二章（加成合计≈Ch1的2倍：atk+18, def+20, maxHp+79）
        gold_helmet_ch2 = {
            bonus = { fortune = 3 },
            desc = "通体金光的头盔，杀敌取财，日进斗金。",
        },
        boar_belt_ch2 = {
            bonus = { atk = 3, maxHp = 12 },
            desc = "猪大哥的蛮力腰带，力大无穷。",
        },
        snake_cape_ch2 = {
            bonus = { def = 5, maxHp = 12 },
            desc = "碧鳞蛇王蜕下的鳞甲披风，坚韧异常。",
        },
        wu_shoulder_ch2 = {
            bonus = { def = 5, maxHp = 10 },
            desc = "乌地北锻造的玄铁肩甲，固若金汤。",
        },
        wu_weapon_ch2 = {
            bonus = { atk = 4, def = 2, maxHp = 10 },
            desc = "乌天南的佩刀，刀气如风，势不可挡。",
        },
        wu_ring_chou = {
            bonus = { atk = 4, def = 4, maxHp = 10 },
            desc = "乌万仇的戒指，满载仇恨之力。",
        },
        wu_ring_hai = {
            bonus = { atk = 4, def = 4, maxHp = 10 },
            desc = "乌万海的戒指，深沉如海，暗藏杀机。",
        },
        wu_boots_ch2 = {
            bonus = { atk = 5, maxHp = 20 },
            desc = "踏云而行，十中避一，轻灵飘逸。",
        },
        wu_armor_ch2 = {
            bonus = { def = 4, maxHp = 12 },
            desc = "乌大傻以蛮力锤锻的玄铁重铠，沉若铁山，硬抗百拳。",
        },
        wu_necklace_ch2 = {
            bonus = { atk = 4, maxHp = 12 },
            desc = "乌二傻以妖骨獠牙穿就的项链，锋锐嗜血，一击致命。",
        },
        wu_hammer_ch2 = {
            bonus = { maxHp = 12 },
            desc = "大傻二傻合力铸就的蛮荒巨锤，一锤落地，山崩石裂。",
        },
        dizun_ring_ch2 = {
            bonus = { fortune = 3 },
            desc = "帝尊再铸之戒，双煞淬炼，福缘深厚。",
        },
        -- 法宝图鉴（第二章·T5）
        fabao_xuehaitu_t5 = {
            bonus = { atk = 3, killHeal = 3 },
            desc = "血煞盟秘传图卷，杀意初凝，血海翻涌。",
        },
        fabao_haoqiyin_t5 = {
            bonus = { killHeal = 3, hpRegen = 0.5 },
            desc = "浩气宗正法印记，正气护体，生生不息。",
        },
        fabao_qingyunta_t5 = {
            bonus = { heavyHit = 8, def = 3 },
            desc = "青云门镇山宝塔，初显威能，碎石裂金。",
        },
        fabao_fengmopan_t5 = {
            bonus = { maxHp = 10, hpRegen = 0.5 },
            desc = "封魔殿封印法盘，魔气初封，血脉坚韧。",
        },
        -- 第三章（×2.0目标：atk≈50, def≈54, maxHp≈212, killHeal≈16 + hpRegen/heavyHit新增）
        -- 实际合计：atk=50, def=54, maxHp=210, killHeal=16, hpRegen=6, heavyHit=15
        kumu_helmet_ch3 = {
            bonus = { maxHp = 25, def = 5, hpRegen = 1 },
            desc = "枯木妖王灵脉凝成的冠冕，残存一丝生机。",
        },
        yanchan_armor_ch3 = {
            bonus = { def = 8, maxHp = 20 },
            desc = "岩蟾妖王蜕壳锻造的石铠，坚如磐石。",
        },
        canglang_necklace_ch3 = {
            bonus = { atk = 5, def = 5 },
            desc = "苍狼妖王獠牙磨制的项坠，嗜血凶戾。",
        },
        chijia_ring_ch3 = {
            bonus = { atk = 5, maxHp = 15 },
            desc = "赤甲妖王毒尾凝结的指环，剧毒锋锐。",
        },
        shegu_belt_ch3 = {
            bonus = { def = 6, maxHp = 20, killHeal = 5 },
            desc = "蛇骨妖王脊椎编织的腰环，韧性惊人。",
        },
        lieyan_cape_ch3 = {
            bonus = { atk = 5, def = 6, hpRegen = 1 },
            desc = "烈焰狮王鬃毛织就的战披，触之灼热，余焰不灭。",
        },
        shen_shoulder_ch3 = {
            bonus = { def = 8, maxHp = 20, hpRegen = 1 },
            desc = "蜃妖王幻影凝聚的肩甲，虚实莫辨，死中求活。",
        },
        -- 黄天大圣灵器武器（5把共享掉落）
        huangsha_duanliu = {
            bonus = { atk = 6, def = 4, hpRegen = 1 },
            desc = "黄沙断流，风刃所至，万物凋零。",
        },
        huangsha_fentian = {
            bonus = { atk = 5, maxHp = 25 },
            desc = "焚天之焰，灼尽一切，生生不息。",
        },
        huangsha_shihun = {
            bonus = { atk = 5, killHeal = 8, hpRegen = 1 },
            desc = "噬魂夺魄，杀敌续命，越战越强。",
        },
        huangsha_liedi = {
            bonus = { atk = 7, heavyHit = 15 },
            desc = "裂地之力，每一击都震碎大地。",
        },
        huangsha_mieying = {
            bonus = { atk = 7, maxHp = 15 },
            desc = "灭影无形，暴击之下，万劫不复。",
        },
        dizun_ring_ch3 = {
            bonus = { physique = 4 },
            desc = "帝尊三铸之戒，万里黄沙淬体，筋骨如铁。",
        },
        -- 法宝图鉴（第三章·T7）
        fabao_xuehaitu_t7 = {
            bonus = { atk = 5, killHeal = 5 },
            desc = "血煞盟秘传图卷，杀意凝形，血海浩荡无涯。",
        },
        fabao_haoqiyin_t7 = {
            bonus = { killHeal = 5, hpRegen = 1 },
            desc = "浩气宗正法印记，正气如渊，伤损自复。",
        },
        fabao_qingyunta_t7 = {
            bonus = { heavyHit = 15, def = 5 },
            desc = "青云门镇山宝塔，威震四方，金石俱碎。",
        },
        fabao_fengmopan_t7 = {
            bonus = { maxHp = 20, hpRegen = 1 },
            desc = "封魔殿封印法盘，魔气深封，气血充盈。",
        },
        -- 第四章·龙神圣器（合计：atk=34, def=9, maxHp=112, killHeal=11, hpRegen=2）
        shengqi_duanliu = {
            bonus = { atk = 7, def = 3, maxHp = 22 },
            desc = "龙极断流，风卷残云，一刀斩断万古长河。",
        },
        shengqi_fentian = {
            bonus = { atk = 6, maxHp = 25, hpRegen = 2 },
            desc = "龙极焚天，焚尽苍穹，浴火之中生生不息。",
        },
        shengqi_shihun = {
            bonus = { atk = 7, maxHp = 20, killHeal = 5 },
            desc = "龙极噬魂，杀伐果断，每一击都在吞噬生机。",
        },
        shengqi_liedi = {
            bonus = { atk = 7, def = 6, maxHp = 20 },
            desc = "龙极裂地，力贯千钧，大地为之龟裂。",
        },
        shengqi_mieying = {
            bonus = { atk = 7, maxHp = 25, killHeal = 6 },
            desc = "龙极灭影，暗影之中，必杀一击，万劫不复。",
        },
        -- 第四章·帝尊肆戒（福缘+5）
        silong_ring_ch4 = {
            bonus = { fortune = 5 },
            desc = "帝尊终铸之戒，四龙精魄凝聚，福缘天成，气运亨通。",
        },
        -- 第四章·八卦海（合计：atk=26, def=56, maxHp=140, killHeal=8, hpRegen=5, heavyHit=35）
        chengyuan_helmet_ch4 = {
            bonus = { maxHp = 30, def = 6, hpRegen = 1 },
            desc = "沈渊衣以深渊之水淬炼的冥冠，戴上后仿若沉入万丈深渊。",
        },
        zhiyan_boots_ch4 = {
            bonus = { def = 8, maxHp = 25 },
            desc = "岩不动脚下亘古不移的磐石锻造，落地便如山岳扎根。",
        },
        leiming_necklace_ch4 = {
            bonus = { atk = 8, heavyHit = 15 },
            desc = "雷惊蛰心中凝结的雷珠磨制，电弧缠绕，触之酥麻。",
        },
        fenghen_ring_ch4 = {
            bonus = { atk = 8, heavyHit = 20 },
            desc = "风无痕万年逃亡中唯一不曾遗落之物，轻若无物，锋如断魂。",
        },
        yanxin_belt_ch4 = {
            bonus = { def = 8, maxHp = 30, killHeal = 8 },
            desc = "炎若晦丹炉余焰凝成的腰环，温热不散，杀敌续命。",
        },
        houtu_shoulder_ch4 = {
            bonus = { def = 10, maxHp = 25, hpRegen = 2 },
            desc = "厚德生以厚土封印阵力时剥落的肩甲，生生不息。",
        },
        zeyuan_armor_ch4 = {
            bonus = { def = 12, maxHp = 30, hpRegen = 2 },
            desc = "泽归墟毕生炼毒的精华凝为仙铠，毒泽化生，万物滋养。",
        },
        tiangang_cape_ch4 = {
            bonus = { atk = 10, def = 12 },
            desc = "司空正阳以天罡正气织就的圣披，浩然之气，百邪不侵。",
        },
        -- 法宝图鉴（第四章·T9）
        fabao_xuehaitu_t9 = {
            bonus = { atk = 7, killHeal = 7 },
            desc = "血煞盟秘传图卷，杀意滔天，血海焚天灭地。",
        },
        fabao_haoqiyin_t9 = {
            bonus = { killHeal = 7, hpRegen = 2 },
            desc = "浩气宗正法印记，浩气长存，万物归元。",
        },
        fabao_qingyunta_t9 = {
            bonus = { heavyHit = 20, def = 7 },
            desc = "青云门镇山宝塔，威压万方，天崩地裂。",
        },
        fabao_fengmopan_t9 = {
            bonus = { maxHp = 30, hpRegen = 2 },
            desc = "封魔殿封印法盘，魔气尽封，血脉如岳。",
        },
        fabao_longjiling_t9 = {
            bonus = { atk = 5, constitution = 5 },
            desc = "四龙之威凝为一令，龙息喷吐，百鬼辟易。",
        },
        -- 第五章·太虚遗藏（合计：atk=36, def=64, maxHp=170, killHeal=20, hpRegen=8, heavyHit=35, wisdom=6, constitution=6, physique=14）
        zhenpai_boots_ch5 = {
            bonus = { def = 8, maxHp = 20 },
            desc = "太虚剑宫护山石傀遗留的重铸石靴，步如山岳。",
        },
        wenfeng_necklace_ch5 = {
            bonus = { atk = 8, constitution = 6 },
            desc = "裴千岳问剑之刃化为的雷纹坠，剑意如雷。",
        },
        hanchi_ring_ch5 = {
            bonus = { physique = 8, hpRegen = 1 },
            desc = "霜鸾寒池凝结的冰华戒指，冰魄入骨。",
        },
        bailian_belt_ch5 = {
            bonus = { maxHp = 30, hpRegen = 2 },
            desc = "韩百炼地炉淬火的腰绶，百炼不屈。",
        },
        guanlan_necklace_ch5 = {
            bonus = { atk = 8, wisdom = 6 },
            desc = "石观澜碑林守护的佩饰，碑文如剑。",
        },
        suxin_ring_ch5 = {
            bonus = { atk = 10, heavyHit = 20 },
            desc = "宁栖梧宿心之怨凝为残戒，杀意难消。",
        },
        cangzhen_armor_ch5 = {
            bonus = { def = 12, maxHp = 30, hpRegen = 3 },
            desc = "温素章藏经阁护法玄衣，守正辟邪。",
        },
        cangzhen_helmet_ch5 = {
            bonus = { atk = 10, physique = 6, killHeal = 10 },
            desc = "藏真一脉护脉玄冠，杀伐之中养护经脉。",
        },
        tuxue_belt_ch5 = {
            bonus = { maxHp = 30, def = 10, killHeal = 10 },
            desc = "屠血将命绶，杀戮淬炼，血脉坚韧。",
        },
        qijian_boots_ch5 = {
            bonus = { def = 12, maxHp = 30 },
            desc = "栖剑行靴，剑气护步，铁壁无隙。",
        },
        tuxue_shoulder_ch5 = {
            bonus = { def = 12, maxHp = 30, hpRegen = 2 },
            desc = "屠血魔肩，血战千场，铁肩担道。",
        },
        shiyuan_cape_ch5 = {
            bonus = { heavyHit = 30, def = 10 },
            desc = "噬渊血犼魔氅，深渊之力镇煞四方。",
        },
        dizun_ring_ch5 = {
            bonus = { fortune = 6 },
            desc = "帝尊五铸之戒，太虚淬炼，福泽深厚。",
        },
        fengyin_zhuxian_ch5 = {
            bonus = { atk = 5 },
            desc = "封印之下犹有诛天之意，剑气冲霄。",
        },
        fengyin_xianxian_ch5 = {
            bonus = { atk = 5 },
            desc = "封印之下犹有陷地之力，万物沉沦。",
        },
        fengyin_luxian_ch5 = {
            bonus = { atk = 5 },
            desc = "封印之下犹有戮灵之威，杀伐无情。",
        },
        fengyin_juexian_ch5 = {
            bonus = { atk = 5 },
            desc = "封印之下犹有绝世之锋，一剑断仙。",
        },
    },
}

-- 套装效果
EquipmentData.SetBonuses = {
    tiger_king = {
        name = "虎王套装",
        pieces = {
            -- 仅3件套效果，无2件套
            [3] = {
                name = "虎王之力",
                description = "攻击力+15, 生命值+50, 防御力+8",
                bonuses = { atk = 15, maxHp = 50, def = 8 },
            },
        },
    },
    wu_rings = {
        name = "乌堡双煞",
        pieces = {
            [2] = {
                name = "双煞合璧",
                description = "攻击力+20, 暴击率+5%, 生命值+60",
                bonuses = { atk = 20, critRate = 0.05, maxHp = 60 },
            },
        },
    },

    -- ===================== 仙劫套装（T9灵器，4套×3阶） =====================
    -- 触发事件映射：skill_hit → player_deal_damage, kill → monster_death,
    --              take_damage → player_hurt, heavy_hit → player_heavy_hit
    xuesha = {
        name = "血煞套装",
        pieces = {
            [3] = {
                name = "血煞之悟",
                description = "悟性+25",
                bonuses = { wisdom = 25 },
            },
            [5] = {
                name = "血煞连击",
                description = "连击率+2%",
                bonuses = { comboChance = 0.02 },
            },
            [8] = {
                name = "血煞冲击",
                description = "悟性+25, 技能命中15%概率释放血煞冲击",
                bonuses = { wisdom = 25 },
                aoeEffect = {
                    trigger = "player_deal_damage",
                    chance = 0.15,
                    damageAttribute = "wisdom",
                    damageCoeff = 10,
                    range = 2.0,
                    color = { 180, 30, 30, 255 },
                    glowColor = { 255, 60, 60, 120 },
                    shape = "circle",
                    effectName = "血煞冲击",
                    duration = 0.5,
                    cooldown = 10.0,
                },
            },
        },
    },
    qingyun = {
        name = "青云套装",
        pieces = {
            [3] = {
                name = "青云之骨",
                description = "根骨+25",
                bonuses = { constitution = 25 },
            },
            [5] = {
                name = "青云重击",
                description = "重击率+4%",
                bonuses = { heavyHitRate = 0.04 },
            },
            [8] = {
                name = "青云裂空",
                description = "根骨+25, 重击25%概率释放青云裂空",
                bonuses = { constitution = 25 },
                aoeEffect = {
                    trigger = "player_heavy_hit",
                    chance = 0.25,
                    damageAttribute = "constitution",
                    damageCoeff = 10,
                    range = 2.5,
                    color = { 60, 180, 220, 255 },
                    glowColor = { 100, 220, 255, 120 },
                    shape = "circle",
                    effectName = "青云裂空",
                    duration = 0.5,
                    cooldown = 10.0,
                },
            },
        },
    },
    fengmo = {
        name = "封魔套装",
        pieces = {
            [3] = {
                name = "封魔之魄",
                description = "体魄+25",
                bonuses = { physique = 25 },
            },
            [5] = {
                name = "封魔血怒",
                description = "血怒概率+4%",
                bonuses = { bloodRageChance = 0.04 },
            },
            [8] = {
                name = "封魔金轮",
                description = "体魄+25, 受击10%概率释放封魔金轮",
                bonuses = { physique = 25 },
                aoeEffect = {
                    trigger = "player_hurt",
                    chance = 0.10,
                    damageAttribute = "physique",
                    damageCoeff = 10,
                    range = 2.0,
                    color = { 200, 160, 50, 255 },
                    glowColor = { 255, 200, 80, 120 },
                    shape = "circle",
                    effectName = "封魔金轮",
                    duration = 0.5,
                    cooldown = 10.0,
                },
            },
        },
    },
    haoqi = {
        name = "浩气套装",
        pieces = {
            [3] = {
                name = "浩气之缘",
                description = "福缘+25",
                bonuses = { fortune = 25 },
            },
            [5] = {
                name = "浩气同步",
                description = "宠物同步率+5%",
                bonuses = { petSyncRate = 0.05 },
            },
            [8] = {
                name = "浩气破天",
                description = "福缘+25, 击杀20%概率释放浩气破天",
                bonuses = { fortune = 25 },
                aoeEffect = {
                    trigger = "monster_death",
                    chance = 0.20,
                    damageAttribute = "fortune",
                    damageCoeff = 10,
                    range = 2.5,
                    color = { 220, 230, 255, 255 },
                    glowColor = { 240, 245, 255, 120 },
                    shape = "circle",
                    effectName = "浩气破天",
                    duration = 0.5,
                    cooldown = 10.0,
                },
            },
        },
    },

    -- ===================== 第五章·太虚遗藏 2件套 =====================

    humai_yizhuang = {
        name = "护脉遗装",
        pieces = {
            [2] = {
                name = "护脉遗泽",
                description = "最大生命 +1200",
                bonuses = { maxHp = 1200 },
            },
        },
    },
    zhenzong_xuanwei = {
        name = "镇宗玄卫",
        pieces = {
            [2] = {
                name = "镇宗之御",
                description = "防御 +10%",
                bonuses = { defPercent = 0.10 },
            },
        },
    },
}

-- ===================== 葫芦升级配置（金币消耗 → 提升阶级） =====================

-- 葫芦升级数据表：从当前 tier 升级到 tier+1 的消耗与效果
-- key = 目标 tier（升级后的阶级）
EquipmentData.GOURD_UPGRADE = {
    -- [目标tier] = { cost=金币, requiredRealm=境界要求, quality=品质, subStats=副属性列表 }
    -- 取最大波动值：绿/蓝/紫/青×1.2, 橙×1.3。生命值floor取整，击杀回血保留2位小数，福缘=linearGrowth无随机
    -- maxHp = floor(6 × tierMult × maxFluct), killHeal = 3 × tierMult × maxFluct, fortune = floor(tier × qualityMult)
    [2]  = { cost = 10000,    requiredRealm = nil,         quality = "green",  subStats = { { stat = "maxHp", value = 10 } } },                                                                       -- floor(6×1.5×1.2)=10
    [3]  = { cost = 25000,    requiredRealm = "lianqi_1",  quality = "blue",   subStats = { { stat = "maxHp", value = 15 }, { stat = "fortune", value = 3 } } },                                       -- floor(6×2.2×1.2)=15, floor(3×1.2)=3
    [4]  = { cost = 50000,    requiredRealm = "lianqi_1",  quality = "blue",   subStats = { { stat = "maxHp", value = 21 }, { stat = "fortune", value = 4 } } },                                       -- floor(6×3.0×1.2)=21, floor(4×1.2)=4
    [5]  = { cost = 100000,   requiredRealm = "zhuji_1",   quality = "purple", subStats = { { stat = "maxHp", value = 28 }, { stat = "fortune", value = 6 }, { stat = "killHeal", value = 14.4 } } },  -- floor(6×4.0×1.2)=28, floor(5×1.3)=6, 3×4.0×1.2=14.4
    [6]  = { cost = 200000,   requiredRealm = "jindan_1",  quality = "purple", subStats = { { stat = "maxHp", value = 39 }, { stat = "fortune", value = 7 }, { stat = "killHeal", value = 19.8 } } },  -- floor(6×5.5×1.2)=39, floor(6×1.3)=7, 3×5.5×1.2=19.8
    [7]  = { cost = 750000,   requiredRealm = "yuanying_1", quality = "orange",  subStats = { { stat = "maxHp", value = 54 }, { stat = "fortune", value = 10 }, { stat = "killHeal", value = 27.3 } } }, -- floor(6×7.0×1.3)=54, floor(7×1.5)=10, 3×7.0×1.3=27.3
    [8]  = { cost = 2400000,  requiredRealm = "huashen_1", quality = "orange",  subStats = { { stat = "maxHp", value = 70 }, { stat = "fortune", value = 12 }, { stat = "killHeal", value = 35.1 } } }, -- floor(6×9.0×1.3)=70, floor(8×1.5)=12, 3×9.0×1.3=35.1
    [9]  = { cost = 7000000,  requiredRealm = "heti_1",    quality = "cyan",    subStats = { { stat = "maxHp", value = 79 }, { stat = "fortune", value = 16 }, { stat = "killHeal", value = 39.6 } }, spiritStat = { stat = "wisdom", name = "悟性", value = 8 } }, -- floor(6×11.0×1.2)=79, floor(9×1.8)=16, 3×11.0×1.2=39.6, spirit=floor(9×1.8×0.5)=8
    [10] = { cost = 5000000,  requiredRealm = "dacheng_1", quality = "cyan",    subStats = { { stat = "maxHp", value = 93 }, { stat = "fortune", value = 18 }, { stat = "killHeal", value = 46.8 } }, spiritStat = { stat = "wisdom", name = "悟性", value = 9 } }, -- floor(6×13.0×1.2)=93, floor(10×1.8)=18, 3×13.0×1.2=46.8, spirit=floor(10×1.8×0.5)=9
    [11] = { cost = 10000000, requiredRealm = "dujie_1",   quality = "cyan",    subStats = { { stat = "maxHp", value = 108 }, { stat = "fortune", value = 19 }, { stat = "killHeal", value = 54 } }, spiritStat = { stat = "wisdom", name = "悟性", value = 9 } },   -- floor(6×15.0×1.2)=108, floor(11×1.8)=19, 3×15.0×1.2=54, spirit=floor(11×1.8×0.5)=9
}

-- 葫芦各阶主属性（hpRegen）= 基础值 × TIER_MULTIPLIER × 品质倍率
-- 基础值 1.0, 品质倍率: green=1.1, blue=1.2, purple=1.3, orange=1.5, cyan=1.8
EquipmentData.GOURD_MAIN_STAT = {
    [1]  = 1.10,    -- 1.0 × 1.0 × 1.1(绿)
    [2]  = 2.20,    -- 1.0 × 2.0 × 1.1(绿)
    [3]  = 3.60,    -- 1.0 × 3.0 × 1.2(蓝)
    [4]  = 5.40,    -- 1.0 × 4.5 × 1.2(蓝)
    [5]  = 7.80,    -- 1.0 × 6.0 × 1.3(紫)
    [6]  = 10.40,   -- 1.0 × 8.0 × 1.3(紫)
    [7]  = 15.75,   -- 1.0 × 10.5 × 1.5(橙)
    [8]  = 20.25,   -- 1.0 × 13.5 × 1.5(橙)
    [9]  = 30.60,   -- 1.0 × 17.0 × 1.8(青)
    [10] = 37.80,   -- 1.0 × 21.0 × 1.8(青)
    [11] = 45.00,   -- 1.0 × 25.0 × 1.8(青)
}

-- ===================== 龙神圣器打造配方 =====================
-- 灵器 → 圣器 的映射关系
EquipmentData.DRAGON_FORGE_RECIPES = {
    { source = "huangsha_duanliu", target = "shengqi_duanliu", label = "断流" },
    { source = "huangsha_fentian", target = "shengqi_fentian", label = "焚天" },
    { source = "huangsha_shihun",  target = "shengqi_shihun",  label = "噬魂" },
    { source = "huangsha_liedi",   target = "shengqi_liedi",   label = "裂地" },
    { source = "huangsha_mieying", target = "shengqi_mieying", label = "灭影" },
}

-- 打造消耗
EquipmentData.DRAGON_FORGE_COST = {
    gold = 5000000,  -- 500万金币
    materials = {
        { id = "dragon_scale_ice",   count = 1 },
        { id = "dragon_scale_abyss", count = 1 },
        { id = "dragon_scale_fire",  count = 1 },
        { id = "dragon_scale_sand",  count = 1 },
    },
}

-- 龙极令打造消耗（独立，不与龙极武器共享）
EquipmentData.LONGJI_FORGE_COST = {
    taixu_token = 1000,    -- 太虚令 1000 枚
    materials = {
        { id = "dragon_scale_ice",   count = 1 },
        { id = "dragon_scale_abyss", count = 1 },
        { id = "dragon_scale_fire",  count = 1 },
        { id = "dragon_scale_sand",  count = 1 },
    },
}

-- 灵器打造消耗（独立，不与龙极武器共享）
EquipmentData.LINGQI_FORGE_COST = {
    gold = 100000,         -- 10 万金币
    materials = {
        { id = "dragon_scale_ice",   count = 1 },
        { id = "dragon_scale_abyss", count = 1 },
        { id = "dragon_scale_fire",  count = 1 },
        { id = "dragon_scale_sand",  count = 1 },
    },
}

EquipmentData.LINGQI_FORGE_SET_CHANCE = 0.30  -- 30% 概率出套装灵器
EquipmentData.LINGQI_FORGE_SLOTS = EquipmentData.STANDARD_SLOTS  -- 与掉落一致

-- ============================================================================
-- 法宝模板（阵营挑战系统新版法宝，动态生成，Tier/品质为实例数据）
-- 旧版专属装备（blood_sea_lv1/lv2/lv3 等）保留不动，与新法宝独立共存
-- ============================================================================
EquipmentData.FabaoTemplates = {
    -- 血煞盟 · 血海图（主属性：悟性 wisdom，仙缘公式）
    fabao_xuehaitu = {
        name      = "血海图",
        slot      = "exclusive",
        mainStatType = "wisdom",      -- 仙缘属性：公式 = floor(tier × qualityMult) × 5
        mainStatFormula = "xianyuan",  -- "xianyuan" = 仙缘公式, "standard" = 标准公式
        mainStatBase = 5,             -- 仙缘公式下此值 = 倍数因子（sub × 5）
        skillId   = "blood_sea_aoe",
        -- 图标按 tier 范围映射（复用现有图标资源）
        iconByTier = {
            [3] = "icon_fabao_xuehaitu_lv1.png",  -- T3-T4（法宝专用图标，不影响旧血海图）
            [4] = "icon_fabao_xuehaitu_lv1.png",
            [5] = "icon_fabao_xuehaitu_lv2.png",  -- T5-T6
            [6] = "icon_fabao_xuehaitu_lv2.png",
            [7] = "icon_fabao_xuehaitu_lv3.png",  -- T7-T9
            [8] = "icon_fabao_xuehaitu_lv3.png",
            [9] = "icon_fabao_xuehaitu_lv3.png",
        },
        sellPriceByTier = {
            [3] = 300,  [4] = 400,  [5] = 500,
            [6] = 600,  [7] = 700,  [8] = 800, [9] = 900,
        },
    },
    -- 浩气宗 · 浩气印（主属性：福缘 fortune，仙缘公式）
    fabao_haoqiyin = {
        name      = "浩气印",
        slot      = "exclusive",
        mainStatType = "fortune",
        mainStatFormula = "xianyuan",
        mainStatBase = 5,
        skillId   = "haoran_zhengqi",
        iconByTier = {
            [3] = "icon_haoqi_seal_lv1.png",
            [4] = "icon_haoqi_seal_lv1.png",
            [5] = "icon_haoqi_seal_lv2.png",
            [6] = "icon_haoqi_seal_lv2.png",
            [7] = "icon_haoqi_seal_lv3.png",
            [8] = "icon_haoqi_seal_lv3.png",
            [9] = "icon_haoqi_seal_lv3.png",
        },
        sellPriceByTier = {
            [3] = 300,  [4] = 400,  [5] = 500,
            [6] = 600,  [7] = 700,  [8] = 800, [9] = 900,
        },
    },
    -- 青云门 · 青云塔（主属性：根骨 constitution，仙缘公式）
    fabao_qingyunta = {
        name      = "青云塔",
        slot      = "exclusive",
        mainStatType = "constitution",
        mainStatFormula = "xianyuan",
        mainStatBase = 5,
        skillId   = "qingyun_suppress",
        iconByTier = {
            [3] = "icon_fabao_qingyunta_lv1.png",
            [4] = "icon_fabao_qingyunta_lv1.png",
            [5] = "icon_fabao_qingyunta_lv2.png",
            [6] = "icon_fabao_qingyunta_lv2.png",
            [7] = "icon_fabao_qingyunta_lv3.png",
            [8] = "icon_fabao_qingyunta_lv3.png",
            [9] = "icon_fabao_qingyunta_lv3.png",
        },
        sellPriceByTier = {
            [3] = 300,  [4] = 400,  [5] = 500,
            [6] = 600,  [7] = 700,  [8] = 800, [9] = 900,
        },
    },
    -- 封魔殿 · 封魔盘（主属性：体魄 physique，仙缘公式）
    fabao_fengmopan = {
        name      = "封魔盘",
        slot      = "exclusive",
        mainStatType = "physique",
        mainStatFormula = "xianyuan",
        mainStatBase = 5,
        skillId   = "fengmo_seal_array",
        iconByTier = {
            [3] = "icon_fabao_fengmopan_lv1.png",
            [4] = "icon_fabao_fengmopan_lv1.png",
            [5] = "icon_fabao_fengmopan_lv2.png",
            [6] = "icon_fabao_fengmopan_lv2.png",
            [7] = "icon_fabao_fengmopan_lv3.png",
            [8] = "icon_fabao_fengmopan_lv3.png",
            [9] = "icon_fabao_fengmopan_lv3.png",
        },
        sellPriceByTier = {
            [3] = 300,  [4] = 400,  [5] = 500,
            [6] = 600,  [7] = 700,  [8] = 800, [9] = 900,
        },
    },
    -- 龙极令（攻击型法宝，第四章铸造，主属性：攻击力，standard 公式）
    fabao_longjiling = {
        name      = "龙极令",
        slot      = "exclusive",
        mainStatType = "atk",             -- 攻击力
        mainStatFormula = "standard",     -- 标准公式：base × TIER_MULT × qualityMult
        mainStatBase = 2,                 -- 攻击法宝 base=2
        skillId   = "dragon_breath",
        iconByTier = {
            [9] = "icon_fabao_longjiling.png",
        },
        sellPriceByTier = {
            [9] = 1200,
        },
        forgeType = "dragon_longji",
    },
}

return EquipmentData
