-- ============================================================================
-- town.lua - 主城区域数据
-- ============================================================================

local town = {}

-- 区域范围
town.regions = {
    town = { x1 = 33, y1 = 33, x2 = 48, y2 = 48, zone = "town" },
    trial_area = { x1 = 38, y1 = 25, x2 = 43, y2 = 31, zone = "town" },  -- 青云试炼区（村北）
}

-- 主城围墙出入口（四个方向的通道中心坐标）
town.gates = {
    { x1 = 40, y1 = 33, x2 = 41, y2 = 33, dir = "north" },  -- 上方出口
    { x1 = 40, y1 = 48, x2 = 41, y2 = 48, dir = "south" },  -- 下方出口
    { x1 = 33, y1 = 40, x2 = 33, y2 = 41, dir = "west" },   -- 左方出口
    { x1 = 48, y1 = 40, x2 = 48, y2 = 41, dir = "east" },   -- 右方出口
}

-- 玩家出生点
town.spawnPoint = { x = 40.5, y = 40.5 }

-- NPC
town.npcs = {
    {
        id = "alchemy_furnace", name = "炼丹炉", subtitle = "炼制丹药",
        x = 38, y = 38, icon = "🔥",
        portrait = "Textures/npc_alchemy_furnace.png",
        interactType = "alchemy", zone = "town",
        dialog = "欢迎来到炼丹炉，将虎骨和山贼令牌交给我，我可以为你炼制练气丹。",
    },
    {
        id = "lingyun_merchant", name = "葫芦夫人", subtitle = "葫芦升级",
        x = 42, y = 38, icon = "🏺",
        portrait = "Textures/npc_lingyun_merchant.png",
        interactType = "shop", zone = "town",
        dialog = "想让葫芦更上一层楼？带上金币来找我，我能帮你淬炼葫芦，提升阶级。",
    },
    {
        id = "blacksmith", name = "锻造师", subtitle = "装备洗练",
        x = 36, y = 38, icon = "🔨",
        portrait = "Textures/npc_blacksmith.png",
        interactType = "forge", zone = "town",
        dialog = "我可以为你的装备洗练额外属性，每件装备可洗练一条。费用视装备阶级而定。",
    },
    {
        id = "equip_merchant", name = "装备商人", subtitle = "装备购买",
        x = 44, y = 40, icon = "🛒",
        portrait = "Textures/npc_equip_merchant.png",
        interactType = "sell_equip", zone = "town",
        dialog = "出售各类基础装备，物美价廉，适合初入江湖的侠客。",
    },
    {
        id = "bulletin_board", name = "公告栏", subtitle = "查看公告",
        x = 40, y = 39, icon = "📜",
        image = "edited_bulletin_board_20260303101038.png",
        interactType = "bulletin", isObject = true, zone = "town",
        label = "公告栏",
    },
    {
        id = "village_elder", name = "村长李老", subtitle = "区域主线",
        x = 40, y = 42, icon = "👴",
        portrait = "Textures/npc_village_elder.png",
        interactType = "village_chief", zone = "town",
        dialog = "年轻人，这片土地正被妖兽侵扰。替老夫清除它们，老夫便为你解开虎啸林的封印。",
    },
    {
        id = "teleport_array", name = "传送法阵", subtitle = "跨章传送",
        x = 41, y = 41, icon = "🌀",
        interactType = "teleport_array", zone = "town",
        isObject = true, label = "传送法阵",
        dialog = "传送法阵闪烁着幽蓝的灵光，连接着远方的修仙圣地。",
    },
    {
        id = "qingyun_trial", name = "青云试炼", subtitle = "试炼之塔",
        x = 40, y = 28, icon = "🗼",
        interactType = "trial_tower", isObject = true, zone = "town",
        label = "青云试炼",
        dialog = "青云试炼之塔，修仙者以武问道之所。\n逐层挑战，可获灵韵与金条。",
    },
    {
        id = "qingyun_envoy", name = "青云使·云裳", subtitle = "每日供奉",
        x = 42, y = 28, icon = "🏮",
        portrait = "Textures/npc_qingyun_envoy.png",
        interactType = "trial_offering", zone = "town",
        dialog = "吾乃青云城使者云裳，受命驻守试炼之塔。\n凡通过试炼者，每日可于此领取青云城供奉。",
    },
    {
        id = "dao_tree_ch1", name = "两界村·悟道树", subtitle = "每日参悟",
        x = 44, y = 36, icon = "🌳",
        interactType = "dao_tree", isObject = true, zone = "town",
        label = "悟道树",
        dialog = "村口古树通灵，凡人与修士的气息在此交汇。静坐树下，可感天地初开之理。",
    },
    {
        id = "seal_master_ch1", name = "封魔使·玄清", subtitle = "封魔任务",
        x = 38, y = 42, icon = "🔮",
        portrait = "Textures/npc_exorcist.png",
        interactType = "seal_demon", chapter = 1, zone = "town",
        dialog = "魔气渐浓，妖邪作乱。吾乃封魔谷使者玄清，专司封镇魔化之物。若你有足够修为，可领取封魔任务，击杀魔化妖兽可获灵韵与体魄丹。",
    },
    {
        id = "warehouse_chest", name = "百宝箱", subtitle = "存取物品",
        x = 44, y = 42, icon = "📦", image = "image/warehouse_chest_20260331104459.png", imageScale = 1.0,
        interactType = "warehouse", zone = "town", isObject = true,
        dialog = "需要存放什么物品吗？打开仓库即可安全保管。",
    },
    {
        id = "xuanwei", name = "玄微", subtitle = "天道问心",
        x = 36, y = 42, icon = "🔮",
        portrait = "Textures/npc_xuanwei.png",
        interactType = "dao_question", zone = "town",
        dialog = "天道有问……你可愿一听？",
    },
}

