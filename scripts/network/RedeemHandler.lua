-- ============================================================================
-- RedeemHandler.lua — 兑换码系统服务端 Handler
--
-- 职责：ServerApplyRedeemRewards / ConvertRewardsToArray /
--       RegisterRedeemCodesFromConfig / HandleGMCreateCode / HandleRedeemCode
--
-- 来源：从 server_main.lua 提取（§4.5 模块化拆分 B3）
-- ============================================================================

local Session      = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local ConnKey         = Session.ConnKey
local GetUserId       = Session.GetUserId
local SafeSend        = Session.SafeSend
local IsGMAdmin       = Session.IsGMAdmin
local AcquireSlotLock = Session.AcquireSlotLock
local ReleaseSlotLock = Session.ReleaseSlotLock
local connSlots_      = Session.connSlots_

local M = {}

-- ============================================================================
-- 常量
-- ============================================================================

--- 兑换码系统 UID：存储全局兑换码配置
local REDEEM_SYSTEM_UID = 0
M.REDEEM_SYSTEM_UID = REDEEM_SYSTEM_UID

-- ============================================================================
-- ServerApplyRedeemRewards — 兑换码奖励合并到存档（带幂等性检查）
-- ============================================================================

--- 将兑换码奖励合并到存档数据中（服务端执行，无需客户端参与）
--- 服务端将兑换码奖励合并到存档（带幂等性检查，防止重复发放）
---@param saveData table 存档数据
---@param rewards table 奖励列表
---@param code string|nil 兑换码（用于幂等性去重）
---@return boolean applied 是否实际应用了奖励（false=已应用过，跳过）
local function ServerApplyRedeemRewards(saveData, rewards, code)
    if not rewards or type(rewards) ~= "table" then return false end
    local player = saveData.player
    if not player then return false end

    -- ====== 幂等性检查：防止同一兑换码奖励被重复合并 ======
    if code then
        if not saveData.appliedRedeemCodes then
            saveData.appliedRedeemCodes = {}
        end
        if saveData.appliedRedeemCodes[code] then
            print("[Server][RedeemMerge] SKIP duplicate apply for code=" .. code)
            return false
        end
    end

    for _, reward in ipairs(rewards) do
        local rType = reward.type
        local amount = reward.amount or 0

        if rType == "gold" then
            player.gold = (player.gold or 0) + amount
            print("[Server][RedeemMerge] gold +" .. amount)

        elseif rType == "lingYun" then
            player.lingYun = (player.lingYun or 0) + amount
            print("[Server][RedeemMerge] lingYun +" .. amount)

        elseif rType == "title" then
            local titleId = reward.id
            if titleId then
                -- titles 格式: { unlocked = { "id1", "id2", ... }, equipped = "id1", ... }
                if not saveData.titles then
                    saveData.titles = { unlocked = {}, equipped = nil, killStats = {} }
                end
                local unlocked = saveData.titles.unlocked or {}
                -- 检查是否已拥有
                local alreadyHas = false
                for _, id in ipairs(unlocked) do
                    if id == titleId then
                        alreadyHas = true
                        break
                    end
                end
                if not alreadyHas then
                    table.insert(unlocked, titleId)
                    saveData.titles.unlocked = unlocked
                    print("[Server][RedeemMerge] title unlocked: " .. titleId)
                else
                    print("[Server][RedeemMerge] title already owned: " .. titleId)
                end
            end

        elseif rType == "item" then
            local itemId = reward.id
            local count = amount > 0 and amount or 1
            if itemId then
                -- backpack 格式: { "1" = {category, consumableId, count, ...}, "2" = ..., ... }
                local backpack = saveData.backpack or {}
                local MAX_STACK = 9999
                local MAX_SLOTS = require("config.GameConfig").BACKPACK_SIZE or 60

                -- 查找已有相同 consumableId 的堆叠
                local remaining = count
                for i = 1, MAX_SLOTS do
                    local key = tostring(i)
                    local item = backpack[key]
                    if item and item.category == "consumable" and item.consumableId == itemId then
                        local cur = item.count or 1
                        if cur < MAX_STACK then
                            local space = MAX_STACK - cur
                            if remaining <= space then
                                item.count = cur + remaining
                                remaining = 0
                                break
                            else
                                item.count = MAX_STACK
                                remaining = remaining - space
                            end
                        end
                    end
                end

                -- 剩余数量放到空槽位
                while remaining > 0 do
                    local placed = false
                    for i = 1, MAX_SLOTS do
                        local key = tostring(i)
                        if not backpack[key] then
                            local addCount = remaining > MAX_STACK and MAX_STACK or remaining
                            backpack[key] = {
                                category = "consumable",
                                consumableId = itemId,
                                count = addCount,
                                name = reward.name,
                            }
                            remaining = remaining - addCount
                            placed = true
                            break
                        end
                    end
                    if not placed then
                        print("[Server][RedeemMerge] WARNING: backpack full, " .. remaining .. "x " .. itemId .. " lost")
                        break
                    end
                end

                saveData.backpack = backpack
                print("[Server][RedeemMerge] item " .. itemId .. " x" .. count)
            end
        end
    end

    -- ====== 记录已应用的兑换码，防止重复发放 ======
    if code then
        saveData.appliedRedeemCodes[code] = os.time()
    end
    return true
