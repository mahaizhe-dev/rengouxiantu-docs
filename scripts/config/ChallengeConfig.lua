-- ============================================================================
-- ChallengeConfig.lua - 阵营挑战系统配置（新版 v5）
-- 血煞盟·沈墨 / 浩气宗·陆青云 / 青云门·云裳 / 封魔殿·凌战
-- 声望 1-9 级（T3-T11），令牌分段：乌堡令(1-3) / 沙海令(4-5) / 太虚令(6-7) / 太虚剑令(8) / 谪仙令(9)
-- ============================================================================

local ChallengeConfig = {}

-- ──────────────────────────────────────────────
-- 基础常量
-- ──────────────────────────────────────────────

-- 每次挑战消耗的令牌数量（入场费）
ChallengeConfig.ATTEMPT_COST = 10

-- 副本地图大小（瓦片）
ChallengeConfig.ARENA_SIZE = 6

-- 副本地形瓦片类型
ChallengeConfig.ARENA_TILE = "CAMP_DIRT"

-- ──────────────────────────────────────────────
-- 声望等级常量
-- ──────────────────────────────────────────────

-- 最大声望等级（UI/系统动态循环用此常量，不硬编码 7）
ChallengeConfig.MAX_REPUTATION_LEVEL = 9

-- 声望等级 → Tier 映射
ChallengeConfig.REPUTATION_TIER = {
    [1] = 3, [2] = 4, [3] = 5, [4] = 6, [5] = 7,
    [6] = 8, [7] = 9, [8] = 10, [9] = 11,
}

-- 声望等级 → 令牌
ChallengeConfig.REPUTATION_TOKEN = {
    [1] = "wubao_token",  [2] = "wubao_token",  [3] = "wubao_token",
    [4] = "sha_hai_ling", [5] = "sha_hai_ling",
    [6] = "taixu_token",  [7] = "taixu_token",
    [8] = "taixu_jianling",
    [9] = "zhexian_ling",
}

-- 声望等级 → 解锁消耗
ChallengeConfig.REPUTATION_UNLOCK_COST = {
    [1] = 100, [2] = 300, [3] = 600,
    [4] = 500, [5] = 1000,
    [6] = 1000, [7] = 2000,
    [8] = 3000,
    [9] = 1000,
}

-- 声望等级 → 首通品质
ChallengeConfig.REPUTATION_FIRST_CLEAR_QUALITY = {
    [1] = "blue",   -- T3: 最高紫 → 首通蓝
    [2] = "blue",   -- T4: 最高紫 → 首通蓝
    [3] = "purple", -- T5: 最高橙 → 首通紫
    [4] = "purple", -- T6: 最高橙 → 首通紫
    [5] = "purple", -- T7: 最高橙 → 首通紫
    [6] = "purple", -- T8: 最高橙 → 首通紫
    [7] = "orange", -- T9: 最高灵器 → 首通橙
    [8] = "orange", -- T10: 最高青 → 首通橙
    [9] = "orange", -- T11/仙1: 蓝~红随机 → 首通橙色法宝保底
}

-- 声望等级 → 随机法宝品质下限（非首通挑战奖励）
ChallengeConfig.REPUTATION_RANDOM_MIN_QUALITY = {
    [1] = "white",
    [2] = "white",
    [3] = "white",
    [4] = "white",
    [5] = "white",
    [6] = "white",
    [7] = "green",
    [8] = "green",
    [9] = "blue",
}

-- 声望等级 → 随机法宝品质上限（非首通挑战奖励）
ChallengeConfig.REPUTATION_RANDOM_MAX_QUALITY = {
    [1] = "purple",
    [2] = "purple",
    [3] = "orange",
    [4] = "orange",
    [5] = "orange",
    [6] = "orange",
    [7] = "cyan",
    [8] = "cyan",
    [9] = "red",
}


-- ──────────────────────────────────────────────
-- 额外掉落显式概率表（v2: 第3候选，每项独立概率）
-- 命中时变为"法宝A / 法宝B / 额外道具"三选一
-- 未命中时仍为"法宝A / 法宝B"二选一
-- ──────────────────────────────────────────────

-- 5 系基础精华 ID（R1-R7 通用）
ChallengeConfig.BASE_ESSENCE_IDS = {
    "lipo_essence",     -- 力魄精华 → 凝力丹
    "panshi_essence",   -- 磐石精华 → 凝甲丹
    "yuanling_essence", -- 元灵精华 → 凝元丹
    "shihun_essence",   -- 噬魂精华 → 凝魂丹
    "lingxi_essence",   -- 灵息精华 → 凝息丹
}

