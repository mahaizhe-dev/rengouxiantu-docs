-- ============================================================================
-- LiangjieStoneConfig.lua - 第六章两界阵石配置
-- 四根阵石分布在两界村外四角，消耗谪仙令激活并培养至 30 级。
-- ============================================================================

local LiangjieStoneConfig = {}

LiangjieStoneConfig.CURRENCY_ID = "zhexian_ling"
LiangjieStoneConfig.CURRENCY_NAME = "谪仙令"
LiangjieStoneConfig.ACTIVATION_COST = 1000
LiangjieStoneConfig.ACTIVATION_EXP_REWARD = 10000000
LiangjieStoneConfig.MAX_LEVEL = 30

-- 每三个等级一档，共十档。
LiangjieStoneConfig.UPGRADE_COST_TIERS = {
    500, 750, 1000, 1250, 1500,
    1750, 2000, 2250, 2500, 3000,
}

LiangjieStoneConfig.IMAGE = "image/ch6_liangjie_array_stone_20260710105731.png"

LiangjieStoneConfig.STONES = {
    xuanbi = {
        id = "xuanbi",
        name = "玄壁阵石",
        position = "西北",
        x = 32,
        y = 32,
        color = {110, 175, 235, 255},
        bonusStat = "def",
        bonusLabel = "防御",
        bonusPerLevel = 4,
        image = LiangjieStoneConfig.IMAGE,
    },
    tianfeng = {
        id = "tianfeng",
        name = "天锋阵石",
        position = "东北",
        x = 49,
        y = 32,
        color = {245, 130, 95, 255},
        bonusStat = "atk",
        bonusLabel = "攻击",
        bonusPerLevel = 5,
        image = LiangjieStoneConfig.IMAGE,
    },
    houtu = {
        id = "houtu",
        name = "厚土阵石",
        position = "西南",
        x = 32,
        y = 49,
        color = {225, 185, 90, 255},
        bonusStat = "maxHp",
        bonusLabel = "生命上限",
        bonusPerLevel = 50,
        image = LiangjieStoneConfig.IMAGE,
    },
    huiyuan = {
        id = "huiyuan",
        name = "回元阵石",
        position = "东南",
        x = 49,
        y = 49,
        color = {105, 220, 165, 255},
        bonusStat = "hpRegen",
        bonusLabel = "生命回复",
        bonusPerLevel = 5,
        image = LiangjieStoneConfig.IMAGE,
    },
}

LiangjieStoneConfig.STONE_ORDER = { "xuanbi", "tianfeng", "houtu", "huiyuan" }

---@param level number 目标等级 1~30
---@return number|nil
function LiangjieStoneConfig.GetUpgradeCost(level)
    if type(level) ~= "number" or level < 1 or level > LiangjieStoneConfig.MAX_LEVEL then
        return nil
    end
    local tier = math.floor((level - 1) / 3) + 1
    return LiangjieStoneConfig.UPGRADE_COST_TIERS[tier]
end

---@param stoneId string
---@param level number
---@return number
function LiangjieStoneConfig.GetTotalBonus(stoneId, level)
    local cfg = LiangjieStoneConfig.STONES[stoneId]
    if not cfg then return 0 end
    return cfg.bonusPerLevel * math.max(0, math.min(LiangjieStoneConfig.MAX_LEVEL, level or 0))
end

---@return number
function LiangjieStoneConfig.GetMaxUpgradeCost()
    local total = 0
    for level = 1, LiangjieStoneConfig.MAX_LEVEL do
        total = total + (LiangjieStoneConfig.GetUpgradeCost(level) or 0)
    end
    return total
end

return LiangjieStoneConfig
