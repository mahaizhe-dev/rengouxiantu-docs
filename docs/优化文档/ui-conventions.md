# UI 编码规范

本文档记录项目中 UI 组件的标准实现模式，避免重复踩坑。

---

## Tab 页签组件

**标准做法**（参考 `CharacterUI.lua`、`LeaderboardUI.lua`、`SystemMenu.lua` 图鉴）

### 核心原则

1. **用 `tabBtns_[]` 数组**存储按钮引用，用数字索引，循环更新样式
2. **用 `SetStyle()` 更新样式**，不要调用 `SetBackgroundColor()` / `SetFontColor()` 等不存在的方法
3. **统一颜色常量**，全项目保持一致

### 颜色常量（统一值）

```lua
local TAB_ACTIVE_BG     = {70, 80, 120, 255}
local TAB_INACTIVE_BG   = {40, 45, 60, 200}
local TAB_ACTIVE_COLOR  = {240, 240, 255, 255}
local TAB_INACTIVE_COLOR = {140, 140, 160, 200}
```

### 标准模板

```lua
-- ── 模块级状态 ──
local activeTab_ = 1
local tabBtns_ = {}

-- ── 更新样式（循环数组） ──
local function UpdateTabStyles()
    for i, btn in ipairs(tabBtns_) do
        btn:SetStyle({
            backgroundColor = i == activeTab_ and TAB_ACTIVE_BG or TAB_INACTIVE_BG,
            fontColor = i == activeTab_ and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR,
        })
    end
end

-- ── 切换 Tab ──
local function SwitchTab(tabIndex)
    if activeTab_ == tabIndex then return end
    activeTab_ = tabIndex
    UpdateTabStyles()
    RefreshContent()  -- 刷新内容区域
end

-- ── 构建 Tab 按钮（在 Create 中） ──
local TAB_NAMES = { "标签A", "标签B", "标签C" }
tabBtns_ = {}
local tabChildren = {}
for i, name in ipairs(TAB_NAMES) do
    local isActive = (i == activeTab_)
    local btn = UI.Button {
        text = name,
        flexGrow = 1,
        height = 30,
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        borderRadius = T.radius.sm,
        backgroundColor = isActive and TAB_ACTIVE_BG or TAB_INACTIVE_BG,
        fontColor = isActive and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR,
        onClick = function() SwitchTab(i) end,
    }
    tabBtns_[i] = btn
    table.insert(tabChildren, btn)
end

-- Tab 栏容器
local tabBar = UI.Panel {
    flexDirection = "row",
    gap = T.spacing.xs,
    children = tabChildren,
}
```

### 内容区域两种模式

| 模式 | 适用场景 | 做法 |
|------|---------|------|
| **ClearChildren + 重建** | 内容轻量、构建快 | 单容器 `tabContent_`，切 Tab 时 `ClearChildren()` 后填充新内容 |
| **Show/Hide 切换** | 内容重（异步加载、保留滚动位置） | 两个容器 `contentA_` / `contentB_`，通过 `Show()` / `Hide()` 切换 |

### 禁止事项

```
-- UI.Button 没有以下方法：
btn:SetBackgroundColor(...)   -- 不存在
btn:SetFontColor(...)         -- 不存在
btn:SetText(...)              -- 不存在

-- 正确做法：统一用 SetStyle
btn:SetStyle({ backgroundColor = ..., fontColor = ... })
```

### 销毁时清理

```lua
function Module.Destroy()
    tabBtns_ = {}
    -- ... 其他清理
end
```

---

## Create 守卫与 Destroy 生命周期

**核心原则**：使用 `if panel_ then return` 守卫防止重复创建的模块，**必须**提供配套的 `Destroy()` 函数，并在 `main.lua` 的 `ReturnToLogin()` 中调用。

### 问题根因

切换账号时 `ReturnToLogin()` 销毁 overlay（所有子 widget 随之销毁），但模块级变量（`panel_`、`visible_` 等）仍持有已销毁 widget 的引用。下次调用 `Create()` 时守卫 `if panel_ then return` 判定为已创建，直接跳过，导致第二个账号无法打开该面板。

### 必须遵守的规则

1. **有 `if panel_ then return` 守卫 → 必须有 `Destroy()`**
2. **`Destroy()` 必须重置所有模块级状态**（`panel_ = nil`、`visible_ = false`、清空引用数组等）
3. **`ReturnToLogin()` 必须调用该模块的 `Destroy()`**

### 标准模板

```lua
-- ── 模块级状态 ──
local panel_ = nil
local visible_ = false
local contentArea_ = nil

--- 创建面板（守卫：仅创建一次）
function Module.Create(parentOverlay)
    if panel_ then return end   -- ← 守卫
    -- ... 创建 UI ...
    parentOverlay:AddChild(panel_)
end

--- 销毁面板（切换角色时调用，重置所有模块级状态）
function Module.Destroy()       -- ← 配套 Destroy
    panel_ = nil
    visible_ = false
    contentArea_ = nil
    -- 重置所有其他模块级引用和状态变量
end
```

### 自查清单（新增 UI 模块时）

- [ ] 是否使用了 `if panel_ then return` 守卫？
- [ ] 如果是，是否提供了 `Destroy()` 函数？
- [ ] `Destroy()` 是否重置了**所有**模块级变量（panel_、visible_、数组、计时器等）？
- [ ] `main.lua` 的 `ReturnToLogin()` 是否调用了该 `Destroy()`？

### 历史教训

| 模块 | 问题 | 后果 |
|------|------|------|
| AtlasUI | 有守卫无 Destroy | 第一个账号打开后，第二个账号无法打开 |

---

## 通用规则

### Widget 属性更新

- **`SetStyle(table)`** — 批量更新多个样式属性（backgroundColor, fontColor, fontSize 等）
- **`SetVisible(bool)`** 或 **`Show()` / `Hide()`** — 控制显隐
- **`SetText(string)`** — 仅 `UI.Label` 支持，`UI.Button` 需用 `SetStyle`
- **`ClearChildren()`** — 清空子元素
- **`AddChild(widget)`** — 添加子元素
- **`Destroy()`** / **`Remove()`** — 销毁组件

---

*最后更新: 2026-03-27*
