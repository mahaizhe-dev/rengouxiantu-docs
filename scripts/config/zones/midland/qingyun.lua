-- ============================================================================
-- qingyun.lua - 青云城（中洲中央主城，最大区域）
-- 坐标范围: (22,42)→(58,76)  36×34
-- 承载绝大多数功能 NPC（暂不填充，仅传送阵）
-- ============================================================================

local qingyun = {}

qingyun.regions = {
    mz_qingyun = { x1 = 22, y1 = 42, x2 = 58, y2 = 76, zone = "mz_qingyun" },
    -- 商业街中轴线：从青云塔南侧(y=50)到城南(y=74)，3格宽
    mz_qingyun_market = { x1 = 39, y1 = 50, x2 = 41, y2 = 74, zone = "mz_qingyun" },
    -- 东墙补强（x=58，分段：东门上方 / 东门下方~y69 / y74~79）
    mz_qingyun_ewall_n  = { x1 = 58, y1 = 53, x2 = 58, y2 = 57, zone = "mz_qingyun" },
    mz_qingyun_ewall_s  = { x1 = 58, y1 = 63, x2 = 58, y2 = 69, zone = "mz_qingyun" },
    mz_qingyun_ewall_s2 = { x1 = 58, y1 = 74, x2 = 58, y2 = 79, zone = "mz_qingyun" },
    -- 西墙补强（x=22，分段：西门上方 / 西门下方~y69 / y74~79）
    mz_qingyun_wwall_n  = { x1 = 22, y1 = 53, x2 = 22, y2 = 57, zone = "mz_qingyun" },
    mz_qingyun_wwall_s  = { x1 = 22, y1 = 63, x2 = 22, y2 = 69, zone = "mz_qingyun" },
    mz_qingyun_wwall_s2 = { x1 = 22, y1 = 74, x2 = 22, y2 = 79, zone = "mz_qingyun" },
}

-- 中洲出生点：青云城中央
qingyun.spawnPoint = { x = 40, y = 60 }

-- 仅一个跨章传送阵
qingyun.npcs = {
    {
        id = "mz_teleport_array", name = "传送法阵", subtitle = "跨章传送",
        x = 40, y = 60, icon = "🌀",
        interactType = "teleport_array", zone = "mz_qingyun",
        isObject = true, label = "传送法阵",
        dialog = "传送法阵散发着金色灵光，可以将你传送至其他章节。",
    },
    -- 功能 NPC：附灵师（萃取 + 附灵）— 商业街西侧
    {
        id = "temper_master", name = "附灵师", subtitle = "萃取·附灵",
        x = 37, y = 64, icon = "💎",
        portrait = "Textures/npc_temper_master.png",
        interactType = "temper", zone = "mz_qingyun",
        dialog = "淬炼之道，以精化灵。三件同源灵器，可萃出一枚附灵玉，为无套之器注入灵力。",
    },
    -- 功能 NPC：洗练师（装备洗练）— 商业街东侧
    {
        id = "forge_master_qy", name = "洗练师", subtitle = "装备洗练",
        x = 43, y = 64, icon = "🔨",
        portrait = "Textures/npc_forge_master_qy.png",
        interactType = "forge", zone = "mz_qingyun",
        dialog = "我可以为你的装备洗练额外属性，每件装备可洗练一条。费用视装备阶级而定。",
    },
    -- 功能 NPC：炼丹炉（阵营丹药）— 商业街西侧
    {
        id = "mz_alchemy", name = "炼丹炉", subtitle = "阵营丹药",
        x = 37, y = 67, icon = "🔥",
        portrait = "Textures/npc_alchemy_furnace.png",
        interactType = "alchemy", zone = "mz_qingyun",
        dialog = "古炉灵火不灭，可将阵营战场的精华炼制成永久增益丹药。",
    },
    -- 五一活动 NPC：天官降福 — 传送阵北侧
    {
        id = "npc_event_exchange", name = "天官降福", subtitle = "五一活动兑换",
        x = 40, y = 58, icon = "🧧",
        portrait = "Textures/npc_tianguan.png",
        interactType = "event_exchange", zone = "mz_qingyun",
        dialog = "五一佳节，天庭特赐福袋与灵韵。\n击败所有BOSS均有机会掉落活动信物，\n集齐可兑换珍稀奖励！",
        eventBound = true,
    },
    -- 镇狱塔入口 NPC — 青云塔贴图上
    {
        id = "prison_tower_entrance", name = "镇狱塔", subtitle = "青云镇狱",
        x = 40, y = 49, icon = "🗿",
        interactType = "prison_tower", zone = "mz_qingyun",
        isObject = true, label = "镇狱塔",
        dialog = "镇狱塔灵压深重，隐约可闻BOSS的怒吼……",
    },
    -- 阵营挑战 NPC：云无涯（青云城主）— 青云塔正前方
    {
        id = "qingyun_master", name = "云无涯", subtitle = "青云城主",
        x = 40, y = 51, icon = "🏔️",
        portrait = "Textures/npc_qingyun_master.png",
        interactType = "challenge_envoy",
        zone = "mz_qingyun",
        challengeFaction = "qingyun",
        dialog = "青云之道，在于根骨坚韧、心境澄明。来，让我看看你的修行成果。",
    },
}

