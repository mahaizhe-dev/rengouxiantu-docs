# 数值参考手册

> **「人狗仙途」属性公式、装备数据、怪物数值、存档结构**
>
> 本文档是 AI 开发助手的数值速查表，所有数值已与代码交叉验证。
> 行为规范与安全红线见 [`rules.md`](rules.md)。
>
> **数据来源校验日期**: 2026-04-27

---

## §1 核心伤害公式

```lua
-- GameConfig.CalcDamage(atk, def)
DMG = ATK^2 / (ATK + DEF) * random(0.9, 1.1)
-- 最小伤害 = 1
```

---

## §2 玩家属性体系

### 2.1 基础战斗属性

| 属性 | 初始值 | 每级成长 | 计算公式 |
|------|--------|---------|---------|
| maxHp | 100 | +15 | `(base + equip + collection) * (1 + physiqueHpBonus)` |
| atk | 15 | +3 | `(base + equip + collection + title + seaPillar + medalFlat + artifactTiandi) * (1 + titleAtkBonus + buffAtkPercent)` |
| def | 5 | +2 | `(base + equip + collection) * (1 + constitutionDefBonus)` |
| hpRegen | 1.0 | +0.2 | `base + equip + collection`（受体魄回血效率加成） |
| critRate | 5% | — | `0.05 + equip + title` |
| critDmg | 150% | — | `1.5 + equip` |
| speed | 0 | — | `equip`（百分比加成移速） |
| attackSpeed | 1.0 | — | `base + realmBonus + petBerserk`（减速 debuff 乘算） |
| dmgReduce | 0 | — | `equip`（上限 75%） |

**ATK 来源汇总**（Player._RecalcStatsCache）：

| 来源 | 字段 | 说明 |
|------|------|------|
| 基础 | `self.atk` | 等级成长 |
| 装备 | `self.equipAtk` | InventorySystem 汇总 |
| 图鉴 | `self.collectionAtk` | CollectionSystem 累加 |
| 称号 | `self.titleAtk` | TitleSystem 累加（flat） |
| 海柱 | `self.seaPillarAtk` | SeaPillarSystem（第四章） |
| 勋章 | `self.medalAtkFlat` | 勋章系统 flat 加成 |
| 神器·天帝 | `self.artifactTiandiAtk` | ArtifactSystem |
| 称号% | `self.titleAtkBonus` | 百分比乘区 |
| Buff% | `CombatSystem.GetBuffAtkPercent()` | 百分比乘区 |

### 2.2 仙元属性（四维）

| 属性 | 来源 | 核心效果 |
|------|------|---------|
| **福缘** fortune | 装备+图鉴+神器+福源果 | 击杀金币+N；每5点→2%概率+1灵韵；每25点→+2%宠物同步率 |
| **悟性** wisdom | 装备（主属性：exclusive 槽） | 击杀经验+N；每5点→+1%技能伤害；每50点→+1%技能连击概率 |
| **根骨** constitution | 装备+丹药+神器+职业每级+1 | 每5点→+1%防御力；每25点→+1%重击伤害/+1%重击概率 |
| **体魄** physique | 装备 | 每点→**+0.3/秒**生命回复；每5点→+1%生命上限；每25点→+1%血怒概率 |

**详细转换公式**：

```lua
-- 福缘
击杀金币加成 = totalFortune                    -- 每点+1金币
灵韵加成: 每5点→2%概率+1灵韵, 累计100%=保底1个  -- 仅BOSS掉灵韵时生效
宠物同步率加成 = floor(totalFortune / 25) * 0.02

-- 悟性
击杀经验加成 = totalWisdom                     -- 每点+1经验
技能伤害加成 = floor(totalWisdom / 5) * 0.01   -- 每5点+1%
技能连击概率 = floor(totalWisdom / 50) * 0.01  -- 每50点+1%

-- 根骨
防御力加成% = floor(totalConstitution / 5) * 0.01   -- 每5点+1%
重击伤害加成% = floor(totalConstitution / 25) * 0.01 -- 每25点+1%
重击概率加成 = floor(totalConstitution / 25) * 0.01  -- 每25点+1%

-- 体魄
生命回复加成 = totalPhysique * 0.3                   -- 每点+0.3/秒（固定值）
生命上限加成% = floor(totalPhysique / 5) * 0.01     -- 每5点+1%
血怒概率加成 = floor(totalPhysique / 25) * 0.01     -- 每25点+1%
```

