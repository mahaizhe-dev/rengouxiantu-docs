-- ============================================================================
-- SealDemonConfig.lua - 封魔任务配置数据
--
-- 包含：
--   - DEMON_BUFF: 封魔增幅（狂暴 + 血量倍率）
--   - QUESTS: 20个一次性封魔任务（5章×4）
--   - DAILY: 5个日常封魔任务（每章1个，所有章节共享每日1次）
--   - EXCLUDED_BOSSES: 不参与封魔的BOSS清单
--   - QUEST_BY_ID: 按ID索引（自动生成）
--   - PHYSIQUE_PILL: 体魄丹配置
-- ============================================================================

local SealDemonConfig = {}

-- ============================================================================
-- 封魔增幅
-- ============================================================================

SealDemonConfig.DEMON_BUFF = {
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
    hpMult = 1.5,
}

-- ============================================================================
-- 体魄丹配置
-- ============================================================================

SealDemonConfig.PHYSIQUE_PILL = {
    maxCount = 100,       -- 最大累计使用量
    dailyLimit = 1,       -- 每日获取上限（由日常任务固定发放）
    bonusPerTen = 2,      -- 每10枚+2体魄
    tiers = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 },  -- 阶梯：每10枚+2体魄
}

-- ============================================================================
-- 一次性封魔任务（20个：ch1×4 + ch2×4 + ch3×4 + ch4×4 + ch5×4）
-- ============================================================================

