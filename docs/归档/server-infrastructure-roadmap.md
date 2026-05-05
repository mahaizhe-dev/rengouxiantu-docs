# 服务器基建规划：从存档优化到多人合作

> **项目**：人狗仙途 v2
> **范围**：8 大基建模块的全面设计与执行路径
> **创建日期**：2026-03-29
> **最后更新**：2026-04-09（§4.5 B1~B3 已全部上线：ServerSession + 8 Handler 模块拆分完成，server_main.lua 3478→1430 行，437 项测试全绿）
> **基于**：server-infra-assessment.md v3.5、save-system-design.md v3.1、server-save-migration.md v2.6、代码审计
> **前提**：Phase 2 已上线，**不再考虑旧存档**（v1~v9 无需兼容）

---

## 目录

1. [总览与设计原则](#1-总览与设计原则)
2. [模块一：存档优化与角色仓库](#2-模块一存档优化与角色仓库)
3. [模块二：防作弊与服务器校验](#3-模块二防作弊与服务器校验)
4. [模块三：GM 工具与服务器运营后台](#4-模块三gm-工具与服务器运营后台)
5. [模块四：账号级与角色级数据隔离](#5-模块四账号级与角色级数据隔离)
6. [模块五：弱网与断线重连保护](#6-模块五弱网与断线重连保护)
7. [模块六：有限交易系统与灵韵迁移](#7-模块六有限交易系统与灵韵迁移)
8. [模块七：多职业系统](#8-模块七多职业系统)
9. [模块八：多人合作](#9-模块八多人合作)
10. [跨模块依赖与执行总览](#10-跨模块依赖与执行总览)
11. [serverCloud API 能力速查](#11-servercloud-api-能力速查)
12. [下一步执行路线图](#12-下一步执行路线图2026-04-06-审计后)

---

## 1. 总览与设计原则

### 1.1 当前架构基线

| 维度 | 现状（2026-04-06 审计） |
|------|------|
| 架构 | C/S 同包部署（client_main.lua + server_main.lua 同一 CDN 包） |
| 存档 | serverCloud Score KV，**单键存储**（save_{slot}），4 槽位（v11 三键合并已完成） |
| 版本 | CURRENT_SAVE_VERSION = **v16**，CODE_VERSION = **4**，DISPLAY_VERSION = **v1.7.1** |
| 协议 | **22 C2S + 21 S2C = 43 事件**（SaveProtocol.lua） |
| C2S 覆盖 | 8/13+ 系统有服务端验证（封妖、悟道树、试炼塔、丹药购买、GM命令、兑换码、竞速道印、排行榜） |
| 经济体系 | 灵韵/金币/经验仍为客户端权威（**F 级**），丹药购买已 C2S 校验 |
| 单 key 上限 | 1MB（serverCloud），远超 clientCloud 的 10KB |
| 频率限制 | 300 读/分钟，300 写/分钟 |
| server_main.lua | **1430 行**（B1~B3 拆分后，原 3478 行） |
| 存档模块 | 已拆分为 8 模块（SaveKeys/Loader/Migrations/Persistence/Recovery/Serializer/Slots/State） |

### 1.2 设计原则

| # | 原则 | 说明 |
|---|------|------|
| P1 | **渐进式服务端权威** | 不一次性全部改 C2S，按优先级分批推进 |
| P2 | **原子操作优先** | 涉及多步操作（扣款+发货）用 BatchCommit |
| P3 | **同桶存储** | 效果与计数在同一数据桶，不分散存储（B3 教训） |
| P4 | **软校验先行** | 新校验先记日志 2 周，收集数据后再转硬校验 |
| P5 | **模块化 Handler** | 新功能 = 新 Handler 文件，不膨胀 server_main.lua |
| P6 | **SYSTEM_UID 公共数据** | userId=0 存储全局数据（拍卖行、公告等） |
| P7 | **Quota 管日常** | 所有每日/每周限次用 Quota API，免疫客户端时间篡改 |

### 1.3 serverCloud API 能力矩阵

> 完整表格见 [§11](#11-servercloud-api-能力速查)，此处仅列关键映射。

| 需求 | 推荐 API | 原因 |
|------|---------|------|
| 存档读写 | Score.Get/Set + BatchGet/Set | KV 存储，1MB/key |
| 货币扣款 | **Money.Cost** | 内置余额校验，原子性 |
| 每日限次 | **Quota.Add** (period="day") | 服务器时间，免疫客户端篡改 |
| 拍卖挂单 | **List.Add** (SYSTEM_UID) | 有序列表，list_id 可追踪 |
| 交易/购买 | **BatchCommit** | 跨域原子：Money+List+Quota |
| 邮件/通知 | **Message.Send** | 跨用户消息 |
| 排行榜 | **Ranking** (iscores) | 已实现服务端权威写入 |

---

## 2. 模块一：存档优化与角色仓库

### 2.1 存档结构优化（三键合并）

**现状问题**：

clientCloud 时代 10KB/key 限制导致存档拆成三键（save_data + save_bag1 + save_bag2）。serverCloud 1MB/key 上限下，三键拆分毫无意义，徒增复杂度。

**目标结构**（v11）：

```
每个角色槽位：
  save_{slot}         →  单键，包含全部数据（~6-11KB，远低于 1MB 上限）
  save_backup_{slot}  →  单键备份
```

**合并映射**：

```lua
-- v10（当前，三键）
save_data_{slot}   →  player + skills + quests + shop + challenges + ...
save_bag1_{slot}   →  equipment（精简序列化）
save_bag2_{slot}   →  inventory

-- v11（目标，单键）
save_{slot} = {
    version = 11,
    timestamp = os.time(),
    player = { ... },         -- 含丹药计数（同桶存储）
    equipment = { ... },      -- 全字段序列化（不再精简）
    inventory = { ... },      -- 原 bag1 + bag2 合并
    skills = { ... },
    collection = { ... },
    pet = { ... },
    quests = { ... },
    shop = { ... },           -- 仅保留非丹药字段
    challenges = { ... },     -- 仅保留非丹药计数字段
    sealDemon = { ... },
    trialTower = { ... },
    artifact = { ... },
    fortuneFruits = { ... },
    warehouse = { ... },      -- 🆕 角色仓库（新增）
    bossKills = 0,
    bossKillTimes = { ... },
    bulletin = { ... },
}
```

**收益**：

| 维度 | 三键 | 单键 |
|------|------|------|
| 每槽读取 | BatchGet 3 key | Get 1 key |
| 每槽写入 | BatchSet 3 key | Set 1 key |
| 代码复杂度 | GetBag1Key/GetBag2Key 等 12 个函数 | 无需 |
| 大小余量 | clientCloud 10KB 紧张 | serverCloud 1MB，余量 99%+ |
| 装备序列化 | 精简（fillEquipFields 反查 ~60 行） | 全字段直存 |

**可清理的历史债务**：~925 行（MIGRATIONS v2~v9、fillEquipFields、GetBag1Key/2Key、ExportToLocalFile、MigrateToServer、save_export 逻辑等）

### 2.2 角色仓库系统

**现状**：不存在。背包 BACKPACK_SIZE=50，无仓库存储。城镇地图有"仓库"瓷砖但仅装饰。

**设计方案**：

#### 2.2.1 数据结构

```lua
-- 角色仓库（存在角色存档 save_{slot} 内）
warehouse = {
    items = {
        -- 与背包 inventory 相同的物品格式
        { id = "iron_sword", name = "铁剑", type = "weapon", ... },
        { id = "healing_pill", name = "疗伤丹", type = "consumable", count = 5, ... },
    },
    maxSize = 100,   -- 初始容量
}
```

**容量设计**：

| 仓库类型 | 初始容量 | 扩展方式 | 上限 |
|---------|---------|---------|------|
| 角色仓库 | 100 | 灵韵购买扩展槽 | 500 |
| 账号共享仓库 | 50 | 灵韵购买扩展槽 | 200 |

#### 2.2.2 角色仓库（同存档，简单）

**存储位置**：`save_{slot}.warehouse`（与角色存档同桶）

**操作**：纯客户端操作 + 自动存档同步
- 放入：从 inventory 移到 warehouse
- 取出：从 warehouse 移到 inventory
- 整理：排序、筛选

**为什么不走 C2S**：角色仓库是该角色自己的数据，不涉及跨角色/跨用户操作，存在存档中随自动存档保存即可。防作弊（仓库物品价值校验）由 SaveGame 增强校验覆盖。

#### 2.2.3 账号共享仓库 — ✅ 已被万界商行替代

> **更新（2026-04-11）**：原计划的"账号共享仓库"功能已被**万界商行**（Black Merchant）系统完全替代。
>
> 万界商行是一个基于 SYSTEM_UID + serverCloud.money 的全服商品交易 NPC 系统，实现了比共享仓库更完整的跨账号物品流通：
>
> | 原计划（共享仓库） | 实际实现（万界商行） |
> |------------------|-------------------|
> | 同账号跨角色存取 | **全服跨账号**买卖 |
> | 独立 Score key 存储 | SYSTEM_UID money 域存库存 |
> | C2S 存取协议 | BatchCommit 原子买卖（仙石扣款 + 库存增减） |
> | 无经济循环 | 内置买卖价差回收机制（买入价 > 卖出价） |
>
> **实现文件**：
> - `scripts/config/BlackMerchantConfig.lua` — 16 件商品配置（8 耙碎片 + 8 八卦碎片）
> - `scripts/network/BlackMerchantHandler.lua` — 服务端 HandleBuy/HandleSell/HandleExchange
> - `scripts/ui/BlackMerchantUI.lua` — 客户端 UI（库存/交易/记录/兑换面板）
> - `scripts/network/BlackMerchantTradeLogger.lua` — 交易日志（List API + FIFO 裁剪）
>
> 因此，**§2.2.3 账号共享仓库不再需要实施**。角色仓库（§2.2.2）仍按原计划保留。

### 2.3 执行路径

```
阶段 B4-S3 ──→ v11 迁移：三键合并 + 装备全字段 + 丹药同桶
    │
    ├─ MIGRATIONS[11] 实现
    ├─ 删除 GetBag1Key/GetBag2Key 等冗余函数
    ├─ 删除 fillEquipFields 反查逻辑
    └─ ProcessLoadedData 适配单键读取
    
后续 ──→ 角色仓库
    │
    ├─ warehouse 字段加入 save_{slot} 结构
    ├─ WarehouseUI 交互实现（城镇 NPC 触发）
    └─ 背包 ↔ 仓库 拖拽/按钮操作

~~阶段 E 之后 ──→ 账号共享仓库~~ ✅ 已被万界商行替代（2026-04-11）
    └─ 万界商行（BlackMerchant）已实现全服跨账号商品交易，替代共享仓库需求
```

---

## 3. 模块二：防作弊与服务器校验

### 3.1 现状审计

**C2S 覆盖率**：4/13 系统有服务端验证（30%），9 个系统纯客户端可篡改。

| 分级 | 系统 | 当前状态 | 风险 |
|------|------|---------|------|
| ✅ 已完成 | 悟道树 | C2S + Quota | 安全 |
| ✅ 已完成 | 试炼塔日常供奉 | C2S + Quota | 安全 |
| ✅ 已完成 | 排行榜写入 | 服务端权威计算 | 安全 |
| ✅ 已完成 | 版本握手 | CODE_VERSION 校验 | 安全 |
| ✅ 已完成 | 封妖系统 | C2S 端到端完整（Accept/BossKilled/Abandon） | 安全 |
| ✅ 已完成 | 炼丹/购药 | C2S_BuyPill 服务端校验 + 丹药同桶迁移（v13~v15） | 安全 |
| ✅ 已完成 | GM 命令 | C2S_GMCommand 白名单权限校验 | 安全 |
| ✅ 已完成 | 兑换码 | C2S_RedeemCode + SYSTEM_UID + Quota 防重复 | 安全 |
| ✅ 已完成 | 竞速道印 | C2S_TryUnlockRace 名额限制校验 | 安全 |
| ✅ 已完成 | 属性上界 | V5c maxHp/atk/def 软校验（仅日志） | 监控中 |
| 🟡 P1 | 战斗/经验 | 无 | exp/金币可篡改 |
| 🟡 P1 | 进阶/突破 | 无 | realm 可跳变 |
| 🟡 P1 | 装备锻造/洗练 | 无 | 装备属性可篡改 |
| 🟢 P2 | 宠物系统 | 无 | 宠物等级/技能 |
| 🟢 P2 | 收藏系统 | 无 | 收藏属性加成 |
| 🟢 P2 | 称号系统 | 无 | 称号加成 |
| 🟢 P2 | 技能系统 | 无 | 技能等级 |

### 3.2 防作弊三层体系

#### 第一层：SaveGame 增强校验（被动防线）

在 HandleSaveGame 中，客户端提交存档数据时进行校验。不需要新增 C2S 事件。

| # | 校验项 | 规则 | 处理 | 状态 |
|---|--------|------|------|------|
| V1 | 等级上限 | level ≤ realmCfg.maxLevel | 硬校验：cap 到合法值 | ✅ 已实现 (server_main:855) |
| V2 | 经验值范围 | 0 ≤ exp ≤ nextLvExp×2 | 硬校验：cap | ✅ 已实现 (server_main:870) |
| V3 | 金币非负 | gold ≥ 0 | 硬校验：置 0 | ✅ 已实现 (server_main:890) |
| V4 | 灵韵非负 | lingYun ≥ 0 | 硬校验：置 0 | ✅ 已实现 (server_main:899) |
| V5 | 基础生命上限 | maxHp ≤ expected × 1.5 | **软校验**：记日志 | ✅ 已实现 (server_main:1468 V5c) |
| V6 | 基础攻击上限 | atk ≤ expected × 1.5 | **软校验**：记日志 | ✅ 已实现 (server_main:1468 V5c) |
| V7 | 基础防御上限 | def ≤ expected × 1.5 | **软校验**：记日志 | ✅ 已实现 (server_main:1468 V5c) |
| V8 | 丹药计数上限 | 每种 ≤ maxBuy（含海柱） | 硬校验：cap | ✅ 已实现 (server_main:909) |
| V8b | 海柱等级上限 | 每柱 level 0~10 | 硬校验：cap | ✅ 已实现 (server_main:966) |
| V9 | 境界合法 | realm ∈ REALMS | 硬校验（已有） | ✅ 已实现 |
| V10 | 境界-等级一致 | level ≥ requiredLevel | 硬校验（已有） | ✅ 已实现 |

**属性期望值计算公式**（已完整推导，见 server-infra-assessment.md B3 节）：

```
expectedMaxHp = (100 + (level-1)×15) + Σ境界maxHp + 虎骨丹×30 + 浩气丹×30
expectedAtk   = (15  + (level-1)×3)  + Σ境界atk  + 灵蛇丹×10 + 血煞丹×8
expectedDef   = (5   + (level-1)×2)  + Σ境界def  + 金刚丹×8
```

**策略**：V1~V4/V8~V10 硬校验（明确合法范围，不会误杀）；V5~V7 软校验先行（首阶段记日志+打标记，收集 2 周数据后再决定是否硬校验）。

#### 第二层：C2S 验证（主动防线）

关键操作改为客户端发请求 → 服务端校验+执行 → 返回结果。

**P0 优先接入**：

| 系统 | C2S 事件 | 服务端校验逻辑 | 状态 |
|------|---------|---------------|------|
| 封妖接取 | C2S_SealDemonAccept | Quota 每日限次 + 存档校验 + BOSS 池随机 | ✅ 已完成 |
| 封妖击杀 | C2S_SealDemonBossKilled | 任务状态校验 + 奖励分发 + 体魄丹 cap | ✅ 已完成 |
| 封妖放弃 | C2S_SealDemonAbandon | 任务存在性 + 幂等处理 | ✅ 已完成 |
| 丹药购买 | C2S_BuyPill | 丹药 ID 白名单 + 存档状态校验 | ✅ 已完成 (server_main:2357) |

**P1 后续接入**（阶段 E 模块化后分批推进）：

| 系统 | C2S 事件 | 服务端校验逻辑 |
|------|---------|---------------|
| 战斗结算 | C2S_BattleResult | exp/金币/掉落合理性校验 |
| 进阶突破 | C2S_RealmBreakthrough | 等级/灵韵/材料前置条件校验 |
| 装备强化 | C2S_EquipUpgrade | 材料消耗 + 随机结果服务端生成 |

#### 第三层：BanHandler（惩罚防线）

阶段 E 实现，详见 [模块三 GM 工具](#4-模块三gm-工具与服务器运营后台)。

封禁能力分层：

| 层级 | 能力 | 机制 |
|------|------|------|
| L1 | 连接拦截 | ClientIdentity 阶段检查 banList → Disconnect() |
| L2 | 排行榜剔除 | SaveGame 时跳过 SetInt（不写入排行） |
| L3 | 存档冻结 | 拒绝封禁玩家的保存请求 |
| L4 | 主动踢人 | 向目标 connection 发送断开指令 |

### 3.3 执行路径

```
✅ 已完成 ──→ P0 紧急修复（代码审计确认 2026-03-29）
    │
    ├─ ✅ B2.2~B2.6：封妖系统 C2S 端到端完整（客户端+服务端+协议）
    ├─ ✅ B3 第一步：丹药反推校验热修（ProcessLoadedData 中实现）
    ├─ ✅ B4-S2 V1~V4/V8~V10：SaveGame 硬校验（V1-V5b 全部实现）
    └─ ✅ B4-S4.1：TryRecoverSave 补全（seaPillar* 字段已补丁修复）

✅ 已完成 ──→ P0 结构性修复（2026-04-06 审计确认）
    │
    ├─ ✅ B3 第二步：丹药计数挪入 player（MIGRATIONS[13] 同桶迁移）
    ├─ ✅ MIGRATIONS[14]+[15]：丹药反推 bug 修复（两轮迭代）
    ├─ ✅ S1.2：丹药购买 C2S 事件（HandleBuyPill server_main:2357）
    └─ ✅ V5c：maxHp/atk/def 属性软校验（server_main:1468，仅日志）

阶段 E 之后 ──→ P1 扩展
    │
    ├─ 战斗结算 C2S
    ├─ 进阶突破 C2S
    ├─ 装备强化 C2S
    └─ BanHandler 四层封禁
```

---

## 4. 模块三：GM 工具与服务器运营后台

### 4.1 现状审计

**GM 控制台现状**（`scripts/ui/GMConsole.lua`，~340 行）：

| 维度 | 现状 | 问题 |
|------|------|------|
| 入口 | F1 键，`GameConfig.GM_ENABLED` 门控 | 客户端门控，可绕过 |
| 命令数 | 28 个客户端命令 | 全部本地执行，无服务端校验 |
| 服务端 | 仅 1 个（HandleGMResetDaily）走 C2S | 97% 的 GM 操作可本地篡改 |
| 权限 | 无服务端权限校验 | 任何人修改 GM_ENABLED 即可使用 |
| 审计 | 无操作日志 | 无法追溯谁做了什么 |

**28 个 GM 命令分类**：

| 类别 | 命令数 | 典型命令 | 走 C2S |
|------|--------|---------|--------|
| 资源修改 | 8 | addGold, addLingYun, addExp | ❌ |
| 状态修改 | 6 | setLevel, setRealm, fullHeal | ❌ |
| 系统控制 | 5 | resetDaily, clearQuests | 1/5 |
| 调试工具 | 5 | showStats, dumpSave | ❌ |
| 传送/场景 | 4 | teleport, changeScene | ❌ |

### 4.2 GM 工具升级方案

#### 4.2.1 服务端 GM 权限系统

```lua
-- server_main.lua 或 GMHandler.lua

-- GM 用户白名单（Score key: gm_whitelist，SYSTEM_UID 存储）
local GM_PERMISSIONS = {
    admin  = { "all" },                      -- 全权限
    mod    = { "query", "ban", "mail" },     -- 查询、封禁、发邮件
    viewer = { "query" },                    -- 仅查询
}

function HandleGMCommand(eventType, eventData, connKey)
    local userId = GetUserId(connKey)
    
    -- 1. 权限校验
    local gmLevel = gmWhitelist[userId]
    if not gmLevel then
        SendError(connKey, "无 GM 权限")
        return
    end
    
    -- 2. 权限范围校验
    local command = eventData.command
    if not HasPermission(gmLevel, command) then
        SendError(connKey, "权限不足")
        return
    end
    
    -- 3. 执行命令
    ExecuteGMCommand(command, eventData.params, connKey)
    
    -- 4. 审计日志
    LogGMAudit(userId, command, eventData.params)
end
```

**GM 白名单存储**：

| 方案 | 存储 | 优缺点 |
|------|------|--------|
| A. SYSTEM_UID Score | `Score.Get(0, "gm_whitelist")` | ✅ 动态可更新 ⚠️ 需验证 SYSTEM_UID |
| B. 服务端硬编码 | server_main.lua 中 `GM_UIDS = {...}` | ✅ 简单可靠 ❌ 改名单需发版 |
| C. 混合 | 硬编码 admin + Score 存动态 mod/viewer | ✅ 安全+灵活 |

**推荐方案 C**：admin 硬编码在服务端代码中（最高安全）；mod/viewer 存 SYSTEM_UID Score key（运营灵活）。

#### 4.2.2 服务端 GM 命令体系

| 命令 | 分类 | 权限 | 服务端逻辑 |
|------|------|------|-----------|
| `gm.query` | 查询 | viewer+ | 读取目标玩家存档 → 返回摘要信息 |
| `gm.queryDetail` | 查询 | mod+ | 读取目标玩家完整存档 → 返回全量数据 |
| `gm.ban` | 封禁 | mod+ | 写入 ban_list Score key → 实时踢人 |
| `gm.unban` | 解封 | mod+ | 从 ban_list 移除 |
| `gm.mail` | 邮件 | mod+ | Message.Send → 目标玩家收到补偿邮件 |
| `gm.resetDaily` | 重置 | mod+ | Quota.Reset 目标玩家的 daily keys |
| `gm.addResource` | 资源 | admin | 修改目标存档的 gold/lingYun/exp |
| `gm.setLevel` | 状态 | admin | 修改目标存档的 level/realm |
| `gm.broadcast` | 公告 | admin | SYSTEM_UID Score 写入公告内容 |
| `gm.auditLog` | 审计 | admin | 读取审计 List → 返回操作记录 |

#### 4.2.3 福利邮件系统

**基于 Message API 实现**：

```
发送流程：
  GM/运营 → gm.mail 命令 → HandleGMMail → Message.Send(targetUserId, ...)
  
接收流程：
  玩家登录 → HandleLoadGame → Message.Get(userId, "mail") → S2C 下发邮件列表
  玩家领取 → C2S_ClaimMail → 服务端发放附件 + Message.MarkRead
```

**邮件数据结构**：

```lua
{
    type = "compensation",      -- compensation | reward | system
    title = "维护补偿",
    content = "感谢您的耐心等待",
    attachments = {
        { type = "gold", amount = 1000 },
        { type = "lingYun", amount = 500 },
        { type = "item", id = "healing_pill", count = 10 },
    },
    expireTime = os.time() + 7 * 86400,  -- 7 天过期
}
```

**群发邮件**：遍历 SYSTEM_UID 的 `active_users` List（登录时注册），逐个 Message.Send。受 300 写/分钟限制，大规模群发需分批（每批 ~250 条，间隔 1 分钟）。

#### 4.2.4 GM 审计日志

**存储**：List API（SYSTEM_UID，key="gm_audit"）

```lua
{
    operator = userId,
    command = "gm.ban",
    target = targetUserId,
    params = { reason = "疑似外挂" },
    timestamp = os.time(),
}
```

**查询**：`gm.auditLog` 命令读取最近 N 条审计记录。

### 4.3 执行路径

```
阶段 E（模块化）──→ GMHandler.lua
    │
    ├─ 权限系统（白名单 + 3 级权限）
    ├─ 命令路由（C2S_GMCommand → 分发）
    ├─ 审计日志（List API）
    └─ 查询命令（gm.query / gm.queryDetail）

阶段 E 之后 ──→ 封禁系统
    │
    ├─ BanHandler.lua（L1~L4 四层封禁）
    ├─ ClientIdentity 阶段拦截
    ├─ 客户端 BLACKLIST → 服务端迁移
    └─ 作弊自动检测（存档异常 + 排行异常）

C2 验证通过后 ──→ 福利系统
    │
    ├─ Message API 邮件收发
    ├─ gm.mail 命令
    ├─ 邮件 UI（客户端）
    └─ 群发邮件（分批发送）

C2 验证通过后 ──→ 公告系统
    │
    ├─ SYSTEM_UID Score key 存公告
    ├─ gm.broadcast 命令
    └─ 客户端登录拉取 + 弹窗展示
```

---

## 5. 模块四：账号级与角色级数据隔离

### 5.1 数据分层设计

**核心原则**：角色独有的数据存角色存档（save_{slot}），跨角色共享的数据存账号级 key。

| 层级 | 存储 key | 写入权限 | 数据内容 |
|------|---------|---------|---------|
| **角色级** | `save_{slot}` | 服务端（SaveGame） | 属性、装备、背包、技能、宠物、进度 |
| **角色级（扩展）** | `seal_demon_daily_s{slot}`（Quota） | 服务端 | 每日限次（角色隔离） |
| **账号级** | `account_progress_{userId}` | 服务端 | 成就、神器、账号仓库 |
| **账号级** | `account_warehouse_{userId}` | 服务端 | 共享仓库物品 |
| **账号级** | `slots_index_{userId}` | 服务端 | 槽位索引（已有） |
| **全局** | SYSTEM_UID keys | 服务端 | 公告、拍卖行、兑换码、GM 白名单 |

### 5.2 角色级数据（现有 + 优化）

**已实现**（Phase 2）：

- 存档读写：`save_data_{slot}` / `save_bag1_{slot}` / `save_bag2_{slot}`（v11 合并为 `save_{slot}`）
- 备份：`save_backup_{slot}`（简化后单键备份）
- Quota 角色隔离：`{quotaName}_s{slot}` 后缀（每个角色独立限次）

**Quota 角色隔离机制**（已实现）：

```lua
-- server_main.lua 中 connSlots_ 映射
connSlots_[connKey] = slot  -- HandleLoadGame 时设置

-- 使用时拼接角色后缀
local quotaKey = "seal_demon_daily_s" .. (connSlots_[connKey] or 1)
serverCloud.quota:Add(userId, quotaKey, 1, 1, "day")
```

**为什么 Quota 需要角色隔离**：同一账号的角色 1 和角色 2 各自有独立的每日次数。如果不隔离，角色 1 用完次数后角色 2 也无法使用。

### 5.3 账号级数据（新增）

#### 5.3.1 成就系统（从称号系统升级）

**现状**：称号系统是角色级的，每个角色独立解锁。

**目标**：成就系统升级为账号级，任意角色的进度共享。

**数据结构**：

```lua
-- account_progress_{userId}
{
    achievements = {
        first_blood = { unlocked = true, unlockedAt = 1711234567, unlockedBy = 1 },
        boss_slayer = { unlocked = true, unlockedAt = 1711234568, unlockedBy = 2 },
        realm_master = { unlocked = false, progress = 5, target = 10 },
    },
    achievementPoints = 150,
}
```

**上报逻辑**：

```
角色触发成就条件 → C2S_AchievementUnlock { achievementId }
  → 服务端读取 account_progress
  → 校验是否已解锁
  → 写入解锁记录
  → S2C_AchievementResult
```

#### 5.3.2 神器系统（从角色级提升到账号级）

**现状**：`artifact` 存在角色存档中，每个角色独立。

**目标**：神器解锁账号共享，任意角色可使用已解锁的神器。

**迁移策略**：

```
首次加载时检测：
  if account_progress.artifacts == nil then
    -- 遍历所有角色存档的 artifact 数据
    -- 合并（取并集）→ 写入 account_progress.artifacts
    -- 标记迁移完成
  end
```

**多角色合并冲突处理**：同一神器在多个角色中有不同等级 → 取最高等级。

### 5.4 全局数据（SYSTEM_UID）

| Key | 用途 | 读写频率 |
|-----|------|---------|
| `gm_whitelist` | GM 权限白名单 | 低频读 |
| `ban_list` | 封禁名单 | 登录时读 |
| `announcements` | 全局公告 | 登录时读 |
| `redeem_codes` | 兑换码配置 | 兑换时读 |
| ~~`auction_{category}` (List)~~ | ~~拍卖行挂单~~ | ~~已被万界商行替代~~ |
| `bm_stock_{consumableId}` (Money) | 万界商行商品库存 | 中频读写（SYSTEM_UID=0） |
| `bm_pub_trade` (List) | 万界商行公共交易日志 | 低频写（FIFO 50 条） |
| `gm_audit` (List) | GM 操作日志 | 低频写 |
| `active_users` (List) | 活跃用户列表 | 登录写 |

**✅ SYSTEM_UID (userId=0) 已验证可用**：兑换码系统已使用 `REDEEM_SYSTEM_UID = 0` 存储全局兑换码配置（server_main:3025），Score.Get/Set + Quota 均正常工作。

### 5.5 执行路径

```
✅ 已完成 ──→ C2 验证 SYSTEM_UID 可用性
    │
    └─ ✅ 可用：兑换码系统已验证 userId=0 的 Score/Quota 读写

阶段 G ──→ 账号级数据（依赖 E 模块化）
    │
    ├─ G1：定义 account_progress 数据结构
    ├─ G2：成就系统设计（替代称号）
    ├─ G3：成就 C2S 上报协议
    ├─ G4：神器迁移（角色级 → 账号级）
    ├─ G5：多角色合并逻辑（取并集/最高等级）
    ├─ G6：AccountHandler.lua 实现
    ├─ G7：客户端 UI 适配
    └─ G8：回归测试
    
仓库模块 ──→ 账号共享仓库（独立于 G，可并行）
    │
    └─ account_warehouse Score key + WarehouseHandler
```

---

## 6. 模块五：弱网与断线重连保护

### 6.1 现状审计

**已实现的保护机制**：

| 机制 | 状态 | 位置 |
|------|------|------|
| 15s 客户端超时检测 | ✅ | SaveSystemNet |
| 30s 锁死解锁 + 失败计数 | ✅ | SaveSystemNet |
| 无连接快速失败 | ✅ | SaveSystemNet |
| 存档失败用户提示 | ✅ | SaveSystemNet |
| SafeSend pcall 保护 | ✅ | SaveSystemNet |

**缺失的保护机制**：

| 机制 | 现状 | 影响 |
|------|------|------|
| **自动重连** | ❌ 不存在 | 断线后必须手动重启 |
| **连接状态 UI (W1)** | ✅ 已完成 | SaveSystem.Update 每 5s 轮询连接状态，断线时 main.lua 显示底部红色横幅 |
| **断线暂停存档 + 恢复补存 (W2)** | ✅ 已完成 | SaveSystem._disconnected 标志暂停自动存档，恢复后立即 Save() |
| **操作队列/重试** | ❌ 不做 | 幂等审计成本过高 |
| **心跳保活** | ❌ 待验证 | 需确认引擎是否已内置（阶段 C） |
| **离线缓冲** | ❌ 不做 | 架构级重写 |

### 6.2 弱网保护方案

#### 6.2.1 连接状态管理器

```lua
-- network/ConnectionManager.lua

local ConnectionManager = {
    state = "connected",          -- connected | reconnecting | disconnected
    reconnectAttempts = 0,
    maxReconnectAttempts = 5,
    reconnectDelays = { 2, 4, 8, 15, 30 },  -- 指数退避（秒）
    lastHeartbeat = 0,
    heartbeatInterval = 15,       -- 15 秒心跳
    heartbeatTimeout = 45,        -- 3 次未回复判定断线
    pendingOps = {},              -- 待重发操作队列
}
```

**状态机**：

```
connected ─── 心跳超时/网络错误 ───→ reconnecting
    ↑                                    │
    │                              尝试重连（指数退避）
    │                                    │
    │          ← ─ 重连成功 ─ ─ ─ ─ ─ ─ ┤
    │                                    │
    │                              超过最大重试次数
    │                                    ↓
    └──────── 用户手动重连 ────── disconnected
```

#### 6.2.2 心跳保活

```lua
-- 客户端
function ConnectionManager:SendHeartbeat()
    if os.time() - self.lastHeartbeat >= self.heartbeatInterval then
        SafeSend("C2S_Heartbeat", { clientTime = os.time() })
        self.lastHeartbeat = os.time()
    end
end

function ConnectionManager:CheckHeartbeatTimeout()
    if os.time() - self.lastServerResponse > self.heartbeatTimeout then
        self:OnDisconnect("heartbeat_timeout")
    end
end

-- 服务端
function HandleHeartbeat(eventType, eventData, connKey)
    -- 更新最后活跃时间
    lastActivity[connKey] = os.time()
    -- 回复 pong
    SendToClient(connKey, "S2C_Heartbeat", { serverTime = os.time() })
end
```

#### 6.2.3 自动重连

```lua
function ConnectionManager:AttemptReconnect()
    if self.reconnectAttempts >= self.maxReconnectAttempts then
        self:SetState("disconnected")
        EventBus:emit("NETWORK_DISCONNECTED")
        return
    end
    
    self.reconnectAttempts = self.reconnectAttempts + 1
    local delay = self.reconnectDelays[self.reconnectAttempts] or 30
    
    -- 延迟后重连
    self:ScheduleReconnect(delay)
end

function ConnectionManager:OnReconnectSuccess()
    self:SetState("connected")
    self.reconnectAttempts = 0
    
    -- 重新发送版本握手
    SendVersionHandshake()
    
    -- 重新加载当前角色
    SendLoadGame(currentSlot)
    
    -- 重发队列中的操作
    self:FlushPendingOps()
end
```

#### 6.2.4 连接状态 UI

```lua
-- 连接状态提示条（NanoVG 渲染）

local STATE_DISPLAY = {
    connected     = { color = nil, text = nil },           -- 不显示
    reconnecting  = { color = "#FFA500", text = "重连中..." },  -- 橙色
    disconnected  = { color = "#FF0000", text = "已断开连接" }, -- 红色
}

function DrawConnectionStatus(vg, w, h)
    local state = ConnectionManager.state
    local display = STATE_DISPLAY[state]
    if not display.text then return end
    
    -- 顶部横幅
    nvgBeginPath(vg)
    nvgFillColor(vg, display.color)
    nvgRect(vg, 0, 0, w, 30)
    nvgFill(vg)
    
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, "#FFFFFF")
    nvgText(vg, w/2, 15, display.text)
end
```

#### 6.2.5 操作队列与重发

```lua
-- 断线期间缓冲 C2S 操作
function ConnectionManager:QueueOp(eventName, data)
    if self.state ~= "connected" then
        -- 仅缓冲幂等操作
        if IDEMPOTENT_OPS[eventName] then
            table.insert(self.pendingOps, { event = eventName, data = data })
            return true  -- 已队列化
        else
            return false  -- 不可缓冲（如存档，需要最新数据）
        end
    end
    return nil  -- 正常发送
end

-- 可安全重发的操作
local IDEMPOTENT_OPS = {
    C2S_SealDemonAccept = true,      -- Quota 保护幂等
    C2S_DaoTreeStart = true,         -- Quota 保护幂等
    C2S_TrialClaimDaily = true,      -- Quota 保护幂等
    -- C2S_SaveGame = false,         -- 不缓冲：需要最新存档数据
    -- C2S_BuyPill = false,          -- 不缓冲：金币可能已变化
}
```

#### 6.2.6 存档保护增强

**断线期间存档策略**：

| 场景 | 处理 |
|------|------|
| 正常连接 | 自动存档每 120s |
| 重连中 | **暂停自动存档**，本地缓存变化 |
| 重连成功 | **立即触发一次存档** |
| 彻底断线 | 本地 fallback 存档（仅用于恢复） |

**本地 fallback 存档**（安全网）：

```lua
-- 断线后写入本地 fallback（不替代云存档，仅用于极端情况恢复）
function ConnectionManager:SaveLocalFallback()
    if self.state == "disconnected" then
        local data = SaveSystem.SerializeAll()
        data._fallback = true
        data._fallbackTime = os.time()
        local f = File:new("fallback_save.json", FILE_WRITE)
        f:WriteString(cjson.encode(data))
        f:Close()
    end
end
```

### 6.3 C/S 架构约束

**重要约束**：UrhoX C/S 同包架构下，"重连"本质上是引擎层的网络重连，不是应用层的 HTTP 重连。需要确认引擎是否支持：

| 能力 | 需要验证 |
|------|---------|
| 连接断开后能否重新 Connect | 需验证 |
| 重连后 ClientIdentity 是否重新触发 | 需验证 |
| 重连后 Scene 是否需要重新同步 | 需验证 |
| connection.roundTripTime 监控 | ✅ 引擎内置 |

**验证方案**：在阶段 C 中新增 C7 网络重连验证项。

### 6.4 执行路径

```
✅ 已完成 ──→ W1 + W2（代码审计确认 2026-03-30）
    │
    ├─ ✅ W1：连接状态 UI（SaveSystem.Update 每5s轮询 + main.lua 底部红色横幅）
    ├─ ✅ W2：断线暂停存档（SaveSystem._disconnected 标志 + Save() 入口跳过）
    └─ ✅ W2：恢复后立即补存（connection_restored → SaveSystem.Save()）

阶段 C ──→ C7 网络重连能力验证
    │
    ├─ 断开后 ReConnect 可行性
    ├─ ClientIdentity 重触发确认
    └─ Scene 重同步确认

验证通过后 ──→ ConnectionManager 扩展（W3/W4）
    │
    ├─ W3：心跳保活（C2S/S2C_Heartbeat，需双端同步上线）
    ├─ W4：自动重连（状态机 + 指数退避，依赖 C7 验证结果）
    └─ 本地 fallback 安全网（远期）
```

---

## 7. 模块六：有限交易系统与灵韵迁移（交易部分已被万界商行替代）

> **更新（2026-04-11）**：本模块的**交易系统**部分（§7.3 拍卖行、系统回收、搜索）已被**万界商行**（Black Merchant）系统完全替代。万界商行基于 SYSTEM_UID + serverCloud.money + BatchCommit 实现了全服商品原子买卖，内置价差回收机制，比原计划的拍卖行更简洁实用。
>
> **灵韵迁移**部分（§7.1~§7.2）仍然有效且独立需要——灵韵从存档 player.lingYun 迁移到 Money API 是经济系统安全化的基础，不受黑市影响。
>
> **万界商行已实现的能力**（对比原计划拍卖行）：
>
> | 维度 | 原计划拍卖行 | 万界商行（已实现） |
> |------|------------|------------------|
> | 交易模式 | 玩家挂单 → 玩家购买 | NPC 系统库存 → 玩家买卖 |
> | 原子性 | BatchCommit | ✅ BatchCommit（MoneyCost + MoneyAdd 原子提交） |
> | 经济回收 | 5% 税收 | ✅ 买卖价差（买入价 > 卖出价，自然回收） |
> | 交易日志 | 无 | ✅ List API 公共日志 + 个人日志（FIFO 50 条） |
> | 碎片兑换 | 无 | ✅ 8 碎片 → 1 完整物品 |
> | 存储 | List API (SYSTEM_UID) 挂单 | SYSTEM_UID money 域存库存 |
> | 搜索 | 按类别分 key + 服务端缓存 | 16 件固定商品，客户端分 Tab 浏览 |

### 7.1 灵韵系统现状

**灵韵（LingYun）经济审计**：

| 维度 | 现状 | 问题 |
|------|------|------|
| 存储 | `player.lingYun`（整数，存档内） | 客户端可直接篡改 |
| 获取 | 10+ 来源（BOSS 掉落、封妖、试炼塔、卖装备等） | 全部客户端直接加 |
| 消费 | 10+ 去处（进阶、炼丹、宠物、装备商店、神器等） | 全部客户端直接减 |
| 校验 | **无** | `player.lingYun = player.lingYun - cost` 无余额检查 |
| 原子性 | **无** | 扣款和发货不是原子操作 |

**关键代码路径**（Player.lua:780）：

```lua
function Player:GainLingYun(amount)
    self.lingYun = self.lingYun + amount  -- 直接加，无上限校验
    EventBus:emit("LINGYUN_CHANGED", self.lingYun)
end
```

**消费端（典型，AlchemyUI）**：

```lua
if player.lingYun >= cost then
    player.lingYun = player.lingYun - cost  -- 直接减，无原子保护
    -- 发放丹药...
end
```

### 7.2 灵韵迁移到 Money API

**目标**：将灵韵从存档 `player.lingYun` 迁移到 serverCloud Money 域，获得原子扣款和余额校验。

#### 7.2.1 Money API 优势

| 维度 | Score (当前) | Money (目标) |
|------|-------------|-------------|
| 扣款 | 客户端直接修改 | **Money.Cost 原子扣款** |
| 余额校验 | 客户端 `if >= cost` | **服务端内置，不可透支** |
| 并发安全 | 无 | **原子操作** |
| 交易支持 | 不可能 | **BatchCommit 跨域原子** |
| 审计 | 无 | 可配合 List 记录流水 |

#### 7.2.2 迁移方案

**阶段 D.1：双写期**（金额写入 Money + 存档 player.lingYun）

```
所有灵韵变动 → C2S_LingYunChange { type="earn"|"spend", amount, source }
  → 服务端 HandleLingYunChange:
    1. earn:  Money.Add(userId, "lingYun", amount)
    2. spend: Money.Cost(userId, "lingYun", amount) → 失败返回余额不足
    3. 同步写入 save_{slot}.player.lingYun（双写兼容）
    4. S2C_LingYunResult { ok, balance }
```

**阶段 D.2：切换读取源**

```
客户端显示灵韵余额：
  旧：读 player.lingYun
  新：Money.Get(userId, "lingYun") 服务端下发

登录时余额同步：
  HandleLoadGame → Money.Get → 下发给客户端
```

**阶段 D.3：废弃 Score 域读取**

```
player.lingYun 保留但不再作为真值
Money.Get 为唯一数据源
```

#### 7.2.3 首次迁移（存量灵韵）

```lua
-- HandleLoadGame 中检测
function MigrateLingYunToMoney(userId, saveData)
    local moneyBalance = serverCloud.money:Get(userId, "lingYun")
    if moneyBalance == 0 and saveData.player.lingYun > 0 then
        -- 首次迁移：存档灵韵 → Money
        serverCloud.money:Add(userId, "lingYun", saveData.player.lingYun)
        print("[Server] LingYun migrated: " .. saveData.player.lingYun)
    end
end
```

### 7.3 ~~有限交易系统~~ ✅ 已被万界商行替代

> **此节原计划的拍卖行、系统回收、搜索功能已被万界商行（BlackMerchant）系统替代。以下为历史设计记录，不再实施。**

~~**设计约束**~~：
- ~~**有限**：不是自由交易市场，只允许特定类型物品交易~~
- ~~**回收**：系统回收机制防止通货膨胀~~
- ~~**原子**：买卖操作原子完成，不可出现钱扣了货没到~~

#### 7.3.1 可交易物品

| 物品类型 | 可交易 | 回收价 | 说明 |
|---------|--------|--------|------|
| 装备（蓝色+） | ✅ | 基础价 × 品质系数 | 灵韵回收 |
| 材料 | ✅ | 固定价格表 | 灵韵回收 |
| 丹药（成品） | ❌ | — | 防止经济崩溃 |
| 宠物 | ❌ | — | 暂不开放 |

#### 7.3.2 拍卖行架构

**数据存储**：List API（SYSTEM_UID）

```lua
-- 挂单结构（List item）
{
    list_id = "auto_generated",      -- List API 自动生成
    seller = userId,
    sellerName = "玩家A",
    itemData = { id = "iron_sword", name = "铁剑", ... },
    price = 500,                     -- 灵韵标价
    listTime = os.time(),
    expireTime = os.time() + 48 * 3600,  -- 48 小时过期
    category = "weapon",
}
```

**上架**：

```
C2S_AuctionList → { itemIndex, price }
  → HandleAuctionList:
    1. 从 save_{slot} 读取 inventory[itemIndex] → 校验物品存在且可交易
    2. Quota 检查每日上架次数（限 10 次/天）
    3. BatchCommit:
       - 从 inventory 移除物品（Score.Set save_{slot}）
       - 添加挂单到拍卖行（List.Add SYSTEM_UID "auction_{category}"）
       - Quota 计数（Quota.Add）
    4. S2C_AuctionResult { ok }
```

**购买**：

```
C2S_AuctionBuy → { listId }
  → HandleAuctionBuy:
    1. List.GetById(SYSTEM_UID, "auction_{category}", listId) → 校验挂单存在
    2. Money.Get(buyerId, "lingYun") → 校验余额
    3. BatchCommit:
       - Money.Cost(buyerId, "lingYun", price)           -- 买家扣款
       - Money.Add(sellerId, "lingYun", price × 0.95)    -- 卖家到账（5% 税收回收）
       - List.Delete(SYSTEM_UID, listId)                  -- 移除挂单
       - 将物品写入买家 save_{slot}.inventory（Score.Set）
    4. Message.Send(sellerId, "trade_notification", { ... })  -- 通知卖家
    5. S2C_AuctionBuyResult { ok, item }
```

**5% 税收回收**：每笔交易扣除 5% 灵韵作为系统回收，控制灵韵通胀。

#### 7.3.3 系统回收站

**NPC 回收**：玩家向 NPC 出售物品，获得固定灵韵。

```
C2S_RecycleItem → { itemIndex }
  → HandleRecycleItem:
    1. 读取物品 → 查回收价格表
    2. Money.Add(userId, "lingYun", recyclePrice)
    3. 从 inventory 移除物品
    4. S2C_RecycleResult { ok, gained }
```

**过期挂单处理**：服务端定期扫描（HandleUpdate 中每 5 分钟检查一次），过期挂单自动返回卖家邮箱（Message.Send）。

#### 7.3.4 拍卖行搜索

**约束**：List API 无条件查询（D5），只能按 userId+key 全量返回。

**解决方案**：按物品类别分 key 存储 + 服务端内存缓存

```lua
-- 分类 key
auction_weapon     -- 武器类
auction_armor      -- 防具类
auction_material   -- 材料类

-- 服务端缓存
local auctionCache = {}  -- { category: { items } }
local cacheExpiry = 60   -- 60 秒缓存过期

function GetAuctionList(category)
    if auctionCache[category] and os.time() - auctionCache[category].time < cacheExpiry then
        return auctionCache[category].items
    end
    local items = serverCloud.list:Get(SYSTEM_UID, "auction_" .. category)
    auctionCache[category] = { items = items, time = os.time() }
    return items
end
```

**客户端筛选**：服务端下发类别全量数据后，客户端本地做名称搜索、价格排序等轻量筛选。

### 7.4 执行路径

```
阶段 C.C4 ──→ 验证 Money.Cost 余额校验 ✅（2026-04-09，8/8 通过）
阶段 C.C5 ──→ 验证 BatchCommit 原子回滚 ✅（2026-04-09，9/9 通过）

C4 通过 ✅ ──→ 阶段 D：灵韵迁移【可立即启动】
    │
    ├─ D1：Money.Add 存量灵韵迁移
    ├─ D2：C2S_LingYunChange 双写协议
    ├─ D3：所有灵韵获取/消费改走 C2S
    ├─ D4：客户端余额从 Money.Get 读取
    └─ D5：废弃 player.lingYun 作为真值

~~交易系统~~ ✅ 已被万界商行替代（2026-04-11）
    └─ BlackMerchantHandler.lua 已实现：
       ├─ 买卖（BatchCommit: MoneyCost + MoneyAdd 原子操作）
       ├─ 碎片兑换（8→1 合成）
       ├─ 交易日志（List API，公共+个人双日志，FIFO 50 条）
       ├─ 价差回收（买入价 > 卖出价，自然沉淀仙石）
       └─ 完整 UI（库存/交易/记录/兑换四面板）
```

---

## 8. 模块七：多职业系统

### 8.1 现状审计

**当前实现**（`GameConfig.lua` L180-193）：

```lua
GameConfig.CLASS_DATA = {
    monk = {
        name = "武僧",
        icon = "🥊",
        passive = {
            name = "金刚铁骨",
            desc = "重击率+10%，每级+1根骨",
            heavyHitChance = 0.10,
            constitutionPerLevel = 1,
        },
    },
}
GameConfig.PLAYER_CLASS = "monk"  -- 硬编码
```

**关键发现**：
- `classId` **不存档** — 始终从 `GameConfig.PLAYER_CLASS` 读取
- CONFIG 结构已支持扩展（CLASS_DATA 是 table，可加新 key）
- 被动技能机制已有（heavyHitChance、constitutionPerLevel）
- 注释明确写了"当前仅武僧，未来可扩展"

### 8.2 多职业设计

#### 8.2.1 职业配置扩展

```lua
GameConfig.CLASS_DATA = {
    monk = {
        name = "武僧",
        icon = "🥊",
        passive = {
            name = "金刚铁骨",
            desc = "重击率+10%，每级+1根骨",
            heavyHitChance = 0.10,
            constitutionPerLevel = 1,
        },
        baseStats = { hp = 100, atk = 15, def = 5 },
        growthStats = { hp = 15, atk = 3, def = 2 },  -- 每级成长
    },
    swordsman = {
        name = "剑修",
        icon = "⚔️",
        passive = {
            name = "剑意锋芒",
            desc = "暴击率+15%，每级+2攻击",
            critChance = 0.15,
            atkPerLevel = 2,
        },
        baseStats = { hp = 80, atk = 20, def = 3 },
        growthStats = { hp = 12, atk = 4, def = 1.5 },
    },
    healer = {
        name = "药师",
        icon = "🧪",
        passive = {
            name = "妙手回春",
            desc = "回复效果+25%，每级+3生命",
            healBonus = 0.25,
            hpPerLevel = 3,
        },
        baseStats = { hp = 120, atk = 10, def = 4 },
        growthStats = { hp = 18, atk = 2, def = 1.5 },
    },
}
```

#### 8.2.2 存档支持

**classId 写入 player 存档**：

```lua
-- 序列化（新增字段）
player.classId = "monk"  -- 存档中记录职业

-- 反序列化兼容
if not player.classId then
    player.classId = "monk"  -- 旧存档默认武僧
end
```

**属性公式适配**：

```lua
function ComputeBaseStats(player)
    local classCfg = GameConfig.CLASS_DATA[player.classId]
    return {
        maxHp = classCfg.baseStats.hp + (player.level - 1) * classCfg.growthStats.hp,
        atk   = classCfg.baseStats.atk + (player.level - 1) * classCfg.growthStats.atk,
        def   = classCfg.baseStats.def + (player.level - 1) * classCfg.growthStats.def,
    }
end
```

**对 SaveGame 校验的影响**：V5~V7 属性校验公式需要根据 classId 查对应的 base/growth，不能硬编码武僧公式。

#### 8.2.3 职业选择时机

| 方案 | 时机 | 优缺点 |
|------|------|--------|
| A. 创建角色时选择 | CreateChar 流程 | ✅ 最直观 ❌ 无法体验后再选 |
| B. 新手教程后选择 | 完成教程触发选择 UI | ✅ 有基础了解 |
| C. 首次进阶时选择 | 筑基境界时触发 | ✅ 有深入体验 ❌ 前期全是武僧 |

**推荐方案 A**：创建角色时选择职业。UI 上展示三个职业的属性和被动对比。

**C2S 协议**（新增字段）：

```
C2S_CreateChar → { slot, name, classId }   -- 新增 classId
HandleCreateChar:
  1. 校验 classId ∈ CLASS_DATA
  2. 初始化角色属性（根据 classId 的 baseStats）
  3. 写入存档 player.classId
```

#### 8.2.4 转职系统（可选，后期）

如果需要允许玩家切换职业：

```
C2S_ClassChange → { newClassId }
HandleClassChange:
  1. 校验 newClassId 合法
  2. 校验转职条件（消耗灵韵？限次？）
  3. 重算基础属性（新职业 base+growth）
  4. 保留丹药加成 + 装备
  5. 写入新 classId
  6. S2C_ClassChangeResult
```

**注意**：转职需要重算属性，丹药加成和装备加成保持不变，只改基础和成长。

### 8.3 执行路径

```
准备阶段 ──→ classId 存档化
    │
    ├─ player.classId 字段加入序列化
    ├─ 旧存档默认 "monk"
    └─ 属性公式适配（按 classId 查 CLASS_DATA）

职业扩展 ──→ 新职业配置
    │
    ├─ CLASS_DATA 新增职业（剑修、药师等）
    ├─ 被动技能实现
    ├─ 每级成长差异化
    └─ 服务端 SaveGame 校验适配（公式按 classId 分支）

UI 阶段 ──→ 职业选择
    │
    ├─ CreateChar UI 增加职业选择界面
    ├─ C2S_CreateChar 新增 classId 参数
    ├─ 职业介绍面板（属性对比、被动说明）
    └─ 角色列表显示职业图标

后期（可选）──→ 转职系统
    │
    ├─ 转职 NPC / UI
    ├─ C2S_ClassChange 协议
    ├─ 属性重算逻辑
    └─ 转职次数限制（Quota）
```

---

## 9. 模块八：多人合作

### 9.1 现状评估

**当前 C/S 用途**：纯存档中继。服务端只负责存档读写和排行榜，不参与任何游戏逻辑。

**引擎多人能力**：

| 能力 | 状态 | 说明 |
|------|------|------|
| SendRemoteEvent | ✅ | C2S/S2C 通信已验证 |
| 多连接 | ✅ | max_players=2（可调），connSlots_ 管理 |
| Scene 同步 | ⚠️ 需验证 | 引擎可能支持 Replicated Scene |
| 匹配系统 | ✅ | free_match_with_ai 已配置 |
| 实时同步 | ❌ 不存在 | 完全没有 |

**关键约束**：
- 同包架构下所有代码在同一 CDN 包，客户端和服务端共享代码
- 服务端运行在引擎进程内，支持 HandleUpdate 轮询
- 当前 server_main.lua ~500 行，已较膨胀

### 9.2 多人合作模式设计

#### 9.2.1 协作模式选择

| 模式 | 同步需求 | 复杂度 | 适合场景 |
|------|---------|--------|---------|
| **A. 异步合作** | 低 | 低 | 赠送/帮助/留言 |
| **B. 回合制合作** | 中 | 中 | BOSS 战、组队副本 |
| **C. 实时合作** | 高 | 高 | 同屏战斗、同步移动 |

**推荐路线**：A → B → C 渐进式推进。

#### 9.2.2 模式 A：异步合作（最简）

无需实时同步，基于 Message API 实现。

**功能清单**：

| 功能 | 实现 | API |
|------|------|-----|
| 好友赠礼 | 送灵韵/物品 → Message.Send | Money.Cost + Message.Send |
| 好友助力 | 每日助力 → Quota 限次 | Quota.Add + Message.Send |
| 留言板 | List.Add (SYSTEM_UID "messages") | List API |

**执行简单，可独立于其他模块先行开发。**

#### 9.2.3 模式 B：回合制合作（推荐目标）

**适用场景**：组队挑战 BOSS、多人副本。

**架构设计**：

```
匹配阶段：
  玩家 A 创建房间 → C2S_CreateRoom { bossId, maxPlayers }
  服务端 → 创建 room 对象 → 等待匹配
  玩家 B 加入 → C2S_JoinRoom { roomId }
  服务端 → 房间满员 → S2C_RoomReady → 全员进入战斗

战斗阶段（回合制）：
  每回合：
    服务端广播 S2C_TurnStart { currentPlayer, bossHp, playerStates }
    当前玩家 → C2S_PlayerAction { action = "attack" | "skill" | "defend" }
    服务端计算结果 → S2C_TurnResult { damage, effects, bossHp }
    
  战斗结束：
    服务端判定胜负 → S2C_BattleEnd { result, rewards }
    奖励分配 → 各玩家存档写入
```

**服务端状态管理**：

```lua
-- network/handlers/CoopHandler.lua

local rooms = {}   -- roomId → room 对象

local Room = {
    id = "",
    bossId = "",
    players = {},     -- { connKey, userId, slot, ready }
    state = "waiting", -- waiting | fighting | finished
    turn = 0,
    bossHp = 0,
}

function HandleUpdate(dt)
    for id, room in pairs(rooms) do
        if room.state == "fighting" then
            -- 回合超时检测（30s 未操作自动防御）
            if os.time() - room.turnStartTime > 30 then
                AutoDefend(room)
            end
        elseif room.state == "waiting" then
            -- 等待超时（60s 无人加入自动解散）
            if os.time() - room.createTime > 60 then
                DisbandRoom(room)
            end
        end
    end
end
```

**奖励分配**：

```lua
function DistributeRewards(room, bossConfig)
    for _, player in ipairs(room.players) do
        -- 每个参与者独立奖励（不分摊）
        local rewards = GenerateRewards(bossConfig, player.level)
        -- 写入各自存档
        local saveData = serverCloud:Get(player.userId, "save_" .. player.slot)
        ApplyRewards(saveData, rewards)
        serverCloud:Set(player.userId, "save_" .. player.slot, saveData)
        -- 通知各客户端
        SendToClient(player.connKey, "S2C_CoopReward", { rewards = rewards })
    end
end
```

#### 9.2.4 模式 C：实时合作（远期）

需要较大的架构扩展，包括：
- **实体同步**：位置/动画/状态的帧级同步
- **预测与回滚**：客户端预测 + 服务端权威 + 差异回滚
- **带宽控制**：区分高频数据（位置 20fps）和低频数据（属性 1fps）

**本文不展开设计**，建议在模式 B 稳定运行后再评估必要性。

### 9.3 匹配系统设计

**利用引擎内置匹配**：

```json
// .project/settings.json
{
    "@runtime": {
        "multiplayer": {
            "enabled": true,
            "max_players": 4,       // 从 2 提升到 4（支持 4 人组队）
            "match_info": {
                "desc_name": "free_match_with_ai",
                "player_number": 2,  // 2 人即可开始
                "match_timeout": 30
            }
        }
    }
}
```

**自定义匹配（回合制场景）**：

```
玩家选择 BOSS → 发送匹配请求
  → 服务端检查是否有等待中的同 BOSS 房间
  → 有 → 加入房间
  → 无 → 创建新房间 → 等待

房间满员或超时 → 开始战斗
  → 超时未满员 → 2 人也可开始（降低人数门槛）
```

### 9.4 执行路径

```
独立验证 ──→ 多人通信验证
    │
    ├─ max_players 提升到 4
    ├─ 多连接同时收发 RemoteEvent 验证
    └─ 服务端状态管理（rooms）可行性

模式 A ──→ 异步合作（最简，可先行）
    │
    ├─ 好友赠礼（Message + Money）
    ├─ 每日助力（Quota + Message）
    └─ 留言板（List）

模式 B ──→ 回合制合作（目标）
    │
    ├─ 房间系统（创建/加入/解散）
    ├─ 匹配逻辑（引擎匹配 or 自定义）
    ├─ 回合制战斗服务端逻辑
    ├─ 奖励分配
    ├─ CoopHandler.lua
    └─ 组队 UI（房间列表/队伍面板/战斗同步）

模式 C ──→ 实时合作（远期评估）
    │
    └─ 模式 B 稳定后再评估必要性
```

---

## 10. 跨模块依赖与执行总览

### 10.1 模块依赖图（审计更新 2026-04-06）

```
用户 8 项需求 → 执行期映射

  需求 1 基础防作弊 ──┐
  需求 5 GM 指令保护 ──┼──→ ✅【第三期：安全基线】已完成（v13~v15, GM+丹药+校验）
                      │
                      ↓
              ┌──────────────────────────┐
              │ 【第四期：API 验证+模块化】│
              │  ✅C2:SYSTEM_UID(已验证)   │
              │  C4:Money  C5:BatchCommit │
              │  C6:Message              │
              │  + 阶段 E 服务端拆分       │
              └──┬────┬────┬────┬────────┘
                 │    │    │    │
       ┌─────────┘    │    │    └──────────────┐
       ↓              ↓    ↓                   ↓
  ┌──────────────┐  ┌──────────────┐         ┌──────────┐
  │【第五期】🔶   │  │  【第六期】   │         │【第八期】 │
  │5.1~5.3+5.5 ✅│  │ 经济系统     │         │ 多人玩法  │
  │5.4/5.6 待做  │  │ 需求 6       │         │ 需求 8   │
  │(C6待验证)    │  │(C2✅+C4+C5+E)│         │(独立验证) │
  └──────────────┘  └──────────────┘         └──────────┘

  需求 3 弱网断线恢复 ──→ ✅ 已完成（第二期 W1+W2）
  需求 7 多职业 ──→ ✅【第七期】已上线（7.1~7.5 全部完成：classId v16 + 双职业 + 8技能 + 选角UI）

  C7 引擎级自动重连 ──→ ❌ 不可行（引擎无 ServerDisconnected 事件）

  ★ 路线图外已完成 ──→ 酒系统 ✅、仓库 bug 修复 ✅、装备首获道印 ✅
  ★ 万界商行 ✅ ──→ 替代§7.3拍卖行 + §2.2.3共享仓库 + §6.4/6.5（2026-04-11）
```

### 10.2 执行分期

#### 第一期：紧急修复（v10 热修）— ✅ 已完成

> **审计结论（2026-03-29）**：代码审计确认第一期 4 项任务均已在之前的迭代中实现。B4-S4.1 有 seaPillar* 字段缺失的小补丁已修复。

| 任务 | 模块 | 阶段 | 状态 | 审计备注 |
|------|------|------|------|---------|
| B3 第一步：丹药反推校验 | 二 | B3 | ✅ 已完成 | SaveSystem:2145 ProcessLoadedData 中实现 |
| B2.2~B2.6：封妖 C2S 接入 | 二 | B2 | ✅ 已完成 | SealDemonSystem 4 函数均发 C2S，3 个 Server Handler 完整 |
| B4-S2 V1~V4/V8~V10：SaveGame 硬校验 | 二 | B4 | ✅ 已完成 | server_main:849 V1-V5b 全部 clamp，含海柱等级校验 |
| B4-S4.1：TryRecoverSave 补全 | 一 | B4 | ✅ 已完成 | rebuildData seaPillar*/code_version/bossKills 补丁已合入 |

#### 第二期：存档全方位优化（v10 → v11）— 当前阶段

> **范围重新定义（2026-03-30）**：第二期聚焦存档系统全方位优化，防作弊/校验延后到第三期。
> **详细评估报告**：`docs/save-system-evaluation.md`（含两轮评估）
> 自测脚本：`scripts/tests/phase2_self_test.lua`（14 项测试）。

**核心目标**：先保障线上存档安全（P0），再降低代码复杂度（P1-P4）。

| 步骤 | # | 任务 | 类型 | 改动量 | 风险 | 状态 |
|------|---|------|------|--------|------|------|
| **①** | P0-1 | 自动存档频率 120s→60s | 保护 | 1 行 | 🟢 极低 | ✅ 已完成 |
| **①** | P0-2 | 修复 `save_request` 事件监听 | Bug 修复 | 5 行 | 🟢 极低 | ✅ 已完成 |
| **①** | P0-3 | 添加 12 个关键操作即时存档 | 保护 | 12 行 | 🟢 低 | ✅ 已完成 |
| **②** | S4 | 加固 B3 丹药反推逻辑 | 优化 | 小 | 🟢 低 | ✅ 已完成 |
| **③** | S3 | 删除已死兼容代码 | 清理 | -240 行 | 🟢 低 | ✅ 已完成 |
| **③** | S5 | 序列化统一（Full 模式） | 优化 | -125 行 | 🟡 中 | ✅ 已完成 |
| **④** | S1 | 三键合并为单键 | 核心 | v11 迁移 | 🟡 中 | ✅ 已完成 |
| **④** | S6 | 备份层级简化 | 优化 | 重构 | 🟢 低 | ✅ 已完成 |
| **④** | S7 | ExportToLocalFile 降频 | 优化 | 小 | 🟢 低 | ✅ 已完成 |
| **⑤** | S2 | 文件拆分（消除上帝文件） | 重构 | 重组织 | 🟡 中 | ✅ 已完成 |

**执行顺序**：

```
✅ 步骤① P0 存档安全保护（~18 行）
  ├─ ✅ P0-1  AUTO_SAVE_INTERVAL 120→60
  ├─ ✅ P0-2  SaveSystem.Init() 监听 save_request 事件
  └─ ✅ P0-3  12 处关键操作添加 EventBus.Emit("save_request")
        ↓
✅ 步骤② P1 加固丹药反推（S4 硬编码常量→配置引用）
        ↓
✅ 步骤③ P2 删除死代码 + 序列化统一（S3 + S5）
        ↓
✅ 步骤④ P3 三键合并 + 备份简化 + 降频（S1 → S6 → S7）
  ├─ ✅ S1  三键合并（v10→v11 迁移，线上验证通过）
  ├─ ✅ S6  备份层级简化
  └─ ✅ S7  ExportToLocalFile 降频
        ↓
✅ 步骤⑤ P4 文件拆分（S2 — 3096 行→ 8+1 模块，含构建修复）
```

**第二期全部完成 ✅**（2026-03-31）

**预期成果**：
- 🔴 **P0 即时收益**：资源丢失窗口 120s→60s + 12 类关键操作即时存档 + 海神柱 bug 修复
- SaveSystem.lua：3188 行 → 拆分后最大 ~500 行（-84%）
- 备份 keys/slot：13 → 5（-62%）
- 序列化路径：2 → 1（-50%）
- 添加新子系统修改点：7 处 → 3 处（-57%）
- Key 名函数：15 → 1 通用函数（-93%）

#### 第三期：安全基线（需求 1+5 合并）— ✅ 已完成

> **重新评估（2026-03-31）**：基于用户 8 项需求优先级重排。需求 1（基础防作弊）和需求 5（GM 指令保护）合并为安全基线，作为最高优先级。
> 需求 3（弱网断线恢复）已在第二期 W1+W2 中完成，无需再排期。
> **审计结论（2026-04-06）**：代码审计确认第三期 5 项任务均已实现。丹药系统经历 3 轮迁移（v13~v15），GM 白名单和 C2S 化均已上线。

**目标**：堵住最危险的安全漏洞，建立最小可用的服务端安全体系。

| # | 任务 | 具体内容 | 风险 | 工作量 | 状态 | 审计备注 |
|---|------|---------|------|--------|------|---------|
| 3.1 | **GM 白名单** | server_main 硬编码 admin userId 列表；HandleGMResetDaily 加权限校验；客户端 GM_ENABLED 改为从服务端下发 | 🟢 低 | 小 | ✅ 已完成 | GM_ADMIN_UIDS + IsGMAdmin()，server_main:39-50 |
| 3.2 | **危险 GM 命令 C2S 化** | addGold/addLingYun/addExp/setLevel/setRealm 5 条高危命令改走 C2S → 服务端白名单校验后执行 → 写入审计日志 | 🟢 低 | 中 | ✅ 已完成 | HandleGMCommand，server_main:2398，服务端鉴权后客户端执行 |
| 3.3 | **V5~V7 属性软校验** | maxHp/atk/def 上界校验（`expected × 1.5`），首阶段仅记日志+打标记，不硬拒绝。公式需按 classId 分支（为多职业预留） | 🟢 低 | 中 | ✅ 已完成 | V5c 软校验，server_main:1468，含 classId 分支 |
| 3.4 | **B3 丹药同桶迁移** | MIGRATIONS[13]：丹药计数从 shop/challenges 挪入 player，根治属性复刻 bug。当前版本 v12，此为 v12→v13 迁移 | 🟡 中 | 中 | ✅ 已完成 | MIGRATIONS[13]+[14]+[15]，经历 3 轮修复（同桶→bugfix→bugfix v2） |
| 3.5 | **丹药购买 C2S** | C2S_BuyPill 事件：服务端校验余额+计数上限+原子扣款+发放（依赖 3.4 同桶完成） | 🟡 中 | 中 | ✅ 已完成 | HandleBuyPill，server_main:2357，白名单：tiger/snake/diamond/tempering |

**第三期全部完成 ✅**（2026-04-06 审计确认）

**关于 bossKills cap**：已从此期移除。单纯加 cap 无实际意义——客户端仍可提交 cap-1 的伪造值。真正的修复是服务端权威的击杀计数（C2S_BossKill），但这需要战斗结算 C2S 化，属于后续长期目标。

**安全审计发现**（原始评估，保留存档）：
- `GameConfig.GM_ENABLED` 是客户端 Lua 布尔值，任何人修改内存即可绕过 → **已通过 3.1/3.2 缓解**
- 25 个 GM 命令中 24 个纯客户端执行，直接 mutate GameState.player → **高危命令已 C2S 化**
- 唯一的 C2S 命令 HandleGMResetDaily 无权限校验 → **已加 IsGMAdmin 校验**
- 所有客户端 GM 修改的值会通过正常 SaveGame 流程持久化到服务端 → **服务端 V5c 软校验兜底**

#### 第四期：API 验证 + 服务端模块化 — 🔶 部分完成

> **目标**：验证 serverCloud 高级 API 可用性，同时拆分 server_main.lua（3478 行 → 7+ 模块）。
> **审计更新（2026-04-06）**：C2 SYSTEM_UID 已在兑换码系统中验证通过（REDEEM_SYSTEM_UID=0）。server_main 目前 3478 行，拆分需求更加迫切。

| # | 任务 | 具体内容 | 风险 | 工作量 | 状态 | 审计备注 |
|---|------|---------|------|--------|------|---------|
| 4.1 | **C2: SYSTEM_UID 验证** | `Score.Set(0, "test", data)` — 可行性未知，文档未记录。不可用时备选 GM 账号 userId | 🟡 中 | 小 | ✅ 已验证 | REDEEM_SYSTEM_UID=0，兑换码系统使用 Score+Quota(userId=0) 正常工作 |
| 4.2 | **C4: Money.Cost 验证** | 验证余额不足时自动拒绝 + 返回值格式 | 🟢 低 | 小 | ✅ 已验证（2026-04-09） | 8 项断言全通过：Add/Cost/余额不足拒绝/精确耗尽。测试脚本 `c4c5_server_test.lua` |
| 4.3 | **C5: BatchCommit 验证** | 验证跨域原子回滚（Money 不足时 Score 写入是否回滚） | 🟢 低 | 小 | ✅ 已验证（2026-04-09） | 9 项断言全通过：原子提交/失败回滚/Score 回滚确认。测试脚本 `c4c5_server_test.lua` |
| 4.4 | **C6: Message 验证** | 验证跨用户 Send/Get/MarkRead/Delete | 🟢 低 | 小 | ❌ 待验证 | |
| 4.5 | **阶段 E: 服务端模块化** | server_main.lua 拆分为：1 Session + 8 Handler 模块 | 🟡 中 | 大 | ✅ **B1~B3 已完成并上线**（2026-04-09） | 1430 行（B1~B3 后）。B4(SaveHandler) 可选。详见下方 §4.5 详细方案 |

##### §4.5 详细方案：server_main 模块化拆分

**现状**：server_main.lua 3478 行、44 函数（17 local + 27 global）、23 个 Handler、27 个功能区。

**共享状态表（核心耦合点）**：

| 状态表 | 写入方 | 读取方 | 拆分风险 |
|--------|-------|--------|---------|
| `connections_` | InitHandler | 所有模块 | 低 |
| `userIds_` | InitHandler | 所有模块 | 低 |
| `connSlots_` | SaveHandler | DaoTree/SealDemon/Trial/Rank/Redeem/Pill | **高**（最强耦合） |
| `slotWriteLocks_` | SaveHandler | DaoTree/SealDemon/Trial/Redeem | **高**（互斥锁） |
| `sealDemonActive_` | SealDemonHandler | HandleDisconnect | 中 |
| `daoTreeMeditating_` | DaoTreeHandler | HandleDisconnect | 中 |
| `trialClaimingActive_` | TrialHandler | HandleDisconnect | 中 |
| `rateLimitCounters_` | CheckRateLimit | 所有 Handler | 低 |
| `creatingChar_` | SaveHandler | HandleDisconnect | 中 |

**架构方案**：1 入口（server_main）+ 1 Session 层（ServerSession）+ 9 业务模块

```
server_main.lua（精简入口：Start/Stop + Handler 注册路由）
    └── ServerSession.lua（共享状态表 + 工具函数 + onDisconnect 回调注册）
        ├── PillHandler.lua      (~40 行)
        ├── GMHandler.lua        (~30 行)
        ├── DaoTreeHandler.lua   (~200 行)
        ├── SealDemonHandler.lua (~150 行)
        ├── TrialHandler.lua     (~100 行)
        ├── RedeemHandler.lua    (~400 行)
        ├── RankHandler.lua      (~200 行)
        ├── MigrateHandler.lua   (~100 行)
        └── SaveHandler.lua      (~1100 行，最大)
```

**分批拆分方案（逐步推进，每批稳定后再拆下一批）**：

| 批次 | 拆出模块 | 行数 | 耦合度 | 基线测试覆盖 | 风险 |
|------|---------|------|--------|------------|------|
| **B1** | PillHandler + GMHandler | ~70 | 零耦合，纯路由 | T5(GM权限) T9(丹药白名单) | ✅ **已完成并上线**（2026-04-07） |
| **B2** | DaoTreeHandler + SealDemonHandler + TrialHandler | ~450 | 中（各自只读 `connSlots_`，写自己的状态表） | T8(断连清理) + 177项B2自测 | ✅ **已完成并上线**（2026-04-09） |
| **B3** | RedeemHandler + RankHandler | ~600 | 较高（读写 `connSlots_` + 写锁） | T0 T2 T4 T7(排行+兑换码+写锁) + 23项B3自测 | ✅ **已完成并上线**（2026-04-09） |
| **B4** | SaveHandler（最大最复杂） | ~1100 | 核心（V1-V6 校验引用多域常量） | T6 T7 T8 T12 **全量回归** | 🟡 **可选**（server_main 已降至 1430 行，不再是瓶颈） |

**每批次执行流程**：

```
拆分代码 → GM 按钮跑基线测试（237 项全绿）→ 部署测试服 → 稳定 1-2 天 → 下一批次
```

**线上风险评估**：

| 等级 | 风险 | 触发条件 | 后果 | 缓解措施 |
|------|------|---------|------|---------|
| P0 | 存档覆写（锁死锁） | `AcquireSlotLock` 成功但异常路径未 `Release` | 该用户永远无法存档 | M4: 锁超时自动释放（可独立部署） |
| P0 | 脏写（提前释放锁） | 模块边界处提前 `Release`，另一请求插入 | 存档数据混写 | M3: 防御性日志 + Release 前校验 |
| P0 | 断连状态泄漏 | `HandleDisconnect` 漏清某张状态表 | 幽灵连接占用锁/资源 | onDisconnect 回调注册机制 |
| P0 | 兑换码重复发放 | `appliedRedeemCodes` 检查与写入不在同一事务 | 玩家重复领取奖励 | 幂等性保证（已有，拆分后需保持） |
| P1 | 排行榜不刷新 | `ComputeRankFromSaveData` 引用断裂 | 玩家存档但排行不更新 | T0/T2 基线测试覆盖 |
| P1 | 限流绕过 | `CheckRateLimit` 未在新模块入口调用 | 恶意请求冲击服务端 | T6 基线测试 + 代码审查 |

**缓解措施**：

| 编号 | 措施 | 可独立部署 | 说明 |
|------|------|-----------|------|
| M1 | 分批上线 | — | 每批次稳定后再拆下一批，降低回滚范围 |
| M2 | 保留存档备份文件 | ✅ | 登录时写 backup，异常时可恢复 |
| M3 | 防御性日志 | ✅ | 每次 Lock/Release/Disconnect 打 print，线上可追溯 |
| M4 | 锁超时自动释放 | ✅ | 60s 超时自动 Release，防死锁。可先于拆分独立上线 |

**基线测试（2026-04-07 已通过 ✅）**：

| 测试组 | 覆盖内容 | 断言数 |
|--------|---------|--------|
| T0 | ComputeRankFromSaveData（nil/无效/边界/截断/默认值） | ~24 |
| T2 | 排行榜分数公式一致性（全境界遍历+单调递增） | ~54 |
| T4 | ServerApplyRedeemRewards 幂等性（首次/重复/多码/混合奖励/称号去重） | ~20 |
| T5 | GM 权限校验（白名单/非GM/nil/0/类型严格） | 5 |
| T6 | 限流 CheckRateLimit（首次/30次内/第31次/窗口过期） | 4 |
| T7 | 存档槽写锁（获取/重复/释放/跨slot/跨用户） | 8 |
| T8 | 连接状态绑定 + 断连清理（7 张状态表） | 9 |
| T9 | 丹药 ID 白名单（4 合法 + 5 非法） | 9 |
| T10 | ConvertRewardsToArray 格式转换（直通/kv转数组/nil） | 5 |
| T11 | RACE_MEDAL_CONFIG 竞速道印配置完整性 | ~8 |
| T12 | SaveProtocol 事件注册完整性（20 C2S + 19 S2C + ALL_EVENTS） | ~91 |
| **合计** | | **237** |

测试入口：GM 控制台 → **"模块化基线自测"** 按钮（`tests/s45_modular_baseline_test.lua`）
结果：`237 passed, 0 failed` ✅（2026-04-07）

**B1 执行记录（2026-04-07 ✅）**：

| 步骤 | 产出文件 | 说明 |
|------|---------|------|
| S0 | `network/ServerSession.lua` | 共享状态层：9 张状态表 + 8 个工具函数（ConnKey/GetUserId/SafeSend/CheckRateLimit/AcquireSlotLock/ReleaseSlotLock/IsSlotLocked/IsGMAdmin/NormalizeSlotsIndex） |
| S1 | `network/PillHandler.lua` | 丹药购买授权：VALID_PILL_IDS 白名单 + HandleBuyPill（~60 行） |
| S2 | `network/GMHandler.lua` | GM 命令授权：HandleGMCommand（~40 行） |
| 路由 | `server_main.lua` 改造 | 原声明替换为 `local xxx = Session.xxx` 别名引用（table 按引用传递，语义等价），handler 改为模块转发 |

- **拆分策略**：别名引用（`local connections_ = Session.connections_`），现有数百处引用零改动
- **净效果**：server_main.lua 3478 → 3285 行（-193 行），新增 3 个模块文件
- **基线验证**：拆分后 GM 按钮跑测 237/237 全绿，行为零变更
- **上线状态**：✅ 已上线（2026-04-07）

**B2 执行记录（2026-04-09 ✅）**：

| 步骤 | 产出文件 | 说明 |
|------|---------|------|
| S1 | `network/DaoTreeHandler.lua` | 悟道树系统：HandleDaoTreeStart/Complete/Query + HandleGMResetDaily + CalcDaoTreeExp + 常量（~450 行） |
| S2 | `network/SealDemonHandler.lua` | 封魔任务系统：HandleSealDemonAccept/BossKilled/Abandon + QUEST_BY_ID + DAILY 配置（~350 行） |
| S3 | `network/TrialHandler.lua` | 试炼塔系统：HandleTrialClaimDaily + calcReward + 里程碑/每日路径分支（~200 行） |
| 路由 | `server_main.lua` 改造 | 删除原始 handler 代码（-920 行），添加 8 个转发桩，保留 RateLimitedSubscribe 路由兼容 |

- **净效果**：server_main.lua 3285 → 2320 行（-965 行）
- **自测**：177 项 B2 专项测试全绿 + 237 项 B1 基线回归全绿
- **上线状态**：✅ 已上线（2026-04-09）

**B3 执行记录（2026-04-09 ✅）**：

| 步骤 | 产出文件 | 说明 |
|------|---------|------|
| S1 | `network/RankHandler.lua` | 排行榜系统：ComputeRankFromSaveData/RebuildRankOnLogin/HandleGetRankList/HandleTryUnlockRace + RACE_MEDAL_CONFIG |
| S2 | `network/RedeemHandler.lua` | 兑换码系统：ServerApplyRedeemRewards/ConvertRewardsToArray/RegisterRedeemCodesFromConfig/HandleGMCreateCode/HandleRedeemCode + REDEEM_SYSTEM_UID |
| 路由 | `server_main.lua` 改造 | 删除原始代码（-890 行），添加 4 个转发桩，更新 4 处跨模块引用（ComputeRankFromSaveData/RebuildRankOnLogin/ServerApplyRedeemRewards/RegisterRedeemCodesFromConfig） |

- **跨模块引用处理**：B3 特有风险 — 3 个函数被 B4 作用域代码调用，改为 `RankHandler.xxx` / `RedeemHandler.xxx` 模块调用
- **净效果**：server_main.lua 2320 → 1430 行（-890 行）
- **自测**：23 项 B3 专项测试全绿 + 177 项 B2 回归全绿 + 237 项 B1 基线回归全绿（共 437 项）
- **上线状态**：✅ 已上线（2026-04-09）
- **注意**：`GameConfig.GM_ENABLED` 当前为 `true`（测试用），上线前必须改回 `false`

**说明**：C7（网络重连）已确认引擎层不支持 `ServerDisconnected` 事件，当前用 5s 轮询替代。引擎级自动重连不可行，W3/W4 降级为「有则锦上添花」。

**API 验证优先级（更新）**：~~C4~~ ✅ > ~~C5~~ ✅ > C6（C2+C4+C5 已完成，仅 C6 待验证，决定邮件系统 5.4 是否可行）

#### 第五期：账号级系统 + 福利/邮件/兑换码（需求 2+4）— 🔶 大部分完成

> **目标**：建立账号级与角色级的明确区分；上线服务器级的福利/邮件/兑换码体系。
> **审计更新（2026-04-06）**：5.1~5.3 仙图录系统 + 5.5 兑换码系统均已上线。仅 5.4 福利邮件、5.6 全服公告待实施。

| # | 任务 | 具体内容 | 前置 | 风险 | 工作量 | 状态 | 审计备注（代码验证） |
|---|------|---------|------|------|--------|------|---------|
| 5.1 | **account_atlas 数据结构** | 账号级 CloudStorage key `account_atlas`，含道印（medals）+ 神器（artifact + artifact_ch4）两大板块 | ~~阶段 E~~ | 🟢 低 | 小 | ✅ 已上线 | `AtlasSystem.lua` ~870行，v2 数据版本。SaveSystemNet L214-225 加载，server_main L622/L749/L1192/L1543 独立 key 读写。即时存储 `SaveImmediate()` 防不可逆进度丢失 |
| 5.2 | **道印系统**（原"成就系统"） | 仙图录道印板块：11 枚道印（6 value_check + 1 item_consume + 2 server_race + 2 first_obtain），账号级属性加成 | 5.1 | 🟡 中 | 中 | ✅ 已上线 | `MedalConfig.lua` ~300行完整配置。`CheckMedals()` 数值检测 + `ConsumeGuardianToken()` 道具消耗 + `TryUnlockRace()` 全服竞速（server_main L3388-3478 排行榜占位）+ `TryUnlockFirstObtain()` 装备首获 + `RetroCheckFirstObtain()` 回溯扫描。`RecalcMedalBonuses()` 属性写入 Player |
| 5.3 | **神器账号级迁移** | 仙图录神器板块：artifact + artifact_ch4 从角色存档→account_atlas。双向同步（并集合并 + 下发） | 5.1 | 🟡 中 | 中 | ✅ 已上线 | 第三章上宝逊金钯（9格）+ 第四章文王八卦盘（8格）。`MergeArtifactFromCharacter()` 角色→仙图录（并集），`SyncArtifactToCharacter()` 仙图录→角色（下发）。`PostLoadSync()` 7 步流程完整集成 |
| 5.4 | **福利邮件系统** | 基于 Message API。GM 发邮件 → 玩家登录拉取 → 领取附件（金币/灵韵/物品）| C2+C6 通过 | 🟡 中 | 中 | ❌ 待实施 | C2 已通过，C6 待验证 |
| 5.5 | **兑换码系统** | SYSTEM_UID Score 存兑换码配置 + Quota 防重复兑换 + C2S_RedeemCode 协议 | C2 通过 | 🟢 低 | 中 | ✅ 已上线 | `RedeemCodes.lua` 5 个有效码 + 4 个废弃码。`HandleRedeemCode()`（server_main L3202-3376）服务端权威发放 + 幂等性保证。`HandleGMCreateCode()` GM 动态创建。支持 perType account/character、targetUID 专属、expireTime 过期 |
| 5.6 | **全服公告** | SYSTEM_UID Score 存公告内容 + 登录拉取 + 弹窗展示 | C2 通过 | 🟢 低 | 小 | ❌ 待实施 | C2 已通过，可随时开始 |

**UI 实现**：`AtlasUI.lua` ~1000 行，2 个 Tab（道印 + 神器），集成于 SystemMenu + CharacterSelectScreen。`RedeemUI.lua` 弹窗输入框 + 奖励展示。

**设计文档对照**：

| 设计文档 | 路线图条目 | 实现状态 |
|---------|-----------|---------|
| `docs/设计文档/仙图录-账号级.md` v0.8 | 5.1 + 5.2 + 5.3 | ✅ 已上线（AtlasSystem + MedalConfig + AtlasUI 完整实现） |
| `docs/设计文档/神器-账号级.md` | 5.3 补充 | ✅ 已上线（第三章+第四章双向同步） |
| `docs/设计文档/兑换码.md` | 5.5 | ✅ 运营中，5 个有效兑换码 + 4 个已废弃 |

#### 第六期：经济系统——灵韵货币化 + 交易 + 仓库（需求 6）

> **目标**：灵韵迁移到 Money API，实现有限交易和回收机制。

| # | 任务 | 具体内容 | 前置 | 风险 | 工作量 |
|---|------|---------|------|------|--------|
| 6.1 | **灵韵 → Money 迁移** | 双写期 → 切换读取源 → 废弃 Score 域。首次登录存量灵韵迁移 | C4 通过 | 🟡 中 | 大 |
| 6.2 | **系统回收（NPC 回收）** | C2S_RecycleItem → Money.Add 固定价 | 6.1 | 🟢 低 | 小 |
| 6.3 | **角色仓库 UI** | 城镇 NPC 触发，背包 ↔ 仓库拖拽。存在 save_{slot}.warehouse（纯客户端操作+存档同步） | v11 已预留 | 🟢 低 | 中 |
| ~~6.4~~ | ~~**账号共享仓库**~~ | ~~独立 Score key，C2S 跨角色存取~~ | — | — | — | ✅ 已被万界商行替代（2026-04-11） |
| ~~6.5~~ | ~~**拍卖行**~~ | ~~List API (SYSTEM_UID) 挂单/购买/过期退回~~ | — | — | — | ✅ 已被万界商行替代（2026-04-11） |

#### 第七期：多职业（需求 7，灵活插入）— ✅ 双职业已上线

> **说明**：多职业系统的服务端依赖极小，主要是客户端配置+UI 工作。可在任意阶段插入开发。
> **审计更新（2026-04-06，代码验证）**：双职业（罗汉 monk / 太虚 taixu）已完整上线。classId 存档迁移、职业选择 UI、属性公式分支、8 个职业技能（含被动）全部实现。仙图录道印已对接 4 个职业道印位（2 已激活、2 预留）。

| # | 任务 | 具体内容 | 前置 | 风险 | 工作量 | 状态 | 审计备注（代码验证） |
|---|------|---------|------|------|--------|------|---------|
| 7.1 | **classId 存档化** | player.classId 写入存档，旧存档默认 "monk" | 无 | 🟢 低 | 小 | ✅ 已上线 | `SaveMigrations.lua` MIGRATIONS[16]，v15→v16 默认 "monk" |
| 7.2 | **职业配置** | CLASS_DATA 双职业（罗汉/太虚），含被动天赋 + 技能预览 | 7.1 | 🟢 低 | 小 | ✅ 已上线 | `GameConfig.lua:193-212` monk（金刚铁骨：重击+10%，每级+1根骨）/ taixu（御剑悟道：连击+8%，每级+1悟性）。`SkillData.lua` 每职业 4 技能 + 解锁序列 |
| 7.3 | **属性公式适配** | Player 属性按 classId 查 CLASS_DATA 分支计算 | 7.1 + 第三期 3.3 | 🟢 低 | 小 | ✅ 已上线 | `Player.lua:227-272` GetTotalConstitution（罗汉+根骨）/ GetTotalWisdom（太虚+悟性）/ GetClassHeavyHitChance / GetClassComboChance 4 个分支函数 |
| 7.4 | **创建角色选职业** | CharacterSelectScreen UI + C2S_CreateChar classId 参数 | 7.2 | 🟢 低 | 中 | ✅ 已上线 | `CharacterSelectScreen.lua:748-1012` 职业卡片+技能预览+精灵图+起名。`SaveSystemNet.lua:340-363` C2S_CreateChar 传递 classId。`SaveSlots.lua:158-197` 本地创角写入 classId |
| 7.5 | **被动技能实现** | 各职业差异化被动 + 主动技能体系 | 7.2 | 🟢 低 | 中 | ✅ 已上线 | 罗汉 4 技能（金刚掌/伏魔刀/金钟罩/龙象功）+ 太虚 4 技能（破剑式/一剑开天/御剑诀/剑阵降临）。`CombatSystem.lua:616` 重击判定 + `SkillSystem.lua:53-55` 连击判定 + `SkillSystem.lua:124-163` 等级自动解锁 |

**当前状态**：双职业完整上线，不支持职业切换（仅创角时选择）。

**仙图录道印关联**（代码已实现）：
- `MedalConfig.lua` 定义了 **4 个职业道印**：太虚之道（medal_taixu）、镇岳之力（medal_zhenyue）、罗汉之躯（medal_luohan）、天衍之机（medal_tianyan）
- 当前 monk/taixu 对应的 2 个道印已可激活，镇岳/天衍 2 个道印位已预留
- **后续扩展**：如需增加新职业（镇岳/天衍），仅需扩展 CLASS_DATA + SkillData，道印检测逻辑已就位

#### 第八期：多人玩法（需求 8）

> **最高复杂度，建议所有基础设施就绪后再启动。**

| # | 任务 | 具体内容 | 前置 | 风险 | 工作量 |
|---|------|---------|------|------|--------|
| 8.1 | **多人通信验证** | max_players 提升到 4 + 多连接 RemoteEvent 并发验证 | 无 | 🟡 中 | 小 |
| 8.2 | **模式 A: 异步合作** | 好友赠礼（Money+Message）/ 每日助力（Quota）/ 留言板（List）| C6 通过 | 🟢 低 | 中 |
| 8.3 | **模式 B: 回合制合作** | 房间系统 + 匹配 + 回合制 BOSS 战 + 奖励分配 | 8.1 + 阶段 E | 🔴 高 | 极大 |
| 8.4 | **模式 C: 实时合作** | 实体同步 + 预测回滚 + 带宽控制。模式 B 稳定后再评估 | 8.3 | 🔴 极高 | 极大 |

**推荐路线**：8.1 → 8.2 → 8.3 渐进式推进。8.4 视 8.3 稳定性和用户反馈决定。

### 10.3 版本号规划（审计更新 2026-04-06）

| 版本 | 阶段 | 内容 | 模块覆盖 | 状态 |
|------|------|------|---------|------|
| **v10** | B/B2/B3.1/B4-S2/S4.1 | 迁移通道 + 封妖C2S + 体魄丹 + 反推热修 + SaveGame V1-V5b 硬校验 + TryRecoverSave 补全 | 一、二 | ✅ 已上线 |
| **v11** | P0+W1+W2+S1-S7 | 即时存档保护 + 连接状态UI + 断线暂停 + 三键合并 + 序列化统一 + 文件拆分 8+1 模块 | 一 | ✅ 已上线 |
| **v12** | warehouse 字段预留 | 仓库数据结构写入存档（第二期尾声已完成） | 一 | ✅ 已上线 |
| **v13** | 第三期 3.4 | 丹药同桶迁移（shop/challenges → player）| 二 | ✅ 已上线 |
| **v14** | 第三期 3.4 bugfix | 丹药迁移修复（MIGRATIONS[14]） | 二 | ✅ 已上线 |
| **v15** | 第三期 3.4 bugfix v2 | 丹药迁移修复第二轮（MIGRATIONS[15]） | 二 | ✅ 已上线 |
| **v16**（当前） | 第七期 7.1 | classId 存档化（MIGRATIONS[16]，默认 "monk"） | 七 | ✅ 已上线 |
| — | 第五期 5.1~5.3 | 仙图录系统（account_atlas 独立 key，无需存档版本迁移）：道印+神器账号级双向同步 | 五 | ✅ 已上线 |
| — | 第七期 7.1~7.5 | 双职业系统（classId 存档 v16 + CLASS_DATA 2 职业 + 8 技能 + 选角 UI） | 七 | ✅ 已上线 |
| **v17** | 第六期 6.1 | 灵韵 → Money 迁移（双写期 → 切换读取源） | 六 | 📋 规划中 |

### 10.4 风险热力图（审计更新 2026-04-06）

| 期数 | 主题 | 技术风险 | 依赖风险 | 复杂度 | 对应需求 | 状态 |
|------|------|---------|---------|--------|---------|------|
| 三 | 安全基线 | ~~🟢 低~~ | ~~🟢 低~~ | ~~中~~ | 需求 1+5 | ✅ 已完成 |
| 四 | API 验证+模块化 | 🟢 低（C2+C4+C5 已验证） | 🟢 低（仅 C6 待验证） | 中 | 基础设施 | 🔶 C2+C4+C5 ✅ |
| 五 | 账号级+福利 | ~~🟡 中~~ | ~~🟡 中~~ | ~~高~~ | 需求 2+4 | ✅ 5.1~5.3+5.5 已上线（仅 5.4/5.6 待做） |
| 六 | 经济系统 | 🟡 中（灵韵迁移双写期） | 🟢 低（C4+C5 已通过，门控解除） | ~~高~~ **中**（拍卖行+共享仓库已被万界商行替代，仅余灵韵迁移+角色仓库+NPC回收） | 需求 6 | 📋 可启动 |
| 七 | 多职业 | ~~🟢 低~~ | ~~🟢 低~~ | ~~低~~ | 需求 7 | ✅ 双职业已上线（7.1~7.5 全部完成） |
| 八 | 多人玩法 | 🔴 高（实时同步） | 🟡 中（独立验证） | 极高 | 需求 8 | ❌ 待启动 |

**已完成需求**：
- 需求 1+5（基础防作弊+GM 保护）：第三期 5 项全部完成 ✅
- 需求 2（账号级系统）：仙图录 account_atlas 已上线（道印 11 枚 + 神器双向同步） ✅
- 需求 3（弱网断线恢复）：W1 连接状态 UI + W2 断线暂停存档 + 恢复补存 — 第二期已完成 ✅
- 需求 4（兑换码）：5 个有效兑换码运营中，服务端权威发放 + GM 动态创建 ✅
- 需求 7（多职业）：双职业（罗汉/太虚）完整上线，含 8 技能 + 被动 + 选角 UI ✅
- C7（引擎级自动重连）：已确认不可行（引擎无 ServerDisconnected 事件），降级为非必需

**路线图外已完成功能**：
- 酒系统（WineSystem）：独立玩法系统 ✅
- 仓库 bug 修复：GameState.Init warehouse=nil + WarehouseSystem.Deserialize(nil) 兜底 ✅
- 装备首获道印（first_obtain）：灵器初现 + 圣器降世，回溯扫描已有装备 ✅
- **万界商行（BlackMerchant）** ✅（2026-04-11）：全服 NPC 商品交易系统，替代原计划拍卖行（§7.3）和共享仓库（§2.2.3/§6.4）。基于 SYSTEM_UID + Money + BatchCommit + List 实现，含 16 件商品、买卖价差回收、碎片兑换、交易日志

---

## 11. serverCloud API 能力速查

| 域 | API | 数据模型 | 适用场景 | 限制 |
|----|-----|---------|---------|------|
| **Score** | Get/Set/SetInt/Add/Delete | KV (scores+iscores) | 存档、配置 | 1MB/key |
| **BatchGet** | 单人多Key/多人多Key | 批量读取 | 登录加载 | 300 读/min |
| **BatchSet** | 链式 Set/SetInt/Add/Delete | 批量写入 | 存档保存 | 300 写/min |
| **Ranking** | GetRankList/GetUserRank/GetRankTotal | iscores 排序 | 排行榜 | 仅整数 |
| **Money** | Get/Add/Cost | 命名货币 | 灵韵/金币 | **Cost 原子扣款** |
| **List** | Get/GetById/Add/Modify/Delete | 有序列表+list_id | 拍卖/日志 | 无条件查询 |
| **Item** | Get/Add/Use | 命名道具+数量 | 简单道具 | — |
| **Message** | Send/Get/MarkRead/Delete | 跨用户消息 | 邮件/通知 | 跨用户发送 |
| **Quota** | Get/Add/Reset | 限次计数器 | 每日限制 | **day/week/month 自动刷新** |
| **BatchCommit** | Score+Money+List+Quota | 跨域原子事务 | 交易/购买 | **1000 ops/批** |

**全局限制**：

| 限制项 | 值 |
|--------|-----|
| 读请求频率 | 300 次/分钟 |
| 写请求频率 | 300 次/分钟 |
| BatchCommit 操作数 | 1000/次 |
| Score 单 key | 1MB |

**待验证项**（审计更新 2026-04-06）：

| # | 项目 | 验证方法 | 对应模块 | 状态 |
|---|------|---------|---------|------|
| C2 | SYSTEM_UID 读写 | Score.Set(0, "test", {...}) | 三、四、六 | ✅ 已验证（兑换码系统生产验证，REDEEM_SYSTEM_UID=0） |
| C3 | List (SYSTEM_UID) | List.Add(0, "test", {...}) | 六 | ❌ 待验证 |
| C4 | Money.Cost 余额校验 | Money.Cost(uid, "gold", 99999) | 六 | ✅ 已验证（2026-04-09，8 断言全通过） |
| C5 | BatchCommit 原子回滚 | MoneyCost(不够) + MoneyAdd | 六 | ✅ 已验证（2026-04-09，9 断言全通过） |
| C6 | Message 跨用户 | Message.Send(uid1, "test", uid2, {...}) | 三、八 | ❌ 待验证 |
| C7 | 网络重连 | 断开后 ReConnect | 五 | ❌ 不可行（引擎无事件） |

---

## 12. 下一步执行路线图（2026-04-06 审计后）

### 12.1 当前全局进度

```
第一期 ████████████████████ 100%  ✅ 紧急修复（v10）
第二期 ████████████████████ 100%  ✅ 存档全方位优化（v11~v12）
第三期 ████████████████████ 100%  ✅ 安全基线（v13~v15）
第四期 █████████████████░░░  85%  🔶 C2+C4+C5 已验证✅，阶段 E B1~B3 已上线✅（B4 可选），仅 C6 待验证
第五期 █████████████░░░░░░░  67%  🔶 5.1~5.3✅已上线 + 5.5✅运营中，仅 5.4/5.6 待做
第六期 ░░░░░░░░░░░░░░░░░░░░   0%  📋 可启动（C4+C5 已通过，灵韵迁移门控解除）
第七期 ████████████████████ 100%  ✅ 双职业已上线（罗汉/太虚，8技能）
第八期 ░░░░░░░░░░░░░░░░░░░░   0%  ❌ 待启动（建议最后）
```

### 12.2 推荐执行顺序

**立即可做（无外部依赖）**：

| 优先级 | 任务 | 工作量 | 理由 |
|--------|------|--------|------|
| ~~P0~~ ✅ | **4.5 阶段 E：server_main 模块化** | 大 | ✅ B1~B3 已上线，3478→1430 行，8 Handler 独立模块化（B4 可选） |
| ~~P1~~ ✅ | **4.2 C4: Money.Cost 验证** | 小 | ✅ 已验证（2026-04-09），灵韵迁移门控解除 |
| ~~P1~~ ✅ | **4.3 C5: BatchCommit 验证** | 小 | ✅ 已验证（2026-04-09），交易系统门控解除 |
| **P1** | **4.4 C6: Message 验证** | 小 | 邮件系统（5.4）的门控条件 |
| **P2** | **5.6 全服公告** | 小 | C2 已通过，可直接开始 |

**依赖解锁后可做**：

| 任务 | 前置条件 | 说明 |
|------|---------|------|
| 5.4 福利邮件 | C6 验证通过 | GM 发邮件 → 玩家领取 |
| 6.1 灵韵 → Money | ✅ C4 已通过 | 经济系统核心（v17），**门控已解除，可立即启动** |
| 6.2 NPC 回收 + 6.3 角色仓库 | 6.1 完成 | 经济系统剩余两项（~~6.4/6.5 已被万界商行替代~~） |

**可选扩展（非阻塞）**：

| 任务 | 说明 |
|------|------|
| 7.2+ 扩展新职业（镇岳/天衍） | 仅需扩展 CLASS_DATA + SkillData，仙图录道印检测逻辑已就位 |
| 仙图录设计文档同步 | `仙图录-账号级.md` v0.8 与代码有差异（代码实际 11 枚道印含 2 个 first_obtain，文档仅 9 枚），建议同步 |

### 12.3 关键路径

```
                 ┌─ C4 验证 ✅ ─→ 6.1 灵韵迁移（v17）【可立即启动】─→ 6.2 NPC回收 + 6.3 角色仓库
                 │
4.5 server_main ─┼─ C5 验证 ✅ ─→ ~~6.5 拍卖行~~ ✅ 已被万界商行替代
    模块化拆分 ✅ │
                 └─ C6 验证 ❌ ─→ 5.4 福利邮件【等 C6 验证】

并行可做：5.6 全服公告 / 扩展新职业（镇岳/天衍） / 多人区域（§9）

已完成（无需再排期）：
  ✅ C2 SYSTEM_UID 验证（兑换码生产验证）
  ✅ C4 Money.Cost 验证（2026-04-09，8 断言全通过）
  ✅ C5 BatchCommit 验证（2026-04-09，9 断言全通过）
  ✅ 4.5 阶段 E 模块化（B1~B3，3478→1430 行）
  ✅ 5.1~5.3 仙图录（account_atlas + 11道印 + 神器双向同步）
  ✅ 5.5 兑换码（5有效 + GM创建 + 服务端权威）
  ✅ 7.1~7.5 双职业（classId v16 + 2职业 + 8技能 + 选角UI）
  ✅ 万界商行（替代 §7.3 拍卖行 + §2.2.3/§6.4 共享仓库 + §6.5 拍卖行）
```

### 12.4 技术债务清单

| 项目 | 严重度 | 说明 |
|------|--------|------|
| ~~server_main.lua 3478 行~~ | ~~🔴 高~~ ✅ 已解决 | B1~B3 拆分后降至 1430 行，8 个 Handler 独立模块化，不再是瓶颈 |
| 设计文档与代码不同步 | 🟡 中 | 仙图录文档 v0.8 写 9 枚道印，代码实际 11 枚（+2 first_obtain）；兑换码文档列 7 个码，实际 5 有效+4 废弃 |
| GM 命令仍有弱点 | 🟡 中 | 非高危命令仍纯客户端执行（如 addItem） |
| bossKills 无服务端验证 | 🟡 中 | 客户端可提交伪造值，需战斗结算 C2S 化 |
| 灵韵仍在 Score 域 | 🟢 低 | 需迁移到 Money API（C4 已验证通过，可启动 6.1 迁移） |
| 丹药迁移经历 3 轮修复 | 🟢 低 | v13→v14→v15，已稳定但说明迁移测试需加强 |
| **DungeonHandler SlotLock 缺失** | 🔴 高 | `_ApplyRewardToOnline` 对 `save_X` 做读-改-写但未获取 SlotLock，与 `HandleSaveGame` 存在竞态，可导致存档数据回退。其他所有 Handler（DaoTree/SealDemon/Trial/Redeem）均已正确使用 SlotLock。**待修复** |
| **slotsIndex 空写入 Bug（已修三层防御）** | ✅ 已修 | 历史 Bug：`_cachedSlotsIndex` 为 nil 时 fallback 空表 `{}`，写入 serverCloud 清空 `slots_index`。已在三层修复：① SavePersistence.lua:310 跳过 nil 写入 ② CloudStorage.lua:303 nil→空字符串 ③ server_main.lua:1112 检查 `next(slots)` 非空。自愈机制（FetchSlots:340-376）可从 `save_X` 重建索引 |

### 12.5 预览/正式环境隔离事件记录（2026-04-12）

**事件**：作者账号 4 个角色槽位在预览窗口全部显示空（"+ 创建角色"）。

**根因**：2026-04-11 TapTap 平台拆分预览环境与正式环境，serverCloud 后端数据隔离。预览窗口连接的是独立空命名空间，正式服数据不受影响。

**验证结果**：
- 预览环境：空命名空间，`needMigration=true`，`slotCount=0`
- 正式服：作者手机登录确认 4 个角色完好

**排查过程中穷举审计的代码路径**：
- `server_main.lua` 6 处 BatchSet、4 处 BatchGet — 无异常
- `DungeonHandler.lua` 2 处写入 — 发现 SlotLock 缺失（见技术债务）
- `CloudStorage.lua` / `SavePersistence.lua` / `SaveSystemNet.lua` — 发现已修复的 slotsIndex 空写入 Bug 证据链
- 自愈机制（`HandleFetchSlots` 孤儿存档修复）逻辑正确，可从 `save_X` 重建 `slots_index`
- **结论**：代码中不存在能同时清空 `slots_index` 和 `save_1~4` 的路径，全空仅可能是空命名空间

**对开发流程的影响**：
- 预览环境无法看到正式服存档、排行榜、玩家数据
- 多人副本系统（DungeonHandler）需在预览环境用测试数据独立调试
- 正式服验证只能通过手机端 TapTap 正式版进行

---

*最后更新：2026-04-12*
*版本：v3.8（v3.7 + 预览/正式环境隔离事件记录 + DungeonHandler SlotLock 缺失记入技术债务）*
