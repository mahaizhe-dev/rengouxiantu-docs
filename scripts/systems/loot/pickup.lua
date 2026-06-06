-- ============================================================================
-- loot/pickup.lua - 自动拾取 + 宠物拾取 + 掉落物计时
-- ============================================================================

local shared = require("systems.loot.shared")

local GameConfig = shared.GameConfig
local GameState  = shared.GameState
local EventBus   = shared.EventBus
local Utils      = shared.Utils
local IconUtils  = shared.IconUtils

local M = {}

-- ── 拾取常量 ──
local MAGNET_RANGE = 1.2
local MAGNET_RANGE_SQ = MAGNET_RANGE * MAGNET_RANGE
local MAGNET_SPEED = 8.0
local PICKUP_ARRIVE_DIST = 0.3
local PICKUP_ARRIVE_DIST_SQ = PICKUP_ARRIVE_DIST * PICKUP_ARRIVE_DIST
local LOOT_PICKUP_RANGE_SQ = GameConfig.LOOT_PICKUP_RANGE * GameConfig.LOOT_PICKUP_RANGE
local PET_PICKUP_RANGE_SQ = GameConfig.PET_PICKUP_RANGE * GameConfig.PET_PICKUP_RANGE

-- ============================================================================
-- 自动拾取（玩家）
-- ============================================================================

