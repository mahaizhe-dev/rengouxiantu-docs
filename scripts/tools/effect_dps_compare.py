#!/usr/bin/env python3
"""特效DPS对比分析 v2 — 按装备槽位分三组对比
A组: 5法宝(同部位互斥) — 主属性 + 技能DPS + 图鉴加成 = 总槽位价值
B组: 5龙极武器特效 + 1钉耙神器(武器/神器特效对比)
C组: 4套装8件被动(同部位互斥)

代码源:
  EquipmentData.lua     — 法宝模板/图鉴/套装8pc定义
  SkillData.lua         — 法宝技能参数
  SkillSystem.lua       — CastAoeDotSkill / CastMultiZoneHeavySkill / CastDamageAmpZoneSkill / CastXianyuanConeAoeSkill / CastBuffSkill
  CombatSystem.lua      — 武器特效: wind_slash / lifesteal_burst / shadow_strike / heavy_strike
  BossMechanics.lua     — sacrifice_aura
  ArtifactSystem.lua    — 天蓬遗威
  SetAoeSystem.lua      — 套装8pc aoeEffect (attr×3 → CalcDmg, 不暴击, CD30s)
  Player.lua            — 仙缘→派生公式
  Monster.lua:609-613   — damageBoostPercent 增伤区域乘算
  BuffZoneSystem.lua:308-309 — DOT tick = 直接TakeDamage(真伤)
"""
import math

# ==================== 公式 ====================
def calc_damage(atk, defv):
    if atk + defv <= 0:
        return 1
    return max(1, math.floor(atk * atk / (atk + defv)))

# ==================== 公共参数 ====================
REALM_MULT    = {3: 2.60, 4: 3.80}
REALM_ATKSPD  = {3: 0.4, 4: 0.6}
PLAYER_LV     = {3: 65, 4: 100}
BOSS_AVG_DEF  = {3: 377, 4: 1144}

EQUIP_MAIN = {
    3: {"atk": 173.3, "def": 110.3, "maxHp": 551.3, "critRate": 0.225,
        "speed": 0.225, "dmgReduce": 0.130, "hpRegen": 13.65},
    4: {"atk": 336.6, "def": 214.2, "maxHp": 1071.0, "critRate": 0.378,
        "speed": 0.378, "dmgReduce": 0.210, "hpRegen": 25.5},
}
# 法宝主属性(xianyuan公式): floor(tier×qualityMult)×5
# T7 orange(×1.5): floor(7×1.5)×5=50, T9 cyan(×1.8): floor(9×1.8)×5=80
EXCLUSIVE_FAIRY = {3: 50, 4: 80}

# 副属性行数/值
SUB_CRIT_RATE = {3: 0.038, 4: 0.060}
SUB_CRIT_DMG  = {3: 0.19,  4: 0.30}
SUB_FAIRY     = {3: 10, 4: 16}
SUB_ATK       = {3: 10.5, 4: 16.5}
SUB_HEAVY     = {3: 56.0, 4: 88.0}
SUB_MAXHP     = {3: 42.0, 4: 66.0}
SPIRIT_CRIT_DMG = {3: 0, 4: 0.15 * 12}  # 4章元灵暴伤=1.80

ARTIFACTS = {
    3: {"heavyHit": 300, "constitution": 100, "physique": 100},
    4: {"heavyHit": 300, "constitution": 100, "physique": 100,
        "wisdom": 100, "fortune": 100, "def": 64},
}

# 法宝图鉴加成 (from EquipmentData.lua FabaoCollectionBonuses)
FABAO_COLLECTION = {
    "血海图": {3: {"atk": 5, "killHeal": 5},    4: {"atk": 7, "killHeal": 7}},
    "浩气印": {3: {"killHeal": 5, "hpRegen": 1}, 4: {"killHeal": 7, "hpRegen": 2}},
    "青云塔": {3: {"heavyHit": 15, "def": 5},    4: {"heavyHit": 20, "def": 7}},
    "封魔盘": {3: {"maxHp": 20, "hpRegen": 1},   4: {"maxHp": 30, "hpRegen": 2}},
    "龙极令": {3: {},                             4: {"atk": 5}},
}

def sub_lines(ch):
    """副属性行数: (暴击率行, 暴击伤害行, 仙缘行, 倾向行, 速度行)"""
    if ch == 4:
        return (10, 12, 11, 10, 5)
    else:
        return (11, 12, 11, 9, 5)

# ==================== 仙缘转换 (from Player.lua) ====================
def wisdom_effects(pts):
    skill_dmg = math.floor(pts / 5) * 0.01       # 每5悟性+1%技能伤害
    combo     = math.floor(pts / 50) * 0.01       # 每50悟性+1%连击率
    return skill_dmg, combo

