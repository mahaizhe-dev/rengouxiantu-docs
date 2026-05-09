-- ============================================================================
-- GameConfig.lua - 全局游戏常量配置
-- ============================================================================

local GameConfig = {}

-- GM 调试开关（发布正式版前改为 false）
GameConfig.GM_ENABLED = false
GameConfig.GM_SHOW_COORDS = false  -- GM：鼠标悬停显示瓦片坐标

-- 多人副本功能总开关（Kill Switch）
-- 设为 false 可完全禁用副本功能，不影响游戏本体
GameConfig.DUNGEON_ENABLED = false

-- 游戏代码版本号（每次发版递增，用于版本守卫和前向校验）
-- 规则：纯整数，比较简单；每次改动存档结构或重大更新时 +1
GameConfig.CODE_VERSION = 4
GameConfig.DISPLAY_VERSION = "v1.9.4"

-- 地图设置
GameConfig.TILE_SIZE = 128         -- 每个瓦片的逻辑像素大小（基准值，不要直接用于渲染）
GameConfig.MAP_WIDTH = 80          -- 地图宽度（瓦片数）
GameConfig.MAP_HEIGHT = 80         -- 地图高度（瓦片数）

-- 相机缩放（0.5~1.5，默认0.75 拉远视角；1.0=原始大小）
GameConfig.CAMERA_ZOOM = 0.75

-- 移动速度（瓦片/秒）
GameConfig.PLAYER_SPEED = 4.0
GameConfig.PET_SPEED = 5.0         -- 宠物速度略快于玩家以便追赶
GameConfig.MONSTER_SPEED = 1.5     -- 怪物巡逻速度
GameConfig.MONSTER_CHASE_SPEED = 3.0 -- 怪物追击速度

-- 战斗相关
GameConfig.AUTO_ATTACK_INTERVAL = 1.0  -- 自动攻击间隔（秒）
GameConfig.AGGRO_RANGE = 4.0           -- 怪物仇恨范围（瓦片）
GameConfig.DEAGGRO_RANGE = 8.0         -- 怪物脱离仇恨范围
GameConfig.ATTACK_RANGE = 1.5          -- 攻击距离（瓦片）

-- 领地栓绳（怪物距出生点的最大追击距离）
GameConfig.LEASH_RADIUS = {
    normal       = 6,
    elite        = 10,
    boss         = 16,
    king_boss    = 20,
    emperor_boss = 25,
    saint_boss   = 999, -- 副本BOSS不栓绳（与 DungeonClient leashRadius=999 一致）
}
GameConfig.RETURN_SPEED_MULT = 1.5     -- 回巢加速倍率
GameConfig.HEAL_INTERVAL = 1           -- 脱战回血间隔（秒）
GameConfig.HEAL_PCT = 0.01             -- 每次回血比例（1%最大生命）

-- 卡住检测与BOSS瞬移
GameConfig.STUCK_THRESHOLD = 5.0       -- 判定卡住时间（秒）
GameConfig.STUCK_CHECK_INTERVAL = 0.5  -- 检测间隔（秒）
GameConfig.STUCK_MOVE_THRESHOLD = 0.3  -- 检测周期内最小移动距离（瓦片）

GameConfig.PET_ATTACK_RANGE = 1.2
GameConfig.LOOT_PICKUP_RANGE = 1.0     -- 拾取距离
GameConfig.PET_PICKUP_RANGE = 2.5      -- 宠物拾取范围（T1解锁）
GameConfig.PET_PICKUP_DELAY = 2.0      -- 掉落物落地多久后宠物才会去捡（秒）
GameConfig.PET_PICKUP_TIMEOUT = 3.0    -- 宠物跑向掉落物超时（秒，防卡墙）
GameConfig.NPC_INTERACT_RANGE = 1.2    -- NPC交互距离（瓦片）

-- 宠物基础
GameConfig.PET_FOLLOW_DISTANCE = 1.5   -- 宠物跟随距离
GameConfig.PET_TELEPORT_DISTANCE = 10  -- 超过此距离瞬移到玩家身边
GameConfig.PET_REVIVE_TIME = 30        -- 宠物死亡后复活时间（秒）

-- 宠物阶级配置
GameConfig.PET_TIERS = {
    [0] = { name = "幼犬", icon = "🐕", maxLevel = 20, syncRate = 0.20 },
    [1] = { name = "灵犬", icon = "🐕", maxLevel = 40, syncRate = 0.30 },
    [2] = { name = "妖犬", icon = "🐺", maxLevel = 60, syncRate = 0.40 },
    [3] = { name = "灵兽", icon = "🦁", maxLevel = 80, syncRate = 0.50 },
    [4] = { name = "圣兽", icon = "🐲", maxLevel = 100, syncRate = 0.60 },
}

-- 宠物突破消耗（灵韵 + 对应阶级灵兽丹）
GameConfig.PET_BREAKTHROUGH = {
    [1] = { lingYun = 30,   pillId = "spirit_pill",   pillCount = 10 },
    [2] = { lingYun = 300,  pillId = "spirit_pill_2",  pillCount = 20 },
    [3] = { lingYun = 1500, pillId = "spirit_pill_3",  pillCount = 30 },
    [4] = { lingYun = 5000, pillId = "spirit_pill_4",  pillCount = 40 },
}

-- 练气丹炼制消耗
GameConfig.QI_PILL_COST = 10  -- 灵韵/颗

-- 宠物基础属性（1级）
GameConfig.PET_BASE = {
    maxHp = 40,
    atk = 5,
    def = 2,
}

-- 宠物每级固定成长
GameConfig.PET_GROWTH = {
    maxHp = 20,
    atk = 2,
    def = 2,
}

