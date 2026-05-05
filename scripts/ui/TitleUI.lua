-- ============================================================================
-- TitleUI.lua - 称号选择面板
-- 展示所有称号（已解锁/未解锁），支持佩戴/取消佩戴，查看条件与总属性
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local TitleSystem = require("systems.TitleSystem")
local TitleData = require("config.TitleData")
local T = require("config.UITheme")

local TitleUI = {}

local panel_ = nil
local visible_ = false

-- ============================================================================
-- 称号卡片
-- ============================================================================

--- 创建单个称号卡片
---@param titleId string
---@return table widget
local function CreateTitleCard(titleId)
    local title = TitleData.TITLES[titleId]
    if not title then return UI.Panel {} end

    local isUnlocked = TitleSystem.unlocked[titleId]
    local isEquipped = TitleSystem.GetEquippedId() == titleId

    -- 颜色
    local nameColor = isUnlocked and (title.color or {100, 200, 100, 255}) or {100, 100, 100, 180}
    local borderColor = isEquipped and (title.borderColor or {80, 160, 80, 200})
        or isUnlocked and {60, 80, 60, 120}
        or {50, 50, 55, 100}
    local bgColor = isEquipped and {35, 55, 35, 230}
        or isUnlocked and {30, 40, 35, 220}
        or {30, 30, 35, 200}

    -- 条件进度
    local conditionText = title.conditionText or ""
    local progressText = TitleSystem.GetConditionProgress(title.condition)

    -- 加成文字
    local bonusText = ""
    if title.bonus then
        local parts = {}
        if title.bonus.atk and title.bonus.atk > 0 then
            table.insert(parts, "攻击+" .. math.floor(title.bonus.atk))
        end
        if title.bonus.critRate and title.bonus.critRate > 0 then
            table.insert(parts, "暴击+" .. string.format("%.0f%%", title.bonus.critRate * 100))
        end
        if title.bonus.heavyHit and title.bonus.heavyHit > 0 then
            table.insert(parts, "重击值+" .. math.floor(title.bonus.heavyHit))
        end
        if title.bonus.killHeal and title.bonus.killHeal > 0 then
            table.insert(parts, "击杀回血+" .. math.floor(title.bonus.killHeal))
        end
        if title.bonus.atkBonus and title.bonus.atkBonus > 0 then
            table.insert(parts, "攻击+" .. string.format("%.0f%%", title.bonus.atkBonus * 100))
        end
        if title.bonus.expBonus and title.bonus.expBonus > 0 then
            table.insert(parts, "经验+" .. string.format("%.0f%%", title.bonus.expBonus * 100))
        end
        bonusText = table.concat(parts, " ")
    end

    -- 状态文字与按钮
    local statusWidget
    if isEquipped then
        statusWidget = UI.Button {
            text = "卸下",
            width = 56,
            height = 26,
            fontSize = T.fontSize.xs,
            borderRadius = T.radius.sm,
            backgroundColor = {80, 60, 50, 230},
            fontColor = {255, 180, 140, 255},
            onClick = function(self)
                TitleSystem.Equip(nil)
                TitleUI.Refresh()
                -- 刷新角色面板（如果之后打开）
                EventBus.Emit("title_changed")
            end,
        }
    elseif isUnlocked then
        statusWidget = UI.Button {
            text = "佩戴",
            width = 56,
            height = 26,
            fontSize = T.fontSize.xs,
            borderRadius = T.radius.sm,
            backgroundColor = {50, 80, 50, 230},
            fontColor = {150, 230, 150, 255},
            onClick = function(self)
                TitleSystem.Equip(titleId)
                TitleUI.Refresh()
                EventBus.Emit("title_changed")
            end,
        }
    else
        statusWidget = UI.Label {
            text = "未解锁",
            fontSize = T.fontSize.xs,
            fontColor = {100, 100, 100, 180},
        }
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        padding = T.spacing.sm,
        backgroundColor = bgColor,
        borderRadius = T.radius.sm,
        borderWidth = isEquipped and 2 or 1,
        borderColor = borderColor,
        children = {
            -- 称号名 + 信息
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                gap = 2,
                children = {
                    -- 第一行：称号名
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        children = {
                            UI.Label {
                                text = title.name,
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = nameColor,
                            },
                            isEquipped and UI.Label {
                                text = "[佩戴中]",
                                fontSize = T.fontSize.xs,
                                fontColor = {100, 200, 100, 200},
                            } or UI.Panel {},
                        },
                    },
                    -- 第二行：激活条件
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 2,
                        children = {
                            UI.Label {
                                text = "条件: ",
                                fontSize = T.fontSize.xs,
                                fontColor = {140, 140, 140, 200},
                            },
                            UI.Label {
                                text = conditionText,
                                fontSize = T.fontSize.xs,
                                fontColor = isUnlocked and {100, 200, 100, 220} or {180, 180, 180, 220},
                            },
                            UI.Label {
                                text = "  " .. progressText,
                                fontSize = T.fontSize.xs,
                                fontColor = isUnlocked and {100, 255, 100, 255} or {200, 180, 100, 220},
                            },
                        },
                    },
                    -- 第三行：属性加成
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 2,
                        children = {
                            UI.Label {
                                text = "加成: ",
                                fontSize = T.fontSize.xs,
                                fontColor = {140, 140, 140, 200},
                            },
                            UI.Label {
                                text = bonusText,
                                fontSize = T.fontSize.xs,
                                fontColor = isUnlocked and {255, 150, 100, 255} or {140, 140, 140, 180},
                            },
                        },
                    },
                },
            },
            -- 状态/操作
            UI.Panel {
                width = 60,
                alignItems = "center",
                justifyContent = "center",
                children = {
                    statusWidget,
                },
            },
        },
    }
