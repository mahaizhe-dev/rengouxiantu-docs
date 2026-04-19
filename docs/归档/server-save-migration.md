# 服务器存档迁移方案

> **版本**: v2.1
> **创建日期**: 2026-03-16
> **更新日期**: 2026-03-26（排行榜服务端权威计算 + 登录自动修复）
> **状态**: Phase 1 已完成 + Phase 2 已完成并测试通过，待正式上线迁移

---

## 一、迁移目标

| 维度 | 当前（clientScore） | 目标（serverCloud） |
|------|-------------------|-------------------|
| 存储引擎 | clientScore（客户端读写） | serverCloud（服务端读写） |
| 单 key 上限 | **10KB** | **1MB** |
| 数据校验 | 无（客户端可篡改） | 服务端可校验 |
| 日常限次 | 无原生支持 | `quota` API 原生支持 |
| 原子事务 | 无 | `BatchCommit`（跨域原子） |
| 架构模式 | 纯客户端 | C/S（Client + Server） |

---

## 二、关键约束（已全部验证通过）

### 2.1 serverCloud 无法读取 clientScore ✅ 已验证

- `clientScore` 运行在客户端进程（UrhoXRuntime）
- `serverCloud` 运行在服务端进程（UrhoXServer）
- **服务端无法主动拉取 clientScore 数据**

**实测验证（fb503）**：服务端 `serverCloud:Get(uid, "slots_index")` → 返回 nil。
**结论：clientCloud 和 serverCloud 是完全独立的存储后端，不共享数据。**

### 2.2 multiplayer.enabled 互斥约束 ✅ 已验证

| `enabled` | clientCloud | 服务器部署 |
|-----------|-------------|-----------|
| `false` | **可用** | 不部署 |
| `true` | **nil** | 部署 |

**不可能在同一版本中同时访问 clientCloud 和 serverCloud。**

### 2.3 本地文件跨版本持久化 ✅ 已验证

| 平台 | File API 写入 | 关闭后持久化 |
|------|-------------|-------------|
| iOS/Android | 成功 | **持久化** ✅ |
| PC (WASM) | 成功 | **丢失** ❌ |

### 2.4 旧数据不删除

迁移完成后 **不主动删除** clientScore 中的旧数据。回滚安全网。

---

## 三、迁移方案：两阶段发布 + 本地文件中转

### 3.1 总体架构

```
Phase 1 (enabled=false)              Phase 2 (enabled=true)
┌──────────────────────────┐        ┌──────────────────────────────┐
│ 每次存档成功后            │        │ 首次连接服务端后              │
│ coreData + bag1 + bag2   │        │                              │
│ + slotsIndex             │        │ 1. C2S_FetchSlots            │
│   ↓ cjson.encode          │        │ 2. needMigration? → 迁移链   │
│ 写入本地文件              │  ───►  │   ├─ clientCloud 迁移        │
│ save_export_X.json        │  升级  │   ├─ local_file 迁移         │
│                           │        │   └─ 重新 FetchSlots         │
│ ✅ 已实现 + 验证          │        │ 3. 迁移成功 → 删除本地文件    │
└──────────────────────────┘        │                              │
                                    │ ✅ 已实现 + 测试通过          │
                                    └──────────────────────────────┘
```

### 3.2 迁移安全原则 🔴

> **迁移 ≠ 优化。只做搬运，不改结构。**

| 原则 | 说明 |
|------|------|
| **1. 迁移前有备份** | 服务端迁移前将完整 payload 备份到 `save_migrate_backup_{source}` |
| **2. 迁移后结构不变** | serverCloud 中的存储结构与 clientScore **完全一致**：三键拆分保留 |
| **3. 版本号不变** | CURRENT_SAVE_VERSION 保持 v9，不升至 v10 |
| **4. 幂等保护** | 目标槽位已有数据 → 跳过迁移，不覆盖 |

---

## 四、实际存储结构（已实现）

### 4.1 三键结构保留

迁移后 serverCloud 的存储结构与 clientScore **完全一致**，不做合并：

| Key | 说明 |
|-----|------|
| `slots_index` | 槽位索引（含 4 个槽位） |
| `save_data_1~4` | 核心存档数据 |
| `save_bag1_1~4` | 背包前半 |
| `save_bag2_1~4` | 背包后半 |
| `rank_score_1~4` | 排行分数（iscore），**服务端权威计算**（`ComputeRankFromSaveData`） |
| `rank_info_1~4` | 排行展示信息（服务端从 coreData 提取） |
| `rank_time_1~4` | 排行时间戳（同分排序用） |
| `boss_kills_1~4` | BOSS 击杀数（服务端从 coreData 提取） |
| `account_bulletin` | 账号级公告 |
| `player_level` | 等级（辅助字段） |
| `_code_ver` | 代码版本号 |

### 4.2 四槽位设计

| 槽位 | 用途 | 创角允许 |
|------|------|---------|
| 1-2 | 正常角色槽 | ✅ 允许创角 |
| 3-4 | 迁移恢复槽（local_file 迁移目标） | ❌ 不允许创角 |

**相关常量**：
- `SaveSystem.MAX_SLOTS = 4`
- `SaveSystem.NEW_CHAR_MAX = 2`

### 4.3 SlotMap 映射（服务端 HandleMigrateData 实现）

