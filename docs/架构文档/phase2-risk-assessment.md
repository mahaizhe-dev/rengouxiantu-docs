# 第二期优化 — 风险评估与测试预案

> 最后更新：2026-03-30（基于代码审计）
> 基线版本：SAVE_VERSION=10, CODE_VERSION=4
> 状态：**已上线 TapTap，所有变更均为热修复**

---

## 一、第二期任务总览

| # | 任务 | 风险等级 | 影响范围 | 可回滚 |
|---|------|---------|---------|--------|
| 1 | B3-2：丹药计数挪入 player | 🟡 中 | 存档结构 + 3 模块 | ✅ |
| 2 | V5~V7：属性软校验 | 🟢 低 | server_main 仅日志 | ✅ |
| 3 | S1.2：丹药购买 C2S 事件 | 🟢 低 | 新增事件 | ✅ |
| 4 | B4-S3：三键合并为单键 | 🔴 高 | 存档读写核心链路 | ⚠️ |
| 5 | MIGRATIONS[11] | 🟡 中 | 迁移管线 | ✅ |
| 6 | 装备全字段序列化 | 🟡 中 | 背包序列化 + 空间 | ✅ |
| 7 | classId 存档化 | 🟢 低 | 新增字段 | ✅ |
| 8 | warehouse 字段预留 | 🟢 低 | 新增空对象 | ✅ |
| 9 | bossKills 上限 cap | 🟢 低 | clamp 逻辑 | ✅ |
| 10 | 历史债务清理 ~600 行 | 🟡 中 | MIGRATIONS + fillEquipFields | ✅ |

---

## 二、逐项风险分析

### 2.1 B3-2：丹药计数挪入 player 桶

**当前状态**：
- 4 个字段在 `shop` 桶（AlchemyUI 模块局部变量）：`tigerPillCount`, `snakePillCount`, `diamondPillCount`, `temperingPillEaten`
- 2 个字段在 `challenges` 桶（ChallengeSystem 模块变量）：`xueshaDanCount`, `haoqiDanCount`
- 10 个字段已在 `player` 桶：`pillKillHeal`, `pillConstitution`, `pillPhysique`, `fruitFortune`, `daoTreeWisdom`, `daoTreeWisdomPity`, `seaPillarDef/Atk/MaxHp/HpRegen`

**变更内容**：将 shop 的 4 个 + challenges 的 2 个共 6 个字段迁移到 player 桶。

**涉及文件**（5 个）：
| 文件 | 变更 |
|------|------|
| `SaveSystem.lua` — SerializePlayer | +6 字段 |
| `SaveSystem.lua` — DeserializePlayer | +6 字段赋值 |
| `SaveSystem.lua` — SerializeShop/DeserializeShop | 删除 4 字段（可整体废弃） |
| `ChallengeSystem.lua` — Serialize/Deserialize | 删除 2 丹药字段 |
| `AlchemyUI.lua` — Get/Set 函数 | 改为读写 player 对象 |
| `server_main.lua` — V5 校验 | 合并 shop/challenges 校验到 player 块 |

**风险点**：
1. **向后兼容**：旧客户端已把丹药存在 shop/challenges 桶，MIGRATIONS[11] 需要在 load 时把旧位置的值搬到 player 中
2. **服务端校验**：V5 的 3 个校验块（shop/challenges/player）需要合并为 1 个 player 块
3. **双读问题**：迁移期如果 player 和 shop 都有值，取哪个？→ 以 player 为准，shop 仅作 fallback

**缓解措施**：
- MIGRATIONS[11] 中先检查 player 是否已有值，若无则从 shop/challenges 搬入
- 搬入后删除 shop/challenges 中的对应字段（减少存档大小）
- 自测脚本覆盖：纯旧存档、已迁移存档、混合存档三种场景

---

### 2.2 V5~V7：属性软校验

**当前状态**：服务端已有 V1~V5b 硬校验（level/exp/gold/lingYun/丹药/海神柱等级）。

**新增内容**：对战斗属性做上界日志检查（先 log-only，2 周后转硬校验）。

**软上限（含 20% 安全余量）**：

