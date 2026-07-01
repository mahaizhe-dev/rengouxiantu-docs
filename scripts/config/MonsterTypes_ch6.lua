-- ============================================================================
-- MonsterTypes_ch6.lua - 第六章·两界村之影
-- ============================================================================
-- 本文件注册第六章怪物基础身份、头像、刷新档位和基础掉落。
-- 本轮接入随机装备；不接技能、世界掉落池或章节专属装备。
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)

-- 第六章：天界/影游/山灵/蛙族/魔君，先统一为 1.0 修正，保持设计表基础值。
M.RaceModifiers.ch6_celestial_soldier = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }
M.RaceModifiers.ch6_shadow_spirit      = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }
M.RaceModifiers.ch6_mountain_spirit    = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }
M.RaceModifiers.ch6_frog_immortal      = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }
M.RaceModifiers.ch6_demon_lord         = { hp = 0.87, atk = 1.0, def = 1.0, speed = 1.0 } -- demonBuff HP x1.5 => effective HP x1.305

local CH6_EQUIP_WINDOW_THREE = { 9, 10, 11 }
local CH6_EQUIP_WINDOW_TWO = { 10, 11 }
local CH6_EQUIP_WINDOW_XIAN1_ONLY = { 11 }

local function QualityRange(minQuality, maxQuality)
    return { minQuality = minQuality, maxQuality = maxQuality }
end

local CH6_EQUIP_COMMON_PURPLE = {
    [9] = QualityRange("green", "cyan"),
    [10] = QualityRange("white", "cyan"),
    [11] = QualityRange("white", "purple"),
}

local CH6_EQUIP_COMMON_ORANGE = {
    [9] = QualityRange("green", "cyan"),
    [10] = QualityRange("white", "cyan"),
    [11] = QualityRange("white", "orange"),
}

local CH6_EQUIP_COMMON_CYAN = {
    [9] = QualityRange("green", "cyan"),
    [10] = QualityRange("white", "cyan"),
    [11] = QualityRange("white", "cyan"),
}

local CH6_EQUIP_EMPEROR_PURPLE = {
    [10] = QualityRange("blue", "cyan"),
    [11] = QualityRange("green", "purple"),
}

local CH6_EQUIP_EMPEROR_ORANGE = {
    [10] = QualityRange("blue", "cyan"),
    [11] = QualityRange("green", "orange"),
}

local CH6_EQUIP_EMPEROR_CYAN = {
    [10] = QualityRange("blue", "cyan"),
    [11] = QualityRange("green", "cyan"),
}

local CH6_EQUIP_EMPEROR_RED = {
    [10] = QualityRange("blue", "cyan"),
    [11] = QualityRange("green", "red"),
}

local CH6_EQUIP_KING_CYAN = {
    [9] = QualityRange("blue", "cyan"),
    [10] = QualityRange("green", "cyan"),
    [11] = QualityRange("white", "cyan"),
}

local CH6_EQUIP_SAINT_RED = {
    [11] = QualityRange("purple", "red"),
}

local function EquipmentDrop(tierWindow, qualityByTier)
    return {
        chance = 1.0,
        type = "equipment",
        tierWindow = tierWindow,
        qualityByTier = qualityByTier,
    }
end

local function WorldDrop()
    return { chance = 1.0, type = "world_drop", pool = "ch6" }
end

local function EmperorRareWorldDrop()
    return { chance = 0.05, type = "world_drop", pool = "ch6_emperor_rare" }
end

local function ConsumableDrop(chance, consumableId, amount)
    local entry = { chance = chance, type = "consumable", consumableId = consumableId }
    if amount then entry.amount = amount end
    return entry
end