| 迁移源 | 原始槽位 → 目标槽位 | 说明 |
|--------|---------------------|------|
| `clientCloud` | 1→1, 2→2 | 原样搬运（客户端 clientCloud 仍有数据的情况） |
| `local_file` | 1→3, 2→4 | 重映射到恢复槽位，避免冲突 |

### 4.4 版本号

| 项目 | 值 |
|------|-----|
| CURRENT_SAVE_VERSION | **9**（未改变） |
| GameConfig.CODE_VERSION | 用于版本握手（C2S_VersionHandshake） |

---

## 五、C/S 通信协议（已实现）

### 5.1 SaveProtocol 事件表

| 事件名 | 方向 | 用途 | 数据格式 |
|--------|------|------|---------|
| `C2S_VersionHandshake` | C→S | 版本握手 | `{ Version: int }` |
| `S2C_ForceUpdate` | S→C | 强制更新通知 | 无数据 |
| `C2S_FetchSlots` | C→S | 请求角色列表 | 无数据 |
| `S2C_SlotsData` | S→C | 返回角色列表 | `{ Data: JSON(slotsIndex + needMigration) }` |
| `C2S_LoadGame` | C→S | 请求加载槽位 | `{ Slot: int }` |
| `S2C_LoadResult` | S→C | 返回存档数据 | `{ Slot, SaveData, Bag1Data, Bag2Data, InvData: JSON }` |
| `C2S_SaveGame` | C→S | 上报保存数据 | `{ Slot, SaveData, Bag1Data, Bag2Data, SlotsIndex, RankScore, RankInfo, RankTime, BossKills, PlayerLevel, AccountBulletin: JSON }` |
| `S2C_SaveResult` | S→C | 保存结果 | `{ Ok: bool, Reason: string }` |
| `C2S_MigrateData` | C→S | 上传旧存档迁移 | `{ Data: JSON(payload + _migrationSource) }` |
| `S2C_MigrateResult` | S→C | 迁移结果 | `{ Ok: bool, Reason: string }` |
| `C2S_CreateChar` | C→S | 创建角色 | `{ Slot, Name, Data: JSON }` |
| `S2C_CharResult` | S→C | 角色操作结果 | `{ Ok: bool, Reason: string }` |
| `C2S_DeleteChar` | C→S | 删除角色 | `{ Slot: int }` |
| `C2S_GetRankList` | C→S | 查询排行榜 | `{ RankKey, Start, Count: int }` |
| `S2C_RankListData` | S→C | 排行榜数据 | `{ Data: JSON }` |

**注意**：所有复杂数据通过 `cjson.encode` 编码为 JSON 字符串，放入 VariantMap 的 String 字段传输。VariantMap 不支持直接传递 Lua table。

### 5.2 事件注册

`SaveProtocol.RegisterAll()` 在 client_main.lua 和 server_main.lua 中统一调用，一次注册所有远程事件。

---

## 六、文件结构（已实现）

```
scripts/
├── client_main.lua              # 客户端入口（C/S 模式）
├── server_main.lua              # 服务端入口（连接管理 + 所有 Handler）
├── main.lua                     # 单机模式入口（Phase 1 保留）
├── network/
│   ├── CloudStorage.lua         # 存储抽象层（单机/网络模式切换）
│   ├── SaveProtocol.lua         # C/S 通信事件定义 + 注册
│   └── SaveSystemNet.lua        # 客户端存档网络逻辑（FetchSlots/Load/Save/Migrate）
├── systems/
│   ├── SaveSystem.lua           # 存档系统（序列化/反序列化/版本迁移）
│   └── ...
└── ui/
    └── CharacterSelectScreen.lua  # 角色选择界面（4 槽位展示）
```

---

## 七、迁移流程（已实现）

### 7.1 Phase 1：本地导出（enabled=false）

**实现文件**：`SaveSystem.lua` → `ExportToLocalFile()`

每次存档成功后，将完整数据导出到本地文件：

```
save_export_1.json / save_export_2.json
```

导出内容：
```lua
{
    export_version = 1,
    slot = 1,
    timestamp = os.time(),
    save_data = coreData,          -- 核心存档
    save_bag1 = bag1Data,          -- 背包前半
    save_bag2 = bag2Data,          -- 背包后半
    slots_index = slotsIndex,      -- 槽位索引（完整保存时非nil）
}
```

**验证状态**：fb501 确认导出成功，fb532 确认 slotsIndex 包含在导出数据中（full branch）。

### 7.2 Phase 2：服务端迁移（enabled=true）

**触发流程**（`SaveSystemNet.lua` → `FetchSlots()`）：

