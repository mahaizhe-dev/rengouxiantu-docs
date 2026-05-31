-- ============================================================================
-- MonsterTypes_ch3_Desert.lua - 黄沙九寨·沙漠区域怪物
-- 枯木寨/岩蟾寨/苍狼寨/赤甲寨/蛇骨寨/赤焰寨/蜃妖寨/黄天寨 + 流沙之母 + 猪二哥
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
-- =====================================================================
-- 第三章：万里黄沙 · 黄沙九寨
-- 妖怪横行的蛮荒领域，九寨各有一个妖王作为寨主（从外到里 9→1）
-- 第九寨已被铲平，无怪物
-- =====================================================================

-- ===================== 枯木寨(第八寨) 小怪Lv.33~35(筑基中) + 妖王36(筑基后) =====================
M.Types.sand_scorpion_8 = {
    name = "枯木精",
    icon = "🌳",
    portrait = "Textures/monster_kumu.png",
    zone = "ch3_fort_8",
    category = "normal",
    race = "kumu",
    levelRange = {33, 35},
    realm = "zhuji_2",  -- 筑基中期
    bodyColor = {180, 150, 80, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.05, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.05, type = "consumable", consumableId = "sha_hai_ling" },
    },
}
M.Types.yao_king_8 = {
    name = "枯木妖王",
    icon = "🌳",
    portrait = "Textures/monster_kumu_king.png",
    zone = "ch3_fort_8",
    category = "boss",
    race = "yao_king",
    level = 36,
    realm = "zhuji_3",  -- 筑基后期
    bodyColor = {100, 80, 40, 255},
    stationary = true,    -- 不移动，原地站桩
    attackRange = 5.0,    -- 远程攻击范围5格
    groundSpike = {       -- 普通攻击改为地刺
        warningTime = 0.3,          -- 预警时间（极短）
        warningRange = 0.8,         -- 地刺爆炸半径
        warningColor = {140, 100, 50, 150},  -- 土黄色预警
    },
    phases = 2,
    skills = { "kumu_entangle" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "枯木妖王枝干暴涨，遮天蔽日！",
          addSkill = "kumu_decay_dust" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {2, 2} },
        { chance = 0.15, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.05, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.02, type = "consumable", consumableId = "demon_essence" },
        -- ⑤突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_3" },
        -- ⑥技能书
        { chance = 0.05, type = "world_drop", pool = "xiewei_books" },  -- 攻速技能书5%（随机1本）

        -- ⑧专属装备
        { chance = 0.08, type = "equipment", equipId = "kumu_helmet_ch3" },  -- 枯木灵冠8%
        -- ⑨世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- ⑩沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑪神器碎片
        { chance = 0.001, type = "consumable", consumableId = "rake_fragment_1" },
    },
}

-- ===================== 岩蟾寨(第七寨) 小怪Lv.37~39(筑基后) + 妖王40(筑基后) =====================
M.Types.sand_wolf_7 = {
    name = "岩蟾",
    icon = "🐸",
    portrait = "Textures/monster_yanchan.png",
    zone = "ch3_fort_7",
    category = "normal",
    race = "yanchan",
    levelRange = {37, 39},
    realm = "zhuji_3",  -- 筑基后期
    bodyColor = {160, 140, 90, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.05, type = "consumable", consumableId = "sha_hai_ling" },
    },
}
M.Types.yao_king_7 = {
    name = "岩蟾妖王",
    icon = "🐸",
    portrait = "Textures/monster_yanchan_king.png",
    zone = "ch3_fort_7",
    category = "boss",
    race = "yao_king",
    level = 40,
    realm = "zhuji_3",  -- 筑基后期
    bodyColor = {120, 110, 70, 255},
    phases = 2,
    skills = { "yanchan_quake" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.3,
          announce = "岩蟾妖王怒震大地！",
          addSkill = "yanchan_venom_spray" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {2, 2} },
        { chance = 0.12, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.03, type = "consumable", consumableId = "demon_essence" },
        -- ⑤突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_3" },
        -- ⑥技能书
        { chance = 0.05, type = "world_drop", pool = "yanchan_books" },  -- 蕴灵·生命技能书5%（随机1本）

        -- ⑧专属装备
        { chance = 0.05, type = "equipment", equipId = "yanchan_armor_ch3" },  -- 岩蟾石铠5%
        -- ⑨世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- ⑩沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑪神器碎片
        { chance = 0.001, type = "consumable", consumableId = "rake_fragment_2" },
    },
}

