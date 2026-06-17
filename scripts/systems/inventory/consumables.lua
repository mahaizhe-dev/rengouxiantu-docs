-- ============================================================================
-- inventory/consumables.lua — 消耗品 CRUD + 单次使用 + 葫芦/专属升级
-- ============================================================================
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local TradeLock = require("systems.BlackMarketTradeLock")

local M = {}

--- 添加消耗品到背包（支持堆叠上限溢出）
---@param IS table InventorySystem facade
---@param consumableId string 消耗品 ID（如 "meat_bone", "spirit_pill"）
---@param amount number|nil 数量（默认1）
---@return boolean allSuccess 是否全部添加成功
---@return number addedCount 实际写入数量（部分成功时 > 0 但 allSuccess=false）
function M.AddConsumable(IS, consumableId, amount)
    local manager_ = IS.GetManager()
    if not manager_ then return false, 0 end
    amount = amount or 1
    local originalAmount = amount

    local MAX_STACK = GameConfig.MAX_STACK_COUNT  -- 9999

    -- 查找已有的未满堆叠（BM-S4A: 跳过锁定堆叠，新物品不合并进锁定堆叠）
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            -- BM-S4A/BM-NORESELL: 锁定堆叠 / 黑市买入来源堆叠不接受普通物品合并
            -- （AddConsumable 仅用于普通入库；黑市买入走 AddConsumableLockedNewStack）
            if TradeLock.IsLocked(item) or TradeLock.IsNoResell(item) then
                -- skip locked / no-resell stack
            else
                local cur = item.count or 1
                if cur < MAX_STACK then
                    local space = MAX_STACK - cur
                    if amount <= space then
                        -- 当前堆叠能装下全部
                        item.count = cur + amount
                        EventBus.Emit("inventory_item_added", item, i)
                        return true, originalAmount
                    else
                        -- 填满当前堆叠，剩余溢出到新堆叠
                        item.count = MAX_STACK
                        amount = amount - space
                        EventBus.Emit("inventory_item_added", item, i)
                        -- 继续循环查找下一个未满堆叠
                    end
                end
            end
            -- 此堆叠已满或锁定，继续查找下一个
        end
    end

    -- 剩余 amount 需要创建新堆叠
    if amount <= 0 then return true, originalAmount end

    local foodData = GameConfig.PET_FOOD[consumableId]
    local matData = GameConfig.PET_MATERIALS[consumableId]
    local PetSkillData = require("config.PetSkillData")
    local bookData = PetSkillData.SKILL_BOOKS[consumableId]
    local eventData = GameConfig.EVENT_ITEMS and GameConfig.EVENT_ITEMS[consumableId]
    local consumableData = GameConfig.CONSUMABLES[consumableId]
    local data = foodData or matData or bookData or eventData or consumableData
    if not data then return false, originalAmount - amount end

    -- 循环创建新堆叠直到 amount 用尽或背包满
    while amount > 0 do
        local stackAmount = math.min(amount, MAX_STACK)
        local item = {
            id = require("core.Utils").NextId(),
            name = data.name,
            icon = data.icon,
            image = data.image or nil,
            category = "consumable",
            consumableId = consumableId,
            count = stackAmount,
            sellPrice = data.sellPrice or 1,
            quality = data.quality or "white",
            desc = data.desc,
            petExp = foodData and foodData.exp or nil,
            isSkillBook = bookData and true or nil,
            skillId = bookData and bookData.skillId or nil,
            bookTier = bookData and bookData.tier or nil,
        }
        local success, idx = manager_:AddToInventory(item)
        if success then
            EventBus.Emit("inventory_item_added", item, idx)
            amount = amount - stackAmount
        else
            -- 背包满，无法继续，返回已写入数量
            return false, originalAmount - amount
        end
    end
    return true, originalAmount
end

