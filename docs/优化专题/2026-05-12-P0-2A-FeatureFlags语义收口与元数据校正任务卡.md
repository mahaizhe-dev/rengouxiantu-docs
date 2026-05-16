# 2026-05-12 P0-2A FeatureFlags 语义收口与元数据校正任务卡

> 这是 `P0-2` 之后的紧接任务。
> `P0-5` 和 `P0-3` 只有在本任务被 Git 复核通过后才能开始。

配套文档：

- [P0-2 线上开关与发布护栏任务卡](./2026-05-12-P0-2-线上开关与发布护栏任务卡.md)
- [执行方最小操作清单](./2026-05-12-执行方最小操作清单.md)
- [实施手册（执行 AI 版）](./2026-05-12-线上项目优化与重构实施手册-执行AI版.md)

---

## 1. 任务定义

任务ID：`P0-2A`

任务名称：`FeatureFlags 语义收口与元数据校正`

变更类型：`缺陷修复`

目标：

- 修正 `FeatureFlags.setOverride()` 对未注册开关仍会生效的安全问题
- 校正 `flag -> 后续任务` 映射，避免误导后续执行顺序
- 修正 `P0-2` 完成报告中的 Git 元数据错误

---

## 2. 为什么要先做这个

基于 `P0-2` Git 复核，当前还存在 3 个必须先收口的问题：

1. `setOverride("UNKNOWN_FLAG", true)` 会让未知开关实际生效。
2. 部分 flag 的 `task` 映射与当前路线图不一致。
3. `P0-2` 完成报告中的 `commit SHA / parent SHA` 与真实 Git 提交不一致。

这 3 个问题不修，后续 `P0-5 / P0-3` 的灰度验证会出现语义歧义和追踪错误。

---

## 3. 本任务的成功标准

成功标准只有 5 条：

1. 未注册 flag 的 `setOverride()` 必须拒绝且不生效。
2. 未注册 flag 的 `isEnabled()` 仍然返回 `false`。
3. 所有 flag 的 `task` 元数据必须与当前路线图一致。
4. `P0-2` 完成报告中的 `commit / parent` 信息必须修正为真实值。
5. 阻断门禁在本任务完成后仍保持绿色。

如果 5 条里任一条不满足，本任务不算完成。

---

## 4. 本任务允许修改的文件

允许新增或修改：

- `scripts/config/FeatureFlags.lua`
- `scripts/tests/test_feature_flags.lua`
- `docs/优化专题/2026-05-12-P0-2-完成报告.md`
- 必要时少量修改 `scripts/tests/README.md`

如果确实需要新增辅助测试文件，也只能放在 `scripts/tests/` 下。

---

## 5. 本任务禁止修改的文件

不要修改：

- `scripts/main.lua`
- `scripts/server_main.lua`
- `scripts/client_main.lua`
- `scripts/network/*`
- `scripts/systems/save/*`
- 任何业务逻辑文件

特别禁止：

- 借着修语义顺手新增新的运行时行为
- 借着修元数据顺手改高风险任务顺序

---

## 6. 执行前先读这些文件

1. `scripts/config/FeatureFlags.lua`
2. `scripts/tests/test_feature_flags.lua`
3. `docs/优化专题/2026-05-12-P0-2-完成报告.md`
4. `docs/优化专题/2026-05-12-P0-2-线上开关与发布护栏任务卡.md`

执行前必须先回答：

1. 未注册 flag 目前为什么会实际生效
2. 哪些 `task` 映射与路线图不一致
3. `P0-2` 的真实 commit 和 parent 是什么

答不出来就不要动代码。

---

## 7. 固定执行步骤

严格按这个顺序做。

### 步骤 1：收口未知开关 override 语义

必须把 `setOverride(flagName, value)` 改成以下语义：

1. `flagName` 未注册时：
   - 返回 `false`
   - 不写入 override
2. `flagName` 已注册且 `value` 为 boolean 时：
   - 返回 `true`
   - 正常写入 override
