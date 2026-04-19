# 项目规则（永久生效）

> **「人狗仙途」修仙 RPG 智能体准则**
>
> 本文档是 AI 开发助手的行为规范与项目知识库。
> 丢失上下文后，**先完整阅读本文件**，再开始工作。

---

## ⚠️ 线上项目警告（最高优先级）

**本项目是一个已发布到 TapTap 的线上运营项目，拥有真实玩家和线上存档数据。**

**所有代码修改必须以不破坏线上数据为最高优先级。违反以下规则等同于线上事故：**

### 存档安全红线

```
🔴 绝对禁止（线上事故级别）：
  - 删除或重命名已有的存档字段（线上玩家存档会丢数据）
  - 修改 clientCloud/clientScore 的 key 名称（线上存档立即失效）
  - 修改已有属性的计算公式而不做兼容（线上玩家数值突变）
  - 修改品质/Tier 倍率表中已有的数值（线上装备属性突变）
  - 删除 SaveSystem.MIGRATIONS 中已有的迁移函数（旧版存档无法加载）
  - 修改 REALM_LIST 中已有境界的 order 值（排行榜排序错乱）
  - 修改 EXP_TABLE 中已有等级的经验值（玩家经验进度异常）
```

### 必须遵守的兼容性原则

```
✅ 新增字段：使用默认值兼容（旧存档无该字段时取默认值，如 sellCurrency=nil 默认金币）
✅ 修改计算公式：必须同时更新存档迁移，保证已有装备数据一致
✅ 新增属性/系统：SaveSystem.CURRENT_SAVE_VERSION 递增 + 写迁移函数
✅ 修改装备数据表：特殊装备（SpecialEquipment）的已有条目只允许新增字段，禁止修改已有字段值
✅ 数值平衡调整：仅允许修改怪物属性、掉落率、新增装备的数值，不碰已有装备公式
✅ 新增货币类型：sellCurrency 字段向后兼容（nil=金币，不影响旧装备）
```

### 高风险操作检查清单

**每次涉及以下文件的修改，必须逐项确认：**

| 文件 | 风险 | 必须检查 |
|------|------|---------|
| `GameConfig.lua` 常量 | 全局影响 | 搜索所有引用点，确认不影响线上数据 |
| `EquipmentData.lua` 倍率表 | 装备数值 | 只允许**新增** tier/品质，禁止修改已有数值 |
| `EquipmentData.lua` 特殊装备 | 存量装备 | 已有条目只允许新增字段，禁止修改已有字段值 |
| `SaveSystem.lua` 序列化 | 存档兼容 | 递增版本号 + 写迁移函数 + 旧字段保留 |
| `Player.lua` 属性计算 | 战斗平衡 | 确认公式变更对已有存档的影响 |
| `SkillData.lua` 技能参数 | 战斗平衡 | 已有技能参数修改需评估对线上玩家的影响 |
| `LootSystem.lua` 品质/货币 | 掉落平衡 | 灵韵售价公式、品质权重、Tier 门槛 |
| `REALM_LIST` / `EXP_TABLE` | 进度体系 | 只允许**末尾追加**，禁止插入或修改已有项 |

---

## 一、项目基础架构

### 1.1 项目概况

- **游戏名称**: 人狗仙途（开局一条狗）
- **类型**: 2D 俯视角修仙 RPG（NanoVG 渲染 + UrhoX UI）
- **屏幕方向**: 竖屏（portrait）
- **引擎**: UrhoX（基于 Urho3D 1.8 扩展）
- **语言**: Lua 5.4
- **地图**: 80x80 瓦片网格，每瓦片逻辑像素 128px
- **坐标系**: 瓦片坐标（浮点），(40.5, 40.5) 为第一章出生点
- **状态**: **线上运营中**（TapTap 已发布，有真实玩家数据）

### 1.2 目录结构

```
scripts/                    # 游戏代码（AI 工作区）
├── main.lua                # 入口文件
├── config/                 # 配置数据
│   ├── GameConfig.lua      # 全局常量（伤害公式、境界表、品质表）
│   ├── EquipmentData.lua   # 装备属性定义（槽位、倍率表、基础值、图鉴）
│   ├── MonsterData.lua     # 怪物定义（第一章）
│   ├── MonsterTypes_ch4.lua # 第四章怪物定义（八卦阵BOSS、龙BOSS）
│   ├── SkillData.lua       # 技能定义
│   ├── TileTypes.lua       # 瓦片类型枚举（全章节唯一 ID，Ch1:1-10 Ch2:11-17 Ch3:18-25 Ch4:26-39）
│   ├── UITheme.lua         # UI 主题常量
│   ├── ChapterConfig.lua   # 章节配置（地图尺寸、解锁条件）
│   ├── ActiveZoneData.lua  # 活跃区域数据（运行时全局入口）
│   ├── ZoneData.lua        # 第一章区域定义
│   ├── ZoneData_ch2.lua    # 第二章区域定义
│   ├── ZoneData_ch3.lua    # 第三章区域定义
│   ├── ZoneData_ch4.lua    # 第四章区域定义
│   ├── QuestData_ch4.lua   # 第四章任务数据
│   └── zones/              # 各区域详细配置
│       ├── chapter1-3/     # 第一至三章区域
│       └── chapter4/       # 第四章区域（13个：haven + 8卦阵 + 4龙岛）
├── core/                   # 核心模块
│   ├── GameState.lua       # 全局状态（player, pet, monsters, npcs...）
│   ├── EventBus.lua        # 事件总线（发布/订阅）
│   └── Utils.lua           # 工具函数
├── entities/               # 实体
│   ├── Player.lua          # 玩家（属性、碰撞、debuff、GetTotal* 方法）
│   ├── Pet.lua             # 宠物
│   └── Monster.lua         # 怪物
├── systems/                # 系统
│   ├── CombatSystem.lua    # 战斗（伤害计算、自动攻击、特效、DOT、Buff）
│   ├── LootSystem.lua      # 掉落（装备生成、品质权重、Tier 窗口、灵韵货币）
│   ├── InventorySystem.lua # 背包装备管理（双货币出售）
│   ├── SkillSystem.lua     # 技能系统
│   ├── SaveSystem.lua      # 云存档（序列化、版本迁移、多槽位）
│   ├── ProgressionSystem.lua # 境界突破
│   ├── QuestSystem.lua     # 任务系统
│   ├── CollectionSystem.lua # 图鉴系统
│   ├── TitleSystem.lua     # 称号系统
│   ├── ChallengeSystem.lua # 挑战副本
│   ├── SealDemonSystem.lua # 封魔系统（替代旧除魔系统）
│   ├── ArtifactSystem.lua  # 神器系统
│   ├── FortuneFruitSystem.lua # 福源果系统
│   ├── SeaPillarSystem.lua # 海柱系统（第四章）
│   ├── DaoTreeSystem.lua   # 道树系统（第四章）
│   ├── VersionGuard.lua    # 版本守卫（热更检测）
│   └── GameEvents.lua      # 游戏事件注册
├── rendering/              # 渲染
│   ├── WorldRenderer.lua   # 世界渲染（NanoVG 自定义 Widget）
│   ├── TileRenderer.lua    # 瓦片渲染
│   ├── EntityRenderer.lua  # 实体渲染
│   ├── EffectRenderer.lua  # 特效渲染
│   └── DecorationRenderers.lua # 装饰物渲染
├── ui/                     # UI 面板（基于 urhox-libs/UI）
│   ├── BottomBar.lua       # 底部操作栏（状态+技能+功能按钮）
│   ├── InventoryUI.lua     # 背包（双货币显示）
│   ├── CharacterUI.lua     # 角色面板
│   ├── EquipTooltip.lua    # 装备详情浮窗（灵韵/金币售价）
│   ├── ForgeUI.lua         # 洗练系统（为装备增加副属性）
│   ├── NPCDialog.lua       # NPC 对话
│   ├── GMConsole.lua       # GM 调试控制台
│   └── ...                 # 其他面板（共 34 个 UI 文件）
├── world/                  # 世界
│   ├── GameMap.lua         # 地图（瓦片数据、碰撞检测）
│   ├── Camera.lua          # 相机
│   ├── Spawner.lua         # 怪物刷新
│   └── ZoneManager.lua     # 区域管理（切换检测、提示）
└── network/
    └── CloudStorage.lua    # 云存储封装（clientCloud API）

assets/                     # 资源目录
├── Textures/               # 图片资源（怪物、NPC肖像、图标）
├── audio/                  # 音频资源
└── Fonts/                  # 字体

docs/                       # 设计文档
```

