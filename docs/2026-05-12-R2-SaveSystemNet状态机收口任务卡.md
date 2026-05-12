# 2026-05-12 R2 SaveSystemNet 状态机收口任务卡

> 这是 `R1` 通过后的下一张正式任务卡。
> 不再单独拆 `R2-prep`。
> “边界盘点/生命周期梳理”并入本任务的固定第 1 步。

配套文档：

- [R1 诊断与日志治理收窄版任务卡](./2026-05-12-R1-诊断与日志治理收窄版任务卡.md)
- `docs/2026-05-12-R1-诊断与日志治理收窄版完成报告.md`
- [P0-4 后续优化路线复盘与重排说明（执行 AI 评估版）](./2026-05-12-P0-4后续优化路线复盘与重排说明-执行AI评估版.md)
- `docs/2026-05-12-P0-4后续优化路线评估报告.md`
- [执行方最小操作清单](./2026-05-12-执行方最小操作清单.md)
- [实施手册（执行 AI 版）](./2026-05-12-线上项目优化与重构实施手册-执行AI版.md)
- [架构规则 rules.md](../架构文档/rules.md)

---

## 1. 任务定义

任务ID：`R2`

任务名称：`SaveSystemNet 状态机收口`

变更类型：`等价重构 + 风险收口`

目标：

- 收口 `SaveSystemNet.lua` 中单槽 pending 状态的生命周期
- 消灭“静默覆盖旧回调 / 晚到响应语义不一致 / 调用方永久等待”这类结构性问题
- 在**不改协议、不改服务端 handler、不改存档结构**的前提下，先把客户端网络状态机收稳

---

## 2. 为什么现在做这个

当前 `SaveSystemNet.lua` 的主要问题不是功能缺失，而是状态语义不清：

1. 同类请求重复进入时，旧 pending 可能被新请求覆盖
2. 某些响应晚到时会被忽略，但不同动作的处理方式并不统一
3. `_pendingFetchSlots / _pendingLoad / _pendingChar / _pendingMigrate / _queuedFetchSlots` 都是独立变量，生命周期散落
4. 废弃迁移路径虽然已在产品策略上关闭，但代码层仍保留较多历史形态

如果不先收口这些语义，就直接做 `R3` 服务端主链拆分，后面很难判断问题是：

- 客户端状态机
- 还是服务端链路

所以这一步的本质是：**先让请求状态变得可预测，再碰更深的服务端拆分。**

---

## 3. 本任务的成功标准

成功标准只有 9 条：

1. `SaveSystemNet` 中每类动作的 pending 生命周期都被统一建模，不再散落成“每处自己判断”。
2. 对于同类请求重复进入，行为必须显式且一致：
   - 要么拒绝新请求
   - 要么取消旧请求并明确通知旧回调
   - 但绝不能静默覆盖
3. 晚到响应的处理必须统一：
   - 无匹配 pending 时，统一忽略并记录诊断/警告
   - 不再出现有的动作静默吞掉、有的动作继续误用当前回调
4. `FetchSlots / Load / Char / Migrate` 四类动作的状态流转有统一辅助函数或统一状态结构。
5. 本任务不得引入协议字段改动，尤其不得新增/修改 `SaveProtocol` 中的请求关联字段。
6. 本任务不得修改 `server_main.lua`。
7. 本任务不得改存档结构、版本号、迁移函数链。
8. 至少新增一组纯 Lua 自动化测试覆盖状态机核心语义。
9. blocking gate 继续保持绿色。

只要 9 条里任意一条不满足，本任务不算完成。

---

## 4. 本任务允许修改的文件

允许新增或修改：

- `scripts/network/SaveSystemNet.lua`
- `scripts/network/CloudStorage.lua`
- `scripts/tests/TestRegistry.lua`
- `scripts/tests/test_save_system_net_state_machine.lua`
- 必要时少量修改 `scripts/tests/README.md`

