-- ============================================================================
-- EquipmentData.lua - 装备数据表
-- ============================================================================

local EquipmentData = {}

-- 装备槽位类型（全部12个槽位，按UI布局排列）
-- 布局 4x3:
--   项链(暴击)    头盔(生命)    肩膀(防御)
--   武器(攻击)    衣服(防御)    披风(减伤)*稀有
--   戒指(攻击)    腰带(生命)    戒指(攻击)
--   专属(技能伤)* 鞋子(移速)    法宝(生命恢复)*稀有
EquipmentData.SLOTS = {
    "necklace",   -- 项链
    "helmet",     -- 头盔
    "shoulder",   -- 肩膀
    "weapon",     -- 武器
    "armor",      -- 衣服
    "cape",       -- 披风（稀有，仅BOSS掉落）
    "ring1",      -- 戒指1
    "belt",       -- 腰带
    "ring2",      -- 戒指2
    "exclusive",  -- 专属（稀有，未来版本解锁）
    "boots",      -- 鞋子
    "treasure",   -- 法宝（稀有，仅BOSS掉落）
}

-- 标准装备槽（小怪可掉落的制式装备）
EquipmentData.STANDARD_SLOTS = {
    "weapon", "helmet", "armor", "shoulder", "belt", "boots", "ring1", "ring2", "necklace"
}

-- 稀有装备槽（非常规掉落：披风、法宝、专属）
EquipmentData.SPECIAL_SLOTS = { "cape", "treasure", "exclusive" }

-- 装备槽显示名
EquipmentData.SLOT_NAMES = {
    weapon = "武器", helmet = "头盔", armor = "衣服", shoulder = "肩膀",
    belt = "腰带", boots = "鞋子", ring1 = "戒指", ring2 = "戒指",
    necklace = "项链", cape = "披风", treasure = "葫芦", exclusive = "法宝",
}

-- 仙装常规命名规范：T11~T19 有常规随机装备名，T20 只用于终局特殊装备。
EquipmentData.XIAN_TIER_NAMING = {
    [11] = { xian = "仙1",  stage = "谪仙",           series = "谪仙", weapon = "谪仙剑" },
    [12] = { xian = "仙2",  stage = "人仙",           series = "真武", weapon = "人仙剑" },
    [13] = { xian = "仙3",  stage = "地仙",           series = "地阙", weapon = "地阙剑" },
    [14] = { xian = "仙4",  stage = "天仙",           series = "天衡", weapon = "天衡剑" },
    [15] = { xian = "仙5",  stage = "玄仙",           series = "玄霄", weapon = "玄霄剑" },
    [16] = { xian = "仙6",  stage = "金仙",           series = "金阙", weapon = "金阙剑" },
    [17] = { xian = "仙7",  stage = "太乙金仙",       series = "太乙", weapon = "太乙剑" },
    [18] = { xian = "仙8",  stage = "大罗金仙",       series = "大罗", weapon = "大罗剑" },
    [19] = { xian = "仙9",  stage = "混元大罗金仙",   series = "混元", weapon = "混元剑" },
    [20] = { xian = "仙10", stage = "终局仙阶",       series = nil,    specialOnly = true },
}

function EquipmentData.GetTierDisplayName(tier)
    if tier == nil then
        return ""
    end

    local tierNum = tonumber(tier)
    if tierNum then
        local tierIndex = math.floor(tierNum)
        if tierIndex == tierNum then
            local naming = EquipmentData.XIAN_TIER_NAMING[tierIndex]
            if naming and naming.xian then
                return naming.xian .. "阶"
            end
            return tostring(tierIndex) .. "阶"
        end
    end

    return tostring(tier) .. "阶"
end

