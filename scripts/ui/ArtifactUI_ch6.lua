-- ============================================================================
-- ArtifactUI_ch6.lua - 第六章神器「界匙」九宫格与双王觉醒面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local ArtifactCh6 = require("systems.ArtifactSystem_ch6")
local T = require("config.UITheme")

local ArtifactUI_ch6 = {}

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil
local gridCells_ = {}
local gridLabels_ = {}
local infoLabel_ = nil
local costLabel_ = nil
local passiveContainer_ = nil
local passiveTitle_ = nil
local passiveStatus_ = nil
local passiveDesc_ = nil
local bossStatus_ = nil

local confirmPanel_ = nil
local confirmGridName_ = nil
local confirmCostGold_ = nil
local confirmCostLingYun_ = nil
local confirmCostFragment_ = nil
local confirmFeedback_ = nil
local confirmActivateBtn_ = nil
local confirmCancelBtn_ = nil
local pendingIndex_ = nil

local savingPanel_ = nil
local successPanel_ = nil
local victoryPanel_ = nil
local cooldownRefreshTimer_ = 0
local eventsBound_ = false

ArtifactUI_ch6._pendingBossFight = false

local COLOR_CYAN = {145, 235, 255, 255}
local COLOR_PURPLE = {190, 120, 255, 255}
local COLOR_GREEN = {120, 245, 180, 255}
local COLOR_DIM = {140, 140, 165, 210}
local MASK_ACTIVE = {0, 0, 0, 0}
local MASK_READY = {8, 30, 38, 150}
local MASK_LOCKED = {8, 8, 18, 225}

local GRID_W = 240
local GRID_H = 350
local GRID_GAP = 2
local CELL_W = math.floor((GRID_W - GRID_GAP * 2) / 3)
local CELL_H = math.floor((GRID_H - GRID_GAP * 2) / 3)

local function SetConfirmBusy(busy)
    if confirmActivateBtn_ then confirmActivateBtn_:SetDisabled(busy) end
    if confirmCancelBtn_ then confirmCancelBtn_:SetDisabled(busy) end
end

local function HideSaving()
    if savingPanel_ then savingPanel_:Hide() end
end

local function ShowSaving()
    if savingPanel_ then savingPanel_:Show() end
end

function ArtifactUI_ch6.HideConfirm()
    if ArtifactCh6.IsBusy() then return end
    if confirmPanel_ then confirmPanel_:Hide() end
    pendingIndex_ = nil
    SetConfirmBusy(false)
end

local function ShowSuccess(index, details)
    if not successPanel_ then return end
    local maxHp = details and details.maxHp or 0
    local hpRegen = details and details.hpRegen or 0
    local fortune = details and details.fortune or 0
    local summary = successPanel_:FindById("jieshi_success_summary")
    if summary then
        summary:SetText(string.format(
            "第%s位已重铸\n当前：生命+%d\n生命回复+%d  福源+%d",
            ArtifactCh6.GRID_NAMES[index], maxHp, hpRegen, fortune))
    end
    successPanel_:Show()
end

local function ShowConfirm(index)
    if not confirmPanel_ or ArtifactCh6.IsBusy() then return end
    pendingIndex_ = index
    local fragment = GameConfig.CONSUMABLES[ArtifactCh6.FRAGMENT_IDS[index]]
    if confirmGridName_ then
        confirmGridName_:SetText("重铸「第" .. ArtifactCh6.GRID_NAMES[index] .. "位」")
    end
    if confirmCostGold_ then
        confirmCostGold_:SetText(
            "金币  " .. ArtifactCh6.FormatGold(ArtifactCh6.ACTIVATE_GOLD_COST))
    end
    if confirmCostLingYun_ then
        confirmCostLingYun_:SetText(
            "灵韵  " .. tostring(ArtifactCh6.ACTIVATE_LINGYUN_COST))
    end
    if confirmCostFragment_ then
        confirmCostFragment_:SetText(
            "碎片  " .. (fragment and fragment.name or "对应界匙碎片"))
    end
    if confirmFeedback_ then
        confirmFeedback_:SetText("")
        confirmFeedback_:SetVisible(false)
    end
    SetConfirmBusy(false)
    confirmPanel_:Show()
