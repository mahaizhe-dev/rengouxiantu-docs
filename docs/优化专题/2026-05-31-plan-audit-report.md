# 重构计划审核评估报告

> **目的**: 基于代码实际状态，审核重构计划文档的准确性，为 Step 4+ 后续开发做准备  
> **审核时间**: 2026-05-31  
> **审核对象**: `docs/2026-05-30-origin-main-bigfile-refactor-plan.md`  
> **当前 HEAD**: `ebaeec2` (branch: `refactor/bigfile-split`)

---

## 1. 结论摘要

| 维度 | 状态 | 说明 |
|------|------|------|
| 行数一致性 | ✅ 全部匹配 | 计划中记录的所有文件行数与实际代码完全一致 |
| Step 4 拆分策略 | ⚠️ 需修订 | MonsterData.Skills 占 85%（3139行），需二级拆分策略 |
| Step 5 拆分策略 | ✅ 可行 | 渲染线文件有清晰的函数级分段边界 |
| Step 6 拆分策略 | ✅ 可行 | 系统线文件函数数量适中，按技能类型/功能域拆分可行 |
| Step 7 拆分策略 | ✅ 可行 | UI 面板有明确的 Tab/功能模块划分 |
| Budget Gate 覆盖 | ⚠️ 有缺口 | `network/`, `entities/`, `world/`, `main.lua` 未纳入扫描 |
| EXEMPTIONS 完整性 | ✅ 完整 | 当前被扫描目录内所有超阈值文件均已注册 |

---

## 2. 文件行数交叉验证（计划 vs 实际）

### 第一梯队（Step 4-7 目标）

| 文件 | 计划记录 | 实际行数 | 偏差 |
|------|---------|---------|------|
| config/MonsterData.lua | 3698 | 3698 | 0 |
| config/MonsterTypes_ch3.lua | 2205 | 2205 | 0 |
| config/EquipmentData_Special.lua | 2012 | 2012 | 0 |
| rendering/EffectRenderer.lua | 3561 | 3561 | 0 |
| rendering/TileRenderer.lua | 3301 | 3301 | 0 |
| rendering/EntityRenderer.lua | 3298 | 3298 | 0 |
| systems/SkillSystem.lua | 2123 | 2123 | 0 |
| systems/LootSystem.lua | 1668 | 1668 | 0 |
| systems/ChallengeSystem.lua | 1529 | 1529 | 0 |
| systems/InventorySystem.lua | 1386 | 1386 | 0 |
| ui/PetPanel.lua | 2175 | 2175 | 0 |
| ui/ChallengeUI.lua | 2119 | 2119 | 0 |

**结论**: 自计划制定以来无代码膨胀，文件处于静态状态，可安全执行拆分。

---

## 3. Step 4 深度审核：MonsterData.lua

### 3.1 实际内部结构

```
L8-L168     core_stats (公式+种族修正+阶级倍率+计算函数)    ~160 行  (4.3%)
L185-L3324  Skills (怪物技能定义大表)                      ~3139 行 (84.9%) ← 绝对主体
L3324-L3336 Types = {} (空表声明)                          ~12 行   (0.3%)
L3336-L3698 WORLD_DROP_POOLS (世界掉落池)                  ~362 行  (9.8%)
```

### 3.2 Skills 内部分段分析

- **总分段数**: 55 个（按 `-- =====` 注释标记）
- **平均每段**: 57 行
- **最大分段**: 536 行（太虚宗主 L3027-L3562）
- **前四大段**: 536, 498, 462, 353 行

