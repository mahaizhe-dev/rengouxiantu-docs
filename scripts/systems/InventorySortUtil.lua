--- InventorySortUtil.lua
--- 背包/仓库共享的物品排序与合并工具
--- 执行文档 §3.2: 提取 InventorySystem.SortBackpack() 中的排序/合并逻辑

local TradeLock = require("systems.BlackMarketTradeLock")
local GameConfig = require("config.GameConfig")
local Utils = require("core.Utils")

local M = {}

--------------------------------------------------------------------
-- §3.3.3 并发保护标志
--------------------------------------------------------------------
M._sorting = false

--------------------------------------------------------------------
-- 合并键生成
-- consumableId + 锁状态 + 批次
--------------------------------------------------------------------
function M.GetMergeKey(item)
    local cId = item.consumableId
    -- BM-NORESELL: 黑市买入来源永久独立分组，绝不与普通来源合并（防洗白）
    -- 即使临时锁过期（IsLocked=false），bmNoResell 仍把它隔离在 |noresell 系列键
    if TradeLock.IsNoResell(item) then
        if TradeLock.IsLocked(item) then
            local batch = item.bmLockBatchId or "_nobatch_"
            return cId .. "|noresell|locked|" .. batch
        else
            return cId .. "|noresell"
        end
    end
    if TradeLock.IsLocked(item) then
        local batch = item.bmLockBatchId or "_nobatch_"
        return cId .. "|locked|" .. batch
    else
        return cId .. "|unlocked"
    end
end

--------------------------------------------------------------------
-- 合并消耗品堆叠
-- items: 物品数组（会被修改）
-- 返回：合并后的物品数组
-- §3.3.1: 装备只做引用搬运，不做 shallow copy
--------------------------------------------------------------------
function M.MergeConsumables(items)
    local MAX_STACK = GameConfig.MAX_STACK_COUNT
    local mergeGroups = {} -- mergeKey → { stack1, stack2, ... }
    local result = {}      -- 非消耗品(装备)直接放入

    for _, item in ipairs(items) do
        if item.category == "consumable" and item.consumableId then
            local key = M.GetMergeKey(item)
            if not mergeGroups[key] then
                mergeGroups[key] = {}
            end
            -- 尝试塞入已有的未满堆叠
            local placed = false
            for _, stack in ipairs(mergeGroups[key]) do
                if stack.count < MAX_STACK then
                    local space = MAX_STACK - stack.count
                    local move = math.min(item.count or 1, space)
                    stack.count = stack.count + move
                    local leftover = (item.count or 1) - move
                    if leftover > 0 then
                        item.count = leftover
                        -- 继续下一个堆叠
                    else
                        placed = true
                        break
                    end
                end
            end
            if not placed then
                local remaining = item.count or 1
                while remaining > 0 do
                    local stackAmt = math.min(remaining, MAX_STACK)
                    local newItem = item
                    if remaining ~= (item.count or 1) or stackAmt ~= remaining then
                        -- 拆分时才创建新表（仅消耗品，不涉及装备字段丢失问题）
                        newItem = {}
                        for k, v in pairs(item) do newItem[k] = v end
                        newItem.id = Utils.NextId()
                    end
                    newItem.count = stackAmt
                    table.insert(mergeGroups[key], newItem)
                    remaining = remaining - stackAmt
                end
            end
        else
            -- §3.3.1: 装备直接引用搬运，绝不 shallow copy
            result[#result + 1] = item
        end
    end

    -- 将合并后的消耗品堆叠加入结果
    for _, stacks in pairs(mergeGroups) do
        for _, stack in ipairs(stacks) do
            result[#result + 1] = stack
        end
    end

    return result
end

--------------------------------------------------------------------
-- 排序比较器
-- 装备在前(品质降序→阶降序→槽位名升序)
-- 消耗品在后(consumableId 升序)
--------------------------------------------------------------------
function M.SortComparator(a, b)
    local aIsEquip = (a.category ~= "consumable") and 1 or 0
    local bIsEquip = (b.category ~= "consumable") and 1 or 0
    -- 装备 > 消耗品
    if aIsEquip ~= bIsEquip then return aIsEquip > bIsEquip end
    if aIsEquip == 1 then
        -- 都是装备：品质降序
        local aQ = GameConfig.QUALITY_ORDER[a.quality] or 0
        local bQ = GameConfig.QUALITY_ORDER[b.quality] or 0
        if aQ ~= bQ then return aQ > bQ end
        -- 品质相同：阶降序
        local aT = a.tier or 0
        local bT = b.tier or 0
        if aT ~= bT then return aT > bT end
        -- 阶相同：按槽位名排序（稳定）
        return (a.slot or "") < (b.slot or "")
    else
        -- 都是消耗品：按 consumableId 排序
        local aId = a.consumableId or ""
        local bId = b.consumableId or ""
        return tostring(aId) < tostring(bId)
    end
end

--------------------------------------------------------------------
-- §3.3.2 数量守恒校验
-- 排序前后消耗品总数量必须一致
-- items: 物品数组
-- 返回: { [consumableId] = totalCount }
--------------------------------------------------------------------
function M.CountConsumables(items)
    local counts = {}
    for _, item in ipairs(items) do
        if item.category == "consumable" and item.consumableId then
            local cId = tostring(item.consumableId)
            counts[cId] = (counts[cId] or 0) + (item.count or 1)
        end
    end
    return counts
end

--------------------------------------------------------------------
-- 校验排序前后数量守恒
-- 返回: ok:bool, message:string
--------------------------------------------------------------------
function M.VerifyConservation(beforeCounts, afterCounts)
    -- 检查排序前的物品是否在排序后都存在且数量一致
    for cId, beforeCount in pairs(beforeCounts) do
        local afterCount = afterCounts[cId] or 0
        if afterCount ~= beforeCount then
            local msg = string.format(
                "[InventorySortUtil] 数量守恒校验失败: consumableId=%s, before=%d, after=%d",
                cId, beforeCount, afterCount)
            print(msg)
            return false, msg
        end
    end
    -- 检查排序后是否出现了排序前没有的物品
    for cId, afterCount in pairs(afterCounts) do
        if not beforeCounts[cId] then
            local msg = string.format(
                "[InventorySortUtil] 数量守恒校验失败: 排序后出现新物品 consumableId=%s, count=%d",
                cId, afterCount)
            print(msg)
            return false, msg
        end
    end
    return true, "OK"
end

--------------------------------------------------------------------
-- 完整的排序流程（合并 + 排序 + 守恒校验）
-- items: 物品数组（原始引用列表）
-- 返回: sortedItems:array, ok:bool, message:string
--------------------------------------------------------------------
function M.SortItems(items)
    -- §3.3.2 排序前计数
    local beforeCounts = M.CountConsumables(items)

    -- 合并消耗品
    local merged = M.MergeConsumables(items)

    -- 排序
    table.sort(merged, M.SortComparator)

    -- §3.3.2 排序后计数 + 校验
    local afterCounts = M.CountConsumables(merged)
    local ok, msg = M.VerifyConservation(beforeCounts, afterCounts)
    if not ok then
        print("[InventorySortUtil] 排序被中止，物品未变更: " .. msg)
        return nil, false, msg
    end

    return merged, true, "OK"
end

return M
