-- ============================================================================
-- XianyuanChestHandler.lua — 仙缘宝箱服务端 Handler
--
-- 职责：StartOpen / CancelOpen / CompleteOpen / Pick 四个 C2S 处理
-- 设计文档：docs/仙缘宝箱.md v2.0 §7.6 / §7.7
-- ============================================================================

local Session      = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local XCConfig     = require("config.XianyuanChestConfig")
local LootSystem   = require("systems.LootSystem")
local BackpackUtils = require("network.BackpackUtils")

local M = {}

-- ============================================================================
-- 内存状态（运行时，不持久化）
-- ============================================================================

-- connKey -> chestId（当前正在读条的宝箱）
local openingChest_ = {}

-- connKey -> { chestId = string, items = table[] }（CompleteOpen 后待 Pick 的奖励）
local pendingReward_ = {}

-- connKey -> true（防并发锁）
local chestActive_ = {}

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 将 JSON 反序列化后可能带字符串键的数组归一化为整数键数组
--- serverCloud 往返后 {"1":x,"2":y,"3":z} → Lua {["1"]=x,["2"]=y,["3"]=z}
--- Lua # 运算符对此返回 0，需要转换回 {[1]=x,[2]=y,[3]=z}
---@param t table|nil
---@return table
local function NormalizeArray(t)
    if not t then return {} end
    -- 先检查是否已经是正常数组（#t > 0）
    if #t > 0 then return t end
    -- 尝试按字符串键 "1","2",... 重建整数键数组
    local result = {}
    local i = 1
    while true do
        local v = t[tostring(i)]
        if v == nil then break end
        result[i] = v
        i = i + 1
    end
    if #result > 0 then
        return result
    end
    -- 无法归一化，原样返回
    return t
end

--- 从 eventData 提取 connKey + userId + connection
---@return string|nil connKey
---@return integer|nil userId
---@return any connection
local function ExtractContext(eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = Session.ConnKey(connection)
    local userId = Session.GetUserId(connKey)
    if not userId then
        return nil, nil, connection
    end
    if not Session.connSlots_[connKey] then
        return nil, nil, connection
    end
    return connKey, userId, connection
end

--- 发送错误响应
---@param connection any
---@param eventName string
---@param reason string
local function SendError(connection, eventName, reason)
    local data = VariantMap()
    data["ok"] = Variant(false)
    data["reason"] = Variant(reason or "unknown")
    Session.SafeSend(connection, eventName, data)
end

--- 将修改后的存档回写到 serverCloud
---@param userId integer
---@param slot number
---@param saveData table
---@param desc string
local function WriteSaveBack(userId, slot, saveData, desc)
    local saveKey = "save_" .. slot
    saveData.timestamp = os.time()
    serverCloud:BatchSet(userId)
        :Set(saveKey, saveData)
        :Save(desc, {
            ok = function()
                print("[XianyuanChest] SaveBack OK: " .. desc)
            end,
            error = function(code, reason)
                print("[XianyuanChest] SaveBack FAILED: " .. desc
                    .. " code=" .. tostring(code) .. " " .. tostring(reason))
            end,
        })
end

-- ============================================================================
-- HandleStartOpen — 请求开始解封
-- C2S: { chestId, current }
-- S2C: { ok, reason?, attr, req, current }
-- ============================================================================

function M.HandleStartOpen(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    -- 防并发
    if chestActive_[connKey] then
        SendError(connection, SaveProtocol.S2C_XianyuanChest_StartResult, "操作进行中")
        return
    end
    chestActive_[connKey] = true

    -- 读取 chestId 和客户端面板属性值
    local chestId = ""
    local clientCurrent = 0
    pcall(function() chestId = eventData["chestId"]:GetString() end)
    pcall(function() clientCurrent = eventData["current"]:GetInt() end)
    if chestId == "" then
        chestActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_XianyuanChest_StartResult, "参数错误")
        return
    end

    -- 校验 chestId 合法
    local cfg = XCConfig.CHESTS[chestId]
    if not cfg then
        chestActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_XianyuanChest_StartResult, "宝箱不存在")
        return
    end

    -- 读取存档（检查是否已开启）
    local slot = Session.connSlots_[connKey]
    Session.ServerGetSlotData(userId, slot, function(saveData)
        chestActive_[connKey] = nil

        if not saveData or not saveData.player then
            SendError(connection, SaveProtocol.S2C_XianyuanChest_StartResult, "存档异常")
            return
        end

        -- 检查是否已开启
        local opened = saveData.openedXianyuanChests or {}
        if opened[chestId] then
            SendError(connection, SaveProtocol.S2C_XianyuanChest_StartResult, "已开启")
            return
        end

        -- 使用客户端发来的面板实时属性值
        local current = clientCurrent
        local attrName = XCConfig.ATTR_NAMES[cfg.attr] or cfg.attr

        print("[XianyuanChest] AttrCheck: " .. attrName .. " current=" .. current .. " req=" .. cfg.req)

        -- 检查属性门槛
        if current < cfg.req then
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["reason"] = Variant("attr_not_enough")
            data["attr"] = Variant(cfg.attr)
            data["req"] = Variant(cfg.req)
            data["current"] = Variant(current)
            Session.SafeSend(connection, SaveProtocol.S2C_XianyuanChest_StartResult, data)
            return
        end

        -- 达标 → 标记正在开启
        openingChest_[connKey] = chestId

        local data = VariantMap()
        data["ok"] = Variant(true)
        data["attr"] = Variant(attrName)
        data["req"] = Variant(cfg.req)
        data["current"] = Variant(current)
        Session.SafeSend(connection, SaveProtocol.S2C_XianyuanChest_StartResult, data)

        print("[XianyuanChest] StartOpen OK: user=" .. tostring(userId)
            .. " chest=" .. chestId .. " " .. attrName .. "=" .. current .. ">=" .. cfg.req)
    end)
