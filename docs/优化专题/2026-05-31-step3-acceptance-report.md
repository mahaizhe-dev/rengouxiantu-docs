# Step 3 验收报告 — EquipmentData 拆分

## 结论摘要

**Step 3 通过验收。**

- EquipmentData.lua (3449→252 行) 拆分为 facade + 3 子模块
- 所有调用方无需改动 require 路径（0 处）
- 门禁 242/242 PASS，0 FAIL
- 全量测试 21 PASS / 5 FAIL（与基线一致，新增失败数 = 0）
- 已推送远端，HEAD 对齐

---

## 1. 基本信息

| 项目 | 值 |
|------|------|
| 本次验收阶段 | **Step 3** |
| 目标说明 | 将 `config/EquipmentData.lua`（3449 行）拆分为 facade + 3 子模块，保持 SLOTS 立即可用 |
| 工作分支 | `refactor/bigfile-split`（本地 & 远端同名） |
| 基线提交 | `6404c07`（Step 2 完成后 HEAD） |
| 交付提交 | `23b756c` — `refactor(config): Step 3 — split EquipmentData into facade + 3 sub-modules` |
| 是否已 push 到远端 | **yes** |
| 远端当前 HEAD | `23b756cff90063c85d12b323fd2e62e513068dff` |

---

## 2. Git 证据

### git rev-parse HEAD
```
23b756cff90063c85d12b323fd2e62e513068dff
```

### git log --oneline -5
```
23b756c refactor(config): Step 3 — split EquipmentData into facade + 3 sub-modules
6404c07 refactor(config): Step 2 — graduate GameConfig.lua from EXEMPTIONS (755 lines < DATA_TARGET 900)
fb32d9c test(infra): add file length budget gate
1edf68c docs: add §12 execution log for Step 0 & Step 1
e9c4d17 update: 事件配置/GameConfig/公告/兑换UI/测试文件更新
```

### git show --stat --summary 23b756c
```
commit 23b756cff90063c85d12b323fd2e62e513068dff
Author: mahaizhe-dev <mahaizhe-dev@users.noreply.github.com>
Date:   Sun May 31 10:54:07 2026 +0800

    refactor(config): Step 3 — split EquipmentData into facade + 3 sub-modules

 docs/2026-05-30-origin-main-bigfile-refactor-plan.md |   41 +
 scripts/config/EquipmentData.lua                     | 3205 +-------------------
 scripts/config/EquipmentData_Collection.lua          |  665 ++++
 scripts/config/EquipmentData_Forge.lua               |  535 ++++
 scripts/config/EquipmentData_Special.lua             | 2012 ++++++++++++
 scripts/tests/test_file_budget.lua                   |    3 +-
 6 files changed, 3259 insertions(+), 3202 deletions(-)
 create mode 100644 scripts/config/EquipmentData_Collection.lua
 create mode 100644 scripts/config/EquipmentData_Forge.lua
 create mode 100644 scripts/config/EquipmentData_Special.lua
```

### git diff --stat 6404c07..HEAD
```
 docs/2026-05-30-origin-main-bigfile-refactor-plan.md |   41 +
 scripts/config/EquipmentData.lua                     | 3205 +-------------------
 scripts/config/EquipmentData_Collection.lua          |  665 ++++
 scripts/config/EquipmentData_Forge.lua               |  535 ++++
 scripts/config/EquipmentData_Special.lua             | 2012 ++++++++++++
 scripts/tests/test_file_budget.lua                   |    3 +-
 6 files changed, 3259 insertions(+), 3202 deletions(-)
```

### git diff --name-status 6404c07..HEAD
```
M  docs/2026-05-30-origin-main-bigfile-refactor-plan.md
M  scripts/config/EquipmentData.lua
A  scripts/config/EquipmentData_Collection.lua
A  scripts/config/EquipmentData_Forge.lua
A  scripts/config/EquipmentData_Special.lua
M  scripts/tests/test_file_budget.lua
```

### git status --short（tracked 文件）
```
（无 tracked 文件变更，工作树干净；untracked 仅 .agent/.claude/.cli/.project/.tmp/ 及 assets 资源）
```

---

## 3. 目标文件清单

| 文件路径 | 变更前行数 | 变更后行数 | 预算阈值 | 状态 | commit SHA |
|---------|-----------|-----------|---------|------|-----------|
| `config/EquipmentData.lua` | 3449 | 252 | DATA_TARGET=900 | **达标（已拆分，facade 已毕业）** | `23b756c` |
| `config/EquipmentData_Special.lua` | — (new) | 2012 | EXEMPTION=2050 | **仍超标但受豁免** | `23b756c` |
| `config/EquipmentData_Collection.lua` | — (new) | 665 | DATA_TARGET=900 | **达标** | `23b756c` |
| `config/EquipmentData_Forge.lua` | — (new) | 535 | DATA_TARGET=900 | **达标** | `23b756c` |

---

## 4. 结构拆分详情

### 4.1 拆分总览

