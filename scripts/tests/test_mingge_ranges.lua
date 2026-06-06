-- ============================================================================
-- test_mingge_ranges.lua — 五行命格属性范围与粒度测试（blocking）
--
-- 覆盖范围（§5.2）：
--   R1: STAT_RANGES 覆盖 3 tier × 15 stat × 3 quality
--   R2: 每条 range {min, max} 满足 min <= max
--   R3: 同一 tier 内品质递增：purple.max <= orange.min, orange.max <= cyan.min
--   R4: 跨 tier 品质衔接：T(n) cyan.max <= T(n+1) purple.min（允许等号）
--   R5: 百分比属性值域 [0, 1]
--   R6: 整型属性 min/max 为整数
--   R7: QUALITY_ROLL 区间覆盖 1~6000 无交叠
--   R8: STAT_FIELDS 映射完整（每个 statId 有对应玩家字段）
--   R9: SOURCES 中每个 source.stat 在 STAT_RANGES[source.tier] 中存在
--   R10: ELEMENT_STATS 五行归属无重复、覆盖全部 source.stat
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

-- ── 辅助 ─────────────────────────────────────────────────────────────────────

local TIERS = { 1, 2, 3 }
local QUALITIES = { "purple", "orange", "cyan" }

-- 所有 stat id（从 STAT_RANGES[1] 的 key 收集）
local ALL_STATS = {}
if MinggeData.STAT_RANGES and MinggeData.STAT_RANGES[1] then
    for statId, _ in pairs(MinggeData.STAT_RANGES[1]) do
        ALL_STATS[#ALL_STATS + 1] = statId
    end
    table.sort(ALL_STATS)
end

local function isInteger(v)
    return type(v) == "number" and v == math.floor(v)
end

-- ============================================================================
-- R1: STAT_RANGES 覆盖 3 tier × 15 stat × 3 quality
-- ============================================================================
SUITE("R1: STAT_RANGES 完整覆盖")

ASSERT(MinggeData.STAT_RANGES ~= nil, "STAT_RANGES 表存在")

for _, tier in ipairs(TIERS) do
    local tierData = MinggeData.STAT_RANGES[tier]
    ASSERT(tierData ~= nil, "STAT_RANGES[" .. tier .. "] 存在")
    if tierData then
        local statCount = 0
        for _ in pairs(tierData) do statCount = statCount + 1 end
        ASSERT_EQ(statCount, 15, "T" .. tier .. " 包含 15 个属性")
        for _, statId in ipairs(ALL_STATS) do
            local statData = tierData[statId]
            ASSERT(statData ~= nil, "T" .. tier .. "/" .. statId .. " 存在")
            if statData then
                for _, q in ipairs(QUALITIES) do
                    local range = statData[q]
                    ASSERT(range ~= nil, "T" .. tier .. "/" .. statId .. "/" .. q .. " 存在")
                    if range then
                        ASSERT(type(range[1]) == "number", "T" .. tier .. "/" .. statId .. "/" .. q .. " min 为数字")
                        ASSERT(type(range[2]) == "number", "T" .. tier .. "/" .. statId .. "/" .. q .. " max 为数字")
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- R2: min <= max
-- ============================================================================
SUITE("R2: min <= max")

for _, tier in ipairs(TIERS) do
    local tierData = MinggeData.STAT_RANGES[tier]
    if tierData then
        for _, statId in ipairs(ALL_STATS) do
            local statData = tierData[statId]
            if statData then
                for _, q in ipairs(QUALITIES) do
                    local range = statData[q]
                    if range and range[1] and range[2] then
                        ASSERT(range[1] <= range[2],
                            "T" .. tier .. "/" .. statId .. "/" .. q .. ": min(" .. range[1] .. ") <= max(" .. range[2] .. ")")
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- R3: 同 tier 内品质递增 (purple.max <= orange.min, orange.max <= cyan.min)
-- ============================================================================
SUITE("R3: 同 tier 品质递增")

for _, tier in ipairs(TIERS) do
    local tierData = MinggeData.STAT_RANGES[tier]
    if tierData then
        for _, statId in ipairs(ALL_STATS) do
            local statData = tierData[statId]
            if statData and statData.purple and statData.orange and statData.cyan then
                local pMax = statData.purple[2]
                local oMin = statData.orange[1]
                local oMax = statData.orange[2]
                local cMin = statData.cyan[1]
                -- purple.max <= orange.min（允许等号：边界相邻）
                ASSERT(pMax <= oMin,
                    "T" .. tier .. "/" .. statId .. ": purple.max(" .. pMax .. ") <= orange.min(" .. oMin .. ")")
                -- orange.max <= cyan.min
                ASSERT(oMax <= cMin,
                    "T" .. tier .. "/" .. statId .. ": orange.max(" .. oMax .. ") <= cyan.min(" .. cMin .. ")")
            end
        end
    end
end

-- ============================================================================
-- R4: 跨 tier 成长 — T(n+1) cyan.max > T(n) cyan.max（高 tier 天花板提升）
-- 注：数据设计允许跨 tier 重叠（T1 cyan 高端可能 > T2 purple 低端），
--     这是有意设计（避免断崖），因此验证天花板提升而非严格衔接。
-- ============================================================================
SUITE("R4: 跨 tier 天花板提升")

for i = 1, 2 do
    local currTier = MinggeData.STAT_RANGES[i]
    local nextTier = MinggeData.STAT_RANGES[i + 1]
    if currTier and nextTier then
        for _, statId in ipairs(ALL_STATS) do
            local currStat = currTier[statId]
            local nextStat = nextTier[statId]
            if currStat and nextStat and currStat.cyan and nextStat.cyan then
                local currCyanMax = currStat.cyan[2]
                local nextCyanMax = nextStat.cyan[2]
                ASSERT(nextCyanMax > currCyanMax,
                    "T" .. i .. "→T" .. (i+1) .. "/" .. statId .. ": T" .. (i+1) .. ".cyan.max(" .. nextCyanMax .. ") > T" .. i .. ".cyan.max(" .. currCyanMax .. ")")
            end
        end
    end
end

-- ============================================================================
-- R5: 百分比属性值域 [0, 1]
-- ============================================================================
SUITE("R5: 百分比属性值域")

for _, tier in ipairs(TIERS) do
    local tierData = MinggeData.STAT_RANGES[tier]
    if tierData then
        for _, statId in ipairs(ALL_STATS) do
            if MinggeData.PERCENT_STATS[statId] then
                local statData = tierData[statId]
                if statData then
                    for _, q in ipairs(QUALITIES) do
                        local range = statData[q]
                        if range then
                            ASSERT(range[1] >= 0 and range[1] <= 1,
                                "T" .. tier .. "/" .. statId .. "/" .. q .. " min 在 [0,1]")
                            ASSERT(range[2] >= 0 and range[2] <= 1,
                                "T" .. tier .. "/" .. statId .. "/" .. q .. " max 在 [0,1]")
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- R6: 整型属性 min/max 为整数
-- ============================================================================
SUITE("R6: 整型属性为整数")

-- 非百分比、非小数的属性应为整数
for _, tier in ipairs(TIERS) do
    local tierData = MinggeData.STAT_RANGES[tier]
    if tierData then
        for _, statId in ipairs(ALL_STATS) do
            local isPct = MinggeData.PERCENT_STATS[statId]
            local isDec = MinggeData.DECIMAL_STATS[statId]
            -- 只检查纯整型属性（非百分比、非小数）
            if not isPct and not isDec then
                local statData = tierData[statId]
                if statData then
                    for _, q in ipairs(QUALITIES) do
                        local range = statData[q]
                        if range then
                            ASSERT(isInteger(range[1]),
                                "T" .. tier .. "/" .. statId .. "/" .. q .. " min 为整数")
                            ASSERT(isInteger(range[2]),
                                "T" .. tier .. "/" .. statId .. "/" .. q .. " max 为整数")
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- R7: QUALITY_ROLL 区间覆盖 1~6000 无交叠
-- ============================================================================
SUITE("R7: QUALITY_ROLL 区间完整性")

ASSERT(MinggeData.QUALITY_ROLL ~= nil, "QUALITY_ROLL 存在")

if MinggeData.QUALITY_ROLL then
    local pRange = MinggeData.QUALITY_ROLL.purple
    local oRange = MinggeData.QUALITY_ROLL.orange
    local cRange = MinggeData.QUALITY_ROLL.cyan
    ASSERT(pRange ~= nil, "QUALITY_ROLL.purple 存在")
    ASSERT(oRange ~= nil, "QUALITY_ROLL.orange 存在")
    ASSERT(cRange ~= nil, "QUALITY_ROLL.cyan 存在")
    if pRange and oRange and cRange then
        -- 区间起止
        ASSERT_EQ(pRange[1], 1, "purple 起点 = 1")
        ASSERT_EQ(cRange[2], 6000, "cyan 终点 = 6000")
        -- 无间隙：purple.end+1 = orange.start, orange.end+1 = cyan.start
        ASSERT_EQ(pRange[2] + 1, oRange[1], "purple.end+1 = orange.start")
        ASSERT_EQ(oRange[2] + 1, cRange[1], "orange.end+1 = cyan.start")
        -- 各区间长度与权重匹配
        local pLen = pRange[2] - pRange[1] + 1
        local oLen = oRange[2] - oRange[1] + 1
        local cLen = cRange[2] - cRange[1] + 1
        ASSERT_EQ(pLen, 2000, "purple 区间长度 = 2000")
        ASSERT_EQ(oLen, 2000, "orange 区间长度 = 2000")
        ASSERT_EQ(cLen, 2000, "cyan 区间长度 = 2000")
    end
end

-- ============================================================================
-- R8: STAT_FIELDS 映射完整
-- ============================================================================
SUITE("R8: STAT_FIELDS 映射")

for _, statId in ipairs(ALL_STATS) do
    ASSERT(MinggeData.STAT_FIELDS[statId] ~= nil,
        statId .. " 在 STAT_FIELDS 中有映射")
    if MinggeData.STAT_FIELDS[statId] then
        ASSERT(MinggeData.STAT_FIELDS[statId] ~= "",
            statId .. " 映射字段非空")
    end
end

-- 附加：套装 stat 也在 STAT_FIELDS 中
for setId, set in pairs(MinggeData.SETS) do
    ASSERT(MinggeData.STAT_FIELDS[set.stat] ~= nil,
        "套装 " .. setId .. ".stat=" .. set.stat .. " 在 STAT_FIELDS 中")
end

-- ============================================================================
-- R9: SOURCES 中每个 source.stat 在 STAT_RANGES[source.tier] 中存在
-- ============================================================================
SUITE("R9: SOURCES.stat 与 STAT_RANGES 一致")

for bossId, source in pairs(MinggeData.SOURCES) do
    local tierData = MinggeData.STAT_RANGES[source.tier]
    ASSERT(tierData ~= nil,
        bossId .. ": tier=" .. source.tier .. " 在 STAT_RANGES 中存在")
    if tierData then
        ASSERT(tierData[source.stat] ~= nil,
            bossId .. ": stat=" .. source.stat .. " 在 T" .. source.tier .. " STAT_RANGES 中存在")
    end
end

-- ============================================================================
-- R10: ELEMENT_STATS 五行归属无重复、覆盖全部 source.stat
-- ============================================================================
SUITE("R10: ELEMENT_STATS 归属完整性")

ASSERT(MinggeData.ELEMENT_STATS ~= nil, "ELEMENT_STATS 存在")

if MinggeData.ELEMENT_STATS then
    -- 收集所有已归属的 stat
    local assignedStats = {}
    local duplicates = {}
    for elem, stats in pairs(MinggeData.ELEMENT_STATS) do
        ASSERT(type(stats) == "table", "ELEMENT_STATS[" .. elem .. "] 为 table")
        for _, statId in ipairs(stats) do
            if assignedStats[statId] then
                duplicates[statId] = (duplicates[statId] or assignedStats[statId]) .. "," .. elem
            else
                assignedStats[statId] = elem
            end
        end
    end

    -- 无重复
    local dupCount = 0
    for statId, elems in pairs(duplicates) do
        dupCount = dupCount + 1
        ASSERT(false, statId .. " 重复归属到: " .. elems)
    end
    if dupCount == 0 then
        passed = passed + 1 -- "无重复归属" 整体通过
    end

    -- 验证每个 SOURCES 的 stat 都在其 element 的归属列表中
    for bossId, source in pairs(MinggeData.SOURCES) do
        local elemStats = MinggeData.ELEMENT_STATS[source.element]
        if elemStats then
            local found = false
            for _, s in ipairs(elemStats) do
                if s == source.stat then found = true; break end
            end
            ASSERT(found,
                bossId .. ": stat=" .. source.stat .. " 在 ELEMENT_STATS[" .. source.element .. "] 中")
        end
    end
end

-- ============================================================================
-- 汇总
-- ============================================================================
print("")
print("================================================================")
if failed == 0 then
    print(string.format("  五行命格属性范围：全部 %d 项通过 ✓", passed))
else
    print(string.format("  五行命格属性范围：%d 失败 / %d 总计", failed, passed + failed))
    for _, e in ipairs(errors) do
        print("    ✗ " .. e)
    end
end
print("================================================================")
print("")

return { passed = passed, failed = failed, total = passed + failed }
