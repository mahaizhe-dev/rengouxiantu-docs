-- ============================================================================
-- MonsterTypes_xianjie.lua - 中洲城·仙劫战场
-- ============================================================================
-- 域外邪魔（Lv.100 大乘初期）：王级BOSS单位，自带魔化BUFF
-- 掉落：T9装备（灵器套装概率）、龙髓/妖兽精华/金条、修炼果/九转金丹/灵韵果、天帝剑痕碎片
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)

-- =====================================================================
-- 仙劫战场 种族修正
-- =====================================================================
M.RaceModifiers.outer_demon = { hp = 1.2, atk = 1.1, def = 1.0, speed = 0.9 }  -- 域外邪魔：高血高攻，速度略慢

-- =====================================================================
-- 仙劫套装ID列表（数据驱动：掉落表引用，不硬编码具体套装）
-- =====================================================================
local XIANJIE_SET_IDS = { "xuesha", "qingyun", "fengmo", "haoqi" }

-- =====================================================================
-- 域外邪魔 BOSS
-- =====================================================================
M.Types.outer_demon_boss = {
    name = "域外邪魔",
    icon = "👹",
    portrait = "Textures/monster_outer_demon.png",
    zone = "xianjie_battlefield",
    category = "king_boss",
    race = "outer_demon",
    level = 100,
    realm = "dacheng_1",
    bodyColor = { 80, 20, 80, 255 },
    clawColor = { 150, 50, 150 },
    skillTextColor = { 180, 80, 220, 255 },
    warningColorOverride = { 100, 30, 100, 120 },
    spawnCount = 5,
    demonBuff = true,           -- 自带魔化BUFF（视觉+属性强化，不影响掉落）
    phases = 2,
    skills = { "void_cross_slash", "evil_impact", "doom_wave" },
    phaseConfig = {
        { threshold = 0.5, atkMult = 1.5, speedMult = 1.3,
          announce = "域外邪魔暴怒，邪气冲天！" },
    },
    tierOnly = 9,
    dropTable = {
        -- T9装备（蓝~青品质）100%掉落
        { chance = 1.0, type = "equipment", minQuality = "blue", maxQuality = "cyan" },
        -- 套装灵器（0.4%独立掉落，从4套中随机1套）
        { chance = 0.004, type = "set_equipment", setIds = XIANJIE_SET_IDS },
        -- 灵韵（15~25）100%掉落
        { chance = 1.0, type = "lingYun", amount = { 12, 18 } },
        -- 100% 掉落池：龙髓/妖兽精华/金条 三选一
        { chance = 1.0, type = "world_drop", pool = "xianjie_material" },
        -- 5% 掉落池：九转金丹/修炼果/灵韵果 三选一
        { chance = 0.05, type = "world_drop", pool = "xianjie_rare" },
        -- 0.1% 掉落池：天帝剑痕碎片 三选一
        { chance = 0.001, type = "world_drop", pool = "xianjie_fragments" },
        -- 金砖0.25%
        { chance = 0.0025, type = "consumable", consumableId = "gold_brick" },
    },
}

end
