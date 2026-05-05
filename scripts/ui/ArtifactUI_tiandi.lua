-- ============================================================================
-- ArtifactUI_tiandi.lua - 天帝剑痕神器面板（3×3九宫格拼图）
-- 独立弹窗，由 NPCDialog 管理
-- 完整神器图作为背景，格子覆盖在上面
-- 激活格子 = 透明（露出图片），未激活 = 深色遮罩
-- 格子 4-9：待解锁（后续战场实装后追加）
-- BOSS战和被动：暂未实现
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ArtifactTiandi = require("systems.ArtifactSystem_tiandi")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local FormatUtils = require("utils.FormatUtils")

local ArtifactUI_tiandi = {}

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil

local gridCells_ = {}       -- 九宫格格子引用
local gridLabels_ = {}      -- 九宫格中心文字引用
local infoLabel_ = nil      -- 属性信息
local costLabel_ = nil      -- 费用提示Label
local confirmPanel_ = nil   -- 确认弹窗
local confirmGridName_ = nil
local confirmCostGold_ = nil
local confirmCostLY_ = nil
local confirmCostFrag_ = nil
local confirmFeedback_ = nil
local confirmCloseTimer_ = nil
local pendingIndex_ = nil

-- ============================================================================
-- 颜色常量（金红剑痕主题）
-- ============================================================================

local COLOR_GOLD        = {255, 215, 0, 255}
local COLOR_GOLD_DIM    = {180, 130, 40, 255}
local COLOR_RED_ACCENT  = {220, 80, 40, 255}
local COLOR_PENDING     = {90, 80, 70, 200}

-- 格子遮罩色（纯黑压暗，让底部神器图片透出来，不产生色偏）
local MASK_ACTIVATED    = {0, 0, 0, 0}    -- 已激活：完全透明，图片原色
local MASK_HAS_FRAGMENT = {0, 0, 0, 20}   -- 有碎片：极轻压暗，图片原色近似
local MASK_NO_FRAGMENT  = {0, 0, 0, 55}   -- 无碎片：轻度压暗，图片清晰
local MASK_LOCKED       = {0, 0, 0, 100}  -- 锁定格：中度压暗，图片可辨

-- 格子边框色
local BORDER_ACTIVATED    = {80, 220, 100, 255}
local BORDER_CAN_ACTIVATE = {255, 200, 50, 255}
local BORDER_LOCKED       = {50, 40, 40, 120}
local BORDER_PENDING      = {60, 50, 40, 80}

-- 拼图区域尺寸
local GRID_WIDTH  = 240
local GRID_HEIGHT = 350
local GRID_GAP = 2
local CELL_W = math.floor((GRID_WIDTH  - GRID_GAP * 2) / 3)
local CELL_H = math.floor((GRID_HEIGHT - GRID_GAP * 2) / 3)

-- ============================================================================
-- 工具函数
-- ============================================================================

local FormatGold = FormatUtils.Gold

local function GetFragmentCount(index)
    local player = GameState.player
    if not player or not player.inventory then return 0 end
    local fragId = ArtifactTiandi.FRAGMENT_IDS[index]
    if not fragId then return 0 end
    return player.inventory[fragId] or 0
end

-- ============================================================================
-- 确认弹窗
-- ============================================================================

local function ShowConfirmDialog(index)
    if not confirmPanel_ then return end
    pendingIndex_ = index
    local gridName = ArtifactTiandi.GRID_NAMES[index]
    if confirmGridName_ then
        confirmGridName_:SetText(string.format("激活「%s」格", gridName))
    end
    if confirmCostGold_ then
        confirmCostGold_:SetText(string.format("金币  %s", FormatGold(ArtifactTiandi.ACTIVATE_GOLD_COST)))
    end
    if confirmCostLY_ then
        confirmCostLY_:SetText(string.format("灵韵  %d", ArtifactTiandi.ACTIVATE_LINGYUN_COST))
    end
    if confirmCostFrag_ then
        local fragCfg = GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[ArtifactTiandi.FRAGMENT_IDS[index]]
        local fragName = fragCfg and fragCfg.name or ("天帝剑痕碎片·" .. gridName)
        confirmCostFrag_:SetText("碎片  " .. fragName)
    end
    if confirmFeedback_ then
        confirmFeedback_:SetText("")
        confirmFeedback_:SetVisible(false)
    end
    confirmCloseTimer_ = nil
    confirmPanel_:Show()
end