def constitution_effects(pts):
    def_bonus  = math.floor(pts / 5) * 0.01      # 每5根骨+1%DEF
    heavy_dmg  = math.floor(pts / 25) * 0.01     # 每25根骨+1%重击伤害
    heavy_rate = math.floor(pts / 25) * 0.01     # 每25根骨+1%重击率
    return def_bonus, heavy_dmg, heavy_rate

def physique_effects(pts):
    hp_regen      = pts * 0.3                     # 每点体魄+0.3回血
    hp_bonus      = math.floor(pts / 5) * 0.01   # 每5体魄+1%HP
    bloodrage_rate = math.floor(pts / 25) * 0.01  # 每25体魄+1%焚血率
    return hp_regen, hp_bonus, bloodrage_rate

# ==================== 基础属性计算(不含法宝主属性) ====================
def calc_base_stats(cls, ch):
    """计算指定职业在指定章节的基础属性(法宝主属性另算)"""
    lv = PLAYER_LV[ch]
    rm = REALM_MULT[ch]
    eq = EQUIP_MAIN[ch]
    lines = sub_lines(ch)
    arts = ARTIFACTS[ch]

    base_atk = (15 + 3 * lv) * rm + eq["atk"]
    base_def = (5 + 2 * lv) * rm + eq["def"]
    base_hp  = (100 + 15 * lv) * rm + eq["maxHp"]
    base_regen = 1.0 + 0.2 * lv + eq["hpRegen"]
    base_crit_rate = 0.05 + eq["critRate"]
    atk_speed = 1.0 + REALM_ATKSPD[ch]

    crit_rate_sub = lines[0] * SUB_CRIT_RATE[ch]
    crit_dmg_sub  = lines[1] * SUB_CRIT_DMG[ch]
    total_crit_rate = min(1.0, base_crit_rate + crit_rate_sub)
    total_crit_dmg  = 1.50 + crit_dmg_sub + SPIRIT_CRIT_DMG[ch]
    crit_mult = total_crit_rate * total_crit_dmg + (1 - total_crit_rate) * 1.0

    # 各职业差异(不含法宝主属性, 法宝主属性在A组按法宝类型单独加)
    if cls == "太虚":
        atk_sub = lines[3] * SUB_ATK[ch]
        total_atk = base_atk + atk_sub
        # 太虚默认堆悟性(从套装5pc+仙缘行), 但法宝主属性是变量
        # 基础仙缘(不含法宝): lv(天赋仙缘) + 副属性仙缘行 + 5pc套装bonus + 神器
        base_wisdom  = lv + lines[2] * SUB_FAIRY[ch] + 25 + arts.get("wisdom", 0)   # 太虚天赋仙缘=悟性
        base_con     = 25 + arts.get("constitution", 0)   # 副套装3pc青云 + 神器
        base_phy     = arts.get("physique", 0)
        base_fortune = arts.get("fortune", 0)
        total_hp_raw = base_hp
        base_heavy_hit = 0
        class_heavy_rate = 0
        class_combo = 0.08 + 0.02   # 天赋8% + 5pc血煞2%
        tendency = "ATK"

    elif cls == "罗汉":
        total_atk = base_atk   # 罗汉无ATK副属性
        heavy_sub = lines[3] * SUB_HEAVY[ch]
        base_con     = lv + lines[2] * SUB_FAIRY[ch] + 25 + arts.get("constitution", 0)  # 罗汉天赋仙缘=根骨
        base_wisdom  = 25 + arts.get("wisdom", 0)     # 副套装3pc血煞 + 神器
        base_phy     = arts.get("physique", 0)
        base_fortune = arts.get("fortune", 0)
        total_hp_raw = base_hp
        base_heavy_hit = heavy_sub + arts.get("heavyHit", 0)
        class_heavy_rate = 0.10 + 0.04   # 天赋10% + 5pc青云4%
        class_combo = 0
        tendency = "HeavyHit"

    elif cls == "镇岳":
        total_atk = base_atk
        maxhp_sub = lines[3] * SUB_MAXHP[ch]
        base_phy     = lv + lines[2] * SUB_FAIRY[ch] + 25 + arts.get("physique", 0)  # 镇岳天赋仙缘=体魄
        base_wisdom  = 25 + arts.get("wisdom", 0)     # 副套装3pc血煞 + 神器
        base_con     = arts.get("constitution", 0)
        base_fortune = arts.get("fortune", 0)
        total_hp_raw = base_hp + maxhp_sub
        base_heavy_hit = 0
        class_heavy_rate = 0
        class_combo = 0
        tendency = "MaxHP"

    return {
        "cls": cls, "ch": ch,
        "atk": total_atk,
        "hp_raw": total_hp_raw,
        "crit_rate": total_crit_rate,
        "crit_dmg": total_crit_dmg,
        "crit_mult": crit_mult,
        "atk_speed": atk_speed,
        # 基础仙缘(不含法宝主属性)
        "base_wisdom": base_wisdom,
        "base_con": base_con,
        "base_phy": base_phy,
        "base_fortune": base_fortune,
        # 其他
        "base_heavy_hit": base_heavy_hit,
        "class_heavy_rate": class_heavy_rate,
        "class_combo": class_combo,
        "mon_def": BOSS_AVG_DEF[ch],
        "base_regen": base_regen,
        "tendency": tendency,
    }