local function BuildXianTierSlotNames(series, weaponName)
    return {
        weapon = weaponName or (series .. "剑"),
        helmet = series .. "盔",
        armor = series .. "甲",
        shoulder = series .. "肩",
        belt = series .. "带",
        boots = series .. "履",
        ring1 = series .. "戒",
        ring2 = series .. "戒",
        necklace = series .. "链",
        cape = series .. "披风",
        treasure = series .. "珠",
        exclusive = "无",
    }
end

-- 每个槽位的主属性类型（按图片定义）
EquipmentData.MAIN_STAT = {
    necklace  = "critRate",    -- 项链 → 暴击
    helmet    = "maxHp",       -- 头盔 → 生命
    shoulder  = "def",         -- 肩膀 → 防御
    weapon    = "atk",         -- 武器 → 攻击
    armor     = "def",         -- 衣服 → 防御
    cape      = "dmgReduce",   -- 披风 → 减伤（稀有）
    ring1     = "atk",         -- 戒指 → 攻击
    belt      = "maxHp",       -- 腰带 → 生命
    ring2     = "atk",         -- 戒指 → 攻击
    exclusive = "wisdom",      -- 专属 → 悟性（仙元属性）
    boots     = "speed",       -- 鞋子 → 移动速度
    treasure  = "hpRegen",     -- 法宝 → 生命恢复（稀有）
}

-- 主属性基础值（T1 白装基准）
EquipmentData.BASE_MAIN_STAT = {
    necklace  = { critRate = 0.03 },
    helmet    = { maxHp = 20 },
    shoulder  = { def = 3 },
    weapon    = { atk = 5 },
    armor     = { def = 4 },
    cape      = { dmgReduce = 0.02 },
    ring1     = { atk = 3 },
    belt      = { maxHp = 15 },
    ring2     = { atk = 3 },
    exclusive = { wisdom = 5 },  -- 基础悟性值（整数属性，使用 TIER_MULTIPLIER）
    boots     = { speed = 0.03 },
    treasure  = { hpRegen = 1.0 },
}

