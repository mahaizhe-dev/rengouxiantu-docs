-- ============================================================================
-- QuestData_ch4.lua - 第四章·八卦海 主线任务数据
-- 与第一、二、三章完全独立，由 QuestSystem.Init() 合并加载
-- 8步顺序任务：每个八卦阵击杀BOSS 10次 → 解锁下一个传送阵
-- ============================================================================

local TileTypes = require("config.TileTypes")

local QuestData_ch4 = {}

--- 区域主线任务链
QuestData_ch4.ZONE_QUESTS = {
    -- ── 八卦海主线 ──
    bagua_zone = {
        id = "bagua_zone",
        name = "八卦海主线",
        zone = "ch4_haven",              -- 任务所属区域（龟背岛）
        chapter = 4,                     -- 所属章节
        unlockSeal = nil,                -- 封印在步骤内逐步处理
        steps = {
            -- 主线1：坎·沉渊阵 → 击杀沈渊衣10次 → 解锁艮阵传送 → T7橙装3选1
            {
                id = "kill_kan_boss",
                name = "破坎阵",
                desc = "击败坎·沉渊阵的沈渊衣10次，解锁艮阵传送",
                targetType = "kan_boss",
                targetCount = 10,
                unlockSeal = "seal_ch4_gen",
                reward = {
                    type = "equipment_pick",
                    tier = 7,
                    quality = "orange",
                    count = 3,
                },
            },
            -- 主线2：艮·止岩阵 → 击杀岩不动10次 → 解锁震阵传送 → T8紫装3选1
            {
                id = "kill_gen_boss",
                name = "破艮阵",
                desc = "击败艮·止岩阵的岩不动10次，解锁震阵传送",
                targetType = "gen_boss",
                targetCount = 10,
                unlockSeal = "seal_ch4_zhen",
                reward = {
                    type = "equipment_pick",
                    tier = 8,
                    quality = "purple",
                    count = 3,
                },
            },
            -- 主线3：震·惊雷阵 → 击杀雷惊蛰10次 → 解锁巽阵传送 → 九转金丹+龙髓
            {
                id = "kill_zhen_boss",
                name = "破震阵",
                desc = "击败震·惊雷阵的雷惊蛰10次，解锁巽阵传送",
                targetType = "zhen_boss",
                targetCount = 10,
                unlockSeal = "seal_ch4_xun",
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "jiuzhuan_jindan", count = 1 },
                        { itemId = "dragon_marrow",   count = 1 },
                    },
                },
            },
            -- 主线4：巽·风旋阵 → 击杀风无痕10次 → 解锁离阵传送 → T8橙装3选1
            {
                id = "kill_xun_boss",
                name = "破巽阵",
                desc = "击败巽·风旋阵的风无痕10次，解锁离阵传送",
                targetType = "xun_boss",
                targetCount = 10,
                unlockSeal = "seal_ch4_li",
                reward = {
                    type = "equipment_pick",
                    tier = 8,
                    quality = "orange",
                    count = 3,
                },
            },
            -- 主线5：离·烈焰阵 → 击杀炎若晦10次 → 解锁坤阵传送 → T9紫装3选1
            {
                id = "kill_li_boss",
                name = "破离阵",
                desc = "击败离·烈焰阵的炎若晦10次，解锁坤阵传送",
                targetType = "li_boss",
                targetCount = 10,
                unlockSeal = "seal_ch4_kun",
                reward = {
                    type = "equipment_pick",
                    tier = 9,
                    quality = "purple",
                    count = 3,
                },
            },
            -- 主线6：坤·厚土阵 → 击杀厚德生10次 → 解锁兑阵传送 → T9橙装3选1
            {
                id = "kill_kun_boss",
                name = "破坤阵",
                desc = "击败坤·厚土阵的厚德生10次，解锁兑阵传送",
                targetType = "kun_boss",
                targetCount = 10,
                unlockSeal = "seal_ch4_dui",
                reward = {
                    type = "equipment_pick",
                    tier = 9,
                    quality = "orange",
                    count = 3,
                },
            },
            -- 主线7：兑·泽沼阵 → 击杀泽归墟10次 → 解锁乾阵传送 → 高级攻/防/生技能书3选1
            {
                id = "kill_dui_boss",
                name = "破兑阵",
                desc = "击败兑·泽沼阵的泽归墟10次，解锁乾阵传送",
                targetType = "dui_boss",
                targetCount = 10,
                unlockSeal = "seal_ch4_qian",
                reward = {
                    type = "consumable_pick",
                    items = { "book_atk_3", "book_def_3", "book_hp_3" },
                },
            },
            -- 主线8：乾·天罡阵 → 击杀司空正阳10次 → 高级蕴灵技能2选1
            {
                id = "kill_qian_boss",
                name = "破乾阵",
                desc = "击败乾·天罡阵的司空正阳10次，完成八卦海主线",
                targetType = "qian_boss",
                targetCount = 10,
                reward = {
                    type = "consumable_pick",
                    items = { "book_hpPerLv_3", "book_defPerLv_3" },
                },
            },
        },
    },
}

