-- ============================================================================
-- DragonForgeUI.lua - 龙神圣器打造界面（第四章）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: S2.4固定高度 | 7页签(5圣器+龙极令+灵器) | 左右对比预览 | S10按钮语义
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local IconUtils = require("utils.IconUtils")
local StatNames = require("utils.StatNames")
local FormatUtils = require("utils.FormatUtils")
local ForgeSystem = require("systems.ForgeSystem")

local DragonForgeUI = {}

---@type any
local panel_ = nil
local visible_ = false
---@type any
local contentPanel_ = nil
---@type any
local outerPanel_ = nil
---@type any
local tabBarPanel_ = nil
---@type any
local resultLabel_ = nil
---@type any
local parentOverlay_ = nil
---@type any
local successPanel_ = nil

local currentTab_ = 1  -- 当前页签索引（1~7）

local PORTRAIT_SIZE = 64
local STAT_ROW_H    = 22

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
    [6] = { label = "🐲龙极令",  color = {255, 180, 30, 255},  inactiveColor = {80, 60, 20, 220}  },
    [7] = { label = "⚒️灵器铸造", color = {50, 220, 180, 255},  inactiveColor = {20, 60, 55, 220}  },
}

-- ============================================================================
-- 属性显示辅助（预览面板 & 成功面板共用）
-- ============================================================================

local STAT_NAMES    = StatNames.NAMES
local STAT_ICONS    = StatNames.ICONS
local FormatStatVal = StatNames.FormatValue

--- 单行属性行（icon + name 左对齐，val 右对齐）
local function SuccessStatRow(icon, name, valStr, nameColor, valColor)
    return UI.Panel {
        flexDirection    = "row",
        justifyContent   = "space-between",
        alignItems       = "center",
        width            = "100%",
        paddingLeft      = T.spacing.sm,
        paddingRight     = T.spacing.sm,
        height           = STAT_ROW_H,
        children = {
            UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.sm, fontColor = nameColor },
            UI.Label { text = valStr,               fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = valColor },
        },
    }
end

--- 特殊效果文字描述（从效果对象生成可读字符串）
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
    elseif eff.type == "xianyuan_lowest_boost" then
        return string.format("当前总值最低的仙缘属性额外获得%d点加成（唯一）", eff.bonus or 0)
    elseif eff.type == "yuanjia" then
        return string.format("受到伤害后，若当前生命低于50%%，获得%.0f%%减伤，持续%.0f秒（冷却%.0f秒）",
            (eff.dmgReduce or 0) * 100, eff.duration or 4, eff.cooldown or 8)
    else
        return eff.description or eff.desc or (eff.name or "特殊效果")
    end
end

-- ============================================================================
-- 格式化范围值
-- ============================================================================

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
-- 预览面板右侧：打造后圣器属性（含范围 + 灵性❓）
-- ============================================================================