end

-- ============================================================================
-- HandleCancelOpen — 取消读条
-- C2S: { chestId }
-- 无返回（静默处理）
-- ============================================================================

function M.HandleCancelOpen(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    local chestId = ""
    pcall(function() chestId = eventData["chestId"]:GetString() end)

    if openingChest_[connKey] == chestId or chestId == "" then
        openingChest_[connKey] = nil
        print("[XianyuanChest] CancelOpen: user=" .. tostring(userId) .. " chest=" .. chestId)
    end
end

-- ============================================================================
-- HandleCompleteOpen — 读条完成
-- C2S: { chestId, current }
-- S2C: { chestId, items (JSON) }
-- ============================================================================

function M.HandleCompleteOpen(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    -- 防并发
    if chestActive_[connKey] then
        SendError(connection, SaveProtocol.S2C_XianyuanChest_Reward, "操作进行中")
        return
    end
    chestActive_[connKey] = true

    local chestId = ""
    local clientCurrent = 0
    pcall(function() chestId = eventData["chestId"]:GetString() end)
    pcall(function() clientCurrent = eventData["current"]:GetInt() end)

    -- 校验 openingChestId 一致
    if openingChest_[connKey] ~= chestId then
        chestActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_XianyuanChest_Reward, "读条状态异常")
        return
    end

    local cfg = XCConfig.CHESTS[chestId]
    if not cfg then
        chestActive_[connKey] = nil
        openingChest_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_XianyuanChest_Reward, "宝箱不存在")
        return
    end

    -- 再次读取存档校验
    local slot = Session.connSlots_[connKey]
    Session.ServerGetSlotData(userId, slot, function(saveData)
        chestActive_[connKey] = nil
        openingChest_[connKey] = nil

        if not saveData or not saveData.player then
            SendError(connection, SaveProtocol.S2C_XianyuanChest_Reward, "存档异常")
            return
        end

        -- 再次检查是否已开启（防竞态）
        local opened = saveData.openedXianyuanChests or {}
        if opened[chestId] then
            SendError(connection, SaveProtocol.S2C_XianyuanChest_Reward, "已开启")
            return
        end

        -- 再次检查属性门槛（使用客户端面板实时值）
        if clientCurrent < cfg.req then
            SendError(connection, SaveProtocol.S2C_XianyuanChest_Reward, "attr_not_enough")
            return
        end

        -- 检查是否有未领取的持久化待选奖励（上次打开后放弃选择）
        if not saveData.pendingXianyuanRewards then
            saveData.pendingXianyuanRewards = {}
        end
        local pendingItems = saveData.pendingXianyuanRewards[chestId]
        local items
        if pendingItems then
            -- serverCloud JSON 往返后数组键可能变成字符串，归一化为整数键
            pendingItems = NormalizeArray(pendingItems)
            -- 同时归一化每件装备的 subStats 数组
            for _, eq in ipairs(pendingItems) do
                if eq.subStats then
                    eq.subStats = NormalizeArray(eq.subStats)
                end
            end
        end
        if pendingItems and #pendingItems >= 3 then
            -- 复用上次生成的装备（结果固定）
            items = pendingItems
            -- 将归一化后的数据回写到 saveData（修正存档中的字符串键）
            saveData.pendingXianyuanRewards[chestId] = items
            print("[XianyuanChest] Reusing pending rewards for chest=" .. chestId)
        else
            -- 首次打开：生成 3 件候选装备并持久化
            items = LootSystem.GenerateXianyuanReward(cfg.tier, cfg.quality, cfg.attr)
            if not items or #items < 3 then
                SendError(connection, SaveProtocol.S2C_XianyuanChest_Reward, "装备生成失败")
                return
            end
            -- 持久化待选奖励（不标记已开启，仅在 Pick 成功后标记）
            saveData.pendingXianyuanRewards[chestId] = items
            WriteSaveBack(userId, slot, saveData,
                "xianyuan_chest_pending:" .. chestId)
        end

        -- 缓存待选奖励到内存
        pendingReward_[connKey] = {
            chestId = chestId,
            items = items,
        }

        -- 下发奖励
        local cjson = cjson ---@diagnostic disable-line: undefined-global
        local data = VariantMap()
        data["ok"] = Variant(true)
        data["chestId"] = Variant(chestId)
        data["items"] = Variant(cjson.encode(items))
        Session.SafeSend(connection, SaveProtocol.S2C_XianyuanChest_Reward, data)

        print("[XianyuanChest] CompleteOpen OK: user=" .. tostring(userId)
            .. " chest=" .. chestId .. " items=" .. #items)
    end)
end

-- ============================================================================
-- HandlePick — 选择奖励（1/2/3）
-- C2S: { chestId, pickIndex }
-- S2C: { ok, equipment (JSON) }
-- ============================================================================

function M.HandlePick(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not userId then return end

    -- 防并发
    if chestActive_[connKey] then
        SendError(connection, SaveProtocol.S2C_XianyuanChest_PickResult, "操作进行中")
        return
    end
    chestActive_[connKey] = true

    local chestId = ""
    local pickIndex = 0
    pcall(function() chestId = eventData["chestId"]:GetString() end)
    pcall(function() pickIndex = eventData["pickIndex"]:GetInt() end)

    -- 校验 pickIndex 范围
    if pickIndex < 1 or pickIndex > 3 then
        chestActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_XianyuanChest_PickResult, "选择无效")
        return
    end

    -- 校验待选奖励存在
    local pending = pendingReward_[connKey]
    if not pending or pending.chestId ~= chestId then
        chestActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_XianyuanChest_PickResult, "奖励已失效")
        return
    end

    local equipment = pending.items[pickIndex]
    if not equipment then
        chestActive_[connKey] = nil
        SendError(connection, SaveProtocol.S2C_XianyuanChest_PickResult, "装备不存在")
        return
    end

    -- 读取存档，将装备放入背包
    local slot = Session.connSlots_[connKey]
    Session.ServerGetSlotData(userId, slot, function(saveData)
        chestActive_[connKey] = nil

        if not saveData then
            SendError(connection, SaveProtocol.S2C_XianyuanChest_PickResult, "存档异常")
            return
        end

        -- 确保背包存在
        if not saveData.backpack then
            saveData.backpack = {}
        end

        -- 放入背包
        local success = BackpackUtils.AddEquipmentToBackpack(saveData.backpack, equipment)
        if not success then
            SendError(connection, SaveProtocol.S2C_XianyuanChest_PickResult, "背包已满")
            return
        end

        -- 清除内存待选奖励
        pendingReward_[connKey] = nil

        -- 标记宝箱已开启（只有选取成功才算真正打开）
        if not saveData.openedXianyuanChests then
            saveData.openedXianyuanChests = {}
        end
        saveData.openedXianyuanChests[chestId] = true

        -- 清除持久化待选奖励
        if saveData.pendingXianyuanRewards then
            saveData.pendingXianyuanRewards[chestId] = nil
        end

        -- 回写存档
        WriteSaveBack(userId, slot, saveData,
            "xianyuan_chest_pick:" .. chestId .. ":" .. pickIndex)

        -- 返回结果
        local cjson = cjson ---@diagnostic disable-line: undefined-global
        local data = VariantMap()
        data["ok"] = Variant(true)
        data["equipment"] = Variant(cjson.encode(equipment))
        Session.SafeSend(connection, SaveProtocol.S2C_XianyuanChest_PickResult, data)

        print("[XianyuanChest] Pick OK: user=" .. tostring(userId)
            .. " chest=" .. chestId .. " pick=" .. pickIndex
            .. " slot=" .. (equipment.slot or "?") .. " quality=" .. (equipment.quality or "?"))
    end)
