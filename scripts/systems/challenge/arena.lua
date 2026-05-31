--- ChallengeSystem / arena sub-module
--- Unlock, Enter, Exit, Arena creation, Rollback
--- All functions receive `CS` (ChallengeSystem table) as first arg for state access.

local shared = require("systems.challenge.shared")
local GameConfig      = shared.GameConfig
local GameState       = shared.GameState
local EventBus        = shared.EventBus
local ChallengeConfig = shared.ChallengeConfig
local MonsterData     = shared.MonsterData
local Monster         = shared.Monster
local TileTypes       = shared.TileTypes

local M = {}

-- ============================================================================
-- 解锁（新版声望系统）
-- ============================================================================

--- 解锁指定声望等级（新版）
---@param CS table ChallengeSystem ref
---@param factionKey string
---@param repLevel number 1-8
---@return boolean success
---@return string|nil message
function M.UnlockReputation(CS, factionKey, repLevel)
    local factionCfg = ChallengeConfig.FACTIONS[factionKey]
    if not factionCfg or not factionCfg.reputation then
        return false, "阵营不支持新版声望"
    end

    local repCfg = factionCfg.reputation[repLevel]
    if not repCfg then return false, "声望等级不存在" end

    local progress = CS.GetReputationProgress(factionKey, repLevel)
    if not progress then return false, "进度数据异常" end
    if progress.unlocked then return false, "已解锁" end

    -- 前置：上一级必须已通关
    if repLevel > 1 then
        local prevP = CS.GetReputationProgress(factionKey, repLevel - 1)
        if not prevP or not prevP.completed then
            return false, "需先通关声望" .. (repLevel - 1) .. "级"
        end
    end

    -- 检查令牌
    local tokenId = repCfg.tokenId
    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountUnlockedConsumable(tokenId)
    if tokenCount < repCfg.unlockCost then
        return false, tokenName .. "不足（需要 " .. repCfg.unlockCost .. "，当前 " .. tokenCount .. "）"
    end

    -- 扣除令牌
    local ok = InventorySystem.ConsumeConsumable(tokenId, repCfg.unlockCost)
    if not ok then return false, "令牌扣除失败（可能被锁定）" end

    -- 标记解锁
    progress.unlocked = true

    print("[ChallengeSystem] RepUnlocked: " .. factionKey .. " rep" .. repLevel
        .. " (" .. repCfg.name .. "), cost " .. repCfg.unlockCost .. " " .. tokenId)

    -- 立即存档
    EventBus.Emit("save_request")

    return true, "解锁成功！"
end

--- 旧版解锁（保留不变）
---@param CS table
---@param faction string
---@param tier number
---@return boolean success
---@return string|nil message
function M.Unlock(CS, faction, tier)
    local factionCfg = ChallengeConfig.FACTIONS[faction]
    if not factionCfg then return false, "阵营不存在" end

    local tierCfg = factionCfg.tiers[tier]
    if not tierCfg then return false, "等级不存在" end

    local progress = CS.GetProgress(faction, tier)
    if not progress then return false, "进度数据异常" end

    if progress.unlocked then return false, "已解锁" end

    -- 检查前置
    if tier > 1 then
        local prevProgress = CS.GetProgress(faction, tier - 1)
        if not prevProgress or not prevProgress.completed then
            return false, "需先通关上一级挑战"
        end
    end

    -- 检查令牌
    local tokenId = tierCfg.tokenId or "wubao_token"
    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountUnlockedConsumable(tokenId)
    if tokenCount < tierCfg.unlockCost then
        return false, tokenName .. "不足（需要 " .. tierCfg.unlockCost .. "，当前 " .. tokenCount .. "）"
    end

    -- 扣除令牌
    local ok = InventorySystem.ConsumeConsumable(tokenId, tierCfg.unlockCost)
    if not ok then return false, "令牌扣除失败（可能被锁定）" end
    progress.unlocked = true

    print("[ChallengeSystem] Unlocked: " .. faction .. " T" .. tier
        .. " (" .. tierCfg.name .. "), cost " .. tierCfg.unlockCost .. " tokens")

    EventBus.Emit("save_request")

    return true, "解锁成功！"
end

-- ============================================================================
-- 进入副本
-- ============================================================================

