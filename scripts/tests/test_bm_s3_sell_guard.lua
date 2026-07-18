-- ============================================================================
-- test_bm_s3_sell_guard.lua — BM-S3 + BM-S3R 黑市卖出服务端权威校验测试
--
-- BM-S3R 收口：所有商品统一 high_risk_blocked，安全类 = 0
--
-- 测试层次：
--   A. 分类层：SellGuard 对各分类/商品 ID 的判定是否正确
--   B. 覆盖率：总数校验
--   C. 回归层：自动回收路径不受影响
--
-- 纯 Lua 测试，通过 stub 替代引擎依赖。
-- ============================================================================

local passed = 0
local failed = 0
local total  = 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        print("  ✗ " .. name .. ": " .. tostring(err))
    end
end

local function assertEqual(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a))
    end
end

local function assertTrue(v, msg)
    if not v then error(msg or "expected true") end
end

local function assertFalse(v, msg)
    if v then error(msg or "expected false") end
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then error("cannot read file: " .. path) end
    local content = f:read("*a") or ""
    f:close()
    return content
end

local function assertContains(text, needle, msg)
    if not text:find(needle, 1, true) then
        error((msg or "expected text") .. ": " .. needle)
    end
end

local function assertNotContains(text, needle, msg)
    if text:find(needle, 1, true) then
        error((msg or "unexpected text") .. ": " .. needle)
    end
end

print("\n[test_bm_s3_sell_guard] === BM-S3R 黑市卖出服务端权威校验测试 ===\n")

-- ============================================================================
-- Stubs
-- ============================================================================

local _stubModules = {
    "config.BlackMerchantConfig",
    "config.GameConfig",
    "config.PillRecipes",
    "config.EquipmentData",
    "config.PetSkillData",
    "network.BlackMarketSellGuard",
    "systems.AudioSystem",
    "cjson",
}
local _origPackageLoaded = {}
for _, k in ipairs(_stubModules) do
    _origPackageLoaded[k] = package.loaded[k]
end

-- 清除缓存以确保加载最新版本
for _, k in ipairs(_stubModules) do
    package.loaded[k] = nil
end

package.loaded["cjson"] = {
    encode = function() return "{}" end,
    decode = function() return {} end,
}

local BMConfig = require("config.BlackMerchantConfig")
local PillRecipes = require("config.PillRecipes")
local SellGuard = require("network.BlackMarketSellGuard")
local AudioSystem = require("systems.AudioSystem")

-- ============================================================================
-- A. 分类层测试 — BM-S3R: 所有商品均应被拒卖
-- ============================================================================

print("  --- 分类层 (BM-S3R: 全部拒卖) ---")

