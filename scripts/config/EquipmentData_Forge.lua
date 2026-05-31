-- EquipmentData_Forge.lua
-- 套装/锻造/法宝数据子模块
-- 由 EquipmentData.lua facade 加载

---@param EquipmentData table
return function(EquipmentData)

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
            [7] = "icon_fabao_xuehaitu_lv3.png",  -- T7-T10
            [8] = "icon_fabao_xuehaitu_lv3.png",
            [9] = "icon_fabao_xuehaitu_lv3.png",
            [10] = "icon_fabao_xuehaitu_lv3.png",
        },
        sellPriceByTier = {
            [3] = 300,  [4] = 400,  [5] = 500,
            [6] = 600,  [7] = 700,  [8] = 800, [9] = 900, [10] = 1200,
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
            [10] = "icon_haoqi_seal_lv3.png",
        },
        sellPriceByTier = {
            [3] = 300,  [4] = 400,  [5] = 500,
            [6] = 600,  [7] = 700,  [8] = 800, [9] = 900, [10] = 1200,
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
            [10] = "icon_fabao_qingyunta_lv3.png",
        },
        sellPriceByTier = {
            [3] = 300,  [4] = 400,  [5] = 500,
            [6] = 600,  [7] = 700,  [8] = 800, [9] = 900, [10] = 1200,
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
            [10] = "icon_fabao_fengmopan_lv3.png",
        },
        sellPriceByTier = {
            [3] = 300,  [4] = 400,  [5] = 500,
            [6] = 600,  [7] = 700,  [8] = 800, [9] = 900, [10] = 1200,
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
    -- 龙魂令（攻击型法宝，第五章铸剑地炉升级自龙极令，T10 圣器，standard 公式）
    -- 主属性: 2 × TIER_MULT(T10) × qualityMult(2.1) = 2 × 21.0 × 2.1 / 21.0 = 42
    -- （standard 公式实际 = base × tier × qualityMult = 2 × 10 × 2.1 = 42）
    fabao_longhunling = {
        name      = "龙魂令",
        slot      = "exclusive",
        mainStatType = "atk",
        mainStatFormula = "standard",
        mainStatBase = 2,                 -- 攻击法宝 base=2，T10圣器: 2×10×2.1=42
        skillId   = "dragon_breath",        -- 复用龙极令龙息技能
        iconByTier = {
            [10] = "icon_fabao_longjiling.png",  -- 复用图标（后续可替换）
        },
        sellPriceByTier = {
            [10] = 2000,
        },
        forgeType = "sword_forge_longhun",
    },
}

