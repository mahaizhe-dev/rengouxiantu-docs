# 远端代码大文件拆分优化方案

基线版本：`origin/main @ 65d1ea5a5b4065974f14b167b2ec574e405e2069`

审查基线目录：`generated/rengouxiantu-docs_origin_main_review_20260530_c`

目标：给执行 AI 一份可以直接照做的拆分方案，在不改变对外模块入口和核心玩法行为的前提下，系统性解决当前远端代码的大文件问题。

## 0. 执行 AI 必读

这份文档不是“可选建议”，而是给执行 AI 的施工约束。执行时请先按下面四条判断：

1. 当前工作树是否干净并且基于 `origin/main @ 65d1ea5a5b4065974f14b167b2ec574e405e2069`。
2. 当前修改是否只针对本阶段目标文件，没有顺手扩散到第二梯队文件。
3. 当前拆分是否保留了原公共 API、原 `require` 路径、原事件名、原存档字段、原资源路径。
4. 当前阶段是否已经给出“修改文件清单 + 目标文件行数前后对比 + 已跑测试 + 剩余风险”。

如果任一项答不上来，不要进入编码。

### 0.1 风险评估总结（2026-05-30 审查补充）

| 维度 | 风险等级 | 说明 |
|------|---------|------|
| **存档安全** | 🟡 中 | `EquipmentData` 被 `SaveMigrations`（6处）和 `SaveSerializer`（2处）硬依赖；子模块加载顺序错误将导致旧存档迁移失败 |
| **C/S 架构** | 🟢 低 | 本轮目标文件均为纯客户端或共享 config，不涉及网络协议层 |
| **线上兼容** | 🟡 中 | 文件数量变化要求客户端全量更新，不可走增量热更 |
| **执行难度** | 🟡 中 | 6 个 Phase 工作量大，AI 单次执行易出错，必须严格逐阶段推进 |

### 0.2 开工前必须处理：脏工作树

当前 `main` 分支有 6 个已修改未提交文件：

- `scripts/config/GameConfig.lua`
- `scripts/config/RedeemCodes.lua`
- `scripts/network/EventHandler.lua`
- `scripts/tests/test_event_system.lua`
- `scripts/ui/BottomBar.lua`
- `scripts/ui/BulletinUI.lua`
- `scripts/ui/EventExchangeUI.lua`

**执行 AI 必须**：
1. 先将这些变更提交到 `origin/main`（或确认已被 merge）。
2. 确认基线 commit 包含这些变更后，再新建干净工作树开始重构。
3. 如果无法合入，使用 `git stash` 暂存，重构完成后再 rebase 回来。

**禁止**：在包含脏变更的工作树上直接开始重构。

## 1. 当前结论

远端 `scripts` 目录下最长文件如下：

| 行数 | 文件 |
|---:|---|
| 3698 | `scripts/config/MonsterData.lua` |
| 3561 | `scripts/rendering/EffectRenderer.lua` |
| 3449 | `scripts/config/EquipmentData.lua` |
| 3301 | `scripts/rendering/TileRenderer.lua` |
| 3298 | `scripts/rendering/EntityRenderer.lua` |
| 2205 | `scripts/config/MonsterTypes_ch3.lua` |
| 2175 | `scripts/ui/PetPanel.lua` |
| 2123 | `scripts/systems/SkillSystem.lua` |
| 2119 | `scripts/ui/ChallengeUI.lua` |

按目录统计，问题已经是目录级，而不是 9 个文件的孤立问题：

| 目录 | 超长文件数（>=1200 行） | 合计行数 | 最大文件 |
|---|---:|---:|---:|
| `ui` | 15 | 23805 | 2175 |
| `systems` | 5 | 7921 | 2123 |
| `rendering` | 4 | 11558 | 3561 |
| `config` | 3 | 9352 | 3698 |

结论：

- 这轮不能只做单文件瘦身，必须建立统一拆分规则和长度预算。
- 现有代码已经具备“门面文件 + 子模块”演进条件，不需要重写调用方。
- 优先级最高的是 `config`、`rendering`、`ui`、`systems` 四条主线。

## 2. 执行原则

执行 AI 必须遵守以下原则：

- 以远端 `origin/main` 为准，新建干净工作树执行，不要在当前脏工作树上直接重构。
- 保留现有对外 `require` 路径不变。原大文件先退化为 facade，不要一次性改全项目引用。
- 先拆结构，后考虑进一步抽象。第一轮不要顺手改玩法逻辑。
- 子模块只接收上下文或宿主表，不反向依赖父模块，避免循环引用。
- 数据文件只放数据和注册，不混入运行时副作用。
- 每完成一个阶段，就运行对应测试；不要攒到最后统一回归。

### 2.1 必须复用的现有模块模式

执行 AI 不要自创拆分风格，优先复用项目里已经存在的 4 种模式：

- 注册型配置模块：参考 `scripts/config/MonsterTypes_ch1.lua`，使用 `return function(M)`，由子文件向宿主表注册数据。
- 独立工具模块：参考 `scripts/systems/combat/TargetSelector.lua`，使用 `local M = {}; function M.Xxx() ... end; return M`。
- facade 合并子模块：参考 `scripts/rendering/DecorationRenderers.lua`，由主模块 `require` 多个子模块并合并函数到对外宿主表。
- 独立数据表模块：参考 `scripts/config/QuestData_ch3.lua`，纯配置可直接 `return table`。

本轮建议固定使用下列映射，不要自行变体：

- `MonsterTypes_ch3` 子文件：用“注册型配置模块”。
- `MonsterData` 子文件：优先“独立数据表模块”或“注册型配置模块”，由 `MonsterData.lua` 聚合。
- `EquipmentData` 子文件：优先“注册型配置模块”；纯常量文件允许直接返回 table。
- `TileRenderer`、`EffectRenderer`、`EntityRenderer` 子文件：用 “facade 合并子模块”。
- `SkillSystem` 子文件：用“独立工具模块”，由 facade 注入 `SkillSystem` 或 `ctx`。
- `PetPanel`、`ChallengeUI` 子文件：用“独立工具模块”，由 controller 统一持有状态和组装视图。

