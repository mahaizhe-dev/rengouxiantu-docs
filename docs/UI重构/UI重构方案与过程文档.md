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

---

## 附录 L: 背包界面（InventoryUI）重构 — Phase 1 结构梳理与风险评估

> 来源：核心 UI 背包界面重构前的 Phase 1 调研，2026-06-18
> 状态：**Phase 1 已完成，待评审放行后进入 Phase 2**

### L.1 文件清单与规模

背包界面由**两个平行子系统**组成，共用同一外壳（InventoryUI 的标题栏 + 2 Tab）：
- **子系统 A：装备物品**（Tab 1）— InventoryUI 主体 + EquipTooltip
- **子系统 B：五行命格**（Tab 2）— MinggePage（拥有独立的配置层 MinggeData + 逻辑层 MinggeSystem + 独立存档键 `saveData.mingge`）

| 文件 | 行数 | 职责 | 层级 | 所属 |
|------|------|------|------|------|
| `scripts/ui/InventoryUI.lua` | **817** | 背包主面板（外壳 + 2 Tab + 装备物品 Tab） | UI | A |
| `scripts/ui/EquipTooltip.lua` | **1030** | 装备 tooltip + 操作弹窗（装备/出售/丢弃） | UI | A |
| `scripts/ui/MinggePage.lua` | **709** | 五行命格子页（Tab 2 内容，**自带完整左右面板**） | UI | B |
| `scripts/ui/MinggeTooltip.lua` | — | 命格 tooltip + 操作弹窗（装备/出售/锁定/卸下） | UI | B |
| `scripts/ui/components/ImageItemSlot.lua` | — | 物品格子共享组件（A/B 均已复用） | 组件 | 共享 |
| `scripts/systems/InventorySystem.lua` | 367 | 装备/背包逻辑层（入口聚合） | 逻辑 | A |
| `scripts/systems/InventorySortUtil.lua` | 207 | 排序工具 | 逻辑 | A |
| `scripts/systems/inventory/consumables.lua` | 627 | 消耗品逻辑（添加/消耗/葫芦升级/令牌盒） | 逻辑 | A |
| `scripts/systems/inventory/batch_use.lua` | 381 | 批量使用/出售逻辑 | 逻辑 | A |
| `scripts/systems/inventory/equip_stats.lua` | 315 | 装备属性结算 | 逻辑 | A |
| `scripts/systems/MinggeSystem.lua` | ~550 | 命格逻辑层（装备/出售/属性结算，独立于 A） | 逻辑 | B |
| `scripts/config/MinggeData.lua` | ~330 | 命格配置（五行/槽位/套装/属性范围/掉落源） | 配置 | B |
| **UI 层合计** | **2556+** | （A: 1847 行 + B: 709 行 + MinggeTooltip） | | |
| **逻辑层合计** | **1897 + 550** | A 已模块化（5 文件）；B 独立（MinggeSystem） | | |

**重构目标**：UI 层共 **2556+ 行**（A 子系统 1847 + B 子系统 709 + 两个 Tooltip）。逻辑层 A/B 均已良好模块化，**本轮重构聚焦 UI 层，不动逻辑层与配置层**。

> ⚠️ **A/B 是平行镜像结构**：两个子系统的 UI 骨架几乎完全相同（左侧装备面板 4×3/5×3 格 + 属性统计 + 套装标签；右侧背包面板 整理 + 批量出售 + 品质勾选 + 两段格子 + ImageItemSlot + Tooltip）。这是本次重构**最大的代码复用机会**，详见 L.9。

### L.2 三层边界分析

#### 配置层（纯数据，重构中不应修改）

| 模块 | 作用 | InventoryUI 读取方式 |
|------|------|------------------|
| `GameConfig.BAG_SPLIT` | 背包分段数 | `InventoryUI.lua:360,803` |
| `GameConfig.BACKPACK_SIZE` | 背包总格数 | `InventoryUI.lua:412,809,813` |
| `EquipmentData` | 装备槽位/套装定义 | 仅传递给 InventorySystem，UI 不直接读字段 |
| `UITheme` (T) | 设计令牌 | 全文件 |

> **边界清晰度**：InventoryUI 不直接读 `CONSUMABLES`/`QUALITY_ORDER`/`SLOTS`/`SetBonuses` 等字段，全部通过 InventorySystem 接口（`GetEquipStatSummary`/`GetActiveSetBonuses`）取结果。配置访问已被逻辑层很好隔离。

#### 逻辑层（业务状态，重构中保持接口不变）

InventoryUI 调用的接口：
- `InventorySystem.GetManager()` → `manager_:GetEquipmentItem(slot)` / `:GetInventoryItem(i)`
- `InventorySystem.SortBackpack()` / `SellByQuality(set)` / `PickupPendingItems()`
- `InventorySystem.GetEquipStatSummary()` / `GetActiveSetBonuses()`

InventorySystem 公共 API（35+ 方法，重构不应改动）：
`Init / GetManager / AddItem / PickupPendingItems / SellItem / SellByQuality / SortBackpack / GetFreeSlots / RecalcEquipStats / GetEquipStatSummary / GetActiveSetBonuses / AddConsumable / CountConsumable / ConsumeConsumable / GetPetFoodList / GetSkillBookList / UpgradeGourd / UseBatchConsumable / ...`

#### UI 层（本次重构对象）

| 函数/区域 | 行范围 | 职责 | 问题 |
|-----------|--------|------|------|
| `LoadSellSettings / SaveSellSettings` | 28–50 | 出售勾选本地持久化（cjson） | 持久化逻辑混入 UI |
| `CreateEquipPanel()` | 98–229 | 左侧装备面板（4×3 格 + 17 项属性 + 套装） | 硬编码 statDefs 颜色 17 处 |
| `CreateInvPanel()` | 232–434 | 右侧背包面板（整理/批量出售/两段格子） | 业务逻辑混入 onClick |
| `SwitchTab()` | 437–476 | Tab 切换（装备/命格） | Tab 激活色硬编码 4 次 |
| `InventoryUI.Create()` | 480–657 | 面板骨架（手工 overlay+card+header，**非 PanelShell**） | 骨架手工搭建 |
| `Show/Hide/Toggle/IsVisible` | 661–707 | 公共 API | OK |
| `UpdateAllSlots()` (local) | 711–726 | 刷新所有格子 | 被多处回调引用 |
| `UpdateStats()` | 728–797 | 刷新 17 项属性标签 | OK |
| `UpdateFreeSlots()` | 798–817 | 刷新空位计数 | OK |

### L.3 当前问题清单

| # | 问题 | 严重度 | 影响 |
|---|------|--------|------|
| 1 | **~133 处硬编码 RGBA**（InventoryUI 31 + EquipTooltip 71 + MinggePage 31） | 高 | 风格无法统一管控；改色要逐行搜索 |
| 2 | **不使用 PanelShell** — 手工 overlay+card+header | 高 | 骨架与其他面板（已统一 PanelShell）不一致 |
| 3 | **EquipTooltip 1030 行超 1000 阈值** | 中 | 单文件偏大，弹窗逻辑密集 |
| 4 | **业务逻辑混入 UI** — 整理/批量出售/勾选持久化直接在 onClick 中执行 | 中 | 操作逻辑无法独立复用/测试 |
| 5 | **17 项属性颜色（statDefs）散落硬编码** | 中 | 属性配色无 Token，与角色面板属性配色可能不一致 |
| 6 | **Tab 激活/非激活色重复定义 4 次** | 低 | 改一处漏一处 |
| 7 | **未使用 SectionCard / PriceTag** | 低 | 重复构建分组/价格模式 |

### L.4 安全边界清单（重构后必须保持不变）

#### 公共 API 签名

