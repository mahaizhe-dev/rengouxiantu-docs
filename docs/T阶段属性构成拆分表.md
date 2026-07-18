# T阶段属性构成拆分表

## 1. 口径

本表按最新代码口径重整，不再把“角色成长 + 装备主轴”误当成完整面板构成。

- 代码基准：`rengouxiantu-docs` 最新 `origin/main`。
- 当前主线已覆盖到 `T11 = 仙1 = Lv121-140`。
- `T阶段基准` 只用于观察角色成长、装备主轴、仙阶奖励的基础比例。
- `最终属性构成` 必须按 `Player:GetTotal*()`、`SkillData.GetTotalKillHeal()`、`Player:TakeDamage()` 等真实公式拆。
- 随机装备、命格、酒槽、宠物赐主、称号、道印、瑶池、图鉴、丹药都不能再漏掉。
- 无上限或强条件来源单独列，不强行塞进固定上限表，避免把理论配置写成所有玩家必有。

当前代码里已经确认的特殊边界：

- 装备图鉴目前只有第1-5章，第6章图鉴条目尚未接入 `EquipmentData_Collection.lua`。
- 瑶池洗髓当前代码最高 `26级`，每级 `1%` 增伤与 `1%` 减伤；之前讨论的 49 级不是当前代码事实。
- `BadgeData.lua` 有徽章配置，但最终属性公式没有读取 `badge*` 字段；当前不计入有效构成。
- `ArtifactSystem_tiandi` 当前只开放 `6格`，虽然配置保留 `TOTAL_GRID_COUNT=9`，当前可达按 6 格计算。

## 2. 最终属性公式

以下为代码已经接线的真实字段。后续新增系统必须先放进这张表，再讨论是否进入阶段基准。

| 属性/效果 | 真实公式入口 | 已接线字段 |
| - | - | - |
| 攻击 | `Player:GetTotalAtk()` | `player.atk`、`equipAtk`、`collectionAtk`、`titleAtk`、`seaPillarAtk`、`swordPoolAtk`、`medalAtkFlat`、`artifactTiandiAtk`、`daoAtk`、`prisonTowerAtk`、`minggeAtk` |
| 攻击百分比 | `Player:_RecalcStatsCache()` | `titleAtkBonus`、高级外观 `skinBonuses.atkPct`、战斗Buff、`juexian._atkBonus` |
| 防御平值 | `Player:GetTotalDef()` | `player.def`、`equipDef`、`collectionDef`、`seaPillarDef`、`swordPoolDef`、`artifactCh4Defense`、`medalDefFlat`、`prisonTowerDef`、`minggeDef` |
| 防御百分比 | `Player:GetTotalDef()` | 根骨换算、`skinBonuses.defPct`、战斗Buff、`equipDefPercent`、`def_boost` 特效 |
| 生命平值 | `Player:GetTotalMaxHp()` | `player.maxHp`、`equipHp`、`collectionHp`、`seaPillarMaxHp`、`swordPoolMaxHp`、`medalHpFlat`、`daoMaxHp`、`prisonTowerMaxHp`、`minggeHp` |
| 生命百分比 | `Player:GetTotalMaxHp()` | 体魄换算、`skinBonuses.hpPct` |
| 生命恢复 | `Player:GetTotalHpRegen()` | `hpRegen`、`equipHpRegen`、`skillBonusHpRegen`、`collectionHpRegen`、`seaPillarHpRegen`、`swordPoolHpRegen`、`medalHpRegen`、`artifactTiandiHpRegen`、`prisonTowerHpRegen`、`minggeHpRegen`、体魄恢复换算 |
| 悟性 | `Player:GetTotalWisdom()` | `equipWisdom`、`artifactCh4Wisdom`、宠物赐主、`daoTreeWisdom`、`wineWisdom`、`medalWuxing`、职业成长、`collectionWisdom`、战斗Buff、`daoWisdom`、高级外观、`artifactCh5Wisdom`、`minggeWisdom` |
| 根骨 | `Player:GetTotalConstitution()` | `equipConstitution`、`pillConstitution`、`gangguConstitution`、`artifactConstitution`、职业成长、宠物赐主、`wineConstitution`、`medalGengu`、`collectionConstitution`、战斗Buff、`daoConstitution`、高级外观、`artifactCh5Constitution`、`minggeConstitution` |
| 体魄 | `Player:GetTotalPhysique()` | `equipPhysique`、`artifactPhysique`、宠物赐主、`pillPhysique`、`winePhysique`、`medalTipo`、`collectionPhysique`、战斗Buff、职业成长、`daoPhysique`、高级外观、`artifactCh5Physique`、`minggePhysique` |
| 福缘 | `Player:GetTotalFortune()` | `equipFortune`、`collectionFortune`、`artifactCh4Fortune`、`fruitFortune`、`pillFortune`、宠物赐主、`wineFortune`、`medalFuyuan`、战斗Buff、`daoFortune`、高级外观、`minggeFortune` |
| 暴击率 | `Player:GetTotalCritRate()` | 基础 `5%`、`equipCritRate`、`titleCritRate`、`collectionCritRate`、`wineCritRate`、`minggeCritRate` |
| 暴击伤害 | `Player:GetTotalCritDmg()` | 基础 `150%`、`equipCritDmg`、`minggeCritDmg`、陷仙特效、酒Buff |
| 重击值 | `Player:GetTotalHeavyHit()` | `equipHeavyHit`、`titleHeavyHit`、`artifactHeavyHit`、`collectionHeavyHit`、`minggeHeavyHit` |
| 天诛率 | `Player:GetTotalTianzhuChance()` | `equipTianzhuChance`、`minggeTianzhuChance` |
| 天诛伤害 | `Player:GetTotalTianzhuDmg()` | 基础 `150%`、`equipTianzhuDamage`、`minggeTianzhuDamage` |
| 击杀回血 | `SkillData.GetTotalKillHeal()` | `equipKillHeal`、`titleKillHeal`、`collectionKillHeal`、`pillKillHeal`、`artifactTiandiKillHeal`、`minggeKillHeal` |
| 技能伤害 | `Player:GetSkillDmgPercent()` + `equipSkillDmg` | 悟性换算、`equipSkillDmg` |
| 技能连击 | `Player:GetSkillComboChance()` | 悟性换算、职业被动、`equipComboChance` |
| 宠物同步率 | `Player:GetFortuneSyncBonus()` | 福缘换算、`equipPetSyncRate`、`minggePetSyncRate` |
| 减伤 | `Player:TakeDamage()` | `equipDmgReduce`、渊甲特效、宠物狂暴守护减伤、瑶池洗髓减伤 |
| 最终增伤 | `Monster:TakeDamage()` | 瑶池洗髓增伤、宠物狂暴伤害Buff、战斗Buff/技能流程 |
| 攻速 | `Player:GetAttackSpeed()` | 基础攻速、境界攻速、犬魂狂暴、`minggeAtkSpeed` |
| 移速 | `Player:Update()` | 基础移速、`equipSpeed`、犬魂狂暴、高级外观移速、`minggeSpeed` |

