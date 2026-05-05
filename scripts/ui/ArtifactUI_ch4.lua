-- ============================================================================
-- ArtifactUI_ch4.lua - 文王八卦盘神器面板（环形八卦圆盘）
-- 独立弹窗，由 NPCDialog 管理
-- 8个卦位环形排列，中心为太极图
-- 激活卦位 = 卦象亮起，未激活 = 深色遮罩
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ArtifactCh4 = require("systems.ArtifactSystem_ch4")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")

local ArtifactUI_ch4 = {}

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil

local gridCells_ = {}
local gridLabels_ = {}
local gridSubLabels_ = {}
local infoLabel_ = nil
local actionBtn_ = nil
local costLabel_ = nil
local confirmPanel_ = nil
local confirmGridName_ = nil
local confirmCostGold_ = nil
local confirmCostLY_ = nil
local confirmCostFrag_ = nil
local confirmFeedback_ = nil
local confirmCloseTimer_ = nil
local pendingIndex_ = nil
local victoryPanel_ = nil
local centerTaiji_ = nil
local feedbackTimer_ = nil

-- 被动技能详情区域引用
local passiveContainer_ = nil
local passiveTitle_ = nil
local passiveStatus_ = nil
local passiveDesc_ = nil
local passiveDetail_ = nil
local shieldLabel_ = nil

-- ============================================================================
-- 颜色常量
-- ============================================================================

local COLOR_BAGUA_ACTIVE  = {80, 180, 255, 255}
local COLOR_BAGUA_GLOW    = {100, 200, 255, 255}
local COLOR_GOLD          = {255, 215, 0, 255}
local COLOR_GOLD_DIM      = {180, 150, 60, 255}
local COLOR_PASSIVE_ON    = {100, 200, 255, 255}
local COLOR_PASSIVE_OFF   = {120, 120, 130, 255}
local COLOR_NEXT          = {100, 180, 220, 255}

-- 格子状态色
local BG_ACTIVATED    = {0, 0, 0, 0}
local BG_HAS_FRAGMENT = {15, 20, 40, 170}
local BG_NO_FRAGMENT  = {10, 12, 25, 220}

local BORDER_ACTIVATED    = {80, 180, 255, 255}
local BORDER_CAN_ACTIVATE = {255, 215, 0, 255}
local BORDER_LOCKED       = {50, 55, 70, 150}

-- 八卦圆盘布局参数
local DISK_SIZE = 280
local CELL_SIZE = 56
local RADIUS = 100
local CENTER_SIZE = 60

-- 八卦方位角度
local BAGUA_ANGLES = {
    270, 225, 180, 135, 90, 45, 0, 315,
}

-- ============================================================================
-- 确认弹窗
-- ============================================================================

local function ShowConfirmDialog(index)
    if not confirmPanel_ then return end
    pendingIndex_ = index
    local gridName = ArtifactCh4.GRID_SYMBOLS[index] .. " " .. ArtifactCh4.GRID_NAMES[index]
    if confirmGridName_ then
        confirmGridName_:SetText(string.format("激活「%s」卦位", gridName))
    end
    if confirmCostGold_ then
        confirmCostGold_:SetText(string.format("金币  %s", ArtifactCh4.FormatGold(ArtifactCh4.ACTIVATE_GOLD_COST)))
    end
    if confirmCostLY_ then
        confirmCostLY_:SetText(string.format("灵韵  %d", ArtifactCh4.ACTIVATE_LINGYUN_COST))
    end
    if confirmCostFrag_ then
        local fragCfg = GameConfig.CONSUMABLES[ArtifactCh4.FRAGMENT_IDS[index]]
        local fragName = fragCfg and fragCfg.name or ("卦象·" .. ArtifactCh4.GRID_NAMES[index])
        confirmCostFrag_:SetText("碎片  " .. fragName)
    end
    if confirmFeedback_ then
        confirmFeedback_:SetText("")
        confirmFeedback_:SetVisible(false)
    end
    confirmCloseTimer_ = nil
    confirmPanel_:Show()
end