SealDemonConfig.QUESTS = {
    -- ===================== 第一章（保持原类别 boss） =====================
    {
        id = "seal_ch1_1", chapter = 1, requiredLevel = 5,
        name = "封魔·魔蛛母",
        desc = "蛛母被魔气侵蚀，实力暴涨。封魔谷请你前往蜘蛛洞镇压。",
        sourceBoss = "spider_queen",
        overrideLevel = 10,
        overrideCategory = nil,       -- 保持 boss
        overrideRealm = "lianqi_1",
        spawnZone = "spider_cave", spawnX = 65, spawnY = 62,  -- spider_nest{62,55,77,77}, 距原BOSS(70,68)≈7格
        reward = { lingYun = 10, petFood = "immortal_bone" },
    },
    {
        id = "seal_ch1_2", chapter = 1, requiredLevel = 10,
        name = "封魔·魔猪三哥",
        desc = "猪三哥被魔气吞噬，在野猪林中横行。请速速前往镇压。",
        sourceBoss = "boar_king",
        overrideLevel = 10,
        overrideCategory = nil,
        overrideRealm = "lianqi_1",
        spawnZone = "boar_forest", spawnX = 15, spawnY = 65,
        reward = { lingYun = 10, petFood = "immortal_bone" },
    },
    {
        id = "seal_ch1_3", chapter = 1, requiredLevel = 15,
        name = "封魔·魔大大王",
        desc = "大大王被魔气腐蚀，在山贼寨中称霸。封魔谷已下令镇压。",
        sourceBoss = "bandit_chief",
        overrideLevel = 15,
        overrideCategory = nil,
        overrideRealm = "lianqi_2",
        spawnZone = "bandit_camp", spawnX = 36, spawnY = 8,  -- bandit_backhill{33,4,47,20}, 距原BOSS(39,14)≈7格
        reward = { lingYun = 10, petFood = "immortal_bone" },
    },
    {
        id = "seal_ch1_4", chapter = 1, requiredLevel = 20,
        name = "封魔·魔虎王",
        desc = "虎王被魔气催化，凶性大发。请前往虎王领地将其镇压。",
        sourceBoss = "tiger_king",
        overrideLevel = 20,
        overrideCategory = nil,
        overrideRealm = "lianqi_3",
        spawnZone = "tiger_domain", spawnX = 63, spawnY = 20,  -- tiger_domain{58,2,78,25}, 距原BOSS(68,14)≈8格
        reward = { lingYun = 20, petFood = "demon_essence", petFoodCount = 1 },
    },

    -- ===================== 第二章（全部升级为 king_boss） =====================
    {
        id = "seal_ch2_1", chapter = 2, requiredLevel = 25,
        name = "封魔·魔猪大哥",
        desc = "猪大哥被魔气强化，在山坡上横冲直撞。",
        sourceBoss = "boar_boss_ch2",
        overrideLevel = 25,
        overrideCategory = "king_boss",
        overrideRealm = "zhuji_1",
        spawnZone = "boar_slope", spawnX = 14, spawnY = 21,  -- wild_b{2,2,30,26}, 距原BOSS(14,14)≈7格
        reward = { lingYun = 50, petFood = "demon_essence" },
    },
    {
        id = "seal_ch2_2", chapter = 2, requiredLevel = 30,
        name = "封魔·魔乌地北",
        desc = "乌地北吸收魔气后实力倍增，在修罗场兴风作浪。",
        sourceBoss = "wu_dibei",
        overrideLevel = 30,
        overrideCategory = "king_boss",
        overrideRealm = "zhuji_2",
        spawnZone = "fortress_e", spawnX = 45, spawnY = 14,  -- fortress_e1{34,2,79,26}, 距原BOSS wu_dibei(58,7)≈15格
        reward = { lingYun = 50, petFood = "demon_essence" },
    },
    {
        id = "seal_ch2_3", chapter = 2, requiredLevel = 35,
        name = "封魔·魔乌天南",
        desc = "乌天南被魔气侵蚀，剑意中夹杂凶煞之力。",
        sourceBoss = "wu_tiannan",
        overrideLevel = 35,
        overrideCategory = "king_boss",
        overrideRealm = "zhuji_3",
        spawnZone = "fortress_e", spawnX = 45, spawnY = 68,  -- fortress_e2{34,57,79,79}, 距原BOSS wu_tiannan(58,75)≈15格
        reward = { lingYun = 50, petFood = "demon_essence" },
    },
    {
        id = "seal_ch2_4", chapter = 2, requiredLevel = 40,
        name = "封魔·魔乌万仇",
        desc = "乌万仇与魔气共鸣，暗影之力更加恐怖。",
        sourceBoss = "wu_wanchou",
        overrideLevel = 40,
        overrideCategory = "king_boss",
        overrideRealm = "jindan_1",
        spawnZone = "fortress_e", spawnX = 65, spawnY = 34,  -- fortress_e4{60,24,79,58}, 距原BOSS wu_wanchou(70,41)≈9格
        reward = { lingYun = 100, petFood = "demon_essence", petFoodCount = 2 },
    },

    -- ===================== 第三章（前3个 king_boss，最后1个 emperor_boss） =====================
    {
        id = "seal_ch3_1", chapter = 3, requiredLevel = 50,
        name = "封魔·魔枯木妖王",
        desc = "枯木妖王被魔气浸透，根须贯穿大地。",
        sourceBoss = "yao_king_8",
        overrideLevel = 50,
        overrideCategory = "king_boss",
        overrideRealm = "jindan_3",
        spawnZone = "ch3_fort_8", spawnX = 35, spawnY = 12,  -- ch3_fort_8{32,8,47,23}, 距原BOSS(40,16)≈6格
        reward = { lingYun = 250, petFood = "demon_essence", petFoodCount = 2 },
    },
    {
        id = "seal_ch3_2", chapter = 3, requiredLevel = 55,
        name = "封魔·魔烈焰狮王",
        desc = "烈焰狮王吞噬大量魔气，烈焰中夹杂着魔煞之力。",
        sourceBoss = "yao_king_3",
        overrideLevel = 60,
        overrideCategory = "king_boss",
        overrideRealm = "yuanying_2",
        spawnZone = "ch3_fort_3", spawnX = 58, spawnY = 34,  -- ch3_fort_3{54,30,73,49}, 距原BOSS(63,40)≈8格
        reward = { lingYun = 250, petFood = "demon_essence", petFoodCount = 2 },
    },
    {
        id = "seal_ch3_3", chapter = 3, requiredLevel = 60,
        name = "封魔·魔蜃妖王",
        desc = "蜃妖王吞噬魔气，幻术之力足以颠倒黑白。",
        sourceBoss = "yao_king_2",
        overrideLevel = 65,
        overrideCategory = "king_boss",
        overrideRealm = "yuanying_3",
        spawnZone = "ch3_fort_2", spawnX = 34, spawnY = 58,  -- ch3_fort_2{30,54,49,73}, 距原BOSS(39,64)≈8格
        reward = { lingYun = 250, petFood = "demon_essence", petFoodCount = 2 },
    },
    {
        id = "seal_ch3_4", chapter = 3, requiredLevel = 65,
        name = "封魔·魔蛇骨妖王",
        desc = "蛇骨妖王与魔气完全融合，白骨之刺贯穿一切。终极封魔。",
        sourceBoss = "yao_king_4",
        overrideLevel = 70,
        overrideCategory = "emperor_boss",
        overrideRealm = "huashen_1",
        spawnZone = "ch3_fort_4", spawnX = 10, spawnY = 57,  -- ch3_fort_4{6,54,25,73}, 距原BOSS(15,63)≈8格
        reward = { lingYun = 500, petFood = "demon_essence", petFoodCount = 3 },
    },

    -- ===================== 第四章（全部 emperor_boss） =====================
    {
        id = "seal_ch4_1", chapter = 4, requiredLevel = 70,
        name = "封魔·魔沈渊衣",
        desc = "沈渊衣被魔气侵蚀，深渊之水化为魔潮，吞噬一切。",
        sourceBoss = "kan_boss",
        overrideLevel = 80,
        overrideCategory = "emperor_boss",
        overrideRealm = "huashen_3",
        spawnZone = "ch4_kan", spawnX = 36.5, spawnY = 13.5,  -- kan{32,7,47,22}, 距原BOSS(39.5,19.5)≈7格
        reward = { lingYun = 500, petFood = "dragon_marrow", petFoodCount = 1 },
    },
    {
        id = "seal_ch4_2", chapter = 4, requiredLevel = 80,
        name = "封魔·魔雷惊蛰",
        desc = "雷惊蛰被魔气催化，雷电中夹杂毁灭之力，轰鸣震天。",
        sourceBoss = "zhen_boss",
        overrideLevel = 90,
        overrideCategory = "emperor_boss",
        overrideRealm = "heti_2",
        spawnZone = "ch4_zhen", spawnX = 62.5, spawnY = 38.5,  -- zhen{57,32,72,47}, 距原BOSS(64.5,44.5)≈7格
        reward = { lingYun = 500, petFood = "dragon_marrow", petFoodCount = 1 },
    },
    {
        id = "seal_ch4_3", chapter = 4, requiredLevel = 90,
        name = "封魔·魔炎若晦",
        desc = "炎若晦与魔焰融合，离火化为地狱业火，焚尽万物。",
        sourceBoss = "li_boss",
        overrideLevel = 95,
        overrideCategory = "emperor_boss",
        overrideRealm = "heti_3",
        spawnZone = "ch4_li", spawnX = 42.5, spawnY = 63.5,  -- li{32,57,47,72}, 距原BOSS(39.5,69.5)≈7格
        reward = { lingYun = 500, petFood = "dragon_marrow", petFoodCount = 1 },
    },
    {
        id = "seal_ch4_4", chapter = 4, requiredLevel = 95,
        name = "封魔·魔泽归墟",
        desc = "泽归墟与魔气完全融合，泽沼化为无底魔渊，终极封魔。",
        sourceBoss = "dui_boss",
        overrideLevel = 100,
        overrideCategory = "emperor_boss",
        overrideRealm = "dacheng_1",
        spawnZone = "ch4_dui", spawnX = 12.5, spawnY = 38.5,  -- dui{7,32,22,47}, 距原BOSS(14.5,44.5)≈7格
        reward = { lingYun = 1000, petFood = "dragon_marrow", petFoodCount = 3 },
    },

    -- ===================== 第五章（全部 saint_boss） =====================
    {
        id = "seal_ch5_1", chapter = 5, requiredLevel = 105,
        name = "封魔·魔寒百炼",
        desc = "寒百炼被魔气侵蚀，锻骨之术化为噬魂黑焰。",
        sourceBoss = "ch5_han_bailian",
        overrideLevel = 120,
        overrideCategory = "saint_boss",
        overrideRealm = "dujie_1",
        spawnZone = "ch5_forge", spawnX = 7, spawnY = 26,  -- ch5_forge{4,21,17,34}, 距原BOSS(10.5,32.5)≈7格
        reward = { lingYun = 1000, petFood = "dragon_marrow", petFoodCount = 3 },
    },
    {
        id = "seal_ch5_2", chapter = 5, requiredLevel = 110,
        name = "封魔·魔石观澜",
        desc = "石观澜被魔气浸透，碑林剑意化为灭世魔锋。",
        sourceBoss = "ch5_shi_guanlan",
        overrideLevel = 120,
        overrideCategory = "saint_boss",
        overrideRealm = "dujie_1",
        spawnZone = "ch5_stele_forest", spawnX = 68, spawnY = 28,  -- ch5_stele_forest{59,21,76,44}, 距原BOSS(74.5,33.5)≈8格
        reward = { lingYun = 1000, petFood = "dragon_marrow", petFoodCount = 3 },
    },
    {
        id = "seal_ch5_3", chapter = 5, requiredLevel = 115,
        name = "封魔·魔宁七武",
        desc = "宁七武与魔气融合，拳风中夹杂腐蚀之力。",
        sourceBoss = "ch5_ning_qiwu",
        overrideLevel = 120,
        overrideCategory = "saint_boss",
        overrideRealm = "dujie_1",
        spawnZone = "ch5_sword_court", spawnX = 8, spawnY = 50,  -- ch5_sword_court{4,39,21,63}, 距原BOSS(12.5,56.5)≈8格
        reward = { lingYun = 1000, petFood = "dragon_marrow", petFoodCount = 3 },
    },
    {
        id = "seal_ch5_4", chapter = 5, requiredLevel = 120,
        name = "封魔·魔深渊统帅",
        desc = "深渊统帅与魔气完全融合，黑暗权柄碾碎万物。终极封魔。",
        sourceBoss = "ch5_abyss_marshal",
        overrideLevel = 120,
        overrideCategory = "saint_boss",
        overrideRealm = "dujie_1",
        spawnZone = "ch5_demon_abyss", spawnX = 34, spawnY = 53,  -- ch5_demon_abyss{27,50,53,67}, 距原BOSS(40.5,58)≈8格
        reward = { lingYun = 2000, petFood = "dragon_marrow", petFoodCount = 5 },
    },
}