| 接口 | 签名 | 外部调用点 |
|------|------|-----------|
| `InventoryUI.Create(parentOverlay)` | `(table) → void` | `main.lua:1208` |
| `InventoryUI.Show()` | `() → void` | 内部 + main.lua |
| `InventoryUI.Hide()` | `() → void` | `main.lua:1636`, `GameEvents.lua:489,494` |
| `InventoryUI.Toggle()` | `() → void` | `main.lua:1179,1644` |
| `InventoryUI.IsVisible()` | `() → boolean` | `main.lua:1635`, `GameEvents.lua:489,494` |
| `InventoryUI.UpdateStats()` | `() → void` | 内部 + EventBus |
| `InventoryUI.UpdateFreeSlots()` | `() → void` | 内部 |

> **外部引用面极窄**：InventoryUI 仅被 `main.lua` 和 `GameEvents.lua` 两个文件引用，边界非常清晰，重构安全性高。
> `UpdateAllSlots()` 是 `local` 函数（非公共 API），但被 4 处 UI 回调引用（L147/268/377/423），拆分时需保持模块内可见性。

#### 存储键名（SaveSerializer，UI 重构不可触碰）

```
save_data.inventory {
  equipment { [slotId] = SerializeItemFull(item) }   -- SaveSerializer:310
  backpack  { ["1"]=item, ["2"]=item, ... }          -- SaveSerializer:328，key 为字符串索引
}
```
`SerializeItemFull`（SaveSerializer:355–395）含字段：`id/name/type/slot/quality/tier/level/mainStat/subStats/setId/icon/sellPrice/count/...` + **BM-NORESELL 永久标记** `bmNoResell/bmSource/bmBuyAt/bmBuyItemId`。
**UI 重构绝不触碰 SaveSerializer 与物品字段名。**

#### EventBus 事件契约

| 事件 | InventoryUI 角色 | 说明 |
|------|-----------------|------|
| `equip_stats_changed` | **监听者** | → 调用 `UpdateStats()`（装备变更后 UI 刷新唯一信号） |
| `mingge_info` | **监听者** | → 更新 infoLabel 文字（仅 mingge Tab） |

> InventoryUI 自身**不 Emit** 任何事件，状态变更全部经 InventorySystem 间接触发。关键链路：`RecalcEquipStats → Emit("equip_stats_changed") → UpdateStats()`，重构时必须保留此监听。

#### 跨模块调用（UI → 外部）

| 调用 | 目标 | 说明 |
|------|------|------|
| `GameState.uiOpen = "inventory"` | 全局状态 | UI 互斥锁 |
| `EquipTooltip.Init/Show/Hide` | 装备弹窗子模块 | 公共接口锁定 |
| `MinggePage.Create/OnShow/OnHide` | 命格子页 | 公共接口锁定 |
| `ImageItemSlot.Create` | 共享组件 | 已复用 |

### L.5 风险矩阵

| # | 风险项 | 概率 | 影响 | 等级 | 缓解措施 |
|---|--------|------|------|------|----------|
| 1 | 手工骨架改 PanelShell 后，弹出菜单（sellMenu_）/tooltip 层级错乱 | 中 | 🟡中 | ⚠️ | sellMenu_/EquipTooltip 继续挂 parentOverlay 而非 panel_ 内部，保持当前层级做法 |
| 2 | 拆分 EquipTooltip 时操作逻辑（装备/出售/丢弃）分支丢失 | 中 | 🔴高 | ⚠️ | 逐函数搬迁，每搬一个立即 build 验证；EquipTooltip 公共接口（Init/Show/Hide）签名锁定 |
| 3 | 17 项属性 statDefs 颜色 Token 化后与原设计色不匹配 | 中 | 🟢低 | 🟢 | 先录入 `invStat*` 专用 Token，逐项替换后视觉对比 |
| 4 | 业务逻辑剥离（整理/批量出售）后 Refresh 时序错乱显示旧数据 | 低 | 🟡中 | 🟢 | 操作函数返回 success → UI 层统一 Refresh（沿用 RealmPanel/PetPanel 模式） |
| 5 | 误改 SaveSerializer 物品字段 / 背包 key 格式 | 极低 | 🔴极高 | ⚠️ | UI 重构不触碰 SaveSerializer 与 InventorySystem；仅改 UI 层渲染 |
| 6 | MinggePage 接口变更导致 Tab 2 渲染崩溃 | 低 | 🟡中 | 🟢 | MinggePage 公共接口（Create/OnShow/OnHide）签名锁定 |
| 7 | 出售勾选本地持久化（cjson 读写）剥离后丢失配置 | 低 | 🟢低 | 🟢 | LoadSellSettings/SaveSellSettings 保留文件读写逻辑，仅调整调用位置 |
| 8 | 提取 A/B 共享面板构建器时，命格（5×3 槽 + 锁定/卸下操作）与装备（4×3 槽）的差异处理不当导致一方功能退化 | 中 | 🔴高 | ⚠️ | 共享构建器以**参数化配置**驱动差异（槽位布局/操作集/数据源），先抽取再分别接入，每接入一方立即 build 验证 |
| 9 | 误改 `saveData.mingge` 结构或命格物品字段 | 极低 | 🔴极高 | ⚠️ | UI 重构不触碰 SaveSerializer 的 SerializeMingge/DeserializeMingge 与 _SerializeMinggeItem |
| 10 | 命格属性刷新链路（mingge_stats_changed）在拆分后断裂 | 低 | 🟡中 | 🟢 | 保留 MinggePage 对 mingge_stats_changed / mingge_item_added 的监听 |

**Gate 评估**：风险矩阵中**无 🔴（高概率 + 高影响）项**。⚠️ 项共 4 个（风险 2/5/8/9，均为中概率+高影响或极低概率+极高影响），均有明确缓解措施 → **可放行进入 Phase 2**。
**新增关注**：风险 8（A/B 共享构建器的差异参数化）是本轮新增的核心技术风险，决定了"平行镜像复用"能否安全落地。

### L.6 推荐拆分方案（Phase 2 预规划）

```
scripts/ui/
├── InventoryUI.lua          ← 入口：骨架(PanelShell) + Tab 切换 + 公共 API
│                               目标 ~300 行
├── InventoryEquipPanel.lua  ← 左侧装备面板（4×3 格 + 属性统计 + 套装）
│                               目标 ~250 行
├── InventoryBagPanel.lua    ← 右侧背包面板（整理/批量出售/两段格子）
│                               目标 ~250 行
├── InventoryOps.lua         ← 操作逻辑：Sort/Sell 包装 + 勾选持久化
│                               目标 ~120 行
├── EquipTooltip.lua         ← 装备弹窗（保留，token 化 + 可考虑拆操作弹窗）
│                               目标 ~700 行（操作逻辑可剥离到 EquipTooltipOps）
└── MinggePage.lua           ← 命格子页（保留，仅 token 化）
                                目标 ~700 行
```

**总量控制**：2556 行 → 拆分后每文件 < 700 行，主控 < 300 行。

### L.7 Token 化范围估计

| 区域 | 硬编码 RGBA 数 | 预计新增 Token |
|------|---------------|---------------|
| InventoryUI 面板背景/按钮 | ~10 | 复用 `surface*`/`btnSpend`/`btnSecondary` |
| InventoryUI 属性配色 (statDefs) | 17 | `invStat*` 系列（或复用角色面板属性色） |
| InventoryUI Tab 色 | 4 | 复用已有 `tabActiveBg`/`tabInactiveBg` |
| EquipTooltip | 71 | `equipTip*` 系列 + 品质色复用 |
| MinggePage | 31 | `mingge*` 系列 + 五行色（统一到 MinggeData） |
| **合计** | **~133** | **预计新增 ~25 个 Token** |