-- ===================== 枯木/岩蟾/九寨野外精英 Lv.41(金丹初) =====================
M.Types.sand_elite_outer = {
    name = "沙暴妖尉",
    icon = "👹",
    portrait = "Textures/monster_shabao_wei.png",
    zone = "ch3_wild_outer",
    category = "elite",
    race = "sand_demon",
    level = 41,
    realm = "jindan_1",  -- 金丹初期
    bodyColor = {190, 160, 70, 255},
    skills = { "sand_blade" },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "orange" },
        { chance = 0.10, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.03, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.50, type = "consumable", consumableId = "sha_hai_ling" },
        -- 世界掉落
        { chance = 0.01, type = "world_drop", pool = "ch3" },  -- 1%
    },
}

-- ===================== 流沙之母(游荡王级BOSS) Lv.45(金丹中) 外围沙漠边缘巡逻 =====================
-- ===================== 流沙之子·外域 Lv.45(金丹中) 王级BOSS =====================
-- 掉落套用苍狼妖王，移除神器碎片、专属装备
M.Types.liusha_son_outer = {
    name = "流沙之子",
    icon = "🐛",
    portrait = "Textures/monster_liusha_mother.png",
    zone = "ch3_wild_outer",
    category = "king_boss",
    race = "sand_demon",
    level = 45,
    realm = "jindan_2",  -- 金丹中期
    bodyColor = {200, 170, 80, 255},
    clawColor = {180, 140, 50},
    skillTextColor = {220, 190, 80, 255},
    warningColorOverride = {200, 170, 80, 120},
    phases = 2,
    skills = { "liusha_burrow" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "流沙之子钻入地底，大地震颤！",
          addSkill = "liusha_sand_wave" },
    },
    dropTable = {
        -- ①灵韵
        { chance = 1.0, type = "lingYun", amount = {3, 5} },
        -- ②专属材料
        { chance = 0.01, type = "consumable", consumableId = "jindan_sand", amount = {1, 1} },
        -- ③装备掉落
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        -- ④食物（100%必掉仙骨）
        { chance = 1.0, type = "consumable", consumableId = "immortal_bone" },
        -- ⑤突破材料
        { chance = 0.02, type = "consumable", consumableId = "spirit_pill_3" },
        -- ⑥T6橙色披风
        { chance = 0.05, type = "equipment", equipId = "liusha_cape_ch3" },
        -- ⑦神器碎片（第七寨+第八寨共享0.1%）
        { chance = 0.001, type = "world_drop", pool = "rake_fragment_ch3_78" },
        -- ⑧世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },
        -- ⑨沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑩宠物书：蕴灵·攻击书（初级/中级随机）3%
        { chance = 0.03, type = "consumable", consumablePool = { "book_atkPerLv_1", "book_atkPerLv_2" } },
    },
}