| 属性 | 理论极限 | 推荐软上限 | 公式来源 |
|------|---------|-----------|---------|
| maxHp | ~12500 | 15000 | base(4740) + seaPillar(300) + equip(~2500) + physique50%(~3750) + collection(~500) |
| atk | ~1750 | 2100 | base(1061) + seaPillar(30) + equip(~400) + title(15) + collection(~100) |
| def | ~2100 | 2500 | base(701) + seaPillar(20) + equip(~350) + constitution88%(~850) + collection(~100) |
| hpRegen | ~160 | 200 | base(70.8) + seaPillar(30) + equip(~30) + pillKillHeal(45*0.5≈22) |

**涉及文件**：仅 `server_main.lua` HandleSaveGame（在 V5b 之后追加 V5c~V7 块）

**风险点**：
1. **误报**：如果上限设太低，正常玩家也会被日志标记 → 先做 log-only，收集 2 周数据
2. **属性计算遗漏**：属性来源复杂（基础+装备+丹药+海神柱+体质%+collection），遗漏源头会导致上限偏低

**缓解措施**：
- 第一阶段仅 `print("[Server][V6-WARN]")` 日志，不 clamp
- 2 周后根据日志数据调整阈值，确认无误报再转硬校验
- 自测脚本模拟极端属性值验证边界

---

### 2.3 S1.2：丹药购买 C2S 事件

**当前状态**：丹药购买在客户端本地执行（AlchemyUI 扣金币+增计数），无服务端参与。

**新增内容**：购买时发送 C2S 事件，服务端验证金币余额、丹药上限后回应。

**涉及文件**：
| 文件 | 变更 |
|------|------|
| `AlchemyUI.lua` | 购买逻辑改为 C2S 请求 → 等回调 → 再扣款 |
| `server_main.lua` | 新增 HandlePillPurchase 处理函数 |
| `SaveProtocol.lua`（如存在） | 新增事件 ID |

**风险点**：
1. **体验延迟**：网络往返增加购买延迟，需加 loading 反馈
2. **离线降级**：单机模式下无服务端，需 fallback 到本地逻辑
3. **重复购买**：客户端连点可能发多个请求 → 服务端需幂等/频率限制

**缓解措施**：
- 检查 `.project/settings.json` 的 `multiplayer.enabled`，单机模式保留本地逻辑
- 客户端加购买冷却（200ms 防抖）
- 服务端基于当前存档快照校验（不依赖客户端传值）

---

### 2.4 B4-S3：三键合并为单键 🔴 高风险

**当前状态**：
- 存档分 3 个 key：`save_data_X`（core ~4KB）+ `save_bag1_X`（1-30 ~6KB）+ `save_bag2_X`（31-60 ~6KB）
- 另有 6 个备份 key 对：`save_prev_bag1_X` 等
- 总计 12 个 bag 相关 key 函数（8 个 bag key + 4 个其他）
- serverCloud 单 key 上限 1MB

**变更内容**：
- 三键 → 单键 `save_data_X`，inventory 数据嵌入 coreData
- 删除 8 个 bag key 函数 + 对应备份 key 函数
- 简化 HandleSaveGame/HandleLoadGame 的 BatchSet/BatchGet

**预估合并后大小**：
- coreData ~4KB + bag1 ~6KB + bag2 ~6KB = **~16KB**（远低于 1MB 限制）

**涉及文件**（大量）：
| 文件 | 变更 |
|------|------|
| `SaveSystem.lua` — Save 流程 | 合并 bag1/bag2 到 coreData |
| `SaveSystem.lua` — Load 流程 | 取消 bag 重组逻辑 |
| `SaveSystem.lua` — 8 个 key 函数 | 删除 |
| `SaveSystem.lua` — SerializeBackpackBags | 改为 SerializeBackpack（不拆分） |
| `SaveSystem.lua` — checkpoint/备份 | 简化为单 key 备份 |
| `server_main.lua` — HandleSaveGame | 单 key BatchSet |
| `server_main.lua` — HandleLoadGame | 单 key BatchGet |
| `server_main.lua` — HandleDeleteChar | 简化 key 清理 |

**风险点**：
1. **🔴 数据丢失**：合并过程中 bag1/bag2 遗漏 → 装备丢失（不可逆！）
2. **🔴 向后兼容**：旧客户端仍发三键存档，服务端需同时支持
3. **🟡 存档膨胀**：单 key 大小从 ~4KB 跳到 ~16KB，备份 key 同步膨胀
4. **🟡 原子性**：三键 BatchSet 如果部分失败，数据一致性问题（合并后此问题消失）

