-- ============================================================================
-- EquipTooltip.lua - 装备属性详情浮层
-- 内嵌在背包面板中，不使用 Modal，避免 overlay 层级问题
-- 支持双面板对比：背包/商店中查看装备时，左侧显示已装备，右侧显示当前物品
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local InventorySystem = require("systems.InventorySystem")
local SkillData = require("config.SkillData")
local GameState = require("core.GameState")
local IconUtils = require("utils.IconUtils")
local StatNames = require("utils.StatNames")
local T = require("config.UITheme")
local EventBus = require("core.EventBus")

local EquipTooltip = {}

---@type Panel|nil
local panel_ = nil       -- 浮层面板（常驻，显示/隐藏切换）
---@type Panel|nil
local container_ = nil   -- 挂载的父容器
---@type function|nil
local onDone_ = nil

-- ── 属性映射（来自共享模块） ──
local STAT_NAMES = StatNames.NAMES
local STAT_ICONS = StatNames.ICONS
local FormatStatValue = StatNames.FormatValue

--- 构建一行属性
local function StatRow(icon, name, valStr, nameColor, valColor, fs)
    fs = fs or T.fontSize.sm
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.xs, paddingRight = T.spacing.xs,
        height = fs + 10,
        children = {
            UI.Label { text = icon .. " " .. name, fontSize = fs, fontColor = nameColor },
            UI.Label { text = valStr, fontSize = fs, fontWeight = "bold", fontColor = valColor },
        },
    }
end