-- ===================== 流沙之子·中域 Lv.55(元婴初) 王级BOSS =====================
-- 掉落套用烈焰狮王，移除神器碎片、专属装备
M.Types.liusha_son_mid = {
    name = "流沙之子",
    icon = "🐛",
    portrait = "Textures/monster_liusha_mother.png",
    zone = "ch3_wild_mid",
    category = "king_boss",
    race = "sand_demon",
    level = 55,
    realm = "yuanying_1",  -- 元婴初期
    bodyColor = {210, 180, 90, 255},
    clawColor = {190, 150, 60},
    skillTextColor = {220, 190, 80, 255},
    warningColorOverride = {200, 170, 80, 120},
    phases = 2,
    skills = { "liusha_burrow" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "流沙之子钻入地底，大地震颤！",
          addSkill = "liusha_sand_wave" },
    },
    dropTable = {
        -- ①灵韵
        { chance = 1.0, type = "lingYun", amount = {4, 6} },
        -- ②装备掉落
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        -- ③元婴果
        { chance = 0.01, type = "consumable", consumableId = "yuanying_fruit" },
        -- ④食物（100%必掉仙骨）
        { chance = 1.0, type = "consumable", consumableId = "immortal_bone" },
        -- ⑤突破材料
        { chance = 0.03, type = "consumable", consumableId = "spirit_pill_3" },
        -- ⑥T7紫色头盔（沙蚀额冠）
        { chance = 0.05, type = "equipment", equipId = "liusha_helmet_ch3" },
        -- ⑦神器碎片（第四五六寨共享0.1%）
        { chance = 0.001, type = "world_drop", pool = "rake_fragment_ch3_456" },
        -- ⑧帝尊叁戒（0.5%独立掉落）
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch3" },
        -- ⑨沙海令盒（0.1%独立掉落）
        { chance = 0.005, type = "consumable", consumableId = "sha_hai_ling_box" },
        -- ⑩世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },
        -- ⑪沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑫宠物书：加伤书（初级/中级随机）3%
        { chance = 0.03, type = "consumable", consumablePool = { "book_bonusDmg_1", "book_bonusDmg_2" } },
        -- 沙煞酒由 WineData 控制（3%）
    },
}

-- ===================== 流沙之母·内域 Lv.65(元婴后) 皇级BOSS =====================
-- 掉落套用沙万里，移除神器碎片、专属装备；增加 liusha_quicksand 技能
M.Types.liusha_mother = {
    name = "流沙之母",
    icon = "👑",
    portrait = "Textures/monster_liusha_mother_emperor.png",
    zone = "ch3_wild_inner",
    category = "emperor_boss",
    race = "sand_demon",
    level = 65,
    realm = "yuanying_3",  -- 元婴后期
    bodyColor = {180, 140, 50, 255},
    clawColor = {160, 120, 30},
    skillTextColor = {255, 215, 0, 255},
    warningColorOverride = {200, 170, 80, 120},
    phases = 3,
    skills = { "liusha_burrow", "liusha_quicksand" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          announce = "流沙之母释放滔天妖压！",
          addSkill = "liusha_sand_wave",
          triggerSkill = "liusha_quicksand" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.6, intervalMult = 0.4,
          announce = "渺小的人类，也敢挑衅流沙之主！",
          triggerSkill = "liusha_sandstorm" },
    },
    dropTable = {
        -- ①常规掉落
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {5, 8} },
        { chance = 0.03, type = "consumable", consumableId = "yuanying_fruit" },
        -- ④食物（100%必掉仙骨）
        { chance = 1.0, type = "consumable", consumableId = "immortal_bone" },
        -- ⑤突破材料
        { chance = 0.05, type = "consumable", consumableId = "spirit_pill_3" },
        -- ⑥灵器武器·噬魂（0.5%独立掉落）
        { chance = 0.005, type = "equipment", equipId = "huangsha_shihun" },
        -- ⑦专属腰带·流沙绶带（3%独立掉落）
        { chance = 0.03, type = "equipment", equipId = "liusha_belt_ch3" },
        -- ⑧帝尊叁戒（1%独立掉落）
        { chance = 0.01, type = "equipment", equipId = "dizun_ring_ch3" },
        -- ⑨沙海令盒（0.5%独立掉落）
        { chance = 0.005, type = "consumable", consumableId = "sha_hai_ling_box" },
        -- ⑩神器碎片（第二三寨共享0.1%）
        { chance = 0.001, type = "world_drop", pool = "rake_fragment_ch3_23" },
        -- ⑪世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },
        -- ⑫沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑬宠物书：忽视防御书（初级/中级随机）3%
        { chance = 0.03, type = "consumable", consumablePool = { "book_ignoreDef_1", "book_ignoreDef_2" } },
        -- 沙煞酒由 WineData 控制（5%）
    },
}

