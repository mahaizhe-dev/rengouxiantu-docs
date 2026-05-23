-- ============================================================================
-- PetSkillData.lua - 宠物技能数据配置
-- 技能定义、技能书、升级配方
-- ============================================================================

local PetSkillData = {}

-- ===================== 技能定义 =====================
-- 每个技能有 2 个等级（tier 1/2），提供被动百分比属性加成

PetSkillData.SKILLS = {
    atk_basic = {
        id = "atk_basic",
        name = "攻击强化",
        icon = "⚔",
        stat = "atk",
        tiers = {
            [1] = { name = "初级攻击", value = 10, percent = true },
            [2] = { name = "中级攻击", value = 20, percent = true },
            [3] = { name = "高级攻击", value = 30, percent = true },
            [4] = { name = "特级攻击", value = 40, percent = true },
        },
    },
    hp_basic = {
        id = "hp_basic",
        name = "生命强化",
        icon = "❤",
        stat = "maxHp",
        tiers = {
            [1] = { name = "初级生命", value = 10, percent = true },
            [2] = { name = "中级生命", value = 20, percent = true },
            [3] = { name = "高级生命", value = 30, percent = true },
            [4] = { name = "特级生命", value = 40, percent = true },
        },
    },
    def_basic = {
        id = "def_basic",
        name = "防御强化",
        icon = "🛡",
        stat = "def",
        tiers = {
            [1] = { name = "初级防御", value = 10, percent = true },
            [2] = { name = "中级防御", value = 20, percent = true },
            [3] = { name = "高级防御", value = 30, percent = true },
            [4] = { name = "特级防御", value = 40, percent = true },
        },
    },
    evade_basic = {
        id = "evade_basic",
        name = "闪避强化",
        icon = "💨",
        stat = "evadeChance",
        tiers = {
            [1] = { name = "低级闪避", value = 5, percent = true },
            [2] = { name = "中级闪避", value = 10, percent = true },
            [3] = { name = "高级闪避", value = 15, percent = true },
            [4] = { name = "特级闪避", value = 20, percent = true },
        },
    },
    regen_basic = {
        id = "regen_basic",
        name = "恢复强化",
        icon = "💚",
        stat = "hpRegenPct",
        tiers = {
            [1] = { name = "低级恢复", value = 1, percent = true },
            [2] = { name = "中级恢复", value = 2, percent = true },
            [3] = { name = "高级恢复", value = 3, percent = true },
            [4] = { name = "特级恢复", value = 4, percent = true },
        },
    },
    crit_basic = {
        id = "crit_basic",
        name = "暴击强化",
        icon = "💥",
        stat = "critRate",
        tiers = {
            [1] = { name = "低级暴击", value = 5, percent = true },
            [2] = { name = "中级暴击", value = 10, percent = true },
            [3] = { name = "高级暴击", value = 15, percent = true },
            [4] = { name = "特级暴击", value = 20, percent = true },
        },
    },
    -- ===================== Ch3 新技能 =====================
    atkSpd_basic = {
        id = "atkSpd_basic",
        name = "攻速强化",
        icon = "⚡",
        stat = "atkSpeedPct",
        tiers = {
            [1] = { name = "初级攻速", value = 8, percent = true },
            [2] = { name = "中级攻速", value = 15, percent = true },
            [3] = { name = "高级攻速", value = 20, percent = true },
            [4] = { name = "特级攻速", value = 25, percent = true },
        },
    },
    critDmg_basic = {
        id = "critDmg_basic",
        name = "暴伤强化",
        icon = "💎",
        stat = "critDmgPct",
        tiers = {
            [1] = { name = "初级暴伤", value = 15, percent = true },
            [2] = { name = "中级暴伤", value = 30, percent = true },
            [3] = { name = "高级暴伤", value = 45, percent = true },
            [4] = { name = "特级暴伤", value = 60, percent = true },
        },
    },
    doubleHit_basic = {
        id = "doubleHit_basic",
        name = "连击强化",
        icon = "✌",
        stat = "doubleHitPct",
        tiers = {
            [1] = { name = "初级连击", value = 8, percent = true },
            [2] = { name = "中级连击", value = 15, percent = true },
            [3] = { name = "高级连击", value = 20, percent = true },
            [4] = { name = "特级连击", value = 25, percent = true },
        },
    },
    lifeSteal_basic = {
        id = "lifeSteal_basic",
        name = "吸血强化",
        icon = "🩸",
        stat = "lifeStealPct",
        tiers = {
            [1] = { name = "初级吸血", value = 3, percent = true },
            [2] = { name = "中级吸血", value = 6, percent = true },
            [3] = { name = "高级吸血", value = 9, percent = true },
            [4] = { name = "特级吸血", value = 12, percent = true },
        },
    },
    hpPerLv_basic = {
        id = "hpPerLv_basic",
        name = "生命·蕴灵",
        icon = "💖",
        stat = "maxHp",
        tiers = {
            [1] = { name = "初级蕴灵·生命", value = 5, perLevel = true },
            [2] = { name = "中级蕴灵·生命", value = 10, perLevel = true },
            [3] = { name = "高级蕴灵·生命", value = 15, perLevel = true },
            [4] = { name = "特级蕴灵·生命", value = 20, perLevel = true },
        },
    },
    dmgReduce_basic = {
        id = "dmgReduce_basic",
        name = "减伤强化",
        icon = "🪨",
        stat = "dmgReducePct",
        tiers = {
            [1] = { name = "初级减伤", value = 5, percent = true },
            [2] = { name = "中级减伤", value = 10, percent = true },
            [3] = { name = "高级减伤", value = 15, percent = true },
            [4] = { name = "特级减伤", value = 20, percent = true },
        },
    },
    defPerLv_basic = {
        id = "defPerLv_basic",
        name = "防御·蕴灵",
        icon = "🏔",
        stat = "def",
        tiers = {
            [1] = { name = "初级蕴灵·防御", value = 0.5, perLevel = true },
            [2] = { name = "中级蕴灵·防御", value = 1, perLevel = true },
            [3] = { name = "高级蕴灵·防御", value = 1.5, perLevel = true },
            [4] = { name = "特级蕴灵·防御", value = 2, perLevel = true },
        },
    },
    -- ===================== Ch5 新技能 =====================
    ignoreDef_basic = {
        id = "ignoreDef_basic",
        name = "忽视强化",
        icon = "🔱",
        stat = "ignoreDefPct",
        tiers = {
            [1] = { name = "初级忽视", value = 8, percent = true },
            [2] = { name = "中级忽视", value = 15, percent = true },
            [3] = { name = "高级忽视", value = 20, percent = true },
            [4] = { name = "特级忽视", value = 25, percent = true },
        },
    },
    atkPerLv_basic = {
        id = "atkPerLv_basic",
        name = "攻击·蕴灵",
        icon = "⚔",
        stat = "atk",
        tiers = {
            [1] = { name = "初级蕴灵·攻击", value = 0.5, perLevel = true },
            [2] = { name = "中级蕴灵·攻击", value = 1, perLevel = true },
            [3] = { name = "高级蕴灵·攻击", value = 1.5, perLevel = true },
            [4] = { name = "特级蕴灵·攻击", value = 2, perLevel = true },
        },
    },
    bonusDmg_basic = {
        id = "bonusDmg_basic",
        name = "加伤强化",
        icon = "🔥",
        stat = "bonusDmgPct",
        tiers = {
            [1] = { name = "初级加伤", value = 5, percent = true },
            [2] = { name = "中级加伤", value = 10, percent = true },
            [3] = { name = "高级加伤", value = 15, percent = true },
            [4] = { name = "特级加伤", value = 20, percent = true },
        },
    },
    -- ===================== 灵兽赐主技能（加成主人仙缘属性） =====================
    wisdom_owner = {
        id = "wisdom_owner",
        name = "灵兽通慧",
        icon = "📘",
        stat = "wisdom",
        targetOwner = true,
        tiers = {
            [1] = { name = "灵兽通慧", value = 10, flat = true },
            [2] = { name = "灵兽通慧·贰", value = 20, flat = true },
            [3] = { name = "灵兽通慧·叁", value = 30, flat = true },
            [4] = { name = "灵兽通慧·肆", value = 40, flat = true },
        },
    },
    constitution_owner = {
        id = "constitution_owner",
        name = "灵兽铸骨",
        icon = "📗",
        stat = "constitution",
        targetOwner = true,
        tiers = {
            [1] = { name = "灵兽铸骨", value = 10, flat = true },
            [2] = { name = "灵兽铸骨·贰", value = 20, flat = true },
            [3] = { name = "灵兽铸骨·叁", value = 30, flat = true },
            [4] = { name = "灵兽铸骨·肆", value = 40, flat = true },
        },
    },
    physique_owner = {
        id = "physique_owner",
        name = "灵兽淬体",
        icon = "📕",
        stat = "physique",
        targetOwner = true,
        tiers = {
            [1] = { name = "灵兽淬体", value = 10, flat = true },
            [2] = { name = "灵兽淬体·贰", value = 20, flat = true },
            [3] = { name = "灵兽淬体·叁", value = 30, flat = true },
            [4] = { name = "灵兽淬体·肆", value = 40, flat = true },
        },
    },
    fortune_owner = {
        id = "fortune_owner",
        name = "灵兽赐福",
        icon = "📙",
        stat = "fortune",
        targetOwner = true,
        tiers = {
            [1] = { name = "灵兽赐福", value = 10, flat = true },
            [2] = { name = "灵兽赐福·贰", value = 20, flat = true },
            [3] = { name = "灵兽赐福·叁", value = 30, flat = true },
            [4] = { name = "灵兽赐福·肆", value = 40, flat = true },
        },
    },
}

