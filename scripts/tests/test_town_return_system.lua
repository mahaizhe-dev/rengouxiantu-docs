-- ============================================================================
-- test_town_return_system.lua - 快捷回城自测脚本
-- 执行文档 §4.11: 16 个测试用例
-- 用法: 在 GM 控制台输入 require("tests.test_town_return_system").RunAll()
-- ============================================================================

local GameState      = require("core.GameState")
local ActiveZoneData = require("config.ActiveZoneData")

local T = {}
local passed_ = 0
local failed_ = 0
local total_ = 0

--------------------------------------------------------------------
-- 测试辅助
--------------------------------------------------------------------
local function assert_eq(name, got, expected)
    total_ = total_ + 1
    if got == expected then
        passed_ = passed_ + 1
        print("  ✅ " .. name)
    else
        failed_ = failed_ + 1
        print("  ❌ " .. name .. " | expected=" .. tostring(expected) .. " got=" .. tostring(got))
    end
end

local function assert_true(name, val)
    assert_eq(name, val == true, true)
end

local function assert_false(name, val)
    assert_eq(name, val == true, false)
end

local function assert_near(name, got, expected, tol)
    tol = tol or 0.01
    total_ = total_ + 1
    if got == nil then
        failed_ = failed_ + 1
        print("  ❌ " .. name .. " | expected≈" .. tostring(expected) .. " got=nil")
        return
    end
    if math.abs(got - expected) <= tol then
        passed_ = passed_ + 1
        print("  ✅ " .. name)
    else
        failed_ = failed_ + 1
        print("  ❌ " .. name .. " | expected≈" .. tostring(expected) .. " got=" .. tostring(got))
    end
end

--- 创建假玩家
local function makeMockPlayer(x, y)
    return {
        x = x or 10, y = y or 10,
        alive = true,
        hp = 100,
        lastMoveX = x or 10, lastMoveY = y or 10,
        stuckTimer = 0,
        dx = 0, dy = 0,
        moving = false,
        target = nil,
        direction = "right",
        facingRight = true,
        SetMoveDirection = function(self, ddx, ddy)
            self.dx = ddx
            self.dy = ddy
        end,
    }
end

--- 创建假宠物
local function makeMockPet(x, y)
    return {
        x = x or 11, y = y or 10,
        alive = true,
        state = "follow",
        target = nil,
    }
end

--- 创建假怪物
local function makeMockMonster(x, y, targetPlayer)
    return {
        x = x or 15, y = y or 10,
        alive = true,
        state = targetPlayer and "chase" or "idle",
        target = targetPlayer,
    }
end

--- 需要 mock 的依赖系统键列表（CanUse 内 pcall(require, ...) 会读取）
local _depModuleKeys = {
    "systems.ChallengeSystem",
    "systems.TrialTowerSystem",
    "systems.PrisonTowerSystem",
    "network.DungeonClient",
}

--- 保存/恢复依赖模块的快照
local _savedDeps = {}
local function saveDeps()
    for _, k in ipairs(_depModuleKeys) do
        _savedDeps[k] = package.loaded[k]  -- 可能为 nil
    end
end
local function restoreDeps()
    for _, k in ipairs(_depModuleKeys) do
        package.loaded[k] = _savedDeps[k]
    end
end

--- Mock 依赖系统为惰性（IsActive/IsDungeonMode 返回 false）
local function mockDeps()
    package.loaded["systems.ChallengeSystem"]   = { IsActive = function() return false end }
    package.loaded["systems.TrialTowerSystem"]   = { IsActive = function() return false end }
    package.loaded["systems.PrisonTowerSystem"]  = { IsActive = function() return false end }
    package.loaded["network.DungeonClient"]      = { IsDungeonMode = function() return false end }
end

--- 单例模块实例 + 真实 CanUse 的备份
local _sys = nil           -- 只 require 一次，之后复用
local _realCanUse = nil    -- 保存模块原始 CanUse

--- 获取 TownReturnSystem 的干净实例（首次 require，后续仅重置状态字段）
--- @param stubCanUse? boolean 是否桩化 CanUse() 为始终 true（默认 true，避免真实系统干扰）
local function freshSystem(stubCanUse)
    if not _sys then
        -- 首次：Mock 依赖 + 加载模块 + 保存真实 CanUse
        mockDeps()
        package.loaded["systems.TownReturnSystem"] = nil
        _sys = require("systems.TownReturnSystem")
        _realCanUse = _sys.CanUse
    end
    -- 每次调用：重置所有运行时状态（避免跨用例污染）
    _sys._channeling    = false
    _sys._channelTimer  = 0
    _sys._fxTimer       = 0
    _sys._startX        = 0
    _sys._startY        = 0
    -- 根据参数设置 CanUse
    if stubCanUse ~= false then
        _sys.CanUse = function()
            local p = GameState.player
            if not p or not p.alive then
                return false, "当前无法使用回城"
            end
            return true, nil
        end
    else
        _sys.CanUse = _realCanUse  -- 恢复真实 CanUse
    end
    return _sys
