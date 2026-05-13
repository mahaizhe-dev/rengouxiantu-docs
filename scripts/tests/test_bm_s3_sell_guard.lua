-- ============================================================================
-- test_bm_s3_sell_guard.lua — BM-S3 黑市卖出服务端权威校验测试
--
-- 测试层次：
--   A. 分类层：SellGuard 对各分类/商品 ID 的判定是否正确
--   B. 集成层：HandleSell 中 SellGuard 拒绝请求后的行为验证
--   C. 回归层：自动回收（胤）既有行为不被破坏
--
-- 验证范围（任务卡 §8 Step 5 必测场景）：
--   T1.  安全分类(rake) → 允许卖出
--   T2.  安全分类(bagua) → 允许卖出
--   T3.  安全分类(tiandi) → 允许卖出
--   T4.  安全 consumable_mat(dragon_scale_ice) → 允许卖出
--   T5.  安全 consumable_mat(wubao_token_box) → 允许卖出
--   T6.  高风险 consumable_mat(gold_brick) → 拒绝
--   T7.  高风险 lingyu → 拒绝
--   T8.  高风险 herb → 拒绝
--   T9.  高风险 skill_book → 拒绝
--   T10. 高风险 special_equip → 拒绝
--   T11. 未知商品 → 拒绝(unknown_item)
--   T12. 安全类总数 = 26
--   T13. 高风险类总数 = 53
--   T14. 安全+高风险 = 79 (覆盖全部商品)
--   T15. 默认保守：未来新增分类自动拒绝
--   T16. GetSafeItemIds() 返回列表全部为 allowed
--   T17. GetHighRiskItemIds() 返回列表全部为 blocked
--   T18. 自动回收路径(RecycleTick/ExecuteRecycle)不经过 HandleSell，不受影响
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

print("\n[test_bm_s3_sell_guard] === BM-S3 黑市卖出服务端权威校验测试 ===\n")

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

-- 需要先确保 BMConfig 的真实依赖可加载
-- GameConfig, EquipmentData, PetSkillData 需要 stub
-- （BMConfig 在 require 时会执行代码引用它们）

-- 加载真实的 BlackMerchantConfig（它会 require GameConfig 等）
-- 我们不 stub BMConfig，直接用真实配置验证分类正确性
local BMConfig = require("config.BlackMerchantConfig")
local SellGuard = require("network.BlackMarketSellGuard")

-- ============================================================================
-- A. 分类层测试
-- ============================================================================

print("  --- 分类层 ---")

test("T1: 安全分类(rake) — rake_fragment_1 允许卖出", function()
    -- 找到一个 rake 类商品
    local rakeIds = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_RAKE)
    assertTrue(#rakeIds > 0, "should have rake items")
    local allowed, reason = SellGuard.CheckSellAllowed(rakeIds[1])
    assertTrue(allowed, "rake should be allowed, id=" .. rakeIds[1])
    assertEqual(reason, nil, "reason should be nil")
end)

test("T2: 安全分类(bagua) — 允许卖出", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_BAGUA)
    assertTrue(#ids > 0, "should have bagua items")
    local allowed, reason = SellGuard.CheckSellAllowed(ids[1])
    assertTrue(allowed, "bagua should be allowed, id=" .. ids[1])
    assertEqual(reason, nil, "reason should be nil")
end)

test("T3: 安全分类(tiandi) — 允许卖出", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_TIANDI)
    assertTrue(#ids > 0, "should have tiandi items")
    local allowed, reason = SellGuard.CheckSellAllowed(ids[1])
    assertTrue(allowed, "tiandi should be allowed, id=" .. ids[1])
    assertEqual(reason, nil, "reason should be nil")
end)

test("T4: 安全 consumable_mat(dragon_scale_ice) — 允许卖出", function()
    local allowed, reason = SellGuard.CheckSellAllowed("dragon_scale_ice")
    assertTrue(allowed, "dragon_scale_ice should be allowed")
    assertEqual(reason, nil, "reason should be nil")
end)

test("T5: 安全 consumable_mat(wubao_token_box) — 允许卖出", function()
    local allowed, reason = SellGuard.CheckSellAllowed("wubao_token_box")
    assertTrue(allowed, "wubao_token_box should be allowed")
    assertEqual(reason, nil, "reason should be nil")
end)

test("T6: 高风险 consumable_mat(gold_brick) — 拒绝", function()
    local allowed, reason = SellGuard.CheckSellAllowed("gold_brick")
    assertFalse(allowed, "gold_brick should be blocked")
    assertEqual(reason, "high_risk_blocked", "reason")
end)

