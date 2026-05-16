# 2026-05-12 P0-5 CloudStorage 网络模式语义收口任务卡

> 这是 `P0-2A` 之后的下一张正式任务卡。
> `P0-3` 只有在本任务被 Git 复核通过后才能开始。

配套文档：

- [P0-2A FeatureFlags 语义收口与元数据校正任务卡](./2026-05-12-P0-2A-FeatureFlags语义收口与元数据校正任务卡.md)
- [执行方最小操作清单](./2026-05-12-执行方最小操作清单.md)
- [实施手册（执行 AI 版）](./2026-05-12-线上项目优化与重构实施手册-执行AI版.md)
- [线上项目优化与重构执行报告](./2026-05-12-线上项目优化与重构执行报告.md)

---

## 1. 任务定义

任务ID：`P0-5`

任务名称：`CloudStorage 网络模式语义收口`

变更类型：`缺陷修复`

目标：

- 消灭网络模式下 `CloudStorage.BatchSet()` 的“假成功”路径
- 让调用方能够区分“真成功”和“明确不支持/明确失败”
- 在不改协议、不改服务端主结构的前提下，为后续 `P0-3` 存档链路收敛先清出真实语义边界

---

## 2. 为什么先做这个

当前最危险的问题不是 `CloudStorage` 写不进去，而是：

1. 调用方以为写进去了
2. 实际没有落盘
3. 回调还走了 `ok()`

这会直接污染后续判断，尤其是：

- `checkpoint / prev / login backup`
- `slots_index` 自愈写回
- `account_atlas` 账号级即时保存

如果不先把这类“假成功”收口，后续做 `P0-3` 时，会把错误语义一起带进新的存档链路。

---

## 3. 本任务的成功标准

成功标准只有 7 条：

1. 当 `CLOUDSTORAGE_STRICT_BATCHSET=false` 时，旧行为保持不变。
2. 当 `CLOUDSTORAGE_STRICT_BATCHSET=true` 且 batch 属于真正的存档写入时，网络模式仍走现有保存通路。
3. 当 `CLOUDSTORAGE_STRICT_BATCHSET=true` 且 batch 属于当前不支持的非存档写入时，不允许再调用 `ok()` 冒充成功。
4. `unsupported` 必须通过明确的错误码/错误原因暴露给调用方，不能只打日志。
5. 所有直接 `CloudStorage.BatchSet()` 调用点都要被盘点并分类。
6. 至少有一组纯 Lua 自动化测试覆盖 `flag off / flag on / save batch / unsupported batch`。
7. 本任务不得引入协议改动，也不得修改服务端主 handler 结构。

只要 7 条里有任一条不满足，本任务不算完成。

---

## 4. 本任务允许修改的文件

允许新增或修改：

- `scripts/network/CloudStorage.lua`
- `scripts/systems/save/SavePersistence.lua`
- `scripts/systems/save/SaveLoader.lua`
- `scripts/systems/save/SaveRecovery.lua`
- `scripts/systems/save/SaveSlots.lua`
- `scripts/systems/AtlasSystem.lua`
- `scripts/tests/TestRegistry.lua`
- `scripts/tests/test_cloudstorage_network_semantics.lua`
- 必要时少量修改 `scripts/tests/README.md`

如果确实需要新增辅助测试文件，也只能放在 `scripts/tests/` 下。

---

## 5. 本任务禁止修改的文件

不要修改：

- `scripts/server_main.lua`
- `scripts/network/SaveProtocol.lua`
- `scripts/network/SaveSystemNet.lua`
- `scripts/config/FeatureFlags.lua`
- `scripts/systems/save/SaveSerializer.lua`
- `scripts/systems/save/SaveLoader.lua` 之外的 DTO / 迁移相关重构文件

特别禁止：

- 顺手扩协议
- 顺手给服务端补新的 Meta 写接口
- 顺手把 `BatchSet()` 一次性拆成新 API 并全项目替换
- 顺手做 `P0-3 / P0-4 / P0-6`

本任务第一阶段只修语义，不做大重构。

---

## 6. 执行前先读这些文件

1. `scripts/network/CloudStorage.lua`
2. `scripts/systems/save/SavePersistence.lua`
3. `scripts/systems/save/SaveLoader.lua`
4. `scripts/systems/save/SaveRecovery.lua`
5. `scripts/systems/save/SaveSlots.lua`
6. `scripts/systems/AtlasSystem.lua`
7. `scripts/config/FeatureFlags.lua`
8. 搜索 `CloudStorage.BatchSet(` 的全部直接调用点

执行前必须先回答：

1. 哪些 `BatchSet` 调用点是真正的 `save_{slot}` 存档写入
2. 哪些调用点是 `slots_index / login / prev / deleted / account_atlas` 这类非主存档写入
3. 当前 `CloudStorage` 在网络模式下是如何把“未真正写入”的路径伪装成成功的
4. 在不改协议的前提下，`unsupported` 准备如何返回给调用方

答不出来就不要动代码。

---

## 7. 固定执行步骤

严格按这个顺序做。

### 步骤 1：盘点所有直接调用点

必须列出所有直接 `CloudStorage.BatchSet()` 调用点，并分类成下列 3 类之一：

1. `save_batch`
   - 包含 `save_{slot}` 或兼容 `save_data_{slot}`，本质上是角色存档写入
2. `meta_batch`
   - 只写 `slots_index / login / prev / deleted / account_atlas` 等元数据或备份类 key
