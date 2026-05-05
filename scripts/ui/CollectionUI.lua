-- ============================================================================
-- CollectionUI.lua - 神兵图录 UI 面板
-- 展示所有独特装备图鉴，支持上交收录
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CollectionSystem = require("systems.CollectionSystem")
local CombatSystem = require("systems.CombatSystem")
local T = require("config.UITheme")
local StatNames = require("utils.StatNames")

local CollectionUI = {}

local panel_ = nil
local visible_ = false
local entryWidgets_ = {}  -- { [equipId] = entryPanel }
local currentChapter_ = 1  -- 当前选中的章节索引
local collTabBtns_ = {}    -- 章节标签按钮引用
local collScrollContent_ = nil  -- 图录列表滚动内容容器

-- 装备槽位 emoji 映射
local SLOT_EMOJI = {
    weapon = "⚔️", helmet = "🪖", armor = "🛡️", shoulder = "🦺",
    belt = "🎗️", boots = "👢", ring1 = "💍", ring2 = "💍",
    necklace = "📿", cape = "🧣", treasure = "🏺", exclusive = "✨",
}

-- 属性名映射（来自共享模块）
local STAT_LABELS = StatNames.SHORT_NAMES
local STAT_COLORS = StatNames.COLORS

--- 格式化属性奖励为文字
---@param bonus table
---@return string
local function FormatBonus(bonus)
    local parts = {}
    local order = {"atk", "def", "maxHp", "hpRegen", "fortune", "killHeal", "heavyHit", "critRate", "wisdom", "constitution", "physique"}
    for _, key in ipairs(order) do
        local val = bonus[key]
        if val and val > 0 then
            local label = STAT_LABELS[key] or key
            if key == "critRate" then
                table.insert(parts, label .. "+" .. string.format("%d%%", math.floor(val * 100)))
            elseif key == "hpRegen" then
                table.insert(parts, label .. "+" .. string.format("%.1f", val))
            else
                table.insert(parts, label .. "+" .. tostring(math.floor(val)))
            end
        end
    end
    return table.concat(parts, "  ")
end