-- 羊肠小径
M.Types.ch6_patrol_immortal_soldier = {
    name = "巡逻仙兵",
    icon = "⚔️",
    portrait = "image/monster_ch6_narrow_patrol_immortal_soldier_q_20260627083139.png",
    zone = "narrow_trail",
    category = "boss",
    race = "ch6_celestial_soldier",
    levelRange = {121, 122},
    realm = "zhexian_1",
    respawnTime = 60,
    bodyColor = {150, 175, 210, 255},
    skills = { "qian_gang_sword", "rect_sweep" },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_PURPLE),
        { chance = 1.0, type = "lingYun", amount = {6, 10} },
        WorldDrop(),
        { chance = 0.20, type = "consumable", consumableId = "dragon_marrow" },
    },
}

M.Types.ch6_lingfeng = {
    name = "巡游天神·凌风",
    icon = "🌪️",
    portrait = "image/monster_ch6_narrow_lingfeng_q_20260627083109.png",
    zone = "narrow_trail",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 124,
    realm = "zhexian_2",
    respawnTime = 180,
    bodyColor = {120, 175, 230, 255},
    clawColor = {170, 220, 255},
    skillTextColor = {170, 220, 255, 255},
    warningColorOverride = {120, 180, 240, 120},
    phases = 2,
    skills = { "xun_wind_slash", "xun_phantom_dash" },
    phaseConfig = {
        { threshold = 0.3,
          announce = "凌风引动天雷，巡天之威骤临！",
          triggerSkill = "zhen_divine_thunder" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_PURPLE),
        { chance = 1.0, type = "lingYun", amount = {18, 30} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "immortal_essence_blood"),
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", amount = {2, 2} },
    },
}

-- 影游荒原
M.Types.ch6_shadow_wanderer = {
    name = "影游使",
    icon = "👻",
    portrait = "image/monster_ch6_shadow_wanderer_q2_20260627085755.png",
    zone = "village_north_ruins",
    category = "boss",
    race = "ch6_shadow_spirit",
    levelRange = {123, 126},
    realm = "zhexian_2",
    realmByLevel = {
        [123] = "zhexian_2", [124] = "zhexian_2",
        [125] = "zhexian_3", [126] = "zhexian_3",
    },
    respawnTime = 60,
    bodyColor = {70, 80, 125, 255},
    skills = { "ch5_shadow_thrust", "shen_vortex" },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_ORANGE),
        { chance = 1.0, type = "lingYun", amount = {8, 12} },
        WorldDrop(),
        { chance = 0.25, type = "consumable", consumableId = "dragon_marrow" },
    },
}

M.Types.ch6_zhuyou = {
    name = "夜游神·烛幽",
    icon = "🌙",
    portrait = "image/monster_ch6_zhuyou_q2_20260627084954.png",
    zone = "village_north_ruins",
    category = "emperor_boss",
    race = "ch6_shadow_spirit",
    level = 128,
    realm = "zhexian_4",
    respawnTime = 180,
    bodyColor = {55, 65, 120, 255},
    clawColor = {130, 110, 210},
    skillTextColor = {170, 150, 240, 255},
    warningColorOverride = {110, 90, 190, 120},
    phases = 2,
    skills = { "shen_vortex", "shen_maze" },
    phaseConfig = {
        { threshold = 0.3,
          announce = "烛幽没入夜影，幻灭之域骤然张开！",
          triggerSkill = "shen_annihilation" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_ORANGE),
        { chance = 1.0, type = "lingYun", amount = {24, 36} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "immortal_essence_blood"),
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", amount = {2, 3} },
    },
}

-- 两界山
M.Types.ch6_mountain_colossus = {
    name = "山岭巨像",
    icon = "🗿",
    portrait = "image/monster_ch6_mountain_colossus_majestic_20260627093111.png",
    zone = "bandit_backhill",
    category = "boss",
    race = "ch6_mountain_spirit",
    levelRange = {127, 130},
    realm = "zhexian_4",
    realmByLevel = {
        [127] = "zhexian_4", [128] = "zhexian_4",
        [129] = "zhexian_5", [130] = "zhexian_5",
    },
    respawnTime = 60,
    bodyColor = {125, 115, 95, 255},
    skills = { "gen_rock_slam", "gen_avalanche" },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_ORANGE),
        { chance = 1.0, type = "lingYun", amount = {10, 15} },
        WorldDrop(),
        { chance = 0.30, type = "consumable", consumableId = "dragon_marrow" },
    },
}

