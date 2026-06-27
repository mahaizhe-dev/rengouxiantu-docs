-- ============================================================================
-- AlchemySystem.lua - 炼丹炉数据层（Phase 1）
-- 职责：持有 7 个核心丹药计数的运行时真值
-- 依赖约束：只允许 require core.GameState，不得 require UI/Save/Network 模块
-- ============================================================================

local GameConfig = require("config.GameConfig")
local InventorySystem = require("systems.InventorySystem")
local GameState = require("core.GameState")

local AlchemySystem = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- 运行时状态（由 SaveSerializer.DeserializePlayer 恢复）
-- ══════════════════════════════════════════════════════════════════════════════

local tigerPillCount_ = 0
local snakePillCount_ = 0
local diamondPillCount_ = 0
local temperingPillEaten_ = 0
local dragonBloodPillCount_ = 0
local swordIntentPillCount_ = 0
local abyssSealPillCount_ = 0

-- pillCounts key 映射（与 SaveLoader 建立的 player.pillCounts 结构一致）
local PILL_COUNTS_KEY = {
    tiger        = "tiger",
    snake        = "snake",
    diamond      = "diamond",
    tempering    = "tempering",
    dragonBlood  = "dragon_blood",
    swordIntent  = "sword_intent",
    abyssSeal    = "abyss_seal",
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 内部辅助：同步单个字段到 player.pillCounts（双写）
-- 条件：player.pillCounts 存在时才写入（SaveLoader 初始化后才存在）
-- ══════════════════════════════════════════════════════════════════════════════

local function syncToPillCounts(key, value)
    local player = GameState.player
    if player and player.pillCounts then
        player.pillCounts[key] = value
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Getter / Setter 接口
-- ══════════════════════════════════════════════════════════════════════════════

--- 获取虎骨丹已炼制次数
function AlchemySystem.GetTigerPillCount()
    return tigerPillCount_
end

--- 设置虎骨丹已炼制次数
function AlchemySystem.SetTigerPillCount(count)
    tigerPillCount_ = count or 0
    syncToPillCounts(PILL_COUNTS_KEY.tiger, tigerPillCount_)
end

--- 获取灵蛇丹已炼制次数
function AlchemySystem.GetSnakePillCount()
    return snakePillCount_
end

--- 设置灵蛇丹已炼制次数
function AlchemySystem.SetSnakePillCount(count)
    snakePillCount_ = count or 0
    syncToPillCounts(PILL_COUNTS_KEY.snake, snakePillCount_)
end

--- 获取金刚丹已炼制次数
function AlchemySystem.GetDiamondPillCount()
    return diamondPillCount_
end

--- 设置金刚丹已炼制次数
function AlchemySystem.SetDiamondPillCount(count)
    diamondPillCount_ = count or 0
    syncToPillCounts(PILL_COUNTS_KEY.diamond, diamondPillCount_)
end

--- 获取千锤百炼丹已食用次数
function AlchemySystem.GetTemperingPillEaten()
    return temperingPillEaten_
end

--- 设置千锤百炼丹已食用次数
function AlchemySystem.SetTemperingPillEaten(count)
    temperingPillEaten_ = count or 0
    syncToPillCounts(PILL_COUNTS_KEY.tempering, temperingPillEaten_)
end

--- 获取龙血丹已炼制次数
function AlchemySystem.GetDragonBloodPillCount()
    return dragonBloodPillCount_
end

--- 设置龙血丹已炼制次数
function AlchemySystem.SetDragonBloodPillCount(count)
    dragonBloodPillCount_ = count or 0
    syncToPillCounts(PILL_COUNTS_KEY.dragonBlood, dragonBloodPillCount_)
end

--- 获取太虚剑丹已炼制次数
function AlchemySystem.GetSwordIntentPillCount()
    return swordIntentPillCount_
end

--- 设置太虚剑丹已炼制次数
function AlchemySystem.SetSwordIntentPillCount(count)
    swordIntentPillCount_ = count or 0
    syncToPillCounts(PILL_COUNTS_KEY.swordIntent, swordIntentPillCount_)
end

--- 获取狱甲丹已炼制次数
function AlchemySystem.GetAbyssSealPillCount()
    return abyssSealPillCount_
end

--- 设置狱甲丹已炼制次数
function AlchemySystem.SetAbyssSealPillCount(count)
    abyssSealPillCount_ = count or 0
    syncToPillCounts(PILL_COUNTS_KEY.abyssSeal, abyssSealPillCount_)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 生命周期接口
-- ══════════════════════════════════════════════════════════════════════════════

--- 重置所有运行时状态为 0（ReturnToLogin 时调用）
function AlchemySystem.ResetRuntimeState()
    tigerPillCount_ = 0
    snakePillCount_ = 0
    diamondPillCount_ = 0
    temperingPillEaten_ = 0
    dragonBloodPillCount_ = 0
    swordIntentPillCount_ = 0
    abyssSealPillCount_ = 0
    print("[AlchemySystem] ResetRuntimeState: all pill counts zeroed")
end

--- 获取当前所有计数的快照（用于调试/校验）
---@return table snapshot { tiger=n, snake=n, diamond=n, tempering=n, dragonBlood=n, swordIntent=n, abyssSeal=n }
function AlchemySystem.GetSnapshot()
    return {
        tiger       = tigerPillCount_,
        snake       = snakePillCount_,
        diamond     = diamondPillCount_,
        tempering   = temperingPillEaten_,
        dragonBlood = dragonBloodPillCount_,
        swordIntent = swordIntentPillCount_,
        abyssSeal   = abyssSealPillCount_,
    }
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Phase 2: 炼制业务逻辑（CanCraft / Craft）
-- ══════════════════════════════════════════════════════════════════════════════

local PillRecipes = require("config.PillRecipes")

-- countKey → getter/setter 映射表（避免大量 if/elseif）
local COUNT_GETTERS = {
    tiger       = function() return tigerPillCount_ end,
    snake       = function() return snakePillCount_ end,
    diamond     = function() return diamondPillCount_ end,
    tempering   = function() return temperingPillEaten_ end,
    dragonBlood = function() return dragonBloodPillCount_ end,
    swordIntent = function() return swordIntentPillCount_ end,
    abyssSeal   = function() return abyssSealPillCount_ end,
}

local COUNT_SETTERS = {
    tiger       = function(v) AlchemySystem.SetTigerPillCount(v) end,
    snake       = function(v) AlchemySystem.SetSnakePillCount(v) end,
    diamond     = function(v) AlchemySystem.SetDiamondPillCount(v) end,
    tempering   = function(v) AlchemySystem.SetTemperingPillEaten(v) end,
    dragonBlood = function(v) AlchemySystem.SetDragonBloodPillCount(v) end,
    swordIntent = function(v) AlchemySystem.SetSwordIntentPillCount(v) end,
    abyssSeal   = function(v) AlchemySystem.SetAbyssSealPillCount(v) end,
}

--- 获取材料显示名称
---@param materialId string
---@return string
local function getMaterialName(materialId)
    local data = GameConfig.PET_MATERIALS[materialId] or GameConfig.PET_FOOD[materialId]
    return data and data.name or materialId
end

-- ──────────────────────────────────────────────────────────────────────────────
-- CanCraft: 前置校验（仅检查，不扣费）
-- ──────────────────────────────────────────────────────────────────────────────

--- 检查产出型丹药是否可以炼制
---@param recipeId string 配方 ID（PillRecipes.CONSUMABLES 的 key）
---@return boolean ok
---@return string|nil errMsg 失败时的提示文案
function AlchemySystem.CanCraftConsumable(recipeId)
    local recipe = PillRecipes.CONSUMABLES[recipeId]
    if not recipe then return false, "未知配方: " .. tostring(recipeId) end

    local player = GameState.player
    if not player then return false, "角色未就绪" end

    -- 灵韵检查
    if player.lingYun < recipe.cost then
        return false, "灵韵不足！炼制需要 " .. recipe.cost .. " 灵韵"
    end

    -- 背包空间检查
    local canAdd = InventorySystem.CountConsumable(recipe.outputId) > 0
        or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        return false, "背包已满，无法炼制！"
    end

    return true, nil
end

--- 检查永久属性丹是否可以炼制
---@param recipeId string 配方 ID（PillRecipes.PERMANENTS 的 key）
---@return boolean ok
---@return string|nil errMsg 失败时的提示文案
function AlchemySystem.CanCraftPermanent(recipeId)
    local recipe = PillRecipes.PERMANENTS[recipeId]
    if not recipe then return false, "未知配方: " .. tostring(recipeId) end

    local player = GameState.player
    if not player then return false, "角色未就绪" end

    -- 上限检查
    local getter = COUNT_GETTERS[recipe.countKey]
    local current = getter and getter() or 0
    if current >= recipe.maxCount then
        return false, recipe.name .. "已炼制完毕！限炼" .. recipe.maxCount .. "颗"
    end

    -- 灵韵检查
    if player.lingYun < recipe.cost then
        return false, "灵韵不足！炼制需要 " .. recipe.cost .. " 灵韵"
    end

    -- 材料检查
    local matName = getMaterialName(recipe.material)
    if InventorySystem.CountUnlockedConsumable(recipe.material) < recipe.materialCount then
        return false, matName .. "不足！炼制需要 " .. recipe.materialCount .. " 个" .. matName
    end

    return true, nil
end

--- 检查令牌盒是否可以炼制
---@param tokenId string 令牌消耗品 ID
---@param boxId string 令牌盒消耗品 ID
---@return boolean ok
---@return string|nil errMsg 失败时的提示文案
function AlchemySystem.CanCraftTokenBox(tokenId, boxId)
    local player = GameState.player
    if not player then return false, "角色未就绪" end

    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local lingYunCost = PillRecipes.TOKEN_BOX_LINGYUN_COST
    local tokenCost = PillRecipes.TOKEN_BOX_TOKEN_COST

    -- 灵韵检查
    if player.lingYun < lingYunCost then
        return false, "灵韵不足！炼制需要 " .. lingYunCost .. " 灵韵"
    end

    -- 令牌数量检查
    local tokenCount = InventorySystem.CountConsumable(tokenId)
    if tokenCount < tokenCost then
        return false, tokenName .. "不足！需要 " .. tokenCost .. "，当前 " .. tokenCount
    end

    -- 背包空间检查
    local canAdd = InventorySystem.CountConsumable(boxId) > 0
        or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        return false, "背包已满，无法炼制！"
    end

    return true, nil
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Craft: 执行炼制（扣费 + 产出/加属性 + 计数）
-- 调用前应已通过 CanCraft 检查（Craft 内部会做二次校验并静默失败）
-- ──────────────────────────────────────────────────────────────────────────────

--- 执行产出型炼制
---@param recipeId string 配方 ID
---@return boolean ok
---@return string|nil resultMsg 成功消息
function AlchemySystem.CraftConsumable(recipeId)
    local recipe = PillRecipes.CONSUMABLES[recipeId]
    if not recipe then return false, nil end

    local player = GameState.player
    if not player then return false, nil end

    -- 二次校验（防止并发/延迟场景）
    if player.lingYun < recipe.cost then return false, nil end
    local canAdd = InventorySystem.CountConsumable(recipe.outputId) > 0
        or InventorySystem.GetFreeSlots() > 0
    if not canAdd then return false, nil end

    -- 扣除灵韵
    player.lingYun = player.lingYun - recipe.cost
    -- 添加产出到背包
    InventorySystem.AddConsumable(recipe.outputId, 1)

    local newCount = InventorySystem.CountConsumable(recipe.outputId)
    local msg = "炼制成功！获得" .. recipe.name .. " ×1 (共 " .. newCount .. " 颗)"
    return true, msg
end

--- 执行永久属性丹炼制（在 C2S 授权回调内调用）
---@param recipeId string 配方 ID
---@return boolean ok
---@return string|nil resultMsg 成功消息
function AlchemySystem.CraftPermanent(recipeId)
    local recipe = PillRecipes.PERMANENTS[recipeId]
    if not recipe then return false, nil end

    local player = GameState.player
    if not player then return false, nil end

    local getter = COUNT_GETTERS[recipe.countKey]
    local setter = COUNT_SETTERS[recipe.countKey]
    if not getter or not setter then return false, nil end

    -- 二次校验（防止授权期间状态变化）
    local current = getter()
    if current >= recipe.maxCount then return false, nil end
    if player.lingYun < recipe.cost then return false, nil end
    if InventorySystem.CountUnlockedConsumable(recipe.material) < recipe.materialCount then
        return false, nil
    end

    -- 扣除灵韵
    player.lingYun = player.lingYun - recipe.cost
    -- 消耗材料
    local ok = InventorySystem.ConsumeConsumable(recipe.material, recipe.materialCount)
    if not ok then
        -- 回滚灵韵
        player.lingYun = player.lingYun + recipe.cost
        return false, nil
    end

    -- 增加计数
    setter(current + 1)

    -- 应用属性加成
    local stat = recipe.bonusStat
    local value = recipe.bonusValue
    if stat == "maxHp" then
        player.maxHp = player.maxHp + value
        player:InvalidateStatsCache()
        if recipe.alsoHeal then
            player.hp = math.min(player.hp + value, player:GetTotalMaxHp())
        end
    elseif stat == "pillConstitution" then
        player.pillConstitution = (player.pillConstitution or 0) + value
        player:InvalidateStatsCache()
    else
        -- atk, def 等直接字段
        player[stat] = (player[stat] or 0) + value
        player:InvalidateStatsCache()
    end

    -- 生成成功消息
    local newCount = getter()
    local statName = PillRecipes.STAT_DISPLAY[stat] or stat
    local msg
    if stat == "pillConstitution" then
        msg = "服用成功！" .. statName .. "+" .. value .. " (已服" .. newCount .. "/" .. recipe.maxCount .. ")"
    else
        msg = "炼制成功！" .. statName .. "永久 +" .. value .. " (已炼" .. newCount .. "/" .. recipe.maxCount .. ")"
    end
    return true, msg
end

--- 执行令牌盒炼制
---@param tokenId string 令牌消耗品 ID
---@param boxId string 令牌盒消耗品 ID
---@return boolean ok
---@return string|nil resultMsg 成功消息
function AlchemySystem.CraftTokenBox(tokenId, boxId)
    local player = GameState.player
    if not player then return false, nil end

    local lingYunCost = PillRecipes.TOKEN_BOX_LINGYUN_COST
    local tokenCost = PillRecipes.TOKEN_BOX_TOKEN_COST
    local boxName = GameConfig.CONSUMABLES[boxId] and GameConfig.CONSUMABLES[boxId].name or boxId

    -- 二次校验
    if player.lingYun < lingYunCost then return false, nil end
    if InventorySystem.CountConsumable(tokenId) < tokenCost then return false, nil end
    local canAdd = InventorySystem.CountConsumable(boxId) > 0
        or InventorySystem.GetFreeSlots() > 0
    if not canAdd then return false, nil end

    -- 扣除灵韵
    player.lingYun = player.lingYun - lingYunCost
    -- 消耗令牌
    local ok = InventorySystem.ConsumeConsumable(tokenId, tokenCost)
    if not ok then
        -- 回滚灵韵
        player.lingYun = player.lingYun + lingYunCost
        return false, nil
    end
    -- 发放令牌盒
    InventorySystem.AddConsumable(boxId, 1)

    local newCount = InventorySystem.CountConsumable(boxId)
    local msg = "炼制成功！获得" .. boxName .. " ×1 (共 " .. newCount .. " 个)"
    return true, msg
end

return AlchemySystem
