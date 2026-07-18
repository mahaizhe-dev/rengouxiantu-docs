-- ============================================================================
-- test_trial_tower.lua — 青云试炼（试炼塔）配置与公式 模拟测试
--
-- 覆盖场景：
--   TEST 1:  REALMS 表完整性（1-26 全覆盖，无空洞）
--   TEST 2:  GetRealmByFloor 边界与连续性（1-300 穷举）
--   TEST 3:  CalcMonsterLevel 等级范围验证（每个 REALM 段）
--   TEST 4:  FLOOR_MONSTERS 完整性（1-300 全层有配置）
--   TEST 5:  FLOOR_MONSTERS 怪物 ID 非空验证
--   TEST 6:  BOSS 层（第10层）每段验证
--   TEST 7:  CalcFirstClearReward 交替增长与目标锚点验证
--   TEST 8:  CalcDailyRewardByTier 等于对应10层首通奖励
--   TEST 9:  GetDailyTier 边界验证
--   TEST 10: 大乘/仙阶段境界 ID 正确性
--   TEST 11: 251-260 三BOSS关卡验证
--   TEST 12: CalcBossPositions 2/3 BOSS 出生点数量验证
--   TEST 13: 第六章 261-300 怪物主题验证
--   TEST 14: BOSS 专属等级/境界覆盖规则验证
--   PERF 1:  300 层完整遍历基准（时间 < 50ms）
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

-- ─────────────────────────────────────────────
-- 断言工具
-- ─────────────────────────────────────────────

local function assert_eq(actual, expected, testName)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName)
        print("    expected: " .. tostring(expected))
        print("    actual:   " .. tostring(actual))
    end
end

local function assert_true(cond, testName)
    assert_eq(cond, true, testName)
end

local function assert_range(val, lo, hi, testName)
    totalTests = totalTests + 1
    if val >= lo and val <= hi then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName)
        print("    expected range: [" .. lo .. ", " .. hi .. "]")
        print("    actual: " .. tostring(val))
    end
end

local function assert_not_nil(val, testName)
    totalTests = totalTests + 1
    if val ~= nil then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName .. " (got nil)")
    end
end

-- ─────────────────────────────────────────────
-- 加载配置
-- ─────────────────────────────────────────────

local TrialTowerConfig = require("config.TrialTowerConfig")

print("=== TEST 1: REALMS 表完整性（1-26 全覆盖）===")
do
    assert_eq(TrialTowerConfig.MAX_DAILY_TIER, 30, "MAX_DAILY_TIER == 30")
    assert_eq(TrialTowerConfig.MAX_FLOOR, 300, "MAX_FLOOR == 300")

    for i = 1, 26 do
        local realm = TrialTowerConfig.REALMS[i]
        assert_not_nil(realm, "REALMS[" .. i .. "] 存在")
        if realm then
            assert_not_nil(realm.id,       "REALMS[" .. i .. "].id 非空")
            assert_not_nil(realm.name,     "REALMS[" .. i .. "].name 非空")
            assert_not_nil(realm.floors,   "REALMS[" .. i .. "].floors 非空")
            assert_not_nil(realm.reqLevel, "REALMS[" .. i .. "].reqLevel 非空")
            assert_not_nil(realm.maxLevel, "REALMS[" .. i .. "].maxLevel 非空")
        end
    end

    local pairExpected = {
        [19] = "dacheng_1", [20] = "dacheng_2", [21] = "dacheng_3", [22] = "dacheng_4",
        [23] = "zhexian_1", [24] = "zhexian_4", [25] = "zhexian_7", [26] = "zhexian_9",
    }
    for idx, expectedId in pairs(pairExpected) do
        local realm = TrialTowerConfig.REALMS[idx]
        if realm then
            assert_eq(realm.id, expectedId, "REALMS[" .. idx .. "].id == " .. expectedId)
        end
    end
end