end

local function DoActivate()
    local index = pendingIndex_
    if not index or ArtifactCh6.IsBusy() then return end

    SetConfirmBusy(true)
    ShowSaving()
    local started, message = ArtifactCh6.Activate(index, function(success, resultMessage, details)
        HideSaving()
        SetConfirmBusy(false)
        if success then
            if confirmPanel_ then confirmPanel_:Hide() end
            pendingIndex_ = nil
            ArtifactUI_ch6.Refresh()
            ShowSuccess(index, details)
            local ok, CharacterUI = pcall(require, "ui.CharacterUI")
            if ok and CharacterUI then CharacterUI.Refresh() end
            local okAtlas, AtlasUI = pcall(require, "ui.AtlasUI")
            if okAtlas and AtlasUI and AtlasUI.Refresh then AtlasUI.Refresh() end
        else
            if confirmFeedback_ then
                confirmFeedback_:SetText(resultMessage)
                confirmFeedback_:SetStyle({ fontColor = {255, 120, 120, 255} })
                confirmFeedback_:SetVisible(true)
            end
            ArtifactUI_ch6.Refresh()
        end
    end)

    if not started then
        HideSaving()
        SetConfirmBusy(false)
        if confirmFeedback_ then
            confirmFeedback_:SetText(message)
            confirmFeedback_:SetStyle({ fontColor = {255, 120, 120, 255} })
            confirmFeedback_:SetVisible(true)
        end
    end
end

local function CreateGridCell(index)
    local idx = index
    local label = UI.Label {
        text = ArtifactCh6.GRID_NAMES[index],
        fontSize = T.fontSize.md,
        textAlign = "center",
        fontColor = COLOR_DIM,
    }
    gridLabels_[index] = label

    local cell = UI.Panel {
        width = CELL_W,
        height = CELL_H,
        borderWidth = 1,
        borderColor = {50, 55, 75, 150},
        backgroundColor = MASK_LOCKED,
        justifyContent = "center",
        alignItems = "center",
        onClick = function()
            if not ArtifactCh6.IsGridActivated(idx) then ShowConfirm(idx) end
        end,
        children = { label },
    }
    return cell
end

local function RefreshGridCell(index)
    local cell = gridCells_[index]
    local label = gridLabels_[index]
    if not cell or not label then return end

    local activated = ArtifactCh6.IsGridActivated(index)
    local hasFragment = ArtifactCh6.GetFragmentCount(index) > 0
    if activated then
        cell:SetStyle({
            backgroundColor = MASK_ACTIVE,
            borderColor = index % 2 == 0 and COLOR_PURPLE or COLOR_CYAN,
            borderWidth = 2,
        })
        label:SetText("✓")
        label:SetStyle({ fontColor = COLOR_GREEN })
    elseif hasFragment then
        cell:SetStyle({
            backgroundColor = MASK_READY,
            borderColor = COLOR_CYAN,
            borderWidth = 2,
        })
        label:SetText("◇")
        label:SetStyle({ fontColor = COLOR_CYAN })
    else
        cell:SetStyle({
            backgroundColor = MASK_LOCKED,
            borderColor = {50, 55, 75, 150},
            borderWidth = 1,
        })
        label:SetText(ArtifactCh6.GRID_NAMES[index])
        label:SetStyle({ fontColor = COLOR_DIM })
    end
end

