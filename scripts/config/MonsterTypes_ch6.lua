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
M.RaceModifiers.ch6_demon_lord         = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }

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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_PURPLE),
        { chance = 1.0, type = "lingYun", amount = {6, 10} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_PURPLE),
        { chance = 1.0, type = "lingYun", amount = {18, 30} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_ORANGE),
        { chance = 1.0, type = "lingYun", amount = {8, 12} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_ORANGE),
        { chance = 1.0, type = "lingYun", amount = {24, 36} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_ORANGE),
        { chance = 1.0, type = "lingYun", amount = {10, 15} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_CYAN),
        { chance = 1.0, type = "lingYun", amount = {30, 45} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_CYAN),
        { chance = 1.0, type = "lingYun", amount = {12, 18} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {36, 48} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {36, 48} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {40, 60} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_COMMON_CYAN),
        { chance = 1.0, type = "lingYun", amount = {12, 18} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {36, 48} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {36, 48} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_TWO, CH6_EQUIP_EMPEROR_RED),
        { chance = 1.0, type = "lingYun", amount = {40, 60} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_THREE, CH6_EQUIP_KING_CYAN),
        { chance = 1.0, type = "lingYun", amount = {20, 30} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_XIAN1_ONLY, CH6_EQUIP_SAINT_RED),
        { chance = 1.0, type = "lingYun", amount = {60, 80} },
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
    dropTable = {
        EquipmentDrop(CH6_EQUIP_WINDOW_XIAN1_ONLY, CH6_EQUIP_SAINT_RED),
        { chance = 1.0, type = "lingYun", amount = {60, 90} },
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
