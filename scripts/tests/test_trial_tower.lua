-- ============================================================================
-- test_trial_tower.lua — 青云试炼（试炼塔）配置与公式 模拟测试
--
-- 覆盖场景：
--   TEST 1:  REALMS 表完整性（1-26 全覆盖，无空洞）
--   TEST 2:  GetRealmByFloor 边界与连续性（1-260 穷举）
--   TEST 3:  CalcMonsterLevel 等级范围验证（每个 REALM 段）
--   TEST 4:  FLOOR_MONSTERS 完整性（1-260 全层有配置）
--   TEST 5:  FLOOR_MONSTERS 怪物 ID 非空验证
--   TEST 6:  BOSS 层（第10层）每段验证
--   TEST 7:  CalcFirstClearReward 单调递增验证（realmIndex 维度）
--   TEST 8:  CalcDailyRewardByTier 公式验证（tier 1-26 逐一对照设计文档）
--   TEST 9:  GetDailyTier 边界验证
--   TEST 10: 大乘段（181-260）境界 ID 正确性
--   TEST 11: 251-260 三BOSS关卡验证
--   TEST 12: CalcBossPositions 2/3 BOSS 出生点数量验证
--   PERF 1:  260 层完整遍历基准（时间 < 50ms）
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

local function assert_false(cond, testName)
    assert_eq(cond, false, testName)
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
    -- 期望 MAX_DAILY_TIER = 26
    assert_eq(TrialTowerConfig.MAX_DAILY_TIER, 26, "MAX_DAILY_TIER == 26")

    -- 所有 REALMS[1..26] 必须存在
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

    -- 大乘段 id 配对校验
    local pairExpected = {
        [19] = "dacheng_1", [20] = "dacheng_1",
        [21] = "dacheng_2", [22] = "dacheng_2",
        [23] = "dacheng_3", [24] = "dacheng_3",
        [25] = "dacheng_4", [26] = "dacheng_4",
    }
    for idx, expectedId in pairs(pairExpected) do
        local realm = TrialTowerConfig.REALMS[idx]
        if realm then
            assert_eq(realm.id, expectedId, "REALMS[" .. idx .. "].id == " .. expectedId)
        end
    end
end

print("=== TEST 2: GetRealmByFloor 边界与连续性（1-260 穷举）===")
do
    -- 每一层都必须能找到对应 realm
    for floor = 1, 260 do
        local realm, realmIdx = TrialTowerConfig.GetRealmByFloor(floor)
        assert_not_nil(realm,    "floor " .. floor .. " realm 非空")
        assert_not_nil(realmIdx, "floor " .. floor .. " realmIdx 非空")
        if realm then
            -- realmIndex 应等于 ceil(floor/10)
            local expected = math.ceil(floor / 10)
            assert_eq(realmIdx, expected, "floor " .. floor .. " realmIdx = " .. expected)
        end
    end

    -- 边界: 超出 260 层应返回 nil
    local realmOut, _ = TrialTowerConfig.GetRealmByFloor(261)
    assert_eq(realmOut, nil, "floor 261 realm == nil（超范围）")

    -- 边界: 第1层
    local r1, ri1 = TrialTowerConfig.GetRealmByFloor(1)
    assert_eq(ri1, 1, "floor 1 realmIdx == 1")
    assert_eq(r1.id, "lianqi_1", "floor 1 realm.id == lianqi_1")

    -- 边界: 第180层
    local r180, ri180 = TrialTowerConfig.GetRealmByFloor(180)
    assert_eq(ri180, 18, "floor 180 realmIdx == 18")

    -- 边界: 第181层（大乘开始）
    local r181, ri181 = TrialTowerConfig.GetRealmByFloor(181)
    assert_eq(ri181, 19, "floor 181 realmIdx == 19")
    assert_eq(r181.id, "dacheng_1", "floor 181 realm.id == dacheng_1")

    -- 边界: 第260层
    local r260, ri260 = TrialTowerConfig.GetRealmByFloor(260)
    assert_eq(ri260, 26, "floor 260 realmIdx == 26")
    assert_eq(r260.id, "dacheng_4", "floor 260 realm.id == dacheng_4")