def apply_fabao(base, fabao_name, ch):
    """在base属性上叠加法宝主属性和图鉴加成, 返回完整属性"""
    s = dict(base)  # copy

    # 法宝主属性值
    fabao_val = EXCLUSIVE_FAIRY[ch]  # xianyuan公式: base5 × TIER_MULT × quality

    # 龙极令特殊: standard公式, mainStatType=atk
    # xianyuan公式和standard公式在预设表中直接取最终值
    # EXCLUSIVE_FAIRY = {3:68, 4:128} 是xianyuan公式的结果
    # 龙极令的atk值 = base2 × TIER_MULT × quality ≈ 不同
    # 龙极令: standard公式, base=2, floor(base × TIER_MULT × qualityMult)
    # 品质上限同法宝: T7→orange(×1.5), T9→cyan(×1.8)
    # Ch3 T7: floor(2×10.5×1.5)=floor(31.5)=31; Ch4 T9: floor(2×17.0×1.8)=floor(61.2)=61
    LONGJI_ATK = {3: 31, 4: 61}

    if fabao_name == "血海图":
        s["base_wisdom"] = s["base_wisdom"] + fabao_val
    elif fabao_name == "浩气印":
        s["base_fortune"] = s["base_fortune"] + fabao_val
    elif fabao_name == "青云塔":
        s["base_con"] = s["base_con"] + fabao_val
    elif fabao_name == "封魔盘":
        s["base_phy"] = s["base_phy"] + fabao_val
    elif fabao_name == "龙极令":
        s["atk"] = s["atk"] + LONGJI_ATK[ch]

    # 图鉴加成
    col = FABAO_COLLECTION.get(fabao_name, {}).get(ch, {})
    s["atk"] = s["atk"] + col.get("atk", 0)
    s["base_heavy_hit"] = s["base_heavy_hit"] + col.get("heavyHit", 0)
    s["hp_raw"] = s["hp_raw"] + col.get("maxHp", 0)
    s["base_regen"] = s["base_regen"] + col.get("hpRegen", 0)

    # 计算派生属性
    wisdom = s["base_wisdom"]
    con    = s["base_con"]
    phy    = s["base_phy"]
    fortune = s["base_fortune"]

    skill_dmg, combo_from_wis = wisdom_effects(wisdom)
    con_def, con_hd, con_hr = constitution_effects(con)
    phy_regen, phy_hp, phy_br = physique_effects(phy)

    s["wisdom"]   = wisdom
    s["con"]      = con
    s["phy"]      = phy
    s["fortune"]  = fortune
    s["xianyuan_sum"] = wisdom + con + phy + fortune
    s["skill_dmg"]    = skill_dmg
    s["combo"]        = s["class_combo"] + combo_from_wis
    s["heavy_hit"]    = s["base_heavy_hit"]
    s["heavy_rate"]   = s["class_heavy_rate"] + con_hr
    s["con_heavy_dmg"] = con_hd
    s["hp"] = s["hp_raw"] * (1 + phy_hp)
    s["regen"] = s["base_regen"] + phy_regen
    return s


# ==================== A组: 法宝技能DPS ====================
def fabao_skill_dps_xuehaitu(s):
    """血海图技能: blood_sea_aoe
    即时: effectiveAtk×0.60 → CalcDamage → ApplyCrit
    DOT: effectiveAtk×0.15/s × 5s = 0.75×effectiveAtk(真伤, 直接TakeDamage)
    CD12s, 有连击"""
    effective_atk = s["atk"] * (1 + s["skill_dmg"])
    # 即时伤害
    raw_instant = math.floor(effective_atk * 0.60)
    instant_dmg = calc_damage(raw_instant, s["mon_def"])
    instant_crit = instant_dmg * s["crit_mult"]
    # DOT (5 ticks, 每tick = effectiveAtk × 0.15, 真伤)
    dot_per_tick = math.floor(effective_atk * 0.15)
    dot_total = dot_per_tick * 5
    # 单次释放总伤 = 即时(含暴击期望) + DOT(真伤不暴击)
    total_per_cast = instant_crit + dot_total
    # 连击: 连击概率 × 再来一次(即时+DOT均重复)
    combo_total = total_per_cast * s["combo"]
    total_with_combo = total_per_cast + combo_total
    dps = total_with_combo / 12.0
    return dps, instant_crit, dot_total, total_per_cast, total_with_combo

