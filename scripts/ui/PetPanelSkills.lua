-- ============================================================================
-- PetPanelSkills.lua - 宠物面板「技能」Tab 内容构建 + 技能弹窗逻辑
-- P2 重构：整合 CreateSkillGridCell/ShowLearnPopup/ShowSkillActionPopup/ShowSkillRules
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local PetSkillData = require("config.PetSkillData")
local InventorySystem = require("systems.InventorySystem")
local CombatSystem = require("systems.CombatSystem")
local PetPanelForms = require("ui.PetPanelForms")
local PetPanelOps = require("ui.PetPanelOps")
local T = require("config.UITheme")

local M = {}

-- 模块内部状态
local confirmDialog_ = nil
local parentOverlay_ = nil
local refreshFn_ = nil  -- 外部注入的面板刷新回调

-- 宠物技能变更后刷新角色面板
local function notifyCharacterUI()
    local CharacterUI = require("ui.CharacterUI")
    if CharacterUI.IsVisible() then
        CharacterUI.Refresh()
    end
end

-- ============================================================================
-- 初始化（由 PetPanel.Create 调用，注入外部依赖）
-- ============================================================================

---@param overlay table 父遮罩容器（用于挂载弹窗）
---@param callbacks table { refresh: fn }
function M.Init(overlay, callbacks)
    parentOverlay_ = overlay
    refreshFn_ = callbacks.refresh
end

-- ============================================================================
-- 弹窗管理
-- ============================================================================

function M.HideConfirm()
    if confirmDialog_ then
        confirmDialog_:Destroy()
        confirmDialog_ = nil
    end
end

