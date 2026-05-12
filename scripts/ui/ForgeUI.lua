-- ============================================================================
-- ForgeUI.lua - 锻造师洗练面板
-- 每件装备可额外洗练1条副属性，洗练池 = EquipmentData.SUB_STATS
-- 优先展示身上装备，其次展示背包内装备
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local EventBus = require("core.EventBus")
local SaveSession = require("systems.save.SaveSession")
local T = require("config.UITheme")
local StatNames = require("utils.StatNames")

local ForgeUI = {}

local panel_ = nil
local visible_ = false
local listPanel_ = nil
local detailPanel_ = nil
local selectedItem_ = nil     -- 当前选中的装备引用
local selectedSource_ = nil   -- "equipment" | "inventory"
local selectedSlot_ = nil     -- 装备槽位id 或 背包索引
local resultLabel_ = nil      -- 底部结果提示标签
local lastForgeTime_ = 0      -- 上次洗练时间戳（防连点）
local FORGE_THROTTLE = 0.5    -- 洗练最小间隔（秒）

-- 洗练费用（按阶级，与 TIER_MULTIPLIER 增长对齐）
local FORGE_COST = {
    [1]  = 500,
    [2]  = 1000,
    [3]  = 2000,
    [4]  = 4000,
    [5]  = 8000,
    [6]  = 15000,
    [7]  = 25000,
    [8]  = 40000,
    [9]  = 60000,
    [10] = 100000,
    [11] = 160000,
}

-- 装备槽位 emoji 映射（用于列表显示，替代图片路径）
local SLOT_EMOJI = {
    weapon = "⚔️", helmet = "🪖", armor = "🛡️", shoulder = "🦺",
    belt = "🎗️", boots = "👢", ring1 = "💍", ring2 = "💍",
    necklace = "📿", cape = "🧣", treasure = "🏺", exclusive = "✨",
}

-- ============================================================================
-- 洗练逻辑
-- ============================================================================

--- 获取洗练费用
---@param item table
---@return number
local function GetForgeCost(item)
    return FORGE_COST[item.tier or 1] or 50
end

--- 计算某属性在指定 tier 下的洗练值范围文本
---@param statId string
---@param tier number
---@return string rangeText "（下限~上限）"
local function GetForgeRangeText(statId, tier)
    local baseDef = nil
    for _, sub in ipairs(EquipmentData.SUB_STATS) do
        if sub.stat == statId then baseDef = sub; break end
    end
    if not baseDef then return "" end

    local tierMult
    if EquipmentData.PCT_STATS[statId] then
        tierMult = EquipmentData.PCT_SUB_TIER_MULT[tier or 1] or 1.0
    else
        tierMult = EquipmentData.SUB_STAT_TIER_MULT[tier or 1] or 1.0
    end

    local rawMin = baseDef.baseValue * tierMult * 0.8
    local rawMax = baseDef.baseValue * tierMult * 1.2
    rawMin = math.floor(rawMin * 100 + 0.5) / 100
    rawMax = math.floor(rawMax * 100 + 0.5) / 100
    if rawMin <= 0 then rawMin = 0.01 end
    if rawMax <= 0 then rawMax = 0.01 end

    local isPct = EquipmentData.PCT_STATS[statId]
    local isHpRegen = (statId == "hpRegen")
    if not isPct and not isHpRegen then
        rawMin = math.max(1, math.floor(rawMin + 0.5))
        rawMax = math.max(1, math.floor(rawMax + 0.5))
    end

    local function fmt(val)
        if EquipmentData.PCT_STATS[statId] or EquipmentData.PCT_MAIN_STATS[statId] then
            if statId == "critDmg" then return string.format("%.0f%%", val * 100)
            else return string.format("%.1f%%", val * 100) end
        elseif statId == "hpRegen" then return string.format("%.1f", val)
        else return tostring(math.floor(val))
        end
    end

    return "（" .. fmt(rawMin) .. "~" .. fmt(rawMax) .. "）"
end

