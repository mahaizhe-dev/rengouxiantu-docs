-- ============================================================================
-- XianyuanChestSystem.lua — 仙缘宝箱客户端系统
--
-- 职责：
--   1. 管理 openedXianyuanChests 状态（序列化/反序列化）
--   2. 客户端读条逻辑（3 秒计时 → 发 CompleteOpen）
--   3. 距离检测（交互半径 1.5 瓦片）
--   4. 与服务端的协议交互（订阅 S2C 事件、发送 C2S 事件）
--   5. 渲染缓存失效通知
--
-- 设计文档：docs/仙缘宝箱.md v2.0
-- ============================================================================

local GameState    = require("core.GameState")
local SaveProtocol = require("network.SaveProtocol")
local XCConfig     = require("config.XianyuanChestConfig")
local SaveState    = require("systems.save.SaveState")

local cjson = cjson ---@diagnostic disable-line: undefined-global

--- 将可能带字符串键的数组归一化为整数键数组（防御 JSON 往返键类型变化）
---@param t table|nil
---@return table
local function NormalizeArray(t)
    if not t then return {} end
    if #t > 0 then return t end
    local result = {}
    local i = 1
    while true do
        local v = t[tostring(i)]
        if v == nil then break end
        result[i] = v
        i = i + 1
    end
    return #result > 0 and result or t
end

local XianyuanChestSystem = {}

-- ============================================================================
-- 状态
-- ============================================================================

-- 已开启的宝箱集合 { [chestId] = true }
XianyuanChestSystem.openedChests = {}

-- 读条状态
XianyuanChestSystem._channeling = false
XianyuanChestSystem._channelTimer = 0
XianyuanChestSystem._channelChestId = nil

-- 待选奖励（CompleteOpen 后收到的 3 件装备）
XianyuanChestSystem._pendingReward = nil  -- { chestId, items }

-- 等待 StartResult 的 chestId（TryStartOpen 时设置，收到回复后清除）
XianyuanChestSystem._pendingStartChestId = nil

-- 渲染缓存脏标记
XianyuanChestSystem._renderDirty = true

-- 是否已初始化（订阅事件）
XianyuanChestSystem._initialized = false

-- ============================================================================
-- 初始化
-- ============================================================================

function XianyuanChestSystem.Init()
    if XianyuanChestSystem._initialized then return end
    XianyuanChestSystem._initialized = true

    -- 订阅 S2C 事件
    SubscribeToEvent(SaveProtocol.S2C_XianyuanChest_StartResult,
        "XianyuanChest_HandleStartResult")
    SubscribeToEvent(SaveProtocol.S2C_XianyuanChest_Reward,
        "XianyuanChest_HandleReward")
    SubscribeToEvent(SaveProtocol.S2C_XianyuanChest_PickResult,
        "XianyuanChest_HandlePickResult")

    print("[XianyuanChestSystem] Initialized, subscribed to S2C events")
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 判断宝箱是否已开启
---@param chestId string
---@return boolean
function XianyuanChestSystem.IsOpened(chestId)
    return XianyuanChestSystem.openedChests[chestId] == true
end

--- 获取宝箱配置
---@param chestId string
---@return table|nil
function XianyuanChestSystem.GetChestConfig(chestId)
    return XCConfig.CHESTS[chestId]
end

--- 找到玩家附近的宝箱（未开启、在交互范围内）
---@param px number 玩家 x 瓦片坐标
---@param py number 玩家 y 瓦片坐标
---@param chapter number|nil 当前章节（仅检查该章宝箱），nil 则检查全部
---@return string|nil chestId, table|nil chestConfig
function XianyuanChestSystem.FindNearby(px, py, chapter)
    local range = XCConfig.INTERACT_RANGE
    local rangeSq = range * range

    for chestId, cfg in pairs(XCConfig.CHESTS) do
        -- 跳过不在当前章节的宝箱
        if chapter and cfg.chapter ~= chapter then
            goto continue
        end
        -- 跳过已开启的宝箱
        if XianyuanChestSystem.openedChests[chestId] then
            goto continue
        end
        -- 宝箱坐标（稍后由用户补充到配置表）
        if cfg.x and cfg.y then
            local dx = px - cfg.x
            local dy = py - cfg.y
            if dx * dx + dy * dy <= rangeSq then
                return chestId, cfg
            end
        end
        ::continue::
    end
    return nil, nil
