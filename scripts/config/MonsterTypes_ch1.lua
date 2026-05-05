-- ============================================================================
-- MonsterTypes_ch1.lua - 第一章怪物类型定义
-- 羊肠小径 · 蜘蛛洞 · 野猪林 · 山贼寨 · 虎啸林
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    M.Types.spider_trail = {
        name = "小蜘蛛",
        icon = "🕷️",
        portrait = "Textures/monster_spider_trail.png",
        zone = "narrow_trail",
        category = "normal",
        race = "spider",
        levelRange = {1, 3},
        bodyColor = {80, 60, 50, 255},
        dropTable = {
            { chance = 0.1, type = "equipment", minQuality = "white", maxQuality = "green" },
            { chance = 0.65, type = "consumable", consumableId = "meat_bone" },
        },
    }

    -- ===================== 蜘蛛洞 Lv.3~5 + 精英6 =====================
    M.Types.spider_small = {
        name = "小蜘蛛",
        icon = "🕷️",
        portrait = "Textures/monster_spider_small.png",
        zone = "spider_cave",
        category = "normal",
        race = "spider",
        levelRange = {3, 5},
        bodyColor = {80, 60, 50, 255},
        dropTable = {
            { chance = 0.1, type = "equipment", minQuality = "white", maxQuality = "green" },
            { chance = 0.65, type = "consumable", consumableId = "meat_bone" },
        },
    }
    M.Types.spider_elite = {
        name = "毒蛛精",
        icon = "🕷️",
        portrait = "Textures/monster_spider_elite.png",
        zone = "spider_cave",
        category = "elite",
        race = "spider",
        level = 6,
        bodyColor = {120, 40, 120, 255},
        skills = { "poison_spit" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "blue" },
            { chance = 0.20, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.005, type = "world_drop", pool = "ch1" },  -- 世界掉落0.5%
        },
    }

    -- ===================== 蜘蛛巢穴 精英6 + BOSS8 =====================
    M.Types.spider_queen = {
        name = "蛛母",
        icon = "🕸️",
        portrait = "Textures/monster_spider_queen.png",
        zone = "spider_cave",
        category = "boss",
        race = "spider",
        level = 8,
        respawnTime = 90,  -- 第1章BOSS: 1分30秒
        bodyColor = {160, 50, 160, 255},
        phases = 2,
        skills = { "poison_spit" },
        phaseConfig = {
            { threshold = 0.5, atkMult = 1.4, speedMult = 1.3, intervalMult = 0.6,
              announce = "蛛母发出刺耳的尖啸！",
              addSkill = "cross_smash" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 0.30, type = "lingYun", amount = {1, 1} },
            { chance = 0.30, type = "consumable", consumableId = "spirit_meat" },
            -- ②专属材料
            { chance = 0.10, type = "consumable", consumableId = "spirit_pill" },
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "purple" },
            -- ④专属装备
            { chance = 0.12, type = "equipment", equipId = "spider_queen_ring", quality = "purple" },
            -- ⑤世界掉落
            { chance = 0.01, type = "world_drop", pool = "ch1" },
        },
    }

    -- ===================== 野猪林 Lv.6~8 + 精英9 + BOSS10 =====================
    M.Types.boar_small = {
        name = "野猪",
        icon = "🐗",
        portrait = "Textures/monster_boar_small.png",
        zone = "boar_forest",
        category = "normal",
        race = "boar",
        levelRange = {6, 8},
        bodyColor = {120, 80, 50, 255},
        dropTable = {
            { chance = 0.1, type = "equipment", minQuality = "white", maxQuality = "green" },
            { chance = 0.50, type = "consumable", consumableId = "meat_bone" },
            { chance = 0.10, type = "consumable", consumableId = "spirit_meat" },
        },
    }
    M.Types.boar_captain = {
        name = "野猪统领",
        icon = "🐗",
        portrait = "Textures/monster_boar_captain.png",
        zone = "boar_forest",
        category = "elite",
        race = "boar",
        level = 9,
        bodyColor = {160, 100, 50, 255},
        skills = { "rect_sweep" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "blue" },
            { chance = 0.20, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.005, type = "world_drop", pool = "ch1" },  -- 世界掉落0.5%
        },
    }
    M.Types.boar_king = {
        name = "猪三哥",
        icon = "🐗",
        portrait = "Textures/monster_boar_king.png",
        zone = "boar_forest",
        category = "boss",
        race = "boar",
        level = 10,
        respawnTime = 90,  -- 第1章BOSS: 1分30秒
        bodyColor = {180, 100, 40, 255},
        phases = 2,
        skills = { "rect_sweep" },
        phaseConfig = {
            { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
              announce = "猪三哥暴怒了！",
              addSkill = "ground_pound" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 0.60, type = "lingYun", amount = {1, 1} },
            { chance = 0.35, type = "consumable", consumableId = "spirit_meat" },
            -- ②专属材料
            { chance = 0.20, type = "consumable", consumableId = "spirit_pill" },
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "purple" },
            -- ④专属装备
            { chance = 0.10, type = "equipment", equipId = "boar_king_weapon", quality = "purple" },
            -- ⑤世界掉落
            { chance = 0.01, type = "world_drop", pool = "ch1" },
        },
    }

    -- ===================== 山贼寨主寨 Lv.8~12 =====================
    M.Types.bandit_small = {
        name = "山贼",
        icon = "🗡️",
        portrait = "Textures/monster_bandit_small.png",
        zone = "bandit_camp",
        category = "normal",
        race = "bandit",
        levelRange = {8, 10},
        bodyColor = {100, 70, 60, 255},
        dropTable = {
            { chance = 0.1, type = "equipment", minQuality = "white", maxQuality = "green" },
            { chance = 0.50, type = "consumable", consumableId = "meat_bone" },
            { chance = 0.10, type = "consumable", consumableId = "spirit_meat" },
        },
    }
    M.Types.bandit_guard = {
        name = "山贼护卫",
        icon = "🛡️",
        portrait = "Textures/monster_bandit_guard.png",
        zone = "bandit_camp",
        category = "normal",
        race = "bandit",
        levelRange = {11, 13},
        realm = "lianqi_1",  -- 练气初期
        bodyColor = {110, 80, 60, 255},
        skills = { "shield_bash" },
        dropTable = {
            { chance = 0.15, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.25, type = "consumable", consumableId = "meat_bone" },
            { chance = 0.08, type = "consumable", consumableId = "spirit_meat" },
        },
    }
    M.Types.bandit_second = {
        name = "二大王",
        icon = "⚔️",
        portrait = "Textures/monster_bandit_second.png",
        zone = "bandit_camp",
        category = "elite",
        race = "bandit",
        level = 11,
        realm = "lianqi_1",  -- 练气初期
        bodyColor = {140, 70, 50, 255},
        skills = { "whirlwind" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.18, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.005, type = "world_drop", pool = "ch1" },  -- 世界掉落0.5%
        },
    }
    M.Types.bandit_strategist = {
        name = "军师",
        icon = "📖",
        portrait = "Textures/monster_bandit_strategist.png",
        zone = "bandit_camp",
        category = "elite",
        race = "bandit",
        level = 12,
        realm = "lianqi_1",  -- 练气初期
        bodyColor = {90, 80, 100, 255},
        skills = { "fan_strike" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.20, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.005, type = "world_drop", pool = "ch1" },  -- 世界掉落0.5%
        },
    }

    -- ===================== 山贼寨后山 Lv.11~15 =====================
    M.Types.bandit_guard_back = {
        name = "山贼护卫",
        icon = "🛡️",
        portrait = "Textures/monster_bandit_guard.png",
        zone = "bandit_backhill",
        category = "normal",
        race = "bandit",
        levelRange = {11, 13},
        realm = "lianqi_1",  -- 练气初期
        bodyColor = {120, 85, 65, 255},
        skills = { "shield_bash" },
        dropTable = {
            { chance = 0.15, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.25, type = "consumable", consumableId = "meat_bone" },
            { chance = 0.08, type = "consumable", consumableId = "spirit_meat" },
        },
    }
    M.Types.bandit_chief = {
        name = "大大王",
        icon = "👑",
        portrait = "Textures/monster_bandit_boss.png",
        zone = "bandit_backhill",
        category = "boss",
        race = "bandit",
        level = 15,
        respawnTime = 90,  -- 第1章BOSS: 1分30秒
        realm = "lianqi_1",  -- 练气初期
        bodyColor = {150, 60, 60, 255},
        phases = 2,
        skills = { "shield_slam" },
        phaseConfig = {
            -- 阶段2: HP<50% 暴怒 + 冲锋突刺
            { threshold = 0.5, atkMult = 1.5, speedMult = 1.3,
              announce = "大大王怒发冲冠！",
              addSkill = "line_charge" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.25, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.03, type = "consumable", consumableId = "immortal_bone" },
            -- ②专属材料
            { chance = 0.05, type = "consumable", consumableId = "qi_pill" },
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "purple" },
            -- ④专属装备
            { chance = 0.10, type = "equipment", equipId = "boss_cape", quality = "purple" },
            -- ⑤世界掉落
            { chance = 0.01, type = "world_drop", pool = "ch1" },
        },
    }

    -- ===================== 虎啸林 Lv.13~16 =====================
    M.Types.tiger_elite = {
        name = "猛虎",
        icon = "🐅",
        portrait = "Textures/monster_tiger_elite.png",
        zone = "tiger_domain",
        category = "elite",
        race = "tiger",
        levelRange = {13, 15},
        realm = "lianqi_1",  -- 练气初期
        bodyColor = {200, 150, 60, 255},
        skills = { "tiger_claw" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.15, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.005, type = "world_drop", pool = "ch1" },  -- 世界掉落0.5%
        },
    }
    M.Types.tiger_king = {
        name = "虎王",
        icon = "🐅",
        portrait = "Textures/monster_tiger_king.png",
        zone = "tiger_domain",
        category = "king_boss",
        race = "tiger",
        level = 16,
        respawnTime = 90,  -- 第1章BOSS: 1分30秒
        realm = "lianqi_2",  -- 练气中期
        bodyColor = {220, 160, 40, 255},
        phases = 3,
        skills = { "tiger_claw" },
        phaseConfig = {
            -- 阶段2: HP<70% 虎啸
            { threshold = 0.7, atkMult = 1.3, announce = "虎王发出震耳虎啸！",
              addSkill = "tiger_roar" },
            -- 阶段3: HP<30% 暴怒 + 十字裂地
            { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.5,
              announce = "虎王陷入疯狂暴怒！",
              addSkill = "cross_smash" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.50, type = "lingYun", amount = {1, 1} },
            { chance = 0.20, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.05, type = "consumable", consumableId = "immortal_bone" },
            -- ②专属材料
            { chance = 0.50, type = "consumable", consumableId = "spirit_pill", amount = {1, 2} },
            { chance = 0.05, type = "world_drop", pool = "tiger_books" },  -- 中级技能书5%（随机1本）
            { chance = 0.05, type = "consumable", consumableId = "tiger_bone" },  -- 虎骨5%
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "purple" },
            -- ④专属装备
            { chance = 0.10, type = "equipment", equipId = "tiger_set_weapon", quality = "purple" },
            { chance = 0.10, type = "equipment", equipId = "tiger_set_armor", quality = "purple" },
            { chance = 0.05, type = "equipment", equipId = "tiger_set_necklace", quality = "orange" },
            -- ⑤练气丹（5%掉落）
            { chance = 0.05, type = "consumable", consumableId = "qi_pill" },
            -- ⑥帝尊壹戒（3%独立掉落）
            { chance = 0.03, type = "equipment", equipId = "dizun_ring_ch1" },
            -- ⑦世界掉落
            { chance = 0.01, type = "world_drop", pool = "ch1" },
        },
    }
end
