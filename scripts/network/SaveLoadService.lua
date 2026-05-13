-- ============================================================================
-- SaveLoadService.lua — LoadGame 服务壳
--
-- R3 等价拆分第一阶段：从 server_main.lua 原位平移 HandleLoadGame 逻辑。
-- 本模块仅负责 LoadGame 主链，不涉及黑市重写。
--
-- ※ 黑市 WAL 补偿（CheckWALOnLogin）在本模块末尾以原始语义调用，
--   但 BlackMerchantHandler 本身不在本次写集内，不做任何修改。
--
-- 变更历史：
--   2026-05-13  R3 创建 — 等价平移，不重写业务
-- ============================================================================

local SaveLoadService = {}

local SaveProtocol      = require("network.SaveProtocol")
local Session           = require("network.ServerSession")
local DungeonConfig     = require("config.DungeonConfig")
local RedeemHandler     = require("network.RedeemHandler")
-- ※ BM-01A 边界冻结：仅 require 以调用 CheckWALOnLogin，不修改该模块
local BlackMerchantHandler = require("network.BlackMerchantHandler")
local Logger            = require("utils.Logger")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

-- ============================================================================
-- 本地工具
-- ============================================================================

local SafeSend = Session.SafeSend

local function SendResult(connection, eventName, success, message)
    local data = VariantMap()
    data["ok"] = Variant(success)
    if message then
        data["message"] = Variant(message)
    end
    SafeSend(connection, eventName, data)
end

-- ============================================================================
-- LoadGame 主入口
--
-- 分区说明（R3 §8.3）：
--   [主存档正文]     save_{slot} / save_data_{slot} / save_bag1/2_{slot} 读取 + v11/v10 合并
--   [账号级旁路]     account_atlas / account_cosmetics 注入到 saveData
--   [过渡代码]       pending_redeem / dungeon_pending 迁移（遗留数据清理）
--   [BM 边界冻结]    CheckWALOnLogin — 异步调用，不阻塞回包，不修改 BM 模块
--
-- ※ 黑市相关（BM handler / WAL / 交易历史 / 兑换 / 自动收购）
--   不在本 service 范围内。CheckWALOnLogin 仅为保持原有调用语义。
-- ============================================================================