-- ===================== 苍狼寨(第六寨) 小怪Lv.41~43(金丹初) + 妖王44(金丹初) =====================
M.Types.sand_demon_6 = {
    name = "苍狼",
    icon = "🐺",
    portrait = "Textures/monster_canglang.png",
    zone = "ch3_fort_6",
    category = "normal",
    race = "sand_demon",
    levelRange = {41, 43},
    realm = "jindan_1",  -- 金丹初期
    bodyColor = {170, 140, 60, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.05, type = "consumable", consumableId = "sha_hai_ling" },
    },
}
M.Types.yao_king_6 = {
    name = "苍狼妖王",
    icon = "🐺",
    portrait = "Textures/monster_canglang_king.png",
    zone = "ch3_fort_6",
    category = "boss",
    race = "yao_king",
    level = 44,
    realm = "jindan_1",  -- 金丹初期
    bodyColor = {140, 140, 150, 255},
    phases = 2,
    skills = { "canglang_charge" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "苍狼妖王仰天长嚎！",
          addSkill = "canglang_howl" },
    },
    dropTable = {
        -- ①常规掉落
        { chance = 1.0, type = "lingYun", amount = {3, 5} },
        -- ②专属材料
        { chance = 0.01, type = "consumable", consumableId = "jindan_sand", amount = {1, 1} },
        -- ③装备掉落
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        -- ④宠物食物
        { chance = 0.10, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.10, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.03, type = "consumable", consumableId = "demon_essence" },
        -- ⑤突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_3" },
        -- ⑥技能书
        { chance = 0.05, type = "world_drop", pool = "canglang_books" },  -- 暴伤技能书5%（随机1本）

        -- ⑧专属装备
        { chance = 0.08, type = "equipment", equipId = "canglang_necklace_ch3" },  -- 苍狼牙坠8%
        -- ⑨世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- ⑩沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑪神器碎片
        { chance = 0.001, type = "consumable", consumableId = "rake_fragment_3" },
    },
}

-- ===================== 赤甲寨(第五寨) 小怪Lv.45~47(金丹初) + 妖王48(金丹中) =====================
M.Types.sand_scorpion_5 = {
    name = "赤甲蝎",
    icon = "🦂",
    portrait = "Textures/monster_chijia.png",
    zone = "ch3_fort_5",
    category = "normal",
    race = "sand_scorpion",
    levelRange = {45, 47},
    realm = "jindan_1",  -- 金丹初期
    bodyColor = {200, 100, 50, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.05, type = "consumable", consumableId = "sha_hai_ling" },
    },
}
M.Types.yao_king_5 = {
    name = "赤甲妖王",
    icon = "🦂",
    portrait = "Textures/monster_chijia_king.png",
    zone = "ch3_fort_5",
    category = "boss",
    race = "yao_king",
    level = 48,
    realm = "jindan_2",  -- 金丹中期
    bodyColor = {220, 80, 40, 255},
    phases = 2,
    skills = { "chijia_tail_sweep" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.3,
          announce = "赤甲妖王喷射剧毒！",
          addSkill = "chijia_pincer" },
    },
    dropTable = {
        -- ①常规掉落
        { chance = 1.0, type = "lingYun", amount = {3, 5} },
        -- ②专属材料
        { chance = 0.02, type = "consumable", consumableId = "jindan_sand", amount = {1, 1} },
        -- ③装备掉落
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        -- ④宠物食物
        { chance = 0.08, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.10, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "demon_essence" },
        -- ⑤突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_3" },
        -- ⑥技能书
        { chance = 0.05, type = "world_drop", pool = "chijia_books" },  -- 减伤技能书5%（随机1本）

        -- ⑧专属装备
        { chance = 0.08, type = "equipment", equipId = "chijia_ring_ch3" },  -- 赤甲毒尾戒8%
        -- ⑨世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- ⑩沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑪神器碎片
        { chance = 0.001, type = "consumable", consumableId = "rake_fragment_4" },
    },
}