**缓解措施**：
- **必须分两步**：
  1. 先在 MIGRATIONS[11] 中合并读取逻辑（读三键重组到单结构），写出时仍保持三键
  2. 确认迁移无损后，再切换写出为单键
- 服务端 HandleLoadGame 检测 bag1/bag2 是否存在，存在则重组（向后兼容旧客户端）
- **关键测试**：60 格背包满载 → 序列化 → 反序列化 → 逐物品比对
- 上线前导出 10 份真实存档做 round-trip 验证

---

### 2.5 MIGRATIONS[11]

**当前状态**：MIGRATIONS[2]~[10]，共 343 行（v2~v9 约 288 行可清理）。

**新增内容**：MIGRATIONS[11] 处理 v10→v11 迁移：
1. 丹药字段从 shop/challenges 搬到 player（配合 B3-2）
2. bag1/bag2 合并到 inventory（配合 B4-S3）
3. bossKills cap 应用
4. classId 注入
5. warehouse 预留

**风险点**：
1. **迁移顺序**：必须先搬丹药再合并 bag，否则 shop/challenges 桶在合并后丢失
2. **幂等性**：MIGRATIONS[11] 可能被多次执行（保存-加载循环），必须幂等
3. **回滚**：如果 v11 有 bug，version=11 的存档无法回滚到 v10 代码 → 需保留 v11→v10 的降级路径

**缓解措施**：
- 迁移函数内每步都做 `if not data.player.xxx then ... end` 幂等检查
- 单元测试覆盖：v10 存档 → MIGRATIONS[11] → 验证所有字段
- 保留 `SaveSystem.lua:566` 的 v11→v10 降级容忍逻辑（当前已有）

---

### 2.6 装备全字段序列化

**当前状态**：
- 已装备物品：`SerializeItemFull()`（24 字段，完整）
- 背包物品：`SerializeItem()`（裁剪版，装备类移除 name/icon/sellPrice/subStats[].name）
- 反序列化时 `fillEquipFields()`（65 行）从模板反查裁剪字段

**变更内容**：背包物品也用 `SerializeItemFull()`，废弃 `SerializeItem()` + `fillEquipFields()`。

**空间影响估算**：
- 每件装备增加 ~50 字节（name ~10B, icon ~15B, sellPrice ~8B, subStats[].name ~15B）
- 60 格满装备最坏情况：+3000 字节 ≈ +3KB
- 合并后单 key 从 ~16KB → ~19KB（仍远低于 1MB 限制）

**风险点**：
1. **🟡 存档膨胀**：可接受（+3KB），但需监控
2. **🟡 旧存档兼容**：旧存档中背包装备没有 name/icon 等字段，加载时需保留 fillEquipFields 做 fallback
3. **🟢 数据完整性**：消除了模板反查失败的风险（之前存在 specialTpl 找不到的边界情况）

**缓解措施**：
- 保留 `fillEquipFields` 作为 fallback（检测到 item.name 缺失时调用）
- MIGRATIONS[11] 中对所有背包物品补全缺失字段
- 不再考虑旧存档 → fillEquipFields 可在清理期删除

---

### 2.7 classId 存档化

**当前状态**：仅有 "monk" 一个职业，通过 `CLASS_DATA` 硬编码。

**变更内容**：在 player 桶中添加 `classId = "monk"` 字段。

**风险**：🟢 极低。新增字段，默认值 "monk"，无破坏性。

---

### 2.8 warehouse 字段预留

**变更内容**：在 coreData 中添加 `warehouse = {}` 空对象。

**风险**：🟢 极低。纯预留，无逻辑。

---

### 2.9 bossKills 上限 cap

**当前状态**：
- `GameEvents.lua:56` 无限递增
- 68 个 BOSS，3 分钟重生，全部可重复击杀
- 用于称号解锁（1k/10k 里程碑）和排行显示（不参与排序）

**推荐上限**：80,000（理论上限 68×3min 需要 ~283 小时全勤刷，80k 提供充足余量）

**变更内容**：
- 客户端：`GameEvents.lua` 增加 `if GameState.bossKills >= 80000 then return end`
- 服务端：`server_main.lua` V8 块 clamp bossKills

**风险**：🟢 极低。单向 clamp，不影响已有数据。

---

### 2.10 历史债务清理 ~600 行

**审计结果**：