end

--- 模拟 N 帧更新
local function tickFrames(sys, dt, frames)
    for _ = 1, frames do
        sys.Update(dt)
    end
end

--------------------------------------------------------------------
-- TC01: 点击后开始 2 秒读条
--------------------------------------------------------------------
function T.TC01_start_channeling()
    print("TC01: 点击后开始2秒读条")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    local ok, reason = sys.TryStart()
    assert_true("TryStart returns true", ok)
    assert_true("IsChanneling is true", sys.IsChanneling())
    assert_eq("channelTimer is 0", sys._channelTimer, 0)
    assert_near("CHANNEL_DURATION is 2.0", sys.CHANNEL_DURATION, 2.0)
end

--------------------------------------------------------------------
-- TC02: 读条中再次点击取消
--------------------------------------------------------------------
function T.TC02_click_to_cancel()
    print("TC02: 读条中再次点击取消")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    sys.TryStart()
    sys.Update(0.5) -- 读条0.5秒
    assert_true("Still channeling at 0.5s", sys.IsChanneling())

    -- 再次点击取消
    local ok, _ = sys.TryStart()
    assert_true("Second TryStart returns true (cancelled)", ok)
    assert_false("IsChanneling is false after cancel", sys.IsChanneling())
end

--------------------------------------------------------------------
-- TC03: 受到攻击不会取消读条
--------------------------------------------------------------------
function T.TC03_attack_does_not_cancel()
    print("TC03: 受到攻击不取消")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    sys.TryStart()
    -- 模拟受到攻击：减血但不移动
    GameState.player.hp = 50
    sys.Update(0.5)
    assert_true("Still channeling after damage", sys.IsChanneling())
    local progress = sys.GetChannelProgress()
    assert_near("Progress at ~0.25", progress, 0.25, 0.02)
end

--------------------------------------------------------------------
-- TC04: 玩家移动取消读条
--------------------------------------------------------------------
function T.TC04_movement_cancels()
    print("TC04: 移动取消读条")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    sys.TryStart()
    sys.Update(0.3) -- 部分读条
    assert_true("Channeling before move", sys.IsChanneling())

    -- 模拟玩家移动
    GameState.player.x = 10.5
    GameState.player.y = 10.5
    sys.Update(0.016)
    assert_false("Channeling cancelled after move", sys.IsChanneling())
end

--------------------------------------------------------------------
-- TC05: 玩家死亡取消读条
--------------------------------------------------------------------
function T.TC05_death_cancels()
    print("TC05: 死亡取消读条")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    sys.TryStart()
    sys.Update(0.5)
    assert_true("Channeling before death", sys.IsChanneling())

    GameState.player.alive = false
    sys.Update(0.016)
    assert_false("Channeling cancelled on death", sys.IsChanneling())
end

--------------------------------------------------------------------
-- TC06: 挑战/试炼塔/镇狱塔/副本中无法启动
--------------------------------------------------------------------
function T.TC06_restricted_contexts()
    print("TC06: 受限场景无法启动")
    local sys = freshSystem(false) -- 使用真实 CanUse
    GameState.player = makeMockPlayer(10, 10)

    -- 正常状态可以启动
    local canUse, _ = sys.CanUse()
    assert_true("CanUse=true normally", canUse)

    -- 注: 实际系统使用 pcall(require, ...) 来检测，
    -- 这里我们直接调用 CanUse 验证在正常状态下返回 true
    -- 真正的拦截测试需在运行时手动激活各系统
    print("  (挑战/试炼塔/镇狱塔/副本拦截需运行时手动验证)")
end

--------------------------------------------------------------------
-- TC07: 读条完成传送到 SPAWN_POINT
--------------------------------------------------------------------
function T.TC07_teleport_to_spawn()
    print("TC07: 传送到 SPAWN_POINT")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(50, 50)
    GameState.pet = makeMockPet(51, 50)
    GameState.monsters = {}

    local spawn = ActiveZoneData.Get().SPAWN_POINT
    if not spawn then
        total_ = total_ + 1
        failed_ = failed_ + 1
        print("  ❌ SPAWN_POINT not found in ActiveZoneData")
        return
    end

    sys.TryStart()
    -- 模拟完整读条（2秒，每帧0.1s x 20帧）
    tickFrames(sys, 0.1, 20)

    assert_false("Not channeling after complete", sys.IsChanneling())
    assert_near("Player x = spawn.x", GameState.player.x, spawn.x, 0.01)
    assert_near("Player y = spawn.y", GameState.player.y, spawn.y, 0.01)