3. `other`
   - 既不是主存档，也不是当前可证明安全的元数据写入

要求：

- 报告里必须交付完整清单
- 不允许只挑自己准备改的几个点写

### 步骤 2：收口 CloudStorage 语义

在 `CloudStorage.lua` 中落实 `CLOUDSTORAGE_STRICT_BATCHSET` 的第一阶段语义。

固定要求：

1. `flag=false`
   - 保持当前线上行为
   - 不改变现有默认路径
2. `flag=true + save_batch`
   - 保持现有网络保存路径
   - 继续走现有 `C2S_SaveGame`
3. `flag=true + 非 save_batch`
   - 不允许再走 `events.ok()`
   - 必须通过 `events.error(code, reason)` 明确暴露
   - `code` 必须稳定，可用于测试断言
   - `reason` 必须包含 `desc` 和关键 keys 信息，方便排查

不要新增第三套复杂回调协议。

建议：

- 在 `CloudStorage.lua` 内定义稳定的 unsupported 错误码常量
- 把 key 分类逻辑收敛到一个小函数里，不要散在 `Save()` 主流程

### 步骤 3：只补最小调用方处理

如果 strict 模式下某些调用点会收到 `unsupported error`，允许做最小补充，但只能是：

1. 日志更清楚
2. 调用方不再把错误当成功
3. 必要时在回调里做明确降级说明

不允许做的事：

1. 新增协议
2. 绕过 `CloudStorage` 直接偷偷写别的接口
3. 为了“让所有调用点都绿”而把 unsupported 又吞回成功

### 步骤 4：建立纯 Lua 测试

新增：

- `scripts/tests/test_cloudstorage_network_semantics.lua`

最低覆盖：

1. `flag=false + 非 save batch`
   - 保持当前旧行为
2. `flag=true + 非 save batch`
   - 不调用 `ok()`
   - 调用 `error()`
   - 错误码稳定
3. `flag=true + save batch`
   - 正常走网络保存路径
   - 能验证构造出的请求基本字段
4. `flag=true + unsupported`
   - 错误原因中能看出 `desc` 和 key 列表

测试方式建议：

- stub `network / VariantMap / Variant / SubscribeToEvent`
- 纯 Lua 加载 `CloudStorage.lua`
- 不依赖真实引擎场景

### 步骤 5：接入门禁

如果新测试是纯 Lua，可直接接入现有 runner。

至少跑：

```bash
python3 scripts/tests/_run_via_lupa.py --gate=blocking
python3 scripts/tests/_run_via_lupa.py --all
```

如果新测试暂时不适合 blocking，必须在报告里解释为什么，以及计划何时转正。

---

## 8. 本任务的关键限制

这一步不是“做完整 MetaBatch 支持”。

这一步只做：

1. 识别真正支持的 save batch
2. 让 unsupported 非保存批量写入不再假成功
3. 把错误显式暴露给调用方
4. 用测试把语义钉死

本任务默认接受这样一种结果：

- `strict flag` 打开后，部分 `meta_batch` 仍然是“明确不支持”
- 但它们必须“明确失败”，不能再“假成功”

如果后续要真正支持这些元数据写入，那是后续更小任务，不是本任务。

---

## 9. 本任务的停手条件

出现以下情况，停止编码，改交付问题说明：

1. 要消灭假成功，必须同时改协议和服务端处理
2. 发现某些调用方业务上强依赖“假成功”才能继续流程
3. 为了完成本任务需要改动超过 8 个核心运行文件
4. 无法为 `unsupported` 设计稳定可断言的错误码
5. 新测试无法在纯 Lua 下隔离加载 `CloudStorage`

如果停手，仍然要交付：

- 调用点分类清单
- 哪些调用方依赖假成功
- 为什么当前任务切分还不够小
- 建议拆出的后续更小任务

---

## 10. 本任务交付模板

下一份完成报告必须至少包含以下内容，不允许省略：

```md
任务ID: P0-5
本次结论: 完成 / 部分完成 / 停止

1. Git 交付信息
- PR 链接:
- commit SHA:
- parent SHA:
- diff 摘要:

2. 调用点盘点
| file | desc | keys/用途 | 分类 | 旧行为 | 新行为 |

3. 语义矩阵
| 模式 | flag | batch 类型 | 结果 | 说明 |

4. 修改文件
- 新增:
- 修改:

5. 关键实现说明
- strict 模式如何判断 unsupported:
- 错误码是什么:
- reason 中包含了什么:
- 哪些调用方补了最小处理:

6. 自动化测试
- 新增测试:
- 注册到哪个 gate/group:
- 运行命令:
- 原始输出:

7. 风险与回滚
- 默认值下是否保持旧行为:
- strict 模式下已知 unsupported 清单:
- 回滚方式:

8. 下一步建议
- 是否允许进入 P0-3:
- 如果不允许，阻塞点是什么:
```

---

## 11. 做完这个任务后才能做什么

只有在以下条件同时满足时，才允许进入 `P0-3`：

1. `P0-5` 已提交 Git
2. 已输出完成报告
3. 我基于 `报告 + Git 代码` 复核通过

没有这 3 条，不允许开始下一步存档链路重构。

---

## 12. 额外提醒

本任务最容易犯的错有 3 个：

1. 为了省事继续保留 `ok()` 假成功
2. 为了“彻底解决”顺手改协议和服务端
3. 为了让测试好看，把 unsupported 又吞掉

这 3 种做法都不接受。