## 3. 丹药构成

### 3.1 炼丹炉永久丹

| 丹药 | 章节 | 接入字段 | 单颗 | 上限 | 满额 |
| - | -: | - | -: | -: | -: |
| 虎骨丹 | 1 | `player.maxHp` | HP +30 | 5 | HP +150 |
| 灵蛇丹 | 2 | `player.atk` | ATK +10 | 5 | ATK +50 |
| 金刚丹 | 2 | `player.def` | DEF +8 | 5 | DEF +40 |
| 千锤百炼丹 | 3 | `pillConstitution` | 根骨 +1 | 50 | 根骨 +50 |
| 龙血丹 | 4 | `player.maxHp` | HP +30 | 10 | HP +300 |
| 太虚剑丹 | 5 | `player.atk` | ATK +10 | 10 | ATK +100 |
| 狱甲丹 | 5 | `player.def` | DEF +8 | 10 | DEF +80 |

炼丹炉永久丹满额合计：

| ATK | DEF | HP | 根骨 |
| -: | -: | -: | -: |
| 150 | 120 | 450 | 50 |

### 3.2 挑战丹药

| 丹药 | 接入字段 | 单颗 | 上限 | 满额 |
| - | - | -: | -: | -: |
| 凝力丹 | `player.atk` | ATK +10 | 10 | ATK +100 |
| 凝甲丹 | `player.def` | DEF +8 | 10 | DEF +80 |
| 凝元丹 | `player.maxHp` | HP +30 | 10 | HP +300 |
| 凝魂丹 | `pillKillHeal` | 击杀回血 +40 | 10 | 击杀回血 +400 |
| 凝息丹 | `player.hpRegen` | 回复 +6/s | 10 | 回复 +60/s |
| 钢筋铁骨丹 | `gangguConstitution` | 根骨 +1 | 50 | 根骨 +50 |

挑战丹药满额合计：

| ATK | DEF | HP | 回复 | 击杀回血 | 根骨 |
| -: | -: | -: | -: | -: | -: |
| 100 | 80 | 300 | 60 | 400 | 50 |

### 3.3 封魔体魄丹

| 来源 | 接入字段 | 当前代码实际效果 | 上限 | 满额 |
| - | - | - | -: | -: |
| 封魔日常体魄丹 | `pillPhysique` | 直接 +1 体魄 | 100 | 体魄 +100 |

说明：`SealDemonConfig.PHYSIQUE_PILL` 里有 `bonusPerTen=2` 注释，但当前奖励、存档与 `Player:GetTotalPhysique()` 都是直接读写 `pillPhysique`，没有按“每10枚+2”二次换算。因此本文按实际代码满额 `体魄+100` 统计。