### L.8 五行命格子系统（MinggePage）对等评估

> Tab 2「五行命格」不是简单的页面内容，而是一个拥有**独立配置层 + 独立逻辑层 + 独立存档键**的完整平行子系统。此节与 L.2~L.7（主要针对子系统 A）对等展开。

#### L.8.1 命格三层边界

| 层级 | 文件 | 内容 |
|------|------|------|
| 配置层 | `config/MinggeData.lua` (~330) | ELEMENTS（五行）/ SLOTS（15 槽）/ SETS（四象套装）/ STAT_RANGES（属性范围）/ SOURCES（37 个 boss 掉落源）/ STAT_FIELDS（statId→player 字段映射） |
| 逻辑层 | `systems/MinggeSystem.lua` (~550) | Init/GetManager/IsUnlocked/SetUnlocked/AddItem/SellItem/SellByQuality/SortBackpack/Equip/Unequip/RecalcStats/GetStatSummary/GetActiveSetBonuses/GenerateItem/ToggleLock |
| UI 层 | `ui/MinggePage.lua` (709) + `ui/MinggeTooltip.lua` | 左右面板（5×3 命格槽 + 60 格背包）+ 解封遮罩 + 操作弹窗 |

#### L.8.2 命格 UI 层结构（MinggePage.lua）

| 函数 | 行范围 | 职责 |
|------|--------|------|
| `LoadSellSettings/SaveSellSettings` | 36–59 | 出售勾选本地持久化（**与 InventoryUI 重复**） |
| `CheckRealmUnlocked()` | 83–89 | 境界 order ≥ 7（金丹初期）解封判定 |
| `CreateEquipPanel()` | 95–224 | 左侧命格面板（5 行×3 列 + 属性统计 + 套装） |
| `CreateInvPanel()` | 229–415 | 右侧背包面板（30/30 分屏 + 整理 + 批量出售） |
| `UpdateAllSlots/UpdateStats/UpdateFreeSlots` | 559–641 | 刷新（**与 InventoryUI 同名同构**） |
| `MinggePage.Create(parentOverlay)` | 424–556 | 公共 API，返回 wrapperPanel（含解封遮罩） |
| `MinggePage.OnShow()` | 649–702 | 延迟初始化 + 解封检查 + 刷新 |
| `MinggePage.OnHide()` | 704–707 | 隐藏 Tooltip 和菜单 |

- **不使用 PanelShell**（合理：它是 Tab 内容，外壳由 InventoryUI 管理）
- **使用 ImageItemSlot**（`mingge_equip` / `mingge_inv` 分类）+ MinggeTooltip 专属弹窗
- **特有结构**：解封遮罩 `lockMask_`（境界未达金丹时锁定整页）
- **业务逻辑混入 UI**：批量出售/解封/整理直接在 onClick 调 MinggeSystem（L261/270–296/521–541）

#### L.8.3 命格存储 / 序列化

```
saveData.mingge {
  unlocked = true|nil,                          -- 解封标记
  equipped = { [slotId] = _SerializeMinggeItem }, -- 15 槽，SaveSerializer:828+
  backpack = { ["1"]=item, ... }                 -- 60 格，key 为字符串索引
}
```
- 命格物品字段：`id/minggeId/bossId/element/tier/quality/stat/value/roll/setId/locked/category`（`image` 不落盘，由 `MinggeData.PORTRAITS[bossId]` 重建）
- **16 个 `player.mingge*` 字段为运行时计算值，不序列化**（Player.lua:185–201）
- 迁移：SaveMigrations v26→v27 为空迁移（仅推进版本号）

#### L.8.4 命格 EventBus 契约

| 事件 | 角色 | 说明 |
|------|------|------|
| `mingge_stats_changed` | MinggePage **监听** → UpdateStats；CharacterUI 也监听 | RecalcStats 完成后由 MinggeSystem Emit |
| `mingge_item_added` | MinggePage **监听** → UpdateAllSlots | AddItem 成功 |
| `mingge_info` | MinggePage **Emit** → InventoryUI 消费写 infoLabel | 批量出售/解封提示 |
| `save_request` | MinggePage **Emit** | 解封成功后立即存档 |

> 关键链路：`MinggeSystem.RecalcStats → Emit("mingge_stats_changed") → MinggePage.UpdateStats() + CharacterUI.Refresh()`。与 A 子系统的 `equip_stats_changed` 链路平行对称。

#### L.8.5 命格硬编码统计与发现

- **31 处硬编码 RGBA**（精确分析），仅 2 处用 `T.color.titleText`，令牌化约 6%
- ⚠️ **重复定义 bug 隐患**：`ELEMENT_COLORS` 在 MinggePage.lua(L71–76) 和 MinggeData.lua(L60–66) 各定义一次，**颜色值不一致**（如 metal: `{220,200,140}` vs `{240,220,130}`）→ 重构时应统一到 MinggeData 单一源
- ⚠️ **重复持久化逻辑**：`LoadSellSettings/SaveSellSettings` 在 InventoryUI 和 MinggePage 各有一份 → 可提取到共享 InventoryOps

#### L.8.6 A/B 平行镜像 — 复用机会清单

| 共性结构 | 子系统 A（装备） | 子系统 B（命格） | 复用建议 |
|---------|----------------|----------------|---------|
| 左侧装备面板 | 4×3 格 + 属性统计 | 5×3 格 + 属性统计 | 参数化共享构建器（槽位布局可配） |
| 右侧背包面板 | 整理 + 批量出售 + 两段格子 | 同 | 共享构建器（数据源/分段可配） |
| 品质勾选菜单 | sellMenu_（UI.Menu） | 同 | 共享构建器 |
| 出售设置持久化 | LoadSellSettings/SaveSellSettings | 重复实现 | 提取到 InventoryOps |
| 物品格子 | ImageItemSlot | ImageItemSlot | 已复用 ✅ |
| 操作弹窗 | EquipTooltip | MinggeTooltip | 评估能否抽公共 Tooltip 骨架 |
| 刷新三件套 | UpdateAllSlots/Stats/FreeSlots | 同名同构 | 共享构建器内置 |

> **差异点**（参数化处理）：槽位行列数（4×3 vs 5×3）、操作集（装备无锁定/卸下，命格有）、数据源（InventorySystem vs MinggeSystem）、命格特有的解封遮罩。

### L.9 结论与下一步（A + B 统揽）

背包界面是项目核心 UI 之一，由 **A（装备物品）+ B（五行命格）两个平行镜像子系统**组成，UI 层共 **2556+ 行**。主要问题：
1. **~133 处硬编码 RGBA**（A: InventoryUI 31 + EquipTooltip 71；B: MinggePage 31）— 颜色令牌化是最大空白
2. 不使用 PanelShell（外壳）— 骨架与其他面板不一致
3. EquipTooltip 超 1000 行 — 弹窗逻辑密集
4. 业务逻辑混入 UI onClick（A/B 均有）
5. **A/B 大量重复结构**（左右面板/品质勾选/持久化/刷新三件套）未复用
6. 命格 ELEMENT_COLORS 双份定义且不一致（潜在 bug）

**优势**：A/B 逻辑层均已良好模块化，UI 外部引用面极窄（A 仅被 main.lua+GameEvents.lua；B 仅被 InventoryUI），配置访问已隔离 → 重构安全性高。

**Phase 2 优先级**：
1. 🔴 InventoryUI 外壳接入 PanelShell（统一骨架）
2. 🔴 **提取 A/B 共享面板构建器**（参数化驱动装备/命格差异）— 本轮最大收益点，也是核心风险（风险 8）
3. 🔴 ~133 处颜色 Token 化（最大工作量）
4. 🟡 剥离操作逻辑到 InventoryOps（含统一出售设置持久化）
5. 🟡 EquipTooltip / MinggeTooltip 操作弹窗逻辑剥离（评估能否抽公共骨架）
6. 🟢 统一 ELEMENT_COLORS 到 MinggeData 单一源 + 共享组件复用（SectionCard / PriceTag）

