-- ============================================================================
-- client_main.lua - 人狗仙途 客户端入口（网络模式）
--
-- 职责：
--   1. 网络初始化：Scene 关联、事件注册、版本握手
--   2. 设置 CloudStorage 为网络模式
--   3. 启动游戏主逻辑
--
-- 兼容两种模式：
--   - match_info（无 background_match）：大厅匹配后 Start() 被调用，
--     serverConn 可能已就绪，也可能需等 ServerReady
--   - background_match：Start() 立即调用，serverConn 稍后通过 ServerReady 就绪
-- ============================================================================

local FeatureFlags = require("config.FeatureFlags")
local SaveProtocol = require("network.SaveProtocol")
local CloudStorage = require("network.CloudStorage")
local GameConfig = require("config.GameConfig")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

-- ============================================================================
-- 状态
-- ============================================================================

---@type Scene
local netScene_ = nil
local networkReady_ = false
local networkInitDone_ = false  -- 防止重复初始化

-- 连接超时回退
local CONNECT_TIMEOUT = 120.0  -- 秒：匹配系统首次连接约需60秒，留足余量
local connectTimer_ = 0
local connectTimeoutDone_ = false
local connectingLabel_ = nil   -- P1-UI-7: 连接状态 UI 提示

-- ============================================================================
-- 入口
-- ============================================================================

function Start()
    print("[ClientMain] === 网络模式客户端启动 ===")
    print("[ClientMain] clientCloud=" .. tostring(clientCloud) .. " clientScore=" .. tostring(clientScore))

    -- 1. 提前设置网络模式（FetchSlots 走 SaveSystemNet 路径，无连接时自动排队）
    CloudStorage.SetNetworkMode(true)

    -- 2. 订阅 ServerReady（兜底：如果 Start 时连接还没好）
    SubscribeToEvent("ServerReady", "HandleServerReady")

    -- 3. 尝试立即初始化网络（match_info 模式下，大厅匹配后 Start 被调用时连接可能已就绪）
    local serverConn = network:GetServerConnection()
    if serverConn then
        print("[ClientMain] Server connection available at Start(), initializing immediately")
        InitializeNetwork(serverConn)
    else
        print("[ClientMain] No server connection at Start(), waiting for ServerReady...")
    end

    -- 4. 启动连接超时监控（用 PostUpdate 避免被 main.lua 的 Update 订阅覆盖）
    SubscribeToEvent("PostUpdate", "HandleClientMainUpdate")

    -- 5. 启动游戏 UI（不依赖服务器连接）
    DoGameStart()

end

-- ============================================================================
-- ServerReady — 匹配完成后触发（兜底路径）
-- ============================================================================

function HandleServerReady(eventType, eventData)
    print("[ClientMain] === ServerReady received! ===")

    if networkInitDone_ then
        print("[ClientMain] Network already initialized, skipping")
        return
    end

    if connectTimeoutDone_ then
        -- 超时后 ServerReady 到来：允许初始化（multiplayer 构建下这是唯一的连接路径）
        print("[ClientMain] ServerReady after timeout — late but accepting!")
    end

    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[ClientMain] ERROR: ServerReady fired but no server connection!")
        return
    end

    InitializeNetwork(serverConn)
end

-- ============================================================================
-- 连接超时监控 — 8秒无服务器连接则回退到单机模式
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleClientMainUpdate(eventType, eventData)
    if networkInitDone_ or connectTimeoutDone_ then return end

    local dt = eventData["TimeStep"]:GetFloat()
    connectTimer_ = connectTimer_ + dt

    -- P1-UI-7: 5 秒后显示"正在连接服务器..."提示，给用户可见反馈
    if connectTimer_ >= 5.0 and not connectingLabel_ then
        local ok, _ = pcall(function()
            local UI = require("urhox-libs/UI")
            connectingLabel_ = UI.Label {
                text = "正在连接服务器...",
                fontSize = 16,
                fontColor = {255, 255, 255, 200},
                textAlign = "center",
                position = "absolute",
                bottom = 40,
                left = 0,
                width = "100%",
            }
            UI.GetRoot():AddChild(connectingLabel_)
        end)
    end

    if connectTimer_ >= CONNECT_TIMEOUT then
        connectTimeoutDone_ = true
        -- 更新提示文案
        if connectingLabel_ then
            connectingLabel_:SetText("连接超时，等待重试...")
            connectingLabel_:SetStyle({ fontColor = {255, 180, 80, 255} })
        end
        FallbackToStandalone()
    end
end

--- 连接超时处理：通知排队的回调失败，但保持 NETWORK 模式
--- 在 multiplayer 构建下 standalone 路径不可用（clientCloud/clientScore 为 nil），
--- 因此不切换到 standalone，让用户重试时重新尝试连接服务器
function FallbackToStandalone()
    print("[ClientMain] === No server connection after " .. CONNECT_TIMEOUT .. "s ===")
    print("[ClientMain] Connection timeout, notifying pending callbacks...")

    -- 不切换 CloudStorage 模式！保持 NETWORK 模式
    -- 因为 multiplayer 构建下 standalone 路径无法工作（clientCloud=nil）
    -- CloudStorage.SetNetworkMode(false)  -- 已移除

    -- 通知 SaveSystemNet 中排队的回调失败（带错误信息）
    local SaveSystemNet = require("network.SaveSystemNet")
    SaveSystemNet.ClearQueue()

    -- 不标记 networkReady_（允许后续 ServerReady 仍然生效）
    -- networkReady_ = true  -- 已移除

    print("[ClientMain] Timeout handled. Retry will re-attempt server connection.")
