-- ============================================================================
-- QuestData_ch2.lua - 第二章·乌家堡 主线任务数据
-- 与第一章完全独立，由 QuestSystem.Init() 合并加载
-- ============================================================================

local TileTypes = require("config.TileTypes")

local QuestData_ch2 = {}

--- 区域主线任务链
QuestData_ch2.ZONE_QUESTS = {
    -- ── 乌家堡区域主线 ──
    fortress_zone = {
        id = "fortress_zone",
        name = "乌家堡主线",
        zone = "camp_a",              -- 任务NPC所在区域
        chapter = 2,                  -- 所属章节（用于跨区域显示）
        unlockSeal = nil,             -- 封印在步骤内处理
        steps = {
            -- 主线1：考验实力 → 奖励：金条5个 + 灵韵10
            {
                id = "kill_boar_boss_ch2",
                name = "考验实力",
                desc = "击败野猪坡的猪大哥，证明自己的实力",
                targetType = "boar_boss_ch2",
                targetCount = 1,
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "gold_bar", count = 10 },
                        { itemId = "lingYun",  count = 10 },
                    },
                },
            },
            -- 主线2：淬毒 → 奖励：4阶紫装3选1
            {
                id = "kill_snake_king",
                name = "淬毒",
                desc = "击败毒蛇沼的蛇王，取其毒液",
                targetType = "snake_king",
                targetCount = 1,
                reward = {
                    type = "equipment_pick",
                    tier = 4,
                    quality = "purple",
                    count = 3,
                },
            },
            -- 主线3：进攻乌堡 → 击杀天南+地北（多目标） → 奖励：筑基丹1颗 + 金条10个
            {
                id = "attack_fortress",
                name = "进攻乌堡",
                desc = "攻入乌家堡，击败乌天南和乌地北",
                targets = {
                    { targetType = "wu_tiannan", targetCount = 1, name = "乌天南" },
                    { targetType = "wu_dibei",   targetCount = 1, name = "乌地北" },
                },
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "zhuji_pill", count = 1 },
                        { itemId = "gold_bar",   count = 10 },
                    },
                },
            },
            -- 主线4：报仇 → 奖励：5阶紫装3选1
            {
                id = "kill_wu_wanchou",
                name = "报仇",
                desc = "击败乌家堡作恶的源泉——投靠炼尸宗的大伯乌万仇",
                targetType = "wu_wanchou",
                targetCount = 1,
                reward = {
                    type = "equipment_pick",
                    tier = 5,
                    quality = "purple",
                    count = 3,
                },
            },
            -- 主线5：让他们安息 → 奖励：T5橙装3选1
            {
                id = "kill_blood_puppets",
                name = "让他们安息",
                desc = "击败乌家血傀，让那些被炼成傀儡的修士安息",
                targetType = "wu_blood_puppet",
                targetCount = 100,
                reward = {
                    type = "equipment_pick",
                    tier = 5,
                    quality = "orange",
                    count = 3,
                },
            },
            -- 主线6：攻破大门 → 解除封印（交互步骤）
            {
                id = "unseal_fortress_gate",
                name = "攻破大门",
                desc = "解除乌堡大门的封印，打通前往大殿的正门通道",
                targetType = "interact_unseal_fortress",
                targetCount = 1,
                reward = nil,
            },
        },
    },
}

--- 封印数据
QuestData_ch2.SEALS = {
    fortress_gate = {
        questChain = "fortress_zone",
        sealTiles = {
            {x = 33, y = 39}, {x = 34, y = 39},
            {x = 33, y = 40}, {x = 34, y = 40},
            {x = 33, y = 41}, {x = 34, y = 41},
            {x = 33, y = 42}, {x = 34, y = 42},
            {x = 33, y = 43}, {x = 34, y = 43},
        },
        originalTile = TileTypes.TILE.FORTRESS_FLOOR,
        promptText = "大门被封印封锁",
        promptRange = 3.0,
    },
}

return QuestData_ch2
