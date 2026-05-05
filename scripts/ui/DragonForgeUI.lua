-- ============================================================================
-- DragonForgeUI.lua - 神真子·龙神圣器打造界面
-- 5页签（断流/焚天/噬魂/裂地/灭影），葫芦升级风格左右对比
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local IconUtils = require("utils.IconUtils")
local StatNames = require("utils.StatNames")
local FormatUtils = require("utils.FormatUtils")
local LootSystem = require("systems.LootSystem")

local DragonForgeUI = {}

local panel_ = nil
local visible_ = false
local contentPanel_ = nil
local outerPanel_ = nil
local tabBarPanel_ = nil
local resultLabel_ = nil
local parentOverlay_ = nil
local successPanel_ = nil

local currentTab_ = 1  -- 当前页签索引（1~5）

local PORTRAIT_SIZE = 64

--- 格式化金币数字（来自共享模块）
local FormatGold = FormatUtils.Gold

--- 获取当前装备的武器
local function GetEquippedWeapon()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return nil end
    return mgr:GetEquipmentItem("weapon")
end

-- 额外页签定义（背包打造模式）— 使用渐变色系与前5个Tab做区分
local EXTRA_TABS = {
    [6] = { label = "🐲龙极令", color = {255, 180, 30, 255}, inactiveColor = {80, 60, 20, 220} },
    [7] = { label = "⚒️灵器铸造", color = {50, 220, 180, 255}, inactiveColor = {20, 60, 55, 220} },
}

--- 构建页签栏
local function BuildTabBar()
    local recipes = EquipmentData.DRAGON_FORGE_RECIPES
    local tabs = {}

    for i, recipe in ipairs(recipes) do
        local isActive = (i == currentTab_)
        local targetDef = EquipmentData.SpecialEquipment[recipe.target]
        local qualityCfg = targetDef and GameConfig.QUALITY[targetDef.quality]
        local activeColor = qualityCfg and qualityCfg.color or {255, 80, 80, 255}

        table.insert(tabs, UI.Button {
            text = recipe.label,
            width = 52,
            height = 30,
            fontSize = T.fontSize.sm,
            fontWeight = isActive and "bold" or "normal",
            fontColor = isActive and {255, 255, 255, 255} or {180, 180, 190, 200},
            backgroundColor = isActive
                and { activeColor[1], activeColor[2], activeColor[3], 200 }
                or {50, 55, 65, 200},
            borderRadius = T.radius.sm,
            borderWidth = isActive and 1 or 0,
            borderColor = isActive and { activeColor[1], activeColor[2], activeColor[3], 255 } or nil,
            onClick = function(self)
                if currentTab_ ~= i then
                    currentTab_ = i
                    RefreshUI()
                end
            end,
        })
    end

    -- 追加额外页签（龙极令、灵器铸造）
    for tabIdx = 6, 7 do
        local def = EXTRA_TABS[tabIdx]
        local isActive = (tabIdx == currentTab_)
        local ic = def.inactiveColor or {50, 55, 65, 200}
        table.insert(tabs, UI.Button {
            text = def.label,
            height = 30,
            paddingLeft = 8, paddingRight = 8,
            fontSize = T.fontSize.sm,
            fontWeight = isActive and "bold" or "normal",
            fontColor = isActive and {255, 255, 255, 255} or {def.color[1], def.color[2], def.color[3], 180},
            backgroundColor = isActive
                and { def.color[1], def.color[2], def.color[3], 220 }
                or ic,
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = { def.color[1], def.color[2], def.color[3], isActive and 255 or 80 },
            onClick = function(self)
                if currentTab_ ~= tabIdx then
                    currentTab_ = tabIdx
                    RefreshUI()
                end
            end,
        })
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

--- 格式化范围值
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

-- ============================================================================
-- 属性显示辅助（预览面板 & 成功面板共用）
-- ============================================================================

local STAT_NAMES = StatNames.NAMES
local STAT_ICONS = StatNames.ICONS
local FormatStatVal = StatNames.FormatValue

local function SuccessStatRow(icon, name, valStr, nameColor, valColor)
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        width = "100%",
        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
        height = T.fontSize.sm + 12,
        children = {
            UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.sm, fontColor = nameColor },
            UI.Label { text = valStr, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = valColor },
        },
    }
end

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
    elseif eff.type == "sacrifice_aura" then
        return string.format("持续灼烧周围%.1f格敌人，每%.1f秒造成%.0f%%攻击力伤害",
            eff.range or 1.5, eff.tickInterval or 1.0, (eff.damagePercent or 0) * 100)
    elseif eff.type == "lifesteal_burst" then
        return string.format("击杀堆叠%d层释放前方AOE（%.0f%%攻击力），造成等量吸血，击杀回复%.0f%%最大生命",
            eff.maxStacks or 10, (eff.damagePercent or 1.0) * 100, (eff.healPercent or 0) * 100)
    elseif eff.type == "heavy_strike" then
        return string.format("每第%d次攻击必定触发重击", eff.hitInterval or 5)
    elseif eff.type == "shadow_strike" then
        return string.format("暴击时%.0f%%概率追加影击，造成%.0f%%攻击力伤害",
            (eff.triggerChance or 0) * 100, (eff.damagePercent or 0) * 100)
    elseif eff.type == "death_immunity" then
        return string.format("受致命伤害%.0f%%概率免死，保留1点生命并无敌%.1f秒",
            (eff.immuneChance or 0) * 100, eff.immuneDuration or 1.0)
    else
        return eff.description or (eff.name or "特殊效果")
    end
end

