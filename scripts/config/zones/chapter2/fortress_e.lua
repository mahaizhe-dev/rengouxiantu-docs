-- ============================================================================
-- fortress_e.lua - E区·乌家堡（堡垒主体，含E1/E2/E3/E4 + BOSS房）
-- 整体外墙: (34,2)→(79,79)
-- ============================================================================

local fortress_e = {}

-- ============================================================================
-- 子区域定义
-- ============================================================================
fortress_e.regions = {
    -- E1 乌家北堡
    fortress_e1 = { x1 = 34, y1 = 2,  x2 = 79, y2 = 26, zone = "fortress_e1" },
    -- E2 乌家南堡
    fortress_e2 = { x1 = 34, y1 = 57, x2 = 79, y2 = 79, zone = "fortress_e2" },
    -- E3 乌堡大殿
    fortress_e3 = { x1 = 34, y1 = 31, x2 = 56, y2 = 51, zone = "fortress_e3" },
    -- E4 乌家主堡
    fortress_e4 = { x1 = 60, y1 = 24, x2 = 79, y2 = 58, zone = "fortress_e4" },
}

-- ============================================================================
-- BOSS 房定义（靠外墙中段，有轻微阻隔）
-- ============================================================================
fortress_e.bossRooms = {
    -- E1 BOSS房：靠北墙（有入口和碎墙阻隔）
    {
        wall  = { x1 = 54, y1 = 2,  x2 = 63, y2 = 11 },  -- 外墙范围
        inner = { x1 = 55, y1 = 3,  x2 = 62, y2 = 10 },  -- 内部范围
        entrance = { x1 = 57, y1 = 11, x2 = 60, y2 = 11 }, -- 入口（朝南，4格宽）
        barriers = {
            { 56, 10 }, { 61, 10 },                         -- 入口两侧碎墙
        },
    },
    -- E2 BOSS房：靠南墙（镜像）
    {
        wall  = { x1 = 54, y1 = 70, x2 = 63, y2 = 79 },
        inner = { x1 = 55, y1 = 71, x2 = 62, y2 = 78 },
        entrance = { x1 = 57, y1 = 70, x2 = 60, y2 = 70 }, -- 入口（朝北，4格宽）
        barriers = {
            { 56, 71 }, { 61, 71 },
        },
    },
}

-- ============================================================================
-- 堡内通道定义
-- ============================================================================
fortress_e.passages = {
    -- B→E1 开放通道（穿过西墙进入北翼，含墙厚 x=34~35）
    { type = "open", x1 = 30, y1 = 12, x2 = 35, y2 = 15, desc = "B→E1" },
    -- C→E2 开放通道（穿过西墙进入南翼，含墙厚 x=34~35）
    { type = "open", x1 = 30, y1 = 66, x2 = 35, y2 = 69, desc = "C→E2" },
    -- E1→E4 北堡南墙通道（穿透2格厚分隔墙 y=26~27，窄口4格）
    { type = "open", x1 = 68, y1 = 26, x2 = 71, y2 = 27, desc = "E1→E4" },
    -- E2→E4 南翼北墙通道（穿透2格厚分隔墙 y=55~56）
    { type = "open", x1 = 68, y1 = 55, x2 = 71, y2 = 57, desc = "E2→E4" },
    -- E4→E3 主堡入大殿（穿透3格厚分隔墙 x=57~59）
    { type = "open", x1 = 57, y1 = 39, x2 = 60, y2 = 43, desc = "E4→E3" },
    -- D→E3 封印正门（修罗场→乌堡大殿，需任务解锁；由 skull_d.sealedGate 覆盖封印瓦片）
    { type = "sealed", x1 = 33, y1 = 39, x2 = 35, y2 = 43, desc = "D→E3" },
}

-- ============================================================================
-- 东墙缺口定义（白框位置，保留开口）
-- 两个缺口分别位于 E1 和 E2 区域的东墙
-- ============================================================================
fortress_e.eastGaps = {
    { x1 = 78, y1 = 10, x2 = 79, y2 = 16 },   -- E1 东墙缺口（北侧）
    { x1 = 78, y1 = 46, x2 = 79, y2 = 52 },   -- E2 东墙缺口（南侧）
}

fortress_e.npcs = {
    {
        id = "dao_tree_ch2", name = "乌家堡·悟道树", subtitle = "每日参悟",
        x = 78, y = 50, icon = "🌳",
        interactType = "dao_tree", isObject = true, zone = "fortress_e4",
        label = "悟道树",
        dialog = "灵树扎根于魔气之中却不染分毫，枝叶间隐有剑意流转。静坐树下，可窥天地至理。",
    },
}

