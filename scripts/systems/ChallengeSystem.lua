-- ============================================================================
-- ChallengeSystem.lua - 阵营挑战/法宝系统（v3）
-- 血煞盟·殷无咎（新版声望） / 浩气宗·陆青云（旧版 tiers）
-- 新版：7 级声望（T3-T9），法宝掉落，5 种凝X丹，精华材料
-- 旧版：8 级 tiers（T1-T8），专属装备 + 血煞丹/浩气丹
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local ChallengeConfig = require("config.ChallengeConfig")
local MonsterData = require("config.MonsterData")
local Monster = require("entities.Monster")
local TileTypes = require("config.TileTypes")

local ChallengeSystem = {}

-- ============================================================================
-- 运行时状态
-- ============================================================================

-- === 旧版进度（tiers 阵营使用） ===
-- progress[faction][tier] = { unlocked = bool, completed = bool }
ChallengeSystem.progress = {}

-- === 新版进度（reputation 阵营使用） ===
-- treasure_challenge[faction][treasureKey][levelStr] = { unlocked = bool, completed = bool }
ChallengeSystem.treasure_challenge = {}

-- 精华库存（5 种通用精华，全阵营共享）
ChallengeSystem.essence_counts = {
    lipo_essence = 0,
    panshi_essence = 0,
    yuanling_essence = 0,
    shihun_essence = 0,
    lingxi_essence = 0,
}

-- 当前挑战状态
ChallengeSystem.active = false          -- 是否在挑战副本中
ChallengeSystem.currentFaction = nil    -- 当前挑战阵营 key
ChallengeSystem.currentTier = nil       -- 当前挑战等级（旧版用 tier 数字）
ChallengeSystem.currentRepLevel = nil   -- 当前挑战声望等级（新版用 1-7）
ChallengeSystem.challengeMonster = nil  -- 当前挑战怪物实例
ChallengeSystem.rewardCollected = false -- 本次奖励是否已领取

-- 副本覆盖层备份
ChallengeSystem._backup = nil
ChallengeSystem._camera = nil

-- === 旧版丹药计数 ===
ChallengeSystem.xueshaDanCount = 0
ChallengeSystem.haoqiDanCount = 0

-- === 新版丹药计数（凝X丹系列） ===
ChallengeSystem.ningliDanCount = 0    -- 凝力丹 ATK+10
ChallengeSystem.ningjiaDanCount = 0   -- 凝甲丹 DEF+8
ChallengeSystem.ningyuanDanCount = 0  -- 凝元丹 maxHP+30
ChallengeSystem.ninghunDanCount = 0   -- 凝魂丹 killHeal+40
ChallengeSystem.ningxiDanCount = 0    -- 凝息丹 hpRegen+6

-- ============================================================================
-- 丹药配置
-- ============================================================================

-- 旧版丹药（血煞丹/浩气丹，仅用于旧版 tiers 阵营）
local LEGACY_PILL_CONFIG = {
    xuesha_dan = {
        bonuses = {
            { stat = "atk", bonus = 8, desc = "攻击力" },
            { stat = "pillKillHeal", bonus = 5, desc = "击杀回血" },
        },
        maxUse = 9,
        countField = "xueshaDanCount",
        name = "血煞丹",
        icon = "💉",
        flavor = "以血煞之气淬炼的丹药，服用后血脉贲张，杀意化为生机。",
        effectDesc = "永久增加攻击力+8、击杀回血+5",
        color = {200, 60, 60, 255},
    },
    haoqi_dan = {
        bonuses = {
            { stat = "maxHp", bonus = 30, desc = "生命上限" },
            { stat = "hpRegen", bonus = 0.5, desc = "生命回复" },
        },
        maxUse = 9,
        countField = "haoqiDanCount",
        name = "浩气丹",
        icon = "💚",
        flavor = "浩气宗秘传丹方，吞服后正气护体，气血充盈。",
        effectDesc = "永久增加生命上限+30、生命回复+0.5/s",
        color = {60, 140, 220, 255},
    },
}

-- 新版丹药（凝X丹系列，通过炼丹炉使用，全阵营共享）
ChallengeSystem.NEW_PILL_CONFIG = {
    ningli_dan = {
        bonuses = { { stat = "atk", bonus = 10, desc = "攻击力" } },
        maxUse = 10,
        countField = "ningliDanCount",
        name = "凝力丹",
        icon = "⚔️",
        essenceId = "lipo_essence",
        essenceName = "力魄精华",
        lingYunCost = 100,
        effectDesc = "永久增加攻击力+10",
        color = {220, 80, 80, 255},
    },
    ningjia_dan = {
        bonuses = { { stat = "def", bonus = 8, desc = "防御力" } },
        maxUse = 10,
        countField = "ningjiaDanCount",
        name = "凝甲丹",
        icon = "🛡️",
        essenceId = "panshi_essence",
        essenceName = "磐石精华",
        lingYunCost = 100,
        effectDesc = "永久增加防御力+8",
        color = {120, 160, 220, 255},
    },
    ningyuan_dan = {
        bonuses = { { stat = "maxHp", bonus = 30, desc = "生命上限" } },
        maxUse = 10,
        countField = "ningyuanDanCount",
        name = "凝元丹",
        icon = "💚",
        essenceId = "yuanling_essence",
        essenceName = "元灵精华",
        lingYunCost = 100,
        effectDesc = "永久增加生命上限+30",
        color = {80, 200, 120, 255},
    },
    ninghun_dan = {
        bonuses = { { stat = "pillKillHeal", bonus = 40, desc = "击杀回血" } },
        maxUse = 10,
        countField = "ninghunDanCount",
        name = "凝魂丹",
        icon = "💀",
        essenceId = "shihun_essence",
        essenceName = "噬魂精华",
        lingYunCost = 100,
        effectDesc = "永久增加击杀回血+40",
        color = {180, 80, 200, 255},
    },
    ningxi_dan = {
        bonuses = { { stat = "hpRegen", bonus = 6, desc = "生命回复" } },
        maxUse = 10,
        countField = "ningxiDanCount",
        name = "凝息丹",
        icon = "🌿",
        essenceId = "lingxi_essence",
        essenceName = "灵息精华",
        lingYunCost = 100,
        effectDesc = "永久增加生命回复+6/s",
        color = {100, 220, 180, 255},
    },
}