### 2.2.1 套装属性系对照表

> 变更时间: 2026-04-25 — 青云/浩气套装属性系互换（setId 键名不变）

| 套装 (setId) | 属性系 | 3件效果 | 5件效果 | 8件效果 |
|-------------|--------|---------|---------|---------|
| **血煞** xuesha | 悟性系 | 悟性+25 | 连击率+2% | 技能触发血煞冲击 |
| **青云** qingyun | **根骨系** | 根骨+25 | 重击率+4% | 重击触发青云裂空 |
| **封魔** fengmo | 体魄系 | 体魄+25 | 血怒概率+4% | 受击触发封魔金轮 |
| **浩气** haoqi | **福缘系** | 福缘+25 | 宠物同步率+5% | 击杀触发浩气破天 |

**法宝属性（未变更）**：浩气印→福缘，青云塔→根骨

### 2.3 装备属性字段清单

Player 身上 InventorySystem 汇总：
```lua
equipAtk, equipDef, equipHp, equipSpeed, equipHpRegen,
equipCritRate, equipDmgReduce, equipSkillDmg, equipKillHeal,
equipCritDmg, equipHeavyHit, equipFortune, equipWisdom,
equipConstitution, equipPhysique
```

装备物品额外字段（第四章）：
```lua
item.sellCurrency  -- "lingYun" 或 nil（nil=金币）
item.spiritStat    -- { stat="fortune", name="福缘", value=8 }（灵器+品质）
item.forgeStat     -- { stat="atk", name="攻击力", value=14.85 }（洗练附加）
```

### 2.4 攻击速度与间隔

```lua
attackSpeed = base(1.0) + realmAtkSpeedBonus + petBerserkAtkSpeed
-- 减速debuff: attackSpeed *= (1 - slowAtkPercent)
attackInterval = AUTO_ATTACK_INTERVAL(1.0s) / attackSpeed
```

**境界攻速加成**：

| 境界 | 加成 | 境界 | 加成 |
|------|------|------|------|
| 凡人 | +0 | 合体 | +0.6 |
| 练气 | +0.1 | 大乘 | +0.8 |
| 筑基 | +0.2 | 渡劫 | +1.0 |
| 金丹 | +0.3 | | |
| 元婴 | +0.4 | | |
| 化神 | +0.5 | | |

---

## §3 战斗流程

### 3.1 普攻伤害流程

```
自动攻击（范围1.5格最近怪物）
  → damage = CalcDamage(GetTotalAtk(), monster.def)
  → 暴击判定 → damage * GetTotalCritDmg()
  → 噬魂增伤buff → damage + floor(damage * buffMult)（一次性消耗）
  → monster:TakeDamage(damage)
  → 重击判定（职业被动10% + 根骨加成）
    → heavyDmg = floor(ATK + HeavyHit) * (1 + constitutionHeavyDmgBonus)
    → 可暴击，无视防御
  → 裂地触发（每N次攻击必定重击，与概率重击独立）
  → DOT触发（流血：概率施加，内置CD）
  → 裂风斩触发（20%概率，75%ATK额外伤害，走CalcDamage）
  → 灭影触发（暴击时50%概率，60%ATK额外伤害，内置CD 2s）
  → 神器被动（天蓬遗威：15%概率，50%ATK真实伤害，不走CalcDamage）
  → 血怒叠层（体魄概率触发，满5层引爆）
```

### 3.2 玩家受伤流程

```
player:TakeDamage(damage)
  → 闪避判定（踏云：10%概率完全闪避）
  → 减伤计算: damage *= (1 - min(dmgReduce, 0.75))
  → 洗髓减伤（独立乘区，每级1%，上限26%）
  → _preDamageHooks（御剑护体、法宝被动等通用钩子）
  → 护盾吸收（金钟罩）: 护盾优先扣血
  → ArtifactCh4 护盾（第四章神器护盾层）
  → 扣血 → 死亡判定
  → 蜃影判定（15%概率免死+1s无敌）
```

### 3.3 血怒系统

