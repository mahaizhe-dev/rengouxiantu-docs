# UI 重构方案与过程文档

> **目的**：供其他 AI/开发者交叉审查本轮 UI 架构改造的设计决策与实施路径。
> **范围**：角色面板（CharacterUI）、装备商人面板（EquipShopUI）、炼丹炉面板（AlchemyUI）。
> **时间**：2026-06-07 ~ 2026-06-10

---

## 目录

1. [设计原则总纲](#1-设计原则总纲)
2. [装备商人面板重构（已完成）](#2-装备商人面板重构已完成)
3. [角色面板重构（已完成）](#3-角色面板重构已完成)
4. [炼丹炉面板重构（已完成）](#4-炼丹炉面板重构已完成)
5. [共享组件清单](#5-共享组件清单)
6. [UITheme 设计令牌体系](#6-uitheme-设计令牌体系)
7. [四阶段迭代方法论](#7-四阶段迭代方法论)
8. [审查要点与疑问清单](#8-审查要点与疑问清单)

---

## 1. 设计原则总纲

### 1.1 视觉规范："仙侠暗金"风格

| 维度 | 规范 |
|------|------|
| 主色调 | 深蓝黑底 `{25,28,38}` + 金色强调 `{255,220,150}` |
| 品质色阶 | white → green → blue → purple → orange → red，逐级提升辉光强度 |
| 面层级 | `surfaceDeep → surface → surfaceLight → panelBg`，由暗到亮四级 |
| 文字层级 | `textPrimary(白) → textSecondary(灰蓝) → textMuted(暗灰)` |
| 圆角 | sm=6 / md=10 / lg=14，由内到外递增 |
| 间距 | xxs=2 / xs=4 / sm=8 / md=12 / lg=16 / xl=24，8px 为基础单位 |

### 1.2 架构原则

1. **令牌驱动**：所有颜色/尺寸/间距通过 `UITheme.lua` 中心化管理，禁止硬编码 RGBA
2. **骨架统一**：所有面板共用 `PanelShell`（overlay → card → header → scroll → footer）
3. **组件复用**：可复用 UI 原子提取到 `scripts/ui/components/`，跨面板共享
4. **数据驱动**：UI 只负责渲染，业务逻辑剥离到 `systems/` 或 `config/`
5. **渐进迁移**：新增令牌只允许追加，不改动已有令牌语义；一次只迁移一个面板系统
6. **组件委托**：面板内工厂函数与共享组件功能重叠时，委托给共享组件而非重复实现

### 1.3 图标规格

| 用途 | 尺寸 | 说明 |
|------|------|------|
| 物品/装备格子 | 56×56px (`T.size.slotSize`) | 品质辉光边框 + 底色微光 |
| 技能/被动卡片图标 | 56×56px | 与装备格子同规格，保持视觉一致 |
| 工具按钮 | 48px | 底栏操作按钮 |
| 关闭按钮 | 36px | 面板右上角 |

图标命名约定：
- 装备图标：`icon_t{tier}_{slot}.png`（如 `icon_t3_weapon.png`）
- 技能书图标：`book_{stat}.png`（如 `book_atk.png`）

---

## 2. 装备商人面板重构（已完成）

### 2.1 重构前状态

原 `EquipShopUI.lua` 单文件约 900+ 行，存在：
- 大量硬编码 RGBA 颜色值（约 40+ 处）
- 没有骨架复用（每个面板手写 overlay + card + header）
- 商品行手工构建，无统一 slot 组件
- 价格标签格式不统一（有的用 emoji，有的用文字拼接）

### 2.2 重构决策与实施

#### 第一步：提取 PanelShell

**决策**：所有 NPC 交互面板共享同一骨架结构。

```
overlay (半透遮罩, 点击关闭)
└── card (panelBg + goldDark边框 + lg圆角)
    ├── header (标题 + 头像/图标 + 关闭按钮)
    ├── ScrollView (可滚动内容区)
    └── footer (操作结果 + 提示)
```

**实现**：`scripts/ui/components/PanelShell.lua`
- 支持 portrait（左侧头像）、title/subtitle、onClose、footerHint
- 提供 `AddContent`/`ClearContent`/`SetResult`/`Show`/`Hide` 方法
- 面板尺寸响应式：`width="94%", maxWidth=T.size.npcPanelMaxW(500px), maxHeight="76%"`

#### 第二步：提取 ItemSlot

**决策**：56px 格子是整个游戏的原子视觉单位，装备/道具/宠物/技能书都用同规格。

**实现**：`scripts/ui/components/ItemSlot.lua`
- 品质辉光：`T.qualityBorder[quality]` 作为 borderColor（带透明度渐变）
- 品质底色：`T.decor.qualitySlotBg[quality]` 微透明底色
- 支持贴图 icon 或 emoji 占位
- 支持 onClick 时自动包裹 Button

#### 第三步：提取 PriceTag

**决策**：金币/灵韵价格出现在商人、黑市、炼丹等多处，统一标签样式。

**实现**：`scripts/ui/components/PriceTag.lua`
- 自动判断 currency（gold/lingyin）对应 emoji + 配色
- 自动对比 balance，余额不足时文字变红（`T.color.error`）
- 大数额自动缩写（10000+ → "1.0w"）
- 便捷工厂：`PriceTag.Gold(1000, balance)` / `PriceTag.LingYin(50, balance)`

#### 第四步：颜色令牌化

**决策**：全面审计硬编码 RGBA，归入 UITheme 语义令牌。

审计结果：
- 40+ 处硬编码颜色全部替换为 `T.color.xxx` / `T.qualityBorder.xxx` / `T.decor.xxx`
- 新增令牌：`surface`/`surfaceLight`/`headerBg`/`border`/`borderLight` 面层级
- 新增令牌：`textPrimary`/`textSecondary`/`textMuted` 文字层级
- 新增令牌：`success`/`error`/`warning`/`info` 语义色
- 新增令牌：`gold`/`goldDark`/`jade`/`jadeDark` 强调色

### 2.3 重构后结构

```
EquipShopUI.lua (639行)
├── 引用 PanelShell → 骨架
├── 引用 ItemSlot   → 商品图标
├── 引用 PriceTag   → 价格标签
├── 引用 T.*        → 所有视觉参数
├── BuildChXItems() → 按章节构建商品数据（纯数据）
└── BuildShopRow()  → 通用商品行渲染器
```

### 2.4 成效

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| 硬编码颜色 | ~40处 | 0 |
| 面板骨架代码 | 每文件80+行 | `PanelShell.Create()` 1行 |
| 图标组件重复 | 各面板各写一套 | `ItemSlot.Create()` 统一 |
| 价格标签 | 各处格式不同 | `PriceTag.Create()` 统一 |

---

## 3. 角色面板重构（已完成）

### 3.1 重构前状态

原 `CharacterUI.lua` 单文件 1200+ 行，包含：
- Tab 切换逻辑
- 属性展示（35+ 属性行，每行手动构建）
- 技能/丹药展示（每种丹药硬编码一个 UI 块）
- 称号/收藏展示
- 大量重复的属性行构建代码

### 3.2 重构决策与实施

#### Phase 1：Tab 结构拆分

**决策**：角色面板内容复杂，按 Tab 拆分为独立模块。

```
CharacterUI.lua (194行, 主控)
├── CharacterTab1.lua (243行, 属性面板)
├── CharacterTab2.lua (356行, 技能/被动)
└── CharacterTab3.lua (362行, 称号/丹药/收藏)
```

**关键实现**：
- `CharacterUI.lua` 只负责 Tab 切换 + PanelShell 骨架
- 各 Tab 暴露 `Build()` 方法返回 children 数组
- Tab 按钮等宽分布，使用 `flexGrow=1, flexBasis=0` 均分

#### Phase 2：属性行组件提取

**决策**：35+ 属性行具有相同模式（label + value），提取通用组件。

| 组件 | 用途 | 特点 |
|------|------|------|
| `StatRow` | 基础属性行 | label/value 两列，交替底色（奇偶行） |
| `StatRowTip` | 带提示属性行 | StatRow + 右侧 "!" 按钮，展开详情说明 |
| `IconStatRow` | 图标属性行 | 图标 + 名称 + 状态标签 + 数值（丹药/区域加成） |

**StatRow 关键设计**：
```lua
-- 内部计数器实现交替底色（不依赖外部状态）
local rowCounter_ = 0
function StatRow.ResetCounter() rowCounter_ = 0 end
function StatRow.Create(opts)
    rowCounter_ = rowCounter_ + 1
    local bgColor = (rowCounter_ % 2 == 0) and T.color.rowAlt or nil
    ...
end
```

#### Phase 3：技能卡片组件

**决策**：宠物面板和角色面板都有技能展示，提取统一的 `SkillCard` 组件。

**排版参考**：宠物面板·固有技能区的竖向堆叠布局。

```
┌─────────────────────────────────┐ ← surfaceDeep + 1px border
│ [56px图标] │ 名称（粗体，暖白）          │
│            │ 描述（灰色，可换行）         │
│            │ CD 3.0s  伤害 150%（暖色）   │
└─────────────────────────────────┘
```

**被动技能变体**（ArtifactPassiveCard）：
- 左侧 3px 蓝色竖条 (`T.color.accentPassive`)
- `overflow = "hidden"` + `alignItems = "stretch"`
- 其余布局与 SkillCard 一致

#### Phase 4：视觉细节调优

根据用户反馈逐步调整：

1. **每个技能条独立底色**：添加 `surfaceDeep = {25,28,40,230}` 令牌，使技能卡片与外层 `surface` 形成视觉分层
2. **图标尺寸统一为装备规格**：从 32px 调整到 56px（`T.size.slotSize`），与 ItemSlot 视觉一致
3. **边框强化**：每个 SkillCard 添加 `borderWidth=1, borderColor=T.color.border`

#### Phase 5：SectionCard + SectionHeader 提取

**决策**：多个 Tab 都有"分组"概念（一个标题 + 一组内容），统一为 SectionCard。

```lua
-- SectionCard: surface底色 + borderLight + sm圆角 + 内边距
SectionCard.Create({
    title = "固有技能",
    children = { SkillCard.Create(...), SkillCard.Create(...) }
})

-- SectionHeader: 独立标题行（仅标题，不含容器）
SectionHeader.Create({ title = "基础属性", icon = "⚔️" })
```

### 3.3 重构后目录结构

```
scripts/ui/
├── CharacterUI.lua     (194行) -- 主控 + PanelShell + Tab切换
├── CharacterTab1.lua   (243行) -- 属性面板（StatRow × 35+）
├── CharacterTab2.lua   (356行) -- 技能面板（SkillCard + ArtifactPassiveCard）
├── CharacterTab3.lua   (362行) -- 称号/丹药/收藏（IconStatRow）
└── components/
    ├── PanelShell.lua          -- 标准面板骨架
    ├── ItemSlot.lua            -- 56px 品质格子
    ├── PriceTag.lua            -- 价格标签
    ├── SectionCard.lua         -- 分组卡片容器
    ├── SectionHeader.lua       -- 分组标题行
    ├── StatRow.lua             -- 基础属性行
    ├── StatRowTip.lua          -- 带提示属性行
    ├── IconStatRow.lua         -- 图标状态行
    ├── SkillCard.lua           -- 技能卡片（56px图标+纵向堆叠）
    └── ArtifactPassiveCard.lua -- 被动技能卡片（左蓝竖条）
```

### 3.4 成效

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| 主文件行数 | 1200+ 行 | 194 行（主控） |
| 总行数 | ~1200 行 | ~1155 行（拆分为 5 文件） |
| 硬编码颜色 | ~60处 | 0 |
| 重复属性行代码 | 每行 8-12 行手写 | `StatRow.Create()` 1行调用 |
| 技能卡片重复 | 各面板各写 | `SkillCard.Create()` 统一 |
| 跨面板复用 | 不可能 | 10 个共享组件可任意组合 |

---

## 4. 炼丹炉面板重构（已完成）

### 4.1 重构前状态

**`AlchemyUI.lua`** — 1891 行，是当前最大的 UI 单文件。

| 问题 | 具体表现 |
|------|---------|
| **每种丹药硬编码** | 每章有独立的 `BuildChXContent()` 函数（5个章节 × 平均 80 行 = 400+ 行） |
| **每种丹药硬编码炼制函数** | `DoCraftTiger()`, `DoCraftSnake()`, `DoCraftDiamond()` 等约 15 个独立函数 |
| **状态散布** | `tigerPillCount_`, `snakePillCount_`, `diamondPillCount_`... 约 8 个模块级变量 |
| **UI 与逻辑混合** | 扣减灵韵、增加属性、修改存档全在 UI 回调中 |
| **重复代码模式** | 每种丹药的 UI 块完全相同的模式重复 15+ 次（标题→说明→进度→材料→按钮） |
| **无共享组件** | 不使用 PanelShell/ItemSlot/PriceTag 等已有组件 |

### 4.2 四阶段实施记录

本次重构严格遵循**四阶段迭代流程**（见第 7 节方法论），以下记录每个阶段的实际产出。

#### 阶段一：结构梳理（数据-逻辑-UI 三层分离）

**决策**：将 1891 行单文件拆为三层架构。

```
[重构后文件结构]

scripts/config/PillRecipes.lua      (198行) -- 纯数据：所有丹药配方定义
scripts/systems/AlchemySystem.lua   (422行) -- 数据层：运行时状态 + 校验 + 炼制逻辑
scripts/ui/AlchemyUI.lua            (956行) -- UI层：数据驱动通用渲染器
```

**数据层 `PillRecipes.lua`**：
- 集中定义所有丹药配方（id、名称、图标、章节、类型、花费、产出、限购）
- 按 chapter 预索引 `BY_CHAPTER[ch]` 供 UI 查询
- 纯静态数据，零运行时状态

**逻辑层 `AlchemySystem.lua`**：
- 持有 7 个核心丹药计数的运行时真值
- 提供 `CanCraft(recipe)` / `DoCraft(recipe)` / `GetCraftCount(id)` 接口
- 与 GameState/SaveSession 对接，UI 不再直接操作存档
- 炼制结果通过 EventBus 广播，UI 监听刷新

**UI 层 `AlchemyUI.lua`**：
- 通用丹药行渲染器 `BuildPillRow(recipe)` 替代 15+ 个硬编码函数
- 按当前章节从 `PillRecipes.BY_CHAPTER` 取数据，循环渲染
- 使用 PanelShell 骨架 + 160px 炼丹炉 PNG 头像

#### 阶段二：组件抽取

**抽取 1：CategoryBadge（新建共享组件）**

发现 AlchemyUI 的分类标签（修炼丹、强化丹、辅助丹等）与其他面板的标签徽章模式一致，提取为通用组件。

```lua
-- scripts/ui/components/CategoryBadge.lua
local CategoryBadge = {}

-- 预设配色方案（从 AlchemyUI 提炼）
CategoryBadge.PRESETS = {
    cultivation = { text = "修炼丹", bgColor = {...}, fontColor = {...} },
    enhance     = { text = "强化丹", bgColor = {...}, fontColor = {...} },
    auxiliary   = { text = "辅助丹", bgColor = {...}, fontColor = {...} },
    token       = { text = "令牌盒", bgColor = {...}, fontColor = {...} },
    special     = { text = "特殊",   bgColor = {...}, fontColor = {...} },
}

--- 从预设创建
function CategoryBadge.FromPreset(key) ... end

--- 自定义创建
function CategoryBadge.Create(cfg) ... end
```

**抽取 2：CreatePillIcon 委托给 ItemSlot**

原 AlchemyUI 的 `CreatePillIcon(iconFile, quality)` 手动构建品质框+贴图，与 `ItemSlot.Create()` 功能重叠。改为委托模式：

```lua
--- 创建丹药图标（委托给共享组件 ItemSlot）
local function CreatePillIcon(iconFile, quality)
    return ItemSlot.Create({ icon = iconFile, quality = quality or "blue" })
end
```

**组件委托原则**：面板内部保留语义清晰的工厂函数名（`CreatePillIcon`），实现体委托给共享组件（`ItemSlot`），兼顾可读性与复用性。

#### 阶段三：规则沉淀

本轮迭代中发现的引擎约束和最佳实践，已沉淀到 `ui-rensheng-standard` skill 文档：

| 新增规则 | 内容 | 来源场景 |
|---------|------|---------|
| S0.1 图片渲染 | 无 `UI.Image`，用 `backgroundImage` | ItemSlot 渲染贴图图标 |
| S0.2 PanelShell 自适应高度 | ScrollView 仅 `flexShrink=1`，不加 `flexGrow=1` | 炼丹面板高度溢出 |
| S0.3 gap 必须用令牌 | 禁止硬编码数字 `gap=2`，用 `T.spacing.xxs` | 全面审计间距值 |
| S1.2 间距阶梯 | `xxs=2 / xs=4 / sm=8 / md=12 / lg=16 / xl=24` | 新增 xxs 层级 |
| S5.4 组件委托模式 | 内部工厂 → 委托共享组件，保留语义名 | CreatePillIcon → ItemSlot |

#### 阶段四：验收回归

**行数对比**：

| 文件 | 重构前 | 重构后 |
|------|--------|--------|
| AlchemyUI.lua | 1891 行（单文件） | 956 行 |
| PillRecipes.lua | （不存在） | 198 行 |
| AlchemySystem.lua | （不存在） | 422 行 |
| **合计** | **1891 行** | **1576 行**（-17%） |

**质量指标**：

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| 硬编码颜色 | ~50处 | 0（全部令牌化） |
| 丹药行重复代码 | 15×80行 | 通用 `BuildPillRow()` 1处 |
| 炼制逻辑耦合位置 | UI 回调内 | AlchemySystem 统一收口 |
| 新增丹药工作量 | ~80行手写 | PillRecipes 加 1 条记录 |
| 共享组件使用 | 0 | PanelShell + ItemSlot + CategoryBadge |
| 面板间可复用 | 否 | CategoryBadge 可跨面板复用 |

**功能验收**：
- 炼丹炉打开/关闭正常
- 各章节丹药列表正确显示
- 炼制扣减/产出逻辑正确
- 限购进度正确同步
- 灵韵不足/材料不足提示正常
- 存档兼容（旧版计数字段正确迁移）

### 4.3 关键设计决策记录

#### 决策 1：AlchemyUI 保留 956 行未进一步拆分

**原因**：虽然行数偏高（接近 1000 行阈值），但 AlchemyUI 含 160px 炼丹炉 PNG 图片布局、5 个章节 Tab、炼制动画效果等视觉逻辑，强拆为 Tab 文件反而增加跨文件状态同步复杂度。与角色面板（4 个独立 Tab 无共享状态）不同，炼丹面板的 Tab 间共享灵韵余额和炉温状态。

#### 决策 2：AlchemySystem 保留 422 行

**原因**：包含 7 种丹药各自不同的炼制条件校验（基础丹、永久丹、令牌盒、阵营丹等），简单 `CanCraft/DoCraft` 接口背后是不同 type 的分支逻辑。将来如果类型进一步增多，可按 type 拆为策略模式。

#### 决策 3：组件委托而非内联替换

**原因**：`CreatePillIcon` 保留为内部工厂名并委托给 `ItemSlot.Create()`，而非直接在调用处写 `ItemSlot.Create()`。好处：
1. 语义更清晰（读代码时知道"这是丹药图标"而非"这是通用格子"）
2. 将来如果丹药图标需要额外装饰（如"可炼制"角标），只改委托函数即可
3. 减少大面积改动引入的回归风险

---

## 5. 共享组件清单

| 组件 | 文件 | 用途 | 已使用面板 |
|------|------|------|-----------|
| `PanelShell` | components/PanelShell.lua | 标准面板骨架 | EquipShop, Character, Alchemy, BlackMerchant, Pet |
| `ItemSlot` | components/ItemSlot.lua | 56px品质格子 | EquipShop, BlackMerchant, Inventory, Alchemy |
| `CategoryBadge` | components/CategoryBadge.lua | 分类标签徽章（预设+自定义） | Alchemy |
| `PriceTag` | components/PriceTag.lua | 金币/灵韵价格标签 | EquipShop, BlackMerchant, Alchemy |
| `SectionCard` | components/SectionCard.lua | 分组卡片容器 | Character, Pet |
| `SectionHeader` | components/SectionHeader.lua | 分组标题行 | Character |
| `StatRow` | components/StatRow.lua | 基础属性行（交替底色） | CharacterTab1 |
| `StatRowTip` | components/StatRowTip.lua | 带提示属性行 | CharacterTab1 |
| `IconStatRow` | components/IconStatRow.lua | 图标+状态+数值行 | CharacterTab3 (丹药/区域) |
| `SkillCard` | components/SkillCard.lua | 技能卡片（56px图标+纵向堆叠） | CharacterTab2, Pet |
| `ArtifactPassiveCard` | components/ArtifactPassiveCard.lua | 被动技能卡片（左蓝竖条） | CharacterTab2 |

---

## 6. UITheme 设计令牌体系

### 6.1 完整令牌结构

```
UITheme
├── fontSize    (xs/sm/md/lg/xl/xxl/hero)
├── spacing     (xxs/xs/sm/md/lg/xl/safeTop)
├── radius      (sm/md/lg)
├── color
│   ├── 面层级: panelBg → headerBg → surface → surfaceDeep → surfaceLight
│   ├── 文字:   textPrimary → textSecondary → textMuted
│   ├── 语义:   success / error / warning / info
│   ├── 品质:   qualityWhite ~ qualityRed
│   ├── 强调:   gold / goldDark / jade / jadeDark
│   ├── Tab:    tabActiveBg / tabInactiveBg / tabActiveText / tabInactiveText
│   ├── 功能:   closeBtn / disabled / subText / rowAlt / accentPassive
│   ├── Badge:  badgeBg / badgeFont（分类标签通用配色）
│   └── 角色面板专用: nameHighlight / goldSoft / goldBgSubtle / bonusActive
├── qualityBorder (white~red, 带透明度)
├── decor
│   ├── headerBorderBottom
│   ├── dividerColor / dividerHeight
│   └── qualitySlotBg (white~red, 微透明底色)
├── size
│   ├── 按钮/图标: skillButton(56) / toolButton(48) / closeButton(36)
│   ├── 格子: slotSize(56)
│   ├── 进度条: hpBarHeight / expBarHeight / petHpBarHeight / monsterBarH
│   ├── 容器: smallPanelW / npcPanelMaxW / bottomBarMaxW
│   └── 标签: levelLabelW / resInfoW / statValueMinW
└── worldFont (NanoVG世界渲染字号)
```

### 6.2 扩展规则

- **只追加，不修改**：已有令牌一旦发布就不能改语义，只能新增
- **命名约定**：驼峰式，前缀表示归属（如 `tabActiveBg`、`qualityPurple`）
- **面板专用色**：当某面板有独特需求时，创建 `面板名+用途` 令牌（如 `artifactBgGold`）
- **透明度规范**：面层级 alpha ≥ 200；边框 alpha 80-200；微光底色 alpha 15-30
- **间距阶梯**：`xxs(2) → xs(4) → sm(8) → md(12) → lg(16) → xl(24)`，gap 必须选用此阶梯

---

## 7. 四阶段迭代方法论

> **每个面板的重构必须完整走完四个阶段**，不得跳过或合并。
> 此方法论从 AlchemyUI 重构中总结提炼，已沉淀到 `ui-rensheng-standard` skill 的 S6.2 节。

### 7.1 阶段定义

| 阶段 | 名称 | 目标 | 产出物 |
|------|------|------|--------|
| **Phase 1** | 结构梳理 + 风险评估 | 理清数据/逻辑/UI 边界，识别安全边界与风险点 | 三层文件 + 接口契约 + 风险矩阵 |
| **Phase 2** | 组件抽取 | 发现重复模式，提取/委托共享组件 | 新组件文件 + 委托函数 |
| **Phase 2.5** | 规范化比对 | 将重构产出与已有规范逐条对照，消灭偏差 | 比对清单（合规/偏差/修正） |
| **Phase 3** | 规则沉淀 | 将实践中发现的约束写入 skill 文档 | SKILL.md 新增/修改条目 |
| **Phase 4** | 验收回归 | 功能验证 + 指标对比 + 文档更新 | 本文档对应章节 |

### 7.2 阶段间依赖

```
Phase 1 (结构梳理 + 风险评估)
    │  产出：三层拆分方案 + 风险矩阵（概率/影响/缓解措施）
    │  Gate：风险矩阵无🔴高概率+高影响项 → 放行；否则须先设计降险方案
    │
    ▼  必须先完成三层拆分 + 确认安全边界，才能识别跨文件重复
Phase 2 (组件抽取)
    │
    ▼  组件/令牌接入完成后，对照规范逐条检查偏差
Phase 2.5 (规范化比对)
    │  产出：比对清单（合规项 / 偏差项 + 修正动作）
    │  Gate：偏差项全部修正并构建通过 → 放行
    │
    ▼  代码已严格合规，才能从中提炼新规则（否则规则本身就带偏差）
Phase 3 (规则沉淀)
    │
    ▼  规则确认后才可做最终验收
Phase 4 (验收回归)
```

### 7.3 各阶段检查清单

**Phase 1 完成标准**：
- [ ] 原单文件已拆为 config（纯数据）+ system（逻辑）+ UI（渲染）
- [ ] UI 层不直接操作存档/网络
- [ ] system 层暴露 `Can*/Do*/Get*` 清晰接口
- [ ] **风险矩阵已输出**（列出每项风险的概率/影响/等级/缓解措施）
- [ ] **安全边界已标注**（哪些接口签名/存储键名/外部调用点不可改动）
- [ ] 构建通过，功能不变

**Phase 2 完成标准**：
- [ ] 重复模式（≥2处相同结构）已识别并列清单
- [ ] 已有共享组件能覆盖的 → 委托
- [ ] 完全新模式（无现有组件） → 新建共享组件
- [ ] 委托函数保留语义名（如 `CreatePillIcon`）

**Phase 2.5 完成标准**：
- [ ] 逐条比对 UITheme 令牌覆盖率：零硬编码 RGBA 残留
- [ ] 逐条比对 PanelShell 接入规范：maxHeight / header / ScrollView flexShrink / border 等
- [ ] 逐条比对按钮色彩分类：btnSpend / btnDanger / btnSuccess / btnSecondary / btnDisabled 使用正确
- [ ] 逐条比对组件委托：已有共享组件能覆盖的场景无自建重复实现
- [ ] 偏差项已列出并全部修正
- [ ] 构建通过

**Phase 3 完成标准**：
- [ ] 新发现的引擎约束已写入 SKILL.md（S0 节）
- [ ] 新发现的最佳实践已写入 SKILL.md（对应 S 节）
- [ ] 新增令牌已在 S1 节登记

**Phase 4 完成标准**：
- [ ] 行数/硬编码/组件使用 等指标记录到本文档
- [ ] 关键设计决策有 "原因" 记录
- [ ] 功能回归测试通过
- [ ] 本文档对应章节已从 "待实施" 改为 "已完成"

### 7.4 Phase 1 风险评估模板

> 每次 Phase 1 结构梳理时，同步输出以下两部分：

**A. 风险矩阵**

| # | 风险项 | 概率 | 影响 | 等级 | 缓解措施 |
|---|--------|------|------|------|----------|
| 1 | （描述可能出错的事） | 低/中/高 | 🟢低/🟡中/🔴高 | 🟢/⚠️/🔴 | （做什么来避免或降低） |

等级计算：概率×影响 → 🟢可接受 / ⚠️需缓解 / 🔴阻塞（须先解决再继续）

**B. 安全边界清单**

列出**不可触碰**的接口/键名/调用点：

```
不可改动：
- Xxx.Serialize() / Xxx.Deserialize() 签名
- 存储键名: "xxx_field"
- 外部调用入口: Xxx.Create(parentOverlay) 返回值
```

**Gate 规则**：
- 风险矩阵中无 🔴（高概率+高影响）→ 直接进入 Phase 2
- 存在 🔴 → 必须先设计降险方案，经确认后再继续

---

### 7.5 适用范围

此四阶段流程适用于：
- 单文件 > 800 行的面板重构
- 涉及逻辑-UI 混合的面板整理
- 需要提取新共享组件的迁移

对于简单的令牌化替换（仅替换硬编码颜色，不改结构），可只做 Phase 1 + Phase 4。

---

## 8. 审查要点与疑问清单

### 8.1 已解决问题

| 原始疑问 | 解决方案 |
|---------|---------|
| PillRecipes 数据结构是否覆盖所有变体？ | 已覆盖：consumable / permanent / token_box，阵营丹用 `faction` 字段区分 |
| 存档迁移是否健壮？ | 已在 SaveMigrations 中写入 v17→v18 迁移，统一到 `player.pillCounts[id]` |
| 通用渲染器如何处理令牌盒分支？ | `BuildPillRow` 内部按 `recipe.type` 分支渲染不同消耗/产出描述 |
| `BuildPillRow` 应否提取为共享组件？ | 否。炼丹是唯一使用者，保留为内部函数 |

### 8.2 后续优化方向

1. **AlchemyUI 行数**：当前 956 行接近 1000 行阈值。若未来新增丹药类型导致超过 1000 行，考虑按 Tab 拆分（类似 CharacterUI）
2. **CategoryBadge 复用**：目前仅 AlchemyUI 使用，观察后续面板是否有标签徽章需求再决定是否扩展预设
3. **虚拟化**：当前丹药 < 20 种无需虚拟化；若扩展到 50+ 需启用 VirtualList

### 8.3 已知限制

- 本轮重构聚焦 UI 层面板结构和视觉规范化，**未涉及游戏逻辑本身的 refactor**（如战斗系统、存档系统）
- 组件未做性能优化（如虚拟化列表），当前数据量不需要

---

## 附录 A：文件修改清单（装备商人重构）

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `config/UITheme.lua` | 新建 | 完整设计令牌体系 |
| `ui/EquipShopUI.lua` | 重写 | 引入 PanelShell/ItemSlot/PriceTag，颜色全面令牌化 |
| `ui/components/PanelShell.lua` | 新建 | 标准面板骨架 |
| `ui/components/ItemSlot.lua` | 新建 | 56px品质格子 |
| `ui/components/PriceTag.lua` | 新建 | 价格标签 |

## 附录 B：文件修改清单（角色面板重构）

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `config/UITheme.lua` | 修改 | +surfaceDeep, +角色面板专用色, +rowAlt, +accentPassive |
| `ui/CharacterUI.lua` | 重写 | 1200行→194行，仅保留 Tab 切换和 PanelShell |
| `ui/CharacterTab1.lua` | 新建 | 属性面板（StatRow ×35+）|
| `ui/CharacterTab2.lua` | 新建 | 技能/被动面板（SkillCard + ArtifactPassiveCard）|
| `ui/CharacterTab3.lua` | 新建 | 称号/丹药/收藏面板（IconStatRow）|
| `ui/components/StatRow.lua` | 新建 | 基础属性行（交替底色）|
| `ui/components/StatRowTip.lua` | 新建 | 带提示属性行 |
| `ui/components/IconStatRow.lua` | 新建 | 图标状态行 |
| `ui/components/SkillCard.lua` | 新建 | 技能卡片组件 |
| `ui/components/ArtifactPassiveCard.lua` | 新建 | 被动技能卡片 |
| `ui/components/SectionCard.lua` | 新建 | 分组卡片容器 |
| `ui/components/SectionHeader.lua` | 新建 | 分组标题行 |

## 附录 C：文件修改清单（炼丹炉重构）

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `config/UITheme.lua` | 修改 | +xxs spacing, +badge tokens |
| `config/PillRecipes.lua` | 新建 | 炼丹配方静态数据（198行） |
| `systems/AlchemySystem.lua` | 新建 | 炼丹逻辑层（422行） |
| `ui/AlchemyUI.lua` | 重写 | 1891行→956行，引入 PanelShell/ItemSlot/CategoryBadge |
| `ui/components/CategoryBadge.lua` | 新建 | 分类标签徽章共享组件 |
| `ui/components/ItemSlot.lua` | 修改 | 支持贴图图标模式（backgroundImage） |

## 附录 D：文件修改清单（公告板 BulletinUI 迭代）

**迭代类型**：轻量级（数据分离 + PanelShell 接入 + 令牌化，无系统层抽取）

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `config/Changelogs.lua` | 新建 | 版本日志 + 前言纯数据（~900行），从 UI 中分离 |
| `ui/BulletinUI.lua` | 重写 | 1445行→540行，引入 PanelShell + ChangelogData + T.color 令牌 |

**改造要点**：
1. **数据分离**：PREFACE + CHANGELOGS 外移到 `config/Changelogs.lua`，维护者更新版本日志无需接触 UI 代码
2. **PanelShell 接入**：替换手工 overlay/card/header/close 逻辑，统一 `maxHeight="76%"` + `T.color.goldDark` 边框
3. **令牌化**：30+ 硬编码 RGBA 替换为 `T.color.*`（textPrimary/textMuted/info/warning/gold/surface/surfaceDeep/borderLight/btnSpend/btnDisabled）
4. **安全边界守护**：Serialize/Deserialize/SerializeAccount/DeserializeAccount/HasUnclaimedReward/GetActiveReward/Create/Show/Hide/IsVisible/Destroy 全部保持签名不变

## 附录 E：文件修改清单（排行榜 LeaderboardUI + XianshiRankUI 迭代）

**迭代类型**：轻量级（Token 化 + 次级面板数据驱动 + 视觉规范化，无系统层抽取）

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `config/UITheme.lua` | 修改 | +rankSilver, +rankBronze, +rankTop3Bg, +highlightMe |
| `ui/LeaderboardUI.lua` | 修改 | Token 化全量颜色/间距；ShowRules 数据驱动重构；规则面板仅保留修仙榜 |
| `ui/XianshiRankUI.lua` | 修改 | 排名色统一引用 Token；标题添加 💎 emoji |

### Phase 3：规则沉淀

本轮排行榜迭代中发现并确认的规则：

| 新增规则 | 内容 | 来源场景 |
|---------|------|---------|
| **次级文字信息面板范式** | overlay → card(panelBg + cardBorderInfo + lg圆角 + lg内边距) → 标题(titleText) → divider → 内容区(surfaceDeep底 + sm圆角) → divider → 鼓励语(jade) → 关闭按钮(secondary) | ShowRules 规则弹窗 |
| **规则/帮助面板数据驱动** | 纯文本规则/帮助说明必须从 UI 构建器中分离为 `local DATA = {...}` 数据表，循环渲染；新增规则只改数据不改 UI | ShowRules 5条三元表达式 → RULES_DATA 数据表 |
| **序号视觉层次** | 有序列表中，序号使用 `goldDark` 加粗，内容使用 `textSecondary`，row 布局 + baseline 对齐 | 规则行可读性提升 |
| **isMe 高亮色约束** | 排行榜/列表中"我的行"统一使用 `T.color.highlightMe`（暖金深底 `{60,55,30,200}`），不得使用 `accentPassive`（蓝色系会导致文字不可读） | 用户反馈"完全看不清" |
| **跨文件排名色统一** | 多个文件使用相同的金银铜排名色时，必须在 UITheme 创建专用 Token（`rankSilver/rankBronze`），不得各自硬编码 | LeaderboardUI + XianshiRankUI 排名色统一 |
| **不使用 PanelShell 的合理场景** | 自定义 header（如排行榜的 Tab + 规则按钮）或极简信息弹窗（无 ScrollView 需求）可不用 PanelShell，但必须保持 overlay + card 基础结构 | LeaderboardUI 自定义 header、ShowRules 轻量弹窗 |

### Phase 4：验收回归

**指标对比**：

| 指标 | 改前 | 改后 |
|------|------|------|
| LeaderboardUI 硬编码颜色 | 8处（银/铜/top3底/isMe底） | 0 |
| XianshiRankUI 硬编码颜色 | 2处（银/铜） | 0 |
| 硬编码间距（非阶梯值） | 7处（gap=2/4, padding=6） | 0 |
| ShowRules 三元表达式 | 5×2=10处 | 0（数据表循环渲染） |
| 榜单规则覆盖 | 2/3（缺镇狱榜） | 仅保留修仙榜（按需求精简） |
| 新增 UITheme Token | — | +4（highlightMe, rankSilver, rankBronze, rankTop3Bg） |

**关键设计决策**：

| 决策 | 原因 |
|------|------|
| LeaderboardUI 不使用 PanelShell | 自定义 header（3 Tab + 规则按钮 + 刷新按钮），PanelShell 的标准 header 无法容纳 |
| ShowRules 不使用 PanelShell | 纯文本信息弹窗，无 ScrollView 需求，PanelShell 过重 |
| 规则面板仅保留修仙榜 | 用户决策：试炼榜/镇狱榜无需规则说明 |
| isMe 高亮使用暖金深底 | `accentPassive`（蓝色）导致白/金文字不可读；暖金深底与金色文字对比度适中 |
| XianshiRankUI 标题加 💎 emoji | 用户需求：与其他面板标题风格保持一致（📜排行榜规则、⚔排行榜） |

**功能验收**：
- [x] 修仙榜/试炼榜/镇狱榜正常切换显示
- [x] 排名前3金银铜色正确
- [x] "我的行"高亮清晰可读
- [x] 修仙榜规则弹窗正常弹出/关闭
- [x] 试炼榜/镇狱榜点规则按钮无反应（符合预期）
- [x] 仙石榜 PanelShell 正常显示，标题含 💎
- [x] 构建通过，无 LSP 错误

---

## 附录 C：CollectionUI 重构 — Phase 3 规则沉淀

> 来源：神兵图录（CollectionUI）重构过程中发现的规则，2026-06-12

### C.1 PanelShell portrait 标准模式

**规则**：所有功能面板（非纯弹窗）必须配置 portrait，传入 `PanelShell.Create({ portrait = ... })`。

```lua
-- 标准写法
local PORTRAIT_SIZE = 64
local portraitPanel = UI.Panel {
    width           = PORTRAIT_SIZE,
    height          = PORTRAIT_SIZE,
    borderRadius    = T.radius.md,
    backgroundColor = T.color.headerBg,
    overflow        = "hidden",
    backgroundImage = "xxx.png",      -- 静态图直接赋值
    backgroundFit   = "cover",
}
shell_ = PanelShell.Create({ portrait = portraitPanel, ... })
```

**约束**：
- `PORTRAIT_SIZE` = 64，局部常量声明
- `borderRadius` 统一 `T.radius.md`（10px），不用 lg
- `overflow = "hidden"` 必须存在（裁剪圆角溢出）
- portrait 内容可以是 NPC、图标、物品等，不限于人像
- title 中不再重复 emoji 前缀（portrait 已承担视觉标识功能）

### C.2 法宝/模板类条目的图标解析

**规则**：当装备虚拟条目本身不含 `icon` 字段时，必须从其关联模板查找。

```lua
-- 解析链
local iconPath = template.icon                    -- 1. 直取
if not iconPath and template.isFabaoCollection then
    local fabaoTpl = EquipmentData.FabaoTemplates
        and EquipmentData.FabaoTemplates[template.fabaoTemplateId]
    if fabaoTpl and fabaoTpl.iconByTier then
        iconPath = fabaoTpl.iconByTier[template.fabaoTier]  -- 2. 模板查表
    end
end
```

**适用场景**：任何 `isFabaoCollection = true` 的虚拟条目（图鉴、铸造预览等）。

**图标文件位置规律**：
| 来源 | 路径格式 | 存放位置 |
|------|---------|---------|
| Forge iconByTier | `"icon_fabao_xxx_lvN.png"` | `assets/` 根目录 |
| 生成图片 | `"image/icon_xxx_timestamp.png"` | `assets/image/` |
| ch5+ 新装备 | `"image/icon_xxx_timestamp.png"` | `assets/image/` |

### C.3 行内操作按钮令牌

**规则**：列表行内小按钮（收录/购买/解锁等）统一使用 `T.size.inlineBtnH`（28）和 `T.size.inlineBtnW`（60），禁止硬编码。

```lua
UI.Button {
    width  = T.size.inlineBtnW,   -- 60
    height = T.size.inlineBtnH,   -- 28
    fontSize = T.fontSize.xs,
    borderRadius = T.radius.sm,
    ...
}
```

### C.4 ImageItemSlot icon 优先级链（完整）

```
item.image (.png) → item.icon (.png) → 分类回退查询 → fallback "📦"
```

分类回退规则：
- `category == "mingge"` → `MinggeData.PORTRAITS[bossId]`
- `category == "consumable"` → `GameConfig.CONSUMABLES[consumableId].image`
- `isFabaoCollection == true` → `FabaoTemplates[fabaoTemplateId].iconByTier[fabaoTier]`

**注意**：回退查询在 ImageItemSlot 外部完成（调用方负责），ImageItemSlot 只接收最终的 `item.icon` 或 `item.image`。

## 附录 F：CollectionUI 重构 — Phase 4 验收回归

**迭代类型**：轻量级（PanelShell 接入 + Token 化 + ImageItemSlot 委托 + 法宝图标解析修复）

### 文件修改清单

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `config/UITheme.lua` | 修改 | +collectedBg, +collectedBorder, +summaryBg, +summaryBorder, +bonusLabel, +bonusValue, +inlineBtnH, +inlineBtnW |
| `ui/CollectionUI.lua` | 重写 | PanelShell 骨架接入 + portrait 配置 + Token 化 + ImageItemSlot 委托 + 法宝 iconByTier 解析 |

### 行数对比

| 文件 | 重构前 | 重构后 |
|------|--------|--------|
| CollectionUI.lua | 634 行 | 583 行（-8%） |

> 行数减少主要来自：删除 `SLOT_EMOJI` 映射表 + 删除手动构建图标框代码（委托给 ImageItemSlot）

### 质量指标

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| 硬编码 RGBA 颜色 | 19 处 | **0** |
| Token 引用数 (`T.*`) | 0 | **65** |
| PanelShell 接入 | ❌ 手工 overlay+card | ✅ `PanelShell.Create()` |
| Portrait 配置 | ❌ 无 | ✅ `book_atk.png`（图录图标） |
| 装备图标渲染 | 手工 emoji + Panel | ✅ `ImageItemSlot` 委托 |
| 法宝图标显示 | ❌ 缺失（nil → "📦"） | ✅ FabaoTemplates.iconByTier 查表 |
| 行内按钮尺寸 | 硬编码 px | ✅ `T.size.inlineBtnH/W` |
| 共享组件使用 | 0 | **2**（PanelShell + ImageItemSlot） |

### 关键设计决策

| 决策 | 原因 |
|------|------|
| Portrait 使用 `book_atk.png` 而非 NPC 人像 | 图录面板代表"藏品册"概念，书籍图标比人像更贴切；现有 23KB 素材可用 |
| 法宝图标在 CollectionUI 内部解析，未修改 ImageItemSlot | 回退查询应在调用方完成（C.4 规则）；ImageItemSlot 保持通用性，只接收最终 `item.icon` |
| 不拆分为多文件 | 583 行 < 1000 行阈值；章节 Tab 间共享 `collScrollContent_` 状态，强拆增加复杂度 |
| 保留 `CreateEntryWidget` 内部工厂模式 | 每个条目 Widget 结构复杂（图标+信息+操作三列），抽为共享组件收益不大（仅本面板使用） |

### 安全边界验证

| 接口 | 签名变化 | 验证结果 |
|------|---------|---------|
| `CollectionUI.Create(parentOverlay)` | 无变化 | ✅ `main.lua:1228` 调用正常 |
| `CollectionUI.Show()` | 无变化 | ✅ |
| `CollectionUI.Hide()` | 无变化 | ✅ `main.lua:1616`, `GameEvents.lua:498` |
| `CollectionUI.Toggle()` | 无变化 | ✅ `main.lua:1191`, `main.lua:1666` |
| `CollectionUI.IsVisible()` | 无变化 | ✅ `main.lua:1615`, `GameEvents.lua:498` |
| `CollectionUI.Refresh()` | 无变化 | ✅ 内部 EventBus 回调 |
| `CollectionUI.DoSubmit(equipId)` | 无变化 | ✅ 内部按钮 onClick |

### 功能验收

- [x] 图录面板打开/关闭正常（PanelShell 骨架）
- [x] Portrait 显示正确（book_atk.png，64×64 圆角）
- [x] 各章节 Tab 切换正常
- [x] 普通装备图标正确显示（ImageItemSlot + template.icon）
- [x] 法宝图标正确显示（FabaoTemplates.iconByTier 回退）
- [x] 已收录条目绿色高亮（collectedBg/collectedBorder Token）
- [x] "可收录"按钮可点击，使用 `T.size.inlineBtnH/W` + `btnSpend` 配色
- [x] 总加成面板双列布局正确
- [x] 收录后即时刷新（EventBus 监听 + save_request 触发）
- [x] 零硬编码 RGBA 残留
- [x] 构建通过

---

---

## 附录 G: PetPanel 重构 — Phase 1 结构梳理与风险评估

### G.1 文件清单与规模

| 文件 | 行数 | 职责 | 层级 |
|------|------|------|------|
| `scripts/ui/PetPanel.lua` | **2213** | 宠物面板主 UI（4 Tab + 弹窗） | UI |
| `scripts/ui/PetPanelForms.lua` | 316 | 形态切换子模块 UI | UI |
| `scripts/entities/Pet.lua` | 1108 | 宠物实体（属性/战斗/形态/经验） | 数据+逻辑 |
| `scripts/config/PetFormConfig.lua` | 118 | 形态配置表 | 配置 |
| `scripts/config/PetSkillData.lua` | 471 | 技能定义+升级消耗 | 配置 |
| `scripts/config/PetAppearanceConfig.lua` | 284 | 外观皮肤配置 | 配置 |
| `scripts/systems/PetSkinSystem.lua` | 214 | 外观装备/解锁逻辑 | 逻辑 |
| `scripts/network/PetSkillRepairService.lua` | 189 | 技能修复网络服务 | 网络 |
| **合计** | **4913** | | |

**重构目标文件**：`PetPanel.lua`（2213行）+ `PetPanelForms.lua`（316行）= **2529 行 UI 代码**

### G.2 三层边界分析

#### 配置层（纯数据，重构中不应修改）

| 模块 | 作用 | PetPanel 读取方式 |
|------|------|------------------|
| `GameConfig.PET_TIERS` | 阶级名称/属性/等级上限 | `pet:GetTierData()` |
| `GameConfig.PET_FOOD` | 食物列表+经验值 | `GameConfig.PET_FOOD[foodId]` |
| `GameConfig.PET_EXP_TABLE` | 经验表 | `GameConfig.PET_EXP_TABLE[level]` |
| `PetSkillData.SKILLS` | 技能定义表 | `PetSkillData.SKILLS[id]` |
| `PetSkillData.UPGRADE_COST` | 升级消耗两路径 | `PetSkillData.UPGRADE_COST[tier]` |
| `PetSkillData.SKILL_BOOKS` | 技能书 ID→名称 | `PetSkillData.SKILL_BOOKS[bookId]` |
| `PetAppearanceConfig` | 外观配置列表 | `PetAppearanceConfig.byId[skinId]` |
| `PetFormConfig.FORMS` | 形态属性修正 | `PetFormConfig.Get(formId)` |

#### 逻辑层（业务状态，重构中保持接口不变）

| 模块 | PetPanel 调用的接口 |
|------|-------------------|
| `Pet` 实体 | `:GetTierData()`, `:GetStatBreakdown()`, `:GetExpProgress()`, `:GetSyncRate()`, `:GetIcon()`, `:Feed(foodId)`, `:Breakthrough()`, `:RecalcStats()`, `:CanSwitchForm()`, `:SwitchForm()`, `:GetUnlockedForms()`, `:IsFormUnlocked()`, `.skills[]`, `.tier`, `.level`, `.hp`, `.maxHp`, `.alive`, `.formId`, `.formSwitchCD` |
| `InventorySystem` | `.CountConsumable(id)`, `.ConsumeConsumable(id, count)`, `.GetPetFoodList()`, `.GetSkillBookList()`, `.CountUnlockedConsumable(id)` |
| `PetSkinSystem` | `.GetAllSkins()`, `.GetEquippedSkin()`, `.EquipSkin(id)`, `.ResetToDefault()` |
| `CombatSystem` | `.AddFloatingText(x, y, msg, color, duration)` |
| `EventBus` | `.Emit("save_request")`, `.On("pet_form_changed", fn)` |

#### UI 层（本次重构对象）

| 函数/区域 | 行范围 | 职责 | 问题 |
|-----------|--------|------|------|
| `BuildInfoContent()` | 51-170 | 属性显示+喂食按钮 | 硬编码 RGBA ~15处 |
| `BuildBreakthroughContent()` | 170-340 | 突破 UI | 硬编码 ~20处，内联逻辑 |
| `BuildSkillsContent()` | 343-590 | 固有技能+形态卡+主动技能+宫格 | 硬编码 ~40处，最复杂段 |
| `BuildAppearanceContent()` | 594-910 | 外观图鉴 3列卡片 | 硬编码 ~45处，大块 MakeCard |
| `PetPanel.Create()` | 918-1112 | 面板骨架（手工非 PanelShell） | 硬编码 ~20处 |
| `PetPanel.Refresh()` | 1155-1210 | FindById 刷新固定区 | 尚可 |
| `PetPanel.DoFeed/DoBreakthrough` | 1213-1290 | 操作逻辑 | 业务逻辑混入UI |
| `CreateSkillGridCell()` | 1298-1370 | 单格渲染 | 硬编码色阶 |
| `ShowLearnPopup()` | 1373-1565 | 学习弹窗 | 硬编码 ~20处 |
| `ShowSkillActionPopup()` | 1569-1870 | 升级弹窗(路径A+B) | 硬编码 ~40处，最长弹窗 |
| `DoUpgradePathA/B` | 1878-1985 | 升级操作逻辑 | 业务逻辑混入UI |
| `StartDeleteSkill()` | 1991-2018 | 删除二次确认 | OK |
| `ShowSkillConfirm/Rules` | 2022-2200 | 通用确认+规则弹窗 | 硬编码 ~10处 |
| `PetPanel.Update(dt)` | 2207-2213 | 每秒 CD 刷新 | 简洁OK |

### G.3 当前问题清单

| # | 问题 | 严重度 | 影响 |
|---|------|--------|------|
| 1 | **185 处硬编码 RGBA**（PetPanel）+ 21处（PetPanelForms）= 206 总计 | 高 | 视觉不统一、改色要逐行搜索 |
| 2 | **不使用 PanelShell** — 手工构建 overlay+card+header | 高 | 骨架风格与其他面板不一致 |
| 3 | **2213 行远超 1500 行拆分阈值** | 高 | 可读性差、维护困难 |
| 4 | **业务逻辑内嵌 UI** — DoFeed/DoBreakthrough/DoUpgradePathA/B 直接在 PetPanel 中执行消耗、概率判定、存档触发 | 中 | 无法独立测试/复用 |
| 5 | **技能色阶散落** — tierBorderColors/tierLabelColors/tierLabels 多处重复定义 | 中 | 改一处漏一处 |
| 6 | **形态子模块耦合** — PetPanelForms 通过全局 `CombatSystem_AddFloatingHint` 避免循环引用 | 低 | 可接受但不优雅 |
| 7 | **无共享组件使用** — 未使用 PanelShell / ItemSlot / SectionCard 等 | 高 | 重复构建模式 |

### G.4 安全边界清单

#### 公共 API 签名（重构后必须保持不变）

| 接口 | 签名 | 外部调用点 |
|------|------|-----------|
| `PetPanel.Create(parentOverlay)` | `(table) → void` | `main.lua:1207` |
| `PetPanel.Show()` | `() → void` | `GameEvents.lua:490` |
| `PetPanel.Hide()` | `() → void` | `main.lua:1608`, `GameEvents.lua:496` |
| `PetPanel.Toggle()` | `() → void` | `main.lua:1179`, `main.lua:1658` |
| `PetPanel.IsVisible()` | `() → boolean` | `main.lua:1607`, `GameEvents.lua:490/496` |
| `PetPanel.Refresh()` | `() → void` | 内部 + EventBus |
| `PetPanel.Update(dt)` | `(number) → void` | `main.lua:1515` |

#### 存储键名（SaveSerializer 序列化字段，不可改名）

读取自 `Pet` 实体，但 UI 重构不应改变 Pet 实例上的字段名：
- `pet.name`, `pet.level`, `pet.exp`, `pet.tier`
- `pet.hp`, `pet.alive`, `pet.deathTimer`
- `pet.skills[i] = { id, tier }`
- `pet.appearance = { selectedId }`
- `pet.formId`, `pet.pendingFormId`, `pet.formSwitchCD`

#### EventBus 事件契约

| 事件 | 触发者 | PetPanel 角色 |
|------|--------|--------------|
| `save_request` | PetPanel（突破/学习/升级/精研/删除后） | 发出者 |
| `pet_form_changed` | Pet:SwitchForm → EventBus | 监听者（刷新面板） |
| `equip_stats_changed` 等 | 外部系统 | 间接（Pet._statsDirty） |

#### 跨模块调用（PetPanel → 外部）

| 调用 | 目标 | 说明 |
|------|------|------|
| `CombatSystem.AddFloatingText(...)` | 战斗系统 | 操作反馈浮字 |
| `InventorySystem.ConsumeConsumable(...)` | 背包系统 | 消耗物品 |
| `InventorySystem.CountConsumable(...)` | 背包系统 | 查询库存 |
| `PetSkinSystem.EquipSkin(...)` | 外观系统 | 装备皮肤 |
| `CharacterUI.Refresh()` | 角色面板 | 联动刷新（技能影响主人属性） |
| `GameState.uiOpen = "pet"` | 全局状态 | UI 互斥锁 |

### G.5 风险矩阵

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 拆分后技能升级逻辑丢失分支 | 中 | 高（扣错资源/不出结果） | P2 阶段逐函数搬迁，每搬一个函数立即 build 验证 |
| PanelShell 接入后 overlay 层级与弹窗冲突 | 中 | 中（弹窗被遮挡） | 弹窗改挂 parentOverlay 而非 panel_ 内部（保持当前做法） |
| 外观卡片 MakeCard 拆出后状态引用断裂 | 低 | 中 | MakeCard 接收纯数据参数，不引用闭包变量 |
| Token 化后色阶不匹配原设计意图 | 中 | 低（视觉微调） | 先录入专用 pet token 组，再逐区域替换，PR 前视觉对比 |
| DoFeed/DoBreakthrough 剥离后 Refresh 时序错乱 | 低 | 中（显示旧数据） | 操作函数返回 success → UI 层统一 Refresh |
| PetPanelForms 接口变更导致技能 Tab 渲染崩溃 | 低 | 高 | PetPanelForms 公共接口（BuildFormRow/GetBerserkEnhancementRow/GetSpiritDevourEnhancementRow/UpdateCDLabels）签名锁定 |
| SaveSerializer 读取 pet 字段 — 误改字段名 | 极低 | 极高（存档丢失） | UI 重构不触碰 Pet.lua 实体和 SaveSerializer |

### G.6 推荐拆分方案（P2 预规划）

```
scripts/ui/
├── PetPanel.lua           ← 入口：骨架(PanelShell) + Tab 切换 + 公共API
│                              目标 ~400 行
├── PetPanelInfo.lua       ← Tab "属性·喂食"
│                              目标 ~200 行
├── PetPanelBreakthrough.lua ← Tab "突破"
│                              目标 ~200 行
├── PetPanelSkills.lua     ← Tab "技能" + 宫格 + 学习/升级弹窗
│                              目标 ~600 行（最复杂，可考虑再拆弹窗）
├── PetPanelAppearance.lua ← Tab "外观"
│                              目标 ~300 行
├── PetPanelForms.lua      ← 形态切换子模块（保留，仅 token 化）
│                              目标 ~300 行
└── PetPanelOps.lua        ← 操作逻辑：DoFeed/DoBreakthrough/DoUpgrade/Delete
                               目标 ~250 行
```

**总量控制**：2529 行 → 拆分后 ~2250 行（-11%），每个文件 < 600 行。

### G.7 Token 化范围估计

| 区域 | 硬编码 RGBA 数 | 预计新增 Token |
|------|---------------|---------------|
| Tab 按钮色 | 7 | `petTab*` 系列 4 个 |
| 属性·喂食 | 15 | 复用 `surface*` + 新增 `statColor*` 3个 |
| 突破 | 20 | 复用 `surface*` + `tier*Color` 系列 |
| 技能（固有+主动+宫格） | 40 | `skillTierBorder[1-4]`、`skillBg*` 系列 |
| 外观卡片 | 45 | `skinCardEquipped*`、`skinCardOwned*`、`skinCardLocked*` |
| 弹窗（学习+升级+确认） | 35 | 复用 `dialogBg` + `pathA*`/`pathB*` |
| HP/EXP 条 | 8 | `hpBar*`、`expBar*` |
| PanelShell 骨架 | 15 | 复用已有 `panelBg`、`closeButton` 等 |
| PetPanelForms | 21 | `formNormal*`、`formBattle*`、`formGuard*`、`formRage*` |
| **合计** | **206** | **预计新增 ~30 个 Token** |

### G.8 结论与下一步

**PetPanel 是本项目最大最复杂的 UI 文件**，远超拆分阈值（2213 行 vs 1500 限制）。核心问题：
1. 206 处硬编码 RGBA — 风格无法统一管控
2. 不使用 PanelShell — 骨架与其他面板不一致
3. 业务逻辑混入 UI — 无法独立验证操作正确性
4. 巨型单文件 — 任何修改都有连带风险

**P2 阶段优先级**：
1. 🔴 拆分文件（消除单文件过大风险）
2. 🔴 接入 PanelShell（统一骨架）
3. 🟡 Token 化（消除硬编码 RGBA）
4. 🟡 剥离操作逻辑到 PetPanelOps
5. 🟢 共享组件复用（如将 MakeCard → 通用 SkinCard）

---

## 附录 H: PetPanel 重构 — Phase 3 规则沉淀

> 来源：宠物面板（PetPanel）P2 重构过程中发现并确认的规则，2026-06-13

### H.1 新增规则总表

| 新增规则 | 写入 SKILL.md 位置 | 内容摘要 | 来源场景 |
|---------|-------------------|---------|---------|
| **PanelShell 含固定信息区的适配模式** | S0.4 | 固定区域（HP/EXP/TabBar）放在 AddContent 顶部，不 hack header | PetPanel 4-Tab + 固定进度条 |
| **弹窗宽度层级约束** | S0.5 | 信息弹窗 ≤ 88%/400px，功能弹窗可与父面板等宽 94%/500px | ShowSkillRules vs ShowLearnPopup |
| **面板专属 Token 命名规范** | S1.5 | `{panel}{Module}{Semantic}` 驼峰三段命名，10+ 私有色时启用 | PetPanel 60+ 专属 Token |
| **Tab 拆分模式** | S5.6 | >1500 行 + 4 Tab → 每 Tab 独立模块，主控只管骨架 + SwitchTab | PetPanel 2213→5 文件拆分 |

### H.2 关键设计决策

| 决策 | 原因 |
|------|------|
| PetPanel 使用 PanelShell（推翻 P1 预判） | P1 认为 HP/EXP/TabBar 固定区域与 PanelShell 不兼容；P2 发现将固定区域放在 AddContent 内部（而非 hack header）可行，统一骨架收益大于定制成本 |
| 信息弹窗（规则/帮助）宽度 88%+400 | 次级弹窗必须视觉上"嵌套于"父面板内，避免遮挡父面板边缘产生对齐错觉 |
| 功能弹窗（学习/装备）宽度与父面板等宽 | 功能弹窗含列表+操作按钮，需要足够空间；视觉上是"替代"而非"叠加" |
| 按 Tab 拆分为 5 个文件 | 原 2213 行单文件远超 1500 行阈值；4 Tab 业务完全独立，互相零耦合 |
| 60+ 专属 Token 使用 `pet` 前缀分组 | 宠物面板含 4 个 Tab × 多种视觉状态（装备/锁定/激活/冷却），颜色需求远超其他面板；统一前缀避免全局命名冲突 |

### H.3 行数对比

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| 文件数 | 1（PetPanel.lua） | 5（主控+4 Tab） |
| 总行数 | 2213 | 2152（-3%） |
| 主控文件 | 2213 | 341 |
| 最大单文件 | 2213 | 1123（Skills Tab） |
| 硬编码 RGBA | 206 处 | 0 |
| UITheme 新增 Token | — | +60（pet* 前缀） |

### H.4 新增 Token 清单（按模块分组）

**Tab 颜色**（4）：
`petTabInfo` · `petTabBreakthrough` · `petTabSkills` · `petTabAppearance`

**进度条**（4）：
`petHpBarBg` · `petHpBarFill` · `petExpBarBg` · `petExpBarFill`

**阶级徽章**（2）：
`petTierBadgeBg` · `petTierBadgeFg`

**固有技能**（4）：
`petSkillInnateBg` · `petSkillInnateBorder` · `petSkillInnateTitle` · `petSkillInnateRowBg`

**主动技能**（6）：
`petSkillActiveBg` · `petSkillActiveBorder` · `petSkillActiveTitle` · `petSkillActiveRowBg` · `petSkillLockedBg` · `petSkillLockedBorder`

**技能阶边框+标签**（8）：
`petSkillTierBorder1-4` · `petSkillTierLabel1-4`

**技能学习弹窗**（3）：
`petLearnItemBg` · `petLearnItemSelected` · `petLearnItemSelBorder`

**突破**（4）：
`petBreakthroughBg` · `petBreakthroughBorder` · `petBreakthroughTitle` · `petBreakthroughGain`

**外观/皮肤**（8）：
`petSkinEquippedBg` · `petSkinEquippedBorder` · `petSkinOwnedBg` · `petSkinOwnedBorder` · `petSkinLockedBg` · `petSkinLockedBorder` · `petSkinPreviewBg` · `petSkinEquipBtn`

**形态系统**（19）：
`petFormContainerBg` · `petFormContainerBd` · `petFormTitle` · `petFormDesc` · `petFormActiveGlow` · `petFormCdFont` · `petFormLockedFont` · `petFormNameUnlocked` · `petFormStatDesc` · `petFormCdActive` · `petFormRageBg` · `petFormRageBd` · `petFormRageIcon` · `petFormEnhRageBg` · `petFormEnhRageBd` · `petFormEnhRageFg` · `petFormEnhGuardBg` · `petFormEnhGuardBd` · `petFormEnhGuardFg`

**属性信息**（7）：
`petInfoHeadBg` · `petStatHpRegen` · `petStatEvade` · `petStatCrit` · `petStatSync` · `petStatSyncHint` · `petFoodBtnBg`

**槽位**（4）：
`petSlotEmptyBg` · `petSlotEmptyBorder` · `petSlotEmptyIcon` · `petSlotFilledBg`

**尺寸 Token**（1）：
`petHpBarHeight`（size 节）

---

## 附录 I: PetPanel 重构 — Phase 4 验收回归

**迭代类型**：大型重构（PanelShell 接入 + Token 化 + Tab 拆分 + 形态系统集成）

### 文件修改清单

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `config/UITheme.lua` | 修改 | +60 个 pet* 前缀 Token（颜色+尺寸） |
| `ui/PetPanel.lua` | 重写 | PanelShell 骨架 + 固定信息区 + TabBar + SwitchTab 主控 |
| `ui/PetPanelInfo.lua` | 新建 | Tab 1：属性信息 + 喂食按钮 |
| `ui/PetPanelBreakthrough.lua` | 新建 | Tab 2：突破预览 + 条件展示 |
| `ui/PetPanelSkills.lua` | 新建 | Tab 3：固有/主动技能 + 学习弹窗 + 规则弹窗 |
| `ui/PetPanelAppearance.lua` | 新建 | Tab 4：皮肤卡片 + 装备/预览 |

### 行数对比

| 文件 | 重构前 | 重构后 |
|------|--------|--------|
| PetPanel.lua（主控） | 2213 | 341 |
| PetPanelInfo.lua | — | 189 |
| PetPanelBreakthrough.lua | — | 209 |
| PetPanelSkills.lua | — | 1123 |
| PetPanelAppearance.lua | — | 290 |
| **合计** | **2213** | **2152（-3%）** |

### 质量指标

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| 文件数 | 1 | **5**（主控+4 Tab） |
| 最大单文件行数 | 2213 | **1123**（Skills Tab） |
| 硬编码 RGBA 颜色 | 206 处 | **0** |
| Token 引用数 (`T.*`) | 0 | **180+** |
| PanelShell 接入 | ❌ 手工 overlay+card | ✅ `PanelShell.Create()` |
| Portrait 配置 | ❌ 无 | ✅ 宠物头像（动态更新） |
| 共享组件使用 | 0 | **1**（PanelShell） |
| LSP Error | — | **0** |
| LSP Warning | — | 27（均为类型推导误报，不影响运行） |
| 构建状态 | — | ✅ 通过 |

### 安全边界验证

| 接口 | 签名变化 | 验证结果 |
|------|---------|---------|
| `PetPanel.Create(parentOverlay)` | 无变化 | ✅ `main.lua:1207` 调用正常 |
| `PetPanel.Show()` | 无变化 | ✅ `GameEvents.lua:490` |
| `PetPanel.Hide()` | 无变化 | ✅ `main.lua:1608`, `GameEvents.lua:496` |
| `PetPanel.Toggle()` | 无变化 | ✅ `main.lua:1179`, `main.lua:1658` |
| `PetPanel.IsVisible()` | 无变化 | ✅ `main.lua:1607`, `GameEvents.lua:490/496` |
| `PetPanel.Update(dt)` | 无变化 | ✅ `main.lua:1515` |
| `PetPanel.Refresh()` | 无变化 | ✅ 内部 EventBus 回调 |
| EventBus `pet_form_changed` | 无变化 | ✅ `Pet.lua` 4 处 Emit，`PetPanel.lua` 1 处 On |
| 存储序列化 | UI 层不触碰 | ✅ 无 SaveSerializer/SaveKey 引用 |

### 关键设计决策

| 决策 | 原因 |
|------|------|
| 使用 PanelShell（推翻 P1 预判） | 固定信息区放在 AddContent 内部而非 hack header，统一骨架收益 > 定制成本 |
| 按 Tab 拆分为 5 文件 | 原 2213 行远超阈值；4 Tab 业务零耦合 |
| Skills Tab 保留 1123 行未再拆 | 含 3 个弹窗（Rules/Learn/Info）逻辑紧密，拆分反增复杂度；低于 1500 行可接受 |
| 60+ Token 用 `pet` 前缀分组 | 4 Tab × 多视觉状态 = 颜色需求远超其他面板；前缀避免命名冲突 |
| 信息弹窗 88%/400 vs 功能弹窗 94%/500 | 层级视觉区分：信息类"嵌套于"父面板内，功能类"替代"父面板 |

### 功能验收

- [x] 宠物面板打开/关闭正常（PanelShell 骨架 + portrait）
- [x] 4 个 Tab 切换正常（属性/突破/技能/外观）
- [x] HP/EXP 进度条固定不随 Tab 滚动
- [x] 技能规则弹窗正常弹出/关闭（宽度 88%/400）
- [x] 技能学习弹窗正常弹出/关闭（宽度 94%/500）
- [x] 形态切换事件正确刷新 UI
- [x] 外观卡片装备/预览操作正常
- [x] 突破条件展示正确
- [x] 所有颜色均通过 Token 引用（0 硬编码）
- [x] 全项目 LSP 0 Error
- [x] 构建通过

---

---

## 附录 J: RealmPanel 重构 — Phase 3 规则沉淀

> 来源：境界突破面板（RealmPanel）P2/P2.5 重构过程中发现并确认的规则，2026-06-13

### J.1 新增规则总表

| 新增规则 | 内容摘要 | 来源场景 |
|---------|---------|---------|
| **Banner 区文字可读性保障** | 文字叠加在 backgroundImage 上时，必须添加半透明黑底衬底（`{0,0,0,120}` + `T.radius.sm`），并将文字色从 `textMuted` 提升至 `textSecondary` 以确保对比度 | RealmPanel banner 区域 Lv + 进度点阵被暗云背景吞噬 |
| **信息详略层级分离** | 面板内同时存在"当前状态"和"下一级奖励"时，当前状态用详细逐行展示（space-between 布局），下一级用缩略行内展示（inline emoji+数值），避免信息权重错位 | RealmPanel 累计加成 vs 突破奖励的详略反转修正 |
| **进度条适用性判断** | 条件列表仅需展示"是否满足"时，使用居中文字标签（✓/✗ + 颜色）即可，进度条仅在展示百分比进度有意义时使用；视觉重量：进度条 > 文字标签 | RealmPanel 突破条件从进度条改为居中 Label |
| **副标题信息去重** | PanelShell subtitle 不应重复 banner/内容区已展示的信息（如境界名、等级），应改为固定介绍性描述语，降低认知冗余 | RealmPanel 副标题从"元婴初期·Lv.51"改为"炼丹筑基，突破境界" |
| **单行奖励列表约束** | 奖励摘要行使用 `flexDirection="row"` + `gap=T.spacing.xs` + 不设 `flexWrap`，确保不换行；如果内容可能超宽，对容器设 `flexShrink=1` | RealmPanel 突破奖励行换行问题修复 |

### J.2 关键设计决策

| 决策 | 原因 |
|------|------|
| RealmPanel 保留单文件（717 行） | 低于 1000 行阈值；无 Tab 结构，业务逻辑已剥离到 ProgressionSystem |
| 保留 2 处非 Token RGBA | `{0,0,0,120}` 半透明遮罩和 `{255,100,100}` 浮字色属于通用临时值，无语义 Token 对应；注册全局 Token 过度抽象 |
| 累计加成用 space-between 逐行 | 玩家需要看清"当前境界具体加了什么"，逐行展示信息密度适中，无需横向压缩 |
| 突破奖励用 inline 缩略 | "下一级能得到什么"是辅助决策信息，一行总览即可，不需逐行展开增加面板高度 |
| 突破条件移除进度条 | 条件仅为 bool 判断（等级够/不够、灵韵够/不够），百分比进度无意义，文字标签更轻量 |

---

## 附录 K: RealmPanel 重构 — Phase 4 验收回归

**迭代类型**：轻量级（PanelShell 已接入 + Token 化 + 视觉优化 + 信息架构调整）

### 文件修改清单

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `ui/RealmPanel.lua` | 修改 | P2 视觉优化（详略反转、进度条移除、Banner 衬底、副标题去重、奖励行不换行） |

### 行数对比

| 文件 | P2 开始时 | P2.5 完成后 |
|------|-----------|-------------|
| RealmPanel.lua | ~750 行 | 717 行（-4%） |

> 行数略减：移除了 PROGRESS_BAR_* 常量和 buildConditionRow 中的进度条结构代码。

### 质量指标

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| Token 引用数 (`T.*`) | ~80 | **86** |
| 硬编码 RGBA 残留 | 4 处 | **2 处**（半透明衬底 + 浮字色，均为合理例外） |
| PanelShell 接入 | ✅ | ✅ |
| 共享组件使用 | PanelShell + ImageItemSlot | 同 |
| 信息架构 | 详略错位 | ✅ 当前加成=详细，突破奖励=缩略 |
| 条件展示 | 进度条（过重） | ✅ 居中文字标签（轻量） |
| Banner 可读性 | 文字被吞噬 | ✅ 半透明衬底 + textSecondary |
| 副标题 | 重复信息"元婴·Lv.51" | ✅ 介绍语"炼丹筑基，突破境界" |
| 构建状态 | — | ✅ 通过 |

### 安全边界验证

| 接口 | 签名变化 | 验证结果 |
|------|---------|---------|
| `RealmPanel.Create(parentOverlay)` | 无变化 | ✅ |
| `RealmPanel.Show()` | 无变化 | ✅ |
| `RealmPanel.Hide()` | 无变化 | ✅ |
| `RealmPanel.Toggle()` | 无变化 | ✅ |
| `RealmPanel.IsVisible()` | 无变化 | ✅ |
| `RealmPanel.Refresh()` | 无变化 | ✅ |

### 功能验收

- [x] 境界面板打开/关闭正常（PanelShell 骨架）
- [x] Banner 区域境界名 + 等级 + 进度点阵清晰可读（半透明衬底）
- [x] 当前境界加成逐行详细展示（含攻速行）
- [x] 突破奖励一行缩略展示（emoji + 数值）
- [x] 突破条件居中文字标签（绿色满足 / 红色不足）
- [x] 副标题显示"炼丹筑基，突破境界"（无信息冗余）
- [x] 突破按钮逻辑正常（金色可点 / 灰色禁用）
- [x] 0 硬编码 RGBA（2 处合理例外已记录）
- [x] 构建通过

---

*文档更新时间：2026-06-13*
*撰写者：AI 开发助手*
*状态：三大面板重构 + 公告板迭代 + 排行榜迭代 + 图录面板重构 + PetPanel 重构 + RealmPanel 重构（P1-P4 全部完成），四阶段方法论已沉淀*