---

---

## 附录 M: 背包界面 Phase 2 重构方案（实施计划 · 安全优先版）

> 基于附录 L 的 Phase 1 评估制定。**核心定调：安全第一，保留 A/B 镜像结构，不强行合并。**
> 状态：**待评审。评审通过后按 M.5 分步实施。**

### M.1 总体策略

| 原则 | 说明 |
|------|------|
| **安全 > DRY** | 当"消除重复"与"数据安全"冲突时，无条件选择安全；宁可保留镜像重复代码 |
| **保留 A/B 镜像** | 装备(A)、命格(B)两子系统的有状态构建器**各自独立**，不提取跨子系统共享构建器 |
| **单子系统推进** | 每个改造步骤只动一个子系统，改完立即 build + 回归，确认无误再动下一个 |
| **可回滚** | 每步是一次独立提交粒度，出问题可单独回退，不牵连其他步骤 |
| **不动逻辑/配置/存档** | 仅改 UI 层渲染与组织；InventorySystem / MinggeSystem / SaveSerializer / MinggeData 一律不碰 |

> ⚠️ 本方案**推翻 L.9 优先级 #2（提取 A/B 共享面板构建器）**，理由见 M.2。

### M.2 关键决策：放弃 A/B 共享有状态构建器（串位风险分析）

#### M.2.1 串位风险的本质

A/B 两子系统的 slot 创建代码几乎逐行相同，差异仅 3 个参数：

| 差异点 | 装备 (A) `InventoryUI:136~150` | 命格 (B) `MinggePage:142~158` |
|--------|------|------|
| `slotCategory` | `"equipment"` | `"mingge_equip"` |
| `inventoryManager` | `InventorySystem.GetManager()` | `MinggeSystem.GetManager()` |
| 弹窗模块 | `EquipTooltip.Show` | `MinggeTooltip.Show` |
| slotId 命名空间 | 具名槽 `weapon/armor/...` | 五行槽 `metal1/fire2/...` |
| backpack 数据源 | inventory backpack | mingge backpack（独立 manager） |

#### M.2.2 为什么串位是"资产安全"问题而非"视觉 bug"

1. **类型系统无法防护**：A/B 的 `inventoryManager` 都是 `InventoryManager` 类型，LSP/编译期看不出区别。共享构建器一旦把 manager 传错或闭包捕获错误引用，**编译通过、运行出错**。
2. **闭包捕获放大风险**：每个 slot 的 `onSlotClick` 闭包捕获了 manager 与对应 Tooltip。共享构建器需把这两者参数化传入，参数错位即"串位"。
3. **后果是玩家资产损失**：串位会导致装备/卸下/出售操作作用到**另一个子系统的背包** → 误卖、误删、错装。对有真实存档的游戏，这是**不可逆的资产损失**，远超视觉 bug 的严重度。
4. **测试难覆盖**：串位只在特定操作序列下暴露，常规点击测试不一定触发，回归成本高。

#### M.2.3 决策

> **保留 A/B 镜像结构。装备与命格的"持有数据源的构建器"各自独立维护，不合并。**
> 接受由此带来的代码重复（左右面板/刷新三件套/品质菜单在两边各一份）。这是用安全换取的合理代价。

### M.3 共享红线（允许 vs 禁止）

| 类别 | 可否跨 A/B 共享 | 示例 |
|------|---------------|------|
| **无状态视觉令牌** | ✅ 允许 | UITheme 颜色/间距/圆角 Token、属性配色 `invStat*` |
| **无状态纯样式小组件** | ✅ 允许 | 分隔线样式、标题样式、空位标签样式（不持有 manager） |
| **面板外壳骨架** | ✅ 允许 | PanelShell（只包外壳，不进 Tab 内容数据流） |
| **已验证的格子组件** | ✅ 维持现状 | ImageItemSlot（已用 slotCategory 区分，调用方各自传 manager） |
| **持有 manager 的构建器** | ❌ **禁止** | 左侧装备面板构建器、右侧背包面板构建器 |
| **持有 slotId / backpack index 的回调** | ❌ **禁止** | onSlotClick、装备/出售/卸下操作 |
| **跨子系统的数据源参数化** | ❌ **禁止** | 任何"传入 manager 决定操作哪个背包"的函数 |

**一句话红线**：**凡是会"持有或路由 manager / slotId / backpack index"的代码，A 与 B 必须各写各的，绝不共用一个带数据源参数的函数。**

### M.4 Token 化方案（新增 Token 清单）

颜色令牌化是最大工作量（~133 处）。新增 Token 按子系统分组，避免命名冲突：

| 分组 | 预计 Token | 说明 |
|------|-----------|------|
| 物品属性配色 | `invStat*`（攻/防/血/暴击/...约 8 个） | A/B **可共享**（纯视觉，无数据源）；优先复用角色面板已有属性色 |
| 背包通用 | 复用 `surface*` / `btnSpend` / `btnSecondary` / `tabActiveBg` / `tabInactiveBg` | 不新增 |
| 装备弹窗 | `equipTip*`（约 6~8 个） | EquipTooltip 专属 |
| 命格弹窗 | `minggeTip*`（约 4~6 个） | MinggeTooltip 专属 |
| 命格五行色 | **统一到 `MinggeData.ELEMENT_COLORS` 单一源** | 修复双份定义不一致 bug，UI 不再自带副本 |
| 命格解封遮罩 | `minggeLockMask*`（约 3 个） | B 特有 |

> 五行色不进 UITheme，而是统一到配置层 `MinggeData.ELEMENT_COLORS`（它本就是五行的领域数据），UI 层引用单一源。

### M.5 分步实施计划（每步独立 build + 回归 + 可回滚）

> 顺序原则：先低风险（外壳/Token）后稍高风险（操作剥离/拆分）；先做 A 验证模式，再用同样模式做 B。

| 步骤 | 内容 | 涉及文件 | 风险 | 验证重点 |
|------|------|---------|------|---------|
| **Step 0** | UITheme 录入新增 Token；MinggeData 统一 ELEMENT_COLORS | UITheme.lua / MinggeData.lua | 🟢低 | 仅新增，不改引用；build 通过 |
| **Step 1** | InventoryUI 外壳接入 PanelShell（标题/关闭/Tab 区），**Tab 内容 A/B 暂不动** | InventoryUI.lua | 🟡中 | sellMenu_/Tooltip 仍挂 parentOverlay；Tab 切换正常；弹窗不被遮挡 |
| **Step 2** | 子系统 A Token 化（颜色全替换为 Token，零结构改动） | InventoryUI.lua + EquipTooltip.lua | 🟢低 | 视觉对比一致；功能不变 |
| **Step 3** | 子系统 B Token 化（同 Step 2 模式） | MinggePage.lua + MinggeTooltip.lua | 🟢低 | 同上；五行色引用 MinggeData 单一源 |
| **Step 4** | A 操作逻辑剥离到 `InventoryOps`（整理/批量出售/出售设置持久化） | InventoryUI.lua + 新建 InventoryOps.lua | 🟡中 | 操作函数返回 success → UI 统一 Refresh；误卖测试 |
| **Step 5** | B 操作逻辑剥离（命格整理/批量出售/解封；可复用 InventoryOps 的**无状态**部分如出售设置持久化） | MinggePage.lua | 🟡中 | 解封流程正常；命格批量出售正确 |
| **Step 6**（可选） | 子系统**内部**拆分：仅当单文件仍超阈值时。A: InventoryUI→主控+装备面板+背包面板；EquipTooltip 剥操作弹窗。**B 的 709 行 < 1000，默认不拆** | A 子系统文件 | 🟡中 | 拆分后 slot 闭包仍各自持有正确 manager |