M.Types.ch6_duanyue = {
    name = "两界山神·断岳",
    icon = "⛰️",
    portrait = "image/monster_ch6_duanyue_majestic_20260627093145.png",
    zone = "bandit_backhill",
    category = "emperor_boss",
    race = "ch6_mountain_spirit",
    level = 132,
    realm = "zhexian_6",
    respawnTime = 180,
    bodyColor = {110, 100, 80, 255},
    clawColor = {180, 155, 95},
    skillTextColor = {210, 185, 120, 255},
    warningColorOverride = {160, 130, 80, 120},
    phases = 3,
    skills = { "gen_rock_slam", "gen_stone_wall" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.2, speedMult = 1.1,
          announce = "断岳踏碎山根，乱石自地脉中翻涌！",
          addSkill = "gen_avalanche" },
        { threshold = 0.3, atkMult = 1.45, speedMult = 1.2, intervalMult = 0.75,
          announce = "断岳唤醒两界山脉，厚土之力压向四方！",
          addSkill = "kun_earth_surge" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_CYAN),
        { chance = 1.0, type = "lingYun", amount = {30, 45} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "immortal_essence_blood"),
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", amount = {3, 3} },
    },
}

-- 界守·西大营
M.Types.ch6_west_celestial_soldier = {
    name = "西营天兵",
    icon = "🛡️",
    portrait = "image/monster_ch6_west_soldier_serious_20260627102843.png",
    zone = "bandit_camp",
    category = "boss",
    race = "ch6_celestial_soldier",
    levelRange = {131, 136},
    realm = "zhexian_6",
    realmByLevel = {
        [131] = "zhexian_6", [132] = "zhexian_6",
        [133] = "zhexian_7", [134] = "zhexian_7",
        [135] = "zhexian_8", [136] = "zhexian_8",
    },
    respawnTime = 60,
    bodyColor = {165, 155, 115, 255},
    skills = { "rect_sweep", "qian_heaven_toss" },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_CYAN),
        { chance = 1.0, type = "lingYun", amount = {12, 18} },
        WorldDrop(),
        { chance = 0.35, type = "consumable", consumableId = "dragon_marrow" },
    },
}

M.Types.ch6_pojun = {
    name = "西大营天将·破军",
    icon = "⚔️",
    portrait = "image/monster_ch6_pojun_serious_20260627102842.png",
    zone = "bandit_camp",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 137,
    realm = "zhexian_8",
    respawnTime = 180,
    bodyColor = {175, 120, 85, 255},
    clawColor = {230, 140, 80},
    skillTextColor = {240, 160, 90, 255},
    warningColorOverride = {210, 120, 70, 120},
    phases = 3,
    skills = { "qian_gang_sword", "qian_heaven_toss" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.25, speedMult = 1.1,
          announce = "破军剑势压境，十字杀路封断退路！",
          addSkill = "ch5_zhu_cross" },
        { threshold = 0.3, atkMult = 1.55, speedMult = 1.2, intervalMult = 0.7,
          announce = "破军杀意入阵，追命剑标连落！",
          addSkill = "ch5_zhu_tracking" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {36, 48} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "immortal_essence_blood"),
        { chance = 1.0, type = "consumable", consumableId = "immortal_beast_soul", amount = {1, 1} },
    },
}

