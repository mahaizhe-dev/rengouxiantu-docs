-- ============================================================================
-- WubaoTreasureSystem.lua - 乌家宝藏客户端系统
-- ============================================================================

local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local SaveProtocol = require("network.SaveProtocol")
local Config = require("config.WubaoTreasureConfig")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local M = {}

M.state = { rewardOrder = {}, opened = {} }
M._channeling = false
M._channelTimer = 0
M._channelChestId = nil
M._pendingStartChestId = nil
M._autoCompleteAfterStart = false
M._renderDirty = true
M._initialized = false

local function normalizeState(data)
    local state = type(data) == "table" and data or {}
    local rewardOrder = type(state.rewardOrder) == "table" and state.rewardOrder or {}
    local openedSrc = type(state.opened) == "table" and state.opened or {}
    local opened = {}
    for chestId, value in pairs(openedSrc) do
        if value then opened[chestId] = true end
    end
    return {
        rewardOrder = rewardOrder,
        opened = opened,
    }
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

local function showMessage(message, color)
    if not message or message == "" then return end
    print("[WubaoTreasure] " .. message)
    local player = GameState.player
    if player then
        local ok, CombatSystem = pcall(require, "systems.CombatSystem")
        if ok and CombatSystem and CombatSystem.AddFloatingText then
            CombatSystem.AddFloatingText(
                player.x,
                player.y - 1.4,
                message,
                color or {255, 220, 120, 255},
                2.0
            )
        end
    end
end

local function decodeJson(jsonText, fallback)
    if not jsonText or jsonText == "" or not cjson then return fallback end
    local ok, data = pcall(cjson.decode, jsonText)
    if ok and type(data) == "table" then return data end
    return fallback
end

local function applyBackpackPatch(patchJson)
    local patch = decodeJson(patchJson, {})
    local okInv, InventorySystem = pcall(require, "systems.InventorySystem")
    if not okInv or not InventorySystem then return false end
    local manager = InventorySystem.GetManager()
    if not manager then return false end
    for _, change in ipairs(patch) do
        local slot = tonumber(change.slot)
        if slot then
            if change.clear then
                manager:SetInventoryItem(slot, nil)
            elseif change.item then
                manager:SetInventoryItem(slot, change.item)
            end
        end
    end
    return true
end

local function sendComplete(chestId)
    local conn = network and network:GetServerConnection()
    if not conn then
        showMessage("网络断开，开箱未结算，可重新开启", {255, 130, 110, 255})
        EventBus.Emit("WubaoTreasure_OpenFailed", {
            chestId = chestId or "",
            reason = "网络断开，开箱未结算，可重新开启",
        })
        return false
    end
    local data = VariantMap()
    data["chestId"] = Variant(chestId)
    conn:SendRemoteEvent(SaveProtocol.C2S_WubaoTreasure_CompleteOpen, true, data)
    return true
end

function M.Init()
    if M._initialized then return end
    M._initialized = true
    SubscribeToEvent(SaveProtocol.S2C_WubaoTreasure_StartResult, "WubaoTreasure_HandleStartResult")
    SubscribeToEvent(SaveProtocol.S2C_WubaoTreasure_OpenResult, "WubaoTreasure_HandleOpenResult")
    print("[WubaoTreasure] Initialized")
end

function M.ApplyBackpackPatch(patchJson)
    return applyBackpackPatch(patchJson)
end

---@param chestId string
---@return boolean
function M.IsOpened(chestId)
    return M.state.opened[chestId] == true
end

---@param chestId string
---@return table|nil
function M.GetChestConfig(chestId)
    return Config.CHESTS[chestId]
end

---@param px number
---@param py number
---@param chapter number|nil
---@return string|nil, table|nil
function M.FindNearby(px, py, chapter)
    local range = Config.INTERACT_RANGE
    local rangeSq = range * range
    for _, chestId in ipairs(Config.CHEST_ORDER) do
        local cfg = Config.CHESTS[chestId]
        if cfg and (not chapter or cfg.chapter == chapter) and not M.state.opened[chestId] then
            local dx = px - cfg.x
            local dy = py - cfg.y
            if dx * dx + dy * dy <= rangeSq then
                return chestId, cfg
            end
        end
    end
    return nil, nil
end

---@param chapter number
---@return table[]
function M.GetChestsForChapter(chapter)
    local result = {}
    for _, chestId in ipairs(Config.CHEST_ORDER) do
        local cfg = Config.CHESTS[chestId]
        if cfg and cfg.chapter == chapter then
            result[#result + 1] = {
                chestId = chestId,
                cfg = cfg,
                opened = M.state.opened[chestId] == true,
            }
        end
    end
    return result
end

function M.InvalidateRenderCache()
    M._renderDirty = true
end

function M.ClearRenderDirty()
    M._renderDirty = false
end

function M.IsRenderDirty()
    return M._renderDirty
end

---@param chestId string
---@return boolean
function M.TryStartOpen(chestId)
    if M._channeling then
        M.CancelChannel()
        return false
    end
    if not Config.CHESTS[chestId] or M.state.opened[chestId] then return false end

    local conn = network and network:GetServerConnection()
    if not conn then
        showMessage("网络断开，无法开启宝箱", {255, 120, 120, 255})
        return false
    end

    M._pendingStartChestId = chestId
    M._autoCompleteAfterStart = false
    local data = VariantMap()
    data["chestId"] = Variant(chestId)
    conn:SendRemoteEvent(SaveProtocol.C2S_WubaoTreasure_StartOpen, true, data)
    return true