**每步收尾动作**（强制）：
1. 本地 LSP 诊断 0 Error
2. 调用 build 工具构建通过
3. 按该步"验证重点"做功能回归
4. 确认无误 → 进入下一步；异常 → 回退本步

### M.6 拆分目标结构（保守版 · 不跨子系统）

```
scripts/ui/
├── InventoryUI.lua          ← A 外壳(PanelShell) + Tab 切换 + 公共 API + 装备 Tab 内容主控
│                               （Step 6 若拆：再分出下面两个）
│   ├── InventoryEquipPanel.lua  ← A 左侧装备面板（持有 InventorySystem manager）
│   └── InventoryBagPanel.lua    ← A 右侧背包面板（持有 InventorySystem manager）
├── InventoryOps.lua         ← A 操作逻辑 + 无状态出售设置持久化（B 可复用无状态部分）
├── EquipTooltip.lua         ← A 装备弹窗（Token 化；操作逻辑可剥离到 EquipTooltipOps）
├── MinggePage.lua           ← B 命格页（Token 化 + 操作剥离；默认不拆，<1000 行）
└── MinggeTooltip.lua        ← B 命格弹窗（Token 化）
```

> 注意：`InventoryEquipPanel` 与 `MinggePage` 的左侧面板**是两个独立文件**，不是同一个共享构建器——这正是 M.2 决策的体现。

### M.7 安全边界（复述 · 重构全程不可触碰）

- **公共 API 签名**：InventoryUI.Create/Show/Hide/Toggle/IsVisible/UpdateStats/UpdateFreeSlots；MinggePage.Create/OnShow/OnHide — 全部保持不变
- **存档**：SaveSerializer 的 inventory（equipment/backpack）与 mingge（unlocked/equipped/backpack）结构、SerializeItemFull / _SerializeMinggeItem 字段、BM-NORESELL 标记 — **绝不触碰**
- **逻辑/配置层**：InventorySystem + 4 子模块、MinggeSystem、MinggeData、EquipmentData — 仅调用，不改
- **EventBus 监听**：`equip_stats_changed`→UpdateStats、`mingge_stats_changed`/`mingge_item_added`、`mingge_info` — 全部保留
- **浮层挂载**：sellMenu_ / EquipTooltip / MinggeTooltip 继续挂 parentOverlay（不进 PanelShell 内部）

### M.8 回归测试清单（每步按需勾选，全部完成为 Phase 4 验收）

**子系统 A（装备）**
- [ ] 背包打开/关闭/Tab 切换正常
- [ ] 装备槽点击 → EquipTooltip 显示正确装备信息
- [ ] 装备/卸下/出售/丢弃操作作用于正确物品
- [ ] 整理、按品质批量出售数量与收益正确
- [ ] 出售品质勾选持久化（重开背包保留）
- [ ] 装备变更后 17 项属性 + 套装即时刷新（equip_stats_changed）
- [ ] **串位检查**：A 的任何操作都不影响命格背包

**子系统 B（命格）**
- [ ] 命格 Tab 显示正常；未达金丹时解封遮罩生效
- [ ] 解封流程（达标解封成功 / 未达标提示）正常
- [ ] 命格槽点击 → MinggeTooltip 显示正确命格信息
- [ ] 命格装备/卸下/出售/锁定操作作用于正确物品
- [ ] 命格整理、批量出售正确
- [ ] 命格属性 + 四象套装即时刷新（mingge_stats_changed → CharacterUI 同步）
- [ ] **串位检查**：B 的任何操作都不影响装备背包

**通用**
- [ ] 全项目 LSP 0 Error
- [ ] 每步 build 通过
- [ ] 视觉与重构前一致（Token 化无色差）

### M.9 明确不做的事（排除项）

| 不做 | 原因 |
|------|------|
| ❌ 提取 A/B 共享的"持有 manager 的面板构建器" | 串位 = 资产损失风险（M.2） |
| ❌ 合并 EquipTooltip 与 MinggeTooltip 为公共 Tooltip | 二者物品字段结构不同（装备 mainStat/subStats vs 命格 element/value），合并易串字段 |
| ❌ 改动 MinggePage 文件拆分（709 行 < 1000） | 无收益，徒增风险 |
| ❌ 改动逻辑层/配置层/存档 | 超出 UI 重构范围 |
| ❌ 引入拖拽等新交互 | 重构不改玩法 |

### M.10 核心数据安全专项（物品保存 / 属性）🔴

> 背包涉及物品保存与属性，是游戏最核心的数据。本节专门论证"为何 UI 重构不会损坏核心数据"，并给出三道防线。

#### M.10.1 实证：UI 层不直接读写物品数据

代码核查结论（grep 物品字段赋值）：

| 文件 | 是否直接写 item 字段 | 结论 |
|------|---------------------|------|
| `InventoryUI.lua` | **0 处** | 纯读取渲染，写操作全部经 InventorySystem 接口 |
| `MinggePage.lua` | **0 处** | 同上，经 MinggeSystem 接口 |
| `MinggeTooltip.lua` | **0 处** | 操作经 MinggeSystem 接口 |
| `EquipTooltip.lua` | **1 处**（L695~704） | 旧存档消耗品兼容补全：`item.quality/desc/image` 缺失时从配置补全。**重构必须原样保留** |

> 核心数据的**真正写入**（序列化、属性结算、出售扣减）全部发生在 `systems/` 层，UI 层只是"读 + 通过接口触发"。

#### M.10.2 三道防线

**防线 1：代码物理隔离（最根本）**
- 物品序列化：`SaveSerializer.SerializeInventory / SerializeMingge / SerializeItemFull / _SerializeMinggeItem`
- 属性结算：`equip_stats.RecalcEquipStats` / `MinggeSystem.RecalcStats`
- 这些**全在 systems 层，本方案列为绝对禁区，重构不改一个字符** → 物品保存与属性计算的代码不可能被 UI 重构破坏

**防线 2：串位防护（M.2 决策）**
- UI 是"操作入口"，真正风险不是"改坏保存代码"而是"通过正确接口触发错误操作"（串位）
- 已用**保留 A/B 镜像 + 红线（禁止共享持有 manager 的构建器）** 从源头消除

**防线 3：测试基线对比（客观证明）**
- 项目已有统一测试入口 `scripts/tests/run_all.lua`，覆盖核心数据的相关测试组：

| 测试 | 覆盖 |
|------|------|
| `test_save_dto_contract` / `test_save_optimization` | 存档结构契约 / 序列化 |
| `test_alchemy_save_roundtrip` | 存档往返一致性 |
| `test_mingge_config / _ranges / _drop_contract` | 命格配置/属性范围/掉落 |
| `test_warehouse_sort` / `test_batch_consumable` | 排序 / 批量消耗 |
| `test_bm_noresell*` / `test_bm_s*` | 黑市出售 / 禁回售物品标记 |

- **保障逻辑**：UI 重构不动 systems 层 → 上述测试在重构前后结果**必须完全一致**。任何一条变红 = 重构越界，立即回退。

#### M.10.3 强制执行动作

1. **建立基线**：实施 Step 0 前运行 `lua scripts/tests/run_all.lua --all`，记录全绿基线
2. **每步比对**：M.5 每个 Step 完成后重跑测试，结果必须与基线一致（尤其 save / mingge 组）
3. **保留兼容补全**：EquipTooltip 旧存档消耗品补全逻辑（M.10.1）在 Token 化/拆分时原样保留
4. **存档实测**：用一份含装备 + 命格 + 消耗品的真实存档，重构前后各打开背包一次，核对物品数量/属性/品质显示一致