function ArtifactUI_ch4.HideConfirm()
    if confirmPanel_ then confirmPanel_:Hide() end
    confirmCloseTimer_ = nil
    pendingIndex_ = nil
end

local function DoConfirmActivate()
    local index = pendingIndex_
    if not index then return end
    local success, msg = ArtifactCh4.Activate(index)
    if confirmFeedback_ then
        confirmFeedback_:SetText(msg)
        confirmFeedback_:SetStyle({
            fontColor = success and {100, 255, 150, 255} or {255, 100, 100, 255},
        })
        confirmFeedback_:SetVisible(true)
    end
    if success then
        ArtifactUI_ch4.Refresh()
        confirmCloseTimer_ = 1.0
    end
end

-- ============================================================================
-- 格子渲染
-- ============================================================================

local function OnGridCellClick(index)
    if ArtifactCh4.IsGridActivated(index) then return end
    ShowConfirmDialog(index)
end

local function CreateGridCell(index)
    local cellIndex = index
    local angle = BAGUA_ANGLES[index]
    local rad = math.rad(angle)
    local cx = DISK_SIZE / 2 + RADIUS * math.cos(rad) - CELL_SIZE / 2
    local cy = DISK_SIZE / 2 - RADIUS * math.sin(rad) - CELL_SIZE / 2

    local symbolLabel = UI.Label {
        text = ArtifactCh4.GRID_SYMBOLS[index],
        fontSize = 22,
        textAlign = "center",
        fontColor = {100, 100, 110, 150},
    }
    gridLabels_[index] = symbolLabel

    local subLabel = UI.Label {
        text = ArtifactCh4.GRID_ELEMENTS[index],
        fontSize = 10,
        textAlign = "center",
        fontColor = {100, 100, 110, 120},
    }
    gridSubLabels_[index] = subLabel

    local cell = UI.Panel {
        position = "absolute",
        left = math.floor(cx),
        top = math.floor(cy),
        width = CELL_SIZE,
        height = CELL_SIZE,
        borderRadius = CELL_SIZE / 2,
        borderWidth = 2,
        borderColor = BORDER_LOCKED,
        backgroundColor = BG_NO_FRAGMENT,
        justifyContent = "center",
        alignItems = "center",
        gap = 1,
        onClick = function() OnGridCellClick(cellIndex) end,
        children = { symbolLabel, subLabel },
    }
    return cell
end

local function RefreshGridCell(index, cell)
    local activated = ArtifactCh4.IsGridActivated(index)
    local hasFragment = ArtifactCh4.GetFragmentCount(index) > 0
    local label = gridLabels_[index]
    local subLabel = gridSubLabels_[index]

    if activated then
        cell:SetStyle({
            backgroundColor = BG_ACTIVATED,
            borderColor = BORDER_ACTIVATED,
            borderWidth = 2,
        })
        if label then label:SetStyle({ fontColor = COLOR_BAGUA_ACTIVE, fontSize = 24 }) end
        if subLabel then subLabel:SetStyle({ fontColor = {120, 190, 255, 200} }) end
    elseif hasFragment then
        cell:SetStyle({
            backgroundColor = BG_HAS_FRAGMENT,
            borderColor = BORDER_CAN_ACTIVATE,
            borderWidth = 2,
        })
        if label then label:SetStyle({ fontColor = COLOR_GOLD, fontSize = 22 }) end
        if subLabel then subLabel:SetStyle({ fontColor = {200, 180, 100, 180} }) end
    else
        cell:SetStyle({
            backgroundColor = BG_NO_FRAGMENT,
            borderColor = BORDER_LOCKED,
            borderWidth = 1,
        })
        if label then label:SetStyle({ fontColor = {100, 100, 110, 150}, fontSize = 22 }) end
        if subLabel then subLabel:SetStyle({ fontColor = {100, 100, 110, 120} }) end
    end
end

-- ============================================================================
-- 创建面板
-- ============================================================================

