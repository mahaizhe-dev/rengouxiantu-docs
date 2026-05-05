-- ============================================================================
-- QuestSystem.lua - 区域主线任务系统
-- 管理任务进度、击杀追踪、奖励发放、封印状态
-- ============================================================================

local QuestData = require("config.QuestData")
local ActiveZoneData = require("config.ActiveZoneData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CombatSystem = require("systems.CombatSystem")
local Utils = require("core.Utils")
local EquipmentUtils = require("utils.EquipmentUtils")

local QuestSystem = {}

-- 运行时状态
-- questStates[chainId] = { currentStep = 1, kills = {}, completed = false }
local questStates_ = {}

-- 封印状态
-- sealStates_[zoneId] = true(已解封) / false(未解封)
local sealStates_ = {}

-- 封印提示冷却（避免频繁提示）
local sealPromptCooldown_ = 0

--- 判断封印是否属于当前章节（通过其 questChain 的 zone 判断）
--- 修复：fortress_gate 不是 region key，需要通过 questChain.zone 间接查找
---@param sealData table
---@return boolean
local function IsSealInCurrentChapter(sealData)
    local regions = ActiveZoneData.Get().Regions
    local chain = QuestData.ZONE_QUESTS[sealData.questChain]
    if chain and chain.zone then
        return regions[chain.zone] ~= nil
    end
    return false
end

-- 延迟加载
local LootSystem_ = nil
local EquipmentData_ = nil

local function GetLootSystem()
    if not LootSystem_ then LootSystem_ = require("systems.LootSystem") end
    return LootSystem_
end

local function GetEquipmentData()
    if not EquipmentData_ then EquipmentData_ = require("config.EquipmentData") end
    return EquipmentData_
end

--- 初始化任务系统
function QuestSystem.Init()
    -- 合并第二章、第三章任务数据（各章完全独立的数据文件）
    local chapterModules = {
        { name = "config.QuestData_ch2", label = "Ch2" },
        { name = "config.QuestData_ch3", label = "Ch3" },
        { name = "config.QuestData_ch4", label = "Ch4" },
        { name = "config.QuestData_mz",  label = "MZ" },
    }
    for _, chMod in ipairs(chapterModules) do
        local ok, chData = pcall(require, chMod.name)
        if ok and chData then
            for chainId, chain in pairs(chData.ZONE_QUESTS or {}) do
                if QuestData.ZONE_QUESTS[chainId] then
                    print("[QuestSystem] WARNING: chainId collision on merge: '" .. chainId .. "' (" .. chMod.label .. " overwrites!)")
                end
                QuestData.ZONE_QUESTS[chainId] = chain
            end
            for zoneId, seal in pairs(chData.SEALS or {}) do
                if QuestData.SEALS[zoneId] then
                    print("[QuestSystem] WARNING: sealId collision on merge: '" .. zoneId .. "' (" .. chMod.label .. " overwrites!)")
                end
                QuestData.SEALS[zoneId] = seal
            end
            print("[QuestSystem] " .. chMod.label .. " quest data merged")
        end
    end

    -- 为所有区域主线创建初始状态
    for chainId, chain in pairs(QuestData.ZONE_QUESTS) do
        if not questStates_[chainId] then
            questStates_[chainId] = {
                currentStep = 1,
                kills = {},
                completed = false,
            }
        end
    end

    -- 初始化封印状态
    for zoneId, _ in pairs(QuestData.SEALS) do
        if sealStates_[zoneId] == nil then
            sealStates_[zoneId] = false
        end
    end

    local count = 0
    for _ in pairs(questStates_) do count = count + 1 end
    print("[QuestSystem] Initialized, " .. count .. " quest chains")
end

--- 获取某区域主线的当前状态
---@param chainId string
---@return table|nil
function QuestSystem.GetChainState(chainId)
    return questStates_[chainId]
end

--- 获取某区域主线的当前步骤数据
---@param chainId string
---@return table|nil stepData, number stepIndex
function QuestSystem.GetCurrentStep(chainId)
    local state = questStates_[chainId]
    if not state or state.completed then return nil, 0 end

    local chain = QuestData.ZONE_QUESTS[chainId]
    if not chain then return nil, 0 end

    local step = chain.steps[state.currentStep]
    return step, state.currentStep
end

--- 获取当前区域的主线任务链ID
---@param zone string 区域ID（如 "town"）
---@return string|nil chainId
function QuestSystem.GetChainForZone(zone)
    for chainId, chain in pairs(QuestData.ZONE_QUESTS) do
        if chain.zone == zone then
            return chainId
        end
    end
    return nil
end

--- 检查步骤是否匹配某个 targetType（支持单目标和多目标）
---@param step table
---@param typeId string
---@return boolean matched, string|nil matchedTarget
local function StepMatchesTarget(step, typeId)
    if step.targets then
        for _, t in ipairs(step.targets) do
            if t.targetType == typeId then return true, t.targetType end
            -- 支持 targetAliases：多种怪物共享同一个击杀计数器
            if t.targetAliases then
                for _, alias in ipairs(t.targetAliases) do
                    if alias == typeId then return true, t.targetType end
                end
            end
        end
    elseif step.targetType == typeId then
        return true, step.targetType
    end
    return false, nil
end

--- 检查多目标步骤是否全部完成
---@param step table
---@param kills table
---@return boolean
local function IsStepAllTargetsDone(step, kills)
    if step.targets then
        for _, t in ipairs(step.targets) do
            if (kills[t.targetType] or 0) < (t.targetCount or 1) then
                return false
            end
        end
        return true
    else
        return (kills[step.targetType] or 0) >= (step.targetCount or 1)
    end
end

--- 获取步骤的总进度文本（支持多目标）
---@param step table
---@param kills table
---@return string
local function GetStepProgressText(step, kills)
    if step.targets then
        local parts = {}
        for _, t in ipairs(step.targets) do
            local count = kills[t.targetType] or 0
            local needed = t.targetCount or 1
            table.insert(parts, t.name .. " " .. count .. "/" .. needed)
        end
        return table.concat(parts, " | ")
    else
        local count = kills[step.targetType] or 0
        local needed = step.targetCount or 1
        return count .. "/" .. needed
    end
end

--- 获取当前区域主线的显示文本
---@return string|nil text, boolean|nil isComplete
function QuestSystem.GetCurrentQuestText()
    local zone = GameState.currentZone or "town"
    local chainId = QuestSystem.GetChainForZone(zone)

    -- 当前区域无任务链时，按章节查找（支持跨区域显示ch2任务）
    if not chainId then
        local chapter = GameState.currentChapter or 1
        for cId, chain in pairs(QuestData.ZONE_QUESTS) do
            if chain.chapter == chapter then
                chainId = cId
                break
            end
        end
    end

    if not chainId then return nil, false end

    local state = questStates_[chainId]
    if not state then return nil, false end

    if state.completed then
        return "主线已完成", true
    end

    local step, idx = QuestSystem.GetCurrentStep(chainId)
    if not step then return nil, false end

    local chain = QuestData.ZONE_QUESTS[chainId]
    local total = #chain.steps
    local progressStr = GetStepProgressText(step, state.kills)

    return string.format("(%d/%d) %s %s", idx, total, step.name, progressStr), false
end

--- 怪物击杀回调
---@param monster table Monster 实例
function QuestSystem.OnMonsterKilled(monster)
    if not monster.typeId then return end

    -- 遍历所有活跃任务链
    for chainId, state in pairs(questStates_) do
        if not state.completed then
            local chain = QuestData.ZONE_QUESTS[chainId]
            if chain then
                local step = chain.steps[state.currentStep]
                if step then
                    local matched, matchedTarget = StepMatchesTarget(step, monster.typeId)
                    if matched then
                        -- 增加击杀计数
                        state.kills[matchedTarget] = (state.kills[matchedTarget] or 0) + 1
                        local count = state.kills[matchedTarget]

                        print("[QuestSystem] Kill tracked: " .. monster.typeId .. " " .. count)

                        if IsStepAllTargetsDone(step, state.kills) then
                            -- 步骤完成
                            QuestSystem.CompleteStep(chainId)
                        else
                            -- 进度提示
                            local player = GameState.player
                            if player then
                                CombatSystem.AddFloatingText(
                                    player.x, player.y - 1.5,
                                    step.name .. " " .. GetStepProgressText(step, state.kills),
                                    {255, 220, 100, 255}, 2.0
                                )
                            end
                        end
                    end
                end
            end
        end
    end
end

--- 完成当前步骤
---@param chainId string
function QuestSystem.CompleteStep(chainId)
    local state = questStates_[chainId]
    local chain = QuestData.ZONE_QUESTS[chainId]
    if not state or not chain then return end

    local step = chain.steps[state.currentStep]
    if not step then return end

    print("[QuestSystem] Step completed: " .. step.id)

    -- 发放奖励（无奖励的步骤跳过）
    if step.reward then
        if step.reward.type == "equipment_pick" then
            QuestSystem.GenerateRewardPick(step.reward, chainId)
        elseif step.reward.type == "material" then
            -- 弹出奖励领取界面，玩家点击领取后才入背包
            EventBus.Emit("quest_material_reward", step.reward)
        elseif step.reward.type == "material_bundle" then
            -- 复合奖励（多项物品一起展示）
            EventBus.Emit("quest_material_bundle_reward", step.reward.items)
        elseif step.reward.type == "equip_and_bundle" then
            -- 固定装备 + 道具复合奖励：先给装备入背包，再弹道具领取
            QuestSystem.GrantFixedEquipment(step.reward.equipId)
            if step.reward.items and #step.reward.items > 0 then
                EventBus.Emit("quest_material_bundle_reward", step.reward.items)
            end
        elseif step.reward.type == "consumable_pick" then
            -- 消耗品3选1（如宠物技能书）
            EventBus.Emit("quest_consumable_pick", step.reward.items)
        end
    end

    -- 步骤级封印解除（ch4八卦海逐步解锁传送阵）
    if step.unlockSeal and QuestData.SEALS[step.unlockSeal] then
        sealStates_[step.unlockSeal] = true
        EventBus.Emit("seal_removed", step.unlockSeal)
        print("[QuestSystem] Step seal unlocked: " .. step.unlockSeal)
    end

    -- 进入下一步
    state.currentStep = state.currentStep + 1
    state.kills = {} -- 清空击杀计数

    -- 检查是否全部完成
    if state.currentStep > #chain.steps then
        state.completed = true
        print("[QuestSystem] Quest chain completed: " .. chainId)

        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                "所有主线已完成！",
                {255, 215, 0, 255}, 3.0
            )
        end

        EventBus.Emit("quest_chain_complete", chainId)
    else
        -- 提示下一步
        local nextStep = chain.steps[state.currentStep]
        if nextStep then
            local player = GameState.player
            if player then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 2.0,
                    "新任务: " .. nextStep.name,
                    {100, 255, 200, 255}, 3.0
                )
            end
        end

        EventBus.Emit("quest_step_complete", chainId, state.currentStep - 1)
    end