end
M.ServerApplyRedeemRewards = ServerApplyRedeemRewards

-- ============================================================================
-- ConvertRewardsToArray — key-value 奖励格式转数组
-- ============================================================================

--- 将 key-value 奖励格式转为客户端期望的数组格式
--- 输入: { gold = 1000, lingYun = 10, titleId = "pioneer" }
--- 输出: [{ type="gold", amount=1000 }, { type="lingYun", amount=10 }, { type="title", id="pioneer" }]
local function ConvertRewardsToArray(rewards)
    if not rewards or type(rewards) ~= "table" then return {} end
    -- 如果已经是数组格式（第一个元素有 type 字段），直接返回
    if rewards[1] and rewards[1].type then return rewards end

    local result = {}
    for key, value in pairs(rewards) do
        if key == "gold" then
            table.insert(result, { type = "gold", amount = value })
        elseif key == "lingYun" then
            table.insert(result, { type = "lingYun", amount = value })
        elseif key == "titleId" then
            table.insert(result, { type = "title", id = value })
        elseif key == "itemId" then
            -- itemId + itemCount 组合，查找物品显示名
            local itemName = nil
            local okGC, GC = pcall(require, "config.GameConfig")
            if okGC and GC and GC.PET_MATERIALS and GC.PET_MATERIALS[value] then
                itemName = GC.PET_MATERIALS[value].name
            end
            table.insert(result, { type = "item", id = value, name = itemName, amount = rewards.itemCount or 1 })
        elseif key == "itemCount" then
            -- 跳过，已在 itemId 中处理
        else
            table.insert(result, { type = key, amount = value })
        end
    end
    return result
end
M.ConvertRewardsToArray = ConvertRewardsToArray

-- ============================================================================
-- RegisterRedeemCodesFromConfig — 从配置文件注册兑换码
-- ============================================================================

