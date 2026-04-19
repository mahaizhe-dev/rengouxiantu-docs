-- ============================================================================
-- UI_SPEC.lua - UI 布局规范与适配准则
-- 本文件是项目 UI 开发规范，所有面板/弹窗/浮层的布局必须遵循此文件的规则。
-- ============================================================================

--[[

============================================================
一、面板三层结构（所有弹窗/面板通用）
============================================================

任何覆盖全屏的 UI 面板都必须遵循三层嵌套：

  Layer 1: Overlay（全屏遮罩层）
    - position = "absolute", top/left/right/bottom = 0
    - 负责半透明遮罩和点击关闭
    - justifyContent = "center", alignItems = "center"
    - 不设宽度约束

  Layer 2: Card（内容卡片层）
    - 承载实际内容
    - 宽度策略见下方第二节
    - 设置 backgroundColor、borderRadius、padding
    - 关闭按钮在此层的标题栏中

  Layer 3: Title Bar（标题栏）
    - flexDirection = "row"
    - justifyContent = "space-between"
    - 包含标题文字 + 关闭按钮
    - 宽度由 Card 层自动约束，无需单独设置

示例结构：
    UI.Panel {                                    -- Layer 1: Overlay
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {                            -- Layer 2: Card
                maxWidth = 500,                   -- 宽度约束
                alignSelf = "center",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.md,
                children = {
                    UI.Panel {                    -- Layer 3: Title Bar
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "面板标题" },
                            UI.Button { text = "✕", ... },
                        },
                    },
                    -- 面板内容...
                },
            },
        },
    }


============================================================
二、宽度约束策略
============================================================

核心原则：优先使用 maxWidth，慎用固定 width。

  场景 A: 固定宽度小面板（如角色信息、宠物面板）
    - 使用 width = T.size.smallPanelW（400px）
    - 面板内容宽度固定，不会随屏幕变化
    - 适用于：内容简单、不需要响应式的小面板

  场景 B: 响应式宽面板（如背包、商店）
    - 使用 maxWidth = <计算值>
    - 添加 alignSelf = "center" 居中
    - 宽屏下保持最大宽度，窄屏（手机）下自动收缩
    - maxWidth 计算方式：根据内容物理尺寸累加
      例：装备格(3列) + 背包格(6列) + 间距 + 内边距

  场景 C: 弹性等分面板（如装备对比 Tooltip）
    - 容器：maxWidth = 单卡宽 * 2 + gap, width = "100%"
    - 子卡片：flexGrow = 1, flexShrink = 1, flexBasis = 0
    - 子卡片：maxWidth = 单卡宽（限制最大尺寸）
    - 效果：宽屏下两卡各占最大宽度，窄屏下等比缩小

禁止规则：
  ❌ 不要在 ScrollView 内部对内容面板使用 width = "100%"
     → 会导致内容拉伸到全屏宽度
  ❌ 不要依赖百分比宽度做响应式
     → 百分比参考的是父容器，在 ScrollView 中不可预测
  ✅ 始终使用 maxWidth + 像素值


============================================================
三、关闭按钮规范
============================================================

规则：关闭按钮始终放在 Card 层的标题栏内，不放在 Overlay 层。

标准关闭按钮样式：
    UI.Button {
        text = "✕",
        width = T.size.closeButton,      -- 36
        height = T.size.closeButton,     -- 36
        fontSize = T.fontSize.md,        -- 16
        borderRadius = T.size.closeButton / 2,
        backgroundColor = {60, 60, 70, 200},
        onClick = function() Panel.Hide() end,
    }

禁止：
  ❌ 不要把关闭按钮放在 Overlay 层用 position = "absolute"
     → 会脱离面板内容，位置无法随面板适配
  ✅ 关闭按钮是标题栏的一部分，宽度由 Card 约束


============================================================
四、手机适配规范
============================================================

核心原则：所有 UI 必须同时兼容横屏（桌面）和竖屏（手机）。

4.1 弹性布局优先
    - 并列面板使用 flexGrow/flexShrink/flexBasis 等分
    - 不要使用固定 width 做并列，会在窄屏溢出
    - 添加 overflow = "hidden" 防止内容溢出容器

4.2 文本溢出保护
    - 长文本容器添加 overflow = "hidden"
    - 关键文本考虑缩小字号或换行

4.3 maxWidth 限制最大尺寸
    - 所有面板都应设置 maxWidth
    - 宽屏下保持合理宽度，不会无限拉伸
    - 窄屏下自动收缩到屏幕宽度

4.4 flexWrap 自动换行（可选）
    - 当并列内容在窄屏放不下时，考虑 flexWrap = "wrap"
    - 配合 justifyContent = "center" 居中对齐

示例 - 装备对比（两卡并列）：
    -- 容器
    UI.Panel {
        flexDirection = "row",
        gap = T.spacing.sm,
        maxWidth = T.size.tooltipWidth * 2 + T.spacing.sm,
        width = "100%",
        children = {
            -- 左卡
            UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
                maxWidth = T.size.tooltipWidth,
                overflow = "hidden",
                ...
            },
            -- 右卡
            UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
                maxWidth = T.size.tooltipWidth,
                overflow = "hidden",
                ...
            },
        },
    }


============================================================
五、设计令牌引用（UITheme.lua）
============================================================

所有 UI 数值必须引用 UITheme.lua 中的令牌，不要硬编码数字。

    间距：T.spacing.xs(4) / sm(8) / md(12) / lg(16) / xl(24)
    圆角：T.radius.sm(6) / md(10) / lg(14)
    字号：T.fontSize.xs(12) / sm(14) / md(16) / lg(18) / xl(22) / xxl(28)
    尺寸：T.size.slotSize(56) / closeButton(36) / smallPanelW(400)
          T.size.tooltipWidth(280) / npcPanelMaxW(500)
    颜色：T.color.panelBg / titleText / overlay


============================================================
六、检查清单（交付前自查）
============================================================

布局结构：
  [ ] 面板是否遵循 Overlay → Card → TitleBar 三层结构？
  [ ] 关闭按钮是否在 Card 层标题栏内？

宽度适配：
  [ ] Card 层是否使用 maxWidth（响应式）或 width（固定小面板）？
  [ ] 是否避免了在 ScrollView 内使用 width = "100%"？
  [ ] 并列面板是否使用 flexGrow/flexShrink 等分而非固定 width？

手机兼容：
  [ ] 面板在手机竖屏(~360px)下是否能正常显示？
  [ ] 内容是否有 overflow = "hidden" 防止溢出？
  [ ] 所有面板是否设置了 maxWidth？

设计令牌：
  [ ] 数值是否引用 T.spacing / T.radius / T.fontSize / T.size？
  [ ] 颜色是否引用 T.color 或与现有面板保持一致？

]]

return {
    VERSION = "1.0.0",
    DESCRIPTION = "UI Layout Specification - See comments above",
}
