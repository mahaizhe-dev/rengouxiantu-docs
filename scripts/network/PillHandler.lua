-- ============================================================================
-- PillHandler.lua — 丹药购买 C2S 授权门
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B1）
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")

local M = {}

-- 合法丹药 ID 白名单
local VALID_PILL_IDS = {
    tiger = true,       -- 虎骨丹
    snake = true,       -- 灵蛇丹
    diamond = true,     -- 金刚丹
    tempering = true,   -- 千锤百炼丹
    -- 阵营丹药（中洲炼丹炉）
    ningli_dan = true,   -- 凝力丹
    ningjia_dan = true,  -- 凝甲丹
    ningyuan_dan = true, -- 凝元丹
    ninghun_dan = true,  -- 凝魂丹
    ningxi_dan = true,   -- 凝息丹
}

--- 供基线测试访问
M.VALID_PILL_IDS = VALID_PILL_IDS

function M.HandleBuyPill(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Session.ConnKey(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then return end

    local pillId = eventData["pillId"]:GetString()
    print("[Server][BuyPill] Request: pillId=" .. pillId .. " userId=" .. tostring(userId))

    -- 校验丹药 ID 合法性
    if not VALID_PILL_IDS[pillId] then
        print("[Server][BuyPill] REJECTED: invalid pillId=" .. pillId
            .. " userId=" .. tostring(userId))
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["pillId"] = Variant(pillId)
        data["msg"] = Variant("无效丹药ID")
        Session.SafeSend(connection, SaveProtocol.S2C_BuyPillResult, data)
        return
    end

    -- 校验用户是否有活跃存档（防止未加载存档就购买）
    if not Session.connSlots_[connKey] then
        print("[Server][BuyPill] REJECTED: no active save, userId=" .. tostring(userId))
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["pillId"] = Variant(pillId)
        data["msg"] = Variant("未加载存档")
        Session.SafeSend(connection, SaveProtocol.S2C_BuyPillResult, data)
        return
    end

    -- 授权通过
    print("[Server][BuyPill] AUTHORIZED: pillId=" .. pillId .. " userId=" .. tostring(userId))
    local data = VariantMap()
    data["ok"] = Variant(true)
    data["pillId"] = Variant(pillId)
    data["msg"] = Variant("已授权")
    Session.SafeSend(connection, SaveProtocol.S2C_BuyPillResult, data)
end

return M