-- 阶级×槽位的中式名称
EquipmentData.TIER_SLOT_NAMES = {
    [1] = {
        weapon = "铁剑", helmet = "布帽", armor = "布衣", shoulder = "布肩",
        belt = "粗布带", boots = "布靴", ring1 = "铜戒", ring2 = "铜戒",
        necklace = "铜链", cape = "粗布披风", treasure = "酒葫芦", exclusive = "无",
    },
    [2] = {
        weapon = "玄铁剑", helmet = "皮盔", armor = "皮甲", shoulder = "皮肩",
        belt = "兽皮带", boots = "皮靴", ring1 = "银戒", ring2 = "银戒",
        necklace = "银链", cape = "锦缎披风", treasure = "灵符", exclusive = "无",
    },
    [3] = {
        weapon = "精钢剑", helmet = "锻铁盔", armor = "链甲", shoulder = "锻铁肩",
        belt = "锻铁带", boots = "锻铁靴", ring1 = "金戒", ring2 = "金戒",
        necklace = "金链", cape = "锦绣披风", treasure = "玉符", exclusive = "无",
    },
    [4] = {
        weapon = "灵纹剑", helmet = "玄铁盔", armor = "锁子甲", shoulder = "玄铁肩",
        belt = "灵纹带", boots = "玄铁靴", ring1 = "玉戒", ring2 = "玉戒",
        necklace = "玉佩", cape = "灵纹披风", treasure = "灵玉", exclusive = "无",
    },
    -- T5 筑基（Lv.25+）
    [5] = {
        weapon = "青锋剑", helmet = "寒铁盔", armor = "玄甲", shoulder = "寒铁肩",
        belt = "寒玉带", boots = "寒铁靴", ring1 = "灵石戒", ring2 = "灵石戒",
        necklace = "灵石坠", cape = "青云披风", treasure = "灵晶", exclusive = "无",
    },
    -- T6 金丹（Lv.40+）
    [6] = {
        weapon = "赤霄剑", helmet = "紫金盔", armor = "紫金甲", shoulder = "紫金肩",
        belt = "紫金腰环", boots = "紫金靴", ring1 = "丹晶戒", ring2 = "丹晶戒",
        necklace = "丹晶链", cape = "紫霞披风", treasure = "丹晶", exclusive = "无",
    },
    -- T7 元婴（Lv.55+）
    [7] = {
        weapon = "碧落剑", helmet = "天蚕盔", armor = "天蚕甲", shoulder = "天蚕肩",
        belt = "天蚕丝带", boots = "天蚕靴", ring1 = "元灵戒", ring2 = "元灵戒",
        necklace = "元灵坠", cape = "天蚕披风", treasure = "元灵珠", exclusive = "无",
    },
    -- T8 化神（Lv.70+）
    [8] = {
        weapon = "星陨剑", helmet = "星辰盔", armor = "星辰甲", shoulder = "星辰肩",
        belt = "星辰带", boots = "星辰靴", ring1 = "星辰戒", ring2 = "星辰戒",
        necklace = "星辰链", cape = "星辰披风", treasure = "星辰石", exclusive = "无",
    },
    -- T9 合体（Lv.85+）
    [9] = {
        weapon = "龙渊剑", helmet = "龙鳞盔", armor = "龙鳞甲", shoulder = "龙鳞肩",
        belt = "龙骨带", boots = "龙鳞靴", ring1 = "龙骨戒", ring2 = "龙骨戒",
        necklace = "龙骨坠", cape = "龙鳞披风", treasure = "龙珠", exclusive = "无",
    },
    -- T10 大乘（Lv.100+）
    [10] = {
        weapon = "九霄剑", helmet = "九霄盔", armor = "九霄甲", shoulder = "九霄肩",
        belt = "九霄带", boots = "九霄靴", ring1 = "九霄戒", ring2 = "九霄戒",
        necklace = "九霄链", cape = "九霄披风", treasure = "九霄珠", exclusive = "无",
    },
    -- 仙装常规随机装备。T20 不设常规套，只保留特殊装备口径。
    [11] = BuildXianTierSlotNames("谪仙", "谪仙剑"),
    [12] = BuildXianTierSlotNames("真武", "人仙剑"),
    [13] = BuildXianTierSlotNames("地阙", "地阙剑"),
    [14] = BuildXianTierSlotNames("天衡", "天衡剑"),
    [15] = BuildXianTierSlotNames("玄霄", "玄霄剑"),
    [16] = BuildXianTierSlotNames("金阙", "金阙剑"),
    [17] = BuildXianTierSlotNames("太乙", "太乙剑"),
    [18] = BuildXianTierSlotNames("大罗", "大罗剑"),
    [19] = BuildXianTierSlotNames("混元", "混元剑"),
}

-- 阶级倍率（T1~T20）
-- T1凡人 T2凡人 T3练气 T4练气 T5筑基 T6金丹 T7元婴 T8化神 T9合体 T10大乘 T11~T20仙装
EquipmentData.TIER_MULTIPLIER = {
    [1]  = 1.0,
    [2]  = 2.0,
    [3]  = 3.0,
    [4]  = 4.5,
    [5]  = 6.0,
    [6]  = 8.0,
    [7]  = 10.5,
    [8]  = 13.5,
    [9]  = 17.0,
    [10] = 21.0,
    [11] = 25.0,   -- 仙1（T11=仙1）
    -- 仙装阶（仙2-仙10）
    [12] = 30.0,   -- 仙2
    [13] = 40.0,   -- 仙3
    [14] = 50.0,   -- 仙4
    [15] = 60.0,   -- 仙5
    [16] = 75.0,   -- 仙6
    [17] = 95.0,   -- 仙7
    [18] = 120.0,  -- 仙8
    [19] = 150.0,  -- 仙9
    [20] = 185.0,  -- 仙10（预留）
}

