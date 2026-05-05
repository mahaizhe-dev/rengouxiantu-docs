-- ============================================================================
-- haoqi.lua - 浩气宗（右翼上方势力，右桥通仙殒战场）
-- 坐标范围: (61,28)→(77,52)  16×24
-- 与瑶池纵向相连
-- ============================================================================

local haoqi = {}

haoqi.regions = {
    mz_haoqi = { x1 = 61, y1 = 28, x2 = 77, y2 = 52, zone = "mz_haoqi" },
}

haoqi.npcs = {
    {
        id = "haoqi_master",
        name = "陆天行",
        subtitle = "浩气宗主·阵营挑战",
        x = 69, y = 40,
        icon = "⚔️",
        portrait = "Textures/npc_haoqi_master.png",
        interactType = "challenge_envoy",
        challengeFaction = "haoqi",
        zone = "mz_haoqi",
        dialog = {
            "天地浩然，正气长存。吾儿青云虽年少，剑意已有几分火候。",
            "你若想磨炼自身，便去找青云试剑。他不会手下留情的。",
        },
    },
}
haoqi.spawns = {}

-- 浩气宗装饰物：3城门 + 剑碑(地标) + 装饰
haoqi.decorations = {
    -- 城门（7格完整覆盖缺口：1填充墙+1石柱+3通道+1石柱+1填充墙）
    { type = "city_gate", x = 64, y = 28, w = 7, h = 1, dir = "ns", label = "浩气北门" },
    { type = "city_gate", x = 67, y = 52, w = 7, h = 1, dir = "ns", label = "浩气南门" },
    { type = "city_gate", x = 61, y = 31, w = 1, h = 7, dir = "ew", label = "浩气西门" },
    -- 核心地标：剑碑（区域中央偏北）
    { type = "sword_stele", x = 68, y = 35, w = 2, h = 3, label = "浩然剑碑" },
    -- 环境装饰
    { type = "lantern", x = 64, y = 31 },
    { type = "lantern", x = 74, y = 31 },
    { type = "lantern", x = 64, y = 48 },
    { type = "lantern", x = 74, y = 48 },
    { type = "stone_tablet", x = 72, y = 40, label = "浩气碑" },
    { type = "tree", x = 63, y = 34 },
    { type = "tree", x = 75, y = 34 },
    { type = "tree", x = 63, y = 45 },
    { type = "tree", x = 75, y = 45 },
    { type = "flower", x = 66, y = 42 },
    { type = "flower", x = 72, y = 36 },
}

haoqi.generation = {
    fill = { tile = "CELESTIAL_FLOOR" },
    border = {
        tile = "CELESTIAL_WALL",
        minThick = 1, maxThick = 1,
        gaps = {
            { side = "north", from = 65, to = 69 },  -- 浩气北门（通右桥→仙殒战场）
            { side = "south", from = 68, to = 72 },  -- 浩气南门（通瑶池）
            { side = "west",  from = 32, to = 36 },  -- 浩气西门（通封魔殿方向）
        },
        openSides = { "east" },  -- 东侧靠地图边缘，开放
    },
}

return haoqi