--- 创建单个图录条目 Widget
---@param equipId string
---@return table widget
local function CreateEntryWidget(equipId)
    local template = EquipmentData.SpecialEquipment[equipId]
    local entry = EquipmentData.Collection.entries[equipId]
    if not template or not entry then return UI.Panel {} end

    local isCollected = CollectionSystem.IsCollected(equipId)
    local qualityColor = GameConfig.QUALITY[template.quality]
        and GameConfig.QUALITY[template.quality].color
        or {200, 200, 200, 255}
    local qualityName = GameConfig.QUALITY[template.quality]
        and GameConfig.QUALITY[template.quality].name
        or "普通"

    -- 状态标记
    local statusText, statusColor
    if isCollected then
        statusText = "已收录"
        statusColor = {100, 255, 150, 255}
    else
        local hasInBag = CollectionSystem.FindInBackpack(equipId) ~= nil
        if hasInBag then
            statusText = "可收录"
            statusColor = {255, 220, 100, 255}
        else
            statusText = "未获得"
            statusColor = {120, 120, 120, 200}
        end
    end

    -- 装备名区域
    local nameColor = isCollected and qualityColor or {120, 120, 120, 200}

    local entryPanel = UI.Panel {
        id = "coll_entry_" .. equipId,
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        padding = T.spacing.sm,
        backgroundColor = isCollected and {35, 45, 40, 220} or {30, 30, 35, 200},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = isCollected and {80, 180, 100, 120} or {60, 60, 70, 100},
        children = {
            -- 装备图标（emoji + 品质边框）
            UI.Panel {
                width = 44,
                height = 44,
                backgroundColor = {20, 22, 30, 255},
                borderRadius = T.radius.sm,
                borderWidth = 2,
                borderColor = isCollected and qualityColor or {60, 60, 70, 150},
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = SLOT_EMOJI[template.slot] or "?",
                        fontSize = 22,
                    },
                },
            },
            -- 装备信息
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                gap = 2,
                children = {
                    -- 第一行：名称 + 品质
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        children = {
                            UI.Label {
                                text = template.name,
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = nameColor,
                            },
                            UI.Label {
                                text = "[" .. qualityName .. "]",
                                fontSize = T.fontSize.xs,
                                fontColor = isCollected and qualityColor or {100, 100, 100, 180},
                            },
                        },
                    },
                    -- 第二行：收集奖励
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 2,
                        children = {
                            UI.Label {
                                text = "收集奖励：",
                                fontSize = T.fontSize.xs,
                                fontColor = isCollected and {160, 180, 140, 220} or {100, 100, 100, 180},
                            },
                            UI.Label {
                                text = FormatBonus(entry.bonus),
                                fontSize = T.fontSize.xs,
                                fontColor = isCollected and {200, 220, 180, 255} or {100, 100, 100, 180},
                            },
                        },
                    },
                    -- 第三行：描述
                    UI.Label {
                        text = isCollected and entry.desc or "收录后解锁详情",
                        fontSize = T.fontSize.xs,
                        fontColor = {140, 140, 140, 180},
                    },
                },
            },
            -- 状态/操作按钮
            UI.Panel {
                width = 64,
                alignItems = "center",
                justifyContent = "center",
                children = {
                    isCollected and UI.Label {
                        text = statusText,
                        fontSize = T.fontSize.xs,
                        fontColor = statusColor,
                    } or UI.Button {
                        id = "coll_btn_" .. equipId,
                        text = statusText,
                        width = 60,
                        height = 28,
                        fontSize = T.fontSize.xs,
                        borderRadius = T.radius.sm,
                        backgroundColor = (statusText == "可收录")
                            and {160, 120, 30, 255}
                            or {50, 50, 55, 180},
                        fontColor = statusColor,
                        onClick = function(self)
                            CollectionUI.DoSubmit(equipId)
                        end,
                    },
                },
            },
        },
    }

    return entryPanel
end

--- 格式化单个属性值
--- 格式化属性值（来自共享模块）
local FormatStatValue = StatNames.FormatValue