-- ============================================================================
-- 初始化
-- ============================================================================

function ChallengeSystem.Init()
    ChallengeSystem.active = false
    ChallengeSystem.currentFaction = nil
    ChallengeSystem.currentTier = nil
    ChallengeSystem.currentRepLevel = nil
    ChallengeSystem.challengeMonster = nil
    ChallengeSystem.rewardCollected = false
    ChallengeSystem._backup = nil
    ChallengeSystem._camera = nil

    -- 旧版丹药计数
    ChallengeSystem.xueshaDanCount = 0
    ChallengeSystem.haoqiDanCount = 0

    -- 新版丹药计数
    ChallengeSystem.ningliDanCount = 0
    ChallengeSystem.ningjiaDanCount = 0
    ChallengeSystem.ningyuanDanCount = 0
    ChallengeSystem.ninghunDanCount = 0
    ChallengeSystem.ningxiDanCount = 0

    -- 精华库存
    ChallengeSystem.essence_counts = {
        lipo_essence = 0,
        panshi_essence = 0,
        yuanling_essence = 0,
        shihun_essence = 0,
        lingxi_essence = 0,
    }

    -- 为旧版阵营初始化 progress
    ChallengeSystem.progress = {}
    for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
        if faction.tiers then
            ChallengeSystem.progress[factionKey] = {}
            for tier = 1, #faction.tiers do
                ChallengeSystem.progress[factionKey][tier] = {
                    unlocked = false,
                    completed = false,
                }
            end
        end
    end

    -- 为新版阵营初始化 treasure_challenge
    ChallengeSystem.treasure_challenge = {}
    for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
        if faction.reputation then
            ChallengeSystem.treasure_challenge[factionKey] = {
                [faction.treasureKey] = {},
            }
            -- 声望 1-7 默认未解锁
            for level = 1, 7 do
                ChallengeSystem.treasure_challenge[factionKey][faction.treasureKey][tostring(level)] = {
                    unlocked = false,
                    completed = false,
                }
            end
        end
    end

    -- 监听怪物死亡事件
    EventBus.On("monster_death", function(monster)
        ChallengeSystem.OnMonsterDeath(monster)
    end)

    print("[ChallengeSystem] Initialized (v3)")
end

-- ============================================================================
-- 进度查询（兼容新旧版本）
-- ============================================================================

--- 获取旧版进度
---@param faction string
---@param tier number
---@return table|nil { unlocked, completed }
function ChallengeSystem.GetProgress(faction, tier)
    if ChallengeSystem.progress[faction] then
        return ChallengeSystem.progress[faction][tier]
    end
    return nil
end

--- 获取新版声望进度
---@param factionKey string
---@param repLevel number 1-7
---@return table|nil { unlocked, completed }
function ChallengeSystem.GetReputationProgress(factionKey, repLevel)
    local faction = ChallengeConfig.FACTIONS[factionKey]
    if not faction or not faction.reputation then return nil end
    local tc = ChallengeSystem.treasure_challenge[factionKey]
    if not tc then return nil end
    local treasure = tc[faction.treasureKey]
    if not treasure then return nil end
    return treasure[tostring(repLevel)]
end

--- 检查是否已解锁（新旧兼容）
---@param faction string
---@param tierOrLevel number
---@param isReputation boolean|nil true=新版声望, false/nil=旧版tier
---@return boolean
function ChallengeSystem.IsUnlocked(faction, tierOrLevel, isReputation)
    if isReputation then
        local p = ChallengeSystem.GetReputationProgress(faction, tierOrLevel)
        return p and p.unlocked or false
    else
        local p = ChallengeSystem.GetProgress(faction, tierOrLevel)
        return p and p.unlocked or false
    end
end

--- 检查是否已通关（新旧兼容）
---@param faction string
---@param tierOrLevel number
---@param isReputation boolean|nil
---@return boolean
function ChallengeSystem.IsCompleted(faction, tierOrLevel, isReputation)
    if isReputation then
        local p = ChallengeSystem.GetReputationProgress(faction, tierOrLevel)
        return p and p.completed or false
    else
        local p = ChallengeSystem.GetProgress(faction, tierOrLevel)
        return p and p.completed or false
    end
end

