-- ============================================================================
-- bandit_camp.lua - 山贼寨区域数据
-- ============================================================================

local bandit_camp = {}

-- 区域范围（主寨 + 后山）
bandit_camp.regions = {
    bandit_camp     = { x1 = 2,  y1 = 2,  x2 = 28, y2 = 48, zone = "bandit_camp" },
    bandit_backhill = { x1 = 33, y1 = 4,  x2 = 47, y2 = 20, zone = "bandit_camp" },
}

-- 怪物刷新点
-- 主寨 (2,2)→(28,48)，DrawBorder 概率墙(20%WALL)在边界
-- Barriers: 竖向山脊 x=29(留口y=39~42和y=8~14)
-- 装饰阻挡: watchtower(24,24 2x2), tent(5,10)(16,8)(23,35)(8,38),
--   fence(10~12,24)(20~22,38), barrel(17,9)(6,11)(24,36), well 无
-- 安全可用区域: x=4~27, y=4~47（避开边界+barrier+装饰）
--
-- 后山 (33,4)→(47,20)，DrawBorder 概率墙(30%MOUNTAIN)
-- Barriers: 四周加固墙(y=3,y=21,x=48), 内部岩群多处
-- 岩群阻挡: (35,5)(36,5)(35,6) (46,8)(47,8)(46,9) (41,13)(42,13)(42,14)
--   (34,17)(35,17) (43,19)(44,19) (39,6)(45,12)(34,14)(42,18)
-- watchtower(33,10 2x2), tent(36,7)(44,15), barrel(37,7)(44,16)
-- 安全可用区域: x=35~45, y=6~18（避开边界+岩群+装饰）
bandit_camp.spawns = {
    -- ===== 山贼寨主寨 (2,2)→(28,48) Lv.8~12 =====
    -- 山贼 Lv.8~10（主力小怪）
    { type = "bandit_small", x = 8,  y = 15 },   -- 避开 tent(5,10)
    { type = "bandit_small", x = 12, y = 20 },   -- 安全
    { type = "bandit_small", x = 15, y = 13 },   -- 避开 flag(14,14)
    { type = "bandit_small", x = 20, y = 26 },   -- 避开 watchtower(24,24~25,25)
    { type = "bandit_small", x = 10, y = 30 },   -- 安全
    { type = "bandit_small", x = 18, y = 35 },   -- 安全
    { type = "bandit_small", x = 22, y = 16 },   -- 避开 fence(10~12,24)
    { type = "bandit_small", x = 25, y = 42 },   -- 避开 barrel(24,36) 和边界
    { type = "bandit_small", x = 7,  y = 44 },   -- 避开边界 x=2
    { type = "bandit_small", x = 14, y = 43 },   -- 南部（避开南墙 y=46~48）
    -- 山贼护卫 Lv.11~13 练气初期（数量较少）
    { type = "bandit_guard", x = 10, y = 22 },   -- 安全
    { type = "bandit_guard", x = 22, y = 32 },   -- 安全
    -- 二大王 Lv.11 Boss 练气初期（巡逻Boss：fortress_loop，覆盖主寨）
    {
        type = "bandit_second", x = 13, y = 28,
        patrolPreset = "fortress_loop",
        patrol = {
            nodes = {
                { x = 13, y = 18 },   -- 篝火旁
                { x = 20, y = 14 },   -- 东北帐篷区
                { x = 24, y = 24 },   -- 瞭望塔前
                { x = 19, y = 30 },   -- 中部篝火
                { x = 10, y = 35 },   -- 西南
                { x = 8,  y = 25 },   -- 西侧木栅附近
            },
        },
    },
    -- 军师 Lv.12 精英 练气初期（3个刷新点）
    { type = "bandit_strategist", x = 18, y = 22 }, -- 中部
    { type = "bandit_strategist", x = 8,  y = 33 }, -- 西南区域
    { type = "bandit_strategist", x = 24, y = 12 }, -- 东北区域

    -- ===== 山贼寨后山 (33,4)→(47,20) Lv.11~15 =====
    -- 山贼护卫 Lv.11~13 练气初期（后山主力）
    { type = "bandit_guard_back", x = 37, y = 9 },   -- 避开 tent(36,7) barrel(37,7) 和岩群(35,5~6)
    { type = "bandit_guard_back", x = 40, y = 7 },   -- 避开 岩群(39,6)
    { type = "bandit_guard_back", x = 43, y = 16 },  -- 避开 岩群(43,19) tent(44,15)
    { type = "bandit_guard_back", x = 44, y = 10 },  -- 避开 岩群(45,12)(46,8~9)
    { type = "bandit_guard_back", x = 38, y = 16 },  -- 避开 岩群(34,17)(35,17)
    { type = "bandit_guard_back", x = 40, y = 10 },  -- 安全，避开 岩群(41,13)
    { type = "bandit_guard_back", x = 36, y = 13 },  -- 避开 岩群(34,14) watchtower(33,10~34,11)
    -- 大大王 Lv.15 BOSS 练气初期
    { type = "bandit_chief", x = 39, y = 14 },       -- 中心偏安全，避开岩群(41,13)(42,13~14)
}

