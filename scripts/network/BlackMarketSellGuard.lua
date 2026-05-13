-- ============================================================================
-- BlackMarketSellGuard.lua — 黑市卖出服务端权威校验（BM-S3 + BM-S3R 收口）
--
-- 职责：在 HandleSell() 中对商品进行安全分类判定
-- 设计文档：
--   docs/2026-05-13-BM-S3-黑市卖出服务端权威校验第一阶段任务卡.md
--   docs/2026-05-13-BM-S3R-黑市卖出服务端保守分类与真实集成校验任务卡.md
--
-- 原则："宁可拒绝，不可误发仙石"
--
-- BM-S3R 收口结论：
--   所有 79 项商品均存在本地先消耗路径（ConsumeConsumable / _UseTokenBox），
--   服务端无法独立证明安全。统一按 high_risk_blocked 处理。
--
-- 安全类证明表（BM-S3R Step 1 审计结果）：
--   rake 碎片(19项)  → ArtifactSystem.lua:242 ConsumeConsumable → 伪安全
--   bagua 碎片        → ArtifactSystem_ch4.lua:212 ConsumeConsumable → 伪安全
--   tiandi 碎片       → ArtifactSystem_tiandi.lua:123 ConsumeConsumable → 伪安全
--   dragon_scale_*(4) → DragonForgeUI.lua:1112 ConsumeConsumable → 伪安全
--   token_box(3)      → InventorySystem.lua:997-1001 _UseTokenBox → 伪安全
--   lingyu / herb / skill_book / special_equip / gold_brick → 已为高风险
--
-- 结果：安全类 = 0 项，高风险类 = 79 项
-- ============================================================================

local BMConfig = require("config.BlackMerchantConfig")

local M = {}

-- ============================================================================
-- BM-S3R: 不再有安全类白名单
-- 所有商品统一走 high_risk_blocked，服务端一律拒卖
-- 未来如需放行特定商品，必须逐项证明"服务端可独立校验安全"
-- ============================================================================

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 判断商品是否允许通过服务端卖出校验
--- BM-S3R: 所有商品均为高风险，统一拒卖
---@param itemId string BMConfig.ITEMS 中的商品 ID
---@return boolean allowed 是否允许卖出
---@return string|nil reason 拒绝原因（allowed=false 时有值）
function M.CheckSellAllowed(itemId)
    local cfg = BMConfig.ITEMS[itemId]
    if not cfg then
        return false, "unknown_item"
    end

    -- BM-S3R: 所有已知商品均存在本地先消耗路径，服务端无法独立证明安全
    -- 统一按 high_risk_blocked 处理
    -- 未来放行需逐项证明：该商品无本地先变化路径 OR 服务端可独立校验库存
    return false, "high_risk_blocked"
end

--- 获取安全类商品 ID 列表（用于测试和报告）
--- BM-S3R: 始终返回空列表
---@return string[]
function M.GetSafeItemIds()
    local result = {}
    for _, id in ipairs(BMConfig.ITEM_IDS) do
        local allowed = M.CheckSellAllowed(id)
        if allowed then
            result[#result + 1] = id
        end
    end
    return result
end

--- 获取高风险类商品 ID 列表（用于测试和报告）
--- BM-S3R: 返回全部 79 项
---@return string[]
function M.GetHighRiskItemIds()
    local result = {}
    for _, id in ipairs(BMConfig.ITEM_IDS) do
        local allowed = M.CheckSellAllowed(id)
        if not allowed then
            result[#result + 1] = id
        end
    end
    return result
end

return M
