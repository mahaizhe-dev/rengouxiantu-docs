-- ============================================================================
-- AscensionConfig.lua - 120级后仙阶/渡劫/仙体 静态配置
-- ============================================================================
-- 只放配置数据，不写逻辑。
-- 关联文档：
--   docs/数值文档/120级飞升渡劫与仙体系统程序执行版.md
--   docs/数值文档/后120级仙阶设定表.md

local C = {}

-- ============================================================================
-- 1. 功能开关
-- ============================================================================
C.FEATURE_ENABLED = true

-- ============================================================================
-- 2. 材料定义
-- ============================================================================
C.ITEM_ONE_TURN_PILL = "one_turn_tribulation_pill"   -- 一转仙劫丹
C.ITEM_TWO_TURN_PILL = "two_turn_tribulation_pill"   -- 二转仙劫丹（暂不产出）

-- ============================================================================
-- 3. 仙阶进度配置
-- ============================================================================
-- 每个大仙阶内 9 阶的进度需求（1阶为渡劫/大突破，2-9阶为小突破）
C.PROGRESS_PER_MINOR = { 30, 10, 10, 20, 20, 20, 30, 30, 30 }
C.PROGRESS_OVERFLOW_MAX = 4      -- 最后一颗丹允许的最大溢出

-- 吃丹随机表（权重制）
C.PILL_GAIN_TABLE = {
    { type = "normal",      gain = 1, weight = 775 },
    { type = "crit",        gain = 2, weight = 200 },
    { type = "bigCrit",     gain = 3, weight = 20 },
    { type = "heavenCrit",  gain = 5, weight = 5 },
}
C.PILL_GAIN_TOTAL_WEIGHT = 1000  -- 权重总和

-- ============================================================================
-- 4. 渡劫配置
-- ============================================================================
C.TRIBULATION_COOLDOWN_SEC = 600   -- 失败冷却 10 分钟
C.TRIBULATION_DURATION_SEC = 60    -- 渡劫持续 60 秒
C.TRIBULATION_WARMUP_SEC = 3      -- 入场准备 3 秒

-- 九次渡劫框架（首版只实现第1次）
C.TRIBULATION_STAGES = {
    [1] = { name = "雷火劫",     from = "dacheng_4",  to = "dujie_1",  material = C.ITEM_ONE_TURN_PILL },
    [2] = { name = "风雷劫",     material = C.ITEM_TWO_TURN_PILL },
    [3] = { name = "地脉劫" },
    [4] = { name = "天门劫" },
    [5] = { name = "玄阴劫" },
    [6] = { name = "金光劫" },
    [7] = { name = "太乙轮劫" },
    [8] = { name = "大罗万象劫" },
    [9] = { name = "混元无量劫" },
}

-- ============================================================================
-- 5. 仙体配置
-- ============================================================================
C.IMMORTAL_BODY_SWITCH_COST_LINGYUN = 1000

-- 等级成长模板（从 Lv1 开始计算）
C.GROWTH_PROFILES = {
    mortal = {
        name = "凡夫俗子",
        maxHp = 15, atk = 3, def = 2, hpRegen = 0.3,
    },
    immortal_body_1 = {
        name = "仙人之体",
        maxHp = 25, atk = 5, def = 3, hpRegen = 0.5,
    },
    immortal_body_qinglian = {
        name = "青莲长生体",
        maxHp = 30, atk = 3, def = 2, hpRegen = 1.0,
    },
    immortal_body_wanbao_liuli = {
        name = "万宝琉璃体",
        maxHp = 15, atk = 3, def = 2, hpRegen = 0.3,
        xianyuanGrowth = {
            fortune = {
                perLevel = 1,
                startLevel = 1,
                maxLevel = 300,
            },
        },
    },
}

-- ============================================================================
-- 6. 大仙阶总览（9 大仙阶 × 9 小阶 = 81 阶）
-- ============================================================================
C.MAJOR_STAGES = {
    { id = "zhexian",   name = "谪仙",       levelRange = {121, 140}, maxLevel = 140, coefficient = 1.0 },
    { id = "renxian",   name = "人仙",       levelRange = {141, 160}, maxLevel = 160, coefficient = 1.2 },
    { id = "dixian",    name = "地仙",       levelRange = {161, 180}, maxLevel = 180, coefficient = 1.4 },
    { id = "tianxian",  name = "天仙",       levelRange = {181, 200}, maxLevel = 200, coefficient = 1.6 },
    { id = "xuanxian",  name = "玄仙",       levelRange = {201, 220}, maxLevel = 220, coefficient = 1.8 },
    { id = "jinxian",   name = "金仙",       levelRange = {221, 240}, maxLevel = 240, coefficient = 2.0 },
    { id = "taiyijinxian", name = "太乙金仙", levelRange = {241, 260}, maxLevel = 260, coefficient = 2.5 },
    { id = "daluojinxian", name = "大罗金仙", levelRange = {261, 280}, maxLevel = 280, coefficient = 3.0 },
    { id = "hunyuan",   name = "混元大罗金仙", levelRange = {281, 300}, maxLevel = 300, coefficient = 4.0 },
}

