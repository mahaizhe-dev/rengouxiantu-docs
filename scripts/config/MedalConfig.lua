-- ============================================================================
-- MedalConfig.lua - 道印配置（数据驱动，不可硬编码）
-- 遵循 rules.md §5.6：所有数值在配置模块中，逻辑层引用配置
-- 对应设计文档：仙图录.md §5
-- ============================================================================

local MedalConfig = {}

-- ============================================================================
-- 大境界映射（凡人=0, 练气=1, ..., 渡劫=8）
-- 用于 realm_master 道印的阈值检测
-- ============================================================================

--- 境界 ID 前缀 → 大境界编号
MedalConfig.MAJOR_REALM_MAP = {
    mortal   = 0,
    lianqi   = 1,
    zhuji    = 2,
    jindan   = 3,
    yuanying = 4,
    huashen  = 5,
    heti     = 6,
    dacheng  = 7,
    dujie    = 8,
}

--- 从 realm ID（如 "jindan_2"）提取大境界编号
---@param realmId string
---@return integer 0~8
function MedalConfig.GetMajorRealmIndex(realmId)
    if not realmId or realmId == "" then return 0 end
    if realmId == "mortal" then return 0 end
    -- 提取前缀: "jindan_2" → "jindan"
    local prefix = realmId:match("^([^_]+)")
    return MedalConfig.MAJOR_REALM_MAP[prefix] or 0
end

-- ============================================================================
-- 职业 ID 映射
-- ============================================================================

MedalConfig.CLASS_IDS = {
    taixu   = "taixu",       -- 太虚（剑修）—— 必须与 GameConfig.CLASS_DATA key 一致
    zhenyue = "zhenyue",     -- 镇岳（体修）
    luohan  = "monk",        -- 罗汉（武僧）
    tianyan  = "tianyan",    -- 天衍（阵法师）
}

-- ============================================================================
-- 属性名称（用于 UI 显示）
-- ============================================================================

MedalConfig.ATTR_NAMES = {
    hp      = "HP",
    atk     = "攻击力",
    def     = "防御力",
    hpRegen = "生命回复",
    gengu   = "根骨",
    wuxing  = "悟性",
    fuyuan  = "福源",
    tipo    = "体魄",
}

-- ============================================================================
-- 道印定义
-- ============================================================================

---@class MedalDef
---@field id string 唯一标识
---@field name string 显示名称
---@field type "levelable"|"one_time" 类型
---@field max_level integer 最高等级（0=无上限, 1=一次性）
---@field trigger table 触发配置
---@field bonus table 每级加成
---@field desc string 简短描述

