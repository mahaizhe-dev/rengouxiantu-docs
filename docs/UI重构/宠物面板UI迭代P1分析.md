# 宠物面板 UI 迭代 P1 — 分析与执行方案

> **阶段**: P1（分析 + 规划）
> **范围**: `PetPanel.lua` + 4 个子模块 + `PetPanelForms.lua`
> **日期**: 2026-06-13

---

## 1. 当前状态总览

| 文件 | 行数 | 硬编码RGBA | 核心问题 |
|------|------|-----------|---------|
| `PetPanel.lua`（主文件） | 1395 | ~95 处 | 手工骨架、弹窗×4、技能色阶散落 |
| `PetPanelInfo.lua` | 151 | ~14 处 | 卡片背景、属性文字色 |
| `PetPanelBreakthrough.lua` | 171 | ~22 处 | 卡片背景、条件✅/❌色、按钮态 |
| `PetPanelSkills.lua` | 272 | ~28 处 | 固有/主动区背景、技能槽分隔线 |
| `PetPanelAppearance.lua` | 290 | ~30 处 | 外观卡片边框/底色按状态切换 |
| `PetPanelForms.lua` | ~180 | ~21 处 | 形态按钮色方案 |
| **合计** | **~2459** | **~210** | — |

---

## 2. 问题分类清单

### 2.1 结构层（HIGH）

| # | 问题 | 影响 |
|---|------|------|
| S1 | **未使用 PanelShell** — `PetPanel.Create()` 手工构建 overlay→card→header→scrollContent→tabBar，与其他面板风格不统一 | 骨架风格断裂，改版时无法批量生效 |
| S2 | **Tab 色全局常量硬编码** — `TAB_DEFS[].activeColor` 逐 Tab 自定义 RGBA，不走 `T.color.tabActiveBg` | Tab 不统一，主题切换无效 |
| S3 | **弹窗骨架重复** — `ShowLearnPopup` / `ShowSkillActionPopup` / `ShowSkillConfirm` / `ShowSkillRules` 各自构建 overlay+card+padding 模式，约 4 处重复 | 改一处改四次 |

### 2.2 视觉层（HIGH）

| # | 问题 | 典型硬编码 | 可替换 Token |
|---|------|-----------|-------------|
| V1 | 卡片/区域背景色 | `{35, 38, 50, 200}` / `{45, 30, 30, 200}` / `{40, 35, 50, 200}` | `T.color.surface` / `T.color.surfaceDeep` |
| V2 | 属性文字色 | `{200, 200, 200, 255}` | `T.color.textSecondary` |
| V3 | 弱化/禁用文字 | `{120, 120, 120, 200}` / `{150, 150, 150, 255}` | `T.color.textMuted` / `T.color.disabled` |
| V4 | 条件满足/不满足 | `{100, 200, 100, 255}` / `{255, 100, 100, 255}` | `T.color.success` / `T.color.error` |
| V5 | 按钮可用态 | `{60, 120, 180, 255}` / `{120, 80, 200, 255}` | `T.color.btnSpend` 系列 |
| V6 | 按钮禁用态 | `{50, 50, 60, 160}` + `{100,100,100,255}` | `T.color.btnDisabled` + `T.color.textMuted` |
| V7 | 关闭按钮背景 | `{60, 60, 70, 200}` | `T.color.closeBtn` |
| V8 | 遮罩背景 | `{0, 0, 0, 150}` / `{0, 0, 0, 160}` | `T.color.overlay` |
| V9 | HP条绿 / EXP条蓝 | `{80,200,80,255}` / `{100,180,255,255}` | 新增 `T.color.hpBar` / `T.color.expBar` |
| V10 | 技能阶色（tier 1-4） | 4组 borderColor + labelColor 散落2处 | 新增 `T.color.tierColors[]` |
| V11 | 外观卡片3态（已装备/已拥有/未拥有） | 3组 bg+border 共9个字面量 | 新增 `T.color.skinCard.equipped/owned/locked` |

