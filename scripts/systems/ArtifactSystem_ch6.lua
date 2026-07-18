-- ============================================================================
-- ArtifactSystem_ch6.lua - 第六章神器「界匙」
-- 九格激活、账号级进度、双王竞技场、属性重算与被动「两界替命」。
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")
local SaveState = require("systems.save.SaveState")
local SaveSerializer = require("systems.save.SaveSerializer")

local ArtifactCh6 = {}

ArtifactCh6.VERSION = 1
ArtifactCh6.GRID_COUNT = 9
ArtifactCh6.GRID_NAMES = { "一", "二", "三", "四", "五", "六", "七", "八", "九" }
ArtifactCh6.FRAGMENT_IDS = {
    "jieshi_fragment_1",
    "jieshi_fragment_2",
    "jieshi_fragment_3",
    "jieshi_fragment_4",
    "jieshi_fragment_5",
    "jieshi_fragment_6",
    "jieshi_fragment_7",
    "jieshi_fragment_8",
    "jieshi_fragment_9",
}

ArtifactCh6.ACTIVATE_GOLD_COST = 30000000
ArtifactCh6.ACTIVATE_LINGYUN_COST = 30000
ArtifactCh6.PER_GRID_BONUS = {
    maxHp = 150,
    hpRegen = 10,
    fortune = 10,
}
ArtifactCh6.FULL_BONUS = {
    maxHp = 150,
    hpRegen = 10,
    fortune = 10,
}

ArtifactCh6.FULL_IMAGE = "image/ch6_jieshi_full_array_20260711011456.png"
ArtifactCh6.WORLD_IMAGE = "image/ch6_jieshi_world_artifact_20260711011456.png"
ArtifactCh6.KEY_RUNE_IMAGE = "image/ch6_jieshi_key_rune_20260711011456.png"
ArtifactCh6.RIFT_IMAGE = "image/ch6_jieshi_vertical_rift_20260711011456.png"

ArtifactCh6.PASSIVE = {
    name = "两界替命",
    desc = "受到致命伤害时恢复至25%最大生命并进入影界无敌3秒，内置冷却180秒",
    cooldown = 180,
    invincibleDuration = 3.0,
    healRatio = 0.25,
}

ArtifactCh6.BOSS_IMPLEMENTED = true
ArtifactCh6.ARENA_SIZE = 12
ArtifactCh6.PLAYER_SPAWN_Y_OFFSET = 4.0
ArtifactCh6.BOSS_SPAWN_X_OFFSET = 2.5
ArtifactCh6.BOSS_SPAWN_Y_OFFSET = -2.0
ArtifactCh6.BOSS_MONSTER_IDS = {
    "artifact_ch6_gua_demon",
    "artifact_ch6_gua_immortal",
}
ArtifactCh6.activatedGrids = {
    false, false, false,
    false, false, false,
    false, false, false,
}
ArtifactCh6.bossDefeated = false
ArtifactCh6.passiveUnlocked = false
ArtifactCh6.rescueReadyAt = 0
ArtifactCh6.gmBypass = false
ArtifactCh6.arenaActive = false
ArtifactCh6._backup = nil
ArtifactCh6._gameMap = nil
ArtifactCh6._camera = nil

local busy_ = false
local cooldownSavePending_ = false
local cooldownSaveInFlight_ = false
local cooldownRetryTimer_ = 0
local timeProvider_ = os.time

local PLAYER_SNAPSHOT_FIELDS = {
    "gold", "lingYun", "hp", "alive",
    "artifactCh6MaxHp", "artifactCh6HpRegen", "artifactCh6Fortune",
}

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return out
end

local function NewGridState()
    return {
        false, false, false,
        false, false, false,
        false, false, false,
    }
end

local function NormalizeTimestamp(value)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge then
        return 0
    end
    return math.max(0, math.floor(value))
end

local function NormalizeProgress(data, includeCooldown)
    local normalized = {
        version = ArtifactCh6.VERSION,
        activatedGrids = NewGridState(),
        bossDefeated = false,
        passiveUnlocked = false,
    }
    if includeCooldown then normalized.rescueReadyAt = 0 end
    if type(data) ~= "table" then return normalized end

    local sourceGrids = type(data.activatedGrids) == "table"
        and data.activatedGrids or {}
    local allActive = true
    for i = 1, ArtifactCh6.GRID_COUNT do
        normalized.activatedGrids[i] = sourceGrids[i] == true
        if not normalized.activatedGrids[i] then allActive = false end
    end

    normalized.bossDefeated = allActive and data.bossDefeated == true
    normalized.passiveUnlocked = normalized.bossDefeated
        and data.passiveUnlocked == true
    if includeCooldown then
        normalized.rescueReadyAt = NormalizeTimestamp(data.rescueReadyAt)
    end
    return normalized
end