def fabao_skill_dps_haoqiyin(s, base_dps):
    """浩气印技能: haoran_zhengqi (BUFF型, 无直接伤害)
    +100四维, 持续10s, CD20s → 50%覆盖率
    通过增加四维间接提升所有伤害来源的DPS"""
    # 计算增加100四维后各派生属性的变化量
    extra_wisdom = 100
    extra_con = 100
    extra_phy = 100
    extra_fortune = 100

    # 悟性+100: skillDmg增加, combo增加
    new_skill_dmg, new_combo = wisdom_effects(s["wisdom"] + extra_wisdom)
    delta_skill_dmg = new_skill_dmg - s["skill_dmg"]
    delta_combo = new_combo - (s["combo"] - s["class_combo"])  # 减去职业基础combo再比较

    # 根骨+100: 重击伤害增加, 重击率增加
    _, new_hd, new_hr = constitution_effects(s["con"] + extra_con)
    delta_hd = new_hd - s["con_heavy_dmg"]
    delta_hr = new_hr - (s["heavy_rate"] - s["class_heavy_rate"])

    # 体魄+100: 焚血率增加
    _, _, new_br = physique_effects(s["phy"] + extra_phy)

    # 近似: buff期间DPS提升 ≈ base_dps × delta_skill_dmg (主要来自skillDmg%)
    # 50%覆盖率
    # 简化: 增伤效果 ≈ delta_skill_dmg(技能伤害) + delta_combo(连击率) 对普攻无直接效果
    # 实际上浩气印主要价值 = 50% uptime × (所有技能+delta_skill_dmg% + 所有连击+delta_combo)
    # 这不是简单的DPS加, 而是乘法增益
    # 以base_dps的百分比增益估算
    buff_dps_gain = base_dps * delta_skill_dmg * 0.50  # 50% uptime × skillDmg%增量 × baseDPS

    return buff_dps_gain, delta_skill_dmg, delta_combo, delta_hd, delta_hr

def fabao_skill_dps_qingyunta(s):
    """青云塔技能: qingyun_suppress (multi_zone_heavy)
    (ATK+HH) × (1+conHeavyDmg) × 1.0(mult) → ApplyCrit → 真伤TakeDamage
    CD30s, 有连击"""
    base_dmg = (s["atk"] + s["heavy_hit"]) * (1 + s["con_heavy_dmg"])
    dmg_crit = base_dmg * s["crit_mult"]
    total_with_combo = dmg_crit * (1 + s["combo"])
    dps = total_with_combo / 30.0
    return dps, base_dmg, dmg_crit, total_with_combo

def fabao_skill_dps_fengmopan(s, base_dps):
    """封魔盘技能: fengmo_seal_array (增伤区域, 无直接伤害)
    +10%最终伤害, 持续10s, CD20s → 50%覆盖率
    花费10%当前HP"""
    # 等效DPS增益 = baseDPS × 10% × 50%覆盖率 = baseDPS × 5%
    dps_gain = base_dps * 0.10 * 0.50
    return dps_gain

def fabao_skill_dps_longjiling(s):
    """龙极令技能: dragon_breath (xianyuan_cone_aoe)
    xianyuanSum × 2.0 × (1+skillDmg%) → CalcDamage → ApplyCrit
    CD15s, 有连击"""
    raw = math.floor(s["xianyuan_sum"] * 2.0)
    effective = math.floor(raw * (1 + s["skill_dmg"]))
    dmg = calc_damage(effective, s["mon_def"])
    dmg_crit = dmg * s["crit_mult"]
    total_with_combo = dmg_crit * (1 + s["combo"])
    dps = total_with_combo / 15.0
    return dps, raw, effective, dmg, dmg_crit, total_with_combo


# ==================== B组: 武器特效 + 钉耙神器 ====================
def weapon_wind_slash(s):
    """断流·裂风斩: 20%/hit, 75%ATK → CalcDamage, 无暴击, 无CD"""
    raw = math.floor(s["atk"] * 0.75)
    dmg = calc_damage(raw, s["mon_def"])
    dps = dmg * 0.20 * s["atk_speed"]
    return dps, raw, dmg

def weapon_sacrifice_aura(s):
    """焚天·献祭光环: 5%ATK/0.5s(=10%ATK/s), 真伤, 无CalcDmg, 无暴击, 持续"""
    dmg_per_tick = math.floor(s["atk"] * 0.05)
    dps = dmg_per_tick * 2  # 0.5s间隔
    return dps, dmg_per_tick

