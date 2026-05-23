-- ============================================================================
-- MonsterTypes_ch5.lua - 第五章·太虚之殇
-- ============================================================================
-- 太虚宗废墟怪物（Lv.91~120）：宗门残魂/异变/深渊大魔
-- 裂山门入口守卫（king_boss×2）
-- 六大主区（normal + elite + emperor_boss）
-- 藏经书阁（elite + emperor_boss，无普通怪）
-- 镇魔深渊（king_boss + emperor_boss 双BOSS）
-- 四封剑台（saint_boss×4，暂不刷新）
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)

-- =====================================================================
-- 第五章·太虚之殇 种族修正
-- 设计文档："先确定等级、境界、类别，不在这一版提前展开种族修正"
-- 因此所有种族修正均为 1.0，保持设计文档裸档基准
-- =====================================================================
M.RaceModifiers.sword_ruin_ghost    = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 剑墟残魂
M.RaceModifiers.stone_guardian      = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 石傀守卫
M.RaceModifiers.cold_pool_beast     = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 寒池灵兽
M.RaceModifiers.forge_puppet        = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 炉火傀儡
M.RaceModifiers.stele_spirit        = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 碑林幻灵
M.RaceModifiers.court_wraith        = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 别院怨灵
M.RaceModifiers.library_demon       = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 书阁妖灵
M.RaceModifiers.abyss_demon         = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 深渊魔族
M.RaceModifiers.taixu_elder         = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 太虚长老
M.RaceModifiers.immortal_sword      = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 仙剑器灵

-- =====================================================================
-- 裂山门遗址 — 入口守卫（左右各1只 king_boss）   Lv.95
-- 护山石傀：山门废墟的石制守卫，阻挡闯入者
-- =====================================================================
M.Types.ch5_stone_guardian = {
    name = "护山石傀",
    icon = "🗿",
    portrait = "Textures/monster_stone_guardian.png",
    zone = "ch5_broken_gate",
    category = "king_boss",
    race = "stone_guardian",
    level = 95,
    realm = "heti_3",  -- 合体后期
    bodyColor = {140, 130, 110, 255},
    clawColor = {180, 170, 140},
    skillTextColor = {200, 190, 160, 255},
    warningColorOverride = {160, 150, 120, 120},
    phases = 1,
    skills = { "ch5_rock_smash", "ch5_rock_scatter", "ch5_gate_crush" },
    berserkBuff = { atkSpeedMult = 1.5, speedMult = 1.4, cdrMult = 0.6 },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 8, maxTier = 9, minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {10, 15} },
        { chance = 0.20, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "jiuzhuan_jindan" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.03, type = "equipment", equipId = "zhenpai_boots_ch5" },  -- 镇派行靴3%（橙）
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
    },
}