function ArtifactUI_tiandi.HideConfirm()
    if confirmPanel_ then confirmPanel_:Hide() end
    confirmCloseTimer_ = nil
    pendingIndex_ = nil
end

local function DoConfirmActivate()
    local index = pendingIndex_
    if not index then return end
    local success, msg = ArtifactTiandi.ActivateGrid(index)
    if confirmFeedback_ then
        confirmFeedback_:SetText(msg)
        confirmFeedback_:SetStyle({
            fontColor = success and {100, 255, 150, 255} or {255, 100, 100, 255},
        })
        confirmFeedback_:SetVisible(true)
    end
    if success then
        ArtifactUI_tiandi.Refresh()
        confirmCloseTimer_ = 1.0
    end
end

-- ============================================================================
-- 格子渲染
-- ============================================================================

local function OnGridCellClick(index)
    -- 格子 4-9 暂未实现（待解锁）
    if index > ArtifactTiandi.GRID_COUNT then return end
    if ArtifactTiandi.activatedGrids[index] then return end
    ShowConfirmDialog(index)
end

local function CreateGridCell(index)
    local cellIndex = index
    local centerLabel = UI.Label {
        text = index <= ArtifactTiandi.GRID_COUNT and "🔒" or "···",
        fontSize = index <= ArtifactTiandi.GRID_COUNT and 18 or 12,
        textAlign = "center",
    }
    gridLabels_[index] = centerLabel
    local cell = UI.Panel {
        width = CELL_W,
        height = CELL_H,
        borderWidth = 1,
        borderColor = index <= ArtifactTiandi.GRID_COUNT and BORDER_LOCKED or BORDER_PENDING,
        backgroundColor = index <= ArtifactTiandi.GRID_COUNT and MASK_NO_FRAGMENT or MASK_LOCKED,
        justifyContent = "center",
        alignItems = "center",
        onClick = function() OnGridCellClick(cellIndex) end,
        children = { centerLabel },
    }
    return cell
end

local function RefreshGridCell(index, cell)
    local label = gridLabels_[index]

    -- 格子 4-9：待解锁状态（不可操作）
    if index > ArtifactTiandi.GRID_COUNT then
        cell:SetStyle({
            backgroundColor = MASK_LOCKED,
            borderColor = BORDER_PENDING,
        })
        if label then
            label:SetText("···")
            label:SetStyle({ fontColor = {70, 60, 50, 140}, fontSize = 12 })
        end
        return
    end

    local activated = ArtifactTiandi.activatedGrids[index]
    local hasFragment = GetFragmentCount(index) > 0

    if activated then
        cell:SetStyle({
            backgroundColor = MASK_ACTIVATED,
            borderColor = BORDER_ACTIVATED,
        })
        if label then
            label:SetText("✓")
            label:SetStyle({ fontColor = {80, 255, 120, 200}, fontSize = 18 })
        end
    elseif hasFragment then
        cell:SetStyle({
            backgroundColor = MASK_HAS_FRAGMENT,
            borderColor = BORDER_CAN_ACTIVATE,
        })
        if label then
            label:SetText("⚡")
            label:SetStyle({ fontColor = COLOR_GOLD, fontSize = 18 })
        end
    else
        cell:SetStyle({
            backgroundColor = MASK_NO_FRAGMENT,
            borderColor = BORDER_LOCKED,
        })
        if label then
            label:SetText("🔒")
            label:SetStyle({ fontColor = {100, 80, 70, 150}, fontSize = 18 })
        end
    end
end

-- ============================================================================
-- 创建面板
-- ============================================================================

