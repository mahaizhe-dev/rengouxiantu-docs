-- ============================================================================
-- UITheme.lua - UI 设计令牌（Design Tokens）
-- 统一管理所有 UI 尺寸、字号、间距、圆角等数值
-- ============================================================================

local UITheme = {}

-- ── 字号阶梯 ──
UITheme.fontSize = {
    xxs  = 10,   -- 微标签（badge、角标）
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
    xxs = 2,   -- 极紧凑间距（名称与描述行间、badge 内边距）
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
    -- 通用
    transparent = {0, 0, 0, 0},          -- 透明（无色边框/背景占位）

    -- 基础（已有，保留）
    panelBg    = {25, 28, 38, 245},    -- 面板内容卡片背景
    titleText  = {255, 220, 150, 255}, -- 面板标题文字（金色）
    overlay    = {0, 0, 0, 120},       -- 面板半透明遮罩

    -- ▼ 新增：面层级 ──────────────────────────────
    surface       = {35, 40, 55, 255},    -- 卡片/行背景
    surfaceDeep   = {25, 28, 40, 230},    -- 技能条/内嵌条目底色（比 surface 更暗）
    surfaceLight  = {50, 56, 75, 255},    -- 行 hover / 次级区域
    headerBg      = {18, 20, 30, 255},    -- 面板 header 深底
    border        = {60, 65, 90, 200},    -- 默认边框
    borderLight   = {80, 85, 110, 120},   -- 淡分隔线

    -- ▼ 新增：文字层级 ────────────────────────────
    textPrimary   = {240, 240, 240, 255}, -- 主文字（白）
    textSecondary = {170, 175, 195, 255}, -- 辅助文字（灰蓝）
    textMuted     = {120, 125, 145, 255}, -- 弱化文字

    -- ▼ 新增：语义色 ─────────────────────────────
    success    = {100, 220, 120, 255},    -- 购买成功 / 正向
    error      = {255, 100, 100, 255},    -- 不足 / 失败
    warning    = {255, 200, 80, 255},     -- 金币 / 警告
    info       = {120, 180, 255, 255},    -- 灵韵 / 信息

    -- ▼ 新增：品质色 ─────────────────────────────
    qualityWhite  = {200, 200, 200, 255},
    qualityGreen  = {80, 210, 120, 255},
    qualityBlue   = {90, 170, 255, 255},
    qualityPurple = {180, 130, 255, 255},
    qualityOrange = {255, 165, 80, 255},
    qualityRed    = {255, 80, 90, 255},

    -- ▼ 新增：强调色 ─────────────────────────────
    gold          = {255, 220, 150, 255}, -- 金色（=titleText，语义别名）
    goldDark      = {200, 160, 80, 255},  -- 暗金（渐变终点）
    jade          = {80, 180, 130, 255},  -- 翡翠（正面状态）
    jadeDark      = {50, 130, 90, 255},   -- 暗翠（渐变终点）

    -- ▼ 新增：Tab 栏色 ────────────────────────────
    tabActiveBg     = {70, 80, 120, 255},
    tabInactiveBg   = {40, 45, 60, 200},
    tabActiveText   = {240, 240, 255, 255},
    tabInactiveText = {140, 140, 160, 200},

    -- ▼ tip 面板色 ──────────────────────────
    tipBg           = {40, 40, 50, 220},   -- tip 展开区域通用底色
    tipText         = {200, 210, 225, 220}, -- tip 文字通用色

    -- ▼ 新增：功能色 ─────────────────────────────
    closeBtn        = {60, 60, 70, 200},   -- 关闭按钮背景
    disabled        = {120, 120, 120, 200}, -- 禁用/未解锁
    subText         = {180, 180, 200, 200}, -- 小节分隔文字
    rowAlt          = {45, 50, 68, 180},   -- 属性行交替底色（偶数行）
    accentPassive   = {120, 180, 255, 180}, -- 被动技能左竖条（蓝色系）

    -- ▼ 新增：角色面板专用 ────────────────────────
    nameHighlight   = {255, 255, 200, 255}, -- 解锁技能/丹药名称高亮（暖白）
    goldSoft        = {255, 225, 140, 220}, -- 金丹/解锁值（柔金）
    goldBgSubtle    = {255, 200, 80, 60},   -- 金丹解锁底色（微透明金）
    highlightMe     = {60, 55, 30, 200},   -- "我的行"高亮底色（暖金深底，排行榜/列表通用）
    rankSilver      = {200, 200, 210, 255}, -- 排名银色（#2）
    rankBronze      = {205, 127, 50, 255},  -- 排名铜色（#3）
    rankTop3Bg      = {255, 255, 255, 25},  -- 排名前3行微白底
    bonusActive     = {180, 230, 80, 255},  -- 区域加成激活（黄绿）

    -- ▼ 神器卡片背景 ──────────────────────────────
    artifactBgGold   = {50, 45, 20, 230},   -- 神器被动卡片（金系）
    artifactBgPurple = {35, 20, 55, 230},   -- 神器被动卡片（紫系）
    artifactBgBlue   = {20, 35, 55, 230},   -- 神器被动卡片（蓝系）
    infoLight        = {180, 220, 255, 255}, -- 已解锁/已修复状态（亮冰蓝）

    -- ▼ 按钮色 — 5 类语义 ─────────────────────────────
    btnSpend         = {180, 140, 50, 255},  -- 琥珀金（花钱：购买/炼制/解锁/突破）
    btnSpendFg       = {255, 245, 220, 255}, -- 暖白
    btnDanger        = {200, 60, 60, 255},   -- 朱砂红（战斗/危险/不可逆）
    btnDangerFg      = {255, 230, 230, 255}, -- 浅粉白
    btnSuccess       = {45, 140, 80, 255},   -- 翠绿（正向确认/激活/收益）
    btnSuccessFg     = {220, 255, 230, 255}, -- 浅绿白
    btnSecondary     = {70, 70, 80, 220},    -- 中灰（次要/取消/帮助）
    btnSecondaryFg   = {200, 200, 210, 255}, -- 亮灰
    btnDisabled      = {50, 50, 55, 255},    -- 深灰（禁用态）
    btnDisabledFg    = {120, 115, 110, 255}, -- 暗灰

    -- ── 向后兼容别名（迁移期保留，全量迁移后可移除） ──
    btnPrimary       = {45, 100, 200, 255},  -- [废弃]
    btnPrimaryFg     = {255, 255, 255, 255}, -- [废弃]
    btnAlchemy       = {180, 130, 50, 255},  -- [别名→btnSpend]
    btnAlchemyFg     = {255, 245, 220, 255}, -- [别名→btnSpendFg]

    -- ▼ 宠物面板专用 ─────────────────────────────────
    -- Tab 4色方案
    petTabInfo          = {80, 100, 140, 255},   -- 属性·喂食 tab
    petTabBreakthrough  = {120, 80, 180, 255},   -- 突破 tab
    petTabSkills        = {60, 140, 120, 255},   -- 技能 tab
    petTabAppearance    = {180, 120, 60, 255},   -- 外观 tab

    -- HP/EXP 条
    petHpBarBg          = {50, 20, 20, 220},     -- HP 条底色（暗红）
    petHpBarFill        = {80, 200, 80, 255},    -- HP 条填充（绿）
    petExpBarBg         = {30, 40, 60, 220},     -- EXP 条底色（暗蓝）
    petExpBarFill       = {100, 180, 255, 255},  -- EXP 条填充（亮蓝）

    -- 阶级徽章
    petTierBadgeBg      = {80, 60, 140, 160},    -- 阶级 badge 底
    petTierBadgeFg      = {180, 160, 255, 230},  -- 阶级 badge 文字

    -- 固有技能区
    petSkillInnateBg      = {45, 30, 30, 200},   -- 固有技能卡背景（暗红底）
    petSkillInnateBorder  = {200, 80, 80, 80},   -- 固有技能边框
    petSkillInnateTitle   = {255, 120, 120, 255},-- 固有技能标题
    petSkillInnateRowBg   = {35, 25, 25, 220},   -- 固有技能行背景

    -- 主动技能区
    petSkillActiveBg      = {30, 30, 50, 200},   -- 主动技能卡背景（解锁态）
    petSkillActiveBorder  = {140, 100, 255, 100},-- 主动技能边框（解锁态）
    petSkillActiveTitle   = {180, 140, 255, 255},-- 主动技能标题
    petSkillActiveRowBg   = {25, 20, 40, 220},   -- 主动技能行背景
    petSkillLockedBg      = {40, 40, 40, 150},   -- 主动技能未解锁底
    petSkillLockedBorder  = {80, 80, 80, 60},    -- 主动技能未解锁边框

    -- 突破下阶预览卡
    petBreakthroughBg     = {40, 35, 50, 200},   -- 突破预览卡底
    petBreakthroughBorder = {120, 90, 200, 100}, -- 突破预览卡边框
    petBreakthroughTitle  = {180, 160, 255, 255},-- 突破预览标题
    petBreakthroughGain   = {150, 255, 180, 255},-- 突破增益文字（绿）

    -- 皮肤卡片三态
    petSkinEquippedBg     = {40, 32, 15, 240},   -- 装备中卡底（暗金）
    petSkinEquippedBorder = {220, 170, 50, 220}, -- 装备中卡边框（金）
    petSkinOwnedBg        = {28, 28, 45, 220},   -- 已拥有卡底（暗蓝）
    petSkinOwnedBorder    = {100, 110, 180, 120},-- 已拥有卡边框
    petSkinLockedBg       = {35, 35, 35, 160},   -- 未解锁卡底（灰）
    petSkinLockedBorder   = {60, 60, 60, 80},    -- 未解锁卡边框
    petSkinPreviewBg      = {20, 18, 30, 255},   -- 贴图预览底
    petSkinEquipBtn       = {50, 120, 200, 255}, -- 装备按钮底

    -- 形态卡片区
    petFormContainerBg     = {35, 35, 45, 200},  -- 形态容器底
    petFormContainerBorder = {100, 80, 60, 80},  -- 形态容器边框
    petFormTitleColor      = {255, 200, 100, 255},-- 形态标题（金）
    petFormActiveGlow      = {255, 200, 80, 255},-- 激活态辉光边框
    petFormCdColor         = {200, 150, 80, 255},-- CD 文字色
    petFormLockedColor     = {100, 100, 100, 150},-- 未解锁形态文字

    -- 形态增强行（暖色=攻击/怒/通用，冷色=防御/守护）
    petEnhanceWarmBg       = {60, 45, 20, 180},  -- 暖色增强底
    petEnhanceWarmBorder   = {200, 160, 60, 100},-- 暖色增强边框
    petEnhanceWarmText     = {255, 200, 80, 255},-- 暖色增强文字
    petEnhanceCoolBg       = {20, 50, 60, 180},  -- 冷色增强底
    petEnhanceCoolBorder   = {80, 180, 200, 100},-- 冷色增强边框
    petEnhanceCoolText     = {100, 220, 200, 255},-- 冷色增强文字

    -- ▼ 技能弹窗 ─────────────────────────────────
    -- 弹窗外壳
    popupOverlay         = {0, 0, 0, 160},       -- 弹窗遮罩
    popupBg              = {30, 33, 45, 250},    -- 弹窗卡底
    popupBorder          = {100, 180, 160, 120}, -- 弹窗卡边框（青系）
    popupBorderBlue      = {100, 150, 200, 120}, -- 弹窗卡边框（蓝系）
    popupBorderInfo      = {100, 160, 220, 120}, -- 弹窗卡边框（信息色）
    -- 技能格
    petSlotEmptyBg       = {40, 43, 55, 200},    -- 空格底
    petSlotEmptyBorder   = {70, 70, 90, 100},    -- 空格边框
    petSlotEmptyIcon     = {100, 100, 120, 180}, -- 空格"+"文字
    petSlotFilledBg      = {45, 48, 60, 230},    -- 已装备格底
    -- 技能阶边框色
    petSkillTierBorder1  = {100, 100, 130, 120}, -- 初级
    petSkillTierBorder2  = {100, 200, 100, 180}, -- 中级
    petSkillTierBorder3  = {255, 180, 60, 200},  -- 高级
    petSkillTierBorder4  = {255, 50, 50, 200},   -- 特级
    -- 技能阶标文字色
    petSkillTierLabel1   = {200, 200, 200, 200}, -- 初级
    petSkillTierLabel2   = {100, 255, 100, 255}, -- 中级
    petSkillTierLabel3   = {255, 200, 80, 255},  -- 高级
    petSkillTierLabel4   = {255, 80, 80, 255},   -- 特级
    -- 学习弹窗
    petLearnItemBg       = {40, 45, 60, 220},    -- 技能书列表项底
    petLearnItemSelected = {60, 90, 130, 255},   -- 选中态底
    petLearnItemSelBorder= {100, 180, 255, 200}, -- 选中态边框
    -- 升级路径卡
    petUpgradePathABg    = {50, 80, 120, 255},   -- 路径A激活底
    petUpgradePathABorder= {80, 140, 200, 150},  -- 路径A激活边框
    petUpgradePathBBg    = {60, 45, 100, 255},   -- 路径B激活底
    petUpgradePathBBorder= {140, 100, 220, 150}, -- 路径B激活边框
    petUpgradeDisabledBg = {40, 42, 55, 255},    -- 路径禁用底
    petUpgradeDisabledBd = {60, 60, 70, 100},    -- 路径禁用边框
    petRateNormal        = {255, 180, 80, 255},  -- 普通成功率色
    petRateHigh          = {100, 230, 100, 255}, -- 高成功率色
    -- 弹窗动作按钮
    petBtnUpgradeA       = {60, 120, 180, 255},  -- 普通升级按钮
    petBtnUpgradeB       = {120, 80, 200, 255},  -- 深度学习按钮
    petDeleteBtnBg       = {80, 40, 40, 120},    -- 删除按钮底
    petDeleteBtnFg       = {180, 120, 120, 200}, -- 删除按钮文字
    petDeleteConfirmBg   = {200, 40, 40, 255},   -- 删除确认态底
    -- 弹窗确认/取消
    petConfirmBg         = {60, 160, 120, 255},  -- 确认按钮底
    petCancelBg          = {80, 80, 90, 220},    -- 取消按钮底
    petCancelFg          = {180, 180, 180, 255}, -- 取消按钮文字
    -- 信息头
    petInfoHeadBg        = {35, 38, 50, 220},    -- 技能信息头底
    -- 名称色（按阶级）
    petNameTier1         = {200, 200, 200, 255}, -- 初级技能名
    petNameTier2         = {100, 200, 100, 255}, -- 中级技能名
    petNameTier3         = {255, 200, 80, 255},  -- 高级技能名
    petNameTier4         = {255, 80, 80, 255},   -- 特级技能名
    -- 规则弹窗
    petRulesTitle        = {140, 200, 255, 255}, -- 规则标题色
    petRulesText         = {210, 215, 225, 255}, -- 规则正文色
    petRulesBtn          = {60, 120, 180, 255},  -- "知道了"按钮底
    -- 满级文字
    petMaxTierText       = {255, 215, 100, 230}, -- "已满级"文字
    -- 材料检查色（复用语义色）
    petMaterialOk        = {100, 200, 100, 255}, -- 材料充足（绿）
    petMaterialLack      = {255, 100, 100, 255}, -- 材料不足（红）
    -- 描述性文字
    petDescText          = {170, 170, 180, 255}, -- 描述/消耗文字
    petUpgradeHintText   = {150, 180, 220, 200}, -- 升级后提示文字
    -- 属性面板（PetPanelInfo）
    petStatHpRegen       = {150, 255, 200, 255}, -- 生命回复（绿色）
    petStatEvade         = {180, 220, 255, 255}, -- 闪避率（蓝色）
    petStatCrit          = {255, 220, 100, 255}, -- 暴击率（金色）
    petStatSync          = {150, 130, 255, 255}, -- 同步率（紫色）
    petStatSyncHint      = {130, 120, 170, 200}, -- 同步率说明
    petFoodBtnBg         = {50, 55, 70, 220},    -- 食物按钮底色
    -- 突破面板（PetPanelBreakthrough）
    petBreakNextBg       = {40, 35, 50, 200},    -- "突破后"卡底（紫调）
    petBreakNextBorder   = {120, 90, 200, 100},  -- "突破后"卡边框
    petBreakNextTitle    = {180, 160, 255, 255}, -- "突破后"标题（亮紫）
    petBreakSyncUp       = {150, 255, 180, 255}, -- 同步率提升数值（绿）
    petBreakBtnActive    = {160, 100, 30, 255},  -- 突破按钮可用（金橙）
    petBreakBtnDisabled  = {60, 60, 70, 180},    -- 突破按钮禁用底
    petBreakBtnDisFg     = {140, 140, 140, 255}, -- 突破按钮禁用文字
    petBreakMaxBg        = {60, 60, 70, 120},    -- 已满阶按钮底
    petBreakMaxFg        = {100, 100, 100, 255}, -- 已满阶按钮文字
    -- 技能面板（PetPanelSkills）
    petInnateBg          = {45, 30, 30, 200},    -- 固有技能区底色（暗红）
    petInnateBorder      = {200, 80, 80, 80},    -- 固有技能区边框
    petInnateTitle       = {255, 120, 120, 255}, -- 固有技能标题
    petInnateCardBg      = {35, 25, 25, 220},    -- 固有技能卡底
    petInnateName        = {255, 100, 100, 255}, -- 固有技能名称
    petInnateDesc        = {200, 180, 180, 200}, -- 固有技能描述
    petInnateExtra       = {255, 180, 100, 200}, -- 固有技能额外数值
    petActiveUnlockBg    = {30, 30, 50, 200},    -- 主动技能解锁底
    petActiveLockedBg    = {40, 40, 40, 150},    -- 主动技能未解锁底
    petActiveUnlockBd    = {140, 100, 255, 100}, -- 主动技能解锁边框
    petActiveLockedBd    = {80, 80, 80, 60},     -- 主动技能未解锁边框
    petActiveTitle       = {180, 140, 255, 255}, -- 主动技能标题（解锁）
    petActiveCardBg      = {25, 20, 40, 220},    -- 主动技能卡底（解锁）
    petActiveLockedCard  = {30, 30, 30, 150},    -- 主动技能卡底（未解锁）
    petActiveName        = {200, 160, 255, 255}, -- 主动技能名称（解锁）
    petActiveDesc        = {180, 170, 200, 200}, -- 主动技能描述（解锁）
    petActiveStat        = {255, 200, 130, 200}, -- 主动技能数值（解锁）
    petLockedText        = {120, 120, 120, 200}, -- 未解锁通用灰文字
    petLockedDim         = {100, 100, 100, 150}, -- 未解锁更暗灰
    petDivider           = {80, 80, 100, 80},    -- 分隔线
    petRulesBtnSmall     = {60, 80, 120, 200},   -- "?"按钮底色
    petRulesBtnSmallFg   = {200, 220, 255, 255}, -- "?"按钮文字
    petSlotCount         = {150, 150, 150, 255}, -- 技能槽计数
    -- 外观面板（PetPanelAppearance）
    petSkinResetBg       = {70, 70, 80, 200},     -- "恢复默认"按钮底
    petSkinResetFg       = {180, 180, 190, 255},  -- "恢复默认"按钮文字
    petSkinEquipBg       = {40, 32, 15, 240},     -- 装备中卡底（暖金底）
    petSkinEquipBd       = {220, 170, 50, 220},   -- 装备中卡边框（金）
    petSkinOwnedBg       = {28, 28, 45, 220},     -- 已拥有卡底
    petSkinOwnedBd       = {100, 110, 180, 120},  -- 已拥有卡边框
    petSkinLockedBg      = {35, 35, 35, 160},     -- 未解锁卡底
    petSkinLockedBd      = {60, 60, 60, 80},      -- 未解锁卡边框
    petSkinPreviewOwned  = {20, 18, 30, 255},     -- 预览区底（已拥有）
    petSkinPreviewLocked = {25, 25, 25, 200},     -- 预览区底（未解锁）
    petSkinLockedTint    = {140, 140, 140, 255},  -- 未解锁贴图染灰
    petSkinBadgeEquipFg  = {255, 230, 130, 255},  -- 装备中角标"✦"文字
    petSkinBadgeEquipBg  = {120, 80, 0, 200},     -- 装备中角标底
    petSkinBadgePremFg   = {255, 200, 80, 255},   -- 高级角标"★"（已拥有）
    petSkinBadgePremDim  = {120, 100, 60, 180},   -- 高级角标"★"（未解锁）
    petSkinBadgePremBg   = {100, 50, 0, 180},     -- 高级角标底
    petSkinNamePrem      = {255, 190, 80, 255},   -- 高级皮肤名（已拥有）
    petSkinNamePremDim   = {130, 100, 50, 180},   -- 高级皮肤名（未解锁）
    petSkinNameBase      = {220, 225, 240, 255},  -- 基础皮肤名（已拥有）
    petSkinNameBaseDim   = {110, 110, 110, 180},  -- 基础皮肤名（未解锁）
    petSkinBonusOwned    = {80, 230, 80, 220},    -- 属性加成（已拥有绿）
    petSkinBonusLocked   = {90, 90, 90, 150},     -- 属性加成（未解锁灰）
    petSkinEquipLabel    = {220, 185, 60, 255},   -- "使用中"文字
    petSkinEquipBtn      = {50, 120, 200, 255},   -- "装备"按钮底
    petSkinSourceText    = {100, 100, 100, 160},  -- 来源说明文字
    petSkinSectionBase   = {160, 170, 200, 200},  -- 基础外观分栏标
    petSkinSectionPrem   = {220, 180, 80, 220},   -- 高级外观分栏标
    -- 形态面板（PetPanelForms）
    petFormNormalBg      = {60, 60, 70, 220},     -- 普通形态按钮底
    petFormNormalBd      = {100, 100, 120, 150},  -- 普通形态边框
    petFormNormalIcon    = {50, 50, 60, 255},     -- 普通形态图标底
    petFormBattleBg      = {50, 35, 25, 220},     -- 战斗形态按钮底
    petFormBattleBd      = {200, 120, 60, 150},   -- 战斗形态边框
    petFormBattleIcon    = {70, 40, 20, 255},     -- 战斗形态图标底
    petFormGuardBg       = {25, 40, 50, 220},     -- 守护形态按钮底
    petFormGuardBd       = {80, 160, 220, 150},   -- 守护形态边框
    petFormGuardIcon     = {20, 50, 70, 255},     -- 守护形态图标底
    petFormRageBg        = {50, 25, 25, 220},     -- 狂暴形态按钮底
    petFormRageBd        = {220, 80, 80, 150},    -- 狂暴形态边框
    petFormRageIcon      = {70, 20, 20, 255},     -- 狂暴形态图标底
    petFormActiveGlow    = {255, 200, 80, 255},   -- 激活态边框金色
    petFormLockedFont    = {100, 100, 100, 150},  -- 形态锁定文字
    petFormCdFont        = {200, 150, 80, 255},   -- CD 文字
    petFormNameUnlocked  = {220, 220, 230, 255},  -- 形态名（解锁）
    petFormStatDesc      = {180, 200, 160, 200},  -- 属性变更简述
    petFormCdActive      = {180, 220, 120, 255},  -- 当前形态CD文字
    petFormContainerBg   = {35, 35, 45, 200},     -- 形态容器底色
    petFormContainerBd   = {100, 80, 60, 80},     -- 形态容器边框
    petFormTitle         = {255, 200, 100, 255},  -- "形态"标题
    petFormDesc          = {160, 160, 170, 180},  -- 形态描述文字
    petFormEnhRageBg     = {60, 45, 20, 180},     -- 形态增强底（狂暴/战斗）
    petFormEnhRageBd     = {200, 160, 60, 100},   -- 形态增强边框（狂暴/战斗）
    petFormEnhRageFg     = {255, 200, 80, 255},   -- 形态增强文字（狂暴/战斗）
    petFormEnhGuardBg    = {20, 50, 60, 180},     -- 形态增强底（守护）
    petFormEnhGuardBd    = {80, 180, 200, 100},   -- 形态增强边框（守护）
    petFormEnhGuardFg    = {100, 220, 200, 255},  -- 形态增强文字（守护）

    -- ▼ 图录/收集面板色 ─────────────────────────────
    collectedBg     = {35, 45, 40, 220},    -- 已收录条目底色（绿底）
    collectedBorder = {80, 180, 100, 120},  -- 已收录条目边框（绿边）
    summaryBg       = {25, 35, 30, 220},    -- 总加成面板底色
    summaryBorder   = {80, 150, 100, 100},  -- 总加成面板边框
    bonusLabel      = {160, 180, 140, 220}, -- 奖励标签文字（灰绿）
    bonusValue      = {200, 220, 180, 255}, -- 奖励值文字（亮绿）

    -- ▼ 标签/徽章色 ──────────────────────────────
    badgeAdvanceBg   = {15, 70, 75, 200},    -- 进阶丹药 badge 底（青）
    badgeAdvanceFg   = {100, 230, 220, 255}, -- 进阶丹药 badge 文字（青）
    badgeAttrBg      = {90, 50, 15, 200},    -- 属性丹药 badge 底（橙）
    badgeAttrFg      = {255, 185, 80, 255},  -- 属性丹药 badge 文字（橙）
    badgePackBg      = {55, 30, 80, 200},    -- 物品打包 badge 底（紫）
    badgePackFg      = {200, 150, 255, 255}, -- 物品打包 badge 文字（紫）

    -- ▼ 芯片/小容器色 ────────────────────────────
    chipBg           = {40, 45, 60, 180},    -- 行内小信息容器底色（灵韵余额等）

    -- ▼ 活动面板色（EventExchangeUI，前缀 evt） ────────
    evtRarityCommon    = {200, 200, 210, 255},  -- 普通物品文字
    evtRarityRare      = {100, 200, 255, 255},  -- 稀有物品文字
    evtRarityLegendary = {255, 215, 0, 255},    -- 传说物品文字
    evtBoxSmallTag     = {80, 140, 220, 255},   -- 小宝箱标签色
    evtBoxBigTag       = {220, 180, 40, 255},   -- 大宝箱标签色
    evtBoxSmallBg      = {35, 40, 55, 200},     -- 小宝箱区底色
    evtBoxSmallBd      = {80, 140, 220, 80},    -- 小宝箱区边框
    evtBoxBigBg        = {45, 40, 30, 200},     -- 大宝箱区底色
    evtBoxBigBd        = {220, 180, 40, 80},    -- 大宝箱区边框
    evtFiveOpenBg      = {180, 80, 200, 255},   -- 五连开按钮底色
    evtPoolBg          = {30, 33, 45, 220},     -- 奖池展开区底色
    evtPoolBd          = {80, 90, 110, 120},    -- 奖池展开区边框
    evtDescBg          = {30, 35, 50, 180},     -- 道具说明区底色
    evtDescTitle       = {200, 200, 220, 220},  -- 道具说明标题
    evtDescSmall       = {140, 180, 220, 200},  -- 道具说明小宝箱文字
    evtDescBig         = {220, 180, 100, 200},  -- 道具说明大宝箱文字
    evtPity            = {255, 200, 80, 200},   -- 保底进度文字
    evtScoreGreen      = {140, 200, 140, 200},  -- 积分加成文字（绿）
    evtOwnHave         = {255, 220, 100, 255},  -- 持有数量（有道具）
    evtOwnEmpty        = {120, 120, 140, 200},  -- 持有数量（无道具）
    evtDivider         = {80, 90, 110, 80},     -- 内容分隔线
    evtRecordTime      = {120, 120, 140, 150},  -- 记录时间文字
    evtEmptyHint       = {120, 120, 140, 150},  -- 空数据提示
    evtPoolToggleBg    = {50, 55, 70, 200},     -- 奖池展开按钮底
    evtPoolToggleFg    = {160, 160, 180, 220},  -- 奖池展开按钮文字
    evtResultTitle     = {200, 200, 210, 255},  -- 开启结果标题
    -- 排行页
    evtRankHintBg      = {60, 50, 30, 200},     -- 奖励提示条底色
    evtRankHintBd      = {200, 160, 40, 100},   -- 奖励提示条边框
    evtRankHintFg      = {255, 220, 100, 255},  -- 奖励提示条文字
    evtRankHeader      = {140, 140, 155, 200},  -- 排行表头文字
    evtRankGold        = {255, 215, 0, 255},    -- 第1名名字色
    evtRankSilver      = {200, 200, 220, 255},  -- 第2名名字色
    evtRankBronze      = {200, 150, 80, 255},   -- 第3名名字色
    evtRankNormal      = {200, 200, 210, 255},  -- 其他名次名字色
    evtRankScore       = {255, 220, 100, 255},  -- 积分数字色
    evtRankRowAlt      = {40, 43, 55, 120},     -- 排行行交替底色
    evtRankSelfBg      = {50, 45, 30, 180},     -- 自己排名区底色
    evtRankTapNick     = {140, 160, 200, 180},  -- TapTap昵称文字
    evtRankTotal       = {120, 120, 140, 150},  -- 参与人数文字
    evtLockHintBg      = {45, 35, 30, 200},     -- 锁榜提示底色
    evtLockHintBd      = {200, 100, 60, 100},   -- 锁榜提示边框
    evtLockHintFg      = {255, 180, 100, 255},  -- 锁榜提示文字
    -- 弹窗
    evtPopupBg         = {30, 32, 45, 250},     -- 弹窗底色
    evtPopupBorderGold = {255, 200, 50, 200},   -- 弹窗金边
    evtPopupBorderDim  = {160, 160, 180, 150},  -- 弹窗灰边（重复）
    evtPopupDivider    = {255, 215, 0, 60},     -- 弹窗内分割线
    evtPopupSkinName   = {255, 230, 150, 255},  -- 弹窗皮肤名
    evtPopupSkinBg     = {40, 42, 55, 200},     -- 弹窗皮肤图底
    evtPopupBonusGreen = {150, 230, 150, 255},  -- 弹窗加成文字绿
    evtPopupSubtext    = {180, 180, 195, 220},  -- 弹窗副文字
    evtPopupItemName   = {255, 180, 50, 255},   -- 弹窗传说物品名
    evtPopupItemDesc   = {180, 180, 200, 200},  -- 弹窗传说物品描述
    -- 里程碑
    evtMsClaimedBg     = {30, 38, 35, 160},     -- 已领取行底色
    evtMsCanClaimBg    = {50, 45, 25, 220},     -- 可领取行底色
    evtMsClaimedBadge  = {50, 120, 70, 180},    -- 已领取徽章底
    evtMsProgressBg    = {50, 55, 70, 180},     -- 进度条底色
    -- Tab栏（活动面板内专用，沿用通用 tab token 即可，此处仅备注）
    evtTabActiveBg     = {200, 160, 40, 255},   -- Tab激活底
    evtTabActiveFg     = {30, 25, 15, 255},     -- Tab激活文字
    evtTabInactiveBg   = {60, 65, 80, 200},     -- Tab未激活底
    evtTabInactiveFg   = {180, 180, 190, 255},  -- Tab未激活文字
    -- NPC头部
    evtNpcBg           = {60, 50, 80, 200},     -- NPC头像底色
    evtNpcSubtitle     = {140, 140, 160, 200},  -- NPC副标题
    evtNpcDialog       = {180, 180, 200, 220},  -- NPC对话文字
    evtStatusText      = {180, 220, 255, 200},  -- 状态提示文字

    -- ▼ 卡片边框色（半透明，用于公告/活动/奖励区块） ────
    cardBorderGold   = {255, 200, 80, 120},  -- 金色半透明（公告/福利/奖励/补偿）
    cardBorderInfo   = {100, 140, 200, 100}, -- 蓝色半透明（信息/社群卡片）

    -- ── 装备弹窗 EquipTooltip 专属色（Step 2 录入） ──
    equipTipPanelBg          = {25, 28, 38, 245},    -- 主面板底色
    equipTipPanelBorder      = {80, 90, 110, 200},   -- 主面板边框
    equipTipDivider          = {80, 85, 100, 120},   -- 信息区分割线
    equipTipDividerFaint     = {80, 85, 100, 100},   -- 对比表分割线（更淡）
    equipTipDescText         = {220, 220, 230, 220}, -- 消耗品描述正文
    equipTipConsumableBg     = {35, 45, 35, 200},    -- 消耗品描述区底色（绿调）
    equipTipStatLabel        = {160, 160, 180, 200}, -- 属性段标题（主/副属性 ▸）
    equipTipMainStatName     = {255, 255, 230, 255}, -- 主属性名称（暖白）
    equipTipSubStatName      = {200, 200, 220, 255}, -- 副属性名称（冷白）
    equipTipSubStatVal       = {150, 220, 150, 255}, -- 副属性数值（淡绿）
    equipTipSubStatBg        = {30, 35, 48, 200},    -- 副属性区底色
    equipTipForgeBg          = {45, 38, 55, 200},    -- 洗练属性区底色（紫调）
    equipTipForgeBorder      = {180, 140, 60, 120},  -- 洗练属性区边框（暗金）
    equipTipForgeLabel       = {180, 160, 100, 200}, -- 洗练 ▸ 标签
    equipTipForgeVal         = {255, 200, 100, 255}, -- 洗练属性数值（亮金）
    equipTipSpiritBg         = {25, 45, 45, 200},    -- 灵性区底色（青调）
    equipTipSpiritBorder     = {0, 200, 200, 120},   -- 灵性区边框
    equipTipSpiritLabel      = {0, 200, 200, 200},   -- 灵性 ▸ 标签
    equipTipSpiritName       = {150, 240, 240, 255}, -- 灵性属性名（浅青）
    equipTipSpiritVal        = {0, 220, 220, 255},   -- 灵性属性数值（深青）
    equipTipSaintBg          = {50, 10, 10, 210},    -- 圣性区底色（深红调）
    equipTipSaintBorder      = {255, 60, 60, 130},   -- 圣性区边框
    equipTipSaintLabel       = {255, 80, 80, 220},   -- 圣性 ▸ 标签
    equipTipSaintName        = {255, 180, 180, 255}, -- 圣性属性名（粉红）
    equipTipSetName          = {255, 200, 100, 255}, -- 套装名称（橙金）
    equipTipInactive         = {120, 120, 120, 180}, -- 未激活行（暗灰）
    equipTipSetBg            = {45, 38, 25, 200},    -- 套装区底色（暖棕）
    equipTipEnchantActive    = {200, 160, 255, 255}, -- 附灵激活行（浅紫）
    equipTipEnchantBg        = {40, 30, 60, 220},    -- 附灵区底色（深紫）
    equipTipEnchantBorder    = {160, 100, 255, 150}, -- 附灵区边框
    equipTipSkillBg          = {25, 40, 55, 200},    -- 技能区底色（蓝调）
    equipTipSkillBorder      = {80, 160, 220, 100},  -- 技能区边框
    equipTipSkillName        = {100, 200, 255, 255}, -- 技能名称（亮蓝）
    equipTipSkillCd          = {160, 180, 200, 180}, -- 技能 CD 文字
    equipTipSkillDesc        = {180, 200, 220, 200}, -- 技能描述
    equipTipWineLabel        = {200, 180, 120, 200}, -- 美酒 ▸ 标签
    equipTipWineName         = {255, 220, 140, 255}, -- 美酒名称（暖金）
    equipTipWineEffect       = {200, 200, 180, 180}, -- 美酒效果描述
    equipTipWineEmpty        = {100, 100, 110, 150}, -- 空酒槽提示
    equipTipWineBg           = {40, 35, 25, 200},    -- 美酒区底色（暖棕）
    equipTipWineBorder       = {180, 150, 80, 100},  -- 美酒区边框
    equipTipSpecialBg        = {55, 25, 25, 200},    -- 独特效果区底色（深红）
    equipTipSpecialBorder    = {220, 120, 60, 100},  -- 独特效果区边框
    equipTipSpecialName      = {255, 160, 60, 255},  -- 独特效果名称（橙）
    equipTipSpecialDesc      = {255, 200, 150, 200}, -- 独特效果描述
    equipTipLingYunPrice     = {180, 140, 255, 200}, -- 灵韵售价（紫）
    equipTipGoldPrice        = {200, 180, 100, 160}, -- 金币售价（暗金）
    equipTipTagBg            = {60, 60, 80, 200},    -- 标签底色
    equipTipTagText          = {255, 255, 255, 220}, -- 标签文字
    equipTipCompareLabel     = {160, 160, 180, 180}, -- 对比标题
    equipTipCompareEquipped  = {100, 200, 100, 230}, -- 对比"已装备"列头（绿）
    equipTipCompareCurrent   = {100, 180, 255, 230}, -- 对比"当前"列头（蓝）
    equipTipCompareNeutral   = {200, 200, 220, 220}, -- 对比持平色
    equipTipCompareBetter    = {100, 255, 100, 255}, -- 对比更优（绿）
    equipTipCompareWorse     = {255, 130, 130, 220}, -- 对比更差（红）
    equipTipCompareStatName  = {200, 200, 220, 200}, -- 对比属性名
    equipTipComparePanelBg   = {20, 22, 32, 235},    -- 对比面板底色
    equipTipComparePanelBorder = {80, 90, 110, 150}, -- 对比面板边框
    equipTipEquippedTag      = {60, 100, 60, 220},   -- "已装备"标签色
    equipTipEquippedPanelBg  = {22, 25, 35, 235},    -- 已装备对比面板底色
    equipTipEquippedPanelBorder = {60, 80, 60, 180}, -- 已装备对比面板边框（绿调）

    -- ── 背包/命格通用色（Step 0 预录，Step 2/3 接入） ──
    invPanelBg       = {30, 35, 45, 240},    -- 左右面板底色
    invStatPanelBg   = {20, 25, 35, 200},    -- 属性统计区深底
    invStatValue     = {220, 220, 220, 255}, -- 属性数值文字
    invSetBonus      = {255, 200, 100, 200}, -- 装备套装加成文字
    minggeSetBonus   = {100, 220, 255, 230}, -- 命格套装加成文字
    invSortBtn       = {50, 90, 130, 220},   -- 整理按钮
    invSellBtn       = {120, 80, 30, 220},   -- 批量出售按钮
    invSellDropBtn   = {100, 65, 20, 220},   -- ▼下拉按钮
    invEmptySlot     = {180, 180, 180, 200}, -- 空位提示文字
    invDivider       = {80, 90, 110, 150},   -- 分隔线
    invDividerText   = {140, 150, 170, 200}, -- 分隔文字
    invTabActive     = {60, 140, 220, 255},  -- 背包Tab激活底
    invTabInactive   = {60, 60, 75, 200},    -- 背包Tab未激活底
    invInfoLabel     = {200, 200, 200, 200}, -- 信息标签
    minggeLockMask   = {15, 10, 25, 220},    -- 命格解封遮罩底
    minggeUnlockBtn  = {100, 60, 180, 240},  -- 解封按钮底

    -- ▼ 命格 Tooltip 专属色 ──────────────────────────────
    minggeTipOverlay      = {0, 0, 0, 160},       -- 遮罩（比通用 overlay 更深）
    minggeTipCardBg       = {30, 35, 50, 250},    -- 内容卡片底色
    minggeTipPortraitBg   = {20, 22, 35, 255},    -- 头像区底色
    minggeTipElemBadgeBg  = {0, 0, 0, 180},       -- 五行角标底色
    minggeTipInfoText     = {180, 180, 200, 230},  -- 品质/五行/阶级信息行文字
    minggeTipDivider      = {80, 90, 120, 150},    -- 分隔线
    minggeTipStatRowBg    = {50, 60, 80, 200},     -- 属性行底色
    minggeTipStatName     = {220, 220, 240, 255},  -- 属性名文字
    minggeTipSetBg        = {40, 55, 70, 200},     -- 套装信息区底色
    minggeTipSetName      = {100, 220, 255, 255},  -- 套装名文字（纯白透明）
    minggeTipSetDesc      = {150, 200, 220, 200},  -- 套装描述文字
    minggeTipWarn         = {255, 100, 100, 230},  -- 同名警告文字
    minggeTipSellLabel    = {140, 140, 160, 200},  -- 出售标签文字
    minggeTipLingYunPrice = {180, 140, 255, 255},  -- 灵韵售价文字
    minggeTipEquipBtn     = {60, 140, 80, 240},    -- 装备按钮底色
    minggeTipDisabledBtn  = {80, 80, 80, 200},     -- 禁用装备按钮底色
    minggeTipSellBtn      = {140, 80, 40, 240},    -- 出售按钮底色
    minggeTipLockBtn      = {80, 80, 100, 220},    -- 锁定/解锁按钮底色
    minggeTipUnequipBtn   = {140, 100, 40, 240},   -- 卸下按钮底色
    minggeTipCloseBtn     = {60, 60, 70, 220},     -- 关闭按钮底色
}