-- ============================================================================
-- 解锁（新版声望系统）
-- ============================================================================

--- 解锁指定声望等级（新版）
---@param factionKey string
---@param repLevel number 1-7
---@return boolean success
---@return string|nil message
function ChallengeSystem.UnlockReputation(factionKey, repLevel)
    local factionCfg = ChallengeConfig.FACTIONS[factionKey]
    if not factionCfg or not factionCfg.reputation then
        return false, "阵营不支持新版声望"
    end

    local repCfg = factionCfg.reputation[repLevel]
    if not repCfg then return false, "声望等级不存在" end

    local progress = ChallengeSystem.GetReputationProgress(factionKey, repLevel)
    if not progress then return false, "进度数据异常" end
    if progress.unlocked then return false, "已解锁" end

    -- 前置：上一级必须已通关
    if repLevel > 1 then
        local prevP = ChallengeSystem.GetReputationProgress(factionKey, repLevel - 1)
        if not prevP or not prevP.completed then
            return false, "需先通关声望" .. (repLevel - 1) .. "级"
        end
    end

    -- 检查令牌
    local tokenId = repCfg.tokenId
    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountConsumable(tokenId)
    if tokenCount < repCfg.unlockCost then
        return false, tokenName .. "不足（需要 " .. repCfg.unlockCost .. "，当前 " .. tokenCount .. "）"
    end

    -- 扣除令牌
    InventorySystem.ConsumeConsumable(tokenId, repCfg.unlockCost)

    -- 标记解锁
    progress.unlocked = true

    print("[ChallengeSystem] RepUnlocked: " .. factionKey .. " rep" .. repLevel
        .. " (" .. repCfg.name .. "), cost " .. repCfg.unlockCost .. " " .. tokenId)

    -- 立即存档
    EventBus.Emit("save_request")

    return true, "解锁成功！"
end

--- 旧版解锁（保留不变）
---@param faction string
---@param tier number
---@return boolean success
---@return string|nil message
function ChallengeSystem.Unlock(faction, tier)
    local factionCfg = ChallengeConfig.FACTIONS[faction]
    if not factionCfg then return false, "阵营不存在" end

    local tierCfg = factionCfg.tiers[tier]
    if not tierCfg then return false, "等级不存在" end

    local progress = ChallengeSystem.GetProgress(faction, tier)
    if not progress then return false, "进度数据异常" end

    if progress.unlocked then return false, "已解锁" end

    -- 检查前置
    if tier > 1 then
        local prevProgress = ChallengeSystem.GetProgress(faction, tier - 1)
        if not prevProgress or not prevProgress.completed then
            return false, "需先通关上一级挑战"
        end
    end

    -- 检查令牌
    local tokenId = tierCfg.tokenId or "wubao_token"
    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountConsumable(tokenId)
    if tokenCount < tierCfg.unlockCost then
        return false, tokenName .. "不足（需要 " .. tierCfg.unlockCost .. "，当前 " .. tokenCount .. "）"
    end

    -- 扣除令牌
    InventorySystem.ConsumeConsumable(tokenId, tierCfg.unlockCost)
    progress.unlocked = true

    print("[ChallengeSystem] Unlocked: " .. faction .. " T" .. tier
        .. " (" .. tierCfg.name .. "), cost " .. tierCfg.unlockCost .. " tokens")

    EventBus.Emit("save_request")

    return true, "解锁成功！"
end

-- ============================================================================
-- 进入副本（新旧兼容）
-- ============================================================================

--- 进入新版声望挑战
---@param factionKey string
---@param repLevel number 1-7
---@param gameMap table
---@param camera table|nil
---@return boolean success
---@return string|nil message
function ChallengeSystem.EnterReputation(factionKey, repLevel, gameMap, camera)
    if ChallengeSystem.active then
        return false, "已在挑战中"
    end

    local factionCfg = ChallengeConfig.FACTIONS[factionKey]
    if not factionCfg or not factionCfg.reputation then
        return false, "阵营不支持新版声望"
    end

    local repCfg = factionCfg.reputation[repLevel]
    if not repCfg then return false, "声望等级不存在" end

    -- 检查解锁
    if not ChallengeSystem.IsUnlocked(factionKey, repLevel, true) then
        return false, "尚未解锁"
    end

    -- 检查入场费
    local tokenId = repCfg.tokenId
    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountConsumable(tokenId)
    if tokenCount < ChallengeConfig.ATTEMPT_COST then
        return false, tokenName .. "不足（需要 " .. ChallengeConfig.ATTEMPT_COST .. "，当前 " .. tokenCount .. "）"
    end

    -- 扣除入场费并立即存档（防止中途退出/重启后令牌回档）
    InventorySystem.ConsumeConsumable(tokenId, ChallengeConfig.ATTEMPT_COST)
    EventBus.Emit("save_request")

    -- 创建竞技场（复用 _createArena）
    local success, msg = ChallengeSystem._createArena(gameMap, camera, repCfg.monsterId, factionCfg)
    if not success then return false, msg end

    -- 更新状态
    ChallengeSystem.currentFaction = factionKey
    ChallengeSystem.currentTier = nil  -- 新版不用 tier
    ChallengeSystem.currentRepLevel = repLevel

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

