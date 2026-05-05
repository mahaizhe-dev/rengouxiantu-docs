#!/usr/bin/env python3
"""四章×三职业 DPS 计算器 — 基于 v3 预设方案 (代码验证版 v4)"""
import math

# ==================== 公式 ====================
def calc_damage(atk, defv):
    """CalcDamage = ATK^2 / (ATK + DEF), minimum 1"""
    if atk + defv <= 0:
        return 1
    return max(1, atk * atk / (atk + defv))

# ==================== 公共参数 ====================
# 境界倍率 (statMult): 作用于 HP/ATK/DEF
REALM_MULT = {1: 1.40, 2: 1.80, 3: 2.60, 4: 3.80}
# 攻速加成
REALM_ATKSPD = {1: 0.1, 2: 0.2, 3: 0.4, 4: 0.6}
# 洗髓等级
WASH_LEVEL = {1: 3, 2: 6, 3: 12, 4: 18}

# 怪物 DEF — 对标守关BOSS平均防御 (代码公式: floor(baseDef × catMult × raceMod × realmMult))
# baseDef = 2 + lv*2, catMult(boss=1.3/king=1.5/emperor=1.8), raceMod按种族, realmMult按境界
PLAYER_LV = {1: 16, 2: 36, 3: 65, 4: 100}
# 各章守关BOSS平均DEF (从 MonsterTypes_ch1-4.lua + MonsterData.lua 精确计算):
#   Ch1: 蛛母(16)+猪三哥(37)+大大王(49)+虎王(59) = 161/4 = 40
#   Ch2: 猪大哥(99)+碧鳞(67)+乌地北(124)+乌天南(141)+乌万仇(168)+乌万海(199) = 798/6 = 133
#   Ch3: 枯木(190)+岩蟾(211)+苍狼(257)+赤甲(294)+蛇骨(333)+烈焰狮王(451)+蜃妖王(503)+枯木守卫(471)+沙万里(679) = 3389/9 = 377
#   Ch4: 沈渊衣(535)+岩不动(602)+雷惊蛰(777)+风无痕(903)+炎若晦(996)+厚德生(1029)+泽归墟(1105)+司空正阳(1368)+四龙帝(1937+1639+1341+1490) = 13722/12 = 1144
BOSS_AVG_DEF = {1: 40, 2: 133, 3: 377, 4: 1144}
def monster_def(ch):
    return BOSS_AVG_DEF[ch]

# ==================== 装备主属性 (v3 预设) ====================
EQUIP_MAIN = {
    1: {"atk": 42.9, "def": 27.3, "maxHp": 136.5, "critRate": 0.078,
        "speed": 0.078, "dmgReduce": 0.052, "hpRegen": 3.9},
    2: {"atk": 99.0, "def": 63.0, "maxHp": 315.0, "critRate": 0.135,
        "speed": 0.135, "dmgReduce": 0.078, "hpRegen": 7.8},
    3: {"atk": 173.3, "def": 110.3, "maxHp": 551.3, "critRate": 0.225,
        "speed": 0.225, "dmgReduce": 0.130, "hpRegen": 13.65},
    4: {"atk": 336.6, "def": 214.2, "maxHp": 1071.0, "critRate": 0.378,
        "speed": 0.378, "dmgReduce": 0.210, "hpRegen": 25.5},
}

# 法宝主属性(核心仙缘): xianyuan公式 = floor(tier × qualityMult) × mainStatBase(5)
# 品质上限: T3-T4→purple(×1.3), T5-T8→orange(×1.5), T9+→cyan(×1.8)
# Ch1 T3: floor(3×1.3)×5 = 3×5 = 15
# Ch2 T5: floor(5×1.5)×5 = 7×5 = 35
# Ch3 T7: floor(7×1.5)×5 = 10×5 = 50
# Ch4 T9: floor(9×1.8)×5 = 16×5 = 80
# 注: 旧专属装备(base5×TIER_MULT×quality={0,39,68,128})已从游戏移除
# 每职业默认法宝: 太虚→血海图(悟性), 罗汉→青云塔(根骨), 镇岳→封魔盘(体魄)
EXCLUSIVE_FAIRY = {1: 15, 2: 35, 3: 50, 4: 80}