-- [LEGACY] 旧字段保留，防止外部引用报错
ChallengeConfig.EXTRA_DROP_TYPES = { "gold_bar", "food", "essence", "cultivation_fruit" }
ChallengeConfig.ESSENCE_IDS = ChallengeConfig.BASE_ESSENCE_IDS

--- 构建指定声望等级的显式概率表
--- 每个 entry: { type=string, chance=number, count=number, [subId]=string }
--- chance 为该单项在第3候选位出现的绝对概率
---@param repLevel number 1-9
---@return table[] entries
function ChallengeConfig.BuildExtraDropTable(repLevel)
    local entries = {}

    -- ① 金条：所有档位固定 1.0%，数量按 2/4/6...递增
    local goldCount = repLevel * 2  -- R1=2, R2=4, ..., R9=18
    table.insert(entries, { type = "gold_bar", chance = 0.01, count = goldCount })

    -- ② 食物线：所有档位 3.0%
    local foodId, foodCount
    if repLevel <= 2 then
        foodId = "immortal_bone"
        foodCount = repLevel  -- R1=1, R2=2
    elseif repLevel <= 5 then
        foodId = "demon_essence"
        foodCount = repLevel - 2  -- R3=1, R4=2, R5=3
    else
        foodId = "dragon_marrow"
        foodCount = repLevel - 5  -- R6=1, R7=2, R8=3, R9=4
    end
    table.insert(entries, { type = "food", chance = 0.03, count = foodCount, subId = foodId })

    -- ③ 精华线：按档位递增
    local essenceChance  -- 单个精华概率
    if repLevel == 1 then essenceChance = 0.001
    elseif repLevel == 2 then essenceChance = 0.0015
    elseif repLevel == 3 then essenceChance = 0.002
    elseif repLevel == 4 then essenceChance = 0.0025
    elseif repLevel == 5 then essenceChance = 0.003
    elseif repLevel == 6 then essenceChance = 0.004
    elseif repLevel == 7 then essenceChance = 0.005
    else -- R8-R9: 五系各0.3%
        essenceChance = 0.003
    end

    for _, essId in ipairs(ChallengeConfig.BASE_ESSENCE_IDS) do
        table.insert(entries, { type = "essence", chance = essenceChance, count = 1, subId = essId })
    end

    -- R8 起加入钢骨精华；R9 提升到 1.5%
    if repLevel >= 8 then
        local gangguChance = repLevel >= 9 and 0.015 or 0.01
        table.insert(entries, { type = "essence", chance = gangguChance, count = 1, subId = "ganggu_essence" })
    end

    -- ④ 修炼果：R4 开始 1.0%
    if repLevel >= 4 then
        local fruitCount = repLevel - 3  -- R4=1 ... R8=5, R9=6
        table.insert(entries, { type = "cultivation_fruit", chance = 0.01, count = fruitCount })
    end

    -- ⑤ 灵韵果：R6 开始 1.0%
    if repLevel >= 6 then
        local lingyunCount = repLevel - 5  -- R6=1 ... R8=3, R9=4
        table.insert(entries, { type = "lingyun_fruit", chance = 0.01, count = lingyunCount })
    end

    return entries
end

--- 获取第3候选位总出现概率（所有单项 chance 之和）
---@param repLevel number 1-9
---@return number totalChance
function ChallengeConfig.GetExtraDropChance(repLevel)
    local entries = ChallengeConfig.BuildExtraDropTable(repLevel)
    local total = 0
    for _, e in ipairs(entries) do
        total = total + e.chance
    end
    return total
end

--- [LEGACY] 兼容旧接口：返回第3候选位总出现概率
---@deprecated 使用 ChallengeConfig.GetExtraDropChance(repLevel) 代替
function ChallengeConfig.GetExtraTotalChance(repLevel)
    return ChallengeConfig.GetExtraDropChance(repLevel)
end