--- Execute: 等价于原 HandleLoadGame 函数体
---@param connection userdata    引擎 Connection 对象
---@param connKey   string       连接标识
---@param userId    integer      玩家 userId
---@param slot      integer      槽位号 (1-4)
function SaveLoadService.Execute(connection, connKey, userId, slot)
    print("[Server] LoadGame: userId=" .. tostring(userId) .. " slot=" .. slot)

    -- ── [主存档正文] v11 新 key + v10 旧 key（兼容窗口） ──
    local newSaveKey = "save_" .. slot
    local oldSaveKey = "save_data_" .. slot
    local oldBag1Key = "save_bag1_" .. slot
    local oldBag2Key = "save_bag2_" .. slot

    -- ── [过渡代码] 兑换码 pending + 副本 pending ──
    local pendingKey = "pending_redeem_s" .. slot
    local dungeonPendingKey = DungeonConfig.MakePendingKey(nil, slot)
    local oldDungeonPendingKey = "dungeon_pending_reward_" .. slot

    serverCloud:BatchGet(userId)
        :Key(newSaveKey)
        :Key(oldSaveKey)
        :Key(oldBag1Key)
        :Key(oldBag2Key)
        :Key("account_atlas")
        :Key("account_cosmetics")
        :Key(pendingKey)
        :Key(dungeonPendingKey)
        :Key(oldDungeonPendingKey)
        :Fetch({
            ok = function(scores)
                -- ── [主存档正文] v11 优先，v10 fallback ──
                local saveData = nil
                local newData = scores[newSaveKey]
                local oldData = scores[oldSaveKey]

                if newData and type(newData) == "table" then
                    saveData = newData
                elseif oldData and type(oldData) == "table" then
                    saveData = oldData
                    local backpack = {}
                    local b1 = scores[oldBag1Key]
                    local b2 = scores[oldBag2Key]
                    if b1 and type(b1) == "table" then
                        for k, v in pairs(b1) do backpack[k] = v end
                    end
                    if b2 and type(b2) == "table" then
                        for k, v in pairs(b2) do backpack[k] = v end
                    end
                    saveData.backpack = backpack
                end

                if not saveData then
                    print("[Server] LoadGame: save data missing for slot " .. slot
                        .. " userId=" .. tostring(userId))
                    SendResult(connection, SaveProtocol.S2C_LoadResult, false, "存档数据丢失")
                    return
                end

                -- ── [账号级旁路] account_atlas 注入 ──
                local accountAtlas = scores["account_atlas"]
                if accountAtlas and type(accountAtlas) == "table" then
                    saveData.atlas = accountAtlas
                    print("[Server] LoadGame: account_atlas applied for userId=" .. tostring(userId))
                end

                -- ── [账号级旁路] account_cosmetics 注入 ──
                local accountCosmetics = scores["account_cosmetics"]
                if accountCosmetics and type(accountCosmetics) == "table" then
                    saveData.accountCosmetics = accountCosmetics
                    print("[Server] LoadGame: account_cosmetics applied for userId=" .. tostring(userId))
                end

                -- ── [过渡代码] 旧版 pending 兑换码奖励恢复 ──
                local pendingRedeem = scores[pendingKey]
                if pendingRedeem and type(pendingRedeem) == "table" and pendingRedeem.rewards then
                    local pendingCode = pendingRedeem.code
                    print("[Server] LoadGame: found pending redeem rewards for userId="
                        .. tostring(userId) .. " slot=" .. slot
                        .. " code=" .. tostring(pendingCode))
                    local applied = RedeemHandler.ServerApplyRedeemRewards(saveData, pendingRedeem.rewards, pendingCode)
                    if applied then
                        saveData.timestamp = os.time()
                        print("[Server] LoadGame: rewards applied for code=" .. tostring(pendingCode))
                    else
                        print("[Server] LoadGame: rewards SKIPPED (already in save) for code=" .. tostring(pendingCode))
                    end
                    serverCloud:BatchSet(userId)
                        :Set(newSaveKey, saveData)
                        :Delete(pendingKey)
                        :Save("恢复兑换码奖励到存档", {
                            ok = function()
                                print("[Server] LoadGame: pending redeem cleared for userId="
                                    .. tostring(userId) .. " slot=" .. slot
                                    .. " applied=" .. tostring(applied))
                            end,
                            error = function(errCode, reason)
                                print("[Server] LoadGame: WARNING pending redeem merge FAILED: " .. tostring(reason))
                            end,
                        })
                end

                -- ── [过渡代码] 旧格式副本 pending key 迁移 ──
                local oldDungeonPending = scores[oldDungeonPendingKey]
                if oldDungeonPending and type(oldDungeonPending) == "table" and oldDungeonPending.lingYun then
                    local newDungeonPending = scores[dungeonPendingKey]
                    if not newDungeonPending or type(newDungeonPending) ~= "table" then
                        serverCloud:BatchSet(userId)
                            :Set(dungeonPendingKey, oldDungeonPending)
                            :Delete(oldDungeonPendingKey)
                            :Save("迁移副本pending到新key格式", {
                                ok = function()
                                    print("[Server] LoadGame: migrated dungeon pending to new key for userId="
                                        .. tostring(userId) .. " slot=" .. slot)
                                end,
                                error = function(errCode, reason)
                                    print("[Server] LoadGame: WARNING dungeon pending migration FAILED: " .. tostring(reason))
                                end,
                            })
                    else
                        serverCloud:Delete(userId, oldDungeonPendingKey, {
                            ok = function()
                                print("[Server] LoadGame: old dungeon pending key deleted (new key already exists)")
                            end,
                            error = function() end,
                        })
                    end
                end

                -- ── [回包] 发送存档数据（v11 单 key 格式） ──
                local resultData = VariantMap()
                resultData["ok"] = Variant(true)
                resultData["slot"] = Variant(slot)
                resultData["saveData"] = Variant(cjson.encode(saveData))
                SafeSend(connection, SaveProtocol.S2C_LoadResult, resultData)

                print("[Server] LoadGame sent: userId=" .. tostring(userId) .. " slot=" .. slot)

                -- ── [BM 边界冻结] WAL 补偿检查（异步，不阻塞回包） ──
                -- ※ 此调用保持原有语义，不修改 BlackMerchantHandler 模块
                BlackMerchantHandler.CheckWALOnLogin(userId, slot, saveData)
            end,
            error = function(code, reason)
                print("[Server] LoadGame ERROR: " .. tostring(code) .. " " .. tostring(reason))
                SendResult(connection, SaveProtocol.S2C_LoadResult, false, tostring(reason))
            end,
        })
end

return SaveLoadService