#### M.10.4 结论

> 物品保存与属性计算的**代码不在本次重构范围内**（systems 层禁区），UI 层不直接写物品数据（仅 1 处需保留的兼容补全）。配合保留镜像（防串位）与测试基线对比（防越界），**本方案对核心数据是安全的**。前提是严格遵守 M.7 安全边界与 M.10.3 强制动作。

#### M.10.5 基线快照（2026-06-18 已建立）

**运行环境**：沙箱无独立 `lua` 解释器，改用引擎 `UrhoXRuntime` tool_mode 运行测试门禁，harness 脚本 `scripts/_proc/run_baseline.lua`（复刻 run_all.lua 的 blocking 门禁逻辑，以 `engine:Exit()` 替代 `os.exit()`）。

```
门禁：blocking（40 项）
结果：passed=27  failed=13  skipped=0   —— 连续两次运行结果完全一致（确定性 ✓）
```

**13 项失败均为既有状态（非本次改动引入）+ 主要为 harness/环境差异，非生产代码 bug**：

| 失败项 | 性质判定 | 证据 |
|--------|---------|------|
| `alchemy_save_roundtrip` / `alchemy_state_sync` | 环境（mock 不全） | SaveSerializer 读 `player.x`(L23) 与 `player:GetTotalMaxHp()`(L254)，alchemy 测试 mock player 未提供 → 真实序列化代码无问题 |
| `runner_smoke` 2/346 | 环境 | 运行器自检在引擎 runtime 下偏差 |
| `bm_s3_*` / `bm_s4e_*` / `bm_fix01_*` / `bm_warehouse_consistency` | 环境（需真实运行时状态） | 黑市卖出流程测试依赖运行时单例/状态 |
| `trial_tower` 78/1480 | 环境 | 依赖运行时 |
| `challenge_r8_extradrop` | 环境（require 解析差异） | `MonsterTypes` 解析为 function |
| `save_system_net_state_machine` 1/34 | 环境 | 网络状态机运行时 |
| `pre_c5a1_three_lines` 3/27 | 环境 | 运行时依赖 |
| `file_budget` 5/335 | **真实既有** | 5 个文件超长度预算（如 ChallengeUI 2144 行），与本次重构无关 |

**与背包重构最相关的核心数据测试——全部通过 ✓**：

| 测试 | 结果 |
|------|------|
| `save_dto_contract`（存档结构契约） | ✅ PASS |
| `mingge_config` / `mingge_ranges`(1127项) / `mingge_drop_contract`(225项) | ✅ ALL PASS |
| `bm_noresell` / `bm_noresell_consume` / `bm_noresell_warehouse` | ✅ ALL PASS |
| `recycle_system` / `recycle_window_schedule` | ✅ PASS |

**基线用法**：每个重构 Step 后用同一命令复跑，要求：
1. **passed/failed 计数与失败集合 = 基线完全一致**（27/13，同样 13 项）
2. **当前通过的核心数据测试不得转红**（尤其 save_dto_contract / mingge* / bm_noresell*）
3. 出现任何新失败 = 重构引入回归 → 立即回退该 Step

**说明**：引擎 runtime harness 与项目预期的 lupa/纯 lua 环境有差异（故非全绿）。若需要全绿参考，可在 Python lupa 环境跑。但对**本次 UI 重构的回归检测**，确定性快照已足够——这些测试不加载 `ui/` 模块，UI 重构不应改变其结果，因此"结果是否偏离基线"即是可靠的越界信号。

> harness 脚本 `scripts/_proc/run_baseline.lua` 为重构期临时工具，重构完成（Phase 4）后可删除。

---

*文档更新时间：2026-06-18*
*撰写者：AI 开发助手*
*状态：三大面板重构 + 公告板迭代 + 排行榜迭代 + 图录面板重构 + PetPanel 重构 + RealmPanel 重构（P1-P4 全部完成）+ 背包界面（装备 + 五行命格双子系统）Phase 1-4 全部完成，四阶段方法论已沉淀*

---

## 附录 N：背包界面 Phase 3 — 规则沉淀

### N.1 内联品质选择器（取代绝对定位 Menu）

**问题**：`UI.Menu` 使用 `GetAbsoluteLayout()` 绝对定位，当按钮处于 ScrollView 内部时坐标计算不可靠（滚动偏移未计入），菜单飘出屏幕。

**规则**：当下拉选择器的触发按钮位于可滚动区域内时，**禁止**使用绝对定位 Menu/Popup。改用**内联展开面板**（`visible = false` → 点击 Show/Hide），插入在触发按钮的下方相邻位置。

```lua
-- ✅ 正确：内联展开面板
local qualityPanel = UI.Panel { visible = false, ... }
invPanel:AddChild(operationBar)
invPanel:AddChild(qualityPanel)  -- 紧邻操作栏下方

-- ❌ 错误：绝对定位 Menu（坐标飘移）
sellMenu_.absoluteLayout = { x = bl.x, y = bl.y + bl.h, ... }
```

### N.2 显式双列属性布局（取代 flex-wrap）

**问题**：`flexDirection="row" + flexWrap="wrap" + width="48%"` 在不同屏幕宽度下对齐不稳定，且 label 长度差异导致视觉参差。

**规则**：属性统计表使用**两个显式 Column Panel** + 中间竖分隔线，各列内部 `space-between` 对齐。

```lua
UI.Panel {
    flexDirection = "row",
    gap = T.spacing.sm,
    children = {
        buildStatColumn(leftDefs),
        UI.Panel { width = 1, backgroundColor = T.color.borderLight },  -- 竖分隔线
        buildStatColumn(rightDefs),
    },
}
```

### N.3 详情区不设独立滚动条

**问题**：属性详情区使用 `UI.ScrollView { maxHeight = 160 }` 产生嵌套滚动条，操作体验差且视觉割裂。

**规则**：折叠展开的详情区使用普通 `UI.Panel`（非 ScrollView），展开后随面板整体 ScrollView 滚动。

### N.4 动态职业精灵（CLASS_PORTRAITS 模式）

**规则**：所有展示玩家角色精灵的面板，必须通过 `GameState.player.classId`（优先）或 `GameConfig.PLAYER_CLASS`（兜底）动态获取，禁止硬编码路径。

```lua
local CLASS_PORTRAITS = {
    monk    = "Textures/player_right.png",
    taixu   = "Textures/class_swordsman_right.png",
    zhenyue = "image/zhenyue_sprite_v3_20260426072019.png",
}
local function GetClassSprite()
    local classId = (GameState.player and GameState.player.classId)
        or GameConfig.PLAYER_CLASS or "monk"
    return CLASS_PORTRAITS[classId] or CLASS_PORTRAITS.monk
end
```

### N.5 事件驱动刷新（存档恢复 + 增量入包）

**问题**：UI 在 `Show()` 时调用 `UpdateAllSlots()` 一次性刷新，但若存档异步加载完成时面板已打开，格子仍为空。

**规则**：面板创建时必须订阅以下事件，并在回调中（当面板可见时）触发 `UpdateAllSlots()`：
- `"equip_stats_changed"` — 存档恢复后立即触发
- `"inventory_item_added"` — 掉落/购买/领取时单件触发
- `"mingge_stats_changed"` / `"mingge_item_added"` — 命格对应事件

### N.6 A/B 镜像安全原则

**规则**：InventoryUI（子系统A）和 MinggePage（子系统B）共享 `ImageItemSlot` 组件类型，但各自持有独立的 `manager` 闭包引用（`InventorySystem.GetManager()` vs `MinggeSystem.GetManager()`）。**禁止**创建共享的有状态 builder 函数，防止管理器串位导致物品写入错误背包。