-- 怪物刷新点
-- E1 北堡 (34,2)→(79,26)，墙厚2，内部约 x=36~77, y=4~24
--   装饰/障碍物避开，BOSS房 (55,3)→(62,10) 入口朝南(57~60,11)
--   安全区: x=38~75, y=5~22（避开左墙加厚x=36、BOSS房区域、装饰物）
-- E2 南堡 (34,57)→(79,79)，镜像，内部约 x=36~77, y=59~77
--   BOSS房 (55,71)→(62,78) 入口朝北(57~60,70)
--   安全区: x=38~75, y=60~76
-- E3 大殿 (34,31)→(56,51)，左墙加厚x=36，内部 x=37~54, y=33~49
--   保持空旷，仅放 king_boss
-- E4 主堡 (60,24)→(79,58)，内部约 x=62~77, y=28~53
--   安全区: x=63~76, y=30~52
fortress_e.spawns = {
    -- === E1 北堡：乌家兵×10 + 血傀×3 + 乌地北(BOSS) ===
    { type = "wu_soldier",      x = 40, y = 8 },
    { type = "wu_soldier",      x = 48, y = 6 },
    { type = "wu_soldier",      x = 42, y = 14 },
    { type = "wu_soldier",      x = 50, y = 18 },
    { type = "wu_soldier",      x = 66, y = 8 },
    { type = "wu_soldier",      x = 72, y = 14 },
    { type = "wu_soldier",      x = 65, y = 20 },
    { type = "wu_soldier",      x = 44, y = 22 },
    { type = "wu_soldier",      x = 56, y = 18 },
    { type = "wu_soldier",      x = 74, y = 6 },
    { type = "wu_blood_puppet", x = 46, y = 10 },
    { type = "wu_blood_puppet", x = 70, y = 18 },
    { type = "wu_blood_puppet", x = 60, y = 16 },
    -- 乌地北 BOSS（BOSS房内）
    { type = "wu_dibei",        x = 58, y = 7 },
    -- 乌大傻 巡逻BOSS（北堡·BOSS房南侧水平长矩形）
    { type = "wu_dasha",        x = 56, y = 18,
      patrolPreset = "fortress_loop",
      patrol = {
          nodes = {
              { x = 38, y = 15 },
              { x = 74, y = 15 },
              { x = 74, y = 21 },
              { x = 38, y = 21 },
          },
      },
    },

    -- === E2 南堡：乌家家仆×10 + 血傀×3 + 乌天南(BOSS) ===
    { type = "wu_servant",      x = 40, y = 74 },
    { type = "wu_servant",      x = 48, y = 76 },
    { type = "wu_servant",      x = 42, y = 68 },
    { type = "wu_servant",      x = 50, y = 64 },
    { type = "wu_servant",      x = 66, y = 74 },
    { type = "wu_servant",      x = 72, y = 68 },
    { type = "wu_servant",      x = 65, y = 62 },
    { type = "wu_servant",      x = 44, y = 60 },
    { type = "wu_servant",      x = 56, y = 64 },
    { type = "wu_servant",      x = 74, y = 76 },
    { type = "wu_blood_puppet", x = 46, y = 72 },
    { type = "wu_blood_puppet", x = 70, y = 64 },
    { type = "wu_blood_puppet", x = 60, y = 66 },
    -- 乌天南 BOSS（BOSS房内）
    { type = "wu_tiannan",      x = 58, y = 75 },
    -- 乌二傻 巡逻BOSS（南堡·BOSS房北侧水平长矩形）
    { type = "wu_ersha",        x = 56, y = 64,
      patrolPreset = "fortress_loop",
      patrol = {
          nodes = {
              { x = 38, y = 61 },
              { x = 74, y = 61 },
              { x = 74, y = 67 },
              { x = 38, y = 67 },
          },
      },
    },

    -- === E4 主堡：血傀×6 + 乌万仇(BOSS) ===
    { type = "wu_blood_puppet", x = 64, y = 32 },
    { type = "wu_blood_puppet", x = 74, y = 34 },
    { type = "wu_blood_puppet", x = 66, y = 42 },
    { type = "wu_blood_puppet", x = 75, y = 48 },
    { type = "wu_blood_puppet", x = 72, y = 38 },
    { type = "wu_blood_puppet", x = 65, y = 44 },
    -- 乌万仇 BOSS（主堡中心）
    { type = "wu_wanchou",      x = 70, y = 41 },

    -- === E3 大殿：仅 king_boss（保持空旷） ===
    { type = "wu_wanhai",       x = 46, y = 41 },
}