local function GetAtlasSystem()
    local ok, AtlasSystem = pcall(require, "systems.AtlasSystem")
    return ok and AtlasSystem or nil
end

local function SyncAccountState()
    local AtlasSystem = GetAtlasSystem()
    if not AtlasSystem or not AtlasSystem.data then return false end
    AtlasSystem.data.version = math.max(3, tonumber(AtlasSystem.data.version) or 1)
    AtlasSystem.data.artifact_jieshi = DeepCopy(ArtifactCh6.SerializeAccount())
    if AtlasSystem.MarkArtifactJieshiAccountLoaded then
        AtlasSystem.MarkArtifactJieshiAccountLoaded()
    end
    return true
end

local function GetPlayerSnapshot(player)
    local snapshot = {}
    if not player then return snapshot end
    for _, field in ipairs(PLAYER_SNAPSHOT_FIELDS) do
        snapshot[field] = DeepCopy(player[field])
    end
    return snapshot
end

local function RestorePlayerSnapshot(player, snapshot)
    if not player or not snapshot then return end
    for _, field in ipairs(PLAYER_SNAPSHOT_FIELDS) do
        player[field] = DeepCopy(snapshot[field])
    end
    if player.InvalidateStatsCache then
        player:InvalidateStatsCache()
    else
        player._statsCacheFrame = -1
    end
    EventBus.Emit("player_lingyun_change", player.lingYun or 0)
end

local function MakeSnapshot()
    local AtlasSystem = GetAtlasSystem()
    return {
        progress = ArtifactCh6.SerializeAccount(),
        account = AtlasSystem and AtlasSystem.data
            and DeepCopy(AtlasSystem.data.artifact_jieshi) or nil,
        inventory = DeepCopy(SaveSerializer.SerializeInventory()),
        player = GetPlayerSnapshot(GameState.player),
    }
end

local function RestoreSnapshot(snapshot)
    if not snapshot then return end
    ArtifactCh6.ApplyAccountState(snapshot.progress)
    SaveSerializer.DeserializeInventory(snapshot.inventory)
    RestorePlayerSnapshot(GameState.player, snapshot.player)

    local AtlasSystem = GetAtlasSystem()
    if AtlasSystem and AtlasSystem.data then
        AtlasSystem.data.artifact_jieshi = DeepCopy(snapshot.account)
            or ArtifactCh6.SerializeAccount()
    end
    ArtifactCh6.RecalcAttributes()
end

local function GetSaveBlockReason()
    if not SaveState.loaded then return "存档尚未加载，暂时不能激活界匙" end
    if not SaveState.activeSlot then return "当前没有激活的角色存档" end
    if SaveState.saving then return "正在保存，请稍后再试" end
    if SaveState._retryTimer then return "存档正在等待重试，请稍后再试" end
    if SaveState._disconnected then return "网络断开，无法安全保存界匙进度" end

    local AtlasSystem = GetAtlasSystem()
    if not AtlasSystem or not AtlasSystem.loaded or not AtlasSystem.data then
        return "账号神器档案尚未加载"
    end
    return nil
end

local function TrySaveCooldown()
    if not cooldownSavePending_ or cooldownSaveInFlight_ then return false end
    if busy_ or GetSaveBlockReason() then return false end

    cooldownSaveInFlight_ = true
    local SaveSystem = require("systems.SaveSystem")
    local callbackCalled = false
    local function finish(ok, reason)
        if callbackCalled then return end
        callbackCalled = true
        cooldownSaveInFlight_ = false
        if ok then
            cooldownSavePending_ = false
            cooldownRetryTimer_ = 0
            print("[ArtifactCh6] Rescue cooldown saved")
        else
            cooldownRetryTimer_ = 3
            print("[ArtifactCh6] Rescue cooldown save failed, retry queued: "
                .. tostring(reason or "unknown"))
        end
    end

    local ok, err = pcall(function()
        SaveSystem.Save(finish)
    end)
    if not ok then finish(false, err) end
    return true
end

function ArtifactCh6.GetActivatedCount()
    local count = 0
    for i = 1, ArtifactCh6.GRID_COUNT do
        if ArtifactCh6.activatedGrids[i] then count = count + 1 end
    end
    return count
end

function ArtifactCh6.IsGridActivated(index)
    return ArtifactCh6.activatedGrids[index] == true
end

function ArtifactCh6.GetFragmentCount(index)
    local fragmentId = ArtifactCh6.FRAGMENT_IDS[index]
    if not fragmentId then return 0 end
    return InventorySystem.CountUnlockedConsumable(fragmentId) or 0
end

function ArtifactCh6.IsBusy()
    return busy_
end