--- 最大技能等级
PetSkillData.MAX_TIER = 4

-- ===================== 技能书定义（消耗品） =====================
-- consumableId 格式: book_<stat>_<tier>

PetSkillData.SKILL_BOOKS = {
    book_atk_1 = { name = "初级攻击书", icon = "book_atk.png", skillId = "atk_basic", tier = 1, quality = "blue",    sellPrice = 200, desc = "记载了初级攻击强化法诀。\n用途：宠物攻击+10%。" },
    book_hp_1  = { name = "初级生命书", icon = "book_hp.png",  skillId = "hp_basic",  tier = 1, quality = "blue",    sellPrice = 200, desc = "记载了初级生命强化法诀。\n用途：宠物生命+10%。" },
    book_def_1 = { name = "初级防御书", icon = "book_def.png", skillId = "def_basic", tier = 1, quality = "blue",    sellPrice = 200, desc = "记载了初级防御强化法诀。\n用途：宠物防御+10%。" },
    book_atk_2 = { name = "中级攻击书", icon = "book_atk.png", skillId = "atk_basic", tier = 2, quality = "purple",  sellPrice = 1000, desc = "记载了中级攻击强化法诀。\n用途：升级初级攻击，攻击+20%。" },
    book_hp_2  = { name = "中级生命书", icon = "book_hp.png",  skillId = "hp_basic",  tier = 2, quality = "purple",  sellPrice = 1000, desc = "记载了中级生命强化法诀。\n用途：升级初级生命，生命+20%。" },
    book_def_2 = { name = "中级防御书", icon = "book_def.png", skillId = "def_basic", tier = 2, quality = "purple",  sellPrice = 1000, desc = "记载了中级防御强化法诀。\n用途：升级初级防御，防御+20%。" },
    -- Ch2 新技能书
    book_evade_1 = { name = "初级闪避书", icon = "book_evade.png", skillId = "evade_basic", tier = 1, quality = "blue", sellPrice = 200, desc = "记载了闪避强化法诀。\n用途：宠物闪避率+5%。" },
    book_regen_1 = { name = "初级恢复书", icon = "book_regen.png", skillId = "regen_basic", tier = 1, quality = "blue", sellPrice = 200, desc = "记载了恢复强化法诀。\n用途：宠物每秒回复1%最大生命。" },
    book_crit_1  = { name = "初级暴击书", icon = "book_crit.png", skillId = "crit_basic",  tier = 1, quality = "blue", sellPrice = 200, desc = "记载了暴击强化法诀。\n用途：宠物暴击率+5%。" },
    book_evade_2 = { name = "中级闪避书", icon = "book_evade.png", skillId = "evade_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级闪避强化法诀。\n用途：升级初级闪避，闪避率+10%。" },
    book_regen_2 = { name = "中级恢复书", icon = "book_regen.png", skillId = "regen_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级恢复强化法诀。\n用途：升级初级恢复，每秒回复2%最大生命。" },
    book_crit_2  = { name = "中级暴击书", icon = "book_crit.png", skillId = "crit_basic",  tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级暴击强化法诀。\n用途：升级初级暴击，暴击率+10%。" },
    -- Ch3 新技能书
    book_atkSpd_1    = { name = "初级攻速书", icon = "book_atkSpd.png", skillId = "atkSpd_basic",    tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了攻速强化法诀。\n用途：宠物攻击速度+8%。" },
    book_atkSpd_2    = { name = "中级攻速书", icon = "book_atkSpd.png", skillId = "atkSpd_basic",    tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级攻速强化法诀。\n用途：升级初级攻速，攻击速度+15%。" },
    book_critDmg_1   = { name = "初级暴伤书", icon = "book_critDmg.png", skillId = "critDmg_basic",  tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了暴伤强化法诀。\n用途：宠物暴击伤害+15%。" },
    book_critDmg_2   = { name = "中级暴伤书", icon = "book_critDmg.png", skillId = "critDmg_basic",  tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级暴伤强化法诀。\n用途：升级初级暴伤，暴击伤害+30%。" },
    book_doubleHit_1 = { name = "初级连击书", icon = "book_doubleHit.png", skillId = "doubleHit_basic", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了连击法诀。\n用途：宠物普攻8%概率追加一击。" },
    book_doubleHit_2 = { name = "中级连击书", icon = "book_doubleHit.png", skillId = "doubleHit_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级连击法诀。\n用途：升级初级连击，普攻15%概率追加一击。" },
    book_lifeSteal_1 = { name = "初级吸血书", icon = "book_lifeSteal.png", skillId = "lifeSteal_basic", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了吸血法诀。\n用途：宠物攻击吸血3%。" },
    book_lifeSteal_2 = { name = "中级吸血书", icon = "book_lifeSteal.png", skillId = "lifeSteal_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级吸血法诀。\n用途：升级初级吸血，攻击吸血6%。" },
    book_hpPerLv_1   = { name = "初级蕴灵·生命书", icon = "book_hpPerLv.png", skillId = "hpPerLv_basic", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了蕴灵生命法诀。\n用途：宠物每级+5生命值。" },
    book_hpPerLv_2   = { name = "中级蕴灵·生命书", icon = "book_hpPerLv.png", skillId = "hpPerLv_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级蕴灵生命法诀。\n用途：升级初级蕴灵·生命，每级+10生命值。" },
    book_dmgReduce_1 = { name = "初级减伤书", icon = "book_dmgReduce.png", skillId = "dmgReduce_basic", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了减伤法诀。\n用途：宠物受伤减免5%。" },
    book_dmgReduce_2 = { name = "中级减伤书", icon = "book_dmgReduce.png", skillId = "dmgReduce_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级减伤法诀。\n用途：升级初级减伤，受伤减免10%。" },
    book_defPerLv_1  = { name = "初级蕴灵·防御书", icon = "book_defPerLv.png", skillId = "defPerLv_basic", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了蕴灵防御法诀。\n用途：宠物每级+0.5防御值。" },
    book_defPerLv_2  = { name = "中级蕴灵·防御书", icon = "book_defPerLv.png", skillId = "defPerLv_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级蕴灵防御法诀。\n用途：升级初级蕴灵·防御，每级+1防御值。" },
    -- 灵兽赐主技能书（加成主人仙缘属性）
    book_wisdom_owner_1      = { name = "灵兽通慧书",     icon = "book_wisdom.png",       skillId = "wisdom_owner",       tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了灵兽通慧法诀。\n用途：主人悟性+10。" },
    book_wisdom_owner_2      = { name = "灵兽通慧书·贰",  icon = "book_wisdom.png",       skillId = "wisdom_owner",       tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级灵兽通慧法诀。\n用途：升级灵兽通慧，主人悟性+20。" },
    book_constitution_owner_1 = { name = "灵兽铸骨书",     icon = "book_constitution.png", skillId = "constitution_owner", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了灵兽铸骨法诀。\n用途：主人根骨+10。" },
    book_constitution_owner_2 = { name = "灵兽铸骨书·贰",  icon = "book_constitution.png", skillId = "constitution_owner", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级灵兽铸骨法诀。\n用途：升级灵兽铸骨，主人根骨+20。" },
    book_physique_owner_1    = { name = "灵兽淬体书",     icon = "book_physique.png",     skillId = "physique_owner",     tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了灵兽淬体法诀。\n用途：主人体魄+10。" },
    book_physique_owner_2    = { name = "灵兽淬体书·贰",  icon = "book_physique.png",     skillId = "physique_owner",     tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级灵兽淬体法诀。\n用途：升级灵兽淬体，主人体魄+20。" },
    book_fortune_owner_1     = { name = "灵兽赐福书",     icon = "book_fortune.png",      skillId = "fortune_owner",      tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了灵兽赐福法诀。\n用途：主人福缘+10。" },
    book_fortune_owner_2     = { name = "灵兽赐福书·贰",  icon = "book_fortune.png",      skillId = "fortune_owner",      tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级灵兽赐福法诀。\n用途：升级灵兽赐福，主人福缘+20。" },
    -- Ch4 高级技能书（tier 3，橙色品质）
    book_atk_3       = { name = "高级攻击书",       icon = "book_atk.png",       skillId = "atk_basic",       tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级攻击强化法诀。\n用途：升级中级攻击，攻击+30%。" },
    book_hp_3        = { name = "高级生命书",       icon = "book_hp.png",        skillId = "hp_basic",        tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级生命强化法诀。\n用途：升级中级生命，生命+30%。" },
    book_def_3       = { name = "高级防御书",       icon = "book_def.png",       skillId = "def_basic",       tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级防御强化法诀。\n用途：升级中级防御，防御+30%。" },
    book_evade_3     = { name = "高级闪避书",       icon = "book_evade.png",     skillId = "evade_basic",     tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级闪避强化法诀。\n用途：升级中级闪避，闪避率+15%。" },
    book_regen_3     = { name = "高级恢复书",       icon = "book_regen.png",     skillId = "regen_basic",     tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级恢复强化法诀。\n用途：升级中级恢复，每秒回复3%最大生命。" },
    book_crit_3      = { name = "高级暴击书",       icon = "book_crit.png",      skillId = "crit_basic",      tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级暴击强化法诀。\n用途：升级中级暴击，暴击率+15%。" },
    book_atkSpd_3    = { name = "高级攻速书",       icon = "book_atkSpd.png",    skillId = "atkSpd_basic",    tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级攻速强化法诀。\n用途：升级中级攻速，攻击速度+20%。" },
    book_critDmg_3   = { name = "高级暴伤书",       icon = "book_critDmg.png",   skillId = "critDmg_basic",   tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级暴伤强化法诀。\n用途：升级中级暴伤，暴击伤害+45%。" },
    book_doubleHit_3 = { name = "高级连击书",       icon = "book_doubleHit.png", skillId = "doubleHit_basic", tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级连击法诀。\n用途：升级中级连击，普攻20%概率追加一击。" },
    book_lifeSteal_3 = { name = "高级吸血书",       icon = "book_lifeSteal.png", skillId = "lifeSteal_basic", tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级吸血法诀。\n用途：升级中级吸血，攻击吸血9%。" },
    book_hpPerLv_3   = { name = "高级蕴灵·生命书", icon = "book_hpPerLv.png",   skillId = "hpPerLv_basic",   tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级蕴灵生命法诀。\n用途：升级中级蕴灵·生命，每级+15生命值。" },
    book_dmgReduce_3 = { name = "高级减伤书",       icon = "book_dmgReduce.png", skillId = "dmgReduce_basic", tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级减伤法诀。\n用途：升级中级减伤，受伤减免15%。" },
    book_defPerLv_3  = { name = "高级蕴灵·防御书", icon = "book_defPerLv.png",  skillId = "defPerLv_basic",  tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级蕴灵防御法诀。\n用途：升级中级蕴灵·防御，每级+1.5防御值。" },
    book_wisdom_owner_3      = { name = "灵兽通慧书·叁",  icon = "book_wisdom.png",       skillId = "wisdom_owner",       tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级灵兽通慧法诀。\n用途：升级灵兽通慧·贰，主人悟性+30。" },
    book_constitution_owner_3 = { name = "灵兽铸骨书·叁", icon = "book_constitution.png", skillId = "constitution_owner", tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级灵兽铸骨法诀。\n用途：升级灵兽铸骨·贰，主人根骨+30。" },
    book_physique_owner_3    = { name = "灵兽淬体书·叁",  icon = "book_physique.png",     skillId = "physique_owner",     tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级灵兽淬体法诀。\n用途：升级灵兽淬体·贰，主人体魄+30。" },
    book_fortune_owner_3     = { name = "灵兽赐福书·叁",  icon = "book_fortune.png",      skillId = "fortune_owner",      tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级灵兽赐福法诀。\n用途：升级灵兽赐福·贰，主人福缘+30。" },
    -- Ch5 新技能书（忽视/蕴灵·攻击/加伤）
    book_ignoreDef_1 = { name = "初级忽视书", icon = "book_ignoreDef.png", skillId = "ignoreDef_basic", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了忽视法诀。\n用途：宠物8%概率打出无视防御伤害。\n普攻、连击、灵噬均可触发。" },
    book_ignoreDef_2 = { name = "中级忽视书", icon = "book_ignoreDef.png", skillId = "ignoreDef_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级忽视法诀。\n用途：升级初级忽视，15%概率打出无视防御伤害。\n普攻、连击、灵噬均可触发。" },
    book_ignoreDef_3 = { name = "高级忽视书", icon = "book_ignoreDef.png", skillId = "ignoreDef_basic", tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级忽视法诀。\n用途：升级中级忽视，20%概率打出无视防御伤害。\n普攻、连击、灵噬均可触发。" },
    book_atkPerLv_1  = { name = "初级蕴灵·攻击书", icon = "book_atkPerLv.png", skillId = "atkPerLv_basic", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了蕴灵攻击法诀。\n用途：宠物每级+0.5攻击值。" },
    book_atkPerLv_2  = { name = "中级蕴灵·攻击书", icon = "book_atkPerLv.png", skillId = "atkPerLv_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级蕴灵攻击法诀。\n用途：升级初级蕴灵·攻击，每级+1攻击值。" },
    book_atkPerLv_3  = { name = "高级蕴灵·攻击书", icon = "book_atkPerLv.png", skillId = "atkPerLv_basic", tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级蕴灵攻击法诀。\n用途：升级中级蕴灵·攻击，每级+1.5攻击值。" },
    book_bonusDmg_1  = { name = "初级加伤书", icon = "book_bonusDmg.png", skillId = "bonusDmg_basic", tier = 1, quality = "blue",   sellPrice = 200,  desc = "记载了加伤法诀。\n用途：宠物全伤害+5%。\n普攻、连击、灵噬均受加成。" },
    book_bonusDmg_2  = { name = "中级加伤书", icon = "book_bonusDmg.png", skillId = "bonusDmg_basic", tier = 2, quality = "purple", sellPrice = 1000, desc = "记载了中级加伤法诀。\n用途：升级初级加伤，全伤害+10%。\n普攻、连击、灵噬均受加成。" },
    book_bonusDmg_3  = { name = "高级加伤书", icon = "book_bonusDmg.png", skillId = "bonusDmg_basic", tier = 3, quality = "orange", sellPrice = 3000, desc = "记载了高级加伤法诀。\n用途：升级中级加伤，全伤害+15%。\n普攻、连击、灵噬均受加成。" },
    -- Ch5 特级技能书（tier 4，红色圣器品质）
    book_atk_4       = { name = "特级攻击书",       icon = "book_atk.png",       skillId = "atk_basic",       tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级攻击强化法诀。\n用途：升级高级攻击，攻击+40%。" },
    book_hp_4        = { name = "特级生命书",       icon = "book_hp.png",        skillId = "hp_basic",        tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级生命强化法诀。\n用途：升级高级生命，生命+40%。" },
    book_def_4       = { name = "特级防御书",       icon = "book_def.png",       skillId = "def_basic",       tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级防御强化法诀。\n用途：升级高级防御，防御+40%。" },
    book_evade_4     = { name = "特级闪避书",       icon = "book_evade.png",     skillId = "evade_basic",     tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级闪避强化法诀。\n用途：升级高级闪避，闪避率+20%。" },
    book_regen_4     = { name = "特级恢复书",       icon = "book_regen.png",     skillId = "regen_basic",     tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级恢复强化法诀。\n用途：升级高级恢复，每秒回复4%最大生命。" },
    book_crit_4      = { name = "特级暴击书",       icon = "book_crit.png",      skillId = "crit_basic",      tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级暴击强化法诀。\n用途：升级高级暴击，暴击率+20%。" },
    book_atkSpd_4    = { name = "特级攻速书",       icon = "book_atkSpd.png",    skillId = "atkSpd_basic",    tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级攻速强化法诀。\n用途：升级高级攻速，攻击速度+25%。" },
    book_critDmg_4   = { name = "特级暴伤书",       icon = "book_critDmg.png",   skillId = "critDmg_basic",   tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级暴伤强化法诀。\n用途：升级高级暴伤，暴击伤害+60%。" },
    book_doubleHit_4 = { name = "特级连击书",       icon = "book_doubleHit.png", skillId = "doubleHit_basic", tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级连击法诀。\n用途：升级高级连击，普攻25%概率追加一击。" },
    book_lifeSteal_4 = { name = "特级吸血书",       icon = "book_lifeSteal.png", skillId = "lifeSteal_basic", tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级吸血法诀。\n用途：升级高级吸血，攻击吸血12%。" },
    book_hpPerLv_4   = { name = "特级蕴灵·生命书", icon = "book_hpPerLv.png",   skillId = "hpPerLv_basic",   tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级蕴灵生命法诀。\n用途：升级高级蕴灵·生命，每级+20生命值。" },
    book_dmgReduce_4 = { name = "特级减伤书",       icon = "book_dmgReduce.png", skillId = "dmgReduce_basic", tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级减伤法诀。\n用途：升级高级减伤，受伤减免20%。" },
    book_defPerLv_4  = { name = "特级蕴灵·防御书", icon = "book_defPerLv.png",  skillId = "defPerLv_basic",  tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级蕴灵防御法诀。\n用途：升级高级蕴灵·防御，每级+2防御值。" },
    book_ignoreDef_4 = { name = "特级忽视书",       icon = "book_ignoreDef.png", skillId = "ignoreDef_basic", tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级忽视法诀。\n用途：升级高级忽视，25%概率打出无视防御伤害。\n普攻、连击、灵噬均可触发。" },
    book_atkPerLv_4  = { name = "特级蕴灵·攻击书", icon = "book_atkPerLv.png",  skillId = "atkPerLv_basic",  tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级蕴灵攻击法诀。\n用途：升级高级蕴灵·攻击，每级+2攻击值。" },
    book_bonusDmg_4  = { name = "特级加伤书",       icon = "book_bonusDmg.png",  skillId = "bonusDmg_basic",  tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级加伤法诀。\n用途：升级高级加伤，全伤害+20%。\n普攻、连击、灵噬均受加成。" },
    book_wisdom_owner_4       = { name = "灵兽通慧书·肆", icon = "book_wisdom.png",       skillId = "wisdom_owner",       tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级灵兽通慧法诀。\n用途：升级灵兽通慧·叁，主人悟性+40。" },
    book_constitution_owner_4 = { name = "灵兽铸骨书·肆", icon = "book_constitution.png", skillId = "constitution_owner", tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级灵兽铸骨法诀。\n用途：升级灵兽铸骨·叁，主人根骨+40。" },
    book_physique_owner_4     = { name = "灵兽淬体书·肆", icon = "book_physique.png",     skillId = "physique_owner",     tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级灵兽淬体法诀。\n用途：升级灵兽淬体·叁，主人体魄+40。" },
    book_fortune_owner_4      = { name = "灵兽赐福书·肆", icon = "book_fortune.png",      skillId = "fortune_owner",      tier = 4, quality = "red", sellPrice = 8000, desc = "记载了特级灵兽赐福法诀。\n用途：升级灵兽赐福·叁，主人福缘+40。" },
}

-- ===================== 升级配方 =====================
-- key = 目标 tier，需要对应 tier 的书 + 灵韵

PetSkillData.UPGRADE_COST = {
    [2] = {
        pathA = { bookCount = 1, lingYun = 0,  successRate = 0.20 },  -- 普通升级：20%成功率
        pathB = { bookCount = 1, lingYun = 100, successRate = 1.0  },  -- 精研升级：100%成功率
    },
    [3] = {
        pathA = { bookCount = 1, lingYun = 0,    successRate = 0.10 },  -- 普通升级：10%成功率
        pathB = { bookCount = 1, lingYun = 1000, successRate = 1.0  },  -- 精研升级：100%成功率，1000灵韵
    },
    [4] = {
        pathA = { bookCount = 1, lingYun = 0,      successRate = 0.10 },  -- 普通升级：10%成功率
        pathB = { bookCount = 1, lingYun = 10000,  successRate = 1.0  },  -- 精研升级：100%成功率，10000灵韵
    },
}

-- ===================== 属性名映射 =====================

PetSkillData.STAT_NAMES = {
    atk = "攻击",
    maxHp = "生命",
    def = "防御",
    evadeChance = "闪避",
    hpRegenPct = "回复",
    critRate = "暴击",
    atkSpeedPct = "攻速",
    critDmgPct = "暴伤",
    doubleHitPct = "连击",
    lifeStealPct = "吸血",
    dmgReducePct = "减伤",
    ignoreDefPct = "忽视",
    bonusDmgPct = "加伤",
    wisdom = "悟性",
    constitution = "根骨",
    physique = "体魄",
    fortune = "福缘",
}

-- ===================== 主动技能：灵噬 =====================
-- T1解锁，随进阶自动升级。单体伤害 + 易伤debuff

PetSkillData.ACTIVE_SKILL = {
    id = "spirit_bite",
    name = "灵噬",
    icon = "🐺",
    unlockTier = 1,  -- T1(灵犬)解锁
    description = "凝聚灵力撕咬目标，造成%d%%攻击力伤害，并使其受到所有伤害增加8%%，持续4秒",
    cd = 12.0,          -- 固定CD
    vulnPercent = 0.08, -- 固定8%易伤
    vulnDuration = 4.0, -- 固定4秒
    -- 每阶伤害倍率：T1=100%, 每阶+20%
    tiers = {
        [1] = { dmgMult = 1.00 },
        [2] = { dmgMult = 1.20 },
        [3] = { dmgMult = 1.40 },
        [4] = { dmgMult = 1.60 },
        [5] = { dmgMult = 1.80 },
        [6] = { dmgMult = 2.00 },
        [7] = { dmgMult = 2.20 },
    },
}

--- 获取灵噬技能描述（按阶级）
---@param tier number 宠物阶级(1-3)
---@return string
function PetSkillData.GetActiveSkillDesc(tier)
    local skill = PetSkillData.ACTIVE_SKILL
    local td = skill.tiers[tier]
    local dmgPct = td and math.floor(td.dmgMult * 100) or 100
    return string.format(skill.description, dmgPct)
end

-- ===================== 工具函数 =====================

--- 获取技能显示名称（含等级）
---@param skillId string
---@param tier number
---@return string
function PetSkillData.GetSkillDisplayName(skillId, tier)
    local skill = PetSkillData.SKILLS[skillId]
    if not skill then return "未知技能" end
    local tierData = skill.tiers[tier]
    if not tierData then return skill.name end
    return tierData.name
end

--- 获取技能加成值
---@param skillId string
---@param tier number
---@return string stat, number value, boolean percent, boolean perLevel, boolean flat, boolean targetOwner
function PetSkillData.GetSkillBonus(skillId, tier)
    local skill = PetSkillData.SKILLS[skillId]
    if not skill then return "atk", 0, false, false, false, false end
    local tierData = skill.tiers[tier]
    if not tierData then return skill.stat, 0, false, false, false, false end
    return skill.stat, tierData.value, tierData.percent == true, tierData.perLevel == true, tierData.flat == true, skill.targetOwner == true
end

--- 获取技能图标
---@param skillId string
---@return string
function PetSkillData.GetSkillIcon(skillId)
    local skill = PetSkillData.SKILLS[skillId]
    return skill and skill.icon or "?"
end

--- 通过技能书 consumableId 获取书数据
---@param bookId string
---@return table|nil
function PetSkillData.GetBookData(bookId)
    return PetSkillData.SKILL_BOOKS[bookId]
end

return PetSkillData