end

-- ============================================================================
-- 连接清理（断线时自动清除内存状态）
-- ============================================================================

--- 清除指定连接的所有内存状态
---@param connKey string
function M.CleanupConnection(connKey)
    openingChest_[connKey] = nil
    pendingReward_[connKey] = nil
    chestActive_[connKey] = nil
end

-- ============================================================================
-- 注册所有事件订阅
-- ============================================================================

function M.RegisterAll()
    SubscribeToEvent(SaveProtocol.C2S_XianyuanChest_StartOpen,    "HandleXCStartOpen")
    SubscribeToEvent(SaveProtocol.C2S_XianyuanChest_CancelOpen,   "HandleXCCancelOpen")
    SubscribeToEvent(SaveProtocol.C2S_XianyuanChest_CompleteOpen,  "HandleXCCompleteOpen")
    SubscribeToEvent(SaveProtocol.C2S_XianyuanChest_Pick,          "HandleXCPick")
end

-- 全局事件处理函数（SubscribeToEvent 需要全局函数名）
function HandleXCStartOpen(eventType, eventData)
    M.HandleStartOpen(eventType, eventData)
end

function HandleXCCancelOpen(eventType, eventData)
    M.HandleCancelOpen(eventType, eventData)
end

function HandleXCCompleteOpen(eventType, eventData)
    M.HandleCompleteOpen(eventType, eventData)
end

function HandleXCPick(eventType, eventData)
    M.HandlePick(eventType, eventData)
end

return M
