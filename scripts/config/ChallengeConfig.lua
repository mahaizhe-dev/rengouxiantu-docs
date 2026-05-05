-- ============================================================================
-- ChallengeConfig.lua - 阵营挑战系统配置（新版 v3）
-- 血煞盟·沈墨 / 浩气宗·陆青云 / 青云门·云裳 / 封魔殿·凌战
-- 声望 1-7 级（T3-T9），令牌分段：乌堡令(1-3) / 沙海令(4-5) / 太虚令(6-7)
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

-- 声望等级 → Tier 映射
ChallengeConfig.REPUTATION_TIER = {
    [1] = 3, [2] = 4, [3] = 5, [4] = 6, [5] = 7, [6] = 8, [7] = 9,
}

-- 声望等级 → 令牌
ChallengeConfig.REPUTATION_TOKEN = {
    [1] = "wubao_token",  [2] = "wubao_token",  [3] = "wubao_token",
    [4] = "sha_hai_ling", [5] = "sha_hai_ling",
    [6] = "taixu_token",  [7] = "taixu_token",
}

-- 声望等级 → 解锁消耗
ChallengeConfig.REPUTATION_UNLOCK_COST = {
    [1] = 100, [2] = 300, [3] = 600,
    [4] = 500, [5] = 1000,
    [6] = 1000, [7] = 2000,
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
}

-- ──────────────────────────────────────────────
-- 物品掉落配置（声望等级 × 1% 概率）
-- ──────────────────────────────────────────────

-- 四种物品掉落（等概率四选一）
ChallengeConfig.EXTRA_DROP_TYPES = { "gold_bar", "food", "essence", "cultivation_fruit" }

--- 获取指定声望等级的物品掉落种类列表
--- R6-R7 额外增加灵韵果，与其他种类共享概率
---@param repLevel number 1-7
---@return string[]
function ChallengeConfig.GetExtraDropTypes(repLevel)
    if repLevel and repLevel >= 6 then
        return { "gold_bar", "food", "essence", "cultivation_fruit", "lingyun_fruit" }
    end
    return ChallengeConfig.EXTRA_DROP_TYPES
end

-- 声望等级 → 金条数量
ChallengeConfig.EXTRA_GOLD_BAR_COUNT = {
    [1] = 1, [2] = 1, [3] = 1,  -- T3-T5
    [4] = 2, [5] = 2,           -- T6-T7
    [6] = 3, [7] = 3,           -- T8-T9
}

-- 声望等级 → 宠物食物 consumableId
ChallengeConfig.EXTRA_FOOD_ID = {
    [1] = "immortal_bone",  [2] = "immortal_bone",  [3] = "immortal_bone",  -- R1-R3: 仙骨
    [4] = "demon_essence",  [5] = "demon_essence",                          -- R4-R5: 妖兽精华
    [6] = "dragon_marrow",  [7] = "dragon_marrow",                          -- R6-R7: 龙髓
}

-- 丹药材料（五种精华，等概率五选一）
ChallengeConfig.ESSENCE_IDS = {
    "lipo_essence",     -- 力魄精华 → 凝力丹
    "panshi_essence",   -- 磐石精华 → 凝甲丹
    "yuanling_essence", -- 元灵精华 → 凝元丹
    "shihun_essence",   -- 噬魂精华 → 凝魂丹
    "lingxi_essence",   -- 灵息精华 → 凝息丹
}

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
---@param repLevel number 1-7
---@return table|nil
function ChallengeConfig.GetReputationLevel(factionKey, repLevel)
    local faction = ChallengeConfig.FACTIONS[factionKey]
    if not faction or not faction.reputation then return nil end
    return faction.reputation[repLevel]
end

--- 获取首通品质
---@param repLevel number 1-7
---@return string quality
function ChallengeConfig.GetFirstClearQuality(repLevel)
    return ChallengeConfig.REPUTATION_FIRST_CLEAR_QUALITY[repLevel] or "blue"
end

--- 获取物品掉落概率（声望等级 × 1%）
---@param repLevel number 1-7
---@return number probability 0.01~0.07
function ChallengeConfig.GetExtraDropChance(repLevel)
    return (repLevel or 0) * 0.01
end

--- 获取物品掉落的金条数量
---@param repLevel number 1-7
---@return number count
function ChallengeConfig.GetExtraGoldBarCount(repLevel)
    return ChallengeConfig.EXTRA_GOLD_BAR_COUNT[repLevel] or 1
end

--- 获取物品掉落的食物 ID
---@param repLevel number 1-7
---@return string consumableId
function ChallengeConfig.GetExtraFoodId(repLevel)
    return ChallengeConfig.EXTRA_FOOD_ID[repLevel] or "beast_meat"
end

return ChallengeConfig
