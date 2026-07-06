-- ============================================================================
-- TreasureRunnerSystem.lua - Daily treasure runner monster (xiao zuanfeng)
-- ============================================================================

local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local MonsterData = require("config.MonsterData")
local EquipmentData = require("config.EquipmentData")
local Monster = require("entities.Monster")
local InventorySystem = require("systems.InventorySystem")
local LootSystem = require("systems.LootSystem")
local CombatSystem = require("systems.CombatSystem")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local TradeLock = require("systems.BlackMarketTradeLock")

local M = {}

local VERSION = 3
-- 钻风采用固定 100 段生命：每次有效命中只扣 1 格，不按普通伤害数值结算。
local HP_BARS = 100
local HIT_COOLDOWN = 0.45
local ENSURE_INTERVAL = 5.0
local DATE_CHECK_INTERVAL = 30.0

local CONFIG = {
    [1] = {
        monsterType = "ch1_xiao_zuanfeng",
        displayName = "小钻风",
        statSourceBoss = "tiger_king",
        portrait = "image/monster_xiao_zuanfeng_portrait_20260703120928.png",
        level = 16,
        realm = "lianqi_2",
        category = "king_boss",
        reward = {
            { id = "lingyun_fruit", min = 1, max = 2 },
            { id = "gold_bar", min = 1, max = 4 },
        },
        spawn = { x = 18.5, y = 40.5 },
        route = {
            { x = 18.5, y = 40.5 },
            { x = 8.5, y = 44.5 },
            { x = 6.5, y = 30.5 },
            { x = 9.5, y = 16.5 },
            { x = 18.5, y = 14.5 },
            { x = 25.5, y = 22.5 },
            { x = 25.5, y = 34.5 },
        },
    },
    [2] = {
        monsterType = "ch2_xiao_zuanfeng",
        displayName = "小钻风",
        statSourceBoss = "wu_wanhai",
        portrait = "image/monster_xiao_zuanfeng_portrait_20260703120928.png",
        level = 36,
        realm = "zhuji_3",
        category = "king_boss",
        reward = {
            { id = "lingyun_fruit", min = 2, max = 3 },
            { id = "gold_bar", min = 2, max = 8 },
        },
        specialDrop = {
            ring = { chance = 0.02, equipId = "dizun_ring_ch2" },
            fallback = { id = "wubao_token_box", count = 1 },
        },
        spawn = { x = 56.5, y = 62.5 },
        route = {
            { x = 38.5, y = 62.5 },
            { x = 50.5, y = 62.5 },
            { x = 62.5, y = 62.5 },
            { x = 74.5, y = 62.5 },
            { x = 74.5, y = 66.5 },
            { x = 62.5, y = 66.5 },
            { x = 50.5, y = 66.5 },
            { x = 38.5, y = 66.5 },
        },
    },
    [3] = {
        monsterType = "ch3_xiao_zuanfeng",
        displayName = "小钻风",
        statSourceBoss = "yao_king_1",
        portrait = "image/monster_xiao_zuanfeng_portrait_20260703120928.png",
        level = 65,
        realm = "yuanying_3",
        category = "emperor_boss",
        reward = {
            { id = "lingyun_fruit", min = 3, max = 5 },
            { id = "gold_bar", min = 3, max = 16 },
        },
        specialDrop = {
            ring = { chance = 0.01, equipId = "dizun_ring_ch3" },
            fallback = { id = "sha_hai_ling_box", count = 1 },
        },
        spawn = { x = 45.5, y = 70.5 },
        route = {
            { x = 45.5, y = 70.5 },
            { x = 34.5, y = 70.5 },
            { x = 32.5, y = 65.5 },
            { x = 35.5, y = 57.5 },
            { x = 45.5, y = 58.5 },
            { x = 47.5, y = 66.5 },
        },
    },
    [4] = {
        monsterType = "ch4_xiao_zuanfeng",
        displayName = "小钻风",
        statSourceBoss = "dragon_ice",
        portrait = "image/monster_xiao_zuanfeng_portrait_20260703120928.png",
        level = 100,
        realm = "dacheng_1",
        category = "emperor_boss",
        reward = {
            { id = "lingyun_fruit", min = 4, max = 7 },
            { id = "gold_bar", min = 4, max = 32 },
        },
        specialDrop = {
            ring = { chance = 0.005, equipId = "silong_ring_ch4" },
            fallback = { id = "taixu_token_box", count = 1 },
        },
        spawn = { x = 35.5, y = 68.5 },
        route = {
            { x = 35.5, y = 68.5 },
            { x = 42.5, y = 68.5 },
            { x = 43.5, y = 65.5 },
            { x = 35.5, y = 65.5 },
            { x = 35.5, y = 62.5 },
            { x = 43.5, y = 62.5 },
            { x = 43.5, y = 60.5 },
            { x = 35.5, y = 59.5 },
        },
    },
    [5] = {
        monsterType = "ch5_xiao_zuanfeng",
        displayName = "小钻风",
        statSourceBoss = "ch5_abyss_marshal",
        portrait = "image/monster_xiao_zuanfeng_portrait_20260703120928.png",
        level = 120,
        realm = "zhexian_1",
        category = "emperor_boss",
        reward = {
            { id = "lingyun_fruit", min = 5, max = 9 },
            { id = "gold_bar", min = 5, max = 64 },
        },
        specialDrop = {
            ring = { chance = 0.005, equipId = "dizun_ring_ch5" },
            fallback = { id = "taixu_jianling_box", count = 1 },
        },
        spawn = { x = 17.5, y = 47.5 },
        route = {
            { x = 17.5, y = 47.5 },
            { x = 8.5, y = 42.5 },
            { x = 17.5, y = 43.5 },
            { x = 18.5, y = 50.5 },
            { x = 16.5, y = 58.5 },
            { x = 8.5, y = 60.5 },
            { x = 7.5, y = 48.5 },
        },
    },
    [6] = {
        monsterType = "ch6_zong_zuanfeng",
        displayName = "总钻风",
        statSourceBoss = "ch6_mojun_shixuan",
        portrait = "image/monster_zong_zuanfeng_portrait_20260703120928.png",
        level = 140,
        realm = "renxian_1",
        category = "saint_boss",
        reward = {
            { id = "lingyun_fruit_superior", min = 1, max = 2 },
            { id = "gold_brick", min = 1, max = 3 },
        },
        specialDrop = {
            ring = { chance = 0.002, equipId = "ch6_xianzun_1_ring" },
            fallback = { id = "zhexian_ling_box", count = 1 },
        },
        spawn = { x = 18.5, y = 28.5 },
        route = {
            { x = 7.5, y = 28.5 },
            { x = 16.5, y = 24.5 },
            { x = 27.5, y = 28.5 },
            { x = 27.5, y = 40.5 },
            { x = 16.5, y = 44.5 },
            { x = 7.5, y = 38.5 },
        },
    },
}