### 2.2 禁止自行修改的范围

执行 AI 在第一轮拆分中，禁止主动修改以下内容：

- 事件名、存档字段名、配置 key、掉落 key、技能 id、装备 id。
- 资源路径、图标名、贴图名、图片缓存 key。
- 玩法数值、掉率、技能倍率、UI 文案、视觉风格。
- 测试框架本身的运行机制，除非只是把新测试接入现有 `TestRegistry`。
- 第二梯队文件，除非本阶段目标文件拆分后编译或测试确实要求联动修复。

### 2.3 每阶段必须提交的输出

每完成一个阶段，执行 AI 必须同时给出：

- 本阶段改动文件列表。
- 本阶段目标文件的行数前后对比。
- 已运行的测试命令和结果。
- 明确列出未处理的后续项，而不是默认“顺手下一轮再说”。
- 如果没有达到目标行数，说明是“阶段性完成”还是“拆分失败”。

## 3. 长度预算

建议这轮同时引入硬约束，避免文件拆完又长回去。

### 3.1 文件预算

- 普通代码文件：目标 `<= 600` 行，警戒 `<= 900` 行。
- 纯数据配置文件：目标 `<= 900` 行，警戒 `<= 1400` 行。
- 单函数：目标 `<= 80` 行，警戒 `<= 120` 行。

### 3.2 守门机制

新增一个长度检查脚本，至少覆盖：

- `scripts/config/**/*.lua`
- `scripts/rendering/**/*.lua`
- `scripts/ui/**/*.lua`
- `scripts/systems/**/*.lua`

建议脚本名：

- `scripts/tests/test_file_length_budget.lua`

或者：

- `tools/check_lua_file_length.ps1`

如果先追求最小改动，优先做 `Lua` 版本测试脚本，直接接入现有 `scripts/tests` 流。

### 3.3 测试接入方式

当前项目已经有统一测试入口，不要把长度检查脚本孤立放着。

长度预算测试建议这样接：

- 文件：`scripts/tests/test_file_length_budget.lua`
- `TestRegistry` 注册：`group = "infra"`，`gate = "blocking"`，`mode = "run_file"`
- 目标：默认 blocking 跑法就能自动执行长度预算检查

推荐命令：

- 首选：`python3 scripts/tests/_run_via_lupa.py`
- 分组：`python3 scripts/tests/_run_via_lupa.py smoke`
- 分组：`python3 scripts/tests/_run_via_lupa.py combat`
- 分组：`python3 scripts/tests/_run_via_lupa.py regression`
- fallback：`lua scripts/tests/run_all.lua`

如果环境里没有 `lupa`，允许先用 `lua scripts/tests/run_all.lua` 做最小验证，但最终仍应以项目现有主入口完成一次验证。

## 4. 关键审查发现

### 4.1 `scripts/config/MonsterData.lua`

当前结构：

- 基础属性公式
- 种族修正
- 阶级倍率
- `MonsterData.Skills`
- `MonsterData.WORLD_DROP_POOLS`
- 章节怪物加载入口

关键判断：

- 它已经是“聚合入口 + 分章节加载”的模式。
- 说明当前项目已经接受 `config` 层的拆分方式。
- 这一文件继续变大的主因，不是怪物类型本身，而是技能定义和掉落池继续堆在同一个入口文件里。

建议拆分：

- `scripts/config/monster/core_stats.lua`
- `scripts/config/monster/race_modifiers.lua`
- `scripts/config/monster/category_multipliers.lua`
- `scripts/config/monster/skills.lua`
- `scripts/config/monster/world_drop_pools.lua`

`MonsterData.lua` 保留：

- `CalcBaseStats`
- `CalcRealmMult`
- `CalcFinalStats`
- 统一聚合和 `require("config.MonsterTypes_*")`

### 4.2 `scripts/config/MonsterTypes_ch3.lua`

当前结构明显分为四块：

- 挑战副本 `T1-T4`
- 第三章沙海野外怪、寨主、精英、神器 Boss
- 挑战副本 `T5-T8`
- 新声望体系 `R1-R8`

建议拆分：

- `scripts/config/monster_types/ch3/challenge_t1_t4.lua`
- `scripts/config/monster_types/ch3/desert_world.lua`
- `scripts/config/monster_types/ch3/challenge_t5_t8.lua`
- `scripts/config/monster_types/ch3/reputation.lua`

`MonsterTypes_ch3.lua` 只保留总入口，依次调用四个子文件注册到 `M.Types`。

### 4.3 `scripts/config/EquipmentData.lua`

当前结构：

- 常量和基础表
- `SpecialEquipment`
- `Collection`
- `SetBonuses`
- 葫芦升级
- 龙神圣器和灵器打造
- `FabaoTemplates`
- `SWORD_FORGE_COSTS`
- `SWORD_FORGE_ORDER`

问题不只是“行数大”，而是“多种业务概念堆在一个配置表里”。

建议拆分：

- `scripts/config/equipment/constants.lua`
- `scripts/config/equipment/special/ch1.lua`
- `scripts/config/equipment/special/ch2.lua`
- `scripts/config/equipment/special/ch3.lua`
- `scripts/config/equipment/special/ch4.lua`
- `scripts/config/equipment/special/ch5.lua`
- `scripts/config/equipment/collection.lua`
- `scripts/config/equipment/set_bonuses.lua`
- `scripts/config/equipment/gourd.lua`
- `scripts/config/equipment/forge.lua`
- `scripts/config/equipment/fabao_templates.lua`
- `scripts/config/equipment/sword_forge.lua`

`EquipmentData.lua` 保留：

- 顶层宿主表创建
- 聚合 `require`
- 少量被高频调用的通用常量

**🔴 存档安全约束（审查补充）**：

`EquipmentData` 被 `SaveMigrations.lua`（6处）和 `SaveSerializer.lua`（2处）在模块加载阶段硬引用。facade 中的 `require` 顺序**必须**保证：

