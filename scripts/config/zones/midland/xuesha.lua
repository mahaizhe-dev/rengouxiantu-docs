-- ============================================================================
-- xuesha.lua - 血煞盟（左翼上方势力，左桥通仙劫战场）
-- 坐标范围: (3,28)→(19,52)  16×24
-- 与天机阁纵向相连
-- ============================================================================

local xuesha = {}

xuesha.regions = {
    mz_xuesha = { x1 = 3, y1 = 28, x2 = 19, y2 = 52, zone = "mz_xuesha" },
}

xuesha.npcs = {
    {
        id = "xuesha_master",
        name = "殷无咎",
        subtitle = "血煞盟主·阵营挑战",
        x = 11, y = 40,
        icon = "🗡️",
        portrait = "Textures/npc_xuesha_master.png",
        interactType = "challenge_envoy",
        challengeFaction = "xuesha",
        zone = "mz_xuesha",
        dialog = {
            "嗯？你闻到了吗……空气中弥漫的煞气，正是磨炼的好时候。",
            "我血煞盟的弟子，向来以战养战。你若有胆量，便来试试。",
        },
    },
}
xuesha.spawns = {}

-- 血煞盟装饰物：3城门 + 演武场(地标) + 装饰
xuesha.decorations = {
    -- 城门（7格完整覆盖缺口：1填充墙+1石柱+3通道+1石柱+1填充墙）
    { type = "city_gate", x = 10, y = 28, w = 7, h = 1, dir = "ns", label = "血煞北门" },
    { type = "city_gate", x = 7,  y = 52, w = 7, h = 1, dir = "ns", label = "血煞南门" },
    { type = "city_gate", x = 19, y = 31, w = 1, h = 7, dir = "ew", label = "血煞东门" },
    -- 核心地标：演武场（区域中央）
    { type = "arena_ring", x = 8, y = 37, w = 4, h = 4, label = "演武场" },
    -- 环境装饰
    { type = "lantern", x = 6,  y = 31 },
    { type = "lantern", x = 16, y = 31 },
    { type = "lantern", x = 6,  y = 48 },
    { type = "lantern", x = 16, y = 48 },
    { type = "stone_tablet", x = 14, y = 42, label = "煞气碑" },
    { type = "tree", x = 5,  y = 34 },
    { type = "tree", x = 17, y = 45 },
    { type = "flower", x = 7,  y = 44 },
    { type = "flower", x = 15, y = 35 },
}

xuesha.generation = {
    fill = { tile = "CELESTIAL_FLOOR" },
    border = {
        tile = "CELESTIAL_WALL",
        minThick = 1, maxThick = 1,
        gaps = {
            { side = "north", from = 11, to = 15 },  -- 血煞北门（通左桥→仙劫战场）
            { side = "south", from = 8,  to = 12 },  -- 血煞南门（通天机阁）
            { side = "east",  from = 32, to = 36 },  -- 血煞东门（通封魔殿方向）
        },
        openSides = { "west" },  -- 西侧靠地图边缘，开放
    },
}

return xuesha