local state_ = { version = VERSION, date = nil, highestChapter = 1, totalKilledToday = 0, slots = {} }
local lastGameMap_ = nil
---@type number
local ensureTimer_ = 0
---@type number
local dateTimer_ = 0

local function Today()
    return os.date("%Y-%m-%d")
end

local function DateKey(date)
    return tostring(date or Today()):gsub("%D", "")
end

local function CopyTable(t)
    local out = {}
    if not t then return out end
    for k, v in pairs(t) do
        if type(v) == "table" then
            out[k] = CopyTable(v)
        else
            out[k] = v
        end
    end
    return out
end

local function NormalizePaidBars(paidBars)
    local out = {}
    if type(paidBars) ~= "table" then return out end
    for key, value in pairs(paidBars) do
        if value then
            local barIndex = math.floor(tonumber(key) or 0)
            if barIndex >= 1 and barIndex <= HP_BARS then
                out[barIndex] = true
            end
        end
    end
    return out
end

local function ClearRuntimeMonsters()
    for _, monster in ipairs(GameState.monsters or {}) do
        if monster and monster.isTreasureRunner then
            monster.alive = false
            monster.state = "dead"
        end
    end
end

local function NewSlot(slotId, chapter, date)
    return {
        slotId = slotId,
        chapter = chapter,
        status = "available",
        activeInstanceId = nil,
        spawnPointKey = "ch" .. tostring(chapter) .. "_runner",
        hpBarsCurrent = HP_BARS,
        paidBars = {},
        hitGoldTotal = 0,
        rewardRunId = "tr_" .. DateKey(date) .. "_" .. tostring(slotId) .. "_001",
    }
