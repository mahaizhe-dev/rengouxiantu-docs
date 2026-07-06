-- ============================================================================
-- QuestData_ch5.lua - 第五章·太虚之殇 主线任务 + 封印数据
-- 与其他章节完全独立，由 QuestSystem.Init() 合并加载
-- 主线 7 步：残破山门 → 剑心初悟 → 炉火淬锋 → 碑林悟道 → 栖剑归鞘 → 书阁破妄 → 剑宫封印
-- 封印：2 处白色（剑气城墙入口，独立任务链）+ 1 处红色（剑宫入口，主线关联）
-- ============================================================================

local TileTypes = require("config.TileTypes")

local QuestData_ch5 = {}

--- 区域主线任务链
QuestData_ch5.ZONE_QUESTS = {
    -- ── 太虚遗址主线（红色封印关联） ──
    taixu_zone = {
        id = "taixu_zone",
        name = "太虚遗址主线",
        zone = "ch5_front_camp",
        chapter = 5,
        unlockSeal = nil,
        steps = {
            -- 主线1：残破山门 — 击杀护山石傀×20 → T9橙装3选1
            {
                id = "break_broken_gate",
                name = "残破山门",
                desc = "击败裂山门遗址的护山石傀20次，打通前往宗门腹地的通路",
                targetType = "ch5_stone_guardian",
                targetCount = 20,
                reward = {
                    type = "equipment_pick",
                    tier = 9,
                    quality = "orange",
                    count = 3,
                },
            },
            -- 主线2：剑心初悟 — 击杀问剑长老×20 + 洗剑霜鸾×20 → T9青装3选1
            {
                id = "clear_sword_cold",
                name = "剑心初悟",
                desc = "击败问剑长老·裴千岳20次、洗剑霜鸾20次，感悟太虚剑意",
                targets = {
                    { targetType = "ch5_pei_qianyue", targetCount = 20, name = "问剑长老·裴千岳" },
                    { targetType = "ch5_frost_luan",   targetCount = 20, name = "洗剑霜鸾" },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 9,
                    quality = "cyan",
                    count = 3,
                },
            },
            -- 主线3：炉火淬锋 — 击杀铸剑长老·韩百炼×20 + 精英×100 → 渡劫丹×1 + 金砖×1
            {
                id = "clear_forge",
                name = "炉火淬锋",
                desc = "击败铸剑长老·韩百炼20次并消灭100个太虚精英残魂",
                targets = {
                    { targetType = "ch5_han_bailian", targetCount = 20, name = "铸剑长老·韩百炼" },
                    {
                        targetType = "ch5_sword_shadow", targetCount = 100, name = "太虚精英",
                        targetAliases = {
                            "ch5_ice_turtle", "ch5_forge_soldier",
                            "ch5_stele_phantom", "ch5_night_guard", "ch5_book_demon",
                        },
                    },
                },
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "dujie_dan",  count = 1 },
                        { itemId = "gold_brick", count = 1 },
                    },
                },
            },
            -- 主线4：碑林悟道 — 击杀守碑长老·石观澜×20 + 精英×100 → T10橙装3选1
            {
                id = "clear_stele",
                name = "碑林悟道",
                desc = "击败守碑长老·石观澜20次并消灭100个太虚精英残魂",
                targets = {
                    { targetType = "ch5_shi_guanlan", targetCount = 20, name = "守碑长老·石观澜" },
                    {
                        targetType = "ch5_sword_shadow", targetCount = 100, name = "太虚精英",
                        targetAliases = {
                            "ch5_ice_turtle", "ch5_forge_soldier",
                            "ch5_stele_phantom", "ch5_night_guard", "ch5_book_demon",
                        },
                    },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 10,
                    quality = "orange",
                    count = 3,
                },
            },
            -- 主线5：栖剑归鞘 — 击杀别院院主·宁栖梧×20 + 精英×100 → 渡劫丹×1 + 金砖×3
            {
                id = "clear_court",
                name = "栖剑归鞘",
                desc = "击败别院院主·宁栖梧20次并消灭100个太虚精英残魂",
                targets = {
                    { targetType = "ch5_ning_qiwu", targetCount = 20, name = "别院院主·宁栖梧" },
                    {
                        targetType = "ch5_sword_shadow", targetCount = 100, name = "太虚精英",
                        targetAliases = {
                            "ch5_ice_turtle", "ch5_forge_soldier",
                            "ch5_stele_phantom", "ch5_night_guard", "ch5_book_demon",
                        },
                    },
                },
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "dujie_dan",  count = 1 },
                        { itemId = "gold_brick", count = 3 },
                    },
                },
            },
            -- 主线6：书阁破妄 — 击杀藏经阁主·温素章×20 + 精英×100 → T10青装3选1
            {
                id = "clear_library",
                name = "书阁破妄",
                desc = "击败藏经阁主·温素章20次并消灭100个太虚精英残魂",
                targets = {
                    { targetType = "ch5_wen_suzhang", targetCount = 20, name = "藏经阁主·温素章" },
                    {
                        targetType = "ch5_sword_shadow", targetCount = 100, name = "太虚精英",
                        targetAliases = {
                            "ch5_ice_turtle", "ch5_forge_soldier",
                            "ch5_stele_phantom", "ch5_night_guard", "ch5_book_demon",
                        },
                    },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 10,
                    quality = "cyan",
                    count = 3,
                },
            },
            -- 主线7：剑宫封印 — 交互解除红色封印，进入太虚剑宫
            {
                id = "unseal_ch5_palace",
                name = "剑宫封印",
                desc = "前往剑宫入口，解除血色封印",
                targetType = "interact_unseal_ch5_palace",
                targetCount = 1,
                reward = nil,
            },
        },
    },

    -- ── 剑气城墙主线（白色封印关联，暂不开发） ──
    ch5_corridor_quest = {
        id = "ch5_corridor_quest",
        name = "剑气城墙封印",
        zone = "ch5_sword_corridor",
        chapter = 5,
        steps = {},  -- 暂不开发
    },
}