-- =====================================================================
-- ① 问剑坪 — 1普通 + 1精英 + 1BOSS    Lv.91~95
-- 太虚宗弟子残魂在废墟问剑台上游荡
-- =====================================================================
M.Types.ch5_sword_ghost = {
    name = "同门残魂",
    icon = "👻",
    portrait = "Textures/monster_sword_ghost.png",
    zone = "ch5_sword_plaza",
    category = "normal",
    race = "sword_ruin_ghost",
    levelRange = {91, 94},
    realm = "heti_2",  -- 合体中期
    bodyColor = {120, 140, 180, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minTier = 7, maxTier = 9, minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_sword_shadow = {
    name = "论剑残影",
    icon = "⚔️",
    portrait = "Textures/monster_sword_shadow.png",
    zone = "ch5_sword_plaza",
    category = "elite",
    race = "sword_ruin_ghost",
    level = 94,
    realm = "heti_2",  -- 合体中期
    bodyColor = {100, 120, 170, 255},
    skills = { "ch5_shadow_thrust" },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 7, maxTier = 9, minQuality = "white", maxQuality = "orange" },
        { chance = 0.12, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.50, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_pei_qianyue = {
    name = "问剑长老·裴千岳",
    icon = "🗡️",
    portrait = "Textures/monster_pei_qianyue.png",
    zone = "ch5_sword_plaza",
    category = "emperor_boss",
    race = "taixu_elder",
    level = 95,
    realm = "heti_3",  -- 合体后期
    bodyColor = {80, 100, 160, 255},
    clawColor = {120, 140, 200},
    skillTextColor = {140, 160, 220, 255},
    warningColorOverride = {100, 120, 180, 120},
    phases = 2,
    skills = { "ch5_pei_sword_qi", "ch5_pei_sky_slash" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          announce = "裴千岳拔剑出鞘，剑意贯虹！",
          addSkill = "ch5_pei_phantom_sword" },
        { threshold = 0.3, atkMult = 1.6, speedMult = 1.4, intervalMult = 0.5,
          announce = "千岳剑意……破灭万物！",
          triggerSkill = "ch5_pei_execution" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 8, maxTier = 9, minQuality = "green", maxQuality = "orange" },
        { chance = 1.0, type = "lingYun", amount = {12, 20} },
        { chance = 0.20, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.01, type = "consumable", consumableId = "jiuzhuan_jindan" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.02, type = "equipment", equipId = "wenfeng_necklace_ch5" },  -- 闻风玉坠2%（灵器）
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_4" },  -- 灵兽丹·肆1%
        { chance = 0.01, type = "consumable", consumableId = "sword_intent_crystal" },  -- 剑星草1%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
    },
}

-- =====================================================================
-- ② 洗剑寒池 — 1普通 + 1精英 + 1BOSS    Lv.96~100
-- 寒池灵兽因太虚宗崩灭而失控
-- =====================================================================
M.Types.ch5_cold_crane = {
    name = "寒池灵鹤",
    icon = "🦢",
    portrait = "Textures/monster_cold_crane.png",
    zone = "ch5_cold_pool",
    category = "normal",
    race = "cold_pool_beast",
    levelRange = {96, 99},
    realm = "heti_3",  -- 合体后期
    bodyColor = {180, 210, 240, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minTier = 7, maxTier = 9, minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_ice_turtle = {
    name = "裂冰玄鼋",
    icon = "🐢",
    portrait = "Textures/monster_ice_turtle.png",
    zone = "ch5_cold_pool",
    category = "elite",
    race = "cold_pool_beast",
    level = 99,
    realm = "heti_3",  -- 合体后期
    bodyColor = {140, 180, 220, 255},
    skills = { "ch5_frost_breath" },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 7, maxTier = 9, minQuality = "white", maxQuality = "cyan" },
        { chance = 0.16, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.50, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_frost_luan = {
    name = "洗剑霜鸾",
    icon = "🦅",
    portrait = "Textures/monster_frost_luan.png",
    zone = "ch5_cold_pool",
    category = "emperor_boss",
    race = "cold_pool_beast",
    level = 100,
    realm = "dacheng_1",  -- 大乘初期
    bodyColor = {100, 160, 220, 255},
    clawColor = {140, 200, 255},
    skillTextColor = {160, 220, 255, 255},
    warningColorOverride = {120, 180, 240, 120},
    phases = 2,
    skills = { "ch5_luan_frost_peck", "ch5_luan_ice_storm" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          announce = "霜鸾长鸣，寒池凝冰三千丈！",
          addSkill = "ch5_luan_ice_prison" },
        { threshold = 0.3, atkMult = 1.6, speedMult = 1.4, intervalMult = 0.5,
          announce = "霜鸾绝唱……万物冰封！",
          triggerSkill = "ch5_luan_requiem" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 8, maxTier = 9, minQuality = "green", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {14, 22} },
        { chance = 0.40, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.02, type = "consumable", consumableId = "jiuzhuan_jindan" },  -- 九转金丹2%
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.02, type = "equipment", equipId = "hanchi_ring_ch5" },  -- 寒池灵戒2%（灵器）
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.01, type = "consumable", consumableId = "sword_intent_crystal" },  -- 剑星草1%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
    },
}

-- =====================================================================
-- ③ 铸剑地炉 — 1普通 + 1精英 + 1BOSS    Lv.101~105
-- 铸剑炉中残留的火傀和兵傀
-- =====================================================================
M.Types.ch5_slag_puppet = {
    name = "炉渣火傀",
    icon = "🔥",
    portrait = "Textures/monster_slag_puppet.png",
    zone = "ch5_forge",
    category = "normal",
    race = "forge_puppet",
    levelRange = {101, 104},
    realm = "dacheng_1",  -- 大乘初期
    bodyColor = {220, 120, 40, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minTier = 8, maxTier = 10, minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_forge_soldier = {
    name = "炼炉兵傀",
    icon = "⚙️",
    portrait = "Textures/monster_forge_soldier.png",
    zone = "ch5_forge",
    category = "elite",
    race = "forge_puppet",
    levelRange = {101, 104},
    realm = "dacheng_1",  -- 大乘初期
    bodyColor = {200, 100, 30, 255},
    skills = { "ch5_molten_sweep" },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 8, maxTier = 10, minQuality = "white", maxQuality = "cyan" },
        { chance = 0.20, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.50, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_han_bailian = {
    name = "铸剑长老·韩百炼",
    icon = "🔨",
    portrait = "Textures/monster_han_bailian.png",
    zone = "ch5_forge",
    category = "emperor_boss",
    race = "taixu_elder",
    level = 105,
    realm = "dacheng_2",  -- 大乘中期
    bodyColor = {180, 80, 20, 255},
    clawColor = {220, 120, 40},
    skillTextColor = {240, 140, 60, 255},
    warningColorOverride = {200, 100, 30, 120},
    phases = 2,
    skills = { "ch5_han_forge_slam", "ch5_han_flame_roll" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.1,
          announce = "韩百炼抄起铸剑锤，烈焰焚天！",
          addSkill = "ch5_han_forge_clone" },
        { threshold = 0.3, atkMult = 1.7, speedMult = 1.3, intervalMult = 0.5,
          announce = "天炉焚灭……百炼归一！",
          triggerSkill = "ch5_han_inferno" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 9, maxTier = 10, minQuality = "green", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {15, 25} },
        { chance = 0.60, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.01, type = "equipment", equipId = "bailian_belt_ch5" },  -- 百炼熔带1%（橙）
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.01, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹1%（皇级）
        { chance = 0.01, type = "consumable", consumableId = "sword_intent_crystal" },  -- 剑星草1%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：防御书（特级）0.5%
        { chance = 0.005, type = "consumable", consumableId = "book_def_4" },
    },
}

-- =====================================================================
-- ④ 悟剑碑林 — 1普通 + 1精英 + 1BOSS    Lv.106~110
-- 碑林中的石俑和幻影，承载着残留的剑意
-- =====================================================================
M.Types.ch5_stele_golem = {
    name = "剑痕石俑",
    icon = "🪨",
    portrait = "Textures/monster_stele_golem.png",
    zone = "ch5_stele_forest",
    category = "normal",
    race = "stele_spirit",
    levelRange = {106, 109},
    realm = "dacheng_2",  -- 大乘中期
    bodyColor = {160, 160, 170, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minTier = 8, maxTier = 10, minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_stele_phantom = {
    name = "守碑幻影",
    icon = "👤",
    portrait = "Textures/monster_stele_phantom.png",
    zone = "ch5_stele_forest",
    category = "elite",
    race = "stele_spirit",
    level = 109,
    realm = "dacheng_2",  -- 大乘中期
    bodyColor = {130, 130, 150, 255},
    skills = { "ch5_stele_cross" },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 8, maxTier = 10, minQuality = "white", maxQuality = "cyan" },
        { chance = 0.24, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.50, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_shi_guanlan = {
    name = "守碑长老·石观澜",
    icon = "🏛️",
    portrait = "Textures/monster_shi_guanlan.png",
    zone = "ch5_stele_forest",
    category = "emperor_boss",
    race = "taixu_elder",
    level = 110,
    realm = "dacheng_3",  -- 大乘后期
    bodyColor = {100, 100, 120, 255},
    clawColor = {140, 140, 170},
    skillTextColor = {160, 160, 190, 255},
    warningColorOverride = {120, 120, 150, 120},
    phases = 2,
    skills = { "ch5_shi_stele_rain", "ch5_shi_stele_shock" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.4, speedMult = 1.2,
          announce = "石观澜凝碑为剑，万道剑痕齐鸣！",
          addSkill = "ch5_shi_stele_clone" },
        { threshold = 0.3, atkMult = 1.8, speedMult = 1.5, intervalMult = 0.5,
          announce = "万碑归一……剑痕化道！",
          triggerSkill = "ch5_shi_convergence" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 9, maxTier = 10, minQuality = "green", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {16, 28} },
        { chance = 0.80, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.01, type = "equipment", equipId = "guanlan_necklace_ch5" },  -- 观澜碑坠1%（橙）
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.01, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹1%（皇级）
        { chance = 0.01, type = "consumable", consumableId = "sword_intent_crystal" },  -- 剑星草1%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：生命书（特级）0.5%
        { chance = 0.005, type = "consumable", consumableId = "book_hp_4" },
    },
}

-- =====================================================================
-- ⑤ 栖剑别院 — 1普通 + 1精英 + 1BOSS    Lv.111~115
-- 别院中游荡的怨魂和巡逻的剑侍残骸
-- =====================================================================
M.Types.ch5_court_wraith = {
    name = "别院怨魂",
    icon = "💀",
    portrait = "Textures/monster_court_wraith.png",
    zone = "ch5_sword_court",
    category = "normal",
    race = "court_wraith",
    levelRange = {111, 114},
    realm = "dacheng_3",  -- 大乘后期
    bodyColor = {100, 80, 120, 255},
    dropTable = {
        { chance = 0.10, type = "equipment", minTier = 8, maxTier = 10, minQuality = "white", maxQuality = "purple" },
        { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
        { chance = 0.05, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_night_guard = {
    name = "夜巡剑侍",
    icon = "🌙",
    portrait = "Textures/monster_night_guard.png",
    zone = "ch5_sword_court",
    category = "elite",
    race = "court_wraith",
    level = 114,
    realm = "dacheng_3",  -- 大乘后期
    bodyColor = {80, 60, 110, 255},
    skills = { "ch5_moon_pierce" },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 8, maxTier = 10, minQuality = "white", maxQuality = "cyan" },
        { chance = 0.27, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.50, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_ning_qiwu = {
    name = "别院院主·宁栖梧",
    icon = "🌿",
    portrait = "Textures/monster_ning_qiwu.png",
    zone = "ch5_sword_court",
    category = "emperor_boss",
    race = "taixu_elder",
    level = 115,
    realm = "dacheng_4",  -- 大乘巅峰
    bodyColor = {60, 40, 90, 255},
    clawColor = {100, 80, 140},
    skillTextColor = {120, 100, 160, 255},
    warningColorOverride = {80, 60, 120, 120},
    phases = 2,
    skills = { "ch5_ning_dead_bloom", "ch5_ning_leaf_blade" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.4, speedMult = 1.2,
          announce = "宁栖梧枯坐千年，一朝拔剑惊天地！",
          addSkill = "ch5_ning_wood_prison" },
        { threshold = 0.3, atkMult = 1.8, speedMult = 1.5, intervalMult = 0.5,
          announce = "千年枯荣……梧桐泣血！",
          triggerSkill = "ch5_ning_withering" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 9, maxTier = 10, minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {18, 30} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.005, type = "equipment", equipId = "qijian_boots_ch5" },  -- 栖剑行靴0.5%（灵器）共享1%二选一
        { chance = 0.005, type = "equipment", equipId = "suxin_ring_ch5" },  -- 宿心残戒0.5%（橙）共享1%二选一
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.01, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹1%（皇级）
        { chance = 0.01, type = "consumable", consumableId = "sword_intent_crystal" },  -- 剑星草1%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：攻击书（特级）0.5%
        { chance = 0.005, type = "consumable", consumableId = "book_atk_4" },
    },
}

-- =====================================================================
-- ⑥ 藏经书阁 — 精英 + BOSS（无普通怪）   Lv.116~119
-- 书阁中的书妖和阁主残魂
-- =====================================================================
M.Types.ch5_book_demon = {
    name = "禁页书妖",
    icon = "📖",
    portrait = "Textures/monster_book_demon.png",
    zone = "ch5_library",
    category = "elite",
    race = "library_demon",
    level = 118,
    realm = "dacheng_4",  -- 大乘巅峰
    bodyColor = {180, 160, 100, 255},
    skills = { "ch5_ink_poison" },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 8, maxTier = 10, minQuality = "white", maxQuality = "cyan" },
        { chance = 0.30, type = "consumable", consumableId = "demon_essence" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.50, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_wen_suzhang = {
    name = "藏经阁主·温素章",
    icon = "📚",
    portrait = "Textures/monster_wen_suzhang.png",
    zone = "ch5_library",
    category = "emperor_boss",
    race = "taixu_elder",
    level = 119,
    realm = "dacheng_4",  -- 大乘巅峰
    bodyColor = {160, 140, 80, 255},
    clawColor = {200, 180, 100},
    skillTextColor = {220, 200, 120, 255},
    warningColorOverride = {180, 160, 90, 120},
    phases = 2,
    skills = { "ch5_wen_book_barrage", "ch5_wen_rune_blast" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.4, speedMult = 1.2,
          announce = "温素章翻动禁卷，万道灵文化为剑雨！",
          addSkill = "ch5_wen_ink_clone" },
        { threshold = 0.3, atkMult = 1.8, speedMult = 1.5, intervalMult = 0.5,
          announce = "禁典开启……万灵归墟！",
          triggerSkill = "ch5_wen_forbidden" },
    },
    dropTable = {
        { chance = 1.0, type = "equipment", minTier = 9, maxTier = 10, minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {20, 35} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.005, type = "equipment", equipId = "cangzhen_armor_ch5" },  -- 藏真玄衣0.5%（灵器）共享1%二选一
        { chance = 0.005, type = "equipment", equipId = "cangzhen_helmet_ch5" },  -- 藏真玄冠0.5%（灵器）共享1%二选一
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.01, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹1%（皇级）
        { chance = 0.01, type = "consumable", consumableId = "sword_intent_crystal" },  -- 剑星草1%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：蕴灵三书特级共享1.5%（每本0.5%）
        { chance = 0.015, type = "world_drop", pool = "wen_yunling_books" },
    },
}

-- =====================================================================
-- ⑦ 镇魔深渊 — 双BOSS结构（无普通怪/精英怪）  Lv.120
-- 裂渊屠血将（king_boss）+ 镇渊魔帅·噬渊血犼（emperor_boss）
-- =====================================================================
M.Types.ch5_blood_general = {
    name = "裂渊屠血将",
    icon = "🩸",
    portrait = "Textures/monster_blood_general.png",
    zone = "ch5_demon_abyss",
    category = "king_boss",
    race = "abyss_demon",
    level = 120,
    realm = "dacheng_4",  -- 大乘巅峰
    bodyColor = {180, 30, 30, 255},
    clawColor = {220, 60, 40},
    skillTextColor = {240, 80, 60, 255},
    warningColorOverride = {200, 40, 30, 120},
    phases = 2,
    skills = { "ch5_blood_cleave", "ch5_blood_whirl" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.3,
          announce = "裂渊屠血将鲜血沸腾，杀意滔天！",
          addSkill = "ch5_blood_eruption" },
    },
    tierOnly = 10,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {10, 10} },
        { chance = 0.50, type = "consumable", consumableId = "dragon_marrow" },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.0025, type = "equipment", equipId = "tuxue_belt_ch5" },  -- 屠血命绶0.25%（灵器）共享0.5%二选一
        { chance = 0.0025, type = "equipment", equipId = "tuxue_shoulder_ch5" },  -- 屠血魔肩0.25%（灵器）共享0.5%二选一
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.005, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹0.5%（血屠将）
        { chance = 0.002, type = "consumable", consumableId = "immortal_essence_blood" },  -- 仙人精血0.2%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
    },
}

M.Types.ch5_abyss_marshal = {
    name = "镇渊魔帅·噬渊血犼",
    icon = "👹",
    portrait = "Textures/monster_abyss_marshal.png",
    zone = "ch5_demon_abyss",
    category = "emperor_boss",
    race = "abyss_demon",
    level = 120,
    realm = "dujie_1",  -- 谪仙初期
    bodyColor = {120, 20, 40, 255},
    clawColor = {180, 40, 60},
    skillTextColor = {200, 60, 80, 255},
    warningColorOverride = {150, 30, 50, 120},
    phases = 2,
    skills = { "ch5_abyss_devour", "ch5_abyss_roar" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.6, speedMult = 1.3,
          announce = "噬渊血犼吞天噬地，深渊为之震颤！",
          addSkill = "ch5_abyss_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "噬天灭地……万劫不复！",
          triggerSkill = "ch5_abyss_annihilation" },
    },
    tierOnly = 10,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {25, 40} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", count = {1, 2} },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.01, type = "equipment", equipId = "shiyuan_cape_ch5" },  -- 噬渊魔氅1%（灵器）
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch5" },  -- 帝尊伍戒0.5%
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.02, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹2%（血犼）
        { chance = 0.01, type = "consumable", consumableId = "abyss_seal_shard" },  -- 地狱灵芝1%
        { chance = 0.01, type = "consumable", consumableId = "immortal_essence_blood" },  -- 仙人精血1%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：减伤+加伤特级共享1%（每本0.5%）
        { chance = 0.01, type = "world_drop", pool = "abyss_marshal_books" },
    },
}

-- =====================================================================
-- ⑧ 四封剑台 — 4× saint_boss    Lv.120（暂不刷新）
-- 诛仙剑 / 陷仙剑 / 戮仙剑 / 绝仙剑
-- 数据注册但不添加刷新点，等后续开放
-- =====================================================================
M.Types.ch5_sword_zhu = {
    name = "诛仙剑",
    icon = "⚔️",
    portrait = "image/monster_sword_zhu_20260517104708.png",
    zone = "ch5_sword_palace",
    category = "saint_boss",
    race = "immortal_sword",
    level = 120,
    realm = "dujie_1",  -- 谪仙初期
    bodyColor = {200, 40, 40, 255},
    clawColor = {240, 80, 60},
    skillTextColor = {255, 100, 80, 255},
    warningColorOverride = {220, 60, 40, 120},
    phases = 3,
    stationary = true,
    attackRange = 6.0,
    groundSpike = {
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {200, 60, 40, 150},
    },
    skills = { "ch5_zhu_line", "ch5_zhu_cross_slash", "ch5_zhu_cross", "ch5_zhu_tracking" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          triggerSkill = "ch5_zhu_transition", addSkill = "ch5_zhu_core",
          announce = "诛仙剑嗡鸣震天，杀意弥漫！" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.6, intervalMult = 0.4,
          triggerSkill = "ch5_zhu_field",
          announce = "诛仙剑意——万物皆可诛！" },
    },
    tierOnly = 10,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "purple", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {30, 50} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", count = 3 },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.01, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch5" },       -- 帝尊伍戒0.5%
        { chance = 0.005, type = "equipment", equipId = "fengyin_zhuxian_ch5" },   -- 封印·诛仙0.5%
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.03, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹3%（四剑）
        { chance = 0.01, type = "consumable", consumableId = "abyss_seal_shard" },  -- 地狱灵芝1%
        { chance = 0.03, type = "consumable", consumableId = "immortal_essence_blood" },  -- 仙人精血3%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：通慧+忽视特级共享1%（每本0.5%）
        { chance = 0.01, type = "world_drop", pool = "sword_zhu_books" },
    },
}

M.Types.ch5_sword_xian = {
    name = "陷仙剑",
    icon = "⚔️",
    portrait = "image/monster_sword_xian_20260517104710.png",
    zone = "ch5_sword_palace",
    category = "saint_boss",
    race = "immortal_sword",
    level = 120,
    realm = "dujie_1",  -- 谪仙初期
    bodyColor = {40, 40, 200, 255},
    clawColor = {60, 80, 240},
    skillTextColor = {80, 100, 255, 255},
    warningColorOverride = {40, 60, 220, 120},
    phases = 3,
    stationary = true,
    attackRange = 6.0,
    groundSpike = {
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {40, 80, 200, 150},
    },
    skills = { "ch5_xian_frost_ring", "ch5_xian_mirror_slash", "ch5_xian_ice_prison", "ch5_xian_mirror_barrage" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          triggerSkill = "ch5_xian_transition", addSkill = "ch5_xian_core",
          announce = "陷仙剑布下陷阱，天罗地网！" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.6, intervalMult = 0.4,
          triggerSkill = "ch5_xian_field",
          announce = "陷仙剑意——陷天陷地陷众生！" },
    },
    tierOnly = 10,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "purple", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {30, 50} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", count = 3 },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.01, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch5" },       -- 帝尊伍戒0.5%
        { chance = 0.005, type = "equipment", equipId = "fengyin_xianxian_ch5" }, -- 封印·陷仙0.5%
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.03, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹3%（四剑）
        { chance = 0.01, type = "consumable", consumableId = "abyss_seal_shard" },  -- 地狱灵芝1%
        { chance = 0.03, type = "consumable", consumableId = "immortal_essence_blood" },  -- 仙人精血3%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：铸骨+连击特级共享1%（每本0.5%）
        { chance = 0.01, type = "world_drop", pool = "sword_xian_books" },
    },
}