function ArtifactUI_ch4.Create(parentOverlay)
    if panel_ then return end
    parentOverlay_ = parentOverlay

    EventBus.On("artifact_ch4_boss_defeated", function()
        ArtifactUI_ch4.ShowVictory()
    end)
    gridCells_ = {}
    gridLabels_ = {}
    gridSubLabels_ = {}

    -- 构建8个卦位
    local diskChildren = {}
    for i = 1, ArtifactCh4.GRID_COUNT do
        local cell = CreateGridCell(i)
        gridCells_[i] = cell
        table.insert(diskChildren, cell)
    end

    -- 中心太极
    centerTaiji_ = UI.Label {
        text = "☯",
        fontSize = 36,
        textAlign = "center",
        fontColor = {150, 150, 160, 200},
    }
    table.insert(diskChildren, UI.Panel {
        position = "absolute",
        left = math.floor(DISK_SIZE / 2 - CENTER_SIZE / 2),
        top = math.floor(DISK_SIZE / 2 - CENTER_SIZE / 2),
        width = CENTER_SIZE,
        height = CENTER_SIZE,
        borderRadius = CENTER_SIZE / 2,
        backgroundColor = {0, 0, 0, 0},
        borderWidth = 1,
        borderColor = {80, 150, 220, 80},
        justifyContent = "center",
        alignItems = "center",
        children = { centerTaiji_ },
    })

    -- 属性信息
    infoLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {200, 200, 210, 255},
        textAlign = "center",
    }

    -- 费用提示
    costLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = {150, 150, 160, 255},
        textAlign = "center",
    }

    -- ── 被动技能详情（增强版） ──
    local passive = ArtifactCh4.PASSIVE
    passiveTitle_ = UI.Label {
        text = "☯ 被动技能「" .. passive.name .. "」",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = COLOR_PASSIVE_OFF,
        textAlign = "center",
    }
    passiveStatus_ = UI.Label {
        text = "未激活",
        fontSize = T.fontSize.xs,
        fontWeight = "bold",
        fontColor = {255, 100, 100, 200},
        textAlign = "center",
    }
    passiveDesc_ = UI.Label {
        text = passive.desc,
        fontSize = T.fontSize.xs,
        fontColor = {180, 180, 190, 200},
        textAlign = "center",
    }
    -- 详细参数行
    passiveDetail_ = UI.Panel {
        flexDirection = "row",
        gap = 6,
        flexWrap = "wrap",
        justifyContent = "center",
        children = {
            UI.Label {
                text = string.format("护盾 = 防御×%d", passive.shieldMultiplier),
                fontSize = T.fontSize.xs,
                fontColor = {100, 180, 220, 200},
            },
            UI.Label {
                text = string.format("刷新 %ds", passive.refreshInterval),
                fontSize = T.fontSize.xs,
                fontColor = {150, 200, 150, 200},
            },
        },
    }
    -- 护盾状态
    shieldLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontWeight = "bold",
        fontColor = {100, 200, 255, 220},
        textAlign = "center",
        visible = false,
    }
    passiveContainer_ = UI.Panel {
        width = "100%",
        backgroundColor = {15, 30, 50, 180},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = {80, 150, 220, 40},
        padding = T.spacing.sm,
        gap = 4,
        alignItems = "center",
        children = {
            passiveTitle_,
            passiveStatus_,
            passiveDesc_,
            passiveDetail_,
            shieldLabel_,
        },
    }

    -- BOSS战按钮
    actionBtn_ = UI.Button {
        text = "唤醒八卦盘",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = COLOR_GOLD_DIM,
        visible = false,
        onClick = function() ArtifactUI_ch4.OnActionClick() end,
    }

    -- ── 确认弹窗 ──
    confirmGridName_ = UI.Label {
        text = "",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = {230, 230, 240, 255},
        textAlign = "center",
    }
    confirmCostGold_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {255, 215, 100, 255},
    }
    confirmCostLY_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {150, 180, 255, 255},
    }
    confirmCostFrag_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {180, 140, 255, 255},
    }
    confirmFeedback_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = {255, 100, 100, 255},
        textAlign = "center",
        visible = false,
    }
    local bonusB = ArtifactCh4.PER_GRID_BONUS
    confirmPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 200,
        onClick = function() ArtifactUI_ch4.HideConfirm() end,
        children = {
            UI.Panel {
                width = 260,
                backgroundColor = {20, 30, 50, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {80, 150, 220, 100},
                paddingTop = 14, paddingBottom = 14,
                paddingLeft = 18, paddingRight = 18,
                gap = 10,
                alignItems = "center",
                onClick = function() end,
                children = {
                    UI.Label {
                        text = "确认激活",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = COLOR_BAGUA_ACTIVE,
                        textAlign = "center",
                    },
                    UI.Panel { height = 1, width = "90%", backgroundColor = {80, 150, 220, 40} },
                    confirmGridName_,
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {10, 20, 35, 180},
                        borderRadius = 6,
                        padding = 10,
                        gap = 6,
                        children = {
                            UI.Label { text = "消耗", fontSize = T.fontSize.xs, fontColor = {160, 160, 170, 255} },
                            confirmCostGold_,
                            confirmCostLY_,
                            confirmCostFrag_,
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {10, 20, 35, 180},
                        borderRadius = 6,
                        padding = 10,
                        gap = 4,
                        children = {
                            UI.Label { text = "每格加成", fontSize = T.fontSize.xs, fontColor = {160, 160, 170, 255} },
                            UI.Panel {
                                flexDirection = "row",
                                gap = 8,
                                flexWrap = "wrap",
                                children = {
                                    UI.Label {
                                        text = string.format("悟性 +%d", bonusB.wisdom),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {100, 200, 255, 255},
                                    },
                                    UI.Label {
                                        text = string.format("福源 +%d", bonusB.fortune),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {255, 220, 100, 255},
                                    },
                                    UI.Label {
                                        text = string.format("防御 +%d", bonusB.defense),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {100, 220, 160, 255},
                                    },
                                },
                            },
                        },
                    },
                    confirmFeedback_,
                    UI.Panel {
                        flexDirection = "row",
                        gap = 12,
                        justifyContent = "center",
                        marginTop = 4,
                        children = {
                            UI.Button {
                                text = "取消",
                                width = 96,
                                height = T.size.dialogBtnH,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {70, 70, 80, 220},
                                onClick = function() ArtifactUI_ch4.HideConfirm() end,
                            },
                            UI.Button {
                                text = "激活",
                                width = 96,
                                height = T.size.dialogBtnH,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = {60, 130, 200, 255},
                                onClick = function() DoConfirmActivate() end,
                            },
                        },
                    },
                },
            },
        },
    }

    -- 组装内容面板
    local contentPanel = UI.Panel {
        width = "100%",
        padding = T.spacing.md,
        gap = T.spacing.sm,
        alignItems = "center",
        children = {
            -- 副标题
            UI.Label {
                text = "文王拘而演周易·后天八卦护身宝器",
                fontSize = T.fontSize.sm,
                fontColor = {120, 140, 170, 255},
                textAlign = "center",
            },
            -- 八卦圆盘区域
            UI.Panel {
                width = DISK_SIZE,
                height = DISK_SIZE,
                alignSelf = "center",
                borderRadius = DISK_SIZE / 2,
                overflow = "hidden",
                backgroundImage = ArtifactCh4.FULL_IMAGE,
                backgroundFit = "fill",
                borderWidth = 2,
                borderColor = {60, 100, 160, 100},
                children = diskChildren,
            },
            -- 费用提示
            costLabel_,
            -- 属性加成信息
            infoLabel_,
            -- 被动技能详情（增强版）
            passiveContainer_,
            -- BOSS战按钮
            actionBtn_,
            -- 确认弹窗
            confirmPanel_,
        },
    }

    -- 弹窗外壳
    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = T.color.overlay,
        zIndex = 900,
        visible = false,
        onClick = function() ArtifactUI_ch4.Hide() end,
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                maxHeight = "90%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {80, 150, 220, 60},
                overflow = "scroll",
                onClick = function() end,
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        paddingTop = T.spacing.sm,
                        paddingLeft = T.spacing.md,
                        paddingRight = T.spacing.sm,
                        children = {
                            UI.Label {
                                text = "☯ 文王八卦盘",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = T.color.titleText,
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function() ArtifactUI_ch4.Hide() end,
                            },
                        },
                    },
                    contentPanel,
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)

    -- 立即刷新数据
    ArtifactUI_ch4.Refresh()
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function ArtifactUI_ch4.Show()
    if not panel_ then return end
    if visible_ then return end
    visible_ = true
    ArtifactUI_ch4.Refresh()
    panel_:Show()
    GameState.uiOpen = "artifact_ch4"
