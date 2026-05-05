-- ============================================================================
-- YaochiWashUI.lua - 瑶池洗髓面板
-- 包含：灵液面板（丹药投入 + 进度条）和 淬炼仪式画面（读条）
-- ============================================================================

local UI              = require("urhox-libs/UI")
local GameConfig      = require("config.GameConfig")
local GameState       = require("core.GameState")
local EventBus        = require("core.EventBus")
local T               = require("config.UITheme")
local YaochiWashSystem = require("systems.YaochiWashSystem")

local YaochiWashUI = {}

-- ── 模块状态 ──────────────────────────────────────────────────────
local panel_         = nil   -- 主面板
local visible_       = false
local parentOverlay_ = nil

-- UI 引用（需要动态更新的控件）
local pointsLabel_    = nil  -- "洗髓灵液: X / Y"
local progressBar_    = nil  -- 灵液进度条
local progressFill_   = nil  -- 进度条填充
local progressText_   = nil  -- 进度百分比
local levelLabel_     = nil  -- "洗髓境 第X重 (灵体增减伤 +X%)"
local realmLabel_     = nil  -- "当前境界: ..."
local ritualBtn_      = nil  -- "洗髓淬炼" 按钮
local hintLabel_      = nil  -- 底部提示
local pillRows_       = {}   -- 丹药行（每行含数量标签）

-- 仪式画面
local ritualPanel_    = nil  -- 全屏仪式面板
local ritualBar_      = nil  -- 读条进度条填充
local ritualText_     = nil  -- "洗髓淬炼中... Xs"
local ritualPercent_  = nil  -- 百分比文字

-- 二次确认弹窗
local confirmPanel_   = nil

-- ── 颜色常量 ──────────────────────────────────────────────────────
local COLOR_GOLD      = {255, 220, 150, 255}
local COLOR_PURPLE    = {200, 180, 255, 255}
local COLOR_GRAY      = {150, 150, 150, 255}
local COLOR_WHITE     = {230, 230, 240, 255}
local COLOR_CYAN      = {100, 220, 255, 255}
local COLOR_GREEN     = {100, 230, 150, 255}
local COLOR_RED       = {255, 100, 100, 255}
local COLOR_BAR_BG    = {40, 45, 60, 255}
local COLOR_BAR_FILL  = {120, 80, 220, 255}
local COLOR_RITUAL_BG = {0, 0, 0, 220}
local COLOR_RITUAL_BAR = {180, 140, 255, 255}

-- ── 辅助函数 ──────────────────────────────────────────────────────

--- 格式化灵液点数
local function FormatPoints(pts)
    if pts >= 10000 then
        return string.format("%.1fW", pts / 10000)
    end
    return tostring(pts)
end

--- 获取丹药中文名
local function GetPillName(pillId)
    local def = GameConfig.PET_MATERIALS[pillId]
    return def and def.name or pillId
end

--- 获取丹药 icon
local function GetPillIcon(pillId)
    local def = GameConfig.PET_MATERIALS[pillId]
    return def and def.icon or "💊"
end

-- ── 刷新面板数据 ──────────────────────────────────────────────────