function ArtifactUI_tiandi.Create(parentOverlay)
    if panel_ then return end
    parentOverlay_ = parentOverlay

    -- 构建 3×3 九宫格（9格全部渲染，4-9为待解锁灰色）
    local gridRows = {}
    gridCells_ = {}
    gridLabels_ = {}
    for row = 1, 3 do
        local rowChildren = {}
        for col = 1, 3 do
            local index = (row - 1) * 3 + col
            local cell = CreateGridCell(index)
            gridCells_[index] = cell
            table.insert(rowChildren, cell)
        end
        table.insert(gridRows, UI.Panel {
            flexDirection = "row",
            gap = GRID_GAP,
            justifyContent = "center",
            children = rowChildren,
        })
    end

    -- 属性信息
    infoLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {200, 190, 180, 255},
        textAlign = "center",
    }

    -- 费用提示
    costLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = {150, 140, 130, 255},
        textAlign = "center",
    }

    -- 神器特效预览（提前展示，功能待实装）
    local pendingHint = UI.Panel {
        width = "100%",
        gap = 6,
        children = {
            UI.Label {
                text = "── 神器觉醒特效 ──",
                fontSize = T.fontSize.xs,
                fontColor = {120, 110, 90, 180},
                textAlign = "center",
                marginTop = 4,
            },
            -- BOSS战预览卡
            UI.Panel {
                width = "100%",
                backgroundColor = {35, 18, 12, 200},
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = {180, 80, 40, 100},
                padding = 10,
                gap = 4,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "🔥 BOSS战 · 天帝之怒",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = {220, 120, 60, 220},
                            },
                            UI.Label {
                                text = "🔒 9格满开启",
                                fontSize = T.fontSize.xs,
                                fontColor = {130, 100, 80, 180},
                            },
                        },
                    },
                    UI.Label {
                        text = "挑战封魔谷镇守之灵，胜利方可解锁神器被动",
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 120, 90, 180},
                    },
                    UI.Label {
                        text = "[ 功能待实装 ]",
                        fontSize = T.fontSize.xs,
                        fontColor = {110, 90, 70, 140},
                    },
                },
            },
            -- 被动技能预览卡
            UI.Panel {
                width = "100%",
                backgroundColor = {18, 12, 30, 200},
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = {120, 80, 220, 100},
                padding = 10,
                gap = 4,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "⚡ 被动 · 天帝剑斩",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = {200, 160, 255, 220},
                            },
                            UI.Label {
                                text = "🔒 击败BOSS解锁",
                                fontSize = T.fontSize.xs,
                                fontColor = {130, 100, 160, 180},
                            },
                        },
                    },
                    UI.Label {
                        text = "暴击时，降低所有技能冷却时间 1.5 秒",
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 130, 200, 180},
                    },
                    UI.Label {
                        text = "[ 功能待实装 ]",
                        fontSize = T.fontSize.xs,
                        fontColor = {110, 90, 130, 140},
                    },
                },
            },
        },
    }

    -- ── 确认弹窗 ──
    confirmGridName_ = UI.Label {
        text = "",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = {230, 220, 200, 255},
        textAlign = "center",
    }
    confirmCostGold_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {255, 210, 80, 255},
    }
    confirmCostLY_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {150, 180, 255, 255},
    }
    confirmCostFrag_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {220, 160, 80, 255},
    }
    confirmFeedback_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = {255, 100, 100, 255},
        textAlign = "center",
        visible = false,
    }
    local bonusB = ArtifactTiandi.PER_GRID_BONUS
    confirmPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 200,
        onClick = function() ArtifactUI_tiandi.HideConfirm() end,
        children = {
            UI.Panel {
                width = 260,
                backgroundColor = {38, 30, 22, 252},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 160, 40, 100},
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
                        fontColor = COLOR_GOLD,
                        textAlign = "center",
                    },
                    UI.Panel { height = 1, width = "90%", backgroundColor = {255, 160, 40, 40} },
                    confirmGridName_,
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {20, 15, 10, 180},
                        borderRadius = 6,
                        padding = 10,
                        gap = 6,
                        children = {
                            UI.Label { text = "消耗", fontSize = T.fontSize.xs, fontColor = {160, 150, 140, 255} },
                            confirmCostGold_,
                            confirmCostLY_,
                            confirmCostFrag_,
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {20, 15, 10, 180},
                        borderRadius = 6,
                        padding = 10,
                        gap = 4,
                        children = {
                            UI.Label { text = "每格加成", fontSize = T.fontSize.xs, fontColor = {160, 150, 140, 255} },
                            UI.Panel {
                                flexDirection = "row",
                                gap = 8,
                                flexWrap = "wrap",
                                children = {
                                    UI.Label {
                                        text = string.format("攻击 +%g", bonusB.atk),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {255, 160, 80, 255},
                                    },
                                    UI.Label {
                                        text = string.format("击杀回血 +%g", bonusB.killHeal),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {100, 220, 160, 255},
                                    },
                                    UI.Label {
                                        text = string.format("生命回复 +%g/s", bonusB.hpRegen),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {100, 180, 255, 255},
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
                                backgroundColor = {70, 60, 50, 220},
                                onClick = function() ArtifactUI_tiandi.HideConfirm() end,
                            },
                            UI.Button {
                                text = "激活",
                                width = 96,
                                height = T.size.dialogBtnH,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = {210, 130, 30, 255},
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
                text = "上古天帝以无上剑意斩破虚空所留之痕",
                fontSize = T.fontSize.sm,
                fontColor = {160, 140, 110, 255},
                textAlign = "center",
            },
            -- 拼图区域：完整图片 + 格子覆盖
            UI.Panel {
                width = GRID_WIDTH,
                height = GRID_HEIGHT,
                alignSelf = "center",
                borderRadius = T.radius.md,
                overflow = "hidden",
                backgroundImage = ArtifactTiandi.FULL_IMAGE,
                backgroundFit = "fill",
                justifyContent = "center",
                alignItems = "center",
                gap = GRID_GAP,
                children = gridRows,
            },
            -- 费用提示
            costLabel_,
            -- 属性加成信息
            infoLabel_,
            -- 暂未实现提示
            pendingHint,
            -- 确认弹窗（绝对定位，覆盖在内容上方）
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
        onClick = function() ArtifactUI_tiandi.Hide() end,
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                maxHeight = "90%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 160, 40, 60},
                overflow = "scroll",
                onClick = function() end,  -- 阻止穿透
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
                                text = "⚔ 天帝剑痕",
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
                                backgroundColor = {60, 50, 45, 200},
                                onClick = function() ArtifactUI_tiandi.Hide() end,
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
    ArtifactUI_tiandi.Refresh()
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function ArtifactUI_tiandi.Show()
    if not panel_ then return end
    if visible_ then return end
    visible_ = true
    ArtifactUI_tiandi.Refresh()
    panel_:Show()
    GameState.uiOpen = "artifact_tiandi"
end

function ArtifactUI_tiandi.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    ArtifactUI_tiandi.HideConfirm()
    if GameState.uiOpen == "artifact_tiandi" then
        GameState.uiOpen = nil
    end
end

function ArtifactUI_tiandi.Toggle()
    if visible_ then ArtifactUI_tiandi.Hide() else ArtifactUI_tiandi.Show() end
end

function ArtifactUI_tiandi.IsVisible()
    return visible_
end

-- ============================================================================
-- 更新
-- ============================================================================

function ArtifactUI_tiandi.Update(dt)
    if confirmCloseTimer_ and confirmCloseTimer_ > 0 then
        confirmCloseTimer_ = confirmCloseTimer_ - dt
        if confirmCloseTimer_ <= 0 then
            confirmCloseTimer_ = nil
            ArtifactUI_tiandi.HideConfirm()
        end
    end
end

-- ============================================================================
-- 刷新显示
-- ============================================================================

function ArtifactUI_tiandi.Refresh()
    local count = ArtifactTiandi.GetActivatedCount()

    -- 刷新九宫格（全部9格）
    for i = 1, ArtifactTiandi.TOTAL_GRID_COUNT do
        if gridCells_[i] then
            RefreshGridCell(i, gridCells_[i])
        end
    end

    -- 属性加成
    local atk, killHeal, hpRegen = ArtifactTiandi.GetCurrentBonus()
    if infoLabel_ then
        if count > 0 then
            infoLabel_:SetText(string.format("已激活 %d/%d  |  攻击+%g  击杀回血+%g  生命回复+%g/s",
                count, ArtifactTiandi.GRID_COUNT, atk, killHeal, hpRegen))
        else
            infoLabel_:SetText("点击格子激活 · 每格需碎片+1000万金+2000灵韵")
        end
    end

    -- 费用提示
    if costLabel_ then
        if count < ArtifactTiandi.GRID_COUNT then
            costLabel_:SetText("激活费用：" .. FormatGold(ArtifactTiandi.ACTIVATE_GOLD_COST)
                .. "金币 + " .. ArtifactTiandi.ACTIVATE_LINGYUN_COST .. "灵韵 + 对应碎片")
        else
            costLabel_:SetText("仙劫战场三格已满")
        end
    end
end

-- ============================================================================
-- BOSS战（预留接口，当前无实现）
-- ============================================================================

function ArtifactUI_tiandi.TryStartPendingBossFight(gameMap, camera)
    return false
end

-- ============================================================================
-- 销毁
-- ============================================================================

function ArtifactUI_tiandi.Destroy()
    gridCells_ = {}
    gridLabels_ = {}
    infoLabel_ = nil
    costLabel_ = nil
    confirmPanel_ = nil
    confirmGridName_ = nil
    confirmCostGold_ = nil
    confirmCostLY_ = nil
    confirmCostFrag_ = nil
    confirmFeedback_ = nil
    confirmCloseTimer_ = nil
    pendingIndex_ = nil
    panel_ = nil
    visible_ = false
    parentOverlay_ = nil
end

return ArtifactUI_tiandi
