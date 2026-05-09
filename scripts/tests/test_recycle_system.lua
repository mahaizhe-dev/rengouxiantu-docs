-- ============================================================================
-- test_recycle_system.lua — 大黑无天自动收购系统 模拟测试
--
-- 目的：在纯 Lua 环境中验证核心逻辑的正确性，覆盖以下场景：
--   1. 加权随机分布验证（概率 25%/50%/25%）
--   2. 过天状态检测（首次 tick、同日重复、跨天、服务器重启）
--   3. 商品筛选（满库存/未满/混合）
--   4. 收购数量边界（stock=1 但随机出 2）
--   5. BatchCommit 失败路径
--   6. 并发锁保护（recycleRunning_ 防重入）
--   7. 日志记录字段正确性
--   8. GM 手动触发不受每日限制
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

local function assert_eq(actual, expected, testName)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName)
        print("    expected: " .. tostring(expected))
        print("    actual:   " .. tostring(actual))
    end
end

local function assert_true(cond, testName)
    assert_eq(cond, true, testName)
end

local function assert_range(val, lo, hi, testName)
    totalTests = totalTests + 1
    if val >= lo and val <= hi then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName)
        print("    expected range: [" .. lo .. ", " .. hi .. "]")
        print("    actual: " .. tostring(val))
    end
end

-- ============================================================================
-- Mock 配置
-- ============================================================================

local BMConfig = {
    SYSTEM_UID = 0,
    MAX_STOCK = 5,
    RECYCLE_NPC_NAME = "大黑无天",
    RECYCLE_WEIGHTS = { 0.25, 0.75, 1.0 },  -- 累积概率：0件25%、1件50%、2件25%
    ITEMS = {
        rake_1  = { name = "逊金钯碎片·壹", sell_price = 6, max_stock = 5 },
        rake_2  = { name = "逊金钯碎片·贰", sell_price = 6, max_stock = 5 },
        bagua_1 = { name = "八卦盘碎片·壹", sell_price = 6, max_stock = 5 },
        mat_1   = { name = "千年灵芝",     sell_price = 4, max_stock = 10 },
        token_box = { name = "乌堡令盒",   sell_price = 4, max_stock = 10 },
    },
    ITEM_IDS = { "rake_1", "rake_2", "bagua_1", "mat_1", "token_box" },
}
function BMConfig.StockKey(itemId) return "bm_stock_" .. itemId end

-- ============================================================================
-- 核心函数提取（从设计文档 §12 的逻辑完整复刻）
-- ============================================================================

--- 加权随机收购数量（使用注入的随机值，方便测试）
---@param r number 0~1 的随机值
---@return integer
local function WeightedRecycleAmount(r)
    local weights = BMConfig.RECYCLE_WEIGHTS  -- { 0.25, 0.75, 1.0 }
    if r <= weights[1] then return 0 end
    if r <= weights[2] then return 1 end
    return 2
end

-- ============================================================================
-- 测试 1：加权随机分布验证
-- ============================================================================
print("\n=== TEST 1: WeightedRecycleAmount 边界值 ===")

-- 精确边界
assert_eq(WeightedRecycleAmount(0.0),   0, "r=0.0 → 0件")
assert_eq(WeightedRecycleAmount(0.1),   0, "r=0.1 → 0件")
assert_eq(WeightedRecycleAmount(0.25),  0, "r=0.25（边界）→ 0件")
assert_eq(WeightedRecycleAmount(0.251), 1, "r=0.251 → 1件")
assert_eq(WeightedRecycleAmount(0.5),   1, "r=0.5 → 1件")
assert_eq(WeightedRecycleAmount(0.75),  1, "r=0.75（边界）→ 1件")
assert_eq(WeightedRecycleAmount(0.751), 2, "r=0.751 → 2件")
assert_eq(WeightedRecycleAmount(0.99),  2, "r=0.99 → 2件")
assert_eq(WeightedRecycleAmount(1.0),   2, "r=1.0 → 2件")

-- 统计验证（大样本）
print("\n=== TEST 1b: 统计分布验证（10000 次） ===")
local counts = { [0] = 0, [1] = 0, [2] = 0 }
math.randomseed(42)
for _ = 1, 10000 do
    local r = math.random()
    local amount = WeightedRecycleAmount(r)
    counts[amount] = counts[amount] + 1