如果确实需要 very small test helper，也只能放在 `scripts/tests/` 下。

---

## 5. 本任务禁止修改的文件

不要修改：

- `scripts/network/SaveProtocol.lua`
- `scripts/server_main.lua`
- `scripts/main.lua`
- `scripts/client_main.lua`
- `scripts/systems/save/*`
- `scripts/config/FeatureFlags.lua`
- `scripts/network/MigrationPolicy.lua`

特别禁止：

- 顺手改协议，给 `FetchSlots / Load / Create / Delete / Migrate` 强加新 `requestId`
- 顺手改服务端回包
- 顺手重做 UI 角色选择流程
- 顺手改 `SaveDTO`
- 顺手继续做 `R3`

---

## 6. 执行前先读这些文件

必须先读：

1. `scripts/network/SaveSystemNet.lua`
2. `scripts/network/CloudStorage.lua`
3. `scripts/network/MigrationPolicy.lua`
4. `scripts/server_main.lua` 中：
   - `HandleFetchSlots`
   - `HandleLoadGame`
   - `HandleCreateChar`
   - `HandleDeleteChar`
   - `HandleMigrateData`
5. `docs/2026-05-12-P0-4后续优化路线评估报告.md`
6. `docs/架构文档/rules.md`

执行前必须先回答：

1. 当前每类动作是谁创建 pending，谁清理 pending，谁回调调用方
2. 同类请求重入时，当前行为是什么
3. 晚到响应到达时，当前行为是什么
4. 哪些问题可以在不改协议的前提下收口，哪些问题不行

答不出来就不要动代码。

---

## 7. 固定执行步骤

严格按这个顺序做。

### 步骤 1：先交付状态机盘点结果

虽然不再拆 `R2-prep`，但盘点仍是本任务第一步，而且必须进入完成报告。

至少要列出这 5 个状态对象：

1. `_pendingFetchSlots`
2. `_pendingLoad`
3. `_pendingChar`
4. `_pendingMigrate`
5. `_queuedFetchSlots`

每个都要说明：

1. 创建点
2. 清理点
3. 成功回调点
4. 失败回调点
5. 重入时现在会发生什么
6. 晚到响应时现在会发生什么

如果这个表都列不清，说明还没读懂，不允许进入代码修改。

### 步骤 2：先统一“同类请求重入”的语义

本任务不追求“支持无限并发请求”。
本任务追求的是：**当前约束下，语义明确且安全。**

允许的收口方式有两种，只能选一种并全程一致：

1. `single-flight reject`
   - 某类请求未完成时，新同类请求立即失败
   - 新回调收到稳定错误原因
2. `single-flight cancel-old`
   - 某类请求未完成时，先明确通知旧回调被取消
   - 再让新请求进入

禁止：

1. 静默覆盖旧 pending
2. 只替换变量，不通知旧回调
3. 某个动作 `reject`，另一个动作 `cancel-old`，语义不一致

### 步骤 3：统一晚到响应处理

要求：

1. 如果响应回来时找不到匹配 pending：
   - 不执行业务回调
   - 统一记一条 `warn` 或 `diag`
2. 这种处理在 `FetchSlots / Load / Char / Migrate` 上要一致

这一步的目标不是“补所有并发能力”，而是：

- 避免晚到响应误伤当前状态
- 避免旧回调和新状态串线

### 步骤 4：收口状态结构

建议把散落状态收成更清晰的结构，例如：

- 每类动作有统一的 state record
- 统一的 `beginPending / failPending / resolvePending / cancelPending`

不要求你一定用某个具体名字。

但必须满足：

1. 逻辑重复明显减少
2. 四类动作状态语义更一致
3. 代码阅读时能看出每个动作的完整生命周期

### 步骤 5：废弃迁移路径做 tombstone 化，而不是重做

`MigrateToServer / MigrateFromLocalFile / HandleMigrateResult` 仍可保留，但本任务只允许做：