--- BM-S4AR: 强制新建锁定堆叠（黑市买入专用，绝不合并已有堆叠）
---@param IS table InventorySystem facade
---@param consumableId string
---@param amount number
---@param batchId string 批次 ID（由 TradeLock.GenerateBatchId() 生成）
---@param duration number|nil 锁时长秒数（默认 TradeLock.LOCK_DURATION）
---@return boolean allSuccess
---@return number addedCount
function M.AddConsumableLockedNewStack(IS, consumableId, amount, batchId, duration)
    local manager_ = IS.GetManager()
    if not manager_ then return false, 0 end
    amount = amount or 1
    local originalAmount = amount

    local MAX_STACK = GameConfig.MAX_STACK_COUNT  -- 9999
    local dur = duration or TradeLock.LOCK_DURATION
    local lockUntil = os.time() + dur

    -- 查找消耗品配置
    local foodData = GameConfig.PET_FOOD[consumableId]
    local matData = GameConfig.PET_MATERIALS[consumableId]
    local PetSkillData = require("config.PetSkillData")
    local bookData = PetSkillData.SKILL_BOOKS[consumableId]
    local eventData = GameConfig.EVENT_ITEMS and GameConfig.EVENT_ITEMS[consumableId]
    local consumableData = GameConfig.CONSUMABLES[consumableId]
    local data = foodData or matData or bookData or eventData or consumableData
    if not data then return false, 0 end

    -- 循环创建新堆叠（跳过所有已有堆叠，直接找空位）
    while amount > 0 do
        local stackAmount = math.min(amount, MAX_STACK)
        local item = {
            id = require("core.Utils").NextId(),
            name = data.name,
            icon = data.icon,
            image = data.image or nil,
            category = "consumable",
            consumableId = consumableId,
            count = stackAmount,
            sellPrice = data.sellPrice or 1,
            quality = data.quality or "white",
            desc = data.desc,
            petExp = foodData and foodData.exp or nil,
            isSkillBook = bookData and true or nil,
            skillId = bookData and bookData.skillId or nil,
            bookTier = bookData and bookData.tier or nil,
            -- BM-S4AR: 创建时即带锁元数据
            bmLockUntil = lockUntil,
            bmLockSource = TradeLock.SOURCE_BLACK_MARKET,
            bmLockBatchId = batchId,
        }
        -- BM-NORESELL: 黑市买入 → 永久禁回售来源标记（客户端本地与服务端存档保持一致）
        TradeLock.MarkNoResell(item, consumableId)
        local success, idx = manager_:AddToInventory(item)
        if success then
            EventBus.Emit("inventory_item_added", item, idx)
            amount = amount - stackAmount
        else
            return false, originalAmount - amount
        end
    end
    return true, originalAmount
end

--- 统计某种消耗品的总数量
---@param IS table InventorySystem facade
---@param consumableId string
---@return number
function M.CountConsumable(IS, consumableId)
    local manager_ = IS.GetManager()
    if not manager_ then return 0 end
    local total = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            total = total + (item.count or 1)
        end
    end
    return total
end

--- BM-S4A: 统计某种消耗品的未锁定数量（用于消费/使用前检查）
---@param IS table InventorySystem facade
---@param consumableId string
---@return number unlocked 未锁定的总数量
---@return number locked 锁定中的总数量
function M.CountUnlockedConsumable(IS, consumableId)
    local manager_ = IS.GetManager()
    if not manager_ then return 0, 0 end
    return TradeLock.CountUnlockedConsumable(
        function(i) return manager_:GetInventoryItem(i) end,
        GameConfig.BACKPACK_SIZE,
        consumableId
    )
end

--- BM-S4B: 判断指定消耗品是否存在任何锁定堆叠（整类禁售）
---@param IS table InventorySystem facade
---@param consumableId string
---@return boolean
function M.HasAnyLockedConsumable(IS, consumableId)
    local manager_ = IS.GetManager()
    if not manager_ then return false end
    return TradeLock.HasAnyLockedConsumable(
        function(i) return manager_:GetInventoryItem(i) end,
        GameConfig.BACKPACK_SIZE,
        consumableId
    )