--- 构建打造后预览行（显示数值范围，灵性属性显示❓）
local function BuildForgePreviewRows(targetDef)
    local rows = {}
    local qColor = {255, 50, 50, 255}
    local randLo = 1.1   -- randBase for red quality
    local randHi = 1.5   -- randBase + 0.4
    local numTM = EquipmentData.SUB_STAT_TIER_MULT[9]   -- 11.0
    local pctTM = EquipmentData.PCT_SUB_TIER_MULT[9]    -- 6.0
    local qMult = GameConfig.QUALITY["red"].multiplier   -- 2.1

    -- 武器名
    table.insert(rows, UI.Label {
        text = targetDef.name,
        fontSize = T.fontSize.lg, fontWeight = "bold",
        fontColor = qColor, textAlign = "center",
    })
    table.insert(rows, UI.Label {
        text = "9阶  [圣器] 武器",
        fontSize = T.fontSize.sm,
        fontColor = {qColor[1], qColor[2], qColor[3], 180}, textAlign = "center",
    })
    table.insert(rows, UI.Panel { width = "100%", height = 1, backgroundColor = {80, 85, 100, 120}, marginTop = T.spacing.xs, marginBottom = T.spacing.xs })

    -- 主属性（固定）
    local mainChildren = {
        UI.Label { text = "▸ 主属性", fontSize = T.fontSize.xs, fontColor = {200, 160, 160, 220}, paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs },
    }
    for stat, value in pairs(targetDef.mainStat or {}) do
        local icon = STAT_ICONS[stat] or "📊"
        local name = STAT_NAMES[stat] or stat
        local valStr = FormatStatVal(stat, value)
        table.insert(mainChildren, UI.Panel {
            flexDirection = "row", justifyContent = "space-between", alignItems = "center",
            paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm, height = T.fontSize.md + 10,
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

    -- 副属性（显示范围）
    local subChildren = {
        UI.Label { text = "▸ 副属性（随机锻造）", fontSize = T.fontSize.xs, fontColor = {160, 180, 200, 220}, paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs },
    }
    for _, sub in ipairs(targetDef.subStats or {}) do
        local icon = STAT_ICONS[sub.stat] or "📊"
        local name = sub.name or STAT_NAMES[sub.stat] or sub.stat
        -- 查找基础定义
        local subDef = nil
        for _, s in ipairs(EquipmentData.SUB_STATS) do
            if s.stat == sub.stat then subDef = s; break end
        end
        local valStr
        if subDef and subDef.linearGrowth then
            local fixedVal = math.floor(9 * qMult)
            valStr = "+" .. fixedVal
        else
            local baseVal = subDef and subDef.baseValue or 1
            local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTM or numTM
            local minV = baseVal * tierMult * randLo
            local maxV = baseVal * tierMult * randHi
            minV = math.floor(minV * 100 + 0.5) / 100
            maxV = math.floor(maxV * 100 + 0.5) / 100
            valStr = FormatRange(sub.stat, minV, maxV)
        end
        table.insert(subChildren, UI.Panel {
            flexDirection = "row", justifyContent = "space-between", alignItems = "center",
            paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm, height = T.fontSize.sm + 10,
            children = {
                UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.sm, fontColor = {220, 220, 240, 255} },
                UI.Label { text = valStr, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {150, 255, 150, 255} },
            },
        })
    end
    table.insert(rows, UI.Panel {
        backgroundColor = {25, 30, 45, 220}, borderRadius = T.radius.sm,
        padding = T.spacing.sm, gap = T.spacing.xs, children = subChildren,
    })

    -- 灵性属性（随机，显示❓）
    table.insert(rows, UI.Panel {
        backgroundColor = {20, 45, 45, 220}, borderRadius = T.radius.sm,
        borderWidth = 1, borderColor = {0, 200, 200, 120},
        padding = T.spacing.sm, gap = T.spacing.xs,
        children = {
            UI.Label { text = "▸ 灵性属性", fontSize = T.fontSize.xs, fontColor = {0, 200, 200, 220}, paddingLeft = T.spacing.xs },
            UI.Panel {
                flexDirection = "row", justifyContent = "center", alignItems = "center",
                paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                children = {
                    UI.Label { text = "❓ 随机属性", fontSize = T.fontSize.sm, fontColor = {0, 200, 200, 150} },
                },
            },
        },
    })

    -- 特殊效果（固定）
    if targetDef.specialEffect then
        local eff = targetDef.specialEffect
        table.insert(rows, UI.Panel {
            backgroundColor = {55, 25, 20, 220}, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {220, 120, 60, 100},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "✨ " .. (eff.name or "特殊效果"), fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 160, 60, 255} },
                UI.Label { text = GetSpecialEffectDesc(eff), fontSize = T.fontSize.xs, fontColor = {255, 200, 150, 200} },
            },
        })
    end

    -- 标签
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
-- 背包打造模式内容构建（Tab 6 龙极令 / Tab 7 灵器铸造）
-- ============================================================================