# ==================== 副属性 (v3 预设分配) ====================
# 副属性单值表 (平均roll ×1.0)
SUB_STAT_TIER = {1: 3, 2: 5, 3: 7, 4: 9}
SUB_CRIT_RATE = {1: 0.016, 2: 0.025, 3: 0.038, 4: 0.060}
SUB_CRIT_DMG  = {1: 0.08,  2: 0.125, 3: 0.19,  4: 0.30}
SUB_FAIRY     = {1: 3, 2: 7, 3: 10, 4: 16}  # 常规件
SUB_ATK       = {1: 3.3, 2: 6.0, 3: 10.5, 4: 16.5}
SUB_HEAVY     = {1: 17.6, 2: 32.0, 3: 56.0, 4: 88.0}
SUB_MAXHP     = {1: 13.2, 2: 24.0, 3: 42.0, 4: 66.0}
SUB_HPREGEN   = {1: 1.1, 2: 2.0, 3: 3.5, 4: 5.5}  # base=0.5 × SUB_TIER_MULT

# 行数分配
def sub_lines(ch):
    """返回 (critRate行, critDmg行, fairy行, tendency行, flex行)"""
    if ch == 1:
        return (10, 11, 11, 8, 4)
    elif ch == 4:
        return (10, 12, 11, 10, 5)  # Ch4 critRate溢出省1行
    else:
        return (11, 12, 11, 9, 5)

# 灵性属性 (T9/灵器 only): 12条全投critDmg, 15%/条
SPIRIT_CRIT_DMG = {1: 0, 2: 0, 3: 0, 4: 0.15 * 12}  # 1.80

# ==================== 套装加成 ====================
# 8pc主套 + 3pc副套
SET_BONUS = {
    "taixu": {"main_fairy": 25, "sub_fairy_type": "constitution", "sub_fairy": 25,
              "combo_rate": 0.02},  # 5pc: 连击+2%
    "luohan": {"main_fairy": 25, "sub_fairy_type": "wisdom", "sub_fairy": 25,
               "heavy_rate": 0.04},  # 5pc: 重击+4%
    "zhenyue": {"main_fairy": 25, "sub_fairy_type": "wisdom", "sub_fairy": 25,
                "bloodrage_rate": 0.04},  # 5pc: 血怒+4%
}

# ==================== 神器 ====================
ARTIFACTS = {
    1: {},
    2: {},
    3: {"heavyHit": 300, "constitution": 100, "physique": 100},  # 上宝逊金钯
    4: {"heavyHit": 300, "constitution": 100, "physique": 100,
        "wisdom": 100, "fortune": 100, "def": 64},  # 上宝+文王
}

# ==================== 仙缘转换 ====================
def wisdom_effects(pts):
    """悟性: +1%技能伤害/5pt, +1%连击/50pt"""
    skill_dmg = math.floor(pts / 5) * 0.01
    combo = math.floor(pts / 50) * 0.01
    return skill_dmg, combo

def constitution_effects(pts):
    """根骨: +1%DEF/5pt, +1%重击伤害/25pt, +1%重击概率/25pt"""
    def_bonus = math.floor(pts / 5) * 0.01
    heavy_dmg = math.floor(pts / 25) * 0.01
    heavy_rate = math.floor(pts / 25) * 0.01
    return def_bonus, heavy_dmg, heavy_rate

def physique_effects(pts):
    """体魄: +0.3HP回复/pt, +1%HP上限/5pt, +1%血怒概率/25pt"""
    hp_regen = pts * 0.3
    hp_bonus = math.floor(pts / 5) * 0.01
    bloodrage_rate = math.floor(pts / 25) * 0.01
    return hp_regen, hp_bonus, bloodrage_rate

# ==================== 职业计算 ====================

def calc_base_stats(ch):
    """计算基础属性(境界后) + 装备主属性"""
    lv = PLAYER_LV[ch]
    rm = REALM_MULT[ch]
    
    base_hp = (100 + 15 * lv) * rm
    base_atk = (15 + 3 * lv) * rm
    base_def = (5 + 2 * lv) * rm
    base_regen = 1.0 + 0.2 * lv  # hpRegen不受境界倍率
    
    eq = EQUIP_MAIN[ch]
    return {
        "hp": base_hp + eq["maxHp"],
        "atk": base_atk + eq["atk"],
        "def": base_def + eq["def"],
        "hpRegen": base_regen + eq["hpRegen"],
        "critRate_base": 0.05 + eq["critRate"],
        "dmgReduce": eq["dmgReduce"],
        "atkSpeed": 1.0 + REALM_ATKSPD[ch],
    }