M.Types.ch5_sword_lu = {
    name = "戮仙剑",
    icon = "⚔️",
    portrait = "image/edited_monster_sword_lu_20260517105112.png",
    zone = "ch5_sword_palace",
    category = "saint_boss",
    race = "immortal_sword",
    level = 120,
    realm = "dujie_1",  -- 谪仙初期
    bodyColor = {40, 160, 40, 255},
    clawColor = {60, 200, 60},
    skillTextColor = {80, 220, 80, 255},
    warningColorOverride = {40, 180, 40, 120},
    phases = 3,
    stationary = true,
    attackRange = 6.0,
    groundSpike = {
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {60, 180, 60, 150},
    },
    skills = { "ch5_lu_fire_vent", "ch5_lu_fire_ring", "ch5_lu_sword_rain", "ch5_lu_melt_line" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          triggerSkill = "ch5_lu_transition", addSkill = "ch5_lu_core",
          announce = "戮仙剑杀气冲天，血雾弥漫！" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.6, intervalMult = 0.4,
          triggerSkill = "ch5_lu_field",
          announce = "戮仙剑意——戮尽仙魔不留痕！" },
    },
    tierOnly = 10,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "purple", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {30, 50} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", count = 3 },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.01, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch5" },       -- 帝尊伍戒0.5%
        { chance = 0.005, type = "equipment", equipId = "fengyin_luxian_ch5" },   -- 封印·戮仙0.5%
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.03, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹3%（四剑）
        { chance = 0.01, type = "consumable", consumableId = "abyss_seal_shard" },  -- 地狱灵芝1%
        { chance = 0.03, type = "consumable", consumableId = "immortal_essence_blood" },  -- 仙人精血3%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：淬体+攻速特级共享1%（每本0.5%）
        { chance = 0.01, type = "world_drop", pool = "sword_lu_books" },
    },
}