### 1.3 模块依赖关系

```
main.lua ── 初始化 UI / 创建游戏世界 / 主循环
  ├── GameState      ← 全局状态容器（所有模块读写）
  ├── EventBus       ← 事件解耦（player_attack, monster_death 等）
  ├── GameConfig     ← 常量配置（所有模块只读）
  ├── ActiveZoneData ← 当前章节区域数据（运行时唯一入口）
  ├── CombatSystem   → 监听 EventBus 事件，驱动伤害计算
  ├── LootSystem     → 掉落生成，依赖 EquipmentData + GameConfig
  ├── SaveSystem     → 云端序列化，依赖 CloudStorage
  └── WorldRenderer  → NanoVG 渲染，读取 GameState 绘制画面
```

### 1.4 章节系统

| 章节 | 名称 | 地图 | 区域数 | 解锁条件 | 出生点 |
|------|------|------|--------|---------|--------|
| 1 | 两界村 | 80x80 | 7 | 无 | (40.5, 40.5) |
| 2 | 乌家堡 | 80x80 | 5 | 筑基后期 + 第一章主线 | (7.5, 30.5) |
| 3 | 万里黄沙 | 80x80 | 12 | 金丹后期 + 第二章主线 | (40.5, 74.5) |
| 4 | 八卦海 | 80x80 | 13 | 化神后期 + 第三章主线 | (39.5, 39.5) |

**关键机制**:
- `ActiveZoneData` 是所有模块访问当前章节数据的**唯一入口**
- `RebuildWorld()` 是章节切换的统一入口，pcall 保护
- `TileTypes` 全章节 ID 唯一（Ch1: 1-10, Ch2: 11-17, Ch3: 18-25, Ch4: 26-39）

### 1.5 瓦片规格

| 属性 | 值 |
|------|---|
| 逻辑像素大小 | 128px（`GameConfig.TILE_SIZE`） |
| 地图尺寸 | 80x80 瓦片 |
| 坐标系 | 浮点瓦片坐标 |
| 不可行走 | MOUNTAIN(6), WATER(7), WALL(8), FORTRESS_WALL(11), SEALED_GATE(14), CRYSTAL_STONE(15), SAND_WALL(18), CORAL_WALL(29), ROCK_REEF(30), ICE_WALL(33), ABYSS_WALL(35), VOLCANO_WALL(37), DUNE_WALL(39) |

---

## 二、属性与战斗体系

### 2.1 核心伤害公式

```lua
-- GameConfig.CalcDamage(atk, def)
DMG = ATK^2 / (ATK + DEF) * random(0.9, 1.1)
-- 最小伤害 = 1
```

### 2.2 玩家属性完整体系

#### 2.2.1 基础战斗属性

| 属性 | 初始值 | 每级成长 | 计算公式 |
|------|--------|---------|---------|
| maxHp | 100 | +15 | `(base + equip + collection) * (1 + physiqueHpBonus)` |
| atk | 15 | +3 | `(base + equip + collection + title) * (1 + titleAtkBonus)` |
| def | 5 | +2 | `(base + equip + collection) * (1 + constitutionDefBonus)` |
| hpRegen | 1.0 | +0.2 | `base + equip + collection`（受体魄回血效率加成） |
| critRate | 5% | — | `0.05 + equip + title` |
| critDmg | 150% | — | `1.5 + equip` |
| speed | 0 | — | `equip`（百分比加成移速） |
| attackSpeed | 1.0 | — | `base + realmBonus + petBerserk`（减速debuff乘算） |
| dmgReduce | 0 | — | `equip`（上限75%） |

**属性来源汇总**（每个属性可能来自以下来源）：

| 来源 | 对应字段前缀 | 说明 |
|------|-------------|------|
| 基础 | `self.atk` | 等级成长获得 |
| 装备 | `self.equipAtk` | InventorySystem 汇总所有装备 |
| 图鉴 | `self.collectionAtk` | CollectionSystem 收录奖励累加 |
| 称号 | `self.titleAtk`, `self.titleAtkBonus` | TitleSystem 累加 |
| 丹药 | `self.pillKillHeal`, `self.pillConstitution` | ChallengeSystem 奖励 |
| 神器 | `self.artifactHeavyHit` 等 | ArtifactSystem 计算 |
| 福源果 | `self.fruitFortune` | 一次性交互物永久+1 |
| 境界 | `self.realmAtkSpeedBonus` | 每个境界的 attackSpeedBonus |

#### 2.2.2 仙元属性（四维属性）

| 属性 | 来源 | 核心效果 |
|------|------|---------|
| **福缘** fortune | 装备+图鉴+神器+福源果 | 击杀金币+N；每5点→2%概率+1灵韵；每25点→+2%宠物同步率 |
| **悟性** wisdom | 装备（主属性：专属槽） | 击杀经验+N；每5点→+1%技能伤害；每50点→+1%技能连击概率 |
| **根骨** constitution | 装备+丹药+神器+职业每级+1 | 每5点→+1%防御力；每25点→+1%重击伤害/+1%重击概率 |
| **体魄** physique | 装备 | 每5点→+1%生命上限；每10点→+1%回血效率；每25点→+1%血怒概率 |

**详细转换表**：

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
生命上限加成% = floor(totalPhysique / 5) * 0.01     -- 每5点+1%
回血效率加成% = floor(totalPhysique / 10) * 0.01    -- 每10点+1%
血怒概率加成 = floor(totalPhysique / 25) * 0.01     -- 每25点+1%
```

#### 2.2.3 装备属性字段完整清单

Player 身上由 InventorySystem 汇总写入的装备属性：

```lua
equipAtk, equipDef, equipHp, equipSpeed, equipHpRegen,
equipCritRate, equipDmgReduce, equipSkillDmg, equipKillHeal,
equipCritDmg, equipHeavyHit, equipFortune, equipWisdom,
equipConstitution, equipPhysique
```

**装备物品额外字段**（第四章新增）：
```lua
item.sellCurrency  -- "lingYun" 或 nil（nil=金币）
item.spiritStat    -- { stat="fortune", name="福缘", value=8 }（灵器+品质）
item.forgeStat     -- { stat="atk", name="攻击力", value=14.85 }（洗练附加）
```

#### 2.2.4 攻击速度与攻击间隔

```lua
-- 攻击速度 = 基础(1.0) + 境界加成 + 犬魂狂暴
attackSpeed = base + realmAtkSpeedBonus + petBerserkAtkSpeed
-- 减速debuff: attackSpeed *= (1 - slowAtkPercent)

-- 攻击间隔 = 基础间隔 / 攻击速度
attackInterval = AUTO_ATTACK_INTERVAL(1.0s) / attackSpeed
```

**境界攻速加成**（累计）：

| 境界 | 攻速加成 |
|------|---------|
| 凡人 | +0 |
| 练气 | +0.1 |
| 筑基 | +0.2 |
| 金丹 | +0.3 |
| 元婴 | +0.4 |
| 化神 | +0.5 |
| 合体 | +0.6 |
| 大乘 | +0.8 |
| 渡劫 | +1.0 |

### 2.3 普攻伤害流程

```
自动攻击（范围内1.5格最近怪物）
  ↓
damage = CalcDamage(GetTotalAtk(), monster.def)
  ↓
暴击判定 → damage * GetTotalCritDmg()
  ↓
噬魂增伤buff → damage + floor(damage * buffMult)（一次性消耗）
  ↓
monster:TakeDamage(damage)
  ↓
重击判定（职业被动10% + 根骨加成）
  → heavyDmg = floor(ATK + HeavyHit) * (1 + constitutionHeavyDmgBonus)
  → 可暴击，无视防御（直接TakeDamage，不走CalcDamage）
  ↓
