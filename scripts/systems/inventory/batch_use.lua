-- ============================================================================
-- inventory/batch_use.lua — 批量使用/出售消耗品
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local TradeLock = require("systems.BlackMarketTradeLock")

local M = {}

--- 批量使用/出售消耗品统一入口
---@param IS table InventorySystem facade
---@param consumableId string 消耗品 ID
---@param count number 使用/出售数量
---@return boolean success, string|nil message, number|nil actualCount
function M.UseBatchConsumable(IS, consumableId, count)
    if not consumableId or not count or count <= 0 then
        return false, "参数错误"
    end

    -- BM-S4A: 使用未锁定数量做库存检查（锁定堆叠不可操作）
    local unlocked = IS.CountUnlockedConsumable(consumableId)
    if unlocked <= 0 then
        -- 如果有锁定的但没有未锁定的，给出保护期提示
        local total = IS.CountConsumable(consumableId)
        if total > 0 then
            return false, TradeLock.LOCK_MESSAGE
        end
        return false, "物品不足"
    end
    -- 夹紧到未锁定拥有量
    count = math.min(count, unlocked)

    -- 查配置（用于 category 判断）
    local cfgData = GameConfig.CONSUMABLES[consumableId]

    if consumableId == "exp_pill" then
        return M._UseBatchExpPill(IS, count)
    elseif consumableId == "exp_pill_superior" then
        return M._UseBatchExpPillSuperior(IS, count)
    elseif consumableId == "exp_pill_supreme" then
        return M._UseBatchExpPillSupreme(IS, count)
    elseif consumableId == "lingyun_fruit" then
        return M._UseBatchLingyunFruit(IS, count)
    elseif consumableId == "lingyun_fruit_superior" then
        return M._UseBatchLingyunFruitSuperior(IS, count)
    elseif consumableId == "xianjie_premium_zong" then
        return M._UseBatchPremiumZong(IS, count)
    elseif consumableId == "valentine_xiangsi_redbean_cake" then
        return M._UseBatchPremiumRedbeanCake(IS, count)
    elseif consumableId == "gold_bar" or consumableId == "gold_brick"
        or (cfgData and cfgData.category == "event") then
        return M._SellBatchConsumable(IS, consumableId, count)
    elseif consumableId == "wubao_token_box" then
        return M._UseTokenBox(IS, consumableId, "wubao_token")
    elseif consumableId == "sha_hai_ling_box" then
        return M._UseTokenBox(IS, consumableId, "sha_hai_ling")
    elseif consumableId == "taixu_token_box" then
        return M._UseTokenBox(IS, consumableId, "taixu_token")
    elseif consumableId == "taixu_jianling_box" then
        return M._UseTokenBox(IS, consumableId, "taixu_jianling")
    elseif consumableId == "zhexian_ling_box" then
        return M._UseTokenBox(IS, consumableId, "zhexian_ling")
    else
        return false, "该物品不支持批量操作"
    end
end