local function RefreshPanel()
    if not panel_ or not visible_ then return end

    local level = YaochiWashSystem.GetLevel()
    local points = YaochiWashSystem.GetPoints()
    local required = YaochiWashSystem.GetRequiredPoints()
    local maxLevel = YaochiWashSystem.GetMaxLevelForRealm()

    -- 洗髓境
    if levelLabel_ then
        if level > 0 then
            levelLabel_:SetText("洗髓境 第" .. level .. "重  (灵体增减伤 +" .. level .. "%)")
            levelLabel_:SetStyle({ fontColor = COLOR_PURPLE })
        else
            levelLabel_:SetText("洗髓境 未开  (未淬炼)")
            levelLabel_:SetStyle({ fontColor = COLOR_GRAY })
        end
    end

    -- 当前境界
    if realmLabel_ then
        local rd = GameConfig.REALMS[GameState.player.realm]
        local realmName = rd and rd.name or "???"
        realmLabel_:SetText("当前境界: " .. realmName)
    end

    -- 灵液进度
    if pointsLabel_ and required then
        pointsLabel_:SetText("洗髓灵液: " .. FormatPoints(points) .. " / " .. FormatPoints(required))
    elseif pointsLabel_ then
        pointsLabel_:SetText("洗髓灵液: " .. FormatPoints(points) .. " (已满级)")
    end

    -- 进度条
    if progressFill_ and required then
        local pct = math.min(1, points / required)
        progressFill_:SetStyle({ width = tostring(math.floor(pct * 100)) .. "%" })
        if progressText_ then
            progressText_:SetText(math.floor(pct * 100) .. "%")
        end
    end

    -- 丹药行数量
    for _, row in ipairs(pillRows_) do
        local count = YaochiWashSystem.GetPillCount(row.pillId)
        if row.countLabel then
            row.countLabel:SetText("×" .. count)
            row.countLabel:SetStyle({
                fontColor = count > 0 and COLOR_WHITE or COLOR_GRAY,
            })
        end
    end

    -- 淬炼按钮状态
    if ritualBtn_ then
        local canDo, reason = YaochiWashSystem.CanPerformRitual()
        if canDo then
            ritualBtn_:SetStyle({
                backgroundColor = {160, 120, 255, 255},
                opacity = 1,
            })
            ritualBtn_:SetText("洗髓淬炼")
        else
            ritualBtn_:SetStyle({
                backgroundColor = {80, 80, 100, 255},
                opacity = 0.6,
            })
            ritualBtn_:SetText(reason or "洗髓淬炼")
        end
    end

    -- 底部提示
    if hintLabel_ then
        if level >= YaochiWashSystem.MAX_LEVEL then
            hintLabel_:SetText("洗髓境已达巅峰，肉身圆满")
            hintLabel_:SetStyle({ fontColor = COLOR_GOLD })
        elseif level >= maxLevel then
            local rd = GameConfig.REALMS[GameState.player.realm]
            local realmName = rd and rd.name or "???"
            hintLabel_:SetText("需突破「" .. realmName .. "」境界以继续淬炼")
            hintLabel_:SetStyle({ fontColor = COLOR_RED })
        else
            local nextCost = required
            if nextCost then
                hintLabel_:SetText("下一级消耗: " .. FormatPoints(nextCost) .. " 灵液")
            else
                hintLabel_:SetText("")
            end
            hintLabel_:SetStyle({ fontColor = COLOR_GRAY })
        end
    end
end

-- ── 丹药投入操作 ──────────────────────────────────────────────────

local function DoConvert(pillId, count)
    local ok, msg = YaochiWashSystem.ConvertPills(pillId, count)
    if ok then
        -- 浮动文字提示
        local CombatSystem = require("systems.CombatSystem")
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg, COLOR_GREEN, 1.5)
        end
    else
        local CombatSystem = require("systems.CombatSystem")
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg, COLOR_RED, 1.5)
        end
    end
    RefreshPanel()
end