按游戏系统聚类:
| 系统 | 行范围 | 估计行数 |
|------|--------|---------|
| 通用技能 + ch2 遗留 | L185-L507 | ~322 |
| 第三章·沙漠九寨 | L508-L860 | ~353 |
| 猪二哥 | L861-L980 | ~120 |
| 流沙系列 | L917-L1156 | ~240 |
| 第四章·八阵BOSS | L1157-L1654 | ~498 |
| 仙劫战场 | L1655-L1812 | ~158 |
| 第五章·镇渊魔帅 | L1813-L2564 | ~752 |
| 第五章·四仙剑BOSS | L2565-L3026 | ~462 |
| 太虚宗主（神器BOSS） | L3027-L3324 | ~298 |

### 3.3 计划中的拆分方案评估

计划提出拆为: `core_stats`, `race_modifiers`, `category_multipliers`, `skills`, `world_drop_pools`

**评估**:
- ✅ `core_stats` (含 race_modifiers + category_multipliers): 合并到 facade 中即可（~160行），无需单独文件
- ⚠️ `skills` 单独一个文件仍有 3139 行，**远超 DATA_ALERT=1400**
- ✅ `world_drop_pools`: 362 行，独立文件合理

### 3.4 修订建议

**MonsterData 推荐拆分方案（二级）**:

```
MonsterData.lua (facade, ~200行)
├── MonsterData_Skills_Common.lua    (~322行) 通用+ch2
├── MonsterData_Skills_ch3.lua       (~713行) 沙漠九寨+猪二哥+流沙
├── MonsterData_Skills_ch4.lua       (~498行) 八阵BOSS
├── MonsterData_Skills_ch5.lua       (~1214行 → 可选再拆) 镇渊+四仙剑+仙劫
├── MonsterData_Skills_artifact.lua  (~298行) 太虚宗主
└── MonsterData_WorldDrop.lua        (~362行) 掉落池
```

**优势**: 每个文件 < 900 行（DATA_TARGET），按章节维护，与 MonsterTypes_chN 对应。

**接入方式**: 与现有 MonsterTypes 注册模式一致：
```lua
-- facade 尾部
MonsterData.Skills = {}
require("config.MonsterData_Skills_Common")(MonsterData)
require("config.MonsterData_Skills_ch3")(MonsterData)
...
```

---

## 4. Step 4 深度审核：MonsterTypes_ch3.lua

### 4.1 实际结构

```
L1-L7       文件头 + closure: return function(M)
L8-L217     挑战副本 T1-T4 (沈墨 + 陆青云)          ~210 行
L218-L966   沙漠九寨主线怪物 (8寨+精英+BOSS)        ~749 行
L967-L996   神器BOSS（猪二哥）                       ~30 行
L997-L1238  挑战副本 T5-T8                           ~242 行
L1239-L2205 声望体系 R1-R8 (沈墨+陆青云)            ~967 行
```

### 4.2 计划方案评估

计划提出: `challenge_tiers`, `desert_world`, `reputation`, `artifact_boss`

**评估**:
- ✅ 分割点清晰，代码结构有明确注释标记
- ⚠️ `reputation` 段（967行）接近 DATA_TARGET=900，需注意
- ✅ 挑战系统自然分为 T1-T4 和 T5-T8 两段，可合并一个文件
- ✅ 猪二哥仅 30 行，不值得独立文件，可并入 desert_world

**修订建议**:
```
MonsterTypes_ch3.lua (facade, ~50行)
├── MonsterTypes_ch3_challenge.lua   (~452行) T1-T4 + T5-T8 合并
├── MonsterTypes_ch3_desert.lua      (~779行) 九寨+猪二哥
└── MonsterTypes_ch3_reputation.lua  (~967行) 声望 R1-R8
```

---

## 5. Step 4 深度审核：EquipmentData_Special.lua

### 5.1 实际结构

- 纯数据表 `return { ... }`，无函数
- 按章节分段: 第一章 → 第二章(L215) → 第三章(L345) → 黄天大圣(L536) → 龙神圣器(L683) → 后续
- 每条装备 ~18-25 行

### 5.2 评估

- 当前 2012 行，EXEMPTION=2050
- 计划标注"纯数据表，后续按章节再拆"
- **按章节拆分是最自然的边界**，与现有 MonsterTypes_chN 系列命名一致

