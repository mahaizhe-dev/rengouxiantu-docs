# 资源生成 Skill 编写计划书

> 日期：2026-05-15
>
> 对应设计稿：
> - `docs/架构文档/资源生成Skill设计方案.md`
> - `docs/架构文档/rules.md`
> - `docs/架构文档/npc-portrait-spec.md`
>
> 本地精灵参考：
> - `assets/Textures/player_right.png`
> - `assets/Textures/class_swordsman_right.png`
> - `assets/Textures/class_body_cultivator_right.png`
> - `assets/Textures/class_formation_master_right.png`
>
> 用途：本计划书不是资源规范文档，而是交给另一位 AI 执行的 `SKILL` 编写任务说明。目标是让对方直接按计划产出可用 skill，而不是重新做方案设计。

---

## 0. 任务目标

需要另一位 AI 编写一个正式可用的资源生成 skill，用于《人狗仙途》的美术资源生成场景。

这次任务的目标不是：

- 重新讨论资源规范
- 重新决定怪物分类
- 重新决定正视角定义
- 重新发散 skill 范围

这次任务的目标是：

1. 把现有方案固化成一个正式 skill。
2. 保证 skill 可触发、可读、可扩展。
3. 让 skill 在实际使用时默认套用规则，不再每次重复长篇说明。

---

## 1. 交付范围

另一位 AI 需要交付的内容，限定为 skill 本身及其必要文件。

### 1.1 必交付

- `rengouxiantu-asset-generator/SKILL.md`

### 1.2 建议交付

- `rengouxiantu-asset-generator/references/asset-standards.md`
- `rengouxiantu-asset-generator/references/front-view-spec.md`
- `rengouxiantu-asset-generator/references/naming-rules.md`
- `rengouxiantu-asset-generator/references/prompt-examples.md`

### 1.3 本期不交付

- 资源图片本体
- 自动生成图片脚本
- README
- 安装指南
- 额外说明文档

结论：

- 这是一个“文档型 skill”交付。
- `v1` 不要求脚本化，不要求 prompt 生成器，不要求模板资产包。

---

## 2. skill 基本定位

skill 名称固定建议为：

- `rengouxiantu-asset-generator`

skill 要覆盖的资源类型固定为：

- 瓦片
- 装饰物贴图
- 大型物件贴图（`N×N`）
- 地表贴花
- 特效资源
- 角色图 / NPC 图
- 装备图标
- 小怪展示图
- 精英头像
- BOSS 全身图

另一位 AI 不需要再扩展到以下内容：

- UI 截图设计
- 横幅海报
- 立绘宣传图
- 3D 模型
- Spine 动画

---

## 3. 编写原则

另一位 AI 必须按下面原则写 skill。

### 3.1 不重复设计稿

资源规则已经在设计稿中定过，skill 编写时不要重新发明一套说法。

应该做的是：

- 提炼成触发逻辑
- 提炼成默认规则
- 提炼成分类流程
- 提炼成使用时的响应方式

不应该做的是：

- 再写一份新的大而全方案
- 把所有设计稿原文塞进 `SKILL.md`
- 在 `SKILL.md` 里堆大量示例和解释

### 3.2 保持 Progressive Disclosure

`SKILL.md` 只保留高频核心逻辑：

- 什么时候触发
- 如何分类
- 默认规则是什么
- 什么情况读哪个 references 文件

细节下沉到 `references/`：

- 规格表
- 正视角定义
- 命名规则
- prompt 模板

### 3.3 skill 是执行说明，不是方案评审

另一位 AI 写出来的 skill 应该像“操作手册”，而不是“讨论稿”。

要求：

- 用命令式表达
- 用短句
- 用判断分支
- 用清晰的资源分类入口

避免：

- 大段背景说明
- 方案来龙去脉
- 过多设计原因复述

### 3.4 v1 不上脚本

本期不要求：

- `scripts/build_prompt.*`
- `scripts/validate_asset_request.*`
- 自动命名脚本

只有在另一位 AI 明确发现：

- 纯文档版无法稳定执行
- 同一段 prompt 生成逻辑已经重复到失控

才允许建议 `v2` 补脚本，但本次交付不做。

---

## 4. 另一位 AI 的输入材料

另一位 AI 必须先阅读下面三份文档，再开始写 skill。

### 4.1 必读

- `docs/架构文档/资源生成Skill设计方案.md`
- `docs/架构文档/rules.md`
- `docs/架构文档/npc-portrait-spec.md`