--- 封印数据
--- sealColor: "white" | "red" 用于渲染区分同章节不同风格
QuestData_ch5.SEALS = {
    -- ═══ 白色封印：剑气城墙入口（独立任务链，暂不开发） ═══

    -- 左路入口（别院→城墙桥 末段，cx=12，y=66~67）
    seal_ch5_corridor_left = {
        questChain = "ch5_corridor_quest",
        sealColor = "white",
        sealTiles = {
            {x = 11, y = 66}, {x = 12, y = 66}, {x = 13, y = 66},
            {x = 11, y = 67}, {x = 12, y = 67}, {x = 13, y = 67},
        },
        originalTile = TileTypes.TILE.CH5_BRIDGE,
        promptText = "剑气封印阻隔去路",
        promptRange = 3.0,
    },

    -- 右路入口（藏经阁→城墙桥 末段，cx=67，y=66~67）
    seal_ch5_corridor_right = {
        questChain = "ch5_corridor_quest",
        sealColor = "white",
        sealTiles = {
            {x = 66, y = 66}, {x = 67, y = 66}, {x = 68, y = 66},
            {x = 66, y = 67}, {x = 67, y = 67}, {x = 68, y = 67},
        },
        originalTile = TileTypes.TILE.CH5_BRIDGE,
        promptText = "剑气封印阻隔去路",
        promptRange = 3.0,
    },

    -- ═══ 四封剑台封印（祀剑池解锁） ═══

    -- 左上房：诛仙剑 (24,19,12×12,doorSide=rb → 右墙+下墙门)
    seal_ch5_boss_zhu = {
        questChain = "taixu_zone",
        manualOnly = true,
        sealColor = "red",
        sealTile = TileTypes.TILE.CH5_SEAL_WALL,
        sealTiles = {
            -- 右墙门洞 (2高×1厚，居中 y=24~25)
            {x = 35, y = 24}, {x = 35, y = 25},
            -- 下墙门洞 (2宽×1厚，居中 x=29~30)
            {x = 29, y = 30}, {x = 30, y = 30},
        },
        originalTile = TileTypes.TILE.CH5_PALACE_WHITE,
        promptText = "诛仙剑气封锁入口",
        promptRange = 3.0,
    },

    -- 右上房：陷仙剑 (45,19,12×12,doorSide=lb → 左墙+下墙门)
    seal_ch5_boss_xian = {
        questChain = "taixu_zone",
        manualOnly = true,
        sealColor = "blue",
        sealTile = TileTypes.TILE.CH5_SEAL_WALL_BLUE,
        sealTiles = {
            -- 左墙门洞 (2高×1厚，居中 y=24~25)
            {x = 45, y = 24}, {x = 45, y = 25},
            -- 下墙门洞 (2宽×1厚，居中 x=50~51)
            {x = 50, y = 30}, {x = 51, y = 30},
        },
        originalTile = TileTypes.TILE.CH5_PALACE_WHITE,
        promptText = "陷仙剑气封锁入口",
        promptRange = 3.0,
    },

    -- 左下房：戮仙剑 (24,35,12×12,doorSide=rt → 右墙+上墙门)
    seal_ch5_boss_lu = {
        questChain = "taixu_zone",
        manualOnly = true,
        sealColor = "green",
        sealTile = TileTypes.TILE.CH5_SEAL_WALL_GREEN,
        sealTiles = {
            -- 右墙门洞 (2高×1厚，居中 y=40~41)
            {x = 35, y = 40}, {x = 35, y = 41},
            -- 上墙门洞 (2宽×1厚，居中 x=29~30)
            {x = 29, y = 35}, {x = 30, y = 35},
        },
        originalTile = TileTypes.TILE.CH5_PALACE_WHITE,
        promptText = "戮仙剑气封锁入口",
        promptRange = 3.0,
    },

    -- 右下房：绝仙剑 (45,35,12×12,doorSide=lt → 左墙+上墙门)
    seal_ch5_boss_jue = {
        questChain = "taixu_zone",
        manualOnly = true,
        sealColor = "purple",
        sealTile = TileTypes.TILE.CH5_SEAL_WALL_PURPLE,
        sealTiles = {
            -- 左墙门洞 (2高×1厚，居中 y=40~41)
            {x = 45, y = 40}, {x = 45, y = 41},
            -- 上墙门洞 (2宽×1厚，居中 x=50~51)
            {x = 50, y = 35}, {x = 51, y = 35},
        },
        originalTile = TileTypes.TILE.CH5_PALACE_WHITE,
        promptText = "绝仙剑气封锁入口",
        promptRange = 3.0,
    },

    -- ═══ 红色封印：太虚剑宫入口（主线 taixu_zone 关联） ═══
    -- 合并左右入口为一个封印，由主线步骤7交互解除
    ch5_palace = {
        questChain = "taixu_zone",
        sealColor = "red",
        sealTiles = {
            -- 左入口（x=26~27，y=31~33）
            {x = 26, y = 31}, {x = 27, y = 31},
            {x = 26, y = 32}, {x = 27, y = 32},
            {x = 26, y = 33}, {x = 27, y = 33},
            -- 右入口（x=53~54，y=31~33）
            {x = 53, y = 31}, {x = 54, y = 31},
            {x = 53, y = 32}, {x = 54, y = 32},
            {x = 53, y = 33}, {x = 54, y = 33},
        },
        originalTile = TileTypes.TILE.CH5_PALACE_WHITE,
        promptText = "血色封印封锁剑宫",
        promptRange = 3.0,
    },
}

return QuestData_ch5