### 3.4 丹药总计

| 属性 | 当前可固定满额 |
| - | -: |
| ATK | 250 |
| DEF | 200 |
| HP | 750 |
| 回复 | 60 |
| 击杀回血 | 400 |
| 根骨 | 100 |
| 体魄 | 100 |

## 4. 装备图鉴构成

图鉴由 `CollectionSystem` 累加 `EquipmentData_Collection.lua` 的 `entries[*].bonus`。当前代码只到第5章。

| 累计到章节 | ATK | DEF | HP | 回复 | 击杀回血 | 重击 | 暴击率 | 悟性 | 根骨 | 体魄 | 福缘 |
| - | -: | -: | -: | -: | -: | -: | -: | -: | -: | -: | -: |
| Ch1 | 12 | 12 | 60 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 |
| Ch2 | 39 | 39 | 190 | 3 | 12 | 10 | 0 | 0 | 0 | 0 | 8 |
| Ch3 | 93 | 93 | 450 | 15 | 60 | 30 | 0 | 0 | 0 | 0 | 12 |
| Ch4 | 179 | 174 | 840 | 33 | 132 | 60 | 0 | 5 | 0 | 0 | 17 |
| Ch5 | 287 | 282 | 1360 | 56 | 236 | 100 | 0 | 5 | 10 | 10 | 23 |

判断：

- 图鉴不是边缘系统。到第5章时，它已经提供 `ATK+287 / DEF+282 / HP+1360 / 回复+56 / 击杀回血+236 / 重击+100`。
- 旧表只写到第4章且数值不一致，已经不能作为第六章构成依据。
- 第6章特殊装备图鉴如果后续接入，必须继续加到这张表，而不是只写在掉落文档。

## 5. 固定养成系统上限

### 5.1 海神柱与祀剑池

| 系统 | ATK | DEF | HP | 回复 |
| - | -: | -: | -: | -: |
| 海神柱，4柱10级 | 30 | 20 | 300 | 30 |
| 祀剑池，4剑10级 | 50 | 40 | 500 | 50 |
| 合计 | 80 | 60 | 800 | 80 |

### 5.2 神器系统

| 系统 | 当前可达 | ATK | DEF | HP | 回复 | 击杀回血 | 重击 | 悟性 | 根骨 | 体魄 | 福缘 |
| - | - | -: | -: | -: | -: | -: | -: | -: | -: | -: | -: |
| 上宝逊金钯 | 9格满 | 0 | 0 | 0 | 0 | 0 | 300 | 0 | 100 | 100 | 0 |
| 文王八卦盘 | 8格满 | 0 | 64 | 0 | 0 | 0 | 0 | 100 | 0 | 0 | 100 |
| 天帝剑痕 | 当前6格 | 60 | 0 | 0 | 6 | 27 | 0 | 0 | 0 | 0 | 0 |
| 诛仙阵图 | 9格满 | 0 | 0 | 0 | 0 | 0 | 0 | 100 | 100 | 100 | 0 |

天帝剑痕如果未来开放 9 格，理论满额会变为 `ATK+100 / 击杀回血+45 / 回复+10`，但当前代码只开放 6 格，阶段构成表不能提前按 9 格写。

### 5.3 镇狱塔

`PrisonTowerConfig.MAX_FLOOR = 150`，每 5 层给一次永久属性。

| 系统 | ATK | DEF | HP | 回复 |
| - | -: | -: | -: | -: |
| 镇狱塔150层满 | 120 | 90 | 1200 | 10 |

### 5.4 天道问心与悟道树

| 系统 | 字段 | 上限/规则 |
| - | - | - |
| 天道问心 | `daoAtk` / `daoMaxHp` / `daoWisdom` / `daoFortune` / `daoConstitution` / `daoPhysique` | 5题二选一，单属性最大通常为 `+10`，攻击分支 `+5`，生命分支 `+30`；不能所有分支同时取满 |
| 悟道树 | `daoTreeWisdom` | 悟性上限 `+100` |

### 5.5 仙阶

`AscensionConfig.BASE_REWARDS = HP+500 / ATK+100 / DEF+80 / 回复+10`，谪仙段系数为 1.0。

| 仙阶段 | 小阶 | 累计奖励 |
| - | -: | - |
| 谪仙1-9阶 | 9 | HP +1300 / ATK +260 / DEF +208 / 回复 +26 |

T11 表里角色成长项已经包含这部分仙阶奖励。

## 6. 条件/随机/开放系统

这些系统会进最终属性，但不应无脑并入“固定阶段上限”。

### 6.1 道印