local function BuildForgePreviewRows(targetDef)
    local rows = {}
    local qColor  = T.color.qualityRed
    local randLo  = 1.1
    local randHi  = 1.5
    local numTM   = EquipmentData.SUB_STAT_TIER_MULT[9]
    local pctTM   = EquipmentData.PCT_SUB_TIER_MULT[9]
    local qMult   = GameConfig.QUALITY["red"].multiplier

    -- 武器名 + 品阶
    table.insert(rows, UI.Label {
        text      = targetDef.name,
        fontSize  = T.fontSize.lg, fontWeight = "bold",
        fontColor = qColor, textAlign = "center",
    })
    table.insert(rows, UI.Label {
        text      = "9阶  [圣器] 武器",
        fontSize  = T.fontSize.sm,
        fontColor = { qColor[1], qColor[2], qColor[3], 180 },
        textAlign = "center",
    })
    table.insert(rows, UI.Panel {
        width = "100%", height = T.decor.dividerHeight,
        backgroundColor = T.decor.dividerColor,
        marginTop = T.spacing.xs, marginBottom = T.spacing.xs,
    })

    -- 主属性（固定）
    local mainChildren = {
        UI.Label {
            text = "▸ 主属性", fontSize = T.fontSize.xs,
            fontColor = T.color.equipTipStatLabel,
            paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs,
        },
    }
    for stat, value in pairs(targetDef.mainStat or {}) do
        local icon   = STAT_ICONS[stat] or "📊"
        local name   = STAT_NAMES[stat] or stat
        local valStr = FormatStatVal(stat, value)
        table.insert(mainChildren, UI.Panel {
            flexDirection  = "row", justifyContent = "space-between",
            alignItems     = "center",
            paddingLeft    = T.spacing.sm, paddingRight = T.spacing.sm,
            height         = STAT_ROW_H,
            children = {
                UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.md, fontColor = T.color.equipTipMainStatName },
                UI.Label { text = valStr,               fontSize = T.fontSize.md, fontWeight = "bold", fontColor = T.color.statValueGold },
            },
        })
    end
    table.insert(rows, UI.Panel {
        backgroundColor = T.decor.qualitySlotBg.red,
        borderRadius    = T.radius.sm,
        borderWidth     = 1,
        borderColor     = { qColor[1], qColor[2], qColor[3], 100 },
        padding         = T.spacing.sm,
        gap             = T.spacing.xs,
        children        = mainChildren,
    })

    -- 副属性（随机范围）
    local subChildren = {
        UI.Label {
            text = "▸ 副属性（随机锻造）", fontSize = T.fontSize.xs,
            fontColor   = T.color.equipTipStatLabel,
            paddingLeft = T.spacing.xs, marginBottom = T.spacing.xs,
        },
    }
    for _, sub in ipairs(targetDef.subStats or {}) do
        local icon = STAT_ICONS[sub.stat] or "📊"
        local name = sub.name or STAT_NAMES[sub.stat] or sub.stat
        local subDef = nil
        for _, s in ipairs(EquipmentData.SUB_STATS) do
            if s.stat == sub.stat then subDef = s; break end
        end
        local valStr
        if subDef and subDef.linearGrowth then
            local fixedVal = math.floor(9 * qMult)
            valStr = "+" .. fixedVal
        else
            local baseVal  = subDef and subDef.baseValue or 1
            local tierMult = EquipmentData.PCT_STATS[sub.stat] and pctTM or numTM
            local minV = baseVal * tierMult * randLo
            local maxV = baseVal * tierMult * randHi
            minV = math.floor(minV * 100 + 0.5) / 100
            maxV = math.floor(maxV * 100 + 0.5) / 100
            valStr = FormatRange(sub.stat, minV, maxV)
        end
        table.insert(subChildren, UI.Panel {
            flexDirection  = "row", justifyContent = "space-between",
            alignItems     = "center",
            paddingLeft    = T.spacing.xs, paddingRight = T.spacing.xs,
            height         = STAT_ROW_H,
            children = {
                UI.Label { text = icon .. " " .. name, fontSize = T.fontSize.sm, fontColor = T.color.equipTipSubStatName },
                UI.Label { text = valStr, fontSize = T.fontSize.xxs, fontWeight = "bold", fontColor = T.color.statValueGreen, flexShrink = 1 },
            },
        })
    end
    table.insert(rows, UI.Panel {
        backgroundColor = T.color.equipTipSubStatBg,
        borderRadius    = T.radius.sm,
        padding         = T.spacing.sm,
        gap             = T.spacing.xs,
        children        = subChildren,
    })

    -- 灵性属性（随机，显示❓）
    table.insert(rows, UI.Panel {
        backgroundColor = T.color.equipTipSpiritBg,
        borderRadius    = T.radius.sm,
        borderWidth     = 1,
        borderColor     = T.color.equipTipSpiritBorder,
        padding         = T.spacing.sm,
        gap             = T.spacing.xs,
        children = {
            UI.Label {
                text        = "▸ 灵性属性",
                fontSize    = T.fontSize.xs,
                fontColor   = T.color.equipTipSpiritLabel,
                paddingLeft = T.spacing.xs,
            },
            UI.Panel {
                flexDirection  = "row", justifyContent = "center",
                alignItems     = "center",
                paddingTop     = T.spacing.xs, paddingBottom = T.spacing.xs,
                children = {
                    UI.Label { text = "❓ 随机属性", fontSize = T.fontSize.sm, fontColor = { T.color.statValueCyan[1], T.color.statValueCyan[2], T.color.statValueCyan[3], 150 } },
                },
            },
        },
    })

    -- 特殊效果（固定）
    if targetDef.specialEffect then
        local eff = targetDef.specialEffect
        table.insert(rows, UI.Panel {
            backgroundColor = T.color.equipTipSpecialBg,
            borderRadius    = T.radius.sm,
            borderWidth     = 1,
            borderColor     = T.color.equipTipSpecialBorder,
            padding         = T.spacing.sm,
            gap             = T.spacing.xs,
            children = {
                UI.Label { text = "✨ " .. (eff.name or "特殊效果"), fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.equipTipSpecialName },
                UI.Label { text = GetSpecialEffectDesc(eff),            fontSize = T.fontSize.xs,                    fontColor = T.color.equipTipSpecialDesc },
            },
        })
    end

    -- "打造后"标签
    table.insert(rows, UI.Panel {
        width = "100%", alignItems = "center", paddingTop = T.spacing.xs,
        children = {
            UI.Label {
                text            = "打造后",
                fontSize        = T.fontSize.xs,
                fontColor       = T.color.matEnough,
                backgroundColor = { T.color.matEnough[1], T.color.matEnough[2], T.color.matEnough[3], 40 },
                paddingLeft     = T.spacing.sm, paddingRight = T.spacing.sm,
                borderRadius    = T.radius.sm,
            },
        },
    })

    return rows
end

-- ============================================================================
-- 页签栏构建
-- ============================================================================