end

local function GetHighestUnlockedChapter()
    local ChapterConfig = require("config.ChapterConfig")
    local highest = 1
    for chapter = 1, 6 do
        local cfg = ChapterConfig.Get(chapter)
        if cfg and not cfg.placeholder then
            local ok = ChapterConfig.CheckRequirements(chapter)
            if ok then highest = chapter end
        end
    end
    return highest
end

local function PickMiddleChapter(date, highest)
    if highest <= 2 then return nil end
    local count = highest - 2
    local seed = 0
    local s = tostring(date or "")
    for i = 1, #s do
        seed = seed + string.byte(s, i) * i
    end
    return 2 + (seed % count)
end

local function BuildDailyState(date, highest)
    local slots = {
        fixed_ch1 = NewSlot("fixed_ch1", 1, date),
    }
    if highest > 1 then
        slots.highest = NewSlot("highest", highest, date)
    end
    local middle = PickMiddleChapter(date, highest)
    if middle then
        slots.middle = NewSlot("middle", middle, date)
    end
    return {
        version = VERSION,
        date = date,
        serverDate = date,
        highestChapter = highest,
        totalKilledToday = 0,
        slots = slots,
    }
end

local function RecountKilled()
    local killed = 0
    for _, slot in pairs(state_.slots or {}) do
        if slot.status == "killed" then
            killed = killed + 1
        end
    end
    state_.totalKilledToday = killed
end

local function EnsureDailyState(force)
    local date = Today()
    if force or state_.date ~= date or type(state_.slots) ~= "table" then
        ClearRuntimeMonsters()
        state_ = BuildDailyState(date, GetHighestUnlockedChapter())
        return
    end
    RecountKilled()
end

local function IsPlayerOwnedSource(source)
    if not source then return false end
    if source == GameState.player or source == GameState.pet then return true end
    if source.owner and (source.owner == GameState.player or source.owner == GameState.pet) then return true end
    return false
end

local function FindSafeSpot(gameMap, x, y)
    if not gameMap or gameMap:IsWalkable(x, y) then return x, y end
    for r = 1, 6 do
        for dy = -r, r do
            for dx = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local tx = x + dx
                    local ty = y + dy
                    if gameMap:IsWalkable(tx, ty) then
                        return tx, ty
                    end
                end
            end
        end
    end
    return x, y
end