### 4.2 本地参考资源

另一位 AI 还必须参考当前本地的四张角色精灵图。

路径（相对 workspace）：

- `assets/Textures/player_right.png`
- `assets/Textures/class_swordsman_right.png`
- `assets/Textures/class_body_cultivator_right.png`
- `assets/Textures/class_formation_master_right.png`

目的不是读取具体角色设定，而是提取像素风格基线：

- `256x256` 透明底
- 全身主体完整
- 单体居中
- 中高像素密度
- 干净轮廓线
- 不是超复古低细节块面风

注意：

- 当前本地没有可供参考的装备图标、NPC 图、怪物图 PNG 现货。
- 装备图标规则继续沿用现有已验证规则，但不是从本地图片抽样得出的。

### 4.3 阅读目标

读取这三份文档时，不是为了继续设计，而是为了提取：

1. 哪些规则是常驻规则。
2. 哪些规则属于分类后才使用的附加规则。
3. 哪些内容必须进入 `SKILL.md`。
4. 哪些内容应该拆去 `references/`。

---

## 5. 目标目录结构

另一位 AI 最终应产出的目录结构建议如下：

```text
rengouxiantu-asset-generator/
├── SKILL.md
└── references/
    ├── asset-standards.md
    ├── front-view-spec.md
    ├── naming-rules.md
    └── prompt-examples.md
```

说明：

- `SKILL.md` 是必需。
- `references/` 控制在一层，不再继续嵌套。

禁止额外添加：

- `README.md`
- `CHANGELOG.md`
- `INSTALL.md`
- `notes.md`

---

## 6. `SKILL.md` 编写任务拆解

这是本计划书的核心。

另一位 AI 要写的不是“自由发挥版 SKILL.md”，而是按下面模块完成。

### 6.1 Frontmatter

必须只有两个字段：

- `name`
- `description`

要求：

- `name` 固定为 `rengouxiantu-asset-generator`
- `description` 必须同时包含：
  - skill 做什么
  - 什么时候触发
  - 触发词示例
  - 覆盖的资源类型

`description` 必须明确写出这些触发语义：

- 瓦片
- 贴图
- 装饰物
- 大型物件
- `N×N`
- 特效
- 刀光
- 爆炸
- 护盾
- NPC 图
- 怪物头像
- 精英头像
- BOSS 全身图
- 装备图标

### 6.2 开头总则

`SKILL.md` 正文开头必须先说明：

1. 先判断资源类型。
2. 再套用默认规格。
3. 默认规则不需要每次重复给用户。
4. 生成后先预览，等用户确认，再接入代码或配置。

这一段要短，不要展开成长文。

### 6.3 默认规则区

必须在 `SKILL.md` 中保留一个很短的默认规则区，内容只保留高频项：

- 世界观：仙侠修仙
- 风格：像素风
- 输出：PNG
- 默认禁止：文字、水印、UI
- 同类资源保持统一视角和尺寸

不要把所有尺寸细节都塞进这里。

### 6.4 分类规则区

这一段必须成为 `SKILL.md` 的主入口。

必须明确列出并区分：

- 装备图标
- 角色 / NPC 图
- 小怪展示图
- 精英头像
- BOSS 全身图
- 特效资源
- 瓦片
- 装饰物贴图
- 大型物件贴图（`N×N`）
- 地表贴花

要求：

- 每类只写最关键的 1 到 3 条识别规则
- 不要在这里铺完整规格表
- 详细规格跳转 `references/asset-standards.md`

### 6.5 关键分流规则

`SKILL.md` 中必须有两条硬分流：

#### A. 装饰物贴图 vs 地表贴花

必须明确：

- 立起来的地图物件 → 装饰物贴图
- 贴在地上的覆盖层 → 地表贴花

#### B. 单格物件 vs `N×N` 大型物件

必须明确：

- 默认单格立式物件按普通装饰物处理
- 一旦用户给出明确占地，如 `2×2`、`3×3`、`4×4`，改判为大型物件贴图

#### C. 特效资源 vs 地表贴花

必须明确：

- 战斗或场景叠加用的独立视觉元素 → 特效资源
- 贴在地上的固定覆盖层 → 地表贴花

特效资源默认 `256x256`、透明背景、主体居中、便于叠加。

#### D. 小怪 / 精英 / BOSS

必须明确：

- 小怪：单体展示图，根据体型选择构图——大型人形/兽类可用胸像，小型兽类、虫类、鸟类必须保留整体轮廓和全身识别
- 精英：胸像构图为主，特征强化
- BOSS：全身图