| 道印 | 当前规则 | 加成 |
| - | - | - |
| 境界大师 | 大境界进度，最高8级 | HP +240 |
| 职业道印 | 对应职业每10级1级，最高10级 | 太虚悟性 +10 / 罗汉根骨 +10 / 镇岳体魄 +10 / 天衍福缘 +10 |
| 青云试炼 | 配置最高8级 | DEF +32 |
| 守护者 | 道具消耗型，`max_level=0` | 四维每级 +1，无硬上限 |
| 全服竞速 | 化神/合体前10名 | ATK +10 |
| 首获青/红 | 首次获得对应品质 | 回复 +2 |
| 事件道印 | 事件发放 | 福缘 +3 |

`守护者` 是开放成长轴，不能计入阶段固定总和。

### 6.2 称号

当前称号全解锁后常驻加成为：

| ATK | 暴击率 | 重击 | 击杀回血 | 经验加成 | 攻击百分比 |
| -: | -: | -: | -: | -: | -: |
| 15 | 1% | 100 | 60 | 1% | 1% |

称号由击杀、等级、白名单、挑战等条件解锁，属于条件轴。

### 6.3 美酒

当前美酒槽位为 3 个，因此最多同时装备 3 种酒。

| 类型 | 当前已接线效果 |
| - | - |
| 四维被动酒 | 根骨/悟性/体魄/福缘各有 `+25`，但只能按酒槽选择同时生效 |
| 被动暴击酒 | 暴击率 +8% |
| 饮酒Buff | 攻击 +10%、瞬回15%、暴伤 +30%、击退免疫、饮酒持续+3秒、每秒恢复强化等 |

美酒不是固定全量来源，必须按具体装备酒槽计算。

### 6.4 宠物赐主

宠物主人书是宠物技能轴，不占装备图鉴。

| 技能 | 最高特级效果 |
| - | -: |
| 灵兽通慧 | 悟性 +40 |
| 灵兽铸骨 | 根骨 +40 |
| 灵兽淬体 | 体魄 +40 |
| 灵兽赐福 | 福缘 +40 |

如果四本都学满，主人四维各 +40；如果技能未学或阶级不足，则按实际宠物技能结算。

### 6.5 高级宠物外观

高级外观是账号级解锁属性，不看当前装备的是哪一个外观；只要账号已解锁，就会通过 `skinBonuses` 汇总进最终公式。

| 外观 | 当前代码加成 |
| - | -: |
| 赤焰天犬 | 攻击百分比 +1% |
| 玄冰天犬 | 防御百分比 +1% |
| 樱华天犬 | 生命百分比 +1% |
| 瑞光天犬 | 福缘 +10 |
| 灵悟天犬 | 悟性 +10 |
| 磐岩天犬 | 根骨 +10 |
| 铁魄天犬 | 体魄 +10 |
| 疾风天犬 | 移速百分比 +1% |

封顶规则：

| 类型 | 封顶 |
| - | -: |
| 百分比类 `atkPct/defPct/hpPct/moveSpeedPct` | 单项最高 5% |
| 固定值类 `fortune/wisdom/constitution/physique` | 单项最高 50 |

这部分是有效属性来源，但它依赖账号解锁状态，不并入 T11 固定快照。

### 6.6 命格

命格是 15 个装备槽的独立随机装备轴。

- 主词条来源：`MinggeData.STAT_RANGES[tier][stat][quality]`。
- 当前命格只到 `T3`。
- 可接入字段包括：ATK、DEF、HP、回复、击杀回血、重击、暴击率、暴伤、移速、天诛率、天诛伤害、四维、宠物同步率。
- 青色命格 20% 概率带套装。
- 同一五行行内 3 件同套触发套装；5 行最多触发 5 次。

命格套装效果：

| 套装 | 每行触发 |
| - | -: |
| 青龙 | 攻速 +8% |
| 白虎 | 暴伤 +20% |
| 朱雀 | 天诛伤害 +20% |
| 玄武 | 宠物同步率 +8% |

### 6.7 瑶池洗髓

当前代码：

| 项 | 数值 |
| - | -: |
| 最高等级 | 26 |
| 每级效果 | 最终增伤 +1%，最终减伤 +1% |
| 满级效果 | 最终增伤 +26%，最终减伤 +26% |

瑶池不是面板平值来源，但它直接进入造成伤害与承受伤害的最终乘区，必须在战斗收益评估里单列。

### 6.8 装备随机轴

随机装备会通过 `InventorySystem/equip_stats` 接入：

- 主属性：`equipAtk / equipDef / equipHp / equipHpRegen / equipCritRate / equipDmgReduce / equipSpeed / equipWisdom / equipFortune / equipConstitution / equipPhysique` 等。
- 副属性：`equipSkillDmg / equipKillHeal / equipCritDmg / equipHeavyHit / equipTianzhuChance / equipTianzhuDamage / equipPetSyncRate` 等。
- 套装与特效：`equipComboChance / equipBloodRageChance / equipHeavyHitRate / equipDefPercent / equipSpecialEffects` 等。