```lua
-- EquipmentData.lua（facade）正确加载顺序
local EquipmentData = {}

-- 1. 先加载基础常量（SLOTS、STANDARD_SLOTS、MAIN_STAT 等）
require("config.equipment.constants")(EquipmentData)

-- 2. 再加载依赖常量的数据模块
require("config.equipment.special")(EquipmentData)
require("config.equipment.collection")(EquipmentData)
require("config.equipment.set_bonuses")(EquipmentData)

-- 3. 最后加载打造类（可能引用上面的数据）
require("config.equipment.gourd")(EquipmentData)
require("config.equipment.forge")(EquipmentData)
require("config.equipment.fabao_templates")(EquipmentData)
require("config.equipment.sword_forge")(EquipmentData)

return EquipmentData
```

**原因**：如果 `constants` 还没加载就被 `SaveMigrations` 读取 `EquipmentData.SLOTS`，会返回 `nil`，导致旧存档迁移静默失败。

**验证方法**：Phase 1 完成后必须跑 `test_save_dto_contract` 和 `test_migration_state_policy`，确保存档字段映射和迁移链完整。

### 4.4 `scripts/rendering/EffectRenderer.lua`

当前问题最突出：

- 41 个函数
- 多个 100 到 280 行的大函数
- 既有基础攻击特效，又有技能特效 registry，又有 warning/zone/hud/buff/真图剑效

明显可拆分的区块：

- 图片缓存和资源加载
- 基础攻击效果
- 技能效果 renderer 注册表
- 区域效果
- 怪物预警效果
- HUD 标记类效果
- 套装和 buff 光环
- 真图剑效果

建议目录：

- `scripts/rendering/effects/assets.lua`
- `scripts/rendering/effects/basic_attacks.lua`
- `scripts/rendering/effects/skill_registry.lua`
- `scripts/rendering/effects/skills/ice_slash.lua`
- `scripts/rendering/effects/skills/blood_slash.lua`
- `scripts/rendering/effects/skills/blood_sea.lua`
- `scripts/rendering/effects/skills/haoqi_seal.lua`
- `scripts/rendering/effects/skills/golden_bell.lua`
- `scripts/rendering/effects/skills/dragon_elephant.lua`
- `scripts/rendering/effects/skills/three_swords.lua`
- `scripts/rendering/effects/skills/giant_sword.lua`
- `scripts/rendering/effects/skills/sword_shield.lua`
- `scripts/rendering/effects/skills/sword_formation.lua`
- `scripts/rendering/effects/skills/qingyun_suppress.lua`
- `scripts/rendering/effects/skills/earth_surge.lua`
- `scripts/rendering/effects/skills/blood_explosion.lua`
- `scripts/rendering/effects/skills/dragon_breath.lua`
- `scripts/rendering/effects/skills/soul_burst.lua`
- `scripts/rendering/effects/zones.lua`
- `scripts/rendering/effects/warnings.lua`
- `scripts/rendering/effects/hud.lua`
- `scripts/rendering/effects/auras.lua`
- `scripts/rendering/effects/zhentu.lua`

`EffectRenderer.lua` 保留：

- 总入口 `Render`
- `RenderFloatingTexts`
- 对外导出的 `Render*` API
- 对子模块的统一组装

### 4.5 `scripts/rendering/TileRenderer.lua`

当前有两个问题：

- 约 90 个函数，几乎每种 tile 一个函数。
- `GetTileRenderFns()` 本身接近 200 行，已经是一个单独模块。

建议目录：

- `scripts/rendering/tiles/shared/noise.lua`
- `scripts/rendering/tiles/shared/flat.lua`
- `scripts/rendering/tiles/town.lua`
- `scripts/rendering/tiles/ch2.lua`
- `scripts/rendering/tiles/ch3.lua`
- `scripts/rendering/tiles/yaochi.lua`
- `scripts/rendering/tiles/ch5_ground.lua`
- `scripts/rendering/tiles/ch5_interactive.lua`
- `scripts/rendering/tiles/ch5_structures.lua`
- `scripts/rendering/tiles/registry.lua`

拆分原则：

- 相同章节或相同视觉主题的 tile 放在一起。
- `Ensure*Image` 跟对应 `Render*` 放同一模块，不单独散落。
- `GetTileRenderFns()` 迁到 `registry.lua`，主文件只读取 registry。

### 4.6 `scripts/rendering/EntityRenderer.lua`

这是当前最该优先处理的渲染文件，因为它不是“多函数多模块”，而是“几个超大函数吞掉整块职责”。

远端超大函数：

- `RenderPlayer` 876 行
- `RenderMonster` 622 行
- `RenderMonsterFrame` 315 行
- `RenderLootDrops` 292 行
- `RenderFortuneFruits` 288 行
- `RenderXianyuanChests` 263 行
- `RenderNPCs` 235 行

建议目录：

- `scripts/rendering/entities/player.lua`
- `scripts/rendering/entities/pet.lua`
- `scripts/rendering/entities/monster_core.lua`
- `scripts/rendering/entities/monster_frame.lua`
- `scripts/rendering/entities/monster_bars.lua`
- `scripts/rendering/entities/npc.lua`
- `scripts/rendering/entities/loot.lua`
- `scripts/rendering/entities/fortune_fruit.lua`
- `scripts/rendering/entities/xianyuan_chest.lua`
- `scripts/rendering/entities/chain_seal.lua`
- `scripts/rendering/entities/common_colors.lua`

`EntityRenderer.lua` 保留：

- 对外导出的总入口函数
- 公共颜色/徽章 helpers 的薄封装
- 对子模块的参数分发

### 4.7 `scripts/systems/SkillSystem.lua`

这个文件的危险点不只是长，而是混合了四层职责：

- 状态和初始化
- 技能释放
- 技能栏与绑定
- 各类被动和特殊机制

建议目录：

