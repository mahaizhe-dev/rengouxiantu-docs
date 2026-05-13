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

print("\n[test_bm_s3_sell_guard] === BM-S3R 黑市卖出服务端权威校验测试 ===\n")

-- ============================================================================
-- Stubs
-- ============================================================================

local _stubModules = {
    "config.BlackMerchantConfig",
    "config.GameConfig",
    "config.EquipmentData",
    "config.PetSkillData",
    "network.BlackMarketSellGuard",
}
local _origPackageLoaded = {}
for _, k in ipairs(_stubModules) do
    _origPackageLoaded[k] = package.loaded[k]
end

-- 清除缓存以确保加载最新版本
for _, k in ipairs(_stubModules) do
    package.loaded[k] = nil
end

local BMConfig = require("config.BlackMerchantConfig")
local SellGuard = require("network.BlackMarketSellGuard")

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

test("T9: skill_book → 拒卖", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_SKILL_BOOK)
    assertTrue(#ids > 0, "should have skill_book items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "skill_book should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
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
    local boxes = { "wubao_token_box", "sha_hai_ling_box", "taixu_token_box" }
    for _, id in ipairs(boxes) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, id .. " should be blocked")
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

-- ============================================================================
-- B. 覆盖率测试 — BM-S3R: 0 安全 + 79 高风险
-- ============================================================================

print("  --- 覆盖率 (BM-S3R) ---")

test("T14: 安全类总数 = 0", function()
    local safeIds = SellGuard.GetSafeItemIds()
    assertEqual(#safeIds, 0, "safe item count")
end)

test("T15: 高风险类总数 = 79", function()
    local highRiskIds = SellGuard.GetHighRiskItemIds()
    assertEqual(#highRiskIds, 79, "high-risk item count")
end)

test("T16: 安全+高风险 = 79 (覆盖全部商品)", function()
    local safeIds = SellGuard.GetSafeItemIds()
    local highRiskIds = SellGuard.GetHighRiskItemIds()
    local totalItems = #safeIds + #highRiskIds
    assertEqual(totalItems, #BMConfig.ITEM_IDS, "total should match ITEM_IDS count")
    assertEqual(totalItems, 79, "total should be 79")
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
    assertEqual(#highRiskIds, 79, "should have 79 items")
    for _, id in ipairs(highRiskIds) do
        local allowed = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "high-risk item should be blocked: " .. id)
    end
end)

-- ============================================================================
-- C. 回归层 — 自动回收路径不受影响
-- ============================================================================

print("  --- 回归层 ---")

test("T20: SellGuard 不导出任何被自动回收路径引用的接口", function()
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