print("=== TEST 2: GetRealmByFloor 边界与连续性（1-300 穷举）===")
do
    for floor = 1, 300 do
        local realm, realmIdx = TrialTowerConfig.GetRealmByFloor(floor)
        assert_not_nil(realm,    "floor " .. floor .. " realm 非空")
        assert_not_nil(realmIdx, "floor " .. floor .. " realmIdx 非空")
        if realm then
            local expected
            if floor <= 180 then
                expected = math.ceil(floor / 10)
            elseif floor <= 260 then
                expected = 18 + math.ceil((floor - 180) / 20)
            else
                expected = 22 + math.ceil((floor - 260) / 10)
            end
            assert_eq(realmIdx, expected, "floor " .. floor .. " realmIdx = " .. expected)
        end
    end

    local realmOut, _ = TrialTowerConfig.GetRealmByFloor(301)
    assert_eq(realmOut, nil, "floor 301 realm == nil（超范围）")

    local r1, ri1 = TrialTowerConfig.GetRealmByFloor(1)
    assert_eq(ri1, 1, "floor 1 realmIdx == 1")
    assert_eq(r1.id, "lianqi_1", "floor 1 realm.id == lianqi_1")

    local r180, ri180 = TrialTowerConfig.GetRealmByFloor(180)
    assert_eq(ri180, 18, "floor 180 realmIdx == 18")

    local r181, ri181 = TrialTowerConfig.GetRealmByFloor(181)
    assert_eq(ri181, 19, "floor 181 realmIdx == 19")
    assert_eq(r181.id, "dacheng_1", "floor 181 realm.id == dacheng_1")

    local r260, ri260 = TrialTowerConfig.GetRealmByFloor(260)
    assert_eq(ri260, 22, "floor 260 realmIdx == 22")
    assert_eq(r260.id, "dacheng_4", "floor 260 realm.id == dacheng_4")

    local r261, ri261 = TrialTowerConfig.GetRealmByFloor(261)
    assert_eq(ri261, 23, "floor 261 realmIdx == 23")
    assert_eq(r261.id, "zhexian_1", "floor 261 realm.id == zhexian_1")

    local requiredOrders = {
        [260] = 22,
        [261] = 23,
        [270] = 23,
        [271] = 26,
        [280] = 26,
        [281] = 29,
        [290] = 29,
        [291] = 31,
        [300] = 31,
    }
    for floor, expectedOrder in pairs(requiredOrders) do
        assert_eq(TrialTowerConfig.GetRequiredOrderByFloor(floor), expectedOrder,
            "floor " .. floor .. " requiredOrder == " .. expectedOrder)
    end
end

print("=== TEST 3: CalcMonsterLevel 等级范围验证 ===")
do
    local expectations = {
        { 1,   10,  10, 20  },
        { 11,  20,  20, 25  },
        { 171, 180, 95, 100 },
        { 181, 200, 100, 120 },
        { 201, 220, 105, 120 },
        { 221, 240, 110, 120 },
        { 241, 260, 115, 120 },
        { 261, 270, 121, 126 },
        { 271, 280, 127, 132 },
        { 281, 290, 133, 138 },
        { 291, 300, 139, 140 },
    }
    for _, exp in ipairs(expectations) do
        local f1, f10, minLv, maxLv = exp[1], exp[2], exp[3], exp[4]
        local lv1  = TrialTowerConfig.CalcMonsterLevel(f1)
        local lv10 = TrialTowerConfig.CalcMonsterLevel(f10)
        assert_range(lv1,  minLv, maxLv, "floor " .. f1  .. " level in [" .. minLv .. "," .. maxLv .. "]")
        assert_range(lv10, minLv, maxLv, "floor " .. f10 .. " level in [" .. minLv .. "," .. maxLv .. "]")
        assert_true(lv10 >= lv1, "floor " .. f1 .. "-" .. f10 .. " 等级单调递增")
    end

    assert_eq(TrialTowerConfig.CalcMonsterLevel(260), 120, "floor 260 level == 120")
    assert_eq(TrialTowerConfig.CalcMonsterLevel(300), 140, "floor 300 level == 140")
end

print("=== TEST 4: FLOOR_MONSTERS 完整性（1-300 全层）===")
do
    local totalFloors = 0
    for floor = 1, 300 do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        if cfg then
            totalFloors = totalFloors + 1
        else
            totalTests = totalTests + 1
            failed = failed + 1
            print("  FAIL: FLOOR_MONSTERS[" .. floor .. "] 缺失")
        end
    end
    assert_eq(totalFloors, 300, "FLOOR_MONSTERS 共 300 层配置")
