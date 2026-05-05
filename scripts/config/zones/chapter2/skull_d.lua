-- ============================================================================
-- skull_d.lua - D区·修罗场（城门前）
-- 基础坐标: (13,23)→(30,59)  17×36
-- 凹陷甬道: (31,35)→(33,47)  额外向东延伸
-- ============================================================================

local skull_d = {}

skull_d.regions = {
    skull_d = { x1 = 13, y1 = 23, x2 = 30, y2 = 59, zone = "skull_d" },
}

-- 凹陷甬道定义（供 GameMap 堡垒生成使用）
skull_d.concavity = {
    x1 = 31, y1 = 35, x2 = 33, y2 = 47,  -- 凹陷区域（SWAMP 地砖）
}

-- 封印大门位置（SEALED_GATE 不可通行）
skull_d.sealedGate = {
    x1 = 33, y1 = 39, x2 = 34, y2 = 43,
}

skull_d.npcs = {}

-- 怪物刷新点
-- 区域 (13,23)→(30,59)  17×36
-- scatterRocks: 上下左三面交界 16% 密度 边界宽 4 格，右边不放（接堡墙）
-- 凹陷甬道: (31,35)→(33,47) 和封印大门 (33,39)→(34,43) 附近避开
-- 装饰阻挡: banner(16,28)(25,35)(20,52), bone_pile(18,30)(27,42)(15,48)(22,55),
--           campfire(21,38)(17,45)
-- 安全刷怪区: x=16~28, y=27~55（避开四周碎石带）
-- 全区只有精英怪（百年前两宗修士尸傀）
skull_d.spawns = {
    -- 血煞盟尸傀 Lv.24~26 精英（北半区分布）
    { type = "xueshameng_corpse", x = 18, y = 28 },
    { type = "xueshameng_corpse", x = 25, y = 30 },
    { type = "xueshameng_corpse", x = 20, y = 33 },
    { type = "xueshameng_corpse", x = 27, y = 37 },
    { type = "xueshameng_corpse", x = 17, y = 40 },
    -- 浩气宗尸傀 Lv.24~26 精英（南半区分布）
    { type = "haoqizong_corpse",  x = 25, y = 44 },
    { type = "haoqizong_corpse",  x = 19, y = 47 },
    { type = "haoqizong_corpse",  x = 27, y = 50 },
    { type = "haoqizong_corpse",  x = 16, y = 53 },
    { type = "haoqizong_corpse",  x = 23, y = 55 },
}
skull_d.decorations = {
    -- 战场遗迹：残破旗帜
    { type = "banner",     x = 16, y = 28, color = {120, 40, 40, 255} },
    { type = "banner",     x = 25, y = 35, color = {100, 35, 35, 255} },
    { type = "banner",     x = 20, y = 52, color = {110, 45, 30, 255} },
    -- 骨堆
    { type = "bone_pile",  x = 18, y = 30 },
    { type = "bone_pile",  x = 27, y = 42 },
    { type = "bone_pile",  x = 15, y = 48 },
    { type = "bone_pile",  x = 22, y = 55 },
    -- 篝火残迹（熄灭的）
    { type = "campfire",   x = 21, y = 38 },
    { type = "campfire",   x = 17, y = 45 },
}

skull_d.generation = {
    fill = { tile = "BATTLEFIELD" },
    -- 凹陷区域也填充 BATTLEFIELD，由 GameMap 的堡垒生成处理
}

return skull_d
