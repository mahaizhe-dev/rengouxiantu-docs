-- ============================================================================
-- fort_9.lua - 第九寨·废寨（安全区 + 废墟，第三章入口）
-- 坐标: (8,8)→(23,23)  16×16
-- 上半区(y=8~15): 安全区，SAND_FLOOR，NPC/传送阵
-- 下半区(y=16~23): 废墟，DESERT，散落碎墙
-- ============================================================================

local DungeonConfig = require("config.DungeonConfig")
local _dc = DungeonConfig.GetDefault()

local fort_9 = {}

fort_9.regions = {
    ch3_fort_9 = { x1 = 8, y1 = 8, x2 = 23, y2 = 23, zone = "ch3_fort_9" },
}

fort_9.spawnPoint = { x = 15.5, y = 10.5 }

fort_9.npcs = {
    {
        id = "ch3_teleport_array", name = "传送法阵", subtitle = "跨章传送",
        x = 15, y = 10, icon = "🌀",
        interactType = "teleport_array", zone = "ch3_fort_9",
        isObject = true, label = "传送法阵",
        dialog = "传送法阵散发着金色沙尘般的光芒，可以将你传送回乌家堡营地。",
    },
    {
        id = "ch3_merchant", name = "装备商人", subtitle = "商店",
        x = 11, y = 12, icon = "🛒",
        portrait = "Textures/npc_equip_merchant.png",
        interactType = "sell_equip", zone = "ch3_fort_9",
        dialog = "万里黄沙中，好装备就是你的命！快来看看吧。",
    },
    {
        id = "ch3_alchemy", name = "炼丹炉", subtitle = "炼丹",
        x = 20, y = 12, icon = "🔥",
        portrait = "Textures/npc_alchemy_furnace.png",
        interactType = "alchemy", zone = "ch3_fort_9",
        dialog = "炼丹炉火焰跳动，可以在此炼制丹药。",
    },
    {
        id = "ch3_guide", name = "沙漠向导·风沙", subtitle = "主线",
        x = 15, y = 14, icon = "🧭",
        portrait = "Textures/npc_desert_guide.png",
        interactType = "village_chief", zone = "ch3_fort_9",
        questChain = "sand_zone",
        dialog = "这里曾是九寨之首……如今只剩废墟。妖王们各据一寨，互相倾轧。你若想平定黄沙，就从外围的寨子开始吧。",
    },
    {
        id = "seal_master_ch3", name = "封魔使·赤阳", subtitle = "封魔任务",
        x = 12, y = 14, icon = "🔮",
        portrait = "Textures/npc_exorcist.png",
        interactType = "seal_demon", chapter = 3, zone = "ch3_fort_9",
        dialog = "黄沙之下，妖气冲天。吾乃封魔谷使者赤阳，若你修为足够，可领取封魔任务，斩魔患、获灵韵与体魄丹。",
    },
    {
        id = "qingyun_envoy_ch3", name = "云霓", subtitle = "青云城使者",
        x = 19, y = 13, icon = "🏮",
        portrait = "Textures/npc_qingyun_envoy.png",
        interactType = "challenge_envoy", zone = "ch3_fort_9",
        challengeFaction = "qingyun",
        dialog = "青云之道，以根骨御万法。你可愿接受青云门的试炼？",
    },
    {
        id = "fengmodian_envoy_ch3", name = "凌战", subtitle = "封魔殿使者",
        x = 19, y = 11, icon = "🔮",
        portrait = "Textures/npc_fengmo_envoy.png",
        interactType = "challenge_envoy", zone = "ch3_fort_9",
        challengeFaction = "fengmo",
        dialog = "吾乃封魔殿少帅凌战。封魔之道，以己身镇万邪。你可敢接受我的试炼？",
    },
    {
        id = "warehouse_chest", name = "百宝箱", subtitle = "存取物品",
        x = 18, y = 10, icon = "📦", image = "image/warehouse_chest_20260331104459.png", imageScale = 1.0,
        interactType = "warehouse", zone = "ch3_fort_9", isObject = true,
        dialog = "需要存放什么物品吗？打开仓库即可安全保管。",
    },

    -- ── 多人副本入口（安全区北侧） ──
    {
        id = "ch3_dungeon_entrance", name = _dc.boss.name, subtitle = _dc.strings.subtitle,
        x = 15.5, y = 5.5, icon = "🌳",
        interactType = "dungeon_entrance", zone = "ch3_fort_9",
        isObject = true, label = _dc.strings.subtitle,
        dialog = _dc.strings.npcDesc,
    },
}

fort_9.decorations = {
    -- 安全区（上半）
    { type = "teleport_array", x = 15, y = 10, color = {200, 180, 100, 255} },
    { type = "tent", x = 10, y = 11, color = {180, 150, 90, 255} },
    { type = "tent", x = 20, y = 11, color = {175, 140, 85, 255} },
    { type = "campfire", x = 15, y = 12 },
    { type = "healing_spring", x = 11, y = 10, color = {80, 200, 170, 255}, label = "治愈之泉" },
    { type = "teleport_array", x = 15.5, y = 5.5, color = {220, 50, 50, 220} },  -- 世界BOSS入口（红色）
    -- 废墟区（下半）
    { type = "bone_pile", x = 12, y = 18 },
    { type = "bone_pile", x = 19, y = 20 },
    { type = "crack", x = 16, y = 19 },
    { type = "crack", x = 13, y = 21 },
    { type = "stone_tablet", x = 20, y = 22 },
}

-- 无怪物
fort_9.spawns = {}

fort_9.generation = {
    special = "sand_fortress_ruins",
    fill = { tile = "SAND_FLOOR" },
    -- 城墙由 BuildCh3SandFortresses() 统一构建，不使用数据驱动边界
}

return fort_9
