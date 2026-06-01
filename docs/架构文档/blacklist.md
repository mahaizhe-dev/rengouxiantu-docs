# 排行榜黑名单

> 代码位置：`scripts/config/Blacklist.lua`（统一配置，所有排行榜共用）

## 当前黑名单

### 按账号 userId 封禁（最精确，无法逃避）

| userId | TapTap 昵称 | 已知角色名 | 原因 | 添加时间 | 处罚力度 |
|--------|------------|-----------|------|---------|---------|
| 1853807222 | 123 | 一剑纵横三界、爸爸快插我、修仙者 | 作弊，数据异常，多次改名逃避封禁 | 2026-03-16 | 排行榜屏蔽 |
| **待填入** | 指上人间 | 未知 | 仙石异常（154434），疑似作弊 | 2026-06-01 | **全部排行榜屏蔽 + 扣仙石至0 + 清除排行分数 + 禁止登录** |

### 按角色名封禁（辅助，防止 userId 未匹配时兜底）

| 角色名 | 原因 | 添加时间 |
|--------|------|---------|
| 一剑纵横三界 | 作弊 | 2026-03-15 |
| 爸爸快插我 | 作弊同账号 | 2026-03-15 |

## 覆盖范围（四榜 + 登录）

| 排行榜 | rank key | 过滤位置 | 状态 |
|--------|----------|---------|------|
| 修仙榜 | `rank2_score_*` | `LeaderboardUI.lua` (修仙榜 tab) | ✅ 已有 |
| 试炼榜 | `trial_floor` | `LeaderboardUI.lua` (试炼榜 tab) | ✅ 新增 |
| 镇狱榜 | `prison_floor` | `LeaderboardUI.lua` (镇狱榜 tab) | ✅ 新增 |
| 仙石榜 | `xianshi_rank` | `XianshiRankUI.lua` | ✅ 新增 |
| 登录拦截 | — | `server_main.lua` HandleClientIdentity | ✅ 新增 |

## 屏蔽机制（四级）

1. **userId**（`Blacklist.userIds`）：直接按账号封禁，改名无效，零误封
2. **角色名**（`Blacklist.charNames`）：首次渲染前匹配，命中后自动扩展为 userId 级封禁
3. **TapTap 昵称**（`Blacklist.nicknames`）：昵称回调后匹配（当前未启用，避免误封）
4. **登录踢出**（`Blacklist.kickOnLogin`）：服务端 HandleClientIdentity 直接 Disconnect，玩家完全无法进入游戏

## 处罚操作（一次性，登录时自动执行）

针对严重作弊者，在 `SlotReadService.lua` 中配置一次性管理操作：
- 扣除全部仙石（`MoneyCost`）
- 清除所有排行榜分数（`ScoreSetInt` 设为 0）
- 使用幂等标志位防止重复执行

## 排查流程

1. **获取 userId**：
   - 仙石榜：预览游戏打开仙石榜，查看日志（`XianshiRankUI.RenderList` 会 print 每条 entry 的 userId）
   - 修仙榜：日志输出前10名 `[Leaderboard] #N userId=xxx char=xxx`
   - 或直接在 `RankHandler.HandleGetRankList` 服务端日志中查看
2. 确认 userId 后填入 `scripts/config/Blacklist.lua` 的 `userIds` 数组
3. 如需禁止登录，同时添加到 `kickOnLogin` 表
4. 如需扣仙石/清榜，填入 `SlotReadService.lua` 的 `BAN_TARGET_UID`
5. 构建发布，等待目标玩家下次登录触发

## 文件索引

| 文件 | 职责 |
|------|------|
| `scripts/config/Blacklist.lua` | 统一黑名单配置（所有模块引用） |
| `scripts/ui/LeaderboardUI.lua` | 客户端修仙榜/试炼榜/镇狱榜过滤 |
| `scripts/ui/XianshiRankUI.lua` | 客户端仙石榜过滤 |
| `scripts/server_main.lua` | 服务端登录拦截 |
| `scripts/network/SlotReadService.lua` | 一次性管理操作（扣仙石+清榜） |
