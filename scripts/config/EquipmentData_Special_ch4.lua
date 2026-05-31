-- EquipmentData_Special_ch4.lua
-- 特殊装备：龙神圣器 + 第四章·八卦海 + 挑战专属 + 法宝图鉴

return {
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
    -- 龙魂令（T10红色，第五章铸剑地炉升级自龙极令）
    fabao_longhunling = {
        name = "龙魂令", slot = "exclusive", quality = "red", tier = 10,
        isFabaoCollection = true, fabaoTemplateId = "fabao_longhunling", fabaoTier = 10,
    },
    -- 第五章·T10 灵器级法宝（Lv.8）
    fabao_xuehaitu_t10 = {
        name = "血海图Lv.8", slot = "exclusive", quality = "cyan", tier = 10,
        isFabaoCollection = true, fabaoTemplateId = "fabao_xuehaitu", fabaoTier = 10,
    },
    fabao_haoqiyin_t10 = {
        name = "浩气印Lv.8", slot = "exclusive", quality = "cyan", tier = 10,
        isFabaoCollection = true, fabaoTemplateId = "fabao_haoqiyin", fabaoTier = 10,
    },
    fabao_qingyunta_t10 = {
        name = "青云塔Lv.8", slot = "exclusive", quality = "cyan", tier = 10,
        isFabaoCollection = true, fabaoTemplateId = "fabao_qingyunta", fabaoTier = 10,
    },
    fabao_fengmopan_t10 = {
        name = "封魔盘Lv.8", slot = "exclusive", quality = "cyan", tier = 10,
        isFabaoCollection = true, fabaoTemplateId = "fabao_fengmopan", fabaoTier = 10,
    },

}