function M.ShowConfirm(title, text, onConfirm, onCancel)
    M.HideConfirm()

    confirmDialog_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = T.color.popupOverlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self) end,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = T.color.popupBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = T.color.popupBorder,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                children = {
                    UI.Label {
                        text = title,
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = text,
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.textSecondary,
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        justifyContent = "center",
                        children = {
                            UI.Button {
                                text = onCancel and "放弃" or "取消",
                                width = 100, height = 38,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = T.color.petCancelBg,
                                fontColor = T.color.petCancelFg,
                                onClick = function(self)
                                    M.HideConfirm()
                                    if onCancel then onCancel() end
                                end,
                            },
                            UI.Button {
                                text = "确认",
                                width = 100, height = 38,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = T.color.petConfirmBg,
                                fontColor = T.color.textPrimary,
                                onClick = function(self)
                                    M.HideConfirm()
                                    if onConfirm then onConfirm() end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmDialog_)
    end
end

-- ============================================================================
-- 技能规则说明（对齐排行榜规则面板规范：数据驱动 + 序号行 + 分层底色）
-- ============================================================================

--- 技能规则数据（精简）
local SKILL_RULES_DATA = {
    title = "📜 技能规则",
    rules = {
        "点击空格「+」学习技能，消耗初级技能书×1",
        "同一技能只能学习一次，10格可装满不同技能",
        "点击已学技能可升级：普通或深度学习(100%)",
        "升级消耗对应等级技能书，深度学习额外消耗灵韵",
        "升级失败仍消耗材料，请量力而行",
        "删除技能需二次确认，不退还任何材料",
        "初级技能书(蓝)：坊市购买(1000金)",
        "中级技能书(紫)：黑市购买(4仙石)",
        "高级技能书(橙)：黑市购买(8仙石) / 龙神BOSS掉落",
        "特级技能书(红)：黑市购买(16仙石) / 第五章皇级BOSS掉落",
    },
    motto = "合理搭配技能，让狗子更强！",
}

--- 构建单条规则行（序号金色 + 内容灰蓝）
local function BuildSkillRuleLine(index, text)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = T.spacing.xs,
        alignItems = "baseline",
        children = {
            UI.Label {
                text = tostring(index) .. ".",
                fontSize = T.fontSize.sm,
                fontColor = T.color.goldDark,
                fontWeight = "bold",
            },
            UI.Label {
                text = text,
                fontSize = T.fontSize.sm,
                fontColor = T.color.textSecondary,
                flexShrink = 1,
            },
        },
    }
end

function M.ShowSkillRules()
    M.HideConfirm()

    local data = SKILL_RULES_DATA

    -- 构建规则行列表
    local ruleLines = {}
    for i, rule in ipairs(data.rules) do
        ruleLines[#ruleLines + 1] = BuildSkillRuleLine(i, rule)
    end

    confirmDialog_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self)
            M.HideConfirm()
        end,
        children = {
            UI.Panel {
                width = "88%",
                maxWidth = 400,
                maxHeight = "76%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = T.color.cardBorderInfo or T.color.goldDark,
                padding = T.spacing.lg,
                gap = T.spacing.sm,
                onClick = function(self) end, -- 阻止穿透
                children = {
                    -- 标题
                    UI.Label {
                        text = data.title,
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                        textAlign = "center",
                    },
                    -- 上分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = T.decor.dividerColor },
                    -- 规则区域（深色底 + 圆角）
                    UI.ScrollView {
                        flexShrink = 1,
                        children = {
                            UI.Panel {
                                width = "100%",
                                backgroundColor = T.color.surfaceDeep,
                                borderRadius = T.radius.sm,
                                padding = T.spacing.sm,
                                gap = T.spacing.xs,
                                children = ruleLines,
                            },
                        },
                    },
                    -- 下分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = T.decor.dividerColor },
                    -- 鼓励语
                    UI.Label {
                        text = data.motto,
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.jade,
                        textAlign = "center",
                        marginTop = T.spacing.xs,
                    },
                    -- 关闭按钮
                    UI.Button {
                        text = "知道了",
                        variant = "secondary",
                        alignSelf = "center",
                        width = 120,
                        marginTop = T.spacing.sm,
                        onClick = function(self)
                            M.HideConfirm()
                        end,
                    },
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmDialog_)
    end
end

-- ============================================================================
-- 空格点击：学习技能列表弹窗
-- ============================================================================

function M.ShowLearnPopup(slotIndex)
    local pet = GameState.pet
    if not pet then return end

    -- 收集已学技能 id
    local learnedSkills = {}
    for i = 1, 10 do
        if pet.skills[i] then
            learnedSkills[pet.skills[i].id] = true
        end
    end

    -- 筛选背包中未学过的初级技能书
    local books = InventorySystem.GetSkillBookList()
    local available = {}
    for _, book in ipairs(books) do
        if book.bookTier == 1 and not learnedSkills[book.skillId] then
            table.insert(available, book)
        end
    end

    -- 选中状态
    local selectedBook_ = nil
    ---@type table|nil
    local learnBtn_ = nil
    local bookButtons_ = {}

    -- 构建列表
    local listChildren = {}

    if #available == 0 then
        table.insert(listChildren, UI.Label {
            text = "暂无可学习的技能书\n(需要初级技能书，且技能未重复)",
            fontSize = T.fontSize.sm,
            fontColor = T.color.textMuted,
            textAlign = "center",
        })
    else
        for _, book in ipairs(available) do
            local skillDef = PetSkillData.SKILLS[book.skillId]
            local statName = PetSkillData.STAT_NAMES[skillDef.stat] or "?"
            local _, value, pct, _, isFlat, isOwner = PetSkillData.GetSkillBonus(book.skillId, 1)
            local valueFmt = pct and (value .. "%") or tostring(value)
            local ownerPrefix = isOwner and "主人" or ""
            local normalBg = T.color.petLearnItemBg
            local selectedBg = T.color.petLearnItemSelected

            local btn = UI.Button {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
                paddingTop = 6, paddingBottom = 6,
                backgroundColor = normalBg,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = T.color.transparent,
                onClick = function(self)
                    for _, b in ipairs(bookButtons_) do
                        b:SetStyle({
                            backgroundColor = normalBg,
                            borderColor = T.color.transparent,
                        })
                    end
                    selectedBook_ = book
                    self:SetStyle({
                        backgroundColor = selectedBg,
                        borderColor = T.color.petLearnItemSelBorder,
                    })
                    if learnBtn_ then
                        learnBtn_:SetStyle({
                            backgroundColor = T.color.petConfirmBg,
                            fontColor = T.color.textPrimary,
                        })
                    end
                end,
                children = {
                    UI.Label {
                        text = skillDef.icon,
                        fontSize = T.fontSize.lg,
                        width = 28,
                        textAlign = "center",
                        pointerEvents = "none",
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        pointerEvents = "none",
                        children = {
                            UI.Label {
                                text = book.name,
                                fontSize = T.fontSize.sm,
                                fontColor = T.color.textSecondary,
                            },
                            UI.Label {
                                text = ownerPrefix .. statName .. "+" .. valueFmt,
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.textMuted,
                            },
                        },
                    },
                    UI.Label {
                        text = "x" .. book.count,
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textSecondary,
                        pointerEvents = "none",
                    },
                },
            }
            table.insert(bookButtons_, btn)
            table.insert(listChildren, btn)
        end
    end

    -- 学习按钮
    learnBtn_ = UI.Button {
        text = "学习",
        width = "100%", height = 40,
        fontSize = T.fontSize.md, fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = T.color.btnDisabled,
        fontColor = T.color.btnDisabledFg,
        onClick = function(self)
            if not selectedBook_ then return end
            local book = selectedBook_
            local ok = InventorySystem.ConsumeConsumable(book.consumableId, 1)
            if not ok then return end
            pet.skills[slotIndex] = { id = book.skillId, tier = 1 }
            pet:RecalcStats()

            local skillName = PetSkillData.GetSkillDisplayName(book.skillId, 1)
            local player = GameState.player
            if player then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 1.0,
                    "学习成功! " .. skillName, T.color.jade, 2.0
                )
            end
            EventBus.Emit("save_request")
            M.HideConfirm()
            if refreshFn_ then refreshFn_() end
            notifyCharacterUI()
        end,
    }

    M.HideConfirm()

    confirmDialog_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = T.color.popupOverlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self)
            M.HideConfirm()
        end,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = T.size.npcPanelMaxW,
                maxHeight = "76%",
                backgroundColor = T.color.popupBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = T.color.popupBorder,
                onClick = function(self) end,
                children = {
                    -- ═══ header ═══
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        paddingLeft = T.spacing.sm,
                        paddingRight = T.spacing.md,
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.sm,
                        borderBottomWidth = 1,
                        borderColor = T.decor.headerBorderBottom,
                        children = {
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                children = {
                                    UI.Label {
                                        text = "学习初级技能",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.gold,
                                    },
                                    UI.Label {
                                        text = "选择一本技能书进行学习",
                                        fontSize = T.fontSize.xs,
                                        fontColor = T.color.textMuted,
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.sm,
                                backgroundColor = {255, 100, 100, 30},
                                fontColor = T.color.error,
                                onClick = function(self)
                                    M.HideConfirm()
                                end,
                            },
                        },
                    },
                    -- ═══ 可滚动内容区 ═══
                    UI.ScrollView {
                        flexShrink = 1,
                        paddingLeft = T.spacing.sm,
                        paddingRight = T.spacing.sm,
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.sm,
                        children = {
                            UI.Panel {
                                width = "100%",
                                gap = T.spacing.sm,
                                children = listChildren,
                            },
                        },
                    },
                    -- ═══ footer（操作按钮 + 提示） ═══
                    UI.Panel {
                        width = "100%",
                        paddingLeft = T.spacing.sm,
                        paddingRight = T.spacing.sm,
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.sm,
                        borderTopWidth = 1,
                        borderColor = T.decor.dividerColor,
                        gap = T.spacing.xs,
                        alignItems = "center",
                        children = {
                            learnBtn_,
                            UI.Label {
                                text = "点击空白处关闭",
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.textMuted,
                            },
                        },
                    },
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmDialog_)
    end