第六章仙1装备窗口：

| 等级段 | 常规掉落Tier | 说明 |
| - | - | - |
| Lv121-140 | T9 / T10 / T11 | `T11 = 仙1` |

当前百分比副属性阶段目标：

| 阶段 | 百分比副属性目标 | 暴伤目标 |
| - | -: | -: |
| T7 | 3.8% | 19% |
| T8 | 4.6% | 23% |
| T9 | 5.2% | 26% |
| T10 | 6.0% | 30% |
| T11 / 仙1 | 6.6% | 33% |

## 7. 按章节累计过程表

本节恢复原表最重要的“逐章累计”过程。口径如下：

- 章节终点按当前主线装备阶段观察：`Ch1=T3/Lv15`、`Ch2=T5/Lv40`、`Ch3=T7/Lv70`、`Ch4=T9/Lv100`、`Ch5=T10/Lv120`、`Ch6=T11/仙1/Lv140`。
- 角色成长按代码实际升级次数：`初始值 + (Lv-1) × LEVEL_GROWTH + 本章终点境界奖励`；同等级下一大境界奖励不提前计入，例如 Ch5 的 Lv120 仍按大乘巅峰，Ch6 才计谪仙段。
- 白板装备按代码逐件 `floor(base × tierMult)`，不沿用旧表中 `11 × 倍率` 的小数写法。
- 本表只看关键五属性：`攻击 / 防御 / 生命 / 生命回复 / 击杀回血`。
- 不混入随机副属性、命格、酒槽、宠物赐主、称号、道印分支、高级外观、瑶池最终乘区。

### 7.1 章节累计总表

| 累计到章节 | 阶段 | ATK | DEF | HP | 回复 | 击杀回血 |
| - | - | -: | -: | -: | -: | -: |
| Ch1 | T3 / Lv15 | 112 | 73 | 673 | 9.2 | 0 |
| Ch2 | T5 / Lv40 | 433 | 314 | 1761 | 86.3 | 412 |
| Ch3 | T7 / Lv70 | 743 | 537 | 3214 | 123.1 | 460 |
| Ch4 | T9 / Lv100 | 1213 | 988 | 5832 | 206.7 | 532 |
| Ch5 | T10 / Lv120 | 1748 | 1473 | 8145 | 307 | 636 |
| Ch6 | T11 / 仙1 / Lv140 | 2281 | 1810 | 11028 | 352.9 | 663 |

说明：

- Ch6 当前没有第六章图鉴代码，图鉴仍按 Ch5 累计值计算。
- Ch6 表中计入当前已接线的中洲/仙阶固定轴：`天帝剑痕` 与 `镇狱塔150层`。
- Ch5 不计入 `天帝剑痕`，因为该系统语义是中洲/仙劫战场轴。

### 7.2 按构成层逐步累计

| 累计到章节 | 构成层 | ATK | DEF | HP | 回复 | 击杀回血 |
| - | - | -: | -: | -: | -: | -: |
| Ch1 | 角色等级+境界 | 67 | 40 | 358 | 6.2 | 0 |
| Ch1 | 白板装备主轴 | 33 | 21 | 105 | 3 | 0 |
| Ch1 | 丹药累计 | 0 | 0 | 150 | 0 | 0 |
| Ch1 | 装备图鉴累计 | 12 | 12 | 60 | 0 | 0 |
| Ch1 | 固定系统累计 | 0 | 0 | 0 | 0 | 0 |
| Ch1 | 合计 | 112 | 73 | 673 | 9.2 | 0 |
| Ch2 | 角色等级+境界 | 178 | 113 | 911 | 17.3 | 0 |
| Ch2 | 白板装备主轴 | 66 | 42 | 210 | 6 | 0 |
| Ch2 | 丹药累计 | 150 | 120 | 450 | 60 | 400 |
| Ch2 | 装备图鉴累计 | 39 | 39 | 190 | 3 | 12 |
| Ch2 | 固定系统累计 | 0 | 0 | 0 | 0 | 0 |
| Ch2 | 合计 | 433 | 314 | 1761 | 86.3 | 412 |
| Ch3 | 角色等级+境界 | 386 | 251 | 1947 | 38.1 | 0 |
| Ch3 | 白板装备主轴 | 114 | 73 | 367 | 10 | 0 |
| Ch3 | 丹药累计 | 150 | 120 | 450 | 60 | 400 |
| Ch3 | 装备图鉴累计 | 93 | 93 | 450 | 15 | 60 |
| Ch3 | 固定系统累计 | 0 | 0 | 0 | 0 | 0 |
| Ch3 | 合计 | 743 | 537 | 3214 | 123.1 | 460 |
| Ch4 | 角色等级+境界 | 667 | 491 | 3347 | 66.7 | 0 |
| Ch4 | 白板装备主轴 | 187 | 119 | 595 | 17 | 0 |
| Ch4 | 丹药累计 | 150 | 120 | 750 | 60 | 400 |
| Ch4 | 装备图鉴累计 | 179 | 174 | 840 | 33 | 132 |
| Ch4 | 固定系统累计 | 30 | 84 | 300 | 30 | 0 |
| Ch4 | 合计 | 1213 | 988 | 5832 | 206.7 | 532 |
| Ch5 | 角色等级+境界 | 900 | 720 | 4500 | 90 | 0 |
| Ch5 | 白板装备主轴 | 231 | 147 | 735 | 21 | 0 |
| Ch5 | 丹药累计 | 250 | 200 | 750 | 60 | 400 |
| Ch5 | 装备图鉴累计 | 287 | 282 | 1360 | 56 | 236 |
| Ch5 | 固定系统累计 | 80 | 124 | 800 | 80 | 0 |
| Ch5 | 合计 | 1748 | 1473 | 8145 | 307 | 636 |
| Ch6 | 角色等级+境界 | 1209 | 939 | 6043 | 115.9 | 0 |
| Ch6 | 白板装备主轴 | 275 | 175 | 875 | 25 | 0 |
| Ch6 | 丹药累计 | 250 | 200 | 750 | 60 | 400 |
| Ch6 | 装备图鉴累计 | 287 | 282 | 1360 | 56 | 236 |
| Ch6 | 固定系统累计 | 260 | 214 | 2000 | 96 | 27 |
| Ch6 | 合计 | 2281 | 1810 | 11028 | 352.9 | 663 |