```
客户端连接服务端 → C2S_FetchSlots
  ↓
服务端 HandleFetchSlots:
  ├─ 读取 slots_index + save_data_1~4 + rank_score_1~4
  ├─ 正向验证：索引有条目但数据丢失 → 标记 dataLost=true
  ├─ 反向验证（orphan self-healing）：数据存在但索引缺失 → 自动重建
  ├─ 排行榜自动修复（v2.1 新增）：
  │    遍历 slot 1~4，若 save_data 存在且 level > 5 但 rank_score == 0
  │    → 调用 ComputeRankFromSaveData 重建排行分数
  │    → fire-and-forget BatchSet 写回（不阻塞登录响应）
  ├─ 判断 needMigration（slots_index 为空或无有效槽位）
  └─ 返回 S2C_SlotsData { slotsIndex, needMigration }
  ↓
客户端收到响应:
  ├─ needMigration=false → 正常显示角色列表
  ├─ needMigration=true → 触发迁移链:
  │    ① MigrateToServer (clientCloud) — 仅理论路径，enabled=true 时 clientCloud=nil
  │    ② MigrateFromLocalFile (local_file):
  │         读取 save_export_1.json / save_export_2.json
  │         → 构建 payload { _migrationSource = "local_file" }
  │         → C2S_MigrateData → 服务端处理 → S2C_MigrateResult
  │         → 成功后删除本地文件
  │    ③ 重新 FetchSlots（获取迁移后结果）
  └─ needMigration=false 但移动端有本地文件 → 仍尝试 local_file 迁移
```

**排行榜自动修复（v2.1 新增）**：

Phase 1 的 `ExportToLocalFile` 不包含 rank 键（仅导出 save_data/bag1/bag2/slots_index），且 Phase 2 中 clientCloud=nil 导致 `MigrateToServer` 跳过。因此通过 `local_file` 迁移的玩家，serverCloud 中只有存档数据，没有排行分数。

HandleFetchSlots 在登录时自动检测并修复：
- 条件：`save_data_{slot}` 存在且 `player.level > 5`，但 `rank_score_{slot} == 0`
- 动作：调用 `ComputeRankFromSaveData(saveData)` 从存档计算排行分数，异步写回
- 特点：fire-and-forget，不阻塞 `S2C_SlotsData` 响应，玩家无感知

### 7.3 服务端迁移处理（HandleMigrateData）

```
收到 C2S_MigrateData:
  ↓
解析 payload → 识别 _migrationSource (clientCloud / local_file)
  ↓
安全备份：将完整 payload 写入 save_migrate_backup_{source}
  ↓
根据 source 确定 slotMap:
  ├─ clientCloud: { [1]=1, [2]=2 }
  └─ local_file:  { [1]=3, [2]=4 }
  ↓
遍历 payload 中的槽位数据:
  ├─ 目标槽位已有数据 → 跳过（幂等保护）
  └─ 目标槽位为空 → 写入三键数据 + 更新 slotsIndex
  ↓
合并 slotsIndex（payloadIndex → existingIndex，按 slotMap 重映射）
合并 account_bulletin
  ↓
BatchSet 写入 serverCloud
  ↓
返回 S2C_MigrateResult { ok=true }
```

**已知限制**：HandleMigrateData **不写入排行榜数据**。原因：
- `local_file` 迁移 payload（来自 Phase 1 ExportToLocalFile）不包含 rank 键
- `clientCloud` 迁移路径在 Phase 2 不可达（clientCloud=nil）

排行榜数据通过以下两条路径恢复：
1. **登录自动修复**：HandleFetchSlots 检测到存档存在但 rank_score == 0 → 自动重建（见 §7.2）
2. **首次保存**：HandleSaveGame 服务端权威计算 rankScore 并写入（`ComputeRankFromSaveData`）

### 7.4 slotsIndex 处理细节

**NormalizeSlotsIndex**（server_main.lua）：cjson.decode 产生的 JSON 数字 key 是字符串类型（`"1"`, `"2"` 等），此函数将其转换为 Lua 数字 key（`1`, `2` 等），确保 `slotsIndex.slots[slot]` 可通过数字索引访问。

**orphan self-healing**（HandleFetchSlots 反向验证）：
- 遍历 slot 1~4，如果 `slotsIndex.slots[slot]` 不存在但 `save_data_{slot}` 有数据
- 自动从 save_data 中提取摘要信息重建索引条目
- 写回 serverCloud 修复索引

**Lua `#` 运算符陷阱**（已修复）：
- `slotsIndex.slots` 是稀疏表（如 `{[3] = {...}}`）
- `#slotsIndex.slots` 返回 0（Lua `#` 只计连续整数键）
- 迭代必须用 `for slot = 1, MAX_SLOTS do` 或 `for k, v in pairs()`
- SaveSystemNet.lua 中两处日志已修复为 `pairs()` 计数

---

## 八、已验证的测试结果

### 8.1 Phase 1 验证（fb501, fb532）

| 测试项 | 结果 |
|--------|------|
| ExportToLocalFile 导出成功 | ✅ `Export OK: slot 1 (4163 bytes)`（fb501）|
| slotsIndex 包含在导出中 | ✅ full branch 导出含 updatedIndex（fb532 确认）|
| 本地文件跨版本持久化 | ✅ iPhone 13 Pro 验证通过 |

### 8.2 Phase 2 验证（fb533）

| 测试项 | 结果 |
|--------|------|
| 服务端连接 + 版本握手 | ✅ |
| FetchSlots → needMigration=true | ✅ |
| MigrateFromLocalFile 读取本地文件 | ✅ `read slot 1 (9828 bytes)` |
| C2S_MigrateData → 服务端处理 | ✅ `Migration successful!` |
| 重新 FetchSlots → needMigration=false | ✅ 服务端 slotsIndex 非空 |
| 加载 slot 3（迁移目标槽） | ✅ `Player data restored: Lv.25 zhuji_1` |
| 保存到 slot 3 | ✅ `Slot 3 saved! [3-key] [+checkpoint]` |
| 再次 FetchSlots | ✅ 数据持久化正确 |
| 排行榜写入 | ✅ 保存时自动写入 rank_score |

