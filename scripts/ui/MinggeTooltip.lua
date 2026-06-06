---@diagnostic disable
-- ============================================================================
-- MinggeTooltip.lua - 五行命格物品详情浮层
-- ============================================================================
-- 展示命格物品的属性详情，支持装备/卸下/出售操作

local UI = require("urhox-libs/UI")
local MinggeData = require("config.MinggeData")
local MinggeSystem = require("systems.MinggeSystem")
local GameState = require("core.GameState")
local T = require("config.UITheme")

local MinggeTooltip = {}

---@type Panel|nil
local panel_ = nil
---@type Panel|nil
local container_ = nil
---@type function|nil
local onDone_ = nil

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 格式化属性值
local function FormatStatValue(stat, value)
    if MinggeData.PERCENT_STATS[stat] then
        return string.format("+%.1f%%", value * 100)
    elseif MinggeData.DECIMAL_STATS[stat] then
        return string.format("+%.1f", value)
    else
        return "+" .. tostring(math.floor(value))
    end
end

--- 获取品质色
local function GetQualityColor(quality)
    return MinggeData.QUALITY_COLORS[quality] or {200, 200, 200, 255}
end

--- 获取 roll 百分比描述
local function GetRollPercent(item)
    if not item.roll then return "" end
    local ranges = MinggeData.STAT_RANGES[item.tier]
    if not ranges or not ranges[item.stat] then return "" end
    local range = ranges[item.stat][item.quality]
    if not range then return "" end
    local min, max = range[1], range[2]
    if max <= min then return "100%" end
    local pct = (item.value - min) / (max - min) * 100
    return string.format("%.0f%%", pct)
end

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化 Tooltip（挂载到 overlay 层）
---@param parentOverlay Panel
function MinggeTooltip.Init(parentOverlay)
    container_ = parentOverlay

    panel_ = UI.Panel {
        id = "minggeTooltipPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 250,
        onClick = function(self)
            MinggeTooltip.Hide()
        end,
    }

    parentOverlay:AddChild(panel_)
end

-- ============================================================================
-- 显示
-- ============================================================================