end

-- ============================================================================
-- 网络初始化（只执行一次）
-- ============================================================================

function InitializeNetwork(serverConn)
    if networkInitDone_ then return end
    networkInitDone_ = true

    -- P1-UI-7: 连接成功，移除"正在连接"提示
    if connectingLabel_ then
        connectingLabel_:Remove()
        connectingLabel_ = nil
    end

    print("[ClientMain] Initializing network...")

    -- 1. 创建最小 Scene（网络连接关联用）
    netScene_ = Scene()
    netScene_:CreateComponent("Octree", LOCAL)

    -- 2. Scene 关联
    serverConn.scene = netScene_

    -- 3. 注册所有远程事件
    SaveProtocol.RegisterAll()

    -- 4. 订阅服务端响应事件
    SubscribeToEvent(SaveProtocol.S2C_ForceUpdate, "HandleForceUpdate")
    SubscribeToEvent(SaveProtocol.S2C_Maintenance, "HandleMaintenance")
    SubscribeToEvent(SaveProtocol.S2C_RateLimited, "HandleRateLimited")

    -- 5b. 副本系统初始化（自包含模块，内部订阅所有副本事件）
    -- pcall 防护：即使副本模块初始化失败，也不能阻断后续 SaveSystemNet.OnNetworkReady()
    local dcOk, dcErr = pcall(function()
        local DungeonClient = require("network.DungeonClient")
        DungeonClient.Init()
    end)
    if not dcOk then
        print("[ClientMain] WARNING: DungeonClient.Init() failed: " .. tostring(dcErr))
    end

    -- 5. 版本握手
    local handshakeData = VariantMap()
    handshakeData["CodeVersion"] = Variant(GameConfig.CODE_VERSION)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_VersionHandshake, true, handshakeData)
    print("[ClientMain] VersionHandshake sent: CODE_VERSION=" .. GameConfig.CODE_VERSION)

    networkReady_ = true
    print("[ClientMain] Network initialization complete")

    -- 6. 通知 SaveSystemNet 网络已就绪（执行排队的 FetchSlots）
    local SaveSystemNet = require("network.SaveSystemNet")
    SaveSystemNet.OnNetworkReady()
end

-- ============================================================================
-- 游戏主逻辑启动
-- ============================================================================

function DoGameStart()
    require("main")

    if GameStart then
        GameStart()
    else
        print("[ClientMain] WARNING: GameStart not found, main.lua may need update")
    end
end

-- ============================================================================
-- 公共接口
-- ============================================================================

---@return boolean
function IsNetworkReady()
    return networkReady_
end

-- ============================================================================
-- 强制更新处理
-- ============================================================================

function HandleForceUpdate(eventType, eventData)
    local requiredVersion = eventData["requiredVersion"]:GetInt()
    print("[ClientMain] ForceUpdate received: required=" .. requiredVersion
        .. " current=" .. GameConfig.CODE_VERSION)

    local VersionGuard = require("systems.VersionGuard")
    VersionGuard._DoKick()
end

-- ============================================================================
-- 维护通知处理
-- ============================================================================

-- ============================================================================
-- 维护通知处理
-- ============================================================================

function HandleMaintenance(eventType, eventData)
    local message = eventData["message"]:GetString()
    print("[ClientMain] Maintenance notice: " .. tostring(message))

    local ok, _ = pcall(function()
        local UI = require("urhox-libs/UI")
        local overlay = UI.Panel {
            width = "100%", height = "100%",
            justifyContent = "center", alignItems = "center",
            backgroundColor = { 0, 0, 0, 200 },
            children = {
                UI.Panel {
                    width = 400, height = 200,
                    backgroundColor = { 40, 40, 40, 255 },
                    borderRadius = 12,
                    justifyContent = "center", alignItems = "center",
                    padding = 20,
                    children = {
                        UI.Label {
                            text = "维护公告",
                            fontSize = 20,
                            color = { 255, 220, 100, 255 },
                            marginBottom = 12,
                        },
                        UI.Label {
                            text = message or "服务器正在维护中",
                            fontSize = 16,
                            color = { 200, 200, 200, 255 },
                            marginBottom = 20,
                        },
                        UI.Button {
                            text = "退出游戏",
                            variant = "primary",
                            width = 160, height = 44,
                            onClick = function()
                                engine:Exit()
                            end,
                        },
                    },
                },
            },
        }
        UI.SetRoot(overlay)
    end)

    if not ok then
        engine:Exit()
    end
end

-- ============================================================================
-- 服务端限流反馈处理
-- ============================================================================

function HandleRateLimited(eventType, eventData)
    local originEvent = eventData["EventName"]:GetString()
    print("[ClientMain] RateLimited by server, origin=" .. tostring(originEvent))

    -- 如果正在存档中，解除 saving 锁并标记脏以便重试
    local ok2, _ = pcall(function()
        local SaveSystem = require("systems.SaveSystem")
        if SaveSystem.saving then
            SaveSystem.saving = false
            SaveSystem._dirty = true
            print("[ClientMain] Save was rate-limited, will retry on next debounce cycle")
        end
    end)

    -- 显示短暂提示（不阻断操作）
    local ok3, _ = pcall(function()
        local EventBus = require("core.EventBus")
        EventBus.Emit("toast", "操作过于频繁，请稍后再试")
    end)
end