另一位 AI 不允许把这三类重新合并成一个“怪物图”。

#### E. 默认规格 vs 明确例外

必须明确：

- 装备图标规则继续纳入正式 skill
- BOSS 默认 `256x256`，但用户明确特别注明时允许例外尺寸
- 大型立式物件默认高度规则固定，只有用户明确特别注明“允许超高”时才允许更高画布

### 6.6 references 导航区

`SKILL.md` 必须明确告诉后续模型：

- 查尺寸 / 背景 / 构图 → `references/asset-standards.md`
- 查正视角定义 → `references/front-view-spec.md`
- 查命名规范 → `references/naming-rules.md`
- 查 prompt 模板 → `references/prompt-examples.md`

要求：

- 只做一层链接
- 不再出现二级 references

### 6.7 输出行为区

`SKILL.md` 里必须约束对外响应方式：

- 不要每次重复常规规范
- 默认只输出本次变量
- 必要时再展开完整规格

默认输出格式固定为四行：

```text
资源类型：...
本次变量：...
默认规格：已按 skill 内置规则处理
文件名建议：...
```

同时必须保留确认流程：

1. 判断资源类型
2. 提取变量
3. 生成 prompt
4. 生成图片并展示预览
5. 等用户确认后再接入

---

## 7. `references/` 文件编写任务

### 7.1 `references/asset-standards.md`

这份文件负责装全部规格表，不要放流程。

必须包含：

- 各资源类型的尺寸
- 背景透明规则
- 视角
- 构图要求
- 怪物三档差异
- 特效资源规范
- `N×N` 大型物件的占地与画布规则
- 本地三张角色精灵提取出的像素风格基线

建议结构：

1. 通用规则
2. 装备图标
3. 角色 / NPC 图
4. 小怪展示图
5. 精英头像
6. BOSS 全身图
7. 特效资源
8. 瓦片
9. 装饰物贴图
10. 大型物件贴图
11. 地表贴花

### 7.2 `references/front-view-spec.md`

这份文件只做一件事：

- 把“正视角”写清楚

必须包含：

- 正确定义
- 错误示例类型
- 与俯视角的边界
- 与 `N×N` 立式大型物件的关系

要求：

- 这份文件不能被其他无关内容稀释
- 必须能单独解决“用户说正视角时到底是什么意思”

### 7.3 `references/naming-rules.md`

必须包含：

- 装备图标命名
- NPC 图命名
- 小怪 / 精英 / BOSS 命名
- 特效资源命名
- 瓦片命名
- 装饰物命名
- `N×N` 大型物件命名
- 地表贴花命名

要求：

- 稳定可检索
- 不自动加时间戳
- 文件名前缀统一
- **怪物命名必须对齐现有 60+ 文件的后缀模式**：`monster_{name}[_{role}].png`（角色后缀），例如 `monster_spider_elite.png`、`monster_bandit_boss.png`、`monster_boar_small.png`。不要使用 `monster_elite_{id}.png` 这种角色前缀模式

### 7.4 `references/prompt-examples.md`

必须包含每类资源的 prompt 骨架。

必须覆盖：

- 装备图标
- NPC 图
- 小怪展示图
- 精英头像
- BOSS 全身图
- 特效资源
- 瓦片
- 装饰物贴图
- `N×N` 大型物件
- 地表贴花

要求：

- 用“骨架模板 + 1 个简短示例”形式
- 不要堆大量冗长案例
- 对小怪模板补一条例外说明：小型怪兽优先保留整体，不强裁胸像

---

## 8. 非目标与禁止事项

另一位 AI 在编写 skill 时，禁止做以下事情：

### 8.1 禁止重新设计规则

下面这些规则已定，不再改：

- 怪物三档拆分
- BOSS 使用全身图
- 小型怪兽保留整体轮廓优先
- 特效资源独立成类，默认 `256x256` 透明背景
- 装饰物贴图采用 RPG Maker 正视角
- 地表贴花使用俯视角
- `N×N` 为逻辑占地
- 装备图标继续纳入正式 skill
- BOSS 与大型立式物件只在“明确特别注明”的情况下允许例外尺寸 / 超高

### 8.2 禁止把细节全部塞进 `SKILL.md`

如果另一位 AI 写出一个 300 到 500 行以上、且大部分是规格表的 `SKILL.md`，说明结构失败。