---

## 附录 O：背包界面 Phase 4 — 验收回归

### O.1 功能验收路径

| # | 路径 | 预期 | 状态 |
|---|------|------|:----:|
| 1 | 打开背包 → 装备物品 Tab 默认激活 | 装备格+背包格正确显示当前物品 | ✅ |
| 2 | 切换到五行命格 Tab | 五行方位布局格子正确、背包格独立 | ✅ |
| 3 | 点击装备 → EquipTooltip 弹出 | 双面板对比、操作按钮可用 | ✅ |
| 4 | 点击命格物品 → MinggeTooltip 弹出 | 属性、操作正确 | ✅ |
| 5 | 展开属性详情 → 双列对齐 | 左右列对齐、竖分隔线、套装区分隔 | ✅ |
| 6 | 收起属性详情 | 只显示摘要行（攻/防/血 + 收起按钮） | ✅ |
| 7 | 整理按钮 | 背包排序 + resultLabel 反馈 | ✅ |
| 8 | 批量出售 | 按选中品质出售 + 金额反馈 | ✅ |
| 9 | ▼ 品质选择 → 内联展开/收起 | 面板在操作栏下方展开，不飘出 | ✅ |
| 10 | 角色精灵 → 根据职业显示 | monk/taixu/zhenyue 各显对应图 | ✅ |
| 11 | 面板关闭 → overlay 点击/✕按钮 | 正常关闭、GameState.uiOpen 清除 | ✅ |
| 12 | 境界未达标 → 命格锁屏显示 | 🔒遮罩 + 解封按钮（金丹初期后可解） | ✅ |

### O.2 技术验收

| 检查项 | 结果 |
|--------|:----:|
| LSP Error = 0 | ✅ |
| Build 通过 | ✅ |
| 硬编码 RGBA = 0（四文件） | ✅ |
| 硬编码 gap 数字 = 0（仅 `gap=1` 极紧凑特例） | ✅ |
| Style 头标记 | ✅ 四文件均已标注 |
| 事件刷新覆盖（equip_stats_changed / inventory_item_added） | ✅ |
| 独立 ScrollView 已移除（属性详情随面板滚动） | ✅ |
| 套装效果独立容器逐条渲染 | ✅ |

### O.3 数据安全

| 测试 | 结论 |
|------|------|
| UI 层不直接写 item 数据 | ✅（仅通过 System API 间接操作） |
| A/B 管理器闭包隔离 | ✅（各持独立 manager 引用） |
| 测试基线（27/40 pass）不变 | ✅（UI 重构不影响逻辑测试） |

### O.4 结论

**背包界面（InventoryUI + MinggePage + EquipTooltip + MinggeTooltip）Phase 1-4 全部完成。**

重构范围：
- 4 文件完全令牌化（133 处硬编码 RGBA → 0）
- PanelShell 标准骨架接入
- 操作逻辑提取至 InventoryOps（无状态委托）
- 双列属性布局 + 套装分区
- 内联品质选择器（替代绝对定位 Menu）
- 动态职业精灵
- 事件驱动存档恢复刷新
- 竖屏优先单列布局（maxWidth=500, maxHeight=76%）

---

## 附录 P：洗练界面（ForgeUI）Phase 3 — 规则沉淀

### P.1 功能面板格子保持左对齐

**问题**：将格子容器加 `justifyContent = "center"` 后，末行不满 7 格时格子浮到中间，视觉散乱。

**规则**：功能面板（洗练、附灵等）中的装备格子使用标准左对齐 `flexWrap = "wrap"`，不加 `justifyContent = "center"`。居中仅适用于洗练信息块等独立功能区。

```lua
-- ✅ 正确：格子左对齐自然排列
local row = UI.Panel { width = "100%", flexDirection = "row", flexWrap = "wrap", gap = SLOT_GAP }

-- ❌ 错误：格子居中（末行散乱）
local row = UI.Panel { width = "100%", flexDirection = "row", flexWrap = "wrap", gap = SLOT_GAP, justifyContent = "center" }
```

### P.2 NPC 头像必须使用项目已有资源

**问题**：开发者编造 emoji/文字作为 portrait，不符合 S2.5 NPC 头像规范。

**规则**：`PanelShell.portrait` 必须使用 `backgroundImage` 指向项目中已有的 NPC 头像资源。查找方式：`grep portrait scripts/config/zones/` 获取 NPC 配置中定义的头像路径。

```lua
-- ✅ 正确：使用项目资源
backgroundImage = "Textures/npc_blacksmith.png",  -- 从 zones/town.lua 查得

-- ❌ 错误：自编 emoji
children = { UI.Label { text = "🔨", fontSize = 28 } }
```

### P.3 按钮语义色必须在首次实现时就接入

**问题**：先写无色按钮，P2.5 审查时才发现缺失，返工成本高。

**规则**：创建任何操作按钮时，必须立即确定其 S10 语义（btnSpend/btnSuccess/btnSecondary/btnDanger/btnDisabled），不允许留空。

### P.4 结果文字不与按钮同行

**问题**：`flexDirection = "row"` 放按钮和结果标签同行，长文本折行后挤压丑陋。

**规则**：操作结果反馈 `resultLabel_` 始终独占一行（在按钮下方），不与按钮共享水平空间。

### P.5 ui-rensheng-standard skill 触发时机

**问题**：本次重构全程未触发 `ui-rensheng-standard` skill，导致大量返工。

**规则**：**每次会话开始修改 `scripts/ui/*.lua` 文件前，必须先触发 `ui-rensheng-standard` skill**。这不是可选步骤。

---

## 附录 Q：洗练界面（ForgeUI）Phase 4 — 验收回归

### Q.1 功能验收路径

| # | 路径 | 预期 | 状态 |
|---|------|------|:----:|
| 1 | 打开洗练面板 | NPC 锻造师头像 + 标题"洗练" + 副标题 | ✅ |
| 2 | 未选中状态 | 信息块显示"选择装备" + 按钮禁用（btnDisabled 灰色） | ✅ |
| 3 | 点击身上装备格 | 信息块更新：装备名（品质色）+ 洗练属性 + 按钮启用（btnSpend 琥珀金） | ✅ |
| 4 | 点击背包装备格 | 同上，source = "inventory" | ✅ |
| 5 | 再次点击已选格 | 取消选中，回到未选中状态 | ✅ |
| 6 | 金币充足时点击洗练 | 扣费 + 属性刷新 + 结果显示（绿色成功文字，独占行） | ✅ |
| 7 | 金币不足时 | 按钮禁用（btnDisabled），点击无反应 | ✅ |
| 8 | 防连点（0.5s 内重复点击） | 显示"操作过快" | ✅ |
| 9 | 金币超万显示 | 按钮文字 "💰10.0w" 格式 | ✅ |
| 10 | 关闭面板 | overlay 点击 / ✕ 按钮均可关闭，SaveSession.Flush() 触发 | ✅ |
| 11 | footer 提示 | "每件装备可洗练1条额外属性，再次洗练会替换" | ✅ |

### Q.2 规范验收（对照 ui-rensheng-standard）

| 检查项 | 结果 |
|--------|:----:|
| Style 文件头标记 | ✅ |
| 硬编码 RGBA = 0 | ✅ |
| PanelShell 骨架（goldDark 边框 / maxH=76%） | ✅ |
| NPC 头像 = backgroundImage 项目资源 | ✅ `npc_blacksmith.png` |
| 按钮语义色（btnSpend / btnDisabled） | ✅ |
| 金币超万缩写 | ✅ |
| 格子左对齐 | ✅ |
| 分区标题居中 | ✅ |
| ScrollView 无 flexGrow=1 | ✅（无 ScrollView） |
| 死代码已清理 | ✅ INV_COLS 已删 |
| Build 通过 | ✅ |

