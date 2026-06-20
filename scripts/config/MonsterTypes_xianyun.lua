-- ============================================================================
-- MonsterTypes_xianyun.lua - 中洲城·仙殒战场
-- ============================================================================
-- 域外天魔（Lv.120 谪仙境）：皇级BOSS单位，自带魔化BUFF
-- 掉落：T10装备（灵器套装概率）、龙髓/修炼果/灵韵果、渡劫丹/上品修炼果/金砖/上品灵韵果/仙人精血、天帝剑痕碎片
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)

-- =====================================================================
-- 仙殒战场 种族修正
-- =====================================================================
M.RaceModifiers.outer_celestial = { hp = 1.0, atk = 1.0, def = 1.0, speed = 1.0 }  -- 域外天魔：无种族修正，靠 demonBuff 体现魔化

-- =====================================================================
-- 仙殒战场·域外天魔技能
-- =====================================================================

-- 虚空三连斩：十字形剑气连续3次释放，间隔0.3s，追踪玩家
M.Skills.void_triple_slash = {
    id = "void_triple_slash",
    name = "虚空三连斩",
    cooldown = 10,
    damageMult = 3.5,
    castTime = 1.2,
    warningShape = "cross",
    warningRange = 5.0,
    warningCrossWidth = 1.5,
    warningColor = {120, 40, 200, 140},     -- 深紫
    burstCount = 3,                         -- 连续3次释放
    burstInterval = 0.3,                    -- 间隔0.3s
    burstTrack = true,                      -- 每次重新追踪玩家位置
}

-- 天魔冲击：锥形冲击波强化版，范围扩大50%，附带减速
M.Skills.celestial_impact = {
    id = "celestial_impact",
    name = "天魔冲击",
    cooldown = 7,
    damageMult = 4.5,
    effect = "slow",
    effectDuration = 3.0,
    effectValue = 0.60,         -- 减速60%
    castTime = 1.0,
    warningShape = "cone",
    warningRange = 5.0,         -- 原邪能冲击3.5，扩大至5.0
    warningConeAngle = 70,      -- 扇角扩大
    warningColor = {80, 20, 160, 140},     -- 暗蓝紫
}

-- 末日波动·强化：全场AOE，高伤害（对标域外邪魔doom_wave但伤害更高范围更大）
M.Skills.doom_wave_ex = {
    id = "doom_wave_ex",
    name = "末日波动·强化",
    cooldown = 12,
    damageMult = 5.5,
    castTime = 1.8,
    warningShape = "circle",
    warningRange = 6.0,         -- 原5.0扩大
    warningColor = {200, 30, 80, 150},      -- 深红
    isFieldSkill = true,                    -- 场地技能：百分比伤害+安全格判定
}

-- 天魔连弹（新技能）：连射5发追踪圆形冲击，每发重新瞄准
M.Skills.celestial_barrage = {
    id = "celestial_barrage",
    name = "天魔连弹",
    cooldown = 9,
    damageMult = 2.5,           -- 单发伤害（×5发=12.5总系数）
    castTime = 0.8,
    warningShape = "circle",
    warningRange = 2.0,         -- 每发小范围AOE
    warningColor = {160, 60, 220, 140},     -- 紫色
    burstCount = 5,             -- 连射5发
    burstInterval = 0.2,        -- 间隔0.2s（视觉上形成弹幕效果）
    burstTrack = true,          -- 每发重新追踪玩家位置
}

-- =====================================================================
-- 仙劫套装ID列表（与仙劫战场共用四大套装）
-- =====================================================================
local XIANJIE_SET_IDS = { "xuesha", "qingyun", "fengmo", "haoqi" }

-- =====================================================================
-- 域外天魔 BOSS
-- =====================================================================
M.Types.outer_celestial_boss = {
    name = "域外天魔",
    icon = "👿",
    portrait = "image/edited_monster_outer_celestial_20260619095204.png",
    zone = "xianyun_battlefield",
    category = "emperor_boss",
    race = "outer_celestial",
    level = 120,
    realm = "dujie_1",
    bodyColor = { 40, 20, 120, 255 },
    clawColor = { 100, 60, 220 },
    skillTextColor = { 140, 80, 255, 255 },
    warningColorOverride = { 60, 20, 140, 120 },
    spawnCount = 5,
    demonBuff = true,           -- 自带魔化BUFF（视觉+属性强化）
    phases = 3,
    skills = { "void_triple_slash", "celestial_impact", "doom_wave_ex" },  -- P1基础三技能，P2新增连弹
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.4, speedMult = 1.2,
          announce = "域外天魔怒意凝聚，天地变色！",
          addSkill = "celestial_barrage" },      -- P2 新增连弹技能
        { threshold = 0.25, atkMult = 1.8, speedMult = 1.5,
          announce = "域外天魔释放全部力量，紫焰冲天！",
          triggerSkill = "doom_wave_ex" },        -- P3 立即触发强化末日波动
    },
    tierOnly = 10,
    dropTable = {
        -- ① T10装备（蓝~青品质）100%掉落
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        -- ② 套装灵器（0.4%独立掉落，从4套中随机1套1件，强制T10）
        { chance = 0.004, type = "set_equipment", tier = 10, setIds = XIANJIE_SET_IDS },
        -- ③ 灵韵 20~35 100%掉落
        { chance = 1.0, type = "lingYun", amount = { 20, 35 } },
        -- ④ 100% 普通掉落池：龙髓/修炼果/灵韵果 三选一
        { chance = 1.0, type = "world_drop", pool = "xianyun_material" },
        -- ⑤ 5% 稀有掉落池：渡劫丹/上品修炼果/金砖/上品灵韵果/仙人精血 五选一
        { chance = 0.05, type = "world_drop", pool = "xianyun_rare" },
        -- ⑥ 0.1% 神器池：天帝剑痕碎片·肆/伍/陆 三选一
        { chance = 0.001, type = "world_drop", pool = "xianyun_fragments" },
        -- ⑦ 5% 五行命格（T3 火·移速）— 由 GameEvents→RollMingge 驱动，MinggeData.SOURCES 已注册
    },
}

end