-- ============================================================================
-- 日常封魔任务（每章1个，所有章节共享每日1次限额）
-- ============================================================================

SealDemonConfig.DAILY = {
    [1] = {
        name = "日常封魔 · 两界村",
        requiredQuests = { "seal_ch1_1", "seal_ch1_2", "seal_ch1_3", "seal_ch1_4" },
        bossPool = {
            { sourceBoss = "spider_queen",  level = 20, category = "boss", realm = "lianqi_3", spawnZone = "spider_cave",   spawnX = 65, spawnY = 62 },
            { sourceBoss = "boar_king",     level = 20, category = "boss", realm = "lianqi_3", spawnZone = "boar_forest",   spawnX = 15, spawnY = 65 },
            { sourceBoss = "bandit_chief",  level = 20, category = "boss", realm = "lianqi_3", spawnZone = "bandit_camp",   spawnX = 36, spawnY = 8  },
            { sourceBoss = "tiger_king",    level = 20, category = "boss", realm = "lianqi_3", spawnZone = "tiger_domain",  spawnX = 63, spawnY = 20 },
        },
        reward = { petFood = "demon_essence", petFoodCount = 1, physiquePill = 1 },
    },
    [2] = {
        name = "日常封魔 · 乌家堡",
        requiredQuests = { "seal_ch2_1", "seal_ch2_2", "seal_ch2_3", "seal_ch2_4" },
        bossPool = {
            { sourceBoss = "boar_boss_ch2", level = 40, category = "king_boss", realm = "jindan_1", spawnZone = "boar_slope",  spawnX = 14, spawnY = 21 },
            { sourceBoss = "wu_dibei",      level = 40, category = "king_boss", realm = "jindan_1", spawnZone = "fortress_e",  spawnX = 45, spawnY = 14 },
            { sourceBoss = "wu_tiannan",    level = 40, category = "king_boss", realm = "jindan_1", spawnZone = "fortress_e",  spawnX = 45, spawnY = 68 },
            { sourceBoss = "wu_wanchou",    level = 40, category = "king_boss", realm = "jindan_1", spawnZone = "fortress_e",  spawnX = 65, spawnY = 34 },
        },
        reward = { petFood = "demon_essence", petFoodCount = 2, physiquePill = 1 },
    },
    [3] = {
        name = "日常封魔 · 万里黄沙",
        requiredQuests = { "seal_ch3_1", "seal_ch3_2", "seal_ch3_3", "seal_ch3_4" },
        bossPool = {
            { sourceBoss = "yao_king_8",    level = 70, category = "emperor_boss", realm = "huashen_1", spawnZone = "ch3_fort_8", spawnX = 35, spawnY = 12 },
            { sourceBoss = "yao_king_3",    level = 70, category = "emperor_boss", realm = "huashen_1", spawnZone = "ch3_fort_3", spawnX = 58, spawnY = 34 },
            { sourceBoss = "yao_king_2",    level = 70, category = "emperor_boss", realm = "huashen_1", spawnZone = "ch3_fort_2", spawnX = 34, spawnY = 58 },
            { sourceBoss = "yao_king_4",    level = 70, category = "emperor_boss", realm = "huashen_1", spawnZone = "ch3_fort_4", spawnX = 10, spawnY = 57 },
        },
        reward = { petFood = "demon_essence", petFoodCount = 3, physiquePill = 1 },
    },
    [4] = {
        name = "日常封魔 · 八卦海",
        requiredQuests = { "seal_ch4_1", "seal_ch4_2", "seal_ch4_3", "seal_ch4_4" },
        bossPool = {
            { sourceBoss = "kan_boss",   level = 100, category = "emperor_boss", realm = "dacheng_1", spawnZone = "ch4_kan",  spawnX = 36.5, spawnY = 13.5 },
            { sourceBoss = "zhen_boss",  level = 100, category = "emperor_boss", realm = "dacheng_1", spawnZone = "ch4_zhen", spawnX = 62.5, spawnY = 38.5 },
            { sourceBoss = "li_boss",    level = 100, category = "emperor_boss", realm = "dacheng_1", spawnZone = "ch4_li",   spawnX = 42.5, spawnY = 63.5 },
            { sourceBoss = "dui_boss",   level = 100, category = "emperor_boss", realm = "dacheng_1", spawnZone = "ch4_dui",  spawnX = 12.5, spawnY = 38.5 },
        },
        reward = { petFood = "dragon_marrow", petFoodCount = 3, physiquePill = 1 },
    },
    [5] = {
        name = "日常封魔 · 太虚遗址",
        requiredQuests = { "seal_ch5_1", "seal_ch5_2", "seal_ch5_3", "seal_ch5_4" },
        bossPool = {
            { sourceBoss = "ch5_han_bailian",   level = 120, category = "saint_boss", realm = "dujie_1", spawnZone = "ch5_forge",         spawnX = 7,    spawnY = 26   },
            { sourceBoss = "ch5_shi_guanlan",   level = 120, category = "saint_boss", realm = "dujie_1", spawnZone = "ch5_stele_forest",  spawnX = 68,   spawnY = 28   },
            { sourceBoss = "ch5_ning_qiwu",     level = 120, category = "saint_boss", realm = "dujie_1", spawnZone = "ch5_sword_court",   spawnX = 8,    spawnY = 50   },
            { sourceBoss = "ch5_abyss_marshal", level = 120, category = "saint_boss", realm = "dujie_1", spawnZone = "ch5_demon_abyss",   spawnX = 34,   spawnY = 53   },
        },
        reward = { petFood = "dragon_marrow", petFoodCount = 5, physiquePill = 1 },
    },
}