M.Types.ch5_sword_jue = {
    name = "绝仙剑",
    icon = "⚔️",
    portrait = "image/monster_sword_jue_20260517104750.png",
    zone = "ch5_sword_palace",
    category = "saint_boss",
    race = "immortal_sword",
    level = 120,
    realm = "dujie_1",  -- 谪仙初期
    bodyColor = {160, 40, 160, 255},
    clawColor = {200, 60, 200},
    skillTextColor = {220, 80, 220, 255},
    warningColorOverride = {180, 40, 180, 120},
    phases = 3,
    stationary = true,
    attackRange = 6.0,
    groundSpike = {
        warningTime = 0.3,
        warningRange = 0.8,
        warningColor = {180, 60, 180, 150},
    },
    skills = { "ch5_jue_blood_chain", "ch5_jue_blood_mark", "ch5_jue_blood_mist", "ch5_jue_blood_slash" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.3, speedMult = 1.2,
          triggerSkill = "ch5_jue_transition", addSkill = "ch5_jue_core",
          announce = "绝仙剑逆天而起，断绝生机！" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.6, intervalMult = 0.4,
          triggerSkill = "ch5_jue_field",
          announce = "绝仙剑意——绝情绝义绝天道！" },
    },
    tierOnly = 10,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "purple", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {30, 50} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", count = 3 },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.01, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch5" },       -- 帝尊伍戒0.5%
        { chance = 0.005, type = "equipment", equipId = "fengyin_juexian_ch5" },  -- 封印·绝仙0.5%
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },  -- 灵兽丹·伍1%
        { chance = 0.03, type = "consumable", consumableId = "dujie_dan" },  -- 渡劫丹3%（四剑）
        { chance = 0.01, type = "consumable", consumableId = "abyss_seal_shard" },  -- 地狱灵芝1%
        { chance = 0.03, type = "consumable", consumableId = "immortal_essence_blood" },  -- 仙人精血3%
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：赐福+吸血特级共享1%（每本0.5%）
        { chance = 0.01, type = "world_drop", pool = "sword_jue_books" },
    },
}