local function BuildConfirmPanel()
    confirmGridName_ = UI.Label {
        text = "",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = {225, 240, 255, 255},
        textAlign = "center",
    }
    confirmCostGold_ = UI.Label {
        text = "", fontSize = T.fontSize.sm, fontColor = {255, 215, 100, 255},
    }
    confirmCostLingYun_ = UI.Label {
        text = "", fontSize = T.fontSize.sm, fontColor = COLOR_CYAN,
    }
    confirmCostFragment_ = UI.Label {
        text = "", fontSize = T.fontSize.sm, fontColor = COLOR_PURPLE,
    }
    confirmFeedback_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        textAlign = "center",
        visible = false,
    }

    confirmCancelBtn_ = UI.Button {
        text = "取消",
        width = 96,
        height = T.size.dialogBtnH,
        backgroundColor = T.color.btnSecondary,
        fontColor = T.color.btnSecondaryFg,
        onClick = function() ArtifactUI_ch6.HideConfirm() end,
    }
    confirmActivateBtn_ = UI.Button {
        text = "激活",
        width = 96,
        height = T.size.dialogBtnH,
        backgroundColor = T.color.btnSpend,
        fontColor = T.color.btnSpendFg,
        fontWeight = "bold",
        onClick = function() DoActivate() end,
    }

    return UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 190},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 220,
        onClick = function() ArtifactUI_ch6.HideConfirm() end,
        children = {
            UI.Panel {
                width = 280,
                padding = 16,
                gap = 10,
                alignItems = "center",
                backgroundColor = {18, 24, 42, 252},
                borderWidth = 1,
                borderColor = {155, 220, 255, 130},
                borderRadius = T.radius.md,
                onClick = function() end,
                children = {
                    UI.Label {
                        text = "确认重铸",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = COLOR_CYAN,
                    },
                    confirmGridName_,
                    UI.Panel {
                        width = "100%",
                        padding = 10,
                        gap = 6,
                        backgroundColor = {8, 12, 25, 210},
                        borderRadius = T.radius.sm,
                        children = {
                            UI.Label {
                                text = "消耗",
                                fontSize = T.fontSize.xs,
                                fontColor = COLOR_DIM,
                            },
                            confirmCostGold_,
                            confirmCostLingYun_,
                            confirmCostFragment_,
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        padding = 10,
                        gap = 4,
                        backgroundColor = {8, 12, 25, 210},
                        borderRadius = T.radius.sm,
                        children = {
                            UI.Label {
                                text = "每格加成",
                                fontSize = T.fontSize.xs,
                                fontColor = COLOR_DIM,
                            },
                            UI.Label {
                                text = "生命 +150",
                                fontSize = T.fontSize.sm,
                                fontColor = COLOR_GREEN,
                            },
                            UI.Label {
                                text = "生命回复 +10",
                                fontSize = T.fontSize.sm,
                                fontColor = COLOR_CYAN,
                            },
                            UI.Label {
                                text = "福源 +10",
                                fontSize = T.fontSize.sm,
                                fontColor = COLOR_PURPLE,
                            },
                        },
                    },
                    confirmFeedback_,
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "center",
                        gap = 12,
                        children = { confirmCancelBtn_, confirmActivateBtn_ },
                    },
                },
            },
        },
    }
end

local function BuildSavingPanel()
    return UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 260,
        visible = false,
        backgroundColor = {0, 0, 0, 205},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = 250,
                padding = 18,
                gap = 8,
                alignItems = "center",
                backgroundColor = {18, 24, 42, 252},
                borderWidth = 1,
                borderColor = {155, 220, 255, 130},
                borderRadius = T.radius.md,
                children = {
                    UI.Label {
                        text = "◇",
                        fontSize = 34,
                        fontColor = COLOR_CYAN,
                    },
                    UI.Label {
                        text = "正在保存界匙进度",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {230, 240, 255, 255},
                    },
                    UI.Label {
                        text = "保存确认前不会完成激活",
                        fontSize = T.fontSize.xs,
                        fontColor = COLOR_DIM,
                    },
                },
            },
        },
    }
end

