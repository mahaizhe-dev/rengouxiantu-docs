-- ============================================================================
-- SwordForgeUI.lua - 铸剑地炉打造界面（独立于龙神圣器打造）
-- 第五章专属：每个配方一个顶级页签，无二级子页签
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local StatNames = require("utils.StatNames")
local FormatUtils = require("utils.FormatUtils")
local ForgeSystem = require("systems.ForgeSystem")

local SwordForgeUI = {}

-- ============================================================================
-- 模块私有状态
-- ============================================================================

---@type userdata|nil
local panel_ = nil
local visible_ = false
local contentPanel_ = nil
local outerPanel_ = nil
local tabBarPanel_ = nil
local resultLabel_ = nil
local parentOverlay_ = nil
local successPanel_ = nil

-- 当前选中配方索引（对应 SWORD_FORGE_ORDER，1-based）
local currentRecipeIdx_ = 1

local RED_COLOR = {255, 80, 50, 255}
local STAT_ROW_H = 22  -- 属性行统一高度（对齐 EquipTooltip）

--- 格式化金币
local FormatGold = FormatUtils.Gold

local STAT_NAMES = StatNames.NAMES
local STAT_ICONS = StatNames.ICONS
local FormatStatVal = StatNames.FormatValue

-- ============================================================================
-- 内部工具函数
-- ============================================================================

--- 在背包中按 equipId 查找第一个匹配装备，跳过已占用格子
---@param manager table
---@param equipId string
---@param usedSlots table<number,boolean>|nil
---@return table|nil, number|nil
local function FindBagItemByEquipId(manager, equipId, usedSlots)
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not (usedSlots and usedSlots[i]) then
            local it = manager:GetInventoryItem(i)
            if it and it.equipId == equipId then
                return it, i
            end
        end
    end
    return nil, nil
end

--- 获取当前装备栏中的武器实例
local function GetEquippedWeapon()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return nil end
    return mgr:GetEquipmentItem("weapon")
end

--- 构建单条材料检查行（消耗品）
local function BuildMaterialRow(matId, need, have)
    local matDef = GameConfig.PET_MATERIALS and GameConfig.PET_MATERIALS[matId]
    local matName = matDef and matDef.name or matId
    local matIcon = matDef and matDef.icon or "❓"
    local enough = have >= need
    return UI.Panel {
        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
        children = {
            UI.Label { text = matIcon, fontSize = T.fontSize.sm },
            UI.Label {
                text = matName .. "  " .. have .. "/" .. need,
                fontSize = T.fontSize.xs,
                fontColor = enough and {130, 230, 130, 255} or {255, 130, 100, 255},
            },
        },
    }
end

--- 构建背包装备检查行
local function BuildBagEquipRow(equipId, have)
    local tpl = EquipmentData.SpecialEquipment[equipId]
          or EquipmentData.FabaoTemplates[equipId]
    local name = tpl and tpl.name or equipId
    return UI.Panel {
        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
        children = {
            UI.Label { text = "🎴", fontSize = T.fontSize.sm },
            UI.Label {
                text = name .. "  " .. (have and "✓" or "✗（缺少）"),
                fontSize = T.fontSize.xs,
                fontColor = have and {130, 230, 130, 255} or {255, 130, 100, 255},
            },
        },
    }
end

-- ============================================================================
-- 属性预览辅助函数
-- ============================================================================

--- 格式化范围值（百分比 vs 数值）
local function FormatRange(stat, minVal, maxVal)
    if stat == "critRate" or stat == "critDmg" or stat == "speed"
        or stat == "dmgReduce" or stat == "skillDmg" then
        return string.format("+%.1f%%~%.1f%%", minVal * 100, maxVal * 100)
    elseif stat == "hpRegen" then
        return string.format("+%.1f~%.1f/s", minVal, maxVal)
    else
        return "+" .. math.floor(minVal) .. "~" .. math.floor(maxVal)
    end
end

--- 格式化特殊效果说明
local function GetSpecialEffectDesc(eff)
    if not eff then return "" end
    if eff.type == "bleed_dot" then
        return string.format("攻击%.0f%%概率附带流血，每秒%.0f%%攻击力伤害，持续%d秒",
            (eff.triggerChance or 1) * 100, (eff.damagePercent or 0) * 100, eff.duration or 0)
    elseif eff.type == "evade_damage" then
        return string.format("受击时%.0f%%概率完全闪避伤害", (eff.evadeChance or 0) * 100)
    elseif eff.type == "wind_slash" then
        return string.format("攻击%.0f%%概率释放风刃，造成%.0f%%攻击力额外伤害",
            (eff.triggerChance or 0) * 100, (eff.damagePercent or 0) * 100)
    elseif eff.type == "lifesteal_burst" then
        return string.format("击杀堆叠%d层释放前方AOE（%.0f%%攻击力），造成等量吸血，击杀回复%.0f%%最大生命",
            eff.maxStacks or 10, (eff.damagePercent or 1.0) * 100, (eff.healPercent or 0) * 100)
    elseif eff.type == "heavy_strike" then
        return string.format("每第%d次攻击必定触发重击", eff.hitInterval or 5)
    elseif eff.type == "death_immunity" then
        return string.format("受致命伤害%.0f%%概率免死，保留1点生命并无敌%.1f秒",
            (eff.immuneChance or 0) * 100, eff.immuneDuration or 1.0)
    elseif eff.type == "zhuxian" then
        if eff.procChance then
            return string.format("每次攻击%.0f%%概率触发诛仙剑气，造成%.0f%%攻击额外伤害",
                (eff.procChance or 0.30) * 100, (eff.dmgMult or 1.80) * 100)
        else
            return string.format("暴击时，追加一次%.0f%%攻击力的额外伤害（可暴击）",
                (eff.damagePercent or 0.15) * 100)
        end
    elseif eff.type == "xianxian" then
        return string.format("生命>%.0f%%时暴击伤害+%.0f%%；生命≤%.0f%%时每秒恢复%.0f%%最大生命",
            (eff.highHpThreshold or 0.50) * 100, (eff.critDmgBonus or 0.50) * 100,
            (eff.highHpThreshold or 0.50) * 100, (eff.lowHpRegenPercent or 0.02) * 100)
    elseif eff.type == "luxian" then
        return string.format("普攻时有%.0f%%概率发动连击，连击可触发普攻特效",
            (eff.procChance or 0.10) * 100)
    elseif eff.type == "juexian" then
        return string.format("每次攻击获得1层绝命，每层攻击力+%.0f%%，最多%d层，持续%.0f秒",
            (eff.stackPercent or 0.03) * 100, eff.maxStacks or 5, eff.duration or 4.0)
    elseif eff.type == "def_boost" then
        return string.format("防御力提高%.0f%%", (eff.defPercent or 0) * 100)
    elseif eff.type == "yuanjia" then
        return string.format("受到伤害后，若当前生命低于50%%，获得%.0f%%减伤，持续%.0f秒（冷却%.0f秒）",
            (eff.dmgReduce or 0) * 100, eff.duration or 4, eff.cooldown or 8)
    elseif eff.type == "abyss_guard" then
        return string.format("受到伤害后，若当前生命低于%.0f%%，获得%.0f%%减伤，持续%.0f秒（冷却%.0f秒）",
            (eff.lowHpThreshold or 0.50) * 100, (eff.dmgReduce or 0.12) * 100,
            eff.duration or 4, eff.cooldown or 8)
    elseif eff.type == "hp_regen_full" then
        return string.format("每秒恢复%.0f%%最大生命值，生命满时停止恢复",
            (eff.regenPercent or 0.02) * 100)
    else
        return eff.description or eff.desc or (eff.name or "特殊效果")
    end