### 8.3 禁止新增无关文件

不要创建：

- README
- 快速手册
- 变更日志
- 临时说明

### 8.4 禁止把 v1 复杂化

不要为了“看起来完整”而强行加入：

- prompt 自动拼装脚本
- 请求解析器
- 资源校验脚本
- 图像后处理脚本

---

## 9. 推荐执行顺序

另一位 AI 应按下面顺序工作。

### 第一步：吃透输入材料

阅读：

- `资源生成Skill设计方案.md`
- `rules.md`
- `npc-portrait-spec.md`

输出目标：

- 完成资源分类表
- 确认 references 拆分边界

### 第二步：先搭 skill 目录

先创建：

- `SKILL.md`
- `references/`

不要一开始就直接写长文。

### 第三步：先写 `SKILL.md` 骨架

先写这些标题和空区块：

1. frontmatter
2. 默认规则
3. 分类
4. 分流规则
5. references 导航
6. 输出行为

确认骨架成立后，再填内容。

### 第四步：补 references

按重要性顺序写：

1. `asset-standards.md`
2. `front-view-spec.md`
3. `naming-rules.md`
4. `prompt-examples.md`

### 第五步：自检

检查：

1. 是否所有资源类型都能被分类
2. 是否存在“怪物图”这种模糊旧说法
3. 是否把装饰物 / 大型物件 / 地表贴花混写
4. 是否把完整规格表错误堆进 `SKILL.md`
5. 是否出现多余文档

---

## 10. 验收标准

只要满足下面标准，就算另一位 AI 完成任务。

### 10.1 结构验收

- skill 目录结构正确
- `SKILL.md` 可独立触发
- `references/` 文件拆分合理
- 无多余文档

### 10.2 内容验收

- 覆盖全部目标资源类型
- 怪物资源明确分为小怪展示图、精英胸像、BOSS 全身图
- 小怪构图规则正确：大型人形/兽类可用胸像，小型兽类/虫类/鸟类保留整体轮廓
- 特效资源被独立成类，且与地表贴花边界清晰
- `N×N` 大型物件规则明确
- BOSS 例外尺寸与大型物件“允许超高”例外被正确写入
- 正视角定义明确且未与俯视角混淆
- 命名规则完整

### 10.3 使用验收

拿以下请求测试时，skill 都应能正确分类：

1. “生成一个 128x128 的沙地瓦片”
2. “做一个宝箱贴图，RPGmaker 正视角”
3. “做一个 3x3 的大型祭坛贴图”
4. “做一个狼妖小怪展示图”
5. “做一个蛇王精英头像”
6. “做一个章节 BOSS 全身图”
7. “做一个地面裂纹贴花”
8. “做一个 256x256 的火焰爆炸特效资源”

如果这 8 类请求不能稳定落到正确分类，说明 skill 仍未完成。

---

## 11. 最终交付说明

另一位 AI 完成后，应向你交付的是：

1. skill 所在路径
2. 交付文件清单
3. `SKILL.md` 的简要结构说明
4. 一次自检结果

不需要交付：

- 长篇设计复盘
- 再写一版方案
- 重复介绍资源规范

---

## 12. 一句话任务指令

如果要把任务直接发给另一位 AI，可以用下面这句：

> 请根据 `docs/架构文档/资源生成Skill设计方案.md`、`docs/架构文档/rules.md`、`docs/架构文档/npc-portrait-spec.md`，编写正式可用的 `rengouxiantu-asset-generator` skill。保持 `SKILL.md` 精简，把详细规格拆到 `references/`，严格保留小怪展示图 / 精英头像 / BOSS 全身图、特效资源独立分类、装饰物正视角、`N×N` 大型物件占地规则，不要新增无关文档或脚本。

---

## 13. 后续同步提醒

> **Skill 落地后需同步 `rules.md`**
>
> 当前 `docs/架构文档/rules.md` §2（图片制作标准）仅覆盖：装备图标、角色图、NPC 图、怪物图（未分层）。
> 本 skill 新增的以下资源类型尚未写入 `rules.md`：
>
> - 特效资源（刀光、爆炸、护盾等）
> - 装饰物贴图（RPG Maker 正视角）
> - 大型物件贴图（N×N 占地规则）
> - 地表贴花
> - 怪物三档分层（小怪展示图 / 精英头像 / BOSS 全身图）
>
> Skill 验收通过后，应由人工或下一轮 AI 将上述规格补入 `rules.md` §2，确保全项目文档一致。