-- ── 属性色阶（背包/命格通用，按 stat key 查找） ──
UITheme.statColor = {
    atk             = {255, 150, 100, 255},
    def             = {100, 200, 255, 255},
    maxHp           = {100, 255, 100, 255},
    hpRegen         = {150, 255, 200, 255},
    critRate        = {255, 220, 100, 255},
    critDmg         = {255, 200, 80, 255},
    heavyHit        = {255, 140, 60, 255},
    skillDmg        = {200, 150, 255, 255},
    killHeal        = {100, 255, 180, 255},
    dmgReduce       = {180, 140, 255, 255},
    speed           = {100, 220, 255, 255},
    moveSpeed       = {100, 220, 255, 255},
    fortune         = {255, 215, 0, 255},
    wisdom          = {200, 150, 255, 255},
    constitution    = {255, 180, 100, 255},
    physique        = {220, 50, 50, 255},
    tianzhuChance   = {0, 220, 220, 255},
    tianzhuDamage   = {0, 220, 220, 255},
    petSyncRate     = {0, 220, 220, 255},
    attackSpeedBonus= {255, 200, 80, 255},
}

-- ── 品质辉光边框色（带透明度，用于图标边框） ──
UITheme.qualityBorder = {
    white  = {200, 200, 200, 100},
    green  = {80, 210, 120, 160},
    blue   = {90, 170, 255, 180},
    purple = {180, 130, 255, 180},
    orange = {255, 165, 80, 200},
    red    = {255, 80, 90, 200},
}

-- ── 装饰预设 ──
UITheme.decor = {
    -- 面板 header 样式
    headerBorderBottom = {60, 65, 90, 200},
    -- 行分隔线
    dividerColor = {60, 65, 90, 120},
    dividerHeight = 1,
    -- 品质背景微光（用于 slot 底色）
    qualitySlotBg = {
        white  = {200, 200, 200, 15},
        green  = {80, 210, 120, 20},
        blue   = {90, 170, 255, 25},
        purple = {180, 130, 255, 25},
        orange = {255, 165, 80, 30},
        red    = {255, 80, 90, 30},
    },
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

    -- 行内操作按钮
    inlineBtnH     = 28,   -- 列表行内小按钮高度（收录/购买/解锁等）
    inlineBtnW     = 60,   -- 列表行内小按钮默认宽度

    -- Tab / StatRow
    statValueMinW  = 72,   -- StatRow 值列最小宽度（右对齐）
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