```lua
BLOOD_RAGE_MAX_STACKS = 5
BLOOD_RAGE_DETONATE_RATIO = 0.10  -- 满层引爆 = 玩家maxHP × 10%，无视防御，可暴击
```

### 3.4 等级压制

```lua
-- 玩家等级 - 怪物等级 > 10 → 不掉经验、金币、宠物食物
```

---

## §4 技能与装备特效

### 4.1 职业系统

**3 个职业**（GameConfig.CLASS_DATA）：

| classId | 名称 | 被动技能 | 特点 |
|---------|------|---------|------|
| monk | 罗汉 | 金刚体魄（重击+10%，每级+1根骨） | 默认职业 |
| taixu | 太虚 | 太虚体（详见 SkillData） | 技能系 |
| zhenyue | 镇岳 | 镇岳体（详见 SkillData） | 血量系 |

### 4.2 技能表（monk 通用）

| 技能 | 类型 | 解锁 | CD | 伤害 | 特殊效果 |
|------|------|------|-----|------|---------|
| 金刚掌 ice_slash | melee_aoe | Lv.3 | 5s | 150%ATK | 减速20%/3s，范围1.5格 |
| 伏魔刀 blood_slash | lifesteal | Lv.6 | 8s | 100%ATK | 吸血等量HP，前方矩形2×1格 |
| 金钟罩 golden_bell | passive | 练气 | 60s | — | HP<50%触发，护盾=防御×4，8s |
| 降龙象 dragon_elephant | aoe | 专属 | 12s | 依tier | 强力AOE |

### 4.3 法宝技能

| 技能 | CD | 效果 |
|------|-----|------|
| 治愈 jade_gourd_heal | 30s | 每秒**4%**HP×10s（随葫芦升级增强） |

> 注：taixu 4技能 + zhenyue 4技能 + 2法宝技能详见 SkillData.lua

### 4.4 装备特效

| 特效名 | 类型 | 触发条件 | 效果 |
|--------|------|---------|------|
| 流血 bleed_dot | DOT | 35%概率，CD 3s | 每秒8%ATK×3s，无视防御 |
| 裂风斩 wind_slash | 额外伤害 | 20%概率 | 75%ATK额外伤害（走CalcDamage） |
| 噬魂 lifesteal_burst | 击杀 | CD 1s | 回3%maxHP + 下一击+30%伤害(3s) |
| 裂地 heavy_strike | 计数 | 每20次攻击 | 必定重击 |
| 灭影 shadow_strike | 暴击 | 50%概率，CD 2s | 60%ATK额外伤害 |
| 献祭光环 sacrifice_aura | 永久 | — | 每秒5%ATK真实伤害，范围3格 |
| 踏云 evade_damage | 闪避 | 10%概率 | 完全闪避一次伤害 |
| 蜃影 death_immunity | 免死 | 15%概率 | 免疫致命伤+1s无敌 |

---

## §5 装备数据

### 5.1 属性公式

```lua
-- 主属性（数值型：atk/def/maxHp/hpRegen/wisdom）
MainStat = BASE_MAIN_STAT[slot] * TIER_MULTIPLIER[tier] * qualityMultiplier

-- 主属性（百分比型：critRate/speed/dmgReduce）
PctMainStat = BASE_MAIN_STAT[slot] * PCT_TIER_MULTIPLIER[tier] * qualityMultiplier

-- 副属性（数值型）
SubStat = baseValue * SUB_STAT_TIER_MULT[tier] * random(0.8, 1.2)

-- 副属性（百分比型：critRate/critDmg）
PctSubStat = baseValue * PCT_SUB_TIER_MULT[tier] * random(0.8, 1.2)

-- 副属性（线性增长型：fortune/wisdom/constitution/physique）
LinearSub = floor(tier * qualityMultiplier)  -- 无随机
```

### 5.2 Tier 倍率表

**TIER_MULTIPLIER（普通属性）**:
| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 2.0 | 3.0 | 4.5 | 6.0 | 8.0 | 10.5 | 13.5 | 17.0 | 21.0 | 25.0 |

**PCT_TIER_MULTIPLIER（百分比主属性）**:
| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 4.0 | 5.0 | 6.0 | 7.0 | 8.0 | 9.0 |

**SUB_STAT_TIER_MULT（副属性）**:
| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 1.5 | 2.2 | 3.0 | 4.0 | 5.5 | 7.0 | 9.0 | 11.0 | 13.0 | 15.0 |

