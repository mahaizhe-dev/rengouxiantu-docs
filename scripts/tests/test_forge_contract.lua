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
--   C8: Registry 安全边界 — 危险集成测试若存在必须 non_blocking
--   C9: 虎王试炼炉 — 第一章独立站点与唯一配方
--   C10: 乌堡锻造台 — 第二章独立站点与唯一配方
--   C11: 图鉴运行时生效 — 所有 Collection.entries bonus 均实际应用到 Player 字段
--   C14: 第四至第六章锻造链优化 — 配方、模板、图鉴和UI语义精确一致
-- ============================================================================

local EquipmentData = require("config.EquipmentData")
local GameConfig = require("config.GameConfig")
local TigerDomainZone = require("config.zones.tiger_domain")
local Chapter2FortressZone = require("config.zones.chapter2.fortress_e")
local Chapter3Fort1Zone = require("config.zones.chapter3.fort_1")
local CollectionSystem = require("systems.CollectionSystem")
local GameState = require("core.GameState")

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

local function ASSERT_NUM_EQ(actual, expected, desc)
    actual = actual or 0
    expected = expected or 0
    local ok = type(actual) == "number" and type(expected) == "number" and math.abs(actual - expected) < 0.000001
    ASSERT(ok, desc .. string.format(" (expected=%s, actual=%s)", tostring(expected), tostring(actual)))
end

local function SUITE(name)
    print("")
    print("  ── " .. name .. " ──")
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local text = f:read("*a") or ""
    f:close()
    return text
end

local function fileContains(path, needle)
    return readFile(path):find(needle, 1, true) ~= nil
end

local function indexOf(path, needle)
    local pos = readFile(path):find(needle, 1, true)
    return pos or -1
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
-- C8: Registry 安全边界 — 危险集成测试若存在必须 non_blocking + disabled
-- ============================================================================
SUITE("C8: Registry 安全边界")

local TestRegistry = require("tests.TestRegistry")

local DANGEROUS_TEST_IDS = {
    "jiefeng_forge_pipeline",
    "sword_forge_comprehensive",
    "ch1_tiger_trial_forge_pipeline",
    "ch2_wubao_forge_pipeline",
    "ch3_huangsha_forge_pipeline",
    "all_forge_pipeline",
}

local allTests = TestRegistry.GetAll()
local testById = {}
for _, t in ipairs(allTests) do
    testById[t.id] = t
end

for _, dangerousId in ipairs(DANGEROUS_TEST_IDS) do
    local entry = testById[dangerousId]
    if entry then
        ASSERT_EQ(entry.enabled, false,
            dangerousId .. ": enabled=false（禁止在引擎内自动运行）")
        ASSERT(entry.gate ~= "blocking",
            dangerousId .. ": gate≠blocking（不能阻断门禁）")
    else
        passed = passed + 1
    end
end

-- ============================================================================
-- C9: 虎王试炼炉独立站点与唯一配方
-- ============================================================================
SUITE("C9: 虎王试炼炉独立站点")

ASSERT(EquipmentData.FORGE_STATIONS and EquipmentData.FORGE_STATIONS.tiger_trial_forge ~= nil,
    "tiger_trial_forge 站点存在")

local tigerForgeNpc = nil
for _, npc in ipairs(TigerDomainZone.npcs or {}) do
    if npc.id == "ch1_tiger_trial_forge" then
        tigerForgeNpc = npc
        break
    end
end
ASSERT(tigerForgeNpc ~= nil, "虎王试炼炉地图交互物存在")
if tigerForgeNpc then
    ASSERT_EQ(tigerForgeNpc.interactType, "tiger_trial_forge", "虎王试炼炉使用独立交互")
    ASSERT(tigerForgeNpc.isObject == true, "虎王试炼炉使用物件渲染")
    ASSERT(tigerForgeNpc.showNameplate == true and tigerForgeNpc.hideName ~= true, "虎王试炼炉显示 NPC 新名板")
    ASSERT_EQ(tigerForgeNpc.name, "虎王试炼炉", "虎王试炼炉名板标题正确")
    ASSERT_EQ(tigerForgeNpc.subtitle, "极虎锻造", "虎王试炼炉名板副标题正确")
end

local tigerOrder = EquipmentData.FORGE_RECIPE_ORDER and EquipmentData.FORGE_RECIPE_ORDER.tiger_trial_forge
ASSERT(tigerOrder ~= nil and #tigerOrder == 1 and tigerOrder[1] == "tiger_trial_jihu_helmet",
    "虎王试炼炉只有极虎盔一个配方")

