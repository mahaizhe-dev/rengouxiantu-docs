-- ============================================================================
-- test_mingge_config.lua — 五行命格配置完整性测试（blocking）
--
-- 覆盖范围（§5.1）：
--   M1: 五行槽位数 = 15（5 元素 × 3）
--   M2: 背包容量 = 60
--   M3: 品质枚举 = {purple, orange, cyan}
--   M4: 品质权重 = 50/30/20
--   M5: SOURCES 数量 = 37（T1:15, T2:15, T3:7）
--   M6: 乌万海不在 SOURCES 中
--   M7: 流沙之子双来源映射存在且指向同一个 bossId
--   M8: 四象套装定义完整（4 套，各有 stat/value）
--   M9: setEligibleQuality = "cyan"
--   M10: 无洗练/升级配置（仅初版）
-- ============================================================================

local MinggeData = require("config.MinggeData")

-- ── 测试框架（inline，无引擎依赖）────────────────────────────────────────────

local passed = 0
local failed = 0
local errors = {}

local function ASSERT(cond, desc)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("  ✗ FAIL: " .. desc)
        table.insert(errors, desc)
    end
end

local function ASSERT_EQ(actual, expected, desc)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        local msg = string.format("%s (expected=%s, actual=%s)", desc, tostring(expected), tostring(actual))
        print("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function SUITE(name)
    print("")
    print("  ── " .. name .. " ──")
end

-- ============================================================================
-- M1: 五行槽位数 = 15
-- ============================================================================
SUITE("M1: 五行槽位数")

ASSERT_EQ(#MinggeData.ALL_SLOTS, 15, "ALL_SLOTS 数量 = 15")
ASSERT_EQ(#MinggeData.ELEMENTS, 5, "ELEMENTS 数量 = 5")

for _, elem in ipairs(MinggeData.ELEMENTS) do
    ASSERT(MinggeData.SLOTS[elem] ~= nil, "SLOTS[" .. elem .. "] 存在")
    if MinggeData.SLOTS[elem] then
        ASSERT_EQ(#MinggeData.SLOTS[elem], 3, "SLOTS[" .. elem .. "] 有 3 个槽位")
    end
end

-- ============================================================================
-- M2: 背包容量 = 60
-- ============================================================================
SUITE("M2: 背包容量")

ASSERT_EQ(MinggeData.BACKPACK_SIZE, 60, "BACKPACK_SIZE = 60")

-- ============================================================================
-- M3: 品质枚举 = {purple, orange, cyan}
-- ============================================================================
SUITE("M3: 品质枚举")

ASSERT_EQ(#MinggeData.QUALITIES, 3, "QUALITIES 数量 = 3")
ASSERT_EQ(MinggeData.QUALITIES[1], "purple", "品质[1] = purple")
ASSERT_EQ(MinggeData.QUALITIES[2], "orange", "品质[2] = orange")
ASSERT_EQ(MinggeData.QUALITIES[3], "cyan", "品质[3] = cyan")

-- ============================================================================
-- M4: 品质权重 = 50/30/20
-- ============================================================================
SUITE("M4: 品质权重")

ASSERT_EQ(MinggeData.QUALITY_WEIGHTS.purple, 50, "紫品权重 = 50")
ASSERT_EQ(MinggeData.QUALITY_WEIGHTS.orange, 30, "橙品权重 = 30")
ASSERT_EQ(MinggeData.QUALITY_WEIGHTS.cyan, 20, "青品权重 = 20")

local totalWeight = MinggeData.QUALITY_WEIGHTS.purple
                  + MinggeData.QUALITY_WEIGHTS.orange
                  + MinggeData.QUALITY_WEIGHTS.cyan
ASSERT_EQ(totalWeight, 100, "品质权重总和 = 100")

-- ============================================================================
-- M5: SOURCES 数量 = 37 (T1:15, T2:15, T3:7)
-- ============================================================================
SUITE("M5: SOURCES 数量")

local totalSources = 0
local t1Count = 0
local t2Count = 0
local t3Count = 0

for _, source in pairs(MinggeData.SOURCES) do
    totalSources = totalSources + 1
    if source.tier == 1 then t1Count = t1Count + 1
    elseif source.tier == 2 then t2Count = t2Count + 1
    elseif source.tier == 3 then t3Count = t3Count + 1
    end
end

ASSERT_EQ(totalSources, 37, "SOURCES 总数 = 37")
ASSERT_EQ(t1Count, 15, "T1 来源数 = 15")
ASSERT_EQ(t2Count, 15, "T2 来源数 = 15")
ASSERT_EQ(t3Count, 7, "T3 来源数 = 7")

-- ============================================================================
-- M6: 乌万海不在 SOURCES 中（已删除 BOSS）
-- ============================================================================
SUITE("M6: 乌万海排除")

ASSERT(MinggeData.SOURCES["wu_wanhai"] == nil, "乌万海(wu_wanhai) 不在 SOURCES 中")
ASSERT(MinggeData.SOURCES["wuwanhai"] == nil, "乌万海(wuwanhai) 不在 SOURCES 中")

-- ============================================================================
-- M7: 流沙之子双来源映射
-- ============================================================================
SUITE("M7: 流沙之子双来源映射")

ASSERT(MinggeData.BOSS_TO_MINGGE["liusha_son_outer"] ~= nil, "liusha_son_outer 映射存在")
ASSERT(MinggeData.BOSS_TO_MINGGE["liusha_son_mid"] ~= nil, "liusha_son_mid 映射存在")
ASSERT_EQ(MinggeData.BOSS_TO_MINGGE["liusha_son_outer"], "liusha_son",
    "liusha_son_outer → liusha_son")
ASSERT_EQ(MinggeData.BOSS_TO_MINGGE["liusha_son_mid"], "liusha_son",
    "liusha_son_mid → liusha_son")
ASSERT(MinggeData.SOURCES["liusha_son"] ~= nil, "liusha_son 在 SOURCES 中存在")

-- ============================================================================
-- M8: 四象套装定义完整
-- ============================================================================
SUITE("M8: 四象套装定义")

local expectedSets = { "qinglong", "baihu", "zhuque", "xuanwu" }
ASSERT_EQ(#MinggeData.SET_IDS, 4, "套装数量 = 4")

for _, setId in ipairs(expectedSets) do
    local set = MinggeData.SETS[setId]
    ASSERT(set ~= nil, "套装 " .. setId .. " 存在")
    if set then
        ASSERT(set.name ~= nil and set.name ~= "", setId .. ": name 非空")
        ASSERT(set.stat ~= nil and set.stat ~= "", setId .. ": stat 非空")
        ASSERT(type(set.value) == "number" and set.value > 0, setId .. ": value > 0")
        -- 验证 stat 是有效的 STAT_FIELDS key
        ASSERT(MinggeData.STAT_FIELDS[set.stat] ~= nil,
            setId .. ": stat=" .. tostring(set.stat) .. " 在 STAT_FIELDS 中存在")
    end
end

-- 验证具体数值
ASSERT_EQ(MinggeData.SETS.qinglong.value, 0.08, "青龙: 攻速+8%")
ASSERT_EQ(MinggeData.SETS.baihu.value, 0.20, "白虎: 暴击伤害+20%")
ASSERT_EQ(MinggeData.SETS.zhuque.value, 0.20, "朱雀: 天诛伤害+20%")
ASSERT_EQ(MinggeData.SETS.xuanwu.value, 0.08, "玄武: 宠物同步率+8%")

ASSERT_EQ(MinggeData.SET_REQUIRED_PIECES, 3, "套装触发件数 = 3")

-- ============================================================================
-- M9: setEligibleQuality = "cyan"
-- ============================================================================
SUITE("M9: 套装附带品质限制")

ASSERT_EQ(MinggeData.DROP_RULES.setEligibleQuality, "cyan",
    "只有青品质允许判定套装")
ASSERT_EQ(MinggeData.DROP_RULES.setAttachChance, 0.20,
    "套装附带概率 = 20%")
ASSERT_EQ(MinggeData.DROP_RULES.baseDropChance, 0.05,
    "基础掉落概率 = 5%")

-- ============================================================================
-- M10: 无洗练/升级配置（初版设计）
-- ============================================================================
SUITE("M10: 无洗练/升级配置")

ASSERT(MinggeData.WASH_RULES == nil, "WASH_RULES 不存在（初版无洗练）")
ASSERT(MinggeData.UPGRADE_RULES == nil, "UPGRADE_RULES 不存在（初版无升级）")
ASSERT(MinggeData.RECYCLE_RULES == nil, "RECYCLE_RULES 不存在（初版无分解）")

-- ============================================================================
-- 汇总
-- ============================================================================
print("")
print("================================================================")
if failed == 0 then
    print(string.format("  五行命格配置完整性：全部 %d 项通过 ✓", passed))
else
    print(string.format("  五行命格配置完整性：%d 失败 / %d 总计", failed, passed + failed))
    for _, e in ipairs(errors) do
        print("    ✗ " .. e)
    end
end
print("================================================================")
print("")

return { passed = passed, failed = failed, total = passed + failed }