### 8.3 排行榜防作弊 + 自动修复验证（v2.1）

| 测试项 | 结果 |
|--------|------|
| 服务端权威计算 rankScore | ✅ HandleSaveGame 调用 ComputeRankFromSaveData，忽略客户端 rankData |
| P1 存档校验（非法 realm） | ✅ 返回 invalid_realm，拒绝写入排行 |
| P1 存档校验（level 越界） | ✅ 自动 cap 到 maxLevel |
| 登录自动修复（rank_score == 0） | ✅ HandleFetchSlots 检测缺失排行并重建 |
| 排行榜数据恢复（4 账号→全量） | ✅ 老玩家登录后排行自动修复 |

### 8.4 已修复的 Bug

| Bug | 根因 | 修复 |
|-----|------|------|
| `FetchSlots ok: 0 slots` | Lua `#` 对稀疏表返回 0 | `pairs()` 计数替换 `#` |
| Phase 2 重建丢失多人配置 | 构建时未传完整 multiplayer 参数 | 补全 background_match + match_info |
| PC 预览 WebSocket 报错 | 多人游戏无法在 PC 预览运行 | 预期行为，需手机扫码测试 |
| 排行榜仅 4 账号数据 | ExportToLocalFile 不含 rank 键 + clientCloud=nil 跳过迁移 → 仅迁移后保存过的玩家有排行 | HandleFetchSlots 登录时自动修复 + HandleSaveGame 服务端权威计算 |

---

## 九、构建配置（已确认）

### 9.1 multiplayer 配置

```json
{
  "@runtime": {
    "multiplayer": {
      "enabled": true,
      "max_players": 2,
      "background_match": true,
      "match_info": {
        "desc_name": "free_match_with_ai",
        "player_number": 1,
        "match_timeout": 5,
        "immediately_start": true
      }
    }
  }
}
```

**关键配置说明**：
- `max_players: 2` — 最少配置，实际单人使用
- `background_match: true` — 游戏脚本立即加载，匹配后台运行
- `immediately_start: true` — 不等待满员即开始
- `free_match_with_ai` + `player_number: 1` — 超时自动 AI 填充，1人即可开始

### 9.2 项目入口

```json
{
  "entry": "client_main.lua",
  "entry@client": "client_main.lua",
  "entry@server": "server_main.lua"
}
```

---

## 十、回退方案

如上线后发现严重问题：

1. `settings.json` → `multiplayer.enabled = false`
2. `project.json` → `entry = "main.lua"`，删除 `entry@client` / `entry@server`
3. 重新构建 + 发布

clientScore 旧数据未删除，玩家无损恢复到迁移前状态。

**回退影响**：迁移后在 serverCloud 中新产生的进度会丢失。

### 10.1 单机迁移二维码（已验证 2026-03-27）

**场景**：个别玩家错过迁移窗口，需要临时切单机版保存存档，再切回多人版完成迁移。

**操作步骤**（严格按顺序执行）：

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | `project.json` 删除 `entry@client` 和 `entry@server` | 只保留 `entry: "main.lua"` |
| 2 | 构建：`entry="main.lua"`, `multiplayer.enabled=false` | 单机模式 |
| 3 | 生成测试二维码 | 给玩家扫码 |
| 4 | **等待玩家完成存档保存** | 不要提前恢复！ |
| 5 | `project.json` 恢复 `entry@client: "client_main.lua"` + `entry@server: "server_main.lua"` | 恢复多人入口 |
| 6 | 构建：附录 B 全量多人参数 | 恢复多人模式 |

**关键注意**：
- 测试二维码指向**最新构建**，步骤 6 构建后会覆盖单机版本
- 步骤 4 必须等玩家确认完成后再执行步骤 5-6
- `multiplayer.enabled=false` 时 `clientCloud` 可用，玩家可正常存档到 clientCloud
- 玩家切回多人版后，Phase 2 迁移流程会自动从 clientCloud/local_file 拉取存档

---

## 十一、上线计划

### 11.1 Phase 1 版本（当前线上）

Phase 1 导出版本已部署到 TapTap，玩家每次存档自动生成 `save_export_X.json`。

### 11.2 Phase 2 上线步骤（计划：明天晚上）

| 步骤 | 操作 | 验证 |
|------|------|------|
| 1 | 确认 Phase 1 已运行足够时间（活跃玩家至少存档一次） | 检查运行天数 |
| 2 | 构建 Phase 2（multiplayer 全量参数） | build 成功 |
| 3 | 生成测试二维码 | QR 码可扫 |
| 4 | 测试账号验证（迁移 → 加载 → 保存 → 重进） | 全流程通过 |
| 5 | 发布到 TapTap（强更） | 发布成功 |
| 6 | 监控：迁移成功率、数据完整性、排行榜 | >99% 成功率 |

### 11.3 上线后监控

| 时间点 | 检查项 |
|--------|--------|
| +5min | 服务端存活，连接数 > 0 |
| +30min | 迁移成功/失败日志统计 |
| +1h | 排行榜数据非空、排序正确 |
| +2h | 自动/手动存档正常 |
| +24h | 内存、连接数、错误日志稳定 |

---

## 十二、PC 玩家处理

