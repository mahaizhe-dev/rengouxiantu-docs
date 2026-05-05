-- ============================================================================
-- camp_a.lua - A区·联军临时营地（第二章出生点）
-- 坐标: (4,30)→(11,46)  7×16  （向内缩2格，略偏北）
-- ============================================================================

local camp_a = {}

camp_a.regions = {
    camp_a = { x1 = 4, y1 = 30, x2 = 11, y2 = 46, zone = "camp_a" },
}

camp_a.spawnPoint = { x = 7.5, y = 37.5 }

camp_a.npcs = {
    {
        id = "ch2_teleport_array", name = "传送法阵", subtitle = "跨章传送",
        x = 7, y = 37, icon = "🌀",
        interactType = "teleport_array", zone = "camp_a",
        isObject = true, label = "传送法阵",
        dialog = "传送法阵散发着幽蓝的光芒，可以将你传送回两界村。",
    },
    {
        id = "haoqi_envoy", name = "陆浩然", subtitle = "浩气宗使者",
        x = 10, y = 42, icon = "⚔️",
        interactType = "challenge_envoy", zone = "camp_a",
        portrait = "Textures/npc_haoqi_envoy.png",
        challengeFaction = "haoqi",
        dialog = "浩气长存，正道永昌。敢来切磋一番吗？",
    },

    {
        id = "xuesha_spy", name = "沈墨", subtitle = "血煞盟使者",
        x = 10, y = 38, icon = "🗡️",
        interactType = "challenge_envoy", zone = "camp_a",
        portrait = "Textures/npc_xuesha_spy.png",
        challengeFaction = "xuesha",
        dialog = "血煞之道，唯强者生。你有胆量接受挑战吗？",
    },

    {
        id = "ch2_merchant", name = "装备商人", subtitle = "商店",
        x = 5, y = 33, icon = "🛒",
        interactType = "sell_equip", zone = "camp_a",
        portrait = "Textures/npc_equip_merchant.png",
        dialog = "攻堡利器，应有尽有！法宝、丹药、护甲，童叟无欺。",
    },
    {
        id = "ch2_alchemy", name = "炼丹炉", subtitle = "炼丹",
        x = 10, y = 33, icon = "🔥",
        interactType = "alchemy", zone = "camp_a",
        portrait = "Textures/npc_alchemy_furnace.png",
        dialog = "炼丹炉火焰跳动，可以在此炼制丹药。",
    },
    {
        id = "wuyunzhu", name = "乌云珠", subtitle = "主线",
        x = 7, y = 43, icon = "💎",
        interactType = "village_chief", zone = "camp_a",
        portrait = "Textures/npc_wuyunzhu.png",
        questChain = "fortress_zone",
        dialog = "我是乌家堡逃出来的……堡主已经疯了，他用禁术将阵亡修士炼成骷髅兵。请帮我完成这些任务，拯救乌家堡！",
        dialogUnseal = "所有恶人都已伏诛！现在让我来解除乌堡大门的封印，打通正门！",
        dialogComplete = "感谢恩公……乌家堡的噩梦终于结束了。",
    },
    {
        id = "seal_master_ch2", name = "封魔使·玄冥", subtitle = "封魔任务",
        x = 5, y = 38, icon = "🔮",
        portrait = "Textures/npc_exorcist.png",
        interactType = "seal_demon", chapter = 2, zone = "camp_a",
        dialog = "此地魔气更甚前章，魔化之物实力远超寻常。吾乃封魔谷使者玄冥，若你修为足够，可领取封魔任务斩除魔患，获取灵韵与体魄丹。",
    },
    {
        id = "warehouse_chest", name = "百宝箱", subtitle = "存取物品",
        x = 5, y = 43, icon = "📦", image = "image/warehouse_chest_20260331104459.png", imageScale = 1.0,
        interactType = "warehouse", zone = "camp_a", isObject = true,
        dialog = "需要存放什么物品吗？打开仓库即可安全保管。",
    },
}

camp_a.decorations = {
    -- 帐篷
    { type = "tent", x = 5, y = 32, color = {150, 115, 65, 255} },
    { type = "tent", x = 10, y = 32, color = {145, 105, 60, 255} },
    -- 篝火
    { type = "campfire", x = 7, y = 35 },
    -- 传送法阵
    { type = "teleport_array", x = 7, y = 37, color = {100, 150, 255, 255} },
    -- 治愈之泉
    { type = "healing_spring", x = 9, y = 44, color = {80, 200, 170, 255}, label = "治愈之泉" },
}

camp_a.spawns = {}

camp_a.generation = {
    fill = { tile = "CAMP_DIRT" },
}

return camp_a