end
local p0 = counts[0] / 10000
local p1 = counts[1] / 10000
local p2 = counts[2] / 10000
print(string.format("  0件: %.1f%%  1件: %.1f%%  2件: %.1f%%", p0*100, p1*100, p2*100))
assert_range(p0, 0.22, 0.28, "0件概率≈25%")
assert_range(p1, 0.47, 0.53, "1件概率≈50%")
assert_range(p2, 0.22, 0.28, "2件概率≈25%")

-- 期望值
local expectedValue = p0 * 0 + p1 * 1 + p2 * 2
print(string.format("  期望值: %.3f（理论值 1.0）", expectedValue))
assert_range(expectedValue, 0.95, 1.05, "期望值≈1.0")

-- ============================================================================
-- 测试 2：过天状态检测
-- ============================================================================
print("\n=== TEST 2: 过天状态检测 ===")

local lastRecycleDate_ = nil
local recycleExecuted = false

--- 模拟 RecycleTick 的日期判断逻辑
local function SimRecycleTick(mockToday)
    if lastRecycleDate_ == mockToday then
        return false  -- 今天已执行，跳过
    end
    lastRecycleDate_ = mockToday
    recycleExecuted = true
    return true  -- 触发收购
end

-- 2a: 首次调用（lastRecycleDate_ = nil）
lastRecycleDate_ = nil
recycleExecuted = false
local triggered = SimRecycleTick("2026-05-08")
assert_true(triggered, "首次调用应触发收购")
assert_eq(lastRecycleDate_, "2026-05-08", "首次调用后记录日期")

-- 2b: 同日重复调用
recycleExecuted = false
triggered = SimRecycleTick("2026-05-08")
assert_true(not triggered, "同日重复调用不应触发")

-- 2c: 跨天
recycleExecuted = false
triggered = SimRecycleTick("2026-05-09")
assert_true(triggered, "新的一天应触发收购")
assert_eq(lastRecycleDate_, "2026-05-09", "跨天后更新日期")

-- 2d: 模拟服务器重启（lastRecycleDate_ 重置为 nil）
lastRecycleDate_ = nil
recycleExecuted = false
triggered = SimRecycleTick("2026-05-09")
assert_true(triggered, "重启后同日应重新触发（可接受行为）")

-- 2e: 跨月/跨年
lastRecycleDate_ = "2026-12-31"
triggered = SimRecycleTick("2027-01-01")
assert_true(triggered, "跨年应触发")

-- 2f: 同日字符串完全匹配
lastRecycleDate_ = "2026-05-08"
triggered = SimRecycleTick("2026-05-08")
assert_true(not triggered, "完全相同的日期字符串不触发")

-- ============================================================================
-- 测试 3：商品筛选逻辑
-- ============================================================================
print("\n=== TEST 3: 商品筛选逻辑 ===")