-- 装饰物
bandit_camp.decorations = {
    -- ============================================================
    -- 山贼寨主寨装饰物 (2,2)→(28,48)
    -- 主题：匪寨据点 — 瞭望塔、篝火、帐篷、旗帜、木栅
    -- ============================================================
    -- 瞭望塔（寨门口，占 2x2）
    { type = "watchtower", x = 24, y = 24, w = 2, h = 2, label = "前哨" },
    -- 篝火
    { type = "campfire", x = 13, y = 18 },
    { type = "campfire", x = 19, y = 30 },
    { type = "campfire", x = 7,  y = 40 },
    -- 帐篷
    { type = "tent", x = 5,  y = 10, color = {150, 115, 65, 255} },
    { type = "tent", x = 16, y = 8,  color = {145, 105, 60, 255} },
    { type = "tent", x = 23, y = 35, color = {155, 120, 70, 255} },
    { type = "tent", x = 8,  y = 38, color = {140, 110, 65, 255} },
    -- 旗帜（山贼旗，红黑色调）
    { type = "flag", x = 14, y = 14, color = {180, 40, 30, 255} },
    { type = "flag", x = 24, y = 20, color = {160, 35, 25, 255} },
    -- 木栅栏（寨子内部分隔区域）
    { type = "fence", x = 10, y = 24 },
    { type = "fence", x = 11, y = 24 },
    { type = "fence", x = 12, y = 24 },
    { type = "fence", x = 20, y = 38 },
    { type = "fence", x = 21, y = 38 },
    { type = "fence", x = 22, y = 38 },
    -- 兵器架
    { type = "weapon_rack", x = 6,  y = 15 },
    { type = "weapon_rack", x = 21, y = 28 },
    -- 木桶（物资存储）
    { type = "barrel", x = 17, y = 9 },
    { type = "barrel", x = 6,  y = 11 },
    { type = "barrel", x = 24, y = 36 },

    -- ============================================================
    -- 山贼寨后山装饰物 (33,4)→(47,20)
    -- ============================================================
    -- 瞭望塔（入口处，占 2x2）
    { type = "watchtower", x = 33, y = 10, w = 2, h = 2, label = "瞭望塔" },
    -- 帐篷
    { type = "tent", x = 36, y = 7, color = {160, 120, 70, 255} },
    { type = "tent", x = 44, y = 15, color = {140, 110, 65, 255} },
    -- 篝火
    { type = "campfire", x = 39, y = 12 },
    { type = "campfire", x = 44, y = 8 },
    -- 兵器架
    { type = "weapon_rack", x = 41, y = 10 },
    { type = "weapon_rack", x = 36, y = 16 },
    -- 枯树（灰褐色调）
    { type = "tree", x = 45, y = 6, color = {80, 70, 55, 255} },
    { type = "tree", x = 37, y = 18, color = {75, 65, 50, 255} },
    { type = "tree", x = 44, y = 18, color = {85, 75, 60, 255} },
    -- 路标
    { type = "sign", x = 33, y = 12, label = "后山" },
    -- 木桶/物资
    { type = "barrel", x = 37, y = 7 },
    { type = "barrel", x = 44, y = 16 },
}

-- 地图生成配置
bandit_camp.generation = {
    subRegions = {
        {
            regionKey = "bandit_camp",
            fill = { tile = "CAMP_FLOOR" },
            border = {
                tile = "WALL",
                minThick = 2,
                maxThick = 3,
                gaps = {
                    { side = "east",  from = 39, to = 42 },  -- 东侧入口（→主城）
                    { side = "east",  from = 9,  to = 13 },  -- 东侧通道（→后山）
                    { side = "south", from = 5,  to = 10 },  -- 南侧通道（→野猪林）
                },
            },
            erosion = { maxDepth = 2, protect = { north = true, west = true } },
        },
        {
            regionKey = "bandit_backhill",
            fill = { tile = "CAMP_FLOOR" },
            border = {
                tile = "MOUNTAIN",
                minThick = 1,
                maxThick = 2,
                gaps = {
                    { side = "north", from = 38, to = 41 },  -- 北侧入口（从荒野进入，4格宽）
                    { side = "west",  from = 9,  to = 13 },  -- 西侧通道（→山贼寨主寨）
                },
            },
            erosion = { maxDepth = 2, protect = {} },
        },
    },
}

return bandit_camp
