-- ============================================================================
-- TrialTowerConfig.lua - 青云试炼（试炼塔）配置
-- 260层爬塔系统，当前实现前10层（练气初期·蛛穴试炼）
-- ============================================================================

local TrialTowerConfig = {}

-- ============================================================================
-- 常量
-- ============================================================================

TrialTowerConfig.ARENA_SIZE = 10            -- 内部可行走区域（12×12含墙）
TrialTowerConfig.MAX_FLOOR = 260            -- 总层数上限
TrialTowerConfig.DAILY_UNLOCK_FLOOR = 10    -- 通关第10层才能领每日奖励

-- ============================================================================
-- 青云试炼专属增幅
-- ============================================================================

TrialTowerConfig.TRIAL_BUFF = {
    berserk = { atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 },
    atkMult = 1.5,
    hpMult = 2.0,
}

-- ============================================================================
-- 境界映射表
-- ============================================================================

TrialTowerConfig.REALMS = {
    [1]  = { id = "lianqi_1", name = "练气初期", floors = {1, 10},   reqLevel = 10, maxLevel = 20 },
    [2]  = { id = "lianqi_2", name = "练气中期", floors = {11, 20},  reqLevel = 20, maxLevel = 25 },
    [3]  = { id = "lianqi_3", name = "练气后期", floors = {21, 30},  reqLevel = 25, maxLevel = 30 },
    [4]  = { id = "zhuji_1",  name = "筑基初期", floors = {31, 40},  reqLevel = 30, maxLevel = 37 },
    [5]  = { id = "zhuji_2",  name = "筑基中期", floors = {41, 50},  reqLevel = 37, maxLevel = 43 },
    [6]  = { id = "zhuji_3",  name = "筑基后期", floors = {51, 60},  reqLevel = 43, maxLevel = 50 },
    [7]  = { id = "jindan_1", name = "金丹初期", floors = {61, 70},  reqLevel = 50, maxLevel = 55 },
    [8]  = { id = "jindan_2", name = "金丹中期", floors = {71, 80},  reqLevel = 55, maxLevel = 60 },
    [9]  = { id = "jindan_3", name = "金丹后期", floors = {81, 90},  reqLevel = 60, maxLevel = 65 },
    [10] = { id = "yuanying_1", name = "元婴初期", floors = {91, 100},  reqLevel = 65, maxLevel = 70 },
    [11] = { id = "yuanying_2", name = "元婴中期", floors = {101, 110}, reqLevel = 70, maxLevel = 75 },
    [12] = { id = "yuanying_3", name = "元婴后期", floors = {111, 120}, reqLevel = 75, maxLevel = 80 },
    -- ===== 第四章·八卦海（121-180层）=====
    [13] = { id = "huashen_1", name = "化神初期", floors = {121, 130}, reqLevel = 70, maxLevel = 85 },
    [14] = { id = "huashen_2", name = "化神中期", floors = {131, 140}, reqLevel = 75, maxLevel = 85 },
    [15] = { id = "huashen_3", name = "化神后期", floors = {141, 150}, reqLevel = 80, maxLevel = 85 },
    [16] = { id = "heti_1",    name = "合体初期", floors = {151, 160}, reqLevel = 85, maxLevel = 100 },
    [17] = { id = "heti_2",    name = "合体中期", floors = {161, 170}, reqLevel = 90, maxLevel = 100 },
    [18] = { id = "heti_3",    name = "合体后期", floors = {171, 180}, reqLevel = 95, maxLevel = 100 },
    -- ===== 第五章·太虚之殇（181-260层）=====
    -- 大乘每境界跨 20 层（与 GameConfig.REALMS order 19-22 对应）
    [19] = { id = "dacheng_1", name = "大乘初期", floors = {181, 200}, reqLevel = 100, maxLevel = 120 },
    [20] = { id = "dacheng_2", name = "大乘中期", floors = {201, 220}, reqLevel = 105, maxLevel = 120 },
    [21] = { id = "dacheng_3", name = "大乘后期", floors = {221, 240}, reqLevel = 110, maxLevel = 120 },
    [22] = { id = "dacheng_4", name = "大乘巅峰", floors = {241, 260}, reqLevel = 115, maxLevel = 120 },
}

