-- ============================================================================
-- CollectionUI.lua - 神兵图录 UI 面板
-- 展示所有独特装备图鉴，支持上交收录
-- 使用 PanelShell 标准面板骨架 + ImageItemSlot 规范装备图标
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
local PanelShell = require("ui.components.PanelShell")
local ImageItemSlot = require("ui.ImageItemSlot")

local CollectionUI = {}

local shell_ = nil       -- PanelShell 实例
local visible_ = false
local entryWidgets_ = {}  -- { [equipId] = entryPanel }
local currentChapter_ = 1  -- 当前选中的章节索引
local collTabBtns_ = {}    -- 章节标签按钮引用
local collScrollContent_ = nil  -- 章节列表内容容器（shell contentPanel 内部）

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
        statusColor = T.color.success
    else
        local hasInBag = CollectionSystem.FindInBackpack(equipId) ~= nil
        if hasInBag then
            statusText = "可收录"
            statusColor = T.color.warning
        else
            statusText = "未获得"
            statusColor = T.color.disabled
        end
    end

    -- 装备名区域
    local nameColor = isCollected and qualityColor or T.color.disabled

    -- 右侧状态/操作区域
    local statusWidget
    if isCollected then
        statusWidget = UI.Label {
            text = statusText,
            fontSize = T.fontSize.xs,
            fontColor = statusColor,
        }
    elseif statusText == "可收录" then
        statusWidget = UI.Button {
            id = "coll_btn_" .. equipId,
            text = statusText,
            width = T.size.inlineBtnW,
            height = T.size.inlineBtnH,
            fontSize = T.fontSize.xs,
            borderRadius = T.radius.sm,
            backgroundColor = T.color.btnSpend,
            fontColor = statusColor,
            onClick = function(self)
                CollectionUI.DoSubmit(equipId)
            end,
        }
    else
        -- 未获得：用 Label 而非按钮（不可操作）
        statusWidget = UI.Label {
            text = statusText,
            fontSize = T.fontSize.xs,
            fontColor = statusColor,
        }
    end

    -- 构造 item 数据供 ImageItemSlot 渲染（无论是否收录都显示图标）
    -- 法宝条目没有 icon 字段，需从 FabaoTemplates.iconByTier 查找
    local iconPath = template.icon
    if not iconPath and template.isFabaoCollection then
        local fabaoTpl = EquipmentData.FabaoTemplates
            and EquipmentData.FabaoTemplates[template.fabaoTemplateId]
        if fabaoTpl and fabaoTpl.iconByTier then
            iconPath = fabaoTpl.iconByTier[template.fabaoTier]
        end
    end
    local slotItem = {
        icon = iconPath,
        quality = template.quality,
        name = template.name,
    }

    local entryPanel = UI.Panel {
        id = "coll_entry_" .. equipId,
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        padding = T.spacing.sm,
        backgroundColor = isCollected and T.color.collectedBg or T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = isCollected and T.color.collectedBorder or T.color.borderLight,
        children = {
            -- 装备图标（使用 ImageItemSlot 规范组件）
            ImageItemSlot {
                size = T.size.slotSize,
                item = slotItem,
                pointerEvents = "none",
            },
            -- 装备信息
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                gap = T.spacing.xxs,
                children = {
                    -- 第一行：名称 + 品质
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        children = {
                            ---@diagnostic disable-next-line: param-type-mismatch
                            UI.Label {
                                text = template.name,
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = nameColor,
                            },
                            UI.Label {
                                text = "[" .. qualityName .. "]",
                                fontSize = T.fontSize.xs,
                                fontColor = isCollected and qualityColor or T.color.textMuted,
                            },
                        },
                    },
                    -- 第二行：收集奖励
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.xxs,
                        children = {
                            UI.Label {
                                text = "收集奖励：",
                                fontSize = T.fontSize.xs,
                                fontColor = isCollected and T.color.bonusLabel or T.color.textMuted,
                            },
                            UI.Label {
                                text = FormatBonus(entry.bonus),
                                fontSize = T.fontSize.xs,
                                fontColor = isCollected and T.color.bonusValue or T.color.textMuted,
                            },
                        },
                    },
                    -- 第三行：描述
                    ---@diagnostic disable-next-line: param-type-mismatch
                    UI.Label {
                        text = isCollected and entry.desc or "收录后解锁详情",
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textMuted,
                    },
                },
            },
            -- 状态/操作
            UI.Panel {
                width = 64,
                alignItems = "center",
                justifyContent = "center",
                children = { statusWidget },
            },
        },
    }

    return entryPanel
end

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
            backgroundColor = T.color.summaryBg,
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = T.color.summaryBorder,
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
                            fontColor = T.color.titleText,
                        },
                        UI.Label {
                            id = "coll_progress",
                            text = collected .. "/" .. total,
                            fontSize = T.fontSize.xs,
                            fontColor = T.color.textSecondary,
                        },
                    },
                },
                UI.Label {
                    text = "暂无加成",
                    fontSize = T.fontSize.xs,
                    fontColor = T.color.textMuted,
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
                    fontColor = T.color.textPrimary,
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
                        fontColor = T.color.textPrimary,
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
        backgroundColor = T.color.summaryBg,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.summaryBorder,
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
                        fontColor = T.color.titleText,
                    },
                    UI.Label {
                        id = "coll_progress",
                        text = collected .. "/" .. total,
                        fontSize = T.fontSize.xs,
                        fontColor = collected >= total and T.color.gold or T.color.textSecondary,
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
            btn:SetStyle({ backgroundColor = T.color.tabActiveBg })
        else
            btn:SetStyle({ backgroundColor = T.color.tabInactiveBg })
        end
    end
end

--- 创建章节标签栏
---@return table Widget
local function BuildCollectionTabs()
    collTabBtns_ = {}
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
            backgroundColor = isActive and T.color.tabActiveBg or T.color.tabInactiveBg,
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

--- 创建图录面板（基于 PanelShell 标准骨架）
---@param parentOverlay table
function CollectionUI.Create(parentOverlay)
    local PORTRAIT_SIZE = 64
    local portraitPanel = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        overflow = "hidden",
        backgroundImage = "book_atk.png",
        backgroundFit = "cover",
    }

    shell_ = PanelShell.Create({
        title = "神兵图录",
        subtitle = "上交独特装备，获得永久属性加成",
        portrait = portraitPanel,
        onClose = function() CollectionUI.Hide() end,
        parent = parentOverlay,
    })

    -- 向 shell 内容区添加：总加成面板 + 章节标签 + 列表
    local summaryContainer = UI.Panel { id = "coll_summary_container" }
    shell_:AddContent(summaryContainer)
    shell_:AddContent(BuildCollectionTabs())

    -- 图录列表容器（手动管理子节点刷新）
    collScrollContent_ = UI.Panel {
        id = "coll_list",
        gap = T.spacing.xs,
        children = BuildChapterEntries(),
    }
    shell_:AddContent(collScrollContent_)

    -- 监听收录事件刷新
    EventBus.On("collection_submitted", function()
        if visible_ then
            CollectionUI.Refresh()
        end
    end)
end

--- 显示图录面板
function CollectionUI.Show()
    if not shell_ or visible_ then return end
    visible_ = true
    shell_:Show()
    GameState.uiOpen = "collection"
    CollectionUI.Refresh()
end

--- 隐藏图录面板
function CollectionUI.Hide()
    if not shell_ or not visible_ then return end
    visible_ = false
    shell_:Hide()
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
    if not shell_ then return end

    -- 刷新总加成
    local summaryContainer = shell_.contentPanel:FindById("coll_summary_container")
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
