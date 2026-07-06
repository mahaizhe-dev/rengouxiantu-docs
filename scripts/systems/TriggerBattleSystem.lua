-- ============================================================================
-- TriggerBattleSystem.lua - 触发式战斗客户端状态机
-- ============================================================================

---@type table<string, any>
local M = {}

local TriggeredBattleConfig = require("config.TriggeredBattleConfig")
local MonsterData = require("config.MonsterData")
local Monster = require("entities.Monster")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CombatSystem = require("systems.CombatSystem")
local InventorySystem = require("systems.InventorySystem")
---@type table<string, any>
local SaveProtocol = require("network.SaveProtocol")

---@diagnostic disable-next-line: undefined-global
---@type any
local cjson = cjson
if not cjson then
    local ok, lib = pcall(require, "cjson") ---@diagnostic disable-line: unresolved-require
    if ok then cjson = lib end
end

M.active = false
M.state = "idle"
M.eventId = nil
M.runId = nil
M.monsters = {}
M._gameMap = nil
M._networkRegistered = false
M._finishTimeout = 0

local function floatText(text, color, duration)
    local p = GameState.player
    if p then
        CombatSystem.AddFloatingText(p.x, p.y - 1.0, text, color or {255, 220, 100, 255}, duration or 2.0)
    end
end

local function readString(eventData, key, default)
    local ok, value = pcall(function()
        local v = eventData[key]
        return v and v:GetString() or nil
    end)
    if ok and value ~= nil then return value end
    return default or ""
end

local function readBool(eventData, key, default)
    local ok, value = pcall(function()
        local v = eventData[key]
        return v and v:GetBool() or nil
    end)
    if ok and value ~= nil then return value end
    return default or false
end

local function readInt(eventData, key, default)
    local ok, value = pcall(function()
        local v = eventData[key]
        return v and v:GetInt() or nil
    end)
    if ok and value ~= nil then return value end
    return default or 0
end

local function cloneMonsterData(src)
    local dst = {}
    for k, v in pairs(src or {}) do dst[k] = v end
    dst.dropTable = {}
    dst.expReward = 0
    dst.goldReward = {0, 0}
    dst.localRespawn = true
    return dst
end

local function isOtherActivityActive()
    local checks = {
        { "systems.ChallengeSystem", "IsActive" },
        { "systems.TrialTowerSystem", "IsActive" },
        { "systems.PrisonTowerSystem", "IsActive" },
        { "systems.TribulationScene", "IsActive" },
        { "systems.SwordWallSystem", "IsActive" },
        { "network.DungeonClient", "IsDungeonMode" },
    }
    for _, def in ipairs(checks) do
        local ok, mod = pcall(require, def[1])
        if ok and mod and mod[def[2]] and mod[def[2]]() then
            return true
        end
    end
    return false
end

function M.SetGameMap(gameMap)
    M._gameMap = gameMap
end

function M.IsActive()
    return M.active == true
end

function M.IsCompleted(eventId)
    GameState.triggeredBattles = GameState.triggeredBattles or {}
    return TriggeredBattleConfig.IsCompleted(GameState.triggeredBattles, eventId)
end

function M.Init()
    if M._unsubMonsterDeath then M._unsubMonsterDeath() end
    M._unsubMonsterDeath = EventBus.On("monster_death", function(monster)
        M.OnMonsterDeath(monster)
    end)
end

function M.RegisterNetworkEvents()
    if M._networkRegistered then return end
    _G.TriggerBattleSystem_HandleStartResult = function(eventType, eventData)
        M.HandleStartResult(eventData)
    end
    _G.TriggerBattleSystem_HandleFinishResult = function(eventType, eventData)
        M.HandleFinishResult(eventData)
    end
    SubscribeToEvent(SaveProtocol.S2C_TriggeredBattleStartResult, "TriggerBattleSystem_HandleStartResult")
    SubscribeToEvent(SaveProtocol.S2C_TriggeredBattleFinishResult, "TriggerBattleSystem_HandleFinishResult")
    M._networkRegistered = true
    print("[TriggerBattle] S2C events registered")
end