--- 批量使用修炼果（预计算经验上限，一次性扣除+发放）
---@param IS table InventorySystem facade
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function M._UseBatchExpPill(IS, count)
    local player = GameState.player
    if not player then print("[DEBUG _UseBatchExpPill] player is nil"); return false, "玩家不存在" end

    local EXP_PER_PILL = 10000

    -- 计算称号经验加成倍率（与 Player:GainExp 保持一致）
    local expBonus = player.titleExpBonus or 0
    local expMultiplier = 1 + expBonus
    local effectiveExpPerPill = math.floor(EXP_PER_PILL * expMultiplier)

    -- 计算经验上限（境界卡等级时的经验 cap）
    print("[DEBUG _UseBatchExpPill] player.realm=" .. tostring(player.realm) .. " level=" .. tostring(player.level) .. " exp=" .. tostring(player.exp))
    local realmData = GameConfig.REALMS[player.realm]
    if not realmData then print("[DEBUG _UseBatchExpPill] REALMS[" .. tostring(player.realm) .. "] is nil!"); return false, "境界数据异常" end

    local maxLevel = realmData.maxLevel
    local expCap = math.huge  -- 默认无上限

    if player.level >= maxLevel then
        local curLevelExp = GameConfig.EXP_TABLE[player.level] or 0
        local nextLevelExp = GameConfig.EXP_TABLE[player.level + 1]
        if nextLevelExp then
            expCap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
        end
        if player.exp >= expCap then
            return false, "经验已达境界上限，请先突破境界"
        end
    end

    -- 预计算：在 cap 限制下最多能吃多少颗
    -- GainExp 内部会再乘 expMultiplier，所以每颗实际提供 effectiveExpPerPill 点经验
    local maxUsable = count
    if player.level >= maxLevel and expCap ~= math.huge then
        local remainingExp = expCap - player.exp
        if remainingExp <= 0 then
            return false, "经验已达境界上限，请先突破境界"
        end
        local canUse = math.max(1, math.floor(remainingExp / effectiveExpPerPill))
        maxUsable = math.min(count, canUse)
    end

    if maxUsable <= 0 then
        return false, "经验已达境界上限，请先突破境界"
    end

    -- 检查库存并夹紧
    local have = IS.CountConsumable("exp_pill")
    maxUsable = math.min(maxUsable, have)
    if maxUsable <= 0 then return false, "修炼果不足" end

    -- 原子扣除
    local ok = IS.ConsumeConsumable("exp_pill", maxUsable)
    if not ok then return false, "消耗失败" end

    -- 一次性发放经验（GainExp 内部处理升级+cap+expBonus）
    local totalRawExp = EXP_PER_PILL * maxUsable
    player:GainExp(totalRawExp)

    local actualExp = math.floor(totalRawExp * expMultiplier)
    EventBus.Emit("exp_pill_used", actualExp)
    local msg = "使用 " .. maxUsable .. " 颗修炼果，获得 " .. actualExp .. " 经验！"
    print("[InventorySystem] " .. msg)
    return true, msg, maxUsable
end