--- 进入新版声望挑战
---@param CS table
---@param factionKey string
---@param repLevel number 1-8
---@param gameMap table
---@param camera table|nil
---@return boolean success
---@return string|nil message
function M.EnterReputation(CS, factionKey, repLevel, gameMap, camera)
    if CS.active then
        return false, "已在挑战中"
    end

    local factionCfg = ChallengeConfig.FACTIONS[factionKey]
    if not factionCfg or not factionCfg.reputation then
        return false, "阵营不支持新版声望"
    end

    local repCfg = factionCfg.reputation[repLevel]
    if not repCfg then return false, "声望等级不存在" end

    -- 检查解锁
    if not CS.IsUnlocked(factionKey, repLevel, true) then
        return false, "尚未解锁"
    end

    -- 检查入场费
    local tokenId = repCfg.tokenId
    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountUnlockedConsumable(tokenId)
    if tokenCount < ChallengeConfig.ATTEMPT_COST then
        return false, tokenName .. "不足（需要 " .. ChallengeConfig.ATTEMPT_COST .. "，当前 " .. tokenCount .. "）"
    end

    -- 扣除入场费并立即存档
    local ok = InventorySystem.ConsumeConsumable(tokenId, ChallengeConfig.ATTEMPT_COST)
    if not ok then return false, "令牌扣除失败（可能被锁定）" end
    EventBus.Emit("save_request")

    -- 创建竞技场
    local success, msg = M._createArena(CS, gameMap, camera, repCfg.monsterId, factionCfg)
    if not success then return false, msg end

    -- 更新状态
    CS.currentFaction = factionKey
    CS.currentTier = nil
    CS.currentRepLevel = repLevel

    EventBus.Emit("challenge_entered", { faction = factionKey, repLevel = repLevel })

    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "— " .. repCfg.name .. " —",
            factionCfg.color, 3.0
        )
    end

    print("[ChallengeSystem] Entered rep arena: " .. factionKey .. " rep" .. repLevel
        .. " (" .. repCfg.name .. ") monsterId=" .. repCfg.monsterId)

    return true, nil
end

--- 旧版进入
---@param CS table
---@param faction string
---@param tier number
---@param gameMap table
---@param camera table|nil
---@return boolean success
---@return string|nil message
function M.Enter(CS, faction, tier, gameMap, camera)
    if CS.active then
        return false, "已在挑战中"
    end

    local factionCfg = ChallengeConfig.FACTIONS[faction]
    if not factionCfg then return false, "阵营不存在" end

    local tierCfg = factionCfg.tiers[tier]
    if not tierCfg then return false, "等级不存在" end

    if not CS.IsUnlocked(faction, tier) then
        return false, "尚未解锁"
    end

    -- 检查入场费
    local tokenId = tierCfg.tokenId or "wubao_token"
    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountUnlockedConsumable(tokenId)
    if tokenCount < ChallengeConfig.ATTEMPT_COST then
        return false, tokenName .. "不足（需要 " .. ChallengeConfig.ATTEMPT_COST .. "，当前 " .. tokenCount .. "）"
    end

    -- 扣除入场费并立即存档
    local ok = InventorySystem.ConsumeConsumable(tokenId, ChallengeConfig.ATTEMPT_COST)
    if not ok then return false, "令牌扣除失败（可能被锁定）" end
    EventBus.Emit("save_request")

    -- 创建竞技场
    local success, msg = M._createArena(CS, gameMap, camera, tierCfg.monsterId, factionCfg)
    if not success then return false, msg end

    CS.currentFaction = faction
    CS.currentTier = tier
    CS.currentRepLevel = nil

    EventBus.Emit("challenge_entered", { faction = faction, tier = tier })

    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "— " .. tierCfg.name .. " —",
            factionCfg.color, 3.0
        )
    end

    print("[ChallengeSystem] Entered arena: " .. faction .. " T" .. tier
        .. " (" .. tierCfg.name .. ")")

    return true, nil
end

-- ============================================================================
-- 竞技场创建（内部共用）
-- ============================================================================