function M.RequestStart(eventId)
    local cfg = TriggeredBattleConfig.Get(eventId)
    if not cfg then
        floatText("事件配置不存在", {255, 100, 100, 255})
        return false
    end
    if M.active or M.state == "starting" then
        floatText("挑战进行中", {255, 200, 80, 255})
        return false
    end
    if M.IsCompleted(eventId) then
        floatText(cfg.completedHint or "已完成", {200, 200, 200, 255})
        return false
    end
    if isOtherActivityActive() then
        floatText("当前副本中无法挑战", {255, 120, 100, 255})
        return false
    end

    local conn = network and network:GetServerConnection()
    if not conn then
        floatText("网络未连接，无法结算奖励", {255, 100, 100, 255}, 2.5)
        return false
    end

    M.state = "starting"
    M.eventId = eventId
    M.runId = nil
    M.monsters = {}

    local msg = VariantMap()
    msg["eventId"] = Variant(eventId)
    conn:SendRemoteEvent(SaveProtocol.C2S_TriggeredBattleStart, true, msg)
    floatText("残阵回应中……", {180, 180, 255, 255}, 1.5)
    return true
end

function M.HandleStartResult(eventData)
    local eventId = readString(eventData, "eventId", M.eventId or "")
    if eventId ~= (M.eventId or eventId) then return end

    local ok = readBool(eventData, "ok", false)
    local message = readString(eventData, "message", "")
    if readBool(eventData, "alreadyCompleted", false) then
        GameState.triggeredBattles = GameState.triggeredBattles or {}
        GameState.triggeredBattles[eventId] = GameState.triggeredBattles[eventId] or { completed = true, rewarded = true }
        M.state = "idle"
        M.eventId = nil
        floatText(message ~= "" and message or "已完成", {200, 200, 200, 255})
        return
    end
    if not ok then
        M.state = "idle"
        M.eventId = nil
        floatText(message ~= "" and message or "挑战无法开始", {255, 100, 100, 255}, 2.5)
        return
    end

    local runId = readString(eventData, "runId", "")
    M.BeginFight(eventId, runId)
end