固定系统累计说明：

| 章节 | 已计入固定系统 |
| - | - |
| Ch1-Ch2 | 无关键五属性固定系统 |
| Ch3 | 上宝逊金钯主要给重击/根骨/体魄，不进入本节五属性 |
| Ch4 | 海神柱 + 文王八卦盘防御 |
| Ch5 | Ch4固定系统 + 祀剑池 |
| Ch6 | Ch5固定系统 + 天帝剑痕 + 镇狱塔150层 |

### 7.3 阶段占比核心结论

核心判断：

- `攻击/防御/生命` 在 Ch3 之后重新回到角色成长主导；装备白板主轴占比持续下降，第六章只剩约 `8%~12%`。
- `回复` 不是装备主导属性；Ch2-Ch3 由丹药主导，Ch4 以后变成角色成长、丹药、图鉴、固定系统共同分摊。
- `击杀回血` 主要来自丹药和图鉴；第六章当前为丹药 `60.3%`、图鉴 `35.6%`、天帝剑痕 `4.1%`。
- 第六章如果新增特殊装备图鉴，最容易改变的是 `图鉴占比`；如果新增系统型养成，最容易改变的是 `固定系统占比`。

攻击占比：

| 章节 | 角色 | 装备 | 丹药 | 图鉴 | 固定系统 | 主导 |
| - | -: | -: | -: | -: | -: | - |
| Ch1 | 59.8% | 29.5% | 0% | 10.7% | 0% | 角色 59.8% |
| Ch2 | 41.1% | 15.2% | 34.6% | 9.0% | 0% | 角色 41.1% |
| Ch3 | 52.0% | 15.3% | 20.2% | 12.5% | 0% | 角色 52.0% |
| Ch4 | 55.0% | 15.4% | 12.4% | 14.8% | 2.5% | 角色 55.0% |
| Ch5 | 51.5% | 13.2% | 14.3% | 16.4% | 4.6% | 角色 51.5% |
| Ch6 | 53.0% | 12.1% | 11.0% | 12.6% | 11.4% | 角色 53.0% |

防御占比：

| 章节 | 角色 | 装备 | 丹药 | 图鉴 | 固定系统 | 主导 |
| - | -: | -: | -: | -: | -: | - |
| Ch1 | 54.8% | 28.8% | 0% | 16.4% | 0% | 角色 54.8% |
| Ch2 | 36.0% | 13.4% | 38.2% | 12.4% | 0% | 丹药 38.2% |
| Ch3 | 46.7% | 13.6% | 22.3% | 17.3% | 0% | 角色 46.7% |
| Ch4 | 49.7% | 12.0% | 12.1% | 17.6% | 8.5% | 角色 49.7% |
| Ch5 | 48.6% | 9.9% | 13.5% | 19.0% | 9.0% | 角色 48.6% |
| Ch6 | 51.6% | 9.6% | 11.0% | 15.5% | 12.3% | 角色 51.6% |

生命占比：