--- 构建物品信息行（通用，供主面板和对比面板复用）
---@param item table
---@param tagLabel string|nil 标签（如"已装备"/"背包"）
---@param tagColor table|nil 标签颜色
---@return table[] rows
local function BuildItemInfoRows(item, tagLabel, tagColor)
    local rows = {}

    local isConsumable = item.category == "consumable"
    local qualityCfg = GameConfig.QUALITY[item.quality]
    local qName = qualityCfg and qualityCfg.name or "普通"
    local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}
    local slotName = EquipmentData.SLOT_NAMES[item.slot] or item.slot or ""

    -- 物品名称（含图标）
    local imgSrc = item.image or (IconUtils.IsImagePath(item.icon) and item.icon) or nil
    local displayIcon = IconUtils.GetTextIcon(item.icon, "")
    local nameText = item.name or "未知物品"

    if imgSrc then
        -- 图片图标：左侧图片 + 右侧名称，水平排列
        table.insert(rows, UI.Panel {
            flexDirection = "row", justifyContent = "center", alignItems = "center", gap = T.spacing.xs,
            children = {
                UI.Panel { width = 28, height = 28, backgroundImage = imgSrc, backgroundFit = "contain" },
                UI.Label {
                    text = nameText,
                    fontSize = T.fontSize.lg, fontWeight = "bold",
                    fontColor = qColor,
                },
            },
        })
    else
        -- emoji 或无图标
        local fullName = displayIcon ~= "" and (displayIcon .. " " .. nameText) or nameText
        table.insert(rows, UI.Label {
            text = fullName,
            fontSize = T.fontSize.lg, fontWeight = "bold",
            fontColor = qColor,
            textAlign = "center",
        })
    end

    if isConsumable then
        local typeLabel = item.petExp and "宠物食物" or "消耗品"
        local countStr = (item.count and item.count > 1) and (" ×" .. item.count) or ""
        table.insert(rows, UI.Label {
            text = "[" .. qName .. " " .. typeLabel .. "]" .. countStr,
            fontSize = T.fontSize.sm, fontColor = {qColor[1], qColor[2], qColor[3], 200}, textAlign = "center",
        })
    else
        local tierStr = item.tier and (item.tier .. "阶") or ""
        local subLine = "[" .. qName .. "] " .. slotName
        if tierStr ~= "" then
            subLine = tierStr .. "  " .. subLine
        end
        table.insert(rows, UI.Label {
            text = subLine,
            fontSize = T.fontSize.sm, fontColor = {qColor[1], qColor[2], qColor[3], 180}, textAlign = "center",
        })
    end

    -- 分割线
    table.insert(rows, UI.Panel { width = "100%", height = 1, backgroundColor = {80, 85, 100, 120}, marginTop = T.spacing.xs, marginBottom = T.spacing.xs })

    -- 消耗品描述
    if isConsumable then
        local descChildren = {}
        if item.desc then
            table.insert(descChildren, UI.Label {
                text = item.desc,
                fontSize = T.fontSize.sm, fontColor = {220, 220, 230, 220},
            })
        end
        if item.petExp then
            table.insert(descChildren, UI.Label {
                text = "🐾 宠物经验 +" .. item.petExp,
                fontSize = T.fontSize.md, fontWeight = "bold", fontColor = {130, 230, 130, 255},
            })
        end
        if #descChildren > 0 then
            table.insert(rows, UI.Panel {
                backgroundColor = {35, 45, 35, 200}, borderRadius = T.radius.sm,
                padding = T.spacing.sm, gap = T.spacing.xs,
                children = descChildren,
            })
        end
    end

    -- 主属性
    if item.mainStat then
        local mainChildren = {
            UI.Label { text = "▸ 主属性", fontSize = T.fontSize.xs, fontColor = {160, 160, 180, 200}, paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs },
        }
        for stat, value in pairs(item.mainStat) do
            table.insert(mainChildren, StatRow(
                STAT_ICONS[stat] or "📊", STAT_NAMES[stat] or stat,
                FormatStatValue(stat, value),
                {255, 255, 230, 255}, qColor, T.fontSize.md
            ))
        end
        table.insert(rows, UI.Panel {
            backgroundColor = {math.floor(qColor[1] * 0.15), math.floor(qColor[2] * 0.15), math.floor(qColor[3] * 0.15), 220},
            borderRadius = T.radius.sm, borderWidth = 1, borderColor = {qColor[1], qColor[2], qColor[3], 120},
            padding = T.spacing.sm, gap = T.spacing.xs, children = mainChildren,
        })
    end

    -- 副属性
    if item.subStats and #item.subStats > 0 then
        local subChildren = {
            UI.Label { text = "▸ 副属性", fontSize = T.fontSize.xs, fontColor = {160, 160, 180, 200}, paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs },
        }
        for _, sub in ipairs(item.subStats) do
            table.insert(subChildren, StatRow(
                STAT_ICONS[sub.stat] or "📊", sub.name or STAT_NAMES[sub.stat] or sub.stat,
                FormatStatValue(sub.stat, sub.value),
                {200, 200, 220, 255}, {150, 220, 150, 255}, T.fontSize.sm
            ))
        end
        table.insert(rows, UI.Panel {
            backgroundColor = {30, 35, 48, 200}, borderRadius = T.radius.sm, padding = T.spacing.sm, gap = T.spacing.xs,
            children = subChildren,
        })
    end

    -- 洗练属性
    if item.forgeStat then
        local fs = item.forgeStat
        table.insert(rows, UI.Panel {
            backgroundColor = {45, 38, 55, 200}, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {180, 140, 60, 120},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 洗练属性", fontSize = T.fontSize.xs, fontColor = {180, 160, 100, 200}, paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs },
                StatRow(
                    STAT_ICONS[fs.stat] or "🔨", fs.name or STAT_NAMES[fs.stat] or fs.stat,
                    FormatStatValue(fs.stat, fs.value),
                    {255, 220, 150, 255}, {255, 200, 100, 255}, T.fontSize.md
                ),
            },
        })
    end

    -- 灵性属性
    if item.spiritStat then
        local ss = item.spiritStat
        table.insert(rows, UI.Panel {
            backgroundColor = {25, 45, 45, 200}, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {0, 200, 200, 120},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 灵性属性", fontSize = T.fontSize.xs, fontColor = {0, 200, 200, 200}, paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs },
                StatRow(
                    STAT_ICONS[ss.stat] or "✨", ss.name or STAT_NAMES[ss.stat] or ss.stat,
                    FormatStatValue(ss.stat, ss.value),
                    {150, 240, 240, 255}, {0, 220, 220, 255}, T.fontSize.md
                ),
            },
        })
    end

    -- 套装
    if item.setId then
        local setData = EquipmentData.SetBonuses[item.setId]
        if setData then
            local setCount = 0
            local manager = InventorySystem.GetManager()
            if manager then
                local equipped = manager:GetAllEquipment()
                if equipped then
                    local slotSeen = {}
                    for eqSlotId, eq in pairs(equipped) do
                        if eq and eq.setId == item.setId then
                            local origSlot = eq.slot or eqSlotId
                            if not slotSeen[origSlot] then
                                slotSeen[origSlot] = true
                                setCount = setCount + 1
                            end
                        end
                    end
                end
            end
            local setChildren = {
                UI.Label { text = "🔗 " .. setData.name .. " (" .. setCount .. "件)", fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 200, 100, 255} },
            }
            for threshold, bonus in pairs(setData.pieces) do
                local active = setCount >= threshold
                table.insert(setChildren, UI.Label {
                    text = (active and "✓ " or "  ") .. "(" .. threshold .. "件) " .. bonus.description,
                    fontSize = T.fontSize.xs, fontColor = active and {100, 255, 100, 255} or {120, 120, 120, 180},
                })
            end
            table.insert(rows, UI.Panel {
                backgroundColor = {45, 38, 25, 200}, borderRadius = T.radius.sm, padding = T.spacing.sm, gap = T.spacing.xs,
                children = setChildren,
            })
        end
    end

    -- 附灵属性（enchantSetId）
    if item.enchantSetId then
        local setData = EquipmentData.SetBonuses[item.enchantSetId]
        if setData then
            -- 统计当前附灵套装件数（含自然setId + enchantSetId）
            local enchantCount = 0
            local manager = InventorySystem.GetManager()
            if manager then
                local equipped = manager:GetAllEquipment()
                if equipped then
                    local slotSeen = {}
                    for eqSlotId, eq in pairs(equipped) do
                        if eq then
                            if eq.setId == item.enchantSetId then
                                local origSlot = eq.slot or eqSlotId
                                if not slotSeen[origSlot] then
                                    slotSeen[origSlot] = true
                                    enchantCount = enchantCount + 1
                                end
                            end
                            if eq.enchantSetId == item.enchantSetId then
                                enchantCount = enchantCount + 1
                            end
                        end
                    end
                end
            end
            local enchantChildren = {
                UI.Label {
                    text = "💎 附灵: " .. setData.name .. " (" .. enchantCount .. "件)",
                    fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {180, 130, 255, 255},
                },
            }
            for threshold, bonus in pairs(setData.pieces) do
                local active = enchantCount >= threshold
                table.insert(enchantChildren, UI.Label {
                    text = (active and "✓ " or "  ") .. "(" .. threshold .. "件) " .. bonus.description,
                    fontSize = T.fontSize.xs, fontColor = active and {200, 160, 255, 255} or {120, 120, 120, 180},
                })
            end
            table.insert(rows, UI.Panel {
                backgroundColor = {40, 30, 60, 220}, borderRadius = T.radius.sm,
                borderWidth = 1, borderColor = {160, 100, 255, 150},
                padding = T.spacing.sm, gap = T.spacing.xs,
                children = enchantChildren,
            })
        end
    end

    -- 附带技能
    if item.skillId then
        local skillDef = SkillData.Skills[item.skillId]
        if skillDef then
            local cdText = skillDef.cooldown and ("CD " .. math.floor(skillDef.cooldown) .. "s") or ""
            table.insert(rows, UI.Panel {
                backgroundColor = {25, 40, 55, 200}, borderRadius = T.radius.sm,
                borderWidth = 1, borderColor = {80, 160, 220, 100},
                padding = T.spacing.sm, gap = T.spacing.xs,
                children = {
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                        children = {
                            UI.Label { text = "🔮 技能: " .. (skillDef.icon or "") .. " " .. (skillDef.name or item.skillId), fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {100, 200, 255, 255} },
                            UI.Label { text = cdText, fontSize = T.fontSize.xs, fontColor = {160, 180, 200, 180} },
                        },
                    },
                    UI.Label {
                        text = SkillData.GetDynamicDescription(
                            item.skillId,
                            GameState.player and GameState.player:GetTotalMaxHp() or nil,
                            item.tier or InventorySystem.GetGourdTier()
                        ),
                        fontSize = T.fontSize.xs, fontColor = {180, 200, 220, 200},
                    },
                },
            })
        end
    end

    -- 美酒槽位（仅葫芦装备显示）
    if item.slot == "treasure" then
        local wineOk, WineData = pcall(require, "config.WineData")
        if wineOk then
            local player = GameState.player
            local wineSlots = player and player.wineSlots or {}
            local wineChildren = {
                UI.Label { text = "▸ 美酒", fontSize = T.fontSize.xs, fontColor = {200, 180, 120, 200}, paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs },
            }
            for i = 1, 3 do
                local wineId = wineSlots[i]
                if wineId then
                    local wine = WineData.BY_ID[wineId]
                    if wine then
                        local effectText = WineData.GetEffectText(wine)
                        table.insert(wineChildren, UI.Panel {
                            flexDirection = "row", alignItems = "center",
                            paddingLeft = T.spacing.xs, paddingRight = T.spacing.xs,
                            height = T.fontSize.sm + 10,
                            children = {
                                UI.Label { text = "\xf0\x9f\x8d\xb6 " .. wine.name, fontSize = T.fontSize.sm, fontColor = {255, 220, 140, 255} },
                                UI.Label { text = "  " .. effectText, fontSize = T.fontSize.xs, fontColor = {200, 200, 180, 180}, flexShrink = 1 },
                            },
                        })
                    end
                else
                    table.insert(wineChildren, UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        paddingLeft = T.spacing.xs,
                        height = T.fontSize.sm + 10,
                        children = {
                            UI.Label { text = "\xf0\x9f\x94\x92 \xe7\xa9\xba\xe6\xa7\xbd", fontSize = T.fontSize.sm, fontColor = {100, 100, 110, 150} },
                        },
                    })
                end
            end
            table.insert(rows, UI.Panel {
                backgroundColor = {40, 35, 25, 200}, borderRadius = T.radius.sm,
                borderWidth = 1, borderColor = {180, 150, 80, 100},
                padding = T.spacing.sm, gap = T.spacing.xs,
                children = wineChildren,
            })
        end
    end

    -- 独特效果
    if item.specialEffect then
        local eff = item.specialEffect
        local descText = ""
        if eff.type == "bleed_dot" then
            descText = string.format("攻击%.0f%%概率附带%s，每秒%.0f%%攻击力，持续%d秒，CD%d秒",
                (eff.triggerChance or 1) * 100, eff.name or "",
                (eff.damagePercent or 0) * 100, eff.duration or 0, eff.cooldown or 0)
        elseif eff.type == "evade_damage" then
            descText = string.format("受到攻击时%.0f%%概率完全闪避伤害",
                (eff.evadeChance or 0) * 100)
        elseif eff.type == "wind_slash" then
            descText = string.format("攻击时%.0f%%概率释放风刃，造成%.0f%%攻击力额外伤害",
                (eff.triggerChance or 0) * 100, (eff.damagePercent or 0) * 100)
        elseif eff.type == "sacrifice_aura" then
            descText = string.format("持续灼烧周围%.1f格敌人，每%.1f秒造成%.0f%%攻击力伤害",
                eff.range or 1.5, eff.tickInterval or 1.0, (eff.damagePercent or 0) * 100)
        elseif eff.type == "lifesteal_burst" then
            descText = string.format("击杀堆叠%d层释放前方AOE（%.0f%%攻击力），造成等量吸血，击杀回复%.0f%%最大生命",
                eff.maxStacks or 10, (eff.damagePercent or 1.0) * 100, (eff.healPercent or 0) * 100)
        elseif eff.type == "heavy_strike" then
            descText = string.format("每第%d次攻击必定触发重击", eff.hitInterval or 5)
        elseif eff.type == "shadow_strike" then
            descText = string.format("暴击时%.0f%%概率追加影击，造成%.0f%%攻击力伤害",
                (eff.triggerChance or 0) * 100, (eff.damagePercent or 0) * 100)
        elseif eff.type == "death_immunity" then
            descText = string.format("受到致命伤害时%.0f%%概率免死，保留1点生命并无敌%.1f秒",
                (eff.immuneChance or 0) * 100, eff.immuneDuration or 1.0)
        elseif eff.type == "hp_regen_percent" then
            descText = string.format("每秒恢复%.0f%%最大生命值%s",
                (eff.regenPercent or 0) * 100, eff.stopWhenFull and "（血满停止）" or "")
        else
            descText = eff.description or (eff.name or "特殊效果")
        end
        table.insert(rows, UI.Panel {
            backgroundColor = {55, 25, 25, 200}, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {220, 120, 60, 100},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "✨ " .. (eff.name or "特殊效果"), fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 160, 60, 255} },
                UI.Label { text = descText, fontSize = T.fontSize.xs, fontColor = {255, 200, 150, 200} },
            },
        })
    end

    -- 售价（消耗品从 GameConfig 实时读取，避免存档旧值不同步）
    local displaySellPrice = item.sellPrice
    local displaySellCurrency = item.sellCurrency
    if item.category == "consumable" and item.consumableId then
        local cfgItem = GameConfig.CONSUMABLES[item.consumableId]
        if cfgItem then
            displaySellPrice = cfgItem.sellPrice or displaySellPrice
            displaySellCurrency = cfgItem.sellCurrency or displaySellCurrency
        end
    end
    if displaySellPrice then
        table.insert(rows, UI.Panel {
            flexDirection = "row", justifyContent = "flex-end", paddingRight = T.spacing.xs,
            children = {
                UI.Label {
                    text = displaySellCurrency == "lingYun"
                        and ("✨ 售价 " .. displaySellPrice .. " 灵韵")
                        or  ("💰 售价 " .. displaySellPrice),
                    fontSize = T.fontSize.xs,
                    fontColor = displaySellCurrency == "lingYun" and {180, 140, 255, 200} or {200, 180, 100, 160},
                },
            },
        })
    end

    -- 标签（放在底部）
    if tagLabel then
        table.insert(rows, UI.Panel {
            alignItems = "center",
            marginTop = T.spacing.xs,
            children = {
                UI.Panel {
                    backgroundColor = tagColor or {60, 60, 80, 200},
                    borderRadius = T.radius.sm,
                    paddingTop = 2, paddingBottom = 2,
                    paddingLeft = T.spacing.md, paddingRight = T.spacing.md,
                    children = {
                        UI.Label {
                            text = tagLabel,
                            fontSize = T.fontSize.xs,
                            fontWeight = "bold",
                            fontColor = {255, 255, 255, 220},
                            textAlign = "center",
                        },
                    },
                },
            },
        })
    end

    return rows