--- 在概率表中加权抽取 1 个物品
--- 调用前已确认命中额外掉落（roll < totalChance）
---@param repLevel number 1-9
---@return table|nil entry 命中的条目 { type, count, subId }
function ChallengeConfig.RollExtraDropEntry(repLevel)
    local entries = ChallengeConfig.BuildExtraDropTable(repLevel)
    local total = 0
    for _, e in ipairs(entries) do total = total + e.chance end
    if total <= 0 then return nil end

    local roll = math.random() * total
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + e.chance
        if roll < acc then
            return e
        end
    end
    return entries[#entries]  -- fallback
end

-- [LEGACY] 旧接口兼容（供旧代码不报错）
ChallengeConfig.EXTRA_GOLD_BAR_COUNT = {
    [1] = 2, [2] = 4, [3] = 6, [4] = 8, [5] = 10,
    [6] = 12, [7] = 14, [8] = 16, [9] = 18,
}
ChallengeConfig.EXTRA_FOOD_ID = {
    [1] = "immortal_bone",  [2] = "immortal_bone",  [3] = "demon_essence",
    [4] = "demon_essence",  [5] = "demon_essence",
    [6] = "dragon_marrow",  [7] = "dragon_marrow",
    [8] = "dragon_marrow",  [9] = "dragon_marrow",
}

--- [LEGACY] 旧接口
function ChallengeConfig.GetExtraDropTypes(repLevel)
    if repLevel and repLevel >= 6 then
        return { "gold_bar", "food", "essence", "cultivation_fruit", "lingyun_fruit" }
    end
    return ChallengeConfig.EXTRA_DROP_TYPES
end

-- ──────────────────────────────────────────────
-- 阵营配置
-- ──────────────────────────────────────────────

ChallengeConfig.FACTIONS = {
    -- ═══════════════════════════════════════════
    -- 血煞盟
    -- ═══════════════════════════════════════════
    xuesha = {
        -- 新版 NPC（殷无咎·血煞盟主）
        npcId = "xuesha_master",
        name = "血煞盟",
        envoyName = "殷无咎",
        color = {200, 60, 60, 255},
        treasureKey = "xuehaitu",       -- 法宝 key（存档用）
        fabaoTplId = "fabao_xuehaitu",  -- 法宝模板 ID（EquipmentData 中）

        -- 旧版 NPC ID（用于 GetFactionByNpcId 向下兼容）
        legacyNpcId = "xuesha_spy",

        -- 新版声望等级（7 级，T3-T9）
        reputation = {
            [1] = {
                name = "声望1级",
                tier = 3,
                tokenId = "wubao_token",
                unlockCost = 100,
                monsterId = "challenge_shenmo_r1",
            },
            [2] = {
                name = "声望2级",
                tier = 4,
                tokenId = "wubao_token",
                unlockCost = 300,
                monsterId = "challenge_shenmo_r2",
            },
            [3] = {
                name = "声望3级",
                tier = 5,
                tokenId = "wubao_token",
                unlockCost = 600,
                monsterId = "challenge_shenmo_r3",
            },
            [4] = {
                name = "声望4级",
                tier = 6,
                tokenId = "sha_hai_ling",
                unlockCost = 500,
                monsterId = "challenge_shenmo_r4",
            },
            [5] = {
                name = "声望5级",
                tier = 7,
                tokenId = "sha_hai_ling",
                unlockCost = 1000,
                monsterId = "challenge_shenmo_r5",
            },
            [6] = {
                name = "声望6级",
                tier = 8,
                tokenId = "taixu_token",
                unlockCost = 1000,
                monsterId = "challenge_shenmo_r6",
            },
            [7] = {
                name = "声望7级",
                tier = 9,
                tokenId = "taixu_token",
                unlockCost = 2000,
                monsterId = "challenge_shenmo_r7",
            },
            [8] = {
                name = "声望8级",
                tier = 10,
                tokenId = "taixu_jianling",
                unlockCost = 3000,
                monsterId = "challenge_shenmo_r8",
            },
            [9] = {
                name = "声望9级",
                tier = 11,
                tokenId = "zhexian_ling",
                unlockCost = 1000,
                monsterId = "challenge_shenmo_r9",
            },
        },

        -- 旧版 Tier 配置（保留，兼容存量存档的 progress 数据）
        tiers = {
            -- ===== Ch2 挑战（消耗乌堡令）=====
            [1] = {
                name = "初试锋芒",
                chapter = 2,
                tokenId = "wubao_token",
                unlockCost = 100,
                monsterId = "challenge_shenmo_t1",
                reward = { type = "equipment", equipId = "blood_sea_lv1", label = "血海图·初" },
                repeatDrop = { equipId = "blood_sea_lv1", chance = 0.10, label = "血海图·初" },
            },
            [2] = {
                name = "血刃试炼",
                chapter = 2,
                tokenId = "wubao_token",
                unlockCost = 300,
                monsterId = "challenge_shenmo_t2",
                reward = { type = "pill", pillId = "xuesha_dan", count = 1, label = "血煞丹 ×1" },
                repeatDrop = { equipId = "blood_sea_lv1", chance = 0.20, label = "血海图·初" },
            },
            [3] = {
                name = "血海翻涌",
                chapter = 2,
                tokenId = "wubao_token",
                unlockCost = 600,
                monsterId = "challenge_shenmo_t3",
                reward = { type = "equipment", equipId = "blood_sea_lv2", label = "血海图·破" },
                repeatDrop = { equipId = "blood_sea_lv2", chance = 0.10, label = "血海图·破" },
            },
            [4] = {
                name = "血煞之巅",
                chapter = 2,
                tokenId = "wubao_token",
                unlockCost = 1000,
                monsterId = "challenge_shenmo_t4",
                reward = { type = "pill", pillId = "xuesha_dan", count = 2, label = "血煞丹 ×2" },
                repeatDrop = { equipId = "blood_sea_lv2", chance = 0.20, label = "血海图·破" },
            },
            -- ===== Ch3 挑战（消耗沙海令）=====
            [5] = {
                name = "沙海淬血",
                chapter = 3,
                tokenId = "sha_hai_ling",
                unlockCost = 300,
                monsterId = "challenge_shenmo_t5",
                reward = { type = "pill", pillId = "xuesha_dan", count = 2, label = "血煞丹 ×2" },
                repeatDrop = { equipId = "blood_sea_lv2", chance = 0.25, label = "血海图·破" },
            },
            [6] = {
                name = "血煞炼狱",
                chapter = 3,
                tokenId = "sha_hai_ling",
                unlockCost = 600,
                monsterId = "challenge_shenmo_t6",
                reward = { type = "equipment", equipId = "blood_sea_lv3", label = "血海图·绝" },
                repeatDrop = { equipId = "blood_sea_lv3", chance = 0.10, label = "血海图·绝" },
            },
            [7] = {
                name = "血海滔天",
                chapter = 3,
                tokenId = "sha_hai_ling",
                unlockCost = 1000,
                monsterId = "challenge_shenmo_t7",
                reward = { type = "pill", pillId = "xuesha_dan", count = 2, label = "血煞丹 ×2" },
                repeatDrop = { equipId = "blood_sea_lv3", chance = 0.20, label = "血海图·绝" },
            },
            [8] = {
                name = "血煞封魔",
                chapter = 3,
                tokenId = "sha_hai_ling",
                unlockCost = 1500,
                monsterId = "challenge_shenmo_t8",
                reward = { type = "pill", pillId = "xuesha_dan", count = 2, label = "血煞丹 ×2" },
                repeatDrop = { equipId = "blood_sea_lv3", chance = 0.25, label = "血海图·绝" },
            },
        },
    },

    -- ═══════════════════════════════════════════
    -- 浩气宗
    -- ═══════════════════════════════════════════
    haoqi = {
        npcId = "haoqi_master",
        name = "浩气宗",
        envoyName = "陆青云",
        color = {60, 140, 220, 255},
        treasureKey = "haoqiyin",           -- 法宝 key（存档用）
        fabaoTplId = "fabao_haoqiyin",      -- 法宝模板 ID（EquipmentData 中）

        -- 旧版 NPC ID（用于 GetFactionByNpcId 向下兼容）
        legacyNpcId = "haoqi_envoy",

        -- 新版声望等级（7 级，T3-T9）
        reputation = {
            [1] = {
                name = "声望1级",
                tier = 3,
                tokenId = "wubao_token",
                unlockCost = 100,
                monsterId = "challenge_luqingyun_r1",
            },
            [2] = {
                name = "声望2级",
                tier = 4,
                tokenId = "wubao_token",
                unlockCost = 300,
                monsterId = "challenge_luqingyun_r2",
            },
            [3] = {
                name = "声望3级",
                tier = 5,
                tokenId = "wubao_token",
                unlockCost = 600,
                monsterId = "challenge_luqingyun_r3",
            },
            [4] = {
                name = "声望4级",
                tier = 6,
                tokenId = "sha_hai_ling",
                unlockCost = 500,
                monsterId = "challenge_luqingyun_r4",
            },
            [5] = {
                name = "声望5级",
                tier = 7,
                tokenId = "sha_hai_ling",
                unlockCost = 1000,
                monsterId = "challenge_luqingyun_r5",
            },
            [6] = {
                name = "声望6级",
                tier = 8,
                tokenId = "taixu_token",
                unlockCost = 1000,
                monsterId = "challenge_luqingyun_r6",
            },
            [7] = {
                name = "声望7级",
                tier = 9,
                tokenId = "taixu_token",
                unlockCost = 2000,
                monsterId = "challenge_luqingyun_r7",
            },
            [8] = {
                name = "声望8级",
                tier = 10,
                tokenId = "taixu_jianling",
                unlockCost = 3000,
                monsterId = "challenge_luqingyun_r8",
            },
            [9] = {
                name = "声望9级",
                tier = 11,
                tokenId = "zhexian_ling",
                unlockCost = 1000,
                monsterId = "challenge_luqingyun_r9",
            },
        },

        -- 旧版 Tier 配置（保留，兼容存量存档的 progress 数据）
        tiers = {
            -- ===== Ch2 挑战（消耗乌堡令）=====
            [1] = {
                name = "以武会友",
                chapter = 2,
                tokenId = "wubao_token",
                unlockCost = 100,
                monsterId = "challenge_luqingyun_t1",
                reward = { type = "equipment", equipId = "haoqi_seal_lv1", label = "浩气印·初" },
                repeatDrop = { equipId = "haoqi_seal_lv1", chance = 0.10, label = "浩气印·初" },
            },
            [2] = {
                name = "浩气凌云",
                chapter = 2,
                tokenId = "wubao_token",
                unlockCost = 300,
                monsterId = "challenge_luqingyun_t2",
                reward = { type = "pill", pillId = "haoqi_dan", count = 1, label = "浩气丹 ×1" },
                repeatDrop = { equipId = "haoqi_seal_lv1", chance = 0.20, label = "浩气印·初" },
            },
            [3] = {
                name = "正气冲霄",
                chapter = 2,
                tokenId = "wubao_token",
                unlockCost = 600,
                monsterId = "challenge_luqingyun_t3",
                reward = { type = "equipment", equipId = "haoqi_seal_lv2", label = "浩气印·破" },
                repeatDrop = { equipId = "haoqi_seal_lv2", chance = 0.10, label = "浩气印·破" },
            },
            [4] = {
                name = "宗主之路",
                chapter = 2,
                tokenId = "wubao_token",
                unlockCost = 1000,
                monsterId = "challenge_luqingyun_t4",
                reward = { type = "pill", pillId = "haoqi_dan", count = 2, label = "浩气丹 ×2" },
                repeatDrop = { equipId = "haoqi_seal_lv2", chance = 0.20, label = "浩气印·破" },
            },
            -- ===== Ch3 挑战（消耗沙海令）=====
            [5] = {
                name = "沙海试剑",
                chapter = 3,
                tokenId = "sha_hai_ling",
                unlockCost = 300,
                monsterId = "challenge_luqingyun_t5",
                reward = { type = "pill", pillId = "haoqi_dan", count = 2, label = "浩气丹 ×2" },
                repeatDrop = { equipId = "haoqi_seal_lv2", chance = 0.25, label = "浩气印·破" },
            },
            [6] = {
                name = "天罡炼心",
                chapter = 3,
                tokenId = "sha_hai_ling",
                unlockCost = 600,
                monsterId = "challenge_luqingyun_t6",
                reward = { type = "equipment", equipId = "haoqi_seal_lv3", label = "浩气印·绝" },
                repeatDrop = { equipId = "haoqi_seal_lv3", chance = 0.10, label = "浩气印·绝" },
            },
            [7] = {
                name = "浩气冲天",
                chapter = 3,
                tokenId = "sha_hai_ling",
                unlockCost = 1000,
                monsterId = "challenge_luqingyun_t7",
                reward = { type = "pill", pillId = "haoqi_dan", count = 2, label = "浩气丹 ×2" },
                repeatDrop = { equipId = "haoqi_seal_lv3", chance = 0.20, label = "浩气印·绝" },
            },
            [8] = {
                name = "正道无极",
                chapter = 3,
                tokenId = "sha_hai_ling",
                unlockCost = 1500,
                monsterId = "challenge_luqingyun_t8",
                reward = { type = "pill", pillId = "haoqi_dan", count = 2, label = "浩气丹 ×2" },
                repeatDrop = { equipId = "haoqi_seal_lv3", chance = 0.25, label = "浩气印·绝" },
            },
        },
    },

    -- ═══════════════════════════════════════════
    -- 青云门
    -- ═══════════════════════════════════════════
    qingyun = {
        -- 新版 NPC（云无涯·青云城主）
        npcId = "qingyun_master",
        name = "青云门",
        envoyName = "云裳",
        color = {80, 200, 120, 255},        -- 青翠绿
        treasureKey = "qingyunta",          -- 法宝 key（存档用）
        fabaoTplId = "fabao_qingyunta",     -- 法宝模板 ID（EquipmentData 中）

        -- 旧版 NPC ID（青云门是新增阵营，无旧版 NPC）
        legacyNpcId = nil,

        -- 新版声望等级（7 级，T3-T9）
        reputation = {
            [1] = {
                name = "声望1级",
                tier = 3,
                tokenId = "wubao_token",
                unlockCost = 100,
                monsterId = "challenge_yunshang_r1",
            },
            [2] = {
                name = "声望2级",
                tier = 4,
                tokenId = "wubao_token",
                unlockCost = 300,
                monsterId = "challenge_yunshang_r2",
            },
            [3] = {
                name = "声望3级",
                tier = 5,
                tokenId = "wubao_token",
                unlockCost = 600,
                monsterId = "challenge_yunshang_r3",
            },
            [4] = {
                name = "声望4级",
                tier = 6,
                tokenId = "sha_hai_ling",
                unlockCost = 500,
                monsterId = "challenge_yunshang_r4",
            },
            [5] = {
                name = "声望5级",
                tier = 7,
                tokenId = "sha_hai_ling",
                unlockCost = 1000,
                monsterId = "challenge_yunshang_r5",
            },
            [6] = {
                name = "声望6级",
                tier = 8,
                tokenId = "taixu_token",
                unlockCost = 1000,
                monsterId = "challenge_yunshang_r6",
            },
            [7] = {
                name = "声望7级",
                tier = 9,
                tokenId = "taixu_token",
                unlockCost = 2000,
                monsterId = "challenge_yunshang_r7",
            },
            [8] = {
                name = "声望8级",
                tier = 10,
                tokenId = "taixu_jianling",
                unlockCost = 3000,
                monsterId = "challenge_yunshang_r8",
            },
            [9] = {
                name = "声望9级",
                tier = 11,
                tokenId = "zhexian_ling",
                unlockCost = 1000,
                monsterId = "challenge_yunshang_r9",
            },
        },

        -- 青云门是新增阵营，无旧版 tiers（无存量存档需要兼容）
        tiers = {},
    },

    -- ═══════════════════════════════════════════
    -- 封魔殿
    -- ═══════════════════════════════════════════
    fengmo = {
        -- 新版 NPC（凌战·封魔殿少帅）
        npcId = "fengmo_master",
        name = "封魔殿",
        envoyName = "凌战",
        color = {160, 80, 200, 255},        -- 暗紫色
        treasureKey = "fengmopan",          -- 法宝 key（存档用）
        fabaoTplId = "fabao_fengmopan",     -- 法宝模板 ID（EquipmentData 中）

        -- 封魔殿是新增阵营，无旧版 NPC
        legacyNpcId = nil,

        -- 新版声望等级（7 级，T3-T9）
        reputation = {
            [1] = {
                name = "声望1级",
                tier = 3,
                tokenId = "wubao_token",
                unlockCost = 100,
                monsterId = "challenge_liwuji_r1",
            },
            [2] = {
                name = "声望2级",
                tier = 4,
                tokenId = "wubao_token",
                unlockCost = 300,
                monsterId = "challenge_liwuji_r2",
            },
            [3] = {
                name = "声望3级",
                tier = 5,
                tokenId = "wubao_token",
                unlockCost = 600,
                monsterId = "challenge_liwuji_r3",
            },
            [4] = {
                name = "声望4级",
                tier = 6,
                tokenId = "sha_hai_ling",
                unlockCost = 500,
                monsterId = "challenge_liwuji_r4",
            },
            [5] = {
                name = "声望5级",
                tier = 7,
                tokenId = "sha_hai_ling",
                unlockCost = 1000,
                monsterId = "challenge_liwuji_r5",
            },
            [6] = {
                name = "声望6级",
                tier = 8,
                tokenId = "taixu_token",
                unlockCost = 1000,
                monsterId = "challenge_liwuji_r6",
            },
            [7] = {
                name = "声望7级",
                tier = 9,
                tokenId = "taixu_token",
                unlockCost = 2000,
                monsterId = "challenge_liwuji_r7",
            },
            [8] = {
                name = "声望8级",
                tier = 10,
                tokenId = "taixu_jianling",
                unlockCost = 3000,
                monsterId = "challenge_liwuji_r8",
            },
            [9] = {
                name = "声望9级",
                tier = 11,
                tokenId = "zhexian_ling",
                unlockCost = 1000,
                monsterId = "challenge_liwuji_r9",
            },
        },

        -- 封魔殿是新增阵营，无旧版 tiers（无存量存档需要兼容）
        tiers = {},
    },
}

-- ──────────────────────────────────────────────
-- 法宝图标阶段映射（按 Tier 区间）
-- ──────────────────────────────────────────────

-- 返回法宝图标路径后缀阶段名
-- T3-T4 → "chu"  T5-T8 → "po"  T9+ → "jue"
function ChallengeConfig.GetFabaoIconStage(tier)
    if tier <= 4 then return "chu"
    elseif tier <= 8 then return "po"
    else return "jue"
    end
end

-- ──────────────────────────────────────────────
-- 查询函数
-- ──────────────────────────────────────────────

--- 根据 npcId 获取阵营 key（支持新旧两种 NPC ID）
---@param npcId string
---@return string|nil factionKey
function ChallengeConfig.GetFactionByNpcId(npcId)
    for key, faction in pairs(ChallengeConfig.FACTIONS) do
        if faction.npcId == npcId then
            return key
        end
        -- 兼容旧版 NPC ID
        if faction.legacyNpcId and faction.legacyNpcId == npcId then
            return key
        end
    end
    return nil
end

--- 判断阵营是否已升级为新版（有 reputation 字段）
---@param factionKey string
---@return boolean
function ChallengeConfig.IsNewVersion(factionKey)
    local faction = ChallengeConfig.FACTIONS[factionKey]
    return faction ~= nil and faction.reputation ~= nil
end

--- 获取声望等级配置
---@param factionKey string
---@param repLevel number 1-9
---@return table|nil
function ChallengeConfig.GetReputationLevel(factionKey, repLevel)
    local faction = ChallengeConfig.FACTIONS[factionKey]
    if not faction or not faction.reputation then return nil end
    return faction.reputation[repLevel]
end

--- 获取首通品质
---@param repLevel number 1-9
---@return string quality
function ChallengeConfig.GetFirstClearQuality(repLevel)
    return ChallengeConfig.REPUTATION_FIRST_CLEAR_QUALITY[repLevel] or "blue"
end

--- 获取非首通声望法宝随机品质下限
---@param repLevel number 1-9
---@return string quality
function ChallengeConfig.GetRandomMinQuality(repLevel)
    return ChallengeConfig.REPUTATION_RANDOM_MIN_QUALITY[repLevel] or "white"
end

--- 获取非首通声望法宝随机品质上限
---@param repLevel number 1-9
---@return string quality
function ChallengeConfig.GetRandomMaxQuality(repLevel)
    return ChallengeConfig.REPUTATION_RANDOM_MAX_QUALITY[repLevel] or "purple"
end

--- 获取重复通关法宝的品质范围
---@param repLevel number 1-9
---@return string minQuality
---@return string maxQuality
function ChallengeConfig.GetRepeatQualityRange(repLevel)
    return ChallengeConfig.GetRandomMinQuality(repLevel),
        ChallengeConfig.GetRandomMaxQuality(repLevel)
end

-- [LEGACY] 旧接口保留供兼容查询，实际概率已由 BuildExtraDropTable 管理
---@deprecated 使用 ChallengeConfig.BuildExtraDropTable(repLevel) 代替
function ChallengeConfig.GetExtraGoldBarCount(repLevel)
    return ChallengeConfig.EXTRA_GOLD_BAR_COUNT[repLevel] or 2
end

---@deprecated 使用 ChallengeConfig.BuildExtraDropTable(repLevel) 代替
function ChallengeConfig.GetExtraFoodId(repLevel)
    return ChallengeConfig.EXTRA_FOOD_ID[repLevel] or "beast_meat"
end

return ChallengeConfig