-- 宠物经验表
GameConfig.PET_EXP_TABLE = {
    -- Tier 0: Lv.1-20 (手调早期快速升级区, 累计 19,400)
    [1] = 0,     [2] = 120,   [3] = 300,   [4] = 520,   [5] = 800,
    [6] = 1100,  [7] = 1500,  [8] = 1950,  [9] = 2500,  [10] = 3200,
    [11] = 4000, [12] = 4900, [13] = 5400, [14] = 6800, [15] = 8400,
    [16] = 10200,[17] = 12200,[18] = 14400,[19] = 16800,[20] = 19400,
    -- Tier 1: Lv.21-40 (等差递增, 阶段 165,600)
    [21] = 22400,[22] = 25800,[23] = 29600,[24] = 33800,[25] = 38400,
    [26] = 43400,[27] = 48800,[28] = 54600,[29] = 60800,[30] = 67400,
    [31] = 74800,[32] = 83000,[33] = 92000,[34] = 102000,[35] = 113000,
    [36] = 125000,[37] = 138000,[38] = 152000,[39] = 168000,[40] = 185000,
    -- Tier 2: Lv.41-60 (10%增长, 阶段 1,047,000)
    [41] = 204000, [42] = 225000, [43] = 248000, [44] = 273000, [45] = 300000,
    [46] = 330000, [47] = 363000, [48] = 399000, [49] = 438000, [50] = 481000,
    [51] = 528000, [52] = 580000, [53] = 637000, [54] = 700000, [55] = 769000,
    [56] = 845000, [57] = 928000, [58] = 1020000,[59] = 1121000,[60] = 1232000,
    -- Tier 3: Lv.61-80 (10%增长, 阶段 7,001,000)
    [61] = 1354000, [62] = 1488000, [63] = 1636000, [64] = 1798000, [65] = 1977000,
    [66] = 2174000, [67] = 2390000, [68] = 2628000, [69] = 2890000, [70] = 3178000,
    [71] = 3495000, [72] = 3844000, [73] = 4228000, [74] = 4650000, [75] = 5114000,
    [76] = 5625000, [77] = 6187000, [78] = 6805000, [79] = 7485000, [80] = 8233000,
    -- Tier 4: Lv.81-100 (10%→5%递降成长率, 阶段 37,547,000)
    [81] = 9056000,  [82] = 9959000,  [83] = 10947000, [84] = 12026000, [85] = 13202000,
    [86] = 14480000, [87] = 15866000, [88] = 17365000, [89] = 18982000, [90] = 20722000,
    [91] = 22590000, [92] = 24591000, [93] = 26729000, [94] = 29008000, [95] = 31431000,
    [96] = 34001000, [97] = 36720000, [98] = 39589000, [99] = 42609000, [100] = 45780000,
}

-- 宠物食物定义
GameConfig.PET_FOOD = {
    meat_bone     = { name = "肉骨头", icon = "🦴", exp = 20,  sellPrice = 5,   quality = "white", desc = "普通的肉骨头，散发着淡淡肉香。\n用途：喂食宠物，恢复少量经验。" },
    spirit_meat   = { name = "灵肉",   icon = "🥩", exp = 80,  sellPrice = 25,  quality = "green", desc = "蕴含灵气的精炼兽肉，品质上乘。\n用途：喂食宠物，恢复可观经验。" },
    immortal_bone = { name = "仙骨",   icon = "✨", exp = 300, sellPrice = 100, quality = "purple", desc = "远古仙兽遗骨，蕴藏强大灵力。\n用途：喂食宠物，恢复大量经验。" },
    beast_meat    = { name = "灵兽肉", icon = "🍖", exp = 150, sellPrice = 60,  quality = "blue",   desc = "灵兽身上的精华肉块，灵气充沛。\n用途：喂食宠物，恢复较多经验。" },
    demon_essence = { name = "妖兽精华", icon = "🔥", exp = 800, sellPrice = 300, quality = "orange", desc = "强大妖兽体内凝结的精华，蕴含磅礴灵力。\n用途：喂食宠物，恢复海量经验。" },
    dragon_marrow = { name = "龙髓", icon = "🐉", exp = 3000, sellPrice = 1000, quality = "red", desc = "远古龙族脊髓凝结的精华，蕴含毁天灭地之力。\n用途：喂食宠物，恢复惊人经验。" },
}