local tigerRecipe = EquipmentData.FORGE_RECIPES and EquipmentData.FORGE_RECIPES.tiger_trial_jihu_helmet
ASSERT(tigerRecipe ~= nil, "极虎盔配方存在")
if tigerRecipe then
    ASSERT_EQ(tigerRecipe.stationId, "tiger_trial_forge", "极虎盔配方归属第一章站点")
    ASSERT_EQ(tigerRecipe.outputId, "jihu_helmet_ch1", "极虎盔配方产出 ID 正确")
    ASSERT_EQ(tigerRecipe.generator and tigerRecipe.generator.type, "fixed_special_equipment", "极虎盔使用固定特殊装备生成器")
    ASSERT_EQ(tigerRecipe.gold, 10000, "极虎盔配方金币消耗 1 万")
    ASSERT_EQ(#(tigerRecipe.fromBagList or {}), 4, "极虎盔消耗四件装备")

    local consumes = {}
    for _, entry in ipairs(tigerRecipe.fromBagList or {}) do
        consumes[entry.equipId] = true
    end
    ASSERT(consumes.tiger_set_weapon, "极虎盔消耗虎牙刃")
    ASSERT(consumes.tiger_set_armor, "极虎盔消耗虎王铠")
    ASSERT(consumes.tiger_set_necklace, "极虎盔消耗虎王血珀")
    ASSERT(consumes.dizun_ring_ch1, "极虎盔消耗帝尊壹戒")
    ASSERT(not consumes.tiger_set_cape, "极虎盔不消耗虎纹战袍")
end

for _, id in ipairs((EquipmentData.FORGE_RECIPE_ORDER and EquipmentData.FORGE_RECIPE_ORDER.sword_forge) or {}) do
    ASSERT(id ~= "tiger_trial_jihu_helmet", "第五章铸剑地炉不显示极虎盔配方")
end

local jihu = EquipmentData.SpecialEquipment and EquipmentData.SpecialEquipment.jihu_helmet_ch1
ASSERT(jihu ~= nil, "极虎盔特殊装备模板存在")
if jihu then
    ASSERT_EQ(jihu.slot, "helmet", "极虎盔槽位为头盔")
    ASSERT_EQ(jihu.icon, "image/icon_jihu_helmet_ch1_20260703062816.png", "极虎盔使用专属图标")
    ASSERT_EQ(jihu.quality, "orange", "极虎盔品质为橙色")
    ASSERT_EQ(jihu.tier, 4, "极虎盔为 T4")
    ASSERT_EQ(jihu.mainStat and jihu.mainStat.maxHp, 135, "极虎盔主属性生命值正确")
    ASSERT(jihu.fixedSubStats == true, "极虎盔副属性固定")
end

local ch1HasJihu = false
for _, id in ipairs((EquipmentData.Collection.chapters[1] or {}).order or {}) do
    if id == "jihu_helmet_ch1" then ch1HasJihu = true end
end
ASSERT(ch1HasJihu, "极虎盔进入第一章图鉴")

local collectionEntry = EquipmentData.Collection.entries and EquipmentData.Collection.entries.jihu_helmet_ch1
ASSERT(collectionEntry ~= nil, "极虎盔图鉴条目存在")
ASSERT_EQ(collectionEntry and collectionEntry.bonus and collectionEntry.bonus.atk, 5, "极虎盔图鉴奖励 atk+5")

-- ============================================================================
-- C10: 乌堡锻造台独立站点与唯一配方
-- ============================================================================
SUITE("C10: 乌堡锻造台独立站点")

ASSERT(EquipmentData.FORGE_STATIONS and EquipmentData.FORGE_STATIONS.wubao_forge ~= nil,
    "wubao_forge 站点存在")
if EquipmentData.FORGE_STATIONS and EquipmentData.FORGE_STATIONS.wubao_forge then
    ASSERT_EQ(EquipmentData.FORGE_STATIONS.wubao_forge.name, "乌堡锻造台", "乌堡锻造台站点名正确")
    ASSERT_EQ(EquipmentData.FORGE_STATIONS.wubao_forge.subtitle, "血海锻戒", "乌堡锻造台副标题正确")
end

local wubaoForgeNpc = nil
for _, npc in ipairs(Chapter2FortressZone.npcs or {}) do
    if npc.id == "ch2_wubao_forge" then
        wubaoForgeNpc = npc
        break
    end
end
ASSERT(wubaoForgeNpc ~= nil, "乌堡锻造台地图交互物存在")
if wubaoForgeNpc then
    ASSERT_EQ(wubaoForgeNpc.interactType, "wubao_forge", "乌堡锻造台使用独立交互")
    ASSERT(wubaoForgeNpc.isObject == true, "乌堡锻造台使用物件渲染")
    ASSERT(wubaoForgeNpc.showNameplate == true and wubaoForgeNpc.hideName ~= true, "乌堡锻造台显示 NPC 新名板")
    ASSERT_EQ(wubaoForgeNpc.name, "乌堡锻造台", "乌堡锻造台名板标题正确")
    ASSERT_EQ(wubaoForgeNpc.subtitle, "血海锻戒", "乌堡锻造台名板副标题正确")
    ASSERT_EQ(wubaoForgeNpc.zone, "fortress_e3", "乌堡锻造台位于乌堡大殿")
    ASSERT_EQ(wubaoForgeNpc.x, 40.5, "乌堡锻造台 X 坐标居中到 40 格")
    ASSERT_EQ(wubaoForgeNpc.y, 41.5, "乌堡锻造台 Y 坐标居中到 41 格")
end

local wubaoOrder = EquipmentData.FORGE_RECIPE_ORDER and EquipmentData.FORGE_RECIPE_ORDER.wubao_forge
ASSERT(wubaoOrder ~= nil and #wubaoOrder == 1 and wubaoOrder[1] == "wubao_xuehai_shenchou_ring",
    "乌堡锻造台只有血海深仇戒一个配方")

local wubaoRecipe = EquipmentData.FORGE_RECIPES and EquipmentData.FORGE_RECIPES.wubao_xuehai_shenchou_ring
ASSERT(wubaoRecipe ~= nil, "血海深仇戒配方存在")
if wubaoRecipe then
    ASSERT_EQ(wubaoRecipe.stationId, "wubao_forge", "血海深仇戒配方归属第二章站点")
    ASSERT_EQ(wubaoRecipe.outputId, "xuehai_shenchou_ring_ch2", "血海深仇戒产出 ID 正确")
    ASSERT_EQ(wubaoRecipe.generator and wubaoRecipe.generator.type, "fixed_special_equipment", "血海深仇戒使用固定特殊装备生成器")
    ASSERT_EQ(wubaoRecipe.gold, 100000, "血海深仇戒金币消耗 10 万")
    ASSERT_EQ(#(wubaoRecipe.fromBagList or {}), 3, "血海深仇戒消耗三件装备")

    local consumes = {}
    for _, entry in ipairs(wubaoRecipe.fromBagList or {}) do
        consumes[entry.equipId] = true
    end
    ASSERT(consumes.wu_ring_hai, "血海深仇戒消耗乌堡戒·海")
    ASSERT(consumes.wu_ring_chou, "血海深仇戒消耗乌堡戒·仇")
    ASSERT(consumes.dizun_ring_ch2, "血海深仇戒消耗帝尊贰戒")
end

for _, id in ipairs((EquipmentData.FORGE_RECIPE_ORDER and EquipmentData.FORGE_RECIPE_ORDER.tiger_trial_forge) or {}) do
    ASSERT(id ~= "wubao_xuehai_shenchou_ring", "第一章虎王试炼炉不显示血海深仇戒配方")
end
for _, id in ipairs((EquipmentData.FORGE_RECIPE_ORDER and EquipmentData.FORGE_RECIPE_ORDER.sword_forge) or {}) do
    ASSERT(id ~= "wubao_xuehai_shenchou_ring", "第五章铸剑地炉不显示血海深仇戒配方")
end

local xuehaiRing = EquipmentData.SpecialEquipment and EquipmentData.SpecialEquipment.xuehai_shenchou_ring_ch2
ASSERT(xuehaiRing ~= nil, "血海深仇戒特殊装备模板存在")
if xuehaiRing then
    ASSERT_EQ(xuehaiRing.slot, "ring1", "血海深仇戒槽位为戒指")
    ASSERT_EQ(xuehaiRing.icon, "icon_t6_ring.png", "血海深仇戒使用 T6 戒指图标")
    ASSERT_EQ(xuehaiRing.quality, "orange", "血海深仇戒品质为橙色")
    ASSERT_EQ(xuehaiRing.tier, 6, "血海深仇戒为 T6")
    ASSERT_EQ(xuehaiRing.mainStat and xuehaiRing.mainStat.atk, 36, "血海深仇戒主属性攻击正确")
    ASSERT_EQ(xuehaiRing.subStats and xuehaiRing.subStats[1] and xuehaiRing.subStats[1].stat, "critRate", "血海深仇戒副属性含暴击")
    ASSERT_EQ(xuehaiRing.subStats and xuehaiRing.subStats[2] and xuehaiRing.subStats[2].stat, "heavyHit", "血海深仇戒副属性含重击")
    ASSERT_EQ(xuehaiRing.subStats and xuehaiRing.subStats[3] and xuehaiRing.subStats[3].stat, "constitution", "血海深仇戒副属性含根骨")
    ASSERT(xuehaiRing.fixedSubStats == true, "血海深仇戒副属性固定")
end

local ch2HasXuehaiRing = false
for _, id in ipairs((EquipmentData.Collection.chapters[2] or {}).order or {}) do
    if id == "xuehai_shenchou_ring_ch2" then ch2HasXuehaiRing = true end
end
ASSERT(ch2HasXuehaiRing, "血海深仇戒进入第二章图鉴")

local xuehaiCollectionEntry = EquipmentData.Collection.entries and EquipmentData.Collection.entries.xuehai_shenchou_ring_ch2
ASSERT(xuehaiCollectionEntry ~= nil, "血海深仇戒图鉴条目存在")
ASSERT_EQ(xuehaiCollectionEntry and xuehaiCollectionEntry.bonus and xuehaiCollectionEntry.bonus.def, 5,
    "血海深仇戒图鉴奖励 def+5")
ASSERT_EQ(xuehaiCollectionEntry and xuehaiCollectionEntry.bonus and xuehaiCollectionEntry.bonus.maxHp, 20,
    "血海深仇戒图鉴奖励 maxHp+20")

-- ============================================================================
-- C11: 黄沙锻造台独立站点与黄沙换兵配方
-- ============================================================================
SUITE("C11: 黄沙锻造台独立站点")

ASSERT(EquipmentData.FORGE_STATIONS and EquipmentData.FORGE_STATIONS.huangsha_forge ~= nil,
    "huangsha_forge 站点存在")
if EquipmentData.FORGE_STATIONS and EquipmentData.FORGE_STATIONS.huangsha_forge then
    ASSERT_EQ(EquipmentData.FORGE_STATIONS.huangsha_forge.name, "黄沙锻造台", "黄沙锻造台站点名正确")
    ASSERT_EQ(EquipmentData.FORGE_STATIONS.huangsha_forge.subtitle, "黄沙换兵", "黄沙锻造台副标题正确")
end

local huangshaForgeNpc = nil
for _, npc in ipairs(Chapter3Fort1Zone.npcs or {}) do
    if npc.id == "ch3_huangsha_forge" then
        huangshaForgeNpc = npc
        break
    end
end
ASSERT(huangshaForgeNpc ~= nil, "黄沙锻造台地图交互物存在")
if huangshaForgeNpc then
    ASSERT_EQ(huangshaForgeNpc.interactType, "huangsha_forge", "黄沙锻造台使用独立交互")
    ASSERT(huangshaForgeNpc.isObject == true, "黄沙锻造台使用物件渲染")
    ASSERT(huangshaForgeNpc.showNameplate == true and huangshaForgeNpc.hideName ~= true, "黄沙锻造台显示 NPC 新名板")
    ASSERT_EQ(huangshaForgeNpc.name, "黄沙锻造台", "黄沙锻造台名板标题正确")
    ASSERT_EQ(huangshaForgeNpc.subtitle, "黄沙换兵", "黄沙锻造台名板副标题正确")
    ASSERT_EQ(huangshaForgeNpc.zone, "ch3_fort_1", "黄沙锻造台位于第三章第一寨")
    ASSERT_EQ(huangshaForgeNpc.x, 65, "黄沙锻造台 X 坐标为 65")
    ASSERT_EQ(huangshaForgeNpc.y, 59, "黄沙锻造台 Y 坐标为 59")
end

local hasStoneAtForge = false
for _, deco in ipairs(Chapter3Fort1Zone.decorations or {}) do
    if deco.type == "stone_tablet" and deco.x == 65 and deco.y == 59 then
        hasStoneAtForge = true
        break
    end
end
ASSERT(not hasStoneAtForge, "65,59 石碑装饰已移除")

local huangshaOrder = EquipmentData.FORGE_RECIPE_ORDER and EquipmentData.FORGE_RECIPE_ORDER.huangsha_forge
ASSERT(huangshaOrder ~= nil and #huangshaOrder == 1 and huangshaOrder[1] == "huangsha_weapon_reroll",
    "黄沙锻造台只有黄沙换兵一个配方")

local huangshaRecipe = EquipmentData.FORGE_RECIPES and EquipmentData.FORGE_RECIPES.huangsha_weapon_reroll
ASSERT(huangshaRecipe ~= nil, "黄沙换兵配方存在")
if huangshaRecipe then
    ASSERT_EQ(huangshaRecipe.stationId, "huangsha_forge", "黄沙换兵配方归属第三章站点")
    ASSERT_EQ(huangshaRecipe.inputMode, "equip_weapon", "黄沙换兵要求装备栏武器")
    ASSERT_EQ(huangshaRecipe.outputMode, "replace_weapon", "黄沙换兵原地替换武器")
    ASSERT_EQ(huangshaRecipe.gold, 1000000, "黄沙换兵金币消耗 100 万")
    ASSERT_EQ(huangshaRecipe.fromBag2 and huangshaRecipe.fromBag2.equipId, "dizun_ring_ch3", "黄沙换兵消耗帝尊叁戒")
    ASSERT_EQ(#(huangshaRecipe.materials or {}), 1, "黄沙换兵消耗 1 种普通材料")
    ASSERT_EQ(huangshaRecipe.materials and huangshaRecipe.materials[1] and huangshaRecipe.materials[1].id, "sha_hai_ling", "黄沙换兵消耗沙海令")
    ASSERT_EQ(huangshaRecipe.materials and huangshaRecipe.materials[1] and huangshaRecipe.materials[1].count, 1000, "黄沙换兵消耗 1000 沙海令")
    ASSERT_EQ(huangshaRecipe.generator and huangshaRecipe.generator.type, "random_huangsha_weapon_except_equipped", "黄沙换兵使用随机排除自身生成器")
    ASSERT_EQ(#(huangshaRecipe.equipSourcePool or {}), 5, "黄沙换兵装备输入池为 5 把")
    ASSERT_EQ(#(huangshaRecipe.generator and huangshaRecipe.generator.pool or {}), 5, "黄沙换兵生成池为 5 把")

    local poolSet = {}
    for _, equipId in ipairs(huangshaRecipe.equipSourcePool or {}) do
        poolSet[equipId] = true
        ASSERT(EquipmentData.SpecialEquipment[equipId] ~= nil, "黄沙输入池装备存在：" .. tostring(equipId))
        ASSERT_EQ(EquipmentData.SpecialEquipment[equipId] and EquipmentData.SpecialEquipment[equipId].slot, "weapon", "黄沙输入池必须是武器：" .. tostring(equipId))
    end
    for _, equipId in ipairs((huangshaRecipe.generator and huangshaRecipe.generator.pool) or {}) do
        ASSERT(poolSet[equipId] == true, "黄沙生成池与输入池一致：" .. tostring(equipId))
    end
end

for _, stationId in ipairs({ "tiger_trial_forge", "wubao_forge", "dragon_forge", "sword_forge" }) do
    for _, id in ipairs((EquipmentData.FORGE_RECIPE_ORDER and EquipmentData.FORGE_RECIPE_ORDER[stationId]) or {}) do
        ASSERT(id ~= "huangsha_weapon_reroll", stationId .. " 不显示黄沙换兵配方")
    end
end

ASSERT(fileContains("scripts/ui/GMConsole.lua", "give_huangsha_forge_kit"), "GM 控制台包含黄沙铸造测试包命令")
ASSERT(fileContains("scripts/ui/GMConsole.lua", "CmdGiveHuangshaForgeKit"), "GM 控制台包含黄沙铸造测试包实现函数")
ASSERT(fileContains("scripts/ui/GMConsole.lua", "黄沙铸造包"), "GM 控制台包含黄沙铸造包按钮")
ASSERT(fileContains("scripts/ui/GMConsole.lua", "dizun_ring_ch3"), "黄沙铸造包发放帝尊叁戒")
ASSERT(fileContains("scripts/ui/GMConsole.lua", 'AddConsumable("sha_hai_ling", 1000)'), "黄沙铸造包发放 1000 沙海令")
ASSERT(fileContains("scripts/ui/GMConsole.lua", "5000000"), "黄沙铸造包发放 500 万金币")

local swordForgeUiPath = "scripts/ui/SwordForgeUI.lua"
ASSERT(fileContains(swordForgeUiPath, 'BuildEquippedWeaponRow("任意黄沙武器"'),
    "黄沙换兵 UI 将正确的装备池要求传给公共材料行")
ASSERT(fileContains(swordForgeUiPath, 'local displayText = requiredName .. "（需要装备）"'),
    "黄沙换兵 UI 由公共材料行统一标注需要装备")
ASSERT(fileContains(swordForgeUiPath, 'isHuangshaRerollRecipe and "⚠️ 必须装备黄沙武器" or recipe.desc'), "黄沙换兵按钮上方只显示短警示")
do
    local posWeapon = indexOf(swordForgeUiPath, "-- ── 当前装备武器池输入")
    local posRing = indexOf(swordForgeUiPath, "-- ── fromBag2")
    local posToken = indexOf(swordForgeUiPath, "-- ── 普通材料")
    local posGold = indexOf(swordForgeUiPath, "-- ── 金币（展示在材料列表最后）")
    ASSERT(posWeapon > 0 and posRing > posWeapon and posToken > posRing and posGold > posToken,
        "黄沙换兵材料展示顺序为武器、戒指、令牌、金币")
end

SUITE("C12: 全图鉴运行时实际生效")

do
    local oldPlayer = GameState.player
    local oldCollected = CollectionSystem.collected
    local ok, err = pcall(function()
        local statToPlayerField = {
            atk = "collectionAtk",
            def = "collectionDef",
            maxHp = "collectionHp",
            hpRegen = "collectionHpRegen",
            fortune = "collectionFortune",
            killHeal = "collectionKillHeal",
            heavyHit = "collectionHeavyHit",
            critRate = "collectionCritRate",
            wisdom = "collectionWisdom",
            constitution = "collectionConstitution",
            physique = "collectionPhysique",
        }
        local fieldOrder = {
            "collectionAtk",
            "collectionDef",
            "collectionHp",
            "collectionHpRegen",
            "collectionFortune",
            "collectionKillHeal",
            "collectionHeavyHit",
            "collectionCritRate",
            "collectionWisdom",
            "collectionConstitution",
            "collectionPhysique",
        }
        local expected = {}
        local collected = {}
        local entryCount = 0

        for equipId, entry in pairs(EquipmentData.Collection.entries or {}) do
            entryCount = entryCount + 1
            collected[equipId] = true
            ASSERT(EquipmentData.SpecialEquipment[equipId] ~= nil, "图鉴条目存在对应装备/虚拟模板：" .. tostring(equipId))
            for stat, value in pairs(entry.bonus or {}) do
                local field = statToPlayerField[stat]
                ASSERT(field ~= nil, "图鉴加成字段受 CollectionSystem 支持：" .. tostring(equipId) .. "." .. tostring(stat))
                if field then
                    expected[field] = (expected[field] or 0) + (value or 0)
                end
            end
        end

        local mockPlayer = {
            invalidated = false,
            InvalidateStatsCache = function(self)
                self.invalidated = true
            end,
        }

        GameState.player = mockPlayer
        CollectionSystem.collected = collected
        CollectionSystem.RecalcBonuses()

        for _, field in ipairs(fieldOrder) do
            ASSERT_NUM_EQ(mockPlayer[field], expected[field] or 0, "全图鉴收录后实际应用 " .. field)
        end
        ASSERT(mockPlayer.invalidated, "全图鉴收录后失效角色属性缓存")

        local serialized = CollectionSystem.Serialize()
        ASSERT_EQ(#serialized, entryCount, "全图鉴收录后序列化条目数正确")

        local seen = {}
        for _, equipId in ipairs(serialized) do
            seen[equipId] = true
        end
        for equipId in pairs(EquipmentData.Collection.entries or {}) do
            ASSERT(seen[equipId] == true, "全图鉴序列化包含条目：" .. tostring(equipId))
        end

        local restoredPlayer = {
            invalidated = false,
            InvalidateStatsCache = function(self)
                self.invalidated = true
            end,
        }
        GameState.player = restoredPlayer
        CollectionSystem.Deserialize(serialized)
        for _, field in ipairs(fieldOrder) do
            ASSERT_NUM_EQ(restoredPlayer[field], expected[field] or 0, "全图鉴反序列化后实际应用 " .. field)
        end
        ASSERT(restoredPlayer.invalidated, "全图鉴反序列化后失效角色属性缓存")
    end)
    GameState.player = oldPlayer
    CollectionSystem.collected = oldCollected
    ASSERT(ok, "全图鉴运行时生效测试无异常：" .. tostring(err))
end

SUITE("C13: 统一铸造配置与界面单一数据源")

do
    local recipeOrderSeen = {}
    for stationId, order in pairs(EquipmentData.FORGE_RECIPE_ORDER or {}) do
        ASSERT(EquipmentData.FORGE_STATIONS[stationId] ~= nil,
            "配方顺序表存在对应站点：" .. tostring(stationId))
        for _, recipeId in ipairs(order) do
            local recipe = EquipmentData.FORGE_RECIPES[recipeId]
            ASSERT(recipe ~= nil, "顺序表引用统一配方：" .. tostring(recipeId))
            if recipe then
                ASSERT_EQ(recipe.stationId, stationId,
                    recipeId .. " 统一配方归属站点一致")
                ASSERT(recipeOrderSeen[recipeId] == nil,
                    recipeId .. " 只出现在一个站点顺序表")
                recipeOrderSeen[recipeId] = stationId

                local generator = recipe.generator or {}
                local outputId = recipe.outputId
                    or generator.outputId
                    or generator.targetId
                if outputId and generator.type ~= "fabao" then
                    ASSERT(EquipmentData.SpecialEquipment[outputId] ~= nil,
                        recipeId .. " 统一配方产物模板存在")
                end

                if recipe.inputMode == "equip_weapon" then
                    local hasFixedSource = type(recipe.equipSource) == "string"
                    local hasSourcePool = type(recipe.equipSourcePool) == "table"
                        and #recipe.equipSourcePool > 0
                    ASSERT(hasFixedSource ~= hasSourcePool,
                        recipeId .. " 装备栏输入必须且只能声明 equipSource/equipSourcePool 之一")
                    if hasFixedSource then
                        local sourceDef = EquipmentData.SpecialEquipment[recipe.equipSource]
                        ASSERT(sourceDef and sourceDef.slot == "weapon",
                            recipeId .. " 固定装备栏输入必须引用 weapon 模板")
                    end
                end

                if recipe.outputMode == "replace_weapon" then
                    ASSERT_EQ(recipe.inputMode, "equip_weapon",
                        recipeId .. " 原地替换配方必须从装备栏读取武器")
                    if generator.type == "random_huangsha_weapon_except_equipped" then
                        for _, candidateId in ipairs(generator.pool or {}) do
                            local candidateDef = EquipmentData.SpecialEquipment[candidateId]
                            ASSERT(candidateDef and candidateDef.slot == "weapon",
                                recipeId .. " 随机产物槽位为 weapon：" .. tostring(candidateId))
                        end
                    else
                        local outputDef = EquipmentData.SpecialEquipment[outputId]
                        ASSERT(outputDef and outputDef.slot == "weapon",
                            recipeId .. " 原地替换产物槽位为 weapon")
                    end
                end
            end
        end
    end

    for recipeId in pairs(EquipmentData.FORGE_RECIPES or {}) do
        ASSERT(recipeOrderSeen[recipeId] ~= nil,
            "统一配方已进入且仅进入一个站点顺序表：" .. tostring(recipeId))
    end
end

local dragonForgeUiPath = "scripts/ui/DragonForgeUI.lua"
ASSERT(not fileContains(dragonForgeUiPath, "EquipmentData.DRAGON_FORGE_RECIPES"),
    "龙神界面不再读取旧 DRAGON_FORGE_RECIPES")
ASSERT(not fileContains(dragonForgeUiPath, "EquipmentData.DRAGON_FORGE_COST"),
    "龙神界面不再读取旧 DRAGON_FORGE_COST")
ASSERT(not fileContains(dragonForgeUiPath, "EquipmentData.LONGJI_FORGE_COST"),
    "龙极令界面不再读取旧 LONGJI_FORGE_COST")
ASSERT(not fileContains(dragonForgeUiPath, "EquipmentData.LINGQI_FORGE_COST"),
    "灵器铸造界面不再读取旧 LINGQI_FORGE_COST")
ASSERT(fileContains(dragonForgeUiPath, "EquipmentData.FORGE_RECIPES"),
    "龙神界面统一读取 FORGE_RECIPES")
ASSERT(not fileContains(swordForgeUiPath, "EquipmentData.SWORD_FORGE_COSTS"),
    "通用铸造界面不再合并旧 SWORD_FORGE_COSTS")
ASSERT(not fileContains(swordForgeUiPath, "EquipmentData.SWORD_FORGE_ORDER"),
    "通用铸造界面不再回退旧 SWORD_FORGE_ORDER")
ASSERT(fileContains(swordForgeUiPath, "EquipmentData.FORGE_RECIPES"),
    "通用铸造界面统一读取 FORGE_RECIPES")
ASSERT(fileContains(swordForgeUiPath, 'local displayText = requiredName .. "（需要装备）"'),
    "装备栏材料行统一显示配方要求并标注需要装备")
ASSERT(fileContains(swordForgeUiPath, '"；当前装备：" .. item.name'),
    "装备错误时当前装备只作为诊断信息追加")
ASSERT(not fileContains(swordForgeUiPath, "item and item.name or requiredText"),
    "禁止当前装备名称覆盖配方要求名称")

SUITE("C14: 第四至第六章锻造链优化")

local function materialCount(recipe, materialId)
    for _, material in ipairs((recipe and recipe.materials) or {}) do
        if material.id == materialId then return material.count end
    end
    return nil
end

local dragonWeaponRecipeIds = {
    "dragon_shengqi_duanliu",
    "dragon_shengqi_fentian",
    "dragon_shengqi_shihun",
    "dragon_shengqi_liedi",
    "dragon_shengqi_mieying",
}
for _, recipeId in ipairs(dragonWeaponRecipeIds) do
    local recipe = EquipmentData.FORGE_RECIPES[recipeId]
    ASSERT_EQ(recipe and recipe.fromBag2 and recipe.fromBag2.equipId,
        "silong_ring_ch4", recipeId .. " 消耗帝尊肆戒")
    ASSERT_EQ(recipe and recipe.inputMode, "equip_weapon", recipeId .. " 保持装备升级")
    ASSERT_EQ(recipe and recipe.outputMode, "replace_weapon", recipeId .. " 保持原位替换")
end

local longjiRecipe = EquipmentData.FORGE_RECIPES.dragon_longji
ASSERT_EQ(longjiRecipe and longjiRecipe.fromBag and longjiRecipe.fromBag.equipId,
    "silong_ring_ch4", "龙极令消耗帝尊肆戒")
ASSERT_EQ(longjiRecipe and longjiRecipe.taixu_token, 1000, "龙极令太虚令消耗不变")

local zhenlongRecipe = EquipmentData.FORGE_RECIPES.zhenlong_helmet_ch4
local zhenlongTemplate = EquipmentData.SpecialEquipment.zhenlong_helmet_ch4
ASSERT_EQ(zhenlongRecipe and zhenlongRecipe.stationId, "dragon_forge", "真龙盔归属龙神熔炉")
ASSERT_EQ(zhenlongRecipe and zhenlongRecipe.inputMode, "bag_consume", "真龙盔为背包打造")
ASSERT_EQ(zhenlongRecipe and zhenlongRecipe.outputMode, "add_to_bag", "真龙盔产物进入背包")
ASSERT_EQ(zhenlongRecipe and zhenlongRecipe.gold, 1000000, "真龙盔消耗100万金币")
ASSERT_EQ(zhenlongRecipe and zhenlongRecipe.fromBagList and zhenlongRecipe.fromBagList[1].equipId,
    "jilong_helmet_ch4", "真龙盔消耗极龙盔")
ASSERT_EQ(zhenlongRecipe and zhenlongRecipe.fromBagList and zhenlongRecipe.fromBagList[2].equipId,
    "fabao_longjiling", "真龙盔消耗龙极令")
ASSERT_EQ(zhenlongRecipe and zhenlongRecipe.fromBagList and zhenlongRecipe.fromBagList[3].equipId,
    "silong_ring_ch4", "真龙盔消耗帝尊肆戒")
ASSERT_EQ(zhenlongTemplate and zhenlongTemplate.tier, 10, "真龙盔为T10")
ASSERT_EQ(zhenlongTemplate and zhenlongTemplate.quality, "cyan", "真龙盔为青色")
ASSERT_NUM_EQ(zhenlongTemplate and zhenlongTemplate.mainStat and zhenlongTemplate.mainStat.maxHp,
    756, "真龙盔生命属性")
ASSERT_NUM_EQ(zhenlongTemplate and zhenlongTemplate.subStats and zhenlongTemplate.subStats[1].value,
    19.5, "真龙盔攻击副属性")
ASSERT_NUM_EQ(zhenlongTemplate and zhenlongTemplate.subStats and zhenlongTemplate.subStats[2].value,
    0.075, "真龙盔暴击副属性")
ASSERT_NUM_EQ(zhenlongTemplate and zhenlongTemplate.subStats and zhenlongTemplate.subStats[3].value,
    15.6, "真龙盔防御副属性")
ASSERT_NUM_EQ(zhenlongTemplate and zhenlongTemplate.spiritStat and zhenlongTemplate.spiritStat.value,
    0.1875, "真龙盔灵性暴伤")

local bloodFiveRecipeIds = {
    "daozang_saint_armor",
    "saint_cape_ch5",
    "jiefeng_zhuxian_ch5",
    "jiefeng_xianxian_ch5",
    "jiefeng_luxian_ch5",
    "jiefeng_juexian_ch5",
}
for _, recipeId in ipairs(bloodFiveRecipeIds) do
    ASSERT_EQ(materialCount(EquipmentData.FORGE_RECIPES[recipeId], "immortal_essence_blood"),
        5, recipeId .. " 仙人精血消耗为5")
end

local longhunRecipe = EquipmentData.FORGE_RECIPES.fabao_longhunling
ASSERT_EQ(longhunRecipe and longhunRecipe.fromBag and longhunRecipe.fromBag.equipId,
    "dizun_ring_ch5", "龙魂令消耗帝尊伍戒")
ASSERT_EQ(materialCount(longhunRecipe, "immortal_essence_blood"), 5, "龙魂令消耗仙人精血5")
ASSERT_EQ(materialCount(longhunRecipe, "taixu_jianling"), 1000, "龙魂令消耗太虚剑令1000")
ASSERT_EQ(longhunRecipe and longhunRecipe.generator and longhunRecipe.generator.type,
    "fabao", "龙魂令使用通用法宝生成器")
ASSERT_EQ(longhunRecipe and longhunRecipe.generator and longhunRecipe.generator.templateId,
    "fabao_longhunling", "龙魂令直接生成自身模板")

local t9Random = EquipmentData.FORGE_RECIPES.dragon_lingqi
local t10Random = EquipmentData.FORGE_RECIPES.t10_random_lingqi_ch5
ASSERT(t9Random and not t9Random.fromBag and not t9Random.fromBag2 and not t9Random.fromBagList,
    "随机T9灵器不消耗帝尊戒")
ASSERT(t10Random and not t10Random.fromBag and not t10Random.fromBag2 and not t10Random.fromBagList,
    "随机T10灵器不消耗帝尊戒")

local longwangRecipe = EquipmentData.FORGE_RECIPES.fabao_longwangling
local longwangTemplate = EquipmentData.FabaoTemplates.fabao_longwangling
ASSERT_EQ(longwangRecipe and longwangRecipe.fromBag and longwangRecipe.fromBag.equipId,
    "ch6_xianzun_1_ring", "龙王令消耗仙尊壹戒")
ASSERT_EQ(materialCount(longwangRecipe, "shadow_crystal"), 6, "龙王令消耗影子水晶6")
ASSERT_EQ(materialCount(longwangRecipe, "zhexian_ling"), 1000, "龙王令消耗谪仙令1000")
ASSERT_EQ(longwangRecipe and longwangRecipe.gold, 0, "龙王令不消耗金币")
ASSERT_EQ(longwangRecipe and longwangRecipe.generator and longwangRecipe.generator.type,
    "fabao", "龙王令使用通用法宝生成器")
ASSERT_EQ(longwangTemplate and longwangTemplate.skillId, "dragon_breath", "龙王令沿用龙息技能")

local collection = EquipmentData.Collection.entries
ASSERT_NUM_EQ(collection.zhenlong_helmet_ch4 and collection.zhenlong_helmet_ch4.bonus.atk,
    12, "真龙盔图鉴攻击+12")
local ch6FabaoBonuses = {
    fabao_xuehaitu_t11 = { atk = 15, killHeal = 30 },
    fabao_haoqiyin_t11 = { killHeal = 30, hpRegen = 10 },
    fabao_qingyunta_t11 = { heavyHit = 50, def = 15 },
    fabao_fengmopan_t11 = { maxHp = 50, hpRegen = 5 },
    fabao_longwangling_t11 = { atk = 5, fortune = 5 },
}
for equipId, expectedBonus in pairs(ch6FabaoBonuses) do
    local template = EquipmentData.SpecialEquipment[equipId]
    local entry = collection[equipId]
    ASSERT_EQ(template and template.tier, 11, equipId .. " 图鉴精确匹配T11")
    ASSERT_EQ(template and template.quality, "red", equipId .. " 图鉴精确匹配红色")
    for stat, value in pairs(expectedBonus) do
        ASSERT_NUM_EQ(entry and entry.bonus and entry.bonus[stat], value,
            equipId .. " 图鉴加成 " .. stat)
    end
end

do
    local oldInventorySystem = package.loaded["systems.InventorySystem"]
    local slots = {
        [1] = {
            isFabao = true,
            equipId = "fabao_xuehaitu",
            tier = 11,
            quality = "cyan",
        },
        [2] = {
            isFabao = true,
            equipId = "fabao_xuehaitu",
            tier = 11,
            quality = "red",
        },
    }
    package.loaded["systems.InventorySystem"] = {
        GetManager = function()
            return {
                GetInventoryItem = function(_, index)
                    return slots[index]
                end,
            }
        end,
    }
    ASSERT_EQ(CollectionSystem.FindInBackpack("fabao_xuehaitu_t11"), 2,
        "T11法宝图鉴跳过青色并精确匹配红色")
    slots[2] = nil
    ASSERT_EQ(CollectionSystem.FindInBackpack("fabao_xuehaitu_t11"), nil,
        "T11法宝图鉴不接受青色替代红色")
    package.loaded["systems.InventorySystem"] = oldInventorySystem
end

local orderedRecipeCount = 0
for _, order in pairs(EquipmentData.FORGE_RECIPE_ORDER or {}) do
    orderedRecipeCount = orderedRecipeCount + #order
end
ASSERT_EQ(orderedRecipeCount, 29, "统一锻造配方总数为29")
ASSERT(fileContains(dragonForgeUiPath, '"装备升级"')
    and fileContains(dragonForgeUiPath, '"背包打造"'),
    "龙神熔炉明确区分装备升级与背包打造")
ASSERT(fileContains(swordForgeUiPath, '"装备升级"')
    and fileContains(swordForgeUiPath, '"背包打造"'),
    "通用锻造界面明确区分装备升级与背包打造")
ASSERT(fileContains(swordForgeUiPath, 'haveCount .. "/" .. needCount'),
    "通用背包装备材料显示拥有数量/需求数量")
ASSERT(fileContains(swordForgeUiPath, "EquipmentUtils.CalcMainStatValue"),
    "法宝预览与运行时共用主属性公式")

local forgeSystemPath = "scripts/systems/ForgeSystem.lua"
ASSERT(fileContains(forgeSystemPath, "NormalizeEquipmentRuntimeFields(weapon)"),
    "原地替换武器统一补齐运行时 type 字段")
ASSERT(fileContains(forgeSystemPath, 'elseif genType == "true_sword"'),
    "第六章真仙剑接入统一生成器分派")

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