裂地触发（每N次攻击必定重击，与概率重击独立）
  ↓
DOT触发（流血：概率施加，内置CD）
  ↓
裂风斩触发（20%概率，75%ATK额外伤害，走CalcDamage）
  ↓
灭影触发（暴击时50%概率，60%ATK额外伤害，内置CD 2s）
  ↓
神器被动（天蓬遗威：15%概率，50%ATK真实伤害，不走CalcDamage）
  ↓
血怒叠层（体魄概率触发，满5层引爆）
```

### 2.4 玩家受伤流程

```
monster:TakeDamage(damage) → player:TakeDamage(damage)
  ↓
闪避判定（踏云：10%概率完全闪避）
  ↓
减伤计算: damage *= (1 - min(dmgReduce, 0.75))
  ↓
护盾吸收（金钟罩）: 护盾优先扣血
  ↓
扣血 → 死亡判定
  ↓
蜃影判定（15%概率免死+1s无敌）
```

### 2.5 技能系统

| 技能 | 类型 | 解锁 | CD | 伤害 | 特殊效果 |
|------|------|------|-----|------|---------|
| 金刚掌 | melee_aoe | Lv.3 | 5s | 150%ATK | 减速20%/3s，范围1.5格 |
| 伏魔刀 | lifesteal | Lv.6 | 8s | 100%ATK | 吸血等量HP，前方矩形2×1格 |
| 金钟罩 | passive | 练气 | 60s | — | HP<50%自动触发，护盾=防御×4，8s |
| 血海翻涌 | aoe_dot | 专属装备 | 12s | T3:60%+10%/s×4s | 前方120°扇形 |
| 浩气领域 | ground_zone | 专属装备 | 15s | T3:5%ATK/s×7s | 自身回2%HP/s |
| 治愈 | buff | 法宝 | 30s | — | T1:每秒3%HP×10s（随葫芦升级增强） |

### 2.6 装备特效系统

| 特效名 | 类型 | 触发条件 | 效果 |
|--------|------|---------|------|
| 流血 | bleed_dot | 35%概率，CD 3s | 每秒8%ATK×3s，无视防御 |
| 裂风斩 | wind_slash | 20%概率 | 75%ATK额外伤害（走CalcDamage） |
| 噬魂 | lifesteal_burst | 击杀时，CD 1s | 回3%maxHP + 下一击+30%伤害(3s) |
| 裂地 | heavy_strike | 每20次攻击 | 必定重击（与概率重击独立） |
| 灭影 | shadow_strike | 暴击时50%，CD 2s | 60%ATK额外伤害 |
| 献祭光环 | sacrifice_aura | 永久 | 每秒5%ATK真实伤害，范围3格 |
| 踏云 | evade_damage | 10%概率 | 完全闪避一次伤害 |
| 蜃影 | death_immunity | 15%概率 | 免疫致命伤害 + 1s无敌 |

### 2.7 装备属性公式

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

**Tier 倍率表（普通属性 TIER_MULTIPLIER）**:
| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 2.0 | 3.0 | 4.5 | 6.0 | 8.0 | 10.5 | 13.5 | 17.0 | 21.0 | 25.0 |

**Tier 倍率表（百分比主属性 PCT_TIER_MULTIPLIER）**:
| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 4.0 | 5.0 | 6.0 | 7.0 | 8.0 | 9.0 |

**副属性倍率表（SUB_STAT_TIER_MULT）**:
| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 1.5 | 2.2 | 3.0 | 4.0 | 5.5 | 7.0 | 9.0 | 11.0 | 13.0 | 15.0 |

**百分比副属性倍率表（PCT_SUB_TIER_MULT）**:
| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 1.3 | 1.6 | 2.0 | 2.5 | 3.0 | 3.8 | 4.8 | 6.0 | 7.5 | 9.0 |

**品质倍率**:
| 品质 | 倍率 | 副属性条数 | 额外特性 |
|------|------|----------|----------|
| white 普通 | 1.0 | 0 | |
| green 良品 | 1.1 | 1 | |
| blue 精品 | 1.2 | 2 | |
| purple 极品 | 1.3 | 3 | |
| orange 稀世 | 1.5 | 3 | |
| cyan 灵器 | 1.8 | 3 | + 灵性属性（半值仙元） + sellCurrency="lingYun" |
| red 圣器 | 2.1 | 3 | + 灵性属性 + sellCurrency="lingYun" |
| gold 仙器 | 2.5 | 3 | + 灵性属性 + sellCurrency="lingYun" |
| rainbow 神器 | 3.0 | 3 | + 灵性属性 + sellCurrency="lingYun" |

### 2.7.1 灵韵货币与灵器机制

**第四章引入双货币系统**：

| 货币 | 字段 | 获取方式 | 用途 |
|------|------|---------|------|
| 金币（默认） | `sellCurrency = nil` | 击杀怪物、出售装备 | 洗练、商店 |
| 灵韵 | `sellCurrency = "lingYun"` | 出售灵器+品质装备、BOSS 概率掉落 | 高级消耗（待扩展） |

**灵器（cyan）品质特有机制**：

1. **灵性属性**（spiritStat）：额外的半值仙元属性（`floor(tier × qualityMult × 0.5)`）
2. **灵韵售价**：随机灵器 `sellPrice = max(1, tier - 4)`（T5=1, T6=2, ... T9=5）
3. **掉落限制**：仅 T9+ 可掉落灵器，且需怪物 Lv≥96（`TIER_QUALITY_GATE.cyan[9]=96`）
4. **掉落权重**：极低（T9 权重 cyan=1，对比 white=250, purple=25, orange=5）
5. **特殊装备波动**：灵器乘算范围 `{ 1.1, 0.3 }`（即 1.1 ~ 1.4）

**代码判断**：
```lua
-- 出售时判断货币类型
if item.sellCurrency == "lingYun" then
    -- 扣灵韵
else
    -- 扣金币（默认）