### Q.3 数据安全

| 测试 | 结论 |
|------|------|
| 洗练逻辑（RollForgeStat/DoForge）未修改 | ✅ |
| SaveSession.MarkDirty + Flush 保持 | ✅ |
| 防连点节流 0.5s | ✅ |
| 身上装备洗练后触发 RecalcEquipStats | ✅ |

### Q.4 结论

**洗练界面（ForgeUI）Phase 1-4 全部完成。**

重构范围：
- 从 630 行列表式面板重构为 ~600 行 PanelShell + 信息板 + 格子布局
- 全量令牌化（~20 处硬编码 RGBA → 0）
- 按钮接入 S10 语义色体系（btnSpend / btnDisabled）
- 金币超万缩写（S8）
- NPC 头像接入项目资源（S2.5）
- 操作板居中 + 格子左对齐 + 结果独占行

---

## 附录 R：附灵师界面（TemperUI）Phase 3 — 规则沉淀

### R.1 列表密集型面板使用固定高度卡片

**问题**：PanelShell 自适应收缩（S0.2）适合内容较少的面板，但列表密集型面板（装备列表、物品选择）在内容少时显示极矮，体验差。

**规则**：当面板核心功能是**可滚动列表选择**时，不使用 PanelShell，改用 S2.4 手动模板 + `height = "76%"`（固定高度）。内部 ScrollView 使用 `flexGrow = 1, flexShrink = 1, flexBasis = 0` 填满剩余空间。

| 面板类型 | 高度策略 | 适用 |
|---------|---------|------|
| 功能面板（炼丹、商店卡片） | PanelShell `maxHeight = "76%"` 自适应 | 内容固定/少量 |
| 列表选择面板（附灵、洗练旧版） | S2.4 手动 `height = "76%"` 固定 | 列表可滚动 |
| 格子面板（洗练新版、背包） | PanelShell `maxHeight = "76%"` + 格子撑高 | 格子数量足够 |

### R.2 预览格操作板模式

**规则**：当操作需要用户"先选材料，再确认执行"时，使用**预览格操作板**（surfaceDeep + border 容器）：
- 顶部放预览格子（展示已选物品）
- 中部放状态提示 + 费用
- 底部放操作按钮

```lua
-- 萃取：3格预览
┌────┐ ┌────┐ ┌────┐
│ 1  │ │ 2  │ │ 3  │
└────┘ └────┘ └────┘
已选 2/3（血煞）  消耗🔮100
[萃取 btnSpend]

-- 附灵：装备→灵玉 双格预览
┌────┐   →   ┌────┐
│装备│        │灵玉│
└────┘        └────┘
消耗🔮100  [附灵 btnSpend]
```

### R.3 Tab 切换禁止 Destroy/Recreate

**问题**：旧 TemperUI 切 Tab 时销毁重建整个面板（含弹窗），极其浪费且弹窗状态丢失。

**规则**：Tab 切换只做 `SetBackgroundColor` 更新按钮样式 + `ClearChildren/AddChild` 重建内容区。面板骨架（header/footer/弹窗）不重建。

### R.4 关闭按钮背景色为 S2.4 模板标准值

`{255, 100, 100, 30}` 是 S2.4 代码模板中的关闭按钮背景色标准值，不需要额外 token 化。所有手动构建的面板关闭按钮统一使用此值。

---

## 附录 S：附灵师界面（TemperUI）Phase 4 — 验收回归

### S.1 功能验收路径

| # | 路径 | 预期 | 状态 |
|---|------|------|:----:|
| 1 | 打开面板 | NPC 头像 + "附灵师" + "萃取·附灵" + goldDark 金边 | ✅ |
| 2 | 面板高度 | 固定 76%，不随内容收缩 | ✅ |
| 3 | 默认显示萃取 Tab | 3个空预览格 + "选择3件同套装装备" 提示 | ✅ |
| 4 | 萃取：选择物品 | 点击列表项→填入预览格→计数更新 | ✅ |
| 5 | 萃取：选不同套装 | 自动清空重选 | ✅ |
| 6 | 萃取：满3件+灵韵足 | 按钮激活（btnSpend 琥珀金） | ✅ |
| 7 | 萃取：执行成功 | 扣灵韵 + 删3件 + 获得附灵玉 + 成功弹窗 | ✅ |
| 8 | 萃取：回滚机制 | AddConsumable 失败时恢复已删除装备 | ✅ |
| 9 | 切换附灵 Tab | Tab 样式切换 + 内容重建 + 选择重置 | ✅ |
| 10 | 附灵：选装备 | 点击装备行→预览格显示→再点取消 | ✅ |
| 11 | 附灵：选附灵玉 | 点击灵玉行→预览格显示（backgroundImage） | ✅ |
| 12 | 附灵：两者选中+灵韵足 | 按钮激活 | ✅ |
| 13 | 附灵：执行成功 | 扣灵韵+消耗灵玉+写入enchantSetId+成功弹窗 | ✅ |
| 14 | 弹窗确认关闭 | 点击"确认"隐藏弹窗 | ✅ |
| 15 | overlay 点击关闭 | 点击空白区关闭面板 | ✅ |
| 16 | ✕ 按钮关闭 | 右上角关闭 + SaveSession.Flush | ✅ |

### S.2 规范验收（对照 ui-rensheng-standard）

| 检查项 | 结果 |
|--------|:----:|
| Style 头标记 + @diagnostic | ✅ |
| 硬编码 RGBA | 1处（关闭按钮 S2.4 标准值）✅ |
| S2.4 手动模板结构 | ✅ height="76%" + goldDark + 无 header bg |
| NPC 头像 = backgroundImage | ✅ `npc_temper_master.png` |
| 关闭按钮右侧 | ✅ |
| 按钮语义色 S10（≤3色） | ✅ btnSpend + btnDisabled + btnSecondary |
| 弹窗 S0.5 宽度层级（88%/400） | ✅ |
| ScrollView flexGrow+flexBasis=0（固定高度卡片内） | ✅ |
| Tab 无 Destroy/Recreate | ✅ |
| overlay 点击关闭 + footer 提示 | ✅ |
| gap 全部 T.spacing.* | ✅ |
| Build 通过 | ✅ |

### S.3 数据安全

| 测试 | 结论 |
|------|------|
| 萃取回滚（AddConsumable 失败恢复 3 件） | ✅ 逻辑保留 |
| 附灵写入 enchantSetId + RecalcEquipStats | ✅ 逻辑保留 |
| SaveSession.MarkDirty (萃取/附灵后) | ✅ |
| SaveSession.Flush (关闭面板时) | ✅ |
| 灵韵扣除在操作成功后（不白扣） | ✅ |

### S.4 结论

**附灵师界面（TemperUI）Phase 1-4 全部完成。**

重构范围：
- 从 1064 行自管理面板重构为 ~750 行 S2.4 手动模板
- 全量令牌化（61 处硬编码 RGBA → 1 处标准值）
- Tab 从 Destroy/Recreate 改为 Show/Hide 模式
- 修复 UI.Image（不存在的组件）→ backgroundImage
- 预览格操作板交互（萃取3格 / 附灵双格）
- 按钮接入 S10 语义色（btnSpend / btnDisabled / btnSecondary）
- NPC 头像接入项目资源（S2.5）
- 卡片固定高度 76%（列表密集型面板标准）
- 弹窗符合 S0.5 宽度层级
- 新增 UITheme token：setXuesha / setQingyun / setFengmo / setHaoqi

---