PC (WASM) 本地文件不持久化，无法通过 local_file 迁移。

**流程**：
```
PC 玩家打开 Phase 2 → 服务端无数据 → 无本地文件
  ↓ 显示提示：请先在手机上登录一次以完成迁移
  ↓
玩家手机端完成迁移 → serverCloud 有数据
  ↓
PC 重新打开 → FetchSlots → 有数据 → 正常进入 ✅
```

**纯 PC 玩家**（从未手机登录）：提供"新建角色 + 补偿礼包"兜底。

---

## 十三、后续优化路线（未来版本，不在本次迁移范围内）

以下优化 **待迁移稳定 2 周+** 后独立版本执行：

| 优化项 | 说明 | 版本 |
|--------|------|------|
| 三键合并为单键 | save_data + save_bag1 + save_bag2 → save_X | v10+ |
| 装备去精简序列化 | 废弃 compact 分支，统一全字段 | 同上 |
| 删除 fillEquipFields | 不再需要反查逻辑 | 同上 |
| 备份体系简化 | 每槽 14 key → 4 key | 同上 |
| 删除冗余 key 函数 | GetBag1Key 等 12 个函数 | 同上 |

---

## 十四、技术备忘录

### 14.1 VariantMap 传输约束

`SendRemoteEvent` 的 `VariantMap` 只支持基础类型（Int/Float/String/Vector3 等），不支持 Lua table。所有复杂数据必须 `cjson.encode()` 为字符串。

### 14.2 ClientIdentity vs ClientConnected

- `ClientConnected`：TCP 连接建立，`connection.identity` **为空**
- `ClientIdentity`：身份验证完成，`connection.identity` 可用，`userId` 可获取

### 14.3 Scene 关联三步时序

```
1. 客户端设 serverConnection.scene = netScene_
2. 客户端发送 ClientReady / C2S_VersionHandshake
3. 服务端收到后设 connection.scene = scene_
```

### 14.4 远程事件必须注册

所有远程事件在接收端必须先 `RegisterRemoteEvent()`，否则被静默丢弃。`SaveProtocol.RegisterAll()` 统一处理。

### 14.5 background_match 模式

`background_match: true` 时游戏脚本立即加载执行，匹配在后台运行。匹配成功后触发 `ServerReady` 事件。client_main.lua 通过订阅 `ServerReady` 获取 `serverConnection`。

---

---

## 十五、P0 存档健壮性热修复（2026-03-27）

> **背景**：Phase 2 上线后，网络模式下存档存在多种静默失败路径，玩家无感知。
> **影响**：最坏情况下 2 小时内 ~48 次存档静默失败，进度丢失。

### 15.1 根因分析

| # | 根因 | 影响 |
|---|------|------|
| 1 | `SendRemoteEvent` 成功但服务端响应丢失，`saving` 锁 30s 无超时检测 | 存档卡死 30s → 等 120s 自动存档 → 再卡死 |
| 2 | 30s 超时解锁只做 `saving=false`，不递增 `_consecutiveFailures`、不设 `_retryTimer` | 无退避重试，系统认为"没出过错" |
| 3 | `serverConn` 为 nil 时 `CloudStorage.BatchSet:Save()` 打日志+调 `error` 回调，但 `SaveSystem.Save()` 入口未预检 | 白做序列化后才发现无连接 |
| 4 | 存档失败仅打 console 日志，无 UI 提示 | 玩家完全无感知 |

### 15.2 修复方案（P0 优先级，~30 行变更）

| 方案 | 文件 | 变更 |
|------|------|------|
| **方案 1** | `SaveSystem.lua` Update() | 新增 15s 客户端超时检测：`_saveTimeoutActive` + `_saveTimeoutElapsed`，超时后解锁 `saving`、递增失败计数、触发退避重试 |
| **方案 1 补充** | `SaveSystem.lua` Save() + DoSave() 4 个回调 | Save() 中激活超时（仅网络模式）；ok/error 回调中关闭超时 |
| **方案 4** | `SaveSystem.lua` Save() 30s 解锁处 | 解锁时递增 `_consecutiveFailures` + 设 `_retryTimer` + emit `save_warning` + `return`（不再 fall-through） |
| **方案 6** | `SaveSystem.lua` Save() 序列化前 | `IsNetworkMode() && !serverConn` → 快速失败，避免白做序列化 |
| **方案 2** | `main.lua` | 新增 `save_warning` 事件监听（黄色浮字"存档同步中，请保持网络连接..."）+ `save_warning_clear` 日志 |

### 15.3 故障恢复时间线改善

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| 首次检测失败 | 30s（锁死超时） | 15s（响应超时） |
| 首次重试 | 120s（等自动存档） | 25s（15s 超时 + 10s 退避） |
| 玩家感知 | 无（静默失败） | ≥2 次失败时黄色浮字提示 |
| 无连接检测 | 序列化后才发现 | 序列化前快速失败 |

### 15.4 验证关键字

| 日志关键字 | 含义 |
|-----------|------|
| `Save TIMEOUT (no response in 15s)` | 方案 1 生效：15s 无响应自动重试 |
| `30s stuck unlock:` | 方案 4 生效：30s 解锁计入失败 |
| `Save SKIPPED: no serverConn` | 方案 6 生效：无连接快速失败 |
| `save_warning:` | 方案 2 生效：UI 提示已展示 |
| `save_warning_clear` | 存档恢复正常 |