function ArtifactCh6.CanActivate(index)
    if type(index) ~= "number" or index ~= math.floor(index)
        or index < 1 or index > ArtifactCh6.GRID_COUNT then
        return false, "无效的格子序号"
    end
    if busy_ then return false, "界匙操作正在保存" end
    if ArtifactCh6.activatedGrids[index] then return false, "该位格已激活" end

    local saveBlock = GetSaveBlockReason()
    if saveBlock then return false, saveBlock end
    if ArtifactCh6.gmBypass then return true, "" end

    if ArtifactCh6.GetFragmentCount(index) <= 0 then
        local fragment = GameConfig.CONSUMABLES[ArtifactCh6.FRAGMENT_IDS[index]]
        return false, "缺少" .. (fragment and fragment.name
            or ("界匙碎片·" .. ArtifactCh6.GRID_NAMES[index]))
    end

    local player = GameState.player
    if not player then return false, "角色数据异常" end
    if (player.gold or 0) < ArtifactCh6.ACTIVATE_GOLD_COST then
        return false, "金币不足（需要"
            .. ArtifactCh6.FormatGold(ArtifactCh6.ACTIVATE_GOLD_COST) .. "）"
    end
    if (player.lingYun or 0) < ArtifactCh6.ACTIVATE_LINGYUN_COST then
        return false, "灵韵不足（需要"
            .. tostring(ArtifactCh6.ACTIVATE_LINGYUN_COST) .. "）"
    end
    return true, ""
end

---@param index number
---@param callback fun(success: boolean, message: string, details: table|nil)|nil
---@return boolean started
---@return string message
function ArtifactCh6.Activate(index, callback)
    local canActivate, reason = ArtifactCh6.CanActivate(index)
    if not canActivate then return false, reason end

    local player = GameState.player
    local snapshot = MakeSnapshot()
    busy_ = true

    if not ArtifactCh6.gmBypass then
        local consumed = InventorySystem.ConsumeConsumable(
            ArtifactCh6.FRAGMENT_IDS[index], 1)
        if not consumed then
            busy_ = false
            return false, "碎片扣除失败（可能被锁定）"
        end
        player.gold = (player.gold or 0) - ArtifactCh6.ACTIVATE_GOLD_COST
        player.lingYun = (player.lingYun or 0) - ArtifactCh6.ACTIVATE_LINGYUN_COST
        EventBus.Emit("player_lingyun_change", player.lingYun)
    end

    ArtifactCh6.activatedGrids[index] = true
    ArtifactCh6.RecalcAttributes()
    SyncAccountState()

    local total = ArtifactCh6.GetActivatedCount()
    local maxHp, hpRegen, fortune = ArtifactCh6.GetCurrentBonus()
    local details = {
        index = index,
        total = total,
        maxHp = maxHp,
        hpRegen = hpRegen,
        fortune = fortune,
    }
    local SaveSystem = require("systems.SaveSystem")
    local callbackCalled = false

    local function finish(ok, saveReason)
        if callbackCalled then return end
        callbackCalled = true
        busy_ = false
        if ok then
            EventBus.Emit("artifact_ch6_grid_activated", details)
            local message = "激活「界匙·第" .. ArtifactCh6.GRID_NAMES[index]
                .. "位」成功"
            if callback then callback(true, message, details) end
        else
            RestoreSnapshot(snapshot)
            local message = "保存失败，界匙激活已回滚："
                .. tostring(saveReason or "unknown")
            if callback then callback(false, message, nil) end
        end
    end

    local ok, err = pcall(function()
        SaveSystem.Save(finish)
    end)
    if not ok then finish(false, err) end
    return true, "界匙激活保存中"
end

function ArtifactCh6.GetCurrentBonus()
    local count = ArtifactCh6.GetActivatedCount()
    local maxHp = count * ArtifactCh6.PER_GRID_BONUS.maxHp
    local hpRegen = count * ArtifactCh6.PER_GRID_BONUS.hpRegen
    local fortune = count * ArtifactCh6.PER_GRID_BONUS.fortune
    if count >= ArtifactCh6.GRID_COUNT then
        maxHp = maxHp + ArtifactCh6.FULL_BONUS.maxHp
        hpRegen = hpRegen + ArtifactCh6.FULL_BONUS.hpRegen
        fortune = fortune + ArtifactCh6.FULL_BONUS.fortune
    end
    return maxHp, hpRegen, fortune
end

function ArtifactCh6.RecalcAttributes()
    local player = GameState.player
    if not player then return end
    local maxHp, hpRegen, fortune = ArtifactCh6.GetCurrentBonus()
    player.artifactCh6MaxHp = maxHp
    player.artifactCh6HpRegen = hpRegen
    player.artifactCh6Fortune = fortune
    if player.InvalidateStatsCache then
        player:InvalidateStatsCache()
    else
        player._statsCacheFrame = -1
    end
    print("[ArtifactCh6] Attributes: maxHp=" .. maxHp
        .. " hpRegen=" .. hpRegen .. " fortune=" .. fortune)
