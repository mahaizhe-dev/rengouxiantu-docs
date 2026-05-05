--- StatNames: 统一属性名称、图标、颜色和格式化
--- 消除 7+ 个 UI 文件中 STAT_NAMES/STAT_ICONS/FormatStatValue 的重复定义
---
--- 使用方式:
---   local StatNames = require("utils.StatNames")
---   local name = StatNames.NAMES.atk           --> "攻击力"
---   local short = StatNames.SHORT_NAMES.atk    --> "攻击"
---   local icon = StatNames.ICONS.atk           --> "⚔️"
---   local str = StatNames.FormatValue("critRate", 0.15)  --> "+15.0%"
---   local str = StatNames.FormatShort("critRate", 0.15)  --> "15.0%"

local StatNames = {}

------------------------------------------------------------------------
-- 属性全称（用于 Tooltip、详情面板）
-- 来源: EquipTooltip, EquipShopUI, DragonForgeUI, ChallengeUI
------------------------------------------------------------------------
StatNames.NAMES = {
    atk         = "攻击力",
    def         = "防御力",
    maxHp       = "生命值",
    speed       = "速度",
    hpRegen     = "生命回复",
    critRate    = "暴击",
    critDmg     = "暴击伤害",
    dmgReduce   = "减伤",
    skillDmg    = "技能伤害",
    killHeal    = "击杀回血",
    heavyHit    = "重击",
    fortune     = "福缘",
    wisdom      = "悟性",
    constitution = "根骨",
    physique    = "体魄",
    killGold    = "击杀金币",
}

------------------------------------------------------------------------
-- 属性简称（用于 HUD、紧凑列表、奖励显示）
-- 来源: QuestRewardUI, ForgeUI, CollectionUI, BreakthroughCelebration
------------------------------------------------------------------------
StatNames.SHORT_NAMES = {
    atk         = "攻击",
    def         = "防御",
    maxHp       = "生命",
    speed       = "移速",
    hpRegen     = "回复",
    critRate    = "暴击",
    critDmg     = "暴伤",
    dmgReduce   = "减伤",
    skillDmg    = "技伤",
    killHeal    = "击杀回血",
    heavyHit    = "重击",
    fortune     = "福缘",
    wisdom      = "悟性",
    constitution = "根骨",
    physique    = "体魄",
    killGold    = "击杀金币",
}

------------------------------------------------------------------------
-- 属性图标 emoji
-- 来源: EquipTooltip, DragonForgeUI, ChallengeUI
------------------------------------------------------------------------
StatNames.ICONS = {
    atk         = "⚔️",
    def         = "🛡️",
    maxHp       = "❤️",
    speed       = "💨",
    hpRegen     = "💚",
    critRate    = "💥",
    critDmg     = "🔥",
    dmgReduce   = "🔰",
    skillDmg    = "✨",
    killHeal    = "💖",
    heavyHit    = "🔨",
    fortune     = "🍀",
    wisdom      = "📖",
    constitution = "💪",
    physique    = "🩸",
    killGold    = "💰",
}

------------------------------------------------------------------------
-- 属性颜色（RGBA）
-- 来源: CollectionUI STAT_COLORS
------------------------------------------------------------------------
StatNames.COLORS = {
    atk         = {255, 150, 100, 255},
    def         = {100, 200, 255, 255},
    maxHp       = {100, 255, 100, 255},
    hpRegen     = {150, 255, 200, 255},
    fortune     = {255, 215, 0, 255},
    killHeal    = {100, 255, 180, 255},
    heavyHit    = {255, 120, 80, 255},
    critRate    = {255, 200, 60, 255},
    wisdom      = {180, 140, 255, 255},
    constitution = {140, 220, 180, 255},
    physique    = {220, 180, 140, 255},
}

------------------------------------------------------------------------
-- 百分比类属性集合
-- 这些属性的原始值是小数（如 0.15 表示 15%），显示时需要 *100
------------------------------------------------------------------------
StatNames.PCT_STATS = {
    speed     = true,
    critRate  = true,
    critDmg   = true,
    dmgReduce = true,
    skillDmg  = true,
}

------------------------------------------------------------------------
-- 格式化属性值（带 + 号前缀，用于装备详情/奖励）
-- 来源: EquipTooltip, QuestRewardUI, ChallengeUI, DragonForgeUI 的 FormatStatValue
--
---@param stat string 属性 key
---@param value number 属性值
---@return string 如 "+15.0%", "+100", "+2.5/s"
------------------------------------------------------------------------
function StatNames.FormatValue(stat, value)
    if stat == "hpRegen" then
        return string.format("+%.1f/s", value)
    elseif StatNames.PCT_STATS[stat] then
        if stat == "critDmg" then
            return string.format("+%.0f%%", value * 100)
        else
            return string.format("+%.1f%%", value * 100)
        end
    else
        return "+" .. tostring(math.floor(value))
    end
end

------------------------------------------------------------------------
-- 格式化属性值（无 + 号前缀，用于对比列表）
-- 来源: EquipTooltip FormatStatShort
--
---@param stat string 属性 key
---@param value number 属性值
---@return string 如 "15.0%", "100", "2.5/s"
------------------------------------------------------------------------
function StatNames.FormatShort(stat, value)
    if stat == "hpRegen" then
        return string.format("%.1f/s", value)
    elseif StatNames.PCT_STATS[stat] then
        if stat == "critDmg" then
            return string.format("%.0f%%", value * 100)
        else
            return string.format("%.1f%%", value * 100)
        end
    else
        return tostring(math.floor(value))
    end
end

------------------------------------------------------------------------
-- 获取属性名称（优先全称，fallback 到 key）
---@param stat string
---@param short boolean|nil 为 true 时返回简称
---@return string
------------------------------------------------------------------------
function StatNames.GetName(stat, short)
    if short then
        return StatNames.SHORT_NAMES[stat] or StatNames.NAMES[stat] or stat
    end
    return StatNames.NAMES[stat] or stat
end

------------------------------------------------------------------------
-- 获取属性图标
---@param stat string
---@return string
------------------------------------------------------------------------
function StatNames.GetIcon(stat)
    return StatNames.ICONS[stat] or "📊"
end

------------------------------------------------------------------------
-- 获取属性颜色
---@param stat string
---@param fallback table|nil 默认颜色 {r,g,b,a}
---@return table {r,g,b,a}
------------------------------------------------------------------------
function StatNames.GetColor(stat, fallback)
    return StatNames.COLORS[stat] or fallback or {200, 200, 220, 255}
end

return StatNames