end

function ArtifactUI_ch4.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    ArtifactUI_ch4.HideConfirm()
    if GameState.uiOpen == "artifact_ch4" then
        GameState.uiOpen = nil
    end
end

function ArtifactUI_ch4.Toggle()
    if visible_ then ArtifactUI_ch4.Hide() else ArtifactUI_ch4.Show() end
end

function ArtifactUI_ch4.IsVisible()
    return visible_
end

-- ============================================================================
-- 更新
-- ============================================================================

function ArtifactUI_ch4.Update(dt)
    if feedbackTimer_ and feedbackTimer_ > 0 then
        feedbackTimer_ = feedbackTimer_ - dt
        if feedbackTimer_ <= 0 then
            feedbackTimer_ = nil
            ArtifactUI_ch4.Refresh()
        end
    end
    if confirmCloseTimer_ and confirmCloseTimer_ > 0 then
        confirmCloseTimer_ = confirmCloseTimer_ - dt
        if confirmCloseTimer_ <= 0 then
            confirmCloseTimer_ = nil
            ArtifactUI_ch4.HideConfirm()
        end
    end
end

-- ============================================================================
-- 刷新显示
-- ============================================================================

function ArtifactUI_ch4.Refresh()
    local count = ArtifactCh4.GetActivatedCount()

    -- 刷新八卦格
    for i = 1, ArtifactCh4.GRID_COUNT do
        if gridCells_[i] then
            RefreshGridCell(i, gridCells_[i])
        end
    end

    -- 中心太极颜色
    if centerTaiji_ then
        if count >= ArtifactCh4.GRID_COUNT then
            centerTaiji_:SetStyle({ fontColor = COLOR_BAGUA_ACTIVE, fontSize = 40 })
        elseif count > 0 then
            centerTaiji_:SetStyle({ fontColor = {120, 150, 180, 220}, fontSize = 36 })
        else
            centerTaiji_:SetStyle({ fontColor = {150, 150, 160, 200}, fontSize = 36 })
        end
    end

    -- 属性加成
    local wis, fort, def = ArtifactCh4.GetCurrentBonus()
    if infoLabel_ then
        if count > 0 then
            infoLabel_:SetText(string.format("已激活 %d/%d  |  悟性+%d  福源+%d  防御+%d",
                count, ArtifactCh4.GRID_COUNT, wis, fort, def))
        else
            infoLabel_:SetText("点击卦位激活 · 每格需碎片+500万金+1000灵韵")
        end
    end

    -- 费用提示
    if costLabel_ then
        if count < ArtifactCh4.GRID_COUNT then
            costLabel_:SetText("激活费用：" .. ArtifactCh4.FormatGold(ArtifactCh4.ACTIVATE_GOLD_COST)
                .. "金币 + " .. ArtifactCh4.ACTIVATE_LINGYUN_COST .. "灵韵 + 对应卦象碎片")
        elseif not ArtifactCh4.bossDefeated then
            costLabel_:SetText("八卦已满，可唤醒八卦盘")
        else
            costLabel_:SetText("八卦盘已完全觉醒")
        end
    end

    -- 护盾状态
    if shieldLabel_ then
        if ArtifactCh4.passiveUnlocked then
            local cur, max = ArtifactCh4.GetShieldStatus()
            shieldLabel_:SetText(string.format("护盾：%d / %d", math.floor(cur), math.floor(max)))
            shieldLabel_:SetVisible(true)
        else
            shieldLabel_:SetVisible(false)
        end
    end

    -- 被动技能详情
    ArtifactUI_ch4.RefreshPassive()
    ArtifactUI_ch4.RefreshActionButton()