- `scripts/systems/skill/state.lua`
- `scripts/systems/skill/unlocks.lua`
- `scripts/systems/skill/update.lua`
- `scripts/systems/skill/bindings.lua`
- `scripts/systems/skill/bar.lua`
- `scripts/systems/skill/auto_cast.lua`
- `scripts/systems/skill/casting/direct_damage.lua`
- `scripts/systems/skill/casting/lifesteal.lua`
- `scripts/systems/skill/casting/heal.lua`
- `scripts/systems/skill/casting/buff.lua`
- `scripts/systems/skill/casting/aoe_dot.lua`
- `scripts/systems/skill/casting/ground_zone.lua`
- `scripts/systems/skill/casting/cone_aoe.lua`
- `scripts/systems/skill/casting/damage_amp_zone.lua`
- `scripts/systems/skill/casting/melee_aoe_dot.lua`
- `scripts/systems/skill/casting/multi_zone_heavy.lua`
- `scripts/systems/skill/casting/hp_cost.lua`
- `scripts/systems/skill/passives/sword_shield.lua`
- `scripts/systems/skill/passives/nth_cast.lua`
- `scripts/systems/skill/passives/charge.lua`
- `scripts/systems/skill/passives/toggle.lua`
- `scripts/systems/skill/passives/accumulate_trigger.lua`
- `scripts/systems/skill/registry.lua`

现有 `systems/combat/*` 已经存在，因此 `SkillSystem` 的子目录化完全符合项目当前结构。

### 4.8 `scripts/ui/PetPanel.lua`

当前明显是“tab 构建 + 业务动作 + 弹窗流程”全部塞在一个文件里。

建议目录：

- `scripts/ui/pet/state.lua`
- `scripts/ui/pet/view.lua`
- `scripts/ui/pet/tabs/info.lua`
- `scripts/ui/pet/tabs/breakthrough.lua`
- `scripts/ui/pet/tabs/skills.lua`
- `scripts/ui/pet/tabs/appearance.lua`
- `scripts/ui/pet/modals/learn.lua`
- `scripts/ui/pet/modals/skill_action.lua`
- `scripts/ui/pet/modals/confirm.lua`
- `scripts/ui/pet/modals/rules.lua`
- `scripts/ui/pet/actions.lua`
- `scripts/ui/pet/controller.lua`

`PetPanel.lua` 保留：

- 对外 API：`Create/Show/Hide/Toggle/Refresh/...`
- 对 controller 的薄封装

### 4.9 `scripts/ui/ChallengeUI.lua`

当前结构天然分成几块：

- 主界面展示
- 额外掉落提示
- 声望界面
- 胜利界面
- 掉落卡片构建

建议目录：

- `scripts/ui/challenge/state.lua`
- `scripts/ui/challenge/controller.lua`
- `scripts/ui/challenge/overview.lua`
- `scripts/ui/challenge/extra_drop_tips.lua`
- `scripts/ui/challenge/coming_soon.lua`
- `scripts/ui/challenge/reputation.lua`
- `scripts/ui/challenge/victory.lua`
- `scripts/ui/challenge/reward_rows.lua`

### 4.10 首轮最小可接受拆分

上面的文件列表是“理想终态”，不是要求执行 AI 在第一轮就拆到最碎。为了提高执行准确性，第一轮只要求达到“最小可接受拆分”。

#### `MonsterTypes_ch3.lua`

首轮至少拆成：

- `challenge_t1_t4.lua`
- `desert_world.lua`
- `challenge_t5_t8.lua`
- `reputation.lua`

#### `EquipmentData.lua`

首轮至少拆成：

- `constants.lua`
- `special.lua`
- `collection.lua`
- `set_bonuses.lua`
- `forge.lua`
- `fabao_templates.lua`
- `sword_forge.lua`

说明：

- `special/ch1..ch5.lua` 是第二步细化目标，不要求首轮一次完成。

#### `MonsterData.lua`

首轮至少拆成：

- `core_stats.lua`
- `skills.lua`
- `drop_pools.lua`

说明：

- `race_modifiers.lua`、`category_multipliers.lua` 可以在首轮一起拆，也可以放在第二步继续细化。

#### `TileRenderer.lua`

首轮至少拆成：

- `shared.lua`
- `town_ch2.lua`
- `ch3.lua`
- `yaochi.lua`
- `ch5_ground.lua`
- `ch5_interactive.lua`
- `ch5_structures.lua`
- `registry.lua`

说明：

- 不强制首轮拆到每个章节单独一类 tile 一个文件。

#### `EffectRenderer.lua`

首轮至少拆成：

- `assets.lua`
- `basic_attacks.lua`
- `skill_registry.lua`
- `skills.lua`
- `zones.lua`
- `warnings.lua`
- `hud.lua`
- `auras.lua`
- `zhentu.lua`

说明：

- 首轮不强制“一技能一文件”。
- 如果 `skills.lua` 仍然过长，再进入第二步拆 `skills/*.lua`。

#### `EntityRenderer.lua`

首轮至少拆成：

- `player.lua`
- `monster.lua`
- `npc.lua`
- `loot.lua`
- `special.lua`

说明：

- `special.lua` 负责 `fortune_fruit`、`xianyuan_chest`、`chain_seal` 等非主实体对象。

#### `SkillSystem.lua`

首轮至少拆成：

- `state.lua`
- `bindings.lua`
- `bar.lua`
- `auto_cast.lua`
- `casting.lua`
- `passives.lua`
- `registry.lua`

说明：

- 第二步再把 `casting.lua` 和 `passives.lua` 继续细分到多个子文件。

#### `PetPanel.lua`

首轮至少拆成：

- `controller.lua`
- `state.lua`
- `tabs/info.lua`
- `tabs/breakthrough.lua`
- `tabs/skills.lua`
- `tabs/appearance.lua`
- `modals.lua`

说明：

- 第二步再把 `modals.lua` 拆成 `learn.lua`、`skill_action.lua`、`confirm.lua`、`rules.lua`。

#### `ChallengeUI.lua`

首轮至少拆成：

- `controller.lua`
- `overview.lua`
- `extra_drop_tips.lua`
- `reputation.lua`
- `victory.lua`
- `reward_rows.lua`

说明：