| 项目 | 值 |
|------|------|
| 原文件路径 | `scripts/config/EquipmentData.lua` |
| 是否保留原入口路径和原 API | **yes** — `require("config.EquipmentData")` 返回完整 table |
| facade 文件路径 | `scripts/config/EquipmentData.lua`（252 行） |
| 新增子模块路径列表 | `EquipmentData_Special.lua`, `EquipmentData_Collection.lua`, `EquipmentData_Forge.lua` |
| 旧调用方是否需要改 require | **0 处** — 所有 20+ 处调用方仍用 `require("config.EquipmentData")` |
| 初始化顺序是否变化 | **no** — facade 先定义核心常量(SLOTS/STANDARD_SLOTS)，再加载子模块，顺序与原文件一致 |

### 4.2 对外导出函数/字段清单

**拆分前（单文件 3449 行）所有 `EquipmentData.xxx` 字段**：

**拆分后分布**：

| 位置 | 字段 |
|------|------|
| **facade（252行）** | SLOTS, STANDARD_SLOTS, SPECIAL_SLOTS, SLOT_NAMES, MAIN_STAT, BASE_MAIN_STAT, TIER_SLOT_NAMES, TIER_MULTIPLIER, PCT_TIER_MULTIPLIER, PCT_SUB_TIER_MULT, PCT_STATS, PCT_MAIN_STATS, INT_MAIN_STATS, LINEAR_GROWTH_STATS, SUB_STATS, SUB_STAT_TIER_MULT |
| **EquipmentData_Special（2012行）** | SpecialEquipment（通过 `EquipmentData.SpecialEquipment = require(...)` 挂载） |
| **EquipmentData_Collection（665行）** | Collection（通过 `EquipmentData.Collection = require(...)` 挂载） |
| **EquipmentData_Forge（535行）** | SetBonuses, GOURD_UPGRADE, GOURD_MAIN_STAT, DRAGON_FORGE_RECIPES, DRAGON_FORGE_COST, LONGJI_FORGE_COST, LINGQI_FORGE_COST, LINGQI_FORGE_SET_CHANCE, LINGQI_FORGE_SLOTS, FabaoTemplates, SWORD_FORGE_COSTS, SWORD_FORGE_ORDER |

**拆分后对外接口与拆分前完全一致** — 调用方通过 `EquipmentData.SetBonuses`、`EquipmentData.SpecialEquipment` 等访问，路径不变。

### 4.3 调用关系图

```
调用方 (SaveMigrations, InventorySystem, LootSystem, ...)
    │
    └─→ require("config.EquipmentData")  ← facade (252 行)
              │
              ├── [直接定义] SLOTS, STANDARD_SLOTS, TIER_*, SUB_STATS, ...
              │
              ├── EquipmentData.SpecialEquipment = require("config.EquipmentData_Special")
              │       └── return { ... }  (纯数据表, 2012 行)
              │
              ├── EquipmentData.Collection = require("config.EquipmentData_Collection")
              │       └── return { ... }  (纯数据表, 665 行)
              │
              └── require("config.EquipmentData_Forge")(EquipmentData)
                      └── function(EquipmentData)  (闭包模式, 535 行)
                          ├── EquipmentData.SetBonuses = { ... }
                          ├── EquipmentData.LINGQI_FORGE_SLOTS = EquipmentData.STANDARD_SLOTS  ← 自引用
                          └── EquipmentData.SWORD_FORGE_COSTS = { ... }
```

### 4.4 循环依赖风险

**无循环依赖**：
- `EquipmentData_Special` 和 `EquipmentData_Collection` 是纯 `return {...}` 表，无任何 require
- `EquipmentData_Forge` 通过闭包参数接收 `EquipmentData` table，不调用 require

### 4.5 兼容性验证

**旧入口是否还能直接工作：yes**

所有 20+ 处调用方（SaveMigrations×6, SaveSerializer×2, InventorySystem, LootSystem, CollectionSystem, BlackMerchantConfig, QuestSystem, 测试×6+）均使用 `require("config.EquipmentData")`，无需改动。

---

## 5. 文件长度门禁

| 项目 | 值 |
|------|------|
| `test_file_budget.lua` 是否改动 | **yes** |
| EXEMPTIONS 数量 | 变更前: 9 条 → 变更后: 9 条（净 0 变化；移除 1 条旧的，新增 1 条新的） |
| 新增豁免条目 | `["config/EquipmentData_Special.lua"] = 2050` |
| 移除豁免条目 | `["config/EquipmentData.lua"] = 3500`（facade 252 行已毕业，注释标记） |

### 门禁结果原始输出

```
  总计: 242 文件 | ✅ 242 PASS | ❌ 0 FAIL | ⚠️  21 WARNING

  结论: ✅ PASS — 所有文件在预算范围内

[PASS] file_budget (242/242 passed)

[SUMMARY] total=2 executed=2 passed=2 failed=0 skipped=0

EXIT: SUCCESS
```

可复算依据：
- 242 个被扫描的 `.lua` 文件全部 PASS
- 21 WARNING 来自超过 DATA_ALERT(1400) 但有 EXEMPTION 的文件（如 rendering/EffectRenderer 3561 行等）
- 0 FAIL 表示无文件超出其 EXEMPTION 上限

