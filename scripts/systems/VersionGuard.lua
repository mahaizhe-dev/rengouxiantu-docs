-- ============================================================================
-- VersionGuard.lua - 版本守卫（轮询踢出 + 启动校验）
--
-- 机制：
--   1. 启动时将 CODE_VERSION 写入 clientScore（per-user 云变量）
--   2. 每 60 秒双通道检测：
--      a) 读取自己的云端 _code_ver（同账号多标签页/回退场景）
--      b) 从排行榜读取其他玩家的 _code_ver（全局版本广播）
--   3. 任一通道发现 cloudVer > 本地值 → 安全存档 → 提示更新
--
-- 覆盖场景：
--   ✅ 玩家在新版本存了档，又回到旧版本缓存会话（通道 a）
--   ✅ 玩家开了两个标签页，一个新版一个旧版（通道 a）
--   ✅ 新版本已发布，任意玩家打开过新版本（通道 b - 排行榜广播）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local CloudStorage = require("network.CloudStorage")

local VersionGuard = {}

local POLL_INTERVAL = 60  -- 轮询间隔（秒）
local CLOUD_KEY = "_code_ver"

local _timer = 0
local _active = false
local _kicked = false  -- 防止重复触发

--- 初始化：写入当前版本，开始轮询
function VersionGuard.Init()
    _active = true
    _kicked = false
    _timer = 0

    -- 启动时写入当前代码版本到云端
    CloudStorage.SetInt(CLOUD_KEY, GameConfig.CODE_VERSION, {
        ok = function()
            print("[VersionGuard] Registered CODE_VERSION=" .. GameConfig.CODE_VERSION)
        end,
        error = function(code, reason)
            print("[VersionGuard] Failed to register version: " .. tostring(reason))
        end,
    })
end

--- 检查版本号，超过本地则踢出
---@param cloudVer number
---@param source string
local function _CheckVersion(cloudVer, source)
    if cloudVer > GameConfig.CODE_VERSION then
        print("[VersionGuard] VERSION MISMATCH via " .. source .. ": cloud=" .. cloudVer
            .. " > local=" .. GameConfig.CODE_VERSION .. " → KICKING")
        VersionGuard._DoKick()
    end
end

--- 每帧调用（在 HandleUpdate 中）
---@param dt number
function VersionGuard.Update(dt)
    if not _active or _kicked then return end

    _timer = _timer + dt
    if _timer < POLL_INTERVAL then return end
    _timer = 0

    -- 通道 a: 读取自己的云端版本（同账号多标签页/回退场景）
    CloudStorage.Get(CLOUD_KEY, {
        ok = function(values, iscores)
            _CheckVersion(iscores[CLOUD_KEY] or 0, "self")
        end,
        error = function(code, reason)
            print("[VersionGuard] Self-poll failed: " .. tostring(reason))
        end,
    })

    -- 通道 b: 从排行榜读取其他玩家的版本号（全局广播）
    -- 查询 rank2_score_1 排行榜前 5 名，附加 _code_ver 字段
    CloudStorage.GetRankList("rank2_score_1", 0, 5, {
        ok = function(rankList)
            local maxVer = 0
            for i = 1, #rankList do
                local ver = rankList[i].iscore[CLOUD_KEY] or 0
                if ver > maxVer then maxVer = ver end
            end
            if maxVer > 0 then
                _CheckVersion(maxVer, "leaderboard")
            end
        end,
        error = function(code, reason)
            print("[VersionGuard] Leaderboard poll failed: " .. tostring(reason))
        end,
    }, CLOUD_KEY)
end

--- 执行踢出流程
function VersionGuard._DoKick()
    if _kicked then return end
    _kicked = true
    _active = false

    local SaveSystem = require("systems.SaveSystem")

    -- 仅在存档已正常加载时才保存（安全闸门会二次拦截）
    if SaveSystem.loaded and SaveSystem.activeSlot then
        print("[VersionGuard] Saving before kick...")
        SaveSystem.DoSave(SaveSystem.activeSlot, function(success)
            print("[VersionGuard] Pre-kick save: " .. (success and "OK" or "FAILED"))
            VersionGuard._ShowKickUI()
        end, SaveSystem._saveEpoch)
    else
        VersionGuard._ShowKickUI()
    end
end

--- 显示踢出提示 UI 并退出
function VersionGuard._ShowKickUI()
    -- 尝试使用 UI 系统显示提示
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
                            text = "检测到新版本",
                            fontSize = 20,
                            color = { 255, 220, 100, 255 },
                            marginBottom = 12,
                        },
                        UI.Label {
                            text = "游戏已更新，请重新进入",
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
        -- UI 初始化前就触发了，直接退出
        print("[VersionGuard] UI unavailable, exiting directly")
        engine:Exit()
    end
end

return VersionGuard
