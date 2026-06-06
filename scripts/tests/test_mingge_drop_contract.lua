-- ============================================================================
-- test_mingge_drop_contract.lua — 五行命格掉落合同与定价测试（blocking）
--
-- 覆盖范围（§5.3）：
--   D1: SELL_PRICE 完整（3 tier × 3 quality）且满足 purple < orange < cyan
--   D2: SELL_PRICE 跨 tier 递增：T(n)[q] <= T(n+1)[q]
--   D3: DROP_RULES 字段完整且数值合理
--   D4: SOURCES 等级约束 — T1:[36,89], T2:[90,119], T3:120
--   D5: SOURCES 五行分布 — 每个元素至少有来源
--   D6: BOSS_TO_MINGGE 映射目标都在 SOURCES 中
--   D7: GetMinggeId 格式验证 — element_bossId
--   D8: STAT_NAMES 覆盖所有 statId
--   D9: FormatStatValue 百分比/整数格式正确性
--   D10: QUALITY_COLORS / ELEMENT_COLORS 完整
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
-- D1: SELL_PRICE 完整且品质递增
-- ============================================================================
SUITE("D1: SELL_PRICE 完整性与品质递增")

ASSERT(MinggeData.SELL_PRICE ~= nil, "SELL_PRICE 存在")

local TIERS = { 1, 2, 3 }
local QUALITIES = { "purple", "orange", "cyan" }

if MinggeData.SELL_PRICE then
    for _, tier in ipairs(TIERS) do
        local tierPrice = MinggeData.SELL_PRICE[tier]
        ASSERT(tierPrice ~= nil, "SELL_PRICE[" .. tier .. "] 存在")
        if tierPrice then
            for _, q in ipairs(QUALITIES) do
                ASSERT(type(tierPrice[q]) == "number" and tierPrice[q] > 0,
                    "SELL_PRICE[" .. tier .. "][" .. q .. "] > 0")
            end
            -- 品质递增：purple < orange < cyan
            if tierPrice.purple and tierPrice.orange and tierPrice.cyan then
                ASSERT(tierPrice.purple < tierPrice.orange,
                    "T" .. tier .. ": purple(" .. tierPrice.purple .. ") < orange(" .. tierPrice.orange .. ")")
                ASSERT(tierPrice.orange < tierPrice.cyan,
                    "T" .. tier .. ": orange(" .. tierPrice.orange .. ") < cyan(" .. tierPrice.cyan .. ")")
            end
        end
    end

    -- 验证具体数值
    ASSERT_EQ(MinggeData.SELL_PRICE[1].purple, 1, "T1 purple 售价 = 1")
    ASSERT_EQ(MinggeData.SELL_PRICE[1].orange, 2, "T1 orange 售价 = 2")
    ASSERT_EQ(MinggeData.SELL_PRICE[1].cyan, 3, "T1 cyan 售价 = 3")
    ASSERT_EQ(MinggeData.SELL_PRICE[2].purple, 2, "T2 purple 售价 = 2")
    ASSERT_EQ(MinggeData.SELL_PRICE[2].orange, 4, "T2 orange 售价 = 4")
    ASSERT_EQ(MinggeData.SELL_PRICE[2].cyan, 6, "T2 cyan 售价 = 6")
    ASSERT_EQ(MinggeData.SELL_PRICE[3].purple, 3, "T3 purple 售价 = 3")
    ASSERT_EQ(MinggeData.SELL_PRICE[3].orange, 6, "T3 orange 售价 = 6")
    ASSERT_EQ(MinggeData.SELL_PRICE[3].cyan, 9, "T3 cyan 售价 = 9")
end

-- ============================================================================
-- D2: SELL_PRICE 跨 tier 递增
-- ============================================================================
SUITE("D2: SELL_PRICE 跨 tier 递增")