end

--- 交互型任务完成回调（如找NPC对话解封）
---@param interactType string 交互目标类型ID
function QuestSystem.OnInteract(interactType)
    for chainId, state in pairs(questStates_) do
        if not state.completed then
            local chain = QuestData.ZONE_QUESTS[chainId]
            if chain then
                local step = chain.steps[state.currentStep]
                if step and step.targetType == interactType then
                    state.kills[step.targetType] = (state.kills[step.targetType] or 0) + 1
                    local count = state.kills[step.targetType]
                    local needed = step.targetCount or 1

                    print("[QuestSystem] Interact tracked: " .. interactType .. " " .. count .. "/" .. needed)

                    if count >= needed then
                        QuestSystem.CompleteStep(chainId)
                    end
                end
            end
        end
    end
end

--- 生成3选1装备奖励
---@param rewardCfg table { tier, quality, count }
---@param chainId string
function QuestSystem.GenerateRewardPick(rewardCfg, chainId)
    local LootSystem = GetLootSystem()
    local rewards = {}
    local usedSlots = {}

    for i = 1, (rewardCfg.count or 3) do
        local item = QuestSystem.GenerateQuestEquipment(
            rewardCfg.tier, rewardCfg.quality, usedSlots
        )
        if item then
            table.insert(rewards, item)
            usedSlots[item.slot] = true
        end
    end

    if #rewards > 0 then
        -- 触发奖励选择UI
        EventBus.Emit("quest_reward_pick", rewards, chainId)
        print("[QuestSystem] Generated " .. #rewards .. " reward items for pick")
    end
end

--- 生成任务奖励装备（固定tier+quality，排除武器和衣服）
---@param tier number
---@param quality string
---@param excludeSlots table 已使用的槽位（避免重复）
---@return table|nil
function QuestSystem.GenerateQuestEquipment(tier, quality, excludeSlots)
    local LootSystem = GetLootSystem()
    local EquipmentData = GetEquipmentData()
    local GameConfig = require("config.GameConfig")

    -- 从奖励槽位中随机选择（排除已用的）
    local available = {}
    for _, slot in ipairs(QuestData.REWARD_SLOTS) do
        if not excludeSlots[slot] then
            table.insert(available, slot)
        end
    end
    if #available == 0 then
        -- 全部用完，允许重复
        available = QuestData.REWARD_SLOTS
    end
    local slot = available[math.random(1, #available)]

    local qualityConfig = GameConfig.QUALITY[quality]
    if not qualityConfig then return nil end

    -- 主属性计算
    local mainValue, mainStatType = EquipmentUtils.CalcSlotMainStat(slot, tier, qualityConfig.multiplier)
    if not mainValue then return nil end

    -- 生成副属性
    local subStats = LootSystem.GenerateSubStats(qualityConfig.subStatCount, tier, mainStatType)

    -- 装备名称
    local tierNames = EquipmentData.TIER_SLOT_NAMES[tier]
    local baseName = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

    local item = {
        id = Utils.NextId(),
        name = baseName,
        slot = slot,
        icon = LootSystem.GetSlotIcon(slot, tier),
        quality = quality,
        tier = tier,
        mainStat = { [mainStatType] = mainValue },
        subStats = subStats,
        sellPrice = math.floor(10 * tier * qualityConfig.multiplier),
    }

    return item
end

--- 发放固定装备（根据 equipId 查找 EquipmentData 中的定义）
---@param equipId string 装备ID（如 "boar_belt_ch2"）
function QuestSystem.GrantFixedEquipment(equipId)
    local EquipmentData = GetEquipmentData()
    local equipDef = EquipmentData.BOSS_DROPS and EquipmentData.BOSS_DROPS[equipId]
        or EquipmentData[equipId]
    if not equipDef then
        print("[QuestSystem] WARNING: Fixed equip not found: " .. equipId)
        return
    end

    -- 复制一份装备数据，添加唯一ID
    local item = {}
    for k, v in pairs(equipDef) do
        item[k] = v
    end
    item.id = Utils.NextId()

    -- 放入背包
    local InventorySystem = require("systems.InventorySystem")
    local ok = InventorySystem.AddItem(item)
    if not ok then
        table.insert(GameState.pendingItems, item)
        print("[QuestSystem] Backpack full, equip pending: " .. (item.name or equipId))
    end

    -- 浮动文字
    local player = GameState.player
    if player then
        local GameConfig = require("config.GameConfig")
        local qualityConfig = GameConfig.QUALITY[item.quality]
        local qColor = qualityConfig and qualityConfig.color or {255, 255, 255, 255}
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "获得: " .. (item.name or equipId),
            qColor, 2.5
        )
    end

    print("[QuestSystem] Fixed equip granted: " .. (item.name or equipId))
end

--- 判断封印是否属于当前章节（公开接口，供渲染模块使用）
---@param zoneId string
---@return boolean
function QuestSystem.IsSealInCurrentChapter(zoneId)
    local sealData = QuestData.SEALS[zoneId]
    if not sealData then return false end
    return IsSealInCurrentChapter(sealData)
end

--- 解除封印
---@param zoneId string 被封印的区域ID
---@return boolean success
function QuestSystem.Unseal(zoneId)
    local sealData = QuestData.SEALS[zoneId]
    if not sealData then return false end

    -- 已经解封
    if sealStates_[zoneId] then return true end

    -- 境界驱动封印：检查玩家境界是否达标
    if sealData.realmDriven then
        local GameConfig = require("config.GameConfig")
        local player = GameState.player
        if not player then return false end
        local rd = GameConfig.REALMS[player.realm]
        local playerOrder = rd and rd.order or 0
        if playerOrder < sealData.requiredRealmOrder then
            return false
        end
        -- 境界达标，解封
        sealStates_[zoneId] = true
        EventBus.Emit("seal_removed", zoneId)
        print("[QuestSystem] Realm seal removed: " .. zoneId .. " (realm order " .. playerOrder .. " >= " .. sealData.requiredRealmOrder .. ")")
        return true
    end

    -- 任务链驱动封印：检查任务链是否完成，或当前步骤就是解封步骤
    local state = questStates_[sealData.questChain]
    if not state then return false end
    if not state.completed then
        local chain = QuestData.ZONE_QUESTS[sealData.questChain]
        if not chain then return false end
        local step = chain.steps[state.currentStep]
        -- 通用检查：步骤ID匹配 unseal_<zoneId> 模式
        if not step or step.id ~= "unseal_" .. zoneId then
            return false
        end
    end

    sealStates_[zoneId] = true

    -- 恢复瓦片为可通行
    EventBus.Emit("seal_removed", zoneId)

    print("[QuestSystem] Seal removed: " .. zoneId)
    return true
end

--- 查找玩家附近的境界驱动封印（由交互按钮调用）
--- 返回封印 zoneId 和 sealData，或 nil 表示附近无封印
---@return string|nil zoneId, table|nil sealData
function QuestSystem.FindNearbySeal()
    local player = GameState.player
    if not player or not player.alive then return nil end

    for zoneId, sealData in pairs(QuestData.SEALS) do
        if sealData.realmDriven and IsSealInCurrentChapter(sealData) and not sealStates_[zoneId] then
            -- 检查距离
            local cx, cy = 0, 0
            for _, tile in ipairs(sealData.sealTiles) do
                cx = cx + tile.x
                cy = cy + tile.y
            end
            cx = cx / #sealData.sealTiles
            cy = cy / #sealData.sealTiles

            local dist = Utils.Distance(player.x, player.y, cx, cy)
            if dist <= sealData.promptRange then
                return zoneId, sealData
            end
        end
    end

    return nil
end

--- 检查封印是否已解除
---@param zoneId string
---@return boolean
function QuestSystem.IsSealRemoved(zoneId)
    return sealStates_[zoneId] == true
end

--- GM 强制切换封印状态（无视境界/任务条件）
---@param zoneId string
---@return boolean newState true=已解封, false=已封印
function QuestSystem.GMToggleSeal(zoneId)
    local sealData = QuestData.SEALS[zoneId]
    if not sealData then return false end
    if sealStates_[zoneId] then
        -- 当前已解封 → 恢复封印
        sealStates_[zoneId] = false
        EventBus.Emit("seal_reset", zoneId)
        print("[QuestSystem] GM seal restored: " .. zoneId)
        return false
    else
        -- 当前封印中 → 强制解封
        sealStates_[zoneId] = true
        EventBus.Emit("seal_removed", zoneId)
        print("[QuestSystem] GM seal removed: " .. zoneId)
        return true
    end
end

--- 检查任务链是否已完成
---@param chainId string
---@return boolean
function QuestSystem.IsChainCompleted(chainId)
    local state = questStates_[chainId]
    return state and state.completed == true
end

--- 获取任务链全部步骤信息（用于NPC展示）
---@param chainId string
---@return table[] steps { name, desc, completed, current }
function QuestSystem.GetStepsInfo(chainId)
    local chain = QuestData.ZONE_QUESTS[chainId]
    local state = questStates_[chainId]
    if not chain or not state then return {} end

    local result = {}
    for i, step in ipairs(chain.steps) do
        local isCurrent = (i == state.currentStep and not state.completed)
        local info = {
            name = step.name,
            desc = step.desc,
            completed = i < state.currentStep or state.completed,
            current = isCurrent,
        }
        -- 多目标步骤：用进度文本替代简单数字
        if step.targets then
            info.multiTarget = true
            info.progressText = isCurrent and GetStepProgressText(step, state.kills) or ""
            -- 用总目标数作为 killNeeded（仅用于显示）
            local totalNeeded = 0
            local totalKills = 0
            for _, t in ipairs(step.targets) do
                totalNeeded = totalNeeded + (t.targetCount or 1)
                if isCurrent then
                    totalKills = totalKills + math.min(state.kills[t.targetType] or 0, t.targetCount or 1)
                end
            end
            info.killCount = totalKills
            info.killNeeded = totalNeeded
        else
            info.killCount = isCurrent and (state.kills[step.targetType] or 0) or 0
            info.killNeeded = step.targetCount or 1
        end
        table.insert(result, info)
    end
    return result
end

--- 更新封印提示（在主循环中调用）
---@param dt number
function QuestSystem.Update(dt)
    -- 封印提示冷却
    if sealPromptCooldown_ > 0 then
        sealPromptCooldown_ = sealPromptCooldown_ - dt
    end

    local player = GameState.player
    if not player or not player.alive then return end

    -- 检查玩家是否靠近封印（仅当前章节的封印）
    for zoneId, sealData in pairs(QuestData.SEALS) do
        if IsSealInCurrentChapter(sealData) and not sealStates_[zoneId] then
            -- 计算玩家到封印中心的距离
            local cx, cy = 0, 0
            for _, tile in ipairs(sealData.sealTiles) do
                cx = cx + tile.x
                cy = cy + tile.y
            end
            cx = cx / #sealData.sealTiles
            cy = cy / #sealData.sealTiles

            local dist = Utils.Distance(player.x, player.y, cx, cy)
            if dist <= sealData.promptRange and sealPromptCooldown_ <= 0 then
                -- 根据封印所属章节选择提示颜色
                local chain = QuestData.ZONE_QUESTS[sealData.questChain]
                local promptColor
                if chain and chain.chapter == 101 then
                    promptColor = {180, 220, 255, 255}   -- 中洲：青白色仙气
                elseif chain and chain.chapter == 4 then
                    promptColor = {80, 200, 240, 255}    -- 第四章：海蓝色
                elseif chain and chain.chapter == 3 then
                    promptColor = {220, 180, 60, 255}    -- 第三章：沙金色
                elseif chain and chain.chapter == 2 then
                    promptColor = {255, 60, 40, 255}     -- 第二章：血红色
                else
                    promptColor = {200, 150, 255, 255}   -- 第一章：紫蓝色
                end
                CombatSystem.AddFloatingText(
                    cx, cy - 0.5,
                    sealData.promptText,
                    promptColor, 2.0
                )
                sealPromptCooldown_ = 3.0  -- 3秒内不重复提示
            end
        end
    end
end

--- 应用封印到地图（将封印瓦片设为不可通行）
--- 仅应用属于当前章节的封印，避免跨章节污染
---@param gameMap table GameMap 实例
function QuestSystem.ApplySeals(gameMap)
    if not gameMap then return end

    for zoneId, sealData in pairs(QuestData.SEALS) do
        -- 跳过不属于当前章节的封印（如 ch1 的 tiger_domain 不应出现在 ch2）
        if not IsSealInCurrentChapter(sealData) then
            goto continue
        end
        print("[QuestSystem] ApplySeals checking: " .. zoneId ..
              " sealState=" .. tostring(sealStates_[zoneId]) ..
              " sealTile=" .. tostring(sealData.sealTile) ..
              " realmDriven=" .. tostring(sealData.realmDriven))

        -- 保底：关联任务链已完成时，强制同步封印状态为已解封
        -- 防止存档故障/恢复导致封印状态与任务完成状态不同步
        -- 🔴 排除 realmDriven 封印：这类封印由玩家手动交互解封，不随任务链完成自动解封
        if not sealStates_[zoneId] and not sealData.realmDriven then
            local chainState = questStates_[sealData.questChain]
            if chainState and chainState.completed then
                sealStates_[zoneId] = true
                print("[QuestSystem] Seal auto-fixed: " .. zoneId .. " (quest completed but seal was locked)")
            end
        end

        -- realmDriven 封印：验证玩家境界，防止旧存档中不合法的已解封状态
        -- 若存档中标记为已解封，但玩家实际境界不达标，则重新锁定（回退旧测试数据）
        if sealStates_[zoneId] and sealData.realmDriven then
            local GameConfig = require("config.GameConfig")
            local player = GameState.player
            local rd = player and GameConfig.REALMS[player.realm]
            local playerOrder = rd and rd.order or 0
            if playerOrder < sealData.requiredRealmOrder then
                sealStates_[zoneId] = false
                print("[QuestSystem] Seal re-locked: " .. zoneId ..
                      " (player realm " .. playerOrder .. " < required " .. sealData.requiredRealmOrder .. ")")
            end
        end

        if not sealStates_[zoneId] then
            local sealTileType = sealData.sealTile or ActiveZoneData.Get().TILE.MOUNTAIN
            for _, tile in ipairs(sealData.sealTiles) do
                gameMap:SetTile(tile.x, tile.y, sealTileType)
            end
            print("[QuestSystem] Seal applied: " .. zoneId .. " (" .. #sealData.sealTiles .. " tiles, tileType=" .. tostring(sealTileType) .. ")")
        else
            -- 已解封：确保瓦片恢复为可通行
            for _, tile in ipairs(sealData.sealTiles) do
                gameMap:SetTile(tile.x, tile.y, sealData.originalTile or ActiveZoneData.Get().TILE.GRASS)
            end
            print("[QuestSystem] Seal already removed: " .. zoneId .. " (sealState=true)")
        end

        ::continue::
    end
end

--- 移除封印瓦片（恢复可通行）
---@param gameMap table
---@param zoneId string
function QuestSystem.RemoveSealTiles(gameMap, zoneId)
    if not gameMap then return end

    local sealData = QuestData.SEALS[zoneId]
    if not sealData then return end

    for _, tile in ipairs(sealData.sealTiles) do
        gameMap:SetTile(tile.x, tile.y, sealData.originalTile or ActiveZoneData.Get().TILE.GRASS)
    end
    print("[QuestSystem] Seal tiles removed: " .. zoneId)
end

--- 序列化任务数据
---@return table
function QuestSystem.Serialize()
    return {
        questStates = questStates_,
        sealStates = sealStates_,
    }
end

--- 反序列化任务数据
---@param data table
function QuestSystem.Deserialize(data)
    if not data then return end

    if data.questStates then
        for chainId, state in pairs(data.questStates) do
            questStates_[chainId] = state
        end
    end

    if data.sealStates then
        for zoneId, unsealed in pairs(data.sealStates) do
            sealStates_[zoneId] = unsealed
        end
    end

    -- 一致性修复：任务已完成但封印未解除时，强制同步
    -- 🔴 排除 realmDriven 封印：这类封印由玩家手动交互解封，不随任务链完成自动解封
    for zoneId, sealData in pairs(QuestData.SEALS) do
        if not sealStates_[zoneId] and not sealData.realmDriven then
            local chainState = questStates_[sealData.questChain]
            if chainState and chainState.completed then
                sealStates_[zoneId] = true
                print("[QuestSystem] Seal consistency fix on load: " .. zoneId)
            end
        end
    end

    print("[QuestSystem] Data restored")
end

--- 立刻完成整条主线任务链（GM 用）
--- 跳过所有步骤，标记完成，解除关联封印
---@param chainId string 任务链ID
---@return boolean success
function QuestSystem.ForceCompleteChain(chainId)
    local chain = QuestData.ZONE_QUESTS[chainId]
    if not chain then return false end

    local state = questStates_[chainId]
    if not state then return false end

    if state.completed then return true end -- 已完成

    -- 直接标记完成
    state.currentStep = #chain.steps + 1
    state.kills = {}
    state.completed = true

    -- 解除该任务链关联的所有封印
    for zoneId, sealData in pairs(QuestData.SEALS) do
        if sealData.questChain == chainId and not sealStates_[zoneId] then
            sealStates_[zoneId] = true
            EventBus.Emit("seal_removed", zoneId)
            print("[QuestSystem] Seal force-removed: " .. zoneId)
        end
    end

    EventBus.Emit("quest_chain_complete", chainId)
    print("[QuestSystem] Chain force-completed: " .. chainId)
    return true
end

--- 重置单个区域的主线任务链（GM 用）
---@param chainId string 任务链ID
function QuestSystem.ResetChain(chainId)
    local chain = QuestData.ZONE_QUESTS[chainId]
    if not chain then return false end

    -- 重置任务进度
    questStates_[chainId] = {
        currentStep = 1,
        kills = {},
        completed = false,
    }

    -- 如果该任务链关联了封印，也重置封印状态
    for zoneId, sealData in pairs(QuestData.SEALS) do
        if sealData.questChain == chainId then
            sealStates_[zoneId] = false
            -- 通知地图重新应用封印
            EventBus.Emit("seal_reset", zoneId)
        end
    end

    print("[QuestSystem] Chain reset: " .. chainId)
    return true
end

--- 重置（用于返回登录）
function QuestSystem.Reset()
    questStates_ = {}
    sealStates_ = {}
    sealPromptCooldown_ = 0
end

return QuestSystem