def calc_taixu(ch):
    """太虚 DPS 计算"""
    lv = PLAYER_LV[ch]
    base = calc_base_stats(ch)
    lines = sub_lines(ch)
    m_def = monster_def(ch)
    arts = ARTIFACTS[ch]
    wash = WASH_LEVEL[ch]
    
    # 副属性
    crit_rate_sub = lines[0] * SUB_CRIT_RATE[ch]
    crit_dmg_sub = lines[1] * SUB_CRIT_DMG[ch]
    atk_sub = lines[3] * SUB_ATK[ch]  # 太虚倾向=ATK
    
    # 暴击
    total_crit_rate = min(1.0, base["critRate_base"] + crit_rate_sub)
    total_crit_dmg = 1.50 + crit_dmg_sub + SPIRIT_CRIT_DMG[ch]
    crit_mult = total_crit_rate * total_crit_dmg + (1 - total_crit_rate) * 1.0
    
    # 仙缘
    # 悟性来源: lv(太虚+1/lv) + sub + exclusive + 8pc血煞 + 神器
    wisdom_total = lv + lines[2] * SUB_FAIRY[ch] + EXCLUSIVE_FAIRY[ch] + 25 + arts.get("wisdom", 0)
    skill_dmg_pct, combo_pct = wisdom_effects(wisdom_total)
    
    # 根骨来源: 3pc青云 + 神器
    con_total = 25 + arts.get("constitution", 0)
    con_def, con_heavy_dmg, con_heavy_rate = constitution_effects(con_total)
    
    # 体魄来源: 神器
    phy_total = arts.get("physique", 0)
    phy_regen, phy_hp, phy_bloodrage = physique_effects(phy_total)
    
    # 天赋: 连击+8%, 5pc血煞+2%
    total_combo = 0.08 + 0.02 + combo_pct
    
    # 面板
    total_atk = base["atk"] + atk_sub
    total_def = (base["def"] + arts.get("def", 0)) * (1 + con_def)
    total_hp = base["hp"] * (1 + phy_hp)
    total_regen = base["hpRegen"] + phy_regen
    atk_speed = base["atkSpeed"]
    
    # === DPS 分项 ===
    # 1) 普攻: CalcDmg(totalATK, monDEF) × critMult × atkSpeed
    normal_raw = calc_damage(total_atk, m_def)
    normal_dps = normal_raw * crit_mult * atk_speed
    
    # 2) 破剑式: 150%ATK → CalcDmg, CD 5s, 吃skillDmg% [代码: damageMultiplier=1.5, cooldown=5.0]
    sword_raw = total_atk * 1.50 * (1 + skill_dmg_pct)
    sword_dmg = calc_damage(sword_raw, m_def) * crit_mult
    sword_dps = sword_dmg / 5.0
    
    # 3) 奔雷式砸击: 150%ATK → CalcDmg, CD 5s, 吃skillDmg% [代码: damageMultiplier=1.5, cooldown=5.0]
    thunder_raw = total_atk * 1.50 * (1 + skill_dmg_pct)
    thunder_dmg = calc_damage(thunder_raw, m_def) * crit_mult
    thunder_dps = thunder_dmg / 5.0
    
    # 4) 奔雷式DOT (插剑电击): 10%effectiveATK/s 真伤, 持续5s, 每秒tick, CD5s
    #    [代码: rawDotDmg = effectiveAtk * 0.10, trueDamage=true, dotDuration=5.0, tickInterval=1.0]
    #    每个CD周期产生5tick伤害, CD=5s → 平均DPS = 5tick×rawDotDmg×critMult / 5s
    effective_atk_for_dot = total_atk * (1 + skill_dmg_pct)
    dot_per_tick = effective_atk_for_dot * 0.10
    dot_total_per_cycle = dot_per_tick * 5 * crit_mult  # 5tick × 每tick独立暴击
    dot_dps = dot_total_per_cycle / 5.0  # 真伤无视DEF, CD5s=持续5s(无间断)
    
    # 5) 一剑开天 (被动巨剑): 300%effectiveATK → CalcDmg, 每8次主动技能触发
    #    [代码: effectiveAtk = ATK×(1+skillDmg%), CalcDamage(effectiveAtk×3.0, def)]
    # 技能频率: 破剑式1/5s + 奔雷式1/5s = 0.4次/s, 含连击
    skill_freq = 0.4 * (1 + total_combo)  # 连击增加触发次数
    trigger_interval = 8 / skill_freq
    giant_raw = effective_atk_for_dot * 3.0  # 吃skillDmg%
    giant_dps_raw = calc_damage(giant_raw, m_def) * crit_mult
    giant_dps = giant_dps_raw / trigger_interval
    
    # 6) 连击加成: 奔雷式砸击+DOT 有连击概率 (破剑式也有连击,此处简化为奔雷连击)
    combo_dps = (thunder_dps + dot_dps) * total_combo
    
    # 重击 (from 根骨) [代码: heavyDmg = (ATK+HH)×(1+conHeavyDmg), 真伤→TakeDamage]
    heavy_rate = con_heavy_rate
    heavy_hit_val = 0  # 太虚无重击值堆叠
    heavy_dmg_raw = (total_atk + heavy_hit_val) * (1 + con_heavy_dmg)
    heavy_dps = heavy_dmg_raw * crit_mult * heavy_rate * atk_speed  # 真伤无视DEF
    
    total_dps = normal_dps + sword_dps + thunder_dps + dot_dps + giant_dps + combo_dps + heavy_dps
    
    # 洗髓增伤
    total_dps_wash = total_dps * (1 + wash * 0.01)
    
    return {
        "class": "太虚",
        "ch": ch,
        "total_atk": total_atk,
        "total_def": total_def,
        "total_hp": total_hp,
        "total_regen": total_regen,
        "crit_rate": total_crit_rate,
        "crit_dmg": total_crit_dmg,
        "crit_mult": crit_mult,
        "wisdom": wisdom_total,
        "skill_dmg_pct": skill_dmg_pct,
        "combo_pct": total_combo,
        "dps_normal": normal_dps,
        "dps_skill": sword_dps + thunder_dps,
        "dps_dot": dot_dps,
        "dps_giant": giant_dps,
        "dps_combo": combo_dps,
        "dps_heavy": heavy_dps,
        "dps_total_raw": total_dps,
        "dps_total_wash": total_dps_wash,
        "wash": wash,
        "mon_def": m_def,
    }