**PCT_SUB_TIER_MULT（百分比副属性）**:
| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 1.3 | 1.6 | 2.0 | 2.5 | 3.0 | 3.8 | 4.8 | 6.0 | 7.5 | 9.0 |

### 5.3 品质倍率

| 品质 | 倍率 | 副属性条数 | 额外特性 |
|------|------|----------|----------|
| white 普通 | 1.0 | 0 | |
| green 良品 | 1.1 | 1 | |
| blue 精品 | 1.2 | 2 | |
| purple 极品 | 1.3 | 3 | |
| orange 稀世 | 1.5 | 3 | |
| cyan 灵器 | 1.8 | 3 | + 灵性属性 + sellCurrency="lingYun" |
| red 圣器 | 2.1 | 3 | + 灵性属性 + sellCurrency="lingYun" |
| gold 仙器 | 2.5 | 3 | + 灵性属性 + sellCurrency="lingYun" |
| rainbow 神器 | 3.0 | 3 | + 灵性属性 + sellCurrency="lingYun" |

### 5.4 槽位与主属性

| 槽位 | 主属性 | 基础值(T1白) | 掉落类型 |
|------|--------|------------|---------|
| weapon | atk | 5 | 标准 |
| helmet | maxHp | 20 | 标准 |
| armor | def | 4 | 标准 |
| shoulder | def | 3 | 标准 |
| belt | maxHp | 15 | 标准 |
| boots | speed | 0.03 (3%) | 标准 |
| ring1 | atk | 3 | 标准 |
| ring2 | atk | 3 | 标准 |
| necklace | critRate | 0.03 | 标准 |
| cape | dmgReduce | 0.02 (2%) | **稀有**（仅BOSS） |
| treasure | hpRegen | 1.0 | **稀有**（仅BOSS） |
| exclusive | wisdom | 5 | **稀有**（挑战奖励） |

### 5.5 副属性池（12种）

| 副属性 | 基础值(T1) | 类型 |
|--------|-----------|------|
| atk 攻击力 | 1.5 | 数值型 |
| def 防御力 | 1.2 | 数值型 |
| maxHp 生命值 | 6 | 数值型 |
| hpRegen 生命回复 | 0.5 | 数值型 |
| killHeal 击杀回血 | 3 | 数值型 |
| critRate 暴击率 | 0.01 | 百分比型 |
| critDmg 暴击伤害 | 0.05 | 百分比型 |
| heavyHit 重击值 | 8 | 数值型 |
| fortune 福缘 | 1 | 线性增长 |
| wisdom 悟性 | 1 | 线性增长 |
| constitution 根骨 | 1 | 线性增长 |
| physique 体魄 | 1 | 线性增长 |

### 5.6 掉落 Tier 窗口

**怪物等级→可掉 Tier**（LootSystem.GetAvailableTiers，代码实际边界）：

| 怪物等级 | 可掉落 Tier |
|---------|------------|
| 1-5 | T1 |
| 6-10 | T1, T2 |
| 11-15 | T1, T2, T3 |
| 16-25 | T2, T3, T4 |
| 26-40 | T3, T4, T5 |
| 41-55 | T4, T5, T6 |
| 56-70 | T5, T6, T7 |
| 71-85 | T6, T7, T8 |
| 86-100 | T7, T8, T9 |
| 101-120 | T8, T9, T10 |
| 121+ | T9, T10, T11 |

窗口位置衰减: 位置1(最低) ×1.0, 位置2 ×0.5, 位置3(最高) ×0.2。BOSS/精英仅掉窗口最高 2 个 Tier。

### 5.7 洗练系统（ForgeUI）

为装备追加 1 条额外副属性（forgeStat）：

| 参数 | 说明 |
|------|------|
| 消耗 | 金币，按 Tier 递增（见下表） |
| 规则 | 从副属性池随机，排除已有 mainStat + subStats + forgeStat |
| 不排除 | spiritStat（灵性属性），可重复 |
| 数值 | 同副属性公式 |

**洗练费用表**（FORGE_COST，代码实际值）：

| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 500 | 1000 | 2000 | 3500 | 5000 | 10000 | 16000 | 25000 | 40000 | 60000 | 100000 |