end

print("=== TEST 3: CalcMonsterLevel 等级范围验证 ===")
do
    -- 每段 REALM 的 reqLevel 和 maxLevel 边界验证
    local expectations = {
        -- { floorFirst, floorLast, minLv, maxLv }
        { 1,   10,  10, 20  },
        { 11,  20,  20, 25  },
        { 171, 180, 95, 100 },
        -- 大乘段
        { 181, 190, 100, 120 },
        { 191, 200, 100, 120 },
        { 201, 210, 105, 120 },
        { 211, 220, 105, 120 },
        { 221, 230, 110, 120 },
        { 231, 240, 110, 120 },
        { 241, 250, 115, 120 },
        { 251, 260, 115, 120 },
    }
    for _, exp in ipairs(expectations) do
        local f1, f10, minLv, maxLv = exp[1], exp[2], exp[3], exp[4]
        local lv1  = TrialTowerConfig.CalcMonsterLevel(f1)
        local lv10 = TrialTowerConfig.CalcMonsterLevel(f10)
        assert_range(lv1,  minLv, maxLv, "floor " .. f1  .. " level in [" .. minLv .. "," .. maxLv .. "]")
        assert_range(lv10, minLv, maxLv, "floor " .. f10 .. " level in [" .. minLv .. "," .. maxLv .. "]")
        -- 同段内应单调递增
        assert_true(lv10 >= lv1, "floor " .. f1 .. "-" .. f10 .. " 等级单调递增")
    end

    -- 大乘中期前第1层 level >= 105
    local lv201 = TrialTowerConfig.CalcMonsterLevel(201)
    assert_range(lv201, 105, 120, "floor 201 level in [105,120]")

    -- 最后一层 260 的等级
    local lv260 = TrialTowerConfig.CalcMonsterLevel(260)
    assert_eq(lv260, 120, "floor 260 level == 120 (maxLevel)")
end

print("=== TEST 4: FLOOR_MONSTERS 完整性（1-260 全层）===")
do
    local totalFloors = 0
    for floor = 1, 260 do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        if cfg then
            totalFloors = totalFloors + 1
        else
            totalTests = totalTests + 1
            failed = failed + 1
            print("  FAIL: FLOOR_MONSTERS[" .. floor .. "] 缺失")
        end
    end
    assert_eq(totalFloors, 260, "FLOOR_MONSTERS 共 260 层配置")
end

print("=== TEST 5: FLOOR_MONSTERS 怪物 ID 非空验证 ===")
do
    -- 抽查关键层
    local checkFloors = { 1, 10, 100, 180, 181, 190, 191, 200, 201, 210,
                          211, 220, 221, 230, 231, 240, 241, 250, 251, 260 }
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
    for i = 1, 26 do
        table.insert(bossFloors, i * 10)
    end
    for _, floor in ipairs(bossFloors) do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        assert_not_nil(cfg, "BOSS层 floor " .. floor .. " 存在")
        if cfg then
            assert_true(cfg.isBoss == true, "floor " .. floor .. " isBoss == true")
            assert_true(cfg.bossGroundSpike == true, "floor " .. floor .. " bossGroundSpike == true")
            assert_not_nil(cfg.bossName, "floor " .. floor .. " bossName 非空")
            -- BOSS层应有 1~3 只 BOSS
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

print("=== TEST 7: CalcFirstClearReward 单调递增验证 ===")
do
    -- 比较各 realmIndex 的第10层奖励（即最高层）应单调递增
    local prevLingYun = 0
    for ri = 1, 26 do
        local floor = ri * 10
        local ly, gb = TrialTowerConfig.CalcFirstClearReward(floor)
        assert_true(ly >= prevLingYun, "realm " .. ri .. " 第10层灵韵(" .. ly .. ") >= 上段(" .. prevLingYun .. ")")
        assert_true(gb > 0, "realm " .. ri .. " 第10层金条 > 0")
        prevLingYun = ly
    end
end

