-- ============================================================================
-- QuestData_ch3.lua - 第三章·沙漠九寨 主线任务数据
-- 与第一、二章完全独立，由 QuestSystem.Init() 合并加载
-- ============================================================================

local TileTypes = require("config.TileTypes")

local QuestData_ch3 = {}

--- 区域主线任务链
QuestData_ch3.ZONE_QUESTS = {
    -- ── 沙漠九寨区域主线 ──
    sand_zone = {
        id = "sand_zone",
        name = "沙漠九寨主线",
        zone = "ch3_fort_9",             -- 任务NPC所在区域
        chapter = 3,                     -- 所属章节
        unlockSeal = nil,
        steps = {
            -- 主线1：攻破第八寨、第七寨 → 奖励：随机T5紫装3选1
            {
                id = "kill_fort_8_7",
                name = "扫平外围",
                desc = "攻破第八寨和第七寨，清除外围妖寨的威胁",
                targets = {
                    { targetType = "yao_king_8", targetCount = 1, name = "枯木妖王" },
                    { targetType = "yao_king_7", targetCount = 1, name = "岩蟾妖王" },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 5,
                    quality = "purple",
                    count = 3,
                },
            },
            -- 主线2：攻破第六寨 + 100个3章精英 → 宠物中级攻击/生命/防御 3选1
            {
                id = "kill_fort_6_elites_a",
                name = "深入腹地",
                desc = "攻破第六寨并消灭100个沙漠精英妖兵",
                targets = {
                    { targetType = "yao_king_6", targetCount = 1, name = "苍狼妖王" },
                    {
                        targetType = "sand_elite_outer", targetCount = 100, name = "沙漠精英",
                        targetAliases = { "sand_elite_mid", "sand_elite_inner" },
                    },
                },
                reward = {
                    type = "consumable_pick",
                    items = { "book_atk_2", "book_hp_2", "book_def_2" },
                },
            },
            -- 主线3：攻破第五寨、第四寨 → 奖励：随机T6紫装3选1
            {
                id = "kill_fort_5_4",
                name = "肃清妖患",
                desc = "攻破第五寨和第四寨，扫清沙漠腹地的妖寨",
                targets = {
                    { targetType = "yao_king_5", targetCount = 1, name = "赤甲妖王" },
                    { targetType = "yao_king_4", targetCount = 1, name = "蛇骨妖王" },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 6,
                    quality = "purple",
                    count = 3,
                },
            },
            -- 主线4：攻破第三寨 + 100个3章精英 → 宠物中级恢复/闪避/暴击 3选1
            {
                id = "kill_fort_3_elites_b",
                name = "斩妖除魔",
                desc = "攻破第三寨并消灭100个沙漠精英妖兵",
                targets = {
                    { targetType = "yao_king_3", targetCount = 1, name = "赤焰妖王" },
                    {
                        targetType = "sand_elite_outer", targetCount = 100, name = "沙漠精英",
                        targetAliases = { "sand_elite_mid", "sand_elite_inner" },
                    },
                },
                reward = {
                    type = "consumable_pick",
                    items = { "book_regen_2", "book_evade_2", "book_crit_2" },
                },
            },
            -- 主线5：攻破第二寨 + 100个3章精英 → 随机T7紫装3选1
            {
                id = "kill_fort_2_elites_c",
                name = "兵临城下",
                desc = "攻破第二寨并消灭100个沙漠精英妖兵，直逼黄天寨",
                targets = {
                    { targetType = "yao_king_2", targetCount = 1, name = "蜃妖王" },
                    {
                        targetType = "sand_elite_outer", targetCount = 100, name = "沙漠精英",
                        targetAliases = { "sand_elite_mid", "sand_elite_inner" },
                    },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 7,
                    quality = "purple",
                    count = 3,
                },
            },
            -- 主线6：手动解除第一寨封印（交互步骤）
            {
                id = "unseal_ch3_fort_1_gate",
                name = "解除封印",
                desc = "解除第一寨大门的封印，进入黄天寨挑战黄天大圣",
                targetType = "interact_unseal_ch3_fort_1_gate",
                targetCount = 1,
                reward = nil,
            },
        },
    },
}

--- 封印数据 - 第一寨四面入口
--- fort_1 坐标: (54,54)→(76,76), cx=65, cy=65, gapHalf=1
--- 入口缺口: 3格宽 (64,65,66)，只封最外层即可阻断通行
--- 每面 3 格 × 4 面 = 12 格
QuestData_ch3.SEALS = {
    ch3_fort_1_gate = {
        questChain = "sand_zone",
        sealTiles = {
            -- 北墙最外层 (wy=54)
            { x = 64, y = 54 }, { x = 65, y = 54 }, { x = 66, y = 54 },
            -- 南墙最外层 (wy=76)
            { x = 64, y = 76 }, { x = 65, y = 76 }, { x = 66, y = 76 },
            -- 西墙最外层 (wx=54)
            { x = 54, y = 64 }, { x = 54, y = 65 }, { x = 54, y = 66 },
            -- 东墙最外层 (wx=76)
            { x = 76, y = 64 }, { x = 76, y = 65 }, { x = 76, y = 66 },
        },
        originalTile = TileTypes.TILE.SAND_FLOOR,
        promptText = "第一寨大门被封印封锁",
        promptRange = 3.0,
    },
}

return QuestData_ch3