--- 创建总加成提示面板（双列显示，包含全部属性）
---@return table widget
local function CreateBonusSummaryPanel()
    local summary = CollectionSystem.GetBonusSummary()
    local collected = CollectionSystem.GetCollectedCount()
    local total = CollectionSystem.GetTotalCount()

    -- 全部属性列表（按显示顺序）
    local order = {"atk", "def", "maxHp", "hpRegen", "fortune", "killHeal", "heavyHit", "critRate", "wisdom", "constitution", "physique"}

    -- 收集有值的属性
    local activeStats = {}
    for _, key in ipairs(order) do
        local val = summary[key] or 0
        if val > 0 then
            table.insert(activeStats, { key = key, val = val })
        end
    end

    -- 如果没有任何加成
    if #activeStats == 0 then
        return UI.Panel {
            id = "coll_summary",
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
                            text = "图录总加成",
                            fontSize = T.fontSize.sm,
                            fontWeight = "bold",
                            fontColor = {180, 255, 200, 255},
                        },
                        UI.Label {
                            id = "coll_progress",
                            text = collected .. "/" .. total,
                            fontSize = T.fontSize.xs,
                            fontColor = {180, 180, 180, 220},
                        },
                    },
                },
                UI.Label {
                    text = "暂无加成",
                    fontSize = T.fontSize.xs,
                    fontColor = {120, 120, 120, 180},
                },
            },
        }
    end

    -- 双列布局：每行放两个属性
    local rows = {}
    for i = 1, #activeStats, 2 do
        local left = activeStats[i]
        local right = activeStats[i + 1]

        local leftLabel = STAT_LABELS[left.key] or left.key
        local leftColor = STAT_COLORS[left.key] or {200, 200, 200, 255}
        local leftVal = FormatStatValue(left.key, left.val)

        local leftCell = UI.Panel {
            flexDirection = "row",
            flexGrow = 1,
            flexBasis = 0,
            justifyContent = "space-between",
            children = {
                UI.Label {
                    text = leftLabel,
                    fontSize = T.fontSize.xs,
                    fontColor = leftColor,
                },
                UI.Label {
                    text = leftVal,
                    fontSize = T.fontSize.xs,
                    fontColor = {220, 220, 220, 255},
                },
            },
        }

        local rightCell
        if right then
            local rightLabel = STAT_LABELS[right.key] or right.key
            local rightColor = STAT_COLORS[right.key] or {200, 200, 200, 255}
            local rightVal = FormatStatValue(right.key, right.val)
            rightCell = UI.Panel {
                flexDirection = "row",
                flexGrow = 1,
                flexBasis = 0,
                justifyContent = "space-between",
                children = {
                    UI.Label {
                        text = rightLabel,
                        fontSize = T.fontSize.xs,
                        fontColor = rightColor,
                    },
                    UI.Label {
                        text = rightVal,
                        fontSize = T.fontSize.xs,
                        fontColor = {220, 220, 220, 255},
                    },
                },
            }
        else
            rightCell = UI.Panel { flexGrow = 1, flexBasis = 0 }
        end

        table.insert(rows, UI.Panel {
            flexDirection = "row",
            gap = T.spacing.md,
            children = { leftCell, rightCell },
        })
    end

    return UI.Panel {
        id = "coll_summary",
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
                        text = "图录总加成",
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = {180, 255, 200, 255},
                    },
                    UI.Label {
                        id = "coll_progress",
                        text = collected .. "/" .. total,
                        fontSize = T.fontSize.xs,
                        fontColor = collected >= total and {255, 215, 0, 255} or {180, 180, 180, 220},
                    },
                },
            },
            table.unpack(rows),
        },
    }
end

-- ============================================================================
-- 章节切页
-- ============================================================================

--- 构建当前章节的条目列表
---@param chapterIndex number|nil 默认当前章节
---@return table[] children
local function BuildChapterEntries(chapterIndex)
    chapterIndex = chapterIndex or currentChapter_
    local chapters = EquipmentData.Collection.chapters
    local ch = chapters[chapterIndex]
    if not ch then return {} end

    local items = {}
    for _, equipId in ipairs(ch.order) do
        local widget = CreateEntryWidget(equipId)
        entryWidgets_[equipId] = widget
        table.insert(items, widget)
    end
    return items
end

--- 刷新图录内容（切换章节时调用）
local function RefreshCollectionContent()
    if not collScrollContent_ then return end
    collScrollContent_:ClearChildren()
    entryWidgets_ = {}
    local items = BuildChapterEntries(currentChapter_)
    for _, child in ipairs(items) do
        collScrollContent_:AddChild(child)
    end
    -- 更新标签按钮样式
    for i, btn in ipairs(collTabBtns_) do
        if i == currentChapter_ then
            btn:SetStyle({ backgroundColor = {100, 140, 255, 220} })
        else
            btn:SetStyle({ backgroundColor = {55, 58, 70, 200} })
        end
    end
end

