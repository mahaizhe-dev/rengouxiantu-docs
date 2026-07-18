-- ============================================================================
-- challenge/rewards.lua - 怪物死亡处理与奖励发放
-- ============================================================================

local shared = require("systems.challenge.shared")
local GameConfig = shared.GameConfig
local GameState = shared.GameState
local EventBus = shared.EventBus
local ChallengeConfig = shared.ChallengeConfig
local LEGACY_PILL_CONFIG = shared.LEGACY_PILL_CONFIG

local M = {}

--- 击杀挑战 BOSS 后立即停止残留伤害，奖励选择期间不再发生胜负翻转
function M.StopVictoryCombat()
    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.ClearEffects()
    CombatSystem.ClearChallengeStatusEffects()

    local player = GameState.player
    if player and player.SetMoveDirection then
        player:SetMoveDirection(0, 0)
    end
end

-- ============================================================================
-- 怪物死亡处理
-- ============================================================================

function M.OnMonsterDeath(CS, monster)
    if not CS.active then return end
    if monster ~= CS.challengeMonster then return end

    local faction = CS.currentFaction
    if not faction then return end

    -- 新版声望路径
    if CS.currentRepLevel then
        M._onRepMonsterDeath(CS, faction, CS.currentRepLevel)
        return
    end

    -- 旧版 tier 路径
    local tier = CS.currentTier
    if not tier then return end

    local factionCfg = ChallengeConfig.FACTIONS[faction]
    local tierCfg = factionCfg and factionCfg.tiers[tier]
    if not tierCfg then return end

    local ChallengeSystem = require("systems.ChallengeSystem")
    local progress = ChallengeSystem.GetProgress(faction, tier)
    local isFirstClear = progress and not progress.completed

    if progress then
        progress.completed = true
    end
    M.StopVictoryCombat()

    -- 挑战过程中不存档：completed 仅在内存中标记
    -- 入场时已存档（令牌扣除已持久化），奖励领取时再统一存档
    -- 这样强退/重启 = 令牌已消耗 + completed 未持久化 = 需重新挑战

    -- 非首通时判定重复掉落
    local repeatDropResult = nil
    if not isFirstClear and tierCfg.repeatDrop then
        local roll = math.random()
        if roll < tierCfg.repeatDrop.chance then
            repeatDropResult = tierCfg.repeatDrop
            print("[ChallengeSystem] RepeatDrop HIT: " .. tierCfg.repeatDrop.label)
        end
    end

    EventBus.Emit("challenge_victory", {
        faction = faction,
        tier = tier,
        isFirstClear = isFirstClear,
        tierCfg = tierCfg,
        factionCfg = factionCfg,
        repeatDropResult = repeatDropResult,
    })

    print("[ChallengeSystem] Monster defeated: " .. faction .. " T" .. tier
        .. ", firstClear=" .. tostring(isFirstClear))
end

--- 新版声望怪物死亡处理
---@param CS table ChallengeSystem
---@param factionKey string
---@param repLevel number 1-9
function M._onRepMonsterDeath(CS, factionKey, repLevel)
    local factionCfg = ChallengeConfig.FACTIONS[factionKey]
    if not factionCfg or not factionCfg.reputation then return end

    local repCfg = factionCfg.reputation[repLevel]
    if not repCfg then return end

    local ChallengeSystem = require("systems.ChallengeSystem")
    local progress = ChallengeSystem.GetReputationProgress(factionKey, repLevel)
    local isFirstClear = progress and not progress.unlocked == false and not progress.completed

    if progress then
        progress.completed = true
    end
    M.StopVictoryCombat()

    -- 挑战过程中不存档：completed 仅在内存中标记
    -- 入场时已存档（令牌扣除已持久化），奖励领取时再统一存档
    -- 强退/重启 = 令牌已消耗 + completed 未持久化 = 需重新挑战 + 重新打BOSS

    local LootSystem = require("systems.LootSystem")
    local tier = repCfg.tier
    local templateId = factionCfg.fabaoTplId

    -- 预生成2件法宝供玩家二选一
    local choices = {}  -- { fabaoA, fabaoB_or_item }

    if isFirstClear then
        -- 首通：两件保底品质法宝，不触发物品掉落
        local quality = ChallengeConfig.GetFirstClearQuality(repLevel)
        local fabaoA = LootSystem.CreateFabaoEquipment(templateId, tier, quality)
        local fabaoB = LootSystem.CreateFabaoEquipment(templateId, tier, quality)
        choices = { fabaoA, fabaoB }
        print("[ChallengeSystem] FirstClear: generated 2 fabao T" .. tier .. " quality=" .. quality)
    else
        -- 非首通：固定2件随机法宝 + 额外掉落判定第3候选
        local rollOpts = {
            minQuality = ChallengeConfig.GetRandomMinQuality(repLevel),
            maxQuality = ChallengeConfig.GetRandomMaxQuality(repLevel),
        }
        local fabaoA = LootSystem.CreateFabaoEquipment(templateId, tier, nil, rollOpts)
        local fabaoB = LootSystem.CreateFabaoEquipment(templateId, tier, nil, rollOpts)
        choices = { fabaoA, fabaoB }

        -- 额外掉落判定：按显式概率表 roll
        local extraDropChance = ChallengeConfig.GetExtraDropChance(repLevel)
        local roll = math.random()
        if roll < extraDropChance then
            local extraEntry = ChallengeConfig.RollExtraDropEntry(repLevel)
            if extraEntry then
                local itemDrop = M._buildExtraDropItem(extraEntry)
                choices[3] = itemDrop
                print("[ChallengeSystem] ExtraDrop HIT: " .. (itemDrop and itemDrop.desc or "?")
                    .. " (roll=" .. string.format("%.4f", roll) .. " < " .. string.format("%.4f", extraDropChance) .. ")")
            end
        else
            print("[ChallengeSystem] ExtraDrop MISS (roll=" .. string.format("%.4f", roll)
                .. " >= " .. string.format("%.4f", extraDropChance) .. ")")
        end
    end

    EventBus.Emit("challenge_victory", {
        faction = factionKey,
        repLevel = repLevel,
        isFirstClear = isFirstClear,
        repCfg = repCfg,
        factionCfg = factionCfg,
        choices = choices,        -- { item1, item2 } 预生成的二选一
        isReputation = true,
    })

    print("[ChallengeSystem] Rep monster defeated: " .. factionKey .. " rep" .. repLevel
        .. ", firstClear=" .. tostring(isFirstClear))