end

local function IsOtherArenaActive(moduleName)
    local ok, system = pcall(require, moduleName)
    return ok and system and system.arenaActive == true
end

function ArtifactCh6.CanFightBoss()
    if ArtifactCh6.bossDefeated then
        return false, "界匙双王已被击败"
    end
    if ArtifactCh6.GetActivatedCount() < ArtifactCh6.GRID_COUNT then
        return false, "界匙九格尚未全部激活"
    end
    if not ArtifactCh6.BOSS_IMPLEMENTED then
        return false, "界匙神器Boss尚未开放"
    end
    if busy_ then return false, "界匙进度正在保存" end
    if ArtifactCh6.arenaActive then return false, "已在界匙双王战斗中" end

    local saveBlock = GetSaveBlockReason()
    if saveBlock then return false, saveBlock end

    local okChallenge, ChallengeSystem = pcall(require, "systems.ChallengeSystem")
    if okChallenge and ChallengeSystem and ChallengeSystem.active then
        return false, "正在挑战中，无法同时进入"
    end

    local arenaModules = {
        "systems.ArtifactSystem",
        "systems.ArtifactSystem_ch4",
        "systems.ArtifactSystem_ch5",
        "systems.ArtifactSystem_tiandi",
    }
    for _, moduleName in ipairs(arenaModules) do
        if IsOtherArenaActive(moduleName) then
            return false, "正在神器战斗中，无法同时进入"
        end
    end
    return true, ""
end

local function ApplyArtifactBossStats(boss, data)
    local hpMult = tonumber(data.artifactCh6HpMult) or 1
    local atkMult = tonumber(data.artifactCh6AtkMult) or 1
    local defMult = tonumber(data.artifactCh6DefMult) or 1
    local speedMult = tonumber(data.artifactCh6SpeedMult) or 1

    boss.maxHp = math.max(1, math.floor((boss.maxHp or 1) * hpMult))
    boss.hp = boss.maxHp
    boss.atk = math.max(1, math.floor((boss.atk or 1) * atkMult))
    boss.def = math.max(0, math.floor((boss.def or 0) * defMult))
    boss.speed = math.max(0.1, (boss.speed or 1) * speedMult)
    boss.baseAtk = boss.atk
    boss.baseSpeed = boss.speed
end

local function SpawnArtifactBoss(monsterId, x, y)
    local MonsterData = require("config.MonsterData")
    local Monster = require("entities.Monster")
    local data = MonsterData.Types[monsterId]
    if not data then return nil, "BOSS数据不存在：" .. tostring(monsterId) end

    local boss = Monster.New(data, x, y)
    boss.typeId = monsterId
    boss.isArtifactBoss = true
    boss.isArtifactCh6Boss = true
    boss.artifactCh6Aspect = data.artifactCh6Aspect
    boss.artifactCh6HealTimer = tonumber(data.artifactCh6HealInterval) or 0
    boss.artifactCh6BlessingTimer = 0
    ApplyArtifactBossStats(boss, data)
    GameState.AddMonster(boss)
    return boss, nil
end

---@param gameMap table
---@param camera table|nil
function ArtifactCh6._rollback(gameMap, camera)
    local backup = ArtifactCh6._backup
    if not backup then return end

    gameMap.tiles = backup.tiles
    gameMap.width = backup.width
    gameMap.height = backup.height

    local player = GameState.player
    if player then
        player.x = backup.playerX
        player.y = backup.playerY
        if player.SetMoveDirection then player:SetMoveDirection(0, 0) end
    end

    GameState.monsters = backup.monsters or {}
    GameState.npcs = backup.npcs or {}
    GameState.lootDrops = backup.lootDrops or {}
    GameState.bossKillTimes = backup.bossKillTimes or {}

    local cam = camera or ArtifactCh6._camera
    if cam and backup.cameraX ~= nil then
        cam.x = backup.cameraX
        cam.y = backup.cameraY
        cam.mapWidth = backup.cameraMapW
        cam.mapHeight = backup.cameraMapH
    end

    ArtifactCh6._backup = nil
    ArtifactCh6._gameMap = nil
    ArtifactCh6._camera = nil
    ArtifactCh6.arenaActive = false
end

