# 排行榜黑名单

> 代码位置：`scripts/config/Blacklist.lua`（统一配置，所有排行榜共用）

## 当前黑名单

### 按账号 userId 封禁（最精确，无法逃避）

| userId | 已知角色名 | 原因 | 处罚力度 | 仙石榜 |
|--------|-----------|------|---------|--------|
| 1853807222 | 一剑纵横三界、爸爸快插我、修仙者 | 作弊，数据异常，多次改名逃避 | 三榜屏蔽 | 屏蔽 |
| 23818077 | 三合 | 排行榜第7，太虚第一，作弊数据异常 | 三榜屏蔽 | **保留观察** |
| 797347017 | — | 作弊数据异常 | 三榜屏蔽 | **保留观察** |
| 1731101682 | — | 仙石榜第2，作弊数据异常 | 三榜屏蔽 + 扣仙石至0 | **保留观察** |

### 按角色名封禁（辅助兜底）

| 角色名 | 原因 |
|--------|------|
| 一剑纵横三界 | 作弊 |
| 爸爸快插我 | 作弊同账号 |
| 三合 | 排行榜第7，太虚第一 |

### 仙石榜保留名单（xianshiKeep）

以下 userId 在仙石榜**不过滤**，其余三榜（修仙/试炼/镇狱）正常屏蔽：

| userId | 说明 |
|--------|------|
| 23818077 | "三合"，观察中 |
| 797347017 | 观察中 |
| 1731101682 | 仙石榜第2，观察中 |

### 登录拦截名单（kickOnLogin）

| userId | 状态 | 说明 |
|--------|------|------|
| （暂无） | — | 后续观察如继续作弊再启用 |

> 如需对上述玩家启用登录拦截，在 `Blacklist.kickOnLogin` 中添加 `[userId] = true`。

---

## 一次性管理操作（SlotReadService.lua）

| userId | 操作内容 | 幂等标志 | 状态 |
|--------|---------|---------|------|
| 1074886667 | 扣仙石≤2000 + 解锁樱华天犬 | `admin_op_deduct_1074_xianshi2000` | 已执行 |
| 1731101682 | 扣全部仙石至0 | `admin_op_deduct_1731101682_xianshi_all` | 等待下次登录触发 |

---

## 覆盖范围（四榜 + 登录）

| 排行榜 | rank key | 过滤位置 | 状态 |
|--------|----------|---------|------|
| 修仙榜 | `rank2_score_*` | `LeaderboardUI.lua` | ✅ |
| 试炼榜 | `trial_floor` | `LeaderboardUI.lua` | ✅ |
| 镇狱榜 | `prison_floor` | `LeaderboardUI.lua` | ✅ |
| 仙石榜 | `xianshi_rank` | `XianshiRankUI.lua`（传入 `xianshiKeep`） | ✅ |
| 登录拦截 | — | `server_main.lua` HandleClientIdentity | ✅ |

## 屏蔽机制（四级）

1. **userId**（`Blacklist.userIds`）：直接按账号封禁，改名无效，零误封
2. **角色名**（`Blacklist.charNames`）：首次渲染前匹配，命中后自动扩展为 userId 级封禁
3. **仙石榜保留**（`Blacklist.xianshiKeep`）：在 `FilterRankList` 第三参数传入，跳过过滤
4. **登录踢出**（`Blacklist.kickOnLogin`）：服务端 HandleClientIdentity 直接 Disconnect

## 排查流程

1. **获取 userId**：查看仙石榜/修仙榜日志输出
2. 确认 userId 后填入 `Blacklist.userIds`
3. 如需仙石榜保留观察，同时填入 `Blacklist.xianshiKeep`
4. 如需扣仙石，在 `SlotReadService.lua` 添加一次性管理操作
5. 如需禁止登录，添加到 `Blacklist.kickOnLogin`
6. 构建发布，等待目标玩家下次登录触发

## 文件索引

| 文件 | 职责 |
|------|------|
| `scripts/config/Blacklist.lua` | 统一黑名单配置 |
| `scripts/ui/LeaderboardUI.lua` | 客户端修仙榜/试炼榜/镇狱榜过滤 |
| `scripts/ui/XianshiRankUI.lua` | 客户端仙石榜过滤（传入 xianshiKeep） |
| `scripts/server_main.lua` | 服务端登录拦截 |
| `scripts/network/SlotReadService.lua` | 一次性管理操作（扣仙石等） |

---

*最后更新: 2026-07-09*
