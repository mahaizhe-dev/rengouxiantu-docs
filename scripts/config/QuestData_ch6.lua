-- ============================================================================
-- QuestData_ch6.lua - 第六章·两界村之影封印数据
-- 虎王试炼为未来副本区域：当前版本只展示封印，不提供任何解封入口。
-- ============================================================================

local TileTypes = require("config.TileTypes")

local QuestData_ch6 = {}

QuestData_ch6.ZONE_QUESTS = {
    shadow_village_zone = {
        id = "shadow_village_zone",
        name = "两界村之影",
        zone = "shadow_spawn_safe",
        chapter = 6,
        unlockSeal = nil,
        steps = {
            {
                id = "clear_shadow_entrance",
                name = "影门试锋",
                desc = "击败巡游天神·凌风30次，并清理100名巡逻仙兵，试探影入口外的天界封锁线",
                targets = {
                    { targetType = "ch6_lingfeng", targetCount = 30, name = "巡游天神·凌风" },
                    { targetType = "ch6_patrol_immortal_soldier", targetCount = 100, name = "巡逻仙兵" },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 11,
                    quality = "purple",
                    count = 3,
                },
            },
            {
                id = "trace_night_wilderness",
                name = "夜荒寻踪",
                desc = "击败夜游神·烛幽30次，并清理100名影游使，追查村北旧场渗出的暗影",
                targets = {
                    { targetType = "ch6_zhuyou", targetCount = 30, name = "夜游神·烛幽" },
                    { targetType = "ch6_shadow_wanderer", targetCount = 100, name = "影游使" },
                },
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "one_turn_tribulation_pill", count = 1 },
                        { itemId = "exp_pill_superior", count = 1 },
                        { itemId = "gold_brick", count = 1 },
                    },
                },
            },
            {
                id = "break_duanyue_mountain",
                name = "断岳开山",
                desc = "击败两界山神·断岳30次，并清理100尊山岭巨像，打通两界山脉的压制",
                targets = {
                    { targetType = "ch6_duanyue", targetCount = 30, name = "两界山神·断岳" },
                    { targetType = "ch6_mountain_colossus", targetCount = 100, name = "山岭巨像" },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 11,
                    quality = "orange",
                    count = 3,
                },
            },
            {
                id = "break_west_camp",
                name = "西营破阵",
                desc = "击败西大营天将·破军30次、西大营天将·镇垣30次，撕开西营上下一线的残存军阵",
                targets = {
                    { targetType = "ch6_pojun", targetCount = 30, name = "西大营天将·破军" },
                    { targetType = "ch6_zhenyuan", targetCount = 30, name = "西大营天将·镇垣" },
                },
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "one_turn_tribulation_pill", count = 1 },
                        { itemId = "exp_pill_superior", count = 1 },
                        { itemId = "gold_brick", count = 1 },
                    },
                },
            },
            {
                id = "break_east_camp",
                name = "东营破阵",
                desc = "击败东大营天将·青锋30次、东大营天将·雷策30次，瓦解东营内外两层防线",
                targets = {
                    { targetType = "ch6_qingfeng", targetCount = 30, name = "东大营天将·青锋" },
                    { targetType = "ch6_leice", targetCount = 30, name = "东大营天将·雷策" },
                },
                reward = {
                    type = "material_bundle",
                    items = {
                        { itemId = "one_turn_tribulation_pill", count = 1 },
                        { itemId = "exp_pill_superior", count = 1 },
                        { itemId = "gold_brick", count = 1 },
                    },
                },
            },
            {
                id = "suppress_heng_marshal",
                name = "哼元压营",
                desc = "击败哼元帅30次，并清理100名西营天兵，压住西营最后的反扑",
                targets = {
                    { targetType = "ch6_heng_marshal", targetCount = 30, name = "哼元帅" },
                    { targetType = "ch6_west_celestial_soldier", targetCount = 100, name = "西营天兵" },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 11,
                    quality = "cyan",
                    count = 3,
                },
            },
            {
                id = "suppress_ha_marshal",
                name = "哈元镇营",
                desc = "击败哈元帅30次，并清理100名东营天兵，压住东营最后的反扑",
                targets = {
                    { targetType = "ch6_ha_marshal", targetCount = 30, name = "哈元帅" },
                    { targetType = "ch6_east_celestial_soldier", targetCount = 100, name = "东营天兵" },
                },
                reward = {
                    type = "equipment_pick",
                    tier = 11,
                    quality = "cyan",
                    count = 3,
                },
            },
            {
                id = "unseal_ch6_shadow_village",
                name = "村心解封",
                desc = "回到村长处，解开中央两界村封印",
                targetType = "interact_unseal_ch6_shadow_village",
                targetCount = 1,
                reward = nil,
            },
        },
    },

    ch6_tiger_trial_future = {
        id = "ch6_tiger_trial_future",
        name = "虎王试炼封印",
        zone = "tiger_domain",
        chapter = 6,
        steps = {},
    },
}

QuestData_ch6.SEALS = {
    ch6_shadow_village = {
        questChain = "shadow_village_zone",
        sealColor = "red",
        sealTile = TileTypes.TILE.SEALED_GATE,
        sealTiles = {
            { x = 40, y = 33 }, { x = 41, y = 33 },
            { x = 40, y = 48 }, { x = 41, y = 48 },
            { x = 33, y = 40 }, { x = 33, y = 41 },
            { x = 48, y = 40 }, { x = 48, y = 41 },
        },
        originalTile = TileTypes.TILE.TOWN_ROAD,
        promptText = "中央两界村封印未解除",
        promptRange = 4.0,
    },

    seal_ch6_tiger_trial = {
        questChain = "ch6_tiger_trial_future",
        manualOnly = true,
        futureLocked = true,
        sealColor = "white",
        sealTile = TileTypes.TILE.SEALED_GATE,
        sealTiles = {
            { x = 67, y = 26 }, { x = 68, y = 26 },
            { x = 69, y = 26 }, { x = 70, y = 26 },
            { x = 67, y = 27 }, { x = 68, y = 27 },
            { x = 69, y = 27 }, { x = 70, y = 27 },
        },
        originalTile = TileTypes.TILE.CH6_TRIAL_STONE,
        promptText = "虎王试炼封印：暂未开启",
        promptRange = 3.0,
    },
}

return QuestData_ch6