--- 自动拾取范围内的掉落物（带磁吸飞行效果）
---@param player table
---@param dt number
function M.AutoPickup(player, dt)
    dt = dt or 0.016
    local InventorySystem = require("systems.InventorySystem")

    local freeSlots = InventorySystem.GetFreeSlots()

    for i = #GameState.lootDrops, 1, -1 do
        local drop = GameState.lootDrops[i]
        local distSq = Utils.DistanceSq(player.x, player.y, drop.x, drop.y)

        if drop.partialLooted then goto continue_drop end

        -- 含装备的掉落物：背包满时不磁吸、不拾取
        if drop.items and #drop.items > 0 then
            if freeSlots < #drop.items then
                -- 如果已在磁吸中，回退到原始位置
                if drop.magnetized then
                    drop.x = drop.originX or drop.x
                    drop.y = drop.originY or drop.y
                    drop.magnetized = false
                end
                if distSq <= MAGNET_RANGE_SQ then
                    if not drop.fullHintTime or (time.elapsedTime - drop.fullHintTime > 2.0) then
                        drop.fullHintTime = time.elapsedTime
                        local CombatSystem = require("systems.CombatSystem")
                        CombatSystem.AddFloatingText(
                            player.x, player.y - 0.5,
                            "背包已满", {255, 100, 100, 255}, 1.5
                        )
                    end
                end
                goto continue_drop
            end
        end

        -- 含命格的掉落物：背包满时不磁吸、不拾取（与装备一致）
        if drop.mingges and #drop.mingges > 0 then
            local MinggeSystem = require("systems.MinggeSystem")
            if MinggeSystem.GetFreeSlots() < #drop.mingges then
                -- 如果已在磁吸中，回退到原始位置
                if drop.magnetized then
                    drop.x = drop.originX or drop.x
                    drop.y = drop.originY or drop.y
                    drop.magnetized = false
                end
                if distSq <= MAGNET_RANGE_SQ then
                    if not drop._minggeFullHintTime or (time.elapsedTime - drop._minggeFullHintTime > 2.0) then
                        drop._minggeFullHintTime = time.elapsedTime
                        local CombatSystem = require("systems.CombatSystem")
                        CombatSystem.AddFloatingText(
                            player.x, player.y - 0.5,
                            "命格背包已满", {255, 100, 100, 255}, 1.5
                        )
                    end
                end
                goto continue_drop
            end
        end

        -- 磁吸阶段
        if distSq <= MAGNET_RANGE_SQ and not drop.magnetized then
            drop.magnetized = true
            drop.originX = drop.x
            drop.originY = drop.y
        end

        if drop.magnetized then
            local dx = player.x - drop.x
            local dy = player.y - drop.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > PICKUP_ARRIVE_DIST then
                local speed = MAGNET_SPEED * (1.0 + (1.0 - d / MAGNET_RANGE) * 2.0)
                drop.x = drop.x + (dx / d) * speed * dt
                drop.y = drop.y + (dy / d) * speed * dt
            else
                distSq = 0
            end
        end

        if distSq <= PICKUP_ARRIVE_DIST_SQ or (not drop.magnetized and distSq <= LOOT_PICKUP_RANGE_SQ) then
            -- 经验
            if drop.expReward and drop.expReward > 0 then
                local expBonus = player:GetKillExpBonus()
                player:GainExp(drop.expReward + expBonus)
            end
            -- 金币
            if drop.goldMin and drop.goldMax then
                local gold = Utils.RandomInt(drop.goldMin, drop.goldMax)
                local killGoldBonus = player:GetKillGoldBonus()
                if killGoldBonus > 0 then
                    gold = gold + killGoldBonus
                end
                player:GainGold(gold)
            end
            -- 灵韵
            if drop.lingYun and drop.lingYun > 0 then
                local totalLingYun = drop.lingYun
                local guaranteed, chance = player:GetFortuneLingYunBonus()
                local extra = guaranteed + (chance > 0 and math.random() < chance and 1 or 0)
                totalLingYun = totalLingYun + extra
                player:GainLingYun(totalLingYun)
                local CombatSystem = require("systems.CombatSystem")
                local displayText = "+" .. totalLingYun .. " 💎"
                if extra > 0 then
                    displayText = displayText .. " (福缘+" .. extra .. ")"
                end
                CombatSystem.AddFloatingText(
                    drop.x, drop.y - 0.5,
                    displayText,
                    {200, 150, 255, 255}, 1.8
                )
                local LingYunFx = require("rendering.LingYunFx")
                LingYunFx.QueuePickup(drop.x, drop.y, totalLingYun)
            end
            -- 消耗品
            local hasConsumableFailure = false
            local hasFragmentPickup = false
            if drop.consumables then
                local CombatSystem = require("systems.CombatSystem")
                for cId, cAmount in pairs(drop.consumables) do
                    local ok, added = InventorySystem.AddConsumable(cId, cAmount)
                    local cData = GameConfig.PET_FOOD[cId] or GameConfig.PET_MATERIALS[cId] or GameConfig.EVENT_ITEMS[cId]
                    local PetSkillData = require("config.PetSkillData")
                    local bookData = PetSkillData.SKILL_BOOKS[cId]
                    cData = cData or bookData

                    if added > 0 then
                        if cData then
                            local icon = IconUtils.GetTextIcon(cData.icon, "💊")
                            CombatSystem.AddFloatingText(
                                drop.x, drop.y - 0.5,
                                icon .. " " .. cData.name .. (added > 1 and ("×" .. added) or ""),
                                {180, 255, 180, 255}, 2.0
                            )
                        end
                        if string.find(cId, "_fragment_") then
                            hasFragmentPickup = true
                        end
                        -- 掉落音判定（A~E类消耗品：碎片/丹药/灵韵果/黑市等）
                        local AudioSystem = require("systems.AudioSystem")
                        AudioSystem.CheckAndPlayForConsumable(cId)

                        local remaining = cAmount - added
                        if remaining <= 0 then
                            drop.consumables[cId] = nil
                        else
                            drop.consumables[cId] = remaining
                        end
                    end

                    if not ok then
                        hasConsumableFailure = true
                        if cData then
                            CombatSystem.AddFloatingText(
                                drop.x, drop.y - 0.5,
                                cData.name .. " 堆叠已满",
                                {255, 100, 100, 255}, 2.0
                            )
                        end
                    end
                end
                if not next(drop.consumables) then
                    drop.consumables = nil
                end
            end
            -- 神器碎片存档
            if hasFragmentPickup then
                print("[Pickup] Artifact fragment acquired, requesting save")
                EventBus.Emit("save_request")
            end
            -- 装备
            if drop.items and #drop.items > 0 then
                local CombatSystem = require("systems.CombatSystem")
                for _, item in ipairs(drop.items) do
                    local ok = InventorySystem.AddItem(item)
                    if ok then
                        freeSlots = freeSlots - 1
                        local qColor = GameConfig.QUALITY[item.quality]
                        local qName = qColor and qColor.name or "普通"
                        print("[Pickup] Got equipment: [" .. qName .. "] " .. item.name)
                        CombatSystem.AddFloatingText(
                            drop.x, drop.y - 0.3,
                            item.name,
                            qColor and qColor.color or {255, 255, 255, 255},
                            2.0
                        )
                        -- 掉落音判定（B类灵器+/E类专属/黑市装备）
                        local AudioSystem = require("systems.AudioSystem")
                        AudioSystem.CheckAndPlayForItem(item)
                        if item.isSpecial then
                            print("[Pickup] Special equipment acquired, requesting save: " .. item.name)
                            EventBus.Emit("save_request")
                        end
                    end
                end
            end
            -- 命格（前置拦截已确保有空位，与装备一致直接添加）
            if drop.mingges and #drop.mingges > 0 then
                local MinggeSystem = require("systems.MinggeSystem")
                local CombatSystem = require("systems.CombatSystem")
                local MinggeData = require("config.MinggeData")
                for _, mItem in ipairs(drop.mingges) do
                    MinggeSystem.AddItem(mItem)
                    local qColor = MinggeData.QUALITY_COLORS[mItem.quality] or {200, 200, 200, 255}
                    CombatSystem.AddFloatingText(
                        drop.x, drop.y - 0.3,
                        mItem.name,
                        qColor,
                        2.0
                    )
                end
            end
            -- 移除或标记
            if hasConsumableFailure then
                drop.partialLooted = true
                drop.expReward = nil
                drop.goldMin = nil
                drop.goldMax = nil
                drop.lingYun = nil
            else
                table.remove(GameState.lootDrops, i)
            end
        end
        ::continue_drop::
    end