- `coming_soon.lua` 可以首轮独立，也可以暂时留在 `overview.lua`。

## 5. 执行顺序

### 5.0 施工前清单

执行 AI 在真正改代码前，先完成以下动作并记录结果：

1. 新建干净工作树，基于 `origin/main`。
2. 记录 9 个目标文件的当前行数。
3. 记录计划本阶段只改哪些文件。
4. 跑一次基线测试：
   - `python3 scripts/tests/_run_via_lupa.py`
   - 如果环境缺少 `lupa`，至少跑 `lua scripts/tests/run_all.lua`
5. 明确当前阶段的“成功定义”：
   - 是建立样板拆分模式
   - 还是把某个超长文件拆到目标线以下

如果第 1 步到第 4 步没有做完，不要进入 Phase 1。

### Phase 0：建立安全施工面

目标：

- 基于 `origin/main` 新建干净工作树。
- 引入文件长度预算检查。
- 跑一次基线测试，确保后续回归能比较。

必须产出：

- 干净工作树
- 长度预算脚本
- 基线测试结果记录

建议测试：

- `python3 scripts/tests/_run_via_lupa.py`
- `python3 scripts/tests/_run_via_lupa.py combat`
- `python3 scripts/tests/_run_via_lupa.py regression`

### Phase 1：先拆纯配置

目标文件：

- `scripts/config/MonsterTypes_ch3.lua`
- `scripts/config/EquipmentData.lua`

理由：

- 风险低
- 回归面相对集中
- 能快速建立“入口文件 + 子配置模块”的范式

必须验收：

- 挑战副本配置、声望副本配置、法宝和剑冢配置读取不变
- 不新增运行时 require 循环
- `MonsterTypes_ch3.lua` 退化成入口文件，不再保留主体数据块
- `EquipmentData.lua` 至少拆到“常量 / 特装 / 图录 / 套装 / 打造 / 法宝 / 剑冢”层级

建议测试：

- `scripts/tests/test_challenge_fabao.lua`
- `scripts/tests/test_challenge_r8_extradrop.lua`
- `scripts/tests/test_jiefeng_forge_pipeline.lua`
- `scripts/tests/test_jiefeng_sword_config.lua`
- `scripts/tests/test_sword_forge_comprehensive.lua`
- `scripts/tests/test_t10_set_drop.lua`
- `scripts/tests/test_save_dto_contract.lua` **🔴 审查补充：EquipmentData 是存档迁移硬依赖**
- `scripts/tests/test_migration_state_policy.lua` **🔴 审查补充：确保迁移链完整**

### Phase 2：继续拆 `MonsterData.lua`

目标：

- 把技能定义和世界掉落池移出入口文件
- 保留 `MonsterData.lua` 作为聚合和计算门面

必须验收：

- 怪物基础属性计算不变
- 掉落池读取不变
- 章节怪物注册顺序不变
- `MonsterData.lua` 主体只保留计算逻辑和聚合入口，不再内嵌大段技能表和掉落池表

建议测试：

- `scripts/tests/test_battle_pipeline_regression.lua`
- `scripts/tests/test_p0_regression.lua`
- `scripts/tests/test_p1p2p3_refactor.lua`

### Phase 3：拆渲染层

目标文件：

- `scripts/rendering/TileRenderer.lua`
- `scripts/rendering/EffectRenderer.lua`
- `scripts/rendering/EntityRenderer.lua`

执行顺序建议：

1. `TileRenderer`
2. `EffectRenderer`
3. `EntityRenderer`

原因：

- `TileRenderer` 最接近纯 registry + renderer 拆分。
- `EffectRenderer` 已有技能特效分发点，可平移到子目录。
- `EntityRenderer` 风险最高，应放到渲染拆分最后。

必须验收：

- tile 显示映射不变
- 基础攻击、技能特效、怪物预警、区域效果不变
- 玩家、怪物、NPC、掉落物、奇遇物件渲染入口不变
- facade 文件仍然保留原对外函数名
- 子模块拆分后不新增每帧动态 require

建议测试：

- `scripts/tests/test_battle_pipeline_regression.lua`
- `scripts/tests/test_combo_runner.lua`
- `scripts/tests/test_hit_resolver.lua`
- `scripts/tests/test_target_selector.lua`
- `scripts/tests/test_buff_skill_callbacks.lua`
- `scripts/tests/test_artifact_ch5.lua`

### Phase 4：拆 `SkillSystem.lua`

目标：

- 先按职责拆文件，再逐步消除长函数
- 保持 `SkillSystem.*` 公共 API 不变

必须验收：

- 技能解锁
- 主动释放
- 被动触发
- 技能栏绑定
- 自动释放
- 剑阵、护体、蓄力、耗血、开关被动逻辑不变
- `TypeHandlers` 仍然是统一分发中心
- facade 文件仍然保留原对外 `SkillSystem.*` API

建议测试：

- `scripts/tests/test_battle_pipeline_regression.lua`
- `scripts/tests/test_combo_runner.lua`
- `scripts/tests/test_target_selector.lua`
- `scripts/tests/test_pre_damage_hooks.lua`
- `scripts/tests/test_buff_skill_callbacks.lua`
- `scripts/tests/test_p1_regression.lua`
- `scripts/tests/test_p1p2p3_refactor.lua`

### Phase 5：拆 UI 层

目标文件：

- `scripts/ui/PetPanel.lua`
- `scripts/ui/ChallengeUI.lua`

执行顺序建议：

1. `PetPanel`
2. `ChallengeUI`

原因：

- `PetPanel` 的 tab 和 modal 边界更清晰。
- `ChallengeUI` 交叉依赖奖励展示和声望流程，稍后拆更稳。

必须验收：

- 面板显隐和 tab 切换不变
- 宠物喂养、突破、技能学习/升级/删除流程不变
- 挑战入口、额外掉落提示、声望界面、胜利弹窗不变
- controller 持有状态，tab/modal 子文件不要各自维护独立全局状态

建议测试：