---@param gameMap table
---@param camera table|nil
---@return boolean success
---@return string|nil message
function ArtifactCh6.EnterBossArena(gameMap, camera)
    local canFight, reason = ArtifactCh6.CanFightBoss()
    if not canFight then return false, reason end
    if not gameMap or type(gameMap.tiles) ~= "table" then
        return false, "地图数据异常"
    end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    local okReturn, TownReturnSystem = pcall(
        require, "systems.TownReturnSystem")
    if okReturn and TownReturnSystem
        and TownReturnSystem.IsChanneling
        and TownReturnSystem.IsChanneling() then
        TownReturnSystem.Cancel()
    end

    local TileTypes = require("config.TileTypes")
    local T = TileTypes.TILE
    local totalSize = ArtifactCh6.ARENA_SIZE + 2

    ArtifactCh6._backup = {
        tiles = gameMap.tiles,
        width = gameMap.width,
        height = gameMap.height,
        playerX = player.x,
        playerY = player.y,
        monsters = GameState.monsters,
        npcs = GameState.npcs,
        lootDrops = GameState.lootDrops,
        bossKillTimes = GameState.bossKillTimes,
        cameraX = camera and camera.x or nil,
        cameraY = camera and camera.y or nil,
        cameraMapW = camera and camera.mapWidth or nil,
        cameraMapH = camera and camera.mapHeight or nil,
    }

    gameMap.width = totalSize
    gameMap.height = totalSize
    gameMap.tiles = {}
    for y = 1, totalSize do
        gameMap.tiles[y] = {}
        for x = 1, totalSize do
            local isWall = x == 1 or x == totalSize or y == 1 or y == totalSize
            gameMap.tiles[y][x] = isWall and T.WALL or T.CH6_SEAL_FLOOR
        end
    end

    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}
    GameState.bossKillTimes = {}

    local centerX = totalSize / 2 + 0.5
    local centerY = totalSize / 2 + 0.5
    player.x = centerX
    player.y = centerY + ArtifactCh6.PLAYER_SPAWN_Y_OFFSET
    if player.SetMoveDirection then player:SetMoveDirection(0, 0) end
    if player.GetTotalMaxHp then player.hp = player:GetTotalMaxHp() end
    player.alive = true

    if camera then
        camera.x = centerX
        camera.y = centerY
        camera.mapWidth = totalSize
        camera.mapHeight = totalSize
    end

    local demon, demonErr = SpawnArtifactBoss(
        ArtifactCh6.BOSS_MONSTER_IDS[1],
        centerX - ArtifactCh6.BOSS_SPAWN_X_OFFSET,
        centerY + ArtifactCh6.BOSS_SPAWN_Y_OFFSET)
    if not demon then
        ArtifactCh6._rollback(gameMap, camera)
        return false, demonErr
    end

    local immortal, immortalErr = SpawnArtifactBoss(
        ArtifactCh6.BOSS_MONSTER_IDS[2],
        centerX + ArtifactCh6.BOSS_SPAWN_X_OFFSET,
        centerY + ArtifactCh6.BOSS_SPAWN_Y_OFFSET)
    if not immortal then
        ArtifactCh6._rollback(gameMap, camera)
        return false, immortalErr
    end

    ArtifactCh6.arenaActive = true
    ArtifactCh6._gameMap = gameMap
    ArtifactCh6._camera = camera

    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.5,
        "— 魔化·呱大王 / 仙化·呱大王 —",
        {185, 235, 230, 255}, 3.0)
    print("[ArtifactCh6] Entered twin boss arena: "
        .. demon.name .. " + " .. immortal.name)
    return true, nil
end

local function RestoreVictoryProgress(progress, account)
    ArtifactCh6.ApplyAccountState(progress)
    local AtlasSystem = GetAtlasSystem()
    if AtlasSystem and AtlasSystem.data then
        AtlasSystem.data.artifact_jieshi = DeepCopy(account)
            or DeepCopy(progress)
    end
end

local function SaveBossVictory()
    local AtlasSystem = GetAtlasSystem()
    local progressBefore = ArtifactCh6.SerializeAccount()
    local accountBefore = AtlasSystem and AtlasSystem.data
        and DeepCopy(AtlasSystem.data.artifact_jieshi) or nil

    busy_ = true
    ArtifactCh6.bossDefeated = true
    ArtifactCh6.passiveUnlocked = true
    ArtifactCh6.rescueReadyAt = 0
    ArtifactCh6.RecalcAttributes()
    SyncAccountState()

    local SaveSystem = require("systems.SaveSystem")
    local callbackCalled = false
    local function finish(ok, reason)
        if callbackCalled then return end
        callbackCalled = true
        busy_ = false
        local player = GameState.player
        local CombatSystem = require("systems.CombatSystem")

        if ok then
            if player then
                player.hp = player.GetTotalMaxHp and player:GetTotalMaxHp()
                    or player.hp
                player.alive = true
                CombatSystem.AddFloatingText(
                    player.x or 0, (player.y or 0) - 1.0,
                    "两界替命·觉醒！",
                    {145, 235, 255, 255}, 3.0)
            end
            EventBus.Emit("artifact_ch6_boss_defeated")
            print("[ArtifactCh6] Twin bosses defeated and saved")
        else
            RestoreVictoryProgress(progressBefore, accountBefore)
            if player then
                player.alive = true
                CombatSystem.AddFloatingText(
                    player.x or 0, (player.y or 0) - 1.0,
                    "觉醒保存失败，请重新挑战",
                    {255, 105, 105, 255}, 3.0)
            end
            EventBus.Emit("artifact_ch6_boss_save_failed", reason)
            print("[ArtifactCh6] Boss victory save failed: " .. tostring(reason))
        end
    end

    local ok, err = pcall(function()
        SaveSystem.Save(finish)
    end)
    if not ok then finish(false, err) end