def weapon_lifesteal_burst(s, base_dps):
    """噬魂: 击杀+3%maxHP回复 +30%增伤3s, CD1s
    Boss战: 无击杀 → DPS=0
    刷怪: 假设每5s击杀 → 3/5=60%覆盖率 → 增伤=baseDPS×30%×60%"""
    dps_boss = 0
    dps_farm = base_dps * 0.30 * 0.60  # 刷怪场景
    heal_per_kill = math.floor(s["hp"] * 0.03)
    return dps_boss, dps_farm, heal_per_kill

def weapon_heavy_strike(s):
    """裂地: 每20攻必重击, (ATK+HH)×(1+conHeavyDmg) → ApplyCrit, 真伤"""
    heavy_dmg = (s["atk"] + s["heavy_hit"]) * (1 + s["con_heavy_dmg"])
    heavy_crit = heavy_dmg * s["crit_mult"]
    interval = 20.0 / s["atk_speed"]
    dps = heavy_crit / interval
    return dps, heavy_dmg, heavy_crit, interval

def weapon_shadow_strike(s):
    """灭影: 暴击时50%, 60%ATK → CalcDamage, CD2s, 无暴击"""
    raw = math.floor(s["atk"] * 0.60)
    dmg = calc_damage(raw, s["mon_def"])
    crit_per_sec = s["crit_rate"] * s["atk_speed"]
    trigger_rate = min(crit_per_sec * 0.50, 0.50)  # CD2s上限
    dps = dmg * trigger_rate
    return dps, raw, dmg, trigger_rate

def artifact_tianpeng(s):
    """天蓬遗威(钉耙神器): 15%/hit, 50%ATK真伤, 无暴击, CD2s"""
    raw = math.floor(s["atk"] * 0.50)
    trigger_rate = min(s["atk_speed"] * 0.15, 0.50)
    dps = raw * trigger_rate
    return dps, raw, trigger_rate


# ==================== C组: 套装8件被动 ====================
def set8pc_xuesha(s):
    """血煞冲击: wisdom×3 → CalcDamage, 不暴击, CD30s
    触发: player_deal_damage 15%"""
    raw = math.floor(s["wisdom"] * 3)
    dmg = calc_damage(raw, s["mon_def"])
    dps = dmg / 30.0
    return dps, raw, dmg

def set8pc_qingyun(s):
    """青云裂空: constitution×3 → CalcDamage, 不暴击, CD30s
    触发: player_heavy_hit 25% (需重击率>0)"""
    raw = math.floor(s["con"] * 3)
    dmg = calc_damage(raw, s["mon_def"])
    dps = dmg / 30.0
    if s["heavy_rate"] <= 0:
        dps = 0
    return dps, raw, dmg

def set8pc_fengmo(s):
    """封魔金轮: physique×3 → CalcDamage, 不暴击, CD30s
    触发: player_hurt 10%"""
    raw = math.floor(s["phy"] * 3)
    dmg = calc_damage(raw, s["mon_def"])
    dps = dmg / 30.0
    return dps, raw, dmg

def set8pc_haoqi(s):
    """浩气破天: fortune×3 → CalcDamage, 不暴击, CD30s
    触发: monster_death 20% (Boss战≈0)"""
    raw = math.floor(s["fortune"] * 3)
    dmg = calc_damage(raw, s["mon_def"])
    dps_boss = 0
    dps_farm = dmg / 30.0
    return dps_boss, dps_farm, raw, dmg


# ==================== 普攻DPS (用于增伤效果参照) ====================
def calc_auto_dps(s):
    """计算普攻基础DPS, 作为增伤类效果的参照基准"""
    raw = calc_damage(math.floor(s["atk"]), s["mon_def"])
    dps = raw * s["crit_mult"] * s["atk_speed"]
    return dps


# ==================== 输出工具 ====================
def fmt(v, d=1):
    return f"{v:.{d}f}"

def pct(v, d=1):
    return f"{v*100:.{d}f}%"

# ==================== 主输出 ====================
CLASSES  = ["太虚", "罗汉", "镇岳"]
CHAPTERS = [3, 4]
FABAO_NAMES = ["血海图", "浩气印", "青云塔", "封魔盘", "龙极令"]

print("=" * 130)
print("特效DPS对比分析 v2 — 按装备槽位分三组")
print("A组: 5法宝(同部位) | B组: 5武器特效+1神器 | C组: 4套装8件被动")
print("=" * 130)

