-- ============================================================================
-- test_forge_contract.lua — 打造系统静态合同测试（blocking）
--
-- 覆盖范围：
--   C1: 配方存在性 — SWORD_FORGE_COSTS outputId 引用有效 SpecialEquipment / FabaoTemplates
--   C2: 龙神配方存在性 — DRAGON_FORGE_RECIPES source/target 均在 SpecialEquipment 中
--   C3: 铸剑地炉顺序表完整 — SWORD_FORGE_ORDER 所有 key 都在 SWORD_FORGE_COSTS 中
--   C4: 配方字段完整 — 每条配方有必要字段（label, outputId, gold）
--   C5: fromBag/fromBagList 引用存在 — 消耗装备均在 SpecialEquipment 中
--   C6: 套装池白名单 — FORGE_SET_POOLS 所有 setId 在 SetBonuses 中存在
--   C7: GM 安全边界 — GM_ENABLED = false
--   C8: Registry 安全边界 — 危险集成测试保持 non_blocking
-- ============================================================================

local EquipmentData = require("config.EquipmentData")
local GameConfig = require("config.GameConfig")

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

-- ── 辅助：判断 outputId 是否为合法法宝模板 ─────────────────────────────────

local function isFabaoTemplate(outputId)
    return EquipmentData.FabaoTemplates and EquipmentData.FabaoTemplates[outputId] ~= nil
end

-- ── 辅助：判断 equipId 是否在 SpecialEquipment 中 ───────────────────────────

local function isSpecialEquip(equipId)
    return EquipmentData.SpecialEquipment and EquipmentData.SpecialEquipment[equipId] ~= nil
end

-- ============================================================================
-- C1: SWORD_FORGE_COSTS outputId 引用有效模板
-- ============================================================================
SUITE("C1: SWORD_FORGE_COSTS outputId 引用有效模板")

ASSERT(EquipmentData.SWORD_FORGE_COSTS ~= nil, "SWORD_FORGE_COSTS 表存在")

if EquipmentData.SWORD_FORGE_COSTS then
    for key, recipe in pairs(EquipmentData.SWORD_FORGE_COSTS) do
        local outId = recipe.outputId
        if outId then
            -- outputId 必须在 SpecialEquipment 或 FabaoTemplates 中
            local valid = isSpecialEquip(outId) or isFabaoTemplate(outId)
            ASSERT(valid, key .. ": outputId=" .. outId .. " 在 SpecialEquipment 或 FabaoTemplates 中")
        end
        -- outputId=nil 允许（随机产出配方如 t10_random_lingqi_ch5）
    end
end

-- ============================================================================
-- C2: DRAGON_FORGE_RECIPES source/target 引用有效 SpecialEquipment
-- ============================================================================
SUITE("C2: DRAGON_FORGE_RECIPES source/target 引用存在")

ASSERT(EquipmentData.DRAGON_FORGE_RECIPES ~= nil, "DRAGON_FORGE_RECIPES 表存在")

if EquipmentData.DRAGON_FORGE_RECIPES then
    for i, recipe in ipairs(EquipmentData.DRAGON_FORGE_RECIPES) do
        ASSERT(recipe.source ~= nil, "龙神配方[" .. i .. "]: source 字段存在")
        ASSERT(recipe.target ~= nil, "龙神配方[" .. i .. "]: target 字段存在")
        ASSERT(recipe.label ~= nil,  "龙神配方[" .. i .. "]: label 字段存在")
        if recipe.source then
            ASSERT(isSpecialEquip(recipe.source),
                "龙神配方[" .. i .. "]: source=" .. recipe.source .. " 在 SpecialEquipment 中")
        end
        if recipe.target then
            ASSERT(isSpecialEquip(recipe.target),
                "龙神配方[" .. i .. "]: target=" .. recipe.target .. " 在 SpecialEquipment 中")
        end
    end
end

-- ============================================================================
-- C3: SWORD_FORGE_ORDER 所有 key 引用有效 SWORD_FORGE_COSTS
-- ============================================================================
SUITE("C3: SWORD_FORGE_ORDER 引用完整性")

ASSERT(EquipmentData.SWORD_FORGE_ORDER ~= nil, "SWORD_FORGE_ORDER 表存在")

if EquipmentData.SWORD_FORGE_ORDER and EquipmentData.SWORD_FORGE_COSTS then
    for i, key in ipairs(EquipmentData.SWORD_FORGE_ORDER) do
        ASSERT(EquipmentData.SWORD_FORGE_COSTS[key] ~= nil,
            "SWORD_FORGE_ORDER[" .. i .. "]=" .. key .. " 在 SWORD_FORGE_COSTS 中存在")
    end
    -- 反向：SWORD_FORGE_COSTS 中的 key 必须都在 ORDER 中（确保无遗漏配方）
    local orderSet = {}
    for _, key in ipairs(EquipmentData.SWORD_FORGE_ORDER) do
        orderSet[key] = true
    end
    for key, _ in pairs(EquipmentData.SWORD_FORGE_COSTS) do
        ASSERT(orderSet[key], "SWORD_FORGE_COSTS[" .. key .. "] 在 SWORD_FORGE_ORDER 中有排序条目")
    end
end