end
```

### 2.7.2 洗练系统（ForgeUI）

**洗练**为装备追加 1 条额外副属性（forgeStat）：

| 参数 | 说明 |
|------|------|
| 消耗 | 金币（T1=200 ~ T9=40000） |
| 规则 | 从副属性池随机选取，排除已有的 mainStat + subStats + forgeStat |
| 不排除 | spiritStat（灵性属性），可与洗练结果重复 |
| 数值 | 与副属性相同公式：`baseValue × SUB_STAT_TIER_MULT[tier] × random(0.8, 1.2)` |

### 2.8 装备槽位与主属性

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

**副属性池**（12种）：

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

### 2.9 掉落 Tier 窗口

**怪物等级**决定可掉落的装备阶级（滑动窗口）：

| 怪物等级 | 可掉落 Tier |
|---------|------------|
| 1-5 | T1 |
| 6-10 | T1, T2 |
| 11-15 | T1, T2, T3 |
| 16-24 | T2, T3, T4 |
| 25-39 | T3, T4, T5 |
| 40-54 | T4, T5, T6 |
| 55-69 | T5, T6, T7 |
| 70-84 | T6, T7, T8 |
| 85-99 | T7, T8, T9 |
| 100-119 | T8, T9, T10 |
| 120+ | T9, T10, T11 |

**窗口位置衰减**: 位置1(最低) x1.0, 位置2 x0.5, 位置3(最高) x0.2

**BOSS/精英**: 仅掉落窗口中最高的 2 个 Tier。

### 2.10 血怒系统

```lua
-- 触发条件：体魄属性提供的血怒概率（每25点+1%）
-- 叠层：普攻命中时，概率叠加血怒
-- 满 5 层引爆：伤害 = 玩家maxHP × 10%，无视防御（直接TakeDamage），可暴击
BLOOD_RAGE_MAX_STACKS = 5
BLOOD_RAGE_DETONATE_RATIO = 0.10
-- 怪物死亡时清除该怪物的血怒层数
```

### 2.11 职业系统

当前仅武僧（monk），被动"金刚体魄"：
- 重击率 +10%
- 每级 +1 根骨

### 2.12 宠物属性

```lua
-- 基础属性（1级）
maxHp = 40, atk = 5, def = 2
-- 每级成长
maxHp += 20, atk += 2, def += 2
-- 同步率 = 阶级基础 + 福缘加成
-- 宠物攻击力 = 玩家ATK * 同步率
```

| 阶级 | 名称 | 等级上限 | 基础同步率 |
|------|------|---------|-----------|
| 0 | 幼犬 | 20 | 10% |
| 1 | 灵犬 | 40 | 20% |
| 2 | 妖犬 | 60 | 35% |
| 3 | 灵兽 | 80 | 50% |
| 4 | 神兽 | 100 | 65% |

### 2.13 Debuff 系统

| Debuff | 效果 | 来源 |
|--------|------|------|
| 中毒 | 每秒固定伤害，持续N秒 | 怪物技能 |
| 击晕 | 无法移动/攻击/释放技能 | 怪物技能 |
| 减速 | 降低移速和攻速（乘算） | 金刚掌/怪物技能 |
| 血煞印记 | 每层每秒扣%maxHP，不过期 | 挑战BOSS机制 |

### 2.14 等级压制

```lua
-- 玩家等级 - 怪物等级 > 10 → 不掉经验、金币、宠物食物
```

### 2.15 怪物行为参数

| 参数 | 值 | 说明 |
|------|---|------|
| 仇恨范围 | 4.0 格 | 进入后怪物追击 |
| 脱离范围 | 8.0 格 | 超出后怪物放弃 |
| 攻击距离 | 1.5 格 | 进入后开始攻击 |
| 巡逻速度 | 1.5 格/s | |
| 追击速度 | 3.0 格/s | |
| 回巢加速 | ×1.5 | |
| 脱战回血 | 1%maxHP/s | |
| 领地半径 | 普通6/精英10/BOSS16/王BOSS20 |

### 2.16 怪物数值公式

#### 基础属性公式

```lua
baseHp  = 50 + level * 50
-- Lv.60+ 二次HP成长（高等级怪物更耐打）
if level > 60 then
    baseHp = baseHp + (level - 60)^2 * 5   -- K=5, 起点=60
end
baseAtk   = 5  + level * 2.5
baseDef   = 2  + level * 2
baseSpeed = 1.2 + level * 0.1
```

#### 最终属性公式

```
finalStat = base × 阶级倍率 × 种族修正 × 境界系数
finalExp  = baseExp × 阶级经验倍率 × 境界经验系数
```

#### 阶级倍率表

| 阶级 | HP | ATK | DEF | Speed | EXP | Gold |
|------|-----|-----|-----|-------|-----|------|
| normal 小怪 | 1 | 1 | 1 | 1 | 1 | 1 |
| elite 精英 | 2 | 1.2 | 1.2 | 1.2 | 2 | 2 |
| boss BOSS | 5 | 1.3 | 1.3 | 1.3 | 5 | 5 |
| king_boss 王级 | 10 | 1.5 | 1.5 | 1.5 | 10 | 10 |
| emperor_boss 皇级 | **20** | 1.8 | 1.8 | 1.6 | 20 | 20 |
| saint_boss 圣级 | **50** | 2.5 | 2.5 | 2.0 | 50 | 50 |
| world_boss 世界BOSS | **50×4=200** | 2.5 | 2.5 | 2.0 | 0（不掉经验） | 0（不掉金币） |

> **世界BOSS 特殊规则**：
> - 使用圣级系数，血量额外 ×4
> - 不掉落经验和金币（奖励通过副本结算灵韵发放）
> - 不回复血量（无自然回血）
> - 固定时间刷新，刷新时无论老 BOSS 是否存活，强制替换为新 BOSS
> - 资源/技能复用八卦阵BOSS文王（文王仙魂）
>
> **世界BOSS 刷新时间表**（每 3 小时，从 0:00 开始）：
> | 序号 | 刷新时间 |
> |------|---------|
> | 1 | 00:00 |
> | 2 | 03:00 |
> | 3 | 06:00 |
> | 4 | 09:00 |
> | 5 | 12:00 |
> | 6 | 15:00 |
> | 7 | 18:00 |
> | 8 | 21:00 |
>
> 刷新间隔由 `DungeonConfig.bossRespawnInterval = 10800`（3小时 = 10800秒）控制。
> 服务端在 BOSS 被击杀后启动倒计时，到期后自动刷新新 BOSS。
> 若 BOSS 未被击杀，则持续存活直到被击杀后再启动倒计时。

#### 境界系数（statMult）

化神前：小境界步进 +0.10，大境界步进 +0.20
化神后（order≥13）：小境界步进 +0.15，大境界步进 +0.30

```
statMult = 1.1 + order × 0.1 + (majorCount - 1) × 0.1
-- 化神+(order>=13)追加：+ extraOrders × 0.05 + extraMajors × 0.05
```

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

境界经验系数（rewardMult）= `1.0 + order × 0.2`（不受化神加速影响）

---

## 三、图片生产规范

### 3.1 装备图标规范

**所有装备图标必须严格遵循以下规范，违反将导致返工。**

#### 硬性要求

| 项目 | 规范 |
|------|------|
| 尺寸 | 64x64 像素 |
| 格式 | PNG |
| 背景 | **透明**（`transparent: true`） |
| 宽高比 | 1:1 |

#### 画面内容要求（红线）

```
必须满足：
  - 纯物品渲染，仅展示装备本体
  - 透明背景，无任何底色/底板/光圈
  - 物品居中，占画面 70%-85%

绝对禁止：
  - 文字（名称、等级、数值、标签）
  - UI 元素（边框、品质框、角标、按钮）
  - 装饰背景（纯色底、渐变底、场景底）
  - 人物/手部（不要出现角色持握装备）
  - emoji 或符号
```

#### Prompt 模板

```
"{装备中文描述},仙侠修仙风格,纯物品渲染,无文字无UI,透明背景"
```

**generate_image 参数**：

```json
{
  "prompt": "{装备描述},仙侠修仙风格,纯物品渲染,无文字无UI,透明背景",
  "name": "icon_t{tier}_{slot}",
  "target_size": "64x64",
  "aspect_ratio": "1:1",
  "transparent": true
}
```

#### 文件命名规则

| 类型 | 命名格式 | 示例 |
|------|---------|------|
| T1 制式装备 | `icon_{slot}.png` | `icon_weapon.png` |
| T2+ 制式装备 | `icon_t{tier}_{slot}.png` | `icon_t3_armor.png` |
| 独特/BOSS 装备 | `icon_{唯一标识}.png` | `icon_boar_king_weapon.png` |
| 套装装备 | `icon_{套装名}_{slot}.png` | `icon_tiger_set_weapon.png` |

**slot 取值**（12 种）：
`weapon` `helmet` `armor` `shoulder` `belt` `boots` `ring` `necklace` `cape` `treasure` `exclusive` `pants`

> 注意：ring1/ring2 共用 `ring` 图标，不区分左右。

#### 各阶视觉主题

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

#### 生成流程

```
1. 确认阶级主题（查上表）
   ↓
2. 按模板组装 prompt
   ↓
3. 调用 generate_image / batch_generate_images
   参数: target_size="64x64", transparent=true
   ↓
4. 复制到正确文件名
   cp icon_t5_weapon_20260306164650.png icon_t5_weapon.png
   ↓
5. 删除带时间戳的临时文件
   rm icon_t5_*_202603*.png
   ↓