end

print("=== TEST 5: FLOOR_MONSTERS 怪物 ID 非空验证 ===")
do
    local checkFloors = { 1, 10, 100, 180, 181, 190, 200, 210, 220, 230, 240, 250, 260,
                          261, 270, 271, 280, 281, 290, 291, 300 }
    for _, floor in ipairs(checkFloors) do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        assert_not_nil(cfg, "FLOOR_MONSTERS[" .. floor .. "] 非空")
        if cfg then
            assert_not_nil(cfg.monsters, "FLOOR_MONSTERS[" .. floor .. "].monsters 非空")
            assert_true(cfg.level > 0, "FLOOR_MONSTERS[" .. floor .. "].level > 0")
            if cfg.monsters then
                for _, m in ipairs(cfg.monsters) do
                    assert_not_nil(m.id,    "floor " .. floor .. " monster.id 非空")
                    assert_true(m.count > 0, "floor " .. floor .. " monster.count > 0")
                end
            end
        end
    end
end

print("=== TEST 6: BOSS 层验证（每段第10层）===")
do
    local bossFloors = {}
    for i = 1, 30 do
        table.insert(bossFloors, i * 10)
    end
    for _, floor in ipairs(bossFloors) do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        assert_not_nil(cfg, "BOSS层 floor " .. floor .. " 存在")
        if cfg then
            assert_true(cfg.isBoss == true, "floor " .. floor .. " isBoss == true")
            assert_true(cfg.bossGroundSpike == true, "floor " .. floor .. " bossGroundSpike == true")
            assert_not_nil(cfg.bossName, "floor " .. floor .. " bossName 非空")
            if cfg.monsters then
                local total = 0
                for _, m in ipairs(cfg.monsters) do
                    total = total + m.count
                end
                assert_range(total, 1, 3, "BOSS层 floor " .. floor .. " BOSS数量 1-3")
            end
        end
    end
end

print("=== TEST 7: CalcFirstClearReward 交替增长与目标锚点验证 ===")
do
    local anchors = {
        [1]   = { lingYun = 1,   goldBar = 0   },
        [2]   = { lingYun = 1,   goldBar = 1   },
        [3]   = { lingYun = 2,   goldBar = 1   },
        [10]  = { lingYun = 5,   goldBar = 5   },
        [100] = { lingYun = 50,  goldBar = 50  },
        [200] = { lingYun = 100, goldBar = 100 },
        [300] = { lingYun = 150, goldBar = 150 },
    }
    for floor, expected in pairs(anchors) do
        local ly, gb = TrialTowerConfig.CalcFirstClearReward(floor)
        assert_eq(ly, expected.lingYun, "floor " .. floor .. " 首通灵韵 == " .. expected.lingYun)
        assert_eq(gb, expected.goldBar, "floor " .. floor .. " 首通金条 == " .. expected.goldBar)
    end

    for floor = 2, 300 do
        local prevLy, prevGb = TrialTowerConfig.CalcFirstClearReward(floor - 1)
        local ly, gb = TrialTowerConfig.CalcFirstClearReward(floor)
        if floor % 2 == 1 then
            assert_eq(ly, prevLy + 1, "奇数层 floor " .. floor .. " 灵韵较上一层 +1")
            assert_eq(gb, prevGb, "奇数层 floor " .. floor .. " 金条不变")
        else
            assert_eq(ly, prevLy, "偶数层 floor " .. floor .. " 灵韵不变")
            assert_eq(gb, prevGb + 1, "偶数层 floor " .. floor .. " 金条较上一层 +1")
        end
    end
end