end

--- 构建产出装备属性预览面板（仿第四章打造）
local function BuildForgePreviewRows(targetDef)
    local rows = {}
    local qColor = {255, 50, 50, 255}
    local randLo = 1.1
    local randHi = 1.5
    -- 使用产出装备的实际阶级，而非 hardcode T9（铸剑地炉圣器均为 T10）
    local tier   = targetDef.tier or 10
    local numTM  = (EquipmentData.SUB_STAT_TIER_MULT and EquipmentData.SUB_STAT_TIER_MULT[tier])
                   or (EquipmentData.SUB_STAT_TIER_MULT and EquipmentData.SUB_STAT_TIER_MULT[9]) or 11.0
    local pctTM  = (EquipmentData.PCT_SUB_TIER_MULT  and EquipmentData.PCT_SUB_TIER_MULT[tier])
                   or (EquipmentData.PCT_SUB_TIER_MULT  and EquipmentData.PCT_SUB_TIER_MULT[9])  or 6.0
    local qMult  = GameConfig.QUALITY["red"] and GameConfig.QUALITY["red"].multiplier or 2.1

    -- 装备名称 & 阶位
    local tierLabel = targetDef.tier and EquipmentData.GetTierDisplayName(targetDef.tier) or "9阶"
    local slotLabel = EquipmentData.SLOT_NAMES and EquipmentData.SLOT_NAMES[targetDef.slot] or (targetDef.slot or "装备")
    table.insert(rows, UI.Label {
        text = targetDef.name,
        fontSize = T.fontSize.lg, fontWeight = "bold",
        fontColor = qColor, textAlign = "center",
    })
    table.insert(rows, UI.Label {
        text = tierLabel .. "  [圣器] " .. slotLabel,
        fontSize = T.fontSize.sm,
        fontColor = {qColor[1], qColor[2], qColor[3], 180}, textAlign = "center",
    })
    table.insert(rows, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 85, 100, 120},
        marginTop = T.spacing.xs, marginBottom = T.spacing.xs,
    })

    -- 主属性（固定值）
    local mainChildren = {
        UI.Label { text = "▸ 主属性", fontSize = T.fontSize.xs,
                   fontColor = {200, 160, 160, 220}, paddingLeft = T.spacing.xs,
                   marginBottom = T.spacing.xs },
    }
    for stat, value in pairs(targetDef.mainStat or {}) do
        local icon = STAT_ICONS[stat] or "📊"
        local name = STAT_NAMES[stat] or stat
        local valStr = FormatStatVal(stat, value)
        table.insert(mainChildren, UI.Panel {
            flexDirection = "row", justifyContent = "space-between", alignItems = "center",
            paddingLeft = T.spacing.xs, paddingRight = T.spacing.xs,
            height = STAT_ROW_H,
            children = {
                UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.md, fontColor = {255, 255, 230, 255} },
                UI.Label { text = valStr, fontSize = T.fontSize.md, fontWeight = "bold", fontColor = {255, 215, 0, 255} },
            },
        })
    end
    table.insert(rows, UI.Panel {
        backgroundColor = {math.floor(qColor[1] * 0.15), math.floor(qColor[2] * 0.15), math.floor(qColor[3] * 0.15), 220},
        borderRadius = T.radius.sm, borderWidth = 1, borderColor = {qColor[1], qColor[2], qColor[3], 100},
        padding = T.spacing.sm, gap = T.spacing.xs, children = mainChildren,
    })

    -- 副属性（随机范围）
    local subChildren = {
        UI.Label { text = "▸ 副属性（随机锻造）", fontSize = T.fontSize.xs,
                   fontColor = {160, 180, 200, 220}, paddingLeft = T.spacing.xs,
                   marginBottom = T.spacing.xs },
    }
    for _, sub in ipairs(targetDef.subStats or {}) do
        local icon = STAT_ICONS[sub.stat] or "📊"
        local name = sub.name or STAT_NAMES[sub.stat] or sub.stat
        local subDef = nil
        for _, s in ipairs(EquipmentData.SUB_STATS or {}) do
            if s.stat == sub.stat then subDef = s; break end
        end
        local valStr
        if subDef and subDef.linearGrowth then
            -- linearGrowth 属性值 = floor(tier × qMult)，使用产出装备实际阶级
            valStr = "+" .. math.floor(tier * qMult)
        else
            local baseVal = subDef and subDef.baseValue or 1
            local tierMult = (EquipmentData.PCT_STATS and EquipmentData.PCT_STATS[sub.stat]) and pctTM or numTM
            local minV = math.floor(baseVal * tierMult * randLo * 100 + 0.5) / 100
            local maxV = math.floor(baseVal * tierMult * randHi * 100 + 0.5) / 100
            valStr = FormatRange(sub.stat, minV, maxV)
        end
        table.insert(subChildren, UI.Panel {
            flexDirection = "row", justifyContent = "space-between", alignItems = "center",
            paddingLeft = T.spacing.xs, paddingRight = T.spacing.xs, height = STAT_ROW_H,
            children = {
                UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.sm, fontColor = {220, 220, 240, 255} },
                UI.Label { text = valStr, fontSize = T.fontSize.xxs, fontWeight = "bold", fontColor = {150, 255, 150, 255}, flexShrink = 1 },
            },
        })
    end
    table.insert(rows, UI.Panel {
        backgroundColor = {25, 30, 45, 220}, borderRadius = T.radius.sm,
        padding = T.spacing.sm, gap = T.spacing.xs, children = subChildren,
    })

    -- 灵性属性（随机，显示❓）
    if targetDef.hasSpiritStat then
        table.insert(rows, UI.Panel {
            backgroundColor = {20, 45, 45, 220}, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {0, 200, 200, 120},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 灵性属性", fontSize = T.fontSize.xs,
                           fontColor = {0, 200, 200, 220}, paddingLeft = T.spacing.xs },
                UI.Panel {
                    flexDirection = "row", justifyContent = "center", alignItems = "center",
                    paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                    children = {
                        UI.Label { text = "❓ 随机属性", fontSize = T.fontSize.sm, fontColor = {0, 200, 200, 150} },
                    },
                },
            },
        })
    end

    -- 圣性属性（确认固定 或 随机❓）
    if targetDef.saintStat and targetDef.saintStat.confirmed then
        -- 帝尊圣戒：固定圣性属性
        local ss = targetDef.saintStat
        local icon = STAT_ICONS[ss.stat] or "🔴"
        local name = ss.name or STAT_NAMES[ss.stat] or ss.stat
        local valStr = FormatStatVal(ss.stat, ss.value)
        table.insert(rows, UI.Panel {
            backgroundColor = {50, 10, 10, 230}, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {255, 60, 60, 150},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 圣性属性（固定）", fontSize = T.fontSize.xs,
                           fontColor = {255, 80, 80, 230}, paddingLeft = T.spacing.xs },
                UI.Panel {
                    flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                    paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm, height = STAT_ROW_H,
                    children = {
                        UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.sm, fontColor = {255, 180, 180, 255} },
                        UI.Label { text = valStr, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 80, 80, 255} },
                    },
                },
            },
        })
    elseif targetDef.hasSaintStat then
        -- 四把仙剑：随机圣性属性
        table.insert(rows, UI.Panel {
            backgroundColor = {50, 10, 10, 230}, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {255, 60, 60, 120},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 圣性属性", fontSize = T.fontSize.xs,
                           fontColor = {255, 80, 80, 200}, paddingLeft = T.spacing.xs },
                UI.Panel {
                    flexDirection = "row", justifyContent = "center", alignItems = "center",
                    paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                    children = {
                        UI.Label { text = "❓ 随机圣性", fontSize = T.fontSize.sm, fontColor = {255, 80, 80, 150} },
                    },
                },
            },
        })
    end

    -- 特殊效果（若有）
    if targetDef.specialEffect then
        local eff = targetDef.specialEffect
        table.insert(rows, UI.Panel {
            backgroundColor = {55, 25, 20, 220}, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {220, 120, 60, 100},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "✨ " .. (eff.name or "特殊效果"),
                           fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 160, 60, 255} },
                UI.Label { text = GetSpecialEffectDesc(eff),
                           fontSize = T.fontSize.xs, fontColor = {255, 200, 150, 200} },
            },
        })
    end

    -- 法宝技能（若有）
    if targetDef.skillId then
        local ok, SkillData = pcall(require, "config.SkillData")
        if ok and SkillData then
            local skillDef = SkillData.Skills and SkillData.Skills[targetDef.skillId]
            if skillDef then
                table.insert(rows, UI.Panel {
                    backgroundColor = {40, 35, 15, 220}, borderRadius = T.radius.sm,
                    borderWidth = 1, borderColor = {255, 200, 50, 100},
                    padding = T.spacing.sm, gap = T.spacing.xs,
                    children = {
                        UI.Label { text = (skillDef.icon or "✨") .. " " .. skillDef.name,
                                   fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 200, 50, 255} },
                        UI.Label { text = skillDef.description or "",
                                   fontSize = T.fontSize.xs, fontColor = {255, 220, 150, 200} },
                    },
                })
            end
        end
    end

    -- 底部标签
    table.insert(rows, UI.Panel {
        width = "100%", alignItems = "center", paddingTop = T.spacing.xs,
        children = {
            UI.Label {
                text = "打造后",
                fontSize = T.fontSize.xs,
                fontColor = {60, 130, 60, 220},
                backgroundColor = {60, 130, 60, 40},
                paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
                borderRadius = T.radius.sm,
            },
        },
    })

    return rows
