-- ============================================================================
-- BlackMarketSellGuard.lua — 黑市卖出服务端权威校验（BM-S3 第一阶段）
--
-- 职责：在 HandleSell() 中对商品进行安全分类判定
-- 设计文档：docs/2026-05-13-BM-S3-黑市卖出服务端权威校验第一阶段任务卡.md
--
-- 原则："宁可拒绝，不可误发仙石"
--   - 安全类：无本地消耗路径，沿用现有快照校验
--   - 高风险类：存在本地消耗路径，服务端无法独立证明安全，一律拒卖
--
-- 分类依据：BM-S1 风险矩阵冻结结果
--   安全类（26 项）：碎片(rake/bagua/tiandi) + 龙鳞(dragon_scale_*) + 令牌盒(已 BM-01A 修补)
--   高风险类（53 项）：附灵玉(lingyu) + 金砖(gold_brick) + 草药(herb) + 技能书(skill_book) + 特殊装备(special_equip)
-- ============================================================================

local BMConfig = require("config.BlackMerchantConfig")

local M = {}

-- ============================================================================
-- 安全类 category 白名单
-- 这些分类的商品没有"本地先消耗→延迟落盘→卖旧快照"的攻击路径
-- ============================================================================

local SAFE_CATEGORIES = {
    [BMConfig.CATEGORY_RAKE]    = true,   -- 上宝逊金钯碎片（19 项）
    [BMConfig.CATEGORY_BAGUA]   = true,   -- 文王八卦盘碎片
    [BMConfig.CATEGORY_TIANDI]  = true,   -- 天帝剑痕碎片
}

-- consumable_mat 分类中混合了安全和高风险商品，需要逐 ID 判断
-- 安全：dragon_scale_* (4 项), 令牌盒 (3 项, 已 BM-01A 修补)
-- 高风险：gold_brick (1 项)

local SAFE_CONSUMABLE_MAT_IDS = {
    dragon_scale_ice   = true,
    dragon_scale_abyss = true,
    dragon_scale_fire  = true,
    dragon_scale_sand  = true,
    wubao_token_box    = true,
    sha_hai_ling_box   = true,
    taixu_token_box    = true,
}

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 判断商品是否允许通过服务端卖出校验
--- 安全类返回 true，高风险类返回 false + 原因
---@param itemId string BMConfig.ITEMS 中的商品 ID
---@return boolean allowed 是否允许卖出
---@return string|nil reason 拒绝原因（allowed=false 时有值）
function M.CheckSellAllowed(itemId)
    local cfg = BMConfig.ITEMS[itemId]
    if not cfg then
        return false, "unknown_item"
    end

    local cat = cfg.category

    -- 1. 整分类安全的商品
    if SAFE_CATEGORIES[cat] then
        return true, nil
    end

    -- 2. consumable_mat 分类：逐 ID 判断
    if cat == BMConfig.CATEGORY_CONSUMABLE_MAT then
        if SAFE_CONSUMABLE_MAT_IDS[itemId] then
            return true, nil
        end
        -- gold_brick 等落到高风险
        return false, "high_risk_blocked"
    end

    -- 3. 所有其他分类均为高风险（lingyu / herb / skill_book / special_equip / 未来新增分类）
    --    "默认保守"：新分类自动拒卖，需显式加入安全白名单
    return false, "high_risk_blocked"
end

--- 获取安全类商品 ID 列表（用于测试和报告）
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
