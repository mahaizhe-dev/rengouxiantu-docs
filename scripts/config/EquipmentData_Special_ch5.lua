-- EquipmentData_Special_ch5.lua
-- 特殊装备：第五章·太虚遗藏 + 封印古剑 + 铸剑地炉

return {
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
        specialEffect = {
            type = "yuanjia",
            name = "渊甲护身",
            desc = "受到伤害后，若当前生命低于50%，获得12%减伤，持续4秒（冷却8秒）",
            dmgReduce = 0.12,
            duration = 4.0,
            cooldown = 8.0,
        },
    },

    -- 天渊灵披（镇渊魔帅·蚀骨，掉落1%）：T10 青/灵器 披风
    -- 主属性: 0.02 × 8.0(T10pct) × 1.8(灵器) = 0.288
    -- 副属性: 灵器3条，hpRegen/critDmg/maxHp；无灵性属性
    lingqi_cape_ch5 = {
        name = "天渊灵披",
        slot = "cape",
        icon = "image/icon_lingqi_cape_ch5_20260524014619.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { dmgReduce = 0.288 },
        subStats = {
            { stat = "hpRegen", name = "生命回复", value = 6.5 },    -- 0.5 × 13.0 = 6.5
            { stat = "critDmg", name = "暴击伤害", value = 0.375 },  -- 0.05 × 7.5 = 0.375
            { stat = "maxHp",   name = "生命值",   value = 78 },     -- 6 × 13.0 = 78
        },
        specialEffect = {
            type = "yuanjia",
            name = "渊甲护身",
            desc = "受到伤害后，若当前生命低于50%，获得12%减伤，持续4秒（冷却8秒）",
            dmgReduce = 0.12,
            duration = 4.0,
            cooldown = 8.0,
        },
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

    -- 均灵环：T10 青/灵器 戒指
    -- 主属性: 3 × 21.0(T10) × 1.8(灵器) = 113.4
    -- 副属性: 灵器3条，def/maxHp/hpRegen；无灵性属性
    lingqi_ring_ch5 = {
        name = "均灵环",
        slot = "ring2",
        icon = "image/icon_lingqi_ring_ch5_20260523093208.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 113.4 },
        subStats = {
            { stat = "def",     name = "防御力",   value = 15.6 }, -- 1.2 × 13.0 = 15.6
            { stat = "maxHp",   name = "生命值",   value = 78 },   -- 6 × 13.0 = 78
            { stat = "hpRegen", name = "生命回复", value = 6.5 },  -- 0.5 × 13.0 = 6.5
        },
        specialEffect = {
            type = "xianyuan_lowest_boost",
            name = "仙缘均衡",
            desc = "当前总值最低的仙缘属性额外获得100点加成（唯一，同类取最高值）",
            bonus = 100,
        },
    },

    -- ===================== 第五章·封印古剑（四仙剑各0.5%独立掉落） =====================

    -- 封印古剑·诛仙（诛仙剑Boss掉落）：T10 青/灵器 武器
    fengyin_zhuxian_ch5 = {
        name = "封印古剑·诛仙",
        desc = "诛仙剑灵封印后残余的剑身，虽失锋芒，仍余诛杀之意。",
        slot = "weapon",
        icon = "image/icon_fengyin_zhuxian_ch5_20260518083648.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        hasSpiritStat = true,  -- 掉落时自动附加1条随机灵性属性
        mainStat = { atk = 189 },
        subStats = {
            { stat = "critDmg", name = "暴击伤害", value = 0.375 },
            { stat = "critDmg", name = "暴击伤害", value = 0.375 },
            { stat = "atk", name = "攻击力", value = 19.5 },
        },
        specialEffect = {
            type = "zhuxian",
            name = "诛仙",
            desc = "暴击时，追加一次15%攻击力的伤害（可暴击）",
            damagePercent = 0.15,
            canCrit = true,
            cooldown = 1.0,
        },
    },

    -- 封印古剑·陷仙（陷仙剑Boss掉落）：T10 青/灵器 武器
    fengyin_xianxian_ch5 = {
        name = "封印古剑·陷仙",
        desc = "陷仙剑灵封印后残余的剑身，困敌之力犹存，触之即陷。",
        slot = "weapon",
        icon = "image/icon_fengyin_xianxian_ch5_20260518085543.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        hasSpiritStat = true,  -- 掉落时自动附加1条随机灵性属性
        mainStat = { atk = 189 },
        subStats = {
            { stat = "physique", name = "体魄", value = 18 },
            { stat = "maxHp", name = "生命值", value = 78 },
            { stat = "critRate", name = "暴击率", value = 0.075 },
        },
        specialEffect = {
            type = "xianxian",
            name = "陷仙",
            desc = "生命>50%时暴击伤害+50%；生命≤50%时每秒恢复2%最大生命",
            highHpThreshold = 0.50,
            critDmgBonus = 0.50,
            lowHpRegenPercent = 0.02,
        },
    },

    -- 封印古剑·戮仙（戮仙剑Boss掉落）：T10 青/灵器 武器
    fengyin_luxian_ch5 = {
        name = "封印古剑·戮仙",
        desc = "戮仙剑灵封印后残余的剑身，嗜杀本能未泯，血气缠绕。",
        slot = "weapon",
        icon = "image/icon_fengyin_luxian_ch5_20260518083709.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        hasSpiritStat = true,  -- 掉落时自动附加1条随机灵性属性
        mainStat = { atk = 189 },
        subStats = {
            { stat = "constitution", name = "根骨", value = 18 },
            { stat = "heavyHit", name = "重击伤害", value = 104 },
            { stat = "atk", name = "攻击力", value = 19.5 },
        },
        specialEffect = {
            type = "luxian",
            name = "戮仙",
            desc = "普攻时有10%概率发动连击，连击可触发普攻特效",
            procChance = 0.10,
            cooldown = 1.0,
        },
    },

    -- 封印古剑·绝仙（绝仙剑Boss掉落）：T10 青/灵器 武器
    fengyin_juexian_ch5 = {
        name = "封印古剑·绝仙",
        desc = "绝仙剑灵封印后残余的剑身，绝灭之力沉睡其中，不可轻触。",
        slot = "weapon",
        icon = "image/icon_fengyin_juexian_ch5_20260518083649.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        hasSpiritStat = true,  -- 掉落时自动附加1条随机灵性属性
        mainStat = { atk = 189 },  -- 5 × 21.0 × 1.8 = 189（weapon BASE=5）
        subStats = {
            { stat = "killHeal", name = "击杀回血", value = 39 },    -- 3 × 13.0 = 39
            { stat = "atk", name = "攻击力", value = 19.5 },         -- 1.5 × 13.0 = 19.5
            { stat = "atk", name = "攻击力", value = 19.5 },         -- 1.5 × 13.0 = 19.5
        },
        specialEffect = {
            type = "juexian",
            name = "绝仙",
            desc = "每次攻击获得1层绝命，每层攻击+3%，最多5层，持续4秒",
            stackPercent = 0.03,   -- 每层+3%攻击
            maxStacks = 5,         -- 最多5层
            duration = 4.0,        -- 持续4秒，命中刷新
        },
    },

    -- ======================================================================
    -- 铸剑地炉打造装备（第五章 T10 圣器，需铸剑地炉合成）
    -- 圣器 qualityMult=2.1，SPECIAL_FLUCTUATION["red"]={1.2,0.3}
    -- ======================================================================

    -- 帝尊圣戒（铸剑地炉打造）：T10 红/圣器 戒指
    -- 主属性: 3 × 21.0(T10) × 2.1(圣器) = 132.3
    -- 副属性: 3条，圣器波动 1.2~1.5（linearGrowth无波动）
    -- 圣性属性: 福缘+21（floor(10×2.1×1.0)=21）
    dizun_saint_ring = {
        name = "帝尊圣戒",
        desc = "帝尊之位，以此戒为证，天下福缘汇聚于此。",
        slot = "ring1",
        icon = "image/icon_dizun_saint_ring_20260523093147.png",
        quality = "red",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 132.3 },  -- ring1 BASE=3 × TIER_MULT[T10]=21.0 × qualityMult=2.1 = 132.3
        subStats = {
            { stat = "wisdom",       name = "悟性", value = 21 },  -- linearGrowth: floor(10×2.1)=21
            { stat = "constitution", name = "根骨", value = 21 },  -- linearGrowth: floor(10×2.1)=21
            { stat = "physique",     name = "体魄", value = 21 },  -- linearGrowth: floor(10×2.1)=21
        },
        -- 圣性属性：福缘，打造时确认（非随机）
        saintStat = { stat = "fortune", name = "福缘", value = 21, confirmed = true },
    },

    -- 道藏圣甲（铸剑地炉打造）：T10 红/圣器 护甲
    -- 主属性: 4 × 21.0(T10) × 2.1(圣器) = 176.4
    -- 副属性: 3条，圣器波动 1.2~1.5
    -- 圣性属性: 体魄+21（floor(10×2.1×1.0)=21）
    daozang_saint_armor = {
        name = "道藏圣衣",
        desc = "藏真玄衣与泽渊仙铠熔铸相融，凝就护体圣衣，道藏千卷精华尽聚于此。",
        slot = "armor",
        icon = "image/icon_daozang_saint_armor_20260524014620.png",
        quality = "red",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { def = 176.4 },  -- 4 × 21.0 × 2.1 = 176.4
        subStats = {
            { stat = "physique",  name = "体魄",     value = 21 },    -- linearGrowth: floor(10×2.1)=21
            { stat = "maxHp",     name = "生命值",   value = 126.0 }, -- 6 × 21.0 = 126.0
            { stat = "critDmg",   name = "暴击伤害", value = 0.315 }, -- 0.05 × 3.0 × 2.1 = 0.315
        },
        -- 随机灵性属性（锻造时生成）
        hasSpiritStat = true,
        specialEffect = {
            type = "hp_regen_percent",
            name = "泽渊生息",
            desc = "每秒恢复2%最大生命值，生命满时停止恢复",
            regenPercent = 0.02,
            stopWhenFull = true,
        },
    },

    -- 深渊圣氅（铸剑地炉打造）：T10 红/圣器 披风
    -- 主属性: 0.02 × 8.0(PCT_T10) × 2.1(圣器) = 0.336
    -- 副属性: 3条，圣器波动 1.2~1.5
    -- 圣性属性: 根骨+21（floor(10×2.1×1.0)=21）
    saint_cape_ch5 = {
        name = "深渊圣氅",
        desc = "以深渊之力与圣器精华合铸，气势如虹，穿此圣氅者百邪莫侵。",
        slot = "cape",
        icon = "image/icon_saint_cape_ch5_20260524014625.png",
        quality = "red",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { dmgReduce = 0.336 },  -- 0.02 × 8.0 × 2.1 = 0.336
        subStats = {
            { stat = "def",      name = "防御力",   value = 31.5 },  -- 1.5 × 21.0 = 31.5
            { stat = "critDmg",  name = "暴击伤害", value = 0.315 }, -- 0.05 × 3.0 × 2.1 = 0.315
            { stat = "wisdom",   name = "悟性",     value = 21 },    -- linearGrowth: floor(10×2.1)=21
        },
        -- 灵性属性：打造时随机生成1条
        hasSpiritStat = true,
        specialEffect = {
            type = "yuanjia",
            name = "渊甲护身",
            desc = "受到伤害后，若当前生命低于50%，获得12%减伤，持续4秒，冷却8秒",
            lowHpThreshold = 0.50,
            dmgReduce = 0.12,
            duration = 4,
            cooldown = 8,
        },
    },

    -- 解封古剑·诛仙（铸剑地炉打造）：T10 红/圣器 武器
    -- 源自 fengyin_zhuxian_ch5，解封后焕发圣威
    -- 主属性: 5 × 21.0(T10) × 2.1(圣器) = 220.5
    -- 圣性属性: 随机（由 LootSystem.GenerateSaintStat 生成）
    jiefeng_zhuxian_ch5 = {
        name = "解封古剑·诛仙",
        desc = "封印尽去，诛天之意彻底绽放，千里之外斩灵魂于无形。",
        slot = "weapon",
        icon = "image/icon_fengyin_zhuxian_ch5_20260518083648.png",
        quality = "red",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 220.5 },  -- 5 × 21.0 × 2.1 = 220.5
        subStats = {
            { stat = "critDmg", name = "暴击伤害", value = 0.4375 }, -- 封印版0.375 × (2.1/1.8) = 0.4375
            { stat = "critDmg", name = "暴击伤害", value = 0.4375 }, -- 封印版0.375 × (2.1/1.8) = 0.4375
            { stat = "atk",     name = "攻击力",   value = 22.75 },  -- 封印版19.5 × (2.1/1.8) = 22.75
        },
        -- 圣性属性（灵性升级）：有圣性则无灵性
        hasSaintStat = true,
        specialEffect = {
            type = "zhuxian",
            name = "诛仙·圣威",
            desc = "暴击时，追加一次15%攻击力的伤害（可暴击）",
            damagePercent = 0.15,
            canCrit = true,
            cooldown = 1.0,
        },
    },

    -- 解封古剑·陷仙（铸剑地炉打造）：T10 红/圣器 武器
    jiefeng_xianxian_ch5 = {
        name = "解封古剑·陷仙",
        desc = "封印尽去，陷地之力汹涌而出，万物沉于无尽深渊。",
        slot = "weapon",
        icon = "image/icon_fengyin_xianxian_ch5_20260518085543.png",
        quality = "red",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 220.5 },
        subStats = {
            { stat = "physique",  name = "体魄",   value = 21 },    -- linearGrowth: floor(10×2.1)=21
            { stat = "maxHp",     name = "生命值", value = 91 },    -- 封印版78 × (2.1/1.8) ≈ 91
            { stat = "critRate",  name = "暴击率", value = 0.0875 }, -- 封印版0.075 × (2.1/1.8) = 0.0875
        },
        -- 圣性属性（灵性升级）：有圣性则无灵性
        hasSaintStat = true,
        specialEffect = {
            type = "xianxian",
            name = "陷仙·圣威",
            desc = "生命>50%时暴击伤害+50%；生命≤50%时每秒恢复2%最大生命",
            highHpThreshold = 0.50,
            critDmgBonus = 0.50,
            lowHpRegenPercent = 0.02,
        },
    },

    -- 解封古剑·戮仙（铸剑地炉打造）：T10 红/圣器 武器
    jiefeng_luxian_ch5 = {
        name = "解封古剑·戮仙",
        desc = "封印尽去，戮灵之威席卷而出，百鬼匿迹，万灵颤栗。",
        slot = "weapon",
        icon = "image/icon_fengyin_luxian_ch5_20260518083709.png",
        quality = "red",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 220.5 },
        subStats = {
            { stat = "constitution", name = "根骨",     value = 21 },    -- linearGrowth: floor(10×2.1)=21
            { stat = "heavyHit",     name = "重击伤害", value = 121 },   -- 封印版104 × (2.1/1.8) ≈ 121
            { stat = "atk",          name = "攻击力",   value = 22.75 }, -- 封印版19.5 × (2.1/1.8) = 22.75
        },
        -- 圣性属性（灵性升级）：有圣性则无灵性
        hasSaintStat = true,
        specialEffect = {
            type = "luxian",
            name = "戮仙·圣威",
            desc = "普攻时有10%概率发动连击，连击可触发普攻特效",
            procChance = 0.10,
            cooldown = 1.0,
        },
    },

    -- 解封古剑·绝仙（铸剑地炉打造）：T10 红/圣器 武器
    jiefeng_juexian_ch5 = {
        name = "解封古剑·绝仙",
        desc = "封印尽去，绝世之锋重临，一剑在手，可断天地，可诛神灵。",
        slot = "weapon",
        icon = "image/icon_fengyin_juexian_ch5_20260518083649.png",
        quality = "red",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 220.5 },
        subStats = {
            { stat = "killHeal", name = "击杀回血", value = 45.5 },  -- 封印版39 × (2.1/1.8) ≈ 45.5
            { stat = "atk",      name = "攻击力",   value = 22.75 }, -- 封印版19.5 × (2.1/1.8) = 22.75
            { stat = "atk",      name = "攻击力",   value = 22.75 }, -- 封印版19.5 × (2.1/1.8) = 22.75
        },
        -- 圣性属性（灵性升级）：有圣性则无灵性
        hasSaintStat = true,
        specialEffect = {
            type = "juexian",
            name = "绝仙·圣威",
            desc = "每次攻击获得1层绝命，每层攻击+3%，最多5层，持续4秒",
            stackPercent = 0.03,
            maxStacks = 5,
            duration = 4.0,
        },
    },

    -- #9 玄枢灵披（极阴阵灵掉落）：T8 青/灵器 披风
    -- 主属性: 0.02 × 6.0(PCT_T8) × 1.8(灵器) = 0.216
    -- 副属性: 灵器3条, 中值×1.0
    -- 灵性属性: 福缘+7（floor(8×1.8×0.5)=7）
    xuanshu_cape_ch4 = {
        name = "玄枢灵披",
        slot = "cape",
        icon = "icon_xuanshu_cape_ch4.png",
        quality = "cyan",
        tier = 8,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { dmgReduce = 0.216 },
        subStats = {
            { stat = "def", name = "防御力", value = 10.8 },       -- 1.2 × 9.0(SUB_T8) = 10.8
            { stat = "maxHp", name = "生命值", value = 54.0 },    -- 6 × 9.0(SUB_T8) = 54.0
            { stat = "hpRegen", name = "生命恢复", value = 4.5 }, -- 0.5 × 9.0(SUB_T8) = 4.5
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 7 }, -- floor(8×1.8×0.5) = 7
    },

    -- #10 阴阳履（极阴/极阳阵灵掉落）：T8 青/灵器 鞋子
    -- 主属性: 0.03 × 6.0(PCT_T8) × 1.8(灵器) = 0.324
    -- 副属性: 灵器3条, 中值×1.0
    -- 特效: 与踏云靴一致（闪避10%伤害）
    yinyang_boots_ch4 = {
        name = "阴阳履",
        slot = "boots",
        icon = "icon_yinyang_boots_ch4.png",
        quality = "cyan",
        tier = 8,
        sellPrice = 3,
        sellCurrency = "lingYun",
        mainStat = { speed = 0.324 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 13.5 },       -- 1.5 × 9.0(SUB_T8) = 13.5
            { stat = "critRate", name = "暴击率", value = 0.048 }, -- 0.01 × 4.8(PCT_SUB_T8) = 0.048
            { stat = "maxHp", name = "生命值", value = 54.0 },    -- 6 × 9.0(SUB_T8) = 54.0
        },
        specialEffect = {
            type = "evade_damage",
            name = "阴阳步",
            evadeChance = 0.10,  -- 10%概率完全闪避伤害
        },
    },

    -- #11 彩虹锤（极阳阵灵掉落）：T9 青/灵器 武器
    -- 主属性: 5 × 17.0(T9) × 1.8(灵器) = 153.0
    -- 副属性: 灵器3条, 中值×1.0; SUB_T9=11.0
    -- 灵性属性: 福缘+8（floor(9×1.8×0.5)=8）
    tiantianquan_weapon_ch4 = {
        name = "彩虹锤",
        slot = "weapon",
        icon = "icon_tiantianquan_weapon_ch4.png",
        quality = "cyan",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { atk = 153.0 },
        subStats = {
            { stat = "killHeal", name = "击杀回血", value = 33 },    -- 3 × 11.0(SUB_T9) = 33
            { stat = "hpRegen", name = "生命回复", value = 5.5 },   -- 0.5 × 11.0(SUB_T9) = 5.5
            { stat = "fortune", name = "福缘", value = 16 },        -- linearGrowth: floor(9 × 1.8) = 16
        },
        spiritStat = { stat = "fortune", name = "福缘", value = 8 }, -- floor(9×1.8×0.5) = 8
        desc = "色彩斑斓的棒棒糖造型武器，不知道是哪位仙人用来哄徒弟的。甜得齁嗓子，打得够疼。",
    },

    -- #极龙盔（四龙BOSS 1%共享掉落）：T9 青/灵器 头盔
    -- 主属性: 20(头盔maxHp基数) × 17.0(T9) × 1.8(灵器) = 612.0
    -- 副属性: 灵器3条, 中值×1.0
    -- 灵性属性: critDmg = 0.05 × 6.0(PCT_SUB_T9) × 0.5 = 0.15
    jilong_helmet_ch4 = {
        name = "极龙盔",
        slot = "helmet",
        icon = "icon_jilong_helmet_ch4.png",
        quality = "cyan",
        tier = 9,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { maxHp = 612.0 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 16.5 },          -- 1.5 × 11.0(SUB_T9) = 16.5
            { stat = "critRate", name = "暴击率", value = 0.06 },     -- 0.01 × 6.0(PCT_SUB_T9) = 0.06
            { stat = "def", name = "防御力", value = 13.2 },          -- 1.2 × 11.0(SUB_T9) = 13.2
        },
        spiritStat = { stat = "critDmg", name = "暴击伤害", value = 0.15 }, -- 0.05 × 6.0(PCT_SUB_T9) × 0.5 = 0.15
        desc = "四方龙神之力凝聚而成的战盔，龙威加身，百邪不侵。",
    },

    -- 真龙盔（龙神熔炉打造）：T10 青/灵器 头盔
    -- 属性类型沿用极龙盔，数值按 T10 青色标准提升。
    zhenlong_helmet_ch4 = {
        name = "真龙盔",
        slot = "helmet",
        icon = "icon_jilong_helmet_ch4.png",
        quality = "cyan",
        tier = 10,
        sellPrice = 5,
        sellCurrency = "lingYun",
        mainStat = { maxHp = 756 },
        subStats = {
            { stat = "atk", name = "攻击力", value = 19.5 },
            { stat = "critRate", name = "暴击率", value = 0.075 },
            { stat = "def", name = "防御力", value = 15.6 },
        },
        spiritStat = { stat = "critDmg", name = "暴击伤害", value = 0.1875 },
        fixedSubStats = true,
        desc = "极龙盔经龙极令与帝尊肆戒再度淬炼，龙威凝实，化为真龙之冠。",
    },
}
