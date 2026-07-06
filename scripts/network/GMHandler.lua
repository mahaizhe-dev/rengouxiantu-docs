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

    if cmd == "wubao_keys_16" or cmd == "wubao_reset_treasure" then
        local slot = Session.connSlots_[connKey]
        local WubaoTreasureHandler = require("network.WubaoTreasureHandler")
        if cmd == "wubao_keys_16" then
            WubaoTreasureHandler.GMGrantKeys16(userId, slot, connection)
        else
            WubaoTreasureHandler.GMResetTreasure(userId, slot, connection, connKey)
        end
        return
    end

    -- §12 黑市收购：异步分支（服务端执行后返回结果）
    if cmd == "bm_recycle" then
        print("[Server][GM] bm_recycle: 开始异步执行")
        local BlackMerchantHandler = require("network.BlackMerchantHandler")
        BlackMerchantHandler.GMExecuteRecycle(function(ok, summary)
            local data = VariantMap()
            data["ok"] = Variant(ok)
            data["cmd"] = Variant("bm_recycle")
            data["msg"] = Variant(summary or "未知结果")
            Session.SafeSend(connection, SaveProtocol.S2C_GMCommandResult, data)
            print("[Server][GM] bm_recycle 完成: " .. tostring(summary))
        end)
        return  -- 不走后续统一响应
    end

    -- 剑气积分GM加点
    if cmd == "add_sw_points" then
        local SWC = require("config.SwordWallConfig")
        local commit = serverCloud:BatchCommit("GM剑气积分+500")
        commit:MoneyAdd(userId, SWC.POINT_KEY, 500)
        commit:Commit({
            ok = function()
                local data = VariantMap()
                data["ok"] = Variant(true)
                data["cmd"] = Variant("add_sw_points")
                data["msg"] = Variant("剑气积分+500")
                Session.SafeSend(connection, SaveProtocol.S2C_GMCommandResult, data)
                print("[Server][GM] add_sw_points OK for userId=" .. tostring(userId))
            end,
            error = function(code, reason)
                local data = VariantMap()
                data["ok"] = Variant(false)
                data["cmd"] = Variant("add_sw_points")
                data["msg"] = Variant("失败: " .. tostring(reason))
                Session.SafeSend(connection, SaveProtocol.S2C_GMCommandResult, data)
            end,
        })
        return
    end

    -- C+: 网络诊断摘要查询
    if cmd == "net_diag_60" or cmd == "net_diag_1440" or cmd == "net_diag_current" then
        local NDH = require("network.NetDiagHandler")
        if cmd == "net_diag_current" then
            -- 返回服务端当前内存桶（不查 serverCloud）
            local data = VariantMap()
            data["ok"] = Variant(true)
            data["cmd"] = Variant(cmd)
            data["msg"] = Variant("诊断数据见日志")
            Session.SafeSend(connection, SaveProtocol.S2C_GMCommandResult, data)
            print("[Server][GM] net_diag_current: (in-memory bucket printed by Tick)")
            return
        end
        local minutes = (cmd == "net_diag_60") and 60 or 1440
        local queryFn = NDH.GetSummary(minutes)
        queryFn(function(sum, err)
            local msg
            if not sum then
                msg = "查询失败: " .. tostring(err)
            else
                local avgRtt = (sum.hbRttCount > 0) and math.floor(sum.hbRttSum / sum.hbRttCount) or 0
                local lossRate = (sum.hbSent > 0) and string.format("%.1f", sum.hbMissed / sum.hbSent * 100) or "0"
                msg = "网络诊断 最近" .. minutes .. "分钟"
                    .. "\n样本: " .. (sum.reports or 0) .. "报告 " .. (sum._buckets or 0) .. "桶"
                    .. "\n心跳: sent=" .. (sum.hbSent or 0) .. " ack=" .. (sum.hbAck or 0)
                    .. " missed=" .. (sum.hbMissed or 0) .. " 丢失率=" .. lossRate .. "%"
                    .. "\nRTT: avg=" .. avgRtt .. "ms max=" .. (sum.hbRttMax or 0) .. "ms"
                    .. "\nShadow: unstable=" .. (sum.shadowUnstable or 0)
                    .. " reconnecting=" .. (sum.shadowReconnecting or 0)
                    .. " disconnected=" .. (sum.shadowDisconnected or 0)
                    .. "\n保存: start=" .. (sum.saveStart or 0) .. " ok=" .. (sum.saveOk or 0)
                    .. " fail=" .. (sum.saveFail or 0) .. " timeout=" .. (sum.saveTimeout or 0)
                    .. " noConn=" .. (sum.saveNoServerConn or 0)
                    .. "\n黑市拦截: wh=" .. (sum.bmSellBlockWarehouse or 0)
                    .. " consume=" .. (sum.bmSellBlockConsume or 0)
                    .. " maxElapsed=" .. (sum.bmSellBlockMaxElapsed or 0) .. "s"
                    .. "\n限流: total=" .. (sum.rateLimitedTotal or 0)
                    .. " bm=" .. (sum.rateLimitedBM or 0) .. " save=" .. (sum.rateLimitedSave or 0)
            end
            local data = VariantMap()
            data["ok"] = Variant(sum ~= nil)
            data["cmd"] = Variant(cmd)
            data["msg"] = Variant(msg)
            Session.SafeSend(connection, SaveProtocol.S2C_GMCommandResult, data)
            print("[Server][GM] " .. cmd .. ": " .. msg)
        end)
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