end

--- 获取当前章节所有宝箱的状态列表（用于渲染）
---@param chapter number
---@return table[] { chestId, cfg, opened }
function XianyuanChestSystem.GetChestsForChapter(chapter)
    local result = {}
    for chestId, cfg in pairs(XCConfig.CHESTS) do
        if cfg.chapter == chapter then
            result[#result + 1] = {
                chestId = chestId,
                cfg = cfg,
                opened = XianyuanChestSystem.openedChests[chestId] == true,
            }
        end
    end
    return result
end

--- 渲染缓存是否脏
---@return boolean
function XianyuanChestSystem.IsRenderDirty()
    return XianyuanChestSystem._renderDirty
end

--- 清除渲染脏标记
function XianyuanChestSystem.ClearRenderDirty()
    XianyuanChestSystem._renderDirty = false
end

--- 标记渲染缓存脏
function XianyuanChestSystem.InvalidateRenderCache()
    XianyuanChestSystem._renderDirty = true
end

-- ============================================================================
-- 读条交互
-- ============================================================================

--- 尝试开始解封宝箱（发送 C2S_StartOpen）
--- 先触发存档同步，确保服务端读到最新装备数据后再发请求
---@param chestId string
---@return boolean sent 是否发送了请求
function XianyuanChestSystem.TryStartOpen(chestId)
    -- 已在读条中，取消
    if XianyuanChestSystem._channeling then
        XianyuanChestSystem.CancelChannel()
        return false
    end

    -- 已有待选奖励 → 直接重新弹出奖励面板（不重新请求服务端）
    if XianyuanChestSystem._pendingReward then
        if XianyuanChestSystem._pendingReward.chestId == chestId then
            if XianyuanChestUI_HandleShowReward then
                XianyuanChestUI_HandleShowReward("XianyuanChest_ShowReward", {
                    chestId = XianyuanChestSystem._pendingReward.chestId,
                    items = XianyuanChestSystem._pendingReward.items,
                })
            end
            return true
        end
        -- 不同宝箱，不允许同时打开两个
        return false
    end

    local cfg = XCConfig.CHESTS[chestId]
    if not cfg then return false end

    -- 已开启
    if XianyuanChestSystem.openedChests[chestId] then
        return false
    end

    -- 缓存待确认 chestId（StartResult 中使用）
    XianyuanChestSystem._pendingStartChestId = chestId

    -- 获取面板实时属性值，随请求发送给服务端
    local currentAttrValue = 0
    local player = GameState.player
    if player then
        local getter = XCConfig.ATTR_GETTERS[cfg.attr]
        if getter and player[getter] then
            currentAttrValue = player[getter](player)
        end
    end

    local data = VariantMap()
    data["chestId"] = Variant(chestId)
    data["current"] = Variant(currentAttrValue)
    local conn = network:GetServerConnection()
    if conn then
        conn:SendRemoteEvent(
            SaveProtocol.C2S_XianyuanChest_StartOpen, true, data)
        print("[XianyuanChestSystem] Sent StartOpen: " .. chestId
            .. " current=" .. currentAttrValue)
    else
        print("[XianyuanChestSystem] StartOpen: no server connection")
        XianyuanChestSystem._pendingStartChestId = nil
    end

    return true
end

--- 取消读条
function XianyuanChestSystem.CancelChannel()
    if not XianyuanChestSystem._channeling then return end

    local chestId = XianyuanChestSystem._channelChestId or ""

    XianyuanChestSystem._channeling = false
    XianyuanChestSystem._channelTimer = 0
    XianyuanChestSystem._channelChestId = nil

    -- 通知服务端
    if chestId ~= "" then
        local data = VariantMap()
        data["chestId"] = Variant(chestId)
        local conn = network:GetServerConnection()
        if conn then
            conn:SendRemoteEvent(
                SaveProtocol.C2S_XianyuanChest_CancelOpen, true, data)
        end
    end

    print("[XianyuanChestSystem] CancelChannel: " .. chestId)