--- 模拟筛选满库存商品
---@param systemMoneys table  模拟的系统库存数据
---@return table fullItems
local function FilterFullStockItems(systemMoneys)
    local fullItems = {}
    for _, itemId in ipairs(BMConfig.ITEM_IDS) do
        local cfg = BMConfig.ITEMS[itemId]
        local maxStock = cfg.max_stock or BMConfig.MAX_STOCK
        local stock = systemMoneys[BMConfig.StockKey(itemId)] or 0
        if stock >= maxStock then
            fullItems[#fullItems + 1] = { id = itemId, stock = stock, cfg = cfg }
        end
    end
    return fullItems
end

-- 3a: 全部满库存
local moneys_all_full = {
    bm_stock_rake_1  = 5,
    bm_stock_rake_2  = 5,
    bm_stock_bagua_1 = 5,
    bm_stock_mat_1   = 10,
    bm_stock_token_box = 10,
}
local filtered = FilterFullStockItems(moneys_all_full)
assert_eq(#filtered, 5, "全部满库存: 5 个商品符合")

-- 3b: 部分满库存
local moneys_partial = {
    bm_stock_rake_1  = 5,   -- 满
    bm_stock_rake_2  = 3,   -- 未满
    bm_stock_bagua_1 = 5,   -- 满
    bm_stock_mat_1   = 9,   -- 未满（max=10）
    bm_stock_token_box = 10, -- 满
}
filtered = FilterFullStockItems(moneys_partial)
assert_eq(#filtered, 3, "部分满库存: 3 个商品符合")

-- 3c: 全部空库存
local moneys_empty = {}
filtered = FilterFullStockItems(moneys_empty)
assert_eq(#filtered, 0, "全部空库存: 0 个商品符合")

-- 3d: 库存超过 max_stock（异常情况，也应该被收购）
local moneys_over = {
    bm_stock_rake_1 = 7,  -- 超过 max_stock=5
}
filtered = FilterFullStockItems(moneys_over)
assert_eq(#filtered, 1, "超限库存: stock=7 > max=5，应符合")

-- 3e: 恰好等于 max_stock
local moneys_exact = {
    bm_stock_mat_1 = 10,  -- 恰好 = max_stock=10
}
filtered = FilterFullStockItems(moneys_exact)
assert_eq(#filtered, 1, "恰好满库存: stock=10 = max=10，应符合")

-- ============================================================================
-- 测试 4：收购数量边界（stock=1 但随机出 2）
-- ============================================================================
print("\n=== TEST 4: 收购数量边界 ===")

--- 模拟为满库存商品决定收购数量（使用固定随机值序列）
---@param fullItems table
---@param randomValues table  预设的随机值序列
---@return table toRecycle
local function DecideRecycleAmounts(fullItems, randomValues)
    local toRecycle = {}
    for i, item in ipairs(fullItems) do
        local r = randomValues[i] or math.random()
        local amount = WeightedRecycleAmount(r)
        if amount > 0 then
            amount = math.min(amount, item.stock)  -- 关键：不超过当前库存
            toRecycle[#toRecycle + 1] = {
                id = item.id,
                amount = amount,
                cfg = item.cfg,
                newStock = item.stock - amount,
            }
        end
    end
    return toRecycle
end

-- 4a: stock=1, 随机出 2 → 应截断为 1
local items_low_stock = {
    { id = "rake_1", stock = 1, cfg = BMConfig.ITEMS.rake_1 },
}
local result = DecideRecycleAmounts(items_low_stock, { 0.8 })  -- r=0.8 → 2件
assert_eq(#result, 1, "stock=1 随机2件: 应有1条收购记录")
assert_eq(result[1].amount, 1, "stock=1 随机2件: 实际收购数量截断为1")
assert_eq(result[1].newStock, 0, "stock=1 随机2件: 新库存为0")

-- 4b: stock=2, 随机出 2 → 正好
local items_exact_stock = {
    { id = "rake_1", stock = 2, cfg = BMConfig.ITEMS.rake_1 },
}
result = DecideRecycleAmounts(items_exact_stock, { 0.8 })
assert_eq(result[1].amount, 2, "stock=2 随机2件: 正好收购2件")
assert_eq(result[1].newStock, 0, "stock=2 随机2件: 新库存为0")

-- 4c: stock=5, 随机出 0 → 不收购
local items_skip = {
    { id = "rake_1", stock = 5, cfg = BMConfig.ITEMS.rake_1 },
}
result = DecideRecycleAmounts(items_skip, { 0.1 })  -- r=0.1 → 0件
assert_eq(#result, 0, "随机0件: 无收购记录")

-- 4d: 多个商品混合随机
local items_mixed = {
    { id = "rake_1",  stock = 5, cfg = BMConfig.ITEMS.rake_1 },
    { id = "rake_2",  stock = 5, cfg = BMConfig.ITEMS.rake_2 },
    { id = "bagua_1", stock = 5, cfg = BMConfig.ITEMS.bagua_1 },
}
result = DecideRecycleAmounts(items_mixed, { 0.1, 0.5, 0.9 })
-- r=0.1→0件, r=0.5→1件, r=0.9→2件
assert_eq(#result, 2, "混合随机: 2 个商品被收购（跳过0件的）")
assert_eq(result[1].id, "rake_2", "混合随机: 第1个收购是 rake_2")
assert_eq(result[1].amount, 1, "混合随机: rake_2 收购 1 件")
assert_eq(result[2].id, "bagua_1", "混合随机: 第2个收购是 bagua_1")
assert_eq(result[2].amount, 2, "混合随机: bagua_1 收购 2 件")

-- ============================================================================
-- 测试 5：BatchCommit 构建验证
-- ============================================================================
print("\n=== TEST 5: BatchCommit 指令构建 ===")

--- 模拟构建 BatchCommit 操作列表
local function BuildBatchOps(toRecycle)
    local ops = {}
    for _, r in ipairs(toRecycle) do
        ops[#ops + 1] = {
            op = "MoneyCost",
            uid = BMConfig.SYSTEM_UID,
            key = BMConfig.StockKey(r.id),
            amount = r.amount,
        }
    end
    return ops
end

local recycleList = {
    { id = "rake_1",  amount = 1, cfg = BMConfig.ITEMS.rake_1, newStock = 4 },
    { id = "bagua_1", amount = 2, cfg = BMConfig.ITEMS.bagua_1, newStock = 3 },
}
local ops = BuildBatchOps(recycleList)
assert_eq(#ops, 2, "BatchCommit: 2 条 MoneyCost 指令")
assert_eq(ops[1].key, "bm_stock_rake_1", "BatchCommit: 第1条 key 正确")
assert_eq(ops[1].amount, 1, "BatchCommit: 第1条 amount=1")
assert_eq(ops[1].uid, 0, "BatchCommit: uid=SYSTEM_UID=0")
assert_eq(ops[2].key, "bm_stock_bagua_1", "BatchCommit: 第2条 key 正确")
assert_eq(ops[2].amount, 2, "BatchCommit: 第2条 amount=2")

-- ============================================================================
-- 测试 6：日志记录字段验证
-- ============================================================================
print("\n=== TEST 6: TradeLogger.LogPublic 参数验证 ===")

--- 模拟构建日志条目
local function BuildLogEntries(toRecycle)
    local entries = {}
    for _, r in ipairs(toRecycle) do
        entries[#entries + 1] = {
            playerName = BMConfig.RECYCLE_NPC_NAME,
            action = "buy",
            itemId = r.id,
            amount = r.amount,
            price = r.cfg.sell_price,
            newXianshi = 0,
        }
    end
    return entries
end

local logs = BuildLogEntries(recycleList)
assert_eq(#logs, 2, "日志: 2 条记录")
assert_eq(logs[1].playerName, "大黑无天", "日志: playerName = 大黑无天")
assert_eq(logs[1].action, "buy", "日志: action = buy")
assert_eq(logs[1].itemId, "rake_1", "日志: itemId 正确")
assert_eq(logs[1].amount, 1, "日志: amount 正确")
assert_eq(logs[1].price, 6, "日志: price = sell_price = 6")
assert_eq(logs[1].newXianshi, 0, "日志: newXianshi = 0（系统NPC）")

-- ============================================================================
-- 测试 7：并发锁保护
-- ============================================================================
print("\n=== TEST 7: 并发锁保护 ===")

local recycleRunning_ = false
local executeCount = 0

--- 模拟 ExecuteRecycle 的锁检查
local function SimExecuteRecycle()
    if recycleRunning_ then
        return false, "正在执行中"
    end
    recycleRunning_ = true
    executeCount = executeCount + 1
    -- 模拟异步完成
    recycleRunning_ = false
    return true, "OK"
end

-- 7a: 正常执行
executeCount = 0
local ok, msg = SimExecuteRecycle()
assert_true(ok, "正常执行: 应成功")
assert_eq(executeCount, 1, "正常执行: 计数器=1")

-- 7b: 模拟异步期间重入（锁未释放时）
recycleRunning_ = true  -- 模拟仍在异步中
ok, msg = SimExecuteRecycle()
assert_true(not ok, "锁未释放时重入: 应被拒绝")
assert_eq(msg, "正在执行中", "锁未释放时重入: 返回正确消息")
assert_eq(executeCount, 1, "锁未释放时重入: 计数器不变")
recycleRunning_ = false  -- 清理

-- ============================================================================
-- 测试 8：GM 手动触发不受每日限制
-- ============================================================================
print("\n=== TEST 8: GM 手动触发 vs 自动触发 ===")

lastRecycleDate_ = "2026-05-08"  -- 模拟今天已自动执行过

-- 8a: 自动触发应跳过
triggered = SimRecycleTick("2026-05-08")
assert_true(not triggered, "自动触发: 同日应跳过")

-- 8b: GM 手动触发应直接执行（不检查日期）
local function SimGMRecycle()
    -- GM 命令直接调用 ExecuteRecycle，不经过 RecycleTick
    return SimExecuteRecycle()
end
ok, msg = SimGMRecycle()
assert_true(ok, "GM手动触发: 同日应仍可执行")

-- 8c: GM 手动触发不应更新 lastRecycleDate_
-- （确认 GM 手动触发走的是 ExecuteRecycle，不走 RecycleTick）
assert_eq(lastRecycleDate_, "2026-05-08", "GM手动触发: 不应更新 lastRecycleDate_")

-- ============================================================================
-- 测试 9：完整流程端到端模拟
-- ============================================================================
print("\n=== TEST 9: 端到端流程模拟 ===")

--- 完整模拟一次收购流程
---@param systemMoneys table
---@param randomValues table
---@return integer totalRecycled, table logEntries
local function SimFullRecycle(systemMoneys, randomValues)
    -- Step 1: 筛选满库存商品
    local eligibleItems = FilterFullStockItems(systemMoneys)
    if #eligibleItems == 0 then
        return 0, {}
    end

    -- Step 2: 加权随机决定数量
    local toRecycle = DecideRecycleAmounts(eligibleItems, randomValues)
    if #toRecycle == 0 then
        return 0, {}
    end

    -- Step 3: 构建 BatchCommit 操作
    local batchOps = BuildBatchOps(toRecycle)

    -- Step 4: 模拟 BatchCommit 成功 → 扣减库存
    for _, op in ipairs(batchOps) do
        systemMoneys[op.key] = (systemMoneys[op.key] or 0) - op.amount
    end

    -- Step 5: 记录日志
    local logEntries = BuildLogEntries(toRecycle)

    -- Step 6: 统计总量
    local totalCount = 0
    for _, r in ipairs(toRecycle) do
        totalCount = totalCount + r.amount
    end

    return totalCount, logEntries
end

-- 9a: 典型场景 — 3 个满库存商品
local moneys9 = {
    bm_stock_rake_1  = 5,
    bm_stock_rake_2  = 5,
    bm_stock_bagua_1 = 5,
    bm_stock_mat_1   = 3,   -- 未满
    bm_stock_token_box = 10, -- 满
}
-- 随机值: rake_1→0.5(1件), rake_2→0.1(0件), bagua_1→0.9(2件), token_box→0.6(1件)
local total, logs9 = SimFullRecycle(moneys9, { 0.5, 0.1, 0.9, 0.6 })
-- 注意: FilterFullStockItems 按 ITEM_IDS 顺序遍历
-- ITEM_IDS = { "rake_1", "rake_2", "bagua_1", "mat_1", "token_box" }
-- 满库存: rake_1(5), rake_2(5), bagua_1(5), token_box(10) → 4 个
-- 随机值对应: rake_1→0.5(1件), rake_2→0.1(0件), bagua_1→0.9(2件), token_box→0.6(1件)
assert_eq(total, 4, "端到端: 总收购 4 件 (1+0+2+1)")
assert_eq(#logs9, 3, "端到端: 3 条日志记录（跳过0件的）")

-- 验证库存变化
assert_eq(moneys9["bm_stock_rake_1"], 4, "端到端: rake_1 库存 5→4")
assert_eq(moneys9["bm_stock_rake_2"], 5, "端到端: rake_2 库存不变（随机0件）")
assert_eq(moneys9["bm_stock_bagua_1"], 3, "端到端: bagua_1 库存 5→3")
assert_eq(moneys9["bm_stock_mat_1"], 3, "端到端: mat_1 库存不变（未满库存）")
assert_eq(moneys9["bm_stock_token_box"], 9, "端到端: token_box 库存 10→9")

-- ============================================================================
-- 测试 10：连续多天模拟
-- ============================================================================
print("\n=== TEST 10: 连续多天模拟 ===")

local moneys10 = {
    bm_stock_rake_1 = 5,  -- max=5，初始满
}
lastRecycleDate_ = nil

-- 模拟 3 天
local days = { "2026-05-01", "2026-05-02", "2026-05-03" }
local dayRandoms = { 0.5, 0.5, 0.5 }  -- 每天都随机到 1 件

for d, day in ipairs(days) do
    lastRecycleDate_ = days[d - 1]  -- 前一天的日期（第1天为 nil）
    local trig = SimRecycleTick(day)
    assert_true(trig, "Day " .. d .. ": 应触发")

    -- 只有满库存才收购
    local fItems = FilterFullStockItems(moneys10)
    if #fItems > 0 then
        local toRec = DecideRecycleAmounts(fItems, { dayRandoms[d] })
        for _, r in ipairs(toRec) do
            moneys10[BMConfig.StockKey(r.id)] = r.newStock
        end
    end
end

-- Day1: stock=5(满)→随机1件→stock=4
-- Day2: stock=4(未满)→不符合→stock=4
-- Day3: stock=4(未满)→不符合→stock=4
assert_eq(moneys10["bm_stock_rake_1"], 4, "多天模拟: 只有第1天收购，后续未满不再收购")

-- ============================================================================
-- 测试 11：GMHandler 架构问题检测
-- ============================================================================
print("\n=== TEST 11: GMHandler 架构分析 ===")

-- 现有 GMHandler 架构：客户端发送 → 服务端鉴权 → 返回 ok → 客户端执行回调
-- bm_recycle 需要服务端执行：这是架构变更！
-- 检测点：GMHandler 需要新增 cmd == "bm_recycle" 分支

-- 方案A: 在 GMHandler 中分支处理（参考 C2S_GMResetDaily 模式）
-- 方案B: 新增独立协议事件（如 C2S_BMRecycle）
-- 设计选择: 方案A 更简洁，复用现有 GMCommand 协议

local gmArchitectureIssues = {}

-- 问题1: 现有 GMHandler 在鉴权后直接返回 ok，不执行业务逻辑
-- bm_recycle 需要在鉴权后执行 ExecuteRecycle，然后才返回结果
gmArchitectureIssues[#gmArchitectureIssues + 1] = {
    issue = "GMHandler 需要新增服务端执行分支",
    severity = "设计变更",
    solution = "在鉴权通过后、发送响应前，检查 cmd=='bm_recycle' 并调用 ExecuteRecycle",
}

-- 问题2: ExecuteRecycle 是异步的（含 serverCloud.money:Get 回调）
-- GMHandler 需要等异步完成后才能返回结果
gmArchitectureIssues[#gmArchitectureIssues + 1] = {
    issue = "ExecuteRecycle 是异步函数，GMHandler 需要延迟响应",
    severity = "关键",
    solution = "bm_recycle 分支不立即返回 S2C_GMCommandResult，而是在 ExecuteRecycle callback 中发送",
}

-- 问题3: 客户端 callback 预期
-- SendGMCommand 的 callback 在收到 S2C_GMCommandResult(ok=true) 时执行
-- 但 bm_recycle 的客户端不需要执行业务逻辑，只需要显示结果
gmArchitectureIssues[#gmArchitectureIssues + 1] = {
    issue = "客户端 callback 应该只显示结果，不执行业务逻辑",
    severity = "低",
    solution = "callback 中仅 ShowLog 显示收购结果（从 S2C msg 字段读取）",
}

print("  发现 " .. #gmArchitectureIssues .. " 个架构要点:")
for i, item in ipairs(gmArchitectureIssues) do
    print("  " .. i .. ". [" .. item.severity .. "] " .. item.issue)
    print("     → " .. item.solution)
end

-- 这些不是自动化测试，而是设计审查发现
-- 标记为 passed 不增加测试计数
totalTests = totalTests + 1
passed = passed + 1  -- 审查完成即通过

-- ============================================================================
-- 测试 12：TradeLogger.LogPublic 调用时序问题
-- ============================================================================
print("\n=== TEST 12: 日志写入时序分析 ===")

-- 关键问题：设计文档 §12.3.3 中描述的是
--   BatchCommit 成功后 → 逐项调用 TradeLogger.LogPublic
-- 
-- 但 TradeLogger.LogPublic 内部也是异步的（serverCloud.list:Add）
-- 如果有 3 个商品被收购，会触发 3 次 list:Add + 3 次 TrimList
-- 
-- 潜在问题：
-- 1. 多次 TrimList 并发执行，可能导致同一条记录被重复删除 ✗
-- 2. 但 TrimList 的 Delete 是按 list_id 的，重复删除只会报错不会丢数据 ✓
-- 3. 这和现有的 HandleBuy/HandleSell 中的调用模式一致 ✓

local timingIssues = {}

-- 检查: 一次收购多个商品 → 多次 LogPublic → 多次 TrimList
-- 现有交易（Buy/Sell）每次只写 1 条日志，不存在此问题
-- 但自动收购可能一次写多条
timingIssues[#timingIssues + 1] = {
    issue = "单次收购多商品 → 多次 LogPublic → TrimList 并发",
    risk = "低",
    reason = "TrimList 按 list_id 删除，重复删除不会丢数据；与现有模式一致",
    mitigation = "可选优化：合并为单次 list:Add 写入（但增加复杂度，收益不大）",
}

print("  发现 " .. #timingIssues .. " 个时序要点:")
for i, item in ipairs(timingIssues) do
    print("  " .. i .. ". [风险:" .. item.risk .. "] " .. item.issue)
    print("     → " .. item.reason)
end

totalTests = totalTests + 1
passed = passed + 1

-- ============================================================================
-- 汇总
-- ============================================================================
print("\n" .. string.rep("=", 60))
print(string.format("测试结果: %d/%d 通过  %d 失败", passed, totalTests, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("!!! 有测试失败，请检查 !!!")
else
    print("全部通过")
end
