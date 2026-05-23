-- ============================================================================
-- test_jiefeng_sword_config.lua — 解封仙剑配置正确性验证
--
-- 覆盖范围：
--   S1: 互斥规则 — 四把解封仙剑只有 hasSaintStat，没有 hasSpiritStat
--   S2: 配方标签 — SWORD_FORGE_COSTS 四条标签均为"解封古剑·X"格式
--   S3: 配方完整性 — fromBag 的 equipId 均以 fengyin_ 开头
--   S4: 封印古剑存在 — fengyin_* 均在 SpecialEquipment 中有定义
--   S5: 解封古剑主属性 — 四剑 mainStat.atk = 220.5（T10 红/圣器）
--   S6: 产出 ID 一致 — SWORD_FORGE_COSTS[key].outputId == key
-- ============================================================================

local EquipmentData = require("config.EquipmentData")

-- ── 测试框架（inline，无引擎依赖）────────────────────────────────────────────

local passed = 0
local failed = 0
local errors = {}

local function ASSERT(cond, desc)
    if cond then
        passed = passed + 1
        print("  ✓ " .. desc)
    else
        failed = failed + 1
        print("  ✗ FAIL: " .. desc)
        table.insert(errors, desc)
    end
end

local function ASSERT_EQ(actual, expected, desc)
    if actual == expected then
        passed = passed + 1
        print("  ✓ " .. desc)
    else
        failed = failed + 1
        local msg = string.format("%s (expected=%s, actual=%s)", desc, tostring(expected), tostring(actual))
        print("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function ASSERT_NIL(val, desc)
    if val == nil then
        passed = passed + 1
        print("  ✓ " .. desc)
    else
        failed = failed + 1
        local msg = desc .. " (expected nil, got " .. tostring(val) .. ")"
        print("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function SUITE(name)
    print("")
    print("  ── " .. name .. " ──")
end

-- ── 常量 ──────────────────────────────────────────────────────────────────────

local JIEFENG_IDS = {
    "jiefeng_zhuxian_ch5",
    "jiefeng_xianxian_ch5",
    "jiefeng_luxian_ch5",
    "jiefeng_juexian_ch5",
}

local FENGYIN_IDS = {
    "fengyin_zhuxian_ch5",
    "fengyin_xianxian_ch5",
    "fengyin_luxian_ch5",
    "fengyin_juexian_ch5",
}

local EXPECTED_LABELS = {
    jiefeng_zhuxian_ch5 = "解封古剑·诛仙",
    jiefeng_xianxian_ch5 = "解封古剑·陷仙",
    jiefeng_luxian_ch5  = "解封古剑·戮仙",
    jiefeng_juexian_ch5 = "解封古剑·绝仙",
}

-- ============================================================================
-- S1: 圣性/灵性互斥规则
-- ============================================================================
SUITE("S1: 圣性/灵性互斥规则")

for _, id in ipairs(JIEFENG_IDS) do
    local def = EquipmentData.SpecialEquipment[id]
    ASSERT(def ~= nil, id .. " 在 SpecialEquipment 中存在")
    if def then
        ASSERT_EQ(def.hasSaintStat, true,  id .. ": hasSaintStat=true")
        ASSERT_NIL(def.hasSpiritStat,      id .. ": hasSpiritStat=nil（与圣性互斥）")
    end
end

-- ============================================================================
-- S2: SWORD_FORGE_COSTS 配方标签
-- ============================================================================
SUITE("S2: SWORD_FORGE_COSTS 配方标签")

ASSERT(EquipmentData.SWORD_FORGE_COSTS ~= nil, "SWORD_FORGE_COSTS 表存在")

for id, expectedLabel in pairs(EXPECTED_LABELS) do
    local recipe = EquipmentData.SWORD_FORGE_COSTS[id]
    ASSERT(recipe ~= nil, "配方 " .. id .. " 存在")
    if recipe then
        ASSERT_EQ(recipe.label, expectedLabel, id .. " label=" .. expectedLabel)
        -- 确认旧标签已不存在
        ASSERT(recipe.label ~= "一重解封·" .. string.match(id, "jiefeng_(%a+)_ch5"),
            id .. " label 不含\"一重解封\"前缀")
    end
end

-- ============================================================================
-- S3: fromBag.equipId 以 fengyin_ 开头
-- ============================================================================
SUITE("S3: 配方 fromBag 指向封印古剑")

for id, _ in pairs(EXPECTED_LABELS) do
    local recipe = EquipmentData.SWORD_FORGE_COSTS[id]
    if recipe then
        ASSERT(recipe.fromBag ~= nil, id .. ": fromBag 字段存在")
        if recipe.fromBag then
            local fbId = recipe.fromBag.equipId
            ASSERT(fbId ~= nil, id .. ": fromBag.equipId 不为 nil")
            if fbId then
                ASSERT(string.find(fbId, "^fengyin_") ~= nil,
                    id .. ": fromBag.equipId 以 fengyin_ 开头（实际=" .. fbId .. "）")
            end
        end
    end
end

-- ============================================================================
-- S4: fengyin_* 封印古剑均在 SpecialEquipment 中有定义
-- ============================================================================
SUITE("S4: 封印古剑 SpecialEquipment 定义存在")

for _, fid in ipairs(FENGYIN_IDS) do
    local def = EquipmentData.SpecialEquipment[fid]
    ASSERT(def ~= nil, fid .. " 在 SpecialEquipment 中存在")
    if def then
        ASSERT(def.name ~= nil, fid .. ": name 不为 nil")
        ASSERT_EQ(def.slot, "weapon", fid .. ": slot=weapon")
        -- 封印古剑本身允许有 hasSpiritStat（掉落时附加随机灵性）
        -- 此处不约束，只验证存在性
    end
end

-- ============================================================================
-- S5: 解封古剑主属性数值
-- ============================================================================
SUITE("S5: 解封古剑主属性 mainStat.atk=220.5")

for _, id in ipairs(JIEFENG_IDS) do
    local def = EquipmentData.SpecialEquipment[id]
    if def then
        ASSERT(def.mainStat ~= nil, id .. ": mainStat 存在")
        if def.mainStat then
            ASSERT_EQ(def.mainStat.atk, 220.5, id .. ": mainStat.atk=220.5")
        end
        ASSERT_EQ(def.tier, 10, id .. ": tier=10")
        ASSERT_EQ(def.quality, "red", id .. ": quality=red")
        ASSERT_EQ(def.slot, "weapon", id .. ": slot=weapon")
    end
end

-- ============================================================================
-- S6: outputId 与 key 一致
-- ============================================================================
SUITE("S6: SWORD_FORGE_COSTS outputId 与 key 一致")

for id, _ in pairs(EXPECTED_LABELS) do
    local recipe = EquipmentData.SWORD_FORGE_COSTS[id]
    if recipe then
        ASSERT_EQ(recipe.outputId, id, id .. ": outputId==" .. id)
    end
end

-- ============================================================================
-- 汇总
-- ============================================================================
print("")
print("================================================================")
if failed == 0 then
    print(string.format("  解封仙剑配置验证：全部 %d 项通过", passed))
else
    print(string.format("  解封仙剑配置验证：%d 失败 / %d 总计", failed, passed + failed))
    for _, e in ipairs(errors) do
        print("    ✗ " .. e)
    end
end
print("================================================================")
print("")

return { passed = passed, failed = failed, total = passed + failed }
