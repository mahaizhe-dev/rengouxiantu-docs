-- ============================================================================
-- MonsterTypes_ch3_Challenge.lua - 挑战副本 T1-T8（沈墨 + 陆青云）
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
-- ===================== 挑战副本：血煞盟·沈墨 =====================

M.Types.challenge_shenmo_t1 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "boss",
    race = "human",
    level = 25,
    realm = "zhuji_1",
    bodyColor = {140, 50, 50, 255},
    clawColor = {200, 30, 30},          -- 血红爪击
    skillTextColor = {255, 80, 60, 255}, -- 血色技能名浮字
    warningColorOverride = {180, 30, 30, 120}, -- 通用技能预警覆盖为血色
    phases = 1,
    skills = { "line_charge", "whirlwind" },
    dropTable = {},
    isChallenge = true,
    -- 血煞印记：命中叠层，每层扣1%最大血量/秒，不过期
    bloodMark = { damagePercent = 0.01 },
}

M.Types.challenge_shenmo_t2 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "boss",
    race = "human",
    level = 30,
    realm = "zhuji_2",
    bodyColor = {160, 40, 40, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 2,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.3,
          announce = "血海...涌动！",
          triggerSkill = "shenmo_blood_flood_easy" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.01 },
}

M.Types.challenge_shenmo_t3 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 35,
    realm = "zhuji_3",
    bodyColor = {180, 30, 30, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 2,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        -- P2: HP<50% 狂暴+场地技能（低难度）
        { threshold = 0.5, atkMult = 1.0, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌！",
          triggerSkill = "shenmo_blood_flood_easy" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.015 },
}

M.Types.challenge_shenmo_t4 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 40,
    realm = "jindan_1",
    bodyColor = {200, 20, 20, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        -- P2: HP<60% 场地技能+狂暴+分身
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        -- P3: HP<25% 强化狂暴+场地技能
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
}

-- ===================== 挑战副本：浩气宗·陆青云 =====================

M.Types.challenge_luqingyun_t1 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "boss",
    race = "human",
    level = 25,
    realm = "zhuji_1",
    bodyColor = {50, 90, 160, 255},
    clawColor = {220, 180, 40},          -- 金黄爪击
    skillTextColor = {255, 220, 60, 255}, -- 金黄技能名浮字
    warningColorOverride = {220, 180, 40, 120}, -- 通用技能预警覆盖为金黄
    phases = 1,
    skills = { "shield_bash", "rect_sweep" },
    dropTable = {},
    isChallenge = true,
    -- 正气结界：周期性生成永久屏障区域，对玩家造成30%ATK/秒
    barrierZone = { interval = 30, maxCount = 2, damagePercent = 0.30, radius = 0.8 },
}

M.Types.challenge_luqingyun_t2 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "boss",
    race = "human",
    level = 30,
    realm = "zhuji_2",
    bodyColor = {40, 100, 180, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 2,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.3,
          announce = "天罡剑阵...聚！",
          triggerSkill = "luqingyun_sword_array_easy" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 30, maxCount = 2, damagePercent = 0.30, radius = 0.8 },
}

M.Types.challenge_luqingyun_t3 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 35,
    realm = "zhuji_3",
    bodyColor = {30, 110, 200, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 2,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        -- P2: HP<50% 狂暴+场地技能（低难度）
        { threshold = 0.5, atkMult = 1.0, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array_easy" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 30, maxCount = 3, damagePercent = 0.30, radius = 0.8 },
}

M.Types.challenge_luqingyun_t4 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 40,
    realm = "jindan_1",
    bodyColor = {20, 120, 220, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        -- P2: HP<60% 场地技能+狂暴+囚笼
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        -- P3: HP<30% 强化狂暴+场地技能
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
}

-- ===================== 挑战副本：血煞盟·沈墨 T5-T8（第三章沙海试炼） =====================

M.Types.challenge_shenmo_t5 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 50,
    realm = "jindan_3",
    bodyColor = {200, 20, 20, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
}

M.Types.challenge_shenmo_t6 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 55,
    realm = "yuanying_1",
    bodyColor = {220, 15, 15, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

M.Types.challenge_shenmo_t7 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 60,
    realm = "yuanying_2",
    bodyColor = {230, 10, 10, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

M.Types.challenge_shenmo_t8 = {
    name = "沈墨",
    icon = "🗡️",
    portrait = "Textures/npc_xuesha_spy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 60,
    realm = "yuanying_3",
    bodyColor = {240, 5, 5, 255},
    clawColor = {200, 30, 30},
    skillTextColor = {255, 80, 60, 255},
    warningColorOverride = {180, 30, 30, 120},
    phases = 3,
    skills = { "line_charge", "whirlwind", "cross_smash" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "血海...翻涌吧！",
          triggerSkill = "shenmo_blood_flood",
          addSkill = "shenmo_shadow_clone" },
        { threshold = 0.25, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "以我之血，染尽苍穹！",
          triggerSkill = "shenmo_blood_flood" },
    },
    dropTable = {},
    isChallenge = true,
    bloodMark = { damagePercent = 0.02 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

-- ===================== 挑战副本：浩气宗·陆青云 T5-T8（第三章沙海试炼） =====================

M.Types.challenge_luqingyun_t5 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 50,
    realm = "jindan_3",
    bodyColor = {20, 120, 220, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
}

M.Types.challenge_luqingyun_t6 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 55,
    realm = "yuanying_1",
    bodyColor = {15, 130, 235, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

M.Types.challenge_luqingyun_t7 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "king_boss",
    race = "human",
    level = 60,
    realm = "yuanying_2",
    bodyColor = {10, 140, 245, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

M.Types.challenge_luqingyun_t8 = {
    name = "陆青云",
    icon = "⚔️",
    portrait = "Textures/npc_haoqi_envoy.png",
    zone = "challenge_arena",
    category = "emperor_boss",
    race = "human",
    level = 60,
    realm = "yuanying_3",
    bodyColor = {5, 150, 255, 255},
    clawColor = {220, 180, 40},
    skillTextColor = {255, 220, 60, 255},
    warningColorOverride = {220, 180, 40, 120},
    phases = 3,
    skills = { "shield_bash", "rect_sweep", "ground_pound" },
    phaseConfig = {
        { threshold = 0.6, speedMult = 1.3, intervalMult = 0.7,
          announce = "天罡剑阵...起！",
          triggerSkill = "luqingyun_sword_array",
          addSkill = "luqingyun_prison" },
        { threshold = 0.3, atkMult = 2.0, speedMult = 1.5, intervalMult = 0.4,
          announce = "正气长存，邪不胜正！",
          triggerSkill = "luqingyun_sword_array" },
    },
    dropTable = {},
    isChallenge = true,
    barrierZone = { interval = 20, maxCount = 5, damagePercent = 0.30, radius = 0.8 },
    berserkBuff = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
}

end
