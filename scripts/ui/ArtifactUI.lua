-- ============================================================================
-- ArtifactUI.lua - 上宝逊金钯神器面板（3×3九宫格拼图）
-- 独立弹窗，由 NPCDialog 管理
-- 完整神器图作为背景，格子覆盖在上面
-- 激活格子 = 透明（露出图片），未激活 = 深色遮罩
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ArtifactSystem = require("systems.ArtifactSystem")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")

local ArtifactUI = {}

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil

local gridCells_ = {}       -- 九宫格格子引用
local gridLabels_ = {}      -- 九宫格中心文字引用
local infoLabel_ = nil      -- 属性信息
local actionBtn_ = nil      -- BOSS战按钮
local costLabel_ = nil      -- 费用提示Label
local confirmPanel_ = nil   -- 确认弹窗
local confirmGridName_ = nil
local confirmCostGold_ = nil
local confirmCostLY_ = nil
local confirmCostFrag_ = nil
local confirmFeedback_ = nil
local confirmCloseTimer_ = nil
local pendingIndex_ = nil
local victoryPanel_ = nil
local feedbackTimer_ = nil

-- 被动技能详情区域引用
local passiveContainer_ = nil
local passiveTitle_ = nil
local passiveStatus_ = nil
local passiveDesc_ = nil
local passiveDetail_ = nil

-- ============================================================================
-- 颜色常量
-- ============================================================================

local COLOR_GOLD        = {255, 215, 0, 255}
local COLOR_GOLD_DIM    = {180, 150, 60, 255}
local COLOR_PASSIVE_ON  = {255, 215, 0, 255}
local COLOR_PASSIVE_OFF = {120, 120, 130, 255}
local COLOR_NEXT        = {200, 160, 40, 255}

-- 格子遮罩色
local MASK_ACTIVATED    = {0, 0, 0, 0}
local MASK_HAS_FRAGMENT = {15, 15, 25, 170}
local MASK_NO_FRAGMENT  = {10, 10, 15, 225}

-- 格子边框色
local BORDER_ACTIVATED    = {80, 220, 100, 255}
local BORDER_CAN_ACTIVATE = {255, 215, 0, 255}
local BORDER_LOCKED       = {50, 50, 60, 120}

-- 拼图区域尺寸
local GRID_WIDTH  = 240
local GRID_HEIGHT = 350
local GRID_GAP = 2
local CELL_W = math.floor((GRID_WIDTH  - GRID_GAP * 2) / 3)
local CELL_H = math.floor((GRID_HEIGHT - GRID_GAP * 2) / 3)

-- ============================================================================
-- 确认弹窗
-- ============================================================================

local function ShowConfirmDialog(index)
    if not confirmPanel_ then return end
    pendingIndex_ = index
    local gridName = ArtifactSystem.GRID_NAMES[index]
    if confirmGridName_ then
        confirmGridName_:SetText(string.format("激活「%s」格", gridName))
    end
    if confirmCostGold_ then
        confirmCostGold_:SetText(string.format("金币  %s", ArtifactSystem.FormatGold(ArtifactSystem.ACTIVATE_GOLD_COST)))
    end
    if confirmCostLY_ then
        confirmCostLY_:SetText(string.format("灵韵  %d", ArtifactSystem.ACTIVATE_LINGYUN_COST))
    end
    if confirmCostFrag_ then
        local fragCfg = GameConfig.CONSUMABLES[ArtifactSystem.FRAGMENT_IDS[index]]
        local fragName = fragCfg and fragCfg.name or ("碎片·" .. ArtifactSystem.GRID_NAMES[index])
        confirmCostFrag_:SetText("碎片  " .. fragName)
    end
    if confirmFeedback_ then
        confirmFeedback_:SetText("")
        confirmFeedback_:SetVisible(false)
    end
    confirmCloseTimer_ = nil
    confirmPanel_:Show()
end

function ArtifactUI.HideConfirm()
    if confirmPanel_ then confirmPanel_:Hide() end
    confirmCloseTimer_ = nil
    pendingIndex_ = nil