function M.BeginFight(eventId, runId)
    local cfg = TriggeredBattleConfig.Get(eventId)
    if not cfg then return end
    local player = GameState.player
    if not player then return end

    M.active = true
    M.state = "fighting"
    M.eventId = eventId
    M.runId = runId
    M.monsters = {}
    M._finishTimeout = 0

    local pos = cfg.playerStart
    if pos then
        player.x = pos.x
        player.y = pos.y
        if player.SetMoveDirection then player:SetMoveDirection(0, 0) end
    end

    for _, spawn in ipairs(cfg.monsterSpawns or {}) do
        local src = MonsterData.Types[spawn.type]
        if src then
            local data = cloneMonsterData(src)
            local monster = Monster.New(data, spawn.x, spawn.y)
            monster.typeId = spawn.type
            monster.isTriggeredBattle = true
            monster.triggerBattleEventId = eventId
            monster.triggerBattleRunId = runId
            monster.localRespawn = true
            GameState.AddMonster(monster)
            M.monsters[#M.monsters + 1] = monster
        else
            print("[TriggerBattle] missing monster type: " .. tostring(spawn.type))
        end
    end

    floatText(cfg.title .. "开启", {220, 120, 255, 255}, 3.0)
    print("[TriggerBattle] begin event=" .. eventId .. " runId=" .. tostring(runId))
end

function M.OnMonsterDeath(monster)
    if not M.active or M.state ~= "fighting" then return end
    if not monster.isTriggeredBattle then return end
    if monster.triggerBattleEventId ~= M.eventId or monster.triggerBattleRunId ~= M.runId then return end

    for i = #M.monsters, 1, -1 do
        if M.monsters[i] == monster then
            table.remove(M.monsters, i)
            break
        end
    end
    if #M.monsters == 0 then
        M.RequestFinish()
    end
end

function M.RequestFinish()
    if not M.active or M.state ~= "fighting" then return end
    local conn = network and network:GetServerConnection()
    if not conn then
        M.Fail("网络断开，奖励未结算，可重新挑战")
        return
    end

    M.state = "settling"
    M._finishTimeout = 12.0
    local msg = VariantMap()
    msg["eventId"] = Variant(M.eventId or "")
    msg["runId"] = Variant(M.runId or "")
    msg["result"] = Variant("victory")
    conn:SendRemoteEvent(SaveProtocol.C2S_TriggeredBattleFinish, true, msg)
    floatText("残阵消散，正在结算……", {220, 200, 255, 255}, 2.0)
end

function M.ApplyRewardPatch(rewardPatchJson)
    if not rewardPatchJson or rewardPatchJson == "" then return true end
    local ok, patch = pcall(cjson.decode, rewardPatchJson)
    if not ok or type(patch) ~= "table" then
        print("[TriggerBattle] reward patch decode failed: " .. tostring(rewardPatchJson))
        return false
    end

    local mgr = InventorySystem.GetManager()
    if not mgr then return false end
    for _, change in ipairs(patch) do
        local slot = tonumber(change.slot)
        if slot and change.item then
            mgr:SetInventoryItem(slot, change.item)
            EventBus.Emit("inventory_item_added", change.item, slot)
        end
    end
    return true
end

function M.HandleFinishResult(eventData)
    local eventId = readString(eventData, "eventId", M.eventId or "")
    local runId = readString(eventData, "runId", M.runId or "")
    if eventId ~= (M.eventId or eventId) then return end
    if runId ~= "" and M.runId and runId ~= M.runId then return end

    local ok = readBool(eventData, "ok", false)
    local message = readString(eventData, "message", "")
    if not ok then
        M.Fail(message ~= "" and message or "奖励结算失败，可重新挑战")
        return
    end

    local rewardPatch = readString(eventData, "rewardPatch", "")
    local patchOk = M.ApplyRewardPatch(rewardPatch)
    if not patchOk then
        M.Fail("本地背包同步失败，重新登录后再确认奖励")
        return
    end
    local rewardId = readString(eventData, "rewardId", "")
    local rewardCount = readInt(eventData, "rewardCount", 1)
    local cfg = TriggeredBattleConfig.Get(eventId)

    GameState.triggeredBattles = GameState.triggeredBattles or {}
    local stateJson = readString(eventData, "stateJson", "")
    if stateJson ~= "" then
        local decOk, state = pcall(cjson.decode, stateJson)
        if decOk and type(state) == "table" then
            GameState.triggeredBattles[eventId] = state
        end
    end
    GameState.triggeredBattles[eventId] = GameState.triggeredBattles[eventId]
        or TriggeredBattleConfig.CloneCompletion(eventId, runId)

    M.Cleanup()
    M.state = "completed"
    if rewardId ~= "" then
        EventBus.Emit("quest_granted_reward_popup", {
            itemId = rewardId,
            count = rewardCount > 0 and rewardCount or 1,
            title = cfg and cfg.title or "挑战完成",
            subtitle = "获得奖励",
        })
    end
    floatText(message ~= "" and message or "获得界匙碎片·壹", {255, 220, 120, 255}, 3.0)
    EventBus.Emit("save_request")
end

function M.Fail(reason)
    print("[TriggerBattle] failed: " .. tostring(reason))
    M.Cleanup()
    M.state = "idle"
    floatText(reason or "挑战失败", {255, 100, 100, 255}, 3.0)
end

function M.Cleanup()
    for _, monster in ipairs(M.monsters or {}) do
        GameState.RemoveMonster(monster)
    end
    M.monsters = {}
    M.active = false
    M.eventId = nil
    M.runId = nil
    M._finishTimeout = 0
end

function M.Update(dt, gameMap)
    if gameMap then M._gameMap = gameMap end
    if not M.active then return end
    local player = GameState.player
    if not player or not player.alive then
        M.Fail("挑战失败，可重新挑战")
        return
    end

    local cfg = TriggeredBattleConfig.Get(M.eventId or "")
    local b = cfg and cfg.arenaBounds
    if b and M.state == "fighting" then
        if player.x < b.x1 - 0.5 or player.x > b.x2 + 0.5
            or player.y < b.y1 - 0.5 or player.y > b.y2 + 0.5 then
            M.Fail("离开残阵，挑战失败")
            return
        end
    end

    if M.state == "settling" then
        M._finishTimeout = (M._finishTimeout or 0) - dt
        if M._finishTimeout <= 0 then
            M.Fail("结算超时，可重新挑战")
        end
    end
end

return M