-- =====================================================================
-- ⑨ 巡逻魔帅 — 2× emperor_boss    Lv.120 极谪仙境
-- 镇渊魔帅·蚀骨（别院外围）/ 镇渊魔帅·裂魂（碑林外围）
-- 掉落暂复用血犼；后续独立调整
-- =====================================================================
M.Types.ch5_marshal_shugu = {
    name = "镇渊魔帅·蚀骨",
    icon = "💀",
    portrait = "Textures/monster_abyss_marshal.png",
    zone = "ch5_sword_court",
    category = "emperor_boss",
    race = "abyss_demon",
    level = 120,
    realm = "dujie_1",  -- 谪仙初期
    bodyColor = {60, 10, 80, 255},
    clawColor = {140, 30, 180},
    skillTextColor = {180, 60, 220, 255},
    warningColorOverride = {100, 20, 140, 120},
    phases = 2,
    skills = { "ch5_abyss_devour", "ch5_abyss_roar" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.6, speedMult = 1.3,
          announce = "蚀骨魔帅骨裂天地，紫焰腐蚀万物！",
          addSkill = "ch5_abyss_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "蚀骨……万物皆腐，归于虚无！",
          triggerSkill = "ch5_abyss_annihilation" },
    },
    tierOnly = 10,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {25, 40} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", count = {1, 2} },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.01, type = "equipment", equipId = "lingqi_cape_ch5" },  -- 天渊灵披1%（灵器）
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch5" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },
        { chance = 0.02, type = "consumable", consumableId = "dujie_dan" },
        { chance = 0.01, type = "consumable", consumableId = "abyss_seal_shard" },  -- 地狱灵芝1%
        { chance = 0.01, type = "consumable", consumableId = "immortal_essence_blood" },
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：暴击+暴伤特级共享1%（每本0.5%），随机掉1本
        { chance = 0.01, type = "world_drop", pool = "shugu_books" },
    },
}