**无需修订**，计划方案合理。

---

## 6. Step 5 审核：渲染线

### 6.1 EffectRenderer.lua (3561行)

**内部结构** (按大分段):
| 段 | 行范围 | 内容 | 估计行数 |
|----|--------|------|---------|
| 基础特效 | L1-L355 | 浮字/斩击/爪击 | ~355 |
| 技能特效渲染函数 | L356-L2036 | 20+ 个 renderXxx() | ~1680 |
| 剑阵/Zone/警告 | L2037-L2715 | 剑阵+宠物+区域 | ~679 |
| 大段后半 | L2716-L3561 | 多段后续特效 | ~846 |

**拆分可行性**: ✅ 极佳。每个 renderXxx 函数独立性强，可按特效类型/章节拆分。

### 6.2 TileRenderer.lua (3301行)

**内部结构**: 每种地块一对 `Ensure*Image()` + `Render*()` 函数，分段清晰。

**拆分可行性**: ✅ 按地块类型分组（城镇/山地/沼泽/沙漠/天宫/封印等）。

### 6.3 EntityRenderer.lua (3298行)

**内部结构**:
| 段 | 行范围 | 内容 | 估计行数 |
|----|--------|------|---------|
| RenderPlayer | L150-L1022 | 玩家渲染 | ~873 |
| RenderPet | L1023-L1104 | 宠物渲染 | ~82 |
| RenderMonsters | L1105-L2049 | 怪物渲染 | ~945 |
| RenderMonsterHealthBars | L2050-L2093 | 血条 | ~44 |
| RenderNPCs | L2094-L2328 | NPC渲染 | ~235 |
| RenderLootDrops | L2329-L2610 | 掉落物 | ~282 |
| 后续 | L2611-L3298 | 仙缘果/宝箱/锁链等 | ~688 |

**拆分可行性**: ✅ 按实体类型拆分（Player/Monster/NPC/Drops 各一个子模块）。

---

## 7. Step 6 审核：系统线

| 文件 | 行数 | 函数数 | 拆分可行性 |
|------|------|--------|-----------|
| SkillSystem.lua | 2123 | 45 | ✅ 按技能类型拆(Damage/Heal/Buff/AoE/Zone) |
| LootSystem.lua | 1668 | 27 | ✅ 按掉落类型拆(world_drop/boss_drop/quest_drop) |
| ChallengeSystem.lua | 1529 | 29 | ✅ 按挑战阶段拆(tier/reputation/reward) |
| InventorySystem.lua | 1386 | 36 | ✅ 按功能域拆(equip/upgrade/dismantle/sort) |

**计划方案与实际匹配度**: ✅ 高。所有文件函数级分段明确，无交叉耦合函数。

---

## 8. Step 7 审核：UI 线

| 文件 | 行数 | 函数数 | 内部结构 |
|------|------|--------|---------|
| PetPanel.lua | 2175 | 24+ | 按 Tab 分: Info/Breakthrough/Skills/Appearance |
| ChallengeUI.lua | 2119 | 18+ | 按场景分: 选择/战斗/胜利/声望 |

**拆分可行性**: ✅ PetPanel 按 Tab 独立（每 Tab 约 400-600 行），ChallengeUI 按对话流拆分。

---

## 9. Budget Gate 覆盖缺口（重要发现）

### 9.1 当前 SCAN_DIRS

```lua
SCAN_DIRS = { "config", "rendering", "ui", "systems" }
```

### 9.2 未覆盖的超阈值文件