6. 构建验证
```

#### 批量注意事项

- batch_generate_images 单次最多 10 张，超出需分批
- 同一批次的装备应保持**风格一致**（同阶同主题）
- 每批生成后**立即复制+清理**，不要堆积临时文件

#### 素材覆盖范围

当前已有素材：T1 ~ T5（含独特装备）。
`LootSystem.GetSlotIcon` 中 `math.min(tier, N)` 的上限 N 必须与实际素材保持一致。
新增某阶图标后，同步更新该上限值。

### 3.2 NPC 肖像规范

| 项目 | 规范 |
|------|------|
| 尺寸 | 256x256 像素 |
| 格式 | PNG |
| 背景 | **透明**（`transparent: true`） |
| 宽高比 | 1:1 |
| 画风 | **像素风**，Q版卡通，全身站立 |

#### Prompt 模板

```
"{服饰描述},{角色特征/动作},全身站立,像素风格,Q版卡通风格,无背景,透明,干净简洁"
```

**generate_image 参数**：

```json
{
  "prompt": "{描述},像素风格,Q版卡通风格,全身站立,无背景,透明,干净简洁",
  "name": "npc_{英文id}",
  "target_size": "256x256",
  "aspect_ratio": "1:1",
  "transparent": true
}
```

#### 文件命名

- 格式: `npc_{english_id}.png`
- 存放: `assets/Textures/npc_{id}.png`

#### 禁止事项

```
❌ 任何背景（纯色、渐变、场景）
❌ UI 元素、水印
❌ 半身像（必须全身）
❌ 尺寸不是 256x256
```

### 3.3 怪物图片规范

| 项目 | 规范 |
|------|------|
| 尺寸 | 256x256 像素 |
| 格式 | PNG |
| 背景 | **透明** |
| 命名 | `monster_{english_id}.png` |
| 存放 | `assets/Textures/monster_{id}.png` |

### 3.4 瓦片贴图规范（后续增加时遵循）

| 项目 | 规范 |
|------|------|
| 尺寸 | 128x128 像素（与 TILE_SIZE 一致） |
| 格式 | PNG |
| 背景 | **不透明**（瓦片需要填满） |
| 命名 | `{tile_type_name}.png`（如 `battlefield_tile.png`） |
| 存放 | `assets/Textures/` |
| 风格 | 俯视角，可无缝拼接 |

---

## 四、存档规范

### 4.1 存档版本

```lua
SaveSystem.CURRENT_SAVE_VERSION = 10  -- 当前版本
SaveSystem.MAX_SLOTS = 4              -- 角色槽位数
SaveSystem.AUTO_SAVE_INTERVAL = 120   -- 自动存档间隔（秒）
SaveSystem.CHECKPOINT_INTERVAL = 5    -- 每 N 次存档写一次定期备份
```

### 4.2 数据架构（三 key 分离）

| key | 内容 | 大小 |
|-----|------|------|
| `save_data_{slot}` | 核心数据（player, equipment, pet, skills, collection, quests, titles, shop, challenges...） | ~5-8 KB |
| `save_bag1_{slot}` | 背包 1-30 格 | ~1-5 KB |
| `save_bag2_{slot}` | 背包 31-60 格 | ~1-5 KB |
| `slots_index` | 槽位元数据（名称、等级、境界） | ~0.5 KB |

**clientScore API 限制**:
- 单个 value 上限: **10 KB**（超出静默失败）
- 读写频率: 300 次 / 60 秒

### 4.3 备份层级

```
login_*       ← 登录时自动备份（最安全，不会被覆写）
save_prev_*   ← 每 5 次存档写一次（~10 分钟周期）
bak_*         ← 删角色前备份
save_data_*   ← 当前存档（最新，可能不完整）
```

### 4.4 排行榜分数编码

```lua
rankScore = realmOrder * 1000 + level
-- 例: 练气初期 Lv.15 → 1 * 1000 + 15 = 1015
```

### 4.5 版本迁移规则

**修改存档数据结构时必须**:

1. `CURRENT_SAVE_VERSION` 递增
2. 在 `MIGRATIONS` 表中注册 `[新版本号]` 迁移函数
3. 迁移函数必须处理所有可能的旧数据格式
4. **不可删除**已有迁移函数（旧版存档需要逐级迁移）
5. 迁移后必须设置 `data.version = 新版本号`

**当前迁移链**: v1 → v2 → v3 → v4 → v5 → v6 → v7 → v8 → v9 → v10

### 4.6 序列化字段裁剪

- **已装备物品**: 保留全字段（`SerializeItemFull`），存入 coreData
- **背包物品**: 裁剪冗余字段（`SerializeItem`），省略可推导的 name/icon/sellPrice
- **反序列化**: `fillEquipFields()` 从配置表恢复被裁剪的字段

### 4.6.1 配对字段同步规则 🔴

**语义上成对的字段，在序列化/反序列化/fillEquipFields 中必须作为整体同步，禁止独立判断。**

违反此规则会导致旧存档加载后字段交叉污染（一半是旧值，一半是新值）。

**已知配对字段**：

| 配对 | 字段 A | 字段 B | 错误后果 |
|------|--------|--------|---------|
| 售价 | `sellPrice` | `sellCurrency` | 旧存档 1000 金币 + 新模板灵韵 = 售价 1000 灵韵 |

**规则**：
1. 特殊装备（`isSpecial=true`）：`fillEquipFields` 中从模板恢复时，**始终覆盖**配对字段的全部成员，不做 `if not` 单独守旧
2. 新增配对字段时，必须检查序列化（`SerializeItem`）和反序列化（`fillEquipFields`）双向一致
3. 新增货币类型/售价体系时，必须检查旧存档中已持有装备的兼容性

```lua
-- ✅ 正确：配对字段整体同步
if specialTpl then
    itemData.sellPrice = specialTpl.sellPrice or 100
    itemData.sellCurrency = specialTpl.sellCurrency
end

-- ❌ 错误：各自独立判断，旧值和新值交叉
if not itemData.sellPrice then ... end          -- 旧值保留
if not itemData.sellCurrency then ... end       -- 新值补入
```

**检查清单**（新增/修改装备字段时自查）：
- [ ] 该字段是否与其他字段构成语义配对？
- [ ] `fillEquipFields` 中是否作为整体恢复？
- [ ] 旧存档加载后，配对字段的组合是否合理？

*规则创建时间: 2026-03-29 — 原因: sellPrice/sellCurrency 独立判断导致旧存档灭影武器显示"售价 1000 灵韵"*

### 4.7 安全检查

```lua
-- 本地安全阀：防止空白数据覆盖云端高级存档
if cloudLevel > 10 and currentLevel <= 1 then
    -- 阻止存档，触发 "save_blocked" 事件
end
```

---

## 五、操作规范

### 5.1 禁止自动发布 TapTap

**永久禁止不是用户主动要求的发布 TapTap。**

- 只有当用户**明确说出**"发布到 TapTap"、"发布 TapTap"、"上架 TapTap" 等类似请求时，才可以调用 `publish_to_taptap` 工具
- 构建（build）和生成测试二维码（generate_test_qrcode）不受此规则限制
- AI **绝对不得**在没有用户明确指令的情况下主动发起 TapTap 发布
- 违反此规则视为严重错误

### 5.2 文件删除操作规范

**文件删除是不可逆操作。必须以不可逆操作的标准执行，违反视为严重事故。**

#### 绝对前提

```
删除前必须满足全部条件：
  1. 备份 — 将待删文件移到临时目录（如 .tmp/backup/），而非直接 rm
  2. 交叉验证引用 — 至少用两种以上方式确认文件未被引用
  3. 用户确认 — 列出完整删除清单，等用户明确同意后才执行
```

#### 引用检查方法（必须交叉使用，不得只用一种）

| 方法 | 能检测到 | 不能检测到 |
|------|---------|-----------|
| 静态 grep 文件名 | 直接字符串引用 | 字符串拼接、动态加载 |
| grep 文件名片段 | 部分拼接（如 `"icon_t"`) | 完全动态构造 |
| 搜索目录/前缀模式 | 批量加载模式 | — |
| 代码逻辑分析 | 所有引用方式 | — |

**必须执行的检查项**：
```
✅ grep 完整文件名（如 "icon_t2_weapon.png"）
✅ grep 文件名的组成片段（如 "icon_t"、"_weapon"）
✅ grep 字符串拼接模式（如 '.. "icon'、'"icon_t" ..'）
✅ 阅读相关业务代码，理解资源加载逻辑
```

#### 操作流程

```
1. 分析 — 列出候选删除文件
   ↓
2. 交叉验证 — 用上述至少三种方法检查引用
   ↓