-- ===================== 蛇骨寨(第四寨) 小怪Lv.49~51(金丹中) + 妖王52(金丹后) =====================
M.Types.sand_wolf_4 = {
    name = "蛇骨妖",
    icon = "🐍",
    portrait = "Textures/monster_shegu.png",
    zone = "ch3_fort_4",
    category = "normal",
    race = "shegu",
    levelRange = {49, 51},
    realm = "jindan_2",  -- 金丹中期
    bodyColor = {130, 120, 100, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.05, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.02, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "sha_hai_ling" },
    },
}
M.Types.yao_king_4 = {
    name = "蛇骨妖王",
    icon = "🐍",
    portrait = "Textures/monster_shegu_king.png",
    zone = "ch3_fort_4",
    category = "boss",
    race = "yao_king",
    level = 52,
    realm = "jindan_3",  -- 金丹后期
    bodyColor = {180, 180, 160, 255},
    phases = 2,
    skills = { "shegu_bone_spike" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.4,
          announce = "蛇骨妖王白骨森森，毒雾弥漫！",
          addSkill = "shegu_miasma" },
    },
    dropTable = {
        -- ①常规掉落
        { chance = 1.0, type = "lingYun", amount = {3, 5} },
        -- ②专属材料
        { chance = 0.03, type = "consumable", consumableId = "jindan_sand", amount = {1, 1} },
        -- ③装备掉落
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        -- ④宠物食物
        { chance = 0.05, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.12, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "demon_essence" },
        -- ⑤突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_3" },
        -- ⑥技能书
        { chance = 0.05, type = "world_drop", pool = "tieji_books" },  -- 蕴灵·防御技能书5%（随机1本）

        -- ⑧专属装备
        { chance = 0.05, type = "equipment", equipId = "shegu_belt_ch3" },  -- 蛇骨腰环5%（橙）
        -- ⑨世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- ⑩沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑪神器碎片
        { chance = 0.001, type = "consumable", consumableId = "rake_fragment_5" },
    },
}

-- ===================== 蛇骨/赤甲/苍狼寨野外精英 Lv.56(元婴初) =====================
M.Types.sand_elite_mid = {
    name = "沙暴妖将",
    icon = "👹",
    portrait = "Textures/monster_shabao_jiang.png",
    zone = "ch3_wild_mid",
    category = "elite",
    race = "sand_demon",
    level = 56,
    realm = "yuanying_1",  -- 元婴初期
    bodyColor = {200, 140, 40, 255},
    skills = { "sand_cross_strike" },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "orange" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.50, type = "consumable", consumableId = "sha_hai_ling" },
        -- 世界掉落
        { chance = 0.01, type = "world_drop", pool = "ch3" },  -- 1%
    },
}

-- ===================== 赤焰寨(第三寨) 小怪Lv.53~55(金丹后) + 烈焰狮王56(元婴初) =====================
M.Types.sand_demon_3 = {
    name = "赤焰妖",
    icon = "🔥",
    portrait = "Textures/monster_chiyan.png",
    zone = "ch3_fort_3",
    category = "normal",
    race = "sand_demon",
    levelRange = {53, 55},
    realm = "jindan_3",  -- 金丹后期
    bodyColor = {140, 100, 40, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.06, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.03, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "sha_hai_ling" },
    },
}
M.Types.yao_king_3 = {
    name = "烈焰狮王",
    icon = "🦁",
    portrait = "Textures/monster_lieyan_lion.png",
    zone = "ch3_fort_3",
    category = "king_boss",
    race = "yao_king",
    level = 56,
    realm = "yuanying_1",  -- 元婴初期
    bodyColor = {220, 100, 30, 255},
    phases = 3,
    skills = { "lieyan_roar" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3,
          announce = "烈焰狮王鬃毛燃起烈焰！",
          addSkill = "lieyan_pounce" },
        { threshold = 0.3, atkMult = 1.8, speedMult = 1.5, intervalMult = 0.6,
          announce = "烈焰狮王怒吼，火海焚天！",
          addSkill = "lieyan_roar",
          triggerSkill = "lieyan_inferno" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {4, 6} },
        { chance = 0.01, type = "consumable", consumableId = "yuanying_fruit" },
        -- 宠物食物
        { chance = 0.10, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.08, type = "consumable", consumableId = "demon_essence" },
        -- 突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_3" },
        -- 技能书
        { chance = 0.05, type = "world_drop", pool = "xuanmang_books" },  -- 连击技能书5%（随机1本）

        -- ⑧专属装备
        { chance = 0.05, type = "equipment", equipId = "lieyan_cape_ch3" },  -- 烈焰鬃披5%（橙）
        -- ⑧.5 帝尊叁戒（0.5%独立掉落）
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch3" },
        -- ⑧.6 沙海令盒（0.1%独立掉落）
        { chance = 0.005, type = "consumable", consumableId = "sha_hai_ling_box" },
        -- ⑨世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- ⑩沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑪神器碎片
        { chance = 0.001, type = "consumable", consumableId = "rake_fragment_6" },
    },
}