### 2.3 规范层（MEDIUM）

| # | 问题 |
|---|------|
| N1 | Tab 切换无动画过渡 |
| N2 | 弹窗无统一入场/退场动效 |
| N3 | 属性区硬编码 emoji 作为图标无法主题化（但可接受） |
| N4 | Header 布局非标准（关闭按钮在左，右侧放宠物图标+名称），PanelShell 标准是左标题右关闭 |

---

## 3. PanelShell 迁移可行性分析

### 3.1 PanelShell 提供的能力

| 能力 | PanelShell 实现 | PetPanel 当前实现 |
|------|----------------|-----------------|
| Overlay 遮罩 + 点击关闭 | `T.color.overlay` + onClick | 手工 `{0,0,0,150}` + onClick |
| 金边圆角卡片 | `T.color.panelBg` + `T.color.goldDark` 1px border | 手工 `T.color.panelBg` + `T.radius.lg`，无金边 |
| Header（标题+关闭按钮） | portrait + title + subtitle + 关闭按钮(右) | 关闭按钮(左) + 图标+名称+阶级badge(右) |
| ScrollView 内容区 | `shell.contentPanel` + `shell:AddContent()` | tabContent_ 自己管理 |
| Footer 提示 | `"点击空白处关闭"` | 无 footer |
| Show/Hide 方法 | `shell:Show()` / `shell:Hide()` | 自写 Show/Hide |

### 3.2 迁移方案

**策略**: 不直接用 PanelShell（因 PetPanel Header 结构非标准——有图标+阶级badge+固定区HP/EXP+TabBar），而是**参照 PanelShell 的 Token 用法**对手工骨架做 Token 替换 + 金边补充。

**理由**:
1. PetPanel 的 Header 需要包含宠物图标、名称、阶级 Badge（PanelShell 仅支持 portrait + title + subtitle）
2. PetPanel 在 Header 和 Content 之间有「固定区域」（等级+HP+EXP+TabBar），不会随 tab 滚动
3. 强行适配 PanelShell 会导致要么丧失固定区域，要么大量 hack

**执行路径**: 
- 骨架保持手工，但把所有颜色/圆角/间距换为 UITheme Token
- 补充金边（`borderWidth = 1, borderColor = T.color.goldDark`）
- 弹窗骨架提取为 `PetPopupShell` 内部复用函数（非导出，仅 PetPanel 内使用）

### 3.3 需新增的 UITheme Token

```lua
-- PetPanel 专用（建议加到 UITheme.color 末尾）
hpBar         = {80, 200, 80, 255},     -- HP 进度条填充
hpBarBg       = {50, 20, 20, 220},      -- HP 进度条底色
expBar        = {100, 180, 255, 255},   -- EXP 进度条填充
expBarBg      = {30, 40, 60, 220},      -- EXP 进度条底色

-- 技能阶色 (skill tier visual)
tierBorder    = { {100,100,130,120}, {100,200,100,180}, {255,180,60,200}, {255,50,50,200} },
tierText      = { {200,200,200,200}, {100,255,100,255}, {255,200,80,255}, {255,80,80,255} },

-- 外观卡片三态
skinEquippedBg     = {40, 32, 15, 240},
skinEquippedBorder = {220, 170, 50, 220},
skinOwnedBg        = {28, 28, 45, 220},
skinOwnedBorder    = {100, 110, 180, 120},
skinLockedBg       = {35, 35, 35, 160},
skinLockedBorder   = {60, 60, 60, 80},
```

---

## 4. 执行计划（P2 阶段）

### 步骤 1: UITheme 扩展（~15 处新增）
- 新增上述 Token 到 `UITheme.lua`
- 确保不破坏已有引用

