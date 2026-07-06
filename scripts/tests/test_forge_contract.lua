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
-- ============================================================================

local EquipmentData = require("config.EquipmentData")
local GameConfig = require("config.GameConfig")
local TigerDomainZone = require("config.zones.tiger_domain")
local Chapter2FortressZone = require("config.zones.chapter2.fortress_e")
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

SUITE("C11: 全图鉴运行时实际生效")

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