### 5.8 灵韵货币机制

| 货币 | 字段 | 获取 | 用途 |
|------|------|------|------|
| 金币 | sellCurrency=nil | 击杀/出售 | 洗练、商店 |
| 灵韵 | sellCurrency="lingYun" | 出售灵器+装备、BOSS掉 | 高级消耗 |

灵器特有：灵性属性（spiritStat）、灵韵售价 `max(1, tier-4)`、仅 T9+ 可掉落灵器。

---

## §6 怪物数值

### 6.1 基础属性公式

```lua
baseHp  = 50 + level * 50
-- Lv.55+ 二次HP成长（高等级怪物更耐打）
if level > 55 then
    baseHp = baseHp + (level - 55)^2 * 5   -- K=5, 起点=55
end
baseAtk   = 5  + level * 2.5
baseDef   = 2  + level * 2
baseSpeed = 1.2 + level * 0.1
```

> 注：EXP 也在 Lv.55 开始二次增长

### 6.2 阶级倍率表

| 阶级 | HP | ATK | DEF | Speed | EXP | Gold |
|------|-----|-----|-----|-------|-----|------|
| normal | 1 | 1 | 1 | 1 | 1 | 1 |
| elite | 2 | 1.2 | 1.2 | 1.2 | 2 | 2 |
| boss | 5 | 1.3 | 1.3 | 1.3 | 5 | 5 |
| king_boss | 10 | 1.5 | 1.5 | 1.5 | 10 | 10 |
| emperor_boss | 20 | 1.8 | 1.8 | 1.6 | 20 | 20 |
| saint_boss | 50 | 2.5 | 2.5 | 2.0 | 50 | 50 |
| world_boss | 50×4=200 | 2.5 | 2.5 | 2.0 | 0 | 0 |

> 世界BOSS：圣级系数 × HP额外×4，不掉经验/金币，不回血，3h刷新。

### 6.3 怪物行为参数

| 参数 | 值 |
|------|---|
| 仇恨范围 | 4.0 格 |
| 脱离范围 | 8.0 格 |
| 攻击距离 | 1.5 格 |
| 巡逻速度 | 1.5 格/s |
| 追击速度 | 3.0 格/s |
| 回巢加速 | ×1.5 |
| 脱战回血 | 1%maxHP/s |
| 领地半径 | 普通6/精英10/BOSS16/王BOSS20 |

### 6.4 境界系数（statMult）

化神前：小境界步进 +0.10，大境界步进 +0.20
化神后（order≥13）：小境界步进 +0.15，大境界步进 +0.30

| order | 境界 | statMult | 步进 |
|-------|------|---------|------|
| 1 | 练气初 | 1.20 | — |
| 2 | 练气中 | 1.30 | +0.10 |
| 3 | 练气后 | 1.40 | +0.10 |
| 4 | 筑基初 | 1.60 | +0.20(大) |
| 5 | 筑基中 | 1.70 | +0.10 |
| 6 | 筑基后 | 1.80 | +0.10 |
| 7 | 金丹初 | 2.00 | +0.20(大) |
| 8 | 金丹中 | 2.10 | +0.10 |
| 9 | 金丹后 | 2.20 | +0.10 |
| 10 | 元婴初 | 2.40 | +0.20(大) |
| 11 | 元婴中 | 2.50 | +0.10 |
| 12 | 元婴后 | 2.60 | +0.10 |
| 13 | 化神初 | 2.90 | +0.30(大) |
| 14 | 化神中 | 3.05 | +0.15 |
| 15 | 化神后 | 3.20 | +0.15 |
| 16 | 合体初 | 3.50 | +0.30(大) |
| 17 | 合体中 | 3.65 | +0.15 |
| 18 | 合体后 | 3.80 | +0.15 |
| 19 | 大乘初 | 4.10 | +0.30(大) |
| 20 | 大乘中 | 4.25 | +0.15 |
| 21 | 大乘后 | 4.40 | +0.15 |
| 22 | 大乘巅 | 4.55 | +0.15 |
| 23 | 渡劫初 | 4.85 | +0.30(大) |
| 24 | 渡劫中 | 5.00 | +0.15 |
| 25 | 渡劫后 | 5.15 | +0.15 |
| 26 | 渡劫巅 | 5.30 | +0.15 |