end

-- ============================================================================
-- 技能格点击：技能信息 + 升级/删除操作弹窗
-- ============================================================================

function M.ShowSkillActionPopup(slotIndex, skill)
    PetPanelOps.ResetDeleteConfirm()
    M.HideConfirm()

    local pet = GameState.pet
    if not pet then return end

    local displayName = PetSkillData.GetSkillDisplayName(skill.id, skill.tier)
    local icon = PetSkillData.GetSkillIcon(skill.id)
    local stat, value, isPercent, isPerLevel, isFlat, isOwner = PetSkillData.GetSkillBonus(skill.id, skill.tier)
    local statName = PetSkillData.STAT_NAMES[stat] or stat
    local ownerPrefix = isOwner and "主人" or ""
    local valueFmt
    if isPerLevel then
        local petLevel = pet.level or 1
        local totalVal = value * petLevel
        local coeffStr = (value == math.floor(value)) and tostring(math.floor(value)) or tostring(value)
        local totalStr = (totalVal == math.floor(totalVal)) and tostring(math.floor(totalVal)) or string.format("%.1f", totalVal)
        valueFmt = coeffStr .. "×" .. petLevel .. "级=" .. totalStr
    elseif isPercent then
        valueFmt = value .. "%"
    else
        valueFmt = tostring(value)
    end
    local nextTier = skill.tier + 1
    local isMaxTier = nextTier > PetSkillData.MAX_TIER

    local popupChildren = {}

    -- 回调集
    local callbacks = {
        hideConfirm = function() M.HideConfirm() end,
        refresh = function() if refreshFn_ then refreshFn_() end end,
    }

    -- ── 技能信息头 + 删除按钮 ──
    table.insert(popupChildren, UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        padding = T.spacing.sm,
        backgroundColor = T.color.petInfoHeadBg,
        borderRadius = T.radius.sm,
        children = {
            UI.Label { text = icon, fontSize = T.fontSize.xl, width = 36, textAlign = "center" },
            UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
                children = {
                    UI.Label {
                        text = displayName,
                        fontSize = T.fontSize.md, fontWeight = "bold",
                        fontColor = ({
                            [1] = T.color.petNameTier1,
                            [2] = T.color.petNameTier2,
                            [3] = T.color.petNameTier3,
                            [4] = T.color.petNameTier4,
                        })[skill.tier] or T.color.petNameTier1,
                    },
                    UI.Label {
                        text = ownerPrefix .. statName .. " +" .. valueFmt,
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.textSecondary,
                    },
                },
            },
            UI.Button {
                id = "delete_skill_btn",
                text = "🗑",
                width = 30, height = 30,
                fontSize = T.fontSize.sm,
                borderRadius = T.radius.sm,
                backgroundColor = T.color.petDeleteBtnBg,
                fontColor = T.color.petDeleteBtnFg,
                onClick = function(self)
                    PetPanelOps.StartDeleteSkill(slotIndex, skill, self, callbacks)
                end,
            },
        },
    })

    -- ── 升级区 ──
    if not isMaxTier then
        local cost = PetSkillData.UPGRADE_COST[nextTier]
        local statKey = string.gsub(skill.id, "_basic", "")
        local bookId = "book_" .. statKey .. "_" .. nextTier
        local bookCount = InventorySystem.CountConsumable(bookId)
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        local bookName = bookData and bookData.name or "中级技能书"
        local playerLingYun = pet.owner and pet.owner.lingYun or 0

        local _, nextValue, nextPct, nextPerLv, _, _ = PetSkillData.GetSkillBonus(skill.id, nextTier)
        local nextFmt
        if nextPerLv then
            local petLevel = pet.level or 1
            local nextTotal = nextValue * petLevel
            local nCoeffStr = (nextValue == math.floor(nextValue)) and tostring(math.floor(nextValue)) or tostring(nextValue)
            local nTotalStr = (nextTotal == math.floor(nextTotal)) and tostring(math.floor(nextTotal)) or string.format("%.1f", nextTotal)
            nextFmt = nCoeffStr .. "×" .. petLevel .. "级=" .. nTotalStr
        elseif nextPct then
            nextFmt = nextValue .. "%"
        else
            nextFmt = tostring(nextValue)
        end

        -- 升级目标提示
        table.insert(popupChildren, UI.Label {
            text = "升级后: " .. ownerPrefix .. statName .. " +" .. nextFmt,
            fontSize = T.fontSize.xs,
            fontColor = T.color.petUpgradeHintText,
            textAlign = "center",
            marginTop = 2,
        })

        local hasBookA = bookCount >= cost.pathA.bookCount
        local hasBookB = bookCount >= cost.pathB.bookCount
        local hasLingYun = playerLingYun >= cost.pathB.lingYun
        local canA = hasBookA
        local canB = hasBookB and hasLingYun

        -- ── 路径A：普通升级 ──
        local colorA = canA and T.color.petUpgradePathABg or T.color.petUpgradeDisabledBg
        local borderA = canA and T.color.petUpgradePathABorder or T.color.petUpgradeDisabledBd
        table.insert(popupChildren, UI.Panel {
            width = "100%",
            backgroundColor = colorA,
            borderRadius = T.radius.md,
            borderWidth = 1, borderColor = borderA,
            padding = T.spacing.sm,
            gap = 4,
            children = {
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label { text = "成功率", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
                        UI.Label {
                            text = math.floor(cost.pathA.successRate * 100) .. "%",
                            fontSize = T.fontSize.md, fontWeight = "bold",
                            fontColor = T.color.petRateNormal,
                        },
                    },
                },
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label { text = "消耗: " .. bookName .. " x" .. cost.pathA.bookCount, fontSize = T.fontSize.xs, fontColor = T.color.petDescText },
                        UI.Label { text = "(已有:" .. bookCount .. ")", fontSize = T.fontSize.xs, fontColor = hasBookA and T.color.petMaterialOk or T.color.petMaterialLack },
                        UI.Label { text = hasBookA and " ✓" or " ✗", fontSize = T.fontSize.xs, fontColor = hasBookA and T.color.petMaterialOk or T.color.petMaterialLack },
                    },
                },
                UI.Button {
                    text = "普通升级",
                    width = "100%", height = 40,
                    fontSize = T.fontSize.md, fontWeight = "bold",
                    borderRadius = T.radius.md,
                    backgroundColor = canA and T.color.petBtnUpgradeA or T.color.btnDisabled,
                    fontColor = canA and T.color.textPrimary or T.color.btnDisabledFg,
                    marginTop = 4,
                    onClick = function(self)
                        PetPanelOps.DoUpgradePathA(slotIndex, skill, callbacks)
                    end,
                },
            },
        })

        -- ── 路径B：深度学习 ──
        local colorB = canB and T.color.petUpgradePathBBg or T.color.petUpgradeDisabledBg
        local borderB = canB and T.color.petUpgradePathBBorder or T.color.petUpgradeDisabledBd
        table.insert(popupChildren, UI.Panel {
            width = "100%",
            backgroundColor = colorB,
            borderRadius = T.radius.md,
            borderWidth = 1, borderColor = borderB,
            padding = T.spacing.sm,
            gap = 4,
            children = {
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label { text = "成功率", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
                        UI.Label {
                            text = math.floor(cost.pathB.successRate * 100) .. "%",
                            fontSize = T.fontSize.md, fontWeight = "bold",
                            fontColor = T.color.petRateHigh,
                        },
                    },
                },
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label { text = "消耗: " .. bookName .. " x" .. cost.pathB.bookCount, fontSize = T.fontSize.xs, fontColor = T.color.petDescText },
                        UI.Label { text = "(已有:" .. bookCount .. ")", fontSize = T.fontSize.xs, fontColor = hasBookB and T.color.petMaterialOk or T.color.petMaterialLack },
                        UI.Label { text = hasBookB and " ✓" or " ✗", fontSize = T.fontSize.xs, fontColor = hasBookB and T.color.petMaterialOk or T.color.petMaterialLack },
                    },
                },
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label { text = "消耗: 灵韵 x" .. cost.pathB.lingYun, fontSize = T.fontSize.xs, fontColor = T.color.petDescText },
                        UI.Label { text = "(已有:" .. playerLingYun .. ")", fontSize = T.fontSize.xs, fontColor = hasLingYun and T.color.petMaterialOk or T.color.petMaterialLack },
                        UI.Label { text = hasLingYun and " ✓" or " ✗", fontSize = T.fontSize.xs, fontColor = hasLingYun and T.color.petMaterialOk or T.color.petMaterialLack },
                    },
                },
                UI.Button {
                    text = "深度学习",
                    width = "100%", height = 40,
                    fontSize = T.fontSize.md, fontWeight = "bold",
                    borderRadius = T.radius.md,
                    backgroundColor = canB and T.color.petBtnUpgradeB or T.color.btnDisabled,
                    fontColor = canB and T.color.textPrimary or T.color.btnDisabledFg,
                    marginTop = 4,
                    onClick = function(self)
                        PetPanelOps.DoUpgradePathB(slotIndex, skill, callbacks)
                    end,
                },
            },
        })
    else
        table.insert(popupChildren, UI.Label {
            text = "已满级",
            fontSize = T.fontSize.md, fontWeight = "bold",
            fontColor = T.color.petMaxTierText,
            textAlign = "center",
            marginTop = T.spacing.md,
            marginBottom = T.spacing.md,
        })
    end

    confirmDialog_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = T.color.popupOverlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self)
            M.HideConfirm()
        end,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = T.color.popupBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = T.color.popupBorderBlue,
                padding = T.spacing.lg,
                gap = T.spacing.sm,
                onClick = function(self) end,
                children = popupChildren,
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmDialog_)
    end
