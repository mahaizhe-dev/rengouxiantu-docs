# UI 重构方案与过程文档

> **目的**：供其他 AI/开发者交叉审查本轮 UI 架构改造的设计决策与实施路径。
> **范围**：角色面板（CharacterUI）、装备商人面板（EquipShopUI）、炼丹炉面板（AlchemyUI）。
> **时间**：2026-06-07 ~ 2026-06-08

---

## 目录

1. [设计原则总纲](#1-设计原则总纲)
2. [装备商人面板重构（已完成）](#2-装备商人面板重构已完成)
3. [角色面板重构（已完成）](#3-角色面板重构已完成)
4. [炼丹炉面板重构方案（待实施）](#4-炼丹炉面板重构方案待实施)
5. [共享组件清单](#5-共享组件清单)
6. [UITheme 设计令牌体系](#6-uitheme-设计令牌体系)
7. [审查要点与疑问清单](#7-审查要点与疑问清单)

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
| 间距 | xs=4 / sm=8 / md=12 / lg=16 / xl=24，8px 为基础单位 |

### 1.2 架构原则

1. **令牌驱动**：所有颜色/尺寸/间距通过 `UITheme.lua` 中心化管理，禁止硬编码 RGBA
2. **骨架统一**：所有面板共用 `PanelShell`（overlay → card → header → scroll → footer）
3. **组件复用**：可复用 UI 原子提取到 `scripts/ui/components/`，跨面板共享
4. **数据驱动**：UI 只负责渲染，业务逻辑剥离到 `systems/` 或 `config/`
5. **渐进迁移**：新增令牌只允许追加，不改动已有令牌语义；一次只迁移一个面板系统

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
    ├── SkillCard.lua           -- 技能卡片（56px图标 + 纵向堆叠）
    └── ArtifactPassiveCard.lua -- 被动技能卡片（左蓝竖条变体）
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

## 4. 炼丹炉面板重构方案（待实施）

### 4.1 现状分析

**`AlchemyUI.lua`** — 1891 行，是当前最大的 UI 单文件。

#### 4.1.1 结构问题

| 问题 | 具体表现 |
|------|---------|
| **每种丹药硬编码** | 每章有独立的 `BuildChXContent()` 函数（5个章节 × 平均 80 行 = 400+ 行） |
| **每种丹药硬编码炼制函数** | `DoCraftTiger()`, `DoCraftSnake()`, `DoCraftDiamond()` 等约 15 个独立函数 |
| **状态散布** | `tigerPillCount_`, `snakePillCount_`, `diamondPillCount_`... 约 8 个模块级变量 |
| **UI 与逻辑混合** | 扣减灵韵、增加属性、修改存档全在 UI 回调中 |
| **重复代码模式** | 每种丹药的 UI 块完全相同的模式重复 15+ 次（标题→说明→进度→材料→按钮） |
| **无共享组件** | 不使用 PanelShell/ItemSlot/PriceTag/SectionCard 等已有组件 |

#### 4.1.2 每种丹药的固定模式（高度重复）

每种丹药的 UI 构建代码遵循完全一致的模式：

```
emoji + 丹药名（标题 Label）
└── 效果描述（灰色 Label）
└── 进度文字 "已炼制 X/Y"（状态 Label）
└── 材料检查文字（绿色/红色 Label）
└── 炼制按钮（Button, 条件色）
└── 分隔线（1px Panel）
```

### 4.2 重构方案

#### 4.2.1 总体架构

```
[重构后]

scripts/config/PillRecipes.lua      (约 80行)  -- 纯数据：所有丹药配方定义
scripts/systems/AlchemySystem.lua   (约 150行) -- 纯逻辑：扣减/增加/存档/校验
scripts/ui/AlchemyUI.lua            (约 200行) -- 纯渲染：数据驱动通用渲染器
```

#### 4.2.2 数据层：PillRecipes.lua

```lua
-- scripts/config/PillRecipes.lua
local PillRecipes = {}

-- 丹药类型枚举
PillRecipes.TYPE = {
    CONSUMABLE = "consumable",  -- 生成消耗品放入背包
    PERMANENT  = "permanent",   -- 永久加属性（限购）
    TOKEN_BOX  = "token_box",   -- 令牌合成盒
}

-- 完整配方表
PillRecipes.ALL = {
    -- ═══ Ch1 ═══
    {
        id = "qi_pill",
        name = "练气丹",
        icon = "💊",
        chapter = 1,
        type = "consumable",
        desc = "修炼必需品，消耗灵韵炼制",
        cost = { lingYun = 10 },
        output = { consumableId = "qi_pill", count = 1 },
        buttonColor = {60, 120, 80, 220},
    },
    {
        id = "tiger_bone",
        name = "虎骨丹",
        icon = "🦴",
        chapter = 1,
        type = "permanent",
        desc = "永久增加血量上限 +30",
        cost = { lingYun = 10, material = { id = "tiger_bone", count = 1 } },
        effect = { stat = "maxHp", value = 30 },
        maxBuy = 5,
        buttonColor = {120, 80, 60, 220},
    },
    -- ═══ Ch2 ═══
    {
        id = "zhuji_pill",
        name = "筑基丹",
        icon = "🔮",
        chapter = 2,
        type = "consumable",
        cost = { lingYun = 100 },
        output = { consumableId = "zhuji_pill", count = 1 },
    },
    {
        id = "snake_pill",
        name = "灵蛇丹",
        icon = "🐍",
        chapter = 2,
        type = "permanent",
        desc = "永久增加攻击力 +10",
        cost = { lingYun = 100, material = { id = "snake_fruit", count = 1 } },
        effect = { stat = "atk", value = 10 },
        maxBuy = 5,
    },
    -- ... 其余丹药同结构，约 15 条记录
}

-- 按 chapter 索引
PillRecipes.BY_CHAPTER = {}
for _, recipe in ipairs(PillRecipes.ALL) do
    local ch = recipe.chapter
    PillRecipes.BY_CHAPTER[ch] = PillRecipes.BY_CHAPTER[ch] or {}
    table.insert(PillRecipes.BY_CHAPTER[ch], recipe)
end

return PillRecipes
```

#### 4.2.3 逻辑层：AlchemySystem.lua

```lua
-- scripts/systems/AlchemySystem.lua
local AlchemySystem = {}
local PillRecipes = require("config.PillRecipes")
local GameState = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local SaveSession = require("systems.save.SaveSession")

--- 检查是否可炼制
---@param recipe table 配方记录
---@return boolean canCraft, string? reason
function AlchemySystem.CanCraft(recipe)
    local player = GameState.player
    if not player then return false, "无玩家数据" end

    -- 灵韵检查
    if recipe.cost.lingYun and player.lingYun < recipe.cost.lingYun then
        return false, "灵韵不足"
    end

    -- 材料检查
    if recipe.cost.material then
        local mat = recipe.cost.material
        if InventorySystem.CountConsumable(mat.id) < mat.count then
            return false, "材料不足"
        end
    end

    -- 限购检查
    if recipe.maxBuy then
        local count = AlchemySystem.GetCraftCount(recipe.id)
        if count >= recipe.maxBuy then
            return false, "已售罄"
        end
    end

    return true
end

--- 执行炼制（扣减材料 + 产出 + 存档）
---@param recipe table
---@return boolean success
function AlchemySystem.DoCraft(recipe)
    local canCraft, reason = AlchemySystem.CanCraft(recipe)
    if not canCraft then return false end

    local player = GameState.player

    -- 扣减灵韵
    player.lingYun = player.lingYun - (recipe.cost.lingYun or 0)

    -- 扣减材料
    if recipe.cost.material then
        InventorySystem.RemoveConsumable(recipe.cost.material.id, recipe.cost.material.count)
    end

    -- 产出处理
    if recipe.type == "consumable" then
        InventorySystem.AddConsumable(recipe.output.consumableId, recipe.output.count)
    elseif recipe.type == "permanent" then
        -- 永久属性加成
        local stat = recipe.effect.stat
        player[stat] = (player[stat] or 0) + recipe.effect.value
        -- 记录炼制次数
        player.pillCounts = player.pillCounts or {}
        player.pillCounts[recipe.id] = (player.pillCounts[recipe.id] or 0) + 1
    elseif recipe.type == "token_box" then
        -- 令牌合成
        InventorySystem.RemoveConsumable(recipe.cost.token.id, recipe.cost.token.count)
        InventorySystem.AddConsumable(recipe.output.consumableId, 1)
    end

    SaveSession.MarkDirty()
    return true
end

--- 获取某丹药已炼制次数
function AlchemySystem.GetCraftCount(pillId)
    local player = GameState.player
    if not player or not player.pillCounts then return 0 end
    return player.pillCounts[pillId] or 0
end

return AlchemySystem
```

#### 4.2.4 UI 层：AlchemyUI.lua（重构后）

```lua
-- scripts/ui/AlchemyUI.lua (重构后，约 200 行)
local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local PanelShell = require("ui.components.PanelShell")
local SectionCard = require("ui.components.SectionCard")
local PriceTag = require("ui.components.PriceTag")
local PillRecipes = require("config.PillRecipes")
local AlchemySystem = require("systems.AlchemySystem")
local GameState = require("core.GameState")

local AlchemyUI = {}
local shell_ = nil

--- 通用丹药行渲染器
---@param recipe table 配方数据
---@return table UI.Panel
local function BuildPillRow(recipe)
    local canCraft, reason = AlchemySystem.CanCraft(recipe)
    local player = GameState.player

    local children = {}

    -- 标题行 (icon + name)
    table.insert(children, UI.Label {
        text = (recipe.icon or "💊") .. " " .. recipe.name,
        fontSize = T.fontSize.sm, fontWeight = "bold",
        fontColor = T.color.nameHighlight,
    })

    -- 效果描述
    if recipe.desc then
        table.insert(children, UI.Label {
            text = recipe.desc,
            fontSize = T.fontSize.xs,
            fontColor = T.color.textSecondary,
        })
    end

    -- 限购进度
    if recipe.maxBuy then
        local count = AlchemySystem.GetCraftCount(recipe.id)
        table.insert(children, UI.Label {
            text = count >= recipe.maxBuy
                and ("已售罄（限炼 " .. recipe.maxBuy .. " 颗）")
                or ("已炼制 " .. count .. "/" .. recipe.maxBuy),
            fontSize = T.fontSize.xs,
            fontColor = count >= recipe.maxBuy and T.color.error or T.color.textMuted,
        })
    end

    -- 价格标签
    if recipe.cost.lingYun then
        table.insert(children, PriceTag.LingYin(recipe.cost.lingYun, player.lingYun))
    end

    -- 炼制按钮
    table.insert(children, UI.Button {
        text = canCraft and ("炼制" .. recipe.name) or (reason or "无法炼制"),
        width = "100%", height = T.size.dialogBtnH,
        fontSize = T.fontSize.sm,
        backgroundColor = canCraft
            and (recipe.buttonColor or {60, 120, 80, 220})
            or T.color.disabled,
        onClick = function()
            if AlchemySystem.DoCraft(recipe) then
                AlchemyUI.Refresh()
            end
        end,
    })

    return UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1, borderColor = T.color.border,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = children,
    }
end

--- 按当前章节构建内容
function AlchemyUI.Refresh()
    if not shell_ then return end
    shell_:ClearContent()

    local chapter = GameState.GetCurrentChapter()
    local recipes = PillRecipes.BY_CHAPTER[chapter] or {}

    for _, recipe in ipairs(recipes) do
        shell_:AddContent(BuildPillRow(recipe))
    end
end

function AlchemyUI.Show(parentOverlay)
    if not shell_ then
        shell_ = PanelShell.Create({
            title = "炼丹炉",
            portrait = UI.Label { text = "🔥", fontSize = T.fontSize.xl },
            onClose = function() AlchemyUI.Hide() end,
            parent = parentOverlay,
        })
    end
    AlchemyUI.Refresh()
    shell_:Show()
end

function AlchemyUI.Hide()
    if shell_ then shell_:Hide() end
end

return AlchemyUI
```

### 4.3 迁移路径

| 步骤 | 内容 | 风险 |
|------|------|------|
| M1 | 创建 `PillRecipes.lua`，从现有硬编码提取所有配方数据 | 低：纯数据，不影响运行 |
| M2 | 创建 `AlchemySystem.lua`，将炼制逻辑从 UI 回调中剥离 | 中：需确保存档字段兼容 |
| M3 | 新建精简版 `AlchemyUI.lua`（使用通用渲染器） | 中：需逐章节验证 UI 行为一致 |
| M4 | C2S 授权流程迁移（`SendBuyPill` → AlchemySystem） | 高：涉及网络协议 |
| M5 | 中洲阵营丹药特殊逻辑迁移 | 中：阵营系统耦合 |
| M6 | 删除旧文件，全面测试 | 低：此时已完全替换 |

### 4.4 存档兼容

**关键变更**：原来每种丹药用独立的模块级变量记录数量（如 `tigerPillCount_`），重构后统一存入 `player.pillCounts[pillId]`。

**兼容策略**：
```lua
-- 存档加载时的迁移逻辑（SaveMigrations 中执行一次）
if player.tigerPillCount then
    player.pillCounts = player.pillCounts or {}
    player.pillCounts["tiger_bone"] = player.tigerPillCount
    player.tigerPillCount = nil
end
-- 同理处理其他旧字段...
```

### 4.5 预期成效

| 指标 | 重构前 | 重构后 |
|------|--------|--------|
| 文件行数 | 1891行（单文件） | ~430行（3文件总计） |
| 添加新丹药 | 新增 ~80行代码 | 在 PillRecipes 加 1 条记录（~10行） |
| 硬编码颜色 | ~50处 | 0 |
| 复用共享组件 | 无 | PanelShell + PriceTag + SectionCard |
| 逻辑可测试 | 不可能（混在UI中） | AlchemySystem 可独立单元测试 |
| C2S 授权 | 散布在各 DoCraft 函数中 | 统一收口到 AlchemySystem.DoCraft |

---

## 5. 共享组件清单

| 组件 | 文件 | 用途 | 已使用面板 |
|------|------|------|-----------|
| `PanelShell` | components/PanelShell.lua | 标准面板骨架 | EquipShop, Character, Alchemy, BlackMerchant, Pet |
| `ItemSlot` | components/ItemSlot.lua | 56px品质格子 | EquipShop, BlackMerchant, Inventory |
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
├── spacing     (xs/sm/md/lg/xl/safeTop)
├── radius      (sm/md/lg)
├── color
│   ├── 面层级: panelBg → headerBg → surface → surfaceDeep → surfaceLight
│   ├── 文字:   textPrimary → textSecondary → textMuted
│   ├── 语义:   success / error / warning / info
│   ├── 品质:   qualityWhite ~ qualityRed
│   ├── 强调:   gold / goldDark / jade / jadeDark
│   ├── Tab:    tabActiveBg / tabInactiveBg / tabActiveText / tabInactiveText
│   ├── 功能:   closeBtn / disabled / subText / rowAlt / accentPassive
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

---

## 7. 审查要点与疑问清单

### 7.1 请审查方关注

1. **PillRecipes 数据结构**：`type` 枚举是否覆盖所有丹药变体？中洲阵营丹药（凝力丹等）需要额外字段（faction）吗？

2. **存档迁移**：原来约 8 个散布的 `xxxPillCount_` 变量 → 统一到 `player.pillCounts[id]`，SaveMigrations 中的迁移逻辑是否足够健壮？

3. **C2S 授权**：原 `SendBuyPill(pillId, callback)` 模式在重构后如何保持？是否应在 AlchemySystem 中统一封装 pending 状态管理？

4. **令牌盒逻辑**：令牌盒 recipe 的 `cost` 结构比普通丹药多一个 `token` 字段（消耗令牌），通用渲染器需要处理这种分支。

5. **章节可见性**：原代码通过 `GameState.GetCurrentChapter()` 控制显示哪些丹药。重构后 `PillRecipes.BY_CHAPTER[chapter]` 是否足够？还是需要更细粒度的解锁条件（如等级、前置丹药）？

6. **组件粒度**：`BuildPillRow` 作为内部函数 vs 提取为 `PillRow.lua` 共享组件——考虑到炼丹是唯一使用者，暂定内部函数是否合理？

### 7.2 已知限制

- 本轮重构聚焦 UI 层面板结构和视觉规范化，**未涉及游戏逻辑本身的 refactor**（如战斗系统、存档系统）
- `AlchemyUI` 的中洲阵营丹药部分（Ch101）逻辑较特殊（按阵营解锁），可能需要在 PillRecipes 中增加 `unlockCondition` 字段
- 组件未做性能优化（如虚拟化列表），当前丹药数量（<20）不需要

---

## 附录 A：文件修改清单（角色面板重构）

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

## 附录 B：文件修改清单（装备商人重构）

| 文件 | 操作 | 主要变更 |
|------|------|---------|
| `config/UITheme.lua` | 新建 | 完整设计令牌体系 |
| `ui/EquipShopUI.lua` | 重写 | 引入 PanelShell/ItemSlot/PriceTag，颜色全面令牌化 |
| `ui/components/PanelShell.lua` | 新建 | 标准面板骨架 |
| `ui/components/ItemSlot.lua` | 新建 | 56px品质格子 |
| `ui/components/PriceTag.lua` | 新建 | 价格标签 |

---

*文档生成时间：2026-06-08*
*撰写者：AI 开发助手*
*状态：角色面板+商人面板已完成，炼丹炉为待审方案*
