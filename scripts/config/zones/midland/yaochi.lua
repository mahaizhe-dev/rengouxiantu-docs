-- ============================================================================
-- yaochi.lua - 瑶池（右翼下方，与浩气宗纵向相连）
-- 坐标范围: (64,54)→(77,79)  14×26
-- 地形: 自然湖泊 + 湖心亭 + 栈道 + 南岸灵药园
-- ============================================================================

local yaochi = {}

-- ============================================================================
-- 区域定义
-- ============================================================================
yaochi.regions = {
    -- 主区域（陆地 + 水域 + 南岸灵药园）
    mz_yaochi = { x1 = 64, y1 = 54, x2 = 77, y2 = 79, zone = "mz_yaochi" },

    -- 自然湖体（多矩形叠加，形成大面积不规则水岸线）
    mz_yaochi_water_core  = { x1 = 66, y1 = 60, x2 = 76, y2 = 72, zone = "mz_yaochi" },
    mz_yaochi_water_north = { x1 = 68, y1 = 58, x2 = 75, y2 = 59, zone = "mz_yaochi" },
    mz_yaochi_water_ne    = { x1 = 69, y1 = 57, x2 = 74, y2 = 57, zone = "mz_yaochi" },
    mz_yaochi_water_east  = { x1 = 76, y1 = 62, x2 = 76, y2 = 71, zone = "mz_yaochi" },
    mz_yaochi_water_west  = { x1 = 65, y1 = 63, x2 = 65, y2 = 70, zone = "mz_yaochi" },
    mz_yaochi_water_south = { x1 = 67, y1 = 73, x2 = 75, y2 = 73, zone = "mz_yaochi" },
    mz_yaochi_water_sw    = { x1 = 66, y1 = 71, x2 = 66, y2 = 73, zone = "mz_yaochi" },
    mz_yaochi_water_se    = { x1 = 76, y1 = 72, x2 = 76, y2 = 73, zone = "mz_yaochi" },

    -- 南岸凹凸（打破直线）
    mz_yaochi_water_s_bump1 = { x1 = 69, y1 = 74, x2 = 71, y2 = 74, zone = "mz_yaochi" },  -- 栈道正南小湾
    mz_yaochi_water_s_bump2 = { x1 = 74, y1 = 74, x2 = 75, y2 = 74, zone = "mz_yaochi" },  -- 东南角延伸

    -- 东岸凹凸（打破直线）
    mz_yaochi_water_e_bump1 = { x1 = 77, y1 = 64, x2 = 77, y2 = 66, zone = "mz_yaochi" },  -- 东岸中段凸出
    mz_yaochi_water_e_notch  = { x1 = 76, y1 = 68, x2 = 76, y2 = 68, zone = "mz_yaochi" },  -- placeholder，下方陆地留缺口用

    -- 湖心亭（3×3 岛屿，CELESTIAL_FLOOR 可通行）
    mz_yaochi_island = { x1 = 69, y1 = 65, x2 = 71, y2 = 67, zone = "mz_yaochi" },
    -- 栈道（1 格宽，从北岸连通湖心亭）
    mz_yaochi_path = { x1 = 70, y1 = 57, x2 = 70, y2 = 64, zone = "mz_yaochi" },

    -- 悟道古树平台（湖畔，覆盖部分水域）
    mz_yaochi_tree_platform = { x1 = 69, y1 = 73, x2 = 71, y2 = 75, zone = "mz_yaochi" },
    -- 南岸药田地块
    mz_yaochi_herb_field = { x1 = 65, y1 = 76, x2 = 76, y2 = 79, zone = "mz_yaochi" },
}

-- ============================================================================
-- NPC / 刷怪
-- ============================================================================
yaochi.npcs = {
    {
        id = "yaochi_master",
        name = "瑶池仙姑",
        icon = "🧚",
        portrait = "Textures/npc_yaochi_master.png",
        subtitle = "洗髓修炼",
        x = 70, y = 66,
        interactType = "yaochi_wash",
        dialog = "瑶池灵水可炼化丹药为洗髓灵液，以灵液蕴养肉身、洗炼筋骨。",
    },
    {
        id = "dao_tree_mz",
        name = "瑶池·悟道古树",
        subtitle = "每日参悟",
        x = 70, y = 73,
        icon = "🌳",
        interactType = "dao_tree",
        isObject = true,
        zone = "mz_yaochi",
        label = "悟道树",
        dialog = "古树扎根瑶池灵脉，枝叶吞吐天地灵气。静坐树下，可悟大道至理。",
    },
}
yaochi.spawns = {}

