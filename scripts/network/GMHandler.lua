-- ============================================================================
-- GMHandler.lua — GM 管理员命令授权
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B1）
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")

local M = {}

function M.HandleGMCommand(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Session.ConnKey(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then return end

    local cmd = eventData["cmd"]:GetString()
    print("[Server][GM] Command: cmd=" .. cmd .. " userId=" .. tostring(userId))

    -- 权限校验：仅管理员可执行
    if not Session.IsGMAdmin(userId) then
        print("[Server][GM] Command REJECTED: userId=" .. tostring(userId) .. " not admin, cmd=" .. cmd)
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["cmd"] = Variant(cmd)
        data["msg"] = Variant("权限不足：非管理员")
        Session.SafeSend(connection, SaveProtocol.S2C_GMCommandResult, data)
        return
    end

    -- 授权通过，回复客户端执行
    print("[Server][GM] Command AUTHORIZED: cmd=" .. cmd .. " userId=" .. tostring(userId))
    local data = VariantMap()
    data["ok"] = Variant(true)
    data["cmd"] = Variant(cmd)
    data["msg"] = Variant("已授权")
    Session.SafeSend(connection, SaveProtocol.S2C_GMCommandResult, data)
end

return M