-- ============================================================================
-- 铸剑地炉打造配方（第五章，需在铸剑炉NPC处操作）
-- ============================================================================
EquipmentData.SWORD_FORGE_COSTS = {
    -- 配方1：帝尊圣戒（帝尊壹~伍戒合五为一，无普通材料）
    dizun_saint_ring = {
        outputId    = "dizun_saint_ring",
        label       = "帝尊圣戒",
        desc        = "五戒归一，福缘汇聚，帝尊之位以此戒为证。",
        gold        = 1000000,
        fromBagList = {
            { equipId = "dizun_ring_ch1"  },   -- 帝尊壹戒
            { equipId = "dizun_ring_ch2"  },   -- 帝尊贰戒
            { equipId = "dizun_ring_ch3"  },   -- 帝尊叁戒
            { equipId = "silong_ring_ch4" },   -- 帝尊肆戒
            { equipId = "dizun_ring_ch5"  },   -- 帝尊伍戒
        },
    },
    -- 配方2：道藏圣衣（藏真玄衣 + 泽渊仙铠 + 帝尊圣戒 + 仙人精血×4）
    daozang_saint_armor = {
        outputId    = "daozang_saint_armor",
        label       = "道藏圣衣",
        desc        = "藏真玄衣与泽渊仙铠熔铸相融，以帝尊圣戒为媒，凝就道藏圣衣。",
        gold        = 5000000,
        fromBagList = {
            { equipId = "cangzhen_armor_ch5" },  -- 藏真玄衣
            { equipId = "zeyuan_armor_ch4"   },  -- 泽渊仙铠
            { equipId = "dizun_saint_ring"   },  -- 帝尊圣戒（消耗）
        },
        materials = {
            { id = "immortal_essence_blood", count = 4 },
        },
    },
    -- 配方3：深渊圣氅（噬渊魔氅 + 帝尊圣戒 + 天渊灵披 + 仙人精血×4）
    saint_cape_ch5 = {
        outputId    = "saint_cape_ch5",
        label       = "深渊圣氅",
        desc        = "噬渊魔氅与天渊灵披合而为一，以帝尊圣戒为媒，炼就深渊圣氅。",
        gold        = 5000000,
        fromBagList = {
            { equipId = "shiyuan_cape_ch5" },    -- 噬渊魔氅
            { equipId = "dizun_saint_ring"  },   -- 帝尊圣戒（消耗）
            { equipId = "lingqi_cape_ch5"   },   -- 天渊灵披
        },
        materials = {
            { id = "immortal_essence_blood", count = 4 },
        },
    },
    -- 配方4：龙魂令（任意龙极令×1 + 仙人精血×1 + 太虚剑令×1000，免费）
    fabao_longhunling = {
        outputId  = "fabao_longhunling",
        label     = "龙魂令",
        desc      = "将龙极令与千枚太虚剑令融合，以仙人精血为引，铸就承载龙魂之法宝。",
        gold      = 0,
        fromBag   = { equipId = "fabao_longjiling" },  -- 龙极令（消耗）
        materials = {
            { id = "immortal_essence_blood", count = 1    },
            { id = "taixu_jianling",         count = 1000 },
        },
    },
    -- 配方5-1：一重解封·诛仙（封印古剑·诛仙 + 帝尊圣戒 + 蚀骨龙牙×4 + 仙人精血×4）
    jiefeng_zhuxian_ch5 = {
        outputId  = "jiefeng_zhuxian_ch5",
        label     = "解封古剑·诛仙",
        desc      = "以帝尊圣戒之力解开封印，令诛仙古剑重焕圣威。",
        gold      = 10000000,
        fromBag   = { equipId = "fengyin_zhuxian_ch5" },  -- 封印古剑·诛仙（消耗）
        fromBag2  = { equipId = "dizun_saint_ring"    },  -- 帝尊圣戒（消耗）
        materials = {
            { id = "immortal_essence_blood", count = 4 },
            { id = "dragon_scale_sand",      count = 4 },  -- 蚀骨龙牙
        },
    },
    -- 配方5-2：一重解封·陷仙（封印古剑·陷仙 + 帝尊圣戒 + 封霜龙鳞×4 + 仙人精血×4）
    jiefeng_xianxian_ch5 = {
        outputId  = "jiefeng_xianxian_ch5",
        label     = "解封古剑·陷仙",
        desc      = "以帝尊圣戒之力解开封印，令陷仙古剑重焕圣威。",
        gold      = 10000000,
        fromBag   = { equipId = "fengyin_xianxian_ch5" },
        fromBag2  = { equipId = "dizun_saint_ring"     },
        materials = {
            { id = "immortal_essence_blood", count = 4 },
            { id = "dragon_scale_ice",       count = 4 },  -- 封霜龙鳞
        },
    },
    -- 配方5-3：一重解封·戮仙（封印古剑·戮仙 + 帝尊圣戒 + 焚天龙焰×4 + 仙人精血×4）
    jiefeng_luxian_ch5 = {
        outputId  = "jiefeng_luxian_ch5",
        label     = "解封古剑·戮仙",
        desc      = "以帝尊圣戒之力解开封印，令戮仙古剑重焕圣威。",
        gold      = 10000000,
        fromBag   = { equipId = "fengyin_luxian_ch5" },
        fromBag2  = { equipId = "dizun_saint_ring"   },
        materials = {
            { id = "immortal_essence_blood", count = 4 },
            { id = "dragon_scale_fire",      count = 4 },  -- 焚天龙焰
        },
    },
    -- 配方5-4：一重解封·绝仙（封印古剑·绝仙 + 帝尊圣戒 + 渊蛟龙骨×4 + 仙人精血×4）
    jiefeng_juexian_ch5 = {
        outputId  = "jiefeng_juexian_ch5",
        label     = "解封古剑·绝仙",
        desc      = "以帝尊圣戒之力解开封印，令绝仙古剑重焕圣威。",
        gold      = 10000000,
        fromBag   = { equipId = "fengyin_juexian_ch5" },
        fromBag2  = { equipId = "dizun_saint_ring"    },
        materials = {
            { id = "immortal_essence_blood", count = 4 },
            { id = "dragon_scale_abyss",     count = 4 },  -- 渊蛟龙骨
        },
    },
}

-- 铸剑地炉配方显示顺序（上排：解封古剑；下排：圣器；最后：灵器龙魂令）
EquipmentData.SWORD_FORGE_ORDER = {
    "jiefeng_zhuxian_ch5",
    "jiefeng_xianxian_ch5",
    "jiefeng_luxian_ch5",
    "jiefeng_juexian_ch5",
    "dizun_saint_ring",
    "daozang_saint_armor",
    "saint_cape_ch5",
    "fabao_longhunling",
}


end