--- 根据层数获取境界信息
--- 1-180层: 每10层一个境界 (realmIndex 1-18)
--- 181-260层: 每20层一个境界 (realmIndex 19-22)
---@param floor number
---@return table|nil realm, number realmIndex
function TrialTowerConfig.GetRealmByFloor(floor)
    local realmIndex
    if floor <= 180 then
        realmIndex = math.ceil(floor / 10)
    else
        realmIndex = 18 + math.ceil((floor - 180) / 20)
    end
    local realm = TrialTowerConfig.REALMS[realmIndex]
    return realm, realmIndex
end

--- 根据层数计算怪物等级
--- 在境界的 floor 范围内线性插值 reqLevel → maxLevel
---@param floor number 当前层（1-based）
---@return number level
function TrialTowerConfig.CalcMonsterLevel(floor)
    local realm = TrialTowerConfig.GetRealmByFloor(floor)
    if not realm then return 10 end
    local floorStart = realm.floors[1]
    local floorEnd = realm.floors[2]
    local span = floorEnd - floorStart  -- 9 或 19
    local progress = floor - floorStart  -- 0 ~ span
    return realm.reqLevel + math.floor((realm.maxLevel - realm.reqLevel) * progress / math.max(1, span))
end

--- 层内位置（相对于境界起始层）
--- 1-180层: 1~10; 181-260层: 1~20
---@param floor number
---@return number localFloor
function TrialTowerConfig.GetLocalFloor(floor)
    if floor <= 180 then
        return ((floor - 1) % 10) + 1
    else
        return ((floor - 181) % 20) + 1
    end
end

-- ============================================================================
-- 首通奖励公式（线性增长，所有层统一灵韵+金条）
-- ============================================================================

--- 计算某层的首通奖励
--- 使用 rewardTier（每10层一档，1-26）保持奖励线性递增
--- 灵韵 = rewardTier * 2 + floor(localFloor10 / 3) + 1
--- 金条 = max(1, round((rewardTier * 500 + localFloor10 * 100) / 500))
---@param floor number
---@return number lingYun, number goldBar
function TrialTowerConfig.CalcFirstClearReward(floor)
    if floor < 1 or floor > TrialTowerConfig.MAX_FLOOR then return 0, 0 end
    -- 奖励档位：始终按每10层递增（与每日档位一致）
    local rewardTier = math.ceil(floor / 10)
    local localFloor10 = ((floor - 1) % 10) + 1  -- 1~10

    local lingYun = rewardTier * 2 + math.floor(localFloor10 / 3) + 1
    local goldBar = math.max(1, math.floor((rewardTier * 500 + localFloor10 * 100) / 500 + 0.5))

    return lingYun, goldBar
end

-- ============================================================================
-- 每日奖励（= 第10层首通 × 2，按档位领取）
-- ============================================================================

TrialTowerConfig.MAX_DAILY_TIER = 26  -- 最高26档（对应260层）

--- 计算某个档位的每日奖励
--- 档位tier = floor(最高通关层/10)，取该档第10层首通值×2
---@param tier number 档位（1-26）
---@return number dailyLingYun, number dailyGoldBar
function TrialTowerConfig.CalcDailyRewardByTier(tier)
    if tier <= 0 or tier > TrialTowerConfig.MAX_DAILY_TIER then
        return 0, 0
    end
    -- 第10层首通: lingYun = tier*2 + floor(10/3) + 1 = tier*2 + 4
    -- 第10层首通: goldBar = max(1, round((tier*500 + 1000) / 500))
    -- 每日 = 首通 × 2
    local lingYun = (tier * 2 + 4) * 2
    local goldBar = math.max(1, math.floor((tier * 500 + 1000) / 500 + 0.5)) * 2
    return lingYun, goldBar