local function BuildTabBar()
    local recipes = EquipmentData.DRAGON_FORGE_RECIPES
    local tabs = {}

    for i, recipe in ipairs(recipes) do
        local isActive    = (i == currentTab_)
        local targetDef   = EquipmentData.SpecialEquipment[recipe.target]
        local qualityCfg  = targetDef and GameConfig.QUALITY[targetDef.quality]
        local activeColor = qualityCfg and qualityCfg.color or T.color.qualityRed

        table.insert(tabs, UI.Button {
            text            = recipe.label,
            width           = 52,
            height          = 30,
            fontSize        = T.fontSize.sm,
            fontWeight      = isActive and "bold" or "normal",
            fontColor       = isActive and T.color.tabActiveText or T.color.tabInactiveText,
            backgroundColor = isActive
                and { activeColor[1], activeColor[2], activeColor[3], 200 }
                or  T.color.tabInactiveBg,
            borderRadius    = T.radius.sm,
            borderWidth     = isActive and 1 or 0,
            borderColor     = isActive and { activeColor[1], activeColor[2], activeColor[3], 255 } or nil,
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
        local def      = EXTRA_TABS[tabIdx]
        local isActive = (tabIdx == currentTab_)
        local ic       = def.inactiveColor or T.color.tabInactiveBg
        table.insert(tabs, UI.Button {
            text            = def.label,
            height          = 30,
            paddingLeft     = T.spacing.sm, paddingRight = T.spacing.sm,
            fontSize        = T.fontSize.sm,
            fontWeight      = isActive and "bold" or "normal",
            fontColor       = isActive
                and T.color.tabActiveText
                or { def.color[1], def.color[2], def.color[3], 180 },
            backgroundColor = isActive
                and { def.color[1], def.color[2], def.color[3], 220 }
                or  ic,
            borderRadius    = T.radius.sm,
            borderWidth     = 1,
            borderColor     = { def.color[1], def.color[2], def.color[3], isActive and 255 or 80 },
            onClick = function(self)
                if currentTab_ ~= tabIdx then
                    currentTab_ = tabIdx
                    RefreshUI()
                end
            end,
        })
    end

    return UI.Panel {
        flexDirection  = "row",
        width          = "100%",
        gap            = T.spacing.xs,
        justifyContent = "center",
        flexWrap       = "wrap",
        children       = tabs,
    }
end

-- ============================================================================
-- 背包打造模式内容构建（Tab 6 龙极令 / Tab 7 灵器铸造）
-- ============================================================================

--- 构建龙极令打造内容（Tab 6）
local function BuildLongjiContent()
    local InventorySystem = require("systems.InventorySystem")
    local player   = GameState.player
    local children = {}

    local cost      = EquipmentData.LONGJI_FORGE_COST
    local cyanColor = GameConfig.QUALITY["cyan"] and GameConfig.QUALITY["cyan"].color or T.color.statValueCyan

    -- 产物说明区
    table.insert(children, UI.Panel {
        width           = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius    = T.radius.lg,
        borderWidth     = 1,
        borderColor     = { cyanColor[1], cyanColor[2], cyanColor[3], 150 },
        padding         = T.spacing.md,
        gap             = T.spacing.sm,
        alignItems      = "center",
        children = {
            UI.Label { text = "🐲 龙极令",          fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.gold },
            UI.Label { text = "T9 灵器品质  攻击型法宝", fontSize = T.fontSize.sm,                    fontColor = { cyanColor[1], cyanColor[2], cyanColor[3], 200 } },
            UI.Panel { width = "80%", height = T.decor.dividerHeight, backgroundColor = { T.color.gold[1], T.color.gold[2], T.color.gold[3], 60 } },
            UI.Label { text = "⚔️ 主属性：攻击力（standard 公式）",        fontSize = T.fontSize.sm, fontColor = T.color.statValueGold },
            UI.Label { text = "🐲 专属技能：龙息（90°扇形AOE，仙缘伤害）", fontSize = T.fontSize.sm, fontColor = { T.color.gold[1], T.color.gold[2], T.color.gold[3], 230 } },
            UI.Label { text = "📦 产物放入背包",                             fontSize = T.fontSize.xs, fontColor = T.color.textSecondary },
        },
    })

    -- 材料消耗区
    local materialRows = {}
    local materialsOk  = true

    -- 太虚令
    local taixuHave = InventorySystem.CountUnlockedConsumable("taixu_token")
    local taixuNeed = cost.taixu_token
    local taixuOk   = taixuHave >= taixuNeed
    if not taixuOk then materialsOk = false end
    table.insert(materialRows, UI.Panel {
        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
        children = {
            UI.Label { text = "🔮", fontSize = T.fontSize.sm },
            UI.Label {
                text      = "太虚令  " .. taixuHave .. "/" .. taixuNeed,
                fontSize  = T.fontSize.xs,
                fontColor = taixuOk and T.color.matEnough or T.color.matInsufficient,
            },
        },
    })

    -- 四龙鳞材料
    for _, mat in ipairs(cost.materials) do
        local matDef  = GameConfig.PET_MATERIALS[mat.id]
        local matName = matDef and matDef.name or mat.id
        local matIcon = matDef and matDef.icon or "❓"
        local have    = InventorySystem.CountUnlockedConsumable(mat.id)
        local enough  = have >= mat.count
        if not enough then materialsOk = false end
        table.insert(materialRows, UI.Panel {
            flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
            children = {
                UI.Label { text = matIcon, fontSize = T.fontSize.sm },
                UI.Label {
                    text      = matName .. "  " .. have .. "/" .. mat.count,
                    fontSize  = T.fontSize.xs,
                    fontColor = enough and T.color.matEnough or T.color.matInsufficient,
                },
            },
        })
    end

    -- 背包空位检查
    local freeSlots = InventorySystem.GetFreeSlots()
    local hasSpace  = freeSlots > 0
    if not hasSpace then materialsOk = false end
    table.insert(materialRows, UI.Label {
        text      = "📦 背包空位：" .. freeSlots,
        fontSize  = T.fontSize.xs,
        fontColor = hasSpace and T.color.matEnough or T.color.matInsufficient,
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
        text            = btnText,
        width           = "100%",
        height          = T.size.dialogBtnH,
        fontSize        = T.fontSize.sm,
        backgroundColor = canForge and T.color.btnSpend    or T.color.btnDisabled,
        fontColor       = canForge and T.color.btnSpendFg  or T.color.btnDisabledFg,
        onClick = function(self)
            if canForge then DragonForgeUI.DoForgeLongji() end
        end,
    })

    table.insert(children, UI.Panel {
        width      = "100%",
        gap        = T.spacing.sm,
        padding    = T.spacing.sm,
        alignItems = "center",
        children   = materialRows,
    })

    return children
end

--- 构建灵器铸造内容（Tab 7）
local function BuildLingqiContent()
    local InventorySystem = require("systems.InventorySystem")
    local player   = GameState.player
    local children = {}

    local cost      = EquipmentData.LINGQI_FORGE_COST
    local cyanColor = GameConfig.QUALITY["cyan"] and GameConfig.QUALITY["cyan"].color or T.color.statValueCyan

    -- 产物说明区
    table.insert(children, UI.Panel {
        width           = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius    = T.radius.lg,
        borderWidth     = 1,
        borderColor     = { cyanColor[1], cyanColor[2], cyanColor[3], 150 },
        padding         = T.spacing.md,
        gap             = T.spacing.sm,
        alignItems      = "center",
        children = {
            UI.Label { text = "⚒️ 灵器铸造",               fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = { cyanColor[1], cyanColor[2], cyanColor[3], 255 } },
            UI.Label { text = "T9 灵器品质  随机槽位",       fontSize = T.fontSize.sm,                    fontColor = { cyanColor[1], cyanColor[2], cyanColor[3], 200 } },
            UI.Panel { width = "80%", height = T.decor.dividerHeight, backgroundColor = { T.color.statValueCyan[1], T.color.statValueCyan[2], T.color.statValueCyan[3], 60 } },
            UI.Label { text = "🎰 30% 概率套装灵器，70% 普通灵器",                          fontSize = T.fontSize.sm, fontColor = T.color.statValueGold },
            UI.Label { text = "🎲 随机槽位：武器/头盔/铠甲/肩甲/腰带/战靴/戒指/项链", fontSize = T.fontSize.xs, fontColor = T.color.textSecondary },
            UI.Label { text = "📦 产物放入背包",                                        fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
        },
    })

    -- 材料消耗区
    local materialRows = {}
    local materialsOk  = true

    -- 金币
    local canAfford = player.gold >= cost.gold
    if not canAfford then materialsOk = false end
    table.insert(materialRows, UI.Label {
        text      = "💰 消耗：" .. FormatGold(cost.gold) .. " 金币（当前：" .. FormatGold(player.gold) .. "）",
        fontSize  = T.fontSize.xs,
        fontColor = canAfford and T.color.matEnough or T.color.matInsufficient,
    })

    -- 四龙鳞材料
    for _, mat in ipairs(cost.materials) do
        local matDef  = GameConfig.PET_MATERIALS[mat.id]
        local matName = matDef and matDef.name or mat.id
        local matIcon = matDef and matDef.icon or "❓"
        local have    = InventorySystem.CountUnlockedConsumable(mat.id)
        local enough  = have >= mat.count
        if not enough then materialsOk = false end
        table.insert(materialRows, UI.Panel {
            flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
            children = {
                UI.Label { text = matIcon, fontSize = T.fontSize.sm },
                UI.Label {
                    text      = matName .. "  " .. have .. "/" .. mat.count,
                    fontSize  = T.fontSize.xs,
                    fontColor = enough and T.color.matEnough or T.color.matInsufficient,
                },
            },
        })
    end

    -- 背包空位检查
    local freeSlots = InventorySystem.GetFreeSlots()
    local hasSpace  = freeSlots > 0
    if not hasSpace then materialsOk = false end
    table.insert(materialRows, UI.Label {
        text      = "📦 背包空位：" .. freeSlots,
        fontSize  = T.fontSize.xs,
        fontColor = hasSpace and T.color.matEnough or T.color.matInsufficient,
    })

    local canForge = materialsOk

    -- 铸造按钮
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
        text            = btnText,
        width           = "100%",
        height          = T.size.dialogBtnH,
        fontSize        = T.fontSize.sm,
        backgroundColor = canForge and T.color.btnSpend   or T.color.btnDisabled,
        fontColor       = canForge and T.color.btnSpendFg or T.color.btnDisabledFg,
        onClick = function(self)
            if canForge then DragonForgeUI.DoForgeLingqi() end
        end,
    })

    table.insert(children, UI.Panel {
        width      = "100%",
        gap        = T.spacing.sm,
        padding    = T.spacing.sm,
        alignItems = "center",
        children   = materialRows,
    })

    return children
end

-- ============================================================================
-- 主内容区构建（动态，每次刷新重建）
-- ============================================================================

local function BuildContent()
    local EquipTooltip    = require("ui.EquipTooltip")
    local InventorySystem = require("systems.InventorySystem")
    local player          = GameState.player
    local children        = {}

    -- Tab 6/7 走背包打造模式
    if currentTab_ == 6 then return BuildLongjiContent() end
    if currentTab_ == 7 then return BuildLingqiContent() end

    local recipes  = EquipmentData.DRAGON_FORGE_RECIPES
    local recipe   = recipes[currentTab_]
    if not recipe then return children end

    local sourceDef = EquipmentData.SpecialEquipment[recipe.source]
    local targetDef = EquipmentData.SpecialEquipment[recipe.target]
    if not sourceDef or not targetDef then return children end

    local weapon    = GetEquippedWeapon()
    local hasSource = weapon and weapon.equipId == recipe.source

    -- 左侧面板：当前装备 / 需装备提示
    local curRows
    if hasSource then
        curRows = EquipTooltip.BuildItemInfoRows(weapon,    "当前",  T.color.equipTipComparePanelBg)
    else
        curRows = EquipTooltip.BuildItemInfoRows(sourceDef, "需装备", { 120, 80, 80, 220 })
    end

    -- 右侧面板：圣器打造后预览
    local nextRows = BuildForgePreviewRows(targetDef)

    local curPanel = UI.Panel {
        flexGrow        = 1, flexShrink = 1, flexBasis = 0,
        maxWidth        = T.size.tooltipWidth,
        backgroundColor = T.color.equipTipComparePanelBg,
        borderRadius    = T.radius.lg,
        borderWidth     = 1,
        borderColor     = hasSource and { 100, 200, 220, 200 } or T.color.border,
        padding         = T.spacing.sm,
        gap             = T.spacing.sm,
        overflow        = "hidden",
        children        = curRows,
    }

    local targetQColor    = GameConfig.QUALITY[targetDef.quality]
    local nextBorderColor = targetQColor and targetQColor.color or T.color.qualityRed

    local nextPanel = UI.Panel {
        flexGrow        = 1, flexShrink = 1, flexBasis = 0,
        maxWidth        = T.size.tooltipWidth,
        backgroundColor = T.color.surfaceDeep,
        borderRadius    = T.radius.lg,
        borderWidth     = 1,
        borderColor     = { nextBorderColor[1], nextBorderColor[2], nextBorderColor[3], 180 },
        padding         = T.spacing.sm,
        gap             = T.spacing.sm,
        overflow        = "hidden",
        children        = nextRows,
    }

    -- 左右对比行（紧贴并排，对齐 EquipTooltip）
    table.insert(children, UI.Panel {
        flexDirection = "row",
        gap           = T.spacing.xs,
        alignItems    = "flex-start",
        width         = "100%",
        children      = { curPanel, nextPanel },
    })

    -- 打造条件区
    local cost       = EquipmentData.DRAGON_FORGE_COST
    local canAfford  = player.gold >= cost.gold
    local materialsOk = true
    local materialRows = {}

    -- 装备状态警告
    if not hasSource then
        table.insert(materialRows, UI.Label {
            text      = "⚠ 需装备「" .. sourceDef.name .. "」",
            fontSize  = T.fontSize.xs,
            fontColor = T.color.warning,
        })
    end

    -- 金币
    table.insert(materialRows, UI.Label {
        text      = "💰 消耗：" .. FormatGold(cost.gold) .. " 金币（当前：" .. FormatGold(player.gold) .. "）",
        fontSize  = T.fontSize.xs,
        fontColor = canAfford and T.color.matEnough or T.color.matInsufficient,
    })
    if not canAfford then materialsOk = false end

    -- 材料列表
    for _, mat in ipairs(cost.materials) do
        local matDef  = GameConfig.PET_MATERIALS[mat.id]
        local matName = matDef and matDef.name or mat.id
        local matIcon = matDef and matDef.icon or "❓"
        local have    = InventorySystem.CountUnlockedConsumable(mat.id)
        local enough  = have >= mat.count
        if not enough then materialsOk = false end

        table.insert(materialRows, UI.Panel {
            flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
            children = {
                UI.Label { text = matIcon, fontSize = T.fontSize.sm },
                UI.Label {
                    text      = matName .. "  " .. have .. "/" .. mat.count,
                    fontSize  = T.fontSize.xs,
                    fontColor = enough and T.color.matEnough or T.color.matInsufficient,
                },
            },
        })
    end

    local canForge = hasSource and canAfford and materialsOk

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
        text            = btnText,
        width           = "100%",
        height          = T.size.dialogBtnH,
        fontSize        = T.fontSize.sm,
        backgroundColor = canForge and T.color.btnDanger   or T.color.btnDisabled,
        fontColor       = canForge and T.color.btnDangerFg or T.color.btnDisabledFg,
        onClick = function(self)
            if canForge then DragonForgeUI.DoForge() end
        end,
    })

    table.insert(children, UI.Panel {
        width      = "100%",
        gap        = T.spacing.sm,
        padding    = T.spacing.sm,
        alignItems = "center",
        children   = materialRows,
    })

    return children