end

--- 消耗指定数量的消耗品
--- BM-S4A: 仅消耗未锁定的堆叠，锁定堆叠跳过
---@param IS table InventorySystem facade
---@param consumableId string
---@param amount number
---@return boolean success
function M.ConsumeConsumable(IS, consumableId, amount)
    local manager_ = IS.GetManager()
    if not manager_ then return false end

    -- BM-S4A: 检查未锁定数量是否足够（锁定堆叠不参与消耗）
    local unlocked = M.CountUnlockedConsumable(IS, consumableId)
    if unlocked < amount then
        return false
    end

    local remaining = amount
    for i = 1, GameConfig.BACKPACK_SIZE do
        if remaining <= 0 then break end
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId == consumableId then
            -- BM-S4A: 跳过锁定堆叠
            if TradeLock.IsLocked(item) then
                -- skip locked stack
            else
                local has = item.count or 1
                if has <= remaining then
                    remaining = remaining - has
                    manager_:SetInventoryItem(i, nil)  -- 全部用完，移除
                else
                    item.count = has - remaining
                    remaining = 0
                end
            end
        end
    end

    EventBus.Emit("consumable_used", consumableId, amount)

    -- BM-S2R: 黑市可卖物消耗才置脏（非黑市消耗品不触发门禁）
    -- BMConfig 加载失败时保守置脏（fail-closed）
    local _okBMS, _BMS = pcall(require, "systems.BlackMarketSyncState")
    if _okBMS and _BMS then
        local _okBMC, _BMC = pcall(require, "config.BlackMerchantConfig")
        if (not _okBMC) or (not _BMC) or (_BMC.ITEMS and _BMC.ITEMS[consumableId]) then
            _BMS.MarkConsumeUsed(consumableId)
        end
    end

    return true
end

--- 获取背包中所有宠物食物列表
---@param IS table InventorySystem facade
---@return table[] { {slotIndex, consumableId, name, icon, count, petExp} }
function M.GetPetFoodList(IS)
    local manager_ = IS.GetManager()
    if not manager_ then return {} end
    local list = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.petExp then
            table.insert(list, {
                slotIndex = i,
                consumableId = item.consumableId,
                name = item.name,
                icon = item.icon,
                count = item.count or 1,
                petExp = item.petExp,
            })
        end
    end
    return list
end

--- 获取背包中所有技能书列表
---@param IS table InventorySystem facade
---@return table[] { {slotIndex, consumableId, name, icon, count, skillId, bookTier, quality} }
function M.GetSkillBookList(IS)
    local manager_ = IS.GetManager()
    if not manager_ then return {} end
    local list = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "consumable" and item.isSkillBook then
            table.insert(list, {
                slotIndex = i,
                consumableId = item.consumableId,
                name = item.name,
                icon = item.icon,
                count = item.count or 1,
                skillId = item.skillId,
                bookTier = item.bookTier,
                quality = item.quality,
            })
        end
    end
    return list
end

-- ============================================================================
-- 葫芦升级系统
-- ============================================================================