| 清理目标 | 行数 | 文件 | 风险 |
|---------|------|------|------|
| MIGRATIONS v2~v9 | ~288 行 | SaveSystem.lua L130~390 | 🟡 中 |
| fillEquipFields | ~65 行 | SaveSystem.lua L932~997 | 🟡 中 |
| 8 个 bag key 函数 | ~80 行 | SaveSystem.lua | 🟡 中 |
| SerializeItem（裁剪版） | ~50 行 | SaveSystem.lua L870~920 | 🟢 低 |
| SerializeBackpackBags（拆分版） | ~25 行 | SaveSystem.lua L789~813 | 🟢 低 |
| SerializeShop/DeserializeShop | ~30 行 | SaveSystem.lua L1194~1224 | 🟢 低 |
| legacy inv key 清理 | ~40 行 | server_main.lua | 🟢 低 |
| **合计** | **~578 行** | | |

**风险点**：
1. **MIGRATIONS 删除**：v10 以下的存档将无法迁移 → 必须确认所有线上存档已迁移到 v10+
2. **fillEquipFields 删除**：依赖全字段序列化（2.6）先完成

**缓解措施**：
- 清理顺序严格按依赖：先完成 2.6（全字段序列化）→ 再删 fillEquipFields → 最后删 MIGRATIONS
- 上线前在服务端日志中确认无 v9 以下存档加载记录
- 规则"不再考虑旧存档"已确认，但建议保留 2 周观察窗口

---

## 三、依赖关系与推荐执行顺序

```
第一批（无依赖，可并行）：
  ├── 2.2 V5~V7 属性软校验（仅 server_main，log-only）
  ├── 2.7 classId 存档化
  ├── 2.8 warehouse 预留
  └── 2.9 bossKills cap

第二批（前置依赖：第一批完成）：
  ├── 2.1 B3-2 丹药计数挪入 player
  └── 2.3 S1.2 丹药购买 C2S

第三批（前置依赖：第二批完成）：
  ├── 2.6 装备全字段序列化
  └── 2.5 MIGRATIONS[11]（包含所有迁移逻辑）

第四批（前置依赖：第三批完成）：
  └── 2.4 B4-S3 三键合并单键

第五批（前置依赖：第四批上线稳定 2 周）：
  └── 2.10 历史债务清理
```

**关键路径**：B3-2 → MIGRATIONS[11] → B4-S3 → 清理
**高风险集中在第四批**（三键合并），建议该批独立上线并做 A/B 灰度。

---

## 四、自测脚本说明

配套自测脚本：`scripts/tests/phase2_self_test.lua`

### 测试覆盖矩阵

| 测试用例 | 覆盖任务 | 验证点 |
|---------|---------|--------|
| T01 丹药字段迁移 | B3-2, MIGRATIONS[11] | 6 字段从 shop/challenges 搬到 player |
| T02 属性软上限 | V5~V7 | maxHp/atk/def/hpRegen 边界检查 |
| T03 bossKills cap | 2.9 | clamp 到 80000 |
| T04 classId/warehouse | 2.7, 2.8 | 新字段存在且默认值正确 |
| T05 装备全字段序列化 round-trip | 2.6 | SerializeItemFull → Deserialize → 比对 |
| T06 三键→单键数据完整性 | B4-S3 | bag1+bag2 合并后物品数不变 |
| T07 MIGRATIONS[11] 幂等性 | 2.5 | 执行两次结果一致 |
| T08 SerializePlayer 字段完整性 | B3-2 | 所有 23+6 个字段均有值 |
| T09 rebuildData 完整性 | 灾备 | TryRecoverSave 产出的数据可正常 Deserialize |

脚本采用纯 Lua assert 测试，不依赖引擎运行时，可离线执行。

---

## 五、回滚方案

| 场景 | 方案 |
|------|------|
| V5~V7 误报过多 | 删除 V5c~V7 日志代码，不影响存档 |
| 丹药迁移丢失 | MIGRATIONS[11] 回读 shop/challenges 桶恢复 |
| 三键合并数据丢失 | 服务端 HandleLoadGame 仍支持读三键，客户端降版本回写三键 |
| bossKills cap 偏低 | 调高上限值，无数据丢失 |
| 全字段序列化膨胀过大 | 回退到裁剪版，保留 fillEquipFields |

---

*文档版本：v1.0*
*审计基线：SaveSystem.lua + server_main.lua + GameEvents.lua + AlchemyUI.lua + ChallengeSystem.lua*
