-- ============================================================================
-- MonsterTypes_ch4.lua - 第四章·八卦海
-- ============================================================================
-- 八卦阵怪物（Lv.66~99）：太虚宗上古弟子 + 阵力孕育之物
-- 四方龙族皇级BOSS（Lv.100）：封霜应龙 / 堕渊蛟龙 / 焚天蜃龙 / 蚀骨螭龙
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)

local XIANJIE_SET_IDS = { "xuesha", "qingyun", "fengmo", "haoqi" }  -- 仙劫战场四套装

-- =====================================================================
-- 第四章·八卦阵 种族修正（新增）
-- =====================================================================
-- 太虚宗邪修弟子（人族变种）
M.RaceModifiers.water_puppet   = { hp = 1.1, atk = 0.9, def = 1.0, speed = 0.8 }  -- 水傀：偏肉慢速
M.RaceModifiers.rock_golem     = { hp = 1.3, atk = 0.8, def = 1.3, speed = 0.7 }  -- 岩俑：高防低速
M.RaceModifiers.thunder_spirit = { hp = 0.7, atk = 1.3, def = 0.7, speed = 1.3 }  -- 雷魂：玻璃高攻
M.RaceModifiers.wind_phantom   = { hp = 0.8, atk = 1.1, def = 0.8, speed = 1.4 }  -- 残影：高速脆皮
M.RaceModifiers.fire_thrall    = { hp = 0.9, atk = 1.2, def = 0.8, speed = 1.1 }  -- 焦骨：偏攻
M.RaceModifiers.earth_golem    = { hp = 1.3, atk = 0.9, def = 1.2, speed = 0.8 }  -- 土俑：高防
M.RaceModifiers.swamp_gu       = { hp = 0.8, atk = 1.1, def = 0.9, speed = 1.2 }  -- 蛊毒：偏攻快速
M.RaceModifiers.stone_pillar   = { hp = 1.5, atk = 1.0, def = 1.4, speed = 0.0 }  -- 石柱：超肉不动
-- 太虚邪修BOSS（人族修士）
M.RaceModifiers.taixu_disciple = { hp = 1.1, atk = 1.1, def = 1.0, speed = 1.0 }  -- 太虚弟子：均衡偏攻