def calc_luohan(ch):
    """罗汉 DPS 计算"""
    lv = PLAYER_LV[ch]
    base = calc_base_stats(ch)
    lines = sub_lines(ch)
    m_def = monster_def(ch)
    arts = ARTIFACTS[ch]
    wash = WASH_LEVEL[ch]
    
    crit_rate_sub = lines[0] * SUB_CRIT_RATE[ch]
    crit_dmg_sub = lines[1] * SUB_CRIT_DMG[ch]
    heavy_sub = lines[3] * SUB_HEAVY[ch]  # 罗汉倾向=HeavyHit
    
    total_crit_rate = min(1.0, base["critRate_base"] + crit_rate_sub)
    total_crit_dmg = 1.50 + crit_dmg_sub + SPIRIT_CRIT_DMG[ch]
    crit_mult = total_crit_rate * total_crit_dmg + (1 - total_crit_rate) * 1.0
    
    # 根骨: lv(罗汉+1/lv) + sub + exclusive + 8pc青云 + 神器
    con_total = lv + lines[2] * SUB_FAIRY[ch] + EXCLUSIVE_FAIRY[ch] + 25 + arts.get("constitution", 0)
    con_def, con_heavy_dmg, con_heavy_rate = constitution_effects(con_total)
    
    # 悟性: 3pc血煞 + 神器
    wis_total = 25 + arts.get("wisdom", 0)
    skill_dmg_pct, combo_pct_wis = wisdom_effects(wis_total)
    
    # 体魄: 神器
    phy_total = arts.get("physique", 0)
    phy_regen, phy_hp, phy_bloodrage = physique_effects(phy_total)
    
    # 天赋: 重击+10%, 5pc青云+4%
    total_heavy_rate = 0.10 + 0.04 + con_heavy_rate
    
    total_atk = base["atk"]  # 罗汉无ATK副属性
    total_def = (base["def"] + arts.get("def", 0)) * (1 + con_def)
    total_hp = base["hp"] * (1 + phy_hp)
    total_regen = base["hpRegen"] + phy_regen
    total_heavy_hit = heavy_sub + arts.get("heavyHit", 0)
    atk_speed = base["atkSpeed"]
    
    # === DPS 分项 ===
    # 1) 普攻
    normal_raw = calc_damage(total_atk, m_def)
    normal_dps = normal_raw * crit_mult * atk_speed
    
    # 2) 重击: (ATK + HeavyHit) × (1+conHeavyDmg%), 真伤无视DEF, 每次普攻判定
    heavy_dmg_per = (total_atk + total_heavy_hit) * (1 + con_heavy_dmg) * crit_mult
    heavy_dps = heavy_dmg_per * total_heavy_rate * atk_speed
    
    # 3) 金刚掌: 150%ATK → CalcDmg, CD 5s, 吃skillDmg%
    vajra_raw = total_atk * 1.50 * (1 + skill_dmg_pct)
    vajra_dmg = calc_damage(vajra_raw, m_def) * crit_mult
    vajra_dps = vajra_dmg / 5.0
    
    # 4) 伏魔刀: 100%ATK → CalcDmg, CD 8s, 吃skillDmg%, 吸血(不计入DPS)
    fumo_raw = total_atk * 1.00 * (1 + skill_dmg_pct)
    fumo_dmg = calc_damage(fumo_raw, m_def) * crit_mult
    fumo_dps = fumo_dmg / 8.0
    
    # 5) 龙象功: 普攻叠18层 → AoE真伤, (ATK+HeavyHit)×(1+conHeavyDmg%), 无额外倍率
    #    [代码: heavyDmg = floor(ATK+HH), ×(1+conHeavyDmg), ApplyCrit, 真伤TakeDamage]
    # 叠层速度: atkSpeed次/秒(普攻+1,重击+2), 加权平均叠层/s = atkSpeed×(1×(1-heavyRate) + 2×heavyRate)
    effective_stacks_per_sec = atk_speed * (1 * (1 - total_heavy_rate) + 2 * total_heavy_rate)
    stack_time = 18 / effective_stacks_per_sec
    dragon_dmg = (total_atk + total_heavy_hit) * (1 + con_heavy_dmg) * crit_mult  # 无×1.50!
    dragon_dps = dragon_dmg / stack_time
    
    total_dps = normal_dps + heavy_dps + vajra_dps + fumo_dps + dragon_dps
    total_dps_wash = total_dps * (1 + wash * 0.01)
    
    return {
        "class": "罗汉",
        "ch": ch,
        "total_atk": total_atk,
        "total_def": total_def,
        "total_hp": total_hp,
        "total_regen": total_regen,
        "crit_rate": total_crit_rate,
        "crit_dmg": total_crit_dmg,
        "crit_mult": crit_mult,
        "constitution": con_total,
        "heavy_hit": total_heavy_hit,
        "heavy_rate": total_heavy_rate,
        "dps_normal": normal_dps,
        "dps_heavy": heavy_dps,
        "dps_vajra": vajra_dps,
        "dps_fumo": fumo_dps,
        "dps_dragon": dragon_dps,
        "dps_total_raw": total_dps,
        "dps_total_wash": total_dps_wash,
        "wash": wash,
        "mon_def": m_def,
    }