--- 随机洗练一条副属性（从副属性池中选，排除主属性和已有副属性）
---@param item table
---@return table|nil newStat {stat, name, value}
local function RollForgeStat(item)
    -- 收集已有属性（主属性 + 副属性）
    local excluded = {}
    if item.mainStat then
        for stat, _ in pairs(item.mainStat) do
            excluded[stat] = true
        end
    end
    if item.subStats then
        for _, sub in ipairs(item.subStats) do
            excluded[sub.stat] = true
        end
    end
    -- 已有洗练属性也排除
    if item.forgeStat then
        excluded[item.forgeStat.stat] = true
    end

    -- 可用池
    local pool = {}
    for _, sub in ipairs(EquipmentData.SUB_STATS) do
        if not excluded[sub.stat] then
            table.insert(pool, sub)
        end
    end

    if #pool == 0 then return nil end

    local pick = pool[math.random(1, #pool)]
    -- 百分比副属性（critRate/critDmg）走独立的平缓倍率表
    local tierMult
    if EquipmentData.PCT_STATS[pick.stat] then
        tierMult = EquipmentData.PCT_SUB_TIER_MULT[item.tier or 1] or 1.0
    else
        tierMult = EquipmentData.SUB_STAT_TIER_MULT[item.tier or 1] or 1.0
    end
    local value = pick.baseValue * tierMult * (0.8 + math.random() * 0.4)
    value = math.floor(value * 100 + 0.5) / 100
    if value <= 0 then value = 0.01 end

    -- 整数类属性（非百分比、非 hpRegen）显示时用 math.floor，
    -- 需要保证洗练值至少为 1，否则会显示"+0"
    if not EquipmentData.PCT_STATS[pick.stat] and pick.stat ~= "hpRegen" then
        value = math.max(1, math.floor(value + 0.5))
    end

    return { stat = pick.stat, name = pick.name, value = value }
end

--- 执行洗练
---@return boolean success
---@return string message
local function DoForge()
    if not selectedItem_ then return false, "请选择装备" end

    local player = GameState.player
    if not player then return false, "错误" end

    local cost = GetForgeCost(selectedItem_)
    if player.gold < cost then
        return false, "金币不足（需要 " .. cost .. "）"
    end

    local newStat = RollForgeStat(selectedItem_)
    if not newStat then
        return false, "该装备无法再洗练新属性"
    end

    -- 扣金币
    player.gold = player.gold - cost

    -- 写入洗练属性
    selectedItem_.forgeStat = newStat

    -- 如果是身上装备，需要刷新属性
    if selectedSource_ == "equipment" then
        InventorySystem.RecalcEquipStats()
    end

    -- 会话式合并保存：洗练属于高频操作，合并落盘（P2优化）
    SaveSession.MarkDirty()

    local rangeText = GetForgeRangeText(newStat.stat, selectedItem_.tier)
    return true, "洗练成功！获得 " .. newStat.name .. " +" .. ForgeUI.FormatStatValue(newStat) .. " " .. rangeText
end

--- 格式化属性值
---@param sub table {stat, value}
---@return string
function ForgeUI.FormatStatValue(sub)
    if EquipmentData.PCT_STATS[sub.stat] or EquipmentData.PCT_MAIN_STATS[sub.stat] then
        -- 百分比属性统一用百分比显示
        if sub.stat == "critDmg" then
            return string.format("%.0f%%", sub.value * 100)
        else
            return string.format("%.1f%%", sub.value * 100)
        end
    elseif sub.stat == "hpRegen" then
        return string.format("%.1f/s", sub.value)
    else
        return tostring(math.floor(sub.value))
    end
end

-- ============================================================================
-- 收集可洗练装备列表
-- ============================================================================

--- 收集所有可洗练装备（身上优先，然后背包）
---@return table[] { {item, source, slotId} }
local function CollectEquipments()
    local list = {}
    local manager = InventorySystem.GetManager()
    if not manager then return list end

    -- 身上装备
    for _, slotId in ipairs(EquipmentData.SLOTS) do
        local item = manager:GetEquipmentItem(slotId)
        if item and item.quality then
            table.insert(list, { item = item, source = "equipment", slotId = slotId })
        end
    end

    -- 背包内装备
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager:GetInventoryItem(i)
        if item and item.quality and item.category ~= "consumable" then
            table.insert(list, { item = item, source = "inventory", slotId = i })
        end
    end

    return list
end

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 创建一个装备行条目
---@param entry table {item, source, slotId}
---@param isSelected boolean
---@return table widget
local function CreateEquipRow(entry, isSelected)
    local item = entry.item
    local qCfg = GameConfig.QUALITY[item.quality]
    local qColor = qCfg and qCfg.color or {200, 200, 200, 255}

    -- 来源标签
    local srcText = entry.source == "equipment" and "[穿戴]" or "[背包]"
    local srcColor = entry.source == "equipment" and {120, 200, 255, 220} or {160, 160, 170, 200}

    -- 洗练状态：显示具体属性
    local forgeTag = ""
    local forgeColor = {0,0,0,0}
    if item.forgeStat then
        forgeTag = " " .. item.forgeStat.name .. "+" .. ForgeUI.FormatStatValue(item.forgeStat)
        forgeColor = {100, 255, 180, 230}
    end

    local bgColor = isSelected and {60, 65, 90, 250} or {35, 40, 55, 220}
    local bdColor = isSelected and {255, 215, 100, 255} or {50, 55, 70, 120}
    local bdWidth = isSelected and 2 or 1

    return UI.Button {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
        paddingTop = 6, paddingBottom = 6,
        backgroundColor = bgColor,
        borderRadius = T.radius.sm,
        borderWidth = bdWidth,
        borderColor = bdColor,
        onClick = function(self)
            selectedItem_ = item
            selectedSource_ = entry.source
            selectedSlot_ = entry.slotId
            ForgeUI.Refresh()
        end,
        children = {
            -- 图标（用 emoji 替代图片路径）
            UI.Label {
                text = SLOT_EMOJI[item.slot] or "📦",
                fontSize = T.fontSize.lg,
                width = 28,
                textAlign = "center",
            },
            -- 名称行
            UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 4,
                        children = {
                            UI.Label {
                                text = item.name,
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = qColor,
                            },
                            UI.Label {
                                text = forgeTag,
                                fontSize = T.fontSize.xs,
                                fontColor = forgeColor,
                            },
                        },
                    },
                    UI.Label {
                        text = srcText,
                        fontSize = T.fontSize.xs,
                        fontColor = srcColor,
                    },
                },
            },
        },
    }