end

-- ============================================================================
-- 宠物拾取
-- ============================================================================

--- 查找宠物可捡的最近掉落物
---@param petX number
---@param petY number
---@param blacklist table|nil
---@return table|nil
function M.FindPetPickable(petX, petY, blacklist)
    local bestDrop = nil
    local bestDistSq = PET_PICKUP_RANGE_SQ

    for _, drop in ipairs(GameState.lootDrops) do
        local age = time.elapsedTime - (drop.spawnTime or 0)
        if age < GameConfig.PET_PICKUP_DELAY then goto next_drop end
        if drop.magnetized then goto next_drop end
        if drop.items and #drop.items > 0 then goto next_drop end
        if drop.mingges and #drop.mingges > 0 then goto next_drop end
        if blacklist and blacklist[drop.id] then goto next_drop end

        local distSq = Utils.DistanceSq(petX, petY, drop.x, drop.y)
        if distSq < bestDistSq then
            bestDistSq = distSq
            bestDrop = drop
        end
        ::next_drop::
    end
    return bestDrop
end

--- 宠物执行拾取
---@param player table
---@param drop table
---@return boolean
function M.PetPickup(player, drop)
    local InventorySystem = require("systems.InventorySystem")
    local CombatSystem = require("systems.CombatSystem")

    if drop.items and #drop.items > 0 then return false end
    if drop.mingges and #drop.mingges > 0 then return false end

    -- 经验
    if drop.expReward and drop.expReward > 0 then
        local expBonus = player:GetKillExpBonus()
        player:GainExp(drop.expReward + expBonus)
        drop.expReward = nil
    end

    -- 金币
    if drop.goldMin and drop.goldMax then
        local gold = Utils.RandomInt(drop.goldMin, drop.goldMax)
        local killGoldBonus = player:GetKillGoldBonus()
        if killGoldBonus > 0 then
            gold = gold + killGoldBonus
        end
        player:GainGold(gold)
        drop.goldMin = nil
        drop.goldMax = nil
    end

    -- 灵韵
    if drop.lingYun and drop.lingYun > 0 then
        local totalLingYun = drop.lingYun
        local guaranteed, chance = player:GetFortuneLingYunBonus()
        local extra = guaranteed + (chance > 0 and math.random() < chance and 1 or 0)
        totalLingYun = totalLingYun + extra
        player:GainLingYun(totalLingYun)
        local displayText = "+" .. totalLingYun .. " 💎"
        if extra > 0 then
            displayText = displayText .. " (福缘+" .. extra .. ")"
        end
        CombatSystem.AddFloatingText(
            drop.x, drop.y - 0.5,
            displayText,
            {200, 150, 255, 255}, 1.8
        )
        local LingYunFx = require("rendering.LingYunFx")
        LingYunFx.QueuePickup(drop.x, drop.y, totalLingYun)
        drop.lingYun = nil
    end

    -- 消耗品
    local hasConsumableFailure = false
    local hasFragmentPickup = false
    if drop.consumables then
        for cId, cAmount in pairs(drop.consumables) do
            local ok, added = InventorySystem.AddConsumable(cId, cAmount)
            local cData = GameConfig.PET_FOOD[cId] or GameConfig.PET_MATERIALS[cId]
            local PetSkillData = require("config.PetSkillData")
            local bookData = PetSkillData.SKILL_BOOKS[cId]
            cData = cData or bookData

            if added > 0 then
                if cData then
                    local icon = IconUtils.GetTextIcon(cData.icon, "💊")
                    CombatSystem.AddFloatingText(
                        drop.x, drop.y - 0.5,
                        icon .. " " .. cData.name .. (added > 1 and ("×" .. added) or ""),
                        {180, 255, 180, 255}, 2.0
                    )
                end
                if string.find(cId, "_fragment_") then
                    hasFragmentPickup = true
                end
                -- 掉落音判定（A~E类消耗品：碎片/丹药/灵韵果/黑市等）
                local AudioSystem = require("systems.AudioSystem")
                AudioSystem.CheckAndPlayForConsumable(cId)
                local remaining = cAmount - added
                if remaining <= 0 then
                    drop.consumables[cId] = nil
                else
                    drop.consumables[cId] = remaining
                end
            end

            if not ok then
                hasConsumableFailure = true
                if cData then
                    CombatSystem.AddFloatingText(
                        drop.x, drop.y - 0.5,
                        cData.name .. " 堆叠已满",
                        {255, 100, 100, 255}, 2.0
                    )
                end
            end
        end
        if not next(drop.consumables) then
            drop.consumables = nil
        end
    end
    -- 神器碎片存档
    if hasFragmentPickup then
        print("[PetPickup] Artifact fragment acquired, requesting save")
        EventBus.Emit("save_request")
    end

    -- 判断是否完全拾取
    if not hasConsumableFailure then
        for i = #GameState.lootDrops, 1, -1 do
            if GameState.lootDrops[i].id == drop.id then
                table.remove(GameState.lootDrops, i)
                break
            end
        end
        return true
    else
        drop.partialLooted = true
        return false
    end
end

-- ============================================================================
-- 掉落物计时器
-- ============================================================================

--- 更新掉落物过期计时
---@param dt number
function M.UpdateTimers(dt)
    for i = #GameState.lootDrops, 1, -1 do
        local drop = GameState.lootDrops[i]
        drop.timer = drop.timer - dt
        if drop.timer <= 0 then
            table.remove(GameState.lootDrops, i)
        end
    end
end

return M