print("=== TEST 8: CalcDailyRewardByTier 公式验证（对照设计文档）===")
do
    -- 设计文档明确给出的值（tier 19-26）
    local docValues = {
        [19] = { lingYun = 84,  goldBar = 42 },
        [20] = { lingYun = 88,  goldBar = 44 },
        [21] = { lingYun = 92,  goldBar = 46 },
        [22] = { lingYun = 96,  goldBar = 48 },
        [23] = { lingYun = 100, goldBar = 50 },
        [24] = { lingYun = 104, goldBar = 52 },
        [25] = { lingYun = 108, goldBar = 54 },
        [26] = { lingYun = 112, goldBar = 56 },
    }
    for tier, expected in pairs(docValues) do
        local ly, gb = TrialTowerConfig.CalcDailyRewardByTier(tier)
        assert_eq(ly, expected.lingYun, "tier " .. tier .. " 灵韵 == " .. expected.lingYun)
        assert_eq(gb, expected.goldBar, "tier " .. tier .. " 金条 == " .. expected.goldBar)
    end

    -- 公式正确性：tier 1-18 也应符合 (tier*2+4)*2 / (tier+2)*2
    for tier = 1, 18 do
        local ly, gb = TrialTowerConfig.CalcDailyRewardByTier(tier)
        local expectedLy = (tier * 2 + 4) * 2
        local expectedGb = (tier + 2) * 2
        assert_eq(ly, expectedLy, "tier " .. tier .. " 灵韵公式验证")
        assert_eq(gb, expectedGb, "tier " .. tier .. " 金条公式验证")
    end

    -- 越界：tier = 0 和 tier = 27 应返回 0,0
    local ly0, gb0 = TrialTowerConfig.CalcDailyRewardByTier(0)
    assert_eq(ly0, 0, "tier 0 灵韵 == 0")
    assert_eq(gb0, 0, "tier 0 金条 == 0")

    local ly27, gb27 = TrialTowerConfig.CalcDailyRewardByTier(27)
    assert_eq(ly27, 0, "tier 27 灵韵 == 0（超出上限）")
    assert_eq(gb27, 0, "tier 27 金条 == 0（超出上限）")

    -- 每日奖励单调递增
    local prevLy = 0
    for tier = 1, 26 do
        local ly, _ = TrialTowerConfig.CalcDailyRewardByTier(tier)
        assert_true(ly > prevLy, "tier " .. tier .. " 灵韵(" .. ly .. ") > 上档(" .. prevLy .. ")")
        prevLy = ly
    end
end

print("=== TEST 9: GetDailyTier 边界验证 ===")
do
    -- 未解锁（< 10层）
    assert_eq(TrialTowerConfig.GetDailyTier(0),  0, "highestFloor=0 → tier=0")
    assert_eq(TrialTowerConfig.GetDailyTier(9),  0, "highestFloor=9 → tier=0")
    -- 刚解锁
    assert_eq(TrialTowerConfig.GetDailyTier(10), 1, "highestFloor=10 → tier=1")
    -- 中间段
    assert_eq(TrialTowerConfig.GetDailyTier(100), 10, "highestFloor=100 → tier=10")
    assert_eq(TrialTowerConfig.GetDailyTier(180), 18, "highestFloor=180 → tier=18")
    -- 大乘段
    assert_eq(TrialTowerConfig.GetDailyTier(190), 19, "highestFloor=190 → tier=19")
    assert_eq(TrialTowerConfig.GetDailyTier(200), 20, "highestFloor=200 → tier=20")
    assert_eq(TrialTowerConfig.GetDailyTier(260), 26, "highestFloor=260 → tier=26")
    -- 超过 260：上限钳制到 26
    assert_eq(TrialTowerConfig.GetDailyTier(300), 26, "highestFloor=300 → tier=26（上限钳制）")
end

