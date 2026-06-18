-- ============================================================================
-- InventoryOps.lua — 背包/命格共享操作逻辑（无状态，不持有 manager）
--
-- Step 4/5 提取：整理/批量出售/出售设置持久化
-- 安全说明：本模块不持有任何 InventoryManager/MinggeSystem 引用，
--          操作通过调用方传入的 system 接口完成，不存在串位风险（M.3 红线合规）。
-- ============================================================================

local cjson = require("cjson")

local InventoryOps = {}

-- ============================================================================
-- 出售品质勾选持久化（A/B 共用，文件名由调用方指定）
-- ============================================================================

--- 从本地文件加载出售品质勾选到 qualities 表
---@param filename string 设置文件名（如 "sell_equip_settings.json"）
---@param qualities table 目标表，字段会被覆盖
function InventoryOps.LoadSellSettings(filename, qualities)
    pcall(function()
        if not fileSystem or not fileSystem:FileExists(filename) then return end
        local file = File(filename, FILE_READ)
        if not file or not file:IsOpen() then return end
        local raw = file:ReadString()
        file:Close()
        local ok, data = pcall(cjson.decode, raw)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if qualities[k] ~= nil then
                    qualities[k] = (v == true)
                end
            end
        end
    end)
end

--- 将出售品质勾选持久化到本地文件
---@param filename string 设置文件名
---@param qualities table 源表
function InventoryOps.SaveSellSettings(filename, qualities)
    pcall(function()
        local file = File(filename, FILE_WRITE)
        if not file or not file:IsOpen() then return end
        file:WriteString(cjson.encode(qualities))
        file:Close()
    end)
end

-- ============================================================================
-- 整理操作（调用方传入 sortFn）
-- ============================================================================

--- 执行整理
---@param sortFn function 实际排序函数（如 InventorySystem.SortBackpack）
---@return string msg 操作结果消息
function InventoryOps.DoSort(sortFn)
    sortFn()
    return "背包已整理"
end

-- ============================================================================
-- 批量出售操作（调用方传入 sellFn）
-- ============================================================================

--- 执行批量出售
---@param qualities table 品质勾选表 { white=bool, green=bool, ... }
---@param sellFn function 实际出售函数，签名 (qualities) → count, gold, lingYun
---@return boolean ok 是否有出售
---@return string msg 操作结果消息
function InventoryOps.DoBatchSell(qualities, sellFn)
    -- 校验是否勾选了至少一个品质
    local hasAny = false
    for _, v in pairs(qualities) do
        if v then hasAny = true; break end
    end
    if not hasAny then
        return false, "请先在▼中勾选要出售的品质"
    end

    local count, gold, lingYun = sellFn(qualities)
    if count > 0 then
        local parts = {}
        if gold and gold > 0 then parts[#parts + 1] = gold .. " 金币" end
        if lingYun and lingYun > 0 then parts[#parts + 1] = lingYun .. " 灵韵" end
        local earned = #parts > 0 and table.concat(parts, " + ") or "0"
        return true, "出售了 " .. count .. " 件，获得 " .. earned
    else
        return false, "没有可出售的对应品质物品"
    end
end

return InventoryOps