for ch in CHAPTERS:
    tier_label = "T7紫品" if ch == 3 else "T9橙品"
    print(f"\n{'#'*130}")
    print(f"## 第{ch}章毕业 | Lv.{PLAYER_LV[ch]} | 境界×{REALM_MULT[ch]} | BOSS均DEF={BOSS_AVG_DEF[ch]} | 法宝{tier_label}")
    print(f"{'#'*130}")

    # 计算基础属性(不含法宝)
    bases = {}
    for cls in CLASSES:
        bases[cls] = calc_base_stats(cls, ch)

    # ============================================================
    # A组: 5法宝对比
    # ============================================================
    print(f"\n{'='*130}")
    print(f"A组: 5法宝同部位对比 — 主属性贡献 + 技能DPS + 图鉴加成 = 总槽位价值")
    print(f"{'='*130}")

    for cls in CLASSES:
        base = bases[cls]
        print(f"\n  ■ 【{cls}】(倾向={base['tendency']}, 天赋仙缘={'悟性' if cls=='太虚' else '根骨' if cls=='罗汉' else '体魄'})")

        # 先算不带法宝的auto DPS作为参照
        s_none = apply_fabao(base, "龙极令", ch)  # 用龙极令近似(它给ATK不给仙缘)
        auto_dps_ref = calc_auto_dps(s_none)

        fabao_rows = []
        for fab_name in FABAO_NAMES:
            s = apply_fabao(base, fab_name, ch)
            auto_dps = calc_auto_dps(s)

            # 技能DPS
            if fab_name == "血海图":
                skill_dps, inst, dot, per_cast, w_combo = fabao_skill_dps_xuehaitu(s)
                skill_desc = f"即时{fmt(inst)}+DOT{fmt(dot,0)}/cast CD12s"
            elif fab_name == "浩气印":
                skill_dps, d_sd, d_cm, d_hd, d_hr = fabao_skill_dps_haoqiyin(s, auto_dps)
                skill_desc = f"BUFF:+{pct(d_sd)}skillDmg 50%up"
            elif fab_name == "青云塔":
                skill_dps, bd, dc, wc = fabao_skill_dps_qingyunta(s)
                skill_desc = f"重击真伤{fmt(dc,0)}/cast CD30s"
            elif fab_name == "封魔盘":
                skill_dps = fabao_skill_dps_fengmopan(s, auto_dps)
                skill_desc = f"+10%finalDmg 50%up"
            elif fab_name == "龙极令":
                skill_dps, raw, eff, dmg, dc, wc = fabao_skill_dps_longjiling(s)
                skill_desc = f"仙缘和{s['xianyuan_sum']:.0f}×2→{fmt(dc,0)}/cast CD15s"

            # 主属性对普攻DPS的增量
            auto_dps_delta = auto_dps - auto_dps_ref

            # 总DPS贡献 = 技能DPS + 普攻DPS增量(来自主属性)
            total_value = skill_dps + max(0, auto_dps_delta)

            # 附加价值(非DPS)
            col = FABAO_COLLECTION.get(fab_name, {}).get(ch, {})
            extras = []
            if col.get("killHeal", 0) > 0:
                extras.append(f"击杀回{col['killHeal']}%HP")
            if col.get("hpRegen", 0) > 0:
                extras.append(f"+{col['hpRegen']}回血")
            if col.get("def", 0) > 0:
                extras.append(f"+{col['def']}DEF")
            if col.get("maxHp", 0) > 0:
                extras.append(f"+{col['maxHp']}HP")
            extra_str = ", ".join(extras) if extras else "-"

            fabao_rows.append({
                "name": fab_name,
                "stat_type": "wisdom" if fab_name == "血海图" else "fortune" if fab_name == "浩气印" else "constitution" if fab_name == "青云塔" else "physique" if fab_name == "封魔盘" else "atk",
                "stat_val": EXCLUSIVE_FAIRY[ch] if fab_name != "龙极令" else (27 if ch==3 else 51),
                "skill_dps": skill_dps,
                "auto_delta": max(0, auto_dps_delta),
                "total_dps": total_value,
                "skill_desc": skill_desc,
                "extra_str": extra_str,
            })

        # 排序
        fabao_rows.sort(key=lambda x: -x["total_dps"])

        # 输出表头
        print(f"    {'#':>2s} {'法宝':8s} {'主属性':14s} {'技能DPS':>10s} {'属性DPS增量':>12s} {'总DPS贡献':>12s}  {'技能机制':30s} {'图鉴附加':20s}")
        print(f"    {'─'*120}")
        for i, r in enumerate(fabao_rows):
            stat_str = f"+{r['stat_val']}{r['stat_type']}"
            print(f"    {i+1:>2d} {r['name']:8s} {stat_str:14s} {fmt(r['skill_dps']):>10s} {fmt(r['auto_delta']):>12s} {fmt(r['total_dps']):>12s}  {r['skill_desc']:30s} {r['extra_str']:20s}")

    # ============================================================
    # B组: 武器特效 + 神器
    # ============================================================
    print(f"\n{'='*130}")
    print(f"B组: 5龙极武器特效 + 1钉耙神器 — Boss战DPS对比")
    print(f"{'='*130}")

    # B组使用默认法宝(血海图, 太虚最常用; 其他职业也用各自最优法宝)
    # 但武器特效与法宝选择无关, 用一个固定法宝即可
    # 为公平起见, 各职业用各自天赋仙缘对应的法宝
    DEFAULT_FABAO = {"太虚": "血海图", "罗汉": "青云塔", "镇岳": "封魔盘"}

    print(f"\n    {'特效':16s} {'机制':32s}", end="")
    for cls in CLASSES:
        print(f" {cls:>10s}", end="")
    print()
    print(f"    {'─'*110}")

    weapon_effects = [
        ("断流·裂风斩", "75%ATK→CalcDmg|20%/hit|无CD",     weapon_wind_slash),
        ("焚天·献祭光环", "5%ATK/0.5s|真伤|持续",            weapon_sacrifice_aura),
        ("噬魂·增伤", "击杀+30%buff3s|Boss≈0",              None),
        ("裂地·重击", "每20攻必重击|(ATK+HH)×Crit|真伤",     weapon_heavy_strike),
        ("灭影·追击", "暴击50%|60%ATK→CalcDmg|CD2s",        weapon_shadow_strike),
        ("天蓬遗威", "15%/hit|50%ATK|真伤|CD2s",             artifact_tianpeng),
    ]

    weapon_results = []
    for wname, wmech, wfunc in weapon_effects:
        dps_list = []
        for cls in CLASSES:
            s = apply_fabao(bases[cls], DEFAULT_FABAO[cls], ch)
            if wname == "噬魂·增伤":
                auto_dps = calc_auto_dps(s)
                boss_dps, farm_dps, heal = weapon_lifesteal_burst(s, auto_dps)
                dps_list.append(boss_dps)
            elif wfunc == weapon_sacrifice_aura:
                d, _ = wfunc(s)
                dps_list.append(d)
            elif wfunc == weapon_wind_slash:
                d, _, _ = wfunc(s)
                dps_list.append(d)
            elif wfunc == weapon_heavy_strike:
                d, _, _, _ = wfunc(s)
                dps_list.append(d)
            elif wfunc == weapon_shadow_strike:
                d, _, _, _ = wfunc(s)
                dps_list.append(d)
            elif wfunc == artifact_tianpeng:
                d, _, _ = wfunc(s)
                dps_list.append(d)
        weapon_results.append((wname, wmech, dps_list))

        line = f"    {wname:16s} {wmech:32s}"
        for v in dps_list:
            if v > 0:
                line += f" {fmt(v):>10s}"
            else:
                line += f" {'—':>10s}"
        print(line)

    # 排名
    print(f"\n    --- Boss战DPS排名 ---")
    for cls in CLASSES:
        ci = CLASSES.index(cls)
        ranked = [(wr[0], wr[2][ci]) for wr in weapon_results]
        ranked.sort(key=lambda x: -x[1])
        print(f"\n    【{cls}】")
        for i, (n, d) in enumerate(ranked):
            if d > 0:
                print(f"      #{i+1} {n:16s} {fmt(d):>8s}/s")
            else:
                print(f"      #{i+1} {n:16s} {'—':>8s}  (Boss战无效)")

    # 详细分析
    print(f"\n    --- 关键详情 ---")
    for cls in CLASSES:
        s = apply_fabao(bases[cls], DEFAULT_FABAO[cls], ch)
        # 裂地
        dps_hs, hd, hdc, interval = weapon_heavy_strike(s)
        # 断流
        _, raw_ws, dmg_ws = weapon_wind_slash(s)
        print(f"    {cls}: ATK={fmt(s['atk'])} HH={fmt(s['heavy_hit'])} critMult={fmt(s['crit_mult'],3)} atkSpd={fmt(s['atk_speed'])}"
              f" | 断流: raw={raw_ws}→dmg={dmg_ws}"
              f" | 裂地: base={fmt(hd,0)}→crit={fmt(hdc,0)}/{fmt(interval)}s")

    # ============================================================
    # C组: 套装8件被动
    # ============================================================
    print(f"\n{'='*130}")
    print(f"C组: 4套装8件被动对比 — Boss战DPS (attr×3 → CalcDamage, 不暴击, CD30s)")
    print(f"{'='*130}")

    print(f"\n    {'套装被动':14s} {'触发条件':24s} {'属性来源':10s}", end="")
    for cls in CLASSES:
        print(f" {'DPS':>8s} {'(raw→dmg)':>14s}", end="")
    print()
    print(f"    {'─'*120}")

    set_effects = [
        ("血煞冲击", "15%/命中(player_deal_damage)", "wisdom", set8pc_xuesha),
        ("青云裂空", "25%/重击(player_heavy_hit)",    "constitution", set8pc_qingyun),
        ("封魔金轮", "10%/受击(player_hurt)",         "physique", set8pc_fengmo),
        ("浩气破天", "20%/击杀(monster_death)",       "fortune", set8pc_haoqi),
    ]

    set_results = []
    for sname, strig, sattr, sfunc in set_effects:
        line = f"    {sname:14s} {strig:24s} {sattr:10s}"
        dps_list = []
        for cls in CLASSES:
            s = apply_fabao(bases[cls], DEFAULT_FABAO[cls], ch)
            if sfunc == set8pc_haoqi:
                d_boss, d_farm, raw, dmg = sfunc(s)
                dps_list.append(d_boss)
                if d_boss > 0:
                    line += f" {fmt(d_boss):>8s} ({raw}→{dmg})"
                else:
                    line += f" {'Boss≈0':>8s} ({raw}→{dmg})"
            elif sfunc == set8pc_qingyun:
                d, raw, dmg = sfunc(s)
                dps_list.append(d)
                note = "" if s["heavy_rate"] > 0 else "[无重击]"
                if d > 0:
                    line += f" {fmt(d):>8s} ({raw}→{fmt(dmg,0)}){note}"
                else:
                    line += f" {'—':>8s} ({raw}→{fmt(dmg,0)}){note}"
            else:
                d, raw, dmg = sfunc(s)
                dps_list.append(d)
                line += f" {fmt(d):>8s} ({raw}→{fmt(dmg,0)})"
        set_results.append((sname, dps_list))
        print(line.ljust(120))

    # 排名
    print(f"\n    --- Boss战DPS排名 ---")
    for cls in CLASSES:
        ci = CLASSES.index(cls)
        ranked = [(sr[0], sr[1][ci]) for sr in set_results]
        ranked.sort(key=lambda x: -x[1])
        print(f"\n    【{cls}】")
        for i, (n, d) in enumerate(ranked):
            if d > 0:
                print(f"      #{i+1} {n:14s} {fmt(d):>8s}/s")
            else:
                note = "(Boss战无效)" if "浩气" in n else "(需重击率>0)" if "青云" in n else ""
                print(f"      #{i+1} {n:14s} {'—':>8s}  {note}")

    # 属性值参考
    print(f"\n    --- 各职业套装被动关联属性值 ---")
    for cls in CLASSES:
        s = apply_fabao(bases[cls], DEFAULT_FABAO[cls], ch)
        print(f"    {cls}: 悟性={s['wisdom']:.0f} 根骨={s['con']:.0f} 体魄={s['phy']:.0f} 福缘={s['fortune']:.0f}"
              f" | 重击率={pct(s['heavy_rate'])}")