end

--- 刷新被动技能详情
function ArtifactUI_ch4.RefreshPassive()
    if not passiveContainer_ then return end

    local count = ArtifactCh4.GetActivatedCount()

    if ArtifactCh4.passiveUnlocked then
        -- ✅ 已激活
        passiveContainer_:SetStyle({
            borderColor = {80, 180, 255, 220},
            borderWidth = 2,
            backgroundColor = {15, 40, 70, 240},
        })
        if passiveTitle_ then passiveTitle_:SetStyle({ fontColor = COLOR_PASSIVE_ON }) end
        if passiveStatus_ then
            passiveStatus_:SetText("已激活")
            passiveStatus_:SetStyle({ fontColor = {100, 255, 150, 255} })
        end
        if passiveDesc_ then passiveDesc_:SetStyle({ fontColor = {150, 210, 255, 255} }) end
        if passiveDetail_ then passiveDetail_:SetVisible(true) end
    elseif count >= ArtifactCh4.GRID_COUNT and not ArtifactCh4.bossDefeated then
        -- ⚡ 可觉醒
        passiveContainer_:SetStyle({
            borderColor = {80, 150, 220, 100},
            borderWidth = 1,
            backgroundColor = {15, 35, 55, 200},
        })
        if passiveTitle_ then passiveTitle_:SetStyle({ fontColor = COLOR_NEXT }) end
        if passiveStatus_ then
            passiveStatus_:SetText("待觉醒 - 击败BOSS后激活")
            passiveStatus_:SetStyle({ fontColor = {100, 180, 220, 255} })
        end
        if passiveDesc_ then passiveDesc_:SetStyle({ fontColor = {180, 180, 190, 200} }) end
        if passiveDetail_ then passiveDetail_:SetVisible(true) end
    else
        -- 🔒 未激活
        passiveContainer_:SetStyle({
            borderColor = {80, 150, 220, 40},
            borderWidth = 1,
            backgroundColor = {15, 30, 50, 180},
        })
        if passiveTitle_ then passiveTitle_:SetStyle({ fontColor = COLOR_PASSIVE_OFF }) end
        if passiveStatus_ then
            passiveStatus_:SetText(string.format("未激活 (%d/%d 卦位)", count, ArtifactCh4.GRID_COUNT))
            passiveStatus_:SetStyle({ fontColor = {255, 100, 100, 200} })
        end
        if passiveDesc_ then passiveDesc_:SetStyle({ fontColor = {140, 140, 150, 180} }) end
        if passiveDetail_ then passiveDetail_:SetVisible(false) end
    end
