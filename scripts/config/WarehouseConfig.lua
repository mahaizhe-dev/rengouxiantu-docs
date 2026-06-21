-- ============================================================================
-- WarehouseConfig.lua - 仓库系统配置常量
-- ============================================================================

local WarehouseConfig = {}

-- ── 格子布局 ──
WarehouseConfig.ITEMS_PER_ROW = 8      -- 每排格子数
WarehouseConfig.MAX_ROWS = 6           -- 最大排数（角色仓库）
WarehouseConfig.MAX_SLOTS = 48         -- 8 × 6 = 48

-- ── 排解锁费用（万金币）──
-- 第1排免费，第2排100W，第3排500W，第4排1000W，N≥5=(N-3)×1000W
WarehouseConfig.ROW_COSTS = {
    [1] = 0,
    [2] = 1000000,
    [3] = 5000000,
    [4] = 10000000,
}

--- 获取指定排的解锁费用
---@param row number 排号（1-based）
---@return number 费用（金币）
function WarehouseConfig.GetRowCost(row)
    if row <= 0 or row > WarehouseConfig.MAX_ROWS then return -1 end
    if WarehouseConfig.ROW_COSTS[row] then
        return WarehouseConfig.ROW_COSTS[row]
    end
    -- N ≥ 5: (N-3) × 1000W
    return (row - 3) * 10000000
end

-- ── 第二页 ──
WarehouseConfig.PAGE2_MAX_ROWS = 6
WarehouseConfig.PAGE2_MAX_SLOTS = 48   -- 8 × 6 = 48
WarehouseConfig.PAGE2_ROW_COSTS = {
    [1] = 50000000,    -- 5000万
    [2] = 75000000,    -- 7500万
    [3] = 100000000,   -- 1亿
    [4] = 125000000,   -- 1.25亿
    [5] = 150000000,   -- 1.5亿
    [6] = 175000000,   -- 1.75亿
}

--- 获取第二页指定排的解锁费用
---@param row number 排号（1-based）
---@return number 费用（金币），-1 表示无效
function WarehouseConfig.GetPage2RowCost(row)
    if row <= 0 or row > WarehouseConfig.PAGE2_MAX_ROWS then return -1 end
    return WarehouseConfig.PAGE2_ROW_COSTS[row] or -1
end

-- ── 账号仓库 ──
WarehouseConfig.ACCOUNT_SLOTS = 8      -- 账号仓库 1 排 8 格
WarehouseConfig.ACCOUNT_ENABLED = false -- 账号仓库暂未开放

-- ── 初始状态 ──
WarehouseConfig.INITIAL_UNLOCKED_ROWS = 1  -- 初始解锁排数（第1排免费）

return WarehouseConfig
