-- ============================================================================
-- ChallengeSystem.lua - 阵营挑战/法宝系统（v4）— Facade
-- 血煞盟·殷无咎（新版声望） / 浩气宗·陆青云（旧版 tiers）
-- 新版：8 级声望（T3-T10），法宝掉落，5 种凝X丹，精华材料
-- 旧版：8 级 tiers（T1-T8），专属装备 + 血煞丹/浩气丹
-- ============================================================================

local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local ChallengeConfig = require("config.ChallengeConfig")

local arena       = require("systems.challenge.arena")
local rewards     = require("systems.challenge.rewards")
local persistence = require("systems.challenge.persistence")

local ChallengeSystem = {}

-- ============================================================================
-- 运行时状态
-- ============================================================================

-- === 旧版进度（tiers 阵营使用） ===
ChallengeSystem.progress = {}

-- === 新版进度（reputation 阵营使用） ===
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
ChallengeSystem.active = false
ChallengeSystem.currentFaction = nil
ChallengeSystem.currentTier = nil
ChallengeSystem.currentRepLevel = nil
ChallengeSystem.challengeMonster = nil
ChallengeSystem.rewardCollected = false

-- 副本覆盖层备份
ChallengeSystem._backup = nil
ChallengeSystem._camera = nil

-- === 旧版丹药计数 ===
ChallengeSystem.xueshaDanCount = 0
ChallengeSystem.haoqiDanCount = 0

-- === 新版丹药计数（凝X丹系列） ===
ChallengeSystem.ningliDanCount = 0
ChallengeSystem.ningjiaDanCount = 0
ChallengeSystem.ningyuanDanCount = 0
ChallengeSystem.ninghunDanCount = 0
ChallengeSystem.ningxiDanCount = 0
ChallengeSystem.gangguDanCount = 0

