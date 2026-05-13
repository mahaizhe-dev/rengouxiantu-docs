-- ============================================================================
-- test_bm_s4c1_confirm_dialog_buttons.lua
-- BM-S4C1: 确认弹窗按钮行缺失回归测试
--
-- 验证 ShowConfirmDialog 构建的 dialogContent 数组在 buy/sell
-- 两种路径下均不包含 nil 空洞，且末尾元素始终是按钮行 Panel。
-- ============================================================================

local TAG = "[test_bm_s4c1]"

-- ============================================================================
-- 测试辅助
-- ============================================================================

local passed, failed = 0, 0

local function assert_true(cond, msg)
    if cond then
        passed = passed + 1
        print("  ✓ " .. msg)
    else
        failed = failed + 1
        print("  ✗ FAIL: " .. msg)
    end
end

local function assert_eq(a, b, msg)
    assert_true(a == b, msg .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end

-- ============================================================================
-- 模拟 UI 框架的 ipairs 行为，检测 nil 空洞
-- ============================================================================

--- 模拟 ipairs 遍历计数（遇 nil 停止）
---@param t table
---@return integer ipairsCount 实际被 ipairs 遍历到的元素数
---@return integer rawCount   table 中实际非 nil 元素数（含 nil 后面的）
local function countWithIpairs(t)
    local ipairsCount = 0
    for _ in ipairs(t) do
        ipairsCount = ipairsCount + 1
    end
    -- rawlen 受 nil 影响，手动遍历到真实末尾
    local rawCount = 0
    local i = 1
    while true do
        if rawget(t, i) ~= nil then
            rawCount = rawCount + 1
        elseif rawget(t, i + 1) == nil and rawget(t, i + 2) == nil then
            break  -- 连续3个nil视为末尾
        end
        i = i + 1
        if i > 100 then break end  -- 安全边界
    end
    return ipairsCount, rawCount
end

-- ============================================================================
-- 核心测试：模拟 dialogContent 构建逻辑
-- ============================================================================

print(TAG .. " === BM-S4C1 确认弹窗按钮行回归测试 ===\n")

-- 用占位值模拟真实 UI 组件
local LABEL = "label"
local PANEL = "panel"
local BUTTON_ROW = "button_row"

--- 模拟修复后的 dialogContent 构建（从 BlackMerchantUI.lua 提取核心结构）
---@param isBuy boolean
---@return table dialogContent
local function buildDialogContent(isBuy)
    local content = {
        LABEL,  -- 标题
        PANEL,  -- 分隔线
        LABEL,  -- 交易详情
        LABEL,  -- 附加信息
    }
    -- BM-S4AR: 买入时条件插入保护期提醒
    if isBuy then
        table.insert(content, LABEL)  -- 保护期提醒
    end
    -- 按钮行（始终追加）
    table.insert(content, BUTTON_ROW)
    return content
end

--- 模拟修复前的旧逻辑（children 数组中间含 nil）
---@param isBuy boolean
---@return table dialogContent
local function buildDialogContent_OLD(isBuy)
    return {
        LABEL,  -- 标题
        PANEL,  -- 分隔线
        LABEL,  -- 交易详情
        LABEL,  -- 附加信息
        isBuy and LABEL or nil,  -- 保护期提醒 — 旧写法，sell 时产生 nil
        BUTTON_ROW,              -- 按钮行
    }
end

-- --- A. 修复后：buy 路径 ---
print("  --- A. 修复后 buy 路径 ---")
do
    local content = buildDialogContent(true)
    local ipN, rawN = countWithIpairs(content)
    assert_eq(ipN, rawN, "A1: buy 路径无 nil 空洞 (ipairs=" .. ipN .. " raw=" .. rawN .. ")")
    assert_eq(content[#content], BUTTON_ROW, "A2: buy 路径末尾是按钮行")
    assert_eq(#content, 6, "A3: buy 路径共 6 个子元素（含保护期提醒）")
end

-- --- B. 修复后：sell 路径 ---
print("  --- B. 修复后 sell 路径 ---")
do
    local content = buildDialogContent(false)
    local ipN, rawN = countWithIpairs(content)
    assert_eq(ipN, rawN, "B1: sell 路径无 nil 空洞 (ipairs=" .. ipN .. " raw=" .. rawN .. ")")
    assert_eq(content[#content], BUTTON_ROW, "B2: sell 路径末尾是按钮行")
    assert_eq(#content, 5, "B3: sell 路径共 5 个子元素（无保护期提醒）")
end

-- --- C. 旧逻辑回归：sell 路径存在 nil 截断 ---
print("  --- C. 旧逻辑回归验证 ---")
do
    local oldContent = buildDialogContent_OLD(false)
    local ipN, rawN = countWithIpairs(oldContent)
    -- 旧逻辑 sell 路径：{L, P, L, L, nil, BUTTON_ROW}
    -- ipairs 只能遍历到 4，但实际有 5 个非 nil 元素
    assert_true(ipN < rawN, "C1: 旧逻辑 sell 路径存在 nil 截断 (ipairs=" .. ipN .. " raw=" .. rawN .. ")")
    assert_true(ipN == 4, "C2: 旧逻辑 ipairs 在第 5 位 nil 处停止")
end

-- --- D. 旧逻辑：buy 路径无问题 ---
print("  --- D. 旧逻辑 buy 路径 ---")
do
    local oldContent = buildDialogContent_OLD(true)
    local ipN, rawN = countWithIpairs(oldContent)
    assert_eq(ipN, rawN, "D1: 旧逻辑 buy 路径无 nil（因为条件为 true）")
    assert_eq(oldContent[#oldContent], BUTTON_ROW, "D2: 旧逻辑 buy 路径末尾是按钮行")
end

-- ============================================================================
-- 汇总
-- ============================================================================

print(string.format("\n%s TOTAL: %d  PASSED: %d  FAILED: %d\n",
    TAG, passed + failed, passed, failed))

if failed > 0 then
    error(string.format("%s %d test(s) FAILED", TAG, failed))
end

return { passed = passed, failed = failed, total = passed + failed }