--- 进入旧版 tier 挑战（保留不变）
---@param faction string
---@param tier number
---@param gameMap table
---@param camera table|nil
---@return boolean success
---@return string|nil message
function ChallengeSystem.Enter(faction, tier, gameMap, camera)
    if ChallengeSystem.active then
        return false, "已在挑战中"
    end

    local factionCfg = ChallengeConfig.FACTIONS[faction]
    if not factionCfg then return false, "阵营不存在" end

    local tierCfg = factionCfg.tiers[tier]
    if not tierCfg then return false, "等级不存在" end

    if not ChallengeSystem.IsUnlocked(faction, tier) then
        return false, "尚未解锁"
    end

    -- 检查入场费
    local tokenId = tierCfg.tokenId or "wubao_token"
    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountConsumable(tokenId)
    if tokenCount < ChallengeConfig.ATTEMPT_COST then
        return false, tokenName .. "不足（需要 " .. ChallengeConfig.ATTEMPT_COST .. "，当前 " .. tokenCount .. "）"
    end

    -- 扣除入场费并立即存档（防止中途退出/重启后令牌回档）
    InventorySystem.ConsumeConsumable(tokenId, ChallengeConfig.ATTEMPT_COST)
    EventBus.Emit("save_request")

    -- 创建竞技场
    local success, msg = ChallengeSystem._createArena(gameMap, camera, tierCfg.monsterId, factionCfg)
    if not success then return false, msg end

    ChallengeSystem.currentFaction = faction
    ChallengeSystem.currentTier = tier
    ChallengeSystem.currentRepLevel = nil

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

--- 创建虚空竞技场（新旧版共用）
---@param gameMap table
---@param camera table|nil
---@param monsterId string
---@param factionCfg table
---@return boolean success
---@return string|nil message
function ChallengeSystem._createArena(gameMap, camera, monsterId, factionCfg)
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
    ChallengeSystem._backup = {
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
    ChallengeSystem._camera = camera
    ChallengeSystem.active = true
    ChallengeSystem.challengeMonster = challengeMonster
    ChallengeSystem.rewardCollected = false

    return true, nil
end

-- ============================================================================
-- 退出副本
-- ============================================================================

--- 退出挑战副本（恢复世界状态）
function ChallengeSystem.Exit(gameMap, isVictory, camera)
    if not ChallengeSystem.active then return end

    local cam = camera or ChallengeSystem._camera
    local CombatSystem = require("systems.CombatSystem")

    if ChallengeSystem.challengeMonster then
        GameState.RemoveMonster(ChallengeSystem.challengeMonster)
        ChallengeSystem.challengeMonster = nil
    end

    ChallengeSystem._rollback(gameMap, cam)

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
        faction = ChallengeSystem.currentFaction,
        tier = ChallengeSystem.currentTier,
        repLevel = ChallengeSystem.currentRepLevel,
        victory = isVictory or false,
    })

    ChallengeSystem.active = false
    ChallengeSystem.currentFaction = nil
    ChallengeSystem.currentTier = nil
    ChallengeSystem.currentRepLevel = nil
    ChallengeSystem.rewardCollected = false
    ChallengeSystem._camera = nil

    if player then
        local msg = isVictory and "挑战胜利！" or "挑战结束"
        local color = isVictory and {255, 215, 0, 255} or {200, 200, 200, 255}
        CombatSystem.AddFloatingText(player.x, player.y - 1.5, msg, color, 3.0)
    end

    print("[ChallengeSystem] Exited (victory=" .. tostring(isVictory) .. ")")
end

--- 内部回滚
function ChallengeSystem._rollback(gameMap, camera)
    local backup = ChallengeSystem._backup
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

    ChallengeSystem._backup = nil
end

-- ============================================================================
-- 怪物死亡处理
-- ============================================================================

function ChallengeSystem.OnMonsterDeath(monster)
    if not ChallengeSystem.active then return end
    if monster ~= ChallengeSystem.challengeMonster then return end

    local faction = ChallengeSystem.currentFaction
    if not faction then return end

    -- 新版声望路径
    if ChallengeSystem.currentRepLevel then
        ChallengeSystem._onRepMonsterDeath(faction, ChallengeSystem.currentRepLevel)
        return
    end

    -- 旧版 tier 路径
    local tier = ChallengeSystem.currentTier
    if not tier then return end

    local factionCfg = ChallengeConfig.FACTIONS[faction]
    local tierCfg = factionCfg and factionCfg.tiers[tier]
    if not tierCfg then return end

    local progress = ChallengeSystem.GetProgress(faction, tier)
    local isFirstClear = progress and not progress.completed

    if progress then
        progress.completed = true
    end

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
---@param factionKey string
---@param repLevel number 1-7
function ChallengeSystem._onRepMonsterDeath(factionKey, repLevel)
    local factionCfg = ChallengeConfig.FACTIONS[factionKey]
    local repCfg = factionCfg and factionCfg.reputation[repLevel]
    if not repCfg then return end

    local progress = ChallengeSystem.GetReputationProgress(factionKey, repLevel)
    local isFirstClear = progress and not progress.unlocked == false and not progress.completed

    if progress then
        progress.completed = true
    end

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
        -- 非首通：第一件随机法宝
        local fabaoA = LootSystem.CreateFabaoEquipment(templateId, tier, nil)
        -- 物品掉落判定：声望等级 × 1%
        local itemDropChance = ChallengeConfig.GetExtraDropChance(repLevel)
        local roll = math.random()
        if roll < itemDropChance then
            -- 物品掉落触发：第二选项为道具
            local itemDrop = ChallengeSystem._rollExtraDrop(repLevel)
            choices = { fabaoA, itemDrop }
            print("[ChallengeSystem] ItemDrop HIT: " .. (itemDrop and itemDrop.desc or "?")
                .. " (roll=" .. string.format("%.3f", roll) .. " < " .. itemDropChance .. ")")
        else
            -- 未触发：第二选项为随机法宝
            local fabaoB = LootSystem.CreateFabaoEquipment(templateId, tier, nil)
            choices = { fabaoA, fabaoB }
            print("[ChallengeSystem] ItemDrop MISS: 2 random fabao (roll=" .. string.format("%.3f", roll) .. " >= " .. itemDropChance .. ")")
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

