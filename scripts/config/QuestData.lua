-- ============================================================================
-- QuestData.lua - 区域主线任务数据
-- 每个区域有独立的主线任务链，互不干扰
-- ============================================================================

local QuestData = {}

--- 装备槽位（排除武器和衣服）
QuestData.REWARD_SLOTS = {
    "helmet", "shoulder", "belt", "boots", "ring1", "ring2", "necklace"
}

--- 区域主线任务链
--- 每个 zone 一条主线，steps 依次完成
QuestData.ZONE_QUESTS = {
    -- ── 两界村区域主线 ──
    town_zone = {
        id = "town_zone",
        name = "两界村主线",
        zone = "town",               -- 所属区域（用于显示筛选）
        chapter = 1,                  -- 所属章节
        unlockSeal = "tiger_domain",  -- 完成全部步骤后解锁的封印
        steps = {
            {
                id = "kill_spider_queen",
                name = "击败蛛母",
                desc = "击败潜伏在山林中的蛛母",
                targetType = "spider_queen",
                targetCount = 1,
                reward = {
                    type = "equipment_pick",
                    tier = 1,
                    quality = "purple",
                    count = 3,  -- 生成3件，玩家选1件
                },
            },
            {
                id = "kill_boar_king",
                name = "击败猪三哥",
                desc = "讨伐凶残的猪三哥",
                targetType = "boar_king",
                targetCount = 1,
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "gold_bar", count = 1 },
                        { itemId = "qi_pill", count = 1 },
                    },
                },
            },
            {
                id = "kill_bandit_chief",
                name = "击败大大王",
                desc = "铲除山贼头领大大王",
                targetType = "bandit_chief",
                targetCount = 1,
                reward = {
                    type = "equipment_pick",
                    tier = 3,
                    quality = "purple",
                    count = 3,
                },
            },
            {
                id = "unseal_tiger_domain",
                name = "解除封印",
                desc = "找到村长李老，请求解除虎啸林的封印",
                targetType = "interact_village_elder",
                targetCount = 1,
                reward = nil,  -- 无任务奖励
            },
        },
    },
}

--- 封印数据
--- key = 被封印的区域ID, value = 封印信息
QuestData.SEALS = {
    tiger_domain = {
        questChain = "town_zone",         -- 需要完成的任务链
        sealTiles = {                     -- 封印覆盖的瓦片坐标
            {x = 67, y = 26}, {x = 68, y = 26},
            {x = 69, y = 26}, {x = 70, y = 26},
            {x = 67, y = 27}, {x = 68, y = 27},
            {x = 69, y = 27}, {x = 70, y = 27},
        },
        promptText = "封印未解除",
        promptRange = 3.0,  -- 靠近提示范围
    },
}

return QuestData
