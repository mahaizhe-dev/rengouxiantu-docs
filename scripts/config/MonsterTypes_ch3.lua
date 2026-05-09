-- ============================================================================
-- MonsterTypes_ch3.lua - 第三章 + 挑战副本 + 神器BOSS + 驱魔怪物
-- 万里黄沙·黄沙九寨 · 沈墨T1-T8 · 陆青云T1-T8 · 猪二哥 · 魔化怪物
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
-- ===================== 挑战副本：血煞盟·沈墨 =====================

M.Types.challenge_shenmo_t1 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "boss",
    race = "human",
    level = 25,
    realm = "zhuji_1",
    bodyColor = {140, 50, 50, 255},
    clawColor = {200, 30, 30},          -- 血红爪击
    skillTextColor = {255, 80, 60, 255}, -- 血色技能名浮字
    warningColorOverride = {180, 30, 30, 120}, -- 通用技能预警覆盖为血色
    phases = 1,
    skills = { "line_charge", "whirlwind" },
    dropTable = {},
    isChallenge = true,
    -- 血煞印记：命中叠层，每层扣1%最大血量/秒，不过期
    bloodMark = { damagePercent = 0.01 },
}

M.Types.challenge_shenmo_t2 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "boss",
    race = "human",
    level = 30,
    realm = "zhuji_2",
    bodyColor = {160, 40, 40, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 2,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.3,
          announce = "血海...涌动！",
          triggerSkill = "shenmo_blood_flood_easy" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.01 },
}

M.Types.challenge_shenmo_t3 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 35,
    realm = "zhuji_3",
    bodyColor = {180, 30, 30, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 2,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        -- P2: HP<50% 狂暴+场地技能（低难度）
        { threshold = 0.5, atkMult = 1.0, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌！",
          triggerSkill = "shenmo_blood_flood_easy" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.015 },
}

M.Types.challenge_shenmo_t4 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 40,
    realm = "jindan_1",
    bodyColor = {200, 20, 20, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        -- P2: HP<60% 场地技能+狂暴+分身
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        -- P3: HP<25% 强化狂暴+场地技能
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
}

-- ===================== 挑战副本：浩气宗·陆青云 =====================

M.Types.challenge_luqingyun_t1 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "boss",
    race = "human",
    level = 25,
    realm = "zhuji_1",
    bodyColor = {50, 90, 160, 255},
    clawColor = {220, 180, 40},          -- 金黄爪击
    skillTextColor = {255, 220, 60, 255}, -- 金黄技能名浮字
    warningColorOverride = {220, 180, 40, 120}, -- 通用技能预警覆盖为金黄
    phases = 1,
    skills = { "shield_bash", "rect_sweep" },
    dropTable = {},
    isChallenge = true,
    -- 正气结界：周期性生成永久屏障区域，对玩家造成30%ATK/秒
    barrierZone = { interval = 30, maxCount = 2, damagePercent = 0.30, radius = 0.8 },
}

M.Types.challenge_luqingyun_t2 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "boss",
    race = "human",
    level = 30,
    realm = "zhuji_2",
    bodyColor = {40, 100, 180, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 2,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.3,
          announce = "天罡剑阵...聚！",
          triggerSkill = "luqingyun_sword_array_easy" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 30, maxCount = 2, damagePercent = 0.30, radius = 0.8 },
}