end

local function DoConfirmActivate()
    local index = pendingIndex_
    if not index then return end
    local success, msg = ArtifactSystem.Activate(index)
    if confirmFeedback_ then
        confirmFeedback_:SetText(msg)
        confirmFeedback_:SetStyle({
            fontColor = success and {100, 255, 150, 255} or {255, 100, 100, 255},
        })
        confirmFeedback_:SetVisible(true)
    end
    if success then
        ArtifactUI.Refresh()
        confirmCloseTimer_ = 1.0
    end
end

-- ============================================================================
-- 格子渲染
-- ============================================================================

local function OnGridCellClick(index)
    if ArtifactSystem.IsGridActivated(index) then return end
    ShowConfirmDialog(index)
end

local function CreateGridCell(index)
    local cellIndex = index
    local centerLabel = UI.Label {
        text = "🔒",
        fontSize = 18,
        textAlign = "center",
    }
    gridLabels_[index] = centerLabel
    local cell = UI.Panel {
        width = CELL_W,
        height = CELL_H,
        borderWidth = 1,
        borderColor = BORDER_LOCKED,
        backgroundColor = MASK_NO_FRAGMENT,
        justifyContent = "center",
        alignItems = "center",
        onClick = function() OnGridCellClick(cellIndex) end,
        children = { centerLabel },
    }
    return cell
end

local function RefreshGridCell(index, cell)
    local activated = ArtifactSystem.IsGridActivated(index)
    local hasFragment = ArtifactSystem.GetFragmentCount(index) > 0
    local label = gridLabels_[index]

    if activated then
        cell:SetStyle({
            backgroundColor = MASK_ACTIVATED,
            borderColor = BORDER_ACTIVATED,
        })
        if label then
            label:SetText("✓")
            label:SetStyle({ fontColor = {80, 255, 120, 200} })
        end
    elseif hasFragment then
        cell:SetStyle({
            backgroundColor = MASK_HAS_FRAGMENT,
            borderColor = BORDER_CAN_ACTIVATE,
        })
        if label then
            label:SetText("⚡")
            label:SetStyle({ fontColor = COLOR_GOLD })
        end
    else
        cell:SetStyle({
            backgroundColor = MASK_NO_FRAGMENT,
            borderColor = BORDER_LOCKED,
        })
        if label then
            label:SetText("🔒")
            label:SetStyle({ fontColor = {100, 100, 110, 150} })
        end
    end
end

-- ============================================================================
-- 创建面板
-- ============================================================================