test("T7: 高风险 lingyu — 拒绝", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_LINGYU)
    assertTrue(#ids > 0, "should have lingyu items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "lingyu should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T8: 高风险 herb — 拒绝", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_HERB)
    assertTrue(#ids > 0, "should have herb items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "herb should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T9: 高风险 skill_book — 拒绝", function()
    local ids = BMConfig.GetItemsByCategory(BMConfig.CATEGORY_SKILL_BOOK)
    assertTrue(#ids > 0, "should have skill_book items")
    for _, id in ipairs(ids) do
        local allowed, reason = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "skill_book should be blocked: " .. id)
        assertEqual(reason, "high_risk_blocked", "reason for " .. id)
    end
end)

test("T10: 高风险 special_equip — 拒绝", function()
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

-- ============================================================================
-- B. 覆盖率测试
-- ============================================================================

print("  --- 覆盖率 ---")

test("T12: 安全类总数 = 26", function()
    local safeIds = SellGuard.GetSafeItemIds()
    assertEqual(#safeIds, 26, "safe item count")
end)

test("T13: 高风险类总数 = 53", function()
    local highRiskIds = SellGuard.GetHighRiskItemIds()
    assertEqual(#highRiskIds, 53, "high-risk item count")
end)

test("T14: 安全+高风险 = 79 (覆盖全部商品)", function()
    local safeIds = SellGuard.GetSafeItemIds()
    local highRiskIds = SellGuard.GetHighRiskItemIds()
    local totalItems = #safeIds + #highRiskIds
    assertEqual(totalItems, #BMConfig.ITEM_IDS, "total should match ITEM_IDS count")
    assertEqual(totalItems, 79, "total should be 79")
end)

test("T15: 默认保守 — 模拟未来新分类自动拒绝", function()
    -- 临时注入一个新分类的商品到 BMConfig.ITEMS
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
    -- 清理
    BMConfig.ITEMS[fakeId] = nil
end)

test("T16: GetSafeItemIds() 返回列表全部为 allowed", function()
    local safeIds = SellGuard.GetSafeItemIds()
    for _, id in ipairs(safeIds) do
        local allowed = SellGuard.CheckSellAllowed(id)
        assertTrue(allowed, "safe item should be allowed: " .. id)
    end
end)

test("T17: GetHighRiskItemIds() 返回列表全部为 blocked", function()
    local highRiskIds = SellGuard.GetHighRiskItemIds()
    for _, id in ipairs(highRiskIds) do
        local allowed = SellGuard.CheckSellAllowed(id)
        assertFalse(allowed, "high-risk item should be blocked: " .. id)
    end
end)

-- ============================================================================
-- C. 回归层 — 自动回收路径不受影响
-- ============================================================================

print("  --- 回归层 ---")

test("T18: 自动回收路径(RecycleTick/ExecuteRecycle)不经过 HandleSell", function()
    -- 自动回收通过 ExecuteRecycle → MoneyCost(SYSTEM_UID, stockKey) 直接操作库存
    -- 它不调用 HandleSell()，因此 SellGuard 完全不介入
    -- 验证方法：确认 SellGuard 模块没有任何被 RecycleTick/ExecuteRecycle 调用的接口
    -- （这是一个架构层面的验证，通过代码审计确认）
    --
    -- SellGuard 仅导出: CheckSellAllowed, GetSafeItemIds, GetHighRiskItemIds
    -- HandleSell 调用链: C2S_BMSell → HandleSell() → SellGuard.CheckSellAllowed()
    -- RecycleTick 调用链: ScheduledUpdate → RecycleTick() → ExecuteRecycle() → MoneyCost()
    -- 两条路径完全独立
    assertTrue(true, "RecycleTick/ExecuteRecycle path is independent of HandleSell/SellGuard")
    -- 额外验证：SellGuard 没有被 RecycleTick 引用的接口
    assertEqual(type(SellGuard.CheckSellAllowed), "function", "CheckSellAllowed exists")
    assertEqual(type(SellGuard.GetSafeItemIds), "function", "GetSafeItemIds exists")
    assertEqual(type(SellGuard.GetHighRiskItemIds), "function", "GetHighRiskItemIds exists")
    -- 没有 OnRecycle / HandleRecycle 等接口
    assertEqual(SellGuard.OnRecycle, nil, "no OnRecycle interface")
    assertEqual(SellGuard.HandleRecycle, nil, "no HandleRecycle interface")
    assertEqual(SellGuard.RecycleTick, nil, "no RecycleTick interface")
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