-- ============================================================================
-- 7. 仙阶属性奖励表（81阶完整）
-- ============================================================================
-- 公式：大仙阶1阶 = 谪仙1阶基准 × 系数，小阶 = 大仙阶1阶 × 0.2
-- 谪仙1阶基准：HP+500, ATK+100, DEF+80, 回复+10

C.BASE_REWARDS = { maxHp = 500, atk = 100, def = 80, hpRegen = 10 }

-- 生成完整 81 阶奖励表
C.ASCENSION_REWARDS = {}
for stageIdx, stage in ipairs(C.MAJOR_STAGES) do
    local coeff = stage.coefficient
    local major = {
        maxHp   = math.floor(C.BASE_REWARDS.maxHp * coeff),
        atk     = math.floor(C.BASE_REWARDS.atk * coeff),
        def     = math.floor(C.BASE_REWARDS.def * coeff),
        hpRegen = C.BASE_REWARDS.hpRegen * coeff,
    }
    local minor = {
        maxHp   = math.floor(major.maxHp * 0.2),
        atk     = math.floor(major.atk * 0.2),
        def     = major.def * 0.2,  -- 允许小数，后续 floor
        hpRegen = major.hpRegen * 0.2,
    }
    -- DEF 小阶取整规则：保留一位小数
    minor.def = math.floor(minor.def * 10) / 10

    for minorIdx = 1, 9 do
        local totalIdx = (stageIdx - 1) * 9 + minorIdx
        local isMajor = (minorIdx == 1)
        local rewards = isMajor and major or minor
        local requiredLevel = (stage.levelRange[1] - 1) + (minorIdx - 1) * 2
        C.ASCENSION_REWARDS[totalIdx] = {
            totalIndex  = totalIdx,
            stageIndex  = stageIdx,
            minorIndex  = minorIdx,
            stageName   = stage.name,
            displayName = stage.name .. ({"一","二","三","四","五","六","七","八","九"})[minorIdx] .. "阶",
            isMajor     = isMajor,
            requiredLevel = requiredLevel,
            maxLevel    = stage.maxLevel,
            rewards     = rewards,
        }
    end
end

-- ============================================================================
-- 8. 仙阶怪物系数
-- ============================================================================
-- 属性系数 = 6.0 + (大仙阶序-1)*5.0 + (阶位-1)*0.5
-- 奖励系数 = 1.0 + (22 + 仙阶总序) * 0.2

C.MONSTER_BASE_COEFFICIENT = 6.0
C.MONSTER_MAJOR_STEP = 5.0      -- 大仙阶间跳跃（含小阶增长 4.0 + 边界 1.0）
C.MONSTER_MINOR_STEP = 0.5

--- 获取仙阶怪物属性系数
---@param totalIndex number 仙阶总序 1-81
---@return number
function C.GetMonsterAttributeCoeff(totalIndex)
    local stageIdx = math.ceil(totalIndex / 9)  -- 大仙阶序 1-9
    local minorIdx = ((totalIndex - 1) % 9) + 1 -- 小阶 1-9
    return C.MONSTER_BASE_COEFFICIENT + (stageIdx - 1) * C.MONSTER_MAJOR_STEP + (minorIdx - 1) * C.MONSTER_MINOR_STEP
end

--- 获取仙阶怪物奖励系数
---@param totalIndex number 仙阶总序 1-81
---@return number
function C.GetMonsterRewardCoeff(totalIndex)
    local order = 22 + totalIndex
    return 1.0 + order * 0.2
end

-- ============================================================================
-- 9. 仙装 Tier 映射（T11=仙1，tier 12=仙2...tier 20=仙10）
-- ============================================================================
-- T11 就是仙1，没有单独的 T11 了
-- 倍率表已直接写入 EquipmentData.TIER_MULTIPLIER[11]-[20]
-- 此处仅保留名称映射供 UI 使用

C.XIAN_TIER_OFFSET = 10  -- tier = 仙阶 + XIAN_TIER_OFFSET（仙1=tier11, 仙2=tier12）

C.XIAN_TIER_NAMES = {
    [11] = "仙1",  [12] = "仙2",  [13] = "仙3",  [14] = "仙4",  [15] = "仙5",
    [16] = "仙6",  [17] = "仙7",  [18] = "仙8",  [19] = "仙9",  [20] = "仙10",
}