end

---@param parentOverlay table
function ForgeUI.Create(parentOverlay)
    -- 装备列表（可滚动）
    listPanel_ = UI.Panel {
        id = "forge_list",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        gap = T.spacing.xs,
        overflow = "scroll",
    }

    -- 底部详情区
    detailPanel_ = UI.Panel {
        id = "forge_detail",
        width = "100%",
        gap = T.spacing.xs,
        paddingTop = T.spacing.sm,
    }

    -- 结果提示
    resultLabel_ = UI.Label {
        id = "forge_result",
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = {100, 255, 150, 255},
        textAlign = "center",
        height = 16,
    }

    -- 主面板
    panel_ = UI.Panel {
        id = "forgePanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingBottom = T.spacing.xl,
        visible = false,
        zIndex = 100,
        children = {
            -- 内容卡片
            UI.Panel {
                width = "94%",
                maxWidth = T.size.npcPanelMaxW,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.md,
                gap = T.spacing.xs,
                children = {
                    -- 标题栏（关闭按钮在左，标题在右）
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton, height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function() ForgeUI.Hide() end,
                            },
                            UI.Label {
                                text = "🔨 洗练",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = T.color.titleText,
                            },
                        },
                    },
                    -- 说明
                    UI.Label {
                        text = "每件装备可洗练1条额外属性，再次洗练会替换\n洗练不会洗出和主副属性相同的词缀",
                        fontSize = T.fontSize.xs,
                        fontColor = {150, 155, 170, 200},
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {60, 65, 80, 150} },
                    -- 装备列表
                    listPanel_,
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {60, 65, 80, 150} },
                    -- 详情区
                    detailPanel_,
                    -- 结果提示
                    resultLabel_,
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
end

-- ============================================================================
-- 刷新
-- ============================================================================

--- 统一刷新（列表 + 详情）
function ForgeUI.Refresh()
    ForgeUI.RefreshList()
    ForgeUI.RefreshDetail()
end

function ForgeUI.RefreshList()
    if not listPanel_ then return end
    listPanel_:ClearChildren()

    local equips = CollectEquipments()
    if #equips == 0 then
        listPanel_:AddChild(UI.Label {
            text = "没有可洗练的装备",
            fontSize = T.fontSize.sm,
            fontColor = {150, 150, 150, 200},
            textAlign = "center",
            marginTop = T.spacing.lg,
        })
        return
    end

    for _, entry in ipairs(equips) do
        local isSel = (selectedItem_ == entry.item)
        listPanel_:AddChild(CreateEquipRow(entry, isSel))
    end
end