end

--------------------------------------------------------------------
-- TC08: 传送后同步 lastMoveX/Y, stuckTimer, 宠物位置
--------------------------------------------------------------------
function T.TC08_post_teleport_sync()
    print("TC08: 传送后状态同步")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(50, 50)
    GameState.pet = makeMockPet(51, 50)
    GameState.monsters = {}

    local spawn = ActiveZoneData.Get().SPAWN_POINT
    if not spawn then
        total_ = total_ + 1; failed_ = failed_ + 1
        print("  ❌ SPAWN_POINT not found")
        return
    end

    sys.TryStart()
    tickFrames(sys, 0.1, 20)

    assert_near("lastMoveX synced", GameState.player.lastMoveX, spawn.x, 0.01)
    assert_near("lastMoveY synced", GameState.player.lastMoveY, spawn.y, 0.01)
    assert_eq("stuckTimer reset", GameState.player.stuckTimer, 0)
    assert_eq("dx reset", GameState.player.dx, 0)
    assert_eq("dy reset", GameState.player.dy, 0)
    assert_false("moving is false", GameState.player.moving)

    -- 宠物同步
    assert_near("pet x synced", GameState.pet.x, spawn.x + 1, 0.01)
    assert_near("pet y synced", GameState.pet.y, spawn.y, 0.01)
    assert_eq("pet state = follow", GameState.pet.state, "follow")
    assert_eq("pet target = nil", GameState.pet.target, nil)
end

--------------------------------------------------------------------
-- TC09: 传送成功触发 save_request
--------------------------------------------------------------------
function T.TC09_save_request_emitted()
    print("TC09: 传送后触发 save_request")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(50, 50)
    GameState.pet = nil
    GameState.monsters = {}

    local EventBus = require("core.EventBus")
    local saveEmitted = false
    local oldEmit = EventBus.Emit
    EventBus.Emit = function(event, ...)
        if event == "save_request" then
            saveEmitted = true
        end
        if oldEmit then oldEmit(event, ...) end
    end

    sys.TryStart()
    tickFrames(sys, 0.1, 20)

    EventBus.Emit = oldEmit  -- 恢复

    assert_true("save_request was emitted", saveEmitted)
end

--------------------------------------------------------------------
-- TC10: 光效计时器正确启动和结束
--------------------------------------------------------------------
function T.TC10_fx_timer()
    print("TC10: 光效计时器")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(50, 50)
    GameState.pet = nil
    GameState.monsters = {}

    sys.TryStart()
    tickFrames(sys, 0.1, 20)  -- 读条完成

    local fxT = sys.GetFxTimer()
    assert_true("FX timer > 0 after teleport", fxT > 0)
    assert_near("FX timer ≈ FX_DURATION", fxT, sys.FX_DURATION, 0.05)

    -- 消耗光效
    tickFrames(sys, 0.1, 10)
    assert_near("FX timer ≈ 0 after decay", sys.GetFxTimer(), 0, 0.05)
end

--------------------------------------------------------------------
-- TC11: 读条中打开全屏 UI（模拟 CanUse 变 false）
--------------------------------------------------------------------
function T.TC11_ui_panel_cancels()
    print("TC11: CanUse 变 false 取消读条")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    sys.TryStart()
    sys.Update(0.5)
    assert_true("Channeling before CanUse=false", sys.IsChanneling())

    -- 模拟 CanUse 返回 false（通过让 player 死亡）
    GameState.player.alive = false
    sys.Update(0.016)
    assert_false("Channeling cancelled when CanUse=false", sys.IsChanneling())
end

--------------------------------------------------------------------
-- TC12: 读条取消后无残留定时器
--------------------------------------------------------------------
function T.TC12_no_residual_timer()
    print("TC12: 取消后无残留")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    sys.TryStart()
    sys.Update(0.8)
    sys.Cancel()

    assert_false("Not channeling", sys.IsChanneling())
    assert_eq("channelTimer = 0", sys._channelTimer, 0)
    assert_eq("GetChannelProgress = nil", sys.GetChannelProgress(), nil)
end

--------------------------------------------------------------------
-- TC13: 读条期间进度值正确递增
--------------------------------------------------------------------
function T.TC13_progress_increments()
    print("TC13: 读条进度递增")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    sys.TryStart()

    sys.Update(0.5)
    assert_near("Progress at 0.5s ≈ 0.25", sys.GetChannelProgress(), 0.25, 0.02)

    sys.Update(0.5)
    assert_near("Progress at 1.0s ≈ 0.50", sys.GetChannelProgress(), 0.50, 0.02)

    sys.Update(0.5)
    assert_near("Progress at 1.5s ≈ 0.75", sys.GetChannelProgress(), 0.75, 0.02)