| 章节 | 角色 | 装备 | 丹药 | 图鉴 | 固定系统 | 主导 |
| - | -: | -: | -: | -: | -: | - |
| Ch1 | 53.2% | 15.6% | 22.3% | 8.9% | 0% | 角色 53.2% |
| Ch2 | 51.7% | 11.9% | 25.6% | 10.8% | 0% | 角色 51.7% |
| Ch3 | 60.6% | 11.4% | 14.0% | 14.0% | 0% | 角色 60.6% |
| Ch4 | 57.4% | 10.2% | 12.9% | 14.4% | 5.1% | 角色 57.4% |
| Ch5 | 55.2% | 9.0% | 9.2% | 16.7% | 9.8% | 角色 55.2% |
| Ch6 | 54.8% | 7.9% | 6.8% | 12.3% | 18.1% | 角色 54.8% |

回复占比：

| 章节 | 角色 | 装备 | 丹药 | 图鉴 | 固定系统 | 主导 |
| - | -: | -: | -: | -: | -: | - |
| Ch1 | 67.4% | 32.6% | 0% | 0% | 0% | 角色 67.4% |
| Ch2 | 20.0% | 7.0% | 69.5% | 3.5% | 0% | 丹药 69.5% |
| Ch3 | 31.0% | 8.1% | 48.7% | 12.2% | 0% | 丹药 48.7% |
| Ch4 | 32.3% | 8.2% | 29.0% | 16.0% | 14.5% | 角色 32.3% |
| Ch5 | 29.3% | 6.8% | 19.5% | 18.2% | 26.1% | 角色 29.3% |
| Ch6 | 32.8% | 7.1% | 17.0% | 15.9% | 27.2% | 角色 32.8% |

击杀回血占比：

| 章节 | 角色 | 装备 | 丹药 | 图鉴 | 固定系统 | 主导 |
| - | -: | -: | -: | -: | -: | - |
| Ch1 | - | - | - | - | - | 无 |
| Ch2 | 0% | 0% | 97.1% | 2.9% | 0% | 丹药 97.1% |
| Ch3 | 0% | 0% | 87.0% | 13.0% | 0% | 丹药 87.0% |
| Ch4 | 0% | 0% | 75.2% | 24.8% | 0% | 丹药 75.2% |
| Ch5 | 0% | 0% | 62.9% | 37.1% | 0% | 丹药 62.9% |
| Ch6 | 0% | 0% | 60.3% | 35.6% | 4.1% | 丹药 60.3% |

### 7.4 丹药关键五属性累计

| 累计到章节 | 已满丹药 | ATK | DEF | HP | 回复 | 击杀回血 |
| - | - | -: | -: | -: | -: | -: |
| Ch1 | 虎骨丹 | 0 | 0 | 150 | 0 | 0 |
| Ch2 | Ch1 + 灵蛇丹 + 金刚丹 + 凝力/凝甲/凝元/凝息/凝魂丹 | 150 | 120 | 450 | 60 | 400 |
| Ch3 | Ch2 + 千锤百炼丹 | 150 | 120 | 450 | 60 | 400 |
| Ch4 | Ch3 + 龙血丹 | 150 | 120 | 750 | 60 | 400 |
| Ch5 | Ch4 + 太虚剑丹 + 狱甲丹 | 250 | 200 | 750 | 60 | 400 |
| Ch6 | 当前无新增关键五属性丹药 | 250 | 200 | 750 | 60 | 400 |

### 7.5 装备图鉴关键五属性累计

| 累计到章节 | ATK | DEF | HP | 回复 | 击杀回血 |
| - | -: | -: | -: | -: | -: |
| Ch1 | 12 | 12 | 60 | 0 | 0 |
| Ch2 | 39 | 39 | 190 | 3 | 12 |
| Ch3 | 93 | 93 | 450 | 15 | 60 |
| Ch4 | 179 | 174 | 840 | 33 | 132 |
| Ch5 | 287 | 282 | 1360 | 56 | 236 |
| Ch6 | 287 | 282 | 1360 | 56 | 236 |

第六章特殊装备图鉴尚未接入代码；后续新增时必须先更新本表，再看第六章怪物与装备投放强度。

## 8. T11固定构成快照

下面只列“当前代码中有硬上限、且不依赖随机词条选择”的主要来源。命格、酒槽、宠物技能、称号、道印守护者、随机装备副词条不混入。

| 来源 | ATK | DEF | HP | 回复 | 击杀回血 | 重击 | 悟性 | 根骨 | 体魄 | 福缘 |
| - | -: | -: | -: | -: | -: | -: | -: | -: | -: | -: |
| 角色等级+境界奖励 | 1209 | 939 | 6043 | 115.9 | 0 | 0 | 0 | 0 | 0 | 0 |
| 仙1白板装备主轴 | 275 | 175 | 875 | 25 | 0 | 0 | 0 | 0 | 0 | 0 |
| 丹药满额 | 250 | 200 | 750 | 60 | 400 | 0 | 0 | 100 | 100 | 0 |
| 装备图鉴Ch5累计 | 287 | 282 | 1360 | 56 | 236 | 100 | 5 | 10 | 10 | 23 |
| 海神柱+祀剑池 | 80 | 60 | 800 | 80 | 0 | 0 | 0 | 0 | 0 | 0 |
| 神器固定满额 | 60 | 64 | 0 | 6 | 27 | 300 | 200 | 200 | 200 | 100 |
| 镇狱塔150层 | 120 | 90 | 1200 | 10 | 0 | 0 | 0 | 0 | 0 | 0 |
| 悟道树 | 0 | 0 | 0 | 0 | 0 | 0 | 100 | 0 | 0 | 0 |
| 固定合计 | 2281 | 1810 | 11028 | 352.9 | 663 | 400 | 305 | 310 | 310 | 123 |