### 步骤 2: PetPanel.lua 主文件 Token 化
1. **骨架区域**（Create 函数）:
   - Overlay: `{0,0,0,150}` → `T.color.overlay`
   - Card: 补 `borderWidth=1, borderColor=T.color.goldDark`
   - Header 关闭按钮: → `T.color.closeBtn`
   - 阶级badge: → `T.color.qualityPurple` 系
   - 等级文字: → `T.color.textSecondary`
   - HP条: → `T.color.hpBar` / `T.color.hpBarBg`
   - EXP条: → `T.color.expBar` / `T.color.expBarBg`
2. **Tab 栏**: 移除 TAB_DEFS 各自 activeColor，统一 → `T.color.tabActiveBg` / `T.color.tabInactiveBg`
3. **弹窗骨架**: 提取 `local function createPopupOverlay(children, cfg)` 复用 overlay+card 模式

### 步骤 3: 子模块 Token 化
按文件逐一替换:
1. `PetPanelInfo.lua` — 卡片bg→`T.color.surface`，属性文字→`T.color.textSecondary`，食物按钮bg→`T.color.surfaceLight`
2. `PetPanelBreakthrough.lua` — 卡片bg→`T.color.surface`，条件色→`T.color.success/error`，突破按钮→`T.color.btnSpend`
3. `PetPanelSkills.lua` — 固有技能区bg→专色或`T.color.surfaceDeep`，阶色→`T.color.tierBorder[tier]`
4. `PetPanelAppearance.lua` — 三态卡片→`T.color.skinXxx` 系列
5. `PetPanelForms.lua` — 形态按钮色保持（已有结构化常量，可选迁移）

### 步骤 4: 验证
- 逐文件 Build + 截图对比
- 确认公共 API 签名不变（Create/Show/Hide/Toggle/IsVisible/Refresh/Update）
- 确认存档字段不受影响

---

## 5. 风险评估

| 风险 | 级别 | 缓解措施 |
|------|------|---------|
| Token 替换后色差肉眼可见 | 低 | Token 值与原硬编码值相近（差值 <10），可微调 |
| Tab 统一色后辨识度下降 | 中 | 保留当前 4 色方案作为 `T.color.petTab[key]` 可选扩展 |
| 弹窗提取后行为回归 | 低 | 功能不变，仅提取视觉骨架 |
| PetPanelForms 强迁移 | 低 | 该模块已有结构化常量（FORM_COLORS），P2 可跳过或仅做别名 |

---

## 6. 决策待确认

| # | 决策点 | 选项 A | 选项 B | 建议 |
|---|--------|--------|--------|------|
| D1 | Tab 颜色是否统一 | 统一为 `tabActiveBg` | 保留4色但迁入 UITheme | **B** — 4色是设计意图(属性蓝/突破紫/技能绿/外观橙)，移入 `T.color.petTab.info/breakthrough/skills/appearance` |
| D2 | Header 布局是否改为标准 | 左标题右关闭（PanelShell 标准） | 保持当前（左关闭右图标名称） | **A** — 统一体验，关闭按钮右上角 |
| D3 | 是否在 P2 引入动画 | 加 fade/slide | 纯色替换不加动画 | **B** — P2 只做 Token 化，动画留 P3 |
| D4 | 弹窗是否用 PanelShell | 弹窗改用 PanelShell | 弹窗仅提取内部函数 | **B** — 弹窗含大量自定义布局，内部函数更灵活 |

---

## 7. 总结

P1 分析结论：
1. **不采用 PanelShell 整体迁移**（结构差异过大），而是参照其 Token 用法做「Token 化 + 金边补充」
2. **预计 210 处硬编码 → 全部替换为 UITheme Token**（其中约 15 个需新增 Token）
3. **执行顺序**: UITheme 扩展 → 主文件骨架 → 子模块逐一 → 验证
4. **公共 API 零变更**，纯视觉层改动
5. **预计 P2 工作量**: 6 个文件，单文件 10-30 分钟替换+验证

等待用户确认 D1-D4 决策点后启动 P2 执行。
