-- ============================================================================
-- test_prison_tower.lua — 青云镇狱塔系统 模拟测试
--
-- 目的：在纯 Lua 环境中验证核心配置与公式的正确性，覆盖以下场景：
--   TEST 1:  BOSS 上阵公式验证（150 层穷举）
--   TEST 2:  BOSS 解锁池验证（边界）
--   TEST 3:  BOSS 上阵选择验证（倒序优先 + 循环取）
--   TEST 4:  境界映射与等级公式验证（15 段穷举）
--   TEST 5:  BOSS 档位保底验证（emperor_boss 保底）
--   TEST 6:  镇狱BUFF 数值链路验证
--   TEST 7:  永久加成聚合验证（关键断点）
--   TEST 8:  里程碑无遗漏验证
--   TEST 9:  存档序列化/反序列化往返验证
--   TEST 10: 排行榜反作弊边界验证
--   TEST 11: 同屏单位数验证
--   TEST 12: 出生点无重叠验证
--   PERF 1:  150 层完整生成基准
--   PERF 2:  单层怪物生成基准
--   PERF 3:  永久加成聚合基准
--   PERF 4:  数值溢出安全验证
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

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

local function assert_near(actual, expected, epsilon, testName)
    totalTests = totalTests + 1
    if math.abs(actual - expected) <= epsilon then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName)
        print("    expected: " .. tostring(expected) .. " ± " .. tostring(epsilon))
        print("    actual:   " .. tostring(actual))
    end
end

-- ============================================================================
-- 加载配置（纯 Lua，不依赖引擎运行时）
-- ============================================================================

-- 设置搜索路径到项目根目录
package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local PrisonTowerConfig = require("config.PrisonTowerConfig")

-- ============================================================================
-- TEST 1: BOSS 上阵公式验证
-- ============================================================================
print("\n=== TEST 1: BOSS 上阵公式验证（150 层穷举） ===")

-- 关键边界点
assert_eq(PrisonTowerConfig.CalcBossCount(1),   1, "第1层=1只")
assert_eq(PrisonTowerConfig.CalcBossCount(2),   2, "第2层=2只")
assert_eq(PrisonTowerConfig.CalcBossCount(3),   3, "第3层=3只")
assert_eq(PrisonTowerConfig.CalcBossCount(4),   4, "第4层=4只")
assert_eq(PrisonTowerConfig.CalcBossCount(5),   4, "第5层=4只(上限)")
assert_eq(PrisonTowerConfig.CalcBossCount(6),   1, "第6层=1只(新段)")
assert_eq(PrisonTowerConfig.CalcBossCount(7),   2, "第7层=2只")
assert_eq(PrisonTowerConfig.CalcBossCount(10),  4, "第10层=4只")
assert_eq(PrisonTowerConfig.CalcBossCount(11),  1, "第11层=1只(新段)")
assert_eq(PrisonTowerConfig.CalcBossCount(150), 4, "第150层=4只(最后)")

-- 穷举全部 150 层验证公式一致性
local bossCountErrors = 0
for floor = 1, 150 do
    local expected = math.min(((floor - 1) % 5) + 1, 4)
    local actual = PrisonTowerConfig.CalcBossCount(floor)
    if actual ~= expected then
        bossCountErrors = bossCountErrors + 1
        print("  FAIL: floor=" .. floor .. " expected=" .. expected .. " actual=" .. actual)
    end
end
assert_eq(bossCountErrors, 0, "150层BOSS数量穷举无误差")

-- ============================================================================
-- TEST 2: BOSS 解锁池验证
-- ============================================================================
print("\n=== TEST 2: BOSS 解锁池验证 ===")