境界经验系数 = `1.0 + order × 0.2`（不受化神加速影响）

最终属性 = `base × 阶级倍率 × 种族修正 × 境界系数`

---

## §7 章节系统

| 章节 | 名称 | 解锁条件 | 出生点 |
|------|------|---------|--------|
| 1 | 两界村 | 无 | (40.5, 40.5) |
| 2 | 乌家堡 | 筑基后期 + Ch1主线 | (7.5, **40.5**) |
| 3 | 万里黄沙 | 金丹后期 + Ch2主线 | (**15.5**, **10.5**) |
| 4 | 八卦海 | 化神后期 + Ch3主线 | (39.5, 39.5) |

- `ActiveZoneData` 是所有模块的当前章节数据**唯一入口**
- `RebuildWorld()` 是章节切换统一入口
- `TileTypes` 全章节 ID 唯一（Ch1:1-10, Ch2:11-17, Ch3:18-25, Ch4:26-39+）

### 7.1 不可行走瓦片（完整清单）

```
MOUNTAIN(6), WATER(7), WALL(8), FORTRESS_WALL(11), SEALED_GATE(14),
CRYSTAL_STONE(15), SAND_WALL(18), DEEP_SEA(26), SHALLOW_SEA(27),
CORAL_WALL(29), ROCK_REEF(30), ICE_WALL(33), ABYSS_WALL(35),
VOLCANO_WALL(37), DUNE_WALL(39), CELESTIAL_WALL(41), RIFT_VOID(43),
BATTLEFIELD_VOID(45), LIGHT_CURTAIN(47), SEAL_RED(48), YAOCHI_CLIFF(49)
```

---

## §8 宠物系统

```lua
-- 基础属性（1级）
maxHp = 40, atk = 5, def = 2
-- 每级成长
maxHp += 20, atk += 2, def += 2
-- 宠物攻击力 = 玩家ATK * 同步率
```

| 阶级 | 名称 | 等级上限 | 基础同步率 |
|------|------|---------|-----------|
| 0 | 幼犬 | 20 | **20%** |
| 1 | 灵犬 | 40 | **30%** |
| 2 | 妖犬 | 60 | **40%** |
| 3 | 灵兽 | 80 | 50% |
| 4 | **圣兽** | 100 | **60%** |

同步率 = 阶级基础 + 福缘加成（每25点+2%）+ 套装加成

---

## §9 Debuff 系统

| Debuff | 效果 | 来源 |
|--------|------|------|
| 中毒 | 每秒固定伤害，持续N秒 | 怪物技能 |
| 击晕 | 无法移动/攻击/释放技能 | 怪物技能 |
| 减速 | 降低移速和攻速（乘算） | 金刚掌/怪物技能 |
| 血煞印记 | 每层每秒扣%maxHP，不过期 | 挑战BOSS机制 |

---

## §10 装备图标视觉主题

| 阶 | 境界 | 材质主题 | 色调关键词 |
|----|------|---------|-----------|
| T1 | 凡人 | 铁、布、铜 | 朴素、灰褐 |
| T2 | 凡人 | 玄铁、皮革、银 | 深灰、棕色 |
| T3 | 练气 | 精钢、锻铁、金 | 银白、金色 |
| T4 | 练气 | 灵纹、玄铁、玉 | 青白、灵纹发光 |
| T5 | 筑基 | 青锋、寒铁、灵石 | 青色、寒光 |
| T6 | 金丹 | 金丹、紫金、丹晶 | 紫金、华贵 |
| T7 | 元婴 | 天蚕、元灵 | 空灵、缥缈 |
| T8 | 化神 | 星辰 | 星光、深邃蓝紫 |
| T9 | 合体 | 龙鳞、龙骨 | 龙纹、暗金 |
| T10 | 大乘 | 混元 | 混沌、多彩 |
| T11 | 渡劫 | 天劫 | 雷电、白金 |

---

*创建时间: 2026-04-27*
*数据来源: 全部数值与代码交叉验证（GameConfig.lua, EquipmentData.lua, Player.lua, LootSystem.lua, ForgeUI.lua, MonsterData.lua, ChapterConfig.lua, SaveState.lua, SaveKeys.lua, SkillData.lua, TileTypes.lua）*