end

function ArtifactUI_ch4.RefreshActionButton()
    if not actionBtn_ then return end
    local count = ArtifactCh4.GetActivatedCount()

    if count >= ArtifactCh4.GRID_COUNT and not ArtifactCh4.bossDefeated then
        actionBtn_:SetVisible(true)
        local canFight = ArtifactCh4.CanFightBoss()
        actionBtn_:SetText("唤醒八卦盘")
        actionBtn_:SetStyle({ backgroundColor = canFight and {60, 130, 200, 255} or {80, 80, 90, 200} })
    elseif ArtifactCh4.bossDefeated then
        actionBtn_:SetVisible(true)
        actionBtn_:SetText("✦ 八卦盘已觉醒 ✦")
        actionBtn_:SetStyle({ backgroundColor = {40, 120, 160, 200} })
    else
        actionBtn_:SetVisible(false)
    end
end

-- ============================================================================
-- 操作处理
-- ============================================================================

function ArtifactUI_ch4.OnActionClick()
    local count = ArtifactCh4.GetActivatedCount()
    if count >= ArtifactCh4.GRID_COUNT and not ArtifactCh4.bossDefeated then
        local canFight, reason = ArtifactCh4.CanFightBoss()
        if canFight then
            ArtifactUI_ch4.Hide()
            ArtifactUI_ch4._pendingBossFight = true
        else
            local CombatSystem = require("systems.CombatSystem")
            local player = GameState.player
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 0.5, reason, {255, 100, 100, 255}, 2.0)
            end
        end
    end
end