local function BuildSafeRoute(gameMap, route)
    local safe = {}
    for _, p in ipairs(route or {}) do
        local x, y = FindSafeSpot(gameMap, p.x, p.y)
        safe[#safe + 1] = { x = x, y = y }
    end
    return safe
end

local function FindSlotMonster(slotId)
    for _, m in ipairs(GameState.monsters or {}) do
        if m and m.alive and m.isTreasureRunner and m.treasureSlotId == slotId then
            return m
        end
    end
    return nil
end

local function GetBossGoldRange(chapter)
    local cfg = CONFIG[chapter]
    if not cfg then return 1, 1 end
    local boss = MonsterData.Types[cfg.statSourceBoss]
    if not boss then return 1, 1 end
    local stats = MonsterData.CalcFinalStats(
        boss.level or cfg.level,
        boss.category or cfg.category,
        boss.race,
        boss.realm or cfg.realm
    )
    return stats.goldMin or 1, stats.goldMax or 1
end

local function GetHitGoldAmount(chapter)
    local minGold = GetBossGoldRange(chapter)
    return math.max(1, math.floor(minGold / 10))
end

local function SpawnForSlot(slot, gameMap)
    local chapter = slot.chapter
    local cfg = CONFIG[chapter]
    if not cfg then return nil end
    local boss = MonsterData.Types[cfg.statSourceBoss] or {}
    local sx = tonumber((slot.lastKnownPosition and slot.lastKnownPosition.x) or cfg.spawn.x) or cfg.spawn.x
    local sy = tonumber((slot.lastKnownPosition and slot.lastKnownPosition.y) or cfg.spawn.y) or cfg.spawn.y
    sx, sy = FindSafeSpot(gameMap, sx, sy)
    sx = tonumber(sx) or cfg.spawn.x
    sy = tonumber(sy) or cfg.spawn.y

    local data = {
        name = cfg.displayName,
        icon = "💰",
        portrait = cfg.portrait or "image/monster_xiao_zuanfeng_portrait_20260703120928.png",
        category = "elite",
        race = boss.race or "human",
        level = cfg.level,
        realm = cfg.realm,
        hp = HP_BARS,
        atk = 1,
        def = 0,
        speed = 3.2,
        bodyColor = {80, 210, 160, 255},
        bodySize = 0.85,
        passive = true,
        dropTable = {},
    }

    local monster = Monster.New(data, sx, sy)
    monster.typeId = cfg.monsterType
    monster.isTreasureRunner = true
    monster.frameCategory = "saint_boss"
    monster.treasureSlotId = slot.slotId
    monster.treasureChapter = chapter
    monster.treasureRewardRunId = slot.rewardRunId
    monster.treasureMaxHpBars = HP_BARS
    monster.treasureHpBarsCurrent = slot.hpBarsCurrent or HP_BARS
    monster.hp = monster.treasureHpBarsCurrent
    monster.maxHp = HP_BARS
    monster.expReward = 0
    monster.goldReward = {0, 0}
    monster.dropTable = {}
    monster.state = "patrol"
    monster.patrolNodes = BuildSafeRoute(gameMap, cfg.route)
    monster.treasureTargetIndex = 1
    monster.treasureLastHitTime = -9999
    monster.treasureFleeTimer = 0
    monster.treasureStuckTimer = 0
    monster.treasureLastX = sx
    monster.treasureLastY = sy

    slot.status = "active"
    slot.activeInstanceId = slot.activeInstanceId or ("tr_" .. DateKey(state_.date) .. "_" .. tostring(slot.slotId))
    GameState.AddMonster(monster)
    print("[TreasureRunner] spawned " .. cfg.displayName .. " slot=" .. tostring(slot.slotId) .. " chapter=" .. tostring(chapter))
    return monster
end

function M.EnsureSpawn(gameMap, force)
    lastGameMap_ = gameMap or lastGameMap_
    EnsureDailyState(false)
    if not lastGameMap_ then return end

    local currentChapter = GameState.currentChapter or 1
    for _, slot in pairs(state_.slots or {}) do
        if slot.chapter == currentChapter and slot.status ~= "killed" and slot.status ~= "settling" then
            local monster = FindSlotMonster(slot.slotId)
            if not monster or force then
                if not monster then
                    SpawnForSlot(slot, lastGameMap_)
                end
            else
                slot.status = "active"
                slot.hpBarsCurrent = monster.treasureHpBarsCurrent or monster.hp or HP_BARS
                slot.lastKnownPosition = { x = monster.x, y = monster.y }
            end
        end
    end
end

function M.OnWorldReady(gameMap)
    lastGameMap_ = gameMap
    ensureTimer_ = 0
    M.EnsureSpawn(gameMap, false)
end

function M.Update(dt, gameMap)
    lastGameMap_ = gameMap or lastGameMap_
    dateTimer_ = dateTimer_ + dt
    if dateTimer_ >= DATE_CHECK_INTERVAL then
        dateTimer_ = 0
        EnsureDailyState(false)
    end
    ensureTimer_ = ensureTimer_ + dt
    if ensureTimer_ >= ENSURE_INTERVAL then
        ensureTimer_ = 0
        M.EnsureSpawn(lastGameMap_, false)
    end
end

local function NextRouteTarget(monster)
    local nodes = monster.patrolNodes
    if not nodes or #nodes == 0 then return nil end
    monster.treasureTargetIndex = (monster.treasureTargetIndex or 1)
    if monster.treasureTargetIndex < 1 or monster.treasureTargetIndex > #nodes then
        monster.treasureTargetIndex = 1
    end
    return nodes[monster.treasureTargetIndex]
end

function M.UpdateMonster(monster, dt, player, pet, gameMap)
    if not monster or not monster.alive then return end
    local slot = state_.slots and state_.slots[monster.treasureSlotId]
    if not slot or slot.status == "killed" then
        monster.alive = false
        return
    end

    slot.lastKnownPosition = { x = monster.x, y = monster.y }
    monster.target = nil
    monster.attackTimer = 0

    if monster.treasureFleeTimer and monster.treasureFleeTimer > 0 then
        monster.treasureFleeTimer = monster.treasureFleeTimer - dt
    end

    local target = monster.treasureFleeTarget
    if not target or (monster.treasureFleeTimer or 0) <= 0 then
        target = NextRouteTarget(monster)
    end
    if not target then return end

    local distSq = Utils.DistanceSq(monster.x, monster.y, target.x, target.y)
    if distSq < 0.25 then
        if monster.treasureFleeTarget then
            monster.treasureFleeTarget = nil
        else
            local nodes = monster.patrolNodes
            if nodes and #nodes > 0 then
                monster.treasureTargetIndex = (monster.treasureTargetIndex % #nodes) + 1
            end
        end
        target = NextRouteTarget(monster)
        if not target then return end
    end

    local speed = ((monster.treasureFleeTimer or 0) > 0) and 5.0 or 2.3
    monster:MoveToward(target.x, target.y, speed, dt, gameMap)

    local moved = Utils.DistanceSq(monster.x, monster.y, monster.treasureLastX or monster.x, monster.treasureLastY or monster.y)
    if moved < 0.0025 then
        monster.treasureStuckTimer = (monster.treasureStuckTimer or 0) + dt
    else
        monster.treasureStuckTimer = 0
        monster.treasureLastX = monster.x
        monster.treasureLastY = monster.y
    end
    if monster.treasureStuckTimer > 2.0 then
        local nodes = monster.patrolNodes
        if nodes and #nodes > 0 then
            monster.treasureTargetIndex = ((monster.treasureTargetIndex or 1) % #nodes) + 1
            local p = nodes[monster.treasureTargetIndex]
            monster.x, monster.y = FindSafeSpot(gameMap, p.x, p.y)
            slot.lastKnownPosition = { x = monster.x, y = monster.y }
        end
        monster.treasureStuckTimer = 0
    end
end

local function PayHitGold(slot, monster, barIndex)
    slot.paidBars = slot.paidBars or {}
    if slot.paidBars[barIndex] or slot.paidBars[tostring(barIndex)] then return end
    local amount = GetHitGoldAmount(slot.chapter)
    slot.paidBars[barIndex] = true
    slot.hitGoldTotal = (slot.hitGoldTotal or 0) + amount
    ---@type any
    local player = GameState.player
    if player then
        player.gold = (player.gold or 0) + amount
    end
    CombatSystem.AddFloatingText(monster.x, monster.y - 0.6, "+" .. tostring(amount) .. "金币", {255, 210, 80, 255}, 1.2)
    EventBus.Emit("save_request")
end

function M.HandleDamage(monster, damage, source)
    if not monster or not monster.alive then return 0 end
    if not IsPlayerOwnedSource(source) then return 0 end

    local slot = state_.slots and state_.slots[monster.treasureSlotId]
    if not slot or slot.status ~= "active" then return 0 end

    local now = GameState.gameTime or 0
    if now - (monster.treasureLastAppliedHit or -9999) < HIT_COOLDOWN then
        return 0
    end
    monster.treasureLastAppliedHit = now
    monster.treasureLastHitTime = now

    local current = math.max(0, slot.hpBarsCurrent or monster.hp or HP_BARS)
    if current <= 0 then return 0 end
    local barIndex = current
    PayHitGold(slot, monster, barIndex)

    current = current - 1
    slot.hpBarsCurrent = current
    monster.hp = current
    monster.treasureHpBarsCurrent = current
    monster.hurtFlashTimer = 0.18
    EventBus.Emit("monster_hurt", monster, 1)

    if source and source.x and source.y then
        local dx = monster.x - source.x
        local dy = monster.y - source.y
        local nx, ny = Utils.Normalize(dx, dy)
        local tx = monster.x + nx * 4
        local ty = monster.y + ny * 4
        tx, ty = FindSafeSpot(lastGameMap_, tx, ty)
        monster.treasureFleeTarget = { x = tx, y = ty }
    end
    monster.treasureFleeTimer = 3.0

    if current <= 0 then
        slot.status = "settling"
        monster:Die()
    end
    return 1
end

local function AddConsumablePlan(plan, itemId, count)
    if not itemId or not count or count <= 0 then return end
    plan.consumables[itemId] = (plan.consumables[itemId] or 0) + count
end

local function BuildRewardPlan(chapter)
    local cfg = CONFIG[chapter]
    local plan = { consumables = {}, equipments = {}, popupItems = {} }
    if not cfg then return plan end

    for _, reward in ipairs(cfg.reward or {}) do
        local minCount = tonumber(reward.min) or 1
        local maxCount = tonumber(reward.max) or minCount
        AddConsumablePlan(plan, reward.id, Utils.RandomInt(minCount, maxCount))
    end

    local special = cfg.specialDrop
    if special and special.ring and special.fallback then
        local ring = special.ring
        if math.random() < (ring.chance or 0) and EquipmentData.SpecialEquipment[ring.equipId] then
            plan.equipments[#plan.equipments + 1] = ring.equipId
        else
            AddConsumablePlan(plan, special.fallback.id, special.fallback.count or 1)
        end
    end

    return plan
end

local function CountConsumableSlotsNeeded(consumables)
    local manager = InventorySystem.GetManager()
    if not manager then return 999 end
    local capacities = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager:GetInventoryItem(i)
        if item and item.category == "consumable" and item.consumableId
            and not TradeLock.IsLocked(item) and not TradeLock.IsNoResell(item) then
            local free = GameConfig.MAX_STACK_COUNT - (item.count or 1)
            if free > 0 then
                capacities[item.consumableId] = (capacities[item.consumableId] or 0) + free
            end
        end
    end

    local needed = 0
    for itemId, count in pairs(consumables or {}) do
        local remaining = count - (capacities[itemId] or 0)
        if remaining > 0 then
            needed = needed + math.ceil(remaining / GameConfig.MAX_STACK_COUNT)
        end
    end
    return needed
end

local function CanWriteReward(plan)
    local needSlots = #plan.equipments + CountConsumableSlotsNeeded(plan.consumables)
    return InventorySystem.GetFreeSlots() >= needSlots, needSlots
end

local function MakeConsumablePopupEntry(itemId, count)
    return { itemId = itemId, count = count }
end

local function MakeEquipmentPopupEntry(item)
    return {
        name = item.name,
        icon = item.icon,
        quality = item.quality,
        desc = item.desc,
        count = 1,
    }
end

local function GrantReward(slot)
    local plan = BuildRewardPlan(slot.chapter)
    local ok, needSlots = CanWriteReward(plan)
    if not ok then
        return false, "背包空间不足，需要至少 " .. tostring(needSlots) .. " 个空格"
    end

    local popupItems = {}
    for _, equipId in ipairs(plan.equipments) do
        local item = LootSystem.CreateSpecialEquipment(equipId)
        if not item then
            return false, "装备配置缺失: " .. tostring(equipId)
        end
        local addOk = InventorySystem.AddItem(item)
        if not addOk then
            return false, "背包空间不足"
        end
        popupItems[#popupItems + 1] = MakeEquipmentPopupEntry(item)
    end

    local consumableIds = {}
    for itemId in pairs(plan.consumables) do consumableIds[#consumableIds + 1] = itemId end
    table.sort(consumableIds)
    for _, itemId in ipairs(consumableIds) do
        local count = plan.consumables[itemId]
        local addOk, added = InventorySystem.AddConsumable(itemId, count)
        if not addOk or added ~= count then
            return false, "背包空间不足"
        end
        popupItems[#popupItems + 1] = MakeConsumablePopupEntry(itemId, count)
    end

    return true, popupItems
end

function M.OnMonsterDeath(monster)
    if not monster or not monster.isTreasureRunner then return false end
    local slot = state_.slots and state_.slots[monster.treasureSlotId]
    if not slot then return true end
    if slot.rewardRunId ~= monster.treasureRewardRunId then return true end
    if slot.status ~= "settling" and slot.status ~= "active" then return true end

    local ok, result = GrantReward(slot)
    if ok then
        slot.status = "killed"
        slot.activeInstanceId = nil
        slot.hpBarsCurrent = 0
        slot.lastKnownPosition = { x = monster.x, y = monster.y }
        RecountKilled()
        EventBus.Emit("quest_granted_bundle_reward_popup", {
            title = (CONFIG[slot.chapter] and CONFIG[slot.chapter].displayName or "小钻风") .. "已击败",
            subtitle = "获得奖励",
            items = result,
        })
        EventBus.Emit("save_request")
        pcall(function()
            require("systems.SaveSystem").RequestImmediateSave("treasure_runner_kill")
        end)
        print("[TreasureRunner] reward granted slot=" .. tostring(slot.slotId))
    else
        slot.status = "available"
        slot.activeInstanceId = nil
        slot.hpBarsCurrent = HP_BARS
        slot.lastKnownPosition = { x = monster.x, y = monster.y }
        CombatSystem.AddFloatingText(monster.x, monster.y - 0.8, tostring(result or "奖励发放失败，重新挑战"), {255, 120, 100, 255}, 2.5)
        EventBus.Emit("save_request")
        ensureTimer_ = ENSURE_INTERVAL
        print("[TreasureRunner] reward failed: " .. tostring(result))
    end
    return true
end

function M.GetActiveMarkers(chapter)
    local markers = {}
    for _, monster in ipairs(GameState.monsters or {}) do
        if monster and monster.alive and monster.isTreasureRunner
            and (not chapter or monster.treasureChapter == chapter) then
            markers[#markers + 1] = {
                x = monster.x,
                y = monster.y,
                label = CONFIG[monster.treasureChapter] and CONFIG[monster.treasureChapter].displayName or "小钻风",
                slotId = monster.treasureSlotId,
            }
        end
    end
    return markers
end

function M.HasActiveMarker(chapter)
    return #M.GetActiveMarkers(chapter) > 0
end

function M.Serialize()
    EnsureDailyState(false)
    return CopyTable(state_)
end

function M.Deserialize(data)
    if type(data) ~= "table" then
        state_ = { version = VERSION, date = nil, highestChapter = 1, totalKilledToday = 0, slots = {} }
        return
    end
    state_ = CopyTable(data)
    local savedVersion = tonumber(state_.version) or 0
    state_.version = VERSION
    state_.slots = state_.slots or {}
    for slotId, slot in pairs(state_.slots) do
        slot.slotId = slot.slotId or slotId
        slot.paidBars = NormalizePaidBars(slot.paidBars)
        slot.hpBarsCurrent = tonumber(slot.hpBarsCurrent) or HP_BARS
        if slot.status == "settling" then
            slot.status = "available"
            slot.hpBarsCurrent = HP_BARS
        elseif slot.status ~= "killed" and savedVersion < VERSION and slot.hpBarsCurrent < HP_BARS then
            slot.hpBarsCurrent = HP_BARS
        elseif slot.status ~= "killed" and slot.hpBarsCurrent <= 0 then
            slot.hpBarsCurrent = HP_BARS
        end
    end
    RecountKilled()
end

function M.ResetRuntime()
    ClearRuntimeMonsters()
    state_ = { version = VERSION, date = nil, highestChapter = 1, totalKilledToday = 0, slots = {} }
    lastGameMap_ = nil
    ensureTimer_ = 0
    dateTimer_ = 0
end

function M.GMResetToday()
    ClearRuntimeMonsters()
    state_ = BuildDailyState(Today(), GetHighestUnlockedChapter())
    M.EnsureSpawn(lastGameMap_, true)
    EventBus.Emit("save_request")
    return true, "今日小钻风已重置"
end

function M.GMForceCurrentChapter()
    local chapter = GameState.currentChapter or 1
    if not CONFIG[chapter] then
        return false, "当前章节无小钻风配置"
    end
    local date = Today()
    ClearRuntimeMonsters()
    state_ = {
        version = VERSION,
        date = date,
        serverDate = date,
        highestChapter = chapter,
        totalKilledToday = 0,
        debugForced = true,
        slots = {
            gm_current = NewSlot("gm_current", chapter, date),
        },
    }
    M.EnsureSpawn(lastGameMap_, true)
    EventBus.Emit("save_request")
    return true, "已在当前章节强制刷新小钻风"
end

function M.GetDebugSummary()
    EnsureDailyState(false)
    local parts = { "date=" .. tostring(state_.date), "killed=" .. tostring(state_.totalKilledToday or 0) }
    for slotId, slot in pairs(state_.slots or {}) do
        parts[#parts + 1] = tostring(slotId) .. ":ch" .. tostring(slot.chapter) .. "/" .. tostring(slot.status) .. "/" .. tostring(slot.hpBarsCurrent or HP_BARS)
    end
    table.sort(parts)
    return table.concat(parts, " | ")
end

return M