end

-- ============================================================================
-- 技能宫格单元格
-- ============================================================================

---@param slotIndex number
---@param skill table|nil
---@return table UI element
function M.CreateSkillGridCell(slotIndex, skill)
    if not skill then
        return UI.Button {
            flexGrow = 1, flexShrink = 1, flexBasis = 0,
            aspectRatio = 1,
            borderRadius = T.radius.md,
            backgroundColor = T.color.petSlotEmptyBg,
            borderWidth = 1,
            borderColor = T.color.petSlotEmptyBorder,
            justifyContent = "center",
            alignItems = "center",
            onClick = function(self)
                M.ShowLearnPopup(slotIndex)
            end,
            children = {
                UI.Label {
                    text = "+",
                    fontSize = 22,
                    fontColor = T.color.petSlotEmptyIcon,
                    pointerEvents = "none",
                },
            },
        }
    end

    local skillIcon = PetSkillData.GetSkillIcon(skill.id)
    local tierBorderColors = {
        [1] = T.color.petSkillTierBorder1,
        [2] = T.color.petSkillTierBorder2,
        [3] = T.color.petSkillTierBorder3,
        [4] = T.color.petSkillTierBorder4,
    }
    local tierLabels = { [1] = "初", [2] = "中", [3] = "高", [4] = "特" }
    local tierLabelColors = {
        [1] = T.color.petSkillTierLabel1,
        [2] = T.color.petSkillTierLabel2,
        [3] = T.color.petSkillTierLabel3,
        [4] = T.color.petSkillTierLabel4,
    }
    local tierLabel = tierLabels[skill.tier] or "初"
    local tierLabelColor = tierLabelColors[skill.tier] or tierLabelColors[1]

    return UI.Button {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        aspectRatio = 1,
        borderRadius = T.radius.md,
        backgroundColor = T.color.petSlotFilledBg,
        borderWidth = 1.5,
        borderColor = tierBorderColors[skill.tier] or T.color.petSlotEmptyBorder,
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self)
            M.ShowSkillActionPopup(slotIndex, skill)
        end,
        children = {
            UI.Label {
                text = skillIcon,
                fontSize = 22,
                pointerEvents = "none",
            },
            UI.Label {
                text = tierLabel,
                fontSize = 10,
                fontColor = tierLabelColor,
                position = "absolute",
                bottom = 2, right = 4,
                pointerEvents = "none",
            },
        },
    }
