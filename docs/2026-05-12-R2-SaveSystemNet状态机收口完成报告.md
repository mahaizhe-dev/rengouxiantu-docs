# R2 SaveSystemNet 状态机收口 — 完成报告

任务ID: R2
本次结论: **完成**
日期: 2026-05-12

---

## 1. Git 交付信息

- commit SHA: f469c8a
- parent SHA: 7eaf252
- 分支: main

---

## 2. 状态机盘点表（步骤 1 交付物）

| 状态对象 | 创建点 | 清理点 | 成功回调 | 失败回调 | 重入行为（旧） | 晚到行为（旧） |
|----------|--------|--------|----------|----------|----------------|----------------|
| `_pendingFetchSlots` | `FetchSlots` 发送 C2S 后赋值 | `HandleSlotsData` 开头清 nil | `HandleSlotsData` ok=true 分支 | `HandleSlotsData` ok=false 分支 | 静默覆盖旧 callback | **无 nil 检查** — 晚到响应直接执行当前 callback（可能误触） |
| `_pendingLoad` | `Load` 发送 C2S 后赋值 | `HandleLoadResult` 开头清 nil | `HandleLoadResult` → `ProcessLoadedData` | `HandleLoadResult` ok=false 分支 | 静默覆盖旧 callback | 有 nil 检查，晚到时 return（安全但无日志） |
| `_pendingChar` | `CreateCharacter` / `DeleteCharacter` 赋值 | `HandleCharResult` 开头清 nil | `HandleCharResult` ok=true 分支 | `HandleCharResult` ok=false 分支 | 静默覆盖（create/delete 共享变量） | 有 nil 检查，晚到时 return（安全但无日志） |
| `_pendingMigrate` | `MigrateToServer` / `MigrateFromLocalFile` 赋值 | `HandleMigrateResult` 开头清 nil / BatchGet error 分支 | `HandleMigrateResult` ok=true / BatchGet no_data 分支 | `HandleMigrateResult` ok=false / BatchGet error 分支 | 静默覆盖旧 callback | **无 nil 检查** — 晚到响应直接执行 callback（可能误触） |
| `_queuedFetchSlots` | `FetchSlots` 无连接 + 非 `_networkReady` 时赋值 | `OnNetworkReady` 消费 / `ClearQueue` 清理 | `OnNetworkReady` 中重新调用 `FetchSlots` | `ClearQueue` 中通知超时 | 静默覆盖排队 callback | N/A（队列机制，无 S2C 响应） |

**发现的两个 bug**：
1. `HandleSlotsData` 无 nil 检查 — 晚到响应可能误触当前不相关的 callback
2. `HandleMigrateResult` 无 nil 检查 — 同上

---

## 3. 语义决策

**选择: `single-flight reject`**

理由：
1. 当前协议无 `requestId`，无法取消已发出的请求 → `cancel-old` 需要客户端自行"忽略旧响应"，但在无 requestId 下无法区分新旧响应
2. `reject` 语义更简单安全：pending 存在时直接拒绝新请求，新回调收到稳定错误原因
3. 正常 UI 流程不允许同一动作重入（按钮在 pending 期间应禁用），所以 reject 是合理的防御性约束

**统一程度：4 类动作（fetchSlots / load / char / migrate）全部使用 single-flight reject，语义完全一致。**

---

## 4. 实际修改文件

| 文件 | 变更内容 |
|------|----------|
| `scripts/network/SaveSystemNet.lua` | 核心重构：替换 4 个独立 pending 变量为统一 `_pending` 表 + 4 个辅助函数（`beginPending`/`resolvePending`/`rejectPending`/`hasPending`）；所有请求函数和 S2C handler 统一走新接口；新增 `_getPendingSnapshot()` 和 `_resetForTest()` 测试辅助 |
| `scripts/tests/test_save_system_net_state_machine.lua` | 新增：12 组测试用例（34 个断言），覆盖 4 类动作的 reject/晚到/正常流程/队列/网络就绪 |
| `scripts/tests/TestRegistry.lua` | 新增 `save_system_net_state_machine` blocking gate 条目 |