-- ============================================================================
-- 装饰物
-- ============================================================================
yaochi.decorations = {
    -- 北岸（少量点缀）
    { type = "tree", x = 65, y = 55 },
    { type = "tree", x = 73, y = 55 },
    { type = "flower", x = 68, y = 56 },
    { type = "flower", x = 72, y = 56 },

    -- 西岸（少量绿植）
    { type = "tree", x = 65, y = 60 },
    { type = "tree", x = 65, y = 66 },
    { type = "flower", x = 65, y = 62 },

    -- 东岸（密植林带）
    { type = "tree", x = 77, y = 57 },
    { type = "tree", x = 77, y = 60 },
    { type = "tree", x = 77, y = 63 },
    { type = "tree", x = 77, y = 66 },
    { type = "tree", x = 77, y = 69 },
    { type = "tree", x = 77, y = 72 },

    -- 南岸（自然分布，错开避免直线感）
    { type = "tree", x = 66, y = 74 },
    { type = "flower", x = 67, y = 74 },
    { type = "tree", x = 68, y = 75 },
    { type = "flower", x = 72, y = 74 },
    { type = "tree", x = 73, y = 75 },
    { type = "tree", x = 76, y = 74 },
    { type = "flower", x = 75, y = 75 },

    -- 东岸凸出点装饰
    { type = "tree", x = 77, y = 67 },
    { type = "flower", x = 77, y = 68 },

    -- 湖心亭（洗髓交互点）
    { type = "celestial_pool", x = 69, y = 65, w = 3, h = 3, label = "瑶池洗髓" },

    -- 湖心亭四角灯笼（必须在 celestial_pool 之后，确保渲染在上层）
    { type = "lantern", x = 69, y = 65 },  -- 左上
    { type = "lantern", x = 71, y = 65 },  -- 右上
    { type = "lantern", x = 69, y = 67 },  -- 左下
    { type = "lantern", x = 71, y = 67 },  -- 右下

    -- === 悟道古树（湖畔，3×3）===
    { type = "dao_tree", x = 69, y = 72, w = 3, h = 3, label = "悟道古树" },
    -- 悟道树两侧花卉
    { type = "flower", x = 68, y = 73 },
    { type = "flower", x = 72, y = 73 },

    -- === 南岸灵药园 (y76~79) ===
    -- 整齐药田（4列 × 2排，对称布局）
    { type = "herb_garden", x = 65, y = 76, w = 2, h = 2, label = "灵药田" },
    { type = "herb_garden", x = 65, y = 78, w = 2, h = 2, label = "灵药田" },
    { type = "herb_garden", x = 68, y = 76, w = 2, h = 2, label = "灵药田" },
    { type = "herb_garden", x = 68, y = 78, w = 2, h = 2, label = "灵药田" },
    { type = "herb_garden", x = 71, y = 76, w = 2, h = 2, label = "灵药田" },
    { type = "herb_garden", x = 71, y = 78, w = 2, h = 2, label = "灵药田" },
    { type = "herb_garden", x = 74, y = 76, w = 2, h = 2, label = "灵药田" },
    { type = "herb_garden", x = 74, y = 78, w = 2, h = 2, label = "灵药田" },
    -- 灯笼（药园四角照明）
    { type = "lantern", x = 65, y = 76 },
    { type = "lantern", x = 76, y = 76 },
    { type = "lantern", x = 65, y = 79 },
    { type = "lantern", x = 76, y = 79 },
}

-- ============================================================================
-- 地图生成
-- ============================================================================
yaochi.generation = {
    -- 主填充：所有区域先铺 CELESTIAL_FLOOR
    fill = { tile = "CELESTIAL_FLOOR" },
    -- 边界墙（北侧和西侧有墙，东侧和南侧靠地图边缘开放）
    border = {
        tile = "CELESTIAL_WALL",
        minThick = 1, maxThick = 1,
        gaps = {
            { side = "north", from = 68, to = 72 },  -- 瑶池北门（通浩气宗）
            { side = "west",  from = 58, to = 62 },  -- 瑶池西门（通青云城）
        },
        openSides = { "east", "south" },
    },
    -- 子区域覆盖（按顺序：湖体 → 恢复岛和栈道）
    subRegions = {
        -- ① 自然湖体（多矩形叠加，形成大面积不规则水岸）
        { regionKey = "mz_yaochi_water_core",  fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_north", fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_ne",    fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_east",  fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_west",  fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_south", fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_sw",    fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_se",    fill = { tile = "WATER" } },
        -- 南岸 / 东岸自然凹凸
        { regionKey = "mz_yaochi_water_s_bump1", fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_s_bump2", fill = { tile = "WATER" } },
        { regionKey = "mz_yaochi_water_e_bump1", fill = { tile = "WATER" } },
        -- 东岸凹口（陆地嵌入水域，打破直线）
        { regionKey = "mz_yaochi_water_e_notch",  fill = { tile = "CELESTIAL_FLOOR" } },
        -- ② 恢复湖心岛和栈道（可通行平台）
        { regionKey = "mz_yaochi_path",        fill = { tile = "CELESTIAL_FLOOR" } },
        { regionKey = "mz_yaochi_island",      fill = { tile = "CELESTIAL_FLOOR" } },
        -- ③ 悟道古树平台（覆盖水域，湖畔陆地）
        { regionKey = "mz_yaochi_tree_platform", fill = { tile = "CELESTIAL_FLOOR" } },
        -- ④ 南岸药田地块
        { regionKey = "mz_yaochi_herb_field",    fill = { tile = "HERB_FIELD" } },
    },
}

return yaochi
