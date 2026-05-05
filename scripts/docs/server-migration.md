# 存档迁移方案：clientCloud → serverCloud

> 人狗仙途 - 服务器模式迁移技术文档

## 1. 背景

游戏原本使用 `multiplayer.enabled=false` + `clientCloud`（clientScore）存储玩家存档。
现需迁移到 `multiplayer.enabled=true` + `serverCloud` 模式，以支持服务端逻辑。

### 核心约束

| 条件 | `enabled=false` | `enabled=true` |
|------|-----------------|-----------------|
| clientCloud | 可用 | **nil（不可用）** |
| serverCloud | 不可用 | 可用 |
| 本地文件 | 可用 | 可用 |

**clientCloud 和 serverCloud 互斥**，无法在同一版本中同时访问。
这是引擎 `multiplayer.enabled` 的设计决定：该字段同时控制 clientCloud 注入和服务器部署。

## 2. 迁移策略：本地文件中转（两阶段发布）

```
Phase 1 (enabled=false)         Phase 2 (enabled=true)
┌─────────────────────┐        ┌──────────────────────────┐
│ 每次存档成功后       │        │ 启动时检查本地文件        │
│ clientCloud 数据     │        │                          │
│   ↓ cjson.encode     │        │ 读取 save_export_X.json  │
│ 写入本地文件         │  ───►  │   ↓ cjson.decode         │
│ save_export_X.json   │  升级  │ 写入 serverCloud          │
│                      │        │   ↓ 成功后                │
│                      │        │ 删除本地文件              │
└─────────────────────┘        └──────────────────────────┘
```

### 已验证（2026-03-24，iPhone 13 Pro）

- fb499：`enabled=false` 写入本地文件成功
- fb500：`enabled=true` 读取到 fb499 写入的文件，**本地文件跨版本持久化已确认**
- fb503：`serverCloud:Get(uid, "slots_index")` 返回 nil，**clientCloud 和 serverCloud 完全独立确认**
- fb501：`[SaveSystem] Export OK: slot 1 (4163 bytes)`，**Phase 1 导出功能验证通过**

### PC (WASM) 平台限制

PC 端 File API 写入内存文件系统，关闭后丢失。**PC 玩家无法通过本地文件迁移**。

**处理方案**：Phase 2 检测到无本地文件 + serverCloud 无数据时，显示提示：
> "存档迁移进行中，请先在手机上登录一次以完成迁移。迁移完成后，即可在 PC 端正常游玩。"

**原理**：serverCloud 是服务端存储，与客户端平台无关。手机完成迁移后，PC 连接服务端即可读到同一份数据。

## 3. Phase 1 实现（当前版本）

### 修改文件

`scripts/systems/SaveSystem.lua` — 唯一修改

### 新增函数

```lua
function SaveSystem.ExportToLocalFile(slot, coreData, bag1Data, bag2Data, slotsIndex)
```

- 将 3 key 存档数据（coreData / bag1Data / bag2Data）+ slotsIndex 序列化为 JSON
- 写入本地文件 `save_export_{slot}.json`
- pcall 保护，失败不影响主存档流程

### 调用位置

DoSave 函数的两个成功回调中（`EventBus.Emit("game_saved")` 之后）：

1. **主路径**（有 slots_index）：传入 `updatedIndex`
2. **降级路径**（无 slots_index）：传入 `nil`

### 本地文件格式

文件名：`save_export_1.json` / `save_export_2.json`

```json
{
    "export_version": 1,
    "export_time": 1774285780,
    "slot": 1,
    "save_data": { ... },
    "save_bag1": { ... },
    "save_bag2": { ... },
    "slots_index": { ... }
}
```

字段对应关系：

| 本地文件字段 | clientCloud 键名 | 内容 |
|-------------|-----------------|------|
| save_data | save_data_X | 核心数据 + 装备（~4KB） |
| save_bag1 | save_bag1_X | 背包 1-30 格（~6KB） |
| save_bag2 | save_bag2_X | 背包 31-60 格（~6KB） |
| slots_index | slots_index | 槽位元数据 |

### 构建配置

```
entry: main.lua
multiplayer.enabled: false
```

## 4. Phase 2 实现（待开发）

### 核心逻辑

在 `client_main.lua` 启动时（CloudStorage 网络模式初始化之前）：

1. 检查 `save_export_1.json` 和 `save_export_2.json` 是否存在
2. 如果存在：
   - 读取并 cjson.decode
   - 通过 serverCloud 写入对应键（save_data_X / save_bag1_X / save_bag2_X / slots_index）
   - 写入成功后删除本地文件
   - 标记迁移完成
3. 如果不存在：正常启动（新用户或已迁移用户）

### 构建配置

```
entry_client: client_main.lua
entry_server: server_main.lua
multiplayer.enabled: true
```

### 关键注意事项

- serverCloud 单 key 上限 1MB（远大于 clientCloud 的 10KB），无需担心大小问题
- 迁移写入应在游戏主循环之前完成，避免空存档覆盖
- 必须处理迁移中断（写入部分成功）：用原子标记 or 全量重试

## 5. 发布计划

```
步骤 1：发布 Phase 1 版本（enabled=false, entry=main.lua）
         ↓ 保持 2-4 周，确保活跃玩家都运行过至少一次
步骤 2：开发并测试 Phase 2 代码
步骤 3：发布 Phase 2 版本（enabled=true, entry_client=client_main.lua）
         ↓ 玩家首次启动时自动完成迁移
步骤 4：观察 1-2 周，确认无异常
步骤 5：移除 Phase 1 导出代码（可选，保留也无害）
```

## 6. 风险评估

| 风险 | 概率 | 影响 | 应对 |
|------|------|------|------|
| 玩家跳过 Phase 1 直接升级 Phase 2 | 低 | 存档丢失 | Phase 2 可兜底：从 clientCloud 备份恢复（需要临时切回 enabled=false 读取） |
| 玩家卸载重装后升级 | 低 | 本地文件丢失 | 同上，clientCloud 数据仍在服务端 |
| 导出文件损坏 | 极低 | 迁移失败 | pcall 解码保护，失败保留文件等下次重试 |
| Phase 1 期间存档正常丢失 | 与现有版本相同 | 无额外风险 | 导出逻辑不影响现有存档流程 |

## 7. 迁移原则

1. **迁移 ≠ 优化**：保持完全相同的数据结构，不改版本号（CURRENT_SAVE_VERSION = 9）
2. **零侵入**：导出失败不影响游戏正常运行
3. **每次覆盖**：本地文件始终是最新存档，不存在过期问题
4. **玩家无感**：整个迁移过程对玩家透明，无需任何操作