end

--- 根据最高通关层获取当前每日档位
---@param highestFloor number
---@return number tier (0=未解锁)
function TrialTowerConfig.GetDailyTier(highestFloor)
    if highestFloor < TrialTowerConfig.DAILY_UNLOCK_FLOOR then
        return 0
    end
    return math.min(math.floor(highestFloor / 10), TrialTowerConfig.MAX_DAILY_TIER)
end

--- 兼容旧接口：计算每日奖励（使用最高档位）
---@param highestFloor number 最高通关层
---@return number tier, number dailyLingYun, number dailyGoldBar
function TrialTowerConfig.CalcDailyReward(highestFloor)
    local tier = TrialTowerConfig.GetDailyTier(highestFloor)
    if tier <= 0 then return 0, 0, 0 end
    local ly, gb = TrialTowerConfig.CalcDailyRewardByTier(tier)
    return tier, ly, gb
end

-- ============================================================================
-- 怪物配置（120层，12个境界段各10层）
-- ============================================================================
-- 每10层组合规则（统一模式）：
--   1-3: 8只小怪(N)
--   4-6: 6小怪(N) + 2精英(E)
--   7-9: 4小怪(N) + 4精英(E)
--   10:  仅2只BOSS(B) + 地刺
-- 支持双小怪/双精英/双BOSS配置（设计文档要求混合怪物）

--- 生成一个10层段的布怪配置
--- 支持双小怪(normalId2)、双精英(eliteId2)、双BOSS(bossId2)
---@param cfg table { baseFloor, normals={id,id2?}, elites={id,id2?}, bosses={id,id2?}, bossName }
---@return table floors 10层配置
local function GenerateFloorBlock(cfg)
    local baseFloor = cfg.baseFloor
    local n1 = cfg.normals[1]
    local n2 = cfg.normals[2] or n1  -- 第二种小怪，默认同第一种
    local e1 = cfg.elites[1]
    local e2 = cfg.elites[2] or e1   -- 第二种精英，默认同第一种
    local b1 = cfg.bosses[1]
    local b2 = cfg.bosses[2] or b1   -- 第二种BOSS，默认同第一种
    local b3 = cfg.bosses[3]         -- 第三种BOSS（可选，用于三BOSS关卡）
    local bossName = cfg.bossName

    local floors = {}
    for i = 1, 10 do
        local floor = baseFloor + i - 1
        local level = TrialTowerConfig.CalcMonsterLevel(floor)
        if i <= 3 then
            -- 纯小怪 8只（双种各4）
            floors[floor] = { level = level, comp = "8N",
                monsters = { { id = n1, count = 4 }, { id = n2, count = 4 } } }
        elseif i <= 6 then
            -- 小怪6 + 精英2（双种小怪各3，双种精英各1）
            floors[floor] = { level = level, comp = "6N+2E",
                monsters = {
                    { id = n1, count = 3 }, { id = n2, count = 3 },
                    { id = e1, count = 1 }, { id = e2, count = 1 },
                } }
        elseif i <= 9 then
            -- 小怪4 + 精英4（双种小怪各2，双种精英各2）
            floors[floor] = { level = level, comp = "4N+4E",
                monsters = {
                    { id = n1, count = 2 }, { id = n2, count = 2 },
                    { id = e1, count = 2 }, { id = e2, count = 2 },
                } }
        else
            -- BOSS层：2~3只BOSS
            local bossMonsters = { { id = b1, count = 1 }, { id = b2, count = 1 } }
            local bossComp = "2B"
            if b3 then
                table.insert(bossMonsters, { id = b3, count = 1 })
                bossComp = "3B"
            end
            floors[floor] = { level = level, comp = bossComp,
                monsters = bossMonsters,
                isBoss = true, bossGroundSpike = true,
                bossName = bossName }
        end
    end
    return floors