### 15.5 延后方案

| 方案 | 原因 | 计划 |
|------|------|------|
| 方案 3（checkpoint 网络模式支持） | 需新增 C2S/S2C 协议 | Phase F |
| 方案 5（断网本地缓存） | WASM 文件易失，恢复后可能覆盖新数据 | 不实施 |

---

---

## 十六、C2S 防抖永久锁死修复（2026-03-29）

> **背景**：所有通过布尔标志实现 C2S 防抖的系统，当服务端 S2C 响应丢失时（典型根因：服务端 handler 的 `if not userId then return end` silent return），客户端防抖标志永远为 `true`，功能永久锁死。

### 16.1 根因

服务端多个 handler 开头有以下模式：

```lua
function HandleXxx(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end  -- ← silent return，不发 S2C
```

`userId` 为空的典型场景：服务端重启/重连，`connections_` 映射表丢失旧连接的 userId。此时客户端已发 C2S，服务端静默丢弃，S2C 永远不会到达。

客户端使用布尔标志防重复点击（如 `_accepting = true`），只在 S2C 回调中重置为 `false`。S2C 丢失 → 永远锁死。

### 16.2 排查结果

| 系统 | 文件 | 防抖标志 | 有 silent return | 有 UI 逃生路径 | 永久锁死 |
|------|------|---------|-----------------|---------------|---------|
| 封魔日常 | `SealDemonSystem.lua` | `_accepting` / `_reporting` (bool) | 是 | 否 | **是** |
| 试炼供奉 | `TrialOfferingUI.lua` | `claiming_` (bool) | 是 | 否（Show/Hide 均不重置） | **是** |
| 悟道树 | `DaoTreeUI.lua` | `waitingServer_` (bool) | 是 | 是（Show/Hide 均重置） | 否 |

### 16.3 修复方案：时间戳 + 超时自动解锁

将布尔标志替换为 `os.clock()` 时间戳，10 秒后自动解锁。懒检查，无需 Update 轮询：

```lua
local C2S_TIMEOUT = 10  -- 秒

local function _isThrottled(startTime)
    return startTime > 0 and (os.clock() - startTime) < C2S_TIMEOUT
end

-- 发送前：
if _isThrottled(self._acceptingAt) then return end
self._acceptingAt = os.clock()

-- S2C 回调：
self._acceptingAt = 0
```

### 16.4 修改清单

| 文件 | 旧标志 | 新标志 | 修改点数 |
|------|--------|--------|---------|
| `SealDemonSystem.lua` | `_accepting` (bool) | `_acceptingAt` (number) | 6 处 |
| `SealDemonSystem.lua` | `_reporting` (bool) | `_reportingAt` (number) | 4 处 |
| `TrialOfferingUI.lua` | `claiming_` (bool) | `claimingAt_` (number) | 4 处 |

DaoTreeUI 无需修改（Show/Hide 天然重置 `waitingServer_`，不存在永久锁死）。

### 16.5 验证

- 构建通过：0 errors / 0 warnings
- 用户报告症状（封魔"正在处理中，请稍候"卡死）可通过等待 10 秒后重新点击恢复

---

## 十七、日常 Quota 按角色隔离（2026-03-29）

> **背景**：所有日常系统的 Quota key 为账号级（`userId` + 固定 key），多角色共享日常次数。角色 A 完成日常后，角色 B 无法再做。

### 17.1 根因

`serverCloud.quota` 的唯一性维度是 `(userId, key)`。所有 handler 构建 key 时未拼接角色 slot：

```lua
-- 旧（账号级，所有角色共享）
serverCloud.quota:Add(userId, "seal_demon_daily", 1, 1, "day", ...)
serverCloud.quota:Add(userId, "dao_tree_daily", 1, 3, "day", ...)
serverCloud.quota:Add(userId, "trial_daily_offering", 1, 1, "day", ...)
```

### 17.2 修复方案

所有日常 Quota key 拼接 `"_s" .. slot` 后缀，按角色槽位隔离：

| 旧 Key | 新 Key | 说明 |
|--------|--------|------|
| `"seal_demon_daily"` | `"seal_demon_daily_s" .. slot` | 封魔每日 |
| `"dao_tree_" .. treeId` | `"dao_tree_" .. treeId .. "_s" .. slot` | 悟道树单树 |
| `"dao_tree_daily"` | `"dao_tree_daily_s" .. slot` | 悟道树每日总次数 |
| `"trial_daily_offering"` | `"trial_daily_offering_s" .. slot` | 试炼供奉每日 |

### 17.3 修改清单（server_main.lua）

| Handler | 修改点 | slot 来源 |
|---------|--------|----------|
| `HandleDaoTreeStart` | 2 处 key 构建 | `connSlots_[connKey] or 1` |
| `HandleDaoTreeComplete` | 2 处 key 构建 | `connSlots_[connKey] or 1` |
| `HandleDaoTreeQuery` | 2 处 key 构建 | `connSlots_[connKey] or 1` |
| `HandleSealDemonAccept` | 1 处 key 构建 | `connSlots_[connKey] or 1` |
| `HandleTrialClaimDaily` | 2 处 key 构建 | `connSlots_[connKey] or 1` |

