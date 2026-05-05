-- ============================================================================
-- haven.lua - 龟背岛（中央神龟岛，第四章出生点）
-- 龟壳: (32,32)→(47,47)  16×16, C=4 切角
-- 龟头朝南(離): y=48~51, 龟尾朝北(坎): y=29~31
-- 四肢最远: x=29/50, 腰弧: x=31/48
-- 完整区域: (29,29)→(50,51) 覆盖龟全身
-- 8 个阵法传送阵分布在龟的尾巴、四肢、腰部
-- ============================================================================

local haven = {}

haven.regions = {
    ch4_haven = { x1 = 29, y1 = 29, x2 = 50, y2 = 51, zone = "ch4_haven" },
}

haven.spawnPoint = { x = 39.5, y = 41.5 }

-- 8 个传送阵 NPC（分布在龟的身体部位上，按后天八卦方位）
haven.npcs = {
    -- ── 阵法传送阵（龟身体部位） ──

    -- 坎（北）→ 龟尾
    { id = "ch4_tp_kan",  name = "坎阵传送", subtitle = "传送至坎·沉渊阵",
      x = 39.5, y = 30.5, icon = "☵",
      interactType = "bagua_teleport", zone = "ch4_haven",
      isObject = true, label = "坎阵传送",
      teleportTarget = { x = 47.5, y = 14.5, island = "kan" },
    },
    -- 艮（东北）→ 右后肢
    { id = "ch4_tp_gen",  name = "艮阵传送", subtitle = "传送至艮·止岩阵",
      x = 48.5, y = 34.5, icon = "☶",
      interactType = "bagua_teleport", zone = "ch4_haven",
      isObject = true, label = "艮阵传送",
      teleportTarget = { x = 57.5, y = 29.5, island = "gen" },
    },
    -- 震（东）→ 右腰
    { id = "ch4_tp_zhen", name = "震阵传送", subtitle = "传送至震·惊雷阵",
      x = 47.5, y = 39.5, icon = "☳",
      interactType = "bagua_teleport", zone = "ch4_haven",
      isObject = true, label = "震阵传送",
      teleportTarget = { x = 64.5, y = 47.5, island = "zhen" },
    },
    -- 巽（东南）→ 右前肢
    { id = "ch4_tp_xun",  name = "巽阵传送", subtitle = "传送至巽·风旋阵",
      x = 48.5, y = 44.5, icon = "☴",
      interactType = "bagua_teleport", zone = "ch4_haven",
      isObject = true, label = "巽阵传送",
      teleportTarget = { x = 49.5, y = 57.5, island = "xun" },
    },
    -- 离（南）→ 壳内南沿（不变）
    { id = "ch4_tp_li",   name = "离阵传送", subtitle = "传送至离·烈焰阵",
      x = 39.5, y = 45.5, icon = "☲",
      interactType = "bagua_teleport", zone = "ch4_haven",
      isObject = true, label = "离阵传送",
      teleportTarget = { x = 31.5, y = 64.5, island = "li" },
    },
    -- 坤（西南）→ 左前肢
    { id = "ch4_tp_kun",  name = "坤阵传送", subtitle = "传送至坤·厚土阵",
      x = 30.5, y = 44.5, icon = "☷",
      interactType = "bagua_teleport", zone = "ch4_haven",
      isObject = true, label = "坤阵传送",
      teleportTarget = { x = 21.5, y = 49.5, island = "kun" },
    },
    -- 兑（西）→ 左腰
    { id = "ch4_tp_dui",  name = "兑阵传送", subtitle = "传送至兑·泽沼阵",
      x = 31.5, y = 39.5, icon = "☱",
      interactType = "bagua_teleport", zone = "ch4_haven",
      isObject = true, label = "兑阵传送",
      teleportTarget = { x = 14.5, y = 31.5, island = "dui" },
    },
    -- 乾（西北）→ 左后肢
    { id = "ch4_tp_qian", name = "乾阵传送", subtitle = "传送至乾·天罡阵",
      x = 30.5, y = 34.5, icon = "☰",
      interactType = "bagua_teleport", zone = "ch4_haven",
      isObject = true, label = "乾阵传送",
      teleportTarget = { x = 29.5, y = 21.5, island = "qian" },
    },

    -- ── 功能 NPC（散布于龟壳各处，间距 4~5 格） ──

    -- 文王八卦盘（第四章神器，龟壳正中央）
    { id = "ch4_divine_bagua", name = "文王八卦盘", subtitle = "第四章神器",
      x = 39.5, y = 39.5, icon = "☯",
      interactType = "divine_bagua", zone = "ch4_haven",
      isObject = true, label = "文王八卦盘",
      dialog = "一面古朴的八卦盘悬浮于龟壳正中，八方卦象流转不息，与脚下八卦传送阵遥相呼应。激活卦位可获得强大的属性加成。",
    },
    -- 跨章传送阵（龟壳西侧）
    { id = "ch4_teleport_array", name = "传送法阵", subtitle = "跨章传送",
      x = 35.5, y = 39.5, icon = "🌀",
      interactType = "teleport_array", zone = "ch4_haven",
      isObject = true, label = "传送法阵",
      dialog = "传送法阵散发着幽蓝的海雾，可以将你传送回万里黄沙。",
    },
    -- 装备商人（龟壳西北）
    { id = "ch4_merchant", name = "装备商人", subtitle = "商店",
      x = 37, y = 36, icon = "🛒",
      portrait = "Textures/npc_equip_merchant.png",
      interactType = "sell_equip", zone = "ch4_haven",
      dialog = "八卦海中危机四伏，好装备能保你一命！",
    },
    -- 炼丹炉（龟壳东北）
    { id = "ch4_alchemy", name = "炼丹炉", subtitle = "炼丹",
      x = 42, y = 36, icon = "🔥",
      portrait = "Textures/npc_alchemy_furnace.png",
      interactType = "alchemy", zone = "ch4_haven",
      dialog = "海风中的炼丹炉，火焰不息。",
    },
    -- 九师弟·太虚末（龟壳正南，主线NPC）
    { id = "ch4_quest_npc", name = "太虚末", subtitle = "区域主线",
      x = 39.5, y = 43.5, icon = "👦",
      portrait = "Textures/npc_taixu_mo.png",
      interactType = "village_chief", zone = "ch4_haven",
      questChain = "bagua_zone",
      dialog = "我是太虚宗九师弟……八位师兄被困在八卦阵中万年，神智早已模糊。请帮我击败他们，唤醒他们的意识！",
      dialogComplete = "八位师兄终于清醒了……太虚宗的噩梦结束了。多谢恩人！",
    },
    -- 神真子（龟头上，y=49.5 头部主体中央）
    { id = "ch4_shenzhenzi", name = "神真子", subtitle = "静坐悟道",
      x = 39.5, y = 49.5, icon = "🧘",
      portrait = "Textures/npc_shenzhenzi.png",
      interactType = "dragon_forge", zone = "ch4_haven",
      dialog = "神真子端坐于龟首之上，双目微闭，似在感应天地灵气。",
    },
    -- 福缘树（坐标 39,7~40,8 即 2×2）
    { id = "dao_tree_ch4", name = "八卦海·福缘树", subtitle = "每日参悟",
      x = 39.5, y = 7.5, icon = "🌳",
      interactType = "dao_tree", isObject = true, zone = "ch4_haven",
      label = "福缘树",
      dialog = "神龟背上灵树参天，枝叶间流转八方灵气。静坐树下，可悟天地玄机。",
    },
    -- 封魔使（龟壳东侧）
    { id = "seal_master_ch4", name = "封魔使·玄海", subtitle = "封魔任务",
      x = 43.5, y = 39.5, icon = "🔮",
      portrait = "Textures/npc_exorcist.png",
      interactType = "seal_demon", chapter = 4, zone = "ch4_haven",
      dialog = "八卦海魔气弥漫，八方阵法中的妖修已被魔化。吾乃封魔谷使者玄海，专司镇压魔化之物。修为足够者，可领取封魔任务，击杀魔化妖修可获灵韵与体魄丹。",
    },
    -- 百宝箱（龟壳西南）
    {
      id = "warehouse_chest", name = "百宝箱", subtitle = "存取物品",
      x = 35.5, y = 43.5, icon = "📦", image = "image/warehouse_chest_20260331104459.png", imageScale = 1.0,
      interactType = "warehouse", zone = "ch4_haven", isObject = true,
      dialog = "需要存放什么物品吗？打开仓库即可安全保管。",
    },
}