def calc_zhenyue(ch):
    """镇岳 DPS 计算 — 焚血伤害 = 总hpRegen (基础+装备+体魄+焚血增量)"""
    lv = PLAYER_LV[ch]
    base = calc_base_stats(ch)
    lines = sub_lines(ch)
    m_def = monster_def(ch)
    arts = ARTIFACTS[ch]
    wash = WASH_LEVEL[ch]
    
    crit_rate_sub = lines[0] * SUB_CRIT_RATE[ch]
    crit_dmg_sub = lines[1] * SUB_CRIT_DMG[ch]
    maxhp_sub = lines[3] * SUB_MAXHP[ch]  # 镇岳倾向=maxHP
    
    total_crit_rate = min(1.0, base["critRate_base"] + crit_rate_sub)
    total_crit_dmg = 1.50 + crit_dmg_sub + SPIRIT_CRIT_DMG[ch]
    crit_mult = total_crit_rate * total_crit_dmg + (1 - total_crit_rate) * 1.0
    
    # 体魄: lv(镇岳+1/lv) + sub + exclusive + 8pc封魔 + 神器
    phy_total = lv + lines[2] * SUB_FAIRY[ch] + EXCLUSIVE_FAIRY[ch] + 25 + arts.get("physique", 0)
    phy_regen, phy_hp, phy_bloodrage = physique_effects(phy_total)
    
    # 悟性: 3pc血煞 + 神器
    wis_total = 25 + arts.get("wisdom", 0)
    skill_dmg_pct, combo_pct_wis = wisdom_effects(wis_total)
    
    # 根骨: 神器
    con_total = arts.get("constitution", 0)
    con_def, con_heavy_dmg, con_heavy_rate = constitution_effects(con_total)
    
    # 天赋: 血怒+10%, 5pc封魔+4%
    total_bloodrage_rate = 0.10 + 0.04 + phy_bloodrage
    bloodrage_value = math.floor(phy_total / 25) * 0.01  # 每25pt +1%
    
    total_atk = base["atk"]  # 镇岳无ATK副属性
    total_def_raw = base["def"] + arts.get("def", 0)
    total_def = total_def_raw * (1 + con_def)
    total_hp = (base["hp"] + maxhp_sub) * (1 + phy_hp)
    
    # ★★★ 关键: 总hpRegen (基础+装备+体魄加成) ★★★
    total_regen_before_fenxue = base["hpRegen"] + phy_regen
    
    # 焚血增量 = 2% × maxHP (每秒)
    fenxue_regen_add = total_hp * 0.02
    
    # 总hpRegen (含焚血增量) = 焚血真伤/秒
    total_regen_with_fenxue = total_regen_before_fenxue + fenxue_regen_add
    
    atk_speed = base["atkSpeed"]
    
    # === DPS 分项 ===
    # 1) 普攻
    normal_raw = calc_damage(total_atk, m_def)
    normal_dps = normal_raw * crit_mult * atk_speed
    
    # 2) 裂山: maxHP×10%×(1+skillDmg%) → CalcDmg, CD 3s, 消耗5%maxHP
    #    [代码: hpCoefficient=0.10, hpCost=0.05, cooldown=3.0, skillDmgApplies=true]
    lishan_raw = total_hp * 0.10 * (1 + skill_dmg_pct)
    lishan_dmg = calc_damage(lishan_raw, m_def) * crit_mult
    lishan_dps = lishan_dmg / 3.0
    lishan_hp_cost = total_hp * 0.05 / 3.0  # HP消耗/秒
    
    # 3) 地涌: maxHP×30%×(1+skillDmg%) → CalcDmg, CD 15s
    #    [代码: hpCoefficient=0.30, healPercent=0.30, cooldown=15.0, skillDmgApplies=true]
    dimai_raw = total_hp * 0.30 * (1 + skill_dmg_pct)
    dimai_dmg = calc_damage(dimai_raw, m_def) * crit_mult
    dimai_dps = dimai_dmg / 15.0
    
    # 4) 焚血之躯 (真实伤害, 无视DEF, 可暴击, 不吃skillDmg%)
    # ★ 焚血伤害/秒 = 总hpRegen(含焚血增量) = 基础regen + 体魄regen + 焚血2%maxHP
    fenxue_dps = total_regen_with_fenxue * crit_mult  # 真伤，走ApplyCrit
    fenxue_hp_cost = total_regen_with_fenxue  # HP消耗/秒 = 回复量(净变化0)
    
    # 5) 血爆: 累计消耗≥maxHP触发, maxHP×100%×(1+bloodRageValue), 真伤可暴击
    total_hp_drain = lishan_hp_cost + fenxue_hp_cost  # 总HP消耗/秒
    bloodburst_cycle = total_hp / total_hp_drain if total_hp_drain > 0 else 999
    bloodburst_dmg = total_hp * 1.0 * (1 + bloodrage_value) * crit_mult
    bloodburst_dps = bloodburst_dmg / bloodburst_cycle if bloodburst_cycle > 0 else 0
    
    total_dps = normal_dps + lishan_dps + dimai_dps + fenxue_dps + bloodburst_dps
    total_dps_wash = total_dps * (1 + wash * 0.01)
    
    return {
        "class": "镇岳",
        "ch": ch,
        "total_atk": total_atk,
        "total_def": total_def,
        "total_hp": total_hp,
        "total_regen_before_fenxue": total_regen_before_fenxue,
        "total_regen_with_fenxue": total_regen_with_fenxue,
        "crit_rate": total_crit_rate,
        "crit_dmg": total_crit_dmg,
        "crit_mult": crit_mult,
        "physique": phy_total,
        "hp_pct": phy_hp,
        "bloodrage_rate": total_bloodrage_rate,
        "bloodrage_value": bloodrage_value,
        "skill_dmg_pct": skill_dmg_pct,
        "dps_normal": normal_dps,
        "dps_lishan": lishan_dps,
        "dps_dimai": dimai_dps,
        "dps_fenxue": fenxue_dps,
        "dps_bloodburst": bloodburst_dps,
        "dps_total_raw": total_dps,
        "dps_total_wash": total_dps_wash,
        "wash": wash,
        "mon_def": m_def,
        "fenxue_regen_add": fenxue_regen_add,
        "bloodburst_cycle": bloodburst_cycle,
    }