> **注**: 初始版本（v2.4）使用 `connections_[connKey].slot` 获取 slot，但这是一个 BUG —— `connections_[connKey]` 是 C++ Connection userdata，不是 Lua table，`.slot` 永远为 nil。已在 v2.5 中修复为 `connSlots_`（见 §18）。

**GM 重置（HandleGMResetDaily）**：暂不修改，仅测试用途。后续按需改为带 slot 的 key。

### 17.4 兼容性

- 旧 Quota key（无 `_s` 后缀）自然废弃，不影响新逻辑
- 上线后所有角色的日常次数从零开始（因 key 名改变），等同于一次免费的日常重置
- 无需数据迁移

### 17.5 验证

- 构建通过：0 errors / 0 warnings

## 十八、connSlots_ 服务端权威 slot + 数据分层审计（2026-03-29）

> **背景**：§17 的 Quota key 修复中使用 `connections_[connKey].slot` 获取角色 slot，但 `connections_[connKey]` 是 C++ Connection userdata，不是 Lua table，`.slot` 属性不存在，返回 nil。`nil or 1` 导致所有角色永远使用 slot=1。

### 18.1 根因

```lua
-- connections_ 表结构
connections_[connKey] = connection  -- C++ Connection userdata，不是 Lua table

-- 错误用法（v2.4）
local slot = connections_[connKey] and connections_[connKey].slot or 1
-- connections_[connKey] = Connection userdata (truthy)
-- connections_[connKey].slot = nil (C++ 对象没有 .slot 属性)
-- nil or 1 = 1  ← 永远是 1
```

### 18.2 修复方案

新增 `connSlots_` 表，在加载/保存存档时记录当前连接的活跃角色 slot：

```lua
--- connKey -> slot (当前加载的角色槽位)
local connSlots_ = {}
```

**写入时机**（2 处）：
| 事件 | 代码 |
|------|------|
| `HandleLoadGame` | `connSlots_[connKey] = slot` |
| `HandleSaveGame` | `connSlots_[connKey] = slot`（冗余保护） |

**清理时机**（1 处）：
| 事件 | 代码 |
|------|------|
| `HandleClientDisconnected` | `connSlots_[connKey] = nil` |

**读取替换**（6 处）：

所有 `connections_[connKey] and connections_[connKey].slot or 1` → `connSlots_[connKey] or 1`

| Handler | 行号 |
|---------|------|
| `HandleDaoTreeStart` | ~1496 |
| `HandleDaoTreeComplete` | ~1596（同时移除客户端 `eventData["slot"]` 依赖） |
| `HandleDaoTreeQuery` | ~1788 |
| `HandleSealDemonAccept` | ~1882 |
| `HandleSealDemonBossKilled` | ~2061 |
| `HandleTrialClaimDaily` | ~2205 |

### 18.3 DaoTreeComplete slot 来源统一

`HandleDaoTreeComplete` 原先从 `eventData["slot"]:GetInt()` 获取 slot（客户端传入），与其他 handler 不一致。改为统一使用 `connSlots_[connKey] or 1`（服务端权威值）。

**安全提升**：避免恶意客户端篡改 slot 导致 Quota 跨角色消耗。

### 18.4 serverCloud 数据分层审计（角色级 vs 账号级）

| Key 模式 | 级别 | 说明 | 状态 |
|----------|------|------|------|
| `slots_index` | 账号级 | 角色槽位索引 | ✅ 正确 |
| `account_bulletin` | 账号级 | 已读公告状态 | ✅ 正确 |
| `trial_info` | 账号级 | 试炼排行榜（取全账号最佳角色） | ✅ 正确 |
| `save_data_{slot}` | 角色级 | 核心存档（含主线 quests） | ✅ 正确 |
| `save_bag1_{slot}` | 角色级 | 背包 1 | ✅ 正确 |
| `save_bag2_{slot}` | 角色级 | 背包 2 | ✅ 正确 |
| `rank_score_{slot}` | 角色级 | 排行榜分数 | ✅ 正确 |
| `rank2_info_{slot}` | 角色级 | 排行榜附加信息 | ✅ 正确 |
| `dao_tree_{id}_s{slot}` | 角色级 | 悟道树单树每日配额 | ✅ §17 修复 |
| `dao_tree_daily_s{slot}` | 角色级 | 悟道树每日总配额 | ✅ §17 修复 |
| `seal_demon_daily_s{slot}` | 角色级 | 封魔每日配额 | ✅ §17 修复 |
| `trial_daily_offering_s{slot}` | 角色级 | 试炼供奉每日配额 | ✅ §17 修复 |

**主线任务**：存储在 `save_data_{slot}.quests`（QuestSystem.Serialize/Deserialize），角色级，无耦合。

### 18.7 属性丹药 + 区域加成 角色级隔离审计（2026-03-29）

**结论：全部角色级，无问题。**

**属性丹药**（均存于 `save_data_{slot}` 内部，无独立 serverCloud 键）：

