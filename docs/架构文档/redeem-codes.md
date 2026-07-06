# 兑换码配置文档

> 在下方表格中配置兑换码，告诉 AI "生成兑换码" 即可自动注册到服务器。

---

## 可用奖励字段

| 字段 | 说明 | 示例 |
|------|------|------|
| gold | 金币 | 500 |
| lingYun | 灵韵 | 10 |
| titleId | 称号ID | "pioneer" |
| itemId | 道具ID | "weapon" |
| itemCount | 道具数量 | 1 |

## 可用称号ID

| ID | 名称 |
|----|------|
| pioneer | 先行者 |
| novice_star | 新星 |
| jianghu_hero | 江湖豪侠 |
| young_hero | 少年英雄 |
| veteran_xianyu | 老咸鱼 |
| boss_slayer_1k | 千斩 |
| boss_slayer_10k | 万斩 |

## 通用配置说明

| 字段 | 说明 | 默认值 |
|------|------|--------|
| maxUses | 最大使用次数 | 0（无限） |
| perUser | 每人限用次数 | 1 |
| perType | 限制维度：account=每账号 / character=每角色 | account |
| targetUID | 指定玩家UID | 0（全体） |

> **account vs character 区别**：
> - `account`（默认）：同一账号下所有角色共享兑换次数，账号兑换过就不能再兑
> - `character`：同一账号的不同角色可以分别兑换，每个角色独立计次

---

## 兑换记录重置规则

| 操作 | 是否重置兑换记录 | 原因 |
|------|:---:|------|
| 重新构建/重启服务器 | 不会 | quota 持久化存储，独立于代码部署 |
| 修改奖励内容 | 不会 | 只更新 codeData，quota key 不变 |
| 修改 perType（account/character 切换） | **会** | quota key 变了，相当于新的计数器 |
| 修改兑换码名称（如 RGXT → RGXT2） | **会** | 完全是一个新的兑换码 |
| 修改 maxUses / perUser 数值 | 不会 | quota 已消耗的次数不变，但上限会更新 |

> 切换限制维度（perType）本身就意味着重新定义规则，兑换记录重置是正常结果。

---

## 当前生效的兑换码列表

### 公开码

#### RGXT
- 奖励：灵韵 100 + 金条(gold_bar) x10
- 限制：无限次数，每人1次
- 限制维度：character（每角色）
- 目标：全体玩家
- 备注：新手欢迎礼包

#### RGXT099
- 奖励：灵韵 100
- 限制：无限次数，每人1次
- 限制维度：character（每角色）
- 目标：全体玩家
- 备注：新手欢迎礼包

#### LIANGJIE6
- 奖励：灵韵 100
- 限制：100次，每人1次
- 限制维度：character（每角色）
- 目标：全体玩家
- 备注：第六章激活码

---

### 活动码

#### LIUYI61FU
- 奖励：拨浪鼓(childday_rattle) x5 + 守护者证明(item_guardian_token) x1
- 限制：10次，每人1次
- 限制维度：account（每账号）
- 目标：全体玩家
- 备注：六一福利

---

### 通用奖励码

#### LY1K7JAH
- 奖励：灵韵 1000
- 限制：10次，每人1次
- 限制维度：account（每账号）
- 目标：全体玩家

#### LY1W9QBZ
- 奖励：灵韵 10000 (1W)
- 限制：10次，每人1次
- 限制维度：account（每账号）
- 目标：全体玩家

#### SH5XQTR7
- 奖励：先行者称号(pioneer) + 守护者证明(item_guardian_token) x1
- 限制：5次，每人1次
- 限制维度：account（每账号）
- 目标：全体玩家

---

## 已废除/注销的兑换码

| 兑换码 | 原因 |
|--------|------|
| TAIXU666 | 已废除 |
| VIP1144A | 已废除（专属码清理） |
| VIP849A | 已废除（专属码清理） |
| VIP230B | 已废除 |
| VIP230C | 已废除（专属码清理） |
| VIP1503A | 已废除（专属码清理） |
| SHOUHU873V2 | 已废除 |
| SUIPIAN2019 | 已废除 |
| SHOUHU849V2 | 已废除 |
| BUFA873 | 已废除 |
| VIP873A | 已废除 |
| VIP116A | 已废除 |
| VIP2019A | 已废除 |
| VIP579A | 已废除 |
| VIP1074A | 已废除 |
| VIP376A | 已废除 |
| VIP230A | 已废除 |
| VIP873B | 已废除 |
| VIP376B | 已废除 |
| LIUYI2026 | 已注销（六一活动结束） |
| DUANWU2026 | 已废除 |
| JXC7KM2Q | 已废除 |
| R4WNTX8E | 已废除 |
| PH6DZYA3 | 已废除 |
| V9BSGF5L | 已废除 |
| W2XJCN6H | 已废除 |
| LY10W6RX | 已废除 |
| LY1W5PKD | 已废除 |

---

*最后更新: 2026-07-04*
