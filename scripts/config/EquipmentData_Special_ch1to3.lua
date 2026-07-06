-- EquipmentData_Special_ch1to3.lua
-- 特殊装备：第一章 + 第二章 + 第三章（妖王 + 沙万里灵器）

return {
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

    -- 虎王试炼炉合成：T4橙色头盔
    jihu_helmet_ch1 = {
        name = "极虎盔",
        desc = "以虎王三件套与帝尊壹戒合铸的战盔，虎威内敛，锋芒入骨。",
        slot = "helmet",
        icon = "image/icon_jihu_helmet_ch1_20260703062816.png",
        quality = "orange",
        tier = 4,
        sellPrice = 400,
        mainStat = { maxHp = 135 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 5.4 },
            { stat = "critRate", name = "暴击率", value = 0.024 },
            { stat = "critDmg", name = "暴击伤害", value = 0.12 },
        },
        fixedSubStats = true,
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

    -- 乌家宝藏：T5青色灵器腰带
    jianxin_belt_ch2 = {
        name = "剑心腰带",
        desc = "乌万海大殿秘藏的青玉腰带，剑心玉扣明灭不定，佩之气血凝实。",
        slot = "belt",
        icon = "image/jianxin_belt_ch2_20260704023406.png",
        quality = "cyan",
        tier = 5,
        sellCurrency = "lingYun",
        sellPrice = 1,
        mainStat = { maxHp = 162 },
        subStats = {
            { stat = "critRate", name = "暴击率", value = 0.025 },
            { stat = "wisdom", name = "悟性", value = 9 },
            { stat = "killHeal", name = "击杀回血", value = 12 },
        },
        spiritStat = { stat = "atk", name = "攻击力", value = 3 },
        fixedSubStats = true,
    },

    -- 乌堡锻造台合成：T6橙色戒指
    -- 主属性: 3 × 8.0(T6) × 1.5(橙) = 36
    -- 副属性: 橙色3条, 中值×1.1
    xuehai_shenchou_ring_ch2 = {
        name = "血海深仇戒",
        desc = "以乌堡戒·海、乌堡戒·仇与帝尊贰戒合炼而成，仇海翻涌，指节生寒。",
        slot = "ring1",
        icon = "icon_t6_ring.png",
        quality = "orange",
        tier = 6,
        sellPrice = 600,
        mainStat = { atk = 36 },
        subStats = {
            { stat = "critRate", name = "暴击率", value = 0.033 },  -- 0.01 × 3.0(PCT_SUB_T6) × 1.1(橙) = 0.033
            { stat = "heavyHit", name = "重击值", value = 48.4 },   -- 8 × 5.5(SUB_T6) × 1.1(橙) = 48.4
            { stat = "constitution", name = "根骨", value = 9 },    -- linearGrowth: floor(6 × 1.5) = 9
        },
        fixedSubStats = true,
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

    -- 流沙之母掉落：T6橙色披风（王级BOSS游荡）
    -- 主属性: 0.02 × 4.0(PCT_T6) × 1.5(橙) = 0.12
    -- 副属性: 橙色3条, 中值×1.1
    liusha_cape_ch3 = {
        name = "流沙蛛甲披",
        slot = "cape",
        icon = "icon_t6_cape.png",
        quality = "orange",
        tier = 6,
        sellPrice = 600,
        mainStat = { dmgReduce = 0.12 },
        subStats = {
            { stat = "def", name = "防御力", value = 7.26 },         -- 1.2 × 5.5(SUB_T6) × 1.1(橙) = 7.26
            { stat = "maxHp", name = "生命值", value = 36.3 },      -- 6 × 5.5(SUB_T6) × 1.1(橙) = 36.3
            { stat = "constitution", name = "根骨", value = 9 },    -- linearGrowth: floor(6 × 1.5) = 9
        },
    },

    -- 55级流沙之子掉落：T7紫色头盔
    -- 主属性: 20 × 10.5(T7) × 1.3(紫) = 273
    -- 副属性: 紫色3条, 中值×1.0; SUB_T7=7.0
    liusha_helmet_ch3 = {
        name = "沙蚀额冠",
        slot = "helmet",
        icon = "icon_t7_helmet.png",
        quality = "purple",
        tier = 7,
        sellPrice = 700,
        mainStat = { maxHp = 273 },
        subStats = {
            { stat = "wisdom", name = "悟性", value = 9 },          -- linearGrowth: floor(7 × 1.3) = 9
            { stat = "def", name = "防御力", value = 8.4 },          -- 1.2 × 7.0 = 8.4
            { stat = "maxHp", name = "生命值", value = 42.0 },       -- 6 × 7.0 = 42.0
        },
    },

    -- 流沙之母掉落：T7灵器腰带（帝级BOSS专属，含特效）
    -- 主属性: 15 × 10.5(T7) × 1.8(灵器) = 283.5
    -- 副属性: 灵器3条, 中值×1.0; SUB_T7=7.0, PCT_SUB_T7=3.8
    liusha_belt_ch3 = {
        name = "流沙绶带",
        slot = "belt",
        icon = "icon_t7_belt.png",
        quality = "cyan",
        tier = 7,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { maxHp = 283.5 },
        subStats = {
            { stat = "physique", name = "体魄", value = 12 },       -- linearGrowth: floor(7 × 1.8) = 12
            { stat = "def", name = "防御力", value = 8.4 },         -- 1.2 × 7.0 = 8.4
            { stat = "hpRegen", name = "生命回复", value = 3.5 },   -- 0.5 × 7.0 = 3.5
        },
        spiritStat = { stat = "critRate", name = "暴击率", value = 0.019 }, -- 0.01 × 3.8(PCT_SUB_T7) × 0.5 = 0.019
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

}