--- 确认弹窗（高价丹药）
local function ShowConfirm(pillId, count)
    if confirmPanel_ then
        confirmPanel_:Remove()
        confirmPanel_ = nil
    end

    local pillName = GetPillName(pillId)

    confirmPanel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 1100,
        onClick = function(self)
            confirmPanel_:Remove()
            confirmPanel_ = nil
        end,
        children = {
            UI.Panel {
                width = 380,
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 200, 80, 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function(self) end, -- 阻止冒泡
                children = {
                    UI.Label {
                        text = "⚠️ 确认化为灵液",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = COLOR_GOLD,
                        textAlign = "center",
                        width = "100%",
                    },
                    UI.Label {
                        text = "确定要将 " .. count .. " 颗" .. pillName .. "化为灵液吗？\n此操作不可逆。",
                        fontSize = T.fontSize.md,
                        fontColor = COLOR_WHITE,
                        lineHeight = 1.5,
                        textAlign = "center",
                        width = "100%",
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "center",
                        gap = T.spacing.md,
                        children = {
                            UI.Button {
                                text = "确定",
                                width = 120,
                                height = 40,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = {200, 160, 40, 255},
                                onClick = function(self)
                                    confirmPanel_:Remove()
                                    confirmPanel_ = nil
                                    DoConvert(pillId, count)
                                end,
                            },
                            UI.Button {
                                text = "取消",
                                width = 120,
                                height = 40,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {80, 80, 100, 255},
                                onClick = function(self)
                                    confirmPanel_:Remove()
                                    confirmPanel_ = nil
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    parentOverlay_:AddChild(confirmPanel_)
end

--- 尝试投入丹药（含高价丹药确认）
local function TryConvert(pillId, count)
    local available = YaochiWashSystem.GetPillCount(pillId)
    if available <= 0 then return end
    count = math.min(count, available)
    if count <= 0 then return end

    if YaochiWashSystem.HIGH_VALUE_PILLS[pillId] then
        ShowConfirm(pillId, count)
    else
        DoConvert(pillId, count)
    end
end

-- ── 仪式画面 ──────────────────────────────────────────────────────

local function ShowRitualPanel()
    if ritualPanel_ then
        ritualPanel_:Show()
        return
    end

    ritualPanel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = COLOR_RITUAL_BG,
        zIndex = 1050,
        children = {
            UI.Panel {
                width = 420,
                alignItems = "center",
                gap = T.spacing.lg,
                children = {
                    -- 标题
                    UI.Label {
                        text = "🌊 瑶池洗髓 🌊",
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = COLOR_GOLD,
                        textAlign = "center",
                        width = "100%",
                    },
                    -- 装饰文字
                    UI.Label {
                        text = "天地灵液洗炼筋骨，脱胎换骨破凡尘...",
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 160, 220, 200},
                        textAlign = "center",
                        width = "100%",
                    },
                    -- 淬炼配图
                    UI.Panel {
                        width = 300,
                        height = 400,
                        borderRadius = T.radius.md,
                        backgroundImage = "Textures/yaochi_ritual.png",
                    },
                    -- 进度条背景
                    UI.Panel {
                        width = "90%", height = 24,
                        backgroundColor = COLOR_BAR_BG,
                        borderRadius = T.radius.sm,
                        overflow = "hidden",
                        children = {
                            -- 进度条填充（通过 ref 更新宽度）
                            (function()
                                ritualBar_ = UI.Panel {
                                    width = "0%", height = "100%",
                                    backgroundColor = COLOR_RITUAL_BAR,
                                    borderRadius = T.radius.sm,
                                }
                                return ritualBar_
                            end)(),
                        },
                    },
                    -- 读条文字
                    (function()
                        ritualText_ = UI.Label {
                            text = "洗髓淬炼中... 20s",
                            fontSize = T.fontSize.md,
                            fontColor = COLOR_WHITE,
                            textAlign = "center",
                            width = "100%",
                        }
                        return ritualText_
                    end)(),
                    -- 百分比
                    (function()
                        ritualPercent_ = UI.Label {
                            text = "0%",
                            fontSize = T.fontSize.lg,
                            fontWeight = "bold",
                            fontColor = COLOR_RITUAL_BAR,
                            textAlign = "center",
                            width = "100%",
                        }
                        return ritualPercent_
                    end)(),
                    -- 间隔
                    UI.Panel { height = 20 },
                    -- 取消按钮
                    UI.Button {
                        text = "取消",
                        width = 160,
                        height = 44,
                        fontSize = T.fontSize.md,
                        borderRadius = T.radius.md,
                        backgroundColor = {100, 60, 60, 200},
                        onClick = function(self)
                            YaochiWashSystem.CancelRitual()
                            if ritualPanel_ then ritualPanel_:Hide() end
                            RefreshPanel()
                        end,
                    },
                },
            },
        },
    }
    parentOverlay_:AddChild(ritualPanel_)
end

local function HideRitualPanel()
    if ritualPanel_ then ritualPanel_:Hide() end
end

local function UpdateRitualPanel()
    if not ritualPanel_ or not YaochiWashSystem.IsRitualActive() then return end

    local progress = YaochiWashSystem.GetRitualProgress()
    local remaining = YaochiWashSystem.GetRitualRemaining()

    if ritualBar_ then
        ritualBar_:SetStyle({ width = tostring(math.floor(progress * 100)) .. "%" })
    end
    if ritualText_ then
        ritualText_:SetText("洗髓淬炼中... " .. math.ceil(remaining) .. "s")
    end
    if ritualPercent_ then
        ritualPercent_:SetText(math.floor(progress * 100) .. "%")
    end
end

-- ── 创建丹药行 ────────────────────────────────────────────────────

local function CreatePillRow(pillId)
    local pillName = GetPillName(pillId)
    local value = YaochiWashSystem.PILL_VALUES[pillId]
    local count = YaochiWashSystem.GetPillCount(pillId)

    local countLabel

    local row = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        paddingLeft = T.spacing.xs,
        paddingRight = T.spacing.xs,
        height = 36,
        children = {
            -- 丹药名
            UI.Label {
                text = pillName,
                fontSize = T.fontSize.sm,
                fontColor = COLOR_WHITE,
                width = 80,
            },
            -- 数量
            (function()
                countLabel = UI.Label {
                    text = "×" .. count,
                    fontSize = T.fontSize.sm,
                    fontColor = count > 0 and COLOR_WHITE or COLOR_GRAY,
                    width = 50,
                }
                return countLabel
            end)(),
            -- 灵韵值
            UI.Label {
                text = "(" .. value .. "/颗)",
                fontSize = T.fontSize.xs,
                fontColor = {160, 150, 200, 200},
                width = 60,
            },
            -- 操作按钮
            UI.Button {
                text = "+1",
                width = 38, height = 28,
                fontSize = T.fontSize.xs,
                borderRadius = T.radius.sm,
                backgroundColor = {70, 60, 120, 255},
                onClick = function(self) TryConvert(pillId, 1) end,
            },
            UI.Button {
                text = "+10",
                width = 42, height = 28,
                fontSize = T.fontSize.xs,
                borderRadius = T.radius.sm,
                backgroundColor = {70, 60, 120, 255},
                onClick = function(self) TryConvert(pillId, 10) end,
            },
            UI.Button {
                text = "全部",
                width = 46, height = 28,
                fontSize = T.fontSize.xs,
                borderRadius = T.radius.sm,
                backgroundColor = {90, 70, 140, 255},
                onClick = function(self)
                    local all = YaochiWashSystem.GetPillCount(pillId)
                    if all > 0 then TryConvert(pillId, all) end
                end,
            },
        },
    }

    table.insert(pillRows_, {
        pillId = pillId,
        countLabel = countLabel,
        row = row,
    })

    return row
end

-- ── 公开接口 ──────────────────────────────────────────────────────

--- 初始化面板（在 NPCDialog.Create 时调用）
---@param parentOverlay table
function YaochiWashUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    pillRows_ = {}

    -- 构建丹药行列表
    local pillChildren = {}
    for _, pillId in ipairs(YaochiWashSystem.PILL_ORDER) do
        table.insert(pillChildren, CreatePillRow(pillId))
    end

    -- 主面板
    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 120},
        zIndex = 900,
        visible = false,
        onClick = function(self) YaochiWashUI.Hide() end,
        children = {
            UI.Panel {
                width = T.size.npcPanelMaxW,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {140, 120, 200, 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.sm,
                onClick = function(self) end, -- 阻止冒泡
                children = {
                    -- 标题
                    UI.Label {
                        text = "🌊 瑶池洗髓",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                        textAlign = "center",
                        width = "100%",
                    },
                    -- 洗髓境
                    (function()
                        levelLabel_ = UI.Label {
                            text = "洗髓境 未开  (未淬炼)",
                            fontSize = T.fontSize.md,
                            fontColor = COLOR_GRAY,
                            textAlign = "center",
                            width = "100%",
                        }
                        return levelLabel_
                    end)(),
                    -- 当前境界
                    (function()
                        realmLabel_ = UI.Label {
                            text = "当前境界: ---",
                            fontSize = T.fontSize.sm,
                            fontColor = COLOR_CYAN,
                            textAlign = "center",
                            width = "100%",
                        }
                        return realmLabel_
                    end)(),
                    -- 分隔线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {80, 90, 110, 100},
                    },
                    -- 灵液点数
                    (function()
                        pointsLabel_ = UI.Label {
                            text = "洗髓灵液: 0 / 0",
                            fontSize = T.fontSize.sm,
                            fontColor = COLOR_WHITE,
                            width = "100%",
                        }
                        return pointsLabel_
                    end)(),
                    -- 进度条
                    UI.Panel {
                        width = "100%", height = 18,
                        backgroundColor = COLOR_BAR_BG,
                        borderRadius = T.radius.sm,
                        overflow = "hidden",
                        children = {
                            (function()
                                progressFill_ = UI.Panel {
                                    width = "0%", height = "100%",
                                    backgroundColor = COLOR_BAR_FILL,
                                    borderRadius = T.radius.sm,
                                }
                                return progressFill_
                            end)(),
                            (function()
                                progressText_ = UI.Label {
                                    text = "0%",
                                    fontSize = T.fontSize.xs,
                                    fontColor = COLOR_WHITE,
                                    position = "absolute",
                                    width = "100%",
                                    textAlign = "center",
                                }
                                return progressText_
                            end)(),
                        },
                    },
                    -- 分隔线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {80, 90, 110, 100},
                    },
                    -- 提示
                    UI.Label {
                        text = "⚠ 丹药应优先用于境界突破，多余丹药可化为灵液。",
                        fontSize = T.fontSize.xs,
                        fontColor = {255, 200, 100, 200},
                        width = "100%",
                    },
                    -- 丹药行标题
                    UI.Label {
                        text = "化为灵液:",
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = COLOR_WHITE,
                        width = "100%",
                    },
                    -- 丹药行列表
                    table.unpack(pillChildren),
                },
            },
        },
    }

    -- 丹药行后面的元素需要单独添加（因为 table.unpack 必须在最后）
    -- 找到内容面板
    local contentPanel = panel_.children[1]

    -- 分隔线
    contentPanel:AddChild(UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 100},
    })

    -- 操作按钮行
    ritualBtn_ = UI.Button {
        text = "洗髓淬炼",
        width = "100%",
        height = 44,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = {160, 120, 255, 255},
        onClick = function(self)
            local canDo, reason = YaochiWashSystem.CanPerformRitual()
            if not canDo then
                local CombatSystem = require("systems.CombatSystem")
                local player = GameState.player
                if player then
                    CombatSystem.AddFloatingText(player.x, player.y - 0.5,
                        reason or "无法淬炼", COLOR_RED, 1.5)
                end
                return
            end
            local ok, err = YaochiWashSystem.StartRitual()
            if ok then
                ShowRitualPanel()
            end
        end,
    }
    contentPanel:AddChild(ritualBtn_)

    -- 底部提示
    hintLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = COLOR_GRAY,
        textAlign = "center",
        width = "100%",
    }
    contentPanel:AddChild(hintLabel_)

    -- 关闭提示
    contentPanel:AddChild(UI.Label {
        text = "点击空白处关闭",
        fontSize = T.fontSize.xs,
        fontColor = {120, 120, 140, 150},
        textAlign = "center",
        width = "100%",
    })

    parentOverlay:AddChild(panel_)

    -- 事件订阅
    EventBus.On("yaochi_wash_level_up", function(level)
        HideRitualPanel()
        RefreshPanel()
        -- 等级提升浮动提示
        local CombatSystem = require("systems.CombatSystem")
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 0.8,
                "洗髓境 第" .. level .. "重 (灵体增减伤 +" .. level .. "%)", COLOR_GOLD, 2.5)
        end
    end)

    EventBus.On("yaochi_wash_ritual_cancelled", function()
        HideRitualPanel()
        RefreshPanel()
    end)