1. 生命周期清晰化
2. 统一重入/晚到响应语义
3. 日志和回调结果更明确

不允许做：

1. 重新启用迁移
2. 修改迁移协议
3. 改 `MigrationPolicy`
4. 改 slot remap 规则

### 步骤 6：建立纯 Lua 状态机测试

新增：

- `scripts/tests/test_save_system_net_state_machine.lua`

最低覆盖：

1. 同类 pending 重入时的统一语义
   - `reject` 或 `cancel-old`，但必须可断言
2. 晚到响应在无 pending 时被忽略
3. 清队列 `ClearQueue()` 的行为可断言
4. 网络未就绪时 `FetchSlots` 入队语义可断言
5. 至少覆盖 `FetchSlots` 和 `Load` 两类动作

如果还能覆盖 `Char` / `Migrate` 更好，但不是最低门槛。

测试方式建议：

1. stub `network / VariantMap / Variant / SubscribeToEvent`
2. 纯 Lua 加载 `SaveSystemNet.lua`
3. 通过替换 callback 和模拟事件驱动测试状态语义

### 步骤 7：接入门禁

如果测试是纯 Lua，应接入现有 runner。

至少跑：

```bash
python3 scripts/tests/_run_via_lupa.py
python3 scripts/tests/_run_via_lupa.py --all
```

如果新测试不进入 blocking，完成报告里必须说明原因。

---

## 8. 本任务的关键限制

这一步不是“并发协议升级”。

这一步只做：

1. 当前单飞行模型的语义收口
2. 晚到响应忽略统一
3. pending 生命周期统一
4. 状态机测试补齐

不做：

1. 协议升级
2. 服务端联动改造
3. 真正的多并发同类请求支持
4. UI 流程重写

---

## 9. 本任务的停手条件

出现以下情况，停止编码，改交付问题说明：

1. 若要完成本任务，必须改 `SaveProtocol` 或服务端回包字段
2. 发现当前某类动作的安全收口必须依赖服务端新增 `requestId`
3. 需要修改超过 2 个运行时核心文件之外的额外业务模块
4. 新测试无法在纯 Lua 下隔离加载 `SaveSystemNet`
5. 发现某些问题本质上已经属于 `R3` 服务端链路问题，而不是客户端状态机问题

如果停手，仍然要交付：

1. 哪些动作能在当前协议下安全收口
2. 哪些动作必须延后到 `R3` 或更晚
3. 为什么 `R2` 不能独立完成

---

## 10. 本任务交付模板

下一份完成报告必须至少包含以下内容，不允许省略：

```md
任务ID: R2
本次结论: 完成 / 部分完成 / 停止

1. Git 交付信息
- PR 链接:
- commit SHA:
- parent SHA:

2. 状态机盘点表
- _pendingFetchSlots
- _pendingLoad
- _pendingChar
- _pendingMigrate
- _queuedFetchSlots

3. 语义决策
- 本次选择的是 reject 还是 cancel-old
- 为什么
- 哪些动作完全统一了

4. 实际修改文件
- 文件清单
- 每个文件改了什么

5. 测试
- 测试命令
- 原始输出
- blocking 是否继续全绿

6. rules.md 符合性说明
- 是否改协议: 是 / 否
- 是否改存档结构: 是 / 否
- 是否改服务端: 是 / 否

7. 风险与遗留
- 仍然存在的状态机盲区
- 是否允许进入 R2 线上验证:
```

---

## 11. 完成后的放行条件

只有在以下条件同时满足时，才允许进入 `R2` 后的线上验证：

1. `R2` 已提交 Git
2. 完成报告已提交
3. blocking gate 继续绿色
4. 没有协议改动
5. 没有服务端改动

注意：

- `R2` 通过后，不建议立刻进入 `R3`
- 应先做一轮线上暗发布 + 自有账号验证
- 验证稳定后，再决定是否开始 `R3`