end

--- 获取读条进度 0~1，未读条返回 nil
---@return number|nil progress, string|nil chestId
function XianyuanChestSystem.GetChannelProgress()
    if not XianyuanChestSystem._channeling then return nil, nil end
    local progress = XianyuanChestSystem._channelTimer / XCConfig.CHANNEL_DURATION
    return math.min(progress, 1.0), XianyuanChestSystem._channelChestId
end

--- 是否正在读条
---@return boolean
function XianyuanChestSystem.IsChanneling()
    return XianyuanChestSystem._channeling
end

--- 选择奖励（1/2/3）
---@param pickIndex number
function XianyuanChestSystem.PickReward(pickIndex)
    if not XianyuanChestSystem._pendingReward then return end

    local data = VariantMap()
    data["chestId"] = Variant(XianyuanChestSystem._pendingReward.chestId)
    data["pickIndex"] = Variant(pickIndex)
    local conn = network:GetServerConnection()
    if conn then
        conn:SendRemoteEvent(
            SaveProtocol.C2S_XianyuanChest_Pick, true, data)
    end
    print("[XianyuanChestSystem] Sent Pick: index=" .. pickIndex)
end

--- 获取待选奖励（3 件装备），nil 表示无待选
---@return table|nil { chestId, items }
function XianyuanChestSystem.GetPendingReward()
    return XianyuanChestSystem._pendingReward
end

--- 清除待选奖励
function XianyuanChestSystem.ClearPendingReward()
    XianyuanChestSystem._pendingReward = nil
end

-- ============================================================================
-- S2C 事件处理
-- ============================================================================

--- 处理 StartResult（服务端校验结果）
function XianyuanChestSystem._HandleStartResult(eventData)
    local ok = false
    pcall(function() ok = eventData["ok"]:GetBool() end)

    if ok then
        -- 校验通过，开始客户端读条
        XianyuanChestSystem._channelChestId = XianyuanChestSystem._pendingStartChestId
        XianyuanChestSystem._pendingStartChestId = nil
        XianyuanChestSystem._channeling = true
        XianyuanChestSystem._channelTimer = 0
        print("[XianyuanChestSystem] StartResult OK, begin channeling chest="
            .. tostring(XianyuanChestSystem._channelChestId))
    else
        local failedChestId = XianyuanChestSystem._pendingStartChestId
        XianyuanChestSystem._pendingStartChestId = nil

        local reason = ""
        pcall(function() reason = eventData["reason"]:GetString() end)
        print("[XianyuanChestSystem] StartResult FAILED: " .. reason)

        -- 通过事件通知 UI 显示失败原因
        local attr = ""
        local req = 0
        local current = 0
        pcall(function() attr = eventData["attr"]:GetString() end)
        pcall(function() req = eventData["req"]:GetInt() end)
        pcall(function() current = eventData["current"]:GetInt() end)

        -- 直接调用全局事件处理函数（避免 SendEvent 需要 VariantMap）
        if XianyuanChestUI_HandleOpenFailed then
            XianyuanChestUI_HandleOpenFailed("XianyuanChest_OpenFailed", {
                chestId = failedChestId,
                reason = reason,
                attr = attr,
                req = req,
                current = current,
            })
        end
    end
end