MedalConfig.MEDALS = {
    -- ════════════════════════════════════════════════════════════
    -- ① 数值检测类 (value_check) — 6 枚
    -- ════════════════════════════════════════════════════════════

    realm_master = {
        id = "realm_master",
        name = "境界大师",
        type = "levelable",
        max_level = 8,
        trigger = {
            type = "value_check",
            source = "major_realm",      -- 大境界编号 (1~8)
            thresholds = {1, 2, 3, 4, 5, 6, 7, 8},
        },
        bonus = { hp = 30 },
        desc = "突破各大境界，道途之路尽收于心",
    },

    taixu = {
        id = "taixu",
        name = "太虚之道",
        type = "levelable",
        max_level = 10,
        trigger = {
            type = "value_check",
            source = "class_level_taixu", -- 太虚角色等级
            thresholds = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100},
        },
        bonus = { wuxing = 1 },
        desc = "太虚角色达到等级里程碑，剑意纵横三千界",
    },

    zhenyue = {
        id = "zhenyue",
        name = "镇岳之力",
        type = "levelable",
        max_level = 10,
        trigger = {
            type = "value_check",
            source = "class_level_zhenyue", -- 镇岳角色等级
            thresholds = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100},
        },
        bonus = { tipo = 1 },
        desc = "镇岳角色达到等级里程碑，铁骨铸就不灭身",
    },

    luohan = {
        id = "luohan",
        name = "罗汉之躯",
        type = "levelable",
        max_level = 10,
        trigger = {
            type = "value_check",
            source = "class_level_luohan", -- 罗汉角色等级
            thresholds = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100},
        },
        bonus = { gengu = 1 },
        desc = "罗汉角色达到等级里程碑，金刚不坏万法空",
    },

    tianyan = {
        id = "tianyan",
        name = "天衍之机",
        type = "levelable",
        max_level = 10,
        trigger = {
            type = "value_check",
            source = "class_level_tianyan", -- 天衍角色等级
            thresholds = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100},
        },
        bonus = { fuyuan = 1 },
        desc = "天衍角色达到等级里程碑，玄机算尽天地间",
    },

    trial = {
        id = "trial",
        name = "青云试炼",
        type = "levelable",
        max_level = 8,
        trigger = {
            type = "value_check",
            source = "trial_floor",         -- 历史最高通关层
            thresholds = {30, 60, 90, 120, 150, 180, 210, 240},
        },
        bonus = { def = 4 },
        desc = "通关青云试炼塔层数里程碑，步步登天不畏难",
    },

    -- ════════════════════════════════════════════════════════════
    -- ② 道具消耗类 (item_consume) — 1 枚
    -- ════════════════════════════════════════════════════════════

    guardian = {
        id = "guardian",
        name = "仙途守护者",
        type = "levelable",
        max_level = 0,                      -- 0 = 无上限
        trigger = {
            type = "item_consume",
            item_id = "item_guardian_token", -- 守护者证明
            exp_per_level = 100,
        },
        bonus = { gengu = 1, wuxing = 1, fuyuan = 1, tipo = 1 },
        desc = "感谢积极参与测试和反馈的先行者们",
    },

    -- ════════════════════════════════════════════════════════════
    -- ③ 全服竞速类 (server_race) — 2 枚
    -- ════════════════════════════════════════════════════════════

    pioneer_huashen = {
        id = "pioneer_huashen",
        name = "先人一步·化神",
        type = "one_time",
        max_level = 1,
        trigger = {
            type = "server_race",
            leaderboard = "pioneer_huashen",
            max_slots = 10,
            condition_realm = "huashen",    -- 突破化神
        },
        bonus = { atk = 5 },
        desc = "全服前10名突破化神境，一步先则步步先",
    },

    pioneer_heti = {
        id = "pioneer_heti",
        name = "先人一步·合体",
        type = "one_time",
        max_level = 1,
        trigger = {
            type = "server_race",
            leaderboard = "pioneer_heti",
            max_slots = 10,
            condition_realm = "heti",       -- 突破合体
        },
        bonus = { atk = 5 },
        desc = "全服前10名突破合体境，一步先则步步先",
    },

    -- ════════════════════════════════════════════════════════════
    -- ④ 装备品质首获类 (first_obtain) — 2 枚
    -- ════════════════════════════════════════════════════════════

    first_cyan = {
        id = "first_cyan",
        name = "灵器初现",
        type = "one_time",
        max_level = 1,
        trigger = {
            type = "first_obtain",
            quality = "cyan",               -- 灵器品质
        },
        bonus = { hpRegen = 1 },
        desc = "首次获得灵器品质装备，灵力初凝护体生",
    },

    first_red = {
        id = "first_red",
        name = "圣器降世",
        type = "one_time",
        max_level = 1,
        trigger = {
            type = "first_obtain",
            quality = "red",                -- 圣器品质
        },
        bonus = { hpRegen = 1 },
        desc = "首次获得圣器品质装备，圣光庇佑身自愈",
    },

    -- ════════════════════════════════════════════════════════════
    -- ⑤ 事件发放类 (event_grant) — 一次性历史事件道印
    -- ════════════════════════════════════════════════════════════

    wutian_drunk = {
        id = "wutian_drunk",
        name = "大事件：无天醉酒",
        type = "one_time",
        max_level = 1,
        trigger = {
            type = "event_grant",
            leaderboard = "xianshi_rank",   -- 仙石榜（服务器级）
        },
        bonus = { fuyuan = 3 },
        desc = "26年5月8日夜，大黑无天当值醉酒，仙石市场紊乱，星界财团的另外一位股东降临接掌黑市",
    },
}

--- 道印显示顺序
MedalConfig.ORDER = {
    "realm_master",
    "taixu",
    "zhenyue",
    "luohan",
    "tianyan",
    "trial",
    "guardian",
    "pioneer_huashen",
    "pioneer_heti",
    "first_cyan",
    "first_red",
    "wutian_drunk",
}

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 格式化道印加成文本
---@param bonus table {hp=30} → "HP+30"
---@param level integer|nil 当前等级（用于计算总加成）
---@return string
function MedalConfig.FormatBonus(bonus, level)
    level = level or 1
    local parts = {}
    for attr, perLevel in pairs(bonus) do
        local name = MedalConfig.ATTR_NAMES[attr] or attr
        local total = perLevel * level
        parts[#parts + 1] = name .. "+" .. total
    end
    return table.concat(parts, " ")
end

--- 获取道印当前等级（从存储数据中）
---@param medalId string
---@param medalsData table account_atlas.medals
---@return integer
function MedalConfig.GetLevel(medalId, medalsData)
    if not medalsData then return 0 end
    local medal = MedalConfig.MEDALS[medalId]
    if not medal then return 0 end

    if medal.trigger.type == "server_race" or medal.trigger.type == "first_obtain"
        or medal.trigger.type == "event_grant" then
        local key = medalId
        return medalsData[key] and 1 or 0
    elseif medal.trigger.type == "item_consume" then
        local exp = medalsData.guardian_exp or 0
        return math.floor(exp / medal.trigger.exp_per_level)
    else
        local key = medalId .. "_level"
        return medalsData[key] or 0
    end
end

--- 获取道印总数
---@return integer
function MedalConfig.GetTotalCount()
    return #MedalConfig.ORDER
end

return MedalConfig