-- ============================================================================
-- 10. 仙装等级→Tier 窗口（扩展掉落系统用）
-- ============================================================================
-- 仙装 Tier 解锁等级（T11=仙1 解锁等级已在旧表中=121）
C.XIAN_TIER_UNLOCK_LEVEL = {
    [11] = 121,  -- 仙1
    [12] = 141,  -- 仙2
    [13] = 161,  -- 仙3
    [14] = 181,  -- 仙4
    [15] = 201,  -- 仙5
    [16] = 221,  -- 仙6
    [17] = 241,  -- 仙7
    [18] = 261,  -- 仙8
    [19] = 281,  -- 仙9
    [20] = 301,  -- 仙10（预留）
}

-- 怪物等级→可用 Tier 窗口（扩展 121+ 部分）
C.XIAN_TIER_WINDOWS = {
    -- { minLevel, maxLevel, tiers }
    { 121, 140, { 9, 10, 11 } },            -- 谪仙段：T9, T10, 仙1
    { 141, 160, { 10, 11, 12 } },           -- 人仙段：T10, 仙1, 仙2
    { 161, 180, { 11, 12, 13 } },           -- 地仙段：仙1, 仙2, 仙3
    { 181, 200, { 12, 13, 14 } },           -- 天仙段：仙2, 仙3, 仙4
    { 201, 220, { 13, 14, 15 } },           -- 玄仙段：仙3, 仙4, 仙5
    { 221, 240, { 14, 15, 16 } },           -- 金仙段：仙4, 仙5, 仙6
    { 241, 260, { 15, 16, 17 } },           -- 太乙段：仙5, 仙6, 仙7
    { 261, 280, { 16, 17, 18 } },           -- 大罗段：仙6, 仙7, 仙8
    { 281, 300, { 17, 18, 19 } },           -- 混元段：仙7, 仙8, 仙9
}

-- 品质门槛（仙装阶段橙/青/红解锁偏移）
C.XIAN_QUALITY_GATE = {
    -- tier = { orange_level, cyan_level, red_level }
    [11] = { 126, 131, 136 },  -- 仙1
    [12] = { 146, 151, 156 },  -- 仙2
    [13] = { 166, 171, 176 },  -- 仙3
    [14] = { 186, 191, 196 },  -- 仙4
    [15] = { 206, 211, 216 },  -- 仙5
    [16] = { 226, 231, 236 },  -- 仙6
    [17] = { 246, 251, 256 },  -- 仙7
    [18] = { 266, 271, 276 },  -- 仙8
    [19] = { 286, 291, 296 },  -- 仙9
    [20] = { 306, 311, 316 },  -- 仙10
}

-- ============================================================================
-- 11. 剑气长城兑换配置
-- ============================================================================
C.SWORD_WALL_PILL_PRICE = 2000       -- 每颗 2000 剑气积分
C.SWORD_WALL_PILL_LIMIT = 10         -- 每角色永久限购 10 颗

-- ============================================================================
-- 12. 第六章炼丹炉配置
-- ============================================================================
C.ALCHEMY_PILL_GOLD_COST = 1000000   -- 100 万金币
C.ALCHEMY_PILL_LINGYUN_COST = 10000  -- 1 万灵韵

-- ============================================================================
-- 13. 注册仙阶假 realm 到 GameConfig.REALMS（供 BreakthroughCelebration 使用）
-- ============================================================================
local realmsRegistered_ = false

function C.EnsureRealmsRegistered()
    if realmsRegistered_ then return end
    realmsRegistered_ = true

    local GameConfig = require("config.GameConfig")
    if not GameConfig.REALMS then return end

    local function ApplyRealmEntry(realmId, entry)
        local realm = GameConfig.REALMS[realmId]
        if not realm then
            realm = {}
            GameConfig.REALMS[realmId] = realm
        end
        realm.name = entry.displayName
        realm.isMajor = entry.isMajor
        realm.order = 22 + entry.totalIndex
        realm.maxLevel = entry.maxLevel or 300
        realm.requiredLevel = entry.requiredLevel or 120
        realm.attackSpeedBonus = 1.0  -- 继承谪仙攻速，之后不再增加
        realm.rewards = entry.rewards
        realm.monsterAttributeCoeff = C.GetMonsterAttributeCoeff(entry.totalIndex)
        realm.monsterRewardCoeff = C.GetMonsterRewardCoeff(entry.totalIndex)
    end

    for _, entry in ipairs(C.ASCENSION_REWARDS) do
        local realmId = "asc_" .. entry.totalIndex
        ApplyRealmEntry(realmId, entry)

        -- 怪物配置可直接使用 zhexian_1 / renxian_1 这类执行 ID。
        local stage = C.MAJOR_STAGES[entry.stageIndex]
        local aliasId = stage.id .. "_" .. tostring(entry.minorIndex)
        ApplyRealmEntry(aliasId, entry)
    end
end

return C