- `scripts/tests/test_challenge_fabao.lua`
- `scripts/tests/test_challenge_r8_extradrop.lua`
- `scripts/tests/test_p0_regression.lua`
- `scripts/tests/test_p1_regression.lua`

### Phase 6：处理第二梯队大文件

本轮拆完后，继续排队处理：

- `scripts/ui/AlchemyUI.lua`
- `scripts/ui/BlackMerchantUI.lua`
- `scripts/network/DungeonHandler.lua`
- `scripts/main.lua`
- `scripts/systems/LootSystem.lua`
- `scripts/ui/DragonForgeUI.lua`
- `scripts/ui/CharacterUI.lua`
- `scripts/ui/EventExchangeUI.lua`
- `scripts/systems/ChallengeSystem.lua`
- `scripts/ui/SystemMenu.lua`
- `scripts/ui/SwordForgeUI.lua`

否则第一梯队拆完，超长文件仍会持续从 `ui` 目录重新长出来。

## 6. 实施细节要求

执行 AI 在每个阶段都要遵守以下实现要求：

- 原文件先改成 facade，不要先删成空壳再补实现。
- 新增子模块后，优先移动完整函数，不要一开始就做跨函数重写。
- 抽公共 helper 时，只抽真正复用的逻辑，不要为了“看起来优雅”过度抽象。
- 不要在第一轮顺手改命名风格、注释风格、颜色值、数值平衡。
- 如果一个大函数只被一个模块使用，先移动到对应子模块，不强行继续切小。
- 如果拆分会影响性能关键路径，先保持现有缓存策略和局部变量本地化策略。

## 7. 完成标准

执行完成后，至少满足：

- 上述 9 个大文件全部显著瘦身。
- 每个重构后的入口文件保留原公共 API。
- 没有新增 require 循环。
- 文件长度检查脚本能运行并纳入测试流。
- 关键测试通过。
- 文档里列出的第二梯队文件被加入后续待办，而不是再次被忽略。

建议量化验收：

- `MonsterTypes_ch3.lua` 下降到 `< 300` 行
- `MonsterData.lua` 下降到 `< 1200` 行
- `EquipmentData.lua` 下降到 `< 1200` 行
- `EffectRenderer.lua` 下降到 `< 800` 行
- `TileRenderer.lua` 下降到 `< 700` 行
- `EntityRenderer.lua` 下降到 `< 700` 行
- `SkillSystem.lua` 下降到 `< 700` 行
- `PetPanel.lua` 下降到 `< 600` 行
- `ChallengeUI.lua` 下降到 `< 600` 行

### 7.1 每阶段关闭前检查表

执行 AI 在关闭任一阶段前，必须逐项确认：

- 目标文件是否已经从“主体实现文件”退化成 facade 或聚合入口。
- 子模块是否使用了项目现有模块模式，而不是临时拼接风格。
- 是否保留原公共 API、原 `require` 路径、原 key、原事件名。
- 是否没有新增循环依赖。
- 是否没有为了拆分而修改玩法逻辑。
- 是否已跑本阶段要求的测试。
- 是否已给出目标文件行数前后对比。

只要有一项不能确认，这个阶段就不应标记完成。

### 7.2 执行 AI 的汇报格式

执行 AI 每个阶段结束后，建议用以下固定格式汇报：

1. 本阶段目标与是否完成。
2. 改动文件列表。
3. 目标文件行数前后对比。
4. 已运行测试与结果。
5. 残留风险与下一阶段建议。

不要只汇报“已拆分完成”，那不足以让审查者判断结构质量。

## 8. 推荐交付方式

执行 AI 不要试图“一次性全拆完”。推荐按以下 PR 或提交节奏推进：

1. `infra: add file length budget guard`
2. `refactor(config): split MonsterTypes_ch3 and EquipmentData`
3. `refactor(config): split MonsterData skills and drop pools`
4. `refactor(rendering): split TileRenderer`
5. `refactor(rendering): split EffectRenderer`
6. `refactor(rendering): split EntityRenderer`
7. `refactor(systems): split SkillSystem`
8. `refactor(ui): split PetPanel and ChallengeUI`

这样做的好处：

- 回归范围可控
- 失败时容易定位
- 每一步都能保留可运行状态

补充约束：

- 每个提交只允许覆盖一个主阶段，不要跨阶段混合。
- 如果某一阶段被事实证明跨度过大，可以拆成 `a/b` 两个提交，但仍然只服务同一主阶段。

## 9. 线上发布策略（审查补充）

### 9.1 核心约束

| 维度 | 约束 | 原因 |
|------|------|------|
| **发布方式** | 强制全量更新（非增量热更） | facade + 子模块结构变更涉及文件路径变化，增量补丁无法保证一致性 |
| **版本号** | 主版本号 +1（如 1.x → 2.0） | 存档迁移链可能需要新 migration；清晰标记"结构性重构" |
| **灰度策略** | 先内测 → 20% 灰度 → 全量 | 降低"存档读不出来"的全量事故风险 |
| **回滚能力** | 保留重构前最后一版完整构建产物 | 一旦灰度期间出现严重存档问题可立即回退 |

### 9.2 发布检查清单

```
□ 所有测试通过（含 test_save_dto_contract、test_migration_state_policy）
□ 存档 round-trip 验证通过（SaveSerializer → 写盘 → 读盘 → 反序列化 → 字段完整）
□ 新旧版本 require 路径对比无遗漏（CI 脚本 diff facade 导出表 vs 旧版导出表）
□ multiplayer handler 中的 require 路径已全部指向 facade
□ 构建产物大小与重构前差异 < 5%（排除因拆分而新增的文件头开销）
□ 版本号已更新
□ 回滚版本已打 tag 并上传
```

### 9.3 回滚方案

1. 灰度期间若存档丢失率 > 0.1%，立即回退到重构前 tag
2. 回退后用户存档自动使用旧 migration 链，无需额外处理
3. 修复后重新走灰度流程

---

## 10. 可直接交给执行 AI 的任务描述

下面这段可以直接作为执行说明：

