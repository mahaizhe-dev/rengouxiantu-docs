-- ============================================================================
-- ProgressionSystem.lua - 境界进阶系统
-- 支持大境界（凡人→练气、练气→筑基、筑基→金丹）和小境界（初期→中期→后期）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local ProgressionSystem = {}

--- 初始化
function ProgressionSystem.Init()
    print("[ProgressionSystem] Initialized, realms: " .. #GameConfig.REALM_LIST)
end

--- 获取玩家当前境界在 REALM_LIST 中的索引
---@param realmId string|nil
---@return integer
local function getRealmIndex(realmId)
    realmId = realmId or "mortal"
    for i, id in ipairs(GameConfig.REALM_LIST) do
        if id == realmId then return i end
    end
    return 1 -- fallback to mortal
end

--- 获取下一个可突破的境界
---@return string|nil realmId, table|nil realmData
function ProgressionSystem.GetNextBreakthrough()
    local player = GameState.player
    if not player then return nil, nil end

    local curIndex = getRealmIndex(player.realm)
    local nextIndex = curIndex + 1
    if nextIndex > #GameConfig.REALM_LIST then
        return nil, nil -- 已达最高境界
    end

    local nextId = GameConfig.REALM_LIST[nextIndex]
    local nextData = GameConfig.REALMS[nextId]
    return nextId, nextData
end

--- 检查是否满足突破条件
---@param targetRealm string 目标境界 ID
---@return boolean canBreak, string reason
function ProgressionSystem.CanBreakthrough(targetRealm)
    local player = GameState.player
    if not player then return false, "玩家不存在" end

    local targetData = GameConfig.REALMS[targetRealm]
    if not targetData then return false, "未知境界" end

    -- 检查顺序：目标必须是当前的下一个境界
    local curIndex = getRealmIndex(player.realm)
    local targetIndex = getRealmIndex(targetRealm)
    if targetIndex ~= curIndex + 1 then
        return false, "当前境界不符"
    end

    -- 检查等级
    local reqLevel = targetData.requiredLevel or 1
    if player.level < reqLevel then
        return false, "等级不足 (需要 Lv." .. reqLevel .. ")"
    end

    -- 检查消耗
    local cost = targetData.cost
    if cost then
        -- 练气丹消耗（练气阶段）
        if cost.qiPill then
            local InventorySystem = require("systems.InventorySystem")
            local pillCount = InventorySystem.CountConsumable("qi_pill")
            if pillCount < cost.qiPill then
                return false, "练气丹不足 (需要 " .. cost.qiPill .. ", 当前 " .. pillCount .. ")"
            end
        end
        -- 筑基丹消耗（筑基阶段）
        if cost.zhujiPill then
            local InventorySystem = require("systems.InventorySystem")
            local pillCount = InventorySystem.CountConsumable("zhuji_pill")
            if pillCount < cost.zhujiPill then
                return false, "筑基丹不足 (需要 " .. cost.zhujiPill .. ", 当前 " .. pillCount .. ")"
            end
        end
        -- 金丹沙消耗（金丹阶段）
        if cost.jindanSand then
            local InventorySystem = require("systems.InventorySystem")
            local sandCount = InventorySystem.CountConsumable("jindan_sand")
            if sandCount < cost.jindanSand then
                return false, "金丹沙不足 (需要 " .. cost.jindanSand .. ", 当前 " .. sandCount .. ")"
            end
        end
        -- 元婴果消耗（元婴阶段）
        if cost.yuanyingFruit then
            local InventorySystem = require("systems.InventorySystem")
            local fruitCount = InventorySystem.CountConsumable("yuanying_fruit")
            if fruitCount < cost.yuanyingFruit then
                return false, "元婴果不足 (需要 " .. cost.yuanyingFruit .. ", 当前 " .. fruitCount .. ")"
            end
        end
        -- 九转金丹消耗（化神·合体阶段）
        if cost.jiuzhuanJindan then
            local InventorySystem = require("systems.InventorySystem")
            local jdCount = InventorySystem.CountConsumable("jiuzhuan_jindan")
            if jdCount < cost.jiuzhuanJindan then
                return false, "九转金丹不足 (需要 " .. cost.jiuzhuanJindan .. ", 当前 " .. jdCount .. ")"
            end
        end
        -- 渡劫丹消耗（大乘及以上阶段）
        if cost.dujieDan then
            local InventorySystem = require("systems.InventorySystem")
            local djCount = InventorySystem.CountConsumable("dujie_dan")
            if djCount < cost.dujieDan then
                return false, "渡劫丹不足 (需要 " .. cost.dujieDan .. ", 当前 " .. djCount .. ")"
            end
        end
        -- 灵韵消耗
        if cost.lingYun and player.lingYun < cost.lingYun then
            return false, "灵韵不足 (需要 " .. cost.lingYun .. ", 当前 " .. player.lingYun .. ")"
        end
        if cost.gold and player.gold < cost.gold then
            return false, "金币不足 (需要 " .. cost.gold .. ", 当前 " .. player.gold .. ")"
        end
    end

    return true, ""
end

--- 执行突破
---@param targetRealm string 目标境界 ID
---@return boolean success, string message
function ProgressionSystem.Breakthrough(targetRealm)
    local canBreak, reason = ProgressionSystem.CanBreakthrough(targetRealm)
    if not canBreak then
        return false, reason
    end

    local targetData = GameConfig.REALMS[targetRealm]
    local player = GameState.player

    -- 扣除资源
    local cost = targetData.cost
    if cost then
        if cost.qiPill then
            local InventorySystem = require("systems.InventorySystem")
            InventorySystem.ConsumeConsumable("qi_pill", cost.qiPill)
        end
        if cost.zhujiPill then
            local InventorySystem = require("systems.InventorySystem")
            InventorySystem.ConsumeConsumable("zhuji_pill", cost.zhujiPill)
        end
        if cost.jindanSand then
            local InventorySystem = require("systems.InventorySystem")
            InventorySystem.ConsumeConsumable("jindan_sand", cost.jindanSand)
        end
        if cost.yuanyingFruit then
            local InventorySystem = require("systems.InventorySystem")
            InventorySystem.ConsumeConsumable("yuanying_fruit", cost.yuanyingFruit)
        end
        if cost.jiuzhuanJindan then
            local InventorySystem = require("systems.InventorySystem")
            InventorySystem.ConsumeConsumable("jiuzhuan_jindan", cost.jiuzhuanJindan)
        end
        if cost.dujieDan then
            local InventorySystem = require("systems.InventorySystem")
            InventorySystem.ConsumeConsumable("dujie_dan", cost.dujieDan)
        end
        if cost.lingYun then
            player.lingYun = player.lingYun - cost.lingYun
        end
        if cost.gold then
            player.gold = player.gold - cost.gold
        end
    end

    -- 更新境界
    local oldRealm = player.realm
    player.realm = targetRealm

    -- 应用攻速加成（累计值，直接设置）
    player.realmAtkSpeedBonus = targetData.attackSpeedBonus or 0

    -- 应用固定属性奖励
    local rewards = targetData.rewards
    if rewards then
        player.maxHp = player.maxHp + (rewards.maxHp or 0)
        player.atk = player.atk + (rewards.atk or 0)
        player.def = player.def + (rewards.def or 0)
        player.hpRegen = player.hpRegen + (rewards.hpRegen or 0)
    end

    -- 回满血
    player.hp = player:GetTotalMaxHp()

    EventBus.Emit("realm_breakthrough", oldRealm, targetRealm)

    -- 先人一步道印：突破化神/合体时尝试竞速解锁（大境界首个子境界触发）
    local AtlasSystem = require("systems.AtlasSystem")
    if targetRealm == "huashen_1" then
        AtlasSystem.TryUnlockRace("pioneer_huashen")
    elseif targetRealm == "heti_1" then
        AtlasSystem.TryUnlockRace("pioneer_heti")
    end

    EventBus.Emit("save_request")  -- 境界突破消耗大量资源，即时存档

    local realmName = targetData.name or targetRealm
    local typeStr = targetData.isMajor and "大境界" or "小境界"
    print("[Progression] " .. typeStr .. " Breakthrough! " .. oldRealm .. " -> " .. targetRealm .. " (" .. realmName .. ")")

    return true, "突破成功！进入" .. realmName .. "！"
end

--- 获取当前境界信息
---@return table
function ProgressionSystem.GetRealmInfo()
    local player = GameState.player
    if not player then return {} end

    local realmData = GameConfig.REALMS[player.realm] or {}
    return {
        id = player.realm,
        name = realmData.name or "未知",
        maxLevel = realmData.maxLevel or 10,
        level = player.level,
        isMajor = realmData.isMajor or false,
        attackSpeedBonus = realmData.attackSpeedBonus or 0,
    }
end

--- 格式化突破奖励文本
---@param realmData table
---@return string
function ProgressionSystem.FormatRewards(realmData)
    if not realmData then return "" end
    local parts = {}
    local r = realmData.rewards
    if r then
        if r.maxHp and r.maxHp > 0 then parts[#parts + 1] = "❤+" .. r.maxHp end
        if r.atk and r.atk > 0 then parts[#parts + 1] = "⚔+" .. r.atk end
        if r.def and r.def > 0 then parts[#parts + 1] = "🛡+" .. r.def end
        if r.hpRegen and r.hpRegen > 0 then parts[#parts + 1] = "💨+" .. r.hpRegen end
    end
    -- 大境界额外显示攻速
    if realmData.isMajor then
        local prevBonus = ProgressionSystem.GetPrevAttackSpeedBonus(realmData)
        local gain = (realmData.attackSpeedBonus or 0) - prevBonus
        if gain > 0 then
            parts[#parts + 1] = "⚡攻速+" .. math.floor(gain * 100 + 0.5) .. "%"
        end
    end
    return table.concat(parts, "  ")
end

--- 获取上一个大境界的攻速加成（用于计算增量）
---@param realmData table
---@return number
function ProgressionSystem.GetPrevAttackSpeedBonus(realmData)
    local order = realmData.order or 0
    -- 向前找上一个境界
    if order <= 1 then return 0 end
    local prevId = GameConfig.REALM_LIST[order] -- order是从0开始, REALM_LIST从1开始, 所以[order]就是前一个
    if prevId then
        local prev = GameConfig.REALMS[prevId]
        if prev then return prev.attackSpeedBonus or 0 end
    end
    return 0
end

return ProgressionSystem