--- 构建龙极令打造内容（Tab 6）
local function BuildLongjiContent()
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    local children = {}

    local cost = EquipmentData.LONGJI_FORGE_COST

    -- 产物说明区
    local cyanColor = GameConfig.QUALITY["cyan"] and GameConfig.QUALITY["cyan"].color or {0, 200, 200, 255}
    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = {30, 35, 50, 240},
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = {cyanColor[1], cyanColor[2], cyanColor[3], 150},
        padding = T.spacing.md,
        gap = T.spacing.sm,
        alignItems = "center",
        children = {
            UI.Label { text = "🐲 龙极令", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = {255, 200, 50, 255} },
            UI.Label { text = "T9 灵器品质  攻击型法宝", fontSize = T.fontSize.sm, fontColor = {cyanColor[1], cyanColor[2], cyanColor[3], 200} },
            UI.Panel { width = "80%", height = 1, backgroundColor = {255, 200, 50, 60} },
            UI.Label { text = "⚔️ 主属性：攻击力（standard 公式）", fontSize = T.fontSize.sm, fontColor = {255, 215, 0, 255} },
            UI.Label { text = "🐲 专属技能：龙息（90°扇形AOE，仙缘伤害）", fontSize = T.fontSize.sm, fontColor = {255, 200, 50, 230} },
            UI.Label { text = "📦 产物放入背包", fontSize = T.fontSize.xs, fontColor = {180, 180, 190, 180} },
        },
    })

    -- 材料消耗区
    local materialRows = {}
    local materialsOk = true

    -- 太虚令
    local taixuHave = InventorySystem.CountConsumable("taixu_token")
    local taixuNeed = cost.taixu_token
    local taixuOk = taixuHave >= taixuNeed
    if not taixuOk then materialsOk = false end
    table.insert(materialRows, UI.Panel {
        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
        children = {
            UI.Label { text = "🔮", fontSize = T.fontSize.sm },
            UI.Label {
                text = "太虚令  " .. taixuHave .. "/" .. taixuNeed,
                fontSize = T.fontSize.xs,
                fontColor = taixuOk and {130, 230, 130, 255} or {255, 130, 100, 255},
            },
        },
    })

    -- 四龙鳞材料
    for _, mat in ipairs(cost.materials) do
        local matDef = GameConfig.PET_MATERIALS[mat.id]
        local matName = matDef and matDef.name or mat.id
        local matIcon = matDef and matDef.icon or "❓"
        local have = InventorySystem.CountConsumable(mat.id)
        local enough = have >= mat.count
        if not enough then materialsOk = false end
        table.insert(materialRows, UI.Panel {
            flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
            children = {
                UI.Label { text = matIcon, fontSize = T.fontSize.sm },
                UI.Label {
                    text = matName .. "  " .. have .. "/" .. mat.count,
                    fontSize = T.fontSize.xs,
                    fontColor = enough and {130, 230, 130, 255} or {255, 130, 100, 255},
                },
            },
        })
    end

    -- 背包空位检查
    local freeSlots = InventorySystem.GetFreeSlots()
    local hasSpace = freeSlots > 0
    if not hasSpace then materialsOk = false end
    table.insert(materialRows, UI.Label {
        text = "📦 背包空位：" .. freeSlots,
        fontSize = T.fontSize.xs,
        fontColor = hasSpace and {130, 230, 130, 255} or {255, 130, 100, 255},
    })

    local canForge = materialsOk

    -- 打造按钮
    local btnText
    if not hasSpace then
        btnText = "背包已满"
    elseif not taixuOk then
        btnText = "太虚令不足"
    elseif not materialsOk then
        btnText = "材料不足"
    else
        btnText = "打造龙极令（1000 太虚令）"
    end

    table.insert(materialRows, UI.Button {
        text = btnText,
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.sm,
        variant = canForge and "primary" or "disabled",
        backgroundColor = canForge and {180, 140, 30, 220} or {80, 80, 90, 200},
        onClick = function(self)
            if canForge then
                DragonForgeUI.DoForgeLongji()
            end
        end,
    })

    table.insert(children, UI.Panel {
        width = "100%", gap = T.spacing.sm,
        padding = T.spacing.sm,
        alignItems = "center",
        children = materialRows,
    })

    return children
end

--- 构建灵器铸造内容（Tab 7）
local function BuildLingqiContent()
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    local children = {}

    local cost = EquipmentData.LINGQI_FORGE_COST
    local cyanColor = GameConfig.QUALITY["cyan"] and GameConfig.QUALITY["cyan"].color or {0, 200, 200, 255}

    -- 产物说明区
    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = {25, 35, 40, 240},
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = {cyanColor[1], cyanColor[2], cyanColor[3], 150},
        padding = T.spacing.md,
        gap = T.spacing.sm,
        alignItems = "center",
        children = {
            UI.Label { text = "⚒️ 灵器铸造", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = {cyanColor[1], cyanColor[2], cyanColor[3], 255} },
            UI.Label { text = "T9 灵器品质  随机槽位", fontSize = T.fontSize.sm, fontColor = {cyanColor[1], cyanColor[2], cyanColor[3], 200} },
            UI.Panel { width = "80%", height = 1, backgroundColor = {0, 200, 200, 60} },
            UI.Label { text = "🎰 30% 概率套装灵器，70% 普通灵器", fontSize = T.fontSize.sm, fontColor = {255, 215, 0, 255} },
            UI.Label { text = "🎲 随机槽位：武器/头盔/铠甲/肩甲/腰带/战靴/戒指/项链", fontSize = T.fontSize.xs, fontColor = {180, 200, 220, 200} },
            UI.Label { text = "📦 产物放入背包", fontSize = T.fontSize.xs, fontColor = {180, 180, 190, 180} },
        },
    })

    -- 材料消耗区
    local materialRows = {}
    local materialsOk = true

    -- 金币
    local canAfford = player.gold >= cost.gold
    if not canAfford then materialsOk = false end
    table.insert(materialRows, UI.Label {
        text = "💰 消耗：" .. FormatGold(cost.gold) .. " 金币（当前：" .. FormatGold(player.gold) .. "）",
        fontSize = T.fontSize.xs,
        fontColor = canAfford and {130, 230, 130, 255} or {255, 130, 100, 255},
    })

    -- 四龙鳞材料
    for _, mat in ipairs(cost.materials) do
        local matDef = GameConfig.PET_MATERIALS[mat.id]
        local matName = matDef and matDef.name or mat.id
        local matIcon = matDef and matDef.icon or "❓"
        local have = InventorySystem.CountConsumable(mat.id)
        local enough = have >= mat.count
        if not enough then materialsOk = false end
        table.insert(materialRows, UI.Panel {
            flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
            children = {
                UI.Label { text = matIcon, fontSize = T.fontSize.sm },
                UI.Label {
                    text = matName .. "  " .. have .. "/" .. mat.count,
                    fontSize = T.fontSize.xs,
                    fontColor = enough and {130, 230, 130, 255} or {255, 130, 100, 255},
                },
            },
        })
    end

    -- 背包空位检查
    local freeSlots = InventorySystem.GetFreeSlots()
    local hasSpace = freeSlots > 0
    if not hasSpace then materialsOk = false end
    table.insert(materialRows, UI.Label {
        text = "📦 背包空位：" .. freeSlots,
        fontSize = T.fontSize.xs,
        fontColor = hasSpace and {130, 230, 130, 255} or {255, 130, 100, 255},
    })

    local canForge = materialsOk

    -- 打造按钮
    local btnText
    if not hasSpace then
        btnText = "背包已满"
    elseif not canAfford then
        btnText = "金币不足"
    elseif not materialsOk then
        btnText = "材料不足"
    else
        btnText = "铸造灵器（" .. FormatGold(cost.gold) .. " 金币）"
    end

    table.insert(materialRows, UI.Button {
        text = btnText,
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.sm,
        variant = canForge and "primary" or "disabled",
        backgroundColor = canForge and {30, 150, 150, 220} or {80, 80, 90, 200},
        onClick = function(self)
            if canForge then
                DragonForgeUI.DoForgeLingqi()
            end
        end,
    })

    table.insert(children, UI.Panel {
        width = "100%", gap = T.spacing.sm,
        padding = T.spacing.sm,
        alignItems = "center",
        children = materialRows,
    })

    return children