--- 升级装备中的葫芦（消耗金币，提升 tier，更新属性）
---@param IS table InventorySystem facade
---@return boolean success, string|nil errorMsg
function M.UpgradeGourd(IS)
    local manager_ = IS.GetManager()
    if not manager_ then return false, "系统未初始化" end
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    -- 获取装备中的葫芦
    local gourd = manager_:GetEquipmentItem("treasure")
    if not gourd then return false, "未装备葫芦" end

    local currentTier = gourd.tier or 1
    local nextTier = currentTier + 1
    local upgradeData = EquipmentData.GOURD_UPGRADE[nextTier]
    if not upgradeData then return false, "已达最高阶级" end

    -- 检查境界要求
    if upgradeData.requiredRealm then
        local playerRealmData = GameConfig.REALMS[player.realm]
        local reqRealmData = GameConfig.REALMS[upgradeData.requiredRealm]
        if not playerRealmData or not reqRealmData then return false, "境界数据异常" end
        if playerRealmData.order < reqRealmData.order then
            local reqName = reqRealmData.name or upgradeData.requiredRealm
            return false, "境界不足，需要" .. reqName
        end
    end

    -- 检查金币
    if player.gold < upgradeData.cost then
        return false, "金币不足"
    end

    -- 扣除金币
    player:SpendGold(upgradeData.cost)

    -- 更新葫芦属性
    gourd.tier = nextTier
    gourd.quality = upgradeData.quality
    local LootSystem = require("systems.LootSystem")
    gourd.icon = LootSystem.GetGourdIcon(upgradeData.quality)
    gourd.name = "酒葫芦 lv." .. nextTier

    -- 更新主属性
    local newHpRegen = EquipmentData.GOURD_MAIN_STAT[nextTier] or gourd.mainStat.hpRegen
    gourd.mainStat = { hpRegen = newHpRegen }

    -- 更新副属性（覆盖，升级后洗练属性清除）
    gourd.subStats = {}
    for _, sub in ipairs(upgradeData.subStats) do
        table.insert(gourd.subStats, { stat = sub.stat, value = sub.value })
    end

    -- 更新灵性属性
    if upgradeData.spiritStat then
        gourd.spiritStat = { stat = upgradeData.spiritStat.stat, name = upgradeData.spiritStat.name, value = upgradeData.spiritStat.value }
    else
        gourd.spiritStat = nil
    end

    -- 清除洗练属性
    gourd.forgeStat = nil

    -- 重新计算装备加成
    IS.RecalcEquipStats()

    EventBus.Emit("gourd_upgraded", nextTier)
    print("[InventorySystem] Gourd upgraded to tier " .. nextTier)

    -- 即时存档：升级消耗大量金币，避免玩家退出后丢失进度
    EventBus.Emit("save_request")

    return true, nil
end

--- 获取当前装备的葫芦 tier（供技能系统查表用）
---@param IS table InventorySystem facade
---@return number tier
function M.GetGourdTier(IS)
    local manager_ = IS.GetManager()
    if not manager_ then return 1 end
    local gourd = manager_:GetEquipmentItem("treasure")
    if not gourd then return 1 end
    return gourd.tier or 1
end

--- 获取专属装备阶级（用于技能 tierScaling 查表）
---@param IS table InventorySystem facade
---@return number tier 默认4（Lv.1）
function M.GetExclusiveTier(IS)
    local manager_ = IS.GetManager()
    if not manager_ then return 3 end
    local excl = manager_:GetEquipmentItem("exclusive")
    if not excl then return 3 end
    return excl.tier or 3
end

--- 获取专属装备的**技能等级 Tier**
--- 新版法宝（id 以 "fabao_" 开头）技能暂不成长，固定返回 T3
--- 旧版专属装备（xuehaitu_chu/po/jue 等）保持原有 Tier 成长
---@param IS table InventorySystem facade
function M.GetExclusiveSkillTier(IS)
    local manager_ = IS.GetManager()
    if not manager_ then return 3 end
    local excl = manager_:GetEquipmentItem("exclusive")
    if not excl then return 3 end
    -- 新版法宝：技能暂不成长（§8.4）
    if excl.id and type(excl.id) == "string" and excl.id:sub(1, 6) == "fabao_" then
        return 3
    end
    return excl.tier or 3
end

-- ============================================================================
-- 单次使用消耗品
-- ============================================================================