3. `value` 非 boolean 时：
   - 返回 `false`
   - 不写入 override

禁止继续保留“返回 false 但 override 实际生效”的现状。

### 步骤 2：校正 task 映射

逐一核对 `FLAG_REGISTRY` 中每个 flag 的 `task` 字段。

最低要求：

- `SAVE_PIPELINE_V2` → 对应存档链路重构任务
- `SERVER_SAVE_VALIDATOR_V2` → 对应服务端存档校验/存档链路相关任务
- `SAVE_MIGRATION_SINGLE_ENTRY` → 对应迁移入口收敛任务
- `NEW_MAIN_LOOP_ORCHESTRATOR` → 对应 `main.lua` 编排器拆分任务
- `NEW_SERVER_ROUTER` → 对应服务端路由/服务化相关任务
- `CLOUDSTORAGE_STRICT_BATCHSET` → 对应 CloudStorage 语义修正任务

不要“猜一个差不多的 P0/P1 号”填进去。

### 步骤 3：更新测试

必须修改 `test_feature_flags.lua`，至少覆盖：

1. 未注册 flag 的 `setOverride()` 返回 `false`
2. 未注册 flag 的 `isEnabled()` 仍为 `false`
3. 未注册 flag 不会污染 `snapshot()`
4. 修正后的 task 映射与路线图一致

如果旧测试断言了“未知 flag override 后可读取为 true”，必须删掉并改成新语义。

### 步骤 4：修正完成报告

更新 `P0-2` 完成报告中的 Git 信息：

- `commit SHA`
- `parent SHA`
- 如果 `diff 摘要` 数量有变化，也要同步修正

要求：

- 报告内容必须与真实 Git 提交完全一致
- 不允许继续保留错误 SHA

### 步骤 5：回归门禁

至少跑：

```bash
python3 scripts/tests/_run_via_lupa.py --gate=blocking
python3 scripts/tests/_run_via_lupa.py config
```

如当前环境允许，也建议补跑：

```bash
python3 scripts/tests/_run_via_lupa.py --all
```

---

## 8. 本任务的停手条件

出现以下情况，停止编码，改交付问题说明：

1. 修 `FeatureFlags` 语义需要同时改动业务逻辑
2. 无法确认当前路线图中每个 flag 的准确目标任务
3. `P0-2` 的真实 Git 提交链条无法确认
4. 修复后阻断门禁变红，且无法在本任务范围内收口

如果停手，仍然要交付：

- 语义风险说明
- task 映射歧义清单
- Git 元数据不一致清单

---

## 9. 本任务交付模板

下一份完成报告必须至少包含以下内容，不允许省略：

```md
任务ID: P0-2A
本次结论: 完成 / 部分完成 / 停止

1. Git 交付信息
- PR 链接:
- commit SHA:
- parent SHA:
- diff 摘要:

2. 修改文件
- 新增:
- 修改:

3. FeatureFlags 语义修正
- 未注册 flag 的旧行为:
- 未注册 flag 的新行为:
- 为什么必须这样改:

4. task 映射校正
| flag | 修正前 | 修正后 | 依据 |

5. 自动化测试
- 修改了哪些测试:
- 新增了哪些断言:
- 运行命令:
- 原始输出:

6. P0-2 完成报告修正
- 修正前:
- 修正后:

7. 风险与回滚
- 已知风险:
- 回滚方式:

8. 下一步建议
- 是否允许进入 P0-5:
- 是否允许进入 P0-3:
```

---

## 10. 做完这个任务后才能做什么

只有在以下条件同时满足时，才允许进入 `P0-5` 或 `P0-3`：

1. `P0-2A` 已提交 Git
2. 已输出完成报告
3. 我基于 `报告 + Git 代码` 复核通过

没有这 3 条，不允许开始高风险存档改造。

---

## 11. 额外提醒

本任务不是“再做一版 FeatureFlags”。

本任务只做三件事：

1. 语义修正
2. 元数据校正
3. 报告与 Git 对齐

不要顺手扩展开关数量，不要顺手接入新行为。