print("=== TEST 10: 大乘段境界 ID 正确性 ===")
do
    local segments = {
        { floors = {181, 200}, expectedId = "dacheng_1" },
        { floors = {201, 220}, expectedId = "dacheng_2" },
        { floors = {221, 240}, expectedId = "dacheng_3" },
        { floors = {241, 260}, expectedId = "dacheng_4" },
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
    -- 第260层（第26段第10层）应为3BOSS关卡
    local cfg260 = TrialTowerConfig.FLOOR_MONSTERS[260]
    assert_not_nil(cfg260, "FLOOR_MONSTERS[260] 存在")
    if cfg260 then
        assert_true(cfg260.isBoss == true, "floor 260 isBoss == true")
        assert_eq(cfg260.comp, "3B", "floor 260 comp == '3B'（三BOSS）")
        assert_not_nil(cfg260.monsters, "floor 260 monsters 非空")
        if cfg260.monsters then
            assert_eq(#cfg260.monsters, 3, "floor 260 monsters 数量 == 3")
            -- 验证三个 BOSS ID
            local bossIds = {}
            for _, m in ipairs(cfg260.monsters) do
                bossIds[m.id] = true
            end
            assert_true(bossIds["ch5_sword_xian"] == true, "floor 260 含 ch5_sword_xian")
            assert_true(bossIds["ch5_sword_lu"]   == true, "floor 260 含 ch5_sword_lu")
            assert_true(bossIds["ch5_sword_jue"]  == true, "floor 260 含 ch5_sword_jue")
        end
    end

    -- 对比：第250层（双BOSS）
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
    -- 2个BOSS（默认）
    local pos2 = TrialTowerConfig.CalcBossPositions(arenaSize)
    assert_eq(#pos2, 2, "CalcBossPositions(2) 返回 2 个位置")

    -- 3个BOSS（四剑封台）
    local pos3 = TrialTowerConfig.CalcBossPositions(arenaSize, 3)
    assert_eq(#pos3, 3, "CalcBossPositions(3) 返回 3 个位置")

    -- 出生点在竞技场范围内
    local function inArena(p)
        return p.x >= 1 and p.x <= arenaSize + 2 and p.y >= 1 and p.y <= arenaSize + 2
    end
    for i, p in ipairs(pos3) do
        assert_true(inArena(p), "3BOSS 出生点[" .. i .. "] 在竞技场范围内")
    end
    -- 三个位置互不相同
    assert_true(pos3[1].x ~= pos3[2].x or pos3[1].y ~= pos3[2].y, "3BOSS 出生点[1]≠[2]")
    assert_true(pos3[1].x ~= pos3[3].x or pos3[1].y ~= pos3[3].y, "3BOSS 出生点[1]≠[3]")
    assert_true(pos3[2].x ~= pos3[3].x or pos3[2].y ~= pos3[3].y, "3BOSS 出生点[2]≠[3]")
end

print("=== PERF 1: 260 层完整遍历基准 ===")
do
    local startTime = os.clock()
    local count = 0
    for floor = 1, 260 do
        local cfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
        if cfg and cfg.monsters then
            for _, m in ipairs(cfg.monsters) do
                count = count + m.count
            end
        end
        TrialTowerConfig.CalcMonsterLevel(floor)
        TrialTowerConfig.CalcFirstClearReward(floor)
    end
    local elapsed = (os.clock() - startTime) * 1000  -- ms
    totalTests = totalTests + 1
    if elapsed < 50 then
        passed = passed + 1
        print("  PASS: 260 层完整遍历耗时 " .. string.format("%.2f", elapsed) .. "ms < 50ms")
    else
        failed = failed + 1
        print("  FAIL: 260 层完整遍历耗时 " .. string.format("%.2f", elapsed) .. "ms >= 50ms（性能回归）")
    end
    print("  INFO: 260 层怪物总召唤数 = " .. count)
end

-- ─────────────────────────────────────────────
-- 汇总
-- ─────────────────────────────────────────────
print(string.rep("─", 50))
print(string.format("结果: %d/%d 通过  失败: %d", passed, totalTests, failed))
if failed == 0 then
    print("✓ 全部测试通过")
else
    print("✗ 有测试失败，请检查上方 FAIL 项")
end

return { passed = passed, failed = failed, total = totalTests }