print("=== TEST 8: CalcDailyRewardByTier 等于对应10层首通奖励 ===")
do
    local docValues = {
        [10] = { lingYun = 50,  goldBar = 50  },
        [20] = { lingYun = 100, goldBar = 100 },
        [30] = { lingYun = 150, goldBar = 150 },
    }
    for tier = 1, 30 do
        local dailyLy, dailyGb = TrialTowerConfig.CalcDailyRewardByTier(tier)
        local firstLy, firstGb = TrialTowerConfig.CalcFirstClearReward(tier * 10)
        assert_eq(dailyLy, firstLy, "tier " .. tier .. " 每日灵韵 == " .. (tier * 10) .. "层首通灵韵")
        assert_eq(dailyGb, firstGb, "tier " .. tier .. " 每日金条 == " .. (tier * 10) .. "层首通金条")
        if docValues[tier] then
            assert_eq(dailyLy, docValues[tier].lingYun, "tier " .. tier .. " 目标灵韵 == " .. docValues[tier].lingYun)
            assert_eq(dailyGb, docValues[tier].goldBar, "tier " .. tier .. " 目标金条 == " .. docValues[tier].goldBar)
        end
    end

    local ly0, gb0 = TrialTowerConfig.CalcDailyRewardByTier(0)
    assert_eq(ly0, 0, "tier 0 灵韵 == 0")
    assert_eq(gb0, 0, "tier 0 金条 == 0")

    local ly31, gb31 = TrialTowerConfig.CalcDailyRewardByTier(31)
    assert_eq(ly31, 0, "tier 31 灵韵 == 0（超出上限）")
    assert_eq(gb31, 0, "tier 31 金条 == 0（超出上限）")

    local prevLy = 0
    local prevGb = 0
    for tier = 1, 30 do
        local ly, gb = TrialTowerConfig.CalcDailyRewardByTier(tier)
        assert_true(ly > prevLy, "tier " .. tier .. " 灵韵(" .. ly .. ") > 上档(" .. prevLy .. ")")
        assert_true(gb > prevGb, "tier " .. tier .. " 金条(" .. gb .. ") > 上档(" .. prevGb .. ")")
        prevLy = ly
        prevGb = gb
    end
end

print("=== TEST 9: GetDailyTier 边界验证 ===")
do
    assert_eq(TrialTowerConfig.GetDailyTier(0),  0, "highestFloor=0 → tier=0")
    assert_eq(TrialTowerConfig.GetDailyTier(9),  0, "highestFloor=9 → tier=0")
    assert_eq(TrialTowerConfig.GetDailyTier(10), 1, "highestFloor=10 → tier=1")
    assert_eq(TrialTowerConfig.GetDailyTier(100), 10, "highestFloor=100 → tier=10")
    assert_eq(TrialTowerConfig.GetDailyTier(180), 18, "highestFloor=180 → tier=18")
    assert_eq(TrialTowerConfig.GetDailyTier(190), 19, "highestFloor=190 → tier=19")
    assert_eq(TrialTowerConfig.GetDailyTier(200), 20, "highestFloor=200 → tier=20")
    assert_eq(TrialTowerConfig.GetDailyTier(260), 26, "highestFloor=260 → tier=26")
    assert_eq(TrialTowerConfig.GetDailyTier(270), 27, "highestFloor=270 → tier=27")
    assert_eq(TrialTowerConfig.GetDailyTier(300), 30, "highestFloor=300 → tier=30")
    assert_eq(TrialTowerConfig.GetDailyTier(330), 30, "highestFloor=330 → tier=30（上限钳制）")
end

print("=== TEST 10: 大乘/仙阶段境界 ID 正确性 ===")
do
    local segments = {
        { floors = {181, 200}, expectedId = "dacheng_1" },
        { floors = {201, 220}, expectedId = "dacheng_2" },
        { floors = {221, 240}, expectedId = "dacheng_3" },
        { floors = {241, 260}, expectedId = "dacheng_4" },
        { floors = {261, 270}, expectedId = "zhexian_1" },
        { floors = {271, 280}, expectedId = "zhexian_4" },
        { floors = {281, 290}, expectedId = "zhexian_7" },
        { floors = {291, 300}, expectedId = "zhexian_9" },
    }
    for _, seg in ipairs(segments) do
        for floor = seg.floors[1], seg.floors[2] do
            local realm = TrialTowerConfig.GetRealmByFloor(floor)
            if realm then
                assert_eq(realm.id, seg.expectedId,
                    "floor " .. floor .. " realm.id == " .. seg.expectedId)
            end
        end
    end
end