end

--- 构建物品信息行（公共接口，供外部复用）
EquipTooltip.BuildItemInfoRows = BuildItemInfoRows

--- 汇总一件装备的所有属性（主属性+副属性+洗练）为 { stat = totalValue }
---@param item table
---@return table<string, number>
local function CollectAllStats(item)
    local stats = {}
    if item.mainStat then
        for stat, value in pairs(item.mainStat) do
            stats[stat] = (stats[stat] or 0) + value
        end
    end
    if item.subStats then
        for _, sub in ipairs(item.subStats) do
            stats[sub.stat] = (stats[sub.stat] or 0) + sub.value
        end
    end
    if item.forgeStat then
        stats[item.forgeStat.stat] = (stats[item.forgeStat.stat] or 0) + item.forgeStat.value
    end
    if item.spiritStat then
        stats[item.spiritStat.stat] = (stats[item.spiritStat.stat] or 0) + item.spiritStat.value
    end
    return stats
end

--- 格式化属性值（不带 + 前缀，用于对比表）
local FormatStatShort = StatNames.FormatShort

--- 属性对比排序
local STAT_ORDER = { "atk", "def", "maxHp", "speed", "hpRegen", "critRate", "critDmg", "dmgReduce", "skillDmg", "killHeal", "heavyHit", "fortune", "wisdom", "constitution", "physique" }