if MinggeData.SELL_PRICE then
    for _, q in ipairs(QUALITIES) do
        for i = 1, 2 do
            local curr = MinggeData.SELL_PRICE[i]
            local next = MinggeData.SELL_PRICE[i + 1]
            if curr and next and curr[q] and next[q] then
                ASSERT(curr[q] <= next[q],
                    q .. ": T" .. i .. "(" .. curr[q] .. ") <= T" .. (i+1) .. "(" .. next[q] .. ")")
            end
        end
    end
end

-- ============================================================================
-- D3: DROP_RULES 字段完整且数值合理
-- ============================================================================
SUITE("D3: DROP_RULES 合理性")

ASSERT(MinggeData.DROP_RULES ~= nil, "DROP_RULES 存在")

if MinggeData.DROP_RULES then
    local dr = MinggeData.DROP_RULES
    -- baseDropChance 在 (0, 1] 区间
    ASSERT(type(dr.baseDropChance) == "number", "baseDropChance 为数字")
    ASSERT(dr.baseDropChance > 0 and dr.baseDropChance <= 1,
        "baseDropChance 在 (0,1]: " .. tostring(dr.baseDropChance))
    -- setAttachChance 在 (0, 1] 区间
    ASSERT(type(dr.setAttachChance) == "number", "setAttachChance 为数字")
    ASSERT(dr.setAttachChance > 0 and dr.setAttachChance <= 1,
        "setAttachChance 在 (0,1]: " .. tostring(dr.setAttachChance))
    -- setEligibleQuality 是有效品质
    ASSERT(type(dr.setEligibleQuality) == "string", "setEligibleQuality 为字符串")
    local validQuality = false
    for _, q in ipairs(QUALITIES) do
        if q == dr.setEligibleQuality then validQuality = true; break end
    end
    ASSERT(validQuality, "setEligibleQuality=" .. tostring(dr.setEligibleQuality) .. " 是有效品质")
end

-- ============================================================================
-- D4: SOURCES 等级约束
-- ============================================================================
SUITE("D4: SOURCES 等级约束")

for bossId, source in pairs(MinggeData.SOURCES) do
    ASSERT(type(source.level) == "number", bossId .. ": level 为数字")
    if source.tier == 1 then
        ASSERT(source.level >= 36 and source.level <= 89,
            bossId .. ": T1 level=" .. source.level .. " 在 [36,89]")
    elseif source.tier == 2 then
        ASSERT(source.level >= 90 and source.level <= 119,
            bossId .. ": T2 level=" .. source.level .. " 在 [90,119]")
    elseif source.tier == 3 then
        ASSERT_EQ(source.level, 120,
            bossId .. ": T3 level=" .. source.level .. " = 120")
    end
end

-- ============================================================================
-- D5: SOURCES 五行分布 — 每个元素至少有来源
-- ============================================================================
SUITE("D5: SOURCES 五行分布")

local elemCount = {}
for _, elem in ipairs(MinggeData.ELEMENTS) do
    elemCount[elem] = 0
end

for _, source in pairs(MinggeData.SOURCES) do
    if elemCount[source.element] then
        elemCount[source.element] = elemCount[source.element] + 1
    end
end

for _, elem in ipairs(MinggeData.ELEMENTS) do
    ASSERT(elemCount[elem] > 0,
        "元素 " .. elem .. " 至少有 1 个来源（实际: " .. elemCount[elem] .. "）")
    -- 至少 5 个来源确保每个元素有充分的内容
    ASSERT(elemCount[elem] >= 5,
        "元素 " .. elem .. " 至少有 5 个来源（实际: " .. elemCount[elem] .. "）")
end

-- ============================================================================
-- D6: BOSS_TO_MINGGE 映射目标都在 SOURCES 中
-- ============================================================================
SUITE("D6: BOSS_TO_MINGGE 映射有效性")

ASSERT(MinggeData.BOSS_TO_MINGGE ~= nil, "BOSS_TO_MINGGE 存在")