M.Types.ch6_zhenyuan = {
    name = "西大营天将·镇垣",
    icon = "🛡️",
    portrait = "image/monster_ch6_zhenyuan_serious_20260627102859.png",
    zone = "bandit_camp",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 138,
    realm = "zhexian_8",
    respawnTime = 180,
    bodyColor = {150, 135, 100, 255},
    clawColor = {210, 180, 110},
    skillTextColor = {230, 200, 130, 255},
    warningColorOverride = {190, 160, 100, 120},
    phases = 3,
    skills = { "shield_slam", "qian_taixu_palm" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.2, speedMult = 1.05,
          announce = "镇垣举盾立阵，横扫之势压住前路！",
          addSkill = "rect_sweep" },
        { threshold = 0.3, atkMult = 1.45, speedMult = 1.15, intervalMult = 0.75,
          announce = "镇垣引天罡镇压，山岳般的剑势坠下！",
          addSkill = "qian_heaven_toss" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {36, 48} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "immortal_essence_blood"),
        { chance = 1.0, type = "consumable", consumableId = "immortal_beast_soul", amount = {1, 1} },
    },
}

M.Types.ch6_heng_marshal = {
    name = "哼元帅",
    icon = "👑",
    portrait = "image/monster_ch6_heng_marshal_comic_20260627102506.png",
    zone = "bandit_camp",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 140,
    realm = "renxian_1",
    respawnTime = 180,
    bodyColor = {190, 125, 90, 255},
    clawColor = {255, 160, 95},
    skillTextColor = {255, 185, 110, 255},
    warningColorOverride = {230, 130, 80, 130},
    phases = 3,
    skills = { "tiger_roar", "zhen_thunder_roar" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.2, speedMult = 1.1,
          announce = "哼元帅声震西营，追命剑标接连落下！",
          addSkill = "ch5_zhu_tracking" },
        { threshold = 0.3, state = "berserk",
          announce = "哼元帅怒声贯耳，狂暴之势骤起！",
          berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
          addSkill = "zhen_thunder_pierce" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {40, 60} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "shadow_crystal"),
        { chance = 1.0, type = "consumable", consumableId = "immortal_beast_soul", amount = {1, 2} },
    },
}

-- 界守·东大营
M.Types.ch6_east_celestial_soldier = {
    name = "东营天兵",
    icon = "⚔️",
    portrait = "image/monster_ch6_east_soldier_serious_20260627102841.png",
    zone = "spider_cave",
    category = "boss",
    race = "ch6_celestial_soldier",
    levelRange = {131, 136},
    realm = "zhexian_6",
    realmByLevel = {
        [131] = "zhexian_6", [132] = "zhexian_6",
        [133] = "zhexian_7", [134] = "zhexian_7",
        [135] = "zhexian_8", [136] = "zhexian_8",
    },
    respawnTime = 60,
    bodyColor = {120, 160, 185, 255},
    skills = { "zhen_thunder_pierce", "xun_wind_slash" },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_CYAN),
        { chance = 1.0, type = "lingYun", amount = {12, 18} },
        WorldDrop(),
        { chance = 0.35, type = "consumable", consumableId = "dragon_marrow" },
    },
}

M.Types.ch6_qingfeng = {
    name = "东大营天将·青锋",
    icon = "🗡️",
    portrait = "image/monster_ch6_qingfeng_serious_20260627102842.png",
    zone = "spider_cave",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 137,
    realm = "zhexian_8",
    respawnTime = 180,
    bodyColor = {95, 150, 175, 255},
    clawColor = {120, 220, 230},
    skillTextColor = {150, 235, 240, 255},
    warningColorOverride = {100, 190, 210, 120},
    phases = 3,
    skills = { "qian_gang_sword", "xun_wind_slash" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.25, speedMult = 1.15,
          announce = "青锋剑影加急，残影突刺逼近要害！",
          addSkill = "ch5_shadow_thrust" },
        { threshold = 0.3, atkMult = 1.55, speedMult = 1.25, intervalMult = 0.7,
          announce = "青锋斩开东营风雷，横天断命！",
          addSkill = "ch5_zhu_cross_slash" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {36, 48} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "immortal_essence_blood"),
        { chance = 1.0, type = "consumable", consumableId = "immortal_beast_soul", amount = {1, 1} },
    },
}