--- 封印数据 - 7个传送阵封印（坎阵免费开放，艮~乾需逐步解锁）
--- 每个封印覆盖传送NPC周围 2x2 瓦片，阻断通行并显示特效
QuestData_ch4.SEALS = {
    -- 艮阵传送 NPC (48.5, 34.5) → 中心瓦片 (48, 34)
    seal_ch4_gen = {
        questChain = "bagua_zone",
        sealTiles = {
            {x = 48, y = 34}, {x = 49, y = 34},
            {x = 48, y = 35}, {x = 49, y = 35},
        },
        originalTile = TileTypes.TILE.SEA_SAND,
        promptText = "艮阵封印未解除",
        promptRange = 2.5,
    },
    -- 震阵传送 NPC (47.5, 39.5) → 中心瓦片 (47, 39)
    seal_ch4_zhen = {
        questChain = "bagua_zone",
        sealTiles = {
            {x = 47, y = 39}, {x = 48, y = 39},
            {x = 47, y = 40}, {x = 48, y = 40},
        },
        originalTile = TileTypes.TILE.SEA_SAND,
        promptText = "震阵封印未解除",
        promptRange = 2.5,
    },
    -- 巽阵传送 NPC (48.5, 44.5) → 中心瓦片 (48, 44)
    seal_ch4_xun = {
        questChain = "bagua_zone",
        sealTiles = {
            {x = 48, y = 44}, {x = 49, y = 44},
            {x = 48, y = 45}, {x = 49, y = 45},
        },
        originalTile = TileTypes.TILE.SEA_SAND,
        promptText = "巽阵封印未解除",
        promptRange = 2.5,
    },
    -- 离阵传送 NPC (39.5, 45.5) → 中心瓦片 (39, 45)
    seal_ch4_li = {
        questChain = "bagua_zone",
        sealTiles = {
            {x = 39, y = 45}, {x = 40, y = 45},
            {x = 39, y = 46}, {x = 40, y = 46},
        },
        originalTile = TileTypes.TILE.SEA_SAND,
        promptText = "离阵封印未解除",
        promptRange = 2.5,
    },
    -- 坤阵传送 NPC (30.5, 44.5) → 中心瓦片 (30, 44)
    seal_ch4_kun = {
        questChain = "bagua_zone",
        sealTiles = {
            {x = 30, y = 44}, {x = 31, y = 44},
            {x = 30, y = 45}, {x = 31, y = 45},
        },
        originalTile = TileTypes.TILE.SEA_SAND,
        promptText = "坤阵封印未解除",
        promptRange = 2.5,
    },
    -- 兑阵传送 NPC (31.5, 39.5) → 中心瓦片 (31, 39)
    seal_ch4_dui = {
        questChain = "bagua_zone",
        sealTiles = {
            {x = 31, y = 39}, {x = 32, y = 39},
            {x = 31, y = 40}, {x = 32, y = 40},
        },
        originalTile = TileTypes.TILE.SEA_SAND,
        promptText = "兑阵封印未解除",
        promptRange = 2.5,
    },
    -- 乾阵传送 NPC (30.5, 34.5) → 中心瓦片 (30, 34)
    seal_ch4_qian = {
        questChain = "bagua_zone",
        sealTiles = {
            {x = 30, y = 34}, {x = 31, y = 34},
            {x = 30, y = 35}, {x = 31, y = 35},
        },
        originalTile = TileTypes.TILE.SEA_SAND,
        promptText = "乾阵封印未解除",
        promptRange = 2.5,
    },
}

return QuestData_ch4