function ArtifactUI.Create(parentOverlay)
    if panel_ then return end
    parentOverlay_ = parentOverlay

    -- 监听BOSS击败事件 → 显示觉醒弹窗
    EventBus.On("artifact_boss_defeated", function()
        ArtifactUI.ShowVictory()
    end)
    -- 构建 3×3 九宫格
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

    -- ── 被动技能详情（增强版：显示激活/未激活状态 + 详细参数） ──
    local passive = ArtifactSystem.PASSIVE
    passiveTitle_ = UI.Label {
        text = "🔱 被动技能「" .. passive.name .. "」",
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
                text = string.format("触发率 %d%%", passive.chance * 100),
                fontSize = T.fontSize.xs,
                fontColor = {200, 180, 100, 200},
            },
            UI.Label {
                text = string.format("伤害 %d%%攻击力", passive.dmgMultiplier * 100),
                fontSize = T.fontSize.xs,
                fontColor = {255, 150, 100, 200},
            },
            UI.Label {
                text = string.format("冷却 %.0fs", passive.cooldown),
                fontSize = T.fontSize.xs,
                fontColor = {150, 180, 220, 200},
            },
        },
    }
    passiveContainer_ = UI.Panel {
        width = "100%",
        backgroundColor = {40, 35, 15, 180},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = {255, 215, 0, 40},
        padding = T.spacing.sm,
        gap = 4,
        alignItems = "center",
        children = {
            passiveTitle_,
            passiveStatus_,
            passiveDesc_,
            passiveDetail_,
        },
    }

    -- BOSS战按钮
    actionBtn_ = UI.Button {
        text = "唤醒神器",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = COLOR_GOLD_DIM,
        visible = false,
        onClick = function() ArtifactUI.OnActionClick() end,
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
    local bonusB = ArtifactSystem.PER_GRID_BONUS
    confirmPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 200,
        onClick = function() ArtifactUI.HideConfirm() end,
        children = {
            UI.Panel {
                width = 260,
                backgroundColor = {35, 37, 50, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 215, 0, 100},
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
                    UI.Panel { height = 1, width = "90%", backgroundColor = {255, 215, 0, 40} },
                    confirmGridName_,
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {20, 20, 30, 180},
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
                        backgroundColor = {20, 20, 30, 180},
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
                                        text = string.format("体魄 +%d", bonusB.physique),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {255, 220, 100, 255},
                                    },
                                    UI.Label {
                                        text = string.format("根骨 +%d", bonusB.constitution),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {100, 220, 160, 255},
                                    },
                                    UI.Label {
                                        text = string.format("重击值 +%d", bonusB.heavyHit),
                                        fontSize = T.fontSize.sm,
                                        fontColor = {255, 120, 100, 255},
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
                                onClick = function() ArtifactUI.HideConfirm() end,
                            },
                            UI.Button {
                                text = "激活",
                                width = 96,
                                height = T.size.dialogBtnH,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = {200, 160, 40, 255},
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
                text = "天蓬元帅旧兵器·上宝逊金钯",
                fontSize = T.fontSize.sm,
                fontColor = {160, 150, 120, 255},
                textAlign = "center",
            },
            -- 拼图区域：完整图片 + 格子覆盖
            UI.Panel {
                width = GRID_WIDTH,
                height = GRID_HEIGHT,
                alignSelf = "center",
                borderRadius = T.radius.md,
                overflow = "hidden",
                backgroundImage = ArtifactSystem.FULL_IMAGE,
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
            -- 被动技能详情（增强版）
            passiveContainer_,
            -- BOSS战按钮
            actionBtn_,
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
        onClick = function() ArtifactUI.Hide() end,
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                maxHeight = "90%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 215, 0, 60},
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
                                text = "⚔ 上宝逊金钯",
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
                                onClick = function() ArtifactUI.Hide() end,
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
    ArtifactUI.Refresh()
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function ArtifactUI.Show()
    if not panel_ then return end
    if visible_ then return end
    visible_ = true
    ArtifactUI.Refresh()
    panel_:Show()
    GameState.uiOpen = "artifact"
end

function ArtifactUI.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    ArtifactUI.HideConfirm()
    if GameState.uiOpen == "artifact" then
        GameState.uiOpen = nil
    end
end

function ArtifactUI.Toggle()
    if visible_ then ArtifactUI.Hide() else ArtifactUI.Show() end
end

function ArtifactUI.IsVisible()
    return visible_
end

-- ============================================================================
-- 更新
-- ============================================================================

function ArtifactUI.Update(dt)
    if feedbackTimer_ and feedbackTimer_ > 0 then
        feedbackTimer_ = feedbackTimer_ - dt
        if feedbackTimer_ <= 0 then
            feedbackTimer_ = nil
            ArtifactUI.Refresh()
        end
    end
    if confirmCloseTimer_ and confirmCloseTimer_ > 0 then
        confirmCloseTimer_ = confirmCloseTimer_ - dt
        if confirmCloseTimer_ <= 0 then
            confirmCloseTimer_ = nil
            ArtifactUI.HideConfirm()
        end
    end
end

-- ============================================================================
-- 刷新显示
-- ============================================================================

function ArtifactUI.Refresh()
    local count = ArtifactSystem.GetActivatedCount()

    -- 刷新九宫格
    for i = 1, ArtifactSystem.GRID_COUNT do
        if gridCells_[i] then
            RefreshGridCell(i, gridCells_[i])
        end
    end

    -- 属性加成
    local hh, con, fort = ArtifactSystem.GetCurrentBonus()
    if infoLabel_ then
        if count > 0 then
            infoLabel_:SetText(string.format("已激活 %d/%d  |  重击+%d  根骨+%d  体魄+%d",
                count, ArtifactSystem.GRID_COUNT, hh, con, fort))
        else
            infoLabel_:SetText("点击格子激活 · 每格需碎片+50万金+500灵韵")
        end
    end

    -- 费用提示
    if costLabel_ then
        if count < ArtifactSystem.GRID_COUNT then
            costLabel_:SetText("激活费用：" .. ArtifactSystem.FormatGold(ArtifactSystem.ACTIVATE_GOLD_COST)
                .. "金币 + " .. ArtifactSystem.ACTIVATE_LINGYUN_COST .. "灵韵 + 对应碎片")
        elseif not ArtifactSystem.bossDefeated then
            costLabel_:SetText("九格已满，可唤醒神器")
        else
            costLabel_:SetText("神兵已完全觉醒")
        end
    end

    -- 被动技能详情
    ArtifactUI.RefreshPassive()
    -- BOSS战按钮
    ArtifactUI.RefreshActionButton()
end

--- 刷新被动技能详情区域（增强版：激活/未激活状态 + 参数高亮）
function ArtifactUI.RefreshPassive()
    if not passiveContainer_ then return end

    local count = ArtifactSystem.GetActivatedCount()

    if ArtifactSystem.passiveUnlocked then
        -- ✅ 已激活 → 金色高亮
        passiveContainer_:SetStyle({
            borderColor = {255, 215, 0, 220},
            borderWidth = 2,
            backgroundColor = {60, 50, 10, 240},
        })
        if passiveTitle_ then
            passiveTitle_:SetStyle({ fontColor = COLOR_PASSIVE_ON })
        end
        if passiveStatus_ then
            passiveStatus_:SetText("已激活")
            passiveStatus_:SetStyle({ fontColor = {100, 255, 150, 255} })
        end
        if passiveDesc_ then
            passiveDesc_:SetStyle({ fontColor = {255, 230, 150, 255} })
        end
        if passiveDetail_ then passiveDetail_:SetVisible(true) end
    elseif count >= ArtifactSystem.GRID_COUNT and not ArtifactSystem.bossDefeated then
        -- ⚡ 可觉醒 → 预备状态
        passiveContainer_:SetStyle({
            borderColor = {200, 160, 40, 100},
            borderWidth = 1,
            backgroundColor = {45, 40, 15, 200},
        })
        if passiveTitle_ then
            passiveTitle_:SetStyle({ fontColor = COLOR_NEXT })
        end
        if passiveStatus_ then
            passiveStatus_:SetText("待觉醒 - 击败BOSS后激活")
            passiveStatus_:SetStyle({ fontColor = {200, 160, 40, 255} })
        end
        if passiveDesc_ then
            passiveDesc_:SetStyle({ fontColor = {180, 180, 190, 200} })
        end
        if passiveDetail_ then passiveDetail_:SetVisible(true) end
    else
        -- 🔒 未激活 → 灰色
        passiveContainer_:SetStyle({
            borderColor = {255, 215, 0, 40},
            borderWidth = 1,
            backgroundColor = {40, 35, 15, 180},
        })
        if passiveTitle_ then
            passiveTitle_:SetStyle({ fontColor = COLOR_PASSIVE_OFF })
        end
        if passiveStatus_ then
            passiveStatus_:SetText(string.format("未激活 (%d/%d 格)", count, ArtifactSystem.GRID_COUNT))
            passiveStatus_:SetStyle({ fontColor = {255, 100, 100, 200} })
        end
        if passiveDesc_ then
            passiveDesc_:SetStyle({ fontColor = {140, 140, 150, 180} })
        end
        if passiveDetail_ then passiveDetail_:SetVisible(false) end
    end
end

--- 刷新操作按钮
function ArtifactUI.RefreshActionButton()
    if not actionBtn_ then return end
    local count = ArtifactSystem.GetActivatedCount()

    if count >= ArtifactSystem.GRID_COUNT and not ArtifactSystem.bossDefeated then
        actionBtn_:SetVisible(true)
        local canFight = ArtifactSystem.CanFightBoss()
        actionBtn_:SetText("唤醒神器")
        actionBtn_:SetStyle({ backgroundColor = canFight and {220, 60, 60, 255} or {80, 80, 90, 200} })
    elseif ArtifactSystem.bossDefeated then
        actionBtn_:SetVisible(true)
        actionBtn_:SetText("✦ 神兵已觉醒 ✦")
        actionBtn_:SetStyle({ backgroundColor = {60, 140, 80, 200} })
    else
        actionBtn_:SetVisible(false)
    end
end

-- ============================================================================
-- 操作处理
-- ============================================================================

function ArtifactUI.OnActionClick()
    local count = ArtifactSystem.GetActivatedCount()
    if count >= ArtifactSystem.GRID_COUNT and not ArtifactSystem.bossDefeated then
        local canFight, reason = ArtifactSystem.CanFightBoss()
        if canFight then
            ArtifactUI.Hide()
            ArtifactUI._pendingBossFight = true
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
function ArtifactUI.TryStartPendingBossFight(gameMap, camera)
    if not ArtifactUI._pendingBossFight then return false end
    ArtifactUI._pendingBossFight = false
    local success, msg = ArtifactSystem.EnterBossArena(gameMap, camera)
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

function ArtifactUI.ShowVictory()
    if victoryPanel_ then return end
    if not parentOverlay_ then return end

    local passive = ArtifactSystem.PASSIVE
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
                backgroundColor = {30, 28, 20, 250},
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = {255, 215, 0, 180},
                paddingTop = 20, paddingBottom = 16,
                paddingLeft = 20, paddingRight = 20,
                gap = 12,
                alignItems = "center",
                onClick = function() end,
                children = {
                    UI.Panel {
                        width = 80, height = 110,
                        backgroundImage = ArtifactSystem.FULL_IMAGE,
                        backgroundFit = "contain",
                    },
                    UI.Label {
                        text = "神兵觉醒",
                        fontSize = T.fontSize.xl or 22,
                        fontWeight = "bold",
                        fontColor = {255, 215, 0, 255},
                        textAlign = "center",
                    },
                    UI.Panel { height = 1, width = "80%", backgroundColor = {255, 215, 0, 60} },
                    UI.Label {
                        text = "上宝逊金钯已完全觉醒！",
                        fontSize = T.fontSize.md,
                        fontColor = {230, 230, 240, 255},
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "100%",
                        backgroundColor = {50, 45, 15, 230},
                        borderRadius = 6,
                        borderWidth = 1,
                        borderColor = {255, 215, 0, 100},
                        padding = 10,
                        gap = 4,
                        children = {
                            UI.Label { text = "解锁被动技能", fontSize = T.fontSize.xs, fontColor = {180, 180, 190, 200} },
                            UI.Label {
                                text = passive.name,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                fontColor = {255, 215, 0, 255},
                            },
                            UI.Label {
                                text = passive.desc,
                                fontSize = T.fontSize.sm,
                                fontColor = {220, 220, 230, 230},
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
                        backgroundColor = {200, 160, 40, 255},
                        marginTop = 4,
                        onClick = function() ArtifactUI.HideVictory() end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(victoryPanel_)
    GameState.uiOpen = "artifact_victory"
end

function ArtifactUI.HideVictory()
    if victoryPanel_ then
        victoryPanel_:SetVisible(false)
        victoryPanel_ = nil
    end
    if GameState.uiOpen == "artifact_victory" then
        GameState.uiOpen = nil
    end
end

-- ============================================================================
-- 销毁
-- ============================================================================

function ArtifactUI.Destroy()
    gridCells_ = {}
    gridLabels_ = {}
    infoLabel_ = nil
    actionBtn_ = nil
    costLabel_ = nil
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
    ArtifactUI._pendingBossFight = false
    victoryPanel_ = nil
    panel_ = nil
    visible_ = false
    parentOverlay_ = nil
end

return ArtifactUI