--- 显示命格详情
---@param item table 命格物品
---@param source string "backpack"|"equipment"
---@param slotIndex number|string 背包槽位 或 装备槽ID
---@param onDoneCallback function|nil
function MinggeTooltip.Show(item, source, slotIndex, onDoneCallback)
    if not panel_ then return end
    onDone_ = onDoneCallback

    -- 清空旧内容
    panel_:ClearChildren()

    -- 内容卡片
    local card = UI.Panel {
        width = T.size.tooltipWidth + 20,
        backgroundColor = {30, 35, 50, 250},
        borderRadius = T.radius.lg,
        padding = T.spacing.md,
        gap = T.spacing.sm,
        -- 阻止点击穿透到遮罩
        onClick = function(self) end,
    }

    -- ── 名称行 ──
    local qualityColor = GetQualityColor(item.quality)
    local qualityName = MinggeData.QUALITY_NAMES[item.quality] or "?"
    local elementName = MinggeData.ELEMENT_NAMES[item.element] or "?"

    card:AddChild(UI.Label {
        text = item.name or "未知命格",
        fontSize = T.fontSize.lg,
        fontWeight = "bold",
        fontColor = qualityColor,
        textAlign = "center",
    })

    -- ── 基本信息行 ──
    local infoText = qualityName .. "品 · " .. elementName .. "行 · T" .. (item.tier or "?")
    card:AddChild(UI.Label {
        text = infoText,
        fontSize = T.fontSize.sm,
        fontColor = {180, 180, 200, 230},
        textAlign = "center",
    })

    -- ── 来源 ──
    if item.bossName then
        card:AddChild(UI.Panel {
            flexDirection = "row",
            justifyContent = "center",
            gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = "来源:",
                    fontSize = T.fontSize.xs,
                    fontColor = {140, 140, 160, 200},
                },
                UI.Label {
                    text = item.bossName,
                    fontSize = T.fontSize.xs,
                    fontColor = {200, 180, 140, 255},
                },
            },
        })
    end

    -- ── 分隔线 ──
    card:AddChild(UI.Panel {
        height = 1,
        backgroundColor = {80, 90, 120, 150},
        marginTop = T.spacing.xs,
        marginBottom = T.spacing.xs,
    })

    -- ── 属性值 ──
    local statName = MinggeData.STAT_NAMES[item.stat] or item.stat or "?"
    local statValue = FormatStatValue(item.stat, item.value or 0)
    local rollPct = GetRollPercent(item)

    card:AddChild(UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        children = {
            UI.Label {
                text = statName,
                fontSize = T.fontSize.md,
                fontColor = {220, 220, 240, 255},
            },
            UI.Panel {
                flexDirection = "row",
                gap = T.spacing.xs,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = statValue,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = qualityColor,
                    },
                    rollPct ~= "" and UI.Label {
                        text = "(" .. rollPct .. ")",
                        fontSize = T.fontSize.xs,
                        fontColor = {150, 150, 170, 200},
                    } or nil,
                },
            },
        },
    })

    -- ── 套装信息 ──
    if item.setId then
        local setDef = MinggeData.SETS[item.setId]
        if setDef then
            card:AddChild(UI.Panel {
                backgroundColor = {40, 55, 70, 200},
                borderRadius = T.radius.sm,
                padding = T.spacing.sm,
                marginTop = T.spacing.xs,
                children = {
                    UI.Label {
                        text = "四象·" .. setDef.name,
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = {100, 220, 255, 255},
                    },
                    UI.Label {
                        text = setDef.desc .. "（同行3件激活）",
                        fontSize = T.fontSize.xs,
                        fontColor = {150, 200, 220, 200},
                    },
                },
            })
        end
    end

    -- ── 同名已装备警告 ──
    if source == "backpack" and item.minggeId then
        if MinggeSystem.IsDuplicateEquipped(item.minggeId) then
            card:AddChild(UI.Label {
                text = "⚠ 同名命格已装备，无法再次装备",
                fontSize = T.fontSize.xs,
                fontColor = {255, 100, 100, 230},
                textAlign = "center",
                marginTop = T.spacing.xs,
            })
        end
    end

    -- ── 出售价格 ──
    local sellPrice = item.sellPrice or 1
    card:AddChild(UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        gap = T.spacing.xs,
        marginTop = T.spacing.xs,
        children = {
            UI.Label {
                text = "出售:",
                fontSize = T.fontSize.xs,
                fontColor = {140, 140, 160, 200},
            },
            UI.Label {
                text = sellPrice .. " 灵韵",
                fontSize = T.fontSize.xs,
                fontColor = {180, 140, 255, 255},
            },
        },
    })

    -- ── 操作按钮 ──
    local buttons = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        gap = T.spacing.sm,
        marginTop = T.spacing.md,
    }

    if source == "backpack" then
        -- 装备按钮
        local canEquip = true
        if item.minggeId and MinggeSystem.IsDuplicateEquipped(item.minggeId) then
            canEquip = false
        end
        buttons:AddChild(UI.Button {
            text = "装备",
            fontSize = T.fontSize.sm,
            paddingLeft = T.spacing.lg,
            paddingRight = T.spacing.lg,
            height = 32,
            borderRadius = T.radius.md,
            backgroundColor = canEquip and {60, 140, 80, 240} or {80, 80, 80, 200},
            disabled = not canEquip,
            onClick = function(self)
                local ok, err = MinggeSystem.Equip(slotIndex)
                if ok then
                    MinggeTooltip.Hide()
                    if onDone_ then onDone_() end
                else
                    print("[MinggeTooltip] Equip failed: " .. (err or ""))
                end
            end,
        })

        -- 出售按钮
        if not item.locked then
            buttons:AddChild(UI.Button {
                text = "出售",
                fontSize = T.fontSize.sm,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                height = 32,
                borderRadius = T.radius.md,
                backgroundColor = {140, 80, 40, 240},
                onClick = function(self)
                    MinggeSystem.SellItem(slotIndex)
                    MinggeTooltip.Hide()
                    if onDone_ then onDone_() end
                end,
            })
        end

        -- 锁定/解锁按钮
        buttons:AddChild(UI.Button {
            text = item.locked and "解锁" or "锁定",
            fontSize = T.fontSize.sm,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            height = 32,
            borderRadius = T.radius.md,
            backgroundColor = {80, 80, 100, 220},
            onClick = function(self)
                MinggeSystem.ToggleLock(slotIndex)
                MinggeTooltip.Hide()
                if onDone_ then onDone_() end
            end,
        })
    elseif source == "equipment" then
        -- 卸下按钮
        buttons:AddChild(UI.Button {
            text = "卸下",
            fontSize = T.fontSize.sm,
            paddingLeft = T.spacing.lg,
            paddingRight = T.spacing.lg,
            height = 32,
            borderRadius = T.radius.md,
            backgroundColor = {140, 100, 40, 240},
            onClick = function(self)
                local ok, err = MinggeSystem.Unequip(slotIndex)
                if ok then
                    MinggeTooltip.Hide()
                    if onDone_ then onDone_() end
                else
                    print("[MinggeTooltip] Unequip failed: " .. (err or ""))
                end
            end,
        })
    end

    -- 关闭按钮
    buttons:AddChild(UI.Button {
        text = "关闭",
        fontSize = T.fontSize.sm,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        height = 32,
        borderRadius = T.radius.md,
        backgroundColor = {60, 60, 70, 220},
        onClick = function(self)
            MinggeTooltip.Hide()
        end,
    })

    card:AddChild(buttons)
    panel_:AddChild(card)
    panel_:Show()
end

-- ============================================================================
-- 隐藏
-- ============================================================================

function MinggeTooltip.Hide()
    if panel_ then
        panel_:Hide()
    end
    onDone_ = nil
end

return MinggeTooltip