local function BuildSuccessPanel()
    return UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 250,
        visible = false,
        backgroundColor = {0, 0, 0, 205},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = 290,
                padding = 18,
                gap = 10,
                alignItems = "center",
                backgroundColor = {16, 28, 42, 252},
                borderWidth = 2,
                borderColor = {145, 235, 255, 170},
                borderRadius = T.radius.md,
                children = {
                    UI.Panel {
                        width = 76,
                        height = 108,
                        backgroundImage = ArtifactCh6.WORLD_IMAGE,
                        backgroundFit = "contain",
                    },
                    UI.Label {
                        text = "界匙重铸成功",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = COLOR_CYAN,
                    },
                    UI.Label {
                        id = "jieshi_success_summary",
                        text = "",
                        width = "100%",
                        fontSize = T.fontSize.sm,
                        fontColor = {220, 230, 245, 255},
                        textAlign = "center",
                        whiteSpace = "normal",
                        lineHeight = 1.35,
                    },
                    UI.Label {
                        text = "账号级进度已保存",
                        fontSize = T.fontSize.xs,
                        fontColor = COLOR_GREEN,
                    },
                    UI.Button {
                        text = "确认",
                        width = 120,
                        height = T.size.dialogBtnH,
                        backgroundColor = T.color.btnSuccess,
                        fontColor = T.color.btnSuccessFg,
                        onClick = function()
                            if successPanel_ then successPanel_:Hide() end
                        end,
                    },
                },
            },
        },
    }
end

function ArtifactUI_ch6.Create(parentOverlay)
    if panel_ then return end
    parentOverlay_ = parentOverlay
    gridCells_ = {}
    gridLabels_ = {}

    if not eventsBound_ then
        eventsBound_ = true
        EventBus.On("artifact_ch6_boss_defeated", function()
            ArtifactUI_ch6.ShowVictory()
            local okCharacter, CharacterUI = pcall(require, "ui.CharacterUI")
            if okCharacter and CharacterUI then CharacterUI.Refresh() end
            local okAtlas, AtlasUI = pcall(require, "ui.AtlasUI")
            if okAtlas and AtlasUI and AtlasUI.Refresh then AtlasUI.Refresh() end
        end)
    end

    local gridRows = {}
    for row = 1, 3 do
        local cells = {}
        for col = 1, 3 do
            local index = (row - 1) * 3 + col
            local cell = CreateGridCell(index)
            gridCells_[index] = cell
            cells[#cells + 1] = cell
        end
        gridRows[#gridRows + 1] = UI.Panel {
            flexDirection = "row",
            gap = GRID_GAP,
            justifyContent = "center",
            children = cells,
        }
    end

    infoLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {210, 220, 235, 255},
        textAlign = "center",
    }
    costLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = COLOR_DIM,
        textAlign = "center",
    }
    passiveTitle_ = UI.Label {
        text = "◇ 被动「" .. ArtifactCh6.PASSIVE.name .. "」",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = COLOR_DIM,
        textAlign = "center",
    }
    passiveStatus_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontWeight = "bold",
        textAlign = "center",
    }
    passiveDesc_ = UI.Label {
        text = ArtifactCh6.PASSIVE.desc,
        fontSize = T.fontSize.xs,
        fontColor = COLOR_DIM,
        textAlign = "center",
    }
    passiveContainer_ = UI.Panel {
        width = "100%",
        padding = T.spacing.sm,
        gap = 4,
        alignItems = "center",
        backgroundColor = {20, 18, 38, 210},
        borderWidth = 1,
        borderColor = {140, 120, 190, 70},
        borderRadius = T.radius.sm,
        children = { passiveTitle_, passiveStatus_, passiveDesc_ },
    }
    bossStatus_ = UI.Button {
        text = "唤醒双王",
        width = "100%",
        height = T.size.dialogBtnH,
        backgroundColor = T.color.btnDanger,
        fontColor = T.color.btnDangerFg,
        fontWeight = "bold",
        visible = false,
        onClick = function() ArtifactUI_ch6.OnBossClick() end,
    }

    confirmPanel_ = BuildConfirmPanel()
    savingPanel_ = BuildSavingPanel()
    successPanel_ = BuildSuccessPanel()

    local content = UI.Panel {
        width = "100%",
        padding = T.spacing.md,
        gap = T.spacing.sm,
        alignItems = "center",
        children = {
            UI.Label {
                text = "人界为齿，影界为锁，九钥归一",
                fontSize = T.fontSize.sm,
                fontColor = {165, 175, 205, 230},
                textAlign = "center",
            },
            UI.Panel {
                width = GRID_W,
                height = GRID_H,
                alignSelf = "center",
                overflow = "hidden",
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = {145, 235, 255, 80},
                backgroundImage = ArtifactCh6.FULL_IMAGE,
                backgroundFit = "fill",
                justifyContent = "center",
                alignItems = "center",
                gap = GRID_GAP,
                children = gridRows,
            },
            costLabel_,
            infoLabel_,
            passiveContainer_,
            bossStatus_,
            confirmPanel_,
            savingPanel_,
            successPanel_,
        },
    }

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%",
        height = "100%",
        zIndex = 900,
        visible = false,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function() ArtifactUI_ch6.Hide() end,
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                maxHeight = "92%",
                overflow = "scroll",
                backgroundColor = T.color.panelBg,
                borderWidth = 1,
                borderColor = {145, 235, 255, 90},
                borderRadius = T.radius.lg,
                onClick = function() end,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "space-between",
                        paddingTop = T.spacing.sm,
                        paddingLeft = T.spacing.md,
                        paddingRight = T.spacing.sm,
                        children = {
                            UI.Label {
                                text = "◇ 界匙",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = COLOR_CYAN,
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                backgroundColor = {50, 55, 75, 220},
                                onClick = function() ArtifactUI_ch6.Hide() end,
                            },
                        },
                    },
                    content,
                },
            },
        },
    }
    parentOverlay_:AddChild(panel_)
    ArtifactUI_ch6.Refresh()