---

## 6. 测试验证

| 项目 | 值 |
|------|------|
| 执行环境 | Python 3.12.3, lupa 2.8, Lua 5.5 (LuaJIT-like runtime) |
| 执行命令 | `python3 scripts/tests/_run_via_lupa.py` |
| 总体结果 | **21 PASS / 5 FAIL** |
| 新增失败数 | **0** |

### 当前失败列表

| 测试名 | 错误 | 性质 |
|--------|------|------|
| `smoke_fail` | 1 sub-test(s) failed | **设计如此**（故意失败的冒烟测试） |
| `smoke_crash` | intentional crash for smoke test | **设计如此** |
| `trial_tower` | 78/1480 sub-test(s) failed | **预存失败**（非本次引入） |
| `save_dto_contract` | 2/68 sub-test(s) failed | **预存失败** |
| `bm_s3_sell_guard` | 4/20 sub-test(s) failed | **预存失败** |

### 变更前基线失败列表（Step 2 完成后 6404c07）

完全相同的 5 个测试，相同的失败数目。

### 对比结论

新增失败数 = **0**，无回归。

---

## 7. 文档更新

| 项目 | 值 |
|------|------|
| 更新的文档文件 | `docs/2026-05-30-origin-main-bigfile-refactor-plan.md` |
| Step 执行日志起始位置 | 文件末尾（§12 执行日志区域），约第 1264 行起 |
| 修改的关键数字 | EquipmentData 行数 3449→252; EXEMPTIONS 变化; 21 PASS / 5 FAIL; commit `23b756c` |
| 文档与代码是否一致 | **yes** |

---

## 8. 风险与遗留

### 当前仍超预算的文件列表（EXEMPTIONS）

| 文件 | 当前行数 | 豁免上限 | 备注 |
|------|---------|---------|------|
| `config/MonsterData.lua` | 3698 | 3750 | Step 4 目标 |
| `config/EquipmentData_Special.lua` | 2012 | 2050 | 本次新增，纯数据，后续可按章节再拆 |
| `config/MonsterTypes_ch3.lua` | 2205 | 2250 | Step 5 目标 |
| `rendering/EffectRenderer.lua` | 3561 | 3600 | Step 6 目标 |
| `rendering/TileRenderer.lua` | 3301 | 3350 | Step 7 目标 |
| `rendering/EntityRenderer.lua` | 3298 | 3350 | Step 7 目标 |
| `ui/PetPanel.lua` | 2175 | 2225 | 第二梯队 |
| `config/MonsterTypes_ch5.lua` | 940 | 1000 | 第二梯队 |
| `rendering/DecoDivine.lua` | 1398 | 1450 | 第二梯队 |

### 当前仍依赖平台特性的脚本

无（本次拆分仅涉及纯 Lua 数据表，不依赖平台 API）。

### 本阶段未处理但会影响下一阶段验收的问题

- `EquipmentData_Special.lua`（2012 行）仍超 DATA_TARGET=900，已设 EXEMPTION=2050 作为棘轮。后续可按章节（ch1-ch5）再拆，但不阻塞本阶段验收。

### 是否存在"文档说有、代码里没有"的对象

**否**。facade 文件、所有子模块路径、测试结果均与文档和代码一致。

---

## 9. 拆分后子模块预算检查

| 子模块 | 行数 | 适用预算 | 是否达标 |
|--------|------|---------|---------|
| `EquipmentData.lua` (facade) | 252 | DATA_TARGET=900 | ✅ 达标 |
| `EquipmentData_Special.lua` | 2012 | EXEMPTION=2050 | ✅ 受豁免保护 |
| `EquipmentData_Collection.lua` | 665 | DATA_TARGET=900 | ✅ 达标 |
| `EquipmentData_Forge.lua` | 535 | DATA_TARGET=900 | ✅ 达标 |

---

## 10. 关键代码片段

### facade 尾部（子模块加载，EquipmentData.lua:248-252）

```lua
-- ===================== 子模块加载 =====================
EquipmentData.SpecialEquipment = require("config.EquipmentData_Special")
EquipmentData.Collection = require("config.EquipmentData_Collection")
require("config.EquipmentData_Forge")(EquipmentData)

return EquipmentData
```

### Forge 闭包自引用（EquipmentData_Forge.lua:272）

```lua
EquipmentData.LINGQI_FORGE_SLOTS = EquipmentData.STANDARD_SLOTS  -- 与掉落一致
```

### EXEMPTIONS 变更区域（test_file_budget.lua:53-55）

```lua
-- [已毕业] config/EquipmentData.lua — 252 行 facade，已在 DATA_TARGET(900) 内，Step 3 拆分
["config/EquipmentData_Special.lua"] = 2050,  -- 当前 2012（纯数据表，后续按章节再拆）
```

---

*报告生成时间: 2026-05-31*
*验收 AI commit: 23b756cff90063c85d12b323fd2e62e513068dff*