# ==================== 输出 ====================
def fmt(v, decimal=1):
    return f"{v:.{decimal}f}"

def pct(v, decimal=1):
    return f"{v*100:.{decimal}f}%"

print("=" * 100)
print("四章×三职业 DPS 分析 — 基于 v3 预设方案")
print("=" * 100)

for ch in [1, 2, 3, 4]:
    print(f"\n{'='*100}")
    print(f"第{ch}章毕业 | Lv.{PLAYER_LV[ch]} | 境界×{REALM_MULT[ch]} | wash+{WASH_LEVEL[ch]}% | 怪DEF={monster_def(ch)}")
    print(f"{'='*100}")
    
    tx = calc_taixu(ch)
    lh = calc_luohan(ch)
    zy = calc_zhenyue(ch)
    
    # 面板对比
    print(f"\n--- 面板属性 ---")
    print(f"{'':12s} {'太虚':>12s} {'罗汉':>12s} {'镇岳':>12s}")
    print(f"{'ATK':12s} {fmt(tx['total_atk']):>12s} {fmt(lh['total_atk']):>12s} {fmt(zy['total_atk']):>12s}")
    print(f"{'DEF':12s} {fmt(tx['total_def']):>12s} {fmt(lh['total_def']):>12s} {fmt(zy['total_def']):>12s}")
    print(f"{'HP':12s} {fmt(tx['total_hp']):>12s} {fmt(lh['total_hp']):>12s} {fmt(zy['total_hp']):>12s}")
    print(f"{'HPRegen':12s} {fmt(tx['total_regen']):>12s} {fmt(lh['total_regen']):>12s} {fmt(zy['total_regen_before_fenxue']):>12s}(+焚血{fmt(zy['fenxue_regen_add'])})")
    print(f"{'CritRate':12s} {pct(tx['crit_rate']):>12s} {pct(lh['crit_rate']):>12s} {pct(zy['crit_rate']):>12s}")
    print(f"{'CritDmg':12s} {pct(tx['crit_dmg']):>12s} {pct(lh['crit_dmg']):>12s} {pct(zy['crit_dmg']):>12s}")
    print(f"{'CritMult':12s} {fmt(tx['crit_mult'],2):>12s} {fmt(lh['crit_mult'],2):>12s} {fmt(zy['crit_mult'],2):>12s}")
    
    # 仙缘
    print(f"\n--- 仙缘属性 ---")
    print(f"太虚: 悟性={tx['wisdom']}, 技能伤害+{pct(tx['skill_dmg_pct'])}, 连击{pct(tx['combo_pct'])}")
    print(f"罗汉: 根骨={lh['constitution']}, DEF+{pct(constitution_effects(lh['constitution'])[0])}, 重击概率{pct(lh['heavy_rate'])}, 重击值={fmt(lh['heavy_hit'])}")
    print(f"镇岳: 体魄={zy['physique']}, HP+{pct(zy['hp_pct'])}, 血怒概率{pct(zy['bloodrage_rate'])}, 技能伤害+{pct(zy['skill_dmg_pct'])}")
    
    # DPS 分项
    print(f"\n--- DPS 分项 ---")
    print(f"{'':16s} {'太虚':>10s} {'罗汉':>10s} {'镇岳':>10s}")
    print(f"{'普攻':16s} {fmt(tx['dps_normal']):>10s} {fmt(lh['dps_normal']):>10s} {fmt(zy['dps_normal']):>10s}")
    
    # 太虚技能
    print(f"{'技能(CalcDmg)':16s} {fmt(tx['dps_skill']):>10s} {fmt(lh['dps_vajra']+lh['dps_fumo']):>10s} {fmt(zy['dps_lishan']+zy['dps_dimai']):>10s}")
    print(f"  {'破剑式':14s} {fmt(tx['dps_skill']/2):>10s} {'—':>10s} {'—':>10s}")
    print(f"  {'奔雷式砸击':14s} {fmt(tx['dps_skill']/2):>10s} {'—':>10s} {'—':>10s}")
    print(f"  {'金刚掌':14s} {'—':>10s} {fmt(lh['dps_vajra']):>10s} {'—':>10s}")
    print(f"  {'伏魔刀':14s} {'—':>10s} {fmt(lh['dps_fumo']):>10s} {'—':>10s}")
    print(f"  {'裂山':14s} {'—':>10s} {'—':>10s} {fmt(zy['dps_lishan']):>10s}")
    print(f"  {'地涌':14s} {'—':>10s} {'—':>10s} {fmt(zy['dps_dimai']):>10s}")
    
    # 真伤/被动
    print(f"{'真伤(无视DEF)':16s} {fmt(tx['dps_dot']):>10s} {'—':>10s} {fmt(zy['dps_fenxue']):>10s}")
    print(f"  {'DOT/焚血':14s} {fmt(tx['dps_dot']):>10s} {'—':>10s} {fmt(zy['dps_fenxue']):>10s}")
    
    # 重击/龙象
    print(f"{'重击+龙象(真伤)':16s} {fmt(tx['dps_heavy']):>10s} {fmt(lh['dps_heavy']+lh['dps_dragon']):>10s} {'—':>10s}")
    print(f"  {'重击':14s} {fmt(tx['dps_heavy']):>10s} {fmt(lh['dps_heavy']):>10s} {'—':>10s}")
    print(f"  {'龙象功':14s} {'—':>10s} {fmt(lh['dps_dragon']):>10s} {'—':>10s}")
    
    # 被动/爆发
    print(f"{'被动爆发':16s} {fmt(tx['dps_giant']):>10s} {'—':>10s} {fmt(zy['dps_bloodburst']):>10s}")
    print(f"  {'一剑开天':14s} {fmt(tx['dps_giant']):>10s} {'—':>10s} {'—':>10s}")
    print(f"  {'血爆':14s} {'—':>10s} {'—':>10s} {fmt(zy['dps_bloodburst']):>10s}(周期{fmt(zy['bloodburst_cycle'])}s)")
    
    # 连击
    print(f"{'连击':16s} {fmt(tx['dps_combo']):>10s} {'—':>10s} {'—':>10s}")
    
    # 总计
    print(f"{'─'*16} {'─'*10} {'─'*10} {'─'*10}")
    print(f"{'总DPS(raw)':16s} {fmt(tx['dps_total_raw']):>10s} {fmt(lh['dps_total_raw']):>10s} {fmt(zy['dps_total_raw']):>10s}")
    print(f"{'总DPS(+wash)':16s} {fmt(tx['dps_total_wash']):>10s} {fmt(lh['dps_total_wash']):>10s} {fmt(zy['dps_total_wash']):>10s}")
    
    # 占比
    max_dps = max(tx['dps_total_wash'], lh['dps_total_wash'], zy['dps_total_wash'])
    print(f"\n--- DPS 排名 ---")
    results = [
        ("太虚", tx['dps_total_wash']),
        ("罗汉", lh['dps_total_wash']),
        ("镇岳", zy['dps_total_wash']),
    ]
    results.sort(key=lambda x: -x[1])
    for i, (name, dps) in enumerate(results):
        pct_of_max = dps / results[0][1] * 100
        print(f"  #{i+1} {name}: {fmt(dps)}/s ({pct_of_max:.1f}%)")
    
    # 镇岳焚血详情
    zy_base_regen = 1.0 + 0.2 * PLAYER_LV[ch] + EQUIP_MAIN[ch]["hpRegen"]
    zy_phy_regen = zy['physique'] * 0.3
    print(f"\n--- 镇岳焚血详情 ---")
    print(f"  基础hpRegen(等级+装备): {fmt(zy_base_regen)} (等级{fmt(1.0+0.2*PLAYER_LV[ch])} + 装备{fmt(EQUIP_MAIN[ch]['hpRegen'])})")
    print(f"  体魄hpRegen({zy['physique']}pt×0.3): +{fmt(zy_phy_regen)}")
    print(f"  焚血前总regen: {fmt(zy['total_regen_before_fenxue'])}/s")
    print(f"  焚血增量(2%×{fmt(zy['total_hp'])}HP): +{fmt(zy['fenxue_regen_add'])}/s")
    print(f"  总hpRegen(=焚血真伤基数): {fmt(zy['total_regen_with_fenxue'])}/s")
    print(f"  焚血DPS(×{fmt(zy['crit_mult'],2)}暴击): {fmt(zy['dps_fenxue'])}/s")
    print(f"  血爆周期: {fmt(zy['bloodburst_cycle'])}s (HP消耗: 裂山{fmt(zy['total_hp']*0.05/3)}/s + 焚血{fmt(zy['total_regen_with_fenxue'])}/s)")