end

-- ============================================================================
-- 成功弹窗（背包圣器/法宝）
-- ============================================================================

local function HideForgeSuccess()
    if successPanel_ then
        successPanel_:Remove()
        successPanel_ = nil
    end
    if GameState.uiOpen == "forge_success" then
        GameState.uiOpen = "sword_forge"
    end
end

local function SuccessStatRow(icon, name, valStr, nameColor, valColor)
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        width = "100%",
        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
        height = STAT_ROW_H,
        children = {
            UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.sm, fontColor = nameColor },
            UI.Label { text = valStr, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = valColor },
        },
    }
end

local function ShowForgeSuccess(item, title, subtitle)
    if successPanel_ then HideForgeSuccess() end
    if not parentOverlay_ then return end

    local qualityConfig = GameConfig.QUALITY[item.quality]
    local qColor = qualityConfig and qualityConfig.color or RED_COLOR
    local goldColor = {255, 215, 0, 255}

    -- 主属性行
    local mainChildren = {}
    for stat, value in pairs(item.mainStat or {}) do
        table.insert(mainChildren, SuccessStatRow(
            STAT_ICONS[stat] or "📊", STAT_NAMES[stat] or stat,
            FormatStatVal(stat, value),
            {255, 255, 230, 255}, goldColor
        ))
    end

    -- 副属性行
    local subChildren = {}
    for _, sub in ipairs(item.subStats or {}) do
        table.insert(subChildren, SuccessStatRow(
            STAT_ICONS[sub.stat] or "📊", sub.name or STAT_NAMES[sub.stat] or sub.stat,
            FormatStatVal(sub.stat, sub.value),
            {220, 220, 240, 255}, {150, 255, 150, 255}
        ))
    end

    -- 灵性属性
    local spiritWidget = nil
    if item.spiritStat then
        local ss = item.spiritStat
        spiritWidget = UI.Panel {
            width = "100%",
            backgroundColor = {20, 45, 45, 220},
            borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {0, 200, 200, 120},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 灵性属性", fontSize = T.fontSize.xs, fontColor = {0, 200, 200, 220}, paddingLeft = T.spacing.xs },
                SuccessStatRow(
                    STAT_ICONS[ss.stat] or "✨", ss.name or STAT_NAMES[ss.stat] or ss.stat,
                    FormatStatVal(ss.stat, ss.value),
                    {150, 240, 240, 255}, {0, 230, 230, 255}
                ),
            },
        }
    end

    -- 圣性属性
    local saintWidget = nil
    if item.saintStat then
        local ss = item.saintStat
        saintWidget = UI.Panel {
            width = "100%",
            backgroundColor = {50, 10, 10, 230},
            borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {255, 60, 60, 150},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 圣性属性", fontSize = T.fontSize.xs, fontColor = {255, 80, 80, 230}, paddingLeft = T.spacing.xs },
                SuccessStatRow(
                    STAT_ICONS[ss.stat] or "🔴", ss.name or STAT_NAMES[ss.stat] or ss.stat,
                    FormatStatVal(ss.stat, ss.value),
                    {255, 180, 180, 255}, {255, 80, 80, 255}
                ),
            },
        }
    end

    -- 套装标记
    local setWidget = nil
    if item.setId then
        local setData = EquipmentData.SetBonuses[item.setId]
        local setName = setData and setData.name or item.setId
        setWidget = UI.Panel {
            width = "100%",
            backgroundColor = {50, 30, 50, 220},
            borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {200, 100, 200, 120},
            padding = T.spacing.sm,
            children = {
                UI.Label { text = "🔮 套装：" .. setName, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {220, 150, 255, 255} },
            },
        }
    end

    local contentChildren = {
        UI.Panel {
            width = "100%",
            backgroundColor = {qColor[1] * 0.15, qColor[2] * 0.15, qColor[3] * 0.15, 220},
            borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {qColor[1], qColor[2], qColor[3], 100},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 主属性", fontSize = T.fontSize.xs, fontColor = {200, 160, 160, 220}, paddingLeft = T.spacing.xs },
                table.unpack(mainChildren),
            },
        },
        UI.Panel {
            width = "100%",
            backgroundColor = {25, 30, 45, 220},
            borderRadius = T.radius.sm,
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 副属性", fontSize = T.fontSize.xs, fontColor = {160, 180, 200, 220}, paddingLeft = T.spacing.xs },
                table.unpack(subChildren),
            },
        },
    }
    if spiritWidget then table.insert(contentChildren, spiritWidget) end
    if saintWidget  then table.insert(contentChildren, saintWidget)  end
    if setWidget    then table.insert(contentChildren, setWidget)    end

    -- 技能标记（法宝专用）
    if item.skillId then
        local SkillData = require("config.SkillData")
        local skillDef = SkillData.Skills[item.skillId]
        if skillDef then
            table.insert(contentChildren, UI.Panel {
                width = "100%",
                backgroundColor = {40, 35, 15, 220},
                borderRadius = T.radius.sm,
                borderWidth = 1, borderColor = {255, 200, 50, 100},
                padding = T.spacing.sm, gap = T.spacing.xs,
                children = {
                    UI.Label { text = (skillDef.icon or "✨") .. " " .. skillDef.name,
                               fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 200, 50, 255} },
                    UI.Label { text = skillDef.description or "", fontSize = T.fontSize.xs, fontColor = {255, 220, 150, 200} },
                },
            })
        end
    end

    local slotName = EquipmentData.SLOT_NAMES[item.slot] or item.slot
    local qualityName = qualityConfig and qualityConfig.name or item.quality

    successPanel_ = UI.Panel {
        id = "swordForgeSuccessPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = T.color.overlay,
        zIndex = 250,
        onClick = function(self) end,
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = T.spacing.md,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 2, borderColor = {qColor[1], qColor[2], qColor[3], 180},
                padding = T.spacing.xl,
                width = "88%",
                maxWidth = 400,
                maxHeight = "85%", overflow = "scroll",
                onClick = function(self) end,
                children = {
                    UI.Label { text = title, fontSize = T.fontSize.xl + 2, fontWeight = "bold",
                               fontColor = goldColor, textAlign = "center" },
                    UI.Label { text = subtitle, fontSize = T.fontSize.sm,
                               fontColor = {qColor[1], qColor[2], qColor[3], 160}, textAlign = "center" },
                    UI.Panel { width = "80%", height = 1, backgroundColor = {qColor[1], qColor[2], qColor[3], 60} },
                    UI.Label { text = item.name, fontSize = T.fontSize.lg, fontWeight = "bold",
                               fontColor = {qColor[1], qColor[2], qColor[3], 255}, textAlign = "center" },
                    UI.Label { text = EquipmentData.GetTierDisplayName(item.tier) .. " [" .. qualityName .. "] " .. slotName,
                               fontSize = T.fontSize.sm,
                               fontColor = {qColor[1], qColor[2], qColor[3], 180}, textAlign = "center" },
                    UI.Panel { width = "80%", height = 1, backgroundColor = {qColor[1], qColor[2], qColor[3], 40} },
                    UI.Panel { width = "100%", gap = T.spacing.sm, children = contentChildren },
                    UI.Panel { width = "80%", height = 1, backgroundColor = {qColor[1], qColor[2], qColor[3], 40} },
                    UI.Button {
                        text = "确认",
                        width = 180, height = T.size.dialogBtnH,
                        fontSize = T.fontSize.md, fontWeight = "bold",
                        fontColor = T.color.btnSuccessFg, borderRadius = T.radius.md,
                        backgroundColor = T.color.btnSuccess,
                        onClick = function(self) HideForgeSuccess() end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(successPanel_)
    GameState.uiOpen = "forge_success"
end

-- ============================================================================
-- UI 刷新（前向引用占位）
-- ============================================================================

local RefreshUI

-- ============================================================================
-- 执行打造
-- ============================================================================

--- 执行铸剑地炉打造（委托 ForgeSystem）
---@param recipeId string
function SwordForgeUI.DoForgeSword(recipeId)
    local result = ForgeSystem.Execute(recipeId)
    if not result.success then
        resultLabel_:SetText(result.error or "铸造失败")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    local refreshOk, refreshErr = pcall(RefreshUI)
    if not refreshOk then
        print("[SwordForgeUI] WARNING: RefreshUI error after forge: " .. tostring(refreshErr))
    end

    -- 根据产出模式选择弹窗内容
    local recipe = EquipmentData.FORGE_RECIPES[recipeId]
    local title, subtitle, displayItem

    if recipe and recipe.outputMode == "replace_weapon" then
        -- 解封古剑路径
        title       = "⚔️ 解封古剑！"
        subtitle    = "封印破除，圣剑出世"
        displayItem = result.weapon
    elseif recipe and recipe.generator and recipe.generator.type == "longhunling" then
        title       = "🐲 龙魂令铸成！"
        subtitle    = "千枚剑灵融入龙极，龙魂觉醒"
        displayItem = result.item
    elseif recipe and recipe.generator and recipe.generator.type == "random_lingqi_mixed" then
        title       = "✨ 灵器铸成！"
        subtitle    = (result.item and result.item.setId) and "套装灵器，天工巧铸" or "灵器出炉，神光隐现"
        displayItem = result.item
    else
        title       = "🔥 圣器铸成！"
        subtitle    = (recipe and recipe.desc) or "铸剑地炉，圣威显现"
        displayItem = result.item
    end

    local popupOk, popupErr = pcall(ShowForgeSuccess, displayItem, title, subtitle)
    if not popupOk then
        print("[SwordForgeUI] ERROR: ShowForgeSuccess failed: " .. tostring(popupErr))
        local itemName = displayItem and displayItem.name or "未知"
        resultLabel_:SetText("铸造成功！（" .. itemName .. "）")
        resultLabel_:SetStyle({ fontColor = {100, 255, 150, 255} })
    end
end

-- ============================================================================
-- 内容构建
-- ============================================================================

--- 构建当前选中配方的内容面板
local function BuildRecipeContent(recipeId)
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    local children = {}

    local costs = EquipmentData.SWORD_FORGE_COSTS or {}
    local recipe = costs[recipeId]
    if not recipe then
        return { UI.Label { text = "（配方数据缺失）", fontSize = T.fontSize.sm, fontColor = {255, 130, 100, 255} } }
    end

    local mgr = InventorySystem.GetManager()
    local materialRows = {}
    local canForge = true

    -- ── 标题行：产出名称 + 品质色 ──────────────────────────────────────────
    local outputTemplate = EquipmentData.SpecialEquipment[recipe.outputId]
    local isFabaoOutput  = (outputTemplate == nil)
    if not outputTemplate then
        outputTemplate = EquipmentData.FabaoTemplates[recipe.outputId]
    end
    -- outputTemplate 只用于后续面板构建，不再往 materialRows 写标题（标题在 BuildForgePreviewRows 内）

    -- ── 灵器铸造专属信息面板（outputId=nil 且配方含 lingqi）─────────────────
    local isLingqiRecipe = (recipe.outputId == nil) and string.find(recipeId, "lingqi")
    if isLingqiRecipe then
        local cyanColor = GameConfig.QUALITY["cyan"] and GameConfig.QUALITY["cyan"].color or {0, 200, 200, 255}
        -- 从 FORGE_RECIPES 获取 tier 和 setChance
        local forgeRecipe = EquipmentData.FORGE_RECIPES and EquipmentData.FORGE_RECIPES[recipeId]
        local gen = forgeRecipe and forgeRecipe.generator
        local tier = gen and gen.tier or 10
        local setChance = gen and gen.setChance or 0.30
        local normalChance = math.floor((1 - setChance) * 100 + 0.5)
        local setPercent = math.floor(setChance * 100 + 0.5)

        table.insert(materialRows, UI.Panel {
            width = "100%",
            backgroundColor = {25, 35, 40, 240},
            borderRadius = T.radius.lg,
            borderWidth = 1,
            borderColor = {cyanColor[1], cyanColor[2], cyanColor[3], 150},
            padding = T.spacing.md,
            gap = T.spacing.sm,
            alignItems = "center",
            children = {
                UI.Label { text = "⚒️ 灵器铸造", fontSize = T.fontSize.lg, fontWeight = "bold",
                           fontColor = {cyanColor[1], cyanColor[2], cyanColor[3], 255} },
                UI.Label { text = "T" .. tier .. " 灵器品质  随机槽位", fontSize = T.fontSize.sm,
                           fontColor = {cyanColor[1], cyanColor[2], cyanColor[3], 200} },
                UI.Panel { width = "80%", height = 1, backgroundColor = {0, 200, 200, 60} },
                UI.Label { text = "🎰 " .. setPercent .. "% 概率套装灵器，" .. normalChance .. "% 普通灵器",
                           fontSize = T.fontSize.sm, fontColor = {255, 215, 0, 255} },
                UI.Label { text = "🎲 随机槽位：武器/头盔/铠甲/肩甲/腰带/战靴/戒指/项链",
                           fontSize = T.fontSize.xs, fontColor = {180, 200, 220, 200} },
                UI.Label { text = "📦 产物放入背包", fontSize = T.fontSize.xs, fontColor = {180, 180, 190, 180} },
            },
        })
        table.insert(materialRows, UI.Panel { width = "100%", height = 1, backgroundColor = {80, 80, 100, 60} })
    end

    -- ── 背包空位（解封古剑原地变换，无需空位）──────────────────────────────
    local isJiefengRecipe = recipe.fromBag and recipe.fromBag.equipId
                            and string.find(recipe.fromBag.equipId, "fengyin_")
    local freeSlots = InventorySystem.GetFreeSlots()
    local hasSpace = isJiefengRecipe or (freeSlots > 0)
    if not hasSpace then canForge = false end
    if not isJiefengRecipe then
        table.insert(materialRows, UI.Label {
            text = "📦 背包空位：" .. freeSlots,
            fontSize = T.fontSize.xs,
            fontColor = (freeSlots > 0) and {130, 230, 130, 255} or {255, 130, 100, 255},
        })
    end

    -- ── 金币 ────────────────────────────────────────────────────────────────
    local canAfford = (recipe.gold == 0) or (player.gold >= recipe.gold)
    if not canAfford then canForge = false end
    if recipe.gold > 0 then
        table.insert(materialRows, UI.Label {
            text = "💰 " .. FormatGold(recipe.gold) .. "  （持有：" .. FormatGold(player.gold) .. "）",
            fontSize = T.fontSize.xs,
            fontColor = canAfford and {130, 230, 130, 255} or {255, 130, 100, 255},
        })
    end

    -- ── fromBag ──────────────────────────────────────────────────────────────
    local missingWeaponEquip = false  -- 解封配方缺少装备武器标记
    if recipe.fromBag then
        local isFengyinSword = recipe.fromBag.equipId and string.find(recipe.fromBag.equipId, "fengyin_")
        local hasFb
        if isFengyinSword then
            -- 封印四仙剑：检查装备栏（而非背包）
            local equippedWeapon = GetEquippedWeapon()
            hasFb = equippedWeapon ~= nil and equippedWeapon.equipId == recipe.fromBag.equipId
            if not hasFb then missingWeaponEquip = true end
        else
            local fbItem = mgr and FindBagItemByEquipId(mgr, recipe.fromBag.equipId)
            hasFb = fbItem ~= nil
        end
        if not hasFb then canForge = false end
        table.insert(materialRows, BuildBagEquipRow(recipe.fromBag.equipId, hasFb))
    end

    -- ── fromBag2 ─────────────────────────────────────────────────────────────
    if recipe.fromBag2 then
        local fb2Item = mgr and FindBagItemByEquipId(mgr, recipe.fromBag2.equipId)
        local hasFb2 = fb2Item ~= nil
        if not hasFb2 then canForge = false end
        table.insert(materialRows, BuildBagEquipRow(recipe.fromBag2.equipId, hasFb2))
    end

    -- ── fromBagList（如帝尊圣戒的5个戒指）────────────────────────────────────
    if recipe.fromBagList then
        local usedSlots2 = {}
        for _, fb in ipairs(recipe.fromBagList) do
            local foundItem, foundSlot = mgr and FindBagItemByEquipId(mgr, fb.equipId, usedSlots2)
            local has = foundItem ~= nil
            if not has then canForge = false end
            if foundSlot then usedSlots2[foundSlot] = true end
            table.insert(materialRows, BuildBagEquipRow(fb.equipId, has))
        end
    end

    -- ── 普通材料 ─────────────────────────────────────────────────────────────
    if recipe.materials then
        for _, mat in ipairs(recipe.materials) do
            local have = InventorySystem.CountUnlockedConsumable(mat.id)
            if have < mat.count then canForge = false end
            table.insert(materialRows, BuildMaterialRow(mat.id, mat.count, have))
        end
    end

    -- ── 配方描述 ─────────────────────────────────────────────────────────────
    if recipe.desc then
        table.insert(materialRows, UI.Panel {
            width = "100%", height = 1, backgroundColor = {80, 80, 100, 60},
        })
        table.insert(materialRows, UI.Label {
            text = recipe.desc, fontSize = T.fontSize.xs,
            fontColor = {200, 180, 160, 160}, flexWrap = "wrap", width = "100%",
        })
    end

    -- ── 打造按钮 ─────────────────────────────────────────────────────────────
    local btnText
    if not hasSpace then
        btnText = "背包已满"
    elseif not canAfford then
        btnText = "金币不足"
    elseif missingWeaponEquip then
        btnText = "⚠️ 需要装备武器"
    elseif not canForge then
        btnText = "材料不足"
    else
        if recipe.gold > 0 then
            btnText = "🔥 铸造（" .. FormatGold(recipe.gold) .. "）"
        else
            btnText = "🔥 铸造"
        end
    end

    table.insert(materialRows, UI.Button {
        text = btnText,
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.sm, fontWeight = "bold",
        variant = canForge and "primary" or "disabled",
        backgroundColor = canForge and {200, 50, 30, 220} or {80, 80, 90, 200},
        borderRadius = T.radius.md,
        onClick = function(self)
            if canForge then
                SwordForgeUI.DoForgeSword(recipeId)
            end
        end,
    })

    -- ── 解封仙剑配方：DragonForgeUI 风格（上部左右对比 + 下部材料） ───────────
    local isJiefeng = recipe.fromBag and recipe.fromBag.equipId
                      and string.find(recipe.fromBag.equipId, "fengyin_")

    if isJiefeng then
        local EquipTooltip = require("ui.EquipTooltip")
        local fromBagDef   = EquipmentData.SpecialEquipment[recipe.fromBag.equipId]
        -- 封印四仙剑在装备栏（而非背包）
        local equippedWeapon = GetEquippedWeapon()
        local fromBagItem  = (equippedWeapon and equippedWeapon.equipId == recipe.fromBag.equipId)
                             and equippedWeapon or nil
        local hasFromBag   = fromBagItem ~= nil

        -- 左面板：封印古剑（消耗品，显示装备栏中的实例）
        local curRows
        if hasFromBag then
            curRows = EquipTooltip.BuildItemInfoRows(fromBagItem, "消耗", {180, 80, 60, 220})
        else
            curRows = EquipTooltip.BuildItemInfoRows(fromBagDef, "缺少", {80, 50, 50, 220})
        end

        local curPanel = UI.Panel {
            flexGrow = 1, flexShrink = 1, flexBasis = 0,
            maxWidth = T.size.tooltipWidth,
            backgroundColor = T.color.equipTipComparePanelBg,
            borderRadius = T.radius.lg, borderWidth = 1,
            borderColor = hasFromBag and {200, 100, 80, 200} or T.color.equipTipComparePanelBorder,
            padding = T.spacing.sm, gap = T.spacing.sm,
            overflow = "hidden",
            children = curRows,
        }

        -- 右面板：解封仙剑属性预览
        local previewRows = BuildForgePreviewRows(outputTemplate)
        local qCfg = outputTemplate and GameConfig.QUALITY[outputTemplate.quality]
        local qColor = qCfg and qCfg.color or RED_COLOR

        local nextPanel = UI.Panel {
            flexGrow = 1, flexShrink = 1, flexBasis = 0,
            maxWidth = T.size.tooltipWidth,
            backgroundColor = T.color.equipTipComparePanelBg,
            borderRadius = T.radius.lg, borderWidth = 1,
            borderColor = {qColor[1], qColor[2], qColor[3], 180},
            padding = T.spacing.sm, gap = T.spacing.sm,
            overflow = "hidden",
            children = previewRows,
        }

        -- 上部：并排对比（紧贴，对齐 EquipTooltip）
        table.insert(children, UI.Panel {
            flexDirection = "row",
            gap = T.spacing.xs,
            alignItems = "flex-start",
            width = "100%",
            children = { curPanel, nextPanel },
        })

        -- 下部：材料（居中纯文字，无框体）
        table.insert(children, UI.Panel {
            width = "100%",
            gap = T.spacing.sm,
            padding = T.spacing.sm,
            alignItems = "center",
            children = materialRows,
        })

    elseif isLingqiRecipe then
        -- ── 灵器铸造配方：居中纯文字材料 ──────────────────────────────────────
        table.insert(children, UI.Panel {
            width = "100%",
            gap = T.spacing.sm,
            padding = T.spacing.sm,
            alignItems = "center",
            children = materialRows,
        })

    else
        -- ── 其他配方：上方产出预览（框体） + 下方材料（居中纯文字） ─────────────

        -- ── 右面板：产出属性预览 ──────────────────────────────────────────────
        local rightPanel
        if outputTemplate and outputTemplate.mainStat then
            local previewRows = BuildForgePreviewRows(outputTemplate)
            local rqCfg = GameConfig.QUALITY[outputTemplate.quality or "red"]
            local rqColor = rqCfg and rqCfg.color or RED_COLOR
            rightPanel = UI.Panel {
                width = "90%",
                maxWidth = T.size.tooltipWidth,
                backgroundColor = T.color.equipTipComparePanelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = {rqColor[1], rqColor[2], rqColor[3], 180},
                padding = T.spacing.sm, gap = T.spacing.sm,
                children = previewRows,
            }
        else
            -- 法宝类：龙魂令等，展示主属性/技能确认/灵性/其他随机
            local fabaoRows = {}
            local fabaoName = outputTemplate and outputTemplate.name or (recipe.outputId or "产出")
            table.insert(fabaoRows, UI.Label {
                text = fabaoName,
                fontSize = T.fontSize.lg, fontWeight = "bold",
                fontColor = {255, 50, 50, 255}, textAlign = "center",
            })
            table.insert(fabaoRows, UI.Label {
                text = "10阶  [圣器] 法宝",
                fontSize = T.fontSize.sm, fontColor = {255, 50, 50, 160}, textAlign = "center",
            })
            table.insert(fabaoRows, UI.Panel {
                width = "100%", height = 1, backgroundColor = {80, 85, 100, 120},
                marginTop = T.spacing.xs, marginBottom = T.spacing.xs,
            })

            -- 主属性（法宝固定）
            if outputTemplate and outputTemplate.mainStatBase then
                local mainVal = outputTemplate.mainStatBase
                              * (outputTemplate.mainStatTierMult or 10)
                              * 2.1  -- 圣器 qualityMult
                local statKey = outputTemplate.mainStatType or "atk"
                local icon = STAT_ICONS[statKey] or "📊"
                local name = STAT_NAMES[statKey] or statKey
                table.insert(fabaoRows, UI.Panel {
                    backgroundColor = {math.floor(255*0.15), math.floor(50*0.15), math.floor(50*0.15), 220},
                    borderRadius = T.radius.sm, borderWidth = 1, borderColor = {255, 50, 50, 100},
                    padding = T.spacing.sm, gap = T.spacing.xs,
                    children = {
                        UI.Label { text = "▸ 主属性", fontSize = T.fontSize.xs, fontColor = {200, 160, 160, 220}, paddingLeft = T.spacing.xs },
                        UI.Panel {
                            flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                            paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm, height = STAT_ROW_H,
                            children = {
                                UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.md, fontColor = {255, 255, 230, 255} },
                                UI.Label { text = FormatStatVal(statKey, mainVal), fontSize = T.fontSize.md, fontWeight = "bold", fontColor = {255, 215, 0, 255} },
                            },
                        },
                    },
                })
            end

            -- 装备技能（确认）
            if outputTemplate and outputTemplate.skillId then
                local ok2, SkillData2 = pcall(require, "config.SkillData")
                if ok2 and SkillData2 then
                    local skillDef2 = SkillData2.Skills and SkillData2.Skills[outputTemplate.skillId]
                    if skillDef2 then
                        table.insert(fabaoRows, UI.Panel {
                            backgroundColor = {40, 35, 15, 220}, borderRadius = T.radius.sm,
                            borderWidth = 1, borderColor = {255, 200, 50, 100},
                            padding = T.spacing.sm, gap = T.spacing.xs,
                            children = {
                                UI.Label { text = "▸ 装备技能（确认）", fontSize = T.fontSize.xs, fontColor = {255, 200, 80, 220}, paddingLeft = T.spacing.xs },
                                UI.Label { text = (skillDef2.icon or "✨") .. " " .. skillDef2.name,
                                           fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 200, 50, 255} },
                                UI.Label { text = skillDef2.description or "", fontSize = T.fontSize.xs, fontColor = {255, 220, 150, 200} },
                            },
                        })
                    end
                end
            end

            -- 灵性属性（随机）
            table.insert(fabaoRows, UI.Panel {
                backgroundColor = {20, 45, 45, 220}, borderRadius = T.radius.sm,
                borderWidth = 1, borderColor = {0, 200, 200, 120},
                padding = T.spacing.sm, gap = T.spacing.xs,
                children = {
                    UI.Label { text = "▸ 灵性属性（随机）", fontSize = T.fontSize.xs, fontColor = {0, 200, 200, 220}, paddingLeft = T.spacing.xs },
                    UI.Panel {
                        flexDirection = "row", justifyContent = "center", alignItems = "center",
                        paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                        children = {
                            UI.Label { text = "❓ 随机灵性", fontSize = T.fontSize.sm, fontColor = {0, 200, 200, 180} },
                        },
                    },
                },
            })

            -- 其他属性（随机）
            table.insert(fabaoRows, UI.Panel {
                backgroundColor = {25, 30, 45, 220}, borderRadius = T.radius.sm,
                padding = T.spacing.sm, gap = T.spacing.xs,
                children = {
                    UI.Label { text = "▸ 其他属性（随机）", fontSize = T.fontSize.xs, fontColor = {160, 180, 200, 220}, paddingLeft = T.spacing.xs },
                    UI.Panel {
                        flexDirection = "row", justifyContent = "center", alignItems = "center",
                        paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                        children = {
                            UI.Label { text = "❓ 随机属性", fontSize = T.fontSize.sm, fontColor = {150, 200, 255, 150} },
                        },
                    },
                },
            })

            -- 底部标签
            table.insert(fabaoRows, UI.Panel {
                width = "100%", alignItems = "center", paddingTop = T.spacing.xs,
                children = {
                    UI.Label {
                        text = "打造后",
                        fontSize = T.fontSize.xs, fontColor = {60, 130, 60, 220},
                        backgroundColor = {60, 130, 60, 40},
                        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
                        borderRadius = T.radius.sm,
                    },
                },
            })

            rightPanel = UI.Panel {
                width = "90%",
                maxWidth = T.size.tooltipWidth,
                backgroundColor = T.color.equipTipComparePanelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = {RED_COLOR[1], RED_COLOR[2], RED_COLOR[3], 150},
                padding = T.spacing.sm, gap = T.spacing.sm,
                children = fabaoRows,
            }
        end

        -- 上方：产出装备预览（居中框体）
        table.insert(children, UI.Panel {
            width = "100%",
            alignItems = "center",
            children = { rightPanel },
        })

        -- 下方：材料（居中纯文字，无框体）
        table.insert(children, UI.Panel {
            width = "100%",
            gap = T.spacing.sm,
            padding = T.spacing.sm,
            alignItems = "center",
            children = materialRows,
        })
    end

    return children
end

--- 构建页签栏（每个配方一个顶级页签）
local function BuildTabBar()
    local order = EquipmentData.SWORD_FORGE_ORDER or {}
    local costs = EquipmentData.SWORD_FORGE_COSTS or {}
    local tabs = {}

    for idx, recipeId in ipairs(order) do
        local recipe = costs[recipeId]
        if recipe then
            local isActive = (idx == currentRecipeIdx_)
            table.insert(tabs, UI.Button {
                text = recipe.label or recipeId,
                height = 30,
                paddingLeft = 8, paddingRight = 8,
                fontSize = T.fontSize.sm,
                fontWeight = isActive and "bold" or "normal",
                fontColor = isActive and {255, 255, 255, 255}
                                       or {RED_COLOR[1], RED_COLOR[2], RED_COLOR[3], 180},
                backgroundColor = isActive
                    and {RED_COLOR[1], RED_COLOR[2], RED_COLOR[3], 220}
                    or  {80, 25, 20, 200},
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = { RED_COLOR[1], RED_COLOR[2], RED_COLOR[3], isActive and 255 or 80 },
                onClick = function(self)
                    if currentRecipeIdx_ ~= idx then
                        currentRecipeIdx_ = idx
                        RefreshUI()
                    end
                end,
            })
        end
    end

    return UI.Panel {
        flexDirection = "row",
        width = "100%",
        gap = T.spacing.xs,
        justifyContent = "center",
        flexWrap = "wrap",
        children = tabs,
    }
end

--- 重建内容面板
local function RefreshUI_internal()
    if not outerPanel_ then return end

    if contentPanel_ then
        contentPanel_:Destroy()
        contentPanel_ = nil
    end

    if tabBarPanel_ then
        tabBarPanel_:Destroy()
        tabBarPanel_ = nil
    end

    tabBarPanel_ = BuildTabBar()
    outerPanel_:AddChild(tabBarPanel_)

    local order = EquipmentData.SWORD_FORGE_ORDER or {}
    local recipeId = order[currentRecipeIdx_]
    local newChildren = recipeId and BuildRecipeContent(recipeId) or {}

    contentPanel_ = UI.Panel {
        width = "100%", gap = T.spacing.sm, alignItems = "center",
        children = newChildren,
    }
    outerPanel_:AddChild(contentPanel_)
end

RefreshUI = function()
    RefreshUI_internal()
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function SwordForgeUI.Create(parentOverlay)
    resultLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = T.color.success,
        textAlign = "center",
    }

    outerPanel_ = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
    }

    panel_ = UI.Panel {
        id = "swordForgePanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 100,
        onClick = function(self) SwordForgeUI.Hide() end,
        children = {
            -- S2.4 固定高度卡片
            UI.Panel {
                width = "94%",
                maxWidth = T.size.tooltipWidth * 2 + 80,
                height = "76%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = T.color.forgeBorderRed,
                flexDirection = "column",
                onClick = function(self) end,  -- 防穿透
                children = {
                    -- ── Header ──
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        alignItems = "center", gap = T.spacing.md,
                        paddingLeft = T.spacing.md, paddingRight = T.spacing.md,
                        paddingTop = T.spacing.sm, paddingBottom = T.spacing.sm,
                        borderBottomWidth = 1,
                        borderColor = T.color.goldDark,
                        children = {
                            -- NPC 肖像
                            UI.Panel {
                                width = 64, height = 64,
                                borderRadius = T.radius.md,
                                backgroundColor = T.color.headerBg,
                                backgroundImage = "image/furnace_3x3_20260515085411.png",
                                backgroundFit = "cover",
                                borderWidth = 1, borderColor = T.color.forgeBorderRed,
                                overflow = "hidden",
                            },
                            -- 标题区
                            UI.Panel { flexGrow = 1, flexShrink = 1, gap = T.spacing.xxs, children = {
                                UI.Label { text = "铸剑地炉", fontSize = T.fontSize.lg,
                                           fontWeight = "bold", fontColor = T.color.gold },
                                UI.Label { text = "第五章·圣器锻造", fontSize = T.fontSize.xs,
                                           fontColor = T.color.textMuted },
                            }},
                            -- 关闭按钮（右侧）
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton, height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {255, 100, 100, 30},
                                onClick = function() SwordForgeUI.Hide() end,
                            },
                        },
                    },
                    -- ── ScrollView ──
                    UI.ScrollView {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        width = "100%",
                        padding = T.spacing.md,
                        gap = T.spacing.sm,
                        children = { outerPanel_ },
                    },
                    -- ── Footer ──
                    UI.Panel {
                        width = "100%", alignItems = "center", gap = T.spacing.xs,
                        paddingTop = T.spacing.sm, paddingBottom = T.spacing.sm,
                        borderTopWidth = 1, borderColor = T.color.border,
                        children = {
                            resultLabel_,
                            UI.Label { text = "点击空白处关闭", fontSize = T.fontSize.xs,
                                       fontColor = T.color.textMuted },
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
    parentOverlay_ = parentOverlay
end

function SwordForgeUI.Show()
    if panel_ and not visible_ then
        visible_ = true
        GameState.uiOpen = "sword_forge"
        currentRecipeIdx_ = 1
        resultLabel_:SetText("")
        RefreshUI()
        panel_:Show()
    end
end

function SwordForgeUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        if GameState.uiOpen == "sword_forge" then
            GameState.uiOpen = nil
        end
    end
end

function SwordForgeUI.IsVisible()
    return visible_
end

function SwordForgeUI.Destroy()
    if successPanel_ then HideForgeSuccess() end
    panel_ = nil
    contentPanel_ = nil
    outerPanel_ = nil
    tabBarPanel_ = nil
    parentOverlay_ = nil
    successPanel_ = nil
    visible_ = false
end

return SwordForgeUI