-- 装饰物
town.decorations = {
    -- 房屋（大型建筑）
    { type = "house",   x = 35, y = 35, w = 2, h = 2, color = {140, 100, 60, 255} },
    { type = "dao_tree", x = 44, y = 35, w = 2, h = 2, label = "悟道树" },
    { type = "house",   x = 35, y = 44, w = 2, h = 2, color = {130, 95, 65, 255} },
    { type = "house",   x = 44, y = 44, w = 2, h = 2, color = {150, 110, 70, 255} },

    -- 水井（中心广场，偏离十字路口避免阻挡出生点）
    { type = "well", x = 39, y = 42, color = {100, 110, 120, 255} },

    -- 树木
    { type = "tree", x = 34, y = 34, color = {50, 130, 50, 255} },
    { type = "tree", x = 47, y = 34, color = {60, 140, 55, 255} },
    { type = "tree", x = 34, y = 47, color = {55, 125, 45, 255} },
    { type = "tree", x = 47, y = 47, color = {45, 135, 50, 255} },
    { type = "tree", x = 37, y = 37, color = {50, 120, 50, 255} },
    { type = "tree", x = 43, y = 37, color = {60, 130, 55, 255} },

    -- 灯笼（沿道路）
    { type = "lantern", x = 39, y = 36 },
    { type = "lantern", x = 42, y = 36 },
    { type = "lantern", x = 39, y = 44 },
    { type = "lantern", x = 42, y = 44 },

    -- 治愈之泉（中心广场南侧）
    { type = "healing_spring", x = 41, y = 43, color = {80, 220, 180, 255}, label = "治愈之泉" },

    -- 花坛
    { type = "flower", x = 38, y = 41 },
    { type = "flower", x = 43, y = 41 },

    -- 木桶/货箱
    { type = "barrel", x = 37, y = 44 },
    { type = "barrel", x = 46, y = 35 },
    { type = "barrel", x = 37, y = 35 },

    -- 摊位（避开治愈之泉 41,43）
    { type = "stall", x = 42, y = 43, label = "杂货摊" },

    -- 传送法阵（村中心，十字路口附近）
    { type = "teleport_array", x = 41, y = 41, color = {100, 150, 255, 255} },

    -- 青云试炼塔（村北试炼区）
    { type = "trial_tower", x = 39.5, y = 25, w = 3, h = 3, label = "青云试炼" },
}

-- 连接道路（主城北门→试炼区）
town.roads = {
    { x1 = 40, y1 = 32, x2 = 41, y2 = 32, tile = "TOWN_ROAD" },
}

-- 地图生成配置（主城特殊处理：十字道路 + 围墙，由 GameMap 专门处理）
town.generation = {
    fill = { tile = "TOWN_FLOOR" },
    -- 主城有专门的围墙逻辑（BuildTownWalls），不使用通用 border
    -- 主城有十字道路，在 Generate() 中单独处理
    special = "town",  -- 标记为特殊处理
}

return town
