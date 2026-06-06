---@diagnostic disable
-- ============================================================================
-- MinggeSystem.lua - 五行命格系统（独立背包 + 独立装备栏 + 属性结算）
-- ============================================================================
-- 与 InventorySystem 平行运行，管理命格独立的 60 格背包和 15 装备槽。
-- 属性写入 player.mingge* 字段，由 Player:GetTotal*() 汇总。

local UI = require("urhox-libs/UI")
local MinggeData = require("config.MinggeData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local MinggeSystem = {}

---@type InventoryManager|nil
local manager_ = nil

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化命格系统（创建独立的 InventoryManager）
function MinggeSystem.Init()
    -- 构建 15 个装备槽配置
    local equipSlots = {}
    for _, slotId in ipairs(MinggeData.ALL_SLOTS) do
        -- 从 slotId 中提取五行类型（去掉数字后缀）
        local element = slotId:match("^(%a+)%d+$")
        equipSlots[slotId] = { type = element, item = nil }
    end

    manager_ = UI.InventoryManager.new({
        inventorySize = MinggeData.BACKPACK_SIZE,
        equipmentSlots = equipSlots,
    })

    -- 装备变更时刷新命格属性加成
    manager_.onChange = function()
        MinggeSystem.RecalcStats()
    end

    print("[MinggeSystem] Initialized with " .. MinggeData.BACKPACK_SIZE .. " slots, 15 equip slots")
end

--- 获取 InventoryManager 实例（供 UI 使用）
---@return InventoryManager
function MinggeSystem.GetManager()
    return manager_
end

--- 仅供测试使用：注入 mock manager
---@param mgr InventoryManager
function MinggeSystem.SetManager(mgr)
    manager_ = mgr
end

-- ============================================================================
-- 背包操作
-- ============================================================================

--- 添加命格到背包
---@param item table 命格物品
---@return boolean success
---@return number|nil slotIndex
function MinggeSystem.AddItem(item)
    if not manager_ then return false, nil end

    -- 境界守卫：金丹初期（order>=7）以上才能获得命格
    local GameConfig = require("config.GameConfig")
    local player = GameState.player
    local realmData = player and GameConfig.REALMS[player.realm]
    if not realmData or realmData.order < 7 then
        print("[MinggeSystem] Realm guard: player realm too low, reject AddItem")
        return false, nil
    end

    -- 确保 category 和 type 字段
    item.category = "mingge"
    item.type = item.element or item.type

    local success, idx = manager_:AddToInventory(item)
    if success then
        EventBus.Emit("mingge_item_added", item, idx)
        print("[MinggeSystem] Added: " .. (item.name or "?") .. " to slot " .. idx)
    else
        print("[MinggeSystem] Backpack full! Cannot add: " .. (item.name or "?"))
        EventBus.Emit("mingge_backpack_full", item)
    end
    return success, idx
end

--- 出售命格（从背包中移除，获得灵韵）
---@param slotIndex number 背包槽位
---@return boolean
function MinggeSystem.SellItem(slotIndex)
    if not manager_ then return false end
    local item = manager_:GetInventoryItem(slotIndex)
    if not item then return false end
    if item.locked then
        print("[MinggeSystem] Cannot sell locked item: " .. (item.name or "?"))
        return false
    end

    local price = item.sellPrice or 1
    local player = GameState.player
    if player then
        player:GainLingYun(price)
    end

    manager_:SetInventoryItem(slotIndex, nil)
    EventBus.Emit("mingge_item_sold", item, price)
    print("[MinggeSystem] Sold " .. (item.name or "?") .. " for " .. price .. " lingYun")
    return true
end

--- 批量出售指定品质的命格
---@param qualitySet table {purple=true, orange=true} 需要出售的品质集合
---@return number soldCount, number totalLingYun
function MinggeSystem.SellByQuality(qualitySet)
    if not manager_ then return 0, 0 end

    local soldCount = 0
    local totalLingYun = 0

    for i = 1, MinggeData.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item and item.category == "mingge" and item.quality then
            if qualitySet[item.quality] and not item.locked then
                local price = item.sellPrice or 1
                totalLingYun = totalLingYun + price
                manager_:SetInventoryItem(i, nil)
                soldCount = soldCount + 1
            end
        end
    end

    if soldCount > 0 then
        local player = GameState.player
        if player then
            player:GainLingYun(totalLingYun)
        end
        MinggeSystem.RecalcStats()  -- 防御性重算（卖的是背包不影响，但防止逻辑遗漏）
        EventBus.Emit("mingge_batch_sold", soldCount, totalLingYun)
        print("[MinggeSystem] Batch sold " .. soldCount .. " mingge for " .. totalLingYun .. " lingYun")
    end

    return soldCount, totalLingYun
end

--- 整理背包（按 tier→quality→element→stat 排序）
function MinggeSystem.SortBackpack()
    if not manager_ then return end

    -- 收集所有背包物品
    local items = {}
    for i = 1, MinggeData.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item then
            items[#items + 1] = item
        end
    end

    -- 排序规则：tier desc → quality(cyan>orange>purple) → element → stat
    local qualityOrder = { cyan = 3, orange = 2, purple = 1 }
    local elementOrder = { metal = 1, wood = 2, water = 3, fire = 4, earth = 5 }

    table.sort(items, function(a, b)
        -- tier 降序
        if a.tier ~= b.tier then return a.tier > b.tier end
        -- quality 降序
        local qa = qualityOrder[a.quality] or 0
        local qb = qualityOrder[b.quality] or 0
        if qa ~= qb then return qa > qb end
        -- element 升序
        local ea = elementOrder[a.element] or 0
        local eb = elementOrder[b.element] or 0
        if ea ~= eb then return ea < eb end
        -- stat 字母序
        return (a.stat or "") < (b.stat or "")
    end)

    -- 清空全部格子，按排序结果重新放入
    for i = 1, MinggeData.BACKPACK_SIZE do
        manager_:SetInventoryItem(i, nil)
    end
    for i, item in ipairs(items) do
        manager_:SetInventoryItem(i, item)
    end

    print("[MinggeSystem] Backpack sorted: " .. #items .. " items")
end

--- 获取背包空余格数
---@return number
function MinggeSystem.GetFreeSlots()
    if not manager_ then return 0 end
    local count = 0
    for i = 1, MinggeData.BACKPACK_SIZE do
        if not manager_:GetInventoryItem(i) then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- 装备操作
-- ============================================================================

--- 检查同命格 ID 是否已装备（同命格不可重复装备）
---@param minggeId string 命格唯一ID（如 "metal_sha_wanli"）
---@return boolean
function MinggeSystem.IsDuplicateEquipped(minggeId)
    if not manager_ then return false end
    for _, slotId in ipairs(MinggeData.ALL_SLOTS) do
        local equipped = manager_:GetEquipmentItem(slotId)
        if equipped and equipped.minggeId == minggeId then
            return true
        end
    end
    return false
end

--- 装备命格（从背包槽到装备槽）
---@param backpackIndex number 背包槽位
---@param targetSlot string|nil 目标装备槽（nil则自动选择同五行空槽）
---@return boolean success
---@return string|nil errorMsg
function MinggeSystem.Equip(backpackIndex, targetSlot)
    if not manager_ then return false, "系统未初始化" end

    local item = manager_:GetInventoryItem(backpackIndex)
    if not item then return false, "槽位为空" end
    if item.category ~= "mingge" then return false, "非命格物品" end

    -- 同命格唯一性检查
    if item.minggeId and MinggeSystem.IsDuplicateEquipped(item.minggeId) then
        return false, "同名命格已装备"
    end

    -- 确定目标槽位
    local element = item.element
    if not element then return false, "命格缺少五行属性" end

    if targetSlot then
        -- 验证目标槽位属于同一五行
        local slotElement = targetSlot:match("^(%a+)%d+$")
        if slotElement ~= element then
            return false, "五行不匹配"
        end
    else
        -- 自动寻找同五行空槽
        local slots = MinggeData.SLOTS[element]
        if not slots then return false, "无效五行" end
        for _, slotId in ipairs(slots) do
            if not manager_:GetEquipmentItem(slotId) then
                targetSlot = slotId
                break
            end
        end
        if not targetSlot then
            return false, "该五行装备位已满"
        end
    end

    -- 执行装备：如果目标位已有装备，交换回背包
    local existing = manager_:GetEquipmentItem(targetSlot)
    manager_:SetInventoryItem(backpackIndex, existing) -- nil or swap
    manager_:SetEquipmentItem(targetSlot, item)

    EventBus.Emit("mingge_equipped", item, targetSlot)
    print("[MinggeSystem] Equipped: " .. (item.name or "?") .. " -> " .. targetSlot)
    return true, nil
end

--- 卸下命格（从装备槽到背包）
---@param slotId string 装备槽ID
---@return boolean success
---@return string|nil errorMsg
function MinggeSystem.Unequip(slotId)
    if not manager_ then return false, "系统未初始化" end

    local item = manager_:GetEquipmentItem(slotId)
    if not item then return false, "该槽位为空" end

    -- 检查背包是否有空位
    local freeSlot = nil
    for i = 1, MinggeData.BACKPACK_SIZE do
        if not manager_:GetInventoryItem(i) then
            freeSlot = i
            break
        end
    end
    if not freeSlot then
        return false, "背包已满"
    end

    -- 执行卸下
    manager_:SetEquipmentItem(slotId, nil)
    manager_:SetInventoryItem(freeSlot, item)

    EventBus.Emit("mingge_unequipped", item, slotId)
    print("[MinggeSystem] Unequipped: " .. (item.name or "?") .. " from " .. slotId)
    return true, nil
end

-- ============================================================================
-- 属性结算
-- ============================================================================

--- 重新计算命格属性加成，写入 player.mingge* 字段
function MinggeSystem.RecalcStats()
    local player = GameState.player
    if not player then return end

    -- 清零所有命格属性字段
    for _, fieldName in pairs(MinggeData.STAT_FIELDS) do
        player[fieldName] = 0
    end
    -- petSyncRate 单独处理（不在标准 STAT_FIELDS 显示名中，但在 STAT_FIELDS 映射中）
    player.minggePetSyncRate = 0

    -- 累加已装备命格的属性
    for _, slotId in ipairs(MinggeData.ALL_SLOTS) do
        local item = manager_ and manager_:GetEquipmentItem(slotId)
        if item and item.stat and item.value then
            local fieldName = MinggeData.STAT_FIELDS[item.stat]
            if fieldName then
                player[fieldName] = (player[fieldName] or 0) + item.value
            end
        end
    end

    -- 计算套装加成
    local setBonuses = MinggeSystem._CalcSetBonuses()
    for _, bonus in ipairs(setBonuses) do
        local setDef = MinggeData.SETS[bonus.setId]
        if setDef then
            local fieldName = MinggeData.STAT_FIELDS[setDef.stat]
            if fieldName then
                player[fieldName] = (player[fieldName] or 0) + setDef.value * bonus.count
            end
        end
    end

    -- 强制缓存失效（触发 Player GetTotal* 重算）
    player._statsCacheFrame = -1

    EventBus.Emit("mingge_stats_changed")
end

--- 计算当前激活的套装加成
--- 规则：同一五行行内 3 件同套 = 1 次触发，每行独立判断
---@return table[] 激活的套装列表 { setId, element, count }
function MinggeSystem._CalcSetBonuses()
    if not manager_ then return {} end

    local bonuses = {}

    for _, element in ipairs(MinggeData.ELEMENTS) do
        local slots = MinggeData.SLOTS[element]
        -- 统计该行内各套装出现次数
        local setCount = {}
        for _, slotId in ipairs(slots) do
            local item = manager_:GetEquipmentItem(slotId)
            if item and item.setId then
                setCount[item.setId] = (setCount[item.setId] or 0) + 1
            end
        end
        -- 判断是否达到触发条件
        for setId, count in pairs(setCount) do
            if count >= MinggeData.SET_REQUIRED_PIECES then
                bonuses[#bonuses + 1] = {
                    setId = setId,
                    element = element,
                    count = 1, -- 每行最多触发一次
                }
            end
        end
    end

    return bonuses
end

--- 获取当前激活的套装加成（供 UI 显示）
---@return table[]
function MinggeSystem.GetActiveSetBonuses()
    return MinggeSystem._CalcSetBonuses()
end

--- 获取命格属性汇总（供 UI 显示）
---@return table statSummary {stat=value, ...}
function MinggeSystem.GetStatSummary()
    local summary = {}
    local player = GameState.player
    if not player then return summary end

    for statId, fieldName in pairs(MinggeData.STAT_FIELDS) do
        local val = player[fieldName] or 0
        if val ~= 0 then
            summary[statId] = val
        end
    end
    return summary
end

-- ============================================================================
-- 命格生成（供 LootSystem 调用）
-- ============================================================================

--- 生成一个命格物品
---@param bossId string BOSS 来源 ID
---@return table|nil item 生成的命格物品，nil 表示配置缺失
function MinggeSystem.GenerateItem(bossId)
    local source = MinggeData.SOURCES[bossId]
    if not source then
        print("[MinggeSystem] WARNING: Unknown bossId: " .. tostring(bossId))
        return nil
    end

    -- 1. 判定品质（按权重）
    local quality = MinggeSystem._RollQuality()

    -- 2. 判定属性值（在品质对应的区间内随机）
    local stat = source.stat
    local tier = source.tier
    local ranges = MinggeData.STAT_RANGES[tier]
    if not ranges or not ranges[stat] then
        print("[MinggeSystem] WARNING: No stat range for tier=" .. tier .. " stat=" .. stat)
        return nil
    end
    local range = ranges[stat][quality]
    if not range then
        print("[MinggeSystem] WARNING: No range for quality=" .. quality)
        return nil
    end

    local value, roll = MinggeSystem._RollValue(range[1], range[2])

    -- 3. 判定套装（仅青品质有 20% 概率）
    local setId = nil
    if quality == MinggeData.DROP_RULES.setEligibleQuality then
        if math.random() < MinggeData.DROP_RULES.setAttachChance then
            setId = MinggeData.SET_IDS[math.random(1, #MinggeData.SET_IDS)]
        end
    end

    -- 4. 构建命格 item
    local minggeId = MinggeData.GetMinggeId(bossId)
    local name = MinggeData.GetMinggeFullName(bossId, setId)
    local sellPrice = MinggeData.SELL_PRICE[tier] and MinggeData.SELL_PRICE[tier][quality] or 1

    local item = {
        category     = "mingge",
        id           = "mingge_t" .. tier .. "_" .. bossId .. "_" .. math.random(100000, 999999),
        minggeId     = minggeId,
        bossId       = bossId,
        bossName     = source.name,
        name         = name,
        element      = source.element,
        type         = source.element,  -- InventoryManager 用 type 做槽位匹配
        tier         = tier,
        quality      = quality,
        stat         = stat,
        value        = value,
        roll         = roll,
        setId        = setId,
        sellCurrency = "lingYun",
        sellPrice    = sellPrice,
        locked       = false,
    }

    return item
end

--- 品质判定（按 50/30/20 权重）
---@return string quality
function MinggeSystem._RollQuality()
    local total = 0
    for _, w in pairs(MinggeData.QUALITY_WEIGHTS) do
        total = total + w
    end
    local r = math.random(1, total)
    local acc = 0
    for _, q in ipairs(MinggeData.QUALITIES) do
        acc = acc + MinggeData.QUALITY_WEIGHTS[q]
        if r <= acc then
            return q
        end
    end
    return "purple" -- fallback
end

--- 属性值 roll（在 min~max 区间均匀随机）
--- 返回值和 roll 点（1~6000 轴）
---@param min number
---@param max number
---@return number value, number roll
function MinggeSystem._RollValue(min, max)
    -- roll 点在 1~6000 随机
    local roll = math.random(1, 6000)
    -- 线性映射到 min~max
    local t = (roll - 1) / 5999  -- 0~1
    local value = min + t * (max - min)

    -- 对于整数属性，四舍五入
    -- 对于小数属性，保留合理精度
    if max - min >= 1.0 and min == math.floor(min) then
        value = math.floor(value + 0.5)
    else
        -- 保留 4 位小数精度
        value = math.floor(value * 10000 + 0.5) / 10000
    end

    return value, roll
end

-- ============================================================================
-- 辅助查询
-- ============================================================================

--- 获取所有已装备命格
---@return table[] equipped
function MinggeSystem.GetEquippedItems()
    if not manager_ then return {} end
    local items = {}
    for _, slotId in ipairs(MinggeData.ALL_SLOTS) do
        local item = manager_:GetEquipmentItem(slotId)
        if item then
            items[#items + 1] = { slot = slotId, item = item }
        end
    end
    return items
end

--- 获取指定五行的装备情况
---@param element string
---@return table[] 该行的装备信息 { slotId, item|nil }
function MinggeSystem.GetElementSlots(element)
    if not manager_ then return {} end
    local slots = MinggeData.SLOTS[element]
    if not slots then return {} end
    local result = {}
    for _, slotId in ipairs(slots) do
        result[#result + 1] = {
            slotId = slotId,
            item = manager_:GetEquipmentItem(slotId),
        }
    end
    return result
end

--- 获取背包中所有命格物品
---@return table[] items
function MinggeSystem.GetBackpackItems()
    if not manager_ then return {} end
    local items = {}
    for i = 1, MinggeData.BACKPACK_SIZE do
        local item = manager_:GetInventoryItem(i)
        if item then
            items[#items + 1] = { index = i, item = item }
        end
    end
    return items
end

--- 获取背包中命格数量
---@return number
function MinggeSystem.GetBackpackCount()
    if not manager_ then return 0 end
    local count = 0
    for i = 1, MinggeData.BACKPACK_SIZE do
        if manager_:GetInventoryItem(i) then
            count = count + 1
        end
    end
    return count
end

--- 切换命格锁定状态
---@param slotIndex number 背包槽位
---@return boolean newState
function MinggeSystem.ToggleLock(slotIndex)
    if not manager_ then return false end
    local item = manager_:GetInventoryItem(slotIndex)
    if not item then return false end
    item.locked = not item.locked
    return item.locked
end

return MinggeSystem