-- ============================================================================
-- BOSS 排除清单
-- ============================================================================

SealDemonConfig.EXCLUDED_BOSSES = {
    -- ch2
    "snake_king",       -- ch2 碧鳞 Lv.26，等级高于 ch2 首任务要求(Lv.25)，替换为 boar_boss_ch2
    "wu_wanhai",        -- ch2 最终剧情 BOSS，不做封魔
    -- ch3
    "yao_king_1",       -- ch3 沙万里，不做封魔
    -- ch4
    "qian_pillar_n",    -- ch4 石柱，不做封魔
    "qian_pillar_s",    -- ch4 石柱，不做封魔
    "qian_pillar_w",    -- ch4 石柱，不做封魔
    "qian_pillar_e",    -- ch4 石柱，不做封魔
    "dragon_azure",     -- ch4 龙BOSS，不做封魔（剧情BOSS）
    "dragon_vermilion", -- ch4 龙BOSS，不做封魔（剧情BOSS）
    "dragon_white",     -- ch4 龙BOSS，不做封魔（剧情BOSS）
    "dragon_black",     -- ch4 龙BOSS，不做封魔（剧情BOSS）
    -- ch5
    "ch5_stone_guardian",      -- ch5 石傀机关，地形固定，不做封魔
    "ch5_blood_general",       -- ch5 屠血将×4群刷，不适合单体封魔
    "ch5_marshal_shugu",       -- ch5 巡逻魔帅·蚀骨，有巡逻路线
    "ch5_marshal_liesoul",     -- ch5 巡逻魔帅·裂魂，有巡逻路线
    "ch5_sword_zhu",           -- ch5 诛仙剑器灵，stationary=true
    "ch5_sword_xian",          -- ch5 陷仙剑器灵，stationary=true
    "ch5_sword_lu",            -- ch5 戮仙剑器灵，stationary=true
    "ch5_sword_jue",           -- ch5 绝仙剑器灵，stationary=true
    "artifact_sikong_xuanyin", -- ch5 神器副本专属BOSS，不做封魔
}

-- ============================================================================
-- 按 ID 索引（自动生成）
-- ============================================================================

SealDemonConfig.QUEST_BY_ID = {}
for _, q in ipairs(SealDemonConfig.QUESTS) do
    SealDemonConfig.QUEST_BY_ID[q.id] = q
end

return SealDemonConfig