---@param CS table
---@param gameMap table
---@param camera table|nil
---@param monsterId string
---@param factionCfg table
---@return boolean success
---@return string|nil message
function M._createArena(CS, gameMap, camera, monsterId, factionCfg)
    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    local monsterData = MonsterData.Types[monsterId]
    if not monsterData then
        return false, "怪物数据不存在: " .. tostring(monsterId)
    end

    local T = TileTypes.TILE
    local innerSize = ChallengeConfig.ARENA_SIZE
    local totalSize = innerSize + 2

    -- 1. 备份世界
    CS._backup = {
        tiles = gameMap.tiles,
        width = gameMap.width,
        height = gameMap.height,
        playerX = player.x,
        playerY = player.y,
        playerHp = player.hp,
        monsters = GameState.monsters,
        npcs = GameState.npcs,
        lootDrops = GameState.lootDrops,
        bossKillTimes = GameState.bossKillTimes,
        cameraX = camera and camera.x or nil,
        cameraY = camera and camera.y or nil,
        cameraMapW = camera and camera.mapWidth or nil,
        cameraMapH = camera and camera.mapHeight or nil,
    }

    -- 2. 创建竞技场
    gameMap.width = totalSize
    gameMap.height = totalSize
    gameMap.tiles = {}
    for y = 1, totalSize do
        gameMap.tiles[y] = {}
        for x = 1, totalSize do
            if x == 1 or x == totalSize or y == 1 or y == totalSize then
                gameMap.tiles[y][x] = T.WALL
            else
                gameMap.tiles[y][x] = T.CAMP_DIRT
            end
        end
    end

    -- 3. 清除实体
    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}
    GameState.bossKillTimes = {}

    -- 4. 传送玩家
    local centerX = totalSize / 2 + 0.5
    local centerY = totalSize / 2 + 1.5
    player.x = centerX
    player.y = centerY
    player:SetMoveDirection(0, 0)
    player.hp = player:GetTotalMaxHp()

    if camera then
        camera.x = centerX
        camera.y = centerY
        camera.mapWidth = totalSize
        camera.mapHeight = totalSize
    end

    -- 5. 生成怪物
    local monsterX = totalSize / 2 + 0.5
    local monsterY = totalSize / 2 - 0.5
    local challengeMonster = Monster.New(monsterData, monsterX, monsterY)
    challengeMonster.typeId = monsterId
    challengeMonster.isChallenge = true
    GameState.AddMonster(challengeMonster)

    -- 6. 更新状态
    CS._camera = camera
    CS.active = true
    CS.challengeMonster = challengeMonster
    CS.rewardCollected = false

    return true, nil
end

-- ============================================================================
-- 退出副本
-- ============================================================================

--- 退出挑战副本（恢复世界状态）
---@param CS table
function M.Exit(CS, gameMap, isVictory, camera)
    if not CS.active then return end

    local cam = camera or CS._camera
    local CombatSystem = require("systems.CombatSystem")

    if CS.challengeMonster then
        GameState.RemoveMonster(CS.challengeMonster)
        CS.challengeMonster = nil
    end

    M._rollback(CS, gameMap, cam)

    local player = GameState.player
    if player then
        player.hp = player:GetTotalMaxHp()
        player:SetMoveDirection(0, 0)
    end

    CombatSystem.ClearEffects()
    CombatSystem.ClearBloodMark()
    CombatSystem.ClearBarrierZones()
    CombatSystem.ClearJadeShield()
    CombatSystem.ClearSealMark()

    EventBus.Emit("challenge_exited", {
        faction = CS.currentFaction,
        tier = CS.currentTier,
        repLevel = CS.currentRepLevel,
        victory = isVictory or false,
    })

    CS.active = false
    CS.currentFaction = nil
    CS.currentTier = nil
    CS.currentRepLevel = nil
    CS.rewardCollected = false
    CS._camera = nil

    if player then
        local msg = isVictory and "挑战胜利！" or "挑战结束"
        local color = isVictory and {255, 215, 0, 255} or {200, 200, 200, 255}
        CombatSystem.AddFloatingText(player.x, player.y - 1.5, msg, color, 3.0)
    end

    print("[ChallengeSystem] Exited (victory=" .. tostring(isVictory) .. ")")
end

--- 内部回滚
---@param CS table
function M._rollback(CS, gameMap, camera)
    local backup = CS._backup
    if not backup then return end

    gameMap.tiles = backup.tiles
    gameMap.width = backup.width
    gameMap.height = backup.height

    GameState.monsters = backup.monsters or {}
    GameState.npcs = backup.npcs or {}
    GameState.lootDrops = backup.lootDrops or {}
    GameState.bossKillTimes = backup.bossKillTimes or {}

    local player = GameState.player
    if player then
        player.x = backup.playerX
        player.y = backup.playerY
    end

    if camera and backup.cameraX then
        camera.x = backup.cameraX
        camera.y = backup.cameraY
        camera.mapWidth = backup.cameraMapW
        camera.mapHeight = backup.cameraMapH
    end

    CS._backup = nil
end

--- 副本内更新
---@param CS table
function M.Update(CS, dt, gameMap)
    if not CS.active then return end
    -- 玩家死亡由 DeathScreen/UI 处理退出
end

return M
