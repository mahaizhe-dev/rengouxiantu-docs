-- ============================================================================
-- MonsterTypes_ch2.lua - 第二章怪物类型定义
-- 野外 · 野猪坡 · 毒蛇沼 · 修罗场 · 乌堡 · 荒野被动怪
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    -- ===================== 第二章：野外 Lv.16~20 =====================
    M.Types.swamp_snake = {
        name = "沼泽毒蛇",
        icon = "🐍",
        portrait = "Textures/monster_swamp_snake.png",
        zone = "wilderness_ch2",
        category = "normal",
        race = "snake",
        levelRange = {16, 20},
        realm = "lianqi_1",  -- 练气初期
        bodyColor = {40, 100, 40, 255},
        dropTable = {
            { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.10, type = "consumable", consumableId = "spirit_meat" },
        },
    }

    -- ===================== 第二章：野猪坡 Lv.16~20 =====================
    M.Types.black_boar = {
        name = "黑野猪",
        icon = "🐗",
        portrait = "Textures/monster_black_boar.png",
        zone = "boar_slope",
        category = "normal",
        race = "boar",
        levelRange = {16, 19},
        realm = "lianqi_1",  -- 练气初期
        bodyColor = {60, 50, 40, 255},
        dropTable = {
            { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.10, type = "consumable", consumableId = "spirit_meat" },
        },
    }
    M.Types.red_boar_elite = {
        name = "赤鬃野猪",
        icon = "🐗",
        portrait = "Textures/monster_red_boar.png",
        zone = "boar_slope",
        category = "elite",
        race = "boar",
        level = 19,
        realm = "lianqi_2",  -- 练气中期
        bodyColor = {180, 80, 40, 255},
        skills = { "ground_pound" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.01, type = "world_drop", pool = "ch2" },  -- 世界掉落1%
            { chance = 0.15, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.03, type = "consumable", consumableId = "beast_meat" },
        },
    }
    M.Types.boar_boss_ch2 = {
        name = "猪大哥",
        icon = "🐗",
        portrait = "Textures/monster_boar_boss_ch2.png",
        zone = "boar_slope",
        category = "boss",
        race = "boar",
        level = 20,
        realm = "lianqi_3",  -- 练气后期
        bodyColor = {160, 60, 30, 255},
        phases = 2,
        skills = { "ground_pound" },
        phaseConfig = {
            { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
              announce = "猪大哥暴怒了！",
              addSkill = "rect_sweep" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.25, type = "consumable", consumableId = "beast_meat" },
            -- ②专属材料
            { chance = 0.15, type = "consumable", consumableId = "spirit_pill" },
            { chance = 0.05, type = "consumable", consumableId = "spirit_pill_2" },  -- 灵兽丹·贰5%
            { chance = 0.05, type = "consumable", consumableId = "qi_pill" },      -- 练气丹5%
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "purple" },
            -- ④专属装备
            { chance = 0.10, type = "equipment", equipId = "boar_belt_ch2" },     -- 蛮力腰带10%
            -- ⑤世界掉落
            { chance = 0.02, type = "world_drop", pool = "ch2" },
        },
    }

    -- ===================== 第二章：毒蛇沼 Lv.21~26 =====================
    M.Types.poison_snake = {
        name = "沼泽毒蛇",
        icon = "🐍",
        portrait = "Textures/monster_poison_snake.png",
        zone = "snake_swamp",
        category = "normal",
        race = "snake",
        levelRange = {21, 25},
        realm = "lianqi_2",  -- 练气中期
        bodyColor = {60, 180, 60, 255},
        dropTable = {
            { chance = 0.10, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.10, type = "consumable", consumableId = "spirit_meat" },
        },
    }
    M.Types.snake_king = {
        name = "蛇妖·碧鳞",
        icon = "🐍",
        portrait = "Textures/monster_snake_king.png",
        zone = "snake_swamp",
        category = "boss",
        race = "snake",
        level = 26,
        realm = "zhuji_1",  -- 筑基初期
        bodyColor = {30, 160, 80, 255},
        phases = 2,
        skills = { "poison_spit" },
        phaseConfig = {
            { threshold = 0.5, atkMult = 1.4, speedMult = 1.3, intervalMult = 0.7,
              announce = "蛇王吐出剧毒之息！",
              addSkill = "line_charge" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.50, type = "lingYun", amount = {1, 1} },
            { chance = 0.20, type = "consumable", consumableId = "beast_meat" },
            { chance = 0.05, type = "consumable", consumableId = "immortal_bone" },
            -- ②专属材料
            { chance = 0.05, type = "consumable", consumableId = "spirit_pill_2" },  -- 灵兽丹·贰5%
            { chance = 0.05, type = "world_drop", pool = "snake_books" },  -- 中级技能书5%（随机1本）
            { chance = 0.03, type = "consumable", consumableId = "snake_fruit" },  -- 灵蛇果3%
            { chance = 0.05, type = "consumable", consumableId = "qi_pill" },      -- 练气丹5%
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "purple" },
            -- ④专属装备
            { chance = 0.08, type = "equipment", equipId = "snake_cape_ch2" },    -- 蛇鳞披风8%
            -- ⑤世界掉落
            { chance = 0.02, type = "world_drop", pool = "ch2" },
        },
    }

    -- ===================== 第二章：修罗场 Lv.24~26 =====================
    M.Types.xueshameng_corpse = {
        name = "血煞盟尸傀",
        icon = "💀",
        portrait = "Textures/monster_xueshao_corpse.png",
        zone = "shura_field",
        category = "elite",
        race = "undead",
        levelRange = {24, 26},
        realm = "lianqi_3",  -- 练气后期
        bodyColor = {120, 50, 80, 255},
        skills = { "rect_sweep" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.01, type = "world_drop", pool = "ch2" },  -- 世界掉落1%
            { chance = 0.12, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.05, type = "consumable", consumableId = "beast_meat" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- 精英必掉乌堡令
        },
    }
    M.Types.haoqizong_corpse = {
        name = "浩气宗尸傀",
        icon = "💀",
        portrait = "Textures/monster_haoqi_corpse.png",
        zone = "shura_field",
        category = "elite",
        race = "undead",
        levelRange = {24, 26},
        realm = "lianqi_3",  -- 练气后期
        bodyColor = {80, 80, 120, 255},
        skills = { "line_charge" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.01, type = "world_drop", pool = "ch2" },  -- 世界掉落1%
            { chance = 0.12, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.05, type = "consumable", consumableId = "beast_meat" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- 精英必掉乌堡令
        },
    }

    -- ===================== 第二章：乌堡南北 Lv.26~35 =====================
    M.Types.wu_soldier = {
        name = "乌家兵",
        icon = "⚔️",
        portrait = "Textures/monster_wu_soldier.png",
        zone = "wu_fortress",
        category = "normal",
        race = "dark_warrior",
        levelRange = {26, 29},
        realm = "zhuji_1",  -- 筑基初期
        bodyColor = {60, 60, 70, 255},
        dropTable = {
            { chance = 0.15, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.10, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.10, type = "consumable", consumableId = "wubao_token" },  -- 小怪10%乌堡令
        },
    }
    M.Types.wu_servant = {
        name = "乌家家仆",
        icon = "⚔️",
        portrait = "Textures/monster_wu_servant.png",
        zone = "wu_fortress",
        category = "normal",
        race = "dark_warrior",
        levelRange = {30, 32},
        realm = "zhuji_1",  -- 筑基初期
        bodyColor = {70, 65, 75, 255},
        dropTable = {
            { chance = 0.15, type = "equipment", minQuality = "white", maxQuality = "purple" },
            { chance = 0.10, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.10, type = "consumable", consumableId = "wubao_token" },  -- 小怪10%乌堡令
        },
    }
    M.Types.wu_blood_puppet = {
        name = "乌家血傀",
        icon = "💀",
        portrait = "Textures/monster_wu_blood_puppet.png",
        zone = "wu_fortress",
        category = "elite",
        race = "undead",
        levelRange = {33, 35},
        realm = "zhuji_2",  -- 筑基中期
        bodyColor = {100, 50, 60, 255},
        skills = { "fire_zone" },
        dropTable = {
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "orange" },
            { chance = 0.01, type = "world_drop", pool = "ch2" },  -- 世界掉落1%
            { chance = 0.10, type = "consumable", consumableId = "spirit_meat" },
            { chance = 0.08, type = "consumable", consumableId = "beast_meat" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- 精英必掉乌堡令
        },
    }

    -- ===================== 第二章：乌堡巡逻BOSS Lv.33 =====================
    M.Types.wu_dasha = {
        name = "乌大傻",
        icon = "💀",
        portrait = "Textures/monster_wu_dasha.png",
        zone = "wu_fortress_north",
        category = "boss",
        race = "undead",
        level = 33,
        realm = "zhuji_2",  -- 筑基中期
        bodyColor = {120, 50, 50, 255},
        phases = 2,
        skills = { "ground_pound" },
        phaseConfig = {
            { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
              announce = "乌大傻怒吼一声，符文暴涨！",
              addSkill = "rect_sweep" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.50, type = "lingYun", amount = {1, 1} },
            { chance = 0.15, type = "consumable", consumableId = "beast_meat" },
            { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- BOSS必掉乌堡令
            -- ②专属材料
            { chance = 0.02, type = "consumable", consumableId = "diamond_wood" },  -- 金刚木2%
            { chance = 0.10, type = "consumable", consumableId = "spirit_pill_2" },  -- 灵兽丹·贰10%
            -- ③专属装备
            { chance = 0.05, type = "special_equip", equipId = "wu_armor_ch2" },  -- 乌煞重铠5%
            { chance = 0.03, type = "special_equip", equipId = "wu_hammer_ch2" },  -- 傻大锤3%
            -- ④装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
            -- ⑤世界掉落
            { chance = 0.02, type = "world_drop", pool = "ch2" },
            { chance = 0.01, type = "world_drop", pool = "boss_pill_ch2" },  -- 筑基丹/修炼果/乌堡令盒共享1%
        },
    }
    M.Types.wu_ersha = {
        name = "乌二傻",
        icon = "💀",
        portrait = "Textures/monster_wu_ersha.png",
        zone = "wu_fortress_south",
        category = "boss",
        race = "undead",
        level = 33,
        realm = "zhuji_2",  -- 筑基中期
        bodyColor = {80, 60, 70, 255},
        phases = 2,
        skills = { "whirlwind" },
        phaseConfig = {
            { threshold = 0.5, atkMult = 1.4, speedMult = 1.3,
              announce = "乌二傻双爪泛起寒光！",
              addSkill = "fire_zone" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.50, type = "lingYun", amount = {1, 1} },
            { chance = 0.15, type = "consumable", consumableId = "beast_meat" },
            { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- BOSS必掉乌堡令
            -- ②专属材料
            { chance = 0.02, type = "consumable", consumableId = "diamond_wood" },  -- 金刚木2%
            { chance = 0.10, type = "consumable", consumableId = "spirit_pill_2" },  -- 灵兽丹·贰10%
            -- ③专属装备
            { chance = 0.05, type = "special_equip", equipId = "wu_necklace_ch2" },  -- 乌骨牙链5%
            { chance = 0.03, type = "special_equip", equipId = "wu_hammer_ch2" },  -- 傻大锤3%
            -- ④装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
            -- ⑤世界掉落
            { chance = 0.02, type = "world_drop", pool = "ch2" },
            { chance = 0.01, type = "world_drop", pool = "boss_pill_ch2" },  -- 筑基丹/修炼果/乌堡令盒共享1%
        },
    }

    -- ===================== 第二章：乌堡北堡BOSS Lv.29 =====================
    M.Types.wu_dibei = {
        name = "乌地北",
        icon = "🛡️",
        portrait = "Textures/monster_wu_dibei.png",
        zone = "wu_fortress_north",
        category = "boss",
        race = "dark_warrior",
        level = 29,
        realm = "zhuji_1",  -- 筑基初期
        bodyColor = {50, 55, 80, 255},
        phases = 2,
        skills = { "shield_slam" },
        phaseConfig = {
            { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
              announce = "乌地北举起巨盾！",
              addSkill = "cross_smash" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.50, type = "lingYun", amount = {1, 1} },
            { chance = 0.15, type = "consumable", consumableId = "beast_meat" },
            { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- BOSS必掉乌堡令
            -- ②专属材料
            { chance = 0.02, type = "consumable", consumableId = "diamond_wood" },  -- 金刚木2%
            { chance = 0.05, type = "consumable", consumableId = "spirit_pill_2" },  -- 灵兽丹·贰5%
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "purple" },
            -- ④专属装备
            { chance = 0.05, type = "equipment", equipId = "wu_shoulder_ch2" },   -- 玄铁肩甲5%
            -- ⑤世界掉落
            { chance = 0.02, type = "world_drop", pool = "ch2" },
            { chance = 0.01, type = "world_drop", pool = "boss_pill_ch2" },  -- 筑基丹/修炼果/乌堡令盒共享1%
        },
    }

    -- ===================== 第二章：乌堡南堡BOSS Lv.31 =====================
    M.Types.wu_tiannan = {
        name = "乌天南",
        icon = "⚔️",
        portrait = "Textures/monster_wu_tiannan.png",
        zone = "wu_fortress_south",
        category = "boss",
        race = "dark_warrior",
        level = 31,
        realm = "zhuji_2",  -- 筑基中期
        bodyColor = {90, 45, 50, 255},
        phases = 2,
        skills = { "whirlwind" },
        phaseConfig = {
            { threshold = 0.5, atkMult = 1.5, speedMult = 1.3,
              announce = "乌天南拔刀狂舞！",
              addSkill = "fire_zone" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.50, type = "lingYun", amount = {1, 1} },
            { chance = 0.15, type = "consumable", consumableId = "beast_meat" },
            { chance = 0.08, type = "consumable", consumableId = "immortal_bone" },
            { chance = 0.02, type = "consumable", consumableId = "demon_essence" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- BOSS必掉乌堡令
            -- ②专属材料
            { chance = 0.02, type = "consumable", consumableId = "diamond_wood" },  -- 金刚木2%
            { chance = 0.10, type = "consumable", consumableId = "spirit_pill_2" },  -- 灵兽丹·贰10%
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
            -- ④专属装备
            { chance = 0.05, type = "equipment", equipId = "wu_weapon_ch2" },     -- 南刀·裂风5%
            -- ⑤世界掉落
            { chance = 0.02, type = "world_drop", pool = "ch2" },
            { chance = 0.01, type = "world_drop", pool = "boss_pill_ch2" },  -- 筑基丹/修炼果/乌堡令盒共享1%
        },
    }

    -- ===================== 第二章：乌堡主堡BOSS Lv.35 =====================
    M.Types.wu_wanchou = {
        name = "乌万仇",
        icon = "👑",
        portrait = "Textures/monster_wu_wanchou.png",
        zone = "wu_fortress_main",
        category = "boss",
        race = "dark_warrior",
        level = 35,
        realm = "zhuji_3",  -- 筑基后期
        bodyColor = {80, 40, 90, 255},
        phases = 3,
        skills = { "wanchou_shadow_slash" },
        phaseConfig = {
            -- P2: <60% → 场地技能 + 新增万仇震怒
            { threshold = 0.6, atkMult = 1.3,
              announce = "尔等蝼蚁，竟伤我至此！",
              triggerSkill = "wanchou_annihilation",
              addSkill = "wanchou_fury" },
            -- P3: <30% → 场地技能 + 新增血煞吞噬 + 暴怒
            { threshold = 0.3, atkMult = 1.8, speedMult = 1.4, intervalMult = 0.6,
              announce = "血煞之力...吞噬一切！",
              triggerSkill = "wanchou_annihilation",
              addSkill = "wanchou_blood_devour" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.12, type = "consumable", consumableId = "beast_meat" },
            { chance = 0.10, type = "consumable", consumableId = "immortal_bone" },
            { chance = 0.03, type = "consumable", consumableId = "demon_essence" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- BOSS必掉乌堡令
            -- ②专属材料
            { chance = 0.05, type = "consumable", consumableId = "spirit_pill_2" },  -- 灵兽丹·贰5%
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "green", maxQuality = "orange" },
            -- ④专属装备
            { chance = 0.05, type = "equipment", equipId = "wu_ring_chou" },      -- 乌堡戒·仇5%
            -- ⑤帝尊贰戒（2%独立掉落）
            { chance = 0.02, type = "equipment", equipId = "dizun_ring_ch2" },
            -- ⑥世界掉落
            { chance = 0.02, type = "world_drop", pool = "ch2" },
            { chance = 0.01, type = "world_drop", pool = "boss_pill_ch2" },  -- 筑基丹/修炼果/乌堡令盒共享1%
        },
    }

    -- ===================== 第二章：大殿 王级BOSS Lv.36 =====================
    M.Types.wu_wanhai = {
        name = "乌万海",
        icon = "👑",
        portrait = "Textures/monster_wu_wanhai.png",
        zone = "wu_fortress_hall",
        category = "king_boss",
        race = "dark_warrior",
        level = 36,
        realm = "zhuji_3",  -- 筑基后期
        bodyColor = {40, 35, 30, 255},
        phases = 3,
        skills = { "cross_smash" },
        tierOnly = 5,  -- 仅掉落T5装备
        phaseConfig = {
            { threshold = 0.7, atkMult = 1.3,
              announce = "乌万海冷笑一声，杀气弥漫！",
              addSkill = "ground_pound" },
            { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.5,
              announce = "乌万海暴怒：尔等蝼蚁，焉敢犯我乌堡！",
              addSkill = "fire_zone" },
        },
        dropTable = {
            -- ①常规掉落
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 1.0, type = "lingYun", amount = {1, 1} },
            { chance = 0.10, type = "consumable", consumableId = "beast_meat" },
            { chance = 0.12, type = "consumable", consumableId = "immortal_bone" },
            { chance = 0.05, type = "consumable", consumableId = "demon_essence" },
            { chance = 1.0, type = "consumable", consumableId = "wubao_token" },  -- 王级BOSS必掉乌堡令
            -- ②专属材料
            { chance = 0.10, type = "consumable", consumableId = "spirit_pill_2" },  -- 灵兽丹·贰10%
            -- ③装备掉落
            { chance = 1.0, type = "equipment", minQuality = "white", maxQuality = "orange" },
            -- ④专属装备
            { chance = 0.05, type = "equipment", equipId = "wu_ring_hai" },       -- 乌堡戒·海5%
            { chance = 0.02, type = "equipment", equipId = "wu_boots_ch2" },      -- 踏云靴2%
            -- ⑤帝尊贰戒（2%独立掉落）
            { chance = 0.02, type = "equipment", equipId = "dizun_ring_ch2" },
            -- ⑥世界掉落
            { chance = 0.02, type = "world_drop", pool = "ch2" },
            { chance = 0.01, type = "world_drop", pool = "boss_pill_ch2" },  -- 筑基丹/修炼果/乌堡令盒共享1%
        },
    }

    -- ===================== 荒野 Lv.1 被动怪 =====================
    M.Types.frog = {
        name = "青蛙",
        icon = "🐸",
        portrait = "Textures/monster_frog.png",
        zone = "wilderness",
        category = "normal",
        race = "frog",
        level = 1,
        passive = true,  -- 不主动攻击，被打才还手
        bodyColor = {60, 160, 60, 255},
        dropTable = {
            { chance = 0.65, type = "consumable", consumableId = "meat_bone" },
        },
    }
end