这张表的意义是“不会再漏掉明确可拉满的固定来源”。它不是最终面板上限，因为最终面板还会继续叠加：

- 根骨带来的防御百分比。
- 体魄带来的生命百分比与每点 `0.3/s` 回复。
- 装备副属性、命格、酒、宠物赐主、称号、道印、高级宠物外观、瑶池等条件轴。

### 8.1 不并入上表但必须记账的硬上限

这些来源已经接入最终属性，但不是“所有玩家固定拉满”，所以不并入 T11 固定快照：

| 来源 | 可提供属性 | 不并入原因 |
| - | - | - |
| 天道问心 | 分支最高：攻击 +5 或生命 +30；四维分支单项最高 +10 | 题目分支互斥 |
| 道印守护者 | 四维每级 +1，当前配置无等级上限 | 开放式消耗轴 |
| 称号 | 全解锁可得攻击 +15、暴击率 +1%、重击 +100、击杀回血 +60、经验 +1%、攻击百分比 +1% | 依赖称号获取 |
| 美酒 | 四维酒各 +25、暴击酒 +8%、饮酒 Buff 若干 | 受酒槽与当前选择限制 |
| 宠物赐主 | 四维各最高 +40 | 依赖宠物技能学习与品阶 |
| 高级宠物外观 | 攻/防/血/移速百分比单项封顶 5%；四维固定值单项封顶 50 | 依赖账号外观解锁 |
| 命格 | 攻防血、回复、击杀回血、暴击、暴伤、重击、天诛、四维、宠物同步率、攻速等 | 随机装备轴 |
| 瑶池 | 最终增伤/减伤，当前代码最高各 +26% | 战斗最终乘区，不是面板平值 |

## 9. 当前漏算风险结论

旧表最大问题不是某个数字偏差，而是分类错误：

- 丹药不是小系统，满额已经给 `ATK+250 / DEF+200 / HP+750 / 回复+60 / 根骨+100 / 体魄+100 / 击杀回血+400`。
- 装备图鉴到第5章已经给 `ATK+287 / DEF+282 / HP+1360 / 回复+56`，不能只写成“后文补充”。
- 白板装备主轴按代码逐件取整，旧表中部分 `.5` 观察值不能继续作为真实装备值。
- 神器、镇狱塔、海神柱、祀剑池都已经是固定大副轴。
- 瑶池虽然不进面板平值，但直接进最终伤害/减伤乘区。
- 命格、酒、宠物赐主、称号、道印守护者、高级宠物外观是条件轴，必须写清楚，但不能按所有玩家固定满额计算。

后续更新第六章时，新增的第六章特殊装备图鉴、仙1装备副属性、仙1特殊装备套装、酒、神器碎片、青莲长生体，必须先归入本表对应来源，再讨论数值强度。

## 10. 相关代码

- `scripts/entities/Player.lua`
- `scripts/config/SkillData.lua`
- `scripts/config/PillRecipes.lua`
- `scripts/systems/ChallengeSystem.lua`
- `scripts/config/SealDemonConfig.lua`
- `scripts/systems/SealDemonSystem.lua`
- `scripts/network/SealDemonHandler.lua`
- `scripts/config/EquipmentData_Collection.lua`
- `scripts/systems/CollectionSystem.lua`
- `scripts/config/SeaPillarConfig.lua`
- `scripts/config/SwordPoolConfig.lua`
- `scripts/config/PrisonTowerConfig.lua`
- `scripts/systems/ArtifactSystem.lua`
- `scripts/systems/ArtifactSystem_ch4.lua`
- `scripts/systems/ArtifactSystem_tiandi.lua`
- `scripts/systems/ArtifactSystem_ch5.lua`
- `scripts/systems/DaoQuestionSystem.lua`
- `scripts/network/DaoTreeHandler.lua`
- `scripts/config/MedalConfig.lua`
- `scripts/config/TitleData.lua`
- `scripts/config/WineData.lua`
- `scripts/config/PetSkillData.lua`
- `scripts/config/PetAppearanceConfig.lua`
- `scripts/config/MinggeData.lua`
- `scripts/systems/YaochiWashSystem.lua`
- `scripts/config/BadgeData.lua`