--- 创建章节标签栏
---@return table Widget
local function BuildCollectionTabs()
    local tabChildren = {}
    local chapters = EquipmentData.Collection.chapters
    for i, ch in ipairs(chapters) do
        local isActive = (i == currentChapter_)
        local btn = UI.Button {
            text = ch.name,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            height = 32,
            flexGrow = 1,
            borderRadius = T.radius.sm,
            backgroundColor = isActive and {100, 140, 255, 220} or {55, 58, 70, 200},
            onClick = function(self)
                if currentChapter_ == i then return end
                currentChapter_ = i
                RefreshCollectionContent()
            end,
        }
        collTabBtns_[i] = btn
        table.insert(tabChildren, btn)
    end
    return UI.Panel {
        flexDirection = "row",
        gap = T.spacing.sm,
        children = tabChildren,
    }
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 创建图录面板
---@param parentOverlay table
function CollectionUI.Create(parentOverlay)
    panel_ = UI.Panel {
        id = "collectionPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = {0, 0, 0, 150},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self) end,  -- 阻止穿透
        children = {
            -- 内容卡片
            UI.Panel {
                id = "collectionCard",
                width = "94%",
                maxWidth = 500,
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
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self)
                                    CollectionUI.Hide()
                                end,
                            },
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = T.spacing.sm,
                                children = {
                                    UI.Label {
                                        text = "📜",
                                        fontSize = T.fontSize.xl,
                                    },
                                    UI.Label {
                                        text = "神兵图录",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                },
                            },
                        },
                    },
                    -- 副标题说明
                    UI.Label {
                        text = "上交独特装备，获得永久属性加成",
                        fontSize = T.fontSize.xs,
                        fontColor = {150, 150, 150, 200},
                        textAlign = "center",
                    },
                    -- 总加成面板
                    UI.Panel {
                        id = "coll_summary_container",
                    },
                    -- 章节切换标签
                    BuildCollectionTabs(),
                    -- 图录列表（可滚动）
                    (function()
                        collScrollContent_ = UI.Panel {
                            id = "coll_list",
                            gap = T.spacing.xs,
                            paddingRight = T.spacing.xs,
                            children = BuildChapterEntries(),
                        }
                        return UI.ScrollView {
                            id = "coll_scroll",
                            flexGrow = 1,
                            flexShrink = 1,
                            flexBasis = 0,
                            children = { collScrollContent_ },
                        }
                    end)(),
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)

    -- 监听收录事件刷新
    EventBus.On("collection_submitted", function()
        if visible_ then
            CollectionUI.Refresh()
        end
    end)
end

--- 显示图录面板
function CollectionUI.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "collection"
    CollectionUI.Refresh()
end

--- 隐藏图录面板
function CollectionUI.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    if GameState.uiOpen == "collection" then
        GameState.uiOpen = nil
    end
end

--- 切换显示/隐藏
function CollectionUI.Toggle()
    if visible_ then CollectionUI.Hide() else CollectionUI.Show() end
end

--- 是否可见
---@return boolean
function CollectionUI.IsVisible()
    return visible_
end

--- 刷新整个面板（重建列表）
function CollectionUI.Refresh()
    if not panel_ then return end

    -- 刷新总加成
    local summaryContainer = panel_:FindById("coll_summary_container")
    if summaryContainer then
        summaryContainer:ClearChildren()
        summaryContainer:AddChild(CreateBonusSummaryPanel())
    end

    -- 刷新当前章节列表
    RefreshCollectionContent()
end

--- 上交装备
---@param equipId string
function CollectionUI.DoSubmit(equipId)
    local ok, msg = CollectionSystem.Submit(equipId)
    local player = GameState.player
    if player then
        if ok then
            local template = EquipmentData.SpecialEquipment[equipId]
            local entry = EquipmentData.Collection.entries[equipId]
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "图录收录: " .. (template and template.name or equipId),
                {255, 220, 100, 255}, 2.5
            )
            -- 显示获得的加成
            if entry then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 0.5,
                    FormatBonus(entry.bonus),
                    {150, 255, 180, 255}, 2.0
                )
            end
        else
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.5,
                msg,
                {255, 100, 100, 255}, 1.5
            )
        end
    end

    -- 上交成功后存档（装备已从背包移除，需持久化）
    if ok then
        print("[CollectionUI] Collection submitted, requesting save")
        EventBus.Emit("save_request")
    end

    -- 刷新面板
    CollectionUI.Refresh()
end

return CollectionUI