test("T1: rake 碎片 → 拒卖 (伪安全: ArtifactSystem.lua:242 ConsumeConsumable)", function()
    local rakeIds = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_RAKE)
    assertTrue(#rakeIds > 0, "should have rake items")
    for _, id in ipairs(rakeIds) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "rake should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T2: bagua 碎片 → 拒卖 (伪安全: ArtifactSystem_ch4.lua:212 ConsumeConsumable)", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_BAGUA)
    assertTrue(#ids > 0, "should have bagua items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "bagua should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T3: tiandi 碎片 → 拒卖 (伪安全: ArtifactSystem_tiandi.lua:123 ConsumeConsumable)", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_TIANDI)
    assertTrue(#ids > 0, "should have tiandi items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "tiandi should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T4: dragon_scale_ice → 拒卖 (伪安全: DragonForgeUI.lua:1112 ConsumeConsumable)", function()
    local allowed, reason = SellGuard.CheckSellAllowed("dragon_scale_ice")
    assertFalse(allowed, "dragon_scale_ice should be blocked")
    assertEqual(reason, "high_risk_blocked", "reason")
end)

test("T5: wubao_token_box → 拒卖 (伪安全: InventorySystem.lua:997 _UseTokenBox)", function()
    local allowed, reason = SellGuard.CheckSellAllowed("wubao_token_box")
    assertFalse(allowed, "wubao_token_box should be blocked")
    assertEqual(reason, "high_risk_blocked", "reason")
end)

test("T6: gold_brick → 拒卖", function()
    local allowed, reason = SellGuard.CheckSellAllowed("gold_brick")
    assertFalse(allowed, "gold_brick should be blocked")
    assertEqual(reason, "high_risk_blocked", "reason")
end)

test("T7: lingyu → 拒卖", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_LINGYU)
    assertTrue(#ids > 0, "should have lingyu items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "lingyu should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T8: herb → 拒卖", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_HERB)
    assertTrue(#ids > 0, "should have herb items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "herb should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T9: 三档 skill_book → 拒卖", function()
    local categories = {
        BMConfig.CATEGORY_SKILL_BOOK_MID,
        BMConfig.CATEGORY_SKILL_BOOK_HIGH,
        BMConfig.CATEGORY_SKILL_BOOK_SPECIAL,
    }
    for _, category in ipairs(categories) do
        local ids = BMConfig.GetItemsByCategory(category)
        assertTrue(#ids > 0, "should have " .. category .. " items")
        for _, id in ipairs(ids) do
            local allowed, reason = SellGuard.CheckSellAllowed(id)
            assertFalse(allowed, "skill_book should be blocked: " .. id)
            assertEqual(reason, "high_risk_blocked", "reason for " .. id)
        end
    end
end)

test("T10: special_equip → 拒卖", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_SPECIAL_EQUIP)
    assertTrue(#ids > 0, "should have special_equip items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "special_equip should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T11: 未知商品 → 拒绝(unknown_item)", function()
    local allowed, reason = SellGuard.CheckSellAllowed("totally_fake_item_9999")
    assertFalse(allowed, "unknown item should be blocked")
    assertEqual(reason, "unknown_item", "reason should be unknown_item")
end)

test("T12: 全部 dragon_scale 变体 → 拒卖", function()
    local variants = { "dragon_scale_ice", "dragon_scale_abyss", "dragon_scale_fire", "dragon_scale_sand" }
    for _, id in ipairs(variants) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, id .. " should be blocked")
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T13: 全部 token_box 变体 → 拒卖", function()
    local boxes = { "wubao_token_box", "sha_hai_ling_box", "taixu_token_box", "taixu_jianling_box", "zhexian_ling_box" }
    for _, id in ipairs(boxes) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, id .. " should be blocked")
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

-- ============================================================================
-- B. 覆盖率测试 — BM-S3R: 0 安全 + 全部高风险
-- ============================================================================

print("  --- 覆盖率 (BM-S3R) ---")

test("T14: 安全类总数 = 0", function()
    local safeIds = SellGuard.GetSafeItemIds()
    assertEqual(#safeIds, 0, "safe item count")
end)

test("T15: 高风险类覆盖全部商品", function()
    local highRiskIds = SellGuard.GetHighRiskItemIds()
    assertEqual(#highRiskIds, #BMConfig.ITEM_IDS, "high-risk item count")
end)

test("T16: 安全+高风险覆盖全部商品", function()
    local safeIds = SellGuard.GetSafeItemIds()
    local highRiskIds = SellGuard.GetHighRiskItemIds()
    local totalItems = #safeIds + #highRiskIds
    assertEqual(totalItems, #BMConfig.ITEM_IDS, "total should match ITEM_IDS count")
end)

test("T17: 默认保守 — 模拟未来新分类自动拒绝", function()
    local fakeId = "__test_future_category_item__"
    BMConfig.ITEMS[fakeId] = {
        name = "测试未来商品",
        buy_price = 1,
        sell_price = 2,
        category = "future_category_2030",
    }
    local allowed, reason = SellGuard.CheckSellAllowed(fakeId)
    assertFalse(allowed, "future category should be blocked by default")
    assertEqual(reason, "high_risk_blocked", "reason")
    BMConfig.ITEMS[fakeId] = nil
end)

test("T18: GetSafeItemIds() 返回空列表", function()
    local safeIds = SellGuard.GetSafeItemIds()
    assertEqual(#safeIds, 0, "safe list should be empty")
end)

test("T19: GetHighRiskItemIds() 返回列表全部为 blocked", function()
    local highRiskIds = SellGuard.GetHighRiskItemIds()
    assertEqual(#highRiskIds, #BMConfig.ITEM_IDS, "should cover all items")
    for _, id in ipairs(highRiskIds) do
        local allowed = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "high-risk item should be blocked: " .. id)
    end
end)

test("T20: 第六章黑市新增材料配置正确", function()
    local grass = BMConfig.ITEMS.night_shadow_grass
    assertTrue(grass ~= nil, "night_shadow_grass should be in black market")
    assertEqual(grass.category, BMConfig.CATEGORY_HERB, "night_shadow_grass category")
    assertEqual(grass.buy_price, 10, "night_shadow_grass buy_price")
    assertEqual(grass.sell_price, 20, "night_shadow_grass sell_price")
    assertEqual(grass.max_stock, 10, "night_shadow_grass max_stock")

    local crystal = BMConfig.ITEMS.shadow_crystal
    assertTrue(crystal ~= nil, "shadow_crystal should be in black market")
    assertEqual(crystal.category, BMConfig.CATEGORY_MATERIAL, "shadow_crystal category")
    assertEqual(crystal.buy_price, 20, "shadow_crystal buy_price")
    assertEqual(crystal.sell_price, 40, "shadow_crystal sell_price")
    assertEqual(crystal.max_stock, 5, "shadow_crystal max_stock")

    local xianzunRing = BMConfig.ITEMS.ch6_xianzun_1_ring
    assertTrue(xianzunRing ~= nil, "ch6_xianzun_1_ring should be in black market")
    assertEqual(xianzunRing.name, "仙尊壹戒", "ch6_xianzun_1_ring name")
    assertEqual(xianzunRing.category, BMConfig.CATEGORY_SPECIAL_EQUIP, "ch6_xianzun_1_ring category")
    assertEqual(xianzunRing.itemType, "equipment", "ch6_xianzun_1_ring itemType")
    assertEqual(xianzunRing.equipId, "ch6_xianzun_1_ring", "ch6_xianzun_1_ring equipId")
    assertEqual(xianzunRing.buy_price, 20, "ch6_xianzun_1_ring buy_price")
    assertEqual(xianzunRing.sell_price, 40, "ch6_xianzun_1_ring sell_price")
end)

test("T20.1: 令牌盒黑市配置一致且仅第六章提价", function()
    local expected = {
        { id = "wubao_token_box",    name = "乌堡令盒",   buy = 2, sell = 4, sort = 4 },
        { id = "sha_hai_ling_box",   name = "沙海令盒",   buy = 2, sell = 4, sort = 5 },
        { id = "taixu_token_box",    name = "太虚令盒",   buy = 2, sell = 4, sort = 6 },
        { id = "taixu_jianling_box", name = "太虚剑令盒", buy = 2, sell = 4, sort = 7 },
        { id = "zhexian_ling_box",   name = "谪仙令盒",   buy = 3, sell = 6, sort = 8 },
    }
    for _, e in ipairs(expected) do
        local item = BMConfig.ITEMS[e.id]
        assertTrue(item ~= nil, e.id .. " should be in black market")
        assertEqual(item.name, e.name, e.id .. " name")
        assertEqual(item.category, BMConfig.CATEGORY_CONSUMABLE, e.id .. " category")
        assertEqual(item.buy_price, e.buy, e.id .. " buy_price")
        assertEqual(item.sell_price, e.sell, e.id .. " sell_price")
        assertEqual(item.max_stock, 10, e.id .. " max_stock")
        assertEqual(item.sort_order, e.sort, e.id .. " sort_order")
    end
end)

test("T20.3: 消耗品与材料页签商品拆分精确", function()
    local expectedConsumables = {
        "valentine_red_thread",
        "valentine_pair_jade",
        "valentine_xiangsi_redbean_cake",
        "xianjie_premium_zong",
        "treasure_map",
        "wubao_treasure_key",
        "gold_brick",
        "wubao_token_box",
        "sha_hai_ling_box",
        "taixu_token_box",
        "taixu_jianling_box",
        "zhexian_ling_box",
    }
    local expectedMaterials = {
        "dragon_scale_ice",
        "dragon_scale_abyss",
        "dragon_scale_fire",
        "dragon_scale_sand",
        "immortal_essence_blood",
        "shadow_crystal",
        "lotus_pool_dew",
    }

    local consumables = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_CONSUMABLE)
    local materials = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_MATERIAL)
    assertEqual(#consumables, #expectedConsumables, "consumable count")
    assertEqual(#materials, #expectedMaterials, "material count")
    for i, id in ipairs(expectedConsumables) do
        assertEqual(consumables[i], id, "consumable order " .. i)
    end
    for i, id in ipairs(expectedMaterials) do
        assertEqual(materials[i], id, "material order " .. i)
    end
end)

test("T20.4: 记录与皮肤同级，记录不再占商品分类页签", function()
    local src = readFile("scripts/ui/BlackMerchantUI.lua")
    local toolbarStart = src:find("-- 仙石行：余额 + 记录/皮肤 + 兑换按钮", 1, true)
    local tabRowsStart = src:find("-- 标签页栏（三行）", toolbarStart or 1, true)
    assertTrue(toolbarStart ~= nil and tabRowsStart ~= nil, "toolbar markers should exist")

    local toolbar = src:sub(toolbarStart, tabRowsStart - 1)
    assertContains(toolbar, "tabBtnHistory_,", "history should be in toolbar")
    assertContains(toolbar, 'text = "皮肤"', "skin should be in toolbar")

    local firstRowStart = src:find("-- 第一行：消耗品 · 材料 · 草药 · 附灵玉 · 特殊装备", tabRowsStart, true)
    local secondRowStart = src:find("-- 第二行：技能书", firstRowStart or tabRowsStart, true)
    assertTrue(firstRowStart ~= nil and secondRowStart ~= nil, "category row markers should exist")

    local firstRow = src:sub(firstRowStart, secondRowStart - 1)
    assertContains(firstRow, "tabBtnConsumable_", "consumable tab should be first-row category")
    assertContains(firstRow, "tabBtnMaterial_", "material tab should be first-row category")
    assertNotContains(firstRow, "tabBtnHistory_", "history should not remain in category row")
end)

test("T20.5: 消耗品与材料掉落提示音映射正确", function()
    local consumables = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_CONSUMABLE)
    local materials = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_MATERIAL)

    for _, id in ipairs(consumables) do
        local cue = AudioSystem.ResolveConsumableDropCue(id)
        if not cue then error("consumable cue missing: " .. id) end
        assertEqual(cue.path, "audio/ggS.ogg", "consumable cue path: " .. id)
        assertEqual(cue.priority, 3, "consumable cue priority: " .. id)
    end

    for _, id in ipairs(materials) do
        local cue = AudioSystem.ResolveConsumableDropCue(id)
        if not cue then error("material cue missing: " .. id) end
        assertEqual(cue.path, "audio/财源滚滚.ogg", "material cue path: " .. id)
        assertEqual(cue.priority, 2, "material cue priority: " .. id)
    end
end)

test("T20.6: 单批取最高优先级，跨批后触发音效覆盖前一批", function()
    local consumableCue = AudioSystem.ResolveConsumableDropCue("treasure_map")
    local materialCue = AudioSystem.ResolveConsumableDropCue("dragon_scale_ice")

    assertEqual(
        AudioSystem.SelectHigherPriorityDropCue(materialCue, consumableCue),
        consumableCue,
        "consumable should win within one drop"
    )
    assertEqual(
        AudioSystem.SelectHigherPriorityDropCue(consumableCue, materialCue),
        consumableCue,
        "iteration order should not change the winning cue"
    )

    local originalScene = Scene
    local originalCache = cache
    local originalFileSystem = fileSystem
    local playedPaths = {}

    Scene = function()
        return {
            CreateChild = function(_, nodeName)
                return {
                    CreateComponent = function()
                        local source = {
                            playing = false,
                            SetSoundType = function() end,
                            IsPlaying = function(self) return self.playing end,
                            Stop = function(self) self.playing = false end,
                            Play = function(self, sound)
                                self.playing = true
                                if nodeName == "DropCue" then
                                    playedPaths[#playedPaths + 1] = sound.path
                                end
                            end,
                        }
                        return source
                    end,
                }
            end,
        }
    end
    cache = {
        GetResource = function(_, resourceType, path)
            assertEqual(resourceType, "Sound", "resource type")
            return { path = path, looped = false }
        end,
    }
    fileSystem = nil

    local ok, err = pcall(function()
        AudioSystem.Init()
        AudioSystem.PlayResolvedDropCue(consumableCue)
        AudioSystem.PlayResolvedDropCue(materialCue)
    end)

    Scene = originalScene
    cache = originalCache
    fileSystem = originalFileSystem
    if not ok then error(err) end

    assertEqual(#playedPaths, 2, "both pickup batches should reach SoundSource:Play")
    assertEqual(playedPaths[1], "audio/ggS.ogg", "first batch should play 恭喜发财")
    assertEqual(playedPaths[2], "audio/财源滚滚.ogg", "second batch should override with 财源滚滚")
end)

test("T20.7: 玩家与宠物拾取都按批汇总后只播放一次", function()
    local src = readFile("scripts/systems/loot/pickup.lua")
    local _, playCount = src:gsub("AudioSystem.PlayResolvedDropCue%(dropCue%)", "")
    assertEqual(playCount, 2, "player and pet pickup should each have one settled playback point")
    assertNotContains(src, "AudioSystem.CheckAndPlayForConsumable(cId)", "pickup should not play per consumable")
    assertNotContains(src, "AudioSystem.CheckAndPlayForItem(item)", "pickup should not play per equipment")
end)

test("T20.2: 令牌盒打包费用仅第六章提高到200", function()
    local expected = {
        { token = "wubao_token",    box = "wubao_token_box",    cost = 100 },
        { token = "sha_hai_ling",   box = "sha_hai_ling_box",   cost = 100 },
        { token = "taixu_token",    box = "taixu_token_box",    cost = 100 },
        { token = "taixu_jianling", box = "taixu_jianling_box", cost = 100 },
        { token = "zhexian_ling",   box = "zhexian_ling_box",   cost = 200 },
    }
    for _, e in ipairs(expected) do
        assertEqual(PillRecipes.GetTokenBoxLingYunCost(e.token, e.box), e.cost, e.box .. " lingYunCost")
    end
end)

-- ============================================================================
-- C. 回归层 — 自动回收路径不受影响
-- ============================================================================

print("  --- 回归层 ---")

test("T21: SellGuard 不导出任何被自动回收路径引用的接口", function()
    -- SellGuard 仅导出: CheckSellAllowed, GetSafeItemIds, GetHighRiskItemIds
    -- HandleSell 调用链: C2S_BMSell → HandleSell() → SellGuard.CheckSellAllowed()
    -- RecycleTick 调用链: ScheduledUpdate → RecycleTick() → ExecuteRecycle() → MoneyCost()
    -- 两条路径完全独立

    -- 验证 SellGuard 只有预期的公共接口
    assertEqual(type(SellGuard.CheckSellAllowed), "function", "CheckSellAllowed exists")
    assertEqual(type(SellGuard.GetSafeItemIds), "function", "GetSafeItemIds exists")
    assertEqual(type(SellGuard.GetHighRiskItemIds), "function", "GetHighRiskItemIds exists")

    -- 验证没有被自动回收路径引用的接口
    assertEqual(SellGuard.OnRecycle, nil, "no OnRecycle interface")
    assertEqual(SellGuard.HandleRecycle, nil, "no HandleRecycle interface")
    assertEqual(SellGuard.RecycleTick, nil, "no RecycleTick interface")
    assertEqual(SellGuard.ExecuteRecycle, nil, "no ExecuteRecycle interface")
end)

-- ============================================================================
-- 汇总
-- ============================================================================

print("\n[test_bm_s3_sell_guard] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

-- ============================================================================
-- Cleanup: 恢复 package.loaded
-- ============================================================================
for _, k in ipairs(_stubModules) do
    package.loaded[k] = _origPackageLoaded[k]
end

return { passed = passed, failed = failed, total = total }