if MinggeData.BOSS_TO_MINGGE then
    for typeId, bossId in pairs(MinggeData.BOSS_TO_MINGGE) do
        ASSERT(MinggeData.SOURCES[bossId] ~= nil,
            typeId .. " → " .. bossId .. " 在 SOURCES 中存在")
    end
end

-- ============================================================================
-- D7: GetMinggeId 格式验证
-- ============================================================================
SUITE("D7: GetMinggeId 格式")

for bossId, source in pairs(MinggeData.SOURCES) do
    local minggeId = MinggeData.GetMinggeId(bossId)
    local expectedId = source.element .. "_" .. bossId
    ASSERT_EQ(minggeId, expectedId,
        "GetMinggeId(" .. bossId .. ") = " .. expectedId)
end

-- 无效 bossId 应返回 "unknown_xxx"
local unknownId = MinggeData.GetMinggeId("nonexistent_boss")
ASSERT(unknownId:find("^unknown_") ~= nil,
    "无效 bossId 返回 unknown_ 前缀: " .. unknownId)

-- ============================================================================
-- D8: STAT_NAMES 覆盖所有 statId
-- ============================================================================
SUITE("D8: STAT_NAMES 完整覆盖")

ASSERT(MinggeData.STAT_NAMES ~= nil, "STAT_NAMES 存在")

if MinggeData.STAT_NAMES and MinggeData.STAT_FIELDS then
    for statId, _ in pairs(MinggeData.STAT_FIELDS) do
        ASSERT(MinggeData.STAT_NAMES[statId] ~= nil,
            statId .. " 在 STAT_NAMES 中有显示名")
    end
end

-- ============================================================================
-- D9: FormatStatValue 格式正确性
-- ============================================================================
SUITE("D9: FormatStatValue 格式")

-- 百分比属性
local critStr = MinggeData.FormatStatValue("critRate", 0.025)
ASSERT(critStr:find("%%") ~= nil, "critRate 格式含 %: " .. critStr)
ASSERT(critStr == "2.5%", "critRate 0.025 → '2.5%': " .. critStr)

-- 整型属性
local atkStr = MinggeData.FormatStatValue("atk", 10)
ASSERT_EQ(atkStr, "10", "atk 10 → '10'")

-- 小数属性
local hpRegenStr = MinggeData.FormatStatValue("hpRegen", 3.5)
ASSERT_EQ(hpRegenStr, "3.5", "hpRegen 3.5 → '3.5'")

-- ============================================================================
-- D10: QUALITY_COLORS / ELEMENT_COLORS 完整
-- ============================================================================
SUITE("D10: 颜色配置完整性")

for _, q in ipairs(QUALITIES) do
    local color = MinggeData.QUALITY_COLORS[q]
    ASSERT(color ~= nil, "QUALITY_COLORS[" .. q .. "] 存在")
    if color then
        ASSERT_EQ(#color, 4, "QUALITY_COLORS[" .. q .. "] 有 4 个分量(RGBA)")
    end
end

for _, elem in ipairs(MinggeData.ELEMENTS) do
    local color = MinggeData.ELEMENT_COLORS[elem]
    ASSERT(color ~= nil, "ELEMENT_COLORS[" .. elem .. "] 存在")
    if color then
        ASSERT_EQ(#color, 4, "ELEMENT_COLORS[" .. elem .. "] 有 4 个分量(RGBA)")
    end
end

-- ============================================================================
-- 汇总
-- ============================================================================
print("")
print("================================================================")
if failed == 0 then
    print(string.format("  五行命格掉落合同：全部 %d 项通过 ✓", passed))
else
    print(string.format("  五行命格掉落合同：%d 失败 / %d 总计", failed, passed + failed))
    for _, e in ipairs(errors) do
        print("    ✗ " .. e)
    end
end
print("================================================================")
print("")

return { passed = passed, failed = failed, total = passed + failed }