end

---@param chestId string
---@return boolean
function M.RequestOpen(chestId)
    if M._channeling then return false end
    if M._pendingStartChestId then return false end
    if not Config.CHESTS[chestId] or M.state.opened[chestId] then return false end

    local conn = network and network:GetServerConnection()
    if not conn then
        local reason = "网络断开，无法开启宝箱"
        showMessage(reason, {255, 120, 120, 255})
        EventBus.Emit("WubaoTreasure_OpenFailed", { chestId = chestId, reason = reason })
        return false
    end

    M._pendingStartChestId = chestId
    M._autoCompleteAfterStart = true
    local data = VariantMap()
    data["chestId"] = Variant(chestId)
    conn:SendRemoteEvent(SaveProtocol.C2S_WubaoTreasure_StartOpen, true, data)
    return true
end

function M.CancelChannel()
    if not M._channeling then return end
    local chestId = M._channelChestId or ""
    M._channeling = false
    M._channelTimer = 0
    M._channelChestId = nil

    if chestId ~= "" then
        local conn = network and network:GetServerConnection()
        if conn then
            local data = VariantMap()
            data["chestId"] = Variant(chestId)
            conn:SendRemoteEvent(SaveProtocol.C2S_WubaoTreasure_CancelOpen, true, data)
        end
    end
end

---@return number|nil, string|nil
function M.GetChannelProgress()
    if not M._channeling then return nil, nil end
    return math.min(M._channelTimer / Config.CHANNEL_DURATION, 1.0), M._channelChestId
end

function M.IsChanneling()
    return M._channeling
end

function M._HandleStartResult(eventData)
    local ok = readBool(eventData, "ok", false)
    local chestId = readString(eventData, "chestId", M._pendingStartChestId or "")
    if ok then
        local stateJson = readString(eventData, "stateJson", "")
        if stateJson ~= "" then
            M.Deserialize(decodeJson(stateJson, M.state))
        end
        if M._autoCompleteAfterStart then
            M._pendingStartChestId = nil
            M._autoCompleteAfterStart = false
            sendComplete(chestId)
        else
            M._channelChestId = chestId
            M._pendingStartChestId = nil
            M._channeling = true
            M._channelTimer = 0
        end
    else
        local reason = readString(eventData, "message", "")
        if reason == "" then reason = readString(eventData, "reason", "无法开启宝箱") end
        M._pendingStartChestId = nil
        M._autoCompleteAfterStart = false
        showMessage(reason, {255, 130, 110, 255})
        EventBus.Emit("WubaoTreasure_OpenFailed", { chestId = chestId, reason = reason })
    end
end

function M._HandleOpenResult(eventData)
    local chestId = readString(eventData, "chestId", "")
    local ok = readBool(eventData, "ok", false)
    if not ok then
        local reason = readString(eventData, "message", "")
        if reason == "" then reason = readString(eventData, "reason", "开箱失败，请重试") end
        showMessage(reason, {255, 130, 110, 255})
        EventBus.Emit("WubaoTreasure_OpenFailed", { chestId = chestId, reason = reason })
        return
    end

    local stateJson = readString(eventData, "stateJson", "")
    if stateJson ~= "" then
        M.Deserialize(decodeJson(stateJson, M.state))
    end

    local patchJson = readString(eventData, "backpackPatch", "")
    if patchJson ~= "" and not applyBackpackPatch(patchJson) then
        showMessage("本地背包同步失败，重新登录后会以服务器存档为准", {255, 160, 90, 255})
    end

    local rewardItems = decodeJson(readString(eventData, "rewardJson", ""), {})
    if #rewardItems > 0 then
        EventBus.Emit("quest_granted_bundle_reward_popup", {
            title = "乌家宝藏",
            subtitle = "宝箱奖励",
            items = rewardItems,
        })
    end

    local message = readString(eventData, "message", "宝箱已开启")
    showMessage(message, {255, 230, 120, 255})
    EventBus.Emit("WubaoTreasure_OpenSuccess", { chestId = chestId, message = message, rewardItems = rewardItems })
end

---@param dt number
function M.Update(dt)
    if not M._channeling then return end
    local player = GameState.player
    local chestId = M._channelChestId
    if not player or not player.alive then
        M.CancelChannel()
        return
    end
    local cfg = chestId and Config.CHESTS[chestId]
    if cfg then
        local dx = player.x - cfg.x
        local dy = player.y - cfg.y
        if math.sqrt(dx * dx + dy * dy) > Config.INTERACT_RANGE then
            M.CancelChannel()
            return
        end
    end

    M._channelTimer = M._channelTimer + dt
    if M._channelTimer < Config.CHANNEL_DURATION then return end

    M._channeling = false
    M._channelTimer = 0
    M._channelChestId = nil
    if chestId then
        sendComplete(chestId)
    end
end

---@return table
function M.Serialize()
    return M.state or { rewardOrder = {}, opened = {} }
end

---@param data table|nil
function M.Deserialize(data)
    M.state = normalizeState(data)
    M.InvalidateRenderCache()
end

function M.Reset()
    M.state = { rewardOrder = {}, opened = {} }
    M._pendingStartChestId = nil
    M._autoCompleteAfterStart = false
    M.CancelChannel()
    M.InvalidateRenderCache()
end

function WubaoTreasure_HandleStartResult(eventType, eventData)
    M._HandleStartResult(eventData)
end

function WubaoTreasure_HandleOpenResult(eventType, eventData)
    M._HandleOpenResult(eventData)
end

return M