--- 从 RedeemCodes.lua 配置文件注册兑换码
function M.RegisterRedeemCodesFromConfig()
    local ok, RedeemCodes = pcall(require, "config.RedeemCodes")
    if not ok or not RedeemCodes or not RedeemCodes.CODES then
        print("[Server][Redeem] RedeemCodes config not found, skip.")
        return
    end

    local codes = RedeemCodes.CODES
    if #codes == 0 then
        print("[Server][Redeem] No codes configured.")
        return
    end

    print("[Server][Redeem] Registering " .. #codes .. " codes from config...")
    for _, entry in ipairs(codes) do
        local code = entry.code
        if code and code ~= "" then
            local codeKey = "redeem_" .. code
            local codeData = {
                code = code,
                rewards = entry.rewards or {},
                maxUses = entry.maxUses or 0,
                perUser = entry.perUser or 1,
                perType = entry.perType or "account",
                expireTime = entry.expireTime or 0,
                targetUID = entry.targetUID or 0,
                createdBy = "config",
                createdAt = os.time(),
                enabled = true,
            }
            serverCloud:Set(REDEEM_SYSTEM_UID, codeKey, codeData, {
                ok = function()
                    print("[Server][Redeem] Registered: " .. code .. " (" .. (entry.note or "") .. ")")
                end,
                error = function(errCode, reason)
                    print("[Server][Redeem] Failed to register " .. code .. ": " .. tostring(reason))
                end,
            })
        end
    end
end

-- ============================================================================
-- HandleGMCreateCode — GM 创建兑换码（服务端权威）
-- ============================================================================

function M.HandleGMCreateCode(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    -- 权限校验
    if not IsGMAdmin(userId) then
        print("[Server][Redeem] CreateCode REJECTED: userId=" .. tostring(userId) .. " not admin")
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["msg"] = Variant("权限不足：非管理员")
        SafeSend(connection, SaveProtocol.S2C_GMCreateCodeResult, data)
        return
    end

    local code = eventData["code"]:GetString()
    local rewardsJson = eventData["rewards"]:GetString()
    local maxUses = eventData["maxUses"]:GetInt()
    local perUser = eventData["perUser"]:GetInt()
    local expireTime = eventData["expireTime"]:GetInt()
    local targetUID = eventData["targetUID"]:GetInt()  -- 0 = 不限

    if code == "" then
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["msg"] = Variant("兑换码不能为空")
        SafeSend(connection, SaveProtocol.S2C_GMCreateCodeResult, data)
        return
    end

    -- 解析奖励 JSON 校验
    local ok, rewards = pcall(cjson.decode, rewardsJson)
    if not ok or type(rewards) ~= "table" then
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["msg"] = Variant("奖励格式错误")
        SafeSend(connection, SaveProtocol.S2C_GMCreateCodeResult, data)
        return
    end

    local codeKey = "redeem_" .. code
    local codeData = {
        code = code,
        rewards = rewards,
        maxUses = maxUses,       -- 0 = 无限
        perUser = perUser,       -- 每人限用次数（通常 1）
        expireTime = expireTime, -- 0 = 永不过期，否则 os.time() 戳
        targetUID = targetUID,   -- 0 = 不限，>0 = 仅该 UID 可用
        createdBy = userId,
        createdAt = os.time(),
        enabled = true,
    }

    print("[Server][Redeem] Creating code: " .. code .. " by userId=" .. tostring(userId))

    -- 存入 SYSTEM_UID 的 Score
    serverCloud:Set(REDEEM_SYSTEM_UID, codeKey, codeData, {
        ok = function()
            -- 输出结构化文档记录到日志
            local targetText = (targetUID > 0) and ("UID:" .. targetUID) or "全体玩家"
            local rewardParts = {}
            if rewards.gold and rewards.gold > 0 then table.insert(rewardParts, "金币+" .. rewards.gold) end
            if rewards.lingYun and rewards.lingYun > 0 then table.insert(rewardParts, "灵韵+" .. rewards.lingYun) end
            if rewards.titleId and rewards.titleId ~= "" then table.insert(rewardParts, "称号:" .. rewards.titleId) end
            if rewards.itemId and rewards.itemId ~= "" then
                table.insert(rewardParts, rewards.itemId .. "x" .. (rewards.itemCount or 1))
            end
            local rewardText = #rewardParts > 0 and table.concat(rewardParts, ", ") or "无"
            print("========== 兑换码记录 ==========")
            print("兑换码: " .. code)
            print("奖励: " .. rewardText)
            print("目标: " .. targetText)
            print("最大使用次数: " .. (maxUses > 0 and tostring(maxUses) or "无限"))
            print("创建者UID: " .. tostring(userId))
            print("创建时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
            print("================================")

            local data = VariantMap()
            data["ok"] = Variant(true)
            data["code"] = Variant(code)
            data["msg"] = Variant("兑换码创建成功")
            SafeSend(connection, SaveProtocol.S2C_GMCreateCodeResult, data)
        end,
        error = function(errCode, reason)
            print("[Server][Redeem] Create FAILED: " .. tostring(reason))
            local data = VariantMap()
            data["ok"] = Variant(false)
            data["msg"] = Variant("创建失败: " .. tostring(reason))
            SafeSend(connection, SaveProtocol.S2C_GMCreateCodeResult, data)
        end,
    })
end

-- ============================================================================
-- HandleRedeemCode — 玩家兑换码兑换（服务端权威）
-- 核心原则：奖励写进存档才算兑换成功，写入失败 = 没用过 = 可重试
-- ============================================================================

function M.HandleRedeemCode(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = ConnKey(connection)
    local userId = GetUserId(connKey)
    if not userId then return end

    local code = eventData["code"]:GetString()
    if code == "" then
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["msg"] = Variant("请输入兑换码")
        SafeSend(connection, SaveProtocol.S2C_RedeemResult, data)
        return
    end

    local slot = connSlots_[connKey]
    if not slot then
        print("[Server] WARNING: connSlots_ not loaded for connKey=" .. connKey .. ", rejecting")
        return
    end
    local codeKey = "redeem_" .. code

    print("[Server][Redeem] Attempt: code=" .. code .. " userId=" .. tostring(userId) .. " slot=" .. slot)

    -- 发送失败结果的辅助函数
    local function sendFail(msg)
        local data = VariantMap()
        data["ok"] = Variant(false)
        data["msg"] = Variant(msg)
        SafeSend(connection, SaveProtocol.S2C_RedeemResult, data)
    end

    -- Step 1: 读取兑换码配置
    serverCloud:Get(REDEEM_SYSTEM_UID, codeKey, {
        ok = function(scores)
            local codeData = scores[codeKey]
            if not codeData or type(codeData) ~= "table" then
                print("[Server][Redeem] Code not found: " .. code)
                sendFail("兑换码无效")
                return
            end
            if codeData.enabled == false then
                sendFail("兑换码已失效")
                return
            end
            if codeData.expireTime and codeData.expireTime > 0 and os.time() > codeData.expireTime then
                sendFail("兑换码已过期")
                return
            end
            if codeData.targetUID and codeData.targetUID > 0 and userId ~= codeData.targetUID then
                print("[Server][Redeem] UID mismatch: targetUID=" .. tostring(codeData.targetUID) .. " userId=" .. tostring(userId))
                sendFail("该兑换码非你所有")
                return
            end

            -- Step 2: 加 slot 锁（防止与 auto-save 并发写入）
            if not AcquireSlotLock(userId, slot) then
                sendFail("系统繁忙，请稍后重试")
                return
            end

            -- Step 3: 读取存档 + 账号兑换记录
            local saveKey = "save_" .. slot
            local accountRedeemKey = "account_redeemed_codes"
            serverCloud:BatchGet(userId)
                :Key(saveKey)
                :Key(accountRedeemKey)
                :Fetch({
                    ok = function(fetchScores)
                        local saveData = fetchScores[saveKey]
                        if not saveData or type(saveData) ~= "table" or not saveData.player then
                            ReleaseSlotLock(userId, slot)
                            sendFail("请先加载角色")
                            return
                        end

                        local accountRedeemed = fetchScores[accountRedeemKey]
                        if not accountRedeemed or type(accountRedeemed) ~= "table" then
                            accountRedeemed = {}
                        end

                        -- Step 4: 用存档判断是否已兑换（而非 quota）
                        local perType = codeData.perType or "account"
                        local perUser = codeData.perUser or 1
                        local redeemRecordKey = (perType == "character") and (code .. "_s" .. slot) or code
                        local usedCount = accountRedeemed[redeemRecordKey] or 0

                        if usedCount >= perUser then
                            ReleaseSlotLock(userId, slot)
                            local dupMsg = (perType == "character")
                                and "该角色已兑换过此兑换码，不可重复使用"
                                or "该账号已兑换过此兑换码，不可重复使用"
                            sendFail(dupMsg)
                            return
                        end

                        -- Step 5: 奖励写入存档
                        local rewardsArray = ConvertRewardsToArray(codeData.rewards)
                        ServerApplyRedeemRewards(saveData, rewardsArray)
                        accountRedeemed[redeemRecordKey] = usedCount + 1
                        saveData.timestamp = os.time()

                        -- Step 6: 写入存档（成功 = 兑换完成；失败 = 什么都没发生，可重试）
                        local function writeSaveAndNotify(globalQuotaConsumed)
                            serverCloud:BatchSet(userId)
                                :Set(saveKey, saveData)
                                :Set(accountRedeemKey, accountRedeemed)
                                :Save("兑换码奖励写入存档: " .. code, {
                                    ok = function()
                                        ReleaseSlotLock(userId, slot)
                                        -- 全局使用次数计数（best-effort，存档已写入，丢了也不影响玩家）
                                        if codeData.maxUses and codeData.maxUses > 0 and not globalQuotaConsumed then
                                            local gKey = "redeem_global_" .. code
                                            serverCloud.quota:Add(REDEEM_SYSTEM_UID, gKey, 1, codeData.maxUses, "forever", {
                                                ok = function() end,
                                                error = function()
                                                    print("[Server][Redeem] WARNING: global quota count failed (non-critical)")
                                                end,
                                            })
                                        end
                                        -- 通知客户端
                                        local rewardsJson = cjson.encode(rewardsArray)
                                        print("[Server][Redeem] SUCCESS: code=" .. code .. " userId=" .. tostring(userId) .. " slot=" .. slot)
                                        local data = VariantMap()
                                        data["ok"] = Variant(true)
                                        data["code"] = Variant(code)
                                        data["rewards"] = Variant(rewardsJson)
                                        data["msg"] = Variant("兑换成功")
                                        SafeSend(connection, SaveProtocol.S2C_RedeemResult, data)
                                    end,
                                    error = function(errCode, reason)
                                        ReleaseSlotLock(userId, slot)
                                        print("[Server][Redeem] Save FAILED: " .. tostring(reason))
                                        -- 存档写入失败 → 奖励没进存档 → 回滚全局配额 → 玩家可重试
                                        if globalQuotaConsumed then
                                            local gKey = "redeem_global_" .. code
                                            serverCloud.quota:Add(REDEEM_SYSTEM_UID, gKey, -1, codeData.maxUses, "forever", {
                                                ok = function() print("[Server][Redeem] Global quota rolled back") end,
                                                error = function() print("[Server][Redeem] WARNING: Global quota rollback FAILED") end,
                                            })
                                        end
                                        sendFail("服务器错误，请重试")
                                    end,
                                })
                        end

                        -- Step 7: 全局使用次数限制
                        if codeData.maxUses and codeData.maxUses > 0 then
                            local globalQuotaKey = "redeem_global_" .. code
                            serverCloud.quota:Add(REDEEM_SYSTEM_UID, globalQuotaKey, 1, codeData.maxUses, "forever", {
                                ok = function()
                                    writeSaveAndNotify(true)
                                end,
                                error = function()
                                    ReleaseSlotLock(userId, slot)
                                    sendFail("兑换码使用次数已达上限")
                                end,
                            })
                        else
                            writeSaveAndNotify(false)
                        end
                    end,
                    error = function(errCode, reason)
                        ReleaseSlotLock(userId, slot)
                        print("[Server][Redeem] BatchGet save FAILED: " .. tostring(reason))
                        sendFail("服务器错误，请重试")
                    end,
                })
        end,
        error = function(errCode, reason)
            print("[Server][Redeem] Fetch code FAILED: " .. tostring(reason))
            sendFail("服务器错误，请重试")
        end,
    })
end

return M