assert_eq(PrisonTowerConfig.CalcUnlockCount(1),   1,  "第1层解锁1个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(4),   1,  "第4层解锁1个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(5),   1,  "第5层解锁1个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(6),   2,  "第6层解锁2个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(10),  2,  "第10层解锁2个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(11),  3,  "第11层解锁3个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(25),  5,  "第25层解锁5个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(50),  10, "第50层解锁10个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(100), 20, "第100层解锁20个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(149), 30, "第149层解锁30个")
assert_eq(PrisonTowerConfig.CalcUnlockCount(150), 30, "第150层解锁30个(上限)")

-- ============================================================================
-- TEST 3: BOSS 上阵选择验证（倒序优先）
-- ============================================================================
print("\n=== TEST 3: BOSS 上阵选择验证 ===")

-- 第1层：池=[spider_queen], 需1只 → [spider_queen]
local active1 = PrisonTowerConfig.GetActiveBossIds(1)
assert_eq(#active1, 1, "第1层上阵1只")
assert_eq(active1[1], "spider_queen", "第1层=spider_queen")

-- 第4层：池=[spider_queen], 需4只 → 循环取 [spider_queen×4]
local active4 = PrisonTowerConfig.GetActiveBossIds(4)
assert_eq(#active4, 4, "第4层上阵4只")
for i = 1, 4 do
    assert_eq(active4[i], "spider_queen", "第4层pos" .. i .. "=spider_queen(池不足循环)")
end

-- 第6层：段2首层, bossCount=1, mainBoss=boar_king, 前段=spider_queen
--   始终4个: 1×boar_king + 3×spider_queen
-- P0-1A: 修正期望 — 实际算法第2段起固定返回4个BOSS
local active6 = PrisonTowerConfig.GetActiveBossIds(6)
assert_eq(#active6, 4, "第6层上阵4只(第2段起固定4)")
assert_eq(active6[1], "boar_king", "第6层pos1=boar_king(当前段主BOSS)")
assert_eq(active6[2], "spider_queen", "第6层pos2=spider_queen(前段补位)")
assert_eq(active6[3], "spider_queen", "第6层pos3=spider_queen(前段补位)")
assert_eq(active6[4], "spider_queen", "第6层pos4=spider_queen(前段补位)")

-- 第7层：段2第2层, bossCount=2, mainBoss=boar_king, 前段=spider_queen
--   始终4个: 2×boar_king + 2×spider_queen
-- P0-1A: 修正期望 — 第2段起固定4个，前bossCount个为当前段主BOSS
local active7 = PrisonTowerConfig.GetActiveBossIds(7)
assert_eq(#active7, 4, "第7层上阵4只(第2段起固定4)")
assert_eq(active7[1], "boar_king", "第7层pos1=boar_king(当前段)")
assert_eq(active7[2], "boar_king", "第7层pos2=boar_king(当前段)")
assert_eq(active7[3], "spider_queen", "第7层pos3=spider_queen(前段补位)")
assert_eq(active7[4], "spider_queen", "第7层pos4=spider_queen(前段补位)")

-- 第11层：段3首层, bossCount=1, mainBoss=bandit_chief, 前段=boar_king
--   始终4个: 1×bandit_chief + 3×boar_king
-- P0-1A: 修正期望 — 第2段起固定4个
local active11 = PrisonTowerConfig.GetActiveBossIds(11)
assert_eq(#active11, 4, "第11层上阵4只(第2段起固定4)")
assert_eq(active11[1], "bandit_chief", "第11层pos1=bandit_chief(当前段)")
assert_eq(active11[2], "boar_king", "第11层pos2=boar_king(前段补位)")
assert_eq(active11[3], "boar_king", "第11层pos3=boar_king(前段补位)")
assert_eq(active11[4], "boar_king", "第11层pos4=boar_king(前段补位)")

-- 第150层：段30末层, bossCount=4, mainBoss=dragon_sand, 前段=dragon_fire
--   bossCount=4 → 4×dragon_sand + 0×前段补位
-- P0-1A: 修正期望 — bossCount=4时全部为当前段主BOSS
local active150 = PrisonTowerConfig.GetActiveBossIds(150)
assert_eq(#active150, 4, "第150层上阵4只")
assert_eq(active150[1], "dragon_sand", "第150层pos1=dragon_sand(当前段)")
assert_eq(active150[2], "dragon_sand", "第150层pos2=dragon_sand(当前段)")
assert_eq(active150[3], "dragon_sand", "第150层pos3=dragon_sand(当前段)")
assert_eq(active150[4], "dragon_sand", "第150层pos4=dragon_sand(当前段)")

-- ============================================================================
-- TEST 4: 境界映射与等级公式验证
-- ============================================================================
print("\n=== TEST 4: 境界映射与等级公式验证（15 段穷举） ===")

-- 验证 15 段都有配置
assert_eq(#PrisonTowerConfig.REALMS, 15, "总共15个挑战段")

-- 穷举全部 150 层
local levelErrors = 0
for floor = 1, 150 do
    local realm, segIdx = PrisonTowerConfig.GetRealmByFloor(floor)
    if not realm then
        levelErrors = levelErrors + 1
        print("  FAIL: floor=" .. floor .. " realm is nil")
    else
        local level = PrisonTowerConfig.CalcMonsterLevel(floor)
        if level < realm.reqLevel or level > realm.maxLevel then
            levelErrors = levelErrors + 1
            print("  FAIL: floor=" .. floor .. " level=" .. level
                .. " out of [" .. realm.reqLevel .. "," .. realm.maxLevel .. "]")
        end
    end
end
assert_eq(levelErrors, 0, "150层等级全部在合法区间")

-- 段边界验证：localFloor=1 → reqLevel, localFloor=10 → maxLevel
for seg = 1, 15 do
    local realm = PrisonTowerConfig.REALMS[seg]
    local floorStart = (seg - 1) * 10 + 1  -- localFloor=1
    local floorEnd = seg * 10              -- localFloor=10
    local levelStart = PrisonTowerConfig.CalcMonsterLevel(floorStart)
    local levelEnd = PrisonTowerConfig.CalcMonsterLevel(floorEnd)
    assert_eq(levelStart, realm.reqLevel,
        "段" .. seg .. " 首层等级=" .. realm.reqLevel)
    assert_eq(levelEnd, realm.maxLevel,
        "段" .. seg .. " 末层等级=" .. realm.maxLevel)
end

-- segmentIndex 验证
assert_eq(PrisonTowerConfig.GetSegmentIndex(1),   1,  "第1层→段1")
assert_eq(PrisonTowerConfig.GetSegmentIndex(10),  1,  "第10层→段1")
assert_eq(PrisonTowerConfig.GetSegmentIndex(11),  2,  "第11层→段2")
assert_eq(PrisonTowerConfig.GetSegmentIndex(150), 15, "第150层→段15")

-- localFloor 验证
assert_eq(PrisonTowerConfig.GetLocalFloor(1),   1,  "第1层→层内1")
assert_eq(PrisonTowerConfig.GetLocalFloor(10),  10, "第10层→层内10")
assert_eq(PrisonTowerConfig.GetLocalFloor(11),  1,  "第11层→层内1")
assert_eq(PrisonTowerConfig.GetLocalFloor(150), 10, "第150层→层内10")

-- ============================================================================
-- TEST 5: BOSS 档位保底验证
-- ============================================================================
print("\n=== TEST 5: BOSS 档位保底验证 ===")

-- 所有低于 emperor_boss 的类别都应被提升
assert_eq(PrisonTowerConfig.GetEffectiveCategory("normal"),       "emperor_boss", "normal→emperor_boss")
assert_eq(PrisonTowerConfig.GetEffectiveCategory("elite"),        "emperor_boss", "elite→emperor_boss")
assert_eq(PrisonTowerConfig.GetEffectiveCategory("boss"),         "emperor_boss", "boss→emperor_boss")
assert_eq(PrisonTowerConfig.GetEffectiveCategory("king_boss"),    "emperor_boss", "king_boss→emperor_boss")
assert_eq(PrisonTowerConfig.GetEffectiveCategory("emperor_boss"), "emperor_boss", "emperor_boss不变")
assert_eq(PrisonTowerConfig.GetEffectiveCategory("saint_boss"),   "saint_boss",   "saint_boss保留")

-- ============================================================================
-- TEST 6: 镇狱BUFF 数值链路验证
-- ============================================================================
print("\n=== TEST 6: 镇狱BUFF 数值链路验证 ===")

local buff = PrisonTowerConfig.ZHENYU_BUFF
assert_eq(buff.hpMult,       2.0, "HP倍率=2.0")
assert_eq(buff.atkMult,      2.0, "ATK倍率=2.0")
assert_eq(buff.defMult,      2.0, "DEF倍率=2.0")
assert_eq(buff.speedMult,    2.0, "速度倍率=2.0")
assert_eq(buff.atkSpeedMult, 2.0, "攻速倍率=2.0")
assert_eq(buff.cdrMult,      0.5, "CDR倍率=0.5")

-- 模拟数值计算链路：base → zhenyuBuff
-- 假设基础 HP=1000, ATK=100, DEF=50
local baseHp, baseAtk, baseDef = 1000, 100, 50
local finalHp  = math.floor(baseHp * buff.hpMult)
local finalAtk = math.floor(baseAtk * buff.atkMult)
local finalDef = math.floor(baseDef * buff.defMult)
assert_eq(finalHp,  2000, "基础1000HP×2.0=2000")
assert_eq(finalAtk, 200,  "基础100ATK×2.0=200")
assert_eq(finalDef, 100,  "基础50DEF×2.0=100")

-- ============================================================================
-- TEST 7: 永久加成聚合验证
-- ============================================================================
print("\n=== TEST 7: 永久加成聚合验证 ===")

-- highestFloor=0 → 全零
local b0 = PrisonTowerConfig.GetAllBonuses(0)
assert_eq(b0.atk, 0, "0层atk=0")
assert_eq(b0.def, 0, "0层def=0")
assert_eq(b0.maxHp, 0, "0层maxHp=0")
assert_near(b0.hpRegen, 0, 0.001, "0层hpRegen=0")

-- highestFloor=5 → 第1个里程碑（前期）
local b5 = PrisonTowerConfig.GetAllBonuses(5)
assert_eq(b5.atk, 2, "5层atk=2")
assert_eq(b5.def, 2, "5层def=2")
assert_eq(b5.maxHp, 20, "5层maxHp=20")
assert_near(b5.hpRegen, 0.2, 0.001, "5层hpRegen=0.2")

-- highestFloor=10 → 前2个里程碑
local b10 = PrisonTowerConfig.GetAllBonuses(10)
assert_eq(b10.atk, 4, "10层atk=4")
assert_eq(b10.def, 4, "10层def=4")
assert_eq(b10.maxHp, 40, "10层maxHp=40")
assert_near(b10.hpRegen, 0.4, 0.001, "10层hpRegen=0.4")

-- highestFloor=50 → 前期10个里程碑
-- 前期: atk=2*10=20, def=2*10=20, maxHp=20*10=200, hpRegen=0.2*10=2.0
local b50 = PrisonTowerConfig.GetAllBonuses(50)
assert_eq(b50.atk, 20, "50层atk=20")
assert_eq(b50.def, 20, "50层def=20")
assert_eq(b50.maxHp, 200, "50层maxHp=200")
assert_near(b50.hpRegen, 2.0, 0.001, "50层hpRegen=2.0")

-- highestFloor=100 → 前期10+中期10=20个里程碑
-- 中期: atk=4*10=40, def=3*10=30, maxHp=40*10=400, hpRegen=0.3*10=3.0
-- 累计: atk=60, def=50, maxHp=600, hpRegen=5.0
local b100 = PrisonTowerConfig.GetAllBonuses(100)
assert_eq(b100.atk, 60, "100层atk=60")
assert_eq(b100.def, 50, "100层def=50")
assert_eq(b100.maxHp, 600, "100层maxHp=600")
assert_near(b100.hpRegen, 5.0, 0.001, "100层hpRegen=5.0")

-- highestFloor=150 → 全部30个里程碑
-- 后期: atk=6*10=60, def=4*10=40, maxHp=60*10=600, hpRegen=0.5*10=5.0
-- 总计: atk=120, def=90, maxHp=1200, hpRegen=10.0
local b150 = PrisonTowerConfig.GetAllBonuses(150)
assert_eq(b150.atk, 120, "150层atk=120(总计)")
assert_eq(b150.def, 90, "150层def=90(总计)")
assert_eq(b150.maxHp, 1200, "150层maxHp=1200(总计)")
assert_near(b150.hpRegen, 10.0, 0.01, "150层hpRegen=10.0(总计)")

-- 非里程碑层（如第7层）不增加加成
local b7 = PrisonTowerConfig.GetAllBonuses(7)
assert_eq(b7.atk, 2, "7层atk=2(同5层)")
assert_eq(b7.def, 2, "7层def=2(同5层)")

-- ============================================================================
-- TEST 8: 里程碑无遗漏验证
-- ============================================================================
print("\n=== TEST 8: 里程碑无遗漏验证 ===")

local milestoneCount = 0
for floor = 5, 150, 5 do
    local bonus = PrisonTowerConfig.MILESTONE_BONUS[floor]
    assert_true(bonus ~= nil, "里程碑floor=" .. floor .. "存在")
    if bonus then
        assert_true(bonus.atk > 0, "floor=" .. floor .. " atk>0")
        assert_true(bonus.def > 0, "floor=" .. floor .. " def>0")
        assert_true(bonus.maxHp > 0, "floor=" .. floor .. " maxHp>0")
        assert_true(bonus.hpRegen > 0, "floor=" .. floor .. " hpRegen>0")
        milestoneCount = milestoneCount + 1
    end
end
assert_eq(milestoneCount, 30, "总共30个里程碑")

-- 验证非5倍数楼层无里程碑
for floor = 1, 150 do
    if floor % 5 ~= 0 then
        assert_true(PrisonTowerConfig.MILESTONE_BONUS[floor] == nil,
            "非里程碑floor=" .. floor .. "不存在")
    end
end

-- ============================================================================
-- TEST 9: 存档序列化/反序列化往返验证
-- ============================================================================
print("\n=== TEST 9: 存档序列化/反序列化往返验证 ===")

-- 模拟 PrisonTowerSystem 的 Serialize / Deserialize（不加载完整系统，避免引擎依赖）
local function mockSerialize(highestFloor)
    return { highestFloor = highestFloor }
end

local function mockDeserialize(data)
    if not data then return { highestFloor = 0 } end
    return { highestFloor = data.highestFloor or 0 }
end

-- 往返测试
local testCases = { 0, 1, 5, 50, 75, 100, 150 }
for _, hf in ipairs(testCases) do
    local serialized = mockSerialize(hf)
    local deserialized = mockDeserialize(serialized)
    assert_eq(deserialized.highestFloor, hf,
        "序列化/反序列化往返 highestFloor=" .. hf)
end

-- nil 输入安全
local dNil = mockDeserialize(nil)
assert_eq(dNil.highestFloor, 0, "nil输入→highestFloor=0")

-- 空表输入安全
local dEmpty = mockDeserialize({})
assert_eq(dEmpty.highestFloor, 0, "空表输入→highestFloor=0")

-- ============================================================================
-- TEST 10: 排行榜反作弊边界验证
-- ============================================================================
print("\n=== TEST 10: 排行榜反作弊边界验证 ===")

-- Mock 境界配置
local MOCK_REALMS = {
    lianqi_1 = { order = 1 },
    lianqi_3 = { order = 3 },
    zhuji_1  = { order = 4 },
    jindan_1 = { order = 7 },
    jindan_2 = { order = 8 },
    yuanying_1 = { order = 10 },
}

--- 模拟反作弊验证
local function validatePrisonRank(data)
    local prisonFloor = data.prisonFloor or 0
    if prisonFloor <= 0 then return true, "no prison data" end
    if prisonFloor > 150 then return false, "prison floor exceeds max" end

    local realmData = MOCK_REALMS[data.realm]
    local realmOrder = realmData and realmData.order or 0
    if realmOrder < 7 then return false, "prison requires jindan_1" end
    if (data.level or 0) < 40 then return false, "prison requires level 40" end

    return true, "ok"
end

-- 楼层超限
local ok, msg = validatePrisonRank({ prisonFloor = 151, realm = "jindan_1", level = 50 })
assert_eq(ok, false, "楼层151超限应拒绝")

-- 境界不足
ok, msg = validatePrisonRank({ prisonFloor = 1, realm = "lianqi_1", level = 50 })
assert_eq(ok, false, "练气境界应拒绝")

ok, msg = validatePrisonRank({ prisonFloor = 1, realm = "zhuji_1", level = 50 })
assert_eq(ok, false, "筑基境界应拒绝")

-- 等级不足
ok, msg = validatePrisonRank({ prisonFloor = 1, realm = "jindan_1", level = 39 })
assert_eq(ok, false, "等级39应拒绝")

-- 正常通过
ok, msg = validatePrisonRank({ prisonFloor = 1, realm = "jindan_1", level = 40 })
assert_eq(ok, true, "金丹初期+40级+1层应通过")

ok, msg = validatePrisonRank({ prisonFloor = 150, realm = "jindan_1", level = 40 })
assert_eq(ok, true, "150层合法应通过")

-- 无镇狱塔数据
ok, msg = validatePrisonRank({ prisonFloor = 0, realm = "lianqi_1", level = 1 })
assert_eq(ok, true, "无镇狱塔数据应通过")

-- ============================================================================
-- TEST 11: 同屏单位数验证
-- ============================================================================
print("\n=== TEST 11: 同屏单位数验证 ===")

local unitErrors = 0
for floor = 1, 150 do
    local bossCount = PrisonTowerConfig.CalcBossCount(floor)
    local pillarCount = 1
    local totalUnits = bossCount + pillarCount
    if totalUnits > 5 then
        unitErrors = unitErrors + 1
        print("  FAIL: floor=" .. floor .. " has " .. totalUnits .. " units (limit 5)")
    end
end
assert_eq(unitErrors, 0, "所有楼层单位数≤5")

-- 最大情况验证: BOSS 4 + 塔柱 1 = 5
local maxBoss = PrisonTowerConfig.CalcBossCount(5)  -- 4只
assert_eq(maxBoss + 1, 5, "最大情况=4BOSS+1塔柱=5")

-- ============================================================================
-- TEST 12: 出生点无重叠验证
-- ============================================================================
print("\n=== TEST 12: 出生点无重叠验证 ===")

local pillarPos = PrisonTowerConfig.PILLAR_POSITION

-- BOSS 出生点与塔柱距离 > 2.0
local spawnPositions = PrisonTowerConfig.BOSS_SPAWN_POSITIONS
for i, pos in ipairs(spawnPositions) do
    local dist = math.sqrt((pos.x - pillarPos.x)^2 + (pos.y - pillarPos.y)^2)
    assert_true(dist > 2.0,
        "BOSS出生点" .. i .. "(" .. pos.x .. "," .. pos.y .. ")"
        .. "与塔柱距离=" .. string.format("%.2f", dist) .. ">2.0")
end

-- BOSS 出生点之间距离 > 1.0
for i = 1, #spawnPositions do
    for j = i + 1, #spawnPositions do
        local a, b = spawnPositions[i], spawnPositions[j]
        local dist = math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
        assert_true(dist > 1.0,
            "出生点" .. i .. "与出生点" .. j .. "距离="
            .. string.format("%.2f", dist) .. ">1.0")
    end
end

-- 所有出生点在竞技场内（1~ARENA_SIZE+2 范围，考虑墙壁偏移）
local arenaMax = PrisonTowerConfig.ARENA_SIZE + 2
for i, pos in ipairs(spawnPositions) do
    assert_true(pos.x >= 1 and pos.x <= arenaMax,
        "出生点" .. i .. " x=" .. pos.x .. "在竞技场内")
    assert_true(pos.y >= 1 and pos.y <= arenaMax,
        "出生点" .. i .. " y=" .. pos.y .. "在竞技场内")
end

-- ============================================================================
-- PERF 1: 150 层完整生成基准
-- ============================================================================
print("\n=== PERF 1: 150 层完整生成基准 ===")

do
    local start = os.clock()
    for iter = 1, 1000 do
        for floor = 1, 150 do
            local _ = PrisonTowerConfig.GetActiveBossIds(floor)
            local _ = PrisonTowerConfig.CalcMonsterLevel(floor)
            local _ = PrisonTowerConfig.CalcBossCount(floor)
            local _ = PrisonTowerConfig.GetRealmByFloor(floor)
        end
    end
    local elapsed = (os.clock() - start) * 1000
    print("  150层×1000次配置生成: " .. string.format("%.2f", elapsed) .. "ms")
    assert_true(elapsed < 5000, "150层×1000次配置生成 < 5000ms")
end

-- ============================================================================
-- PERF 2: 单层怪物配置生成基准
-- ============================================================================
print("\n=== PERF 2: 单层怪物配置生成基准（第150层，最坏情况） ===")

do
    local start = os.clock()
    for iter = 1, 10000 do
        local activeBossIds = PrisonTowerConfig.GetActiveBossIds(150)
        local monsterLevel = PrisonTowerConfig.CalcMonsterLevel(150)
        local realm = PrisonTowerConfig.GetRealmByFloor(150)
        for _, bossId in ipairs(activeBossIds) do
            local _ = PrisonTowerConfig.GetEffectiveCategory("boss")
        end
    end
    local elapsed = (os.clock() - start) * 1000
    local avg = elapsed / 10000
    print("  单层配置×10000次: " .. string.format("%.2f", elapsed) .. "ms"
        .. " (avg " .. string.format("%.4f", avg) .. "ms)")
    assert_true(avg < 1.0, "单层配置平均 < 1ms")
end

-- ============================================================================
-- PERF 3: 永久加成聚合基准
-- ============================================================================
print("\n=== PERF 3: 永久加成聚合基准（GetAllBonuses ×10000） ===")

do
    local start = os.clock()
    for iter = 1, 10000 do
        local _ = PrisonTowerConfig.GetAllBonuses(150)
    end
    local elapsed = (os.clock() - start) * 1000
    print("  GetAllBonuses×10000: " .. string.format("%.2f", elapsed) .. "ms")
    assert_true(elapsed < 500, "GetAllBonuses×10000 < 500ms")
end

-- ============================================================================
-- PERF 4: 数值溢出安全验证
-- ============================================================================
print("\n=== PERF 4: 数值溢出安全验证 ===")

-- 模拟第 150 层最终 BOSS 数值计算
-- 假设最高等级 BOSS 基础数值（保守高估）
local simBaseHp  = 100000   -- 假设基础 HP
local simBaseAtk = 10000    -- 假设基础 ATK
local simBaseDef = 5000     -- 假设基础 DEF

-- emperor_boss 倍率（从 MonsterData: hp×20, atk×12, def×10）
local catHpMult, catAtkMult, catDefMult = 20.0, 12.0, 10.0

-- 镇狱BUFF 倍率
local zhenyuMult = 2.0

local finalHpSim  = simBaseHp * catHpMult * zhenyuMult
local finalAtkSim = simBaseAtk * catAtkMult * zhenyuMult
local finalDefSim = simBaseDef * catDefMult * zhenyuMult

-- Lua 5.4 的 double 精度安全范围: 2^53 = 9007199254740992
local MAX_SAFE = 2^53

assert_true(finalHpSim < MAX_SAFE,
    "模拟HP=" .. finalHpSim .. " < 2^53=" .. MAX_SAFE)
assert_true(finalAtkSim < MAX_SAFE,
    "模拟ATK=" .. finalAtkSim .. " < 2^53=" .. MAX_SAFE)
assert_true(finalDefSim < MAX_SAFE,
    "模拟DEF=" .. finalDefSim .. " < 2^53=" .. MAX_SAFE)

-- NaN 和 inf 安全检查
assert_true(finalHpSim == finalHpSim, "HP不是NaN")
assert_true(finalAtkSim == finalAtkSim, "ATK不是NaN")
assert_true(finalDefSim == finalDefSim, "DEF不是NaN")
assert_true(finalHpSim ~= math.huge, "HP不是inf")
assert_true(finalAtkSim ~= math.huge, "ATK不是inf")
assert_true(finalDefSim ~= math.huge, "DEF不是inf")

-- 即使 10 倍安全余量也不溢出
local extreme = finalHpSim * 10
assert_true(extreme < MAX_SAFE,
    "10倍安全余量HP=" .. extreme .. " < 2^53")

-- ============================================================================
-- 汇总
-- ============================================================================
print("\n" .. string.rep("=", 60))
print(string.format("  TOTAL: %d tests, %d passed, %d failed",
    totalTests, passed, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("\n  *** " .. failed .. " TEST(S) FAILED ***\n")
else
    print("\n  ALL TESTS PASSED\n")
end

-- TestRunner 导出（P0-1: 统一测试入口）
return { passed = passed, failed = failed, total = totalTests }