M.Types.ch6_leice = {
    name = "东大营天将·雷策",
    icon = "⚡",
    portrait = "image/monster_ch6_leice_serious_20260627103121.png",
    zone = "spider_cave",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 138,
    realm = "zhexian_8",
    respawnTime = 180,
    bodyColor = {105, 120, 190, 255},
    clawColor = {180, 200, 255},
    skillTextColor = {200, 215, 255, 255},
    warningColorOverride = {140, 160, 240, 120},
    phases = 3,
    skills = { "zhen_thunder_pierce", "zhen_thunder_roar" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.25, speedMult = 1.1,
          announce = "雷策引天罡入雷，十字雷痕压落！",
          addSkill = "qian_heaven_toss" },
        { threshold = 0.3, atkMult = 1.55, speedMult = 1.2, intervalMult = 0.7,
          announce = "雷策雷令急转，追命雷标连环轰落！",
          addSkill = "ch5_zhu_tracking" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {36, 48} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "immortal_essence_blood"),
        { chance = 1.0, type = "consumable", consumableId = "immortal_beast_soul", amount = {1, 1} },
    },
}

M.Types.ch6_ha_marshal = {
    name = "哈元帅",
    icon = "👑",
    portrait = "image/monster_ch6_ha_marshal_comic_20260627102518.png",
    zone = "spider_cave",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 140,
    realm = "renxian_1",
    respawnTime = 180,
    bodyColor = {90, 150, 190, 255},
    clawColor = {130, 230, 255},
    skillTextColor = {160, 240, 255, 255},
    warningColorOverride = {100, 190, 230, 130},
    phases = 3,
    skills = { "zhen_thunder_roar", "ch5_abyss_roar" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.2, speedMult = 1.1,
          announce = "哈元帅吐声成雷，追命剑标破空而下！",
          addSkill = "ch5_zhu_tracking" },
        { threshold = 0.3, state = "berserk",
          announce = "哈元帅长啸震营，狂暴之势骤起！",
          berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
          addSkill = "zhen_thunder_pierce" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {40, 60} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.01, "shadow_crystal"),
        { chance = 1.0, type = "consumable", consumableId = "immortal_beast_soul", amount = {1, 2} },
    },
}

-- 呱大人领地
M.Types.ch6_toad_immortal = {
    name = "蛤蟆仙人",
    icon = "🐸",
    portrait = "image/monster_ch6_toad_immortal_frog_ref_20260627104040.png",
    zone = "boar_forest",
    category = "king_boss",
    race = "ch6_frog_immortal",
    levelRange = {137, 139},
    realm = "zhexian_8",
    realmByLevel = {
        [137] = "zhexian_8", [138] = "zhexian_8",
        [139] = "zhexian_9",
    },
    respawnTime = 120,
    bodyColor = {80, 150, 75, 255},
    clawColor = {140, 210, 100},
    skillTextColor = {170, 230, 120, 255},
    warningColorOverride = {110, 180, 90, 120},
    skills = { "yanchan_quake", "yanchan_venom_spray", "ch5_rock_scatter" },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_KING_CYAN),
        { chance = 1.0, type = "lingYun", amount = {20, 30} },
        WorldDrop(),
        { chance = 1.0, type = "consumable", consumableId = "dragon_marrow", amount = {1, 1} },
    },
}