3. 备份 — mv 到 .tmp/backup/（不是 rm）
   ↓
4. 提交清单 — 将完整文件列表展示给用户确认
   ↓
5. 用户确认 — 等待用户明确同意
   ↓
6. 构建验证 — build 并确认无报错
   ↓
7. 运行验证 — 确认游戏功能正常后，再清理备份
```

#### 禁止事项

```
❌ 直接 rm 删除任何资源文件
❌ 只用一种 grep 方式就判定"未引用"
❌ 未经用户确认就批量删除
❌ 一次性删除超过 10 个文件而不分批验证
❌ 删除后不立即构建验证
```

#### 事故定义

- 删除了被动态引用的文件
- 删除了无法恢复的文件且未做备份
- 用户明确警告过"不要误删"仍然误删

### 5.3 图像资源生成规范

**生成图像资源（角色贴图、图标、怪物图等）时，未经用户确认，不得主动修改游戏代码将其接入游戏。**

#### 原则

```
✅ 允许：生成图片 → 保存到 assets/ → 展示给用户确认
❌ 禁止：生成图片后直接修改代码引用、修改配置、执行构建

正确流程：
  1. 生成图片资源
  2. 展示给用户预览
  3. 等待用户确认满意
  4. 用户明确要求后，才修改代码接入游戏
```

#### 禁止事项

```
❌ 生成图片后自动修改 GameConfig / EntityRenderer 等代码
❌ 生成图片后自动复制到 Textures/ 并替换现有资源
❌ 生成图片后自动执行 build
❌ 用户未确认图片质量就开始接入工作
```

### 5.4 代码修改规范

```
修改代码后必须：
  1. 调用 build 工具构建验证
  2. 确认无 LSP 报错
  3. 关联修改不遗漏（改了数据结构 → 检查序列化/反序列化）
```

**高风险修改**（必须额外谨慎）：

| 类型 | 风险 | 检查项 |
|------|------|--------|
| 修改 GameConfig 常量 | 影响全局平衡 | 搜索所有引用点 |
| 修改 EquipmentData 属性公式 | 影响存量装备 | 考虑是否需要存档迁移 |
| 修改 SaveSystem 序列化 | 可能破坏存档 | 递增版本号 + 写迁移函数 |
| 修改 fillEquipFields 字段恢复 | 旧存档字段交叉污染 | 配对字段必须整体同步（§4.6.1） |
| 新增装备字段（sellCurrency 等） | 旧存档无此字段 | 检查 fillEquipFields 恢复逻辑 + 旧存档兼容 |
| 修改 Player 属性计算 | 影响战斗平衡 | 检查 CombatSystem 依赖 |
| 新增/删除文件 | 引用断裂 | 检查所有 require 路径 |

### 5.5 问题处理原则（最高优先级）

**面对任何问题，必须正面分析根因，严禁第一时间回避问题、绕行其他方案。**

#### 核心规则

```
🔴 遇到问题时的强制流程：

  1. 正面分析 — 先分析问题本身的根因，提出直接解决方案
  2. 验证排查 — 逐步排查可能的原因，不要跳过任何可能性
  3. 反复论证 — 只有在多次尝试、充分论证后确认问题无法正面解决时
  4. 协商替代 — 才可以与用户协商是否启用替代方案

  ❌ 绝对禁止：
  - 遇到问题就绕过去，直接提出替代方案
  - 未经分析就假设"这个做不到"
  - 用错误的假设掩盖真实原因（如"PC 不支持多人预览"）
  - 修改用户的配置/代码来"回避"问题而非解决问题
```

#### 反面案例

```
❌ 预览打不开 → 直接说"PC 不支持多人" → 改成单机模式
✅ 预览打不开 → 分析原因（CDN 过期？构建失败？配置错误？）→ 尝试重新构建 → 确认根因
```

#### 规则来源

2026-03-25 — 原因：预览界面无法进入时，错误地假设"PC 不支持多人预览"，直接将多人配置改为单机以回避问题，而实际原因仅是 CDN 上传过期，重新构建即可恢复。

### 5.6 禁止硬编码

**所有数值、配置、阈值必须定义在配置模块中，逻辑代码中禁止出现硬编码的魔法数字/字符串。**

#### 原则

```
❌ 禁止：在逻辑代码中直接写死数值
✅ 必须：数值定义在 config/ 下的配置模块，逻辑代码通过变量引用
```

#### 示例

```lua
-- ❌ 错误：硬编码
if player.level >= 120 then return { 9, 10, 11 } end
if distance < 4.0 then state = "chase" end
local dmg = atk * 1.5
local maxSlots = 60

-- ✅ 正确：引用配置
if player.level >= GameConfig.MAX_LEVEL then ... end
if distance < GameConfig.MONSTER_AGGRO_RANGE then state = "chase" end
local dmg = atk * skillData.damageMultiplier
local maxSlots = GameConfig.INVENTORY_MAX_SLOTS
```

#### 适用范围

| 类别 | 放在哪里 | 示例 |
|------|---------|------|
| 战斗数值 | `GameConfig.lua` | 攻击间隔、仇恨范围、减伤上限 |
| 装备数据 | `EquipmentData.lua` | Tier 倍率、槽位基础值、副属性池 |
| 怪物参数 | `MonsterData.lua` / `zones/` | 血量、攻击力、掉落表 |
| 技能参数 | `SkillData.lua` | CD、伤害倍率、持续时间 |
| UI 常量 | `UITheme.lua` | 颜色、字号、间距 |
| 存档参数 | `SaveSystem.lua` 常量区 | 版本号、槽位数、自动存档间隔 |

#### 例外（允许硬编码）

- 数学常量：`0`、`1`、`0.5`、`2 * math.pi` 等
- 自然语义明确的值：`i = 1`、`count + 1`、`#list > 0`
- 单次临时调试代码（提交前必须清理）

---

## 六、发布流程规范

### 6.1 发布前检查清单（每次发布自动执行）

```
发布前必须完成：
  ✅ 竖屏模式 — screen_orientation 设为 "portrait"
  ✅ GM 工具关闭 — GameConfig.GM_ENABLED = false
  ✅ 不上传物料 — 不调用 upload_game_material（图标、截图、宣传图均不动）
  ✅ 构建通过 — build 无报错
```

### 6.2 具体操作

**竖屏模式**：
- 检查 `.project/project.json` 的 `taptap_publish.screen_orientation`
- 如果不是 `"portrait"`，改为 `"portrait"`

**GM 工具关闭**：
- 检查 `scripts/config/GameConfig.lua` 的 `GameConfig.GM_ENABLED`
- 如果不是 `false`，改为 `false`

**物料不变**：
- 发布时**禁止**调用 `upload_game_material`
- 线上图标、截图、宣传图保持现状，不更新
- 只有用户**明确要求**更换物料时才上传

### 6.3 执行要求

- 每次发布前**自动执行**，不需要用户提醒
- 检查结果简要报告即可，不需要逐项询问用户

### 6.4 版本号管理

```lua
GameConfig.CODE_VERSION = 4  -- 每次发版递增
```

- 修改存档结构或重大更新时 `CODE_VERSION += 1`
- 用于版本守卫（`VersionGuard.lua`）前向校验

---

## 七、上下文恢复指南

**当 AI 丢失上下文后，按以下顺序恢复**：

```
1. 完整阅读本文件（docs/rules.md）
   ↓
2. 阅读 scripts/config/GameConfig.lua（全局常量）
   ↓
3. 阅读 scripts/main.lua 前 100 行（模块导入列表）
   ↓
4. 根据任务类型，阅读相关模块
   ↓
5. 开始工作
```

**快速定位**:

| 要改的功能 | 看哪些文件 |
|-----------|-----------|
| 战斗数值 | GameConfig.lua, CombatSystem.lua, Player.lua |
| 装备属性 | EquipmentData.lua, LootSystem.lua |
| 装备洗练 | ForgeUI.lua, EquipmentData.lua |
| 灵韵货币/出售 | InventorySystem.lua, InventoryUI.lua, EquipTooltip.lua, LootSystem.lua |
| 怪物配置（Ch1-3） | MonsterData.lua, zones/ 下对应文件 |
| 怪物配置（Ch4） | MonsterTypes_ch4.lua, zones/chapter4/ |
| 存档相关 | SaveSystem.lua, CloudStorage.lua |
| UI 面板 | ui/ 下对应文件, UITheme.lua |
| 地图/区域 | ZoneData*.lua, TileTypes.lua, GameMap.lua |
| 任务系统 | QuestSystem.lua, QuestData*.lua, QuestData_ch4.lua |
| 境界突破 | ProgressionSystem.lua, GameConfig.REALMS |
| 宠物系统 | Pet.lua, PetSkillData.lua, PetPanel.lua |
| 技能系统 | SkillData.lua, SkillSystem.lua |
| 图鉴/称号 | CollectionSystem.lua, TitleSystem.lua, EquipmentData.Collection |
| 挑战副本 | ChallengeSystem.lua, ChallengeConfig.lua |
| 封魔系统 | SealDemonSystem.lua |
| 第四章海柱/道树 | SeaPillarSystem.lua, DaoTreeSystem.lua |

---

## 八、日常系统安全规范（C2S 请求防刷）

> **规则创建时间**: 2026-04-02
> **触发事件**: 试炼供奉（HandleTrialClaimDaily）存在三重漏洞，允许玩家通过反复点击无限刷取灵韵和金条
> **影响范围**: 线上真实玩家已发现并利用此漏洞

### 8.1 金标准：悟道树模式

**所有涉及资源发放的 C2S 处理函数，必须同时满足以下三层防护。缺任何一层都可被利用。**

| 层级 | 防护 | 作用 | 缺失后果 |
|------|------|------|---------|
| **① 服务端内存锁** | `xxxActive_[connKey] = true` | 序列化同一用户的并发请求 | 快速连点时 ServerGetSlotData 读取到未更新的旧数据，同一份奖励被多次发放 |
| **② 原子事务** | `serverCloud:BatchCommit()` | quota 扣减与数据保存原子执行 | quota:Add 成功但 Save 失败（或反过来），导致数据不一致 |
| **③ 客户端交互禁用** | `btn:SetDisabled(true)` 或 `props.onClick = nil` | 阻止用户触发重复请求 | 用户可在 S2C 回包后继续点击，服务端虽有防护但增加不必要的负载 |

**参考实现**（悟道树）：

```lua
-- ① 服务端内存锁
if daoTreeMeditating_[connKey] then return end  -- 已有请求处理中，直接丢弃
daoTreeMeditating_[connKey] = true

-- 处理完毕后释放
daoTreeMeditating_[connKey] = nil

-- ② 原子事务
local commit = serverCloud:BatchCommit("悟道树参悟奖励")
commit:QuotaAdd(userId, treeQuotaKey, 1, 1, "day", 1)
commit:QuotaAdd(userId, dailyQuotaKey, 1, 3, "day", 1)
commit:ScoreSet(userId, "save_" .. slot, saveData)
commit:Commit({
    ok = function()
        SafeSend(connection, S2C_Event, { ok = true, ... })  -- 仅原子成功时发放奖励
    end,
    error = function(err)
        SafeSend(connection, S2C_Event, { ok = false })       -- 原子失败时通知客户端
    end,
})

-- ③ 客户端交互禁用（DaoTreeUI.lua）
startBtn_.props.onClick = nil      -- 直接移除点击处理器
-- 或
btn:SetDisabled(true)              -- 禁用按钮交互
```

### 8.2 反面案例：试炼供奉的三个漏洞

**以下是被线上玩家利用的真实漏洞，作为永久反面教材。**

#### Bug #1：客户端 onClick 未禁用

```lua
-- ❌ 错误（TrialOfferingUI.lua）：只改文字和样式，onClick 仍然有效
claimBtn_:SetText("今日已领取 ✅")
claimBtn_:SetStyle({ backgroundColor = {80, 80, 90, 200} })
-- 缺失: claimBtn_:SetDisabled(true)
-- 结果: 玩家可以反复点击"今日已领取"按钮继续领奖
```

#### Bug #2：quota 空回调（火力不设防）

```lua
-- ❌ 错误（server_main.lua HandleTrialClaimDaily 里程碑分支）：
serverCloud.quota:Add(userId, quotaKey, 1, 1, "day", {
    ok = function() end,      -- 空回调！quota 成功与否都不关心
    error = function() end,   -- 空回调！quota 超限也不阻止
})
-- 奖励在下方 batch:Save 的 ok 回调中发放，与 quota 结果完全无关
-- 结果: quota 形同虚设，同一天可无限领取
```

#### Bug #3：无服务端内存锁

```lua
-- ❌ 错误：没有 trialClaimingActive_[connKey] 检查
-- 每次请求都调用 ServerGetSlotData 从 serverCloud 异步读取
-- 快速连点时，多个请求同时读到旧数据（dailyClaimedTier 未更新）
-- 每个请求都认为"还没领过"，各自独立发放奖励
-- 结果: 5 次快速点击 = 5 倍奖励
```

### 8.3 编码检查清单

**每次编写或修改涉及资源发放的 C2S 处理函数时，必须逐项确认：**

```
服务端（server_main.lua）：
  □ 函数入口有内存锁检查（xxxActive_[connKey]）？
  □ 锁在所有退出路径（成功/失败/异常）都被释放？
  □ 使用 BatchCommit 原子事务（quota + 数据保存在同一事务中）？
  □ 奖励仅在 BatchCommit 的 ok 回调中发放？
  □ error 回调中通知客户端失败（SafeSend ok=false）？
  □ quota:Add 的回调不是空函数？（如果单独使用 quota:Add 而非 BatchCommit）

客户端（xxxUI.lua）：
  □ 发送 C2S 请求后立即禁用按钮（SetDisabled 或 onClick=nil）？
  □ S2C 成功回包后按钮保持禁用（不恢复 onClick）？
  □ S2C 失败回包后恢复按钮可点击状态？
```

### 8.4 横向排查结果（2026-04-02）

| 系统 | 内存锁 | 原子事务 | 客户端禁用 | 结论 |
|------|--------|---------|-----------|------|
| 悟道树 | ✅ `daoTreeMeditating_` | ✅ `BatchCommit` | ✅ `onClick=nil` | **安全（金标准）** |
| 封魔系统 | ✅ `sealDemonActive_` | ✅ 阻塞式 `quota:Add` | ✅ UI 隐藏 | **安全** |
| 公告栏福利 | — （纯客户端） | — | ✅ 幂等检查 | **安全** |
| 兑换码 | ⚠️ `pending_` | ✅ 双重 `quota:Add` 阻塞 | ✅ `pending_` | **基本安全** |
| **试炼供奉** | ❌ 无 | ❌ 空回调 | ❌ 未禁用 | **🔴 可刷资源** |

### 8.5 根因反思

此漏洞的根本原因：**项目中已有安全的成熟模式（悟道树），但在实现新功能时未对照复用。**

**强制规则**：
1. 新增任何日常/领取类功能前，必须先阅读本节规范
2. 以悟道树（`HandleDaoTreeComplete`）为模板，复制其三层防护结构
3. 自测时必须包含"快速连点 5 次"的边界场景，而非仅测试正常流程
4. 代码 Review 时重点检查 quota 回调是否为空函数

---

*创建时间: 2026-03-06*
*规则 #2 创建时间: 2026-03-07 — 原因: T5 图标首批生成不符合规范（含背景、文字、UI 元素）*
*规则 #3 创建时间: 2026-03-07 — 原因: 误删 44 个动态引用的装备图标，grep 未检测到字符串拼接引用*
*规则 #4 创建时间: 2026-03-07 — 原因: 竖屏和 GM 关闭为每次发布的固定操作*
*重构时间: 2026-03-17 — 建立完整智能体准则，涵盖项目架构、战斗公式、图片规范、存档规范、发布流程*
*更新时间: 2026-03-28 — 第四章（八卦海）同步：章节表、目录结构、灵韵货币、灵器机制、洗练系统、存档v10、4槽位、新系统文件、高风险检查清单*
*规则 #8 创建时间: 2026-04-02 — 原因: 试炼供奉（HandleTrialClaimDaily）三重漏洞被线上玩家利用无限刷取灵韵和金条，根因是未复用悟道树的安全模式*