**未修改文件（符合约束）**：
- `scripts/network/SaveProtocol.lua` — 未改
- `scripts/server_main.lua` — 未改
- `scripts/systems/save/*` — 未改
- `scripts/config/FeatureFlags.lua` — 未改
- `scripts/network/MigrationPolicy.lua` — 未改
- `scripts/network/CloudStorage.lua` — 未改（评估后确认不需修改）

---

## 5. 测试

### 测试命令

```bash
python3 scripts/tests/_run_via_lupa.py          # blocking gate
python3 scripts/tests/_run_via_lupa.py --all     # 全量套件
```

### Blocking gate 原始输出（R2 新增测试部分）

```
[TEST] save_system_net_state_machine

[test_save_system_net_state_machine] === R2 状态机收口测试 ===

[INFO][SaveSystemNet] S2C handlers subscribed
[INFO][SaveSystemNet] C2S_FetchSlots sent
  ✓ T1a: first FetchSlots sends C2S event
[WARN][SaveSystemNet] REJECT: fetchSlots already pending, refusing new request
  ✓ T1b: second FetchSlots does NOT send another C2S event
  ✓ T1c: rejected callback gets nil result
  ✓ T1d: rejected callback gets error message
  ✓ T1e: first callback not yet called
  ✓ T1f: first callback not yet called
[WARN][SaveSystemNet] LATE-RESPONSE: fetchSlots response arrived but no matching pending (ignored)
  ✓ T2: late SlotsData response ignored, no pending
[INFO][SaveSystemNet] C2S_LoadGame sent: slot=1
  ✓ T3a: first Load sends C2S event
[WARN][SaveSystemNet] REJECT: load already pending, refusing new request
  ✓ T3b: second Load does NOT send another C2S event
  ✓ T3c: rejected Load callback gets false
  ✓ T3d: rejected Load callback gets error message
  ✓ T3e: first Load callback not yet called
[WARN][SaveSystemNet] LATE-RESPONSE: load response arrived but no matching pending (ignored)
  ✓ T4: late LoadResult response ignored, no pending
[INFO][SaveSystemNet] C2S_CreateChar sent: slot=1 name=TestChar class=default
  ✓ T5a: CreateCharacter sends C2S event
[WARN][SaveSystemNet] REJECT: char already pending, refusing new request
  ✓ T5b: DeleteCharacter does NOT send another C2S event (shared pending)
  ✓ T5c: rejected Delete callback gets false
  ✓ T5d: rejected Delete gets error message
  ✓ T5e: Create callback not yet called
[WARN][SaveSystemNet] LATE-RESPONSE: char response arrived but no matching pending (ignored)
  ✓ T6: late CharResult response ignored, no pending
[INFO][SaveSystemNet] C2S_MigrateData sent: 0.0KB
[WARN][SaveSystemNet] REJECT: migrate already pending, refusing new request
  ✓ T7a: second MigrateToServer rejected
  ✓ T7b: rejected migration gets error message
[WARN][SaveSystemNet] LATE-RESPONSE: migrate response arrived but no matching pending (ignored)
  ✓ T8: late MigrateResult response ignored, no pending
  ✓ T9a: queued FetchSlots callback not yet called
[WARN][SaveSystemNet] Clearing queued FetchSlots callback (with error notification)
  ✓ T9b: ClearQueue passes nil result
  ✓ T9c: ClearQueue passes timeout error
  ✓ T10a: FetchSlots queued (not called)
[INFO][SaveSystemNet] Network ready, _networkReady=true
[INFO][SaveSystemNet] Executing queued FetchSlots...
[INFO][SaveSystemNet] C2S_FetchSlots sent
  ✓ T10b: OnNetworkReady triggers queued FetchSlots → C2S sent
[INFO][SaveSystemNet] C2S_FetchSlots sent
  ✓ T11a: C2S_FetchSlots sent
[INFO][SaveSystemNet] FetchSlots ok: 1 slots
  ✓ T11b: callback received slotsIndex
  ✓ T11c: callback received no error
  ✓ T11d: pending cleared after resolve
[INFO][SaveSystemNet] C2S_LoadGame sent: slot=1
  ✓ T12a: C2S_LoadGame sent
[INFO][SaveSystemNet] Inventory assembled from single-key network response
[INFO][SaveSystemNet] LoadGame ok: slot=1
  ✓ T12b: Load callback received success
  ✓ T12c: pending cleared after resolve

[test_save_system_net_state_machine] 34/34 passed, 0 failed

[PASS] save_system_net_state_machine (34/34 passed)
```