--- 随机物品掉落
---@param repLevel number 1-7
---@return table { type, consumableId, count, desc }
function ChallengeSystem._rollExtraDrop(repLevel)
    local types = ChallengeConfig.GetExtraDropTypes(repLevel)
    local picked = types[math.random(1, #types)]

    if picked == "gold_bar" then
        local count = ChallengeConfig.GetExtraGoldBarCount(repLevel)
        return { type = "gold_bar", consumableId = "gold_bar", count = count, desc = "金条 ×" .. count }

    elseif picked == "food" then
        local foodId = ChallengeConfig.GetExtraFoodId(repLevel)
        local foodName = GameConfig.CONSUMABLES[foodId] and GameConfig.CONSUMABLES[foodId].name or foodId
        return { type = "food", consumableId = foodId, count = 1, desc = foodName .. " ×1" }

    elseif picked == "essence" then
        local essenceIds = ChallengeConfig.ESSENCE_IDS
        local essId = essenceIds[math.random(1, #essenceIds)]
        local essName = GameConfig.PET_MATERIALS and GameConfig.PET_MATERIALS[essId]
            and GameConfig.PET_MATERIALS[essId].name or essId
        return { type = "essence", essenceId = essId, count = 1, desc = essName .. " ×1" }

    elseif picked == "cultivation_fruit" then
        return { type = "cultivation_fruit", consumableId = "exp_pill", count = 1, desc = "修炼果 ×1" }

    elseif picked == "lingyun_fruit" then
        return { type = "lingyun_fruit", consumableId = "lingyun_fruit", count = 1, desc = "灵韵果 ×1" }
    end

    return { type = "gold_bar", consumableId = "gold_bar", count = 1, desc = "金条 ×1" }
end

-- ============================================================================
-- 奖励发放（新版声望）
-- ============================================================================

--- 发放玩家选中的奖励（二选一后调用）
--- selectedItem 可能是法宝（isFabao=true）或物品掉落（type字段）
---@param selectedItem table 玩家选中的物品
---@param isFirstClear boolean
function ChallengeSystem.GrantReputationChoice(selectedItem, isFirstClear)
    if not selectedItem then return end

    -- 物品掉落（非法宝）
    if not selectedItem.isFabao then
        ChallengeSystem._grantExtraDrop(selectedItem)
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
---@param drop table { type, consumableId, essenceId, count, desc }
function ChallengeSystem._grantExtraDrop(drop)
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
-- 奖励发放（旧版 tiers，保留不变）
-- ============================================================================

--- 发放旧版首通奖励
function ChallengeSystem.GrantReward(faction, tier, reward)
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
                local used = ChallengeSystem[pillCfg.countField]
                if used < pillCfg.maxUse then
                    for _, b in ipairs(pillCfg.bonuses) do
                        player[b.stat] = (player[b.stat] or 0) + b.bonus
                    end
                    ChallengeSystem[pillCfg.countField] = used + 1
                    if player.pillCounts and reward.pillId then
                        local pcKey = reward.pillId:gsub("_dan$", "")
                        player.pillCounts[pcKey] = ChallengeSystem[pillCfg.countField]
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

--- 发放旧版重复掉落
function ChallengeSystem.GrantRepeatDrop(repeatDrop)
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

-- ============================================================================
-- 炼丹（使用精华 + 灵韵 → 凝X丹）
-- ============================================================================

--- 炼制一颗丹药
---@param pillId string e.g. "ningli_dan"
---@return boolean success
---@return string|nil message
function ChallengeSystem.BrewPill(pillId)
    local cfg = ChallengeSystem.NEW_PILL_CONFIG[pillId]
    if not cfg then return false, "丹药不存在" end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    -- 检查已使用次数
    local used = ChallengeSystem[cfg.countField] or 0
    if used >= cfg.maxUse then
        return false, cfg.name .. "已达上限（" .. cfg.maxUse .. "/" .. cfg.maxUse .. "）"
    end

    -- 检查精华（从背包读取）
    local InventorySystem = require("systems.InventorySystem")
    local essCount = InventorySystem.CountConsumable(cfg.essenceId) or 0
    if essCount < 1 then
        return false, cfg.essenceName .. "不足（需要 1，当前 " .. essCount .. "）"
    end

    -- 检查灵韵（灵韵是玩家货币，不是背包消耗品）
    if player.lingYun < cfg.lingYunCost then
        return false, "灵韵不足（需要 " .. cfg.lingYunCost .. "，当前 " .. player.lingYun .. "）"
    end

    -- 扣除材料
    InventorySystem.ConsumeConsumable(cfg.essenceId, 1)
    player.lingYun = player.lingYun - cfg.lingYunCost
    EventBus.Emit("player_lingyun_change", player.lingYun)

    -- 应用永久加成
    for _, b in ipairs(cfg.bonuses) do
        player[b.stat] = (player[b.stat] or 0) + b.bonus
    end
    ChallengeSystem[cfg.countField] = used + 1

    -- 双写 pillCounts
    if player.pillCounts then
        local pcKey = pillId:gsub("_dan$", "")
        player.pillCounts[pcKey] = ChallengeSystem[cfg.countField]
    end

    -- 如果有生命上限加成，同步回满
    for _, b in ipairs(cfg.bonuses) do
        if b.stat == "maxHp" then
            player.hp = math.min(player.hp + b.bonus, player:GetTotalMaxHp())
        end
    end

    print("[ChallengeSystem] Pill brewed: " .. cfg.name .. " (" .. ChallengeSystem[cfg.countField] .. "/" .. cfg.maxUse .. ")")

    -- 存档
    EventBus.Emit("save_request")

    return true, cfg.name .. "炼制成功！" .. cfg.effectDesc
end

-- ============================================================================
-- 副本内更新
-- ============================================================================

function ChallengeSystem.Update(dt, gameMap)
    if not ChallengeSystem.active then return end
    -- 玩家死亡由 DeathScreen/UI 处理退出
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

--- 序列化挑战进度（v3 格式）
---@return table
function ChallengeSystem.Serialize()
    local data = {
        version = 4,

        -- 旧版进度
        progress = {},
        xueshaDanCount = ChallengeSystem.xueshaDanCount,
        haoqiDanCount = ChallengeSystem.haoqiDanCount,

        -- 新版进度
        treasure_challenge = {},
        -- essence_counts 已迁移至背包，不再独立序列化

        -- 新版丹药
        ningliDanCount = ChallengeSystem.ningliDanCount,
        ningjiaDanCount = ChallengeSystem.ningjiaDanCount,
        ningyuanDanCount = ChallengeSystem.ningyuanDanCount,
        ninghunDanCount = ChallengeSystem.ninghunDanCount,
        ningxiDanCount = ChallengeSystem.ningxiDanCount,
    }

    -- 序列化旧版 progress
    for factionKey, tiers in pairs(ChallengeSystem.progress) do
        data.progress[factionKey] = {}
        for tier, p in pairs(tiers) do
            data.progress[factionKey][tostring(tier)] = {
                unlocked = p.unlocked,
                completed = p.completed,
            }
        end
    end

    -- 序列化新版 treasure_challenge
    for factionKey, treasures in pairs(ChallengeSystem.treasure_challenge) do
        data.treasure_challenge[factionKey] = {}
        for treasureKey, levels in pairs(treasures) do
            data.treasure_challenge[factionKey][treasureKey] = {}
            for levelStr, p in pairs(levels) do
                data.treasure_challenge[factionKey][treasureKey][levelStr] = {
                    unlocked = p.unlocked,
                    completed = p.completed,
                }
            end
        end
    end

    -- 精华已存入背包，不再独立序列化

    return data
end

--- 反序列化挑战进度
---@param data table
function ChallengeSystem.Deserialize(data)
    if not data then return end

    -- ────────────────────────────────────────
    -- 版本迁移 v1 → v2（旧：T1 自动解锁 → 需付费解锁）
    -- ────────────────────────────────────────
    if not data.version or data.version < 2 then
        print("[ChallengeSystem] Migrating from v1: resetting challenge progress")
        ChallengeSystem.xueshaDanCount = data.xueshaDanCount or 0
        ChallengeSystem.haoqiDanCount = data.haoqiDanCount or 0
        return
    end

    -- ────────────────────────────────────────
    -- 版本迁移 v2 → v3（旧：tiers → 新：reputation + 精华 + 凝X丹）
    -- ────────────────────────────────────────
    if data.version == 2 then
        print("[ChallengeSystem] Migrating from v2 to v3")

        -- 恢复旧版进度（旧 tiers 的数据保留）
        -- 注意：xueshaDanCount / haoqiDanCount 已被 MIGRATIONS[13] 从 challenges 移到 player，
        -- 此处 data.xueshaDanCount 是 nil。正确的值已由 SaveSerializer.DeserializePlayer 恢复
        -- 到 ChallengeSystem.xueshaDanCount，SaveLoader 会在 Deserialize 之后再覆盖一次。
        -- 所以这里不从 data 读，也不覆盖模块字段。

        if data.progress then
            for factionKey, tiers in pairs(data.progress) do
                if ChallengeSystem.progress[factionKey] then
                    for tierStr, p in pairs(tiers) do
                        local tier = tonumber(tierStr)
                        if tier and ChallengeSystem.progress[factionKey][tier] then
                            ChallengeSystem.progress[factionKey][tier].unlocked = p.unlocked or false
                            ChallengeSystem.progress[factionKey][tier].completed = p.completed or false
                        end
                    end
                end
            end
        end

        -- 迁移旧丹药 → 新丹药
        -- 血煞丹 → 凝力丹，浩气丹 → 凝元丹
        -- 从模块字段读取（由 DeserializePlayer 已恢复），不从 data 读（已被 MIGRATIONS[13] 清除）
        ChallengeSystem.ningliDanCount = ChallengeSystem.xueshaDanCount or 0
        ChallengeSystem.ningyuanDanCount = ChallengeSystem.haoqiDanCount or 0
        ChallengeSystem.ningjiaDanCount = 0
        ChallengeSystem.ninghunDanCount = 0
        ChallengeSystem.ningxiDanCount = 0

        -- 新版声望进度：根据旧版 progress 推导初始状态
        -- ⚠️ 此迁移仅对以下阵营有实际效果（拥有旧版 tiers + 新版 reputation 的阵营）：
        --   1. 血煞盟（xuesha）— v2 时代已上线，存量玩家有旧 progress 数据
        --   2. 浩气宗（haoqi） — v2 时代已上线，存量玩家有旧 progress 数据
        -- 未来新增的阵营（青云门、封魔殿等）如果不存在旧版 tiers 数据，
        -- 则 oldProgress 为 nil → hasChapter2=false → 不执行任何解锁，安全无副作用。
        for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
            if faction.reputation and ChallengeSystem.treasure_challenge[factionKey] then
                local oldProgress = data.progress and data.progress[factionKey]
                local hasChapter2 = oldProgress ~= nil
                local hasChapter3 = false
                if oldProgress then
                    for k, v in pairs(oldProgress) do
                        if tonumber(k) >= 5 and v.unlocked then
                            hasChapter3 = true
                            break
                        end
                    end
                end

                local tc = ChallengeSystem.treasure_challenge[factionKey][faction.treasureKey]
                if tc then
                    if hasChapter2 then
                        -- Ch2 已解锁 → 开启声望 1,2,3
                        for _, lvl in ipairs({1, 2, 3}) do
                            if tc[tostring(lvl)] then
                                tc[tostring(lvl)].unlocked = true
                            end
                        end
                    end
                    if hasChapter3 then
                        -- Ch3 已解锁 → 额外开启声望 4,5
                        for _, lvl in ipairs({4, 5}) do
                            if tc[tostring(lvl)] then
                                tc[tostring(lvl)].unlocked = true
                            end
                        end
                    end
                end
            end
        end

        -- 精华库存初始化为 0
        ChallengeSystem.essence_counts = {
            lipo_essence = 0,
            panshi_essence = 0,
            yuanling_essence = 0,
            shihun_essence = 0,
            lingxi_essence = 0,
        }

        print("[ChallengeSystem] v2→v3 migration done: ningliDan=" .. ChallengeSystem.ningliDanCount
            .. " ningyuanDan=" .. ChallengeSystem.ningyuanDanCount)
        return
    end

    -- ────────────────────────────────────────
    -- v3 → v4: 声望补偿迁移
    -- 原因: v2→v3 迁移时浩气宗尚未配置 reputation，被跳过。
    --       老玩家的浩气宗旧 tiers 进度未转换为 treasure_challenge 声望等级。
    -- 策略: 检测有旧 progress 但无已保存 treasure_challenge 的阵营，
    --       从旧进度推导声望解锁状态（与 v2→v3 相同逻辑），一次性执行。
    -- ────────────────────────────────────────
    if data.version == 3 or data.version == 4 then
        for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
            if faction.reputation and ChallengeSystem.treasure_challenge[factionKey] then
                local oldProgress = data.progress and data.progress[factionKey]
                if not oldProgress then goto continueFaction end

                -- 检查该阵营的 treasure_challenge 是否已有实质数据（任一 unlocked=true）
                -- 如果 hasSavedTC 存在但全是 false，说明是 v3 期间 Serialize 写入的空壳，
                -- 实际声望从未被迁移过，仍需补偿
                local alreadyMigrated = false
                local savedTC = data.treasure_challenge and data.treasure_challenge[factionKey]
                if savedTC then
                    for _, levels in pairs(savedTC) do
                        for _, p in pairs(levels) do
                            if p.unlocked then
                                alreadyMigrated = true
                                break
                            end
                        end
                        if alreadyMigrated then break end
                    end
                end

                if not alreadyMigrated then
                    local hasChapter2 = true  -- 有旧进度即表示曾进入过该阵营
                    local hasChapter3 = false
                    for k, v in pairs(oldProgress) do
                        if tonumber(k) >= 5 and v.unlocked then
                            hasChapter3 = true
                            break
                        end
                    end

                    local tc = ChallengeSystem.treasure_challenge[factionKey][faction.treasureKey]
                    if tc then
                        if hasChapter2 then
                            for _, lvl in ipairs({1, 2, 3}) do
                                if tc[tostring(lvl)] then tc[tostring(lvl)].unlocked = true end
                            end
                        end
                        if hasChapter3 then
                            for _, lvl in ipairs({4, 5}) do
                                if tc[tostring(lvl)] then tc[tostring(lvl)].unlocked = true end
                            end
                        end
                        print("[ChallengeSystem] v3→v4 retroactive migration: " .. factionKey
                            .. " ch2=" .. tostring(hasChapter2) .. " ch3=" .. tostring(hasChapter3))
                    end
                end

                ::continueFaction::
            end
        end
        -- 不 return，继续走正常反序列化加载其余数据
    end

    -- ────────────────────────────────────────
    -- v4 正常反序列化（兼容 v3）
    -- ────────────────────────────────────────

    -- 旧版丹药
    ChallengeSystem.xueshaDanCount = data.xueshaDanCount or 0
    ChallengeSystem.haoqiDanCount = data.haoqiDanCount or 0

    -- 新版丹药
    ChallengeSystem.ningliDanCount = data.ningliDanCount or 0
    ChallengeSystem.ningjiaDanCount = data.ningjiaDanCount or 0
    ChallengeSystem.ningyuanDanCount = data.ningyuanDanCount or 0
    ChallengeSystem.ninghunDanCount = data.ninghunDanCount or 0
    ChallengeSystem.ningxiDanCount = data.ningxiDanCount or 0

    -- 旧版 progress
    if data.progress then
        for factionKey, tiers in pairs(data.progress) do
            if ChallengeSystem.progress[factionKey] then
                for tierStr, p in pairs(tiers) do
                    local tier = tonumber(tierStr)
                    if tier and ChallengeSystem.progress[factionKey][tier] then
                        ChallengeSystem.progress[factionKey][tier].unlocked = p.unlocked or false
                        ChallengeSystem.progress[factionKey][tier].completed = p.completed or false
                    end
                end
            end
        end
    end

    -- 新版 treasure_challenge
    if data.treasure_challenge then
        for factionKey, treasures in pairs(data.treasure_challenge) do
            if ChallengeSystem.treasure_challenge[factionKey] then
                for treasureKey, levels in pairs(treasures) do
                    if ChallengeSystem.treasure_challenge[factionKey][treasureKey] then
                        for levelStr, p in pairs(levels) do
                            if ChallengeSystem.treasure_challenge[factionKey][treasureKey][levelStr] then
                                ChallengeSystem.treasure_challenge[factionKey][treasureKey][levelStr].unlocked = p.unlocked or false
                                ChallengeSystem.treasure_challenge[factionKey][treasureKey][levelStr].completed = p.completed or false
                            end
                        end
                    end
                end
            end
        end
    end

    -- 精华库存迁移：旧存档 essence_counts → 背包
    -- 旧存档会存有 essence_counts 数据，需要一次性迁入背包
    if data.essence_counts then
        local InventorySystem = require("systems.InventorySystem")
        for essId, count in pairs(data.essence_counts) do
            if count > 0 then
                InventorySystem.AddConsumable(essId, count)
                print("[ChallengeSystem] Migrated essence to backpack: " .. essId .. " x" .. count)
            end
        end
        -- 迁移完成后，不再写入 essence_counts（背包已持久化）
    end

    print("[ChallengeSystem] Deserialized v3: ningliDan=" .. ChallengeSystem.ningliDanCount
        .. " ningjiaDan=" .. ChallengeSystem.ningjiaDanCount
        .. " ningyuanDan=" .. ChallengeSystem.ningyuanDanCount
        .. " ninghunDan=" .. ChallengeSystem.ninghunDanCount
        .. " ningxiDan=" .. ChallengeSystem.ningxiDanCount)
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 获取旧版丹药配置
---@param pillId string
---@return table|nil
function ChallengeSystem.GetPillConfig(pillId)
    return LEGACY_PILL_CONFIG[pillId]
end

--- 获取新版丹药配置
---@param pillId string e.g. "ningli_dan"
---@return table|nil
function ChallengeSystem.GetNewPillConfig(pillId)
    return ChallengeSystem.NEW_PILL_CONFIG[pillId]
end

--- 获取精华数量（从背包读取）
---@param essenceId string
---@return number
function ChallengeSystem.GetEssenceCount(essenceId)
    local InventorySystem = require("systems.InventorySystem")
    return InventorySystem.CountConsumable(essenceId) or 0
end

function ChallengeSystem.IsActive()
    return ChallengeSystem.active
end

--- 获取当前挑战信息（新旧兼容）
---@return table|nil
function ChallengeSystem.GetActiveInfo()
    if not ChallengeSystem.active then return nil end

    local factionCfg = ChallengeConfig.FACTIONS[ChallengeSystem.currentFaction]

    -- 新版声望
    if ChallengeSystem.currentRepLevel then
        local repCfg = factionCfg and factionCfg.reputation[ChallengeSystem.currentRepLevel]
        return {
            faction = ChallengeSystem.currentFaction,
            repLevel = ChallengeSystem.currentRepLevel,
            factionName = factionCfg and factionCfg.name or "?",
            tierName = repCfg and repCfg.name or "?",
            monsterAlive = ChallengeSystem.challengeMonster and ChallengeSystem.challengeMonster.alive or false,
            isReputation = true,
        }
    end

    -- 旧版 tier
    local tierCfg = factionCfg and factionCfg.tiers[ChallengeSystem.currentTier]
    return {
        faction = ChallengeSystem.currentFaction,
        tier = ChallengeSystem.currentTier,
        factionName = factionCfg and factionCfg.name or "?",
        tierName = tierCfg and tierCfg.name or "?",
        monsterAlive = ChallengeSystem.challengeMonster and ChallengeSystem.challengeMonster.alive or false,
        isReputation = false,
    }
end

return ChallengeSystem
