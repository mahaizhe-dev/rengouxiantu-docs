-- ============================================================================
-- BlackMerchantTradeLogger.lua — 万界黑商交易记录
--
-- 职责：向 List 域写入交易流水，维护 FIFO 淘汰
--   buy/sell  → SYSTEM_UID + PUBLIC_TRADE_LOG_KEY（公共记录，含玩家名）
--   exchange  → userId   + TRADE_LOG_KEY         （个人记录）
-- 设计文档：docs/设计文档/万界黑商.md §3.4
-- ============================================================================

local BMConfig = require("config.BlackMerchantConfig")

local M = {}

--- FIFO 淘汰：超出上限则删除最旧条目（通用）
--- 按时间戳升序排序后再删除，确保无论 list:Get 返回顺序如何，
--- 始终删除最旧的记录。
---@param uid integer     存储归属 uid
---@param key string      list key
---@param maxRecords integer
local function TrimList(uid, key, maxRecords)
    serverCloud.list:Get(uid, key, {
        ok = function(list)
            if #list > maxRecords then
                -- 按时间戳升序排序，确保最旧的在前面
                table.sort(list, function(a, b)
                    local tA = (a.value and a.value.t) or 0
                    local tB = (b.value and b.value.t) or 0
                    return tA < tB
                end)
                local toDelete = #list - maxRecords
                for i = 1, toDelete do
                    if list[i] and list[i].list_id then
                        serverCloud.list:Delete(list[i].list_id)
                    end
                end
            end
        end,
        error = function(code, reason)
            print("[BlackMerchant][TradeLogger] FIFO trim failed: "
                .. tostring(code) .. " " .. tostring(reason))
        end,
    })
end

--- 写入一条公共交易记录（buy / sell）
---@param playerName string  玩家角色名
---@param action string      "buy" | "sell"
---@param itemId string      商品 ID
---@param amount integer     数量
---@param price integer      单价（仙石）
---@param newXianshi integer 交易后仙石余额
function M.LogPublic(playerName, action, itemId, amount, price, newXianshi)
    local record = {
        t  = os.time(),
        a  = action,
        id = itemId,
        n  = amount,
        p  = price,
        xs = newXianshi,
        pn = playerName,   -- player name
    }
    serverCloud.list:Add(BMConfig.SYSTEM_UID, BMConfig.PUBLIC_TRADE_LOG_KEY, record, {
        error = function(code, reason)
            print("[BlackMerchant][TradeLogger] Public log add failed: "
                .. tostring(code) .. " " .. tostring(reason))
        end,
    })
    TrimList(BMConfig.SYSTEM_UID, BMConfig.PUBLIC_TRADE_LOG_KEY, BMConfig.MAX_TRADE_RECORDS)
end

--- 写入一条个人交易记录（exchange_buy / exchange_sell）
---@param userId integer     玩家 ID
---@param action string      "exchange_buy" | "exchange_sell"
---@param itemId string      "xianshi"
---@param amount integer     数量
---@param price integer      汇率
---@param newXianshi integer 交易后仙石余额
function M.LogPersonal(userId, action, itemId, amount, price, newXianshi)
    local record = {
        t  = os.time(),
        a  = action,
        id = itemId,
        n  = amount,
        p  = price,
        xs = newXianshi,
    }
    serverCloud.list:Add(userId, BMConfig.TRADE_LOG_KEY, record, {
        error = function(code, reason)
            print("[BlackMerchant][TradeLogger] Personal log add failed: "
                .. tostring(code) .. " " .. tostring(reason))
        end,
    })
    TrimList(userId, BMConfig.TRADE_LOG_KEY, BMConfig.MAX_PERSONAL_RECORDS)
end

return M