end

-- ============================================================================
-- 12个境界段的怪物主题（严格按设计文档 predesign-systems.md §1.6）
-- ============================================================================
-- 设计文档中每个境界段都指定了：
--   小怪种族池(normals)、精英种族池(elites)、BOSS(bosses)
-- 所有怪物 ID 必须在 MonsterTypes_ch1~ch4 中有定义

local FLOOR_THEMES = {
    -- ── 练气初期（1-10层）· 蛛穴试炼 ──
    -- 小怪：小蜘蛛  精英：毒蛛精  BOSS：蛛母×2
    { baseFloor = 1,
      normals = { "spider_small" },
      elites  = { "spider_elite" },
      bosses  = { "spider_queen" },
      bossName = "蛛母×2（地刺）" },

    -- ── 练气中期（11-20层）· 野猪林 ──
    -- 小怪：野猪  精英：野猪统领  BOSS：猪三哥×2
    { baseFloor = 11,
      normals = { "boar_small" },
      elites  = { "boar_captain" },
      bosses  = { "boar_king" },
      bossName = "猪三哥×2（地刺）" },

    -- ── 练气后期（21-30层）· 匪寨剿灭 ──
    -- 小怪：山贼  精英：二大王+军师  BOSS：大大王+虎王（混合双BOSS）
    { baseFloor = 21,
      normals = { "bandit_small" },
      elites  = { "bandit_second", "bandit_strategist" },
      bosses  = { "bandit_chief", "tiger_king" },
      bossName = "大大王+虎王（地刺）" },

    -- ── 筑基初期（31-40层）· 蛇沼迷踪 ──
    -- 小怪：沼泽毒蛇  精英：血煞盟尸傀+浩气宗尸傀  BOSS：蛇妖·碧鳞×2
    { baseFloor = 31,
      normals = { "poison_snake" },
      elites  = { "xueshameng_corpse", "haoqizong_corpse" },
      bosses  = { "snake_king" },
      bossName = "蛇妖·碧鳞×2（地刺）" },

    -- ── 筑基中期（41-50层）· 乌堡攻坚 ──
    -- 小怪：乌家兵+乌家家仆  精英：乌家血傀  BOSS：乌地北+乌天南
    { baseFloor = 41,
      normals = { "wu_soldier", "wu_servant" },
      elites  = { "wu_blood_puppet" },
      bosses  = { "wu_dibei", "wu_tiannan" },
      bossName = "乌地北+乌天南（地刺）" },

    -- ── 筑基后期（51-60层）· 乌堡决战 ──
    -- 小怪：乌家家仆+枯木精  精英：乌家血傀+沙暴妖尉  BOSS：乌万仇+乌万海
    { baseFloor = 51,
      normals = { "wu_servant", "sand_scorpion_8" },
      elites  = { "wu_blood_puppet", "sand_elite_outer" },
      bosses  = { "wu_wanchou", "wu_wanhai" },
      bossName = "乌万仇+乌万海（地刺）" },

    -- ── 金丹初期（61-70层）· 黄沙九寨·外围 ──
    -- 小怪：枯木精+岩蟾  精英：沙暴妖尉  BOSS：枯木妖王+岩蟾妖王
    { baseFloor = 61,
      normals = { "sand_scorpion_8", "sand_wolf_7" },
      elites  = { "sand_elite_outer" },
      bosses  = { "yao_king_8", "yao_king_7" },
      bossName = "枯木妖王+岩蟾妖王（地刺）" },

    -- ── 金丹中期（71-80层）· 黄沙九寨·中段 ──
    -- 小怪：苍狼+赤甲蝎  精英：沙暴妖将  BOSS：苍狼妖王+赤甲妖王
    { baseFloor = 71,
      normals = { "sand_demon_6", "sand_scorpion_5" },
      elites  = { "sand_elite_mid" },
      bosses  = { "yao_king_6", "yao_king_5" },
      bossName = "苍狼妖王+赤甲妖王（地刺）" },

    -- ── 金丹后期（81-90层）· 黄沙九寨·深处 ──
    -- 小怪：蛇骨妖+赤焰妖  精英：沙暴妖将/帅  BOSS：蛇骨妖王+烈焰狮王
    { baseFloor = 81,
      normals = { "sand_wolf_4", "sand_demon_3" },
      elites  = { "sand_elite_mid", "sand_elite_inner" },
      bosses  = { "yao_king_4", "yao_king_3" },
      bossName = "蛇骨妖王+烈焰狮王（地刺）" },

    -- ── 元婴初期（91-100层）· 蜃妖洞窟 ──
    -- 小怪：蜃妖  精英：沙暴妖帅+枯木守卫  BOSS：蜃妖王×2
    { baseFloor = 91,
      normals = { "sand_demon_2" },
      elites  = { "sand_elite_inner", "kumu_guard" },
      bosses  = { "yao_king_2" },
      bossName = "蜃妖王×2（地刺）" },

    -- ── 元婴中期（101-110层）· 黄天圣殿 ──
    -- 小怪：蜃妖+枯木精/赤焰妖/蛇骨妖（混合）  精英：沙暴妖帅+枯木守卫  BOSS：蜃妖王+烈焰狮王
    { baseFloor = 101,
      normals = { "sand_demon_2", "sand_demon_3" },
      elites  = { "sand_elite_inner", "kumu_guard" },
      bosses  = { "yao_king_2", "yao_king_3" },
      bossName = "蜃妖王+烈焰狮王（地刺）" },

    -- ── 元婴后期（111-120层）· 大圣关 ──
    -- 小怪：赤焰妖+蛇骨妖  精英：枯木守卫+沙暴妖帅  BOSS：黄天大圣·沙万里×2
    { baseFloor = 111,
      normals = { "sand_demon_3", "sand_wolf_4" },
      elites  = { "kumu_guard", "sand_elite_inner" },
      bosses  = { "yao_king_1" },
      bossName = "黄天大圣·沙万里×2（地刺）" },

    -- ===== 第四章·八卦海（121-180层）=====

    -- ── 化神初期（121-130层）· 沉渊碎岩 ──
    -- 小怪：坎宗弟子  精英：艮宗精英  BOSS：沈渊衣+岩不动
    { baseFloor = 121,
      normals = { "kan_disciple" },
      elites  = { "gen_elite" },
      bosses  = { "kan_boss", "gen_boss" },
      bossName = "沈渊衣+岩不动（地刺）" },

    -- ── 化神中期（131-140层）· 雷风双煞 ──
    -- 小怪：艮宗弟子+震宗弟子  精英：巽宗精英  BOSS：雷惊蛰+风无痕
    { baseFloor = 131,
      normals = { "gen_disciple", "zhen_disciple" },
      elites  = { "xun_elite" },
      bosses  = { "zhen_boss", "xun_boss" },
      bossName = "雷惊蛰+风无痕（地刺）" },

    -- ── 化神后期（141-150层）· 焰土炼狱 ──
    -- 小怪：巽宗弟子+离宗弟子  精英：巽宗精英+坤宗精英  BOSS：炎若晦+厚德生
    { baseFloor = 141,
      normals = { "xun_disciple", "li_disciple" },
      elites  = { "xun_elite", "kun_elite" },
      bosses  = { "li_boss", "kun_boss" },
      bossName = "炎若晦+厚德生（地刺）" },

    -- ── 合体初期（151-160层）· 泽毒天罡 ──
    -- 小怪：坤宗弟子+兑宗弟子  精英：兑宗精英+坤宗精英  BOSS：泽归墟+司空正阳
    { baseFloor = 151,
      normals = { "kun_disciple", "dui_disciple" },
      elites  = { "dui_elite", "kun_elite" },
      bosses  = { "dui_boss", "qian_boss" },
      bossName = "泽归墟+司空正阳（地刺）" },

    -- ── 合体中期（161-170层）· 乾坤再临 ──
    -- 小怪：离宗弟子+兑宗弟子  精英：艮宗精英+兑宗精英  BOSS：司空正阳×2
    { baseFloor = 161,
      normals = { "li_disciple", "dui_disciple" },
      elites  = { "gen_elite", "dui_elite" },
      bosses  = { "qian_boss" },
      bossName = "司空正阳×2（地刺）" },

    -- ── 合体后期（171-180层）· 龙吟天地 ──
    -- 小怪：震宗弟子+巽宗弟子  精英：巽宗精英+坤宗精英  BOSS：封霜应龙+焚天蜃龙
    { baseFloor = 171,
      normals = { "zhen_disciple", "xun_disciple" },
      elites  = { "xun_elite", "kun_elite" },
      bosses  = { "dragon_ice", "dragon_fire" },
      bossName = "封霜应龙+焚天蜃龙（地刺）" },

    -- ===== 第五章·太虚之殇（181-260层）=====

    -- ── 大乘初期前（181-190层）· 裂山问剑 ──
    -- 小怪：同门残魂  精英：论剑残影  BOSS：护山石傀(王级) + 问剑长老裴千岳(皇级)
    { baseFloor = 181,
      normals = { "ch5_sword_ghost" },
      elites  = { "ch5_sword_shadow" },
      bosses  = { "ch5_stone_guardian", "ch5_pei_qianyue" },
      bossName = "护山石傀+问剑长老（地刺）" },

    -- ── 大乘初期后（191-200层）· 寒池铸炉 ──
    -- 小怪：寒池灵鹤+炉渣火傀  精英：裂冰玄鼋+炼炉兵傀  BOSS：洗剑霜鸾+铸剑长老韩百炼
    { baseFloor = 191,
      normals = { "ch5_cold_crane", "ch5_slag_puppet" },
      elites  = { "ch5_ice_turtle", "ch5_forge_soldier" },
      bosses  = { "ch5_frost_luan", "ch5_han_bailian" },
      bossName = "洗剑霜鸾+铸剑长老（地刺）" },

    -- ── 大乘中期前（201-210层）· 碑林悟剑 ──
    -- 小怪：剑痕石俑  精英：守碑幻影  BOSS：守碑长老石观澜×2（皇级）
    { baseFloor = 201,
      normals = { "ch5_stele_golem" },
      elites  = { "ch5_stele_phantom" },
      bosses  = { "ch5_shi_guanlan" },
      bossName = "守碑长老·石观澜×2（地刺）" },

    -- ── 大乘中期后（211-220层）· 别院藏经 ──
    -- 小怪：别院怨魂+禁页书妖  精英：夜巡剑侍+裂渊屠血将  BOSS：别院院主宁栖梧+藏经阁主温素章
    { baseFloor = 211,
      normals = { "ch5_court_wraith", "ch5_book_demon" },
      elites  = { "ch5_night_guard", "ch5_blood_general" },
      bosses  = { "ch5_ning_qiwu", "ch5_wen_suzhang" },
      bossName = "别院院主+藏经阁主（地刺）" },

    -- ── 大乘后期前（221-230层）· 镇魔前哨 ──
    -- 小怪：禁页书妖  精英：裂渊屠血将  BOSS：裂渊屠血将(王级)+镇渊魔帅噬渊血犼(皇级)
    { baseFloor = 221,
      normals = { "ch5_book_demon" },
      elites  = { "ch5_blood_general" },
      bosses  = { "ch5_blood_general", "ch5_abyss_marshal" },
      bossName = "裂渊屠血将+镇渊魔帅（地刺）" },

    -- ── 大乘后期后（231-240层）· 魔帅巡狩 ──
    -- 小怪：禁页书妖  精英：裂渊屠血将  BOSS：魔帅噬骨+魔帅裂魂（皇级×2）
    { baseFloor = 231,
      normals = { "ch5_book_demon" },
      elites  = { "ch5_blood_general" },
      bosses  = { "ch5_marshal_shugu", "ch5_marshal_liesoul" },
      bossName = "魔帅·噬骨+魔帅·裂魂（地刺）" },

    -- ── 大乘巅峰前（241-250层）· 剑宫外阵 ──
    -- 小怪：禁页书妖  精英：裂渊屠血将  BOSS：镇渊魔帅(皇级)+剑宫执旗剑朱(圣级)
    { baseFloor = 241,
      normals = { "ch5_book_demon" },
      elites  = { "ch5_blood_general" },
      bosses  = { "ch5_abyss_marshal", "ch5_sword_zhu" },
      bossName = "镇渊魔帅+剑宫执旗·剑朱（地刺）" },

    -- ── 大乘巅峰后（251-260层）· 四剑封台 ──
    -- 小怪：禁页书妖  精英：裂渊屠血将  BOSS：剑鲜+剑鹿+剑绝（圣级×3）
    { baseFloor = 251,
      normals = { "ch5_book_demon" },
      elites  = { "ch5_blood_general" },
      bosses  = { "ch5_sword_xian", "ch5_sword_lu", "ch5_sword_jue" },
      bossName = "四剑封台·三圣（地刺）" },
}