---

## 十、可选模块 require 必须 pcall 保护

> **规则创建时间**: 2026-04-12
> **触发场景**: 可选模块（如 DungeonClient）的裸 require 一旦抛异常，会导致 main.lua 整体加载失败，GameStart() 从未被定义，存档界面无法创建
> **风险等级**: P0 — 一旦触发，全量玩家不可用（存档界面不渲染）
> **注意**: 2026-04 的"存档丢失"事件经复盘确认是**平台预览环境变更**导致（平台回撤后自动恢复），并非由 pcall 缺失直接触发。但 pcall 保护作为防御性编程仍是必须的——它防御的是一条真实存在的崩溃路径。

### 10.1 问题根因

`main.lua` 文件顶部有 72 行同步 require。Lua 的 require 是文件加载时同步执行的——只要**任何一行**抛异常，整个文件加载失败，后续所有代码（包括 `GameStart()` 函数定义在第 196 行）都不会被解析。

**崩溃链条**：

```
client_main.lua:215   require("main")
    ↓
main.lua:72           require("network.DungeonClient")  ← 裸 require，加载失败即抛异常
    ↓
❌ main.lua 整个文件加载失败（Lua 加载时异常会中止整个文件）
    ↓
❌ GameStart() 函数从未被定义（它在 main.lua:196）
    ↓
client_main.lua:217   if GameStart then → false，走 WARNING 分支
    ↓
❌ 存档界面永远不会显示
    ↓
玩家看到：存档丢失（实际数据完好，只是界面没有被创建）
```

### 10.2 2026-04 存档丢失事件复盘

**最初判断**：怀疑是 DungeonClient 裸 require 崩溃导致 GameStart() 未定义 → 存档界面不渲染。

**最终确认**：存档丢失是**平台对预览环境做了变更**（可能涉及存储路径/隔离策略），平台于当天 16:00 后回撤该变更，存档自动恢复。

**为什么最初误判**：
- pcall 保护添加（Phase 1）和平台回撤在时间上重叠，造成因果错判
- 关键反证：pcall 保护在 Phase 1 就已 build 部署，但存档在 Phase 1 之后仍然"丢失"，直到平台回撤后才恢复。如果 pcall 是修复原因，Phase 1 部署后存档就应该立即恢复

**pcall 仍然必须保留的原因**：
- `require` 崩溃 → `GameStart()` 未定义 → 存档界面不渲染，这条崩溃路径是**真实存在**的
- 虽然这次存档丢失不是由它触发，但未来 DungeonClient 的任何语法错误/依赖缺失都可能触发它
- 这是标准的故障隔离：可选功能模块不应影响核心流程

### 10.3 强制规则 🔴

**main.lua 中的可选模块 require 必须使用 pcall 保护，禁止裸 require。**

#### 哪些模块属于"可选模块"

| 类别 | 判断标准 | 示例 |
|------|---------|------|
| **核心模块** | 游戏无法运行的基础依赖（UI、状态、玩家、存档） | GameConfig, GameState, Player, SaveSystem, UI |
| **可选模块** | 移除后游戏主流程（存档→角色选择→进入世界）仍可运行 | DungeonClient, DungeonRenderer, 未来的新系统模块 |

#### 可选模块的 require 模板

```lua
-- ✅ 正确：pcall 保护，失败时降级为 nil
local _dcOk, DungeonClient = pcall(require, "network.DungeonClient")
if not _dcOk then
    print("[WARN] DungeonClient load failed: " .. tostring(DungeonClient))
    DungeonClient = nil
end

-- 使用时必须 nil 守卫
if DungeonClient then DungeonClient.Update(dt) end
```

```lua
-- ❌ 错误：裸 require，一旦失败会炸掉整个文件
local DungeonClient = require("network.DungeonClient")
```

### 10.4 当前已保护的模块

| 文件 | 被保护的模块 | 保护方式 |
|------|-------------|---------|
| `main.lua:72` | `network.DungeonClient` | pcall + nil 降级 |
| `WorldRenderer.lua:21` | `rendering.DungeonRenderer` | pcall + nil 降级 |
| `EntityRenderer.lua:1697` | `network.DungeonClient` | pcall + false 哨兵延迟加载 |

### 10.5 新增可选模块时的检查清单

```
新增模块到 main.lua 时：
  □ 该模块是否属于"可选模块"？（移除后主流程是否仍可运行）
  □ 如果是可选模块 → 必须 pcall 保护
  □ 所有使用该模块的地方是否有 nil 守卫？
  □ 模块加载失败时是否有 print 日志？（方便排查）
```

### 10.6 教训总结

1. **故障隔离原则**：可选功能模块的任何 bug（语法错误、依赖缺失、运行时异常）绝不能影响核心流程（存档加载、角色选择、进入世界）。pcall 保护是 Lua 中实现故障隔离的标准手段。
2. **因果归因要严谨**：时间重叠 ≠ 因果关系。2026-04 存档事件中，pcall 修复和平台回撤时间重叠，导致错误归因。正确方法：检查 pcall 部署时间点（Phase 1）后存档是否恢复 → 未恢复 → 排除 pcall 假说。
3. **环境因素不可忽视**：线上问题不一定是代码 bug，平台环境变更（存储路径、隔离策略）同样可能导致数据"丢失"。排查时应同时考虑代码和环境两个维度。

---

## 九、构建规范（多人游戏 entry 参数）

> **规则创建时间**: 2026-04-09
> **触发事件**: 多次构建时遗漏 `entry_client` 参数，导致客户端入口从 `client_main.lua` 被覆盖为 `main.lua`，游戏上线后出现"网络异常，无法加载角色数据"
> **影响范围**: 已多次发生，每次均导致多人模式完全不可用

### 9.1 问题根因

本项目是多人游戏（C/S 架构），有两个独立入口：

| 角色 | 入口文件 | 职责 |
|------|---------|------|
| 客户端 | `client_main.lua` | 网络初始化、Scene 关联、ServerReady 事件、版本握手 |
| 服务端 | `server_main.lua` | 玩家管理、存档读写、GM 命令处理 |
| 单机模式 | `main.lua` | 仅供单机调试，**不含任何网络代码** |

调用 `build` 工具时，如果**遗漏 `entry_client` 参数**，构建系统会将 `project.json` 中的 `entry` 字段值（`main.lua`）写入 `entry@client`，导致：

```
entry@client: "client_main.lua"  →  "main.lua"（被覆盖！）
```

客户端加载 `main.lua` 后不会初始化网络连接，表现为"网络异常，无法加载角色数据"。

### 9.2 强制规则 🔴

**每次调用 build 工具，必须显式传入 `entry_client` 和 `entry_server` 参数：**

```
✅ 正确：
build(entry_client="client_main.lua", entry_server="server_main.lua")

❌ 错误（绝对禁止）：
build()                          — 遗漏两个参数
build(entry="main.lua")          — 只传 entry，不传 entry_client
build(entry_server="server_main.lua")  — 只传服务端，遗漏客户端
```

### 9.3 自检方法

构建完成后，**必须检查 manifest 中的 entry 字段**：

```bash
# 快速验证
grep '"entry"' /workspace/dist/<version>/manifest-*.json
# 预期输出：
#   manifest-xxx.json:  "entry": "client_main.lua",   ← 客户端
#   manifest-xxx.json:  "entry": "server_main.lua",   ← 服务端
```

如果看到 `"entry": "main.lua"` 出现在任何 manifest 中，说明构建参数错误，**必须立即修正 project.json 并重新构建**。

### 9.4 事故记录

| 时间 | 版本 | 表现 | 根因 |
|------|------|------|------|
| 2026-04-09 | 1.0.404 ~ 1.0.405 | "网络异常，无法加载角色数据" | build 时未传 entry_client，entry@client 被覆盖为 main.lua |
| （此前多次） | — | 同上 | 同上（反复犯同一错误） |