print("=== TEST 11: 251-260 三BOSS关卡验证 ===")
do
    local cfg260 = TrialTowerConfig.FLOOR_MONSTERS[260]
    assert_not_nil(cfg260, "FLOOR_MONSTERS[260] 存在")
    if cfg260 then
        assert_true(cfg260.isBoss == true, "floor 260 isBoss == true")
        assert_eq(cfg260.comp, "3B", "floor 260 comp == '3B'（三BOSS）")
        assert_not_nil(cfg260.monsters, "floor 260 monsters 非空")
        if cfg260.monsters then
            assert_eq(#cfg260.monsters, 3, "floor 260 monsters 数量 == 3")
            local bossIds = {}
            for _, m in ipairs(cfg260.monsters) do
                bossIds[m.id] = true
            end
            assert_true(bossIds["ch5_sword_xian"] == true, "floor 260 含 ch5_sword_xian")
            assert_true(bossIds["ch5_sword_lu"]   == true, "floor 260 含 ch5_sword_lu")
            assert_true(bossIds["ch5_sword_jue"]  == true, "floor 260 含 ch5_sword_jue")
        end
    end

    local cfg250 = TrialTowerConfig.FLOOR_MONSTERS[250]
    assert_not_nil(cfg250, "FLOOR_MONSTERS[250] 存在")
    if cfg250 then
        assert_true(cfg250.isBoss == true, "floor 250 isBoss == true")
        assert_eq(cfg250.comp, "2B", "floor 250 comp == '2B'（双BOSS）")
    end
end

print("=== TEST 12: CalcBossPositions 出生点数量验证 ===")
do
    local arenaSize = TrialTowerConfig.ARENA_SIZE
    local pos2 = TrialTowerConfig.CalcBossPositions(arenaSize)
    assert_eq(#pos2, 2, "CalcBossPositions(2) 返回 2 个位置")

    local pos3 = TrialTowerConfig.CalcBossPositions(arenaSize, 3)
    assert_eq(#pos3, 3, "CalcBossPositions(3) 返回 3 个位置")

    local function inArena(p)
        return p.x >= 1 and p.x <= arenaSize + 2 and p.y >= 1 and p.y <= arenaSize + 2
    end
    for i, p in ipairs(pos3) do
        assert_true(inArena(p), "3BOSS 出生点[" .. i .. "] 在竞技场范围内")
    end
    assert_true(pos3[1].x ~= pos3[2].x or pos3[1].y ~= pos3[2].y, "3BOSS 出生点[1]≠[2]")
    assert_true(pos3[1].x ~= pos3[3].x or pos3[1].y ~= pos3[3].y, "3BOSS 出生点[1]≠[3]")
    assert_true(pos3[2].x ~= pos3[3].x or pos3[2].y ~= pos3[3].y, "3BOSS 出生点[2]≠[3]")
end

print("=== TEST 13: 第六章 261-300 怪物主题验证 ===")
do
    local expectedBosses = {
        [270] = { "ch6_lingfeng", "ch6_zhuyou" },
        [280] = { "ch6_duanyue", "ch6_zhuyou" },
        [290] = { "ch6_pojun", "ch6_qingfeng" },
        [300] = { "ch6_gua_master", "ch6_mojun_shixuan" },
    }
    for floor, ids in pairs(expectedBosses) do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        assert_not_nil(cfg, "第六章 BOSS层 floor " .. floor .. " 存在")
        if cfg and cfg.monsters then
            assert_eq(cfg.comp, "2B", "floor " .. floor .. " comp == 2B")
            local found = {}
            for _, m in ipairs(cfg.monsters) do found[m.id] = true end
            for _, id in ipairs(ids) do
                assert_true(found[id] == true, "floor " .. floor .. " 含 " .. id)
            end
        end
    end

    local expectedRealms = {
        [261] = "zhexian_1",
        [270] = "zhexian_1",
        [271] = "zhexian_4",
        [280] = "zhexian_4",
        [281] = "zhexian_7",
        [290] = "zhexian_7",
        [291] = "zhexian_9",
        [300] = "zhexian_9",
    }
    for floor, realmId in pairs(expectedRealms) do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        assert_not_nil(cfg, "第六章 floor " .. floor .. " 配置存在")
        if cfg then
            assert_eq(cfg.realm, realmId, "floor " .. floor .. " FLOOR_MONSTERS.realm == " .. realmId)
        end
    end

    local cfg261 = TrialTowerConfig.FLOOR_MONSTERS[261]
    assert_eq(cfg261.monsters[1].id, "ch6_patrol_immortal_soldier", "floor 261 第一普通怪 巡逻仙兵")
    assert_eq(cfg261.monsters[2].id, "ch6_shadow_wanderer", "floor 261 第二普通怪 影游使")

    local cfg291 = TrialTowerConfig.FLOOR_MONSTERS[291]
    assert_eq(cfg291.monsters[1].id, "ch6_toad_immortal", "floor 291 第一普通怪 蛤蟆仙人")
    assert_eq(cfg291.monsters[2].id, "ch6_east_celestial_soldier", "floor 291 第二普通怪 东营天兵")
end

print("=== TEST 14: BOSS 专属等级/境界覆盖规则验证 ===")
do
    local bossLevelCases = {
        { source = 8,   target = 20,  realm = "lianqi_3" },
        { source = 10,  target = 25,  realm = "zhuji_1" },
        { source = 12,  target = 25,  realm = "zhuji_1" },
        { source = 15,  target = 30,  realm = "zhuji_2" },
        { source = 31,  target = 45,  realm = "jindan_2" },
        { source = 65,  target = 80,  realm = "huashen_3" },
        { source = 105, target = 120, realm = "zhexian_1" },
        { source = 115, target = 130, realm = "zhexian_6" },
        { source = 132, target = 145, realm = "renxian_3" },
        { source = 137, target = 150, realm = "renxian_6" },
        { source = 140, target = 155, realm = "renxian_8" },
    }

    for _, case in ipairs(bossLevelCases) do
        local target = TrialTowerConfig.CalcBossTargetLevel(case.source)
        assert_eq(target, case.target, "BOSS Lv." .. case.source .. " targetLevel == " .. case.target)
        local realm = TrialTowerConfig.GetBossTargetRealmByLevel(target)
        assert_eq(realm, case.realm, "BOSS Lv." .. case.source .. " targetRealm == " .. case.realm)
    end

    local monsterCases = {
        { level = 16,  target = 30,  realm = "zhuji_2" },
        { level = 119, target = 130, realm = "zhexian_6" },
        { level = 128, target = 140, realm = "renxian_1" },
    }
    for _, case in ipairs(monsterCases) do
        local override = TrialTowerConfig.GetBossOverride({ level = case.level })
        assert_not_nil(override, "GetBossOverride Lv." .. case.level .. " 非空")
        if override then
            assert_eq(override.level, case.target, "GetBossOverride Lv." .. case.level .. " level")
            assert_eq(override.realm, case.realm, "GetBossOverride Lv." .. case.level .. " realm")
        end
    end
end

print("=== PERF 1: 300 层完整遍历基准 ===")
do
    local startTime = os.clock()
    local count = 0
    for floor = 1, 300 do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        if cfg and cfg.monsters then
            for _, m in ipairs(cfg.monsters) do
                count = count + m.count
            end
        end
        TrialTowerConfig.CalcMonsterLevel(floor)
        TrialTowerConfig.CalcFirstClearReward(floor)
    end
    local elapsed = (os.clock() - startTime) * 1000
    totalTests = totalTests + 1
    if elapsed < 50 then
        passed = passed + 1
        print("  PASS: 300 层完整遍历耗时 " .. string.format("%.2f", elapsed) .. "ms < 50ms")
    else
        failed = failed + 1
        print("  FAIL: 300 层完整遍历耗时 " .. string.format("%.2f", elapsed) .. "ms >= 50ms（性能回归）")
    end
    print("  INFO: 300 层怪物总召唤数 = " .. count)
end

print(string.rep("─", 50))
print(string.format("结果: %d/%d 通过  失败: %d", passed, totalTests, failed))
if failed == 0 then
    print("✓ 全部测试通过")
else
    print("✗ 有测试失败，请检查上方 FAIL 项")
end

return { passed = passed, failed = failed, total = totalTests }