-- ============================================================================
-- 新版丹药配置
-- ============================================================================

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
    ganggu_dan = {
        bonuses = { { stat = "constitution", bonus = 1, desc = "根骨" } },
        maxUse = 50,
        countField = "gangguDanCount",
        name = "钢筋铁骨丹",
        icon = "🦴",
        essenceId = "ganggu_essence",
        essenceName = "钢骨精华",
        lingYunCost = 1000,
        effectDesc = "永久增加根骨+1",
        color = {240, 200, 80, 255},
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
    ChallengeSystem.gangguDanCount = 0

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
            for level = 1, ChallengeConfig.MAX_REPUTATION_LEVEL do
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

    print("[ChallengeSystem] Initialized (v4)")
end

-- ============================================================================
-- 进度查询
-- ============================================================================

---@param faction string
---@param tier number
---@return table|nil { unlocked, completed }
function ChallengeSystem.GetProgress(faction, tier)
    if ChallengeSystem.progress[faction] then
        return ChallengeSystem.progress[faction][tier]
    end
    return nil
end

---@param factionKey string
---@param repLevel number 1-8
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

---判断某一层是否已完成
---@param factionKey string
---@param level number tier(旧版) 或 repLevel(新版)
---@param isReputation boolean|nil 为 true 时查新版 reputation 进度
---@return boolean
function ChallengeSystem.IsCompleted(factionKey, level, isReputation)
    local prog
    if isReputation then
        prog = ChallengeSystem.GetReputationProgress(factionKey, level)
    else
        prog = ChallengeSystem.GetProgress(factionKey, level)
    end
    return prog ~= nil and prog.completed == true
end

--- 判断某一关/声望等级是否已解锁（第一关/第一级永远解锁，后续要求前一级已通关）
---@param factionKey string
---@param level number tier(旧版) 或 repLevel(新版)
---@param isReputation boolean|nil 为 true 时查新版 reputation 进度
---@return boolean
function ChallengeSystem.IsUnlocked(factionKey, level, isReputation)
    if level <= 1 then return true end
    return ChallengeSystem.IsCompleted(factionKey, level - 1, isReputation)
end

-- ============================================================================
-- 炼丹
-- ============================================================================

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
    local essCount = InventorySystem.CountUnlockedConsumable(cfg.essenceId) or 0
    if essCount < 1 then
        return false, cfg.essenceName .. "不足（需要 1，当前 " .. essCount .. "）"
    end

    -- 检查灵韵
    if player.lingYun < cfg.lingYunCost then
        return false, "灵韵不足（需要 " .. cfg.lingYunCost .. "，当前 " .. player.lingYun .. "）"
    end

    -- 扣除材料
    local ok = InventorySystem.ConsumeConsumable(cfg.essenceId, 1)
    if not ok then return false, cfg.essenceName .. "扣除失败（可能被锁定）" end
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

    EventBus.Emit("save_request")

    return true, cfg.name .. "炼制成功！" .. cfg.effectDesc
end

-- ============================================================================
-- 查询接口
-- ============================================================================

local shared = require("systems.challenge.shared")

---@param pillId string
---@return table|nil
function ChallengeSystem.GetPillConfig(pillId)
    return shared.LEGACY_PILL_CONFIG[pillId]
end

---@param pillId string e.g. "ningli_dan"
---@return table|nil
function ChallengeSystem.GetNewPillConfig(pillId)
    return ChallengeSystem.NEW_PILL_CONFIG[pillId]
end

---@param essenceId string
---@return number
function ChallengeSystem.GetEssenceCount(essenceId)
    local InventorySystem = require("systems.InventorySystem")
    return InventorySystem.CountConsumable(essenceId) or 0
end

function ChallengeSystem.IsActive()
    return ChallengeSystem.active
end

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

-- ============================================================================
-- 委托子模块（绑定 CS 参数）
-- ============================================================================

-- arena sub-module
function ChallengeSystem.Unlock(faction, tier)
    return arena.Unlock(ChallengeSystem, faction, tier)
end
function ChallengeSystem.UnlockReputation(factionKey, repLevel)
    return arena.UnlockReputation(ChallengeSystem, factionKey, repLevel)
end
function ChallengeSystem.Enter(faction, tier, gameMap, camera)
    return arena.Enter(ChallengeSystem, faction, tier, gameMap, camera)
end
function ChallengeSystem.EnterReputation(factionKey, repLevel, gameMap, camera)
    return arena.EnterReputation(ChallengeSystem, factionKey, repLevel, gameMap, camera)
end
function ChallengeSystem._createArena(gameMap, camera, monsterId, factionCfg)
    return arena._createArena(ChallengeSystem, gameMap, camera, monsterId, factionCfg)
end
function ChallengeSystem.Exit(gameMap, isVictory, camera)
    return arena.Exit(ChallengeSystem, gameMap, isVictory, camera)
end
function ChallengeSystem._rollback(gameMap, camera)
    return arena._rollback(ChallengeSystem, gameMap, camera)
end
function ChallengeSystem.Update(dt, gameMap)
    return arena.Update(ChallengeSystem, dt, gameMap)
end

-- rewards sub-module
function ChallengeSystem.OnMonsterDeath(monster)
    return rewards.OnMonsterDeath(ChallengeSystem, monster)
end
function ChallengeSystem._onRepMonsterDeath(factionKey, repLevel)
    return rewards._onRepMonsterDeath(ChallengeSystem, factionKey, repLevel)
end
function ChallengeSystem._buildExtraDropItem(entry)
    return rewards._buildExtraDropItem(entry)
end
function ChallengeSystem._rollExtraDrop(repLevel)
    return rewards._rollExtraDrop(ChallengeSystem, repLevel)
end
function ChallengeSystem.GrantReputationChoice(selectedItem, isFirstClear)
    return rewards.GrantReputationChoice(ChallengeSystem, selectedItem, isFirstClear)
end
function ChallengeSystem._grantExtraDrop(drop)
    return rewards._grantExtraDrop(ChallengeSystem, drop)
end
function ChallengeSystem.GrantReward(faction, tier, reward)
    return rewards.GrantReward(ChallengeSystem, faction, tier, reward)
end
function ChallengeSystem.GrantRepeatDrop(repeatDrop)
    return rewards.GrantRepeatDrop(ChallengeSystem, repeatDrop)
end

-- persistence sub-module
function ChallengeSystem.Serialize()
    return persistence.Serialize(ChallengeSystem)
end
function ChallengeSystem.Deserialize(data)
    return persistence.Deserialize(ChallengeSystem, data)
end

return ChallengeSystem