end

function ArtifactUI_ch6.Refresh()
    local count = ArtifactCh6.GetActivatedCount()
    for i = 1, ArtifactCh6.GRID_COUNT do RefreshGridCell(i) end

    local maxHp, hpRegen, fortune = ArtifactCh6.GetCurrentBonus()
    if infoLabel_ then
        infoLabel_:SetText(string.format(
            "已激活 %d/9  |  生命+%d  生命回复+%d  福源+%d",
            count, maxHp, hpRegen, fortune))
    end
    if costLabel_ then
        if count < ArtifactCh6.GRID_COUNT then
            costLabel_:SetText(
                "每格：" .. ArtifactCh6.FormatGold(ArtifactCh6.ACTIVATE_GOLD_COST)
                .. "金币 + " .. ArtifactCh6.ACTIVATE_LINGYUN_COST
                .. "灵韵 + 对应碎片")
        elseif not ArtifactCh6.bossDefeated then
            costLabel_:SetText("九格已全部重铸，可唤醒魔化与仙化呱大王")
        else
            costLabel_:SetText("界匙已完全觉醒")
        end
    end

    if ArtifactCh6.passiveUnlocked then
        local remaining = ArtifactCh6.GetCooldownRemaining()
        passiveContainer_:SetStyle({
            backgroundColor = {18, 48, 52, 230},
            borderColor = COLOR_CYAN,
            borderWidth = 2,
        })
        passiveTitle_:SetStyle({ fontColor = COLOR_CYAN })
        passiveStatus_:SetText(remaining > 0
            and ("冷却中 " .. remaining .. "秒") or "可触发")
        passiveStatus_:SetStyle({
            fontColor = remaining > 0 and COLOR_PURPLE or COLOR_GREEN,
        })
        passiveDesc_:SetStyle({ fontColor = {210, 230, 240, 255} })
    elseif count >= ArtifactCh6.GRID_COUNT then
        passiveContainer_:SetStyle({
            backgroundColor = {28, 24, 48, 220},
            borderColor = {170, 125, 230, 120},
            borderWidth = 1,
        })
        passiveTitle_:SetStyle({ fontColor = COLOR_PURPLE })
        passiveStatus_:SetText("待觉醒 · 击败魔化与仙化呱大王")
        passiveStatus_:SetStyle({ fontColor = COLOR_PURPLE })
        passiveDesc_:SetStyle({ fontColor = {170, 165, 190, 220} })
    else
        passiveContainer_:SetStyle({
            backgroundColor = {20, 18, 38, 210},
            borderColor = {140, 120, 190, 70},
            borderWidth = 1,
        })
        passiveTitle_:SetStyle({ fontColor = COLOR_DIM })
        passiveStatus_:SetText(string.format("未解锁（%d/9格）", count))
        passiveStatus_:SetStyle({ fontColor = COLOR_DIM })
        passiveDesc_:SetStyle({ fontColor = COLOR_DIM })
    end
    if bossStatus_ then
        if count < ArtifactCh6.GRID_COUNT then
            bossStatus_:SetVisible(false)
        elseif ArtifactCh6.bossDefeated then
            bossStatus_:SetVisible(true)
            bossStatus_:SetDisabled(true)
            bossStatus_:SetText("◇ 界匙已觉醒 ◇")
            bossStatus_:SetStyle({
                backgroundColor = T.color.btnSuccess,
                fontColor = T.color.btnSuccessFg,
            })
        else
            local canFight = ArtifactCh6.CanFightBoss()
            bossStatus_:SetVisible(true)
            bossStatus_:SetDisabled(not canFight)
            bossStatus_:SetText("唤醒双王")
            bossStatus_:SetStyle({
                backgroundColor = canFight and T.color.btnDanger
                    or T.color.btnDisabled,
                fontColor = canFight and T.color.btnDangerFg
                    or T.color.btnDisabledFg,
            })
        end
    end