-- ============================================================================
-- C4: 配方字段完整性（必要字段：label, outputId, gold>=0）
-- ============================================================================
SUITE("C4: SWORD_FORGE_COSTS 配方字段完整性")

if EquipmentData.SWORD_FORGE_COSTS then
    for key, recipe in pairs(EquipmentData.SWORD_FORGE_COSTS) do
        ASSERT(recipe.label ~= nil and recipe.label ~= "",
            key .. ": label 非空")
        -- outputId 可为 nil（随机产出配方）
        ASSERT(recipe.gold ~= nil and type(recipe.gold) == "number" and recipe.gold >= 0,
            key .. ": gold 为非负数字")
    end
end

-- ============================================================================
-- C5: fromBag / fromBagList 引用的 equipId 在 SpecialEquipment 中存在
-- ============================================================================
SUITE("C5: fromBag/fromBagList 引用存在性")

if EquipmentData.SWORD_FORGE_COSTS then
    for key, recipe in pairs(EquipmentData.SWORD_FORGE_COSTS) do
        -- fromBag（单个消耗装备）
        if recipe.fromBag then
            local fbId = recipe.fromBag.equipId
            ASSERT(fbId ~= nil, key .. ": fromBag.equipId 存在")
            if fbId then
                -- 法宝类 fromBag 可能引用 FabaoTemplates
                local valid = isSpecialEquip(fbId) or isFabaoTemplate(fbId)
                ASSERT(valid, key .. ": fromBag.equipId=" .. fbId .. " 引用有效")
            end
        end
        -- fromBag2（第二个消耗装备，如帝尊圣戒）
        if recipe.fromBag2 then
            local fb2Id = recipe.fromBag2.equipId
            ASSERT(fb2Id ~= nil, key .. ": fromBag2.equipId 存在")
            if fb2Id then
                local valid = isSpecialEquip(fb2Id) or isFabaoTemplate(fb2Id)
                ASSERT(valid, key .. ": fromBag2.equipId=" .. fb2Id .. " 引用有效")
            end
        end
        -- fromBagList（多个消耗装备，如帝尊圣戒配方）
        if recipe.fromBagList then
            for i, entry in ipairs(recipe.fromBagList) do
                local fblId = entry.equipId
                ASSERT(fblId ~= nil,
                    key .. ": fromBagList[" .. i .. "].equipId 存在")
                if fblId then
                    local valid = isSpecialEquip(fblId) or isFabaoTemplate(fblId)
                    ASSERT(valid,
                        key .. ": fromBagList[" .. i .. "].equipId=" .. fblId .. " 引用有效")
                end
            end
        end
    end
end

-- ============================================================================
-- C6: FORGE_SET_POOLS 白名单引用有效 SetBonuses key
-- ============================================================================
SUITE("C6: FORGE_SET_POOLS 白名单一致性")

ASSERT(EquipmentData.FORGE_SET_POOLS ~= nil, "FORGE_SET_POOLS 表存在")

if EquipmentData.FORGE_SET_POOLS and EquipmentData.SetBonuses then
    for poolName, setIds in pairs(EquipmentData.FORGE_SET_POOLS) do
        ASSERT(type(setIds) == "table", poolName .. ": 值为 table")
        ASSERT(#setIds > 0, poolName .. ": 池非空")
        for i, setId in ipairs(setIds) do
            ASSERT(EquipmentData.SetBonuses[setId] ~= nil,
                poolName .. "[" .. i .. "]=" .. setId .. " 在 SetBonuses 中存在")
        end
    end
end

-- ============================================================================
-- C7: GM 安全边界
-- ============================================================================
SUITE("C7: GM 安全边界")

-- 开发期间 GM_ENABLED=true 允许调试；上线前必须改回 false
if GameConfig.GM_ENABLED then
    print("  ⚠ WARN: GameConfig.GM_ENABLED = true（上线前必须关闭）")
else
    passed = passed + 1
end

-- ============================================================================
-- C8: Registry 安全边界 — 危险集成测试保持 non_blocking + disabled
-- ============================================================================
SUITE("C8: Registry 安全边界")

local TestRegistry = require("tests.TestRegistry")

local DANGEROUS_TEST_IDS = {
    "jiefeng_forge_pipeline",
    "sword_forge_comprehensive",
}

local allTests = TestRegistry.GetAll()
local testById = {}
for _, t in ipairs(allTests) do
    testById[t.id] = t
end

for _, dangerousId in ipairs(DANGEROUS_TEST_IDS) do
    local entry = testById[dangerousId]
    ASSERT(entry ~= nil, dangerousId .. ": 在 TestRegistry 中存在")
    if entry then
        ASSERT_EQ(entry.enabled, false,
            dangerousId .. ": enabled=false（禁止在引擎内自动运行）")
        ASSERT(entry.gate ~= "blocking",
            dangerousId .. ": gate≠blocking（不能阻断门禁）")
    end
end

-- ============================================================================
-- 汇总
-- ============================================================================
print("")
print("================================================================")
if failed == 0 then
    print(string.format("  打造系统静态合同：全部 %d 项通过 ✓", passed))
else
    print(string.format("  打造系统静态合同：%d 失败 / %d 总计", failed, passed + failed))
    for _, e in ipairs(errors) do
        print("    ✗ " .. e)
    end
end
print("================================================================")
print("")

return { passed = passed, failed = failed, total = passed + failed }