--- 处理 Reward（3 选 1 奖励下发）
function XianyuanChestSystem._HandleReward(eventData)
    local ok = false
    pcall(function() ok = eventData["ok"]:GetBool() end)

    if not ok then
        local reason = ""
        pcall(function() reason = eventData["reason"]:GetString() end)
        print("[XianyuanChestSystem] Reward FAILED: " .. reason)
        return
    end

    local chestId = ""
    local itemsJson = ""
    pcall(function() chestId = eventData["chestId"]:GetString() end)
    pcall(function() itemsJson = eventData["items"]:GetString() end)

    local items = {}
    pcall(function() items = cjson.decode(itemsJson) end)

    -- 防御 JSON 往返后数组键变字符串
    items = NormalizeArray(items)
    for _, eq in ipairs(items) do
        if eq.subStats then
            eq.subStats = NormalizeArray(eq.subStats)
        end
    end

    if #items < 3 then
        print("[XianyuanChestSystem] Reward: invalid items count=" .. #items)
        return
    end

    -- 不在此处标记已开启，仅在 Pick 成功后标记
    -- 缓存待选奖励
    XianyuanChestSystem._pendingReward = {
        chestId = chestId,
        items = items,
    }

    -- 同步更新透传缓存（防止客户端自动存档覆盖服务端写入的数据）
    local SS = require("systems.save.SaveState")
    if not SS._pendingXianyuanRewards then
        SS._pendingXianyuanRewards = {}
    end
    SS._pendingXianyuanRewards[chestId] = items

    -- 直接调用全局事件处理函数（避免 SendEvent 需要 VariantMap）
    if XianyuanChestUI_HandleShowReward then
        XianyuanChestUI_HandleShowReward("XianyuanChest_ShowReward", {
            chestId = chestId,
            items = items,
        })
    end

    print("[XianyuanChestSystem] Reward received: chest=" .. chestId
        .. " items=" .. #items)
end

--- 处理 PickResult（选择奖励结果）
function XianyuanChestSystem._HandlePickResult(eventData)
    local ok = false
    pcall(function() ok = eventData["ok"]:GetBool() end)

    if ok then
        local equipJson = ""
        pcall(function() equipJson = eventData["equipment"]:GetString() end)
        local equipment = {}
        pcall(function() equipment = cjson.decode(equipJson) end)

        -- 防御 JSON 往返后 subStats 数组键变字符串
        if equipment and equipment.subStats then
            equipment.subStats = NormalizeArray(equipment.subStats)
        end

        -- 标记本地已开启（只有选取成功才算真正打开）
        local pendingChestId = XianyuanChestSystem._pendingReward
            and XianyuanChestSystem._pendingReward.chestId
        if pendingChestId then
            XianyuanChestSystem.openedChests[pendingChestId] = true
            XianyuanChestSystem.InvalidateRenderCache()
        end

        -- 清除待选奖励
        XianyuanChestSystem._pendingReward = nil

        -- 同步清除透传缓存
        local SS = require("systems.save.SaveState")
        if SS._pendingXianyuanRewards and pendingChestId then
            SS._pendingXianyuanRewards[pendingChestId] = nil
        end

        -- 将装备放入客户端背包
        local InventorySystem = require("systems.InventorySystem")
        if equipment and equipment.name then
            local addOk = InventorySystem.AddItem(equipment)
            if addOk then
                print("[XianyuanChestSystem] Equipment added to backpack: " .. (equipment.name or "?"))
            else
                print("[XianyuanChestSystem] WARNING: Failed to add equipment to backpack (full?)")
            end
        end

        -- 直接调用全局事件处理函数（避免 SendEvent 需要 VariantMap）
        if XianyuanChestUI_HandlePickSuccess then
            XianyuanChestUI_HandlePickSuccess("XianyuanChest_PickSuccess", {
                equipment = equipment,
            })
        end

        print("[XianyuanChestSystem] PickResult OK: " .. (equipment.name or "?")
            .. " slot=" .. (equipment.slot or "?") .. " quality=" .. (equipment.quality or "?"))
    else
        local reason = ""
        pcall(function() reason = eventData["reason"]:GetString() end)
        print("[XianyuanChestSystem] PickResult FAILED: " .. reason)

        -- 直接调用全局事件处理函数（避免 SendEvent 需要 VariantMap）
        if XianyuanChestUI_HandlePickFailed then
            XianyuanChestUI_HandlePickFailed("XianyuanChest_PickFailed", {
                reason = reason,
            })
        end
    end
end

-- ============================================================================
-- 更新（每帧调用）
-- ============================================================================

---@param dt number
function XianyuanChestSystem.Update(dt)
    if not XianyuanChestSystem._channeling then return end

    local player = GameState.player
    local chestId = XianyuanChestSystem._channelChestId

    -- 玩家死亡或不存在 → 取消
    if not player or not player.alive then
        XianyuanChestSystem.CancelChannel()
        return
    end

    -- 检查距离（如果宝箱有坐标）
    if chestId then
        local cfg = XCConfig.CHESTS[chestId]
        if cfg and cfg.x and cfg.y then
            local dx = player.x - cfg.x
            local dy = player.y - cfg.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > XCConfig.INTERACT_RANGE then
                XianyuanChestSystem.CancelChannel()
                return
            end
        end
    end

    -- 推进读条
    XianyuanChestSystem._channelTimer = XianyuanChestSystem._channelTimer + dt
    if XianyuanChestSystem._channelTimer >= XCConfig.CHANNEL_DURATION then
        -- 读条完成 → 发 CompleteOpen
        XianyuanChestSystem._channeling = false
        XianyuanChestSystem._channelTimer = 0

        if chestId then
            -- 获取面板实时属性值，随请求发送给服务端
            local currentAttrValue = 0
            local cfg = XCConfig.CHESTS[chestId]
            if cfg and player then
                local getter = XCConfig.ATTR_GETTERS[cfg.attr]
                if getter and player[getter] then
                    currentAttrValue = player[getter](player)
                end
            end

            local data = VariantMap()
            data["chestId"] = Variant(chestId)
            data["current"] = Variant(currentAttrValue)
            local conn = network:GetServerConnection()
            if conn then
                conn:SendRemoteEvent(
                    SaveProtocol.C2S_XianyuanChest_CompleteOpen, true, data)
            end
            print("[XianyuanChestSystem] Channel complete, sent CompleteOpen: "
                .. chestId .. " current=" .. currentAttrValue)
        end

        XianyuanChestSystem._channelChestId = nil
    end
end

-- ============================================================================
-- 序列化/反序列化
-- ============================================================================

--- 序列化：直接返回 { [chestId]=true, ... }，由 SavePersistence 赋键名
---@return table
function XianyuanChestSystem.Serialize()
    return XianyuanChestSystem.openedChests
end

--- 反序列化：接收 { [chestId]=true, ... } 或 nil
---@param data table|nil  openedXianyuanChests 表（从 saveData.openedXianyuanChests 传入）
function XianyuanChestSystem.Deserialize(data)
    if type(data) == "table" then
        XianyuanChestSystem.openedChests = data
    else
        XianyuanChestSystem.openedChests = {}
    end
    XianyuanChestSystem.InvalidateRenderCache()
    print("[XianyuanChestSystem] Deserialized: " .. XianyuanChestSystem.GetOpenedCount() .. " opened")
end

--- 获取已开启宝箱数量
---@return number
function XianyuanChestSystem.GetOpenedCount()
    local count = 0
    for _ in pairs(XianyuanChestSystem.openedChests) do
        count = count + 1
    end
    return count
end

--- 重置（GM 命令用）
function XianyuanChestSystem.Reset()
    XianyuanChestSystem.openedChests = {}
    XianyuanChestSystem._pendingReward = nil
    XianyuanChestSystem.CancelChannel()
    XianyuanChestSystem.InvalidateRenderCache()
    print("[XianyuanChestSystem] Reset all xianyuan chests")
end

-- ============================================================================
-- 全局事件处理函数（SubscribeToEvent 需要全局函数名）
-- ============================================================================

function XianyuanChest_HandleStartResult(eventType, eventData)
    XianyuanChestSystem._HandleStartResult(eventData)
end

function XianyuanChest_HandleReward(eventType, eventData)
    XianyuanChestSystem._HandleReward(eventData)
end

function XianyuanChest_HandlePickResult(eventType, eventData)
    XianyuanChestSystem._HandlePickResult(eventData)
end

return XianyuanChestSystem