-- 传送阵特效装饰
-- 中央传送阵: 幽蓝色（与其他章节一致）
-- 八卦传送阵: 白色
haven.decorations = {
    { type = "divine_bagua", x = 39.5, y = 39.5 },  -- 八卦盘神器光效
    { type = "healing_spring", x = 43.5, y = 43.5, color = {80, 200, 170, 255}, label = "治愈之泉" },
    { type = "dao_tree", x = 39, y = 7, w = 2, h = 2, label = "福缘树" },
    -- 传送阵移至龟壳西侧（幽蓝色，与其他章节一致，与 NPC 坐标统一）
    { type = "teleport_array", x = 35.5, y = 39.5, color = {100, 150, 255, 255} },
    -- 八卦传送阵（白色，坐标与 NPC 统一）
    { type = "teleport_array", x = 39.5, y = 30.5, color = {240, 240, 255, 255} },  -- 坎·尾巴
    { type = "teleport_array", x = 48.5, y = 34.5, color = {240, 240, 255, 255} },  -- 艮·右后肢
    { type = "teleport_array", x = 47.5, y = 39.5, color = {240, 240, 255, 255} },  -- 震·右腰
    { type = "teleport_array", x = 48.5, y = 44.5, color = {240, 240, 255, 255} },  -- 巽·右前肢
    { type = "teleport_array", x = 39.5, y = 45.5, color = {240, 240, 255, 255} },  -- 离·壳内南
    { type = "teleport_array", x = 30.5, y = 44.5, color = {240, 240, 255, 255} },  -- 坤·左前肢
    { type = "teleport_array", x = 31.5, y = 39.5, color = {240, 240, 255, 255} },  -- 兑·左腰
    { type = "teleport_array", x = 30.5, y = 34.5, color = {240, 240, 255, 255} },  -- 乾·左后肢
}

haven.spawns = {}

haven.generation = {
    fill = { tile = "SEA_SAND" },
}

return haven