---@param gameMap table
---@param camera table
---@return boolean
function ArtifactUI_ch4.TryStartPendingBossFight(gameMap, camera)
    if not ArtifactUI_ch4._pendingBossFight then return false end
    ArtifactUI_ch4._pendingBossFight = false
    local success, msg = ArtifactCh4.EnterBossArena(gameMap, camera)
    if not success then
        local CombatSystem = require("systems.CombatSystem")
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg, {255, 100, 100, 255}, 2.0)
        end
    end
    return success
end

-- ============================================================================
-- 觉醒成功弹窗
-- ============================================================================

function ArtifactUI_ch4.ShowVictory()
    if victoryPanel_ then return end
    if not parentOverlay_ then return end

    local passive = ArtifactCh4.PASSIVE
    victoryPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 200},
        justifyContent = "center",
        alignItems = "center",
        zIndex = 300,
        children = {
            UI.Panel {
                width = 280,
                backgroundColor = {15, 25, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = {80, 180, 255, 180},
                paddingTop = 20, paddingBottom = 16,
                paddingLeft = 20, paddingRight = 20,
                gap = 12,
                alignItems = "center",
                onClick = function() end,
                children = {
                    UI.Label {
                        text = "☯",
                        fontSize = 56,
                        fontColor = COLOR_BAGUA_ACTIVE,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "八卦盘觉醒",
                        fontSize = T.fontSize.xl or 22,
                        fontWeight = "bold",
                        fontColor = COLOR_BAGUA_ACTIVE,
                        textAlign = "center",
                    },
                    UI.Panel { height = 1, width = "80%", backgroundColor = {80, 180, 255, 60} },
                    UI.Label {
                        text = "文王八卦盘已完全觉醒！",
                        fontSize = T.fontSize.md,
                        fontColor = {230, 230, 240, 255},
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {15, 40, 60, 230},
                        borderRadius = 6,
                        borderWidth = 1,
                        borderColor = {80, 180, 255, 100},
                        padding = 10,
                        gap = 4,
                        children = {
                            UI.Label { text = "解锁被动技能", fontSize = T.fontSize.xs, fontColor = {180, 180, 190, 200} },
                            UI.Label {
                                text = passive.name,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                fontColor = COLOR_BAGUA_ACTIVE,
                            },
                            UI.Label {
                                text = passive.desc,
                                fontSize = T.fontSize.sm,
                                fontColor = {180, 210, 240, 230},
                            },
                        },
                    },
                    UI.Button {
                        text = "确认",
                        width = 120,
                        height = T.size.dialogBtnH,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        borderRadius = T.radius.md,
                        backgroundColor = {60, 130, 200, 255},
                        marginTop = 4,
                        onClick = function() ArtifactUI_ch4.HideVictory() end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(victoryPanel_)
    GameState.uiOpen = "artifact_ch4_victory"
end

function ArtifactUI_ch4.HideVictory()
    if victoryPanel_ then
        victoryPanel_:SetVisible(false)
        victoryPanel_ = nil
    end
    if GameState.uiOpen == "artifact_ch4_victory" then
        GameState.uiOpen = nil
    end
end

-- ============================================================================
-- 销毁
-- ============================================================================

function ArtifactUI_ch4.Destroy()
    gridCells_ = {}
    gridLabels_ = {}
    gridSubLabels_ = {}
    infoLabel_ = nil
    actionBtn_ = nil
    costLabel_ = nil
    shieldLabel_ = nil
    confirmPanel_ = nil
    confirmGridName_ = nil
    confirmCostGold_ = nil
    confirmCostLY_ = nil
    confirmCostFrag_ = nil
    confirmFeedback_ = nil
    confirmCloseTimer_ = nil
    pendingIndex_ = nil
    feedbackTimer_ = nil
    passiveContainer_ = nil
    passiveTitle_ = nil
    passiveStatus_ = nil
    passiveDesc_ = nil
    passiveDetail_ = nil
    ArtifactUI_ch4._pendingBossFight = false
    victoryPanel_ = nil
    centerTaiji_ = nil
    panel_ = nil
    visible_ = false
    parentOverlay_ = nil
end

return ArtifactUI_ch4