end

--- 显示面板
function YaochiWashUI.Show(npc)
    if not panel_ then return end
    if visible_ then return end
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "yaochi_wash"
    RefreshPanel()
end

--- 隐藏面板
function YaochiWashUI.Hide()
    if not panel_ or not visible_ then return end
    -- 如果淬炼中，不允许关闭主面板
    if YaochiWashSystem.IsRitualActive() then return end
    visible_ = false
    panel_:Hide()
    if confirmPanel_ then
        confirmPanel_:Remove()
        confirmPanel_ = nil
    end
    if GameState.uiOpen == "yaochi_wash" then
        GameState.uiOpen = nil
    end
end

--- 是否可见
---@return boolean
function YaochiWashUI.IsVisible()
    return visible_
end

--- 销毁
function YaochiWashUI.Destroy()
    if panel_ then
        panel_:Remove()
        panel_ = nil
    end
    if ritualPanel_ then
        ritualPanel_:Remove()
        ritualPanel_ = nil
    end
    if confirmPanel_ then
        confirmPanel_:Remove()
        confirmPanel_ = nil
    end
    visible_ = false
    pillRows_ = {}
    pointsLabel_ = nil
    progressBar_ = nil
    progressFill_ = nil
    progressText_ = nil
    levelLabel_ = nil
    realmLabel_ = nil
    ritualBtn_ = nil
    hintLabel_ = nil
    ritualBar_ = nil
    ritualText_ = nil
    ritualPercent_ = nil
end

--- 帧更新（由外部调用以更新仪式读条）
function YaochiWashUI.Update(dt)
    if YaochiWashSystem.IsRitualActive() then
        YaochiWashSystem.Update(dt)
        UpdateRitualPanel()
    end
end

return YaochiWashUI