M.Types.challenge_luqingyun_t3 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 35,
    realm = "zhuji_3",
    bodyColor = {30, 110, 200, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 2,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        -- P2: HP<50% 狂暴+场地技能（低难度）
        { threshold = 0.5, atkMult = 1.0, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array_easy" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 30, maxCount = 3, damagePercent = 0.30, radius = 0.8 },
}

M.Types.challenge_luqingyun_t4 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 40,
    realm = "jindan_1",
    bodyColor = {20, 120, 220, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        -- P2: HP<60% 场地技能+狂暴+囚笼
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        -- P3: HP<30% 强化狂暴+场地技能
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
}

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
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
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
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
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
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
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
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
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
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
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
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
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
        { chance = 0.001, type = "consumable", consumableId = "sha_hai_ling_box" },
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
        { chance = 0.12, type = "equipment", minQuality = "white", maxQuality = "purple" },
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
        { chance = 0.001, type = "consumable", consumableId = "sha_hai_ling_box" },
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
        { chance = 1.0, type = "lingYun", amount = {5, 8} },
        { chance = 0.03, type = "consumable", consumableId = "yuanying_fruit" },
        -- 宠物食物
        { chance = 0.05, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.15, type = "consumable", consumableId = "demon_essence" },
        -- 突破材料
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%

        -- ⑧灵兽赐主T2技能书（5%共享池，随机1本）
        { chance = 0.05, type = "world_drop", pool = "shawanli_owner_books" },
        -- ⑨灵器武器（1%命中，从5把中随机1把，互斥）
        { chance = 0.01, type = "world_drop", pool = "huangsha_weapons" },
        -- ⑨.5 帝尊叁戒（0.5%独立掉落）
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch3" },
        -- ⑨.6 沙海令盒（0.1%独立掉落）
        { chance = 0.001, type = "consumable", consumableId = "sha_hai_ling_box" },
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

-- ===================== 挑战副本：血煞盟·沈墨 T5-T8（第三章沙海试炼） =====================

M.Types.challenge_shenmo_t5 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 50,
    realm = "jindan_3",
    bodyColor = {200, 20, 20, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
}

M.Types.challenge_shenmo_t6 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 55,
    realm = "yuanying_1",
    bodyColor = {220, 15, 15, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

M.Types.challenge_shenmo_t7 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 60,
    realm = "yuanying_2",
    bodyColor = {230, 10, 10, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

M.Types.challenge_shenmo_t8 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 60,
    realm = "yuanying_3",
    bodyColor = {240, 5, 5, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- ===================== 挑战副本：浩气宗·陆青云 T5-T8（第三章沙海试炼） =====================

M.Types.challenge_luqingyun_t5 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 50,
    realm = "jindan_3",
    bodyColor = {20, 120, 220, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
}

M.Types.challenge_luqingyun_t6 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 55,
    realm = "yuanying_1",
    bodyColor = {15, 130, 235, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

M.Types.challenge_luqingyun_t7 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 60,
    realm = "yuanying_2",
    bodyColor = {10, 140, 245, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

M.Types.challenge_luqingyun_t8 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 60,
    realm = "yuanying_3",
    bodyColor = {5, 150, 255, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- ===================== 挑战副本：血煞盟·沈墨（新声望体系 R1-R7） =====================
-- 新体系所有 BOSS 均为 emperor_boss，与旧 t1-t8 共存（旧存档向后兼容）

-- 声望等级1: T3 筑基初期（单阶段，仅基础技能）
M.Types.challenge_shenmo_r1 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 25,
    realm = "zhuji_1",
    bodyColor = {140, 50, 50, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 1,
    skills = { "line_charge", "whirlwind" },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.015 },
}

-- 声望等级2: T4 筑基后期（3阶段，增加十字斩 + P2/P3）
M.Types.challenge_shenmo_r2 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 35,
    realm = "zhuji_3",
    bodyColor = {170, 35, 35, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.015 },
}

-- 声望等级3: T5 金丹中期
M.Types.challenge_shenmo_r3 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 45,
    realm = "jindan_2",
    bodyColor = {195, 25, 25, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
}

-- 声望等级4: T6 元婴初期（增加狂暴buff）
M.Types.challenge_shenmo_r4 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 55,
    realm = "yuanying_1",
    bodyColor = {210, 18, 18, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级5: T7 化神初期
M.Types.challenge_shenmo_r5 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 70,
    realm = "huashen_1",
    bodyColor = {225, 12, 12, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级6: T8 合体初期
M.Types.challenge_shenmo_r6 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 85,
    realm = "heti_1",
    bodyColor = {235, 8, 8, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级7: T9 大乘初期
M.Types.challenge_shenmo_r7 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 100,
    realm = "dacheng_1",
    bodyColor = {245, 5, 5, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- ═══════════════════════════════════════════════════════════════════
-- 浩气宗声望 BOSS：陆青云 R1-R7
-- 核心机制：正气结界（barrierZone）—— 周期性生成屏障区域
-- ═══════════════════════════════════════════════════════════════════

-- 声望等级1: T3 筑基初期（1阶段，基础技能）
M.Types.challenge_luqingyun_r1 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 25,
    realm = "zhuji_1",
    bodyColor = {50, 90, 160, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {60, 140, 220, 120},
    phases = 1,
    skills = { "shield_bash", "rect_sweep" },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 30, maxCount = 2, damagePercent = 0.30, radius = 0.8 },
}

-- 声望等级2: T4 筑基后期（3阶段，增加 ground_pound + P2/P3）
M.Types.challenge_luqingyun_r2 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 35,
    realm = "zhuji_3",
    bodyColor = {45, 100, 180, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {60, 140, 220, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "浩然正气，天地无极！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 28, maxCount = 2, damagePercent = 0.30, radius = 0.8 },
}

-- 声望等级3: T5 金丹中期
M.Types.challenge_luqingyun_r3 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 45,
    realm = "jindan_2",
    bodyColor = {40, 110, 200, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {60, 140, 220, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "浩然正气，天地无极！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 25, maxCount = 3, damagePercent = 0.35, radius = 0.8 },
}

-- 声望等级4: T6 元婴初期（增加狂暴buff）
M.Types.challenge_luqingyun_r4 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 55,
    realm = "yuanying_1",
    bodyColor = {35, 120, 215, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {60, 140, 220, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "浩然正气，天地无极！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 22, maxCount = 3, damagePercent = 0.35, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级5: T7 化神初期
M.Types.challenge_luqingyun_r5 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 70,
    realm = "huashen_1",
    bodyColor = {30, 130, 230, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {60, 140, 220, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "浩然正气，天地无极！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 3, damagePercent = 0.35, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级6: T8 合体初期
M.Types.challenge_luqingyun_r6 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 85,
    realm = "heti_1",
    bodyColor = {25, 140, 240, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {60, 140, 220, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "浩然正气，天地无极！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 18, maxCount = 4, damagePercent = 0.40, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级7: T9 大乘初期
M.Types.challenge_luqingyun_r7 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 100,
    realm = "dacheng_1",
    bodyColor = {20, 150, 250, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {60, 140, 220, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "浩然正气，天地无极！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 15, maxCount = 4, damagePercent = 0.40, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- ═══════════════════════════════════════════════════════════════════
-- 青云门声望 BOSS：云裳 R1-R7
-- 核心机制：玉甲回响（jadeShield）—— 周期性激活护盾，反弹伤害+减伤
-- 玩家需要在护盾期间停止攻击，等护盾结束后加大输出
-- ═══════════════════════════════════════════════════════════════════

-- 声望等级1: T3 筑基初期（单阶段，仅基础技能）
M.Types.challenge_yunshang_r1 = {
    name = "云裳",
    icon = "🌿",
    portrait = "Textures/npc_qingyun_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 25,
    realm = "zhuji_1",
    bodyColor = {50, 160, 90, 255},
    clawColor = {80, 200, 120},
    skillTextColor = {100, 240, 140, 255},
    warningColorOverride = {60, 180, 100, 120},
    phases = 1,
    skills = { "jade_palm", "spirit_needle" },
    dropTable = {},
    isChallenge = true,
    jadeShield = { interval = 20, duration = 4.0, reflectPercent = 0.30, dmgReduction = 0.50 },
}

-- 声望等级2: T4 筑基后期（3阶段，增加云遁步 + P2/P3）
M.Types.challenge_yunshang_r2 = {
    name = "云裳",
    icon = "🌿",
    portrait = "Textures/npc_qingyun_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 35,
    realm = "zhuji_3",
    bodyColor = {45, 170, 100, 255},
    clawColor = {80, 200, 120},
    skillTextColor = {100, 240, 140, 255},
    warningColorOverride = {60, 180, 100, 120},
    phases = 3,
    skills = { "jade_palm", "spirit_needle", "cloud_drift" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "你的攻势...还不够格！",
          triggerSkill = "yunshang_jade_storm",
          addSkill = "yunshang_root_armor" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "青云之道，岂容亵渎！",
          triggerSkill = "yunshang_jade_storm" },
    },
    dropTable = {},
    isChallenge = true,
    jadeShield = { interval = 19, duration = 4.0, reflectPercent = 0.30, dmgReduction = 0.50 },
}

-- 声望等级3: T5 金丹中期
M.Types.challenge_yunshang_r3 = {
    name = "云裳",
    icon = "🌿",
    portrait = "Textures/npc_qingyun_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 45,
    realm = "jindan_2",
    bodyColor = {40, 180, 110, 255},
    clawColor = {80, 200, 120},
    skillTextColor = {100, 240, 140, 255},
    warningColorOverride = {60, 180, 100, 120},
    phases = 3,
    skills = { "jade_palm", "spirit_needle", "cloud_drift" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "你的攻势...还不够格！",
          triggerSkill = "yunshang_jade_storm",
          addSkill = "yunshang_root_armor" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "青云之道，岂容亵渎！",
          triggerSkill = "yunshang_jade_storm" },
    },
    dropTable = {},
    isChallenge = true,
    jadeShield = { interval = 17, duration = 4.5, reflectPercent = 0.35, dmgReduction = 0.55 },
}

-- 声望等级4: T6 元婴初期（增加狂暴buff）
M.Types.challenge_yunshang_r4 = {
    name = "云裳",
    icon = "🌿",
    portrait = "Textures/npc_qingyun_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 55,
    realm = "yuanying_1",
    bodyColor = {35, 190, 120, 255},
    clawColor = {80, 200, 120},
    skillTextColor = {100, 240, 140, 255},
    warningColorOverride = {60, 180, 100, 120},
    phases = 3,
    skills = { "jade_palm", "spirit_needle", "cloud_drift" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "你的攻势...还不够格！",
          triggerSkill = "yunshang_jade_storm",
          addSkill = "yunshang_root_armor" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "青云之道，岂容亵渎！",
          triggerSkill = "yunshang_jade_storm" },
    },
    dropTable = {},
    isChallenge = true,
    jadeShield = { interval = 15, duration = 4.5, reflectPercent = 0.35, dmgReduction = 0.55 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级5: T7 化神初期
M.Types.challenge_yunshang_r5 = {
    name = "云裳",
    icon = "🌿",
    portrait = "Textures/npc_qingyun_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 70,
    realm = "huashen_1",
    bodyColor = {30, 200, 130, 255},
    clawColor = {80, 200, 120},
    skillTextColor = {100, 240, 140, 255},
    warningColorOverride = {60, 180, 100, 120},
    phases = 3,
    skills = { "jade_palm", "spirit_needle", "cloud_drift" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "你的攻势...还不够格！",
          triggerSkill = "yunshang_jade_storm",
          addSkill = "yunshang_root_armor" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "青云之道，岂容亵渎！",
          triggerSkill = "yunshang_jade_storm" },
    },
    dropTable = {},
    isChallenge = true,
    jadeShield = { interval = 14, duration = 5.0, reflectPercent = 0.40, dmgReduction = 0.60 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级6: T8 合体初期
M.Types.challenge_yunshang_r6 = {
    name = "云裳",
    icon = "🌿",
    portrait = "Textures/npc_qingyun_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 85,
    realm = "heti_1",
    bodyColor = {25, 210, 140, 255},
    clawColor = {80, 200, 120},
    skillTextColor = {100, 240, 140, 255},
    warningColorOverride = {60, 180, 100, 120},
    phases = 3,
    skills = { "jade_palm", "spirit_needle", "cloud_drift" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "你的攻势...还不够格！",
          triggerSkill = "yunshang_jade_storm",
          addSkill = "yunshang_root_armor" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "青云之道，岂容亵渎！",
          triggerSkill = "yunshang_jade_storm" },
    },
    dropTable = {},
    isChallenge = true,
    jadeShield = { interval = 13, duration = 5.0, reflectPercent = 0.45, dmgReduction = 0.65 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级7: T9 大乘初期
M.Types.challenge_yunshang_r7 = {
    name = "云裳",
    icon = "🌿",
    portrait = "Textures/npc_qingyun_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 100,
    realm = "dacheng_1",
    bodyColor = {20, 220, 150, 255},
    clawColor = {80, 200, 120},
    skillTextColor = {100, 240, 140, 255},
    warningColorOverride = {60, 180, 100, 120},
    phases = 3,
    skills = { "jade_palm", "spirit_needle", "cloud_drift" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "你的攻势...还不够格！",
          triggerSkill = "yunshang_jade_storm",
          addSkill = "yunshang_root_armor" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "青云之道，岂容亵渎！",
          triggerSkill = "yunshang_jade_storm" },
    },
    dropTable = {},
    isChallenge = true,
    jadeShield = { interval = 12, duration = 5.5, reflectPercent = 0.50, dmgReduction = 0.70 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- ═══════════════════════════════════════════════════════════════════
-- 封魔殿声望 BOSS：凌战 R1-R7（封魔殿少帅，年轻一代）
-- 核心机制：封魔印（sealMark）—— 周期性叠加印记，满层爆发伤害
--   每隔 stackInterval 秒自动叠1层封魔印
--   达到 maxStacks 层时触发"封印爆发"，造成 burstDamagePercent × 玩家最大HP 的伤害
--   玩家每次攻击 BOSS 可削减 clearPerHit 层（鼓励持续输出）
-- ═══════════════════════════════════════════════════════════════════

-- 声望等级1: T3 筑基初期（1阶段，基础技能）
M.Types.challenge_liwuji_r1 = {
    name = "凌战",
    icon = "🔮",
    portrait = "Textures/npc_fengmo_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 25,
    realm = "zhuji_1",
    bodyColor = {120, 60, 160, 255},
    clawColor = {180, 80, 220},
    skillTextColor = {200, 120, 255, 255},
    warningColorOverride = {140, 60, 180, 120},
    phases = 1,
    skills = { "line_charge", "whirlwind" },
    dropTable = {},
    isChallenge = true,
    sealMark = { stackInterval = 5.0, maxStacks = 5, burstDamagePercent = 0.20, clearPerHit = 1 },
}

-- 声望等级2: T4 筑基后期（3阶段，增加十字斩 + P2/P3）
M.Types.challenge_liwuji_r2 = {
    name = "凌战",
    icon = "🔮",
    portrait = "Textures/npc_fengmo_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 35,
    realm = "zhuji_3",
    bodyColor = {130, 55, 170, 255},
    clawColor = {180, 80, 220},
    skillTextColor = {200, 120, 255, 255},
    warningColorOverride = {140, 60, 180, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "封魔之力...觉醒！",
          triggerSkill = "liwuji_seal_burst",
          addSkill = "liwuji_void_pull" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "万魔臣服，封印永镇！",
          triggerSkill = "liwuji_seal_burst" },
    },
    dropTable = {},
    isChallenge = true,
    sealMark = { stackInterval = 4.5, maxStacks = 5, burstDamagePercent = 0.22, clearPerHit = 1 },
}

-- 声望等级3: T5 金丹中期
M.Types.challenge_liwuji_r3 = {
    name = "凌战",
    icon = "🔮",
    portrait = "Textures/npc_fengmo_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 45,
    realm = "jindan_2",
    bodyColor = {140, 50, 180, 255},
    clawColor = {180, 80, 220},
    skillTextColor = {200, 120, 255, 255},
    warningColorOverride = {140, 60, 180, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "封魔之力...觉醒！",
          triggerSkill = "liwuji_seal_burst",
          addSkill = "liwuji_void_pull" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "万魔臣服，封印永镇！",
          triggerSkill = "liwuji_seal_burst" },
    },
    dropTable = {},
    isChallenge = true,
    sealMark = { stackInterval = 4.0, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 },
}

-- 声望等级4: T6 元婴初期（加狂暴）
M.Types.challenge_liwuji_r4 = {
    name = "凌战",
    icon = "🔮",
    portrait = "Textures/npc_fengmo_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 55,
    realm = "yuanying_1",
    bodyColor = {150, 45, 190, 255},
    clawColor = {180, 80, 220},
    skillTextColor = {200, 120, 255, 255},
    warningColorOverride = {140, 60, 180, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "封魔之力...觉醒！",
          triggerSkill = "liwuji_seal_burst",
          addSkill = "liwuji_void_pull" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "万魔臣服，封印永镇！",
          triggerSkill = "liwuji_seal_burst" },
    },
    dropTable = {},
    isChallenge = true,
    sealMark = { stackInterval = 3.5, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级5: T7 化神初期
M.Types.challenge_liwuji_r5 = {
    name = "凌战",
    icon = "🔮",
    portrait = "Textures/npc_fengmo_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 70,
    realm = "huashen_1",
    bodyColor = {160, 40, 200, 255},
    clawColor = {180, 80, 220},
    skillTextColor = {200, 120, 255, 255},
    warningColorOverride = {140, 60, 180, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "封魔之力...觉醒！",
          triggerSkill = "liwuji_seal_burst",
          addSkill = "liwuji_void_pull" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "万魔臣服，封印永镇！",
          triggerSkill = "liwuji_seal_burst" },
    },
    dropTable = {},
    isChallenge = true,
    sealMark = { stackInterval = 3.0, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级6: T8 合体初期
M.Types.challenge_liwuji_r6 = {
    name = "凌战",
    icon = "🔮",
    portrait = "Textures/npc_fengmo_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 85,
    realm = "heti_1",
    bodyColor = {170, 35, 210, 255},
    clawColor = {180, 80, 220},
    skillTextColor = {200, 120, 255, 255},
    warningColorOverride = {140, 60, 180, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "封魔之力...觉醒！",
          triggerSkill = "liwuji_seal_burst",
          addSkill = "liwuji_void_pull" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "万魔臣服，封印永镇！",
          triggerSkill = "liwuji_seal_burst" },
    },
    dropTable = {},
    isChallenge = true,
    sealMark = { stackInterval = 2.5, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- 声望等级7: T9 大乘初期
M.Types.challenge_liwuji_r7 = {
    name = "凌战",
    icon = "🔮",
    portrait = "Textures/npc_fengmo_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 100,
    realm = "dacheng_1",
    bodyColor = {180, 30, 220, 255},
    clawColor = {180, 80, 220},
    skillTextColor = {200, 120, 255, 255},
    warningColorOverride = {140, 60, 180, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "封魔之力...觉醒！",
          triggerSkill = "liwuji_seal_burst",
          addSkill = "liwuji_void_pull" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "万魔臣服，封印永镇！",
          triggerSkill = "liwuji_seal_burst" },
    },
    dropTable = {},
    isChallenge = true,
    sealMark = { stackInterval = 2.0, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

end
