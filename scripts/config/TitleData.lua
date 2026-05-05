-- ============================================================================
-- TitleData.lua - 称号数据配置
-- ============================================================================

local TitleData = {}

--- 称号列表（有序数组，用于 UI 显示顺序）
TitleData.ORDER = {
    "pioneer",
    "novice_star",
    "jianghu_hero",
    "young_hero",
    "veteran_xianyu",
    "boss_slayer_1k",
    "boss_slayer_10k",
}

--- 先行者白名单（TapTap userId）
--- 第一批：排行榜24位玩家（2026-03-05 收集）
TitleData.PIONEER_WHITELIST = {
    120132649,   -- User335087135
    188131532,   -- 知性喵
    192592733,   -- Усмивка
    260057035,   -- 王
    279944009,   -- 孤独的狼
    327378395,   --
    349256875,   -- 开局地摊卖大力
    424691008,   -- 渣仙
    579832418,   -- 手机用户59901260
    618784741,   -- 言不达意
    623389782,   -- 飞吧
    746792702,   -- 笑看风云
    849655543,   -- H
    1001650429,  -- 曦曦
    1074886667,  -- wbB哥
    1092360835,  -- 星界旅者
    1201181967,  -- 小丑
    1285788232,  -- 闪现撞墙我最爱
    1374362154,  -- 无罪
    1408691548,  -- 轻嗅晚风
    1530137746,  -- 利索的转生者
    1821334908,  -- 手机用户82489393
    1834206814,  -- 遇见叶子自我
    2033325280,  -- 烂不烂问厨房
    2104327381,  -- 时也运也
    -- 后续手动添加的用户放在下方：
    746567079,
    529194580,
    41208301,
    66240013,
    1644899579,
    1853807222,
    2019246023,
    1453475079,
    778429489,
    1144778218,
    223011418,
    228641354,
    873034330,
    937690510,
    1824195486,
}

--- 称号定义
TitleData.TITLES = {
    pioneer = {
        id = "pioneer",
        name = "先行者",
        desc = "奖励给认真测试反馈意见的先行者们",
        color = {120, 180, 255, 255},        -- 蓝色
        borderColor = {80, 140, 220, 220},   -- 蓝色线框
        bgColor = {20, 40, 70, 230},         -- 深蓝背景
        condition = { type = "pioneer" },
        conditionText = "先行测试资格",
        bonus = { critRate = 0.01 },
    },
    novice_star = {
        id = "novice_star",
        name = "新起之秀",
        desc = "击败虎王后获得的第一个称号",
        color = {100, 200, 100, 255},        -- 绿色
        borderColor = {80, 160, 80, 200},    -- 绿色线框
        bgColor = {30, 60, 30, 220},         -- 深绿背景
        condition = { type = "kill", targetType = "tiger_king", count = 1 },
        conditionText = "击杀虎王",
        bonus = { atk = 5 },
    },
    jianghu_hero = {
        id = "jianghu_hero",
        name = "江湖豪侠",
        desc = "斩杀乌堡之主乌万海，威震江湖",
        color = {100, 180, 255, 255},
        borderColor = {60, 130, 220, 220},
        bgColor = {15, 35, 75, 230},
        condition = { type = "kill", targetType = "wu_wanhai", count = 1 },
        conditionText = "击杀乌万海",
        bonus = { atk = 10 },
    },
    young_hero = {
        id = "young_hero",
        name = "英雄出少年",
        desc = "在最高难度下击败血煞盟·沈墨与浩气宗·陆青云，少年英才，名震武林",
        color = {180, 100, 255, 255},        -- 紫色
        borderColor = {140, 70, 220, 220},   -- 紫色线框
        bgColor = {40, 15, 70, 230},         -- 深紫背景
        condition = {
            type = "kill_all",
            targets = {
                { targetType = "challenge_shenmo_t4", count = 1 },
                { targetType = "challenge_luqingyun_t4", count = 1 },
            },
        },
        conditionText = "击败最高难度沈墨与陆青云",
        bonus = { heavyHit = 100 },
    },

    -- ===================== 等级系列 =====================
    veteran_xianyu = {
        id = "veteran_xianyu",
        name = "资深仙友",
        desc = "修仙有成，等级达到25级",
        color = {80, 200, 220, 255},          -- 青蓝色（区别于其他蓝色）
        borderColor = {60, 180, 200, 220},    -- 青蓝线框
        bgColor = {15, 45, 60, 230},          -- 深青背景
        tier = 4,                              -- 独特装饰风格：上下波纹线
        condition = { type = "level", level = 25 },
        conditionText = "等级达到25级",
        bonus = { expBonus = 0.01 },
    },

    -- ===================== BOSS击杀系列 =====================
    boss_slayer_1k = {
        id = "boss_slayer_1k",
        name = "千人斩",
        desc = "斩杀千名首领，威名远扬",
        color = {200, 120, 255, 255},          -- 紫色
        borderColor = {170, 80, 240, 220},     -- 紫色线框
        bgColor = {40, 15, 65, 230},           -- 深紫背景
        tier = 5,                               -- 刀剑交叉装饰
        condition = { type = "boss_kill_total", count = 1000 },
        conditionText = "击杀1000个BOSS",
        bonus = { killHeal = 20 },
    },
    boss_slayer_10k = {
        id = "boss_slayer_10k",
        name = "万人屠",
        desc = "屠戮万名首领，令妖魔胆寒",
        color = {255, 180, 60, 255},           -- 橙色
        borderColor = {240, 150, 30, 220},     -- 橙色线框
        bgColor = {65, 35, 10, 230},           -- 深橙背景
        tier = 6,                               -- 火焰光效特效装饰
        condition = { type = "boss_kill_total", count = 10000 },
        conditionText = "击杀10000个BOSS",
        bonus = { killHeal = 40, atkBonus = 0.01 },
    },
}

return TitleData