-- 百分比主属性阶级倍率（critRate 等百分比属性用此表，增长平缓，避免溢出）
EquipmentData.PCT_TIER_MULTIPLIER = {
    [1]  = 1.0,
    [2]  = 1.5,
    [3]  = 2.0,
    [4]  = 2.5,
    [5]  = 3.0,
    [6]  = 4.0,
    [7]  = 5.0,
    [8]  = 6.0,
    [9]  = 7.0,
    [10] = 8.0,
    [11] = 9.0,   -- 仙1
    -- 仙装阶（仙2-仙10）
    [12] = 10,   -- 仙2
    [13] = 11,   -- 仙3
    [14] = 12,   -- 仙4
    [15] = 13,   -- 仙5
    [16] = 14,   -- 仙6
    [17] = 15,   -- 仙7
    [18] = 16,   -- 仙8
    [19] = 17,   -- 仙9
    [20] = 18,   -- 仙10（预留）
}

-- 百分比副属性阶级倍率（critRate / critDmg 用此表）
EquipmentData.PCT_SUB_TIER_MULT = {
    [1]  = 1.0,
    [2]  = 1.3,
    [3]  = 1.6,
    [4]  = 2.0,
    [5]  = 2.5,
    [6]  = 3.0,
    [7]  = 3.8,
    [8]  = 4.6,
    [9]  = 5.2,
    [10] = 6.0,
    [11] = 6.6,    -- 仙1
    -- 仙装阶（仙2-仙10）
    [12] = 7.2,    -- 仙2
    [13] = 7.8,    -- 仙3
    [14] = 8.4,    -- 仙4
    [15] = 9.0,    -- 仙5
    [16] = 9.6,    -- 仙6
    [17] = 10.2,   -- 仙7
    [18] = 10.8,   -- 仙8
    [19] = 11.4,   -- 仙9
    [20] = 12.0,   -- 仙10（预留）
}

-- 百分比类副属性集合（用于判断走哪个倍率表）
EquipmentData.PCT_STATS = {
    critRate = true,
    critDmg = true,
}

-- 百分比类主属性集合
EquipmentData.PCT_MAIN_STATS = {
    critRate = true,
    speed = true,
    dmgReduce = true,
}

-- 整数型主属性集合（使用 TIER_MULTIPLIER 而非 PCT_TIER_MULTIPLIER）
-- 与默认数值型主属性相同倍率，但需要标记以区分百分比
EquipmentData.INT_MAIN_STATS = {
    wisdom = true,
}

-- 线性增长副属性集合（value = floor(tier × qualityMult)，无随机）
EquipmentData.LINEAR_GROWTH_STATS = {
    killGold = true,  -- 保留旧标记兼容
    fortune = true,
    wisdom = true,
    constitution = true,
    physique = true,
}

-- 可用副属性池（baseValue 约为对应主属性基础值的 30%）
EquipmentData.SUB_STATS = {
    { stat = "atk",       name = "攻击力",   baseValue = 1.5 },
    { stat = "def",       name = "防御力",   baseValue = 1.2 },
    { stat = "maxHp",     name = "生命值",   baseValue = 6 },
    { stat = "hpRegen",   name = "生命回复", baseValue = 0.5 },
    { stat = "killHeal",  name = "击杀回血", baseValue = 3 },
    { stat = "critRate",  name = "暴击率",   baseValue = 0.01 },
    { stat = "critDmg",   name = "暴击伤害", baseValue = 0.05 },
    { stat = "heavyHit",  name = "重击值",   baseValue = 8 },
    { stat = "fortune",   name = "福缘",     baseValue = 1, linearGrowth = true },
    { stat = "wisdom",    name = "悟性",     baseValue = 1, linearGrowth = true },
    { stat = "constitution", name = "根骨",  baseValue = 1, linearGrowth = true },
    { stat = "physique",     name = "体魄",  baseValue = 1, linearGrowth = true },
}