-- ============================================================================
-- 装饰配置
-- ============================================================================
fortress_e.decorations = {
    -- E1 北堡装饰（内部约 x=36~77, y=4~24）
    { type = "weapon_rack", x = 38, y = 6 },
    { type = "weapon_rack", x = 45, y = 6 },
    { type = "barrel",      x = 40, y = 5 },
    { type = "barrel",      x = 41, y = 5 },
    { type = "barrel",      x = 42, y = 5 },
    { type = "campfire",    x = 50, y = 14 },
    { type = "banner",      x = 60, y = 8,  color = {80, 50, 50, 255} },
    { type = "banner",      x = 72, y = 8,  color = {80, 50, 50, 255} },
    { type = "bone_pile",   x = 38, y = 18 },
    { type = "bone_pile",   x = 70, y = 20 },
    { type = "crack",       x = 55, y = 16 },
    { type = "crack",       x = 65, y = 10 },
    { type = "stone_tablet",x = 75, y = 5 },
    { type = "barrel",      x = 74, y = 22 },
    { type = "barrel",      x = 75, y = 22 },
    { type = "campfire",    x = 68, y = 18 },
    { type = "weapon_rack", x = 73, y = 14 },
    { type = "cobweb",      x = 36, y = 4 },
    { type = "cobweb",      x = 77, y = 4 },
    { type = "cobweb",      x = 36, y = 24 },

    -- E2 南堡装饰（内部约 x=36~77, y=59~77）
    { type = "weapon_rack", x = 38, y = 77 },
    { type = "weapon_rack", x = 45, y = 77 },
    { type = "barrel",      x = 40, y = 76 },
    { type = "barrel",      x = 41, y = 76 },
    { type = "campfire",    x = 50, y = 68 },
    { type = "banner",      x = 60, y = 74, color = {80, 50, 50, 255} },
    { type = "banner",      x = 72, y = 74, color = {80, 50, 50, 255} },
    { type = "bone_pile",   x = 38, y = 64 },
    { type = "bone_pile",   x = 70, y = 62 },
    { type = "crack",       x = 55, y = 66 },
    { type = "crack",       x = 65, y = 72 },
    { type = "stone_tablet",x = 75, y = 77 },
    { type = "barrel",      x = 74, y = 60 },
    { type = "barrel",      x = 75, y = 60 },
    { type = "campfire",    x = 68, y = 64 },
    { type = "weapon_rack", x = 73, y = 68 },
    { type = "cobweb",      x = 36, y = 59 },
    { type = "cobweb",      x = 77, y = 59 },
    { type = "cobweb",      x = 77, y = 77 },

    -- E4 主堡装饰（内部约 x=62~77, y=28~53）
    { type = "campfire",    x = 70, y = 40 },
    { type = "banner",      x = 64, y = 30, color = {100, 40, 30, 255} },
    { type = "banner",      x = 76, y = 30, color = {100, 40, 30, 255} },
    { type = "banner",      x = 64, y = 52, color = {100, 40, 30, 255} },
    { type = "banner",      x = 76, y = 52, color = {100, 40, 30, 255} },
    { type = "weapon_rack", x = 62, y = 35 },
    { type = "weapon_rack", x = 62, y = 46 },
    { type = "barrel",      x = 76, y = 35 },
    { type = "barrel",      x = 77, y = 35 },
    { type = "barrel",      x = 76, y = 46 },
    { type = "barrel",      x = 77, y = 46 },
    { type = "bone_pile",   x = 66, y = 38 },
    { type = "bone_pile",   x = 74, y = 44 },
    { type = "crack",       x = 69, y = 32 },
    { type = "crack",       x = 72, y = 50 },
    { type = "stone_tablet",x = 70, y = 34 },
    { type = "cobweb",      x = 77, y = 28 },
    { type = "cobweb",      x = 77, y = 53 },
    { type = "cobweb",      x = 62, y = 28 },

    -- E4 悟道树
    { type = "dao_tree", x = 78, y = 49, w = 2, h = 2, label = "悟道树" },

    -- E3 大殿仅角落蛛网（保持空旷）
    { type = "cobweb",      x = 37, y = 33 },
    { type = "cobweb",      x = 54, y = 33 },
    { type = "cobweb",      x = 37, y = 49 },
    { type = "cobweb",      x = 54, y = 49 },
}

-- ============================================================================
-- 地图生成配置：special = "fortress"（由 GameMap 堡垒生成器处理）
-- ============================================================================
fortress_e.generation = {
    special = "fortress",
    fill = { tile = "FORTRESS_FLOOR" },
}

return fortress_e
