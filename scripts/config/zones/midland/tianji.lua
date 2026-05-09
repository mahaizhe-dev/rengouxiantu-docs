-- ============================================================================
-- tianji.lua - 天机阁（左翼下方，与血煞盟纵向相连）
-- 坐标范围: (3,54)→(16,70)  13×16
-- 训练场:   (3,72)→(16,79)  13×7（南侧，间隔2格路）
-- ============================================================================

local tianji = {}

tianji.regions = {
    mz_tianji = { x1 = 3, y1 = 54, x2 = 16, y2 = 70, zone = "mz_tianji" },
    -- 训练场：天机阁南侧（间隔2格仙府长街，明确分隔）
    mz_tianji_training = { x1 = 3, y1 = 72, x2 = 16, y2 = 79, zone = "mz_tianji_training" },
}

-- NPC 位于藏宝阁前方（中央偏下）
tianji.npcs = {
    {
        id = "black_merchant",
        name = "大黑无天",
        subtitle = "星界财团·股东",
        x = 10, y = 63,
        icon = "npc_black_merchant.png",
        portrait = "Textures/npc_black_merchant.png",
        interactType = "black_merchant",
        zone = "mz_tianji",
        dialog = {
            "嘿嘿……有仙石的话，我这里什么都有。",
            "万界奇珍，概不还价。",
        },
    },
    {
        id = "yin_hunter",
        name = "胤",
        subtitle = "星界财团·股东",
        x = 8, y = 63,
        icon = "npc_yin.png",
        portrait = "Textures/npc_yin.png",
        interactType = "coming_soon",
        zone = "mz_tianji",
        dialog = {
            "……又来了一个。",
            "你找无天？他醉了，烂摊子全是我在收拾。",
            "仙石价格紊乱、账目对不上、还有一堆投诉……",
            "（他不耐烦地整理着手中的账簿）",
            "别挡路，没看到我很忙吗。",
        },
    },
    {
        id = "xianshi_note",
        name = "不起眼的小纸条",
        subtitle = "",
        x = 11, y = 64,
        icon = "npc_note.png",
        portrait = "Textures/npc_note.png",
        hideName = true,
        iconScale = 0.5,
        interactType = "xianshi_note",
        zone = "mz_tianji",
        dialog = {},
    },
}

tianji.spawns = {
    -- === 训练场假人（4个，间距足够大避免AOE误伤） ===
    { type = "training_dummy_0",    x = 5,  y = 74 },  -- 木桩假人（0护甲）
    { type = "training_dummy_500",  x = 14, y = 74 },  -- 铁甲假人（500护甲）
    { type = "training_dummy_1000", x = 5,  y = 78 },  -- 玄铁假人（1000护甲）
    { type = "training_dummy_2000", x = 14, y = 78 },  -- 金刚假人（2000护甲）
}

tianji.decorations = {
    -- === 天机阁主区域 (y54~70) ===
    -- 城门
    { type = "city_gate", x = 7,  y = 54, w = 7, h = 1, dir = "ns", label = "天机北门" },
    { type = "city_gate", x = 16, y = 57, w = 1, h = 7, dir = "ew", label = "天机东门" },

    -- ★ 核心地标：天机阁藏宝阁（4×4，左移1下移2）
    { type = "tianji_pavilion", x = 7, y = 59, w = 4, h = 4, label = "天机阁" },

    -- 藏宝阁前方（南侧）对称布局
    -- 黑商摊位（藏宝阁正前方偏右）
    { type = "merchant_stall", x = 11, y = 62, w = 3, h = 3, label = "黑商摊位" },
    -- 香炉（藏宝阁正前方偏左，与摊位对称）
    { type = "incense_burner", x = 6, y = 63 },

    -- 藏宝阁四角灯笼（紧邻建筑外侧）
    { type = "lantern", x = 6,  y = 59 },
    { type = "lantern", x = 11, y = 59 },
    { type = "lantern", x = 6,  y = 62 },
    { type = "lantern", x = 11, y = 62 },


    -- 下方装饰区
    -- 宝箱（角落）
    { type = "treasure_crate", x = 14, y = 67 },
    { type = "treasure_crate", x = 5,  y = 67 },
    -- 石碑（藏宝阁下方）
    { type = "stone_tablet", x = 10, y = 66, label = "天机碑" },
    -- 下方灯笼
    { type = "lantern", x = 5,  y = 69 },
    { type = "lantern", x = 14, y = 69 },
    -- 花卉点缀
    { type = "flower", x = 5,  y = 56 },
    { type = "flower", x = 14, y = 56 },
    { type = "flower", x = 8,  y = 65 },
    { type = "flower", x = 13, y = 65 },

    -- === 训练场区域 (y72~79) ===
    -- 演武场（居中）
    { type = "arena_ring", x = 8, y = 74, w = 4, h = 4, label = "演武场" },
    -- 训练场灯笼（四角）
    { type = "lantern", x = 4,  y = 73 },
    { type = "lantern", x = 15, y = 73 },
    { type = "lantern", x = 4,  y = 78 },
    { type = "lantern", x = 15, y = 78 },
}

tianji.generation = {
    fill = { tile = "CELESTIAL_FLOOR" },
    border = {
        tile = "CELESTIAL_WALL",
        minThick = 1, maxThick = 1,
        gaps = {
            { side = "north", from = 8,  to = 12 },  -- 天机北门（通血煞盟）
            { side = "east",  from = 58, to = 62 },  -- 天机东门（通青云城）
            { side = "east",  from = 75, to = 76 },  -- 训练场东出口（通南中路）
            { side = "south", from = 8,  to = 12 },  -- 天机南门（通训练场）
        },
        openSides = { "west" },  -- 西侧靠地图边缘
    },
}

return tianji
