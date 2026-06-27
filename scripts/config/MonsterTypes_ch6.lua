-- ============================================================================
-- MonsterTypes_ch6.lua - 第六章·两界村之影
-- ============================================================================
-- 本文件只注册第六章怪物基础身份：名字、区域、境界、品级、基础显示色。
-- 技能、专属掉落、头像路径暂不定，后续确认资源后再接入。
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)

-- 第六章：天界/影游/山灵/蛙族/魔君，先统一为 1.0 修正，避免提前展开数值平衡。
M.RaceModifiers.ch6_celestial_soldier = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }
M.RaceModifiers.ch6_shadow_spirit      = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }
M.RaceModifiers.ch6_mountain_spirit    = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }
M.RaceModifiers.ch6_frog_immortal      = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }
M.RaceModifiers.ch6_demon_lord         = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }

-- 羊肠小径
M.Types.ch6_patrol_immortal_soldier = {
    name = "巡逻仙兵",
    icon = "⚔",
    portrait = "image/monster_ch6_narrow_patrol_immortal_soldier_q_20260627083139.png",
    zone = "narrow_trail",
    category = "normal",
    race = "ch6_celestial_soldier",
    level = 121,
    realm = "dujie_1",
    bodyColor = {150, 175, 210, 255},
}

M.Types.ch6_lingfeng = {
    name = "巡游天神·凌风",
    icon = "🌪",
    portrait = "image/monster_ch6_narrow_lingfeng_q_20260627083109.png",
    zone = "narrow_trail",
    category = "king_boss",
    race = "ch6_celestial_soldier",
    level = 122,
    realm = "dujie_2",
    bodyColor = {120, 175, 230, 255},
    clawColor = {170, 220, 255},
    skillTextColor = {170, 220, 255, 255},
    warningColorOverride = {120, 180, 240, 120},
}

-- 影游荒原
M.Types.ch6_shadow_wanderer = {
    name = "影游使",
    icon = "☾",
    portrait = "image/monster_ch6_shadow_wanderer_q2_20260627085755.png",
    zone = "village_north_ruins",
    category = "normal",
    race = "ch6_shadow_spirit",
    levelRange = {122, 123},
    realm = "dujie_2",
    bodyColor = {70, 80, 125, 255},
}

M.Types.ch6_zhuyou = {
    name = "夜游神·烛幽",
    icon = "🌙",
    portrait = "image/monster_ch6_zhuyou_q2_20260627084954.png",
    zone = "village_north_ruins",
    category = "emperor_boss",
    race = "ch6_shadow_spirit",
    level = 124,
    realm = "dujie_4",
    bodyColor = {55, 65, 120, 255},
    clawColor = {130, 110, 210},
    skillTextColor = {170, 150, 240, 255},
    warningColorOverride = {110, 90, 190, 120},
}

-- 两界山
M.Types.ch6_mountain_colossus = {
    name = "山岭巨像",
    icon = "🗿",
    portrait = "image/monster_ch6_mountain_colossus_majestic_20260627093111.png",
    zone = "bandit_backhill",
    category = "normal",
    race = "ch6_mountain_spirit",
    levelRange = {124, 125},
    realm = "dujie_4",
    bodyColor = {125, 115, 95, 255},
}

M.Types.ch6_duanyue = {
    name = "两界山神·断岳",
    icon = "⛰",
    portrait = "image/monster_ch6_duanyue_majestic_20260627093145.png",
    zone = "bandit_backhill",
    category = "emperor_boss",
    race = "ch6_mountain_spirit",
    level = 126,
    realm = "dujie_4",
    bodyColor = {110, 100, 80, 255},
    clawColor = {180, 155, 95},
    skillTextColor = {210, 185, 120, 255},
    warningColorOverride = {160, 130, 80, 120},
}

-- 界守·西大营
M.Types.ch6_west_celestial_soldier = {
    name = "西营天兵",
    icon = "🛡",
    portrait = "image/monster_ch6_west_soldier_serious_20260627102843.png",
    zone = "bandit_camp",
    category = "normal",
    race = "ch6_celestial_soldier",
    levelRange = {126, 127},
    realm = "dujie_4",
    bodyColor = {165, 155, 115, 255},
}

M.Types.ch6_pojun = {
    name = "西大营天将·破军",
    icon = "戟",
    portrait = "image/monster_ch6_pojun_serious_20260627102842.png",
    zone = "bandit_camp",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 128,
    realm = "dujie_4",
    bodyColor = {175, 120, 85, 255},
    clawColor = {230, 140, 80},
    skillTextColor = {240, 160, 90, 255},
    warningColorOverride = {210, 120, 70, 120},
}