-- 灵性属性池 = 标准副属性 + 天诛属性（供 GenerateSpiritStat 使用）
EquipmentData.SPIRIT_STATS = {
    { stat = "atk",       name = "攻击力",   baseValue = 1.5 },
    { stat = "def",       name = "防御力",   baseValue = 1.2 },
    { stat = "maxHp",     name = "生命值",   baseValue = 6 },
    { stat = "hpRegen",   name = "生命回复", baseValue = 0.5 },
    { stat = "killHeal",  name = "击杀回血", baseValue = 3 },
    { stat = "critRate",  name = "暴击率",   baseValue = 0.01 },
    { stat = "critDmg",   name = "暴击伤害", baseValue = 0.05 },
    { stat = "heavyHit",  name = "重击值",   baseValue = 8 },
    { stat = "fortune",   name = "福缘",     baseValue = 1, linearGrowth = true },
    { stat = "wisdom",    name = "悟性",     baseValue = 1, linearGrowth = true },
    { stat = "constitution", name = "根骨",  baseValue = 1, linearGrowth = true },
    { stat = "physique",     name = "体魄",  baseValue = 1, linearGrowth = true },
    { stat = "tianzhuChance", name = "天诛概率", baseValue = 0.01, fixed = true },
    { stat = "tianzhuDamage", name = "天诛伤害", baseValue = 0.05, fixed = true },
}

-- 圣性属性池 = 标准副属性 + 天诛属性（供 GenerateSaintStat 使用）
EquipmentData.SAINT_STATS = {
    { stat = "atk",       name = "攻击力",   baseValue = 1.5 },
    { stat = "def",       name = "防御力",   baseValue = 1.2 },
    { stat = "maxHp",     name = "生命值",   baseValue = 6 },
    { stat = "hpRegen",   name = "生命回复", baseValue = 0.5 },
    { stat = "killHeal",  name = "击杀回血", baseValue = 3 },
    { stat = "critRate",  name = "暴击率",   baseValue = 0.01 },
    { stat = "critDmg",   name = "暴击伤害", baseValue = 0.05 },
    { stat = "heavyHit",  name = "重击值",   baseValue = 8 },
    { stat = "fortune",   name = "福缘",     baseValue = 1, linearGrowth = true },
    { stat = "wisdom",    name = "悟性",     baseValue = 1, linearGrowth = true },
    { stat = "constitution", name = "根骨",  baseValue = 1, linearGrowth = true },
    { stat = "physique",     name = "体魄",  baseValue = 1, linearGrowth = true },
    { stat = "tianzhuChance", name = "天诛概率", baseValue = 0.02, fixed = true },
    { stat = "tianzhuDamage", name = "天诛伤害", baseValue = 0.10, fixed = true },
}

-- 副属性强度（按阶级递增）
EquipmentData.SUB_STAT_TIER_MULT = {
    [1]  = 1.0,
    [2]  = 1.5,
    [3]  = 2.2,
    [4]  = 3.0,
    [5]  = 4.0,
    [6]  = 5.5,
    [7]  = 7.0,
    [8]  = 9.0,
    [9]  = 11.0,
    [10] = 13.0,
    [11] = 15.0,   -- 仙1
    -- 仙装阶（仙2-仙10）
    [12] = 18.0,   -- 仙2
    [13] = 24.0,   -- 仙3
    [14] = 30.0,   -- 仙4
    [15] = 36.0,   -- 仙5
    [16] = 45.0,   -- 仙6
    [17] = 57.0,   -- 仙7
    [18] = 72.0,   -- 仙8
    [19] = 90.0,   -- 仙9
    [20] = 111.0,  -- 仙10（预留）
}


-- ===================== 子模块加载 =====================
EquipmentData.SpecialEquipment = require("config.EquipmentData_Special")
EquipmentData.Collection = require("config.EquipmentData_Collection")
require("config.EquipmentData_Forge")(EquipmentData)

return EquipmentData