end

function ArtifactUI_ch6.OnBossClick()
    if ArtifactCh6.bossDefeated then return end
    local canFight, reason = ArtifactCh6.CanFightBoss()
    if canFight then
        ArtifactUI_ch6.Hide()
        ArtifactUI_ch6._pendingBossFight = true
        return
    end

    local player = GameState.player
    if player then
        local CombatSystem = require("systems.CombatSystem")
        CombatSystem.AddFloatingText(
            player.x or 0, (player.y or 0) - 0.5,
            reason, {255, 110, 110, 255}, 2.0)
    end
end

---@param gameMap table
---@param camera table|nil
---@return boolean
function ArtifactUI_ch6.TryStartPendingBossFight(gameMap, camera)
    if not ArtifactUI_ch6._pendingBossFight then return false end
    ArtifactUI_ch6._pendingBossFight = false
    local success, message = ArtifactCh6.EnterBossArena(gameMap, camera)
    if not success then
        local player = GameState.player
        if player then
            local CombatSystem = require("systems.CombatSystem")
            CombatSystem.AddFloatingText(
                player.x or 0, (player.y or 0) - 0.5,
                message or "双王挑战启动失败",
                {255, 110, 110, 255}, 2.0)
        end
    end
    return success
end

function ArtifactUI_ch6.ShowVictory()
    if victoryPanel_ or not parentOverlay_ then return end

    victoryPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 980,
        backgroundColor = {0, 0, 0, 210},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = 300,
                padding = 18,
                gap = 10,
                alignItems = "center",
                backgroundColor = {16, 30, 42, 252},
                borderWidth = 2,
                borderColor = {155, 235, 220, 190},
                borderRadius = T.radius.md,
                onClick = function() end,
                children = {
                    UI.Panel {
                        width = 82,
                        height = 116,
                        backgroundImage = ArtifactCh6.FULL_IMAGE,
                        backgroundFit = "contain",
                    },
                    UI.Label {
                        text = "双王归钥",
                        fontSize = T.fontSize.xl or 22,
                        fontWeight = "bold",
                        fontColor = COLOR_CYAN,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "魔化与仙化呱大王均已镇服\n界匙完成账号级觉醒",
                        fontSize = T.fontSize.sm,
                        fontColor = {225, 235, 240, 255},
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "100%",
                        padding = 10,
                        gap = 4,
                        backgroundColor = {24, 48, 52, 230},
                        borderWidth = 1,
                        borderColor = {145, 235, 255, 110},
                        borderRadius = T.radius.sm,
                        children = {
                            UI.Label {
                                text = "解锁被动「" .. ArtifactCh6.PASSIVE.name .. "」",
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                fontColor = COLOR_GREEN,
                                textAlign = "center",
                            },
                            UI.Label {
                                text = ArtifactCh6.PASSIVE.desc,
                                fontSize = T.fontSize.sm,
                                fontColor = {210, 230, 235, 240},
                                textAlign = "center",
                            },
                        },
                    },
                    UI.Label {
                        text = "首胜进度已保存至账号档案",
                        fontSize = T.fontSize.xs,
                        fontColor = COLOR_GREEN,
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "确认",
                        width = 120,
                        height = T.size.dialogBtnH,
                        backgroundColor = T.color.btnSuccess,
                        fontColor = T.color.btnSuccessFg,
                        fontWeight = "bold",
                        onClick = function() ArtifactUI_ch6.HideVictory() end,
                    },
                },
            },
        },
    }
    parentOverlay_:AddChild(victoryPanel_)
    GameState.uiOpen = "artifact_ch6_victory"