--- 批量使用灵韵果（一次性扣除+发放）
---@param IS table InventorySystem facade
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function M._UseBatchLingyunFruit(IS, count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local LINGYUN_PER_FRUIT = 50

    -- 夹紧到库存
    local have = IS.CountConsumable("lingyun_fruit")
    count = math.min(count, have)
    if count <= 0 then return false, "灵韵果不足" end

    -- 原子扣除
    local ok = IS.ConsumeConsumable("lingyun_fruit", count)
    if not ok then return false, "消耗失败" end

    -- 一次性发放灵韵（触发事件）
    local totalLingYun = LINGYUN_PER_FRUIT * count
    player:GainLingYun(totalLingYun)

    local msg = "使用 " .. count .. " 颗灵韵果，获得 " .. totalLingYun .. " 灵韵！"
    print("[InventorySystem] " .. msg)
    return true, msg, count
end

--- 批量使用上品修炼果（预计算经验上限，一次性扣除+发放）
---@param IS table InventorySystem facade
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function M._UseBatchExpPillSuperior(IS, count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local EXP_PER_PILL = 100000

    local expBonus = player.titleExpBonus or 0
    local expMultiplier = 1 + expBonus
    local effectiveExpPerPill = math.floor(EXP_PER_PILL * expMultiplier)

    local realmData = GameConfig.REALMS[player.realm]
    if not realmData then return false, "境界数据异常" end

    local maxLevel = realmData.maxLevel
    local expCap = math.huge

    if player.level >= maxLevel then
        local curLevelExp = GameConfig.EXP_TABLE[player.level] or 0
        local nextLevelExp = GameConfig.EXP_TABLE[player.level + 1]
        if nextLevelExp then
            expCap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
        end
        if player.exp >= expCap then
            return false, "经验已达境界上限，请先突破境界"
        end
    end

    local maxUsable = count
    if player.level >= maxLevel and expCap ~= math.huge then
        local remainingExp = expCap - player.exp
        if remainingExp <= 0 then
            return false, "经验已达境界上限，请先突破境界"
        end
        local canUse = math.max(1, math.floor(remainingExp / effectiveExpPerPill))
        maxUsable = math.min(count, canUse)
    end

    if maxUsable <= 0 then
        return false, "经验已达境界上限，请先突破境界"
    end

    local have = IS.CountConsumable("exp_pill_superior")
    maxUsable = math.min(maxUsable, have)
    if maxUsable <= 0 then return false, "上品修炼果不足" end

    local ok = IS.ConsumeConsumable("exp_pill_superior", maxUsable)
    if not ok then return false, "消耗失败" end

    local totalRawExp = EXP_PER_PILL * maxUsable
    player:GainExp(totalRawExp)

    local actualExp = math.floor(totalRawExp * expMultiplier)
    EventBus.Emit("exp_pill_used", actualExp)
    local msg = "使用 " .. maxUsable .. " 颗上品修炼果，获得 " .. actualExp .. " 经验！"
    print("[InventorySystem] " .. msg)
    return true, msg, maxUsable
end

--- 批量使用极品修炼果（预计算经验上限，一次性扣除+发放）
---@param IS table InventorySystem facade
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function M._UseBatchExpPillSupreme(IS, count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local EXP_PER_PILL = 1000000

    local expBonus = player.titleExpBonus or 0
    local expMultiplier = 1 + expBonus
    local effectiveExpPerPill = math.floor(EXP_PER_PILL * expMultiplier)

    local realmData = GameConfig.REALMS[player.realm]
    if not realmData then return false, "境界数据异常" end

    local maxLevel = realmData.maxLevel
    local expCap = math.huge

    if player.level >= maxLevel then
        local curLevelExp = GameConfig.EXP_TABLE[player.level] or 0
        local nextLevelExp = GameConfig.EXP_TABLE[player.level + 1]
        if nextLevelExp then
            expCap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
        end
        if player.exp >= expCap then
            return false, "经验已达境界上限，请先突破境界"
        end
    end

    local maxUsable = count
    if player.level >= maxLevel and expCap ~= math.huge then
        local remainingExp = expCap - player.exp
        if remainingExp <= 0 then
            return false, "经验已达境界上限，请先突破境界"
        end
        local canUse = math.max(1, math.floor(remainingExp / effectiveExpPerPill))
        maxUsable = math.min(count, canUse)
    end

    if maxUsable <= 0 then
        return false, "经验已达境界上限，请先突破境界"
    end

    local have = IS.CountConsumable("exp_pill_supreme")
    maxUsable = math.min(maxUsable, have)
    if maxUsable <= 0 then return false, "极品修炼果不足" end

    local ok = IS.ConsumeConsumable("exp_pill_supreme", maxUsable)
    if not ok then return false, "消耗失败" end

    local totalRawExp = EXP_PER_PILL * maxUsable
    player:GainExp(totalRawExp)

    local actualExp = math.floor(totalRawExp * expMultiplier)
    EventBus.Emit("exp_pill_used", actualExp)
    local msg = "使用 " .. maxUsable .. " 颗极品修炼果，获得 " .. actualExp .. " 经验"
    print("[InventorySystem] " .. msg)
    return true, msg, maxUsable
end

--- 批量使用上品灵韵果（一次性扣除+发放）
---@param IS table InventorySystem facade
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function M._UseBatchLingyunFruitSuperior(IS, count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local LINGYUN_PER_FRUIT = 500

    local have = IS.CountConsumable("lingyun_fruit_superior")
    count = math.min(count, have)
    if count <= 0 then return false, "上品灵韵果不足" end

    local ok = IS.ConsumeConsumable("lingyun_fruit_superior", count)
    if not ok then return false, "消耗失败" end

    local totalLingYun = LINGYUN_PER_FRUIT * count
    player:GainLingYun(totalLingYun)

    local msg = "使用 " .. count .. " 颗上品灵韵果，获得 " .. totalLingYun .. " 灵韵！"
    print("[InventorySystem] " .. msg)
    return true, msg, count
end

--- 批量出售消耗品（金条等纯卖钱物品）
--- 复用 item_sold 事件，保持与 SellItem 兼容
---@param IS table InventorySystem facade
---@param consumableId string
---@param count number 期望出售数量
---@return boolean success, string|nil message, number|nil actualCount
function M._SellBatchConsumable(IS, consumableId, count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    -- 查找配置获取单价和货币类型
    local cfgData = GameConfig.CONSUMABLES[consumableId]
    if not cfgData then return false, "物品配置不存在" end

    local unitPrice = cfgData.sellPrice or 1
    local sellCurrency = cfgData.sellCurrency  -- nil = 金币

    -- BM-S4A: 夹紧到未锁定库存
    local unlocked = IS.CountUnlockedConsumable(consumableId)
    count = math.min(count, unlocked)
    if count <= 0 then return false, "物品不足" end

    -- 原子扣除
    local ok = IS.ConsumeConsumable(consumableId, count)
    if not ok then return false, "消耗失败" end

    -- 发放收益
    local totalPrice = unitPrice * count
    if sellCurrency == "lingYun" then
        player:GainLingYun(totalPrice)
    else
        player:GainGold(totalPrice)
    end

    -- 复用 item_sold 事件（与单件出售兼容）
    EventBus.Emit("item_sold", { name = cfgData.name, consumableId = consumableId, count = count, sellPrice = unitPrice, sellCurrency = sellCurrency }, totalPrice, sellCurrency)
    -- P0: 批量消耗品出售后 MarkDirty 一次
    pcall(function() require("systems.save.SaveSession").MarkDirty() end)

    local currencyName = sellCurrency == "lingYun" and "灵韵" or "金币"
    local msg = "出售 " .. count .. " 个" .. cfgData.name .. "，获得 " .. totalPrice .. " " .. currencyName .. "！"
    print("[InventorySystem] " .. msg)
    return true, msg, count
end

--- 使用令牌盒：原子化消耗1个令牌盒 → 发放100个对应令牌（单次使用，不支持批量）
---@param IS table InventorySystem facade
---@param boxId string   令牌盒消耗品ID（如 "wubao_token_box"）
---@param tokenId string 对应令牌ID（如 "wubao_token"）
---@return boolean success, string|nil message, number|nil actualCount
function M._UseTokenBox(IS, boxId, tokenId)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local TOKEN_PER_BOX = 100

    local boxData = GameConfig.CONSUMABLES[boxId]
    local tokenData = GameConfig.CONSUMABLES[tokenId]
    if not boxData or not tokenData then return false, "物品配置不存在" end

    -- BM-S4A: 检查未锁定库存
    local unlocked = IS.CountUnlockedConsumable(boxId)
    if unlocked <= 0 then
        local total = IS.CountConsumable(boxId)
        if total > 0 then return false, TradeLock.LOCK_MESSAGE end
        return false, boxData.name .. "不足"
    end

    -- 检查背包空间（令牌已有堆叠或有空位）
    local canAdd = IS.CountConsumable(tokenId) > 0 or IS.GetFreeSlots() > 0
    if not canAdd then
        return false, "背包已满，无法使用！"
    end

    -- 原子扣除令牌盒
    local ok = IS.ConsumeConsumable(boxId, 1)
    if not ok then return false, "消耗失败" end

    -- 发放令牌
    IS.AddConsumable(tokenId, TOKEN_PER_BOX)

    local msg = "使用 " .. boxData.name .. "，获得 " .. TOKEN_PER_BOX .. " 个" .. tokenData.name .. "！"
    print("[InventorySystem] " .. msg)
    return true, msg, 1
end

-- ============================================================================
-- 仙界精品粽 — 独立使用分支（端午活动丹药，永久+福缘，上限10）
-- ============================================================================

local PREMIUM_ZONG_MAX = 10  -- 终身食用上限
local PREMIUM_REDBEAN_CAKE_MAX = 10  -- 终身食用上限

--- 批量使用仙界精品粽（每颗永久+1福缘，终身上限10颗）
---@param IS table InventorySystem facade
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function M._UseBatchPremiumZong(IS, count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    -- 已食用数量（权威字段）
    local eaten = player.premiumZongEaten or 0

    -- 检查是否已达上限
    if eaten >= PREMIUM_ZONG_MAX then
        return false, "已达食用上限（" .. PREMIUM_ZONG_MAX .. "颗）"
    end

    -- 计算本次最多可食用数量
    local maxCanEat = PREMIUM_ZONG_MAX - eaten
    local actualCount = math.min(count, maxCanEat)

    -- 再次夹紧到未锁定库存（BM-S4A 保护）
    local unlocked = IS.CountUnlockedConsumable("xianjie_premium_zong")
    actualCount = math.min(actualCount, unlocked)
    if actualCount <= 0 then return false, "物品不足" end

    -- 原子扣除
    local ok = IS.ConsumeConsumable("xianjie_premium_zong", actualCount)
    if not ok then return false, "消耗失败" end

    -- 成功：更新三个字段
    player.premiumZongEaten = eaten + actualCount
    player.pillFortune = (player.pillFortune or 0) + actualCount
    if not player.pillCounts then player.pillCounts = {} end
    player.pillCounts.zong = player.premiumZongEaten

    -- 立即失效缓存，确保同帧 GetTotalFortune() 返回新值
    player:InvalidateStatsCache()

    EventBus.Emit("premium_zong_used", actualCount)

    -- 立即存档：防止服务端其他操作（开箱等）整包回写覆盖 premiumZongEaten，
    -- 导致重登后计数重置（"从第一个开始记"的根因）
    local SavePersistence = require("systems.save.SavePersistence")
    SavePersistence.Save()

    local msg = "食用 " .. actualCount .. " 颗仙界精品粽，福缘永久+" .. actualCount .. "！（已食用 " .. player.premiumZongEaten .. "/" .. PREMIUM_ZONG_MAX .. "）"
    print("[InventorySystem] " .. msg)
    return true, msg, actualCount
end

-- ============================================================================
-- 相思红豆糕 — 情人节活动丹药（永久+悟性，上限10）
-- ============================================================================

--- 批量使用相思红豆糕（每份永久+1悟性，终身上限10份）
---@param IS table InventorySystem facade
---@param count number 期望使用数量
---@return boolean success, string|nil message, number|nil actualCount
function M._UseBatchPremiumRedbeanCake(IS, count)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local eaten = player.premiumRedbeanCakeEaten or 0
    if eaten >= PREMIUM_REDBEAN_CAKE_MAX then
        return false, "已达食用上限（" .. PREMIUM_REDBEAN_CAKE_MAX .. "份）"
    end

    local maxCanEat = PREMIUM_REDBEAN_CAKE_MAX - eaten
    local actualCount = math.min(count, maxCanEat)

    local itemId = "valentine_xiangsi_redbean_cake"
    local unlocked = IS.CountUnlockedConsumable(itemId)
    actualCount = math.min(actualCount, unlocked)
    if actualCount <= 0 then return false, "物品不足" end

    local ok = IS.ConsumeConsumable(itemId, actualCount)
    if not ok then return false, "消耗失败" end

    player.premiumRedbeanCakeEaten = eaten + actualCount
    player.pillWisdom = player.premiumRedbeanCakeEaten
    if not player.pillCounts then player.pillCounts = {} end
    player.pillCounts.redbean_cake = player.premiumRedbeanCakeEaten

    player:InvalidateStatsCache()

    EventBus.Emit("premium_redbean_cake_used", actualCount)

    local SavePersistence = require("systems.save.SavePersistence")
    SavePersistence.Save()

    local msg = "食用 " .. actualCount .. " 份相思红豆糕，悟性永久+" .. actualCount
        .. "！（已食用 " .. player.premiumRedbeanCakeEaten .. "/" .. PREMIUM_REDBEAN_CAKE_MAX .. "）"
    print("[InventorySystem] " .. msg)
    return true, msg, actualCount
end

return M
