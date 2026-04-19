# 服务器基建评估：评估、执行、风险

> **项目**：人狗仙途 v2
> **范围**：覆盖路线图 Layer 0~4 全部服务器需求
> **创建日期**：2026-03-18
> **更新日期**：2026-03-28（新增阶段 B3 丹药计数修复）
> **基于**：server-save-migration.md v2.0、实际代码实现

---

## 目录

1. [serverCloud 能力盘点](#1-servercloud-能力盘点)
2. [各模块服务器需求映射](#2-各模块服务器需求映射)
3. [基建执行清单](#3-基建执行清单)
4. [依赖关系与执行顺序](#4-依赖关系与执行顺序)
5. [风险登记表](#5-风险登记表)
6. [验证完成标准](#6-验证完成标准)

---

## 1. serverCloud 能力盘点

### 1.1 可用 API 域

| 域 | API | 数据模型 | 适用场景 |
|----|-----|---------|---------|
| **Score** | Get / Set / SetInt / Add / Delete | 顶层 KV（scores + iscores） | 存档、配置、排行 |
| **BatchGet** | 单人多 Key / 多人多 Key | 批量读取 | 登录加载、排行展示 |
| **BatchSet** | 链式 Set/SetInt/Add/Delete | 批量写入 | 存档保存 |
| **Ranking** | GetRankList / GetUserRank / GetRankTotal | 基于 iscores 整数排序 | 排行榜 |
| **Money** | Get / Add / Cost | 命名货币，Cost 内置余额校验 | 灵韵、金币 |
| **List** | Get / GetById / Add / Modify / ModifyKey / Delete | 有序列表，每条有 list_id | 拍卖挂单、审计日志 |
| **Item** | Get / Add / Use | 命名道具+数量 | 简单道具管理 |
| **Message** | Send / Get / MarkRead / Delete | 跨用户消息 | 交易通知、邮件 |
| **Quota** | Get / Add / Reset | 限次计数器，支持 day/week/month 自动刷新 | 每日次数限制 |
| **BatchCommit** | 混合 Score+Money+List+Quota | 跨域原子事务 | 交易、购买 |

### 1.2 使用限制

| 限制项 | 值 |
|--------|-----|
| 读请求频率 | 300 次/分钟 |
| 写请求频率 | 300 次/分钟 |
| 单次 BatchCommit 操作数 | 1000 |
| Score 单 key 上限 | 1MB（serverCloud） |

### 1.3 关键发现

| # | 发现 | 影响 |
|---|------|------|
| D1 | **Money.Cost 内置余额校验** | 交易系统可直接用 MoneyCost，原子性有保障 |
| D2 | **Quota 内置时间刷新** — day/week/month 粒度 | 每日封妖、宝箱、签到全用 Quota |
| D3 | **BatchCommit 跨域原子** | 交易扣款+发货+记录可原子完成 |
| D4 | **所有数据绑定 userId** — 无公共数据存储 | 需要 SYSTEM_UID 方案 |
| D5 | **List 无条件查询** — 只能按 userId+key 列出 | 拍卖行搜索需服务端内存缓存 |
| D6 | **Message 支持跨用户发送** | 交易通知、GM 补偿可用 |
| D7 | **排行榜只排 iscores 整数** | 排行分数必须用 SetInt |
| D8 | **GetRankList 支持附加字段** ✅ 已验证 | rank_info / rank_time / boss_kills 可一次性查询 |

### 1.4 C/S 架构附带能力 ✅ 已验证

| 能力 | 机制 | 实际实现状态 |
|------|------|-------------|
| **版本握手拦截** | C2S_VersionHandshake → 检查 CODE_VERSION → 不匹配 Disconnect() | ✅ 已实现（server_main.lua HandleVersionHandshake） |
| **强制下线** | 服务端重启 → 所有连接断开 | ✅ 引擎内置 |
| **封禁** | ClientIdentity 阶段检查（预留扩展点） | ⚠️ 扩展点已预留，阶段 E 启用 |
| **在线监控** | connection.roundTripTime / bytesInPerSec | ✅ 引擎内置 |

### 1.5 不具备的能力

| 能力 | 应对方案 |
|------|---------|
| 全局/公共数据存储 | **SYSTEM_UID** 方案（待验证） |
| List 条件查询/排序 | 服务端内存缓存 |
| 定时任务/Cron | Quota 自动刷新 + HandleUpdate 轮询 |

---

## 2. 各模块服务器需求映射

### 2.1 Layer 0 — 服务器存档迁移 ✅ 已完成

**详见**: `server-save-migration.md` v2.0

| 需求 | 使用的 API | 实现状态 |
|------|-----------|---------|
| 存档读写 | Score.Set / Score.Get / BatchSet / BatchGet | ✅ 已实现 |
| 迁移备份 | Score.Set（save_migrate_backup_X） | ✅ 已实现 |
| 排行榜 | SetInt + GetRankList（附加字段） | ✅ 已实现 |
| C/S 通信 | SendRemoteEvent + VariantMap(JSON) | ✅ 15 个事件 |
| 身份认证 | ClientIdentity 事件 | ✅ 已实现 |
| 版本握手 | C2S_VersionHandshake + S2C_ForceUpdate | ✅ 已实现 |
| orphan self-healing | FetchSlots 反向验证 | ✅ 已实现 |
| 4 槽位扩展 | MAX_SLOTS=4, NEW_CHAR_MAX=2 | ✅ 已实现 |

**核心实现文件**：
| 文件 | 职责 |
|------|------|
| `server_main.lua` | 服务端全部 Handler |
| `client_main.lua` | 客户端入口（C/S 模式） |
| `network/SaveSystemNet.lua` | 客户端存档网络逻辑 |
| `network/CloudStorage.lua` | 存储抽象层 |
| `network/SaveProtocol.lua` | 事件定义 + 注册 |

#### 排行榜信任模型变化

| 项目 | 迁移前（纯客户端） | 迁移后（C/S） |
|------|-------------------|------------------|
| 排行榜写入 | 客户端 `clientScore:SetInt()` 直接写 | 服务端 `serverCloud.SetInt()` 服务端写 |
| 排行榜读取 | 客户端 `clientScore:GetRankList()` | 服务端 `serverCloud.GetRankList()` → 下发 |
| 分数可信度 | ❌ 客户端可篡改 | ✅ **服务端权威计算**（`ComputeRankFromSaveData`，不信任客户端 `rankData`） |
| 存档校验 | 无 | ✅ **P1 校验**：realm 合法性、level 范围、境界-等级一致性 |
| 排行榜自动修复 | — | ✅ **登录时自动修复**：`HandleFetchSlots` 检测缺失的 rank_score 并从存档重建 |
| 黑名单 | 客户端硬编码（LeaderboardUI.lua BLACKLIST） | 短期保留 → 阶段 E 迁移到服务端 |

---

### 2.2 Layer 2A — 日常玩法（悟道树 / 福源宝箱 / 封妖）

（内容与 v2.1 一致，略去细节。待阶段 C Quota 验证通过后启动。）

| 需求 | API | 说明 |
|------|-----|------|
| 每日限次 | Quota.Add | day 刷新 |
| 奖励发放 | BatchCommit | 原子提交 |
| 福源值校验 | Score.Get | 服务端判断 |

### 2.3 Layer 2B — 福利系统升级

| 需求 | API |
|------|-----|
| 全局公告配置 | Score.Set（SYSTEM_UID） |
| 兑换码 | Score.Set/Add（SYSTEM_UID） |
| 精准补偿 | Message.Send |

### 2.4 Layer 3 — 有限交易与回收

| 需求 | API |
|------|-----|
| 拍卖挂单 | List.Add（SYSTEM_UID） |
| 购买 | BatchCommit（MoneyCost + MoneyAdd + ListDelete） |
| 交易通知 | Message.Send |

### 2.5 灵韵迁移：Score → Money

灵韵从存档 player.lingyun 迁移到 Money 域，启用原子扣款和余额校验。

**迁移时机**：阶段 D（Money.Cost 验证通过后）。

### 2.6 Layer 4 — 多人合作

（内容与 v2.1 一致。需独立的网络验证，与主线互不阻塞。）

### 2.7 账号级数据 — 成就系统 + 神器系统

（内容与 v2.1 一致。依赖阶段 E 模块化架构。）

---

## 3. 基建执行清单

### 阶段 A — C/S 框架 + 存档迁移 ✅ 已完成

> **核查日期：2026-03-25**
> **总体完成度：100%**

| # | 任务 | 完成度 | 状态 | 说明 |
|---|------|--------|------|------|
| A1 | SaveProtocol.lua 事件定义 + 注册 | 100% | ✅ | 15 个 C2S/S2C 事件，RegisterAll() 统一注册 |
| A2 | server_main.lua（全部 Handler） | 100% | ✅ | HandleFetchSlots / HandleLoadGame / HandleSaveGame / HandleMigrateData / HandleCreateChar / HandleDeleteChar / HandleGetRankList / HandleVersionHandshake |
| A3 | CloudStorage.lua 网络模式 | 100% | ✅ | SetNetworkMode(true/false) 切换，BatchSet 代理到 C2S_SaveGame |
| A4 | 客户端迁移逻辑 | 100% | ✅ | SaveSystemNet.MigrateFromLocalFile 实现，迁移链自动触发 |
| A5 | client_main.lua | 100% | ✅ | C/S 入口，ServerReady 订阅，InitializeNetwork，120s 超时 |
| A6 | ~~装备全字段序列化~~ | N/A | ⏭️ | 延后到阶段 F |
| A7 | 版本号处理 | 100% | ✅ | **CURRENT_SAVE_VERSION = v10**（v10 新增封魔+体魄丹） |
| A8 | multiplayer 配置 | 100% | ✅ | enabled=true, max_players=2, background_match=true, free_match_with_ai |
| A9 | 版本握手 | 100% | ✅ | C2S_VersionHandshake → CODE_VERSION 比对 → S2C_ForceUpdate |
| A10 | ~~强制下线协议~~ | N/A | ⏭️ | 引擎内置重启断连已足够，S2C_Maintenance 延后到阶段 E |
| A11 | 全流程测试 | 100% | ✅ | fb533 验证：迁移→加载→保存→重进→排行榜 全部通过 |
| A12 | API 预验证 | 100% | ✅ | SendRemoteEvent 大数据、ClientIdentity、Scene 时序、排行榜附加字段 均已验证 |
| A13 | 排行榜防作弊 + 自动修复 | 100% | ✅ | P0: 服务端权威计算 rankScore（`ComputeRankFromSaveData`）；P0: 登录时自动修复缺失排行；P1: realm/level 合法性校验 |

**关键发现与偏差（相对原计划）**：

| 原计划 | 实际实现 | 原因 |
|--------|---------|------|
| CURRENT_SAVE_VERSION = 10 | 实际已升到 v10 | v10 新增封魔+体魄丹（v9 原则在前，v10 按需迭代） |
| MIGRATIONS[10] 封魔迁移 | MIGRATIONS[10] 已实现 | 清除旧 exorcism + 初始化 sealDemon + pillPhysique |
| 2 槽位 | 4 槽位（1-2 正常 + 3-4 恢复） | local_file 迁移需要不冲突的目标槽 |
| SaveProtocol 7 个事件 | 15 个事件 | 增加了 VersionHandshake、MigrateResult、GetRankList 等 |
| CloudStorage 有 MODE 常量 | SetNetworkMode() 函数 | 更灵活的切换方式 |
| server_main.lua 骨架代码 | 完整功能实现 | 一步到位 |
| 自测脚本 T1-T14 | 真机 QR 码测试（fb532/533） | 实际设备测试更可靠 |

---

### 阶段 B — 正式上线部署（计划：2026-03-26 晚）

**目标**：将 Phase 2 发布到 TapTap，存档迁移自动触发。

#### B-pre：发布前验证

| # | 步骤 | 操作 | 通过标准 |
|---|------|------|---------|
| B-pre.1 | 构建检查 | build 工具，确认无 LSP 错误 | 0 error |
| B-pre.2 | 配置核实 | multiplayer.enabled=true，双入口正确 | 配置无误 |
| B-pre.3 | 竖屏模式确认 | screen_orientation = "portrait" | 与线上一致 |
| B-pre.4 | GM 开关关闭 | GameConfig.GM_MODE = false | 生产模式 |
| B-pre.5 | QR 码测试 | 生成测试二维码 → 扫码全流程 | 迁移/加载/保存/重进通过 |
| B-pre.6 | 回退预演 | multiplayer.enabled=false → 构建 → clientScore 正常 | 回退路径可用 |

#### B-deploy：部署

| # | 步骤 | 操作 |
|---|------|------|
| B-deploy.1 | 白名单测试 | 测试账号扫码全流程 |
| B-deploy.2 | 发布到 TapTap | publish_to_taptap |
| B-deploy.3 | 强更确认 | TapTap 后台设置强更标记 |

#### B-monitor：监控（发布后 0-48h）

| # | 时间点 | 检查项 | 异常处理 |
|---|--------|--------|---------|
| B-mon.1 | +5min | 服务端存活，连接数 > 0 | 检查 Start() 日志 |
| B-mon.2 | +30min | 迁移 success/fail 统计 | 失败率>5% → 排查 |
| B-mon.3 | +1h | 排行榜数据非空 | 检查 rank_score 写入 |
| B-mon.4 | +2h | 自动/手动存档正常 | 查 S2C_SaveResult |
| B-mon.5 | +24h | 内存、连接数稳定 | 检查连接清理 |

**反馈回传分析**：使用 `get_debug_feedbacks` 工具拉取玩家反馈日志，分析迁移问题。

#### B-rollback：回退方案

| # | 操作 |
|---|------|
| 1 | settings.json multiplayer.enabled → false |
| 2 | project.json entry → "main.lua"，删除 entry@client/entry@server |
| 3 | 重新构建 + 发布 |
| 4 | 影响：serverCloud 新进度丢失，回到 clientScore 旧数据 |

---

### 阶段 B2 — C2S 验证缺口修复（全局日常反作弊）

> **核查日期：2026-03-28**
> **优先级：P0（存在可利用的刷取漏洞）**
> **前置：阶段 A 完成 + C1 Quota 已验证**

#### B2-背景：客户端时间漏洞

**问题**：多个日常系统使用客户端 `os.date("%Y-%m-%d")` 判断"今日是否已完成"。玩家修改设备时间即可无限刷取每日奖励。

**漏洞模式**：
```
客户端 GetTodayDate() → os.date("%Y-%m-%d") → 返回设备本地时间
  ↓
修改设备时间到第二天 → 绕过"今日已完成"检查 → 重复领取奖励
```

**正确模式**：
```
客户端发送 C2S 请求（不携带时间）
  ↓
服务端使用 serverCloud.quota:Add(userId, quotaName, 1, 1, "day") 验证
  ↓（quota 使用服务器时间，免疫客户端篡改）
服务端发放奖励 → S2C 返回结果 → 客户端更新 UI
```

#### B2-系统审计结果

| # | 系统 | 服务端 Handler | 客户端调用 C2S | Quota 保护 | 风险级别 | 状态 |
|---|------|---------------|---------------|-----------|---------|------|
| 1 | **试炼塔日常供奉** | ✅ `HandleTrialClaimDaily` (L2053) | ✅ TrialOfferingUI 已改 C2S | ✅ `trial_daily_offering` | 🟢 已修复 | ✅ 完成 |
| 2 | **封妖日常任务** | ✅ `HandleSealDemonAccept` (L1717) | ❌ 客户端从未调用 | ✅ `seal_demon_daily` | 🔴 严重 | ⏳ 待修复 |
| 3 | **封妖BOSS击杀** | ✅ `HandleSealDemonBossKilled` (L1899) | ❌ 客户端从未调用 | ✅ 服务端发奖 | 🔴 严重 | ⏳ 待修复 |
| 4 | **封妖放弃任务** | ✅ `HandleSealDemonAbandon` (L2021) | ❌ 客户端从未调用 | N/A | 🟡 中等 | ⏳ 待修复 |
| 5 | **悟道树** | ✅ `HandleDaoTreeStart` (L1333) | ✅ 客户端已走 C2S | ✅ `dailyDaoTree` | 🟢 安全 | ✅ 无需改动 |

**关键发现**：封妖系统的服务端 Handler（含 Quota）已完整实现，协议已定义在 SaveProtocol.lua 中并注册在 ALL_EVENTS 中，但客户端三个流程（接取/击杀/放弃）全部在本地执行，从未发送 C2S 事件。服务端 Handler 实际是**死代码**。

#### B2-封妖系统修复方案

**需要改动的客户端流程**（3 个）：

| 流程 | 当前（客户端本地） | 改为（C2S/S2C） |
|------|------------------|-----------------|
| **接取任务** | `SealDemonSystem.AcceptQuest/AcceptDaily()` 本地执行 | 发送 `C2S_SealDemonAccept` → 等待 `S2C_SealDemonAcceptResult` |
| **击杀BOSS** | `SealDemonSystem.OnMonsterDeath()` 本地发奖 | 发送 `C2S_SealDemonBossKilled` → 等待 `S2C_SealDemonReward` |
| **放弃任务** | `SealDemonSystem.AbandonActiveTask()` 本地执行 | 发送 `C2S_SealDemonAbandon` → 等待 `S2C_SealDemonAbandonResult` |

**涉及文件**：

| 文件 | 改动范围 | 说明 |
|------|---------|------|
| `scripts/systems/SealDemonSystem.lua` | AcceptQuest / AcceptDaily / OnMonsterDeath / AbandonActiveTask | 改为发 C2S + 订阅 S2C 回调 |
| `scripts/ui/SealDemonUI.lua` | 按钮 onClick / 状态刷新 | 添加 claiming 防抖、等待 S2C 后刷新 |
| `scripts/server_main.lua` | **无需改动** | Handler 已完整实现 |
| `scripts/network/SaveProtocol.lua` | **无需改动** | 协议已定义 |

#### B2-存档影响评估

| 维度 | 评估 | 原因 |
|------|------|------|
| **存档结构变更** | ✅ 无 | 服务端 Handler 读写的字段与客户端完全一致 |
| **存档版本号** | ✅ 不变（v9） | 只改通信路径，不改数据格式 |
| **存档覆盖竞态** | ⚠️ 存在但可控 | 见下方分析 |
| **数据一致性** | ⚠️ 需关注 | 服务端修改存档后，客户端下次 SaveGame 可能覆盖 |

**存档覆盖竞态分析**：

```
时间线：
T1: 服务端 HandleSealDemonBossKilled → 修改存档 sealDemon.quests[id]="completed"
T2: 客户端 S2C 回调 → 更新本地 SealDemonSystem 状态
T3: 客户端自动存档 → SaveGame 发送 coreData 到服务端
```

- **正常情况**（T2 < T3）：客户端收到 S2C 后更新本地状态 → 本地状态已含服务端修改 → SaveGame 写入正确
- **竞态情况**（T3 < T2，极少见）：客户端在收到 S2C 前触发 SaveGame → 旧数据覆盖服务端修改

**缓解措施**：
1. **Quota 是终极防线**：即使存档被覆盖，`seal_demon_daily` quota 已消耗，当日无法再次接取
2. **一次性任务幂等**：`HandleSealDemonAccept` 检查 `sealDemon.quests[id] == "completed"` → 拒绝重复接取
3. **客户端及时同步**：S2C 回调在 SaveGame 前执行的概率极高（网络延迟 < 自动存档间隔）

**结论**：竞态影响极低，最坏情况下一次性任务状态回退需重新击杀，但不会产生重复奖励。

#### B2-执行清单

| # | 任务 | 优先级 | 复杂度 | 状态 |
|---|------|--------|--------|------|
| B2.1 | **试炼塔日常供奉改 C2S** | P0 | 低 | ✅ 已完成 |
| B2.2 | 封妖接取任务改 C2S（AcceptQuest + AcceptDaily） | P0 | 中 | ⏳ |
| B2.3 | 封妖击杀上报改 C2S（OnMonsterDeath） | P0 | 中 | ⏳ |
| B2.4 | 封妖放弃任务改 C2S（AbandonActiveTask） | P0 | 低 | ⏳ |
| B2.5 | 封妖 UI 适配（防抖 + 等待态 + S2C 刷新） | P1 | 中 | ⏳ |
| B2.6 | 端到端测试（日常接取 → 击杀 → 奖励 → 次日刷新） | P0 | — | ⏳ |

#### B2-验证完成标准

- [ ] V1: 封妖日常接取 → 服务端日志 `[Server] SealDemonAccept daily OK` 出现
- [ ] V2: 封妖日常完成后再次接取 → S2C 返回 `daily_limit` 拒绝
- [ ] V3: 封妖 BOSS 击杀 → 服务端日志 `[Server] SealDemonBossKilled` + 存档写入 `quests[id]="completed"`
- [ ] V4: 客户端修改时间 → 封妖日常仍被服务端 quota 拒绝
- [ ] V5: 一次性任务接取/击杀/放弃全流程正常
- [ ] V6: 试炼塔日常供奉 C2S 流程正常（已验证）

---

### 阶段 B3 — 丹药计数丢失修复（P0 属性复刻漏洞）

> **核查日期**：2026-03-28
> **优先级**：P0（存在可利用的属性无限叠加漏洞）
> **前置**：阶段 A 完成
> **状态**：方案评估中

#### B3-背景：丹药计数丢失导致属性复刻

**现象**：玩家进阶到元婴后期后，虎骨丹/灵蛇丹/金刚丹服食计数归零（0/5），但属性加成仍在。玩家可以重新服食，无限叠加属性。

**漏洞模式**：
```
正常状态：player.maxHp = 基础 + 境界 + 丹药加成(150)    shop.tigerPillCount = 5/5
    ↓ 某条件触发 shop 数据丢失
异常状态：player.maxHp = 基础 + 境界 + 丹药加成(150)    shop.tigerPillCount = 0/5
    ↓ 玩家重新购买 5 颗虎骨丹
复刻结果：player.maxHp = 基础 + 境界 + 丹药加成(300)    shop.tigerPillCount = 5/5
```

#### B3-根因分析

**架构缺陷**：丹药的"效果"和"计数"存储在不同的数据桶中。

| 数据 | 存储位置 | 所属桶 |
|------|---------|--------|
| 丹药效果（maxHp/atk/def 增量） | 烙入 `player.maxHp` / `player.atk` / `player.def` | `coreData.player` |
| 丹药计数（已服食次数） | `shop.tigerPillCount` 等 | `coreData.shop` |

两者独立存储，**任何导致 `shop` 丢失而 `player` 保留的路径，都会产生不一致**。

**已定位的触发路径**：`TryRecoverSave` 元数据重建（SaveSystem.lua:2616）：

```lua
rebuildData = {
    player = {
        maxHp = baseHp + realmBonusHp,  -- 从头计算，不含丹药
        atk   = baseAtk + realmBonusAtk,
        def   = baseDef + realmBonusDef,
        ...
    },
    shop = {},          -- ← 空表，所有计数归零
    -- challenges 字段不存在 → ChallengeSystem.Deserialize 不被调用
}
```

但 `TryRecoverSave` 重建的 player 也不含丹药加成（从等级+境界重算），所以纯重建路径两侧一致。**bug 发生在重建数据与真实数据的比较取高逻辑中**：如果旧存档的 player（含丹药加成的高属性）被保留，但 shop 被重建数据的空表覆盖，就会产生不一致。

#### B3-全部丹药架构审计

| 丹药 | 效果存储 | 计数存储 | 同桶？ | 重复服食风险 |
|------|---------|---------|--------|------------|
| **虎骨丹** | player.maxHp（烙入） | shop.tigerPillCount | **否** | **🔴 有** |
| **灵蛇丹** | player.atk（烙入） | shop.snakePillCount | **否** | **🔴 有** |
| **金刚丹** | player.def（烙入） | shop.diamondPillCount | **否** | **🔴 有** |
| **千锤百炼丹** | player.pillConstitution（烙入） | shop.temperingPillEaten | **否** | **🔴 有** |
| **血煞丹** | player.atk + player.pillKillHeal（烙入） | challenges.xueshaDanCount | **否** | ⚠️ 目前安全¹ |
| **浩气丹** | player.maxHp + player.hpRegen（烙入） | challenges.haoqiDanCount | **否** | ⚠️ 目前安全¹ |
| **体魄丹** | player.pillPhysique | player.pillPhysique | **是** | ✅ 安全 |
| **悟道树** | player.daoTreeWisdom | player.daoTreeWisdom | **是** | ✅ 安全 |
| **福源果** | player.fruitFortune | fortuneFruits 系统 | **否** | **🔴 有** |

> ¹ 血煞/浩气"目前安全"是因为 `TryRecoverSave` 不创建 `challenges` 字段，`Deserialize` 不被调用，计数保持 `Init()` 的 0 值。但架构风险与 shop 组相同——未来任何丢失 challenges 的路径都会复现同样的 bug。

**结论**：体魄丹、悟道树安全（计数即效果，同桶）。其余所有"效果烙入 player + 计数存外部模块"的丹药**均有此隐患**。

#### B3-属性公式全量推导

**基础属性**（PLAYER_INITIAL + LEVEL_GROWTH）：

```
baseMaxHp = 100 + (level - 1) × 15
baseAtk   = 15  + (level - 1) × 3
baseDef   = 5   + (level - 1) × 2
```

**境界累计奖励**（GameConfig.REALMS，累加当前境界之前所有境界的 rewards）：

| 境界 | maxHp | atk | def |
|------|-------|-----|-----|
| lianqi_1~3 | +15/+23/+30 | +3/+5/+6 | +2/+3/+4 |
| zhuji_1~3 | +45/+53/+60 | +9/+11/+12 | +6/+7/+8 |
| jindan_1~3 | +75/+83/+90 | +15/+17/+18 | +10/+11/+12 |
| yuanying_1~3 | +105/+113/+120 | +21/+23/+24 | +14/+15/+16 |
| huashen_1~3 | +135/+143/+150 | +27/+29/+30 | +18/+19/+20 |
| heti_1~3 | +165/+173/+180 | +33/+35/+36 | +22/+23/+24 |
| dacheng_1~4 | +195/+203/+210/+218 | +39/+41/+42/+44 | +26/+27/+28/+29 |
| dujie_1~4 | +233/+240/+248/+255 | +47/+48/+50/+51 | +31/+32/+33/+34 |

**丹药加成**（永久烙入 player 基础属性）：

| 丹药 | 影响属性 | 单颗加成 | 上限 | 最大总贡献 |
|------|---------|---------|------|----------|
| 虎骨丹 | maxHp | +30 | 5 | +150 |
| 灵蛇丹 | atk | +10 | 5 | +50 |
| 金刚丹 | def | +8 | 5 | +40 |
| 千锤百炼丹 | pillConstitution | +1 | 50 | +50 |
| 血煞丹 | atk +8, pillKillHeal +5 | — | 9 | atk+72, killHeal+45 |
| 浩气丹 | maxHp +30, hpRegen +0.5 | — | 9 | maxHp+270, regen+4.5 |

**完整公式**：

```
player.maxHp = baseMaxHp + Σ境界maxHp + 虎骨丹×30 + 浩气丹×30
player.atk   = baseAtk   + Σ境界atk  + 灵蛇丹×10 + 血煞丹×8
player.def   = baseDef   + Σ境界def  + 金刚丹×8
```

**不影响 player.maxHp/atk/def 直接值的系统**（通过 `GetTotalX()` 间接加成）：
- equipAtk / equipDef / equipHp — 装备，独立字段
- collectionAtk / collectionDef / collectionHp — 收藏，独立字段
- titleAtk / titleAtkBonus — 称号，独立字段
- pillConstitution — 根骨，通过 `GetConstitutionDefBonus()` 影响
- pillPhysique — 体魄，通过 `GetPhysiqueHpBonus()` 影响
- daoTreeWisdom — 悟性，通过 `GetTotalWisdom()` 影响
- fruitFortune — 福缘，影响掉落率

#### B3-修复方案：两步法

**第一步：迁移校验（修复已损坏的存档）**

在 `ProcessLoadedData` 中，shop 和 challenges 都加载完毕后，检测不一致并反推正确计数。

**触发条件**：shop 组计数全为 0，但属性差值存在正数

**反推逻辑**：

```
expectedMaxHp = 100 + (level-1)×15 + Σ境界maxHp
expectedAtk   = 15  + (level-1)×3  + Σ境界atk
expectedDef   = 5   + (level-1)×2  + Σ境界def

hpDiff  = player.maxHp - expectedMaxHp    -- 全部丹药对 maxHp 的贡献
atkDiff = player.atk   - expectedAtk      -- 全部丹药对 atk 的贡献
defDiff = player.def   - expectedDef      -- 全部丹药对 def 的贡献

-- challenges 组计数可信，先扣除
shopHpContrib  = hpDiff  - haoqiDanCount × 30
shopAtkContrib = atkDiff - xueshaDanCount × 8

-- 反推 shop 组计数
tigerPillCount   = clamp(round(shopHpContrib / 30),  0, 5)
snakePillCount   = clamp(round(shopAtkContrib / 10), 0, 5)
diamondPillCount = clamp(round(defDiff / 8),          0, 5)
temperingPillEaten = clamp(player.pillConstitution,   0, 50)
```

**适用性评估**：

| 维度 | 评估 |
|------|------|
| 已损坏存档 | ✅ 能正确恢复计数 |
| 正常存档 | ✅ 不触发（shop 计数非全零，早期 return） |
| 未迁移存档 | ✅ 安全（迁移后走 ProcessLoadedData） |
| 新增丹药 | ❌ **不可扩展**：同一属性轴增加第二种 shop 组丹药时，一个方程两个未知数，无唯一解 |
| 公式变更 | ❌ **耦合**：LEVEL_GROWTH 或境界奖励调整后反推公式需同步更新 |

**结论：第一步是一次性补丁，仅用于修复已损坏的存档，不作为长期机制。**

**第二步：计数挪入 player（根治，防止未来再发生）**

将所有丹药计数从外部模块迁移到 `coreData.player`，与效果同桶存储。

**迁移映射**：

| 原位置 | 新位置 | 说明 |
|--------|--------|------|
| shop.tigerPillCount | player.tigerPillCount | 与 player.maxHp 同桶 |
| shop.snakePillCount | player.snakePillCount | 与 player.atk 同桶 |
| shop.diamondPillCount | player.diamondPillCount | 与 player.def 同桶 |
| shop.temperingPillEaten | player.temperingPillEaten | 与 player.pillConstitution 同桶 |
| challenges.xueshaDanCount | player.xueshaDanCount | 与 player.atk/pillKillHeal 同桶 |
| challenges.haoqiDanCount | player.haoqiDanCount | 与 player.maxHp/hpRegen 同桶 |
| fortuneFruits.collectedCount² | player.fortuneFruitCount | 与 player.fruitFortune 同桶 |

> ² 福源果计数的确切字段名需确认 FortuneFruitSystem 源码。

**迁移兼容逻辑**（ProcessLoadedData 中）：

```
-- 旧存档：计数在 shop/challenges/fortuneFruits 中，player 中没有
-- 新存档：计数在 player 中
if player.tigerPillCount == nil then
    -- 从旧位置读取
    player.tigerPillCount   = shop.tigerPillCount or 0
    player.snakePillCount   = shop.snakePillCount or 0
    player.diamondPillCount = shop.diamondPillCount or 0
    player.temperingPillEaten = shop.temperingPillEaten or 0
    player.xueshaDanCount   = challenges.xueshaDanCount or 0
    player.haoqiDanCount    = challenges.haoqiDanCount or 0
    player.fortuneFruitCount = fortuneFruits.collectedCount or 0
end
```

**为什么能根治**：

| 场景 | player 数据 | 计数 | 一致性 |
|------|-----------|------|--------|
| 正常存档 | 完好 | 完好（同桶） | ✅ |
| TryRecoverSave 重建 | 属性=基础+境界（无丹药） | 0（同桶一起重建） | ✅ 一致，可重新服食但无复刻 |
| 任何 player 丢失 | 丢失 | 丢失（同桶） | ✅ 一致 |

**关键**：效果和计数同生同灭。重建后玩家可以重新服食丹药，但因为属性也被重置（不含丹药加成），这是正确行为而非复刻。

**代码改动范围**：

| 文件 | 改动 |
|------|------|
| `SaveSystem.lua` — SerializePlayer | 新增序列化 tigerPillCount 等字段 |
| `SaveSystem.lua` — DeserializePlayer | 新增反序列化 + 旧存档兼容迁移 |
| `SaveSystem.lua` — ProcessLoadedData | 插入第一步反推校验逻辑 |
| `SaveSystem.lua` — TryRecoverSave | rebuildData.player 中加入计数字段=0 |
| `AlchemyUI.lua` — Getter/Setter | 改为读写 GameState.player.xxxPillCount |
| `ChallengeSystem.lua` — 丹药消耗 | 改为读写 GameState.player.xxxDanCount |
| `FortuneFruitSystem.lua` — 收集计数 | 改为读写 GameState.player.fortuneFruitCount |
| `CharacterUI.lua` — PILL_CONFIG | getCount 函数改为读 player 字段（多数已是） |

**不需要改动的**：
- 存档版本号：保持 v9（迁移≠优化）
- 服务端：透传，无需改动
- shop/challenges 序列化：保留兼容旧存档读取，但计数字段改从 player 读写

#### B3-风险评估

| ID | 风险 | 概率 | 影响 | 缓解 |
|----|------|------|------|------|
| R22 | **反推公式与实际属性不匹配**（存在其他未知的永久属性源） | 低 | 中 | 已全面审计所有 `player.maxHp/atk/def =` 赋值点，仅等级+境界+丹药三个来源；反推结果 clamp 到合法范围 |
| R23 | **迁移时旧存档 shop 计数丢失但 player 中无新字段** | 中 | 高 | 第一步反推校验兜底：先反推修复计数，再写入 player |
| R24 | **AlchemyUI/ChallengeSystem Getter/Setter 改动遗漏** | 低 | 中 | 全局搜索所有 `GetTigerPillCount` / `SetTigerPillCount` 等调用点 |
| R25 | **福源果计数迁移字段名不匹配** | 低 | 低 | 实施前确认 FortuneFruitSystem 序列化字段 |

#### B3-执行顺序

```
第一步（紧急热修）：
  1. ProcessLoadedData 末尾插入反推校验
  2. 构建 + 测试：正常存档不触发 / 模拟损坏存档能修复
  3. 发布

第二步（结构性根治）：
  4. AlchemyUI Getter/Setter 改为读写 player
  5. ChallengeSystem 丹药计数改为读写 player
  6. FortuneFruitSystem 收集计数改为读写 player
  7. SerializePlayer / DeserializePlayer 增加新字段
  8. ProcessLoadedData 增加旧存档兼容迁移
  9. TryRecoverSave rebuildData 补全计数字段
  10. 全流程测试
  11. 发布
```

#### B3-验证完成标准

- [ ] V1: 正常存档加载 → 反推校验不触发（日志无 `Pill count recovery`）
- [ ] V2: 模拟损坏存档（shop={}，属性含丹药加成）→ 反推恢复正确计数
- [ ] V3: 旧存档（计数在 shop 中）加载 → 自动迁移到 player 字段
- [ ] V4: 迁移后保存 → 重新加载 → 计数从 player 读取正确
- [ ] V5: TryRecoverSave 触发 → player 属性和计数均归零，一致
- [ ] V6: 恢复后重新服食丹药 → 计数正确累加，无复刻
- [ ] V7: 血煞丹/浩气丹/福源果计数迁移后功能正常

---

### 阶段 B4 — C/S 架构与存档结构全面优化方案（综合评估）

> **核查日期**：2026-03-28
> **优先级**：P0/P1 混合（含紧急修复项和结构性优化项）
> **前置**：阶段 A 完成、Phase 2 已上线
> **政策变化**：**不再考虑旧存档**（v1~v9 旧格式无需兼容），可执行破坏性变更

#### B4-现状审计总结

**审计范围**：SaveSystem.lua、server_main.lua、SaveProtocol.lua、Player.lua、GameConfig.lua、AlchemyUI.lua、ChallengeSystem.lua

| 维度 | 现状 | 评级 |
|------|------|------|
| **存档版本** | CURRENT_SAVE_VERSION = **10**（v10 新增封魔+体魄丹） | — |
| **协议覆盖** | 16 C2S + 16 S2C = 32 事件 | — |
| **C2S 系统覆盖** | 4/13 系统有服务端验证（30%） | 🔴 D 级 |
| **服务端权威** | 仅排行榜 + 悟道树 + 试炼塔供奉（20%） | 🔴 D 级 |
| **SaveGame 校验** | 仅 realm/level 合法性（排行用） | 🟡 C 级 |
| **经济体系校验** | 无（gold/lingYun/exp 直接信任客户端） | 🔴 F 级 |
| **序列化覆盖** | 100%（19 个 player 永久字段全部序列化） | 🟢 A 级 |
| **存档结构** | 三键拆分（save_data + bag1 + bag2） | 🟡 冗余 |
| **迁移管线** | MIGRATIONS v2~v10，共 9 个迁移函数 | 🟢 完整 |
| **恢复机制** | TryRecoverSave 6 级优先级 | 🟢 健壮 |
| **存档大小** | 10KB 告警（clientCloud 限制，serverCloud 1MB） | 🟡 旧阈值 |

#### B4-需求覆盖矩阵

| # | 用户需求 | 对应优化项 | 优先级 |
|---|---------|-----------|--------|
| 1 | 日常任务刷新、排行榜服务器校验等基础防作弊 | B4-S1 C2S 覆盖率提升 + B4-S2 SaveGame 增强校验 | P0 |
| 2 | 存档结构优化，包含丹药等属性校验 | B3 丹药修复（已有方案）+ B4-S3 存档结构重整 | P0 |
| 3 | 最大程度保证线上存档稳定性 | B4-S4 恢复机制增强 + B4-S5 存档健壮性 | P1 |
| 4 | 不再考虑旧存档 | B4-S6 历史债务清理 | P2 |
| 5 | 保证扩展性（参考后续计划） | B4-S7 架构扩展性 | P2 |

---

#### B4-S1：C2S 覆盖率提升（P0 防作弊）

**现状**：13 个客户端系统中仅 4 个走 C2S 验证，剩余 9 个纯客户端可篡改。

**覆盖现状**：

| # | 系统 | 当前 C2S | Quota 保护 | 客户端可篡改内容 | 修复优先级 |
|---|------|---------|-----------|----------------|-----------|
| 1 | 悟道树 | ✅ 完整 | ✅ dailyDaoTree | — | ✅ 已完成 |
| 2 | 试炼塔日常供奉 | ✅ 完整 | ✅ trial_daily_offering | — | ✅ 已完成 |
| 3 | 排行榜写入 | ✅ 服务端权威 | N/A | — | ✅ 已完成 |
| 4 | 版本握手 | ✅ 完整 | N/A | — | ✅ 已完成 |
| 5 | **封妖系统** | ❌ Handler 存在但客户端未调用 | ✅ seal_demon_daily | 每日任务/奖励 | **P0**（B2 已规划） |
| 6 | **炼丹/购药** | ❌ | 无 | 服食次数、金币消耗 | **P0**（B3+B4-S2） |
| 7 | **战斗/经验** | ❌ | 无 | exp、掉落、金币 | P1 |
| 8 | **进阶/突破** | ❌ | 无 | realm、属性跳变 | P1 |
| 9 | **装备锻造/洗练** | ❌ | 无 | 装备属性 | P1 |
| 10 | **宠物系统** | ❌ | 无 | 宠物等级/技能 | P2 |
| 11 | **收藏系统** | ❌ | 无 | 收藏属性加成 | P2 |
| 12 | **称号系统** | ❌ | 无 | 称号加成 | P2 |
| 13 | **技能系统** | ❌ | 无 | 技能等级 | P2 |

**本阶段目标**：将 P0 系统全部纳入 C2S 验证，覆盖率从 30% → 50%+。

**执行计划**：

| 步骤 | 任务 | 前置 |
|------|------|------|
| S1.1 | 封妖系统 C2S 接入（B2.2~B2.5） | 已规划 |
| S1.2 | 丹药购买/服食服务端校验（需新 C2S 事件） | B3 完成后 |
| S1.3 | SaveGame 增强校验（S2，不需要新 C2S） | 独立 |

**S1.2 丹药购买服务端校验设计**：

```
新增协议：
  C2S_BuyPill     → { pillType: string, count: int }
  S2C_BuyPillResult → { ok: bool, reason: string, newCount: int }

服务端 HandleBuyPill：
  1. 从 save_data 读取 player 和 pill counts
  2. 校验：gold >= cost × count
  3. 校验：currentCount + count <= maxBuy
  4. 原子操作：扣 gold + 加属性 + 更新计数
  5. BatchSet 写回存档
  6. 返回结果
```

> 注：此设计依赖 B3 完成（丹药计数挪入 player），否则需跨 shop/player 两桶操作。

---

#### B4-S2：HandleSaveGame 增强校验（P0 核心防作弊）

**现状**：HandleSaveGame 仅做 realm/level 校验（用于排行），对 coreData 其余字段**完全信任**。

**增强方案：服务端保存前校验层**

在 HandleSaveGame 解码 coreData 后、BatchSet 写入前，插入校验逻辑：

| # | 校验项 | 规则 | 不通过处理 |
|---|--------|------|-----------|
| V1 | **等级上限** | player.level ≤ realmCfg.maxLevel | cap 到合法值 |
| V2 | **经验值范围** | 0 ≤ player.exp ≤ 当前等级升级所需 exp | cap 到合法值 |
| V3 | **金币非负** | player.gold ≥ 0 | 置 0 |
| V4 | **灵韵非负** | player.lingYun ≥ 0 | 置 0 |
| V5 | **基础属性上限** | player.maxHp ≤ expectedMaxHp + 容差 | 记录日志（不阻断） |
| V6 | **基础攻击上限** | player.atk ≤ expectedAtk + 容差 | 记录日志（不阻断） |
| V7 | **基础防御上限** | player.def ≤ expectedDef + 容差 | 记录日志（不阻断） |
| V8 | **丹药计数上限** | 每种丹药 count ≤ maxBuy | cap 到合法值 |
| V9 | **境界合法** | player.realm ∈ GameConfig.REALMS | 已有（ComputeRankFromSaveData） |
| V10 | **境界-等级一致** | level ≥ requiredLevel | 已有 |

**V5~V7 容差计算**：

```lua
-- 使用 B3 已推导的公式
local expected = computeExpectedStats(player.level, player.realm)
local TOLERANCE = 1.5  -- 50% 容差，覆盖未知的加成来源
if player.maxHp > expected.maxHp * TOLERANCE then
    print("[Server][AntiCheat] Suspicious maxHp: " .. player.maxHp
        .. " expected≤" .. expected.maxHp * TOLERANCE)
    -- 首阶段只记日志，不阻断，收集数据后再收紧
end
```

**策略**：
- V1~V4, V8~V10：**硬校验**，超出直接修正
- V5~V7：**软校验**，首阶段仅记日志 + 打标记（`_flagged = true`），收集 2 周数据后收紧
- 所有校验失败均记录审计日志（AntiCheat 前缀），供人工巡检

**风险评估**：V5~V7 容差设 1.5 倍是因为目前属性来源已全面审计（等级+境界+丹药），但存在装备临时 buff 等边界情况。首阶段软校验避免误杀正常玩家。

---

#### B4-S3：存档结构重整（P0/P1 存档优化）

**三键合并为单键**（从阶段 F 提前到 B4，因"不再考虑旧存档"降低了风险）

| 维度 | 现状（三键） | 目标（单键） |
|------|------------|------------|
| 每槽 key 数 | save_data + save_bag1 + save_bag2 = 3 | save_X = 1 |
| 读取次数 | BatchGet 3 key | Get 1 key |
| 写入次数 | BatchSet 3 key | Set 1 key |
| 大小限制 | clientCloud 10KB/key | serverCloud 1MB/key（无忧） |
| 代码复杂度 | GetBag1Key/GetBag2Key 等 12 个函数 | 无需 |

**合并结构**：

```lua
-- save_X (单键，X=1~4)
{
    version = 11,
    timestamp = os.time(),
    player = { ... },        -- 含丹药计数（B3 迁移后）
    equipment = { ... },     -- 装备（全字段，不再精简序列化）
    inventory = { ... },     -- 背包（原 bag1+bag2 合并）
    skills = { ... },
    collection = { ... },
    pet = { ... },
    quests = { ... },
    shop = { ... },          -- 仅保留非丹药字段
    titles = { ... },
    challenges = { ... },    -- 仅保留非丹药计数字段
    sealDemon = { ... },
    trialTower = { ... },
    artifact = { ... },
    fortuneFruits = { ... }, -- 仅保留非计数字段
    bossKills = 0,
    bossKillTimes = { ... },
    bulletin = { ... },
}
```

**MIGRATIONS[11] 设计**：

```lua
[11] = function(data)
    -- 三键合并：bag1/bag2 → data.inventory（由外层 ProcessLoadedData 处理）
    -- 丹药计数挪入 player（B3 第二步）
    -- 装备去精简序列化（全字段保留）
    -- 删除 fillEquipFields 反查逻辑

    -- 标记版本
    data.version = 11
    return data
end
```

**与 B3 的合并执行**：B3 第二步（丹药计数挪入 player）和三键合并可在同一版本迁移中完成，共用 MIGRATIONS[11]。

**大小估算**：

| 数据 | 典型大小 |
|------|---------|
| save_data | 3~5 KB |
| save_bag1 | 2~4 KB |
| save_bag2 | 1~2 KB |
| 合并后 | 6~11 KB |
| serverCloud 单 key 上限 | 1 MB |
| 余量 | **~99%** |

结论：大小完全无忧，三键拆分仅是 clientCloud 10KB 限制的遗留，在 serverCloud 下毫无意义。

---

#### B4-S4：恢复机制增强（P1 稳定性）

**现状**：TryRecoverSave 6 级优先级已比较健壮，但存在几个缺口：

| # | 缺口 | 影响 | 修复方案 |
|---|------|------|---------|
| 1 | 元数据重建缺少 challenges/sealDemon/trialTower/artifact/fortuneFruits | 重建后这些系统数据丢失 | rebuildData 补全空初始化 |
| 2 | 元数据重建的 shop={} 导致丹药计数归零（B3 根因） | 属性复刻漏洞 | B3 + B4-S3 合并解决 |
| 3 | 10KB 告警阈值是 clientCloud 限制 | serverCloud 下无意义告警 | 改为 100KB 或删除 |
| 4 | checkpoint 不支持网络模式 | 网络模式下无中间检查点 | 阶段 F 实现 |

**S4.1 TryRecoverSave 补全**：

```lua
-- 当前缺失的字段，需要在 rebuildData 中补全：
rebuildData.challenges = {}
rebuildData.sealDemon = { quests = {} }
rebuildData.trialTower = {}
rebuildData.artifact = {}
rebuildData.fortuneFruits = {}
-- B3 丹药计数字段
rebuildData.player.tigerPillCount = 0
rebuildData.player.snakePillCount = 0
rebuildData.player.diamondPillCount = 0
rebuildData.player.temperingPillEaten = 0
rebuildData.player.xueshaDanCount = 0
rebuildData.player.haoqiDanCount = 0
rebuildData.player.fortuneFruitCount = 0
```

**S4.2 告警阈值调整**：

| 维度 | 当前 | 调整后 |
|------|------|--------|
| 大小告警 | 10 KB | 100 KB（serverCloud 1MB，10% 为警戒线） |
| 审计日志 | _auditCounter（每 10 次打印） | 保留但调整阈值 |

---

#### B4-S5：存档健壮性提升（P1 稳定性）

**存档失败检测改善**（§15 P0 热修复已部分覆盖）：

| 机制 | 状态 | 说明 |
|------|------|------|
| 15s 客户端超时检测 | ✅ 已实现 | 方案 1 |
| 30s 解锁计入失败 | ✅ 已实现 | 方案 4 |
| 无连接快速失败 | ✅ 已实现 | 方案 6 |
| 用户感知提示 | ✅ 已实现 | 方案 2 |
| **存档版本号服务端校验** | ❌ 未实现 | **新增** |
| **存档时间戳递增校验** | ❌ 未实现 | **新增** |

**S5.1 存档版本号服务端校验**：

HandleSaveGame 中增加：
```lua
if coreData.version ~= SaveSystem.CURRENT_SAVE_VERSION then
    -- 版本不匹配：可能是旧客户端的残留请求
    -- 记录日志但不阻断（version handshake 已拦截旧版本）
    print("[Server][Warning] Save version mismatch: got " .. tostring(coreData.version)
        .. " expected " .. CURRENT_SAVE_VERSION)
end
```

**S5.2 存档时间戳递增校验**：

```lua
-- 防止旧存档覆盖新存档（竞态保护）
local existingData = serverCloud:Get(userId, saveKey)
if existingData and existingData.timestamp then
    if coreData.timestamp and coreData.timestamp < existingData.timestamp then
        print("[Server][Warning] Save timestamp regression: "
            .. coreData.timestamp .. " < " .. existingData.timestamp)
        -- 首阶段仅记日志，不阻断
    end
end
```

> 注：S5.2 增加一次读操作，对性能有轻微影响。可改为内存缓存最新 timestamp。

---

#### B4-S6：历史债务清理（P2 降低维护成本）

**政策**：用户明确"不再考虑旧存档"，可清理 v1~v9 的兼容代码。

| # | 清理项 | 涉及文件 | 行数估算 | 风险 |
|---|--------|---------|---------|------|
| S6.1 | 删除 MIGRATIONS v2~v9（保留 v10→v11） | SaveSystem.lua | ~430 行 | 低 |
| S6.2 | 删除 REALM_COMPAT 映射 | GameConfig.lua + DeserializePlayer | ~15 行 | 低 |
| S6.3 | 删除 fillEquipFields 反查逻辑 | SaveSystem.lua | ~60 行 | 低 |
| S6.4 | 删除 DeserializeInventory compact 分支 | SaveSystem.lua | ~40 行 | 低 |
| S6.5 | 删除 GetBag1Key/GetBag2Key 等冗余函数 | SaveSystem.lua | ~30 行 | 低 |
| S6.6 | 删除 ExportToLocalFile（Phase 1 专用） | SaveSystem.lua | ~50 行 | 低 |
| S6.7 | 删除 MigrateToServer（clientCloud 迁移路径） | SaveSystemNet.lua | ~40 行 | 低 |
| S6.8 | 删除 local_file 迁移逻辑 | SaveSystemNet.lua | ~80 行 | 中 |
| S6.9 | 删除 save_export_X.json 读取逻辑 | SaveSystem.lua | ~30 行 | 低 |
| S6.10 | 简化 HandleMigrateData（仅保留 error 返回） | server_main.lua | ~150 行 | 中 |

**总清理量**：~925 行

**执行条件**：
1. 确认所有活跃玩家存档版本 ≥ v10
2. 确认迁移完成率达到目标（如 99%+）
3. S6.8/S6.10 需谨慎：仍有少量玩家可能尚未登录完成迁移

**建议**：
- S6.1~S6.7 可立即执行（纯代码清理，v11 迁移函数兜底）
- S6.8~S6.10 延后至迁移完成率确认后执行

---

#### B4-S7：架构扩展性（P2 面向后续计划）

**后续计划参考**：Layer 2A 日常玩法、Layer 3 交易、Layer 4 多人合作、阶段 G 账号级数据

| 扩展方向 | 当前瓶颈 | 优化方案 |
|---------|---------|---------|
| **新增日常系统** | 每个系统需手写 Handler + 在 server_main.lua 注册 | 阶段 E Handler 模式化 |
| **新增丹药/药品** | 计数分桶 → 扩展时不一致风险 | B3 同桶方案解决 |
| **经济体系扩展** | gold/lingYun 在存档 player 中，无原子操作 | 阶段 D 灵韵→Money API |
| **多角色共享数据** | 无账号级存储 | 阶段 G account_progress |
| **装备交易** | 装备序列化不统一 | B4-S3 全字段统一 |
| **存档版本迭代** | MIGRATIONS 链需维护 | S6 清理后链更短更清晰 |

**S7.1 Handler 注册制（阶段 E 预备）**：

当前 server_main.lua Start() 中手动注册 16 个 Handler（~32 行），随着系统增加会持续膨胀。

**预备设计**（阶段 E 时实现）：

```lua
-- handlers/ 目录结构
handlers/
├── save.lua         -- HandleSaveGame, HandleLoadGame, ...
├── daily.lua        -- HandleDaoTreeStart, HandleSealDemonAccept, ...
├── welfare.lua      -- (future) HandleRedeemCode, ...
└── trade.lua        -- (future) HandleAuction, ...

-- ServerCore 自动发现和注册
for _, handler in ipairs(handlers) do
    for event, func in pairs(handler.events) do
        SubscribeToEvent(event, func)
    end
end
```

**S7.2 新增系统的标准模板**：

每个新系统应遵循统一模式：
1. 在 SaveProtocol.lua 定义 C2S/S2C 事件
2. 在 handlers/ 创建 Handler 文件，导出 events 表
3. 在 SaveSystem.lua 的 SerializeXxx/DeserializeXxx 处理持久化
4. 使用 Quota API 进行限次控制
5. 使用 BatchCommit 确保原子操作

---

#### B4-执行分期与优先级

**第一期（P0 紧急修复，与 B2/B3 同步执行）**：

| # | 任务 | 依赖 | 复杂度 |
|---|------|------|--------|
| 1 | B3 第一步：丹药反推校验热修 | 无 | 中 |
| 2 | B2.2~B2.5：封妖系统 C2S 接入 | 无 | 中 |
| 3 | B4-S2 V1~V4：SaveGame 硬校验（level/exp/gold/lingYun） | 无 | 低 |
| 4 | B4-S2 V8：丹药计数上限校验 | B3 第一步 | 低 |
| 5 | B4-S4.1：TryRecoverSave rebuildData 补全 | 无 | 低 |

**第二期（P0 结构性修复，第一期完成后执行）**：

| # | 任务 | 依赖 | 复杂度 |
|---|------|------|--------|
| 6 | B3 第二步：丹药计数挪入 player | 第一期 #1 | 高 |
| 7 | B4-S3：三键合并为单键（MIGRATIONS[11]） | #6 | 高 |
| 8 | B4-S2 V5~V7：属性软校验（先记日志） | #6 | 中 |
| 9 | B4-S4.2：告警阈值调整 | #7 | 低 |
| 10 | B4-S5.1：存档版本号服务端校验 | 无 | 低 |

**第三期（P2 清理与扩展，线上稳定 2 周+后执行）**：

| # | 任务 | 依赖 | 复杂度 |
|---|------|------|--------|
| 11 | B4-S6.1~S6.7：历史债务清理（安全部分） | 第二期完成 | 中 |
| 12 | B4-S6.8~S6.10：迁移代码清理（需确认完成率） | 第二期 + 数据确认 | 中 |
| 13 | 阶段 E：Handler 模式化 | 第二期稳定后 | 高 |
| 14 | B4-S5.2：时间戳递增校验 | 第二期 | 低 |

---

#### B4-风险评估

| ID | 风险 | 概率 | 影响 | 缓解 |
|----|------|------|------|------|
| R30 | **三键合并迁移数据丢失** | 低 | 严重 | MIGRATIONS[11] 中 bag1/bag2 合并前备份到 save_pre_merge_X；回退路径保留旧三键读取能力 |
| R31 | **SaveGame 校验误杀正常玩家** | 中 | 高 | V5~V7 首阶段仅记日志（软校验）；V1~V4 有明确合法范围不会误杀；收集 2 周数据后再决定是否硬校验 |
| R32 | **清理旧迁移后少量玩家无法加载** | 低 | 高 | S6 执行前统计活跃存档版本分布；保留 MIGRATIONS[10→11] 作为最低兼容 |
| R33 | **S5.2 时间戳校验阻断正常保存** | 低 | 高 | 首阶段仅记日志不阻断；客户端时间不准可能导致 false positive |
| R34 | **三键合并后装备全字段导致大小膨胀** | 低 | 低 | 当前三键总计 6~11KB，serverCloud 1MB 上限，余量 ~99% |

---

#### B4-验证完成标准

**第一期**：
- [ ] V1: SaveGame 硬校验生效 — level > maxLevel 被 cap + 日志
- [ ] V2: SaveGame 硬校验生效 — gold < 0 被置 0 + 日志
- [ ] V3: 丹药计数 > maxBuy 被 cap + 日志
- [ ] V4: TryRecoverSave 重建含完整子系统空数据

**第二期**：
- [ ] V5: 三键合并后单键加载/保存正常
- [ ] V6: MIGRATIONS[11] 正确执行：bag1+bag2 → inventory，丹药计数 → player
- [ ] V7: 属性软校验日志在异常存档上触发
- [ ] V8: 告警阈值 100KB 不误报
- [ ] V9: 存档版本号校验日志正常

**第三期**：
- [ ] V10: 删除 MIGRATIONS v2~v9 后，v10 存档仍能正常加载
- [ ] V11: 删除 ExportToLocalFile 后构建无错误
- [ ] V12: Handler 模式化后全部 C2S 事件响应正常

---

#### B4-版本号规划（更新）

| 版本 | 阶段 | 内容 |
|------|------|------|
| **v10**（当前） | 阶段 A/B/B2/B3第一步 | 迁移通道 + 封魔 + 体魄丹 + 反推热修 |
| **v11** | **B3第二步 + B4-S3** | **丹药计数挪入 player + 三键合并 + 装备全字段 + 历史债务清理** |
| **v12** | 阶段 D | 灵韵从 Score 迁移到 Money |
| **v13** | 阶段 G | 成就+神器账号级迁移 |

> 关键变化：原计划 v10=灵韵、v11=三键合并。因"不再考虑旧存档"，三键合并提前到 v11 与 B3 合并执行。灵韵顺延到 v12。

---

### 阶段 C — API 完整验证（阶段 B 稳定后启动）

**前置**：阶段 B 上线稳定至少 2-3 天。

| # | 验证项 | 方法 | 对应功能 |
|---|--------|------|---------|
| C1 | ~~Quota 自动刷新~~ | ✅ **已验证通过**（fb544: Add/Get/OverLimit/BatchCommit+Quota 8步全通过） | 日常玩法 |
| C2 | SYSTEM_UID 读写 | `Score.Set(0, "test", {...})` | 福利/拍卖 |
| C3 | List（SYSTEM_UID） | `List.Add(0, "auction", {...})` | 拍卖行 |
| C4 | Money.Cost 余额校验 | `Money.Cost(uid, "gold", 99999)` | 交易 |
| C5 | BatchCommit 原子回滚 | MoneyCost(不够) + MoneyAdd 一次提交 | 交易 |
| C6 | Message 跨用户 | `Message.Send(uid1, "test", uid2, {...})` | 交易通知 |

---

### 阶段 D — 灵韵迁移（C4 验证通过后）

| # | 任务 |
|---|------|
| D1 | 读 player.lingyun → Money.Add |
| D2 | 双读兼容（优先 Money.Get，fallback saveData） |
| D3 | 消费逻辑改 Money.Cost |
| D4 | 获取逻辑改 Money.Add |
| D5 | 客户端余额同步 |

---

### 阶段 E — 服务端模块化架构（阶段 B 稳定后即可开始）

| # | 任务 | 产出 |
|---|------|------|
| E1 | 设计 Handler 模式 | ServerCore 路由 + 功能 Handler |
| E2 | 创建 handlers/ 目录 | 模块化结构 |
| E3 | 提取 SaveHandler | 从 server_main.lua 分离 |
| E4 | DailyHandler 骨架 | 悟道树/宝箱/封妖 |
| E5 | WelfareHandler 骨架 | 配置下发/兑换码 |
| E6 | TradeHandler 骨架 | 拍卖行/回收 |
| E7 | BanHandler | 封禁名单 + 连接拦截 + 排行榜过滤 + 作弊检测 |

**推荐目标架构**：

```
scripts/
├── client_main.lua
├── server_main.lua              # 入口（初始化 + 注册）
├── network/
│   ├── CloudStorage.lua
│   ├── SaveProtocol.lua
│   ├── SaveSystemNet.lua
│   ├── ServerCore.lua           # 新增：路由 + 连接管理
│   └── handlers/
│       ├── SaveHandler.lua      # 从 server_main.lua 提取
│       ├── BanHandler.lua       # 封禁管理
│       ├── DailyHandler.lua     # 日常玩法
│       ├── WelfareHandler.lua   # 福利系统
│       └── TradeHandler.lua     # 交易回收
```

#### E7 BanHandler 设计

**封禁能力分层**：

| 层级 | 能力 | 机制 |
|------|------|------|
| L1 | 连接拦截 | ClientIdentity 阶段检查 banList → Disconnect() |
| L2 | 排行榜剔除 | 保存存档时跳过 SetInt |
| L3 | 存档冻结 | 拒绝封禁玩家的保存请求 |
| L4 | 主动踢人 | 向目标 connection 发送断开指令 |

**作弊发现能力**：
- AD1 — 存档异常自动检测（保存时检查等级/灵韵/装备异常）
- AD2 — 全排行榜审计日志（所有写入均记录，不再只 Top 10）
- AD3 — GM 远程查询（可选）

**替代客户端 BLACKLIST 的路径**：BanHandler 上线 → 迁移 BLACKLIST.userIds → 确认服务端过滤生效 → 删除客户端过滤逻辑。

---

### 阶段 F — 存储结构优化（迁移稳定 2 周+ 后）

> **前置**：阶段 B 稳定运行 2 周+。与 C/D/E 及 Layer 2~4 互不阻塞。
> **绝不与迁移同版本发布。**

| # | 任务 | 说明 |
|---|------|------|
| F1 | 三键合并为单键 | save_data + save_bag1 + save_bag2 → save_X |
| F2 | 装备去精简序列化 | 统一全字段 |
| F3 | 删除 fillEquipFields | ~60 行反查逻辑 |
| F4 | 备份体系简化 | 每槽 14 key → 4 key |
| F5 | 删除冗余 key 函数 | GetBag1Key 等 12 个 |
| F6 | 删除数据审计代码 | measureSize + _auditCounter |
| F7 | 注册版本迁移 | v9 → 新版本（三键合并 + 字段补全） |
| F8 | 全流程回归测试 | 新旧存档各跑一遍 |

---

### 阶段 G — 账号级数据（成就 + 神器）

> **前置**：阶段 E 模块化架构就绪。

（内容与 v2.1 一致：G1-G10 任务清单。）

将称号系统替换为成就系统，与神器系统一起从角色级提升到账号级。

---

## 4. 依赖关系与执行顺序

### 4.1 时间线（基于实际进度更新）

```
━━━━━━━━━━━━━━ 已完成 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ Phase 1：本地导出版本（线上运行中）
  ✅ 阶段 A：C/S 框架 + 存档迁移（全部任务完成 + 测试通过）

━━━━━━━━━━━━━━ 2026-03-26 晚 上线 ━━━━━━━━━━━━━━━━━━

  阶段 B：部署 + 监控 + 回退准备
  阶段 B2：C2S 验证缺口修复（P0 反作弊）
    ├─ B2.1 试炼塔日常供奉 ✅ 已完成
    └─ B2.2~B2.5 封妖系统 C2S 接入 ⏳
  阶段 B3：丹药计数丢失修复（P0 属性复刻漏洞）⏳
    ├─ 第一步：反推校验热修（紧急）
    └─ 第二步：计数挪入 player（根治，合并到 B4-S3）
  阶段 B4：C/S 架构与存档结构全面优化 ⏳
    ├─ 第一期 P0：SaveGame 校验 + TryRecoverSave 补全
    ├─ 第二期 P0：三键合并 + v11 迁移（含 B3 第二步）
    └─ 第三期 P2：历史债务清理 ~925 行

━━━━━━━━━━━━━━ 上线后稳定期 ━━━━━━━━━━━━━━━━━━━━━━━

  阶段 C: API 完整验证 ──────────────┐
  阶段 E: 服务端模块化（可并行）       │
                                      ↓
  阶段 D: 灵韵迁移（依赖 C4）────────┐
                                      │
  ┌───────────────────────────────────┘
  ↓
  Layer 2A: 日常玩法（依赖 C1 Quota）
  Layer 2B: 福利升级（依赖 C2 SYSTEM_UID）  ← 互不依赖，可并行
  Layer 3:  交易回收（依赖 D + C2/C3/C5）   ← 最晚
  Layer 4:  多人合作（独立线）

━━━━━━━━━━ B4 第三期完成后 ━━━━━━━━━━━━━━━━━━━━━━━━━

  ~~阶段 F: 存储结构优化~~ → 已合并到 B4-S3/S6
  阶段 G: 账号级数据（依赖 E 模块化）
```

### 4.2 关键路径

```
主线：阶段 B → 阶段 C.C4 → 阶段 D → Layer 3（交易）
优化线：阶段 B 稳定 2 周+ → 阶段 F（独立版本，与主线互不阻塞）
```

### 4.3 可并行工作

| 主线 | 可并行 |
|------|--------|
| 阶段 C（API 验证） | 阶段 E（模块化） |
| Layer 2A（日常玩法） | Layer 2B（福利升级） |
| 阶段 F（结构优化） | Layer 2~4 功能开发 |
| 阶段 G（账号级数据） | 阶段 F + Layer 2A/2B/3 |

### 4.4 版本号规划

| 版本 | 阶段 | 内容 |
|------|------|------|
| **v10**（当前） | 阶段 A/B/B2/B3第一步 | 迁移通道 + 封魔 + 体魄丹 + 反推热修 |
| **v11** | B3第二步 + B4-S3 | 丹药计数挪入 player + 三键合并 + 装备全字段 + 历史债务清理 |
| **v12** | 阶段 D | 灵韵从 Score 迁移到 Money |
| **v13** | 阶段 G | 成就+神器账号级迁移 |

> 关键变化：因"不再考虑旧存档"，三键合并提前到 v11 与 B3 合并执行。灵韵顺延到 v12。

---

## 5. 风险登记表

### 5.1 高风险

| ID | 风险 | 概率 | 影响 | 缓解 |
|----|------|------|------|------|
| R1 | **SYSTEM_UID 被拒** | 中 | 严重 | 阶段 C.C2 优先验证；备选：GM 真实账号 |
| R2 | ~~SendRemoteEvent 数据大小~~ | — | — | ✅ **已验证通过**（fb533 迁移 9828 bytes 成功） |
| R3 | **BatchCommit 部分失败不回滚** | 低 | 严重 | 阶段 C.C5 测试 |
| R4 | ~~迁移数据丢失~~ | — | — | ✅ **已验证通过**（fb533 Lv.25 数据完整） |
| R5 | ~~排行榜分数伪造~~ | — | — | ✅ **已消除**（A13: 服务端权威计算 + P1 存档校验） |

### 5.2 中风险

| ID | 风险 | 概率 | 影响 | 缓解 |
|----|------|------|------|------|
| R6 | 拍卖行性能瓶颈（List.Get 全量返回） | 中 | 中 | 内存缓存+分页 |
| R7 | ~~排行榜附加字段不兼容~~ | — | — | ✅ **已验证支持** |
| R8 | 灵韵双写一致性 | 中 | 中 | 迁移完成后废弃 Score 域读取 |
| R9 | Rate Limit（300 写/分） | 低 | 中 | BatchSet 合并 |
| R10 | 多 Scene 不支持 | 中 | 中 | 用引擎匹配系统替代 |
| R11 | 客户端黑名单可绕过 | 高 | 中 | 阶段 E 迁移到服务端 |
| R12 | 多角色成就/神器合并 bug | 中 | 中 | 合并前备份 |
| R20 | **封妖日常客户端时间作弊** | 高 | 高 | 阶段 B2: 接入已有服务端 Handler + Quota |
| R21 | **C2S 改造后存档覆盖竞态** | 低 | 中 | Quota 兜底 + 一次性任务幂等校验；详见 B2-存档影响评估 |
| R22 | **丹药反推公式与实际属性不匹配** | 低 | 中 | 已全面审计属性来源；clamp 到合法范围；详见 B3-风险评估 |
| R23 | **旧存档 shop 计数丢失 + player 无新字段** | 中 | 高 | 第一步反推校验兜底；详见 B3-风险评估 |
| R24 | **丹药 Getter/Setter 改动遗漏** | 低 | 中 | 全局搜索调用点；详见 B3-风险评估 |

| R16 | **存档响应丢失（15s 超时）** | 低 | 高 | 方案1: 客户端 15s 超时检测 → 自动重试 |
| R17 | **serverConn nil 时静默丢弃存档** | 中 | 高 | 方案6: Save() 预检 serverConn → 快速失败+重试 |
| R18 | **30s 锁死不计入失败次数** | 中 | 中 | 方案4: 30s 解锁时递增 consecutiveFailures+退避重试 |
| R19 | **存档失败无用户感知** | 高 | 中 | 方案2: ≥2 次连续失败时浮字提示 |
| R30 | **三键合并迁移数据丢失** | 低 | 严重 | MIGRATIONS[11] 合并前备份到 save_pre_merge_X；回退路径保留旧三键读取能力；详见 B4-S3 |
| R31 | **SaveGame 校验误杀正常玩家** | 中 | 高 | V5~V7 首阶段仅记日志（软校验）；V1~V4 有明确合法范围不会误杀；收集 2 周数据后再决定；详见 B4-S2 |
| R32 | **清理旧迁移后少量玩家无法加载** | 低 | 高 | S6 执行前统计活跃存档版本分布；保留 MIGRATIONS[10→11] 作为最低兼容；详见 B4-S6 |
| R33 | **S5.2 时间戳校验阻断正常保存** | 低 | 高 | 首阶段仅记日志不阻断；客户端时间不准可能导致 false positive；详见 B4-S5 |

### 5.3 低风险

| ID | 风险 | 概率 | 影响 | 缓解 |
|----|------|------|------|------|
| R13 | ~~Quota 刷新时区问题~~ | — | — | ✅ **已验证通过**（fb544 day 刷新正常） |
| R14 | Message 积压 | 低 | 低 | 定期清理 |
| R15 | 服务端代码膨胀 | 中 | 低 | 阶段 E 模块化 |
| R34 | **三键合并后装备全字段导致大小膨胀** | 低 | 低 | 当前三键总计 6~11KB，serverCloud 1MB 上限，余量 ~99%；详见 B4-S3 |

### 5.4 已消除的风险

| 原 ID | 风险 | 消除原因 |
|-------|------|---------|
| R2 | SendRemoteEvent 数据大小限制 | fb533 验证 9828 bytes 迁移成功 |
| R4 | 迁移数据丢失 | fb533 Lv.25 数据完整恢复 + orphan self-healing |
| R7 | 排行榜附加字段不兼容 | 实际验证 GetRankList 支持 rank_info/rank_time/boss_kills |
| — | Lua `#` 稀疏表计数 | 日志 bug 已修复（pairs() 替代） |
| — | Phase 2 重建丢失多人配置 | 完整配置参数已记录 |
| R13 | Quota 刷新时区问题 | fb544 验证 day 刷新正常，8步全通过 |
| R5 | 排行榜分数伪造 | A13: 服务端 `ComputeRankFromSaveData` 权威计算 rankScore + P1 realm/level 校验 |

---

## 6. 验证完成标准

### 6.1 阶段 A ✅ 已全部通过

- [x] server_main.lua 启动无报错
- [x] client_main.lua 连接服务端
- [x] ClientIdentity 获取 userId
- [x] Scene 三步时序无报错
- [x] SendRemoteEvent 往返 JSON 一致
- [x] SaveProtocol 所有事件已注册
- [x] 版本握手：旧版被拒
- [x] 旧存档迁移：local_file → slotMap 重映射 → 写入 serverCloud → 客户端读取正常
- [x] 新建角色 → 保存 → 退出 → 重进 → 数据一致
- [x] 排行榜正常
- [x] 大数据 RemoteEvent 传输成功
- [x] orphan self-healing 反向验证通过

### 6.2 阶段 B 完成标准（待执行）

- [ ] 强更发布成功
- [ ] 迁移成功率 > 99%
- [ ] 活跃玩家数据完整性抽查
- [ ] 自动/手动存档正常
- [ ] 排行榜正常
- [ ] 回退方案已验证可执行
- [ ] V1: 日志搜索 `Save TIMEOUT` / `Save SKIPPED` / `30s stuck unlock` 确认新代码路径可达
- [ ] V2: 日志搜索 `save_warning` 确认 UI 提示可触发
- [ ] V3: 日志搜索 `save_warning_clear` 确认失败后可自动恢复
- [ ] V4: 断网 → 120s 等自动存档 → `Save SKIPPED: no serverConn` → 恢复网络 → `save_warning_clear`

### 6.2b 阶段 B2 完成标准（进行中）

- [x] B2.1: 试炼塔日常供奉改 C2S + Quota 保护（2026-03-27）
- [ ] B2.2: 封妖接取任务改 C2S（AcceptQuest + AcceptDaily）
- [ ] B2.3: 封妖击杀上报改 C2S（OnMonsterDeath）
- [ ] B2.4: 封妖放弃任务改 C2S（AbandonActiveTask）
- [ ] B2.5: 封妖 UI 防抖 + 等待态适配
- [ ] B2.6: 端到端测试（日常接取 → 击杀 → 奖励 → 次日 quota 拒绝）

### 6.2c 阶段 B3 完成标准（方案评估中）

- [ ] B3.step1: ProcessLoadedData 反推校验（热修已损坏存档）
- [ ] B3.step2.1: AlchemyUI Getter/Setter 改读写 player
- [ ] B3.step2.2: ChallengeSystem 丹药计数改读写 player
- [ ] B3.step2.3: FortuneFruitSystem 收集计数改读写 player
- [ ] B3.step2.4: SerializePlayer/DeserializePlayer 增加新字段
- [ ] B3.step2.5: TryRecoverSave rebuildData 补全计数字段
- [ ] B3.step2.6: 全流程测试（V1~V7 全部通过）

### 6.2d 阶段 B4 完成标准（方案已完成，待执行）

> 详细验证标准见 B4-验证完成标准 V1~V12。

**Phase 1（P0 紧急修补）**：
- [ ] B4-S2: HandleSaveGame 10 项校验上线（V1~V4 硬校验 + V5~V8 软校验）
- [ ] B4-S1: 封妖/试炼塔 C2S 全量覆盖
- [ ] B4-S4.1: TryRecoverSave rebuildData 补全 19 个 player 字段
- [ ] B4-S5: 存档鲁棒性改进（时间戳/CRC 校验，软校验）

**Phase 2（P0 结构性）**：
- [ ] B4-S3: 三键合并 + MIGRATIONS[11]（v10→v11）
- [ ] B4-S3: 丹药计数挪入 player + 装备全字段序列化
- [ ] B4-S6: 旧迁移清理（MIGRATIONS[2]~[9] 删除，~925 行）

**Phase 3（P2 清理）**：
- [ ] B4-S7: validateSaveData / SyncManager 架构预留
- [ ] B4: 2 周软校验日志分析 → 决定是否转硬校验

### 6.3 阶段 C 完成标准（待执行）

- [x] C1: Quota.Add day 刷新验证 ✅ fb544 验证通过（2026-03-25）
- [ ] C2: SYSTEM_UID 读写验证
- [ ] C3: List（SYSTEM_UID）增删改查
- [ ] C4: Money.Cost 余额不足 error
- [ ] C5: BatchCommit 失败回滚
- [ ] C6: Message 跨用户收发

### 6.4 阶段 D 完成标准（待执行）

- [ ] 灵韵 Money.Add 迁移成功
- [ ] Money.Get 余额正确
- [ ] Money.Cost 扣款正常
- [ ] 客户端 UI 显示正确

### 6.5 阶段 E 完成标准（待执行）

- [ ] ServerCore 路由框架就绪
- [ ] SaveHandler 从 server_main.lua 提取
- [ ] Handler 注册制（新增不改 server_main.lua）
- [ ] BanHandler 四层封禁能力就绪
- [ ] 作弊发现能力就绪

### 6.6 阶段 F 完成标准（已合并至 B4-S3/S6）

> ⚠️ 阶段 F 原有内容已合并至 B4-S3（三键合并）和 B4-S6（历史债务清理）。
> 验证标准详见 B4-验证完成标准 V1~V12。

- ~~三键合并为单键~~ → B4-S3
- ~~装备全字段序列化~~ → B4-S3
- ~~fillEquipFields 删除~~ → B4-S6
- ~~备份简化~~ → B4-S3
- ~~版本迁移管线通过~~ → B4-S3（MIGRATIONS[11]）

### 6.7 阶段 G 完成标准（待执行）

- [ ] account_progress 数据结构定义
- [ ] 账号级事件通信正常
- [ ] 多角色合并逻辑正确
- [ ] 成就/神器从账号级数据读取
- [ ] 属性加成与迁移前一致

---

## 附录 A — 已验证的 Bug 与修复记录

| 日期 | Bug | 根因 | 修复 | 验证 |
|------|-----|------|------|------|
| 2026-03-24 | FetchSlots ok: 0 slots | Lua `#` 对稀疏表返回 0 | pairs() 计数替换 | fb533 后续测试 |
| 2026-03-24 | Phase 2 重建出现匹配房间界面 | 构建时未传完整 multiplayer 参数 | 补全 background_match + match_info 全量参数 | 重新构建通过 |
| 2026-03-24 | PC 预览 WebSocket 报错 | 多人游戏无法在 PC 预览运行 | 预期行为，需手机扫码测试 | 确认 |
| 2026-03-25 | local_file 迁移排行榜分数错误 | SaveSystemNet:640 写 `p.level` 而非 `realmOrder*1000+level`，且缺 rank_info_/boss_kills_ | 从 GameConfig.REALMS 重建完整 rankScore + 补全 rank_info_/boss_kills_ | fb544 |
| 2026-03-25 | C.C1 Quota API 验证 | — | 8步自动测试：Reset→Add×3→OverLimit→Get→BatchCommit(Quota+Score)→Get→Cleanup，全部 PASS | fb544 |
| 2026-03-26 | 排行榜只有 4 个账号数据 | clientCloud 与 serverCloud 完全隔离，迁移时排行榜数据未搬运；只有迁移后存过档的 4 个玩家有 rank_score | P0: HandleSaveGame 改为服务端权威计算 rankScore（`ComputeRankFromSaveData`），不信任客户端 rankData；P0: HandleFetchSlots 登录时自动检测并修复缺失的 rank_score；P1: realm 合法性 + level 范围 + 境界-等级一致性校验 | 构建通过 |

## 附录 B — 关键构建参数备忘

**每次构建 Phase 2 时必须传递的完整参数**：

```
scriptsPath: "scripts"
entry_client: "client_main.lua"
entry_server: "server_main.lua"
multiplayer:
  enabled: true
  max_players: 2
  background_match: true
  match_info:
    desc_name: "free_match_with_ai"
    player_number: 1
    match_timeout: 5
    immediately_start: true
```

**只传 `{ enabled: true }` 会导致其他字段被重置为默认值！**

## 附录 C — Rate Limit 预估

（内容与 v2.1 一致，8 人场景 ~28 次/分，远低于 300 限制。）

---

*文档版本: v3.5*
*创建日期: 2026-03-18*
*更新日期: 2026-03-28*

**版本历史**：
| 版本 | 变更 |
|------|------|
| v1.0~v2.1 | 初始版本至阶段 G 新增（详见旧版本历史） |
| **v3.0** | **基于实际实现全面更新**：阶段 A 完成度 35%→100%（全部任务已完成并测试通过）；消除已验证的风险项（R2/R4/R7）；新增 Bug 修复记录；新增构建参数备忘录；版本号规划调整（v9 保持不变→v10 灵韵→v11 结构优化）；上线日期更新为 2026-03-26；移除所有伪代码替换为实际实现引用 |
| **v3.1** | C.C1 Quota API 验证通过（fb544）；消除 R13；local_file 迁移排行榜 bug 修复记录 |
| **v3.2** | 排行榜防作弊+自动修复（A13）：服务端权威计算 rankScore、登录时自动修复缺失排行、P1 存档校验；消除 R5；排行榜信任模型更新 |
| **v3.3** | **新增阶段 B2：C2S 验证缺口全局修复**。全面审计发现封妖系统客户端时间作弊漏洞（服务端 Handler 已存在但为死代码）；试炼塔日常供奉 C2S 改造已完成（B2.1）；封妖系统改造方案含存档竞态分析和 Quota 兜底策略；新增 R20/R21 风险项 |
| **v3.4** | **新增阶段 B3：丹药计数丢失修复（P0 属性复刻漏洞）**。全面审计 9 种丹药/果实的效果-计数存储架构，确认 7 种存在"效果烙入 player、计数存外部模块"的分桶隐患；属性公式全量推导（等级+境界+丹药三源）；两步修复方案：第一步反推校验热修已损坏存档，第二步计数挪入 player 根治；新增 R22/R23/R24 风险项 |
| **v3.5** | **新增阶段 B4：C/S 架构 + 存档结构综合优化方案**。基于三轮审计（存档结构/C2S 覆盖/序列化覆盖），完成 5 大需求覆盖矩阵：(1)防作弊→B4-S1/S2、(2)存档优化→B4-S3、(3)线上稳定性→B4-S4/S5、(4)不再考虑旧存档→B4-S6、(5)扩展性→B4-S7。7 个子方案 + 三阶段执行计划（P0 紧急→P0 结构→P2 清理）。版本号规划 v10→v11→v12→v13。新增 R30~R34 风险项；修正 A7 版本号偏差（v9→v10）；阶段 F 合并至 B4-S3/S6；6.2d 验证标准索引 |

*关联文档: server-save-migration.md v2.0*