-- 灵兽丹（突破材料）
GameConfig.PET_MATERIALS = {
    spirit_pill = { name = "灵兽丹", icon = "icon_spirit_pill.png", sellPrice = 300, quality = "purple", desc = "以百草灵药炼制而成的丹药。\n用途：宠物1阶突破的必需材料。" },
    spirit_pill_2 = { name = "灵兽丹·贰", icon = "icon_spirit_pill_2.png", sellPrice = 1000, quality = "purple", desc = "以珍稀灵药炼制的高阶丹药。\n用途：宠物2阶突破的必需材料。" },
    spirit_pill_3 = { name = "灵兽丹·叁", icon = "icon_spirit_pill_3.png", sellPrice = 3000, quality = "orange", desc = "以天材地宝炼制的极品丹药。\n用途：宠物3阶突破的必需材料。" },
    spirit_pill_4 = { name = "灵兽丹·肆", icon = "icon_spirit_pill_4.png", sellPrice = 10000, quality = "red", desc = "以万年灵药炼制的仙品丹药，丹纹隐现。\n用途：宠物4阶突破的必需材料。\n获取：八卦海·龙域BOSS掉落" },
    qi_pill = { name = "练气丹", icon = "icon_qi_pill.png", sellPrice = 0, quality = "purple", desc = "以灵韵凝炼而成的修炼丹药。\n用途：突破修炼境界的必需品。\n炼制：10灵韵 → 1颗\n多余丹药可在瑶池化为灵液，用于洗髓修炼。" },
    zhuji_pill = { name = "筑基丹", icon = "icon_zhuji_pill.png", sellPrice = 0, quality = "orange", desc = "极为珍稀的筑基丹药，蕴含天地灵气。\n用途：突破筑基境界的必需品。\n获取：击败乌万仇、乌万海（1%掉率）\n多余丹药可在瑶池化为灵液，用于洗髓修炼。" },
    jindan_sand = { name = "金丹沙", icon = "icon_jindan_sand.png", sellPrice = 0, quality = "orange", desc = "蕴含金丹之力的灵沙，修炼突破的珍贵材料。\n用途：突破金丹境界的必需品。\n价值：1颗 = 100灵韵\n多余丹药可在瑶池化为灵液，用于洗髓修炼。" },
    yuanying_fruit = { name = "元婴果", icon = "icon_yuanying_fruit.png", sellPrice = 0, quality = "orange", desc = "蕴含元婴之力的灵果，散发金色荧光。\n用途：突破元婴境界的必需品。\n价值：1颗 = 100灵韵\n多余丹药可在瑶池化为灵液，用于洗髓修炼。" },
    exp_pill = { name = "修炼果", icon = "icon_exp_pill.png", sellPrice = 0, quality = "blue", desc = "蕴含灵气的修炼灵果，吸收后可获得大量修炼经验。\n用途：使用后获得10000点经验。\n限制：每次使用1颗，经验达到境界上限时无法使用。" },
    -- 封魔系统：体魄丹（永久+1体魄，上限50）
    physique_pill = { name = "体魄丹", icon = "💊", sellPrice = 0, quality = "purple", desc = "封魔谷秘制的丹药，服用后可永久强化体魄。\n用途：使用后永久+1体魄（上限50）。\n获取：每日封魔任务固定奖励（1枚/天）。" },
    -- 炼丹材料
    tiger_bone = { name = "虎骨", icon = "icon_tiger_bone.png", sellPrice = 1000, quality = "orange", desc = "虎王体内精炼的坚骨，蕴含猛虎之力。\n用途：炼制虎骨丹的必需材料。\n获取：击败虎王（5%掉率）" },
    snake_fruit = { name = "灵蛇果", icon = "icon_snake_fruit.png", sellPrice = 1000, quality = "orange", desc = "蛇妖巢穴中孕育的灵果，散发幽绿荧光。\n用途：炼制灵蛇丹的必需材料。\n获取：击败蛇妖·碧鳞（3%掉率）" },
    diamond_wood = { name = "金刚木", icon = "icon_diamond_wood.png", sellPrice = 1000, quality = "orange", desc = "坚硬如铁的灵木，据说吸收了天地精华。\n用途：炼制金刚丹的必需材料。\n获取：击败乌天南、乌地北（3%掉率）" },
    wind_eroded_grass = { name = "风蚀草", icon = "🌿", sellPrice = 1000, quality = "orange", desc = "沙漠中被风沙打磨千年的灵草，韧如精钢。\n用途：炼制千锤百炼丹的材料。\n获取：沙漠九寨怪物掉落" },
    lingyun_fruit = { name = "灵韵果", icon = "🍇", sellPrice = 0, quality = "orange", desc = "八卦海灵脉孕育的奇果，咬破果皮，灵韵四溢。\n用途：使用后获得50灵韵（不可出售）。\n获取：第四章BOSS掉落" },
    -- 高阶境界突破材料
    jiuzhuan_jindan = { name = "九转金丹", icon = "icon_jiuzhuan_jindan.png", sellPrice = 0, quality = "red", desc = "传说中的仙丹，需九次淬炼方成，蕴含无上仙力。\n用途：化神·合体境界突破的必需品。\n炼制：500灵韵 → 1颗（第四章炼丹炉）\n多余丹药可在瑶池化为灵液，用于洗髓修炼。" },
    dujie_dan = { name = "渡劫丹", icon = "icon_dujie_dan.png", sellPrice = 0, quality = "red", desc = "以九天雷髓与万年灵液淬炼而成的极品仙丹，丹中隐现雷纹。\n用途：大乘及以上境界突破的必需品。\n获取：暂未开放\n多余丹药可在瑶池化为灵液，用于洗髓修炼。" },
    -- 纯卖钱物品
    gold_bar = { name = "金条", icon = "icon_gold_bar.png", sellPrice = 1000, quality = "orange", desc = "沉甸甸的金条，闪耀着诱人的光泽。\n用途：出售给商人换取金币。" },
    gold_brick = { name = "金砖", icon = "icon_gold_bar.png", sellPrice = 100000, quality = "cyan", desc = "由万年灵金铸炼而成的实心金砖，沉如磐石，金光内敛。\n用途：出售给商人换取大量金币。" },
    -- 挑战系统货币
    wubao_token = { name = "乌堡令", icon = "🏷️", sellPrice = 100, quality = "blue", desc = "乌堡势力的信物，散发着阴冷的气息。\n用途：向浩气宗或血煞盟使者上交，解锁切磋挑战。\n售价：100金币" },
    sha_hai_ling = { name = "沙海令", icon = "🏜️", sellPrice = 100, quality = "blue", desc = "沙漠九寨的通行令牌，散发着炽热的气息。\n用途：向浩气宗或血煞盟使者上交，解锁沙海试炼。\n售价：100金币" },
    taixu_token = { name = "太虚令", icon = "🔱", sellPrice = 100, quality = "blue", desc = "太虚宗上古令牌，蕴含修补海神柱的灵力。\n用途：修复和升级海神柱，开启四兽岛传送。\n获取：八卦阵怪物掉落。" },
    -- 令牌盒（100令牌+100灵韵→1盒，使用获得100令牌）
    wubao_token_box = { name = "乌堡令盒", icon = "📦", sellPrice = 0, quality = "purple", desc = "封装了100枚乌堡令的锦盒，散发幽冷气息。\n用途：使用后获得100枚乌堡令。\n炼制：100乌堡令 + 100灵韵（第二章炼丹炉）" },
    sha_hai_ling_box = { name = "沙海令盒", icon = "📦", sellPrice = 0, quality = "purple", desc = "封装了100枚沙海令的锦盒，散发炽热气息。\n用途：使用后获得100枚沙海令。\n炼制：100沙海令 + 100灵韵（第三章炼丹炉）" },
    taixu_token_box = { name = "太虚令盒", icon = "📦", sellPrice = 0, quality = "purple", desc = "封装了100枚太虚令的锦盒，蕴含上古灵力。\n用途：使用后获得100枚太虚令。\n炼制：100太虚令 + 100灵韵（第四章炼丹炉）" },
    -- 上宝逊金钯残片（圣器品质，8片合成）
    rake_fragment_1 = { name = "上宝逊金钯残片·壹", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，仍残留着神器余威。\n用途：集齐九片可重铸神兵。\n获取：枯木妖王掉落（0.1%）" },
    rake_fragment_2 = { name = "上宝逊金钯残片·贰", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，隐约可见钯齿纹路。\n用途：集齐九片可重铸神兵。\n获取：岩蟾妖王掉落（0.1%）" },
    rake_fragment_3 = { name = "上宝逊金钯残片·叁", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，触手生温，灵光闪烁。\n用途：集齐九片可重铸神兵。\n获取：苍狼妖王掉落（0.1%）" },
    rake_fragment_4 = { name = "上宝逊金钯残片·肆", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，散发淡淡金芒。\n用途：集齐九片可重铸神兵。\n获取：赤甲妖王掉落（0.1%）" },
    rake_fragment_5 = { name = "上宝逊金钯残片·伍", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，握持时能感到微微震颤。\n用途：集齐九片可重铸神兵。\n获取：蛇骨妖王掉落（0.1%）" },
    rake_fragment_6 = { name = "上宝逊金钯残片·陆", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，表面刻有上古符文。\n用途：集齐九片可重铸神兵。\n获取：烈焰狮王掉落（0.1%）" },
    rake_fragment_7 = { name = "上宝逊金钯残片·柒", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，周围灵气不断汇聚。\n用途：集齐九片可重铸神兵。\n获取：蜃妖王掉落（0.1%）" },
    rake_fragment_8 = { name = "上宝逊金钯残片·捌", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，蕴含最核心的神兵之魂。\n用途：集齐九片可重铸神兵。\n获取：黄天大圣掉落（0.1%）" },
    rake_fragment_9 = { name = "上宝逊金钯残片·玖", icon = "icon_rake_fragment.png", sellPrice = 50000, quality = "red", desc = "上古神兵「上宝逊金钯」的碎片，仿佛能听到远古战场的回响。\n用途：集齐九片可重铸神兵。\n获取：朱老二处购买（100万金币）" },
    -- 文王八卦盘卦象碎片（第四章神器，8片对应八卦方位）
    bagua_fragment_kan  = { name = "卦象碎片·坎", icon = "icon_bagua_kan.png", sellPrice = 75000, quality = "red", desc = "文王八卦盘「坎卦」碎片，水之精华凝结而成。\n用途：集齐八片可重铸八卦盘。\n获取：沈渊衣掉落（0.1%）" },
    bagua_fragment_gen  = { name = "卦象碎片·艮", icon = "icon_bagua_gen.png", sellPrice = 75000, quality = "red", desc = "文王八卦盘「艮卦」碎片，山之重岳化为此形。\n用途：集齐八片可重铸八卦盘。\n获取：岩不动掉落（0.1%）" },
    bagua_fragment_zhen = { name = "卦象碎片·震", icon = "icon_bagua_zhen.png", sellPrice = 75000, quality = "red", desc = "文王八卦盘「震卦」碎片，雷霆之威尚存其中。\n用途：集齐八片可重铸八卦盘。\n获取：雷惊蛰掉落（0.1%）" },
    bagua_fragment_xun  = { name = "卦象碎片·巽", icon = "icon_bagua_xun.png", sellPrice = 75000, quality = "red", desc = "文王八卦盘「巽卦」碎片，清风拂过仍觉其轻灵。\n用途：集齐八片可重铸八卦盘。\n获取：风无痕掉落（0.1%）" },
    bagua_fragment_li   = { name = "卦象碎片·离", icon = "icon_bagua_li.png", sellPrice = 75000, quality = "red", desc = "文王八卦盘「离卦」碎片，烈火之心永燃不灭。\n用途：集齐八片可重铸八卦盘。\n获取：炎若晦掉落（0.1%）" },
    bagua_fragment_kun  = { name = "卦象碎片·坤", icon = "icon_bagua_kun.png", sellPrice = 75000, quality = "red", desc = "文王八卦盘「坤卦」碎片，厚德载物之象。\n用途：集齐八片可重铸八卦盘。\n获取：厚德生掉落（0.1%）" },
    bagua_fragment_dui  = { name = "卦象碎片·兑", icon = "icon_bagua_dui.png", sellPrice = 75000, quality = "red", desc = "文王八卦盘「兑卦」碎片，泽润万物之象。\n用途：集齐八片可重铸八卦盘。\n获取：泽归墟掉落（0.1%）" },
    bagua_fragment_qian = { name = "卦象碎片·乾", icon = "icon_bagua_qian.png", sellPrice = 75000, quality = "red", desc = "文王八卦盘「乾卦」碎片，天道至刚之象。\n用途：集齐八片可重铸八卦盘。\n获取：司空正阳掉落（0.1%）" },
    -- 龙神打造材料（四龙神各掉落一种，1%掉率）
    dragon_scale_ice = { name = "封霜龙鳞", icon = "🧊", sellPrice = 10000, quality = "red", desc = "封霜应龙脱落的寒鳞，触之彻骨生寒，内蕴远古龙威。\n用途：圣器打造材料。\n获取：封霜应龙掉落（1%）" },
    dragon_scale_abyss = { name = "渊蛟龙骨", icon = "🦴", sellPrice = 10000, quality = "red", desc = "堕渊蛟龙的脊骨碎片，散发幽紫光芒，蕴含深渊之力。\n用途：圣器打造材料。\n获取：堕渊蛟龙掉落（1%）" },
    dragon_scale_fire = { name = "焚天龙焰", icon = "🔥", sellPrice = 10000, quality = "red", desc = "焚天蜃龙的凝固龙焰，灼热异常，永不熄灭。\n用途：圣器打造材料。\n获取：焚天蜃龙掉落（1%）" },
    dragon_scale_sand = { name = "蚀骨龙牙", icon = "🦷", sellPrice = 10000, quality = "red", desc = "蚀骨螭龙的獠牙碎片，坚逾金刚，可侵蚀万物。\n用途：圣器打造材料。\n获取：蚀骨螭龙掉落（1%）" },
    -- 天帝剑痕碎片（仙劫战场·域外邪魔掉落，9片合成天帝剑痕）
    tiandi_fragment_1 = { name = "天帝剑痕碎片·壹", icon = "icon_tiandi_fragment.png", sellPrice = 100000, quality = "red", desc = "远古天帝斩落域外邪魔时遗留的剑痕残片，剑意犹存，隐约可闻天雷余响。\n用途：集齐九片可重铸天帝剑痕。\n获取：域外邪魔掉落（0.1%）" },
    tiandi_fragment_2 = { name = "天帝剑痕碎片·贰", icon = "icon_tiandi_fragment.png", sellPrice = 100000, quality = "red", desc = "据传天帝以此一剑斩断天外入侵通道，立下中洲万世屏障。碎片表面仍残留斩裂虚空的痕迹。\n用途：集齐九片可重铸天帝剑痕。\n获取：域外邪魔掉落（0.1%）" },
    tiandi_fragment_3 = { name = "天帝剑痕碎片·叁", icon = "icon_tiandi_fragment.png", sellPrice = 100000, quality = "red", desc = "剑痕之中封存着天帝护佑中洲的意志，岁月流转仍不减分毫，是那场惊天一役的最后见证。\n用途：集齐九片可重铸天帝剑痕。\n获取：域外邪魔掉落（0.1%）" },
    -- 仙图录：守护者证明（运营发放，用于仙途守护者道印升级）
    item_guardian_token = { name = "守护者证明", icon = "🔖", sellPrice = 0, quality = "orange", desc = "铭刻守护之志的凭证，是对积极反馈者的认可。\n用途：使用后增加100点仙途守护者道印经验。\n（无法出售，只能使用）\n获取：兑换码发放。" },

    -- 附灵玉（萃取系统，对应四大套装，可在黑市交易）
    lingyu_xuesha_lv1  = { name = "1阶附灵玉·血煞", icon = "🔴", image = "Textures/lingyu_xuesha_lv1.png",  sellPrice = 100000, quality = "cyan",
        desc = "萃取三件血煞套装灵器（T9原装或附灵装备均可）所得，蕴含血煞套装的灵力精华。\n用途：为任意装备附灵血煞套装效果（悟性系：悟性、连击率、技能触发血煞冲击）。可覆盖原有附灵。\n获取：附灵师·萃取 / 万界黑商。" },
    lingyu_qingyun_lv1 = { name = "1阶附灵玉·青云", icon = "🔵", image = "Textures/lingyu_qingyun_lv1.png", sellPrice = 100000, quality = "cyan",
        desc = "萃取三件青云套装灵器（T9原装或附灵装备均可）所得，蕴含青云套装的灵力精华。\n用途：为任意装备附灵青云套装效果（根骨系：根骨、重击率、重击触发青云裂空）。可覆盖原有附灵。\n获取：附灵师·萃取 / 万界黑商。" },
    lingyu_fengmo_lv1  = { name = "1阶附灵玉·封魔", icon = "🟣", image = "Textures/lingyu_fengmo_lv1.png",  sellPrice = 100000, quality = "cyan",
        desc = "萃取三件封魔套装灵器（T9原装或附灵装备均可）所得，蕴含封魔套装的灵力精华。\n用途：为任意装备附灵封魔套装效果（体魄系：体魄、血怒概率、受击触发封魔金轮）。可覆盖原有附灵。\n获取：附灵师·萃取 / 万界黑商。" },
    lingyu_haoqi_lv1   = { name = "1阶附灵玉·浩气", icon = "🟡", image = "Textures/lingyu_haoqi_lv1.png",  sellPrice = 100000, quality = "cyan",
        desc = "萃取三件浩气套装灵器（T9原装或附灵装备均可）所得，蕴含浩气套装的灵力精华。\n用途：为任意装备附灵浩气套装效果（福缘系：福缘、宠物同步率、击杀触发浩气破天）。可覆盖原有附灵。\n获取：附灵师·萃取 / 万界黑商。" },

    -- 阵营挑战·丹药精华（五种，全阵营通用，用于炼制凝X丹）
    lipo_essence    = { name = "力魄精华", icon = "💪", sellPrice = 500, quality = "purple",
        desc = "蕴含纯粹攻击之力的精华结晶。\n用途：炼制凝力丹（ATK +10），需1份精华 + 100灵韵。\n获取：阵营挑战物品掉落。" },
    panshi_essence  = { name = "磐石精华", icon = "🛡️", sellPrice = 500, quality = "purple",
        desc = "蕴含坚不可摧防御之力的精华结晶。\n用途：炼制凝甲丹（DEF +8），需1份精华 + 100灵韵。\n获取：阵营挑战物品掉落。" },
    yuanling_essence = { name = "元灵精华", icon = "💚", sellPrice = 500, quality = "purple",
        desc = "蕴含生生不息元气的精华结晶。\n用途：炼制凝元丹（maxHP +30），需1份精华 + 100灵韵。\n获取：阵营挑战物品掉落。" },
    shihun_essence  = { name = "噬魂精华", icon = "💀", sellPrice = 500, quality = "purple",
        desc = "蕴含噬魂夺命之力的精华结晶。\n用途：炼制凝魂丹（击杀回血 +40），需1份精华 + 100灵韵。\n获取：阵营挑战物品掉落。" },
    lingxi_essence  = { name = "灵息精华", icon = "🌿", sellPrice = 500, quality = "purple",
        desc = "蕴含灵气吐纳之力的精华结晶。\n用途：炼制凝息丹（生命回复 +6），需1份精华 + 100灵韵。\n获取：阵营挑战物品掉落。" },
}

-- 职业定义（数据驱动，按 classId 索引）
GameConfig.CLASS_DATA = {
    monk = {
        name = "罗汉",
        icon = "🥊",
        passive = {
            name = "金刚铁骨",
            desc = "重击率+10%，每级+1根骨",
            heavyHitChance = 0.10,
            constitutionPerLevel = 1,
        },
    },
    taixu = {
        name = "太虚",
        icon = "🗡️",
        passive = {
            name = "御剑悟道",
            desc = "连击概率+8%，每级+1悟性",
            comboChance = 0.08,
            wisdomPerLevel = 1,
        },
    },
    zhenyue = {
        name = "镇岳",
        icon = "⛰️",
        passive = {
            name = "岳镇乾坤",
            desc = "血怒概率+10%，每级+1体魄",
            bloodRageChanceBonus = 0.10,
            physiquePerLevel = 1,
        },
    },
}
GameConfig.PLAYER_CLASS = "monk"  -- 默认职业（创角时可覆盖）

-- 玩家初始属性
GameConfig.PLAYER_INITIAL = {
    level = 1,
    exp = 0,
    hp = 100,
    maxHp = 100,
    atk = 15,
    def = 5,
    speed = 0,         -- 速度为稀有属性，默认0
    hpRegen = 1.0,     -- HP回复/秒
    gold = 50,
    lingYun = 0,       -- 灵韵
    realm = "mortal",  -- 凡人
    attackSpeed = 1.0, -- 攻击速度倍率
}

-- 等级经验表（Lv.1-140）
GameConfig.EXP_TABLE = {
    -- 凡人 Lv.1-10
    [1] = 0,       [2] = 200,     [3] = 400,     [4] = 800,     [5] = 1400,
    [6] = 2200,    [7] = 3200,    [8] = 4400,    [9] = 5800,    [10] = 7500,
    -- 练气 Lv.11-25
    [11] = 10000,  [12] = 14000,  [13] = 20000,  [14] = 28000,  [15] = 39000,
    [16] = 54000,  [17] = 76000,  [18] = 110000, [19] = 150000, [20] = 210000,
    [21] = 280000, [22] = 360000, [23] = 470000, [24] = 600000, [25] = 780000,
    -- 筑基 Lv.26-40
    [26] = 940000,   [27] = 1130000,  [28] = 1350000,  [29] = 1620000,  [30] = 1950000,
    [31] = 2240000,  [32] = 2570000,  [33] = 2960000,  [34] = 3400000,  [35] = 3910000,
    [36] = 4300000,  [37] = 4730000,  [38] = 5200000,  [39] = 5720000,  [40] = 6290000,
    -- 金丹 Lv.41-55
    [41] = 6920000,  [42] = 7610000,  [43] = 8370000,  [44] = 9210000,  [45] = 10200000,
    [46] = 11200000, [47] = 12300000, [48] = 13500000, [49] = 14900000, [50] = 16400000,
    [51] = 18000000, [52] = 19800000, [53] = 21700000, [54] = 23900000, [55] = 26300000,
    -- 元婴 Lv.56-70
    [56] = 28900000,  [57] = 31800000,  [58] = 35000000,  [59] = 38500000,  [60] = 42300000,
    [61] = 46600000,  [62] = 51200000,  [63] = 56300000,  [64] = 62000000,  [65] = 68100000,
    [66] = 75000000,  [67] = 82400000,  [68] = 90700000,  [69] = 99700000,  [70] = 110000000,
    -- 化神 Lv.71-85
    [71] = 121000000,  [72] = 133000000,  [73] = 146000000,  [74] = 161000000,  [75] = 177000000,
    [76] = 195000000,  [77] = 214000000,  [78] = 236000000,  [79] = 259000000,  [80] = 285000000,
    [81] = 313000000,  [82] = 345000000,  [83] = 379000000,  [84] = 417000000,  [85] = 459000000,
    -- 合体 Lv.86-100
    [86] = 504000000,   [87] = 555000000,   [88] = 610000000,   [89] = 671000000,   [90] = 738000000,
    [91] = 812000000,   [92] = 893000000,   [93] = 982000000,   [94] = 1090000000,  [95] = 1190000000,
    [96] = 1310000000,  [97] = 1440000000,  [98] = 1590000000,  [99] = 1740000000,  [100] = 1920000000,
    -- 大乘 Lv.101-120
    [101] = 2110000000,  [102] = 2320000000,  [103] = 2550000000,  [104] = 2810000000,  [105] = 3090000000,
    [106] = 3400000000,  [107] = 3730000000,  [108] = 4110000000,  [109] = 4520000000,  [110] = 4970000000,
    [111] = 5460000000,  [112] = 6010000000,  [113] = 6610000000,  [114] = 7270000000,  [115] = 8000000000,
    [116] = 8800000000,  [117] = 9680000000,  [118] = 10700000000, [119] = 11800000000, [120] = 12900000000,
    -- 渡劫 Lv.121-140
    [121] = 14200000000, [122] = 15600000000, [123] = 17200000000, [124] = 18900000000, [125] = 20800000000,
    [126] = 22900000000, [127] = 25100000000, [128] = 27600000000, [129] = 30400000000, [130] = 33400000000,
    [131] = 36800000000, [132] = 40500000000, [133] = 44500000000, [134] = 48900000000, [135] = 53800000000,
    [136] = 59200000000, [137] = 65100000000, [138] = 71600000000, [139] = 78800000000, [140] = 86700000000,
}

-- 升级属性成长（每级增长量）
GameConfig.LEVEL_GROWTH = {
    maxHp = 15,
    atk = 3,
    def = 2,
    hpRegen = 0.2,
}

-- ===================== 境界系统 =====================
-- 凡人→练气→筑基→金丹→元婴→化神→合体→大乘→渡劫
-- 100级以下：3小境界（初期/中期/后期）  100级以上：4小境界（+巅峰）
-- order: 顺序  isMajor: 大境界突破  maxLevel: 等级上限
-- requiredLevel: 突破所需等级  attackSpeedBonus: 累计攻速
-- rewards: 属性奖励  cost: 消耗

GameConfig.REALM_LIST = {
    "mortal",
    "lianqi_1", "lianqi_2", "lianqi_3",
    "zhuji_1",  "zhuji_2",  "zhuji_3",
    "jindan_1", "jindan_2", "jindan_3",
    "yuanying_1", "yuanying_2", "yuanying_3",
    "huashen_1",  "huashen_2",  "huashen_3",
    "heti_1",  "heti_2",  "heti_3",
    "dacheng_1", "dacheng_2", "dacheng_3", "dacheng_4",
    "dujie_1",   "dujie_2",   "dujie_3",   "dujie_4",
}

GameConfig.REALMS = {
    mortal = {
        name = "凡人",
        order = 0,
        maxLevel = 10,
        attackSpeedBonus = 0,
    },
    -- ===== 练气（大境界：凡人→练气）3 小境界 =====
    lianqi_1 = {
        name = "练气初期", order = 1, isMajor = true,
        maxLevel = 25, requiredLevel = 10, attackSpeedBonus = 0.1,
        cost = { qiPill = 1, gold = 3000 },
        rewards = { maxHp = 15, atk = 3, def = 2, hpRegen = 0.2 },
    },
    lianqi_2 = {
        name = "练气中期", order = 2, isMajor = false,
        maxLevel = 25, requiredLevel = 15, attackSpeedBonus = 0.1,
        cost = { qiPill = 2, gold = 10000 },
        rewards = { maxHp = 23, atk = 5, def = 3, hpRegen = 0.3 },
    },
    lianqi_3 = {
        name = "练气后期", order = 3, isMajor = false,
        maxLevel = 25, requiredLevel = 20, attackSpeedBonus = 0.1,
        cost = { qiPill = 5, gold = 20000 },
        rewards = { maxHp = 30, atk = 6, def = 4, hpRegen = 0.4 },
    },
    -- ===== 筑基（大境界：练气→筑基）3 小境界 =====
    zhuji_1 = {
        name = "筑基初期", order = 4, isMajor = true,
        maxLevel = 40, requiredLevel = 25, attackSpeedBonus = 0.2,
        cost = { zhujiPill = 1, gold = 50000 },
        rewards = { maxHp = 45, atk = 9, def = 6, hpRegen = 0.6 },
    },
    zhuji_2 = {
        name = "筑基中期", order = 5, isMajor = false,
        maxLevel = 40, requiredLevel = 30, attackSpeedBonus = 0.2,
        cost = { zhujiPill = 2, gold = 75000 },
        rewards = { maxHp = 53, atk = 11, def = 7, hpRegen = 0.7 },
    },
    zhuji_3 = {
        name = "筑基后期", order = 6, isMajor = false,
        maxLevel = 40, requiredLevel = 35, attackSpeedBonus = 0.2,
        cost = { zhujiPill = 5, gold = 100000 },
        rewards = { maxHp = 60, atk = 12, def = 8, hpRegen = 0.8 },
    },
    -- ===== 金丹（大境界：筑基→金丹）3 小境界 =====
    jindan_1 = {
        name = "金丹初期", order = 7, isMajor = true,
        maxLevel = 55, requiredLevel = 40, attackSpeedBonus = 0.3,
        cost = { jindanSand = 10, gold = 200000 },
        rewards = { maxHp = 75, atk = 15, def = 10, hpRegen = 1.0 },
    },
    jindan_2 = {
        name = "金丹中期", order = 8, isMajor = false,
        maxLevel = 55, requiredLevel = 45, attackSpeedBonus = 0.3,
        cost = { jindanSand = 25, gold = 300000 },
        rewards = { maxHp = 83, atk = 17, def = 11, hpRegen = 1.1 },
    },
    jindan_3 = {
        name = "金丹后期", order = 9, isMajor = false,
        maxLevel = 55, requiredLevel = 50, attackSpeedBonus = 0.3,
        cost = { jindanSand = 50, gold = 500000 },
        rewards = { maxHp = 90, atk = 18, def = 12, hpRegen = 1.2 },
    },
    -- ===== 元婴（大境界：金丹→元婴）3 小境界 =====
    yuanying_1 = {
        name = "元婴初期", order = 10, isMajor = true,
        maxLevel = 70, requiredLevel = 55, attackSpeedBonus = 0.4,
        cost = { yuanyingFruit = 50, gold = 750000 },
        rewards = { maxHp = 105, atk = 21, def = 14, hpRegen = 1.4 },
    },
    yuanying_2 = {
        name = "元婴中期", order = 11, isMajor = false,
        maxLevel = 70, requiredLevel = 60, attackSpeedBonus = 0.4,
        cost = { yuanyingFruit = 100, gold = 1000000 },
        rewards = { maxHp = 113, atk = 23, def = 15, hpRegen = 1.5 },
    },
    yuanying_3 = {
        name = "元婴后期", order = 12, isMajor = false,
        maxLevel = 70, requiredLevel = 65, attackSpeedBonus = 0.4,
        cost = { yuanyingFruit = 200, gold = 1500000 },
        rewards = { maxHp = 120, atk = 24, def = 16, hpRegen = 1.6 },
    },
    -- ===== 化神（大境界：元婴→化神）3 小境界 =====
    huashen_1 = {
        name = "化神初期", order = 13, isMajor = true,
        maxLevel = 85, requiredLevel = 70, attackSpeedBonus = 0.5,
        cost = { jiuzhuanJindan = 50, gold = 2400000 },
        rewards = { maxHp = 135, atk = 27, def = 18, hpRegen = 1.8 },
    },
    huashen_2 = {
        name = "化神中期", order = 14, isMajor = false,
        maxLevel = 85, requiredLevel = 75, attackSpeedBonus = 0.5,
        cost = { jiuzhuanJindan = 75, gold = 3600000 },
        rewards = { maxHp = 143, atk = 29, def = 19, hpRegen = 1.9 },
    },
    huashen_3 = {
        name = "化神后期", order = 15, isMajor = false,
        maxLevel = 85, requiredLevel = 80, attackSpeedBonus = 0.5,
        cost = { jiuzhuanJindan = 100, gold = 5400000 },
        rewards = { maxHp = 150, atk = 30, def = 20, hpRegen = 2.0 },
    },
    -- ===== 合体（大境界：化神→合体）3 小境界 =====
    heti_1 = {
        name = "合体初期", order = 16, isMajor = true,
        maxLevel = 100, requiredLevel = 85, attackSpeedBonus = 0.6,
        cost = { jiuzhuanJindan = 120, gold = 7000000 },
        rewards = { maxHp = 165, atk = 33, def = 22, hpRegen = 2.2 },
    },
    heti_2 = {
        name = "合体中期", order = 17, isMajor = false,
        maxLevel = 100, requiredLevel = 90, attackSpeedBonus = 0.6,
        cost = { jiuzhuanJindan = 160, gold = 10500000 },
        rewards = { maxHp = 173, atk = 35, def = 23, hpRegen = 2.3 },
    },
    heti_3 = {
        name = "合体后期", order = 18, isMajor = false,
        maxLevel = 100, requiredLevel = 95, attackSpeedBonus = 0.6,
        cost = { jiuzhuanJindan = 200, gold = 15800000 },
        rewards = { maxHp = 180, atk = 36, def = 24, hpRegen = 2.4 },
    },
    -- ===== 大乘（大境界：合体→大乘）4 小境界 =====
    dacheng_1 = {
        name = "大乘初期", order = 19, isMajor = true,
        maxLevel = 120, requiredLevel = 100, attackSpeedBonus = 0.8,
        cost = { dujieDan = 50, gold = 19000000 },
        rewards = { maxHp = 195, atk = 39, def = 26, hpRegen = 2.6 },
    },
    dacheng_2 = {
        name = "大乘中期", order = 20, isMajor = false,
        maxLevel = 120, requiredLevel = 105, attackSpeedBonus = 0.8,
        cost = { dujieDan = 75, gold = 25500000 },
        rewards = { maxHp = 203, atk = 41, def = 27, hpRegen = 2.7 },
    },
    dacheng_3 = {
        name = "大乘后期", order = 21, isMajor = false,
        maxLevel = 120, requiredLevel = 110, attackSpeedBonus = 0.8,
        cost = { dujieDan = 100, gold = 34500000 },
        rewards = { maxHp = 210, atk = 42, def = 28, hpRegen = 2.8 },
    },
    dacheng_4 = {
        name = "大乘巅峰", order = 22, isMajor = false,
        maxLevel = 120, requiredLevel = 115, attackSpeedBonus = 0.8,
        cost = { dujieDan = 150, gold = 46500000 },
        rewards = { maxHp = 218, atk = 44, def = 29, hpRegen = 2.9 },
    },
    -- ===== 渡劫（大境界：大乘→渡劫）4 小境界 =====
    dujie_1 = {
        name = "渡劫初期", order = 23, isMajor = true,
        maxLevel = 140, requiredLevel = 120, attackSpeedBonus = 1.0,
        cost = { dujieDan = 200, gold = 51000000 },
        rewards = { maxHp = 233, atk = 47, def = 31, hpRegen = 3.1 },
    },
    dujie_2 = {
        name = "渡劫中期", order = 24, isMajor = false,
        maxLevel = 140, requiredLevel = 125, attackSpeedBonus = 1.0,
        cost = { dujieDan = 280, gold = 69000000 },
        rewards = { maxHp = 240, atk = 48, def = 32, hpRegen = 3.2 },
    },
    dujie_3 = {
        name = "渡劫后期", order = 25, isMajor = false,
        maxLevel = 140, requiredLevel = 130, attackSpeedBonus = 1.0,
        cost = { dujieDan = 380, gold = 93000000 },
        rewards = { maxHp = 248, atk = 50, def = 33, hpRegen = 3.3 },
    },
    dujie_4 = {
        name = "渡劫巅峰", order = 26, isMajor = false,
        maxLevel = 140, requiredLevel = 135, attackSpeedBonus = 1.0,
        cost = { dujieDan = 500, gold = 125500000 },
        rewards = { maxHp = 255, atk = 51, def = 34, hpRegen = 3.4 },
    },
}

-- 旧键兼容映射（存档兼容）
GameConfig.REALM_COMPAT = {
    lianqi = "lianqi_1",
}

-- 背包
GameConfig.BACKPACK_SIZE = 60
GameConfig.BAG_SPLIT = 30  -- 背包拆分：bag1 存 1~30，bag2 存 31~60
GameConfig.MAX_STACK_COUNT = 9999  -- 消耗品单堆叠上限，溢出创建新堆叠

-- 装备品质
GameConfig.QUALITY = {
    white   = { name = "普通", color = {200, 200, 200, 255}, multiplier = 1.0, subStatCount = 0 },
    green   = { name = "良品", color = {100, 200, 100, 255}, multiplier = 1.1, subStatCount = 1 },
    blue    = { name = "精品", color = {100, 150, 255, 255}, multiplier = 1.2, subStatCount = 2 },
    purple  = { name = "极品", color = {180, 100, 255, 255}, multiplier = 1.3, subStatCount = 3 },
    orange  = { name = "稀世", color = {255, 165, 0, 255},   multiplier = 1.5, subStatCount = 3 },
    cyan    = { name = "灵器", color = {0, 220, 220, 255},   multiplier = 1.8, subStatCount = 3 },
    red     = { name = "圣器", color = {255, 50, 50, 255},   multiplier = 2.1, subStatCount = 3 },
    gold    = { name = "仙器", color = {255, 215, 0, 255},   multiplier = 2.5, subStatCount = 3 },
    rainbow = { name = "神器", color = {255, 100, 200, 255}, multiplier = 3.0, subStatCount = 3 },
}

-- 品质排序（用于对比）
GameConfig.QUALITY_ORDER = {
    white = 1, green = 2, blue = 3, purple = 4,
    orange = 5, cyan = 6, red = 7, gold = 8, rainbow = 9,
}

--- 根据等级获取能达到的最大境界 ID
---@param level number
---@return string realmId 最大可达境界的 key（如 "lianqi_3"）
function GameConfig.GetMaxRealmByLevel(level)
    local bestRealm = "mortal"
    local bestOrder = 0
    for id, data in pairs(GameConfig.REALMS) do
        if data.requiredLevel and level >= data.requiredLevel and (data.order or 0) > bestOrder then
            bestOrder = data.order
            bestRealm = id
        end
    end
    return bestRealm
end

-- 伤害公式：DMG = ATK^2 / (ATK + DEF)
function GameConfig.CalcDamage(atk, def)
    if atk + def <= 0 then return 1 end
    local dmg = (atk * atk) / (atk + def)
    -- 加入 10% 随机波动
    local variance = 0.9 + math.random() * 0.2
    return math.max(1, math.floor(dmg * variance))
end

-- 颜色工具
GameConfig.COLORS = {
    -- 地图瓦片
    grass       = {80, 140, 60, 255},
    grass_dark  = {60, 110, 45, 255},
    town        = {160, 130, 100, 255},
    town_road   = {180, 160, 130, 255},
    cave        = {100, 90, 80, 255},
    cave_dark   = {70, 60, 55, 255},
    forest      = {50, 100, 40, 255},
    forest_dark = {35, 75, 30, 255},
    mountain    = {120, 110, 100, 255},
    water       = {60, 120, 180, 255},
    wall        = {80, 80, 80, 255},

    -- 第二章瓦片
    fortress_wall  = {60, 55, 50, 255},
    fortress_floor = {90, 70, 60, 255},
    swamp          = {50, 65, 40, 255},
    sealed_gate    = {80, 70, 30, 255},
    crystal_stone  = {100, 60, 120, 255},
    camp_dirt      = {120, 100, 70, 255},
    battlefield    = {75, 55, 40, 255},

    -- 第三章瓦片
    sand_wall  = {160, 130, 70, 255},
    desert     = {210, 190, 130, 255},
    sand_floor = {180, 155, 110, 255},
    sand_road  = {200, 175, 130, 255},

    -- UI
    hpBar       = {220, 50, 50, 255},
    hpBarBg     = {80, 30, 30, 200},
    expBar      = {50, 150, 255, 255},
    expBarBg    = {30, 50, 80, 200},
    gold        = {255, 215, 0, 255},
    lingYun     = {150, 100, 255, 255},

    -- 实体
    player      = {60, 150, 255, 255},
    playerSkin  = {255, 220, 180, 255},
    pet         = {200, 150, 80, 255},
    petDark     = {160, 120, 60, 255},
}

-- BOSS 级别类别集合（用于击杀统计、掉落判定等）
-- 新增更高级 BOSS 类别时只需在此添加
GameConfig.BOSS_CATEGORIES = {
    ["boss"] = true,
    ["king_boss"] = true,
    ["emperor_boss"] = true,
    ["saint_boss"] = true,
}

--- 精英及以上类别（Tier窗口限制为2级）
GameConfig.ELITE_OR_BOSS = {
    ["elite"] = true,
    ["boss"] = true,
    ["king_boss"] = true,
    ["emperor_boss"] = true,
    ["saint_boss"] = true,
}

-- ═══ 活动限定道具（五一世界掉落活动 v3.4）═══
GameConfig.EVENT_ITEMS = {
    mayday_wu = {
        name = "五", icon = "🎏",
        image = "Textures/event/mayday_wu.png",
        sellPrice = 1000, quality = "purple",
        desc = "五一活动信物「五」，击败各章节BOSS有机会掉落。集齐「五一快乐」四字前往中洲青云城「天官降福」处可兑换丰厚灵韵，也可单字兑换天庭福袋。",
        category = "event", eventId = "mayday_2026",
    },
    mayday_yi = {
        name = "一", icon = "🎏",
        image = "Textures/event/mayday_yi.png",
        sellPrice = 1000, quality = "purple",
        desc = "五一活动信物「一」，击败各章节BOSS有机会掉落。集齐「五一快乐」四字前往中洲青云城「天官降福」处可兑换丰厚灵韵，也可单字兑换天庭福袋。",
        category = "event", eventId = "mayday_2026",
    },
    mayday_kuai = {
        name = "快", icon = "🎏",
        image = "Textures/event/mayday_kuai.png",
        sellPrice = 1000, quality = "purple",
        desc = "五一活动信物「快」，击败各章节BOSS有机会掉落。集齐「五一快乐」四字前往中洲青云城「天官降福」处可兑换丰厚灵韵，也可单字兑换天庭福袋。",
        category = "event", eventId = "mayday_2026",
    },
    mayday_le = {
        name = "乐", icon = "🎏",
        image = "Textures/event/mayday_le.png",
        sellPrice = 1000, quality = "purple",
        desc = "五一活动信物「乐」，击败各章节BOSS有机会掉落。集齐「五一快乐」四字前往中洲青云城「天官降福」处可兑换丰厚灵韵，也可单字兑换天庭福袋。",
        category = "event", eventId = "mayday_2026",
    },
    mayday_fudai = {
        name = "天庭福袋", icon = "🧧",
        image = "Textures/event/mayday_fudai.png",
        sellPrice = 1000, quality = "orange",
        desc = "天庭赐下的福袋，击败各章节BOSS有机会掉落，也可用活动信物兑换。前往中洲青云城「天官降福」处开启，随机获得一种奖励。不可交易。",
        category = "event", eventId = "mayday_2026",
    },
}

--- 统一消耗品查找表（合并 PET_FOOD + PET_MATERIALS + EVENT_ITEMS，供全局名称/图标查找）
GameConfig.CONSUMABLES = {}
for k, v in pairs(GameConfig.PET_FOOD) do GameConfig.CONSUMABLES[k] = v end
for k, v in pairs(GameConfig.PET_MATERIALS) do GameConfig.CONSUMABLES[k] = v end
for k, v in pairs(GameConfig.EVENT_ITEMS) do GameConfig.CONSUMABLES[k] = v end

-- ============================================================================
-- 性能监控配置（Phase 0 基线采集）
-- ============================================================================
GameConfig.PERF_FLAGS = {
    enabled = false,          -- 主开关（默认关，GM 命令 /perf 可运行时切换）
    reportInterval = 10,      -- 报告间隔（秒）
}

return GameConfig