### 门禁汇总

```
[SUMMARY] total=10 executed=10 passed=10 failed=0 skipped=0
EXIT: SUCCESS
```

### 全量套件

```
[SUMMARY] total=24 executed=10 passed=10 failed=0 skipped=14
EXIT: SUCCESS
```

**Blocking gate 继续全绿。**

---

## 6. rules.md 符合性说明

| 检查项 | 结果 |
|--------|------|
| 是否改协议 (`SaveProtocol`) | 否 |
| 是否改存档结构 | 否 |
| 是否改服务端 (`server_main.lua`) | 否 |
| 是否改存档版本号/迁移函数 | 否 |
| 是否改 `FeatureFlags` | 否 |
| 是否改 `MigrationPolicy` | 否 |
| build 命令是否使用 entry_client + entry_server | N/A（本次为纯 Lua 重构+测试，不涉及 build） |

---

## 7. 风险与遗留

### 仍然存在的状态机盲区

1. **跨类动作交叉**：当前只控制同类请求的 single-flight，不同类动作（如 FetchSlots 和 Load 同时 pending）是允许的。这在正常 UI 流程中不会发生（必须先 FetchSlots 成功才能 Load），但协议层无强制约束。
2. **重试机制的 pending 状态**：`FetchSlots` 和 `Load` 有自动重试逻辑（`ScheduleDelayed`），重试期间不在 pending 表中（因为还没成功发出 C2S）。这意味着重试期间新请求可以进入。这是合理的——重试是内部机制，对调用方透明。
3. **废弃迁移路径**：`MigrateToServer` / `MigrateFromLocalFile` 仍保留代码形态但已在产品策略上关闭（`MigrationPolicy` flag=false）。状态机收口已完成，但未做 tombstone 标记。可在后续迭代中决定是否物理删除。

### 是否允许进入 R2 线上验证

**是** — 满足所有放行条件：
1. R2 已提交 Git
2. 完成报告已提交
3. Blocking gate 全绿
4. 无协议改动
5. 无服务端改动

建议先做一轮线上暗发布 + 自有账号验证，确认 FetchSlots / Load / CreateChar / DeleteChar 正常流程无回归后，再决定是否开始 R3。

---

## 8. 新增基础设施说明

### 统一 pending 接口

```lua
-- 动作类型常量
ACTION_FETCH_SLOTS = "fetchSlots"
ACTION_LOAD        = "load"
ACTION_CHAR        = "char"
ACTION_MIGRATE     = "migrate"

-- 统一辅助函数
beginPending(actionType, callback, meta)   -- 开始 pending（已有则返回 false）
resolvePending(actionType)                 -- 解决 pending，返回 callback+meta
rejectPending(actionType, errorMsg)        -- 拒绝 pending 并通知回调
hasPending(actionType)                     -- 查询是否有 pending

-- 测试辅助
SaveSystemNet._getPendingSnapshot()        -- 获取当前 pending 状态快照
SaveSystemNet._resetForTest()              -- 重置所有内部状态
```

### 测试覆盖矩阵

| 测试 | 动作类型 | 验证语义 |
|------|----------|----------|
| T1-T2 | FetchSlots | single-flight reject + 晚到响应 |
| T3-T4 | Load | single-flight reject + 晚到响应 |
| T5-T6 | Char (create+delete 共享) | single-flight reject + 晚到响应 |
| T7-T8 | Migrate | single-flight reject + 晚到响应 |
| T9 | FetchSlots 队列 | ClearQueue 通知回调 |
| T10 | FetchSlots 队列 | 网络就绪后自动执行 |
| T11 | FetchSlots | 正常流程端到端 |
| T12 | Load | 正常流程端到端 |
