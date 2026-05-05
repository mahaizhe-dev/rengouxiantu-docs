-- ============================================================================
-- tiger_domain.lua - 虎王领地区域数据
-- ============================================================================

local tiger_domain = {}

-- 区域范围
tiger_domain.regions = {
    tiger_domain = { x1 = 58, y1 = 2, x2 = 78, y2 = 25, zone = "tiger_domain" },
}

-- 怪物刷新点
-- 区域 (58,2)→(78,25)，DrawBorder 概率占边界1格
-- Barriers: 西墙 x=56~57, 南墙 y=26~27(留口67~68), 东侧 x=79
-- 安全可用区域: x=60~76, y=4~23（避开边界概率墙+barrier）
-- 装饰物阻挡: bone_pile/dead_tree/crack/stone_tablet 均不阻挡移动
-- dead_tree 阻挡: (62,5)(73,7)(66,18)(74,22)  crack 阻挡: (63,12)(71,20)(68,6)
tiger_domain.spawns = {
    -- 猛虎 Lv.13~15 精英 练气初期
    { type = "tiger_elite", x = 63, y = 9 },    -- 西北，避开 dead_tree(62,5) 和 crack(63,12)
    { type = "tiger_elite", x = 70, y = 7 },    -- 北部中央，避开 crack(68,6) 和 dead_tree(73,7)
    { type = "tiger_elite", x = 75, y = 14 },   -- 东部中段
    { type = "tiger_elite", x = 65, y = 19 },   -- 西南，避开 dead_tree(66,18)
    { type = "tiger_elite", x = 72, y = 21 },   -- 东南，避开 crack(71,20) 和 dead_tree(74,22)
    -- 虎王 Lv.16 王级BOSS 练气中期
    { type = "tiger_king", x = 68, y = 14 },    -- 中央偏南，避开 crack(63,12)
}

-- 装饰物
tiger_domain.decorations = {
    -- 骨堆（散落的兽骨/人骨，避开猛虎刷怪点）
    { type = "bone_pile", x = 62, y = 10 },
    { type = "bone_pile", x = 69, y = 16 },
    { type = "bone_pile", x = 74, y = 9 },
    { type = "bone_pile", x = 66, y = 22 },
    -- 枯树（灰白色调，死去的大树）
    { type = "dead_tree", x = 62, y = 5 },
    { type = "dead_tree", x = 73, y = 7 },
    { type = "dead_tree", x = 66, y = 18 },
    { type = "dead_tree", x = 74, y = 22 },
    -- 裂谷/地裂（地面裂缝）
    { type = "crack", x = 63, y = 12 },
    { type = "crack", x = 71, y = 20 },
    { type = "crack", x = 68, y = 6 },
    -- 警示石碑
    { type = "stone_tablet", x = 67, y = 24, label = "虎啸林" },
    { type = "stone_tablet", x = 61, y = 14, label = "危险" },
}

-- 地图生成配置
tiger_domain.generation = {
    fill = { tile = "TIGER_GROUND" },
    border = {
        tile = "MOUNTAIN",
        minThick = 2,
        maxThick = 3,
        gaps = {
            { side = "south", from = 67, to = 70 },  -- 南侧入口
        },
    },
    erosion = { maxDepth = 3, protect = { north = true, east = true } },
}

return tiger_domain