print(f"\n\n{'='*130}")
print("计算公式说明:")
print("─" * 130)
print("A组法宝:")
print("  血海图: 主属性+悟性 | 技能=即时(ATK×0.6×(1+skillDmg%)→CalcDmg→Crit) + DOT(ATK×0.15×(1+skillDmg%)×5tick真伤) | CD12s+连击")
print("  浩气印: 主属性+福缘 | 技能=BUFF(+100四维 10s/20sCD=50%覆盖) → 间接提升skillDmg%/combo/重击率等")
print("  青云塔: 主属性+根骨 | 技能=(ATK+HH)×(1+conHeavyDmg)→Crit→真伤TakeDamage | CD30s+连击")
print("  封魔盘: 主属性+体魄 | 技能=增伤区域(+10%最终伤害 10s/20sCD=50%覆盖) | 花费10%HP")
print("  龙极令: 主属性+ATK  | 技能=仙缘和×2.0×(1+skillDmg%)→CalcDmg→Crit | CD15s+连击")
print()
print("B组武器/神器:")
print("  断流: 20%/hit, 75%ATK→CalcDmg, 无暴击, 无CD → 高频")
print("  焚天: 5%ATK/0.5s, 真伤, 持续性 → 稳定DPS")
print("  噬魂: 击杀+30%增伤3s, Boss战≈0, 刷怪有效")
print("  裂地: 每20攻必重击, (ATK+HH)×(1+conHD)×CritMult, 真伤 → 罗汉最优")
print("  灭影: 暴击50%追击, 60%ATK→CalcDmg, CD2s → 依赖暴击率")
print("  天蓬: 15%/hit, 50%ATK真伤, CD2s → 稳定但有CD限制")
print()
print("C组套装被动:")
print("  统一: attr×3 → CalcDamage(raw, monDef), 不暴击, CD30s")
print("  血煞冲击: wisdom×3, 15%/命中触发 | 青云裂空: con×3, 25%/重击触发(需重击率)")
print("  封魔金轮: phy×3, 10%/受击触发   | 浩气破天: fortune×3, 20%/击杀触发(Boss无效)")
print()
print("其他:")
print("  CalcDamage = ATK²/(ATK+DEF); 真伤 = 直接TakeDamage无视DEF")
print("  连击 = comboChance × 再释放一次; 暴击期望 = critRate×critDmg + (1-critRate)×1.0")
