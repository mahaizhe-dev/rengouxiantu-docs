-- ============================================================================
-- fengmo.lua - 封魔殿（上方势力，紧邻裂谷，中桥通仙落战场）
-- 坐标范围: (30,28)→(50,40)  20×12
-- ============================================================================

local fengmo = {}

fengmo.regions = {
    mz_fengmo = { x1 = 30, y1 = 28, x2 = 50, y2 = 40, zone = "mz_fengmo" },
}

fengmo.npcs = {
    -- 中洲神器：天帝剑痕（位于区域中央）
    {
        id = "mz_divine_tiandi",
        name = "天帝剑痕",
        subtitle = "中洲神器",
        x = 40, y = 33,
        icon = "⚔",
        interactType = "divine_tiandi",
        zone = "mz_fengmo",
        isObject = true,
        label = "天帝剑痕",
        dialog = "一道深嵌于混沌石台上的古老剑痕，散发着浩瀚无垠的天帝威严，传说为上古天帝以无上剑意斩破虚空所留...",
    },
    -- 封魔殿少帅·凌战（阵营挑战）
    {
        id = "fengmo_master", name = "凌战", subtitle = "封魔殿少帅·阵营挑战",
        x = 40, y = 36, icon = "🔮",
        portrait = "Textures/npc_fengmo_envoy.png",
        interactType = "challenge_envoy",
        challengeFaction = "fengmo",
        zone = "mz_fengmo",
        dialog = {
            "封魔之道，在于以己身镇压万邪。封魔印加身之时，便是考验意志之际。",
            "你若能在封魔印的侵蚀下坚持战斗，便算通过本殿的试炼。",
        },
    },
}
fengmo.spawns = {}

-- 封魔殿装饰物：4城门 + 天帝剑痕神器(核心地标) + 灯笼/石碑/花
fengmo.decorations = {
    -- 城门（7格完整覆盖缺口：1填充墙+1石柱+3通道+1石柱+1填充墙）
    { type = "city_gate", x = 37, y = 28, w = 7, h = 1, dir = "ns", label = "封魔北门" },
    { type = "city_gate", x = 37, y = 40, w = 7, h = 1, dir = "ns", label = "封魔南门" },
    { type = "city_gate", x = 30, y = 31, w = 1, h = 7, dir = "ew", label = "封魔西门" },
    { type = "city_gate", x = 50, y = 31, w = 1, h = 7, dir = "ew", label = "封魔东门" },
    -- 核心地标：天帝剑痕神器（取代原封魔大阵，位于区域中央）
    { type = "divine_tiandi", x = 40, y = 33, label = "天帝剑痕" },
    -- 环境装饰
    { type = "lantern", x = 35, y = 30 },
    { type = "lantern", x = 45, y = 30 },
    { type = "lantern", x = 35, y = 38 },
    { type = "lantern", x = 45, y = 38 },
    { type = "stone_tablet", x = 33, y = 34, label = "封魔碑" },
    { type = "tree", x = 32, y = 30 },
    { type = "tree", x = 48, y = 30 },
    { type = "flower", x = 34, y = 37 },
    { type = "flower", x = 46, y = 37 },
}

fengmo.generation = {
    fill = { tile = "CELESTIAL_FLOOR" },
    border = {
        tile = "CELESTIAL_WALL",
        minThick = 1, maxThick = 1,
        gaps = {
            { side = "north", from = 38, to = 42 },  -- 封魔北门（通中桥→仙落战场）
            { side = "south", from = 38, to = 42 },  -- 封魔南门（通青云城）
            { side = "west",  from = 32, to = 36 },  -- 封魔西门（通血煞盟方向）
            { side = "east",  from = 32, to = 36 },  -- 封魔东门（通浩气宗方向）
        },
    },
}

return fengmo