M.Types.ch5_marshal_liesoul = {
    name = "镇渊魔帅·裂魂",
    icon = "💀",
    portrait = "Textures/monster_abyss_marshal.png",
    zone = "ch5_stele_forest",
    category = "emperor_boss",
    race = "abyss_demon",
    level = 120,
    realm = "dujie_1",  -- 谪仙初期
    bodyColor = {30, 30, 90, 255},
    clawColor = {80, 80, 200},
    skillTextColor = {120, 120, 255, 255},
    warningColorOverride = {50, 50, 160, 120},
    phases = 2,
    skills = { "ch5_abyss_devour", "ch5_abyss_roar" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.6, speedMult = 1.3,
          announce = "裂魂魔帅魂裂九霄，阴寒贯穿碑林！",
          addSkill = "ch5_abyss_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "裂魂……千碑俱碎，魂魄无归！",
          triggerSkill = "ch5_abyss_annihilation" },
    },
    tierOnly = 10,
    dropTable = {
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        { chance = 1.0, type = "lingYun", amount = {25, 40} },
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", count = {1, 2} },
        { chance = 0.03, type = "world_drop", pool = "ch5" },
        { chance = 0.005, type = "consumable", consumableId = "gold_brick" },
        { chance = 0.01, type = "equipment", equipId = "lingqi_ring_ch5" },  -- 均灵环1%（灵器）
        { chance = 0.005, type = "equipment", equipId = "dizun_ring_ch5" },
        { chance = 0.01, type = "consumable", consumableId = "spirit_pill_5" },
        { chance = 0.02, type = "consumable", consumableId = "dujie_dan" },
        { chance = 0.01, type = "consumable", consumableId = "abyss_seal_shard" },  -- 地狱灵芝1%
        { chance = 0.01, type = "consumable", consumableId = "immortal_essence_blood" },
        { chance = 1.0, type = "consumable", consumableId = "taixu_jianling" },
        -- 宠物书：闪避+恢复特级共享1%（每本0.5%），随机掉1本
        { chance = 0.01, type = "world_drop", pool = "liesoul_books" },
    },
}

end