| 丹药 | 运行时变量 | 序列化路径 | 隔离级别 |
|------|-----------|-----------|---------|
| 虎骨丹 | `AlchemyUI.tigerPillCount_` | `coreData.shop.tigerPillCount` | 角色级 |
| 灵蛇丹 | `AlchemyUI.snakePillCount_` | `coreData.shop.snakePillCount` | 角色级 |
| 金刚丹 | `AlchemyUI.diamondPillCount_` | `coreData.shop.diamondPillCount` | 角色级 |
| 千锤百炼丹 | `AlchemyUI.temperingPillEaten_` | `coreData.shop.temperingPillEaten` | 角色级 |
| 血煞丹 | `ChallengeSystem.xueshaDanCount` | `coreData.challenges.xueshaDanCount` | 角色级 |
| 浩气丹 | `ChallengeSystem.haoqiDanCount` | `coreData.challenges.haoqiDanCount` | 角色级 |
| 体魄丹 | `player.pillPhysique` | `coreData.player.pillPhysique` | 角色级 |
| 根骨(千锤) | `player.pillConstitution` | `coreData.player.pillConstitution` | 角色级 |

**区域加成**（均存于 `save_data_{slot}` 内部或纯运行时不持久化）：

| 系统 | 运行时变量 | 序列化路径 | 隔离级别 |
|------|-----------|-----------|---------|
| 海神柱属性加成 | `player.seaPillarDef/Atk/MaxHp/HpRegen` | `coreData.player` + `coreData.seaPillar` | 角色级 |
| 福源果 | `player.fruitFortune` + `FortuneFruitSystem.collected` | `coreData.player` + `coreData.fortuneFruits` | 角色级 |
| BuffZone 战斗区域 | `CombatSystem.activeBuffs/activeZones/activeDots` | 不持久化（纯运行时） | 无 |
| 章节 | `GameState.currentChapter` | `coreData.player.chapter` | 角色级 |
| ActiveZoneData | 运行时代理 | 不持久化 | 无 |

**关键确认**：FortuneFruitSystem、SeaPillarSystem、ChallengeSystem、AlchemyUI 均无独立 serverCloud 调用，所有数据通过 SaveSystem 统一存入 `save_data_{slot}`。

### 18.5 线上玩家影响

- Quota key 从 `_s1`（所有角色 fallback）变为 `_s{实际slot}`
- **slot=1 玩家**：key 不变（`_s1` → `_s1`），无影响
- **slot=2/3/4 玩家**：key 变化（`_s1` → `_s2`/`_s3`/`_s4`），等于一次免费日常重置
- **风险等级：极低**，最坏情况是多做一次日常

### 18.6 验证

- 构建通过：0 errors / 0 warnings
- `connections_[connKey].slot` 模式已全部清除（grep 验证）
- `connSlots_` 使用：声明 1 + 清理 1 + 写入 2 + 读取 6 = 10 处

---

*文档版本: v2.6*
*创建日期: 2026-03-16*
*最后更新: 2026-03-29*
*基于: 实际代码实现（server_main.lua / client_main.lua / SaveSystemNet.lua / CloudStorage.lua / SaveSystem.lua）*

**版本历史**：
| 版本 | 变更 |
|------|------|
| v1.0 | 初始迁移方案设计 |
| v1.1 | 技术评审修正（VariantMap/ClientIdentity/Scene 时序/事件注册） |
| v1.2 | 本地文件中转方案验证 + PC 处理 |
| **v2.0** | **基于实际实现全面重写**：Phase 2 已实现并测试通过；4 槽位设计（1-2 正常 + 3-4 恢复）；SlotMap 映射；orphan self-healing；CURRENT_SAVE_VERSION 保持 v9；移除所有伪代码替换为实际实现描述；新增测试验证结果；新增构建配置记录；移除未实现的合并优化（延后到独立版本） |
| **v2.1** | **排行榜服务端权威计算 + 登录自动修复**：§4.1 rank 键改为服务端权威计算；§7.2 HandleFetchSlots 新增 rank_score 读取和自动修复流程；§7.3 HandleMigrateData 补充排行数据缺失说明；§8.3 新增防作弊验证结果；§8.4 记录排行榜 4 账号 Bug 修复 |
| **v2.2** | **P0 存档健壮性热修复**：§15 新增 4 项根因分析 + 5 项修复方案（方案 1/2/4/6）；故障恢复时间 150s→25s；新增玩家可感知的失败提示；风险 R16-R19 登记 |
| **v2.3** | **C2S 防抖永久锁死修复**：§16 新增 3 个系统排查（封魔/试炼供奉/悟道树）；封魔 + 试炼供奉从布尔标志改为时间戳超时（10s 自动解锁）；悟道树天然安全无需修改 |
| **v2.4** | **日常 Quota 按角色隔离**：§17 所有日常 Quota key 拼接 `_s{slot}` 后缀，多角色日常独立；涉及 5 个 handler、9 处修改；GM 重置暂不修改 |
| **v2.5** | **connSlots_ 服务端权威 slot + 数据分层审计**：§18 发现 `connections_[connKey].slot` 永远为 nil（C++ userdata 无 .slot 属性）→ 新增 `connSlots_` 表；`HandleDaoTreeComplete` 改为服务端权威 slot（不信任客户端）；完整数据分层审计（12 个 key，3 账号级 + 9 角色级，全部正确）；主线任务确认角色级 |
| **v2.6** | **属性丹药 + 区域加成角色级隔离审计**：§18.7 审计 8 种丹药（虎骨/灵蛇/金刚/千锤/血煞/浩气/体魄/根骨）+ 5 种区域加成（海神柱/福源果/BuffZone/章节/ActiveZone），全部确认为角色级或纯运行时；无独立 serverCloud 键；无需修复 |