-- 传送阵特效 + 商业街装饰
qingyun.decorations = {
    -- ========== 传送法阵（商业街中段核心，双层环绕装饰） ==========
    -- 传送阵本体（摆正到整数格）
    { type = "teleport_array", x = 40, y = 60, color = {220, 190, 100, 255} },
    -- 内圈：四角香炉（紧贴传送阵对角线）
    { type = "incense_burner", x = 39, y = 59 },
    { type = "incense_burner", x = 41, y = 59 },
    { type = "incense_burner", x = 39, y = 61 },
    { type = "incense_burner", x = 41, y = 61 },
    -- 外圈：四方向灯笼（与商业街灯笼列对齐，形成过渡）
    { type = "lantern", x = 38, y = 60 },
    { type = "lantern", x = 42, y = 60 },
    { type = "lantern", x = 40, y = 58 },
    { type = "lantern", x = 40, y = 62 },
    -- 城门（7格完整覆盖缺口：1填充墙+1石柱+3通道+1石柱+1填充墙）
    { type = "city_gate", x = 37, y = 42, w = 7, h = 1, dir = "ns", label = "青云北门" },
    { type = "city_gate", x = 22, y = 57, w = 1, h = 7, dir = "ew", label = "青云西门" },
    { type = "city_gate", x = 58, y = 57, w = 1, h = 7, dir = "ew", label = "青云东门" },
    -- 青云塔（标志性建筑，商业街尽头正中央，3×3）
    { type = "trial_tower", x = 39, y = 47, w = 3, h = 3, label = "青云塔" },

    -- ========== 商业街灯笼（南北中轴线两侧对称，每隔3格一对） ==========
    -- 从 y=51 到 y=72，每隔3格放置，x=38(西侧) x=42(东侧)
    { type = "lantern", x = 38, y = 51 },  { type = "lantern", x = 42, y = 51 },
    { type = "lantern", x = 38, y = 54 },  { type = "lantern", x = 42, y = 54 },
    { type = "lantern", x = 38, y = 57 },  { type = "lantern", x = 42, y = 57 },
    -- y=60 跳过（传送阵附近留空）
    { type = "lantern", x = 38, y = 63 },  { type = "lantern", x = 42, y = 63 },
    { type = "lantern", x = 38, y = 66 },  { type = "lantern", x = 42, y = 66 },
    { type = "lantern", x = 38, y = 69 },  { type = "lantern", x = 42, y = 69 },
    { type = "lantern", x = 38, y = 72 },  { type = "lantern", x = 42, y = 72 },

    -- ========== 城内其他装饰（保持对称） ==========
    -- 角落景观树
    { type = "tree", x = 28, y = 48 },
    { type = "tree", x = 52, y = 48 },
    { type = "tree", x = 28, y = 70 },
    { type = "tree", x = 52, y = 70 },
    -- 西侧水池 + 东侧石碑（传送阵两翼）
    { type = "pond", x = 30, y = 58, w = 3, h = 2 },
    { type = "stone_tablet", x = 50, y = 59, label = "中洲碑" },
    -- 花圃点缀
    { type = "flower", x = 30, y = 53 },
    { type = "flower", x = 50, y = 53 },
    { type = "flower", x = 30, y = 66 },
    { type = "flower", x = 50, y = 66 },
}

qingyun.spawns = {}

qingyun.generation = {
    fill = { tile = "CELESTIAL_FLOOR" },
    border = {
        tile = "CELESTIAL_WALL",
        minThick = 2, maxThick = 2,
        gaps = {
            { side = "north", from = 38, to = 42 },  -- 青云北门（通封魔殿）
            { side = "west",  from = 58, to = 62 },  -- 青云西门（通天机阁）
            { side = "east",  from = 58, to = 62 },  -- 青云东门（通瑶池）
            { side = "south", from = 38, to = 42 },  -- 青云南门（通修炼场）
        },
    },
    -- 商业街中轴线覆盖为特殊瓦片
    subRegions = {
        { regionKey = "mz_qingyun_market", fill = { tile = "MARKET_STREET" } },
        -- 东墙补强
        { regionKey = "mz_qingyun_ewall_n",  fill = { tile = "CELESTIAL_WALL" } },
        { regionKey = "mz_qingyun_ewall_s",  fill = { tile = "CELESTIAL_WALL" } },
        { regionKey = "mz_qingyun_ewall_s2", fill = { tile = "CELESTIAL_WALL" } },
        -- 西墙补强
        { regionKey = "mz_qingyun_wwall_n",  fill = { tile = "CELESTIAL_WALL" } },
        { regionKey = "mz_qingyun_wwall_s",  fill = { tile = "CELESTIAL_WALL" } },
        { regionKey = "mz_qingyun_wwall_s2", fill = { tile = "CELESTIAL_WALL" } },
    },
}

return qingyun
