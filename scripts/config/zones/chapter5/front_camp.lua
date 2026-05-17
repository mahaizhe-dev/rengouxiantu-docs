-- ============================================================================
-- front_camp.lua - 太虚遗址前营（第五章出生点/安全区）
-- 坐标: x=25~55, y=4~12
-- 空间角色: 安全区 / 回营区 / 功能NPC / 前线营棚
-- 主材质: camp_dirt, camp_flagstone
-- ============================================================================

local front_camp = {}

front_camp.regions = {
    ch5_front_camp = { x1 = 27, y1 = 4, x2 = 53, y2 = 9, zone = "ch5_front_camp" },
}

front_camp.spawnPoint = { x = 40.5, y = 6.5 }

-- NPC
front_camp.npcs = {
    -- ── 传送法阵（中央） ──
    {
        id = "ch5_teleport_array", name = "传送法阵", subtitle = "跨章传送",
        x = 40, y = 7, icon = "🌀",
        interactType = "teleport_array", zone = "ch5_front_camp",
        isObject = true, label = "传送法阵",
        dialog = "传送法阵在残垣间闪烁微光，可以将你传送至其他章节。",
    },
    -- ── 九师弟·太虚末（主线NPC，出生点旁） ──
    {
        id = "ch5_quest_npc", name = "太虚末", subtitle = "区域主线",
        x = 40.5, y = 8.5, icon = "👦",
        portrait = "Textures/npc_taixu_mo.png",
        interactType = "village_chief", zone = "ch5_front_camp",
        questChain = "taixu_zone",
        dialog = "这里是太虚遗址……千年前宗门遭逢大劫，师兄们的残魂化为妖邪守护各处。请帮我击败他们，让太虚宗的亡魂得以安息！",
        dialogComplete = "太虚宗的亡魂终于安息了……剑宫封印已解，前方就是太虚剑宫核心。多谢恩人！",
    },
    -- ── 装备商人（左侧） ──
    {
        id = "ch5_merchant", name = "装备商人", subtitle = "商店",
        x = 31, y = 6, icon = "🛒",
        portrait = "Textures/npc_equip_merchant.png",
        interactType = "sell_equip", zone = "ch5_front_camp",
        dialog = "太虚遗址凶险万分，没有好装备可走不远！",
    },
    -- ── 炼丹炉（中偏左） ──
    {
        id = "ch5_alchemy", name = "炼丹炉", subtitle = "炼丹",
        x = 35, y = 6, icon = "🔥",
        portrait = "Textures/npc_alchemy_furnace.png",
        interactType = "alchemy", zone = "ch5_front_camp",
        dialog = "古炉内焰色幽蓝，可将灵韵淬炼为渡劫丹。",
    },
    -- ── 封魔使（右侧） ──
    {
        id = "seal_master_ch5", name = "封魔使·玄剑", subtitle = "暂未开放",
        x = 45, y = 6, icon = "🔮",
        portrait = "Textures/npc_exorcist.png",
        zone = "ch5_front_camp",
        dialog = "太虚遗址残魂被魔气侵蚀，已非昔日宗门弟子。吾乃封魔谷使者玄剑，专司净化魔魂。此地封魔阵尚在布置中，封魔任务暂未开放，请稍后再来。",
    },
    -- ── 百宝箱（右侧） ──
    {
        id = "warehouse_chest_ch5", name = "百宝箱", subtitle = "存取物品",
        x = 49, y = 6, icon = "📦", image = "image/warehouse_chest_20260331104459.png", imageScale = 1.0,
        interactType = "warehouse", zone = "ch5_front_camp", isObject = true,
        dialog = "需要存放什么物品吗？打开仓库即可安全保管。",
    },
}
front_camp.spawns = {}
front_camp.decorations = {
    -- 营地旗帜和武器架（复用已有类型）
    { type = "banner",      x = 30, y = 5 },
    { type = "banner",      x = 50, y = 5 },
    { type = "weapon_rack", x = 38, y = 5 },
    { type = "barrel",      x = 43, y = 5 },
    { type = "campfire",    x = 46, y = 7 },
    -- 传送法阵
    { type = "teleport_array", x = 40, y = 7, color = {100, 150, 255, 255} },
    -- 治愈之泉
    { type = "healing_spring", x = 40, y = 5, color = {80, 200, 170, 255}, label = "治愈之泉" },
}

front_camp.generation = {
    fill = { tile = "CH5_CAMP_DIRT" },
    border = {
        tile = "CH5_WALL",
        minThick = 1,
        maxThick = 2,

        openSides = { "bottom", "left", "right" },  -- 底部通向裂山门，左通问剑坪，右通寒池
    },
}

return front_camp