--- 构建属性对比表（已装备 vs 当前物品）
---@param equippedItem table
---@param currentItem table
---@return Panel
local function BuildCompareSection(equippedItem, currentItem)
    local eqStats = CollectAllStats(equippedItem)
    local curStats = CollectAllStats(currentItem)

    local eqQuality = GameConfig.QUALITY[equippedItem.quality]
    local curQuality = GameConfig.QUALITY[currentItem.quality]
    local eqColor = eqQuality and eqQuality.color or {200, 200, 200, 255}
    local curColor = curQuality and curQuality.color or {200, 200, 200, 255}

    local rows = {}

    -- 标题行：两件装备名称
    table.insert(rows, UI.Panel {
        flexDirection = "row", alignItems = "center",
        paddingBottom = T.spacing.xs,
        children = {
            UI.Panel { width = "34%", children = {
                UI.Label { text = "属性对比", fontSize = T.fontSize.xs, fontColor = {160, 160, 180, 180} },
            }},
            UI.Panel { width = "33%", alignItems = "center", children = {
                UI.Label { text = "🟢 已装备", fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = {100, 200, 100, 230} },
                UI.Label { text = equippedItem.name or "", fontSize = T.fontSize.xs, fontColor = eqColor, textAlign = "center" },
            }},
            UI.Panel { width = "33%", alignItems = "center", children = {
                UI.Label { text = "🔵 当前", fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = {100, 180, 255, 230} },
                UI.Label { text = currentItem.name or "", fontSize = T.fontSize.xs, fontColor = curColor, textAlign = "center" },
            }},
        },
    })

    -- 分割线
    table.insert(rows, UI.Panel { width = "100%", height = 1, backgroundColor = {80, 85, 100, 100} })

    -- 属性行
    for _, stat in ipairs(STAT_ORDER) do
        local eqVal = eqStats[stat]
        local curVal = curStats[stat]
        if eqVal or curVal then
            local eqStr = eqVal and FormatStatShort(stat, eqVal) or "-"
            local curStr = curVal and FormatStatShort(stat, curVal) or "-"

            -- 颜色：值更高的一方为绿色，更低为红色
            local eqValColor = {200, 200, 220, 220}
            local curValColor = {200, 200, 220, 220}
            if eqVal and curVal then
                if curVal > eqVal then
                    curValColor = {100, 255, 100, 255}
                    eqValColor = {255, 130, 130, 220}
                elseif curVal < eqVal then
                    eqValColor = {100, 255, 100, 255}
                    curValColor = {255, 130, 130, 220}
                end
            elseif curVal and not eqVal then
                curValColor = {100, 255, 100, 255}
            elseif eqVal and not curVal then
                eqValColor = {100, 255, 100, 255}
            end

            table.insert(rows, UI.Panel {
                flexDirection = "row", alignItems = "center",
                paddingTop = 2, paddingBottom = 2,
                children = {
                    UI.Label {
                        text = (STAT_ICONS[stat] or "📊") .. " " .. (STAT_NAMES[stat] or stat),
                        width = "34%", fontSize = T.fontSize.xs, fontColor = {200, 200, 220, 200},
                    },
                    UI.Label {
                        text = eqStr, width = "33%", fontSize = T.fontSize.sm,
                        fontWeight = "bold", fontColor = eqValColor, textAlign = "center",
                    },
                    UI.Label {
                        text = curStr, width = "33%", fontSize = T.fontSize.sm,
                        fontWeight = "bold", fontColor = curValColor, textAlign = "center",
                    },
                },
            })
        end
    end

    return UI.Panel {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        maxWidth = T.size.tooltipWidth,
        backgroundColor = {20, 22, 32, 235},
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = {80, 90, 110, 150},
        padding = T.spacing.md,
        gap = T.spacing.xs,
        overflow = "hidden",
        onClick = function() end,
        children = rows,
    }