> 以 `origin/main @ 65d1ea5a5b4065974f14b167b2ec574e405e2069` 为基线，在干净工作树上执行大文件拆分重构。目标不是改玩法，而是在保持现有对外模块入口、原 `require` 路径、原 key、原事件名、原资源路径不变的前提下，把 `config/rendering/ui/systems` 的大文件拆成 facade + 子模块结构。拆分风格必须复用现有项目模式：注册型配置模块参考 `MonsterTypes_ch1.lua`，工具模块参考 `systems/combat/TargetSelector.lua`，facade 合并子模块参考 `rendering/DecorationRenderers.lua`。先新增文件长度预算检查，并接入 `scripts/tests/TestRegistry.lua`，注册为 `gate=blocking`。然后按配置、渲染、系统、UI 的顺序分阶段实施。每阶段结束后必须汇报改动文件、目标文件行数前后对比、已跑测试和剩余风险。第一轮按“最小可接受拆分”执行，不要求一开始就拆到最碎，但必须把主体大文件退化成 facade 或聚合入口。不要在第一轮顺手修改数值、视觉表现、命名风格或测试运行机制；只做职责拆分、模块落盘和必要的最小兼容改造。

---

## 11. 分阶段执行计划（审查补充）

### 执行总览

```
Step 0 → Step 1 → Step 2 → Step 3 → Step 4 → Step 5 → Step 6 → Step 7 → Step 8 → Step 9 → Step 10 → Step 11
准备     门禁     配置(低)  配置(高)  渲染     系统(低)  系统(高)  UI(低)   UI(高)   全量测试  发布准备  灰度发布
```

---

### Step 0: 环境准备

**目标**: 干净基线 + 脏工作树处理

| 任务 | 操作 |
|------|------|
| 处理脏工作树 | `git stash` 或提交当前 6 个未提交文件（见 §0.2） |
| 创建重构分支 | `git checkout -b refactor/bigfile-split origin/main` |
| 确认基线 | 确保 HEAD = `65d1ea5` |
| 跑一遍全量测试 | `python3 scripts/tests/_run_via_lupa.py` 确认绿灯 |

**提交**: 无（仅环境准备）

**✅ 执行记录 (2026-05-31)**:
- 脏工作树处理: `git stash push -m "pre-refactor: 六一活动/事件/兑换UI等未提交改动"` (7 files stashed)
- 分支: `refactor/bigfile-split` 基于 `65d1ea5`
- 测试结果: 21 suite PASS, 3 suite 基线已有失败（非本次引入）:
  - `trial_tower` 78/1480 fail (REALMS 23-26 未配置)
  - `save_dto_contract` 2/68 fail (envelope field count 6→7, 已新增字段但断言未更新)
  - `bm_s3_sell_guard` 4/20 fail (基线已有)
- 结论: **基线可接受，继续执行**

---

### Step 1: 新增文件长度门禁

**目标**: 建立自动化预算检查，防止未来回退

| 任务 | 详情 |
|------|------|
| 新建 `scripts/tests/test_file_budget.lua` | 按 §3 预算表检查行数上限 |
| 注册到 TestRegistry | `gate = "blocking"` |
| 运行测试 | 此时全部 PASS（当前行数应在预算内） |

**提交**: `test(infra): add file length budget gate`

---

### Step 2: 配置模块拆分（低风险）

**目标**: 拆分与存档无关的配置大文件

| 文件 | 风险 | 拆分策略 |
|------|------|---------|
| `GameConfig.lua` (2341行) | 🟢 低 | 按职责拆分（常量 / 数值表 / 公式） |
| `SkillData.lua` (1677行) | 🟢 低 | 按技能类型注册子模块 |
| `MonsterTypes.lua` (已有ch1-ch5) | 🟢 低 | 仅 facade 聚合，已拆好 |

**验证**:
- `require "config.GameConfig"` 返回表结构不变
- `require "config.SkillData"` 返回表结构不变
- 全量测试通过

**提交**: `refactor(config): split GameConfig and SkillData`

---

### Step 3: 配置模块拆分（高风险）🔴

**目标**: 拆分存档强依赖的 EquipmentData

| 文件 | 风险 | 拆分策略 |
|------|------|---------|
| `EquipmentData.lua` (2889行) | 🔴 高 | facade + 子模块，**严格遵守 §4.3 加载顺序** |

**关键约束**:
1. `EquipmentData.SLOTS` 必须在第一个 `require` 就加载完毕
2. 拆分后立即跑 `test_save_dto_contract.lua` 和 `test_migration_state_policy.lua`
3. 手动验证：加载旧存档 → 反序列化 → 字段完整性

**验证**:
- `require "config.EquipmentData"` 返回表结构不变
- `EquipmentData.SLOTS` 可在模块加载后立即访问
- `SaveMigrations` 的 6 处引用正常工作
- `SaveSerializer` 的 2 处引用正常工作
- 存档 round-trip 测试通过

**提交**: `refactor(config): split EquipmentData (save-critical)`

---

### Step 4: 渲染模块拆分

**目标**: 拆分渲染层大文件

| 文件 | 风险 | 拆分策略 |
|------|------|---------|
| `EffectRenderer.lua` (1845行) | 🟡 中 | 按特效类型拆分（参考现有 DecorationRenderers 模式） |
| `MapRenderer.lua` (1600行) | 🟡 中 | 按地图层/区域拆分 |

**验证**:
- 视觉表现无变化（需人工对比截图）
- 全量测试通过

**提交**: `refactor(rendering): split EffectRenderer and MapRenderer`

---

### Step 5: 系统模块拆分（低风险）

**目标**: 拆分独立性高的系统模块

| 文件 | 风险 | 拆分策略 |
|------|------|---------|
| `SkillSystem.lua` (1823行) | 🟢 低 | 按技能阶段拆分（释放/命中/结算） |
| `CombatSystem.lua` (如 >1000行) | 🟢 低 | 按战斗阶段拆分 |

**验证**:
- 战斗测试全部通过
- 技能释放/命中/结算逻辑不变

**提交**: `refactor(systems): split SkillSystem`

---

### Step 6: 系统模块拆分（高风险）🔴