end

--- 将 RollExtraDropEntry 的结果转换为 UI 展示用的物品对象
---@param entry table { type, count, subId? }
---@return table { type, consumableId?, essenceId?, count, desc, isFabao=false }
function M._buildExtraDropItem(entry)
    local t = entry.type
    local count = entry.count or 1

    if t == "gold_bar" then
        return { type = "gold_bar", consumableId = "gold_bar", count = count, desc = "金条 ×" .. count }

    elseif t == "food" then
        local foodId = entry.subId or "beast_meat"
        local foodName = GameConfig.CONSUMABLES[foodId] and GameConfig.CONSUMABLES[foodId].name or foodId
        return { type = "food", consumableId = foodId, count = count, desc = foodName .. " ×" .. count }

    elseif t == "essence" then
        local essId = entry.subId or "qingyun_essence"
        local essName = GameConfig.PET_MATERIALS and GameConfig.PET_MATERIALS[essId]
            and GameConfig.PET_MATERIALS[essId].name or essId
        return { type = "essence", essenceId = essId, count = count, desc = essName .. " ×" .. count }

    elseif t == "cultivation_fruit" then
        return { type = "cultivation_fruit", consumableId = "exp_pill", count = count, desc = "修炼果 ×" .. count }

    elseif t == "lingyun_fruit" then
        return { type = "lingyun_fruit", consumableId = "lingyun_fruit", count = count, desc = "灵韵果 ×" .. count }
    end

    -- fallback
    return { type = "gold_bar", consumableId = "gold_bar", count = 1, desc = "金条 ×1" }
end

-- [LEGACY] 旧接口保留，供旧代码兼容
---@deprecated 使用 _buildExtraDropItem + ChallengeConfig.RollExtraDropEntry 代替
function M._rollExtraDrop(CS, repLevel)
    local entry = ChallengeConfig.RollExtraDropEntry(repLevel)
    if entry then
        return M._buildExtraDropItem(entry)
    end
    return { type = "gold_bar", consumableId = "gold_bar", count = 1, desc = "金条 ×1" }
end

-- ============================================================================
-- 奖励发放（新版声望）
-- ============================================================================

--- 发放玩家选中的奖励（二选一后调用）
--- selectedItem 可能是法宝（isFabao=true）或物品掉落（type字段）
---@param CS table ChallengeSystem
---@param selectedItem table 玩家选中的物品
---@param isFirstClear boolean
function M.GrantReputationChoice(CS, selectedItem, isFirstClear)
    if not selectedItem then return end

    -- 物品掉落（非法宝）
    if not selectedItem.isFabao then
        M._grantExtraDrop(CS, selectedItem)
        -- 立即存档（防止掉线/强退丢失奖励）
        EventBus.Emit("save_request")
        return
    end

    -- 法宝：加入背包
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return end

    selectedItem.type = selectedItem.slot or "exclusive"
    local success, idx = mgr:AddToInventory(selectedItem)

    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player
    local label = isFirstClear and "首通奖励：" or "挑战奖励："

    if success then
        EventBus.Emit("inventory_item_added", selectedItem, idx)
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                label .. (selectedItem.name or "法宝"),
                {255, 215, 0, 255}, 4.0
            )
        end
        print("[ChallengeSystem] GrantChoice fabao: " .. (selectedItem.name or "?"))
    else
        table.insert(GameState.pendingItems, selectedItem)
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                "背包已满！法宝已暂存",
                {255, 150, 50, 255}, 3.0
            )
        end
    end

    -- 立即存档（防止掉线/强退丢失奖励）
    EventBus.Emit("save_request")