end

--- 构建动态内容（每次刷新重建）
local function BuildContent()
    local EquipTooltip = require("ui.EquipTooltip")
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    local children = {}

    -- Tab 6/7 走背包打造模式
    if currentTab_ == 6 then return BuildLongjiContent() end
    if currentTab_ == 7 then return BuildLingqiContent() end

    local recipes = EquipmentData.DRAGON_FORGE_RECIPES
    local recipe = recipes[currentTab_]
    if not recipe then return children end

    local sourceDef = EquipmentData.SpecialEquipment[recipe.source]
    local targetDef = EquipmentData.SpecialEquipment[recipe.target]
    if not sourceDef or not targetDef then return children end

    local weapon = GetEquippedWeapon()
    local hasSource = weapon and weapon.equipId == recipe.source

    -- 左侧：当前灵器（如果已装备）
    local curRows
    if hasSource then
        curRows = EquipTooltip.BuildItemInfoRows(weapon, "当前", {80, 80, 100, 220})
    else
        -- 未装备该灵器：显示灵器模板
        curRows = EquipTooltip.BuildItemInfoRows(sourceDef, "需装备", {120, 80, 80, 220})
    end

    -- 右侧：圣器预览（显示数值范围 + 灵性❓）
    local nextRows = BuildForgePreviewRows(targetDef)

    local curPanel = UI.Panel {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        maxWidth = T.size.tooltipWidth,
        backgroundColor = {25, 28, 38, 245},
        borderRadius = T.radius.lg, borderWidth = 1,
        borderColor = hasSource and {100, 200, 220, 200} or {80, 80, 90, 150},
        padding = T.spacing.sm, gap = T.spacing.sm,
        overflow = "hidden",
        children = curRows,
    }

    local targetQColor = GameConfig.QUALITY[targetDef.quality]
    local nextBorderColor = targetQColor and targetQColor.color or {255, 80, 80, 255}

    local nextPanel = UI.Panel {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        maxWidth = T.size.tooltipWidth,
        backgroundColor = {30, 22, 22, 245},
        borderRadius = T.radius.lg, borderWidth = 1,
        borderColor = { nextBorderColor[1], nextBorderColor[2], nextBorderColor[3], 180 },
        padding = T.spacing.sm, gap = T.spacing.sm,
        overflow = "hidden",
        children = nextRows,
    }

    local arrowPanel = UI.Panel {
        justifyContent = "center", alignItems = "center",
        paddingTop = T.spacing.lg,
        children = {
            UI.Label { text = "➜", fontSize = T.fontSize.xl, fontColor = {255, 200, 100, 255} },
        },
    }

    table.insert(children, UI.Panel {
        flexDirection = "row",
        gap = T.spacing.xs,
        alignItems = "flex-start",
        width = "100%",
        children = { curPanel, arrowPanel, nextPanel },
    })

    -- 打造条件区
    local cost = EquipmentData.DRAGON_FORGE_COST
    local canAfford = player.gold >= cost.gold
    local materialsOk = true
    local materialRows = {}

    for _, mat in ipairs(cost.materials) do
        local matDef = GameConfig.PET_MATERIALS[mat.id]
        local matName = matDef and matDef.name or mat.id
        local matIcon = matDef and matDef.icon or "❓"
        local have = InventorySystem.CountConsumable(mat.id)
        local enough = have >= mat.count
        if not enough then materialsOk = false end

        table.insert(materialRows, UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.xs,
            children = {
                UI.Label { text = matIcon, fontSize = T.fontSize.sm },
                UI.Label {
                    text = matName .. "  " .. have .. "/" .. mat.count,
                    fontSize = T.fontSize.xs,
                    fontColor = enough and {130, 230, 130, 255} or {255, 130, 100, 255},
                },
            },
        })
    end

    local canForge = hasSource and canAfford and materialsOk

    -- 装备状态
    if not hasSource then
        table.insert(materialRows, 1, UI.Label {
            text = "⚠ 需装备「" .. sourceDef.name .. "」",
            fontSize = T.fontSize.xs,
            fontColor = {255, 180, 80, 255},
        })
    end

    -- 金币
    local costText = "💰 消耗：" .. FormatGold(cost.gold) .. " 金币（当前：" .. FormatGold(player.gold) .. "）"
    local costColor = canAfford and {130, 230, 130, 255} or {255, 130, 100, 255}

    table.insert(materialRows, UI.Label {
        text = costText,
        fontSize = T.fontSize.xs,
        fontColor = costColor,
    })

    -- 打造按钮
    local btnText
    if not hasSource then
        btnText = "未装备灵器"
    elseif not materialsOk then
        btnText = "材料不足"
    elseif not canAfford then
        btnText = "金币不足"
    else
        btnText = "打造圣器（" .. FormatGold(cost.gold) .. "）"
    end

    table.insert(materialRows, UI.Button {
        text = btnText,
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.sm,
        variant = canForge and "primary" or "disabled",
        backgroundColor = canForge and {160, 60, 60, 220} or {80, 80, 90, 200},
        onClick = function(self)
            if canForge then
                DragonForgeUI.DoForge()
            end
        end,
    })

    table.insert(children, UI.Panel {
        width = "100%", gap = T.spacing.sm,
        padding = T.spacing.sm,
        alignItems = "center",
        children = materialRows,
    })

    return children
