# 人狗仙途 v2 — 最终代码审计评估报告（修订版）

> **审计日期**: 2026-04-04
> **修订日期**: 2026-04-04（基于线上实际影响重新定级）
> **第五轮修订**: 2026-04-04（P0 ×2 + P1-A档 ×7 已修复，B/C/P2 再评估）
> **审计范围**: `/workspace/scripts/` 全目录（80+ Lua 文件，~74,758 行）
> **审计方法**: 基于 `rules.md` 独立全量审计 + 与前次审计交叉匹配 + 代码逐条验证
> **优先级标准**: P0 = 当前正在影响线上玩家的问题；P1 = 功能缺陷/可靠性风险；P2 = 性能/可维护性/代码规范

---

## 目录

- [一、定级说明](#一定级说明)
- [二、P0 — 当前正在影响线上的问题（✅ 已全部修复）](#二p0--当前正在影响线上的问题)
- [三、P1 — 功能缺陷与可靠性风险](#三p1--功能缺陷与可靠性风险)
- [四、P2 — 改进建议](#四p2--改进建议)
- [五、P1 风险评估（必要性 / 线上影响 / 测试方案）](#五p1-风险评估必要性--线上影响--测试方案)
- [六、优先修复路线图](#六优先修复路线图)
- [七、值得肯定的设计](#七值得肯定的设计)
- [八、附录：与前次审计交叉匹配](#八附录与前次审计交叉匹配)
- [九、B档 / C档 / P2 再评估](#九b档--c档--p2-再评估)

---

## 一、定级说明

本报告经过三轮修订：

1. **初版**：基于代码静态分析，按"技术上是否存在问题"定级（17 条 P0）
2. **第一轮修订**：移除与业务流程不符的误判（GM_ENABLED、兑换码 UID）
3. **第二轮修订**：逐条论证线上实际影响和触发概率，大幅下调虚高定级
4. **第三轮修订**：确认 PetPanel 路径A扣材料是设计意图，"升级失败不消耗材料"为文案错误，降为 P2
5. **第五轮修订**（本版）：P0 ×2 + P1-A档 ×7 全部修复并构建通过；对 B档/C档/P2 进行再评估

### 修订后的数量

| 优先级 | 数量 | 标准 |
|--------|------|------|
| **P0** | 2 | 当前正在影响线上玩家 |
| **P1** | 25 | 特定条件下可触发 / 功能缺陷 |
| **P2** | 33 | 代码质量 / 性能 / 可维护性 |

---

## 二、P0 — 当前正在影响线上的问题

以下问题**不需要特殊触发条件**，当前每天都在影响玩家：

---

### P0-1: ✅ 已修复 — 套装 bonus 缺失 7 种属性——配了不生效

- **文件**: `systems/InventorySystem.lua:390-405`
- **前次审计**: §2.2（反模式），本次扩展发现实际 BUG
- **代码**:
  ```lua
  -- 套装加成只累加了这 8 种：
  totalAtk, totalDef, totalHp, totalSpeed,
  totalHpRegen, totalCritRate, totalDmgReduce, totalSkillDmg
  -- 遗漏了这 7 种：
  -- killHeal, critDmg, heavyHit, fortune, wisdom, constitution, physique
  ```
- **线上影响**: 套装配置中若含这 7 种属性的加成，穿套装后加成**不生效**。已确认套装需要支持配置这些属性。
- **修复**: ✅ 已在套装循环中补齐 7 种属性的累加（`InventorySystem.lua:401-407`）。构建通过，LSP 无报错。

---

### P0-2: ✅ 已修复 — 并发写入竞态——DaoTree/SealDemon/Trial 与 auto-save 互相覆盖

- **文件**: `server_main.lua:1803-1850`（DaoTree）, `:2340-2405`（SealDemon）, `:2540+`（Trial）
- **前次审计**: §1.5
- **描述**: DaoTree/SealDemon/Trial 奖励用 `ServerGetSlotData` 异步读旧存档 → 修改 → 写回**完整存档**。与客户端 auto-save 无隔离。
- **线上影响**: 触发条件是"奖励结算的 async 窗口（约 200ms-1s）内恰好触发 auto-save（间隔 30-60s）"。单次概率约 0.3%-3%，但每个玩家每天多次悟道/封魔，长期运营下**必然有玩家中招**。后果是**进度丢失**（后写入者覆盖先写入者的全部更改），且不可自动恢复。
- **修复**: ✅ 已实现 per-slot memory lock（`server_main.lua:64-108`）。覆盖三个系统：
  - DaoTree: `AcquireSlotLock` → 3 条 `ReleaseSlotLock` 退出路径
  - SealDemon: `AcquireSlotLock` → 3 条 `ReleaseSlotLock` 退出路径
  - Trial: `AcquireSlotLock` → 6 条 `ReleaseSlotLock` 退出路径
  - HandleSaveGame: `IsSlotLocked` 检查 → 返回 `ok=false, "slot_locked"`（客户端自动重试）
  - HandleClientDisconnected: 断线释放锁防死锁
  - 构建通过，LSP 无报错。

---

## 三、P1 — 功能缺陷与可靠性风险

以下问题需要特定条件触发，或影响非核心功能：

### 3.1 架构模式：服务端授权 + 客户端执行

#### P1-ARCH-1: 资源变更未在服务端执行（BuyPill / 封魔 lingYun / 试炼 goldBar）

- **文件**:
  - `server_main.lua:1984-2020`（BuyPill 仅返回 ok）
  - `ui/AlchemyUI.lua:695-710`（客户端执行扣灵韵/加属性）
  - `server_main.lua:2353-2367`（封魔 lingYun/petFood 仅作 S2C 通知）
  - `systems/SealDemonSystem.lua:669`（客户端 `GainLingYun`）
  - `server_main.lua:2540-2575`（试炼 lingYun/goldBar 仅作 S2C 通知）
- **前次审计**: §8.1 三层安全模型
- **本质**: 这不是多个独立 BUG，而是**同一个架构选择**——"服务端授权门 + 客户端执行资源变更 + 客户端存档"。涉及丹药购买、封魔灵韵/宠物粮、试炼灵韵/金条。
- **线上风险评估**:
  - 利用需要：反编译 UrhoX 客户端 → 修改 Lua 脚本 → 重打包安装
  - 与 Web 游戏改请求参数不同，门槛显著更高
  - 当前用户规模下被利用概率低
  - 封魔体魄丹、试炼 quota + 存档本身已在服务端原子操作
- **建议**: 作为中长期架构改进方向。高价值资源（灵韵、金条）优先迁移到服务端 BatchCommit。

### 3.2 服务端可靠性

#### P1-SRV-1: ✅ 已修复 — connSlots_ fallback slot 1——操作错误角色 ✅ §1.2

- **文件**: `server_main.lua` 8 处 `connSlots_[connKey] or 1`
- **触发**: 未加载存档时发起 C2S 请求。
- **修复**: 全部 8 处改为 guard 模式：`local slot = connSlots_[connKey]; if not slot then return end`，slot 未加载时拒绝请求并打印 WARNING。

#### P1-SRV-2: ✅ 已修复 — HandleClientDisconnected 未清理内存状态 🆕

- **文件**: `server_main.lua:323-332`
- **触发**: 玩家断线时 `sealDemonActive_`、`daoTreeMeditating_`、`trialClaimingActive_` 残留。
- **后果**: 内存泄漏 + 异步回调对已断开连接 SafeSend。
- **修复**: 在 `HandleClientDisconnected` 中补充 3 行 cleanup；前向声明解决作用域问题。

#### P1-SRV-3: trialClaimingActive_ 内存锁无 TTL ✅ §3.3

- **文件**: `server_main.lua:2459-2463`
- **触发**: 回调因网络异常永不返回。
- **后果**: 试炼奖励锁死直到重连。

#### P1-SRV-4: HandleCreateChar TOCTOU 竞态 🆕

- **文件**: `server_main.lua:655-720`
- **触发**: 极短时间内重复提交创建角色请求。
- **后果**: 并发请求可覆盖已有角色。

#### P1-SRV-5: 封魔每日 Quota 接受时扣除，放弃不退 🆕

- **文件**: `server_main.lua:2193`（Accept）, `:2436`（Abandon）
- **后果**: 玩家放弃封魔任务后当日机会浪费。

#### P1-SRV-6: 兑换码非原子两步 Quota ✅ §3.2

- **文件**: `server_main.lua:2863-2890`
- **触发**: 高并发兑换。
- **后果**: 用户 Quota 扣了但全局 Quota 失败，回滚用 -1 增量，可能不被支持。

#### P1-SRV-7: 无 C2S 请求限流 🆕

- **文件**: `server_main.lua` 全局
- **触发**: 恶意客户端快速发包。
- **后果**: 刷爆 300 ops/min 云配额。

### 3.3 存档可靠性

#### P1-SAVE-1: SaveSystemNet 单变量回调覆盖 ✅ §3.6

- **文件**: `network/SaveSystemNet.lua:33-36`
- **触发**: 快速双击创建角色/加载存档。
- **后果**: 前一次回调被覆盖，UI 挂起。不丢数据，重启可恢复。

#### P1-SAVE-2: CloudStorage _pendingCallbacks 无超时 ✅ §3.1

- **文件**: `network/CloudStorage.lua:33, 47-57`
- **触发**: 存档操作进行中网络断开。
- **后果**: saving 锁卡死，当前会话无法存档。重启可恢复。

#### P1-SAVE-3: SerializeItemFull 缺少 sellCurrency/specialEffect 🆕

- **文件**: `systems/save/SaveSerializer.lua:233-258`

#### P1-SAVE-4: DoSave 双重 JSON 编码 ✅ §4.4

- **文件**: `systems/save/SavePersistence.lua:90-101`

#### P1-SAVE-5: CloudStorage FIFO 回调可能错配类型 🆕

- **文件**: `network/CloudStorage.lua:231-237, 258-264`

#### P1-SAVE-6: VersionGuard._DoKick 并行存档风险 🆕

- **文件**: `systems/VersionGuard.lua:75-81`

### 3.4 UI / 客户端可靠性

#### P1-UI-1: ✅ 已修复 — GetUserNickname 异步竞态——排行榜昵称为 nil ✅ §1.1

- **文件**: `server_main.lua:461-469`, `:1211-1218`
- **代码**: 异步 `GetUserNickname` 调用后立即同步使用 `taptapNick`（值为 nil）。
- **线上影响**: 排行榜中所有玩家的 TapTap 昵称显示为空。**纯展示问题**，不影响数据安全和游戏玩法。
- **修复**: 提取 `RebuildRankOnLogin` 函数，排行重建逻辑移入 `onSuccess`/`onError` 回调；`onError` 降级为空昵称。

#### P1-UI-2: ✅ 已修复 — 全局 C2S 按钮缺少点击保护（4/5 文件） 🆕

- **文件**: `ui/DaoTreeUI.lua`, `ui/AlchemyUI.lua`, `ui/RedeemUI.lua`, `ui/GMConsole.lua`
- **后果**: 快速双击触发重复请求。
- **修复**: AlchemyUI 添加 `pendingPillBuys_` 防抖；GMConsole 添加 `pendingGMCommands_` 防抖。DaoTreeUI/RedeemUI 已有保护（`waitingServer_`/`pending_`），无需改动。

#### P1-UI-3: ✅ 已修复 — GourdUI EventBus 监听器泄漏 ✅ §3.4

- **文件**: `ui/GourdUI.lua:887, 1083-1095`
- **后果**: 角色切换后累积重复监听。
- **修复**: 保存 unsub handle，重新订阅前先取消旧订阅。

#### P1-UI-4: ✅ 已修复 — Pet.lua dirty flag 仅覆盖 3 个事件 🆕

- **文件**: `entities/Pet.lua:84-87`
- **后果**: 酒/法宝/徽章/丹药等属性变更后宠物属性过期。
- **修复**: 补齐 `wine_slots_changed`、`realm_breakthrough`、`collection_stats_changed` 三个事件。

#### P1-UI-5: Pet.lua 无 Destroy 方法 🆕

- **文件**: `entities/Pet.lua`

#### P1-UI-6: LeaderboardUI 4 并行查询无超时 ✅ §3.5

- **文件**: `ui/LeaderboardUI.lua:510-520, 640-676`
- **后果**: 任一查询挂起 → 永久 loading。

#### P1-UI-7: ✅ 已修复 — client_main.lua 120s 连接超时无 UI 反馈 🆕

- **文件**: `client_main.lua:32, 108-122`
- **修复**: 5 秒后显示"正在连接服务器..."提示，超时后变为"连接超时，等待重试..."并变色；连接成功时自动移除提示。

#### P1-UI-8: HandleMaintenance 覆盖 UI 树不清理引用 🆕

- **文件**: `client_main.lua:165`

### 3.5 配置 / 数据缺失

#### P1-CFG-1: 渡劫丹"暂未开放"但境界突破已引用 🆕

- **文件**: `config/GameConfig.lua:156, 413-456`

#### P1-CFG-2: 龙神圣器 (shengqi_*) 未入图录 🆕

- **文件**: `config/EquipmentData.lua` Collection 部分

#### P1-CFG-3: main.lua 已达 1487 行临界值 🆕

- **文件**: `main.lua`（1487 行）

---

## 四、P2 — 改进建议

### 4.1 存档代码一致性

#### P2-SAVE-1: 客户端 FetchSlots 只读 v10 key（服务端已兜底） ✅ §1.3

- **文件**: `systems/save/SaveSlots.lua:35-43`
- **说明**: 客户端 FetchSlots 硬编码 `save_data_1~4`（v10），CreateCharacter 写 `save_1`（v11）。但 `server_main.lua:376-408` 服务端已实现 v11/v10 双 key 兜底，当前 `multiplayer.enabled: true` 强制网络模式，**线上不触发**。
- **建议**: 统一客户端读取逻辑，保持代码一致性。

#### P2-SAVE-2: SaveRecovery 境界循环 break 位置错误 🆕

- **文件**: `systems/save/SaveRecovery.lua:173-183`
- **说明**: 当前境界奖励在 break 之前未累加。但此代码仅在存档严重损坏需重建元数据时才触发，**正常游戏流程不走此路径**。

#### P2-SAVE-3: 图鉴退化保护修改 saveData 但写入 coreData 🆕

- **文件**: `systems/save/SavePersistence.lua:247-258, 315`
- **说明**: 浅拷贝后引用分离，保护逻辑不生效。但仅在图鉴数据异常退化超过 50% 时触发，**极端罕见场景**。

#### P2-SAVE-4: quota:Add 缺少 refreshCount 参数 🆕

- **文件**: `server_main.lua:2193, 2863, 2868, 2883`
- **说明**: 文档签名为 7 参数，实际传 6 参数，events 表落在 refreshCount 位置。但**线上功能正常**（引擎对缺省参数有兜底），建议补全参数确保行为符合预期。

### 4.2 性能

#### P2-PERF-1: Minimap 6400 NanoVG 绘制/帧 ✅ §4.3

- **文件**: `ui/Minimap.lua:260-286`
- **建议**: 渲染到 framebuffer 缓存。

#### P2-PERF-2: Player.lua GetTotal* 无缓存 + pcall(require) 热路径 ✅ §4.5

- **文件**: `entities/Player.lua:185-375`
- **建议**: dirty flag 缓存，require 提到模块顶部。

#### P2-PERF-3: 每次登录无条件重建排行 12 次 SetInt ✅ §4.1

- **文件**: `server_main.lua:470-580`

#### P2-PERF-4: 排行榜 N+1 查询 ✅ §4.2

- **文件**: `server_main.lua:1545-1610`

### 4.3 结构性技术债

#### P2-STRUCT-1: ArtifactSystem vs ArtifactSystem_ch4 约 80% 代码克隆 ✅ §2.3

- **文件**: `systems/ArtifactSystem.lua`（731 行）+ `ArtifactSystem_ch4.lua`（695 行）

#### P2-STRUCT-2: 4 系统重复世界备份/回滚 ✅ §2.4

#### P2-STRUCT-3: SkillSystem CastDamageSkill/CastLifestealSkill 90% 重复 🆕

- **文件**: `systems/SkillSystem.lua:358-620`

#### P2-STRUCT-4: ProgressionSystem 6 丹药 x2 重复 if 块 ✅ §2.6

### 4.4 硬编码 / 配置化

| 编号 | 文件 | 描述 |
|------|------|------|
| P2-HC-1 | LootSystem.lua:119-133 | 11 级硬编码阈值 |
| P2-HC-2 | FortuneFruitSystem.lua:19-70 | 30 个果实坐标硬编码 |
| P2-HC-3 | GameEvents.lua / SkillSystem.lua 等 | ~15 处颜色魔法数字 |
| P2-HC-4 | combat/BossMechanics.lua | 战斗参数散落 |
| P2-HC-5 | main.lua:115-119 | 第四章缺少 BGM 条目 |

### 4.5 其他代码质量

| 编号 | 文件 | 描述 |
|------|------|------|
| P2-Q-1 | SaveKeys.lua | deprecated 函数仍被活跃调用 |
| P2-Q-2 | SaveMigrations.lua | v14 完整保留但逻辑已被 v15 覆盖 |
| P2-Q-3 | SaveSerializer.lua | IIFE 包裹 require 降低可读性 |
| P2-Q-4 | SavePersistence.lua | ExportToLocalFile 缺少 clientCloud nil 检查 |
| P2-Q-5 | main.lua | CopyNPC 白名单 19 字段手动列举 |
| P2-Q-6 | GameConfig.lua | CONSUMABLES = PET_MATERIALS 别名语义模糊 |
| P2-Q-7 | EquipmentData.lua | gold_helmet_ch2 三条重复 fortune 副属性 |
| P2-Q-8 | SaveProtocol.lua | ALL_EVENTS 无自动化校验 |
| P2-Q-9 | main.lua | HUD 降频 0.1 使用魔法数字 |
| P2-Q-10 | server_main.lua | SealDemon 用 BatchSet 而非 BatchCommit |
| P2-Q-11 | GameConfig.lua:8 | GM_ENABLED 依赖手动关闭，建议构建时自动注入 |
| P2-Q-12 | PetPanel.lua:1806 | 规则面板写"升级失败不消耗材料"，实际路径A失败消耗技能书（设计意图），战斗提示也写"技能书已消耗"（第 1600 行），仅帮助文案不准确，改为"路径A升级失败消耗技能书" |

---

## 五、P1 风险评估（必要性 / 线上影响 / 测试方案）

基于源码逐项审阅，将 30 条 P1 按修复优先级分为三档：

- **A 档（建议修复）**：必要性高、改动安全、可自测
- **B 档（可选修复）**：有价值但测试难度大或影响有限
- **C 档（暂缓）**：设计层面取舍、改动风险高、或极低概率

---

### A 档：建议修复（7 项）— ✅ 已全部修复

| 编号 | 状态 | 修复摘要 |
|------|------|---------|
| **P1-UI-1** GetUserNickname 竞态 | ✅ 已修复 | 排行重建移入回调，提取 `RebuildRankOnLogin`；`onError` 降级空昵称 |
| **P1-SRV-1** connSlots\_ fallback slot 1 | ✅ 已修复 | 8 处 `or 1` → guard 模式，slot 未加载时拒绝请求 |
| **P1-SRV-2** 断连未清理内存状态 | ✅ 已修复 | `HandleClientDisconnected` 补充 3 行 cleanup + 前向声明 |
| **P1-UI-2** C2S 按钮缺少点击保护 | ✅ 已修复 | AlchemyUI `pendingPillBuys_` + GMConsole `pendingGMCommands_` 防抖 |
| **P1-UI-3** GourdUI EventBus 泄漏 | ✅ 已修复 | 保存 unsub handle，重新订阅前先取消旧订阅 |
| **P1-UI-4** Pet dirty flag 仅覆盖 3 事件 | ✅ 已修复 | 补齐 `wine_slots_changed` / `realm_breakthrough` / `collection_stats_changed` |
| **P1-UI-7** 120s 连接超时无 UI 反馈 | ✅ 已修复 | 5s 后显示提示，超时变色，连接成功后移除 |

---

### B 档：可选修复（9 项）

| 编号 | 必要性 | 改动对线上影响 | 测试方案 |
|------|--------|--------------|---------|
| **P1-SRV-3** trialClaimingActive\_ 无 TTL | **中低**。仅当 `ServerGetSlotData` 或 `BatchCommit` 回调因网络异常永不返回时锁死，重连可恢复。 | **低风险**。加 15s 超时自动释放，~10 行。 | ⚠️ **难自测**：需模拟回调丢失。可通过代码审查验证超时逻辑正确性。 |
| **P1-SRV-7** 无 C2S 限流 | **中**。恶意客户端可快速发包刷爆 300 ops/min 云配额。 | **低风险**。在 `GetUserId` 后加 per-connection rate limiter（令牌桶/滑动窗口），~30 行。正常玩家请求频率远低于限流阈值。 | ⚠️ **难自测**：需编写脚本模拟高频请求。可通过代码审查确认限流逻辑。 |
| **P1-SAVE-1** SaveSystemNet 回调覆盖 | **中低**。快速双击"创建角色"或"加载存档"时前一次回调被覆盖，UI 挂起。不丢数据，重启恢复。 | **低风险**。将单变量改为队列（或禁止并发请求），~15 行。 | ⚠️ **可自测（边界）**：极快速双击创建角色按钮，检查是否卡住。但时间窗口极小。 |
| **P1-SAVE-2** CloudStorage 无超时 | **中低**。网络断开时 `_pendingCallbacks` 永不清理，saving 锁卡死。重启恢复。 | **低风险**。加 15s 超时清理机制，~20 行。 | ⚠️ **难自测**：需模拟网络中断。可通过代码审查验证。 |
| **P1-UI-6** 排行榜 4 并行查询无超时 | **中低**。任一查询挂起 → loading 永久显示。 | **低风险**。加 10s 超时 fallback 显示已获取数据，~15 行。 | ⚠️ **难自测**：需模拟查询超时。正常网络下不触发。 |
| **P1-UI-5** Pet.lua 无 Destroy | **低**。角色切换时旧 Pet 的 EventBus 监听器残留，轻微内存泄漏。 | **低风险**。加 `Destroy` 方法调用 unsub，~10 行。 | ✅ **可自测**：切换角色后检查是否有重复事件触发。 |
| **P1-UI-8** HandleMaintenance 覆盖不清理 | **低**。仅在服务端下发维护通知时触发，老 UI 引用残留。 | **低风险**。加 `UI.Clear()` 或释放旧根节点，~3 行。 | ⚠️ **难自测**：需服务端发送维护事件。 |
| **P1-SAVE-5** CloudStorage FIFO 回调错配 | **低**。理论上当多个不同类型的 cloud 操作排队时回调可能匹配错类型。实际使用中每次只有一个 save 在进行（`SS.saving` 锁保证）。 | **低风险**。改为 requestId 精确匹配（已部分实现），~10 行。 | ⚠️ **难自测**：需极端并发场景。 |
| **P1-SAVE-6** VersionGuard 并行存档风险 | **低**。版本检测触发踢人时可能与正在进行的存档并发。但 `_DoKick` 本身只是弹 UI 提示+阻止后续操作，不直接写存档。 | **低风险**。加 `SS.saving` 检查延迟踢人，~5 行。 | ⚠️ **难自测**：需恰好在存档进行中触发版本不匹配。 |

---

### C 档：暂缓（9 项）

| 编号 | 必要性 | 暂缓理由 |
|------|--------|---------|
| **P1-ARCH-1** 资源变更客户端执行 | 中长期架构改进方向 | **改动风险高**：涉及 BuyPill / 封魔 / 试炼 3 个系统的资源变更逻辑迁移到服务端，需同时改客户端+服务端+存档协议。利用门槛高（需反编译 UrhoX 客户端），当前用户规模下风险可控。建议**待版本稳定后专项迭代**。测试方案：需完整回归测试所有资源变更流程。 |
| **P1-SRV-4** CreateChar TOCTOU | 极低概率 | 需极短时间内（<200ms）重复提交创角请求。正常 UI 不可能触发。若修复 P1-UI-2（按钮防抖），此问题同时被缓解。 |
| **P1-SRV-5** 封魔 quota 放弃不退 | **设计决策** | 这是"接取扣次数"的设计选择，改为"放弃退还"需要确认产品意图。不是代码 BUG。 |
| **P1-SRV-6** 兑换码非原子 Quota | 极低概率 | 需高并发同时兑换同一码。当前用户规模下几乎不可能。修复需改为 BatchCommit 原子事务，改动 ~30 行，但测试困难（需模拟并发）。 |
| **P1-SAVE-3** SerializeItemFull 缺字段 | 低 | `sellCurrency` 和 `specialEffect` 当前所有物品均未使用这两个字段（搜索 GameConfig/EquipmentData 确认）。仅在未来新增物品使用时才有影响。修复为补 2 行，无风险，但无紧迫性。 |
| **P1-SAVE-4** DoSave 双重 JSON | **改动风险高** | 当前客户端 `cjson.encode(coreData)` 后服务端 `cjson.decode` 解码，虽然多一层编码但功能正常。修改编码方式需**同步修改客户端+服务端**，且需处理新旧存档兼容。建议在下次存档版本升级（v12）时一并处理。 |
| **P1-CFG-1** 渡劫丹暂未开放 | **设计意图** | 配置描述已写"暂未开放"，是预留内容。境界突破检查 `dujie_dan` 时会发现玩家没有此道具而阻止突破，与"暂未开放"一致。不是 BUG。 |
| **P1-CFG-2** 龙神圣器未入图录 | 低 | 纯展示问题，不影响装备功能。补充 collection 配置即可，~10 行。 |
| **P1-CFG-3** main.lua 1487 行 | 代码组织 | 接近 1500 行阈值但未超。拆分重构是纯代码质量改进，不影响功能，建议在下个功能迭代时顺便处理。 |

---

### P1 评估总结

| 档位 | 数量 | 建议 |
|------|------|------|
| **A 档（建议修复）** | 7 | 改动安全、可自测、能显著改善用户体验和服务端稳定性 |
| **B 档（可选修复）** | 9 | 有价值但测试难度大或影响有限，可排入后续迭代 |
| **C 档（暂缓）** | 9 | 设计决策/改动风险高/极低概率，暂不处理 |

**建议修复顺序**：P1-UI-1 → P1-SRV-1 → P1-SRV-2 → P1-UI-2 → P1-UI-3 → P1-UI-4 → P1-UI-7

---

## 六、优先修复路线图

### ✅ 已完成（P0，原影响玩家，已全部修复）

| 序号 | 编号 | 改动量 | 描述 | 状态 |
|------|------|--------|------|------|
| 1 | P0-1 | 7 行 | 套装 bonus 补齐 7 属性 | ✅ 已修复 |
| 2 | P0-2 | ~50 行 | 并发写入竞态：per-slot memory lock（覆盖 DaoTree/SealDemon/Trial） | ✅ 已修复 |

### ✅ 已完成（P1-A档，7 项全部修复）

| 序号 | 编号 | 描述 | 状态 |
|------|------|------|------|
| 3 | P1-UI-1 | GetUserNickname 改为回调内写排行榜 | ✅ 已修复 |
| 4 | P1-SRV-1 | connSlots_ fallback 改为 reject 而非默认 slot 1 | ✅ 已修复 |
| 5 | P1-SRV-2 | 断连清理内存状态 | ✅ 已修复 |
| 6 | P1-UI-2 | C2S 按钮统一防抖（AlchemyUI + GMConsole） | ✅ 已修复 |
| 7 | P1-UI-3 | GourdUI EventBus 泄漏修复 | ✅ 已修复 |
| 8 | P1-UI-4 | Pet dirty flag 补齐 3 个事件 | ✅ 已修复 |
| 9 | P1-UI-7 | 连接超时 UI 反馈 | ✅ 已修复 |

### 🟡 计划修复（P1 其余 + P2 高价值）

| 序号 | 描述 |
|------|------|
| 8 | P1-ARCH-1 架构改进：高价值资源迁移服务端 BatchCommit |
| 9 | P1-SAVE-1~2 存档可靠性（超时、防重） |
| 10 | P1-SRV-3~7 服务端可靠性修复 |

### 🟢 持续改进（P2）

| 描述 |
|------|
| Minimap framebuffer 缓存 |
| Player.GetTotal* dirty flag 缓存 |
| ArtifactSystem 去重 |
| 硬编码配置化 |
| 代码一致性清理 |

---

## 七、值得肯定的设计

| 设计 | 评价 |
|------|------|
| **epoch 机制** | SavePersistence 通过递增 epoch 使旧回调自动失效，防止 stale write。 |
| **V1-V6 存档校验** | 6 层渐进式校验（结构 → 类型 → 金币非负 → 灵韵非负 → 丹药上限 → 物品结构）。 |
| **服务端 v11/v10 双 key 兜底** | `server_main.lua:402-408` 优先 v11 fallback v10，保证新旧存档兼容。 |
| **TrialOfferingUI 三层安全** | `_isThrottled` + `C2S_TIMEOUT` + `SetDisabled`，可作为其他模块的参考范本。 |
| **远处怪物降频** | `FAR_MONSTER_UPDATE_INTERVAL = 0.5`，性能优化有效。 |
| **Monster 距离计算** | 预计算平方距离常量 `AGGRO_RANGE_SQ`，避免每帧 sqrt。 |
| **试炼 BatchCommit 原子事务** | Quota + 存档在同一事务中，确保一致性。 |

---

## 八、附录：与前次审计交叉匹配

| 本次编号 | 前次编号 | 说明 |
|---------|---------|------|
| P0-1 | §2.2 扩展 | 套装 bonus 缺 7 属性（前次指反模式，本次发现实际 BUG） |
| P0-2 | §1.5 | 并发写入竞态 |
| P2-Q-12 | §1.4 | PetPanel 规则面板文案不准确（路径A失败扣材料是设计意图，非逻辑 BUG） |
| P1-ARCH-1 | §8.1 扩展 | 资源变更客户端执行（合并为架构问题） |
| P1-SRV-1 | §1.2 | connSlots fallback |
| P1-SRV-3 | §3.3 | 内存锁无 TTL |
| P1-SRV-6 | §3.2 | 兑换码非原子 Quota |
| P1-SAVE-1 | §3.6 | 单变量回调覆盖 |
| P1-SAVE-2 | §3.1 | 回调无超时 |
| P1-SAVE-4 | §4.4 | 双重 JSON 编码 |
| P1-UI-1 | §1.1 | GetUserNickname 竞态 |
| P1-UI-3 | §3.4 | GourdUI EventBus 泄漏 |
| P1-UI-6 | §3.5 | 排行榜无超时 |
| P2-SAVE-1 | §1.3 | FetchSlots key 不匹配（服务端已兜底） |
| P2-PERF-1 | §4.3 | Minimap 6400 draws |
| P2-PERF-2 | §4.5 | GetTotal* 无缓存 |
| P2-PERF-3 | §4.1 | 登录重建排行 |
| P2-PERF-4 | §4.2 | N+1 查询 |
| P2-STRUCT-1 | §2.3 | ArtifactSystem 克隆 |
| P2-STRUCT-2 | §2.4 | 备份/回滚重复 |
| P2-STRUCT-4 | §2.6 | 丹药重复 if |

其余为本次新发现（🆕），未在前次审计中出现。

---

---

## 九、B档 / C档 / P2 再评估

> 基于 A 档修复后的代码状态，对剩余条目逐项重新审视：是否仍然存在、改动风险、推荐方案、是否值得修复。

---

### 9.1 B 档再评估（原 9 项）

#### B-1: P1-SRV-3 — trialClaimingActive_ 无 TTL

| 维度 | 评估 |
|------|------|
| **现状** | P1-SRV-2 修复后断连时已清理 `trialClaimingActive_`。残留场景仅剩"回调因引擎异常永不返回"。 |
| **实际风险** | **极低**。`ServerGetSlotData` 和 `BatchCommit` 的回调由引擎保证，网络超时引擎自身有兜底。断连清理已覆盖最常见的锁残留路径。 |
| **方案** | 加 15s `os.clock()` 超时检查（在 HandleUpdate 中 tick），~10 行 |
| **建议** | ⬇️ **降为 C 档暂缓**。P1-SRV-2 已覆盖主要风险路径，剩余极端场景投入产出比低。 |

#### B-2: P1-SRV-7 — 无 C2S 限流

| 维度 | 评估 |
|------|------|
| **现状** | 20+ 个 C2S 事件无 per-connection 限流。恶意客户端可快速发包。 |
| **实际风险** | **中**。UrhoX 客户端改包门槛高，但理论上可刷爆 300 ops/min 云配额影响所有玩家。 |
| **方案** | 在 `GetUserId` 后加滑动窗口计数器：每连接每 10s 最多 20 次请求，超限 kick。~30 行，集中在一个 `RateLimiter` 函数。 |
| **建议** | ✅ **保留 B 档，建议修复**。改动集中、风险低、防御价值高。 |

#### B-3: P1-SAVE-1 — SaveSystemNet 单变量回调覆盖

| 维度 | 评估 |
|------|------|
| **现状** | `_pendingFetchSlots` / `_pendingLoad` / `_pendingChar` 仍为单变量。 |
| **实际风险** | **低**。P1-UI-2 修复后按钮有防抖，极难在 UI 层面触发并发请求。唯一残留路径是程序化调用（无 UI 触发）。 |
| **方案** | 改为队列或加 `if _pendingXxx then return end` 前置检查，~15 行 |
| **建议** | ⬇️ **降为 C 档暂缓**。P1-UI-2 防抖已从源头遏制，残留风险极低。 |

#### B-4: P1-SAVE-2 — CloudStorage _pendingCallbacks 无超时

| 维度 | 评估 |
|------|------|
| **现状** | 已改为 requestId 匹配（非 FIFO），但无超时清理机制。 |
| **实际风险** | **低**。网络断开时引擎会触发 disconnect → 重连流程会重置状态。`saving` 锁卡死仅在"引擎不回调也不断连"的极端场景，重启可恢复。 |
| **方案** | 在 `_pendingCallbacks` 添加 timestamp，HandleUpdate 中 15s 超时清理，~20 行 |
| **建议** | ✅ **保留 B 档**。改动安全，作为防御性编程有价值，但优先级低于 SRV-7。 |

#### B-5: P1-UI-6 — 排行榜 4 并行查询无超时

| 维度 | 评估 |
|------|------|
| **现状** | 4 路 `GetRankList` 并行，任一挂起 → loading 永久。 |
| **实际风险** | **中低**。正常网络下几乎不触发。但弱网环境（移动端常见）下体验差。 |
| **方案** | 加 10s 超时 fallback：`local timer = os.clock()` 在 HandleUpdate 中检查，到期后用已有数据渲染。~15 行 |
| **建议** | ✅ **保留 B 档**。改善弱网体验，改动安全。 |

#### B-6: P1-UI-5 — Pet.lua 无 Destroy

| 维度 | 评估 |
|------|------|
| **现状** | `_eventUnsubs` 已有 6 个订阅（P1-UI-4 修复后），但无 Destroy 方法取消订阅。 |
| **实际风险** | **低**。角色切换频率低（一局游戏通常不切换），泄漏量小（每次 6 个监听器）。 |
| **方案** | 添加 `Pet:Destroy()` 遍历 `_eventUnsubs` 调用 unsub，~8 行。在切换角色处调用。 |
| **建议** | ⬆️ **升为推荐修复**。改动极小（8 行），且 P1-UI-4 增加了 3 个事件后泄漏更严重。与 P1-UI-3（GourdUI 泄漏）同类问题，应一并修复。 |

#### B-7: P1-UI-8 — HandleMaintenance 覆盖不清理

| 维度 | 评估 |
|------|------|
| **现状** | 维护通知覆盖 UI 树时未清理旧引用。 |
| **实际风险** | **极低**。仅在服务端下发维护事件时触发，频率极低（运营级操作）。 |
| **方案** | 在创建维护 UI 前加 `if mainUI_ then mainUI_:Remove() end`，~3 行 |
| **建议** | ⬇️ **降为 C 档暂缓**。触发频率极低，不影响游戏功能。 |

#### B-8: P1-SAVE-5 — CloudStorage FIFO 回调错配

| 维度 | 评估 |
|------|------|
| **现状** | 已实现 requestId 精确匹配，FIFO 仅作 fallback。 |
| **实际风险** | **极低**。正常流程走 requestId 匹配，FIFO fallback 仅在引擎不回传 requestId 时触发（当前版本引擎已支持）。 |
| **方案** | 移除 FIFO fallback 或加日志告警，~5 行 |
| **建议** | ⬇️ **降为 C 档暂缓**。requestId 机制已解决核心问题。 |

#### B-9: P1-SAVE-6 — VersionGuard 并行存档风险

| 维度 | 评估 |
|------|------|
| **现状** | `_DoKick` 弹 UI 提示 + 阻止后续操作，不直接写存档。 |
| **实际风险** | **极低**。需"正在存档中恰好触发版本不匹配"的极端时序。 |
| **方案** | 在 `_DoKick` 前检查 `SS.saving`，延迟至存档完成后再踢，~5 行 |
| **建议** | ⬇️ **降为 C 档暂缓**。极端场景，现有设计已足够安全。 |

#### B 档再评估汇总

| 编号 | 原档位 | 新建议 | 理由 |
|------|--------|--------|------|
| P1-SRV-3 | B | ⬇️ C 暂缓 | SRV-2 修复已覆盖主要路径 |
| P1-SRV-7 | B | ✅ B 保留（推荐修复） | 防御价值高，改动集中 |
| P1-SAVE-1 | B | ⬇️ C 暂缓 | UI-2 防抖已遏制源头 |
| P1-SAVE-2 | B | ✅ B 保留 | 防御性编程，改动安全 |
| P1-UI-6 | B | ✅ B 保留 | 弱网体验改善 |
| P1-UI-5 | B | ⬆️ **推荐修复** | 8 行，UI-4 增加事件后泄漏加重 |
| P1-UI-8 | B | ⬇️ C 暂缓 | 极低频率 |
| P1-SAVE-5 | B | ⬇️ C 暂缓 | requestId 已解决 |
| P1-SAVE-6 | B | ⬇️ C 暂缓 | 极端场景 |

**B 档修复建议排序**：P1-UI-5（8行） → P1-SRV-7（30行） → P1-UI-6（15行） → P1-SAVE-2（20行）

---

### 9.2 C 档再评估（原 9 项）

#### C-1: P1-ARCH-1 — 资源变更客户端执行

| 维度 | 评估 |
|------|------|
| **现状** | 丹药/封魔/试炼的资源变更仍在客户端执行。 |
| **变化** | P1-UI-2 防抖修复减少了重复请求风险，但核心架构问题不变。 |
| **建议** | ✅ **保持 C 档暂缓**。架构迁移需大量改动 + 完整回归测试，建议专项迭代处理。 |

#### C-2: P1-SRV-4 — CreateChar TOCTOU

| 维度 | 评估 |
|------|------|
| **现状** | 确认存在经典 check-then-act 竞态。 |
| **变化** | P1-UI-2 防抖减少了 UI 层面重复提交，但程序化攻击仍可触发。 |
| **方案** | 在 `HandleCreateChar` 开头加 per-connection `creatingChar_` 标记，回调后清除。~8 行。 |
| **建议** | ⬆️ **升为 B 档可选修复**。改动仅 8 行，可防止角色覆盖（数据破坏），性价比高。 |

#### C-3: P1-SRV-5 — 封魔 quota 放弃不退

| 维度 | 评估 |
|------|------|
| **建议** | ✅ **保持 C 档**。设计决策，非代码 BUG。需产品确认意图。 |

#### C-4: P1-SRV-6 — 兑换码非原子 Quota

| 维度 | 评估 |
|------|------|
| **现状** | 确认使用嵌套 `quota:Add` + 手动回滚。 |
| **建议** | ✅ **保持 C 档暂缓**。当前用户规模下并发兑换概率极低。改为 BatchCommit 原子事务可行但测试困难。 |

#### C-5: P1-SAVE-3 — SerializeItemFull 缺字段

| 维度 | 评估 |
|------|------|
| **现状** | 代码中 24 个字段已覆盖。审计探针显示 `sellCurrency` / `specialEffect` 当前未被任何物品使用。 |
| **建议** | ✅ **保持 C 档暂缓**。无紧迫性，未来新增物品时补充。 |

#### C-6: P1-SAVE-4 — DoSave 双重 JSON

| 维度 | 评估 |
|------|------|
| **现状** | **再审查未发现双重编码**。当前代码只有一次 `cjson.encode`。可能在之前版本中已修复或属于初版误判。 |
| **建议** | ⬇️ **关闭（已不存在）**。从 P1 列表中移除。 |

#### C-7: P1-CFG-1 — 渡劫丹暂未开放

| 维度 | 评估 |
|------|------|
| **现状** | 配置中 `dujie_dan`（下划线）和 `dujieDan`（驼峰）命名不一致，但功能上"暂未开放"是设计意图。 |
| **建议** | ✅ **保持 C 档**。命名不一致可在未来开放时统一处理。 |

#### C-8: P1-CFG-2 — 龙神圣器未入图录

| 维度 | 评估 |
|------|------|
| **现状** | 确认 `shengqi_*` 装备存在但不在 `COLLECTION` 目录中。 |
| **方案** | 补充 collection 配置条目，~10 行 |
| **建议** | ✅ **保持 C 档**。纯展示问题，优先级低。 |

#### C-9: P1-CFG-3 — main.lua 1487 行

| 维度 | 评估 |
|------|------|
| **建议** | ✅ **保持 C 档**。接近阈值但未超，功能迭代时顺便处理。 |

#### C 档再评估汇总

| 编号 | 原档位 | 新建议 | 理由 |
|------|--------|--------|------|
| P1-ARCH-1 | C | ✅ C 保持 | 架构迁移，专项迭代 |
| P1-SRV-4 | C | ⬆️ **B 可选修复** | 仅 8 行，防数据破坏 |
| P1-SRV-5 | C | ✅ C 保持 | 设计决策 |
| P1-SRV-6 | C | ✅ C 保持 | 低概率，测试困难 |
| P1-SAVE-3 | C | ✅ C 保持 | 当前未使用 |
| P1-SAVE-4 | C | ❌ **关闭** | 当前代码不存在此问题 |
| P1-CFG-1 | C | ✅ C 保持 | 设计意图 |
| P1-CFG-2 | C | ✅ C 保持 | 纯展示 |
| P1-CFG-3 | C | ✅ C 保持 | 未超阈值 |

---

### 9.3 P2 再评估（原 33 项）

#### 9.3.1 存档代码一致性（4 项）

| 编号 | 现状 | 建议 |
|------|------|------|
| P2-SAVE-1 FetchSlots key 不匹配 | `multiplayer.enabled: true` 强制网络模式，线上不触发 | ✅ 保持 P2。统一 key 可在下次存档版本升级时处理 |
| P2-SAVE-2 SaveRecovery break | 确认 break 位置在累加之前。但此代码仅在存档严重损坏时触发 | ✅ 保持 P2。极端罕见路径，修复简单（~3 行调换顺序），可顺手修 |
| P2-SAVE-3 图鉴退化浅拷贝 | 确认浅拷贝导致保护逻辑不生效。但仅在图鉴数据异常退化 >50% 时触发 | ✅ 保持 P2。改为深拷贝 ~5 行，可顺手修 |
| P2-SAVE-4 quota:Add 参数 | **再审查：参数实际正确（5 参数匹配签名）** | ❌ **关闭（误判）** |

#### 9.3.2 性能（4 项）

| 编号 | 现状 | 建议 |
|------|------|------|
| P2-PERF-1 Minimap 6400 draws | 已有 color-batch 优化（合并相同颜色）。但每帧仍逐格调用 `nvgBeginPath+nvgRect+nvgFill` | ✅ 保持 P2。可进一步用 framebuffer 缓存，但当前优化已可接受 |
| P2-PERF-2 GetTotal* 无缓存 | 每次调用重新计算所有属性加成。Pet 已有 dirty flag 模式可参考 | ⬆️ **建议修复**。高频调用路径（战斗每帧），dirty flag 模式 ~30 行，性能收益明显 |
| P2-PERF-3 登录重建排行 | P1-UI-1 修复后 SetInt 从 12 次降到 6 次（仅 2 个活跃 slot × 3 个 key） | ⬇️ **降级/缓解**。P1-UI-1 修复已将开销减半，当前 6 次 SetInt 可接受 |
| P2-PERF-4 N+1 查询 | 确认存在：排行榜每个条目单独 `BatchGet`。100 条 → 100 次网络请求 | ✅ 保持 P2。可优化为批量查询，但受限于 cloud API 是否支持 batch userId |

#### 9.3.3 结构性技术债（4 项）

| 编号 | 现状 | 建议 |
|------|------|------|
| P2-STRUCT-1 ArtifactSystem 80% 克隆 | 731 + 695 = 1426 行，两个文件结构高度相似 | ✅ 保持 P2。重构为参数化共享基类，但涉及面广，建议专项迭代 |
| P2-STRUCT-2 4 系统重复备份/回滚 | 多个系统各自实现备份/回滚逻辑 | ✅ 保持 P2。提取公共 `WorldBackup` 工具类，建议专项迭代 |
| P2-STRUCT-3 SkillSystem 90% 重复 | `CastDamageSkill` 和 `CastLifestealSkill` 逻辑高度重叠 | ✅ 保持 P2。提取 `_CastCoreSkill` 内部函数 + 差异参数，~50 行重构 |
| P2-STRUCT-4 ProgressionSystem 丹药重复 | 6 种丹药 ×2 重复 if 块 | ✅ 保持 P2。数据驱动改造，~30 行 |

#### 9.3.4 硬编码 / 配置化（5 项）

| 编号 | 现状 | 建议 |
|------|------|------|
| P2-HC-1 LootSystem 11 级阈值 | 硬编码阈值表 | ✅ 保持 P2。提取为 config 表 |
| P2-HC-2 FortuneFruitSystem 30 坐标 | 硬编码果实坐标 | ✅ 保持 P2。提取为数据文件 |
| P2-HC-3 ~15 处颜色魔法数字 | 散落的 RGBA 数字 | ✅ 保持 P2。提取为主题常量表 |
| P2-HC-4 BossMechanics 参数 | 战斗参数硬编码 | ✅ 保持 P2。提取为 config |
| P2-HC-5 第四章缺 BGM 条目 | BGM 表少一条 | ⬆️ **建议顺手修**。补一行配置，零风险 |

#### 9.3.5 其他代码质量（12 项）

| 编号 | 现状 | 建议 |
|------|------|------|
| P2-Q-1 deprecated 函数活跃调用 | 标记废弃但仍在用 | ✅ 保持 P2 |
| P2-Q-2 v14 迁移冗余 | v15 已覆盖 | ✅ 保持 P2。可安全删除 |
| P2-Q-3 IIFE 包裹 require | 可读性差 | ✅ 保持 P2 |
| P2-Q-4 ExportToLocalFile 缺 nil 检查 | clientCloud 可能为 nil | ⬆️ **建议修复**。1 行 guard，防崩溃 |
| P2-Q-5 CopyNPC 白名单 19 字段 | 手动列举 | ✅ 保持 P2 |
| P2-Q-6 CONSUMABLES 别名语义 | 别名模糊 | ✅ 保持 P2 |
| P2-Q-7 gold_helmet_ch2 三重 fortune | 确认三条相同副属性 | ✅ 保持 P2。可能是设计意图（特殊道具），需确认 |
| P2-Q-8 ALL_EVENTS 无校验 | 事件表与实际不一致可能 | ✅ 保持 P2 |
| P2-Q-9 HUD 降频魔法数字 | `0.1` 硬编码 | ✅ 保持 P2 |
| P2-Q-10 SealDemon BatchSet | 确认用 BatchSet 而非 BatchCommit。DaoTree 已用 BatchCommit。 | ⬆️ **建议修复**。改一个函数名（`BatchSet` → `BatchCommit`），~1 行，一致性 + 原子性 |
| P2-Q-11 GM_ENABLED 手动关闭 | 依赖手动 | ✅ 保持 P2 |
| P2-Q-12 PetPanel 文案不准确 | "升级失败不消耗材料"应改为"路径A失败消耗技能书" | ✅ 保持 P2。改 1 行文案 |

---

### 9.4 再评估总结

#### 修复优先级重排

**新 B 档（推荐修复）— 共 5 项**：

| 优先序 | 编号 | 改动量 | 简述 |
|--------|------|--------|------|
| 1 | P1-UI-5 | ~8 行 | Pet:Destroy() 取消事件订阅 |
| 2 | P1-SRV-4 | ~8 行 | CreateChar 加 per-connection 防重入 |
| 3 | P1-SRV-7 | ~30 行 | C2S per-connection 限流 |
| 4 | P1-UI-6 | ~15 行 | 排行榜查询 10s 超时 |
| 5 | P1-SAVE-2 | ~20 行 | CloudStorage 15s 超时清理 |

**顺手修（P2 低风险高收益）— 共 4 项**：

| 编号 | 改动量 | 简述 |
|------|--------|------|
| P2-HC-5 | 1 行 | 第四章补 BGM 条目 |
| P2-Q-4 | 1 行 | ExportToLocalFile 补 nil 检查 |
| P2-Q-10 | 1 行 | SealDemon BatchSet → BatchCommit |
| P2-Q-12 | 1 行 | PetPanel 文案修正 |

**性能改善（P2 推荐）— 1 项**：

| 编号 | 改动量 | 简述 |
|------|--------|------|
| P2-PERF-2 | ~30 行 | Player.GetTotal* dirty flag 缓存 |

#### 关闭项

| 编号 | 原因 |
|------|------|
| P1-SAVE-4 | 当前代码已无双重 JSON 编码（误判或已修复） |
| P2-SAVE-4 | quota:Add 参数实际正确（误判） |
| P2-PERF-3 | P1-UI-1 修复后 SetInt 从 12 次降到 6 次，已缓解 |

#### 从 B 档降入 C 档（不建议修复）

| 编号 | 原因 |
|------|------|
| P1-SRV-3 | SRV-2 修复已覆盖主要风险路径 |
| P1-SAVE-1 | UI-2 防抖已遏制源头 |
| P1-UI-8 | 极低频率触发 |
| P1-SAVE-5 | requestId 机制已解决 |
| P1-SAVE-6 | 极端场景 |

---

*审计完成。本报告经五轮修订：P0 ×2 已全部修复；P1-A档 ×7 已全部修复并通过构建验证（共修复 9 项）。B/C/P2 共 42 项已完成再评估，其中 3 项关闭（误判/已不存在），5 项从 B 降为 C，1 项从 C 升为 B，剩余保持原档位。新 B 档推荐修复 5 项（~81 行），顺手修 4 项（~4 行）。*
