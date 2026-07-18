-- EquipmentData_Collection.lua
-- 神兵图录（独特装备图鉴系统）数据子模块
-- 由 EquipmentData.lua facade 加载

return {
    -- 按章节分组的展示顺序
    chapters = {
        {
            name = "第一章",
            order = {
                "jade_gourd",
                "boar_patrol_helmet",
                "boar_king_weapon",
                "boss_cape",
                "bandit_second_belt",
                "spider_queen_ring",
                "tiger_set_weapon",
                "tiger_set_armor",
                "tiger_set_necklace",
                "tiger_set_cape",
                "dizun_ring_ch1",
                "jihu_helmet_ch1",
            },
        },
        {
            name = "第二章",
            order = {
                "gold_helmet_ch2",
                "boar_belt_ch2",
                "snake_cape_ch2",
                "wu_shoulder_ch2",
                "wu_weapon_ch2",
                "wu_ring_chou",
                "wu_ring_hai",
                "wu_boots_ch2",
                "wu_armor_ch2",
                "wu_necklace_ch2",
                "wu_hammer_ch2",
                "jianxin_belt_ch2",
                "dizun_ring_ch2",
                "xuehai_shenchou_ring_ch2",
                "fabao_xuehaitu_t5",
                "fabao_haoqiyin_t5",
                "fabao_qingyunta_t5",
                "fabao_fengmopan_t5",
            },
        },
        {
            name = "第三章",
            order = {
                "kumu_helmet_ch3",
                "yanchan_armor_ch3",
                "canglang_necklace_ch3",
                "chijia_ring_ch3",
                "shegu_belt_ch3",
                "liusha_cape_ch3",
                "liusha_helmet_ch3",
                "liusha_belt_ch3",
                "lieyan_cape_ch3",
                "shen_shoulder_ch3",
                "huangsha_duanliu",
                "huangsha_fentian",
                "huangsha_shihun",
                "huangsha_liedi",
                "huangsha_mieying",
                "dizun_ring_ch3",
                "fabao_xuehaitu_t7",
                "fabao_haoqiyin_t7",
                "fabao_qingyunta_t7",
                "fabao_fengmopan_t7",
            },
        },
        {
            name = "第四章",
            order = {
                "chengyuan_helmet_ch4",
                "zhiyan_boots_ch4",
                "leiming_necklace_ch4",
                "fenghen_ring_ch4",
                "yanxin_belt_ch4",
                "houtu_shoulder_ch4",
                "zeyuan_armor_ch4",
                "tiangang_cape_ch4",
                "shengqi_duanliu",
                "shengqi_fentian",
                "shengqi_shihun",
                "shengqi_liedi",
                "shengqi_mieying",
                "silong_ring_ch4",
                "xuanshu_cape_ch4",
                "yinyang_boots_ch4",
                "tiantianquan_weapon_ch4",
                "jilong_helmet_ch4",
                "zhenlong_helmet_ch4",
                "fabao_xuehaitu_t9",
                "fabao_haoqiyin_t9",
                "fabao_qingyunta_t9",
                "fabao_fengmopan_t9",
                "fabao_longjiling_t9",
            },
        },
        {
            name = "第五章",
            order = {
                "zhenpai_boots_ch5",
                "wenfeng_necklace_ch5",
                "hanchi_ring_ch5",
                "bailian_belt_ch5",
                "guanlan_necklace_ch5",
                "suxin_ring_ch5",
                "cangzhen_armor_ch5",
                "shiyuan_cape_ch5",
                "cangzhen_helmet_ch5",
                "tuxue_belt_ch5",
                "qijian_boots_ch5",
                "tuxue_shoulder_ch5",
                "lingqi_cape_ch5",
                "lingqi_ring_ch5",
                "dizun_ring_ch5",
                "fengyin_zhuxian_ch5",
                "fengyin_xianxian_ch5",
                "fengyin_luxian_ch5",
                "fengyin_juexian_ch5",
                -- 铸剑地炉打造（圣器）
                "dizun_saint_ring",
                "daozang_saint_armor",
                "saint_cape_ch5",
                "jiefeng_zhuxian_ch5",
                "jiefeng_xianxian_ch5",
                "jiefeng_luxian_ch5",
                "jiefeng_juexian_ch5",
                -- T10 灵器级法宝
                "fabao_xuehaitu_t10",
                "fabao_haoqiyin_t10",
                "fabao_qingyunta_t10",
                "fabao_fengmopan_t10",
                "fabao_longhunling",
            },
        },
        {
            name = "第六章",
            order = {
                "ch6_xuntian_helmet",
                "ch6_xuntian_boots",
                "ch6_yingyou_ring",
                "ch6_yingyou_necklace",
                "ch6_lieshan_shoulder",
                "ch6_lieshan_armor",
                "ch6_tianbing_belt",
                "ch6_tianbing_weapon",
                "ch6_zhenjie_helmet",
                "ch6_zhenjie_armor",
                "ch6_zhenjie_shoulder",
                "ch6_zhenjie_belt",
                "ch6_zhenjie_boots",
                "ch6_toad_immortal_boots",
                "ch6_heng_weapon",
                "ch6_heng_cyan_helmet",
                "ch6_ha_weapon",
                "ch6_ha_cyan_armor",
                "ch6_gua_king_ring",
                "ch6_xianzun_1_ring",
                "ch6_shixuan_demon_cape",
                "ch6_true_zhuxian",
                "ch6_true_xianxian",
                "ch6_true_luxian",
                "ch6_true_juexian",
                "ch6_hengha_dual_blade",
                "ch6_zhenjie_saint_armor",
                "ch6_guagua_junling_ring",
                "ch6_shijie_saint_cape",
                "fabao_xuehaitu_t11",
                "fabao_haoqiyin_t11",
                "fabao_qingyunta_t11",
                "fabao_fengmopan_t11",
                "fabao_longwangling_t11",
            },
        },
    },
    -- 完整顺序（兼容旧接口）
    order = {
        "jade_gourd",
        "boar_king_weapon",
        "boss_cape",
        "spider_queen_ring",
        "boar_patrol_helmet",
        "tiger_set_weapon",
        "tiger_set_armor",
        "tiger_set_necklace",
        "tiger_set_cape",
        "bandit_second_belt",
        "dizun_ring_ch1",
        "jihu_helmet_ch1",
        "gold_helmet_ch2",
        "boar_belt_ch2",
        "snake_cape_ch2",
        "wu_shoulder_ch2",
        "wu_weapon_ch2",
        "wu_ring_chou",
        "wu_ring_hai",
        "wu_boots_ch2",
        "wu_armor_ch2",
        "wu_necklace_ch2",
        "wu_hammer_ch2",
        "jianxin_belt_ch2",
        "dizun_ring_ch2",
        "xuehai_shenchou_ring_ch2",
        "fabao_xuehaitu_t5",
        "fabao_haoqiyin_t5",
        "fabao_qingyunta_t5",
        "fabao_fengmopan_t5",
        "kumu_helmet_ch3",
        "yanchan_armor_ch3",
        "canglang_necklace_ch3",
        "chijia_ring_ch3",
        "shegu_belt_ch3",
        "liusha_cape_ch3",
        "liusha_helmet_ch3",
        "liusha_belt_ch3",
        "lieyan_cape_ch3",
        "shen_shoulder_ch3",
        "huangsha_duanliu",
        "huangsha_fentian",
        "huangsha_shihun",
        "huangsha_liedi",
        "huangsha_mieying",
        "dizun_ring_ch3",
        "fabao_xuehaitu_t7",
        "fabao_haoqiyin_t7",
        "fabao_qingyunta_t7",
        "fabao_fengmopan_t7",
        "chengyuan_helmet_ch4",
        "zhiyan_boots_ch4",
        "leiming_necklace_ch4",
        "fenghen_ring_ch4",
        "yanxin_belt_ch4",
        "houtu_shoulder_ch4",
        "zeyuan_armor_ch4",
        "tiangang_cape_ch4",
        "shengqi_duanliu",
        "shengqi_fentian",
        "shengqi_shihun",
        "shengqi_liedi",
        "shengqi_mieying",
        "silong_ring_ch4",
        "xuanshu_cape_ch4",
        "yinyang_boots_ch4",
        "tiantianquan_weapon_ch4",
        "jilong_helmet_ch4",
        "zhenlong_helmet_ch4",
        "fabao_xuehaitu_t9",
        "fabao_haoqiyin_t9",
        "fabao_qingyunta_t9",
        "fabao_fengmopan_t9",
        "fabao_longjiling_t9",
        -- 第五章·太虚遗藏
        "zhenpai_boots_ch5",
        "wenfeng_necklace_ch5",
        "hanchi_ring_ch5",
        "bailian_belt_ch5",
        "guanlan_necklace_ch5",
        "suxin_ring_ch5",
        "cangzhen_armor_ch5",
        "shiyuan_cape_ch5",
        "cangzhen_helmet_ch5",
        "tuxue_belt_ch5",
        "qijian_boots_ch5",
        "tuxue_shoulder_ch5",
        "lingqi_cape_ch5",
        "lingqi_ring_ch5",
        "dizun_ring_ch5",
        "fengyin_zhuxian_ch5",
        "fengyin_xianxian_ch5",
        "fengyin_luxian_ch5",
        "fengyin_juexian_ch5",
        -- 铸剑地炉打造（圣器）
        "dizun_saint_ring",
        "daozang_saint_armor",
        "saint_cape_ch5",
        "jiefeng_zhuxian_ch5",
        "jiefeng_xianxian_ch5",
        "jiefeng_luxian_ch5",
        "jiefeng_juexian_ch5",
        -- T10 灵器级法宝
        "fabao_xuehaitu_t10",
        "fabao_haoqiyin_t10",
        "fabao_qingyunta_t10",
        "fabao_fengmopan_t10",
        "fabao_longhunling",
        -- 第六章·两界村之影（仙1橙过渡）
        "ch6_xuntian_helmet",
        "ch6_xuntian_boots",
        "ch6_yingyou_ring",
        "ch6_yingyou_necklace",
        "ch6_lieshan_shoulder",
        "ch6_lieshan_armor",
        "ch6_tianbing_belt",
        "ch6_tianbing_weapon",
        "ch6_zhenjie_helmet",
        "ch6_zhenjie_armor",
        "ch6_zhenjie_shoulder",
        "ch6_zhenjie_belt",
        "ch6_zhenjie_boots",
        "ch6_toad_immortal_boots",
        "ch6_heng_weapon",
        "ch6_heng_cyan_helmet",
        "ch6_ha_weapon",
        "ch6_ha_cyan_armor",
        "ch6_gua_king_ring",
        "ch6_xianzun_1_ring",
        "ch6_shixuan_demon_cape",
        "ch6_true_zhuxian",
        "ch6_true_xianxian",
        "ch6_true_luxian",
        "ch6_true_juexian",
        "ch6_hengha_dual_blade",
        "ch6_zhenjie_saint_armor",
        "ch6_guagua_junling_ring",
        "ch6_shijie_saint_cape",
        "fabao_xuehaitu_t11",
        "fabao_haoqiyin_t11",
        "fabao_qingyunta_t11",
        "fabao_fengmopan_t11",
        "fabao_longwangling_t11",
    },

    -- 每个条目的收录奖励（总计≈T3绿全套的20%）
    entries = {
        jade_gourd = {
            bonus = { atk = 1, maxHp = 5 },
            desc = "浊酒一壶，清灵润体，行走江湖必备之物。",
        },
        spider_queen_ring = {
            bonus = { atk = 1, def = 1 },
            desc = "蛛母丝腺凝结的指环，剧毒缠绕，触之即噬。",
        },
        boar_king_weapon = {
            bonus = { atk = 2, def = 1, maxHp = 5 },
            desc = "猪三哥的战斧，力量惊人。",
        },
        boss_cape = {
            bonus = { def = 2, maxHp = 10 },
            desc = "大大王的战袍，穿上后气势非凡。",
        },
        tiger_set_weapon = {
            bonus = { atk = 2, def = 1, maxHp = 5 },
            desc = "虎牙磨制的利刃，锋利无比。",
        },
        tiger_set_armor = {
            bonus = { def = 3, maxHp = 10 },
            desc = "虎王皮革锻造的铠甲，防御卓越。",
        },
        tiger_set_necklace = {
            bonus = { atk = 3, def = 2, maxHp = 5 },
            desc = "虎王血珀凝结的项坠，蕴含虎王之力。",
        },
        tiger_set_cape = {
            bonus = { atk = 2, def = 2, maxHp = 10 },
            desc = "虎皮缝制的战袍，披上便有虎威加身。",
        },
        boar_patrol_helmet = {
            bonus = { maxHp = 5 },
            desc = "猪妖粗制的铁盔，虽然简陋但异常坚固。",
        },
        bandit_second_belt = {
            bonus = { atk = 1, maxHp = 5 },
            desc = "二大王的腰带，宽如手掌，刀劈不断。",
        },
        dizun_ring_ch1 = {
            bonus = { fortune = 2 },
            desc = "帝尊初铸之戒，虎啸山林，福缘深厚。",
        },
        jihu_helmet_ch1 = {
            bonus = { atk = 5 },
            desc = "虎王试炼炉合铸的终局战盔，舍虎王套装之形，取其攻伐之意。",
        },
        -- 第二章（加成合计≈Ch1的2倍：atk+18, def+20, maxHp+79）
        gold_helmet_ch2 = {
            bonus = { fortune = 3 },
            desc = "通体金光的头盔，杀敌取财，日进斗金。",
        },
        boar_belt_ch2 = {
            bonus = { atk = 3, maxHp = 12 },
            desc = "猪大哥的蛮力腰带，力大无穷。",
        },
        snake_cape_ch2 = {
            bonus = { def = 5, maxHp = 12 },
            desc = "碧鳞蛇王蜕下的鳞甲披风，坚韧异常。",
        },
        wu_shoulder_ch2 = {
            bonus = { def = 5, maxHp = 10 },
            desc = "乌地北锻造的玄铁肩甲，固若金汤。",
        },
        wu_weapon_ch2 = {
            bonus = { atk = 4, def = 2, maxHp = 10 },
            desc = "乌天南的佩刀，刀气如风，势不可挡。",
        },
        wu_ring_chou = {
            bonus = { atk = 4, def = 4, maxHp = 10 },
            desc = "乌万仇的戒指，满载仇恨之力。",
        },
        wu_ring_hai = {
            bonus = { atk = 4, def = 4, maxHp = 10 },
            desc = "乌万海的戒指，深沉如海，暗藏杀机。",
        },
        wu_boots_ch2 = {
            bonus = { atk = 5, maxHp = 20 },
            desc = "踏云而行，十中避一，轻灵飘逸。",
        },
        wu_armor_ch2 = {
            bonus = { def = 4, maxHp = 12 },
            desc = "乌大傻以蛮力锤锻的玄铁重铠，沉若铁山，硬抗百拳。",
        },
        wu_necklace_ch2 = {
            bonus = { atk = 4, maxHp = 12 },
            desc = "乌二傻以妖骨獠牙穿就的项链，锋锐嗜血，一击致命。",
        },
        wu_hammer_ch2 = {
            bonus = { maxHp = 12 },
            desc = "大傻二傻合力铸就的蛮荒巨锤，一锤落地，山崩石裂。",
        },
        jianxin_belt_ch2 = {
            bonus = { killHeal = 20 },
            desc = "乌万海大殿秘藏的剑心腰带，杀意回流，越战越稳。",
        },
        dizun_ring_ch2 = {
            bonus = { fortune = 3 },
            desc = "帝尊再铸之戒，双煞淬炼，福缘深厚。",
        },
        xuehai_shenchou_ring_ch2 = {
            bonus = { def = 5, maxHp = 20 },
            desc = "乌堡三戒合炼而成，血海仇意凝于指间，守身护命，血气绵长。",
        },
        -- 法宝图鉴（第二章·T5）
        fabao_xuehaitu_t5 = {
            bonus = { atk = 3, killHeal = 6 },
            desc = "血煞盟秘传图卷，杀意初凝，血海翻涌。",
        },
        fabao_haoqiyin_t5 = {
            bonus = { killHeal = 6, hpRegen = 2 },
            desc = "浩气宗正法印记，正气护体，生生不息。",
        },
        fabao_qingyunta_t5 = {
            bonus = { heavyHit = 10, def = 3 },
            desc = "青云门镇山宝塔，初显威能，碎石裂金。",
        },
        fabao_fengmopan_t5 = {
            bonus = { maxHp = 10, hpRegen = 1 },
            desc = "封魔殿封印法盘，魔气初封，血脉坚韧。",
        },
        -- 第三章（×2.0目标：atk≈50, def≈54, maxHp≈212, killHeal≈16 + hpRegen/heavyHit新增）
        -- 实际合计：atk=50, def=54, maxHp=210, killHeal=16, hpRegen=6, heavyHit=15
        kumu_helmet_ch3 = {
            bonus = { maxHp = 25, def = 5 },
            desc = "枯木妖王灵脉凝成的冠冕，残存一丝生机。",
        },
        yanchan_armor_ch3 = {
            bonus = { def = 8, maxHp = 20 },
            desc = "岩蟾妖王蜕壳锻造的石铠，坚如磐石。",
        },
        canglang_necklace_ch3 = {
            bonus = { atk = 5, def = 5 },
            desc = "苍狼妖王獠牙磨制的项坠，嗜血凶戾。",
        },
        chijia_ring_ch3 = {
            bonus = { atk = 5, maxHp = 25 },
            desc = "赤甲妖王毒尾凝结的指环，剧毒锋锐。",
        },
        shegu_belt_ch3 = {
            bonus = { def = 6, maxHp = 20, killHeal = 6 },
            desc = "蛇骨妖王脊椎编织的腰环，韧性惊人。",
        },
        liusha_cape_ch3 = {
            bonus = { killHeal = 10, maxHp = 25 },
            desc = "流沙之母蜕壳织就的蛛甲披，沙粒流转间可化解刀剑。",
        },
        liusha_helmet_ch3 = {
            bonus = { maxHp = 25, hpRegen = 1 },
            desc = "流沙之子头壳磨成的额冠，砂粒渗入识海，悟性渐开。",
        },
        liusha_belt_ch3 = {
            bonus = { atk = 4, maxHp = 25, hpRegen = 2 },
            desc = "流沙之母腹中灵砂编织的绶带，系于腰间，砂粒入体化为灵根。",
        },
        lieyan_cape_ch3 = {
            bonus = { atk = 5, def = 6, hpRegen = 1 },
            desc = "烈焰狮王鬃毛织就的战披，触之灼热，余焰不灭。",
        },
        shen_shoulder_ch3 = {
            bonus = { def = 8, maxHp = 25 },
            desc = "蜃妖王幻影凝聚的肩甲，虚实莫辨，死中求活。",
        },
        -- 黄天大圣灵器武器（5把共享掉落）
        huangsha_duanliu = {
            bonus = { atk = 6, def = 4, hpRegen = 1 },
            desc = "黄沙断流，风刃所至，万物凋零。",
        },
        huangsha_fentian = {
            bonus = { atk = 5, maxHp = 25 },
            desc = "焚天之焰，灼尽一切，生生不息。",
        },
        huangsha_shihun = {
            bonus = { atk = 5, killHeal = 8, hpRegen = 1 },
            desc = "噬魂夺魄，杀敌续命，越战越强。",
        },
        huangsha_liedi = {
            bonus = { atk = 6, def = 6 },
            desc = "裂地之力，每一击都震碎大地。",
        },
        huangsha_mieying = {
            bonus = { atk = 7, maxHp = 25 },
            desc = "灭影无形，暴击之下，万劫不复。",
        },
        dizun_ring_ch3 = {
            bonus = { fortune = 4 },
            desc = "帝尊三铸之戒，万里黄沙淬体，筋骨如铁。",
        },
        -- 法宝图鉴（第三章·T7）
        fabao_xuehaitu_t7 = {
            bonus = { atk = 6, killHeal = 12 },
            desc = "血煞盟秘传图卷，杀意凝形，血海浩荡无涯。",
        },
        fabao_haoqiyin_t7 = {
            bonus = { killHeal = 12, hpRegen = 4 },
            desc = "浩气宗正法印记，正气如渊，伤损自复。",
        },
        fabao_qingyunta_t7 = {
            bonus = { heavyHit = 20, def = 6 },
            desc = "青云门镇山宝塔，威震四方，金石俱碎。",
        },
        fabao_fengmopan_t7 = {
            bonus = { maxHp = 20, hpRegen = 2 },
            desc = "封魔殿封印法盘，魔气深封，气血充盈。",
        },
        -- 第四章·龙神圣器（合计：atk=34, def=21, maxHp=150, killHeal=20, hpRegen=2）
        shengqi_duanliu = {
            bonus = { atk = 7, def = 7, maxHp = 30 },
            desc = "龙极断流，风卷残云，一刀斩断万古长河。",
        },
        shengqi_fentian = {
            bonus = { atk = 6, maxHp = 30, hpRegen = 1 },
            desc = "龙极焚天，焚尽苍穹，浴火之中生生不息。",
        },
        shengqi_shihun = {
            bonus = { atk = 7, maxHp = 30, killHeal = 10 },
            desc = "龙极噬魂，杀伐果断，每一击都在吞噬生机。",
        },
        shengqi_liedi = {
            bonus = { atk = 7, def = 7, maxHp = 30 },
            desc = "龙极裂地，力贯千钧，大地为之龟裂。",
        },
        shengqi_mieying = {
            bonus = { atk = 7, maxHp = 30, killHeal = 10 },
            desc = "龙极灭影，暗影之中，必杀一击，万劫不复。",
        },
        -- 第四章·帝尊肆戒（福缘+5）
        silong_ring_ch4 = {
            bonus = { fortune = 5 },
            desc = "帝尊终铸之戒，四龙精魄凝聚，福缘天成，气运亨通。",
        },
        -- 第四章·八卦海（合计：atk=22, def=49, maxHp=150, killHeal=8, hpRegen=5）
        chengyuan_helmet_ch4 = {
            bonus = { maxHp = 30, def = 6, hpRegen = 1 },
            desc = "沈渊衣以深渊之水淬炼的冥冠，戴上后仿若沉入万丈深渊。",
        },
        zhiyan_boots_ch4 = {
            bonus = { def = 6, maxHp = 30 },
            desc = "岩不动脚下亘古不移的磐石锻造，落地便如山岳扎根。",
        },
        leiming_necklace_ch4 = {
            bonus = { atk = 6, maxHp = 15 },
            desc = "雷惊蛰心中凝结的雷珠磨制，电弧缠绕，触之酥麻。",
        },
        fenghen_ring_ch4 = {
            bonus = { atk = 6, maxHp = 15 },
            desc = "风无痕万年逃亡中唯一不曾遗落之物，轻若无物，锋如断魂。",
        },
        yanxin_belt_ch4 = {
            bonus = { def = 5, maxHp = 30, killHeal = 8 },
            desc = "炎若晦丹炉余焰凝成的腰环，温热不散，杀敌续命。",
        },
        houtu_shoulder_ch4 = {
            bonus = { def = 10, maxHp = 30, hpRegen = 1 },
            desc = "厚德生以厚土封印阵力时剥落的肩甲，生生不息。",
        },
        zeyuan_armor_ch4 = {
            bonus = { def = 12, maxHp = 30, hpRegen = 2 },
            desc = "泽归墟毕生炼毒的精华凝为仙铠，毒泽化生，万物滋养。",
        },
        tiangang_cape_ch4 = {
            bonus = { atk = 10, def = 12 },
            desc = "司空正阳以天罡正气织就的圣披，浩然之气，百邪不侵。",
        },
        -- 第四章·新增装备（合计：atk=16, def=7, maxHp=30, killHeal=8, hpRegen=5）
        xuanshu_cape_ch4 = {
            bonus = { def = 7, hpRegen = 1 },
            desc = "以玄枢星力织就的灵披，斗转星移间攻守兼备。",
        },
        yinyang_boots_ch4 = {
            bonus = { maxHp = 30, hpRegen = 2 },
            desc = "阴阳二气淬炼的战靴，踏破生死之界，杀敌回血。",
        },
        tiantianquan_weapon_ch4 = {
            bonus = { atk = 8, hpRegen = 1 },
            desc = "彩虹灵力凝聚而成的仙棒，七彩流光，生机勃勃。",
        },
        jilong_helmet_ch4 = {
            bonus = { atk = 8, killHeal = 8 },
            desc = "四方龙神之力凝聚的战盔，龙威加身，坚不可摧。",
        },
        zhenlong_helmet_ch4 = {
            bonus = { atk = 12 },
            desc = "极龙盔再经龙极令与帝尊肆戒淬炼，真龙威势尽聚于冠。",
        },
        -- 法宝图鉴（第四章·T9）
        fabao_xuehaitu_t9 = {
            bonus = { atk = 9, killHeal = 18 },
            desc = "血煞盟秘传图卷，杀意滔天，血海焚天灭地。",
        },
        fabao_haoqiyin_t9 = {
            bonus = { killHeal = 18, hpRegen = 6 },
            desc = "浩气宗正法印记，浩气长存，万物归元。",
        },
        fabao_qingyunta_t9 = {
            bonus = { heavyHit = 30, def = 9 },
            desc = "青云门镇山宝塔，威压万方，天崩地裂。",
        },
        fabao_fengmopan_t9 = {
            bonus = { maxHp = 30, hpRegen = 3 },
            desc = "封魔殿封印法盘，魔气尽封，血脉如岳。",
        },
        fabao_longjiling_t9 = {
            bonus = { atk = 5, wisdom = 5 },
            desc = "四龙之威凝为一令，龙息喷吐，百鬼辟易。",
        },
        -- 第五章·太虚遗藏（合计：atk=48, def=78, maxHp=330, killHeal=40, hpRegen=10）
        zhenpai_boots_ch5 = {
            bonus = { def = 8, maxHp = 30 },
            desc = "太虚剑宫护山石傀遗留的重铸石靴，步如山岳。",
        },
        wenfeng_necklace_ch5 = {
            bonus = { atk = 8, killHeal = 8 },
            desc = "裴千岳问剑之刃化为的雷纹坠，剑意如雷。",
        },
        hanchi_ring_ch5 = {
            bonus = { maxHp = 30, hpRegen = 1 },
            desc = "霜鸾寒池凝结的冰华戒指，冰魄入骨。",
        },
        bailian_belt_ch5 = {
            bonus = { maxHp = 30, hpRegen = 1 },
            desc = "韩百炼地炉淬火的腰绶，百炼不屈。",
        },
        guanlan_necklace_ch5 = {
            bonus = { atk = 8, def = 8 },
            desc = "石观澜碑林守护的佩饰，碑文如剑。",
        },
        suxin_ring_ch5 = {
            bonus = { atk = 8, killHeal = 8 },
            desc = "宁栖梧宿心之怨凝为残戒，杀意难消。",
        },
        cangzhen_armor_ch5 = {
            bonus = { def = 6, maxHp = 30, hpRegen = 1 },
            desc = "温素章藏经阁护法玄衣，守正辟邪。",
        },
        cangzhen_helmet_ch5 = {
            bonus = { atk = 8, killHeal = 8 },
            desc = "藏真一脉护脉玄冠，杀伐之中养护经脉。",
        },
        tuxue_belt_ch5 = {
            bonus = { def = 6, maxHp = 30 },
            desc = "屠血将命绶，杀戮淬炼，血脉坚韧。",
        },
        qijian_boots_ch5 = {
            bonus = { def = 8, maxHp = 30 },
            desc = "栖剑行靴，剑气护步，铁壁无隙。",
        },
        tuxue_shoulder_ch5 = {
            bonus = { def = 6, maxHp = 30 },
            desc = "屠血魔肩，血战千场，铁肩担道。",
        },
        lingqi_cape_ch5 = {
            bonus = { def = 8, maxHp = 30 },
            desc = "镇渊魔帅·蚀骨所守的天渊灵披，深渊灵气护体。",
        },
        lingqi_ring_ch5 = {
            bonus = { def = 8, maxHp = 30 },
            desc = "镇渊魔帅·裂魂所守的均灵环，阴阳均衡，灵力护身。",
        },
        shiyuan_cape_ch5 = {
            bonus = { def = 8, maxHp = 30 },
            desc = "噬渊血犼魔氅，深渊之力镇煞四方。",
        },
        dizun_ring_ch5 = {
            bonus = { fortune = 6 },
            desc = "帝尊五铸之戒，太虚淬炼，福泽深厚。",
        },
        fengyin_zhuxian_ch5 = {
            bonus = { atk = 8, killHeal = 8, hpRegen = 1 },
            desc = "封印之下犹有诛天之意，剑气冲霄。",
        },
        fengyin_xianxian_ch5 = {
            bonus = { atk = 8, maxHp = 30, hpRegen = 1 },
            desc = "封印之下犹有陷地之力，万物沉沦。",
        },
        fengyin_luxian_ch5 = {
            bonus = { atk = 8, def = 8, hpRegen = 1 },
            desc = "封印之下犹有戮灵之威，杀伐无情。",
        },
        fengyin_juexian_ch5 = {
            bonus = { atk = 8, maxHp = 30, killHeal = 8 },
            desc = "封印之下犹有绝世之锋，一剑断仙。",
        },
        -- 铸剑地炉打造（圣器）
        dizun_saint_ring = {
            bonus = { constitution = 5, physique = 5 },
            desc = "帝尊圣戒，天下福缘汇聚，万邦来朝。",
        },
        daozang_saint_armor = {
            bonus = { def = 6, maxHp = 30, hpRegen = 2 },
            desc = "道藏圣甲，千卷护体，邪祟不侵。",
        },
        saint_cape_ch5 = {
            bonus = { def = 8, maxHp = 30 },
            desc = "深渊圣氅，以深渊之力与圣器精华合铸，百邪莫近。",
        },
        jiefeng_zhuxian_ch5 = {
            bonus = { atk = 8, killHeal = 8, hpRegen = 1 },
            desc = "解封之后，诛天之意倾泻而出，天地为之颤抖。",
        },
        jiefeng_xianxian_ch5 = {
            bonus = { atk = 8, maxHp = 30, hpRegen = 1 },
            desc = "解封之后，陷地之力无可阻挡，万物归于沉寂。",
        },
        jiefeng_luxian_ch5 = {
            bonus = { atk = 8, def = 8, hpRegen = 1 },
            desc = "解封之后，戮灵之威蔓延四方，鬼神皆惧。",
        },
        jiefeng_juexian_ch5 = {
            bonus = { atk = 8, maxHp = 30, killHeal = 8 },
            desc = "解封之后，绝世之锋重现，神仙亦可斩。",
        },
        fabao_xuehaitu_t10 = {
            bonus = { atk = 12, killHeal = 24 },
            desc = "血煞盟至高秘典，血海滔天，杀意化为不灭洪流。",
        },
        fabao_haoqiyin_t10 = {
            bonus = { killHeal = 24, hpRegen = 8 },
            desc = "浩气宗镇宗法印，浩然正气充盈天地，百邪不侵。",
        },
        fabao_qingyunta_t10 = {
            bonus = { heavyHit = 40, def = 12 },
            desc = "青云门通天宝塔，塔影遮天蔽日，一击碎山河。",
        },
        fabao_fengmopan_t10 = {
            bonus = { maxHp = 40, hpRegen = 4 },
            desc = "封魔殿不灭法盘，万魔封印，血脉永固如山岳。",
        },
        fabao_longhunling = {
            bonus = { constitution = 5, physique = 5 },
            desc = "龙魂令在手，龙息长存，生生不息。",
        },
        -- 第六章·两界村之影（掉落特殊装备，合计：atk=64, def=88, maxHp=420, killHeal=48, hpRegen=6, fortune=7）
        ch6_xuntian_helmet = {
            bonus = { def = 8, maxHp = 30 },
            desc = "巡天仙兵所遗头盔，云纹护额，天威仍在。",
        },
        ch6_xuntian_boots = {
            bonus = { def = 8, maxHp = 30 },
            desc = "凌风踏云巡游所穿战履，步起风雷，守御不散。",
        },
        ch6_yingyou_ring = {
            bonus = { atk = 8, killHeal = 12 },
            desc = "影游使凝影成戒，暗芒藏锋，杀意入骨。",
        },
        ch6_yingyou_necklace = {
            bonus = { atk = 8, killHeal = 12 },
            desc = "烛幽夜影所化项链，幽月沉光，斩影续命。",
        },
        ch6_lieshan_shoulder = {
            bonus = { def = 8, maxHp = 30 },
            desc = "山岭巨像裂石为肩，厚土之力护体。",
        },
        ch6_lieshan_armor = {
            bonus = { def = 8, maxHp = 30 },
            desc = "两界山神以山脉气息凝成的战衣，坚如断岳。",
        },
        ch6_tianbing_belt = {
            bonus = { atk = 8, maxHp = 30 },
            desc = "西营天兵制式战带，军阵杀气仍缠其上。",
        },
        ch6_tianbing_weapon = {
            bonus = { atk = 8, maxHp = 30 },
            desc = "东营天兵制式战刃，锋光如令，斩敌不退。",
        },
        ch6_zhenjie_helmet = {
            bonus = { def = 8, maxHp = 30 },
            desc = "东西营天兵镇守阵地的灵盔，青金符纹压住两界动荡。",
        },
        ch6_zhenjie_armor = {
            bonus = { def = 8, maxHp = 30 },
            desc = "破军天将所藏镇界甲，兵锋入甲，仍能护身不动。",
        },
        ch6_zhenjie_shoulder = {
            bonus = { def = 8, maxHp = 30 },
            desc = "镇垣天将遗落的肩甲，厚重如墙，镇守一方。",
        },
        ch6_zhenjie_belt = {
            bonus = { atk = 8, def = 8 },
            desc = "青锋天将束甲之带，风雷藏刃，攻守兼备。",
        },
        ch6_zhenjie_boots = {
            bonus = { def = 8, maxHp = 30 },
            desc = "雷策天将踏阵之履，雷纹凝固，步履沉稳。",
        },
        ch6_toad_immortal_boots = {
            bonus = { maxHp = 30, hpRegen = 2 },
            desc = "蛤蟆仙人跳跃山泽的仙履，轻灵之中暗藏生机。",
        },
        ch6_heng_weapon = {
            bonus = { atk = 8, killHeal = 12 },
            desc = "哼元帅震营大刀，刀背厚重，杀意沉稳。",
        },
        ch6_heng_cyan_helmet = {
            bonus = { def = 8, hpRegen = 1 },
            desc = "哼元帅战盔，威声震西营，回生之力暗伏其中。",
        },
        ch6_ha_weapon = {
            bonus = { atk = 8, killHeal = 12 },
            desc = "哈元帅长啸大刀，刃光如雷，斩敌续战。",
        },
        ch6_ha_cyan_armor = {
            bonus = { maxHp = 30, hpRegen = 1 },
            desc = "哈元帅战甲，雷声入甲，血气回转不息。",
        },
        ch6_gua_king_ring = {
            bonus = { atk = 8, maxHp = 30 },
            desc = "呱大人凝泽成戒，王威藏于鸣声，仙缘自会均衡。",
        },
        ch6_xianzun_1_ring = {
            bonus = { fortune = 7 },
            desc = "仙尊一戒，仙1段福缘汇聚于此，气运自生。",
        },
        ch6_shixuan_demon_cape = {
            bonus = { def = 8, maxHp = 30, hpRegen = 2 },
            desc = "蚀玄魔君氅，暗影成披，魔气侵蚀而护身。",
        },
        ch6_true_zhuxian = {
            bonus = { atk = 12, killHeal = 12, hpRegen = 1 },
            desc = "诛仙二次解封，剑意贯穿两界。",
        },
        ch6_true_xianxian = {
            bonus = { atk = 10, maxHp = 40, hpRegen = 1 },
            desc = "陷仙二次解封，生灭攻守相依。",
        },
        ch6_true_luxian = {
            bonus = { atk = 12, def = 8, hpRegen = 1 },
            desc = "戮仙二次解封，连斩势不可挡。",
        },
        ch6_true_juexian = {
            bonus = { atk = 10, maxHp = 40, hpRegen = 1 },
            desc = "绝仙二次解封，绝命锋芒再临。",
        },
        ch6_zhenjie_saint_armor = {
            bonus = { def = 12, maxHp = 30, hpRegen = 2 },
            desc = "镇界五甲归一，天幕护身而不夺八卦之效。",
        },
        ch6_hengha_dual_blade = {
            bonus = { atk = 12, maxHp = 30, hpRegen = 1 },
            desc = "哼哈双刃齐鸣，震杀之威横贯战阵。",
        },
        ch6_guagua_junling_ring = {
            bonus = { constitution = 5, wisdom = 5, physique = 5 },
            desc = "呱呱均灵，四缘取其低者而补之。",
        },
        ch6_shijie_saint_cape = {
            bonus = { def = 12, maxHp = 40, hpRegen = 2 },
            desc = "蚀界仙氅合并深渊与魔君之力，渊甲长护。",
        },
        -- 第六章·T11 红色法宝
        fabao_xuehaitu_t11 = {
            bonus = { atk = 15, killHeal = 30 },
            desc = "血海图踏入仙阶，血潮横贯两界，杀意凝而不散。",
        },
        fabao_haoqiyin_t11 = {
            bonus = { killHeal = 30, hpRegen = 10 },
            desc = "浩气印踏入仙阶，正气生生不息，攻守皆可回转。",
        },
        fabao_qingyunta_t11 = {
            bonus = { heavyHit = 50, def = 15 },
            desc = "青云塔踏入仙阶，塔威镇界，重势可碎金石。",
        },
        fabao_fengmopan_t11 = {
            bonus = { maxHp = 50, hpRegen = 5 },
            desc = "封魔盘踏入仙阶，封镇万魔，血脉与生机长存。",
        },
        fabao_longwangling_t11 = {
            bonus = { atk = 5, fortune = 5 },
            desc = "龙王令号令龙息，威临两界，攻伐与福缘并聚。",
        },
    },
}