M.Types.ch6_zhenyuan = {
    name = "西大营天将·镇垣",
    icon = "盾",
    portrait = "image/monster_ch6_zhenyuan_serious_20260627102859.png",
    zone = "bandit_camp",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 129,
    realm = "dujie_4",
    bodyColor = {150, 135, 100, 255},
    clawColor = {210, 180, 110},
    skillTextColor = {230, 200, 130, 255},
    warningColorOverride = {190, 160, 100, 120},
}

M.Types.ch6_heng_marshal = {
    name = "哼元帅",
    icon = "哼",
    portrait = "image/monster_ch6_heng_marshal_comic_20260627102506.png",
    zone = "bandit_camp",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 140,
    realm = "dujie_4",
    bodyColor = {190, 125, 90, 255},
    clawColor = {255, 160, 95},
    skillTextColor = {255, 185, 110, 255},
    warningColorOverride = {230, 130, 80, 130},
}

-- 界守·东大营
M.Types.ch6_east_celestial_soldier = {
    name = "东营天兵",
    icon = "⚔",
    portrait = "image/monster_ch6_east_soldier_serious_20260627102841.png",
    zone = "spider_cave",
    category = "normal",
    race = "ch6_celestial_soldier",
    levelRange = {127, 128},
    realm = "dujie_4",
    bodyColor = {120, 160, 185, 255},
}

M.Types.ch6_qingfeng = {
    name = "东大营天将·青锋",
    icon = "刃",
    portrait = "image/monster_ch6_qingfeng_serious_20260627102842.png",
    zone = "spider_cave",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 129,
    realm = "dujie_4",
    bodyColor = {95, 150, 175, 255},
    clawColor = {120, 220, 230},
    skillTextColor = {150, 235, 240, 255},
    warningColorOverride = {100, 190, 210, 120},
}

M.Types.ch6_leice = {
    name = "东大营天将·雷策",
    icon = "雷",
    portrait = "image/monster_ch6_leice_serious_20260627103121.png",
    zone = "spider_cave",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 129,
    realm = "dujie_4",
    bodyColor = {105, 120, 190, 255},
    clawColor = {180, 200, 255},
    skillTextColor = {200, 215, 255, 255},
    warningColorOverride = {140, 160, 240, 120},
}

M.Types.ch6_ha_marshal = {
    name = "哈元帅",
    icon = "哈",
    portrait = "image/monster_ch6_ha_marshal_comic_20260627102518.png",
    zone = "spider_cave",
    category = "emperor_boss",
    race = "ch6_celestial_soldier",
    level = 140,
    realm = "dujie_4",
    bodyColor = {90, 150, 190, 255},
    clawColor = {130, 230, 255},
    skillTextColor = {160, 240, 255, 255},
    warningColorOverride = {100, 190, 230, 130},
}

-- 呱大人领地
M.Types.ch6_toad_immortal = {
    name = "蛤蟆仙人",
    icon = "蛙",
    portrait = "image/monster_ch6_toad_immortal_frog_ref_20260627104040.png",
    zone = "boar_forest",
    category = "boss",
    race = "ch6_frog_immortal",
    level = 129,
    realm = "dujie_4",
    bodyColor = {80, 150, 75, 255},
    clawColor = {140, 210, 100},
    skillTextColor = {170, 230, 120, 255},
    warningColorOverride = {110, 180, 90, 120},
}

M.Types.ch6_gua_master = {
    name = "呱大人",
    icon = "呱",
    portrait = "image/monster_ch6_gua_master_funny_ref_20260627104326.png",
    zone = "boar_forest",
    category = "saint_boss",
    race = "ch6_frog_immortal",
    level = 140,
    realm = "dujie_4",
    bodyColor = {70, 170, 75, 255},
    clawColor = {150, 240, 100},
    skillTextColor = {180, 255, 130, 255},
    warningColorOverride = {120, 210, 90, 140},
}

-- 封印的两界村
M.Types.ch6_mojun_shixuan = {
    name = "魔君·蚀玄",
    icon = "魔",
    portrait = "image/monster_ch6_mojun_shixuan_ref_darker_20260627105823.png",
    zone = "town",
    category = "saint_boss",
    race = "ch6_demon_lord",
    level = 140,
    realm = "dujie_4",
    bodyColor = {70, 35, 90, 255},
    clawColor = {180, 60, 220},
    skillTextColor = {220, 120, 255, 255},
    warningColorOverride = {150, 60, 190, 150},
}

end