end

--- 发放物品掉落
---@param CS table ChallengeSystem (unused but kept for signature consistency)
---@param drop table { type, consumableId, essenceId, count, desc }
function M._grantExtraDrop(CS, drop)
    local InventorySystem = require("systems.InventorySystem")
    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player

    if drop.type == "essence" then
        -- 精华存入背包（与其他消耗品统一管理）
        local essId = drop.essenceId
        if essId then
            InventorySystem.AddConsumable(essId, drop.count or 1)
            print("[ChallengeSystem] Essence gained (backpack): " .. essId .. " x" .. (drop.count or 1))
        end
    else
        -- 其他消耗品存入背包
        if drop.consumableId then
            local ok = InventorySystem.AddConsumable(drop.consumableId, drop.count or 1)
            if ok then
                print("[ChallengeSystem] Drop gained: " .. drop.consumableId .. " x" .. (drop.count or 1))
            else
                print("[ChallengeSystem] WARNING: AddConsumable FAILED for " .. drop.consumableId .. " (backpack full or unregistered)")
            end
        end
    end

    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 2.5,
            "物品掉落：" .. (drop.desc or "?"),
            {255, 180, 50, 255}, 4.0
        )
    end
end

-- ============================================================================
-- 奖励发放（旧版 tiers）[LEGACY: 仅供存量玩家兼容，新功能禁止调用]
-- ============================================================================

-- [LEGACY: 旧版tier挑战，仅供存量玩家兼容，新功能禁止调用]
---@deprecated 新版使用 GrantReputationChoice
function M.GrantReward(CS, faction, tier, reward)
    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player

    if reward.type == "equipment" then
        local LootSystem = require("systems.LootSystem")
        local item = LootSystem.CreateSpecialEquipment(reward.equipId)
        if item then
            local InventorySystem = require("systems.InventorySystem")
            local mgr = InventorySystem.GetManager()
            if mgr then
                item.type = item.slot or "weapon"
                local success, idx = mgr:AddToInventory(item)
                if success then
                    EventBus.Emit("inventory_item_added", item, idx)
                    if player then
                        CombatSystem.AddFloatingText(
                            player.x, player.y - 2.0,
                            "首通奖励：" .. reward.label,
                            {255, 215, 0, 255}, 4.0
                        )
                    end
                else
                    table.insert(GameState.pendingItems, item)
                    if player then
                        CombatSystem.AddFloatingText(
                            player.x, player.y - 2.0,
                            "背包已满！装备已暂存",
                            {255, 150, 50, 255}, 3.0
                        )
                    end
                end
            end
        end

    elseif reward.type == "pill" then
        local pillCfg = LEGACY_PILL_CONFIG[reward.pillId]
        if pillCfg and player then
            local count = reward.count or 1
            for i = 1, count do
                local used = CS[pillCfg.countField]
                if used < pillCfg.maxUse then
                    for _, b in ipairs(pillCfg.bonuses) do
                        player[b.stat] = (player[b.stat] or 0) + b.bonus
                    end
                    CS[pillCfg.countField] = used + 1
                    if player.pillCounts and reward.pillId then
                        local pcKey = reward.pillId:gsub("_dan$", "")
                        player.pillCounts[pcKey] = CS[pillCfg.countField]
                    end
                end
            end

            for _, b in ipairs(pillCfg.bonuses) do
                if b.stat == "maxHp" then
                    player.hp = math.min(player.hp + b.bonus * (reward.count or 1), player:GetTotalMaxHp())
                end
            end

            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                "首通奖励：" .. pillCfg.name .. "（" .. pillCfg.effectDesc .. "）",
                {255, 215, 0, 255}, 4.0
            )
        end
    end
end

-- [LEGACY: 旧版tier挑战，仅供存量玩家兼容，新功能禁止调用]
---@deprecated 新版使用 GrantReputationChoice
function M.GrantRepeatDrop(CS, repeatDrop)
    local CombatSystem = require("systems.CombatSystem")
    local LootSystem = require("systems.LootSystem")
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player

    local item = LootSystem.CreateSpecialEquipment(repeatDrop.equipId)
    if not item then return end

    item.type = item.slot or "weapon"
    local mgr = InventorySystem.GetManager()
    if not mgr then return end

    local success, idx = mgr:AddToInventory(item)
    if success then
        EventBus.Emit("inventory_item_added", item, idx)
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                "物品掉落：" .. repeatDrop.label,
                {255, 180, 50, 255}, 4.0
            )
        end
    else
        table.insert(GameState.pendingItems, item)
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                "背包已满！装备已暂存",
                {255, 150, 50, 255}, 3.0
            )
        end
    end
end

return M