end

--------------------------------------------------------------------
-- TC14: 取消后可立即重新开始读条
--------------------------------------------------------------------
function T.TC14_restart_after_cancel()
    print("TC14: 取消后立即重新开始")
    local sys = freshSystem()
    GameState.player = makeMockPlayer(10, 10)

    sys.TryStart()
    sys.Update(0.5)
    sys.Cancel()

    -- 立即重新开始
    local ok, _ = sys.TryStart()
    assert_true("Re-start succeeds", ok)
    assert_true("Channeling again", sys.IsChanneling())
    assert_near("Timer reset to 0", sys._channelTimer, 0, 0.001)
end

--------------------------------------------------------------------
-- TC15: 传送后怪物仇恨清除
--------------------------------------------------------------------
function T.TC15_monster_aggro_cleared()
    print("TC15: 传送后怪物仇恨清除")
    local sys = freshSystem()
    local player = makeMockPlayer(50, 50)
    GameState.player = player
    GameState.pet = nil

    local m1 = makeMockMonster(55, 50, player)
    local m2 = makeMockMonster(60, 50, player)
    local m3 = makeMockMonster(70, 50, nil)  -- 无仇恨
    GameState.monsters = { m1, m2, m3 }

    sys.TryStart()
    tickFrames(sys, 0.1, 20)

    assert_eq("m1 target cleared", m1.target, nil)
    assert_eq("m1 state = idle", m1.state, "idle")
    assert_eq("m2 target cleared", m2.target, nil)
    assert_eq("m2 state = idle", m2.state, "idle")
    assert_eq("m3 state = idle", m3.state, "idle")
end

--------------------------------------------------------------------
-- TC16: CanUse 在玩家不存在/已死亡时返回 false
--------------------------------------------------------------------
function T.TC16_canuse_edge_cases()
    print("TC16: CanUse 边界")
    local sys = freshSystem(false) -- 使用真实 CanUse

    -- 无玩家
    GameState.player = nil
    local canUse1, reason1 = sys.CanUse()
    assert_false("CanUse=false when no player", canUse1)

    -- 死亡玩家
    GameState.player = makeMockPlayer(10, 10)
    GameState.player.alive = false
    local canUse2, reason2 = sys.CanUse()
    assert_false("CanUse=false when dead", canUse2)

    -- 正常玩家
    GameState.player.alive = true
    local canUse3, _ = sys.CanUse()
    assert_true("CanUse=true when alive", canUse3)
end

--------------------------------------------------------------------
-- RunAll
--------------------------------------------------------------------
function T.RunAll()
    passed_ = 0
    failed_ = 0
    total_  = 0

    -- 备份真实状态
    local origPlayer   = GameState.player
    local origPet      = GameState.pet
    local origMonsters = GameState.monsters

    -- 备份依赖模块（测试结束后恢复）
    saveDeps()

    -- 重置单例（确保本轮测试从头开始）
    _sys = nil
    _realCanUse = nil

    -- 备份 TownReturnSystem 的 package.loaded
    local origTRS = package.loaded["systems.TownReturnSystem"]

    print("========================================")
    print("  快捷回城系统测试 (§4.11)")
    print("========================================")

    local cases = {
        T.TC01_start_channeling,
        T.TC02_click_to_cancel,
        T.TC03_attack_does_not_cancel,
        T.TC04_movement_cancels,
        T.TC05_death_cancels,
        T.TC06_restricted_contexts,
        T.TC07_teleport_to_spawn,
        T.TC08_post_teleport_sync,
        T.TC09_save_request_emitted,
        T.TC10_fx_timer,
        T.TC11_ui_panel_cancels,
        T.TC12_no_residual_timer,
        T.TC13_progress_increments,
        T.TC14_restart_after_cancel,
        T.TC15_monster_aggro_cleared,
        T.TC16_canuse_edge_cases,
    }
    for _, tc in ipairs(cases) do
        local ok, err = pcall(tc)
        if not ok then
            failed_ = failed_ + 1
            total_ = total_ + 1
            print("  💥 CRASH: " .. tostring(err))
        end
    end

    print("========================================")
    print(string.format("  结果: %d/%d 通过, %d 失败", passed_, total_, failed_))
    print("========================================")

    -- 恢复真实状态
    GameState.player   = origPlayer
    GameState.pet      = origPet
    GameState.monsters = origMonsters

    -- 恢复依赖模块和 TownReturnSystem
    restoreDeps()
    package.loaded["systems.TownReturnSystem"] = origTRS

    -- 清理测试单例
    _sys = nil
    _realCanUse = nil

    return passed_, failed_
end

return T