end

-- ============================================================================
-- 刷新逻辑（销毁旧内容，重建页签栏 + 主体内容）
-- ============================================================================

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

    local newChildren = BuildContent()
    contentPanel_ = UI.Panel {
        width      = "100%",
        gap        = T.spacing.sm,
        alignItems = "center",
        children   = newChildren,
    }
    outerPanel_:AddChild(contentPanel_)
end

-- 公开 forward ref（供内部回调使用）
function RefreshUI()
    RefreshUI_internal()
end

-- ============================================================================
-- 面板初始化（Create）
-- ============================================================================

function DragonForgeUI.Create(parentOverlay)
    resultLabel_ = UI.Label {
        text      = "",
        fontSize  = T.fontSize.sm,
        fontColor = T.color.success,
        textAlign = "center",
    }

    outerPanel_ = UI.Panel {
        width = "100%",
        gap   = T.spacing.sm,
    }

    panel_ = UI.Panel {
        id              = "dragonForgePanel",
        position        = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent  = "center",
        alignItems      = "center",
        visible         = false,
        zIndex          = 100,
        onClick         = function(self) DragonForgeUI.Hide() end,
        children = {
            -- S2.4 固定高度卡片（76%），宽度最大 tooltipWidth*2+80
            UI.Panel {
                width           = "94%",
                maxWidth        = T.size.tooltipWidth * 2 + 80,
                height          = "76%",
                backgroundColor = T.color.panelBg,
                borderRadius    = T.radius.lg,
                borderWidth     = 1,
                borderColor     = T.color.forgeBorderRed,
                flexDirection   = "column",
                onClick         = function(self) end,  -- 防穿透
                children = {
                    -- ── Header ────────────────────────────────────────────
                    UI.Panel {
                        width             = "100%",
                        flexDirection     = "row",
                        alignItems        = "center",
                        gap               = T.spacing.md,
                        paddingLeft       = T.spacing.md,
                        paddingRight      = T.spacing.md,
                        paddingTop        = T.spacing.sm,
                        paddingBottom     = T.spacing.sm,
                        borderBottomWidth = 1,
                        borderColor       = T.color.goldDark,
                        children = {
                            -- NPC 头像
                            UI.Panel {
                                width           = PORTRAIT_SIZE,
                                height          = PORTRAIT_SIZE,
                                borderRadius    = T.radius.md,
                                backgroundColor = T.color.headerBg,
                                backgroundImage = "Textures/npc_shenzhenzi.png",
                                backgroundFit   = "cover",
                                borderWidth     = 1,
                                borderColor     = T.color.forgeBorderRed,
                                overflow        = "hidden",
                            },
                            -- 标题区
                            UI.Panel { flexGrow = 1, flexShrink = 1, gap = T.spacing.xxs, children = {
                                UI.Label {
                                    text       = "龙神圣器打造",
                                    fontSize   = T.fontSize.lg,
                                    fontWeight = "bold",
                                    fontColor  = T.color.gold,
                                },
                                UI.Label {
                                    text      = "第四章·圣器锻造",
                                    fontSize  = T.fontSize.xs,
                                    fontColor = T.color.textMuted,
                                },
                            }},
                            -- 关闭按钮（右侧）
                            UI.Button {
                                text            = "✕",
                                width           = T.size.closeButton,
                                height          = T.size.closeButton,
                                fontSize        = T.fontSize.md,
                                borderRadius    = T.size.closeButton / 2,
                                backgroundColor = {255, 100, 100, 30},
                                onClick         = function() DragonForgeUI.Hide() end,
                            },
                        },
                    },
                    -- ── ScrollView（页签 + 主体内容）─────────────────────
                    UI.ScrollView {
                        flexGrow   = 1, flexShrink = 1, flexBasis = 0,
                        width      = "100%",
                        padding    = T.spacing.md,
                        gap        = T.spacing.sm,
                        children   = { outerPanel_ },
                    },
                    -- ── Footer ────────────────────────────────────────────
                    UI.Panel {
                        width          = "100%",
                        alignItems     = "center",
                        gap            = T.spacing.xs,
                        paddingTop     = T.spacing.sm,
                        paddingBottom  = T.spacing.sm,
                        borderTopWidth = 1,
                        borderColor    = T.color.border,
                        children = {
                            resultLabel_,
                            UI.Label {
                                text      = "点击空白处关闭",
                                fontSize  = T.fontSize.xs,
                                fontColor = T.color.textMuted,
                            },
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
    parentOverlay_ = parentOverlay
end

-- ============================================================================
-- 打造成功弹窗（Tab 1~5：圣器替换武器）
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

    local qColor    = T.color.qualityRed
    local goldColor = T.color.statValueGold

    -- 武器图标
    local iconChild
    if IconUtils.IsImagePath(targetDef.icon) then
        iconChild = UI.Panel { width = 60, height = 60, backgroundImage = targetDef.icon, backgroundFit = "contain" }
    else
        iconChild = UI.Label { text = targetDef.icon or "⚔️", fontSize = 40, textAlign = "center" }
    end
    local iconWidget = UI.Panel {
        width           = 80, height = 80,
        justifyContent  = "center", alignItems = "center",
        backgroundColor = T.decor.qualitySlotBg.red,
        borderRadius    = T.radius.lg,
        borderWidth     = 2,
        borderColor     = { qColor[1], qColor[2], qColor[3], 180 },
        children        = { iconChild },
    }

    -- 主属性
    local mainChildren = {}
    for stat, value in pairs(weapon.mainStat or {}) do
        table.insert(mainChildren, SuccessStatRow(
            STAT_ICONS[stat] or "📊", STAT_NAMES[stat] or stat,
            FormatStatVal(stat, value),
            T.color.equipTipMainStatName, goldColor
        ))
    end

    -- 副属性
    local subChildren = {}
    for _, sub in ipairs(weapon.subStats or {}) do
        table.insert(subChildren, SuccessStatRow(
            STAT_ICONS[sub.stat] or "📊", sub.name or STAT_NAMES[sub.stat] or sub.stat,
            FormatStatVal(sub.stat, sub.value),
            T.color.equipTipSubStatName, T.color.statValueGreen
        ))
    end

    -- 灵性属性
    local spiritWidget = nil
    if weapon.spiritStat then
        local ss = weapon.spiritStat
        spiritWidget = UI.Panel {
            width           = "100%",
            backgroundColor = T.color.equipTipSpiritBg,
            borderRadius    = T.radius.sm,
            borderWidth     = 1, borderColor = T.color.equipTipSpiritBorder,
            padding         = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 灵性属性", fontSize = T.fontSize.xs, fontColor = T.color.equipTipSpiritLabel, paddingLeft = T.spacing.xs },
                SuccessStatRow(
                    STAT_ICONS[ss.stat] or "✨", ss.name or STAT_NAMES[ss.stat] or ss.stat,
                    FormatStatVal(ss.stat, ss.value),
                    T.color.equipTipSpiritName, T.color.statValueCyan
                ),
            },
        }
    end

    -- 特殊效果
    local effectWidget = nil
    if weapon.specialEffect then
        local eff = weapon.specialEffect
        effectWidget = UI.Panel {
            width           = "100%",
            backgroundColor = T.color.equipTipSpecialBg,
            borderRadius    = T.radius.sm,
            borderWidth     = 1, borderColor = T.color.equipTipSpecialBorder,
            padding         = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "✨ " .. (eff.name or "特殊效果"), fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.equipTipSpecialName },
                UI.Label { text = GetSpecialEffectDesc(eff),            fontSize = T.fontSize.xs,                    fontColor = T.color.equipTipSpecialDesc },
            },
        }
    end

    -- 组装属性内容区
    local contentChildren = {
        UI.Panel {
            width           = "100%",
            backgroundColor = T.decor.qualitySlotBg.red,
            borderRadius    = T.radius.sm,
            borderWidth     = 1, borderColor = { qColor[1], qColor[2], qColor[3], 100 },
            padding         = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 主属性", fontSize = T.fontSize.xs, fontColor = T.color.equipTipStatLabel, paddingLeft = T.spacing.xs },
                table.unpack(mainChildren),
            },
        },
        UI.Panel {
            width           = "100%",
            backgroundColor = T.color.equipTipSubStatBg,
            borderRadius    = T.radius.sm,
            padding         = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 副属性（随机锻造）", fontSize = T.fontSize.xs, fontColor = T.color.equipTipStatLabel, paddingLeft = T.spacing.xs },
                table.unpack(subChildren),
            },
        },
    }
    if spiritWidget  then table.insert(contentChildren, spiritWidget) end
    if effectWidget  then table.insert(contentChildren, effectWidget) end

    successPanel_ = UI.Panel {
        id              = "forgeSuccessPanel",
        position        = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent  = "center",
        alignItems      = "center",
        backgroundColor = { 0, 0, 0, 180 },
        zIndex          = 250,
        onClick         = function(self) end,
        children = {
            UI.Panel {
                width           = "88%",
                maxWidth        = 400,
                flexDirection   = "column",
                alignItems      = "center",
                gap             = T.spacing.md,
                backgroundColor = T.color.panelBg,
                borderRadius    = T.radius.lg,
                borderWidth     = 2,
                borderColor     = { qColor[1], qColor[2], qColor[3], 180 },
                paddingTop      = T.spacing.xl,
                paddingBottom   = T.spacing.xl,
                paddingLeft     = T.spacing.lg,
                paddingRight    = T.spacing.lg,
                maxHeight       = "85%",
                overflow        = "scroll",
                onClick         = function(self) end,
                children = {
                    UI.Label { text = "⚔️ 龙极铸成！",     fontSize = T.fontSize.xl + 2, fontWeight = "bold", fontColor = goldColor, textAlign = "center" },
                    UI.Label { text = "灵器蜕变，龙威降世", fontSize = T.fontSize.sm,                          fontColor = { T.color.gold[1], T.color.gold[2], T.color.gold[3], 160 }, textAlign = "center" },
                    UI.Panel { width = "80%", height = T.decor.dividerHeight, backgroundColor = T.color.forgeBorderRed },
                    iconWidget,
                    UI.Label { text = targetDef.name, fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = qColor, textAlign = "center" },
                    UI.Label { text = "9阶 [圣器] 武器",   fontSize = T.fontSize.sm,                          fontColor = { qColor[1], qColor[2], qColor[3], 180 }, textAlign = "center" },
                    UI.Panel { width = "80%", height = T.decor.dividerHeight, backgroundColor = { qColor[1], qColor[2], qColor[3], 40 } },
                    UI.Panel { width = "100%", gap = T.spacing.sm, children = contentChildren },
                    UI.Panel { width = "80%", height = T.decor.dividerHeight, backgroundColor = { qColor[1], qColor[2], qColor[3], 40 } },
                    UI.Button {
                        text            = "确认",
                        width           = 180, height = T.size.dialogBtnH,
                        fontSize        = T.fontSize.md, fontWeight = "bold",
                        fontColor       = T.color.btnDangerFg,
                        borderRadius    = T.radius.md,
                        backgroundColor = T.color.btnDanger,
                        onClick         = function(self) HideForgeSuccess() end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(successPanel_)
    GameState.uiOpen = "forge_success"
end

-- ============================================================================
-- 执行打造（Tab 1~5，委托 ForgeSystem）
-- ============================================================================

function DragonForgeUI.DoForge()
    local order    = EquipmentData.FORGE_RECIPE_ORDER.dragon_forge
    local recipeId = order and order[currentTab_]
    if not recipeId then return end

    local result = ForgeSystem.Execute(recipeId)
    if not result.success then
        resultLabel_:SetText(result.error or "打造失败")
        resultLabel_:SetStyle({ fontColor = T.color.error })
        return
    end

    RefreshUI()

    local recipe    = EquipmentData.FORGE_RECIPES[recipeId]
    local targetDef = EquipmentData.SpecialEquipment[recipe.generator.targetId]
    ShowForgeSuccess(result.weapon, targetDef)
end

-- ============================================================================
-- 背包打造通用成功弹窗（Tab 6/7 共用，法宝/灵器）
-- ============================================================================

local function ShowBagForgeSuccess(item, title, subtitle)
    if successPanel_ then HideForgeSuccess() end
    if not parentOverlay_ then return end

    local qualityConfig = GameConfig.QUALITY[item.quality]
    local qColor        = qualityConfig and qualityConfig.color or T.color.statValueCyan
    local goldColor     = T.color.statValueGold

    -- 主属性
    local mainChildren = {}
    for stat, value in pairs(item.mainStat or {}) do
        table.insert(mainChildren, SuccessStatRow(
            STAT_ICONS[stat] or "📊", STAT_NAMES[stat] or stat,
            FormatStatVal(stat, value),
            T.color.equipTipMainStatName, goldColor
        ))
    end

    -- 副属性
    local subChildren = {}
    for _, sub in ipairs(item.subStats or {}) do
        table.insert(subChildren, SuccessStatRow(
            STAT_ICONS[sub.stat] or "📊", sub.name or STAT_NAMES[sub.stat] or sub.stat,
            FormatStatVal(sub.stat, sub.value),
            T.color.equipTipSubStatName, T.color.statValueGreen
        ))
    end

    -- 灵性属性
    local spiritWidget = nil
    if item.spiritStat then
        local ss = item.spiritStat
        spiritWidget = UI.Panel {
            width           = "100%",
            backgroundColor = T.color.equipTipSpiritBg,
            borderRadius    = T.radius.sm,
            borderWidth     = 1, borderColor = T.color.equipTipSpiritBorder,
            padding         = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 灵性属性", fontSize = T.fontSize.xs, fontColor = T.color.equipTipSpiritLabel, paddingLeft = T.spacing.xs },
                SuccessStatRow(
                    STAT_ICONS[ss.stat] or "✨", ss.name or STAT_NAMES[ss.stat] or ss.stat,
                    FormatStatVal(ss.stat, ss.value),
                    T.color.equipTipSpiritName, T.color.statValueCyan
                ),
            },
        }
    end

    -- 圣性属性
    local saintWidget = nil
    if item.saintStat then
        local ss = item.saintStat
        saintWidget = UI.Panel {
            width           = "100%",
            backgroundColor = T.color.equipTipSaintBg,
            borderRadius    = T.radius.sm,
            borderWidth     = 1, borderColor = T.color.equipTipSaintBorder,
            padding         = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 圣性属性", fontSize = T.fontSize.xs, fontColor = T.color.equipTipSaintLabel, paddingLeft = T.spacing.xs },
                SuccessStatRow(
                    STAT_ICONS[ss.stat] or "🔴", ss.name or STAT_NAMES[ss.stat] or ss.stat,
                    FormatStatVal(ss.stat, ss.value),
                    T.color.equipTipSaintName, T.color.statValueRed
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
            width           = "100%",
            backgroundColor = T.color.equipTipSetBg,
            borderRadius    = T.radius.sm,
            borderWidth     = 1, borderColor = { 200, 100, 200, 120 },
            padding         = T.spacing.sm,
            children = {
                UI.Label { text = "🔮 套装：" .. setName, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.equipTipSetName },
            },
        }
    end

    -- 组装属性内容区
    local contentChildren = {
        UI.Panel {
            width           = "100%",
            backgroundColor = { math.floor(qColor[1] * 0.15), math.floor(qColor[2] * 0.15), math.floor(qColor[3] * 0.15), 220 },
            borderRadius    = T.radius.sm,
            borderWidth     = 1, borderColor = { qColor[1], qColor[2], qColor[3], 100 },
            padding         = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 主属性", fontSize = T.fontSize.xs, fontColor = T.color.equipTipStatLabel, paddingLeft = T.spacing.xs },
                table.unpack(mainChildren),
            },
        },
        UI.Panel {
            width           = "100%",
            backgroundColor = T.color.equipTipSubStatBg,
            borderRadius    = T.radius.sm,
            padding         = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "▸ 副属性", fontSize = T.fontSize.xs, fontColor = T.color.equipTipStatLabel, paddingLeft = T.spacing.xs },
                table.unpack(subChildren),
            },
        },
    }
    if spiritWidget then table.insert(contentChildren, spiritWidget) end
    if saintWidget  then table.insert(contentChildren, saintWidget) end
    if setWidget    then table.insert(contentChildren, setWidget) end

    -- 技能标记（法宝专用）
    if item.skillId then
        local SkillData  = require("config.SkillData")
        local skillDef   = SkillData.Skills[item.skillId]
        if skillDef then
            table.insert(contentChildren, UI.Panel {
                width           = "100%",
                backgroundColor = T.color.equipTipSkillBg,
                borderRadius    = T.radius.sm,
                borderWidth     = 1, borderColor = T.color.equipTipSkillBorder,
                padding         = T.spacing.sm, gap = T.spacing.xs,
                children = {
                    UI.Label { text = (skillDef.icon or "✨") .. " " .. skillDef.name, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.equipTipSkillName },
                    UI.Label { text = skillDef.description or "",                       fontSize = T.fontSize.xs,                    fontColor = T.color.equipTipSkillDesc },
                },
            })
        end
    end

    -- 槽位 + 品质信息
    local slotName    = EquipmentData.SLOT_NAMES[item.slot] or item.slot
    local qualityName = qualityConfig and qualityConfig.name or item.quality

    successPanel_ = UI.Panel {
        id              = "forgeSuccessPanel",
        position        = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent  = "center",
        alignItems      = "center",
        backgroundColor = { 0, 0, 0, 180 },
        zIndex          = 250,
        onClick         = function(self) end,
        children = {
            UI.Panel {
                width           = "88%",
                maxWidth        = 400,
                flexDirection   = "column",
                alignItems      = "center",
                gap             = T.spacing.md,
                backgroundColor = T.color.panelBg,
                borderRadius    = T.radius.lg,
                borderWidth     = 2,
                borderColor     = { qColor[1], qColor[2], qColor[3], 180 },
                paddingTop      = T.spacing.xl,
                paddingBottom   = T.spacing.xl,
                paddingLeft     = T.spacing.lg,
                paddingRight    = T.spacing.lg,
                maxHeight       = "85%",
                overflow        = "scroll",
                onClick         = function(self) end,
                children = {
                    UI.Label { text = title,    fontSize = T.fontSize.xl + 2, fontWeight = "bold", fontColor = goldColor, textAlign = "center" },
                    UI.Label { text = subtitle, fontSize = T.fontSize.sm,                          fontColor = { qColor[1], qColor[2], qColor[3], 160 }, textAlign = "center" },
                    UI.Panel { width = "80%", height = T.decor.dividerHeight, backgroundColor = { qColor[1], qColor[2], qColor[3], 60 } },
                    UI.Label { text = item.name,                                       fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = { qColor[1], qColor[2], qColor[3], 255 }, textAlign = "center" },
                    UI.Label { text = EquipmentData.GetTierDisplayName(item.tier) .. " [" .. qualityName .. "] " .. slotName, fontSize = T.fontSize.sm, fontColor = { qColor[1], qColor[2], qColor[3], 180 }, textAlign = "center" },
                    UI.Panel { width = "80%", height = T.decor.dividerHeight, backgroundColor = { qColor[1], qColor[2], qColor[3], 40 } },
                    UI.Panel { width = "100%", gap = T.spacing.sm, children = contentChildren },
                    UI.Panel { width = "80%", height = T.decor.dividerHeight, backgroundColor = { qColor[1], qColor[2], qColor[3], 40 } },
                    UI.Button {
                        text            = "确认",
                        width           = 180, height = T.size.dialogBtnH,
                        fontSize        = T.fontSize.md, fontWeight = "bold",
                        fontColor       = { 255, 255, 255, 255 },
                        borderRadius    = T.radius.md,
                        backgroundColor = { qColor[1], qColor[2], qColor[3], 220 },
                        onClick         = function(self) HideForgeSuccess() end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(successPanel_)
    GameState.uiOpen = "forge_success"
end

-- ============================================================================
-- 龙极令打造（Tab 6，背包模式，委托 ForgeSystem）
-- ============================================================================

function DragonForgeUI.DoForgeLongji()
    local result = ForgeSystem.Execute("dragon_longji")
    if not result.success then
        resultLabel_:SetText(result.error or "打造失败")
        resultLabel_:SetStyle({ fontColor = T.color.error })
        return
    end

    local refreshOk, refreshErr = pcall(RefreshUI)
    if not refreshOk then
        print("[DragonForgeUI] WARNING: RefreshUI error after longji forge: " .. tostring(refreshErr))
    end

    local popupOk, popupErr = pcall(ShowBagForgeSuccess, result.item, "🐲 龙极令铸成！", "四龙之威凝为一令")
    if not popupOk then
        print("[DragonForgeUI] ERROR: ShowBagForgeSuccess failed: " .. tostring(popupErr))
        resultLabel_:SetText("打造成功！（龙极令已放入背包）")
        resultLabel_:SetStyle({ fontColor = T.color.success })
    end
end

-- ============================================================================
-- 灵器铸造（Tab 7，背包模式，委托 ForgeSystem）
-- ============================================================================

function DragonForgeUI.DoForgeLingqi()
    local result = ForgeSystem.Execute("dragon_lingqi")
    if not result.success then
        resultLabel_:SetText(result.error or "铸造失败")
        resultLabel_:SetStyle({ fontColor = T.color.error })
        return
    end

    local refreshOk, refreshErr = pcall(RefreshUI)
    if not refreshOk then
        print("[DragonForgeUI] WARNING: RefreshUI error after lingqi forge: " .. tostring(refreshErr))
    end

    local item   = result.item
    local isSet  = item and item.setId ~= nil
    local title  = isSet and "🔮 套装灵器铸成！" or "⚒️ 灵器铸成！"
    local subtitle = isSet and "龙鳞淬炼，套装显现" or "龙鳞淬炼，灵器出世"
    local popupOk, popupErr = pcall(ShowBagForgeSuccess, item, title, subtitle)
    if not popupOk then
        print("[DragonForgeUI] ERROR: ShowBagForgeSuccess failed: " .. tostring(popupErr))
        resultLabel_:SetText("铸造成功！（灵器已放入背包）")
        resultLabel_:SetStyle({ fontColor = T.color.success })
    end
end

-- ============================================================================
-- 生命周期：Show / Hide / IsVisible / Destroy
-- ============================================================================

function DragonForgeUI.Show(npc)
    if panel_ and not visible_ then
        visible_  = true
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
    panel_          = nil
    contentPanel_   = nil
    outerPanel_     = nil
    tabBarPanel_    = nil
    parentOverlay_  = nil
    successPanel_   = nil
    visible_        = false
end

return DragonForgeUI
