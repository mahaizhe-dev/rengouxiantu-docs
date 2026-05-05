-- ============================================================================
-- BadgeData.lua - 仙图录·徽章定义数据
-- ============================================================================

local BadgeData = {}

--- 徽章显示顺序
BadgeData.ORDER = {
    "dragon_slayer",
    "trial_master",
    "wine_master",
    "collector",
    "artifact_full",
    "title_collector",
}

--- 徽章定义
---@type table<string, {id: string, name: string, icon: string, desc: string, condition: table, bonus: table, points: number}>
BadgeData.BADGES = {
    -- ── 战斗类 ──
    dragon_slayer = {
        id = "dragon_slayer",
        name = "屠龙勇士",
        icon = "🐉",
        desc = "击败全部 BOSS",
        condition = { type = "boss_kill_all" },
        bonus = { atkPct = 0.05 },  -- 攻击+5%
        points = 200,
    },
    trial_master = {
        id = "trial_master",
        name = "试炼宗师",
        icon = "⚔️",
        desc = "青云试炼达到第12层",
        condition = { type = "trial_floor", value = 12 },
        bonus = { defPct = 0.05 },  -- 防御+5%
        points = 150,
    },

    -- ── 收集类 ──
    wine_master = {
        id = "wine_master",
        name = "酒仙",
        icon = "🍶",
        desc = "收集全部6种美酒",
        condition = { type = "wine_count", value = 6 },
        bonus = { hpPct = 0.05 },  -- 生命+5%
        points = 150,
    },
    collector = {
        id = "collector",
        name = "博物学家",
        icon = "📚",
        desc = "装备图鉴收集50件",
        condition = { type = "collection_count", value = 50 },
        bonus = { atkFlat = 20 },  -- 攻击+20
        points = 100,
    },

    -- ── 成长类 ──
    artifact_full = {
        id = "artifact_full",
        name = "神器圆满",
        icon = "💎",
        desc = "神器九宫格全部激活",
        condition = { type = "artifact_grids", value = 9 },
        bonus = { critRate = 0.03 },  -- 暴击+3%
        points = 200,
    },
    title_collector = {
        id = "title_collector",
        name = "名号满堂",
        icon = "🏅",
        desc = "解锁10个称号",
        condition = { type = "title_count", value = 10 },
        bonus = { defFlat = 15 },  -- 防御+15
        points = 100,
    },
}

--- 徽章奖励属性名称映射（用于 UI 显示）
BadgeData.BONUS_NAMES = {
    atkPct = "攻击",
    defPct = "防御",
    hpPct = "生命",
    atkFlat = "攻击",
    defFlat = "防御",
    critRate = "暴击率",
}

--- 格式化徽章奖励文本
---@param bonus table
---@return string
function BadgeData.FormatBonus(bonus)
    local parts = {}
    for stat, value in pairs(bonus) do
        local name = BadgeData.BONUS_NAMES[stat] or stat
        if stat:find("Pct") or stat == "critRate" then
            parts[#parts + 1] = name .. "+" .. math.floor(value * 100) .. "%"
        else
            parts[#parts + 1] = name .. "+" .. value
        end
    end
    return table.concat(parts, " ")
end

return BadgeData
