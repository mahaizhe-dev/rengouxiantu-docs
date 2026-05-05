-- ============================================================================
-- 测试脚本：验证 serverCloud 能否读取 clientCloud 写入的数据
-- 服务端入口
-- ============================================================================

require "LuaScripts/Utilities/Sample"

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

-- Mock graphics for headless server
if GetGraphics() == nil then
    local mockGraphics = {
        SetWindowIcon = function() end,
        SetWindowTitleAndIcon = function() end,
        GetWidth = function() return 1920 end,
        GetHeight = function() return 1080 end,
    }
    function GetGraphics() return mockGraphics end
    graphics = mockGraphics
    console = { background = {} }
    function GetConsole() return console end
    debugHud = {}
    function GetDebugHud() return debugHud end
end

local scene_ = nil

function Start()
    SampleStart()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 注册远程事件
    network:RegisterRemoteEvent("C2S_TestReady")

    -- 监听客户端身份认证
    SubscribeToEvent("ClientIdentity", "HandleClientIdentity")
    SubscribeToEvent("C2S_TestReady", "HandleTestReady")

    print("[TestServer] ====== 服务端启动 ======")
    print("[TestServer] serverCloud=" .. tostring(serverCloud))
    print("[TestServer] 等待客户端连接...")
end

function HandleClientIdentity(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local uid = connection.identity["user_id"]:GetInt64()
    print("[TestServer] 客户端已认证, uid=" .. tostring(uid))

    -- 立即尝试用 serverCloud 读取 clientCloud 写入的 key
    print("[TestServer] 尝试读取 clientCloud 写入的 slots_index...")

    serverCloud:Get(uid, "slots_index", {
        ok = function(scores, iscores)
            if scores.slots_index then
                local json = cjson.encode(scores.slots_index)
                print("[TestServer] READ_SLOTS_OK: " .. json)
            else
                print("[TestServer] READ_SLOTS_EMPTY: scores.slots_index 为 nil")
                -- 打印所有返回的 scores keys
                local keys = {}
                for k, v in pairs(scores) do
                    table.insert(keys, k .. "=" .. type(v))
                end
                print("[TestServer] scores keys: " .. (next(keys) and table.concat(keys, ", ") or "(empty)"))
            end
        end,
        error = function(code, reason)
            print("[TestServer] READ_SLOTS_FAIL: " .. tostring(code) .. " - " .. tostring(reason))
        end,
    })

    -- 读取 save_data_1
    print("[TestServer] 尝试读取 clientCloud 写入的 save_data_1...")

    serverCloud:Get(uid, "save_data_1", {
        ok = function(scores, iscores)
            if scores.save_data_1 then
                local data = scores.save_data_1
                local playerLevel = "?"
                local version = "?"
                if type(data) == "table" then
                    if data.player then playerLevel = tostring(data.player.level or "?") end
                    version = tostring(data.version or "?")
                end
                print("[TestServer] READ_SAVE_OK: version=" .. version .. " playerLevel=" .. playerLevel)
                -- 打印数据大小
                local json = cjson.encode(data)
                print("[TestServer] READ_SAVE_SIZE: " .. #json .. " bytes")
            else
                print("[TestServer] READ_SAVE_EMPTY: scores.save_data_1 为 nil")
            end
        end,
        error = function(code, reason)
            print("[TestServer] READ_SAVE_FAIL: " .. tostring(code) .. " - " .. tostring(reason))
        end,
    })

    -- 读取 rank_score_1 (iscore)
    print("[TestServer] 尝试读取 clientCloud 写入的 rank_score_1 (iscore)...")

    serverCloud:Get(uid, "rank_score_1", {
        ok = function(scores, iscores)
            if iscores.rank_score_1 then
                print("[TestServer] READ_RANK_OK: rank_score_1=" .. tostring(iscores.rank_score_1))
            else
                print("[TestServer] READ_RANK_EMPTY: iscores.rank_score_1 为 nil")
            end
        end,
        error = function(code, reason)
            print("[TestServer] READ_RANK_FAIL: " .. tostring(code) .. " - " .. tostring(reason))
        end,
    })
end

function HandleTestReady(eventType, eventData)
    print("[TestServer] 收到客户端 TestReady 信号")
end

function Stop()
    print("[TestServer] 服务端关闭")
end