end

--- 查找同槽位已装备物品
---@param item table
---@return table|nil equippedItem
local function FindEquippedForSlot(item)
    if not item.slot then return nil end
    local manager = InventorySystem.GetManager()
    if not manager then return nil end

    local eqSlot = item.slot
    if eqSlot == "ring1" or eqSlot == "ring2" or item.type == "ring" then
        local r1 = manager:GetEquipmentItem("ring1")
        local r2 = manager:GetEquipmentItem("ring2")
        if r1 then eqSlot = "ring1"
        elseif r2 then eqSlot = "ring2"
        else return nil end
    end
    return manager:GetEquipmentItem(eqSlot)
end

--- 初始化：将浮层挂载到父容器（在 InventoryUI.Create 中调用一次）
---@param parent Panel 背包面板（position=absolute 的那个）
function EquipTooltip.Init(parent)
    container_ = parent
    panel_ = nil  -- 延迟创建
end

--- 是否已初始化
---@return boolean
function EquipTooltip.IsInited()
    return container_ ~= nil
end

--- 显示装备详情
---@param item table
---@param source string "inventory"|"equipment"|"shop"
---@param sourceSlotId string|number|table  shop 模式下为 shopItem 数据
---@param onDone function|nil
function EquipTooltip.Show(item, source, sourceSlotId, onDone)
    if not item or not container_ then return end
    onDone_ = onDone

    -- 每次重建内容（数据不同）
    EquipTooltip.Hide()

    local isConsumable = item.category == "consumable"

    -- 消耗品：从配置补全 quality / desc / image（兼容旧存档物品）
    if isConsumable and item.consumableId then
        local PetSkillData = require("config.PetSkillData")
        local cfgData = GameConfig.CONSUMABLES[item.consumableId] or PetSkillData.SKILL_BOOKS[item.consumableId]
        if cfgData then
            if not item.quality then item.quality = cfgData.quality end
            if not item.desc then item.desc = cfgData.desc end
            if not item.image then item.image = cfgData.image end
        end
    end

    -- ── 构建主物品信息行 ──
    local mainRows = BuildItemInfoRows(item, nil, nil)

    -- ── 操作按钮 ──
    local btnChildren = {}
    local doneCallback = onDone

    if source == "inventory" and isConsumable then
        if item.petExp then
            table.insert(btnChildren, UI.Button {
                text = "🦴 喂食宠物", variant = "primary", flexGrow = 1,
                onClick = function()
                    EquipTooltip.Hide()
                    if doneCallback then doneCallback() end
                    EventBus.Emit("open_pet_panel")
                end,
            })
        end
        if item.consumableId == "lingyun_fruit" or item.consumableId == "exp_pill" or item.consumableId == "gold_bar" or item.consumableId == "gold_brick" then
            -- 批量使用/出售 UI：×1 / ×10 / ×50 / 全部
            local cId = item.consumableId
            local totalCount = InventorySystem.CountConsumable(cId)
            local actionLabel = (cId == "gold_bar" or cId == "gold_brick") and "出售" or "使用"
            local actionIcon = cId == "lingyun_fruit" and "🍇" or (cId == "exp_pill" and "💊" or "💰")
            local batchAmounts = { 1, 10, 50, totalCount }
            local batchLabels = { "×1", "×10", "×50", "全部(" .. totalCount .. ")" }
            local batchBtns = {}
            for bi = 1, #batchAmounts do
                local batchCount = batchAmounts[bi]
                if batchCount > 0 and batchCount <= totalCount then
                    -- 避免重复按钮（如总数 <= 50 时 "全部" 可能与其他重复）
                    local isDuplicate = false
                    if bi == #batchAmounts then
                        for bj = 1, bi - 1 do
                            if batchAmounts[bj] == batchCount then isDuplicate = true; break end
                        end
                    end
                    if not isDuplicate then
                        table.insert(batchBtns, UI.Button {
                            text = actionIcon .. " " .. actionLabel .. batchLabels[bi],
                            variant = bi == #batchAmounts and "warning" or "primary",
                            flexGrow = 1,
                            onClick = function(self)
                                -- 双击防护：立即禁用按钮
                                self:SetDisabled(true)
                                local ok, msg = InventorySystem.UseBatchConsumable(cId, batchCount)
                                if ok then
                                    EventBus.Emit("show_toast", msg)
                                else
                                    EventBus.Emit("show_toast", msg or "操作失败")
                                end
                                EquipTooltip.Hide()
                                if doneCallback then doneCallback() end
                            end,
                        })
                    end
                end
            end
            -- 将批量按钮包在一个纵向面板中
            table.insert(btnChildren, UI.Panel {
                flexGrow = 1, gap = T.spacing.xs,
                children = batchBtns,
            })
        end
        if item.consumableId == "item_guardian_token" then
            table.insert(btnChildren, UI.Button {
                text = "🔖 使用", variant = "primary", flexGrow = 1,
                onClick = function()
                    local ok, err = InventorySystem.UseGuardianToken(sourceSlotId)
                    if ok then
                        EventBus.Emit("show_toast", "使用守护者证明，仙途守护者经验 +100！")
                    else
                        EventBus.Emit("show_toast", err or "使用失败")
                    end
                    EquipTooltip.Hide()
                    if doneCallback then doneCallback() end
                end,
            })
        end
        -- 修炼果、灵韵果、守护者证明不可出售，金条/金砖已有批量出售UI
        if item.consumableId ~= "exp_pill" and item.consumableId ~= "lingyun_fruit" and item.consumableId ~= "item_guardian_token" and item.consumableId ~= "gold_bar" and item.consumableId ~= "gold_brick" then
            table.insert(btnChildren, UI.Button {
                text = "出售", variant = "warning", flexGrow = 1,
                onClick = function()
                    InventorySystem.SellItem(sourceSlotId)
                    EquipTooltip.Hide()
                    if doneCallback then doneCallback() end
                end,
            })
        end
        -- 仓库打开时显示「存放」按钮（消耗品）
        local WarehouseSystem = require("systems.WarehouseSystem")
        if WarehouseSystem.IsOpen() then
            table.insert(btnChildren, UI.Button {
                text = "📦存放", variant = "secondary", flexGrow = 1,
                onClick = function()
                    local ok, err = WarehouseSystem.StoreItem(sourceSlotId)
                    if ok then
                        EventBus.Emit("show_toast", "已存入仓库")
                    else
                        EventBus.Emit("show_toast", err or "存放失败")
                    end
                    EquipTooltip.Hide()
                    if doneCallback then doneCallback() end
                end,
            })
        end
    elseif source == "inventory" then
        table.insert(btnChildren, UI.Button {
            text = "穿戴", variant = "primary", flexGrow = 1,
            onClick = function()
                local manager = InventorySystem.GetManager()
                if manager and item then
                    local targetSlot = item.slot
                    if item.slot == "ring1" or item.slot == "ring2" or item.type == "ring" then
                        local r1 = manager:GetEquipmentItem("ring1")
                        targetSlot = r1 and "ring2" or "ring1"
                    end
                    if targetSlot then
                        manager:MoveItem("inventory", sourceSlotId, "equipment", targetSlot)
                    end
                end
                EquipTooltip.Hide()
                if doneCallback then doneCallback() end
            end,
        })
        -- 仓库打开时显示「存放」按钮
        local WarehouseSystem = require("systems.WarehouseSystem")
        if WarehouseSystem.IsOpen() then
            table.insert(btnChildren, UI.Button {
                text = "📦存放", variant = "secondary", flexGrow = 1,
                onClick = function()
                    local ok, err = WarehouseSystem.StoreItem(sourceSlotId)
                    if ok then
                        EventBus.Emit("show_toast", "已存入仓库")
                    else
                        EventBus.Emit("show_toast", err or "存放失败")
                    end
                    EquipTooltip.Hide()
                    if doneCallback then doneCallback() end
                end,
            })
        end
        table.insert(btnChildren, UI.Button {
            text = "出售", variant = "warning", flexGrow = 1,
            onClick = function()
                InventorySystem.SellItem(sourceSlotId)
                EquipTooltip.Hide()
                if doneCallback then doneCallback() end
            end,
        })
    elseif source == "equipment" then
        table.insert(btnChildren, UI.Button {
            text = "卸下", variant = "secondary", flexGrow = 1,
            onClick = function()
                local manager = InventorySystem.GetManager()
                if manager then
                    for i = 1, GameConfig.BACKPACK_SIZE do
                        if not manager:GetInventoryItem(i) then
                            manager:MoveItem("equipment", sourceSlotId, "inventory", i)
                            break
                        end
                    end
                end
                EquipTooltip.Hide()
                if doneCallback then doneCallback() end
            end,
        })
    elseif source == "shop" then
        local shopItem = sourceSlotId
        table.insert(btnChildren, UI.Button {
            text = "💰 购买  " .. (shopItem.price or 0) .. " 金币",
            variant = "primary", flexGrow = 1,
            onClick = function()
                local EquipShopUI = require("ui.EquipShopUI")
                local ok = EquipShopUI.DoBuy(shopItem)
                EquipTooltip.Hide()
                if doneCallback then doneCallback() end
            end,
        })
    end

    table.insert(mainRows, UI.Panel {
        flexDirection = "row", gap = T.spacing.sm, marginTop = T.spacing.xs,
        children = btnChildren,
    })

    -- ── 主面板 ──
    local mainPanel = UI.Panel {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        maxWidth = T.size.tooltipWidth,
        backgroundColor = {25, 28, 38, 245},
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = {80, 90, 110, 200},
        padding = T.spacing.md,
        gap = T.spacing.sm,
        overflow = "hidden",
        onClick = function() end, -- 阻止穿透
        children = mainRows,
    }

    -- ── 已装备对比面板（左侧） ──
    local equippedPanel = nil
    if not isConsumable and (source == "inventory" or source == "shop") then
        local equippedItem = FindEquippedForSlot(item)
        if equippedItem then
            local eqRows = BuildItemInfoRows(equippedItem, "已装备", {60, 100, 60, 220})
            equippedPanel = UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
                maxWidth = T.size.tooltipWidth,
                backgroundColor = {22, 25, 35, 235},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {60, 80, 60, 180},
                padding = T.spacing.md,
                gap = T.spacing.sm,
                overflow = "hidden",
                onClick = function() end,
                children = eqRows,
            }
        end
    end

    -- ── 组装浮层 ──
    local contentChildren
    if equippedPanel then
        contentChildren = {
            UI.Panel {
                flexDirection = "row",
                gap = T.spacing.sm,
                alignItems = "flex-start",
                maxWidth = T.size.tooltipWidth * 2 + T.spacing.sm,
                width = "100%",
                onClick = function() end,
                children = { equippedPanel, mainPanel },
            },
        }
    else
        contentChildren = {
            UI.Panel {
                flexDirection = "row",
                justifyContent = "center",
                alignItems = "flex-start",
                maxWidth = T.size.tooltipWidth * 2 + T.spacing.sm,
                width = "100%",
                onClick = function() end,
                children = { mainPanel },
            },
        }
    end

    panel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 150,
        backgroundColor = {0, 0, 0, 150},
        justifyContent = "center",
        alignItems = "center",
        onPointerDown = function(self, event) end,
        onClick = function(self)
            EquipTooltip.Hide()
        end,
        children = contentChildren,
    }

    container_:AddChild(panel_)
end

--- 隐藏
function EquipTooltip.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    onDone_ = nil
end

--- 是否可见
---@return boolean
function EquipTooltip.IsVisible()
    return panel_ ~= nil
end

return EquipTooltip