--- 使用上品修炼果（+100000 EXP，每次1颗，境界等级上限时不可用）
---@param IS table InventorySystem facade
---@return boolean success, string|nil errorMsg
function M.UseExpPillSuperior(IS)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local count = IS.CountConsumable("exp_pill_superior")
    if count < 1 then return false, "上品修炼果不足" end

    local realmData = GameConfig.REALMS[player.realm]
    if realmData then
        local maxLevel = realmData.maxLevel
        if player.level >= maxLevel then
            local curLevelExp = GameConfig.EXP_TABLE[player.level] or 0
            local nextLevelExp = GameConfig.EXP_TABLE[player.level + 1]
            if nextLevelExp then
                local cap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
                if player.exp >= cap then
                    return false, "经验已达境界上限，请先突破境界"
                end
            end
        end
    end

    local ok = IS.ConsumeConsumable("exp_pill_superior", 1)
    if not ok then return false, "消耗失败" end

    player:GainExp(100000)
    EventBus.Emit("exp_pill_used", 100000)
    return true, nil
end

--- 使用上品灵韵果（+500 灵韵，每次1颗）
---@param IS table InventorySystem facade
---@return boolean success, string|nil errorMsg
function M.UseLingyunFruitSuperior(IS)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local count = IS.CountConsumable("lingyun_fruit_superior")
    if count < 1 then return false, "上品灵韵果不足" end

    local ok = IS.ConsumeConsumable("lingyun_fruit_superior", 1)
    if not ok then return false, "消耗失败" end

    player:GainLingYun(500)
    return true, nil
end

--- 使用灵韵果（+50 灵韵，每次1颗）
---@param IS table InventorySystem facade
---@return boolean success, string|nil errorMsg
function M.UseLingyunFruit(IS)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local count = IS.CountConsumable("lingyun_fruit")
    if count < 1 then return false, "灵韵果不足" end

    local ok = IS.ConsumeConsumable("lingyun_fruit", 1)
    if not ok then return false, "消耗失败" end

    player:GainLingYun(50)
    return true, nil
end

--- 使用修炼果（+10000 EXP，每次1颗，境界等级上限时不可用）
---@param IS table InventorySystem facade
---@return boolean success, string|nil errorMsg
function M.UseExpPill(IS)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    -- 检查数量
    local count = IS.CountConsumable("exp_pill")
    if count < 1 then return false, "修炼果不足" end

    -- 检查是否卡在境界等级上限
    local realmData = GameConfig.REALMS[player.realm]
    if realmData then
        local maxLevel = realmData.maxLevel
        if player.level >= maxLevel then
            -- 经验已被 cap，不允许使用
            local curLevelExp = GameConfig.EXP_TABLE[player.level] or 0
            local nextLevelExp = GameConfig.EXP_TABLE[player.level + 1]
            if nextLevelExp then
                local cap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
                if player.exp >= cap then
                    return false, "经验已达境界上限，请先突破境界"
                end
            end
        end
    end

    -- 消耗1颗
    local ok = IS.ConsumeConsumable("exp_pill", 1)
    if not ok then return false, "消耗失败" end

    -- 给予经验
    player:GainExp(10000)
    EventBus.Emit("exp_pill_used", 10000)
    return true, nil
end

--- 使用守护者证明（消耗1个，为仙途守护者道印注入100经验）
---@param IS table InventorySystem facade
---@param slotIndex number|nil 背包槽位（可选，不传则自动查找）
---@return boolean success, string|nil errorMsg
function M.UseGuardianToken(IS, slotIndex)
    local count = IS.CountConsumable("item_guardian_token")
    if count < 1 then return false, "守护者证明不足" end

    local ok = IS.ConsumeConsumable("item_guardian_token", 1)
    if not ok then return false, "消耗失败" end

    local okAtlas, AtlasSystem = pcall(require, "systems.AtlasSystem")
    if okAtlas and AtlasSystem and AtlasSystem.ConsumeGuardianToken then
        AtlasSystem.ConsumeGuardianToken(1)
    else
        print("[InventorySystem] WARNING: AtlasSystem not available, guardian token consumed but exp not applied")
    end

    return true, nil
end

return M