-- ===================== 蜃妖寨(第二寨) 小怪Lv.57~59(元婴初) + 蜃妖王60(元婴中) =====================
M.Types.sand_demon_2 = {
    name = "蜃妖",
    icon = "🌀",
    portrait = "Textures/monster_shen.png",
    zone = "ch3_fort_2",
    category = "normal",
    race = "sand_demon",
    levelRange = {57, 59},
    realm = "yuanying_1",  -- 元婴初期
    bodyColor = {160, 110, 30, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
        { chance = 0.05, type = "consumable", consumableId = "beast_meat" },
        { chance = 0.03, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "sha_hai_ling" },
    },
}
M.Types.yao_king_2 = {
    name = "蜃妖王",
    icon = "🌀",
    portrait = "Textures/monster_shen_king.png",
    zone = "ch3_fort_2",
    category = "king_boss",
    race = "yao_king",
    level = 60,
    realm = "yuanying_2",  -- 元婴中期
    bodyColor = {120, 80, 180, 255},
    phases = 3,
    skills = { "shen_vortex" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3,
          announce = "蜃妖王幻影重重，虚实莫辨！",
          addSkill = "shen_maze",
          triggerSkill = "shen_clone" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.5,
          announce = "蜃妖王化出万千幻象！",
          triggerSkill = "shen_annihilation" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {4, 6} },
        { chance = 0.02, type = "consumable", consumableId = "yuanying_fruit" },
        -- 宠物食物
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.10, type = "consumable", consumableId = "demon_essence" },
        -- 突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_3" },
        -- 技能书
        { chance = 0.05, type = "world_drop", pool = "lieyan_books" },  -- 吸血技能书5%（随机1本）

        -- ⑧专属装备
        { chance = 0.02, type = "equipment", equipId = "shen_shoulder_ch3" },  -- 蜃影肩甲2%（灵器）
        -- ⑧.5 帝尊叁戒（0.5%独立掉落）
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch3" },
        -- ⑧.6 沙海令盒（0.1%独立掉落）
        { chance = 0.005, type = "consumable", consumableId = "sha_hai_ling_box" },
        -- ⑨世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- ⑩沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑪神器碎片
        { chance = 0.001, type = "consumable", consumableId = "rake_fragment_7" },
    },
}

-- ===================== 赤焰/蜃妖/黄天寨野外精英 Lv.63(元婴中) =====================
M.Types.sand_elite_inner = {
    name = "沙暴妖帅",
    icon = "👹",
    portrait = "Textures/monster_shabao_shuai.png",
    zone = "ch3_wild_inner",
    category = "elite",
    race = "sand_demon",
    level = 63,
    realm = "yuanying_2",  -- 元婴中期
    bodyColor = {210, 120, 20, 255},
    skills = { "sand_fire_circle" },
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "orange" },
        { chance = 0.06, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.06, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.50, type = "consumable", consumableId = "sha_hai_ling" },
        -- 世界掉落
        { chance = 0.01, type = "world_drop", pool = "ch3" },  -- 1%
    },
}