-- 自动生成260层配置
TrialTowerConfig.FLOOR_MONSTERS = {}
for _, theme in ipairs(FLOOR_THEMES) do
    local block = GenerateFloorBlock(theme)
    for floor, cfg in pairs(block) do
        TrialTowerConfig.FLOOR_MONSTERS[floor] = cfg
    end
end

-- ============================================================================
-- 怪物生成布局
-- ============================================================================

--- 计算环形布局的生成位置
---@param arenaSize number 竞技场内部尺寸
---@param count number 怪物数量
---@param radius number 环形半径
---@param angleOffset number 角度偏移（弧度）
---@return table positions { {x, y}, ... }
function TrialTowerConfig.CalcCirclePositions(arenaSize, count, radius, angleOffset)
    local cx = arenaSize / 2 + 1  -- 加1是墙壁偏移
    local cy = arenaSize / 2 + 1
    local positions = {}
    for i = 1, count do
        local angle = angleOffset + (i - 1) * (2 * math.pi / count)
        local x = cx + radius * math.cos(angle)
        local y = cy + radius * math.sin(angle)
        -- 钳制在可行走区域内（避免刷在墙壁上）
        x = math.max(2.5, math.min(arenaSize + 0.5, x))
        y = math.max(2.5, math.min(arenaSize + 0.5, y))
        table.insert(positions, { x = x, y = y })
    end
    return positions
end

--- 计算BOSS对称布局的生成位置（支持2~3只BOSS）
---@param arenaSize number
---@param count number|nil BOSS数量，默认2
---@return table positions { {x, y}, ... }
function TrialTowerConfig.CalcBossPositions(arenaSize, count)
    local cx = arenaSize / 2 + 1
    local cy = arenaSize / 2 + 1
    local n = count or 2
    if n >= 3 then
        return {
            { x = cx - 2.5, y = cy - 3.0 },  -- 左BOSS
            { x = cx + 2.5, y = cy - 3.0 },  -- 右BOSS
            { x = cx,       y = cy - 1.0 },  -- 中BOSS（稍后方）
        }
    end
    return {
        { x = cx - 1.5, y = cy - 3.0 },  -- 左BOSS
        { x = cx + 1.5, y = cy - 3.0 },  -- 右BOSS
    }
end

return TrialTowerConfig