| 文件 | 行数 | 目录 | 风险 |
|------|------|------|------|
| main.lua | 1753 | / (根) | 🔴 高 |
| network/DungeonHandler.lua | 1762 | network/ | 🔴 高 |
| network/BlackMerchantHandler.lua | 1404 | network/ | 🟡 中 |
| network/DungeonClient.lua | 1128 | network/ | 🟡 中 |
| network/EventHandler.lua | 932 | network/ | 🟡 中 |
| network/SaveSystemNet.lua | 868 | network/ | 🟢 低 |
| entities/Monster.lua | 1362 | entities/ | 🟡 中 |
| entities/Player.lua | 1244 | entities/ | 🟡 中 |
| entities/Pet.lua | 871 | entities/ | 🟢 低 |
| world/mapgen/Chapter3.lua | 1005 | world/ | 🟢 低 |

**合计遗漏**: 10 个超 CODE_ALERT(900) 的文件未被门禁拦截。

### 9.3 建议

在 Step 8（第二梯队补扫）中扩展 SCAN_DIRS:
```lua
SCAN_DIRS = { "config", "rendering", "ui", "systems", "network", "entities", "world" }
```

同时为 `main.lua` 添加根目录特殊扫描逻辑或将其加入 EXEMPTIONS。

---

## 10. 计划修订建议汇总

### 10.1 Step 4 修订（优先级：高）

| 原计划 | 修订建议 | 原因 |
|--------|---------|------|
| MonsterData → skills 单文件 | 按章节二级拆分（5-6 个子文件） | Skills 3139 行远超 DATA_ALERT |
| MonsterTypes_ch3 → 4 子文件 | 3 子文件（challenge 合并 T1-T8） | 猪二哥仅 30 行不值得独立 |
| EquipmentData_Special | 无需修订 | 按章节拆分自然合理 |

### 10.2 Step 8 修订（优先级：中）

- 扩展 SCAN_DIRS 覆盖 `network/`, `entities/`, `world/`
- 为 `main.lua` 设置 EXEMPTION 或触发重构

### 10.3 新增关注项

| 文件 | 当前行数 | 建议 |
|------|---------|------|
| network/DungeonHandler.lua | 1762 | 应纳入第二梯队 EXEMPTIONS |
| network/BlackMerchantHandler.lua | 1404 | 应纳入第二梯队 EXEMPTIONS |
| entities/Monster.lua | 1362 | 应纳入第二梯队 EXEMPTIONS |
| entities/Player.lua | 1244 | 应纳入第二梯队 EXEMPTIONS |
| main.lua | 1753 | 应纳入第二梯队 EXEMPTIONS 或重构 |

---

## 11. Step 4 执行就绪评估

| 前置条件 | 状态 | 说明 |
|---------|------|------|
| Step 0-3 完成 | ✅ | 已验收通过 |
| 测试基线稳定 | ✅ | 21 PASS / 5 FAIL（全部预存） |
| Budget gate 通过 | ✅ | 242/242 PASS |
| 目标文件无新增代码 | ✅ | 行数与计划制定时完全一致 |
| 拆分边界明确 | ✅ | 所有目标文件有清晰注释分段 |
| 调用关系已映射 | ✅ | MonsterData.Skills 仅 Monster.lua 调用 |
| 循环依赖风险 | ✅ 无 | Skills 是纯数据，无反向引用 |

**结论**: Step 4 可立即开始执行，但建议先按本报告 §10.1 修订拆分方案后再动手。

---

## 12. MonsterTypes 系列全景

```
MonsterTypes_ch1.lua     394 行  ✅ 合规
MonsterTypes_ch2.lua     500 行  ✅ 合规
MonsterTypes_ch3.lua    2205 行  🔴 待拆（Step 4 目标）
MonsterTypes_ch4.lua    1050 行  ⚠️ 超 DATA_TARGET 但在 DATA_ALERT 内
MonsterTypes_ch5.lua     940 行  ⚠️ 超 DATA_TARGET（EXEMPTION=1000）
MonsterTypes_training.lua  68 行  ✅ 合规
MonsterTypes_xianjie.lua   62 行  ✅ 合规
```

---

*审核完成 — 2026-05-31*
