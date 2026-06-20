-- ============================================================================
-- MonsterData_WorldDrop.lua - 世界掉落池定义
-- 同一池内物品共享一次掉率判定，命中后等权随机选一个
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
M.WORLD_DROP_POOLS = {
    ch1 = {
        eliteLabel = "0.5%", bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "gold_bar" },   -- 金条
        },
    },
    ch2 = {
        eliteLabel = "1%", bossLabel = "2%",
        items = {
            { type = "equipment", equipId = "gold_helmet_ch2" },  -- 招财金盔
            { type = "consumable", consumableId = "gold_bar" },
        },
    },
    ch3 = {
        eliteLabel = "1%", bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "exp_pill" },          -- 修炼果
            { type = "consumable", consumableId = "gold_bar" },          -- 金条
            { type = "consumable", consumableId = "demon_essence" },     -- 妖兽精华
            { type = "consumable", consumableId = "wind_eroded_grass", bossOnly = true }, -- 风蚀草（BOSS专属）
        },
    },
    ch4 = {
        eliteLabel = "3%", bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "exp_pill" },          -- 修炼果
            { type = "consumable", consumableId = "gold_bar" },          -- 金条
            { type = "consumable", consumableId = "demon_essence" },     -- 妖兽精华
            { type = "consumable", consumableId = "lingyun_fruit", bossOnly = true }, -- 灵韵果（BOSS专属）
        },
    },
    ch5 = {
        eliteLabel = "3%",
        items = {
            { type = "consumable", consumableId = "exp_pill" },      -- 修炼果
            { type = "consumable", consumableId = "gold_bar" },      -- 金条
            { type = "consumable", consumableId = "demon_essence" }, -- 妖兽精华
        },
    },
    ch5_boss = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "lingyun_fruit" },          -- 灵韵果
            { type = "consumable", consumableId = "exp_pill_superior" },      -- 上品修炼果
            { type = "consumable", consumableId = "lingyun_fruit_superior" }, -- 上品灵韵果
            { type = "consumable", consumableId = "gold_brick" },             -- 金砖
            { type = "consumable", consumableId = "taixu_jianling_box" },       -- 太虚剑令盒
        },
    },
    -- 万仇/万海专用：筑基丹与修炼果共享掉落池
    boss_pill_ch2 = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "zhuji_pill" },       -- 筑基丹
            { type = "consumable", consumableId = "exp_pill" },         -- 修炼果
            { type = "consumable", consumableId = "wubao_token_box" },  -- 乌堡令盒
        },
    },
    -- 虎王专属：中级技能书共享5%，随机掉1本
    tiger_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_atk_2" },   -- 中级攻击书
            { type = "consumable", consumableId = "book_hp_2" },    -- 中级生命书
            { type = "consumable", consumableId = "book_def_2" },   -- 中级防御书
        },
    },
    -- 蛇王专属：中级技能书共享5%，随机掉1本
    snake_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_evade_2" }, -- 中级闪避书
            { type = "consumable", consumableId = "book_regen_2" }, -- 中级恢复书
            { type = "consumable", consumableId = "book_crit_2" },  -- 中级暴击书
        },
    },
    -- 蝎尾妖王专属：攻速技能书共享5%，随机掉1本
    xiewei_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_atkSpd_1" },    -- 初级攻速书
            { type = "consumable", consumableId = "book_atkSpd_2" },    -- 中级攻速书
        },
    },
    -- 苍狼妖王专属：暴伤技能书共享5%，随机掉1本
    canglang_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_critDmg_1" },   -- 初级暴伤书
            { type = "consumable", consumableId = "book_critDmg_2" },   -- 中级暴伤书
        },
    },
    -- 岩蟾妖王专属：蕴灵·生命技能书共享5%，随机掉1本
    yanchan_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_hpPerLv_1" },   -- 初级蕴灵·生命书
            { type = "consumable", consumableId = "book_hpPerLv_2" },   -- 中级蕴灵·生命书
        },
    },
    -- 赤甲妖王专属：减伤技能书共享5%，随机掉1本
    chijia_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_dmgReduce_1" }, -- 初级减伤书
            { type = "consumable", consumableId = "book_dmgReduce_2" }, -- 中级减伤书
        },
    },
    -- 铁脊狼王专属：蕴灵·防御技能书共享5%，随机掉1本
    tieji_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_defPerLv_1" },  -- 初级蕴灵·防御书
            { type = "consumable", consumableId = "book_defPerLv_2" },  -- 中级蕴灵·防御书
        },
    },
    -- 玄蟒妖王专属：连击技能书共享5%，随机掉1本
    xuanmang_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_doubleHit_1" }, -- 初级连击书
            { type = "consumable", consumableId = "book_doubleHit_2" }, -- 中级连击书
        },
    },
    -- 烈焰妖王专属：吸血技能书共享5%，随机掉1本
    lieyan_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_lifeSteal_1" }, -- 初级吸血书
            { type = "consumable", consumableId = "book_lifeSteal_2" }, -- 中级吸血书
        },
    },

    -- 沙万里专属：灵兽赐主T2技能书共享5%，随机掉1本
    shawanli_owner_books = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "book_wisdom_owner_2" },       -- 灵兽通慧书·贰
            { type = "consumable", consumableId = "book_constitution_owner_2" }, -- 灵兽铸骨书·贰
            { type = "consumable", consumableId = "book_physique_owner_2" },     -- 灵兽淬体书·贰
            { type = "consumable", consumableId = "book_fortune_owner_2" },      -- 灵兽赐福书·贰
        },
    },

    -- 黄天大圣灵器武器共享掉落池（1%命中后等权随机1把）
    huangsha_weapons = {
        bossLabel = "1%",
        items = {
            { type = "equipment", equipId = "huangsha_duanliu" },   -- 黄沙·断流
            { type = "equipment", equipId = "huangsha_fentian" },   -- 黄沙·焚天
            { type = "equipment", equipId = "huangsha_liedi" },     -- 黄沙·裂地
            { type = "equipment", equipId = "huangsha_mieying" },   -- 黄沙·灭影
        },
    },

    -- 流沙之子（外域）：第七寨+第八寨神器碎片共享0.1%，随机掉1个
    rake_fragment_ch3_78 = {
        bossLabel = "0.1%",
        items = {
            { type = "consumable", consumableId = "rake_fragment_1" },  -- 第八寨·神器碎片·1
            { type = "consumable", consumableId = "rake_fragment_2" },  -- 第七寨·神器碎片·2
        },
    },
    rake_fragment_ch3_456 = {
        bossLabel = "0.1%",
        items = {
            { type = "consumable", consumableId = "rake_fragment_4" },  -- 第四寨·赤甲妖王
            { type = "consumable", consumableId = "rake_fragment_5" },  -- 第五寨·蛇骨妖王
            { type = "consumable", consumableId = "rake_fragment_3" },  -- 第六寨·苍狼妖王
        },
    },

    -- 流沙之母：第二寨+第三寨神器碎片共享0.1%，随机掉1个
    rake_fragment_ch3_23 = {
        bossLabel = "0.1%",
        items = {
            { type = "consumable", consumableId = "rake_fragment_7" },  -- 第二寨·蜃妖王
            { type = "consumable", consumableId = "rake_fragment_6" },  -- 第三寨·烈焰狮王
        },
    },

    -- 司空正阳专属：高级蕴灵书共享3%，随机掉1本
    sikong_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_hpPerLv_3" },   -- 高级蕴灵·生命书
            { type = "consumable", consumableId = "book_defPerLv_3" },  -- 高级蕴灵·防御书
        },
    },
    -- 封霜应龙专属：高级技能书共享3%，随机掉1本（含赐主）
    dragon_ice_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_evade_3" },          -- 高级闪避书
            { type = "consumable", consumableId = "book_dmgReduce_3" },      -- 高级减伤书
            { type = "consumable", consumableId = "book_wisdom_owner_3" },   -- 灵兽通慧书·叁
        },
    },
    -- 堕渊蛟龙专属：高级技能书共享3%，随机掉1本（含赐主）
    dragon_abyss_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_regen_3" },              -- 高级恢复书
            { type = "consumable", consumableId = "book_crit_3" },               -- 高级暴击书
            { type = "consumable", consumableId = "book_constitution_owner_3" }, -- 灵兽铸骨书·叁
        },
    },
    -- 焚天蜃龙专属：高级技能书共享3%，随机掉1本（含赐主）
    dragon_fire_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_critDmg_3" },        -- 高级暴伤书
            { type = "consumable", consumableId = "book_doubleHit_3" },      -- 高级连击书
            { type = "consumable", consumableId = "book_physique_owner_3" }, -- 灵兽淬体书·叁
        },
    },
    -- 蚀骨螭龙专属：高级技能书共享3%，随机掉1本（含赐主）
    dragon_sand_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_atkSpd_3" },         -- 高级攻速书
            { type = "consumable", consumableId = "book_lifeSteal_3" },      -- 高级吸血书
            { type = "consumable", consumableId = "book_fortune_owner_3" },  -- 灵兽赐福书·叁
        },
    },

    -- ===================== 仙劫战场·域外邪魔掉落池 =====================

    -- 100% 掉落池：龙髓/妖兽精华/金条 三选一
    xianjie_material = {
        bossLabel = "100%",
        items = {
            { type = "consumable", consumableId = "dragon_marrow" },     -- 龙髓
            { type = "consumable", consumableId = "demon_essence" },     -- 妖兽精华
            { type = "consumable", consumableId = "gold_bar" },          -- 金条
        },
    },
    -- 4% 掉落池：九转金丹/修炼果/灵韵果/金砖 四选一
    xianjie_rare = {
        bossLabel = "4%",
        items = {
            { type = "consumable", consumableId = "jiuzhuan_jindan" },   -- 九转金丹
            { type = "consumable", consumableId = "exp_pill" },          -- 修炼果
            { type = "consumable", consumableId = "lingyun_fruit" },     -- 灵韵果
            { type = "consumable", consumableId = "gold_brick" },        -- 金砖
        },
    },
    -- 0.1% 掉落池：天帝剑痕碎片(1/2/3) 三选一
    xianjie_fragments = {
        bossLabel = "0.1%",
        items = {
            { type = "consumable", consumableId = "tiandi_fragment_1" }, -- 天帝剑痕碎片·壹
            { type = "consumable", consumableId = "tiandi_fragment_2" }, -- 天帝剑痕碎片·贰
            { type = "consumable", consumableId = "tiandi_fragment_3" }, -- 天帝剑痕碎片·叁
        },
    },

    -- ===================== 仙殒战场·域外天魔掉落池 =====================

    -- 100% 掉落池：龙髓/修炼果/灵韵果 三选一
    xianyun_material = {
        bossLabel = "100%",
        items = {
            { type = "consumable", consumableId = "dragon_marrow" },         -- 龙髓
            { type = "consumable", consumableId = "exp_pill" },              -- 修炼果
            { type = "consumable", consumableId = "lingyun_fruit" },         -- 灵韵果
        },
    },
    -- 5% 稀有掉落池：渡劫丹/上品修炼果/金砖/上品灵韵果/仙人精血 五选一
    xianyun_rare = {
        bossLabel = "5%",
        items = {
            { type = "consumable", consumableId = "dujie_dan" },                 -- 渡劫丹
            { type = "consumable", consumableId = "exp_pill_superior" },          -- 上品修炼果
            { type = "consumable", consumableId = "gold_brick" },                 -- 金砖
            { type = "consumable", consumableId = "lingyun_fruit_superior" },     -- 上品灵韵果
            { type = "consumable", consumableId = "immortal_essence_blood" },     -- 仙人精血
        },
    },
    -- 0.1% 神器池：天帝剑痕碎片(4/5/6) 三选一
    xianyun_fragments = {
        bossLabel = "0.1%",
        items = {
            { type = "consumable", consumableId = "tiandi_fragment_4" }, -- 天帝剑痕碎片·肆
            { type = "consumable", consumableId = "tiandi_fragment_5" }, -- 天帝剑痕碎片·伍
            { type = "consumable", consumableId = "tiandi_fragment_6" }, -- 天帝剑痕碎片·陆
        },
    },

    -- ===================== 宠物技能书掉落池 =====================

    -- 司空正阳专属：新3系列高级书共享3%，随机掉1本
    sikong_new_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_ignoreDef_3" },  -- 高级忽视防御书
            { type = "consumable", consumableId = "book_bonusDmg_3" },   -- 高级加伤书
        },
    },

    -- 极阴/极阳阵灵：蕴灵三书高级共享3%，随机掉1本
    yinyang_yunling_books = {
        bossLabel = "3%",
        items = {
            { type = "consumable", consumableId = "book_hpPerLv_3" },   -- 高级蕴灵·生命书
            { type = "consumable", consumableId = "book_defPerLv_3" },  -- 高级蕴灵·防御书
            { type = "consumable", consumableId = "book_atkPerLv_3" },  -- 高级蕴灵·攻击书
        },
    },

    -- 温素章专属：蕴灵三书特级共享1.5%（每本0.5%），随机掉1本
    wen_yunling_books = {
        bossLabel = "1.5%",
        items = {
            { type = "consumable", consumableId = "book_hpPerLv_4" },   -- 特级蕴灵·生命书
            { type = "consumable", consumableId = "book_defPerLv_4" },  -- 特级蕴灵·防御书
            { type = "consumable", consumableId = "book_atkPerLv_4" },  -- 特级蕴灵·攻击书
        },
    },

    -- 噬渊血犼专属：减伤+加伤特级共享1%（每本0.5%），随机掉1本
    abyss_marshal_books = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "book_dmgReduce_4" },  -- 特级减伤书
            { type = "consumable", consumableId = "book_bonusDmg_4" },   -- 特级加伤书
        },
    },

    -- 镇渊魔帅·蚀骨专属：暴击+暴伤特级共享1%（每本0.5%），随机掉1本
    shugu_books = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "book_crit_4" },     -- 特级暴击书
            { type = "consumable", consumableId = "book_critDmg_4" },  -- 特级暴伤书
        },
    },

    -- 镇渊魔帅·裂魂专属：闪避+恢复特级共享1%（每本0.5%），随机掉1本
    liesoul_books = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "book_evade_4" },   -- 特级闪避书
            { type = "consumable", consumableId = "book_regen_4" },   -- 特级恢复书
        },
    },

    -- 诛仙剑专属：通慧+忽视特级共享1%（每本0.5%），随机掉1本
    sword_zhu_books = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "book_wisdom_owner_4" },  -- 灵兽通慧书·肆
            { type = "consumable", consumableId = "book_ignoreDef_4" },     -- 特级忽视防御书
        },
    },

    -- 陷仙剑专属：铸骨+连击特级共享1%（每本0.5%），随机掉1本
    sword_xian_books = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "book_constitution_owner_4" },  -- 灵兽铸骨书·肆
            { type = "consumable", consumableId = "book_doubleHit_4" },           -- 特级连击书
        },
    },

    -- 戮仙剑专属：淬体+攻速特级共享1%（每本0.5%），随机掉1本
    sword_lu_books = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "book_physique_owner_4" },  -- 灵兽淬体书·肆
            { type = "consumable", consumableId = "book_atkSpd_4" },          -- 特级攻速书
        },
    },

    -- 绝仙剑专属：赐福+吸血特级共享1%（每本0.5%），随机掉1本
    sword_jue_books = {
        bossLabel = "1%",
        items = {
            { type = "consumable", consumableId = "book_fortune_owner_4" },  -- 灵兽赐福书·肆
            { type = "consumable", consumableId = "book_lifeSteal_4" },      -- 特级吸血书
        },
    },
}

end
