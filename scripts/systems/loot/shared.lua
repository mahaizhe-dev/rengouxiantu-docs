-- ============================================================================
-- loot/shared.lua - LootSystem 子模块公共依赖 + 常量
-- ============================================================================

local shared = {}

-- ── 公共依赖 ──
shared.GameConfig     = require("config.GameConfig")
shared.EquipmentData  = require("config.EquipmentData")
shared.MonsterData    = require("config.MonsterData")
shared.GameState      = require("core.GameState")
shared.EventBus       = require("core.EventBus")
shared.Utils          = require("core.Utils")
shared.IconUtils      = require("utils.IconUtils")
shared.EquipmentUtils = require("utils.EquipmentUtils")
shared.ForgeStatRules = require("systems.forge.ForgeStatRules")

-- ── 普通装备基础售价查表 ──
shared.BASE_SELL_PRICE = {10, 20, 35, 55, 80, 110, 140, 180, 220, 270, 320}

-- ── 品质遍历列表 ──
shared.BASE_QUALITY_WEIGHTS = {
    { quality = "white",  weight = 250 },
    { quality = "green",  weight = 150 },
    { quality = "blue",   weight = 75 },
    { quality = "purple", weight = 25 },
    { quality = "orange", weight = 5 },
    { quality = "cyan",   weight = 1 },
    { quality = "red",    weight = 0.2 },
}

-- ── Tier 品质权重表 ──
shared.TIER_QUALITY_WEIGHTS = {
    [1]  = { white = 250, green = 150, blue = 75, purple = 25 },
    [2]  = { white = 250, green = 150, blue = 75, purple = 25 },
    [3]  = { white = 250, green = 150, blue = 75, purple = 25 },
    [4]  = { white = 250, green = 150, blue = 75, purple = 25 },
    [5]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5 },
    [6]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5 },
    [7]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5 },
    [8]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5 },
    [9]  = { white = 250, green = 150, blue = 75, purple = 25, orange = 5, cyan = 1 },
    [10] = { white = 250, green = 150, blue = 75, purple = 25, orange = 5, cyan = 1 },
    [11] = { white = 250, green = 150, blue = 75, purple = 25, orange = 5, cyan = 1, red = 0.2 },
}

-- ── 高品质 per-tier 等级门槛 ──
shared.TIER_QUALITY_GATE = {
    orange = {
        [5] = 31,  [6] = 46,  [7] = 61,  [8] = 76,
        [9] = 91,  [10] = 106, [11] = 126,
    },
    cyan = {
        [9] = 96,  [10] = 111, [11] = 131,
    },
    red = {
        [11] = 136,
    },
}

-- ── 窗口内位置衰减系数 ──
shared.TIER_POSITION_DECAY = { 1.0, 0.5, 0.2 }

-- ── 特殊装备副属性波动区间 ──
shared.SPECIAL_FLUCTUATION = shared.ForgeStatRules.SPECIAL_FLUCTUATION

-- ── 副属性 baseValue 查找表 ──
shared.SUB_BASE_MAP = {}
for _, sub in ipairs(shared.EquipmentData.SUB_STATS) do
    shared.SUB_BASE_MAP[sub.stat] = sub
end

-- ── T1 基础图标映射 ──
shared.SLOT_ICONS_T1 = {
    weapon    = "icon_weapon.png",
    helmet    = "icon_helmet.png",
    armor     = "icon_armor.png",
    shoulder  = "icon_shoulder.png",
    belt      = "icon_belt.png",
    boots     = "icon_boots.png",
    ring1     = "icon_ring.png",
    ring2     = "icon_ring.png",
    necklace  = "icon_necklace.png",
    cape      = "icon_cape.png",
    treasure  = "image/gourd_green.png",
    exclusive = "icon_exclusive.png",
}

-- ── 葫芦品质图标映射 ──
shared.GOURD_QUALITY_ICONS = {
    green  = "image/gourd_green.png",
    blue   = "image/gourd_blue.png",
    purple = "image/gourd_purple.png",
    orange = "image/gourd_orange.png",
    cyan   = "image/gourd_cyan.png",
    red    = "image/gourd_cyan.png",
    gold   = "image/gourd_cyan.png",
    rainbow = "image/gourd_cyan.png",
}

-- ── 仙装图标映射（T11=仙1；T12+待后续逐阶补齐） ──
shared.XIAN_SLOT_ICONS = {
    [11] = {
        weapon   = "image/icon_t11_weapon_zhexian_diagonal_20260630132255.png",
        helmet   = "image/icon_t11_helmet_zhexian_20260630131845.png",
        armor    = "image/icon_t11_armor_zhexian_20260630131845.png",
        shoulder = "image/icon_t11_shoulder_zhexian_20260630131845.png",
        belt     = "image/icon_t11_belt_zhexian_20260630131845.png",
        boots    = "image/icon_t11_boots_zhexian_20260630131939.png",
        ring     = "image/icon_t11_ring_zhexian_20260630131939.png",
        necklace = "image/icon_t11_necklace_zhexian_20260630131939.png",
    },
}

--- 根据怪物等级确定可用 Tier 列表
---@param monsterLevel number
---@return number[]
function shared.GetAvailableTiers(monsterLevel)
    -- 仙装阶段（121+）：T11=仙1, T12=仙2...T20=仙10
    if monsterLevel >= 281 then return { 17, 18, 19 }     -- 混元段：仙7-仙9
    elseif monsterLevel >= 261 then return { 16, 17, 18 } -- 大罗段：仙6-仙8
    elseif monsterLevel >= 241 then return { 15, 16, 17 } -- 太乙段：仙5-仙7
    elseif monsterLevel >= 221 then return { 14, 15, 16 } -- 金仙段：仙4-仙6
    elseif monsterLevel >= 201 then return { 13, 14, 15 } -- 玄仙段：仙3-仙5
    elseif monsterLevel >= 181 then return { 12, 13, 14 } -- 天仙段：仙2-仙4
    elseif monsterLevel >= 161 then return { 11, 12, 13 } -- 地仙段：仙1-仙3
    elseif monsterLevel >= 141 then return { 10, 11, 12 } -- 人仙段：T10-仙2
    elseif monsterLevel >= 121 then return { 9, 10, 11 }  -- 谪仙段：T9-仙1
    elseif monsterLevel >= 101 then return { 8, 9, 10 }
    elseif monsterLevel >= 86  then return { 7, 8, 9 }
    elseif monsterLevel >= 71  then return { 6, 7, 8 }
    elseif monsterLevel >= 56  then return { 5, 6, 7 }
    elseif monsterLevel >= 41  then return { 4, 5, 6 }
    elseif monsterLevel >= 26  then return { 3, 4, 5 }
    elseif monsterLevel >= 16  then return { 2, 3, 4 }
    elseif monsterLevel >= 11  then return { 1, 2, 3 }
    elseif monsterLevel >= 6   then return { 1, 2 }
    else                            return { 1 }
    end
end

return shared
