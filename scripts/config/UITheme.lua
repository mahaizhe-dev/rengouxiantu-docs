-- ============================================================================
-- UITheme.lua - UI 设计令牌（Design Tokens）
-- 统一管理所有 UI 尺寸、字号、间距、圆角等数值
-- ============================================================================

local UITheme = {}

-- ── 字号阶梯 ──
UITheme.fontSize = {
    xs   = 12,   -- 辅助说明（等级百分比、副属性）
    sm   = 14,   -- 正文、标签、条内文字
    md   = 16,   -- 按钮文字、次要标题
    lg   = 18,   -- 主要标题、NPC 名称、面板标题
    xl   = 22,   -- 强调文字、技能图标
    xxl  = 28,   -- 大标题（死亡屏幕等）
    hero = 36,   -- 超大标题
}

-- ── 间距阶梯 ──
UITheme.spacing = {
    xs = 4,
    sm = 8,
    md = 12,
    lg = 16,
    xl = 24,
    safeTop = 32,  -- 移动端顶部安全区（避开系统按钮）
}

-- ── 圆角阶梯 ──
UITheme.radius = {
    sm = 6,    -- 进度条、小标签
    md = 10,   -- 按钮、卡片、格子
    lg = 14,   -- 对话框、面板
}

-- ── 统一颜色 ──
UITheme.color = {
    panelBg    = {25, 28, 38, 245},    -- 面板内容卡片背景
    titleText  = {255, 220, 150, 255}, -- 面板标题文字（金色）
    overlay    = {0, 0, 0, 120},       -- 面板半透明遮罩
}

-- ── 组件标准尺寸 ──
UITheme.size = {
    -- 按钮/图标
    skillButton    = 56,   -- 技能按钮
    toolButton     = 48,   -- 底栏工具按钮（宠物/突破/背包）
    closeButton    = 36,   -- 关闭按钮

    -- 格子
    slotSize       = 56,   -- 物品/装备格子

    -- 进度条
    hpBarHeight    = 22,   -- HP 条高度
    expBarHeight   = 18,   -- EXP 条高度
    petHpBarHeight = 16,   -- 宠物 HP 条高度
    monsterBarH    = 5,    -- 怪物血条高度

    -- 容器
    smallPanelW    = 400,  -- 侧栏小面板统一宽度
    npcPanelMaxW   = 500,  -- NPC/功能面板最大宽度
    bottomBarMaxW  = 560,  -- 底部栏最大宽度
    dialogBtnH     = 44,   -- 对话框按钮高度
    tooltipWidth   = 280,  -- 装备详情弹出宽度

    -- 标签宽度
    levelLabelW    = 120,  -- 等级标签宽度（容纳"练气初期 Lv.XX"）
    resInfoW       = 86,   -- 底栏左侧资源信息面板宽度
}

-- ── NanoVG 世界渲染字号 ──
UITheme.worldFont = {
    name       = 16,   -- 怪物/NPC 名字（普通）
    nameBoss   = 20,   -- BOSS/王级 名字（加大）
    namePlayer = 18,   -- 玩家名字
    subtitle   = 12,   -- NPC 职能副标题
    level      = 12,   -- 等级标签
    label      = 12,   -- 装饰物标签/告示牌
    damage     = 18,   -- 浮动伤害数字基准
    dropLabel  = 14,   -- 掉落物标签
    realmBadge = 12,   -- 境界铭牌字号
    realmBadgeMon = 10, -- 怪物境界铭牌字号
}

-- ── 怪物等级徽章 ──
UITheme.monsterLvRadius = 11

return UITheme