function ForgeUI.RefreshDetail()
    if not detailPanel_ then return end
    detailPanel_:ClearChildren()

    if not selectedItem_ then
        detailPanel_:AddChild(UI.Label {
            text = "点击上方装备进行洗练",
            fontSize = T.fontSize.sm,
            fontColor = {120, 125, 140, 200},
            textAlign = "center",
            marginTop = T.spacing.sm,
            marginBottom = T.spacing.sm,
        })
        return
    end

    local item = selectedItem_
    local qCfg = GameConfig.QUALITY[item.quality]
    local qColor = qCfg and qCfg.color or {200, 200, 200, 255}
    local cost = GetForgeCost(item)

    -- 选中装备信息行
    local infoChildren = {}

    -- 装备名 + 属性摘要（STAT_NAMES 来自共享模块）
    local STAT_NAMES = StatNames.SHORT_NAMES
    local statSummary = ""
    if item.mainStat then
        for stat, val in pairs(item.mainStat) do
            local name = STAT_NAMES[stat] or stat
            if EquipmentData.PCT_MAIN_STATS[stat] then
                statSummary = name .. "+" .. string.format("%.1f%%", val * 100)
            else
                statSummary = name .. "+" .. math.floor(val)
            end
        end
    end

    table.insert(infoChildren, UI.Panel {
        flexDirection = "row", alignItems = "center", justifyContent = "space-between",
        children = {
            UI.Label {
                text = (SLOT_EMOJI[item.slot] or "📦") .. " " .. item.name,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = qColor,
            },
            UI.Label {
                text = statSummary,
                fontSize = T.fontSize.xs,
                fontColor = {255, 220, 150, 230},
            },
        },
    })

    -- 洗练属性显示
    if item.forgeStat then
        table.insert(infoChildren, UI.Panel {
            flexDirection = "row", alignItems = "center", justifyContent = "space-between",
            backgroundColor = {40, 60, 50, 200},
            borderRadius = T.radius.sm,
            paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
            paddingTop = 4, paddingBottom = 4,
            children = {
                UI.Label {
                    text = "洗练属性: " .. item.forgeStat.name .. " +" .. ForgeUI.FormatStatValue(item.forgeStat)
                        .. " " .. GetForgeRangeText(item.forgeStat.stat, item.tier),
                    fontSize = T.fontSize.xs,
                    fontWeight = "bold",
                    fontColor = {100, 255, 180, 255},
                },
                UI.Label {
                    text = "再次洗练替换",
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 200, 100, 160},
                },
            },
        })
    else
        table.insert(infoChildren, UI.Label {
            text = "尚未洗练，点击下方按钮洗练",
            fontSize = T.fontSize.xs,
            fontColor = {150, 155, 170, 180},
        })
    end

    -- 洗练按钮
    local player = GameState.player
    local canAfford = player and player.gold >= cost
    table.insert(infoChildren, UI.Button {
        text = "洗练  💰" .. cost,
        width = "100%",
        height = 36,
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        variant = canAfford and "primary" or "default",
        backgroundColor = canAfford and nil or {60, 60, 60, 200},
        marginTop = T.spacing.xs,
        onClick = function(self)
            local now = time.elapsedTime
            if now - lastForgeTime_ < FORGE_THROTTLE then
                if resultLabel_ then
                    resultLabel_:SetText("操作过快，请稍后")
                    resultLabel_:SetStyle({ fontColor = {255, 200, 100, 255} })
                end
                return
            end
            lastForgeTime_ = now
            local ok, msg = DoForge()
            ForgeUI.Refresh()
            -- 更新结果提示
            if resultLabel_ then
                resultLabel_:SetText(msg)
                resultLabel_:SetStyle({
                    fontColor = ok and {100, 255, 150, 255} or {255, 120, 100, 255},
                })
            end
        end,
    })

    for _, child in ipairs(infoChildren) do
        detailPanel_:AddChild(child)
    end
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function ForgeUI.Show()
    if panel_ and not visible_ then
        visible_ = true
        panel_:Show()
        GameState.uiOpen = "forge"
        selectedItem_ = nil
        selectedSource_ = nil
        selectedSlot_ = nil
        if resultLabel_ then resultLabel_:SetText("") end
        ForgeUI.Refresh()
    end
end

function ForgeUI.Hide()
    if panel_ and visible_ then
        SaveSession.Flush()  -- 关闭 UI 时收口会话脏数据（P2优化）
        visible_ = false
        panel_:Hide()
        if GameState.uiOpen == "forge" then
            GameState.uiOpen = nil
        end
    end
end

function ForgeUI.Toggle()
    if visible_ then ForgeUI.Hide() else ForgeUI.Show() end
end

function ForgeUI.IsVisible()
    return visible_
end

--- 销毁面板（切换角色时调用，重置所有状态）
function ForgeUI.Destroy()
    panel_ = nil
    visible_ = false
    listPanel_ = nil
    detailPanel_ = nil
    selectedItem_ = nil
    selectedSource_ = nil
    selectedSlot_ = nil
    resultLabel_ = nil
end

return ForgeUI