-- =====================================================================
-- ①坎·沉渊阵（水）— 7普通 + 1BOSS    Lv.66~70
-- 溺毙于阵中的外门弟子化为水傀，沈渊衣无意识间制造
-- =====================================================================
M.Types.kan_disciple = {
    name = "溺潮傀",
    icon = "💧",
    portrait = "Textures/monster_kan_disciple.png",
    zone = "ch4_kan",
    category = "normal",
    race = "water_puppet",
    levelRange = {66, 69},
    realm = "yuanying_3",  -- 元婴后期
    bodyColor = {60, 120, 180, 255},
    dropTable = {
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.05, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.kan_boss = {
    name = "沈渊衣",
    icon = "🌊",
    portrait = "Textures/monster_kan_boss.png",
    zone = "ch4_kan",
    category = "boss",
    race = "taixu_disciple",
    level = 70,
    realm = "huashen_1",  -- 化神初期
    bodyColor = {40, 100, 170, 255},
    clawColor = {80, 160, 220},
    skillTextColor = {100, 180, 240, 255},
    warningColorOverride = {60, 140, 200, 120},
    phases = 2,
    skills = { "kan_tidal_vortex", "kan_water_blade" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.3, speedMult = 1.2,
          announce = "沈渊衣周身水雾暴涨！",
          addSkill = "kan_whirlpool_prison" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 0.02, type = "equipment", equipId = "chengyuan_helmet_ch4" },  -- 沉渊冥冠2%
        { chance = 1.0, type = "lingYun", amount = {4, 6} },
        { chance = 0.12, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.06, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
        { chance = 0.01, type = "consumable", consumableId = "yuanying_fruit" },  -- 元婴果1%（元婴级BOSS）
        { chance = 0.001, type = "consumable", consumableId = "bagua_fragment_kan" },  -- 神器碎片·坎 0.1%
    },
}

-- =====================================================================
-- ②艮·止岩阵（山）— 3普通 + 2精英 + 1BOSS    Lv.71~75
-- 岩不动身上剥落的石甲碎片自行成形
-- 装备里程碑：T8首次出现(Lv.71+)  ← 沈渊衣Lv.71也在此窗口
-- =====================================================================
M.Types.gen_disciple = {
    name = "裂岩俑",
    icon = "🪨",
    portrait = "Textures/monster_gen_disciple.png",
    zone = "ch4_gen",
    category = "normal",
    race = "rock_golem",
    levelRange = {71, 72},
    realm = "huashen_1",  -- 化神初期
    bodyColor = {140, 120, 80, 255},
    dropTable = {
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.06, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.gen_elite = {
    name = "山魄将",
    icon = "⛰️",
    portrait = "Textures/monster_gen_elite.png",
    zone = "ch4_gen",
    category = "elite",
    race = "rock_golem",
    level = 74,
    realm = "huashen_1",  -- 化神初期
    bodyColor = {160, 130, 70, 255},
    skills = { "ground_pound" },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "orange" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（精英共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.gen_boss = {
    name = "岩不动",
    icon = "🗿",
    portrait = "Textures/monster_gen_boss.png",
    zone = "ch4_gen",
    category = "boss",
    race = "taixu_disciple",
    level = 75,
    realm = "huashen_2",  -- 化神中期
    bodyColor = {120, 100, 60, 255},
    clawColor = {180, 150, 80},
    skillTextColor = {200, 170, 80, 255},
    warningColorOverride = {160, 130, 60, 120},
    phases = 2,
    skills = { "gen_rock_slam", "gen_stone_wall" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.0,
          announce = "岩不动身化巨石，不动如山！",
          addSkill = "gen_avalanche" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 0.03, type = "equipment", equipId = "zhiyan_boots_ch4" },      -- 止岩重靴3%
        { chance = 1.0, type = "lingYun", amount = {4, 6} },
        { chance = 0.15, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.08, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
        { chance = 0.002, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹0.2%
        { chance = 0.001, type = "consumable", consumableId = "bagua_fragment_gen" },  -- 神器碎片·艮 0.1%
    },
}

-- =====================================================================
-- ③震·惊雷阵（雷）— 7普通 + 1BOSS    Lv.76~80
-- 被雷阵反噬的剑修残魂，攻高血薄
-- 装备里程碑：T8橙解锁(Lv.76+)
-- =====================================================================
M.Types.zhen_disciple = {
    name = "游雷魂",
    icon = "⚡",
    portrait = "Textures/monster_zhen_disciple.png",
    zone = "ch4_zhen",
    category = "normal",
    race = "thunder_spirit",
    levelRange = {76, 79},
    realm = "huashen_2",  -- 化神中期
    bodyColor = {180, 180, 40, 255},
    dropTable = {
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.07, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.zhen_boss = {
    name = "雷惊蛰",
    icon = "🌩️",
    portrait = "Textures/monster_zhen_boss.png",
    zone = "ch4_zhen",
    category = "king_boss",
    race = "taixu_disciple",
    level = 80,
    realm = "huashen_3",  -- 化神后期
    bodyColor = {200, 200, 30, 255},
    clawColor = {255, 255, 80},
    skillTextColor = {255, 240, 60, 255},
    warningColorOverride = {220, 220, 40, 120},
    phases = 2,
    skills = { "zhen_thunder_pierce", "zhen_thunder_roar" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.3,
          announce = "雷惊蛰剑意暴走，雷鸣九天！",
          triggerSkill = "zhen_divine_thunder" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 0.02, type = "equipment", equipId = "leiming_necklace_ch4" },  -- 雷鸣玉坠2%
        { chance = 1.0, type = "lingYun", amount = {5, 8} },
        { chance = 0.10, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
        { chance = 0.005, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹0.5%（化神级王者BOSS）
        { chance = 0.001, type = "consumable", consumableId = "bagua_fragment_zhen" },  -- 神器碎片·震 0.1%
    },
}

-- =====================================================================
-- ④巽·风旋阵（风）— 3普通 + 2精英 + 1BOSS    Lv.81~85
-- 风无痕万年逃亡留下的残影，获得了自我意识
-- =====================================================================
M.Types.xun_disciple = {
    name = "残影",
    icon = "💨",
    portrait = "Textures/monster_xun_disciple.png",
    zone = "ch4_xun",
    category = "normal",
    race = "wind_phantom",
    levelRange = {81, 82},
    realm = "huashen_3",  -- 化神后期
    bodyColor = {160, 200, 180, 255},
    dropTable = {
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.xun_elite = {
    name = "风蚀护法",
    icon = "🌪️",
    portrait = "Textures/monster_xun_elite.png",
    zone = "ch4_xun",
    category = "elite",
    race = "wind_phantom",
    level = 84,
    realm = "huashen_3",  -- 化神后期
    bodyColor = {130, 180, 160, 255},
    skills = { "whirlwind" },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "orange" },
        { chance = 0.10, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.06, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（精英共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.xun_boss = {
    name = "风无痕",
    icon = "🌀",
    portrait = "Textures/monster_xun_boss.png",
    zone = "ch4_xun",
    category = "king_boss",
    race = "taixu_disciple",
    level = 85,
    realm = "heti_1",  -- 合体初期
    bodyColor = {100, 170, 150, 255},
    clawColor = {140, 210, 190},
    skillTextColor = {160, 220, 200, 255},
    warningColorOverride = {120, 190, 170, 120},
    phases = 2,
    skills = { "xun_wind_slash", "xun_phantom_dash" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.4,
          announce = "风无痕残影分裂，无迹可寻！",
          triggerSkill = "xun_phantom_clone" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 0.02, type = "equipment", equipId = "fenghen_ring_ch4" },      -- 风痕指环2%
        { chance = 1.0, type = "lingYun", amount = {6, 10} },
        { chance = 0.12, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
        { chance = 0.005, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹0.5%（化神级王者BOSS）
        { chance = 0.001, type = "consumable", consumableId = "bagua_fragment_xun" },  -- 神器碎片·巽 0.1%
    },
}

-- =====================================================================
-- ⑤离·烈焰阵（火）— 7普通 + 1BOSS    Lv.86~90
-- 炎若晦炼丹失败的副产物，燃烧的骨架
-- 装备里程碑：T9首次出现(Lv.86+)
-- =====================================================================
M.Types.li_disciple = {
    name = "焦骨炼奴",
    icon = "🔥",
    portrait = "Textures/monster_li_disciple.png",
    zone = "ch4_li",
    category = "normal",
    race = "fire_thrall",
    levelRange = {86, 89},
    realm = "heti_1",  -- 合体初期
    bodyColor = {220, 100, 30, 255},
    dropTable = {
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.09, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.li_boss = {
    name = "炎若晦",
    icon = "☀️",
    portrait = "Textures/monster_li_boss.png",
    zone = "ch4_li",
    category = "king_boss",
    race = "taixu_disciple",
    level = 90,
    realm = "heti_2",  -- 合体中期
    bodyColor = {240, 80, 20, 255},
    clawColor = {255, 120, 40},
    skillTextColor = {255, 140, 60, 255},
    warningColorOverride = {240, 100, 30, 120},
    phases = 2,
    skills = { "li_karma_fire", "li_inferno_burst" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.2,
          announce = "炎若晦引火焚身，烈焰焚天！",
          triggerSkill = "li_heaven_fire" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 0.02, type = "equipment", equipId = "yanxin_belt_ch4" },       -- 焰心腰环2%
        { chance = 1.0, type = "lingYun", amount = {6, 10} },
        { chance = 0.15, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "consumable", consumableId = "book_atk_3" },    -- 高级攻击书3%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
        { chance = 0.01, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹1%（合体期王者BOSS）
        { chance = 0.001, type = "consumable", consumableId = "bagua_fragment_li" },  -- 神器碎片·离 0.1%
    },
}

-- =====================================================================
-- ⑥坤·厚土阵（地）— 3普通 + 2精英 + 1BOSS    Lv.91~93
-- 厚德生试图以土封印阵力，反被阵力反噬
-- 装备里程碑：T9橙解锁(Lv.91+)
-- =====================================================================
M.Types.kun_disciple = {
    name = "裂土行尸",
    icon = "🟤",
    portrait = "Textures/monster_kun_disciple.png",
    zone = "ch4_kun",
    category = "normal",
    race = "earth_golem",
    levelRange = {91, 92},
    realm = "heti_2",  -- 合体中期
    bodyColor = {130, 100, 50, 255},
    dropTable = {
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.10, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.kun_elite = {
    name = "厚土阵灵",
    icon = "🏔️",
    portrait = "Textures/monster_kun_elite.png",
    zone = "ch4_kun",
    category = "elite",
    race = "earth_golem",
    level = 92,
    realm = "heti_2",  -- 合体中期
    bodyColor = {150, 120, 60, 255},
    skills = { "ground_pound" },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "orange" },
        { chance = 0.12, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.08, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（精英共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.kun_boss = {
    name = "厚德生",
    icon = "🌍",
    portrait = "Textures/monster_kun_boss.png",
    zone = "ch4_kun",
    category = "king_boss",
    race = "taixu_disciple",
    level = 93,
    realm = "heti_2",  -- 合体中期
    bodyColor = {110, 90, 40, 255},
    clawColor = {160, 130, 60},
    skillTextColor = {180, 150, 70, 255},
    warningColorOverride = {140, 110, 50, 120},
    phases = 2,
    skills = { "kun_earth_surge", "kun_earth_sweep" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.0,
          announce = "厚德生厚土崩裂，大地震怒！",
          triggerSkill = "kun_earth_collapse" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 0.02, type = "equipment", equipId = "houtu_shoulder_ch4" },    -- 厚土肩铠2%
        { chance = 1.0, type = "lingYun", amount = {10, 15} },
        { chance = 0.18, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "consumable", consumableId = "book_def_3" },    -- 高级防御书3%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
        { chance = 0.01, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹1%（合体期王者BOSS）
        { chance = 0.001, type = "consumable", consumableId = "bagua_fragment_kun" },  -- 神器碎片·坤 0.1%
    },
}

-- =====================================================================
-- ⑦兑·泽沼阵（泽）— 3普通 + 2精英 + 1BOSS    Lv.94~96
-- 泽归墟炼毒外溢，沼泽中孕育的毒物
-- 装备里程碑：T9青/灵器解锁(Lv.96+)
-- =====================================================================
M.Types.dui_disciple = {
    name = "蛊毒虫潮",
    icon = "🦠",
    portrait = "Textures/monster_dui_disciple.png",
    zone = "ch4_dui",
    category = "normal",
    race = "swamp_gu",
    levelRange = {94, 95},
    realm = "heti_2",  -- 合体中期
    bodyColor = {80, 140, 60, 255},
    dropTable = {
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.10, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.dui_elite = {
    name = "化毒尊",
    icon = "☠️",
    portrait = "Textures/monster_dui_elite.png",
    zone = "ch4_dui",
    category = "elite",
    race = "swamp_gu",
    level = 96,
    realm = "heti_3",  -- 合体后期
    bodyColor = {60, 120, 40, 255},
    skills = { "line_charge" },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "cyan" },
        { chance = 0.15, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（精英共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.dui_boss = {
    name = "泽归墟",
    icon = "🧪",
    portrait = "Textures/monster_dui_boss.png",
    zone = "ch4_dui",
    category = "king_boss",
    race = "taixu_disciple",
    level = 96,
    realm = "heti_3",  -- 合体后期
    bodyColor = {50, 110, 30, 255},
    clawColor = {80, 160, 50},
    skillTextColor = {100, 180, 60, 255},
    warningColorOverride = {70, 140, 40, 120},
    phases = 2,
    skills = { "dui_gu_miasma", "dui_venom_line" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "泽归墟万毒齐发，以毒入道！",
          triggerSkill = "dui_gu_devour" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "cyan" },
        { chance = 0.01, type = "equipment", equipId = "zeyuan_armor_ch4" },      -- 泽渊仙铠1%
        { chance = 1.0, type = "lingYun", amount = {10, 15} },
        { chance = 0.20, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "consumable", consumableId = "book_hp_3" },     -- 高级生命书3%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
        { chance = 0.01, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹1%（合体期王者BOSS）
        { chance = 0.001, type = "consumable", consumableId = "bagua_fragment_dui" },  -- 神器碎片·兑 0.1%
    },
}

-- =====================================================================
-- ⑧乾·天罡阵（天）— 4BOSS守卫(石柱) + 1主BOSS    Lv.97~99
-- 司空正阳以精血祭炼的阵眼锚点 + 太虚宗大师兄
-- 无 tierOnly，按等级窗口掉落 T8+T9
-- =====================================================================

-- 天罡四柱：stationary + groundSpike，类枯树守卫
M.Types.qian_pillar_e = {
    name = "天罡·青石柱",
    icon = "🪨",
    portrait = "Textures/monster_qian_pillar.png",
    zone = "ch4_qian",
    category = "boss",
    race = "stone_pillar",
    level = 97,
    realm = "heti_3",  -- 合体后期
    bodyColor = {80, 140, 100, 255},
    stationary = true,
    attackRange = 5.0,
    groundSpike = {
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {100, 160, 120, 150},
    },
    phases = 2,
    skills = {},
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "青石柱上「心正」二字骤然亮起！" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {5, 8} },
        { chance = 0.18, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.qian_pillar_s = {
    name = "天罡·赤石柱",
    icon = "🪨",
    portrait = "Textures/monster_qian_pillar.png",
    zone = "ch4_qian",
    category = "boss",
    race = "stone_pillar",
    level = 97,
    realm = "heti_3",
    bodyColor = {180, 80, 60, 255},
    stationary = true,
    attackRange = 5.0,
    groundSpike = {
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {200, 100, 80, 150},
    },
    phases = 2,
    skills = {},
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "赤石柱上「意诚」二字骤然亮起！" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {5, 8} },
        { chance = 0.18, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.qian_pillar_w = {
    name = "天罡·白石柱",
    icon = "🪨",
    portrait = "Textures/monster_qian_pillar.png",
    zone = "ch4_qian",
    category = "boss",
    race = "stone_pillar",
    level = 98,
    realm = "heti_3",
    bodyColor = {200, 200, 210, 255},
    stationary = true,
    attackRange = 5.0,
    groundSpike = {
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {220, 220, 230, 150},
    },
    phases = 2,
    skills = {},
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.2,
          announce = "白石柱上「身端」二字骤然亮起！" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {5, 8} },
        { chance = 0.18, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
    },
}

M.Types.qian_pillar_n = {
    name = "天罡·玄石柱",
    icon = "🪨",
    portrait = "Textures/monster_qian_pillar.png",
    zone = "ch4_qian",
    category = "boss",
    race = "stone_pillar",
    level = 98,
    realm = "heti_3",
    bodyColor = {40, 40, 60, 255},
    stationary = true,
    attackRange = 5.0,
    groundSpike = {
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {60, 60, 80, 150},
    },
    phases = 2,
    skills = {},
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.3,
          announce = "玄石柱上「道明」二字骤然亮起！" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {5, 8} },
        { chance = 0.18, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
    },
}

-- 司空正阳：大师兄，emperor_boss
M.Types.qian_boss = {
    name = "司空正阳",
    icon = "☯️",
    portrait = "Textures/monster_qian_boss.png",
    zone = "ch4_qian",
    category = "emperor_boss",
    race = "taixu_disciple",
    level = 99,
    realm = "heti_3",  -- 合体后期（Lv.99无法大乘）
    bodyColor = {200, 180, 140, 255},
    clawColor = {240, 220, 160},
    skillTextColor = {255, 240, 180, 255},
    warningColorOverride = {220, 200, 150, 120},
    phases = 3,
    skills = { "qian_gang_sword", "qian_taixu_palm" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          announce = "司空正阳双目通红，万年清醒终至极限！",
          addSkill = "qian_heaven_toss" },
        { threshold = 0.3, atkMult = 1.8, speedMult = 1.5, intervalMult = 0.5,
          announce = "……师尊……为何不来……",
          triggerSkill = "qian_gang_annihilation" },
    },
    tierOnly = 9,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 0.01, type = "equipment", equipId = "tiangang_cape_ch4" },     -- 天罡圣披1%
        { chance = 1.0, type = "lingYun", amount = {12, 18} },
        { chance = 0.50, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.03, type = "world_drop", pool = "sikong_books" },  -- 高级蕴灵书（共享3%，随机掉1本）
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 1.0, type = "consumable", consumableId = "taixu_token" },
        { chance = 0.02, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹2%（司空正阳）
        { chance = 0.001, type = "consumable", consumableId = "bagua_fragment_qian" },  -- 神器碎片·乾 0.1%
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },  -- 金砖0.5%
    },
}

-- =====================================================================
-- 四方龙族皇级BOSS（Lv.100·大乘初期）— 兽岛
-- =====================================================================

-- ===================== 封霜应龙（玄冰岛·西北） =====================
M.Types.dragon_ice = {
    name = "封霜应龙",
    icon = "🐉",
    portrait = "Textures/monster_dragon_ice.png",
    zone = "ch4_beast_north",
    category = "emperor_boss",
    race = "ice_dragon",
    level = 100,
    realm = "dacheng_1",
    bodyColor = {100, 160, 220, 255},
    clawColor = {140, 200, 255},
    skillTextColor = {120, 200, 255, 255},
    warningColorOverride = {100, 180, 240, 120},
    phases = 3,
    skills = { "frost_breath", "frost_crack" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.2, speedMult = 1.1,
          announce = "封霜应龙吐息凝霜，寒气侵骨！",
          addSkill = "ice_prison" },
        { threshold = 0.3, atkMult = 1.8, speedMult = 1.4, intervalMult = 0.5,
          announce = "万古玄冰，封天镇地！",
          triggerSkill = "permafrost_field" },
    },
    tierOnly = 9,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {15, 25} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "dragon_ice_books" },  -- 高级技能书（共享3%，随机掉1本）
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 0.03, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹3%（四龙神）
        { chance = 0.01, type = "consumable", consumableId = "dragon_scale_ice" },  -- 封霜龙鳞1%（圣器打造材料）
        { chance = 0.0025, type = "equipment", equipId = "silong_ring_ch4" },  -- 帝尊肆戒0.25%
        { chance = 0.004, type = "set_equipment", setIds = XIANJIE_SET_IDS },  -- 套装灵器 0.4%（四套随机一件）
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },  -- 金砖0.5%
    },
}

-- ===================== 堕渊蛟龙（幽渊岛·东北） =====================
M.Types.dragon_abyss = {
    name = "堕渊蛟龙",
    icon = "🐉",
    portrait = "Textures/monster_dragon_abyss.png",
    zone = "ch4_beast_east",
    category = "emperor_boss",
    race = "abyss_dragon",
    level = 100,
    realm = "dacheng_1",
    bodyColor = {60, 30, 120, 255},
    clawColor = {100, 50, 180},
    skillTextColor = {130, 80, 220, 255},
    warningColorOverride = {80, 40, 150, 120},
    phases = 3,
    skills = { "abyss_roar", "abyss_venom" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          announce = "堕渊蛟龙怒吼震天，深渊为之颤动！",
          triggerSkill = "abyss_clone" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "万丈深渊，吞噬一切！",
          triggerSkill = "abyss_vortex_field" },
    },
    tierOnly = 9,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {15, 25} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "dragon_abyss_books" },  -- 高级技能书（共享3%，随机掉1本）
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 0.03, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹3%（四龙神）
        { chance = 0.01, type = "consumable", consumableId = "dragon_scale_abyss" },  -- 渊蛟龙骨1%（圣器打造材料）
        { chance = 0.0025, type = "equipment", equipId = "silong_ring_ch4" },  -- 帝尊肆戒0.25%
        { chance = 0.004, type = "set_equipment", setIds = XIANJIE_SET_IDS },  -- 套装灵器 0.4%（四套随机一件）
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },  -- 金砖0.5%
    },
}

-- ===================== 焚天蜃龙（烈焰岛·东南） =====================
M.Types.dragon_fire = {
    name = "焚天蜃龙",
    icon = "🐉",
    portrait = "Textures/monster_dragon_fire.png",
    zone = "ch4_beast_south",
    category = "emperor_boss",
    race = "fire_dragon",
    level = 100,
    realm = "dacheng_1",
    bodyColor = {220, 60, 20, 255},
    clawColor = {255, 100, 30},
    skillTextColor = {255, 120, 40, 255},
    warningColorOverride = {255, 80, 20, 120},
    phases = 3,
    skills = { "dragon_flame", "inferno_ground" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.3,
          announce = "焚天蜃龙炎翼展开，大地为之焦灼！",
          addSkill = "dragon_breath_sweep" },
        { threshold = 0.3, atkMult = 2.2, speedMult = 1.6, intervalMult = 0.3,
          announce = "天地焚尽，化为灰烬！",
          triggerSkill = "inferno_field" },
    },
    tierOnly = 9,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {15, 25} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "dragon_fire_books" },  -- 高级技能书（共享3%，随机掉1本）
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 0.03, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹3%（四龙神）
        { chance = 0.01, type = "consumable", consumableId = "dragon_scale_fire" },  -- 焚天龙焰1%（圣器打造材料）
        { chance = 0.0025, type = "equipment", equipId = "silong_ring_ch4" },  -- 帝尊肆戒0.25%
        { chance = 0.004, type = "set_equipment", setIds = XIANJIE_SET_IDS },  -- 套装灵器 0.4%（四套随机一件）
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },  -- 金砖0.5%
    },
}

-- ===================== 蚀骨螭龙（流沙岛·西南） =====================
M.Types.dragon_sand = {
    name = "蚀骨螭龙",
    icon = "🐉",
    portrait = "Textures/monster_dragon_sand.png",
    zone = "ch4_beast_west",
    category = "emperor_boss",
    race = "sand_dragon",
    level = 100,
    realm = "dacheng_1",
    bodyColor = {180, 150, 60, 255},
    clawColor = {200, 170, 80},
    skillTextColor = {210, 180, 60, 255},
    warningColorOverride = {190, 160, 50, 120},
    phases = 3,
    skills = { "erosion_storm", "sand_charge_dragon" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.2, speedMult = 1.3,
          announce = "蚀骨螭龙腾沙而起，骨碎风卷！",
          addSkill = "sand_prison" },
        { threshold = 0.3, atkMult = 1.8, speedMult = 1.8, intervalMult = 0.4,
          announce = "蚀尽骨肉，化归黄沙！",
          triggerSkill = "erosion_field" },
    },
    tierOnly = 9,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {15, 25} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "dragon_sand_books" },  -- 高级技能书（共享3%，随机掉1本）
        { chance = 0.03, type = "world_drop", pool = "ch4" },  -- 世界掉落（BOSS共享3%）
        { chance = 0.03, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹3%（四龙神）
        { chance = 0.01, type = "consumable", consumableId = "dragon_scale_sand" },  -- 蚀骨龙牙1%（圣器打造材料）
        { chance = 0.0025, type = "equipment", equipId = "silong_ring_ch4" },  -- 帝尊肆戒0.25%
        { chance = 0.004, type = "set_equipment", setIds = XIANJIE_SET_IDS },  -- 套装灵器 0.4%（四套随机一件）
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },  -- 金砖0.5%
    },
}

-- ===================== 文王八卦盘·文王残影（第四章神器BOSS） =====================
-- 核心机制：永驻八卦领域（持续灼烧）+ 阴阳双态切换（每10%血量）+ 阴阳逆转AOE
M.Types.artifact_fuxi_shadow = {
    name = "文王残影",
    icon = "☯",
    portrait = "Textures/monster_wenwang_shadow.png",
    zone = "artifact_arena",
    category = "emperor_boss",
    race = "divine_beast",
    level = 100,
    realm = "dacheng_1",  -- 大乘初期
    bodyColor = {80, 150, 220, 255},
    clawColor = {100, 180, 255},
    skillTextColor = {100, 200, 255, 255},
    warningColorOverride = {80, 150, 220, 120},
    phases = 1,                 -- 不使用传统 phaseConfig，由 dualState 驱动
    skills = { "wenwang_qian_split", "wenwang_li_blaze" },  -- 初始阳仪态技能组

    -- ═══ 双态切换配置（数据驱动，不硬编码） ═══
    dualState = {
        enabled = true,
        initialState = "yang",                  -- 初始状态
        switchInterval = 0.10,                  -- 每10%血量切换一次
        switchSkill = "wenwang_yinyang_reversal", -- 切换时触发的全域AOE
        -- 两种状态的技能组定义
        states = {
            yang = {
                name = "阳仪",
                skills = { "wenwang_qian_split", "wenwang_li_blaze" },
                announce = "阳仪当空，乾离炽焰！",
                -- 领域视觉参数
                auraColor = { 255, 200, 50 },       -- 金色
            },
            yin = {
                name = "阴仪",
                skills = { "wenwang_kun_bind", "wenwang_kan_frost" },
                announce = "阴仪沉渊，坤坎凝寒！",
                auraColor = { 80, 140, 255 },        -- 蓝色
            },
        },
        -- 按切换次数递增的数值强化（第N次切换后的倍率）
        scaling = {
            { atkMult = 1.0, speedMult = 1.0 },    -- 初始（0次切换）
            { atkMult = 1.1, speedMult = 1.05 },   -- 第1次（90%）
            { atkMult = 1.2, speedMult = 1.1 },    -- 第2次（80%）
            { atkMult = 1.3, speedMult = 1.15 },   -- 第3次（70%）
            { atkMult = 1.4, speedMult = 1.2 },    -- 第4次（60%）
            { atkMult = 1.5, speedMult = 1.3 },    -- 第5次（50%）
            { atkMult = 1.7, speedMult = 1.4 },    -- 第6次（40%）
            { atkMult = 1.9, speedMult = 1.5 },    -- 第7次（30%）
            { atkMult = 2.1, speedMult = 1.6 },    -- 第8次（20%）
            { atkMult = 2.4, speedMult = 1.8 },    -- 第9次（10%）
        },
    },

    -- ═══ 永驻八卦领域配置（数据驱动） ═══
    baguaAura = {
        enabled = true,
        radius = 5.0,               -- 领域半径（竞技场8×8，留出走位空间）
        damagePercent = 0.02,        -- 每秒2%最大HP灼烧
        tickInterval = 1.0,          -- 每秒一跳
    },

    phaseConfig = {},               -- 留空，不使用传统阶段系统
    dropTable = {},
    isArtifactBoss = true,
    berserkBuff = { atkSpeedMult = 1.4, speedMult = 1.4, cdrMult = 0.6 },
}

end