print(f"\n\n{'='*100}")
print("计算说明 (代码验证版 v5):")
print("1. 焚血伤害 = 总hpRegen/秒(基础+装备+体魄+焚血2%maxHP) × 暴击期望 — 真实伤害无视DEF, 不吃skillDmg%, ★吃暴击(canCrit=true, 其他持续性真伤不吃)")
print("2. 血爆伤害 = maxHP × 100% × (1+bloodRageValue) × 暴击期望; 周期 = maxHP ÷ (裂山消耗/s + 焚血消耗/s)")
print("3. 龙象功叠层 = 18层 ÷ 加权攻速(普攻+1,重击+2), 伤害=(ATK+HH)×(1+重击伤害%) — 无额外倍率, 真伤")
print("4. 一剑开天触发 = 每8次技能(含连击), 伤害=300%×ATK×(1+skillDmg%) → CalcDmg")
print("5. 破剑式/奔雷式: 150%ATK×(1+skillDmg%) → CalcDmg, CD=5s; 奔雷DOT: 10%effectiveATK/tick, 5tick/5s, 真伤")
print("6. 裂山: 10%maxHP×(1+skillDmg%) → CalcDmg, CD=3s; 地涌: 30%maxHP×(1+skillDmg%) → CalcDmg, CD=15s")
print("7. 所有CalcDmg走防御公式: ATK²/(ATK+DEF); 真伤直接TakeDamage")
print("8. 洗髓增伤为独立乘区: 最终DPS × (1 + washLevel%)")