end

---@param gameMap table
---@param isVictory boolean
---@param camera table|nil
function ArtifactCh6.ExitBossArena(gameMap, isVictory, camera)
    if not ArtifactCh6.arenaActive then return end

    GameState.monsters = {}
    ArtifactCh6._rollback(gameMap, camera)

    local player = GameState.player
    local CombatSystem = require("systems.CombatSystem")
    if player then
        player.hp = player.GetTotalMaxHp and player:GetTotalMaxHp() or player.hp
        player.alive = true
    end

    if isVictory then
        SaveBossVictory()
    elseif player then
        CombatSystem.AddFloatingText(
            player.x or 0, (player.y or 0) - 1.0,
            "双王挑战失败",
            {220, 80, 100, 255}, 2.0)
        print("[ArtifactCh6] Twin boss fight lost")
    end
end

local function UpdateImmortalBlessing(dt)
    local immortal = nil
    local aliveBosses = {}
    for _, monster in ipairs(GameState.monsters) do
        if monster.isArtifactCh6Boss and monster.alive then
            aliveBosses[#aliveBosses + 1] = monster
            if monster.artifactCh6Aspect == "immortal" then immortal = monster end
        end
        if (monster.artifactCh6BlessingTimer or 0) > 0 then
            monster.artifactCh6BlessingTimer =
                math.max(0, monster.artifactCh6BlessingTimer - dt)
        end
    end
    if not immortal then return end

    immortal.artifactCh6HealTimer =
        (immortal.artifactCh6HealTimer or 0) - dt
    if immortal.artifactCh6HealTimer > 0 then return end

    local interval = tonumber(immortal.data.artifactCh6HealInterval) or 14
    local ratio = tonumber(immortal.data.artifactCh6HealRatio) or 0.04
    immortal.artifactCh6HealTimer = interval

    local healedAny = false
    local CombatSystem = require("systems.CombatSystem")
    for _, boss in ipairs(aliveBosses) do
        local missing = math.max(0, (boss.maxHp or 0) - (boss.hp or 0))
        if missing > 0 then
            local heal = math.max(1, math.floor((boss.maxHp or 1) * ratio))
            heal = math.min(heal, missing)
            boss.hp = boss.hp + heal
            boss.artifactCh6BlessingTimer = 1.2
            CombatSystem.AddFloatingText(
                boss.x, boss.y - 0.9,
                "+" .. tostring(heal) .. " 仙露",
                {155, 255, 215, 255}, 1.5)
            healedAny = true
        end
    end
    if healedAny then
        CombatSystem.AddFloatingText(
            immortal.x, immortal.y - 1.4,
            "双界仙露",
            {225, 245, 175, 255}, 1.8)
    end
end

---@param dt number
---@param gameMap table
---@param camera table|nil
function ArtifactCh6.UpdateBossArena(dt, gameMap, camera)
    if not ArtifactCh6.arenaActive then return end

    local player = GameState.player
    if not player then return end
    if not player.alive then
        ArtifactCh6.ExitBossArena(gameMap, false, camera)
        return
    end

    UpdateImmortalBlessing(dt or 0)

    local aliveCount = 0
    for _, monster in ipairs(GameState.monsters) do
        if monster.isArtifactCh6Boss and monster.alive then
            aliveCount = aliveCount + 1
        end
    end
    if aliveCount == 0 then
        ArtifactCh6.ExitBossArena(gameMap, true, camera)
    end
end

function ArtifactCh6.GetCooldownRemaining(now)
    now = NormalizeTimestamp(now or timeProvider_())
    return math.max(0, ArtifactCh6.rescueReadyAt - now)
end

function ArtifactCh6.IsRescueReady(now)
    return ArtifactCh6.GetCooldownRemaining(now) <= 0
end

function ArtifactCh6.GetPassiveDisplayDesc()
    local remaining = ArtifactCh6.GetCooldownRemaining()
    if ArtifactCh6.passiveUnlocked and remaining > 0 then
        return ArtifactCh6.PASSIVE.desc .. "（剩余" .. remaining .. "秒）"
    end
    return ArtifactCh6.PASSIVE.desc
end

---@param player table
---@param source table|nil
---@return boolean triggered
function ArtifactCh6.TryRescuePlayer(player, source)
    if not player or not player.alive or not ArtifactCh6.passiveUnlocked then
        return false
    end
    if source and source.bypassArtifactRescue == true then return false end

    local now = NormalizeTimestamp(timeProvider_())
    if not ArtifactCh6.IsRescueReady(now) then return false end

    local maxHp = player.GetTotalMaxHp and player:GetTotalMaxHp()
        or player.maxHp or 1
    local hpBefore = player.hp or 0
    player.hp = math.max(1, math.floor(maxHp * ArtifactCh6.PASSIVE.healRatio))
    local actualHeal = math.max(0, player.hp - hpBefore)
    player.invincibleTimer = math.max(
        player.invincibleTimer or 0,
        ArtifactCh6.PASSIVE.invincibleDuration)
    player.alive = true

    ArtifactCh6.rescueReadyAt = now + ArtifactCh6.PASSIVE.cooldown
    SyncAccountState()
    cooldownSavePending_ = true
    cooldownRetryTimer_ = 0

    local okCombat, CombatSystem = pcall(require, "systems.CombatSystem")
    if okCombat and CombatSystem then
        if CombatSystem.AddJieshiRescueEffect then
            CombatSystem.AddJieshiRescueEffect(
                player, ArtifactCh6.PASSIVE.invincibleDuration)
        end
        if CombatSystem.EmitCombatFeedback and actualHeal > 0 then
            CombatSystem.EmitCombatFeedback({
                kind = "heal", value = actualHeal,
                source = player, target = player, targetKey = "player:self",
                sourceType = "artifact", sourceId = "jieshi_rescue",
                sourceName = ArtifactCh6.PASSIVE.name,
                color = {145, 255, 205, 255},
                labelPolicy = "always",
            }, {
                {
                    x = player.x, y = player.y - 0.9,
                    text = ArtifactCh6.PASSIVE.name,
                    color = {175, 245, 255, 255}, lifetime = 1.8,
                },
                {
                    x = player.x, y = player.y - 0.4,
                    text = "+" .. actualHeal,
                    color = {145, 255, 205, 255}, lifetime = 1.5,
                },
            })
        end
    end

    EventBus.Emit("artifact_ch6_rescue_triggered", {
        hp = player.hp,
        maxHp = maxHp,
        readyAt = ArtifactCh6.rescueReadyAt,
    })
    TrySaveCooldown()
    print("[ArtifactCh6] 两界替命 triggered, hp=" .. player.hp
        .. " readyAt=" .. ArtifactCh6.rescueReadyAt)
    return true
end

function ArtifactCh6.Update(dt)
    if cooldownRetryTimer_ > 0 then
        cooldownRetryTimer_ = math.max(0, cooldownRetryTimer_ - (dt or 0))
    end
    if cooldownSavePending_ and cooldownRetryTimer_ <= 0 then
        TrySaveCooldown()
    end
end

function ArtifactCh6.HasPendingCooldownSave()
    return cooldownSavePending_ or cooldownSaveInFlight_
end

---@param mutate fun()
---@param successMessage string
---@param callback fun(success: boolean, message: string)|nil
---@return boolean started
---@return string message
local function CommitGMAccountMutation(mutate, successMessage, callback)
    if busy_ then return false, "界匙系统正在处理其他操作" end
    if cooldownSavePending_ or cooldownSaveInFlight_ then
        return false, "替命冷却正在保存，请稍后再试"
    end
    local saveBlock = GetSaveBlockReason()
    if saveBlock then return false, saveBlock end

    local snapshot = MakeSnapshot()
    busy_ = true

    local mutateOk, mutateErr = pcall(mutate)
    if not mutateOk then
        busy_ = false
        RestoreSnapshot(snapshot)
        local message = "GM修改界匙失败：" .. tostring(mutateErr)
        if callback then callback(false, message) end
        return false, message
    end
    if not SyncAccountState() then
        busy_ = false
        RestoreSnapshot(snapshot)
        local message = "账号神器档案同步失败"
        if callback then callback(false, message) end
        return false, message
    end

    local SaveSystem = require("systems.SaveSystem")
    local callbackCalled = false
    local function finish(ok, reason)
        if callbackCalled then return end
        callbackCalled = true
        busy_ = false
        if ok then
            EventBus.Emit("artifact_ch6_gm_account_changed")
            if callback then callback(true, successMessage) end
        else
            RestoreSnapshot(snapshot)
            local message = "保存失败，GM修改已回滚："
                .. tostring(reason or "unknown")
            if callback then callback(false, message) end
        end
    end

    local ok, err = pcall(function()
        SaveSystem.Save(finish)
    end)
    if not ok then finish(false, err) end
    return true, "界匙账号档保存中"
end

---@param callback fun(success: boolean, message: string)|nil
---@return boolean started
---@return string message
function ArtifactCh6.GMResetCooldown(callback)
    return CommitGMAccountMutation(function()
        local state = ArtifactCh6.SerializeAccount()
        state.rescueReadyAt = 0
        ArtifactCh6.ApplyAccountState(state)
    end, "两界替命冷却已清零并保存", callback)
end

---@param callback fun(success: boolean, message: string)|nil
---@return boolean started
---@return string message
function ArtifactCh6.GMResetAccount(callback)
    return CommitGMAccountMutation(function()
        ArtifactCh6.ApplyAccountState({
            version = 1,
            activatedGrids = NewGridState(),
            bossDefeated = false,
            passiveUnlocked = false,
            rescueReadyAt = 0,
        })
        cooldownSavePending_ = false
        cooldownSaveInFlight_ = false
        cooldownRetryTimer_ = 0
    end, "界匙账号进度已完整重置并保存", callback)
end

---@param player table|nil
---@return boolean success
---@return string message
function ArtifactCh6.GMTriggerRescueForTest(player)
    if busy_ then return false, "界匙系统正在处理其他操作" end
    if not player or not player.alive then return false, "玩家当前不可用" end
    if not ArtifactCh6.passiveUnlocked then
        return false, "尚未击败界匙双王，不能测试两界替命"
    end
    local saveBlock = GetSaveBlockReason()
    if saveBlock then return false, saveBlock end

    ArtifactCh6.rescueReadyAt = 0
    cooldownSavePending_ = false
    cooldownSaveInFlight_ = false
    cooldownRetryTimer_ = 0
    SyncAccountState()
    if not ArtifactCh6.TryRescuePlayer(player, { gmTest = true }) then
        return false, "两界替命触发失败"
    end
    return true, "已触发两界替命：恢复25%生命并进入3秒无敌"
end

function ArtifactCh6.Serialize()
    local progress = NormalizeProgress({
        activatedGrids = ArtifactCh6.activatedGrids,
        bossDefeated = ArtifactCh6.bossDefeated,
        passiveUnlocked = ArtifactCh6.passiveUnlocked,
    }, false)
    return progress
end

function ArtifactCh6.SerializeAccount()
    return NormalizeProgress({
        activatedGrids = ArtifactCh6.activatedGrids,
        bossDefeated = ArtifactCh6.bossDefeated,
        passiveUnlocked = ArtifactCh6.passiveUnlocked,
        rescueReadyAt = ArtifactCh6.rescueReadyAt,
    }, true)
end

function ArtifactCh6.Deserialize(data)
    local normalized = NormalizeProgress(data, false)
    ArtifactCh6.activatedGrids = normalized.activatedGrids
    ArtifactCh6.bossDefeated = normalized.bossDefeated
    ArtifactCh6.passiveUnlocked = normalized.passiveUnlocked
    ArtifactCh6.rescueReadyAt = 0
    busy_ = false
    cooldownSavePending_ = false
    cooldownSaveInFlight_ = false
    cooldownRetryTimer_ = 0
    ArtifactCh6.arenaActive = false
    ArtifactCh6._backup = nil
    ArtifactCh6._gameMap = nil
    ArtifactCh6._camera = nil
    ArtifactCh6.RecalcAttributes()
end

function ArtifactCh6.ApplyAccountState(data)
    local normalized = NormalizeProgress(data, true)
    ArtifactCh6.activatedGrids = normalized.activatedGrids
    ArtifactCh6.bossDefeated = normalized.bossDefeated
    ArtifactCh6.passiveUnlocked = normalized.passiveUnlocked
    ArtifactCh6.rescueReadyAt = normalized.rescueReadyAt
    ArtifactCh6.RecalcAttributes()
end

function ArtifactCh6.Reset()
    ArtifactCh6.activatedGrids = NewGridState()
    ArtifactCh6.bossDefeated = false
    ArtifactCh6.passiveUnlocked = false
    ArtifactCh6.rescueReadyAt = 0
    busy_ = false
    cooldownSavePending_ = false
    cooldownSaveInFlight_ = false
    cooldownRetryTimer_ = 0
    ArtifactCh6.arenaActive = false
    ArtifactCh6._backup = nil
    ArtifactCh6._gameMap = nil
    ArtifactCh6._camera = nil
    ArtifactCh6.RecalcAttributes()
end

function ArtifactCh6.SetTimeProviderForTest(provider)
    timeProvider_ = provider or os.time
end

function ArtifactCh6.FormatGold(gold)
    if gold >= 100000000 then
        local yi = gold / 100000000
        if yi == math.floor(yi) then return math.floor(yi) .. "亿" end
        return string.format("%.1f亿", yi)
    end
    if gold >= 10000 then
        local wan = gold / 10000
        if wan == math.floor(wan) then return math.floor(wan) .. "万" end
        return string.format("%.1f万", wan)
    end
    return tostring(gold)
end

return ArtifactCh6