end

-- ============================================================================
-- 构建「技能」Tab 内容（返回 children 列表）
-- ============================================================================

function M.Build()
    local pet = GameState.pet
    if not pet then return {} end

    local children = {}

    -- 固有技能区
    table.insert(children, UI.Panel {
        backgroundColor = T.color.petInnateBg,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.petInnateBorder,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "固有技能",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.petInnateTitle,
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                padding = T.spacing.xs,
                backgroundColor = T.color.petInnateCardBg,
                borderRadius = T.radius.sm,
                children = {
                    UI.Label {
                        text = "🔥",
                        fontSize = T.fontSize.lg,
                        width = 32,
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        children = {
                            UI.Label {
                                text = "犬魂狂暴",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = T.color.petInnateName,
                            },
                            UI.Label {
                                text = "宠物阵亡时，主人获得10秒狂暴",
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.petInnateDesc,
                            },
                            UI.Label {
                                text = "攻速+30%  移速+30%  可刷新",
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.petInnateExtra,
                            },
                            PetPanelForms.GetBerserkEnhancementRow(),
                        },
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                padding = T.spacing.xs,
                backgroundColor = T.color.petInnateCardBg,
                borderRadius = T.radius.sm,
                children = {
                    UI.Label {
                        text = "🐾",
                        fontSize = T.fontSize.lg,
                        width = 32,
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        children = {
                            UI.Label {
                                text = "拾荒伴侣",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = T.color.petInnateName,
                            },
                            UI.Label {
                                text = "狗子心情比较好的时候偶尔会帮你拾取一下身边的气球",
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.petInnateDesc,
                            },
                            UI.Label {
                                text = "拾取范围2.5格",
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.petInnateExtra,
                            },
                        },
                    },
                },
            },
        },
    })

    -- 形态切换卡片行
    local formRow = PetPanelForms.BuildFormRow()
    if formRow then
        table.insert(children, formRow)
    end

    -- 主动技能区：灵噬
    local activeSkill = PetSkillData.ACTIVE_SKILL
    if activeSkill then
        local unlocked = pet.tier >= activeSkill.unlockTier
        local tierData = activeSkill.tiers[pet.tier]
        local dmgPct = tierData and math.floor(tierData.dmgMult * 100) or 100
        local vulnPct = math.floor(activeSkill.vulnPercent * 100)

        local skillDesc
        if unlocked then
            skillDesc = string.format(
                "造成%d%%攻击力伤害，使目标受到所有伤害增加%d%%，持续%.0f秒",
                dmgPct, vulnPct, activeSkill.vulnDuration
            )
        else
            local unlockTierName = GameConfig.PET_TIERS[activeSkill.unlockTier]
                and GameConfig.PET_TIERS[activeSkill.unlockTier].name or "灵犬"
            skillDesc = "进阶至" .. unlockTierName .. "后解锁"
        end

        local statLine = unlocked
            and string.format("CD %.0fs  伤害 %d%%ATK  易伤 %d%%/%.0fs", activeSkill.cd, dmgPct, vulnPct, activeSkill.vulnDuration)
            or "未解锁"

        table.insert(children, UI.Panel {
            backgroundColor = unlocked and T.color.petActiveUnlockBg or T.color.petActiveLockedBg,
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = unlocked and T.color.petActiveUnlockBd or T.color.petActiveLockedBd,
            padding = T.spacing.sm,
            gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = "主动技能" .. (unlocked and "" or " (未解锁)"),
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = unlocked and T.color.petActiveTitle or T.color.petLockedText,
                },
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = T.spacing.sm,
                    padding = T.spacing.xs,
                    backgroundColor = unlocked and T.color.petActiveCardBg or T.color.petActiveLockedCard,
                    borderRadius = T.radius.sm,
                    children = {
                        UI.Label {
                            text = activeSkill.icon,
                            fontSize = T.fontSize.lg,
                            width = 32,
                            textAlign = "center",
                        },
                        UI.Panel {
                            flexGrow = 1, flexShrink = 1, flexBasis = 0,
                            children = {
                                UI.Label {
                                    text = unlocked and (activeSkill.name .. " Lv." .. pet.tier) or activeSkill.name,
                                    fontSize = T.fontSize.sm,
                                    fontWeight = "bold",
                                    fontColor = unlocked and T.color.petActiveName or T.color.petLockedText,
                                },
                                UI.Label {
                                    text = skillDesc,
                                    fontSize = T.fontSize.xs,
                                    fontColor = unlocked and T.color.petActiveDesc or T.color.petLockedDim,
                                },
                                UI.Label {
                                    text = statLine,
                                    fontSize = T.fontSize.xs,
                                    fontColor = unlocked and T.color.petActiveStat or T.color.petLockedDim,
                                },
                                unlocked and PetPanelForms.GetSpiritDevourEnhancementRow() or nil,
                            },
                        },
                    },
                },
            },
        })
    end

    -- 分隔
    table.insert(children, UI.Panel { width = "100%", height = 1, backgroundColor = T.color.petDivider })

    -- 技能宫格标题
    local GRID_COLS = 5
    local GRID_ROWS = 2
    local CELL_GAP = 8

    local usedCount = 0
    for i = 1, 10 do
        if pet.skills[i] then usedCount = usedCount + 1 end
    end

    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                children = {
                    UI.Label {
                        text = "技能槽",
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                    },
                    UI.Button {
                        text = "?",
                        width = 22, height = 22,
                        fontSize = T.fontSize.xs,
                        fontWeight = "bold",
                        fontColor = T.color.petRulesBtnSmallFg,
                        backgroundColor = T.color.petRulesBtnSmall,
                        borderRadius = 11,
                        onClick = function(self)
                            M.ShowSkillRules()
                        end,
                    },
                },
            },
            UI.Label {
                text = usedCount .. "/10",
                fontSize = T.fontSize.xs,
                fontColor = T.color.petSlotCount,
            },
        },
    })

    -- 2x5 技能宫格
    for row = 0, GRID_ROWS - 1 do
        local rowChildren = {}
        for col = 0, GRID_COLS - 1 do
            local slotIndex = row * GRID_COLS + col + 1
            table.insert(rowChildren, M.CreateSkillGridCell(slotIndex, pet.skills[slotIndex]))
        end
        table.insert(children, UI.Panel {
            width = "100%",
            flexDirection = "row",
            gap = CELL_GAP,
            children = rowChildren,
        })
    end

    return children
end

return M