M.Types.ch6_gua_master = {
    name = "呱大人",
    icon = "🐸",
    portrait = "image/monster_ch6_gua_master_funny_ref_20260627104326.png",
    zone = "boar_forest",
    category = "saint_boss",
    race = "ch6_frog_immortal",
    level = 140,
    realm = "renxian_1",
    respawnTime = 180,
    bodyColor = {70, 170, 75, 255},
    clawColor = {150, 240, 100},
    skillTextColor = {180, 255, 130, 255},
    warningColorOverride = {120, 210, 90, 140},
    phases = 3,
    skills = { "yanchan_quake", "yanchan_venom_spray", "ch6_gua_toxic_orbs", "ch6_gua_swamp_cross" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.25, speedMult = 1.1,
          announce = "呱大人鼓动毒潭，毒泡连爆四散！",
          addSkill = "ch6_gua_toxic_burst" },
        { threshold = 0.3, atkMult = 1.55, speedMult = 1.2, intervalMult = 0.75,
          announce = "万沼归潭，呱声压过两界！",
          triggerSkill = "ch6_gua_domain_burst",
          addSkill = "ch6_gua_domain_cycle" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_XIAN1_ONLY, CH6_EQUIP_SAINT_RED),
        { chance = 1.0, type = "lingYun", amount = {60, 80} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.02, "shadow_crystal"),
        { chance = 1.0, type = "consumable", consumableId = "immortal_beast_soul", amount = {2, 2} },
    },
}

-- 封印的两界村
M.Types.ch6_mojun_shixuan = {
    name = "魔君·蚀玄",
    icon = "👹",
    portrait = "image/monster_ch6_mojun_shixuan_ref_darker_20260627105823.png",
    zone = "town",
    category = "saint_boss",
    race = "ch6_demon_lord",
    level = 140,
    realm = "renxian_1",
    respawnTime = 180,
    bodyColor = {70, 35, 90, 255},
    clawColor = {180, 60, 220},
    skillTextColor = {220, 120, 255, 255},
    warningColorOverride = {150, 60, 190, 150},
    demonBuff = true,
    phases = 3,
    skills = { "ch5_jue_blood_mark", "ch5_jue_blood_slash", "ch6_shixuan_shadow_cross", "ch6_shixuan_seal_line" },
    phaseConfig = {
        { threshold = 0.7, atkMult = 1.25, speedMult = 1.1,
          announce = "蚀玄展开影界，玄影裂痕吞向四方！",
          addSkill = "ch6_shixuan_void_collapse" },
        { threshold = 0.3, atkMult = 1.55, speedMult = 1.2,
          announce = "两界封梦，魔君蚀玄撕开封印！",
          triggerSkill = "ch6_shixuan_dream_burst",
          addSkill = "ch6_shixuan_dream_cycle" },
    },
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_XIAN1_ONLY, CH6_EQUIP_SAINT_RED),
        { chance = 1.0, type = "lingYun", amount = {60, 90} },
        WorldDrop(),
        EmperorRareWorldDrop(),
        ConsumableDrop(0.02, "shadow_crystal"),
        { chance = 1.0, type = "consumable", consumableId = "immortal_beast_soul", amount = {2, 3} },
    },
}

local ch6TypeIds = {
    "ch6_patrol_immortal_soldier",
    "ch6_lingfeng",
    "ch6_shadow_wanderer",
    "ch6_zhuyou",
    "ch6_mountain_colossus",
    "ch6_duanyue",
    "ch6_west_celestial_soldier",
    "ch6_pojun",
    "ch6_zhenyuan",
    "ch6_heng_marshal",
    "ch6_east_celestial_soldier",
    "ch6_qingfeng",
    "ch6_leice",
    "ch6_ha_marshal",
    "ch6_toad_immortal",
    "ch6_gua_master",
    "ch6_mojun_shixuan",
}

local localRespawnBossIds = {
    "ch6_patrol_immortal_soldier",
    "ch6_shadow_wanderer",
    "ch6_mountain_colossus",
    "ch6_west_celestial_soldier",
    "ch6_east_celestial_soldier",
    "ch6_toad_immortal",
}

for _, typeId in ipairs(ch6TypeIds) do
    local data = M.Types[typeId]
    if data then
        data["chapter"] = 6
    end
end

for _, typeId in ipairs(localRespawnBossIds) do
    local data = M.Types[typeId]
    if data then
        data["localRespawn"] = true
    end
end

end