end

--- 创建总加成面板
---@return table widget
local function CreateBonusSummaryPanel()
    local summary = TitleSystem.GetBonusSummary()
    local unlocked = TitleSystem.GetUnlockedCount()
    local total = TitleSystem.GetTotalCount()

    local bonusRows = {}
    if summary.atk and summary.atk > 0 then
        table.insert(bonusRows, UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = "攻击",
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 150, 100, 255},
                },
                UI.Label {
                    text = "+" .. math.floor(summary.atk),
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        })
    end
    if summary.critRate and summary.critRate > 0 then
        table.insert(bonusRows, UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = "暴击率",
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 220, 100, 255},
                },
                UI.Label {
                    text = "+" .. string.format("%.0f%%", summary.critRate * 100),
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        })
    end
    if summary.heavyHit and summary.heavyHit > 0 then
        table.insert(bonusRows, UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = "重击值",
                    fontSize = T.fontSize.xs,
                    fontColor = {180, 100, 255, 255},
                },
                UI.Label {
                    text = "+" .. math.floor(summary.heavyHit),
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        })
    end
    if summary.killHeal and summary.killHeal > 0 then
        table.insert(bonusRows, UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = "击杀回血",
                    fontSize = T.fontSize.xs,
                    fontColor = {100, 255, 180, 255},
                },
                UI.Label {
                    text = "+" .. math.floor(summary.killHeal),
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        })
    end
    if summary.atkBonus and summary.atkBonus > 0 then
        table.insert(bonusRows, UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = "攻击加成",
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 180, 60, 255},
                },
                UI.Label {
                    text = "+" .. string.format("%.0f%%", summary.atkBonus * 100),
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        })
    end
    if summary.expBonus and summary.expBonus > 0 then
        table.insert(bonusRows, UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = "经验加成",
                    fontSize = T.fontSize.xs,
                    fontColor = {80, 200, 220, 255},
                },
                UI.Label {
                    text = "+" .. string.format("%.0f%%", summary.expBonus * 100),
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        })
    end

    if #bonusRows == 0 then
        table.insert(bonusRows, UI.Label {
            text = "暂无加成",
            fontSize = T.fontSize.xs,
            fontColor = {120, 120, 120, 180},
        })
    end

    return UI.Panel {
        backgroundColor = {25, 35, 30, 220},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = {80, 150, 100, 100},
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "称号总加成",
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = {180, 255, 200, 255},
                    },
                    UI.Label {
                        text = unlocked .. "/" .. total,
                        fontSize = T.fontSize.xs,
                        fontColor = unlocked >= total and {255, 215, 0, 255} or {180, 180, 180, 220},
                    },
                },
            },
            table.unpack(bonusRows),
        },
    }
end

-- ============================================================================
-- 公共接口
-- ============================================================================

---@param parentOverlay table
function TitleUI.Create(parentOverlay)
    panel_ = UI.Panel {
        id = "titlePanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = {0, 0, 0, 150},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self) end,
        children = {
            UI.Panel {
                id = "titleCard",
                width = T.size.smallPanelW,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                children = {
                    -- 标题栏
                    UI.Panel {
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
                                        text = "🏷️",
                                        fontSize = T.fontSize.xl,
                                    },
                                    UI.Label {
                                        text = "称号选择",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self)
                                    TitleUI.Hide()
                                end,
                            },
                        },
                    },
                    -- 副标题
                    UI.Label {
                        text = "佩戴称号显示在名牌上，所有已解锁称号属性累加",
                        fontSize = T.fontSize.xs,
                        fontColor = {150, 150, 150, 200},
                        textAlign = "center",
                    },
                    -- 总加成面板容器
                    UI.Panel {
                        id = "title_summary_container",
                    },
                    -- 称号列表
                    UI.ScrollView {
                        id = "title_scroll",
                        flexGrow = 1,
                        flexShrink = 1,
                        flexBasis = 0,
                        children = {
                            UI.Panel {
                                id = "title_list",
                                gap = T.spacing.xs,
                                paddingRight = T.spacing.xs,
                            },
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)

    -- 监听称号解锁事件
    EventBus.On("title_unlocked", function()
        if visible_ then
            TitleUI.Refresh()
        end
    end)
end

function TitleUI.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "title"
    TitleUI.Refresh()
end

function TitleUI.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    if GameState.uiOpen == "title" then
        GameState.uiOpen = nil
    end
end

function TitleUI.Toggle()
    if visible_ then TitleUI.Hide() else TitleUI.Show() end
end

function TitleUI.IsVisible()
    return visible_
end

function TitleUI.Refresh()
    if not panel_ then return end

    -- 刷新总加成
    local summaryContainer = panel_:FindById("title_summary_container")
    if summaryContainer then
        summaryContainer:ClearChildren()
        summaryContainer:AddChild(CreateBonusSummaryPanel())
    end

    -- 刷新列表
    local list = panel_:FindById("title_list")
    if not list then return end

    list:ClearChildren()

    for _, titleId in ipairs(TitleData.ORDER) do
        local card = CreateTitleCard(titleId)
        list:AddChild(card)
    end
end

return TitleUI