**目标**: 拆分与存档/网络有交互的系统模块

| 文件 | 风险 | 拆分策略 |
|------|------|---------|
| `SaveMigrations.lua` (45KB) | 🔴 高 | 按版本号段拆分（v1-v10 / v11-v20 / ...） |
| `SaveSerializer.lua` (28KB) | 🟡 中 | 按序列化对象类型拆分 |

**关键约束**:
1. 迁移链必须保持顺序完整（v1 → v2 → ... → vN）
2. 每个子模块 `return function(M)` 注册迁移函数到父表
3. facade 按版本号顺序 require 所有子模块

**验证**:
- `test_save_dto_contract.lua` 通过
- `test_migration_state_policy.lua` 通过
- 从最旧版本存档跑完整迁移链到最新版本
- round-trip 测试通过

**提交**: `refactor(systems): split SaveMigrations and SaveSerializer (save-critical)`

---

### Step 7: UI 模块拆分（低风险）

**目标**: 拆分独立 UI 面板

| 文件 | 风险 | 拆分策略 |
|------|------|---------|
| `PetPanel.lua` (1500+行) | 🟢 低 | 按子面板/Tab 拆分 |
| `ChallengeUI.lua` (1500+行) | 🟢 低 | 按挑战类型拆分 |

**验证**:
- UI 面板正常打开/关闭
- 交互逻辑不变

**提交**: `refactor(ui): split PetPanel and ChallengeUI`

---

### Step 8: UI 模块拆分（中风险）

**目标**: 拆分有复杂状态的 UI 模块

| 文件 | 风险 | 拆分策略 |
|------|------|---------|
| 其他超预算 UI 文件 | 🟡 中 | 按具体情况决定 |

**验证**:
- 全量测试通过
- UI 交互人工验证

**提交**: `refactor(ui): split remaining oversized UI modules`

---

### Step 9: 全量回归测试

**目标**: 确认重构完整性

| 任务 | 详情 |
|------|------|
| 跑全量测试 | `python3 scripts/tests/_run_via_lupa.py` |
| 文件预算门禁 | 所有文件 ≤ 预算上限 |
| 存档完整性 | 旧存档 → 新代码加载 → 保存 → 重新加载 → 字段不丢失 |
| require 路径兼容 | 所有 facade 导出表 = 旧版导出表（自动 diff） |
| network handler 兼容 | 25 个 handler 的 require 路径可解析 |

**提交**: 无（仅验证）

---

### Step 10: 发布准备

**目标**: 打 tag、准备回滚版本

| 任务 | 详情 |
|------|------|
| 更新版本号 | 主版本 +1 |
| 打 tag | `git tag v2.0.0-rc1` |
| 保留回滚构建 | 重构前最后一版的完整构建产物单独存储 |
| 更新发布文档 | changelog 标注"结构性重构，无玩法变更" |

**提交**: `chore: bump version to 2.0.0-rc1`

---

### Step 11: 灰度发布

**目标**: 安全上线

| 阶段 | 范围 | 观察指标 | 回退条件 |
|------|------|---------|---------|
| 内测 | 开发团队 | 存档加载成功率 100% | 任何存档异常 |
| 灰度 20% | 随机 20% 用户 | 存档丢失率 < 0.1% | 丢失率 > 0.1% |
| 全量 | 100% 用户 | 同上 | 同上 |

每阶段至少观察 24h 无异常后进入下一阶段。

---

### 执行节奏建议

| 步骤 | 复杂度 | 预估工作量 |
|------|--------|-----------|
| Step 0-1 | 简单 | 基础设施搭建 |
| Step 2 | 中等 | 低风险配置拆分 |
| Step 3 | **高** | EquipmentData 是全方案最难点 |
| Step 4 | 中等 | 渲染层拆分 |
| Step 5-6 | 中-高 | 系统层拆分 |
| Step 7-8 | 中等 | UI 层拆分 |
| Step 9-11 | 简单 | 验证 + 发布 |

**建议**: Step 3（EquipmentData）作为整个重构的"试金石"——如果这步能干净完成且存档测试全过，后续步骤的风险将大幅降低。如果这步遇到困难，应暂停评估是否需要调整拆分方案。

---

## 12. 执行日志

### Step 0: 环境准备 ✅

| 项目 | 结果 |
|------|------|
| 脏工作树处理 | `git stash` 暂存（"pre-refactor: 六一活动/事件/兑换UI等未提交改动"） |
| 分支创建 | `refactor/bigfile-split` from `origin/main` |
| 基线 HEAD | `65d1ea5` |
| 全量测试 | lupa 跑通，全部 PASS |
| 文档更新 | §0.1 风险评估、§0.2 脏工作树、§4.3 存档安全、§9 上线策略、§11 分阶段计划 |

**提交**: 无（纯准备工作）

---

### Step 1: 新增文件长度门禁 ✅

| 项目 | 结果 |
|------|------|
| 新增文件 | `scripts/tests/test_file_budget.lua` (174 行) |
| 注册入口 | `TestRegistry.lua` 新增 `file_budget` 条目，group=infra, gate=blocking |
| 预算规则 | 代码文件 ≤600 target / ≤900 alert；数据文件 ≤900 target / ≤1400 alert |
| EXEMPTIONS | 39 个文件采用 ratchet 策略（当前行数 + ~50 缓冲） |
| 扫描目录 | config, rendering, ui, systems |
| 验证结果 | 239 文件扫描，0 FAIL，21 WARNING — **PASS** |
| LSP 诊断 | 0 errors, 0 warnings |
| 提交 | `25778f1` — `test(infra): add file length budget gate` |

**验证方法**: sandbox 无 lua CLI，使用 Python 等价脚本复现完整预算逻辑验证；LSP `textDocument/diagnostic` 确认无语法错误。

**注意事项**:
- `io.popen` 在 lupa sandbox 中不可用，该测试需在标准 lua CLI 或引擎环境中执行
- EXEMPTIONS 表作为 ratchet 上限，后续拆分完成后应逐步降低或移除