end

--- 刷新面板显示（销毁旧内容，重建）
local function RefreshUI_internal()
    if not outerPanel_ then return end

    if contentPanel_ then
        contentPanel_:Destroy()
        contentPanel_ = nil
    end

    -- 重建页签栏
    if tabBarPanel_ then
        tabBarPanel_:Destroy()
        tabBarPanel_ = nil
    end
    tabBarPanel_ = BuildTabBar()
    outerPanel_:AddChild(tabBarPanel_)

    -- 重建内容
    local newChildren = BuildContent()
    contentPanel_ = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
        alignItems = "center",
        children = newChildren,
    }
    outerPanel_:AddChild(contentPanel_)
end

-- 公开刷新（供 forward ref 使用）
function RefreshUI()
    RefreshUI_internal()
end

function DragonForgeUI.Create(parentOverlay)
    resultLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {100, 255, 150, 255},
        textAlign = "center",
    }

    outerPanel_ = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
    }

    panel_ = UI.Panel {
        id = "dragonForgePanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingBottom = T.spacing.xl,
        visible = false,
        zIndex = 100,
        children = {
            UI.Panel {
                width = "96%",
                maxWidth = T.size.tooltipWidth * 2 + 80,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {200, 80, 80, 180},
                padding = T.spacing.md,
                gap = T.spacing.sm,
                maxHeight = "90%",
                overflow = "scroll",
                children = {
                    -- 顶部：标题 + 关闭
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.md,
                        children = {
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton, height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function() DragonForgeUI.Hide() end,
                            },
                            UI.Panel {
                                width = PORTRAIT_SIZE,
                                height = PORTRAIT_SIZE,
                                borderRadius = T.radius.md,
                                backgroundColor = {30, 35, 50, 200},
                                overflow = "hidden",
                            },
                            UI.Label {
                                text = "🔨 龙神圣器打造",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = {255, 180, 80, 255},
                                flexGrow = 1, flexShrink = 1,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {200, 80, 80, 60} },
                    -- 动态内容区（页签+内容）
                    outerPanel_,
                    -- 结果提示
                    resultLabel_,
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
    parentOverlay_ = parentOverlay
end

-- ============================================================================
-- 打造成功展示面板
-- ============================================================================

local function HideForgeSuccess()
    if successPanel_ then
        successPanel_:Remove()
        successPanel_ = nil
    end
    if GameState.uiOpen == "forge_success" then
        GameState.uiOpen = "dragon_forge"
    end
end

local function ShowForgeSuccess(weapon, targetDef)
    if successPanel_ then HideForgeSuccess() end
    if not parentOverlay_ then return end

    local qColor = {255, 50, 50, 255}  -- red 圣器 color
    local goldColor = {255, 215, 0, 255}

    -- 武器图标区
    local iconWidget
    local iconChild
    if IconUtils.IsImagePath(targetDef.icon) then
        iconChild = UI.Panel { width = 60, height = 60, backgroundImage = targetDef.icon, backgroundFit = "contain" }
    else
        iconChild = UI.Label { text = targetDef.icon or "⚔️", fontSize = 40, textAlign = "center" }
    end
    iconWidget = UI.Panel {
        width = 80, height = 80,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {qColor[1], qColor[2], qColor[3], 25},
        borderRadius = T.radius.lg,
        borderWidth = 2,
        borderColor = {qColor[1], qColor[2], qColor[3], 180},
        children = { iconChild },
    }

    -- 主属性区
    local mainChildren = {}
    for stat, value in pairs(weapon.mainStat or {}) do
        table.insert(mainChildren, SuccessStatRow(
            STAT_ICONS[stat] or "📊", STAT_NAMES[stat] or stat,
            FormatStatVal(stat, value),
            {255, 255, 230, 255}, goldColor
        ))
    end

    -- 副属性区
    local subChildren = {}
    for _, sub in ipairs(weapon.subStats or {}) do
        table.insert(subChildren, SuccessStatRow(
            STAT_ICONS[sub.stat] or "📊", sub.name or STAT_NAMES[sub.stat] or sub.stat,
            FormatStatVal(sub.stat, sub.value),
            {220, 220, 240, 255}, {150, 255, 150, 255}
        ))
    end

    -- 灵性属性区
    local spiritWidget = nil
    if weapon.spiritStat then
        local ss = weapon.spiritStat
        spiritWidget = UI.Panel {
            width = "100%",
            backgroundColor = {20, 45, 45, 220},
            borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {0, 200, 200, 120},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = "▸ 灵性属性",
                    fontSize = T.fontSize.xs,
                    fontColor = {0, 200, 200, 220},
                    paddingLeft = T.spacing.xs,
                },
                SuccessStatRow(
                    STAT_ICONS[ss.stat] or "✨", ss.name or STAT_NAMES[ss.stat] or ss.stat,
                    FormatStatVal(ss.stat, ss.value),
                    {150, 240, 240, 255}, {0, 230, 230, 255}
                ),
            },
        }
    end

    -- 特殊效果区
    local effectWidget = nil
    if weapon.specialEffect then
        local eff = weapon.specialEffect
        effectWidget = UI.Panel {
            width = "100%",
            backgroundColor = {55, 25, 20, 220},
            borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {220, 120, 60, 120},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = "✨ " .. (eff.name or "特殊效果"),
                    fontSize = T.fontSize.sm, fontWeight = "bold",
                    fontColor = {255, 160, 60, 255},
                },
                UI.Label {
                    text = GetSpecialEffectDesc(eff),
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 200, 150, 210},
                },
            },
        }
    end

    -- 组装内容区
    local contentChildren = {
        -- 主属性
        UI.Panel {
            width = "100%",
            backgroundColor = {qColor[1] * 0.15, qColor[2] * 0.15, qColor[3] * 0.15, 220},
            borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = {qColor[1], qColor[2], qColor[3], 100},
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = "▸ 主属性",
                    fontSize = T.fontSize.xs,
                    fontColor = {200, 160, 160, 220},
                    paddingLeft = T.spacing.xs,
                },
                table.unpack(mainChildren),
            },
        },
        -- 副属性
        UI.Panel {
            width = "100%",
            backgroundColor = {25, 30, 45, 220},
            borderRadius = T.radius.sm,
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = "▸ 副属性（随机锻造）",
                    fontSize = T.fontSize.xs,
                    fontColor = {160, 180, 200, 220},
                    paddingLeft = T.spacing.xs,
                },
                table.unpack(subChildren),
            },
        },
    }
    if spiritWidget then table.insert(contentChildren, spiritWidget) end
    if effectWidget then table.insert(contentChildren, effectWidget) end

    successPanel_ = UI.Panel {
        id = "forgeSuccessPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 180},
        zIndex = 250,
        onClick = function(self) end,  -- 防穿透
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                backgroundColor = {25, 18, 18, 250},
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = {qColor[1], qColor[2], qColor[3], 180},
                paddingTop = T.spacing.xl,
                paddingBottom = T.spacing.xl,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                minWidth = 260,
                maxWidth = T.size.tooltipWidth + 40,
                maxHeight = "85%",
                overflow = "scroll",
                onClick = function(self) end,
                children = {
                    -- 标题
                    UI.Label {
                        text = "⚔️ 龙极铸成！",
                        fontSize = T.fontSize.xl + 2,
                        fontWeight = "bold",
                        fontColor = goldColor,
                        textAlign = "center",
                    },
                    -- 副标题
                    UI.Label {
                        text = "灵器蜕变，龙威降世",
                        fontSize = T.fontSize.sm,
                        fontColor = {255, 180, 120, 160},
                        textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel { width = "80%", height = 1, backgroundColor = {255, 80, 50, 60} },
                    -- 图标
                    iconWidget,
                    -- 武器名
                    UI.Label {
                        text = targetDef.name,
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = qColor,
                        textAlign = "center",
                    },
                    -- 阶级品质
                    UI.Label {
                        text = "9阶 [圣器] 武器",
                        fontSize = T.fontSize.sm,
                        fontColor = {qColor[1], qColor[2], qColor[3], 180},
                        textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel { width = "80%", height = 1, backgroundColor = {255, 80, 50, 40} },
                    -- 属性内容区
                    UI.Panel {
                        width = "100%",
                        gap = T.spacing.sm,
                        children = contentChildren,
                    },
                    -- 分割线
                    UI.Panel { width = "80%", height = 1, backgroundColor = {255, 80, 50, 40} },
                    -- 确认按钮
                    UI.Button {
                        text = "确认",
                        width = 180,
                        height = 44,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 255, 255, 255},
                        borderRadius = T.radius.md,
                        backgroundColor = {180, 50, 50, 255},
                        onClick = function(self)
                            HideForgeSuccess()
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(successPanel_)
    GameState.uiOpen = "forge_success"
end

--- 执行打造
function DragonForgeUI.DoForge()
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    if not player then return end

    local recipes = EquipmentData.DRAGON_FORGE_RECIPES
    local recipe = recipes[currentTab_]
    if not recipe then return end

    local weapon = GetEquippedWeapon()
    if not weapon or weapon.equipId ~= recipe.source then
        resultLabel_:SetText("请先装备「" .. (EquipmentData.SpecialEquipment[recipe.source] or {}).name .. "」")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    local cost = EquipmentData.DRAGON_FORGE_COST

    -- 检查材料
    for _, mat in ipairs(cost.materials) do
        if InventorySystem.CountConsumable(mat.id) < mat.count then
            local matDef = GameConfig.PET_MATERIALS[mat.id]
            resultLabel_:SetText("材料不足：" .. (matDef and matDef.name or mat.id))
            resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
            return
        end
    end

    -- 检查金币
    if player.gold < cost.gold then
        resultLabel_:SetText("金币不足！需要" .. FormatGold(cost.gold) .. "金币")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 扣除金币
    player:SpendGold(cost.gold)

    -- 扣除材料
    for _, mat in ipairs(cost.materials) do
        InventorySystem.ConsumeConsumable(mat.id, mat.count)
    end

    -- 获取圣器模板
    local targetDef = EquipmentData.SpecialEquipment[recipe.target]
    if not targetDef then
        resultLabel_:SetText("打造失败：配方数据异常")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 保留原武器的洗练属性（如果有）
    local oldForgeStat = weapon.forgeStat

    -- 替换武器属性为圣器
    weapon.equipId = recipe.target
    weapon.name = targetDef.name
    weapon.icon = targetDef.icon
    weapon.quality = targetDef.quality
    weapon.tier = targetDef.tier
    weapon.sellPrice = targetDef.sellPrice
    weapon.sellCurrency = targetDef.sellCurrency
    weapon.mainStat = {}
    for k, v in pairs(targetDef.mainStat) do
        weapon.mainStat[k] = v
    end
    -- 副属性：条目类型固定（来自模板），数值随机浮动
    weapon.subStats = {}
    local qualityOrder = GameConfig.QUALITY_ORDER["red"]  -- 7
    local shift = math.max(0, qualityOrder - 4) * 0.1     -- 0.3
    local randBase = 0.8 + shift                           -- 1.1
    local numTierMult = EquipmentData.SUB_STAT_TIER_MULT[9]  -- 11.0
    local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[9]   -- 6.0
    local qualityMult = GameConfig.QUALITY["red"].multiplier  -- 2.1

    for _, templateSub in ipairs(targetDef.subStats) do
        -- 查找 SUB_STATS 基础定义
        local subDef = nil
        for _, s in ipairs(EquipmentData.SUB_STATS) do
            if s.stat == templateSub.stat then subDef = s; break end
        end

        local value
        if subDef and subDef.linearGrowth then
            -- 线性成长属性：固定值，无波动
            value = math.floor(9 * qualityMult)
            if value <= 0 then value = 1 end
        else
            -- 数值/百分比属性：baseValue × tierMult × 随机(1.1~1.5)
            local baseVal = subDef and subDef.baseValue or 1
            local tierMult = EquipmentData.PCT_STATS[templateSub.stat] and pctTierMult or numTierMult
            value = baseVal * tierMult * (randBase + math.random() * 0.4)
            value = math.floor(value * 100 + 0.5) / 100
            if value <= 0 then value = 0.01 end
        end

        table.insert(weapon.subStats, {
            stat = templateSub.stat,
            name = templateSub.name,
            value = value,
        })
    end

    weapon.specialEffect = targetDef.specialEffect
    -- 灵性属性：类型随机，数值随机（半值）
    weapon.spiritStat = LootSystem.GenerateSpiritStat(9, "atk", "red")

    -- 恢复洗练
    if oldForgeStat then
        weapon.forgeStat = oldForgeStat
    end

    -- 重新计算装备属性
    InventorySystem.RecalcEquipStats()

    -- 即时存档：龙极打造消耗大量金币和稀有材料且结果随机，防止退出重刷
    EventBus.Emit("save_request")

    EventBus.Emit("equipment_changed")
    RefreshUI()

    -- 弹出打造成功展示面板
    ShowForgeSuccess(weapon, targetDef)
end

-- ============================================================================
-- 龙极令打造（背包模式）
-- ============================================================================

--- 背包打造通用成功弹窗（法宝/灵器共用）
local function ShowBagForgeSuccess(item, title, subtitle)
    if successPanel_ then HideForgeSuccess() end
    if not parentOverlay_ then return end

    local qualityConfig = GameConfig.QUALITY[item.quality]
    local qColor = qualityConfig and qualityConfig.color or {0, 200, 200, 255}
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
    if setWidget then table.insert(contentChildren, setWidget) end

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
                    UI.Label { text = (skillDef.icon or "✨") .. " " .. skillDef.name, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 200, 50, 255} },
                    UI.Label { text = skillDef.description or "", fontSize = T.fontSize.xs, fontColor = {255, 220, 150, 200} },
                },
            })
        end
    end

    -- 槽位信息
    local slotName = EquipmentData.SLOT_NAMES[item.slot] or item.slot
    local qualityName = qualityConfig and qualityConfig.name or item.quality

    successPanel_ = UI.Panel {
        id = "forgeSuccessPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 180},
        zIndex = 250,
        onClick = function(self) end,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                backgroundColor = {20, 25, 30, 250},
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = {qColor[1], qColor[2], qColor[3], 180},
                paddingTop = T.spacing.xl,
                paddingBottom = T.spacing.xl,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                minWidth = 260,
                maxWidth = T.size.tooltipWidth + 40,
                maxHeight = "85%",
                overflow = "scroll",
                onClick = function(self) end,
                children = {
                    UI.Label { text = title, fontSize = T.fontSize.xl + 2, fontWeight = "bold", fontColor = goldColor, textAlign = "center" },
                    UI.Label { text = subtitle, fontSize = T.fontSize.sm, fontColor = {qColor[1], qColor[2], qColor[3], 160}, textAlign = "center" },
                    UI.Panel { width = "80%", height = 1, backgroundColor = {qColor[1], qColor[2], qColor[3], 60} },
                    UI.Label { text = item.name, fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = {qColor[1], qColor[2], qColor[3], 255}, textAlign = "center" },
                    UI.Label { text = item.tier .. "阶 [" .. qualityName .. "] " .. slotName, fontSize = T.fontSize.sm, fontColor = {qColor[1], qColor[2], qColor[3], 180}, textAlign = "center" },
                    UI.Panel { width = "80%", height = 1, backgroundColor = {qColor[1], qColor[2], qColor[3], 40} },
                    UI.Panel { width = "100%", gap = T.spacing.sm, children = contentChildren },
                    UI.Panel { width = "80%", height = 1, backgroundColor = {qColor[1], qColor[2], qColor[3], 40} },
                    UI.Button {
                        text = "确认",
                        width = 180, height = 44,
                        fontSize = T.fontSize.md, fontWeight = "bold",
                        fontColor = {255, 255, 255, 255},
                        borderRadius = T.radius.md,
                        backgroundColor = {qColor[1], qColor[2], qColor[3], 220},
                        onClick = function(self) HideForgeSuccess() end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(successPanel_)
    GameState.uiOpen = "forge_success"
end

--- 执行龙极令打造
function DragonForgeUI.DoForgeLongji()
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    if not player then return end

    local cost = EquipmentData.LONGJI_FORGE_COST

    -- 检查背包空位
    if InventorySystem.GetFreeSlots() <= 0 then
        resultLabel_:SetText("背包已满，无法打造")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 检查太虚令
    if InventorySystem.CountConsumable("taixu_token") < cost.taixu_token then
        resultLabel_:SetText("太虚令不足！需要" .. cost.taixu_token .. "枚")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 检查材料
    for _, mat in ipairs(cost.materials) do
        if InventorySystem.CountConsumable(mat.id) < mat.count then
            local matDef = GameConfig.PET_MATERIALS[mat.id]
            resultLabel_:SetText("材料不足：" .. (matDef and matDef.name or mat.id))
            resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
            return
        end
    end

    -- 扣除太虚令
    InventorySystem.ConsumeConsumable("taixu_token", cost.taixu_token)

    -- 扣除材料
    for _, mat in ipairs(cost.materials) do
        InventorySystem.ConsumeConsumable(mat.id, mat.count)
    end

    -- 创建龙极令法宝
    local item = LootSystem.CreateFabaoEquipment("fabao_longjiling", 9, "cyan")
    if not item then
        resultLabel_:SetText("打造失败：数据异常")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 放入背包
    local ok = InventorySystem.AddItem(item)
    if not ok then
        resultLabel_:SetText("放入背包失败")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 即时存档
    EventBus.Emit("save_request")
    EventBus.Emit("equipment_changed")

    local refreshOk, refreshErr = pcall(RefreshUI)
    if not refreshOk then
        print("[DragonForgeUI] WARNING: RefreshUI error after longji forge: " .. tostring(refreshErr))
    end

    -- 成功弹窗
    local popupOk, popupErr = pcall(ShowBagForgeSuccess, item, "🐲 龙极令铸成！", "四龙之威凝为一令")
    if not popupOk then
        print("[DragonForgeUI] ERROR: ShowBagForgeSuccess failed: " .. tostring(popupErr))
        resultLabel_:SetText("打造成功！（龙极令已放入背包）")
        resultLabel_:SetStyle({ fontColor = {100, 255, 150, 255} })
    end
end

-- ============================================================================
-- 灵器铸造（背包模式）
-- ============================================================================

--- 执行灵器铸造
function DragonForgeUI.DoForgeLingqi()
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    if not player then return end

    local cost = EquipmentData.LINGQI_FORGE_COST

    -- 检查背包空位
    if InventorySystem.GetFreeSlots() <= 0 then
        resultLabel_:SetText("背包已满，无法铸造")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 检查金币
    if player.gold < cost.gold then
        resultLabel_:SetText("金币不足！需要" .. FormatGold(cost.gold) .. "金币")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 检查材料
    for _, mat in ipairs(cost.materials) do
        if InventorySystem.CountConsumable(mat.id) < mat.count then
            local matDef = GameConfig.PET_MATERIALS[mat.id]
            resultLabel_:SetText("材料不足：" .. (matDef and matDef.name or mat.id))
            resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
            return
        end
    end

    -- 扣除金币
    player:SpendGold(cost.gold)

    -- 扣除材料
    for _, mat in ipairs(cost.materials) do
        InventorySystem.ConsumeConsumable(mat.id, mat.count)
    end

    -- 生成灵器：30% 套装 / 70% 普通
    local item
    local isSet = math.random() < EquipmentData.LINGQI_FORGE_SET_CHANCE
    if isSet then
        item = LootSystem.ForgeRandomSetLingqi()
    else
        item = LootSystem.ForgeRandomLingqi()
    end

    if not item then
        resultLabel_:SetText("铸造失败：数据异常")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 放入背包
    local ok = InventorySystem.AddItem(item)
    if not ok then
        resultLabel_:SetText("放入背包失败")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    -- 即时存档
    EventBus.Emit("save_request")
    EventBus.Emit("equipment_changed")

    local refreshOk, refreshErr = pcall(RefreshUI)
    if not refreshOk then
        print("[DragonForgeUI] WARNING: RefreshUI error after lingqi forge: " .. tostring(refreshErr))
    end

    -- 成功弹窗
    local title = isSet and "🔮 套装灵器铸成！" or "⚒️ 灵器铸成！"
    local subtitle = isSet and "龙鳞淬炼，套装显现" or "龙鳞淬炼，灵器出世"
    local popupOk, popupErr = pcall(ShowBagForgeSuccess, item, title, subtitle)
    if not popupOk then
        print("[DragonForgeUI] ERROR: ShowBagForgeSuccess failed: " .. tostring(popupErr))
        resultLabel_:SetText("铸造成功！（灵器已放入背包）")
        resultLabel_:SetStyle({ fontColor = {100, 255, 150, 255} })
    end
end

function DragonForgeUI.Show(npc)
    if panel_ and not visible_ then
        visible_ = true
        GameState.uiOpen = "dragon_forge"
        currentTab_ = 1
        resultLabel_:SetText("")
        RefreshUI()
        panel_:Show()
    end
end

function DragonForgeUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        if GameState.uiOpen == "dragon_forge" then
            GameState.uiOpen = nil
        end
    end
end

function DragonForgeUI.IsVisible()
    return visible_
end

function DragonForgeUI.Destroy()
    if successPanel_ then HideForgeSuccess() end
    panel_ = nil
    contentPanel_ = nil
    outerPanel_ = nil
    tabBarPanel_ = nil
    parentOverlay_ = nil
    successPanel_ = nil
    visible_ = false
end

return DragonForgeUI