-- ===================== 黄天寨(第一寨) 枯木守卫 Lv.65(元婴后) =====================
M.Types.kumu_guard = {
    name = "枯木守卫",
    icon = "🌳",
    portrait = "Textures/monster_kumu_king.png",
    zone = "ch3_fort_1",
    category = "boss",
    race = "yao_king",
    level = 65,
    realm = "yuanying_2",  -- 元婴中期
    bodyColor = {100, 80, 40, 255},
    stationary = true,      -- 不移动，原地站桩
    attackRange = 5.0,      -- 远程攻击范围5格
    groundSpike = {         -- 普通攻击改为地刺
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {140, 100, 50, 150},
    },
    phases = 2,
    skills = { "kumu_entangle" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "枯木守卫枝干暴涨！",
          addSkill = "kumu_decay_dust" },
    },
    tierOnly = 7,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {3, 5} },
        { chance = 0.10, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.08, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.01, type = "consumable", consumableId = "yuanying_fruit" },
        -- 世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- 沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
    },
}

-- ===================== 黄天寨(第一寨) 皇级BOSS Lv.65(元婴后) =====================
M.Types.yao_king_1 = {
    name = "黄天大圣·沙万里",
    icon = "👑",
    portrait = "Textures/monster_sha_wanli.png",
    zone = "ch3_fort_1",
    category = "emperor_boss",
    race = "yao_king",
    level = 65,
    realm = "yuanying_3",  -- 元婴后期
    bodyColor = {100, 30, 30, 255},
    phases = 3,
    skills = { "sha_cross_quake" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          announce = "沙万里释放滔天妖压！",
          addSkill = "sha_desert_storm",
          triggerSkill = "sha_sand_clone" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.6, intervalMult = 0.4,
          announce = "尔等蝼蚁，也敢挑战本大圣！",
          triggerSkill = "sha_sandstorm_field" },
    },
    tierOnly = 7,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {5, 10} },
        { chance = 0.03, type = "consumable", consumableId = "yuanying_fruit" },
        -- 宠物食物
        { chance = 0.05, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.15, type = "consumable", consumableId = "demon_essence" },
        -- 突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%

        -- ⑧灵兽赐主T2技能书（5%共享池，随机1本）
        { chance = 0.05, type = "world_drop", pool = "shawanli_owner_books" },
        -- ⑨灵器武器（2%命中，从4把中随机1把，互斥）
        { chance = 0.02, type = "world_drop", pool = "huangsha_weapons" },
        -- ⑨.5 帝尊叁戒（1%独立掉落）
        { chance = 0.01, type = "equipment", equipId = "dizun_ring_ch3" },
        -- ⑨.6 沙海令盒（0.5%独立掉落）
        { chance = 0.005, type = "consumable", consumableId = "sha_hai_ling_box" },
        -- ⑩世界掉落
        { chance = 0.03, type = "world_drop", pool = "ch3" },  -- 3%
        -- ⑪沙海令
        { chance = 1.0, type = "consumable", consumableId = "sha_hai_ling" },
        -- ⑫神器碎片
        { chance = 0.001, type = "consumable", consumableId = "rake_fragment_8" },
    },
}

-- ===================== 上宝逊金钯·猪二哥（神器BOSS） =====================
M.Types.artifact_zhu_erge = {
    name = "猪二哥",
    icon = "🐷",
    portrait = "Textures/monster_zhu_erge.png",
    zone = "artifact_arena",
    category = "emperor_boss",
    race = "divine_beast",
    level = 70,
    realm = "yuanying_3",  -- 元婴后期
    bodyColor = {200, 160, 80, 255},
    clawColor = {255, 200, 100},
    skillTextColor = {255, 215, 0, 255},
    warningColorOverride = {200, 160, 80, 120},
    phases = 3,
    skills = { "ground_pound", "rect_sweep" },
    phaseConfig = {
        { threshold = 0.6, atkMult = 1.3, speedMult = 1.2,
          announce = "猪二哥怒目圆睁：我那便宜大哥三弟，有百般不是，也不能由你打杀！",
          triggerSkill = "zhu_erge_divine_wrath",
          addSkill = "cross_smash" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.6, intervalMult = 0.4,
          announce = "猪二哥狂性大发，钉耙横扫八方！",
          triggerSkill = "zhu_erge_divine_wrath" },
    },
    dropTable = {},
    isArtifactBoss = true,
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}


end