end

function ArtifactUI_ch6.HideVictory()
    if victoryPanel_ then
        victoryPanel_:SetVisible(false)
        victoryPanel_ = nil
    end
    if GameState.uiOpen == "artifact_ch6_victory" then
        GameState.uiOpen = nil
    end
end

function ArtifactUI_ch6.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    ArtifactUI_ch6.Refresh()
    panel_:Show()
    GameState.uiOpen = "artifact_ch6"
end

function ArtifactUI_ch6.Hide()
    if not panel_ or not visible_ or ArtifactCh6.IsBusy() then return end
    visible_ = false
    panel_:Hide()
    if confirmPanel_ then confirmPanel_:Hide() end
    if successPanel_ then successPanel_:Hide() end
    pendingIndex_ = nil
    if GameState.uiOpen == "artifact_ch6" then GameState.uiOpen = nil end
end

function ArtifactUI_ch6.IsVisible()
    return visible_
end

function ArtifactUI_ch6.Update(dt)
    if not visible_ then return end
    cooldownRefreshTimer_ = cooldownRefreshTimer_ - (dt or 0)
    if cooldownRefreshTimer_ <= 0 then
        cooldownRefreshTimer_ = 1
        ArtifactUI_ch6.Refresh()
    end
end

function ArtifactUI_ch6.Destroy()
    gridCells_ = {}
    gridLabels_ = {}
    panel_ = nil
    visible_ = false
    parentOverlay_ = nil
    infoLabel_ = nil
    costLabel_ = nil
    passiveContainer_ = nil
    passiveTitle_ = nil
    passiveStatus_ = nil
    passiveDesc_ = nil
    bossStatus_ = nil
    confirmPanel_ = nil
    confirmGridName_ = nil
    confirmCostGold_ = nil
    confirmCostLingYun_ = nil
    confirmCostFragment_ = nil
    confirmFeedback_ = nil
    confirmActivateBtn_ = nil
    confirmCancelBtn_ = nil
    pendingIndex_ = nil
    savingPanel_ = nil
    successPanel_ = nil
    victoryPanel_ = nil
    cooldownRefreshTimer_ = 0
    ArtifactUI_ch6._pendingBossFight = false
end

return ArtifactUI_ch6
